-- BOSS LOOK v2: THE DROWNED KRAKEN (world superboss, WorldFoes/Abyss) -- "the abyssal priest" (tools/boss_look_blender2.py
-- build_abyss2, rebuilt by builder bosses2 after the owner: the purple octopus read as a toy). A tall deep-sea pill under a
-- hood that rises behind the head into a BONY CREST of ridged plates, a pale bone collar, a stiff mantle cut into points
-- down to the waist, eight hooked tentacles hanging below it like a cloak hem (two groups that sway against each other,
-- faster while it attacks), a glowing anglerfish LURE on a bony stalk arching over the head (it bobs and pulses), faint
-- photophores down the hood, a cold cyan seam. (The kit's moves read no model parts; Deco_Tentacle0/1 keep their names.)
-- Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.94, Hover = 0.6,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 1.7, Pos = Vector3.new(0, 0.3, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 0.8, Pos = Vector3.new(0, 0.7, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.32, Pos = Vector3.new(0, 2.85, 0), Show = true },
    },
    Palette = { Body = C(18, 30, 44), Shell = C(12, 18, 28), Shell2 = C(26, 40, 54), Bone = C(170, 162, 140), Glow = C(110, 255, 230) },
    Glow = { Glow = true },
    Emit = { { Part = "Deco_LureGlow", Kind = "Spark", Color = C(170, 255, 240), Rate = 3, Size = 0.25, Speed = 0.8, Life = 1.8 } },
    Animate = function(B, pivot, now, Pose, dy)
        local l = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.1)
        local k = 1 + l
        Pose(B, "Deco_Tentacle0", pivot, CFrame.new(0, -0.4 + dy, 0), CFrame.Angles(math.sin(now * 1.6 * k) * 0.1, math.sin(now * 0.7) * 0.22, math.cos(now * 1.3 * k) * 0.08))
        Pose(B, "Deco_Tentacle1", pivot, CFrame.new(0, -0.4 + dy, 0), CFrame.Angles(math.cos(now * 1.5 * k) * 0.1, -math.sin(now * 0.7) * 0.22, math.sin(now * 1.2 * k) * 0.08))
        Pose(B, "Deco_Cloak", pivot, CFrame.new(0, 1.4 + dy, 0), CFrame.Angles(math.sin(now * 1.3) * 0.03, math.sin(now * 0.6) * 0.05, math.sin(now * 1.1) * 0.02))
        -- the lure (stalk + bulb) bobs from its root on the crest, dips toward you while it attacks
        Pose(B, "Deco_Lure", pivot, CFrame.new(0, 4.05 + dy, 0.55), CFrame.Angles(-0.12 * l + math.sin(now * 1.4) * 0.07, math.sin(now * 0.9) * 0.08, 0))
        B.lkBulb = B.lkBulb or B.model:FindFirstChild("Deco_LureGlow")
        if B.lkBulb then B.lkBulb.Transparency = 0.25 * (0.5 + 0.5 * math.sin(now * 2.4)) end
    end,
}
