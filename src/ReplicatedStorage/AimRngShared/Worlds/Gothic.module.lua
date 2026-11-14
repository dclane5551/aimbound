--!nocheck
-- MOONLIT SPIRES (0.87 world): a gothic city under a huge moon -- wet cobblestones, wrought-iron fences, gas lanterns,
-- tombs and weeping angel statues, chapel spires; a cathedral on the skyline, ground mist and bats. Sister: Void.
local K = require(script.Parent.Parent:WaitForChild("WorldKit"))
local C3, M = K.C3, K.M
local P, Solid, Deco, Neon, Wedge = K.P, K.Solid, K.Deco, K.Neon, K.Wedge

local STONE, STONE2, DARK, IRON = C3(86, 86, 98), C3(70, 70, 82), C3(40, 40, 50), C3(26, 26, 32)
local LAMP, MOSS, ROOF = C3(255, 196, 120), C3(64, 74, 60), C3(44, 46, 60)

local W = {}
W.Id = "Gothic"
W.Title = "MOONLIT SPIRES"
W.TitleColor = C3(190, 196, 255)
W.Sister = "Void"
W.HazardName = "Grave Mire"

-- ==================== PIECES ====================
-- (UPDATE 4 prop pass: real textured models from ReplicatedStorage.WorldProps.Gothic via WorldKit.Prop when the place has
-- them; the part build under each is the fallback. Gameplay boxes measured from the models' height maps.)
local HIT_FENCE = { { Vector3.new(9.2, 1.2, 1.2), Vector3.new(0, 0.6, 0.1) }, { Vector3.new(1.2, 5.2, 1.4), Vector3.new(-4.1, 2.6, 0.1) }, { Vector3.new(1.2, 5.2, 1.4), Vector3.new(4.2, 2.6, 0.1) } }
local HIT_TOMB = { { Vector3.new(3.8, 2, 2.2), Vector3.new(-0.9, 1, -0.4) }, { Vector3.new(1.4, 4.6, 1), Vector3.new(-1.3, 2.3, 1) }, { Vector3.new(1, 4.6, 1), Vector3.new(2.3, 2.3, -1) } }
local HIT_ANGEL = { { Vector3.new(4.4, 1.2, 4), Vector3.new(0, 0.6, 0) }, { Vector3.new(2.6, 8.6, 2.2), Vector3.new(0, 4.3, 0.2) } }
local function Fence(geo, cf, s)
    if K.Prop(geo, "Gothic", "Fence", cf, s, HIT_FENCE) then return end
    -- a stone footing (cover) with iron bars and spear tips (decoration: shots pass between the bars)
    Solid(geo, Vector3.new(9 * s, 1.4 * s, 1.2 * s), cf * CFrame.new(0, 0.7 * s, 0), STONE2, M.Cobblestone)
    Deco(geo, Vector3.new(9.2 * s, 0.25 * s, 1.4 * s), cf * CFrame.new(0, 1.5 * s, 0), STONE, M.Slate)
    for i = 0, 12 do
        local x = (i / 12 - 0.5) * 8.6 * s
        Deco(geo, Vector3.new(0.14 * s, 3.2 * s, 0.14 * s), cf * CFrame.new(x, 3.2 * s, 0), IRON, M.Metal)
        Deco(geo, Vector3.new(0.3 * s, 0.4 * s, 0.14 * s), cf * CFrame.new(x, 4.95 * s, 0) * CFrame.Angles(0, 0, math.rad(45)), IRON, M.Metal)
    end
    Deco(geo, Vector3.new(8.8 * s, 0.14 * s, 0.14 * s), cf * CFrame.new(0, 4.2 * s, 0), IRON, M.Metal)
    for _, sx in ipairs({ -1, 1 }) do
        Solid(geo, Vector3.new(1.3 * s, 5.2 * s, 1.5 * s), cf * CFrame.new(sx * 4.8 * s, 2.6 * s, 0), STONE, M.Cobblestone)
        Deco(geo, Vector3.new(1.0 * s, 1.0 * s, 1.0 * s), cf * CFrame.new(sx * 4.8 * s, 5.7 * s, 0), STONE2, M.Slate, Enum.PartType.Ball)
    end
end
local function Lantern(geo, cf, s, lit)
    if K.Prop(geo, "Gothic", "Lantern", cf, s, { { Vector3.new(0.7, 9, 0.7), Vector3.new(0, 4.5, 0) } }) then
        local glow = Neon(geo, Vector3.new(0.55, 0.8, 0.55) * s, cf * CFrame.new(0, 8.8 * s, 0), LAMP, 0.1) -- (the flame inside the cage)
        if lit then K.Light(glow, LAMP, 26, 1.1) end
        return
    end
    -- a gas lantern: iron post, scrolled arm, a cage with warm glass
    Solid(geo, Vector3.new(0.5 * s, 9 * s, 0.5 * s), cf * CFrame.new(0, 4.5 * s, 0), IRON, M.Metal)
    Deco(geo, Vector3.new(1.4 * s, 0.6 * s, 1.4 * s), cf * CFrame.new(0, 0.3 * s, 0), IRON, M.Metal)
    local head = cf * CFrame.new(0, 9.6 * s, 0)
    Deco(geo, Vector3.new(1.3 * s, 0.2 * s, 1.3 * s), head * CFrame.new(0, -0.9 * s, 0), IRON, M.Metal)
    local glass = Neon(geo, Vector3.new(1.0 * s, 1.5 * s, 1.0 * s), head, LAMP, 0.15)
    Wedge(geo, Vector3.new(1.5 * s, 0.7 * s, 0.75 * s), head * CFrame.new(0, 1.1 * s, -0.37 * s), IRON, M.Metal)
    Wedge(geo, Vector3.new(1.5 * s, 0.7 * s, 0.75 * s), head * CFrame.new(0, 1.1 * s, 0.37 * s) * CFrame.Angles(0, math.pi, 0), IRON, M.Metal)
    if lit then K.Light(glass, LAMP, 26, 1.1) end
end
local function Tomb(geo, cf, s)
    if K.Prop(geo, "Gothic", "Tomb", cf, s, HIT_TOMB) then return end
    -- a stone sarcophagus with a carved lid, two leaning headstones behind it
    Solid(geo, Vector3.new(3.4 * s, 2.2 * s, 6.4 * s), cf * CFrame.new(0, 1.1 * s, 0), STONE2, M.Slate)
    Deco(geo, Vector3.new(3.8 * s, 0.5 * s, 6.8 * s), cf * CFrame.new(0, 2.45 * s, 0), STONE, M.Slate)
    Deco(geo, Vector3.new(0.5 * s, 0.3 * s, 3 * s), cf * CFrame.new(0, 2.85 * s, 0), STONE, M.Slate)
    Deco(geo, Vector3.new(1.8 * s, 0.3 * s, 0.5 * s), cf * CFrame.new(0, 2.85 * s, -0.6 * s), STONE, M.Slate)
    for k, x in ipairs({ -2.6, 2.4 }) do
        Solid(geo, Vector3.new(2 * s, 3 * s, 0.5 * s), cf * CFrame.new(x * s, 1.4 * s, 4.2 * s) * CFrame.Angles(math.rad(k * 6 - 9), 0, math.rad(k * 5 - 7)), STONE, M.Slate)
    end
    Deco(geo, Vector3.new(3.2 * s, 0.2 * s, 2 * s), cf * CFrame.new(-1 * s, 2.25 * s, 1.2 * s), MOSS, M.Grass)
end
local function Angel(geo, cf, s)
    if K.Prop(geo, "Gothic", "Angel", cf, s, HIT_ANGEL) then return end
    -- a weeping angel on a plinth: robed body, bowed head, folded wings rising behind
    Solid(geo, Vector3.new(3.4 * s, 2.4 * s, 3.4 * s), cf * CFrame.new(0, 1.2 * s, 0), STONE2, M.Slate)
    local body = cf * CFrame.new(0, 2.4 * s, 0)
    Solid(geo, Vector3.new(2 * s, 5 * s, 1.6 * s), body * CFrame.new(0, 2.5 * s, 0), STONE, M.Marble)
    Deco(geo, Vector3.new(2.6 * s, 1.6 * s, 2 * s), body * CFrame.new(0, 0.8 * s, 0), STONE, M.Marble)
    Deco(geo, Vector3.one * 1.3 * s, body * CFrame.new(0, 5.5 * s, -0.4 * s), STONE, M.Marble, Enum.PartType.Ball)
    Deco(geo, Vector3.new(1.6 * s, 1.0 * s, 0.6 * s), body * CFrame.new(0, 4.6 * s, -0.95 * s) * CFrame.Angles(math.rad(-30), 0, 0), STONE, M.Marble) -- (hands over the face)
    for _, sx in ipairs({ -1, 1 }) do
        Wedge(geo, Vector3.new(0.4 * s, 6 * s, 2.2 * s), body * CFrame.new(sx * 1.3 * s, 4 * s, 1.0 * s) * CFrame.Angles(0, sx * math.rad(12), 0), STONE, M.Marble)
    end
end
local function Spire(geo, cf, s)
    if K.Prop(geo, "Gothic", "Spire", cf, s, { { Vector3.new(5, 14, 5), Vector3.new(0, 7, 0) } }) then return end
    -- a chapel tower: square stone shaft, a dark pointed window with a faint glow, a tall slate spire and a finial
    local h = 14 * s
    Solid(geo, Vector3.new(5 * s, h, 5 * s), cf * CFrame.new(0, h / 2, 0), STONE2, M.Cobblestone)
    Deco(geo, Vector3.new(5.6 * s, 0.6 * s, 5.6 * s), cf * CFrame.new(0, h, 0), STONE, M.Slate)
    Neon(geo, Vector3.new(1.4 * s, 3 * s, 0.1), cf * CFrame.new(0, h * 0.62, -2.52 * s), C3(255, 170, 100), 0.35)
    Deco(geo, Vector3.new(1.8 * s, 0.4 * s, 0.2), cf * CFrame.new(0, h * 0.62 + 1.6 * s, -2.55 * s), STONE, M.Slate)
    for k = 0, 3 do
        Wedge(geo, Vector3.new(5 * s, 10 * s, 2.5 * s), cf * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, h + 5 * s, -1.25 * s), ROOF, M.Slate)
    end
    Deco(geo, Vector3.new(0.25 * s, 2.4 * s, 0.25 * s), cf * CFrame.new(0, h + 11 * s, 0), IRON, M.Metal)
    Deco(geo, Vector3.new(1.2 * s, 0.25 * s, 0.25 * s), cf * CFrame.new(0, h + 11.5 * s, 0), IRON, M.Metal)
end

W.Props = {
    Cover = { function(geo, _, rng, pos) Fence(geo, CFrame.new(pos) * K.Yaw(rng), 0.8) end, function(geo, _, rng, pos) Tomb(geo, CFrame.new(pos) * K.Yaw(rng), 1) end },
    Tall = { function(geo, _, rng, pos) Angel(geo, CFrame.new(pos) * K.Yaw(rng), 1) end, function(geo, _, rng, pos) Lantern(geo, CFrame.new(pos), 1, false) end },
    Air = {},
}
W.Landmarks = {
    function(geo, _, rng, c) -- THE MOURNING CIRCLE: four weeping angels round the plaza, lanterns between
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            local p = c + Vector3.new(math.cos(a) * 31, 0, math.sin(a) * 31)
            Angel(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1)
            local q = c + Vector3.new(math.cos(a + math.pi / 4) * 34, 0, math.sin(a + math.pi / 4) * 34)
            Lantern(geo, CFrame.new(q), 1, i == 0)
        end
    end,
    function(geo, _, rng, c) -- THE OLD CEMETERY: tombs round the plaza under two lanterns
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2 + 0.25
            Tomb(geo, CFrame.lookAt(c + Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32), c), 0.9)
        end
        Lantern(geo, CFrame.new(c + Vector3.new(-30, 0, 0)), 1, true)
        Lantern(geo, CFrame.new(c + Vector3.new(30, 0, 0)), 1, false)
    end,
}
W.Kits = {
    GtFence = function(g, cf, s) Fence(g, cf, s * 0.6) end,
    GtTomb = function(g, cf, s) Tomb(g, cf, s * 0.6) end,
    GtAngel = function(g, cf, s) Angel(g, cf, s * 0.5) end,
    GtLamp = function(g, cf, s) Lantern(g, cf, s * 0.5, false) end,
    GtSpire = function(g, cf, s) Spire(g, cf, s * 0.6) end,
}
W.Templates = {
    { Name = "Cathedral Square", Rim = "Ruins", RimMat = { M.Cobblestone, M.Slate }, Ground = M.Cobblestone, Patch = { M.Slate, M.Pavement },
        Edge = { "GtFence", "GtTomb", "GtLamp" }, RimKit = { "GtSpire", "GtSpire", "GtAngel" }, Hero = "GtCathedral", Glow = { GtLamp = LAMP } },
    { Name = "Graveyard Hill", Rim = "Cliffs", RimMat = { M.Rock, M.Slate }, RimAccent = M.Mud, PartyRim = "GtSpire", Ground = M.Ground, Patch = { M.Mud, M.Cobblestone },
        Edge = { "GtTomb", "GtAngel", "GtFence" }, RimKit = { "GtTomb", "GtAngel", "GtSpire" }, Hero = "GtCathedral" },
    { Name = "Iron Bridge", Rim = "Edge", RimMat = { M.Slate, M.Rock }, Ground = M.Pavement, Patch = { M.Cobblestone, M.Slate },
        Edge = { "GtFence", "GtLamp", "GtTomb" }, RimKit = { "GtFence", "GtLamp", "GtSpire" }, Hero = "GtCathedral", Glow = { GtLamp = LAMP } },
}
W.Heroes = {}
function W.Heroes.GtCathedral(fx, ctx)
    -- a cathedral on the far side: a long nave, two west towers with spires, a glowing rose window and lit lancets
    local c = Vector3.new(30, 0, ctx.zC + ctx.half * 3.6)
    if K.Prop(fx, "Gothic", "Cathedral", CFrame.new(c + Vector3.new(0, 0, 55)), 1) then return end -- (UPDATE 4: one real model)
    P(fx, { Size = Vector3.new(90, 70, 160), CFrame = CFrame.new(c + Vector3.new(0, 35, 60)), Color = DARK, Material = M.Slate })
    P(fx, { Class = "WedgePart", Size = Vector3.new(90, 40, 80), CFrame = CFrame.new(c + Vector3.new(0, 90, 20)), Color = ROOF, Material = M.Slate })
    P(fx, { Class = "WedgePart", Size = Vector3.new(90, 40, 80), CFrame = CFrame.new(c + Vector3.new(0, 90, 100)) * CFrame.Angles(0, math.pi, 0), Color = ROOF, Material = M.Slate })
    for _, sx in ipairs({ -1, 1 }) do
        local t = c + Vector3.new(sx * 55, 0, -10)
        P(fx, { Size = Vector3.new(30, 130, 30), CFrame = CFrame.new(t + Vector3.new(0, 65, 0)), Color = STONE2, Material = M.Slate })
        for k = 0, 3 do
            P(fx, { Class = "WedgePart", Size = Vector3.new(30, 70, 15), CFrame = CFrame.new(t + Vector3.new(0, 165, 0)) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -7.5), Color = ROOF, Material = M.Slate })
        end
        for k = 0, 2 do P(fx, { Size = Vector3.new(5, 16, 1), CFrame = CFrame.new(t + Vector3.new(0, 40 + k * 26, -15.6)), Color = LAMP, Material = M.Neon, Transparency = 0.3 }) end
    end
    P(fx, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 34, 34), CFrame = CFrame.new(c + Vector3.new(0, 70, -31.2)) * CFrame.Angles(0, math.rad(90), 0), Color = C3(200, 120, 255), Material = M.Neon, Transparency = 0.2 })
    P(fx, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 38, 38), CFrame = CFrame.new(c + Vector3.new(0, 70, -30.6)) * CFrame.Angles(0, math.rad(90), 0), Color = STONE, Material = M.Slate })
    P(fx, { Size = Vector3.new(140, 70, 20), CFrame = CFrame.new(c + Vector3.new(0, 35, -20)), Color = STONE2, Material = M.Slate })
end
W.Vista = { Ground = C3(30, 30, 38), GroundMat = M.Slate, Peak = C3(40, 40, 52), PeakMat = M.Slate, Tip = C3(120, 120, 150) }
function W.VistaFn(fx, Pf, centre, gy, zC, r)
    -- rooftops to the horizon: dark blocks with pitched roofs, chimneys, a scatter of lit windows, more spires
    -- (UPDATE 4 VISTA: real models to the horizon -- WorldKit.Far props + tinted scanned mountains; the part version
    -- below stays as the fallback for an unsaved place)
    if K.HasProp("Gothic", "Townhouses") then
        for _ = 1, 16 do -- rows of steep-roofed townhouses facing the graveyard
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(280, 950)
            local p = centre + Vector3.new(math.cos(a) * d, -1, math.sin(a) * d)
            K.Far(fx, "Gothic", "Townhouses", CFrame.lookAt(p, Vector3.new(centre.X, p.Y, centre.Z)) * CFrame.Angles(0, r:NextNumber(-0.3, 0.3), 0), 1.1 + d / 800)
        end
        for _ = 1, 4 do -- far chapel spires
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(500, 950)
            K.Far(fx, "Gothic", "Spire", CFrame.new(centre + Vector3.new(math.cos(a) * d, -2, math.sin(a) * d)), r:NextNumber(2, 3))
        end
        for k = 1, 4 do -- black hills under the moon
            local a, d = (k / 4 + r:NextNumber(-0.08, 0.08)) * math.pi * 2, r:NextNumber(1050, 1250)
            K.Mesh(fx, "Mountain", CFrame.new(centre + Vector3.new(math.cos(a) * d, -40, math.sin(a) * d)) * CFrame.Angles(0, a + math.pi / 2, 0), r:NextNumber(240, 340), C3(44, 44, 58), { Shadow = false })
        end
        return true
    end
    for _ = 1, 30 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(280, 1000)
        local w, h, dd = r:NextNumber(30, 70), r:NextNumber(30, 90), r:NextNumber(30, 60)
        local p = centre + Vector3.new(math.cos(a) * d, h / 2, math.sin(a) * d)
        local yaw = CFrame.Angles(0, r:NextNumber(0, 6), 0)
        Pf({ Name = "House", Size = Vector3.new(w, h, dd), CFrame = CFrame.new(p) * yaw, Color = C3(30, 30, 40), Material = M.Slate })
        Pf({ Name = "Roof", Size = Vector3.new(w * 0.72, w * 0.72, dd), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * yaw * CFrame.Angles(0, 0, math.rad(45)), Color = ROOF, Material = M.Slate })
        if r:NextNumber() < 0.5 then
            Pf({ Name = "Window", Size = Vector3.new(4, 6, 1), CFrame = CFrame.new(p) * yaw * CFrame.new(r:NextNumber(-w / 3, w / 3), r:NextNumber(-h / 4, h / 4), -dd / 2 - 0.6), Color = LAMP, Material = M.Neon })
        end
        if r:NextNumber() < 0.25 then
            Pf({ Name = "FarSpire", Size = Vector3.new(10, 70, 10), CFrame = CFrame.new(p + Vector3.new(0, h / 2 + 35, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = C3(26, 26, 36), Material = M.Slate })
        end
    end
    return true
end
function W.Scenery(fx, theme, rng, zC, arena, height)
    local half = arena / 2
    -- ground mist creeping over the floor
    local low = K.Box(fx, Vector3.new(arena, 1, arena), CFrame.new(0, 2.5, zC))
    K.Emit(low, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(170, 176, 210)), Rate = 5, Lifetime = NumberRange.new(8, 11),
        Speed = NumberRange.new(0.4, 1.2), SpreadAngle = Vector2.new(180, 5), Size = NumberSequence.new(8, 16), Transparency = NumberSequence.new(0.86, 1),
        EmissionDirection = Enum.NormalId.Top, LightEmission = 0.05, Acceleration = Vector3.new(0.6, -0.05, 0) })
    -- bats circling high over the walls (client)
    -- (UPDATE 4 LIFE: a real bat model; the wing beat = its mesh's span squeezed in and out, banking into the turn)
    local bats = {}
    for i = 1, 7 do
        local s = rng:NextNumber(0.8, 1.15)
        local real, body, base = K.Life(fx, "Gothic", "Bat", s, C3(96, 88, 104)) -- (darker: the moonlight paled it)
        local b = { Rad = rng:NextNumber(half * 0.6, half * 1.1), H = height + rng:NextNumber(4, 30), Ph = rng:NextNumber(0, 6), Sp = rng:NextNumber(0.25, 0.45) }
        if real then
            b.M, b.P, b.Base = real, body, base
        else
            local m = K.Model(fx, "Bat")
            b.B = Deco(m, Vector3.new(0.8, 0.6, 1.2), CFrame.new(), IRON, M.SmoothPlastic)
            b.L = Deco(m, Vector3.new(2.2, 0.1, 1.0), CFrame.new(-1.4, 0, 0), IRON, M.SmoothPlastic)
            b.R = Deco(m, Vector3.new(2.2, 0.1, 1.0), CFrame.new(1.4, 0, 0), IRON, M.SmoothPlastic)
        end
        table.insert(bats, b)
    end
    K.Live(fx, function(t)
        for _, b in ipairs(bats) do
            local a = t * b.Sp + b.Ph
            local pos = Vector3.new(math.cos(a) * b.Rad, b.H + math.sin(t * 1.3 + b.Ph) * 3, zC + math.sin(a) * b.Rad)
            local cf = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
            if b.M then
                local beat = math.sin(t * 13 + b.Ph * 3)
                b.P.Size = b.Base * Vector3.new(0.62 + 0.38 * math.abs(beat), 1 + 0.25 * math.max(beat, 0), 1)
                b.M:PivotTo(cf * CFrame.Angles(0, 0, -0.35 + math.sin(t * 0.9 + b.Ph) * 0.12))
            else
                local flap = math.sin(t * 14 + b.Ph) * 0.7
                b.B.CFrame = cf
                b.L.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-1.3, 0, 0)
                b.R.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(1.3, 0, 0)
            end
        end
    end)
    -- (open maps' walls are invisible: nothing goes on the wall tops)
end
function W.SetPiece(geo, deco, c, rng, F)
    -- THE MIDNIGHT RING: angels and lanterns round the fight floor, a giant clock face glowing on the far side
    K.Ring(12, 100, c + Vector3.new(0, F, 0), function(p, a, i)
        if i % 2 == 0 then Angel(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1.7) else Lantern(geo, CFrame.new(p), 1.5, i == 3) end
    end)
    local clock = CFrame.new(c + Vector3.new(0, F + 55, 150))
    -- (UPDATE 4: a real gothic clock housing, 95 tall, the dial at the old face; the iron hands turn over it (client),
    -- lit from in front by the old face's light)
    if K.Far(deco, "Gothic", "ClockFace", CFrame.new(c + Vector3.new(0, F + 7.5, 151.2)), 9.5) then
        K.Light(K.Box(deco, Vector3.new(1, 1, 1), clock * CFrame.new(0, 0, -8)), C3(255, 230, 190), 70, 1.0)
        local min = Deco(deco, Vector3.new(1.5, 20, 0.6), clock, IRON, M.Metal)
        local hr = Deco(deco, Vector3.new(2, 13, 0.6), clock, IRON, M.Metal)
        local cap = Deco(deco, Vector3.new(0.8, 3.4, 3.4), clock * CFrame.new(0, 0, -3.4) * CFrame.Angles(0, math.rad(90), 0), IRON, M.Metal, Enum.PartType.Cylinder)
        local function Hands(t)
            min.CFrame = clock * CFrame.Angles(0, 0, 0.6 + t * 0.06) * CFrame.new(0, 8, -2.6) -- (in front of the numerals' relief)
            hr.CFrame = clock * CFrame.Angles(0, 0, 2.2 + t * 0.005) * CFrame.new(0, 5, -3.1)
        end
        Hands(0)
        K.Live(deco, Hands)
        return C3(220, 60, 80)
    end
    Deco(deco, Vector3.new(70, 120, 20), clock * CFrame.new(0, -30, 10), DARK, M.Slate)
    local face = Deco(deco, Vector3.new(1, 50, 50), clock * CFrame.Angles(0, math.rad(90), 0), C3(250, 236, 200), M.Neon, Enum.PartType.Cylinder, 0.1)
    K.Light(face, C3(255, 230, 190), 70, 1.0)
    Deco(deco, Vector3.new(1.5, 18, 1), clock * CFrame.new(0, 7, -1.2) * CFrame.Angles(0, 0, math.rad(20)), IRON, M.Metal)
    Deco(deco, Vector3.new(1.5, 13, 1), clock * CFrame.new(4, -2, -1.2) * CFrame.Angles(0, 0, math.rad(-70)), IRON, M.Metal)
    return C3(220, 60, 80)
end

W.Theme = {
    Name = "Moonlit Spires",
    Floor = { Color = C3(74, 74, 84), Material = M.Cobblestone },
    FloorAlt = { Color = C3(60, 60, 70), Material = M.Slate },
    Wall = { Color = C3(80, 78, 90), Material = M.Cobblestone },
    WallTrim = { Color = C3(40, 40, 48), Material = M.Metal },
    Ceiling = { Color = C3(34, 34, 44), Material = M.Slate },
    Prop = { Color = C3(90, 90, 100), Material = M.Slate },
    PropAlt = { Color = C3(60, 64, 56), Material = M.Grass },
    Hazard = { Color = C3(60, 70, 50), Material = M.Mud },
    Accent = LAMP, Light = C3(255, 214, 170), LampBrightness = 1.3, LampRange = 50,
    OpenSky = true,
}
W.Ambience = { Mote = C3(200, 206, 255), Mote2 = C3(255, 200, 140), MoteRise = false, Glow = LAMP }
W.Light = { ClockTime = 13, Brightness = 0.5, -- (0.89: a night clock dims the skybox -- the painted moon sky never showed; day clock + a dim sun)
    -- (UPDATE 4 LIGHTING AUDIT: gun slide L25 -> L53, still a moonlit night)
    Ambient = C3(144, 150, 198), OutdoorAmbient = C3(154, 160, 213),
    FogColor = C3(56, 60, 86), FogStart = 110, FogEnd = 620, Exposure = 1.1, EnvDiffuse = 0.3,
    BloomIntensity = 0.5, BloomThreshold = 1.1, BloomSize = 24,
    CCBrightness = 0, CCContrast = 0.14, CCSaturation = -0.1, CCTint = C3(226, 232, 255) }
W.Atmo = { 0.4, C3(120, 126, 160), C3(40, 44, 70), 2.2, 0 }
W.Terrain = { [M.Cobblestone] = C3(80, 80, 90), [M.Slate] = C3(66, 66, 78), [M.Mud] = C3(54, 52, 50), [M.Ground] = C3(60, 58, 56),
    [M.Rock] = C3(78, 78, 90), [M.Pavement] = C3(88, 88, 98) }
-- (UPDATE 4 wrap-up, RoomGen.DressFor: the room pieces in this world's own language -- dark slate cemetery columns, a weeping angel on each)
W.Cover = { Built = true, Stone = M.Slate, Crown = { World = "Gothic", Name = "Angel", Fit = 0.85, MaxH = 8, Alt = { "Lantern", "Tomb" } } }
W.Contrast = C3(255, 120, 60)
W.EA = { Warn = C3(230, 40, 70), Core = C3(255, 190, 200), Mat = M.Neon }
W.Moods = {
    { Id = "Moonlit", W = 3 },
    { Id = "BloodMoon", Name = "Blood Moon", W = 2, Acc = 0.0, Fog = C3(130, 30, 44), FogAmt = 0.36, CCSat = 0.04 },
    { Id = "Fogbound", Name = "Fogbound", W = 2, Sat = 0.7, Fog = C3(150, 154, 172), FogAmt = 0.45, Dens = 1.35 },
    { Id = "Gaslight", Name = "Gaslight", W = 2, Acc = 0.09, Fog = C3(150, 116, 70), FogAmt = 0.3, Exp = 0.03 },
}
W.Sky = { Bk = "139329572884312", Dn = "103802239644467", Ft = "118280724449024", Lf = "125918690766978", Rt = "118245698843775", Up = "128259405837850" } -- (UPDATE 4 SKIES v4: tools/hdri_sky.py)
return W
