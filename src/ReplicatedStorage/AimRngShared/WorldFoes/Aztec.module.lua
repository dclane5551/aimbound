--!nocheck
-- SUN EMPIRE foes (0.89): warriors and spirits of the jade-and-gold city. Superboss TONATIUH'S AVATAR.
local C3 = Color3.fromRGB
local M = Enum.Material
local JADE, JADE2, GOLD, TERRA, TURQ, FEATHER, FEATHER2, STONE = C3(50, 150, 110), C3(36, 116, 86), C3(236, 186, 64), C3(184, 92, 60), C3(40, 200, 190), C3(30, 170, 120), C3(220, 60, 60), C3(186, 156, 112)

local F = {}
F.Specialist = "HighPriest"
F.Enemies = {
    {
        Name = "Quetzal", Hard = true, Weight = 2,
        Def = { Label = "Quetzal", Hp = 85, Dmg = 9, Speed = 18, Body = 1.9, Head = 1.15, Color = FEATHER, Range = { 22, 36 }, Fire = 2.6, Pattern = "Serpent" },
        Lore = { Role = "Empire serpent", Text = "A feathered serpent weaving through the air. Rakes a row of plumed strikes along its line to you.", Tip = "Sidestep the row." },
        Attack = { Shape = "Row", N = 5, R = 3, Gap = 4.2, W = 0.8, Mult = 0.7 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for k = 1, 5 do
                local sz = R * (1.2 - k * 0.14)
                P(model, { Name = "TailSegment", Shape = Enum.PartType.Ball, Size = Vector3.one * sz, CFrame = base * CFrame.new(math.sin(k * 0.9) * R * 0.4, 0, R * (0.5 + k * 0.8)), Color = (k % 2 == 0) and FEATHER or JADE2, Material = M.SmoothPlastic })
                if k <= 3 then W(model, { Name = "Fin", Size = Vector3.new(0.1, sz * 0.8, sz * 0.9), CFrame = base * CFrame.new(math.sin(k * 0.9) * R * 0.4, sz * 0.6, R * (0.5 + k * 0.8)), Color = (k % 2 == 0) and FEATHER2 or GOLD, Material = M.SmoothPlastic }) end
            end
            for k = -2, 2 do W(model, { Name = "Plume", Size = Vector3.new(0.1, R * 1.1, R * 0.5), CFrame = base * CFrame.new(k * R * 0.3, R * 1.2, -R * 0.1) * CFrame.Angles(0, 0, math.rad(k * -16)), Color = (k % 2 == 0) and FEATHER or FEATHER2, Material = M.SmoothPlastic }) end
            W(model, { Name = "Jaw", Size = Vector3.new(R * 0.9, R * 0.3, R * 0.8), CFrame = base * CFrame.new(0, -R * 0.4, -R * 0.8) * CFrame.Angles(math.pi, 0, 0), Color = JADE2, Material = M.SmoothPlastic })
        end,
    },
    {
        Name = "JaguarWarrior", Weight = 2,
        Def = { Label = "Jaguar Warrior", Hp = 120, Dmg = 11, Speed = 16, Body = 2.2, Head = 1.3, Color = C3(220, 160, 60), Range = { 16, 30 }, Fire = 2.8, Pattern = "Leap", Ground = true },
        Lore = { Role = "Empire warrior", Text = "An elite warrior in a jaguar-head helm, leaping at you. Swings a cone of obsidian blades.", Tip = "Get out of the cone, sideways." },
        Attack = { Shape = "Cone", Half = 24, Past = 10, W = 0.85, Mult = 0.9 },
        Decor = function(model, H)
            local P, W, body, base, hc, head = H.Part, H.Wedge, H.body, H.base, H.headCF, H.head
            P(model, { Name = "Helm", Shape = Enum.PartType.Ball, Size = Vector3.new(head.X * 1.3, head.Y * 1.1, head.Z * 1.3), CFrame = hc * CFrame.new(0, head.Y * 0.2, head.Z * 0.1), Color = C3(220, 160, 60), Material = M.SmoothPlastic })
            for i, o in ipairs({ { -0.3, 0.4 }, { 0.3, 0.3 }, { 0, 0.6 }, { -0.15, 0.1 }, { 0.35, 0.05 } }) do
                P(model, { Name = "Spot", Shape = Enum.PartType.Ball, Size = Vector3.one * head.X * 0.2, CFrame = hc * CFrame.new(head.X * o[1], head.Y * o[2], -head.Z * 0.3), Color = C3(60, 40, 30), Material = M.SmoothPlastic })
            end
            W(model, { Name = "Jaw", Size = Vector3.new(head.X * 1.1, head.Y * 0.3, head.Z * 0.6), CFrame = hc * CFrame.new(0, -head.Y * 0.3, -head.Z * 0.55), Color = C3(220, 160, 60), Material = M.SmoothPlastic })
            for _, sx in ipairs({ -1, 1 }) do W(model, { Name = "Ear", Size = Vector3.new(0.15, head.Y * 0.4, head.Z * 0.3), CFrame = hc * CFrame.new(sx * head.X * 0.4, head.Y * 0.8, 0), Color = C3(220, 160, 60), Material = M.SmoothPlastic }) end
            P(model, { Name = "Shield", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, body.X * 0.9, body.X * 0.9), CFrame = base * CFrame.new(-body.X * 0.75, 0, -body.Z * 0.3) * CFrame.Angles(0, math.rad(90), 0), Color = TURQ, Material = M.SmoothPlastic })
            P(model, { Name = "Blade", Size = Vector3.new(0.2, 0.4, body.Z * 1.8), CFrame = base * CFrame.new(body.X * 0.7, -body.Y * 0.1, -body.Z * 0.5), Color = C3(30, 30, 36), Material = M.Glass })
        end,
    },
    {
        Name = "SunMask",
        Def = { Label = "Sun Mask", Hp = 90, Dmg = 9, Speed = 16, Body = 2.0, Head = 1.2, Color = GOLD, Range = { 20, 32 }, Fire = 2.8, Pattern = "Orbit" },
        Lore = { Role = "Empire glare", Text = "A gold sun mask crowned with rays, strafing back and forth in front of you. Crosses two rays of sun over you.", Tip = "Step out of the X." },
        Attack = { Shape = "Cross", L = 20, Width = 3.4, W = 0.85, Mult = 0.8 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            P(model, { Name = "Mask", Size = Vector3.new(R * 1.6, R * 1.8, 0.4), CFrame = base * CFrame.new(0, 0, -R * 0.95), Color = GOLD, Material = M.Metal })
            for _, sx in ipairs({ -1, 1 }) do P(model, { Name = "EyeSpot", Size = Vector3.new(R * 0.35, R * 0.15, 0.1), CFrame = base * CFrame.new(sx * R * 0.38, R * 0.25, -R * 1.17), Color = TURQ, Glow = true }) end
            P(model, { Name = "Tongue", Size = Vector3.new(R * 0.3, R * 0.6, 0.1), CFrame = base * CFrame.new(0, -R * 0.55, -R * 1.17), Color = FEATHER2, Material = M.SmoothPlastic })
            for i = 0, 9 do
                local a = i / 10 * math.pi * 2
                W(model, { Name = "StarPoint", Size = Vector3.new(0.2, R * 0.7, R * 0.4), CFrame = base * CFrame.new(0, 0, -R * 0.8) * CFrame.Angles(0, 0, a) * CFrame.new(0, R * 1.45, 0), Color = (i % 2 == 0) and GOLD or JADE, Material = M.Metal })
            end
        end,
    },
    {
        Name = "JadeSkull",
        Def = { Label = "Jade Skull", Hp = 75, Dmg = 9, Speed = 14, Body = 1.8, Head = 1.1, Color = JADE, Range = { 20, 32 }, Fire = 2.6, Pattern = "Popcorn" },
        Lore = { Role = "Empire relic", Text = "A carved jade skull that pops up and drifts down. Its gaze bursts where you stand.", Tip = "Keep moving." },
        Attack = { Shape = "Burst", R = 4.6, W = 0.75, Mult = 0.9 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Skull", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 2.0, R * 2.1, R * 2.2), CFrame = base, Color = JADE, Material = M.Marble })
            for _, sx in ipairs({ -1, 1 }) do P(model, { Name = "EyeSpot", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.5, R * 0.45, 0.2), CFrame = base * CFrame.new(sx * R * 0.4, R * 0.2, -R * 1.0), Color = GOLD, Glow = true }) end
            P(model, { Name = "Teeth", Size = Vector3.new(R * 1.0, R * 0.25, 0.2), CFrame = base * CFrame.new(0, -R * 0.55, -R * 0.95), Color = C3(240, 236, 210), Material = M.SmoothPlastic })
            for k = -1, 1 do P(model, { Name = "Inlay", Size = Vector3.new(R * 0.15, R * 0.6, 0.1), CFrame = base * CFrame.new(k * R * 0.45, R * 0.9, -R * 0.6) * CFrame.Angles(math.rad(-40), 0, 0), Color = GOLD, Material = M.Metal }) end
        end,
    },
    {
        Name = "Hummingbird", Hard = true,
        Def = { Label = "Hummingbird", Hp = 55, Dmg = 7, Speed = 24, Body = 1.5, Head = 0.95, Color = TURQ, Range = { 18, 30 }, Fire = 2.2, Pattern = "Zigzag" },
        Lore = { Role = "Empire darter", Text = "A jewel-bright hummingbird darting in zigzags. Stabs two strikes either side of you.", Tip = "Stay in the gap." },
        Attack = { Shape = "Pair", Gap = 3.4, R = 3.2, W = 0.7, Mult = 0.8 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for _, sx in ipairs({ -1, 1 }) do W(model, { Name = "Wing", Size = Vector3.new(0.08, R * 0.6, R * 1.8), CFrame = base * CFrame.new(sx * R * 1.0, R * 0.4, R * 0.1) * CFrame.Angles(0, 0, math.rad(sx * 60)), Color = C3(150, 240, 230), Material = M.SmoothPlastic, Transparency = 0.2 }) end
            P(model, { Name = "Beak", Size = Vector3.new(0.12, 0.12, R * 1.6), CFrame = base * CFrame.new(0, 0, -R * 1.6), Color = C3(40, 40, 40), Material = M.SmoothPlastic })
            P(model, { Name = "Throat", Size = Vector3.new(R * 1.2, R * 0.6, 0.15), CFrame = base * CFrame.new(0, -R * 0.3, -R * 0.85), Color = FEATHER2, Glow = true })
            for k = -1, 1 do W(model, { Name = "TailFin", Size = Vector3.new(0.08, R * 0.3, R * 1.0), CFrame = base * CFrame.new(k * R * 0.2, 0, R * 1.1), Color = JADE, Material = M.SmoothPlastic }) end
        end,
    },
    {
        Name = "HighPriest",
        Def = { Label = "High Priest", Hp = 185, Dmg = 9, Speed = 9, Body = 2.8, Head = 1.4, Color = FEATHER2, Range = { 30, 44 }, Fire = 3.8, Pattern = "SlowStrafe" },
        Lore = { Role = "Empire suppressor", Text = "A priest of the sun under a towering feather headdress. Draws a lattice of light round you: one gap is safe.", Tip = "Find the gap before it fills." },
        Attack = { Shape = "Lattice", W = 1.0, Mult = 0.9 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for k = -4, 4 do W(model, { Name = "Plume", Size = Vector3.new(0.15, R * 2.0, R * 0.6), CFrame = base * CFrame.new(0, R * 1.2, R * 0.3) * CFrame.Angles(0, 0, math.rad(k * 14)) * CFrame.new(0, R * 0.9, 0), Color = (k % 2 == 0) and FEATHER or FEATHER2, Material = M.SmoothPlastic }) end
            P(model, { Name = "Mask", Size = Vector3.new(R * 1.4, R * 1.4, 0.3), CFrame = base * CFrame.new(0, R * 0.2, -R * 1.0), Color = TURQ, Material = M.SmoothPlastic })
            for _, sx in ipairs({ -1, 1 }) do P(model, { Name = "EyeSpot", Size = Vector3.new(R * 0.3, R * 0.15, 0.1), CFrame = base * CFrame.new(sx * R * 0.3, R * 0.35, -R * 1.18), Color = GOLD, Glow = true }) end
            P(model, { Name = "Collar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 0.3, R * 2.6, R * 2.6), CFrame = base * CFrame.new(0, -R * 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = M.Metal })
            P(model, { Name = "ChestCore", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.5, CFrame = base * CFrame.new(0, -R * 0.6, -R * 1.25), Color = JADE, Glow = true })
        end,
    },
}

-- ==================== SUPERBOSS: TONATIUH'S AVATAR ====================
F.Super = {
    Name = "TONATIUH'S AVATAR", Color = GOLD,
    Hitbox = { Torso = { Vector3.new(5.6, 8, 3.6), Vector3.new(0, 2.8, 0) }, Core = { Vector3.new(2.6, 2.6, 2.6), Vector3.new(0, 4, -2), "Ball" },
        Head = { Vector3.new(2.8, 3, 2.8), Vector3.new(0, 8.6, 0) } },
    Evade = { Amp = 10, Rate = 1.3, Dodge = 3.8 },
    Body = function(model, Mf, col, H)
        local P, W, Style = H.Part, H.Wedge, H.Style
        Style(model:FindFirstChild("Torso"), JADE, M.Marble)
        Style(model:FindFirstChild("Core"), GOLD, H.NEON)
        Style(model:FindFirstChild("Head"), GOLD, H.METAL)
        -- the sun god's face: gold, turquoise eyes, a tongue of obsidian, ear spools, a great feather crown
        for _, sx in ipairs({ -1, 1 }) do
            P(model, { Name = "Eye", Size = Vector3.new(0.7, 0.3, 0.15), CFrame = Mf(sx * 0.6, 9, -1.45), Color = TURQ, Material = H.NEON })
            P(model, { Name = "EarSpool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.2, 1.2), CFrame = Mf(sx * 1.6, 8.6, 0), Color = TURQ, Material = H.SMOOTH })
        end
        W(model, { Name = "Tongue", Size = Vector3.new(0.6, 1.2, 0.3), CFrame = Mf(0, 7.4, -1.5) * CFrame.Angles(math.pi, 0, 0), Color = C3(30, 30, 36), Material = M.Glass })
        for k = -5, 5 do W(model, { Name = "Deco_Crown", Size = Vector3.new(0.3, 4.4, 1.2), CFrame = Mf(0, 10, 0.6) * CFrame.Angles(0, 0, math.rad(k * 14)) * CFrame.new(0, 2, 0), Color = (k % 2 == 0) and FEATHER or FEATHER2, Material = H.SMOOTH }) end
        -- the sun-stone disc on its back (turns), jade armour bands, gold arm cuffs, a macuahuitl
        local sc = Mf(0, 5, 2.2)
        P(model, { Name = "Deco_Sun", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 8, 8), CFrame = sc * CFrame.Angles(0, math.rad(90), 0), Color = STONE, Material = M.Limestone })
        P(model, { Name = "Deco_Sun", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 5, 5), CFrame = sc * CFrame.Angles(0, math.rad(90), 0), Color = JADE, Material = M.Marble })
        P(model, { Name = "Deco_Sun", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 2.4, 2.4), CFrame = sc * CFrame.Angles(0, math.rad(90), 0), Color = GOLD, Material = H.NEON })
        for i = 0, 11 do P(model, { Name = "Deco_Sun", Size = Vector3.new(0.6, 0.6, 1.0), CFrame = sc * CFrame.Angles(0, 0, i / 12 * math.pi * 2) * CFrame.new(0, 3.3, 0), Color = (i % 2 == 0) and TURQ or TERRA, Material = H.SMOOTH }) end
        for k = 0, 3 do P(model, { Name = "Band", Size = Vector3.new(5.7, 0.4, 3.7), CFrame = Mf(0, 0.2 + k * 1.6, 0), Color = (k % 2 == 0) and GOLD or TERRA, Material = (k % 2 == 0) and H.METAL or H.SMOOTH }) end
        P(model, { Name = "Deco_Club", Size = Vector3.new(0.4, 7, 1.0), CFrame = Mf(3.6, 4, -1) * CFrame.Angles(0, 0, math.rad(-15)), Color = C3(110, 70, 40), Material = M.Wood })
        for k = 0, 4 do P(model, { Name = "Deco_Club", Size = Vector3.new(0.3, 0.6, 0.6), CFrame = Mf(3.6 + 0.9 * math.sin(math.rad(15)) * (k - 2), 4 + (k - 2) * 1.2, -1.6) * CFrame.Angles(0, 0, math.rad(-15)), Color = C3(30, 30, 36), Material = M.Glass }) end
        H.Emit(model:FindFirstChild("Torso") or model.PrimaryPart, GOLD, 5, 0.35, 1.5, 2)
    end,
    Kit = function(H)
        local Mv, EA, Unit, Pose = H.M, H.EA, H.Unit, H.Pose
        local function SolarFlare(B)
            -- the sun-stone flares: a plus of sun lanes on you, then an X, then the centre
            local r = B:Root()
            if not r then return end
            local at = r.Position
            for k, set in ipairs({ { 0, math.rad(90) }, { math.rad(45), math.rad(-45) } }) do
                task.delay((k - 1) * 0.7, function()
                    if not B:Alive() then return end
                    for _, a in ipairs(set) do
                        local d = CFrame.Angles(0, a, 0):VectorToWorldSpace(Vector3.new(0, 0, 1))
                        EA.Line(B.ctx, at - d * 26, at + d * 26, 4, B:W(0.85), { Mult = 1.0, Height = 9 })
                    end
                end)
            end
            task.delay(1.4 + B:W(0.85), function() if B:Alive() then EA.Circle(B.ctx, at, 6, 0.6, { Mult = 1.1 }) end end)
            B:Wait(B:W(0.85) + 2.0)
        end
        local function SerpentCall(B)
            -- feathered serpents rush across the arena in rows through you
            Mv.Roll(B, 2 + B.phase, 6, 50, "Ball", true)
        end
        return {
            Color = GOLD, Move = "Orbit", Range = 32, SpeedMul = 0.9, Recover = { 1.9, 1.6, 1.3 },
            Names = { "TONATIUH'S AVATAR", "TONATIUH'S AVATAR: ZENITH", "TONATIUH'S AVATAR: FIFTH SUN" },
            Moves = {
                { { SolarFlare, "SOLAR FLARE" }, { SerpentCall, "SERPENT CALL" }, { function(B) Mv.Footsteps(B, 7, 6) end, "TEMPLE STEPS" } },
                { { function(B) Mv.Rain(B, 6, 6, 0.85, 0, 0.42) end, "OBSIDIAN RAIN" }, { SolarFlare, "SOLAR FLARE" }, { function(B) Mv.Pincer(B, 12, 0.9, 0.42) end, "JAGUAR'S JAWS" },
                    { SerpentCall, "SERPENT CALL" } },
                { { function(B) Mv.Checker(B, 34, 0.95) end, "CALENDAR STONES" }, { SolarFlare, "SOLAR FLARE" }, { function(B) Mv.Tide(B, 3, true) end, "SUN WAVES" },
                    { function(B) Mv.ArenaWipe(B, 2, 8, 1.5) end, "FIFTH SUN" } },
            },
            Animate = function(B, pivot, now)
                Pose(B, "Deco_Sun", pivot, CFrame.new(0, 5, 2.2), CFrame.Angles(0, 0, now * 0.35))
                Pose(B, "Deco_Crown", pivot, CFrame.new(0, 10, 0.6), CFrame.Angles(math.sin(now * 1.2) * 0.04, 0, 0))
                Pose(B, "Deco_Club", pivot, CFrame.new(3.6, 4, -1), CFrame.Angles(math.sin(now * 1.0) * 0.1, 0, 0))
            end,
        }
    end,
}
return F
