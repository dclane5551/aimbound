--!nocheck
-- HAUNTED BAYOU (0.87 world): a swamp at night -- bald cypress trees draped in hanging moss, shacks on stilts with a lit
-- window, rowboats, rickety docks, carved totems with glowing eyes, lanterns of green flame; thick green fog, will-o'-the-
-- wisps drifting, fireflies. Sister: Void.
local K = require(script.Parent.Parent:WaitForChild("WorldKit"))
local C3, M = K.C3, K.M
local P, Solid, Deco, Neon, Wedge = K.P, K.Solid, K.Deco, K.Neon, K.Wedge

local MUD, BARK, BARK2, MOSS, MOSS2 = C3(58, 60, 42), C3(64, 54, 44), C3(52, 46, 38), C3(110, 120, 90), C3(86, 100, 70)
local WOOD, WOOD2, WISP, WISP2, WINDOW = C3(96, 80, 60), C3(76, 64, 50), C3(160, 255, 140), C3(120, 230, 255), C3(255, 200, 110)

local W = {}
W.Id = "Bayou"
W.Title = "HAUNTED BAYOU"
W.TitleColor = C3(150, 240, 130)
W.Sister = "Void"
W.HazardName = "Black Water"

-- (UPDATE 4 prop pass: real textured models from ReplicatedStorage.WorldProps.Bayou via WorldKit.Prop when the place has
-- them; the part build under each is the fallback. Gameplay boxes measured from the models' height maps.)
local function Cypress(geo, cf, s)
    if K.Prop(geo, "Bayou", "Cypress", cf, s, { { Vector3.new(2.4, 15, 2.4), Vector3.new(0, 7.5, 0) } }) then return end
    -- a bald cypress: a flared buttressed base, a tall trunk, a flat ragged crown, long curtains of hanging moss
    for k = 0, 3 do
        Wedge(geo, Vector3.new(0.8 * s, 3 * s, 2.4 * s), cf * CFrame.Angles(0, k * math.pi / 2 + 0.3, 0) * CFrame.new(0, 1.5 * s, -1.6 * s), BARK2, M.Wood)
    end
    K.Pillar(geo, 1.8 * s, 15 * s, cf, BARK, M.Wood, true)
    local top = cf * CFrame.new(0, 15 * s, 0)
    for k = 0, 2 do
        local a = k * 2.1
        Deco(geo, Vector3.new(7, 2.4, 6) * s, top * CFrame.new(math.cos(a) * 2.4 * s, k * 0.7 * s, math.sin(a) * 2.4 * s), (k % 2 == 0) and MOSS2 or C3(64, 80, 54), M.Grass, Enum.PartType.Ball)
    end
    for k = 0, 9 do
        local a = k / 10 * math.pi * 2
        local len = (3 + (k * 7 % 5)) * s
        Deco(geo, Vector3.new(0.5 * s, len, 0.2 * s), top * CFrame.new(math.cos(a) * 3.6 * s, -len / 2, math.sin(a) * 3.6 * s) * CFrame.Angles(0, a, 0), MOSS, M.Grass, nil, 0.1)
    end
end
local function Shack(geo, cf, s, lit)
    if K.Prop(geo, "Bayou", "Shack", cf, s, { { Vector3.new(7, 0.4, 6), Vector3.new(0, 3, 0) }, { Vector3.new(5.4, 4, 4.2), Vector3.new(0.4, 5.2, 0.6) } }) then
        if lit then K.Light(K.Box(geo, Vector3.new(0.4, 0.4, 0.4) * s, cf * CFrame.new(0, 5.4 * s, -1.2 * s)), WINDOW, 22, 1.0) end -- (the warm window light)
        return
    end
    -- a plank shack on stilts: a porch, a tin roof, a window glowing warm, a ladder down
    local floorY = 3 * s
    for _, sx in ipairs({ -1, 1 }) do
        for _, sz in ipairs({ -1, 1 }) do Solid(geo, Vector3.new(0.5 * s, floorY + 0.5 * s, 0.5 * s), cf * CFrame.new(sx * 2.8 * s, floorY / 2, sz * 2.4 * s), WOOD2, M.Wood) end
    end
    Solid(geo, Vector3.new(7 * s, 0.4 * s, 6 * s), cf * CFrame.new(0, floorY, 0), WOOD, M.WoodPlanks)
    Solid(geo, Vector3.new(5.4 * s, 4 * s, 4.2 * s), cf * CFrame.new(0.4 * s, floorY + 2.2 * s, 0.6 * s), WOOD2, M.WoodPlanks)
    for _, sz in ipairs({ -1, 1 }) do
        Wedge(geo, Vector3.new(6.4 * s, 1.6 * s, 2.6 * s), cf * CFrame.new(0.4 * s, floorY + 5 * s, 0.6 * s + sz * 1.3 * s) * CFrame.Angles(0, (sz < 0) and 0 or math.pi, 0), C3(110, 90, 80), M.CorrodedMetal)
    end
    local win = Neon(geo, Vector3.new(1.4 * s, 1.2 * s, 0.1), cf * CFrame.new(-0.6 * s, floorY + 2.6 * s, -1.52 * s), WINDOW, 0.15)
    for k = 0, 3 do Deco(geo, Vector3.new(1.2 * s, 0.15 * s, 0.15 * s), cf * CFrame.new(-2.9 * s, (k + 0.6) * 0.8 * s, -3 * s), WOOD2, M.Wood) end
    if lit then K.Light(win, WINDOW, 22, 1.0) end
end
local function Boat(geo, cf, s)
    if K.Prop(geo, "Bayou", "Boat", cf, s, { { Vector3.new(3.6, 1.4, 8), Vector3.new(0.1, 0.7, 0.2) } }) then return end
    -- an old rowboat pulled up on the mud (cover), oars across it
    Solid(geo, Vector3.new(2.6 * s, 1.2 * s, 7 * s), cf * CFrame.new(0, 0.6 * s, 0), WOOD, M.WoodPlanks)
    Wedge(geo, Vector3.new(2.6 * s, 1.2 * s, 1.8 * s), cf * CFrame.new(0, 0.6 * s, -4.4 * s) * CFrame.Angles(0, math.pi, 0), WOOD, M.WoodPlanks, true)
    Deco(geo, Vector3.new(2.2 * s, 0.2 * s, 6.4 * s), cf * CFrame.new(0, 1.15 * s, 0), C3(40, 50, 40), M.SmoothPlastic)
    Deco(geo, Vector3.new(0.2 * s, 0.2 * s, 6 * s), cf * CFrame.new(0.5 * s, 1.4 * s, 0) * CFrame.Angles(0, 0.4, 0), WOOD2, M.Wood)
end
local function Dock(geo, cf, s)
    if K.Prop(geo, "Bayou", "Dock", cf, s, { { Vector3.new(3.4, 2, 5.2), Vector3.new(-0.2, 1, -0.1) } }) then return end
    -- a rickety plank dock on posts, one plank missing, a lantern post at the end
    for k = -2, 2 do
        if k ~= 1 then Solid(geo, Vector3.new(1.4 * s, 0.3 * s, 4 * s), cf * CFrame.new(k * 1.5 * s, 1.6 * s, 0) * CFrame.Angles(0, 0, math.rad(k * 1.5)), WOOD, M.WoodPlanks) end
    end
    for _, x in ipairs({ -3.6, 3.6 }) do
        for _, z in ipairs({ -1.6, 1.6 }) do Solid(geo, Vector3.new(0.5 * s, 2.6 * s, 0.5 * s), cf * CFrame.new(x * s, 1.1 * s, z * s), WOOD2, M.Wood) end
    end
    Deco(geo, Vector3.new(0.3 * s, 4 * s, 0.3 * s), cf * CFrame.new(3.6 * s, 3.6 * s, 1.6 * s), WOOD2, M.Wood)
    Neon(geo, Vector3.new(0.7, 0.9, 0.7) * s, cf * CFrame.new(3.6 * s, 5.4 * s, 1.6 * s), WISP, 0.15)
end
local function Totem(geo, cf, s, lit)
    if K.Prop(geo, "Bayou", "Totem", cf, s, { { Vector3.new(2.4, 8, 2.6), Vector3.new(0, 4, 0.1) } }) then
        if lit then K.Light(K.Box(geo, Vector3.new(0.3, 0.3, 0.3) * s, cf * CFrame.new(0, 6.4 * s, -1.4 * s)), WISP, 20, 0.9) end
        return
    end
    -- a carved totem: stacked masks with glowing hollow eyes, feathers and bones tied at the top
    for k = 0, 2 do
        local m = cf * CFrame.new(0, (1.3 + k * 2.4) * s, 0)
        Solid(geo, Vector3.new(1.9 * s, 2.3 * s, 1.9 * s), m, (k % 2 == 0) and WOOD or BARK, M.Wood)
        for _, sx in ipairs({ -1, 1 }) do
            local e = Neon(geo, Vector3.new(0.4 * s, 0.3 * s, 0.1), m * CFrame.new(sx * 0.45 * s, 0.3 * s, -0.96 * s), (k == 2) and WISP2 or WISP, 0)
            if lit and k == 2 and sx > 0 then K.Light(e, WISP, 20, 0.9) end
        end
        Deco(geo, Vector3.new(1.0 * s, 0.3 * s, 0.2 * s), m * CFrame.new(0, -0.5 * s, -0.98 * s), C3(20, 20, 16), M.SmoothPlastic)
    end
    for k = 0, 2 do
        Wedge(geo, Vector3.new(0.15 * s, 1.6 * s, 0.6 * s), cf * CFrame.new(0, 7.9 * s, 0) * CFrame.Angles(0, k * 1.1, math.rad((k - 1) * 25)) * CFrame.new(0, 0.6 * s, 0), C3(200, 200, 190), M.SmoothPlastic)
    end
end

W.Props = {
    Cover = { function(geo, _, rng, pos) Boat(geo, CFrame.new(pos) * K.Yaw(rng), 1) end, function(geo, _, rng, pos) Dock(geo, CFrame.new(pos) * K.Yaw(rng), 1) end },
    Tall = { function(geo, _, rng, pos) Cypress(geo, CFrame.new(pos) * K.Yaw(rng), 0.9) end, function(geo, _, rng, pos) Totem(geo, CFrame.new(pos) * K.Yaw(rng), 1, false) end },
    Air = {},
}
W.Landmarks = {
    function(geo, _, rng, c) -- THE CYPRESS RING: moss-hung trees round the plaza, a totem among them
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2 + 0.3
            local p = c + Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32)
            if i == 3 then Totem(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1.2, true) else Cypress(geo, CFrame.new(p) * CFrame.Angles(0, a, 0), 0.85) end
        end
    end,
    function(geo, _, rng, c) -- FISHING CAMP: a shack on stilts, docks and boats round the plaza
        Shack(geo, CFrame.lookAt(c + Vector3.new(-32, 0, 6), c), 1, true)
        for i = 0, 2 do
            local a = i * 1.2 - 0.6
            Dock(geo, CFrame.lookAt(c + Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32), c), 1)
        end
        Boat(geo, CFrame.new(c + Vector3.new(4, 0, -33)) * CFrame.Angles(0, 1.3, 0), 1)
    end,
}
W.Kits = {
    ByCypress = function(g, cf, s) Cypress(g, cf, s * 0.6) end,
    ByShack = function(g, cf, s) Shack(g, cf, s * 0.55, false) end,
    ByBoat = function(g, cf, s) Boat(g, cf, s * 0.6) end,
    ByDock = function(g, cf, s) Dock(g, cf, s * 0.55) end,
    ByTotem = function(g, cf, s) Totem(g, cf, s * 0.55, false) end,
}
W.Templates = {
    { Name = "Cypress Swamp", Rim = "Ruins", RimMat = { M.Mud, M.Grass }, Ground = M.Mud, Patch = { M.Grass, M.Ground },
        Edge = { "ByBoat", "ByDock", "ByTotem" }, RimKit = { "ByCypress", "ByCypress", "ByShack" }, Hero = "ByWillow" },
    { Name = "Stilt Village", Rim = "Ruins", RimMat = { M.Mud, M.Ground }, Ground = M.Ground, Patch = { M.Mud, M.WoodPlanks },
        Edge = { "ByDock", "ByBoat" }, RimKit = { "ByShack", "ByCypress", "ByDock" }, Hero = "ByWillow" },
    { Name = "Witch's Hollow", Rim = "Cliffs", RimMat = { M.Rock, M.Mud }, RimAccent = M.Grass, PartyRim = "ByCypress", Ground = M.Mud, Patch = { M.Grass, M.Rock },
        Edge = { "ByTotem", "ByBoat" }, RimKit = { "ByCypress", "ByTotem" }, Hero = "ByWillow" },
}
W.Heroes = {}
function W.Heroes.ByWillow(fx, ctx)
    -- a vast dead cypress on the far side, a shack lit in its roots, will-o'-the-wisps circling it (client)
    local c = Vector3.new(-40, 0, ctx.zC + ctx.half * 3.1)
    local m = K.Model(fx, "HeroCypress")
    Cypress(m, CFrame.new(c), 6)
    Shack(m, CFrame.new(c + Vector3.new(30, 0, -26)) * CFrame.Angles(0, 0.6, 0), 2.4, false)
    K.NoCollide(m)
    local wisps = {}
    for k = 1, 5 do table.insert(wisps, { P = P(fx, { Shape = Enum.PartType.Ball, Size = Vector3.one * 3, Color = WISP, Material = M.Neon }), Ph = k * 1.3 }) end
    K.Live(fx, function(t)
        for _, w in ipairs(wisps) do
            local a = t * 0.3 + w.Ph
            w.P.CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 40, 50 + math.sin(t * 0.8 + w.Ph) * 12, math.sin(a) * 40))
        end
    end)
end
W.Vista = { Ground = C3(30, 38, 30), GroundMat = M.Mud, Peak = C3(30, 36, 30), PeakMat = M.Mud, Tip = MOSS }
function W.VistaFn(fx, Pf, centre, gy, zC, r)
    -- black water stretching away (a dark glassy plane just over the ground) and dead cypress stands in the fog
    -- (UPDATE 4 VISTA: real models to the horizon -- WorldKit.Far props + tinted scanned mountains; the part version
    -- below stays as the fallback for an unsaved place)
    if K.HasProp("Bayou", "Cypress") then
        Pf({ Name = "BlackWater", Size = Vector3.new(3000, 0.4, 3000), CFrame = CFrame.new(centre + Vector3.new(0, 0.6, 0)), Color = C3(16, 24, 20), Material = M.Glass, Reflectance = 0.15, Transparency = 0.1 })
        for _ = 1, 22 do -- dead cypress stands in the fog
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(200, 900)
            K.Far(fx, "Bayou", "Cypress", CFrame.new(centre + Vector3.new(math.cos(a) * d, -1, math.sin(a) * d)) * CFrame.Angles(0, r:NextNumber(0, 6.28), 0), 1.4 + d / 450)
        end
        for _ = 1, 2 do -- a far shack on its stilts
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(350, 650)
            local p = centre + Vector3.new(math.cos(a) * d, -1, math.sin(a) * d)
            K.Far(fx, "Bayou", "Shack", CFrame.lookAt(p, Vector3.new(centre.X, p.Y, centre.Z)), r:NextNumber(2, 2.8))
        end
        return true
    end
    Pf({ Name = "BlackWater", Size = Vector3.new(3000, 0.4, 3000), CFrame = CFrame.new(centre + Vector3.new(0, 0.6, 0)), Color = C3(16, 24, 20), Material = M.Glass, Reflectance = 0.15, Transparency = 0.1 })
    for _ = 1, 40 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(200, 900)
        local h = r:NextNumber(40, 90)
        local p = centre + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
        Pf({ Name = "FarCypress", Size = Vector3.new(4, h, 4), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)), Color = C3(26, 30, 24), Material = M.Wood })
        Pf({ Name = "FarCrown", Shape = Enum.PartType.Ball, Size = Vector3.new(h * 0.4, h * 0.12, h * 0.4), CFrame = CFrame.new(p + Vector3.new(0, h, 0)), Color = C3(30, 40, 30), Material = M.Grass })
    end
    return true
end
function W.Scenery(fx, theme, rng, zC, arena, height)
    -- low green fog over the mud, fireflies, a few will-o'-the-wisps drifting through the room (client)
    local low = K.Box(fx, Vector3.new(arena, 1, arena), CFrame.new(0, 2.5, zC))
    K.Emit(low, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(130, 170, 120)), Rate = 6, Lifetime = NumberRange.new(8, 11),
        Speed = NumberRange.new(0.4, 1.2), SpreadAngle = Vector2.new(180, 5), Size = NumberSequence.new(8, 16), Transparency = NumberSequence.new(0.85, 1),
        EmissionDirection = Enum.NormalId.Top, LightEmission = 0.05 })
    local ff = K.Box(fx, Vector3.new(arena, 1, arena), CFrame.new(0, 6, zC))
    K.Emit(ff, { Color = ColorSequence.new(C3(220, 255, 120)), LightEmission = 1, Rate = 10, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(0.3, 1),
        SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 0) }) })
    local wisps = {}
    for i = 1, 5 do
        local w = Neon(fx, Vector3.one * 0.9, CFrame.new(), (i % 2 == 0) and WISP2 or WISP, 0.1, Enum.PartType.Ball)
        table.insert(wisps, { P = w, C = Vector3.new(rng:NextNumber(-arena * 0.4, arena * 0.4), rng:NextNumber(28, 44), zC + rng:NextNumber(-arena * 0.4, arena * 0.4)), Ph = rng:NextNumber(0, 6) }) -- (above the fight)
    end
    K.Live(fx, function(t)
        for _, w in ipairs(wisps) do
            w.P.CFrame = CFrame.new(w.C + Vector3.new(math.sin(t * 0.4 + w.Ph) * 10, math.sin(t * 1.1 + w.Ph) * 2, math.cos(t * 0.33 + w.Ph) * 10))
            w.P.Transparency = 0.1 + (math.sin(t * 2.3 + w.Ph) * 0.5 + 0.5) * 0.5
        end
    end)
end
function W.SetPiece(geo, deco, c, rng, F)
    -- THE DROWNED GROVE: cypress and totems round the fight floor, a great dead tree with a glowing hollow over the far side
    K.Ring(12, 100, c + Vector3.new(0, F, 0), function(p, a, i)
        if i % 3 == 1 then Totem(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1.8, i == 4) else Cypress(geo, CFrame.new(p) * CFrame.Angles(0, a, 0), 1.4) end
    end)
    local m = K.Model(deco, "BossCypress")
    if K.HasProp("Bayou", "Cypress") then
        -- (UPDATE 4: the real cypress, 114 tall, its roots hidden behind the rim hills so the crown rises over them
        -- (seen in play: at floor level and x4.5 the hills hid it whole); the hollow's light stays where it was)
        Cypress(m, CFrame.new(c + Vector3.new(0, F + 30, 185)), 6)
        K.NoCollide(m)
        K.Light(K.Box(deco, Vector3.new(1, 1, 1), CFrame.new(c + Vector3.new(0, F + 18, 160))), WISP, 60, 1.0)
        return WISP
    end
    Cypress(m, CFrame.new(c + Vector3.new(0, F, 165)), 4.5)
    K.NoCollide(m)
    local hollow = Neon(deco, Vector3.new(8, 12, 2), CFrame.new(c + Vector3.new(0, F + 18, 160)), WISP, 0.1)
    K.Light(hollow, WISP, 60, 1.0)
    return WISP
end

W.Theme = {
    Name = "Haunted Bayou",
    Floor = { Color = MUD, Material = M.Mud },
    FloorAlt = { Color = WOOD, Material = M.WoodPlanks },
    Wall = { Color = BARK, Material = M.Wood },
    WallTrim = { Color = WOOD2, Material = M.WoodPlanks },
    Ceiling = { Color = C3(30, 36, 30), Material = M.Mud },
    Prop = { Color = WOOD, Material = M.WoodPlanks },
    PropAlt = { Color = MOSS, Material = M.Grass },
    Hazard = { Color = C3(20, 34, 28), Material = M.Glass, Transparency = 0.2 },
    Accent = WISP, Light = C3(200, 255, 180), LampBrightness = 1.2, LampRange = 50,
    OpenSky = true,
}
W.Ambience = { Mote = C3(220, 255, 120), Mote2 = WISP2, MoteRise = true, Glow = WISP }
W.Light = { ClockTime = 13, Brightness = 0.6, -- (0.89: a night clock dims the skybox -- the painted night sky never showed; day clock + a dim sun)
    -- (UPDATE 4 LIGHTING AUDIT: gun slide L35 -> L55, still a haunted night)
    Ambient = C3(153, 182, 151), OutdoorAmbient = C3(155, 188, 158),
    FogColor = C3(62, 86, 68), FogStart = 90, FogEnd = 520, Exposure = 1.02, EnvDiffuse = 0.35,
    BloomIntensity = 0.55, BloomThreshold = 1.05, BloomSize = 24,
    CCBrightness = 0, CCContrast = 0.14, CCSaturation = -0.05, CCTint = C3(232, 255, 236) }
W.Atmo = { 0.46, C3(90, 120, 96), C3(30, 46, 36), 2.6, 0 }
W.Terrain = { [M.Mud] = C3(58, 60, 42), [M.Grass] = C3(70, 84, 54), [M.Ground] = C3(64, 60, 46), [M.Rock] = C3(70, 72, 62), [M.WoodPlanks] = C3(96, 80, 60) }
-- (UPDATE 4 wrap-up, RoomGen.DressFor: the room pieces in this world's own language -- the timber piers keep their wood, a mask post on top)
W.Cover = { Crown = { World = "Bayou", Name = "Totem", Fit = 0.45, MaxH = 8, Alt = { "Shack", "Dock" } } }
W.Contrast = C3(255, 120, 220)
W.EA = { Warn = C3(255, 60, 200), Core = C3(255, 220, 250), Mat = M.ForceField }
W.Moods = {
    { Id = "Gloom", W = 3 },
    { Id = "Ghostlight", Name = "Ghostlight", W = 2, Acc = 0.53, Fog = C3(60, 110, 130), FogAmt = 0.36 },
    { Id = "Harvest", Name = "Witch Moon", W = 2, Acc = 0.08, Fog = C3(120, 90, 50), FogAmt = 0.34, Exp = 0.02 },
    { Id = "Drowned", Name = "Drowned Night", W = 1, Val = 0.85, Fog = C3(20, 34, 30), FogAmt = 0.42, Dens = 1.3, Exp = -0.06 },
}
W.Sky = { Bk = "122780570132684", Dn = "131952355890783", Ft = "70642118218398", Lf = "109592252122206", Rt = "101378684212195", Up = "107927784813492" } -- (UPDATE 4 SKIES v4: tools/hdri_sky.py)
return W
