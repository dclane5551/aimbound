-- BOSS LOOK v2: THE FROST SOVEREIGN (Ice superboss) -- "the glacier queen" (tools/boss_look_blender.py build_ice):
-- a deep-blue pill in a gown of hanging ice crystals, crystal epaulettes, a fan tiara behind the pale head, two floating
-- crystal greatswords, an ice-blue seam. Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.5, Hover = 0.6,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.2, Pos = Vector3.new(0, 0.2, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.8, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.5, Pos = Vector3.new(0, 2.85, 0), Show = true },
    },
    Palette = { Body = C(30, 56, 104), Ice = C(118, 168, 214), Dark = C(24, 34, 58), Glow = C(120, 220, 255), Head = C(138, 182, 224) },
    Glow = { Glow = true },
    Emit = { { Part = "Torso", Kind = "Spark", Color = C(200, 240, 255), Rate = 4, Size = 0.22, Speed = 1.5, Life = 1.8, Y = -2.2 } },
    -- the greatswords drift and rise (points up toward you) while she attacks; the gown turns slowly; the tiara sways
    Animate = function(B, pivot, now, Pose, dy)
        local l = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.1)
        for _, sx in ipairs({ -1, 1 }) do
            local side = sx < 0 and "L" or "R"
            Pose(B, "Deco_Arm" .. side, pivot, CFrame.new(sx * 2.15, 1.5 + dy, -0.2),
                CFrame.new(0, math.sin(now * 1.3 + sx) * 0.15 + l * 0.6, -l * 0.3) * CFrame.Angles(-l * 0.9 + math.sin(now * 1.1 + sx) * 0.05, 0, sx * (0.06 + l * 0.15)))
        end
        Pose(B, "Deco_Gown", pivot, CFrame.new(0, 0.55 + dy, 0), CFrame.Angles(math.sin(now * 1.1) * 0.03, now * 0.2, math.sin(now * 0.9) * 0.03))
        Pose(B, "Deco_Halo", pivot, CFrame.new(0, 2.85 + dy, 0.45), CFrame.Angles(0, 0, math.sin(now * 0.8) * 0.08))
    end,
}
