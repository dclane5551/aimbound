--!nocheck
-- AIM ASSIST (touch, PvE only). Owner 2026-10-13 after a real-phone test: "Mobile should have either slight aim assist or
-- auto-shoot (only in pve)" -> decided: a SLIGHT aim assist, no auto fire. Started by PlatformControls on touch devices only
-- (mouse and gamepad never get it). Off in duels / any PvP, Aim Trials (scored), spectating, menus, the hub and with the
-- melee out; on everywhere else you fight bots: dungeons, maps, bosses (shield orbs / aim-round targets too), the range,
-- the hideout dummy, the tutorial.
-- What it does (Settings > Gameplay > "Aim Assist (touch)": Off / Slight (default) / Normal):
--   * FRICTION: your touch look slows down (x0.62 Slight, x0.5 Normal) while the crosshair is over or near an enemy's body,
--     so a drag doesn't fly past a target.
--   * PULL: while you're dragging to look or holding FIRE and the crosshair is just OFF a target (inside a small cone,
--     4 / 5.5 degrees), the view eases toward the body's centre (never the head: headshots stay skill), capped at a slow
--     turn rate. No snapping; nothing once the crosshair is on the enemy (head included); never through walls (the target
--     must be in line of sight from the camera).
-- Cost: the target pick is a 15 Hz scan over a cached enemy set (no workspace sweeps), at most 3 raycasts per scan; the
-- per-frame part is a few vector maths on the one picked target.
--   AimAssist.Start(h) h = { Allowed() -> bool, Nudge(yawRad, pitchRad), Exclude() -> {Instance} }
--   AimAssist.LookScale() -> touch look multiplier right now (friction)
--   AimAssist.Looked()     -- a look drag moved this frame (PlatformControls)
--   AimAssist.SetFiring(on)
local AimAssist = {}

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Shared = script.Parent
local GameSettings = require(Shared:WaitForChild("GameSettings"))

AimAssist.LEVELS = {
    Slight = { Friction = 0.62, Cone = math.rad(4), Rate = 2.6, MaxTurn = math.rad(16) },
    Normal = { Friction = 0.5, Cone = math.rad(5.5), Rate = 4.2, MaxTurn = math.rad(26) },
}
local SCAN_DT = 1 / 15
local MAX_DIST = 420
local SEARCH = math.rad(14) -- (candidates considered at all: the friction zone of a close, wide body can exceed the cone)

local started = false
local hooks: any = {}
local enemies = {} -- [Model] = true (AimRngEnemy tag + AimAssistTarget tag)
local orbs = {}    -- [BasePart] = true (boss shield orbs / aim-round targets: "ShieldOrb<i>" parts, often outside the boss)
local centreOf = setmetatable({}, { __mode = "k" })
local firing = false
local lookedAt = 0
local target: any = nil -- { Model, Part (centre), Radius, OnIt }
local frictionNow = 1

local function Level(): any
    return AimAssist.LEVELS[GameSettings.Get("TouchAimAssist") or "Slight"]
end

local function Centre(m: Instance): BasePart?
    local c = centreOf[m]
    if c and c.Parent then return c end
    if m:IsA("BasePart") then c = m
    else
        c = m:FindFirstChild("Torso") or m:FindFirstChild("HumanoidRootPart") or (m :: any).PrimaryPart or m:FindFirstChild("Body")
            or m:FindFirstChildWhichIsA("BasePart")
    end
    if c and not c:IsA("BasePart") then c = nil end
    centreOf[m] = c
    return c
end
local function Alive(m: Instance): boolean
    if not m.Parent then return false end
    local hp = m:GetAttribute("Health")
    return type(hp) == "number" and hp > 0
end
-- the enemy a hit part belongs to (same walk as the shot code: HitModel links, then up to the model with Health)
local function OwnerOf(inst: Instance): Instance?
    local link = inst:FindFirstChild("HitModel")
    local m = (link and link:IsA("ObjectValue") and link.Value) or inst.Parent
    while m and m ~= Workspace and not m:GetAttribute("Health") do m = m.Parent end
    if m == Workspace then return nil end
    return m
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local function Cast(origin: Vector3, dir: Vector3): RaycastResult?
    params.FilterDescendantsInstances = (hooks.Exclude and hooks.Exclude()) or {}
    return Workspace:Raycast(origin, dir, params)
end

local function Scan()
    target = nil
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local cf = cam.CFrame
    local eye, look = cf.Position, cf.LookVector
    -- 1) what the crosshair is on right now: on an enemy (head included) = friction only, no pull
    local hit = Cast(eye, look * MAX_DIST)
    local onModel = nil
    if hit and hit.Instance then
        local inst = hit.Instance
        if orbs[inst] then onModel = inst else
            local m = OwnerOf(inst)
            if m and enemies[m] and Alive(m) then onModel = m end
        end
    end
    -- 2) the live enemy nearest the crosshair (by angle) that the camera can see
    local list = {}
    local function Consider(key: Instance, part: BasePart?, radius: number)
        if not part then return end
        local to = part.Position - eye
        local d = to.Magnitude
        if d < 1 or d > MAX_DIST then return end
        local ang = math.acos(math.clamp(look:Dot(to / d), -1, 1))
        if ang > SEARCH then return end
        table.insert(list, { Key = key, Part = part, Dist = d, Ang = ang, Radius = radius })
    end
    for m in pairs(enemies) do
        if not m.Parent then enemies[m] = nil
        elseif Alive(m) then
            local c = Centre(m)
            if c then Consider(m, c, math.clamp(math.max(c.Size.X, c.Size.Z) * 0.6, 0.8, 4)) end
        end
    end
    for o in pairs(orbs) do
        if not o.Parent then orbs[o] = nil
        elseif o.Transparency < 0.95 and o.CanQuery then Consider(o, o, math.max(o.Size.X, o.Size.Y, o.Size.Z) * 0.5) end
    end
    if #list == 0 then return end
    table.sort(list, function(a, b) return a.Ang < b.Ang end)
    for i = 1, math.min(2, #list) do
        local c = list[i]
        local onIt = (onModel == c.Key)
        local ok = onIt
        if not ok then
            local r = Cast(eye, (c.Part.Position - eye).Unit * (c.Dist + 2))
            ok = r ~= nil and r.Instance ~= nil and (r.Instance == c.Part or r.Instance:IsDescendantOf(c.Key) or OwnerOf(r.Instance) == c.Key)
        end
        if ok then
            target = { Key = c.Key, Part = c.Part, Radius = c.Radius, OnIt = onIt }
            return
        end
    end
end

-- per frame: friction from the current angle; pull (only off the target, only while you're aiming)
local function Step(dt: number)
    frictionNow = 1
    local lv = Level()
    if not lv or not target or not (hooks.Allowed and hooks.Allowed()) then return end
    local cam = Workspace.CurrentCamera
    local p = target.Part
    if not (cam and p and p.Parent) then target = nil return end
    local cf = cam.CFrame
    local to = p.Position - cf.Position
    local d = to.Magnitude
    if d < 1 then return end
    local loc = cf:VectorToObjectSpace(to / d)
    local yawErr = math.atan2(-loc.X, -loc.Z)                              -- + = the target is to the left
    local pitchErr = math.atan2(loc.Y, math.sqrt(loc.X * loc.X + loc.Z * loc.Z)) -- + = above
    local err = math.sqrt(yawErr * yawErr + pitchErr * pitchErr)
    local body = math.atan2(target.Radius, d)
    -- friction: full over the body, easing out over one more body width + 1 degree
    local edge = body * 2 + math.rad(1)
    if target.OnIt or err <= body then frictionNow = lv.Friction
    elseif err < edge then frictionNow = lv.Friction + (1 - lv.Friction) * ((err - body) / (edge - body)) end
    -- pull: off the target, inside the cone, while dragging (last 0.2 s) or firing
    if target.OnIt or err > lv.Cone or err < body * 0.35 then return end
    if not (firing or os.clock() - lookedAt < 0.2) then return end
    local turn = math.min(err * (1 - math.exp(-lv.Rate * dt)), lv.MaxTurn * dt)
    local k = turn / err
    if hooks.Nudge then hooks.Nudge(yawErr * k, pitchErr * k) end
end

function AimAssist.LookScale(): number return frictionNow end
function AimAssist.Looked() lookedAt = os.clock() end
function AimAssist.SetFiring(on: boolean) firing = on == true end
function AimAssist.Target(): any return target end -- (Studio checks)

function AimAssist.Start(h: any)
    if started then return end
    started = true
    hooks = h or {}
    local function AddEnemy(m) if m:IsA("Model") then enemies[m] = true end end
    for _, tag in ipairs({ "AimRngEnemy", "AimAssistTarget" }) do
        for _, m in ipairs(CollectionService:GetTagged(tag)) do AddEnemy(m) end
        CollectionService:GetInstanceAddedSignal(tag):Connect(AddEnemy)
        CollectionService:GetInstanceRemovedSignal(tag):Connect(function(m) enemies[m] = nil end)
    end
    local function MaybeOrb(d)
        if d:IsA("BasePart") and string.sub(d.Name, 1, 9) == "ShieldOrb" then orbs[d] = true end
    end
    Workspace.DescendantAdded:Connect(MaybeOrb)
    task.defer(function() for _, d in ipairs(Workspace:GetDescendants()) do MaybeOrb(d) end end)
    local acc = 0
    RunService.RenderStepped:Connect(function(dt)
        if not Level() or not (hooks.Allowed and hooks.Allowed()) then
            target, frictionNow = nil, 1
            return
        end
        acc += dt
        if acc >= SCAN_DT then acc = 0; Scan() end
        Step(math.min(dt, 0.1))
    end)
end

return AimAssist
