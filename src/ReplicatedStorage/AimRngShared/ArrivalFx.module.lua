--!nocheck
-- ARRIVAL FX (2026-10-26, owner: rooms' bots "should spawn as you are walking into the room, and make sure they have some sort of
-- method of spawning instead of just poofing in from thin air"). A bot made when you walk into its room (stand-in / party model
-- attr WarpIn = the server time it was made) WARPS IN at its spot: a thin ring opens on the floor under it, a soft shaft of light
-- (bright at the floor, gone at the top) stands over it and narrows away, and the body fades in from nothing over WARP_S
-- (LocalTransparencyModifier: the bot's own look is never touched).
-- While it forms it is NOT THERE yet (owner: holding them still "would make it super easy to kill a bunch of them"): it holds still
-- (SlowMult 0 -- solo: this client runs the bot; party: PartyRuns holds it on the server), your shots pass through it (its parts
-- don't take raycasts) and the server ignores every hit on it for IMMUNE_S (CombatServer DealEnemyDamage: shots, chains, bursts,
-- ailments). Its first attack is already 1.2-2.6 s after it is made. In the biome's signature colour (the room's light pools, the
-- seal gate). Per bot: one ring adornment + one Beam on two Terrain attachments -- no parts, no lights, no particles; one shared
-- Heartbeat while any warp runs.
-- SOUND (2026-10-26): SoundHelper WarpIn at the bot (3D: a reversed air rush that lands as the body forms), at most one every
-- SOUND_GAP s -- a room arriving at once is a short ripple of a few, not a stack of 18.
-- API: ArrivalFx.Play(model, colour, hold?, at?); ArrivalFx.ShouldPlay(inst); ArrivalFx.Forming(inst) (server + client); ArrivalFx.Colour
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = script.Parent

local ArrivalFx = {}
ArrivalFx.WARP_S = 0.7 -- (the body's fade in; the bot holds still and can't be hit this long)
ArrivalFx.IMMUNE_S = 0.85 -- (the server's window: WARP_S + a little for the trip to the client)
ArrivalFx.FX_S = 1.0 -- (ring + shaft, start to gone)
ArrivalFx.FRESH_S = 4 -- (only bots made this recently warp: a room re-shown later just appears as it was)
ArrivalFx.SHAFT_H = 9 -- (the shaft's height over the bot's top)
ArrivalFx.SOUND_GAP = 0.2

-- the biome's signature colour (RoomAtmo.LOOK[biome].Sig), else the fallback
function ArrivalFx.Colour(biome: string?, fallback: Color3?): Color3
    local ok, RA = pcall(require, Shared:WaitForChild("RoomAtmo"))
    local look = ok and RA and RA.LOOK and biome and RA.LOOK[biome]
    return (look and look.Sig) or fallback or Color3.fromRGB(120, 200, 255)
end

function ArrivalFx.ShouldPlay(inst: Instance): boolean
    local t = inst:GetAttribute("WarpIn")
    return type(t) == "number" and Workspace:GetServerTimeNow() - t < ArrivalFx.FRESH_S
end
-- still forming (immune)?
function ArrivalFx.Forming(inst: Instance): boolean
    local t = inst:GetAttribute("WarpIn")
    return type(t) == "number" and Workspace:GetServerTimeNow() - t < ArrivalFx.IMMUNE_S
end

local active = {}
local lastSound = -9
local conn: RBXScriptConnection? = nil
local IS_STUDIO = RunService:IsStudio()
local function Solid(w: any)
    if w.Freed then return end
    w.Freed = true
    for p, q in pairs(w.Query) do if p.Parent then p.CanQuery = q end end
    if w.Hold and w.Model.Parent and w.Model:GetAttribute("SlowMult") == 0 then w.Model:SetAttribute("SlowMult", w.Was) end
end
local function Step()
    local now = os.clock()
    -- (Studio: workspace attr DevWarpHold = 0..1 freezes every warp at that point of the effect, for screenshots)
    local hold = IS_STUDIO and Workspace:GetAttribute("DevWarpHold")
    for i = #active, 1, -1 do
        local w = active[i]
        if type(hold) == "number" then w.T0 = now - math.clamp(hold, 0, 0.99) * ArrivalFx.FX_S end
        local t = math.clamp((now - w.T0) / ArrivalFx.FX_S, 0, 1)
        local b = math.clamp((now - w.T0) / ArrivalFx.WARP_S, 0, 1)
        local body = 1 - (1 - b) * (1 - b) -- (ease out)
        for _, p in ipairs(w.Parts) do
            if p.Parent then p.LocalTransparencyModifier = 1 - body end
        end
        -- (solid once the fade is done AND the server's IMMUNE_S window from w.At has passed: a shot it would refuse never lands here --
        -- the 2026-10-26 sweep found a refused "kill" leaving a bot at 0 health on the client, keeping a room shut)
        if b >= 1 and (not w.At or Workspace:GetServerTimeNow() - w.At >= ArrivalFx.IMMUNE_S) then Solid(w) end
        -- ring: opens to full in the first third, then fades
        local open = 1 - (1 - math.clamp(t * 3, 0, 1)) ^ 2
        local r = w.R * (0.3 + 0.7 * open)
        w.Ring.Radius = r
        w.Ring.InnerRadius = math.max(0, r - 0.35)
        w.Ring.Transparency = 0.1 + 0.9 * t ^ 1.6
        -- shaft: narrows to a thread and fades from the top down
        local wd = w.R * 1.1 * (1 - t) ^ 1.3
        w.Beam.Width0, w.Beam.Width1 = wd, wd * 0.6
        local base = 0.25 + 0.75 * t
        w.Beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, base), NumberSequenceKeypoint.new(0.55, math.min(1, base + 0.35)),
            NumberSequenceKeypoint.new(1, 1) })
        if t >= 1 then
            Solid(w)
            for _, p in ipairs(w.Parts) do if p.Parent then p.LocalTransparencyModifier = 0 end end
            w.Ring:Destroy(); w.Beam:Destroy(); w.A0:Destroy(); w.A1:Destroy()
            table.remove(active, i)
        end
    end
    if #active == 0 and conn then conn:Disconnect(); conn = nil end
end

-- hold: freeze the bot (SlowMult 0) while it forms -- solo floors, where this client runs the bot; at = its WarpIn (server time)
function ArrivalFx.Play(model: Model, colour: Color3, hold: boolean?, at: number?)
    if not model or not model.Parent then return end
    local ok, cf, size = pcall(model.GetBoundingBox, model)
    if not ok then return end
    local parts, query = {}, {}
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            p.LocalTransparencyModifier = 1
            query[p] = p.CanQuery
            p.CanQuery = false -- (your shots pass through it while it forms)
            table.insert(parts, p)
        end
    end
    local R = math.clamp(math.max(size.X, size.Z) * 0.85, 2, 7)
    local foot = cf.Position - Vector3.new(0, size.Y / 2, 0)
    local terrain = Workspace.Terrain
    local ring = Instance.new("CylinderHandleAdornment")
    ring.Name = "WarpRing"
    ring.Adornee = terrain
    ring.CFrame = CFrame.new(foot + Vector3.new(0, 0.1, 0)) * CFrame.Angles(math.pi / 2, 0, 0) -- (the cylinder's axis is its Z)
    ring.Height = 0.08
    ring.Radius, ring.InnerRadius = R * 0.3, math.max(0, R * 0.3 - 0.35)
    ring.Color3 = colour
    ring.Transparency = 0.1
    ring.AlwaysOnTop = false
    ring.ZIndex = 0
    ring.Parent = terrain
    local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
    a0.Name, a1.Name = "WarpA0", "WarpA1"
    a0.Parent, a1.Parent = terrain, terrain
    a0.WorldPosition = foot + Vector3.new(0, 0.1, 0)
    a1.WorldPosition = foot + Vector3.new(0, size.Y + ArrivalFx.SHAFT_H, 0)
    local beam = Instance.new("Beam")
    beam.Name = "WarpShaft"
    beam.Attachment0, beam.Attachment1 = a0, a1
    beam.FaceCamera = true
    beam.Segments = 1
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Color = ColorSequence.new(colour)
    beam.Width0, beam.Width1 = R * 1.1, R * 0.66
    beam.Parent = terrain
    if os.clock() - lastSound >= ArrivalFx.SOUND_GAP then
        local root = model.PrimaryPart or parts[1]
        local okS, SoundHelper = pcall(require, Shared:WaitForChild("SoundHelper"))
        if root and okS then lastSound = os.clock(); SoundHelper.PlayAt("WarpIn", root) end
    end
    local was = model:GetAttribute("SlowMult")
    if hold then model:SetAttribute("SlowMult", 0) end
    table.insert(active, { Model = model, Parts = parts, Query = query, Ring = ring, Beam = beam, A0 = a0, A1 = a1, R = R, T0 = os.clock(),
        Hold = hold == true, Was = was, At = (type(at) == "number") and at or nil })
    if not conn then conn = RunService.Heartbeat:Connect(Step) end
end

return ArrivalFx
