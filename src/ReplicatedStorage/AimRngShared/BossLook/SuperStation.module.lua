-- BOSS LOOK v3: WARDEN-PRIME (world superboss, WorldFoes/Station) -- the last security unit: a slim graphite pill under a white armoured hood with a hazard-orange edge, a lit visor strip across its chest, an antenna, an orbit ring set with nodes turning round it, a halo ring, a stun baton floating at its side
-- (tools/boss_look_blender.py build_station_v3; v3 = the Duelist language after the owner's "Keep them in the same aesthetic
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
        Head = { Shape = "Ball", Size = Vector3.one * 1.36, Pos = Vector3.new(0, 2.6, 0), Show = true },
    },
    Palette = { Body = C(38, 42, 50), Shell = C(204, 208, 216), Orange = C(226, 100, 30), Dark = C(60, 64, 74), Glow = C(80, 220, 255) },
    Glow = { Glow = true },
    Emit = {  },
    Animate = function(B, pivot, now, Pose, dy)
        -- the orbit ring and the halo turn against each other (faster while it attacks), the baton lifts to strike
        local l = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.1)
        B.lkRing = (B.lkRing or 0) + 0.05 + l * 0.1
        Pose(B, "Deco_RingA", pivot, CFrame.new(0, 0.5 + dy, 0), CFrame.Angles(0, B.lkRing, 0))
        Pose(B, "Deco_RingB", pivot, CFrame.new(0, 3.45 + dy, 0.15), CFrame.Angles(0, -B.lkRing * 1.5, 0))
        Pose(B, "Deco_Baton", pivot, CFrame.new(1.6, 0.3 + dy, -0.35), CFrame.new(0, l * 0.4, 0) * CFrame.Angles(-l * 0.5 + math.sin(now * 1.1) * 0.04, 0, -l * 0.1))
    end,
}
