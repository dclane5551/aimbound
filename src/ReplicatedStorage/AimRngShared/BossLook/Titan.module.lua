-- BOSS LOOK v2: APEX TITAN MECH (major) -- "the siege engine" (tools/boss_look_blender2.py build_titan, builder bosses2).
-- A broad gunmetal pill on four floating angular leg-struts that step in diagonal pairs as it walks (its grounded read), a
-- faceted yoke over the shoulders carrying two missile banks (their tube mouths pulse with the phase), two floating six-
-- barrel rotary cannons that spin up while it attacks, a reactor ring turning on its chest, a targeting ring with antenna
-- tines tilted over the head. Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
local CORNERS = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
return {
    On = true,
    Bottom = -3.1, Hover = 0.05,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 3.0, Pos = Vector3.new(0, 0, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.2, Pos = Vector3.new(0, 0.2, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.5, Pos = Vector3.new(0, 2.72, 0), Show = true },
    },
    Palette = { Body = C(40, 42, 48), Shell = C(26, 28, 32), Shell2 = C(50, 52, 60), Trim = C(170, 140, 80),
        Steel = C(84, 86, 96), Dark = C(22, 22, 26), Glow = C(255, 60, 60), Head = C(200, 190, 190) },
    Glow = { Glow = true },
    Emit = {},
    Animate = function(B, pivot, now, Pose, dy)
        local p = B.pos
        local last = B.lkPos or p
        B.lkPos = p
        local moved = Vector3.new(p.X - last.X, 0, p.Z - last.Z).Magnitude
        B.lkStride = (B.lkStride or 0) + moved * 0.55
        local w = BL.Ease(B, "lkWalk", moved > 0.02 and 1 or 0, 0.12)
        for i, c in ipairs(CORNERS) do
            local ph = B.lkStride + ((i == 1 or i == 4) and 0 or math.pi)
            local lift = math.max(0, math.sin(ph)) * 0.4 * w + math.sin(now * 1.3 + i) * 0.02
            Pose(B, "Deco_Leg" .. i, pivot, CFrame.new(c[1] * 2.25, -0.55 + dy, c[2] * 1.35),
                CFrame.new(0, lift, 0) * CFrame.Angles(math.cos(ph) * 0.12 * w, 0, -c[1] * lift * 0.25))
        end
        local dt = math.min(0.1, now - (B.lkT or now)); B.lkT = now
        B.lkSpin = (B.lkSpin or 0) + dt * ((B.active > 0) and (10 + B.phase * 4) or 1.2)
        for _, sx in ipairs({ -1, 1 }) do
            Pose(B, "Deco_Barrel" .. (sx < 0 and "L" or "R"), pivot, CFrame.new(sx * 2.45, 0.1 + dy, -0.55), CFrame.Angles(0, 0, B.lkSpin * sx))
        end
        Pose(B, "Deco_Reactor", pivot, CFrame.new(0, 0.2 + dy, -1.65), CFrame.Angles(0, 0, now * (1.2 + B.phase * 0.8)))
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 3.57 + dy, 0.15), CFrame.Angles(0, now * 0.6, 0))
        B.lkPod = B.lkPod or B.model:FindFirstChild("Deco_GlowPod")
        if B.lkPod then B.lkPod.Transparency = 0.45 * (0.5 - 0.5 * math.sin(now * (3 + B.phase * 2))) end
    end,
}
