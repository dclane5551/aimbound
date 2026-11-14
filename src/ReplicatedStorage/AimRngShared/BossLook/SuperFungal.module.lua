-- BOSS LOOK v3: THE MYCELIUM HEART (world superboss, WorldFoes/Fungal) -- the rot beneath: a slim violet-black pill under a wide drooping crimson mushroom cap (gills glowing underneath), a pale tattered veil at its waist, glowing root tendrils trailing from its base
-- (tools/boss_look_blender.py build_fungal_v3; v3 = the Duelist language after the owner's "Keep them in the same aesthetic
-- of duelist phantom etc, not toys"). Plug-in API: the header of AimRngShared/BossLook. The head colour follows the core
-- rule (BossLook.HeadColor).
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.60, Hover = 0.6,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.0, Pos = Vector3.new(0, 0.2, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.6, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.36, Pos = Vector3.new(0, 2.5, 0), Show = true },
    },
    Palette = { Body = C(40, 26, 60), Veil = C(62, 50, 84), Cap = C(80, 22, 40), Spot = C(226, 214, 200), Stem = C(176, 164, 150), Root = C(70, 48, 96),
        Glow = C(120, 255, 200) },
    Glow = { Glow = true },
    Emit = { { Part = "Torso", Kind = "Spark", Color = C(170, 255, 220), Rate = 4, Size = 0.22, Speed = 0.8, Life = 2.4, Y = 2.4 } },
    Animate = function(B, pivot, now, Pose, dy)
        -- the cap turns slowly and wobbles (more while it attacks), the veil sways, the roots writhe
        local l = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.1)
        local turn = CFrame.Angles(math.sin(now * 2.2) * 0.04 * l, now * 0.15, math.sin(now * 0.9) * (0.03 + l * 0.04))
        Pose(B, "Deco_Cap", pivot, CFrame.new(0, 2.98 + dy, 0.12), turn)
        Pose(B, "Deco_Gill", pivot, CFrame.new(0, 2.98 + dy, 0.12), turn)
        Pose(B, "Deco_Veil", pivot, CFrame.new(0, 0.3 + dy, 0), CFrame.Angles(math.sin(now * 1.2) * 0.035, 0, math.cos(now * 1.0) * 0.035))
        Pose(B, "Deco_Root", pivot, CFrame.new(0, -1.9 + dy, 0), CFrame.Angles(math.sin(now * 1.3) * 0.06, math.sin(now * 0.5) * 0.15, math.cos(now * 1.1) * 0.06))
    end,
}
