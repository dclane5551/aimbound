--!strict
-- QUALITY MODE (UPDATE 4, owner: "With this update, we will add a low quality option in the settings for players with
-- worse computers"): Settings > Video > Graphics Quality = "Auto" (default) | "High" | "Low".
-- AUTO (optimization pass 2026-10-27, owner rule "must run on almost anything"): Low on touch-first devices (phones,
-- tablets) and when the player's own Roblox graphics slider is set by hand to AUTO_LOW_MAX or lower; High otherwise.
-- Everything that asks "is it Low?" goes through QualityMode.IsLow() so Auto resolves in one place.
--
-- Builders (DungeonGenerator, Worlds, HubCity, hideouts ...) tag decoration that only adds looks:
--   QualityMode.Detail(inst)  -> hidden on Low (parts / decals / textures go transparent, emitters / lights / beams off)
--   QualityMode.Thin(emitter) -> kept on Low but at THIN of its rate (rain, ash, motes: the mood stays, the cost drops)
-- Tags replicate, so server-built (party) floors work the same; only the client applies them. Never tag gameplay parts
-- (hitboxes, colliders, telegraphs, targets, portals) -- a hidden collider still collides, but a hidden target can't be seen.
-- Global Low extras live with the light setup (AimRngClient ApplyLightProfile): no shadows, no bloom / sun rays, no
-- terrain grass.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local QualityMode = {}
QualityMode.KEY = "GraphicsQuality"
QualityMode.TAG = "QDetail"
QualityMode.THIN_TAG = "QThin"
QualityMode.THIN = 0.35

local GS: any = nil
local function Settings(): any
    if GS == nil then
        local ok, m = pcall(function() return require(script.Parent:WaitForChild("GameSettings", 5) :: ModuleScript) end)
        GS = ok and m or false
    end
    return GS or nil
end

QualityMode.AUTO_LOW_MAX = 4 -- (Roblox's graphics slider 1-10: a player who set it to 4 or lower by hand wants speed)

local function UserQuality(): Enum.SavedQualitySetting?
    local ok, q = pcall(function() return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel end)
    return ok and q or nil
end

-- what Auto picks on this device right now
function QualityMode.AutoLow(): boolean
    local q = UserQuality()
    if q and q ~= Enum.SavedQualitySetting.Automatic then return q.Value <= QualityMode.AUTO_LOW_MAX end
    local UIS = game:GetService("UserInputService")
    return UIS.TouchEnabled and not UIS.KeyboardEnabled
end

function QualityMode.IsLow(): boolean
    if not RunService:IsClient() then return false end
    local s = Settings()
    if s == nil then return false end
    local v = s.Get(QualityMode.KEY)
    if v == "Auto" then return QualityMode.AutoLow() end
    return v == "Low"
end

-- fn(low) now and on every change (the setting, or the Roblox graphics slider while on Auto)
function QualityMode.OnChanged(fn: (boolean) -> ())
    local s = Settings()
    if not s then task.spawn(fn, false) return end
    s.OnChanged(QualityMode.KEY, function() fn(QualityMode.IsLow()) end)
    pcall(function()
        (UserSettings():GetService("UserGameSettings") :: any):GetPropertyChangedSignal("SavedQualityLevel"):Connect(function()
            if s.Get(QualityMode.KEY) == "Auto" then fn(QualityMode.IsLow()) end
        end)
    end)
end

function QualityMode.Detail<T>(inst: T): T
    CollectionService:AddTag(inst :: any, QualityMode.TAG)
    return inst
end

function QualityMode.Thin<T>(inst: T): T
    CollectionService:AddTag(inst :: any, QualityMode.THIN_TAG)
    return inst
end

-- ===== the client applier =====
local low = false
local function SetOne(d: Instance, hide: boolean)
    if d:IsA("BasePart") or d:IsA("Decal") then
        local o = d:GetAttribute("QOrigT")
        if hide then
            if o == nil then d:SetAttribute("QOrigT", (d :: any).Transparency) end
            (d :: any).Transparency = 1
        elseif o ~= nil then
            (d :: any).Transparency = o
            d:SetAttribute("QOrigT", nil)
        end
    elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") or d:IsA("Fire") or d:IsA("Smoke")
        or d:IsA("Sparkles") or d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
        local o = d:GetAttribute("QOrigE")
        if hide then
            if o == nil then d:SetAttribute("QOrigE", (d :: any).Enabled) end
            (d :: any).Enabled = false
        elseif o ~= nil then
            (d :: any).Enabled = o
            d:SetAttribute("QOrigE", nil)
        end
    end
end
local function ApplyDetail(inst: Instance)
    SetOne(inst, low)
    for _, d in ipairs(inst:GetDescendants()) do SetOne(d, low) end
end
local function ApplyThin(inst: Instance)
    if not inst:IsA("ParticleEmitter") then return end
    local e = inst :: ParticleEmitter
    local o = e:GetAttribute("QOrigRate")
    if low then
        if o == nil then e:SetAttribute("QOrigRate", e.Rate); o = e.Rate end
        e.Rate = (o :: number) * QualityMode.THIN
    elseif o ~= nil then
        e.Rate = o :: number
        e:SetAttribute("QOrigRate", nil)
    end
end
local function ApplyAll()
    for _, i in ipairs(CollectionService:GetTagged(QualityMode.TAG)) do ApplyDetail(i) end
    for _, i in ipairs(CollectionService:GetTagged(QualityMode.THIN_TAG)) do ApplyThin(i) end
end

local started = false
function QualityMode.Start()
    if started or not RunService:IsClient() then return end
    started = true
    CollectionService:GetInstanceAddedSignal(QualityMode.TAG):Connect(function(i)
        -- (builders tag a model before filling it: apply after this frame's build)
        if low then task.defer(ApplyDetail, i) end
    end)
    CollectionService:GetInstanceAddedSignal(QualityMode.THIN_TAG):Connect(function(i)
        if low then task.defer(ApplyThin, i) end
    end)
    QualityMode.OnChanged(function(isLow)
        if isLow == low then return end
        low = isLow
        ApplyAll()
    end)
end
if RunService:IsClient() then task.defer(QualityMode.Start) end

return QualityMode
