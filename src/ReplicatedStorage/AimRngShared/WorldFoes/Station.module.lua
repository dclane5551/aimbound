--!nocheck
-- DERELICT STATION foes (0.89): the machines (and the thing) left on a breached station. Superboss WARDEN-PRIME.
local C3 = Color3.fromRGB
local M = Enum.Material
local PANEL, PANEL2, DARK, RED, AMBER, SCREEN, FLESH = C3(186, 190, 196), C3(150, 154, 160), C3(52, 54, 60), C3(255, 50, 40), C3(255, 170, 40), C3(80, 200, 255), C3(150, 70, 80)

local F = {}
F.Specialist = "WardenUnit"
F.Enemies = {
    {
        Name = "MaintDrone", Weight = 2,
        Def = { Label = "Maintenance Drone", Hp = 90, Dmg = 9, Speed = 16, Body = 2.0, Head = 1.2, Color = PANEL, Range = { 26, 40 }, Fire = 2.6, Pattern = "Tracking" },
        Lore = { Role = "Station drone", Text = "A white maintenance drone with folded tool arms and a warning light, tracking you smoothly. Cuts a welding lane through you.", Tip = "Strafe across its line." },
        Attack = { Shape = "Lane", Width = 3.6, Past = 18, W = 0.85, Mult = 1.0 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Shell", Size = Vector3.new(R * 2.0, R * 1.4, R * 2.0), CFrame = base, Color = PANEL, Material = M.SmoothPlastic })
            for k = -1, 1, 2 do P(model, { Name = "Stripe", Size = Vector3.new(R * 2.05, R * 0.15, R * 2.05), CFrame = base * CFrame.new(0, k * R * 0.45, 0), Color = AMBER, Material = M.SmoothPlastic }) end
            P(model, { Name = "Lens", Size = Vector3.new(R * 0.9, R * 0.4, 0.1), CFrame = base * CFrame.new(0, R * 0.1, -R * 1.02), Color = SCREEN, Glow = true })
            P(model, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.4, CFrame = base * CFrame.new(0, R * 0.85, 0), Color = RED, Glow = true })
            for _, sx in ipairs({ -1, 1 }) do
                P(model, { Name = "ToolArm", Size = Vector3.new(0.18, R * 1.0, 0.18), CFrame = base * CFrame.new(sx * R * 0.8, -R * 0.9, -R * 0.4) * CFrame.Angles(math.rad(30), 0, sx * 0.2), Color = DARK, Material = M.Metal })
                P(model, { Name = "Tip", Size = Vector3.new(0.25, 0.25, 0.25), CFrame = base * CFrame.new(sx * R * 0.85, -R * 1.35, -R * 0.7), Color = AMBER, Glow = true })
            end
        end,
    },
    {
        Name = "TurretPod",
        Def = { Label = "Turret Pod", Hp = 90, Dmg = 22, Speed = 14, Body = 2.1, Head = 1.3, Color = DARK, Range = { 44, 66 }, Fire = 4.2, Pattern = "Peek" },
        Lore = { Role = "Station sentry", Text = "A security pod that peeks from cover and fires one long, narrow beam. Hits hard.", Tip = "A small sidestep when the beam locks." },
        Attack = { Shape = "Lane", Width = 2.6, Past = 30, Max = 80, W = 1.0, Mult = 1.3 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 2.1, CFrame = base, Color = DARK, Material = M.Metal })
            P(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 1.6, R * 0.35, R * 0.35), CFrame = base * CFrame.new(0, 0, -R * 1.4) * CFrame.Angles(0, math.rad(90), 0), Color = PANEL2, Material = M.Metal })
            P(model, { Name = "Tip", Size = Vector3.new(R * 0.3, R * 0.3, 0.1), CFrame = base * CFrame.new(0, 0, -R * 2.22), Color = RED, Glow = true })
            P(model, { Name = "Lens", Size = Vector3.new(R * 0.5, R * 0.25, 0.1), CFrame = base * CFrame.new(0, R * 0.45, -R * 0.95), Color = RED, Glow = true })
            H.Ring(model, base, R * 2.3, 0.15, PANEL, false)
        end,
    },
    {
        Name = "Crawler", Weight = 2,
        Def = { Label = "Crawler", Hp = 130, Dmg = 11, Speed = 16, Body = 2.2, Head = 1.2, Color = PANEL2, Range = { 16, 28 }, Fire = 2.8, Pattern = "GroundStrafe", Ground = true },
        Lore = { Role = "Station walker", Text = "A spider-legged repair walker gone rogue. Sprays a cone of sparks at you.", Tip = "Get out of the cone, sideways." },
        Attack = { Shape = "Cone", Half = 22, Past = 10, W = 0.85, Mult = 0.9 },
        Decor = function(model, H)
            local P, body, base, hc, head = H.Part, H.body, H.base, H.headCF, H.head
            for _, sx in ipairs({ -1, 1 }) do
                for k = 0, 1 do
                    P(model, { Name = "Leg", Size = Vector3.new(body.X * 0.9, 0.2, 0.2), CFrame = base * CFrame.new(sx * body.X * 0.9, body.Y * 0.1, (k - 0.5) * body.Z * 0.8) * CFrame.Angles(0, 0, sx * -0.6), Color = DARK, Material = M.Metal })
                end
            end
            P(model, { Name = "Visor", Size = Vector3.new(head.X * 0.9, head.Y * 0.25, 0.1), CFrame = hc * CFrame.new(0, 0, -head.Z * 0.52), Color = AMBER, Glow = true })
            P(model, { Name = "Plate", Size = Vector3.new(body.X * 0.8, body.Y * 0.35, 0.2), CFrame = base * CFrame.new(0, body.Y * 0.2, -body.Z / 2 - 0.1), Color = PANEL, Material = M.SmoothPlastic })
        end,
    },
    {
        Name = "XenoLarva", Hard = true,
        Def = { Label = "Xeno Larva", Hp = 85, Dmg = 9, Speed = 18, Body = 1.8, Head = 1.1, Color = FLESH, Range = { 22, 36 }, Fire = 2.6, Pattern = "Serpent" },
        Lore = { Role = "Station parasite", Text = "Something that came aboard: a pale segmented larva weaving through the air. Spits a row of acid along its line to you.", Tip = "Sidestep the row." },
        Attack = { Shape = "Row", N = 5, R = 3, Gap = 4.2, W = 0.8, Mult = 0.7 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            for k = 1, 5 do
                local sz = R * (1.2 - k * 0.13)
                P(model, { Name = "TailSegment", Shape = Enum.PartType.Ball, Size = Vector3.one * sz, CFrame = base * CFrame.new(math.sin(k) * R * 0.3, 0, R * (0.5 + k * 0.75)), Color = (k % 2 == 0) and FLESH or C3(190, 120, 120), Material = M.SmoothPlastic })
            end
            for i = 0, 3 do
                local a = i * math.pi / 2
                W(model, { Name = "Jaw", Size = Vector3.new(0.15, R * 0.6, R * 0.5), CFrame = base * CFrame.Angles(0, 0, a) * CFrame.new(0, R * 0.55, -R * 0.9) * CFrame.Angles(math.rad(-30), 0, 0), Color = C3(230, 220, 190), Material = M.SmoothPlastic })
            end
            P(model, { Name = "Maw", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.5, CFrame = base * CFrame.new(0, 0, -R * 0.9), Color = C3(180, 255, 120), Glow = true })
        end,
    },
    {
        Name = "RepairBot",
        Def = { Label = "Repair Bot", Hp = 85, Dmg = 9, Speed = 17, Body = 1.9, Head = 1.15, Color = AMBER, Range = { 18, 32 }, Fire = 2.6, Pattern = "Bounce" },
        Lore = { Role = "Station bouncer", Text = "A boxy repair bot hopping on a magnetic pad. Fires a burst where you stand that leaves a crackling patch.", Tip = "Don't stand where it hit." },
        Attack = { Shape = "Puddle", R = 4, W = 0.8, Mult = 0.8, Life = 2.4 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Box", Size = Vector3.new(R * 1.9, R * 1.6, R * 1.9), CFrame = base, Color = AMBER, Material = M.Metal })
            P(model, { Name = "Pad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 0.3, R * 1.5, R * 1.5), CFrame = base * CFrame.new(0, -R * 1.0, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = DARK, Material = M.Metal })
            P(model, { Name = "PodGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, R * 1.2, R * 1.2), CFrame = base * CFrame.new(0, -R * 1.18, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = SCREEN, Glow = true })
            P(model, { Name = "Lens", Size = Vector3.new(R * 0.9, R * 0.3, 0.1), CFrame = base * CFrame.new(0, R * 0.25, -R * 0.97), Color = SCREEN, Glow = true })
            P(model, { Name = "Antenna", Size = Vector3.new(0.08, R * 1.0, 0.08), CFrame = base * CFrame.new(R * 0.5, R * 1.2, 0), Color = DARK, Material = M.Metal })
        end,
    },
    {
        Name = "WardenUnit",
        Def = { Label = "Warden Unit", Hp = 190, Dmg = 9, Speed = 9, Body = 2.8, Head = 1.4, Color = RED, Range = { 30, 44 }, Fire = 4.0, Pattern = "SlowStrafe" },
        Lore = { Role = "Station suppressor", Text = "A security mech with a spinning shield ring. Locks down a square of laser lanes round you, then the middle.", Tip = "Leave the square before it closes." },
        Attack = { Shape = "Grid", Gap = 6, W = 0.95, Mult = 0.9 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            P(model, { Name = "Shell", Size = Vector3.new(R * 2.0, R * 2.2, R * 2.0), CFrame = base, Color = PANEL, Material = M.SmoothPlastic })
            P(model, { Name = "Lens", Size = Vector3.new(R * 1.4, R * 0.35, 0.1), CFrame = base * CFrame.new(0, R * 0.6, -R * 1.02), Color = RED, Glow = true })
            H.Ring(model, base, R * 3.0, 0.2, RED, true)
            H.Ring(model, base * CFrame.Angles(math.rad(90), 0, 0), R * 2.7, 0.15, PANEL2, false)
            for k = -2, 2 do P(model, { Name = "Stripe", Size = Vector3.new(R * 0.3, R * 0.6, 0.1), CFrame = base * CFrame.new(k * R * 0.38, -R * 0.75, -R * 1.02) * CFrame.Angles(0, 0, 0.5), Color = (k % 2 == 0) and AMBER or DARK, Material = M.SmoothPlastic }) end
        end,
    },
}

-- ==================== SUPERBOSS: WARDEN-PRIME ====================
F.Super = {
    Name = "WARDEN-PRIME", Color = RED,
    Hitbox = { Torso = { Vector3.new(6, 7.4, 4), Vector3.new(0, 2.4, 0) }, Core = { Vector3.new(2.6, 2.6, 2.6), Vector3.new(0, 3, -2.2), "Ball" },
        Head = { Vector3.new(3, 2.4, 3), Vector3.new(0, 7.4, 0) } },
    Evade = { Amp = 10, Rate = 1.4, Dodge = 3.6 },
    Body = function(model, Mf, col, H)
        local P, W, Style = H.Part, H.Wedge, H.Style
        Style(model:FindFirstChild("Torso"), PANEL, H.SMOOTH)
        Style(model:FindFirstChild("Core"), RED, H.NEON)
        Style(model:FindFirstChild("Head"), DARK, H.METAL)
        -- the station's security AI in a war frame: a visor slit, shoulder pylons, a reactor spine, shield rings
        P(model, { Name = "Visor", Size = Vector3.new(2.6, 0.4, 0.2), CFrame = Mf(0, 7.5, -1.55), Color = RED, Material = H.NEON })
        for _, sx in ipairs({ -1, 1 }) do
            P(model, { Name = "Pylon", Size = Vector3.new(1.4, 4, 1.4), CFrame = Mf(sx * 3.8, 6.2, 0), Color = PANEL2, Material = H.SMOOTH })
            P(model, { Name = "PylonTip", Size = Vector3.new(1.0, 0.4, 1.0), CFrame = Mf(sx * 3.8, 8.4, 0), Color = RED, Material = H.NEON })
            for k = -2, 2 do P(model, { Name = "Stripe", Size = Vector3.new(0.35, 1.2, 0.1), CFrame = Mf(sx * 3.8 + k * 0.28, 5, -0.75) * CFrame.Angles(0, 0, 0.5), Color = (k % 2 == 0) and AMBER or DARK, Material = H.SMOOTH }) end
        end
        for k = 0, 3 do P(model, { Name = "Spine", Size = Vector3.new(1.2, 0.8, 1.2), CFrame = Mf(0, 1 + k * 1.6, 2.4), Color = (k % 2 == 0) and SCREEN or DARK, Material = (k % 2 == 0) and H.NEON or H.METAL }) end
        for k = 0, 23 do
            local a = k / 24 * math.pi * 2
            P(model, { Name = "Deco_RingA", Size = Vector3.new(1.3, 0.3, 0.4), CFrame = Mf(0, 3, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 6.2), Color = (k % 4 == 0) and RED or PANEL2, Material = (k % 4 == 0) and H.NEON or H.METAL })
        end
        for k = 0, 15 do
            local a = k / 16 * math.pi * 2
            P(model, { Name = "Deco_RingB", Size = Vector3.new(1.0, 0.25, 0.3), CFrame = Mf(0, 4.5, 0) * CFrame.Angles(math.rad(70), a, 0) * CFrame.new(0, 0, 4.6), Color = SCREEN, Material = H.NEON })
        end
        H.Emit(model:FindFirstChild("Torso") or model.PrimaryPart, C3(255, 200, 140), 4, 0.2, 4, 0.8)
    end,
    Kit = function(H)
        local Mv, EA, Unit, Pose = H.M, H.EA, H.Unit, H.Pose
        local function Lockdown(B)
            -- security grid: a # of lanes round you, then the middle cell
            local r = B:Root()
            if not r then return end
            local at = r.Position
            local d = Unit(at - B.pos)
            local side = Vector3.new(-d.Z, 0, d.X)
            for _, sgn in ipairs({ -1, 1 }) do
                EA.Line(B.ctx, at + side * sgn * 7 - d * 28, at + side * sgn * 7 + d * 28, 3.6, B:W(0.9), { Mult = 1.0, Height = 9 })
                EA.Line(B.ctx, at + d * sgn * 7 - side * 28, at + d * sgn * 7 + side * 28, 3.6, B:W(0.9), { Mult = 1.0, Height = 9 })
            end
            task.delay(B:W(0.9) + 0.4, function() if B:Alive() then EA.Circle(B.ctx, at, 6, B:W(0.6), { Mult = 1.1 }) end end)
            B:Wait(B:W(0.9) + 1.2)
        end
        local function Purge(B)
            -- airlock purge: three lanes in quick turns, each aimed at where you are
            for _ = 1, 3 do
                local r = B:Root()
                if not r or not B:Alive() then return end
                EA.Line(B.ctx, B.pos, B.pos + Unit(r.Position - B.pos) * 70, 4.5, B:W(0.7), { Mult = 1.1, Height = 9 })
                B:Wait(0.5)
            end
            B:Wait(B:W(0.7))
        end
        return {
            Color = RED, Move = "Orbit", Range = 32, SpeedMul = 0.9, Recover = { 1.9, 1.6, 1.3 },
            Names = { "WARDEN-PRIME", "WARDEN-PRIME: RED ALERT", "WARDEN-PRIME: SELF-DESTRUCT" },
            Moves = {
                { { Lockdown, "LOCKDOWN" }, { Purge, "PURGE" }, { function(B) Mv.Mines(B, 13) end, "PROXIMITY MINES" } },
                { { function(B) Mv.Lanes(B, 5, 6, 7, 0.8, true) end, "LASER GRID" }, { Lockdown, "LOCKDOWN" }, { function(B) Mv.Checker(B, 34, 0.95) end, "DECK PANELS" },
                    { Purge, "PURGE" } },
                { { function(B) Mv.Quadrants(B, 70, 2, 0.9) end, "SECTOR SEAL" }, { Lockdown, "LOCKDOWN" }, { function(B) Mv.Crossfire(B, 2, 6, 0.9) end, "CROSSFIRE" },
                    { function(B) Mv.ArenaWipe(B, 2, 8, 1.5) end, "SELF-DESTRUCT" } },
            },
            Animate = function(B, pivot, now)
                Pose(B, "Deco_RingA", pivot, CFrame.new(0, 3, 0), CFrame.Angles(0, now * 0.6, 0))
                Pose(B, "Deco_RingB", pivot, CFrame.new(0, 4.5, 0), CFrame.Angles(0, -now * 0.9, 0))
            end,
        }
    end,
}
return F
