-- BOSS LOOK v2: SERAPH ARCHON (trial boss / map guardian) -- "the seraph" (tools/boss_look_blender2.py build_archon,
-- builder bosses2). A tall midnight pill, SIX ivory blade-wings (three a side) fanning from behind the shoulders with lit
-- gold leading edges, a stiff collar behind the neck, a sword of light floating point-down at its right, a rayed halo
-- turning behind the head, a gold seam. SCALES OF JUDGEMENT still reads: B.raised (-1 left / 1 right) lifts that side's
-- wings high and drops the other (the safe half), as the old Archon's Animate did. Plug-in API: the header of
-- AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.75, Hover = 0.8,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 1.7, Pos = Vector3.new(0, 0.2, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 0.9, Pos = Vector3.new(0, 0.6, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.32, Pos = Vector3.new(0, 2.75, 0), Show = true },
    },
    Palette = { Body = C(36, 40, 70), Shell = C(24, 26, 46), Trim = C(206, 198, 178), Gold = C(214, 164, 64),
        Glow = C(255, 206, 110), Head = C(232, 222, 196) },
    Glow = { Glow = true },
    Emit = {},
    Animate = function(B, pivot, now, Pose, dy)
        local flap = math.sin(now * 1.6) * 0.12
        local wantL = (B.raised == -1) and 0.9 or ((B.raised == 1) and -0.35 or 0)
        local wantR = (B.raised == 1) and 0.9 or ((B.raised == -1) and -0.35 or 0)
        local l = BL.Ease(B, "lkWingL", wantL, 0.12)
        local r = BL.Ease(B, "lkWingR", wantR, 0.12)
        -- (the boss faces -Z: +X is its right; raising = the tips swing up about the shoulder)
        Pose(B, "Deco_WingL", pivot, CFrame.new(-0.55, 1.35 + dy, 0.65), CFrame.Angles(0, -flap * 0.4, -(l + flap)))
        Pose(B, "Deco_WingR", pivot, CFrame.new(0.55, 1.35 + dy, 0.65), CFrame.Angles(0, flap * 0.4, r + flap))
        Pose(B, "Deco_Sword", pivot, CFrame.new(1.55, 0.9 + dy, -0.55), CFrame.new(0, math.sin(now * 1.2) * 0.12, 0) * CFrame.Angles(0, now * 0.25, math.sin(now * 0.9) * 0.04))
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 2.75 + dy, 0.5), CFrame.Angles(0, 0, now * (0.3 + B.phase * 0.15)))
    end,
}
