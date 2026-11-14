-- BOSS LOOK v2: GOLIATH ENFORCER (miniboss) -- "the siege pill" (tools/boss_look_blender2.py build_goliath, builder
-- bosses2). A broad charcoal pill hovering low between two floating tread pods (its grounded read: the road wheels roll as
-- it drives), a faceted octagonal hull collar with hazard piping, a floating V-plow RAM in front of its lower body that
-- punches out on the CHARGE (B.dashing), two raked exhaust stacks breathing fire, a cog crown turning behind the head.
-- Gameplay parts: Torso / Core inside the vessel, Head = the one weak spot, BarrierShield (only the retired GoliathBulwark
-- read it) tucked away inside. Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
local WHEEL_Z = { -0.95, 0, 0.95 }
return {
    On = true,
    Bottom = -2.68, Hover = 0.12,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.8, Pos = Vector3.new(0, 0, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.3, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.44, Pos = Vector3.new(0, 2.5, 0), Show = true },
        BarrierShield = { Shape = "Block", Size = Vector3.new(1, 1, 0.2), Pos = Vector3.new(0, 0, 0) },
    },
    Palette = { Body = C(40, 34, 34), Shell = C(28, 24, 24), Shell2 = C(50, 42, 38), Trim = C(196, 128, 46),
        Steel = C(96, 92, 90), Dark = C(24, 22, 22), Glow = C(255, 140, 30), Head = C(190, 176, 160) },
    Glow = { Glow = true },
    Emit = {},
    Build = function(model, look, spec)
        -- fire from both stack mouths (two slow emitters)
        local host = model:FindFirstChild("BL_StackGlow")
        if not host then return end
        for _, sx in ipairs({ -1, 1 }) do
            local pe = BL.Emit(host, { Kind = "Fire", Color = C(255, 130, 40), Rate = 3, Size = 0.6, Speed = 2.5, Life = 0.7 }, look)
            pe.Parent.WorldPosition = (look * CFrame.new(0.92 * sx, 2.42, 1.85)).Position
        end
    end,
    Animate = function(B, pivot, now, Pose, dy)
        local p = B.pos
        local last = B.lkPos or p
        B.lkPos = p
        local moved = Vector3.new(p.X - last.X, 0, p.Z - last.Z).Magnitude
        B.lkRoll = (B.lkRoll or 0) + moved / 0.5
        for _, sx in ipairs({ -1, 1 }) do
            local side = sx < 0 and "L" or "R"
            for k, z in ipairs(WHEEL_Z) do
                Pose(B, "Deco_Wheel" .. side .. k, pivot, CFrame.new(sx * 2.65, -1.9 + dy, z), CFrame.Angles(-B.lkRoll, 0, 0))
            end
        end
        -- the ram: a slow idle bob, punched forward on a charge
        local out = BL.Ease(B, "lkRam", B.dashing and 1 or 0, 0.35)
        Pose(B, "Deco_Ram", pivot, CFrame.new(0, -1.3 + dy, -2.2), CFrame.new(0, math.sin(now * 2.2) * 0.05, -1.0 * out) * CFrame.Angles(-0.12 * out, 0, 0))
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 2.5 + dy, 0.55), CFrame.Angles(0, 0, now * (0.5 + B.phase * 0.35)))
    end,
}
