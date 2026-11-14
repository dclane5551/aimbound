--!nocheck
-- NEW BIOMES (0.53, owner: "add more biome variation (new biomes such as dreamscapes, flatlands etc)" -> "make them very
-- visually appealing, fitting our current game aesthetic (like the hub)"): DREAMSCAPE ("Dream") and NEON FLATS ("Flats").
-- Everything a biome needs lives here and DungeonGenerator / EnemyModels / BossAI merge it into their tables (the
-- generator's main chunk is near Luau's local limit, so new biomes don't add locals there):
--   data      titles, palette, theme surfaces, ambience, element + affinity, roster (archetypes, lore, attack kinds,
--             pools, specialists, hard-tier movers), superboss names, vista colours, map templates
--   building  Props (cover / tall / air), Landmarks, Scenery (the sky over the open roof), Kit (procedural map-shell
--             kits: the templates' Edge / RimKit names), Hero (the far landmark), Vista (the horizon), SetPiece (boss arena)
--   combat    Attack (the new enemies' telegraphed attacks), Decor (their models, called by EnemyModels.Decorate)
-- Budget like every biome: decoration never collides or blocks shots, <= ~5 lights, animations only on the client.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local IS_CLIENT = RunService:IsClient()
local C3 = Color3.fromRGB
local M = Enum.Material

local NB = {}
NB.BIOMES = { "Dream", "Flats" }

-- ==================== DATA ====================
NB.TITLES = {
    Dream = { Name = "DREAMSCAPE", Color = C3(255, 150, 230) },
    Flats = { Name = "NEON FLATS", Color = C3(255, 140, 80) },
}
NB.PALETTE = {
    Dream = { FloorColor = BrickColor.new("Lavender"), WallColor = BrickColor.new("Dark indigo"), AccentColor = BrickColor.new("Hot pink"),
        LightColor = C3(255, 200, 245), FloorMaterial = M.Marble, HazardColor = BrickColor.new("Hot pink"), HazardName = "Nightmare Rift" },
    Flats = { FloorColor = BrickColor.new("Brick yellow"), WallColor = BrickColor.new("Dark taupe"), AccentColor = BrickColor.new("Neon orange"),
        LightColor = C3(255, 170, 120), FloorMaterial = M.Sandstone, HazardColor = BrickColor.new("Neon orange"), HazardName = "Live Wire" },
}
NB.THEMES = {
    Dream = {
        Name = "The Dreamscape",
        Floor = { Color = C3(150, 134, 186), Material = M.Marble },
        FloorAlt = { Color = C3(196, 170, 214), Material = M.SmoothPlastic },
        Wall = { Color = C3(104, 88, 150), Material = M.Marble },
        WallTrim = { Color = C3(255, 170, 230), Material = M.Glass, Transparency = 0.1 },
        Ceiling = { Color = C3(60, 48, 100), Material = M.Marble },
        Prop = { Color = C3(236, 228, 248), Material = M.Marble },
        PropAlt = { Color = C3(130, 225, 240), Material = M.Glass, Transparency = 0.2 },
        Hazard = { Color = C3(255, 140, 220), Material = M.Glass, Transparency = 0.3 },
        Accent = C3(255, 150, 230), Light = C3(255, 220, 250), LampBrightness = 1.4, LampRange = 52,
        OpenSky = true,
    },
    Flats = {
        Name = "Neon Flats",
        -- (0.58: a dusk-pink salt crust, asphalt, red-rock mesa walls -- the old tan / taupe read as random)
        Floor = { Color = C3(176, 142, 150), Material = M.Salt },
        FloorAlt = { Color = C3(40, 38, 46), Material = M.Asphalt },
        Wall = { Color = C3(128, 62, 58), Material = M.Sandstone },
        WallTrim = { Color = C3(255, 120, 60), Material = M.Metal },
        Ceiling = { Color = C3(60, 40, 60), Material = M.Concrete },
        Prop = { Color = C3(190, 186, 180), Material = M.Concrete },
        PropAlt = { Color = C3(120, 60, 54), Material = M.CorrodedMetal },
        Hazard = { Color = C3(255, 110, 60), Material = M.Neon, Transparency = 0.2 },
        Accent = C3(255, 110, 180), Light = C3(255, 196, 150), LampBrightness = 1.5, LampRange = 54,
        OpenSky = true,
    },
}
NB.AMBIENCE = {
    Dream = { Mote = C3(255, 200, 245), Mote2 = C3(160, 240, 255), MoteRise = true, Glow = C3(255, 160, 230) },
    Flats = { Mote = C3(255, 210, 160), Mote2 = C3(255, 120, 180), MoteRise = false, Glow = C3(255, 140, 90) },
}
-- element: Dream enemies chill (Dreaming), Flats enemies burn (Sunburnt); their weaknesses -- ItemData.ENEMY_AFFINITY
NB.ELEMENT = { Dream = "Lucid", Flats = "Scorch" }
NB.ELEMENT_DEFS = {
    Lucid = { Element = "Cold", Ailment = "Chill", Word = "Dreaming", Color = C3(230, 160, 255) },
    Scorch = { Element = "Fire", Ailment = "Burn", Word = "Sunburnt", Color = C3(255, 150, 70) },
}
NB.AFFINITY = {
    Lucid = { Weak = "Bleed", Resist = "Cold", Name = "Dream" },   -- a cut wakes you up; dreams are cold
    Scorch = { Weak = "Cold", Resist = "Bleed", Name = "Flats" },  -- cold snaps the heat; sun-baked hides don't bleed
}
NB.SUPER_NAMES = { Dream = "THE SANDMAN", Flats = "HIGHWAY KING" }
NB.SUPER_COLOR = { Dream = C3(255, 150, 230), Flats = C3(255, 120, 60) }

-- the roster: five biome types + a specialist each (movement patterns reused from the existing roster, each type with
-- its own look + attack)
NB.ARCHETYPES = {
    -- DREAMSCAPE
    Drowse = { Style = "Drowse", Label = "Drowse", Hp = 85, Dmg = 8, Speed = 14, Body = 2.0, Head = 1.2, Color = C3(200, 180, 255), Range = { 24, 38 }, Fire = 2.8, Pattern = "Leaf", Biome = "Dream" },
    Paperbird = { Style = "Paperbird", Label = "Paperbird", Hp = 70, Dmg = 8, Speed = 20, Body = 1.7, Head = 1.0, Color = C3(255, 240, 250), Range = { 22, 36 }, Fire = 2.4, Pattern = "Flap", Biome = "Dream" },
    Mirage = { Style = "Mirage", Label = "Mirage", Hp = 80, Dmg = 9, Speed = 16, Body = 1.9, Head = 1.15, Color = C3(150, 240, 255), Range = { 22, 34 }, Fire = 2.8, Pattern = "Phase", Biome = "Dream" },
    Sleepwalker = { Style = "Sleepwalker", Label = "Sleepwalker", Hp = 130, Dmg = 11, Speed = 15, Body = 2.3, Head = 1.35, Color = C3(255, 170, 220), Range = { 18, 30 }, Fire = 2.8, Pattern = "Stutter", Ground = true, Biome = "Dream" },
    Jellylamp = { Style = "Jellylamp", Label = "Jellylamp", Hp = 90, Dmg = 9, Speed = 16, Body = 2.0, Head = 1.2, Color = C3(255, 150, 230), Range = { 24, 38 }, Fire = 3.0, Pattern = "Pendulum", Biome = "Dream" },
    Dreamweaver = { Style = "Dreamweaver", Label = "Dreamweaver", Hp = 170, Dmg = 9, Speed = 9, Body = 2.7, Head = 1.4, Color = C3(190, 140, 255), Range = { 30, 44 }, Fire = 3.6, Pattern = "SlowStrafe", Biome = "Dream" },
    -- NEON FLATS
    Roadrunner = { Style = "Roadrunner", Label = "Roadrunner", Hp = 100, Dmg = 10, Speed = 18, Body = 2.0, Head = 1.2, Color = C3(255, 110, 180), Range = { 20, 32 }, Fire = 2.6, Pattern = "Afterimage", Ground = true, Biome = "Flats" },
    Tumble = { Style = "Tumble", Label = "Tumble", Hp = 140, Dmg = 11, Speed = 18, Body = 2.4, Head = 1.2, Color = C3(255, 150, 70), Range = { 18, 30 }, Fire = 3.0, Pattern = "Roll", Biome = "Flats" },
    Vulture = { Style = "Vulture", Label = "Vulture", Hp = 95, Dmg = 10, Speed = 17, Body = 2.0, Head = 1.2, Color = C3(255, 90, 90), Range = { 20, 30 }, Fire = 2.8, Pattern = "Orbit", Biome = "Flats" },
    Billboard = { Style = "Billboard", Label = "Billboard", Hp = 90, Dmg = 10, Speed = 14, Body = 2.0, Head = 1.2, Color = C3(80, 230, 255), Range = { 24, 36 }, Fire = 3.0, Pattern = "Constellation", Biome = "Flats" },
    DustDevil = { Style = "DustDevil", Label = "Dust Devil", Hp = 80, Dmg = 9, Speed = 18, Body = 1.9, Head = 1.1, Color = C3(255, 200, 130), Range = { 22, 34 }, Fire = 2.6, Pattern = "Corkscrew", Biome = "Flats" },
    Pylon = { Style = "Pylon", Label = "Pylon", Hp = 180, Dmg = 9, Speed = 9, Body = 2.8, Head = 1.4, Color = C3(255, 120, 60), Range = { 32, 46 }, Fire = 3.6, Pattern = "SlowStrafe", Biome = "Flats" },
}
NB.LORE = {
    Drowse = { Role = "Dream drifter", Text = "Drifts down like a falling petal, swaying, then floats back up. Its lullaby drops two slow marks on you.", Tip = "Step off each mark, track the sway." },
    Paperbird = { Role = "Dream glider", Text = "An origami crane: a sharp wingbeat, then a long glide. It folds two lanes across you in an X.", Tip = "Step out of the cross, not along it." },
    Mirage = { Role = "Dream phantom", Text = "Flickers, then phases out and slides away. Strikes where you are, then again where you WERE.", Tip = "Keep moving, never step back." },
    Sleepwalker = { Role = "Dream walker", Text = "Freezes dead still mid-step, then lurches on at double speed. Leaves a slow drifting nightmare that follows you.", Tip = "Free shots while it sleeps; outrun the drift." },
    Jellylamp = { Role = "Dream swinger", Text = "Hangs from a thread of light and swings, still at each end. Its stingers fall in a line under its swing.", Tip = "Shoot it at the ends of the swing." },
    Dreamweaver = { Role = "Dream suppressor", Text = "A loom of light. Weaves a lattice of lanes around you: one gap is safe.", Tip = "Find the gap before it fills." },
    Roadrunner = { Role = "Flats sprinter", Text = "Drifts, then dashes off in a blink, leaving a neon afterimage. Its burnout lane keeps burning.", Tip = "Ignore the afterimage; don't stand in the lane." },
    Tumble = { Role = "Flats roller", Text = "A ball of rebar and neon wire rolling low over the salt. Throws three hot scraps around you.", Tip = "Track it low; step out of all three." },
    Vulture = { Role = "Flats circler", Text = "Sweeps a slow arc round you, then DIVES: a marked lane straight through you.", Tip = "Strafe across the dive lane." },
    Billboard = { Role = "Flats sign", Text = "A holo sign that hops between the same points in order, pausing on each. Its glare is a wide cone.", Tip = "Learn its shape and pre-aim the next spot." },
    DustDevil = { Role = "Flats twister", Text = "A spinning column that climbs in a corkscrew and drops. Its twister wanders after you.", Tip = "Keep moving: the twister is slow." },
    Pylon = { Role = "Flats suppressor", Text = "A walking power pylon. Strings a live wire between two points across you.", Tip = "Watch both ends: the wire is long." },
}
NB.RANGED_KIND = {
    Drowse = "Lullaby", Paperbird = "Fold", Mirage = "Recur", Sleepwalker = "Drift", Jellylamp = "Stinger", Dreamweaver = "Weave",
    Roadrunner = "Burnout", Tumble = "Scatter", Vulture = "Dive", Billboard = "Glare", DustDevil = "Twister", Pylon = "Powerline",
}
NB.POOLS = {
    Dream = { "Drowse", "Paperbird", "Mirage", "Sleepwalker", "Sleepwalker", "Jellylamp" },
    Flats = { "Roadrunner", "Roadrunner", "Tumble", "Vulture", "Billboard", "DustDevil" },
}
NB.SPECIALIST = { Dream = "Dreamweaver", Flats = "Pylon" }
NB.HARD = { Dream = { "Paperbird", "Mirage" }, Flats = { "DustDevil", "Roadrunner" } }
NB.SLOW = { Dreamweaver = true, Pylon = true }

NB.VISTA = {
    Dream = { Ground = C3(150, 120, 190), GroundMat = M.SmoothPlastic, Peak = C3(120, 96, 170), PeakMat = M.Marble, Tip = C3(255, 170, 235) },
    Flats = { Ground = C3(176, 142, 150), GroundMat = M.Salt, Peak = C3(120, 60, 70), PeakMat = M.Sandstone, Tip = C3(255, 110, 160) },
}
NB.TEMPLATES = {
    Dream = {
        { Name = "Moonlit Isles", Rim = "Edge", RimMat = { M.Glacier, M.Salt }, Ground = M.Salt, Patch = { M.Limestone, M.Glacier }, Edge = { "DreamDoor", "DreamStairs", "DreamClock" },
            RimKit = { "DreamIsle", "DreamDoor", "DreamColumn" }, Hero = "DreamMoon", Glow = { DreamDoor = C3(255, 150, 230) } },
        { Name = "Pillow Fields", Rim = "Ruins", RimMat = { M.Salt, M.Snow }, Ground = M.Snow, Patch = { M.Salt, M.Limestone }, Edge = { "DreamStairs", "DreamColumn", "DreamClock", "DreamDoor" },
            RimKit = { "DreamColumn", "DreamDoor", "DreamIsle" }, Hero = "DreamMoon", Glow = { DreamDoor = C3(150, 230, 255) } },
        { Name = "Clockwork Hollow", Rim = "Cliffs", RimMat = { M.Glacier, M.Salt }, PartyRim = "DreamColumn", Ground = M.Salt, Patch = { M.Limestone, M.Snow },
            Edge = { "DreamClock", "DreamStairs", "DreamDoor" }, RimKit = { "DreamDoor", "DreamColumn" }, Hero = "DreamMoon", Glow = { DreamDoor = C3(255, 150, 230) } },
    },
    Flats = {
        -- (UPDATE 4 PROPS: scanned oil barrels + crates join the roadside clutter -- EnvKit.Flats via tools/biome_mesh_import.py)
        { Name = "Salt Highway", Rim = "Ruins", RimMat = { M.Sandstone, M.Sand }, Ground = M.Salt, Patch = { M.Asphalt, M.Sand }, Edge = { "WreckCar", "Barrier", "ScanCrate", "OilBarrel" },
            RimKit = { "Billboard", "PowerPylon", "WreckCar" }, Hero = "FlatsSun", Glow = { Billboard = C3(255, 90, 180) } },
        { Name = "Mesa Edge", Rim = "Cliffs", RimMat = { M.Sandstone, M.Rock }, PartyRim = "Outcrop", Ground = M.Sand, Patch = { M.Sandstone, M.Asphalt },
            Edge = { "Barrier", "WreckCar", "Outcrop", "OilBarrel" }, RimKit = { "PowerPylon", "Outcrop", "Billboard" }, Hero = "FlatsSun", Glow = { Billboard = C3(80, 230, 255) } },
        { Name = "Drive-In", Rim = "Ruins", RimMat = { M.Sandstone, M.Sand }, Ground = M.Asphalt, Patch = { M.Salt, M.Sand }, Edge = { "ScanCrate", "WreckCar", "Barrier", "OilBarrel" },
            RimKit = { "Billboard", "Billboard", "PowerPylon" }, Hero = "FlatsSun", Glow = { Billboard = C3(255, 200, 80) } },
    },
}

-- ==================== BUILD HELPERS ====================
local function P(parent: Instance, props: any): BasePart
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
    for k, v in pairs(props) do p[k] = v end
    p.Parent = parent
    return p
end
-- solid cover (in the floor's StaticGeometry: blocks shots, bots steer round it)
local function Solid(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, shape: Enum.PartType?): BasePart
    local p = P(parent, { Size = size, CFrame = cf, Color = color, Material = mat })
    p.CanCollide = true; p.CanQuery = true
    if shape then p.Shape = shape end
    return p
end
local function Neon(parent: Instance, size: Vector3, cf: CFrame, color: Color3, transp: number?): BasePart
    return P(parent, { Size = size, CFrame = cf, Color = color, Material = M.Neon, Transparency = transp or 0 })
end
local function Yaw(rng: Random): CFrame return CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) end
local function Light(part: BasePart, color: Color3, range: number, brightness: number?)
    local l = Instance.new("PointLight"); l.Color = color; l.Range = range; l.Brightness = brightness or 1.6; l.Shadows = false; l.Parent = part
end
local function Live(fx: Instance, fn: (number, number) -> ())
    -- a client-only animation loop that ends with the room
    if not IS_CLIENT then return end
    local t0 = os.clock()
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if not fx.Parent then conn:Disconnect() return end
        if not fx:IsDescendantOf(workspace) then return end -- (optimization pass 2026-10-27: a parked room's loop rests; fn gets the elapsed time, so it resumes in step)
        fn(os.clock() - t0, dt)
    end)
end
local PINK, TEAL, LAV, PEARL = C3(255, 150, 230), C3(130, 235, 245), C3(190, 160, 255), C3(240, 232, 250)
local SUNSET, MAGENTA, CYANF, SALT, RUST = C3(255, 130, 60), C3(255, 70, 170), C3(80, 230, 255), C3(220, 210, 196), C3(120, 60, 54)

-- ==================== DREAMSCAPE PIECES ====================
-- (pos = the bottom centre on the floor; every piece is modest: 4-12 parts)
local function DreamDoor(geo: Instance, cf: CFrame, s: number, glow: Color3?)
    -- a freestanding door frame of white marble with a dream glowing inside it
    local h, w = 9 * s, 4.6 * s
    Solid(geo, Vector3.new(0.9 * s, h, 0.9 * s), cf * CFrame.new(-w / 2, h / 2, 0), PEARL, M.Marble)
    Solid(geo, Vector3.new(0.9 * s, h, 0.9 * s), cf * CFrame.new(w / 2, h / 2, 0), PEARL, M.Marble)
    Solid(geo, Vector3.new(w + 1.4 * s, 0.9 * s, 1.2 * s), cf * CFrame.new(0, h + 0.4 * s, 0), PEARL, M.Marble)
    P(geo, { Size = Vector3.new(w - 0.6 * s, h - 0.4 * s, 0.15), CFrame = cf * CFrame.new(0, h / 2, 0), Color = glow or PINK, Material = M.ForceField, Transparency = 0.05 })
    Neon(geo, Vector3.new(w + 0.1, 0.15 * s, 0.2), cf * CFrame.new(0, 0.1, 0), glow or PINK)
end
local function DreamStairs(geo: Instance, cf: CFrame, s: number)
    -- a broken stairway climbing to nowhere: four steps, the top one floating off
    for i = 0, 3 do
        local step = Solid(geo, Vector3.new(4 * s, 1 * s, 1.8 * s), cf * CFrame.new(0, (i + 0.5) * s, -i * 1.6 * s), (i % 2 == 0) and PEARL or C3(214, 196, 236), M.Marble)
        if i == 3 then step.CFrame = step.CFrame * CFrame.new(0, 1.4 * s, -0.6 * s) * CFrame.Angles(math.rad(8), 0, math.rad(6)); step.CanCollide = false end
    end
    Neon(geo, Vector3.new(4.1 * s, 0.1, 0.12), cf * CFrame.new(0, 1.02 * s, 0.9 * s), TEAL)
end
local function DreamClock(geo: Instance, cf: CFrame, s: number)
    -- a melted clock face slumped on the ground (low cover)
    Solid(geo, Vector3.new(1.2 * s, 6 * s, 6 * s), cf * CFrame.new(0, 2.2 * s, 0) * CFrame.Angles(0, 0, math.rad(70)), PEARL, M.SmoothPlastic, Enum.PartType.Cylinder)
    P(geo, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3 * s, 6.4 * s, 6.4 * s), CFrame = cf * CFrame.new(0, 2.2 * s, 0) * CFrame.Angles(0, 0, math.rad(70)) * CFrame.new(-0.05, 0, 0), Color = C3(255, 200, 120), Material = M.Metal })
    local face = cf * CFrame.new(0, 2.2 * s, 0) * CFrame.Angles(0, 0, math.rad(70)) * CFrame.new(0.64 * s, 0, 0)
    P(geo, { Size = Vector3.new(0.1, 2.2 * s, 0.25 * s), CFrame = face * CFrame.new(0, 0.9 * s, 0), Color = C3(40, 30, 60), Material = M.SmoothPlastic })
    P(geo, { Size = Vector3.new(0.1, 0.25 * s, 1.6 * s), CFrame = face * CFrame.new(0, 0, 0.7 * s), Color = C3(40, 30, 60), Material = M.SmoothPlastic })
    for k = 0, 3 do
        local a = k * math.pi / 2
        Neon(geo, Vector3.new(0.1, 0.4 * s, 0.4 * s), face * CFrame.new(0, math.cos(a) * 2.5 * s, math.sin(a) * 2.5 * s), PINK)
    end
end
local function DreamColumn(geo: Instance, cf: CFrame, s: number)
    -- a twisting column: stacked marble drums each turned a little, a glowing capital
    for i = 0, 5 do
        Solid(geo, Vector3.new(2.4 * s, 2 * s, 2.4 * s), cf * CFrame.new(0, (i + 0.5) * 2 * s, 0) * CFrame.Angles(0, i * 0.35, 0), (i % 2 == 0) and PEARL or C3(222, 206, 240), M.Marble)
    end
    Neon(geo, Vector3.new(3 * s, 0.4 * s, 3 * s), cf * CFrame.new(0, 12.2 * s, 0) * CFrame.Angles(0, 0.4, 0), LAV, 0.1)
end
local function DreamIsle(geo: Instance, cf: CFrame, s: number)
    -- a little floating island: an inverted wedge of rock, a soft lawn, a round glowing tree
    local top = cf * CFrame.new(0, 10 * s, 0)
    P(geo, { Size = Vector3.new(6 * s, 1 * s, 6 * s), CFrame = top, Color = C3(196, 170, 226), Material = M.SmoothPlastic })
    local w = Instance.new("WedgePart"); w.Anchored = true; w.CanCollide = false; w.CanQuery = false; w.CastShadow = false
    w.Size = Vector3.new(6 * s, 5 * s, 3 * s); w.CFrame = top * CFrame.new(0, -3 * s, -1.5 * s) * CFrame.Angles(math.rad(180), 0, 0); w.Color = C3(120, 96, 170); w.Material = M.Marble; w.Parent = geo
    local w2 = w:Clone(); w2.CFrame = top * CFrame.new(0, -3 * s, 1.5 * s) * CFrame.Angles(math.rad(180), math.rad(180), 0); w2.Parent = geo
    P(geo, { Size = Vector3.new(0.4 * s, 2 * s, 0.4 * s), CFrame = top * CFrame.new(0, 1.5 * s, 0), Color = C3(130, 100, 170), Material = M.Wood })
    P(geo, { Shape = Enum.PartType.Ball, Size = Vector3.one * 3 * s, CFrame = top * CFrame.new(0, 3.2 * s, 0), Color = PINK, Material = M.Neon, Transparency = 0.15 })
end

-- ==================== NEON FLATS PIECES ====================
local function WreckCar(geo: Instance, cf: CFrame, s: number)
    -- (UPDATE 4 PROPS: a scanned abandoned sedan -- the parts car read as a toy; real size whatever the caller's scale,
    -- a box collider as the cover it always was. The parts car below = the fallback.)
    local EK = require(script.Parent:WaitForChild("EnvKit"))
    if EK.Has("Flats", "FlatsSedan") then
        EK.Place("Flats", "FlatsSedan", cf * CFrame.Angles(0, math.pi / 2, 0), { Scale = math.clamp(s, 0.8, 1.3), Parent = geo,
            Hitbox = true, HitParent = geo, HitScale = 0.85 })
        return
    end
    -- a dead muscle car: body, cabin, four flat wheels, one tail light still glowing
    local body = cf * CFrame.new(0, 1.3 * s, 0) * CFrame.Angles(0, 0, math.rad(4))
    Solid(geo, Vector3.new(4 * s, 1.6 * s, 8.4 * s), body, C3(120, 50, 60), M.CorrodedMetal)
    Solid(geo, Vector3.new(3.6 * s, 1.3 * s, 3.8 * s), body * CFrame.new(0, 1.4 * s, 0.6 * s), C3(96, 40, 50), M.CorrodedMetal)
    P(geo, { Size = Vector3.new(3.4 * s, 1.0 * s, 0.1), CFrame = body * CFrame.new(0, 1.45 * s, -1.33 * s) * CFrame.Angles(math.rad(-20), 0, 0), Color = C3(40, 50, 70), Material = M.Glass, Transparency = 0.3 })
    for _, sx in ipairs({ -1, 1 }) do
        for _, sz in ipairs({ -1, 1 }) do
            P(geo, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8 * s, 1.8 * s, 1.8 * s), CFrame = body * CFrame.new(sx * 2 * s, -0.6 * s, sz * 2.8 * s), Color = C3(30, 30, 34), Material = M.Rubber })
        end
        Neon(geo, Vector3.new(0.9 * s, 0.35 * s, 0.1), body * CFrame.new(sx * 1.4 * s, 0.2 * s, 4.22 * s), (sx < 0) and MAGENTA or C3(60, 20, 30))
    end
end
local function Barrier(geo: Instance, cf: CFrame, s: number)
    -- two concrete road barriers with a hazard stripe
    for _, x in ipairs({ -2.2, 2.2 }) do
        local c = cf * CFrame.new(x * s, 1.4 * s, 0) * CFrame.Angles(0, math.rad(x * 3), 0)
        Solid(geo, Vector3.new(4 * s, 2.8 * s, 1.4 * s), c, C3(196, 192, 184), M.Concrete)
        P(geo, { Size = Vector3.new(4.02 * s, 0.5 * s, 1.42 * s), CFrame = c * CFrame.new(0, 0.6 * s, 0), Color = SUNSET, Material = M.SmoothPlastic })
    end
end
local function Crates(geo: Instance, cf: CFrame, s: number)
    -- a stack of shipping crates, one with a neon stencil
    Solid(geo, Vector3.new(4 * s, 3 * s, 4 * s), cf * CFrame.new(0, 1.5 * s, 0), C3(140, 110, 80), M.WoodPlanks)
    Solid(geo, Vector3.new(3 * s, 2.6 * s, 3 * s), cf * CFrame.new(0.4 * s, 4.3 * s, 0.3 * s) * CFrame.Angles(0, 0.4, 0), C3(110, 86, 64), M.WoodPlanks)
    Solid(geo, Vector3.new(3.4 * s, 2.8 * s, 3.4 * s), cf * CFrame.new(3.8 * s, 1.4 * s, -0.6 * s) * CFrame.Angles(0, -0.3, 0), C3(150, 120, 86), M.WoodPlanks)
    Neon(geo, Vector3.new(2.4 * s, 0.4 * s, 0.1), cf * CFrame.new(0, 1.8 * s, -2.02 * s), CYANF)
end
-- (UPDATE 4 PROPS) painted roadside ads for the billboards (tools/make_flats_ads.py: generic words, no brands)
NB.AD_ART = { "rbxassetid://114324995079146", "rbxassetid://80050145947081", "rbxassetid://99711470423825" }
local function Billboard(geo: Instance, cf: CFrame, s: number, glow: Color3?)
    -- (UPDATE 4 PROPS: a real roadside billboard -- weathered timber posts + brace, a printed ad in a corroded frame, a
    -- catwalk under it and two scanned security lamps over the top; the neon panel below = the fallback)
    local EK = require(script.Parent:WaitForChild("EnvKit"))
    if EK.Has("Flats", "SecLight") then
        local h = 9 * s
        local wood, iron = C3(104, 84, 66), C3(78, 70, 66)
        for _, sx in ipairs({ -1, 1 }) do
            Solid(geo, Vector3.new(0.9 * s, h + 4.6 * s, 0.9 * s), cf * CFrame.new(sx * 3.4 * s, (h + 4.6 * s) / 2, 0.45 * s), wood, M.Wood)
        end
        P(geo, { Size = Vector3.new(0.35 * s, 0.35 * s, math.sqrt((6.8 * s) ^ 2 + (h * 0.55) ^ 2)), Color = wood, Material = M.Wood,
            CFrame = cf * CFrame.new(0, h * 0.42, 0.45 * s) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.atan2(h * 0.55, 6.8 * s), 0, 0) })
        local panel = cf * CFrame.new(0, h + 2.4 * s, 0)
        local art = NB.AD_ART[(math.floor(math.abs(cf.X) * 7 + math.abs(cf.Z) * 3) % #NB.AD_ART) + 1]
        local board = P(geo, { Size = Vector3.new(10 * s, 5 * s, 0.4 * s), CFrame = panel, Color = C3(150, 140, 130), Material = M.WoodPlanks })
        local face = Instance.new("Decal"); face.Texture = art; face.Face = Enum.NormalId.Front; face.Parent = board
        for _, y in ipairs({ -2.6, 2.6 }) do
            P(geo, { Size = Vector3.new(10.5 * s, 0.32 * s, 0.6 * s), CFrame = panel * CFrame.new(0, y * s, 0), Color = iron, Material = M.CorrodedMetal })
        end
        for _, x in ipairs({ -5.1, 5.1 }) do
            P(geo, { Size = Vector3.new(0.32 * s, 5.5 * s, 0.6 * s), CFrame = panel * CFrame.new(x * s, 0, 0), Color = iron, Material = M.CorrodedMetal })
        end
        P(geo, { Size = Vector3.new(10.4 * s, 0.22 * s, 1.5 * s), CFrame = panel * CFrame.new(0, -2.85 * s, -0.85 * s), Color = C3(96, 94, 92), Material = M.DiamondPlate })
        for _, x in ipairs({ -3, 3 }) do
            P(geo, { Size = Vector3.new(0.18 * s, 0.18 * s, 1.7 * s), CFrame = panel * CFrame.new(x * s, 2.95 * s, -0.75 * s), Color = iron, Material = M.CorrodedMetal })
            EK.Place("Flats", "SecLight", panel * CFrame.new(x * s, 2.1 * s, -1.6 * s), { Scale = s, Parent = geo, Shadow = false })
        end
        return
    end
    -- two steel posts, a big dark panel with a neon frame and glowing "text" bars
    local h = 9 * s
    for _, sx in ipairs({ -1, 1 }) do Solid(geo, Vector3.new(0.6 * s, h, 0.6 * s), cf * CFrame.new(sx * 3.4 * s, h / 2, 0), C3(70, 70, 76), M.Metal) end
    local panel = cf * CFrame.new(0, h + 2.4 * s, 0)
    P(geo, { Size = Vector3.new(10 * s, 5 * s, 0.4 * s), CFrame = panel, Color = C3(20, 16, 26), Material = M.SmoothPlastic })
    local g = glow or MAGENTA
    for _, y in ipairs({ -2.5, 2.5 }) do Neon(geo, Vector3.new(10.2 * s, 0.25 * s, 0.5 * s), panel * CFrame.new(0, y * s, 0), g) end
    for _, x in ipairs({ -5, 5 }) do Neon(geo, Vector3.new(0.25 * s, 5.2 * s, 0.5 * s), panel * CFrame.new(x * s, 0, 0), g) end
    Neon(geo, Vector3.new(6 * s, 1.2 * s, 0.1), panel * CFrame.new(-0.8 * s, 0.9 * s, -0.25 * s), CYANF, 0.1)
    Neon(geo, Vector3.new(4 * s, 0.6 * s, 0.1), panel * CFrame.new(-1.8 * s, -0.9 * s, -0.25 * s), C3(255, 220, 90), 0.1)
end
local function PowerPylon(geo: Instance, cf: CFrame, s: number)
    -- (UPDATE 4 PROPS: a scanned wooden utility pole with its cross-arm and insulators, the same height; the lattice of
    -- parts below = the fallback)
    local EK = require(script.Parent:WaitForChild("EnvKit"))
    if EK.Has("Flats", "FlatsPole") then
        EK.Place("Flats", "FlatsPole", cf, { Scale = 18 * s / 20, Parent = geo, Shadow = false })
        local hb = Solid(geo, Vector3.new(1.6 * s, 6 * s, 1.6 * s), cf * CFrame.new(0, 3 * s, 0), C3(0, 0, 0), M.SmoothPlastic)
        hb.Transparency = 1; hb.Name = "Hitbox"
        return
    end
    -- a steel lattice pylon: four splayed legs, cross braces, two arms with glass insulators
    local h = 18 * s
    for _, sx in ipairs({ -1, 1 }) do
        for _, sz in ipairs({ -1, 1 }) do
            local foot = Vector3.new(sx * 2.4 * s, 0, sz * 2.4 * s)
            local top = Vector3.new(sx * 0.6 * s, h, sz * 0.6 * s)
            local mid = (foot + top) / 2
            P(geo, { Size = Vector3.new(0.4 * s, 0.4 * s, (top - foot).Magnitude), CFrame = cf * CFrame.lookAt(mid, top), Color = C3(90, 90, 98), Material = M.Metal })
        end
    end
    for k = 1, 3 do
        local y = k * h / 4
        local wdt = 4.8 * s * (1 - y / h * 0.75)
        P(geo, { Size = Vector3.new(wdt, 0.3 * s, 0.3 * s), CFrame = cf * CFrame.new(0, y, 0), Color = C3(90, 90, 98), Material = M.Metal })
        P(geo, { Size = Vector3.new(0.3 * s, 0.3 * s, wdt), CFrame = cf * CFrame.new(0, y, 0), Color = C3(90, 90, 98), Material = M.Metal })
    end
    P(geo, { Size = Vector3.new(9 * s, 0.4 * s, 0.4 * s), CFrame = cf * CFrame.new(0, h * 0.86, 0), Color = C3(90, 90, 98), Material = M.Metal })
    for _, sx in ipairs({ -1, 1 }) do
        Neon(geo, Vector3.new(0.5 * s, 0.9 * s, 0.5 * s), cf * CFrame.new(sx * 4.2 * s, h * 0.86 - 0.6 * s, 0), CYANF, 0.2)
    end
    -- (an invisible box for its feet, so bots go round)
    local hb = Solid(geo, Vector3.new(4.4 * s, 6 * s, 4.4 * s), cf * CFrame.new(0, 3 * s, 0), C3(0, 0, 0), M.SmoothPlastic)
    hb.Transparency = 1; hb.Name = "Hitbox"
end

-- ==================== PROPS (old room scatter) / LANDMARKS ====================
-- (pos = floor point; theme passed for parity with the generator's prop functions)
NB.Props = {
    Dream = {
        Cover = { function(geo, _, rng, pos) DreamClock(geo, CFrame.new(pos) * Yaw(rng), 0.9) end, function(geo, _, rng, pos) DreamStairs(geo, CFrame.new(pos) * Yaw(rng), 1) end },
        Tall = { function(geo, _, rng, pos) DreamDoor(geo, CFrame.new(pos) * Yaw(rng), 1) end, function(geo, _, rng, pos) DreamColumn(geo, CFrame.new(pos) * Yaw(rng), 0.9) end },
        Air = { function(geo, _, rng, pos) DreamIsle(geo, CFrame.new(pos + Vector3.new(0, rng:NextNumber(4, 10), 0)) * Yaw(rng), 0.7) end },
    },
    Flats = {
        Cover = { function(geo, _, rng, pos) WreckCar(geo, CFrame.new(pos) * Yaw(rng), 1) end, function(geo, _, rng, pos) Barrier(geo, CFrame.new(pos) * Yaw(rng), 1) end,
            function(geo, _, rng, pos) Crates(geo, CFrame.new(pos) * Yaw(rng), 1) end },
        Tall = { function(geo, _, rng, pos) Billboard(geo, CFrame.new(pos) * Yaw(rng), 0.8) end, function(geo, _, rng, pos) PowerPylon(geo, CFrame.new(pos) * Yaw(rng), 0.8) end },
        Air = {},
    },
}
NB.Landmarks = {
    Dream = {
        function(geo, _, rng, c) -- Ring of Doors: six dream doors facing the plaza
            for i = 0, 5 do
                local a = i / 6 * math.pi * 2 + 0.3
                local p = c + Vector3.new(math.cos(a) * 30, 0, math.sin(a) * 30)
                DreamDoor(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1, (i % 2 == 0) and PINK or TEAL)
            end
        end,
        function(geo, _, rng, c) -- Moon Steps: broken stairways spiralling round the plaza, columns between
            for i = 0, 3 do
                local a = i * math.pi / 2 + 0.6
                local p = c + Vector3.new(math.cos(a) * 28, 0, math.sin(a) * 28)
                DreamStairs(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)) * CFrame.Angles(0, math.rad(90), 0), 1.2)
                local q = c + Vector3.new(math.cos(a + 0.8) * 32, 0, math.sin(a + 0.8) * 32)
                DreamColumn(geo, CFrame.new(q), 0.9)
            end
        end,
    },
    Flats = {
        function(geo, _, rng, c) -- Truck Stop: wrecks round the plaza under two billboards
            for i = 0, 5 do
                local a = i / 6 * math.pi * 2 + 0.2
                WreckCar(geo, CFrame.new(c + Vector3.new(math.cos(a) * 30, 0, math.sin(a) * 30)) * CFrame.Angles(0, -a + rng:NextNumber(-0.4, 0.4), 0), 1)
            end
            Billboard(geo, CFrame.new(c + Vector3.new(-34, 0, 4)) * CFrame.Angles(0, math.rad(90), 0), 0.9, MAGENTA)
            Billboard(geo, CFrame.new(c + Vector3.new(34, 0, -4)) * CFrame.Angles(0, math.rad(-90), 0), 0.9, CYANF)
        end,
        function(geo, _, rng, c) -- Power Line: pylons at the corners, barriers between them
            for _, sx in ipairs({ -1, 1 }) do
                for _, sz in ipairs({ -1, 1 }) do PowerPylon(geo, CFrame.new(c + Vector3.new(sx * 28, 0, sz * 28)), 0.8) end
                Barrier(geo, CFrame.new(c + Vector3.new(sx * 30, 0, 0)) * CFrame.Angles(0, math.rad(90), 0), 1)
            end
        end,
    },
}

-- ==================== MAP SHELL KITS (MapShell templates' Edge / RimKit names) ====================
local KITS = {
    DreamDoor = function(g, cf, s) DreamDoor(g, cf, s * 0.6) end,
    DreamStairs = function(g, cf, s) DreamStairs(g, cf, s * 0.6) end,
    DreamClock = function(g, cf, s) DreamClock(g, cf, s * 0.55) end,
    DreamColumn = function(g, cf, s) DreamColumn(g, cf, s * 0.5) end,
    DreamIsle = function(g, cf, s) DreamIsle(g, cf, s * 0.6) end,
    WreckCar = function(g, cf, s) WreckCar(g, cf, s * 0.55) end,
    Barrier = function(g, cf, s) Barrier(g, cf, s * 0.55) end,
    Crates = function(g, cf, s) Crates(g, cf, s * 0.55) end,
    Billboard = function(g, cf, s) Billboard(g, cf, s * 0.5) end,
    PowerPylon = function(g, cf, s) PowerPylon(g, cf, s * 0.5) end,
}
-- (MapShell's ShellPlace calls this before EnvKit; returns nil when the name isn't ours)
-- RIM LOD (performance pass 2026-10-06): these kits are built from parts, so a rim of 40-52 of them drew 470-760 parts
-- (Salt Highway 987 on the floor, ~3x the other biomes' 200-500 -- their rim pieces are single EnvKit meshes). A rim piece
-- (no shadow, scale >= 1.8: always far outside the play box) keeps only its LOD_KEEP biggest faces (the silhouette you
-- can see from the arena) and every third one is skipped. Edge pieces inside the box keep every part.
local LOD_KEEP, rimCount = 6, 0
function NB.Kit(kit: string, cf: CFrame, opts: any): Instance?
    local fn = KITS[kit]
    if not fn then return nil end
    local m = Instance.new("Model")
    m.Name = kit
    m.Parent = opts.Parent
    local s = opts.Scale or 1
    local rim = opts.Shadow == false and s >= 1.8 and not opts.Hitbox
    if rim then
        rimCount += 1
        if rimCount % 3 == 0 then return m end -- (an empty model: the caller still gets an instance)
    end
    fn(m, cf, s)
    if rim then
        local list = {}
        for _, d in ipairs(m:GetDescendants()) do
            if d:IsA("BasePart") and d.Name ~= "Hitbox" then
                local z = d.Size
                local a, b, c = math.max(z.X, z.Y, z.Z), 0, math.min(z.X, z.Y, z.Z)
                b = z.X + z.Y + z.Z - a - c
                table.insert(list, { P = d, Face = a * b })
            end
        end
        table.sort(list, function(x, y) return x.Face > y.Face end)
        for i = LOD_KEEP + 1, #list do list[i].P:Destroy() end
    end
    -- solid pieces stay visual-only unless the caller wants a hitbox (edge dressing inside the box): one box collider in
    -- the floor geometry, like EnvKit's
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") and d.Name ~= "Hitbox" then d.CanCollide = false; d.CanQuery = false end
    end
    for _, d in ipairs(m:GetDescendants()) do if d.Name == "Hitbox" then d:Destroy() end end
    if opts.Hitbox then
        local bbCF, bbSize = m:GetBoundingBox()
        local h = Instance.new("Part")
        h.Name = "Hitbox"; h.Anchored = true; h.Transparency = 1; h.CastShadow = false; h.CanTouch = false
        h.Size = bbSize * (opts.HitScale or 0.85); h.CFrame = bbCF
        h.Parent = opts.HitParent or opts.Parent
    end
    return m
end

-- ==================== HEROES (the far landmark) ====================
NB.Heroes = {}
function NB.Heroes.DreamMoon(fx: Instance, ctx: any)
    -- a giant moon hanging low over the far side of the arena, a ring of light round it, floating isles beneath
    local c = Vector3.new(ctx.half * 0.6, 160, ctx.zC + ctx.half * 3.2)
    P(fx, { Name = "DreamMoon", Shape = Enum.PartType.Ball, Size = Vector3.one * 150, Position = c, Color = C3(255, 236, 250), Material = M.Neon, Transparency = 0.05 })
    P(fx, { Name = "DreamMoonShade", Shape = Enum.PartType.Ball, Size = Vector3.one * 146, Position = c + Vector3.new(-26, 18, -30), Color = C3(54, 40, 96), Material = M.SmoothPlastic })
    for k = 0, 23 do
        local a = k / 24 * math.pi * 2
        P(fx, { Name = "MoonRing", Size = Vector3.new(26, 2, 2), CFrame = CFrame.new(c) * CFrame.Angles(math.rad(70), 0, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 118),
            Color = (k % 2 == 0) and PINK or TEAL, Material = M.Neon, Transparency = 0.25 })
    end
    local r = ctx.rng
    for _ = 1, 6 do
        local a = r:NextNumber(0, math.pi * 2)
        local d = ctx.half * r:NextNumber(1.4, 2.2)
        DreamIsle(fx, CFrame.new(math.cos(a) * d, 18 + r:NextNumber(10, 60), ctx.zC + math.sin(a) * d) * CFrame.Angles(0, r:NextNumber(0, 6), 0), r:NextNumber(2, 4))
    end
end
function NB.Heroes.FlatsSun(fx: Instance, ctx: any)
    -- the synthwave sun sinking on the far horizon (a disc with dark bands across its lower half) + its reflection line
    local c = Vector3.new(0, 70, ctx.zC + ctx.half * 5.5)
    local R = 190
    P(fx, { Name = "Sun", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, R * 2, R * 2), CFrame = CFrame.new(c) * CFrame.Angles(0, math.rad(90), 0), Color = C3(255, 150, 90), Material = M.Neon })
    P(fx, { Name = "SunTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, R * 1.4, R * 1.4), CFrame = CFrame.new(c + Vector3.new(0, R * 0.32, -1)) * CFrame.Angles(0, math.rad(90), 0), Color = C3(255, 220, 110), Material = M.Neon })
    for k = 0, 5 do
        local y = -R * 0.12 - k * R * 0.14
        local w = 2 * math.sqrt(math.max(0, R * R - y * y))
        P(fx, { Name = "SunBand", Size = Vector3.new(w + 4, 6 + k * 3, 3), CFrame = CFrame.new(c + Vector3.new(0, y, -3)), Color = C3(80, 26, 70), Material = M.SmoothPlastic })
    end
end

-- ==================== VISTA (the horizon) ====================
function NB.Vista(fx: Instance, biome: string, Pf: (any) -> BasePart, centre: Vector3, gy: number, zC: number, r: Random)
    if biome == "Dream" then
        -- a cloud sea instead of ground (soft lavender puffs) and far floating islands at different heights
        -- (0.58: soft particle cloud banks -- the old flat sphere-mesh puffs read as hard discs)
        for _ = 1, 14 do
            local a = r:NextNumber(0, math.pi * 2)
            local d = r:NextNumber(320, 1000)
            local slab = Pf({ Name = "DreamCloud", Size = Vector3.new(260, 20, 260), CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * d, r:NextNumber(-14, 10), math.sin(a) * d)),
                Transparency = 1, CanCollide = false, CanQuery = false })
            local e = Instance.new("ParticleEmitter")
            e.Texture = "rbxasset://textures/particles/smoke_main.dds"
            e.Color = ColorSequence.new(C3(240, 214, 250), C3(250, 200, 230))
            e.Shape = Enum.ParticleEmitterShape.Box; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
            e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 80), NumberSequenceKeypoint.new(1, 100) })
            e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.15), NumberSequenceKeypoint.new(0.8, 0.15), NumberSequenceKeypoint.new(1, 1) })
            e.Lifetime = NumberRange.new(40, 50); e.Rate = 0.2; e.Speed = NumberRange.new(0.5, 1.5); e.SpreadAngle = Vector2.new(180, 20)
            e.Rotation = NumberRange.new(0, 360); e.RotSpeed = NumberRange.new(-2, 2); e.LightEmission = 0.15; e.LightInfluence = 0.3
            e.Parent = slab
            if game:GetService("RunService"):IsClient() then
                task.spawn(function()
                    for _ = 1, 60 do
                        if slab:IsDescendantOf(workspace) then e:Emit(9) return end
                        task.wait(0.1)
                    end
                end)
            end
        end
        for _ = 1, 12 do
            local a = r:NextNumber(0, math.pi * 2)
            local d = r:NextNumber(500, 1000)
            local base = centre + Vector3.new(math.cos(a) * d, r:NextNumber(80, 300), math.sin(a) * d)
            local sz = r:NextNumber(40, 110)
            Pf({ Name = "FarIsle", Size = Vector3.new(sz, sz * 0.25, sz), CFrame = CFrame.new(base) * CFrame.Angles(0, r:NextNumber(0, 6), 0), Color = C3(190, 160, 220), Material = M.SmoothPlastic })
            Pf({ Name = "FarIsleRock", Size = Vector3.one * sz * 0.62, CFrame = CFrame.new(base - Vector3.new(0, sz * 0.32, 0)) * CFrame.Angles(math.rad(45), r:NextNumber(0, 6), math.rad(35)),
                Color = C3(110, 86, 160), Material = M.Marble })
            Pf({ Name = "FarIsleGlow", Shape = Enum.PartType.Ball, Size = Vector3.one * sz * 0.22, CFrame = CFrame.new(base + Vector3.new(0, sz * 0.2, 0)), Color = (r:NextNumber() < 0.5) and PINK or TEAL, Material = M.Neon, Transparency = 0.2 })
        end
        return true
    elseif biome == "Flats" then
        -- the neon grid running out over the salt to the horizon + flat-topped mesas + a far highway with its lights
        for k = -12, 12 do
            Pf({ Name = "GridLine", Size = Vector3.new(1.2, 0.3, 4000), CFrame = CFrame.new(centre + Vector3.new(k * 90, 1.2, 0)), Color = MAGENTA, Material = M.Neon, Transparency = 0.35 })
            Pf({ Name = "GridLine", Size = Vector3.new(4000, 0.3, 1.2), CFrame = CFrame.new(centre + Vector3.new(0, 1.2, k * 90)), Color = MAGENTA, Material = M.Neon, Transparency = 0.45 })
        end
        for _ = 1, 14 do
            local a = r:NextNumber(0, math.pi * 2)
            local d = r:NextNumber(650, 1250)
            local w, h = r:NextNumber(120, 340), r:NextNumber(60, 160)
            local p = centre + Vector3.new(math.cos(a) * d, h / 2 - 4, math.sin(a) * d)
            Pf({ Name = "Mesa", Size = Vector3.new(w, h, w * r:NextNumber(0.4, 0.9)), CFrame = CFrame.new(p) * CFrame.Angles(0, r:NextNumber(0, 6), 0), Color = C3(150, 70, 70), Material = M.Sandstone })
            Pf({ Name = "MesaCap", Size = Vector3.new(w * 1.05, 6, w * 0.6), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, r:NextNumber(0, 6), 0), Color = C3(180, 96, 84), Material = M.Sandstone })
        end
        for k = -10, 10 do
            Pf({ Name = "RoadLight", Shape = Enum.PartType.Ball, Size = Vector3.one * 3, CFrame = CFrame.new(centre + Vector3.new(-520, 8, k * 60)), Color = (k % 2 == 0) and SUNSET or C3(255, 230, 160), Material = M.Neon })
        end
        return true
    end
    -- (0.87 WORLDS: a world's own horizon)
    local wv = NB.WorldVista and NB.WorldVista[biome]
    if wv then return wv(fx, Pf, centre, gy, zC, r) == true end
    return false
end

-- ==================== SCENERY over the open roof ====================
NB.Scenery = {}
function NB.Scenery.Dream(fx: Instance, theme: any, rng: Random, zC: number, arena: number, height: number, invisible: any, emitter: any)
    local half = arena / 2
    -- slow-drifting dream doors and stair fragments hanging in the air over the walls (they bob, client only)
    local floaters = {}
    for i = 1, 8 do
        local a = i / 8 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
        local p = Vector3.new(math.cos(a) * half * 1.15, height + rng:NextNumber(4, 24), zC + math.sin(a) * half * 1.15)
        local m = Instance.new("Model"); m.Name = "DreamFloater"; m.Parent = fx
        if i % 2 == 0 then DreamDoor(m, CFrame.lookAt(p, Vector3.new(0, p.Y, zC)), 0.9, (i % 4 == 0) and PINK or TEAL)
        else DreamStairs(m, CFrame.new(p) * Yaw(rng), 1.1) end
        for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide = false; d.CanQuery = false end end
        table.insert(floaters, { M = m, Base = m:GetPivot(), Ph = rng:NextNumber(0, 6) })
    end
    -- petals drifting down through the room + a soft glow from above
    for _, q in ipairs({ { -1, 0 }, { 1, 0 } }) do
        local src = invisible(fx, Vector3.new(half - 4, 1, half * 2 - 8), CFrame.new(q[1] * half / 2, height - 2, zC))
        emitter(src, {
            Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(PINK, TEAL), LightEmission = 0.8,
            Rate = 9, Lifetime = NumberRange.new(5, 7), Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(30, 30),
            EmissionDirection = Enum.NormalId.Bottom, Size = NumberSequence.new(0.35, 0.15), Transparency = NumberSequence.new(0.2, 1),
            RotSpeed = NumberRange.new(-60, 60), Acceleration = Vector3.new(0.6, -0.4, 0),
        })
    end
    Live(fx, function(t)
        for _, f in ipairs(floaters) do
            if f.M.Parent then f.M:PivotTo(f.Base * CFrame.new(0, math.sin(t * 0.6 + f.Ph) * 2.2, 0) * CFrame.Angles(0, math.sin(t * 0.3 + f.Ph) * 0.08, 0)) end
        end
    end)
end
function NB.Scenery.Flats(fx: Instance, theme: any, rng: Random, zC: number, arena: number, height: number, invisible: any, emitter: any)
    local half = arena / 2
    -- power cables strung over the room between two pylons outside the walls
    local poles = {}
    for _, sx in ipairs({ -1, 1 }) do
        for _, sz in ipairs({ -0.6, 0.6 }) do
            local p = Vector3.new(sx * (half + 18), 0, zC + sz * half)
            local m = Instance.new("Model"); m.Name = "FlatsPylon"; m.Parent = fx
            PowerPylon(m, CFrame.new(p), 1.6)
            for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide = false; d.CanQuery = false end end
            table.insert(poles, p + Vector3.new(0, 18 * 1.6 * 0.86, 0))
        end
    end
    for _, pair in ipairs({ { 1, 3 }, { 2, 4 } }) do
        local a, b = poles[pair[1]], poles[pair[2]]
        for k = 0, 5 do
            local t0, t1 = k / 6, (k + 1) / 6
            local sag = function(t) return a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 12, 0) end
            local p0, p1 = sag(t0), sag(t1)
            P(fx, { Name = "Cable", Size = Vector3.new(0.3, 0.3, (p1 - p0).Magnitude), CFrame = CFrame.lookAt((p0 + p1) / 2, p1), Color = C3(30, 30, 34), Material = M.SmoothPlastic })
        end
    end
    -- heat shimmer + drifting dust on the wind
    local src = invisible(fx, Vector3.new(arena, 1, arena), CFrame.new(0, 2, zC))
    emitter(src, {
        Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(255, 200, 160)), LightEmission = 0.2,
        Rate = 6, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(10, 10),
        EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new(3, 8), Transparency = NumberSequence.new(0.85, 1),
        Acceleration = Vector3.new(5, 0.5, 0),
    })
end

-- ==================== SET PIECES (boss arenas) ====================
NB.SetPiece = {}
local RF = 84
function NB.SetPiece.Dream(geo: Instance, deco: Instance, c: Vector3, rng: Random, F: number): Color3
    -- THE WAKING RING: ten tall dream doors round the fight floor, a moon hanging over the far side
    for i = 0, 9 do
        local a = (i + 0.5) / 10 * 2 * math.pi
        if math.abs(((a - math.pi + math.pi) % (2 * math.pi)) - math.pi) > 0.32 then -- (the north entrance stays open)
            local p = c + Vector3.new(math.sin(a) * 100, F, math.cos(a) * 100)
            DreamDoor(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1.8, (i % 2 == 0) and PINK or TEAL)
        end
    end
    local moon = P(deco, { Shape = Enum.PartType.Ball, Size = Vector3.one * 60, Position = c + Vector3.new(0, F + 90, 150), Color = C3(255, 236, 250), Material = M.Neon })
    Light(moon, C3(255, 210, 245), 60, 1.2)
    return PINK
end
function NB.SetPiece.Flats(geo: Instance, deco: Instance, c: Vector3, rng: Random, F: number): Color3
    -- THE DRIVE-IN: wrecks parked in a ring facing a giant glowing screen on the far side, pylons behind them
    for i = 0, 11 do
        local a = (i + 0.5) / 12 * 2 * math.pi
        if math.abs(((a - math.pi + math.pi) % (2 * math.pi)) - math.pi) > 0.3 then
            local p = c + Vector3.new(math.sin(a) * 98, F, math.cos(a) * 98)
            if i % 3 == 0 then PowerPylon(geo, CFrame.new(p), 1.2) else WreckCar(geo, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 1.4) end
        end
    end
    local screen = c + Vector3.new(0, F + 26, 128)
    P(deco, { Size = Vector3.new(96, 44, 2), CFrame = CFrame.new(screen), Color = C3(20, 14, 26), Material = M.SmoothPlastic })
    local glow = P(deco, { Size = Vector3.new(88, 38, 0.4), CFrame = CFrame.new(screen + Vector3.new(0, 0, -1.2)), Color = C3(255, 120, 180), Material = M.Neon, Transparency = 0.3 })
    Light(glow, C3(255, 140, 190), 60, 1.4)
    for _, sx in ipairs({ -1, 1 }) do
        P(deco, { Size = Vector3.new(3, 48, 3), CFrame = CFrame.new(screen + Vector3.new(sx * 49, -2, 0)), Color = C3(70, 70, 76), Material = M.Metal })
    end
    return SUNSET
end

-- ==================== ATTACKS (the new enemies: every one telegraphed) ====================
function NB.Attack(EA: any, kind: string, atk: any, model: Model, pos: Vector3, lead: Vector3, rng: Random): number?
    local function Alive() return model.Parent ~= nil and model:GetAttribute("Dead") ~= true end
    local from = Vector3.new(pos.X, lead.Y, pos.Z)
    local flat = Vector3.new(lead.X - pos.X, 0, lead.Z - pos.Z)
    local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, 1)
    local side = Vector3.new(-dir.Z, 0, dir.X)
    if kind == "Lullaby" then
        -- two slow rings rolling out from under it (jump them)
        EA.Ring(atk, Vector3.new(pos.X, lead.Y, pos.Z), 40, 0.8, { Mult = 0.8, Speed = 18, StartRadius = 2 })
        task.delay(0.9, function() if Alive() then EA.Ring(atk, Vector3.new(pos.X, lead.Y, pos.Z), 40, 0.5, { Mult = 0.8, Speed = 18, StartRadius = 2 }) end end)
        return 0.8
    elseif kind == "Fold" then
        -- two lanes crossing in an X on you
        for _, a in ipairs({ math.rad(45), math.rad(-45) }) do
            local d = CFrame.Angles(0, a, 0):VectorToWorldSpace(dir)
            EA.Line(atk, lead - d * 22, lead + d * 22, 3.6, 0.8, { Mult = 0.8, Height = 9 })
        end
        return 0.8
    elseif kind == "Recur" then
        -- where you are now, then again where you were (keep going forward)
        EA.Circle(atk, lead, 4.5, 0.7, { Mult = 0.8 })
        local was = lead
        task.delay(0.6, function() if Alive() then EA.Circle(atk, was, 6, 0.6, { Mult = 0.8 }) end end)
        return 0.7
    elseif kind == "Drift" then
        -- a slow nightmare zone that creeps toward where you were for a few seconds
        local at = lead + dir * -6
        EA.Zone(atk, at, 5, 0.8, 3.5, { Mult = 0.3, Height = 5 })
        task.delay(1.6, function() if Alive() then EA.Zone(atk, at + dir * 6, 5, 0.4, 2.5, { Mult = 0.3, Height = 5 }) end end)
        return 0.8
    elseif kind == "Stinger" then
        -- a line of stingers falling under its swing, across you
        for i = -2, 2 do
            local at = lead + side * (i * 4.5)
            task.delay((i + 2) * 0.08, function() if Alive() then EA.Circle(atk, at, 2.6, 0.7, { Mult = 0.6 }) end end)
        end
        return 0.75
    elseif kind == "Weave" then
        -- a lattice: three lanes one way, two the other, leaving gaps
        for i = -1, 1 do
            local o = side * (i * 7.5 + 2)
            EA.Line(atk, lead + o - dir * 26, lead + o + dir * 26, 3, 1.0, { Mult = 0.9, Height = 9 })
        end
        for i = -1, 1, 2 do
            local o = dir * (i * 6)
            EA.Line(atk, lead + o - side * 26, lead + o + side * 26, 3, 1.15, { Mult = 0.9, Height = 9 })
        end
        return 1.0
    elseif kind == "Burnout" then
        -- a lane from it through you that keeps burning
        local len = math.min(flat.Magnitude + 10, 50)
        EA.Line(atk, from, from + dir * len, 4, 0.75, { Mult = 0.9, Height = 9, OnStrike = function(a, b)
            if not Alive() then return end
            for i = 1, 3 do EA.Zone(atk, a:Lerp(b, i / 4), 3, 0.05, 2.2, { Mult = 0.25, Height = 5 }) end
        end })
        return 0.75
    elseif kind == "Scatter" then
        -- three hot scraps thrown around you
        local a0 = rng:NextNumber(0, math.pi * 2)
        for i = 0, 2 do
            local a = a0 + i * math.pi * 2 / 3
            EA.Circle(atk, lead + Vector3.new(math.cos(a) * 5, 0, math.sin(a) * 5), 3.8, 0.7, { Mult = 0.7 })
        end
        return 0.7
    elseif kind == "Dive" then
        -- a marked lane from it straight through you (strafe across it)
        local len = math.min(flat.Magnitude + 16, 60)
        EA.Line(atk, from, from + dir * len, 5, 0.85, { Mult = 1.1, Height = 9 })
        return 0.85
    elseif kind == "Glare" then
        -- a wide cone of glare
        EA.Cone(atk, from, dir, math.min(flat.Magnitude + 14, 50), 26, 0.85, { Mult = 0.9 })
        return 0.85
    elseif kind == "Twister" then
        -- a twister that wanders after you: three zones, each a step closer to where you went
        for i = 0, 2 do
            task.delay(i * 0.7, function()
                if not Alive() then return end
                local tgt = atk.Targets and atk.Targets()[1]
                local hrp = tgt and tgt.Character and tgt.Character:FindFirstChild("HumanoidRootPart")
                local at = hrp and Vector3.new(hrp.Position.X, lead.Y, hrp.Position.Z) or lead
                EA.Zone(atk, lead:Lerp(at, 0.5 + i * 0.25), 4, 0.6, 1.2, { Mult = 0.35, Height = 6 })
            end)
        end
        return 0.6
    elseif kind == "Powerline" then
        -- a long live wire strung between two points either side of you
        local a = lead + side * 22 + dir * rng:NextNumber(-4, 4)
        local b = lead - side * 22 + dir * rng:NextNumber(-4, 4)
        EA.Line(atk, a, b, 3.2, 1.0, { Mult = 1.0, Height = 9 })
        return 1.0
    end
    if NB.WorldAttack then return NB.WorldAttack(EA, kind, atk, model, pos, lead, rng) end -- (0.89 WORLD FOES)
    return nil
end

-- (0.87 WORLDS: the twelve world biomes hand their data, kits, heroes, scenery and set pieces over here -- WorldBiomes)
do
    local ok, err = pcall(function()
        require(script.Parent:WaitForChild("WorldBiomes")).MergeInto(NB, KITS)
    end)
    if not ok then warn("[NewBiomes] worlds failed to merge: " .. tostring(err)) end
end

return NB
