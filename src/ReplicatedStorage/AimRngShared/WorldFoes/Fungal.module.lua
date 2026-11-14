--!nocheck
-- SPORE WORLD foes (0.89): the fungal life of an alien planet. Superboss THE MYCELIUM HEART.
local C3 = Color3.fromRGB
local M = Enum.Material
local CAP, CAP2, CAP3, STEM, GILL, GILL2, SPORE = C3(150, 70, 190), C3(70, 150, 190), C3(220, 90, 130), C3(200, 190, 220), C3(90, 255, 220), C3(255, 120, 230), C3(170, 255, 200)

local F = {}
F.Specialist = "MotherCap"
F.Enemies = {
    {
        Name = "Shroomling", Weight = 2,
        Def = { Label = "Shroomling", Hp = 85, Dmg = 10, Speed = 18, Body = 1.9, Head = 1.2, Color = CAP3, Range = { 18, 32 }, Fire = 2.6, Pattern = "Bounce" },
        Lore = { Role = "Spore hopper", Text = "A little mushroom that bounces on its cap. Bursts a puff of spores where you stand.", Tip = "Keep moving." },
        Attack = { Shape = "Burst", R = 4.6, W = 0.75, Mult = 0.9 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 2.6, R * 1.3, R * 2.6), CFrame = base * CFrame.new(0, R * 0.8, 0), Color = CAP3, Material = M.SmoothPlastic })
            P(model, { Name = "Glow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, R * 2.2, R * 2.2), CFrame = base * CFrame.new(0, R * 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GILL2, Glow = true })
            for k = 0, 4 do
                local a = k * 1.3
                P(model, { Name = "Spot", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.4, CFrame = base * CFrame.new(math.cos(a) * R * 0.8, R * 1.3, math.sin(a) * R * 0.8), Color = C3(250, 240, 250), Material = M.SmoothPlastic })
            end
            P(model, { Name = "Stem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 1.2, R * 0.9, R * 0.9), CFrame = base * CFrame.new(0, -R * 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STEM, Material = M.SmoothPlastic })
        end,
    },
    {
        Name = "SporePuffer",
        Def = { Label = "Spore Puffer", Hp = 80, Dmg = 9, Speed = 14, Body = 1.9, Head = 1.1, Color = C3(210, 190, 230), Range = { 22, 34 }, Fire = 2.6, Pattern = "Popcorn" },
        Lore = { Role = "Spore popper", Text = "A puffball that pops up and drifts down, venting spores. Its spore clouds follow you: three in a row.", Tip = "Keep moving: each lands where you were." },
        Attack = { Shape = "Chase", N = 3, R = 3.4, W = 0.6, Gap = 0.55, Mult = 0.6 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Puff", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 2.4, CFrame = base, Color = C3(220, 200, 236), Material = M.SmoothPlastic })
            for k = 0, 5 do
                local a, b = k * 1.05, ((k % 2) - 0.5) * 0.8
                P(model, { Name = "Vent", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.35, CFrame = base * CFrame.Angles(b, a, 0) * CFrame.new(0, 0, -R * 1.15), Color = SPORE, Glow = true })
            end
            H.Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "sparkles_main.dds", SPORE, 8, 0.3, 1.2, 1.2, Enum.NormalId.Top, 180, 0.9)
        end,
    },
    {
        Name = "LanternCap",
        Def = { Label = "Lantern Cap", Hp = 90, Dmg = 9, Speed = 15, Body = 2.0, Head = 1.2, Color = CAP2, Range = { 24, 38 }, Fire = 3.0, Pattern = "Pendulum" },
        Lore = { Role = "Spore swinger", Text = "A glowing cap hanging from its own tendrils, swinging. Drops a row of glowing spores along its line to you.", Tip = "Shoot it at the ends of its swing; sidestep the row." },
        Attack = { Shape = "Row", N = 5, R = 3, Gap = 4.2, W = 0.8, Mult = 0.7 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 2.8, R * 1.2, R * 2.8), CFrame = base * CFrame.new(0, R * 0.6, 0), Color = CAP2, Material = M.SmoothPlastic })
            P(model, { Name = "Glow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, R * 2.4, R * 2.4), CFrame = base * CFrame.new(0, R * 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GILL, Glow = true })
            for i = 0, 7 do
                local a = i / 8 * math.pi * 2
                P(model, { Name = "Tendril", Size = Vector3.new(0.12, R * (1.2 + (i % 3) * 0.4), 0.12), CFrame = base * CFrame.new(math.cos(a) * R * 1.0, -R * 0.6, math.sin(a) * R * 1.0), Color = GILL, Glow = true, Transparency = 0.3 })
            end
        end,
    },
    {
        Name = "Mycelid", Weight = 2,
        Def = { Label = "Mycelid", Hp = 130, Dmg = 11, Speed = 16, Body = 2.2, Head = 1.3, Color = C3(120, 90, 150), Range = { 16, 28 }, Fire = 2.8, Pattern = "Stutter", Ground = true },
        Lore = { Role = "Spore walker", Text = "A walking mass of fungus with shelf fungi growing off it. Freezes, then lurches on. Breathes a cone of spores at you.", Tip = "Free shots while it freezes; get out of the cone." },
        Attack = { Shape = "Cone", Half = 22, Past = 12, W = 0.85, Mult = 0.9 },
        Decor = function(model, H)
            local P, body, base, hc, head = H.Part, H.body, H.base, H.headCF, H.head
            for k = 0, 3 do
                local sx = (k % 2 == 0) and 1 or -1
                P(model, { Name = "Shelf", Size = Vector3.new(body.X * 0.6, 0.2, body.Z * 0.5), CFrame = base * CFrame.new(sx * body.X * 0.55, body.Y * (0.3 - k * 0.2), 0) * CFrame.Angles(0, 0, sx * -0.2), Color = C3(230, 150, 90), Material = M.SmoothPlastic })
                P(model, { Name = "LightStrip", Size = Vector3.new(body.X * 0.62, 0.08, 0.08), CFrame = base * CFrame.new(sx * body.X * 0.55, body.Y * (0.3 - k * 0.2) - 0.1, -body.Z * 0.25), Color = GILL, Glow = true })
            end
            P(model, { Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(head.X * 1.8, head.Y * 0.8, head.X * 1.8), CFrame = hc * CFrame.new(0, head.Y * 0.55, 0), Color = CAP, Material = M.SmoothPlastic })
            for _, sx in ipairs({ -1, 1 }) do P(model, { Name = "FrostEye", Shape = Enum.PartType.Ball, Size = Vector3.one * head.X * 0.22, CFrame = hc * CFrame.new(sx * head.X * 0.22, 0, -head.Z * 0.48), Color = GILL, Glow = true }) end
        end,
    },
    {
        Name = "SporeBat", Hard = true,
        Def = { Label = "Spore Bat", Hp = 70, Dmg = 9, Speed = 20, Body = 1.7, Head = 1.0, Color = C3(90, 60, 140), Range = { 22, 34 }, Fire = 2.6, Pattern = "Flap" },
        Lore = { Role = "Spore flyer", Text = "An alien bat with glowing membrane wings, beating then gliding. Dives a lane through you.", Tip = "Strafe across the lane." },
        Attack = { Shape = "Lane", Width = 4.4, Past = 16, W = 0.85, Mult = 1.0 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for _, sx in ipairs({ -1, 1 }) do
                W(model, { Name = "Wing", Size = Vector3.new(0.1, R * 1.6, R * 2.2), CFrame = base * CFrame.new(sx * R * 1.5, R * 0.2, R * 0.2) * CFrame.Angles(0, 0, math.rad(sx * 80)), Color = C3(70, 40, 110), Material = M.SmoothPlastic, Transparency = 0.1 })
                P(model, { Name = "WingEdge", Size = Vector3.new(R * 2.6, 0.1, 0.1), CFrame = base * CFrame.new(sx * R * 1.5, R * 0.25, -R * 0.9), Color = GILL2, Glow = true })
                W(model, { Name = "Ear", Size = Vector3.new(0.12, R * 0.6, R * 0.4), CFrame = base * CFrame.new(sx * R * 0.4, R * 1.0, -R * 0.4), Color = C3(70, 40, 110), Material = M.SmoothPlastic })
            end
            for _, sx in ipairs({ -1, 1 }) do P(model, { Name = "EyeSpot", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.25, CFrame = base * CFrame.new(sx * R * 0.3, R * 0.25, -R * 0.9), Color = SPORE, Glow = true }) end
        end,
    },
    {
        Name = "MotherCap",
        Def = { Label = "Mother Cap", Hp = 185, Dmg = 9, Speed = 9, Body = 2.8, Head = 1.4, Color = CAP, Range = { 30, 44 }, Fire = 3.8, Pattern = "SlowStrafe" },
        Lore = { Role = "Spore suppressor", Text = "A huge floating mushroom trailing glowing tendrils. Spreads a lattice of spore lanes round you: one gap is safe.", Tip = "Find the gap before it fills." },
        Attack = { Shape = "Lattice", W = 1.0, Mult = 0.9 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 3.4, R * 1.5, R * 3.4), CFrame = base * CFrame.new(0, R * 0.8, 0), Color = CAP, Material = M.SmoothPlastic })
            P(model, { Name = "Glow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, R * 3, R * 3), CFrame = base * CFrame.new(0, R * 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GILL, Glow = true })
            for i = 0, 9 do
                local a = i / 10 * math.pi * 2
                P(model, { Name = "Tendril", Size = Vector3.new(0.15, R * (1.6 + (i % 3) * 0.5), 0.15), CFrame = base * CFrame.new(math.cos(a) * R * 1.3, -R * 0.9, math.sin(a) * R * 1.3), Color = (i % 2 == 0) and GILL or GILL2, Glow = true, Transparency = 0.2 })
            end
            for k = 0, 5 do
                local a = k * 1.05
                P(model, { Name = "Spot", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.45, CFrame = base * CFrame.new(math.cos(a) * R * 1.1, R * 1.4, math.sin(a) * R * 1.1), Color = C3(250, 240, 250), Material = M.SmoothPlastic })
            end
        end,
    },
}

-- ==================== SUPERBOSS: THE MYCELIUM HEART ====================
F.Super = {
    Name = "THE MYCELIUM HEART", Color = GILL,
    Hitbox = { Torso = { Vector3.new(6, 7, 6), Vector3.new(0, 2, 0) }, Core = { Vector3.new(2.8, 2.8, 2.8), Vector3.new(0, 2.6, -3.1), "Ball" },
        Head = { Vector3.new(2.6, 2.6, 2.6), Vector3.new(0, 7.2, 0), "Ball" } },
    Evade = { Amp = 9, Rate = 1.2, Dodge = 4 },
    Body = function(model, Mf, col, H)
        local P, W, Style = H.Part, H.Wedge, H.Style
        Style(model:FindFirstChild("Torso"), C3(80, 50, 110), H.SMOOTH)
        Style(model:FindFirstChild("Core"), GILL, H.NEON)
        Style(model:FindFirstChild("Head"), GILL2, H.NEON)
        -- a towering cap crown, glowing gill rings under it, a knot of root-tendrils for a body
        P(model, { Name = "Deco_Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(12, 4.4, 12), CFrame = Mf(0, 9.6, 0), Color = CAP, Material = H.SMOOTH })
        P(model, { Name = "Deco_Gill", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 10.5, 10.5), CFrame = Mf(0, 7.9, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GILL, Material = H.NEON })
        for k = 0, 7 do
            local a = k / 8 * math.pi * 2
            P(model, { Name = "Deco_Cap", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = Mf(math.cos(a) * 3.8, 11.2, math.sin(a) * 3.8), Color = C3(250, 240, 250), Material = H.SMOOTH })
        end
        for i = 0, 9 do
            local a = i / 10 * math.pi * 2
            local root = Vector3.new(math.cos(a) * 2.6, -1.5, math.sin(a) * 2.6)
            for k = 0, 2 do
                local p = root + Vector3.new(math.cos(a) * k * 1.5, -k * 1.2, math.sin(a) * k * 1.5)
                P(model, { Name = "Deco_Root", Shape = Enum.PartType.Ball, Size = Vector3.one * (1.4 - k * 0.35), CFrame = Mf(p.X, p.Y, p.Z), Color = (k == 2) and GILL or C3(110, 80, 140), Material = (k == 2) and H.NEON or H.SMOOTH })
            end
        end
        -- small mushrooms sprouting from its shoulders, spores pouring off the cap
        for _, sx in ipairs({ -1, 1 }) do
            P(model, { Name = "Sprout", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 1.1, 2.4), CFrame = Mf(sx * 3.6, 6, 1), Color = CAP2, Material = H.SMOOTH })
            P(model, { Name = "SproutStem", Size = Vector3.new(0.5, 1.6, 0.5), CFrame = Mf(sx * 3.6, 5, 1), Color = STEM, Material = H.SMOOTH })
        end
        local spores = P(model, { Name = "SporeVent", Size = Vector3.new(8, 0.5, 8), CFrame = Mf(0, 7.6, 0), Transparency = 1 })
        H.Emit(spores, SPORE, 10, 0.35, 2, 2.2)
    end,
    Kit = function(H)
        local Mv, EA, Unit, Pose = H.M, H.EA, H.Unit, H.Pose
        local function SporeBloom(B)
            -- spores settle round you in a ring of four, then burst on you
            local r = B:Root()
            if not r then return end
            local at = r.Position
            for k = 0, 3 do
                local a = k * math.pi / 2 + math.pi / 4
                EA.Circle(B.ctx, at + Vector3.new(math.cos(a) * 7, 0, math.sin(a) * 7), 4.5, B:W(0.8), { Mult = 0.9 })
            end
            task.delay(B:W(0.8) + 0.4, function()
                local r2 = B:Root()
                if B:Alive() and r2 then EA.Circle(B.ctx, r2.Position, 5, B:W(0.6), { Mult = 1.0 }) end
            end)
            B:Wait(B:W(0.8) + 1.2)
        end
        local function RootBurst(B)
            -- roots burst up along your path: a lane of circles from it toward you, twice
            for _ = 1, 2 do
                local r = B:Root()
                if not r or not B:Alive() then return end
                local d = Unit(r.Position - B.pos)
                for i = 1, 7 do
                    local at = B:Clamp(B.pos + d * (5 + i * 6.5))
                    task.delay(i * 0.08, function() if B:Alive() then EA.Circle(B.ctx, at, 3.4, B:W(0.7), { Mult = 1.0 }) end end)
                end
                B:Wait(B:W(0.7) + 0.6)
            end
        end
        return {
            Color = GILL, Move = "Orbit", Range = 32, SpeedMul = 0.8, Recover = { 1.9, 1.6, 1.3 },
            Names = { "THE MYCELIUM HEART", "THE MYCELIUM HEART: BLOOMING", "THE MYCELIUM HEART: OVERGROWTH" },
            Moves = {
                { { SporeBloom, "SPORE BLOOM" }, { RootBurst, "ROOT BURST" }, { function(B) Mv.Rain(B, 6, 6, 0.85, 0, 0.42) end, "SPORE FALL" } },
                { { function(B) Mv.Pools(B, 4) end, "ROT POOLS" }, { SporeBloom, "SPORE BLOOM" }, { function(B) Mv.Cage(B, 8, 12, 1.0) end, "FAIRY RING" },
                    { RootBurst, "ROOT BURST" } },
                { { function(B) Mv.Converge(B, 2, 1.0) end, "TENDRIL SURGE" }, { RootBurst, "ROOT BURST" }, { function(B) Mv.Checker(B, 34, 0.95) end, "MYCELIUM GRID" },
                    { function(B) Mv.ArenaWipe(B, 2, 8, 1.5) end, "OVERGROWTH" } },
            },
            Animate = function(B, pivot, now)
                Pose(B, "Deco_Cap", pivot, CFrame.new(0, 9.6, 0), CFrame.Angles(0, now * 0.15, math.sin(now * 0.9) * 0.03))
                Pose(B, "Deco_Gill", pivot, CFrame.new(0, 7.9, 0), CFrame.Angles(0, now * 0.15, 0))
                Pose(B, "Deco_Root", pivot, CFrame.new(0, -1.5, 0), CFrame.Angles(math.sin(now * 1.3) * 0.06, math.sin(now * 0.5) * 0.15, math.cos(now * 1.1) * 0.06))
            end,
        }
    end,
}
return F
