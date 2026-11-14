--!nocheck
-- MOONLIT SPIRES foes (0.89): the night things of a gothic city. Superboss COUNT NOCTIS.
local C3 = Color3.fromRGB
local M = Enum.Material
local STONE, STONE2, BLACK, BLOOD, LAMP, BONE = C3(110, 110, 122), C3(84, 84, 96), C3(24, 22, 30), C3(200, 30, 50), C3(255, 196, 120), C3(226, 220, 204)

local F = {}
F.Specialist = "Bishop"
F.Enemies = {
    {
        Name = "Gargoyle", Hard = true,
        Def = { Label = "Gargoyle", Hp = 95, Dmg = 10, Speed = 17, Body = 2.0, Head = 1.2, Color = C3(150, 150, 170), Range = { 20, 32 }, Fire = 2.8, Pattern = "Flap" },
        Lore = { Role = "Spire diver", Text = "A stone gargoyle torn off a cathedral roof. It wheels overhead, then dives a lane straight through you.", Tip = "Strafe across the dive." },
        Attack = { Shape = "Lane", Width = 4.6, Past = 18, W = 0.85, Mult = 1.0 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for _, sx in ipairs({ -1, 1 }) do
                W(model, { Name = "Wing", Size = Vector3.new(0.18, R * 1.5, R * 2.4), CFrame = base * CFrame.new(sx * R * 1.5, R * 0.3, R * 0.3) * CFrame.Angles(0, 0, math.rad(sx * 78)), Color = STONE2, Material = M.Slate })
                W(model, { Name = "Horn", Size = Vector3.new(0.2, R * 0.8, R * 0.4), CFrame = base * CFrame.new(sx * R * 0.5, R * 1.25, -R * 0.2) * CFrame.Angles(math.rad(-25), 0, math.rad(sx * -20)), Color = BONE, Material = M.SmoothPlastic })
                P(model, { Name = "EyeSpot", Size = Vector3.new(R * 0.32, R * 0.16, 0.1), CFrame = base * CFrame.new(sx * R * 0.32, R * 0.35, -R * 1.02), Color = C3(255, 80, 60), Glow = true })
            end
            P(model, { Name = "Snout", Size = Vector3.new(R * 0.9, R * 0.6, R * 0.6), CFrame = base * CFrame.new(0, -R * 0.05, -R * 1.05), Color = STONE, Material = M.Slate })
            W(model, { Name = "Jaw", Size = Vector3.new(R * 0.8, R * 0.25, R * 0.5), CFrame = base * CFrame.new(0, -R * 0.45, -R * 1.05) * CFrame.Angles(math.pi, 0, 0), Color = STONE2, Material = M.Slate })
            W(model, { Name = "TailFin", Size = Vector3.new(0.15, R * 0.8, R * 1.4), CFrame = base * CFrame.new(0, -R * 0.4, R * 1.3) * CFrame.Angles(math.rad(-30), 0, 0), Color = STONE2, Material = M.Slate })
        end,
    },
    {
        Name = "LanternWraith", Weight = 2,
        Def = { Label = "Lantern Wraith", Hp = 90, Dmg = 9, Speed = 15, Body = 2.0, Head = 1.2, Color = C3(170, 180, 220), Range = { 24, 38 }, Fire = 3.0, Pattern = "Pendulum" },
        Lore = { Role = "Spire wanderer", Text = "A hooded shade swinging a gas lantern. It drops the lantern on you, then the flames spread wider on the same spot.", Tip = "Leave the spot and don't come back." },
        Attack = { Shape = "Echo", R = 4, Delay = 0.7, W = 0.75, Mult = 0.8 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            W(model, { Name = "Hood", Size = Vector3.new(R * 1.8, R * 1.6, R * 1.6), CFrame = base * CFrame.new(0, R * 0.6, R * 0.2), Color = C3(40, 40, 54), Material = M.SmoothPlastic })
            for i = 0, 7 do
                local a = i / 8 * math.pi * 2
                P(model, { Name = "Tendril", Size = Vector3.new(R * 0.5, R * (1.4 + (i % 3) * 0.4), 0.12), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, -R * 1.1, R * 0.85), Color = C3(54, 54, 70), Material = M.SmoothPlastic, Transparency = 0.15 })
            end
            P(model, { Name = "Chain", Size = Vector3.new(0.1, R * 1.0, 0.1), CFrame = base * CFrame.new(R * 0.9, -R * 0.7, -R * 0.6), Color = C3(60, 60, 64), Material = M.Metal })
            P(model, { Name = "Glow", Size = Vector3.new(R * 0.5, R * 0.7, R * 0.5), CFrame = base * CFrame.new(R * 0.9, -R * 1.4, -R * 0.6), Color = LAMP, Glow = true })
            for _, sx in ipairs({ -1, 1 }) do P(model, { Name = "EyeSpot", Size = Vector3.new(R * 0.22, R * 0.12, 0.1), CFrame = base * CFrame.new(sx * R * 0.28, R * 0.35, -R * 1.0), Color = C3(170, 220, 255), Glow = true }) end
        end,
    },
    {
        Name = "Raven", Hard = true,
        Def = { Label = "Raven", Hp = 65, Dmg = 8, Speed = 22, Body = 1.6, Head = 1.0, Color = C3(60, 60, 80), Range = { 20, 32 }, Fire = 2.4, Pattern = "Zigzag" },
        Lore = { Role = "Spire scout", Text = "A huge black raven that zigzags through the air. Rakes a row of claw marks along its line to you.", Tip = "Sidestep the row." },
        Attack = { Shape = "Row", N = 4, R = 3, Gap = 4.6, W = 0.75, Mult = 0.7 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for _, sx in ipairs({ -1, 1 }) do
                for f = 0, 2 do
                    W(model, { Name = "Feather", Size = Vector3.new(0.1, R * 0.7, R * (1.9 - f * 0.4)), CFrame = base * CFrame.new(sx * R * (1.1 + f * 0.45), R * 0.1 - f * R * 0.15, R * 0.2) * CFrame.Angles(0, 0, math.rad(sx * 82)), Color = BLACK, Material = M.SmoothPlastic })
                end
                P(model, { Name = "EyeSpot", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.22, CFrame = base * CFrame.new(sx * R * 0.4, R * 0.3, -R * 0.8), Color = BLOOD, Glow = true })
            end
            W(model, { Name = "Beak", Size = Vector3.new(R * 0.3, R * 0.3, R * 1.0), CFrame = base * CFrame.new(0, R * 0.05, -R * 1.35) * CFrame.Angles(0, math.pi, 0), Color = C3(40, 40, 40), Material = M.SmoothPlastic })
            for k = -1, 1 do W(model, { Name = "TailFin", Size = Vector3.new(0.1, R * 0.4, R * 1.1), CFrame = base * CFrame.new(k * R * 0.25, 0, R * 1.3) * CFrame.Angles(0, k * 0.3, 0), Color = BLACK, Material = M.SmoothPlastic }) end
        end,
    },
    {
        Name = "GraveHound", Weight = 2,
        Def = { Label = "Grave Hound", Hp = 130, Dmg = 11, Speed = 16, Body = 2.2, Head = 1.3, Color = C3(200, 190, 170), Range = { 16, 28 }, Fire = 2.8, Pattern = "Stutter", Ground = true },
        Lore = { Role = "Spire hound", Text = "A skeletal hound that freezes mid-stride, then lunges on. Howls a cone of grave-cold at you.", Tip = "Free shots while it freezes; get out of the cone." },
        Attack = { Shape = "Cone", Half = 22, Past = 12, W = 0.85, Mult = 0.9 },
        Decor = function(model, H)
            local P, W, body, base, hc, head = H.Part, H.Wedge, H.body, H.base, H.headCF, H.head
            for k = 0, 3 do
                P(model, { Name = "Rib", Size = Vector3.new(body.X * 1.05, 0.2, body.Z * 1.05), CFrame = base * CFrame.new(0, body.Y * (0.25 - k * 0.18), 0), Color = BONE, Material = M.SmoothPlastic })
            end
            for k = 0, 3 do W(model, { Name = "Spine", Size = Vector3.new(0.2, body.Y * 0.3, body.Z * 0.3), CFrame = base * CFrame.new(0, body.Y * (0.5 - k * 0.2), body.Z * 0.5) * CFrame.Angles(math.rad(-30), 0, 0), Color = BONE, Material = M.SmoothPlastic }) end
            W(model, { Name = "Jaw", Size = Vector3.new(head.X * 0.9, head.Y * 0.35, head.Z * 0.9), CFrame = hc * CFrame.new(0, -head.Y * 0.55, -head.Z * 0.2) * CFrame.Angles(math.pi, 0, 0), Color = BONE, Material = M.SmoothPlastic })
            for _, sx in ipairs({ -1, 1 }) do
                P(model, { Name = "FrostEye", Size = Vector3.new(head.X * 0.22, head.Y * 0.14, 0.1), CFrame = hc * CFrame.new(sx * head.X * 0.25, head.Y * 0.15, -head.Z * 0.52), Color = C3(120, 220, 255), Glow = true })
                W(model, { Name = "Ear", Size = Vector3.new(0.15, head.Y * 0.6, head.Z * 0.4), CFrame = hc * CFrame.new(sx * head.X * 0.35, head.Y * 0.7, head.Z * 0.1), Color = C3(170, 160, 140), Material = M.SmoothPlastic })
            end
            H.Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "smoke_main.dds", C3(120, 200, 230), 3, 1.2, 0.6, 1.2, Enum.NormalId.Bottom, 40, 0.2)
        end,
    },
    {
        Name = "BellSpirit",
        Def = { Label = "Bell Spirit", Hp = 90, Dmg = 10, Speed = 14, Body = 2.0, Head = 1.2, Color = C3(220, 190, 110), Range = { 24, 36 }, Fire = 3.0, Pattern = "Constellation" },
        Lore = { Role = "Spire toller", Text = "A haunted church bell hopping between the same points in order. Its toll lands four strikes round you, then one on you.", Tip = "Learn its stops; leave the box before the last strike." },
        Attack = { Shape = "Box", Gap = 5, R = 3.6, W = 0.8, Mult = 0.7 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Bell", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 1.6, R * 2.3, R * 2.3), CFrame = base * CFrame.new(0, -R * 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = C3(170, 130, 60), Material = M.Metal })
            P(model, { Name = "Lip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 0.3, R * 2.6, R * 2.6), CFrame = base * CFrame.new(0, -R * 1.0, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = C3(200, 160, 80), Material = M.Metal })
            P(model, { Name = "Crown", Size = Vector3.new(R * 0.5, R * 0.6, R * 0.5), CFrame = base * CFrame.new(0, R * 0.9, 0), Color = C3(120, 90, 40), Material = M.Metal })
            P(model, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.6, CFrame = base * CFrame.new(0, -R * 1.25, 0), Color = LAMP, Glow = true })
            H.Ring(model, base * CFrame.new(0, R * 0.2, 0), R * 3.0, 0.12, C3(255, 210, 140), true)
        end,
    },
    {
        Name = "Bishop",
        Def = { Label = "Bishop", Hp = 185, Dmg = 9, Speed = 9, Body = 2.8, Head = 1.4, Color = C3(200, 40, 60), Range = { 30, 44 }, Fire = 3.8, Pattern = "SlowStrafe" },
        Lore = { Role = "Spire suppressor", Text = "A floating bishop in crimson with a tall mitre, swinging a censer. Blesses a cross of light over you, then its heart.", Tip = "Leave the cross, then the middle." },
        Attack = { Shape = "Sunburst", W = 0.95, Mult = 0.9 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for _, sz in ipairs({ -1, 1 }) do
                W(model, { Name = "Mitre", Size = Vector3.new(R * 1.2, R * 1.6, R * 0.6), CFrame = base * CFrame.new(0, R * 1.9, sz * R * 0.3) * CFrame.Angles(0, (sz < 0) and 0 or math.pi, 0), Color = C3(240, 230, 210), Material = M.SmoothPlastic })
            end
            P(model, { Name = "MitreBand", Size = Vector3.new(R * 1.25, R * 0.2, R * 1.25), CFrame = base * CFrame.new(0, R * 1.2, 0), Color = C3(230, 180, 70), Material = M.Metal })
            for i = 0, 9 do
                local a = i / 10 * math.pi * 2
                P(model, { Name = "Robe", Size = Vector3.new(R * 0.6, R * 2.2, 0.15), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, -R * 1.1, R * 1.0) * CFrame.Angles(math.rad(-10), 0, 0), Color = (i % 2 == 0) and BLOOD or C3(150, 20, 40), Material = M.SmoothPlastic })
            end
            P(model, { Name = "Chain", Size = Vector3.new(0.1, R * 1.2, 0.1), CFrame = base * CFrame.new(-R * 1.2, -R * 0.4, -R * 0.6), Color = C3(200, 170, 80), Material = M.Metal })
            P(model, { Name = "PodGlow", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.6, CFrame = base * CFrame.new(-R * 1.2, -R * 1.1, -R * 0.6), Color = LAMP, Glow = true })
            P(model, { Name = "LightStrip", Size = Vector3.new(R * 0.2, R * 1.2, 0.1), CFrame = base * CFrame.new(0, 0, -R * 1.02), Color = C3(255, 220, 140), Glow = true })
            P(model, { Name = "LightStrip", Size = Vector3.new(R * 0.8, R * 0.2, 0.1), CFrame = base * CFrame.new(0, R * 0.25, -R * 1.02), Color = C3(255, 220, 140), Glow = true })
            H.Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "smoke_main.dds", C3(200, 190, 220), 2, 1.0, 0.8, 1.6, Enum.NormalId.Top, 30, 0.1)
        end,
    },
}

-- ==================== SUPERBOSS: COUNT NOCTIS ====================
F.Super = {
    Name = "COUNT NOCTIS", Color = BLOOD,
    Hitbox = { Torso = { Vector3.new(5, 8, 3.4), Vector3.new(0, 3, 0) }, Core = { Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 4.4, -1.9), "Ball" },
        Head = { Vector3.new(2.6, 2.8, 2.6), Vector3.new(0, 8.6, 0) } },
    Evade = { Amp = 11, Rate = 1.5, Dodge = 3.4 },
    Body = function(model, Mf, col, H)
        local P, W, Style = H.Part, H.Wedge, H.Style
        Style(model:FindFirstChild("Torso"), C3(30, 26, 40), H.SMOOTH)
        Style(model:FindFirstChild("Core"), BLOOD, H.NEON)
        Style(model:FindFirstChild("Head"), C3(220, 214, 226), H.SMOOTH)
        -- the face: pale, slicked hair, red eyes, a high collar
        P(model, { Name = "Hair", Shape = Enum.PartType.Ball, Size = Vector3.new(2.8, 1.4, 2.8), CFrame = Mf(0, 9.7, 0.2), Color = C3(20, 18, 26), Material = H.SMOOTH })
        W(model, { Name = "Peak", Size = Vector3.new(0.6, 0.8, 0.6), CFrame = Mf(0, 9.6, -1.3) * CFrame.Angles(math.pi, 0, 0), Color = C3(20, 18, 26), Material = H.SMOOTH })
        for _, sx in ipairs({ -1, 1 }) do
            P(model, { Name = "Eye", Size = Vector3.new(0.6, 0.22, 0.15), CFrame = Mf(sx * 0.55, 8.8, -1.32), Color = BLOOD, Glow = true })
            W(model, { Name = "Collar", Size = Vector3.new(0.3, 3.4, 2.4), CFrame = Mf(sx * 1.6, 8, 0.5) * CFrame.Angles(0, sx * math.rad(30), 0), Color = BLOOD, Material = H.SMOOTH })
        end
        -- the coat: a waistcoat, a cape that sways, bat wings that flap from the shoulders
        P(model, { Name = "Vest", Size = Vector3.new(3.4, 4.2, 0.3), CFrame = Mf(0, 4.2, -1.75), Color = C3(80, 10, 24), Material = H.SMOOTH })
        for k = 0, 3 do P(model, { Name = "Button", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35, CFrame = Mf(0, 5.6 - k * 0.9, -1.92), Color = C3(230, 190, 90), Material = H.METAL }) end
        for i = 0, 8 do
            local a = (i - 4) * 0.22
            P(model, { Name = "Deco_Cape", Size = Vector3.new(1.2, 9, 0.2), CFrame = Mf(math.sin(a) * 3, 1.5, 1.6 + math.cos(a) * 0.6) * CFrame.Angles(0, a, 0), Color = (i % 2 == 0) and C3(24, 20, 30) or C3(110, 14, 30), Material = H.SMOOTH })
        end
        for _, sx in ipairs({ -1, 1 }) do
            local nm = (sx < 0) and "Deco_WingL" or "Deco_WingR"
            for f = 0, 3 do
                W(model, { Name = nm, Size = Vector3.new(0.2, 3.6 - f * 0.5, 4.2 - f * 0.4), CFrame = Mf(sx * (3 + f * 1.4), 7.2 - f * 0.5, 1.2) * CFrame.Angles(0, 0, sx * math.rad(70 - f * 8)), Color = C3(36, 26, 44), Material = H.SMOOTH })
            end
            W(model, { Name = nm, Size = Vector3.new(0.25, 1.6, 0.6), CFrame = Mf(sx * 7.6, 9, 1.2), Color = BONE, Material = H.SMOOTH })
        end
        -- bats circling him
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2
            W(model, { Name = "Deco_Bat", Size = Vector3.new(1.4, 0.2, 0.8), CFrame = Mf(math.cos(a) * 7, 6 + (i % 2) * 2, math.sin(a) * 7), Color = BLACK, Material = H.SMOOTH })
        end
        H.Emit(model:FindFirstChild("Torso") or model.PrimaryPart, BLOOD, 4, 0.3, 1.2, 1.8)
    end,
    Kit = function(H)
        local Mv, EA, Unit, Pose = H.M, H.EA, H.Unit, H.Pose
        local function BatSwarm(B)
            -- bats strike where you are, five times in quick succession: keep moving
            for _ = 1, 4 + B.phase do
                local r = B:Root()
                if not r or not B:Alive() then return end
                EA.Circle(B.ctx, r.Position, 4, B:W(0.6), { Mult = 0.8 })
                B:Wait(0.42)
            end
            B:Wait(B:W(0.6) + 0.4)
        end
        local function CrimsonCross(B)
            -- a blood cross falls on you: an X, then a + a beat later
            local r = B:Root()
            if not r then return end
            local at = r.Position
            for k, angles in ipairs({ { math.rad(45), math.rad(-45) }, { 0, math.rad(90) } }) do
                task.delay((k - 1) * 0.9, function()
                    if not B:Alive() then return end
                    for _, a in ipairs(angles) do
                        local d = CFrame.Angles(0, a, 0):VectorToWorldSpace(Vector3.new(0, 0, 1))
                        EA.Line(B.ctx, at - d * 26, at + d * 26, 4.5, B:W(0.85), { Mult = 1.1, Height = 9 })
                    end
                end)
            end
            B:Wait(B:W(0.85) + 1.4)
        end
        return {
            Color = BLOOD, Move = "Orbit", Range = 30, SpeedMul = 1.0, Recover = { 1.9, 1.6, 1.3 },
            Names = { "COUNT NOCTIS", "COUNT NOCTIS: BLOOD MOON", "COUNT NOCTIS: ETERNAL NIGHT" },
            Moves = {
                { { BatSwarm, "BAT SWARM" }, { CrimsonCross, "CRIMSON CROSS" }, { function(B) Mv.Rain(B, 6, 6, 0.85, 0, 0.42) end, "BLOOD RAIN" } },
                { { function(B) Mv.Cage(B, 8, 12, 1.0) end, "GRAVE GATES" }, { BatSwarm, "BAT SWARM" }, { function(B) Mv.Carpet(B, 5, 4, 6, 0.75, 0.2) end, "CHANDELIER FALL" },
                    { CrimsonCross, "CRIMSON CROSS" } },
                { { function(B) Mv.InOut(B, 13, 44, true, 1.0) end, "THE TOLLING" }, { BatSwarm, "BAT SWARM" }, { function(B) Mv.Crossfire(B, 2, 6, 0.9) end, "CROSSED BLADES" },
                    { function(B) Mv.ArenaWipe(B, 2, 8, 1.5) end, "NIGHTFALL" } },
            },
            Animate = function(B, pivot, now)
                local f = math.sin(now * 3.2) * 0.25
                Pose(B, "Deco_WingL", pivot, CFrame.new(-2.6, 7.2, 1.2), CFrame.Angles(0, f, -f))
                Pose(B, "Deco_WingR", pivot, CFrame.new(2.6, 7.2, 1.2), CFrame.Angles(0, -f, f))
                Pose(B, "Deco_Cape", pivot, CFrame.new(0, 6, 1.6), CFrame.Angles(math.sin(now * 1.4) * 0.07, 0, math.cos(now * 1.1) * 0.04))
                Pose(B, "Deco_Bat", pivot, CFrame.new(0, 6, 0), CFrame.Angles(0, now * 0.9, 0))
            end,
        }
    end,
}
return F
