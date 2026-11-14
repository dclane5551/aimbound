-- BOSS LOOK v2: IGNIS, THE FORGE TYRANT (Fire superboss + its "Lite" major-floor version) -- "the kiln"
-- (tools/boss_look_blender.py build_fire). Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.53, Hover = 0.4,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 4.1, Pos = Vector3.new(0, 0, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.6, Pos = Vector3.new(0, 0, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.72, Pos = Vector3.new(0, 2.3, -0.75), Show = true },
    },
    Palette = { Body = C(40, 32, 34), Shell2 = C(54, 45, 45), Dark = C(30, 24, 25), Core = C(255, 104, 26),
        Glow = C(255, 140, 48), Head = C(74, 64, 64) },
    HeadTint = C(176, 52, 40), -- (ember red: the auto amber vanished into the lava glow)
    Glow = { Glow = true, Core = true },
    Emit = { { Part = "BL_StackGlow", Kind = "Fire", Color = C(255, 130, 40), Rate = 5, Size = 0.9, Speed = 3, Life = 0.9 },
        { Part = "Torso", Kind = "Spark", Color = C(255, 160, 70), Rate = 5, Size = 0.25, Speed = 3, Life = 1.4 } },
    -- the fists hover low and sway, rear up while it attacks and drop back (the pound); the rock ring turns
    Animate = function(B, pivot, now, Pose, dy)
        local l = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.1)
        for _, sx in ipairs({ -1, 1 }) do
            local side = sx < 0 and "L" or "R"
            local sway = math.sin(now * 1.8 + (sx > 0 and math.pi or 0))
            Pose(B, "Deco_Arm" .. side, pivot, CFrame.new(sx * 2.55, -0.7 + dy, -1.15),
                CFrame.new(sx * l * 0.15, sway * 0.12 + l * 1.25, sway * 0.08 + l * 0.35) * CFrame.Angles(-l * 0.6 + sway * 0.05, 0, sx * l * 0.2))
        end
        Pose(B, "Deco_Halo", pivot, CFrame.new(0, 3.4 + dy, -0.55), CFrame.Angles(math.sin(now * 0.9) * 0.08, now * (0.5 + B.phase * 0.3), 0))
    end,
}
