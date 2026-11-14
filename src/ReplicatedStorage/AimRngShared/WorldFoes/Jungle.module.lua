--!nocheck
-- SUNKEN TEMPLE foes (0.89): vines, idols and poison of a temple the jungle swallowed. Superboss THE IDOL KING.
local C3 = Color3.fromRGB
local M = Enum.Material
local STONE, STONE2, MOSS, GOLD, VINE, LEAF = C3(122, 128, 108), C3(96, 104, 88), C3(74, 112, 52), C3(240, 190, 80), C3(56, 96, 40), C3(88, 140, 56)

local F = {}
F.Specialist = "TempleGuardian"
F.Enemies = {
    {
        Name = "Vinelash", Hard = true, Weight = 2,
        Def = { Label = "Vinelash", Hp = 85, Dmg = 9, Speed = 18, Body = 1.9, Head = 1.15, Color = C3(110, 200, 90), Range = { 22, 36 }, Fire = 2.6, Pattern = "Serpent" },
        Lore = { Role = "Temple serpent", Text = "A living vine that weaves through the air like a snake. It whips a row of thorns along its line to you.", Tip = "Step sideways off the row." },
        Attack = { Shape = "Row", N = 5, R = 3, Gap = 4.2, W = 0.8, Mult = 0.7 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            for k = 1, 5 do
                local sz = R * (1.3 - k * 0.16)
                P(model, { Name = "TailSegment", Shape = Enum.PartType.Ball, Size = Vector3.one * sz, CFrame = base * CFrame.new(math.sin(k * 0.9) * R * 0.4, -R * 0.1 * k, R * (0.6 + k * 0.8)),
                    Color = (k % 2 == 0) and VINE or C3(80, 130, 52), Material = M.Grass })
                if k % 2 == 1 then
                    for _, sx in ipairs({ -1, 1 }) do
                        H.Wedge(model, { Name = "Fin", Size = Vector3.new(0.12, sz * 0.6, sz * 1.1), CFrame = base * CFrame.new(sx * sz * 0.6, -R * 0.1 * k, R * (0.6 + k * 0.8)) * CFrame.Angles(0, 0, sx * math.rad(60)), Color = LEAF, Material = M.Grass })
                    end
                end
            end
            for k = -1, 1 do
                H.Wedge(model, { Name = "Thorn", Size = Vector3.new(0.18, R * 0.5, R * 0.4), CFrame = base * CFrame.new(0, R * 0.95, R * (k * 0.35)) * CFrame.Angles(math.rad(-20), 0, 0), Color = C3(150, 120, 70), Material = M.Wood })
            end
            P(model, { Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.5, CFrame = base * CFrame.new(R * 0.7, R * 0.6, -R * 0.2), Color = C3(255, 110, 150), Glow = true })
        end,
    },
    {
        Name = "Idolfly", Hard = true,
        Def = { Label = "Idolfly", Hp = 80, Dmg = 10, Speed = 18, Body = 1.9, Head = 1.2, Color = GOLD, Range = { 24, 38 }, Fire = 2.8, Pattern = "Flap" },
        Lore = { Role = "Temple watcher", Text = "A stone idol mask on feathered wings. Its gold eyes cross two beams over you.", Tip = "Step out of the X, not along it." },
        Attack = { Shape = "Cross", L = 20, Width = 3.4, W = 0.85, Mult = 0.8 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Mask", Size = Vector3.new(R * 1.6, R * 1.8, 0.3), CFrame = base * CFrame.new(0, R * 0.1, -R * 1.0), Color = STONE, Material = M.Limestone })
            P(model, { Name = "Brow", Size = Vector3.new(R * 1.8, R * 0.3, 0.5), CFrame = base * CFrame.new(0, R * 0.6, -R * 1.1), Color = STONE2, Material = M.Limestone })
            for _, sx in ipairs({ -1, 1 }) do
                P(model, { Name = "EyeSpot", Size = Vector3.new(R * 0.4, R * 0.2, 0.1), CFrame = base * CFrame.new(sx * R * 0.38, R * 0.3, -R * 1.18), Color = GOLD, Glow = true })
                for f = 0, 2 do
                    H.Wedge(model, { Name = "Wing", Size = Vector3.new(0.12, R * (1.2 - f * 0.2), R * (2.0 - f * 0.3)), CFrame = base * CFrame.new(sx * R * (1.2 + f * 0.2), R * (0.2 - f * 0.35), R * 0.2) * CFrame.Angles(0, 0, math.rad(sx * (80 - f * 12))),
                        Color = (f == 1) and C3(220, 70, 60) or C3(40, 150, 110), Material = M.SmoothPlastic })
                end
            end
            for k = -2, 2 do
                H.Wedge(model, { Name = "Plume", Size = Vector3.new(0.12, R * 1.0, R * 0.5), CFrame = base * CFrame.new(k * R * 0.32, R * 1.3, -R * 0.6) * CFrame.Angles(0, 0, math.rad(k * -14)), Color = (k % 2 == 0) and GOLD or C3(40, 150, 110), Material = M.SmoothPlastic })
            end
        end,
    },
    {
        Name = "DartFrog", Weight = 2,
        Def = { Label = "Dart Frog", Hp = 110, Dmg = 11, Speed = 16, Body = 2.2, Head = 1.3, Color = C3(50, 140, 255), Range = { 18, 30 }, Fire = 2.8, Pattern = "Leap", Ground = true },
        Lore = { Role = "Temple leaper", Text = "A poison frog the size of a dog, bright blue with orange warning spots. Spits a burst that leaves a poison puddle.", Tip = "Don't stand where it landed." },
        Attack = { Shape = "Puddle", R = 4.2, W = 0.8, Mult = 0.8, Life = 2.6 },
        Decor = function(model, H)
            local P, head, hc, body, base = H.Part, H.head, H.headCF, H.body, H.base
            for _, sx in ipairs({ -1, 1 }) do
                P(model, { Name = "BulgeEye", Shape = Enum.PartType.Ball, Size = Vector3.one * head.X * 0.5, CFrame = hc * CFrame.new(sx * head.X * 0.36, head.Y * 0.45, -head.Z * 0.1), Color = C3(20, 20, 24), Material = M.SmoothPlastic })
                P(model, { Name = "Pupil", Shape = Enum.PartType.Ball, Size = Vector3.one * head.X * 0.22, CFrame = hc * CFrame.new(sx * head.X * 0.36, head.Y * 0.5, -head.Z * 0.32), Color = C3(255, 200, 60), Glow = true })
            end
            P(model, { Name = "Lip", Size = Vector3.new(head.X * 1.05, head.Y * 0.1, 0.12), CFrame = hc * CFrame.new(0, -head.Y * 0.2, -head.Z * 0.52), Color = C3(20, 30, 60), Material = M.SmoothPlastic })
            for i, o in ipairs({ { -0.3, 0.2 }, { 0.32, -0.1 }, { 0.05, 0.35 }, { -0.2, -0.3 }, { 0.3, 0.3 } }) do
                P(model, { Name = "Spot", Shape = Enum.PartType.Ball, Size = Vector3.new(body.X * 0.26, body.X * 0.26, 0.2), CFrame = base * CFrame.new(body.X * o[1], body.Y * o[2], -body.Z / 2 - 0.05), Color = C3(255, 150, 40), Material = M.SmoothPlastic })
            end
            H.Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "sparkles_main.dds", C3(150, 255, 120), 3, 0.25, 0.6, 0.8, Enum.NormalId.Bottom, 40)
        end,
    },
    {
        Name = "PollenMoth",
        Def = { Label = "Pollen Moth", Hp = 75, Dmg = 8, Speed = 15, Body = 1.8, Head = 1.1, Color = C3(240, 210, 120), Range = { 24, 38 }, Fire = 2.8, Pattern = "Leaf" },
        Lore = { Role = "Temple drifter", Text = "A huge furry moth that drifts down like a falling leaf. Its pollen clouds follow you: three in a row.", Tip = "Keep moving: each lands where you were." },
        Attack = { Shape = "Chase", N = 3, R = 3.4, W = 0.6, Gap = 0.55, Mult = 0.6 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            for _, sx in ipairs({ -1, 1 }) do
                for k, y in ipairs({ 0.35, -0.45 }) do
                    P(model, { Name = "MothWing", Size = Vector3.new(0.1, R * (k == 1 and 1.6 or 1.1), R * (k == 1 and 1.9 or 1.4)), CFrame = base * CFrame.new(sx * R * 1.35, R * y, R * 0.1) * CFrame.Angles(0, 0, math.rad(sx * 75)),
                        Color = (k == 1) and C3(236, 200, 110) or C3(200, 150, 90), Material = M.SmoothPlastic })
                    P(model, { Name = "WingEye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.12, R * 0.4, R * 0.4), CFrame = base * CFrame.new(sx * R * 1.5, R * y, R * 0.1) * CFrame.Angles(0, 0, math.rad(sx * 75)), Color = C3(120, 60, 160), Material = M.SmoothPlastic })
                end
                H.Wedge(model, { Name = "Antenna", Size = Vector3.new(0.08, R * 0.9, R * 0.3), CFrame = base * CFrame.new(sx * R * 0.25, R * 1.2, -R * 0.6) * CFrame.Angles(math.rad(-30), 0, math.rad(sx * -20)), Color = C3(120, 90, 50), Material = M.SmoothPlastic })
            end
            H.Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "sparkles_main.dds", C3(255, 230, 140), 6, 0.25, 0.8, 1.2, Enum.NormalId.Bottom, 60)
        end,
    },
    {
        Name = "TotemImp",
        Def = { Label = "Totem Imp", Hp = 80, Dmg = 9, Speed = 18, Body = 1.8, Head = 1.15, Color = C3(210, 90, 60), Range = { 22, 34 }, Fire = 2.6, Pattern = "Pasu" },
        Lore = { Role = "Temple trickster", Text = "A little carved totem with a feather crown that darts about. Blows a dart straight through you.", Tip = "Strafe across its line." },
        Attack = { Shape = "Lane", Width = 3.6, W = 0.8, Mult = 0.9 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "TotemFace", Size = Vector3.new(R * 1.5, R * 1.7, 0.4), CFrame = base * CFrame.new(0, 0, -R * 0.95), Color = C3(130, 80, 50), Material = M.Wood })
            P(model, { Name = "Mouth", Size = Vector3.new(R * 0.9, R * 0.2, 0.1), CFrame = base * CFrame.new(0, -R * 0.4, -R * 1.18), Color = C3(255, 120, 60), Glow = true })
            for _, sx in ipairs({ -1, 1 }) do
                H.Wedge(model, { Name = "Tusk", Size = Vector3.new(0.15, R * 0.5, R * 0.25), CFrame = base * CFrame.new(sx * R * 0.4, -R * 0.75, -R * 1.15) * CFrame.Angles(math.rad(180), 0, 0), Color = C3(240, 230, 210), Material = M.SmoothPlastic })
            end
            for k = -3, 3 do
                H.Wedge(model, { Name = "Plume", Size = Vector3.new(0.1, R * 1.1, R * 0.4), CFrame = base * CFrame.new(k * R * 0.25, R * 1.4, R * 0.1) * CFrame.Angles(0, 0, math.rad(k * -16)), Color = (k % 2 == 0) and C3(230, 60, 50) or GOLD, Material = M.SmoothPlastic })
            end
        end,
    },
    {
        Name = "TempleGuardian",
        Def = { Label = "Temple Guardian", Hp = 180, Dmg = 9, Speed = 9, Body = 2.8, Head = 1.4, Color = C3(150, 160, 130), Range = { 30, 44 }, Fire = 3.8, Pattern = "SlowStrafe" },
        Lore = { Role = "Temple suppressor", Text = "A floating shell of carved temple stone, moss on its shoulders. Raises a lattice of vines round you: one gap is safe.", Tip = "Find the gap before it fills." },
        Attack = { Shape = "Lattice", W = 1.0, Mult = 0.9 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            for k = 0, 3 do
                local a = k * math.pi / 2
                P(model, { Name = "StonePlate", Size = Vector3.new(R * 1.3, R * 1.6, 0.5), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -R * 1.0), Color = (k % 2 == 0) and STONE or STONE2, Material = M.Limestone })
                P(model, { Name = "Glyph", Size = Vector3.new(R * 0.6, 0.15, 0.1), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, R * 0.2, -R * 1.28), Color = GOLD, Glow = true })
            end
            P(model, { Name = "MossCap", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 2.4, R * 0.8, R * 2.4), CFrame = base * CFrame.new(0, R * 0.95, 0), Color = MOSS, Material = M.Grass })
            for i = 0, 5 do
                local a = i / 6 * math.pi * 2
                P(model, { Name = "Tendril", Size = Vector3.new(0.15, R * (1.4 + (i % 2) * 0.6), 0.15), CFrame = base * CFrame.new(math.cos(a) * R * 1.05, -R * 1.3, math.sin(a) * R * 1.05), Color = VINE, Material = M.Grass })
            end
        end,
    },
}

-- ==================== SUPERBOSS: THE IDOL KING ====================
F.Super = {
    Name = "THE IDOL KING", Color = GOLD,
    Hitbox = { Torso = { Vector3.new(6, 8, 4), Vector3.new(0, 2, 0) }, Core = { Vector3.new(2.6, 2.6, 2.6), Vector3.new(0, 3, -2.2), "Ball" },
        Head = { Vector3.new(3.2, 3.4, 3.2), Vector3.new(0, 8.4, 0) } },
    Evade = { Amp = 10, Rate = 1.3, Dodge = 3.8 },
    Body = function(model, Mf, col, H)
        local P, W, Style = H.Part, H.Wedge, H.Style
        Style(model:FindFirstChild("Torso"), STONE, M.Limestone)
        Style(model:FindFirstChild("Core"), GOLD, H.NEON)
        Style(model:FindFirstChild("Head"), STONE, M.Limestone)
        -- the carved face: a heavy brow, gold eyes, a square jaw, ear plugs
        P(model, { Name = "Brow", Size = Vector3.new(3.8, 0.8, 1.2), CFrame = Mf(0, 9.4, -1.4), Color = STONE2, Material = M.Limestone })
        for _, sx in ipairs({ -1, 1 }) do
            P(model, { Name = "Eye", Size = Vector3.new(0.9, 0.45, 0.2), CFrame = Mf(sx * 0.75, 8.8, -1.66), Color = GOLD, Glow = true })
            P(model, { Name = "EarPlug", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.4, 1.4), CFrame = Mf(sx * 1.8, 8.2, 0), Color = GOLD, Material = H.METAL })
        end
        P(model, { Name = "Jaw", Size = Vector3.new(2.8, 0.9, 1.4), CFrame = Mf(0, 7, -1.2), Color = STONE2, Material = M.Limestone })
        P(model, { Name = "Mouth", Size = Vector3.new(2, 0.3, 0.2), CFrame = Mf(0, 7.4, -1.96), Color = C3(30, 30, 24), Material = H.SMOOTH })
        -- the feather crown (turns slowly), a gold collar, moss slumped over the shoulders
        for i = 0, 8 do
            local a = (i - 4) * 0.2
            W(model, { Name = "Deco_Crown", Size = Vector3.new(0.3, 3.2, 1.2), CFrame = Mf(0, 11.4, 0) * CFrame.Angles(0, 0, a) * CFrame.new(0, 1.2, 0.6),
                Color = (i % 2 == 0) and C3(40, 150, 110) or C3(220, 70, 60), Material = H.SMOOTH })
        end
        P(model, { Name = "Collar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 6.4, 6.4), CFrame = Mf(0, 6.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = H.METAL })
        for _, sx in ipairs({ -1, 1 }) do
            P(model, { Name = "MossShoulder", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 1.6, 3.4), CFrame = Mf(sx * 3.2, 5.6, 0), Color = MOSS, Material = M.Grass })
            -- floating stone hands (Deco_HandL / R bob and drift)
            local nm = (sx < 0) and "Deco_HandL" or "Deco_HandR"
            P(model, { Name = nm, Size = Vector3.new(2.2, 2.6, 1.4), CFrame = Mf(sx * 5.4, 2.4, -1.4), Color = STONE, Material = M.Limestone })
            P(model, { Name = nm .. "Band", Size = Vector3.new(2.3, 0.4, 1.5), CFrame = Mf(sx * 5.4, 1.4, -1.4), Color = GOLD, Material = H.METAL })
        end
        -- carved glyph bands on the body, vines hanging to the ground
        for k = 0, 2 do P(model, { Name = "Glyph", Size = Vector3.new(6.1, 0.3, 4.1), CFrame = Mf(0, -0.6 + k * 2.2, 0), Color = (k == 1) and GOLD or STONE2, Material = (k == 1) and H.METAL or M.Limestone }) end
        for i = 0, 7 do
            local a = i / 8 * math.pi * 2
            P(model, { Name = "Deco_Vine", Size = Vector3.new(0.3, 5 + (i % 3), 0.3), CFrame = Mf(math.cos(a) * 3.2, -3.5, math.sin(a) * 2.2), Color = VINE, Material = M.Grass })
        end
        H.Emit(model:FindFirstChild("Torso") or model.PrimaryPart, C3(255, 230, 140), 5, 0.35, 1.5, 2)
    end,
    Kit = function(H)
        local Mv, EA, Unit, Pose = H.M, H.EA, H.Unit, H.Pose
        local function VineLash(B)
            -- three rows of thorn bursts fanned a little either side of the line to you (aimed, not a spray)
            local r = B:Root()
            if not r then return end
            local dir = Unit(r.Position - B.pos)
            for k = -1, 1 do
                local d = CFrame.Angles(0, k * math.rad(12), 0):VectorToWorldSpace(dir)
                for i = 1, 6 do
                    local at = B:Clamp(B.pos + d * (6 + i * 7))
                    task.delay(i * 0.07 + (k + 1) * 0.25, function() if B:Alive() then EA.Circle(B.ctx, at, 3.6, 0.8, { Mult = 1.0 }) end end)
                end
            end
            B:Wait(B:W(0.8) + 1.0)
        end
        local function GoldenGaze(B)
            -- the eyes sweep a lane onto you, then another where you dodged to
            for _ = 1, 2 + (B.phase >= 3 and 1 or 0) do
                local r = B:Root()
                if not r or not B:Alive() then return end
                local dir = Unit(r.Position - B.pos)
                EA.Line(B.ctx, B.pos, B.pos + dir * 70, 5, B:W(0.85), { Mult = 1.2, Height = 9 })
                B:Wait(B:W(0.85) + 0.35)
            end
        end
        return {
            Color = GOLD, Move = "Orbit", Range = 30, SpeedMul = 0.9, Recover = { 1.9, 1.6, 1.3 },
            Names = { "THE IDOL KING", "THE IDOL KING: AWAKENED", "THE IDOL KING: TEMPLE'S WRATH" },
            Moves = {
                { { VineLash, "VINE LASH" }, { function(B) Mv.Footsteps(B, 7, 6) end, "TEMPLE STEPS" }, { GoldenGaze, "GOLDEN GAZE" } },
                { { function(B) Mv.Rain(B, 6, 6, 0.85, 0, 0.42) end, "STONE RAIN" }, { VineLash, "VINE LASH" }, { function(B) Mv.Cage(B, 8, 12, 1.0) end, "OVERGROWTH" },
                    { function(B) Mv.Halves(B, 1.4) end, "TEMPLE CRUSH" } },
                { { function(B) Mv.Tide(B, 3, true) end, "JUNGLE TIDE" }, { GoldenGaze, "GOLDEN GAZE" }, { VineLash, "VINE LASH" },
                    { function(B) Mv.ArenaWipe(B, 2, 8, 1.5) end, "SACRIFICE" } },
            },
            Animate = function(B, pivot, now)
                Pose(B, "Deco_HandL", pivot, CFrame.new(-5.4, 2.4, -1.4), CFrame.new(math.sin(now * 1.1) * 0.6, math.sin(now * 1.7) * 0.9, 0))
                Pose(B, "Deco_HandR", pivot, CFrame.new(5.4, 2.4, -1.4), CFrame.new(math.sin(now * 1.1 + 2) * 0.6, math.sin(now * 1.7 + 1.5) * 0.9, 0))
                Pose(B, "Deco_Crown", pivot, CFrame.new(0, 11.4, 0), CFrame.Angles(0, math.sin(now * 0.5) * 0.15, 0))
                Pose(B, "Deco_Vine", pivot, CFrame.new(0, -1, 0), CFrame.Angles(math.sin(now * 1.3) * 0.05, 0, math.cos(now * 1.1) * 0.05))
            end,
        }
    end,
}
return F
