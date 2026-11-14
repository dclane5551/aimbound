--!nocheck
-- ===================================================================================================================
-- FERROFLUX (Skins V3, bundle 1 of docs/SKINS_V3_PLAN.md): AK-47 + G17 + Hyperion | Flux Scythe | 1,199 BP.
-- Liquid metal on a leash: black magnetic fluid that bristles into spikes along the gun, held in shape by titanium
-- field coils lit in one glow colour. The guns, the scythe, the arm pieces and the effect meshes are RESCULPTED models
-- (WeaponAssets.SkinModels.Ferroflux_<GUN> / _FX, MeleeModels.Ferroflux, ArmsModels.Ferroflux; built with
-- tools/skin_v3_blender.py in art/weapons/SkinsV3_Ferroflux.blend, painted by tools/skin_v3_paint.py with
-- tools/skins_v3/ferroflux.json). This module brings their motion, effects, sounds and the rest of the bundle:
--   SPIKES   a crown of curved spikes GROWS out of the fluid (ScaleDrive "Spike<i>"): they breathe, surge with every
--            shot and stand taller as the streak climbs. AK: five on the stock root (lower right of the screen) + three on
--            the handguard; G17: four along the slide; Hyperion: a row lining each side of the coil chamber (RowCharge,
--            sinking at each shot and growing back as the cell recharges); the scythe: five along its spine.
--   FIELD    the titanium collars + coil windows glow and pulse at 0.5 Hz, flaring with fire and the inspect
--   CHARGE   the AK magazine's spine (6 lit segments) = the rounds left; reloads drain it and refill it bottom -> top
--   EQUIP    flat (spikes sunk) -> the coils light -> the spikes erupt grip -> muzzle in a ripple, droplets fall
--   INSPECT  from the class inspect's Present beat the spikes sink and re-emerge in a wave muzzle -> stock, twice
-- FIELD RINGS at the muzzle (no fireball), a HELIX tracer that snaps straight, a fluid CROWN impact, the PULL kill (a
-- field disc, a spiked column of fluid rising to chest height, slumping into a puddle) and a hexagonal SPIKE banner
-- beside the HUD's weapon card. Original design (the plan's Originality line): no faceted obsidian, no floating barrel
-- prongs, no gold trims; ferrofluid crowns, field-coil windows and a fluid scythe are ours.
-- ===================================================================================================================
local Set = { Kind = "Ferroflux" }

-- COLOURWAYS: each colourway is a whole palette; the module copy SkinFX loads for colourway v has attribute Colorway = v.
-- The painted model maps are separate SurfaceAppearances (SkinFX.V3Swap); Colorways.Sets.Ferroflux lists the names.
local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local PALETTES = {
    { Name = "Magnet", Body = C(20, 18, 30), Mid = C(56, 50, 78), Detail = C(42, 44, 54), Glow = C(235, 60, 200), Hot = C(255, 170, 235),
      Spark = C(255, 120, 225), Dark = C(9, 8, 14), Text = C(240, 214, 236), Dim = C(120, 40, 110), Ink = C(14, 4, 16) },
    { Name = "Quicksilver", Body = C(44, 52, 72), Mid = C(74, 86, 108), Detail = C(40, 46, 58), Glow = C(70, 220, 255), Hot = C(200, 245, 255),
      Spark = C(140, 235, 255), Dark = C(10, 12, 18), Text = C(214, 236, 245), Dim = C(30, 100, 130), Ink = C(4, 14, 20) },
    { Name = "Magma", Body = C(40, 14, 14), Mid = C(74, 48, 42), Detail = C(44, 38, 38), Glow = C(255, 120, 40), Hot = C(255, 210, 150),
      Spark = C(255, 160, 80), Dark = C(14, 6, 6), Text = C(245, 222, 205), Dim = C(130, 55, 20), Ink = C(20, 6, 2) },
    { Name = "Venom", Body = C(18, 30, 22), Mid = C(50, 66, 52), Detail = C(36, 44, 40), Glow = C(170, 255, 70), Hot = C(225, 255, 180),
      Spark = C(190, 255, 120), Dark = C(6, 10, 8), Text = C(220, 240, 210), Dim = C(70, 110, 30), Ink = C(6, 16, 4) },
}
local P = PALETTES[VAR] or PALETTES[1]
local GLOW, HOT, BODY, MID, DARK, SPARK, DIM = P.Glow, P.Hot, P.Body, P.Mid, P.Dark, P.Spark, P.Dim
Set.Palettes = PALETTES
Set.Colors = { Glow = GLOW, Hot = HOT, Spark = SPARK }

-- art (tools/make_ferroflux_art.py, uploaded as decals with tools/upload_asset.py; these are the IMAGE ids, resolved in Studio)
local A = "rbxassetid://"
Set.Art = {
    EmblemFerroflux = A .. "138390439715710", ff_emblem_mask = A .. "106083338708747", ff_hex = A .. "121901675453731",
    ff_hexrim = A .. "98235441795186", ff_drop = A .. "83059985713643", ff_spike = A .. "75164968276549",
    ff_ring = A .. "81194046461850", ff_corner = A .. "136234649913503", tex_ff_fluid = A .. "84130240824798",
    tex_ff_field = A .. "88640871639081", tex_ff_bar = A .. "81885103397861", ff_helix = A .. "134155716342467",
    ff_spike_l = A .. "80626904928278", ff_drop_l = A .. "108782800722363", -- (light sprites: a tint can colour them on the dark hex)
    tex_ff_twill = A .. "135951733687815", -- (skins11 touch-up: the Flux Sleeves' techwear twill)
}
local ART = Set.Art

-- sounds (tools/make_skin_sfx_v3.py ferroflux: each gun's own recorded shot + the set's low magnetic thump / shimmer / gloop;
-- moments from CC0 recordings -- tools/sound_sources.json)
Set.Sounds = {
    Equip = { Id = 77584973397354, Volume = 0.45 }, MagOut = { Id = 72263268413784, Volume = 0.3 }, MagIn = { Id = 77151192366330, Volume = 0.35 },
    Kill = { Id = 81713197385684, Volume = 0.55 }, Impact = { Id = 87010809279560, Volume = 0.18 }, Swing = { Id = 103753567431848, Volume = 0.4 },
    MeleeHit = { Id = 100092165022567, Volume = 0.4 },
    FireGun = { AK47 = { Id = 93521847314514, Volume = 0.9 }, Glock17 = { Id = 119657957577525, Volume = 0.9 }, Railgun = { Id = 88135260500095, Volume = 0.9 } },
}

local function GunDesc(gun: string): string
    local what = (gun == "Railgun") and "the coil chamber is lined with fluid that bristles as the cell charges and sinks with every shot"
        or (gun == "Glock17") and "four spikes ride the slide's flank, a coil glows under it, and the magazine hangs a single drop"
        or "a crown of curved spikes rises off the stock, the receiver carries a window of glowing field coils and the magazine's spine counts your rounds"
    return "Liquid metal on a leash: black magnetic fluid resculpts the gun, held in shape by titanium field coils. " .. string.upper(string.sub(what, 1, 1)) .. string.sub(what, 2) .. ". The spikes breathe at rest, surge with every shot and stand taller as your streak climbs. Drawn, it pools flat and erupts; inspect it and the spikes sink and rise in waves. Field-ring muzzle, a helix tracer that snaps straight, fluid crown impacts, and every kill PULLS the body into the field."
end

-- ===== the guns =====
-- Spikes = how many Spike<i> parts (1 = rearmost); Fit.spine = the AK magazine's lit spine (gun-space studs, camera side)
Set.GunSkins = {
    { Id = "FerrofluxAK47", Name = "Ferroflux AK-47", Gun = "AK47", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = GunDesc("AK47"), Model = "Ferroflux_AK47", V3 = true, Color = GLOW, Deco = "FerrofluxSpine", Spikes = 8,
      Fit = { spine = { Vector3.new(0.052, -0.02, -0.049), Vector3.new(0.068, -0.075, -0.049), Vector3.new(0.088, -0.13, -0.049),
              Vector3.new(0.116, -0.185, -0.049), Vector3.new(0.152, -0.24, -0.049), Vector3.new(0.205, -0.295, -0.049), Vector3.new(0.27, -0.345, -0.05) },
              spineIn = 0.026, drops = Vector3.new(-1.42, -0.30, 0.004) } },
    { Id = "FerrofluxGlock17", Name = "Ferroflux G19", Gun = "Glock17", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = GunDesc("Glock17"), Model = "Ferroflux_Glock17", V3 = true, Color = GLOW, Spikes = 4, SpikeRest = 0.3,
      Fit = { drops = Vector3.new(-0.31, -0.275, 0.002) } },
    { Id = "FerrofluxRailgun", Name = "Ferroflux Hyperion", Gun = "Railgun", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = GunDesc("Railgun"), Model = "Ferroflux_Railgun", V3 = true, Color = GLOW, BeamColor = GLOW, Spikes = 0, Rows = true,
      Fit = { drops = Vector3.new(1.0, 0.1, 0) } },
}

-- ===== small Roblox-part bits (the sculpt is the model): the AK magazine's lit spine =====
Set.Build = {}
Set.Build.FerrofluxSpine = function(model: Model, frame: BasePart, f: any, forView: boolean, H: any)
    local pts = f.spine
    if not pts then return end
    -- 6 segments along the magazine's front edge, set in from it, proud of its camera face; they ride the magazine and
    -- go dark top -> bottom as it empties (CountDrive "Charge", slot 6 = the top one)
    for i = 1, math.min(6, #pts - 1) do
        local a, b = pts[i], pts[i + 1]
        local d = (b - a)
        local inward = Vector3.new(-d.Y, d.X, 0).Unit * -(f.spineIn or 0.026)
        local mid = (a + b) / 2 + inward
        local seg = H.Deco(model, { Name = "Spine", Size = Vector3.new(0.014, d.Magnitude * 0.8, 0.008),
            CFrame = frame.CFrame * CFrame.lookAt(mid, mid + Vector3.new(0, 0, -1), d.Unit), Color = GLOW, Glow = true })
        seg:SetAttribute("Follow", "Magazine")
        seg:SetAttribute("CountDrive", "Charge")
        seg:SetAttribute("CountSlot", 7 - i)
    end
end

-- ===== motion: every key the parts read =====
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function backOut(x) x = math.clamp(x, 0, 1); local c = 1.9; return 1 + (c + 1) * (x - 1) ^ 3 + c * (x - 1) ^ 2 end
-- the inspect / world wave: 0 -> 1 = a wave travelling front -> back (twice from the Present beat), nil = none
local function Wave(st: any, v: any): number?
    if st.Anim ~= "Inspect" or not st.AnimT then return nil end
    local t = st.AnimT - (v.WaveT0 or 0.62)
    if t > 0 and t < 1.5 then return (t % 0.75) / 0.75 end
    return nil
end
local function Spikes(st: any, v: any, now: number, n: number, sinceShot: number, rest: number?)
    local streak = st.Streak or 0
    -- rest = the idle height (G17 0.3: its crest sits in the lower right of the centre box, so it rests low and rises with
    -- the streak / every shot -- the sightline gate)
    local base = rest or 0.62
    local idle = base + (0.95 - base) / 5 * math.min(streak, 5)
    local se = st.SinceEquip or 99
    local wave = Wave(st, v)
    for i = 1, n do
        local h = idle + 0.05 * math.sin(now * 1.35 + i * 0.8)
        local k = sinceShot - (i - 1) * 0.012 -- (a shot surges every spike, the pulse running muzzle-ward)
        if k >= 0 and k < 0.3 then h += 0.25 * (1 - k / 0.3) ^ 2 end
        if wave then
            local pos = (n - i) / math.max(1, n - 1) -- (front = 0)
            local d = (wave * 1.4 - 0.2) - pos
            h *= 1 - 0.92 * math.exp(-(d / 0.18) ^ 2)
        end
        if se < 0.8 then -- equip: flat 0.15 s, then each erupts rear -> front with an overshoot
            local t0 = 0.15 + (i - 1) / math.max(1, n - 1) * 0.3
            h *= backOut((se - t0) / 0.16)
        end
        st["Spike" .. i] = math.max(0.03, h)
    end
end
local function Field(st: any, sinceShot: number, now: number)
    local se = st.SinceEquip or 99
    local f = 0.3 + 0.22 * (0.5 + 0.5 * math.sin(now * math.pi)) + 0.45 * math.exp(-sinceShot / 0.35)
        + 0.06 * math.min(st.Streak or 0, 5) + 0.4 * (st.Inspect or 0)
    if se < 0.2 then f = se / 0.2 end -- (equip: the coils light first)
    st.Field = math.clamp(f, 0, 1)
end
local function Charge(st: any)
    local charge = math.ceil((st.Ammo or 1) * 6 - 1e-6)
    local rl = st.Reload or 0
    if rl > 0 then
        if rl < 0.3 then charge = math.ceil(charge * (1 - rl / 0.3)) elseif rl < 0.6 then charge = 0 else charge = math.floor(smooth((rl - 0.6) / 0.35) * 6 + 0.5) end
    end
    st.Charge = charge
end
-- the Hyperion: the chamber rows sink at a shot and grow back as the cell recharges; the cells glow with the charge
local function Rows(st: any, sinceShot: number)
    local rc = smooth((sinceShot - 0.06) / 0.85)
    if (st.Reload or 0) > 0 then rc = math.min(rc, 0.25) end
    local se = st.SinceEquip or 99
    if se < 0.8 then rc = math.min(rc, backOut((se - 0.2) / 0.35)) end
    st.RowCharge = math.max(0.05, 0.35 + 0.65 * rc + 0.06 * math.min(st.Streak or 0, 5))
    st.Cells = 0.25 + 0.75 * rc
end
local function MeleeKeys(st: any, v: any, now: number)
    local sw = v.SwingT and (os.clock() - v.SwingT) or 99
    Spikes(st, v, now, 5, sw < 0.4 and sw or 99)
    st.Edge = math.clamp(0.35 + 0.65 * math.exp(-sw / 0.25) + 0.3 * (st.Inspect or 0), 0, 1)
    Field(st, sw < 0.4 and sw or 99, now)
end
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    local v = rig.SkinVars
    if rig.Anim and rig.Anim.Beats then v.WaveT0 = rig.Anim.Beats.Present or rig.Anim.Beats.Raise or v.WaveT0 end
    if rig.Def and rig.Def.IsMelee then MeleeKeys(st, v, now) return end
    local skin = rig.Skin or {}
    local ss = st.SinceShot or 99
    if skin.Rows then Rows(st, ss) else Spikes(st, v, now, skin.Spikes or 0, ss, skin.SpikeRest) end
    Field(st, ss, now)
    Charge(st)
    -- equip: a burst of black droplets falls off the gun once the spikes erupt
    if (st.SinceEquip or 99) < 0.6 and not v.Dropped and rig.Fx and rig.Fx.FFDrops then
        v.Dropped = true
        rig.Fx.FFDrops:Emit(6)
    end
end
Set.OnEquip = function(rig: any) if rig.SkinVars then rig.SkinVars.Dropped = nil end end
Set.OnAnim = function(rig: any, name: string)
    if rig.Def and rig.Def.IsMelee and (name:find("Light") or name:find("Heavy") or name:find("Quick")) then rig.SkinVars.SwingT = os.clock() end
end
-- other players' guns: the idle breath, the field pulse, now and then an inspect wave
Set.World = function(rec: any, now: number, st: any)
    local v = rec.Vars
    v.NextWave = v.NextWave or (now + 3 + math.random() * 5)
    st.Anim, st.AnimT = nil, nil
    if now >= v.NextWave then
        local t = now - v.NextWave
        if t > 1.6 then v.NextWave = now + 7 + math.random() * 6 else st.Anim, st.AnimT = "Inspect", 0.62 + t end
    end
    st.SinceEquip = 99; st.Reload = 0; st.Streak = 1; st.Ammo = 1; st.Inspect = 0
    Spikes(st, v, now, 8, 99)
    Rows(st, 9)
    st.Edge = 0.4
    Field(st, 99, now)
    Charge(st)
end

-- ===== muzzle: no fireball -- a small hot flash, two thin field rings snapping out, a little dark smoke =====
Set.Muzzle = function(rig: any, flash: ParticleEmitter, light: PointLight, muzzle: Attachment, H: any)
    flash.Color = ColorSequence.new(HOT, GLOW)
    flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(1, 0.02) })
    light.Color = GLOW
    light.Brightness = 0.8
    if rig.Fx and rig.Fx.Smoke then rig.Fx.Smoke.Color = ColorSequence.new(C(40, 36, 48)) end
    rig.Fx.FFRing = H.Emitter(muzzle, { Name = "FFRing", Texture = ART.ff_ring, Color = { HOT, GLOW }, Size = { 0.06, 0.62 },
        Life = { 0.1, 0.12 }, Speed = { 2.5, 5 }, Spread = 0, Dir = Enum.NormalId.Right, Orient = Enum.ParticleOrientation.VelocityPerpendicular,
        Trans = { 0.05, 1 }, Locked = false })
    local frame = rig.Gun and rig.Gun:FindFirstChild("Frame")
    local f = rig.Skin and rig.Skin.Fit
    if frame and f and f.drops then
        local a = Instance.new("Attachment")
        a.Position = f.drops * (rig.GV or Vector3.one)
        a.Parent = frame
        rig.Fx.FFDrops = H.Emitter(a, { Name = "FFDrops", Texture = ART.ff_drop, Color = { C(40, 36, 50) }, Light = 0, Influence = 1,
            Size = { 0.05, 0.03 }, Life = { 0.5, 0.8 }, Speed = { 0.2, 0.6 }, Spread = 30, Dir = Enum.NormalId.Bottom, Accel = Vector3.new(0, -14, 0), Trans = { 0, 0.4 }, SkinFx = true })
    end
end
Set.OnFire = function(rig: any, H: any)
    if rig.Fx and rig.Fx.FFRing then rig.Fx.FFRing:Emit(2) end
end
-- reload: a small magnetic snap ring at the mag well as the new magazine seats
Set.OnEvent = function(rig: any, name: string, H: any)
    if name ~= "MagIn" or not (rig.Points and rig.Points.MagWell) then return end
    local p = rig.Points.MagWell.WorldPosition
    local ring = H.ModelSource("SkinModels", "Ferroflux_FX")
    ring = ring and ring:FindFirstChild("Ring")
    if not ring then return end
    local r = ring:Clone()
    for _, sa in ipairs(r:GetChildren()) do sa:Destroy() end
    r.Material = Enum.Material.Neon; r.Color = GLOW; r.Anchored = true; r.CanCollide = false; r.CanQuery = false; r.CanTouch = false; r.CastShadow = false
    local cam = workspace.CurrentCamera
    local up = cam and cam.CFrame.UpVector or Vector3.yAxis
    r.CFrame = CFrame.lookAt(p, p + up) * CFrame.Angles(math.pi / 2, 0, 0)
    r.Parent = H.FxFolder()
    H.Animate(0.22, function(t)
        local k = t / 0.22
        r.Size = Vector3.new(1, 0.04, 1) * (0.06 + 0.22 * k)
        r.Transparency = k ^ 1.5
    end, function() r:Destroy() end)
end

-- ===== HELIX tracer: a thin black core with a field sheath coiling round it, snapping straight (0.12 s) =====
Set.Tracer = function(H: any, from: Vector3, to: Vector3, peer: boolean?)
    local dist = (to - from).Magnitude
    if dist < 2 then return end
    local host = H.FxPart({ Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1), CFrame = CFrame.new(from) })
    local a0, a1 = H.Att(host, from), H.Att(host, to)
    local core = Instance.new("Beam")
    core.Attachment0, core.Attachment1 = a0, a1
    core.Color = ColorSequence.new(C(26, 22, 34)); core.LightEmission = 0; core.LightInfluence = 0.4; core.FaceCamera = true
    core.Width0, core.Width1 = 0.05, 0.03
    core.Parent = host
    local coil = Instance.new("Beam")
    coil.Attachment0, coil.Attachment1 = a0, a1
    coil.Texture = ART.ff_helix; coil.TextureMode = Enum.TextureMode.Static; coil.TextureLength = 1.6; coil.TextureSpeed = 4
    coil.Color = ColorSequence.new(HOT, GLOW); coil.LightEmission = 1; coil.LightInfluence = 0; coil.FaceCamera = true
    coil.Width0, coil.Width1 = 0.28, 0.16
    coil.Parent = host
    local sheath = Instance.new("Beam")
    sheath.Attachment0, sheath.Attachment1 = a0, a1
    sheath.Color = ColorSequence.new(GLOW); sheath.LightEmission = 1; sheath.LightInfluence = 0; sheath.FaceCamera = true
    sheath.Width0, sheath.Width1 = 0.07, 0.04; sheath.Transparency = NumberSequence.new(1)
    sheath.Parent = host
    H.Animate(peer and 0.14 or 0.18, function(t)
        local k = math.clamp(t / 0.12, 0, 1) -- the coil tightens onto the core, then it snaps straight
        coil.Width0, coil.Width1 = 0.28 * (1 - k) + 0.05, 0.16 * (1 - k) + 0.03
        coil.Transparency = NumberSequence.new(0.1 + 0.9 * k ^ 2)
        sheath.Transparency = NumberSequence.new(k < 0.8 and 1 or (0.2 + 0.8 * math.clamp((t - 0.12) / 0.06, 0, 1)))
        -- (hitscan look 2026-10-22: the line stays muzzle -> hit while it fades; the tail no longer chases the head)
        core.Transparency = NumberSequence.new(math.clamp((t - 0.1) / 0.08, 0, 1))
    end, function() host:Destroy() end)
end

-- ===== CROWN impact: a black fluid splash stands up into spikes and sinks (0.35 s) + six field sparks =====
Set.Impact = function(H: any, pos: Vector3, normal: Vector3?, peer: boolean?)
    if not H.Budget("FerrofluxImpact", peer and 3 or 7, 0.4) then return end
    local nrm = (normal and normal.Magnitude > 0.1) and normal.Unit or Vector3.yAxis
    local src = H.ModelSource("SkinModels", "Ferroflux_FX")
    local crown = src and src:FindFirstChild("Crown")
    local face = CFrame.lookAt(pos, pos + nrm) * CFrame.Angles(-math.pi / 2, 0, math.random() * 6.28) -- (crown's +Y = the normal)
    local cr
    if crown then
        cr = crown:Clone()
        cr.Anchored = true; cr.CanCollide = false; cr.CanQuery = false; cr.CanTouch = false; cr.CastShadow = false
        if VAR > 1 then H.V3Swap(cr, VAR) end
        cr.Parent = H.FxFolder()
    end
    local base = crown and crown.Size or Vector3.new(0.34, 0.24, 0.34)
    local att = H.Att(H.FxPart({ Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05), CFrame = CFrame.new(pos + nrm * 0.05) }), pos + nrm * 0.05)
    local sp = H.Emitter(att, { Texture = H.SPARK, Color = { HOT, GLOW }, Size = { 0.09, 0 }, Life = { 0.15, 0.3 }, Speed = { 4, 9 }, Spread = 60,
        Accel = Vector3.new(0, -12, 0) })
    sp.EmissionDirection = Enum.NormalId.Top
    att.Parent.CFrame = CFrame.lookAt(pos, pos + nrm) * CFrame.Angles(-math.pi / 2, 0, 0)
    sp:Emit(peer and 3 or 6)
    H.Animate(0.38, function(t)
        if not cr then return end
        local up = (t < 0.1) and (t / 0.1) or math.max(0, 1 - (t - 0.14) / 0.24)
        local s = 1.25 * (0.35 + 0.65 * (t < 0.1 and t / 0.1 or 1))
        local sz = Vector3.new(base.X * s, base.Y * math.max(0.04, up) * 1.25, base.Z * s)
        cr.Size = sz
        cr.CFrame = face * CFrame.new(0, sz.Y / 2 - 0.02, 0)
    end, function()
        if cr then cr:Destroy() end
        att.Parent:Destroy()
    end)
end

local V = Vector3.new
-- ===== PULL kill v2 (FX roll-out 2026-10-14; v1 = a column rising out of a disc, floating over the stand and the body just
-- gone). ONE idea: the fluid PULLS THE BODY IN -- the field opens on the real floor, the black spiked column bursts up out
-- of it with a crown of smaller spikes round it, and the body is dragged into the column (every part slides in to the
-- axis, shrinks and goes down with it); the spikes slump into a puddle and sink (1.25 s). Dark fluid, so nothing bright
-- sits on the crosshair; motion is in and DOWN. Budget: full = disc + puddle + column + 6 spikes + <= 6 body parts + 1
-- spark burst (<= 14); low: disc + puddle + column + 3 body parts. =====
local function BodyParts(pos: Vector3, H: any): { BasePart }
    local op = OverlapParams.new()
    op.FilterType = Enum.RaycastFilterType.Exclude
    local ex = { H.FxFolder() }
    for _, pl in ipairs(H.Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
    if workspace.CurrentCamera then table.insert(ex, workspace.CurrentCamera) end
    op.FilterDescendantsInstances = ex
    local hits = workspace:GetPartBoundsInRadius(pos, 3.5, op)
    local best, count = nil, {}
    for _, p in ipairs(hits) do
        local m = p:FindFirstAncestorOfClass("Model")
        while m and not (m:FindFirstChild("Head") or m:FindFirstChild("Torso")) do m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model") end
        if m then count[m] = (count[m] or 0) + 1; if not best or count[m] > count[best] then best = m end end
    end
    local out = {}
    if best then
        for _, p in ipairs(best:GetDescendants()) do
            if p:IsA("BasePart") and p.Transparency < 0.6 and p.Size.Magnitude < 12 and #out < 20 then table.insert(out, p) end
        end
        table.sort(out, function(a, b) return a.Size.Magnitude > b.Size.Magnitude end)
    end
    return out
end
Set.Kill = function(H: any, pos: Vector3, low: boolean)
    local src = H.ModelSource("SkinModels", "Ferroflux_FX")
    if not src then return end
    local ground = H.Ground(pos)
    local axis = V(pos.X, ground.Y, pos.Z)
    local model = Instance.new("Model"); model.Name = "FerrofluxKill"; model.Parent = H.FxFolder()
    local function M(name, neon)
        local s = src:FindFirstChild(name)
        if not s then return nil end
        local p = s:Clone()
        p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
        if neon then
            for _, sa in ipairs(p:GetChildren()) do if sa:IsA("SurfaceAppearance") then sa:Destroy() end end
            p.Material = Enum.Material.Neon; p.Color = GLOW
        elseif VAR > 1 then H.V3Swap(p, VAR) end
        p.Transparency = 1
        p.Parent = model
        return p, s.Size
    end
    local disc, discS = M("Ring", true)
    local pud = M("Puddle")
    local col, colS = M("Column")
    -- the crown: smaller copies of the column round it, leaning out
    local crown = {}
    if col and not low then
        for i = 1, 6 do
            local c = col:Clone()
            c.Parent = model
            local a = (i - 1) / 6 * math.pi * 2 + 0.3
            local r = 1.25 + (i % 2) * 0.45
            table.insert(crown, { P = c, Off = V(math.cos(a) * r, 0, math.sin(a) * r), Lean = CFrame.Angles(math.sin(a) * 0.32, 0, -math.cos(a) * 0.32),
                H = 1.3 + (i % 3) * 0.45, T0 = 0.16 + (i % 3) * 0.05 })
        end
    end
    -- the body, dragged into the column
    local bits = {}
    for _, s in ipairs(BodyParts(pos, H)) do
        if #bits >= (low and 3 or 6) then break end
        local ok, c = pcall(function() return s:Clone() end)
        if ok and c then
            for _, ch in ipairs(c:GetChildren()) do
                if not (ch:IsA("SpecialMesh") or ch:IsA("DataModelMesh") or ch:IsA("SurfaceAppearance")) then ch:Destroy() end
            end
            c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
            c.Parent = model
            table.insert(bits, { P = c, CF = c.CFrame, Size = c.Size, C0 = c.Color, Delay = math.random() * 0.06 })
        end
    end
    local sparks
    if not low then
        local host = H.FxPart({ Transparency = 1, Size = V(0.1, 0.1, 0.1), CFrame = CFrame.new(axis + V(0, 0.3, 0)) }, model)
        sparks = H.Emitter(H.Att(host, axis + V(0, 0.3, 0)), { Texture = H.SPARK, Color = { HOT, GLOW }, Size = { 0.2, 0 }, Life = { 0.35, 0.6 }, Speed = { 5, 10 },
            Spread = 70, Dir = Enum.NormalId.Top, Accel = V(0, -14, 0) })
    end
    local burst = false
    local H3 = 3.8 -- (column height: over the body's head)
    H.Animate(1.25, function(t)
        -- the field opens on the floor (0 -> 0.18), turns, closes with the sink
        local open = smooth(t / 0.18) * (1 - smooth((t - 0.95) / 0.25))
        local R = 2.9 * open
        if disc then
            disc.Size = V(math.max(0.05, R * 2), 0.05, math.max(0.05, R * 2))
            disc.CFrame = CFrame.new(axis + V(0, 0.04, 0)) * CFrame.Angles(0, t * 2, 0)
            disc.Transparency = 0.1 + 0.9 * (1 - open)
        end
        -- the column bursts up (0.1 -> 0.32), holds, slumps (0.68 -> 0.92)
        local rise = smooth((t - 0.1) / 0.22)
        local slump = smooth((t - 0.68) / 0.24)
        if col then
            local hgt = H3 * rise * (1 - 0.94 * slump)
            local s = H3 / colS.Y
            local wide = 1 + 1.1 * slump
            col.Size = V(colS.X * s * wide, math.max(0.05, hgt), colS.Z * s * wide)
            col.CFrame = CFrame.new(axis + V(0, col.Size.Y / 2 - 0.05, 0)) * CFrame.Angles(0, t * 0.8, 0)
            col.Transparency = (hgt < 0.06) and 1 or 0
            for _, c in ipairs(crown) do
                local cr = (1 - (1 - math.clamp((t - c.T0) / 0.18, 0, 1)) ^ 3) * (1 - slump)
                local ch = c.H * cr
                local cs = ch / colS.Y
                c.P.Size = V(colS.X * cs * 0.9, math.max(0.05, ch), colS.Z * cs * 0.9)
                c.P.CFrame = CFrame.new(axis + c.Off) * c.Lean * CFrame.new(0, c.P.Size.Y / 2 - 0.05, 0)
                c.P.Transparency = (ch < 0.06) and 1 or 0
            end
        end
        if t >= 0.12 and not burst then burst = true; if sparks then sparks:Emit(14) end end
        -- the body is DRAGGED IN (0.08 -> 0.5): every part slides to the axis, shrinks, darkens and goes down with the column
        for _, b in ipairs(bits) do
            local k = smooth((t - 0.08 - b.Delay) / 0.42)
            local p = b.P
            local home = b.CF.Position
            local target = V(axis.X, ground.Y + (home.Y - ground.Y) * 0.55, axis.Z)
            local at = home:Lerp(target, k) - V(0, k * k * 1.6, 0)
            p.CFrame = (b.CF - home) * CFrame.Angles(0, k * 2.2, 0) + at
            p.Size = b.Size * V(1 - 0.75 * k, 1 - 0.55 * k, 1 - 0.75 * k)
            p.Color = b.C0:Lerp(DARK, k)
            p.Transparency = (k >= 0.98) and 1 or 0
        end
        -- the puddle spreads as everything slumps, then sinks away
        if pud then
            local spread = low and smooth((t - 0.4) / 0.3) or smooth((t - 0.66) / 0.26)
            local sink = smooth((t - 0.95) / 0.3)
            local Rp = 2.2 * spread
            pud.Size = V(math.max(0.05, Rp * 2), math.max(0.02, 0.18 * (1 - sink)), math.max(0.05, Rp * 2))
            pud.CFrame = CFrame.new(axis + V(0, pud.Size.Y / 2 - 0.04 - 0.1 * sink, 0))
            pud.Transparency = (Rp < 0.05) and 1 or (0.15 * sink)
        end
    end, function() model:Destroy() end)
end

-- ===== SPIKE banner (beside the HUD's weapon card): a hexagonal fluid plate; each kill of the streak raises one more spike
-- out of the drop at its centre (1-5); at 5 they ring the drop and the hex rim pulses once =====
local banner
Set.Banner = function(H: any, streak: number)
    local gui, root = H.BannerRoot("Ferroflux", Vector2.new(180, 90), "Side")
    if not root then return end
    if not banner or banner.Root ~= root then
        local New = H.New
        local hex = New("ImageLabel", { Name = "Hex", BackgroundTransparency = 1, Image = ART.ff_hex, ImageColor3 = MID:Lerp(C(255, 255, 255), 0.5), Size = UDim2.fromOffset(86, 86),
            Position = UDim2.fromOffset(2, 2), ZIndex = 2 }, root)
        local rim = New("ImageLabel", { Name = "Rim", BackgroundTransparency = 1, Image = ART.ff_hexrim, ImageColor3 = GLOW, Size = UDim2.fromOffset(86, 86),
            Position = UDim2.fromOffset(2, 2), ZIndex = 3, ImageTransparency = 0.1 }, root)
        local hub = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), Position = UDim2.fromOffset(45, 52), ZIndex = 4 }, root)
        local spikes = {}
        for i = 1, 5 do
            local pv = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), ZIndex = 4 }, hub)
            spikes[i] = { Pivot = pv, Img = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.ff_spike_l, ImageColor3 = HOT, -- (Update 6: the colourway's own hot tint; was a fixed magenta)
                AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(12, 0), ZIndex = 5 }, pv) }
        end
        local drop = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.ff_drop_l, ImageColor3 = GLOW, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(26, 26),
            Position = UDim2.fromOffset(45, 52), ZIndex = 6 }, root)
        local glow = New("ImageLabel", { BackgroundTransparency = 1, Image = H.Art.Glow, ImageColor3 = GLOW, AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(120, 110), Position = UDim2.fromOffset(45, 46), ImageTransparency = 0.7, ZIndex = 1 }, root)
        -- the streak count, in the HUD's number face (the game's own font -- no theme fonts)
        local num = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(98, 46), Size = UDim2.fromOffset(80, 40),
            Font = Enum.Font.GothamBlack, TextSize = 30, TextColor3 = P.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 6 }, root)
        New("UIStroke", { Color = P.Ink, Thickness = 2 }, num)
        banner = { Root = root, Hex = hex, Rim = rim, Spikes = spikes, Drop = drop, Glow = glow, Num = num, Token = 0, T0 = 0, Streak = 1 }
        H.RunService.RenderStepped:Connect(function()
            local b = banner
            if not (b and b.Root.Visible) then return end
            local t = os.clock() - b.T0
            for i, s in ipairs(b.Spikes) do
                local shown = i <= b.Streak
                local ring = b.Streak >= 5
                local ang = ring and ((i - 1) * 72) or ((i - (b.Streak + 1) / 2) * 26)
                local grow = shown and backOut(math.clamp((t - (i == b.Streak and 0 or -1)) / 0.22, 0, 1)) or 0
                local L = (ring and 26 or 30) * grow * (1 + 0.05 * math.sin(os.clock() * 3 + i))
                s.Pivot.Rotation = ang
                s.Img.Size = UDim2.fromOffset(ring and 10 or 12, math.max(0, L))
                s.Img.Position = UDim2.fromOffset(0, ring and -8 or -6)
                s.Img.Visible = L > 0.5
            end
            if b.Streak >= 5 then b.Rim.ImageTransparency = 0.1 * (1 - math.exp(-t * 3) * math.abs(math.sin(t * 9))) end
        end)
    end
    local b = banner
    b.Token += 1
    local token = b.Token
    b.T0 = os.clock()
    b.Streak = math.clamp(streak or 1, 1, 5)
    root.Visible = true
    b.Num.Text = "x" .. b.Streak
    b.Num.TextColor3 = (b.Streak >= 5) and GLOW or P.Text
    b.Glow.ImageTransparency = math.max(0.4, 0.78 - b.Streak * 0.06)
    for _, o in ipairs({ b.Hex, b.Drop }) do o.ImageTransparency = 0 end
    b.Rim.ImageTransparency = 0.1
    b.Num.TextTransparency = 0
    task.delay(1.6, function()
        if b.Token ~= token then return end
        local ti = TweenInfo.new(0.3)
        for _, o in ipairs({ b.Hex, b.Rim, b.Drop, b.Glow }) do H.TweenService:Create(o, ti, { ImageTransparency = 1 }):Play() end
        H.TweenService:Create(b.Num, ti, { TextTransparency = 1 }):Play()
        for _, s in ipairs(b.Spikes) do H.TweenService:Create(s.Img, ti, { ImageTransparency = 1 }):Play() end
        task.delay(0.32, function()
            if b.Token == token then
                root.Visible = false
                for _, s in ipairs(b.Spikes) do s.Img.ImageTransparency = 0 end
            end
        end)
    end)
end

-- ===== the FLUX SCYTHE (melee): a short one-handed scythe -- black lacquer snath with three coil-titanium bands, the
-- blade is held ferrofluid stretched into a crescent with spikes along its spine that bristle with every swing and run
-- along it on the inspect, a field seam along the edge (MeleeModels.Ferroflux) =====
Set.Melee = {
    Skin = { Name = "Flux Scythe", Price = 449, ProductId = 0,
        Desc = "Turns your melee into a short scythe of held ferrofluid: a black lacquer snath bound in three titanium field bands, a crescent of liquid metal with a glowing seam along its edge and spikes along its spine that bristle on every swing and run down the blade when you inspect it. Swings shed a field trail; every kill PULLS the body into the field." },
    Rig = { Class = "Scythe", BladeLen = 1.4 },
    -- (our own beat on the class inspect: a field flare as the blade turns to show its other face)
    InspectEvents = { { "Flip", "Emit", { Name = "FFMeleeSparks", Count = 12 } } },
    Build = function(m: Model, o: any, H: any)
        local parts = H.CloneModel(m, "MeleeModels", "Ferroflux", VAR, { [1] = GLOW })
        -- the head turned about the shaft: built in the class convention (blade along +Z) it pointed AWAY down the view in
        -- the scythe hold (seen edge-on, a sliver in first person). (Update 6, owner: "Scythe is rotated the wrong way
        -- again") -45 swung the crescent out to the RIGHT, off the screen edge; a scythe hooks IN: 135 deg = the same face
        -- angle mirrored, the crescent reaching over the top toward the middle (MeleeData CLASSES "Scythe")
        local TURN = CFrame.Angles(0, math.rad(workspace:GetAttribute("DevScytheTurn") or 135), 0) -- (Studio tuning attr)
        for _, p in pairs(parts) do p.CFrame = TURN * p.CFrame end
        local blade = parts.Blade
        if not blade then return end
        -- the swing trail off the blade (root -> tip of the crescent, melee space)
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Name, a1.Name = "TrailBase", "TrailTip"
        a0.Position = blade.CFrame:PointToObjectSpace(TURN * Vector3.new(0, 1.14, 0.25))
        a1.Position = blade.CFrame:PointToObjectSpace(TURN * Vector3.new(0, 1.0, 1.1))
        a0.Parent, a1.Parent = blade, blade
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Color = ColorSequence.new(HOT, GLOW)
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
        tr.LightEmission = 0.9; tr.LightInfluence = 0
        tr.Lifetime = 0.16; tr.MinLength = 0.02; tr.FaceCamera = true
        tr.Enabled = false
        tr:SetAttribute("SwingTrail", true)
        tr.Parent = blade
        local sa = Instance.new("Attachment"); sa.Position = blade.CFrame:PointToObjectSpace(TURN * Vector3.new(0, 1.12, 0.5)); sa.Parent = blade
        H.Emitter(sa, { Name = "FFMeleeSparks", Color = { HOT, GLOW }, Size = { 0.06, 0 }, Life = { 0.2, 0.4 }, Speed = { 1, 3 }, Accel = Vector3.new(0, -4, 0), SkinFx = true })
    end,
}

-- ===== arms: FLUX GRIPS + FLUX SLEEVES =====
-- glove: a black wet-look tactical glove with a sculpted coil-titanium knuckle plate; ONE effect: a fluid bead on the back
-- of the hand grows three tiny spikes every ~6 s and relaxes (at once on a kill)
Set.Glove = function(K: any)
    local V = K.V
    local parts = {
        { Mesh = "Ferroflux/Knuckle", MeshV = VAR, Size = V(1.06, 0.24, 0.34), Off = V(0, 0.5, -0.3) },
        { Mesh = "Ferroflux/Bead", MeshV = VAR, Size = V(0.46, 0.2, 0.46), Off = V(0, 0.53, 0.12) },
        -- (a thin titanium band at the wrist: the sleeve's cuff takes over above it)
        { Size = V(1.1, 1.1, 0.06), Off = V(0, 0, 0.47), Color = MID, Material = K.SMOOTH, Reflectance = 0.06 },
    }
    for k = 1, 3 do
        local yaw = (k - 2) * 38
        table.insert(parts, { Mesh = "Ferroflux/Spike", MeshV = VAR, Uniform = true, Size = V(0.13, 0.13, 0.42), Off = V(0, 0.57, 0.12),
            OffW = V((k - 2) * 0.05, 0, 0), Rot = V(-62, yaw, 0), Root = 1, Anim = "Grow", Period = 6.2, Dur = 1.2, Phase = k * 0.12,
            MinScale = 0.06, BurstOn = "Kill" })
    end
    return {
        Id = "FluxGrips", Name = "Flux Grips", Price = 449,
        Desc = "Black wet-look tactical gloves with a sculpted titanium knuckle plate. A bead of ferrofluid sits on the back of each hand: every few seconds it slowly grows three small spikes and lets them sink back, and a kill makes them stand up at once.",
        Base = { Color = C(14, 14, 18), Material = K.SMOOTH, Reflectance = 0 }, -- (no reflectance: it mirrored the biome -- maroon in Molten)
        Parts = parts,
    }
end
-- sleeve: a matte black techwear sleeve with a sculpted magnetic coil cuff (three wound, chamfered bands) at the wrist and
-- one dim, steady field seam down the top of the forearm
Set.Sleeve = function(K: any)
    local V = K.V
    return {
        Id = "FluxSleeves", Name = "Flux Sleeves", Price = 299,
        Desc = "Matte black techwear sleeves with a raised forearm panel, a strap at the elbow and a sculpted magnetic coil cuff -- three wound, chamfered titanium bands -- at the wrist, a single dim field seam running down the forearm.",
        -- (skins11 touch-up, arms bar: techwear twill on the sleeve block; the raised forearm panel a lighter rubberised
        -- graphite + the elbow strap with a small titanium buckle, so the arm is never one flat black)
        Base = { Color = C(17, 17, 21), Material = K.SMOOTH, Reflectance = 0, Tex = "tex_ff_twill", TexTile = 1.6, TexT = 0, TexColor = C(30, 30, 36) },
        Parts = {
            { Mesh = "Ferroflux/Cuff", MeshV = VAR, Size = V(1.17, 1.17, 0.2), Off = V(0, 0, -0.41) },
            { Size = V(1.09, 1.09, 0.42), Off = V(0, 0, 0.06), Color = C(34, 34, 42), Material = K.SMOOTH },
            { Size = V(1.12, 1.12, 0.05), Off = V(0, 0, 0.34), Color = C(44, 44, 54), Material = K.SMOOTH },
            { Size = V(0.16, 0.03, 0.08), Off = V(0, 0.575, 0.34), Color = MID, Material = K.SMOOTH, Reflectance = 0.06, Seat = true },
            { Size = V(0.05, 0.03, 0.62), Off = V(0, 0.565, 0.04), Color = GLOW, Glow = true, Transparency = 0.4 },
        },
    }
end

-- ===== health bar v2 (BARS v2, FX roll-out): the house ink frame round a field-magenta fill with dark field lines running
-- through it; its leading edge bristles with black ferrofluid spikes that jump when the enemy is hit (v1's spikes, kept) =====
Set.Bar = { Id = "Ferroflux", Name = "Ferroflux", Price = 149,
    Desc = "A field-magenta bar in an ink frame with dark field lines running through it; its leading edge bristles with black ferrofluid spikes that jump when the enemy is hit. Part of the Ferroflux set.",
    Look = "Ink", FillColor = GLOW, ChipMotion = "Drain", Chip = HOT, Back = DARK, Segments = 5, Decor = { "FieldLines", "EdgeSpikes" } }
Set.BarDecor = {
    FieldLines = function(ctx: any, K: any)
        local img = K.Img("tex_ff_field", { ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(ctx.H * 3, ctx.H * 3), Size = UDim2.new(1, ctx.H * 3, 1, 0),
            ImageColor3 = DARK, ImageTransparency = 0.55, ZIndex = 4 }, ctx.Inner)
        return function(now, dt, alpha, info)
            img.Position = UDim2.fromOffset(-((now * 10) % (ctx.H * 3)), 0)
            img.ImageTransparency = 1 - (1 - 0.55) * alpha
        end
    end,
    EdgeSpikes = function(ctx: any, K: any)
        local U = ctx.U
        local sp = {}
        local n = (ctx.Tier == "Small") and 3 or 4
        for i = 1, n do
            sp[i] = K.Img("ff_spike", { AnchorPoint = Vector2.new(0.5, 1), ImageColor3 = C(110, 100, 140), ZIndex = 12 }, ctx.Holder)
        end
        local kick = 0
        return function(now, dt, alpha, info)
            kick = math.max(info.Hit or 0, kick - dt * 3)
            local x = ctx.W * math.max(0.02, info.Shown)
            for i, im in ipairs(sp) do
                local h = math.max(ctx.H * 0.9, U * (0.45 + 0.12 * (i % 2))) * (1 + 0.9 * kick) * (0.92 + 0.08 * math.sin(now * 4 + i))
                im.Size = UDim2.fromOffset(math.max(4, U * 0.22), h)
                im.Position = UDim2.fromOffset(x - (i - 1) * math.max(4, U * 0.32), 1)
                im.Rotation = -10 - (i - 1) * 8
                im.ImageTransparency = 1 - alpha
            end
        end
    end,
}

-- ===== UI theme v2 (FX roll-out 2026-10-14; v1 = the shared template): BLACK FLUID, icon look. Spike clusters of
-- ferrofluid stand on the two top corners and breathe with the field (they rise and settle like fluid in a magnet's pull),
-- windows open with the FIELD PULL: spikes shoot out of all four corners, then fall back; every title gets a row of three
-- small spikes. Colours from the theme table (Fluid / Field / Ink). =====
local function FfSpike(parent, z, col)
    local s = Instance.new("ImageLabel")
    s.BackgroundTransparency = 1; s.Image = ART.ff_spike_l; s.ImageColor3 = col; s.AnchorPoint = Vector2.new(0.5, 1); s.ZIndex = z
    s.Parent = parent
    return s
end
local function FfDeco(ctx)
    if ctx.Kind ~= "Window" then return nil end
    local t = ctx.Theme
    local host = ctx.Root or ctx.Surface
    local f = Instance.new("Frame")
    f.Name = "FfOverlay"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 20; f.Active = false
    f:SetAttribute("NoSkin", true); f:SetAttribute("Skinned", true)
    f.Parent = host
    local abs = host.AbsoluteSize
    local small = math.min(abs.X, abs.Y) < 260
    local U = small and 0.65 or 1
    local spikes = {}
    -- a cluster of 4 spikes on each top corner, standing OUT of the window's top edge, the tallest at the corner
    for side = 0, 1 do
        for i = 1, 4 do
            local ink = FfSpike(f, f.ZIndex + 1, t.Ink)
            local sp = FfSpike(f, f.ZIndex + 2, t.Fluid)
            local dx = (i - 1) * 17 * U + 8
            local x = (side == 0) and dx or -dx
            local lean = ((side == 0) and -1 or 1) * (8 + (i - 1) * 9)
            table.insert(spikes, { I = ink, S = sp, Side = side, X = x, Lean = lean, H = (60 - (i - 1) * 10) * U, W = 22 * U, Ph = i * 0.9 + side * 2 })
        end
    end
    return function(now, dt)
        for _, s in ipairs(spikes) do
            local breathe = 0.82 + 0.18 * math.sin(now * 1.4 + s.Ph)
            local h = s.H * breathe
            local pos = UDim2.new(s.Side, s.X, 0, 3)
            s.S.Size = UDim2.fromOffset(s.W, h); s.S.Position = pos; s.S.Rotation = s.Lean
            s.I.Size = UDim2.fromOffset(s.W + 6, h + 6); s.I.Position = pos + UDim2.fromOffset(0, 2); s.I.Rotation = s.Lean
        end
    end, { f }
end
local function FfOpen(ctx)
    -- FIELD PULL (0.42 s): spikes shoot out of all four corners (tall + magenta), then fall back into the fluid
    local t = ctx.Theme
    local root = ctx.Root
    if not root then return end
    local f = root:FindFirstChild("FfOverlay") or ctx.Frame
    local made = {}
    for _, c in ipairs({ { 0, 0, -45 }, { 1, 0, 45 }, { 0, 1, -135 }, { 1, 1, 135 } }) do
        for j = -1, 1 do
            local s = FfSpike(f, f.ZIndex + 6, t.Field)
            s.Position = UDim2.fromScale(c[1], c[2]); s.Rotation = c[3] + j * 22; s.Size = UDim2.fromOffset(12, 0)
            ctx.Tween:Create(s, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(14, (j == 0) and 58 or 38) }):Play()
            task.delay(0.18, function()
                if s.Parent then ctx.Tween:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromOffset(12, 0), ImageColor3 = t.Fluid }):Play() end
            end)
            table.insert(made, s)
        end
    end
    task.delay(0.44, function() for _, s in ipairs(made) do s:Destroy() end end)
end
local function FfTitle(ctx)
    -- three small spikes (fluid with an ink edge) on the title bar, right side, tallest in the middle
    local bar, t = ctx.Title, ctx.Theme
    local h = math.max(bar.AbsoluteSize.Y, 30)
    local holder = Instance.new("Frame")
    holder.Name = "FfTitleSpikes"; holder.BackgroundTransparency = 1; holder.AnchorPoint = Vector2.new(1, 0.5)
    holder.Size = UDim2.fromOffset(52, 30); holder.Position = UDim2.new(1, -(h * 2.9 + 14), 0.5, 0); holder.ZIndex = bar.ZIndex + 1
    holder.Parent = bar
    for i = 1, 3 do
        local hh = (i == 2) and 32 or 22
        local ink = FfSpike(holder, bar.ZIndex + 1, t.Ink); ink.Size = UDim2.fromOffset(20, hh + 4); ink.Position = UDim2.new(0, 9 + (i - 1) * 16, 1, 2)
        local sp = FfSpike(holder, bar.ZIndex + 2, t.Field); sp.Size = UDim2.fromOffset(16, hh); sp.Position = UDim2.new(0, 9 + (i - 1) * 16, 1, 0)
    end
    return { holder }
end
-- numbers v3 (SKIN UI 2026-10-29, owner: numbers "unique to the skin and the colorways you have equipped"): HELD IN THE FIELD.
-- The digits are BLACK FLUID outlined in the field's glow (the only set whose numbers are dark: the coil light round the
-- fluid), in a sharp angular face. A number is PULLED into shape (it snaps in from a little low and small), and on every hit
-- the fluid BRISTLES: spikes jut up out of its top edge and sink back. CRIT = the spikes stand tall and the digits fill
-- with the glow; WEAK SPOT = pale-hot digits under a full five-spike crown (a glyph in this face drew huge or not at
-- all); a KILL = the PULL: a full crown of tall spikes erupts and a field ring pulses out from it. Every colour is this copy's palette P (the colourway).
local FF_SPIKES = 5
local FLUIDN = P.Mid:Lerp(P.Body, 0.3)
local function FfMotion(e, age, pa, life)
    local snap = math.min(1, age / 0.09)
    local s = 0.78 + 0.22 * (1 - (1 - snap) ^ 3)
    local b = math.min(1, pa / 0.08)
    s *= 1 + 0.08 * (e.BumpAmp or 1) * (1 - b) * (age > 0.1 and 1 or 0)
    local up = 0.4 + 0.9 * (1 - (1 - math.min(1, age / 0.9)) ^ 3)
    local dy = 8 * (1 - snap) ^ 2
    return up, 0, s, dy, 0, 0
end
local function FfAccent(e)
    local box = Instance.new("Frame")
    box.Name = "FfField"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 0
    for i = 1, FF_SPIKES do
        local s = Instance.new("ImageLabel")
        s.Name = "Spike" .. i; s.BackgroundTransparency = 1; s.Image = ART.ff_spike_l; s.AnchorPoint = Vector2.new(0.5, 1); s.ZIndex = 0
        s.Parent = box
    end
    local ring = Instance.new("ImageLabel")
    ring.Name = "Ring"; ring.BackgroundTransparency = 1; ring.Image = ART.ff_ring; ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.fromScale(0.5, 0.5); ring.ZIndex = 0; ring.Parent = box
    return box
end
local FF_X = { -0.32, -0.14, 0.02, 0.18, 0.34 }
local FF_H = { 0.6, 0.85, 1.0, 0.8, 0.55 }
local function FfAccentStep(e, box, age, pa, alpha)
    local tb = e.Label.TextBounds
    local kt = (e.Killed and e.KillAt) and (os.clock() - e.KillAt) or nil
    -- the dark fill keeps a glow outline (a typed hit is drawn in its damage colour, the glow stays round it)
    e.Stroke.Color = (e.Crit and not e.Dot) and P.Hot or GLOW
    -- a bristle on every hit: up in 0.06 s, back down to a low crown by 0.45 s
    local up = (pa < 0.06) and (pa / 0.06) or math.max(0.45, 1 - (pa - 0.06) / 0.4)
    local tall = (kt and 2.1) or ((e.Crit and not e.Dot) and 1.5) or ((e.Weak and not e.Dot) and 1.25) or 1
    if kt then up = math.max(up, math.clamp(1 - (kt - 0.5) / 0.4, 0.35, 1)) end
    for i = 1, FF_SPIKES do
        local s = box:FindFirstChild("Spike" .. i)
        if s then
            local on = not e.Dot and (kt ~= nil or (i >= 2 and i <= 4) or e.Crit or e.Weak)
            s.Visible = on
            if on then
                local h = math.floor(15 * FF_H[i] * tall * up + 0.5)
                s.Size = UDim2.fromOffset(math.floor(6 + 2 * tall), math.max(1, h))
                s.Position = UDim2.new(0.5, FF_X[i] * tb.X, 0.5, -tb.Y * 0.32)
                s.Rotation = FF_X[i] * 40
                s.ImageColor3 = FLUIDN:Lerp(GLOW, (e.Crit or kt) and 0.8 or 0.55)
                s.ImageTransparency = alpha
            end
        end
    end
    local ring = box:FindFirstChild("Ring")
    if ring then
        local on = kt ~= nil and kt < 0.45
        ring.Visible = on
        if on then
            local q = kt / 0.45
            local d = (tb.X + 20) * (0.7 + 1.1 * q)
            ring.Size = UDim2.fromOffset(d, d * 0.55)
            ring.ImageColor3 = GLOW; ring.ImageTransparency = math.clamp(alpha + q, 0, 1)
        end
    end
end
-- ===== UI THEME v4 (SKIN UI THEMES 2026-10-29 roll-out, owner: themes must "change up the colorways and provide a bit more
-- style than the default", no stretched header art): the clean language in this colourway's fluid (UITheme Clean: roles
-- from P) + two touches of ferrofluid. Hooks read only the palette they are given (a colourway copy shares them):
--   TAB MARK  three FLUID SPIKES stand up off the glowing bar (offset children inside the mark's width), breathing with the
--             field; on the selected tab they surge every few seconds
--   FIELD     a FERROFLUID FLOOR along the bottom of the screen: a glowing field line with two CROWNS of black fluid on it
--             (a mound + a tight cluster of spikes leaning out, the way the fluid stands up over a magnet), a ripple of the field
--             running through them, now and then a surge (a sparse row of single spikes read as a fence)
local FF_CLEAN = {
    Field = P.Dark:Lerp(C(0, 0, 0), 0.25), Surface = P.Dark:Lerp(P.Body, 0.5), Raised = P.Body:Lerp(P.Mid, 0.18), Hover = P.Body:Lerp(P.Mid, 0.45),
    Well = P.Dark, Line = P.Mid:Lerp(P.Detail, 0.3), Tip = P.Dark:Lerp(P.Body, 0.3),
    Accent = P.Glow, Mark = P.Glow, Hair = P.Detail:Lerp(P.Text, 0.4),
    Text = P.Text, Sub = P.Text:Lerp(P.Mid, 0.45), Muted = P.Mid:Lerp(P.Text, 0.35), Ink = P.Ink,
    Fluid = P.Mid:Lerp(P.Body, 0.3), FieldGlow = P.Glow, FieldHot = P.Hot, InkLine = P.Ink,
}
local FF_MARK_X = { -13, -4, 5 }
local FF_MARK_H = { 8, 13, 8 }
FF_CLEAN.TabMark = function(mark, Q)
    -- (offset children anchored at their left / top, inside the mark: tab buttons size themselves to their children)
    local made = {}
    for i = 1, 3 do
        local s = Instance.new("ImageLabel")
        s.Name = "FfMarkSpike"; s.BackgroundTransparency = 1; s.Image = ART.ff_spike_l; s.ImageColor3 = Q.FieldGlow
        s.Size = UDim2.fromOffset(8, FF_MARK_H[i]); s.Position = UDim2.new(0.5, FF_MARK_X[i], 0, -FF_MARK_H[i]); s.ZIndex = mark.ZIndex
        s:SetAttribute("H", FF_MARK_H[i])
        s.Parent = mark
        table.insert(made, s)
    end
    return made
end
FF_CLEAN.Sig = function(ctx)
    local Q, f = ctx.P, ctx.Frame
    local line = Instance.new("Frame")
    line.Name = "FfFieldLine"; line.BorderSizePixel = 0; line.BackgroundColor3 = Q.FieldGlow; line.BackgroundTransparency = 0.35
    line.AnchorPoint = Vector2.new(0.5, 1); line.Position = UDim2.new(0.5, 0, 1, -6); line.Size = UDim2.new(1, -24, 0, 2); line.ZIndex = 0; line.Parent = f
    local lg = Instance.new("UIGradient")
    lg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.2), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
    lg.Parent = line
    -- two CROWNS of fluid standing on the field line (a big one lower right, a smaller one left of centre): a dark mound of fluid
    -- with a glow rim, a tight cluster of spikes on it, tallest in the middle, the outer ones leaning out (a magnet's crown)
    local spikes = {}
    for _, cr in ipairs({ { U = 0.8, W = 240, N = 13, H = 46 }, { U = 0.3, W = 150, N = 9, H = 30 } }) do
        local mound = Instance.new("Frame")
        mound.Name = "FfMound"; mound.BorderSizePixel = 0; mound.BackgroundColor3 = Q.Fluid; mound.BackgroundTransparency = 0.1
        mound.AnchorPoint = Vector2.new(0.5, 0.5); mound.Position = UDim2.new(cr.U, 0, 1, -7); mound.Size = UDim2.fromOffset(cr.W, 16); mound.ZIndex = 0
        local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(1, 0); mc.Parent = mound
        local ms = Instance.new("UIStroke"); ms.Color = Q.FieldGlow; ms.Thickness = 1; ms.Transparency = 0.35; ms.Parent = mound
        mound.Parent = f
        for j = 1, cr.N do
            local x = (j - 0.5) / cr.N - 0.5 -- (-0.5 .. 0.5 across the mound)
            local s = Instance.new("ImageLabel")
            s.Name = "FfFloorSpike"; s.BackgroundTransparency = 1; s.Image = ART.ff_spike_l; s.AnchorPoint = Vector2.new(0.5, 1)
            s.Position = UDim2.new(cr.U, x * cr.W * 0.78, 1, -9 + math.abs(x) * 6); s.Rotation = x * 50; s.ZIndex = 0; s.Parent = f
            spikes[#spikes + 1] = { S = s, U = cr.U + x * 0.1, Base = cr.H * (1 - 3.2 * x * x) * (0.82 + 0.18 * math.sin(j * 2.7)), W = math.floor(cr.W / cr.N * 1.15) }
        end
    end
    local seed = math.random() * 6
    return function(now, _dt)
        local surge = math.max(0, 1 - ((now + seed) % 6.5) / 0.9) -- (a surge every ~6.5 s)
        for _, sp in ipairs(spikes) do
            local w = 0.5 + 0.5 * math.sin(now * 1.6 - sp.U * 40)
            local h = sp.Base * (0.7 + 0.3 * w) * (1 + 0.45 * surge)
            sp.S.Size = UDim2.fromOffset(sp.W, math.max(2, math.floor(h + 0.5)))
            sp.S.ImageColor3 = Q.Fluid:Lerp(Q.FieldGlow, 0.3 + 0.2 * w + 0.35 * surge)
            sp.S.ImageTransparency = 0.05
        end
        line.BackgroundTransparency = 0.3 - 0.25 * surge
    local b = 0.5 + 0.5 * math.sin(now * 3.1)
        for _, m in ipairs(ctx.Marks()) do
            if m.Visible then
                for _, s in ipairs(m:GetChildren()) do
                    local h0 = s.Name == "FfMarkSpike" and s:GetAttribute("H")
                    if h0 then
                        local h = math.floor(h0 * (0.75 + 0.25 * b) * (1 + 0.6 * surge) + 0.5)
                        s.Size = UDim2.fromOffset(8, h); s.Position = UDim2.new(s.Position.X.Scale, s.Position.X.Offset, 0, -h)
                    end
                end
            end
        end
    end, nil
end
local P1 = PALETTES[1]
Set.Theme = { Name = "Ferroflux", Desc = "Black fluid under a magnetic field: fluid spikes stand on every tab and breathe with the field, and crowns of ferrofluid stand along the bottom of the screen, rippling and surging in the field's glow.",
    Panel = { Top = C(22, 18, 34), Bottom = C(8, 6, 14) }, Card = { Top = C(30, 26, 46), Bottom = C(14, 12, 24) }, Title = { Top = C(96, 34, 90), Bottom = C(34, 12, 36) },
    Accent = P1.Glow, Accent2 = C(140, 150, 190), HpFill = P1.Glow, HpBg = C(26, 8, 24), XpFill = C(255, 150, 230), Text = C(240, 214, 236),
    Tex = "tex_ff_fluid", TexT = 0.9, TexTile = 260, TexScroll = Vector2.new(3, -2), Tex2 = "tex_ff_field", Tex2T = 0.93, Tex2Tile = 240, Tex2Scroll = Vector2.new(-4, 0),
    Emblem = "EmblemFerroflux", BorderThick = 2,
    Fluid = C(104, 92, 140), Field = P1.Glow, Ink = P1.Ink,
    Deco = FfDeco, OpenFn = FfOpen, TitleDeco = FfTitle,
    Clean = FF_CLEAN, -- (SKIN UI THEMES: the clean palette + fluid-spike tab marks + the ferrofluid floor; the old art is not drawn)
    -- (SKIN UI 2026-10-29: dark fluid digits in a glow outline, bristling spikes, a crown + field ring on a kill; this colourway's P)
    Numbers = { Font = "Sarpanch", Glyph = "", NoBang = true, Motion = FfMotion, Accent = FfAccent, AccentStep = FfAccentStep,
        Normal = P.Body:Lerp(P.Mid, 0.35), Crit = P.Glow, Weak = P.Hot, Stroke = P.Glow, StrokeThick = 2, Size = 1.1 } }

-- ===== kill effect / bundle / store hero =====
Set.KillEffect = { Id = "FluxPull", Name = "Pull", Image = ART.EmblemFerroflux,
    How = "Own any Ferroflux skin (or the Ferroflux bundle)",
    Desc = "A field opens on the floor, a spiked column of black fluid bursts up out of it with a crown of smaller spikes, and the body is dragged down into it before it all slumps into a puddle and sinks away. With the Ferroflux spike banner." }
Set.Bundle = { Id = "FerrofluxBundle", Name = "Ferroflux Bundle", Price = 2199, BP = 799, ProductId = 0,
    Desc = "The whole Ferroflux set: the Ferroflux AK-47, G19 and Hyperion, the Flux Scythe, Flux Grips and Sleeves, the Ferroflux health bar and the Pull kill effect.",
    Contents = { "WeaponSkin:FerrofluxAK47", "WeaponSkin:FerrofluxGlock17", "WeaponSkin:FerrofluxRailgun", "MeleeSkin:Ferroflux", "Glove:FluxGrips", "Sleeve:FluxSleeves", "HealthBar:Ferroflux", "KillEffect:FluxPull" } }
Set.Hero = { Grad = { C(44, 16, 48), C(8, 6, 14) }, Stroke = GLOW, Emblem = ART.EmblemFerroflux, Name = C(255, 205, 245), Chip = C(110, 30, 100) }

return Set
