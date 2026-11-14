--!nocheck
-- SUN DUNES (0.87 world): an ancient desert empire at golden hour -- sandstone obelisks with gold caps, fallen columns,
-- cloth sun shades, palms, pottery behind low walls; a great stepped pyramid with a burning capstone, blowing sand.
-- Gold + lapis blue (Neon Flats owns orange neon). Sister: Neon Flats.
local K = require(script.Parent.Parent:WaitForChild("WorldKit"))
local C3, M = K.C3, K.M
local P, Solid, Deco, Neon, Wedge = K.P, K.Solid, K.Deco, K.Neon, K.Wedge

local SAND, STONE, STONE2, DARK = C3(214, 180, 128), C3(204, 166, 112), C3(180, 140, 92), C3(140, 102, 66)
local GOLD, LAPIS, CLOTH, CLOTH2 = C3(236, 186, 74), C3(46, 90, 180), C3(196, 60, 52), C3(230, 214, 180)
local PALM, FROND = C3(120, 90, 60), C3(84, 130, 60)

local W = {}
W.Id = "Desert"
W.Title = "SUN DUNES"
W.TitleColor = C3(255, 200, 90)
W.Sister = "Flats"
W.HazardName = "Quicksand"

-- (UPDATE 4 prop pass: real textured models from ReplicatedStorage.WorldProps.Desert via WorldKit.Prop when the place has
-- them; the part build under each is the fallback. Gameplay boxes measured from the models' height maps.)
local function Obelisk(geo, cf, s)
    if K.Prop(geo, "Desert", "Obelisk", cf, s, { { Vector3.new(5, 1.5, 5), Vector3.new(0, 0.75, 0) }, { Vector3.new(2.4, 14.5, 2.4), Vector3.new(0, 8.75, 0) } }) then return end
    -- a tapering sandstone needle on a stepped base, lapis glyph bands, a gold pyramidion
    Solid(geo, Vector3.new(4.4 * s, 1.2 * s, 4.4 * s), cf * CFrame.new(0, 0.6 * s, 0), STONE2, M.Sandstone)
    Solid(geo, Vector3.new(3.4 * s, 1 * s, 3.4 * s), cf * CFrame.new(0, 1.7 * s, 0), STONE, M.Sandstone)
    for k = 0, 4 do
        local w = (2.4 - k * 0.22) * s
        Solid(geo, Vector3.new(w, 2.6 * s, w), cf * CFrame.new(0, (3.5 + k * 2.6) * s, 0), STONE, M.Sandstone)
    end
    for k = 0, 2 do Deco(geo, Vector3.new((2.3 - k * 0.5) * s, 0.35 * s, (2.3 - k * 0.5) * s + 0.06), cf * CFrame.new(0, (4.4 + k * 3.6) * s, 0), LAPIS, M.SmoothPlastic) end
    for k = 0, 3 do
        Wedge(geo, Vector3.new(1.3 * s, 1.6 * s, 0.65 * s), cf * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 15.2 * s, -0.33 * s), GOLD, M.Metal)
    end
end
local function Columns(geo, cf, s)
    if K.Prop(geo, "Desert", "Columns", cf, s, { { Vector3.new(2.2, 8, 2.4), Vector3.new(0, 4, 1.1) }, { Vector3.new(6, 2.2, 5), Vector3.new(0, 1.1, -0.4) } }) then return end
    -- a broken colonnade: one standing column with a lotus capital, a snapped stump, drums fallen in the sand
    for _, c in ipairs({ { -2.6, 7 }, { 2.6, 2.6 } }) do
        K.Pillar(geo, 2.2 * s, c[2] * s, cf * CFrame.new(c[1] * s, 0, 0), STONE, M.Sandstone, true)
        Deco(geo, Vector3.new(2.8 * s, 0.5 * s, 2.8 * s), cf * CFrame.new(c[1] * s, 0.25 * s, 0), STONE2, M.Sandstone)
        Deco(geo, Vector3.new(0.3 * s, 2.3 * s, 2.3 * s), K.Up(cf * CFrame.new(c[1] * s, (c[2] - 1.2) * s, 0)), LAPIS, M.SmoothPlastic, Enum.PartType.Cylinder)
    end
    Deco(geo, Vector3.new(3.4 * s, 1.0 * s, 3.4 * s), cf * CFrame.new(-2.6 * s, 7.4 * s, 0), STONE2, M.Sandstone)
    Solid(geo, Vector3.new(2.2 * s, 2.1 * s, 2.1 * s), cf * CFrame.new(1.2 * s, 1.05 * s, 3.2 * s) * CFrame.Angles(0, 0.5, math.rad(90)), STONE, M.Sandstone, Enum.PartType.Cylinder)
    Solid(geo, Vector3.new(2.2 * s, 2.1 * s, 2.1 * s), cf * CFrame.new(3.8 * s, 1.05 * s, 2.6 * s) * CFrame.Angles(0, 1.1, math.rad(90)), STONE2, M.Sandstone, Enum.PartType.Cylinder)
end
local function Shade(geo, cf, s)
    if K.Prop(geo, "Desert", "Shade", cf, s * 1.2, { { Vector3.new(4, 1.8, 2.4), Vector3.new(0, 0.9, -0.2) } }) then return end
    -- a market sun shade: four poles, a striped cloth roof, crates and a pot under it (the crates are cover)
    for _, x in ipairs({ -3, 3 }) do
        for _, z in ipairs({ -2.4, 2.4 }) do Deco(geo, Vector3.new(0.3 * s, 6 * s, 0.3 * s), cf * CFrame.new(x * s, 3 * s, z * s), PALM, M.Wood) end
    end
    for k = 0, 3 do
        Deco(geo, Vector3.new(6.8 * s, 0.12 * s, 1.3 * s), cf * CFrame.new(0, (6 - math.abs(k - 1.5) * 0.15) * s, (-1.95 + k * 1.3) * s) * CFrame.Angles(math.rad((k - 1.5) * 3), 0, 0),
            (k % 2 == 0) and CLOTH or CLOTH2, M.SmoothPlastic)
    end
    Solid(geo, Vector3.new(2.4 * s, 2 * s, 2.4 * s), cf * CFrame.new(-1.6 * s, 1 * s, 0.4 * s), DARK, M.WoodPlanks)
    Solid(geo, Vector3.new(2 * s, 1.6 * s, 2 * s), cf * CFrame.new(1.2 * s, 0.8 * s, -0.6 * s) * CFrame.Angles(0, 0.4, 0), C3(160, 118, 76), M.WoodPlanks)
    Deco(geo, Vector3.one * 1.4 * s, cf * CFrame.new(1.4 * s, 2.2 * s, -0.5 * s), C3(176, 96, 60), M.Sandstone, Enum.PartType.Ball)
end
local function Palm(geo, cf, s)
    if K.Prop(geo, "Desert", "Palm", cf, s, { { Vector3.new(0.9, 3, 0.9), Vector3.new(0, 1.5, 0) } }) then return end
    -- a leaning palm: a segmented trunk curving up, a crown of drooping fronds, dates
    local p = cf
    for k = 0, 6 do
        p = p * CFrame.new(0, 1.5 * s, 0) * CFrame.Angles(0, 0, math.rad(3.5))
        local d = Deco(geo, Vector3.new(0.9 * s, 1.6 * s, 0.9 * s), p * CFrame.new(0, -0.75 * s, 0), (k % 2 == 0) and PALM or C3(104, 78, 52), M.Wood)
        if k < 2 then d.CanCollide = true; d.CanQuery = true end
    end
    for k = 0, 6 do
        local a = k / 7 * math.pi * 2
        Wedge(geo, Vector3.new(0.15 * s, 0.9 * s, 4.6 * s), p * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.1 * s, -2.1 * s) * CFrame.Angles(math.rad(-22), 0, 0), FROND, M.Grass)
    end
    for k = 0, 2 do Deco(geo, Vector3.one * 0.5 * s, p * CFrame.Angles(0, k * 2.1, 0) * CFrame.new(0.5 * s, -0.4 * s, 0), C3(150, 70, 40), M.SmoothPlastic, Enum.PartType.Ball) end
end
local function PotWall(geo, cf, s)
    -- a low mud-brick wall with tall clay jars along it (the wall is cover)
    Solid(geo, Vector3.new(8 * s, 2.6 * s, 1.4 * s), cf * CFrame.new(0, 1.3 * s, 0), STONE2, M.Sandstone)
    Deco(geo, Vector3.new(8.2 * s, 0.3 * s, 1.6 * s), cf * CFrame.new(0, 2.7 * s, 0), STONE, M.Sandstone)
    if K.Prop(geo, "Desert", "Jars", cf * CFrame.new(-0.6 * s, 0, -1.4 * s), s * 1.15) then return end -- (real clay jars in front of the wall)
    for k, x in ipairs({ -2.8, -1.4, 1.8 }) do
        local h = (k == 2) and 2.4 or 3
        Deco(geo, Vector3.new(h * s, 1.5 * s, 1.5 * s), K.Up(cf * CFrame.new(x * s, h / 2 * s, -1.4 * s)), C3(184, 100, 62), M.Sandstone, Enum.PartType.Cylinder)
        Deco(geo, Vector3.new(0.3 * s, 1.0 * s, 1.0 * s), K.Up(cf * CFrame.new(x * s, h * s, -1.4 * s)), C3(150, 80, 50), M.Sandstone, Enum.PartType.Cylinder)
        Deco(geo, Vector3.new(0.2 * s, 1.55 * s, 1.55 * s), K.Up(cf * CFrame.new(x * s, h * 0.7 * s, -1.4 * s)), LAPIS, M.SmoothPlastic, Enum.PartType.Cylinder)
    end
end
local function StepPyramid(parent, base, w, h, steps)
    -- (UPDATE 4: one real model when the place has it -- WorldProps.Desert.StepPyramid is stored 100 wide)
    if K.Prop(parent, "Desert", "StepPyramid", CFrame.new(base), w / 100) then return end
    for k = 0, steps - 1 do
        local f = 1 - k / steps
        P(parent, { Size = Vector3.new(w * f, h / steps, w * f), CFrame = CFrame.new(base + Vector3.new(0, (k + 0.5) * h / steps, 0)), Color = (k % 2 == 0) and STONE or STONE2, Material = M.Sandstone })
    end
end

W.Props = {
    Cover = { function(geo, _, rng, pos) PotWall(geo, CFrame.new(pos) * K.Yaw(rng), 1) end, function(geo, _, rng, pos) Columns(geo, CFrame.new(pos) * K.Yaw(rng), 0.9) end,
        function(geo, _, rng, pos) Shade(geo, CFrame.new(pos) * K.Yaw(rng), 0.9) end },
    Tall = { function(geo, _, rng, pos) Obelisk(geo, CFrame.new(pos) * K.Yaw(rng), 0.9) end, function(geo, _, rng, pos) Palm(geo, CFrame.new(pos) * K.Yaw(rng), 1) end },
    Air = {},
}
W.Landmarks = {
    function(geo, _, rng, c) -- AVENUE OF OBELISKS: four needles round the plaza, jar walls between
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            Obelisk(geo, CFrame.new(c + Vector3.new(math.cos(a) * 31, 0, math.sin(a) * 31)), 0.85)
        end
    end,
    function(geo, _, rng, c) -- THE OASIS: palms round the plaza and a ring of fallen columns
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2 + 0.3
            local p = c + Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32)
            if i % 2 == 0 then Palm(geo, CFrame.new(p) * CFrame.Angles(0, a + math.pi, 0), 1) else Columns(geo, CFrame.lookAt(p, c), 0.8) end
        end
    end,
}
W.Kits = {
    DsObelisk = function(g, cf, s) Obelisk(g, cf, s * 0.55) end,
    DsColumns = function(g, cf, s) Columns(g, cf, s * 0.55) end,
    DsShade = function(g, cf, s) Shade(g, cf, s * 0.55) end,
    DsPalm = function(g, cf, s) Palm(g, cf, s * 0.6) end,
    DsPotWall = function(g, cf, s) PotWall(g, cf, s * 0.55) end,
}
W.Templates = {
    { Name = "Dune Sea", Rim = "Cliffs", RimMat = { M.Sand, M.Sandstone }, PartyRim = "DsObelisk", Ground = M.Sand, Patch = { M.Sandstone, M.Sand },
        Edge = { "DsColumns", "DsPotWall" }, RimKit = { "DsPalm", "DsObelisk", "DsColumns" }, Hero = "DsPyramid" },
    { Name = "Oasis Ruins", Rim = "Ruins", RimMat = { M.Sand, M.Grass }, Ground = M.Sand, Patch = { M.Grass, M.Sandstone },
        Edge = { "DsShade", "DsPotWall", "DsColumns" }, RimKit = { "DsPalm", "DsPalm", "DsColumns" }, Hero = "DsPyramid" },
    { Name = "Temple Steps", Rim = "Cliffs", RimMat = { M.Sandstone, M.Rock }, RimAccent = M.Sand, PartyRim = "DsColumns", Ground = M.Sandstone, Patch = { M.Sand, M.Rock },
        Edge = { "DsColumns", "DsObelisk", "DsShade" }, RimKit = { "DsObelisk", "DsColumns" }, Hero = "DsPyramid" },
}
W.Heroes = {}
function W.Heroes.DsPyramid(fx, ctx)
    -- a great stepped pyramid on the far side, its gold capstone burning in the low sun, a smaller one beside it
    local c = Vector3.new(40, 0, ctx.zC + ctx.half * 4)
    StepPyramid(fx, c, 300, 170, 14)
    local cap = P(fx, { Size = Vector3.new(26, 14, 26), CFrame = CFrame.new(c + Vector3.new(0, 177, 0)), Color = GOLD, Material = M.Neon, Transparency = 0.1 })
    StepPyramid(fx, c + Vector3.new(-260, 0, 70), 170, 96, 9)
    P(fx, { Size = Vector3.new(14, 8, 14), CFrame = CFrame.new(c + Vector3.new(-260, 100, 70)), Color = GOLD, Material = M.Metal })
    return cap
end
W.Vista = { Ground = C3(206, 168, 116), GroundMat = M.Sand, Peak = C3(196, 150, 100), PeakMat = M.Sand, Tip = C3(226, 190, 136) }
function W.VistaFn(fx, Pf, centre, gy, zC, r)
    -- dunes rolling away: long, low, half-buried ellipsoids in two tones
    -- (UPDATE 4 VISTA: real models to the horizon -- WorldKit.Far props + tinted scanned mountains; the part version
    -- below stays as the fallback for an unsaved place)
    if K.HasMesh("CliffC") then
        for _ = 1, 16 do -- dunes rolling away
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(300, 1000)
            local w = r:NextNumber(180, 420)
            Pf({ Name = "Dune", Shape = Enum.PartType.Ball, Size = Vector3.new(w, w, w), CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * d, -w * 0.42, math.sin(a) * d)),
                Color = (r:NextNumber() < 0.5) and C3(214, 176, 122) or C3(196, 152, 104), Material = M.Sand })
        end
        for k = 1, 6 do -- red sandstone mesas on the horizon (the scanned desert cliff)
            local a, d = (k / 6 + r:NextNumber(-0.05, 0.05)) * math.pi * 2, r:NextNumber(780, 1150)
            K.Mesh(fx, "CliffC", CFrame.new(centre + Vector3.new(math.cos(a) * d, -20, math.sin(a) * d)) * CFrame.Angles(0, a + math.pi / 2, 0), r:NextNumber(280, 440), C3(206, 150, 104), { Shadow = false })
        end
        for _ = 1, 3 do
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(650, 1000)
            K.Far(fx, "Desert", "Obelisk", CFrame.new(centre + Vector3.new(math.cos(a) * d, -2, math.sin(a) * d)), r:NextNumber(2.6, 3.6))
        end
        return true
    end
    for _ = 1, 30 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(300, 1150)
        local w = r:NextNumber(180, 420)
        Pf({ Name = "Dune", Shape = Enum.PartType.Ball, Size = Vector3.new(w, w, w), CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * d, -w * 0.42, math.sin(a) * d)),
            Color = (r:NextNumber() < 0.5) and C3(214, 176, 122) or C3(196, 152, 104), Material = M.Sand })
    end
    for _ = 1, 4 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(700, 1100)
        local p = centre + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
        local h = r:NextNumber(40, 80)
        Pf({ Name = "FarObelisk", Size = Vector3.new(8, h, 8), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)), Color = STONE2, Material = M.Sandstone })
    end
    return true
end
function W.Scenery(fx, theme, rng, zC, arena, height)
    local half = arena / 2
    -- sand blowing across the room on the wind + a fine glitter of dust in the low sun
    local src = K.Box(fx, Vector3.new(4, 10, arena), CFrame.new(-half, 4, zC))
    K.Emit(src, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(230, 196, 140)), Rate = 8, Lifetime = NumberRange.new(5, 7),
        Speed = NumberRange.new(14, 22), SpreadAngle = Vector2.new(6, 6), Size = NumberSequence.new(4, 10), Transparency = NumberSequence.new(0.82, 1),
        EmissionDirection = Enum.NormalId.Right, LightEmission = 0.15 })
    local dust = K.Box(fx, Vector3.new(arena, 1, arena), CFrame.new(0, 8, zC))
    K.Emit(dust, { Color = ColorSequence.new(C3(255, 220, 150)), LightEmission = 0.6, Rate = 8, Lifetime = NumberRange.new(5, 7), Speed = NumberRange.new(0.5, 2),
        SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.18, 0.05), Transparency = NumberSequence.new(0.3, 1), Acceleration = Vector3.new(2, 0, 0) })
    -- banners on poles along the wall tops, rippling in the wind (client)
    local banners = {}
    for i = 1, 10 do
        local a = (i / 10) * math.pi * 2 + 0.2
        local base = Vector3.new(math.cos(a) * half * 1.06, 2, zC + math.sin(a) * half * 1.06) -- (on the ground just outside the arena)
        Deco(fx, Vector3.new(0.4, 12, 0.4), CFrame.new(base + Vector3.new(0, 6, 0)), PALM, M.Wood)
        local cloth = Deco(fx, Vector3.new(0.1, 6, 3.4), CFrame.new(base + Vector3.new(0, 8.4, 1.7)), (i % 2 == 0) and CLOTH or LAPIS, M.SmoothPlastic)
        table.insert(banners, { P = cloth, Base = cloth.CFrame, Ph = i })
    end
    K.Live(fx, function(t)
        for _, b in ipairs(banners) do
            b.P.CFrame = b.Base * CFrame.new(0, 0, -1.7) * CFrame.Angles(0, math.sin(t * 2.6 + b.Ph) * 0.35, 0) * CFrame.new(0, 0, 1.7)
        end
    end)
end
function W.SetPiece(geo, deco, c, rng, F)
    -- THE SUN COURT: obelisks and palms round the fight floor, a pyramid with a burning capstone over the far side
    K.Ring(12, 100, c + Vector3.new(0, F, 0), function(p, a, i)
        if i % 2 == 0 then Obelisk(geo, CFrame.new(p), 1.4) else Palm(geo, CFrame.new(p) * CFrame.Angles(0, a + math.pi, 0), 1.6) end
    end)
    StepPyramid(deco, c + Vector3.new(0, F, 175), 150, 80, 8)
    local cap = Neon(deco, Vector3.new(16, 9, 16), CFrame.new(c + Vector3.new(0, F + 84, 175)), GOLD, 0.05)
    K.Light(cap, C3(255, 210, 120), 70, 1.2)
    return GOLD
end

W.Theme = {
    Name = "Sun Dunes",
    Floor = { Color = C3(206, 172, 122), Material = M.Sand },
    FloorAlt = { Color = C3(190, 150, 104), Material = M.Sandstone },
    Wall = { Color = C3(196, 158, 108), Material = M.Sandstone },
    WallTrim = { Color = C3(150, 112, 72), Material = M.Sandstone },
    Ceiling = { Color = C3(120, 90, 60), Material = M.Sandstone },
    Prop = { Color = C3(200, 162, 110), Material = M.Sandstone },
    PropAlt = { Color = LAPIS, Material = M.SmoothPlastic },
    Hazard = { Color = C3(180, 140, 90), Material = M.Sand },
    Accent = GOLD, Light = C3(255, 226, 170), LampBrightness = 1.2, LampRange = 50,
    OpenSky = true,
}
W.Ambience = { Mote = C3(255, 220, 150), Mote2 = C3(255, 196, 120), MoteRise = false, Glow = GOLD }
-- (UPDATE 4 SKIES: 17.4 -> 16.4 -- past ~17.5 Roblox dims the painted sky; the Lapis mood (+0.6 +-0.4) reached 18.4)
W.Light = { ClockTime = 16.4, Brightness = 2.2, Ambient = C3(160, 132, 104), OutdoorAmbient = C3(196, 156, 116),
    FogColor = C3(206, 156, 106), FogStart = 220, FogEnd = 1050, Exposure = 0.1, EnvDiffuse = 0.3,
    BloomIntensity = 0.3, BloomThreshold = 1.4, BloomSize = 22,
    CCBrightness = 0, CCContrast = 0.12, CCSaturation = 0.06, CCTint = C3(255, 240, 222) }
W.Atmo = { 0.3, C3(240, 186, 126), C3(150, 96, 70), 1.4, 0.4 }
W.Terrain = { [M.Sand] = C3(212, 176, 124), [M.Sandstone] = C3(188, 146, 100), [M.Rock] = C3(150, 112, 80), [M.Ground] = C3(170, 132, 92),
    [M.Grass] = C3(110, 120, 60) }
-- (UPDATE 4 wrap-up, RoomGen.DressFor: the room pieces in this world's own language -- sandstone piers (no more square sand pillars), a small obelisk on each)
W.Cover = { Built = true, Stone = M.Sandstone, Crown = { World = "Desert", Name = "Obelisk", Fit = 0.55, MaxH = 9, Alt = { "Jars", "Palm" } } }
W.Contrast = C3(40, 190, 255)
W.EA = { Warn = C3(255, 70, 40), Core = C3(255, 230, 170), Mat = M.Neon }
W.Moods = {
    { Id = "GoldenHour", W = 3 },
    { Id = "Noon", Name = "High Noon", W = 2, Sat = 0.85, Fog = C3(255, 236, 200), FogAmt = 0.3, Exp = 0.05, Clock = -1.0 },
    { Id = "Sandstorm", Name = "Sandstorm", W = 2, Sat = 0.75, Fog = C3(200, 150, 96), FogAmt = 0.45, Dens = 1.4, Exp = -0.03 },
    { Id = "Lapis", Name = "Lapis Dusk", W = 1, Acc = 0.6, Fog = C3(110, 100, 170), FogAmt = 0.3, Exp = -0.05, Clock = 0.6 },
}
W.Sky = { Bk = "72319344797902", Dn = "126088775087562", Ft = "92686179851203", Lf = "101568049260932", Rt = "137277655273799", Up = "123056368902329" } -- (UPDATE 4 SKIES v4: tools/hdri_sky.py)
return W
