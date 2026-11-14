-- BOSS LOOK v2: FORGEHEART (trial boss / map guardian) -- "the furnace pill" (tools/boss_look_blender2.py
-- build_forgeheart, builder bosses2). A squat slag pill under a heavy hexagonal armour hood, a grilled furnace mouth
-- glowing on its chest, two chimneys behind that flame up from phase 2 (ForgeFlame emitters, as before), a forge hammer
-- floating at its right that rears back for HAMMERFALL (B.raise) and slams down, a molten crown of drips over the head.
-- THE BRANDS (3 white-hot "Brand" plates + "BrandRim", attr BrandIndex 1-3, built here because the old dress made them)
-- crawl round the lower shell, bobbing, faster each phase -- the old kit Animate's job, which BossLook.Animate replaces.
-- Plug-in API: the header of AimRngShared/BossLook.
local BL = require(script.Parent)
local C = BL.C
local HOT, MOLTEN = C(255, 232, 180), C(255, 120, 30)
local SPEED = { 0.45, 0.6, 0.8 }
return {
    On = true,
    Bottom = -1.8, Hover = 0.5,
    Hit = {
        Torso = { Shape = "Ball", Size = Vector3.one * 2.6, Pos = Vector3.new(0, 0, 0) },
        Core = { Shape = "Ball", Size = Vector3.one * 1.0, Pos = Vector3.new(0, -0.25, -0.9) },
        Head = { Shape = "Ball", Size = Vector3.one * 1.4, Pos = Vector3.new(0, 2.42, -0.1), Show = true },
    },
    Palette = { Body = C(46, 38, 36), Shell = C(30, 26, 26), Dark = C(20, 18, 18), Steel = C(70, 64, 62),
        Glow = C(255, 150, 50), Head = C(120, 104, 98) },
    Glow = { Glow = true },
    Emit = {},
    Build = function(model, look, spec)
        for i = 1, 3 do
            local brand = Instance.new("Part")
            brand.Name = "Brand"
            brand.Size = Vector3.new(0.9, 0.9, 0.3)
            brand.Color, brand.Material = HOT, BL.NEON
            brand.Anchored, brand.CanCollide, brand.CanTouch, brand.CanQuery, brand.CastShadow = true, false, false, true, false
            brand.CFrame = look * CFrame.new(0, -0.5, -1.6)
            brand:SetAttribute("BrandIndex", i)
            brand:SetAttribute("Glow", true)
            brand:SetAttribute("KeepNeon", true)
            brand.Parent = model
            local rim = brand:Clone()
            rim.Name = "BrandRim"
            rim.Size = Vector3.new(1.25, 1.25, 0.12)
            rim.Color, rim.Transparency, rim.CanQuery = MOLTEN, 0.25, false
            rim.Parent = model
        end
        local host = model:FindFirstChild("BL_ChimneyGlow")
        if host then
            for _, sx in ipairs({ -1, 1 }) do
                local pe = BL.Emit(host, { Kind = "Fire", Color = C(255, 130, 40), Rate = 0, Size = 0.7, Speed = 3, Life = 0.6 }, look)
                pe.Name = "ForgeFlame"
                pe.Parent.WorldPosition = (look * CFrame.new(0.81 * sx, 2.45, 1.4)).Position
            end
        end
    end,
    Animate = function(B, pivot, now, Pose, dy)
        if not B.lkBrands then
            B.lkBrands, B.lkRims = {}, {}
            for _, p in ipairs(B.model:GetChildren()) do
                local i = p:GetAttribute("BrandIndex")
                if i then
                    if p.Name == "Brand" then B.lkBrands[i] = p else B.lkRims[i] = p end
                end
            end
        end
        local dt = math.min(0.1, now - (B.lkT or now)); B.lkT = now
        B.lkA = (B.lkA or 0) + (SPEED[B.phase] or 0.6) * dt
        local sk = B.poseScale or B.model:GetScale()
        for i = 1, 3 do
            local a = B.lkA + (i - 1) * math.pi * 2 / 3
            local n = Vector3.new(math.sin(a), 0, -math.cos(a))
            local off = n * 1.47 + Vector3.new(0, -0.45 + math.sin(now * 0.8 + i * 2.1) * 0.35 + dy, 0)
            local cf = pivot * CFrame.lookAt(off * sk, (off + n) * sk)
            if B.lkBrands[i] then B.lkBrands[i].CFrame = cf end
            if B.lkRims[i] then B.lkRims[i].CFrame = cf * CFrame.new(0, 0, 0.1) end
        end
        -- the hammer: rears back over the shoulder for HAMMERFALL, slams down on the impact
        local up = (os.clock() < (B.raise or 0)) and 1 or 0
        B.lkHam = (B.lkHam or 0) + (up - (B.lkHam or 0)) * ((up == 1) and 0.1 or 0.5)
        Pose(B, "Deco_Hammer", pivot, CFrame.new(2.25, -0.6 + dy, -0.2),
            CFrame.new(0, math.sin(now * 1.4) * 0.08, 0) * CFrame.Angles(math.rad(80) * B.lkHam, 0, math.sin(now * 1.1) * 0.04))
        Pose(B, "Deco_Crown", pivot, CFrame.new(0, 3.27 + dy, 0), CFrame.Angles(0, now * (0.4 + B.phase * 0.2), 0))
        -- the chimneys flame up from phase 2
        if B.lkFlame ~= B.phase then
            B.lkFlame = B.phase
            for _, e in ipairs(B.model:GetDescendants()) do
                if e:IsA("ParticleEmitter") and e.Name == "ForgeFlame" then e.Rate = (B.phase >= 3 and 16) or (B.phase >= 2 and 8) or 0 end
            end
        end
    end,
}
