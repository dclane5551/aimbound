-- BOSS LOOK v2: TEMPEST SOVEREIGN (Storm superboss) -- "the storm angel" (tools/boss_look_blender.py build_storm): a
-- steel-blue pill floating in a storm-cloud hem, a lit diamond heart, two fans of blade feathers for wings (their tips
-- crackle), a bolt crown, a lightning-bolt tail, a floating lance. Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
return {
    On = true,
    Bottom = -3.0, Hover = 0.8,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.0, Pos = Vector3.new(0, 0.2, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 0.9, Pos = Vector3.new(0, 0.8, 0) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.36, Pos = Vector3.new(0, 2.7, 0), Show = true },
    },
    Palette = { Body = C(46, 58, 92), Shell = C(52, 56, 70), Shell2 = C(30, 34, 46), Bolt = C(255, 224, 96), Trim = C(206, 220, 238), Glow = C(150, 210, 255), Head = C(196, 222, 252) },
    Glow = { Glow = true, Bolt = true },
    Emit = { { Part = "Torso", Kind = "Spark", Color = C(190, 225, 255), Rate = 4, Size = 0.25, Speed = 3, Life = 0.9, Y = -2.4 } },
    -- wings beat slowly (spread while it attacks), the tail flickers, the lance sways, the cloud hem turns, lightning
    -- crackles between the crown, the wingtips and the heart
    Animate = function(B, pivot, now, Pose, dy)
        local l = BL.Ease(B, "lkLift", (B.active > 0) and 1 or 0, 0.08)
        for _, sx in ipairs({ -1, 1 }) do
            Pose(B, "Deco_Wing" .. (sx < 0 and "L" or "R"), pivot, CFrame.new(sx * 0.8, 1.35 + dy, 0.45),
                CFrame.Angles(0, sx * l * 0.2, sx * (math.sin(now * 1.6) * 0.14 + l * 0.18)))
        end
        Pose(B, "Deco_Spear", pivot, CFrame.new(1.75, dy, -0.55), CFrame.Angles(math.sin(now * 1.2) * 0.06 - l * 0.4, 0, math.sin(now * 0.9) * 0.05))
        Pose(B, "Deco_Cloud", pivot, CFrame.new(0, -1.75 + dy, 0), CFrame.Angles(0, now * 0.3, 0))
        if not B.lkTail then
            B.lkTail, B.lkArc = {}, {}
            for _, p in ipairs(B.model:GetDescendants()) do
                if p:IsA("BasePart") then
                    if p.Name == "Deco_Tail" then table.insert(B.lkTail, p) end
                    if string.find(p.Name, "Tip$") or p.Name == "Deco_HeartGlow" then table.insert(B.lkArc, p) end
                end
            end
        end
        for _, p in ipairs(B.lkTail) do p.Transparency = (math.random() < 0.15) and 0.6 or 0 end
        if now < (B.lkArcT or 0) or not (B.d and B.d.Fx) then return end
        B.lkArcT = now + math.max(0.1, 0.34 - B.phase * 0.07)
        local n = #B.lkArc
        if n < 2 then return end
        local a, b = B.lkArc[math.random(1, n)], B.lkArc[math.random(1, n)]
        if a == b then return end
        local p0, p1 = a.Position, b.Position
        local pts = { p0 }
        for i = 1, 3 do table.insert(pts, p0:Lerp(p1, i / 4) + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.2) end
        table.insert(pts, p1)
        for i = 1, #pts - 1 do
            local s = Instance.new("Part")
            s.Anchored = true; s.CanCollide = false; s.CanQuery = false; s.CanTouch = false; s.CastShadow = false
            s.Material = Enum.Material.Neon; s.Color = Color3.fromRGB(215, 235, 255); s.Name = "StormArc"
            s.Size = Vector3.new(0.12, 0.12, (pts[i + 1] - pts[i]).Magnitude)
            s.CFrame = CFrame.lookAt((pts[i] + pts[i + 1]) / 2, pts[i + 1])
            s.Parent = B.d.Fx
            game:GetService("Debris"):AddItem(s, 0.09)
        end
    end,
}
