-- BOSS LOOK v3: MAMA BAYOU (world superboss, WorldFoes/Bayou) -- the swamp witch: a slim bog-dark pill under a ragged moss shawl with a bone fringe, long grey hair falling behind her head, a crooked staff with a skull and a lantern wisp, three wisps circling
-- (tools/boss_look_blender.py build_bayou_v3; v3 = the Duelist language after the owner's "Keep them in the same aesthetic
-- of duelist phantom etc, not toys"). Plug-in API: the header of AimRngShared/BossLook. The head colour follows the core
-- rule (BossLook.HeadColor).
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.21, Hover = 0.6,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.0, Pos = Vector3.new(0, 0.2, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.6, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.36, Pos = Vector3.new(0, 2.6, 0), Show = true },
    },
    Palette = { Body = C(34, 40, 36), Moss = C(40, 46, 32), Bone = C(210, 200, 176), Hair = C(140, 142, 134), Wood = C(60, 46, 36), Glow = C(140, 255, 180) },
    Glow = { Glow = true },
    Emit = { { Part = "Torso", Kind = "Smoke", Color = C(90, 120, 96), Rate = 3, Size = 1.2, Speed = 0.5, Life = 2.2, Y = -2.3 } },
    Animate = function(B, pivot, now, Pose, dy)
        -- the wisps circle, the shawl and hair sway, the staff lifts when she attacks
        local l = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.1)
        Pose(B, "Deco_Wisp", pivot, CFrame.new(0, dy, 0), CFrame.Angles(0, now * 0.7, 0))
        Pose(B, "Deco_Moss", pivot, CFrame.new(0, 1.75 + dy, 0), CFrame.Angles(math.sin(now * 1.2) * 0.035, 0, math.cos(now * 1.0) * 0.035))
        Pose(B, "Deco_Staff", pivot, CFrame.new(1.65, -2.2 + dy, 0), CFrame.new(0, l * 0.5, 0) * CFrame.Angles(-l * 0.25 + math.sin(now * 0.8) * 0.05, 0, math.sin(now * 0.7) * 0.04))
        Pose(B, "Deco_Hair", pivot, CFrame.new(0, 2.92 + dy, 0), CFrame.Angles(math.sin(now * 1.5) * 0.035, 0, 0))
    end,
}
