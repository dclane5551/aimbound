--!nocheck
-- THE DEEP (0.87 world): a bioluminescent sea floor -- branching coral with glowing tips, brain coral, giant clams with
-- shining pearls, swaying kelp, the ribs of a sunken ship; rising bubbles, drifting jellyfish, marine snow, the surface
-- rippling far overhead. Sister: Dreamscape (its drifting, swinging roster suits the water).
local K = require(script.Parent.Parent:WaitForChild("WorldKit"))
local C3, M = K.C3, K.M
local P, Solid, Deco, Neon, Wedge = K.P, K.Solid, K.Deco, K.Neon, K.Wedge

local SAND, ROCK, ROCK2 = C3(70, 96, 104), C3(44, 62, 76), C3(56, 78, 92)
local CORAL, CORAL2, GLOW, GLOW2 = C3(230, 90, 120), C3(250, 140, 90), C3(80, 255, 230), C3(200, 120, 255)
local KELP, WOOD = C3(56, 110, 70), C3(70, 54, 44)

local W = {}
W.Id = "Abyss"
W.Title = "THE DEEP"
W.TitleColor = C3(80, 230, 240)
W.Sister = "Dream"
W.HazardName = "Brine Pool"

local function Branch(geo, base, dir, len, thick, col, depth)
    local tip = base + dir * len
    K.Beam(geo, base, tip, thick, col, M.SmoothPlastic, true)
    if depth <= 0 then
        Neon(geo, Vector3.one * thick * 1.6, CFrame.new(tip), GLOW, 0.1, Enum.PartType.Ball)
        return
    end
    for k = -1, 1, 2 do
        local nd = (CFrame.fromAxisAngle(Vector3.yAxis, k * 0.9) * CFrame.fromAxisAngle(Vector3.xAxis, k * 0.35)):VectorToWorldSpace(dir)
        Branch(geo, tip, (nd + Vector3.new(0, 0.5, 0)).Unit, len * 0.7, thick * 0.72, col, depth - 1)
    end
end
-- (UPDATE 4 prop pass: real textured models from ReplicatedStorage.WorldProps.Abyss via WorldKit.Prop when the place has
-- them; the part build under each is the fallback. Gameplay boxes measured from the models' height maps.)
-- (Abyss reuses the hideouts agent's Aquarium models: HideoutKit.Aquarium -> WorldProps.Abyss)
local function Coral(geo, cf, s)
    local fan = (math.floor(math.abs(cf.Position.X + cf.Position.Z * 3)) % 2 == 0) -- (staghorn or a sea fan, picked from the spot)
    if K.Prop(geo, "Abyss", fan and "SeaFan" or "Coral", cf, s, { { Vector3.new(3.6, 4, 3.6), Vector3.new(-0.4, 2, 0.1) } }) then return end
    -- a rock with a branching coral fan growing out of it, glowing at every tip
    Solid(geo, Vector3.new(4.6 * s, 2.6 * s, 3.8 * s), cf * CFrame.new(0, 1.1 * s, 0) * CFrame.Angles(0.1, 0.4, -0.08), ROCK, M.Rock)
    local col = (math.floor(cf.Position.X) % 2 == 0) and CORAL or CORAL2
    Branch(geo, (cf * CFrame.new(-0.6 * s, 2.2 * s, 0)).Position, (cf:VectorToWorldSpace(Vector3.new(-0.2, 1, 0))).Unit, 2.4 * s, 0.5 * s, col, 2)
    Branch(geo, (cf * CFrame.new(1.2 * s, 2.0 * s, 0.4 * s)).Position, (cf:VectorToWorldSpace(Vector3.new(0.4, 1, 0.2))).Unit, 1.8 * s, 0.4 * s, col, 1)
end
local function BrainCoral(geo, cf, s)
    if K.Prop(geo, "Abyss", "BrainCoral", cf, s, { { Vector3.new(3.6, 3.4, 3.6), Vector3.new(-0.2, 1.7, -0.2) } }) then return end
    Solid(geo, Vector3.new(4.4 * s, 3.2 * s, 4.4 * s), cf * CFrame.new(0, 1.2 * s, 0), C3(210, 160, 110), M.Slate, Enum.PartType.Ball)
    Solid(geo, Vector3.new(3 * s, 2.2 * s, 3 * s), cf * CFrame.new(2.6 * s, 0.8 * s, 0.8 * s), C3(180, 120, 160), M.Slate, Enum.PartType.Ball)
    for k = 0, 4 do
        local a = k * 1.26
        Deco(geo, Vector3.new(0.3 * s, 1.2 * s, 0.3 * s), cf * CFrame.new(math.cos(a) * 2.6 * s - 1 * s, 0.5 * s, math.sin(a) * 2.6 * s), C3(255, 160, 210), M.SmoothPlastic)
        Neon(geo, Vector3.one * 0.45 * s, cf * CFrame.new(math.cos(a) * 2.6 * s - 1 * s, 1.15 * s, math.sin(a) * 2.6 * s), GLOW2, 0.1, Enum.PartType.Ball)
    end
end
local function Clam(geo, cf, s)
    if K.Prop(geo, "Abyss", "Clam", cf, s, { { Vector3.new(5.4, 2.4, 4.2), Vector3.new(0, 1.2, -0.1) } }) then
        return Neon(geo, Vector3.one * 1.1 * s, cf * CFrame.new(0, 2.3 * s, 0.3 * s), C3(220, 255, 250), 0, Enum.PartType.Ball) -- (the glowing pearl, as before)
    end
    -- a giant clam: a ribbed lower shell, the upper shell tilted open, a glowing pearl inside
    Solid(geo, Vector3.new(6 * s, 1.8 * s, 4.6 * s), cf * CFrame.new(0, 0.9 * s, 0), C3(150, 170, 200), M.Slate)
    for k = -2, 2 do Deco(geo, Vector3.new(0.3 * s, 1.9 * s, 4.7 * s), cf * CFrame.new(k * 1.1 * s, 0.9 * s, 0), C3(120, 140, 176), M.Slate) end
    Deco(geo, Vector3.new(6 * s, 0.7 * s, 4.6 * s), cf * CFrame.new(0, 2.6 * s, 1.3 * s) * CFrame.Angles(math.rad(-38), 0, 0), C3(160, 180, 210), M.Slate)
    local pearl = Neon(geo, Vector3.one * 1.3 * s, cf * CFrame.new(0, 2.2 * s, -0.3 * s), C3(220, 255, 250), 0, Enum.PartType.Ball)
    Deco(geo, Vector3.new(5 * s, 0.4 * s, 3.6 * s), cf * CFrame.new(0, 1.85 * s, 0), C3(230, 120, 160), M.SmoothPlastic)
    return pearl
end
local function Kelp(geo, cf, s)
    if K.Prop(geo, "Abyss", "Kelp", cf, s, { { Vector3.new(2.4, 1.4, 2.4), Vector3.new(0, 0.7, 0) } }) then return end -- (shots pass the blades, as before)
    -- a clump of tall kelp blades with float bladders
    for k = 0, 3 do
        local o = cf * CFrame.new((k - 1.5) * 0.9 * s, 0, ((k * 7) % 3 - 1) * 0.7 * s)
        local h = (12 + (k % 2) * 4) * s
        Deco(geo, Vector3.new(0.3 * s, h, 1.2 * s), o * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, k * 0.8, math.rad((k - 1.5) * 3)), KELP, M.Grass)
        Deco(geo, Vector3.one * 0.6 * s, o * CFrame.new(0, h * 0.7, 0), C3(130, 170, 80), M.SmoothPlastic, Enum.PartType.Ball)
    end
    Solid(geo, Vector3.new(2.4 * s, 1.4 * s, 2.4 * s), cf * CFrame.new(0, 0.5 * s, 0), ROCK2, M.Rock)
end
local function Wreck(geo, cf, s)
    -- (the Aquarium hideout's shipwreck + treasure chest; a map-shell kit, so NB.Kit gives it its own hitbox)
    if K.Prop(geo, "Abyss", "Wreck", cf, s) then K.Prop(geo, "Abyss", "Chest", cf * CFrame.new(2.6 * s, 0, 3 * s) * CFrame.Angles(0, 0.5, 0), s) return end
    -- the ribs of a sunken ship: a keel, curved ribs arching up, a broken mast with a torn sail
    Solid(geo, Vector3.new(1.4 * s, 1.4 * s, 16 * s), cf * CFrame.new(0, 0.7 * s, 0), WOOD, M.WoodPlanks)
    for k = -3, 3 do
        for _, sx in ipairs({ -1, 1 }) do
            local h = (5 - math.abs(k) * 0.5) * s
            Deco(geo, Vector3.new(0.5 * s, h, 0.6 * s), cf * CFrame.new(sx * 1.6 * s, h / 2, k * 2.2 * s) * CFrame.Angles(0, 0, sx * math.rad(-22)), WOOD, M.Wood)
        end
    end
    Deco(geo, Vector3.new(0.7 * s, 12 * s, 0.7 * s), cf * CFrame.new(0, 6 * s, -2 * s) * CFrame.Angles(math.rad(14), 0, math.rad(10)), WOOD, M.Wood)
    Deco(geo, Vector3.new(0.1, 5 * s, 4 * s), cf * CFrame.new(0.4 * s, 8 * s, -1.4 * s) * CFrame.Angles(math.rad(14), 0, math.rad(10)), C3(170, 176, 160), M.SmoothPlastic, nil, 0.3)
    Solid(geo, Vector3.new(3.4 * s, 2 * s, 4 * s), cf * CFrame.new(0, 1 * s, 6 * s), WOOD, M.WoodPlanks)
end

W.Props = {
    Cover = { function(geo, _, rng, pos) Coral(geo, CFrame.new(pos) * K.Yaw(rng), 1) end, function(geo, _, rng, pos) BrainCoral(geo, CFrame.new(pos) * K.Yaw(rng), 1) end,
        function(geo, _, rng, pos) Clam(geo, CFrame.new(pos) * K.Yaw(rng), 0.9) end },
    Tall = { function(geo, _, rng, pos) Kelp(geo, CFrame.new(pos) * K.Yaw(rng), 1) end },
    Air = {},
}
W.Landmarks = {
    function(geo, _, rng, c) -- THE PEARL BEDS: giant clams round the plaza, coral between
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            local p = c + Vector3.new(math.cos(a) * 31, 0, math.sin(a) * 31)
            local pearl = Clam(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1.1)
            if i == 0 then K.Light(pearl, C3(170, 255, 240), 28, 1.2) end
            Coral(geo, CFrame.new(c + Vector3.new(math.cos(a + 0.8) * 34, 0, math.sin(a + 0.8) * 34)), 1)
        end
    end,
    function(geo, _, rng, c) -- KELP RING: kelp clumps round the plaza
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2 + 0.3
            Kelp(geo, CFrame.new(c + Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32)) * CFrame.Angles(0, a, 0), 1)
        end
    end,
}
W.Kits = {
    AbCoral = function(g, cf, s) Coral(g, cf, s * 0.6) end,
    AbBrain = function(g, cf, s) BrainCoral(g, cf, s * 0.6) end,
    AbClam = function(g, cf, s) Clam(g, cf, s * 0.55) end,
    AbKelp = function(g, cf, s) Kelp(g, cf, s * 0.6) end,
    AbWreck = function(g, cf, s) Wreck(g, cf, s * 0.6) end,
}
W.Templates = {
    { Name = "Coral Garden", Rim = "Ruins", RimMat = { M.Sand, M.Rock }, Ground = M.Sand, Patch = { M.Rock, M.Slate },
        Edge = { "AbCoral", "AbBrain", "AbClam" }, RimKit = { "AbCoral", "AbKelp", "AbBrain" }, Hero = "AbJelly", Glow = { AbClam = GLOW } },
    { Name = "Kelp Forest", Rim = "Cliffs", RimMat = { M.Rock, M.Slate }, RimAccent = M.Sand, PartyRim = "AbKelp", Ground = M.Sand, Patch = { M.Slate, M.Rock },
        Edge = { "AbKelp", "AbCoral" }, RimKit = { "AbKelp", "AbKelp", "AbCoral" }, Hero = "AbJelly" },
    { Name = "Sunken Wreck", Rim = "Edge", RimMat = { M.Rock, M.Basalt }, Ground = M.Sand, Patch = { M.Rock, M.Slate },
        Edge = { "AbWreck", "AbClam", "AbBrain" }, RimKit = { "AbWreck", "AbCoral", "AbKelp" }, Hero = "AbJelly", Glow = { AbClam = GLOW } },
}
W.Heroes = {}
function W.Heroes.AbJelly(fx, ctx)
    -- a colossal glowing jellyfish drifting over the far side, trailing long tentacles (it pulses on the client)
    local c = Vector3.new(-30, 120, ctx.zC + ctx.half * 3)
    -- (UPDATE 4: the Aquarium hideout's jellyfish model at colossus scale + a soft KeepNeon glow round its bell; it drifts
    -- and breathes on the client)
    local ok, jm = K.Prop(fx, "Abyss", "Jelly", CFrame.new(c.X, 8, c.Z), 7)
    if ok and jm then
        local cf0, sz = jm:GetBoundingBox()
        local glow = P(fx, { Shape = Enum.PartType.Ball, Size = Vector3.new(sz.X * 1.06, sz.Y * 0.36, sz.Z * 1.06), CFrame = CFrame.new(cf0.Position + Vector3.new(0, sz.Y * 0.3, 0)),
            Color = C3(200, 140, 255), Material = M.Neon, Transparency = 0.82 })
        glow:SetAttribute("KeepNeon", true)
        local base, gbase, s0 = jm:GetPivot(), glow.CFrame, jm:GetScale()
        K.Live(fx, function(tt)
            local bob = math.sin(tt * 0.45) * 7
            jm:ScaleTo(s0 * (1 + math.sin(tt * 1.3) * 0.025))
            jm:PivotTo(base + Vector3.new(0, bob, 0))
            glow.CFrame = gbase + Vector3.new(0, bob, 0)
            glow.Transparency = 0.8 + math.sin(tt * 1.3) * 0.05
        end)
        return
    end
    local bell = P(fx, { Shape = Enum.PartType.Ball, Size = Vector3.new(90, 56, 90), CFrame = CFrame.new(c), Color = C3(200, 140, 255), Material = M.Neon, Transparency = 0.45 })
    local inner = P(fx, { Shape = Enum.PartType.Ball, Size = Vector3.new(50, 30, 50), CFrame = CFrame.new(c + Vector3.new(0, -4, 0)), Color = C3(120, 255, 240), Material = M.Neon, Transparency = 0.3 })
    local tents = {}
    for k = 0, 9 do
        local a = k / 10 * math.pi * 2
        local t = P(fx, { Size = Vector3.new(2, 110, 2), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 30, -75, math.sin(a) * 30)), Color = C3(200, 160, 255), Material = M.Neon, Transparency = 0.55 })
        table.insert(tents, { P = t, Base = t.CFrame, Ph = k })
    end
    K.Live(fx, function(tt)
        local pulse = 1 + math.sin(tt * 1.4) * 0.06
        bell.Size = Vector3.new(90 * pulse, 56 / pulse, 90 * pulse)
        inner.Size = Vector3.new(50 * pulse, 30 / pulse, 50 * pulse)
        for _, t in ipairs(tents) do t.P.CFrame = t.Base * CFrame.Angles(math.sin(tt * 0.8 + t.Ph) * 0.06, 0, math.cos(tt * 0.7 + t.Ph) * 0.06) end
    end)
end
W.Vista = { Ground = C3(30, 50, 62), GroundMat = M.Sand, Peak = C3(26, 40, 54), PeakMat = M.Rock, Tip = C3(80, 220, 220) }
function W.VistaFn(fx, Pf, centre, gy, zC, r)
    -- dark reef ridges fading into the blue, dotted with glowing coral; kelp towers
    -- (UPDATE 4 VISTA: real models to the horizon -- WorldKit.Far props + tinted scanned mountains; the part version
    -- below stays as the fallback for an unsaved place)
    if K.HasMesh("CliffA") then
        for _ = 1, 12 do -- reef ridges fading into the blue, corals on their flanks
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(260, 900)
            local p = centre + Vector3.new(math.cos(a) * d, -14, math.sin(a) * d)
            K.Mesh(fx, K.Pick(r, K.CLIFFS), CFrame.new(p) * CFrame.Angles(0, r:NextNumber(0, 6.28), 0), r:NextNumber(110, 240), C3(46, 76, 86), { Shadow = false })
            if r:NextNumber() < 0.6 then
                K.Far(fx, "Abyss", (r:NextNumber() < 0.5) and "SeaFan" or "Coral", CFrame.new(p + Vector3.new(r:NextNumber(-30, 30), 12, r:NextNumber(-30, 30))), r:NextNumber(4, 7))
            end
            Pf({ Name = "ReefGlow", Shape = Enum.PartType.Ball, Size = Vector3.one * r:NextNumber(5, 10), CFrame = CFrame.new(p + Vector3.new(0, r:NextNumber(20, 50), 0)),
                Color = (r:NextNumber() < 0.5) and GLOW or GLOW2, Material = M.Neon, Transparency = 0.25 })
        end
        for _ = 1, 14 do -- kelp forests
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(200, 700)
            K.Far(fx, "Abyss", "Kelp", CFrame.new(centre + Vector3.new(math.cos(a) * d, -1, math.sin(a) * d)) * CFrame.Angles(0, r:NextNumber(0, 6.28), 0), r:NextNumber(4.5, 9))
        end
        return true
    end
    for _ = 1, 26 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(260, 900)
        local w, h = r:NextNumber(60, 160), r:NextNumber(30, 90)
        local p = centre + Vector3.new(math.cos(a) * d, h * 0.3, math.sin(a) * d)
        Pf({ Name = "Reef", Size = Vector3.new(w, h, w * 0.7), CFrame = CFrame.new(p) * CFrame.Angles(r:NextNumber(-0.2, 0.2), r:NextNumber(0, 6), r:NextNumber(-0.2, 0.2)), Color = C3(28, 46, 60), Material = M.Rock })
        Pf({ Name = "ReefGlow", Shape = Enum.PartType.Ball, Size = Vector3.one * r:NextNumber(5, 12), CFrame = CFrame.new(p + Vector3.new(0, h * 0.5, 0)),
            Color = (r:NextNumber() < 0.5) and GLOW or GLOW2, Material = M.Neon, Transparency = 0.2 })
    end
    for _ = 1, 30 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(200, 700)
        local h = r:NextNumber(60, 140)
        Pf({ Name = "FarKelp", Size = Vector3.new(3, h, 6), CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * d, h / 2, math.sin(a) * d)) * CFrame.Angles(0, r:NextNumber(0, 6), 0), Color = C3(30, 70, 50), Material = M.Grass })
    end
    return true
end
function W.Scenery(fx, theme, rng, zC, arena, height)
    local half = arena / 2
    -- bubbles rising from the floor, marine snow drifting down
    local floor = K.Box(fx, Vector3.new(arena, 1, arena), CFrame.new(0, 2, zC))
    K.Emit(floor, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C3(200, 250, 255)), LightEmission = 0.5, Rate = 10,
        Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(8, 8), EmissionDirection = Enum.NormalId.Top,
        Size = NumberSequence.new(0.25, 0.4), Transparency = NumberSequence.new(0.3, 1) })
    local top = K.Box(fx, Vector3.new(arena, 1, arena), CFrame.new(0, height, zC))
    K.Emit(top, { Color = ColorSequence.new(C3(220, 240, 240)), LightEmission = 0.2, Rate = 14, Lifetime = NumberRange.new(10, 14), Speed = NumberRange.new(1, 2),
        SpreadAngle = Vector2.new(30, 30), EmissionDirection = Enum.NormalId.Bottom, Size = NumberSequence.new(0.12, 0.08), Transparency = NumberSequence.new(0.4, 1) })
    -- small jellyfish drifting over the room (client)
    -- (UPDATE 4 LIFE: the real jellyfish (the hero's model, small) in a faint glow; the swim pulse squeezes its bell)
    local jellies = {}
    for i = 1, 6 do
        local col = (i % 2 == 0) and GLOW2 or GLOW
        local j = { C = Vector3.new(rng:NextNumber(-half, half), rng:NextNumber(34, 56), zC + rng:NextNumber(-half, half)), Ph = rng:NextNumber(0, 6) } -- (above the fight)
        local real, body, base = K.Life(fx, "Abyss", "Jelly", rng:NextNumber(0.26, 0.36))
        if real then
            j.M, j.P, j.Base = real, body, base
            local _, sz = real:GetBoundingBox()
            j.G = Neon(fx, Vector3.new(sz.X * 1.05, sz.Y * 0.38, sz.Z * 1.05), CFrame.new(), col, 0.8, Enum.PartType.Ball)
            j.G:SetAttribute("KeepNeon", true)
            j.Up = sz.Y * 0.3
        else
            local m = K.Model(fx, "Jelly")
            j.B = Deco(m, Vector3.new(3, 2, 3), CFrame.new(), col, M.Neon, Enum.PartType.Ball, 0.35)
            j.T = {}
            for k = 0, 3 do table.insert(j.T, Deco(m, Vector3.new(0.2, 4, 0.2), CFrame.new(), col, M.Neon, nil, 0.5)) end
        end
        table.insert(jellies, j)
    end
    K.Live(fx, function(t)
        for _, j in ipairs(jellies) do
            local pos = j.C + Vector3.new(math.sin(t * 0.2 + j.Ph) * 8, math.sin(t * 0.9 + j.Ph) * 2.5, math.cos(t * 0.17 + j.Ph) * 8)
            local p = 1 + math.sin(t * 2 + j.Ph) * 0.12
            if j.M then
                j.P.Size = j.Base * Vector3.new(p, 1 / p, p)
                j.M:PivotTo(CFrame.new(pos) * CFrame.Angles(0, t * 0.15 + j.Ph, 0))
                j.G.CFrame = CFrame.new(pos + Vector3.new(0, j.Up, 0))
                continue
            end
            j.B.Size = Vector3.new(3 * p, 2 / p, 3 * p)
            j.B.CFrame = CFrame.new(pos)
            for k, tp in ipairs(j.T) do
                local a = k * math.pi / 2
                tp.CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 0.9, -2.6, math.sin(a) * 0.9)) * CFrame.Angles(math.sin(t * 1.5 + k) * 0.15, 0, math.cos(t * 1.3 + k) * 0.15)
            end
        end
    end)
end
function W.SetPiece(geo, deco, c, rng, F)
    -- THE TRENCH THRONE: coral pillars and clams round the fight floor, a great jellyfish glowing overhead
    K.Ring(12, 100, c + Vector3.new(0, F, 0), function(p, a, i)
        if i % 2 == 0 then Coral(geo, CFrame.new(p) * CFrame.Angles(0, a, 0), 1.8) else Clam(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1.5) end
    end)
    -- (UPDATE 4 LIFE: the real jellyfish, 60 tall, drifting; the old neon bell stays as its glow and keeps the light)
    local jm = K.Far(deco, "Abyss", "Jelly", CFrame.new(c + Vector3.new(0, F + 62, 140)), 3) -- (high enough that the tentacles clear the rim)
    local bell = Neon(deco, Vector3.new(50, 30, 50), CFrame.new(c + Vector3.new(0, F + 80, 140)), C3(200, 140, 255), jm and 0.8 or 0.4, Enum.PartType.Ball)
    if jm then
        local cf0, sz = jm:GetBoundingBox()
        bell.Size = Vector3.new(sz.X * 1.06, sz.Y * 0.36, sz.Z * 1.06)
        bell.CFrame = CFrame.new(cf0.Position + Vector3.new(0, sz.Y * 0.3, 0))
        bell:SetAttribute("KeepNeon", true)
        local base, gbase = jm:GetPivot(), bell.CFrame
        K.Live(deco, function(t)
            local bob = Vector3.new(0, math.sin(t * 0.4) * 5, 0)
            jm:PivotTo(base * CFrame.Angles(0, t * 0.05, 0) + bob)
            bell.CFrame = gbase + bob
        end)
    end
    K.Light(bell, C3(160, 220, 255), 70, 1.0)
    return GLOW
end

W.Theme = {
    Name = "The Deep",
    Floor = { Color = C3(66, 90, 98), Material = M.Sand },
    FloorAlt = { Color = C3(52, 72, 86), Material = M.Slate },
    Wall = { Color = C3(48, 66, 80), Material = M.Rock },
    WallTrim = { Color = C3(36, 52, 66), Material = M.Slate },
    Ceiling = { Color = C3(24, 40, 54), Material = M.Rock },
    Prop = { Color = C3(60, 82, 96), Material = M.Rock },
    PropAlt = { Color = CORAL, Material = M.SmoothPlastic },
    Hazard = { Color = C3(40, 120, 140), Material = M.Glass, Transparency = 0.3 },
    Accent = GLOW, Light = C3(170, 230, 255), LampBrightness = 1.3, LampRange = 50,
    OpenSky = true,
}
W.Ambience = { Mote = C3(190, 250, 255), Mote2 = C3(200, 150, 255), MoteRise = true, Glow = GLOW }
-- (UPDATE 4 LIGHTING AUDIT: the deep-blue ambient had no red -> the gun's slide read L25; a brighter, less saturated sea
-- ambient + exposure -> L48, still deep water)
W.Light = { ClockTime = 12, Brightness = 1.3, Ambient = C3(111, 137, 160), OutdoorAmbient = C3(122, 151, 173),
    FogColor = C3(14, 62, 92), FogStart = 50, FogEnd = 420, Exposure = 0.8, EnvDiffuse = 0.3,
    BloomIntensity = 0.6, BloomThreshold = 1.05, BloomSize = 26,
    CCBrightness = 0, CCContrast = 0.1, CCSaturation = 0.08, CCTint = C3(205, 238, 255) }
W.Atmo = { 0.5, C3(40, 140, 176), C3(8, 40, 70), 2.6, 0 }
W.Terrain = { [M.Sand] = C3(70, 98, 104), [M.Rock] = C3(44, 62, 78), [M.Slate] = C3(50, 70, 86), [M.Basalt] = C3(30, 42, 54) }
-- (UPDATE 4 wrap-up, RoomGen.DressFor: the room pieces in this world's own language -- reef rock (no more sand pillars), coral growing on top)
W.Cover = { Stone = M.Rock, Crown = { World = "Abyss", Name = "Coral", Fit = 0.9, MaxH = 6, Alt = { "SeaFan", "BrainCoral" } } }
W.Contrast = C3(255, 200, 40)
W.EA = { Warn = C3(255, 70, 150), Core = C3(255, 220, 240), Mat = M.ForceField }
W.Moods = {
    { Id = "Bioglow", W = 3 },
    { Id = "Shallows", Name = "Sunlit Shallows", W = 2, Fog = C3(60, 170, 190), FogAmt = 0.35, Exp = 0.06 },
    { Id = "Midnight", Name = "Midnight Zone", W = 2, Val = 0.85, Acc = 0.78, Fog = C3(10, 20, 60), FogAmt = 0.4, Exp = -0.08 },
    { Id = "RedTide", Name = "Red Tide", W = 1, Acc = 0.97, Fog = C3(120, 50, 70), FogAmt = 0.3 },
}
-- (2026-10-24: Up re-rendered with hdri_sky.blur_wrap -- a faint cut through the clouds in the window overhead is gone)
W.Sky = { Bk = "121542687562858", Dn = "100656285064687", Ft = "108301897113940", Lf = "112821853379994", Rt = "87757880572549", Up = "116094566951463" } -- (UPDATE 4 SKIES v4: tools/hdri_sky.py)
return W
