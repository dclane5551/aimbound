--!nocheck
-- AUTUMN HIGHLANDS foes (0.89): the creatures of the harvest hills. Superboss THE HARVEST KING.
local C3 = Color3.fromRGB
local M = Enum.Material
local MAPLE, MAPLE2, MAPLE3, STRAW, BARK, BLACK = C3(214, 70, 36), C3(240, 140, 40), C3(250, 196, 60), C3(220, 180, 90), C3(80, 58, 44), C3(28, 26, 30)

local F = {}
F.Specialist = "StagSpirit"
F.Enemies = {
    {
        Name = "Scarecrow", Weight = 2,
        Def = { Label = "Scarecrow", Hp = 125, Dmg = 11, Speed = 15, Body = 2.2, Head = 1.3, Color = STRAW, Range = { 16, 28 }, Fire = 2.8, Pattern = "Stutter", Ground = true },
        Lore = { Role = "Field walker", Text = "A scarecrow that walks when you're not looking: it freezes, then lurches on. Throws two sickle cuts crossing on you.", Tip = "Free shots while it freezes; leave the X." },
        Attack = { Shape = "Cross", L = 20, Width = 3.4, W = 0.85, Mult = 0.8 },
        Decor = function(model, H)
            local P, W, body, base, hc, head = H.Part, H.Wedge, H.body, H.base, H.headCF, H.head
            P(model, { Name = "Hat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(head.Y * 0.2, head.X * 2.1, head.X * 2.1), CFrame = hc * CFrame.new(0, head.Y * 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = C3(90, 70, 50), Material = M.Fabric })
            W(model, { Name = "HatTop", Size = Vector3.new(head.X * 0.9, head.Y * 0.9, head.X * 0.9), CFrame = hc * CFrame.new(0, head.Y * 0.95, 0), Color = C3(90, 70, 50), Material = M.SmoothPlastic })
            P(model, { Name = "Pumpkin", Shape = Enum.PartType.Ball, Size = Vector3.new(head.X * 1.15, head.Y * 0.95, head.Z * 1.15), CFrame = hc, Color = MAPLE2, Material = M.SmoothPlastic })
            for _, sx in ipairs({ -1, 1 }) do P(model, { Name = "EyeSpot", Size = Vector3.new(head.X * 0.22, head.Y * 0.2, 0.1), CFrame = hc * CFrame.new(sx * head.X * 0.22, head.Y * 0.1, -head.Z * 0.58), Color = MAPLE3, Glow = true }) end
            P(model, { Name = "Maw", Size = Vector3.new(head.X * 0.5, head.Y * 0.12, 0.1), CFrame = hc * CFrame.new(0, -head.Y * 0.2, -head.Z * 0.58), Color = MAPLE3, Glow = true })
            P(model, { Name = "Crossbar", Size = Vector3.new(body.X * 2.6, 0.3, 0.3), CFrame = base * CFrame.new(0, body.Y * 0.35, body.Z * 0.3), Color = BARK, Material = M.Wood })
            for k = 0, 4 do P(model, { Name = "Plume", Size = Vector3.new(0.1, body.Y * 0.4, 0.1), CFrame = base * CFrame.new((k - 2) * body.X * 0.2, -body.Y * 0.6, -body.Z * 0.4) * CFrame.Angles(0, 0, (k - 2) * 0.2), Color = STRAW, Material = M.SmoothPlastic }) end
        end,
    },
    {
        Name = "LeafSpirit",
        Def = { Label = "Leaf Spirit", Hp = 75, Dmg = 8, Speed = 15, Body = 1.8, Head = 1.1, Color = MAPLE, Range = { 24, 38 }, Fire = 2.8, Pattern = "Leaf" },
        Lore = { Role = "Field drifter", Text = "A whirl of maple leaves with a spirit inside, falling and floating up again. Its leaf storms follow you: three in a row.", Tip = "Keep moving." },
        Attack = { Shape = "Chase", N = 3, R = 3.4, W = 0.6, Gap = 0.55, Mult = 0.6 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            for i = 0, 7 do
                local a = i / 8 * math.pi * 2
                P(model, { Name = "Cloud", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.9, 0.12, R * 0.7), CFrame = base * CFrame.new(math.cos(a) * R * 1.0, (i % 3 - 1) * R * 0.5, math.sin(a) * R * 1.0) * CFrame.Angles(a, 0, a * 0.5),
                    Color = ({ MAPLE, MAPLE2, MAPLE3 })[i % 3 + 1], Material = M.SmoothPlastic })
            end
            P(model, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.7, CFrame = base, Color = C3(255, 200, 120), Glow = true })
        end,
    },
    {
        Name = "TawnyOwl", Hard = true,
        Def = { Label = "Tawny Owl", Hp = 80, Dmg = 10, Speed = 19, Body = 1.9, Head = 1.15, Color = C3(150, 100, 60), Range = { 22, 34 }, Fire = 2.8, Pattern = "Flap" },
        Lore = { Role = "Field hunter", Text = "A great tawny owl that beats its wings then glides. Swoops a lane straight through you.", Tip = "Strafe across the swoop." },
        Attack = { Shape = "Lane", Width = 4.4, Past = 16, W = 0.85, Mult = 1.0 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for _, sx in ipairs({ -1, 1 }) do
                for f = 0, 2 do W(model, { Name = "Feather", Size = Vector3.new(0.1, R * 0.7, R * (1.9 - f * 0.35)), CFrame = base * CFrame.new(sx * R * (1.1 + f * 0.4), -f * R * 0.15, R * 0.2) * CFrame.Angles(0, 0, math.rad(sx * 80)), Color = (f % 2 == 0) and C3(150, 100, 60) or C3(110, 74, 44), Material = M.SmoothPlastic }) end
                P(model, { Name = "Pupil", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.45, CFrame = base * CFrame.new(sx * R * 0.38, R * 0.3, -R * 0.88), Color = MAPLE3, Glow = true })
                W(model, { Name = "Ear", Size = Vector3.new(0.12, R * 0.5, R * 0.3), CFrame = base * CFrame.new(sx * R * 0.5, R * 1.05, -R * 0.4), Color = C3(110, 74, 44), Material = M.SmoothPlastic })
            end
            P(model, { Name = "FacialDisc", Size = Vector3.new(R * 1.6, R * 1.2, 0.15), CFrame = base * CFrame.new(0, R * 0.25, -R * 0.82), Color = C3(220, 190, 150), Material = M.SmoothPlastic })
            W(model, { Name = "Beak", Size = Vector3.new(R * 0.18, R * 0.3, R * 0.25), CFrame = base * CFrame.new(0, 0, -R * 0.95) * CFrame.Angles(math.pi, 0, 0), Color = BLACK, Material = M.SmoothPlastic })
        end,
    },
    {
        Name = "Hedgeling", Weight = 2,
        Def = { Label = "Hedgeling", Hp = 85, Dmg = 9, Speed = 17, Body = 1.9, Head = 1.15, Color = C3(130, 100, 70), Range = { 18, 32 }, Fire = 2.6, Pattern = "Bounce" },
        Lore = { Role = "Field bouncer", Text = "A hedgehog curled into a spiky ball, bouncing about. Scatters a row of spines along its line to you.", Tip = "Sidestep the row." },
        Attack = { Shape = "Row", N = 5, R = 3, Gap = 4.2, W = 0.8, Mult = 0.7 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for i = 0, 15 do
                local a, b = (i * 2.4) % (math.pi * 2), ((i * 1.7) % 2 - 1) * 1.1
                W(model, { Name = "Spine", Size = Vector3.new(0.12, R * 0.6, R * 0.25), CFrame = base * CFrame.Angles(b, a, 0) * CFrame.new(0, 0, R * 1.05) * CFrame.Angles(math.rad(90), 0, 0), Color = (i % 2 == 0) and C3(90, 66, 44) or C3(200, 170, 130), Material = M.SmoothPlastic })
            end
            P(model, { Name = "Snout", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.6, CFrame = base * CFrame.new(0, -R * 0.1, -R * 1.0), Color = C3(220, 190, 160), Material = M.SmoothPlastic })
            P(model, { Name = "Nose", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.22, CFrame = base * CFrame.new(0, -R * 0.1, -R * 1.3), Color = BLACK, Material = M.SmoothPlastic })
        end,
    },
    {
        Name = "Crow", Hard = true,
        Def = { Label = "Crow", Hp = 60, Dmg = 8, Speed = 22, Body = 1.6, Head = 1.0, Color = C3(40, 40, 50), Range = { 20, 32 }, Fire = 2.4, Pattern = "Zigzag" },
        Lore = { Role = "Field scavenger", Text = "A sharp-eyed crow zigzagging over the fields. Pecks two strikes either side of you.", Tip = "Stay in the gap." },
        Attack = { Shape = "Pair", Gap = 3.6, R = 3.4, W = 0.7, Mult = 0.8 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for _, sx in ipairs({ -1, 1 }) do
                W(model, { Name = "Wing", Size = Vector3.new(0.1, R * 0.8, R * 1.9), CFrame = base * CFrame.new(sx * R * 1.3, 0, R * 0.2) * CFrame.Angles(0, 0, math.rad(sx * 80)), Color = BLACK, Material = M.SmoothPlastic })
                P(model, { Name = "EyeSpot", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.2, CFrame = base * CFrame.new(sx * R * 0.38, R * 0.3, -R * 0.82), Color = MAPLE3, Glow = true })
            end
            W(model, { Name = "Beak", Size = Vector3.new(R * 0.25, R * 0.25, R * 0.9), CFrame = base * CFrame.new(0, 0, -R * 1.3) * CFrame.Angles(0, math.pi, 0), Color = C3(60, 60, 60), Material = M.SmoothPlastic })
            for k = -1, 1 do W(model, { Name = "TailFin", Size = Vector3.new(0.1, R * 0.35, R * 1.0), CFrame = base * CFrame.new(k * R * 0.22, 0, R * 1.2) * CFrame.Angles(0, k * 0.3, 0), Color = BLACK, Material = M.SmoothPlastic }) end
        end,
    },
    {
        Name = "StagSpirit",
        Def = { Label = "Stag Spirit", Hp = 185, Dmg = 9, Speed = 9, Body = 2.8, Head = 1.4, Color = C3(255, 200, 120), Range = { 30, 44 }, Fire = 3.8, Pattern = "SlowStrafe" },
        Lore = { Role = "Field suppressor", Text = "The glowing spirit of the forest, a stag's head crowned with great antlers. Blesses a cross of light over you, then its heart.", Tip = "Leave the cross, then the middle." },
        Attack = { Shape = "Sunburst", W = 0.95, Mult = 0.9 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Muzzle", Size = Vector3.new(R * 0.9, R * 0.8, R * 1.2), CFrame = base * CFrame.new(0, -R * 0.2, -R * 1.1), Color = C3(255, 236, 200), Material = M.SmoothPlastic })
            for _, sx in ipairs({ -1, 1 }) do
                local root = base * CFrame.new(sx * R * 0.5, R * 0.9, 0)
                for k = 0, 3 do
                    P(model, { Name = "Antler", Size = Vector3.new(0.2, R * 0.9, 0.2), CFrame = root * CFrame.new(sx * k * R * 0.35, k * R * 0.65, 0) * CFrame.Angles(0, 0, sx * -0.4), Color = C3(255, 230, 180), Glow = true })
                    P(model, { Name = "Antler", Size = Vector3.new(0.18, R * 0.6, 0.18), CFrame = root * CFrame.new(sx * k * R * 0.35, k * R * 0.65 + R * 0.3, 0) * CFrame.Angles(0, 0, sx * 0.6), Color = C3(255, 230, 180), Glow = true })
                end
                P(model, { Name = "Ear", Size = Vector3.new(R * 0.6, R * 0.3, 0.12), CFrame = base * CFrame.new(sx * R * 1.1, R * 0.5, 0), Color = C3(240, 200, 150), Material = M.SmoothPlastic })
                P(model, { Name = "EyeSpot", Size = Vector3.new(R * 0.25, R * 0.15, 0.1), CFrame = base * CFrame.new(sx * R * 0.5, R * 0.3, -R * 0.98), Color = C3(80, 220, 160), Glow = true })
            end
            H.Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "sparkles_main.dds", C3(255, 220, 150), 5, 0.3, 1, 1.4, Enum.NormalId.Top, 90, 0.9)
        end,
    },
}

-- ==================== SUPERBOSS: THE HARVEST KING ====================
F.Super = {
    Name = "THE HARVEST KING", Color = MAPLE2,
    Hitbox = { Torso = { Vector3.new(5.4, 8, 3.6), Vector3.new(0, 2.8, 0) }, Core = { Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 4, -2), "Ball" },
        Head = { Vector3.new(3, 2.8, 3), Vector3.new(0, 8.4, 0), "Ball" } },
    Evade = { Amp = 10, Rate = 1.3, Dodge = 3.8 },
    Body = function(model, Mf, col, H)
        local P, W, Style = H.Part, H.Wedge, H.Style
        Style(model:FindFirstChild("Torso"), C3(110, 70, 40), H.SMOOTH)
        Style(model:FindFirstChild("Core"), MAPLE3, H.NEON)
        Style(model:FindFirstChild("Head"), MAPLE2, H.SMOOTH)
        -- a pumpkin head with a carved glowing face, a crown of wheat and antlers, a patched cloak, a great scythe
        for _, sx in ipairs({ -1, 1 }) do
            W(model, { Name = "Eye", Size = Vector3.new(0.7, 0.6, 0.2), CFrame = Mf(sx * 0.6, 8.7, -1.4), Color = MAPLE3, Material = H.NEON })
            for k = 0, 3 do P(model, { Name = "Antler", Size = Vector3.new(0.25, 1.2, 0.25), CFrame = Mf(sx * (0.9 + k * 0.45), 10 + k * 0.6, 0) * CFrame.Angles(0, 0, sx * -0.5), Color = BARK, Material = M.Wood }) end
        end
        P(model, { Name = "Grin", Size = Vector3.new(1.8, 0.35, 0.2), CFrame = Mf(0, 7.9, -1.45), Color = MAPLE3, Material = H.NEON })
        P(model, { Name = "Stalk", Size = Vector3.new(0.4, 0.9, 0.4), CFrame = Mf(0, 10.1, 0), Color = C3(80, 100, 40), Material = H.SMOOTH })
        for k = 0, 7 do
            local a = k / 8 * math.pi * 2
            P(model, { Name = "Deco_Crown", Size = Vector3.new(0.2, 1.4, 0.2), CFrame = Mf(math.cos(a) * 1.3, 10.2, math.sin(a) * 1.3) * CFrame.Angles(math.cos(a) * 0.3, 0, math.sin(a) * 0.3), Color = STRAW, Material = H.SMOOTH })
        end
        for i = 0, 9 do
            local a = i / 10 * math.pi * 2
            P(model, { Name = "Deco_Cloak", Size = Vector3.new(1.6, 7, 0.2), CFrame = Mf(math.cos(a) * 2.6, 1, math.sin(a) * 2.0) * CFrame.Angles(0, -a, 0) * CFrame.Angles(math.rad(-6), 0, 0), Color = ({ MAPLE, C3(120, 60, 40), C3(160, 110, 60) })[i % 3 + 1], Material = H.SMOOTH })
        end
        P(model, { Name = "Deco_Scythe", Size = Vector3.new(0.35, 11, 0.35), CFrame = Mf(3.6, 4, -0.8) * CFrame.Angles(0, 0, math.rad(-12)), Color = BARK, Material = M.Wood })
        W(model, { Name = "Deco_Scythe", Size = Vector3.new(0.2, 1.4, 5), CFrame = Mf(4.6, 9.4, -2.6) * CFrame.Angles(0, 0, math.rad(-12)), Color = C3(210, 214, 220), Material = H.METAL })
        -- leaves whirling round it
        for i = 0, 7 do
            local a = i / 8 * math.pi * 2
            P(model, { Name = "Deco_Leaf", Shape = Enum.PartType.Ball, Size = Vector3.new(1.0, 0.15, 0.7), CFrame = Mf(math.cos(a) * 6.5, 2.5 + (i % 3) * 2.5, math.sin(a) * 6.5), Color = ({ MAPLE, MAPLE2, MAPLE3 })[i % 3 + 1], Material = H.SMOOTH })
        end
        H.Emit(model:FindFirstChild("Torso") or model.PrimaryPart, MAPLE2, 5, 0.35, 1.5, 2)
    end,
    Kit = function(H)
        local Mv, EA, Unit, Pose = H.M, H.EA, H.Unit, H.Pose
        local function Reap(B)
            -- the scythe reaps: two wide arcs (cones) toward you, the second where you went
            for _ = 1, 2 do
                local r = B:Root()
                if not r or not B:Alive() then return end
                EA.Cone(B.ctx, B.pos, Unit(r.Position - B.pos), 40, 34, B:W(0.9), { Mult = 1.1, Plain = Mv.PLAIN and Mv.PLAIN.Reap })
                B:Wait(B:W(0.9) + 0.4)
            end
        end
        local function Harvest(B)
            -- furrows ploughed toward you: three parallel lanes, the middle one on you
            local r = B:Root()
            if not r then return end
            local d = Unit(r.Position - B.pos)
            local side = Vector3.new(-d.Z, 0, d.X)
            for k = -1, 1 do
                local o = side * k * 8
                task.delay(math.abs(k) * 0.25, function() if B:Alive() then EA.Line(B.ctx, B.pos + o, r.Position + o + d * 20, 4, B:W(0.8), { Mult = 1.0, Height = 9 }) end end)
            end
            B:Wait(B:W(0.8) + 0.8)
        end
        return {
            Color = MAPLE2, Move = "Chase", Range = 24, SpeedMul = 0.9, Recover = { 1.9, 1.6, 1.3 },
            Names = { "THE HARVEST KING", "THE HARVEST KING: REAPING", "THE HARVEST KING: LAST HARVEST" },
            Moves = {
                { { Reap, "REAP" }, { Harvest, "PLOUGH" }, { function(B) Mv.Rain(B, 6, 6, 0.85, 0, 0.42) end, "FALLING LEAVES" } },
                { { function(B) Mv.Footsteps(B, 7, 6) end, "STALKING" }, { Reap, "REAP" }, { function(B) Mv.Cage(B, 8, 12, 1.0) end, "CROP CIRCLE" },
                    { Harvest, "PLOUGH" } },
                { { function(B) Mv.Tide(B, 3, true) end, "WHEAT WAVES" }, { Reap, "REAP" }, { function(B) Mv.Halves(B, 1.4) end, "SCYTHE SWEEP" },
                    { function(B) Mv.ArenaWipe(B, 2, 8, 1.5) end, "LAST HARVEST" } },
            },
            Animate = function(B, pivot, now)
                Pose(B, "Deco_Leaf", pivot, CFrame.new(0, 4, 0), CFrame.Angles(0, now * 0.7, 0))
                Pose(B, "Deco_Cloak", pivot, CFrame.new(0, 4, 0), CFrame.Angles(math.sin(now * 1.3) * 0.05, 0, math.cos(now * 1.1) * 0.05))
                Pose(B, "Deco_Scythe", pivot, CFrame.new(3.6, 4, -0.8), CFrame.Angles(math.sin(now * 0.9) * 0.1, 0, 0))
            end,
        }
    end,
}
return F
