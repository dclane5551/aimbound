-- BOSS LOOK v2: COUNT NOCTIS (world superboss, WorldFoes/Gothic) -- a slim night-black pill, a towering collar behind the pale head (blood-red inside), a floor-length cape, two bat wings, a ruby on the chest, bats circling over its head
-- (tools/boss_look_blender.py build_gothic). Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.76, Hover = 0.7,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 1.8, Pos = Vector3.new(0, 0.2, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.2, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.36, Pos = Vector3.new(0, 2.6, 0), Show = true },
    },
    Palette = { Body = C(34, 26, 44), Shell = C(26, 20, 34), Shell2 = C(46, 34, 58), Dark = C(18, 14, 24), Blood = C(140, 16, 34), Glow = C(230, 30, 60),
        Head = C(206, 196, 216) },
    Glow = { Glow = true },
    Emit = { { Part = "Torso", Kind = "Smoke", Color = C(70, 20, 40), Rate = 3, Size = 1.2, Speed = 0.6, Life = 2, Y = -2.6 } },
    Animate = function(B, pivot, now, Pose, dy)
        -- wings beat slow (spread wide while it attacks), the cape sways, the bats circle above
        local l = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.1)
        local f = math.sin(now * 2.2) * 0.18 + l * 0.35
        Pose(B, "Deco_WingL", pivot, CFrame.new(-0.75, 1.55 + dy, 0.55), CFrame.Angles(0, f * 0.6, -f))
        Pose(B, "Deco_WingR", pivot, CFrame.new(0.75, 1.55 + dy, 0.55), CFrame.Angles(0, -f * 0.6, f))
        Pose(B, "Deco_Cape", pivot, CFrame.new(0, 1.6 + dy, 0.15), CFrame.Angles(math.sin(now * 1.4) * 0.05 + l * 0.08, 0, math.cos(now * 1.1) * 0.03))
        Pose(B, "Deco_Bat", pivot, CFrame.new(0, 4.1 + dy, 0), CFrame.Angles(0, now * 0.9, 0))
    end,
}
