-- BOSS LOOK v2: THE DUELIST (major boss / map guardian) -- "the fencer" (tools/boss_look_blender.py build_duelist). THE
-- REFERENCE of the pill family (owner 2026-10-13: "duelist looks the best"): a slender pill in a long open tailcoat (piping
-- on every edge, a standing collar, split tails), a pale mask head, a rapier with a cup hilt floating en garde at its right,
-- a crescent halo behind the head, a high violet sash seam. Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.95, Hover = 0.75,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 1.5, Pos = Vector3.new(0, 0.3, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 0.8, Pos = Vector3.new(0, 0.6, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.32, Pos = Vector3.new(0, 2.6, 0), Show = true },
    },
    Palette = { Body = C(52, 30, 84), Shell = C(20, 15, 30), Trim = C(104, 92, 132), Steel = C(150, 146, 176),
        Dark = C(18, 12, 26), Glow = C(200, 120, 255), Head = C(168, 154, 204) },
    Glow = { Glow = true },
    Emit = {},
    -- the rapier: en garde (the point circles), raised across the body to PARRY while the guard is up (B.guarding), drawn
    -- back + twisted before a LUNGE (B.lungeAt); the coat sways and flares back on the lunge; the halo rocks
    Animate = function(B, pivot, now, Pose, dy)
        local lunging = os.clock() < (B.lungeAt or 0) + 0.3
        local guard = BL.Ease(B, "lkGuard", B.guarding and 1 or 0, 0.2)
        local lunge = BL.Ease(B, "lkLunge", lunging and 1 or 0, 0.25)
        local idle = CFrame.Angles(math.sin(now * 2.2) * 0.07, math.sin(now * 1.3) * 0.09, math.cos(now * 2.2) * 0.05)
        local rot = idle
            * CFrame.Angles(math.rad(50) * guard, math.rad(-35) * guard, math.rad(-25) * guard)
            * CFrame.new(0, 0, 0.6 * lunge) * CFrame.Angles(math.rad(-25) * lunge, math.rad(18) * lunge, 0)
        Pose(B, "Deco_Sword", pivot, CFrame.new(1.3, 0.1 + dy, -0.6), rot)
        B.lkShard = (B.lkShard or 0) + 0.05 * (1 + B.phase)
        Pose(B, "Deco_ShardHalo", pivot, CFrame.new(0, 2.6 + dy, 0.42), CFrame.Angles(0, 0, math.sin(B.lkShard) * 0.25))
        Pose(B, "Deco_Coat", pivot, CFrame.new(0, 1.6 + dy, 0), CFrame.Angles(math.sin(now * 1.6) * 0.03 - lunge * 0.12, math.sin(now * 0.8) * 0.04, math.sin(now * 1.2) * 0.025))
    end,
}
