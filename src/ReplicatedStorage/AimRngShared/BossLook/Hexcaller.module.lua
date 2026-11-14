-- BOSS LOOK v2: HEXCALLER (miniboss) -- "the hierophant" (tools/boss_look_blender2.py build_hexcaller, builder bosses2).
-- A slender pill in a stiff vestment of eight pointed blade-plates hanging from the waist (each with a lit centre line), a
-- high stole rising behind the shoulders to two points (behind the head only), a staff floating at its right with a
-- faceted teal crystal caged in its head (tips forward while it casts), a rune circle turning on the floor under it, a
-- hexagon crown with six points turning over the head. Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.94, Hover = 0.08,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 1.6, Pos = Vector3.new(0, 0.3, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 0.8, Pos = Vector3.new(0, 0.8, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.28, Pos = Vector3.new(0, 2.9, 0), Show = true },
    },
    Palette = { Body = C(26, 34, 48), Shell = C(20, 26, 36), Shell2 = C(48, 64, 82), Trim = C(196, 236, 224),
        Dark = C(26, 24, 30), Glow = C(70, 235, 190), Head = C(190, 226, 220) },
    Glow = { Glow = true },
    Emit = { { Part = "Deco_StaffHead", Kind = "Spark", Color = C(120, 255, 210), Rate = 3, Size = 0.25, Speed = 1.2, Life = 1.2 } },
    Animate = function(B, pivot, now, Pose, dy)
        Pose(B, "Deco_Robe", pivot, CFrame.new(0, 0.62 + dy, 0), CFrame.Angles(math.sin(now * 1.8) * 0.035, math.sin(now * 0.6) * 0.16, math.sin(now * 1.3) * 0.02))
        Pose(B, "Deco_Sigil", pivot, CFrame.new(0, -2.9 + dy, 0), CFrame.Angles(0, now * (0.6 + B.phase * 0.3), 0))
        local raise = BL.Ease(B, "lkRaise", (B.active > 0) and 1 or 0, 0.15)
        Pose(B, "Deco_Staff", pivot, CFrame.new(1.75, -0.4 + dy, -0.35),
            CFrame.new(0, math.sin(now * 1.3) * 0.12 + raise * 0.3, 0) * CFrame.Angles(-raise * 0.42, 0, math.sin(now * 0.9) * 0.04))
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 3.85 + dy, 0), CFrame.new(0, math.sin(now * 1.6) * 0.06, 0) * CFrame.Angles(0, now * (0.7 + B.phase * 0.3), 0))
    end,
}
