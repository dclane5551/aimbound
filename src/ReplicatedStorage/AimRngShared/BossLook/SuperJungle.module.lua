-- BOSS LOOK v3: THE IDOL KING (world superboss, WorldFoes/Jungle) -- the temple's last god: a slim weathered-stone pill under a carved stone headdress with a gold rim, a fan of slim gold feathers rising behind it, dark vines climbing the body, two great stone hands floating at its sides that rise and slam
-- (tools/boss_look_blender.py build_jungle_v3; v3 = the Duelist language after the owner's "Keep them in the same aesthetic
-- of duelist phantom etc, not toys"). Plug-in API: the header of AimRngShared/BossLook. The head colour follows the core
-- rule (BossLook.HeadColor).
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.10, Hover = 0.6,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.0, Pos = Vector3.new(0, 0.2, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.6, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.36, Pos = Vector3.new(0, 2.62, 0), Show = true },
    },
    Palette = { Body = C(54, 52, 46), Shell = C(78, 74, 62), Gold = C(196, 150, 52), Jade = C(38, 140, 106), Leaf = C(40, 76, 40), Dark = C(34, 32, 28),
        Glow = C(255, 196, 70) },
    HeadTint = C(84, 192, 146), -- (jade: the auto rule turns the gold glow into a gold head on the gold feathers)
    Glow = { Glow = true },
    Emit = { { Part = "Torso", Kind = "Spark", Color = C(255, 210, 110), Rate = 3, Size = 0.22, Speed = 1, Life = 2, Y = -2 } },
    Animate = function(B, pivot, now, Pose, dy)
        -- the hands drift; attacking, they rise and slam down; the feathers sway, the vines breathe
        local l = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.1)
        for _, sx in ipairs({ -1, 1 }) do
            local side = sx < 0 and "L" or "R"
            Pose(B, "Deco_Hand" .. side, pivot, CFrame.new(sx * 1.75, 0.2 + dy, -0.55),
                CFrame.new(math.sin(now * 1.1 + sx) * 0.12, math.sin(now * 1.7 + sx) * 0.2 + l * 0.9, -l * 0.25) * CFrame.Angles(-l * 0.5, 0, sx * l * 0.15))
        end
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 2.9 + dy, 0.75), CFrame.Angles(math.sin(now * 1.0) * 0.03, 0, math.sin(now * 0.8) * 0.04))
        Pose(B, "Deco_Vine", pivot, CFrame.new(0, dy, 0), CFrame.Angles(0, math.sin(now * 0.6) * 0.05, 0))
    end,
}
