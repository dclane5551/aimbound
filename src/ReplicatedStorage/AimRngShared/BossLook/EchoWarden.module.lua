-- BOSS LOOK v2: ECHO WARDEN (trial boss / map guardian) -- "the mirror" (tools/boss_look_blender2.py build_echowarden,
-- builder bosses2). v2 after main's review (v1 read as the Archon recoloured): a FACETED pill cut like a mirror-gem (flat
-- eight-sided facets, no wings), a ring of eight mirror PANES orbiting its waist, its AFTERIMAGE -- a see-through faceted
-- twin standing offset behind it that lags its moves, drifting back into place -- and a MIRROR CROWN of upright broken
-- panes on a lit ring over the head, a violet seam. Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.05, Hover = 0.8,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 1.7, Pos = Vector3.new(0, 0.3, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 0.8, Pos = Vector3.new(0, 0.7, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.28, Pos = Vector3.new(0, 2.78, 0), Show = true },
    },
    Palette = { Body = C(40, 28, 62), Shell = C(24, 16, 38), Trim = C(180, 172, 210), Ghost = C(120, 84, 190),
        Glow = C(190, 110, 255), Head = C(214, 196, 244) },
    Glow = { Glow = true },
    Emit = {},
    Build = function(model, look, spec)
        for _, p in ipairs(model:GetChildren()) do
            if p:IsA("BasePart") and p:GetAttribute("Role") == "Ghost" then p.Transparency = 0.6 end
        end
    end,
    Animate = function(B, pivot, now, Pose, dy)
        Pose(B, "Deco_Shard", pivot, CFrame.new(0, 0.3 + dy, 0), CFrame.Angles(0, now * (0.7 + B.phase * 0.25), 0))
        -- the afterimage lags: its offset follows the boss's own velocity (in boss space), then drifts back
        local v = B.vel or Vector3.zero
        local lv = pivot:VectorToObjectSpace(v)
        B.lkLagX = BL.Ease(B, "lkLagX", math.clamp(-lv.X * 0.08, -1.2, 1.2), 0.08)
        B.lkLagZ = BL.Ease(B, "lkLagZ", math.clamp(-lv.Z * 0.08, -1.2, 1.2), 0.08)
        Pose(B, "Deco_Ghost", pivot, CFrame.new(0.95, -0.15 + dy, 1.35), CFrame.new(B.lkLagX, math.sin(now * 1.6) * 0.15, B.lkLagZ))
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 3.5 + dy, 0), CFrame.Angles(0, -now * (0.4 + B.phase * 0.2), 0))
    end,
}
