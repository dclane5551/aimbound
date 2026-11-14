--!nocheck
-- SUNKEN TEMPLE (0.87 world): a jungle swallowing an ancient temple -- mossy limestone ruins, stone idol heads with gold
-- eyes, banyan trees, temple stairs; a morning of humid gold haze, light shafts through the canopy, a waterfall pouring
-- off a giant temple face on the horizon. Sister: Stormspire (enemies, element, superboss).
local K = require(script.Parent.Parent:WaitForChild("WorldKit"))
local C3, M = K.C3, K.M
local P, Solid, Deco, Neon, Wedge = K.P, K.Solid, K.Deco, K.Neon, K.Wedge

local STONE, STONE2, DARK = C3(122, 128, 108), C3(104, 112, 94), C3(70, 76, 64)
local MOSS, MOSS2, LEAF, LEAF2 = C3(74, 112, 52), C3(96, 132, 60), C3(62, 104, 46), C3(88, 128, 54)
local BARK, GOLD, VINE = C3(78, 60, 44), C3(240, 190, 80), C3(56, 86, 40)

local W = {}
W.Id = "Jungle"
W.Title = "SUNKEN TEMPLE"
W.TitleColor = C3(150, 220, 110)
W.Sister = "Storm"
W.HazardName = "Quicksand"

-- ==================== PIECES (cf = bottom centre on the floor; s = scale) ====================
local function Vines(geo, cf, s, w, n)
    for i = 1, n do
        local x = ((i - 0.5) / n - 0.5) * w
        local len = (1.4 + ((i * 7) % 5) * 0.45) * s
        Deco(geo, Vector3.new(0.18 * s, len, 0.18 * s), cf * CFrame.new(x, -len / 2, 0), VINE, M.Grass)
        Deco(geo, Vector3.new(0.5 * s, 0.35 * s, 0.12 * s), cf * CFrame.new(x + 0.12 * s, -len * 0.6, 0.08 * s) * CFrame.Angles(0, 0, 0.5), LEAF2, M.Grass)
    end
end
-- (UPDATE 4 prop pass: each piece is a real textured model from ReplicatedStorage.WorldProps.Jungle when the place
-- has it -- WorldKit.Prop; the part build below each one is the fallback and keeps the same gameplay boxes)
local HIT_RUIN = { { Vector3.new(8, 3.4, 2), Vector3.new(0, 1.7, 0) } }
local function RuinWall(geo, cf, s)
    if K.Prop(geo, "Jungle", "RuinA", cf * CFrame.new(-1.9 * s, 0, 0), s) then
        K.Prop(geo, "Jungle", "RuinB", cf * CFrame.new(2.3 * s, 0, 0.1 * s) * CFrame.Angles(0, math.pi, 0), s)
        K.Hit(geo, cf, s, HIT_RUIN)
        return
    end
    -- a broken temple wall: a long base course, staggered upper blocks, one fallen, moss on top, vines down the face
    Solid(geo, Vector3.new(8 * s, 2.2 * s, 2 * s), cf * CFrame.new(0, 1.1 * s, 0), STONE, M.Limestone)
    Solid(geo, Vector3.new(3.2 * s, 1.8 * s, 1.9 * s), cf * CFrame.new(-2.3 * s, 3.1 * s, 0.05 * s), STONE2, M.Limestone)
    Solid(geo, Vector3.new(2.4 * s, 1.4 * s, 1.8 * s), cf * CFrame.new(1.1 * s, 2.9 * s, -0.05 * s) * CFrame.Angles(0, 0, math.rad(4)), STONE, M.Limestone)
    Solid(geo, Vector3.new(2.6 * s, 1.6 * s, 1.8 * s), cf * CFrame.new(5.1 * s, 0.75 * s, 1.4 * s) * CFrame.Angles(math.rad(8), math.rad(20), math.rad(-12)), STONE2, M.Limestone)
    Deco(geo, Vector3.new(3.4 * s, 0.3 * s, 2.1 * s), cf * CFrame.new(-2.3 * s, 4.1 * s, 0.05 * s), MOSS, M.Grass)
    Deco(geo, Vector3.new(8.1 * s, 0.25 * s, 0.9 * s), cf * CFrame.new(0, 2.25 * s, 0.6 * s), MOSS2, M.Grass)
    -- a carved gold band along the base course
    Deco(geo, Vector3.new(7.4 * s, 0.22 * s, 0.08), cf * CFrame.new(0, 1.2 * s, -1.02 * s), GOLD, M.Metal)
    Vines(geo, cf * CFrame.new(-2.3 * s, 4 * s, -1.02 * s), s, 3 * s, 4)
end
local function MossRock(geo, cf, s)
    if K.ScanRock(geo, K.MOSS_ROCKS, cf * CFrame.Angles(0, 0.7, 0), 5 * s, C3(150, 160, 132), { Sink = 0.3 * s }) then
        K.Hit(geo, cf, s, { { Vector3.new(4.2, 3, 3.6), Vector3.new(0, 1.5, 0) } })
        return
    end
    Solid(geo, Vector3.new(4.2 * s, 3.2 * s, 3.6 * s), cf * CFrame.new(0, 1.4 * s, 0) * CFrame.Angles(math.rad(12), math.rad(30), math.rad(-8)), DARK, M.Rock)
    Solid(geo, Vector3.new(2.6 * s, 2 * s, 2.4 * s), cf * CFrame.new(2.4 * s, 0.9 * s, 0.8 * s) * CFrame.Angles(math.rad(-10), math.rad(64), math.rad(14)), STONE2, M.Rock)
    Deco(geo, Vector3.new(3.6 * s, 0.4 * s, 3 * s), cf * CFrame.new(-0.2 * s, 3 * s, 0) * CFrame.Angles(math.rad(12), math.rad(30), math.rad(-8)), MOSS, M.Grass)
end
local HIT_STAIR = { -- four 1-stud steps climbing toward +Z (the model is 6.4 x 4 x 5)
    { Vector3.new(6, 1, 5), Vector3.new(0, 0.5, 0) }, { Vector3.new(5.6, 2, 3.75), Vector3.new(0, 1, 0.625) },
    { Vector3.new(5.2, 3, 2.5), Vector3.new(0, 1.5, 1.25) }, { Vector3.new(4.8, 4, 1.25), Vector3.new(0, 2, 1.875) } }
local function Stair(geo, cf, s)
    if K.Prop(geo, "Jungle", "Stair", cf, s, HIT_STAIR) then return end
    -- a temple stair stub: four shrinking steps, a gold inlay on the top riser
    for i = 0, 3 do
        local w = (6 - i * 1.1) * s
        Solid(geo, Vector3.new(w, 1 * s, (4.4 - i * 0.9) * s), cf * CFrame.new(0, (i + 0.5) * s, i * 0.45 * s), (i % 2 == 0) and STONE or STONE2, M.Limestone)
    end
    Neon(geo, Vector3.new(2.4 * s, 0.18 * s, 0.08), cf * CFrame.new(0, 3.5 * s, -0.66 * s), GOLD, 0.2)
    Deco(geo, Vector3.new(2.8 * s, 0.25 * s, 1.6 * s), cf * CFrame.new(-1.6 * s, 1.1 * s, -1.2 * s), MOSS, M.Grass)
end
local HIT_IDOL = { { Vector3.new(5.2, 2, 5.2), Vector3.new(0, 1, 0) }, { Vector3.new(4.2, 6, 4), Vector3.new(0, 5, 0) } }
local function Idol(geo, cf, s)
    if K.Prop(geo, "Jungle", "Idol", cf, s, HIT_IDOL) then return end
    -- a stone idol head on a plinth: heavy brow, square nose, a dark mouth slot, glowing gold eyes, moss on the crown
    Solid(geo, Vector3.new(5.2 * s, 2 * s, 5.2 * s), cf * CFrame.new(0, 1 * s, 0), STONE2, M.Limestone)
    local head = cf * CFrame.new(0, 5 * s, 0)
    Solid(geo, Vector3.new(4.2 * s, 6 * s, 4 * s), head, STONE, M.Limestone)
    Deco(geo, Vector3.new(4.6 * s, 0.9 * s, 1.0 * s), head * CFrame.new(0, 1.2 * s, -2.1 * s), STONE2, M.Limestone)
    Deco(geo, Vector3.new(1.1 * s, 1.8 * s, 0.9 * s), head * CFrame.new(0, -0.1 * s, -2.3 * s), STONE2, M.Limestone)
    Deco(geo, Vector3.new(2.6 * s, 0.5 * s, 0.2 * s), head * CFrame.new(0, -1.7 * s, -2.02 * s), C3(30, 32, 26), M.Slate)
    for _, sx in ipairs({ -1, 1 }) do
        Neon(geo, Vector3.new(0.9 * s, 0.45 * s, 0.1), head * CFrame.new(sx * 1.05 * s, 0.45 * s, -2.03 * s), GOLD)
        Deco(geo, Vector3.new(0.5 * s, 2.6 * s, 2.4 * s), head * CFrame.new(sx * 2.3 * s, -0.2 * s, 0), STONE2, M.Limestone) -- (ears)
    end
    Deco(geo, Vector3.new(4.4 * s, 0.6 * s, 4.2 * s), head * CFrame.new(0, 3.2 * s, 0), MOSS, M.Grass)
    Vines(geo, head * CFrame.new(0.6 * s, 3 * s, 2.02 * s), s, 3 * s, 3)
end
local function Banyan(geo, cf, s)
    if K.Prop(geo, "Jungle", "Banyan", cf, s, { { Vector3.new(2.4, 13, 2.4), Vector3.new(0, 6.5, 0) } }) then return end
    -- a banyan: a thick trunk on flared buttress roots, three leaf crowns, aerial roots hanging from the crown
    K.Pillar(geo, 2.4 * s, 13 * s, cf, BARK, M.Wood, true)
    for k = 0, 3 do
        local a = k * math.pi / 2 + 0.4
        Wedge(geo, Vector3.new(0.7 * s, 3.4 * s, 2.6 * s), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 1.7 * s, -2.1 * s), BARK, M.Wood)
    end
    for k, o in ipairs({ Vector3.new(0, 14.5, 0), Vector3.new(3.4, 12.8, 1.6), Vector3.new(-3, 13.2, -1.8) }) do
        Deco(geo, Vector3.one * (9 - k) * s, cf * CFrame.new(o * s), (k == 1) and LEAF or LEAF2, M.Grass, Enum.PartType.Ball)
    end
    for k = 1, 5 do
        local a = k * 1.25
        local x, z = math.cos(a) * 3.2 * s, math.sin(a) * 3.2 * s
        Deco(geo, Vector3.new(0.16 * s, 7 * s, 0.16 * s), cf * CFrame.new(x, 8.5 * s, z), BARK, M.Wood)
    end
end

-- ==================== PROPS / LANDMARKS ====================
W.Props = {
    Cover = { function(geo, _, rng, pos) RuinWall(geo, CFrame.new(pos) * K.Yaw(rng), 1) end, function(geo, _, rng, pos) MossRock(geo, CFrame.new(pos) * K.Yaw(rng), 1) end,
        function(geo, _, rng, pos) Stair(geo, CFrame.new(pos) * K.Yaw(rng), 1) end },
    Tall = { function(geo, _, rng, pos) Idol(geo, CFrame.new(pos) * K.Yaw(rng), 1) end, function(geo, _, rng, pos) Banyan(geo, CFrame.new(pos) * K.Yaw(rng), 0.9) end },
    Air = {},
}
W.Landmarks = {
    function(geo, _, rng, c) -- IDOL CIRCLE: four idols staring at the plaza, broken walls between them
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            local p = c + Vector3.new(math.cos(a) * 31, 0, math.sin(a) * 31)
            Idol(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 0.9)
        end
    end,
    function(geo, _, rng, c) -- SACRED GROVE: four banyans round the plaza, stair stubs climbing to nothing
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            Banyan(geo, CFrame.new(c + Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32)) * CFrame.Angles(0, a, 0), 0.85)
        end
    end,
}

-- ==================== MAP SHELL ====================
W.Kits = {
    JgRuin = function(g, cf, s) RuinWall(g, cf, s * 0.55) end,
    JgRock = function(g, cf, s) MossRock(g, cf, s * 0.6) end,
    JgStair = function(g, cf, s) Stair(g, cf, s * 0.55) end,
    JgIdol = function(g, cf, s) Idol(g, cf, s * 0.5) end,
    JgTree = function(g, cf, s) Banyan(g, cf, s * 0.6) end,
}
W.Templates = {
    { Name = "Overgrown Court", Rim = "Ruins", RimMat = { M.LeafyGrass, M.Limestone }, Ground = M.Grass, Patch = { M.Mud, M.LeafyGrass },
        Edge = { "JgRuin", "JgRock", "JgStair" }, RimKit = { "JgTree", "JgRuin", "JgIdol" }, Hero = "JgFallsTemple", Glow = { JgIdol = GOLD } },
    { Name = "Waterfall Gorge", Rim = "Cliffs", RimMat = { M.Rock, M.Limestone }, RimAccent = M.LeafyGrass, PartyRim = "JgTree", Ground = M.LeafyGrass, Patch = { M.Mud, M.Grass },
        Edge = { "JgRock", "JgRuin" }, RimKit = { "JgTree", "JgTree", "JgRock" }, Hero = "JgFallsTemple" },
    { Name = "Canopy Steps", Rim = "Cliffs", RimMat = { M.Limestone, M.Rock }, RimAccent = M.LeafyGrass, PartyRim = "JgIdol", Ground = M.Grass, Patch = { M.Limestone, M.Mud },
        Edge = { "JgStair", "JgRuin", "JgIdol" }, RimKit = { "JgTree", "JgIdol" }, Hero = "JgFallsTemple", Glow = { JgIdol = GOLD } },
}
W.Heroes = {}
function W.Heroes.JgFallsTemple(fx, ctx)
    -- a giant temple face carved into a cliff on the far side, a waterfall pouring down beside it into mist
    local half, zC = ctx.half, ctx.zC
    local base = Vector3.new(-40, 0, zC + half * 3.4)
    -- the cliff: jagged leaning rock masses (one slab read as a flat wall), moss slumped over the top
    local rr = ctx.rng
    -- (UPDATE 4: one real model of the cliff + temple face when the place has it; the rng draws below still run so the
    -- rest of the floor rolls the same)
    local real = K.Prop(fx, "Jungle", "TempleCliff", CFrame.new(base + Vector3.new(-50, 0, 60)), 1)
    for k = 0, 8 do
        local x = -170 + k * 42 + rr:NextNumber(-8, 8)
        local h = rr:NextNumber(120, 165)
        if real then for _ = 1, 6 do rr:NextNumber() end continue end -- (the 6 draws the part build makes: size x2, offset, angles x3)
        P(fx, { Size = Vector3.new(rr:NextNumber(46, 64), h, rr:NextNumber(50, 70)), CFrame = CFrame.new(base + Vector3.new(x, h / 2 - 6, 34 + rr:NextNumber(-6, 10)))
            * CFrame.Angles(rr:NextNumber(-0.08, 0.08), rr:NextNumber(-0.3, 0.3), rr:NextNumber(-0.07, 0.07)), Color = (k % 2 == 0) and DARK or C3(84, 90, 76), Material = M.Rock })
        P(fx, { Shape = Enum.PartType.Ball, Size = Vector3.new(60, 30, 60), CFrame = CFrame.new(base + Vector3.new(x, h - 2, 36)), Color = (k % 2 == 0) and LEAF or MOSS, Material = M.Grass })
    end
    for t = 0, (real and -1 or 3) do -- the stepped temple front
        P(fx, { Size = Vector3.new(130 - t * 26, 22, 20), CFrame = CFrame.new(base + Vector3.new(-50, 11 + t * 22, -4 - t * 3)), Color = (t % 2 == 0) and STONE or STONE2, Material = M.Limestone })
    end
    local face = CFrame.new(base + Vector3.new(-50, 104, -12))
    if not real then P(fx, { Size = Vector3.new(50, 44, 12), CFrame = face, Color = STONE, Material = M.Limestone }) end
    for _, sx in ipairs(real and {} or { -1, 1 }) do P(fx, { Size = Vector3.new(10, 4, 1), CFrame = face * CFrame.new(sx * 11, 6, -6.2), Color = GOLD, Material = M.Neon }) end
    if not real then P(fx, { Size = Vector3.new(24, 4, 1), CFrame = face * CFrame.new(0, -12, -6.2), Color = C3(24, 26, 20), Material = M.Slate }) end
    if real then -- (scanned cliff faces behind the falls: the temple model is narrower than the old cliff)
        K.Mesh(fx, "CliffB", CFrame.new(base + Vector3.new(88, 0, 66)), 160, C3(112, 122, 100))
        K.Mesh(fx, "CliffA", CFrame.new(base + Vector3.new(170, 0, 80)) * CFrame.Angles(0, 0.35, 0), 150, C3(100, 112, 92))
    end
    -- the falls (UPDATE 4): camera-facing water beams scrolling down + foam at the foot (WorldKit.Falls; was three flat
    -- translucent slabs that read as glass panels)
    K.Falls(fx, base + Vector3.new(88, 150, -2), base + Vector3.new(88, 1, -6), 22, { Rate = 5 })
    local mist = P(fx, { Size = Vector3.new(50, 4, 30), CFrame = CFrame.new(base + Vector3.new(88, 4, -14)), Transparency = 1 })
    K.Emit(mist, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(220, 240, 240)), Rate = 3, Lifetime = NumberRange.new(5, 7),
        Speed = NumberRange.new(2, 5), Size = NumberSequence.new(14, 30), Transparency = NumberSequence.new(0.55, 1), EmissionDirection = Enum.NormalId.Top, LightEmission = 0.1 })
end
W.Vista = { Ground = C3(42, 66, 36), GroundMat = M.Grass, Peak = C3(50, 78, 42), PeakMat = M.Grass, Tip = C3(96, 132, 70) }
function W.VistaFn(fx, Pf, centre, gy, zC, r)
    -- an endless canopy: clustered tree crowns to the horizon, a few far stone towers poking through
    -- (UPDATE 4 VISTA: real models to the horizon -- WorldKit.Far props + tinted scanned mountains; the part version
    -- below stays as the fallback for an unsaved place)
    if K.HasProp("Jungle", "Banyan") then
        for _ = 1, 20 do -- the canopy: banyans, bigger with distance
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(240, 820)
            K.Far(fx, "Jungle", "Banyan", CFrame.new(centre + Vector3.new(math.cos(a) * d, -2, math.sin(a) * d)) * CFrame.Angles(0, r:NextNumber(0, 6.28), 0), 2.6 + d / 220)
        end
        for k = 1, 5 do -- jungle-clad ridges behind
            local a, d = (k / 5 + r:NextNumber(-0.06, 0.06)) * math.pi * 2, r:NextNumber(950, 1200)
            K.Mesh(fx, "Mountain", CFrame.new(centre + Vector3.new(math.cos(a) * d, -40, math.sin(a) * d)) * CFrame.Angles(0, a + math.pi / 2, 0), r:NextNumber(280, 400), C3(92, 120, 84), { Shadow = false })
        end
        for _ = 1, 3 do -- giant idol heads breaking the canopy
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(560, 860)
            local p = centre + Vector3.new(math.cos(a) * d, -6, math.sin(a) * d)
            K.Far(fx, "Jungle", "Idol", CFrame.lookAt(p, Vector3.new(centre.X, p.Y, centre.Z)), r:NextNumber(5, 7.5))
        end
        return true
    end
    for _ = 1, 46 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(260, 1100)
        local sz = r:NextNumber(50, 120) * (d / 600)
        Pf({ Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.one * sz, CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * d, sz * 0.15, math.sin(a) * d)),
            Color = (r:NextNumber() < 0.5) and LEAF or C3(52, 88, 40), Material = M.Grass })
    end
    for _ = 1, 5 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(600, 1000)
        local h = r:NextNumber(90, 160)
        local p = centre + Vector3.new(math.cos(a) * d, h / 2, math.sin(a) * d)
        Pf({ Name = "FarTower", Size = Vector3.new(36, h, 36), CFrame = CFrame.new(p), Color = STONE2, Material = M.Limestone })
        Pf({ Name = "FarTowerTop", Size = Vector3.new(24, 16, 24), CFrame = CFrame.new(p + Vector3.new(0, h / 2 + 8, 0)), Color = STONE, Material = M.Limestone })
        Pf({ Name = "FarTowerMoss", Size = Vector3.new(38, 4, 38), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)), Color = MOSS, Material = M.Grass })
    end
    return true
end
function W.Scenery(fx, theme, rng, zC, arena, height)
    local half = arena / 2
    -- (no light-shaft slabs / wall-top vines: open maps' walls are invisible -- seen in play, they floated)
    -- butterflies drifting over the floor (client): two-wing flutters on lazy loops
    local flies = {}
    for i = 1, 6 do
        local m = K.Model(fx, "Butterfly")
        local col = (i % 2 == 0) and C3(255, 170, 60) or C3(90, 200, 255)
        local wl = Deco(m, Vector3.new(0.7, 0.05, 0.6), CFrame.new(), col, M.SmoothPlastic)
        local wr = Deco(m, Vector3.new(0.7, 0.05, 0.6), CFrame.new(), col, M.SmoothPlastic)
        table.insert(flies, { L = wl, R = wr, C = Vector3.new(rng:NextNumber(-half * 0.8, half * 0.8), rng:NextNumber(4, 9), zC + rng:NextNumber(-half * 0.8, half * 0.8)),
            Rad = rng:NextNumber(3, 7), Ph = rng:NextNumber(0, 6), Sp = rng:NextNumber(0.4, 0.8) })
    end
    K.Live(fx, function(t)
        for _, f in ipairs(flies) do
            local a = t * f.Sp + f.Ph
            local pos = f.C + Vector3.new(math.cos(a) * f.Rad, math.sin(t * 1.7 + f.Ph) * 1.2, math.sin(a * 1.3) * f.Rad)
            local cf = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a * 1.3)))
            local flap = math.sin(t * 22 + f.Ph) * 0.9
            f.L.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-0.35, 0, 0)
            f.R.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(0.35, 0, 0)
        end
    end)
    -- pollen + fireflies drifting through the room
    local src = K.Box(fx, Vector3.new(arena, 1, arena), CFrame.new(0, 12, zC))
    K.Emit(src, { Color = ColorSequence.new(C3(255, 236, 150), C3(190, 255, 140)), LightEmission = 0.8, Rate = 10, Lifetime = NumberRange.new(6, 9),
        Speed = NumberRange.new(0.3, 1), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.25, 0.1), Transparency = NumberSequence.new(0.2, 1),
        Acceleration = Vector3.new(0.4, 0.15, 0) })
end
function W.SetPiece(geo, deco, c, rng, F)
    -- THE IDOL RING: idols and banyans round the fight floor, a giant gold idol watching from the far side
    K.Ring(10, 100, c + Vector3.new(0, F, 0), function(p, a, i)
        if i % 2 == 0 then Idol(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1.6) else Banyan(geo, CFrame.new(p), 1.3) end
    end)
    local face = CFrame.new(c + Vector3.new(0, F + 40, 150))
    -- (UPDATE 4: the real idol, ~92 tall, facing the fight, its base hidden behind the rim hills so the face rises over
    -- them (seen in play: at floor level, then at +26, the rim dome hid all but the crown); its light stays where the
    -- old eyes were)
    if K.Far(deco, "Jungle", "Idol", CFrame.new(c + Vector3.new(0, F + 52, 180)), 11) then
        K.Light(K.Box(deco, Vector3.new(1, 1, 1), face * CFrame.new(0, 8, -16)), C3(255, 210, 120), 60, 1.2)
        return GOLD
    end
    Deco(deco, Vector3.new(44, 52, 16), face, STONE, M.Limestone)
    for _, sx in ipairs({ -1, 1 }) do
        local eye = Neon(deco, Vector3.new(9, 4, 1), face * CFrame.new(sx * 10, 8, -8.2), GOLD)
        if sx > 0 then K.Light(eye, C3(255, 210, 120), 60, 1.2) end
    end
    Deco(deco, Vector3.new(46, 4, 18), face * CFrame.new(0, 27, 0), MOSS, M.Grass)
    return GOLD
end

-- ==================== THEME / LOOK ====================
W.Theme = {
    Name = "Sunken Temple",
    Floor = { Color = C3(86, 102, 68), Material = M.Grass },
    FloorAlt = { Color = C3(112, 114, 94), Material = M.Limestone },
    Wall = { Color = C3(118, 124, 104), Material = M.Limestone },
    WallTrim = { Color = C3(84, 90, 74), Material = M.Cobblestone },
    Ceiling = { Color = C3(60, 70, 56), Material = M.Rock },
    Prop = { Color = C3(108, 116, 96), Material = M.Limestone },
    PropAlt = { Color = C3(70, 110, 56), Material = M.Grass },
    Hazard = { Color = C3(124, 104, 60), Material = M.Mud },
    Accent = GOLD, Light = C3(255, 232, 176), LampBrightness = 1.4, LampRange = 54,
    OpenSky = true,
}
W.Ambience = { Mote = C3(255, 236, 150), Mote2 = C3(170, 255, 140), MoteRise = true, Glow = GOLD }
W.Light = { ClockTime = 8.4, Brightness = 2.0, Ambient = C3(118, 130, 102), OutdoorAmbient = C3(130, 150, 110),
    FogColor = C3(96, 124, 96), FogStart = 150, FogEnd = 760, Exposure = 0.25, EnvDiffuse = 0.35,
    BloomIntensity = 0.35, BloomThreshold = 1.3, BloomSize = 22,
    CCBrightness = 0, CCContrast = 0.1, CCSaturation = 0.08, CCTint = C3(250, 255, 236) }
W.Atmo = { 0.36, C3(190, 214, 170), C3(70, 100, 70), 2.0, 0.25 }
W.Terrain = { [M.Grass] = C3(66, 104, 50), [M.LeafyGrass] = C3(58, 96, 44), [M.Mud] = C3(80, 66, 46), [M.Limestone] = C3(150, 152, 126),
    [M.Rock] = C3(100, 106, 92), [M.Ground] = C3(86, 76, 56) }
-- (UPDATE 4 wrap-up, RoomGen.DressFor: the room pieces in this world's own language -- mossy temple limestone, a carved idol head on every tall pier)
W.Cover = { Built = true, Stone = M.Limestone, Crown = { World = "Jungle", Name = "Idol", Fit = 0.8, MaxH = 7, Alt = { "RuinB", "Banyan" } } }
W.Contrast = C3(255, 70, 200)
W.EA = { Warn = C3(255, 110, 40), Core = C3(255, 220, 140), Mat = M.Neon }
W.Moods = {
    { Id = "Overgrown", W = 3 },
    { Id = "Monsoon", Name = "Monsoon", W = 2, Sat = 0.8, Fog = C3(120, 140, 150), FogAmt = 0.4, Dens = 1.3, Exp = -0.04 },
    { Id = "GoldenHour", Name = "Golden Hour", W = 2, Acc = 0.11, Fog = C3(240, 190, 110), FogAmt = 0.32, Clock = 0.8 },
    { Id = "EmeraldNight", Name = "Emerald Night", W = 1, Val = 0.86, Acc = 0.33, Fog = C3(30, 90, 70), FogAmt = 0.38, Exp = -0.07 },
}
W.Sky = { Bk = "99927416652726", Dn = "133204665232014", Ft = "110135443312514", Lf = "110799455657287", Rt = "77141455093327", Up = "94999866578413" } -- (UPDATE 4 SKIES v4: tools/hdri_sky.py)
return W
