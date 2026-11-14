-- BOSS LOOK v2: THE BROODMOTHER (major boss / map guardian) -- "the brood queen" (tools/boss_look_blender2.py
-- build_broodmother, builder bosses2). An orb carapace low to the ground on EIGHT floating sickle legs (four a side, high
-- knees, they step in a ripple that quickens with its frenzy: its grounded read), the head orb at the front, two curved
-- fangs that snap under it, a ridged sac of glowing eggs on its back (the identity piece), a web disc behind the head.
-- (Its CLUTCH eggs are ShieldOrb parts made by the signature, off since 0.68; BURROW / CEILING RAIN move it with yOff.)
-- Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -1.6, Hover = 0.05,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.6, Pos = Vector3.new(0, 0, 0.2) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.2, 0.6) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.4, Pos = Vector3.new(0, 0.55, -1.85), Show = true },
    },
    Palette = { Body = C(58, 30, 26), Shell = C(34, 18, 16), Dark = C(26, 16, 14), Trim = C(196, 176, 146),
        Glow = C(255, 120, 60), Head = C(150, 110, 96) },
    Glow = { Glow = true },
    Emit = {},
    Animate = function(B, pivot, now, Pose, dy)
        local dt = math.min(0.1, now - (B.lkT or now)); B.lkT = now
        local p = B.pos
        local last = B.lkPos or p
        B.lkPos = p
        local moved = Vector3.new(p.X - last.X, 0, p.Z - last.Z).Magnitude / math.max(dt, 0.01)
        local frenzy = 1 + 0.25 * (B.frenzy or 0)
        B.lkWalk = (B.lkWalk or 0) + dt * (1.2 + math.clamp(moved / 3, 0, 5)) * frenzy
        local amt = 0.35 + 0.65 * math.clamp(moved / 8, 0, 1)
        for i = 1, 4 do
            local z = -1.1 + (i - 1) * 0.85
            for _, sx in ipairs({ -1, 1 }) do
                local ph = B.lkWalk * 3 + ((i + (sx > 0 and 1 or 0)) % 2) * math.pi
                local lift = math.max(0, math.sin(ph)) * math.rad(20) * amt
                local swing = math.cos(ph) * math.rad(14) * amt
                Pose(B, "Deco_Leg" .. i .. (sx < 0 and "L" or "R"), pivot, CFrame.new(sx * 1.2, 0.35 + dy, z), CFrame.Angles(0, swing * sx, lift * sx))
            end
        end
        local snap = math.abs(math.sin(now * 4 * frenzy)) * 0.3
        Pose(B, "Deco_MandibleL", pivot, CFrame.new(-0.32, 0.0 + dy, -1.7), CFrame.Angles(0, -snap, 0))
        Pose(B, "Deco_MandibleR", pivot, CFrame.new(0.32, 0.0 + dy, -1.7), CFrame.Angles(0, snap, 0))
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 0.9 + dy, -1.2), CFrame.Angles(0, 0, now * 0.4))
    end,
}
