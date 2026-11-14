--!nocheck
-- ARMOR SETS (owner, 2026-10-02: "add the matching Seraphim armor set ... a big bundle, and within the bundle the option
-- to buy individual pieces ... the same incredibly high quality as the set, with cool effects in third person (nothing
-- crazy / obstructive in first person)").
-- An armor PIECE fills one slot (Head / Chest / Back / Legs). It is built from parts around the character's body
-- (pearl plates, engraved gold, wings, halos, glowing stars) using the SkinFX helpers, so it carries the same animation
-- attributes as the weapon skins: halos spin, wings breathe, seams pulse -- driven on every client by
-- SkinFX.StartWorld (third person). Your own armor is part of your character, which first person hides; its particles
-- are switched off for you in first person too (nothing in your view).
-- Storage: Cosmetics category "Armor", equipped per slot in state.CosmeticsEquipped["Armor/<Slot>"]; bundles (Cosmetics
-- category "Bundle") grant + wear a whole set.
local ArmorFX = {}

local Shared = script.Parent
local SkinFX = require(Shared:WaitForChild("SkinFX"))
local Art = require(Shared:WaitForChild("CosmeticArt"))
local HudThemes = require(Shared:WaitForChild("HudThemes"))

local V, CF, ANG, R = Vector3.new, CFrame.new, CFrame.Angles, math.rad
local C = Color3.fromRGB
local PEARL, IVORY = C(214, 210, 202), C(206, 200, 186)
local GOLD, PALEGOLD, GOLDMETAL = C(255, 205, 96), C(255, 232, 170), C(214, 166, 72)
local DEEP = C(46, 44, 56) -- the dark undersuit between plates

ArmorFX.Slots = { "Head", "Chest", "Back", "Legs" }
ArmorFX.SlotLabel = { Head = "Helm", Chest = "Cuirass", Back = "Wings", Legs = "Greaves" }

-- ===== catalog =====
ArmorFX.Pieces = {
    { Id = "SeraphimCrown", Set = "Seraphim", Slot = "Head", Name = "Seraphim Crown", Rarity = "Mythic", Unlock = "Robux", Price = 399, ProductId = 0,
      Desc = "A gold circlet with a star-cut gem, feathered wings at the temples and a halo that turns slowly above your head." },
    { Id = "SeraphimCuirass", Set = "Seraphim", Slot = "Chest", Name = "Seraphim Cuirass", Rarity = "Mythic", Unlock = "Robux", Price = 499, ProductId = 0,
      Desc = "Pearl breastplate and back plate framed in engraved gold, layered feathered pauldrons, and a star burning in the centre of your chest." },
    { Id = "SeraphimWings", Set = "Seraphim", Slot = "Back", Name = "Seraphim Wings", Rarity = "Mythic", Unlock = "Robux", Price = 699, ProductId = 0,
      Desc = "Great feathered wings with gold spines and glowing edges. They breathe as you move and shed drifting feathers, seen by everyone but you, never in your way." },
    { Id = "SeraphimGreaves", Set = "Seraphim", Slot = "Legs", Name = "Seraphim Greaves", Rarity = "Mythic", Unlock = "Robux", Price = 349, ProductId = 0,
      Desc = "A gold belt with a star clasp and pearl tassets, plated thighs, gold knee guards and engraved shin guards." },
}
ArmorFX.PieceById = {}
for _, p in ipairs(ArmorFX.Pieces) do ArmorFX.PieceById[p.Id] = p end

-- bundles: every piece of a set + its matching cosmetics, cheaper than buying them one by one
ArmorFX.Bundles = {
    -- (2026-10-02: armor retired -- the bundle is the weapons, gloves, sleeves and theme)
    { Id = "SeraphimAscendant", Name = "Seraphim Ascendant Bundle", Rarity = "Mythic", Unlock = "Robux", Price = 1799, ProductId = 3716100063,
      Desc = "The whole heavenly set: the Seraphim M4A1, AK-47 and Spear, Celestial Fury gloves, Seraphim sleeves, the Seraphim Ascendant health bar and UI theme.",
      Contents = { "WeaponSkin:SeraphimM4A1", "WeaponSkin:SeraphimAK47", "MeleeSkin:Seraphim", "Glove:CelestialFury", "Sleeve:Seraphim", "HealthBar:SeraphimAscendant", "HudTheme:Seraphim", "KillEffect:Ascension" },
      Added = { "HealthBar:SeraphimAscendant" } }, -- (Added: pieces put in after launch -- owners of the rest get them on load)
    -- INFERNAL set (2026-10-04): the devil counterpart to the Seraphim set
    { Id = "InfernalPactBundle", Name = "Infernal Pact Bundle", Rarity = "Mythic", Unlock = "Robux", Price = 1999, ProductId = 0, Set = "Infernal",
      Desc = "The whole Infernal set: the Infernal SCAR-L, FAMAS and Scythe, Hellbound Talons and Sleeves, the Infernal Pact health bar and the Infernal Pact UI theme.",
      Contents = { "WeaponSkin:InfernalSCAR", "WeaponSkin:InfernalF2000", "MeleeSkin:Infernal", "Glove:HellboundTalons", "Sleeve:Hellbound", "HealthBar:Infernal", "HudTheme:InfernalPact", "KillEffect:Claimed" } },
}
-- every SkinSets set's bundle (set.Bundle = { Id, Name, Price, ProductId, Desc, Contents }), in release order
for _, set in ipairs(SkinFX.SetOrder or {}) do
    local b = set.Bundle
    if b then
        b.Set = b.Set or set.Kind
        b.Rarity = b.Rarity or "Mythic"
        b.Unlock = b.Unlock or "Robux"
        -- (0.58) the set's own UI theme rides in its bundle; Added = owners of the bundle get it on load
        local th = HudThemes.BySet and HudThemes.BySet[set.Kind]
        if th and not table.find(b.Contents, "HudTheme:" .. th.Id) then
            local ref = "HudTheme:" .. th.Id
            local kill = nil
            for i, c in ipairs(b.Contents) do if string.sub(c, 1, 11) == "KillEffect:" then kill = i end end
            table.insert(b.Contents, kill or (#b.Contents + 1), ref)
            b.Added = b.Added or {}
            table.insert(b.Added, ref)
            b.Desc = string.gsub(b.Desc or "", "%.%s*$", "") .. ", plus the " .. th.Name .. " UI theme."
        end
        table.insert(ArmorFX.Bundles, b)
    end
end
-- (Update 5 SKINS V3: the old bundles are retired -- backup: git tag skins-v2-backup, archive/skins_v2/)
ArmorFX.RETIRED_V2 = { SeraphimAscendant = true, InfernalPactBundle = true }
for i = #ArmorFX.Bundles, 1, -1 do if ArmorFX.RETIRED_V2[ArmorFX.Bundles[i].Id] then table.remove(ArmorFX.Bundles, i) end end
ArmorFX.BundleById = {}
for _, b in ipairs(ArmorFX.Bundles) do ArmorFX.BundleById[b.Id] = b end

function ArmorFX.EquipKey(slot: string): string return "Armor/" .. slot end
-- the equipped piece per slot -> { Head = def, ... }
function ArmorFX.Worn(state: any): { [string]: any }
    local out = {}
    local eq = type(state) == "table" and type(state.CosmeticsEquipped) == "table" and state.CosmeticsEquipped or {}
    for _, slot in ipairs(ArmorFX.Slots) do
        local d = ArmorFX.PieceById[eq[ArmorFX.EquipKey(slot)] or ""]
        if d and d.Slot == slot then out[slot] = d end
    end
    return out
end

-- ===== building =====
-- body = { [partName] = BasePart } (a character or the store mannequin). The pieces are built in world space around
-- the body, then (weld = true) welded to their body part, or (weld = false) left anchored with their rest offset.
-- Returns the list of { Part, Body } it made.
local BUILD = {}

local function Face(cf: CFrame, normal: Vector3): CFrame
    -- a CFrame at cf.Position whose XVector = normal (SkinFX.Star faces along X)
    local n = normal.Unit
    local up = math.abs(n.Y) > 0.9 and cf.LookVector or cf.UpVector
    return CFrame.fromMatrix(cf.Position, n, (up - n * up:Dot(n)).Unit)
end
-- a feather base: -Z runs along dir (the feather), X = its thin axis (right-handed, orthonormal)
local function Basis(pos: Vector3, thin: Vector3, dir: Vector3): CFrame
    local z = -dir.Unit
    local x = (thin - z * thin:Dot(z)).Unit
    return CFrame.fromMatrix(pos, x, z:Cross(x))
end

-- a plated shell around a limb, covering EVERY side (owner 2026-10-02: "the armor doesn't really have a backside, the
-- character is kind of naked"): a pearl shell slightly bigger than the limb + gold rims. y0..y1 = 0 (bottom) .. 1 (top)
-- of the part. Returns the shell's CFrame + height.
local function Shell(m, part: BasePart, y0: number, y1: number, color: Color3, name: string)
    local s, P = part.Size, part.CFrame
    local h = s.Y * (y1 - y0)
    local cf = P * CF(0, s.Y * ((y0 + y1) / 2 - 0.5), 0)
    SkinFX.Deco(m, { Name = name, Size = V(s.X + 0.1, h, s.Z + 0.1), CFrame = cf, Color = color, Reflectance = 0.05 })
    for _, e in ipairs({ h / 2, -h / 2 }) do
        SkinFX.Deco(m, { Name = "Trim", Size = V(s.X + 0.16, 0.06, s.Z + 0.16), CFrame = cf * CF(0, e, 0), Color = GOLDMETAL, Metal = true })
    end
    return cf, h
end

BUILD.SeraphimCrown = function(m, body)
    local head = body.Head
    if not head then return end
    local hs = head.Size
    local H = head.CFrame
    -- gold circlet around the brow + a pearl band under it
    SkinFX.Ring(m, H * CF(0, hs.Y * 0.28, 0) * ANG(0, 0, R(90)), hs.X * 0.6, 0.08, 16, GOLDMETAL, "Circlet", { Metal = true })
    SkinFX.Ring(m, H * CF(0, hs.Y * 0.2, 0) * ANG(0, 0, R(90)), hs.X * 0.58, 0.05, 16, PALEGOLD, "CircletGlow")
    -- star-cut gem over the brow
    SkinFX.Star(m, Face(H * CF(0, hs.Y * 0.3, -hs.Z * 0.62), H.LookVector), 0.32, true)
    -- feathered wings at the temples, sweeping back and up; they breathe
    for _, s in ipairs({ -1, 1 }) do
        local root = (H * CF(s * hs.X * 0.6, hs.Y * 0.22, hs.Z * 0.05)).Position
        for i = 1, 3 do
            local lift = R(18 + i * 16)
            local dir = H:VectorToWorldSpace(V(s * 0.25, math.sin(lift), math.cos(lift))).Unit
            local base = Basis(root, H.RightVector, dir)
            for _, p in ipairs(SkinFX.Feather(m, base, ({ 0.62, 0.5, 0.38 })[i], ({ 0.13, 0.11, 0.09 })[i], nil, i == 1)) do
                SkinFX.Hinge(p, root, H.UpVector, 0, 4 + i)
            end
        end
    end
    -- the halo: two rings turning against each other above the head
    local hc = H * CF(0, hs.Y * 0.5 + 0.55, hs.Z * 0.08) * ANG(R(-8), 0, R(90))
    SkinFX.Ring(m, hc, 0.46, 0.06, 18, PALEGOLD, "Halo", { Spin = 0.8 })
    SkinFX.Ring(m, hc * CF(0.02, 0, 0), 0.38, 0.025, 14, GOLD, "Halo2", { Spin = -1.3 })
end

BUILD.SeraphimCuirass = function(m, body)
    local t = body.UpperTorso
    if not t then return end
    local ts = t.Size
    local T = t.CFrame
    local fz, bz = -(ts.Z / 2 + 0.1), ts.Z / 2 + 0.1
    -- breastplate: pearl plate, gold frame, a bevelled collar
    SkinFX.Deco(m, { Name = "Breast", Size = V(ts.X * 0.74, ts.Y * 0.66, 0.12), CFrame = T * CF(0, ts.Y * 0.06, fz), Color = PEARL, Reflectance = 0.06 })
    for _, e in ipairs({ { V(ts.X * 0.76, 0.06, 0.15), CF(0, ts.Y * 0.39, fz) }, { V(ts.X * 0.76, 0.06, 0.15), CF(0, -ts.Y * 0.27, fz) },
        { V(0.06, ts.Y * 0.66, 0.15), CF(ts.X * 0.37, ts.Y * 0.06, fz) }, { V(0.06, ts.Y * 0.66, 0.15), CF(-ts.X * 0.37, ts.Y * 0.06, fz) } }) do
        SkinFX.Deco(m, { Name = "Trim", Size = e[1], CFrame = T * e[2], Color = GOLDMETAL, Metal = true })
    end
    SkinFX.Deco(m, { Name = "Collar", Wedge = true, Size = V(ts.X * 0.5, 0.18, 0.2), CFrame = T * CF(0, ts.Y * 0.47, fz + 0.04) * ANG(0, R(180), 0), Color = GOLDMETAL, Metal = true })
    -- the star in the chest + glowing seams running down from it
    SkinFX.Star(m, Face(T * CF(0, ts.Y * 0.12, fz - 0.07), T.LookVector), 0.55, true)
    for _, s in ipairs({ -1, 1 }) do
        local seam = SkinFX.Deco(m, { Name = "Seam", Size = V(0.04, ts.Y * 0.36, 0.13), CFrame = T * CF(s * ts.X * 0.18, -ts.Y * 0.1, fz - 0.005) * ANG(0, 0, R(s * 24)), Color = PALEGOLD, Glow = true })
        SkinFX.Pulse(seam, 0, 0.55, 2.2)
        -- engraved chevrons on each side of the breastplate
        for k = 0, 2 do
            SkinFX.Deco(m, { Name = "Chev", Size = V(0.22, 0.03, 0.13), CFrame = T * CF(s * ts.X * 0.27, ts.Y * (0.25 - k * 0.12), fz - 0.004) * ANG(0, 0, R(s * -28)), Color = GOLDMETAL, Metal = true })
        end
    end
    -- back plate: as finished as the front -- framed pearl, a gold spine, engraved chevrons and a glowing sigil
    SkinFX.Deco(m, { Name = "BackPlate", Size = V(ts.X * 0.8, ts.Y * 0.8, 0.12), CFrame = T * CF(0, ts.Y * 0.02, bz), Color = IVORY, Reflectance = 0.05 })
    for _, e in ipairs({ { V(ts.X * 0.82, 0.06, 0.15), CF(0, ts.Y * 0.42, bz) }, { V(ts.X * 0.82, 0.06, 0.15), CF(0, -ts.Y * 0.38, bz) },
        { V(0.06, ts.Y * 0.8, 0.15), CF(ts.X * 0.41, ts.Y * 0.02, bz) }, { V(0.06, ts.Y * 0.8, 0.15), CF(-ts.X * 0.41, ts.Y * 0.02, bz) } }) do
        SkinFX.Deco(m, { Name = "Trim", Size = e[1], CFrame = T * e[2], Color = GOLDMETAL, Metal = true })
    end
    SkinFX.Deco(m, { Name = "Spine", Size = V(0.1, ts.Y * 0.72, 0.16), CFrame = T * CF(0, 0, bz + 0.02), Color = GOLDMETAL, Metal = true })
    SkinFX.Star(m, Face(T * CF(0, ts.Y * 0.18, bz + 0.09), -T.LookVector), 0.42, true)
    for _, s in ipairs({ -1, 1 }) do
        local seam = SkinFX.Deco(m, { Name = "Seam", Size = V(0.04, ts.Y * 0.4, 0.14), CFrame = T * CF(s * ts.X * 0.2, -ts.Y * 0.12, bz + 0.005) * ANG(0, 0, R(-s * 24)), Color = PALEGOLD, Glow = true })
        SkinFX.Pulse(seam, 0.3, 0.55, 2.2)
        for k = 0, 2 do
            SkinFX.Deco(m, { Name = "Chev", Size = V(0.22, 0.03, 0.14), CFrame = T * CF(s * ts.X * 0.29, ts.Y * (0.26 - k * 0.13), bz + 0.004) * ANG(0, 0, R(s * 28)), Color = GOLDMETAL, Metal = true })
        end
        -- side plates close the gap between breast and back
        SkinFX.Deco(m, { Name = "SidePlate", Size = V(0.1, ts.Y * 0.62, ts.Z * 0.86), CFrame = T * CF(s * (ts.X / 2 + 0.05), ts.Y * 0.02, 0), Color = PEARL, Reflectance = 0.05 })
        SkinFX.Deco(m, { Name = "Trim", Size = V(0.12, 0.05, ts.Z * 0.88), CFrame = T * CF(s * (ts.X / 2 + 0.05), -ts.Y * 0.29, 0), Color = GOLDMETAL, Metal = true })
    end
    -- arms: rerebraces on the upper arms, vambraces with gold ridges + a glow line on the forearms (all the way round)
    for _, side in ipairs({ "Left", "Right" }) do
        local ua, la = body[side .. "UpperArm"], body[side .. "LowerArm"]
        if ua then
            local cf, h = Shell(m, ua, 0.3, 0.86, PEARL, "Rerebrace")
            SkinFX.Deco(m, { Name = "Band", Size = V(ua.Size.X + 0.14, 0.05, ua.Size.Z + 0.14), CFrame = cf * CF(0, -h * 0.1, 0), Color = PALEGOLD, Glow = true, Transparency = 0.2 })
        end
        if la then
            local cf, h = Shell(m, la, 0.18, 0.92, IVORY, "Vambrace")
            local lz = la.Size.Z / 2 + 0.07
            for _, z in ipairs({ -lz, lz }) do
                SkinFX.Deco(m, { Name = "Ridge", Size = V(0.06, h * 0.86, 0.06), CFrame = cf * CF(0, 0, z), Color = GOLDMETAL, Metal = true })
            end
            local glow = SkinFX.Deco(m, { Name = "VambraceGlow", Size = V(0.025, h * 0.6, 0.07), CFrame = cf * CF(0, 0, lz + 0.01), Color = PALEGOLD, Glow = true })
            SkinFX.Pulse(glow, 0.15, 0.6, 2.4)
        end
    end
    -- pauldrons: three stacked plates per shoulder with gold edges, a gold boss and a tuft of feathers
    for _, s in ipairs({ -1, 1 }) do
        for k = 0, 2 do
            local cf = T * CF(s * (ts.X / 2 + 0.18 + k * 0.05), ts.Y * 0.5 - k * 0.2, 0) * ANG(0, 0, R(-s * (16 + k * 9)))
            SkinFX.Deco(m, { Name = "Pauldron", Size = V(0.9 - k * 0.08, 0.16, ts.Z * 1.22 - k * 0.06), CFrame = cf, Color = (k == 0) and PEARL or IVORY, Reflectance = 0.06 })
            SkinFX.Deco(m, { Name = "Trim", Size = V(0.92 - k * 0.08, 0.04, ts.Z * 1.24 - k * 0.06), CFrame = cf * CF(0, -0.07, 0), Color = GOLDMETAL, Metal = true })
        end
        SkinFX.Deco(m, { Name = "Boss", Shape = Enum.PartType.Ball, Size = V(0.26, 0.26, 0.26), CFrame = T * CF(s * (ts.X / 2 + 0.26), ts.Y * 0.6, 0), Color = GOLDMETAL, Metal = true })
        local root = (T * CF(s * (ts.X / 2 + 0.55), ts.Y * 0.38, 0)).Position
        for i = 1, 2 do
            local dir = T:VectorToWorldSpace(V(s * 0.85, -0.45 - i * 0.25, 0.1)).Unit
            local base = Basis(root, T.LookVector, dir)
            for _, p in ipairs(SkinFX.Feather(m, base, ({ 0.5, 0.38 })[i], ({ 0.12, 0.1 })[i], nil, i == 1)) do SkinFX.Hinge(p, root, T.LookVector, 0, 3) end
        end
    end
end

BUILD.SeraphimWings = function(m, body)
    local t = body.UpperTorso
    if not t then return end
    local ts = t.Size
    local T = t.CFrame
    local back = T.LookVector * -1
    for _, s in ipairs({ -1, 1 }) do
        local root = (T * CF(s * 0.32, ts.Y * 0.28, ts.Z / 2 + 0.2)).Position
        -- six feathers fanning from up-and-back out to the side; long primaries outside, shorter coverts inside
        for i = 1, 6 do
            local a = R(14 + (i - 1) * 13)
            local dir = (T:VectorToWorldSpace(V(s * math.sin(a), math.cos(a) * 0.95, 0)) + back * 0.42).Unit
            local L = ({ 2.1, 2.3, 2.25, 2.0, 1.7, 1.35 })[i]
            local hgt = ({ 0.34, 0.36, 0.34, 0.3, 0.26, 0.22 })[i]
            -- the feather's broad face looks backwards (its thin axis = the torso's back), its length runs along dir
            local base = Basis(root, back, dir)
            local parts = SkinFX.Feather(m, base, L, hgt, nil, i <= 3)
            for _, p in ipairs(parts) do SkinFX.Hinge(p, root, back, 0, 5 + i * 0.4) end
        end
        -- a gold "shoulder" bar the feathers grow from
        SkinFX.Deco(m, { Name = "WingBar", Size = V(0.12, 0.7, 0.14), CFrame = CFrame.new(root) * T.Rotation * CF(s * 0.12, 0.2, 0) * ANG(0, 0, R(-s * 35)), Color = GOLDMETAL, Metal = true })
    end
    -- drifting feathers (switched off for you in first person)
    local root = SkinFX.Deco(m, { Name = "WingCore", Size = V(0.2, 0.2, 0.2), CFrame = T * CF(0, ts.Y * 0.3, ts.Z / 2 + 0.25), Color = PALEGOLD, Glow = true, Transparency = 0.4 })
    SkinFX.Pulse(root, 0.2, 0.7, 2)
    local att = Instance.new("Attachment"); att.Parent = root
    local pe = Instance.new("ParticleEmitter")
    pe.Name = "ArmorFeathers"
    pe.Texture = Art.Feather
    pe.Color = ColorSequence.new(C(255, 252, 240))
    pe.LightEmission = 0.3; pe.LightInfluence = 0.3
    pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32), NumberSequenceKeypoint.new(1, 0.2) })
    pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(1, 1) })
    pe.Lifetime = NumberRange.new(2, 3)
    pe.Rate = 1.2
    pe.Speed = NumberRange.new(0.5, 1.5)
    pe.SpreadAngle = Vector2.new(70, 70)
    pe.Rotation = NumberRange.new(0, 360); pe.RotSpeed = NumberRange.new(-80, 80)
    pe.Acceleration = V(0, -0.8, 0)
    pe:SetAttribute("SkinFx", true)
    pe:SetAttribute("ArmorFx", true)
    pe.Parent = att
end

BUILD.SeraphimGreaves = function(m, body)
    local lt = body.LowerTorso
    if lt then
        local s3 = lt.Size
        local L = lt.CFrame
        SkinFX.Deco(m, { Name = "Belt", Size = V(s3.X + 0.14, 0.2, s3.Z + 0.14), CFrame = L * CF(0, s3.Y * 0.2, 0), Color = GOLDMETAL, Metal = true })
        SkinFX.Star(m, Face(L * CF(0, s3.Y * 0.2, -(s3.Z / 2 + 0.09)), L.LookVector), 0.3, false, { NoRing = true })
        SkinFX.Deco(m, { Name = "BackClasp", Size = V(0.42, 0.26, 0.1), CFrame = L * CF(0, s3.Y * 0.2, s3.Z / 2 + 0.1), Color = PALEGOLD, Metal = true })
        for _, sx in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                local cf = L * CF(sx * s3.X * 0.25, -s3.Y * 0.4, sz * (s3.Z / 2 + 0.08)) * ANG(R(sz * -6), 0, 0)
                SkinFX.Deco(m, { Name = "Tasset", Size = V(s3.X * 0.42, 0.62, 0.08), CFrame = cf, Color = PEARL, Reflectance = 0.05 })
                SkinFX.Deco(m, { Name = "Trim", Size = V(s3.X * 0.44, 0.05, 0.1), CFrame = cf * CF(0, -0.3, 0), Color = GOLDMETAL, Metal = true })
            end
        end
    end
    for _, side in ipairs({ "Left", "Right" }) do
        local ul, ll, ft = body[side .. "UpperLeg"], body[side .. "LowerLeg"], body[side .. "Foot"]
        if ul then
            local U = ul.CFrame
            local us = ul.Size
            Shell(m, ul, 0.12, 0.94, IVORY, "Cuisse")
            SkinFX.Deco(m, { Name = "Thigh", Size = V(us.X * 0.8, us.Y * 0.62, 0.06), CFrame = U * CF(0, 0.04, -(us.Z / 2 + 0.09)), Color = PEARL, Reflectance = 0.06 })
            SkinFX.Deco(m, { Name = "Knee", Shape = Enum.PartType.Ball, Size = V(0.46, 0.46, 0.3), CFrame = U * CF(0, -us.Y * 0.48, -(us.Z / 2 + 0.07)), Color = GOLDMETAL, Metal = true })
            SkinFX.Deco(m, { Name = "BackRidge", Size = V(0.06, us.Y * 0.66, 0.06), CFrame = U * CF(0, 0.02, us.Z / 2 + 0.08), Color = GOLDMETAL, Metal = true })
        end
        if ll then
            local Lc = ll.CFrame
            local ls = ll.Size
            Shell(m, ll, 0.04, 0.96, PEARL, "Greave")
            SkinFX.Deco(m, { Name = "Ridge", Size = V(0.06, ls.Y * 0.8, 0.06), CFrame = Lc * CF(0, 0, -(ls.Z / 2 + 0.08)), Color = GOLDMETAL, Metal = true })
            SkinFX.Deco(m, { Name = "CalfRidge", Size = V(0.06, ls.Y * 0.8, 0.06), CFrame = Lc * CF(0, 0, ls.Z / 2 + 0.08), Color = GOLDMETAL, Metal = true })
            local glow = SkinFX.Deco(m, { Name = "ShinGlow", Size = V(0.025, ls.Y * 0.6, 0.07), CFrame = Lc * CF(0, 0, -(ls.Z / 2 + 0.11)), Color = PALEGOLD, Glow = true })
            SkinFX.Pulse(glow, 0.05, 0.6, 2.4)
        end
        if ft then
            -- sabatons: a pearl shell over the foot + a gold toe cap
            local F = ft.CFrame
            local fs = ft.Size
            SkinFX.Deco(m, { Name = "Sabaton", Size = V(fs.X + 0.1, fs.Y + 0.08, fs.Z + 0.1), CFrame = F * CF(0, 0.02, 0), Color = PEARL, Reflectance = 0.05 })
            SkinFX.Deco(m, { Name = "ToeCap", Size = V(fs.X + 0.14, fs.Y * 0.7, 0.16), CFrame = F * CF(0, 0, -(fs.Z / 2 + 0.06)), Color = GOLDMETAL, Metal = true })
        end
    end
end

-- which body part a built part belongs to (the closest of the ones its piece was built around)
local SLOT_BODY = { Head = { "Head" }, Chest = { "UpperTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" },
    Back = { "UpperTorso" },
    Legs = { "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" } }

function ArmorFX.Build(def: any, body: { [string]: BasePart }, parent: Instance, weld: boolean): { any }
    local build = def and BUILD[def.Id]
    if not build then return {} end
    local m = Instance.new("Model")
    m.Name = "Piece_" .. def.Id
    build(m, body)
    local out = {}
    local cands = SLOT_BODY[def.Slot] or { "UpperTorso" }
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") then
            local best, bd = nil, math.huge
            for _, n in ipairs(cands) do
                local b = body[n]
                if b then
                    local d = (b.Position - p.Position).Magnitude
                    if d < bd then best, bd = b, d end
                end
            end
            best = best or body.UpperTorso
            p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
            p.Massless = true
            if weld and best then
                p.Anchored = false
                local w = Instance.new("Weld")
                w.Part0 = best; w.Part1 = p; w.C0 = best.CFrame:ToObjectSpace(p.CFrame)
                w.Parent = p
            end
            table.insert(out, { Part = p, Body = best, Rest = best and best.CFrame:ToObjectSpace(p.CFrame) })
        end
    end
    m.Parent = parent
    return out
end

-- dress a body with everything worn (state) -> model (named "WorldArmor") or nil
function ArmorFX.Dress(state: any, body: { [string]: BasePart }, parent: Instance, weld: boolean): Model?
    local worn = ArmorFX.Worn(state)
    if next(worn) == nil then return nil end
    local model = Instance.new("Model")
    model.Name = "WorldArmor"
    for _, slot in ipairs(ArmorFX.Slots) do
        if worn[slot] then ArmorFX.Build(worn[slot], body, model, weld) end
    end
    model.Parent = parent
    return model
end

return ArmorFX
