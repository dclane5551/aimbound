-- BOSS LOOK v2: DREAD CHRONARCH (trial boss / map guardian) -- "the clockwork pill" (tools/boss_look_blender2.py
-- build_chronarch, builder bosses2). A bronze pill with a brass CLOCK FACE set in its chest (twelve ticks; the minute hand
-- jumps a notch every beat, the hour hand creeps), a clock-tower collar of brass teeth round the head, a pendulum swinging
-- under it on the beat, two great brass gears turning at its sides, an orrery (two tilted rings + planets) turning over
-- the head, a cyan seam. (Its metronome pressure loop is off since 0.68: the beat here is the animation's own; if B.beat
-- runs again the hands follow it.) Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
local BEAT = 0.9
return {
    On = true,
    Bottom = -3.0, Hover = 0.3,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.2, Pos = Vector3.new(0, 0, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.35, -0.6) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.44, Pos = Vector3.new(0, 2.55, 0), Show = true },
    },
    Palette = { Body = C(64, 46, 34), Shell = C(34, 26, 22), Trim = C(184, 146, 72), Gold = C(170, 132, 60),
        Glow = C(90, 230, 255), Head = C(226, 196, 140) },
    Glow = { Glow = true },
    Emit = {},
    Animate = function(B, pivot, now, Pose, dy)
        local beat = B.beat or math.floor(now / BEAT)
        local frac = (now / BEAT) % 1
        Pose(B, "Deco_HandB", pivot, CFrame.new(0, 0.35 + dy, -1.32), CFrame.Angles(0, 0, -(beat * math.pi / 6)))
        Pose(B, "Deco_HandA", pivot, CFrame.new(0, 0.35 + dy, -1.32), CFrame.Angles(0, 0, -(now * 0.1)))
        Pose(B, "Deco_Pendulum", pivot, CFrame.new(0, -1.7 + dy, 0), CFrame.Angles(0, 0, math.sin((beat + frac) * math.pi) * 0.4))
        Pose(B, "Deco_GearL", pivot, CFrame.new(-2.05, -0.2 + dy, 0.2), CFrame.Angles(now * 0.8, 0, 0))
        Pose(B, "Deco_GearR", pivot, CFrame.new(2.05, -0.2 + dy, 0.2), CFrame.Angles(-now * 0.8, 0, 0))
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 3.6 + dy, 0), CFrame.Angles(0, now * (0.5 + B.phase * 0.25), 0))
    end,
}
