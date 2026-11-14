--!nocheck
-- AUTUMN HIGHLANDS (0.87 world): painterly highlands on a golden autumn afternoon -- maple trees blazing red and amber,
-- dry-stone walls, hay bales, a ruined stone arch, wooden fences; a windmill turning on the far hill, leaves falling.
-- Sister: Stormspire.
local K = require(script.Parent.Parent:WaitForChild("WorldKit"))
local C3, M = K.C3, K.M
local P, Solid, Deco, Neon, Wedge = K.P, K.Solid, K.Deco, K.Neon, K.Wedge

local GRASS, STONE, STONE2, BARK, WOOD = C3(156, 146, 76), C3(150, 144, 130), C3(124, 118, 106), C3(80, 58, 44), C3(130, 96, 64)
local MAPLE, MAPLE2, MAPLE3, HAY, ROOF = C3(214, 70, 36), C3(240, 140, 40), C3(250, 196, 60), C3(220, 180, 90), C3(90, 54, 44)

local W = {}
W.Id = "Autumn"
W.Title = "AUTUMN HIGHLANDS"
W.TitleColor = C3(255, 150, 60)
W.Sister = "Storm"
W.HazardName = "Bog"

local LEAVES = { MAPLE, MAPLE2, MAPLE3 }
-- (UPDATE 4 prop pass: real textured models from ReplicatedStorage.WorldProps.Autumn via WorldKit.Prop when the place has
-- them; the part build under each is the fallback. Gameplay boxes measured from the models' height maps.)
local function Maple(geo, cf, s, ci)
    if K.Prop(geo, "Autumn", "Maple", cf, s, { { Vector3.new(1.6, 7, 1.6), Vector3.new(0, 3.5, 0) } }) then
        Deco(geo, Vector3.new(0.1, 8 * s, 8 * s), K.Up(cf * CFrame.new(0, 0.05, 0)), LEAVES[((ci or 0) + 1) % 3 + 1], M.Grass, Enum.PartType.Cylinder, 0.15) -- (fallen leaves)
        return
    end
    -- a maple: a short sturdy trunk forking into branches, layered round crowns in red / orange / gold
    K.Pillar(geo, 1.5 * s, 7 * s, cf, BARK, M.Wood, true)
    local top = cf * CFrame.new(0, 7 * s, 0)
    for k = 0, 2 do
        local a = k * 2.1 + 0.3
        local tip = (top * CFrame.new(math.cos(a) * 2.8 * s, 2.6 * s, math.sin(a) * 2.8 * s)).Position
        K.Beam(geo, top.Position, tip, 0.6 * s, BARK, M.Wood, true)
        Deco(geo, Vector3.new(6, 4.8, 6) * s, CFrame.new(tip + Vector3.new(0, 1.2 * s, 0)), LEAVES[(k + (ci or 0)) % 3 + 1], M.Grass, Enum.PartType.Ball)
    end
    Deco(geo, Vector3.new(7, 5.6, 7) * s, top * CFrame.new(0, 4.6 * s, 0), LEAVES[(ci or 0) % 3 + 1], M.Grass, Enum.PartType.Ball)
    Deco(geo, Vector3.new(0.1, 8 * s, 8 * s), K.Up(cf * CFrame.new(0, 0.05, 0)), LEAVES[((ci or 0) + 1) % 3 + 1], M.Grass, Enum.PartType.Cylinder, 0.15) -- (fallen leaves)
end
local function DryWall(geo, cf, s)
    if K.Prop(geo, "Autumn", "DryWall", cf, s, { { Vector3.new(9, 2.6, 1.4), Vector3.new(0, 1.3, 0) } }) then return end
    -- a dry-stone wall: rough stones in two courses, a capstone row, moss
    Solid(geo, Vector3.new(9 * s, 2.6 * s, 1.6 * s), cf * CFrame.new(0, 1.3 * s, 0), STONE2, M.Cobblestone)
    for k = -3, 3 do
        Deco(geo, Vector3.new(1.3 * s, 0.7 * s, 1.8 * s), cf * CFrame.new(k * 1.25 * s, 2.85 * s, 0) * CFrame.Angles(0, 0, (k % 2 == 0) and 0.12 or -0.12), STONE, M.Slate)
    end
    Deco(geo, Vector3.new(3 * s, 0.25 * s, 1.7 * s), cf * CFrame.new(-2 * s, 3.25 * s, 0), C3(110, 130, 60), M.Grass)
end
local function Hay(geo, cf, s)
    if K.Prop(geo, "Autumn", "Hay", cf, s, { { Vector3.new(5.4, 2.4, 3.8), Vector3.new(0, 1.2, 0) }, { Vector3.new(2.8, 2.2, 3.8), Vector3.new(0, 3.4, 0) } }) then return end
    -- round hay bales, one stacked on two
    for k, o in ipairs({ { -1.4, 0, 0 }, { 1.4, 0, 0.3 }, { 0, 2.6, 0.1 } }) do
        Solid(geo, Vector3.new(2.6 * s, 2.8 * s, 2.8 * s), cf * CFrame.new(o[1] * s, (1.4 + o[2]) * s, o[3] * s) * CFrame.Angles(0, math.rad(90), 0), (k == 3) and C3(230, 196, 104) or HAY, M.Grass, Enum.PartType.Cylinder)
    end
end
local function Arch(geo, cf, s)
    if K.Prop(geo, "Autumn", "Arch", cf, s, { { Vector3.new(1.8, 8, 2.2), Vector3.new(-2.9, 4, -0.2) }, { Vector3.new(1.8, 8, 2.2), Vector3.new(2.9, 4, -0.2) }, { Vector3.new(7.6, 1.6, 2.2), Vector3.new(0, 7.4, -0.2) } }) then return end
    -- a ruined stone arch: two square pillars, a stepped lintel, a block fallen beside it, ivy
    for _, sx in ipairs({ -1, 1 }) do
        Solid(geo, Vector3.new(1.8 * s, 8 * s, 1.8 * s), cf * CFrame.new(sx * 3 * s, 4 * s, 0), STONE, M.Cobblestone)
        Deco(geo, Vector3.new(2.2 * s, 0.5 * s, 2.2 * s), cf * CFrame.new(sx * 3 * s, 8.2 * s, 0), STONE2, M.Slate)
    end
    Deco(geo, Vector3.new(4.4 * s, 1.4 * s, 1.8 * s), cf * CFrame.new(-0.8 * s, 9.1 * s, 0) * CFrame.Angles(0, 0, math.rad(4)), STONE, M.Cobblestone)
    Solid(geo, Vector3.new(2.2 * s, 1.4 * s, 1.8 * s), cf * CFrame.new(4.6 * s, 0.7 * s, 1.6 * s) * CFrame.Angles(0, 0.5, 0.2), STONE2, M.Cobblestone)
    Deco(geo, Vector3.new(1.9 * s, 4 * s, 0.3 * s), cf * CFrame.new(-3 * s, 5 * s, -0.95 * s), MAPLE, M.Grass)
end
local function FenceRow(geo, cf, s)
    if K.Prop(geo, "Autumn", "FenceRow", cf, s, { { Vector3.new(8.4, 1, 1), Vector3.new(0, 0.5, 0) } }) then return end -- (shots pass the rails)
    -- a split-rail fence (shots pass between the rails) by a low stone footing
    Solid(geo, Vector3.new(8.4 * s, 1.0 * s, 1.0 * s), cf * CFrame.new(0, 0.5 * s, 0), STONE2, M.Cobblestone)
    for k = -2, 2 do Deco(geo, Vector3.new(0.4 * s, 3.4 * s, 0.4 * s), cf * CFrame.new(k * 2 * s, 2.2 * s, 0), WOOD, M.Wood) end
    for _, y in ipairs({ 2.0, 3.2 }) do Deco(geo, Vector3.new(8.6 * s, 0.3 * s, 0.2 * s), cf * CFrame.new(0, y * s, 0) * CFrame.Angles(0, 0, math.rad(y == 2 and 2 or -2)), WOOD, M.Wood) end
end
local function Windmill(parent, base, s, name)
    -- a stone windmill tower, a pointed roof, four lattice sails (returns the sail hub model)
    local h = 14 * s
    -- (UPDATE 4: a real tower model when the place has it -- the part sails below still turn on it)
    local real = K.Prop(parent, "Autumn", "WindmillTower", CFrame.new(base), s)
    for k = 0, (real and -1 or 3) do
        local w = (6 - k * 0.5) * s
        P(parent, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h / 4, w, w), CFrame = K.Up(CFrame.new(base + Vector3.new(0, (k + 0.5) * h / 4, 0))), Color = (k % 2 == 0) and STONE or STONE2, Material = M.Cobblestone })
    end
    for k = 0, (real and -1 or 3) do P(parent, { Class = "WedgePart", Size = Vector3.new(5 * s, 4 * s, 2.5 * s), CFrame = CFrame.new(base + Vector3.new(0, h + 2 * s, 0)) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -1.25 * s), Color = ROOF, Material = M.WoodPlanks }) end
    local hub = K.Model(parent, name or "Sails")
    for k = 0, 3 do
        local arm = CFrame.Angles(0, 0, k * math.pi / 2)
        P(hub, { Size = Vector3.new(0.4 * s, 9 * s, 0.3 * s), CFrame = arm * CFrame.new(0, 4.5 * s, 0), Color = WOOD, Material = M.Wood })
        P(hub, { Size = Vector3.new(1.8 * s, 7 * s, 0.1 * s), CFrame = arm * CFrame.new(1.1 * s, 5 * s, 0.1 * s), Color = C3(230, 220, 196), Material = M.SmoothPlastic, Transparency = 0.1 })
    end
    local pivot = CFrame.new(base + Vector3.new(0, h * 0.8, -3.2 * s))
    hub:PivotTo(pivot)
    return hub, pivot
end

W.Props = {
    Cover = { function(geo, _, rng, pos) DryWall(geo, CFrame.new(pos) * K.Yaw(rng), 0.9) end, function(geo, _, rng, pos) Hay(geo, CFrame.new(pos) * K.Yaw(rng), 1) end },
    Tall = { function(geo, _, rng, pos) Maple(geo, CFrame.new(pos) * K.Yaw(rng), 0.9, rng:NextInteger(0, 2)) end, function(geo, _, rng, pos) Arch(geo, CFrame.new(pos) * K.Yaw(rng), 0.9) end },
    Air = {},
}
W.Landmarks = {
    function(geo, _, rng, c) -- THE MAPLE RING: maples round the plaza in red, orange and gold
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2 + 0.25
            Maple(geo, CFrame.new(c + Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32)) * CFrame.Angles(0, a, 0), 0.9, i)
        end
    end,
    function(geo, _, rng, c) -- THE OLD ABBEY: ruined arches on the diagonals facing the plaza, hay between them
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            local p = c + Vector3.new(math.cos(a) * 31, 0, math.sin(a) * 31)
            Arch(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 0.9)
            Hay(geo, CFrame.new(c + Vector3.new(math.cos(a + 0.7) * 33, 0, math.sin(a + 0.7) * 33)) * CFrame.Angles(0, a, 0), 0.9)
        end
    end,
}
W.Kits = {
    AuMaple = function(g, cf, s) Maple(g, cf, s * 0.6, math.floor(cf.Position.Z) % 3) end,
    AuWall = function(g, cf, s) DryWall(g, cf, s * 0.55) end,
    AuHay = function(g, cf, s) Hay(g, cf, s * 0.6) end,
    AuArch = function(g, cf, s) Arch(g, cf, s * 0.55) end,
    AuFence = function(g, cf, s) FenceRow(g, cf, s * 0.6) end,
}
W.Templates = {
    { Name = "Harvest Fields", Rim = "Ruins", RimMat = { M.Grass, M.Ground }, Ground = M.Grass, Patch = { M.Ground, M.LeafyGrass },
        Edge = { "AuHay", "AuFence", "AuWall" }, RimKit = { "AuMaple", "AuMaple", "AuFence" }, Hero = "AuWindmill" },
    { Name = "Maple Glen", Rim = "Cliffs", RimMat = { M.Rock, M.Grass }, RimAccent = M.LeafyGrass, PartyRim = "AuMaple", Ground = M.LeafyGrass, Patch = { M.Grass, M.Ground },
        Edge = { "AuWall", "AuHay" }, RimKit = { "AuMaple", "AuMaple", "AuArch" }, Hero = "AuWindmill" },
    { Name = "Abbey Ruins", Rim = "Ruins", RimMat = { M.Cobblestone, M.Grass }, Ground = M.Grass, Patch = { M.Cobblestone, M.Ground },
        Edge = { "AuArch", "AuWall", "AuHay" }, RimKit = { "AuArch", "AuMaple", "AuWall" }, Hero = "AuWindmill" },
}
W.Heroes = {}
function W.Heroes.AuWindmill(fx, ctx)
    -- a windmill on a far hill, its sails turning slowly (client)
    local base = Vector3.new(70, 18, ctx.zC + ctx.half * 3.3)
    P(fx, { Shape = Enum.PartType.Ball, Size = Vector3.new(220, 60, 180), CFrame = CFrame.new(base - Vector3.new(0, 18, 0)), Color = C3(150, 140, 70), Material = M.Grass })
    local hub, pivot = Windmill(fx, base, 4, "HeroSails")
    K.Live(fx, function(t) hub:PivotTo(pivot * CFrame.Angles(0, 0, t * 0.3)) end)
    for k = -2, 2 do
        local m = K.Model(fx, "HillMaple")
        Maple(m, CFrame.new(base + Vector3.new(k * 30 - 20, -4, 20 + math.abs(k) * 6)), 2.4, k + 2)
        K.NoCollide(m)
    end
end
W.Vista = { Ground = C3(150, 136, 70), GroundMat = M.Grass, Peak = C3(130, 120, 110), PeakMat = M.Rock, Tip = C3(220, 120, 50) }
function W.VistaFn(fx, Pf, centre, gy, zC, r)
    -- rolling hills patched with woods in autumn colours, receding to blue
    -- (UPDATE 4 VISTA: real models to the horizon -- WorldKit.Far props + tinted scanned mountains; the part version
    -- below stays as the fallback for an unsaved place)
    if K.HasProp("Autumn", "Maple") then
        for _ = 1, 16 do -- rolling hills, the near ones wooded with red maples
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(280, 1050)
            local w = r:NextNumber(180, 380)
            local p = centre + Vector3.new(math.cos(a) * d, -w * 0.36, math.sin(a) * d)
            local far = d > 750
            Pf({ Name = "Hill", Shape = Enum.PartType.Ball, Size = Vector3.new(w, w * 0.8, w), CFrame = CFrame.new(p), Color = far and C3(120, 130, 120) or C3(150, 140, 72), Material = M.Grass })
            for _ = 1, far and 0 or 2 do
                K.Far(fx, "Autumn", "Maple", CFrame.new(p + Vector3.new(r:NextNumber(-w * 0.18, w * 0.18), w * 0.39, r:NextNumber(-w * 0.18, w * 0.18))) * CFrame.Angles(0, r:NextNumber(0, 6.28), 0), 1.8 + d / 400)
            end
        end
        for k = 1, 5 do -- blue highland ridges behind
            local a, d = (k / 5 + r:NextNumber(-0.06, 0.06)) * math.pi * 2, r:NextNumber(1050, 1250)
            K.Mesh(fx, "Mountain", CFrame.new(centre + Vector3.new(math.cos(a) * d, -40, math.sin(a) * d)) * CFrame.Angles(0, a + math.pi / 2, 0), r:NextNumber(260, 380), C3(126, 138, 156), { Shadow = false })
        end
        return true
    end
    for _ = 1, 26 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(280, 1100)
        local w = r:NextNumber(180, 380)
        local p = centre + Vector3.new(math.cos(a) * d, -w * 0.36, math.sin(a) * d)
        local far = d > 750
        Pf({ Name = "Hill", Shape = Enum.PartType.Ball, Size = Vector3.new(w, w * 0.8, w), CFrame = CFrame.new(p), Color = far and C3(120, 130, 120) or C3(150, 140, 72), Material = M.Grass })
        for _ = 1, far and 2 or 4 do
            Pf({ Name = "Woods", Shape = Enum.PartType.Ball, Size = Vector3.one * r:NextNumber(18, 36), CFrame = CFrame.new(p + Vector3.new(r:NextNumber(-w * 0.3, w * 0.3), w * 0.38, r:NextNumber(-w * 0.3, w * 0.3))),
                Color = far and C3(160, 110, 90) or LEAVES[r:NextInteger(1, 3)], Material = M.Grass })
        end
    end
    return true
end
function W.Scenery(fx, theme, rng, zC, arena, height)
    -- leaves tumbling down through the room on a soft breeze
    local src = K.Box(fx, Vector3.new(arena, 1, arena), CFrame.new(0, 28, zC))
    K.Emit(src, { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, MAPLE), ColorSequenceKeypoint.new(0.5, MAPLE2), ColorSequenceKeypoint.new(1, MAPLE3) }),
        LightEmission = 0, LightInfluence = 1, Rate = 16, Lifetime = NumberRange.new(7, 10), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(40, 40),
        EmissionDirection = Enum.NormalId.Bottom, Size = NumberSequence.new(0.4, 0.3), Transparency = NumberSequence.new(0, 1), RotSpeed = NumberRange.new(-160, 160),
        Rotation = NumberRange.new(0, 360), Acceleration = Vector3.new(2, -0.8, 1), Texture = "rbxasset://textures/particles/sparkles_main.dds" })
end
function W.SetPiece(geo, deco, c, rng, F)
    -- THE HARVEST RING: maples and arches round the fight floor, a windmill turning over the far side
    K.Ring(12, 100, c + Vector3.new(0, F, 0), function(p, a, i)
        if i % 2 == 0 then Maple(geo, CFrame.new(p) * CFrame.Angles(0, a, 0), 1.6, i) else Arch(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1.4) end
    end)
    local hub, pivot = Windmill(deco, c + Vector3.new(0, F, 160), 3, "BossSails")
    K.Live(deco, function(t) hub:PivotTo(pivot * CFrame.Angles(0, 0, t * 0.3)) end)
    local lamp = Neon(deco, Vector3.new(4, 4, 4), CFrame.new(c + Vector3.new(0, F + 30, 150)), C3(255, 200, 120), 0.2, Enum.PartType.Ball)
    K.Light(lamp, C3(255, 200, 130), 60, 1.0)
    return MAPLE2
end

W.Theme = {
    Name = "Autumn Highlands",
    Floor = { Color = GRASS, Material = M.Grass },
    FloorAlt = { Color = C3(120, 96, 66), Material = M.Ground },
    Wall = { Color = STONE2, Material = M.Cobblestone },
    WallTrim = { Color = C3(96, 90, 80), Material = M.Slate },
    Ceiling = { Color = ROOF, Material = M.WoodPlanks },
    Prop = { Color = STONE, Material = M.Cobblestone },
    PropAlt = { Color = MAPLE2, Material = M.Grass },
    Hazard = { Color = C3(80, 70, 50), Material = M.Mud },
    Accent = MAPLE2, Light = C3(255, 220, 170), LampBrightness = 1.2, LampRange = 50,
    OpenSky = true,
}
W.Ambience = { Mote = MAPLE2, Mote2 = MAPLE3, MoteRise = false, Glow = MAPLE2 }
W.Light = { ClockTime = 15.8, Brightness = 2.3, Ambient = C3(150, 136, 110), OutdoorAmbient = C3(170, 156, 130),
    FogColor = C3(220, 190, 150), FogStart = 220, FogEnd = 1000, Exposure = 0.12, EnvDiffuse = 0.35,
    BloomIntensity = 0.3, BloomThreshold = 1.35, BloomSize = 20,
    CCBrightness = 0, CCContrast = 0.1, CCSaturation = 0.1, CCTint = C3(255, 244, 228) }
W.Atmo = { 0.3, C3(240, 210, 170), C3(150, 150, 170), 1.4, 0.35 }
W.Terrain = { [M.Grass] = C3(150, 140, 72), [M.LeafyGrass] = C3(140, 120, 60), [M.Ground] = C3(120, 96, 66), [M.Rock] = C3(124, 118, 106),
    [M.Cobblestone] = C3(140, 134, 120) }
-- (UPDATE 4 wrap-up, RoomGen.DressFor: the room pieces in this world's own language -- field-stone towers (no more grass blocks), a red maple growing out of the top)
W.Cover = { Built = true, Stone = M.Cobblestone, Crown = { World = "Autumn", Name = "Maple", Fit = 1.1, MaxH = 7, Alt = { "Hay", "FenceRow" } } }
W.Contrast = C3(60, 160, 255)
W.EA = { Warn = C3(255, 40, 90), Core = C3(255, 220, 230), Mat = M.Neon }
W.Moods = {
    { Id = "Golden", W = 3 },
    { Id = "Frost", Name = "First Frost", W = 2, Sat = 0.75, Fog = C3(210, 220, 236), FogAmt = 0.38, Clock = -4.0, Exp = 0.03 },
    { Id = "Harvest", Name = "Harvest Moon", W = 2, Val = 0.88, Acc = 0.09, Fog = C3(120, 70, 50), FogAmt = 0.36, Exp = -0.07, Clock = 1.0 },
    { Id = "Drizzle", Name = "Drizzle", W = 1, Sat = 0.8, Fog = C3(150, 150, 140), FogAmt = 0.4, Dens = 1.3 },
}
W.Sky = { Bk = "115546834759541", Dn = "133869812973997", Ft = "113321906878966", Lf = "82833042125828", Rt = "108657070021922", Up = "137111083063643" } -- (UPDATE 4 SKIES v4: tools/hdri_sky.py)
return W
