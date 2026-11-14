--!nocheck
-- SAKURA SHRINE foes (0.89): the spirits of a mountain shrine. Superboss THE SHOGUN OF PETALS.
local C3 = Color3.fromRGB
local M = Enum.Material
local RED, BLACK, PETAL, GOLD, PAPER, LAMP = C3(200, 50, 40), C3(36, 30, 32), C3(255, 176, 206), C3(230, 180, 80), C3(246, 236, 220), C3(255, 190, 120)

local F = {}
F.Specialist = "TempleMonk"
F.Enemies = {
    {
        Name = "OniMask", Hard = true,
        Def = { Label = "Oni Mask", Hp = 85, Dmg = 10, Speed = 18, Body = 1.9, Head = 1.15, Color = RED, Range = { 22, 34 }, Fire = 2.6, Pattern = "Pasu" },
        Lore = { Role = "Shrine demon", Text = "A floating red oni mask with horns and a gold grin, darting about. Crosses two blades of light over you.", Tip = "Step out of the X, not along it." },
        Attack = { Shape = "Cross", L = 20, Width = 3.4, W = 0.85, Mult = 0.8 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            P(model, { Name = "Mask", Size = Vector3.new(R * 1.7, R * 1.9, 0.4), CFrame = base * CFrame.new(0, 0, -R * 1.0), Color = RED, Material = M.SmoothPlastic })
            P(model, { Name = "Brow", Size = Vector3.new(R * 1.6, R * 0.3, 0.5), CFrame = base * CFrame.new(0, R * 0.55, -R * 1.1) * CFrame.Angles(0, 0, 0), Color = BLACK, Material = M.SmoothPlastic })
            P(model, { Name = "Mouth", Size = Vector3.new(R * 1.1, R * 0.3, 0.1), CFrame = base * CFrame.new(0, -R * 0.5, -R * 1.22), Color = GOLD, Glow = true })
            for _, sx in ipairs({ -1, 1 }) do
                W(model, { Name = "Horn", Size = Vector3.new(0.25, R * 1.0, R * 0.45), CFrame = base * CFrame.new(sx * R * 0.6, R * 1.2, -R * 0.8) * CFrame.Angles(0, 0, sx * math.rad(-18)), Color = C3(240, 230, 210), Material = M.SmoothPlastic })
                P(model, { Name = "EyeSpot", Size = Vector3.new(R * 0.35, R * 0.18, 0.1), CFrame = base * CFrame.new(sx * R * 0.4, R * 0.25, -R * 1.22), Color = GOLD, Glow = true })
                W(model, { Name = "Tusk", Size = Vector3.new(0.15, R * 0.45, R * 0.2), CFrame = base * CFrame.new(sx * R * 0.35, -R * 0.75, -R * 1.2), Color = C3(240, 230, 210), Material = M.SmoothPlastic })
            end
            for i = 0, 4 do P(model, { Name = "Streamer", Size = Vector3.new(R * 0.25, 0.08, R * 1.8), CFrame = base * CFrame.new((i - 2) * R * 0.35, R * 0.2, R * 1.0), Color = (i % 2 == 0) and BLACK or RED, Material = M.SmoothPlastic }) end
        end,
    },
    {
        Name = "PaperLantern", Weight = 2,
        Def = { Label = "Paper Lantern", Hp = 85, Dmg = 9, Speed = 15, Body = 2.0, Head = 1.2, Color = LAMP, Range = { 24, 38 }, Fire = 3.0, Pattern = "Pendulum" },
        Lore = { Role = "Shrine lantern", Text = "A haunted paper lantern with a lolling tongue, swinging from nothing. Drops on you in a burst that leaves its fire burning.", Tip = "Don't stand where it fell." },
        Attack = { Shape = "Puddle", R = 4, W = 0.8, Mult = 0.8, Life = 2.4 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Paper", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 2.0, R * 2.4, R * 2.0), CFrame = base, Color = C3(255, 200, 140), Material = M.SmoothPlastic, Transparency = 0.1 })
            for k = -2, 2 do P(model, { Name = "Rib", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, R * (2.05 - math.abs(k) * 0.3), R * (2.05 - math.abs(k) * 0.3)), CFrame = base * CFrame.new(0, k * R * 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = BLACK, Material = M.SmoothPlastic }) end
            for _, y in ipairs({ 1.2, -1.2 }) do P(model, { Name = "Cap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 0.3, R * 1.0, R * 1.0), CFrame = base * CFrame.new(0, y * R, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = BLACK, Material = M.Wood }) end
            P(model, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.9, CFrame = base, Color = LAMP, Glow = true })
            P(model, { Name = "EyeSpot", Size = Vector3.new(R * 0.3, R * 0.3, 0.1), CFrame = base * CFrame.new(-R * 0.35, R * 0.3, -R * 1.0), Color = BLACK, Material = M.SmoothPlastic })
            P(model, { Name = "Tongue", Size = Vector3.new(R * 0.35, R * 0.8, 0.1), CFrame = base * CFrame.new(0, -R * 0.5, -R * 1.02), Color = C3(230, 60, 80), Material = M.SmoothPlastic })
        end,
    },
    {
        Name = "KoiSpirit", Hard = true,
        Def = { Label = "Koi Spirit", Hp = 85, Dmg = 9, Speed = 18, Body = 1.9, Head = 1.15, Color = C3(255, 120, 60), Range = { 22, 36 }, Fire = 2.6, Pattern = "Serpent" },
        Lore = { Role = "Shrine swimmer", Text = "A koi swimming through the air as if it were water. Leaves a row of ripples along its line to you.", Tip = "Sidestep the row." },
        Attack = { Shape = "Row", N = 5, R = 3, Gap = 4.2, W = 0.8, Mult = 0.7 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            P(model, { Name = "KoiBody", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 1.5, R * 1.4, R * 2.8), CFrame = base * CFrame.new(0, 0, R * 0.6), Color = C3(250, 246, 240), Material = M.SmoothPlastic })
            for i, o in ipairs({ { 0.4, 0.4, 0.2 }, { -0.4, 0.2, 1.0 }, { 0.2, -0.3, 1.6 } }) do
                P(model, { Name = "Patch", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.8, R * 0.6, R * 0.9), CFrame = base * CFrame.new(R * o[1], R * o[2] + R * 0.3, R * o[3]), Color = C3(255, 110, 50), Material = M.SmoothPlastic })
            end
            for _, sx in ipairs({ -1, 1 }) do W(model, { Name = "Fin", Size = Vector3.new(0.1, R * 0.6, R * 0.9), CFrame = base * CFrame.new(sx * R * 0.75, -R * 0.2, 0) * CFrame.Angles(0, 0, sx * math.rad(55)), Color = C3(255, 200, 170), Material = M.SmoothPlastic, Transparency = 0.2 }) end
            W(model, { Name = "TailFin", Size = Vector3.new(0.1, R * 1.4, R * 1.2), CFrame = base * CFrame.new(0, 0, R * 2.4), Color = C3(255, 140, 80), Material = M.SmoothPlastic, Transparency = 0.15 })
            for _, sx in ipairs({ -1, 1 }) do P(model, { Name = "Whisker", Size = Vector3.new(0.06, 0.06, R * 0.9), CFrame = base * CFrame.new(sx * R * 0.3, -R * 0.3, -R * 0.9) * CFrame.Angles(0, sx * 0.4, 0), Color = GOLD, Material = M.SmoothPlastic }) end
        end,
    },
    {
        Name = "Ronin", Weight = 2,
        Def = { Label = "Ronin", Hp = 130, Dmg = 11, Speed = 16, Body = 2.2, Head = 1.3, Color = C3(70, 80, 110), Range = { 16, 28 }, Fire = 2.8, Pattern = "Stutter", Ground = true },
        Lore = { Role = "Shrine swordsman", Text = "A masterless swordsman in a straw hat. Stops dead, then dashes on. His draw cuts a line across you.", Tip = "Step toward or away from the cut." },
        Attack = { Shape = "Bar", L = 20, Width = 4, W = 0.75, Mult = 1.0 },
        Decor = function(model, H)
            local P, W, hc, head, body, base = H.Part, H.Wedge, H.headCF, H.head, H.body, H.base
            P(model, { Name = "Kasa", Shape = Enum.PartType.Cylinder, Size = Vector3.new(head.Y * 0.25, head.X * 2.4, head.X * 2.4), CFrame = hc * CFrame.new(0, head.Y * 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = C3(210, 180, 110), Material = M.Wood })
            P(model, { Name = "KasaTop", Shape = Enum.PartType.Ball, Size = Vector3.new(head.X * 1.2, head.Y * 0.6, head.X * 1.2), CFrame = hc * CFrame.new(0, head.Y * 0.75, 0), Color = C3(196, 166, 100), Material = M.Wood })
            P(model, { Name = "Sash", Size = Vector3.new(body.X * 1.06, body.Y * 0.14, body.Z * 1.06), CFrame = base * CFrame.new(0, -body.Y * 0.2, 0), Color = RED, Material = M.SmoothPlastic })
            P(model, { Name = "Katana", Size = Vector3.new(0.12, 0.2, body.Z * 2.6), CFrame = base * CFrame.new(body.X * 0.55, -body.Y * 0.2, body.Z * 0.3) * CFrame.Angles(math.rad(-20), 0, 0), Color = C3(220, 224, 230), Material = M.Metal })
            P(model, { Name = "Tsuba", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.6, 0.6), CFrame = base * CFrame.new(body.X * 0.55, -body.Y * 0.32, -body.Z * 0.6) * CFrame.Angles(0, math.rad(90), 0), Color = GOLD, Material = M.Metal })
        end,
    },
    {
        Name = "PetalSprite",
        Def = { Label = "Petal Sprite", Hp = 70, Dmg = 8, Speed = 15, Body = 1.7, Head = 1.0, Color = PETAL, Range = { 24, 38 }, Fire = 2.8, Pattern = "Leaf" },
        Lore = { Role = "Shrine sprite", Text = "A blossom spirit drifting down like a falling petal. Its petal storms follow you: three in a row.", Tip = "Keep moving." },
        Attack = { Shape = "Chase", N = 3, R = 3.4, W = 0.6, Gap = 0.55, Mult = 0.6 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            for i = 0, 4 do
                local a = i / 5 * math.pi * 2
                P(model, { Name = "Wing", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 1.2, 0.15, R * 0.8), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, R * 0.2, -R * 1.0) * CFrame.Angles(math.rad(-20), 0, 0), Color = (i % 2 == 0) and PETAL or C3(255, 214, 230), Material = M.SmoothPlastic })
            end
            P(model, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.6, CFrame = base * CFrame.new(0, R * 0.25, 0), Color = C3(255, 236, 140), Glow = true })
            H.Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "sparkles_main.dds", PETAL, 5, 0.3, 0.8, 1.2, Enum.NormalId.Bottom, 60, 0.4)
        end,
    },
    {
        Name = "TempleMonk",
        Def = { Label = "Temple Monk", Hp = 180, Dmg = 9, Speed = 9, Body = 2.7, Head = 1.4, Color = C3(230, 140, 40), Range = { 30, 44 }, Fire = 3.8, Pattern = "SlowStrafe" },
        Lore = { Role = "Shrine suppressor", Text = "A levitating monk ringed by floating prayer beads. Chants a lattice of light round you: one gap is safe.", Tip = "Find the gap before it fills." },
        Attack = { Shape = "Lattice", W = 1.0, Mult = 0.9 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for i = 0, 9 do
                local a = i / 10 * math.pi * 2
                P(model, { Name = "Robe", Size = Vector3.new(R * 0.6, R * 2.0, 0.15), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, -R * 0.9, R * 1.0) * CFrame.Angles(math.rad(-12), 0, 0), Color = (i % 2 == 0) and C3(230, 140, 40) or C3(200, 110, 30), Material = M.SmoothPlastic })
            end
            for i = 0, 11 do
                local a = i / 12 * math.pi * 2
                P(model, { Name = "Kernel", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.35, CFrame = base * CFrame.new(math.cos(a) * R * 1.8, R * 0.3, math.sin(a) * R * 1.8), Color = (i % 3 == 0) and C3(255, 220, 140) or C3(110, 60, 40), Material = (i % 3 == 0) and M.Neon or M.Wood })
            end
            P(model, { Name = "Glow", Size = Vector3.new(R * 0.15, R * 0.6, 0.1), CFrame = base * CFrame.new(0, R * 0.7, -R * 1.0), Color = GOLD, Glow = true })
        end,
    },
}

-- ==================== SUPERBOSS: THE SHOGUN OF PETALS ====================
F.Super = {
    Name = "THE SHOGUN OF PETALS", Color = PETAL,
    Hitbox = { Torso = { Vector3.new(5, 8, 3.4), Vector3.new(0, 2.8, 0) }, Core = { Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 4, -1.9), "Ball" },
        Head = { Vector3.new(2.6, 2.8, 2.6), Vector3.new(0, 8.4, 0) } },
    Evade = { Amp = 11, Rate = 1.5, Dodge = 3.4 },
    Body = function(model, Mf, col, H)
        local P, W, Style = H.Part, H.Wedge, H.Style
        Style(model:FindFirstChild("Torso"), C3(40, 30, 40), H.SMOOTH)
        Style(model:FindFirstChild("Core"), PETAL, H.NEON)
        Style(model:FindFirstChild("Head"), C3(40, 30, 40), H.SMOOTH)
        -- the kabuto: a dark helm, a gold crescent crest, a menpo mask with a red grimace
        P(model, { Name = "Kabuto", Shape = Enum.PartType.Ball, Size = Vector3.new(3.2, 2.2, 3.2), CFrame = Mf(0, 9.4, 0), Color = BLACK, Material = H.METAL })
        for _, sx in ipairs({ -1, 1 }) do
            W(model, { Name = "Crest", Size = Vector3.new(0.3, 3, 0.8), CFrame = Mf(sx * 0.9, 11.2, -1.2) * CFrame.Angles(0, 0, sx * math.rad(-30)), Color = GOLD, Material = H.METAL })
            W(model, { Name = "Fukigaeshi", Size = Vector3.new(0.4, 1.4, 1.4), CFrame = Mf(sx * 1.8, 9, -0.6) * CFrame.Angles(0, sx * math.rad(30), 0), Color = RED, Material = H.SMOOTH })
            P(model, { Name = "Eye", Size = Vector3.new(0.5, 0.16, 0.1), CFrame = Mf(sx * 0.5, 8.9, -1.32), Color = PETAL, Glow = true })
        end
        P(model, { Name = "Menpo", Size = Vector3.new(2.2, 1.2, 0.4), CFrame = Mf(0, 8, -1.2), Color = RED, Material = H.SMOOTH })
        -- lacquered lamellar armour: shoulder plates (sode), a skirt of plates (kusazuri), cords
        for _, sx in ipairs({ -1, 1 }) do
            for k = 0, 2 do P(model, { Name = "Sode", Size = Vector3.new(0.4, 0.8, 2.6), CFrame = Mf(sx * (3 + k * 0.1), 6.4 - k * 0.85, 0) * CFrame.Angles(0, 0, sx * math.rad(15)), Color = (k % 2 == 0) and RED or BLACK, Material = H.SMOOTH }) end
        end
        for k = 0, 3 do P(model, { Name = "Lamellar", Size = Vector3.new(5.1, 0.6, 3.5), CFrame = Mf(0, 2 + k * 1.1, 0), Color = (k % 2 == 0) and BLACK or RED, Material = H.SMOOTH }) end
        for i = 0, 7 do
            local a = i / 8 * math.pi * 2
            P(model, { Name = "Deco_Skirt", Size = Vector3.new(1.6, 3, 0.25), CFrame = Mf(math.cos(a) * 2.5, -0.4, math.sin(a) * 1.8) * CFrame.Angles(0, -a, 0), Color = (i % 2 == 0) and RED or BLACK, Material = H.SMOOTH })
        end
        -- the nodachi held across its back, a sashimono banner, petals swirling round it
        P(model, { Name = "Deco_Blade", Size = Vector3.new(0.3, 0.5, 9), CFrame = Mf(1.6, 5, 1.6) * CFrame.Angles(math.rad(-30), math.rad(30), 0), Color = C3(230, 234, 240), Material = H.METAL })
        P(model, { Name = "Banner", Size = Vector3.new(0.2, 3.4, 1.8), CFrame = Mf(-1.2, 9.6, 2), Color = PETAL, Material = H.SMOOTH })
        P(model, { Name = "BannerPole", Size = Vector3.new(0.2, 6, 0.2), CFrame = Mf(-1.2, 8, 2.9), Color = BLACK, Material = H.SMOOTH })
        for i = 0, 7 do
            local a = i / 8 * math.pi * 2
            P(model, { Name = "Deco_Petal", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.15, 0.5), CFrame = Mf(math.cos(a) * 6, 3 + (i % 3) * 2.5, math.sin(a) * 6), Color = PETAL, Material = H.NEON })
        end
        H.Emit(model:FindFirstChild("Torso") or model.PrimaryPart, PETAL, 6, 0.35, 2, 2)
    end,
    Kit = function(H)
        local Mv, EA, Unit, Pose = H.M, H.EA, H.Unit, H.Pose
        -- (fixes 2026-10-16 #6, playtester: "shogun boss has undodgeable attacks"): every move re-timed for a walking escape --
        --   IAIJUTSU    up to 5 cuts on a 0.7 s wind-up -> 2 / 3 / 3 cuts on 1.0 s, a beat between them
        --   PETAL STORM the petals hurt after 0.3 s (no time to step off) -> 0.9 s; the burst 0.6 -> 0.95 s, a little smaller
        --   TATAMI      34-stud tiles with 0.95 s to cross to the other colour (17+ studs: not walkable) -> 22-stud tiles, 1.4 s
        --   CLOSING BLADES / CROSSED STEEL / FALLING BLOSSOMS slower + thinner; LAST BLOSSOM 3 safe circles (was 2), 1.8 s
        --   and a longer breather after each move (Recover)
        local function Iaijutsu(B)
            -- draw-cuts: each a lane across you, the next angled where you stepped
            for k = 1, math.min(3, 1 + B.phase) do
                local r = B:Root()
                if not r or not B:Alive() then return end
                local d = Unit(r.Position - B.pos)
                local side = Vector3.new(-d.Z, 0, d.X)
                local c = r.Position
                EA.Line(B.ctx, c - side * 24, c + side * 24, 4, B:W(1.0), { Mult = 1.1, Height = 9, Plain = Mv.PLAIN and Mv.PLAIN.Iaijutsu })
                B:Wait(B:W(1.0) + 0.35)
            end
            B:Wait(0.6)
        end
        local function PetalStorm(B)
            -- petals settle on you as soft circles, then all burst together
            local spots = {}
            for _ = 1, 5 do
                local r = B:Root()
                if not r or not B:Alive() then return end
                table.insert(spots, r.Position)
                EA.Zone(B.ctx, r.Position, 4, 0.9, 1.4, { Mult = 0.2, Height = 5 })
                B:Wait(0.35)
            end
            for _, p in ipairs(spots) do EA.Circle(B.ctx, p, 4.5, B:W(0.95), { Mult = 0.9 }) end
            B:Wait(B:W(0.95) + 0.5)
        end
        return {
            Color = PETAL, Move = "Chase", Range = 22, SpeedMul = 1.0, Recover = { 2.3, 2.0, 1.7 },
            Names = { "THE SHOGUN OF PETALS", "THE SHOGUN OF PETALS: DRAWN BLADE", "THE SHOGUN OF PETALS: LAST BLOSSOM" },
            Moves = {
                { { Iaijutsu, "IAIJUTSU" }, { PetalStorm, "PETAL STORM" }, { function(B) Mv.Step(B, 30, 0.8) end, "FOOTWORK" } },
                { { function(B) Mv.Pincer(B, 12, 1.1, 0.55) end, "CLOSING BLADES" }, { Iaijutsu, "IAIJUTSU" }, { function(B) Mv.Checker(B, 22, 1.4) end, "TATAMI" },
                    { PetalStorm, "PETAL STORM" } },
                { { function(B) Mv.Crossfire(B, 2, 5, 1.15) end, "CROSSED STEEL" }, { Iaijutsu, "IAIJUTSU" }, { function(B) Mv.Rain(B, 6, 4.5, 0.9, 0, 0.45) end, "FALLING BLOSSOMS" },
                    { function(B) Mv.ArenaWipe(B, 3, 9, 1.8) end, "LAST BLOSSOM" } },
            },
            Animate = function(B, pivot, now)
                Pose(B, "Deco_Petal", pivot, CFrame.new(0, 4, 0), CFrame.Angles(0, now * 0.8, 0))
                Pose(B, "Deco_Skirt", pivot, CFrame.new(0, 1, 0), CFrame.Angles(math.sin(now * 1.6) * 0.05, 0, math.cos(now * 1.3) * 0.05))
            end,
        }
    end,
}
return F
