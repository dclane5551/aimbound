-- BOSS LOOK v2: THE LOCKWARDEN (major boss / map guardian) -- "the vault pill" (tools/boss_look_blender2.py
-- build_lockwarden, builder bosses2). A heavy gunmetal pill with a round VAULT DOOR in its chest (a ring of bolts, a lit rim,
-- a spoked handwheel that spins up while it attacks), a giant KEY floating at its right that swings forward for KEY THRUST,
-- a padlock on a chain swinging at its left, a crown of three tesla spires with lit tips, an ice-blue seam. Hovers low.
-- (Its LOCKDOWN signature parts -- BreakPart locks, LockTile discs -- belong to the signature, which is off since 0.68.)
-- Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -2.0, Hover = 0.35,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.4, Pos = Vector3.new(0, 0, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.3, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.44, Pos = Vector3.new(0, 2.68, 0), Show = true },
    },
    Palette = { Body = C(52, 60, 74), Shell2 = C(84, 94, 110), Trim = C(196, 166, 96), Steel = C(110, 118, 132),
        Glow = C(120, 200, 255), Head = C(200, 214, 230) },
    Glow = { Glow = true },
    Emit = {},
    Animate = function(B, pivot, now, Pose, dy)
        local act = BL.Ease(B, "lkAct", (B.active > 0) and 1 or 0, 0.15)
        local dt = math.min(0.1, now - (B.lkT or now)); B.lkT = now
        B.lkWheel = (B.lkWheel or 0) + dt * (0.5 + act * 3 + ((B.locking and 2.5) or 0))
        Pose(B, "Deco_Wheel", pivot, CFrame.new(0, 0.35 + dy, -1.64), CFrame.Angles(0, 0, B.lkWheel))
        Pose(B, "Deco_Key", pivot, CFrame.new(2.1, 0 + dy, -0.3), CFrame.new(0, math.sin(now * 1.2) * 0.1, -act * 0.4) * CFrame.Angles(act * 1.25 + math.sin(now * 0.9) * 0.05, 0, 0))
        Pose(B, "Deco_ChainL", pivot, CFrame.new(-2.0, 1.45 + dy, -0.1), CFrame.Angles(math.sin(now * 1.7) * 0.22, 0, math.sin(now * 1.3) * 0.12))
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 3.5 + dy, 0), CFrame.Angles(0, now * (0.5 + B.phase * 0.3), 0))
    end,
}
