--!nocheck
-- TOXIC WASTES foes (0.89): mutants and junk machines of the scrapland. Superboss THE RECLAIMER.
local C3 = Color3.fromRGB
local M = Enum.Material
local TOXIC, RUST, RUST2, YELLOW, STEEL, BLACK = C3(140, 255, 60), C3(124, 70, 42), C3(92, 58, 40), C3(220, 180, 40), C3(100, 104, 110), C3(30, 30, 30)

local F = {}
F.Specialist = "HazmatMech"
F.Enemies = {
    {
        Name = "MutantFly", Hard = true,
        Def = { Label = "Mutant Fly", Hp = 60, Dmg = 8, Speed = 22, Body = 1.6, Head = 1.0, Color = C3(90, 110, 60), Range = { 20, 32 }, Fire = 2.4, Pattern = "Zigzag" },
        Lore = { Role = "Wastes buzzer", Text = "A fly the size of a dog with glowing green eyes, zigzagging hard. Spits a burst of bile where you stand.", Tip = "Keep moving." },
        Attack = { Shape = "Burst", R = 4.6, W = 0.75, Mult = 0.9 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            for _, sx in ipairs({ -1, 1 }) do
                P(model, { Name = "BigIris", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.9, R * 1.0, R * 0.8), CFrame = base * CFrame.new(sx * R * 0.5, R * 0.3, -R * 0.75), Color = TOXIC, Glow = true })
                P(model, { Name = "Wing", Size = Vector3.new(0.08, R * 0.6, R * 1.8), CFrame = base * CFrame.new(sx * R * 0.9, R * 0.8, R * 0.5) * CFrame.Angles(0, 0, sx * math.rad(30)), Color = C3(200, 220, 200), Material = M.Glass, Transparency = 0.45 })
                for k = 0, 2 do P(model, { Name = "Leg", Size = Vector3.new(0.08, R * 0.9, 0.08), CFrame = base * CFrame.new(sx * R * 0.5, -R * 1.0, (k - 1) * R * 0.5) * CFrame.Angles(0, 0, sx * math.rad(25)), Color = BLACK, Material = M.SmoothPlastic }) end
            end
            P(model, { Name = "Abdomen", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 1.2, R * 1.1, R * 1.8), CFrame = base * CFrame.new(0, -R * 0.1, R * 1.1), Color = C3(70, 90, 50), Material = M.SmoothPlastic })
        end,
    },
    {
        Name = "BarrelBot", Weight = 2,
        Def = { Label = "Barrel Bot", Hp = 140, Dmg = 11, Speed = 18, Body = 2.3, Head = 1.2, Color = YELLOW, Range = { 18, 30 }, Fire = 3.0, Pattern = "Roll" },
        Lore = { Role = "Wastes roller", Text = "A leaking hazard barrel rolling low across the ground. Splashes a burst that leaves a toxic puddle.", Tip = "Track it low; don't stand in the puddle." },
        Attack = { Shape = "Puddle", R = 4.4, W = 0.8, Mult = 0.8, Life = 2.8 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 2.4, R * 2.1, R * 2.1), CFrame = base, Color = YELLOW, Material = M.Metal })
            for _, x in ipairs({ -0.8, 0, 0.8 }) do P(model, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, R * 2.2, R * 2.2), CFrame = base * CFrame.new(x * R, 0, 0), Color = BLACK, Material = M.Metal }) end
            P(model, { Name = "Leak", Size = Vector3.new(R * 0.6, 0.3, R * 0.3), CFrame = base * CFrame.new(R * 0.3, R * 0.95, 0), Color = TOXIC, Glow = true })
            H.Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "smoke_main.dds", TOXIC, 3, 0.8, 1, 1.0, Enum.NormalId.Top, 30, 0.3)
        end,
    },
    {
        Name = "Scrapper", Weight = 2,
        Def = { Label = "Scrapper", Hp = 140, Dmg = 11, Speed = 15, Body = 2.3, Head = 1.3, Color = RUST, Range = { 16, 28 }, Fire = 2.8, Pattern = "GroundStrafe", Ground = true },
        Lore = { Role = "Wastes junker", Text = "A robot bolted together from scrap, a saw blade for a hand. Throws a cone of sparks and shrapnel at you.", Tip = "Get out of the cone, sideways." },
        Attack = { Shape = "Cone", Half = 22, Past = 10, W = 0.85, Mult = 0.9 },
        Decor = function(model, H)
            local P, W, body, base, hc, head = H.Part, H.Wedge, H.body, H.base, H.headCF, H.head
            P(model, { Name = "Plate", Size = Vector3.new(body.X * 0.7, body.Y * 0.4, 0.2), CFrame = base * CFrame.new(-body.X * 0.1, body.Y * 0.15, -body.Z / 2 - 0.12) * CFrame.Angles(0, 0, 0.15), Color = RUST2, Material = M.CorrodedMetal })
            P(model, { Name = "Tip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, body.X * 0.8, body.X * 0.8), CFrame = base * CFrame.new(body.X * 0.9, -body.Y * 0.2, -body.Z * 0.6) * CFrame.Angles(0, math.rad(90), 0), Color = STEEL, Material = M.Metal })
            P(model, { Name = "Visor", Size = Vector3.new(head.X * 0.8, head.Y * 0.18, 0.1), CFrame = hc * CFrame.new(0, head.Y * 0.1, -head.Z * 0.52), Color = TOXIC, Glow = true })
            W(model, { Name = "Exhaust", Size = Vector3.new(0.4, body.Y * 0.6, 0.4), CFrame = base * CFrame.new(-body.X * 0.3, body.Y * 0.6, body.Z * 0.5), Color = BLACK, Material = M.Metal })
            H.Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "smoke_main.dds", C3(60, 60, 60), 3, 0.8, 2, 1.0, Enum.NormalId.Top, 15, 0)
        end,
    },
    {
        Name = "GasBag",
        Def = { Label = "Gas Bag", Hp = 90, Dmg = 9, Speed = 14, Body = 2.1, Head = 1.2, Color = C3(170, 200, 80), Range = { 24, 38 }, Fire = 3.0, Pattern = "Pendulum" },
        Lore = { Role = "Wastes floater", Text = "A swollen bladder of toxic gas hanging from tubes, swinging slowly. Vents puddles of gas where you're heading.", Tip = "Shoot it at the ends of its swing; keep off the gas." },
        Attack = { Shape = "Trail", N = 3, R = 3.8, Gap = 5, W = 0.7, Mult = 0.3, Life = 2.6 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Bladder", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 2.4, R * 2.1, R * 2.4), CFrame = base * CFrame.new(0, R * 0.3, 0), Color = C3(150, 180, 70), Material = M.SmoothPlastic, Transparency = 0.15 })
            for i = 0, 3 do
                local a = i / 4 * math.pi * 2
                P(model, { Name = "Tendril", Size = Vector3.new(0.18, R * 1.6, 0.18), CFrame = base * CFrame.new(math.cos(a) * R * 0.6, -R * 1.2, math.sin(a) * R * 0.6), Color = STEEL, Material = M.Metal })
            end
            P(model, { Name = "Valve", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 0.4, R * 0.8, R * 0.8), CFrame = base * CFrame.new(0, R * 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = YELLOW, Material = M.Metal })
            P(model, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.9, CFrame = base * CFrame.new(0, R * 0.3, 0), Color = TOXIC, Glow = true, Transparency = 0.3 })
        end,
    },
    {
        Name = "Ghoul",
        Def = { Label = "Ghoul", Hp = 120, Dmg = 11, Speed = 16, Body = 2.1, Head = 1.25, Color = C3(130, 140, 100), Range = { 16, 28 }, Fire = 2.8, Pattern = "Stutter", Ground = true },
        Lore = { Role = "Wastes mutant", Text = "A hunched mutant with glowing veins that freezes, then lurches on. Slaps two puddles of slime either side of you.", Tip = "Free shots while it freezes; stay in the gap." },
        Attack = { Shape = "Pair", Gap = 3.6, R = 3.6, W = 0.75, Mult = 0.8 },
        Decor = function(model, H)
            local P, body, base, hc, head = H.Part, H.body, H.base, H.headCF, H.head
            for i, o in ipairs({ { -0.25, 0.3, 30 }, { 0.3, 0.05, -40 }, { 0.05, -0.25, 70 }, { -0.35, -0.2, -20 } }) do
                P(model, { Name = "Vein", Size = Vector3.new(0.1, body.Y * 0.35, 0.1), CFrame = base * CFrame.new(body.X * o[1], body.Y * o[2], -body.Z / 2 - 0.06) * CFrame.Angles(0, 0, math.rad(o[3])), Color = TOXIC, Glow = true })
            end
            P(model, { Name = "Hump", Shape = Enum.PartType.Ball, Size = Vector3.new(body.X * 0.9, body.Y * 0.5, body.Z * 0.9), CFrame = base * CFrame.new(0, body.Y * 0.4, body.Z * 0.3), Color = C3(110, 120, 84), Material = M.SmoothPlastic })
            for _, sx in ipairs({ -1, 1 }) do P(model, { Name = "FrostEye", Shape = Enum.PartType.Ball, Size = Vector3.one * head.X * 0.22, CFrame = hc * CFrame.new(sx * head.X * 0.22, head.Y * 0.1, -head.Z * 0.48), Color = TOXIC, Glow = true }) end
        end,
    },
    {
        Name = "HazmatMech",
        Def = { Label = "Hazmat Mech", Hp = 190, Dmg = 9, Speed = 9, Body = 2.8, Head = 1.4, Color = YELLOW, Range = { 30, 44 }, Fire = 4.0, Pattern = "SlowStrafe" },
        Lore = { Role = "Wastes suppressor", Text = "A boxy hazmat walker-pod with a toxic tank on its back. Sprays a square of toxic lanes round you, then the middle.", Tip = "Leave the square before it closes." },
        Attack = { Shape = "Grid", Gap = 6, W = 0.95, Mult = 0.9 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Shell", Size = Vector3.new(R * 2.1, R * 2.0, R * 2.1), CFrame = base, Color = YELLOW, Material = M.Metal })
            for k = -2, 2 do P(model, { Name = "Stripe", Size = Vector3.new(R * 0.35, R * 2.05, 0.1), CFrame = base * CFrame.new(k * R * 0.42, 0, -R * 1.07) * CFrame.Angles(0, 0, 0.5), Color = BLACK, Material = M.SmoothPlastic }) end
            P(model, { Name = "Lens", Size = Vector3.new(R * 1.2, R * 0.4, 0.1), CFrame = base * CFrame.new(0, R * 0.6, -R * 1.1), Color = TOXIC, Glow = true })
            P(model, { Name = "Tank", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 2.0, R * 0.9, R * 0.9), CFrame = base * CFrame.new(0, R * 0.2, R * 1.4) * CFrame.Angles(0, 0, math.rad(90)), Color = STEEL, Material = M.Metal })
            P(model, { Name = "Coil", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, R * 0.95, R * 0.95), CFrame = base * CFrame.new(0, R * 0.2, R * 1.4) * CFrame.Angles(0, 0, math.rad(90)), Color = TOXIC, Glow = true })
        end,
    },
}

-- ==================== SUPERBOSS: THE RECLAIMER ====================
F.Super = {
    Name = "THE RECLAIMER", Color = TOXIC,
    Hitbox = { Torso = { Vector3.new(7, 7, 6), Vector3.new(0, 2, 0) }, Core = { Vector3.new(2.6, 2.6, 2.6), Vector3.new(0, 2.4, -3.1), "Ball" },
        Head = { Vector3.new(3, 2.4, 3), Vector3.new(0, 6.8, -1) } },
    Evade = { Amp = 8, Rate = 1.1, Dodge = 4.2 },
    Body = function(model, Mf, col, H)
        local P, W, Style = H.Part, H.Wedge, H.Style
        Style(model:FindFirstChild("Torso"), RUST, M.CorrodedMetal)
        Style(model:FindFirstChild("Core"), TOXIC, H.NEON)
        Style(model:FindFirstChild("Head"), YELLOW, H.METAL)
        -- a junk-compactor body on tracks: bolted plates, a glowing reactor in its chest, smokestacks on its back
        for k = 0, 2 do P(model, { Name = "Plate", Size = Vector3.new(7.2, 1.2, 6.2), CFrame = Mf(0, -0.6 + k * 2.2, 0) * CFrame.Angles(0, 0, math.rad((k - 1) * 3)), Color = (k % 2 == 0) and RUST2 or RUST, Material = M.CorrodedMetal }) end
        for _, sx in ipairs({ -1, 1 }) do
            P(model, { Name = "Deco_Track" .. (sx < 0 and "L" or "R"), Size = Vector3.new(1.6, 2, 7), CFrame = Mf(sx * 4.2, -1.6, 0), Color = BLACK, Material = H.METAL })
            for k = -2, 2 do P(model, { Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.7, 1.4, 1.4), CFrame = Mf(sx * 4.2, -1.6, k * 1.4), Color = STEEL, Material = H.METAL }) end
            P(model, { Name = "Stack", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.2, 1.2), CFrame = Mf(sx * 1.8, 7, 2.4) * CFrame.Angles(0, 0, math.rad(90)), Color = BLACK, Material = H.METAL })
        end
        -- the cab (head) with a hazard-striped visor, a claw arm on the right, a crusher maw on the left
        P(model, { Name = "Visor", Size = Vector3.new(2.8, 0.6, 0.2), CFrame = Mf(0, 7, -2.55), Color = TOXIC, Glow = true })
        for k = -3, 3 do P(model, { Name = "Hazard", Size = Vector3.new(0.4, 2.45, 0.1), CFrame = Mf(k * 0.45, 6.8, -2.6) * CFrame.Angles(0, 0, 0.5), Color = (k % 2 == 0) and YELLOW or BLACK, Material = H.SMOOTH }) end
        P(model, { Name = "Deco_Claw", Size = Vector3.new(1.2, 1.2, 5), CFrame = Mf(4.6, 4, -2.4), Color = STEEL, Material = H.METAL })
        for _, sy in ipairs({ -1, 1 }) do W(model, { Name = "Deco_Claw", Size = Vector3.new(0.6, 1.4, 2), CFrame = Mf(4.6, 4 + sy * 0.8, -5.4) * CFrame.Angles(sy > 0 and 0 or math.pi, 0, 0), Color = YELLOW, Material = H.METAL }) end
        P(model, { Name = "Deco_Maw", Size = Vector3.new(2.4, 2.4, 2.4), CFrame = Mf(-4.4, 3.6, -2.2), Color = BLACK, Material = H.METAL })
        P(model, { Name = "Deco_MawGlow", Size = Vector3.new(2, 0.4, 0.2), CFrame = Mf(-4.4, 3.6, -3.45), Color = TOXIC, Glow = true })
        H.Emit(model:FindFirstChild("Torso") or model.PrimaryPart, C3(70, 70, 60), 6, 0.8, 3, 2, "rbxasset://textures/particles/smoke_main.dds")
    end,
    Kit = function(H)
        local Mv, EA, Unit, Pose = H.M, H.EA, H.Unit, H.Pose
        local function SludgeLob(B)
            -- lobbed sludge: a burst on you that leaves a toxic pool, three times
            for _ = 1, 3 do
                local r = B:Root()
                if not r or not B:Alive() then return end
                local at = r.Position
                EA.Circle(B.ctx, at, 5, B:W(0.8), { Mult = 1.0 })
                task.delay(B:W(0.8), function() if B:Alive() then EA.Zone(B.ctx, at, 4.5, 0.1, 3, { Mult = 0.3, Height = 5 }) end end)
                B:Wait(0.6)
            end
            B:Wait(B:W(0.8) + 0.4)
        end
        local function Compactor(B)
            -- the crusher: two walls close in from your sides, then slam
            local r = B:Root()
            if not r then return end
            local at = r.Position
            local d = Unit(at - B.pos)
            local side = Vector3.new(-d.Z, 0, d.X)
            for _, off in ipairs({ 12, 7 }) do
                for _, sx in ipairs({ -1, 1 }) do
                    local c = at + side * sx * off
                    EA.Line(B.ctx, c - d * 24, c + d * 24, 4, B:W(0.8) + (12 - off) * 0.06, { Mult = 1.0, Height = 9 })
                end
            end
            task.delay(B:W(0.8) + 0.6, function() if B:Alive() then EA.Line(B.ctx, at - d * 24, at + d * 24, 6, 0.6, { Mult = 1.2, Height = 9 }) end end)
            B:Wait(B:W(0.8) + 1.4)
        end
        return {
            Color = TOXIC, Move = "Chase", Range = 24, SpeedMul = 0.75, Recover = { 1.9, 1.6, 1.3 },
            Names = { "THE RECLAIMER", "THE RECLAIMER: MELTDOWN", "THE RECLAIMER: CRITICAL MASS" },
            Moves = {
                { { SludgeLob, "SLUDGE LOB" }, { Compactor, "COMPACTOR" }, { function(B) Mv.Mines(B, 13) end, "SCRAP MINES" } },
                { { function(B) Mv.Pools(B, 4) end, "TOXIC SPILL" }, { Compactor, "COMPACTOR" }, { function(B) Mv.Carpet(B, 5, 4, 6, 0.75, 0.2) end, "JUNK RAIN" },
                    { SludgeLob, "SLUDGE LOB" } },
                { { function(B) Mv.Tide(B, 3, true) end, "SLUDGE WAVE" }, { Compactor, "COMPACTOR" }, { function(B) Mv.Quadrants(B, 70, 2, 0.9) end, "FALLOUT ZONES" },
                    { function(B) Mv.ArenaWipe(B, 2, 8, 1.5) end, "MELTDOWN" } },
            },
            Animate = function(B, pivot, now)
                Pose(B, "Deco_Claw", pivot, CFrame.new(4.6, 4, 0), CFrame.Angles(math.sin(now * 1.2) * 0.12, 0, 0))
                Pose(B, "Deco_Maw", pivot, CFrame.new(-4.4, 3.6, -2.2), CFrame.Angles(0, now * 2.0, 0))
                Pose(B, "Deco_MawGlow", pivot, CFrame.new(-4.4, 3.6, -2.2), CFrame.Angles(0, now * 2.0, 0))
            end,
        }
    end,
}
return F
