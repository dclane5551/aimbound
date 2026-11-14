--!nocheck
-- BRASS SKYPORT (0.87 world): a steampunk city floating above the clouds -- wooden decks, brick and brass, great gears,
-- riveted boilers venting steam, crate stacks and pipes, brass lamp posts, a clock tower, moored balloons and airships
-- drifting past over a sea of cloud. Sister: Stormspire.
local K = require(script.Parent.Parent:WaitForChild("WorldKit"))
local C3, M = K.C3, K.M
local P, Solid, Deco, Neon, Wedge = K.P, K.Solid, K.Deco, K.Neon, K.Wedge

local DECK, DECK2, BRICK, BRASS, COPPER = C3(132, 98, 66), C3(110, 80, 56), C3(140, 84, 66), C3(200, 156, 80), C3(176, 104, 70)
local IRON, CANVAS, CANVAS2, LAMP = C3(56, 54, 52), C3(220, 200, 170), C3(180, 70, 60), C3(255, 210, 140)

local W = {}
W.Id = "Sky"
W.Title = "BRASS SKYPORT"
W.TitleColor = C3(240, 190, 100)
W.Sister = "Storm"
W.HazardName = "Steam Vent"

local function Gear(parent, cf, r, thick, col, teeth)
    -- a gear standing on edge (axis = cf's Z): a disc, a hub, teeth round the rim
    P(parent, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(thick, r * 2, r * 2), CFrame = cf * CFrame.Angles(0, math.rad(90), 0), Color = col, Material = M.Metal })
    P(parent, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(thick * 1.6, r * 0.5, r * 0.5), CFrame = cf * CFrame.Angles(0, math.rad(90), 0), Color = IRON, Material = M.Metal })
    for k = 0, (teeth or 12) - 1 do
        local a = k / (teeth or 12) * math.pi * 2
        P(parent, { Size = Vector3.new(r * 0.22, r * 0.26, thick), CFrame = cf * CFrame.Angles(0, 0, a) * CFrame.new(0, r + r * 0.1, 0), Color = col, Material = M.Metal })
    end
end
-- (UPDATE 4 prop pass: real textured models from ReplicatedStorage.WorldProps.Sky via WorldKit.Prop when the place has
-- them; the part build under each is the fallback. Gameplay boxes = the old solid parts, so cover plays the same.)
local function GearStand(geo, cf, s)
    if K.Prop(geo, "Sky", "GearStand", cf, s, { { Vector3.new(6, 1.6, 2.4), Vector3.new(0, 0.8, 0) } }) then return end
    -- a big brass gear standing in an iron cradle (the cradle is cover; shots pass through the spokes' gaps)
    Solid(geo, Vector3.new(6 * s, 1.6 * s, 2.4 * s), cf * CFrame.new(0, 0.8 * s, 0), IRON, M.Metal)
    Gear(geo, cf * CFrame.new(0, 5 * s, 0), 3.6 * s, 0.8 * s, BRASS, 14)
    for _, sx in ipairs({ -1, 1 }) do Deco(geo, Vector3.new(0.5 * s, 4 * s, 0.5 * s), cf * CFrame.new(sx * 2.2 * s, 3 * s, 0) * CFrame.Angles(0, 0, sx * 0.4), IRON, M.Metal) end
end
local function Boiler(geo, cf, s)
    if K.Prop(geo, "Sky", "Boiler", cf, s, { { Vector3.new(6, 3.8, 3.6), Vector3.new(0, 2, 0) } }) then return end
    -- a riveted copper boiler on its side: bands, a pressure gauge, a valve wheel, a stack that puffs steam
    local body = cf * CFrame.new(0, 2 * s, 0)
    Solid(geo, Vector3.new(6 * s, 3.6 * s, 3.6 * s), body, COPPER, M.Metal, Enum.PartType.Cylinder)
    for k = -1, 1 do Deco(geo, Vector3.new(0.3 * s, 3.75 * s, 3.75 * s), body * CFrame.new(k * 2 * s, 0, 0), BRASS, M.Metal, Enum.PartType.Cylinder) end
    Deco(geo, Vector3.new(0.4 * s, 3.8 * s, 3.8 * s), body * CFrame.new(3 * s, 0, 0), IRON, M.Metal, Enum.PartType.Cylinder)
    Deco(geo, Vector3.new(0.2 * s, 1.1 * s, 1.1 * s), body * CFrame.new(3.2 * s, 0.6 * s, 0), C3(240, 236, 220), M.SmoothPlastic, Enum.PartType.Cylinder)
    Deco(geo, Vector3.new(2.6 * s, 0.7 * s, 0.7 * s), K.Up(body * CFrame.new(-1.6 * s, 2.6 * s, 0)), IRON, M.Metal, Enum.PartType.Cylinder)
    local stack = Deco(geo, Vector3.new(0.4, 0.4, 0.4), body * CFrame.new(-1.6 * s, 4 * s, 0), IRON, M.Metal)
    K.Emit(stack, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(240, 236, 230)), Rate = 1.5, Lifetime = NumberRange.new(2, 3),
        Speed = NumberRange.new(4, 6), SpreadAngle = Vector2.new(10, 10), EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new(1, 4), Transparency = NumberSequence.new(0.5, 1) })
    Deco(geo, Vector3.new(0.2 * s, 1.4 * s, 1.4 * s), body * CFrame.new(0, 0, -1.9 * s) * CFrame.Angles(0, math.rad(90), 0), BRASS, M.Metal, Enum.PartType.Cylinder)
    for _, sx in ipairs({ -1, 1 }) do Solid(geo, Vector3.new(0.8 * s, 1.0 * s, 3.4 * s), cf * CFrame.new(sx * 2 * s, 0.5 * s, 0), IRON, M.Metal) end
end
local function Cargo(geo, cf, s)
    if K.Prop(geo, "Sky", "Cargo", cf, s, { { Vector3.new(3.4, 3, 3.4), Vector3.new(-1.4, 1.5, 0) }, { Vector3.new(2.6, 2.4, 2.6), Vector3.new(1.8, 1.2, 0.4) }, { Vector3.new(2.6, 2.2, 2.6), Vector3.new(-1.1, 4.1, 0.2) } }) then return end
    -- crates strapped together with brass corners, a coil of pipe beside them
    Solid(geo, Vector3.new(3.4, 3, 3.4) * s, cf * CFrame.new(0, 1.5 * s, 0), DECK, M.WoodPlanks)
    Solid(geo, Vector3.new(2.6, 2.4, 2.6) * s, cf * CFrame.new(3.2 * s, 1.2 * s, 0.4 * s) * CFrame.Angles(0, 0.3, 0), DECK2, M.WoodPlanks)
    Solid(geo, Vector3.new(2.6, 2.2, 2.6) * s, cf * CFrame.new(0.3 * s, 4.1 * s, 0.2 * s) * CFrame.Angles(0, -0.25, 0), DECK2, M.WoodPlanks)
    for _, y in ipairs({ 0.6, 2.4 }) do Deco(geo, Vector3.new(3.5 * s, 0.25 * s, 3.5 * s), cf * CFrame.new(0, y * s, 0), BRASS, M.Metal) end
    Deco(geo, Vector3.new(4 * s, 0.9 * s, 0.9 * s), cf * CFrame.new(-1 * s, 0.45 * s, -2.6 * s), COPPER, M.Metal, Enum.PartType.Cylinder)
end
local function Lamp(geo, cf, s, lit)
    if K.Prop(geo, "Sky", "Lamp", cf, s, { { Vector3.new(0.6, 8, 0.6), Vector3.new(0, 4, 0) } }) then
        local g = Neon(geo, Vector3.one * 0.9 * s, cf * CFrame.new(0, 8.9 * s, 0), LAMP, 0.15, Enum.PartType.Ball) -- (the lit globe)
        if lit then K.Light(g, LAMP, 24, 1.0) end
        return
    end
    -- a brass lamp post with a glass globe
    K.Pillar(geo, 0.5 * s, 8 * s, cf, BRASS, M.Metal, true)
    Deco(geo, Vector3.new(1.4 * s, 0.6 * s, 1.4 * s), cf * CFrame.new(0, 0.3 * s, 0), IRON, M.Metal)
    Deco(geo, Vector3.new(1.0 * s, 0.3 * s, 1.0 * s), cf * CFrame.new(0, 8.1 * s, 0), IRON, M.Metal)
    local g = Neon(geo, Vector3.one * 1.3 * s, cf * CFrame.new(0, 8.9 * s, 0), LAMP, 0.15, Enum.PartType.Ball)
    Deco(geo, Vector3.new(0.6 * s, 0.4 * s, 0.6 * s), cf * CFrame.new(0, 9.7 * s, 0), BRASS, M.Metal)
    if lit then K.Light(g, LAMP, 24, 1.0) end
end
local function ClockTower(geo, cf, s)
    if K.Prop(geo, "Sky", "ClockTower", cf, s, { { Vector3.new(5, 16, 5), Vector3.new(0, 8, 0) } }) then return end
    -- a brick tower with a brass clock face on each side and a copper dome
    local h = 16 * s
    Solid(geo, Vector3.new(5 * s, h, 5 * s), cf * CFrame.new(0, h / 2, 0), BRICK, M.Brick)
    Deco(geo, Vector3.new(5.6 * s, 0.6 * s, 5.6 * s), cf * CFrame.new(0, h, 0), BRASS, M.Metal)
    for k = 0, 3 do
        local f = cf * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, h * 0.8, -2.55 * s)
        Deco(geo, Vector3.new(0.2 * s, 3.4 * s, 3.4 * s), f * CFrame.Angles(0, math.rad(90), 0), BRASS, M.Metal, Enum.PartType.Cylinder)
        Deco(geo, Vector3.new(0.25 * s, 2.8 * s, 2.8 * s), f * CFrame.new(0, 0, -0.05 * s) * CFrame.Angles(0, math.rad(90), 0), C3(244, 236, 214), M.SmoothPlastic, Enum.PartType.Cylinder)
        Deco(geo, Vector3.new(0.18 * s, 1.2 * s, 0.1 * s), f * CFrame.new(0, 0.5 * s, -0.2 * s), IRON, M.Metal)
    end
    Deco(geo, Vector3.one * 6 * s, cf * CFrame.new(0, h + 1 * s, 0), COPPER, M.Metal, Enum.PartType.Ball)
    Deco(geo, Vector3.new(0.4 * s, 3 * s, 0.4 * s), cf * CFrame.new(0, h + 5 * s, 0), BRASS, M.Metal)
end
local function Balloon(parent, cf, s)
    if K.Prop(parent, "Sky", "Balloon", cf, s) then return end
    -- a moored balloon: a striped envelope, ropes, a wicker basket
    for k = 0, 5 do
        P(parent, { Shape = Enum.PartType.Ball, Size = Vector3.new(8.2 - math.abs(k - 2.5) * 0.9, 10, 8.2 - math.abs(k - 2.5) * 0.9) * s, CFrame = cf * CFrame.new(0, 9 * s, 0) * CFrame.Angles(0, k * math.pi / 6, 0),
            Color = (k % 2 == 0) and CANVAS or CANVAS2, Material = M.SmoothPlastic })
    end
    P(parent, { Size = Vector3.new(2.6, 1.8, 2.6) * s, CFrame = cf * CFrame.new(0, 0.9 * s, 0), Color = C3(150, 110, 70), Material = M.WoodPlanks })
    for _, sx in ipairs({ -1, 1 }) do
        for _, sz in ipairs({ -1, 1 }) do
            K.Beam(parent, (cf * CFrame.new(sx * 1.2 * s, 1.8 * s, sz * 1.2 * s)).Position, (cf * CFrame.new(sx * 2.6 * s, 5.4 * s, sz * 2.6 * s)).Position, 0.1 * s, C3(80, 70, 60), M.SmoothPlastic)
        end
    end
end
local function Airship(parent, cf, s)
    -- (UPDATE 4: a real model when the place has it -- WorldProps.Sky.Airship, pivot at its middle, length along Z)
    if K.Prop(parent, "Sky", "Airship", cf, s) then return end
    -- a long cigar envelope with fins, a gondola slung under it, a turning propeller
    P(parent, { Shape = Enum.PartType.Ball, Size = Vector3.new(14, 14, 50) * s, CFrame = cf, Color = CANVAS, Material = M.SmoothPlastic })
    for k = -1, 1 do P(parent, { Size = Vector3.new(14.2 * s, 0.8 * s, 1 * s), CFrame = cf * CFrame.new(0, 0, k * 12 * s), Color = BRASS, Material = M.Metal }) end
    for k = 0, 3 do
        P(parent, { Class = "WedgePart", Size = Vector3.new(0.6, 7, 8) * s, CFrame = cf * CFrame.Angles(0, 0, k * math.pi / 2) * CFrame.new(0, 6.5 * s, 22 * s) * CFrame.Angles(0, math.pi, 0), Color = CANVAS2, Material = M.SmoothPlastic })
    end
    P(parent, { Size = Vector3.new(5, 3.4, 16) * s, CFrame = cf * CFrame.new(0, -9.5 * s, 0), Color = DECK, Material = M.WoodPlanks })
    for k = -1, 1, 2 do K.Beam(parent, (cf * CFrame.new(0, -7.8 * s, k * 6 * s)).Position, (cf * CFrame.new(0, -5 * s, k * 6 * s)).Position, 0.3 * s, IRON, M.Metal) end
end

W.Props = {
    Cover = { function(geo, _, rng, pos) Cargo(geo, CFrame.new(pos) * K.Yaw(rng), 1) end, function(geo, _, rng, pos) Boiler(geo, CFrame.new(pos) * K.Yaw(rng), 0.9) end },
    Tall = { function(geo, _, rng, pos) GearStand(geo, CFrame.new(pos) * K.Yaw(rng), 1) end, function(geo, _, rng, pos) Lamp(geo, CFrame.new(pos), 1, false) end },
    Air = {},
}
W.Landmarks = {
    function(geo, _, rng, c) -- THE GEARWORKS: standing gears facing the plaza, lamps between them
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            local p = c + Vector3.new(math.cos(a) * 31, 0, math.sin(a) * 31)
            GearStand(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)) * CFrame.Angles(0, math.rad(90), 0), 1)
            Lamp(geo, CFrame.new(c + Vector3.new(math.cos(a + 0.6) * 33, 0, math.sin(a + 0.6) * 33)), 1, i == 0)
        end
    end,
    function(geo, _, rng, c) -- THE BOILER ROOM: boilers round the plaza, cargo between them
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            Boiler(geo, CFrame.lookAt(c + Vector3.new(math.cos(a) * 31, 0, math.sin(a) * 31), c), 1)
            Cargo(geo, CFrame.new(c + Vector3.new(math.cos(a + 0.7) * 33, 0, math.sin(a + 0.7) * 33)) * CFrame.Angles(0, a, 0), 0.9)
        end
    end,
}
W.Kits = {
    SyGear = function(g, cf, s) GearStand(g, cf, s * 0.55) end,
    SyBoiler = function(g, cf, s) Boiler(g, cf, s * 0.55) end,
    SyCargo = function(g, cf, s) Cargo(g, cf, s * 0.6) end,
    SyLamp = function(g, cf, s) Lamp(g, cf, s * 0.55, false) end,
    SyClock = function(g, cf, s) ClockTower(g, cf, s * 0.5) end,
    SyBalloon = function(g, cf, s) Balloon(g, cf * CFrame.new(0, 4 * s, 0), s * 0.6) end,
}
W.Templates = {
    { Name = "Dockyard", Rim = "Edge", RimMat = { M.WoodPlanks, M.Brick }, Ground = M.WoodPlanks, Patch = { M.Brick, M.Slate },
        Edge = { "SyCargo", "SyBoiler", "SyLamp" }, RimKit = { "SyBalloon", "SyCargo", "SyLamp" }, Hero = "SyAirships", Glow = { SyLamp = LAMP } },
    { Name = "Clockworks", Rim = "Edge", RimMat = { M.Brick, M.Slate }, Ground = M.Brick, Patch = { M.WoodPlanks, M.Slate },
        Edge = { "SyGear", "SyBoiler", "SyCargo" }, RimKit = { "SyClock", "SyGear", "SyBalloon" }, Hero = "SyAirships" },
    { Name = "Balloon Port", Rim = "Edge", RimMat = { M.WoodPlanks, M.Slate }, Ground = M.WoodPlanks, Patch = { M.Slate, M.Brick },
        Edge = { "SyLamp", "SyCargo", "SyGear" }, RimKit = { "SyBalloon", "SyBalloon", "SyClock" }, Hero = "SyAirships", Glow = { SyLamp = LAMP } },
}
W.Heroes = {}
function W.Heroes.SyAirships(fx, ctx)
    -- airships cruising slowly past beyond the edge (client), a far floating district on its rock
    local ships = {}
    for k = 1, 3 do
        local m = K.Model(fx, "Airship")
        Airship(m, CFrame.new(), 2.2 + k * 0.6)
        table.insert(ships, { M = m, R = ctx.half * (2 + k * 0.7), H = 60 + k * 30, Sp = 0.02 + k * 0.006, Ph = k * 2.1 })
    end
    local function Place(t)
        for _, sh in ipairs(ships) do
            local a = t * sh.Sp + sh.Ph
            local pos = Vector3.new(math.cos(a) * sh.R, sh.H, ctx.zC + math.sin(a) * sh.R)
            sh.M:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a))))
        end
    end
    Place(0)
    K.Live(fx, Place)
    -- a floating district: a rock with a few buildings and a tower
    local c = Vector3.new(80, 40, ctx.zC + ctx.half * 3.4)
    -- (UPDATE 4: the real floating island (grass top at 0.68 of its height, measured) with the clock tower and a moored
    -- balloon on it; the part rock + blocks are the fallback)
    if K.Far(fx, "Sky", "Island", CFrame.new(c - Vector3.new(0, 102, 0)) * CFrame.Angles(0, 0.7, 0), 5) then
        K.Far(fx, "Sky", "ClockTower", CFrame.new(c + Vector3.new(-26, -3, 8)) * CFrame.Angles(0, 0.3, 0), 3.2)
        K.Far(fx, "Sky", "Balloon", CFrame.new(c + Vector3.new(30, 6, -18)), 2.2)
        return
    end
    P(fx, { Class = "WedgePart", Size = Vector3.new(140, 60, 60), CFrame = CFrame.new(c + Vector3.new(0, -30, -30)) * CFrame.Angles(math.pi, 0, 0), Color = C3(110, 96, 86), Material = M.Rock })
    P(fx, { Class = "WedgePart", Size = Vector3.new(140, 60, 60), CFrame = CFrame.new(c + Vector3.new(0, -30, 30)) * CFrame.Angles(math.pi, math.pi, 0), Color = C3(96, 84, 76), Material = M.Rock })
    P(fx, { Size = Vector3.new(140, 6, 120), CFrame = CFrame.new(c), Color = C3(90, 120, 70), Material = M.Grass })
    local m = K.Model(fx, "District")
    ClockTower(m, CFrame.new(c + Vector3.new(0, 3, 0)), 3.5)
    for k = -1, 1, 2 do P(m, { Size = Vector3.new(30, 24, 26), CFrame = CFrame.new(c + Vector3.new(k * 40, 15, 10)), Color = BRICK, Material = M.Brick }) end
    K.NoCollide(m)
end
W.Vista = { Ground = C3(230, 230, 240), GroundMat = M.SmoothPlastic, Peak = C3(220, 224, 236), PeakMat = M.SmoothPlastic, Tip = C3(255, 255, 255) }
function W.VistaFn(fx, Pf, centre, gy, zC, r)
    -- the cloud sea below: soft particle banks (like the Dreamscape's) + floating rocks in the distance (no ground plane:
    -- the painted sky's cloud sea shows under the islands)
    -- (UPDATE 4 VISTA: real models to the horizon -- WorldKit.Far props + tinted scanned mountains; the part version
    -- below stays as the fallback for an unsaved place)
    if K.HasProp("Sky", "Island") then
        for _ = 1, 8 do -- floating islands at every height
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(450, 1000)
            K.Far(fx, "Sky", "Island", CFrame.new(centre + Vector3.new(math.cos(a) * d, r:NextNumber(10, 160), math.sin(a) * d)) * CFrame.Angles(0, r:NextNumber(0, 6.28), 0), r:NextNumber(2.5, 5))
        end
        for _ = 1, 4 do -- moored balloons drifting off the docks
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(260, 600)
            K.Far(fx, "Sky", "Balloon", CFrame.new(centre + Vector3.new(math.cos(a) * d, r:NextNumber(30, 110), math.sin(a) * d)), r:NextNumber(1.6, 2.4))
        end
        return true
    end
    local g = fx:FindFirstChild("VistaGround")
    if g then g:Destroy() end
    for _ = 1, 14 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(300, 1000)
        local slab = Pf({ Name = "CloudSea", Size = Vector3.new(280, 20, 280), CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * d, r:NextNumber(-60, -30), math.sin(a) * d)), Transparency = 1 })
        local e = K.Emit(slab, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(255, 252, 246), C3(236, 236, 246)),
            Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 90), NumberSequenceKeypoint.new(1, 110) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.1), NumberSequenceKeypoint.new(0.8, 0.1), NumberSequenceKeypoint.new(1, 1) }),
            Lifetime = NumberRange.new(40, 50), Rate = 0.2, Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 20), LightEmission = 0.1, LightInfluence = 0.5 })
        if K.IS_CLIENT then
            task.spawn(function()
                for _ = 1, 60 do
                    if slab:IsDescendantOf(workspace) then e:Emit(9) return end
                    task.wait(0.1)
                end
            end)
        end
    end
    for _ = 1, 8 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(500, 1000)
        local sz = r:NextNumber(40, 90)
        local p = centre + Vector3.new(math.cos(a) * d, r:NextNumber(20, 140), math.sin(a) * d)
        Pf({ Name = "FarRock", Size = Vector3.new(sz, sz * 0.2, sz), CFrame = CFrame.new(p), Color = C3(100, 126, 80), Material = M.Grass })
        Pf({ Name = "FarRockUnder", Size = Vector3.one * sz * 0.6, CFrame = CFrame.new(p - Vector3.new(0, sz * 0.3, 0)) * CFrame.Angles(math.rad(45), r:NextNumber(0, 6), math.rad(35)), Color = C3(110, 96, 86), Material = M.Rock })
    end
    return true
end
function W.Scenery(fx, theme, rng, zC, arena, height)
    -- wisps of cloud blowing across the room, brass sparks from the works (client: a slow gear turning overhead)
    local src = K.Box(fx, Vector3.new(4, 20, arena), CFrame.new(-arena / 2, 18, zC))
    K.Emit(src, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(255, 255, 255)), Rate = 2, Lifetime = NumberRange.new(10, 14),
        Speed = NumberRange.new(8, 12), SpreadAngle = Vector2.new(5, 5), Size = NumberSequence.new(12, 24), Transparency = NumberSequence.new(0.8, 1),
        EmissionDirection = Enum.NormalId.Right, LightEmission = 0.1 })
    local g = K.Life(fx, "Sky", "Gear", 2.8) -- (UPDATE 4 LIFE: the real brass cogwheel, r 14; the part gear is the fallback)
    if not g then g = K.Model(fx, "SkyGear"); Gear(g, CFrame.new(), 14, 2, BRASS, 18) end
    local pivot = CFrame.new(-arena * 0.62, 34, zC + arena * 0.2) * CFrame.Angles(0, math.rad(90), 0)
    g:PivotTo(pivot)
    K.Live(fx, function(t) g:PivotTo(pivot * CFrame.Angles(0, 0, t * 0.15)) end)
end
function W.SetPiece(geo, deco, c, rng, F)
    -- THE GRAND GEAR: boilers and lamps round the fight floor, a giant gear turning over the far side
    K.Ring(12, 100, c + Vector3.new(0, F, 0), function(p, a, i)
        if i % 2 == 0 then Boiler(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1.4) else Lamp(geo, CFrame.new(p), 1.6, i == 3) end
    end)
    local m = K.Life(deco, "Sky", "Gear", 6.8) -- (UPDATE 4 LIFE: the real cogwheel, r 34)
    if not m then m = K.Model(deco, "GrandGear"); Gear(m, CFrame.new(c + Vector3.new(0, F + 50, 150)), 34, 4, BRASS, 24) end
    K.Live(deco, function(t) m:PivotTo(CFrame.new(c + Vector3.new(0, F + 50, 150)) * CFrame.Angles(0, 0, t * 0.1)) end)
    local front = m:IsA("Model") and m.Name == "LifeGear" and (select(2, m:GetBoundingBox()).Z / 2 + 1) or 4 -- (the hub lamp sits on the gear's face)
    local hub = Neon(deco, Vector3.new(6, 6, 6), CFrame.new(c + Vector3.new(0, F + 50, 150 - front)), LAMP, 0.1, Enum.PartType.Ball)
    K.Light(hub, LAMP, 70, 1.0)
    return BRASS
end

W.Theme = {
    Name = "Brass Skyport",
    Floor = { Color = DECK, Material = M.WoodPlanks },
    FloorAlt = { Color = C3(120, 120, 124), Material = M.DiamondPlate },
    Wall = { Color = BRICK, Material = M.Brick },
    WallTrim = { Color = BRASS, Material = M.Metal },
    Ceiling = { Color = C3(70, 60, 56), Material = M.WoodPlanks },
    Prop = { Color = DECK2, Material = M.WoodPlanks },
    PropAlt = { Color = COPPER, Material = M.Metal },
    Hazard = { Color = C3(230, 230, 230), Material = M.Glass, Transparency = 0.4 },
    Accent = BRASS, Light = C3(255, 228, 180), LampBrightness = 1.3, LampRange = 52,
    OpenSky = true,
}
W.Ambience = { Mote = C3(255, 240, 210), Mote2 = BRASS, MoteRise = false, Glow = LAMP }
W.Light = { ClockTime = 14.5, Brightness = 2.4, Ambient = C3(150, 146, 140), OutdoorAmbient = C3(170, 170, 180),
    FogColor = C3(220, 226, 236), FogStart = 260, FogEnd = 1200, Exposure = 0.1, EnvDiffuse = 0.4,
    BloomIntensity = 0.3, BloomThreshold = 1.4, BloomSize = 20,
    CCBrightness = 0, CCContrast = 0.1, CCSaturation = 0.06, CCTint = C3(255, 248, 238) }
W.Atmo = { 0.26, C3(240, 236, 226), C3(170, 190, 220), 1.0, 0.5 }
W.Terrain = { [M.WoodPlanks] = C3(128, 96, 64), [M.Brick] = C3(140, 86, 68), [M.Slate] = C3(100, 96, 96), [M.Concrete] = C3(120, 120, 124) }
-- (UPDATE 4 wrap-up, RoomGen.DressFor: the room pieces in this world's own language -- brick dock piers (no more plank blocks), a brass lamp post on each)
W.Cover = { Built = true, Stone = M.Brick, Crown = { World = "Sky", Name = "Lamp", Fit = 0.35, MaxH = 7, Alt = { "GearStand", "Boiler" } } }
W.Contrast = C3(255, 50, 120)
W.EA = { Warn = C3(255, 70, 40), Core = C3(255, 236, 190), Mat = M.Neon }
W.Moods = {
    { Id = "Clear", W = 3 },
    { Id = "Sunset", Name = "Copper Sunset", W = 2, Acc = 0.07, Fog = C3(255, 170, 110), FogAmt = 0.34, Clock = 3.0 },
    { Id = "Storm", Name = "Squall Front", W = 2, Sat = 0.8, Fog = C3(150, 160, 176), FogAmt = 0.4, Dens = 1.3, Exp = -0.04 },
    { Id = "Dawn", Name = "Dawn Patrol", W = 1, Fog = C3(250, 200, 200), FogAmt = 0.3, Clock = -6.5 },
}
W.Sky = { Bk = "112110449097559", Dn = "72821338550546", Ft = "95531551017418", Lf = "120123978157904", Rt = "118982200955173", Up = "96453682649580" } -- (UPDATE 4 SKIES v4: tools/hdri_sky.py)
return W
