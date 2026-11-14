-- BOSS LOOK v3: TONATIUH'S AVATAR (world superboss, WorldFoes/Aztec) -- the sun's warrior: a slim obsidian pill with a gold-and-jade collar and pectoral, a gold sun disc behind its head with long jade feathers radiating from it, a macuahuitl floating at its side, its obsidian blades lit
-- (tools/boss_look_blender.py build_aztec_v3; v3 = the Duelist language after the owner's "Keep them in the same aesthetic
-- of duelist phantom etc, not toys"). Plug-in API: the header of AimRngShared/BossLook. The head colour follows the core
-- rule (BossLook.HeadColor).
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.10, Hover = 0.6,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.0, Pos = Vector3.new(0, 0.2, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.6, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.36, Pos = Vector3.new(0, 2.6, 0), Show = true },
    },
    Palette = { Body = C(24, 22, 30), Gold = C(188, 140, 48), Jade = C(36, 146, 118), Dark = C(52, 34, 26), Glow = C(255, 190, 60) },
    HeadTint = C(118, 210, 184), -- (pale jade: the auto gold head vanished into the gold sun disc behind it)
    Glow = { Glow = true },
    Emit = { { Part = "Torso", Kind = "Spark", Color = C(255, 210, 100), Rate = 3, Size = 0.22, Speed = 1, Life = 2, Y = -2 } },
    Animate = function(B, pivot, now, Pose, dy)
        -- the sun disc turns (faster each phase), the feathers sway, the club rises to strike when it attacks
        local l = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.1)
        Pose(B, "Deco_Sun", pivot, CFrame.new(0, 2.75 + dy, 0.55), CFrame.Angles(0, 0, now * (0.3 + B.phase * 0.15)))
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 2.75 + dy, 0.55), CFrame.Angles(math.sin(now * 1.2) * 0.03, 0, math.sin(now * 0.9) * 0.03))
        Pose(B, "Deco_Club", pivot, CFrame.new(1.65, -0.9 + dy, -0.33), CFrame.Angles(-l * 0.6 + math.sin(now * 1.0) * 0.05, 0, -l * 0.15))
    end,
}
