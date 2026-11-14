--!nocheck
-- SPORE WORLD (0.87 world): an alien mushroom planet at twilight -- giant mushrooms with glowing gills, puffball clusters,
-- rocks crusted with shelf fungi, glowing tendrils, spore pods; a ringed planet in the sky, luminous spores drifting,
-- floating spore balls. Sister: Void.
local K = require(script.Parent.Parent:WaitForChild("WorldKit"))
local C3, M = K.C3, K.M
local P, Solid, Deco, Neon, Wedge = K.P, K.Solid, K.Deco, K.Neon, K.Wedge

local GROUND, ROCK, ROCK2 = C3(62, 46, 82), C3(56, 44, 74), C3(76, 60, 96)
local STEM, CAP, CAP2, CAP3 = C3(200, 190, 220), C3(150, 70, 190), C3(70, 150, 190), C3(220, 90, 130)
local GILL, GILL2, SPORE = C3(90, 255, 220), C3(255, 120, 230), C3(170, 255, 200)

local W = {}
W.Id = "Fungal"
W.Title = "SPORE WORLD"
W.TitleColor = C3(150, 255, 210)
W.Sister = "Void"
W.HazardName = "Spore Bloom"

local CAPS = { CAP, CAP2, CAP3 }
-- (UPDATE 4 prop pass: real textured models from ReplicatedStorage.WorldProps.Fungal via WorldKit.Prop when the place has
-- them; the part build under each is the fallback. Gameplay boxes measured from the models' height maps.)
local function Shroom(geo, cf, s, ci)
    if K.Prop(geo, "Fungal", "Shroom", cf, s) then return end -- (decoration, like the old one: shots pass)
    -- a giant mushroom: a pale curving stem, a domed cap with spots, a ring of glowing gills under it
    local h = 10 * s
    local top = cf
    for k = 0, 3 do
        local seg = Deco(geo, Vector3.new(h / 4 + 0.2, 1.3 * s, 1.3 * s), K.Up(top * CFrame.new(0, h / 8, 0)), STEM, M.SmoothPlastic, Enum.PartType.Cylinder)
        if k < 2 then seg.CanCollide = true; seg.CanQuery = true end
        top = top * CFrame.new(0, h / 4, 0) * CFrame.Angles(0, 0, math.rad(5))
    end
    local col = CAPS[(ci or 0) % 3 + 1]
    Deco(geo, Vector3.new(9, 4.2, 9) * s, top * CFrame.new(0, 1.2 * s, 0), col, M.SmoothPlastic, Enum.PartType.Ball)
    local gill = Neon(geo, Vector3.new(0.2, 8 * s, 8 * s), K.Up(top * CFrame.new(0, 0.2 * s, 0)), (col == CAP2) and GILL2 or GILL, 0.15, Enum.PartType.Cylinder)
    for k = 0, 4 do
        local a = k * 1.3
        Deco(geo, Vector3.new(1.3, 0.5, 1.3) * s, top * CFrame.new(math.cos(a) * 2.6 * s, 2.9 * s, math.sin(a) * 2.6 * s) * CFrame.Angles(math.cos(a) * 0.4, 0, math.sin(a) * 0.4),
            C3(240, 230, 250), M.SmoothPlastic, Enum.PartType.Ball)
    end
    return gill
end
local function Puffballs(geo, cf, s)
    -- (the model is drawn at 0.7: cover stays under eye height)
    if K.Prop(geo, "Fungal", "Puffballs", cf, s * 0.7, { { Vector3.new(5.2, 5.2, 5.2), Vector3.new(0, 2.6, 0) } }) then return end
    -- a cluster of puffballs, the big one cover, little ones glowing at their tops
    Solid(geo, Vector3.new(4.4, 3.6, 4.4) * s, cf * CFrame.new(0, 1.6 * s, 0), C3(210, 196, 226), M.SmoothPlastic, Enum.PartType.Ball)
    Solid(geo, Vector3.new(3, 2.6, 3) * s, cf * CFrame.new(2.6 * s, 1.1 * s, 1 * s), C3(190, 170, 214), M.SmoothPlastic, Enum.PartType.Ball)
    for k = 0, 3 do
        local a = k * 1.6 + 0.5
        local p = cf * CFrame.new(math.cos(a) * 3 * s - 0.5 * s, 0.6 * s, math.sin(a) * 3 * s)
        Deco(geo, Vector3.one * 1.2 * s, p, C3(180, 160, 210), M.SmoothPlastic, Enum.PartType.Ball)
        Neon(geo, Vector3.one * 0.4 * s, p * CFrame.new(0, 0.55 * s, 0), SPORE, 0.1, Enum.PartType.Ball)
    end
end
local function ShelfRock(geo, cf, s)
    if K.Prop(geo, "Fungal", "ShelfRock", cf, s * 0.75, { { Vector3.new(5.4, 4.6, 5.2), Vector3.new(0, 2.3, 0) } }) then return end
    -- a dark rock crusted with shelf fungi that glow along their edges
    Solid(geo, Vector3.new(5, 3.6, 4) * s, cf * CFrame.new(0, 1.6 * s, 0) * CFrame.Angles(0.12, 0.5, -0.1), ROCK, M.Rock)
    Solid(geo, Vector3.new(3, 2.2, 3) * s, cf * CFrame.new(2.6 * s, 1 * s, -1 * s) * CFrame.Angles(-0.2, 1.1, 0.15), ROCK2, M.Rock)
    for k = 0, 3 do
        local y = (1.2 + k * 0.7) * s
        local shelf = cf * CFrame.new(-2.4 * s + k * 0.3 * s, y, (k - 1.5) * 0.6 * s) * CFrame.Angles(0, k * 0.4, 0)
        Deco(geo, Vector3.new(2.2 * s, 0.25 * s, 1.6 * s), shelf * CFrame.new(-0.6 * s, 0, 0), C3(230, 150, 90), M.SmoothPlastic)
        Neon(geo, Vector3.new(0.1, 0.12 * s, 1.6 * s), shelf * CFrame.new(-1.7 * s, 0, 0), GILL, 0.2)
    end
end
local function Tendrils(geo, cf, s)
    if K.Prop(geo, "Fungal", "Tendrils", cf, s, { { Vector3.new(3.4, 1.4, 3.4), Vector3.new(0, 0.7, 0) } }) then return end
    -- glowing tendrils curling up out of a mound
    Solid(geo, Vector3.new(3, 1.4, 3) * s, cf * CFrame.new(0, 0.5 * s, 0), ROCK2, M.Rock, Enum.PartType.Ball)
    for k = 0, 4 do
        local a = k * 1.25
        local p = (cf * CFrame.new(math.cos(a) * 0.8 * s, 0.8 * s, math.sin(a) * 0.8 * s)).Position
        local dir = Vector3.new(math.cos(a) * 0.4, 1, math.sin(a) * 0.4).Unit
        for j = 1, 4 do
            local q = p + dir * 1.6 * s
            K.Beam(geo, p, q, (0.35 - j * 0.05) * s, (j == 4) and GILL2 or C3(120, 70, 160), (j == 4) and M.Neon or M.SmoothPlastic, true)
            dir = (dir + Vector3.new(-math.sin(a) * 0.5, -0.05, math.cos(a) * 0.5)).Unit
            p = q
        end
        Neon(geo, Vector3.one * 0.5 * s, CFrame.new(p), GILL2, 0, Enum.PartType.Ball)
    end
end
local function Pod(geo, cf, s)
    if K.Prop(geo, "Fungal", "Pod", cf, s, { { Vector3.new(0.8, 7, 0.8), Vector3.new(0, 3.5, 0) } }) then
        -- (a soft glow shell over the model's bulb: the spore light it's named for; KeepNeon = NeonTamer leaves it lit)
        local g = Neon(geo, Vector3.new(3.6, 3.9, 3.6) * s, cf * CFrame.new(0, 8.25 * s, 0), SPORE, 0.62, Enum.PartType.Ball)
        g:SetAttribute("KeepNeon", true)
        return
    end
    -- a tall spore pod: a thin stalk and a glowing translucent bulb with a dark seed inside
    Solid(geo, Vector3.new(0.6 * s, 7 * s, 0.6 * s), cf * CFrame.new(0, 3.5 * s, 0), C3(90, 70, 120), M.SmoothPlastic)
    Neon(geo, Vector3.new(2.6, 3.4, 2.6) * s, cf * CFrame.new(0, 8.4 * s, 0), SPORE, 0.4, Enum.PartType.Ball)
    Deco(geo, Vector3.new(1.2, 1.6, 1.2) * s, cf * CFrame.new(0, 8.3 * s, 0), C3(40, 30, 60), M.SmoothPlastic, Enum.PartType.Ball)
end

W.Props = {
    Cover = { function(geo, _, rng, pos) Puffballs(geo, CFrame.new(pos) * K.Yaw(rng), 1) end, function(geo, _, rng, pos) ShelfRock(geo, CFrame.new(pos) * K.Yaw(rng), 1) end },
    Tall = { function(geo, _, rng, pos) Shroom(geo, CFrame.new(pos) * K.Yaw(rng), 0.9, rng:NextInteger(0, 2)) end, function(geo, _, rng, pos) Pod(geo, CFrame.new(pos), 1) end },
    Air = {},
}
W.Landmarks = {
    function(geo, _, rng, c) -- THE FAIRY RING: giant mushrooms in a circle round the plaza
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2 + 0.25
            local gill = Shroom(geo, CFrame.new(c + Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32)) * CFrame.Angles(0, a, 0), 0.95, i)
            if i == 0 then K.Light(gill, GILL, 30, 1.2) end
        end
    end,
    function(geo, _, rng, c) -- THE BROOD: tendril mounds and spore pods round the plaza
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            Tendrils(geo, CFrame.new(c + Vector3.new(math.cos(a) * 31, 0, math.sin(a) * 31)), 1.2)
            Pod(geo, CFrame.new(c + Vector3.new(math.cos(a + 0.6) * 33, 0, math.sin(a + 0.6) * 33)), 1)
        end
    end,
}
W.Kits = {
    FgShroom = function(g, cf, s) Shroom(g, cf, s * 0.6, math.floor(cf.Position.X) % 3) end,
    FgPuff = function(g, cf, s) Puffballs(g, cf, s * 0.6) end,
    FgShelf = function(g, cf, s) ShelfRock(g, cf, s * 0.6) end,
    FgTendril = function(g, cf, s) Tendrils(g, cf, s * 0.6) end,
    FgPod = function(g, cf, s) Pod(g, cf, s * 0.6) end,
}
W.Templates = {
    { Name = "Mushroom Forest", Rim = "Ruins", RimMat = { M.Mud, M.Ground }, Ground = M.Ground, Patch = { M.Mud, M.Slate },
        Edge = { "FgPuff", "FgShelf", "FgTendril" }, RimKit = { "FgShroom", "FgShroom", "FgPod" }, Hero = "FgCap", Glow = { FgShroom = GILL } },
    { Name = "Spore Crater", Rim = "Cliffs", RimMat = { M.Rock, M.Slate }, RimAccent = M.Mud, PartyRim = "FgShroom", Ground = M.Mud, Patch = { M.Ground, M.Slate },
        Edge = { "FgShelf", "FgPuff" }, RimKit = { "FgShroom", "FgTendril", "FgPod" }, Hero = "FgCap" },
    { Name = "Glowing Hollow", Rim = "Edge", RimMat = { M.Slate, M.Rock }, Ground = M.Slate, Patch = { M.Mud, M.Ground },
        Edge = { "FgTendril", "FgPuff", "FgPod" }, RimKit = { "FgShroom", "FgPod" }, Hero = "FgCap", Glow = { FgShroom = GILL2 } },
}
W.Heroes = {}
function W.Heroes.FgCap(fx, ctx)
    -- a colossal mushroom towering over the far side, its gills glowing, smaller ones round its foot
    local c = Vector3.new(-50, 0, ctx.zC + ctx.half * 3.2)
    local m = K.Model(fx, "HeroShroom")
    Shroom(m, CFrame.new(c), 11, 0)
    for k = -2, 2 do
        if k ~= 0 then Shroom(m, CFrame.new(c + Vector3.new(k * 70, 0, -40)) * CFrame.Angles(0, k, 0), 4 + math.abs(k), k + 3) end
    end
    K.NoCollide(m)
end
W.Vista = { Ground = C3(48, 34, 66), GroundMat = M.Ground, Peak = C3(60, 42, 84), PeakMat = M.Rock, Tip = GILL }
function W.VistaFn(fx, Pf, centre, gy, zC, r)
    -- a forest of giant mushrooms to the horizon, glowing gill rings, floating spore clouds
    -- (UPDATE 4 VISTA: real models to the horizon -- WorldKit.Far props + tinted scanned mountains; the part version
    -- below stays as the fallback for an unsaved place)
    if K.HasProp("Fungal", "Shroom") then
        for _ = 1, 24 do -- a forest of giant mushrooms to the horizon
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(260, 1000)
            K.Far(fx, "Fungal", "Shroom", CFrame.new(centre + Vector3.new(math.cos(a) * d, -1, math.sin(a) * d)) * CFrame.Angles(0, r:NextNumber(0, 6.28), 0), r:NextNumber(3, 6) + d / 300)
        end
        for _ = 1, 6 do -- glowing spore pods between them
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(240, 600)
            local p = centre + Vector3.new(math.cos(a) * d, -1, math.sin(a) * d)
            local sc = r:NextNumber(3, 4.5)
            K.Far(fx, "Fungal", "Pod", CFrame.new(p), sc)
            Pf({ Name = "PodGlow", Shape = Enum.PartType.Ball, Size = Vector3.new(3.6, 3.9, 3.6) * sc, CFrame = CFrame.new(p + Vector3.new(0, 8.25 * sc, 0)), Color = SPORE, Material = M.Neon, Transparency = 0.62 })
        end
        return true
    end
    for _ = 1, 40 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(260, 1000)
        local h = r:NextNumber(40, 140)
        local w = h * r:NextNumber(0.6, 0.9)
        local p = centre + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
        Pf({ Name = "Stem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, w * 0.14, w * 0.14), CFrame = K.Up(CFrame.new(p + Vector3.new(0, h / 2, 0))), Color = C3(150, 140, 180), Material = M.SmoothPlastic })
        Pf({ Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(w, w * 0.45, w), CFrame = CFrame.new(p + Vector3.new(0, h, 0)), Color = CAPS[r:NextInteger(1, 3)], Material = M.SmoothPlastic })
        Pf({ Name = "Gill", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, w * 0.85, w * 0.85), CFrame = K.Up(CFrame.new(p + Vector3.new(0, h - w * 0.08, 0))), Color = (r:NextNumber() < 0.5) and GILL or GILL2, Material = M.Neon, Transparency = 0.2 })
    end
    return true
end
function W.Scenery(fx, theme, rng, zC, arena, height)
    -- luminous spores drifting up through the room + slow floating spore balls (client)
    local src = K.Box(fx, Vector3.new(arena, 1, arena), CFrame.new(0, 3, zC))
    K.Emit(src, { Color = ColorSequence.new(SPORE, GILL2), LightEmission = 0.9, Rate = 18, Lifetime = NumberRange.new(7, 10), Speed = NumberRange.new(0.6, 1.6),
        SpreadAngle = Vector2.new(30, 30), EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new(0.22, 0.1), Transparency = NumberSequence.new(0.1, 1),
        Acceleration = Vector3.new(0.3, 0.2, 0) })
    local balls = {}
    for i = 1, 7 do
        local b = Neon(fx, Vector3.one * rng:NextNumber(1.6, 3), CFrame.new(), (i % 2 == 0) and GILL or SPORE, 0.45, Enum.PartType.Ball)
        table.insert(balls, { P = b, C = Vector3.new(rng:NextNumber(-arena * 0.45, arena * 0.45), rng:NextNumber(32, 52), zC + rng:NextNumber(-arena * 0.45, arena * 0.45)), Ph = rng:NextNumber(0, 6) }) -- (above the fight)
    end
    K.Live(fx, function(t)
        for _, b in ipairs(balls) do
            b.P.CFrame = CFrame.new(b.C + Vector3.new(math.sin(t * 0.25 + b.Ph) * 6, math.sin(t * 0.7 + b.Ph) * 2, math.cos(t * 0.2 + b.Ph) * 6))
        end
    end)
end
function W.SetPiece(geo, deco, c, rng, F)
    -- THE GREAT RING: giant mushrooms round the fight floor, a colossal one glowing over the far side
    K.Ring(12, 100, c + Vector3.new(0, F, 0), function(p, a, i)
        if i % 3 == 2 then Pod(geo, CFrame.new(p), 1.8) else Shroom(geo, CFrame.new(p) * CFrame.Angles(0, a, 0), 1.6, i) end
    end)
    local m = K.Model(deco, "BossShroom")
    -- (UPDATE 4: the real shroom, raised + bigger so its cap clears the rim hills (seen in play: only the cap's rim
    -- showed); the model has no gill part, so the light hangs where the gills were)
    local real = K.HasProp("Fungal", "Shroom")
    local gill = Shroom(m, CFrame.new(c + (real and Vector3.new(0, F + 24, 178) or Vector3.new(0, F, 160))), real and 8 or 6, 1)
    K.NoCollide(m)
    K.Light(gill or K.Box(deco, Vector3.new(1, 1, 1), CFrame.new(c + Vector3.new(0, F + 50, 160))), GILL, 70, 1.2)
    return GILL
end

W.Theme = {
    Name = "Spore World",
    Floor = { Color = GROUND, Material = M.Ground },
    FloorAlt = { Color = C3(52, 40, 70), Material = M.Mud },
    Wall = { Color = ROCK, Material = M.Rock },
    WallTrim = { Color = C3(40, 32, 56), Material = M.Slate },
    Ceiling = { Color = C3(30, 22, 44), Material = M.Rock },
    Prop = { Color = ROCK2, Material = M.Rock },
    PropAlt = { Color = CAP, Material = M.SmoothPlastic },
    Hazard = { Color = C3(120, 255, 180), Material = M.Neon, Transparency = 0.35 },
    Accent = GILL, Light = C3(200, 170, 255), LampBrightness = 1.4, LampRange = 52,
    OpenSky = true,
}
W.Ambience = { Mote = SPORE, Mote2 = GILL2, MoteRise = true, Glow = GILL }
-- (UPDATE 4 SKIES: day clock + low Brightness -- at 19.2 Roblox dimmed the painted spore sky to black; geometry ~same)
-- (UPDATE 4 LIGHTING AUDIT: gun slide L35 at Brightness 0.2 -> ambient + exposure up; the glowing caps still read)
W.Light = { ClockTime = 13, Brightness = 0.2, Ambient = C3(185, 157, 230), OutdoorAmbient = C3(189, 162, 238),
    FogColor = C3(70, 48, 110), FogStart = 160, FogEnd = 760, Exposure = 1.1, EnvDiffuse = 0.35,
    BloomIntensity = 0.55, BloomThreshold = 1.05, BloomSize = 24,
    CCBrightness = 0.01, CCContrast = 0.12, CCSaturation = 0.12, CCTint = C3(240, 230, 255) }
W.Atmo = { 0.34, C3(150, 100, 210), C3(50, 30, 90), 1.6, 0 }
W.Terrain = { [M.Ground] = C3(66, 50, 86), [M.Mud] = C3(54, 42, 72), [M.Rock] = C3(60, 48, 80), [M.Slate] = C3(70, 56, 92) }
-- (UPDATE 4 wrap-up, RoomGen.DressFor: the room pieces in this world's own language -- violet rock (no more mud pillars), a giant mushroom growing out of the top)
W.Cover = { Stone = M.Rock, Crown = { World = "Fungal", Name = "Shroom", Fit = 1.0, MaxH = 8, Alt = { "Puffballs", "Pod" } } }
W.Contrast = C3(255, 230, 60)
W.EA = { Warn = C3(255, 60, 140), Core = C3(255, 220, 240), Mat = M.ForceField }
W.Moods = {
    { Id = "Twilight", W = 3 },
    { Id = "Bloom", Name = "Spore Bloom", W = 2, Acc = 0.9, Fog = C3(170, 70, 160), FogAmt = 0.36, CCSat = 0.05 },
    { Id = "Teal", Name = "Teal Dawn", W = 2, H = 0.48, Amt = 0.25, Acc = 0.46, Fog = C3(50, 140, 140), FogAmt = 0.34 },
    { Id = "Deep", Name = "Deep Night", W = 1, Val = 0.85, Fog = C3(20, 14, 40), FogAmt = 0.4, Exp = -0.08 },
}
-- (2026-10-24: Bk + Up re-rendered with hdri_sky.blur_wrap -- the hard vertical seam straight behind +Z is gone)
W.Sky = { Bk = "100085523867264", Dn = "127022933981736", Ft = "97750574126354", Lf = "123309349941178", Rt = "102751599510032", Up = "116479781541716" } -- (UPDATE 4 SKIES v4: tools/hdri_sky.py)
return W
