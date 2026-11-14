--!nocheck
-- SUN DUNES foes (0.89): the guardians of a buried sun empire. Superboss PHARAOH SUNKA.
local C3 = Color3.fromRGB
local M = Enum.Material
local GOLD, LAPIS, SAND, LINEN, STONE = C3(236, 186, 74), C3(46, 90, 180), C3(214, 180, 128), C3(226, 214, 186), C3(200, 162, 110)

local F = {}
F.Specialist = "SunPriest"
F.Enemies = {
    {
        Name = "Scarab", Weight = 2,
        Def = { Label = "Scarab", Hp = 140, Dmg = 11, Speed = 18, Body = 2.3, Head = 1.2, Color = C3(60, 160, 140), Range = { 18, 30 }, Fire = 3.0, Pattern = "Roll" },
        Lore = { Role = "Dune roller", Text = "A sacred beetle as big as a boulder, rolling low over the sand. Kicks a wall of sand rolling at you.", Tip = "Track it low; jump the wall." },
        Attack = { Shape = "Roller", L = 20, W = 0.7, Mult = 0.9 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for _, sx in ipairs({ -1, 1 }) do
                P(model, { Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 1.2, R * 1.3, R * 2.3), CFrame = base * CFrame.new(sx * R * 0.55, R * 0.3, R * 0.1), Color = C3(30, 120, 110), Material = M.Metal })
                for k = 0, 2 do P(model, { Name = "Leg", Size = Vector3.new(R * 0.9, 0.12, 0.12), CFrame = base * CFrame.new(sx * R * 1.15, -R * 0.55, (k - 1) * R * 0.6) * CFrame.Angles(0, 0, sx * math.rad(-30)), Color = C3(20, 40, 40), Material = M.Metal }) end
            end
            P(model, { Name = "ShellSeam", Size = Vector3.new(0.12, R * 0.3, R * 2.2), CFrame = base * CFrame.new(0, R * 0.95, R * 0.1), Color = GOLD, Glow = true })
            W(model, { Name = "Horn", Size = Vector3.new(0.3, R * 0.9, R * 0.6), CFrame = base * CFrame.new(0, R * 0.4, -R * 1.25) * CFrame.Angles(math.rad(-20), 0, 0), Color = GOLD, Material = M.Metal })
        end,
    },
    {
        Name = "BandageWisp", Hard = true,
        Def = { Label = "Bandage Wisp", Hp = 85, Dmg = 9, Speed = 18, Body = 1.9, Head = 1.15, Color = LINEN, Range = { 20, 32 }, Fire = 2.6, Pattern = "Afterimage" },
        Lore = { Role = "Dune ghost", Text = "A mummy's wrappings with nothing inside, dashing off in a blink and leaving its old shape behind. Leaves a trail of cursed sand where you were heading.", Tip = "Ignore the afterimage; keep off the trail." },
        Attack = { Shape = "Trail", N = 3, R = 3.6, Gap = 5, W = 0.7, Mult = 0.3, Life = 2.4 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            for k = 0, 4 do
                P(model, { Name = "Wrap", Size = Vector3.new(R * 2.1, R * 0.28, R * 2.1), CFrame = base * CFrame.new(0, R * (0.75 - k * 0.38), 0) * CFrame.Angles(0, k * 0.4, math.rad((k % 2 == 0) and 8 or -8)), Color = (k % 2 == 0) and LINEN or C3(196, 182, 150), Material = M.SmoothPlastic })
            end
            for i = 0, 3 do
                local a = i * 1.5
                P(model, { Name = "Streamer", Size = Vector3.new(R * 0.3, 0.08, R * (1.8 + i * 0.3)), CFrame = base * CFrame.new(math.cos(a) * R * 0.5, -R * 0.4 + i * R * 0.2, R * (1.0 + i * 0.15)), Color = LINEN, Material = M.SmoothPlastic })
            end
            P(model, { Name = "EyeSpot", Size = Vector3.new(R * 0.8, R * 0.14, 0.1), CFrame = base * CFrame.new(0, R * 0.4, -R * 1.07), Color = C3(80, 220, 255), Glow = true })
        end,
    },
    {
        Name = "SandDjinn", Hard = true,
        Def = { Label = "Sand Djinn", Hp = 80, Dmg = 9, Speed = 18, Body = 1.9, Head = 1.1, Color = C3(230, 170, 90), Range = { 22, 34 }, Fire = 2.6, Pattern = "Corkscrew" },
        Lore = { Role = "Dune spirit", Text = "A djinn whose lower half is a whirl of sand, climbing in a corkscrew and dropping. Its sand strikes follow you: three in a row.", Tip = "Keep moving." },
        Attack = { Shape = "Chase", N = 3, R = 3.4, W = 0.6, Gap = 0.5, Mult = 0.6 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            P(model, { Name = "Turban", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 1.7, R * 1.0, R * 1.7), CFrame = base * CFrame.new(0, R * 1.0, 0), Color = C3(150, 40, 60), Material = M.SmoothPlastic })
            P(model, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.35, CFrame = base * CFrame.new(0, R * 1.1, -R * 0.85), Color = LAPIS, Glow = true })
            for _, sx in ipairs({ -1, 1 }) do
                P(model, { Name = "Bangle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, R * 0.6, R * 0.6), CFrame = base * CFrame.new(sx * R * 1.15, -R * 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = M.Metal })
            end
            for k = 0, 2 do
                W(model, { Name = "Tendril", Size = Vector3.new(R * (1.4 - k * 0.35), R * 0.5, R * (1.4 - k * 0.35)), CFrame = base * CFrame.new(0, -R * (1.0 + k * 0.5), 0) * CFrame.Angles(0, k * 1.2, math.pi), Color = SAND, Material = M.Sand })
            end
            H.Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "smoke_main.dds", SAND, 6, 1.0, 1.5, 0.8, Enum.NormalId.Bottom, 50, 0.1)
        end,
    },
    {
        Name = "IbisSentry",
        Def = { Label = "Ibis Sentry", Hp = 90, Dmg = 11, Speed = 15, Body = 2.0, Head = 1.2, Color = C3(30, 30, 40), Range = { 30, 46 }, Fire = 3.0, Pattern = "Tracking" },
        Lore = { Role = "Dune sentry", Text = "A temple guardian with the head of an ibis. Tracks you smoothly and shoots a long, narrow sun beam through you.", Tip = "A small sidestep is enough." },
        Attack = { Shape = "Lane", Width = 3, Past = 24, Max = 70, W = 0.9, Mult = 1.0 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            W(model, { Name = "Beak", Size = Vector3.new(R * 0.2, R * 0.25, R * 1.8), CFrame = base * CFrame.new(0, R * 0.1, -R * 1.7) * CFrame.Angles(math.rad(-15), math.pi, 0), Color = C3(40, 40, 40), Material = M.SmoothPlastic })
            P(model, { Name = "Collar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 0.4, R * 2.2, R * 2.2), CFrame = base * CFrame.new(0, -R * 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = M.Metal })
            P(model, { Name = "CollarBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 0.15, R * 2.25, R * 2.25), CFrame = base * CFrame.new(0, -R * 0.45, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = LAPIS, Material = M.SmoothPlastic })
            for _, sx in ipairs({ -1, 1 }) do
                W(model, { Name = "Wing", Size = Vector3.new(0.12, R * 1.0, R * 1.9), CFrame = base * CFrame.new(sx * R * 1.25, R * 0.1, R * 0.4) * CFrame.Angles(0, 0, math.rad(sx * 70)), Color = C3(240, 236, 226), Material = M.SmoothPlastic })
                P(model, { Name = "Lens", Size = Vector3.new(R * 0.22, R * 0.14, 0.1), CFrame = base * CFrame.new(sx * R * 0.38, R * 0.35, -R * 0.95), Color = GOLD, Glow = true })
            end
        end,
    },
    {
        Name = "SunDisk",
        Def = { Label = "Sun Disk", Hp = 90, Dmg = 9, Speed = 16, Body = 2.0, Head = 1.2, Color = GOLD, Range = { 20, 32 }, Fire = 2.8, Pattern = "Orbit" },
        Lore = { Role = "Dune glare", Text = "A floating disc of gold rimmed with rays, strafing back and forth in front of you. Glares a wide cone at you.", Tip = "Get out of the cone, sideways." },
        Attack = { Shape = "Cone", Half = 24, Past = 14, W = 0.85, Mult = 0.9 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Disc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, R * 2.4, R * 2.4), CFrame = base * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(-R * 0.2, 0, 0), Color = GOLD, Material = M.Metal })
            P(model, { Name = "ChestCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, R * 1.0, R * 1.0), CFrame = base * CFrame.new(0, 0, -R * 0.45) * CFrame.Angles(0, math.rad(90), 0), Color = LAPIS, Glow = true })
            for i = 0, 11 do
                local a = i / 12 * math.pi * 2
                P(model, { Name = "StarPoint", Size = Vector3.new(0.2, R * (0.6 + (i % 2) * 0.4), 0.3), CFrame = base * CFrame.new(0, 0, -R * 0.1) * CFrame.Angles(0, 0, a) * CFrame.new(0, R * 1.5, 0), Color = (i % 2 == 0) and GOLD or C3(255, 220, 140), Glow = i % 2 == 1 })
            end
        end,
    },
    {
        Name = "SunPriest",
        Def = { Label = "Sun Priest", Hp = 185, Dmg = 9, Speed = 9, Body = 2.8, Head = 1.4, Color = LAPIS, Range = { 30, 44 }, Fire = 3.8, Pattern = "SlowStrafe" },
        Lore = { Role = "Dune suppressor", Text = "A floating obelisk-priest with a burning eye of gold. Draws a square of sun lanes round you, then burns the middle.", Tip = "Leave the square before it closes." },
        Attack = { Shape = "Grid", Gap = 6, W = 0.95, Mult = 0.9 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            P(model, { Name = "Obelisk", Size = Vector3.new(R * 1.3, R * 3.2, R * 1.3), CFrame = base * CFrame.new(0, -R * 0.2, R * 0.2), Color = STONE, Material = M.Sandstone })
            for k = 0, 3 do W(model, { Name = "Cap", Size = Vector3.new(R * 1.3, R * 0.7, R * 0.65), CFrame = base * CFrame.new(0, R * 1.75, R * 0.2) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -R * 0.33), Color = GOLD, Material = M.Metal }) end
            P(model, { Name = "EyeSpot", Size = Vector3.new(R * 0.9, R * 0.35, 0.1), CFrame = base * CFrame.new(0, R * 0.5, -R * 1.05), Color = GOLD, Glow = true })
            P(model, { Name = "Pupil", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.3, R * 0.3, 0.1), CFrame = base * CFrame.new(0, R * 0.5, -R * 1.1), Color = LAPIS, Glow = true })
            for k = 0, 2 do P(model, { Name = "Vein", Size = Vector3.new(R * 1.35, 0.12, R * 1.35), CFrame = base * CFrame.new(0, -R * (0.6 + k * 0.5), R * 0.2), Color = LAPIS, Glow = true }) end
        end,
    },
}

-- ==================== SUPERBOSS: PHARAOH SUNKA ====================
F.Super = {
    Name = "PHARAOH SUNKA", Color = GOLD,
    Hitbox = { Torso = { Vector3.new(5, 8.4, 3.4), Vector3.new(0, 2.6, 0) }, Core = { Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 4, -1.9), "Ball" },
        Head = { Vector3.new(2.6, 3, 2.6), Vector3.new(0, 8.6, 0) } },
    Evade = { Amp = 9, Rate = 1.2, Dodge = 4 },
    Body = function(model, Mf, col, H)
        local P, W, Style = H.Part, H.Wedge, H.Style
        Style(model:FindFirstChild("Torso"), LINEN, H.SMOOTH)
        Style(model:FindFirstChild("Core"), GOLD, H.NEON)
        Style(model:FindFirstChild("Head"), GOLD, H.METAL)
        -- the nemes headdress: striped lappets falling either side, a cobra on the brow, a braided beard
        for _, sx in ipairs({ -1, 1 }) do
            for k = 0, 3 do P(model, { Name = "Nemes", Size = Vector3.new(0.6, 0.7, 2.2), CFrame = Mf(sx * 1.6, 9.4 - k * 0.75, -0.1) * CFrame.Angles(0, 0, sx * math.rad(10)), Color = (k % 2 == 0) and GOLD or LAPIS, Material = H.SMOOTH }) end
            P(model, { Name = "Eye", Size = Vector3.new(0.6, 0.2, 0.15), CFrame = Mf(sx * 0.55, 8.8, -1.32), Color = C3(80, 220, 255), Glow = true })
        end
        P(model, { Name = "NemesTop", Shape = Enum.PartType.Ball, Size = Vector3.new(3.2, 1.6, 3), CFrame = Mf(0, 9.9, 0), Color = GOLD, Material = H.METAL })
        W(model, { Name = "Cobra", Size = Vector3.new(0.5, 1.2, 0.6), CFrame = Mf(0, 10.4, -1.3), Color = GOLD, Material = H.METAL })
        P(model, { Name = "Beard", Size = Vector3.new(0.5, 1.6, 0.5), CFrame = Mf(0, 7.1, -1.1), Color = LAPIS, Material = H.SMOOTH })
        -- wrapped body bands, a broad collar, crook + flail crossed over the chest
        for k = 0, 5 do P(model, { Name = "Wrap", Size = Vector3.new(5.1, 0.3, 3.5), CFrame = Mf(0, -0.6 + k * 1.2, 0) * CFrame.Angles(0, 0, math.rad((k % 2 == 0) and 4 or -4)), Color = (k % 2 == 0) and LINEN or C3(196, 182, 150), Material = H.SMOOTH }) end
        P(model, { Name = "Collar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 6, 6), CFrame = Mf(0, 6.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = LAPIS, Material = H.SMOOTH })
        P(model, { Name = "CollarGold", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.65, 5, 5), CFrame = Mf(0, 6.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = H.METAL })
        for _, sx in ipairs({ -1, 1 }) do
            P(model, { Name = "Deco_Crook", Size = Vector3.new(0.35, 6, 0.35), CFrame = Mf(sx * 0.6, 4.4, -2.2) * CFrame.Angles(0, 0, sx * math.rad(35)), Color = (sx < 0) and LAPIS or GOLD, Material = H.METAL })
        end
        -- the sun disc halo behind it (turns), robes flowing below
        local hc = Mf(0, 8.5, 2.4)
        P(model, { Name = "Deco_Halo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 7, 7), CFrame = hc * CFrame.Angles(0, math.rad(90), 0), Color = GOLD, Material = H.NEON, Transparency = 0.2 })
        for i = 0, 11 do P(model, { Name = "Deco_Halo", Size = Vector3.new(0.3, 2, 0.3), CFrame = hc * CFrame.Angles(0, 0, i / 12 * math.pi * 2) * CFrame.new(0, 4.4, 0), Color = GOLD, Material = H.METAL }) end
        for i = 0, 9 do
            local a = i / 10 * math.pi * 2
            P(model, { Name = "Deco_Robe", Size = Vector3.new(1.6, 5, 0.2), CFrame = Mf(math.cos(a) * 2.6, -3.4, math.sin(a) * 1.8) * CFrame.Angles(0, -a, 0), Color = (i % 2 == 0) and LINEN or GOLD, Material = H.SMOOTH })
        end
        H.Emit(model:FindFirstChild("Torso") or model.PrimaryPart, SAND, 6, 0.4, 2, 1.8)
    end,
    Kit = function(H)
        local Mv, EA, Unit, Pose = H.M, H.EA, H.Unit, H.Pose
        local function SunBeams(B)
            -- twin sun beams: two lanes either side of you that close onto you
            local r = B:Root()
            if not r then return end
            local dir = Unit(r.Position - B.pos)
            local side = Vector3.new(-dir.Z, 0, dir.X)
            for k, off in ipairs({ 7, 3.5, 0 }) do
                task.delay((k - 1) * 0.45, function()
                    if not B:Alive() then return end
                    for _, sx in ipairs(off == 0 and { 0 } or { -1, 1 }) do
                        local o = side * sx * off
                        EA.Line(B.ctx, B.pos + o, B.pos + o + dir * 70, 3.6, B:W(0.8), { Mult = 1.0, Height = 9 })
                    end
                end)
            end
            B:Wait(B:W(0.8) + 1.3)
        end
        return {
            Color = GOLD, Move = "Orbit", Range = 32, SpeedMul = 0.85, Recover = { 1.9, 1.6, 1.3 },
            Names = { "PHARAOH SUNKA", "PHARAOH SUNKA: THE SCORCHING", "PHARAOH SUNKA: EVERLASTING" },
            Moves = {
                { { SunBeams, "SUN BEAMS" }, { function(B) Mv.Footsteps(B, 7, 6) end, "SANDS OF TIME" }, { function(B) Mv.Roll(B, 3, 6, 52, "Ball", true) end, "SCARAB SWARM" } },
                { { function(B) Mv.Pools(B, 4) end, "PLAGUE OF SAND" }, { SunBeams, "SUN BEAMS" }, { function(B) Mv.Tide(B, 3, true) end, "DUNE SHIFT" },
                    { function(B) Mv.Halves(B, 1.4) end, "JUDGEMENT" } },
                { { function(B) Mv.Quadrants(B, 70, 2, 0.9) end, "FOUR WINDS" }, { SunBeams, "SUN BEAMS" }, { function(B) Mv.Rain(B, 8, 6, 0.85, 0, 0.4) end, "SUN FALL" },
                    { function(B) Mv.ArenaWipe(B, 2, 8, 1.5) end, "ECLIPSE" } },
            },
            Animate = function(B, pivot, now)
                Pose(B, "Deco_Halo", pivot, CFrame.new(0, 8.5, 2.4), CFrame.Angles(0, 0, now * 0.4))
                Pose(B, "Deco_Robe", pivot, CFrame.new(0, -1, 0), CFrame.Angles(math.sin(now * 1.2) * 0.05, 0, math.cos(now * 1.0) * 0.05))
                Pose(B, "Deco_Crook", pivot, CFrame.new(0, 4.4, -2.2), CFrame.Angles(math.sin(now * 0.8) * 0.06, 0, 0))
            end,
        }
    end,
}
return F
