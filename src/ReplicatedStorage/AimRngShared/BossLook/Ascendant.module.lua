-- BOSS LOOK v2: THE ASCENDANT (Trial of Ascension) -- "the judge" (tools/boss_look_blender2.py build_ascendant, builder
-- bosses2). A slate pill with a WHEEL OF EIGHT BLADES standing behind it (the identity piece: VERDICT / BLADE HALO; it
-- turns faster each phase), two angular pauldron plates floating over its shoulders, a greatsword floating point-down
-- before it that swings up while it casts, a short folded-plate skirt, a teal diamond over the head. Hooked through
-- EnemyModels.DecorateAscendant (TryLook "Ascendant"). Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.45, Hover = 0.6,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 1.8, Pos = Vector3.new(0, 0.2, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 0.9, Pos = Vector3.new(0, 0.6, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.32, Pos = Vector3.new(0, 2.75, 0), Show = true },
    },
    Palette = { Body = C(44, 58, 66), Shell = C(28, 36, 42), Shell2 = C(150, 156, 170), Trim = C(204, 178, 104),
        Steel = C(176, 180, 190), Glow = C(60, 240, 210), Head = C(220, 236, 236) },
    Glow = { Glow = true },
    Emit = {},
    Animate = function(B, pivot, now, Pose, dy)
        local lift = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.1)
        Pose(B, "Deco_Wheel", pivot, CFrame.new(0, 1.75 + dy, 1.05), CFrame.Angles(0, 0, now * (0.35 + B.phase * 0.2)))
        Pose(B, "Deco_Robe", pivot, CFrame.new(0, 0 + dy, 0), CFrame.Angles(math.sin(now * 1.2) * 0.03, now * 0.2, math.sin(now) * 0.02))
        for _, sx in ipairs({ -1, 1 }) do
            Pose(B, "Deco_Pauldron" .. (sx < 0 and "L" or "R"), pivot, CFrame.new(), CFrame.new(0, math.sin(now * 1.5 + sx) * 0.12, 0))
        end
        Pose(B, "Deco_Sword", pivot, CFrame.new(0, 0.9 + dy, -1.35), CFrame.Angles(lift * 1.3 + math.sin(now * 1.1) * 0.03, 0, 0))
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 3.75 + dy, 0), CFrame.new(0, math.sin(now * 1.6) * 0.08, 0) * CFrame.Angles(0, now * 1.1, 0))
    end,
}
