-- BOSS LOOK v2: PHARAOH SUNKA (world superboss, WorldFoes/Desert) -- a lapis pill wrapped in linen under a broad gold-and-lapis collar, a lapis nemes with gold stripes behind the gold head, a pleated kilt, the crook + flail crossed, a winged sun disc behind
-- (tools/boss_look_blender.py build_desert). Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.15, Hover = 0.6,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.1, Pos = Vector3.new(0, 0, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.44, Pos = Vector3.new(0, 2.62, 0), Show = true },
    },
    Palette = { Body = C(30, 46, 98), Linen = C(214, 200, 162), Gold = C(226, 180, 66), Lapis = C(34, 64, 150), Glow = C(90, 220, 255), Head = C(226, 184, 78) },
    Glow = { Glow = true },
    Emit = { { Part = "Torso", Kind = "Spark", Color = C(255, 220, 140), Rate = 3, Size = 0.25, Speed = 1, Life = 2, Y = -2 } },
    Animate = function(B, pivot, now, Pose, dy)
        -- the crook + flail lift when it attacks, the kilt sways, the winged sun rocks gently
        local l = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.1)
        Pose(B, "Deco_Crook", pivot, CFrame.new(0, 0.3 + dy, -1.4), CFrame.new(0, l * 0.4, -l * 0.2) * CFrame.Angles(-l * 0.35 + math.sin(now * 0.8) * 0.04, 0, 0))
        Pose(B, "Deco_Robe", pivot, CFrame.new(0, -0.55 + dy, 0), CFrame.Angles(math.sin(now * 1.2) * 0.03, 0, math.cos(now * 1.0) * 0.03))
        Pose(B, "Deco_Halo", pivot, CFrame.new(0, 1.9 + dy, 0.95), CFrame.Angles(0, 0, math.sin(now * 0.7) * 0.06))
    end,
}
