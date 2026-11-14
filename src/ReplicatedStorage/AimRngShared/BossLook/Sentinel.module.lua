-- BOSS LOOK v2: BULWARK SENTINEL (miniboss) -- "the bastion" (tools/boss_look_blender2.py build_sentinel, builder
-- bosses2). An armoured orb held in four faceted buttress plates at its diagonals that flare out under the head (front,
-- sides, back and every diagonal stay open: the head shows), lit piping on every buttress edge, the CORE as a cyan lens in a bezel on its chest (SentinelVent swells it
-- x1.8 and turns it gold: it bulges out of the bezel), four crystals bobbing high over the diagonals, a segmented base ring
-- and an emitter crown turning, three drones orbiting. ShieldPanel (its old light + slab) is tucked away inside; nothing
-- reads it in play (the "Shield" signatures are off). Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
local KIT = C(90, 200, 255) -- (= BossAI KITS.Sentinel.Color: SentinelVent resets the core to it)
return {
    On = true,
    Bottom = -2.26, Hover = 0.5,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 3.0, Pos = Vector3.new(0, 0, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.05, -1.5) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.4, Pos = Vector3.new(0, 2.32, 0), Show = true },
        ShieldPanel = { Shape = "Block", Size = Vector3.new(1, 1, 0.2), Pos = Vector3.new(0, 0, 0) },
    },
    Palette = { Body = C(40, 56, 76), Shell = C(26, 34, 48), Trim = C(196, 220, 236), Steel = C(120, 140, 160),
        Dark = C(18, 22, 30), Glow = KIT, Head = C(190, 214, 236) },
    Glow = { Glow = true },
    Emit = {},
    Build = function(model, look, spec)
        local core = model:FindFirstChild("Core")
        if core then
            core.Transparency = 0
            core.Material = BL.NEON
            core.Color = KIT
            core:SetAttribute("KeepNeon", true)
        end
    end,
    Animate = function(B, pivot, now, Pose, dy)
        Pose(B, "Deco_BaseRing", pivot, CFrame.new(0, -2.15 + dy, 0), CFrame.Angles(0, now * 0.5, 0))
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 3.3 + dy, 0), CFrame.Angles(0, -now * (1 + B.phase * 0.6), 0))
        Pose(B, "Deco_Orbit", pivot, CFrame.new(0, 0.7 + dy, 0), CFrame.Angles(0, now * (0.9 + B.phase * 0.4), 0))
        for i = 1, 4 do
            local a = math.pi / 4 + (i - 1) * math.pi / 2
            Pose(B, "Deco_Crystal" .. i, pivot, CFrame.new(math.cos(a) * 1.75, 3.5 + dy, math.sin(a) * 1.75),
                CFrame.new(0, math.sin(now * 2 + i * 1.6) * 0.22, 0) * CFrame.Angles(0, now * 1.2, 0))
        end
    end,
}
