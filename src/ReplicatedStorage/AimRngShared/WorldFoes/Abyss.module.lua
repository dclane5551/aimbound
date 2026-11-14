--!nocheck
-- THE DEEP foes (0.89): the glowing things of the sea floor. Superboss THE DROWNED KRAKEN.
local C3 = Color3.fromRGB
local M = Enum.Material
local GLOW, GLOW2, DEEP, CORAL, PEARL = C3(80, 255, 230), C3(200, 120, 255), C3(24, 40, 60), C3(230, 90, 120), C3(230, 240, 255)

local F = {}
F.Specialist = "Siren"
F.Enemies = {
    {
        Name = "Anglerfish", Weight = 2,
        Def = { Label = "Anglerfish", Hp = 95, Dmg = 10, Speed = 15, Body = 2.1, Head = 1.25, Color = C3(60, 70, 110), Range = { 22, 34 }, Fire = 3.0, Pattern = "Pendulum" },
        Lore = { Role = "Deep lurker", Text = "A black anglerfish swinging its glowing lure. The lure flashes on you, then the light blooms wider on the same spot.", Tip = "Shoot it at the ends of its swing; leave the spot." },
        Attack = { Shape = "Echo", R = 4, Delay = 0.7, W = 0.75, Mult = 0.8 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            W(model, { Name = "Jaw", Size = Vector3.new(R * 1.6, R * 0.5, R * 1.2), CFrame = base * CFrame.new(0, -R * 0.55, -R * 0.6) * CFrame.Angles(math.pi, 0, 0), Color = DEEP, Material = M.SmoothPlastic })
            for i = -2, 2 do W(model, { Name = "Fang", Size = Vector3.new(0.1, R * 0.4, R * 0.15), CFrame = base * CFrame.new(i * R * 0.28, -R * 0.25, -R * 1.1), Color = PEARL, Material = M.SmoothPlastic }) end
            P(model, { Name = "Chain", Size = Vector3.new(0.12, R * 1.4, 0.12), CFrame = base * CFrame.new(0, R * 1.3, -R * 0.6) * CFrame.Angles(math.rad(-35), 0, 0), Color = DEEP, Material = M.SmoothPlastic })
            P(model, { Name = "Tip", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.5, CFrame = base * CFrame.new(0, R * 1.85, -R * 1.25), Color = GLOW, Glow = true })
            for _, sx in ipairs({ -1, 1 }) do W(model, { Name = "Fin", Size = Vector3.new(0.12, R * 0.8, R * 1.0), CFrame = base * CFrame.new(sx * R * 1.0, 0, R * 0.2) * CFrame.Angles(0, 0, sx * math.rad(50)), Color = C3(40, 50, 80), Material = M.SmoothPlastic }) end
            W(model, { Name = "TailFin", Size = Vector3.new(0.12, R * 1.0, R * 1.0), CFrame = base * CFrame.new(0, 0, R * 1.3), Color = C3(40, 50, 80), Material = M.SmoothPlastic })
        end,
    },
    {
        Name = "Manta", Hard = true,
        Def = { Label = "Manta", Hp = 90, Dmg = 10, Speed = 19, Body = 1.9, Head = 1.1, Color = C3(50, 80, 140), Range = { 22, 34 }, Fire = 2.8, Pattern = "Flap" },
        Lore = { Role = "Deep glider", Text = "A manta ray with glowing rim-lines, beating its wings then gliding. Sweeps a wide lane through you.", Tip = "Strafe across the lane." },
        Attack = { Shape = "Lane", Width = 5.5, Past = 16, W = 0.85, Mult = 1.0 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for _, sx in ipairs({ -1, 1 }) do
                W(model, { Name = "Wing", Size = Vector3.new(0.15, R * 2.2, R * 2.0), CFrame = base * CFrame.new(sx * R * 1.6, 0, 0) * CFrame.Angles(0, 0, math.rad(sx * 88)), Color = C3(40, 64, 120), Material = M.SmoothPlastic })
                P(model, { Name = "WingEdge", Size = Vector3.new(R * 2.4, 0.12, 0.12), CFrame = base * CFrame.new(sx * R * 1.6, 0, -R * 0.95), Color = GLOW, Glow = true })
                W(model, { Name = "Horn", Size = Vector3.new(0.15, R * 0.6, R * 0.5), CFrame = base * CFrame.new(sx * R * 0.5, 0, -R * 1.2) * CFrame.Angles(math.rad(90), 0, 0), Color = C3(40, 64, 120), Material = M.SmoothPlastic })
            end
            P(model, { Name = "Tendril", Size = Vector3.new(0.1, 0.1, R * 2.6), CFrame = base * CFrame.new(0, 0, R * 2.2), Color = C3(30, 50, 90), Material = M.SmoothPlastic })
            P(model, { Name = "Belly", Size = Vector3.new(R * 1.2, 0.1, R * 1.0), CFrame = base * CFrame.new(0, -R * 0.75, 0), Color = PEARL, Material = M.SmoothPlastic })
        end,
    },
    {
        Name = "Pufferfish",
        Def = { Label = "Pufferfish", Hp = 80, Dmg = 9, Speed = 14, Body = 1.9, Head = 1.1, Color = C3(240, 200, 90), Range = { 20, 32 }, Fire = 2.6, Pattern = "Popcorn" },
        Lore = { Role = "Deep popper", Text = "A spiny pufferfish that pops up and drifts down. Puffs four needles round you, then one on you.", Tip = "Leave the box before the last needle." },
        Attack = { Shape = "Box", Gap = 5, R = 3.4, W = 0.8, Mult = 0.7 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for i = 0, 13 do
                local a, b = (i * 2.4) % (math.pi * 2), ((i * 1.3) % 2 - 1) * 1.2
                local d = CFrame.Angles(b, a, 0)
                W(model, { Name = "Spine", Size = Vector3.new(0.12, R * 0.6, R * 0.25), CFrame = base * d * CFrame.new(0, 0, -R * 1.15) * CFrame.Angles(math.rad(-90), 0, 0), Color = C3(255, 236, 200), Material = M.SmoothPlastic })
            end
            for _, sx in ipairs({ -1, 1 }) do
                P(model, { Name = "EyeSpot", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.4, CFrame = base * CFrame.new(sx * R * 0.5, R * 0.3, -R * 0.8), Color = C3(20, 20, 24), Material = M.SmoothPlastic })
                W(model, { Name = "Fin", Size = Vector3.new(0.1, R * 0.5, R * 0.6), CFrame = base * CFrame.new(sx * R * 1.0, 0, 0) * CFrame.Angles(0, 0, sx * math.rad(60)), Color = C3(255, 170, 70), Material = M.SmoothPlastic })
            end
            P(model, { Name = "Lip", Size = Vector3.new(R * 0.5, R * 0.25, 0.2), CFrame = base * CFrame.new(0, -R * 0.15, -R * 1.0), Color = C3(255, 130, 120), Material = M.SmoothPlastic })
        end,
    },
    {
        Name = "Seahorse", Weight = 2,
        Def = { Label = "Seahorse", Hp = 85, Dmg = 9, Speed = 17, Body = 1.9, Head = 1.15, Color = C3(255, 150, 80), Range = { 20, 32 }, Fire = 2.6, Pattern = "Bounce" },
        Lore = { Role = "Deep bouncer", Text = "A big glowing seahorse that bounces through the water. Blows a row of bubbles along its line to you.", Tip = "Step sideways off the row." },
        Attack = { Shape = "Row", N = 5, R = 3, Gap = 4.2, W = 0.8, Mult = 0.7 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            P(model, { Name = "Snout", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 1.2, R * 0.4, R * 0.4), CFrame = base * CFrame.new(0, R * 0.6, -R * 1.1) * CFrame.Angles(0, math.rad(90), math.rad(-15)), Color = C3(255, 140, 70), Material = M.SmoothPlastic })
            for k = 1, 5 do
                local a = k * 0.7
                P(model, { Name = "TailSegment", Shape = Enum.PartType.Ball, Size = Vector3.one * R * (0.9 - k * 0.12), CFrame = base * CFrame.new(0, -R * (0.6 + math.sin(a) * 0.9), R * (math.cos(a) * 0.8 - 0.3)), Color = (k % 2 == 0) and C3(255, 150, 80) or C3(255, 190, 110), Material = M.SmoothPlastic })
            end
            W(model, { Name = "Frill", Size = Vector3.new(0.1, R * 1.2, R * 0.8), CFrame = base * CFrame.new(0, R * 0.2, R * 0.9), Color = GLOW, Glow = true, Transparency = 0.2 })
            for k = 0, 3 do W(model, { Name = "Crest", Size = Vector3.new(0.12, R * 0.35, R * 0.3), CFrame = base * CFrame.new(0, R * (1.05 - k * 0.3), R * (0.2 + k * 0.2)), Color = C3(255, 220, 140), Material = M.SmoothPlastic }) end
        end,
    },
    {
        Name = "GlowEel", Hard = true,
        Def = { Label = "Glow Eel", Hp = 85, Dmg = 9, Speed = 18, Body = 1.8, Head = 1.1, Color = GLOW, Range = { 22, 36 }, Fire = 2.6, Pattern = "Serpent" },
        Lore = { Role = "Deep weaver", Text = "A long eel lit along its whole body, weaving through the water. Sends a low current rolling at you.", Tip = "Jump the current." },
        Attack = { Shape = "Roller", L = 18, W = 0.7, Mult = 0.9 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for k = 1, 6 do
                local sz = R * (1.1 - k * 0.12)
                P(model, { Name = "TailSegment", Shape = Enum.PartType.Ball, Size = Vector3.new(sz, sz, sz * 1.3), CFrame = base * CFrame.new(math.sin(k) * R * 0.4, 0, R * (0.4 + k * 0.85)), Color = C3(20, 60, 70), Material = M.SmoothPlastic })
                P(model, { Name = "LightStrip", Size = Vector3.new(0.12, 0.12, sz * 1.1), CFrame = base * CFrame.new(math.sin(k) * R * 0.4, sz * 0.48, R * (0.4 + k * 0.85)), Color = GLOW, Glow = true })
            end
            W(model, { Name = "Jaw", Size = Vector3.new(R * 0.9, R * 0.3, R * 0.8), CFrame = base * CFrame.new(0, -R * 0.4, -R * 0.8) * CFrame.Angles(math.pi, 0, 0), Color = C3(20, 60, 70), Material = M.SmoothPlastic })
            W(model, { Name = "Fin", Size = Vector3.new(0.12, R * 0.5, R * 2.4), CFrame = base * CFrame.new(0, R * 0.7, R * 1.6), Color = GLOW, Glow = true, Transparency = 0.25 })
        end,
    },
    {
        Name = "Siren",
        Def = { Label = "Siren", Hp = 180, Dmg = 9, Speed = 9, Body = 2.7, Head = 1.4, Color = GLOW2, Range = { 30, 44 }, Fire = 3.8, Pattern = "SlowStrafe" },
        Lore = { Role = "Deep suppressor", Text = "A tentacled siren crowned with shells, singing in light. Its song weaves a lattice of lanes round you: one gap is safe.", Tip = "Find the gap before it fills." },
        Attack = { Shape = "Lattice", W = 1.0, Mult = 0.9 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for i = 0, 7 do
                local a = i / 8 * math.pi * 2
                P(model, { Name = "Tendril", Size = Vector3.new(R * 0.25, R * (2.0 + (i % 3) * 0.5), R * 0.25), CFrame = base * CFrame.new(math.cos(a) * R * 0.75, -R * 1.6, math.sin(a) * R * 0.75), Color = (i % 2 == 0) and GLOW2 or C3(120, 80, 200), Material = M.SmoothPlastic })
            end
            for k = -2, 2 do
                W(model, { Name = "Shell", Size = Vector3.new(0.2, R * (0.9 - math.abs(k) * 0.15), R * 0.6), CFrame = base * CFrame.new(k * R * 0.35, R * 1.25, 0) * CFrame.Angles(0, math.rad(90), math.rad(k * -14)), Color = (k == 0) and PEARL or CORAL, Material = M.SmoothPlastic })
            end
            P(model, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.7, CFrame = base * CFrame.new(0, 0, -R * 0.75), Color = GLOW, Glow = true })
            H.Ring(model, base * CFrame.new(0, -R * 0.3, 0), R * 2.6, 0.12, GLOW, true)
        end,
    },
}

-- ==================== SUPERBOSS: THE DROWNED KRAKEN ====================
F.Super = {
    Name = "THE DROWNED KRAKEN", Color = GLOW2,
    Hitbox = { Torso = { Vector3.new(6, 9, 5), Vector3.new(0, 3, 0) }, Core = { Vector3.new(2.6, 2.6, 2.6), Vector3.new(0, 2.6, -2.6), "Ball" },
        Head = { Vector3.new(3, 3, 3), Vector3.new(0, 4.8, -2.4), "Ball" } },
    Evade = { Amp = 10, Rate = 1.3, Dodge = 3.8 },
    Body = function(model, Mf, col, H)
        local P, W, Style = H.Part, H.Wedge, H.Style
        Style(model:FindFirstChild("Torso"), C3(110, 50, 110), H.SMOOTH)
        Style(model:FindFirstChild("Core"), GLOW, H.NEON)
        Style(model:FindFirstChild("Head"), C3(255, 210, 90), H.NEON)
        -- the mantle: a tall domed hood, glowing spots, fins either side
        P(model, { Name = "Mantle", Shape = Enum.PartType.Ball, Size = Vector3.new(6.4, 10, 5.6), CFrame = Mf(0, 6.6, 0.6), Color = C3(120, 56, 120), Material = H.SMOOTH })
        for i = 0, 7 do
            local a = i / 8 * math.pi * 2
            P(model, { Name = "Spot", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, CFrame = Mf(math.cos(a) * 3.0, 7 + math.sin(a * 2) * 2, math.sin(a) * 2.6), Color = (i % 2 == 0) and GLOW or GLOW2, Material = H.NEON })
        end
        for _, sx in ipairs({ -1, 1 }) do
            W(model, { Name = "MantleFin", Size = Vector3.new(0.3, 4, 3), CFrame = Mf(sx * 3.4, 10, 0.8) * CFrame.Angles(0, 0, sx * math.rad(40)), Color = C3(90, 40, 100), Material = H.SMOOTH })
            P(model, { Name = "EyeRim", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = Mf(sx * 2.2, 4.6, -1.8), Color = C3(40, 20, 50), Material = H.SMOOTH })
        end
        -- eight tentacles reaching down and out (they writhe), glowing suckers along them
        for i = 0, 7 do
            local a = i / 8 * math.pi * 2
            local root = Vector3.new(math.cos(a) * 2.2, -1, math.sin(a) * 2.2)
            for k = 0, 3 do
                local p = root + Vector3.new(math.cos(a) * k * 1.4, -k * 1.5, math.sin(a) * k * 1.4)
                P(model, { Name = "Deco_Tentacle" .. (i % 2), Shape = Enum.PartType.Ball, Size = Vector3.one * (1.6 - k * 0.3), CFrame = Mf(p.X, p.Y, p.Z), Color = C3(130, 60, 130), Material = H.SMOOTH })
                if k > 0 then P(model, { Name = "Deco_Tentacle" .. (i % 2), Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35, CFrame = Mf(p.X, p.Y - 0.6, p.Z), Color = GLOW, Material = H.NEON }) end
            end
        end
        H.Emit(model:FindFirstChild("Torso") or model.PrimaryPart, C3(200, 240, 255), 6, 0.35, 2, 2.4)
    end,
    Kit = function(H)
        local Mv, EA, Unit, Pose = H.M, H.EA, H.Unit, H.Pose
        local function Grasp(B)
            -- two tentacles sweep in as lanes from either side, meeting on you
            local r = B:Root()
            if not r then return end
            local at = r.Position
            local dir = Unit(at - B.pos)
            local side = Vector3.new(-dir.Z, 0, dir.X)
            for k, off in ipairs({ 10, 5, 0 }) do
                task.delay((k - 1) * 0.4, function()
                    if not B:Alive() then return end
                    for _, sx in ipairs(off == 0 and { 0 } or { -1, 1 }) do
                        local c = at + side * sx * off
                        EA.Line(B.ctx, c - dir * 28, c + dir * 28, 4, B:W(0.8), { Mult = 1.0, Height = 9 })
                    end
                end)
            end
            B:Wait(B:W(0.8) + 1.2)
        end
        local function InkCloud(B)
            -- clouds of ink that linger where you stand, three in turn
            for _ = 1, 3 do
                local r = B:Root()
                if not r or not B:Alive() then return end
                EA.Zone(B.ctx, r.Position, 6, B:W(0.7), 3, { Mult = 0.35, Height = 6 })
                B:Wait(0.7)
            end
            B:Wait(0.6)
        end
        return {
            Color = GLOW2, Move = "Chase", Range = 26, SpeedMul = 0.8, Recover = { 1.9, 1.6, 1.3 },
            Names = { "THE DROWNED KRAKEN", "THE DROWNED KRAKEN: RISING TIDE", "THE DROWNED KRAKEN: CRUSH DEPTH" },
            Moves = {
                { { Grasp, "GRASP" }, { InkCloud, "INK CLOUD" }, { function(B) Mv.Rain(B, 6, 6, 0.85, 0, 0.42) end, "BIOLUMINESCENCE" } },
                { { function(B) Mv.InOut(B, 13, 44, true, 1.0) end, "WHIRLPOOL" }, { Grasp, "GRASP" }, { function(B) Mv.Tide(B, 3, true) end, "RIPTIDE" },
                    { InkCloud, "INK CLOUD" } },
                { { function(B) Mv.Footsteps(B, 9, 6) end, "TENTACLE SLAMS" }, { Grasp, "GRASP" }, { function(B) Mv.Crossfire(B, 2, 6, 0.9) end, "CROSSCURRENT" },
                    { function(B) Mv.ArenaWipe(B, 2, 8, 1.5) end, "CRUSH DEPTH" } },
            },
            Animate = function(B, pivot, now)
                Pose(B, "Deco_Tentacle0", pivot, CFrame.new(0, -1, 0), CFrame.Angles(math.sin(now * 1.6) * 0.12, math.sin(now * 0.7) * 0.2, math.cos(now * 1.3) * 0.1))
                Pose(B, "Deco_Tentacle1", pivot, CFrame.new(0, -1, 0), CFrame.Angles(math.cos(now * 1.5) * 0.12, -math.sin(now * 0.7) * 0.2, math.sin(now * 1.2) * 0.1))
            end,
        }
    end,
}
return F
