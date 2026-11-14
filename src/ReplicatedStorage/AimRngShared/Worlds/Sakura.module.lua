--!nocheck
-- SAKURA SHRINE (0.87 world): a mountain shrine in old Japan at spring dusk -- vermilion torii gates, stone lanterns,
-- cherry trees in full blossom, white shrine walls under dark tiled roofs, bamboo; a five-tier pagoda, petals on the wind,
-- paper lanterns rising. Sister: Dreamscape.
local K = require(script.Parent.Parent:WaitForChild("WorldKit"))
local C3, M = K.C3, K.M
local P, Solid, Deco, Neon, Wedge = K.P, K.Solid, K.Deco, K.Neon, K.Wedge

local RED, BLACK, STONE, STONE2 = C3(200, 50, 40), C3(36, 30, 32), C3(150, 150, 140), C3(120, 120, 114)
local PLASTER, ROOF, WOOD = C3(226, 220, 206), C3(54, 58, 70), C3(96, 64, 48)
local BLOSSOM, BLOSSOM2, BARK, BAMBOO, LAMP = C3(255, 176, 206), C3(250, 200, 220), C3(70, 50, 46), C3(120, 160, 80), C3(255, 190, 120)

local W = {}
W.Id = "Sakura"
W.Title = "SAKURA SHRINE"
W.TitleColor = C3(255, 160, 200)
W.Sister = "Dream"
W.HazardName = "Koi Pond"

-- (UPDATE 4 prop pass: real textured models from ReplicatedStorage.WorldProps.Sakura via WorldKit.Prop when the place has
-- them; the part build under each is the fallback. Gameplay boxes measured from the models' height maps.)
local function Torii(geo, cf, s)
    if K.Prop(geo, "Sakura", "Torii", cf, s, { { Vector3.new(1.1, 8, 1.1), Vector3.new(-2.5, 4, 0) }, { Vector3.new(1.1, 8, 1.1), Vector3.new(2.5, 4, 0) } }) then return end
    -- two vermilion pillars on black feet, a curved black top beam (kasagi) over a red beam (nuki), a plaque
    for _, sx in ipairs({ -1, 1 }) do
        K.Pillar(geo, 1.0 * s, 9 * s, cf * CFrame.new(sx * 3.2 * s, 0, 0), RED, M.SmoothPlastic, true)
        Deco(geo, Vector3.new(1.4 * s, 0.9 * s, 1.4 * s), cf * CFrame.new(sx * 3.2 * s, 0.45 * s, 0), BLACK, M.SmoothPlastic)
    end
    Deco(geo, Vector3.new(8.6 * s, 0.6 * s, 0.7 * s), cf * CFrame.new(0, 7.4 * s, 0), RED, M.SmoothPlastic)
    Deco(geo, Vector3.new(10 * s, 0.8 * s, 1.1 * s), cf * CFrame.new(0, 9.2 * s, 0), BLACK, M.SmoothPlastic)
    for _, sx in ipairs({ -1, 1 }) do
        Deco(geo, Vector3.new(1.4 * s, 0.6 * s, 1.1 * s), cf * CFrame.new(sx * 5.2 * s, 9.45 * s, 0) * CFrame.Angles(0, 0, sx * math.rad(12)), BLACK, M.SmoothPlastic)
    end
    Deco(geo, Vector3.new(1.0 * s, 1.6 * s, 0.25 * s), cf * CFrame.new(0, 8.3 * s, 0), BLACK, M.SmoothPlastic)
end
local function Toro(geo, cf, s, lit)
    if K.Prop(geo, "Sakura", "Toro", cf, s, { { Vector3.new(2.2, 1, 2.2), Vector3.new(0, 0.5, 0) }, { Vector3.new(1.2, 5, 1.2), Vector3.new(0, 3.5, 0) } }) then
        local glow = Neon(geo, Vector3.new(0.9, 0.7, 0.9) * s, cf * CFrame.new(0, 4 * s, 0), LAMP, 0.1) -- (the flame in the fire box)
        if lit then K.Light(glow, LAMP, 24, 1.0) end
        return
    end
    -- a stone lantern: base, post, a fire box with a warm glow, a wide roof cap and a finial
    Solid(geo, Vector3.new(2 * s, 0.6 * s, 2 * s), cf * CFrame.new(0, 0.3 * s, 0), STONE2, M.Slate)
    Solid(geo, Vector3.new(0.9 * s, 2.6 * s, 0.9 * s), cf * CFrame.new(0, 1.9 * s, 0), STONE, M.Slate)
    Deco(geo, Vector3.new(1.8 * s, 0.4 * s, 1.8 * s), cf * CFrame.new(0, 3.4 * s, 0), STONE2, M.Slate)
    Deco(geo, Vector3.new(1.4 * s, 1.3 * s, 1.4 * s), cf * CFrame.new(0, 4.25 * s, 0), STONE, M.Slate)
    local glow = Neon(geo, Vector3.new(1.45 * s, 0.7 * s, 0.6 * s), cf * CFrame.new(0, 4.25 * s, 0), LAMP, 0.1)
    for k = 0, 3 do Wedge(geo, Vector3.new(2.8 * s, 0.7 * s, 1.4 * s), cf * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 5.25 * s, -0.7 * s), STONE2, M.Slate) end
    Deco(geo, Vector3.one * 0.5 * s, cf * CFrame.new(0, 5.8 * s, 0), STONE, M.Slate, Enum.PartType.Ball)
    if lit then K.Light(glow, LAMP, 24, 1.0) end
end
local function Cherry(geo, cf, s)
    if K.Prop(geo, "Sakura", "Cherry", cf, s, { { Vector3.new(1.4, 6, 1.4), Vector3.new(0, 3, 0) } }) then
        Deco(geo, Vector3.new(0.1, 7 * s, 7 * s), K.Up(cf * CFrame.new(0, 0.05, 0)), BLOSSOM2, M.SmoothPlastic, Enum.PartType.Cylinder, 0.3) -- (fallen petals)
        return
    end
    -- a cherry tree: a dark twisting trunk, spreading branches, clouds of blossom
    K.Pillar(geo, 1.4 * s, 6 * s, cf, BARK, M.Wood, true)
    local top = cf * CFrame.new(0, 6 * s, 0)
    local tips = {}
    for k = 0, 3 do
        local a = k * math.pi / 2 + 0.4
        local tip = (top * CFrame.new(math.cos(a) * 3.6 * s, 2.4 * s, math.sin(a) * 3.6 * s)).Position
        K.Beam(geo, top.Position, tip, 0.6 * s, BARK, M.Wood, true)
        table.insert(tips, tip)
    end
    for k, tip in ipairs(tips) do
        Deco(geo, Vector3.new(5.6, 3.6, 5.6) * s, CFrame.new(tip + Vector3.new(0, 0.8 * s, 0)), (k % 2 == 0) and BLOSSOM or BLOSSOM2, M.SmoothPlastic, Enum.PartType.Ball)
    end
    Deco(geo, Vector3.new(6.4, 4, 6.4) * s, top * CFrame.new(0, 3.8 * s, 0), BLOSSOM, M.SmoothPlastic, Enum.PartType.Ball)
    Deco(geo, Vector3.new(0.1, 7 * s, 7 * s), K.Up(cf * CFrame.new(0, 0.05, 0)), BLOSSOM2, M.SmoothPlastic, Enum.PartType.Cylinder, 0.3) -- (fallen petals)
end
local function ShrineWall(geo, cf, s)
    -- (UPDATE 4: a castle stone wall (ishigaki) model; three plaster-wall generations came out as roofed huts / open frames)
    if K.Prop(geo, "Sakura", "ShrineWall", cf, s, { { Vector3.new(9, 3.4, 2), Vector3.new(0, 1.7, 0) }, { Vector3.new(9, 1.8, 3), Vector3.new(0, 0.9, 0) } }) then return end
    -- a white plaster wall on a stone footing, a little tiled roof with a dark ridge
    Solid(geo, Vector3.new(9 * s, 0.9 * s, 1.6 * s), cf * CFrame.new(0, 0.45 * s, 0), STONE2, M.Slate)
    Solid(geo, Vector3.new(8.6 * s, 2.6 * s, 1.0 * s), cf * CFrame.new(0, 2.2 * s, 0), PLASTER, M.SmoothPlastic)
    for _, sz in ipairs({ -1, 1 }) do
        Wedge(geo, Vector3.new(9.4 * s, 0.6 * s, 1.1 * s), cf * CFrame.new(0, 3.8 * s, sz * 0.55 * s) * CFrame.Angles(0, (sz < 0) and 0 or math.pi, 0), ROOF, M.Slate)
    end
    Deco(geo, Vector3.new(9.6 * s, 0.25 * s, 0.3 * s), cf * CFrame.new(0, 4.15 * s, 0), BLACK, M.Slate)
    for k = -2, 2 do Deco(geo, Vector3.new(0.3 * s, 2.6 * s, 1.04 * s), cf * CFrame.new(k * 2 * s, 2.2 * s, 0), WOOD, M.Wood) end
end
local function Bamboo(geo, cf, s)
    if K.Prop(geo, "Sakura", "Bamboo", cf, s) then return end
    for k = 0, 6 do
        local o = cf * CFrame.new(((k * 37) % 7 - 3) * 0.55 * s, 0, ((k * 53) % 5 - 2) * 0.55 * s)
        local h = (9 + (k % 3) * 2.5) * s
        Deco(geo, Vector3.new(h, 0.4 * s, 0.4 * s), K.Up(o * CFrame.new(0, h / 2, 0)), BAMBOO, M.SmoothPlastic, Enum.PartType.Cylinder)
        for j = 1, 3 do Deco(geo, Vector3.new(0.15 * s, 0.5 * s, 0.5 * s), K.Up(o * CFrame.new(0, j * h / 4, 0)), C3(90, 120, 60), M.SmoothPlastic, Enum.PartType.Cylinder) end
        Wedge(geo, Vector3.new(0.1, 0.4 * s, 1.6 * s), o * CFrame.new(0.4 * s, h * 0.9, 0) * CFrame.Angles(0, k, math.rad(-30)), C3(110, 170, 70), M.Grass)
    end
end
local function Pagoda(parent, base, s)
    -- (UPDATE 4: one real model replaces the stacked parts when the place has it -- WorldProps.Sakura.Pagoda, stored at s = 1)
    if K.Prop(parent, "Sakura", "Pagoda", CFrame.new(base), s) then return end
    -- five shrinking storeys, each with a wide dark roof flaring at the corners, a bronze spire
    for k = 0, 4 do
        local w = (16 - k * 2.4) * s
        local y = k * 7 * s
        P(parent, { Size = Vector3.new(w * 0.7, 5 * s, w * 0.7), CFrame = CFrame.new(base + Vector3.new(0, y + 2.5 * s, 0)), Color = (k == 0) and RED or C3(180, 46, 38), Material = M.SmoothPlastic })
        P(parent, { Size = Vector3.new(w * 1.15, 0.8 * s, w * 1.15), CFrame = CFrame.new(base + Vector3.new(0, y + 5.4 * s, 0)), Color = ROOF, Material = M.Slate })
        for c = 0, 3 do
            P(parent, { Class = "WedgePart", Size = Vector3.new(w * 1.15, 1.6 * s, w * 0.4), CFrame = CFrame.new(base + Vector3.new(0, y + 6.6 * s, 0)) * CFrame.Angles(0, c * math.pi / 2, 0) * CFrame.new(0, 0, -w * 0.38), Color = ROOF, Material = M.Slate })
        end
    end
    P(parent, { Size = Vector3.new(0.8 * s, 9 * s, 0.8 * s), CFrame = CFrame.new(base + Vector3.new(0, 39 * s, 0)), Color = C3(170, 130, 70), Material = M.Metal })
end

W.Props = {
    Cover = { function(geo, _, rng, pos) ShrineWall(geo, CFrame.new(pos) * K.Yaw(rng), 0.9) end, function(geo, _, rng, pos) Toro(geo, CFrame.new(pos), 1.2, false) end },
    Tall = { function(geo, _, rng, pos) Cherry(geo, CFrame.new(pos) * K.Yaw(rng), 1) end, function(geo, _, rng, pos) Torii(geo, CFrame.new(pos) * K.Yaw(rng), 0.9) end },
    Air = {},
}
W.Landmarks = {
    function(geo, _, rng, c) -- THE GATE PATH: torii gates on the four diagonals facing the plaza, lanterns beside them
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            local p = c + Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32)
            Torii(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 0.95)
            Toro(geo, CFrame.new(c + Vector3.new(math.cos(a + 0.45) * 30, 0, math.sin(a + 0.45) * 30)), 1, i == 0)
        end
    end,
    function(geo, _, rng, c) -- BLOSSOM CIRCLE: cherry trees round the plaza
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2 + 0.2
            Cherry(geo, CFrame.new(c + Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32)) * CFrame.Angles(0, a, 0), 0.9)
        end
    end,
}
W.Kits = {
    SkTorii = function(g, cf, s) Torii(g, cf, s * 0.6) end,
    SkToro = function(g, cf, s) Toro(g, cf, s * 0.7, false) end,
    SkCherry = function(g, cf, s) Cherry(g, cf, s * 0.6) end,
    SkWall = function(g, cf, s) ShrineWall(g, cf, s * 0.55) end,
    SkBamboo = function(g, cf, s) Bamboo(g, cf, s * 0.6) end,
}
W.Templates = {
    { Name = "Shrine Steps", Rim = "Ruins", RimMat = { M.Grass, M.Slate }, Ground = M.Pavement, Patch = { M.Grass, M.Slate },
        Edge = { "SkWall", "SkToro", "SkTorii" }, RimKit = { "SkCherry", "SkTorii", "SkBamboo" }, Hero = "SkPagoda", Glow = { SkToro = LAMP } },
    { Name = "Blossom Valley", Rim = "Cliffs", RimMat = { M.Rock, M.Grass }, RimAccent = M.LeafyGrass, PartyRim = "SkCherry", Ground = M.Grass, Patch = { M.Pavement, M.LeafyGrass },
        Edge = { "SkToro", "SkWall" }, RimKit = { "SkCherry", "SkCherry", "SkBamboo" }, Hero = "SkPagoda" },
    { Name = "Bamboo Grove", Rim = "Ruins", RimMat = { M.Ground, M.Grass }, Ground = M.Ground, Patch = { M.Pavement, M.LeafyGrass },
        Edge = { "SkWall", "SkToro", "SkBamboo" }, RimKit = { "SkBamboo", "SkBamboo", "SkCherry" }, Hero = "SkPagoda", Glow = { SkToro = LAMP } },
}
W.Heroes = {}
function W.Heroes.SkPagoda(fx, ctx)
    local c = Vector3.new(60, 0, ctx.zC + ctx.half * 3.2)
    Pagoda(fx, c, 3.2)
    for k = -2, 2 do -- cherry trees at its feet
        local m = K.Model(fx, "HeroCherry")
        Cherry(m, CFrame.new(c + Vector3.new(k * 30, 0, -40 - math.abs(k) * 8)), 3)
        K.NoCollide(m)
    end
end
W.Vista = { Ground = C3(90, 110, 70), GroundMat = M.Grass, Peak = C3(110, 104, 140), PeakMat = M.Rock, Tip = C3(240, 230, 240) }
function W.VistaFn(fx, Pf, centre, gy, zC, r)
    -- misty hills crowned with blossom, a few far torii and pagodas
    -- (UPDATE 4 VISTA: real models to the horizon -- WorldKit.Far props + tinted scanned mountains; the part version
    -- below stays as the fallback for an unsaved place)
    if K.HasProp("Sakura", "Cherry") then
        for _ = 1, 14 do -- soft hills, each crowned with a blossoming cherry
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(300, 1000)
            local w = r:NextNumber(160, 340)
            local p = centre + Vector3.new(math.cos(a) * d, -w * 0.38, math.sin(a) * d)
            Pf({ Name = "Hill", Shape = Enum.PartType.Ball, Size = Vector3.new(w, w * 0.9, w), CFrame = CFrame.new(p), Color = C3(96, 116, 76), Material = M.Grass })
            K.Far(fx, "Sakura", "Cherry", CFrame.new(p + Vector3.new(r:NextNumber(-w * 0.12, w * 0.12), w * 0.45 - 3, r:NextNumber(-w * 0.12, w * 0.12))) * CFrame.Angles(0, r:NextNumber(0, 6.28), 0), 2.4 + d / 450)
        end
        for _ = 1, 3 do -- far pagodas
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(650, 1000)
            K.Far(fx, "Sakura", "Pagoda", CFrame.new(centre + Vector3.new(math.cos(a) * d, -2, math.sin(a) * d)) * CFrame.Angles(0, r:NextNumber(0, 6.28), 0), r:NextNumber(1.2, 1.7))
        end
        for k = 1, 4 do -- misty blue mountains
            local a, d = (k / 4 + r:NextNumber(-0.08, 0.08)) * math.pi * 2, r:NextNumber(1050, 1250)
            K.Mesh(fx, "Mountain", CFrame.new(centre + Vector3.new(math.cos(a) * d, -40, math.sin(a) * d)) * CFrame.Angles(0, a + math.pi / 2, 0), r:NextNumber(260, 380), C3(120, 118, 150), { Shadow = false })
        end
        return true
    end
    for _ = 1, 22 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(300, 1050)
        local w = r:NextNumber(160, 360)
        local p = centre + Vector3.new(math.cos(a) * d, -w * 0.38, math.sin(a) * d)
        Pf({ Name = "Hill", Shape = Enum.PartType.Ball, Size = Vector3.new(w, w * 0.9, w), CFrame = CFrame.new(p), Color = C3(96, 116, 76), Material = M.Grass })
        for _ = 1, 3 do
            Pf({ Name = "FarBlossom", Shape = Enum.PartType.Ball, Size = Vector3.one * r:NextNumber(20, 40), CFrame = CFrame.new(p + Vector3.new(r:NextNumber(-w * 0.3, w * 0.3), w * 0.45, r:NextNumber(-w * 0.3, w * 0.3))),
                Color = (r:NextNumber() < 0.5) and BLOSSOM or BLOSSOM2, Material = M.SmoothPlastic })
        end
    end
    return true
end
function W.Scenery(fx, theme, rng, zC, arena, height)
    -- petals on the wind + paper lanterns drifting slowly up and away (client)
    local src = K.Box(fx, Vector3.new(arena, 1, arena), CFrame.new(0, 26, zC))
    K.Emit(src, { Color = ColorSequence.new(BLOSSOM, BLOSSOM2), LightEmission = 0.2, LightInfluence = 0.8, Rate = 22, Lifetime = NumberRange.new(7, 10),
        Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(40, 40), EmissionDirection = Enum.NormalId.Bottom, Size = NumberSequence.new(0.35, 0.25),
        Transparency = NumberSequence.new(0, 1), RotSpeed = NumberRange.new(-120, 120), Rotation = NumberRange.new(0, 360), Acceleration = Vector3.new(2.5, -0.6, 0.8),
        Texture = "rbxasset://textures/particles/sparkles_main.dds" })
    -- (UPDATE 4 LIFE: real paper sky lanterns, each in a soft glow -- light through the paper; the glow fades as they
    -- climb away. No Light objects: the glow is a faint Neon ball kept out of the NeonTamer.)
    local lanterns = {}
    for i = 1, 8 do
        local real, paper = K.Life(fx, "Sakura", "SkyLantern", 1.25)
        local l = { C = Vector3.new(rng:NextNumber(-arena * 0.6, arena * 0.6), 0, zC + rng:NextNumber(-arena * 0.6, arena * 0.6)), Ph = rng:NextNumber(0, 40), M = real, Paper = paper }
        if real then
            l.P = Neon(fx, Vector3.new(2.1, 2.9, 2.1), CFrame.new(), C3(255, 160, 90), 0.88, Enum.PartType.Ball)
            l.P:SetAttribute("KeepNeon", true)
            l.T0 = 0.88
        else
            l.P = Neon(fx, Vector3.new(1.2, 1.6, 1.2), CFrame.new(), LAMP, 0.1)
            l.T0 = 0.1
        end
        table.insert(lanterns, l)
    end
    K.Live(fx, function(t)
        for _, l in ipairs(lanterns) do
            local y = ((t * 1.2 + l.Ph * 3) % 100) + 30 -- (they rise from above the fight)
            local cf = CFrame.new(l.C + Vector3.new(math.sin(t * 0.3 + l.Ph) * 4, y, math.cos(t * 0.25 + l.Ph) * 4)) * CFrame.Angles(math.sin(t * 0.7 + l.Ph) * 0.08, t * 0.2 + l.Ph, math.cos(t * 0.6 + l.Ph) * 0.08)
            local fade = math.clamp((y - 90) / 40, 0, 1)
            l.P.CFrame = cf
            l.P.Transparency = l.T0 + (1 - l.T0) * fade
            if l.M then
                l.M:PivotTo(cf)
                l.Paper.Transparency = fade
            end
        end
    end)
end
function W.SetPiece(geo, deco, c, rng, F)
    -- THE BLOSSOM COURT: torii and cherry trees round the fight floor, a great pagoda over the far side
    K.Ring(12, 100, c + Vector3.new(0, F, 0), function(p, a, i)
        if i % 2 == 0 then Torii(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1.5) else Cherry(geo, CFrame.new(p) * CFrame.Angles(0, a, 0), 1.6) end
    end)
    Pagoda(deco, c + Vector3.new(0, F, 160), 2.2)
    local l = Neon(deco, Vector3.new(6, 8, 6), CFrame.new(c + Vector3.new(0, F + 20, 140)), LAMP, 0.1)
    K.Light(l, LAMP, 60, 1.0)
    return RED
end

W.Theme = {
    Name = "Sakura Shrine",
    Floor = { Color = C3(186, 180, 168), Material = M.Pebble },
    FloorAlt = { Color = C3(120, 84, 62), Material = M.WoodPlanks },
    Wall = { Color = C3(170, 164, 150), Material = M.Slate },
    WallTrim = { Color = RED, Material = M.SmoothPlastic },
    Ceiling = { Color = ROOF, Material = M.Slate },
    Prop = { Color = STONE, Material = M.Slate },
    PropAlt = { Color = BLOSSOM, Material = M.SmoothPlastic },
    Hazard = { Color = C3(70, 120, 150), Material = M.Glass, Transparency = 0.3 },
    Accent = C3(255, 120, 150), Light = C3(255, 214, 200), LampBrightness = 1.2, LampRange = 50,
    OpenSky = true,
}
W.Ambience = { Mote = BLOSSOM, Mote2 = C3(255, 230, 240), MoteRise = false, Glow = LAMP }
-- (UPDATE 4 SKIES: 17.3 -> 16.0 -- past ~17.5 Roblox dims the painted sky; the Lantern mood (+1.0 +-0.4) reached 18.7)
W.Light = { ClockTime = 16.0, Brightness = 1.8, Ambient = C3(150, 128, 140), OutdoorAmbient = C3(170, 140, 160),
    FogColor = C3(200, 160, 180), FogStart = 180, FogEnd = 860, Exposure = 0.2, EnvDiffuse = 0.3,
    BloomIntensity = 0.38, BloomThreshold = 1.25, BloomSize = 22,
    CCBrightness = 0.01, CCContrast = 0.1, CCSaturation = 0.1, CCTint = C3(255, 238, 244) }
W.Atmo = { 0.32, C3(250, 200, 214), C3(150, 110, 160), 1.6, 0.3 }
W.Terrain = { [M.Grass] = C3(96, 122, 70), [M.LeafyGrass] = C3(86, 116, 62), [M.Pavement] = C3(176, 170, 158), [M.Slate] = C3(120, 120, 120),
    [M.Rock] = C3(118, 112, 120), [M.Ground] = C3(110, 90, 72) }
-- (UPDATE 4 wrap-up, RoomGen.DressFor: the room pieces in this world's own language -- grey shrine stone (no more grass / earth pillars), a stone lantern on each pier)
W.Cover = { Built = true, Stone = M.Slate, Crown = { World = "Sakura", Name = "Toro", Fit = 0.7, MaxH = 6, Alt = { "Cherry", "Bamboo" } } }
W.Contrast = C3(40, 220, 255)
W.EA = { Warn = C3(255, 40, 70), Core = C3(255, 220, 230), Mat = M.Neon }
W.Moods = {
    { Id = "Spring", W = 3 },
    { Id = "Lantern", Name = "Lantern Night", W = 2, Val = 0.88, Acc = 0.08, Fog = C3(90, 60, 120), FogAmt = 0.36, Exp = -0.07, Clock = 1.0 },
    { Id = "Mist", Name = "Morning Mist", W = 2, Sat = 0.8, Fog = C3(230, 226, 232), FogAmt = 0.42, Dens = 1.3, Clock = -1.0 },
    { Id = "Maple", Name = "Red Maple", W = 1, Acc = 0.03, Fog = C3(230, 120, 80), FogAmt = 0.28 },
}
W.Sky = { Bk = "107823778896044", Dn = "128281097745788", Ft = "93336700355851", Lf = "134472534239535", Rt = "85996776001745", Up = "96093224275673" } -- (UPDATE 4 SKIES v4: tools/hdri_sky.py)
return W
