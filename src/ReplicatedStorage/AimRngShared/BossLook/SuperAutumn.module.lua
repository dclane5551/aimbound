-- BOSS LOOK v3: THE HARVEST KING (world superboss, WorldFoes/Autumn) -- the reaper of the last field: a slim umber pill in a tattered rust-red harvest cloak, pale antlers behind its head, the great scythe floating at its side, a few dead leaves turning round it
-- (tools/boss_look_blender.py build_autumn_v3; v3 = the Duelist language after the owner's "Keep them in the same aesthetic
-- of duelist phantom etc, not toys"). Plug-in API: the header of AimRngShared/BossLook. The head colour follows the core
-- rule (BossLook.HeadColor).
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -3.30, Hover = 0.6,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.0, Pos = Vector3.new(0, 0.2, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.6, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.36, Pos = Vector3.new(0, 2.62, 0), Show = true },
    },
    Palette = { Body = C(54, 32, 26), Shell = C(98, 36, 24), Trim = C(214, 120, 50), Bone = C(214, 202, 176), Dark = C(40, 28, 22),
        Steel = C(196, 198, 206), Leaf = C(170, 70, 30), Glow = C(255, 150, 50) },
    Glow = { Glow = true },
    Emit = { { Part = "Torso", Kind = "Spark", Color = C(255, 160, 70), Rate = 3, Size = 0.22, Speed = 1, Life = 2, Y = -2 } },
    Animate = function(B, pivot, now, Pose, dy)
        -- the cloak sways, the scythe rises over its shoulder when it attacks, the antlers sway, leaves turn round it
        local l = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.1)
        Pose(B, "Deco_Cloak", pivot, CFrame.new(0, 0.45 + dy, 0), CFrame.Angles(math.sin(now * 1.3) * 0.04, math.sin(now * 0.5) * 0.05, math.cos(now * 1.1) * 0.04))
        Pose(B, "Deco_Scythe", pivot, CFrame.new(1.7, dy, 0), CFrame.Angles(-l * 0.5 + math.sin(now * 0.9) * 0.05, 0, -l * 0.15))
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 2.9 + dy, 0.35), CFrame.Angles(math.sin(now * 1.1) * 0.03, 0, math.sin(now * 0.8) * 0.04))
        Pose(B, "Deco_Leaf", pivot, CFrame.new(0, dy, 0), CFrame.Angles(0, now * 0.6, 0))
    end,
}
