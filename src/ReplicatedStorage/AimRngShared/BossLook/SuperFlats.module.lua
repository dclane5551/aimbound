-- BOSS LOOK v2: HIGHWAY KING (Neon Flats superboss) -- "the road baron" (tools/boss_look_blender2.py build_flats2, rebuilt
-- by builder bosses2 after the owner: the hot-rod car read as a toy -> "same aesthetic of duelist phantom etc, not toys"). A
-- slim gunmetal pill in a long open RACING DUSTER (high collar, chrome piping on every edge, split tails that stream back
-- with its speed), two chrome EXHAUST PIPES rising behind the shoulders like swept horns and breathing fire, twin HEADLIGHT
-- slits on the chest, two floating chrome RIM-BLADES at its sides that spin with its speed (faster while it attacks), a
-- floating STEERING-WHEEL crown over the head that turns with its turns, a teal seam. No wheels on the floor: it floats
-- like the rest of the family. (NITRO LAPS is a signature, off since 0.68; nothing in BossAI reads its parts.)
-- Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
local RIM_A = 0.7 -- (the rims face 40 deg toward the player: their spin axis)
return {
    On = true,
    Bottom = -3.05, Hover = 0.5,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 1.6, Pos = Vector3.new(0, 0.3, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 0.8, Pos = Vector3.new(0, 0.6, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.32, Pos = Vector3.new(0, 2.6, 0), Show = true },
    },
    Palette = { Body = C(34, 40, 46), Shell = C(22, 22, 26), Trim = C(170, 174, 184), Chrome = C(140, 146, 156),
        Lamp = C(255, 236, 190), Glow = C(40, 220, 210) },
    Glow = { Glow = true, Lamp = true },
    Emit = {},
    Build = function(model, look, spec)
        local host = model:FindFirstChild("BL_PipeGlow")
        if not host then return end
        for _, sx in ipairs({ -1, 1 }) do
            local pe = BL.Emit(host, { Kind = "Fire", Color = C(255, 140, 50), Rate = 3, Size = 0.5, Speed = 3, Life = 0.5 }, look)
            pe.Parent.WorldPosition = (look * CFrame.new(1.17 * sx, 3.38, 1.45)).Position
        end
    end,
    Animate = function(B, pivot, now, Pose, dy)
        local dt = math.min(0.1, now - (B.lkT or now)); B.lkT = now
        local p = B.pos
        local last = B.lkPos or p
        B.lkPos = p
        local speed = Vector3.new(p.X - last.X, 0, p.Z - last.Z).Magnitude / math.max(dt, 0.01)
        local act = BL.Ease(B, "lkAct", (B.active > 0) and 1 or 0, 0.15)
        B.lkSpin = (B.lkSpin or 0) + dt * (2 + speed * 0.6 + act * 10)
        for _, sx in ipairs({ -1, 1 }) do
            local side = sx < 0 and "L" or "R"
            local axis = Vector3.new(math.cos(RIM_A * sx), 0, -math.sin(RIM_A * sx)) -- (the rim normal: faces out + forward, measured in play)
            Pose(B, "Deco_Wheel" .. side, pivot, CFrame.new(sx * 1.8, -0.3 + dy, -0.35),
                CFrame.new(0, math.sin(now * 1.5 + sx) * 0.12, 0) * CFrame.fromAxisAngle(axis, B.lkSpin * sx))
        end
        -- the steering wheel turns with its turns (yaw rate), the duster streams back with its speed
        local look = pivot.LookVector
        local lastLook = B.lkLook or look
        B.lkLook = look
        local yaw = math.atan2(lastLook:Cross(look).Y, lastLook:Dot(look)) / math.max(dt, 0.01)
        local steer = BL.Ease(B, "lkSteer", math.clamp(yaw * 0.6, -1.2, 1.2), 0.12)
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 3.45 + dy, 0.25), CFrame.fromAxisAngle(Vector3.new(0, 0.89, 0.45), -steer + math.sin(now * 0.8) * 0.08))
        local stream = BL.Ease(B, "lkStream", math.clamp(speed / 20, 0, 1), 0.1)
        Pose(B, "Deco_Coat", pivot, CFrame.new(0, 1.6 + dy, 0), CFrame.Angles(math.sin(now * 1.6) * 0.03 - stream * 0.14, math.sin(now * 0.8) * 0.04, math.sin(now * 1.2) * 0.025))
    end,
}
