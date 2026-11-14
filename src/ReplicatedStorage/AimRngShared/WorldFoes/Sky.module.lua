--!nocheck
-- BRASS SKYPORT foes (0.89): the clockwork guard of a city above the clouds. Superboss ADMIRAL COGSWORTH.
local C3 = Color3.fromRGB
local M = Enum.Material
local BRASS, COPPER, IRON, CANVAS, CANVAS2, LAMP, GLASS = C3(200, 156, 80), C3(176, 104, 70), C3(56, 54, 52), C3(220, 200, 170), C3(180, 70, 60), C3(255, 210, 140), C3(150, 220, 255)

local F = {}
F.Specialist = "Dirigible"
F.Enemies = {
    {
        Name = "ClockOwl", Hard = true,
        Def = { Label = "Clockwork Owl", Hp = 85, Dmg = 10, Speed = 18, Body = 1.9, Head = 1.2, Color = BRASS, Range = { 22, 34 }, Fire = 2.8, Pattern = "Flap" },
        Lore = { Role = "Skyport sentinel", Text = "A brass owl with gear-wheel eyes and riveted wings. Its eyes tick two strikes either side of you.", Tip = "Stay in the gap between them." },
        Attack = { Shape = "Pair", Gap = 3.6, R = 3.6, W = 0.75, Mult = 0.8 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for _, sx in ipairs({ -1, 1 }) do
                P(model, { Name = "Lens", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, R * 0.75, R * 0.75), CFrame = base * CFrame.new(sx * R * 0.42, R * 0.3, -R * 0.98) * CFrame.Angles(0, math.rad(90), 0), Color = LAMP, Glow = true })
                P(model, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.18, R * 0.95, R * 0.95), CFrame = base * CFrame.new(sx * R * 0.42, R * 0.3, -R * 0.95) * CFrame.Angles(0, math.rad(90), 0), Color = COPPER, Material = M.Metal })
                for f = 0, 2 do W(model, { Name = "Wing", Size = Vector3.new(0.12, R * 0.7, R * (1.9 - f * 0.3)), CFrame = base * CFrame.new(sx * R * (1.1 + f * 0.4), -f * R * 0.2, R * 0.2) * CFrame.Angles(0, 0, math.rad(sx * 80)), Color = (f % 2 == 0) and BRASS or COPPER, Material = M.Metal }) end
                W(model, { Name = "Ear", Size = Vector3.new(0.12, R * 0.6, R * 0.3), CFrame = base * CFrame.new(sx * R * 0.55, R * 1.1, -R * 0.3), Color = BRASS, Material = M.Metal })
            end
            W(model, { Name = "Beak", Size = Vector3.new(R * 0.2, R * 0.35, R * 0.3), CFrame = base * CFrame.new(0, -R * 0.05, -R * 1.1) * CFrame.Angles(math.pi, 0, 0), Color = IRON, Material = M.Metal })
        end,
    },
    {
        Name = "Gyrocopter", Weight = 2,
        Def = { Label = "Gyrocopter", Hp = 90, Dmg = 9, Speed = 17, Body = 2.0, Head = 1.2, Color = COPPER, Range = { 20, 30 }, Fire = 2.8, Pattern = "Orbit" },
        Lore = { Role = "Skyport patrol", Text = "A tiny one-pilot rotor craft strafing back and forth in front of you. Makes a strafing run: a lane through you.", Tip = "Strafe across the run." },
        Attack = { Shape = "Lane", Width = 4, Past = 16, W = 0.85, Mult = 1.0 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Mast", Size = Vector3.new(0.2, R * 0.9, 0.2), CFrame = base * CFrame.new(0, R * 1.2, 0), Color = IRON, Material = M.Metal })
            for k = 0, 1 do P(model, { Name = "FlakeArm", Size = Vector3.new(R * 4, 0.12, R * 0.35), CFrame = base * CFrame.new(0, R * 1.65, 0) * CFrame.Angles(0, k * math.pi / 2, 0), Color = CANVAS, Material = M.SmoothPlastic }) end
            P(model, { Name = "Tail", Size = Vector3.new(0.25, 0.25, R * 2), CFrame = base * CFrame.new(0, R * 0.2, R * 1.5), Color = BRASS, Material = M.Metal })
            P(model, { Name = "TailFin", Size = Vector3.new(0.1, R * 0.8, R * 0.6), CFrame = base * CFrame.new(0, R * 0.5, R * 2.4), Color = CANVAS2, Material = M.SmoothPlastic })
            P(model, { Name = "Goggles", Size = Vector3.new(R * 1.0, R * 0.3, 0.1), CFrame = base * CFrame.new(0, R * 0.4, -R * 1.0), Color = GLASS, Glow = true })
        end,
    },
    {
        Name = "Automaton", Weight = 2,
        Def = { Label = "Automaton", Hp = 140, Dmg = 11, Speed = 15, Body = 2.3, Head = 1.3, Color = BRASS, Range = { 16, 28 }, Fire = 2.8, Pattern = "GroundStrafe", Ground = true },
        Lore = { Role = "Skyport guard", Text = "A brass walker with a boiler on its back and a chimney puffing steam. Vents a cone of scalding steam at you.", Tip = "Get out of the cone, sideways." },
        Attack = { Shape = "Cone", Half = 22, Past = 10, W = 0.85, Mult = 0.9 },
        Decor = function(model, H)
            local P, body, base, hc, head = H.Part, H.body, H.base, H.headCF, H.head
            P(model, { Name = "Boiler", Shape = Enum.PartType.Cylinder, Size = Vector3.new(body.Y * 0.9, body.X * 0.55, body.X * 0.55), CFrame = base * CFrame.new(0, body.Y * 0.1, body.Z * 0.65) * CFrame.Angles(0, 0, math.rad(90)), Color = COPPER, Material = M.Metal })
            P(model, { Name = "Chimney", Shape = Enum.PartType.Cylinder, Size = Vector3.new(body.Y * 0.6, body.X * 0.18, body.X * 0.18), CFrame = base * CFrame.new(body.X * 0.2, body.Y * 0.75, body.Z * 0.65) * CFrame.Angles(0, 0, math.rad(90)), Color = IRON, Material = M.Metal })
            P(model, { Name = "Visor", Size = Vector3.new(head.X * 0.85, head.Y * 0.2, 0.1), CFrame = hc * CFrame.new(0, head.Y * 0.1, -head.Z * 0.52), Color = LAMP, Glow = true })
            P(model, { Name = "Gauge", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, body.X * 0.3, body.X * 0.3), CFrame = base * CFrame.new(0, body.Y * 0.15, -body.Z / 2 - 0.12) * CFrame.Angles(0, math.rad(90), 0), Color = C3(240, 236, 220), Material = M.SmoothPlastic })
            local chimneyTop = P(model, { Name = "SteamVent", Size = Vector3.new(0.3, 0.3, 0.3), CFrame = base * CFrame.new(body.X * 0.2, body.Y * 1.1, body.Z * 0.65), Transparency = 1 })
            H.Puff(chimneyTop, "smoke_main.dds", C3(240, 240, 240), 3, 0.8, 2, 1.0, Enum.NormalId.Top, 15, 0)
        end,
    },
    {
        Name = "BalloonMine",
        Def = { Label = "Balloon Mine", Hp = 90, Dmg = 10, Speed = 14, Body = 2.0, Head = 1.2, Color = CANVAS2, Range = { 24, 38 }, Fire = 3.0, Pattern = "Pendulum" },
        Lore = { Role = "Skyport mine", Text = "A spiked mine slung under a little balloon, swinging in the wind. Drops a charge on you, then the blast spreads wider.", Tip = "Leave the spot and don't come back." },
        Attack = { Shape = "Echo", R = 4.2, Delay = 0.7, W = 0.75, Mult = 0.9 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for k = 0, 3 do P(model, { Name = "Balloon", Shape = Enum.PartType.Ball, Size = Vector3.new(R * (1.6 - math.abs(k - 1.5) * 0.3), R * 2.2, R * (1.6 - math.abs(k - 1.5) * 0.3)), CFrame = base * CFrame.new(0, R * 2.2, 0) * CFrame.Angles(0, k * math.pi / 4, 0), Color = (k % 2 == 0) and CANVAS or CANVAS2, Material = M.SmoothPlastic }) end
            for k = 0, 3 do P(model, { Name = "Chain", Size = Vector3.new(0.06, R * 1.0, 0.06), CFrame = base * CFrame.new(math.cos(k * 1.57) * R * 0.5, R * 1.1, math.sin(k * 1.57) * R * 0.5), Color = IRON, Material = M.Metal }) end
            for i = 0, 7 do
                local a = i / 8 * math.pi * 2
                W(model, { Name = "Spike", Size = Vector3.new(0.2, R * 0.5, R * 0.3), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -R * 1.1) * CFrame.Angles(math.rad(-90), 0, 0), Color = IRON, Material = M.Metal })
            end
            P(model, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.4, CFrame = base * CFrame.new(0, -R * 0.9, 0), Color = C3(255, 80, 60), Glow = true })
        end,
    },
    {
        Name = "Gearling", Hard = true,
        Def = { Label = "Gearling", Hp = 55, Dmg = 7, Speed = 25, Body = 1.5, Head = 0.95, Color = BRASS, Range = { 16, 30 }, Fire = 2.2, Pattern = "Ricochet" },
        Lore = { Role = "Skyport spinner", Text = "A loose cog spinning on its own, ricocheting round the room. Leaves a row of sparks along its line to you.", Tip = "Sidestep the row; lead it off the walls." },
        Attack = { Shape = "Row", N = 4, R = 3, Gap = 4.4, W = 0.75, Mult = 0.7 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, R * 2.3, R * 2.3), CFrame = base * CFrame.Angles(0, math.rad(90), 0), Color = BRASS, Material = M.Metal })
            for i = 0, 9 do
                local a = i / 10 * math.pi * 2
                P(model, { Name = "Crystal", Size = Vector3.new(R * 0.35, R * 0.4, 0.45), CFrame = base * CFrame.Angles(0, 0, a) * CFrame.new(0, R * 1.25, 0), Color = BRASS, Material = M.Metal })
            end
            P(model, { Name = "Tip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, R * 0.6, R * 0.6), CFrame = base * CFrame.Angles(0, math.rad(90), 0), Color = LAMP, Glow = true })
        end,
    },
    {
        Name = "Dirigible",
        Def = { Label = "Dirigible", Hp = 190, Dmg = 9, Speed = 9, Body = 2.8, Head = 1.4, Color = CANVAS, Range = { 30, 46 }, Fire = 4.0, Pattern = "SlowStrafe" },
        Lore = { Role = "Skyport suppressor", Text = "A little armed airship with a brass gondola. Its cannons shell a square round you, then the middle.", Tip = "Leave the square before it closes." },
        Attack = { Shape = "Grid", Gap = 6, W = 0.95, Mult = 0.9 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            P(model, { Name = "Envelope", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 2.4, R * 2.2, R * 4.2), CFrame = base * CFrame.new(0, R * 1.3, R * 0.3), Color = CANVAS, Material = M.SmoothPlastic })
            for k = -1, 1 do P(model, { Name = "Band", Size = Vector3.new(R * 2.45, 0.2, 0.25), CFrame = base * CFrame.new(0, R * 1.3, R * (0.3 + k * 1.0)), Color = BRASS, Material = M.Metal }) end
            for k = 0, 3 do W(model, { Name = "TailFin", Size = Vector3.new(0.15, R * 0.9, R * 0.9), CFrame = base * CFrame.new(0, R * 1.3, R * 2.1) * CFrame.Angles(0, 0, k * math.pi / 2) * CFrame.new(0, R * 0.8, 0), Color = CANVAS2, Material = M.SmoothPlastic }) end
            P(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 1.2, R * 0.35, R * 0.35), CFrame = base * CFrame.new(0, -R * 0.3, -R * 1.0) * CFrame.Angles(0, math.rad(90), 0), Color = IRON, Material = M.Metal })
            P(model, { Name = "PodGlow", Size = Vector3.new(R * 1.6, R * 0.25, 0.1), CFrame = base * CFrame.new(0, R * 0.1, -R * 1.05), Color = LAMP, Glow = true })
        end,
    },
}

-- ==================== SUPERBOSS: ADMIRAL COGSWORTH ====================
F.Super = {
    Name = "ADMIRAL COGSWORTH", Color = BRASS,
    Hitbox = { Torso = { Vector3.new(5.4, 7.6, 3.8), Vector3.new(0, 2.6, 0) }, Core = { Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 3.6, -2.1), "Ball" },
        Head = { Vector3.new(2.8, 2.8, 2.8), Vector3.new(0, 8.2, 0) } },
    Evade = { Amp = 10, Rate = 1.3, Dodge = 3.8 },
    Body = function(model, Mf, col, H)
        local P, W, Style = H.Part, H.Wedge, H.Style
        Style(model:FindFirstChild("Torso"), C3(40, 50, 80), H.SMOOTH)
        Style(model:FindFirstChild("Core"), LAMP, H.NEON)
        Style(model:FindFirstChild("Head"), BRASS, H.METAL)
        -- a clockwork admiral: a bicorne hat, a brass face with one great lens, epaulettes, a greatcoat
        P(model, { Name = "Bicorne", Size = Vector3.new(4.4, 1.2, 1.6), CFrame = Mf(0, 10, 0), Color = C3(24, 24, 30), Material = H.SMOOTH })
        P(model, { Name = "HatTrim", Size = Vector3.new(4.5, 0.2, 1.65), CFrame = Mf(0, 9.5, 0), Color = BRASS, Material = H.METAL })
        P(model, { Name = "Eye", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.2, 1.2), CFrame = Mf(0.5, 8.4, -1.45) * CFrame.Angles(0, math.rad(90), 0), Color = GLASS, Material = H.NEON })
        P(model, { Name = "Monocle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1.5, 1.5), CFrame = Mf(0.5, 8.4, -1.4) * CFrame.Angles(0, math.rad(90), 0), Color = COPPER, Material = H.METAL })
        P(model, { Name = "Moustache", Size = Vector3.new(1.8, 0.3, 0.3), CFrame = Mf(0, 7.6, -1.45), Color = C3(230, 226, 220), Material = H.SMOOTH })
        for _, sx in ipairs({ -1, 1 }) do
            P(model, { Name = "Epaulette", Size = Vector3.new(1.6, 0.4, 1.6), CFrame = Mf(sx * 2.9, 6.3, 0), Color = BRASS, Material = H.METAL })
            for k = -1, 1 do P(model, { Name = "Fringe", Size = Vector3.new(0.15, 0.6, 0.15), CFrame = Mf(sx * 3.5, 5.9, k * 0.5), Color = BRASS, Material = H.METAL }) end
        end
        for k = 0, 2 do P(model, { Name = "Button", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4, CFrame = Mf(-0.8, 5.4 - k * 1, -1.95), Color = BRASS, Material = H.METAL }) end
        -- the coat tails, a turning gear on its back, a cannon arm, a sword arm
        for i = 0, 5 do
            local a = (i - 2.5) * 0.3
            P(model, { Name = "Deco_Coat", Size = Vector3.new(1.4, 4.4, 0.2), CFrame = Mf(math.sin(a) * 2.4, -0.8, 1.6 + math.cos(a) * 0.3) * CFrame.Angles(0, a, 0), Color = C3(40, 50, 80), Material = H.SMOOTH })
        end
        local gc = Mf(0, 5.4, 2.2)
        P(model, { Name = "Deco_Gear", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 5, 5), CFrame = gc * CFrame.Angles(0, math.rad(90), 0), Color = BRASS, Material = H.METAL })
        for i = 0, 11 do P(model, { Name = "Deco_Gear", Size = Vector3.new(0.6, 0.8, 0.4), CFrame = gc * CFrame.Angles(0, 0, i / 12 * math.pi * 2) * CFrame.new(0, 2.8, 0), Color = BRASS, Material = H.METAL }) end
        P(model, { Name = "Cannon", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 1.1, 1.1), CFrame = Mf(3.2, 3.6, -1.6) * CFrame.Angles(0, math.rad(90), 0), Color = IRON, Material = H.METAL })
        P(model, { Name = "Saber", Size = Vector3.new(0.2, 0.4, 4.4), CFrame = Mf(-3.2, 3, -2.2) * CFrame.Angles(math.rad(-20), 0, 0), Color = C3(220, 226, 236), Material = H.METAL })
        H.Emit(model:FindFirstChild("Torso") or model.PrimaryPart, C3(240, 240, 240), 4, 0.6, 2, 1.6, "rbxasset://textures/particles/smoke_main.dds")
    end,
    Kit = function(H)
        local Mv, EA, Unit, Pose = H.M, H.EA, H.Unit, H.Pose
        local function Broadside(B)
            -- a broadside: a row of cannon strikes walking across the arena through you, then back
            for pass = 1, 2 do
                local r = B:Root()
                if not r or not B:Alive() then return end
                local d = Unit(r.Position - B.pos)
                local side = Vector3.new(-d.Z, 0, d.X) * ((pass == 1) and 1 or -1)
                for i = -3, 3 do
                    local at = B:Clamp(r.Position + side * (i * 6))
                    task.delay((i + 3) * 0.1, function() if B:Alive() then EA.Circle(B.ctx, at, 4, B:W(0.75), { Mult = 1.0 }) end end)
                end
                B:Wait(B:W(0.75) + 0.8)
            end
        end
        local function Clockwork(B)
            -- the clock strikes: lanes like clock hands sweep to point at you, three in turn
            for k = 1, 3 do
                local r = B:Root()
                if not r or not B:Alive() then return end
                local d = CFrame.Angles(0, (k - 2) * math.rad(10), 0):VectorToWorldSpace(Unit(r.Position - B.pos))
                EA.Line(B.ctx, B.pos, B.pos + d * 70, 4.4, B:W(0.8), { Mult = 1.1, Height = 9 })
                B:Wait(0.55)
            end
            B:Wait(B:W(0.8))
        end
        return {
            Color = BRASS, Move = "Orbit", Range = 32, SpeedMul = 0.9, Recover = { 1.9, 1.6, 1.3 },
            Names = { "ADMIRAL COGSWORTH", "ADMIRAL COGSWORTH: FULL STEAM", "ADMIRAL COGSWORTH: LAST STAND" },
            Moves = {
                { { Broadside, "BROADSIDE" }, { Clockwork, "CLOCKWORK" }, { function(B) Mv.Mines(B, 13) end, "SKY MINES" } },
                { { function(B) Mv.Carpet(B, 5, 4, 6, 0.75, 0.2) end, "BOMBING RUN" }, { Broadside, "BROADSIDE" }, { function(B) Mv.Lanes(B, 4, 5, 8, 0.85, false) end, "SALVO LANES" },
                    { Clockwork, "CLOCKWORK" } },
                { { function(B) Mv.Quadrants(B, 70, 2, 0.9) end, "FLEET ORDERS" }, { Broadside, "BROADSIDE" }, { function(B) Mv.Rain(B, 8, 6, 0.85, 0, 0.4) end, "ARTILLERY" },
                    { function(B) Mv.ArenaWipe(B, 2, 8, 1.5) end, "ABANDON SHIP" } },
            },
            Animate = function(B, pivot, now)
                Pose(B, "Deco_Gear", pivot, CFrame.new(0, 5.4, 2.2), CFrame.Angles(0, 0, now * 0.8))
                Pose(B, "Deco_Coat", pivot, CFrame.new(0, 1.5, 1.6), CFrame.Angles(math.sin(now * 1.5) * 0.06, 0, 0))
            end,
        }
    end,
}
return F
