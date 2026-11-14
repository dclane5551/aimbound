-- BOSS LOOK v2: THE UNBLINKING (Void superboss) -- "the eye" (tools/boss_look_blender.py build_void): a black-violet orb
-- that IS an eye -- the iris ring is its seam, the pupil its head (the weak spot, dead centre on the face that looks at you,
-- like the tiny pill fliers), almond lids, six tendrils hanging below, five obsidian shards orbiting, a rune ring behind.
-- Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -3.5, Hover = 0.8,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 4.2, Pos = Vector3.new(0, 0, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.6, Pos = Vector3.new(0, 0, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.4, Pos = Vector3.new(0, 0, -2.05), Show = true },
    },
    Palette = { Body = C(30, 18, 46), Shell = C(54, 34, 82), Shell2 = C(96, 50, 150), Dark = C(22, 14, 34), Trim = C(170, 140, 220),
        Glow = C(190, 90, 255), Head = C(214, 196, 250) },
    Glow = { Glow = true },
    Emit = { { Part = "Torso", Kind = "Smoke", Color = C(110, 50, 170), Rate = 3, Size = 1.2, Speed = 0.6, Life = 2, Y = -3 } },
    -- tendrils sway, shards orbit, the rune ring turns; it blinks now and then and narrows its lids while BLINDED (never
    -- over the pupil: the weak spot stays open)
    Animate = function(B, pivot, now, Pose, dy)
        for i = 1, 6 do
            local a = math.pi * 2 * (i - 0.5) / 6
            Pose(B, "Deco_Tendril" .. i, pivot, CFrame.new(math.cos(a) * 1.25, -1.55 + dy, math.sin(a) * 1.1 + 0.35),
                CFrame.Angles(math.sin(now * 1.3 + i) * 0.22, 0, math.cos(now * 1.1 + i * 2) * 0.22))
        end
        Pose(B, "Deco_Shard", pivot, CFrame.new(0, dy, 0), CFrame.Angles(0, now * (0.5 + B.phase * 0.2), 0))
        Pose(B, "Deco_Halo", pivot, CFrame.new(0, 0.2 + dy, 2.5), CFrame.Angles(0, 0, -now * 0.35))
        if not B.lkBlinkAt then B.lkBlinkAt = now + 3 elseif now > B.lkBlinkAt + 0.25 then B.lkBlinkAt = now + 3 + math.random() * 3 end
        local blink = (now >= B.lkBlinkAt and now < B.lkBlinkAt + 0.22) and 1 or 0
        local shut = BL.Ease(B, "lkShut", B.blinded and 1 or blink, 0.35)
        Pose(B, "Deco_LidT", pivot, CFrame.new(0, dy, 0), CFrame.Angles(-shut * 0.22, 0, 0))
        Pose(B, "Deco_LidB", pivot, CFrame.new(0, dy, 0), CFrame.Angles(shut * 0.22, 0, 0))
    end,
}
