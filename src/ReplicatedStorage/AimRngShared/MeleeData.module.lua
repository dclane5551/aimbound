--!nocheck
-- ============================================================================================
-- MELEE SYSTEM (shared data). A melee is a full weapon slot: take it out ([3] / [Q] swaps back), swing it
-- (left click = light attack, alternating combo; right click = heavy attack), inspect it ([T]), or quick-swing
-- it from your gun ([V]). Stats come from ItemData.MeleeWeapons (damage, AttackRate, Range, crits).
--
-- Visuals: every melee is drawn by the shared arms rig (ViewmodelRig) like a gun: MeleeData.Rigs[RigId] is a
-- WeaponRigs-style def (Build() makes the model, Points.GripR is the hand, Anims drive it). Until real meshes
-- exist each melee has a PLACEHOLDER model built from parts; a real model can replace it later by setting
-- Asset = "<model in WeaponAssets>" on its rig (parts must keep the zone names below).
--
-- COSMETICS: every melee model is split into ZONES (Blade, Edge, Handle, Guard, Pommel, Accent), so one skin
-- works on every melee, present and future. MeleeData.Skins = the skin catalog (looks per zone + rarity +
-- how it's earned). Player state: OwnedMeleeSkins = { [skinId] = true }, MeleeSkinFor = { [meleeId] = skinId }.
-- ============================================================================================
local MeleeData = {}
local SkinFX = require(script.Parent:WaitForChild("SkinFX"))
local Inspects = require(script.Parent:WaitForChild("Inspects")) -- (Update 5) key helpers + skin inspect overrides

local V, CF, R = Vector3.new, CFrame.new, math.rad
local function ANG(x, y, z) return CFrame.Angles(x, y, z) end

MeleeData.ZONES = { "Blade", "Edge", "Handle", "Guard", "Pommel", "Accent" }

-- Attack tuning (damage multipliers on the melee's base damage; Interval = seconds per swing at AttackRate 1)
MeleeData.Attacks = {
    Light = { Mult = 1.0, Interval = 0.75, HitAt = 0.13, Arc = 0.3, RangeBonus = 0 },
    Heavy = { Mult = 2.2, Interval = 1.5, HitAt = 0.40, Arc = 0.0, RangeBonus = 2 },
    Quick = { Mult = 1.0, Interval = 0.6, HitAt = 0.10, Arc = 0.3, RangeBonus = 0 }, -- [V] from the gun
}
MeleeData.MOVE_BONUS = 0.12 -- melee out: +12% move speed (plus the melee's own MovementSpeedBonus)

-- ==================== placeholder models ====================
-- Model space = gun space: +Y runs up the handle toward the blade, +X is the cutting edge / forward, Z is
-- sideways. The hand (GripR) sits at the origin.
local function Part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = mat or Enum.Material.SmoothPlastic
    if shape then p.Shape = shape end
    p.Anchored = true
    p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
    p.Parent = model
    return p
end
local CYL_Y = ANG(0, 0, R(90)) -- cylinders run along X; this turns them to run up Y

local STEEL, DARK, WOOD, TAPE = Color3.fromRGB(190, 195, 205), Color3.fromRGB(32, 34, 40), Color3.fromRGB(110, 76, 46), Color3.fromRGB(28, 28, 30)
local METAL, FABRIC, FOIL = Enum.Material.Metal, Enum.Material.Fabric, Enum.Material.Foil

-- Each builder returns parts named after their zone (several parts may share a zone: Blade2 -> "Blade").
local BUILDERS = {}
BUILDERS.Knife = function(m, o)
    local bl = o.BladeLen or 0.75
    local tilt = ANG(0, 0, R(o.Curve or 0))
    Part(m, "Grip", V(0.13, 0.46, 0.15), CF(0, 0, 0), o.Handle or DARK, Enum.Material.Plastic) -- handle (zone Handle)
    Part(m, "Guard", V(0.30, 0.05, 0.14), CF(0.03, 0.255, 0), DARK, METAL)
    Part(m, "Pommel", V(0.15, 0.06, 0.16), CF(0, -0.255, 0), DARK, METAL)
    Part(m, "Blade", V(0.17, bl, 0.03), CF(0.01, 0.28, 0) * tilt * CF(0, bl / 2, 0), o.Blade or STEEL, METAL)
    Part(m, "Edge", V(0.035, bl * 0.92, 0.036), CF(0.01, 0.28, 0) * tilt * CF(0.09, bl * 0.46, 0), Color3.fromRGB(230, 235, 245), METAL)
    Part(m, "Blade2", V(0.12, 0.14, 0.03), CF(0.01, 0.28, 0) * tilt * CF(0.03, bl + 0.05, 0) * ANG(0, 0, R(-35)), o.Blade or STEEL, METAL) -- tip
    Part(m, "Accent", V(0.135, 0.06, 0.155), CF(0, 0.12, 0), o.Accent or Color3.fromRGB(180, 140, 60), METAL)
end
-- COMBAT KNIFE (0.97, owner: "Remove the crowbar as the default melee, and make it a simple knife, similar to counter
-- strikes"): everyone's default melee. A plain tactical drop-point: gunmetal blade with a darker fuller, a bright steel
-- edge, a black polymer handle with finger ribs, a short guard. Built flat in X / Y (blade up +Y, edge toward +X) with the
-- shared BladeKit so the Knife class holds / swings / inspect fit it.
BUILDERS.CombatKnife = function(m, o)
    -- (0.97 UPDATE 3, owner: the melees "no longer really match with the guns ... more blocky / cartoonish ... the edge looks
    -- kind of silly and too thick"): the default knife is a real modelled tactical knife (WeaponAssets.MeleeModels.CombatKnife,
    -- in melee space -- blade up +Y, edge +X, flat faces +-Z, handle centred on the origin). (Update 5, owner: "The default
    -- knife is kind of toyish looking"): KNIFE v5 = our own design (art/weapons/CombatKnife_v5.blend, tools/knife_v5_import.luau):
    -- a two-tone drop point -- dark coated flats, a bright saber-grind bevel with a plunge-line ricasso, a swedge, spine
    -- jimping -- a slim guard, textured G10 scales over a burnt-orange liner, steel pins, a lanyard pommel; parts named by
    -- zone (Blade / Blade2 / Edge / Guard / Grip / Grip2 / Accent / Pommel / Pommel2 / Pins). The Sketchfab one is kept as
    -- MeleeModels.CombatKnife_old. The part build below stays as the fallback.
    local wa = script.Parent:FindFirstChild("WeaponAssets")
    local src = wa and wa:FindFirstChild("MeleeModels") and wa.MeleeModels:FindFirstChild("CombatKnife")
    if src then
        for _, p in ipairs(src:GetChildren()) do
            if p:IsA("BasePart") then
                local c = p:Clone()
                c.Anchored = true
                c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = false, false, false, false
                c.Parent = m
            end
        end
        return
    end
    local BK = SkinFX.BladeKit
    local BLADE, EDGE, FULLER = o.Blade or Color3.fromRGB(78, 82, 92), Color3.fromRGB(205, 210, 220), Color3.fromRGB(44, 46, 54)
    local POLY, RIB = o.Handle or Color3.fromRGB(30, 31, 36), Color3.fromRGB(18, 18, 22)
    Part(m, "Grip", V(0.095, 0.43, 0.08), CF(0, 0.015, 0), POLY, Enum.Material.SmoothPlastic)
    for k = 0, 3 do Part(m, "Accent", V(0.1, 0.022, 0.084), CF(0.002, -0.14 + k * 0.075, 0), RIB, Enum.Material.SmoothPlastic) end -- finger ribs
    Part(m, "Guard", V(0.17, 0.04, 0.09), CF(0.012, 0.248, 0), Color3.fromRGB(46, 48, 56), METAL)
    Part(m, "Pommel", V(0.105, 0.055, 0.088), CF(0, -0.225, 0) * ANG(0, 0, R(8)), Color3.fromRGB(46, 48, 56), METAL)
    local st = { { -0.045, 0.268, 0.05, 0.268 }, { -0.047, 0.5, 0.058, 0.5 }, { -0.047, 0.74, 0.058, 0.73 }, { -0.044, 0.87, 0.051, 0.85 },
                 { -0.03, 0.96, 0.032, 0.945 }, { -0.012, 1.03, -0.012, 1.03 } }
    BK.Blade(m, { Stations = st, Thick = 0.026, Color = BLADE, Material = METAL, Reflectance = 0.08, EdgeFrac = 0.28, EdgeColor = EDGE,
        EdgeMaterial = METAL, Inlays = { { A = 0.16, B = 0.3, Color = FULLER, Glow = false, From = 1, To = 4, Name = "Fuller" } } })
end
BUILDERS.Crowbar = function(m, o)
    Part(m, "Grip", V(0.45, 0.11, 0.11), CF(0, 0, 0) * CYL_Y, TAPE, FABRIC, Enum.PartType.Cylinder)
    Part(m, "Blade", V(1.15, 0.08, 0.08), CF(0, 0.75, 0) * CYL_Y, Color3.fromRGB(150, 40, 40), METAL, Enum.PartType.Cylinder)
    Part(m, "Edge", V(0.28, 0.07, 0.07), CF(0.10, 1.36, 0) * ANG(0, 0, R(-40)), Color3.fromRGB(160, 160, 165), METAL)
    Part(m, "Pommel", V(0.18, 0.06, 0.08), CF(0.05, -0.26, 0) * ANG(0, 0, R(30)), Color3.fromRGB(160, 160, 165), METAL)
end
BUILDERS.Bat = function(m, o)
    Part(m, "Grip", V(0.8, 0.11, 0.11), CF(0, -0.1, 0) * CYL_Y, TAPE, FABRIC, Enum.PartType.Cylinder) -- room for two hands
    Part(m, "Pommel", V(0.05, 0.17, 0.17), CF(0, -0.52, 0) * CYL_Y, Color3.fromRGB(60, 60, 64), METAL, Enum.PartType.Cylinder)
    Part(m, "Blade", V(0.55, 0.15, 0.15), CF(0, 0.52, 0) * CYL_Y, Color3.fromRGB(205, 210, 215), METAL, Enum.PartType.Cylinder)
    Part(m, "Blade2", V(0.75, 0.22, 0.22), CF(0, 1.15, 0) * CYL_Y, Color3.fromRGB(205, 210, 215), METAL, Enum.PartType.Cylinder)
    Part(m, "Accent", V(0.06, 0.23, 0.23), CF(0, 0.82, 0) * CYL_Y, Color3.fromRGB(40, 90, 200), METAL, Enum.PartType.Cylinder)
end
BUILDERS.Axe = function(m, o)
    Part(m, "Grip", V(1.25, 0.11, 0.11), CF(0, 0.35, 0) * CYL_Y, WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
    Part(m, "Pommel", V(0.12, 0.13, 0.13), CF(0, -0.27, 0), DARK, METAL)
    Part(m, "Blade", V(0.38, 0.22, 0.05), CF(0.15, 0.9, 0), DARK, METAL)
    Part(m, "Edge", V(0.05, 0.30, 0.055), CF(0.35, 0.9, 0), STEEL, METAL)
    Part(m, "Guard", V(0.18, 0.12, 0.07), CF(-0.15, 0.9, 0), DARK, METAL) -- spike
    Part(m, "Accent", V(0.13, 0.25, 0.13), CF(0, 0.1, 0), Color3.fromRGB(60, 70, 50), FABRIC) -- paracord wrap
end
BUILDERS.Extinguisher = function(m, o)
    Part(m, "Grip", V(0.30, 0.08, 0.10), CF(0, 0, 0), DARK, METAL) -- carry handle
    Part(m, "Guard", V(0.12, 0.18, 0.12), CF(0, 0.12, 0), DARK, METAL)
    Part(m, "Blade", V(1.0, 0.42, 0.42), CF(0, 0.72, 0) * CYL_Y, Color3.fromRGB(200, 30, 30), METAL, Enum.PartType.Cylinder)
    Part(m, "Pommel", V(0.20, 0.42, 0.42), CF(0, 1.30, 0), Color3.fromRGB(200, 30, 30), METAL, Enum.PartType.Ball)
    Part(m, "Accent", V(0.30, 0.43, 0.43), CF(0, 0.6, 0) * CYL_Y, Color3.fromRGB(230, 230, 230), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder) -- label
    Part(m, "Edge", V(0.32, 0.05, 0.05), CF(0.1, 0.2, 0) * ANG(0, 0, R(-60)), TAPE, FABRIC) -- hose
end
BUILDERS.Shield = function(m, o)
    Part(m, "Grip", V(0.10, 0.30, 0.10), CF(0, 0, 0), DARK, METAL) -- handle behind the shield
    Part(m, "Blade", V(0.08, 1.9, 1.15), CF(0.18, 0.25, 0.05), Color3.fromRGB(30, 34, 44), METAL)
    Part(m, "Edge", V(0.10, 1.95, 0.05), CF(0.18, 0.25, 0.63), Color3.fromRGB(80, 85, 95), METAL)
    Part(m, "Guard", V(0.09, 0.30, 0.55), CF(0.23, 0.75, 0.05), Color3.fromRGB(120, 180, 220), Enum.Material.Glass) -- visor window
    Part(m, "Accent", V(0.09, 0.18, 0.8), CF(0.23, -0.25, 0.05), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic) -- POLICE strip
end

-- SERAPHIM SPEAR (the heavenly melee, 2026-10-02 overnight): pearl shaft with gold rings, a long curved gold-edged
-- blade, feathered wings at the blade's base that spread on inspect, a halo ring and a glowing star.
BUILDERS.Spear = function(m, o)
    local PEARL, GOLD, PALE = SkinFX.Colors.Pearl, SkinFX.Colors.Gold, SkinFX.Colors.PaleGold
    local top = 2.05 -- where the head starts (up the shaft, +Y)
    Part(m, "Grip", V(2.95, 0.075, 0.075), CF(0, 0.58, 0) * CYL_Y, PEARL, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder) -- shaft
    Part(m, "Pommel", V(0.12, 0.11, 0.11), CF(0, -0.9, 0) * CYL_Y, GOLD, METAL, Enum.PartType.Cylinder)
    Part(m, "Pommel2", V(0.13, 0.13, 0.13), CF(0, -0.99, 0), GOLD, METAL, Enum.PartType.Ball)
    for i, y in ipairs({ -0.2, 0.25, 1.15, 1.85 }) do
        local r = (i == 4) and 0.12 or 0.095
        Part(m, "Accent", V(0.05, r, r), CF(0, y, 0) * CYL_Y, GOLD, METAL, Enum.PartType.Cylinder)
    end
    -- the head (turned about the shaft so its flat faces the camera in the hold): socket, then a broad two-piece
    -- blade that curves toward the tip
    local H = ANG(0, R(o.HeadTurn or 90), 0)
    Part(m, "Guard", V(0.22, 0.17, 0.17), CF(0, top - 0.05, 0) * CYL_Y, GOLD, METAL, Enum.PartType.Cylinder)
    local b1 = H * CF(0.0, top + 0.4, 0)
    local b2 = b1 * CF(0, 0.4, 0) * ANG(0, 0, R(-10)) * CF(0, 0.32, 0)
    Part(m, "Blade", V(0.3, 0.8, 0.04), b1, PEARL, METAL)
    Part(m, "Blade2", V(0.24, 0.64, 0.04), b2, PEARL, METAL)
    local tip = b2 * CF(0, 0.32, 0)
    local w = Instance.new("WedgePart")
    w.Name = "Blade3"; w.Size = V(0.04, 0.34, 0.24); w.Color = PEARL; w.Material = METAL
    w.CFrame = tip * CF(0, 0.17, 0) * ANG(0, R(90), 0)
    w.Anchored = true; w.CanCollide, w.CanQuery, w.CanTouch, w.CastShadow = false, false, false, false
    w.Parent = m
    -- gold edges down both sides of the blade + a gold spine
    for _, sx in ipairs({ -1, 1 }) do
        Part(m, "Edge", V(0.03, 0.8, 0.046), b1 * CF(sx * 0.155, 0, 0), GOLD, Enum.Material.Neon)
        Part(m, "Edge", V(0.03, 0.64, 0.046), b2 * CF(sx * 0.125, 0, 0), GOLD, Enum.Material.Neon)
    end
    Part(m, "Accent", V(0.04, 1.3, 0.05), b1 * CF(0, 0.15, 0), GOLD, METAL)
    -- a glowing fuller down the middle of the blade (both faces), breathing light
    for _, sz in ipairs({ -1, 1 }) do
        local f1 = SkinFX.Deco(m, { Name = "Fuller", Size = V(0.05, 0.66, 0.012), CFrame = b1 * CF(0, 0.02, sz * 0.024), Color = PALE, Glow = true, Zone = "Blade" })
        local f2 = SkinFX.Deco(m, { Name = "Fuller", Size = V(0.04, 0.5, 0.012), CFrame = b2 * CF(0, -0.02, sz * 0.024), Color = PALE, Glow = true, Zone = "Blade" })
        SkinFX.Pulse(f1, 0, 0.5, 2.2); SkinFX.Pulse(f2, 0.05, 0.55, 2.2)
    end
    -- gold crossguard wings sweeping up from the socket
    for _, sx in ipairs({ -1, 1 }) do
        local g = Instance.new("WedgePart")
        g.Name = "Deco_Crossguard"; g.Size = V(0.035, 0.3, 0.2); g.Color = GOLD; g.Material = METAL; g.Reflectance = 0.25
        g.CFrame = H * CF(sx * 0.16, top + 0.12, 0) * ANG(0, R(sx * 90), 0) * ANG(R(-20), 0, 0)
        g.Anchored = true; g.CanCollide, g.CanQuery, g.CanTouch, g.CastShadow = false, false, false, false
        g:SetAttribute("SkinDeco", true)
        g.Parent = m
    end
    -- glowing star where the blade meets the socket (both faces)
    for _, sz in ipairs({ -1, 1 }) do
        SkinFX.Star(m, H * CF(0, top + 0.16, sz * 0.03) * ANG(0, R(sz * -90), 0), 0.2, true)
    end
    -- a halo turning around the shaft below the head (+ a smaller one counter-rotating)
    SkinFX.Ring(m, CF(0, top - 0.25, 0) * ANG(0, 0, R(90)), 0.16, 0.02, 12, PALE, "Halo", { Spin = 1.4 })
    SkinFX.Ring(m, CF(0, top - 0.33, 0) * ANG(0, 0, R(90)), 0.11, 0.012, 9, GOLD, "Halo2", { Spin = -2.2 })
    -- WINGS: three feathers each side sweeping down and out from the blade's base; they breathe, and spread on inspect
    for _, sx in ipairs({ -1, 1 }) do
        local hinge = H * V(sx * 0.08, top + 0.02, 0)
        for i = 1, 3 do
            local lift = ({ 62, 48, 34 })[i]
            -- feather base: -Z runs along the feather; points out to the side (sx) and down
            local dir = H:VectorToWorldSpace((V(sx, 0, 0) * math.sin(R(lift)) + V(0, -1, 0) * math.cos(R(lift))).Unit)
            local base = CFrame.lookAt(hinge, hinge - dir, H:VectorToWorldSpace(V(0, 0, 1)))
            local ax = H:VectorToWorldSpace(V(0, 0, sx))
            for _, fp in ipairs(SkinFX.Feather(m, base * ANG(0, 0, R(90)), ({ 0.62, 0.5, 0.38 })[i], ({ 0.11, 0.09, 0.07 })[i], "Guard", i == 1)) do
                SkinFX.Hinge(fp, hinge, ax, 30 + i * 6, 3 + i)
            end
        end
    end
    -- the swing trail: a golden ribbon from the blade's base to its tip, lit only while you attack
    local bladePart = m:FindFirstChild("Blade")
    if bladePart then
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Name, a1.Name = "TrailBase", "TrailTip"
        a0.Position = bladePart.CFrame:PointToObjectSpace((b1 * CF(0, -0.3, 0)).Position)
        a1.Position = bladePart.CFrame:PointToObjectSpace((tip * CF(0, 0.3, 0)).Position)
        a0.Parent, a1.Parent = bladePart, bladePart
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Color = ColorSequence.new(Color3.fromRGB(255, 250, 230), GOLD)
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
        tr.LightEmission = 1; tr.LightInfluence = 0
        tr.Lifetime = 0.16; tr.MinLength = 0.02; tr.FaceCamera = true
        tr.Enabled = false
        tr:SetAttribute("SwingTrail", true)
        tr.Parent = bladePart
    end
end

-- INFERNAL SCYTHE (skin-only model, 2026-10-04): a long obsidian shaft ringed in hell-iron, a horned collar with a
-- violet sigil turning round it, and a crescent blade with a molten crimson edge and runes that breathe; bone spikes
-- flare from the collar on inspect; the swing leaves a hellfire ribbon.
BUILDERS.Scythe = function(m, o)
    local C = SkinFX.Colors
    local OBS, IRON, BONE = Color3.fromRGB(30, 20, 32), Color3.fromRGB(74, 40, 50), Color3.fromRGB(58, 38, 50)
    local top = 1.45 -- (a shorter shaft than the spear: in first person the blade has to be in view)
    Part(m, "Grip", V(2.25, 0.08, 0.08), CF(0, 0.33, 0) * CYL_Y, OBS, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
    Part(m, "Pommel", V(0.16, 0.12, 0.12), CF(0, -0.8, 0) * CYL_Y, IRON, METAL, Enum.PartType.Cylinder)
    local spike = Instance.new("WedgePart") -- a spike off the butt
    spike.Name = "Pommel2"; spike.Size = V(0.06, 0.22, 0.1); spike.Color = IRON; spike.Material = METAL
    spike.CFrame = CF(0, -0.95, 0) * ANG(R(180), 0, 0); spike.Anchored = true
    spike.CanCollide, spike.CanQuery, spike.CanTouch, spike.CastShadow = false, false, false, false
    spike.Parent = m
    for i, y in ipairs({ -0.3, 0.05, 0.7, 1.2 }) do
        Part(m, "Accent", V(0.06, (i == 4) and 0.13 or 0.105, (i == 4) and 0.13 or 0.105), CF(0, y, 0) * CYL_Y, IRON, METAL, Enum.PartType.Cylinder)
    end
    -- bone wraps on the grip
    for k = 0, 3 do Part(m, "Accent", V(0.03, 0.095, 0.095), CF(0, -0.2 + k * 0.06, 0) * CYL_Y, BONE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder) end
    -- the collar + two small horns + the turning sigil
    Part(m, "Guard", V(0.26, 0.17, 0.17), CF(0, top, 0) * CYL_Y, IRON, METAL, Enum.PartType.Cylinder)
    for _, sz in ipairs({ -1, 1 }) do
        local h = Instance.new("WedgePart")
        h.Name = "Deco_Horn"; h.Size = V(0.04, 0.26, 0.12); h.Color = BONE; h.Material = Enum.Material.SmoothPlastic
        h.CFrame = CF(-0.05, top + 0.12, sz * 0.07) * ANG(R(sz * -25), 0, R(20))
        h.Anchored = true; h.CanCollide, h.CanQuery, h.CanTouch, h.CastShadow = false, false, false, false
        h:SetAttribute("SkinDeco", true)
        h.Parent = m
    end
    SkinFX.Ring(m, CF(0, top - 0.2, 0) * ANG(0, 0, R(90)), 0.17, 0.02, 12, C.Violet, "Halo", { Spin = 1.3 })
    SkinFX.Ring(m, CF(0, top - 0.28, 0) * ANG(0, 0, R(90)), 0.12, 0.012, 9, C.Crimson, "Halo2", { Spin = -2.0 })
    -- the BAT-WING blade (owner's reference, 2026-10-04): from the collar it sweeps sideways (+Z: back across your view,
    -- over the shaft) in a long shallow curve -- a black spine on top, a molten membrane under it and scalloped claws
    -- hanging off the cutting edge; its flat faces the camera
    local prev = V(0, top + 0.12, 0.05)
    local n = 8
    local segs = {}
    for i = 1, n do
        local t = i / n
        local p = V(0, top + 0.12 + 0.16 * math.sin(t * math.pi) - 0.34 * t * t, 0.06 + 1.4 * t) -- (owner 2026-10-04: it folded back down the shaft and pointed at your face -- now it juts out square from the collar and hooks down at the tip, like a real scythe)
        local mid = (prev + p) / 2
        local len = (p - prev).Magnitude + 0.02
        local w = 0.3 * (1 - t) ^ 0.7 + 0.04
        local d = (p - prev).Unit
        local cf = CFrame.fromMatrix(mid, d, d:Cross(Vector3.xAxis)) -- (length along local X, width up, thin toward the camera)
        Part(m, (i == 1) and "Blade" or "Blade2", V(len, w, 0.035), cf * CF(0, -w * 0.15, 0), OBS, METAL)
        -- molten edge along the lower (cutting) side + a hell-iron spine on the top
        Part(m, "Edge", V(len, 0.03, 0.045), cf * CF(0, -w * 0.62, 0), C.Crimson, Enum.Material.Neon)
        Part(m, "Accent", V(len, 0.02, 0.042), cf * CF(0, w * 0.38, 0), IRON, METAL)
        -- the scallops: black claws hanging off the edge between the wing's "fingers"
        if i % 2 == 1 and i < n then
            Part(m, "Accent", V(0.05, 0.17 * (1 - t * 0.5), 0.03), cf * CF(len * 0.3, -w * 0.62 - 0.07, 0) * ANG(0, 0, R(-24)), OBS, METAL)
        end
        table.insert(segs, cf)
        prev = p
    end
    -- runes down the blade (both faces), breathing light
    for k = 2, n - 2, 2 do
        for _, sz in ipairs({ -1, 1 }) do
            local r = SkinFX.Deco(m, { Name = "Rune", Size = V(0.06, 0.05, 0.012), CFrame = segs[k] * CF(0, 0, sz * 0.022) * ANG(0, 0, R(45)), Color = C.Violet, Glow = true, Zone = "Blade" })
            SkinFX.Pulse(r, 0, 0.5, 1.8 + k * 0.1)
        end
    end
    -- bone spikes off the collar: they breathe and FLARE on inspect
    for _, sz in ipairs({ -1, 1 }) do
        local hinge = V(-0.06, top + 0.02, sz * 0.06)
        for i = 1, 2 do
            local sp = SkinFX.Deco(m, { Name = "BoneSpike", Wedge = true, Size = V(0.03, 0.08, 0.38 - i * 0.08), Color = BONE, Zone = "Guard",
                CFrame = CFrame.lookAt(hinge, hinge + V(-0.6, -0.35 - i * 0.25, sz * 0.5)) * CF(0, 0, -(0.38 - i * 0.08) / 2) })
            SkinFX.Hinge(sp, hinge, V(0, 0, sz), 30 + i * 8, 2 + i)
        end
    end
    -- hellfire licking off the blade root
    local bladePart = m:FindFirstChild("Blade")
    if bladePart then
        local att = Instance.new("Attachment"); att.Parent = bladePart
        local fire = Instance.new("ParticleEmitter")
        fire.Name = "SkinHellfire"; fire.Texture = "rbxasset://textures/particles/fire_main.dds"
        fire.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 130, 140)), ColorSequenceKeypoint.new(0.5, C.Crimson), ColorSequenceKeypoint.new(1, C.Violet) })
        fire.LightEmission = 0.9; fire.LightInfluence = 0
        fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0) })
        fire.Lifetime = NumberRange.new(0.3, 0.55); fire.Rate = 8; fire.Speed = NumberRange.new(0.2, 0.5); fire.Acceleration = V(0, 1, 0)
        fire.SpreadAngle = Vector2.new(25, 25); fire.LockedToPart = true
        fire:SetAttribute("SkinFx", true)
        fire.Parent = att
        -- the swing trail: a crimson-to-violet ribbon from the blade's root to its tip, lit only while you attack
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Name, a1.Name = "TrailBase", "TrailTip"
        a0.Position = bladePart.CFrame:PointToObjectSpace(V(0.15, top + 0.15, 0))
        a1.Position = bladePart.CFrame:PointToObjectSpace(prev)
        a0.Parent, a1.Parent = bladePart, bladePart
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Color = ColorSequence.new(Color3.fromRGB(255, 160, 170), C.Violet)
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
        tr.LightEmission = 1; tr.LightInfluence = 0
        tr.Lifetime = 0.18; tr.MinLength = 0.02; tr.FaceCamera = true
        tr.Enabled = false
        tr:SetAttribute("SwingTrail", true)
        tr.Parent = bladePart
    end
end


-- ==================== WEAPON CLASSES v5 (Update 5) ====================
-- Owner (Update 5): "Melee is awkwardly in the middle of the screen, everything right a little bit"; "make sure everything
-- is held correctly (especially melees), 1:1 compare animations and holds and attacks with the same type of melee in
-- valorant (i.e knife, axe, karambit, spear etc)" -- and (2026-10-11) "we dont want any copyright issues": the Valorant
-- melees were studied only for the TYPE of hold, the kind of arc and the weight / timing of each class; every key below is
-- our own. What the reference showed, per class:
--   every melee rests at the RIGHT EDGE: the fist low in the bottom-right corner, the free hand relaxed at the bottom-left,
--   nothing near the crosshair. Light attacks sweep across the lower screen (forehand right -> left, then backhand), the
--   heavy has a visible wind-up, the draw brings the weapon up from below, the inspect raises it toward the middle-right,
--   shows one face, turns it to show its length / the other face, and settles back.
--   Knife     forward grip, the blade pointing forward-left and a little up from the corner (we see its flat)
--   Karambit  REVERSE grip: ring on top at the index finger, the hooked blade curling out of the bottom of the fist
--   Sword     held upright at the right edge, blade straight up, the flat to you; wide flat slashes
--   Axe       held low on the haft, head up at the top right; diagonal chops, a heavy overhead
--   Blunt     (mace / hammer / bat) the axe hold, heavier swings
--   Spear     (staff / spear) two hands on the shaft, pointed forward past the crosshair's lower right; stabs
--   Scythe    upright like the axe, the blade hooking over the top toward the middle; reaping sweeps
-- Gun track keys: Inspects.K(t, x, y, z, pitch, yaw, roll, ease) = camera space about the fist's grip point (studs, degrees;
-- pitch + = tip back toward you / up, yaw + = tip swings left, roll + = tip leans left on screen; roll, then pitch, then yaw).
-- Un-eased keys run on the rig's smooth spline; "Out" marks a strike. Every step stays under ~90 deg (a CFrame lerp takes the
-- short way round). BladeRoll turns the weapon about its own handle -> tip axis (a flip in place): the fist never twists
-- (HOLDS v4: the fist is a straight continuation of the forearm), so nothing swings through the hand. Clip check:
-- tools/gun_clipcheck.luau with melee rig ids (0 BLADE poses per class).
local K, N = Inspects.K, Inspects.N
-- the karambit's spins turn about the finger ring (camera X through it), not the grip
local RING = Vector3.new(-0.04, 0.12, -0.02)
local function Ring(deg: number): CFrame
    return CFrame.new(RING) * CFrame.Angles(math.rad(deg), 0, 0) * CFrame.new(-RING)
end
local function ClassAnims(class: string): any
    local a = {}
    if class == "Knife" then
        a.Equip = { Length = 0.55, Tracks = {
            Gun = { K(0, 0.1, -0.55, 0.15, -40, 0, -15), K(0.3, 0, 0.03, 0, 4, 0, 0), K(0.42, 0, -0.008, 0, -1.5, 0, 0), K(0.55) },
            BladeRoll = { N(0, -360), N(0.34, -12), N(0.55, 0) },
        }, Events = { { 0.05, "Equip" } } }
        -- forehand: across from the right edge to the left, the blade leading
        a.Light1 = { Length = 0.45, Tracks = { Gun = {
            K(0), K(0.06, 0.1, 0.06, 0.06, 4, -22, -8), K(0.14, -0.4, 0.02, -0.16, -6, 36, 14, "Out"), K(0.22, -0.47, -0.01, -0.13, -8, 42, 16), K(0.45),
        } }, Events = { { 0.1, "Swing" } } }
        -- backhand: from the left back to the right edge
        a.Light2 = { Length = 0.45, Tracks = { Gun = {
            K(0), K(0.07, -0.34, 0.05, 0.02, 4, 32, 14), K(0.15, 0.1, 0.04, -0.16, -6, -28, -12, "Out"), K(0.23, 0.14, 0.03, -0.13, -8, -32, -14), K(0.45),
        } }, Events = { { 0.11, "Swing" } } }
        -- heavy: drawn back, then driven forward at the crosshair
        a.Heavy = { Length = 0.8, Tracks = { Gun = {
            K(0), K(0.22, 0.06, 0.04, 0.2, 10, -10, -4), K(0.34, -0.2, 0.08, -0.6, -14, 22, 4, "Out"), K(0.5, -0.18, 0.07, -0.52, -12, 20, 4), K(0.8),
        } }, Events = { { 0.3, "Swing" } } }
        -- inspect: brought up toward the middle, tip raised, flat to you; tipped over to show its length; flipped to the
        -- other face (Flip); settles back into the corner
        a.Inspect = { Length = 3.0, Beats = { Raise = 0.45, Flip = 1.6, Settle = 2.75 }, Tracks = {
            Gun = { K(0), K(0.45, -0.18, 0.14, 0.02, 26, -18, -32), K(1.1, -0.19, 0.15, 0.02, 24, -20, -30), K(1.6, -0.16, 0.12, 0, 10, 8, 36),
                K(2.25, -0.15, 0.12, 0, 9, 10, 34), K(2.75, 0, -0.01, 0, -2, 0, 2), K(3.0) },
            BladeRoll = { N(0, 0), N(0.5, 18), N(1.2, 22), N(1.55, 200), N(2.25, 204), N(2.65, 360), N(3.0, 360) },
        }, Events = { { 0.45, "Raise" }, { 1.6, "Flip" }, { 2.75, "Settle" } } }
    elseif class == "Karambit" then
        a.Equip = { Length = 0.62, Tracks = { Gun = {
            { 0, CFrame.new(0.1, -0.35, 0.05) * Ring(-360) }, { 0.08, CFrame.new(0.08, -0.27, 0.0) * Ring(-288) },
            { 0.16, CFrame.new(0.06, -0.19, -0.04) * Ring(-216) }, { 0.24, CFrame.new(0.04, -0.11, -0.06) * Ring(-144) },
            { 0.32, CFrame.new(0.02, -0.04, -0.05) * Ring(-72) }, { 0.42, CFrame.new(0, 0.01, -0.01) * Ring(6), "Out" }, { 0.62, CFrame.identity },
            -- (spun a little further out than the hold: the ring's guard came round into the forearm)
        } }, Events = { { 0.05, "Equip" } } }
        -- hooking slashes, the fist leading and the blade trailing under it
        a.Light1 = { Length = 0.46, Tracks = { Gun = {
            K(0), K(0.07, 0.1, 0.08, 0.04, 6, -18, -8), K(0.16, -0.42, 0.16, -0.18, 18, 34, 12, "Out"), K(0.24, -0.48, 0.14, -0.15, 20, 38, 14), K(0.46),
        } }, Events = { { 0.11, "Swing" } } }
        a.Light2 = { Length = 0.46, Tracks = { Gun = {
            K(0), K(0.07, -0.34, 0.1, 0.02, 6, 28, 12), K(0.16, 0.1, 0.16, -0.18, 18, -30, -14, "Out"), K(0.24, 0.14, 0.14, -0.15, 20, -34, -16), K(0.46),
        } }, Events = { { 0.11, "Swing" } } }
        -- heavy: tucked low, then ripped upward and forward
        a.Heavy = { Length = 0.82, Tracks = { Gun = {
            K(0), K(0.24, 0.05, -0.06, 0.12, -10, -6, -6), K(0.38, -0.12, 0.3, -0.4, 44, 10, 8, "Out"), K(0.52, -0.1, 0.27, -0.34, 40, 8, 6), K(0.82),
        } }, Events = { { 0.32, "Swing" } } }
        -- inspect: lifted in, two turns round the ring (Flip at the end of the first), then the blade held up and turned
        local P = CFrame.new(-0.14, 0.14, -0.08) -- (lifted out in front of the forearm for the spins)
        local gun = { { 0, CFrame.identity }, { 0.3, P } }
        for k = 1, 10 do table.insert(gun, { 0.3 + k * 0.075, P * Ring(72 * k) }) end
        table.insert(gun, K(1.4, -0.16, 0.24, 0.04, 40, -12, 4))
        table.insert(gun, K(2.5, -0.16, 0.25, 0.04, 42, -10, 4))
        table.insert(gun, K(2.8, -0.02, 0.03, 0, 5, 0, 0))
        table.insert(gun, K(3.0))
        a.Inspect = { Length = 3.0, Beats = { Raise = 0.3, Flip = 0.68, Settle = 2.8 }, Tracks = {
            Gun = gun,
            BladeRoll = { N(0, 0), N(1.45, 0), N(1.75, 55), N(2.05, 60), N(2.3, -30), N(2.5, -32), N(2.8, 0), N(3.0, 0) },
        }, Events = { { 0.3, "Raise" }, { 0.68, "Flip" }, { 2.8, "Settle" } } }
    elseif class == "Sword" then
        a.Equip = { Length = 0.7, Tracks = {
            Gun = { K(0, 0.1, -0.6, 0.2, -30, 0, -20), K(0.3, 0.02, 0.05, 0, 6, 0, 4), K(0.5, 0, -0.01, 0, -2, 0, -1), K(0.7) },
            BladeRoll = { N(0, -90), N(0.35, -10), N(0.7, 0) },
        }, Events = { { 0.05, "Equip" } } }
        -- forehand: a wide flat cut right -> left, the blade laid over
        a.Light1 = { Length = 0.52, Tracks = { Gun = {
            K(0), K(0.09, 0.1, 0.12, 0.08, 16, 0, -26), K(0.145, -0.16, 0.06, -0.08, -4, 8, 22), K(0.2, -0.38, 0, -0.22, -18, 18, 58, "Out"),
            K(0.28, -0.42, -0.02, -0.19, -20, 20, 62), K(0.52), -- (not laid flat: the long blade reached the resting left hand)
        } }, Events = { { 0.13, "Swing" } } }
        -- backhand: from the left back across to the right edge
        a.Light2 = { Length = 0.52, Tracks = { Gun = {
            K(0), K(0.09, -0.34, 0.1, 0.02, 10, 8, 48), K(0.145, -0.1, 0.06, -0.1, -4, 0, 0), K(0.2, 0.12, 0.02, -0.2, -8, -12, -44, "Out"),
            K(0.28, 0.16, 0, -0.16, -10, -14, -47), K(0.52),
        } }, Events = { { 0.13, "Swing" } } }
        -- heavy: raised, then brought down through the middle
        a.Heavy = { Length = 0.95, Tracks = { Gun = {
            K(0), K(0.3, 0.04, 0.22, 0.14, 34, 0, -6), K(0.38, -0.04, 0.1, -0.12, -10, 0, 2), K(0.46, -0.1, -0.12, -0.36, -68, 4, 6, "Out"),
            K(0.62, -0.09, -0.1, -0.32, -64, 4, 5), K(0.95),
        } }, Events = { { 0.38, "Swing" } } }
        -- inspect: raised upright toward the middle, laid over to show the whole blade, flipped to the other face, stood back up
        a.Inspect = { Length = 3.1, Beats = { Raise = 0.5, Flip = 2.05, Settle = 2.85 }, Tracks = {
            Gun = { K(0), K(0.5, -0.2, 0.1, 0.04, 6, 0, -6), K(1.2, -0.22, 0.16, 0.02, 4, 0, 52), K(1.75, -0.23, 0.17, 0.02, 6, 0, 54),
                K(2.35, -0.22, 0.16, 0.02, 4, 0, 52), K(2.85, 0, -0.01, 0, -2, 0, -2), K(3.1) }, -- (leant over ~50 deg, not flat: a wide guard would swing into the fist)
            BladeRoll = { N(0, 0), N(1.85, 0), N(2.25, 180), N(2.75, 360), N(3.1, 360) },
        }, Events = { { 0.5, "Raise" }, { 2.05, "Flip" }, { 2.85, "Settle" } } }
    elseif class == "Axe" or class == "Blunt" or class == "Scythe" then
        local heavyK = (class == "Blunt") and 1.08 or 1 -- (blunt swings a touch slower)
        a.Equip = { Length = 0.65, Tracks = {
            Gun = { K(0, 0.15, -0.55, 0.2, -50, 0, -25), K(0.3, 0.02, 0.04, -0.02, 8, 0, -4), K(0.48, 0, -0.02, 0, -3, 0, 1), K(0.65) },
        }, Events = { { 0.05, "Equip" } } }
        -- diagonal chop right -> left, head first
        a.Light1 = { Length = 0.55 * heavyK, Tracks = { Gun = {
            K(0), K(0.1 * heavyK, 0.08, 0.16, 0.08, 24, 0, -22), K(0.17 * heavyK, -0.12, 0.02, -0.12, -20, 4, 20),
            K(0.24 * heavyK, -0.26, -0.18, -0.3, -64, 8, 42, "Out"), K(0.32 * heavyK, -0.28, -0.2, -0.28, -68, 9, 44), K(0.55 * heavyK),
        } }, Events = { { 0.16 * heavyK, "Swing" } } }
        -- diagonal chop left -> right
        a.Light2 = { Length = 0.55 * heavyK, Tracks = { Gun = {
            K(0), K(0.1 * heavyK, -0.14, 0.16, 0.06, 20, 0, 24), K(0.17 * heavyK, 0, 0.02, -0.12, -18, -4, -8),
            K(0.24 * heavyK, 0.12, -0.16, -0.28, -60, -8, -32, "Out"), K(0.32 * heavyK, 0.14, -0.18, -0.26, -64, -9, -34), K(0.55 * heavyK),
        } }, Events = { { 0.16 * heavyK, "Swing" } } }
        -- heavy: overhead (the head never tips back past ~30 deg: it would swing into your face)
        a.Heavy = { Length = 0.95, Tracks = { Gun = {
            K(0), K(0.3, 0.04, 0.26, 0.12, 30, 0, -6), K(0.4, -0.04, 0.06, -0.16, -24, 0, 2), K(0.47, -0.1, -0.22, -0.4, -84, 4, 6, "Out"),
            K(0.62, -0.09, -0.2, -0.38, -80, 4, 5), K(0.95),
        } }, Events = { { 0.42, "Swing" } } }
        -- inspect: lifted in, the head turned to face you, then turned across to its other side (Flip), a weighted settle.
        -- Blunt weapons spin the haft a full turn in the hand instead.
        local roll = (class == "Blunt")
            and { N(0, 0), N(0.5, 30), N(1.3, 34), N(1.65, 194), N(2.0, 360), N(2.4, 360), N(3.0, 360) }
            or { N(0, 0), N(0.5, 55), N(1.3, 60), N(1.75, -50), N(2.35, -55), N(2.8, 0), N(3.0, 0) }
        a.Inspect = { Length = 3.0, Beats = { Raise = 0.45, Flip = 1.55, Settle = 2.75 }, Tracks = {
            Gun = { K(0), K(0.45, -0.14, 0.06, 0.04, 4, 0, -14), K(1.3, -0.15, 0.07, 0.04, 6, 0, -16), K(1.6, -0.1, 0.05, 0.03, 2, 0, 10),
                K(2.35, -0.1, 0.06, 0.03, 3, 0, 14), K(2.75, 0, -0.03, 0, -3, 0, 2), K(3.0) },
            BladeRoll = roll,
        }, Events = { { 0.45, "Raise" }, { 1.55, "Flip" }, { 2.75, "Settle" } } }
        if class == "Scythe" then
            -- reaping sweeps: wider and flatter than an axe chop, the blade hooking through
            a.Light1 = { Length = 0.58, Tracks = { Gun = {
                K(0), K(0.1, 0.12, 0.1, 0.06, 10, 0, -24), K(0.17, -0.16, 0.02, -0.12, -8, 6, 26), K(0.25, -0.36, -0.04, -0.24, -20, 12, 54, "Out"),
                K(0.33, -0.39, -0.06, -0.22, -22, 13, 57), K(0.58),
            } }, Events = { { 0.17, "Swing" } } }
            a.Light2 = { Length = 0.58, Tracks = { Gun = {
                K(0), K(0.1, -0.3, 0.1, 0.04, 8, 4, 46), K(0.17, -0.06, 0.04, -0.12, -6, 0, 6), K(0.25, 0.14, -0.04, -0.22, -20, -10, -44, "Out"),
                K(0.33, 0.17, -0.06, -0.2, -22, -11, -48), K(0.58),
            } }, Events = { { 0.17, "Swing" } } }
        end
    elseif class == "Spear" then
        a.Equip = { Length = 0.65, Tracks = {
            Gun = { K(0, 0.12, -0.5, 0.25, -40, 0, -20), K(0.3, 0.01, 0.03, 0, 4, 0, 2), K(0.48, 0, -0.01, 0, -2, 0, 0), K(0.65) },
            BladeRoll = { N(0, -180), N(0.4, -10), N(0.65, 0) },
        }, Events = { { 0.05, "Equip" } } }
        -- quick stabs past the crosshair (a little left, then a little right)
        a.Light1 = { Length = 0.5, Tracks = { Gun = {
            K(0), K(0.07, 0.04, -0.02, 0.18, 4, 0, 0), K(0.17, -0.08, 0.04, -0.72, -4, 4, 0, "Out"), K(0.26, -0.07, 0.03, -0.64, -3, 4, 0), K(0.5),
        } }, Events = { { 0.12, "Swing" } } }
        a.Light2 = { Length = 0.5, Tracks = { Gun = {
            K(0), K(0.07, -0.03, 0.02, 0.18, 2, 0, 0), K(0.17, -0.18, 0.07, -0.7, -6, 9, -6, "Out"), K(0.26, -0.16, 0.06, -0.62, -5, 8, -5), K(0.5),
        } }, Events = { { 0.12, "Swing" } } }
        a.Heavy = { Length = 0.95, Tracks = { Gun = {
            K(0), K(0.32, 0.1, 0.06, 0.4, 10, -8, -14), K(0.46, -0.12, 0.05, -1.1, -6, 6, 16, "Out"), K(0.62, -0.1, 0.05, -1.0, -5, 5, 14), K(0.95),
        } }, Events = { { 0.4, "Swing" } } }
        a.Inspect = { Length = 3.0, Beats = { Raise = 0.5, Flip = 1.6, Settle = 2.75 }, Tracks = {
            Gun = { K(0), K(0.5, -0.12, 0.1, 0.06, 18, -16, -10), K(1.3, -0.13, 0.11, 0.06, 20, -18, -10), K(1.65, -0.1, 0.08, 0.04, 12, 6, 8),
                K(2.35, -0.1, 0.09, 0.04, 13, 8, 9), K(2.75, 0, -0.01, 0, -2, 0, 1), K(3.0) },
            BladeRoll = { N(0, 0), N(0.5, 40), N(1.3, 44), N(1.75, 220), N(2.35, 224), N(2.8, 360), N(3.0, 360) },
        }, Events = { { 0.5, "Raise" }, { 1.6, "Flip" }, { 2.75, "Settle" } } }
    elseif class == "Kunai" then
        -- KUNAI (Update 5, skins plan): forward grip, the kunai lying across the lower right pointing in toward the middle,
        -- its ring by the fist. Spins turn about the RING (in the screen plane, the flat to you) like a finger spin.
        local RK = Vector3.new(0.21, -0.073, 0.14) -- (camera space: the ring at the pommel end, behind the grip along the handle)
        -- (the spin plane can lean out of the screen plane so the blade passes BESIDE the fist instead of through it when it
        -- points back down the arm; Studio tuning: workspace attrs DevKunaiTiltX / DevKunaiTiltY, degrees)
        local isStudio = game:GetService("RunService"):IsStudio()
        -- (measured with tools/melee_clipcheck: flat (0 / 0) the blade crossed the fist block on the draw 5/48 frames and
        -- the inspect spins 15/171; 35 / 0 -> 0 + 4/164; 35 / 25 -> 0 frames on equip, two inspects, light and heavy)
        local TX = math.rad((isStudio and workspace:GetAttribute("DevKunaiTiltX")) or 35)
        local TY = math.rad((isStudio and workspace:GetAttribute("DevKunaiTiltY")) or 25)
        local TILT = CFrame.Angles(TX, TY, 0)
        local function Spin(deg: number): CFrame return CFrame.new(RK) * TILT * CFrame.Angles(0, 0, math.rad(deg)) * TILT:Inverse() * CFrame.new(-RK) end
        -- (owner: "The kunai animation still stutters, both when the inspect first starts and towards the end" -- the keys were
        -- the cause: 72 deg spin keys 0.075 s apart lerp along CHORDS round the ring (the tip's speed rippled 13 times a
        -- second), the spin went from 0 to 960 deg/s in one key and stopped dead into a pose with a different roll, and labelled
        -- / unlabelled keys mixed tangents. Both the draw and the inspect are now ONE analytic curve per channel, sampled every
        -- 1/30 s into un-eased keys (the rig's Catmull-Rom runs smoothly through evenly spaced samples): every channel speeds
        -- up once and slows down once, they share their timing, and the spin's ANGULAR speed eases in and out.)
        local function S5(x: number): number x = math.clamp(x, 0, 1) return x * x * x * (x * (x * 6 - 15) + 10) end   -- smootherstep
        local function OutC(x: number): number x = math.clamp(x, 0, 1) return 1 - (1 - x) ^ 3 end
        local DT = 1 / 60   -- (1/30 left 40 deg chords at the spin's peak speed)
        local function Sampled(len: number, fn: (number) -> any): { any }
            local out = {}
            local n = math.ceil(len / DT - 1e-6)
            for i = 0, n do local t = math.min(len, i * DT); table.insert(out, { t, fn(t) }) end
            return out
        end
        -- draw: flicked up from below the frame, one turn round the ring, decelerating once into the hold (ease-out cubic)
        local DRAW0 = CFrame.new(0.06, -0.4, 0.12)
        a.Equip = { Length = 0.6, Tracks = { Gun = Sampled(0.6, function(t)
            local k = OutC(t / 0.6)
            return DRAW0:Lerp(CFrame.identity, k) * Spin(-360 * (1 - k))
        end) }, Events = { { 0.05, "Equip" } } }
        a.Light1 = { Length = 0.42, Tracks = { Gun = {
            K(0), K(0.06, 0.08, 0.05, 0.05, 4, -18, -6), K(0.13, -0.36, 0.02, -0.14, -6, 30, 10, "Out"), K(0.21, -0.42, 0, -0.12, -8, 34, 12), K(0.42),
        } }, Events = { { 0.09, "Swing" } } }
        a.Light2 = { Length = 0.42, Tracks = { Gun = {
            K(0), K(0.07, -0.3, 0.05, 0.02, 4, 28, 10), K(0.14, 0.08, 0.04, -0.14, -6, -24, -10, "Out"), K(0.22, 0.12, 0.03, -0.12, -8, -28, -12), K(0.42),
        } }, Events = { { 0.1, "Swing" } } }
        -- heavy: drawn back, then driven along its point
        a.Heavy = { Length = 0.78, Tracks = { Gun = {
            K(0), K(0.22, 0.12, 0.02, 0.14, 4, -8, 0), K(0.34, -0.34, 0.08, -0.4, -6, 14, 0, "Out"), K(0.5, -0.31, 0.07, -0.36, -5, 12, 0), K(0.78),
        } }, Events = { { 0.3, "Swing" } } }
        -- inspect: lifted in, two spins round the ring (the spin's angular speed eases in and out: no snap to full speed, no
        -- dead stop), flowing into the held look -- the kunai stood up, rolled to show its face -- turned over to the other
        -- face during the hold, then ONE arc back to rest with the last half turn of the roll, landing together.
        -- (measured in play, first pass: the speed dipped and rose again at every hand-off between moves -- lift-in -> spin at
        -- 0.32, spin -> look at 1.36, look -> turnover at 1.78. The moves now OVERLAP, each starting while the last eases out,
        -- so the motion flows from one into the next.)
        -- (second pass: the turn rate still dipped 392 -> 115 -> 162 deg/s where the spin handed over to the look, and the
        -- roll 108 -> 84 -> 650 before the turnover -> the look starts while the spin is still at speed, the turnover overlaps
        -- the arrival)
        --   0.00-0.40  lift in to P              0.05-1.25  two spins round the ring (-720 deg)
        --   0.80-1.50  P -> LOOK                 0.85-1.45  BladeRoll 0 -> 180 (turned over, while the spin eases out:
        --                                                   third pass, the roll rate dipped 428 -> 62 -> 658 between them)
        --   1.50-2.45  the held look (LOOK -> LOOK2, a slow drift)
        --   2.45-3.00  LOOK2 -> rest + BladeRoll 180 -> 360
        local P = CFrame.new(-0.1, 0.12, 0.02)
        local LOOK = CFrame.new(-0.12, 0.16, 0.04) * CFrame.fromEulerAnglesYXZ(0, 0, math.rad(-72))
        local LOOK2 = CFrame.new(-0.13, 0.17, 0.04) * CFrame.fromEulerAnglesYXZ(math.rad(2), 0, math.rad(-74))
        a.Inspect = { Length = 3.0, Beats = { Raise = 0.3, Flip = 0.68, Look = 1.5, Settle = 2.8 }, Tracks = {
            Gun = Sampled(3.0, function(t)
                local pose = CFrame.identity:Lerp(P, S5(t / 0.4))
                pose = pose:Lerp(LOOK, S5((t - 0.8) / 0.7))
                pose = pose:Lerp(LOOK2, S5((t - 1.5) / 0.95))
                pose = pose:Lerp(CFrame.identity, S5((t - 2.45) / 0.55))
                return pose * Spin(-720 * S5((t - 0.05) / 1.2))
            end),
            BladeRoll = Sampled(3.0, function(t) return 180 * S5((t - 0.85) / 0.6) + 180 * S5((t - 2.45) / 0.55) end),
        }, Events = { { 0.3, "Raise" }, { 0.68, "Flip" }, { 2.8, "Settle" } } }
    elseif class == "Balisong" then
        -- BALISONG (Update 5, skins plan): the knife hold; the butterfly action is two CUSTOM channels a set model's parts
        -- follow (docs/INSPECTS.md "Balisong"): BaliBlade 0 = open .. 1 = folded down between the handles, BaliB 0 = the
        -- bite handle latched to the safe one .. 1 = swung 180 deg away round its pin. At rest both are 0 (open).
        a.Equip = { Length = 0.8, Tracks = {
            Gun = { K(0, 0.1, -0.55, 0.15, -40, 0, -15), K(0.24, 0.03, -0.08, 0.04, -6, 0, -24), K(0.4, 0.01, 0.02, 0, 4, 0, 18),
                K(0.6, 0, 0.02, 0, 2, 0, -6), K(0.7, 0, -0.005, 0, -1, 0, 1), K(0.8) },
            BaliBlade = { N(0, 0.5), N(0.28, 0.5), N(0.48, 0, "Out"), N(0.8, 0) }, -- (Update 6: from half shut -- fully folded it swung out through the fist)
            BaliB = { N(0, 0), N(0.12, 0), N(0.3, 1, "Out"), N(0.5, 1), N(0.66, 0, "Out"), N(0.8, 0) },
        }, Events = { { 0.05, "Equip" }, { 0.48, "BaliOpen" }, { 0.66, "BaliLatch" } } }
        a.Light1 = { Length = 0.45, Tracks = { Gun = {
            K(0), K(0.06, 0.1, 0.06, 0.06, 4, -22, -8), K(0.14, -0.4, 0.02, -0.16, -6, 36, 14, "Out"), K(0.22, -0.47, -0.01, -0.13, -8, 42, 16), K(0.45),
        } }, Events = { { 0.1, "Swing" } } }
        a.Light2 = { Length = 0.45, Tracks = { Gun = {
            K(0), K(0.07, -0.34, 0.05, 0.02, 4, 32, 14), K(0.15, 0.1, 0.04, -0.16, -6, -28, -12, "Out"), K(0.23, 0.14, 0.03, -0.13, -8, -32, -14), K(0.45),
        } }, Events = { { 0.11, "Swing" } } }
        a.Heavy = { Length = 0.8, Tracks = { Gun = {
            K(0), K(0.22, 0.06, 0.04, 0.2, 10, -10, -4), K(0.34, -0.2, 0.08, -0.6, -14, 22, 4, "Out"), K(0.5, -0.18, 0.07, -0.52, -12, 20, 4), K(0.8),
        } }, Events = { { 0.3, "Swing" } } }
        -- inspect: raised in, two fans of the bite handle with little wrist turns, then folded shut, turned over and flicked
        -- open again (Flip), latched, settled
        a.Inspect = { Length = 3.2, Beats = { Raise = 0.45, Fan = 0.62, Flip = 1.75, Settle = 2.95 }, Tracks = {
            Gun = { K(0), K(0.45, -0.16, 0.14, 0.02, 24, -16, -30), K(0.72, -0.16, 0.15, 0.02, 24, -10, -22), K(0.95, -0.16, 0.14, 0.02, 22, -18, -34),
                K(1.2, -0.16, 0.15, 0.02, 24, -10, -22), K(1.45, -0.17, 0.15, 0.02, 24, -16, -30), K(2.4, -0.17, 0.15, 0.02, 22, -16, -30),
                K(2.95, 0, -0.01, 0, -2, 0, 2), K(3.2) },
            BaliB = { N(0, 0), N(0.55, 0), N(0.72, 1, "Out"), N(0.9, 0, "In"), N(1.1, 1, "Out"), N(1.28, 0, "In"), N(1.6, 0), N(1.7, 1, "Out"),
                N(2.2, 1), N(2.32, 0, "Out"), N(3.2, 0) },
            -- (Update 6, owner: "Butterfly knife inspect clips through hands"): the blade folds about a pin INSIDE the fist,
            -- so folding it fully shut (1) during the flip swept it through the glove; it now folds half way (out to the
            -- side, clear of the fist) while the knife turns over, then flicks open
            BaliBlade = { N(0, 0), N(1.55, 0), N(1.75, 0.45), N(1.95, 0.45), N(2.15, 0, "Out"), N(3.2, 0) },
            BladeRoll = { N(0, 0), N(1.75, 0), N(1.95, 180), N(2.6, 180), N(2.95, 360), N(3.2, 360) },
        }, Events = { { 0.45, "Raise" }, { 0.62, "Fan" }, { 1.75, "Flip" }, { 2.15, "BaliOpen" }, { 2.32, "BaliLatch" }, { 2.95, "Settle" } } }
    elseif class == "Knuckle" then
        -- KNUCKLE (Update 5, skins plan: knuckle-bow dagger / knuckles / gauntlets): the striking end (+Y) points forward
        -- and a little up out of a fist held in a guard at the lower right (the grip runs across the fist). Attacks are
        -- punches: a jab, a hook, an uppercut.
        a.Equip = { Length = 0.55, Tracks = { Gun = {
            K(0, 0.05, -0.5, 0.2, -30, 0, -10), K(0.28, 0, 0.04, -0.05, 4, 0, 0, "Out"), K(0.42, 0, -0.01, 0, -1, 0, 0), K(0.55),
        } }, Events = { { 0.05, "Equip" } } }
        a.Light1 = { Length = 0.4, Tracks = { Gun = { -- jab: straight at the crosshair
            K(0), K(0.06, 0.03, 0, 0.06, -4, -4, 0), K(0.13, -0.24, 0.1, -0.5, -6, 10, 0, "Out"), K(0.2, -0.23, 0.09, -0.46, -6, 9, 0), K(0.4),
        } }, Events = { { 0.1, "Swing" } } }
        a.Light2 = { Length = 0.45, Tracks = { Gun = { -- hook: across from the right
            K(0), K(0.07, 0.12, 0.04, 0.05, 0, -20, -10), K(0.15, -0.42, 0.06, -0.25, -4, 40, 20, "Out"), K(0.23, -0.47, 0.04, -0.22, -6, 44, 22), K(0.45),
        } }, Events = { { 0.11, "Swing" } } }
        a.Heavy = { Length = 0.8, Tracks = { Gun = { -- uppercut: dropped, then driven up and forward
            K(0), K(0.22, 0.04, -0.12, 0.1, -14, -6, -6), K(0.34, -0.18, 0.24, -0.4, 34, 10, 6, "Out"), K(0.5, -0.16, 0.22, -0.36, 30, 9, 5), K(0.8),
        } }, Events = { { 0.3, "Swing" } } }
        -- inspect: the fist raised toward the middle and turned to show its face, a flex, turned to the other side, back
        a.Inspect = { Length = 3.0, Beats = { Raise = 0.45, Flip = 1.6, Settle = 2.75 }, Tracks = {
            Gun = { K(0), K(0.45, -0.16, 0.12, 0, 10, -20, -10), K(1.15, -0.17, 0.13, 0, 11, -22, -10), K(1.25, -0.16, 0.12, -0.02, 9, -20, -8),
                K(1.35, -0.17, 0.13, 0, 11, -22, -10), K(1.65, -0.12, 0.1, 0, 6, 10, 8), K(2.35, -0.12, 0.11, 0, 7, 12, 9), K(2.75, 0, -0.01, 0, -2, 0, 1), K(3.0) },
            BladeRoll = { N(0, 0), N(0.5, 70), N(1.2, 74), N(1.7, -55), N(2.35, -58), N(2.8, 0), N(3.0, 0) },
        }, Events = { { 0.45, "Raise" }, { 1.6, "Flip" }, { 2.75, "Settle" } } }
    elseif class == "Dual" then
        -- DUAL (Update 5, skins plan: twin blades): a blade in EACH hand -- the rig draws a mirrored copy in the left fist
        -- (def.Dual), animated by its own channels GunL / BladeRollL (camera space about the left grip). KM = the mirror of K
        -- for the left hand (x, yaw and roll flipped), so a move authored for the right hand reads the same on the left.
        local function KM(t, x, y, z, p, yw, r, e) return K(t, -(x or 0), y, z, p, -(yw or 0), -(r or 0), e) end
        a.Equip = { Length = 0.6, Tracks = {
            Gun = { K(0, 0.1, -0.55, 0.15, -40, 0, -15), K(0.3, 0, 0.03, 0, 4, 0, 0), K(0.45, 0, -0.008, 0, -1.5, 0, 0), K(0.6) },
            GunL = { KM(0, 0.1, -0.6, 0.15, -40, 0, -15), KM(0.06, 0.1, -0.6, 0.15, -40, 0, -15), KM(0.36, 0, 0.03, 0, 4, 0, 0), KM(0.5, 0, -0.008, 0, -1.5, 0, 0), KM(0.6) },
            BladeRoll = { N(0, -360), N(0.34, -12), N(0.6, 0) },
            BladeRollL = { N(0, 360), N(0.06, 360), N(0.4, 12), N(0.6, 0) },
        }, Events = { { 0.05, "Equip" } } }
        -- the right blade cuts (the left one pulls back a little to make room), then the left
        a.Light1 = { Length = 0.42, Tracks = {
            Gun = { K(0), K(0.06, 0.08, 0.05, 0.05, 4, -20, -8), K(0.13, -0.34, 0.02, -0.14, -6, 32, 12, "Out"), K(0.21, -0.39, 0, -0.12, -8, 36, 14), K(0.42) },
            GunL = { KM(0), KM(0.13, 0.04, -0.04, 0.06, 0, 0, 0), KM(0.42) },
        }, Events = { { 0.09, "Swing" } } }
        a.Light2 = { Length = 0.42, Tracks = {
            GunL = { KM(0), KM(0.06, 0.08, 0.05, 0.05, 4, -20, -8), KM(0.13, -0.34, 0.02, -0.14, -6, 32, 12, "Out"), KM(0.21, -0.39, 0, -0.12, -8, 36, 14), KM(0.42) },
            Gun = { K(0), K(0.13, 0.04, -0.04, 0.06, 0, 0, 0), K(0.42) },
        }, Events = { { 0.09, "Swing" } } }
        -- heavy: both blades cross in an X
        a.Heavy = { Length = 0.8, Tracks = {
            Gun = { K(0), K(0.24, 0.08, 0.14, 0.1, 18, -10, -16), K(0.36, -0.26, -0.08, -0.22, -20, 26, 30, "Out"), K(0.5, -0.24, -0.09, -0.2, -22, 24, 32), K(0.8) },
            GunL = { KM(0), KM(0.24, 0.08, 0.14, 0.1, 18, -10, -16), KM(0.36, -0.26, -0.08, -0.22, -20, 26, 30, "Out"), KM(0.5, -0.24, -0.09, -0.2, -22, 24, 32), KM(0.8) },
        }, Events = { { 0.33, "Swing" } } }
        -- inspect: the right blade raised and turned over, then the left, then both shown together and put away
        a.Inspect = { Length = 3.2, Beats = { Raise = 0.45, Flip = 1.45, Settle = 2.95 }, Tracks = {
            Gun = { K(0), K(0.45, -0.14, 0.14, 0.02, 24, -16, -30), K(1.1, -0.15, 0.15, 0.02, 22, -18, -28), K(1.4, -0.04, 0.03, 0, 4, 0, -4),
                K(2.15, -0.1, 0.1, 0.02, 14, -10, -16), K(2.6, -0.1, 0.1, 0.02, 14, -10, -16), K(2.95, 0, -0.01, 0, -2, 0, 2), K(3.2) },
            GunL = { KM(0), KM(0.7, 0, 0, 0), KM(1.15, -0.14, 0.14, 0.02, 24, -16, -30), KM(1.8, -0.15, 0.15, 0.02, 22, -18, -28),
                KM(2.15, -0.1, 0.1, 0.02, 14, -10, -16), KM(2.6, -0.1, 0.1, 0.02, 14, -10, -16), KM(2.95, 0, -0.01, 0, -2, 0, 2), KM(3.2) },
            BladeRoll = { N(0, 0), N(0.5, 18), N(0.75, 200), N(1.05, 204), N(1.35, 360), N(3.2, 360) },
            BladeRollL = { N(0, 0), N(1.2, -18), N(1.45, -200), N(1.75, -204), N(2.05, -360), N(3.2, -360) },
        }, Events = { { 0.45, "Raise" }, { 1.45, "Flip" }, { 2.95, "Settle" } } }
    end
    a.Fire = a.Light1 -- (ViewmodelRig:Fire is never used for melee; kept so nothing errors if it is)
    return a
end
MeleeData.ClassAnims = ClassAnims
MeleeData.CLASS_STYLES = { Knife = true, Karambit = true, Sword = true, Axe = true, Blunt = true, Spear = true, Scythe = true,
    Kunai = true, Balisong = true, Knuckle = true, Dual = true }

-- ==================== animations (ViewmodelRig keyframe format) ====================
-- Channel "Gun" moves the whole melee about the hand, in camera space at the reference FOV.
local function Anims(style: string, long: boolean?)
    if MeleeData.CLASS_STYLES[style] then return ClassAnims(style) end -- (Update 5: the weapon classes' own move sets)
    local a = {}
    a.Equip = { Length = 0.45, Tracks = { Gun = { { 0, CF(0.1, -0.55, 0.25) * ANG(R(-60), R(10), R(-20)) }, { 0.45, CF(), "Out" } } }, Events = { { 0.05, "Equip" } } }
    if style == "Thrust" then
        -- spear: light = quick straight stabs at the crosshair (alternating a little left / right), heavy = draw
        -- back, then a long lunging thrust with a twist
        a.Light1 = { Length = 0.5, Tracks = { Gun = {
            { 0, CF() },
            { 0.07, CF(0.04, -0.02, 0.18) * ANG(R(4), 0, 0) },
            { 0.17, CF(-0.06, 0.04, -0.75) * ANG(R(-4), R(4), 0), "Out" },
            { 0.50, CF() },
        } }, Events = { { 0.12, "Swing" } } }
        a.Light2 = { Length = 0.5, Tracks = { Gun = {
            { 0, CF() },
            { 0.07, CF(-0.03, 0.02, 0.18) * ANG(R(2), 0, 0) },
            { 0.17, CF(-0.16, 0.07, -0.72) * ANG(R(-6), R(9), R(-8)), "Out" },
            { 0.50, CF() },
        } }, Events = { { 0.12, "Swing" } } }
        a.Heavy = { Length = 0.95, Tracks = { Gun = {
            { 0, CF() },
            { 0.32, CF(0.1, 0.06, 0.42) * ANG(R(10), R(-8), R(-20)) },
            { 0.46, CF(-0.12, 0.05, -1.15) * ANG(R(-6), R(6), R(25)), "Out" },
            { 0.95, CF() },
        } }, Events = { { 0.4, "Swing" } } }
    elseif style == "Bash" then
        a.Light1 = { Length = 0.5, Tracks = { Gun = { { 0, CF() }, { 0.08, CF(0.10, 0.02, 0.15) * ANG(0, R(-15), 0) }, { 0.16, CF(-0.15, 0, -0.45) * ANG(0, R(10), 0), "Out" }, { 0.5, CF() } } }, Events = { { 0.1, "Swing" } } }
        a.Light2 = a.Light1
        a.Heavy = { Length = 0.95, Tracks = { Gun = { { 0, CF() }, { 0.30, CF(0.2, 0.05, 0.35) * ANG(0, R(-30), R(-10)) }, { 0.42, CF(-0.25, 0, -0.65) * ANG(0, R(20), R(10)), "Out" }, { 0.95, CF() } } }, Events = { { 0.36, "Swing" } } }
    elseif style == "Reap" then
        -- (the Infernal Scythe, held in BOTH hands across the body, owner 2026-10-04): light = a reaping sweep right ->
        -- left with the blade leading, then back; heavy = lift it overhead and reap down
        a.Light1 = { Length = 0.55, Tracks = { Gun = {
            { 0, CF() },
            { 0.09, CF(0.22, 0.08, 0.08) * ANG(R(4), R(-28), R(-18)) },
            { 0.22, CF(-0.42, -0.06, -0.18) * ANG(R(-14), R(42), R(22)), "Out" },
            { 0.55, CF() },
        } }, Events = { { 0.13, "Swing" } } }
        a.Light2 = { Length = 0.55, Tracks = { Gun = {
            { 0, CF() },
            { 0.09, CF(-0.24, 0.08, 0.06) * ANG(R(4), R(28), R(18)) },
            { 0.22, CF(0.32, -0.08, -0.18) * ANG(R(-14), R(-38), R(-20)), "Out" },
            { 0.55, CF() },
        } }, Events = { { 0.13, "Swing" } } }
        a.Heavy = { Length = 0.95, Tracks = { Gun = {
            { 0, CF() },
            { 0.32, CF(0.04, 0.3, 0.2) * ANG(R(38), R(0), R(-10)) },
            { 0.46, CF(-0.05, -0.3, -0.5) * ANG(R(-68), R(5), R(14)), "Out" },
            { 0.95, CF() },
        } }, Events = { { 0.38, "Swing" } } }
    elseif long then
        -- long upright melees (crowbar, bat, axe): the top only ever tips FORWARD (negative pitch) -- tipping it
        -- back brought the head of the weapon into your face. Light = diagonal sweeps across the screen,
        -- heavy = raise a little, then chop forward and down.
        a.Light1 = { Length = 0.5, Tracks = { Gun = {
            { 0, CF() },
            { 0.08, CF(0.12, 0.10, 0.05) * ANG(R(-5), R(-10), R(-28)) },
            { 0.20, CF(-0.35, -0.15, -0.15) * ANG(R(-55), R(10), R(50)), "Out" },
            { 0.50, CF() },
        } }, Events = { { 0.12, "Swing" } } }
        a.Light2 = { Length = 0.5, Tracks = { Gun = {
            { 0, CF() },
            { 0.08, CF(-0.18, 0.10, 0.0) * ANG(R(-5), R(10), R(30)) },
            { 0.20, CF(0.25, -0.15, -0.15) * ANG(R(-55), R(-10), R(-42)), "Out" },
            { 0.50, CF() },
        } }, Events = { { 0.12, "Swing" } } }
        a.Heavy = { Length = 0.95, Tracks = { Gun = {
            { 0, CF() },
            { 0.30, CF(0.05, 0.12, 0.05) * ANG(R(-5), R(0), R(-18)) },
            { 0.44, CF(-0.10, -0.32, -0.35) * ANG(R(-85), R(5), R(12)), "Out" },
            { 0.95, CF() },
        } }, Events = { { 0.38, "Swing" } } }
    else
        -- light: forehand slash right -> left, then backhand left -> right
        a.Light1 = { Length = 0.5, Tracks = { Gun = {
            { 0, CF() },
            { 0.08, CF(0.30, 0.15, 0.05) * ANG(R(5), R(-25), R(-45)) },
            { 0.20, CF(-0.50, -0.12, -0.20) * ANG(R(-25), R(55), R(70)), "Out" },
            { 0.50, CF() },
        } }, Events = { { 0.11, "Swing" } } }
        a.Light2 = { Length = 0.5, Tracks = { Gun = {
            { 0, CF() },
            { 0.08, CF(-0.35, 0.10, 0.0) * ANG(R(10), R(40), R(55)) },
            { 0.20, CF(0.35, -0.15, -0.20) * ANG(R(-20), R(-45), R(-60)), "Out" },
            { 0.50, CF() },
        } }, Events = { { 0.11, "Swing" } } }
        -- heavy: big overhead chop / lunge
        a.Heavy = { Length = 0.95, Tracks = { Gun = {
            { 0, CF() },
            { 0.30, CF(0.05, 0.35, 0.25) * ANG(R(55), R(-10), R(-15)) },
            { 0.44, CF(-0.10, -0.30, -0.45) * ANG(R(-70), R(10), R(10)), "Out" },
            { 0.95, CF() },
        } }, Events = { { 0.38, "Swing" } } }
    end
    -- inspect: raise it a little, then roll the FOREARM one way and the other to show both faces (ArmRoll turns
    -- the weapon about the shoulder->hand line, so the wrist keeps its natural angle the whole time)
    a.Inspect = { Length = 2.8, Tracks = {
        -- long melees (crowbar, bat, axe) roll less and dip a little so the head stays on screen
        Gun = long and { { 0, CF() }, { 0.35, CF(0.02, -0.08, 0.05) }, { 2.45, CF(0.02, -0.08, 0.05) }, { 2.8, CF() } }
            or { { 0, CF() }, { 0.35, CF(-0.08, 0.10, 0.05) }, { 2.45, CF(-0.08, 0.10, 0.05) }, { 2.8, CF() } },
        ArmRoll = long and { { 0, 0 }, { 0.45, 38 }, { 1.15, 42 }, { 1.65, -35 }, { 2.35, -38 }, { 2.8, 0 } }
            or { { 0, 0 }, { 0.45, 75 }, { 1.15, 80 }, { 1.65, -70 }, { 2.35, -75 }, { 2.8, 0 } },
    }, Events = { { 1.40, "Flip" } } }
    if style == "Reap" then
        -- its own inspect (two hands on the shaft: no forearm roll): lift it and turn the blade toward you, hold it,
        -- then turn it across to show the other face
        a.Inspect = { Length = 2.8, Tracks = { Gun = {
            { 0, CF() },
            { 0.45, CF(-0.05, 0.12, 0.08) * ANG(R(10), R(-40), R(15)) },
            { 1.25, CF(-0.05, 0.15, 0.08) * ANG(R(12), R(-44), R(15)) },
            { 1.70, CF(0.03, 0.10, 0.05) * ANG(R(-8), R(34), R(-12)) },
            { 2.40, CF(0.03, 0.12, 0.05) * ANG(R(-10), R(38), R(-12)) },
            { 2.8, CF() },
        } }, Events = { { 1.45, "Flip" } } }
    end
    a.Fire = a.Light1 -- (ViewmodelRig:Fire is never used for melee; kept so nothing errors if it is)
    return a
end


-- hold defaults per class (a melee's own Rig values win). Blades built flat in X / Y (H.Blade) turn their flat to the camera
-- (FaceCamera). (Update 5) ViewPos = the camera-space spot of the fist's grip point -- the weapon's place on screen -- and
-- PresentDir = the camera-space direction its handle -> tip axis points. Tuned live in play (DevGunLift adds to ViewPos,
-- DevPresent replaces PresentDir): at FOV 70 the knife now sits like the reference -- the fist in the bottom-right corner,
-- the blade pointing in toward ~(62%, 63%) of the screen; at the default FOV 90 the fist is at ~78% / 88%, the tip at
-- ~58% / 60% (the old hold: fist 75%, tip 52% -- "awkwardly in the middle"). Every class moved right the same way.
-- HoldNudge on a set's Rig still shifts its own melee on top.
MeleeData.CLASSES = {
    Knife = { Style = "Knife", GripSpin = 20, HoldAngles = V(0, -5, -26), HoldTurn = V(-4, 70, 6), Scale = 1.05, BladeLen = 0.8,
        ViewPos = V(1.04, -0.76, -0.95), PresentDir = V(-0.46, 0.4, -0.79), FaceCamera = true },
    Karambit = { Style = "Karambit", GripSpin = 20, HoldAngles = V(0, -5, -14), HoldTurn = V(-4, 70, 6), Scale = 1.3, BladeLen = 0.55,
        ViewPos = V(1.0, -0.54, -1.0), PresentDir = V(-0.42, -0.7, -0.58), FaceCamera = true },
    Sword = { Style = "Sword", GripSpin = 20, HoldAngles = V(0, -5, -20), HoldTurn = V(-4, 70, 6), Scale = 0.88, BladeLen = 1.1,
        ViewPos = V(1.0, -0.8, -1.0), PresentDir = V(-0.14, 0.97, -0.2), FaceCamera = true },
    Axe = { Style = "Axe", GripSpin = 55, HoldAngles = V(0, -5, 10), HoldTurn = V(0, 70, 0), BladeLen = 1.1, FaceCamera = true, FaceRoll = 115, -- (owner: the blade points forward and IN toward the crosshair, the back spike out)
        ViewPos = V(1.0, -0.88, -1.05), PresentDir = V(-0.12, 0.96, -0.25) },
    Blunt = { Style = "Blunt", GripSpin = 55, HoldAngles = V(0, -5, 10), HoldTurn = V(0, 70, 0), BladeLen = 1.2,
        ViewPos = V(1.0, -0.88, -1.05), PresentDir = V(-0.12, 0.96, -0.25) },
    Spear = { Style = "Spear", GripSpin = 20, HoldAngles = V(0, -5, -20), HoldTurn = V(0, 70, 0), BladeLen = 2.0, TwoHanded = true, GripLY = -0.9,
        ViewPos = V(0.74, -0.76, -0.95), PresentDir = V(-0.3, 0.25, -0.92) },
    Scythe = { Style = "Scythe", GripSpin = 55, HoldAngles = V(0, -5, 10), HoldTurn = V(0, 70, 0), BladeLen = 1.4,
        ViewPos = V(1.0, -0.88, -1.05), PresentDir = V(-0.12, 0.96, -0.25) },
    -- (Update 5, the skins plan's four new types) KUNAI: forward grip, lying across the lower right toward the middle, ring by the fist
    Kunai = { Style = "Kunai", GripSpin = 20, HoldAngles = V(0, -5, -26), HoldTurn = V(-4, 70, 6), Scale = 1.0, BladeLen = 0.55,
        ViewPos = V(1.04, -0.7, -0.95), PresentDir = V(-0.8, 0.28, -0.53), FaceCamera = true },
    -- BALISONG: the knife hold; its butterfly action = custom channels BaliBlade / BaliB on the set model's parts
    Balisong = { Style = "Balisong", GripSpin = 20, HoldAngles = V(0, -5, -26), HoldTurn = V(-4, 70, 6), Scale = 1.0, BladeLen = 0.65,
        ViewPos = V(1.04, -0.76, -0.95), PresentDir = V(-0.46, 0.4, -0.79), FaceCamera = true },
    -- KNUCKLE: the striking end forward + up out of a fist in a guard (the grip runs across the fist); punches
    Knuckle = { Style = "Knuckle", GripSpin = 20, HoldAngles = V(0, -5, 0), HoldTurn = V(0, 70, 0), Scale = 1.0, BladeLen = 0.45,
        ViewPos = V(0.9, -0.68, -1.05), PresentDir = V(-0.25, 0.42, -0.87) },
    -- DUAL: a blade in each hand (ViewmodelRig def.Dual: the left copy = this hold mirrored; ViewPosL overrides its spot)
    Dual = { Style = "Dual", Dual = true, GripSpin = 20, HoldAngles = V(0, -5, -26), HoldTurn = V(-4, 70, 6), Scale = 0.95, BladeLen = 0.7,
        ViewPos = V(0.98, -0.76, -0.95), PresentDir = V(-0.4, 0.45, -0.8), FaceCamera = true },
}
MeleeData.CLASS_OF_STYLE = { Knife = "Knife", Karambit = "Karambit", Sword = "Sword", Axe = "Axe", Blunt = "Blunt", Spear = "Spear", Scythe = "Scythe",
    Kunai = "Kunai", Balisong = "Balisong", Knuckle = "Knuckle", Dual = "Dual" }

-- ==================== rigs ====================
local function Rig(id: string, builder: string, opts: any): any
    -- (0.93) a Class fills in its hold defaults (the plain knives / axe; set melees merge theirs in SetRig)
    local cls = opts.Class and MeleeData.CLASSES and MeleeData.CLASSES[opts.Class]
    if cls then
        opts = table.clone(opts)
        for k, v in pairs(cls) do if opts[k] == nil then opts[k] = v end end
    end
    local style = opts.Style or "Slash"
    return {
        IsMelee = true,
        MeleeId = id,
        Build = function()
            local m = Instance.new("Model")
            BUILDERS[builder](m, opts)
            -- the rig measures every weapon from a part named Frame; it must be UNROTATED (model space). The
            -- visible handles are cylinders (built lying on their side), so measuring from them turned "up the
            -- handle" into "forward" -- every melee pointed the wrong way and bent the wrist.
            local anchor = Instance.new("Part")
            anchor.Name = "Frame"
            anchor.Size = Vector3.new(0.05, 0.05, 0.05)
            anchor.CFrame = CFrame.identity
            anchor.Transparency = 1
            anchor.Anchored = true
            anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow = false, false, false, false
            anchor.Parent = m
            m.PrimaryPart = anchor
            return m
        end,
        -- zones by part name (any name not listed uses its own name's zone, e.g. Blade2 -> Blade)
        Parts = { Frame = { Zone = "Anchor" }, Grip = { Zone = "Handle" }, Blade = { Zone = "Blade" }, Blade2 = { Zone = "Blade" }, Edge = { Zone = "Edge" }, Guard = { Zone = "Guard" }, Pommel = { Zone = "Pommel" }, Accent = { Zone = "Accent" } },
        Points = {
            -- hammer grip on the handle (palm facing forward-left, fingers around it), like a pistol grip
            -- (opts.GripShift slides the weapon through the hand; +X = forward)
            GripR = CFrame.fromMatrix(V(-0.02, -0.02, 0) - (opts.GripShift or Vector3.zero), V(0.57, 0, -0.82).Unit, Vector3.yAxis, V(0.57, 0, -0.82).Unit:Cross(Vector3.yAxis)),
            -- two-handed melees (opts.TwoHanded): left hand just below the right on the handle, wrapping from the other side
            GripL = opts.TwoHanded and CFrame.fromMatrix(V(-0.02, opts.GripLY or -0.32, 0), V(-0.57, 0, 0.82).Unit, Vector3.yAxis, V(-0.57, 0, 0.82).Unit:Cross(Vector3.yAxis)) or CF(0, -0.3, -0.2),
            Tip = CF(0.05, (opts.BladeLen or 0.75) + 0.35, 0),
        },
        -- default = Counter-Strike knife hold: low right, wrist straight, blade angled forward toward the centre
        Hold = { Position = opts.HoldPos or V(0.66, -0.8, -0.85), Angles = opts.HoldAngles or V(0, -5, -30) }, -- Glock-style hand (natural wrist); blade tipped toward the centre
        OneHanded = not opts.TwoHanded,
        LeftRest = CF(-0.55, -1.6, -0.35), -- left hand rests out of view (camera space)
        RHandShape = "MeleeGrip",
        GripSpin = opts.GripSpin, -- hand turned around the handle for a natural wrist (tuned per melee)
        HoldTurn = opts.HoldTurn, HoldNudge = opts.HoldNudge, -- extra turn (degrees) / shift on top of the block-arms hold
        PresentDir = opts.PresentDir, NoPresent = opts.NoPresent, FaceSpin = opts.FaceSpin, -- (0.58 showcase: ViewmodelRig.MELEE_PRESENT_DIR)
        ViewLift = opts.ViewLift, -- (0.97 VALORANT HOLDS: camera-space offset after the hold)
        ViewPos = opts.ViewPos, -- (Update 5: the class's camera-space grip spot -- the weapon's place on screen)
        Dual = opts.Dual, ViewPosL = opts.ViewPosL, -- (Update 5 DUAL: a mirrored copy in the left fist)
        FaceCamera = opts.FaceCamera, FaceAxis = opts.FaceAxis, FaceFlip = opts.FaceFlip, FaceRoll = opts.FaceRoll, FistWrap = opts.FistWrap, -- (0.93 classes)
        Scale = opts.Scale or 1,
        Anims = Anims(style, (opts.BladeLen or 0.75) >= 1.0),
        RecoilKick = { Back = 0, Up = 0, Pitch = 0, Roll = 0 },
    }
end

MeleeData.Rigs = {
    Melee_Crowbar = Rig("Crowbar", "Crowbar", { BladeLen = 1.2, HoldAngles = V(0, -5, 18), HoldPos = V(0.78, -0.95, -0.95), GripSpin = 55, GripShift = V(0.06, 0, 0) }), -- upright (L4D style): hand low right, hook leaning up-left
    Melee_Kukri = Rig("Kukri", "Knife", { Class = "Knife", Style = "Knife", BladeLen = 0.7, Curve = -22, Blade = Color3.fromRGB(200, 210, 225), Handle = Color3.fromRGB(20, 25, 35) }),
    Melee_BowieKnife = Rig("BowieKnife", "Knife", { Class = "Knife", Style = "Knife", BladeLen = 0.82, Handle = Color3.fromRGB(80, 55, 38), Accent = Color3.fromRGB(200, 170, 90) }),
    Melee_BaseballBat = Rig("BaseballBat", "Bat", { BladeLen = 1.3, Style = "Slash", HoldAngles = V(0, -5, -14), HoldPos = V(0.62, -0.95, -0.9), GripSpin = 55 }), -- upright (L4D style): one hand low, bat leaning up-right off the top
    Melee_FireExtinguisher = Rig("FireExtinguisher", "Extinguisher", { BladeLen = 1.2, Style = "Bash", HoldAngles = V(0, -5, 0), HoldPos = V(0.66, -1.0, -1.1) }),
    Melee_MilitaryAxe = Rig("MilitaryAxe", "Axe", { Class = "Axe", Style = "Axe", BladeLen = 1.0, HoldAngles = V(0, -5, 10), HoldPos = V(0.74, -0.95, -0.95), GripSpin = 55 }),
    Melee_RiotShield = Rig("RiotShield", "Shield", { BladeLen = 1.4, Style = "Bash", HoldAngles = V(0, -15, 0), HoldPos = V(0.35, -0.75, -1.1) }),
    -- skin-only rig: the Seraphim Spear skin turns any melee into this spear (MeleeData.Skins[].RigId)
    Melee_InfernalScythe = Rig("InfernalScythe", "Scythe", { NoPresent = true, BladeLen = 1.7, Style = "Reap", TwoHanded = true, GripLY = 0.9, HoldTurn = V(-41.9, 40.3, 42.4), HoldNudge = V(-0.05, -0.19, 0), HoldAngles = V(-38, -8, -20), HoldPos = V(0.6, -0.95, -1.0), GripSpin = 55, GripShift = V(0, -0.1, 0) }), -- (owner 2026-10-04 reference: the shaft leans up to the top-left; HoldTurn = the old 0,0,98 turned 67 deg about the shaft so the blade reaches forward at the crosshair instead of at your face)
    Melee_SeraphimSpear = Rig("SeraphimSpear", "Spear", { NoPresent = true, BladeLen = 2.6, Style = "Thrust", HoldTurn = V(18, 0, 22), HoldNudge = V(0.03, -0.1, 0), HoldAngles = V(-62, -8, -6), HoldPos = V(0.6, -0.85, -0.6), GripShift = V(0, -0.15, 0) }),
}
-- the bundle melees' own entrances (2026-10-07, owner: melee "animations + positioning"): the spear twirls once about
-- its shaft as it comes up; the scythe swings in from the side with the blade trailing
do
    local sp = MeleeData.Rigs.Melee_SeraphimSpear.Anims
    sp.Equip = { Length = 0.6, Tracks = { Gun = {
        { 0, CF(0.12, -0.6, 0.25) * ANG(R(-50), R(10), R(-20)) },
        { 0.25, CF(0.02, -0.04, 0.06) * ANG(R(-6), R(-160), 0) },
        { 0.45, CF(0, 0.02, 0) * ANG(0, R(-330), 0) },
        { 0.6, CF() * ANG(0, R(-360), 0), "Out" },
    } }, Events = { { 0.05, "Equip" } } }
    local sc = MeleeData.Rigs.Melee_InfernalScythe.Anims
    sc.Equip = { Length = 0.6, Tracks = { Gun = {
        { 0, CF(0.45, -0.4, 0.2) * ANG(R(-30), R(-50), R(-30)) },
        { 0.28, CF(-0.1, 0.06, -0.05) * ANG(R(-6), R(24), R(14)) },
        { 0.42, CF(0.02, -0.02, 0) * ANG(R(4), R(-6), R(-4)) },
        { 0.6, CF(), "Out" },
    } }, Events = { { 0.05, "Equip" } } }
end

-- (state given: a skin with its own model, e.g. the Seraphim Spear, swaps in that rig for every melee)
function MeleeData.RigIdFor(meleeId: string?, state: any?): string
    if state ~= nil then
        local skin = MeleeData.SkinFor(state, meleeId)
        if skin and skin.RigId and MeleeData.Rigs[skin.RigId] then return skin.RigId end
    end
    local id = "Melee_" .. tostring(meleeId or "Knife")
    return MeleeData.Rigs[id] and id or "Melee_Knife"
end

-- ==================== skins (work on every melee) ====================
-- Zone look: { Color, Material?, Reflectance?, Transparency? }; a missing zone keeps the factory look.
-- Source: how it's earned (only "Default" is granted automatically). Price / ProductId = sold in the Cosmetics shop
-- (2026-10-02: nothing ever granted the drop / achievement skins, so they went on sale; ProductId 0 = "Coming soon").
local GOLD = Color3.fromRGB(255, 196, 64)
MeleeData.Skins = {
    Factory = { Name = "Factory", Rarity = "Common", Source = "Default", Desc = "The standard finish.", Zones = {} },
    Gunmetal = { Name = "Gunmetal", Rarity = "Uncommon", Source = "Store", Price = 49, ProductId = 0, Desc = "Brushed dark steel with a bright edge.",
        Zones = { Blade = { Color = Color3.fromRGB(70, 74, 82), Material = METAL }, Edge = { Color = Color3.fromRGB(150, 155, 165), Material = METAL },
            Handle = { Color = Color3.fromRGB(28, 30, 34), Material = FABRIC }, Guard = { Color = Color3.fromRGB(45, 48, 54), Material = METAL } } },
    Crimson = { Name = "Crimson Web", Rarity = "Rare", Source = "Store", Price = 79, ProductId = 0, Desc = "Blood-red steel with a black edge.",
        Zones = { Blade = { Color = Color3.fromRGB(150, 20, 28), Material = METAL, Reflectance = 0.1 }, Edge = { Color = Color3.fromRGB(30, 10, 12), Material = METAL },
            Handle = { Color = Color3.fromRGB(20, 20, 22) }, Accent = { Color = Color3.fromRGB(200, 30, 40), Material = METAL } } },
    Arctic = { Name = "Arctic", Rarity = "Rare", Source = "Store", Price = 79, ProductId = 0, Desc = "Ice blade, frosted glass edge, glowing blue accents.",
        Zones = { Blade = { Color = Color3.fromRGB(225, 240, 255), Material = Enum.Material.Ice }, Edge = { Color = Color3.fromRGB(150, 220, 255), Material = Enum.Material.Glass, Transparency = 0.2 },
            Handle = { Color = Color3.fromRGB(235, 240, 245), Material = FABRIC }, Accent = { Color = Color3.fromRGB(120, 190, 255), Material = Enum.Material.Neon } } },
    NeonEdge = { Name = "Neon Edge", Rarity = "Epic", Source = "Store", Price = 99, ProductId = 0, Desc = "Black steel with a cyan neon edge.",
        Zones = { Blade = { Color = Color3.fromRGB(25, 25, 32), Material = METAL }, Edge = { Color = Color3.fromRGB(0, 230, 255), Material = Enum.Material.Neon },
            Accent = { Color = Color3.fromRGB(0, 230, 255), Material = Enum.Material.Neon }, Handle = { Color = Color3.fromRGB(18, 18, 22) } } },
    Gilded = { Name = "Gilded", Rarity = "Legendary", Source = "Store", Price = 149, ProductId = 0, Desc = "Polished gold, ruby accents.",
        Zones = { Blade = { Color = GOLD, Material = FOIL, Reflectance = 0.25 }, Edge = { Color = Color3.fromRGB(255, 235, 170), Material = FOIL }, Guard = { Color = GOLD, Material = FOIL },
            Pommel = { Color = GOLD, Material = FOIL }, Handle = { Color = Color3.fromRGB(20, 18, 16), Material = Enum.Material.Plastic }, Accent = { Color = Color3.fromRGB(120, 20, 30), Material = Enum.Material.Glass } } },
    Prismatic = { Name = "Prismatic", Rarity = "Mythic", Source = "Store", Price = 199, ProductId = 0, Desc = "Crystal blade with an edge that cycles through every colour.", Animated = "Rainbow",
        Zones = { Blade = { Color = Color3.new(1, 1, 1), Material = Enum.Material.Glass, Reflectance = 0.2 }, Edge = { Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Animated = "Rainbow" },
            Accent = { Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Animated = "Rainbow" }, Handle = { Color = Color3.fromRGB(15, 15, 18) } } },
    -- a model skin: every melee becomes the Seraphim Spear (its own rig: hold, thrusts, wings that spread on inspect)
    Seraphim = { Name = "Seraphim Spear", Rarity = "Mythic", Source = "Store", Price = 499, ProductId = 3716099878, RigId = "Melee_SeraphimSpear", FX = "Seraphim",
        Desc = "Turns your melee into a pearl-and-gold spear. Its wings spread when you inspect it, and every kill ascends in a pillar of light.", Zones = {} },
    -- INFERNAL set: every melee becomes the Infernal Scythe
    Infernal = { Name = "Infernal Scythe", Rarity = "Mythic", Source = "Store", Price = 499, ProductId = 0, RigId = "Melee_InfernalScythe", FX = "Infernal", Set = "Infernal",
        Desc = "Turns your melee into an obsidian scythe with a molten crimson edge and runes that breathe. Bone spikes flare when you inspect it, every swing leaves a hellfire ribbon, and every kill is CLAIMED: the soul is torn free and flies to you.", Zones = {} },
}
-- (owner 2026-10-02: the recolours are retired -- only real model skins are sold; retired ids fall back to Factory)
MeleeData.SkinOrder = { "Factory", "Seraphim", "Infernal" }
-- every SkinSets set's melee (set.Melee = { Build(m, o, H, Part, CYL_Y), Rig = Rig opts, Anims? (a, CF, ANG, R) -> a,
-- Skin = { Name, Price, ProductId, Desc } }): its own model + rig, skin id = the set's kind (e.g. "MeleeSkin:Solaris")
MeleeData.Part, MeleeData.CYL_Y = Part, CYL_Y

-- ==================== MOTION LIBRARY (2026-10-07, owner: "Melee inspect animations need a lot of work, the pullouts too.
-- Every melee skin should have a custom pullout and inspect. Everything needs to be smoother and befit the skin") =====
-- Pullouts (Equip) and inspects built from a few choreographies; every skin gets the pair that fits it (MOTION below).
-- Keys without an ease run on the rig's smooth spline (ViewmodelRig SmoothSample), so they flow through each pose.
-- Rotations step <= ~120 deg between keys (a CFrame lerp takes the short way round). "sig" = the moment the skin's own
-- inspect event fires (its VFX beat: Flip / Close / Circle ...), as a time in seconds.
local Motion = {}
MeleeData.Motion = Motion
function Motion.Equip(kind: string): any
    local k = {
        Draw = { 0.5, { { 0, CF(0.2, -0.7, 0.3) * ANG(R(-70), R(15), R(-30)) }, { 0.22, CF(0.05, -0.08, 0.05) * ANG(R(8), R(-6), R(6)) }, { 0.36, CF(0, 0.02, 0) * ANG(R(-3), 0, R(-2)) }, { 0.5, CF() } } },
        OverShoulder = { 0.55, { { 0, CF(0.35, 0.55, 0.55) * ANG(R(70), R(-20), R(40)) }, { 0.24, CF(0.05, -0.06, -0.12) * ANG(R(-25), R(5), R(-10)) }, { 0.4, CF(0, 0.02, 0.02) * ANG(R(4), 0, 0) }, { 0.55, CF() } } },
        Twirl = { 0.6, { { 0, CF(0.1, -0.6, 0.2) * ANG(R(-50), 0, R(-60)) }, { 0.16, CF(0.02, -0.2, 0.05) * ANG(R(-18), 0, R(-170)) }, { 0.32, CF(-0.02, 0.02, -0.02) * ANG(R(-4), 0, R(-290)) }, { 0.46, CF(0, 0.02, 0) * ANG(R(2), 0, R(-356)) }, { 0.6, CF() } } },
        Flick = { 0.45, { { 0, CF(0.6, -0.3, 0.2) * ANG(0, R(-60), R(-70)) }, { 0.18, CF(-0.05, 0, -0.05) * ANG(0, R(10), R(25)) }, { 0.32, CF(0.02, 0, 0) * ANG(0, R(-3), R(-8)) }, { 0.45, CF() } } },
        Toss = { 0.62, { { 0, CF(0.05, -0.7, 0.1) * ANG(R(-40), 0, 0) }, { 0.2, CF(-0.05, 0.3, -0.1) * ANG(R(10), 0, R(-120)) }, { 0.32, CF(-0.03, 0.36, -0.1) * ANG(R(10), 0, R(-240)) }, { 0.47, CF(0, -0.08, 0) * ANG(R(-6), 0, R(-354)) }, { 0.62, CF() } } },
        Scoop = { 0.62, { { 0, CF(0, -0.6, -0.1) * ANG(R(60), 0, R(-10)) }, { 0.22, CF(0, -0.3, -0.3) * ANG(R(70), 0, 0) }, { 0.38, CF(0, 0.1, -0.1) * ANG(R(-15), 0, 0) }, { 0.5, CF(0, -0.03, 0) * ANG(R(4), 0, 0) }, { 0.62, CF() } } },
        Present = { 0.65, { { 0, CF(-0.2, -0.7, 0.1) * ANG(R(-30), R(20), R(10)) }, { 0.25, CF(-0.25, 0.1, -0.15) * ANG(R(10), R(-30), R(5)) }, { 0.45, CF(-0.2, 0.12, -0.15) * ANG(R(8), R(-32), R(3)) }, { 0.65, CF() } } },
        Bounce = { 0.5, { { 0, CF(0, -0.6, 0.1) * ANG(R(-30), 0, 0) }, { 0.16, CF(0, 0.12, 0) * ANG(R(6), 0, R(8)) }, { 0.27, CF(0, -0.06, 0) * ANG(R(-4), 0, R(-6)) }, { 0.38, CF(0, 0.03, 0) * ANG(0, 0, R(3)) }, { 0.5, CF() } } },
    }
    local d = k[kind] or k.Draw
    return { Length = d[1], Tracks = { Gun = d[2] }, Events = { { 0.05, "Equip" } } }
end
-- inspects: returns the anim + the time of its signature beat
function Motion.Inspect(kind: string): (any, number)
    local k = {
        -- show the flat, drift, turn through the front to the other face, tip it to look down the edge
        Showcase = { 2.9, 1.95, {
            { 0, CF() },
            { 0.5, CF(-0.28, 0.14, 0.02) * ANG(R(6), R(-58), R(-10)) },
            { 1.1, CF(-0.3, 0.16, 0.0) * ANG(R(4), R(-64), R(-6)) },
            { 1.5, CF(-0.24, 0.18, 0.02) * ANG(R(-6), R(-10), R(-4)) },
            { 1.95, CF(-0.18, 0.16, 0.04) * ANG(R(-4), R(40), R(8)) },
            { 2.35, CF(-0.16, 0.08, 0.06) * ANG(R(-28), R(30), R(10)) },
            { 2.9, CF() } } },
        -- baton twirls in front of you: one turn, a pose, one turn back
        Twirl = { 2.9, 1.25, {
            { 0, CF() },
            { 0.35, CF(-0.15, 0.12, -0.05) * ANG(R(-6), R(-20), R(-20)) },
            { 0.6, CF(-0.15, 0.14, -0.05) * ANG(R(-6), R(-20), R(-140)) },
            { 0.85, CF(-0.15, 0.14, -0.05) * ANG(R(-6), R(-20), R(-260)) },
            { 1.1, CF(-0.18, 0.15, -0.05) * ANG(R(-6), R(-24), R(-375)) },
            { 1.25, CF(-0.2, 0.18, -0.05) * ANG(R(-4), R(-35), R(-345)) },
            { 1.75, CF(-0.2, 0.18, -0.05) * ANG(R(-2), R(-38), R(-348)) },
            { 2.0, CF(-0.16, 0.14, -0.05) * ANG(R(-6), R(-20), R(-240)) },
            { 2.25, CF(-0.14, 0.12, -0.05) * ANG(R(-6), R(-18), R(-120)) },
            { 2.5, CF(-0.08, 0.06, -0.02) * ANG(R(-4), R(-8), R(-10)) },
            { 2.9, CF() } } },
        -- a toss up with a spin, the catch, then a look at it
        Toss = { 2.7, 1.2, {
            { 0, CF() },
            { 0.4, CF(-0.08, -0.06, 0) * ANG(R(-10), 0, R(-10)) },
            { 0.72, CF(-0.1, 0.45, -0.15) * ANG(R(10), 0, R(-130)) },
            { 0.95, CF(-0.1, 0.55, -0.15) * ANG(R(10), 0, R(-250)) },
            { 1.2, CF(-0.12, 0.04, -0.05) * ANG(R(-6), R(-20), R(-360)) },
            { 1.35, CF(-0.13, 0.0, -0.05) * ANG(R(-10), R(-22), R(-362)) },
            { 1.8, CF(-0.25, 0.12, 0) * ANG(R(4), R(-55), R(-8)) },
            { 2.2, CF(-0.26, 0.13, 0) * ANG(R(3), R(-58), R(-6)) },
            { 2.7, CF() } } },
        -- figure-eight swings, then presented
        Flourish = { 2.6, 1.4, {
            { 0, CF() },
            { 0.35, CF(0.2, 0.15, -0.1) * ANG(R(-20), R(-30), R(-40)) },
            { 0.7, CF(-0.25, -0.05, -0.15) * ANG(R(-35), R(35), R(45)) },
            { 1.05, CF(0.15, -0.1, -0.12) * ANG(R(-25), R(-25), R(-35)) },
            { 1.4, CF(-0.2, 0.2, 0) * ANG(R(6), R(-50), R(-10)) },
            { 2.0, CF(-0.22, 0.21, 0) * ANG(R(4), R(-54), R(-8)) },
            { 2.6, CF() } } },
        -- hugged in close, a gentle sway, a little squeeze, then held out
        Cradle = { 2.8, 1.3, {
            { 0, CF() },
            { 0.5, CF(-0.35, 0.05, 0.25) * ANG(R(15), R(-40), R(-10)) },
            { 0.9, CF(-0.36, 0.06, 0.25) * ANG(R(15), R(-48), R(-14)) },
            { 1.3, CF(-0.35, 0.01, 0.26) * ANG(R(17), R(-36), R(-6)) },
            { 1.55, CF(-0.35, 0.06, 0.25) * ANG(R(15), R(-44), R(-12)) },
            { 1.8, CF(-0.35, 0.02, 0.26) * ANG(R(16), R(-38), R(-8)) },
            { 2.25, CF(-0.2, 0.12, -0.1) * ANG(R(-5), R(-30), 0) },
            { 2.8, CF() } } },
        -- raised up like a toast, a spin at the top, then pointed out at the crowd
        Perform = { 2.8, 1.4, {
            { 0, CF() },
            { 0.45, CF(-0.1, 0.32, -0.1) * ANG(R(25), R(-10), 0) },
            { 0.8, CF(-0.1, 0.36, -0.1) * ANG(R(25), R(-10), R(-120)) },
            { 1.1, CF(-0.1, 0.38, -0.1) * ANG(R(25), R(-10), R(-240)) },
            { 1.4, CF(-0.1, 0.36, -0.1) * ANG(R(25), R(-10), R(-360)) },
            { 1.8, CF(-0.05, 0.1, -0.3) * ANG(R(-35), R(-5), 0) },
            { 2.3, CF(-0.05, 0.1, -0.31) * ANG(R(-37), R(-6), 0) },
            { 2.8, CF() } } },
    }
    local d = k[kind] or k.Showcase
    return { Length = d[1], Tracks = { Gun = d[3] } }, d[2]
end
-- which pair each skin wears (set kinds; "Default" = the plain melees + skins without their own). Sets missing here keep
-- the pullout / inspect they were built with (the original seven + Starlight's magic circle + Kingyo's leaping fish).
MeleeData.MOTION = {
    Default = { Equip = "Draw", Inspect = "Showcase" },
    Kitsune = { Equip = "Flick", Inspect = "Flourish" },
    Sugar = { Equip = "Twirl", Inspect = "Twirl" },
    Neko = { Equip = "Bounce", Inspect = "Cradle" },
    Origami = { Equip = "Draw", Inspect = "Showcase" },
    Kingyo = { Equip = "Scoop" },
    Cloud = { Equip = "Bounce", Inspect = "Cradle" },
    Gacha = { Equip = "OverShoulder", Inspect = "Toss" },
    Yami = { Equip = "Present", Inspect = "Twirl" },
    Summer = { Equip = "Present", Inspect = "Showcase" },
    Mecha = { Equip = "Flick", Inspect = "Perform" },
    Fairy = { Equip = "Present", Inspect = "Cradle" },
    -- (0.63 beam-gun line)
    Aurora = { Equip = "Draw", Inspect = "Showcase" },
    Horizon = { Equip = "Twirl", Inspect = "Flourish" },
    Comet = { Equip = "Flick", Inspect = "Twirl" },
}
-- give a rig its pullout / inspect from MOTION, keeping the inspect's own events (moved onto the new signature beat;
-- an event in its first 0.4 s, like the war fan snapping shut, stays at the start)
function Motion.Apply(anims: any, key: string)
    local m = MeleeData.MOTION[key]
    if not (m and anims) then return anims end
    if m.Equip then anims.Equip = Motion.Equip(m.Equip) end
    if m.Inspect then
        local old = anims.Inspect
        local new, sig = Motion.Inspect(m.Inspect)
        local ev = {}
        for _, e in ipairs(old and old.Events or {}) do table.insert(ev, { (e[1] < 0.4) and e[1] or sig, e[2] }) end
        table.sort(ev, function(a, b) return a[1] < b[1] end)
        new.Events = ev
        anims.Inspect = new
    end
    return anims
end
-- the plain melees (and every melee wearing the free Factory finish) get the default pair
for _, id in ipairs({ "Melee_Crowbar", "Melee_BaseballBat", "Melee_FireExtinguisher", "Melee_RiotShield" }) do
    local r = MeleeData.Rigs[id]
    if r then r.Anims = Motion.Apply(r.Anims, "Default") end
end
-- a set melee's rig: its Rig.Class fills in the hold + gives the class move set (the set's own inspect events -- its VFX
-- beats -- move onto the class's signature beat); without a class: its own Anims + the MOTION pair, as before
function MeleeData.SetRig(id: string, bname: string, md: any, motionKey: string): any
    local opts = table.clone(md.Rig or {})
    local cls = opts.Class and MeleeData.CLASSES[opts.Class]
    if cls then
        for k, v in pairs(cls) do if opts[k] == nil then opts[k] = v end end
        opts.Style = cls.Style
        -- (melees built flat in X / Y with H.Blade, md.FlatBlade: their flat side turns to the camera)
        if opts.FaceCamera == nil then opts.FaceCamera = md.FlatBlade == true or opts.Class == "Knife" or opts.Class == "Sword" or opts.Class == "Karambit" end
    end
    local rig = Rig(id, bname, opts)
    if cls then
        local oldEv = {}
        if md.Anims then
            local ok, old = pcall(md.Anims, Anims("Slash", false), CF, ANG, R)
            for _, e in ipairs(ok and old and old.Inspect and old.Inspect.Events or {}) do
                if e[2] ~= "Flip" then table.insert(oldEv, e) end
            end
        end
        local ins = rig.Anims.Inspect
        local sig = 1.3
        for _, e in ipairs(ins and ins.Events or {}) do if e[2] == "Flip" then sig = e[1] end end
        for _, e in ipairs(oldEv) do table.insert(ins.Events, { (e[1] < 0.4) and e[1] or sig, e[2] }) end
        if ins then table.sort(ins.Events, function(a, b) return a[1] < b[1] end) end
    else
        if md.Anims then rig.Anims = md.Anims(rig.Anims, CF, ANG, R) or rig.Anims end
        rig.Anims = Motion.Apply(rig.Anims, motionKey)
    end
    -- (Update 5 INSPECTS, docs/INSPECTS.md) a set melee may bring its WHOLE inspect / equip (md.InspectAnim / md.EquipAnim:
    -- an anim, or a function(rig, classAnim) -> anim) and / or timed events on the class one (md.InspectEvents: times in
    -- seconds or beat names "Flip+0.1" -- Raise / Flip / Settle on every class inspect). (skinsB, BESPOKE STILETTO) the
    -- same for the attacks: md.Light1Anim / Light2Anim / HeavyAnim replace the class swing (a set melee with its own move set)
    for _, name in ipairs({ "Inspect", "Equip", "Light1", "Light2", "Heavy" }) do
        local v = md[name .. "Anim"]
        if type(v) == "function" then
            local ok, r = pcall(v, rig, rig.Anims[name])
            v = ok and r or nil
            if not ok then warn("[MeleeData] " .. id .. " " .. name .. "Anim: " .. tostring(r)) end
        end
        if type(v) == "table" then rig.Anims[name] = v end
    end
    if md.InspectEvents and rig.Anims.Inspect then rig.Anims.Inspect = Inspects.WithEvents(rig.Anims.Inspect, md.InspectEvents) end
    return rig
end
for _, set in ipairs(SkinFX.SetOrder or {}) do
    local md = set.Melee
    if md and md.Build then
        local bname = "Set_" .. set.Kind
        BUILDERS[bname] = function(m, o) md.Build(m, o, SkinFX.H, Part, CYL_Y) end
        local rigId = "Melee_" .. set.Kind .. "Set"
        local rig = MeleeData.SetRig(set.Kind .. "Set", bname, md, set.Kind)
        MeleeData.Rigs[rigId] = rig
        local sk = table.clone(md.Skin or {})
        sk.Name = sk.Name or (set.Kind .. " Blade")
        sk.Rarity = sk.Rarity or "Mythic"
        sk.Source = sk.Source or "Store"
        sk.ProductId = sk.ProductId or 0
        sk.RigId, sk.FX, sk.Set, sk.Zones = rigId, set.Kind, set.Kind, sk.Zones or {}
        MeleeData.Skins[set.Kind] = sk
        table.insert(MeleeData.SkinOrder, set.Kind)
    end
end

MeleeData.Rigs.Melee_Knife = MeleeData.SetRig("Knife", "CombatKnife", { Rig = { Class = "Knife", BladeLen = 0.8 }, FlatBlade = true }, "Default")
-- (Update 5, Studio only) a test rig per class that has no melee of its own yet (old placeholder models), so the class
-- holds / move sets can be seen and clip-checked before skins exist: client DevAct "rig:Melee_ClassBlunt" etc.
if game:GetService("RunService"):IsStudio() then
    MeleeData.Rigs.Melee_ClassBlunt = MeleeData.SetRig("ClassBlunt", "Bat", { Rig = { Class = "Blunt", BladeLen = 1.3 } }, "Default")
    MeleeData.Rigs.Melee_ClassSpear = MeleeData.SetRig("ClassSpear", "Spear", { Rig = { Class = "Spear", BladeLen = 2.6, GripShift = Vector3.new(0, -0.15, 0) } }, "Default")
    MeleeData.Rigs.Melee_ClassScythe = MeleeData.SetRig("ClassScythe", "Scythe", { Rig = { Class = "Scythe", BladeLen = 1.7 } }, "Default")
    MeleeData.Rigs.Melee_ClassAxe = MeleeData.SetRig("ClassAxe", "Axe", { Rig = { Class = "Axe", BladeLen = 1.0 } }, "Default")
    MeleeData.Rigs.Melee_ClassKarambit = MeleeData.SetRig("ClassKarambit", "Knife", { Rig = { Class = "Karambit", BladeLen = 0.5, Curve = -40 }, FlatBlade = true }, "Default")
    MeleeData.Rigs.Melee_ClassSword = MeleeData.SetRig("ClassSword", "Knife", { Rig = { Class = "Sword", BladeLen = 1.1 }, FlatBlade = true }, "Default")
    MeleeData.Rigs.Melee_ClassKunai = MeleeData.SetRig("ClassKunai", "Knife", { Rig = { Class = "Kunai", BladeLen = 0.5 }, FlatBlade = true }, "Default")
    MeleeData.Rigs.Melee_ClassBalisong = MeleeData.SetRig("ClassBalisong", "CombatKnife", { Rig = { Class = "Balisong", BladeLen = 0.7 }, FlatBlade = true }, "Default")
    MeleeData.Rigs.Melee_ClassKnuckle = MeleeData.SetRig("ClassKnuckle", "Knife", { Rig = { Class = "Knuckle", BladeLen = 0.4 } }, "Default")
    MeleeData.Rigs.Melee_ClassDual = MeleeData.SetRig("ClassDual", "CombatKnife", { Rig = { Class = "Dual", BladeLen = 0.7 }, FlatBlade = true }, "Default")
end

-- (0.93 COLORWAYS) a set melee in a colourway: its own rig built by the set's recoloured copy (SkinFX.Sets["Tempest#2"]),
-- skin = a clone of the set's skin with RigId "Melee_TempestSet#2" + FX "Tempest#2" (built once, on first use)
MeleeData.Variants = {}
function MeleeData.VariantSkin(kind: string, v: number): any
    local key = kind .. "#" .. v
    local have = MeleeData.Variants[key]
    if have ~= nil then return have or nil end
    local base = MeleeData.Skins[kind]
    local set = base and SkinFX.Sets[key]
    local md = set and set.Melee
    if not (md and md.Build) then MeleeData.Variants[key] = false return nil end
    local bname = "Set_" .. key
    BUILDERS[bname] = function(m, o) md.Build(m, o, SkinFX.H, Part, CYL_Y) end
    local rigId = "Melee_" .. kind .. "Set#" .. v
    local rig = MeleeData.SetRig(kind .. "Set#" .. v, bname, md, kind)
    MeleeData.Rigs[rigId] = rig
    local sk = table.clone(base)
    sk.RigId, sk.FX, sk.Variant = rigId, key, v
    MeleeData.Variants[key] = sk
    return sk
end
function MeleeData.SkinFor(state: any, meleeId: string?): any
    local map = type(state) == "table" and type(state.MeleeSkinFor) == "table" and state.MeleeSkinFor or {}
    local id = map[meleeId or ""] or "Factory"
    if not table.find(MeleeData.SkinOrder, id) then id = "Factory" end
    local sk = MeleeData.Skins[id]
    local cw = SkinFX.Colorways
    if sk and sk.Set and cw and cw.Has(sk.Set) then
        local v = cw.VariantFor(state, sk.Set, "MeleeSkin:" .. id)
        local alt = v > 1 and MeleeData.VariantSkin(sk.Set, v)
        if alt then return alt, id end
    end
    return sk, id
end

function MeleeData.Owns(state: any, skinId: string): boolean
    if skinId == "Factory" then return true end
    return type(state) == "table" and type(state.OwnedMeleeSkins) == "table" and state.OwnedMeleeSkins[skinId] == true
end

return MeleeData
