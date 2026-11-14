-- BOSS LOOK v2: THE SANDMAN (Dream superboss) -- "the dream-giver" (tools/boss_look_blender.py build_dream): a navy pill in a
-- scalloped robe trimmed in light, a long nightcap with a glowing pompom trailing behind its moon-pale head, five stars
-- orbiting, a floating hourglass. Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.96, Hover = 0.6,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.3, Pos = Vector3.new(0, 0.2, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.6, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.5, Pos = Vector3.new(0, 2.65, 0), Show = true },
    },
    Palette = { Body = C(36, 32, 78), Shell = C(60, 46, 120), Shell2 = C(176, 112, 186), Trim = C(222, 192, 118), Glow = C(255, 150, 230),
        Star = C(255, 226, 140), Ice = C(200, 214, 250), Head = C(232, 222, 196) },
    Glow = { Glow = true, Star = true },
    Emit = { { Part = "Torso", Kind = "Spark", Color = C(255, 230, 160), Rate = 4, Size = 0.25, Speed = 1, Life = 2, Y = -2.6 } },
    Build = function(model)
        for _, p in ipairs(model:GetChildren()) do
            if p.Name == "Deco_HourglassGlass" then p.Transparency = 0.45 end
        end
    end,
    -- the robe drifts, the stars orbit, the hourglass rocks and bobs (tips toward you while it attacks)
    Animate = function(B, pivot, now, Pose, dy)
        local l = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.08)
        Pose(B, "Deco_Robe", pivot, CFrame.new(0, 0.6 + dy, 0), CFrame.Angles(math.sin(now * 1.4) * 0.04, now * 0.12, math.cos(now * 1.1) * 0.04))
        Pose(B, "Deco_Star", pivot, CFrame.new(0, dy, 0), CFrame.Angles(0, now * (0.4 + 0.25 * B.phase), 0))
        Pose(B, "Deco_Hourglass", pivot, CFrame.new(2.45, 0.2 + dy, -0.6), CFrame.new(0, math.sin(now * 1.5) * 0.2, 0) * CFrame.Angles(-l * 0.5, 0, math.sin(now * 0.9) * 0.25))
    end,
}
