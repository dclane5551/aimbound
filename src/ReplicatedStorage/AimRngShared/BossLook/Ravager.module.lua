-- BOSS LOOK v2: RAVAGER (miniboss) -- "the hunter" (tools/boss_look_blender2.py build_ravager, builder bosses2). A pill
-- crouched nearly level like a predator with the head orb on its nose, a sawtooth of four triangular dorsal blades raked back
-- along its spine (lit front edges: the identity piece), four floating TALON units low at its corners that paw the ground in stride
-- (its grounded read), two sabre tusks under the head that drop open while it attacks, a bladed tail that lashes, a mane
-- of four horn-blades sweeping back behind the head. Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
local LEGS = { { "LF", -1, -1 }, { "RF", 1, -1 }, { "LB", -1, 1 }, { "RB", 1, 1 } }
return {
    On = true,
    Bottom = -2.23, Hover = 0.15,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.0, Pos = Vector3.new(0, 0, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 0.9, Pos = Vector3.new(0, 0.2, 0.2) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.36, Pos = Vector3.new(0, 1.07, -2.4), Show = true },
    },
    Palette = { Body = C(66, 26, 24), Shell = C(30, 16, 16), Trim = C(186, 168, 146), Steel = C(92, 80, 78),
        Dark = C(24, 14, 14), Glow = C(255, 96, 60), Head = C(200, 160, 150) },
    Glow = { Glow = true },
    Emit = {},
    Animate = function(B, pivot, now, Pose, dy)
        local p = B.pos
        local last = B.lkPos or p
        B.lkPos = p
        local moved = Vector3.new(p.X - last.X, 0, p.Z - last.Z).Magnitude
        B.lkStride = (B.lkStride or 0) + moved * 0.75
        local w = BL.Ease(B, "lkWalk", moved > 0.02 and 1 or 0.25, 0.15)
        for i, l in ipairs(LEGS) do
            local ph = B.lkStride + now * 1.5 * (1 - w) + ((i == 1 or i == 4) and 0 or math.pi)
            local swing = math.sin(ph) * 0.42 * w
            local lift = math.max(0, math.cos(ph)) * 0.32 * w
            Pose(B, "Deco_Leg" .. l[1], pivot, CFrame.new(l[2] * 1.65, -0.95 + dy, l[3] < 0 and -1.55 or 1.45), CFrame.new(0, lift, 0) * CFrame.Angles(swing, 0, 0))
        end
        local raise = BL.Ease(B, "lkJaw", (B.active > 0) and 1 or 0, 0.2)
        Pose(B, "Deco_Jaw", pivot, CFrame.new(0, 0.52 + dy, -2.05), CFrame.Angles(-raise * 0.45 + math.sin(now * 3) * 0.03, 0, 0))
        Pose(B, "Deco_Tail", pivot, CFrame.new(0, -0.68 + dy, 1.88), CFrame.Angles(math.sin(now * 1.7) * 0.08, math.sin(now * 2.4) * (0.3 + raise * 0.15), 0))
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 1.12 + dy, -1.95), CFrame.Angles(math.sin(now * 1.1) * 0.06, 0, math.sin(now * 0.9) * (0.1 + B.phase * 0.04)))
    end,
}
