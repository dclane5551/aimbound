--!nocheck
-- ===================================================================================================================
-- SILKFANG (Skins V3, bundle 13 of docs/SKINS_V3_PLAN.md; SKINS BUILDER 11 "skins11"): TEC-9 + EMR + Void Rifle | Fang
-- Karambit | 1,199 BP. A spider's lair, dark and gothic-sleek: glossy widow-black LACQUER engraved with a fine silver orb
-- web, raised silver web inlays, deep plum settings, ONE venom-crimson HOURGLASS on the camera side that beats slowly,
-- pale SILK THREADS strung across the open frames (the EMR's skeleton stock, the TEC-9's shroud, the Void Rifle's cocoon)
-- with a DEWDROP that slides along one of them now and then, and two gunmetal FANG spurs under every muzzle. The guns are
-- RESCULPTED models (WeaponAssets.SkinModels.Silkfang_<GUN>, tools/skins_v3/silkfang_build.py in
-- art/weapons/SkinsV3_Silkfang.blend, painted by tools/skin_v3_paint.py with tools/skins_v3/silkfang.json); this module
-- brings their motion, effects, sounds and the rest of the bundle.
--   ALIVE    the hourglass beats (a slow double beat, quicker with the streak); a glint runs along the threads every ~4 s; the
--            dewdrop slides down its thread every ~5 s; the Void Rifle's cocoon core breathes
--   EQUIP    the threads are SPUN one by one across the frame (a reel hiss), then the hourglass lights
--   INSPECT  the threads glint in a fast sequence on the Present beat, the fang spurs FLEX out and back on the Tilt / Flip
--   RELOAD   a silk thread clings to the dropping magazine, stretches and snaps
-- Muzzle: a small dark-red flash + a thin silver web ring opening. Tracer: a silk strand that hangs in the air, sags and
-- drifts away. Impact: a small radial web splat + dust. Kill COCOONED: silk threads shoot up out of the ground and wind round
-- the body into a cocoon, which is hoisted up out of view on a single thread. Banner: an hourglass plate at the lower right;
-- each kill spins one segment of the web ring round it. Original (plan "Originality"): no thorns / roses, no violet inlay
-- or bat-wing flourishes, no baroque claws, no spider figure anywhere on the gun (the hourglass is a mark, not a creature).
-- v2 (2026-10-11 evening, owner: v1 "flat and cheap ... lacking any sort of uniqueness ... the material isnt the
-- greatest"): CREATURE-MADE. Glossy CHITIN plates (violet iridescent rims, overlapping lips, a keel), matte plum SILK
-- bindings, dark brushed silver only on joints. TEC-9 = a LEG CAGE (two articulated legs a side clasp the barrel: they
-- open on the draw and clench, flex on the inspect, tick per shot); EMR = FANG JAWS (two hinged chelicerae out of the
-- handguard nose with venom beads: open on the draw / inspect, snap per shot) + a silk-COCOON stock; VOID RIFLE = EGG SACS
-- (translucent silk sacs on both flanks packed with crimson eggs that pulse faster as you fire); FANG KARAMBIT = a real
-- fang out of a chelicera base, a venom drop forming at its tip.
-- ===================================================================================================================
local Set = { Kind = "Silkfang" }

-- COLOURWAYS: each colourway is a whole palette -- the module copy SkinFX loads for colourway v has attribute Colorway = v.
-- The painted model maps are separate SurfaceAppearances (SkinFX.V3Swap); Colorways.Sets.Silkfang lists the names.
local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local V = Vector3.new
local PALETTES = {
    { Name = "Widow", Body = C(30, 27, 52), Mid = C(104, 108, 122), Plum = C(53, 33, 69), Lume = C(255, 30, 60), Silk = C(210, 212, 228),
      Hot = C(255, 150, 160), Deep = C(90, 6, 20), Text = C(240, 225, 235), Plate = C(16, 8, 14), Ink = C(4, 2, 4) },
    { Name = "Recluse", Body = C(47, 32, 21), Mid = C(118, 90, 55), Plum = C(70, 42, 24), Lume = C(255, 160, 60), Silk = C(235, 212, 172),
      Hot = C(255, 214, 160), Deep = C(100, 50, 10), Text = C(250, 232, 210), Plate = C(24, 14, 8), Ink = C(6, 4, 2) },
    { Name = "Ghost Silk", Body = C(36, 42, 54), Mid = C(135, 138, 150), Plum = C(60, 69, 89), Lume = C(170, 220, 255), Silk = C(225, 235, 250),
      Hot = C(230, 246, 255), Deep = C(40, 70, 100), Text = C(232, 240, 250), Plate = C(14, 16, 22), Ink = C(4, 4, 6) },
    { Name = "Jewel Spider", Body = C(11, 39, 44), Mid = C(135, 106, 44), Plum = C(71, 20, 61), Lume = C(255, 60, 200), Silk = C(232, 222, 160),
      Hot = C(255, 170, 230), Deep = C(90, 10, 70), Text = C(236, 246, 240), Plate = C(6, 18, 20), Ink = C(2, 6, 6) },
}
local P = PALETTES[VAR] or PALETTES[1]
local BODY, MID, PLUM, LUME, SILK, HOT, DEEP = P.Body, P.Mid, P.Plum, P.Lume, P.Silk, P.Hot, P.Deep
Set.Palettes = PALETTES
Set.Colors = { Glow = LUME, Hot = HOT, Body = BODY, Accent = SILK, Mid = MID }
-- art (tools/make_silkfang_art.py, uploaded as decals; these are the IMAGE ids, resolved in Studio). "" = not resolved: every
-- user has a fallback.
local A = "rbxassetid://"
Set.Art = {
    EmblemSilkfang = A .. "91386171027573", sf_emblem = A .. "91386171027573", sf_emblem_mask = A .. "119764196039072", sf_hour = A .. "131708337945601",
    sf_seg = A .. "71864260200668", sf_web = A .. "104738461880716", sf_silk = A .. "90054416775558", sf_corner = A .. "79881206755386",
    tex_sf_web = A .. "101327371163757", tex_sf_bar = A .. "77444687385456", SpThread = A .. "128647180194557",
}
local ART = Set.Art
local function Tex(key: string, fallback: string): string
    local t = ART[key]
    return (t and t ~= "") and t or fallback
end

local TAU = math.pi * 2
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function pulse(t, w) return math.exp(-(t / w) ^ 2) end

-- how many silk threads each sculpt carries (Thread1..N, Neon parts with CountDrive "Threads" + GlowDrive "Th<i>")
local THREADS = { TEC9 = 1, EMR = 5, VoidDisintegrator = 6 }

local function GunDesc(gun: string): string
    local what = (gun == "TEC9") and "Two articulated legs a side grow out of the receiver and clasp the barrel -- they open when you draw it and clench, flex when you inspect it, and tick with every shot; the magazine is bound in plum silk"
        or (gun == "EMR") and "Two great fangs jut from the handguard beside the barrel, venom beading at their tips -- they gape when you draw it, snap with every shot and open wide on the inspect; the stock is wound into a cocoon of plum silk"
        or "Two translucent silk egg sacs swell from its flanks, packed with crimson eggs that pulse faster the longer you fire; the void chamber is a silk cocoon round a crimson core"
    return "Built from a spider's own anatomy: glossy violet-black chitin plates with dark-silver joints and a crimson hourglass heart that beats on the side. " .. what .. ". The magazine leaves on a clinging thread, tracers hang like silk, and every kill is COCOONED."
end

-- ===== the guns =====
Set.GunSkins = {
    { Id = "SilkfangTEC9", Name = "Silkfang TEC-9", Gun = "TEC9", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("TEC9"),
      Model = "Silkfang_TEC9", V3 = true, Color = LUME, Color2 = SILK, Deco = "SilkfangGun", Fit = { G = "TEC9" } },
    { Id = "SilkfangEMR", Name = "Silkfang M14", Gun = "EMR", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("EMR"),
      Model = "Silkfang_EMR", V3 = true, Color = LUME, Color2 = SILK, Deco = "SilkfangGun", Fit = { G = "EMR" } },
    { Id = "SilkfangVoidDisintegrator", Name = "Silkfang Void Rifle", Gun = "VoidDisintegrator", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = GunDesc("VoidDisintegrator"), Model = "Silkfang_VoidDisintegrator", V3 = true, Color = LUME, Color2 = SILK, BeamColor = LUME,
      Deco = "SilkfangGun", Fit = { G = "VoidDisintegrator" } },
}
-- the clear SILK of the Void Rifle's egg sacs takes the colourway's silk tint (the import makes clear parts a neutral blue)
Set.Build = {}
Set.Build.SilkfangGun = function(model: Model, frame: BasePart, f: any, forView: boolean, H: any)
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p.Name == "Sac" then p.Color = SILK:Lerp(PLUM, 0.45) end
    end
end

-- ===== sounds (tools/skins_v3/silkfang_sfx.py: each gun's own recorded shot + a dry snap body + a faint low skitter; every
-- moment from CC0 recordings -- a fishing reel running, a fabric strip pulled off, a crab's legs on its shell, a stick drawn
-- through a spider web; tools/sound_sources.json) =====
Set.Sounds = {
    Fire = { Id = 0, Volume = 0 }, Equip = { Id = 71636054579241, Volume = 0.4 }, MagOut = { Id = 80559429394030, Volume = 0.36 },
    MagIn = { Id = 139040121966332, Volume = 0.4 }, Kill = { Id = 105308159332750, Volume = 0.5 }, Impact = { Id = 121104790287253, Volume = 0.2 },
    Swing = { Id = 116577954838166, Volume = 0.38 }, MeleeHit = { Id = 78486699185596, Volume = 0.42 }, Snap = { Id = 88654308561078, Volume = 0.3 },
    Spin = { Id = 125925570047356, Volume = 0.28 },
    -- (each gun's own full shot, levelled 0.5 dB under the plain shot's loudest 50 ms: volumes = the base guns' (TEC-9 0.7,
    -- EMR 0.95, beam 0.65) x the measured RMS difference (-0.2 / -0.2 / -1.7 dB))
    FireGun = { TEC9 = { Id = 112173818864318, Volume = 0.72 }, EMR = { Id = 112605537397790, Volume = 0.97 },
        VoidDisintegrator = { Id = 74682199990765, Volume = 0.79 } },
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
-- st: Heart (hourglass), Threads (how many threads are spun, CountDrive), Th<i> (each thread's glint), Dew (0 -> 1 along
-- its thread), DewGlint, Legs (TEC-9 leg cage: 1 = open, < 0 = clenched), Jaw (EMR fangs: 1 = gaping), Venom (the jaw
-- beads), Eggs (Void egg glow), Core (the cocoon core)
-- v = rig.SkinVars / rec.Vars: Phase, DewPhase, GlintT (a fast glint run), FlexT (spur flex)
local DEW_PERIOD = 5.2
local function Keys(st: any, v: any, now: number, gun: string?, anim: string?, animT: number?)
    local se = st.SinceEquip or 99
    local ss = st.SinceShot or 99
    local streak = math.min(st.Streak or 0, 5)
    local n = THREADS[gun or ""] or 6
    -- the hourglass: a slow double beat (ba-dum) every 1.6 s -> 1.0 s with the streak; it lights only once the threads are
    -- spun on the draw; a shot flares it a little
    local per = 1.6 - 0.12 * streak
    local t = (now + (v.Phase or 0)) % per
    local beat = math.exp(-((t - 0.06) / 0.06) ^ 2) + 0.7 * math.exp(-((t - 0.3) / 0.07) ^ 2)
    local heart = 0.35 + 0.06 * streak + 0.5 * beat + 0.3 * pulse(ss, 0.12)
    -- the draw: the threads are SPUN one by one over 0.15 .. 0.75 s, then the hourglass lights (0.8 .. 1.0 s)
    local spun = n
    if se < 0.8 then spun = math.floor(math.clamp((se - 0.15) / 0.6, 0, 1) * n + 0.0001) end
    st.Threads = spun
    if se < 1.0 then heart = heart * smooth((se - 0.78) / 0.2) end
    st.Heart = math.clamp(heart, 0, 1)
    -- the glint: a soft light running along the threads every ~4 s (one after the other); a FAST run on the inspect's Present
    local gk = (now + (v.Phase or 0)) % 4.2
    local gt = v.GlintT and (now - v.GlintT) or 99
    for i = 1, 6 do
        local g = 0.18 + 0.04 * streak + 0.75 * pulse(gk - 0.25 * i, 0.14)
        if gt < 1.2 then g = math.max(g, pulse(gt - 0.09 * i, 0.07)) end
        if se < 0.8 and i == spun then g = 1 end -- (the thread being spun shines)
        st["Th" .. i] = math.clamp(g, 0, 1)
    end
    -- the dewdrop: slides down its thread for 1.4 s every DEW_PERIOD s, glinting as it goes; hidden while it "re-forms"
    local dt_ = (now + (v.DewPhase or 0)) % DEW_PERIOD
    local slide = smooth(dt_ / 1.4)
    st.Dew = (dt_ < 1.4) and slide or 0
    st.DewGlint = (dt_ < 1.4) and (0.45 + 0.55 * math.sin(slide * math.pi)) or (dt_ > DEW_PERIOD - 0.6 and smooth((dt_ - (DEW_PERIOD - 0.6)) / 0.6) * 0.5 or 0)
    local ft = v.FlexT and (now - v.FlexT) or 99
    -- the TEC-9's LEGS: open on the draw (0 -> 1 by 0.3 s), clench past closed (0.55 s), settle (0.9 s); flex open and
    -- grip again on the inspect; a little clench per shot; a slow breath at rest
    local legs = 0.03 * math.sin(now * 1.3 + (v.Phase or 0))
    if se < 0.9 then
        legs = (se < 0.3) and smooth(se / 0.3) or ((se < 0.55) and (1 - 1.18 * smooth((se - 0.3) / 0.25)) or (-0.18 * (1 - smooth((se - 0.55) / 0.35))))
    end
    if ft < 1.1 then legs = math.max(legs, math.sin(math.clamp(ft / 1.1, 0, 1) * math.pi) * 0.85) end
    st.Legs = legs - 0.12 * pulse(ss, 0.05)
    -- the EMR's JAWS: gape on the draw and snap shut, open wide on the inspect, snap a little with every shot, twitch now
    -- and then at rest
    local jaw = 0
    if se < 0.8 then jaw = (se < 0.35) and smooth(se / 0.35) or (1 - smooth((se - 0.35) / 0.2)) end
    if ft < 1.3 then jaw = math.max(jaw, math.sin(math.clamp(ft / 1.3, 0, 1) * math.pi)) end
    v.NextTw = v.NextTw or (now + 3 + math.random() * 4)
    if now >= v.NextTw then v.TwT = now; v.NextTw = now + 4 + math.random() * 5 end
    local tw = v.TwT and (now - v.TwT) or 99
    st.Jaw = math.max(jaw, 0.4 * pulse(ss - 0.03, 0.05), 0.22 * math.sin(math.clamp(tw / 0.35, 0, 1) * math.pi))
    st.Venom = math.clamp(0.48 + 0.15 * math.sin(now * 1.6) + 0.45 * pulse(ss, 0.08), 0, 1)
    -- the Void Rifle's EGGS: a slow pulse at rest, faster and brighter the longer you fire (EggHeat), dim through a reload
    if ss < 0.06 and ss < (v.LastSS or 99) - 1e-4 then v.EggHeat = math.min(1, (v.EggHeat or 0) + 0.12) end
    v.LastSS = ss
    v.EggHeat = math.max(0, (v.EggHeat or 0) - 0.02)
    local eh = v.EggHeat or 0
    v.EggPh = ((v.EggPh or 0) + 0.016 * (1.4 + 7 * eh)) % TAU
    local eggs = 0.37 + 0.23 * eh + (0.18 + 0.23 * eh) * (0.5 + 0.5 * math.sin(v.EggPh))
    if (st.Reload or 0) > 0.1 and (st.Reload or 0) < 0.85 then eggs = eggs * 0.3 end
    st.Eggs = math.clamp(eggs, 0, 1)
    -- the cocoon core (Void Rifle): breathes, brighter with the streak and each shot
    st.Core = math.clamp(0.42 + 0.15 * math.sin(now * TAU / 3.4) + 0.07 * streak + 0.35 * pulse(ss, 0.1), 0, 1)
end
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    local v = rig.SkinVars
    if rig.Def and rig.Def.IsMelee then
        -- the Fang Karambit: the venom groove breathes; a hit / the inspect's Flip makes it flare
        local gt = v.VenomT and (now - v.VenomT) or 99
        st.Venom = math.clamp(0.47 + 0.12 * math.sin(now * TAU / 2.6) + 0.5 * pulse(gt, 0.25), 0, 1)
        -- the venom DROP at the tip: gathers over ~5 s and falls (a 7 s cycle); the inspect's Flip makes one form at once
        local cyc = (now + (v.DripPh or 0)) % 7
        if v.DripT and now - v.DripT < 1.6 then cyc = 3.6 + (now - v.DripT) * 2.2 end
        st.Drip = (cyc < 6.6) and smooth((cyc - 1.0) / 5.0) or 0
        return
    end
    local gun = rig.GunId
    Keys(st, v, now, gun, rig.AnimName, rig.AnimTime)
    -- the reload thread snaps: one sound per reload
    local rl = st.Reload or 0
    if rl > 0.45 and (v.LastRl or 0) <= 0.45 then PlaySound(H, Set.Sounds.Snap, 0.95 + 0.1 * math.random()) end
    v.LastRl = rl
end
local function GunPartPos(rig: any, name: string): Vector3?
    local gp = rig.GunParts and rig.GunParts[name]
    return gp and gp.Part and gp.Part.Position or nil
end
-- a silk thread clinging to the dropping magazine (every gun): a thin Beam from the mag well to the leaving magazine that
-- stretches, sags, and snaps (thinning to nothing)
local function SilkString(H: any, rig: any)
    local gp = rig.GunParts and rig.GunParts.Magazine
    if not gp or not gp.Part or not rig.Gun then return end
    local frame = rig.Gun:FindFirstChild("Frame")
    if not frame then return end
    local a0 = Instance.new("Attachment"); a0.Parent = frame
    a0.WorldPosition = gp.Part.Position + gp.Part.CFrame.UpVector * gp.Part.Size.Y * 0.45
    local a1 = Instance.new("Attachment"); a1.Parent = gp.Part
    local b = Instance.new("Beam")
    b.Attachment0, b.Attachment1 = a0, a1
    b.Color = ColorSequence.new(SILK, HOT); b.LightEmission = 0.6; b.LightInfluence = 0.2; b.FaceCamera = true; b.Segments = 8
    b.Width0, b.Width1 = 0.006, 0.004
    b.Transparency = NumberSequence.new(0.2)
    b.Parent = frame
    H.Animate(0.5, function(t)
        local k = t / 0.5
        local sag = 0.06 * math.sin(math.min(1, k * 1.4) * math.pi)
        b.CurveSize0, b.CurveSize1 = -sag, sag
        local snap = smooth((k - 0.72) / 0.12)
        b.Width0, b.Width1 = 0.006 * (1 - snap), 0.004 * (1 - snap)
        b.Transparency = NumberSequence.new(0.2 + 0.8 * snap)
    end, function() b:Destroy(); a0:Destroy(); a1:Destroy() end)
end
Set.OnEvent = function(rig: any, name: string, H: any, data: any)
    local v = rig.SkinVars
    if not v then return end
    if rig.Def and rig.Def.IsMelee then
        if name == "Flip" or name == "Raise" then v.VenomT = os.clock() end
        if name == "Flip" then v.DripT = os.clock() end
        return
    end
    if name == "MagOut" then
        SilkString(H, rig)
    elseif name == "Present" then
        v.GlintT = os.clock()
        PlaySound(H, Set.Sounds.Spin, 1.05)
    elseif name == "Tilt" or name == "Flip" or name == "Rack" then
        v.FlexT = os.clock()
    end
end
Set.OnAnim = function(rig: any, name: string)
    if rig.Def and rig.Def.IsMelee and (name:find("Light") or name:find("Heavy") or name:find("Quick")) then rig.SkinVars.VenomT = os.clock() end
end
Set.OnEquip = function(rig: any, H: any)
    local v = rig.SkinVars
    if v then
        v.Phase = math.random() * 4
        v.DewPhase = math.random() * DEW_PERIOD
        v.GlintT, v.FlexT = nil, nil
        if not (rig.Def and rig.Def.IsMelee) then PlaySound(H, Set.Sounds.Equip, 1) end
    end
    if not Set._Preloaded then
        Set._Preloaded = true
        task.spawn(function()
            local list = {}
            for _, k in ipairs({ "sf_hour", "sf_seg", "sf_web", "sf_silk", "EmblemSilkfang", "tex_sf_bar" }) do
                if ART[k] ~= "" then table.insert(list, ART[k]) end
            end
            pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
        end)
    end
end
-- other players' guns: the beating hourglass, the glint, the dewdrop, the cocoon core
Set.World = function(rec: any, now: number, st: any)
    local v = rec.Vars
    v.Phase = v.Phase or math.random() * 4
    v.DewPhase = v.DewPhase or math.random() * DEW_PERIOD
    st.SinceShot = 99; st.SinceEquip = 99; st.Reload = 0; st.Streak = 1
    Keys(st, v, now, nil, nil, nil)
end

-- ===== muzzle: a small dark-red flash + a thin silver web ring opening =====
Set.Muzzle = function(rig: any, flash: ParticleEmitter, light: PointLight, muzzle: Attachment, H: any)
    flash.Color = ColorSequence.new(HOT, DEEP)
    flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.11), NumberSequenceKeypoint.new(1, 0.02) })
    light.Color = LUME
    light.Brightness = 0.45
    rig.Fx.SfRing = H.Emitter(muzzle, { Name = "SfRing", Texture = Tex("sf_web", H.SPARK), Color = ColorSequence.new(SILK, MID),
        Size = { 0.05, 0.3 }, Life = { 0.12, 0.14 }, Speed = { 1.5, 2.2 }, Trans = { 0.35, 1 }, Light = 0.8,
        Orient = Enum.ParticleOrientation.VelocityPerpendicular, Dir = Enum.NormalId.Right, Spread = 0, Rot = { 0, 360 } })
end
Set.OnFire = function(rig: any, H: any)
    if rig.Fx and rig.Fx.SfRing then rig.Fx.SfRing:Emit(1) end
end

-- ===== SILK tracer: a fine silver-white strand that reaches the hit, hangs in the air ~0.3 s, sags, then drifts away =====
Set.Tracer = function(H: any, from: Vector3, to: Vector3, peer: boolean?)
    local dist = (to - from).Magnitude
    if dist < 1.5 then return end
    local dir = (to - from).Unit
    local host = H.FxPart({ Transparency = 1, Size = V(0.05, 0.05, 0.05), CFrame = CFrame.new(from) })
    local a0, a1 = H.Att(host, from), H.Att(host, to)
    local b = Instance.new("Beam")
    b.Attachment0, b.Attachment1 = a0, a1
    b.Texture = Tex("sf_silk", ""); b.TextureMode = Enum.TextureMode.Stretch
    b.Color = ColorSequence.new(SILK, HOT:Lerp(SILK, 0.5)); b.LightEmission = 0.7; b.LightInfluence = 0.15; b.FaceCamera = true; b.Segments = 10
    b.Width0, b.Width1 = 0.01, peer and 0.022 or 0.03
    b.Parent = host
    local travel = H.TRAVEL -- (hitscan: the shot is there at once, nothing flies)
    local hang = 0.3
    local dur = travel + hang + 0.25
    local drift = V(0, 1, 0):Cross(dir)
    drift = (drift.Magnitude > 0.05 and drift.Unit or V(1, 0, 0)) * 0.5
    H.Animate(dur, function(t)
        local hk = math.clamp(t / travel, 0, 1)
        local after = math.max(0, t - travel)
        local sagK = smooth(after / hang)
        local away = smooth((after - hang) / 0.25)
        a0.WorldPosition = from + drift * away * 0.4
        a1.WorldPosition = from + dir * dist * hk + drift * away + V(0, -0.15 * away, 0)
        -- (the strand sags under its own weight once it has landed)
        local sag = math.min(dist * 0.03, 0.6) * sagK
        b.CurveSize0, b.CurveSize1 = -sag, sag
        b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, math.clamp(0.65 + 0.35 * away, 0, 1)),
            NumberSequenceKeypoint.new(1, math.clamp(0.15 + 0.85 * away, 0, 1)) })
    end, function() host:Destroy() end)
end

-- ===== WEB impact: a small radial web splat stamped on the surface (it opens, then fades) + a puff of dust =====
Set.Impact = function(H: any, pos: Vector3, normal: Vector3?, peer: boolean?)
    if not H.Budget("SilkfangImpact", peer and 3 or 8, 0.5) then return end
    local n = (normal and normal.Magnitude > 0.1) and normal.Unit or V(0, 1, 0)
    local face = CFrame.lookAt(pos + n * 0.02, pos + n * 2) * CFrame.Angles(0, 0, math.random() * TAU)
    local p = H.FxPart({ Transparency = 1, Size = V(0.1, 0.1, 0.02), CFrame = face })
    local web = Instance.new("Decal")
    web.Texture = Tex("sf_web", ""); web.Face = Enum.NormalId.Front; web.Color3 = SILK; web.Transparency = 0.2
    web.Parent = p
    local att = H.Att(p, pos + n * 0.03)
    local em = H.Emitter(att, { Name = "SfDust", Texture = H.SMOKE, Color = { C(120, 116, 122), C(70, 66, 72) }, Size = { 0.08, 0.2 }, Life = { 0.25, 0.45 },
        Speed = { 0.6, 1.4 }, Spread = 50, Trans = { 0.55, 1 }, Light = 0, Drag = 3 })
    em.EmissionDirection = Enum.NormalId.Front
    em:Emit(peer and 2 or 4)
    H.Animate(0.7, function(t)
        local k = t / 0.7
        local o = 1 - (1 - math.min(1, k * 4)) ^ 3
        local s = 0.12 + 0.3 * o
        p.Size = V(s, s, 0.02)
        web.Transparency = math.clamp(0.2 + 0.8 * smooth((k - 0.35) / 0.65), 0, 1)
    end, function() p:Destroy() end)
end

-- ===== PULLED UNDER kill (v3, owner 2026-10-14 on v2 "not great ... Fission or Ferroflux are the ideal": the BODY itself
-- must transform into a big finish anchored on the real floor). ONE idea: the enemy is caught in a web and pulled under.
-- 1) WEB (0 -> 0.2): a silver web spins out across the real floor (~7 studs, on a dark ink disc) and five anchor lines
-- shoot from its rim up to the body; 2) DRAGGED DOWN (0.12 -> 0.55): the body is hauled down into the web's centre -- every
-- part slides in and down, squashes and is wrapped white; 3) COCOONED (0.5 -> 0.85): it lies on the web as a fat silk
-- cocoon, a crimson wrap winding round it, the hourglass glowing at the web's heart, the cocoon twitches twice; 4) PULLED
-- UNDER (0.9 -> 1.4): the cocoon sinks through the floor, the web is drawn in after it and a crimson ring snaps out once.
-- All motion is DOWN; the body leaves the crosshair by ~0.4 s. Budget: full = ink + web card + ring + cocoon + host +
-- <= 8 body parts = 13 parts, 6 Beams (5 lines + wrap), 8 silk tufts; low: ink + web card + cocoon + host + 3 body parts,
-- 3 lines, no wrap. =====
local function SfBits(pos: Vector3, H: any): { BasePart }
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
    local out = {}
    if best then
        for _, p in ipairs(best:GetDescendants()) do
            if p:IsA("BasePart") and p.Transparency < 0.6 and p.Size.Magnitude < 12 then table.insert(out, p) end
        end
        table.sort(out, function(a, b) return a.Size.Magnitude > b.Size.Magnitude end)
    end
    return out
end
Set.Kill = function(H: any, pos: Vector3, low: boolean)
    local model = Instance.new("Model")
    model.Name = "SilkfangKill"
    model.Parent = H.FxFolder()
    local ground = H.Ground(pos)
    local axis = V(pos.X, ground.Y, pos.Z)
    local cam = workspace.CurrentCamera
    local rt = cam and cam.CFrame.RightVector or Vector3.xAxis
    rt = V(rt.X, 0, rt.Z)
    rt = (rt.Magnitude > 0.05) and rt.Unit or Vector3.xAxis
    local RW = 3.6 -- (web radius)
    -- the floor: an opaque ink disc with the web card on it (the set's web art, silver), a crimson ring for the snap
    local ink = H.FxPart({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Size = V(0.04, 0.2, 0.2), Color = P.Plate,
        Transparency = 1, CFrame = CFrame.new(axis + V(0, 0.03, 0)) * H.ANG(0, 0, H.R(90)) }, model)
    local card = H.FxPart({ Transparency = 1, Size = V(0.2, 0.02, 0.2), CFrame = CFrame.new(axis + V(0, 0.07, 0)) }, model)
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Top; sg.LightInfluence = 0; sg.AlwaysOnTop = false; sg.CanvasSize = Vector2.new(400, 400); sg.Parent = card
    local web = H.New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("sf_web", Tex("tex_sf_web", "")), ImageColor3 = SILK, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ImageTransparency = 1 }, sg)
    local heart = H.New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("sf_hour", Tex("sf_emblem", "")), ImageColor3 = LUME, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.22, 0.22), ImageTransparency = 1, ZIndex = 2 }, sg)
    local ring = (not low) and H.FxPart({ Shape = Enum.PartType.Cylinder, Size = V(0.025, 0.2, 0.2), Color = LUME, Transparency = 1,
        CFrame = CFrame.new(axis + V(0, 0.05, 0)) * H.ANG(0, 0, H.R(90)) }, model) or nil
    -- the body (its own colours), dragged down into the web
    local bits = {}
    for _, s in ipairs(SfBits(pos, H)) do
        if #bits >= (low and 3 or 8) then break end
        local col = (math.min(s.Color.R, s.Color.G, s.Color.B) > 0.9) and BODY or s.Color -- (a hit-flash white body: its set colour)
        local p = H.FxPart({ Material = (s.Material == Enum.Material.Neon) and Enum.Material.Neon or Enum.Material.SmoothPlastic, Size = s.Size, CFrame = s.CFrame,
            Color = col, Transparency = s.Transparency, Shape = (s:IsA("Part") and s.Shape == Enum.PartType.Ball) and Enum.PartType.Ball or nil }, model)
        table.insert(bits, { P = p, CF = s.CFrame, Size = s.Size, C0 = col, T = s.Transparency, Delay = math.random() * 0.06 })
    end
    -- the cocoon: lies on the web, long along your view's right
    local CL, CW = 3.3, 1.45
    local cocoon = H.FxPart({ Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic, Size = V(CL, CW, CW), Color = SILK, Transparency = 1,
        CFrame = CFrame.fromMatrix(axis + V(0, CW * 0.45, 0), rt, Vector3.yAxis) }, model)
    -- the anchor lines (rim -> body) + the crimson wrap round the cocoon
    local host = H.FxPart({ Transparency = 1, Size = V(1.6, 1, 1.6), CFrame = CFrame.new(axis + V(0, 0.5, 0)) }, model)
    local lines = {}
    local NL = low and 3 or 5
    local fwd = rt:Cross(Vector3.yAxis)
    for i = 1, NL do
        local a = (i - 0.5) / NL * math.pi -- (a half fan on your side and the sides: none run at you over the crosshair)
        local rim = axis + (rt * math.cos(a) + fwd * math.sin(a) * 0.6).Unit * RW + V(0, 0.08, 0)
        local a0, a1 = H.Att(host, rim), H.Att(host, rim)
        local b = Instance.new("Beam")
        b.Attachment0, b.Attachment1 = a0, a1
        b.Color = ColorSequence.new(SILK); b.LightEmission = 0.2; b.LightInfluence = 0.5; b.FaceCamera = true; b.Segments = 1
        b.Width0, b.Width1 = 0.12, 0.07
        b.Transparency = NumberSequence.new(1)
        b.Parent = host
        lines[i] = { B = b, A0 = a0, A1 = a1, Rim = rim, Y = 1.2 + (i % 3) * 0.6 }
    end
    local wrap
    if not low then
        local w0, w1 = H.Att(host, axis), H.Att(host, axis)
        local b = Instance.new("Beam")
        b.Attachment0, b.Attachment1 = w0, w1
        b.Color = ColorSequence.new(DEEP:Lerp(LUME, 0.5)); b.LightEmission = 0.3; b.LightInfluence = 0.4; b.FaceCamera = true; b.Segments = 16
        b.Width0, b.Width1 = 0.2, 0.2
        b.Transparency = NumberSequence.new(1)
        b.Parent = host
        wrap = { B = b, A0 = w0, A1 = w1 }
    end
    local tufts = H.Emitter(H.Att(host, axis + V(0, 0.4, 0)), { Name = "SfTufts", Texture = Tex("sf_silk", H.SPARK), Color = { SILK, SILK:Lerp(LUME, 0.3) },
        Size = { 0.5, 0.25 }, Life = { 0.4, 0.7 }, Speed = { 3, 6 }, Spread = 70, Dir = Enum.NormalId.Top, Drag = 3, Accel = V(0, -8, 0), Light = 0,
        Influence = 0.8, Spin = { -120, 120 }, Rot = { 0, 360 } })
    local dur = low and 1.15 or 1.4
    local UNDER = low and 0.7 or 0.9
    local snapped = false
    H.Animate(dur, function(t, dt)
        -- 1) the WEB spins out across the floor (0 -> 0.2), turns slowly
        local spin = 1 - (1 - math.min(1, t / 0.2)) ^ 3
        local under = smooth((t - UNDER) / (dur - UNDER - 0.05))
        local R = RW * spin * (1 - 0.85 * under)
        local dia = math.max(0.1, R * 2)
        ink.Size = V(0.04, dia + 0.4, dia + 0.4)
        ink.Transparency = (R < 0.05) and 1 or 0
        card.Size = V(dia, 0.02, dia)
        card.CFrame = CFrame.new(axis + V(0, 0.07, 0)) * CFrame.Angles(0, -0.6 * spin + 2.5 * under * under, 0)
        web.ImageTransparency = (R < 0.05) and 1 or 0.05
        -- 2) DRAGGED DOWN (0.12 -> 0.55): every part slides in to the web's heart and down, squashes, is wrapped white
        for _, b in ipairs(bits) do
            local k = smooth((t - 0.12 - b.Delay) / 0.43)
            local home = b.CF.Position
            local target = axis + V(0, 0.5, 0)
            local at = home:Lerp(target, k * k)
            b.P.CFrame = (b.CF - home) * CFrame.Angles(0, 0, k * 0.6) + at
            b.P.Size = b.Size * V(1 - 0.5 * k, math.max(0.1, 1 - 0.75 * k), 1 - 0.5 * k)
            b.P.Color = b.C0:Lerp(SILK, smooth((k - 0.3) / 0.6))
            b.P.Transparency = (t > 0.55) and 1 or b.T
        end
        -- the anchor lines shoot from the rim up to the body (0.05 -> 0.17), then follow it down, then snap in with the web
        for _, l in ipairs(lines) do
            local s = 1 - (1 - math.clamp((t - 0.05) / 0.12, 0, 1)) ^ 2
            local k = smooth((t - 0.12) / 0.43)
            local bodyAt = axis + V(0, l.Y * (1 - k) + 0.5 * k, 0)
            local rim = axis + (l.Rim - axis) * (R / RW) + V(0, 0.08, 0)
            l.A0.WorldPosition = rim
            l.A1.WorldPosition = rim:Lerp(bodyAt, s)
            l.B.Transparency = NumberSequence.new((t < 0.05 or t > UNDER + 0.15) and 1 or 0.05)
        end
        -- 3) the COCOON: appears as the body is pulled in (0.5), twitches (0.66, 0.78), then 4) sinks through the floor
        local form = smooth((t - 0.48) / 0.1)
        local tw = math.exp(-((t - 0.66) / 0.025) ^ 2) - math.exp(-((t - 0.78) / 0.025) ^ 2)
        local sink = under * (CW + 0.4)
        cocoon.Size = V(CL * (0.5 + 0.5 * form), CW * (0.6 + 0.4 * form), CW * (0.6 + 0.4 * form))
        cocoon.CFrame = CFrame.fromMatrix(axis + V(0, CW * 0.45 - sink, 0), rt, Vector3.yAxis) * CFrame.Angles(math.rad(tw * 12), 0, math.rad(tw * 5))
        cocoon.Transparency = (form <= 0 or under >= 0.99) and 1 or 0
        if wrap then
            local cf = cocoon.CFrame
            local L = cocoon.Size.X
            wrap.A0.WorldPosition = (cf * CFrame.new(-L * 0.44, -0.1, 0)).Position
            wrap.A1.WorldPosition = (cf * CFrame.new(L * 0.44, 0.1, 0)).Position
            wrap.B.CurveSize0, wrap.B.CurveSize1 = CW * 1.6, -CW * 1.6
            wrap.B.Transparency = NumberSequence.new((form < 0.5 or under > 0.6) and 1 or 0.1)
        end
        -- the hourglass glows at the web's heart while it is cocooned
        local glow = smooth((t - 0.55) / 0.1) * (1 - under)
        heart.ImageTransparency = 1 - glow
        heart.ImageColor3 = LUME:Lerp(HOT, math.abs(tw))
        -- the snap: a crimson ring out from the web's heart as it goes under
        if ring then
            local rk = math.clamp((t - UNDER - 0.1) / 0.3, 0, 1)
            local rd = 0.6 + RW * 2 * rk
            ring.Size = V(0.025, rd, rd)
            ring.Transparency = (rk <= 0 or rk >= 1) and 1 or (0.1 + 0.9 * rk)
        end
        if t >= 0.5 and not snapped then
            snapped = true
            tufts:Emit(low and 4 or 8)
        end
    end, function() model:Destroy() end)
end

-- ===== the HOURGLASS banner (lower right, beside the weapon card): a dark plate with the crimson hourglass in a web ring;
-- each kill in the streak spins one more segment of the ring into place round it (1 - 5) =====
local banner
local NUMFONT = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold)
local WORDS = { "SNARED", "WOVEN", "SPUN", "WRAPPED", "COCOONED" }
Set.Banner = function(H: any, streak: number)
    local gui, root = H.BannerRoot("Silkfang", Vector2.new(180, 90), "Side")
    if not root then return end
    local New = H.New
    if not banner or banner.Root ~= root then
        local plate = New("Frame", { BackgroundColor3 = P.Plate, BackgroundTransparency = 0.06, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, root,
            { New("UICorner", { CornerRadius = UDim.new(0, 8) }), New("UIStroke", { Color = MID, Thickness = 1.2, Transparency = 0.3 }) })
        local web = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("tex_sf_web", ""), ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(64, 64),
            ImageColor3 = MID, ImageTransparency = 0.88, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, root, { New("UICorner", { CornerRadius = UDim.new(0, 8) }) })
        local segs = {}
        for i = 1, 5 do
            segs[i] = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("sf_seg", ""), ImageColor3 = SILK, AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(45, 45), Size = UDim2.fromOffset(78, 78), Rotation = (i - 1) * 72, ImageTransparency = 0.85, ZIndex = 2 }, root)
        end
        local glow = New("ImageLabel", { BackgroundTransparency = 1, Image = H.Art.Glow, ImageColor3 = LUME, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(45, 45), Size = UDim2.fromOffset(64, 64), ImageTransparency = 0.8, ZIndex = 2 }, root)
        local hour = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("sf_hour", ""), ImageColor3 = LUME, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(45, 45), Size = UDim2.fromOffset(30, 30), ZIndex = 3 }, root)
        if Tex("sf_hour", "") == "" then hour.BackgroundTransparency = 0; hour.BackgroundColor3 = LUME; hour.Size = UDim2.fromOffset(12, 22) end
        local num = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(94, 34), Size = UDim2.fromOffset(80, 30),
            FontFace = NUMFONT, TextSize = 28, TextColor3 = P.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 3 }, root)
        num:SetAttribute("KeepFont", true)
        local word = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(94, 62), Size = UDim2.fromOffset(84, 18),
            FontFace = NUMFONT, TextSize = 13, TextColor3 = SILK, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 3 }, root)
        word:SetAttribute("KeepFont", true)
        banner = { Root = root, Plate = plate, Web = web, Segs = segs, Glow = glow, Hour = hour, Num = num, Word = word, Token = 0 }
    end
    local b = banner
    b.Token += 1
    local token = b.Token
    local st = math.clamp(streak or 1, 1, 5)
    root.Visible = true
    b.Plate.BackgroundTransparency = 0.06
    b.Web.ImageTransparency = 0.88
    b.Hour.ImageTransparency = 0
    b.Num.TextTransparency = 0; b.Word.TextTransparency = 0
    b.Num.Text = "x" .. st
    b.Word.Text = WORDS[st]
    b.Num.TextColor3 = (st >= 5) and LUME or P.Text
    b.Word.TextColor3 = (st >= 5) and LUME or SILK
    for i, s in ipairs(b.Segs) do
        s.ImageTransparency = (i < st) and 0.1 or 0.85
        s.ImageColor3 = (i < st) and SILK or MID
        s.Rotation = (i - 1) * 72
    end
    local seg = b.Segs[st]
    H.Animate(0.42, function(t)
        if b.Token ~= token then return end
        local k = 1 - (1 - t / 0.42) ^ 3
        -- the new segment is spun into place (a quarter turn) and goes from dim to silk
        seg.Rotation = (st - 1) * 72 - 90 * (1 - k)
        seg.ImageTransparency = 0.85 - 0.75 * k
        seg.ImageColor3 = MID:Lerp((st >= 5) and LUME or SILK, k)
        -- the hourglass beats once
        local beat = math.sin(math.clamp(t / 0.2, 0, 1) * math.pi)
        b.Hour.Size = UDim2.fromOffset(30 + 6 * beat, 30 + 6 * beat)
        b.Glow.ImageTransparency = 0.8 - 0.35 * beat * (st >= 5 and 1.6 or 1)
    end)
    task.delay(1.6, function()
        if b.Token ~= token then return end
        local ti = TweenInfo.new(0.3)
        H.TweenService:Create(b.Plate, ti, { BackgroundTransparency = 1 }):Play()
        H.TweenService:Create(b.Web, ti, { ImageTransparency = 1 }):Play()
        H.TweenService:Create(b.Hour, ti, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
        H.TweenService:Create(b.Glow, ti, { ImageTransparency = 1 }):Play()
        H.TweenService:Create(b.Num, ti, { TextTransparency = 1 }):Play()
        H.TweenService:Create(b.Word, ti, { TextTransparency = 1 }):Play()
        for _, s in ipairs(b.Segs) do H.TweenService:Create(s, ti, { ImageTransparency = 1 }):Play() end
        task.delay(0.32, function() if b.Token == token then root.Visible = false end end)
    end)
end

-- ===== the FANG KARAMBIT (melee, Karambit class): WeaponAssets.MeleeModels.Silkfang -- a widow-black crescent blade with a
-- silver edge bevel and a crimson VENOM GROOVE along its spine (Neon, breathing), a plum bolster, a black handle bound in
-- crossing silver silk, and a web-engraved silver finger ring =====
Set.Melee = {
    Skin = { Name = "Fang Karambit", Price = 449, ProductId = 0,
        Desc = "A real fang for a blade: glossy violet-black chitin with raised enamel ridges and a silver edge, growing out of a bulbous chelicera base, a venom channel glowing along its spine and a drop of venom slowly gathering at the tip. The handle is bound in plum silk, the finger ring dark silver. Held reversed, ring on top. Every kill is COCOONED." },
    Rig = { Class = "Karambit", BladeLen = 0.55 },
    FlatBlade = true,
    InspectEvents = { { "Flip", "SfVenom" } },
    Build = function(m: Model, o: any, H: any)
        local parts = H.CloneModel(m, "MeleeModels", "Silkfang", VAR, { [1] = LUME })
        -- (the finger ring is held in the fist: part of the grip for the clip check)
        if parts.GripRing then parts.GripRing.Name = "GripRing" end
        local blade = parts.Blade
        if not blade then return end
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Name, a1.Name = "TrailBase", "TrailTip"
        a0.Position = blade.CFrame:PointToObjectSpace(blade.Position - blade.CFrame.UpVector * blade.Size.Y * 0.3)
        a1.Position = blade.CFrame:PointToObjectSpace(blade.Position + blade.CFrame.UpVector * blade.Size.Y * 0.45)
        a0.Parent, a1.Parent = blade, blade
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Color = ColorSequence.new(SILK, LUME)
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
        tr.LightEmission = 0.5; tr.LightInfluence = 0
        tr.Lifetime = 0.12; tr.MinLength = 0.02; tr.FaceCamera = true
        tr.Enabled = false
        tr:SetAttribute("SwingTrail", true)
        tr.Parent = blade
    end,
}

-- ===== arms: SILK GLOVES + BOUND SLEEVES (sculpted mesh pieces, WeaponAssets.ArmsModels.Silkfang) =====
-- Glove: a black satin glove with a raised silver web on the back of the hand; ONE effect: a tiny dewdrop slides down one of
-- the web's threads every few seconds (and once on a kill). Sleeve: a black silk sleeve wound in crossing silver silk bands,
-- closed at the wrist by a cuff with a crimson hourglass clasp (painted, no glow).
Set.Glove = function(K: any)
    local V3 = K.V
    return {
        Id = "SilkGloves", Name = "Silk Gloves", Price = 449,
        Desc = "Black satin gloves armoured in glossy chitin -- a domed plate with a dark-silver keel on the back of the hand and four articulated knuckle plates -- the fingers bound in plum silk, a silk cuff at the wrist. Now and then a tiny dewdrop slides down the keel -- and once more when you get a kill. Part of the Silkfang set.",
        Base = { Color = BODY:Lerp(C(0, 0, 0), 0.2), Material = Enum.Material.SmoothPlastic },
        Parts = {
            -- (arms bar: three finishes -- black satin glove, glossy chitin plates, matte plum silk bound round the fingers --
            -- and a dark-silver edged silk cuff at the wrist)
            { Mesh = "Silkfang/Wrap", MeshV = VAR, Size = V3(1.12, 1.12, 0.3), Off = V3(0, 0, -0.36) },
            { Mesh = "Silkfang/Cuff", MeshV = VAR, Size = V3(1.1, 1.1, 0.18), Off = V3(0, 0, 0.44) },
            { Mesh = "Silkfang/Back", MeshV = VAR, Size = V3(0.86, 0.14, 0.8), Off = V3(0, 0.57, -0.05), Seat = true },
            { Shape = "Ball", Size = V3(0.055, 0.045, 0.055), Off = V3(0, 0.655, -0.2), Path = V3(0, 0, 0.44), Color = SILK, Glow = true, Seat = true,
              Anim = "Drip", Period = 5.5, Dur = 1.7, PulseMin = 0.15, PulseMax = 1, BurstOn = "Kill" },
        },
    }
end
Set.Sleeve = function(K: any)
    local V3 = K.V
    return {
        Id = "BoundSleeves", Name = "Bound Sleeves", Price = 299,
        Desc = "A black silk sleeve wound into a cocoon of matte plum silk, closed at the wrist by a silk cuff with a crimson hourglass clasp. Part of the Silkfang set.",
        Base = { Color = BODY:Lerp(PLUM, 0.25), Material = Enum.Material.SmoothPlastic },
        Parts = {
            { Mesh = "Silkfang/Cuff", MeshV = VAR, Size = V3(1.15, 1.15, 0.24), Off = V3(0, 0, -0.4) },
            { Mesh = "Silkfang/Wrap", MeshV = VAR, Size = V3(1.27, 1.27, 0.36), Off = V3(0, 0, -0.1) },
            { Mesh = "Silkfang/Wrap", MeshV = VAR, Size = V3(1.27, 1.27, 0.36), Off = V3(0, 0, 0.27), Rot = V3(0, 0, 90) },
            { Mesh = "Silkfang/Clasp", MeshV = VAR, Size = V3(0.3, 0.08, 0.4), Off = V3(0, 0.6, -0.4), Seat = true },
        },
    }
end

-- ===== health bar: a black bar crossed by a fine web, a crimson fill, a dewdrop hanging at the fill's end; a hit makes the
-- web shiver (a small sideways tremble of the web overlay, no flash) =====
Set.Bar = { Id = "Silkfang", Name = "Silkfang", Price = 149,
    Desc = "A black bar crossed by a fine silver web with a venom-crimson fill and a dewdrop hanging at its end. Lost health is WRAPPED in silk before it drains away, and a hit makes the web shiver. Part of the Silkfang set.",
    Look = "Ink", FillColor = LUME, Tex = "tex_sf_bar", TexColor = LUME:Lerp(HOT, 0.25), TexSpeed = 0, ChipMotion = "Drain", Chip = SILK,
    Back = C(10, 8, 12), Glow = LUME, Segments = 5, Decor = { "SilkWrap", "WebShiver", "DewEnd" } }
Set.BarDecor = {
    -- (BARS v2) the lost piece is WRAPPED: silver silk bands wind over the chip as it drains (diagonal threads across it)
    SilkWrap = function(ctx: any, K: any)
        local f = K.Fader()
        local wrap = K.New("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 11 }, ctx.Holder)
        local bands = {}
        for i = 1, 4 do
            local b = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = SILK, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 60, ZIndex = 12 }, wrap)
            f.Add(b, 0.1, "BackgroundTransparency")
            bands[i] = b
        end
        return function(now, dt, alpha, info)
            local x0 = ctx.W * math.clamp(info.Shown, 0, 1)
            local x1 = ctx.W * math.clamp(info.Chip or info.Shown, 0, 1)
            local w = math.max(0, x1 - x0)
            wrap.Position = UDim2.fromOffset(x0, 0)
            wrap.Size = UDim2.fromOffset(w, ctx.H)
            for i, b in ipairs(bands) do
                b.Size = UDim2.fromOffset(2, ctx.H * 2.4)
                b.Position = UDim2.fromOffset(((i - 1) * 7 + (now * 18) % 7), ctx.H / 2)
            end
            f.Apply(w > 2 and alpha or 0)
        end
    end,
    VenomFill = function(ctx: any, K: any)
        for _, c in ipairs(ctx.Inner:GetChildren()) do if c:IsA("ImageLabel") then c.ImageColor3 = LUME end end
        return function() end
    end,
    WebShiver = function(ctx: any, K: any)
        local f = K.Fader()
        local web = f.Add(K.Img(Tex("tex_sf_web", ""), { ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(32, 32), ImageColor3 = SILK,
            Size = UDim2.fromScale(1, 1), ZIndex = 11 }, ctx.Holder), 0.82)
        local kick, lastHit = 0, 0
        return function(now, dt, alpha, info)
            if (info.Hit or 0) > lastHit + 0.05 then kick = 1 end
            lastHit = info.Hit or 0
            kick = math.max(0, kick - dt / 0.35)
            web.Position = UDim2.fromOffset(math.sin(now * 60) * 1.5 * kick, 0)
            f.Apply(alpha)
        end
    end,
    DewEnd = function(ctx: any, K: any)
        local f = K.Fader()
        local dew = f.Add(K.Img("glow", { AnchorPoint = Vector2.new(0.5, 0), ImageColor3 = SILK, ZIndex = 12 }, ctx.Holder), 0.1)
        local dot = Instance.new("Frame")
        dot.BorderSizePixel = 0; dot.BackgroundColor3 = SILK; dot.AnchorPoint = Vector2.new(0.5, 0); dot.ZIndex = 13; dot.Parent = ctx.Holder
        dot.Size = UDim2.fromOffset(5, 6)
        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0.5, 0); corner.Parent = dot
        f.Add(dot, 0.05, "BackgroundTransparency")
        return function(now, dt, alpha, info)
            local x = ctx.W * math.clamp(info.Shown, 0, 1)
            local swell = 0.5 + 0.5 * math.sin(now * 1.7)
            dot.Size = UDim2.fromOffset(4 + 2 * swell, 5 + 3 * swell)
            dot.Position = UDim2.fromOffset(x, ctx.H * 0.62)
            dew.Size = UDim2.fromOffset(ctx.H * 1.2, ctx.H * 1.2)
            dew.Position = UDim2.fromOffset(x, ctx.H * 0.2)
            f.Apply(alpha)
        end
    end,
}

local P1 = PALETTES[1]
-- ===== UI theme v2 (FX roll-out 2026-10-14; v1 = the shared template: web texture + 4 corner sprites + watermark + thread
-- ambient + the shared Sweep). Its own pieces (flat faces + ink, no glow over text): a WEB built of real threads in the two
-- bottom corners (five spokes + three rungs, silver on an ink underline), a small SPIDER (the crimson hourglass on a black
-- body) that lets itself down on a thread from the top edge now and then and climbs back, a SILK LINE with a dewdrop under
-- every title, and windows open with the webs SPINNING: spokes shoot out of the corners one by one, then the rungs are
-- laid. Colours from the theme table. =====
local function SfLine(parent, a, b, th, col, z, name)
    -- a straight thread between two points (pixels, in parent space)
    local d = b - a
    local f = Instance.new("Frame")
    f.Name = name or "SfThread"; f.BorderSizePixel = 0; f.BackgroundColor3 = col; f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Size = UDim2.fromOffset(d.Magnitude, th); f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
    f.Rotation = math.deg(math.atan2(d.Y, d.X)); f.ZIndex = z; f.Parent = parent
    return f
end
local function Web(ctx, f, right, R)
    -- a quarter web in a bottom corner: spokes from the corner, rungs between neighbouring spokes
    local t = ctx.Theme
    local holder = Instance.new("Frame")
    holder.Name = "SfWeb"; holder.BackgroundTransparency = 1; holder.Size = UDim2.fromOffset(R + 4, R + 4)
    holder.AnchorPoint = Vector2.new(right and 1 or 0, 1); holder.Position = UDim2.fromScale(right and 1 or 0, 1); holder.ZIndex = f.ZIndex + 1
    holder.Parent = f
    local o = Vector2.new(right and R + 2 or 2, R + 2)
    local spokes, rungs = {}, {}
    local pts = {}
    for i = 0, 4 do
        local a = math.rad(i * 22.5)
        local dir = Vector2.new((right and -1 or 1) * math.cos(a), -math.sin(a)) -- (fans up out of a bottom corner)
        pts[i] = dir
        -- (each thread = an ink line under a silver line: reads on light and dark glass)
        local ink = SfLine(holder, o, o + dir * R, 3, t.Ink, holder.ZIndex, "SfInk")
        local sil = SfLine(holder, o, o + dir * R, 1, t.Silk, holder.ZIndex + 1, "SfSpoke")
        spokes[i + 1] = { Ink = ink, Sil = sil, Dir = dir }
    end
    for r = 1, 3 do
        local rr = R * (0.32 + 0.24 * r)
        for i = 0, 3 do
            local a, b = o + pts[i] * rr, o + pts[i + 1] * rr * 0.96
            local ln = SfLine(holder, a, b, 1, t.Silk, holder.ZIndex + 1, "SfRung")
            table.insert(rungs, { F = ln, Ring = r })
        end
    end
    return holder, spokes, rungs, o
end
local function SfDeco(ctx)
    local t = ctx.Theme
    if ctx.Kind ~= "Window" then return nil end -- (HUD panels stay clean)
    local host = ctx.Root or ctx.Surface
    local f = Instance.new("Frame")
    f.Name = "SfOverlay"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 20; f.Active = false; f.ClipsDescendants = true
    f:SetAttribute("NoSkin", true); f:SetAttribute("Skinned", true)
    f.Parent = host
    local abs = host.AbsoluteSize
    local small = math.min(abs.X, abs.Y) < 260
    local R = math.clamp(math.floor(math.min(abs.X, abs.Y) * 0.12), small and 20 or 36, small and 34 or 58)
    -- (bottom corners: at the top they covered the window title / close button -- seen in play)
    Web(ctx, f, false, R)
    Web(ctx, f, true, R)
    if small then return nil, { f } end
    -- the spider: a thread + a black body with the crimson hourglass, letting down from the top edge every 7-12 s
    local thread = Instance.new("Frame")
    thread.Name = "SfDrop"; thread.BorderSizePixel = 0; thread.BackgroundColor3 = t.Silk; thread.AnchorPoint = Vector2.new(0.5, 0)
    thread.Size = UDim2.fromOffset(1, 0); thread.ZIndex = f.ZIndex + 2; thread.Parent = f
    local spider = Instance.new("Frame")
    spider.Name = "SfSpider"; spider.BorderSizePixel = 0; spider.BackgroundColor3 = t.Ink; spider.AnchorPoint = Vector2.new(0.5, 0.5)
    spider.Size = UDim2.fromOffset(9, 12); spider.ZIndex = f.ZIndex + 3; spider.Visible = false; spider.Parent = f
    local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0.5, 0); cr.Parent = spider
    local st = Instance.new("UIStroke"); st.Color = t.Silk; st.Thickness = 1; st.Parent = spider
    for i = 1, 2 do -- (the hourglass: two small crimson diamonds point to point)
        local dmd = Instance.new("Frame")
        dmd.BorderSizePixel = 0; dmd.BackgroundColor3 = t.Accent; dmd.AnchorPoint = Vector2.new(0.5, 0.5); dmd.Rotation = 45
        dmd.Size = UDim2.fromOffset(3, 3); dmd.Position = UDim2.new(0.5, 0, 0.5, (i == 1) and -2 or 2); dmd.ZIndex = spider.ZIndex + 1; dmd.Parent = spider
    end
    local nextDrop, dropAt, x = os.clock() + 3 + math.random() * 4, -99, 0.5
    return function(now, dt)
        if now >= nextDrop then
            nextDrop = now + 7 + math.random() * 5
            dropAt, x = now, 0.45 + math.random() * 0.22
        end
        local a = now - dropAt
        if a < 3.2 then
            -- down (0.9 s, eased), hang + sway (1.4 s), climb back (0.9 s)
            local depth
            if a < 0.9 then depth = 1 - (1 - a / 0.9) ^ 2
            elseif a < 2.3 then depth = 1
            else depth = 1 - math.min(1, (a - 2.3) / 0.9) end
            local L = math.floor(46 * depth)
            local sway = (a > 0.9 and a < 2.3) and math.sin((a - 0.9) * 4) * 2 or 0
            thread.Visible, spider.Visible = true, true
            thread.Size = UDim2.fromOffset(1, L); thread.Position = UDim2.new(x, 0, 0, 0)
            spider.Position = UDim2.new(x, sway, 0, L + 5)
        elseif spider.Visible then
            thread.Visible, spider.Visible = false, false
        end
    end, { f }
end
local function SfOpen(ctx)
    -- the webs SPIN: spokes shoot out of the corners one after another (0 -> 0.25 s), then the rungs are laid ring by ring
    local t = ctx.Theme
    local f = (ctx.Root and ctx.Root:FindFirstChild("SfOverlay")) or ctx.Frame
    local spokes, rungs = {}, {}
    for _, w in ipairs(f:GetChildren()) do
        if w.Name == "SfWeb" then
            for _, d in ipairs(w:GetChildren()) do
                if d.Name == "SfSpoke" or d.Name == "SfInk" then table.insert(spokes, { F = d, W = d.Size.X.Offset, P = d.Position, R = d.Rotation })
                elseif d.Name == "SfRung" then table.insert(rungs, d) end
            end
        end
    end
    for _, r in ipairs(rungs) do r.BackgroundTransparency = 1 end
    local t0 = os.clock()
    local conn
    conn = game:GetService("RunService").RenderStepped:Connect(function()
        local a = os.clock() - t0
        for i, s in ipairs(spokes) do
            local k = math.clamp((a - ((i - 1) % 10) * 0.025) / 0.12, 0, 1)
            local th = math.rad(s.R)
            local half = s.W / 2
            -- (grows from its corner end: shift the centre back toward the corner as it shortens)
            local w = s.W * k
            s.F.Size = UDim2.fromOffset(w, s.F.Size.Y.Offset)
            s.F.Position = UDim2.fromOffset(s.P.X.Offset - math.cos(th) * (half - w / 2), s.P.Y.Offset - math.sin(th) * (half - w / 2))
        end
        for i, r in ipairs(rungs) do
            local k = math.clamp((a - 0.22 - (i - 1) % 12 * 0.02) / 0.08, 0, 1)
            r.BackgroundTransparency = 1 - k
        end
        if a >= 0.55 then
            conn:Disconnect()
            for _, s in ipairs(spokes) do s.F.Size = UDim2.fromOffset(s.W, s.F.Size.Y.Offset); s.F.Position = s.P end
            for _, r in ipairs(rungs) do r.BackgroundTransparency = 0 end
        end
    end)
end
local function SfTitle(ctx)
    -- a silk line under the title with a dewdrop hanging at its end
    local bar, t = ctx.Title, ctx.Theme
    local line = Instance.new("Frame")
    line.Name = "SfSilk"; line.BorderSizePixel = 0; line.BackgroundColor3 = t.Silk; line.AnchorPoint = Vector2.new(0, 1)
    line.Position = UDim2.new(0, 10, 1, -3); line.Size = UDim2.new(0.28, 0, 0, 1); line.ZIndex = bar.ZIndex + 1; line.Parent = bar
    local g = Instance.new("UIGradient")
    g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(1, 0) }); g.Parent = line
    local drop = Instance.new("Frame")
    drop.Name = "SfDew"; drop.BorderSizePixel = 0; drop.BackgroundColor3 = t.Accent; drop.AnchorPoint = Vector2.new(0.5, 0)
    drop.Size = UDim2.fromOffset(5, 7); drop.Position = UDim2.new(0.28, 10, 1, -3); drop.ZIndex = bar.ZIndex + 2; drop.Parent = bar
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = drop
    local st = Instance.new("UIStroke"); st.Color = t.Ink; st.Thickness = 1; st.Parent = drop
    return { line, drop }
end
-- numbers v3 (SKIN UI 2026-10-28, owner: the old one had "a weird line under it that just looks wrong and has nothing to do
-- with the skin"): CAUGHT IN THE WEB. Every number lands in a small orb web SPUN behind its digits -- six silk spokes shoot out
-- of the number, then two rungs close round them -- in an elegant serif (Bodoni) that hangs where it was caught and sways a
-- little. CRIT = the web is crimson (the hourglass colour) and the number thrashes in it; WEAK SPOT = a dewdrop runs down a
-- spoke; a KILL = the web wraps in round the number like a cocoon. Every colour is this copy's palette (P = the colourway).
local SF_SPOKES = 3 -- (three threads through the middle = six spokes: a GuiObject turns round its own centre)
local function SfMotion(e, age, pa, life)
    local k = math.min(1, age / 0.28)
    local up = 0.35 + 0.45 * (1 - (1 - k) ^ 3) -- (it hangs: barely rises)
    local hit = (pa < 0.16) and math.sin(pa / 0.16 * math.pi) or 0 -- (each hit stretches the web, then it springs back)
    local scale = 1 + 0.07 * hit * (e.BumpAmp or 1)
    local sway = math.sin(age * 4.2 + e.Seed) * 3 * math.min(1, age / 0.4)
    local thrash = (e.Crit and age < 0.35) and math.sin(age * 70) * 4 * (1 - age / 0.35) or 0
    local wrap = (e.Killed and e.KillAt) and math.clamp((os.clock() - e.KillAt) / 0.35, 0, 1) or 0
    return up, 0, scale * (1 - 0.12 * wrap), 0, 0, sway + thrash
end
local function SfAccent(e)
    local web = Instance.new("Frame")
    web.Name = "SfWeb"; web.BackgroundTransparency = 1; web.AnchorPoint = Vector2.new(0.5, 0.5); web.Position = UDim2.fromScale(0.5, 0.5)
    web.Size = UDim2.fromOffset(0, 0); web.ZIndex = 0
    for i = 1, SF_SPOKES do
        local l = Instance.new("Frame")
        l.Name = "Spoke" .. i; l.BorderSizePixel = 0; l.AnchorPoint = Vector2.new(0.5, 0.5); l.Position = UDim2.fromOffset(0, 0)
        l.Size = UDim2.fromOffset(0, 1); l.Rotation = (i - 1) * 60 + 12; l.ZIndex = 0; l.Parent = web
    end
    for i = 1, 2 do
        local r = Instance.new("Frame")
        r.Name = "Rung" .. i; r.BackgroundTransparency = 1; r.AnchorPoint = Vector2.new(0.5, 0.5); r.ZIndex = 0
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = r
        local st = Instance.new("UIStroke"); st.Thickness = 1; st.Parent = r
        r.Parent = web
    end
    local drop = Instance.new("Frame")
    drop.Name = "Dew"; drop.BorderSizePixel = 0; drop.AnchorPoint = Vector2.new(0.5, 0.5); drop.Size = UDim2.fromOffset(5, 5); drop.ZIndex = 0
    local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = drop
    drop.Parent = web
    return web
end
local function SfAccentStep(e, web, age, pa, alpha)
    local tb = e.Label.TextBounds
    local R = math.max(tb.X, tb.Y) * 0.62 + 10
    local spin = math.clamp(age / 0.14, 0, 1)
    local rung = math.clamp((age - 0.08) / 0.14, 0, 1)
    local wrap = (e.Killed and e.KillAt) and math.clamp((os.clock() - e.KillAt) / 0.35, 0, 1) or 0
    local len = R * (1 - (1 - spin) ^ 2) * (1 - 0.7 * wrap)
    local col = e.Crit and P.Lume or P.Silk
    local tr = math.clamp(0.35 + 0.65 * alpha, 0, 1)
    local shake = (e.Crit and age < 0.35) and math.sin(age * 60) * 3 * (1 - age / 0.35) or 0
    for i = 1, SF_SPOKES do
        local l = web:FindFirstChild("Spoke" .. i)
        if l then
            l.Size = UDim2.fromOffset(math.floor(len * 2), (e.Crit and i == 2) and 2 or 1)
            l.Rotation = (i - 1) * 60 + 12 + shake + wrap * 40
            l.BackgroundColor3 = col; l.BackgroundTransparency = tr
        end
    end
    for i = 1, 2 do
        local r = web:FindFirstChild("Rung" .. i)
        if r then
            local d = R * (i == 1 and 0.55 or 1.0) * 2 * rung * (1 - 0.6 * wrap)
            r.Size = UDim2.fromOffset(math.floor(d), math.floor(d * 0.86))
            local st = r:FindFirstChildOfClass("UIStroke")
            if st then st.Color = col; st.Transparency = math.clamp(tr + 0.15, 0, 1) end
        end
    end
    local drop = web:FindFirstChild("Dew")
    if drop then
        drop.Visible = e.Weak == true and not e.Dot
        if drop.Visible then
            local k = math.clamp((age - 0.12) / 0.5, 0, 1) -- (the dewdrop runs down the lower spoke)
            local a = math.rad(72 + shake + wrap * 40) -- (along the second thread, its lower half)
            local d = len * (0.25 + 0.7 * k)
            drop.Position = UDim2.fromOffset(math.cos(a) * d, math.sin(a) * d)
            drop.BackgroundColor3 = P.Hot; drop.BackgroundTransparency = alpha
        end
    end
end
-- ===== UI THEME v4 (SKIN UI THEMES 2026-10-28, owner: themes "lazy and not much different", header art stretched): the clean
-- language in this colourway's colours (UITheme Clean: palette roles from P) + two touches of its own. Hooks read only the
-- palette they are given (a colourway copy shares these functions):
--   TAB MARK  the underline is a SILK THREAD with a crimson dewdrop hanging off its end; on the top bar the drop runs along the
--             thread now and then (Sig's tick)
--   FIELD     an orb web spun in the lower-right corner of the screen (real threads: spokes + rungs, silk at low strength) and
--             one thread let down from the top bar with a dewdrop that sways
local SF_CLEAN = {
    Field = P.Plate:Lerp(P.Ink, 0.3), Surface = P.Plate:Lerp(P.Body, 0.25), Raised = P.Plate:Lerp(P.Plum, 0.5), Hover = P.Plum:Lerp(P.Body, 0.3):Lerp(P.Mid, 0.08),
    Well = P.Ink, Line = P.Plum:Lerp(P.Mid, 0.3), Tip = P.Plate, Accent = P.Lume, Mark = P.Silk, Hair = P.Silk,
    Text = P.Text, Sub = P.Silk:Lerp(P.Mid, 0.42), Muted = P.Mid:Lerp(P.Silk, 0.25), Ink = P.Ink,
    Silk = P.Silk, Drop = P.Lume, InkLine = P.Ink,
}
local function SfDew(parent, Q, z)
    local d = Instance.new("Frame")
    d.Name = "SfDew"; d.BorderSizePixel = 0; d.BackgroundColor3 = Q.Drop; d.AnchorPoint = Vector2.new(0.5, 0)
    d.Size = UDim2.fromOffset(5, 7); d.ZIndex = z; d.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = d
    local st = Instance.new("UIStroke"); st.Color = Q.InkLine; st.Thickness = 1; st.Parent = d
    return d
end
SF_CLEAN.TabMark = function(mark, Q)
    -- (the thread reads thinner than the 2 px bar: its lower half is the field showing through)
    local fade = Instance.new("UIGradient")
    fade.Rotation = 90
    fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.65) })
    fade.Parent = mark
    -- (tab buttons size themselves to their children and read Position + Size without the AnchorPoint: the drop is anchored
    -- left with its right edge on the mark's, or the tab grew without end)
    local d = SfDew(mark, Q, mark.ZIndex + 1)
    d.AnchorPoint = Vector2.new(0, 0)
    d.Position = UDim2.new(1, -5, 1, -1)
    return { fade, d }
end
SF_CLEAN.Sig = function(ctx)
    local Q, f = ctx.P, ctx.Frame
    local cam = workspace.CurrentCamera
    local vh = (cam and cam.ViewportSize.Y or 800)
    -- the orb web, lower right: spokes fan out of the corner, rungs join neighbours
    local R = math.clamp(math.floor(vh * 0.34), 150, 300)
    local web = Instance.new("Frame")
    web.Name = "SfOrb"; web.BackgroundTransparency = 1; web.AnchorPoint = Vector2.new(1, 1); web.Position = UDim2.fromScale(1, 1)
    web.Size = UDim2.fromOffset(R + 4, R + 4); web.ZIndex = 0; web.Parent = f
    local o = Vector2.new(R + 2, R + 2)
    local dirs = {}
    for i = 0, 5 do
        local a = math.rad(i * 18)
        dirs[i] = Vector2.new(-math.cos(a), -math.sin(a))
        local ln = SfLine(web, o, o + dirs[i] * R, 1, Q.Silk, 0, "SfSpoke")
        ln.BackgroundTransparency = 0.8
    end
    for r = 1, 5 do
        local rr = R * (0.18 + 0.16 * r)
        for i = 0, 4 do
            local ln = SfLine(web, o + dirs[i] * rr, o + dirs[i + 1] * rr * (0.94 + 0.04 * (r % 2)), 1, Q.Silk, 0, "SfRung")
            ln.BackgroundTransparency = 0.84
        end
    end
    -- one thread let down from under the top bar at the far right (in the margin, clear of the content), a dewdrop at its end
    -- that sways; it hangs off the bar itself, so it follows the bar wherever the menu puts it
    if not ctx.Top then return nil, nil end
    local hang = Instance.new("Frame")
    hang.Name = "SfHang"; hang.BackgroundTransparency = 1; hang.AnchorPoint = Vector2.new(0.5, 0); hang.ZIndex = 0
    local len = math.clamp(math.floor(vh * 0.07), 34, 64)
    hang.Position = UDim2.new(1, -11, 1, 0); hang.Size = UDim2.fromOffset(12, len + 8); hang.Parent = ctx.Top
    local thr = Instance.new("Frame")
    thr.Name = "SfThread"; thr.BorderSizePixel = 0; thr.BackgroundColor3 = Q.Silk; thr.BackgroundTransparency = 0.45; thr.AnchorPoint = Vector2.new(0.5, 0)
    thr.Position = UDim2.fromScale(0.5, 0); thr.Size = UDim2.new(0, 1, 0, len); thr.ZIndex = 0; thr.Parent = hang
    local drop = SfDew(hang, Q, 0)
    drop.Position = UDim2.new(0.5, 0, 0, len - 1)
    local seed = math.random() * 6
    return function(now, _dt)
        -- the drop sways on its thread (the holder turns round its top)
        hang.Rotation = math.sin(now * 0.9 + seed) * 2.2
        -- every ~6 s the dewdrop on the selected tab's thread runs from its start to its end, then waits there
        for _, m in ipairs(ctx.Marks()) do
            local d = m.Visible and m:FindFirstChild("SfDew")
            if d then
                local k = ((now + seed) % 6.5) / 2.2
                local x = (k < 1) and (0.08 + 0.92 * (1 - (1 - k) ^ 2)) or 1
                d.Position = UDim2.new(x, -5, 1, -1) -- (never past the mark's right edge: see TabMark)
            end
        end
    end, { hang }
end

local function PG(top, bottom) return { Top = top, Bottom = bottom } end
Set.Theme = { Name = "Silkfang", Desc = "Menus as a widow's lair: webs of real threads spun in the lower corners, a small spider with a crimson hourglass letting itself down on a thread now and then, and a silk line with a dewdrop under every title.",
    Panel = PG(C(20, 10, 20), C(6, 2, 6)), Card = PG(C(30, 16, 30), C(12, 6, 12)), Title = PG(C(110, 20, 40), C(30, 6, 14)),
    Accent = C(255, 30, 60), Accent2 = C(200, 200, 215), HpFill = C(230, 40, 70), HpBg = C(14, 8, 12), XpFill = C(200, 200, 215), Text = C(240, 225, 235),
    Silk = C(214, 216, 232), Ink = C(4, 2, 4),
    Tex = "tex_sf_web", TexT = 0.93, TexTile = 96,
    Emblem = "EmblemSilkfang", BorderThick = 2,
    Deco = SfDeco, OpenFn = SfOpen, TitleDeco = SfTitle,
    Clean = SF_CLEAN, -- (SKIN UI THEMES: the clean palette + silk-thread tab marks + the corner orb web; the old art above is not drawn)
    -- (FX roll-out: numbers let down on a silk thread in an elegant serif, sway, then the thread is cut)
    -- (SKIN UI 2026-10-28: numbers caught in a spun web, colours from this colourway's palette P -- see SfMotion)
    Numbers = { Font = "Bodoni", Glyph = "", NoBang = true, Motion = SfMotion, Accent = SfAccent, AccentStep = SfAccentStep,
        Normal = P.Text, Crit = P.Lume, Weak = P.Hot, Stroke = P.Ink, StrokeThick = 1.5, Size = 1.08 } }

-- ===== bundle / kill effect / store hero =====
Set.KillEffect = { Id = "Cocooned", Name = "Cocooned", Image = Tex("sf_emblem", ""),
    How = "Own any Silkfang skin (or the Silkfang bundle)",
    Desc = "Pulled under: a silver web spins out across the floor, anchor lines shoot up and the enemy is dragged down into it and wound into a silk cocoon that twitches as the crimson hourglass glows -- then it is pulled under through the floor and the web goes after it. With the Hourglass kill banner." }
Set.Bundle = { Id = "SilkfangBundle", Name = "Silkfang Bundle", Price = 2199, BP = 799, ProductId = 0,
    Desc = "The whole Silkfang set: the Silkfang TEC-9, M14 and Void Rifle, the Fang Karambit, Silk Gloves + Bound Sleeves, the Silkfang health bar, the Silkfang UI theme and the Cocooned kill effect.",
    Contents = { "WeaponSkin:SilkfangTEC9", "WeaponSkin:SilkfangEMR", "WeaponSkin:SilkfangVoidDisintegrator", "MeleeSkin:Silkfang", "Glove:SilkGloves", "Sleeve:BoundSleeves",
        "HealthBar:Silkfang", "KillEffect:Cocooned" } }
Set.Hero = { Grad = { C(40, 14, 30), C(6, 2, 6) }, Stroke = MID, Emblem = Tex("sf_emblem", ""), Name = C(240, 225, 235), Chip = C(120, 14, 34) }

return Set
