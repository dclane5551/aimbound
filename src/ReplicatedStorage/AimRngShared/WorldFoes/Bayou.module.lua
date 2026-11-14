--!nocheck
-- HAUNTED BAYOU foes (0.89): the haunts of a night swamp. Superboss MAMA BAYOU.
local C3 = Color3.fromRGB
local M = Enum.Material
local WISP, WISP2, MOSS, MUD, BARK, CLOTH, BONE = C3(160, 255, 140), C3(120, 230, 255), C3(110, 120, 90), C3(58, 60, 42), C3(64, 54, 44), C3(120, 80, 110), C3(226, 220, 204)

local F = {}
F.Specialist = "SwampWitch"
F.Enemies = {
    {
        Name = "WillOWisp", Hard = true,
        Def = { Label = "Will-o'-Wisp", Hp = 75, Dmg = 9, Speed = 16, Body = 1.8, Head = 1.1, Color = WISP, Range = { 22, 34 }, Fire = 2.8, Pattern = "Phase" },
        Lore = { Role = "Bayou light", Text = "A drifting swamp light that flickers out and slides away. Its cold flames follow you: three in a row.", Tip = "Keep moving; never step back." },
        Attack = { Shape = "Chase", N = 3, R = 3.4, W = 0.6, Gap = 0.55, Mult = 0.6 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            local torso = model:FindFirstChild("Torso")
            if torso then torso.Material = M.Neon; torso.Color = WISP; torso.Transparency = 0.2 end
            for k = 1, 4 do P(model, { Name = "TailSegment", Shape = Enum.PartType.Ball, Size = Vector3.one * R * (1.0 - k * 0.2), CFrame = base * CFrame.new(math.sin(k) * R * 0.3, R * 0.2 * k, R * (0.4 + k * 0.6)), Color = WISP, Glow = true, Transparency = 0.3 + k * 0.1 }) end
            H.Puff(torso or model.PrimaryPart, "sparkles_main.dds", WISP, 8, 0.3, 0.8, 1.0, Enum.NormalId.Top, 60, 1)
        end,
    },
    {
        Name = "BogLurker", Weight = 2,
        Def = { Label = "Bog Lurker", Hp = 145, Dmg = 12, Speed = 15, Body = 2.4, Head = 1.35, Color = C3(80, 100, 60), Range = { 18, 30 }, Fire = 3.0, Pattern = "Burrow", Ground = true },
        Lore = { Role = "Bayou lurker", Text = "A moss-hung swamp thing that sinks into the mud and rises elsewhere. Spits a burst that leaves a patch of sucking bog.", Tip = "Don't stand where it hit." },
        Attack = { Shape = "Puddle", R = 4.4, W = 0.8, Mult = 0.8, Life = 2.8 },
        Decor = function(model, H)
            local P, body, base, hc, head = H.Part, H.body, H.base, H.headCF, H.head
            for i = 0, 7 do
                local a = i / 8 * math.pi * 2
                P(model, { Name = "Tendril", Size = Vector3.new(body.X * 0.2, body.Y * (0.7 + (i % 3) * 0.2), 0.12), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, -body.Y * 0.1, body.Z * 0.55), Color = MOSS, Material = M.Grass })
            end
            P(model, { Name = "Hump", Shape = Enum.PartType.Ball, Size = Vector3.new(body.X * 1.1, body.Y * 0.5, body.Z * 1.0), CFrame = base * CFrame.new(0, body.Y * 0.4, body.Z * 0.2), Color = MUD, Material = M.Mud })
            for _, sx in ipairs({ -1, 1 }) do P(model, { Name = "FrostEye", Shape = Enum.PartType.Ball, Size = Vector3.one * head.X * 0.22, CFrame = hc * CFrame.new(sx * head.X * 0.25, head.Y * 0.1, -head.Z * 0.48), Color = C3(255, 220, 90), Glow = true }) end
        end,
    },
    {
        Name = "FireflySwarm",
        Def = { Label = "Firefly Swarm", Hp = 70, Dmg = 8, Speed = 14, Body = 1.8, Head = 1.1, Color = C3(220, 255, 120), Range = { 20, 32 }, Fire = 2.6, Pattern = "Popcorn" },
        Lore = { Role = "Bayou swarm", Text = "A knot of fireflies around a glowing queen, popping up and drifting down. Showers a row of sparks along its line to you.", Tip = "Sidestep the row." },
        Attack = { Shape = "Row", N = 5, R = 3, Gap = 4.2, W = 0.8, Mult = 0.7 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            for i = 0, 9 do
                local a, b = i * 2.4, ((i * 1.7) % 2 - 1) * 1.0
                P(model, { Name = "StarMote", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.3, CFrame = base * CFrame.Angles(b, a, 0) * CFrame.new(0, 0, -R * 1.5), Color = C3(220, 255, 120), Glow = true })
            end
            P(model, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.9, CFrame = base, Color = C3(240, 255, 160), Glow = true })
        end,
    },
    {
        Name = "VoodooDoll", Weight = 2,
        Def = { Label = "Voodoo Doll", Hp = 85, Dmg = 9, Speed = 17, Body = 1.9, Head = 1.15, Color = CLOTH, Range = { 18, 32 }, Fire = 2.6, Pattern = "Bounce" },
        Lore = { Role = "Bayou doll", Text = "A stitched cloth doll stuck with pins, bouncing on its own. Pins two strikes either side of you.", Tip = "Stay in the gap." },
        Attack = { Shape = "Pair", Gap = 3.6, R = 3.4, W = 0.75, Mult = 0.8 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            for k = -1, 1 do P(model, { Name = "Stitch", Size = Vector3.new(R * 0.6, 0.08, 0.08), CFrame = base * CFrame.new(0, k * R * 0.35, -R * 1.02) * CFrame.Angles(0, 0, (k % 2 == 0) and 0.4 or -0.4), Color = C3(30, 30, 30), Material = M.SmoothPlastic }) end
            for _, sx in ipairs({ -1, 1 }) do
                P(model, { Name = "Button", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, R * 0.4, R * 0.4), CFrame = base * CFrame.new(sx * R * 0.35, R * 0.45, -R * 1.02) * CFrame.Angles(0, math.rad(90), 0), Color = WISP, Glow = true })
                P(model, { Name = "Arm", Size = Vector3.new(R * 0.9, R * 0.3, R * 0.3), CFrame = base * CFrame.new(sx * R * 1.2, -R * 0.1, 0), Color = CLOTH, Material = M.SmoothPlastic })
            end
            for i = 0, 3 do
                local a = i * 1.6
                P(model, { Name = "Pin", Size = Vector3.new(0.06, 0.06, R * 1.0), CFrame = base * CFrame.Angles(0.5, a, 0) * CFrame.new(0, 0, -R * 1.0), Color = C3(200, 200, 210), Material = M.Metal })
                P(model, { Name = "PinHead", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.2, CFrame = base * CFrame.Angles(0.5, a, 0) * CFrame.new(0, 0, -R * 1.5), Color = C3(230, 40, 60), Material = M.SmoothPlastic })
            end
        end,
    },
    {
        Name = "MossWraith",
        Def = { Label = "Moss Wraith", Hp = 90, Dmg = 9, Speed = 15, Body = 2.0, Head = 1.2, Color = MOSS, Range = { 24, 38 }, Fire = 3.0, Pattern = "Pendulum" },
        Lore = { Role = "Bayou wraith", Text = "A ghost of hanging moss swinging from a cypress that isn't there. Leaves trails of black water where you're heading.", Tip = "Shoot it at the ends of its swing; keep off the water." },
        Attack = { Shape = "Trail", N = 3, R = 3.8, Gap = 5, W = 0.7, Mult = 0.3, Life = 2.6 },
        Decor = function(model, H)
            local P, R, base = H.Part, H.R, H.base
            for i = 0, 9 do
                local a = i / 10 * math.pi * 2
                P(model, { Name = "Tendril", Size = Vector3.new(R * 0.35, R * (1.6 + (i % 3) * 0.6), 0.1), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, -R * 0.9, R * 0.85), Color = (i % 2 == 0) and MOSS or C3(90, 100, 74), Material = M.Grass, Transparency = 0.1 })
            end
            for _, sx in ipairs({ -1, 1 }) do P(model, { Name = "EyeSpot", Size = Vector3.new(R * 0.25, R * 0.12, 0.1), CFrame = base * CFrame.new(sx * R * 0.3, R * 0.3, -R * 1.0), Color = WISP, Glow = true }) end
            P(model, { Name = "Chain", Size = Vector3.new(0.12, R * 1.6, 0.12), CFrame = base * CFrame.new(0, R * 1.6, 0), Color = BARK, Material = M.Wood })
        end,
    },
    {
        Name = "SwampWitch",
        Def = { Label = "Swamp Witch", Hp = 185, Dmg = 9, Speed = 9, Body = 2.7, Head = 1.4, Color = C3(150, 90, 170), Range = { 30, 44 }, Fire = 3.8, Pattern = "SlowStrafe" },
        Lore = { Role = "Bayou suppressor", Text = "A floating hag over a bubbling pot, a hat of moss and bones. Casts a square of hex lanes round you, then the middle.", Tip = "Leave the square before it closes." },
        Attack = { Shape = "Grid", Gap = 6, W = 0.95, Mult = 0.9 },
        Decor = function(model, H)
            local P, W, R, base = H.Part, H.Wedge, H.R, H.base
            P(model, { Name = "HatBrim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, R * 2.8, R * 2.8), CFrame = base * CFrame.new(0, R * 1.0, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = C3(40, 30, 44), Material = M.SmoothPlastic })
            W(model, { Name = "HatTop", Size = Vector3.new(R * 1.3, R * 1.8, R * 1.3), CFrame = base * CFrame.new(0, R * 1.9, R * 0.1) * CFrame.Angles(math.rad(-15), 0, 0), Color = C3(40, 30, 44), Material = M.SmoothPlastic })
            P(model, { Name = "Pot", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 1.6, R * 1.2, R * 1.6), CFrame = base * CFrame.new(0, -R * 1.4, -R * 0.6), Color = C3(30, 30, 30), Material = M.Metal })
            P(model, { Name = "Glow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, R * 1.3, R * 1.3), CFrame = base * CFrame.new(0, -R * 0.85, -R * 0.6) * CFrame.Angles(0, 0, math.rad(90)), Color = WISP, Glow = true })
            for _, sx in ipairs({ -1, 1 }) do P(model, { Name = "EyeSpot", Size = Vector3.new(R * 0.25, R * 0.12, 0.1), CFrame = base * CFrame.new(sx * R * 0.3, R * 0.4, -R * 1.0), Color = C3(255, 220, 90), Glow = true }) end
            for i = 0, 5 do P(model, { Name = "Tendril", Size = Vector3.new(0.15, R * 1.4, 0.15), CFrame = base * CFrame.new(math.cos(i) * R * 1.0, -R * 0.4, math.sin(i) * R * 1.0), Color = MOSS, Material = M.Grass }) end
            H.Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "smoke_main.dds", WISP, 3, 0.8, 1.5, 1.2, Enum.NormalId.Top, 20, 0.4)
        end,
    },
}

-- ==================== SUPERBOSS: MAMA BAYOU ====================
F.Super = {
    Name = "MAMA BAYOU", Color = WISP,
    Hitbox = { Torso = { Vector3.new(6, 8, 4), Vector3.new(0, 2.4, 0) }, Core = { Vector3.new(2.6, 2.6, 2.6), Vector3.new(0, 3.4, -2.2), "Ball" },
        Head = { Vector3.new(2.8, 2.8, 2.8), Vector3.new(0, 8.2, 0) } },
    Evade = { Amp = 10, Rate = 1.3, Dodge = 3.8 },
    Body = function(model, Mf, col, H)
        local P, W, Style = H.Part, H.Wedge, H.Style
        Style(model:FindFirstChild("Torso"), C3(60, 50, 64), H.SMOOTH)
        Style(model:FindFirstChild("Core"), WISP, H.NEON)
        Style(model:FindFirstChild("Head"), C3(80, 70, 70), H.SMOOTH)
        -- the swamp queen: a crocodile-skull headdress, glowing eyes, moss hair, a cloak of moss, a skull staff
        P(model, { Name = "Skull", Size = Vector3.new(2.6, 1.2, 4.2), CFrame = Mf(0, 9.8, -0.4), Color = BONE, Material = H.SMOOTH })
        for k = -3, 3 do W(model, { Name = "Tooth", Size = Vector3.new(0.15, 0.5, 0.25), CFrame = Mf(k * 0.32, 9.1, -2.3) * CFrame.Angles(math.pi, 0, 0), Color = BONE, Material = H.SMOOTH }) end
        for _, sx in ipairs({ -1, 1 }) do
            P(model, { Name = "Eye", Size = Vector3.new(0.5, 0.2, 0.15), CFrame = Mf(sx * 0.55, 8.4, -1.42), Color = WISP, Material = H.NEON })
            for k = 0, 3 do P(model, { Name = "Deco_Hair", Size = Vector3.new(0.3, 3 + k * 0.4, 0.3), CFrame = Mf(sx * (1.3 + k * 0.2), 6.8 - k * 0.2, 0.4 + k * 0.2), Color = MOSS, Material = M.Grass }) end
        end
        for i = 0, 11 do
            local a = i / 12 * math.pi * 2
            P(model, { Name = "Deco_Moss", Size = Vector3.new(1.4, 8 + (i % 3), 0.2), CFrame = Mf(math.cos(a) * 3, 0.5, math.sin(a) * 2.2) * CFrame.Angles(0, -a, 0), Color = (i % 2 == 0) and MOSS or C3(80, 92, 66), Material = M.Grass })
        end
        P(model, { Name = "Necklace", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 5.6, 5.6), CFrame = Mf(0, 6.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = BONE, Material = H.SMOOTH })
        P(model, { Name = "Deco_Staff", Size = Vector3.new(0.4, 12, 0.4), CFrame = Mf(3.8, 4, -0.6), Color = BARK, Material = M.Wood })
        P(model, { Name = "Deco_Staff", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = Mf(3.8, 10.4, -0.6), Color = BONE, Material = H.SMOOTH })
        P(model, { Name = "Deco_Staff", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, CFrame = Mf(3.8, 10.4, -1.3), Color = WISP, Material = H.NEON })
        -- wisps circling her
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2
            P(model, { Name = "Deco_Wisp", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = Mf(math.cos(a) * 6.5, 4 + (i % 2) * 2.5, math.sin(a) * 6.5), Color = (i % 2 == 0) and WISP or WISP2, Material = H.NEON })
        end
        H.Emit(model:FindFirstChild("Torso") or model.PrimaryPart, WISP, 5, 0.3, 1.2, 2)
    end,
    Kit = function(H)
        local Mv, EA, Unit, Pose = H.M, H.EA, H.Unit, H.Pose
        local function Hex(B)
            -- a hex of black water falls on you: a ring of four pools, then the centre lingers
            local r = B:Root()
            if not r then return end
            local at = r.Position
            for k = 0, 3 do
                local a = k * math.pi / 2
                EA.Circle(B.ctx, at + Vector3.new(math.cos(a) * 7, 0, math.sin(a) * 7), 4.5, B:W(0.8), { Mult = 0.9 })
            end
            task.delay(B:W(0.8) + 0.3, function() if B:Alive() then EA.Zone(B.ctx, at, 6, B:W(0.6), 3, { Mult = 0.35, Height = 6 }) end end)
            B:Wait(B:W(0.8) + 1.2)
        end
        local function GatorJaws(B)
            -- jaws snap shut on you: two lanes either side closing to a centre lane
            local r = B:Root()
            if not r then return end
            local at = r.Position
            local d = Unit(at - B.pos)
            local side = Vector3.new(-d.Z, 0, d.X)
            for k, off in ipairs({ 9, 4.5, 0 }) do
                task.delay((k - 1) * 0.35, function()
                    if not B:Alive() then return end
                    for _, sx in ipairs(off == 0 and { 0 } or { -1, 1 }) do
                        local c = at + side * sx * off
                        EA.Line(B.ctx, c - d * 24, c + d * 24, 4, B:W(0.75), { Mult = 1.0, Height = 9 })
                    end
                end)
            end
            B:Wait(B:W(0.75) + 1.1)
        end
        return {
            Color = WISP, Move = "Orbit", Range = 30, SpeedMul = 0.9, Recover = { 1.9, 1.6, 1.3 },
            Names = { "MAMA BAYOU", "MAMA BAYOU: HIGH WATER", "MAMA BAYOU: THE DROWNING" },
            Moves = {
                { { Hex, "HEX" }, { GatorJaws, "GATOR JAWS" }, { function(B) Mv.Rain(B, 6, 6, 0.85, 0, 0.42) end, "WISP FALL" } },
                { { function(B) Mv.Pools(B, 4) end, "BLACK WATER" }, { GatorJaws, "GATOR JAWS" }, { function(B) Mv.Cage(B, 8, 12, 1.0) end, "CYPRESS CAGE" },
                    { Hex, "HEX" } },
                { { function(B) Mv.Converge(B, 2, 1.0) end, "THE TIDE COMES IN" }, { Hex, "HEX" }, { function(B) Mv.Crossfire(B, 2, 6, 0.9) end, "CROSSROADS" },
                    { function(B) Mv.ArenaWipe(B, 2, 8, 1.5) end, "THE DROWNING" } },
            },
            Animate = function(B, pivot, now)
                Pose(B, "Deco_Wisp", pivot, CFrame.new(0, 5, 0), CFrame.Angles(0, now * 0.7, 0))
                Pose(B, "Deco_Moss", pivot, CFrame.new(0, 4, 0), CFrame.Angles(math.sin(now * 1.2) * 0.05, 0, math.cos(now * 1.0) * 0.05))
                Pose(B, "Deco_Staff", pivot, CFrame.new(3.8, 4, -0.6), CFrame.Angles(math.sin(now * 0.8) * 0.06, 0, 0))
                Pose(B, "Deco_Hair", pivot, CFrame.new(0, 8, 0), CFrame.Angles(math.sin(now * 1.5) * 0.05, 0, 0))
            end,
        }
    end,
}
return F
