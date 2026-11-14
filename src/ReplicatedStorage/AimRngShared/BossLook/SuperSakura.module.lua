-- BOSS LOOK v2: THE SHOGUN OF PETALS (world superboss, WorldFoes/Sakura) -- a lacquered crimson pill in samurai plate (shoulder guards, a laced skirt, a helmet shell behind the head under a golden crescent crest), a floating katana, petals drifting round it
-- (tools/boss_look_blender.py build_sakura). Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.1, Hover = 0.6,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.2, Pos = Vector3.new(0, 0, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.44, Pos = Vector3.new(0, 2.6, 0), Show = true },
    },
    Palette = { Body = C(126, 22, 38), Lacquer = C(34, 22, 30), Cord = C(255, 160, 200), Gold = C(232, 186, 76), Steel = C(196, 200, 214), Dark = C(20, 16, 20),
        Petal = C(255, 176, 206), Glow = C(255, 120, 170), Head = C(236, 222, 228) },
    Glow = { Glow = true },
    Emit = { { Part = "Torso", Kind = "Spark", Color = C(255, 190, 215), Rate = 3, Size = 0.3, Speed = 1, Life = 2.2, Y = -1.8 } },
    Animate = function(B, pivot, now, Pose, dy)
        -- the katana rests at its side, rises to a guard (point at you) when it attacks; petals drift round; the skirt sways
        local l = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.12)
        Pose(B, "Deco_Blade", pivot, CFrame.new(1.9, 0.22 + dy, 0.9),
            CFrame.new(0, l * 0.5, 0) * CFrame.Angles(l * 0.45 + math.sin(now * 1.2) * 0.04, -l * 0.25, math.sin(now * 0.9) * 0.03))
        Pose(B, "Deco_Petal", pivot, CFrame.new(0, dy, 0), CFrame.Angles(0, now * 0.8, 0))
        Pose(B, "Deco_Skirt", pivot, CFrame.new(0, -0.2 + dy, 0), CFrame.Angles(math.sin(now * 1.6) * 0.03, 0, math.cos(now * 1.3) * 0.03))
    end,
}
