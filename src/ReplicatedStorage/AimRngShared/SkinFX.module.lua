--!nocheck
-- SKIN FX v2: premium, model-changing weapon skins. Owner (2026-10-02): "the skins are ok but still look very low effort
-- ... a boring recolor, not a high premium skin ... massively improve the visuals, feel, animations and sound effects".
-- The SERAPHIM set: M4A1 + AK-47 (+ the Seraphim Spear melee, built in MeleeData from the helpers below).
--
-- How a skin is drawn (the SAME model for your first-person view and the third-person gun other players see):
--   ViewmodelRig.ModelFor(def, skin) clones the gun, then SkinFX.Dress(model, skin, forView):
--     * skin.Surface = a SurfaceAppearance (palette PBR maps) on the gun's own mesh,
--     * skin.Deco = a builder below: armour plates, engraved trims, feathered wings, a muzzle crown with spinning halos,
--       glowing seams, star emblems, flowing light beams -- parts tagged SkinDeco.
--   Animation ATTRIBUTES on deco parts (driven by ViewmodelRig in first person and by SkinFX.StartWorld for other
--   players' guns, so both views move the same way):
--     HingeFrac / HingeAxis / HingeAngle (+ HingeIdle deg)  wings: breathe at rest, unfold on inspect
--     RotorFrac / RotorAxis / RotorSpeed (rad/s) [/ RotorAmp deg = oscillate instead of spin]   halos, rings
--     PulseMin / PulseMax / PulseSpeed                         glowing seams breathe
--     FireFlash                                                 hidden; flashes on each shot (muzzle star)
--     SweepTo (frac)                                            a light blade that sweeps the gun (equip / inspect)
--     Halo                                                      fades in while inspecting (first person)
--   skin.FX = "Infernal" has its OWN drivers (heat, jaw, eye, souls, ignite) -- see BUILD.InfernalRifle; no shared motion.
--   skin.FX = "Seraphim": the set's moments -- materialise on equip, star flash + halo spin per shot, golden tracers
--   with a starburst on impact, reload chimes, inspect sweep + choir, the ASCENSION kill effect and a kill banner that
--   escalates with your streak; every moment has its own layered sound (SkinFX.Sound, built-in clips + effects until
--   an uploaded pack exists).
local SkinFX = {}

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local Art = require(script.Parent:WaitForChild("CosmeticArt"))

local GOLD = Color3.fromRGB(255, 205, 96)
local PALEGOLD = Color3.fromRGB(255, 232, 170)
local PEARL = Color3.fromRGB(206, 203, 197) -- (brighter whites blew out under warm biome light + exposure)
local GOLDMETAL = Color3.fromRGB(214, 166, 72)
local IVORY = Color3.fromRGB(212, 206, 192)
-- the gun's own mesh is tinted to a cool slate gunmetal so the pearl armour, gold trims and wings read against it
-- (pearl plates on a pearl body was one bright blob -- in warm biomes it blew out to solid yellow)
local BODY_TINT = Color3.fromRGB(112, 114, 128)
SkinFX.Colors = { Gold = GOLD, PaleGold = PALEGOLD, Pearl = PEARL, GoldMetal = GOLDMETAL }
local V, CF, ANG, R = Vector3.new, CFrame.new, CFrame.Angles, math.rad
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

-- ===== catalog: gun skins (Price = placeholder until the owner sets prices; ProductId 0 = "coming soon") =====
SkinFX.GunSkins = {
    { Id = "SeraphimM4A1", Name = "Seraphim M4A1", Gun = "M4A1", Rarity = "Mythic", Price = 399, ProductId = 3716099889,
      Desc = "Pearl armour and engraved gold, with feathered wings along the barrel that breathe at rest and unfold when you inspect. A crown of spinning halos at the muzzle flashes a star with every shot; golden tracers burst into stars, reloads chime, and every kill ASCENDS: wings of light, a pillar from the sky and an escalating kill banner.",
      Surface = "Seraphim_M4A1", Deco = "SeraphimRifle", FX = "Seraphim", Color = GOLD, Tint = BODY_TINT,
      ViewNudge = Vector3.new(0.26, -0.06, 0), -- (first person: further right -- owner 2026-10-02: "it kind of blocks your view")
      Fit = { zc = -0.03, hgX0 = 0.1, hgX1 = 0.8, hgY = 0.12, hgHalf = 0.121, recX0 = -0.45, recX1 = 0.08, recY = 0.05,
              recHalf = 0.078, stockX0 = -1.4, stockX1 = -0.86, stockY = 0.07, stockHalf = 0.064, muzzleX = 1.3, barrelY = 0.12,
              barrelR = 0.022, top = 0.35, hgTop = 0.222 } },
    { Id = "SeraphimAK47", Name = "Seraphim AK-47", Gun = "AK47", Rarity = "Mythic", Price = 399, ProductId = 3716099897,
      Desc = "Ivory armour and engraved gold, with feathered wings along the barrel that breathe at rest and unfold when you inspect. A crown of spinning halos at the muzzle flashes a star with every shot; golden tracers burst into stars, reloads chime, and every kill ASCENDS: wings of light, a pillar from the sky and an escalating kill banner.",
      Surface = "Seraphim_AK47", Deco = "SeraphimRifle", FX = "Seraphim", Color = GOLD, Tint = BODY_TINT,
      Fit = { zc = -0.012, hgX0 = 0.4, hgX1 = 0.82, hgY = 0.19, hgHalf = 0.06, recX0 = -0.6, recX1 = 0.3, recY = 0.12,
              recHalf = 0.058, stockX0 = -1.45, stockX1 = -0.86, stockY = 0.02, stockHalf = 0.043, muzzleX = 1.32, barrelY = 0.165,
              barrelR = 0.02, top = 0.34, hgTop = 0.314 } },
}
-- ===== INFERNAL set (2026-10-04, owner: "devil themed (purple or red), high quality") =====
-- A caged demon that runs on HEAT and SOULS (owner, same day: "each skin set should be completely unique" -- the first
-- version reused every Seraphim motion; none is shared now): it ignites on equip, heats up + vents smoke under
-- sustained fire, snaps its jaw per shot, opens a demon eye on inspect, and stores claimed souls in vials. Hellfire WHIP
-- tracers, claw-mark impacts, the CLAIMED kill (implosion, fissure, chains, the soul flies to your gun) and a seared
-- TALLY kill banner. Sounds: SkinFX.InfernalSounds (custom pack, silent until uploaded).
local OBSIDIAN = Color3.fromRGB(30, 20, 32)
local HELLIRON = Color3.fromRGB(74, 40, 50)
local CRIMSON = Color3.fromRGB(235, 40, 60)
local VIOLET = Color3.fromRGB(160, 70, 255)
local EMBERC = Color3.fromRGB(255, 140, 90)
local HORN = Color3.fromRGB(58, 38, 50)
SkinFX.Colors.Crimson, SkinFX.Colors.Violet, SkinFX.Colors.Ember = CRIMSON, VIOLET, EMBERC
local INFERNAL_TINT = Color3.fromRGB(96, 70, 100) -- (the gun's own surface, multiplied: a dark plum -- lower read as solid black)
-- (SCAR / F2000 wear their own palette maps -- WeaponAssets.SkinSurfaces Infernal_<gun>, tools/make_skin_maps.py --
-- so the whole gun is obsidian + blood lacquer + hell-iron, not a tinted factory gun; barely tinted)
local INFERNAL_BODY = Color3.fromRGB(120, 108, 122) -- (warm biome light + exposure blew a brighter body out to bright red)
local function InfernalDesc(gun: string): string
    return "A caged demon. Drawn charred, its cracks catch fire one by one. Keep firing and it heats up: the cracks go white-hot, its vents swing open and it smokes when you stop. Its fanged maw snaps with every shot, a demon eye opens when you inspect it, and every kill is CLAIMED: the ground splits, chains lash out and the soul is torn free and flies into your gun to burn in its vials."
end
-- (owner 2026-10-04: on the SCAR and F2000, not the Seraphim guns. Fits measured from the Frame meshes'
-- vertices -- EditableMesh, model space -- the same way the Seraphim fits read.)
table.insert(SkinFX.GunSkins, { Id = "InfernalSCAR", Name = "Infernal SCAR-L", Gun = "SCAR", Rarity = "Mythic", Price = 399, ProductId = 0, Set = "Infernal",
    Desc = InfernalDesc("SCAR"), Surface = "Infernal_SCAR", Deco = "InfernalRifle", FX = "Infernal", Color = CRIMSON, BodyTint = INFERNAL_BODY, Tint = INFERNAL_BODY, -- (Tint: ViewmodelRig.ApplyLook re-tints the surface)
    Fit = { zc = 0.028, hgX0 = 0.38, hgX1 = 0.85, hgY = 0.15, hgHalf = 0.097, recX0 = -0.62, recX1 = 0.08, recY = 0.09,
            recHalf = 0.072, stockX0 = -1.75, stockX1 = -1.25, stockY = 0.04, stockHalf = 0.058, muzzleX = 1.72, barrelY = 0.11,
            barrelR = 0.024, top = 0.32, hgTop = 0.30 } })
table.insert(SkinFX.GunSkins, { Id = "InfernalF2000", Name = "Infernal FAMAS", Gun = "F2000", Rarity = "Mythic", Price = 399, ProductId = 0, Set = "Infernal",
    Desc = InfernalDesc("F2000"), Surface = "Infernal_F2000", Deco = "InfernalRifle", FX = "Infernal", Color = CRIMSON, BodyTint = INFERNAL_BODY, Tint = INFERNAL_BODY,
    -- (bullpup: "receiver" = the body over the magazine behind the grip, "stock" = the butt shell)
    Fit = { zc = 0.015, hgX0 = 0.32, hgX1 = 0.92, hgY = 0.14, hgHalf = 0.112, recX0 = -0.55, recX1 = 0.2, recY = 0.1,
            recHalf = 0.091, stockX0 = -1.15, stockX1 = -0.6, stockY = 0.05, stockHalf = 0.089, muzzleX = 1.19, barrelY = 0.16,
            barrelR = 0.022, top = 0.38, hgTop = 0.36 } })
-- custom sound pack (tools/make_sfx.py infernal_*.wav; the owner uploads them). Id 0 = silent -- never a Roblox clip.
SkinFX.InfernalSounds = {
    Fire = { Id = 70940320548647, Volume = 0.55 }, Equip = { Id = 76846539708173, Volume = 0.45 }, MagOut = { Id = 76841407102462, Volume = 0.3 }, MagIn = { Id = 99173316948060, Volume = 0.35 },
    Kill = { Id = 89510626704161, Volume = 0.55 }, Impact = { Id = 126081550457770, Volume = 0.2 }, Swing = { Id = 82887958994124, Volume = 0.4 }, MeleeHit = { Id = 137388589532929, Volume = 0.4 },
    FireGun = { SCAR = { Id = 120856113880274, Volume = 0.9 }, F2000 = { Id = 134687545962319, Volume = 0.9 } },
}
-- SKIN SHOTS v3 (0.49): every skinned gun has its OWN complete shot (tools/make_skin_sfx_v3.py: the gun's recording-based
-- shot transformed by the set's theme) that REPLACES the base shot (owner: "cosmetics seem to have same sound as normal
-- guns if you take the skin on / off"). Infernal / SkinSets packs keep theirs in <pack>.FireGun; Seraphim's are here.
SkinFX.SeraphimFireGun = { M4A1 = { Id = 82602157439676, Volume = 0.9 }, AK47 = { Id = 133612017411853, Volume = 0.9 } } -- (tools/wire_sounds.py)
SkinFX.CurrentKind = nil -- (the FX kind of the skin in your hands; ViewmodelRig sets it -- picks the sound set)
SkinFX.Sets = {} -- kind -> set module (AimRngShared.SkinSets; loaded at the bottom of this file)
SkinFX.SetOrder = {} -- the same sets, in release order (store lists, kill effects, bundles)

SkinFX.GunSkinById = {}
for _, s in ipairs(SkinFX.GunSkins) do SkinFX.GunSkinById[s.Id] = s end

-- the skin on this gun for this player (nil = the factory look)
function SkinFX.EquipKey(gun: string): string return "WeaponSkin/" .. tostring(gun) end
function SkinFX.GunSkinFor(state: any, gun: string?): any
    if not gun or type(state) ~= "table" or type(state.CosmeticsEquipped) ~= "table" then return nil end
    local s = SkinFX.GunSkinById[state.CosmeticsEquipped[SkinFX.EquipKey(gun)] or ""]
    if not (s and s.Gun == gun) then return nil end
    -- (0.93 COLORWAYS) the recoloured copy of the skin when this item wears an owned colourway
    local cw = SkinFX.Colorways
    if cw and s.Set and cw.Has(s.Set) then
        local v = cw.VariantFor(state, s.Set, "WeaponSkin:" .. s.Id)
        local vs = v > 1 and SkinFX.Sets[s.Set .. "#" .. v]
        local alt = vs and vs.SkinById and vs.SkinById[s.Id]
        if alt then return alt end
    end
    return s
end

-- ===== part helpers (model space = gun space: +X barrel, +Y up, Z sideways) =====
-- A Ball part is always a sphere of its SMALLEST size (a 0.01-thick "petal" ball renders as a 0.01 dot). A ball whose
-- size isn't uniform becomes a Block with a Sphere SpecialMesh, i.e. a true ellipsoid that follows the part's size
-- (resizes, ScaleTo, transparency and colour all still work). (2026-10-06: wings / petals / ears of the kawaii sets.)
local function Ellipsoid(p: BasePart, want: Vector3?)
    if p:IsA("Part") and p.Shape == Enum.PartType.Ball then
        local sz = want or p.Size -- (the size asked for: setting Shape = Ball can already have squared it)
        local lo, hi = math.min(sz.X, sz.Y, sz.Z), math.max(sz.X, sz.Y, sz.Z)
        if hi > lo * 1.15 then
            p.Shape = Enum.PartType.Block
            p.Size = sz
            local m = Instance.new("SpecialMesh")
            m.MeshType = Enum.MeshType.Sphere
            m.Parent = p
        end
    end
end
SkinFX.Ellipsoid = Ellipsoid

local function Deco(model: Model, props: any): BasePart
    local p = Instance.new(props.Wedge and "WedgePart" or "Part")
    p.Name = "Deco_" .. (props.Name or "Part")
    p.Size = props.Size
    p.CFrame = props.CFrame
    p.Color = props.Color or PEARL
    p.Material = props.Material or (props.Glow and Enum.Material.Neon) or (props.Metal and Enum.Material.Metal) or Enum.Material.SmoothPlastic
    p.Reflectance = props.Reflectance or (props.Metal and 0.18) or 0
    p.Transparency = props.Transparency or 0
    if props.Shape then p.Shape = props.Shape end
    Ellipsoid(p, props.Size)
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Anchored = true
    p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
    p:SetAttribute("SkinDeco", true)
    if props.Glow then p:SetAttribute("Glow", true) end
    if props.Zone then p:SetAttribute("Zone", props.Zone) end
    p.Parent = model
    return p
end
SkinFX.Deco = Deco

-- a hinged wing: turns by `angle` degrees about `axis` (world) through `pivot` (world) when the rig opens the wings;
-- idle = degrees of gentle breathing at rest. Stored relative to the part so it survives Model:ScaleTo.
local function Hinge(p: BasePart, pivot: Vector3, axis: Vector3, angle: number, idle: number?)
    local loc = p.CFrame:PointToObjectSpace(pivot)
    p:SetAttribute("HingeFrac", loc / p.Size)
    p:SetAttribute("HingeAxis", p.CFrame:VectorToObjectSpace(axis.Unit))
    p:SetAttribute("HingeAngle", angle)
    if idle then p:SetAttribute("HingeIdle", idle) end
end
SkinFX.Hinge = Hinge
-- a rotor: spins about `axis` (world) through `pivot` (world) at `speed` rad/s (or oscillates `amp` degrees)
local function Rotor(p: BasePart, pivot: Vector3, axis: Vector3, speed: number, amp: number?)
    p:SetAttribute("RotorFrac", p.CFrame:PointToObjectSpace(pivot) / p.Size)
    p:SetAttribute("RotorAxis", p.CFrame:VectorToObjectSpace(axis.Unit))
    p:SetAttribute("RotorSpeed", speed)
    if amp then p:SetAttribute("RotorAmp", amp) end
end
SkinFX.Rotor = Rotor
local function Pulse(p: BasePart, lo: number, hi: number, speed: number)
    p:SetAttribute("PulseMin", lo); p:SetAttribute("PulseMax", hi); p:SetAttribute("PulseSpeed", speed)
end
SkinFX.Pulse = Pulse

-- one feather: a wedge (tall at the hinge end, tapering to a point), a gold spine along its base and a glowing edge on
-- the front of the spine. base = hinge-point CFrame whose -Z runs along the feather; returns the parts
local function Feather(model: Model, base: CFrame, len: number, h: number, zone: string?, glow: boolean?): { BasePart }
    local body = Deco(model, { Name = "Feather", Wedge = true, Size = V(0.016, h, len), CFrame = base * CF(0, h / 2, -len / 2),
        Color = PEARL, Reflectance = 0.06, Zone = zone })
    local spine = Deco(model, { Name = "FeatherEdge", Size = V(0.02, 0.014, len * 0.97), CFrame = base * CF(0, 0.005, -len * 0.485),
        Color = GOLDMETAL, Metal = true, Zone = zone })
    local out = { body, spine }
    if glow ~= false then
        local g = Deco(model, { Name = "FeatherGlow", Size = V(0.022, 0.006, len * 0.55), CFrame = base * CF(0, 0.014, -len * 0.7),
            Color = PALEGOLD, Glow = true, Zone = zone })
        Pulse(g, 0, 0.45, 2.6)
        table.insert(out, g)
    end
    return out
end
SkinFX.Feather = Feather

-- a ring in center's YZ plane (its axis = center.XVector), made of n segments; opts.Spin = rad/s about that axis
local function Ring(model: Model, center: CFrame, radius: number, thick: number, n: number, color: Color3, name: string, opts: any?): { BasePart }
    local out = {}
    local chord = 2 * math.pi * radius / n * 1.08
    for i = 0, n - 1 do
        local a = i / n * math.pi * 2
        local p = Deco(model, { Name = name, Size = V(thick, thick, chord), Color = color, Glow = not (opts and opts.Metal), Metal = opts and opts.Metal,
            CFrame = center * ANG(a, 0, 0) * CF(0, radius, 0) })
        if opts and opts.Spin then Rotor(p, center.Position, center.XVector, opts.Spin) end
        table.insert(out, p)
    end
    return out
end
SkinFX.Ring = Ring

-- a four-point gold star facing along `face`'s XVector (the face normal), with a bright core, a slowly turning ring
-- of sparks around it and (sparkle = true) glints
local function Star(model: Model, face: CFrame, size: number, sparkle: boolean, opts: any?)
    local a = Deco(model, { Name = "StarV", Size = V(0.006, size, size * 0.22), CFrame = face, Color = GOLD, Glow = true })
    local b = Deco(model, { Name = "StarH", Size = V(0.006, size * 0.22, size * 0.7), CFrame = face, Color = GOLD, Glow = true })
    local core = Deco(model, { Name = "StarCore", Size = V(0.008, size * 0.3, size * 0.3), CFrame = face * ANG(R(45), 0, 0), Color = Color3.new(1, 1, 1), Glow = true })
    Pulse(core, 0, 0.35, 3.4)
    if not (opts and opts.NoRing) then
        Ring(model, face * CF(0.002, 0, 0), size * 0.62, size * 0.06, 8, PALEGOLD, "StarRing", { Spin = 1.2 })
    end
    if sparkle then
        local att = Instance.new("Attachment"); att.Parent = core
        local pe = Instance.new("ParticleEmitter")
        pe.Name = "SkinSparkle"
        pe.Texture = SPARK
        pe.Color = ColorSequence.new(PALEGOLD, GOLD)
        pe.LightEmission = 1; pe.LightInfluence = 0
        pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, size * 0.4), NumberSequenceKeypoint.new(1, 0) })
        pe.Transparency = NumberSequence.new(0.1, 1)
        pe.Lifetime = NumberRange.new(0.5, 0.9)
        pe.Rate = 3
        pe.Speed = NumberRange.new(0.02, 0.08)
        pe.SpreadAngle = Vector2.new(180, 180)
        pe.LockedToPart = true
        pe:SetAttribute("SkinFx", true)
        pe.Parent = att
    end
    return a, b, core
end
SkinFX.Star = Star

-- a flowing light beam between two model-space points (attachments on `host`, which moves with the gun)
local function FlowBeam(host: BasePart, a: Vector3, b: Vector3, width: number, color: Color3)
    local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
    a0.Name, a1.Name = "SkinBeamA", "SkinBeamB"
    a0.Position = host.CFrame:PointToObjectSpace(a); a1.Position = host.CFrame:PointToObjectSpace(b)
    a0.Parent, a1.Parent = host, host
    local beam = Instance.new("Beam")
    beam.Name = "SkinBeam"
    beam.Attachment0, beam.Attachment1 = a0, a1
    beam.Texture = SPARK
    beam.TextureMode = Enum.TextureMode.Wrap
    beam.TextureLength = 0.12
    beam.TextureSpeed = 0.9
    beam.Color = ColorSequence.new(color)
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.25), NumberSequenceKeypoint.new(0.85, 0.25), NumberSequenceKeypoint.new(1, 1) })
    beam.Width0, beam.Width1 = width, width
    beam.FaceCamera = true
    beam.Segments = 2
    beam:SetAttribute("SkinFx", true)
    beam.Parent = host
    return beam
end
SkinFX.FlowBeam = FlowBeam

-- ===== decoration builders =====
local BUILD = {}

-- rifles (M4A1 / AK-47), fitted by skin.Fit (measured gun surfaces, model space)
BUILD.SeraphimRifle = function(model: Model, frame: BasePart, f: any, forView: boolean)
    local F = frame.CFrame
    local function M(cf) return F * cf end
    local function W(v) return F:PointToWorldSpace(v) end
    local hgLen = f.hgX1 - f.hgX0
    local recLen = f.recX1 - f.recX0
    local recMid = (f.recX0 + f.recX1) / 2
    local hgTop = f.hgTop or (f.hgY + 0.08)
    for _, s in ipairs({ -1, 1 }) do
        local zr = f.zc + s * (f.recHalf + 0.008)
        local faceOut = ANG(0, R(-90 * s), 0) -- a face whose XVector points out of this side
        -- RECEIVER ARMOUR: a pearl plate framed in gold, an engraved chevron feather pattern and a glowing seam
        Deco(model, { Name = "Plate", Size = V(recLen * 0.86, 0.13, 0.012), CFrame = M(CF(recMid, f.recY + 0.005, zr)), Color = IVORY, Reflectance = 0.06 })
        Deco(model, { Name = "Trim", Size = V(recLen * 0.88, 0.013, 0.017), CFrame = M(CF(recMid, f.recY + 0.073, zr)), Color = GOLDMETAL, Metal = true })
        Deco(model, { Name = "Trim", Size = V(recLen * 0.88, 0.013, 0.017), CFrame = M(CF(recMid, f.recY - 0.063, zr)), Color = GOLDMETAL, Metal = true })
        Deco(model, { Name = "Trim", Size = V(0.013, 0.14, 0.017), CFrame = M(CF(f.recX1 - recLen * 0.06, f.recY + 0.005, zr)), Color = GOLDMETAL, Metal = true })
        local seam = Deco(model, { Name = "Seam", Size = V(recLen * 0.5, 0.007, 0.015), CFrame = M(CF(recMid + recLen * 0.14, f.recY + 0.005, zr + s * 0.002)), Color = PALEGOLD, Glow = true })
        Pulse(seam, 0, 0.6, 2.2)
        for k = 0, 2 do
            local x = f.recX0 + recLen * 0.32 + k * 0.055
            Deco(model, { Name = "Chev", Size = V(0.05, 0.008, 0.015), CFrame = M(CF(x, f.recY + 0.034, zr + s * 0.002) * ANG(0, 0, R(32))), Color = GOLDMETAL, Metal = true })
            Deco(model, { Name = "Chev", Size = V(0.05, 0.008, 0.015), CFrame = M(CF(x, f.recY - 0.024, zr + s * 0.002) * ANG(0, 0, R(-32))), Color = GOLDMETAL, Metal = true })
        end
        -- STAR EMBLEM facing out of the side (with its turning ring of sparks)
        Star(model, M(CF(f.recX0 + recLen * 0.14, f.recY + 0.005, zr + s * 0.004) * faceOut), 0.075, forView or s == 1)
        -- HANDGUARD WINGS: four layered feathers sweeping forward along the barrel; breathe at rest, unfold on inspect
        local zSide = f.zc + s * (f.hgHalf + 0.009)
        local hinge = V(f.hgX0 + 0.03, f.hgY + 0.035, zSide)
        local axis = F:VectorToWorldSpace(V(0, -s, 0.8))
        local lens, hs, tilts = { 0.66, 0.56, 0.46, 0.36 }, { 0.075, 0.066, 0.056, 0.046 }, { 16, 8, 1, -6 }
        for i = 1, 4 do
            local L = lens[i] * math.max(0.7, hgLen / 0.7)
            local base = M(CF(hinge + V(0, -(i - 1) * 0.02, s * (i - 1) * 0.005))) * CFrame.fromMatrix(Vector3.zero, V(0, 0, 1), V(0, 1, 0))
                * ANG(R(tilts[i]), 0, 0)
            local pivotW = W(hinge)
            for _, p in ipairs(Feather(model, base, L, hs[i], nil, i <= 2)) do Hinge(p, pivotW, axis, 36 + i * 11, 2.5 + i * 0.6) end
        end
        -- glowing rail along the handguard side + light flowing along it
        local rail = Deco(model, { Name = "Rail", Size = V(hgLen * 0.86, 0.008, 0.012), CFrame = M(CF((f.hgX0 + f.hgX1) / 2, f.hgY - 0.028, f.zc + s * (f.hgHalf + 0.004))), Color = PALEGOLD, Glow = true })
        Pulse(rail, 0.1, 0.55, 1.7)
        Deco(model, { Name = "Trim", Size = V(hgLen * 0.92, 0.01, 0.01), CFrame = M(CF((f.hgX0 + f.hgX1) / 2, f.hgY - 0.042, f.zc + s * (f.hgHalf + 0.004))), Color = GOLDMETAL, Metal = true })
        FlowBeam(frame, W(V(f.hgX0 + 0.02, f.hgY - 0.028, f.zc + s * (f.hgHalf + 0.012))), W(V(f.hgX1 - 0.02, f.hgY - 0.028, f.zc + s * (f.hgHalf + 0.012))), 0.03, PALEGOLD)
        -- STOCK: pearl cheek plates with a gold edge (+ swept stock wings for other players -- in first person the stock
        -- sits right under the camera and they filled the screen)
        local zs = f.zc + s * (f.stockHalf + 0.007)
        local stLen = f.stockX1 - f.stockX0
        if not forView then -- (in first person the stock sits under the camera: a big white slab there)
            Deco(model, { Name = "Plate", Size = V(stLen * 0.7, 0.1, 0.01), CFrame = M(CF((f.stockX0 + f.stockX1) / 2 + stLen * 0.05, f.stockY + 0.02, zs)), Color = IVORY, Reflectance = 0.05 })
        end
        Deco(model, { Name = "Trim", Size = V(stLen * 0.72, 0.011, 0.013), CFrame = M(CF((f.stockX0 + f.stockX1) / 2 + stLen * 0.05, f.stockY + 0.072, zs)), Color = GOLDMETAL, Metal = true })
        if not forView then
            local sh = V(f.stockX1 - 0.02, f.stockY + 0.03, zs)
            for i = 1, 3 do
                local base = M(CF(sh + V(0, -(i - 1) * 0.028, 0))) * CFrame.fromMatrix(Vector3.zero, V(0, 0, -1), V(0, 1, 0)) * ANG(R(-(18 - i * 9)), 0, 0)
                for _, p in ipairs(Feather(model, base, ({ 0.46, 0.36, 0.28 })[i], ({ 0.07, 0.058, 0.046 })[i], nil, i == 1)) do
                    Hinge(p, W(sh), F:VectorToWorldSpace(V(0, s, 0.6)), 20, 3)
                end
            end
        end
    end
    -- ENERGY CHANNEL along the top of the handguard: a groove of light that breathes
    local ch = Deco(model, { Name = "Channel", Size = V(hgLen * 0.8, 0.008, 0.02), CFrame = M(CF((f.hgX0 + f.hgX1) / 2, hgTop + 0.003, f.zc)), Color = PALEGOLD, Glow = true })
    Pulse(ch, 0, 0.5, 2.4)
    Deco(model, { Name = "Trim", Size = V(hgLen * 0.84, 0.006, 0.034), CFrame = M(CF((f.hgX0 + f.hgX1) / 2, hgTop + 0.001, f.zc)), Color = GOLDMETAL, Metal = true })
    -- MUZZLE CROWN: six gold petals around the barrel, a halo spinning about it and an inner ring turning the other way
    local mz = M(CF(f.muzzleX - 0.02, f.barrelY, f.zc))
    for i = 0, 5 do
        local a = i / 6 * math.pi * 2
        Deco(model, { Name = "Petal", Wedge = true, Size = V(0.012, 0.05, 0.11), Color = GOLDMETAL, Metal = true,
            CFrame = mz * ANG(a, 0, 0) * CF(-0.03, f.barrelR + 0.022, 0) * ANG(0, R(90), 0) })
    end
    Ring(model, mz * CF(0.05, 0, 0), f.barrelR + 0.045, 0.012, 10, PALEGOLD, "MuzzleHalo", { Spin = 2.2 })
    Ring(model, mz * CF(0.075, 0, 0), f.barrelR + 0.028, 0.008, 8, GOLD, "MuzzleHalo2", { Spin = -3.4 })
    -- the muzzle STAR: hidden, flashes with every shot (a four-point star + a white core), rolled at random each shot
    local star = M(CF(f.muzzleX + 0.12, f.barrelY, f.zc))
    for _, p in ipairs({
        Deco(model, { Name = "FlashV", Size = V(0.008, 0.42, 0.06), CFrame = star, Color = Color3.fromRGB(255, 240, 190), Glow = true, Transparency = 1 }),
        Deco(model, { Name = "FlashH", Size = V(0.008, 0.06, 0.3), CFrame = star, Color = Color3.fromRGB(255, 240, 190), Glow = true, Transparency = 1 }),
        Deco(model, { Name = "FlashCore", Size = V(0.01, 0.1, 0.1), CFrame = star * ANG(R(45), 0, 0), Color = Color3.new(1, 1, 1), Glow = true, Transparency = 1 }),
    }) do p:SetAttribute("FireFlash", true) end
    -- a light blade that sweeps from the stock to the muzzle (equip / inspect; other players see it shine now and then)
    local sweep = Deco(model, { Name = "Sweep", Size = V(0.025, 0.5, 0.26), CFrame = M(CF(f.stockX0 + 0.1, f.recY + 0.05, f.zc)), Color = PALEGOLD, Glow = true, Transparency = 1 })
    sweep:SetAttribute("SweepTo", sweep.CFrame:PointToObjectSpace(W(V(f.muzzleX + 0.05, f.recY + 0.05, f.zc))) / sweep.Size)
    -- INSPECT HALO above the receiver (first person; fades in while the wings are open): two rings turning apart
    if forView then
        local hc = M(CF(recMid, f.top + 0.24, f.zc)) * ANG(0, 0, R(90))
        for _, p in ipairs(Ring(model, hc, 0.17, 0.014, 14, PALEGOLD, "Halo", { Spin = 1.1 })) do p.Transparency = 1; p:SetAttribute("Halo", true) end
        for _, p in ipairs(Ring(model, hc, 0.12, 0.009, 10, GOLD, "Halo", { Spin = -1.7 })) do p.Transparency = 1; p:SetAttribute("Halo", true) end
    end
    -- drifting feathers off the receiver (very few; SkinFx emitters follow the viewmodel's visibility)
    local att = Instance.new("Attachment")
    att.Position = frame.CFrame:PointToObjectSpace(W(V(recMid, f.recY + 0.1, f.zc)))
    att.Parent = frame
    local pe = Instance.new("ParticleEmitter")
    pe.Name = "SkinFeathers"
    pe.Texture = Art.Feather
    pe.Color = ColorSequence.new(Color3.fromRGB(255, 250, 235))
    pe.LightEmission = 0.3; pe.LightInfluence = 0.2
    pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.07), NumberSequenceKeypoint.new(1, 0.04) })
    pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.15), NumberSequenceKeypoint.new(1, 1) })
    pe.Lifetime = NumberRange.new(1.2, 2)
    pe.Rate = forView and 0.35 or 0.6
    pe.Speed = NumberRange.new(0.05, 0.2)
    pe.Rotation = NumberRange.new(0, 360); pe.RotSpeed = NumberRange.new(-60, 60)
    pe.Acceleration = V(0, -0.25, 0)
    pe.SpreadAngle = Vector2.new(180, 180)
    pe:SetAttribute("SkinFx", true)
    pe.Parent = att
end

-- INFERNAL rifles (SCAR / F2000), fitted by skin.Fit. A caged demon that runs on HEAT and SOULS -- its moments are
-- its own (owner 2026-10-04: "each skin set should be completely unique"; nothing here reuses a Seraphim motion):
--   IGNITE  equip: the gun is drawn charred black; its cracks catch fire one by one, outward from the grip
--   HEAT    sustained fire heats it: the cracks go ember -> white-hot, vents along the handguard swing open, and it
--           smokes from them when you stop
--   JAW     every shot: the maw's lower jaw snaps open and a forked tongue of flame flicks out
--   EYE     inspect: a demon eye on each side opens and darts about, the receiver plates part over a molten heart
--           that beats (ba-dum)
--   SOULS   three caged vials on the handguard: each kill's soul flies into the gun and lights one
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SOULC = Color3.fromRGB(196, 110, 255)
local WHITEHOT = Color3.fromRGB(255, 226, 205)
BUILD.InfernalRifle = function(model: Model, frame: BasePart, f: any, forView: boolean)
    local F = frame.CFrame
    local function M(cf) return F * cf end
    local function W(v) return F:PointToWorldSpace(v) end
    -- (animation attributes; shifts are stored as a fraction of the part's size so they survive Model:ScaleTo)
    local function Shift(p, key, by)
        p:SetAttribute("ShiftTo", p.CFrame:PointToObjectSpace(p.Position + F:VectorToWorldSpace(by)) / p.Size)
        p:SetAttribute("ShiftDrive", key)
    end
    local function Heat(p, cold, hot) p:SetAttribute("HeatCold", cold); p:SetAttribute("HeatHot", hot or 0) end
    local function Show(p, key) p:SetAttribute("ShowDrive", key); p.Transparency = 1 end
    local hgLen = f.hgX1 - f.hgX0
    local recLen = f.recX1 - f.recX0
    local hgTop = f.hgTop or (f.hgY + 0.08)
    local hm = (f.hgX0 + f.hgX1) / 2
    for _, s in ipairs({ -1, 1 }) do
        local zr = f.zc + s * (f.recHalf + 0.008)
        local faceOut = ANG(0, R(-90 * s), 0) -- (X points out of this side)
        -- RECEIVER: a RIBCAGE over a pit with a molten HEART in it. The heart beats; on inspect the ribs spread apart and
        -- it blazes
        local px0, px1 = f.recX0 + recLen * 0.3, f.recX1 - recLen * 0.03
        local pl, pm = px1 - px0, (px0 + px1) / 2
        local ry = f.recY + 0.005
        Deco(model, { Name = "Pit", Size = V(pl, 0.118, 0.008), CFrame = M(CF(pm, ry, zr - s * 0.002)), Color = Color3.fromRGB(16, 6, 12) })
        local hc = M(CF(pm, ry + 0.004, zr + s * 0.001)) * faceOut
        for _, h in ipairs({ { 0.088, CRIMSON, 0 }, { 0.046, WHITEHOT, 0.0015 } }) do
            local p = Deco(model, { Name = "Heart", Shape = Enum.PartType.Cylinder, Size = V(0.004, h[1], h[1]), CFrame = hc * CF(h[3], 0, 0), Color = h[2], Glow = true })
            p:SetAttribute("Beat", true)
        end
        -- veins out of the heart along the pit
        for k, vn in ipairs({ { -1, 0.3, 14 }, { -1, -0.25, -18 }, { 1, 0.2, -10 }, { 1, -0.3, 22 } }) do
            local len = pl * 0.3
            local p = Deco(model, { Name = "Vein", Size = V(len, 0.006, 0.006), CFrame = M(CF(pm + vn[1] * (0.03 + len / 2), ry + vn[2] * 0.06, zr + s * 0.001) * ANG(0, 0, R(vn[3]))), Color = CRIMSON, Glow = true })
            p:SetAttribute("Beat", true)
        end
        -- the ribs: six curved bone ribs (two angled segments each); they spread from the middle on inspect
        for i = 0, 5 do
            local x = px0 + pl * (0.09 + i * 0.164)
            local by = V((x - pm) / pl * 0.05, 0, s * 0.004)
            for _, up in ipairs({ 1, -1 }) do
                local rib = Deco(model, { Name = "Rib", Size = V(0.017, 0.062, 0.012), CFrame = M(CF(x - 0.004, ry + up * 0.029, zr + s * 0.007) * ANG(0, 0, R(up * 14))), Color = HORN, Reflectance = 0.05 })
                Shift(rib, "Eye", by)
            end
        end
        for _, up in ipairs({ 1, -1 }) do
            Deco(model, { Name = "Trim", Size = V(pl * 1.02, 0.012, 0.017), CFrame = M(CF(pm, ry + up * 0.064, zr)), Color = HELLIRON, Metal = true })
        end
        -- the DEMON EYE: a socket at the rear of the receiver, lids shut (a glowing seam) until you inspect
        local er = 0.042
        local ec = M(CF(f.recX0 + recLen * 0.15, f.recY + 0.005, zr + s * 0.004) * faceOut)
        Ring(model, ec, er + 0.007, 0.012, 10, HELLIRON, "Socket", { Metal = true })
        -- (layers, out of the side: a blood-red eye, a burning iris + cat-slit pupil that dart about together, the lids,
        -- and an iron brow + cheek the lids slide up / down under)
        Deco(model, { Name = "EyeBall", Shape = Enum.PartType.Cylinder, Size = V(0.005, er * 2, er * 2), CFrame = ec * CF(0.001, 0, 0), Color = Color3.fromRGB(150, 12, 18), Glow = true })
        local iris = Deco(model, { Name = "Iris", Shape = Enum.PartType.Cylinder, Size = V(0.005, er * 1.2, er * 1.2), CFrame = ec * CF(0.004, 0, 0), Color = Color3.fromRGB(255, 176, 40), Glow = true })
        iris:SetAttribute("LookFrac", 0.27); Pulse(iris, 0, 0.2, 1.3)
        local pupil = Deco(model, { Name = "Pupil", Size = V(0.004, er * 1.1, er * 0.15), CFrame = ec * CF(0.0075, 0, 0), Color = Color3.fromRGB(10, 0, 4) })
        pupil:SetAttribute("LookFrac", 0.295)
        for _, up in ipairs({ 1, -1 }) do
            local lid = Deco(model, { Name = "Lid", Size = V(0.006, er * 1.12, er * 2.3), CFrame = ec * CF(0.012, up * er * 0.56, 0), Color = Color3.fromRGB(44, 26, 36) })
            Shift(lid, "Eye", V(0, up * er * 1.05, 0))
            local seam = Deco(model, { Name = "LidSeam", Size = V(0.008, 0.004, er * 2.1), CFrame = ec * CF(0.013, up * 0.0022, 0), Color = CRIMSON, Glow = true })
            Pulse(seam, 0.1, 0.6, 1.1); Shift(seam, "Eye", V(0, up * er * 1.05, 0))
            Deco(model, { Name = (up > 0) and "Brow" or "Cheek", Size = V(0.008, er * 1.2, er * 2.7), CFrame = ec * CF(0.019, up * er * 1.65, 0), Color = HELLIRON, Metal = true })
        end
        -- HANDGUARD: an obsidian plate holding three caged SOUL VIALS, with heat VENTS above them
        local zSide = f.zc + s * (f.hgHalf + 0.006)
        Deco(model, { Name = "Plate", Size = V(hgLen * 0.9, 0.11, 0.01), CFrame = M(CF(hm, f.hgY, zSide)), Color = Color3.fromRGB(18, 9, 15) })
        Deco(model, { Name = "Trim", Size = V(hgLen * 0.92, 0.01, 0.015), CFrame = M(CF(hm, f.hgY - 0.056, zSide)), Color = HELLIRON, Metal = true })
        for i = 1, 3 do
            local vx = f.hgX0 + hgLen * (0.22 + (i - 1) * 0.25)
            local vc = M(CF(vx, f.hgY - 0.02, zSide + s * 0.014))
            Deco(model, { Name = "Vial", Shape = Enum.PartType.Cylinder, Size = V(0.075, 0.034, 0.034), CFrame = vc, Color = Color3.fromRGB(60, 22, 48), Material = Enum.Material.Glass, Transparency = 0.55, Reflectance = 0.25 })
            for _, e in ipairs({ -1, 1 }) do
                Deco(model, { Name = "VialCap", Shape = Enum.PartType.Cylinder, Size = V(0.012, 0.042, 0.042), CFrame = vc * CF(e * 0.041, 0, 0), Color = HELLIRON, Metal = true })
            end
            local soul = Deco(model, { Name = "Soul", Shape = Enum.PartType.Ball, Size = V(0.03, 0.03, 0.03), CFrame = vc * CF(0, 0, s * 0.008), Color = SOULC, Glow = true, Transparency = 1 })
            soul:SetAttribute("SoulSlot", i)
            local wisp = Deco(model, { Name = "SoulWisp", Size = V(0.05, 0.006, 0.01), CFrame = vc * CF(0.006, 0.002, s * 0.017), Color = Color3.fromRGB(225, 180, 255), Glow = true, Transparency = 1 })
            wisp:SetAttribute("SoulSlot", i)
        end
        for i = 1, 4 do
            local cx = f.hgX0 + hgLen * (0.095 + (i - 1) * 0.25)
            local cf = M(CF(cx, f.hgY - 0.02, zSide + s * 0.006) * ANG(0, 0, R(((i % 2) * 2 - 1) * 64)))
            local c = Deco(model, { Name = "Crack", Size = V(0.05, 0.006, 0.006), CFrame = cf, Color = CRIMSON, Glow = true })
            Heat(c, 0.6, 0)
            local hc2 = Deco(model, { Name = "CrackHot", Size = V(0.04, 0.003, 0.008), CFrame = cf, Color = WHITEHOT, Glow = true })
            Heat(hc2, 1.7, 0)
        end
        -- vents: four slats hinged along their top edge; heat swings them open over glowing slits
        for i = 0, 3 do
            local vx = f.hgX0 + hgLen * (0.16 + i * 0.2)
            local vy = f.hgY + 0.036
            local slit = Deco(model, { Name = "VentGlow", Size = V(0.05, 0.01, 0.004), CFrame = M(CF(vx, vy, zSide + s * 0.004)), Color = Color3.fromRGB(255, 120, 60), Glow = true })
            Heat(slit, 1.2, 0)
            local slat = Deco(model, { Name = "Vent", Size = V(0.056, 0.016, 0.006), CFrame = M(CF(vx, vy, zSide + s * 0.008)), Color = HELLIRON, Metal = true })
            Hinge(slat, W(V(vx, vy + 0.008, zSide + s * 0.008)), F:VectorToWorldSpace(V(-s, 0, 0)), 55)
            slat:SetAttribute("HingeDrive", "Heat")
        end
        local sm = Instance.new("Attachment")
        sm.Position = frame.CFrame:PointToObjectSpace(W(V(hm, f.hgY + 0.045, zSide + s * 0.02)))
        sm.Parent = frame
        local smoke = Instance.new("ParticleEmitter")
        smoke.Name = "SkinHeatSmoke"
        smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
        smoke.Color = ColorSequence.new(Color3.fromRGB(90, 60, 70), Color3.fromRGB(40, 30, 36))
        smoke.LightInfluence = 0.4
        smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(1, 0.22) })
        smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
        smoke.Lifetime = NumberRange.new(0.6, 1.0); smoke.Speed = NumberRange.new(0.15, 0.4); smoke.Acceleration = V(0, 0.9, 0)
        smoke.SpreadAngle = Vector2.new(20, 20); smoke.Rate = 0
        smoke:SetAttribute("SkinFx", true)
        smoke.Parent = sm
        -- STOCK: an obsidian plate with a heat crack (first person: just the trim -- nothing big under the camera)
        local zs = f.zc + s * (f.stockHalf + 0.007)
        local stLen = f.stockX1 - f.stockX0
        local stM = (f.stockX0 + f.stockX1) / 2 + stLen * 0.05
        Deco(model, { Name = "Trim", Size = V(stLen * 0.72, 0.011, 0.013), CFrame = M(CF(stM, f.stockY + 0.072, zs)), Color = HELLIRON, Metal = true })
        if not forView then
            Deco(model, { Name = "Plate", Size = V(stLen * 0.7, 0.1, 0.01), CFrame = M(CF(stM, f.stockY + 0.02, zs)), Color = Color3.fromRGB(18, 9, 15) })
            local st = Deco(model, { Name = "Crack", Size = V(stLen * 0.4, 0.007, 0.012), CFrame = M(CF(stM - stLen * 0.05, f.stockY + 0.02, zs + s * 0.002) * ANG(0, 0, R(12))), Color = CRIMSON, Glow = true })
            Heat(st, 0.6, 0)
        end
        -- a CHAIN slung from under the receiver back toward the stock
        local c0 = V(f.recX0 + 0.02, f.recY - 0.075, zr + s * 0.004)
        local c1 = V(math.max(f.stockX1 - 0.02, f.recX0 - 0.5), f.stockY - 0.03, f.zc + s * (f.stockHalf + 0.01))
        local nL = math.clamp(math.floor((c1 - c0).Magnitude / 0.05), 3, 9)
        local prevP = c0
        for l = 1, nL do
            local t = l / nL
            local p = c0:Lerp(c1, t) - V(0, 0.07 * math.sin(t * math.pi), 0)
            local mid = (prevP + p) / 2
            local link = Deco(model, { Name = "Chain", Size = V(0.012, 0.012, (p - prevP).Magnitude + 0.012), CFrame = CFrame.lookAt(W(mid), W(p)) * ANG(0, 0, (l % 2 == 0) and R(90) or 0), Color = HELLIRON, Metal = true })
            link.Size = V(0.004, 0.016, link.Size.Z)
            prevP = p
        end
        -- HORNS over the receiver: five tapering segments curling back and up; white-hot tips under heat
        -- (first person: smaller and lower -- full-size horns stood up into your view)
        local hs = forView and 0.55 or 1
        local root = V(f.recX1 - recLen * 0.18, f.top - 0.04, f.zc + s * 0.03)
        local prev = root
        for i = 1, 5 do
            local t = i / 5
            local nextP = root + V((-0.04 * i - 0.009 * i * i) * hs, (0.03 * i - 0.0035 * i * i) * hs, s * (0.009 * i) * hs)
            local mid = (prev + nextP) / 2
            local len = (nextP - prev).Magnitude
            local th = (0.04 * (1 - t * 0.75) + 0.007) * math.max(0.7, hs)
            Deco(model, { Name = "Horn", Size = V(th, th, len + 0.01), CFrame = CFrame.lookAt(W(mid), W(nextP)), Color = (i >= 4) and HELLIRON or HORN, Metal = i < 4, Reflectance = 0.1 })
            if i == 5 then
                local tip = Deco(model, { Name = "HornTip", Size = V(th * 0.7, th * 0.7, 0.03), CFrame = CFrame.lookAt(W(nextP), W(nextP + (nextP - prev).Unit)), Color = CRIMSON, Glow = true })
                Heat(tip, 0.45, 0)
            end
            prev = nextP
        end
    end
    -- VERTEBRAE along the top of the handguard (a spine, low so it never stands in your sight line), heat glowing
    -- between them
    for i = 0, 4 do
        local x = f.hgX0 + hgLen * (0.12 + i * 0.18)
        local k = 1 - i * 0.12
        Deco(model, { Name = "Vertebra", Size = V(0.028 * k, 0.02 * k, 0.03 * k), CFrame = M(CF(x, hgTop + 0.01 * k, f.zc)), Color = HORN })
        for _, sz in ipairs({ -1, 1 }) do
            Deco(model, { Name = "Vertebra", Wedge = true, Size = V(0.01, 0.016 * k, 0.03 * k), CFrame = M(CF(x, hgTop + 0.008 * k, f.zc + sz * 0.026 * k) * ANG(0, R(sz * 90), 0)), Color = HORN })
        end
    end
    local ch = Deco(model, { Name = "Channel", Size = V(hgLen * 0.8, 0.006, 0.012), CFrame = M(CF(hm, hgTop + 0.002, f.zc)), Color = CRIMSON, Glow = true })
    Heat(ch, 0.5, 0)
    -- the MAW at the muzzle: an iron collar, a fixed upper jaw and a lower jaw that SNAPS open with every shot,
    -- fangs on both, a throat that glows with heat
    local mz = M(CF(f.muzzleX - 0.02, f.barrelY, f.zc))
    local jr = f.barrelR + 0.028
    Ring(model, mz * CF(-0.035, 0, 0), jr + 0.004, 0.016, 10, HELLIRON, "Collar", { Metal = true })
    local throat = Deco(model, { Name = "Throat", Shape = Enum.PartType.Cylinder, Size = V(0.006, jr * 1.7, jr * 1.7), CFrame = mz * CF(0.004, 0, 0), Color = Color3.fromRGB(255, 90, 50), Glow = true })
    Heat(throat, 0.5, 0)
    local hingeP = (mz * CF(-0.02, -jr, 0)).Position
    local hingeAx = F:VectorToWorldSpace(V(0, 0, -1))
    for _, up in ipairs({ 1, -1 }) do
        local jaw = Deco(model, { Name = "Jaw", Size = V(0.12, 0.016, jr * 2.1), CFrame = mz * CF(0.04, up * (jr + 0.004), 0), Color = OBSIDIAN, Reflectance = 0.02 })
        -- (a burning lining inside the mouth: you see it when the jaw snaps open)
        local lining = Deco(model, { Name = "JawLining", Size = V(0.11, 0.004, jr * 1.7), CFrame = mz * CF(0.04, up * (jr - 0.005), 0), Color = CRIMSON, Glow = true })
        Heat(lining, 0.35, 0)
        if up < 0 then
            for _, p in ipairs({ jaw, lining }) do Hinge(p, hingeP, hingeAx, 30); p:SetAttribute("HingeDrive", "Jaw") end
        end
        for k = -1, 1 do
            local fang = Deco(model, { Name = "Fang", Wedge = true, Size = V(0.01, 0.055 - math.abs(k) * 0.014, 0.026), Color = Color3.fromRGB(226, 208, 204),
                CFrame = mz * CF(0.06, up * (jr - 0.004), k * 0.022) * ANG(0, R(90), 0) * ANG(up > 0 and R(180) or 0, 0, 0) * CF(0, -(0.027 - math.abs(k) * 0.007), 0) })
            if up < 0 then Hinge(fang, hingeP, hingeAx, 30); fang:SetAttribute("HingeDrive", "Jaw") end
        end
    end
    local eyeL = Deco(model, { Name = "MawEye", Size = V(0.012, 0.014, 0.016), CFrame = mz * CF(-0.005, jr + 0.014, 0.026), Color = CRIMSON, Glow = true })
    local eyeR = Deco(model, { Name = "MawEye", Size = V(0.012, 0.014, 0.016), CFrame = mz * CF(-0.005, jr + 0.014, -0.026), Color = CRIMSON, Glow = true })
    Heat(eyeL, 0.4, 0); Heat(eyeR, 0.4, 0)
    -- the TONGUE: hidden; a forked lick of flame out of the maw with every shot
    local tongueC = Color3.fromRGB(255, 110, 120)
    for _, p in ipairs({
        Deco(model, { Name = "Tongue", Size = V(0.24, 0.026, 0.008), CFrame = mz * CF(0.17, 0, 0), Color = tongueC, Glow = true, Transparency = 1 }),
        Deco(model, { Name = "Tongue", Size = V(0.13, 0.018, 0.007), CFrame = mz * CF(0.33, 0.026, 0) * ANG(0, 0, R(24)), Color = tongueC, Glow = true, Transparency = 1 }),
        Deco(model, { Name = "Tongue", Size = V(0.13, 0.018, 0.007), CFrame = mz * CF(0.33, -0.026, 0) * ANG(0, 0, R(-24)), Color = tongueC, Glow = true, Transparency = 1 }),
        Deco(model, { Name = "TongueCore", Shape = Enum.PartType.Ball, Size = V(0.07, 0.07, 0.07), CFrame = mz * CF(0.06, 0, 0), Color = Color3.fromRGB(205, 150, 255), Glow = true, Transparency = 1 }),
    }) do p:SetAttribute("FireFlash", true) end
    -- IGNITE timing: every glowing piece lights in turn, spreading out from the grip (first person, on equip)
    local span = math.max(0.6, f.muzzleX - f.stockX0)
    for _, p in ipairs(model:GetChildren()) do
        if p:IsA("BasePart") and p:GetAttribute("SkinDeco") and p:GetAttribute("Glow") and not (p:GetAttribute("FireFlash") or p:GetAttribute("ShowDrive") or p:GetAttribute("SoulSlot")) then
            local x = F:PointToObjectSpace(p.Position).X
            p:SetAttribute("IgniteAt", 0.08 + 0.6 * math.clamp(math.abs(x - f.recX0) / span, 0, 1))
        end
    end
    -- hellfire licking off the receiver + embers (very few; SkinFx emitters follow the viewmodel's visibility)
    local att = Instance.new("Attachment")
    att.Position = frame.CFrame:PointToObjectSpace(W(V((f.recX0 + f.recX1) / 2, f.recY + 0.08, f.zc)))
    att.Parent = frame
    local fire = Instance.new("ParticleEmitter")
    fire.Name = "SkinHellfire"
    fire.Texture = FIRE
    fire.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 130, 140)), ColorSequenceKeypoint.new(0.5, CRIMSON), ColorSequenceKeypoint.new(1, VIOLET) })
    fire.LightEmission = 0.9; fire.LightInfluence = 0
    fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.06), NumberSequenceKeypoint.new(1, 0) })
    fire.Lifetime = NumberRange.new(0.35, 0.6)
    fire.Rate = forView and 4 or 8
    fire.Speed = NumberRange.new(0.1, 0.3)
    fire.Acceleration = V(0, 0.6, 0)
    fire.SpreadAngle = Vector2.new(30, 30)
    fire.LockedToPart = true
    fire:SetAttribute("SkinFx", true)
    fire.Parent = att
    local em = Instance.new("ParticleEmitter")
    em.Name = "SkinSparkle"
    em.Texture = SPARK
    em.Color = ColorSequence.new(EMBERC, CRIMSON)
    em.LightEmission = 1; em.LightInfluence = 0
    em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.025), NumberSequenceKeypoint.new(1, 0) })
    em.Lifetime = NumberRange.new(0.6, 1.1)
    em.Rate = forView and 1.5 or 3
    em.Speed = NumberRange.new(0.1, 0.35)
    em.Acceleration = V(0, 0.4, 0)
    em.SpreadAngle = Vector2.new(180, 180)
    em:SetAttribute("SkinFx", true)
    em.Parent = att
end

-- Dress a freshly cloned gun model in a skin (surface maps + decorations). forView = the first-person rig.
-- ===== the EXOTIC MARK (0.54): every exotic gun wears a small crystal core on each side of its receiver and a thin
-- glowing seam either side of it, so an exotic reads apart from a normal gun of the same base in any skin.
-- col = the skin's own signature colour (skin.Color / skin.Accent; exotic orange on the factory finish), so the mark
-- belongs to the skin instead of fighting it. It is small, flush with the body and slides along the receiver to the spot
-- the skin's own decorations leave clearest, so it never sits on top of a skin's centrepiece.
local function FrameBox(frame: BasePart, p: BasePart): (Vector3, Vector3)
    local rel = frame.CFrame:ToObjectSpace(p.CFrame)
    local h = p.Size / 2
    local ext = V(
        math.abs(rel.XVector.X) * h.X + math.abs(rel.YVector.X) * h.Y + math.abs(rel.ZVector.X) * h.Z,
        math.abs(rel.XVector.Y) * h.X + math.abs(rel.YVector.Y) * h.Y + math.abs(rel.ZVector.Y) * h.Z,
        math.abs(rel.XVector.Z) * h.X + math.abs(rel.YVector.Z) * h.Y + math.abs(rel.ZVector.Z) * h.Z)
    return rel.Position - ext, rel.Position + ext
end
function SkinFX.ExoticMark(model: Model, col: Color3?)
    local frame = model:FindFirstChild("Frame") :: BasePart
    if not frame then return end
    col = col or Color3.fromRGB(255, 150, 40)
    -- the guns are one body mesh (Frame) + a few moving parts: the receiver's real surface is found by casting rays at
    -- the Frame alone from each side (its box would put the mark out at the widest point, e.g. the M249's ammo box), so
    -- the model sits in the workspace for the measurement
    local decos = {}
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p:GetAttribute("SkinDeco") and p.Transparency < 0.9 then
            local a, b = FrameBox(frame, p)
            table.insert(decos, { a, b })
        end
    end
    local oldParent = model.Parent
    local moved = not model:IsDescendantOf(workspace)
    if moved then model.Parent = workspace end
    local wasQ = frame.CanQuery
    frame.CanQuery = true
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { frame }
    local fs = frame.Size
    local len = fs.X
    local s = math.clamp(len * 0.04, 0.05, 0.1) -- (crystal size: ~4% of the gun's length; owner preferred this to a bigger one)
    local function Side(x: number, y: number, sd: number): number?
        local r = workspace:Raycast(frame.CFrame * V(x, y, sd * (fs.Z + 1)), frame.CFrame:VectorToWorldSpace(V(0, 0, -sd * (fs.Z * 2 + 2))), rp)
        return r and frame.CFrame:PointToObjectSpace(r.Position).Z or nil
    end
    -- how clear a spot is of the skin's own decorations (distance to the nearest one's box)
    local function Clear(pt: Vector3): number
        local c = math.huge
        for _, d in ipairs(decos) do
            local q = pt:Max(d[1]):Min(d[2])
            c = math.min(c, (pt - q).Magnitude)
        end
        return c
    end
    -- candidates over the receiver (25-65% of the length from the stock end, +X = muzzle) at a few heights; a spot must
    -- be flat across the crystal's width; score = room from the skin's decorations, then the receiver's middle, then
    -- higher up (the first-person camera looks down onto the gun)
    local spots = {}
    for _, sd in ipairs({ 1, -1 }) do
        local best, bestScore = nil, -math.huge
        for i = 0, 14 do
            local x = -len / 2 + len * (0.25 + 0.4 * i / 14)
            for _, fy in ipairs({ -0.12, 0, 0.1, 0.2 }) do
                local y = fy * fs.Y
                local z0, z1, z2 = Side(x, y, sd), Side(x - s * 0.6, y, sd), Side(x + s * 0.6, y, sd)
                if z0 and z1 and z2 and math.max(z0, z1, z2) - math.min(z0, z1, z2) < s * 0.35 then
                    local z = (sd > 0) and math.max(z0, z1, z2) or math.min(z0, z1, z2)
                    local score = math.min(Clear(V(x, y, z)), s * 4) - math.abs(i / 14 - 0.5) * s * 1.5 + fy * s * 2
                    if score > bestScore then best, bestScore = V(x, y, z), score end
                end
            end
        end
        if best then spots[sd] = best end
    end
    local shell = col:Lerp(Color3.new(1, 1, 1), 0.2)
    local deep = col:Lerp(Color3.new(0, 0, 0), 0.4)
    for sd, pt in pairs(spots) do
        local x, y, z = pt.X, pt.Y, pt.Z + sd * 0.004
        local at = frame.CFrame * CF(x, y, z) * ANG(0, 0, R(45))
        -- a setting of the skin's own deep tone, a clear crystal shell (a cube on its corner, half sunk in) and a
        -- glowing heart inside it. (No Glass: Glass blacks out the Neon behind it. No reflectance on the shell.)
        Deco(model, { Name = "ExoticSetting", Size = V(s * 1.05, s * 1.05, 0.012), CFrame = at * CF(0, 0, sd * 0.002),
            Color = deep, Metal = true, Zone = "Exotic" })
        local gem = Deco(model, { Name = "ExoticCore", Size = V(s * 0.72, s * 0.72, s * 0.5), CFrame = at * CF(0, 0, sd * s * 0.08),
            Color = shell, Material = Enum.Material.SmoothPlastic, Transparency = 0.4, Zone = "Exotic" })
        gem:SetAttribute("ExoticMark", true)
        local heart = Deco(model, { Name = "ExoticGlow", Size = V(s * 0.36, s * 0.36, s * 0.3), CFrame = at * CF(0, 0, sd * s * 0.08),
            Color = col, Glow = true, Zone = "Exotic" })
        Pulse(heart, 0, 0.4, 2.2)
        -- the seam: a hairline either side of the crystal along the body
        -- (each half measured on its own so it lies on the body, skipped where the surface falls away)
        for _, dir in ipairs({ -1, 1 }) do
            local sl = s * 1.9
            local cx = x + dir * (s * 0.75 + sl / 2)
            local za, zb = Side(cx - sl * 0.4, y, sd), Side(cx + sl * 0.4, y, sd)
            local zs = za and zb and ((sd > 0) and math.max(za, zb) or math.min(za, zb)) + sd * 0.006
            if zs and math.abs(za - zb) < s * 0.5 and math.abs(zs - z) < s * 0.3 then -- (level with the crystal)
                local seam = Deco(model, { Name = "ExoticSeam", Size = V(sl, 0.018, 0.01),
                    CFrame = frame.CFrame * CF(cx, y, zs), Color = col, Glow = true, Zone = "Exotic" })
                Pulse(seam, 0.2, 0.65, 2.2)
            end
        end
    end
    frame.CanQuery = wasQ
    if moved then model.Parent = oldParent end
end

-- ===== CALIBRATION MARK (UPDATE 7 B2): the gun physically shows its calibration -- one glowing notch per claimed tier, cut
-- into the rear of the receiver on the camera's side (-Z) and placed by rays at the Frame like the exotic mark (flat spots
-- only, clear of the skin's own decorations); tier V adds an underline joining them. First person (ViewmodelRig:SetWeapon).
function SkinFX.CalibrationMark(model: Model, tier: number, col: Color3?)
    local frame = model:FindFirstChild("Frame") :: BasePart
    if not frame or (tier or 0) <= 0 then return end
    col = col or Color3.fromRGB(120, 220, 210)
    local oldParent = model.Parent
    local moved = not model:IsDescendantOf(workspace)
    if moved then model.Parent = workspace end
    local wasQ = frame.CanQuery
    frame.CanQuery = true
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { frame }
    local fs = frame.Size
    local len = fs.X
    local s = math.clamp(len * 0.02, 0.03, 0.055)
    local gap = s * 0.7
    local rowLen = gap * (tier - 1)
    local sd = -1
    local function Side(x: number, y: number): number?
        local r = workspace:Raycast(frame.CFrame * V(x, y, sd * (fs.Z + 1)), frame.CFrame:VectorToWorldSpace(V(0, 0, -sd * (fs.Z * 2 + 2))), rp)
        return r and frame.CFrame:PointToObjectSpace(r.Position).Z or nil
    end
    local best, bestScore = nil, -math.huge
    for i = 0, 12 do
        local x0 = -len / 2 + len * (0.4 + 0.14 * i / 12) -- (the receiver, ahead of the stock: the stock sits right under the camera)
        for _, fy in ipairs({ 0.18, 0.08, 0, -0.08 }) do
            local y = fy * fs.Y
            local zs = {}
            local ok = true
            for k = 0, math.max(1, tier - 1) do
                local z = Side(x0 + gap * math.min(k, tier - 1), y)
                if not z then ok = false break end
                table.insert(zs, z)
            end
            if ok then
                local zMin, zMax = math.min(table.unpack(zs)), math.max(table.unpack(zs))
                if zMax - zMin < s * 0.3 then
                    local score = fy * 2 - math.abs(i / 12 - 0.5) * 0.5
                    if score > bestScore then best, bestScore = V(x0, y, zMin), score end
                end
            end
        end
    end
    if best then
        local z = best.Z + sd * 0.006
        for k = 0, tier - 1 do
            local n = Deco(model, { Name = "CalNotch" .. (k + 1), Size = V(0.012, s * 0.8, 0.008), CFrame = frame.CFrame * CF(best.X + gap * k, best.Y, z),
                Color = col, Glow = true, Zone = "Calibration" })
            Pulse(n, 0.15, 0.45, 1.6 + k * 0.15)
        end
        if tier >= 5 then
            Deco(model, { Name = "CalLine", Size = V(rowLen + s * 0.6, 0.01, 0.008), CFrame = frame.CFrame * CF(best.X + rowLen / 2, best.Y - s * 0.62, z),
                Color = col, Glow = true, Zone = "Calibration" })
        end
    end
    frame.CanQuery = wasQ
    if moved then model.Parent = oldParent end
end

-- ===== SKINS V3 (Update 5, docs/SKINS_V3_BUILD.md): resculpted models =====
-- A V3 skin is a whole replacement model built in Blender (tools/skin_v3_blender.py -> skin_v3_paint.py ->
-- skin_v3_import.py): WeaponAssets.SkinModels.<Kind>_<GUN> (guns), WeaponAssets.MeleeModels.<Kind> (set melees),
-- WeaponAssets.ArmsModels.<Kind> (glove / sleeve mesh pieces). Its painted maps are SurfaceAppearances NAMED
-- "<Kind>_<GUN>_<set>"; colourway v of one lives in WeaponAssets.SkinSurfacesV3 as "<that name>_V<v>".
local function WeaponAssets(): Instance?
    return game.ReplicatedStorage:WaitForChild("AimRngShared"):FindFirstChild("WeaponAssets")
end
-- the source model: WeaponAssets.<folder>.<name>, else a direct child WeaponAssets.<name> (older full-model skins)
function SkinFX.ModelSource(folder: string?, name: string?): Instance?
    local wa = name and WeaponAssets()
    if not wa then return nil end
    local f = folder and wa:FindFirstChild(folder)
    return (f and f:FindFirstChild(name)) or wa:FindFirstChild(name)
end
-- put colourway v's maps on every SurfaceAppearance under root (a SurfaceAppearance's maps can only be SET in Studio's
-- Edit mode, so a variant is a pre-built SurfaceAppearance we clone in its place). Renamed "<name>_V<v>" so GearLight's
-- SURFACE_LUM finds the variant's own brightness.
function SkinFX.V3Swap(root: Instance, v: number?)
    if not v or v <= 1 then return end
    local wa = WeaponAssets()
    local lib = wa and wa:FindFirstChild("SkinSurfacesV3")
    if not lib then return end
    for _, sa in ipairs(root:GetDescendants()) do
        if sa:IsA("SurfaceAppearance") then
            local base = string.gsub(sa.Name, "_V%d+$", "")
            local alt = lib:FindFirstChild(base .. "_V" .. v)
            if alt then
                local parent = sa.Parent
                local col = sa.Color
                sa:Destroy()
                local c = alt:Clone()
                c.Color = col
                c.Parent = parent
            end
        end
    end
end
-- clone a V3 model's parts into m (anchored, no collision / queries); v = colourway; recolour = { [GlowRole] = Color3 }
-- for its Neon parts. -> { [part name] = part }
function SkinFX.CloneModel(m: Instance, folder: string, name: string, v: number?, recolour: any?): { [string]: BasePart }
    local src = SkinFX.ModelSource(folder, name)
    local out = {}
    if not src then return out end
    for _, p in ipairs(src:GetChildren()) do
        if p:IsA("BasePart") then
            local c = p:Clone()
            c.Anchored = true
            c.CanCollide, c.CanQuery, c.CanTouch = false, false, false
            if c.Material == Enum.Material.Neon then c.CastShadow = false end
            local role = c:GetAttribute("GlowRole")
            if role and recolour and recolour[role] then c.Color = recolour[role] end
            c.Parent = m
            out[c.Name] = c
        end
    end
    if v and v > 1 then SkinFX.V3Swap(m, v) end
    return out
end

-- SKINS ON THE V2 GUNS (0.97): WeaponAssets.SkinSurfacesV2 holds one SurfaceAppearance per skin per v2 part,
-- "<Surface>|<GUN>|<Part>" (tools/skin_v2_maps.py + skin_v2_apply.py)
function SkinFX.V2Surface(surface: string?, gun: string?, part: string?): SurfaceAppearance?
    if not surface or not gun then return nil end
    local assets = game.ReplicatedStorage:WaitForChild("AimRngShared"):FindFirstChild("WeaponAssets")
    local f = assets and assets:FindFirstChild("SkinSurfacesV2")
    return f and f:FindFirstChild(surface .. "|" .. gun .. "|" .. (part or "Frame")) or nil
end
function SkinFX.Dress(model: Model, skin: any, forView: boolean?)
    if not skin then return end
    local frame = model:FindFirstChild("Frame")
    if skin.V3 then
        -- (SKINS V3) the model already wears its painted maps: a colourway swaps them, and its Neon parts take the skin's
        -- glow colours by GlowRole (1 = skin.Color, 2 = skin.Color2; the set's C3 already mapped them for the colourway)
        if (skin.Variant or 1) > 1 then SkinFX.V3Swap(model, skin.Variant) end
        for _, p in ipairs(model:GetDescendants()) do
            if p:IsA("BasePart") and p.Material == Enum.Material.Neon then
                local role = p:GetAttribute("GlowRole")
                local c = (role == 2 and skin.Color2) or (role == 1 and skin.Color) or nil
                if c then p.Color = c end
            end
        end
        if skin.Deco and BUILD[skin.Deco] and frame then BUILD[skin.Deco](model, frame, skin.Fit or {}, forView == true) end
        return
    end
    local v2 = skin.Surface and SkinFX.V2Surface(skin.Surface, model.Name, "Frame")
    if v2 then
        for _, p in ipairs(model:GetChildren()) do
            local old = p:IsA("BasePart") and p:FindFirstChildOfClass("SurfaceAppearance")
            if old then
                local src = SkinFX.V2Surface(skin.Surface, model.Name, p.Name)
                    or (p:GetAttribute("Follow") and SkinFX.V2Surface(skin.Surface, model.Name, p:GetAttribute("Follow"))) or v2
                old:Destroy()
                local sa = src:Clone()
                sa.Color = skin.BodyTint or Color3.new(1, 1, 1)
                sa.Parent = p
            end
        end
    elseif skin.Surface then
        local assets = game.ReplicatedStorage:WaitForChild("AimRngShared"):FindFirstChild("WeaponAssets")
        local src = assets and assets:FindFirstChild("SkinSurfaces") and assets.SkinSurfaces:FindFirstChild(skin.Surface)
        if src then
            for _, p in ipairs(model:GetDescendants()) do
                if p:IsA("SurfaceAppearance") then
                    local parent = p.Parent
                    p:Destroy()
                    local sa = src:Clone()
                    sa.Color = skin.BodyTint or BODY_TINT
                    sa.Parent = parent
                end
            end
        end
    end
    if not skin.Surface and skin.BodyTint then
        -- (Infernal: no maps of its own -- the gun's own surface, darkened)
        for _, p in ipairs(model:GetDescendants()) do
            if p:IsA("SurfaceAppearance") then p.Color = skin.BodyTint
            elseif p:IsA("BasePart") and not p:GetAttribute("SkinDeco") and p.Transparency < 1 then
                -- (every visible piece of the gun, not just meshes: the AK-47's wood furniture stayed tan)
                p.Color = p.Color:Lerp(skin.BodyTint, 0.85)
            end
        end
    end
    -- (BEAM GUNS v5: an Arcwright gun's one glow -- its Neon "Glow" part on the energy hardware -- takes the skin's energy
    -- colour, so the core / coils / emitter match the skin's beam)
    local glow = model:FindFirstChild("Glow")
    if glow and glow:IsA("BasePart") and glow.Material == Enum.Material.Neon and (skin.BeamColor or skin.Color) then
        glow.Color = skin.BeamColor or skin.Color
    end
    if skin.Deco and BUILD[skin.Deco] and frame then BUILD[skin.Deco](model, frame, skin.Fit or {}, forView == true) end
end

-- ===== the animation attributes (shared by both views) =====
-- Reads a part's animation attributes once: -> anim record or nil. rest = the part's CFrame relative to its frame.
function SkinFX.AnimRecord(p: BasePart, rest: CFrame, size: Vector3): any
    local a = nil
    local function A() a = a or {}; return a end
    local frac, axis, ang = p:GetAttribute("HingeFrac"), p:GetAttribute("HingeAxis"), p:GetAttribute("HingeAngle")
    if typeof(frac) == "Vector3" and typeof(axis) == "Vector3" and ang then
        A().Hinge = { Pivot = (rest * CF(size * frac)).Position, Axis = rest:VectorToWorldSpace(axis).Unit, Angle = R(ang), Idle = R(p:GetAttribute("HingeIdle") or 0), Phase = (rest.Position.X * 7) % 6.28 }
    end
    local rf, ra = p:GetAttribute("RotorFrac"), p:GetAttribute("RotorAxis")
    if typeof(rf) == "Vector3" and typeof(ra) == "Vector3" then
        A().Rotor = { Pivot = (rest * CF(size * rf)).Position, Axis = rest:VectorToWorldSpace(ra).Unit, Speed = p:GetAttribute("RotorSpeed") or 1, Amp = p:GetAttribute("RotorAmp") }
    end
    if p:GetAttribute("PulseMin") then
        A().Pulse = { Lo = p:GetAttribute("PulseMin"), Hi = p:GetAttribute("PulseMax") or 0.5, Speed = p:GetAttribute("PulseSpeed") or 2, Phase = (rest.Position.X * 3) % 6.28 }
    end
    if p:GetAttribute("FireFlash") then A().Flash = { Center = rest.Position } end
    local sw = p:GetAttribute("SweepTo")
    if typeof(sw) == "Vector3" then local to = (rest * CF(size * sw)).Position; A().Sweep = { To = to, Delta = to - rest.Position } end
    if p:GetAttribute("Halo") then A().Halo = true end
    -- (Infernal drivers: st[key] = Heat / Jaw / Eye / Souls / SinceEquip -- see BUILD.InfernalRifle)
    local hd = p:GetAttribute("HingeDrive")
    if hd and a and a.Hinge then a.Hinge.Drive = hd end
    local sh = p:GetAttribute("ShiftTo")
    if typeof(sh) == "Vector3" then A().Shift = { Delta = (rest * CF(size * sh)).Position - rest.Position, Drive = p:GetAttribute("ShiftDrive") or "Eye" } end
    if p:GetAttribute("ShowDrive") then A().Show = { Drive = p:GetAttribute("ShowDrive") } end
    if p:GetAttribute("HeatCold") then A().Heat = { Cold = p:GetAttribute("HeatCold"), Hot = p:GetAttribute("HeatHot") or 0, Phase = (rest.Position.X * 11) % 6.28 } end
    if p:GetAttribute("Beat") then A().Beat = true end
    if p:GetAttribute("SoulSlot") then A().Soul = { Slot = p:GetAttribute("SoulSlot"), Bob = size.Y * 0.18 } end
    if p:GetAttribute("LookFrac") then A().Look = size.Y * p:GetAttribute("LookFrac") end
    if p:GetAttribute("IgniteAt") then A().Ignite = p:GetAttribute("IgniteAt") end
    -- ===== generic set drivers (SkinSets): every one reads st[<its Drive key>], which the set's Drive / World fill =====
    -- GlowDrive (+ GlowCold / GlowHot): transparency from cold to hot as st[key] goes 0 -> 1
    local gd = p:GetAttribute("GlowDrive")
    if gd then A().Glow = { Drive = gd, Cold = p:GetAttribute("GlowCold") or 1, Hot = p:GetAttribute("GlowHot") or 0 } end
    -- TurnDrive (+ TurnScale, uses the Rotor pivot / axis): the part turns st[key] * TurnScale radians -- an angle the
    -- set accumulates itself, so a driven gear or dial never jumps when its speed changes
    local td = p:GetAttribute("TurnDrive")
    if td and a and a.Rotor then a.Rotor.Drive = td; a.Rotor.Scale = p:GetAttribute("TurnScale") or 1 end
    -- CountDrive (+ CountSlot): shown only while st[key] >= its slot (charge pips, stacked crystals, tank level marks)
    local cd = p:GetAttribute("CountDrive")
    if cd then A().Count = { Drive = cd, Slot = p:GetAttribute("CountSlot") or 1, Base = p.Transparency } end -- (Base: shown again at its built transparency)
    -- TintDrive (+ TintA / TintB): colour from A to B as st[key] goes 0 -> 1 (frost creeping in, metal heating up)
    local tn = p:GetAttribute("TintDrive")
    if tn and typeof(p:GetAttribute("TintA")) == "Color3" and typeof(p:GetAttribute("TintB")) == "Color3" then
        -- (SKINS V3, builder 2) optional TintMid (Color3): a three-stop ramp A -> Mid -> B (a thermal heat ramp)
        local mid = p:GetAttribute("TintMid")
        A().Tint = { Drive = tn, A = p:GetAttribute("TintA"), B = p:GetAttribute("TintB"), Mid = (typeof(mid) == "Color3") and mid or nil }
    end
    -- ScaleDrive (+ ScaleFrac = the pivot as a fraction of the part's size, ScaleMin) (SKINS V3): the part GROWS from its
    -- pivot to full size as st[key] goes 0 -> 1 (a spike rising out of the fluid). The caller resizes the part (4th value
    -- of AnimOffset); the pivot shift is folded into the offset here.
    local scd = p:GetAttribute("ScaleDrive")
    if scd then
        local fr = p:GetAttribute("ScaleFrac")
        local l = (typeof(fr) == "Vector3") and size * fr or Vector3.zero
        -- (ScaleAxes = a Vector3 mask of the part's own axes that scale, e.g. (0, 1, 1): a row of spikes shrinks in height and
        -- depth onto its base line but keeps its length)
        local ax = p:GetAttribute("ScaleAxes")
        A().Scale = { Drive = scd, Min = p:GetAttribute("ScaleMin") or 0.02, Dir = rest:VectorToWorldSpace(l), Base = p.Transparency,
            Axes = (typeof(ax) == "Vector3") and ax or nil, L = l, Rot = rest.Rotation }
    end
    return a
end

-- The animated offset for a part (frame space): -> extra CFrame applied as offset * rest, and a transparency (or nil).
-- st = { Open = 0..1 (inspect wings), Spin = rotor speed boost, Flash = 0..1 since the last shot, FlashRoll, Sweep = 0..1
-- or nil, Halo = 0..1 }
function SkinFX.AnimOffset(a: any, now: number, st: any): (CFrame, number?)
    local off = CFrame.identity
    local tr = nil
    if a.Hinge then
        local h = a.Hinge
        local drive = st[h.Drive or "Open"] or 0
        local ang = h.Angle * drive + h.Idle * math.sin(now * 1.6 + h.Phase) * (1 - drive)
        if ang ~= 0 then off = CF(h.Pivot) * CFrame.fromAxisAngle(h.Axis, ang) * CF(-h.Pivot) end
    end
    if a.Rotor then
        local r = a.Rotor
        local ang = r.Drive and ((st[r.Drive] or 0) * r.Scale) or r.Amp and R(r.Amp) * math.sin(now * r.Speed) or (now * r.Speed * (st.Spin or 1))
        off = CF(r.Pivot) * CFrame.fromAxisAngle(r.Axis, ang % (math.pi * 2)) * CF(-r.Pivot) * off
    end
    if a.Pulse then
        local p = a.Pulse
        tr = p.Lo + (p.Hi - p.Lo) * (0.5 + 0.5 * math.sin(now * p.Speed + p.Phase))
    end
    if a.Flash then
        -- visible for a moment after each shot, rolled at random about the barrel
        local k = st.Flash or 1
        tr = (k >= 1) and 1 or (0.05 + 0.95 * k)
        if k < 1 then
            local c = a.Flash.Center
            off = CF(c) * ANG(st.FlashRoll or 0, 0, 0) * CF(-c) * off
        end
    end
    if a.Sweep then
        -- the light blade travels the gun's length (brightest in the middle of its run)
        if st.Sweep then
            local k = st.Sweep
            off = CF(a.Sweep.Delta * k) * off
            tr = 0.15 + 0.85 * math.abs(k * 2 - 1) ^ 3
        else
            tr = 1
        end
    end
    if a.Halo then tr = 1 - (st.Halo or 0) * 0.85 end
    -- ===== Infernal drivers =====
    if a.Shift then
        local k = st[a.Shift.Drive] or 0
        if k > 0 then off = CF(a.Shift.Delta * k) * off end
    end
    if a.Look then
        -- the demon eye's pupil darts between random spots while it's open
        local e = st.Eye or 0
        if e > 0 then
            local function hsh(n) return ((math.sin(n * 12.9898) * 43758.5453) % 1) * 2 - 1 end
            local i = math.floor(now * 1.3)
            local fk = math.min(1, (now * 1.3 - i) * 7)
            local dx = hsh(i - 1) + (hsh(i) - hsh(i - 1)) * fk
            local dy = hsh(i * 1.7 + 2) + (hsh(i * 1.7 + 3.7) - hsh(i * 1.7 + 2)) * fk
            off = CF(V(dx, dy * 0.45, 0) * a.Look * e) * off
        end
    end
    if a.Heat then
        local h = st.Heat or 0
        tr = math.clamp(a.Heat.Cold + (a.Heat.Hot - a.Heat.Cold) * h, 0, 1)
        if h > 0.6 then tr = math.clamp(tr + 0.1 * math.sin(now * 23 + a.Heat.Phase), 0, 1) end -- (white-hot: it flickers)
    end
    if a.Beat then
        -- ba-dum: two quick throbs every 0.85 s
        local t = now % 0.85
        local b = math.exp(-((t - 0.05) / 0.05) ^ 2) + 0.75 * math.exp(-((t - 0.27) / 0.05) ^ 2)
        local e = st.Eye or 0 -- (smouldering at rest, blazing while the ribs are spread)
        tr = math.clamp(0.62 - (0.3 + 0.32 * e) * b - 0.3 * e, 0, 1)
    end
    if a.Soul then
        if (st.Souls or 0) >= a.Soul.Slot then
            tr = 0.08 + 0.22 * (0.5 + 0.5 * math.sin(now * 9 + a.Soul.Slot * 2))
            off = CF(0, a.Soul.Bob * math.sin(now * 3.2 + a.Soul.Slot), 0) * off
        else
            tr = 1
        end
    end
    if a.Show then
        local v = math.clamp(st[a.Show.Drive] or 0, 0, 1)
        tr = 1 - (1 - (tr or 0)) * v
    end
    -- ===== generic set drivers =====
    if a.Glow then
        local g = a.Glow
        tr = math.clamp(g.Cold + (g.Hot - g.Cold) * math.clamp(st[g.Drive] or 0, 0, 1), 0, 1)
    end
    if a.Count then
        if (st[a.Count.Drive] or 0) < a.Count.Slot then tr = 1 elseif tr == nil then tr = a.Count.Base end
    end
    local col = nil
    if a.Tint then
        local k = math.clamp(st[a.Tint.Drive] or 0, 0, 1)
        local m = a.Tint.Mid
        if m then col = (k < 0.5) and a.Tint.A:Lerp(m, k * 2) or m:Lerp(a.Tint.B, k * 2 - 1) else col = a.Tint.A:Lerp(a.Tint.B, k) end
    end
    if a.Ignite then
        -- equip: unlit (charred) until its turn, a flare as it catches, then its normal glow
        local se = st.SinceEquip or 99
        if se < a.Ignite then tr = 1 elseif se < a.Ignite + 0.16 then tr = 0 end
    end
    local sc = nil
    if a.Scale then
        local k = math.clamp(st[a.Scale.Drive] or 1, a.Scale.Min, 1.6)
        local ax = a.Scale.Axes
        if ax then
            local s3 = Vector3.new(ax.X > 0 and k or 1, ax.Y > 0 and k or 1, ax.Z > 0 and k or 1)
            off = off * CF(a.Scale.Rot * (a.Scale.L * (Vector3.one - s3)))
            sc = s3
        else
            off = off * CF(a.Scale.Dir * (1 - k))
            sc = k
        end
        if k <= a.Scale.Min + 1e-3 then tr = 1 elseif tr == nil then tr = a.Scale.Base end -- (fully sunk: hidden)
    end
    return off, tr, col, sc
end

-- ===== third person: other players' guns / melees move like yours (client) =====
-- WorldGear welds every part to the model's Frame; here each animated part's weld C0 is driven locally.
function SkinFX.StartWorld()
    if SkinFX.WorldStarted or not RunService:IsClient() then return end
    SkinFX.WorldStarted = true
    local lp = Players.LocalPlayer
    local models = {} -- model -> { Parts = { { Weld, Rest, Anim, Part } }, NextSweep }
    local lastScan = 0
    RunService.RenderStepped:Connect(function()
        local now = os.clock()
        local cam = workspace.CurrentCamera
        if now - lastScan > 0.6 then
            lastScan = now
            for m in pairs(models) do if not m.Parent then models[m] = nil end end
            for _, pl in ipairs(Players:GetPlayers()) do
                local char = pl.Character
                if char then
                    for _, name in ipairs({ "WorldGun", "WorldMelee", "WorldArmor" }) do
                        local m = char:FindFirstChild(name)
                        if m and not models[m] then
                            local rec = { Parts = {}, NextSweep = now + 2 + math.random() * 4, Own = pl == lp, Emitters = {}, Kind = m:GetAttribute("SkinFxKind"), Vars = {} }
                            for _, d in ipairs(m:GetDescendants()) do
                                if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then table.insert(rec.Emitters, d) end
                            end
                            for _, p in ipairs(m:GetDescendants()) do
                                if p:IsA("BasePart") and p:GetAttribute("SkinDeco") then
                                    local w = p:FindFirstChildOfClass("Weld")
                                    if w and w.Part1 == p then
                                        local a = SkinFX.AnimRecord(p, w.C0, p.Size)
                                        if a and (a.Hinge or a.Rotor or a.Pulse or a.Sweep or a.Shift or a.Heat or a.Beat or a.Soul or a.Look or a.Show or a.Glow or a.Count or a.Tint or a.Scale) then
                                            table.insert(rec.Parts, { Weld = w, Rest = w.C0, Anim = a, Part = p, Size = p.Size })
                                        end
                                    end
                                end
                            end
                            models[m] = rec
                        end
                    end
                end
            end
        end
        local tp = lp:GetAttribute("ThirdPerson")
        for m, rec in pairs(models) do
            -- your own gear's particles / beams: only when you can see yourself (first person: nothing in your view)
            if rec.Own then
                local on = tp == true
                if rec.LastOn ~= on then
                    rec.LastOn = on
                    for _, e in ipairs(rec.Emitters) do if e.Parent and not e:IsA("Trail") then e.Enabled = on end end
                end
            end
            local frame = m:FindFirstChild("Frame") or (rec.Parts[1] and rec.Parts[1].Part)
            -- animate only what you can see: within 70 studs, in front of the camera, and every other frame past 35
            local rel = frame and (frame.Position - cam.CFrame.Position)
            local dist = rel and rel.Magnitude or math.huge
            local visible = rel and dist < 70 and (dist < 8 or rel.Unit:Dot(cam.CFrame.LookVector) > 0.3)
            rec.Tick = (rec.Tick or 0) + 1
            if visible and dist > 35 and rec.Tick % 2 == 0 then visible = false end
            if visible and #rec.Parts > 0 and frame.LocalTransparencyModifier < 1 then
                local sweep = nil
                if now >= rec.NextSweep then
                    sweep = math.clamp((now - rec.NextSweep) / 0.7, 0, 1)
                    if sweep >= 1 then rec.NextSweep = now + 5 + math.random() * 4; sweep = nil end
                end
                local eye = 0
                rec.NextEye = rec.NextEye or (now + 3 + math.random() * 4)
                if now >= rec.NextEye then
                    local k = (now - rec.NextEye) / 1.8
                    if k >= 1 then rec.NextEye = now + 6 + math.random() * 6 else eye = math.clamp(math.sin(k * math.pi) * 1.6, 0, 1) end
                end
                local st = { Open = 0, Spin = 1, Flash = 1, Sweep = sweep, Halo = 0, Heat = 0.2, Jaw = 0, Eye = eye,
                    Souls = rec.Own and SkinFX.Souls() or 0, SinceEquip = 99, Now = now }
                -- a SkinSets skin animates itself for other players too (its idle cycle, the occasional inspect)
                local set = rec.Kind and SkinFX.Sets[rec.Kind]
                if set and set.World then pcall(set.World, rec, now, st) end
                for _, e in ipairs(rec.Parts) do
                    local off, tr, col, sc = SkinFX.AnimOffset(e.Anim, now, st)
                    e.Weld.C0 = off * e.Rest
                    if tr and e.Part.Transparency ~= tr then e.Part.Transparency = tr end
                    if col and e.Part.Color ~= col then e.Part.Color = col end
                    if sc and e.LastSc ~= sc then e.LastSc = sc; e.Part.Size = e.Size * sc end -- (SKINS V3 ScaleDrive)
                end
            end
        end
    end)
end

-- ===== sounds: layered built-in clips + effects (until an uploaded Seraphim pack exists) =====
local CLIP = {
    Ping = "rbxasset://sounds/electronicpingshort.wav", Snap = "rbxasset://sounds/snap.mp3", Flash = "rbxasset://sounds/flashbulb.wav",
    Unsheath = "rbxasset://sounds/unsheath.wav", Slash = "rbxasset://sounds/swordslash.wav", Lunge = "rbxasset://sounds/swordlunge.wav",
    Glass = "rbxasset://sounds/glassbreak.wav", Ghost = "rbxasset://sounds/HalloweenGhost.wav", Bass = "rbxasset://sounds/bass.mp3",
    Victory = "rbxasset://sounds/victory.wav",
}
local PENTA = { 1.0, 1.125, 1.26, 1.5, 1.68, 2.0 }
local function SoundFolder()
    local f = SoundService:FindFirstChild("SkinSounds")
    if not f then f = Instance.new("Folder"); f.Name = "SkinSounds"; f.Parent = SoundService end
    return f
end
local function PlayClip(clip: string, pitch: number, vol: number, delay: number?, fx: string?)
    local function go()
        local s = Instance.new("Sound")
        s.SoundId = CLIP[clip] or clip
        s.PlaybackSpeed = pitch
        s.Volume = vol
        local grp = SoundService:FindFirstChild("AimRngMix_Weapons")
        if grp then s.SoundGroup = grp end
        if fx == "Hall" or fx == "Choir" then
            local rv = Instance.new("ReverbSoundEffect"); rv.DecayTime = fx == "Choir" and 2.6 or 1.5; rv.WetLevel = -4; rv.DryLevel = -2; rv.Parent = s
        end
        if fx == "Choir" then
            local ch = Instance.new("ChorusSoundEffect"); ch.Depth = 0.35; ch.Rate = 1.1; ch.Mix = 0.6; ch.Parent = s
        end
        if fx == "Bright" then
            local eq = Instance.new("EqualizerSoundEffect"); eq.LowGain = -18; eq.MidGain = -2; eq.HighGain = 3; eq.Parent = s
        end
        s.Parent = SoundFolder()
        s:Play()
        Debris:AddItem(s, 4)
    end
    if delay and delay > 0 then task.delay(delay, go) else go() end
end
local lastFireSnd = 0
local killStreak, lastKill = 0, 0
-- kind: "Fire" | "Equip" | "Inspect" | "MagOut" | "MagIn" | "Kill" | "Impact" | "Swing" | "MeleeHit"
local function PackSound(pack: any, kind: string)
    local d = pack and pack[kind]
    if not d or (d.Id or 0) == 0 then return end
    local snd = Instance.new("Sound")
    snd.SoundId = "rbxassetid://" .. tostring(d.Id)
    snd.Volume = d.Volume
    snd.PlaybackSpeed = 1 + (math.random() - 0.5) * 0.06
    local grp = SoundService:FindFirstChild("AimRngMix_Weapons")
    if grp then snd.SoundGroup = grp end
    snd.Parent = SoundFolder()
    snd:Play()
    Debris:AddItem(snd, 4)
end
-- the skin's own shot for this gun (nil = none uploaded): { Id, Volume }
function SkinFX.FireFor(kind: string?, gun: string?): any
    if not kind or not gun then return nil end
    local set = SkinFX.Sets[kind]
    local fg = (set and set.Sounds and set.Sounds.FireGun) or (kind == "Infernal" and SkinFX.InfernalSounds.FireGun)
        or (kind == "Seraphim" and SkinFX.SeraphimFireGun) or nil
    local d = fg and fg[gun]
    return (d and (d.Id or 0) ~= 0) and d or nil
end
-- plays it for the gun in your hands; true = it played (the rig then skips the base shot + the old layer)
function SkinFX.GunFire(gun: string?): boolean
    local d = SkinFX.FireFor(SkinFX.CurrentKind, gun)
    if not d then return false end
    PackSound({ Fire = d }, "Fire")
    return true
end
function SkinFX.Sound(kind: string)
    local now = os.clock()
    local set = SkinFX.CurrentKind and SkinFX.Sets[SkinFX.CurrentKind]
    if SkinFX.CurrentKind == "Infernal" or set then
        -- custom packs (Infernal + every SkinSets set): its own uploaded clips; an Id of 0 stays silent
        if kind == "Fire" then
            if now - lastFireSnd < 0.05 then return nil end
            lastFireSnd = now
        end
        PackSound(set and set.Sounds or SkinFX.InfernalSounds, kind)
        if kind == "Kill" then
            if now - lastKill > 3.5 then killStreak = 0 end
            killStreak = math.min(killStreak + 1, 5)
            lastKill = now
            return killStreak
        end
        return nil
    end
    if kind == "Fire" then
        if now - lastFireSnd < 0.05 then return end
        lastFireSnd = now
        PlayClip("Ping", 1.7 * PENTA[math.random(1, #PENTA)], 0.07, nil, "Bright")
        PlayClip("Flash", 1.9 + math.random() * 0.2, 0.14)
    elseif kind == "Equip" then
        PlayClip("Unsheath", 1.22, 0.42)
        PlayClip("Ping", 1.26, 0.2, 0.05, "Hall"); PlayClip("Ping", 1.5, 0.2, 0.12, "Hall"); PlayClip("Ping", 2.0, 0.22, 0.19, "Hall")
        PlayClip("Glass", 2.6, 0.08, 0.1)
    elseif kind == "Inspect" then
        PlayClip("Slash", 0.72, 0.32)
        PlayClip("Ghost", 2.15, 0.13, 0.05, "Choir")
        PlayClip("Glass", 2.4, 0.09, 0.3)
        PlayClip("Ping", 2.0, 0.14, 0.45, "Hall"); PlayClip("Ping", 1.68, 0.12, 0.6, "Hall")
    elseif kind == "MagOut" then
        PlayClip("Lunge", 1.8, 0.16)
    elseif kind == "MagIn" then
        PlayClip("Ping", 1.5, 0.2, nil, "Hall")
        PlayClip("Snap", 1.4, 0.3)
    elseif kind == "Kill" then
        if now - lastKill > 3.5 then killStreak = 0 end
        killStreak = math.min(killStreak + 1, 5)
        lastKill = now
        local k = ({ 1, 1.12, 1.26, 1.34, 1.5 })[killStreak]
        PlayClip("Ping", 1.0 * k, 0.26, nil, "Choir"); PlayClip("Ping", 1.26 * k, 0.22, 0.02, "Choir"); PlayClip("Ping", 1.5 * k, 0.2, 0.04, "Choir")
        PlayClip("Bass", 1.25, 0.22)
        if killStreak >= 5 then PlayClip("Victory", 1.25, 0.28, 0.08, "Hall") end
        return killStreak
    elseif kind == "Impact" then
        PlayClip("Ping", 2.6 + math.random() * 0.6, 0.05, nil, "Bright")
    elseif kind == "Swing" then
        PlayClip("Slash", 1.15 + math.random() * 0.1, 0.34)
        PlayClip("Ping", 2.5, 0.07, 0.03, "Bright")
    elseif kind == "MeleeHit" then
        PlayClip("Ping", 1.26, 0.2, nil, "Hall"); PlayClip("Glass", 2.2, 0.1)
    end
    return nil
end
function SkinFX.KillStreak() return (os.clock() - lastKill > 3.5) and 0 or killStreak end

-- ===== golden tracer + starburst impact =====
local function LowFx()
    local ok, GS = pcall(require, script.Parent:WaitForChild("GameSettings"))
    return ok and GS.Get and GS.Get("Particles") == "Reduced"
end
-- ===== MELEE IMPACT (owner 2026-10-07: "improve ... melee (hits + animations + positioning)") =====
-- A landed melee hit: a crossed slash flash facing the camera, a spark burst and a ground-free ring in the skin's
-- colours (a set skin: its Colors; Seraphim gold; Infernal crimson; no skin: steel white), and the skin's own hit sound.
-- Cheap: 4 parts + 1 emitter, gone in 0.3 s, at most 4 alive.
local liveImpacts = 0
local IMPACT_COLORS = { Seraphim = { Color3.fromRGB(255, 236, 170), GOLD }, Infernal = { Color3.fromRGB(255, 90, 70), Color3.fromRGB(160, 70, 255) } }
function SkinFX.MeleeImpact(pos: Vector3, kind: string?, crit: boolean?, killed: boolean?)
    local cam = workspace.CurrentCamera
    if not cam or liveImpacts >= 4 then return end
    local cols = kind and IMPACT_COLORS[kind]
    local set = kind and SkinFX.Sets[kind]
    if not cols and set and set.Colors then
        cols = {}
        for _, c in pairs(set.Colors) do table.insert(cols, c) end
        table.sort(cols, function(x, y) return (x.R + x.G + x.B) > (y.R + y.G + y.B) end)
    end
    cols = (cols and #cols > 0) and cols or { Color3.fromRGB(255, 250, 235), Color3.fromRGB(200, 205, 215) }
    local a, b = cols[1], cols[2] or cols[1]
    -- sound: the set's own MeleeHit clip, else the soft chime
    if set and set.Sounds and set.Sounds.MeleeHit and (set.Sounds.MeleeHit.Id or 0) ~= 0 then
        PackSound(set.Sounds, "MeleeHit")
    elseif kind == "Infernal" then
        PackSound(SkinFX.InfernalSounds, "MeleeHit")
    elseif kind then
        PlayClip("Ping", 1.26, 0.18, nil, "Hall"); PlayClip("Glass", 2.2, 0.08)
    end
    liveImpacts += 1
    local folder = workspace:FindFirstChild("SkinFxWorld") or Instance.new("Folder")
    folder.Name = "SkinFxWorld"; folder.Parent = workspace
    local toCam = (cam.CFrame.Position - pos)
    local p = pos + (toCam.Magnitude > 0.1 and toCam.Unit * 0.6 or Vector3.zero)
    local face = CFrame.lookAt(p, cam.CFrame.Position)
    local big = (crit or killed) and 1.35 or 1
    local parts = {}
    local function P(size, cf, col, shape)
        local q = Instance.new("Part")
        q.Anchored, q.CanCollide, q.CanQuery, q.CanTouch, q.CastShadow = true, false, false, false, false
        q.Material = Enum.Material.Neon; q.Color = col; q.Size = size; q.CFrame = cf
        if shape then q.Shape = shape end
        q.Parent = folder
        table.insert(parts, { Part = q, Size = size })
        return q
    end
    local roll = math.random() * math.pi
    P(V(2.4 * big, 0.09, 0.02), face * CFrame.Angles(0, 0, roll), a)
    P(V(1.7 * big, 0.06, 0.02), face * CFrame.Angles(0, 0, roll + math.rad(70 + math.random() * 30)), b)
    local ring = P(V(0.03, 0.6 * big, 0.6 * big), face * CFrame.Angles(0, math.rad(90), 0), b, Enum.PartType.Cylinder)
    local att = Instance.new("Attachment"); att.Parent = parts[1].Part
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = SPARK; pe.Color = ColorSequence.new(a, b); pe.LightEmission = 1; pe.LightInfluence = 0
    pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28 * big), NumberSequenceKeypoint.new(1, 0) })
    pe.Lifetime = NumberRange.new(0.18, 0.32); pe.Speed = NumberRange.new(10, 22); pe.SpreadAngle = Vector2.new(70, 70)
    pe.Acceleration = Vector3.new(0, -30, 0); pe.Drag = 4; pe.Rate = 0; pe.EmissionDirection = Enum.NormalId.Front
    pe.Parent = att
    pe:Emit(LowFx() and 6 or ((crit or killed) and 18 or 12))
    local t0 = os.clock()
    local conn
    conn = RunService.RenderStepped:Connect(function()
        local k = (os.clock() - t0) / 0.24
        if k >= 1 then
            conn:Disconnect()
            liveImpacts -= 1
            for _, e in ipairs(parts) do e.Part:Destroy() end
            return
        end
        local grow = 0.6 + 0.7 * (1 - (1 - k) ^ 3)
        for i, e in ipairs(parts) do
            local q = e.Part
            if q == ring then
                q.Size = V(0.03, e.Size.Y * (0.4 + 1.6 * k), e.Size.Z * (0.4 + 1.6 * k))
            else
                q.Size = V(e.Size.X * grow, e.Size.Y * (1 - k * 0.6), e.Size.Z)
            end
            q.Transparency = k ^ 1.6
        end
    end)
end

local liveFx = 0
function SkinFX.Tracer(from: Vector3, to: Vector3)
    local dist = (to - from).Magnitude
    if dist < 2 then return end
    local folder = workspace:FindFirstChild("SkinFxWorld") or Instance.new("Folder")
    folder.Name = "SkinFxWorld"; folder.Parent = workspace
    local host = Instance.new("Part")
    host.Anchored, host.CanCollide, host.CanQuery, host.CanTouch, host.CastShadow = true, false, false, false, false
    host.Transparency = 1; host.Size = V(0.1, 0.1, 0.1); host.CFrame = CF(from); host.Parent = folder
    local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
    a0.Parent, a1.Parent = host, host
    a1.WorldPosition = to
    local core = Instance.new("Beam")
    core.Attachment0, core.Attachment1 = a0, a1
    core.Color = ColorSequence.new(Color3.fromRGB(255, 250, 225), GOLD)
    core.LightEmission = 1; core.LightInfluence = 0; core.FaceCamera = true
    core.Width0, core.Width1 = 0.07, 0.03
    core.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.4, 0.05), NumberSequenceKeypoint.new(1, 0.1) })
    core.Parent = host
    local glow = core:Clone()
    glow.Width0, glow.Width1 = 0.3, 0.14
    glow.Texture = SPARK; glow.TextureMode = Enum.TextureMode.Wrap; glow.TextureLength = 1.2; glow.TextureSpeed = 3
    glow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0.5) })
    glow.Parent = host
    local t0 = os.clock()
    local conn
    conn = RunService.RenderStepped:Connect(function()
        local k = (os.clock() - t0) / 0.16
        if k >= 1 or not host.Parent then conn:Disconnect(); host:Destroy(); return end
        -- (hitscan look 2026-10-22: the line stays muzzle -> hit and fades; the tail no longer chases the head)
        local fade = k * k
        core.Transparency = NumberSequence.new(math.clamp(0.05 + fade, 0, 1))
        glow.Transparency = NumberSequence.new(math.clamp(0.45 + fade * 0.55, 0, 1))
    end)
end

function SkinFX.Impact(pos: Vector3, normal: Vector3?)
    if liveFx > 10 then return end
    liveFx += 1
    task.delay(0.5, function() liveFx -= 1 end)
    local folder = workspace:FindFirstChild("SkinFxWorld") or Instance.new("Folder")
    folder.Name = "SkinFxWorld"; folder.Parent = workspace
    local n = (normal and normal.Magnitude > 0.1) and normal.Unit or V(0, 1, 0)
    local face = CFrame.lookAt(pos + n * 0.05, pos + n * 2)
    -- a four-point star facing out of the surface, popping and fading
    local function P(size, cf, color, tr)
        local p = Instance.new("Part")
        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
        p.Material = Enum.Material.Neon; p.Color = color; p.Transparency = tr; p.Size = size; p.CFrame = cf; p.Parent = folder
        Debris:AddItem(p, 0.5)
        return p
    end
    local roll = ANG(0, 0, math.random() * 6.28)
    local sv = P(V(0.05, 0.9, 0.02), face * roll, PALEGOLD, 0.05)
    local sh = P(V(0.6, 0.05, 0.02), face * roll, PALEGOLD, 0.05)
    local core = P(V(0.18, 0.18, 0.03), face * roll * ANG(0, 0, R(45)), Color3.new(1, 1, 1), 0)
    local ti = TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(sv, ti, { Size = V(0.02, 1.5, 0.02), Transparency = 1 }):Play()
    TweenService:Create(sh, ti, { Size = V(1.0, 0.02, 0.02), Transparency = 1 }):Play()
    TweenService:Create(core, ti, { Size = V(0.02, 0.02, 0.02), Transparency = 1 }):Play()
    if not LowFx() then
        local att = Instance.new("Attachment"); att.Parent = core
        local pe = Instance.new("ParticleEmitter")
        pe.Texture = SPARK; pe.Color = ColorSequence.new(Color3.new(1, 1, 1), GOLD); pe.LightEmission = 1; pe.LightInfluence = 0
        pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
        pe.Lifetime = NumberRange.new(0.2, 0.35); pe.Speed = NumberRange.new(3, 7); pe.SpreadAngle = Vector2.new(70, 70)
        pe.EmissionDirection = Enum.NormalId.Back -- (the face looks out of the surface along -Z)
        pe.Rate = 0; pe.Parent = att
        pe:Emit(7)
    end
end

-- ===== INFERNAL tracer (crimson core in a violet glow, embers shed along it) + claw-mark impact =====
-- the hellfire WHIP: the shot leaves the muzzle as an S-curved lash of flame that snaps straight, then burns out
function SkinFX.InfernalTracer(from: Vector3, to: Vector3)
    local dist = (to - from).Magnitude
    if dist < 2 then return end
    local folder = workspace:FindFirstChild("SkinFxWorld") or Instance.new("Folder")
    folder.Name = "SkinFxWorld"; folder.Parent = workspace
    local host = Instance.new("Part")
    host.Anchored, host.CanCollide, host.CanQuery, host.CanTouch, host.CastShadow = true, false, false, false, false
    host.Transparency = 1; host.Size = V(0.1, 0.1, 0.1); host.CFrame = CF(from); host.Parent = folder
    local dir = (to - from).Unit
    local up = (math.abs(dir.Y) > 0.95) and V(1, 0, 0) or V(0, 1, 0)
    local side = dir:Cross(up).Unit
    local rot = math.random() * math.pi * 2
    side = (side * math.cos(rot) + dir:Cross(side) * math.sin(rot)).Unit
    -- (a Beam bends toward each attachment's X axis: tilt both the same way for an S)
    local ax = (dir + side * 0.9).Unit
    local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
    a0.Parent, a1.Parent = host, host
    a0.WorldCFrame = CFrame.lookAt(from, from + ax) * ANG(0, R(90), 0)
    a1.WorldCFrame = CFrame.lookAt(to, to + ax) * ANG(0, R(90), 0)
    local curve = math.min(dist * 0.22, 6)
    local core = Instance.new("Beam")
    core.Attachment0, core.Attachment1 = a0, a1
    core.Color = ColorSequence.new(WHITEHOT, CRIMSON)
    core.LightEmission = 1; core.LightInfluence = 0; core.FaceCamera = true
    core.Width0, core.Width1 = 0.06, 0.03
    core.Segments = 14
    core.CurveSize0, core.CurveSize1 = curve, curve
    core.Parent = host
    local glow = core:Clone()
    glow.Color = ColorSequence.new(CRIMSON, VIOLET)
    glow.Width0, glow.Width1 = 0.3, 0.12
    glow.Texture = FIRE; glow.TextureMode = Enum.TextureMode.Wrap; glow.TextureLength = 1.4; glow.TextureSpeed = -4
    glow.Parent = host
    local t0 = os.clock()
    local conn
    conn = RunService.RenderStepped:Connect(function()
        local t = os.clock() - t0
        if t > 0.2 or not host.Parent then conn:Disconnect(); host:Destroy(); return end
        -- snap: the curve whips through straight (a small overshoot) in 0.07 s, then the flame burns out
        local k = math.clamp(t / 0.07, 0, 1)
        local c = curve * ((1 - k) ^ 2 - 0.18 * math.sin(k * math.pi))
        core.CurveSize0, core.CurveSize1 = c, c
        glow.CurveSize0, glow.CurveSize1 = c, c
        local fade = math.clamp((t - 0.05) / 0.15, 0, 1)
        core.Transparency = NumberSequence.new(math.clamp(0.05 + fade, 0, 1))
        glow.Transparency = NumberSequence.new(math.clamp(0.35 + fade * 0.65, 0, 1))
    end)
end

function SkinFX.InfernalImpact(pos: Vector3, normal: Vector3?)
    if liveFx > 10 then return end
    liveFx += 1
    task.delay(0.5, function() liveFx -= 1 end)
    local folder = workspace:FindFirstChild("SkinFxWorld") or Instance.new("Folder")
    folder.Name = "SkinFxWorld"; folder.Parent = workspace
    local n = (normal and normal.Magnitude > 0.1) and normal.Unit or V(0, 1, 0)
    local face = CFrame.lookAt(pos + n * 0.04, pos + n * 2) * ANG(0, 0, math.random() * 6.28)
    -- three claw marks scorched into the surface, glowing and fading
    for k = -1, 1 do
        local p = Instance.new("Part")
        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
        p.Material = Enum.Material.Neon; p.Color = (k == 0) and Color3.fromRGB(255, 120, 120) or CRIMSON; p.Transparency = 0.05
        p.Size = V(0.07, 0.9 - math.abs(k) * 0.2, 0.02)
        p.CFrame = face * CF(k * 0.22, 0, 0) * ANG(0, 0, R(k * 8))
        p.Parent = folder
        TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = V(0.02, p.Size.Y * 1.15, 0.02), Transparency = 1, Color = VIOLET }):Play()
        Debris:AddItem(p, 0.5)
    end
    if not LowFx() then
        local hostP = Instance.new("Part")
        hostP.Anchored, hostP.CanCollide, hostP.CanQuery, hostP.CanTouch = true, false, false, false
        hostP.Transparency = 1; hostP.Size = V(0.1, 0.1, 0.1); hostP.CFrame = face; hostP.Parent = folder
        Debris:AddItem(hostP, 0.8)
        local att = Instance.new("Attachment"); att.Parent = hostP
        local pe = Instance.new("ParticleEmitter")
        pe.Texture = SPARK; pe.Color = ColorSequence.new(EMBERC, CRIMSON); pe.LightEmission = 1; pe.LightInfluence = 0
        pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0) })
        pe.Lifetime = NumberRange.new(0.25, 0.45); pe.Speed = NumberRange.new(3, 6); pe.SpreadAngle = Vector2.new(65, 65)
        pe.Acceleration = V(0, -8, 0)
        pe.EmissionDirection = Enum.NormalId.Back
        pe.Rate = 0; pe.Parent = att
        pe:Emit(6)
    end
end

-- ===== the souls you've claimed (Infernal): each kill's soul lands in the gun ~0.8 s later and lights a vial;
-- they burn out 12 s after landing =====
local souls = {}
function SkinFX.AddSoul()
    table.insert(souls, os.clock())
    if #souls > 3 then table.remove(souls, 1) end
end
function SkinFX.Souls(): number
    local now = os.clock()
    while souls[1] and now - souls[1] > 12 do table.remove(souls, 1) end
    return #souls
end

-- where a claimed soul flies to: your gun (third person: the gun on your back / in your hands)
local function SoulTarget(): Vector3
    local lp = Players.LocalPlayer
    local char = lp and lp.Character
    if lp and lp:GetAttribute("ThirdPerson") == true and char then
        local g = char:FindFirstChild("WorldGun")
        local fr = g and g:FindFirstChild("Frame")
        if fr then return fr.Position end
    end
    local cam = workspace.CurrentCamera
    return cam and (cam.CFrame * CF(0.7, -0.5, -1.9)).Position or V(0, 0, 0)
end

-- ===== kill effect: CLAIMED -- the light is SUCKED INTO the body, the ground splits open in glowing fissures,
-- chains lash up out of them and drag back down, and the soul is torn out and flies into your gun. (Nothing rises
-- from the ground or falls from the sky: that's the Seraphim's.) =====
local function InfernalKill(pos: Vector3)
    local low = LowFx()
    local folder = Instance.new("Model")
    folder.Name = "InfernalKill"
    local ground = pos - V(0, 2.5, 0)
    local hit = workspace:Raycast(pos, V(0, -12, 0))
    if hit then ground = hit.Position end
    local function P(props)
        local p = Instance.new("Part")
        p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
        p.Material = props.Material or Enum.Material.Neon
        props.Material = nil
        for k, v in pairs(props) do p[k] = v end
        p.Parent = folder
        return p
    end
    -- 1) IMPLOSION: a crimson shell and a black void collapse into the body while embers rush inward
    local shell = P({ Shape = Enum.PartType.Ball, Size = V(5, 5, 5), Color = CRIMSON, Transparency = 0.8, CFrame = CF(pos) })
    local void = P({ Shape = Enum.PartType.Ball, Size = V(2.4, 2.4, 2.4), Color = Color3.fromRGB(12, 0, 8), Material = Enum.Material.SmoothPlastic, Transparency = 0.2, CFrame = CF(pos) })
    local inward = Instance.new("ParticleEmitter")
    inward.Texture = SPARK; inward.Color = ColorSequence.new(EMBERC, CRIMSON); inward.LightEmission = 1; inward.LightInfluence = 0
    inward.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
    inward.Lifetime = NumberRange.new(0.18, 0.24); inward.Speed = NumberRange.new(10, 12)
    inward.Shape = Enum.ParticleEmitterShape.Sphere; inward.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
    inward.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
    inward.Rate = 0; inward.Parent = shell
    -- 2) FISSURE: jagged cracks split the ground outward from under the body, over a scorched patch
    local scorch = P({ Shape = Enum.PartType.Cylinder, Size = V(0.05, 0.2, 0.2), Color = Color3.fromRGB(16, 4, 10), Material = Enum.Material.SmoothPlastic, Transparency = 1,
        CFrame = CF(ground + V(0, 0.03, 0)) * ANG(0, 0, R(90)) })
    local cracks = {}
    local nb = low and 4 or 6
    for i = 1, nb do
        local dir = (i / nb) * math.pi * 2 + (math.random() - 0.5) * 0.7
        local p0 = V(0, 0, 0)
        for j = 1, 3 do
            local len = (1.5 - j * 0.3) * (0.8 + math.random() * 0.5)
            dir += (math.random() - 0.5) * 0.9
            local p1 = p0 + V(math.cos(dir), 0, math.sin(dir)) * len
            local seg = P({ Size = V(0.17 - j * 0.035, 0.05, 0.05), Color = (j == 1) and WHITEHOT or CRIMSON, Transparency = 1 })
            table.insert(cracks, { Part = seg, A = p0, B = p1, T0 = 0.22 + (j - 1) * 0.06, Hot = seg.Color })
            p0 = p1
        end
    end
    -- 3) CHAINS lash up out of the fissure, then drag back down into it
    local chains = {}
    for c = 1, (low and 2 or 3) do
        local a = c / 3 * math.pi * 2 + math.random()
        local links = {}
        for l = 1, 8 do
            local hot = l >= 7 -- (the lashing tips glow white-hot)
            links[l] = P({ Size = V(0.16, 0.34, 0.56), Color = hot and Color3.fromRGB(255, 120, 90) or Color3.fromRGB(84, 48, 58),
                Material = hot and Enum.Material.Neon or Enum.Material.Metal, Reflectance = hot and 0 or 0.25, Transparency = 1, CFrame = CF(ground) })
        end
        table.insert(chains, { Links = links, Out = V(math.cos(a), 0, math.sin(a)), Curl = 0.6 + math.random() * 0.5 })
    end
    -- 4) the SOUL: a pale violet wisp torn out of the body; it circles once and flies into your gun
    local soul = P({ Shape = Enum.PartType.Ball, Size = V(0.5, 0.5, 0.5), Color = SOULC, Transparency = 1, CFrame = CF(pos) })
    local sa0, sa1 = Instance.new("Attachment"), Instance.new("Attachment")
    sa0.Position = V(0, 0.2, 0); sa1.Position = V(0, -0.2, 0)
    sa0.Parent, sa1.Parent = soul, soul
    local trail = Instance.new("Trail")
    trail.Attachment0, trail.Attachment1 = sa0, sa1
    trail.Color = ColorSequence.new(Color3.fromRGB(245, 225, 255), VIOLET)
    trail.LightEmission = 1; trail.LightInfluence = 0
    trail.Transparency = NumberSequence.new(0.15, 1)
    trail.WidthScale = NumberSequence.new(1, 0)
    trail.Lifetime = 0.35; trail.FaceCamera = true; trail.Enabled = false
    trail.Parent = soul
    local wisp = Instance.new("ParticleEmitter")
    wisp.Texture = FIRE; wisp.Color = ColorSequence.new(Color3.fromRGB(245, 225, 255), VIOLET)
    wisp.LightEmission = 1; wisp.LightInfluence = 0
    wisp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
    wisp.Transparency = NumberSequence.new(0.2, 1)
    wisp.Lifetime = NumberRange.new(0.2, 0.35); wisp.Speed = NumberRange.new(0.2, 0.6)
    wisp.Rate = low and 18 or 36; wisp.Enabled = false
    wisp.Parent = sa0
    -- rising heat-embers out of the fissure once it opens
    local att = Instance.new("Attachment"); att.Parent = scorch
    local embers = Instance.new("ParticleEmitter")
    embers.Texture = SPARK; embers.Color = ColorSequence.new(EMBERC, CRIMSON); embers.LightEmission = 1; embers.LightInfluence = 0
    embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
    embers.Lifetime = NumberRange.new(0.6, 1.1); embers.Speed = NumberRange.new(1, 3); embers.Acceleration = V(0, 4, 0)
    embers.SpreadAngle = Vector2.new(70, 70); embers.EmissionDirection = Enum.NormalId.Right -- (the disc is rotated: Right = up)
    embers.Rate = 0; embers.Parent = att
    local light = Instance.new("PointLight")
    light.Color = CRIMSON; light.Range = 18; light.Brightness = 1; light.Parent = scorch
    folder.Parent = workspace
    inward:Emit(low and 14 or 30)
    local t0 = os.clock()
    local mid = pos + V(0, 2, 0)
    local landed = false
    local opened = false
    local conn
    conn = RunService.RenderStepped:Connect(function()
        local t = os.clock() - t0
        if t > 1.6 or not folder.Parent then
            conn:Disconnect(); folder:Destroy()
            if not landed then SkinFX.AddSoul() end
            return
        end
        -- implosion: 0 -> 0.22 s, accelerating inward
        local ik = math.clamp(t / 0.22, 0, 1)
        local ie = ik * ik
        shell.Size = V(1, 1, 1) * (5 * (1 - ie) + 0.05)
        shell.Transparency = ik >= 1 and 1 or (0.8 - 0.55 * ie)
        void.Size = V(1, 1, 1) * (2.4 * (1 - ie) + 0.05)
        void.Transparency = ik >= 1 and 1 or 0.2
        -- ...then the ground SPLITS (0.22 s): a flash of light, the scorch spreads, the cracks race outward
        if t >= 0.22 and not opened then
            opened = true
            embers:Emit(low and 10 or 22)
        end
        light.Brightness = (t < 0.22) and 1 or 6 * math.exp(-(t - 0.22) * 2.6)
        local sk = math.clamp((t - 0.22) / 0.15, 0, 1)
        scorch.Size = V(0.05, 0.2 + 4.6 * sk, 0.2 + 4.6 * sk)
        scorch.Transparency = (t < 0.22) and 1 or math.clamp(0.25 + math.max(0, t - 1.0) / 0.55, 0, 1)
        local cool = math.clamp((t - 0.7) / 0.6, 0, 1)
        for _, c in ipairs(cracks) do
            local g = math.clamp((t - c.T0) / 0.09, 0, 1)
            if g > 0 then
                local a = ground + c.A + V(0, 0.05, 0)
                local b = ground + c.A + (c.B - c.A) * g + V(0, 0.05, 0)
                local len = (b - a).Magnitude
                if len > 0.02 then
                    c.Part.Size = V(c.Part.Size.X, 0.05, len + 0.05)
                    c.Part.CFrame = CFrame.lookAt((a + b) / 2, b)
                end
                c.Part.Color = c.Hot:Lerp(Color3.fromRGB(70, 10, 24), cool)
                c.Part.Transparency = math.clamp(0.05 + math.max(0, t - 1.0) / 0.5, 0, 1)
            end
        end
        -- chains: lash out of the fissure (0.3 -> 0.55 s), hang, drag back down (0.95 -> 1.3 s)
        local ext = (1 - (1 - math.clamp((t - 0.3) / 0.25, 0, 1)) ^ 3) * (1 - math.clamp((t - 0.95) / 0.35, 0, 1) ^ 2)
        for _, chn in ipairs(chains) do
            local n = #chn.Links
            local L = 4.4 * ext
            local function at(sv: number): Vector3
                local u = sv / 4.4
                return ground + chn.Out * (sv * 0.45 + chn.Curl * 1.6 * u * u) + V(0, sv * 0.9 - 0.9 * u * u * u, 0)
            end
            for l = 1, n do
                local link = chn.Links[l]
                if ext < 0.04 then
                    link.Transparency = 1
                else
                    local sv = (l / n) * L
                    local p, q = at(sv), at(sv + 0.45)
                    if (q - p).Magnitude > 0.01 then
                        link.CFrame = CFrame.lookAt(p, q) * ANG(0, 0, (l % 2 == 0) and R(90) or 0)
                    end
                    link.Transparency = 0
                end
            end
        end
        -- the soul: torn up out of the body (0.2 -> 0.55 s, a tightening spiral), then flies to your gun (0.55 -> 1.0 s)
        if t >= 0.2 and t < 0.55 then
            local k = (t - 0.2) / 0.35
            local ang = k * math.pi * 2.5
            soul.Transparency = 0.05
            trail.Enabled = true; wisp.Enabled = true
            soul.CFrame = CF(pos + V(math.cos(ang) * 0.7 * (1 - k * 0.5), 0.3 + k * 1.7, math.sin(ang) * 0.7 * (1 - k * 0.5)))
            mid = soul.Position
        elseif t >= 0.55 and t < 1.0 then
            local k = (t - 0.55) / 0.45
            local e = k * k * (3 - 2 * k)
            local tgt = SoulTarget()
            local ctrl = mid + V(0, 2.2, 0)
            soul.CFrame = CF((1 - e) * (1 - e) * mid + 2 * (1 - e) * e * ctrl + e * e * tgt)
            soul.Size = V(1, 1, 1) * (0.5 - 0.36 * e)
        elseif t >= 1.0 and not landed then
            landed = true
            SkinFX.AddSoul() -- (a vial lights on your gun as it lands)
            soul.Transparency = 1; wisp.Enabled = false; trail.Enabled = false
        end
    end)
end

-- ===== kill effect: ASCENSION -- wings of light unfold, a pillar descends, a rune circle turns, feathers fall =====
local liveKills = 0
-- (colourways) the FX key of a set kill effect in the colourway this state wears: "Kind" or "Kind#v". ref = the item it
-- comes from ("KillEffect:<Id>", "WeaponSkin:<Id>" ...). Every kill path (own kills, try-on, store showcase, spectating)
-- goes through this so the effect + banner always take the equipped colourway.
function SkinFX.KillFX(state: any, fx: string?, ref: string?): string?
    local cw = SkinFX.Colorways
    if not (fx and cw and cw.Has and cw.Has(fx)) or string.find(fx, "#", 1, true) then return fx end
    local v = cw.VariantFor(state, fx, ref)
    return (v > 1 and SkinFX.Sets[fx .. "#" .. v]) and (fx .. "#" .. v) or fx
end
function SkinFX.KillEffect(skin: any, pos: Vector3)
    local set = skin and SkinFX.Sets[skin.FX or ""]
    if not (skin and (skin.FX == "Seraphim" or skin.FX == "Infernal" or set)) or typeof(pos) ~= "Vector3" then return end
    if set then
        -- (SKINS V3, gate C12) every set's kill effect goes through the same LOD rule (H.KillLod)
        local lod = SkinFX.H.KillLod()
        if lod ~= "skip" and set.Kill then set.Kill(SkinFX.H, pos, lod == "low") end
        return
    end
    local low = LowFx()
    if liveKills >= (low and 2 or 4) then return end -- (multi-kills: cap the effects alive at once)
    liveKills += 1
    task.delay(1.6, function() liveKills -= 1 end)
    if skin.FX == "Infernal" then InfernalKill(pos) return end
    local folder = Instance.new("Model")
    folder.Name = "SeraphimKill"
    local ground = pos - V(0, 2.5, 0)
    local hit = workspace:Raycast(pos, V(0, -12, 0))
    if hit then ground = hit.Position end
    local cam = workspace.CurrentCamera
    local toCam = cam and (cam.CFrame.Position - pos) or V(0, 0, 1)
    toCam = V(toCam.X, 0, toCam.Z)
    if toCam.Magnitude < 0.1 then toCam = V(0, 0, 1) end
    local face = CFrame.lookAt(pos, pos + toCam.Unit) -- (the wings face you)
    local parts = {}
    local function P(props)
        local p = Instance.new(props.Wedge and "WedgePart" or "Part")
        props.Wedge = nil
        p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
        p.Material = Enum.Material.Neon
        for k, v in pairs(props) do p[k] = v end
        p.Parent = folder
        table.insert(parts, p)
        return p
    end
    -- burst of light
    local burst = P({ Shape = Enum.PartType.Ball, Size = V(0.6, 0.6, 0.6), Color = Color3.fromRGB(255, 248, 225), Transparency = 0.1, CFrame = CF(pos) })
    -- WINGS: two fans of feathers, folded at first, unfolding outward and up
    local wings = {}
    for _, s in ipairs({ -1, 1 }) do
        for i = 1, (low and 4 or 6) do
            local L = 2.6 - i * 0.22
            local f = P({ Wedge = true, Size = V(0.05, 0.42, L), Color = (i % 2 == 0) and PALEGOLD or Color3.fromRGB(255, 252, 240), Transparency = 0.25 })
            table.insert(wings, { Part = f, Side = s, I = i, L = L })
        end
    end
    local function WingCF(w, open)
        -- root just behind the body; each feather turns out from straight up (folded) to its spread angle
        local spread = (20 + w.I * 16) * open
        local root = face * CF(w.Side * 0.25, 0.6, -0.3)
        -- (the feather's broad side faces you: its thin X axis points at the camera, its length runs up the wing)
        return root * ANG(0, 0, R(-w.Side * spread)) * CF(0, w.L / 2, 0) * CFrame.fromMatrix(Vector3.zero, V(0, 0, 1), V(1, 0, 0))
    end
    for _, w in ipairs(wings) do w.Part.CFrame = WingCF(w, 0) end
    -- pillar from the sky + its bright core
    local pillar = P({ Shape = Enum.PartType.Cylinder, Size = V(34, 2.2, 2.2), Color = Color3.fromRGB(255, 176, 40), Transparency = 0.45,
        CFrame = CF(ground + V(0, 17, 0)) * ANG(0, 0, R(90)) })
    local core = P({ Shape = Enum.PartType.Cylinder, Size = V(34, 0.6, 0.6), Color = GOLD, Transparency = 0.12, CFrame = pillar.CFrame })
    -- rune circle on the ground: a ring and tick marks, turning as they fade
    local rune = {}
    local rc = CF(ground + V(0, 0.06, 0))
    local n = low and 14 or 22
    for i = 0, n - 1 do
        local a = i / n * math.pi * 2
        table.insert(rune, { P({ Size = V(2.4 * math.pi * 2 / n * 1.05, 0.06, 0.1), Color = GOLD, Transparency = 0.15 }), a, 2.4, false })
        if i % 2 == 0 then table.insert(rune, { P({ Size = V(0.08, 0.06, 0.55), Color = PALEGOLD, Transparency = 0.2 }), a, 2.05, true }) end
    end
    -- light + feathers
    local light = Instance.new("PointLight")
    light.Color = PALEGOLD; light.Range = 20; light.Brightness = 5; light.Parent = core
    local att = Instance.new("Attachment"); att.Parent = burst
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = Art.Feather
    pe.Color = ColorSequence.new(Color3.fromRGB(255, 252, 240))
    pe.LightEmission = 0.4; pe.LightInfluence = 0
    pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.3) })
    pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
    pe.Lifetime = NumberRange.new(1.2, 1.8)
    pe.Speed = NumberRange.new(5, 10)
    pe.Acceleration = V(0, -4, 0)
    pe.Drag = 2.5
    pe.Rotation = NumberRange.new(0, 360); pe.RotSpeed = NumberRange.new(-150, 150)
    pe.SpreadAngle = Vector2.new(180, 180)
    pe.Rate = 0
    pe.Parent = att
    local sp = pe:Clone()
    sp.Texture = SPARK; sp.Color = ColorSequence.new(Color3.new(1, 1, 1), GOLD); sp.LightEmission = 1
    sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
    sp.Lifetime = NumberRange.new(0.5, 0.9); sp.Drag = 4; sp.Acceleration = V(0, 3, 0)
    sp.Parent = att
    folder.Parent = workspace
    pe:Emit(low and 8 or 16)
    sp:Emit(low and 12 or 26)
    -- animate it all (one loop, 1.5 s)
    local t0 = os.clock()
    local conn
    conn = RunService.RenderStepped:Connect(function()
        local t = os.clock() - t0
        if t > 1.5 or not folder.Parent then conn:Disconnect(); folder:Destroy(); return end
        local k = t / 1.5
        burst.Size = V(1, 1, 1) * (0.6 + 6 * math.min(t / 0.25, 1))
        burst.Transparency = math.min(1, 0.1 + t / 0.3)
        local open = math.clamp(t / 0.35, 0, 1)
        open = 1 - (1 - open) ^ 3
        local rise = math.max(0, t - 0.45) * 2.4
        for _, w in ipairs(wings) do
            w.Part.CFrame = CF(0, rise, 0) * WingCF(w, open)
            w.Part.Transparency = math.clamp(0.2 + math.max(0, t - 0.6) / 0.8, 0, 1)
        end
        local pk = math.clamp(t / 1.0, 0, 1)
        pillar.Size = V(34, 2.2 * (1 - pk) + 0.1, 2.2 * (1 - pk) + 0.1)
        pillar.Transparency = 0.45 + 0.55 * pk
        core.Size = V(34, 0.6 * (1 - pk) + 0.03, 0.6 * (1 - pk) + 0.03)
        core.Transparency = 0.12 + 0.88 * pk
        light.Brightness = 5 * (1 - pk)
        local spin = t * 0.9
        local grow = 0.7 + 0.5 * math.min(t / 0.3, 1)
        for _, r in ipairs(rune) do
            local p, a, rad, tick = r[1], r[2], r[3], r[4]
            p.CFrame = rc * ANG(0, a + spin * (tick and -1 or 1), 0) * CF(0, 0, -rad * grow)
            p.Transparency = math.clamp(0.15 + k ^ 1.5, 0, 1)
        end
    end)
end

-- ===== the KILL BANNER (Valorant-style): the Seraph emblem pops at the bottom of the screen, a pip per kill in
-- the current streak (up to 5), glowing brighter as the streak climbs. =====
local banner
-- ===== the INFERNAL kill banner: a TALLY seared in, one mark per kill (four strokes, the fifth slashed across
-- them), white-hot as it's scratched and cooling to crimson, with the streak's word under it; it jolts instead of
-- popping. Drawn from UI shapes (no image to load). =====
local ibanner
local CLAIM_WORDS = { "CLAIMED", "DAMNED", "CONDEMNED", "FORSAKEN", "DAMNATION" }
local function InfernalBanner(streak: number)
    local lp = Players.LocalPlayer
    local pg = lp and lp:FindFirstChild("PlayerGui")
    if not pg then return end
    if banner and banner.Root then banner.Root.Visible = false end
    streak = math.clamp(streak or 1, 1, 5)
    if not ibanner or not ibanner.Gui.Parent then
        local gui = Instance.new("ScreenGui")
        gui.Name = "InfernalKillBanner"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 5
        gui.Parent = pg
        local root = Instance.new("Frame")
        root.BackgroundTransparency = 1; root.AnchorPoint = Vector2.new(0.5, 1); root.Position = UDim2.new(0.5, 0, 1, -150)
        root.Size = UDim2.fromOffset(260, 130); root.Visible = false; root.Parent = gui
        local glow = Instance.new("ImageLabel")
        glow.BackgroundTransparency = 1; glow.Image = Art.Glow; glow.ImageColor3 = CRIMSON; glow.AnchorPoint = Vector2.new(0.5, 0.5)
        glow.Position = UDim2.fromScale(0.5, 0.4); glow.Size = UDim2.fromOffset(250, 140); glow.ImageTransparency = 0.5; glow.Parent = root
        local holder = Instance.new("Frame")
        holder.BackgroundTransparency = 1; holder.AnchorPoint = Vector2.new(0.5, 0.5); holder.Position = UDim2.fromScale(0.5, 0.38)
        holder.Size = UDim2.fromOffset(110, 70); holder.Parent = root
        local strokes = {}
        for i = 1, 5 do
            local fr = Instance.new("Frame")
            fr.BorderSizePixel = 0; fr.BackgroundColor3 = Color3.new(1, 1, 1)
            fr.AnchorPoint = Vector2.new(0.5, 0)
            if i <= 4 then
                fr.Position = UDim2.new(0.5, (i - 2.5) * 22, 0, 4); fr.Size = UDim2.fromOffset(7, 62); fr.Rotation = 7
            else
                fr.AnchorPoint = Vector2.new(0.5, 0.5)
                fr.Position = UDim2.fromScale(0.5, 0.5); fr.Size = UDim2.fromOffset(8, 112); fr.Rotation = 62
            end
            local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0, 3); cr.Parent = fr
            local g = Instance.new("UIGradient")
            g.Rotation = 90 -- (charred tips, white-hot middle, along the stroke)
            g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 10, 22)), ColorSequenceKeypoint.new(0.2, CRIMSON),
                ColorSequenceKeypoint.new(0.5, WHITEHOT), ColorSequenceKeypoint.new(0.8, CRIMSON), ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 10, 22)) })
            g.Parent = fr
            fr.Parent = holder
            strokes[i] = { Frame = fr, Full = fr.Size }
        end
        local word = Instance.new("TextLabel")
        word.BackgroundTransparency = 1; word.AnchorPoint = Vector2.new(0.5, 1); word.Position = UDim2.fromScale(0.5, 1)
        word.Size = UDim2.fromOffset(260, 34); word.Font = Enum.Font.Fondamento; word.TextSize = 30
        word.TextColor3 = Color3.fromRGB(255, 214, 200); word.Text = ""
        word:SetAttribute("KeepFont", true) -- (UIStyle would swap the gothic face for the HUD font)
        word.Parent = root
        local ws = Instance.new("UIStroke"); ws.Color = Color3.fromRGB(120, 8, 24); ws.Thickness = 2; ws.Parent = word
        ibanner = { Gui = gui, Root = root, Glow = glow, Strokes = strokes, Word = word, WordStroke = ws, Token = 0 }
    end
    local b = ibanner
    b.Token += 1
    local token = b.Token
    b.Root.Visible = true
    b.Word.Text = CLAIM_WORDS[streak]
    b.Word.TextTransparency, b.WordStroke.Transparency = 0, 0
    b.Word.TextColor3 = (streak >= 5) and WHITEHOT or Color3.fromRGB(255, 214, 200)
    b.Glow.ImageTransparency = math.max(0.12, 0.55 - streak * 0.08)
    for i, st in ipairs(b.Strokes) do
        local fr = st.Frame
        fr.Size = st.Full
        if i < streak then
            fr.BackgroundTransparency = 0; fr.BackgroundColor3 = Color3.fromRGB(200, 120, 120) -- (cooled)
        elseif i == streak then
            -- the newest mark is SEARED in: scratched from nothing, white-hot, then it cools
            fr.BackgroundTransparency = 0; fr.BackgroundColor3 = Color3.new(1, 1, 1)
            fr.Size = UDim2.fromOffset(st.Full.X.Offset, 0)
            TweenService:Create(fr, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = st.Full }):Play()
            task.delay(0.15, function()
                if b.Token == token then TweenService:Create(fr, TweenInfo.new(0.7), { BackgroundColor3 = Color3.fromRGB(200, 120, 120) }):Play() end
            end)
        else
            fr.BackgroundTransparency = 0.88; fr.BackgroundColor3 = Color3.fromRGB(120, 60, 70) -- (a faint scratch waiting)
        end
    end
    -- a jolt, not a pop
    task.spawn(function()
        for _ = 1, 6 do
            if b.Token ~= token then return end
            b.Root.Position = UDim2.new(0.5, math.random(-4, 4), 1, -150 + math.random(-3, 3))
            task.wait(0.025)
        end
        b.Root.Position = UDim2.new(0.5, 0, 1, -150)
    end)
    task.delay(1.5, function()
        if b.Token ~= token then return end
        local ti = TweenInfo.new(0.4)
        TweenService:Create(b.Glow, ti, { ImageTransparency = 1 }):Play()
        TweenService:Create(b.Word, ti, { TextTransparency = 1 }):Play()
        TweenService:Create(b.WordStroke, ti, { Transparency = 1 }):Play()
        for _, st in ipairs(b.Strokes) do TweenService:Create(st.Frame, ti, { BackgroundTransparency = 1 }):Play() end
        task.delay(0.42, function() if b.Token == token then b.Root.Visible = false end end)
    end)
end
-- one kill banner on screen at a time: every banner registers a hide function here
SkinFX.BannerHiders = {}
local function HideBanners(except: string?)
    for k, f in pairs(SkinFX.BannerHiders) do if k ~= except then pcall(f) end end
end
SkinFX.HideBanners = HideBanners
function SkinFX.KillBanner(streak: number, kind: string?)
    local set = SkinFX.Sets[kind or ""]
    if set then
        HideBanners(kind)
        if banner and banner.Root then banner.Root.Visible = false end
        if ibanner and ibanner.Root then ibanner.Root.Visible = false end
        SkinFX.BannerSuffix = string.match(kind or "", "#%d+$") or ""
        if set.Banner then pcall(set.Banner, SkinFX.H, math.clamp(streak or 1, 1, 5)) end
        SkinFX.BannerSuffix = ""
        return
    end
    HideBanners()
    if kind == "Infernal" then return InfernalBanner(streak) end
    if ibanner and ibanner.Root then ibanner.Root.Visible = false end
    local infernal = false
    local cMain, cSoft, cDim, cEdge = (infernal and CRIMSON or GOLD), (infernal and VIOLET or PALEGOLD), (infernal and Color3.fromRGB(50, 24, 40) or Color3.fromRGB(60, 50, 34)), (infernal and HELLIRON or GOLDMETAL)
    local lp = Players.LocalPlayer
    local pg = lp and lp:FindFirstChild("PlayerGui")
    if not pg then return end
    if not banner or not banner.Gui.Parent then
        local gui = Instance.new("ScreenGui")
        gui.Name = "SkinKillBanner"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 5
        gui.Parent = pg
        local root = Instance.new("Frame")
        root.BackgroundTransparency = 1; root.AnchorPoint = Vector2.new(0.5, 1); root.Position = UDim2.new(0.5, 0, 1, -150)
        root.Size = UDim2.fromOffset(300, 170); root.Visible = false; root.Parent = gui
        local scale = Instance.new("UIScale"); scale.Parent = root
        local glow = Instance.new("ImageLabel")
        glow.BackgroundTransparency = 1; glow.Image = Art.Glow; glow.ImageColor3 = GOLD; glow.AnchorPoint = Vector2.new(0.5, 0.5)
        glow.Position = UDim2.fromScale(0.5, 0.42); glow.Size = UDim2.fromOffset(330, 200); glow.ImageTransparency = 0.4; glow.Parent = root
        local rays = Instance.new("ImageLabel")
        rays.BackgroundTransparency = 1; rays.Image = Art.Rays; rays.ImageColor3 = PALEGOLD; rays.AnchorPoint = Vector2.new(0.5, 0.5)
        rays.Position = UDim2.fromScale(0.5, 0.42); rays.Size = UDim2.fromOffset(260, 260); rays.ImageTransparency = 0.55; rays.Parent = root
        local em = Instance.new("ImageLabel")
        em.BackgroundTransparency = 1; em.Image = Art.EmblemSeraph; em.AnchorPoint = Vector2.new(0.5, 0.5)
        em.Position = UDim2.fromScale(0.5, 0.42); em.Size = UDim2.fromOffset(250, 125); em.Parent = root
        local pips = {}
        for i = 1, 5 do
            local p = Instance.new("Frame")
            p.AnchorPoint = Vector2.new(0.5, 0.5); p.Position = UDim2.new(0.5, (i - 3) * 22, 1, -14); p.Size = UDim2.fromOffset(12, 12)
            p.Rotation = 45; p.BorderSizePixel = 0; p.BackgroundColor3 = Color3.fromRGB(60, 50, 34); p.Parent = root
            local st = Instance.new("UIStroke"); st.Color = GOLDMETAL; st.Thickness = 1.5; st.Parent = p
            pips[i] = p
        end
        banner = { Gui = gui, Root = root, Scale = scale, Glow = glow, Rays = rays, Emblem = em, Pips = pips, Token = 0 }
        RunService.RenderStepped:Connect(function()
            if banner and banner.Root.Visible then banner.Rays.Rotation = (os.clock() * 25) % 360 end
        end)
    end
    local b = banner
    b.Token += 1
    local token = b.Token
    b.Root.Visible = true
    -- (one banner for every set: its emblem + colours follow the skin that got the kill)
    b.Emblem.Image = infernal and (Art.EmblemInfernal or Art.EmblemSeraph) or Art.EmblemSeraph
    b.Glow.ImageColor3, b.Rays.ImageColor3 = cMain, cSoft
    for i, p in ipairs(b.Pips) do
        p.BackgroundColor3 = (i <= streak) and cSoft or cDim
        local st = p:FindFirstChildOfClass("UIStroke")
        if st then st.Color = cEdge end
    end
    b.Scale.Scale = 1.35
    TweenService:Create(b.Scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 + (streak - 1) * 0.04 }):Play()
    for _, img in ipairs({ b.Emblem, b.Glow, b.Rays }) do img.ImageTransparency = (img == b.Emblem) and 0 or (img == b.Glow and math.max(0.05, 0.45 - streak * 0.08) or 0.5) end
    task.delay(1.4, function()
        if b.Token ~= token then return end
        local ti = TweenInfo.new(0.35)
        TweenService:Create(b.Emblem, ti, { ImageTransparency = 1 }):Play()
        TweenService:Create(b.Glow, ti, { ImageTransparency = 1 }):Play()
        TweenService:Create(b.Rays, ti, { ImageTransparency = 1 }):Play()
        task.delay(0.36, function() if b.Token == token then b.Root.Visible = false end end)
    end)
end
SkinFX.BannerHiders.Seraphim = function() if banner and banner.Root then banner.Root.Visible = false end end
SkinFX.BannerHiders.Infernal = function() if ibanner and ibanner.Root then ibanner.Root.Visible = false end end

-- ===================================================================================================================
-- SKIN SETS (2026-10-04 night, owner's Skin References note: "a skin for every gun in the game ... group them into
-- bundles ... finish one full bundle at a time"). Each set lives in its own module under AimRngShared.SkinSets and
-- brings EVERYTHING of its own -- gun skins + decoration builders, first / third person drivers, muzzle, tracer,
-- impact, kill effect, kill banner, sound pack, melee, glove, sleeve, health bar, bundle -- so no two sets share a
-- motion. SkinFX only routes to it (SkinFX.Sets[kind]); the helpers below are the shared toolbox (H) a set builds with.
-- ===================================================================================================================
-- (FX AUDIT 2026-10-14, Studio only: workspace attr DevFxSlow = 0.05..1 plays every effect in slow motion for captures)
local function DevSlow(): number
    if not RunService:IsStudio() then return 1 end
    local k = tonumber(workspace:GetAttribute("DevFxSlow"))
    return (k and k > 0 and k < 1) and k or 1
end
SkinFX.DevSlow = DevSlow
local function FxFolder(): Folder
    local f = workspace:FindFirstChild("SkinFxWorld")
    if not f then f = Instance.new("Folder"); f.Name = "SkinFxWorld"; f.Parent = workspace end
    return f
end
-- a loose world-effect part: anchored, no collision / queries / shadow, Neon unless told otherwise
local function FxPart(props: any, parent: Instance?): BasePart
    local p = Instance.new(props.Wedge and "WedgePart" or "Part")
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Material = props.Material or Enum.Material.Neon
    for k, v in pairs(props) do
        if k ~= "Wedge" and k ~= "Material" then p[k] = v end
    end
    Ellipsoid(p, props.Size)
    p.Parent = parent or FxFolder()
    return p
end
-- a particle emitter from a short spec: { Texture, Color = {a, b?}, Size = n | {n0, n1}, Life = {lo, hi}, Speed = {lo, hi},
-- Rate, Spread, Accel, Drag, Emission, Light, Locked, Rot, Spin, Trans = {t0, t1}, Dir (NormalId), Shape, InOut, Name }
local function Emitter(parent: Instance, o: any): ParticleEmitter
    local pe = Instance.new("ParticleEmitter")
    pe.Name = o.Name or "SkinFx"
    pe.Texture = o.Texture or SPARK
    local c = o.Color or { Color3.new(1, 1, 1) }
    pe.Color = (typeof(c) == "ColorSequence") and c or ColorSequence.new(c[1], c[2] or c[1])
    local sz = o.Size or 0.2
    pe.Size = (type(sz) == "number") and NumberSequence.new({ NumberSequenceKeypoint.new(0, sz), NumberSequenceKeypoint.new(1, 0) })
        or (typeof(sz) == "NumberSequence" and sz) or NumberSequence.new({ NumberSequenceKeypoint.new(0, sz[1]), NumberSequenceKeypoint.new(1, sz[2]) })
    local tr = o.Trans or { 0, 1 }
    pe.Transparency = (typeof(tr) == "NumberSequence") and tr or NumberSequence.new(tr[1], tr[2])
    pe.Lifetime = NumberRange.new((o.Life or { 0.4, 0.7 })[1], (o.Life or { 0.4, 0.7 })[2])
    pe.Speed = NumberRange.new((o.Speed or { 1, 2 })[1], (o.Speed or { 1, 2 })[2])
    pe.Rate = o.Rate or 0
    pe.SpreadAngle = Vector2.new(o.Spread or 180, o.Spread or 180)
    pe.Acceleration = o.Accel or Vector3.zero
    pe.Drag = o.Drag or 0
    pe.LightEmission = o.Light or 1
    pe.LightInfluence = o.Influence or 0
    pe.LockedToPart = o.Locked == true
    if o.Rot then pe.Rotation = NumberRange.new(o.Rot[1], o.Rot[2]) end
    if o.Spin then pe.RotSpeed = NumberRange.new(o.Spin[1], o.Spin[2]) end
    if o.Dir then pe.EmissionDirection = o.Dir end
    if o.Shape then pe.Shape = o.Shape end
    if o.InOut then pe.ShapeInOut = o.InOut end
    if o.Style then pe.ShapeStyle = o.Style end
    if o.Orient then pe.Orientation = o.Orient end
    if o.Squash then pe.Squash = o.Squash end
    if o.SkinFx then pe:SetAttribute("SkinFx", true) end
    local slow = DevSlow()
    if slow < 1 then pe.TimeScale = slow end
    pe.Parent = parent
    return pe
end
-- an attachment on `host` at a WORLD position (or host-space offset when local = true)
local function Att(host: Instance, pos: Vector3?, isLocal: boolean?): Attachment
    local a = Instance.new("Attachment")
    if pos then
        if isLocal or not host:IsA("BasePart") then a.Position = pos else a.Position = (host :: BasePart).CFrame:PointToObjectSpace(pos) end
    end
    a.Parent = host
    return a
end
-- the floor under a point (12 studs down), or 2.5 below it
local function Ground(pos: Vector3): Vector3
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local ex = { FxFolder() }
    for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
    if workspace.CurrentCamera then table.insert(ex, workspace.CurrentCamera) end
    rp.FilterDescendantsInstances = ex
    -- (FX AUDIT 2026-10-14: a kill effect fires while the dying body is still there, so the ray stopped on its own torso /
    -- stand and every "ground" effect -- rings, pools, drapes, curtains -- floated at chest height. Skip any part of a
    -- body (a model with a Head / Torso / Humanoid) and anything see-through, up to 4 times.)
    local hit
    for _ = 1, 4 do
        hit = workspace:Raycast(pos, V(0, -12, 0), rp)
        if not hit then break end
        local inst = hit.Instance
        local m = inst:FindFirstAncestorOfClass("Model")
        local body = m and (m:FindFirstChild("Head") or m:FindFirstChild("Torso") or m:FindFirstChildOfClass("Humanoid")) and m
        if not body and inst.Transparency < 0.95 then break end
        table.insert(ex, body or inst)
        rp.FilterDescendantsInstances = ex
        hit = nil
    end
    return hit and hit.Position or (pos - V(0, 2.5, 0))
end
-- run fn(t, dt) every frame for `dur` seconds (t from 0), then done(); returns a stop function. One RenderStepped
-- connection per effect, always disconnected.
local function Animate(dur: number, fn: (number, number) -> (), done: (() -> ())?)
    local t0 = os.clock()
    local last = t0
    local slow = DevSlow()
    local conn
    local function stop()
        if conn then conn:Disconnect(); conn = nil end
        if done then local d = done; done = nil; pcall(d) end
    end
    conn = RunService.RenderStepped:Connect(function()
        local now = os.clock()
        local t = (now - t0) * slow
        if t >= dur then stop(); return end
        local ok, err = pcall(fn, t, (now - last) * slow)
        last = now
        if not ok then warn("[SkinFX] effect: " .. tostring(err)); stop() end
    end)
    return stop
end
-- where your gun is: third person = the world gun, first person = just right of / below the camera
local function GunTarget(): Vector3
    local lp = Players.LocalPlayer
    local char = lp and lp.Character
    if lp and lp:GetAttribute("ThirdPerson") == true and char then
        local g = char:FindFirstChild("WorldGun")
        local fr = g and g:FindFirstChild("Frame")
        if fr then return fr.Position end
    end
    local cam = workspace.CurrentCamera
    return cam and (cam.CFrame * CF(0.7, -0.5, -1.9)).Position or V(0, 0, 0)
end
-- a kill-banner root: one ScreenGui per set, a frame anchored bottom-centre 150 px up. Rebuilt if it was destroyed.
-- (SKINS V3) anchor "Side": beside the HUD's weapon card instead of bottom-centre (the plan's banner rule: ours, off the
-- crosshair, not another game's layout). The card is the bottom of the HUD stack (AimRngClient UI.HudStack, bottom-left,
-- X 16 / W 400 / Bottom 16 / WeaponH 100): the banner sits just right of it, bottom-aligned, and scales with the HUD
-- (BANNER_SIDE; the client may overwrite it from its layout: SkinFX.BANNER_SIDE = { X, Bottom, Scale }).
SkinFX.BANNER_SIDE = { X = 16 + 400 + 14, Bottom = 16, Scale = 1 }
local bannerRoots = {}
SkinFX.BannerSuffix = "" -- (colourways: "#v" while a variant set draws its banner, so it gets its own root)
local function BannerRoot(name: string, size: Vector2, anchor: string?): (ScreenGui?, Frame?)
    local suf = SkinFX.BannerSuffix
    if suf ~= "" and not string.find(name, "#", 1, true) then name = name .. suf end
    local lp = Players.LocalPlayer
    local pg = lp and lp:FindFirstChild("PlayerGui")
    if not pg then return nil, nil end
    local function Side(root: Frame)
        -- (follows the HUD's own UIScale -- "AimRngMasterHUD" -- so it stays beside the weapon card at any UI scale)
        local sd = SkinFX.BANNER_SIDE
        local hud = pg:FindFirstChild("AimRngMasterHUD")
        local us = hud and hud:FindFirstChildOfClass("UIScale")
        local k = (us and us.Scale) or sd.Scale or 1
        root.AnchorPoint = Vector2.new(0, 1)
        root.Position = UDim2.new(0, sd.X * k, 1, -sd.Bottom * k)
        local s = root:FindFirstChild("SideScale") or Instance.new("UIScale")
        s.Name = "SideScale"; s.Scale = k; s.Parent = root
    end
    local r = bannerRoots[name]
    if r and r.Gui.Parent then
        if r.Side then Side(r.Root) end
        return r.Gui, r.Root
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = name .. "KillBanner"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 5
    gui.Parent = pg
    local root = Instance.new("Frame")
    root.BackgroundTransparency = 1; root.AnchorPoint = Vector2.new(0.5, 1); root.Position = UDim2.new(0.5, 0, 1, -150)
    if anchor == "Side" then Side(root) end
    root.Size = UDim2.fromOffset(size.X, size.Y); root.Visible = false; root.Parent = gui
    bannerRoots[name] = { Gui = gui, Root = root, Side = anchor == "Side" }
    SkinFX.BannerHiders[name] = function() root.Visible = false end
    return gui, root
end
-- (SKINS V3, gate C12) one level-of-detail rule for every set's kill effect: "skip" when a kill effect already played in
-- the last KILL_GAP s and 3 are alive, "low" with Particles = Reduced or when kills come faster than KILL_GAP, else "full"
SkinFX.KILL_GAP = 0.5
local lastKillFx, killFxAlive = 0, 0
local function KillLod(): string
    local now = os.clock()
    local fast = now - lastKillFx < SkinFX.KILL_GAP
    lastKillFx = now
    if fast and killFxAlive >= 3 then return "skip" end
    killFxAlive += 1
    task.delay(1.5, function() killFxAlive = math.max(0, killFxAlive - 1) end)
    if fast or LowFx() then return "low" end
    return "full"
end
-- an effect budget: false when `key` already has `max` effects alive (each lives `life` seconds)
local budgets = {}
local function Budget(key: string, max: number, life: number): boolean
    local n = budgets[key] or 0
    if n >= max then return false end
    budgets[key] = n + 1
    task.delay(life, function() budgets[key] = math.max(0, (budgets[key] or 1) - 1) end)
    return true
end
-- a UI element helper for banners: New("Frame", { props }, parent, { children })
local function New(class: string, props: any, parent: Instance?, kids: { Instance }?): Instance
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    for _, c in ipairs(kids or {}) do c.Parent = o end
    if parent then o.Parent = parent end
    return o
end
SkinFX.H = {
    Deco = Deco, Hinge = Hinge, Rotor = Rotor, Pulse = Pulse, Ring = Ring, FlowBeam = FlowBeam,
    V = V, CF = CF, ANG = ANG, R = R, SPARK = SPARK, FIRE = FIRE, SMOKE = "rbxasset://textures/particles/smoke_main.dds",
    Art = Art, LowFx = LowFx, FxFolder = FxFolder, FxPart = FxPart, Emitter = Emitter, Att = Att, Ground = Ground,
    Animate = Animate, GunTarget = GunTarget, BannerRoot = BannerRoot, Budget = Budget, New = New, KillLod = KillLod,
    -- (2026-10-22 HITSCAN LOOK, owner: "There should be no projectiles at all. With the way the bullets are, it makes them
    -- look like projectiles"): guns are hitscan, so a tracer's whole line is there on the shot frame and fades IN PLACE --
    -- no head travelling to the target, no tail chasing it. Set tracers use TRAVEL for their old head-travel time.
    TRAVEL = 0.001,
    CloneModel = SkinFX.CloneModel, V3Swap = SkinFX.V3Swap, ModelSource = SkinFX.ModelSource,
    TweenService = TweenService, RunService = RunService, Debris = Debris, Players = Players, SoundService = SoundService,
}

-- ===== BLADE OUTLINES (0.93 melee redesign, owner: "cooler ones, such as befitting knives and swords" -- Valorant-style
-- melee silhouettes): H.Tri builds a flat triangle from two WedgeParts; H.Blade builds a blade from STATIONS -- pairs of
-- points { spineX, spineY, edgeX, edgeY } in the model's XY plane (Y = up the weapon, the blade lies flat in XY, thin in Z)
-- -- each pair of stations is a quad. The body runs from the spine to (1 - EdgeFrac) of the way across, the bevelled edge
-- band is thinner and its own colour (Glow = neon edge); Inlays are thin glowing strips on both faces between fractions A..B
-- across. The first body piece is renamed "Blade" (the swing trail hangs off it); Trail = { ColorA, ColorB } adds it.
do
    local function Tri(m: Model, a: Vector3, b: Vector3, c: Vector3, thick: number, props: any): { BasePart }
        local ab, ac, bc = b - a, c - a, c - b
        local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
        if abd > acd and abd > bcd then c, a = a, c
        elseif acd > bcd and acd > abd then a, b = b, a end
        ab, ac, bc = b - a, c - a, c - b
        local rc = ac:Cross(ab)
        if rc.Magnitude < 1e-7 or bc.Magnitude < 1e-5 then return {} end
        local right = rc.Unit
        local up = bc:Cross(right).Unit
        local back = bc.Unit
        local height = math.abs(ab:Dot(up))
        if height < 2e-4 then return {} end
        local out = {}
        local w1, w2 = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
        for i, spec in ipairs({ { w1, (a + b) / 2, right, back }, { w2, (a + c) / 2, -right, -back } }) do
            if spec[1] > 2e-4 then
                local pr = table.clone(props)
                pr.Wedge = true
                pr.Size = Vector3.new(thick, height, spec[1])
                pr.CFrame = CFrame.fromMatrix(spec[2], spec[3], up, spec[4])
                table.insert(out, Deco(m, pr))
            end
        end
        return out
    end
    local function Lerp2(st: any, f: number, z: number): Vector3
        return Vector3.new(st[1] + (st[3] - st[1]) * f, st[2] + (st[4] - st[2]) * f, z)
    end
    local function Band(m: Model, stations: any, f0: number, f1: number, z: number, thick: number, props: any, out: any)
        for i = 1, #stations - 1 do
            local s0, s1 = stations[i], stations[i + 1]
            local p1, p2, p3, p4 = Lerp2(s0, f0, z), Lerp2(s0, f1, z), Lerp2(s1, f1, z), Lerp2(s1, f0, z)
            for _, p in ipairs(Tri(m, p1, p2, p3, thick, props)) do table.insert(out, p) end
            for _, p in ipairs(Tri(m, p1, p3, p4, thick, props)) do table.insert(out, p) end
        end
    end
    local function Blade(m: Model, o: any): { BasePart }
        local st = o.Stations
        -- (0.97 VALORANT MELEES: the set blades read as thin slivers next to Valorant's broad blades -> every blade widens
        -- from its spine by BLADE_WIDEN (o.Widen overrides; 1 = as built). Tips (spine = edge) stay points.)
        local wf = o.Widen or SkinFX.BLADE_WIDEN
        if wf ~= 1 then
            local wide = {}
            for i, p in ipairs(st) do wide[i] = { p[1], p[2], p[1] + (p[3] - p[1]) * wf, p[2] + (p[4] - p[2]) * wf } end
            st = wide
        end
        -- (0.97 UPDATE 3, owner: "the edge (or blade?) looks kind of silly and too thick"): after BLADE_WIDEN the bright edge
        -- band ran ~30% of the blade's width like a second blade -- it is now a thin polished strip (EDGE_MAX of the width)
        -- and the blade itself never thicker than BLADE_MAX_THICK
        local t = math.min(o.Thick or 0.03, SkinFX.BLADE_MAX_THICK)
        local z = o.Z or 0
        local ef = math.min(o.EdgeFrac or 0.3, SkinFX.EDGE_MAX)
        local body = {}
        Band(m, st, 0, 1 - ef, z, t, { Name = o.Name or "BladeBody", Color = o.Color, Material = o.Material or Enum.Material.SmoothPlastic,
            Reflectance = o.Reflectance or 0.1, Metal = o.Metal, Zone = "Blade" }, body)
        local edge = {}
        -- BEVELS (0.97 VALORANT MELEES, owner: "The current melees are really bad ... the way they look"): Valorant blades
        -- read as forged metal because of a lighter polished bevel facet running beside the edge and a darker spine ridge on
        -- BOTH faces. Two thin overlay bands per face (o.NoBevel turns them off)
        if not o.NoBevel and #st <= 9 then
            local bevCol = (o.BevelColor or o.Color:Lerp(Color3.new(1, 1, 1), 0.32))
            local spineCol = (o.SpineColor or o.Color:Lerp(Color3.new(0, 0, 0), 0.35))
            local bw = o.BevelWidth or 0.2
            for _, sz in ipairs({ -1, 1 }) do
                Band(m, st, math.max(0, 1 - ef - bw), 1 - ef, z + sz * (t / 2 + 0.0015), 0.003, { Name = "BladeBevel", Color = bevCol,
                    Material = Enum.Material.SmoothPlastic, Reflectance = 0.18, Zone = "Blade" }, edge)
                Band(m, st, 0, 0.1, z + sz * (t / 2 + 0.0015), 0.003, { Name = "BladeSpine", Color = spineCol,
                    Material = Enum.Material.SmoothPlastic, Zone = "Blade" }, edge)
            end
        end
        if ef > 0 then
            Band(m, st, 1 - ef, 1, z, t * (o.EdgeThin or 0.45), { Name = "BladeEdge", Color = o.EdgeColor or o.Color, Glow = o.EdgeGlow,
                Material = (not o.EdgeGlow) and (o.EdgeMaterial or Enum.Material.SmoothPlastic) or nil, Reflectance = o.EdgeGlow and 0 or 0.25, Zone = "Edge" }, edge)
        end
        if o.BackEdge then -- (double-edged: a second band along the spine side)
            Band(m, st, 0, o.BackEdge, z, t * (o.EdgeThin or 0.45) * 1.02, { Name = "BladeEdge", Color = o.EdgeColor or o.Color, Glow = o.EdgeGlow,
                Material = (not o.EdgeGlow) and Enum.Material.SmoothPlastic or nil, Zone = "Edge" }, edge)
        end
        for _, inl in ipairs(o.Inlays or {}) do
            local from, to = inl.From or 1, inl.To or #st
            local sub = {}
            for i = from, to do table.insert(sub, st[i]) end
            for _, sz in ipairs({ -1, 1 }) do
                Band(m, sub, inl.A, inl.B, z + sz * (t / 2 + 0.002), 0.004, { Name = inl.Name or "BladeInlay", Color = inl.Color, Glow = inl.Glow ~= false, Zone = "Blade" }, edge)
            end
        end
        local first = body[1]
        if first then
            first.Name = "Blade"
            if o.Trail then
                local s0, sN = st[1], st[#st]
                local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
                a0.Name, a1.Name = "TrailBase", "TrailTip"
                a0.Position = first.CFrame:PointToObjectSpace(Vector3.new((s0[1] + s0[3]) / 2, (s0[2] + s0[4]) / 2, z))
                a1.Position = first.CFrame:PointToObjectSpace(Vector3.new((sN[1] + sN[3]) / 2, (sN[2] + sN[4]) / 2, z))
                a0.Parent, a1.Parent = first, first
                local tr = Instance.new("Trail")
                tr.Attachment0, tr.Attachment1 = a0, a1
                tr.Color = ColorSequence.new(o.Trail[1], o.Trail[2] or o.Trail[1])
                tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
                tr.LightEmission = 0.8; tr.LightInfluence = 0
                tr.Lifetime = 0.16; tr.MinLength = 0.02; tr.FaceCamera = true
                tr.Enabled = false
                tr:SetAttribute("SwingTrail", true)
                tr.Parent = first
            end
        end
        for _, p in ipairs(edge) do table.insert(body, p) end
        return body
    end
    -- a wrapped grip along Y from y0 to y1: core cylinder + diamond wrap bands (Wrap colour) + optional end caps
    local function Grip(m: Model, o: any)
        local y0, y1, r = o.Y0, o.Y1, o.R or 0.045
        local len = y1 - y0
        -- (0.97 VALORANT MELEES: a faceted octagonal handle -- two square prisms 45 deg apart -- instead of a smooth tube;
        -- the facets catch light like a sculpted grip. o.Round keeps the old cylinder)
        local g
        if o.Round then
            g = Deco(m, { Name = "Grip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, r * 2, r * 2),
                CFrame = CFrame.new(o.X or 0, (y0 + y1) / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = o.Color, Material = o.Material or Enum.Material.SmoothPlastic })
        else
            local w = r * 2 * 0.93
            g = Deco(m, { Name = "Grip", Size = Vector3.new(w, len, w), CFrame = CFrame.new(o.X or 0, (y0 + y1) / 2, 0), Color = o.Color, Material = o.Material or Enum.Material.SmoothPlastic })
            Deco(m, { Name = "GripFacet", Size = Vector3.new(w, len * 0.999, w), CFrame = CFrame.new(o.X or 0, (y0 + y1) / 2, 0) * CFrame.Angles(0, math.rad(45), 0),
                Color = (o.Color or Color3.new(0.2, 0.2, 0.2)):Lerp(Color3.new(1, 1, 1), 0.06), Material = o.Material or Enum.Material.SmoothPlastic })
        end
        g.Name = "Grip"
        if o.Wrap then
            local n = o.Wraps or math.max(3, math.floor(len / 0.07))
            -- clean ribbed bands (the tilted diamond wraps read as chunky boxes up close)
            for k = 0, n - 1 do
                local y = y0 + (k + 0.5) * len / n
                Deco(m, { Name = "GripWrap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len / n * 0.32, r * 2.12, r * 2.12),
                    CFrame = CFrame.new(o.X or 0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = o.Wrap, Material = o.WrapMaterial or Enum.Material.SmoothPlastic })
            end
        end
        return g
    end
    SkinFX.BLADE_WIDEN = 1.4
    SkinFX.EDGE_MAX = 0.11
    SkinFX.BLADE_MAX_THICK = 0.028
    SkinFX.BladeKit = { Tri = Tri, Blade = Blade, Grip = Grip }
    SkinFX.H.Tri, SkinFX.H.Blade, SkinFX.H.Grip = Tri, Blade, Grip
end

-- the set's tracer + impact for a shot (first person: ViewmodelRig:Tracer; other players' shots: AimRngClient ShotFx).
-- -> true when a set drew it
-- (0.62, owner: "shooting in general lights up your whole screen white ... a lot of the shots reflect off of the
-- environment"): every shot's tracer / impact used to add its own bright light where it landed -- a wall right in front of
-- you lit up white (bloom) on every round. TAME runs an effect builder and caps any light it makes; impacts close to the
-- camera keep no light at all, and an impact's flash plays at most every IMPACT_GAP s.
SkinFX.LIGHT_MAX = { Brightness = 0.8, Range = 8 }
SkinFX.IMPACT_GAP = 0.1
local lastImpact = 0
function SkinFX.Tame(near: boolean?, fn: any, ...): (boolean, any)
    local lights = {}
    local conn = workspace.DescendantAdded:Connect(function(d)
        if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then table.insert(lights, d) end
    end)
    local ok, err = pcall(fn, ...)
    conn:Disconnect()
    for _, l in ipairs(lights) do
        if near then l.Enabled = false; l.Brightness = 0
        else l.Brightness = math.min(l.Brightness, SkinFX.LIGHT_MAX.Brightness); l.Range = math.min(l.Range, SkinFX.LIGHT_MAX.Range) end
    end
    return ok, err
end
function SkinFX.ShotFx(kind: string?, from: Vector3, to: Vector3, normal: Vector3?, peer: boolean?): boolean
    local set = SkinFX.Sets[kind or ""]
    if not set then return false end
    local cam = workspace.CurrentCamera
    local near = cam ~= nil and (to - cam.CFrame.Position).Magnitude < 14
    if set.Tracer then
        local ok, err = SkinFX.Tame(false, set.Tracer, SkinFX.H, from, to, peer)
        if not ok then warn("[SkinFX] tracer: " .. tostring(err)) end
    end
    if normal and set.Impact and os.clock() - lastImpact >= SkinFX.IMPACT_GAP then
        lastImpact = os.clock()
        SkinFX.Tame(near, set.Impact, SkinFX.H, to, normal, peer)
    end
    return true
end

-- load every set: its gun skins join the catalog, its builders join BUILD (called with H as a 5th argument)
do
    local folder = script.Parent:FindFirstChild("SkinSets") or script.Parent:WaitForChild("SkinSets", 5)
    local ok, Sets = pcall(function() return folder and require(folder) end)
    if ok and type(Sets) == "table" then
        for _, set in ipairs(Sets.List or {}) do
            SkinFX.Sets[set.Kind] = set
            table.insert(SkinFX.SetOrder, set)
            for name, fn in pairs(set.Build or {}) do
                BUILD[name] = function(model, frame, f, forView) return fn(model, frame, f, forView, SkinFX.H) end
            end
            for _, s in ipairs(set.GunSkins or {}) do
                s.FX = s.FX or set.Kind
                s.Set = s.Set or set.Kind
                table.insert(SkinFX.GunSkins, s)
                SkinFX.GunSkinById[s.Id] = s
            end
            if set.Colors then for k, c in pairs(set.Colors) do SkinFX.Colors[set.Kind .. k] = c end end
        end
    elseif not ok then
        warn("[SkinFX] SkinSets failed to load: " .. tostring(Sets))
    end
end

-- ===== COLORWAYS (0.93, AimRngShared.Colorways) =====
-- SkinFX.Sets["Tempest#2"] loads a second copy of the set's module with attribute Colorway = 2: its C3 maps every colour,
-- so the whole set (decorations, tracers, impacts, kill effect, banner, melee, gloves, sleeves, bar) is recoloured. Its
-- gun skins keep their Ids (ownership) with FX = "Tempest#2", Surface "<map>_V2" and builders "<Build>#2". Each machine
-- (server: world gear, clients: first person + other players' guns) loads the copies it needs, once.
do
    local Colorways = require(script.Parent:WaitForChild("Colorways"))
    SkinFX.Colorways = Colorways
    local function LoadVariant(kind: string, v: number): any
        local folder = script.Parent:FindFirstChild("SkinSets")
        local src = folder and folder:FindFirstChild(kind)
        if not (rawget(SkinFX.Sets, kind) and src and Colorways.Info(kind, v)) then return nil end
        local key = kind .. "#" .. v
        local m = src:Clone()
        m.Name = key
        m:SetAttribute("Colorway", v)
        local ok, set = pcall(require, m)
        if not ok or type(set) ~= "table" then warn("[SkinFX] colourway " .. key .. ": " .. tostring(set)) return nil end
        set.Kind, set.BaseKind, set.Variant = key, kind, v
        for name, fn in pairs(set.Build or {}) do
            BUILD[name .. "#" .. v] = function(model, frame, f, forView) return fn(model, frame, f, forView, SkinFX.H) end
        end
        set.SkinById = {}
        for _, s in ipairs(set.GunSkins or {}) do
            s.FX, s.Set, s.Variant = key, kind, v
            if s.Surface then s.Surface = s.Surface .. "_V" .. v end
            if s.Deco then s.Deco = s.Deco .. "#" .. v end
            set.SkinById[s.Id] = s
        end
        if set.Colors then for k, c in pairs(set.Colors) do SkinFX.Colors[key .. k] = c end end
        return set
    end
    setmetatable(SkinFX.Sets, { __index = function(t, key)
        if type(key) ~= "string" then return nil end
        local kind, v = Colorways.Parse(key)
        if v <= 1 or kind == key then return nil end
        local set = LoadVariant(kind, v)
        rawset(t, key, set or false)
        return set or nil
    end })
end

return SkinFX
