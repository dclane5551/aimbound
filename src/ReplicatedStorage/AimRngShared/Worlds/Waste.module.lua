--!nocheck
-- TOXIC WASTES (0.87 world): a poisoned scrapland -- stacks of leaking hazard barrels, rusted scrap heaps, concrete
-- bunkers, chain-link fences, radio masts blinking red; cooling towers venting smog on the horizon, toxic green glow,
-- drifting dust. Sister: Molten.
local K = require(script.Parent.Parent:WaitForChild("WorldKit"))
local C3, M = K.C3, K.M
local P, Solid, Deco, Neon, Wedge = K.P, K.Solid, K.Deco, K.Neon, K.Wedge

local DIRT, CONC, CONC2, RUST, RUST2 = C3(108, 98, 76), C3(126, 122, 110), C3(100, 98, 90), C3(124, 70, 42), C3(92, 58, 40)
local YELLOW, BLACK, TOXIC, STEEL, RED = C3(220, 180, 40), C3(30, 30, 30), C3(140, 255, 60), C3(90, 94, 100), C3(255, 50, 40)

local W = {}
W.Id = "Waste"
W.Title = "TOXIC WASTES"
W.TitleColor = C3(160, 240, 70)
W.Sister = "Fire"
W.HazardName = "Toxic Sludge"

local function Barrel(geo, cf, col, s, tipped)
    local c = tipped and (cf * CFrame.new(0, 0.9 * s, 0)) or (K.Up(cf * CFrame.new(0, 1.3 * s, 0)))
    local b = Solid(geo, Vector3.new(2.6 * s, 1.8 * s, 1.8 * s), c, col, M.Metal, Enum.PartType.Cylinder)
    Deco(geo, Vector3.new(0.4 * s, 1.85 * s, 1.85 * s), c, BLACK, M.Metal, Enum.PartType.Cylinder)
    return b
end
-- (UPDATE 4 prop pass: real textured models from ReplicatedStorage.WorldProps.Waste via WorldKit.Prop when the place has
-- them; the part build under each is the fallback. Gameplay boxes = the old solid parts, so cover plays the same.)
local function Barrels(geo, cf, s)
    if K.Prop(geo, "Waste", "Barrels", cf, s * 0.85, { -- (x0.85: cover stays under eye height)
        { Vector3.new(6.4, 2.6, 5), Vector3.new(0, 1.3, 0) } }) then return end
    -- a pallet of hazard barrels, one tipped over and leaking a glowing puddle
    Solid(geo, Vector3.new(5 * s, 0.4 * s, 5 * s), cf * CFrame.new(0, 0.2 * s, 0), C3(120, 92, 60), M.WoodPlanks)
    for k, o in ipairs({ { -1.2, -1.2 }, { 1.2, -1.2 }, { -1.2, 1.2 } }) do
        Barrel(geo, cf * CFrame.new(o[1] * s, 0.4 * s, o[2] * s), (k == 2) and C3(60, 110, 160) or YELLOW, s)
    end
    Barrel(geo, cf * CFrame.new(3.6 * s, 0, 1.5 * s) * CFrame.Angles(0, 0.6, 0), YELLOW, s, true)
    Neon(geo, Vector3.new(0.1, 4.2 * s, 4.2 * s), K.Up(cf * CFrame.new(5.2 * s, 0.06, 2.4 * s)), TOXIC, 0.25, Enum.PartType.Cylinder)
end
local function Scrap(geo, cf, s)
    if K.Prop(geo, "Waste", "Scrap", cf, s * 0.85, { { Vector3.new(6, 3, 4), Vector3.new(0, 1.5, 0) } }) then return end
    -- a heap of rusted plates and girders leaning on each other
    Solid(geo, Vector3.new(6 * s, 2.4 * s, 4 * s), cf * CFrame.new(0, 1.1 * s, 0) * CFrame.Angles(0.1, 0, -0.12), RUST, M.CorrodedMetal)
    Solid(geo, Vector3.new(4.4 * s, 0.4 * s, 3.4 * s), cf * CFrame.new(-1 * s, 2.9 * s, 0.3 * s) * CFrame.Angles(0.3, 0.4, 0.35), RUST2, M.CorrodedMetal)
    Deco(geo, Vector3.new(0.6 * s, 0.6 * s, 7 * s), cf * CFrame.new(1.4 * s, 2.6 * s, 0) * CFrame.Angles(0.5, 0.3, 0.2), STEEL, M.Metal)
    Deco(geo, Vector3.new(3 * s, 1.6 * s, 0.3 * s), cf * CFrame.new(2.6 * s, 1.4 * s, -1.6 * s) * CFrame.Angles(0.2, -0.5, 0.4), RUST, M.CorrodedMetal)
    Deco(geo, Vector3.new(2 * s, 1.2 * s, 1.2 * s), cf * CFrame.new(-2.8 * s, 0.6 * s, 1.8 * s) * CFrame.Angles(0, 0.8, math.rad(90)), C3(40, 40, 40), M.Rubber, Enum.PartType.Cylinder)
end
local function Bunker(geo, cf, s)
    if K.Prop(geo, "Waste", "Bunker", cf, s, { { Vector3.new(8, 3.4, 5), Vector3.new(0, 1.7, 0) }, { Vector3.new(8, 2, 1.6), Vector3.new(0, 1, -3.3) } }) then return end
    -- a squat concrete bunker: sloped front, a dark firing slit, hazard stripes, a rusted door
    Solid(geo, Vector3.new(8 * s, 3.4 * s, 5 * s), cf * CFrame.new(0, 1.7 * s, 0), CONC, M.Concrete)
    Wedge(geo, Vector3.new(8 * s, 2 * s, 1.6 * s), cf * CFrame.new(0, 1 * s, -3.3 * s), CONC2, M.Concrete, true)
    Deco(geo, Vector3.new(5 * s, 0.4 * s, 0.2 * s), cf * CFrame.new(0, 2.6 * s, -2.52 * s), C3(16, 16, 16), M.SmoothPlastic)
    for k = -3, 3 do Deco(geo, Vector3.new(0.6 * s, 0.4 * s, 5.06 * s), cf * CFrame.new(k * 1.15 * s, 3.25 * s, 0) * CFrame.Angles(0, 0, 0.6), (k % 2 == 0) and YELLOW or BLACK, M.SmoothPlastic) end
    Deco(geo, Vector3.new(1.8 * s, 2.6 * s, 0.2 * s), cf * CFrame.new(2.6 * s, 1.3 * s, 2.52 * s), RUST, M.CorrodedMetal)
end
local function Fence(geo, cf, s)
    if K.Prop(geo, "Waste", "Fence", cf, s, { { Vector3.new(0.3, 6, 0.3), Vector3.new(-4, 3, 0) }, { Vector3.new(0.3, 6, 0.3), Vector3.new(0, 3, 0) }, { Vector3.new(0.3, 6, 0.3), Vector3.new(4, 3, 0) } }) then return end
    -- chain-link: steel posts, a see-through mesh (shots pass), a rusted sign
    for k = -1, 1 do Solid(geo, Vector3.new(0.3 * s, 6 * s, 0.3 * s), cf * CFrame.new(k * 4 * s, 3 * s, 0), STEEL, M.Metal) end
    Deco(geo, Vector3.new(8 * s, 5.4 * s, 0.05), cf * CFrame.new(0, 3.1 * s, 0), C3(150, 156, 160), M.DiamondPlate, nil, 0.65)
    Deco(geo, Vector3.new(8 * s, 0.15 * s, 0.15 * s), cf * CFrame.new(0, 5.9 * s, 0), STEEL, M.Metal)
    Deco(geo, Vector3.new(2.2 * s, 1.4 * s, 0.1 * s), cf * CFrame.new(-1.8 * s, 3.6 * s, -0.1 * s), YELLOW, M.SmoothPlastic)
    Deco(geo, Vector3.new(0.9 * s, 0.9 * s, 0.05), cf * CFrame.new(-1.8 * s, 3.6 * s, -0.17 * s) * CFrame.Angles(0, 0, math.rad(45)), BLACK, M.SmoothPlastic)
end
local function Mast(geo, cf, s, lit)
    if K.Prop(geo, "Waste", "Mast", cf, s, { { Vector3.new(3, 5, 3), Vector3.new(0, 2.5, 0) } }) then
        local b = Neon(geo, Vector3.one * 0.8 * s, cf * CFrame.new(0, 18.4 * s, 0), RED, 0, Enum.PartType.Ball)
        b.Name = "Beacon"
        if lit then K.Light(b, RED, 20, 0.8) end
        return
    end
    -- a radio mast: a lattice tower with guy-wire stubs and a blinking red beacon
    local h = 18 * s
    for _, sx in ipairs({ -1, 1 }) do
        for _, sz in ipairs({ -1, 1 }) do
            K.Beam(geo, (cf * CFrame.new(sx * 1.4 * s, 0, sz * 1.4 * s)).Position, (cf * CFrame.new(sx * 0.4 * s, h, sz * 0.4 * s)).Position, 0.3 * s, STEEL, M.Metal)
        end
    end
    for k = 1, 5 do
        local y = k * h / 6
        local w = 2.8 * s * (1 - y / h * 0.7)
        Deco(geo, Vector3.new(w, 0.2 * s, 0.2 * s), cf * CFrame.new(0, y, 0), STEEL, M.Metal)
        Deco(geo, Vector3.new(0.2 * s, 0.2 * s, w), cf * CFrame.new(0, y, 0), STEEL, M.Metal)
    end
    local b = Neon(geo, Vector3.one * 0.8 * s, cf * CFrame.new(0, h + 0.4 * s, 0), RED, 0, Enum.PartType.Ball)
    b.Name = "Beacon"
    local hb = Solid(geo, Vector3.new(3 * s, 5 * s, 3 * s), cf * CFrame.new(0, 2.5 * s, 0), C3(0, 0, 0), M.SmoothPlastic)
    hb.Transparency = 1; hb.Name = "Hitbox"
    if lit then K.Light(b, RED, 20, 0.8) end
end
local function CoolingTower(parent, base, s)
    -- (UPDATE 4: one real model replaces the stacked parts when the place has it -- WorldProps.Waste.CoolingTower, stored at s = 1)
    if K.Prop(parent, "Waste", "CoolingTower", CFrame.new(base), s) then return end
    -- a hyperboloid cooling tower from stacked rings
    for k = 0, 9 do
        local t = k / 9
        local r = (1 - 0.45 * math.sin(t * math.pi * 0.85)) * 30 * s
        P(parent, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(9 * s, r * 2, r * 2), CFrame = K.Up(CFrame.new(base + Vector3.new(0, (k + 0.5) * 9 * s, 0))), Color = (k % 3 == 0) and CONC2 or CONC, Material = M.Concrete })
    end
end

W.Props = {
    Cover = { function(geo, _, rng, pos) Barrels(geo, CFrame.new(pos) * K.Yaw(rng), 1) end, function(geo, _, rng, pos) Scrap(geo, CFrame.new(pos) * K.Yaw(rng), 1) end,
        function(geo, _, rng, pos) Bunker(geo, CFrame.new(pos) * K.Yaw(rng), 0.8) end },
    Tall = { function(geo, _, rng, pos) Mast(geo, CFrame.new(pos), 0.9, false) end, function(geo, _, rng, pos) Fence(geo, CFrame.new(pos) * K.Yaw(rng), 1) end },
    Air = {},
}
W.Landmarks = {
    function(geo, _, rng, c) -- THE DUMP: barrel pallets and scrap heaps round the plaza, a mast on one side
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            local p = c + Vector3.new(math.cos(a) * 31, 0, math.sin(a) * 31)
            if i % 2 == 0 then Barrels(geo, CFrame.lookAt(p, c), 1) else Scrap(geo, CFrame.lookAt(p, c), 1) end
        end
        Mast(geo, CFrame.new(c + Vector3.new(34, 0, 0)), 1, true)
    end,
    function(geo, _, rng, c) -- CHECKPOINT: fences on the diagonals, bunkers facing the plaza
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            Fence(geo, CFrame.lookAt(c + Vector3.new(math.cos(a) * 33, 0, math.sin(a) * 33), c), 1)
        end
        Bunker(geo, CFrame.lookAt(c + Vector3.new(-32, 0, 0), c), 0.8)
        Bunker(geo, CFrame.lookAt(c + Vector3.new(32, 0, 0), c), 0.8)
    end,
}
W.Kits = {
    WsBarrels = function(g, cf, s) Barrels(g, cf, s * 0.55) end,
    WsScrap = function(g, cf, s) Scrap(g, cf, s * 0.6) end,
    WsBunker = function(g, cf, s) Bunker(g, cf, s * 0.5) end,
    WsFence = function(g, cf, s) Fence(g, cf, s * 0.6) end,
    WsMast = function(g, cf, s) Mast(g, cf, s * 0.5, false) end,
}
W.Templates = {
    { Name = "Scrapyard", Rim = "Ruins", RimMat = { M.Ground, M.Mud }, Ground = M.Ground, Patch = { M.Mud, M.Asphalt },
        Edge = { "WsBarrels", "WsScrap", "WsFence" }, RimKit = { "WsScrap", "WsMast", "WsBarrels" }, Hero = "WsTowers" },
    { Name = "Sludge Pits", Rim = "Cliffs", RimMat = { M.Rock, M.Mud }, RimAccent = M.Ground, PartyRim = "WsScrap", Ground = M.Mud, Patch = { M.Ground, M.Slate },
        Edge = { "WsBarrels", "WsScrap" }, RimKit = { "WsScrap", "WsScrap", "WsMast" }, Hero = "WsTowers" },
    { Name = "Quarantine Zone", Rim = "Ruins", RimMat = { M.Concrete, M.Asphalt }, Ground = M.Asphalt, Patch = { M.Concrete, M.Ground },
        Edge = { "WsBunker", "WsFence", "WsBarrels" }, RimKit = { "WsFence", "WsMast", "WsBunker" }, Hero = "WsTowers" },
}
W.Heroes = {}
function W.Heroes.WsTowers(fx, ctx)
    -- three cooling towers on the far side venting green-grey smog
    local c = Vector3.new(0, 0, ctx.zC + ctx.half * 3.6)
    for k, o in ipairs({ Vector3.new(-90, 0, 0), Vector3.new(0, 0, 40), Vector3.new(100, 0, -10) }) do
        CoolingTower(fx, c + o, (k == 2) and 1.4 or 1.1)
        local top = P(fx, { Size = Vector3.new(30, 2, 30), CFrame = CFrame.new(c + o + Vector3.new(0, (k == 2) and 128 or 100, 0)), Transparency = 1 })
        K.Emit(top, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(150, 170, 110), C3(90, 96, 70)), Rate = 2.5,
            Lifetime = NumberRange.new(12, 16), Speed = NumberRange.new(6, 10), Size = NumberSequence.new(30, 70), Transparency = NumberSequence.new(0.5, 1),
            EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(12, 12), Acceleration = Vector3.new(3, 0, 0), LightEmission = 0 })
    end
end
W.Vista = { Ground = C3(84, 78, 60), GroundMat = M.Ground, Peak = C3(70, 66, 54), PeakMat = M.Rock, Tip = C3(120, 160, 60) }
function W.VistaFn(fx, Pf, centre, gy, zC, r)
    -- ruined blocks and smokestacks to the horizon, junk heaps, a few toxic pools glowing
    -- (UPDATE 4 VISTA: real models to the horizon -- WorldKit.Far props + tinted scanned mountains; the part version
    -- below stays as the fallback for an unsaved place)
    if K.HasProp("Waste", "Ruin") then
        for _ = 1, 14 do -- gutted concrete blocks to the horizon
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(300, 1050)
            K.Far(fx, "Waste", "Ruin", CFrame.new(centre + Vector3.new(math.cos(a) * d, -2, math.sin(a) * d)) * CFrame.Angles(0, r:NextNumber(0, 6.28), 0), 1.4 + d / 500)
        end
        for _ = 1, 2 do
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(750, 1050)
            K.Far(fx, "Waste", "CoolingTower", CFrame.new(centre + Vector3.new(math.cos(a) * d, -2, math.sin(a) * d)), r:NextNumber(0.9, 1.2))
        end
        for _ = 1, 4 do
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(300, 800)
            K.Far(fx, "Waste", "Mast", CFrame.new(centre + Vector3.new(math.cos(a) * d, -1, math.sin(a) * d)), r:NextNumber(1.8, 2.6))
        end
        for _ = 1, 6 do -- glowing toxic pools
            local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(220, 700)
            local pr = r:NextNumber(30, 70)
            Pf({ Name = "ToxicPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, pr, pr), CFrame = K.Up(CFrame.new(centre + Vector3.new(math.cos(a) * d, 0.3, math.sin(a) * d))),
                Color = TOXIC, Material = M.Neon, Transparency = 0.3 })
        end
        return true
    end
    for _ = 1, 34 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(300, 1100)
        local w, h = r:NextNumber(40, 90), r:NextNumber(30, 120)
        local p = centre + Vector3.new(math.cos(a) * d, h / 2, math.sin(a) * d)
        Pf({ Name = "Ruin", Size = Vector3.new(w, h, w * 0.8), CFrame = CFrame.new(p) * CFrame.Angles(0, r:NextNumber(0, 6), r:NextNumber(-0.05, 0.05)), Color = C3(70, 68, 60), Material = M.Concrete })
        if r:NextNumber() < 0.3 then
            Pf({ Name = "Stack", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h * 1.6, 8, 8), CFrame = K.Up(CFrame.new(p + Vector3.new(w * 0.3, h * 0.3, 0))), Color = C3(80, 60, 50), Material = M.CorrodedMetal })
        end
    end
    for _ = 1, 10 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = r:NextNumber(220, 700)
        local pr = r:NextNumber(30, 70)
        Pf({ Name = "ToxicPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, pr, pr), CFrame = K.Up(CFrame.new(centre + Vector3.new(math.cos(a) * d, 0.3, math.sin(a) * d))),
            Color = TOXIC, Material = M.Neon, Transparency = 0.3 })
    end
    return true
end
function W.Scenery(fx, theme, rng, zC, arena, height)
    -- toxic dust drifting through the room, a faint green haze rising from the floor, the masts' beacons blink (client)
    local src = K.Box(fx, Vector3.new(arena, 1, arena), CFrame.new(0, 10, zC))
    K.Emit(src, { Color = ColorSequence.new(C3(200, 220, 120), C3(150, 255, 90)), LightEmission = 0.4, Rate = 12, Lifetime = NumberRange.new(5, 8),
        Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.2, 0.1), Transparency = NumberSequence.new(0.3, 1),
        Acceleration = Vector3.new(1.5, 0.1, 0) })
    local haze = K.Box(fx, Vector3.new(arena, 1, arena), CFrame.new(0, 2, zC))
    K.Emit(haze, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(130, 170, 80)), Rate = 3, Lifetime = NumberRange.new(6, 9),
        Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 5), Size = NumberSequence.new(8, 18), Transparency = NumberSequence.new(0.88, 1),
        EmissionDirection = Enum.NormalId.Top })
    -- (the beacons are collected once, after the floor finished building; then a toggle twice a second)
    local dungeon = fx.Parent
    local beacons, lastOn = nil, nil
    K.Live(fx, function(t)
        if t < 2 then return end
        if not beacons then
            beacons = {}
            for _, d in ipairs(dungeon and dungeon:GetDescendants() or {}) do
                if d.Name == "Beacon" and d:IsA("BasePart") then table.insert(beacons, d) end
            end
        end
        local on = (math.floor(t * 2) % 2 == 0)
        if on == lastOn then return end
        lastOn = on
        for _, b in ipairs(beacons) do b.Transparency = on and 0 or 0.85 end
    end)
end
function W.SetPiece(geo, deco, c, rng, F)
    -- THE REACTOR YARD: scrap heaps and barrel pallets round the fight floor, a cooling tower venting behind
    K.Ring(12, 100, c + Vector3.new(0, F, 0), function(p, a, i)
        if i % 2 == 0 then Scrap(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1.6) else Barrels(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1.4) end
    end)
    -- (UPDATE 4: the real tower raised + bigger so it clears the rim hills; seen in play: only its lip showed)
    if K.HasProp("Waste", "CoolingTower") then CoolingTower(deco, c + Vector3.new(0, F + 28, 190), 1.3) else CoolingTower(deco, c + Vector3.new(0, F, 170), 1.0) end
    local glow = Neon(deco, Vector3.new(0.4, 50, 50), K.Up(CFrame.new(c + Vector3.new(0, F + 0.3, 170))), TOXIC, 0.2, Enum.PartType.Cylinder)
    K.Light(glow, TOXIC, 60, 1.0)
    return TOXIC
end

W.Theme = {
    Name = "Toxic Wastes",
    Floor = { Color = DIRT, Material = M.Ground },
    FloorAlt = { Color = C3(60, 60, 58), Material = M.Asphalt },
    Wall = { Color = CONC, Material = M.Concrete },
    WallTrim = { Color = RUST, Material = M.CorrodedMetal },
    Ceiling = { Color = C3(70, 68, 60), Material = M.Concrete },
    Prop = { Color = CONC2, Material = M.Concrete },
    PropAlt = { Color = YELLOW, Material = M.Metal },
    Hazard = { Color = TOXIC, Material = M.Neon, Transparency = 0.3 },
    Accent = TOXIC, Light = C3(220, 255, 170), LampBrightness = 1.3, LampRange = 50,
    OpenSky = true,
}
W.Ambience = { Mote = C3(200, 230, 120), Mote2 = TOXIC, MoteRise = true, Glow = TOXIC }
-- (UPDATE 4 LIGHTING AUDIT: the "Fallout" mood's later clock left the open arena at grey plate L32 -> ambient + exposure up)
W.Light = { ClockTime = 15.5, Brightness = 1.7, Ambient = C3(156, 158, 120), OutdoorAmbient = C3(176, 176, 129),
    FogColor = C3(150, 140, 100), FogStart = 200, FogEnd = 900, Exposure = 0.7, EnvDiffuse = 0.3,
    BloomIntensity = 0.35, BloomThreshold = 1.3, BloomSize = 20,
    CCBrightness = 0, CCContrast = 0.16, CCSaturation = -0.04, CCTint = C3(252, 246, 228) }
W.Atmo = { 0.3, C3(196, 186, 120), C3(90, 80, 54), 1.6, 0.2 } -- (thinner + warmer: all-green haze hid the cooling towers and flattened the rust)
W.Terrain = { [M.Ground] = C3(112, 98, 76), [M.Mud] = C3(88, 78, 56), [M.Asphalt] = C3(56, 56, 54), [M.Concrete] = C3(120, 118, 106),
    [M.Rock] = C3(90, 86, 74), [M.Slate] = C3(76, 76, 70) }
-- (UPDATE 4 wrap-up, RoomGen.DressFor: the room pieces in this world's own language -- cast concrete (no more dirt pillars), a beacon mast on each)
W.Cover = { Built = true, Stone = M.Concrete, Crown = { World = "Waste", Name = "Mast", Fit = 0.8, MaxH = 10, Alt = { "Barrels", "Scrap" } } }
W.Contrast = C3(255, 60, 200)
W.EA = { Warn = C3(255, 80, 30), Core = C3(255, 230, 120), Mat = M.Neon }
W.Moods = {
    { Id = "Smog", W = 3 },
    { Id = "Fallout", Name = "Fallout Dusk", W = 2, Acc = 0.08, Fog = C3(170, 100, 60), FogAmt = 0.36, Clock = 1.0, Exp = -0.04 },
    { Id = "Acid", Name = "Acid Rain", W = 2, Sat = 0.85, Fog = C3(110, 150, 90), FogAmt = 0.42, Dens = 1.3, Exp = -0.04 },
    { Id = "Glow", Name = "Night Glow", W = 1, Val = 0.85, Fog = C3(40, 70, 30), FogAmt = 0.38, Exp = -0.08 },
}
W.Sky = { Bk = "114952155691830", Dn = "99984722302590", Ft = "83450589776735", Lf = "72640794655209", Rt = "100809900799314", Up = "112339363044469" } -- (UPDATE 4 SKIES v4: tools/hdri_sky.py)
return W
