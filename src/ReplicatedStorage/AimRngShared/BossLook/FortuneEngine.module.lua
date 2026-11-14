-- BOSS LOOK v2: THE FORTUNE ENGINE (major boss / map guardian) -- "the jackpot pill" (tools/boss_look_blender2.py
-- build_fortuneengine, builder bosses2). A lacquered red pill with a gold-framed REEL WINDOW on its chest (three reels spin
-- while B.spinUntil runs and stop left to right, as before), a gold marquee arch of bulbs that chases (faster while the
-- reels spin), a lever floating at its right that yanks down when it pulls (B.leverAt), two dice tumbling at its left, a
-- gold star coin spinning over the head (the crown). Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
local BULB_A, BULB_B = C(255, 230, 140), C(255, 70, 80)
return {
    On = true,
    Bottom = -1.95, Hover = 0.3,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.4, Pos = Vector3.new(0, 0, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, 0.3, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.44, Pos = Vector3.new(0, 2.62, 0), Show = true },
    },
    Palette = { Body = C(110, 18, 36), Trim = C(204, 170, 84), Gold = C(212, 168, 56), Steel = C(222, 214, 198),
        Glow = C(255, 210, 60), Head = C(240, 214, 150) },
    Glow = { Glow = true },
    Emit = {},
    Animate = function(B, pivot, now, Pose, dy)
        local dt = math.min(0.1, now - (B.lkT or now)); B.lkT = now
        local spin = now < (B.spinUntil or 0)
        for i = 1, 3 do
            local stopAt = (B.spinUntil or 0) - (3 - i) * 0.35 -- (the reels stop left to right)
            local f = "lkReel" .. i
            B[f] = (B[f] or 0) + dt * ((now < stopAt) and 18 or 0)
            Pose(B, "Deco_Reel" .. i, pivot, CFrame.new((i - 2) * 0.84, 0.15 + dy, -1.65), CFrame.Angles(B[f], 0, 0))
        end
        local pull = math.clamp(1 - (now - (B.leverAt or -9)) / 0.6, 0, 1)
        Pose(B, "Deco_Lever", pivot, CFrame.new(1.95, 0 + dy, 0.2), CFrame.Angles(-math.rad(70) * math.sin(pull * math.pi), 0, 0))
        local step = math.floor(now * (spin and 10 or 2.5))
        if step ~= B.lkBulbStep then
            B.lkBulbStep = step
            B.lkBulbs = B.lkBulbs or B.model:FindFirstChild("Deco_Bulbs")
            if B.lkBulbs then B.lkBulbs.Color = (step % 2 == 0) and BULB_A or BULB_B end
        end
        Pose(B, "Deco_Die1", pivot, CFrame.new(-2.0, 0.75 + dy, -0.2), CFrame.new(0, math.sin(now * 1.3) * 0.15, 0) * CFrame.Angles(now * 0.7, now * 0.5, 0))
        Pose(B, "Deco_Die2", pivot, CFrame.new(-2.0, -0.55 + dy, 0.2), CFrame.new(0, math.sin(now * 1.3 + 2) * 0.15, 0) * CFrame.Angles(-now * 0.6, 0, now * 0.8))
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 3.67 + dy, 0), CFrame.Angles(0, now * (1.2 + B.phase * 0.5), 0))
    end,
}
