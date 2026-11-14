-- BOSS LOOK v2: PHANTOM STALKER (miniboss) -- "the veiled pill" (tools/boss_look_blender.py build_phantom).
-- A dark violet teardrop pill hovering in a nine-pointed tattered cloak, a cowl rising behind the head (never in front),
-- two crescent scythes floating at its sides, a shard crown turning over the head, a violet waist seam. Plug-in API:
-- the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -3.29, Hover = 0.9,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.5, Pos = Vector3.new(0, 0.1, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.3, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.48, Pos = Vector3.new(0, 2.52, 0), Show = true },
    },
    Palette = { Body = C(46, 30, 72), Shell = C(34, 23, 52), Shell2 = C(66, 46, 100), Trim = C(205, 186, 240),
        Steel = C(150, 138, 186), Dark = C(26, 18, 38), Glow = C(190, 120, 255), Head = C(150, 126, 200) },
    Glow = { Glow = true },
    Emit = { { Part = "Torso", Kind = "Smoke", Color = C(120, 70, 190), Rate = 3, Size = 1.4, Speed = 0.8, Life = 1.8, Y = -2.6 } },
    -- cloak billow; scythes drift, then rise + tip toward you while it attacks; the crown turns faster each phase
    Animate = function(B, pivot, now, Pose, dy)
        local raise = BL.Ease(B, "lkRaise", (B.active > 0) and 1 or 0, 0.12)
        Pose(B, "Deco_Cloak", pivot, CFrame.new(0, 0.6 + dy, 0), CFrame.Angles(math.sin(now * 2.1) * 0.05, math.sin(now * 0.7) * 0.12, math.sin(now * 1.7) * 0.04))
        for _, sx in ipairs({ -1, 1 }) do
            local side = sx < 0 and "L" or "R"
            local bob = math.sin(now * 1.6 + sx) * 0.14 + raise * 0.5
            Pose(B, "Deco_Arm" .. side, pivot, CFrame.new(sx * 1.98, 0 + dy, 0),
                CFrame.new(0, bob, -raise * 0.4) * CFrame.Angles(-raise * 0.45 + math.sin(now * 1.3 + sx) * 0.05, 0, sx * (math.sin(now * 1.1) * 0.06 - raise * 0.12)))
        end
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 3.38 + dy, 0.1), CFrame.Angles(0, now * (0.8 + B.phase * 0.35), 0))
    end,
}
