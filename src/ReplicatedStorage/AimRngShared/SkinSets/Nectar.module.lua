--!nocheck
-- ===================================================================================================================
-- NECTAR (Skins V3, bundle 12 of docs/SKINS_V3_PLAN.md; SKINS BUILDER 10 "skins10"): Uzi + Galil + SKS | Honey Dipper |
-- 1,199 BP. An APIARY-CRAFTED set, cosy and warm, never childish (v2 after the owner: "This looks like a honeycomb now" --
-- no cell fields anywhere): calm satin honey-lacquered wood (rounded blocks), brushed brass in stepped bands / rivets / a few
-- inlay lines, ONE signature per gun -- a brass-bezelled HONEY JAR WINDOW on the camera side (Neon parts Honey / HoneyTop /
-- Bub1..3: the lit honey IS the magazine) -- and a slow glossy glaze run. Under the muzzle a honey DROP forms and falls.
-- The guns are RESCULPTED models (WeaponAssets.SkinModels.Nectar_<GUN>, tools/skins_v3/nectar_build.py *_v2, painted by
-- tools/skin_v3_paint.py with tools/skins_v3/nectar.json).
--   ALIVE    the honey level drops a little with every shot and sloshes; bubbles rise slowly through it; the drop swells
--            under the muzzle and falls every ~6 s; a lazy pollen mote drifts off the jar
--   EQUIP    honey POURS into the jar from empty
--   INSPECT  the bubbles race up; pollen on the Tilt; a drop falls at the Settle
--   RELOAD   the jar drains as the magazine leaves, pours back as the new one seats; a honey string stretches off the magazine
-- Muzzle: a warm amber flash + golden pollen flecks. Tracer: a warm amber line with glittering pollen. Impact: a small amber
-- splat + sticky drops. Kill GOLDEN HOUR: a stream of glowing honey pours over the body, pools in a warm glow, dissolves
-- into pollen. Banner: five brass-rimmed drops that fill one per kill. Original (plan "Originality"): no candy, no alien
-- pods, no carved tribal relief or lashings, no creature on
-- the gun (the only bee is the tiny one engraved on the UI emblem).
-- ===================================================================================================================
local Set = { Kind = "Nectar" }

local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local V = Vector3.new
local PALETTES = {
    { Name = "Wildflower", Wood = C(74, 40, 16), Brass = C(118, 84, 32), Wax = C(196, 150, 78), Dark = C(26, 14, 6), Lume = C(255, 165, 30),
      Hot = C(255, 226, 150), Amber = C(255, 150, 40), Deep = C(40, 22, 8), Text = C(255, 235, 200), Plate = C(34, 18, 6), Knit = C(70, 34, 8), Leather = C(58, 30, 12), Canvas = C(68, 34, 14), HoneyDeep = C(214, 104, 10) },
    { Name = "Buckwheat", Wood = C(48, 26, 16), Brass = C(120, 66, 40), Wax = C(180, 130, 90), Dark = C(18, 9, 5), Lume = C(255, 130, 30),
      Hot = C(255, 210, 150), Amber = C(240, 120, 30), Deep = C(30, 16, 8), Text = C(250, 228, 200), Plate = C(26, 13, 6), Knit = C(56, 25, 9), Leather = C(44, 22, 12), Canvas = C(52, 28, 16), HoneyDeep = C(190, 78, 12) },
    { Name = "Lavender Honey", Wood = C(56, 28, 56), Brass = C(118, 116, 128), Wax = C(204, 186, 216), Dark = C(20, 10, 22), Lume = C(230, 170, 255),
      Hot = C(250, 230, 255), Amber = C(220, 170, 255), Deep = C(34, 18, 36), Text = C(246, 236, 255), Plate = C(28, 14, 30), Knit = C(58, 28, 62), Leather = C(52, 30, 54), Canvas = C(56, 42, 60), HoneyDeep = C(160, 96, 210) },
}
local P = PALETTES[VAR] or PALETTES[1]
local WOOD, BRASS, WAX, LUME, HOT, AMBER = P.Wood, P.Brass, P.Wax, P.Lume, P.Hot, P.Amber
Set.Palettes = PALETTES
Set.Colors = { Glow = LUME, Hot = HOT, Accent = WAX, Mid = BRASS }
-- art (tools/make_nectar_art.py, uploaded as decals; these are IMAGE ids). "" = not uploaded yet: every user has a fallback.
local A = "rbxassetid://"
Set.Art = {
    EmblemNectar = A .. "102759063297032", nc_emblem = A .. "102759063297032", nc_emblem_mask = A .. "133095008972957", nc_cell = A .. "119232089609080",
    nc_pollen = A .. "135197285608488", nc_drop = A .. "92917918177671", nc_splat = A .. "119337688071789", nc_ring = A .. "97440209465448",
    nc_corner = A .. "109393202325416", tex_nc_comb = A .. "135024265103786", tex_nc_bar = A .. "118605387135863",
    tex_nc_knit = A .. "89203084490930", tex_nc_leather = A .. "81098808393287", tex_nc_canvas = A .. "115654234809035", -- (skins10 gate rework: the arm blocks read as flat colour; IMAGE ids resolved in Studio)
}
local ART = Set.Art
local function Tex(key: string, fallback: string): string
    local t = ART[key]
    return (t and t ~= "") and t or fallback
end

local TAU = math.pi * 2
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function pulse(t, w) return math.exp(-(t / w) ^ 2) end

-- the lit spots per gun (gun-space studs, from the sculpts): the honey jar window (camera side), the muzzle, the drop
local DATA = {
    UZI = { Jar = V(-0.07, 0.115, -0.1), Muzzle = V(0.82, 0.125, 0), Drop = V(0.79, 0.071, 0) },
    GALIL = { Jar = V(-0.46, 0.175, -0.13), Muzzle = V(1.62, 0.195, -0.018), Drop = V(1.6, 0.138, -0.018) },
    SKS = { Jar = V(-0.43, 0.117, -0.128), Muzzle = V(1.82, 0.19, -0.03), Drop = V(1.62, 0.126, -0.02) },
}

local function GunDesc(gun: string): string
    local what = (gun == "GALIL") and "a rounded honey-wood handguard, stock, grips and magazine, a raised honey-wood panel on the receiver"
        or (gun == "SKS") and "a carved honey-wood stock and handguard panels, a raised honey-wood panel on the receiver"
        or "the receiver a rounded block of honey wood under a riveted honey-wood top cap"
    return "Apiary-crafted: " .. what .. ", stepped brass bands and rivets, and a slow run of glossy honey glaze. On the camera side a brass-bezelled HONEY JAR window shows the magazine as lit honey: the level drops with every shot, sloshes, drains on the reload and pours back in, while little bubbles rise through it. A honey drop slowly forms under the grooved brass muzzle and falls. Every kill brings GOLDEN HOUR."
end

-- ===== the guns =====
Set.GunSkins = {
    { Id = "NectarUZI", Name = "Nectar Uzi", Gun = "UZI", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("UZI"),
      Model = "Nectar_UZI", V3 = true, Color = LUME, Color2 = P.HoneyDeep, Deco = "NectarGun", Fit = { G = "UZI" } },
    { Id = "NectarGALIL", Name = "Nectar Galil", Gun = "GALIL", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("GALIL"),
      Model = "Nectar_GALIL", V3 = true, Color = LUME, Color2 = P.HoneyDeep, Deco = "NectarGun", Fit = { G = "GALIL" } },
    { Id = "NectarSKS", Name = "Nectar SKS", Gun = "SKS", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("SKS"),
      Model = "Nectar_SKS", V3 = true, Color = LUME, Color2 = P.HoneyDeep, Deco = "NectarGun", Fit = { G = "SKS" } },
}

-- ===== build: the amber caps take the colourway's amber; first person gets the pollen mote + the falling drop emitter =====
Set.Build = {}
Set.Build.NectarGun = function(model: Model, frame: BasePart, f: any, forView: boolean, H: any)
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p:GetAttribute("IceClear") then
            -- (v2: the jar's glass is a pale, mostly clear glass -- an amber-tinted pane read as full honey even when the
            -- jar was empty mid-reload)
            p.Color = HOT
            p.Transparency = 0.78
            p.Reflectance = 0
            p.CastShadow = false
        end
    end
    local d = DATA[f.G or ""]
    if not d or not forView then return end
    local base = frame.CFrame
    -- a lazy pollen mote drifting up off the jar (rate 1)
    local ac = H.Att(frame, (base * CFrame.new(d.Jar)).Position)
    ac.Name = "NcPollenAt"
    local pol = H.Emitter(ac, { Name = "NcPollen", Texture = Tex("nc_pollen", H.SPARK), Color = { HOT, LUME }, Size = { 0.025, 0.012 }, Life = { 1.4, 2.2 },
        Speed = { 0.05, 0.15 }, Spread = 60, Trans = { 0.2, 1 }, Light = 0.6, Rate = 1, Drag = 0.6 })
    pol.Acceleration = V(0, 0.12, 0)
    -- the falling drop + the honey string (Rate 0, emitted by Drive / events)
    local ad = H.Att(frame, (base * CFrame.new(d.Drop - V(0, 0.03, 0))).Position)
    ad.Name = "NcDropAt"
    local fall = H.Emitter(ad, { Name = "NcFall", Texture = Tex("nc_drop", H.Art.Glow or H.SPARK), Color = { LUME, AMBER }, Size = { 0.035, 0.028 },
        Life = { 0.45, 0.55 }, Speed = { 0, 0.1 }, Spread = 5, Trans = { 0, 0.4 }, Light = 0.8, Rate = 0, Drag = 0 })
    fall.Acceleration = V(0, -12, 0)
end

-- ===== sounds (tools/skins_v3/nectar_sfx.py: each gun's own recorded shot + a warm wooden tok + a soft low drip; every
-- moment from CC0 recordings). Id 0 = silent until uploaded. =====
Set.Sounds = {
    Fire = { Id = 0, Volume = 0 }, Equip = { Id = 134991935003008, Volume = 0.4 }, MagOut = { Id = 129640068551287, Volume = 0.34 },
    MagIn = { Id = 135834313753926, Volume = 0.34 }, Kill = { Id = 74087780466657, Volume = 0.5 }, Impact = { Id = 135805958241692, Volume = 0.2 },
    Swing = { Id = 95990408736010, Volume = 0.38 }, MeleeHit = { Id = 133483214122271, Volume = 0.42 }, Drip = { Id = 103453514294377, Volume = 0.2 },
    -- (each gun's own full shot; level vs the base shot: Uzi +0.2, Galil +2.5, SKS +1.9 dB -> 0.93 / 0.71 / 0.76; the Galil + SKS
    -- files were then turned down by audio_screen --quieten 1.4 / 0.7 dB -> x1.17 / x1.08)
    FireGun = { UZI = { Id = 138940406545337, Volume = 0.93 }, GALIL = { Id = 78855719503854, Volume = 0.83 }, SKS = { Id = 109920926293491, Volume = 0.82 } },
}
local function PlaySound(H: any, d: any, pitch: number?)
    if not d or (d.Id or 0) == 0 then return end
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. tostring(d.Id)
    s.Volume = d.Volume or 0.4
    s.PlaybackSpeed = pitch or 1
    local grp = H.SoundService:FindFirstChild("AimRngMix_Weapons")
    if grp then s.SoundGroup = grp end
    s.Parent = H.SoundService
    s:Play()
    H.Debris:AddItem(s, 3)
end

-- ===== motion: every key the parts read =====
-- Honey (the jar's fill: ScaleDrive up from the window floor = the magazine level), HoneyTop (the lit meniscus band:
-- ShiftDrive 0 = at the full mark, 1 = down at the floor), Bub1..3 (bubbles: 0 = the floor, 1 = the full mark -- kept
-- under the current level, popping at the surface), Drip (the drop under the muzzle: 0 = gone, 1 = full). v = rig.SkinVars.
local DRIP_PERIOD = 6.2
local function Keys(st: any, v: any, now: number, anim: string?, animT: number?, dt: number)
    local ss = st.SinceShot or 99
    local se = st.SinceEquip or 99
    local rl = st.Reload or 0
    local ammo = math.clamp(st.Ammo or 1, 0, 1)
    -- the level: the magazine; poured in on the draw, drained as the magazine leaves, poured back as the new one seats
    local lvl = ammo
    if rl > 0.12 and rl < 0.62 then lvl = ammo * (1 - smooth((rl - 0.12) / 0.22))
    elseif rl >= 0.62 and rl < 0.98 then lvl = smooth((rl - 0.62) / 0.32) end
    if se < 0.9 then lvl = lvl * smooth((se - 0.08) / 0.7) end
    -- syrupy: it eases toward the level, and every shot sets it sloshing for a moment
    local cur = v.Level or lvl
    cur += (lvl - cur) * math.min(1, dt * 7)
    v.Level = cur
    local slosh = 0.035 * math.sin(ss * 22) * math.exp(-ss * 5)
    local shown = math.clamp(cur + slosh, 0, 1)
    st.Honey = math.max(0.002, shown)
    st.HoneyTop = 1 - shown
    -- three bubbles rising slowly from the floor to the surface (faster through the inspect)
    v.BubT = (v.BubT or math.random() * 4) + dt * ((anim == "Inspect") and 2.8 or 1)
    for i, ph in ipairs({ 0, 0.37, 0.71 }) do
        st["Bub" .. i] = shown * (((v.BubT / (3.1 + i * 0.7)) + ph) % 1)
    end
    -- the drop: swells for 4.6 s, hangs heavy, falls (OnDrip fires once per fall)
    local cyc = (now + (v.DripPhase or 0)) % DRIP_PERIOD
    local grow = smooth(cyc / 4.6)
    st.Drip = (cyc < DRIP_PERIOD - 0.25) and (0.05 + 0.95 * grow) or 0.0
    local n = math.floor((now + (v.DripPhase or 0)) / DRIP_PERIOD)
    if v.DripN ~= n then
        local first = v.DripN == nil
        v.DripN = n
        if not first then v.DripFell = now end
    end
    if v.ForceDrop then -- (the inspect's Settle beat: a drop falls now)
        v.ForceDrop = nil
        v.DripPhase = (v.DripPhase or 0) + (DRIP_PERIOD - cyc) - 0.24
        v.DripFell = now
    end
end
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    local v = rig.SkinVars
    if rig.Def and rig.Def.IsMelee then
        local an, at = rig.AnimName, rig.AnimTime
        local fz = 0
        if an == "Inspect" and at then fz = smooth((at - 0.3) / 1.2) * (1 - smooth((at - 2.4) / 0.4)) end
        local cyc = (now + (v.DripPhase or 0)) % 5
        st.MDrip = 0.05 + 0.95 * smooth(cyc / 4.2) * (cyc < 4.75 and 1 or 0)
        st.Core = math.clamp(0.45 + 0.12 * math.sin(now * TAU / 3.2) + fz * 0.4, 0, 1)
        return
    end
    local an, at = rig.AnimName, rig.AnimTime
    if an == "Inspect" and rig.Anim and rig.Anim.Beats then
        local b = rig.Anim.Beats
        v.Present, v.Tilt = b.Present or v.Present, b.Tilt or b.Flip or b.Rack or v.Tilt
    end
    local fell = v.DripFell
    Keys(st, v, now, an, at, dt)
    if v.DripFell ~= fell then
        local fe = v.Fall or (rig.Gun and rig.Gun:FindFirstChild("NcFall", true))
        v.Fall = fe
        if fe then fe:Emit(1) end
        PlaySound(H, Set.Sounds.Drip, 0.9 + math.random() * 0.2)
    end
end
local function GunPartPos(rig: any, name: string): Vector3?
    local gp = rig.GunParts and rig.GunParts[name]
    return gp and gp.Part and gp.Part.Position or nil
end
-- a thin glossy honey string stretching off the magazine and snapping (the reload): a short Beam between the mag well and
-- the leaving magazine, thinning to nothing
local function HoneyString(H: any, rig: any)
    local gp = rig.GunParts and rig.GunParts.Magazine
    if not gp or not gp.Part or not rig.Gun then return end
    local frame = rig.Gun:FindFirstChild("Frame")
    if not frame then return end
    local a0 = Instance.new("Attachment"); a0.Parent = frame
    a0.WorldPosition = gp.Part.Position + V(0, gp.Part.Size.Y * 0.45, 0)
    local a1 = Instance.new("Attachment"); a1.Parent = gp.Part
    local b = Instance.new("Beam")
    b.Attachment0, b.Attachment1 = a0, a1
    b.Color = ColorSequence.new(LUME, AMBER); b.LightEmission = 0.5; b.LightInfluence = 0.3; b.FaceCamera = true; b.Segments = 6
    b.CurveSize0, b.CurveSize1 = -0.05, 0.05
    b.Width0, b.Width1 = 0.012, 0.006
    b.Transparency = NumberSequence.new(0.15)
    b.Parent = frame
    H.Animate(0.45, function(t)
        local k = t / 0.45
        b.Width0, b.Width1 = 0.012 * (1 - k), 0.006 * (1 - k)
        b.Transparency = NumberSequence.new(0.15 + 0.85 * smooth((k - 0.6) / 0.4))
    end, function() b:Destroy(); a0:Destroy(); a1:Destroy() end)
end
Set.OnEvent = function(rig: any, name: string, H: any, data: any)
    local v = rig.SkinVars
    if not v then return end
    if name == "MagOut" then
        HoneyString(H, rig)
    elseif name == "MagIn" then
        PlaySound(H, Set.Sounds.Drip, 1.1)
    elseif name == "Tilt" or name == "Flip" then
        local fl = v.PollenEm or (rig.Gun and rig.Gun:FindFirstChild("NcPollen", true))
        v.PollenEm = fl
        if fl then fl:Emit(6) end
    elseif name == "Settle" then
        v.ForceDrop = true
    end
    if rig.Def and rig.Def.IsMelee and name == "Flip" then v.DripPhase = (v.DripPhase or 0) + 2 end
end
Set.OnEquip = function(rig: any, H: any)
    if rig.SkinVars then
        rig.SkinVars.Phase = math.random() * 4
        rig.SkinVars.DripPhase = math.random() * 2
    end
    if not Set._Preloaded then
        Set._Preloaded = true
        task.spawn(function()
            local list = {}
            for _, k in ipairs({ "nc_cell", "nc_pollen", "nc_drop", "nc_splat", "nc_ring", "nc_emblem" }) do
                if ART[k] ~= "" then table.insert(list, ART[k]) end
            end
            pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
        end)
    end
end
-- other players' guns: the shimmer + the drop
Set.World = function(rec: any, now: number, st: any)
    local v = rec.Vars
    st.SinceShot = 99; st.SinceEquip = 99; st.Reload = 0; st.Streak = 1
    v.Phase = v.Phase or math.random() * 4
    v.DripPhase = v.DripPhase or math.random() * 6
    Keys(st, v, now, nil, nil, 1 / 30)
    st.MDrip = 0.6
    st.Core = 0.5
end

-- ===== muzzle: a warm amber flash + a few golden pollen flecks =====
Set.Muzzle = function(rig: any, flash: ParticleEmitter, light: PointLight, muzzle: Attachment, H: any)
    flash.Color = ColorSequence.new(HOT, LUME)
    flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(1, 0.03) })
    light.Color = LUME
    light.Brightness = 0.6
    rig.Fx.NcFlecks = H.Emitter(muzzle, { Name = "NcFlecks", Texture = Tex("nc_pollen", H.SPARK), Color = { HOT, LUME }, Size = { 0.03, 0.008 },
        Life = { 0.25, 0.45 }, Speed = { 1.2, 2.6 }, Spread = 28, Trans = { 0.05, 1 }, Light = 1, Drag = 3, Dir = Enum.NormalId.Right })
end
Set.OnFire = function(rig: any, H: any)
    if rig.Fx and rig.Fx.NcFlecks then rig.Fx.NcFlecks:Emit(3) end
end

-- ===== tracer: a warm amber line with tiny pollen flecks glittering behind =====
Set.Tracer = function(H: any, from: Vector3, to: Vector3, peer: boolean?)
    local dist = (to - from).Magnitude
    if dist < 1.5 then return end
    local host = H.FxPart({ Transparency = 1, Size = V(0.05, 0.05, 0.05), CFrame = CFrame.new(from) })
    local a0, a1 = H.Att(host, from), H.Att(host, to)
    local core = Instance.new("Beam")
    core.Attachment0, core.Attachment1 = a0, a1
    core.Color = ColorSequence.new(HOT, LUME); core.LightEmission = 1; core.LightInfluence = 0; core.FaceCamera = true; core.Segments = 1
    core.Width0, core.Width1 = 0.014, peer and 0.03 or 0.045
    core.Parent = host
    local fl = Instance.new("Beam")
    fl.Attachment0, fl.Attachment1 = a0, a1
    fl.Texture = Tex("nc_pollen", H.SPARK); fl.TextureMode = Enum.TextureMode.Static; fl.TextureLength = 0.7; fl.TextureSpeed = 0
    fl.Color = ColorSequence.new(HOT, LUME); fl.LightEmission = 1; fl.LightInfluence = 0; fl.FaceCamera = true; fl.Segments = 1
    fl.Width0, fl.Width1 = 0.05, peer and 0.1 or 0.13
    fl.Parent = host
    local dir = (to - from).Unit
    local travel = H.TRAVEL -- (hitscan: the shot is there at once, nothing flies)
    local dur = travel + 0.3
    H.Animate(dur, function(t)
        local hk = math.clamp(t / travel, 0, 1)
        a1.WorldPosition = from + dir * dist * hk
        local after = math.max(0, t - travel) / (dur - travel)
        core.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7 + 0.3 * after), NumberSequenceKeypoint.new(1, math.clamp(0.1 + after * 1.6, 0, 1)) })
        fl.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, math.clamp(0.5 + after, 0, 1)), NumberSequenceKeypoint.new(1, math.clamp(0.15 + after * 0.9, 0, 1)) })
    end, function() host:Destroy() end)
end

-- ===== impact: a small amber splat on the surface + a few sticky drops, fading =====
Set.Impact = function(H: any, pos: Vector3, normal: Vector3?, peer: boolean?)
    if not H.Budget("NectarImpact", peer and 3 or 8, 0.5) then return end
    local n = (normal and normal.Magnitude > 0.1) and normal.Unit or V(0, 1, 0)
    local face = CFrame.lookAt(pos + n * 0.02, pos + n * 2) * CFrame.Angles(0, 0, math.random() * TAU)
    local p = H.FxPart({ Transparency = 1, Size = V(0.2, 0.2, 0.02), CFrame = face })
    local splat = Instance.new("Decal")
    splat.Texture = Tex("nc_splat", Tex("nc_cell", "")); splat.Face = Enum.NormalId.Front; splat.Color3 = AMBER; splat.Transparency = 0.1
    splat.Parent = p
    local att = H.Att(p, pos + n * 0.03)
    local em = H.Emitter(att, { Name = "NcImpactDrops", Texture = Tex("nc_drop", H.SPARK), Color = { LUME, AMBER }, Size = { 0.05, 0.02 }, Life = { 0.2, 0.35 },
        Speed = { 1.5, 3.5 }, Spread = 40, Trans = { 0.05, 1 }, Light = 0.6, Drag = 4 })
    em.EmissionDirection = Enum.NormalId.Front
    em.Acceleration = V(0, -8, 0)
    em:Emit(peer and 3 or 5)
    H.Animate(0.65, function(t)
        local k = t / 0.65
        local e = 1 - (1 - math.min(1, k * 2.6)) ^ 3
        local s = 0.12 + 0.34 * e
        p.Size = V(s, s, 0.02)
        splat.Transparency = math.clamp(0.1 + math.max(0, k - 0.4) * 1.5, 0, 1)
    end, function() p:Destroy() end)
end

-- ===== HONEY POUR kill (FX roll-out 2026-10-14; v1 "Golden Hour" = a thin honey line onto the head + an orange glow blob,
-- its pool floated -- scored 1.5: "a line and a smudge, nothing reads at range"). ONE idea: the enemy is GLAZED AND MELTED.
-- A brass-banded honey jar tips over above the head and pours a thick glowing stream; the honey coats the body from the
-- top down (a glossy amber glaze over its own shapes), then the whole glazed body SLUMPS -- every piece sags and runs down
-- into a wide glossy puddle on a dark rim (the ink backing), which deepens in colour as it sets, a few bubbles pop, and it
-- sinks away. 1.35 s. Motion is DOWN. The glaze is see-through amber, not a light, and has run off the body by ~0.6 s.
-- Budget: full jar 2 + stream host 1 + <= 8 glazed pieces + puddle 2 = 13 parts, 1 beam, <= 10 bubble sprites;
-- low: jar + stream + puddle (4 parts), no glaze, no bubbles. =====
local function NcBodyParts(pos: Vector3, H: any): ({ BasePart }, number)
    local op = OverlapParams.new()
    op.FilterType = Enum.RaycastFilterType.Exclude
    local ex = { H.FxFolder() }
    for _, pl in ipairs(H.Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
    if workspace.CurrentCamera then table.insert(ex, workspace.CurrentCamera) end
    op.FilterDescendantsInstances = ex
    local best, count = nil, {}
    for _, p in ipairs(workspace:GetPartBoundsInRadius(pos, 3.5, op)) do
        local m = p:FindFirstAncestorOfClass("Model")
        while m and not (m:FindFirstChild("Head") or m:FindFirstChild("Torso")) do m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model") end
        if m then count[m] = (count[m] or 0) + 1; if not best or count[m] > count[best] then best = m end end
    end
    local out, top = {}, pos.Y + 0.8
    if best then
        for _, p in ipairs(best:GetDescendants()) do
            if p:IsA("BasePart") and p.Transparency < 0.6 and p.Size.Magnitude < 12 then table.insert(out, p) end
        end
        table.sort(out, function(a, b) return a.Size.Magnitude > b.Size.Magnitude end)
        local ok, cf, size = pcall(function() return best:GetBoundingBox() end)
        if ok and size.Magnitude < 20 then top = cf.Position.Y + size.Y / 2 end
    end
    return out, top
end
Set.Kill = function(H: any, pos: Vector3, low: boolean)
    local g = H.Ground(pos)
    local srcs, top = NcBodyParts(pos, H)
    top = math.max(top, g.Y + 2.5)
    local model = Instance.new("Model"); model.Name = "NectarKill"; model.Parent = H.FxFolder()
    local cam = workspace.CurrentCamera
    local rt = cam and cam.CFrame.RightVector or V(1, 0, 0)
    rt = V(rt.X, 0, rt.Z)
    rt = (rt.Magnitude > 0.05) and rt.Unit or V(1, 0, 0)
    local face = CFrame.fromMatrix(V(pos.X, top, pos.Z), rt, V(0, 1, 0)) -- (+Z toward you)
    -- the jar: amber glass with a brass band, upright above the head, then tipped toward the body
    local jarAt = face * CFrame.new(-0.9, 2.2, 0)
    local jar = H.FxPart({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Color = P.HoneyDeep, Reflectance = 0.12,
        Size = V(1.5, 1.15, 1.15), Transparency = 1, CFrame = jarAt }, model)
    local band = H.FxPart({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Color = BRASS:Lerp(C(255, 230, 170), 0.2), Reflectance = 0.2,
        Size = V(0.3, 1.25, 1.25), Transparency = 1, CFrame = jarAt }, model)
    -- the stream: a thick glowing honey beam from the jar's mouth to the head
    local sh = H.FxPart({ Transparency = 1, Size = V(0.1, 0.1, 0.1), CFrame = CFrame.new(face.Position) }, model)
    local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
    a0.Parent, a1.Parent = sh, sh
    local beam = Instance.new("Beam"); beam.Attachment0, beam.Attachment1 = a0, a1
    beam.Color = ColorSequence.new(HOT, AMBER); beam.LightEmission = 0.5; beam.LightInfluence = 0.2; beam.FaceCamera = true; beam.Segments = 10
    beam.Width0, beam.Width1 = 0, 0; beam.Transparency = NumberSequence.new(0.1); beam.Parent = sh
    -- the glaze: the body's own shapes coated in see-through amber (cloned shells, slightly bigger)
    local glaze = {}
    if not low then
        for _, src in ipairs(srcs) do
            if #glaze >= 8 then break end
            local p = H.FxPart({ Material = Enum.Material.SmoothPlastic, Color = AMBER, Reflectance = 0.15, Transparency = 1,
                Size = src.Size * 1.08 + V(0.05, 0.05, 0.05), CFrame = src.CFrame }, model)
            table.insert(glaze, { P = p, CF = src.CFrame, S = p.Size, Y = src.Position.Y,
                Out = (V(src.Position.X - pos.X, 0, src.Position.Z - pos.Z)) })
        end
    end
    -- the puddle: a glossy honey disc on a dark rim (ink backing), on the real floor
    local R = 2.7
    local rim = H.FxPart({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Color = P.Dark, Transparency = 1,
        Size = V(0.06, 0.4, 0.4), CFrame = CFrame.new(g + V(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, model)
    local pud = H.FxPart({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Color = AMBER, Reflectance = 0.25, Transparency = 1,
        Size = V(0.1, 0.3, 0.3), CFrame = CFrame.new(g + V(0, 0.07, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, model)
    local bubbles = (not low) and H.Emitter(pud, { Texture = Tex("nc_ring", H.SPARK), Color = { HOT, LUME }, Size = { 0.25, 0.45 }, Life = { 0.25, 0.4 },
        Speed = { 0.2, 0.6 }, Spread = 20, Dir = Enum.NormalId.Right, Light = 0.4, Trans = { 0.1, 1 } }) or nil
    local dur = low and 1.0 or 1.35
    local popped = false
    H.Animate(dur, function(t)
        local out = smooth((t - (dur - 0.28)) / 0.26)
        -- 1) the jar appears and TIPS (0 -> 0.16), pours, rights itself and lifts away (0.6 -> 0.8)
        local tip = smooth(t / 0.16) * (1 - smooth((t - 0.6) / 0.16))
        local away = smooth((t - 0.62) / 0.2)
        local jcf = jarAt * CFrame.new(0, away * 1.5, 0) * CFrame.Angles(0, 0, math.rad(90) - math.rad(125) * tip)
        jar.CFrame = jcf; band.CFrame = jcf * CFrame.new(0.2, 0, 0)
        local ja = math.clamp(1 - smooth(t / 0.06) + away, 0, 1)
        jar.Transparency = math.clamp(0.15 + ja, 0, 1); band.Transparency = ja
        -- 2) the stream: from the mouth to the head, thick, thinning as it runs out (0.1 -> 0.6)
        local mouth = (jcf * CFrame.new(0.75, 0, 0)).Position
        a0.WorldPosition = mouth
        local reach = smooth((t - 0.08) / 0.1)
        a1.WorldPosition = mouth:Lerp(V(pos.X, top + 0.05, pos.Z), reach)
        local w = (t < 0.08) and 0 or 0.55 * (1 - smooth((t - 0.45) / 0.18))
        beam.Width0, beam.Width1 = w * 0.8, w
        -- 3) the glaze coats the body top-down (0.15 -> 0.38), then SLUMPS: every piece sags and runs down (0.4 -> 0.8)
        local slump = smooth((t - 0.4) / 0.4)
        for _, q in ipairs(glaze) do
            local coat = smooth((t - 0.15 - math.max(0, (top - q.Y)) * 0.05) / 0.1)
            local sy = q.S.Y * (1 - 0.82 * slump)
            local y = q.Y + (g.Y + sy / 2 + 0.05 - q.Y) * slump
            local spread = 1 + 0.6 * slump
            q.P.Size = V(q.S.X * spread, sy, q.S.Z * spread)
            q.P.CFrame = CFrame.new(V(pos.X, y, pos.Z) + q.Out * (1 + 0.8 * slump)) * (q.CF - q.CF.Position):Lerp(CFrame.new(), slump)
            q.P.Transparency = math.clamp(1 - coat * 0.62 + smooth((slump - 0.7) / 0.3), 0, 1)
        end
        -- 4) the puddle spreads (0.35 -> 0.85), sets darker, bubbles pop, it sinks away
        local spread = smooth((t - (low and 0.15 or 0.35)) / 0.5)
        local r = 0.3 + (R - 0.3) * spread
        pud.Size = V(0.1, r * 2, r * 2); rim.Size = V(0.06, r * 2 + 0.35, r * 2 + 0.35)
        local set = smooth((t - 0.85) / 0.3)
        pud.Color = AMBER:Lerp(P.HoneyDeep, set)
        pud.Transparency = (spread <= 0) and 1 or math.clamp(0.08 + out, 0, 1)
        rim.Transparency = (spread <= 0) and 1 or math.clamp(0.15 + out, 0, 1)
        local sink = out * 0.06
        pud.CFrame = CFrame.new(g + V(0, 0.07 - sink, 0)) * CFrame.Angles(0, 0, math.rad(90))
        rim.CFrame = CFrame.new(g + V(0, 0.04 - sink, 0)) * CFrame.Angles(0, 0, math.rad(90))
        if bubbles and not popped and t > 0.9 then popped = true; bubbles:Emit(10) end
    end, function() model:Destroy() end)
end

-- ===== the HONEY banner (lower right, beside the weapon card): a dark plate with five brass-rimmed drops in a row; each kill
-- in the streak fills one more drop with honey (it pours up from the bottom) =====
local banner
local NUMFONT = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold)
local WORDS = { "SWEET", "GOLDEN", "HONEYED", "OVERFLOW", "GOLDEN HOUR" }
local CELLPOS = { { 16, 58 }, { 34, 58 }, { 52, 58 }, { 70, 58 }, { 88, 58 } }
Set.Banner = function(H: any, streak: number)
    local gui, root = H.BannerRoot("Nectar", Vector2.new(180, 90), "Side")
    if not root then return end
    local New = H.New
    if not banner or banner.Root ~= root then
        local plate = New("Frame", { BackgroundColor3 = P.Plate, BackgroundTransparency = 0.08, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, root,
            { New("UICorner", { CornerRadius = UDim.new(0, 6) }), New("UIStroke", { Color = BRASS, Thickness = 1.5, Transparency = 0.2 }),
              New("UIGradient", { Color = ColorSequence.new(C(255, 255, 255), C(170, 150, 130)), Rotation = 90 }) })
        local cells = {}
        for i, cp in ipairs(CELLPOS) do
            local holder = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cp[1], cp[2]),
                Size = UDim2.fromOffset(18, 27), ZIndex = 2, ClipsDescendants = true }, root)
            local rim = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("nc_drop", ""), ImageColor3 = BRASS, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, holder)
            local fill = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("nc_drop", ""), ImageColor3 = LUME, AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.86, 0), ZIndex = 3, ScaleType = Enum.ScaleType.Crop }, holder)
            if Tex("nc_drop", "") == "" then
                -- (no art yet: plain squares rotated 45 deg as cells)
                rim.Image = ""; rim.BackgroundTransparency = 0.6; rim.BackgroundColor3 = BRASS; rim.Rotation = 45; rim.Size = UDim2.fromScale(0.7, 0.7)
                rim.AnchorPoint = Vector2.new(0.5, 0.5); rim.Position = UDim2.fromScale(0.5, 0.5)
                fill.Image = ""; fill.BackgroundTransparency = 0; fill.BackgroundColor3 = LUME
            end
            cells[i] = { Holder = holder, Rim = rim, Fill = fill }
        end
        local glow = New("ImageLabel", { BackgroundTransparency = 1, Image = H.Art.Glow, ImageColor3 = LUME, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(48, 58), Size = UDim2.fromOffset(110, 80), ImageTransparency = 0.85, ZIndex = 1 }, root)
        local num = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(104, 30), Size = UDim2.fromOffset(72, 30),
            FontFace = NUMFONT, TextSize = 28, TextColor3 = P.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 3 }, root)
        num:SetAttribute("KeepFont", true)
        local word = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(104, 60), Size = UDim2.fromOffset(72, 18),
            FontFace = NUMFONT, TextSize = 13, TextColor3 = WAX, TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextScaled = false, ZIndex = 3 }, root)
        word:SetAttribute("KeepFont", true)
        banner = { Root = root, Plate = plate, Cells = cells, Glow = glow, Num = num, Word = word, Token = 0 }
    end
    local b = banner
    b.Token += 1
    local token = b.Token
    local st = math.clamp(streak or 1, 1, 5)
    root.Visible = true
    b.Plate.BackgroundTransparency = 0.08
    b.Num.TextTransparency = 0; b.Word.TextTransparency = 0
    b.Num.Text = "x" .. st
    b.Word.Text = WORDS[st]
    b.Num.TextColor3 = (st >= 5) and LUME or P.Text
    for i, c in ipairs(b.Cells) do
        c.Fill.Size = UDim2.fromScale(0.86, (i < st) and 0.86 or 0)
        c.Fill.ImageTransparency = 0; c.Fill.BackgroundTransparency = (Tex("nc_drop", "") == "") and 0 or 1
        c.Rim.ImageTransparency = 0
    end
    local newCell = b.Cells[st]
    H.Animate(0.4, function(t)
        if b.Token ~= token then return end
        local k = 1 - (1 - t / 0.4) ^ 3
        newCell.Fill.Size = UDim2.fromScale(0.86, 0.86 * k)
        b.Glow.ImageTransparency = 0.85 - 0.35 * math.sin(k * math.pi) * (st >= 5 and 1.4 or 0.8)
    end)
    task.delay(1.6, function()
        if b.Token ~= token then return end
        local ti = TweenInfo.new(0.3)
        H.TweenService:Create(b.Plate, ti, { BackgroundTransparency = 1 }):Play()
        H.TweenService:Create(b.Num, ti, { TextTransparency = 1 }):Play()
        H.TweenService:Create(b.Word, ti, { TextTransparency = 1 }):Play()
        H.TweenService:Create(b.Glow, ti, { ImageTransparency = 1 }):Play()
        for _, c in ipairs(b.Cells) do
            H.TweenService:Create(c.Fill, ti, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
            H.TweenService:Create(c.Rim, ti, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
        end
        task.delay(0.32, function() if b.Token == token then root.Visible = false end end)
    end)
end

-- ===== the HONEY DIPPER (melee, Blunt class): WeaponAssets.MeleeModels.Nectar -- a grooved honey-wood dipper head on a
-- turned honey-wood handle with brass rings and a brass knob, a glossy honey glaze coating the head; a drop slowly forms
-- under the head and falls. =====
Set.Melee = {
    Skin = { Name = "Honey Dipper", Price = 449, ProductId = 0,
        Desc = "A grooved honey dipper turned from dark honey wood, brass rings on its handle and a glossy glaze of honey on its head. A drop slowly gathers under the head and falls. Every kill brings GOLDEN HOUR." },
    Rig = { Class = "Blunt", BladeLen = 1.0 },
    Build = function(m: Model, o: any, H: any)
        local parts = H.CloneModel(m, "MeleeModels", "Nectar", VAR, { [1] = LUME })
        local head = parts.Blade
        if not head then return end
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Name, a1.Name = "TrailBase", "TrailTip"
        a0.Position = head.CFrame:PointToObjectSpace(head.Position - head.CFrame.UpVector * 0.15)
        a1.Position = head.CFrame:PointToObjectSpace(head.Position + head.CFrame.UpVector * 0.2)
        a0.Parent, a1.Parent = head, head
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Color = ColorSequence.new(HOT, LUME)
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
        tr.LightEmission = 0.6; tr.LightInfluence = 0
        tr.Lifetime = 0.14; tr.MinLength = 0.02; tr.FaceCamera = true
        tr.Enabled = false
        tr:SetAttribute("SwingTrail", true)
        tr.Parent = head
    end,
}

-- ===== arms (v2, the owner: "i dont like the gloves either"): APIARY GLOVES + WAXED FIELD SLEEVES (mesh pieces,
-- WeaponAssets.ArmsModels.Nectar). Glove: a fitted dark-chocolate leather glove (leather-grain block) with a stitched back
-- panel, a padded + stitched knuckle roll, a short flared gauntlet cuff with a brass-edged rim, and ONE amber cabochon in a
-- six-prong brass collet whose inner glow slowly swells and settles (a soft flare on a kill). Sleeve: tobacco waxed canvas
-- (a mottled waxed texture, no weave grid), a stitched leather forearm patch, a turned-back cuff with a rolled lip and a
-- strap tab with a brass snap. (Ids kept from v1: the bundle never shipped.) =====
Set.Glove = function(K: any)
    local V3 = K.V
    return {
        Id = "BeekeeperGloves", Name = "Apiary Gloves", Price = 449,
        Desc = "Fitted dark-chocolate leather gloves with a stitched back panel, a padded knuckle roll and a short brass-edged gauntlet cuff. A single amber cabochon in a brass claw setting glows on the back of the hand, slowly swelling and settling, a little brighter with every kill. Part of the Nectar set.",
        Base = { Color = P.Leather, Material = Enum.Material.SmoothPlastic, Reflectance = 0, Tex = "tex_nc_leather", TexTile = 1.5, TexT = 0, TexColor = P.Leather:Lerp(C(255, 255, 255), 0.05) },
        Parts = {
            { Mesh = "Nectar/Back", MeshV = VAR, Size = V3(0.9, 0.09, 0.78), Off = V3(0, 0.53, 0.04) },
            { Mesh = "Nectar/Knuckle", MeshV = VAR, Size = V3(0.98, 0.17, 0.17), Off = V3(0, 0.5, -0.4), Seat = true },
            { Mesh = "Nectar/Gauntlet", MeshV = VAR, Size = V3(1.2, 1.2, 0.3), Off = V3(0, 0, 0.42) },
            { Mesh = "Nectar/Collet", MeshV = VAR, Size = V3(0.34, 0.12, 0.34), Off = V3(0, 0.6, 0.06), Seat = true },
            { Mesh = "Nectar/Cabochon", MeshV = VAR, Size = V3(0.25, 0.12, 0.25), Off = V3(0, 0.63, 0.06), Seat = true,
              Glow = true, Color = LUME, Anim = "Pulse", Period = 5, PulseMin = 0.2, PulseMax = 0.6, BurstOn = "Kill" },
        },
    }
end
Set.Sleeve = function(K: any)
    local V3 = K.V
    return {
        Id = "KnitSleeves", Name = "Waxed Field Sleeves", Price = 299,
        Desc = "Waxed canvas field-jacket sleeves in deep tobacco with a stitched leather forearm patch, a turned-back cuff and a strap tab with a brass snap. Part of the Nectar set.",
        Base = { Color = P.Canvas, Material = Enum.Material.SmoothPlastic, Reflectance = 0, Tex = "tex_nc_canvas", TexTile = 2.0, TexT = 0, TexColor = P.Canvas:Lerp(C(255, 255, 255), 0.05) },
        Parts = {
            { Mesh = "Nectar/Patch", MeshV = VAR, Size = V3(0.78, 0.09, 0.42), Off = V3(0, 0.52, 0.05), Seat = true },
            { Mesh = "Nectar/Cuff", MeshV = VAR, Size = V3(1.16, 1.16, 0.22), Off = V3(0, 0, -0.38) },
            { Mesh = "Nectar/Tab", MeshV = VAR, Size = V3(0.32, 0.14, 0.06), Off = V3(0, 0.6, -0.27), Rot = V3(90, 0, 0), Seat = true },
        },
    }
end

-- ===== health bar (BARS v2, FX roll-out): the house ink frame round a glowing honey fill that sloshes (a slow bright band
-- rolls along it); lost health DRAINS slowly like syrup, and every hit lets a honey drop fall from where it landed;
-- elites / bosses carry a brass band at the end of the fill =====
Set.Bar = { Id = "Nectar", Name = "Nectar", Price = 149,
    Desc = "A glass tube of honey: the amber fill sloshes and the lost honey drains away slowly like syrup, every hit letting a drop fall from where it lands. On elites and bosses a brass jar band rides the end. Part of the Nectar set.",
    Look = "Ink", FillColor = LUME, Tex = "tex_nc_bar", TexColor = LUME, TexSpeed = 0, ChipMotion = "Drain", Chip = P.HoneyDeep, Back = C(30, 16, 6), Segments = 0,
    Decor = { "Slosh", "Drips", "BrassBand" } }
Set.BarDecor = {
    Slosh = function(ctx: any, K: any)
        local band = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = HOT, Size = UDim2.new(0.22, 0, 1, 0), ZIndex = 4 }, ctx.Inner)
        K.New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 1) }) }, band)
        return function(now, dt, alpha, info)
            band.Position = UDim2.fromScale(0.39 + 0.39 * math.sin(now * 1.1) - 0.11, 0)
            band.BackgroundTransparency = 1 - alpha
        end
    end,
    Drips = function(ctx: any, K: any)
        local f = K.Fader()
        local dropImg = f.Add(K.Img(Tex("nc_drop", ""), { AnchorPoint = Vector2.new(0.5, 0), ImageColor3 = LUME, ZIndex = 11 }, ctx.Holder), 1)
        local k = 1
        local lastHit = 0
        local x = 0.5
        return function(now, dt, alpha, info)
            if (info.Hit or 0) > lastHit + 0.05 then k = 0; x = math.clamp(info.Shown, 0.03, 1) end
            lastHit = info.Hit or 0
            k = math.min(1, k + dt / 0.55)
            local s = math.max(6, ctx.H * 0.8)
            dropImg.Size = UDim2.fromOffset(s * 0.7, s)
            dropImg.Position = UDim2.fromOffset(ctx.W * x, ctx.H * (0.5 + 1.6 * k * k))
            dropImg.ImageTransparency = 1 - alpha * (1 - k) * 0.9
        end
    end,
    BrassBand = function(ctx: any, K: any)
        if ctx.Tier == "Small" then return function() end end
        local b = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = BRASS:Lerp(C(255, 230, 170), 0.3), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 12 }, ctx.Holder)
        K.New("UIStroke", { Color = P.Dark, Thickness = 1.5 }, b)
        return function(now, dt, alpha, info)
            b.Size = UDim2.fromOffset(math.max(3, ctx.H * 0.45), ctx.H * 1.5)
            b.Position = UDim2.fromOffset(ctx.W * math.max(0.02, info.Shown), ctx.H / 2)
            b.BackgroundTransparency = 1 - alpha
        end
    end,
}

-- ===== UI theme v2 (FX roll-out 2026-10-14; v1 = the shared template: watermark + motes + sparkles + a flare -- "a recolour").
-- Its own pieces, in the icon look: honey runs off the top of every window -- a glossy honey GLAZE along the top edge (flat
-- lit face, one hard facet, ink edge) with drips hanging from it that slowly stretch, and every few seconds one lets go as
-- a drop that falls a little way and is gone; brass jar-band caps sit in the bottom corners. OPEN = the pour: the glaze runs
-- along the top from the left and the drips run long down the window, then draw back up to rest (0.55 s). Title bars get a
-- honey drop and a short amber line. Colours from the theme table (Honey / HoneyDeep / Brass / Ink).
local function NcFacet(ctx, o, lit, shade, inkW)
    local g = Instance.new("UIGradient")
    g.Color = ctx.UIStyle.Facet(lit, shade)
    g.Rotation = ctx.UIStyle.FACET_ROT or 35
    g.Parent = o
    local ink = ctx.UIStyle.InkEdge(inkW or 2)
    ink.Parent = o
end
local function NcDeco(ctx)
    if ctx.Kind ~= "Window" then return nil end
    local t = ctx.Theme
    local host = ctx.Root or ctx.Surface
    local f = Instance.new("Frame")
    f.Name = "NcOverlay"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 20; f.Active = false
    f:SetAttribute("NoSkin", true); f:SetAttribute("Skinned", true)
    f.Parent = host
    local small = math.min(host.AbsoluteSize.X, host.AbsoluteSize.Y) < 260
    local gh = small and 5 or 9
    local glaze = Instance.new("Frame")
    glaze.Name = "NcGlaze"; glaze.BorderSizePixel = 0; glaze.BackgroundColor3 = Color3.new(1, 1, 1); glaze.Position = UDim2.fromOffset(0, 0)
    glaze.Size = UDim2.new(1, 0, 0, gh); glaze.ZIndex = f.ZIndex + 1; glaze.Parent = f
    NcFacet(ctx, glaze, t.Honey, t.HoneyDeep, 2)
    local drips = {}
    local xs = small and { 0.5, 0.8 } or { 0.46, 0.6, 0.74, 0.86 } -- (clear of the title text on the left)
    for i, x in ipairs(xs) do
        local d = Instance.new("Frame")
        d.Name = "NcDrip"; d.BorderSizePixel = 0; d.BackgroundColor3 = Color3.new(1, 1, 1); d.AnchorPoint = Vector2.new(0.5, 0)
        d.Position = UDim2.new(x, 0, 0, gh - 2); d.ZIndex = f.ZIndex + 1; d.Parent = f
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = d
        NcFacet(ctx, d, t.HoneyDeep, t.HoneyDeep:Lerp(Color3.new(0, 0, 0), 0.35), 2)
        table.insert(drips, { F = d, X = x, Rest = (small and 9 or 20) + (i % 2) * (small and 5 or 14), W = small and 6 or (12 + (i % 3) * 3), Ph = math.random() * 6.28 })
    end
    local drop = Instance.new("Frame")
    drop.Name = "NcDrop"; drop.BorderSizePixel = 0; drop.BackgroundColor3 = t.Honey; drop.AnchorPoint = Vector2.new(0.5, 0.5); drop.Visible = false
    drop.ZIndex = f.ZIndex + 1; drop.Parent = f
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = drop
        local ink = Instance.new("UIStroke"); ink.Color = t.Ink; ink.Thickness = 2; ink.Parent = drop end
    for _, c in ipairs({ 0, 1 }) do
        for i = 1, 2 do
            local b = Instance.new("Frame")
            b.Name = "NcBand"; b.BorderSizePixel = 0; b.BackgroundColor3 = Color3.new(1, 1, 1); b.AnchorPoint = Vector2.new(c, 1)
            b.Position = UDim2.new(c, (c == 0) and 4 or -4, 1, -4)
            b.Size = (i == 1) and UDim2.fromOffset(small and 16 or 30, small and 4 or 6) or UDim2.fromOffset(small and 4 or 6, small and 16 or 30)
            b.ZIndex = f.ZIndex + 1; b.Parent = f
            NcFacet(ctx, b, t.BrassFace, t.BrassShade, 1)
        end
    end
    f:SetAttribute("NcPour", 1)
    local nextDrop = os.clock() + 2 + math.random() * 3
    local dropAt, dropDrip = -10, 1
    return function(now, dt)
        local pour = f:GetAttribute("NcPour") or 1
        glaze.Size = UDim2.new(math.clamp(pour * 1.6, 0, 1), 0, 0, gh)
        -- (the pour runs the drips long, then they draw back up to rest)
        local long = math.sin(math.clamp(pour, 0, 1) * math.pi)
        local hh = f.AbsoluteSize.Y
        for i, d in ipairs(drips) do
            local breathe = 1 + 0.25 * math.sin(now * 0.7 + d.Ph)
            local let = (i == dropDrip and now - dropAt < 0.6) and math.max(0, 1 - (now - dropAt) / 0.25) * 0.6 or 0
            local len = (pour < 1) and (d.Rest + long * hh * 0.35 * (0.7 + 0.3 * (i % 2))) or d.Rest * (breathe + let)
            d.F.Size = UDim2.fromOffset(d.W, math.max(2, len * math.clamp(pour * 3 - (d.X * 1.5), 0, 1)))
        end
        if now >= nextDrop and pour >= 1 then
            nextDrop = now + 5 + math.random() * 4
            dropAt, dropDrip = now, math.random(1, #drips)
            drop.Visible = true
        end
        local k = (now - dropAt) / 0.7
        if k < 1 then
            local d = drips[dropDrip]
            local s = d.W + 1
            drop.Size = UDim2.fromOffset(s, s * 1.15)
            drop.Position = UDim2.new(d.X, 0, 0, gh + d.Rest * 1.4 + 70 * k * k)
            drop.BackgroundTransparency = math.clamp((k - 0.6) / 0.4, 0, 1)
        elseif drop.Visible then drop.Visible = false end
    end, { f }
end
local function NcOpen(ctx)
    local f = ctx.Root and ctx.Root:FindFirstChild("NcOverlay")
    if not f then return end
    local t0 = os.clock()
    f:SetAttribute("NcPour", 0)
    local conn
    conn = game:GetService("RunService").RenderStepped:Connect(function()
        local k = math.clamp((os.clock() - t0) / 0.55, 0, 1)
        if not f.Parent then conn:Disconnect() return end
        f:SetAttribute("NcPour", k)
        if k >= 1 then conn:Disconnect() end
    end)
end
local function NcTitle(ctx)
    local bar, t = ctx.Title, ctx.Theme
    local line = Instance.new("Frame")
    line.Name = "NcTitleLine"; line.BorderSizePixel = 0; line.BackgroundColor3 = t.Honey; line.AnchorPoint = Vector2.new(0, 1)
    line.Position = UDim2.new(0, 10, 1, -3); line.Size = UDim2.new(0.24, 0, 0, 3); line.ZIndex = bar.ZIndex + 1; line.Parent = bar
    local ink = ctx.UIStyle.InkEdge(1); ink.Parent = line
    local drop = Instance.new("ImageLabel")
    drop.Name = "NcTitleDrop"; drop.BackgroundTransparency = 1; drop.Image = ART.nc_drop; drop.ImageColor3 = t.Honey; drop.AnchorPoint = Vector2.new(0.5, 0)
    drop.Size = UDim2.fromOffset(9, 13); drop.Position = UDim2.new(0.24, 4, 1, -3); drop.ZIndex = bar.ZIndex + 1; drop.Parent = bar
    return { line, drop }
end
-- numbers v3 (SKIN UI roll-out 2026-10-29, owner: numbers "unique to the skin and the colorways you have equipped"): RUNNING
-- HONEY. Soft rounded digits (FredokaOne) poured in this colourway's honey with a glossy highlight across their tops, that SAG
-- as they land (a short viscous stretch down) and rise slowly; a drop gathers under the digits on a short string, stretches
-- and falls (again on every merged hit). CRIT = a honey splash spreads behind the digits; WEAK SPOT = a ● drop leads them; a
-- KILL = the number runs: three drops fall away from it one after another. Every colour is this copy's palette (P =
-- Wildflower amber, Buckwheat deep amber, Lavender Honey lilac).
local function NcMotion(e, age, pa, life)
    local rise = 1 - (1 - math.min(1, math.max(0, age - 0.12) / 0.8)) ^ 3
    local sag = math.sin(math.min(1, pa / 0.24) * math.pi) * 6
    return 0.35 + rise * 1.3, 0, 1 + 0.06 * math.exp(-pa * 10), sag, 0, 0
end
local function NcAccent(e)
    local box = Instance.new("Frame")
    box.Name = "NcHoney"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 0
    local splat = Instance.new("ImageLabel")
    splat.Name = "Splash"; splat.BackgroundTransparency = 1; splat.Image = Tex("nc_splat", ""); splat.AnchorPoint = Vector2.new(0.5, 0.5)
    splat.Position = UDim2.fromScale(0.5, 0.5); splat.ScaleType = Enum.ScaleType.Fit; splat.ZIndex = 0; splat.Parent = box
    -- the gloss: the same digits in the highlight colour, faded out below their upper third
    local gloss = Instance.new("TextLabel")
    gloss.Name = "Gloss"; gloss.BackgroundTransparency = 1; gloss.Size = UDim2.fromScale(1, 1); gloss.ZIndex = 3; gloss.TextStrokeTransparency = 1
    gloss:SetAttribute("KeepFont", true); gloss:SetAttribute("NoSnap", true); gloss.Parent = box
    local g = Instance.new("UIGradient")
    g.Rotation = 90
    g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.14, 0.05), NumberSequenceKeypoint.new(0.36, 0.2),
        NumberSequenceKeypoint.new(0.47, 1), NumberSequenceKeypoint.new(1, 1) })
    g.Parent = gloss
    -- the string + drop under the digits, and three drops for a kill
    local str = Instance.new("Frame")
    str.Name = "String"; str.BorderSizePixel = 0; str.AnchorPoint = Vector2.new(0.5, 0); str.ZIndex = 1; str.Parent = box
    for i = 0, 3 do
        local d = Instance.new("Frame")
        d.Name = "Drop" .. i; d.BorderSizePixel = 0; d.AnchorPoint = Vector2.new(0.5, 0); d.ZIndex = 1
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = d
        local st = Instance.new("UIStroke"); st.Thickness = 1.5; st.Parent = d
        d.Parent = box
    end
    return box
end
local function NcDrop(d, x, y, w, h, col, edge, tr)
    d.Size = UDim2.fromOffset(w, h); d.Position = UDim2.new(0.5, math.floor(x), 0.5, math.floor(y))
    d.BackgroundColor3 = col; d.BackgroundTransparency = tr
    local st = d:FindFirstChildOfClass("UIStroke"); if st then st.Color = edge; st.Transparency = tr end
end
local function NcAccentStep(e, box, age, pa, alpha)
    local lbl = e.Label
    local tb = lbl.TextBounds
    local gloss = box:FindFirstChild("Gloss")
    if gloss then
        if gloss.Text ~= lbl.Text then gloss.Text = lbl.Text end
        gloss.FontFace = lbl.FontFace; gloss.TextSize = lbl.TextSize
        gloss.TextColor3 = P.Hot:Lerp(Color3.new(1, 1, 1), 0.35); gloss.TextTransparency = alpha
    end
    local col, edge = e.Color:Lerp(P.HoneyDeep, 0.25), P.Deep
    -- the drop gathers on a string under the digits (0.5 s), stretches and falls
    local k = pa / 0.55
    local x = tb.X * 0.16
    local str, d0 = box:FindFirstChild("String"), box:FindFirstChild("Drop0")
    if str and d0 then
        local on = k < 1 and not e.Dot
        str.Visible, d0.Visible = on, on
        if on then
            local form = smooth(k / 0.55)
            local fall = math.max(0, (k - 0.55) / 0.45)
            local y0 = tb.Y * 0.34
            local sl = 3 + 7 * form
            str.Size = UDim2.fromOffset(2, (fall > 0) and 0 or sl); str.Position = UDim2.new(0.5, math.floor(x), 0.5, math.floor(y0))
            str.BackgroundColor3 = col; str.BackgroundTransparency = alpha
            local s = 3 + 4 * form
            NcDrop(d0, x, y0 + sl - 2 + 30 * fall * fall, s, s + 2 * form, col, edge, math.clamp(alpha + fall * 0.85, 0, 1))
        end
    end
    -- kill: the number runs -- three drops fall away from its lower edge one after another
    local kt = (e.Killed and e.KillAt) and (os.clock() - e.KillAt) or -1
    for i = 1, 3 do
        local d = box:FindFirstChild("Drop" .. i)
        if d then
            local t = kt - (i - 1) * 0.12
            local on = kt >= 0 and t >= 0 and t < 0.6 and not e.Dot
            d.Visible = on
            if on then
                local u = t / 0.6
                NcDrop(d, (i - 2) * tb.X * 0.3, tb.Y * 0.3 + 50 * u * u, 5, 7, col, edge, math.clamp(alpha + u * 0.8, 0, 1))
            end
        end
    end
    -- crit: a honey splash spreads behind the digits
    local splat = box:FindFirstChild("Splash")
    if splat then
        local on = e.Crit and not e.Dot
        splat.Visible = on and true or false
        if on then
            local s = smooth(age / 0.14)
            local sz = math.floor((tb.X + 30) * (0.55 + 0.55 * s))
            splat.Size = UDim2.fromOffset(sz, math.floor(sz * 0.8)); splat.Rotation = e.Seed * 20
            splat.ImageColor3 = P.HoneyDeep; splat.ImageTransparency = math.clamp(alpha + 0.25, 0, 1)
        end
    end
end
-- ===== UI THEME v4 (SKIN UI THEMES roll-out 2026-10-29): the clean language in this colourway's wood + honey (UITheme Clean) +
-- the apiary's touches. Hooks read only the palette they are given (a colourway copy shares these functions):
--   TAB MARK  the underline is a glossy HONEY BAR with two short drips running off its underside (on the top bar they slowly
--             stretch and shrink)
--   FIELD     HONEY POOLS along the foot of the screen (a warm glow with a glossy surface line, bubbles rising slowly through it),
--             and in the left margin a drip hangs off the top bar, stretches, and every few seconds its drop lets go, falls into
--             the pool and sends a ripple along its surface
local NC_CLEAN = {
    Field = P.Dark:Lerp(P.Deep, 0.5), Surface = P.Plate:Lerp(P.Deep, 0.4), Raised = P.Deep:Lerp(P.Wood, 0.45), Hover = P.Wood:Lerp(P.Brass, 0.25),
    Well = P.Dark, Line = P.Wood:Lerp(P.Brass, 0.5), Tip = P.Plate,
    Accent = P.Lume, Mark = P.Amber, Hair = P.Wax,
    Text = P.Text, Sub = P.Text:Lerp(P.Wax, 0.35), Muted = P.Wax:Lerp(P.Text, 0.2), Ink = P.Dark,
    Honey = P.Lume, HoneyDeep = P.HoneyDeep, Gloss = P.Hot, Amber = P.Amber, InkLine = P.Dark,
}
-- (HudThemes.Variant keeps a colourway copy's Clean colour only when it DIFFERS from colourway 1's; one that is the same in
-- both palettes (the gold, a shared brass ...) went through the hue map instead -- Indigo's gold seam came out green. A
-- hair's difference keeps this copy's own colour.)
if VAR ~= 1 then for k, v in pairs(NC_CLEAN) do if typeof(v) == "Color3" then NC_CLEAN[k] = v:Lerp(Color3.new(0, 0, 0), 0.003) end end end
NC_CLEAN.TabMark = function(mark, Q)
    -- (children of a tab mark: offset-sized, inside the mark's width -- tab buttons are AutomaticSize X)
    local g = Instance.new("UIGradient")
    g.Name = "NcGloss"; g.Rotation = 90; g.Color = ColorSequence.new(Q.Gloss, Q.HoneyDeep)
    g.Parent = mark
    local made = { g }
    for i, d in ipairs({ { 0.27, 5 }, { 0.7, 8 } }) do
        local r = Instance.new("Frame")
        r.Name = "NcDrip" .. i; r.BorderSizePixel = 0; r.BackgroundColor3 = Q.Amber:Lerp(Q.HoneyDeep, 0.3); r.Position = UDim2.new(d[1], 0, 0, 0)
        r.Size = UDim2.fromOffset(3, d[2]); r.ZIndex = mark.ZIndex; r.Parent = mark
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = r
        r:SetAttribute("Len", d[2])
        table.insert(made, r)
    end
    return made
end
NC_CLEAN.Sig = function(ctx)
    local Q, f = ctx.P, ctx.Frame
    local made = {}
    -- the honey pools along the foot of the screen
    local PH = ctx.Phone and 30 or 46
    local pool = Instance.new("Frame")
    pool.Name = "NcPool"; pool.BorderSizePixel = 0; pool.BackgroundColor3 = Q.Amber; pool.AnchorPoint = Vector2.new(0, 1); pool.Position = UDim2.fromScale(0, 1)
    pool.Size = UDim2.new(1, 0, 0, PH); pool.BackgroundTransparency = 0; pool.ZIndex = 0; pool.Parent = f
    local pg = Instance.new("UIGradient")
    pg.Rotation = 90
    pg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, 0.82), NumberSequenceKeypoint.new(1, 0.7) })
    pg.Color = ColorSequence.new(Q.Honey, Q.HoneyDeep)
    pg.Parent = pool
    local surf = Instance.new("Frame")
    surf.Name = "NcSurface"; surf.BorderSizePixel = 0; surf.BackgroundColor3 = Q.Gloss; surf.Position = UDim2.new(0, 0, 0, math.floor(PH * 0.08))
    surf.Size = UDim2.new(1, 0, 0, 1); surf.BackgroundTransparency = 0.6; surf.ZIndex = 0; surf.Parent = pool
    local sg = Instance.new("UIGradient")
    sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.3, 0.1), NumberSequenceKeypoint.new(0.55, 0.7),
        NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 0.6) })
    sg.Parent = surf
    local bubbles = {}
    for i = 1, 6 do
        local b = Instance.new("Frame")
        b.Name = "Bubble"; b.BackgroundTransparency = 1; b.AnchorPoint = Vector2.new(0.5, 0.5); b.ZIndex = 0
        local s = 3 + (i % 3) * 2
        b.Size = UDim2.fromOffset(s, s)
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = b
        local st = Instance.new("UIStroke"); st.Color = Q.Gloss; st.Thickness = 1; st.Transparency = 0.5; st.Parent = b
        b.Parent = pool
        bubbles[i] = { F = b, St = st, X = (i - 0.5) / 6 + (((i * 37) % 10) - 5) / 100, T = i * 1.3, Sp = 5 + (i % 4) }
    end
    -- the drip in the left margin, hung off the top bar (it follows the bar), and its falling drop + the ripple
    local hang, strand, bulb, fallDrop, ripple
    if ctx.Top then
        hang = Instance.new("Frame")
        hang.Name = "NcHang"; hang.BackgroundTransparency = 1; hang.Position = UDim2.new(0, 9, 1, 0); hang.Size = UDim2.fromOffset(10, 40); hang.ZIndex = 0
        hang.Parent = ctx.Top
        strand = Instance.new("Frame")
        strand.Name = "Strand"; strand.BorderSizePixel = 0; strand.BackgroundColor3 = Q.Amber; strand.AnchorPoint = Vector2.new(0.5, 0)
        strand.Position = UDim2.fromScale(0.5, 0); strand.ZIndex = 0; strand.Parent = hang
        local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0.5, 0); sc.Parent = strand
        bulb = Instance.new("Frame")
        bulb.Name = "Bulb"; bulb.BorderSizePixel = 0; bulb.BackgroundColor3 = Q.Amber; bulb.AnchorPoint = Vector2.new(0.5, 0); bulb.ZIndex = 0
        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0.5, 0); bc.Parent = bulb
        local bs = Instance.new("UIStroke"); bs.Color = Q.InkLine; bs.Thickness = 1; bs.Transparency = 0.4; bs.Parent = bulb
        bulb.Parent = hang
        table.insert(made, hang)
    end
    fallDrop = Instance.new("Frame")
    fallDrop.Name = "NcFall"; fallDrop.BorderSizePixel = 0; fallDrop.BackgroundColor3 = Q.Amber; fallDrop.AnchorPoint = Vector2.new(0.5, 0)
    fallDrop.Size = UDim2.fromOffset(6, 8); fallDrop.Visible = false; fallDrop.ZIndex = 0; fallDrop.Parent = f
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0.5, 0); fc.Parent = fallDrop
    ripple = Instance.new("Frame")
    ripple.Name = "NcRipple"; ripple.BackgroundTransparency = 1; ripple.AnchorPoint = Vector2.new(0.5, 0.5); ripple.ZIndex = 0; ripple.Visible = false
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0.5, 0); rc.Parent = ripple
    local rs = Instance.new("UIStroke"); rs.Color = Q.Gloss; rs.Thickness = 1; rs.Parent = ripple
    ripple.Parent = pool
    local CYCLE, ph = 7, math.random() * 3
    return function(now, _dt)
        for _, b in ipairs(bubbles) do
            local u = ((now + b.T) % b.Sp) / b.Sp
            b.F.Position = UDim2.new(b.X, 0, 1 - u * 0.85, 0)
            b.St.Transparency = 0.35 + 0.6 * u
        end
        -- the drip: it stretches over the cycle, then the drop lets go and falls into the pool
        local t = (now + ph) % CYCLE
        local stretch = smooth(t / (CYCLE - 1.2))
        if strand and bulb then
            local L = 4 + 18 * stretch
            if t > CYCLE - 1.2 then L = 4 end
            strand.Size = UDim2.fromOffset(3, L)
            local s = 5 + 3 * stretch
            bulb.Size = UDim2.fromOffset(s, s + 2); bulb.Position = UDim2.new(0.5, 0, 0, L - 3)
            bulb.Visible = t <= CYCLE - 1.2
        end
        local ft = t - (CYCLE - 1.2)
        if ft >= 0 and hang then
            local y0 = hang.AbsolutePosition.Y - f.AbsolutePosition.Y + 22
            local fy = f.AbsoluteSize.Y - PH * 0.92
            local k = math.min(1, ft / 0.7)
            fallDrop.Visible = k < 1
            fallDrop.Position = UDim2.fromOffset(hang.AbsolutePosition.X - f.AbsolutePosition.X + 5, y0 + (fy - y0) * k * k)
            -- the ripple on the pool's surface where it lands
            local rk = (ft - 0.7) / 0.6
            ripple.Visible = rk >= 0 and rk < 1
            if ripple.Visible then
                ripple.Position = UDim2.new(0, hang.AbsolutePosition.X - f.AbsolutePosition.X + 5, 0, math.floor(PH * 0.08))
                ripple.Size = UDim2.fromOffset(8 + 50 * rk, 3 + 6 * rk)
                rs.Transparency = 0.2 + 0.8 * rk
            end
        else
            fallDrop.Visible = false; ripple.Visible = false
        end
        -- the drips on the selected tab's honey bar stretch and shrink slowly
        for _, m in ipairs(ctx.Marks()) do
            if m.Visible then
                for i = 1, 2 do
                    local r = m:FindFirstChild("NcDrip" .. i)
                    if r then r.Size = UDim2.fromOffset(3, math.floor((r:GetAttribute("Len") or 6) * (0.75 + 0.35 * math.sin(now * 0.9 + i * 1.7)))) end
                end
            end
        end
    end, made
end
local P1 = PALETTES[1]
local function PG(top, bottom) return { Top = top, Bottom = bottom } end
Set.Theme = { Name = "Nectar", Desc = "Every menu in your colourway's honey and wood: honey pools along the foot of the screen with bubbles rising through it, a drip hangs off the top and lets a drop fall into the pool now and then, and every tab is underlined with a glossy honey bar that drips.",
    Panel = PG(C(50, 28, 8), C(18, 10, 2)), Card = PG(C(66, 38, 12), C(28, 16, 4)), Title = PG(C(200, 130, 30), C(90, 50, 8)),
    Accent = C(255, 165, 30), Accent2 = C(255, 226, 150), HpFill = C(255, 165, 30), HpBg = C(30, 16, 6), XpFill = C(255, 200, 90), Text = C(255, 235, 200),
    Honey = P1.Lume, HoneyDeep = P1.HoneyDeep, BrassFace = P1.Brass:Lerp(C(255, 230, 170), 0.35), BrassShade = P1.Brass, Ink = C(26, 12, 2),
    Emblem = "EmblemNectar", BorderThick = 2,
    Deco = NcDeco, OpenFn = NcOpen, TitleDeco = NcTitle,
    Clean = NC_CLEAN, -- (SKIN UI THEMES: the clean wood + honey palette + dripping honey tab marks + the honey pool and drip; the old art is not drawn)
    -- (SKIN UI 2026-10-29: running honey -- glossy honey digits that sag, a drop falls; crit = a splash, kill = the number runs)
    Numbers = { Font = "FredokaOne", Glyph = "●", NoBang = true, Motion = NcMotion, Accent = NcAccent, AccentStep = NcAccentStep,
        Normal = P.Text:Lerp(P.Lume, 0.3), Crit = P.Lume, Weak = P.Hot, Stroke = P.Deep, StrokeThick = 2, Size = 1.05 } }

-- ===== bundle / kill effect / store hero =====
Set.KillEffect = { Id = "GoldenHour", Name = "Golden Hour", Image = Tex("nc_emblem", ""),
    How = "Own any Nectar skin (or the Nectar bundle)",
    Desc = "The enemy is glazed and melted: a brass-banded honey jar tips over above it and pours a thick glowing stream, the honey coats the body from the top down, then the whole glazed body slumps into a wide glossy puddle that sets darker and sinks away. With the honey banner that fills one drop per kill." }
Set.Bundle = { Id = "NectarBundle", Name = "Nectar Bundle", Price = 2199, BP = 799, ProductId = 0,
    Desc = "The whole Nectar set: the Nectar Uzi, Galil and SKS, the Honey Dipper, Apiary Gloves + Waxed Field Sleeves, the Nectar health bar, the Nectar UI theme and the Golden Hour kill effect.",
    Contents = { "WeaponSkin:NectarUZI", "WeaponSkin:NectarGALIL", "WeaponSkin:NectarSKS", "MeleeSkin:Nectar", "Glove:BeekeeperGloves", "Sleeve:KnitSleeves",
        "HealthBar:Nectar", "KillEffect:GoldenHour" } }
Set.Hero = { Grad = { C(110, 64, 14), C(24, 12, 2) }, Stroke = LUME, Emblem = Tex("nc_emblem", ""), Name = C(255, 235, 200), Chip = C(120, 70, 14) }

return Set
