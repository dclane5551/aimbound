--!nocheck
-- ============================================================================================
-- NEON TAMER (0.93, owner: "Everything still comes across as still like too neon, some is fine but there needs to be
-- variety" -> "All of it bothers me, including on skins"). Neon is used at hundreds of sites (hub signs + windows, biome
-- kits, enemies, bosses, every skin set's Glow parts, gloves), so this is ONE client pass over everything drawn:
--   * gameplay glow stays as it is: attack telegraphs (Atk*), weak points, aim targets, boss mechanic parts, enemy heads /
--     eyes / cores, the aim-trial room
--   * of the rest, about two thirds become solid painted colour (SmoothPlastic, a touch darker + less saturated) and the
--     other third keeps its glow, dimmed. Which is which is decided by the part's NAME + size, so a row of the same piece
--     (windows, trims, a skin's seams) always matches -- variety between kinds, never a speckled mix.
--   * COSMETICS (skins, gloves, sleeves, kill effects, world gear, hideout pieces) are never painted: same Neon, 15% darker
--   * Settings > Video > Neon Glow: "Reduced" (default) / "Full" (puts everything back).
-- Converted parts remember their original look in attributes NeonOrigColor / NeonOrigMat; set attribute KeepNeon on a
-- part (or an ancestor folder / model) to exempt it.
-- ============================================================================================
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local NeonTamer = {}
NeonTamer.KEEP_SHARE = 0.35 -- share of non-gameplay neon kinds that keep a (dimmed) glow
NeonTamer.DIM = 0.78 -- colour multiplier on the neon that stays
NeonTamer.PAINT_DARKEN = 0.86 -- colour multiplier on neon turned to paint
NeonTamer.PAINT_DESAT = 0.22 -- pull toward grey on paint

local NEON = Enum.Material.Neon
local KEEP_NAMES = { WeakGlow = true, TrialTarget = true, CueArrow = true, LockTile = true, CoolantPlate = true, LightningRod = true,
    Brand = true, Head = true, Eye = true, Iris = true, Core = true, BigIris = true }
local KEEP_PREFIX = { "Atk", "ShieldOrb", "BreakPart", "Orb" }
local KEEP_FOLDERS = { AimBossCues = true, AimBossWeakGlows = true, AimBossCueHighlights = true, AimTrialRoom = true }
-- COSMETICS (owner after the first pass: "the cosmetics look kind of bad now. Turn it back up, just have it be like 15% less
-- than what we originally had instead of changing the skins so much"): skins, gloves, sleeves, melee skins, kill effects,
-- world gear and hideout cosmetics keep their Neon, only COSMETIC_DIM darker -- never painted
NeonTamer.COSMETIC_DIM = 0.85
local COSMETIC_FOLDERS = { GunViewmodel = true, SpectateViewmodel = true, SkinFxWorld = true, InfernalKill = true, SeraphimKill = true,
    WorldGun = true, WorldMelee = true, WorldGloves = true, WorldArmor = true, AvatarLook = true, HideoutLocal = true }
local Players = game:GetService("Players")
local function Cosmetic(p: BasePart): boolean
    if p:GetAttribute("SkinDeco") or p.Name == "GloveDeco" then return true end
    local a = p.Parent
    local depth = 0
    while a and a ~= Workspace and depth < 10 do
        if COSMETIC_FOLDERS[a.Name] or (a:IsA("Model") and Players:GetPlayerFromCharacter(a)) then return true end
        a = a.Parent
        depth += 1
    end
    return false
end

local enabled = true
local touched: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function Gameplay(p: BasePart): boolean
    local n = p.Name
    if KEEP_NAMES[n] then return true end
    for _, pre in ipairs(KEEP_PREFIX) do if string.sub(n, 1, #pre) == pre then return true end end
    if p:GetAttribute("KeepNeon") or p:GetAttribute("TrialTarget") or p:FindFirstChild("HitModel") then return true end
    if CollectionService:HasTag(p, "AimDanger") or CollectionService:HasTag(p, "AimSafe") then return true end
    local a = p.Parent
    local depth = 0
    while a and a ~= Workspace and depth < 8 do
        if KEEP_FOLDERS[a.Name] or a:GetAttribute("KeepNeon") then return true end
        a = a.Parent
        depth += 1
    end
    return false
end

-- a stable 0..1 roll per KIND of piece (name + rounded size): every copy of a piece gets the same treatment
local function Roll(p: BasePart): number
    local s = p.Size
    local key = p.Name .. string.format("|%.1f|%.1f|%.1f", s.X, s.Y, s.Z)
    local h = 5381
    for i = 1, #key do h = (h * 33 + string.byte(key, i)) % 2147483647 end
    return (h % 1000) / 1000
end

local function Grey(c: Color3, k: number): Color3
    local g = (c.R + c.G + c.B) / 3
    return c:Lerp(Color3.new(g, g, g), k)
end

local function Tame(p: BasePart)
    if touched[p] or p.Material ~= NEON or Gameplay(p) then return end
    touched[p] = true
    p:SetAttribute("NeonOrigColor", p.Color)
    p:SetAttribute("NeonOrigMat", "Neon")
    local c = p.Color
    if Cosmetic(p) then -- (cosmetics: the same glow, 15% softer)
        local k = NeonTamer.COSMETIC_DIM
        p.Color = Color3.new(c.R * k, c.G * k, c.B * k)
    elseif Roll(p) < NeonTamer.KEEP_SHARE then
        p.Color = Color3.new(c.R * NeonTamer.DIM, c.G * NeonTamer.DIM, c.B * NeonTamer.DIM)
    else
        local d = NeonTamer.PAINT_DARKEN
        local g = Grey(c, NeonTamer.PAINT_DESAT)
        p.Material = Enum.Material.SmoothPlastic
        p.Color = Color3.new(g.R * d, g.G * d, g.B * d)
    end
end

local function Restore(p: BasePart)
    local orig = p:GetAttribute("NeonOrigColor")
    if typeof(orig) == "Color3" then
        p.Color = orig
        p.Material = NEON
    end
    p:SetAttribute("NeonOrigColor", nil)
    p:SetAttribute("NeonOrigMat", nil)
    touched[p] = nil
end

function NeonTamer.SetEnabled(on: boolean)
    enabled = on
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("BasePart") then
            if on then Tame(d) elseif d:GetAttribute("NeonOrigMat") then Restore(d) end
        end
    end
end

function NeonTamer.Start(initialOn: boolean)
    enabled = initialOn
    Workspace.DescendantAdded:Connect(function(d)
        if enabled and d:IsA("BasePart") and d.Material == NEON then
            -- (wait a frame: builders often set the Name / attributes / HitModel link right after parenting)
            task.defer(function() if enabled and d.Parent then Tame(d) end end)
        end
    end)
    if enabled then
        task.spawn(function()
            local all = Workspace:GetDescendants()
            for i, d in ipairs(all) do
                if d:IsA("BasePart") then Tame(d) end
                if i % 2000 == 0 then task.wait() end
            end
        end)
    end
end

return NeonTamer
