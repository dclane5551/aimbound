-- BOSS LOOK v2: OMNISCIENCE CORE (Cyber superboss) -- "the server core" (tools/boss_look_blender.py build_cyber): a graphite
-- data pill banded with light, four curved server panels orbiting it (lit traces), a node ring round its base, a data
-- halo over its head. Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.15, Hover = 0.7,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.4, Pos = Vector3.new(0, 0, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.5, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.44, Pos = Vector3.new(0, 2.65, 0), Show = true },
    },
    Palette = { Body = C(30, 36, 46), Shell = C(48, 56, 70), Trim = C(118, 136, 158), Glow = C(60, 255, 190), Head = C(110, 176, 168) },
    Glow = { Glow = true },
    Emit = {},
    -- the panels orbit; on SYSTEM CRASH (B.crashed) they fly apart and the rings spin wild
    Animate = function(B, pivot, now, Pose, dy)
        local open = BL.Ease(B, "lkOpen", B.crashed and 1 or 0, 0.12)
        local ang = now * (0.25 + B.phase * 0.1)
        for i = 1, 4 do
            local a = math.rad(45 + (i - 1) * 90)
            local radial = Vector3.new(math.cos(a), 0, math.sin(a)) * (open * 2.2)
            Pose(B, "Deco_Panel" .. i, pivot, CFrame.new(0, dy, 0), CFrame.Angles(0, ang, 0) * CFrame.new(radial + Vector3.new(0, open * ((i % 2 == 0) and 0.6 or -0.6), 0)))
        end
        local wild = 1 + open * 4
        Pose(B, "Deco_RingA", pivot, CFrame.new(0, -1.75 + dy, 0), CFrame.Angles(0, now * 0.6 * wild, 0))
        Pose(B, "Deco_RingB", pivot, CFrame.new(0, 3.55 + dy, 0), CFrame.Angles(0, -now * 0.9 * wild, 0))
    end,
}
