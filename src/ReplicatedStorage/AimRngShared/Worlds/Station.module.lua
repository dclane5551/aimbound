--!nocheck
-- DERELICT STATION (0.87 world): a space station's hull breached open to the stars -- clean white / grey panels gone dark,
-- red emergency lights, cargo containers, terminal consoles, pipe bundles, bulkhead frames, reactor columns; a planet
-- hanging below, trusses and solar arrays reaching away, debris drifting. (Not the neon city: Cyber owns that.)
-- Sister: Cyber.
local K = require(script.Parent.Parent:WaitForChild("WorldKit"))
local C3, M = K.C3, K.M
local P, Solid, Deco, Neon, Wedge = K.P, K.Solid, K.Deco, K.Neon, K.Wedge

local PANEL, PANEL2, DARK, STEEL = C3(186, 190, 196), C3(150, 154, 160), C3(52, 54, 60), C3(110, 114, 122)
local RED, AMBER, SCREEN, CORE = C3(255, 50, 40), C3(255, 170, 40), C3(80, 200, 255), C3(120, 220, 255)
local ORANGE, BLUE = C3(220, 110, 40), C3(50, 90, 160)

local W = {}
W.Id = "Station"
W.Title = "DERELICT STATION"
W.TitleColor = C3(200, 220, 240)
W.Sister = "Cyber"
W.HazardName = "Coolant Leak"

local function Stripes(geo, cf, w, h, s)
    for k = 0, math.floor(w / (0.9 * s)) - 1 do
        Deco(geo, Vector3.new(0.45 * s, h, 0.06), cf * CFrame.new(-w / 2 + (k + 0.5) * 0.9 * s, 0, 0) * CFrame.Angles(0, 0, 0.6), (k % 2 == 0) and AMBER or DARK, M.SmoothPlastic)
    end
end
-- (UPDATE 4 prop pass: real textured models from ReplicatedStorage.WorldProps.Station via WorldKit.Prop when the place has
-- them; the part build under each is the fallback. Gameplay boxes = the old solid parts, so cover plays the same.)
local function Container(geo, cf, s, col)
    if K.Prop(geo, "Station", (col == ORANGE) and "ContainerO" or "ContainerB", cf, s, { { Vector3.new(8, 3.6, 3.6), Vector3.new(0, 1.8, 0) } }) then return end
    -- a ribbed cargo container with a stencilled band and corner castings
    local c = col or ORANGE
    Solid(geo, Vector3.new(8 * s, 3.6 * s, 3.6 * s), cf * CFrame.new(0, 1.8 * s, 0), c, M.Metal)
    for k = -3, 3 do Deco(geo, Vector3.new(0.25 * s, 3.4 * s, 3.7 * s), cf * CFrame.new(k * 1.1 * s, 1.8 * s, 0), c:Lerp(Color3.new(0, 0, 0), 0.2), M.Metal) end
    for _, sx in ipairs({ -1, 1 }) do
        for _, y in ipairs({ 0.2, 3.4 }) do Deco(geo, Vector3.new(0.5 * s, 0.4 * s, 3.8 * s), cf * CFrame.new(sx * 3.85 * s, y * s, 0), DARK, M.Metal) end
    end
    Deco(geo, Vector3.new(3 * s, 0.6 * s, 0.05), cf * CFrame.new(-1.6 * s, 2.6 * s, -1.84 * s), C3(240, 240, 240), M.SmoothPlastic)
end
local function Console(geo, cf, s)
    if K.Prop(geo, "Station", "Console", cf, s, { { Vector3.new(6, 2.4, 2), Vector3.new(0, 1.2, 0) }, { Vector3.new(6, 1.2, 1.4), Vector3.new(0, 3, 0.3) } }) then return end
    -- a terminal bank: a sloped desk with glowing screens, a broken one sparking
    Solid(geo, Vector3.new(6 * s, 2.4 * s, 2 * s), cf * CFrame.new(0, 1.2 * s, 0), PANEL2, M.SmoothPlastic)
    Wedge(geo, Vector3.new(6 * s, 1.2 * s, 1.4 * s), cf * CFrame.new(0, 3.0 * s, 0.3 * s), PANEL, M.SmoothPlastic, true)
    for k = -1, 1 do
        local scr = Neon(geo, Vector3.new(1.6 * s, 0.9 * s, 0.05), cf * CFrame.new(k * 1.9 * s, 3.05 * s, -0.08 * s) * CFrame.Angles(math.rad(-40), 0, 0), (k == 1) and RED or SCREEN, 0.15)
        if k == 1 then scr.Name = "Flicker" end
    end
    Deco(geo, Vector3.new(6.1 * s, 0.2 * s, 2.1 * s), cf * CFrame.new(0, 0.1 * s, 0), DARK, M.Metal)
    Stripes(geo, cf * CFrame.new(0, 0.6 * s, -1.03 * s), 5.4 * s, 0.4 * s, s)
end
local function Pipes(geo, cf, s)
    if K.Prop(geo, "Station", "Pipes", cf, s, { { Vector3.new(0.8, 2.4, 3.4), Vector3.new(-3, 1.2, 0) }, { Vector3.new(0.8, 2.4, 3.4), Vector3.new(0, 1.2, 0) }, { Vector3.new(0.8, 2.4, 3.4), Vector3.new(3, 1.2, 0) } }) then return end
    -- a pipe bundle on saddles at waist height (cover), valve wheels, a leaking joint venting mist
    for _, x in ipairs({ -3, 0, 3 }) do Solid(geo, Vector3.new(0.8 * s, 2.4 * s, 3.4 * s), cf * CFrame.new(x * s, 1.2 * s, 0), DARK, M.Metal) end
    for k, z in ipairs({ -1, 0, 1 }) do
        Deco(geo, Vector3.new(9 * s, 1.0 * s, 1.0 * s), cf * CFrame.new(0, (2.2 + (k % 2) * 0.3) * s, z * 1.05 * s), (k == 2) and C3(200, 60, 50) or STEEL, M.Metal, Enum.PartType.Cylinder)
    end
    Deco(geo, Vector3.new(0.2 * s, 1.4 * s, 1.4 * s), cf * CFrame.new(2.2 * s, 3.1 * s, -1.05 * s), RED, M.Metal, Enum.PartType.Cylinder)
    local leak = Deco(geo, Vector3.new(0.3, 0.3, 0.3), cf * CFrame.new(-1.5 * s, 2.4 * s, 1.6 * s), STEEL, M.Metal)
    K.Emit(leak, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(220, 240, 255)), Rate = 4, Lifetime = NumberRange.new(1, 1.6),
        Speed = NumberRange.new(4, 7), SpreadAngle = Vector2.new(15, 15), EmissionDirection = Enum.NormalId.Back, Size = NumberSequence.new(0.5, 3), Transparency = NumberSequence.new(0.5, 1) })
end
local function Bulkhead(geo, cf, s, lit)
    if K.Prop(geo, "Station", "Bulkhead", cf, s, { { Vector3.new(1.6, 11.5, 2.2), Vector3.new(-3.2, 5.75, 0) }, { Vector3.new(1.6, 11.5, 2.2), Vector3.new(3.2, 5.75, 0) } }) then
        local l = Neon(geo, Vector3.new(0.8 * s, 0.5 * s, 0.8 * s), cf * CFrame.new(0, 12.9 * s, 0), RED, 0) -- (inside the model's red dome)
        l.Name = "Alarm"
        if lit then K.Light(l, RED, 26, 1.2) end
        return
    end
    -- a heavy bulkhead frame with hazard edges and a red warning light on top (the door itself is gone)
    for _, sx in ipairs({ -1, 1 }) do
        Solid(geo, Vector3.new(1.6 * s, 9 * s, 2.2 * s), cf * CFrame.new(sx * 3.4 * s, 4.5 * s, 0), PANEL, M.SmoothPlastic)
        Stripes(geo, cf * CFrame.new(sx * 3.4 * s, 4.5 * s, -1.12 * s) * CFrame.Angles(0, 0, math.rad(90)), 8.6 * s, 0.5 * s, s)
    end
    Deco(geo, Vector3.new(8.4 * s, 1.6 * s, 2.2 * s), cf * CFrame.new(0, 9.8 * s, 0), PANEL2, M.SmoothPlastic)
    local l = Neon(geo, Vector3.new(1.4 * s, 0.6 * s, 0.8 * s), cf * CFrame.new(0, 10.9 * s, 0), RED, 0)
    l.Name = "Alarm"
    if lit then K.Light(l, RED, 26, 1.2) end
end
local function Reactor(geo, cf, s)
    if K.Prop(geo, "Station", "Reactor", cf, s, { { Vector3.new(3.6, 11, 3.6), Vector3.new(0, 5.5, 0) } }) then return end
    -- a reactor column: a white casing with a glowing core window and cooling rings
    K.Pillar(geo, 3.2 * s, 11 * s, cf, PANEL, M.SmoothPlastic, true)
    Neon(geo, Vector3.new(1.8 * s, 3.4 * s, 3.4 * s), K.Up(cf * CFrame.new(0, 5.5 * s, 0)), CORE, 0.2, Enum.PartType.Cylinder)
    for _, y in ipairs({ 1, 3.2, 7.8, 10 }) do Deco(geo, Vector3.new(0.5 * s, 3.8 * s, 3.8 * s), K.Up(cf * CFrame.new(0, y * s, 0)), DARK, M.Metal, Enum.PartType.Cylinder) end
    Deco(geo, Vector3.new(1 * s, 2.4 * s, 2.4 * s), K.Up(cf * CFrame.new(0, 11.4 * s, 0)), STEEL, M.Metal, Enum.PartType.Cylinder)
end
local function Truss(parent, a, b, w, col)
    -- a square lattice girder between two points
    local dir = (b - a)
    local len = dir.Magnitude
    local cf = CFrame.lookAt(a, b)
    for _, o in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
        P(parent, { Size = Vector3.new(w * 0.12, w * 0.12, len), CFrame = cf * CFrame.new(o[1] * w / 2, o[2] * w / 2, -len / 2), Color = col, Material = M.Metal })
    end
    for k = 0, math.floor(len / w) do
        P(parent, { Size = Vector3.new(w, w * 0.08, w * 0.08), CFrame = cf * CFrame.new(0, 0, -k * w) * CFrame.Angles(0, 0, math.rad(45)), Color = col, Material = M.Metal })
    end
end

W.Props = {
    Cover = { function(geo, _, rng, pos) Container(geo, CFrame.new(pos) * K.Yaw(rng), 0.9, (rng:NextNumber() < 0.5) and ORANGE or BLUE) end,
        function(geo, _, rng, pos) Console(geo, CFrame.new(pos) * K.Yaw(rng), 1) end, function(geo, _, rng, pos) Pipes(geo, CFrame.new(pos) * K.Yaw(rng), 0.9) end },
    Tall = { function(geo, _, rng, pos) Reactor(geo, CFrame.new(pos), 0.9) end, function(geo, _, rng, pos) Bulkhead(geo, CFrame.new(pos) * K.Yaw(rng), 0.9, false) end },
    Air = {},
}
W.Landmarks = {
    function(geo, _, rng, c) -- THE CORE ROOM: four reactor columns round the plaza, consoles facing in
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            Reactor(geo, CFrame.new(c + Vector3.new(math.cos(a) * 31, 0, math.sin(a) * 31)), 1)
            Console(geo, CFrame.lookAt(c + Vector3.new(math.cos(a + 0.7) * 32, 0, math.sin(a + 0.7) * 32), c), 0.9)
        end
    end,
    function(geo, _, rng, c) -- THE CARGO HOLD: containers and bulkheads round the plaza
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            local p = c + Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32)
            Bulkhead(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1, i == 0)
            Container(geo, CFrame.lookAt(c + Vector3.new(math.cos(a + 0.75) * 33, 0, math.sin(a + 0.75) * 33), c) * CFrame.Angles(0, math.rad(90), 0), 0.9, (i % 2 == 0) and ORANGE or BLUE)
        end
    end,
}
W.Kits = {
    StContainer = function(g, cf, s) Container(g, cf, s * 0.55, ORANGE) end,
    StContainerB = function(g, cf, s) Container(g, cf, s * 0.55, BLUE) end,
    StConsole = function(g, cf, s) Console(g, cf, s * 0.6) end,
    StPipes = function(g, cf, s) Pipes(g, cf, s * 0.55) end,
    StBulkhead = function(g, cf, s) Bulkhead(g, cf, s * 0.55, false) end,
    StReactor = function(g, cf, s) Reactor(g, cf, s * 0.55) end,
}
W.Templates = {
    { Name = "Hull Breach", Rim = "Edge", RimMat = { M.DiamondPlate, M.Metal }, Ground = M.DiamondPlate, Patch = { M.Metal, M.Concrete }, Parts = true,
        Edge = { "StContainer", "StPipes", "StConsole" }, RimKit = { "StBulkhead", "StContainerB", "StReactor" }, Hero = "StArrays", Glow = { StBulkhead = RED } },
    { Name = "Cargo Bay", Rim = "Ruins", RimMat = { M.DiamondPlate, M.Metal }, Ground = M.DiamondPlate, Patch = { M.Metal, M.Concrete }, Parts = true,
        Edge = { "StContainer", "StContainerB", "StPipes" }, RimKit = { "StContainer", "StContainerB", "StBulkhead" }, Hero = "StArrays" },
    { Name = "Reactor Deck", Rim = "Ruins", RimMat = { M.Metal, M.DiamondPlate }, Ground = M.Metal, Patch = { M.DiamondPlate, M.Concrete }, Parts = true,
        Edge = { "StReactor", "StConsole", "StPipes" }, RimKit = { "StReactor", "StBulkhead", "StPipes" }, Hero = "StArrays", Glow = { StReactor = CORE } },
}
W.Heroes = {}
function W.Heroes.StArrays(fx, ctx)
    -- the rest of the station: trusses reaching away into space, solar arrays, a ring module, blinking nav lights
    local c = Vector3.new(0, 40, ctx.zC)
    local half = ctx.half
    for k, d in ipairs({ Vector3.new(1, 0.15, 0.4), Vector3.new(-1, 0.1, 0.5), Vector3.new(0.3, 0.2, 1) }) do
        local a = c + d.Unit * half * 1.3
        local b = c + d.Unit * half * 4.2
        Truss(fx, a, b, 6, STEEL)
        for j = 1, 3 do
            local p = a:Lerp(b, j / 3.5)
            local side = d.Unit:Cross(Vector3.yAxis).Unit
            for _, sd in ipairs({ -1, 1 }) do
                local pcf = CFrame.lookAt(p + side * sd * 18, p + side * sd * 40) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0.5, 0, 0)
                local pan = P(fx, { Size = Vector3.new(26, 0.4, 46), CFrame = pcf, Color = C3(30, 50, 110), Material = M.Glass, Reflectance = 0.1 })
                if K.TEX.Solar then
                    -- (UPDATE 4: real solar cells (WorldKit.TEX.Solar, square cells) on both faces + a steel frame round
                    -- the panel; the generator can't make a long flat wing, so the arrays stay parts with a real surface)
                    pan.Material = M.SmoothPlastic; pan.Reflectance = 0.04
                    for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Bottom }) do
                        local t = Instance.new("Texture"); t.Texture = K.TEX.Solar; t.Face = face; t.StudsPerTileU = 13; t.StudsPerTileV = 19.5; t.Parent = pan
                    end
                    P(fx, { Size = Vector3.new(27, 0.3, 47), CFrame = pcf, Color = STEEL, Material = M.Metal })
                end
            end
        end
        P(fx, { Shape = Enum.PartType.Ball, Size = Vector3.one * 3, CFrame = CFrame.new(b), Color = (k == 1) and RED or C3(80, 255, 120), Material = M.Neon })
    end
    -- a ring module far off to one side
    local rc = c + Vector3.new(-half * 3, 60, half * 3.5)
    for k = 0, 23 do
        local a = k / 24 * math.pi * 2
        P(fx, { Size = Vector3.new(12, 10, 26), CFrame = CFrame.new(rc) * CFrame.Angles(math.rad(70), 0, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 90), Color = (k % 4 == 0) and PANEL2 or PANEL, Material = M.SmoothPlastic })
    end
end
W.Vista = { Ground = C3(20, 22, 26), GroundMat = M.Metal, Peak = C3(40, 42, 48), PeakMat = M.Metal, Tip = RED }
function W.VistaFn(fx, Pf, centre, gy, zC, r)
    -- no land: the station deck runs out to blocky hull modules, antennas and drifting debris (the planet is in the sky --
    -- the endless ground plane every map gets would hide it)
    -- (UPDATE 4 VISTA: real models to the horizon -- WorldKit.Far props + tinted scanned mountains; the part version
    -- below stays as the fallback for an unsaved place)
    if K.HasProp("Station", "Hull") then
        for _ = 1, 14 do -- hull modules of the rest of the station
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(240, 700)
            local p = centre + Vector3.new(math.cos(a) * d, r:NextNumber(-60, 30), math.sin(a) * d)
            K.Far(fx, "Station", "Hull", CFrame.new(p) * CFrame.Angles(0, r:NextNumber(0, 6.28), 0), r:NextNumber(1.2, 2.6))
            if r:NextNumber() < 0.4 then
                Pf({ Name = "NavLight", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = CFrame.new(p + Vector3.new(0, 40, 0)), Color = RED, Material = M.Neon })
            end
        end
        for _ = 1, 14 do -- drifting debris
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(150, 600)
            local sz = r:NextNumber(2, 9)
            Pf({ Name = "Debris", Size = Vector3.new(sz, sz * 0.3, sz * 0.7), CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * d, r:NextNumber(20, 160), math.sin(a) * d)) * CFrame.Angles(r:NextNumber(0, 6), r:NextNumber(0, 6), 0),
                Color = STEEL, Material = M.Metal })
        end
        return true
    end
    local g = fx:FindFirstChild("VistaGround")
    if g then g:Destroy() end
    for _ = 1, 26 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(240, 700)
        local w, h = r:NextNumber(30, 80), r:NextNumber(12, 50)
        local p = centre + Vector3.new(math.cos(a) * d, r:NextNumber(-60, 30), math.sin(a) * d)
        Pf({ Name = "Module", Size = Vector3.new(w, h, w * r:NextNumber(0.6, 1.4)), CFrame = CFrame.new(p) * CFrame.Angles(0, r:NextNumber(0, 6), 0), Color = (r:NextNumber() < 0.5) and PANEL or PANEL2, Material = M.SmoothPlastic })
        if r:NextNumber() < 0.4 then Pf({ Name = "NavLight", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = CFrame.new(p + Vector3.new(0, h / 2 + 2, 0)), Color = RED, Material = M.Neon }) end
    end
    for _ = 1, 16 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(150, 600)
        local sz = r:NextNumber(2, 9)
        Pf({ Name = "Debris", Size = Vector3.new(sz, sz * 0.3, sz * 0.7), CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * d, r:NextNumber(20, 160), math.sin(a) * d)) * CFrame.Angles(r:NextNumber(0, 6), r:NextNumber(0, 6), 0),
            Color = STEEL, Material = M.Metal })
    end
    return true
end
function W.Scenery(fx, theme, rng, zC, arena, height)
    -- sparks raining from broken lines, alarm lights pulsing, a slow-tumbling panel overhead (client)
    for k = 1, 3 do
        local src = K.Box(fx, Vector3.new(2, 1, 2), CFrame.new(rng:NextNumber(-arena * 0.4, arena * 0.4), 34, zC + rng:NextNumber(-arena * 0.4, arena * 0.4)))
        K.Emit(src, { Color = ColorSequence.new(C3(255, 220, 140), C3(255, 120, 40)), LightEmission = 1, Rate = 6, Lifetime = NumberRange.new(1, 1.6),
            Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(30, 30), EmissionDirection = Enum.NormalId.Bottom, Size = NumberSequence.new(0.15, 0.05),
            Acceleration = Vector3.new(0, -30, 0), Transparency = NumberSequence.new(0, 1) })
    end
    -- (UPDATE 4 LIFE: a torn-off chunk of the station's hull (the vista Hull model, small) tumbling overhead)
    local panel = K.Life(fx, "Station", "Hull", 0.5) or Deco(fx, Vector3.new(12, 0.6, 18), CFrame.new(), PANEL, M.SmoothPlastic)
    local dungeon = fx.Parent
    local alarms = nil
    K.Live(fx, function(t)
        panel:PivotTo(CFrame.new(arena * 0.3, 60 + math.sin(t * 0.2) * 4, zC - arena * 0.1) * CFrame.Angles(t * 0.05, t * 0.08, t * 0.03))
        if t > 2 then
            if not alarms then
                alarms = {}
                for _, d in ipairs(dungeon and dungeon:GetDescendants() or {}) do
                    if (d.Name == "Alarm" or d.Name == "Flicker") and d:IsA("BasePart") then table.insert(alarms, d) end
                end
            end
            local tr = 0.5 - math.cos(t * 3) * 0.5
            for _, a in ipairs(alarms) do a.Transparency = (a.Name == "Flicker") and ((math.sin(t * 23) > 0.6) and 0.8 or 0.15) or tr * 0.8 end
        end
    end)
end
function W.SetPiece(geo, deco, c, rng, F)
    -- THE CORE CHAMBER: reactor columns and bulkheads round the fight floor, the station's main reactor over the far side
    K.Ring(12, 100, c + Vector3.new(0, F, 0), function(p, a, i)
        if i % 2 == 0 then Reactor(geo, CFrame.new(p), 1.5) else Bulkhead(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1.4, i == 3) end
    end)
    local core = c + Vector3.new(0, F + 40, 150)
    -- (UPDATE 4: the real reactor column, 80 tall; its light stays at the old core)
    if K.Far(deco, "Station", "Reactor", CFrame.new(c + Vector3.new(0, F, 150)), 7) then
        K.Light(K.Box(deco, Vector3.new(1, 1, 1), CFrame.new(core + Vector3.new(0, 0, -16))), CORE, 70, 1.2)
        return RED
    end
    Deco(deco, Vector3.new(80, 30, 30), K.Up(CFrame.new(core)), PANEL, M.SmoothPlastic, Enum.PartType.Cylinder)
    local glow = Neon(deco, Vector3.new(24, 31, 31), K.Up(CFrame.new(core)), CORE, 0.15, Enum.PartType.Cylinder)
    K.Light(glow, CORE, 70, 1.2)
    return RED
end

W.Theme = {
    Name = "Derelict Station",
    Floor = { Color = C3(78, 82, 88), Material = M.DiamondPlate },
    FloorAlt = { Color = C3(60, 62, 68), Material = M.Metal },
    Wall = { Color = PANEL2, Material = M.SmoothPlastic },
    WallTrim = { Color = DARK, Material = M.Metal },
    Ceiling = { Color = C3(40, 42, 48), Material = M.Metal },
    Prop = { Color = PANEL, Material = M.SmoothPlastic },
    PropAlt = { Color = ORANGE, Material = M.Metal },
    Hazard = { Color = C3(120, 220, 255), Material = M.Glass, Transparency = 0.35 },
    Accent = RED, Light = C3(220, 230, 255), LampBrightness = 1.3, LampRange = 52,
    OpenSky = true,
}
W.Ambience = { Mote = C3(220, 230, 255), Mote2 = AMBER, MoteRise = false, Glow = RED }
W.Light = { ClockTime = 13, Brightness = 0.6, -- (0.89: at ClockTime 0 Roblox dims the skybox to black -- the painted space never showed; day clock + a dim sun)
    -- (UPDATE 4 LIGHTING AUDIT: gun slide L33 -> L62, space still black)
    Ambient = C3(154, 162, 188), OutdoorAmbient = C3(156, 164, 195),
    FogColor = C3(20, 22, 34), FogStart = 260, FogEnd = 1300, Exposure = 0.87, EnvDiffuse = 0.35,
    BloomIntensity = 0.45, BloomThreshold = 1.15, BloomSize = 22,
    CCBrightness = 0, CCContrast = 0.16, CCSaturation = -0.1, CCTint = C3(232, 238, 255) }
W.Atmo = { 0.12, C3(60, 80, 140), C3(10, 12, 30), 0.2, 0 }
W.Terrain = { [M.Concrete] = C3(110, 112, 116), [M.Pavement] = C3(90, 92, 98) } -- (terrain materials only; the station maps are part-built)
W.Contrast = C3(255, 200, 40)
W.EA = { Warn = C3(255, 60, 40), Core = C3(255, 220, 200), Mat = M.Neon }
W.Moods = {
    { Id = "Breach", W = 3 },
    { Id = "RedAlert", Name = "Red Alert", W = 2, Acc = 0.0, Fog = C3(120, 20, 20), FogAmt = 0.32, CCSat = 0.04 },
    { Id = "Coolant", Name = "Coolant Blue", W = 2, Acc = 0.56, Fog = C3(40, 90, 150), FogAmt = 0.32 },
    { Id = "Powerdown", Name = "Power Down", W = 1, Val = 0.82, Fog = C3(10, 10, 16), FogAmt = 0.36, Exp = -0.1 },
}
W.Sky = { Bk = "95934355053803", Dn = "108311033687896", Ft = "125410324804897", Lf = "122833595749701", Rt = "139222623988570", Up = "125494128530987" } -- (UPDATE 4 SKIES v4: tools/hdri_sky.py)
return W
