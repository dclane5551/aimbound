-- BOSS LOOK v3: ADMIRAL COGSWORTH (world superboss, WorldFoes/Sky) -- the sky captain: a slim bronze pill in a navy greatcoat (the Duelist cut) with gold piping and epaulettes, a bicorne, a great brass cog turning behind its head as a halo, a floating cutlass
-- (tools/boss_look_blender.py build_sky_v3; v3 = the Duelist language after the owner's "Keep them in the same aesthetic
-- of duelist phantom etc, not toys"). Plug-in API: the header of AimRngShared/BossLook. The head colour follows the core
-- rule (BossLook.HeadColor).
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.85, Hover = 0.6,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.0, Pos = Vector3.new(0, 0.2, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.6, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.36, Pos = Vector3.new(0, 2.6, 0), Show = true },
    },
    Palette = { Body = C(40, 38, 48), Navy = C(22, 28, 56), Gold = C(220, 178, 74), Brass = C(168, 122, 56), Steel = C(196, 200, 210), Glow = C(255, 190, 90) },
    HeadTint = C(140, 182, 228), -- (sky blue: the auto gold head sat on the brass cog behind it)
    Glow = { Glow = true },
    Emit = { { Part = "Torso", Kind = "Smoke", Color = C(190, 180, 160), Rate = 2, Size = 0.9, Speed = 0.6, Life = 2, Y = -2.2 } },
    Animate = function(B, pivot, now, Pose, dy)
        -- the cog turns (faster each phase), the coat tails swing, the cutlass rises to the guard when it attacks
        local l = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.1)
        Pose(B, "Deco_Gear", pivot, CFrame.new(0, 2.7 + dy, 0.6), CFrame.Angles(0, 0, now * (0.5 + B.phase * 0.2)))
        Pose(B, "Deco_Coat", pivot, CFrame.new(0, 2.3 + dy, 0), CFrame.Angles(math.sin(now * 1.5) * 0.025, 0, 0))
        Pose(B, "Deco_Cutlass", pivot, CFrame.new(1.6, 0.3 + dy, 0.6), CFrame.new(0, l * 0.4, 0) * CFrame.Angles(l * 0.4 + math.sin(now * 1.2) * 0.04, -l * 0.2, 0))
    end,
}
