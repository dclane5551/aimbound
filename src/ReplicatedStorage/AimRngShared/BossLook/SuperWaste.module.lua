-- BOSS LOOK v3: THE RECLAIMER (world superboss, WorldFoes/Waste) -- the scrapyard's warden: a slim oil-dark pill under a ragged rust tarp cloak with a hazard-yellow band, a smokestack venting toxic fumes over its shoulder, a ring of scrap behind its head, a spinning grinder blade floating at its left, a salvage claw floating at its right
-- (tools/boss_look_blender.py build_waste_v3; v3 = the Duelist language after the owner's "Keep them in the same aesthetic
-- of duelist phantom etc, not toys"). Plug-in API: the header of AimRngShared/BossLook. The head colour follows the core
-- rule (BossLook.HeadColor).
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -3.20, Hover = 0.6,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.0, Pos = Vector3.new(0, 0.2, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.6, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.36, Pos = Vector3.new(0, 2.6, 0), Show = true },
    },
    Palette = { Body = C(50, 44, 40), Shell = C(86, 48, 30), Hazard = C(214, 170, 40), Dark = C(30, 28, 28), Steel = C(150, 150, 156), Rust = C(120, 60, 36),
        Glow = C(150, 240, 60) },
    Glow = { Glow = true },
    Emit = { { Part = "BL_StackGlow", Kind = "Smoke", Color = C(120, 200, 60), Rate = 4, Size = 0.9, Speed = 2, Life = 1.6 } },
    Animate = function(B, pivot, now, Pose, dy)
        -- the grinder spins (faster while it attacks), the claw flexes and reaches out on an attack, the tarp sways, the
        -- scrap ring turns slowly
        local l = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.1)
        B.lkMaw = (B.lkMaw or 0) + 0.12 + l * 0.4
        Pose(B, "Deco_Maw", pivot, CFrame.new(-1.7, 0.4 + dy, -0.5), CFrame.Angles(0, 0, B.lkMaw))
        Pose(B, "Deco_Claw", pivot, CFrame.new(1.7, 0.3 + dy, 0.1), CFrame.new(0, 0, -l * 0.4) * CFrame.Angles(-l * 0.35 + math.sin(now * 1.2) * 0.06, l * 0.2, math.sin(now * 0.9) * 0.04))
        Pose(B, "Deco_Tarp", pivot, CFrame.new(0, 0.4 + dy, 0), CFrame.Angles(math.sin(now * 1.3) * 0.035, 0, math.cos(now * 1.1) * 0.035))
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 2.7 + dy, 0.5), CFrame.Angles(0, 0, now * 0.25))
    end,
}
