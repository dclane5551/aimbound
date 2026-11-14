-- BOSS LOOK v2: THE LAMPLIGHTER (maps-only guardian, MAPS V2 2026-10-30) -- "the keeper of the last lamps"
-- (tools/boss_look_blender_maps.py build_lamplighter). A slim soot-blue pill in a short bell capelet (open at the front, brass
-- clasp + hem piping, a brass collar), a tall lamp-pole floating at his right with a crook and a caged amber lantern hanging at
-- shoulder height (clear of the head), a thin brass halo ring behind the head with a small flame bead, an amber seam.
-- Plug-in API: the header of AimRngShared/BossLook. Kit meshes: ReplicatedStorage.BossKit.Lamplighter (in the PLACE).
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -3.05, Hover = 0.6,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 1.45, Pos = Vector3.new(0, 0.3, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 0.8, Pos = Vector3.new(0, 0.6, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.32, Pos = Vector3.new(0, 2.6, 0), Show = true },
    },
    Palette = { Body = C(30, 32, 46), Shell = C(44, 46, 64), Trim = C(176, 140, 82), Dark = C(20, 20, 26),
        Glow = C(255, 178, 76), Head = C(240, 200, 150) },
    Glow = { Glow = true },
    Emit = {},
    -- the pole leans its lantern toward you while he casts (B.lampAt / an attack); the lantern swings on its chain, the capelet
    -- sways, the flame bead walks round the halo (faster each phase)
    Animate = function(B, pivot, now, Pose, dy)
        local casting = (os.clock() < (B.lampAt or 0) + 1.1) or (B.active or 0) > 0
        local raise = BL.Ease(B, "lkRaise", casting and 1 or 0, 0.14)
        local poleH = CFrame.new(1.85, 0 + dy, -0.15)
        local poleR = CFrame.Angles(-0.32 * raise + math.sin(now * 1.3) * 0.04, 0, math.sin(now * 0.9) * 0.035 - 0.08 * raise)
        local poleT = poleH * poleR * poleH:Inverse()
        Pose(B, "Deco_Pole", pivot, CFrame.identity, poleT)
        local hookH = CFrame.new(1.35, 2.95 + dy, -0.15)
        local swing = CFrame.Angles(math.sin(now * 1.7 + 0.6) * 0.1 + 0.25 * raise, 0, math.sin(now * 1.7) * 0.14)
        Pose(B, "Deco_Lantern", pivot, CFrame.identity, poleT * hookH * swing * hookH:Inverse())
        Pose(B, "Deco_Cape", pivot, CFrame.new(0, 1.95 + dy, 0), CFrame.Angles(math.sin(now * 1.5) * 0.035, math.sin(now * 0.7) * 0.05, math.sin(now * 1.2) * 0.03))
        Pose(B, "Deco_Halo", pivot, CFrame.new(0, 2.75 + dy, 0.48), CFrame.Angles(0, 0, now * (0.5 + 0.25 * (B.phase or 1))))
    end,
}
