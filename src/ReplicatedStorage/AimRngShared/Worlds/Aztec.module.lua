--!nocheck
-- SUN EMPIRE (0.87 world): a living jade-and-gold sun city at blazing noon -- feathered serpent heads, carved glyph
-- pillars, a great sun-stone calendar, golden fire braziers, stepped altars, tropical blooms; a stepped pyramid with a
-- temple on top, the sun overhead. (The Sunken Temple is overgrown ruin; this one is alive and monumental.) Sister: Molten.
local K = require(script.Parent.Parent:WaitForChild("WorldKit"))
local C3, M = K.C3, K.M
local P, Solid, Deco, Neon, Wedge = K.P, K.Solid, K.Deco, K.Neon, K.Wedge

local PAVE, STONE, STONE2 = C3(196, 170, 128), C3(186, 156, 112), C3(160, 130, 92)
local JADE, JADE2, GOLD, TERRA, TURQ = C3(50, 150, 110), C3(36, 116, 86), C3(236, 186, 64), C3(184, 92, 60), C3(40, 200, 190)
local FEATHER, FEATHER2, FLOWER = C3(30, 170, 120), C3(220, 60, 60), C3(255, 90, 140)

local W = {}
W.Id = "Aztec"
W.Title = "SUN EMPIRE"
W.TitleColor = C3(255, 210, 70)
W.Sister = "Fire"
W.HazardName = "Sacred Fire"

-- (UPDATE 4 prop pass: real textured models from ReplicatedStorage.WorldProps.Aztec via WorldKit.Prop when the place has
-- them; the part build under each is the fallback. Gameplay boxes measured from the models' height maps.)
local function Serpent(geo, cf, s)
    if K.Prop(geo, "Aztec", "Serpent", cf, s, { { Vector3.new(5, 1.4, 3.8), Vector3.new(0, 0.7, 0) }, { Vector3.new(3.6, 3.4, 3.4), Vector3.new(0, 3.1, 0) } }) then return end
    -- a feathered serpent head on a step: a jade block head with gold eyes, open jaws, fangs, a crest of feathers
    Solid(geo, Vector3.new(5 * s, 1.4 * s, 5 * s), cf * CFrame.new(0, 0.7 * s, 0), STONE2, M.Limestone)
    local h = cf * CFrame.new(0, 3.2 * s, 0)
    Solid(geo, Vector3.new(3.6 * s, 2.6 * s, 4.4 * s), h, JADE, M.Marble)
    Deco(geo, Vector3.new(3.4 * s, 0.9 * s, 2 * s), h * CFrame.new(0, -1.5 * s, -1.4 * s) * CFrame.Angles(math.rad(14), 0, 0), JADE2, M.Marble)
    Deco(geo, Vector3.new(3.0 * s, 0.7 * s, 0.4 * s), h * CFrame.new(0, -0.9 * s, -2.25 * s), C3(60, 20, 20), M.SmoothPlastic)
    for _, sx in ipairs({ -1, 1 }) do
        Neon(geo, Vector3.new(0.8 * s, 0.6 * s, 0.1), h * CFrame.new(sx * 1.0 * s, 0.6 * s, -2.22 * s), GOLD)
        Wedge(geo, Vector3.new(0.3 * s, 0.9 * s, 0.4 * s), h * CFrame.new(sx * 1.1 * s, -1.0 * s, -2.1 * s) * CFrame.Angles(math.pi, 0, 0), C3(240, 236, 220), M.SmoothPlastic)
        Deco(geo, Vector3.new(0.4 * s, 1.2 * s, 1.2 * s), h * CFrame.new(sx * 1.85 * s, 0.4 * s, -0.8 * s), GOLD, M.Metal)
    end
    for k = -3, 3 do
        local a = k * 0.32
        Wedge(geo, Vector3.new(0.4 * s, 2.8 * s, 1.2 * s), h * CFrame.new(0, 1.4 * s, 1.4 * s) * CFrame.Angles(math.rad(-25), 0, a) * CFrame.new(0, 1.2 * s, 0),
            (k % 2 == 0) and FEATHER or FEATHER2, M.SmoothPlastic)
    end
end
local function GlyphPillar(geo, cf, s)
    if K.Prop(geo, "Aztec", "GlyphPillar", cf, s, { { Vector3.new(2.4, 10.5, 2.4), Vector3.new(0, 5.25, 0) } }) then return end
    -- a square stone pillar banded with jade + gold glyph courses, a flared capital
    local h = 10 * s
    Solid(geo, Vector3.new(2.2 * s, h, 2.2 * s), cf * CFrame.new(0, h / 2, 0), STONE, M.Limestone)
    for k = 0, 3 do
        local y = (1.8 + k * 2.2) * s
        Deco(geo, Vector3.new(2.3 * s, 0.6 * s, 2.3 * s), cf * CFrame.new(0, y, 0), (k % 2 == 0) and JADE or TERRA, M.Marble)
        for f = 0, 3 do Deco(geo, Vector3.new(0.5 * s, 0.5 * s, 0.06), cf * CFrame.Angles(0, f * math.pi / 2, 0) * CFrame.new(0, y + 0.9 * s, -1.13 * s) * CFrame.Angles(0, 0, math.rad(45)), GOLD, M.Metal) end
    end
    Deco(geo, Vector3.new(3.2 * s, 0.8 * s, 3.2 * s), cf * CFrame.new(0, h + 0.4 * s, 0), STONE2, M.Limestone)
    Deco(geo, Vector3.new(2.6 * s, 0.4 * s, 2.6 * s), cf * CFrame.new(0, h + 1 * s, 0), GOLD, M.Metal)
end
local function SunStone(geo, cf, s)
    if K.Prop(geo, "Aztec", "SunStone", cf, s, { { Vector3.new(4, 1.6, 3), Vector3.new(0, 0.8, 0) }, { Vector3.new(6.6, 7, 1.4), Vector3.new(0, 4.6, 0) } }) then return end
    -- the calendar stone on edge: concentric carved rings, a gold sun face at the centre, glyph blocks round the rim
    local c = cf * CFrame.new(0, 4.4 * s, 0)
    Solid(geo, Vector3.new(4 * s, 1.6 * s, 3 * s), cf * CFrame.new(0, 0.8 * s, 0), STONE2, M.Limestone)
    Solid(geo, Vector3.new(1.2 * s, 8 * s, 8 * s), c * CFrame.Angles(0, math.rad(90), 0), STONE, M.Limestone, Enum.PartType.Cylinder)
    Deco(geo, Vector3.new(1.3 * s, 6 * s, 6 * s), c * CFrame.Angles(0, math.rad(90), 0), STONE2, M.Limestone, Enum.PartType.Cylinder)
    Deco(geo, Vector3.new(1.4 * s, 4.6 * s, 4.6 * s), c * CFrame.Angles(0, math.rad(90), 0), JADE, M.Marble, Enum.PartType.Cylinder)
    Neon(geo, Vector3.new(1.5 * s, 2.4 * s, 2.4 * s), c * CFrame.Angles(0, math.rad(90), 0), GOLD, 0.1, Enum.PartType.Cylinder)
    for k = 0, 11 do
        local a = k / 12 * math.pi * 2
        Deco(geo, Vector3.new(0.6 * s, 0.6 * s, 1.3 * s), c * CFrame.Angles(0, 0, a) * CFrame.new(0, 3.5 * s, 0), (k % 2 == 0) and TURQ or TERRA, M.SmoothPlastic)
    end
end
local function Brazier(geo, cf, s, lit)
    if K.Prop(geo, "Aztec", "Brazier", cf, s, { { Vector3.new(2.6, 1.2, 2.6), Vector3.new(0, 0.6, 0) }, { Vector3.new(1.6, 4.4, 1.6), Vector3.new(0, 2.2, 0) } }) then
        local ember = Neon(geo, Vector3.new(0.25 * s, 2 * s, 2 * s), K.Up(cf * CFrame.new(0, 4.75 * s, 0)), C3(255, 150, 50), 0, Enum.PartType.Cylinder) -- (the embers in the bowl)
        if lit then K.Light(ember, C3(255, 170, 80), 24, 1.2) end
        return
    end
    -- a stepped stone stand with a gold bowl of fire
    Solid(geo, Vector3.new(2.6 * s, 1.2 * s, 2.6 * s), cf * CFrame.new(0, 0.6 * s, 0), STONE2, M.Limestone)
    Solid(geo, Vector3.new(1.4 * s, 2.4 * s, 1.4 * s), cf * CFrame.new(0, 2.4 * s, 0), STONE, M.Limestone)
    local bowl = Deco(geo, Vector3.new(1.2 * s, 2.8 * s, 2.8 * s), K.Up(cf * CFrame.new(0, 4.2 * s, 0)), GOLD, M.Metal, Enum.PartType.Cylinder)
    local ember = Neon(geo, Vector3.new(0.3 * s, 2.4 * s, 2.4 * s), K.Up(cf * CFrame.new(0, 4.85 * s, 0)), C3(255, 150, 50), 0, Enum.PartType.Cylinder)
    local f = Instance.new("Fire"); f.Size = 4 * s; f.Heat = 6; f.Color = C3(255, 150, 50); f.SecondaryColor = C3(255, 60, 20); f.Parent = ember
    if lit then K.Light(ember, C3(255, 170, 80), 24, 1.2) end
    return bowl
end
local function Altar(geo, cf, s)
    if K.Prop(geo, "Aztec", "Altar", cf, s, { { Vector3.new(7, 1.2, 6), Vector3.new(0, 0.6, 0) }, { Vector3.new(5.2, 2.4, 4.4), Vector3.new(0, 1.2, 0) }, { Vector3.new(3.4, 3.4, 2.8), Vector3.new(0, 1.7, 0) } }) then return end
    -- a low stepped altar (cover) with jade inlays and tropical blooms at its corners
    for k = 0, 2 do
        Solid(geo, Vector3.new((7 - k * 1.8) * s, 1 * s, (4.4 - k * 1.1) * s), cf * CFrame.new(0, (k + 0.5) * s, 0), (k % 2 == 0) and STONE or STONE2, M.Limestone)
    end
    Deco(geo, Vector3.new(3.4 * s, 0.1, 0.4 * s), cf * CFrame.new(0, 1.0 * s, -2.21 * s), JADE, M.Marble)
    for _, sx in ipairs({ -1, 1 }) do
        for k = 0, 2 do
            Deco(geo, Vector3.new(0.2 * s, 1.8 * s, 0.8 * s), cf * CFrame.new(sx * 3.6 * s, 0.9 * s, -1.8 * s) * CFrame.Angles(0, k * 1.05, math.rad(20)), C3(40, 140, 70), M.Grass)
        end
        Deco(geo, Vector3.one * 0.8 * s, cf * CFrame.new(sx * 3.6 * s, 1.9 * s, -1.8 * s), FLOWER, M.SmoothPlastic, Enum.PartType.Ball)
    end
end
local function Pyramid(parent, base, s)
    -- (UPDATE 4: one real model replaces the stacked parts when the place has it -- WorldProps.Aztec.Pyramid, stored at s = 1)
    if K.Prop(parent, "Aztec", "Pyramid", CFrame.new(base), s) then return end
    -- a stepped pyramid: nine tiers, a stair down the front, a temple with a jade roof and gold trim on top
    for k = 0, 8 do
        local w = (60 - k * 5.6) * s
        P(parent, { Size = Vector3.new(w, 4 * s, w), CFrame = CFrame.new(base + Vector3.new(0, (k + 0.5) * 4 * s, 0)), Color = (k % 2 == 0) and STONE or STONE2, Material = M.Limestone })
        P(parent, { Size = Vector3.new(w + 0.2, 0.6 * s, w + 0.2), CFrame = CFrame.new(base + Vector3.new(0, (k + 1) * 4 * s - 0.3 * s, 0)), Color = (k % 3 == 0) and JADE or TERRA, Material = M.SmoothPlastic })
    end
    -- the stair: real steps climbing the front face from the ground to the temple (one tilted slab read as a falling wall)
    for i = 0, 17 do
        local h = (i + 1) * 2 * s
        P(parent, { Size = Vector3.new(10 * s, h, 1.3 * s), CFrame = CFrame.new(base + Vector3.new(0, h / 2, -30 * s - 0.65 * s + i * 1.25 * s)), Color = (i % 2 == 0) and STONE2 or STONE, Material = M.Limestone })
    end
    for _, sx in ipairs({ -1, 1 }) do -- (balustrades with serpent-gold caps up both sides)
        P(parent, { Size = Vector3.new(1.4 * s, 2 * s, 26 * s), CFrame = CFrame.new(base + Vector3.new(sx * 5.7 * s, 19 * s, -19.5 * s)) * CFrame.Angles(math.rad(-57), 0, 0), Color = JADE, Material = M.Marble })
    end
    local top = base + Vector3.new(0, 36 * s, 0)
    P(parent, { Size = Vector3.new(14 * s, 10 * s, 12 * s), CFrame = CFrame.new(top + Vector3.new(0, 5 * s, 0)), Color = STONE, Material = M.Limestone })
    P(parent, { Size = Vector3.new(16 * s, 3 * s, 14 * s), CFrame = CFrame.new(top + Vector3.new(0, 11.5 * s, 0)), Color = JADE, Material = M.Marble })
    P(parent, { Size = Vector3.new(16.2 * s, 0.8 * s, 14.2 * s), CFrame = CFrame.new(top + Vector3.new(0, 10 * s, 0)), Color = GOLD, Material = M.Metal })
    P(parent, { Size = Vector3.new(5 * s, 6 * s, 0.4 * s), CFrame = CFrame.new(top + Vector3.new(0, 3.5 * s, -6.1 * s)), Color = C3(30, 20, 16), Material = M.SmoothPlastic })
end

W.Props = {
    Cover = { function(geo, _, rng, pos) Altar(geo, CFrame.new(pos) * K.Yaw(rng), 0.9) end, function(geo, _, rng, pos) Serpent(geo, CFrame.new(pos) * K.Yaw(rng), 1) end },
    Tall = { function(geo, _, rng, pos) GlyphPillar(geo, CFrame.new(pos) * K.Yaw(rng), 1) end, function(geo, _, rng, pos) SunStone(geo, CFrame.new(pos) * K.Yaw(rng), 0.9) end },
    Air = {},
}
W.Landmarks = {
    function(geo, _, rng, c) -- THE SERPENT COURT: four serpent heads facing the plaza, braziers between them
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            local p = c + Vector3.new(math.cos(a) * 31, 0, math.sin(a) * 31)
            Serpent(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1)
            Brazier(geo, CFrame.new(c + Vector3.new(math.cos(a + 0.7) * 33, 0, math.sin(a + 0.7) * 33)), 1, i == 0)
        end
    end,
    function(geo, _, rng, c) -- THE CALENDAR: two sun stones facing each other across the plaza, glyph pillars round it
        SunStone(geo, CFrame.lookAt(c + Vector3.new(-32, 0, 0), c), 1)
        SunStone(geo, CFrame.lookAt(c + Vector3.new(32, 0, 0), c), 1)
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            GlyphPillar(geo, CFrame.new(c + Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32)), 1)
        end
    end,
}
W.Kits = {
    AzSerpent = function(g, cf, s) Serpent(g, cf, s * 0.55) end,
    AzPillar = function(g, cf, s) GlyphPillar(g, cf, s * 0.55) end,
    AzSunStone = function(g, cf, s) SunStone(g, cf, s * 0.5) end,
    AzAltar = function(g, cf, s) Altar(g, cf, s * 0.55) end,
    AzBrazier = function(g, cf, s) Brazier(g, cf, s * 0.6, false) end,
}
W.Templates = {
    { Name = "Sun Plaza", Rim = "Ruins", RimMat = { M.Limestone, M.Grass }, Ground = M.Limestone, Patch = { M.Grass, M.Sandstone },
        Edge = { "AzAltar", "AzSerpent", "AzBrazier" }, RimKit = { "AzPillar", "AzSunStone", "AzSerpent" }, Hero = "AzPyramid", Glow = { AzBrazier = C3(255, 160, 70) },
        RimSurface = true }, -- (UPDATE 4 wrap-up: the sun stones + pillars stand ON the rim hills, not buried in them -- MapShell.OnSurface)
    { Name = "Jade Terraces", Rim = "Cliffs", RimMat = { M.Limestone, M.LeafyGrass }, RimAccent = M.Grass, PartyRim = "AzPillar", Ground = M.Grass, Patch = { M.Limestone, M.LeafyGrass },
        Edge = { "AzAltar", "AzSerpent" }, RimKit = { "AzPillar", "AzPillar", "AzSunStone" }, Hero = "AzPyramid" },
    { Name = "Serpent Causeway", Rim = "Edge", RimMat = { M.Limestone, M.Rock }, Ground = M.Limestone, Patch = { M.Sandstone, M.Grass },
        Edge = { "AzSerpent", "AzBrazier", "AzAltar" }, RimKit = { "AzSerpent", "AzPillar", "AzBrazier" }, Hero = "AzPyramid", Glow = { AzBrazier = C3(255, 160, 70) } },
}
W.Heroes = {}
function W.Heroes.AzPyramid(fx, ctx)
    local c = Vector3.new(30, 0, ctx.zC + ctx.half * 3.5)
    Pyramid(fx, c, 3.4)
    for _, sx in ipairs({ -1, 1 }) do
        local m = K.Model(fx, "HeroPillar")
        GlyphPillar(m, CFrame.new(c + Vector3.new(sx * 130, 0, -90)), 4)
        K.NoCollide(m)
    end
end
W.Vista = { Ground = C3(50, 110, 60), GroundMat = M.Grass, Peak = C3(40, 96, 56), PeakMat = M.Grass, Tip = GOLD }
function W.VistaFn(fx, Pf, centre, gy, zC, r)
    -- jungle canopy around the city, smaller pyramids poking out of it, a causeway of pillars
    -- (UPDATE 4 VISTA: real models to the horizon -- WorldKit.Far props + tinted scanned mountains; the part version
    -- below stays as the fallback for an unsaved place)
    if K.HasProp("Jungle", "Banyan") and K.HasProp("Aztec", "Pyramid") then
        for _ = 1, 18 do -- the jungle round the city (the Sunken Temple's banyans)
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(260, 900)
            K.Far(fx, "Jungle", "Banyan", CFrame.new(centre + Vector3.new(math.cos(a) * d, -2, math.sin(a) * d)) * CFrame.Angles(0, r:NextNumber(0, 6.28), 0), 2.4 + d / 240)
        end
        for _ = 1, 4 do -- far pyramids poking out of it
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(560, 1000)
            local p = centre + Vector3.new(math.cos(a) * d, -2, math.sin(a) * d)
            K.Far(fx, "Aztec", "Pyramid", CFrame.lookAt(p, Vector3.new(centre.X, p.Y, centre.Z)), r:NextNumber(1.3, 2.1))
        end
        for k = 1, 4 do
            local a, d = (k / 4 + r:NextNumber(-0.08, 0.08)) * math.pi * 2, r:NextNumber(1000, 1250)
            K.Mesh(fx, "Mountain", CFrame.new(centre + Vector3.new(math.cos(a) * d, -40, math.sin(a) * d)) * CFrame.Angles(0, a + math.pi / 2, 0), r:NextNumber(260, 380), C3(86, 124, 86), { Shadow = false })
        end
        return true
    end
    for _ = 1, 36 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(280, 1100)
        local sz = r:NextNumber(50, 110) * (d / 600)
        Pf({ Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.one * sz, CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * d, sz * 0.12, math.sin(a) * d)),
            Color = (r:NextNumber() < 0.5) and C3(40, 120, 60) or C3(56, 140, 70), Material = M.Grass })
    end
    for _ = 1, 5 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(500, 1000)
        local p = centre + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
        for k = 0, 4 do
            local w = 90 - k * 16
            Pf({ Name = "FarPyramid", Size = Vector3.new(w, 12, w), CFrame = CFrame.new(p + Vector3.new(0, 6 + k * 12, 0)), Color = (k % 2 == 0) and STONE or STONE2, Material = M.Limestone })
        end
    end
    return true
end
function W.Scenery(fx, theme, rng, zC, arena, height)
    -- heat shimmer + bright pollen; tropical birds wheeling high overhead (client)
    local src = K.Box(fx, Vector3.new(arena, 1, arena), CFrame.new(0, 8, zC))
    K.Emit(src, { Color = ColorSequence.new(C3(255, 230, 140), C3(255, 140, 160)), LightEmission = 0.6, Rate = 10, Lifetime = NumberRange.new(5, 8),
        Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.18, 0.08), Transparency = NumberSequence.new(0.2, 1) })
    -- (UPDATE 4 LIFE: real macaws; the wing beat = the mesh's span squeezed in and out, gliding between beats)
    local birds = {}
    for i = 1, 5 do
        local b = { Rad = rng:NextNumber(arena * 0.4, arena * 0.8), H = height + rng:NextNumber(10, 40), Ph = rng:NextNumber(0, 6), Sp = rng:NextNumber(0.15, 0.3) }
        local real, body, base = K.Life(fx, "Aztec", "Macaw", rng:NextNumber(0.85, 1.15))
        if real then
            b.M, b.P, b.Base = real, body, base
        else
            local m = K.Model(fx, "Macaw")
            local col = (i % 2 == 0) and FEATHER2 or C3(40, 120, 230)
            b.B = Deco(m, Vector3.new(0.7, 0.7, 2), CFrame.new(), col, M.SmoothPlastic)
            b.L = Deco(m, Vector3.new(2.4, 0.1, 1.0), CFrame.new(), C3(255, 210, 60), M.SmoothPlastic)
            b.R = Deco(m, Vector3.new(2.4, 0.1, 1.0), CFrame.new(), col, M.SmoothPlastic)
        end
        table.insert(birds, b)
    end
    K.Live(fx, function(t)
        for _, b in ipairs(birds) do
            local a = t * b.Sp + b.Ph
            local pos = Vector3.new(math.cos(a) * b.Rad, b.H + math.sin(t * 0.6 + b.Ph) * 4, zC + math.sin(a) * b.Rad)
            local cf = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
            if b.M then
                -- (a few beats, then a glide: big birds don't flap all the time)
                local beat = (math.sin(t * 0.5 + b.Ph) > -0.2) and math.sin(t * 6 + b.Ph) or 0
                b.P.Size = b.Base * Vector3.new(1 - 0.3 * math.abs(beat), 1 + 0.2 * math.max(beat, 0), 1)
                b.M:PivotTo(cf * CFrame.Angles(0, 0, -0.25))
            else
                local flap = math.sin(t * 6 + b.Ph) * 0.5
                b.B.CFrame = cf
                b.L.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-1.4, 0, 0)
                b.R.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(1.4, 0, 0)
            end
        end
    end)
end
function W.SetPiece(geo, deco, c, rng, F)
    -- THE SUN TEMPLE: serpent heads and burning braziers round the fight floor, the great pyramid over the far side
    K.Ring(12, 100, c + Vector3.new(0, F, 0), function(p, a, i)
        if i % 2 == 0 then Serpent(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1.6) else Brazier(geo, CFrame.new(p), 1.5, i == 3) end
    end)
    -- (UPDATE 4: the real pyramid, 3.2x (~124 tall) and further back: seen in play at 1.6x the rim hills hid it whole and
    -- only the sun disc floated over them; its base stays on the ground and the sun rises with its apex)
    local real = K.HasProp("Aztec", "Pyramid")
    Pyramid(deco, c + Vector3.new(0, F, real and 230 or 180), real and 3.2 or 1.6)
    local sun = Neon(deco, Vector3.new(1, 30, 30), CFrame.new(c + (real and Vector3.new(0, F + 150, 225) or Vector3.new(0, F + 90, 175))) * CFrame.Angles(0, math.rad(90), 0), GOLD, 0.05, Enum.PartType.Cylinder)
    K.Light(sun, C3(255, 220, 140), 70, 1.0)
    return GOLD
end

W.Theme = {
    Name = "Sun Empire",
    Floor = { Color = C3(176, 152, 112), Material = M.Limestone },
    FloorAlt = { Color = C3(70, 130, 70), Material = M.Grass },
    Wall = { Color = STONE, Material = M.Limestone },
    WallTrim = { Color = JADE, Material = M.Marble },
    Ceiling = { Color = STONE2, Material = M.Limestone },
    Prop = { Color = STONE2, Material = M.Limestone },
    PropAlt = { Color = TERRA, Material = M.SmoothPlastic },
    Hazard = { Color = C3(255, 120, 40), Material = M.CrackedLava },
    Accent = TURQ, Light = C3(255, 236, 190), LampBrightness = 1.2, LampRange = 50,
    OpenSky = true,
}
W.Ambience = { Mote = C3(255, 230, 140), Mote2 = TURQ, MoteRise = true, Glow = GOLD }
W.Light = { ClockTime = 12.6, Brightness = 2.1, Ambient = C3(138, 138, 112), OutdoorAmbient = C3(150, 156, 132),
    FogColor = C3(190, 210, 200), FogStart = 260, FogEnd = 1100, Exposure = -0.08, EnvDiffuse = 0.35,
    BloomIntensity = 0.28, BloomThreshold = 1.45, BloomSize = 20,
    CCBrightness = 0, CCContrast = 0.12, CCSaturation = 0.12, CCTint = C3(255, 250, 236) }
W.Atmo = { 0.28, C3(200, 226, 216), C3(80, 140, 200), 1.2, 0.5 }
W.Terrain = { [M.Limestone] = C3(170, 146, 108), [M.Grass] = C3(70, 132, 66), [M.LeafyGrass] = C3(56, 120, 56), [M.Sandstone] = C3(190, 150, 104),
    [M.Rock] = C3(150, 130, 100) }
-- (UPDATE 4 wrap-up, RoomGen.DressFor: the room pieces in this world's own language -- every tall pillar IS a carved glyph pillar, a brazier on top)
W.Cover = { Built = true, Stone = M.Limestone, Clad = { World = "Aztec", Name = "GlyphPillar" }, Crown = { World = "Aztec", Name = "Brazier", Fit = 0.6, MaxH = 4.5, Alt = { "SunStone", "Serpent" } } }
W.Contrast = C3(255, 40, 160)
W.EA = { Warn = C3(255, 60, 30), Core = C3(255, 230, 150), Mat = M.Neon }
W.Moods = {
    { Id = "Zenith", W = 3 },
    { Id = "Eclipse", Name = "Sun Eclipse", W = 1, Val = 0.85, Acc = 0.08, Fog = C3(120, 70, 40), FogAmt = 0.4, Exp = -0.1 },
    { Id = "Rain", Name = "Rain Season", W = 2, Sat = 0.85, Fog = C3(140, 170, 160), FogAmt = 0.4, Dens = 1.3, Exp = -0.03 },
    { Id = "Jade", Name = "Jade Dusk", W = 2, Acc = 0.44, Fog = C3(80, 150, 130), FogAmt = 0.32, Clock = 4.5 },
}
W.Sky = { Bk = "72227051697970", Dn = "132516222689191", Ft = "125430536052213", Lf = "95496384716305", Rt = "139293198149123", Up = "90042831261273" } -- (UPDATE 4 SKIES v4: tools/hdri_sky.py)
return W
