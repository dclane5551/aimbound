--!nocheck
-- ===================================================================================================================
-- PERMAFROST (Skins V3, bundle 9 of docs/SKINS_V3_PLAN.md; SKINS BUILDER 7 "skins7"): M82 + PKM + MP40 | Rime Sabre |
-- 1,199 BP. Weapons CUT OUT OF A GLACIER: the receivers are faceted blocks of deep glacial ice (crystal facets that change
-- along the gun, internal fracture lines and frozen-in bubbles painted in, hoar frost on every top chamfer, frost-steel
-- underneath), clear ice that you can see into, icicles hanging from the undersides and crowning the muzzles (forward /
-- DOWN, never up). ONE light language: a FROST FERN -- a dendritic ice crystal frozen inside a clear ice window on the camera
-- side -- whose light crawls from its root to its tips; a six-arm FROST STAR (our own) frozen in a pane of clear ice in the
-- stocks. The guns are RESCULPTED models (WeaponAssets.SkinModels.Permafrost_<GUN>, built by tools/skins_v3/permafrost_build.py
-- in art/weapons/SkinsV3_Permafrost.blend, painted by tools/skin_v3_paint.py with tools/skins_v3/permafrost.json).
--   ALIVE    a glint crawls up the fern every few seconds (louder with the streak); each shot flares it; vapour sinks off the
--            muzzle ice
--   EQUIP    the gun FREEZES in: the clear ice crystallises out of nothing and the fern grows from its root, step by step
--   INSPECT  the fern lights in a branching sweep, the star flares, ice flakes drift off the window
--   RELOAD   the ice cracks round the mag well (shards) and reseals with a crawl; the MP40's icicle magazine SNAPS off and the
--            new one grows its point back in three crystalline steps
-- Muzzle: a cold flash + a ring of frost crystals + a vapour puff. Tracer: a crystalline line leaving glinting ice motes
-- that melt. Impact: tiny ice shards spike out of the surface + a frost splash. Kill FROST BLOOM: frost ferns grow across the
-- ground from the body, the body frosts over and falls into fine snow. Banner: a crystal plate that grows one more arm of a
-- six-arm frost star per kill. Original design (plan "Originality"): no snow-globe scene, no marble print, no crystal blade
-- on black lacquer with gold edges, no olive hardware with coolant pipes -- dark glacier blocks with a lit fern frozen inside.
-- ===================================================================================================================
local Set = { Kind = "Permafrost" }

-- COLOURWAYS: each colourway is a whole palette -- the module copy SkinFX loads for colourway v has attribute Colorway = v.
-- The painted model maps are separate SurfaceAppearances (SkinFX.V3Swap); Colorways.Sets.Permafrost lists the names.
local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local V = Vector3.new
local PALETTES = {
    { Name = "Glacier", Body = C(11, 27, 58), Mid = C(70, 94, 128), Frost = C(190, 216, 236), Dark = C(6, 12, 26), Lume = C(120, 225, 255),
      Hot = C(226, 250, 255), Ice = C(110, 190, 235), Deep = C(8, 22, 48), Text = C(226, 240, 252), Ink = C(4, 8, 18), Sheet = C(30, 76, 140), Plate = C(10, 24, 48) },
    { Name = "Black Ice", Body = C(12, 12, 21), Mid = C(78, 72, 106), Frost = C(196, 186, 226), Dark = C(4, 4, 9), Lume = C(200, 170, 255),
      Hot = C(244, 236, 255), Ice = C(120, 108, 170), Deep = C(10, 9, 18), Text = C(236, 232, 248), Ink = C(3, 3, 7), Sheet = C(44, 36, 80), Plate = C(16, 14, 28) },
    { Name = "Meltwater", Body = C(8, 44, 52), Mid = C(58, 100, 104), Frost = C(186, 236, 226), Dark = C(3, 16, 20), Lume = C(90, 255, 220),
      Hot = C(224, 255, 248), Ice = C(90, 210, 195), Deep = C(6, 32, 38), Text = C(224, 250, 244), Ink = C(2, 12, 14), Sheet = C(20, 96, 104), Plate = C(8, 36, 42) },
    { Name = "Ember Ice", Body = C(20, 25, 42), Mid = C(100, 84, 78), Frost = C(214, 220, 232), Dark = C(10, 8, 10), Lume = C(255, 140, 60),
      Hot = C(255, 226, 190), Ice = C(160, 186, 220), Deep = C(16, 18, 30), Text = C(240, 236, 232), Ink = C(8, 6, 8), Sheet = C(60, 72, 110), Plate = C(24, 22, 30) },
}
local P = PALETTES[VAR] or PALETTES[1]
local BODY, MID, FROST, LUME, HOT, ICE = P.Body, P.Mid, P.Frost, P.Lume, P.Hot, P.Ice
Set.Palettes = PALETTES
Set.Colors = { Glow = LUME, Hot = HOT, Accent = FROST, Mid = MID }
-- art (tools/make_permafrost_art.py, uploaded as decals; these are the IMAGE ids, resolved in Studio). "" = not uploaded
-- yet: every user of an art key has a fallback.
local A = "rbxassetid://"
Set.Art = {
    EmblemPermafrost = A .. "81890742798339", pf_emblem = A .. "81890742798339", pf_emblem_mask = A .. "122646249764446", pf_flake = A .. "125562646948271",
    pf_shard = A .. "111133157516567", pf_ring = A .. "128712921442066", pf_splash = A .. "140697123480825", pf_bloom = A .. "110110028101055",
    pf_motes = A .. "79758767582984", pf_crack = A .. "123059535159149", pf_corner = A .. "78960920359277", tex_pf_ice = A .. "77304446106821",
    tex_pf_bar = A .. "76543542001836",
}
local ART = Set.Art
local function Tex(key: string, fallback: string): string
    local t = ART[key]
    return (t and t ~= "") and t or fallback
end

local TAU = math.pi * 2
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function pulse(t, w) return math.exp(-(t / w) ^ 2) end

-- the lit spots per gun (gun-space studs, from the sculpts): the fern window, the muzzle crown, the mag well
local DATA = {
    M82 = { Win = V(-0.96, 0.228, -0.12), Muzzle = V(2.24, 0.22, 0), Well = V(-0.72, 0.07, -0.1), Star = V(-2.39, 0.045, 0) },
    PKM = { Win = V(-0.68, 0.17, -0.06), Muzzle = V(2.12, 0.14, 0.066), Well = V(-0.16, 0.0, -0.05), Star = V(-1.6, 0.02, 0.066) },
    MP40 = { Win = V(-0.2, 0.17, -0.05), Muzzle = V(1.5, 0.2, 0.043), Well = V(0.53, 0.12, 0.0), Star = V(-1.1, 0.1, 0.04) },
}

local function GunDesc(gun: string): string
    local what = (gun == "PKM") and "the receiver and the handguard sheathed in faceted glacier ice, a skeleton stock framing a pane of clear ice, icicles hanging under the barrel and the ammunition box frozen into a block of ice with a glowing core"
        or (gun == "MP40") and "the receiver cased in faceted glacier ice and a magazine that IS one great icicle with a glowing core: it snaps off on a reload and the new one grows its point back"
        or "the whole receiver one faceted block of glacier ice, stacked ice sheets on the handguard, a crown of icicles round the muzzle and a skeleton stock framing a pane of clear ice"
    return "Cut out of a glacier: " .. what .. ". Deep blue ice with fracture lines and frozen bubbles, frost on every edge. A frost fern frozen in clear ice on its side lights up from the root to the tips; the gun freezes in when you draw it. Crystalline tracers, ice-shard impacts, and every kill brings the FROST BLOOM."
end

-- ===== the guns =====
Set.GunSkins = {
    { Id = "PermafrostM82", Name = "Permafrost M82", Gun = "M82", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("M82"),
      Model = "Permafrost_M82", V3 = true, Color = LUME, Deco = "PermafrostGun", Fit = { G = "M82" } },
    { Id = "PermafrostPKM", Name = "Permafrost PKM", Gun = "PKM", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("PKM"),
      Model = "Permafrost_PKM", V3 = true, Color = LUME, Deco = "PermafrostGun", Fit = { G = "PKM" } },
    { Id = "PermafrostMP40", Name = "Permafrost MP40", Gun = "MP40", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("MP40"),
      Model = "Permafrost_MP40", V3 = true, Color = LUME, Deco = "PermafrostGun", Fit = { G = "MP40" } },
}

-- ===== build: the clear ice takes the colourway's ice tint; first person gets the vapour + the flake emitters =====
Set.Build = {}
Set.Build.PermafrostGun = function(model: Model, frame: BasePart, f: any, forView: boolean, H: any)
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p:GetAttribute("IceClear") then
            p.Color = (p:GetAttribute("IceTone") == "Deep") and P.Sheet or ICE
            p.Reflectance = 0
            p.CastShadow = false
        end
    end
    local d = DATA[f.G or ""]
    if not d or not forView then return end
    local base = frame.CFrame
    -- cold vapour sinking off the muzzle ice (slow, sparse)
    local am = H.Att(frame, (base * CFrame.new(d.Muzzle)).Position)
    am.Name = "PfVapourAt"
    local vap = H.Emitter(am, { Name = "PfVapour", Texture = H.SMOKE, Color = { FROST, ICE }, Size = { 0.08, 0.32 }, Life = { 0.9, 1.4 },
        Speed = { 0.05, 0.2 }, Spread = 30, Trans = { 0.86, 1 }, Light = 0, Rate = 2, Drag = 1.5 })
    vap.Acceleration = V(0, -0.7, 0)
    vap.LightInfluence = 0.6
    -- ice flakes off the fern window (inspect) -- Rate 0, burst by events
    local aw = H.Att(frame, (base * CFrame.new(d.Win)).Position)
    aw.Name = "PfFlakeAt"
    local fl = H.Emitter(aw, { Name = "PfFlakes", Texture = Tex("pf_flake", H.SPARK), Color = { HOT, LUME }, Size = { 0.05, 0.015 }, Life = { 0.6, 1.1 },
        Speed = { 0.2, 0.7 }, Spread = 70, Trans = { 0.1, 1 }, Light = 1, Rate = 0, Drag = 2, Spin = { -120, 120 } })
    fl.Acceleration = V(0, 0.15, 0)
end

-- ===== sounds (tools/make_skin_sfx_v3.py permafrost: each gun's own recorded shot + an icy crackle transient + a low
-- glacier-groan tail; every moment from CC0 recordings -- ice cracking, crystal tinkles, a freezing creak, snow; see
-- tools/sound_sources.json). Id 0 = silent until uploaded. =====
Set.Sounds = {
    Fire = { Id = 0, Volume = 0 }, Equip = { Id = 118927060737301, Volume = 0.42 }, MagOut = { Id = 80686543572585, Volume = 0.36 }, MagIn = { Id = 118128097679019, Volume = 0.36 },
    Kill = { Id = 125902551515892, Volume = 0.5 }, Impact = { Id = 82063289034510, Volume = 0.22 }, Swing = { Id = 83478574824309, Volume = 0.38 }, MeleeHit = { Id = 96742565291505, Volume = 0.42 },
    Tinkle = { Id = 124875488904125, Volume = 0.24 },
    -- (each gun's own full shot; volumes matched to the base guns' level: M82 / PKM +1.5 dB, MP40 +3.0 dB over the base ->
    -- 0.80 / 0.76 / 0.51; the files were then turned down by tools/audio_screen.py --quieten (0.6 / 0.4 / 2.0 dB) and the
    -- volumes raised by the same factors x1.07 / x1.05 / x1.26)
    FireGun = { M82 = { Id = 136968988520940, Volume = 0.86 }, PKM = { Id = 119254971660666, Volume = 0.8 }, MP40 = { Id = 72260205386792, Volume = 0.64 } },
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
-- Freeze (the clear ice: 0 = not there, 1 = frozen in), Fern1..4 (the crawl steps of the fern), Star1..2, Grow (the MP40
-- icicle's point: 0..3 crystalline steps). v = rig.SkinVars / rec.Vars.
local function Keys(st: any, v: any, now: number, anim: string?, animT: number?)
    local ss = st.SinceShot or 99
    local se = st.SinceEquip or 99
    local streak = math.min(st.Streak or 0, 5)
    local rl = st.Reload or 0
    -- the ice crystallises in over the draw
    st.Freeze = smooth((se - 0.04) / 0.45)
    -- the fern: a dim base glow, a glint crawling root -> tips every few seconds (faster + brighter with the streak)
    local base = 0.32 + 0.07 * streak
    local period = 4.6 - 0.45 * streak
    local cyc = (now + (v.Phase or 0)) % period
    local crawlT = 1.1
    local flare = math.max(0, 1 - ss / 0.14) * 0.9
    local insp = nil
    if anim == "Inspect" and animT then
        -- the inspect: a branching sweep after Present, a full flare on the Tilt, settling after
        local a, b = v.Present or 0.62, v.Tilt or 1.9
        insp = { t = animT - a, tilt = animT - b }
    end
    -- reload: the crack dims the fern while the magazine is out; the reseal runs a crawl
    local rk = 1
    if rl > 0.12 and rl < 0.6 then rk = 0.35 end
    for i = 1, 4 do
        local g = base
        if cyc < crawlT + 0.6 then
            local d = cyc / crawlT * 5 - i
            g = math.max(g, base + (1 - base) * pulse(d, 0.9))
        end
        g = math.max(g, flare)
        if insp then
            if insp.t > 0 then g = math.max(g, pulse(insp.t * 4 - i, 1.1), 0.55) end
            if insp.tilt > -0.1 then g = math.max(g, 0.9 * pulse(insp.tilt, 0.35)) end
        end
        if rl > 0.6 and rl < 0.95 then g = math.max(g, pulse((rl - 0.6) * 18 - i, 0.9)) end
        g = g * rk
        -- the draw: the fern GROWS from its root, step by step (dark until its step)
        if se < 0.9 then
            local on = smooth((se - 0.12 - 0.11 * i) / 0.08)
            g = g * on + (on > 0 and on < 1 and 0.6 * on * (1 - on) * 4 or 0)
        end
        st["Fern" .. i] = math.clamp(g, 0, 1)
    end
    -- the star in the stock pane: breathes slowly, flares with the shot streak and on the inspect's Tilt
    local sb = 0.4 + 0.15 * math.sin(now * TAU / 5.2) + 0.08 * streak
    if insp and insp.tilt > -0.2 then sb = math.max(sb, pulse(insp.tilt - 0.15, 0.4)) end
    local kt = v.KillT and (now - v.KillT) or 99
    sb = math.max(sb, pulse(kt, 0.35))
    st.Star1 = math.clamp(sb, 0, 1)
    st.Star2 = math.clamp(sb * 0.85, 0, 1)
    -- the MP40 icicle: snapped at MagOut, grows back in three steps after MagIn
    local snap, grow = v.SnapT or -99, v.GrowT or -99
    if snap > grow then st.Grow = 0
    elseif now - grow < 0.45 then st.Grow = math.floor(math.clamp((now - grow) / 0.12, 0, 3))
    else st.Grow = 3 end
end
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    local v = rig.SkinVars
    if rig.Def and rig.Def.IsMelee then
        -- the sabre: its cyan core breathes; frost climbs the blade during the inspect (Frost 0 -> 1 between Raise and Flip)
        local an, at = rig.AnimName, rig.AnimTime
        local fz = 0
        if an == "Inspect" and at then fz = smooth((at - 0.4) / 1.4) * (1 - smooth((at - 2.6) / 0.3)) end
        st.Frost = fz * 4.2 -- (CountDrive slots 1..4: the crusts climb the blade step by step)
        st.Core = math.clamp(0.45 + 0.15 * math.sin(now * TAU / 3.4) + fz * 0.5 + pulse(v.HitT and (now - v.HitT) or 99, 0.2), 0, 1)
        st.Freeze = smooth(((st.SinceEquip or 99) - 0.05) / 0.4)
        return
    end
    local an, at = rig.AnimName, rig.AnimTime
    if an == "Inspect" and rig.Anim and rig.Anim.Beats then
        local b = rig.Anim.Beats
        v.Present, v.Tilt = b.Present or v.Present, b.Tilt or b.Flip or b.Rack or v.Tilt
    end
    Keys(st, v, now, an, at)
end
local function GunPartPos(rig: any, name: string): Vector3?
    local gp = rig.GunParts and rig.GunParts[name]
    return gp and gp.Part and gp.Part.Position or nil
end
-- a short burst of ice shards from a point (the reload's crack); its own little host, gone in a second
local function ShardBurst(H: any, pos: Vector3, n: number, speed: number)
    if not H.Budget("PermafrostShards", 3, 0.8) then return end
    local host = H.FxPart({ Transparency = 1, Size = V(0.05, 0.05, 0.05), CFrame = CFrame.new(pos) })
    local em = H.Emitter(host, { Name = "PfShardBurst", Texture = Tex("pf_shard", H.SPARK), Color = { ICE, P.Sheet }, Size = { 0.06, 0.02 }, Life = { 0.25, 0.45 },
        Speed = { speed * 0.5, speed }, Spread = 180, Trans = { 0.05, 1 }, Light = 0.6, Rate = 0, Drag = 2, Spin = { -300, 300 } })
    em.Acceleration = V(0, -14, 0)
    em:Emit(n)
    H.Debris:AddItem(host, 1)
end
Set.OnEvent = function(rig: any, name: string, H: any, data: any)
    local v = rig.SkinVars
    if not v then return end
    local now = os.clock()
    if name == "MagOut" then
        -- the ice cracks round the mag well; the MP40's icicle snaps off
        v.SnapT = now
        local p = GunPartPos(rig, "Magazine")
        if p then ShardBurst(H, p, 9, 3) end
    elseif name == "MagIn" then
        v.GrowT = now
        PlaySound(H, Set.Sounds.Tinkle, 1)
    elseif name == "Present" or name == "Tilt" or name == "Flip" then
        local fl = v.Flakes or (rig.Gun and rig.Gun:FindFirstChild("PfFlakes", true))
        v.Flakes = fl
        if fl then fl:Emit(name == "Present" and 6 or 10) end
        if name ~= "Present" then PlaySound(H, Set.Sounds.Tinkle, 1.12) end
    end
    if rig.Def and rig.Def.IsMelee and name == "Flip" then v.HitT = now end
end
Set.OnEquip = function(rig: any, H: any)
    if rig.SkinVars then rig.SkinVars.Phase = math.random() * 4 end
    if not Set._Preloaded then
        Set._Preloaded = true
        task.spawn(function()
            local list = {}
            for _, k in ipairs({ "pf_bloom", "pf_flake", "pf_shard", "pf_splash", "pf_ring", "pf_motes", "pf_emblem" }) do
                if ART[k] ~= "" then table.insert(list, ART[k]) end
            end
            pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
        end)
    end
end
Set.OnAnim = function(rig: any, name: string)
    if rig.Def and rig.Def.IsMelee and (name:find("Light") or name:find("Heavy") or name:find("Quick")) then rig.SkinVars.HitT = os.clock() end
end
-- other players' guns: frozen in, the crawl, the icicle whole
Set.World = function(rec: any, now: number, st: any)
    local v = rec.Vars
    st.SinceShot = 99; st.SinceEquip = 99; st.Reload = 0; st.Streak = 1
    v.Phase = v.Phase or math.random() * 4
    Keys(st, v, now, nil, nil)
    st.Grow = 3
    st.Freeze = 1
    st.Core = 0.55
    st.Frost = 0
end

-- ===== muzzle: a cold flash, a ring of frost crystals snapping out, a vapour puff =====
Set.Muzzle = function(rig: any, flash: ParticleEmitter, light: PointLight, muzzle: Attachment, H: any)
    flash.Color = ColorSequence.new(HOT, LUME)
    flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.13), NumberSequenceKeypoint.new(1, 0.02) })
    light.Color = LUME
    light.Brightness = 0.55
    rig.Fx.PfRing = H.Emitter(muzzle, { Name = "PfRing", Texture = Tex("pf_ring", H.Art.Glow or H.SPARK), Color = { HOT, LUME }, Size = { 0.06, 0.38 },
        Life = { 0.1, 0.12 }, Speed = { 0, 0 }, Trans = { 0.1, 1 }, Light = 1, Orient = Enum.ParticleOrientation.VelocityPerpendicular,
        Dir = Enum.NormalId.Right, Spread = 0 })
    rig.Fx.PfPuff = H.Emitter(muzzle, { Name = "PfPuff", Texture = H.SMOKE, Color = { FROST, ICE }, Size = { 0.1, 0.4 }, Life = { 0.3, 0.5 },
        Speed = { 0.6, 1.4 }, Spread = 25, Trans = { 0.65, 1 }, Light = 0, Drag = 4, Dir = Enum.NormalId.Right })
end
Set.OnFire = function(rig: any, H: any)
    if rig.Fx then
        if rig.Fx.PfRing then rig.Fx.PfRing:Emit(1) end
        if rig.Fx.PfPuff then rig.Fx.PfPuff:Emit(2) end
    end
end

-- ===== CRYSTALLINE tracer: a thin white-blue core racing to the hit, leaving a line of glinting ice motes that melt =====
Set.Tracer = function(H: any, from: Vector3, to: Vector3, peer: boolean?)
    local dist = (to - from).Magnitude
    if dist < 1.5 then return end
    local host = H.FxPart({ Transparency = 1, Size = V(0.05, 0.05, 0.05), CFrame = CFrame.new(from) })
    local a0, a1 = H.Att(host, from), H.Att(host, to)
    local core = Instance.new("Beam")
    core.Attachment0, core.Attachment1 = a0, a1
    core.Color = ColorSequence.new(HOT, LUME); core.LightEmission = 1; core.LightInfluence = 0; core.FaceCamera = true; core.Segments = 1
    core.Width0, core.Width1 = 0.012, peer and 0.03 or 0.04
    core.Parent = host
    local motes = Instance.new("Beam")
    motes.Attachment0, motes.Attachment1 = a0, a1
    motes.Texture = Tex("pf_motes", H.SPARK); motes.TextureMode = Enum.TextureMode.Static; motes.TextureLength = 0.9; motes.TextureSpeed = 0
    motes.Color = ColorSequence.new(HOT, LUME); motes.LightEmission = 1; motes.LightInfluence = 0; motes.FaceCamera = true; motes.Segments = 1
    motes.Width0, motes.Width1 = 0.06, peer and 0.12 or 0.16
    motes.Parent = host
    local dir = (to - from).Unit
    local travel = H.TRAVEL -- (hitscan: the shot is there at once, nothing flies)
    local dur = travel + 0.34
    H.Animate(dur, function(t)
        local hk = math.clamp(t / travel, 0, 1)
        local head = from + dir * dist * hk
        a1.WorldPosition = head
        -- the core is gone right after it lands; the motes linger and melt (fade + thin) from the gun end first
        local after = math.max(0, t - travel) / (dur - travel)
        core.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7 + 0.3 * after), NumberSequenceKeypoint.new(1, math.clamp(0.1 + after * 1.6, 0, 1)) })
        motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, math.clamp(0.45 + after * 1.2, 0, 1)), NumberSequenceKeypoint.new(1, math.clamp(0.1 + after * 0.9, 0, 1)) })
        local w = 1 - after * 0.6
        motes.Width0, motes.Width1 = 0.06 * w, (peer and 0.12 or 0.16) * w
    end, function() host:Destroy() end)
end

-- ===== impact: tiny ice shards spike out of the surface and melt + a frost splash fading on it =====
Set.Impact = function(H: any, pos: Vector3, normal: Vector3?, peer: boolean?)
    if not H.Budget("PermafrostImpact", peer and 3 or 8, 0.5) then return end
    local n = (normal and normal.Magnitude > 0.1) and normal.Unit or V(0, 1, 0)
    local face = CFrame.lookAt(pos + n * 0.02, pos + n * 2) * CFrame.Angles(0, 0, math.random() * TAU)
    local p = H.FxPart({ Transparency = 1, Size = V(0.2, 0.2, 0.02), CFrame = face })
    local dec = Instance.new("Decal")
    dec.Texture = Tex("pf_splash", Tex("pf_emblem", "")); dec.Face = Enum.NormalId.Front; dec.Color3 = FROST; dec.Transparency = 0.15
    dec.Parent = p
    local att = H.Att(p, pos + n * 0.03)
    local em = H.Emitter(att, { Name = "PfImpactShards", Texture = Tex("pf_shard", H.SPARK), Color = { ICE, P.Sheet }, Size = { 0.09, 0.02 }, Life = { 0.22, 0.38 },
        Speed = { 2.5, 5.5 }, Spread = 38, Trans = { 0.05, 1 }, Light = 0.7, Drag = 5, Orient = Enum.ParticleOrientation.VelocityParallel })
    em.EmissionDirection = Enum.NormalId.Front
    em:Emit(peer and 4 or 6)
    H.Animate(0.6, function(t)
        local k = t / 0.6
        local e = 1 - (1 - math.min(1, k * 2.4)) ^ 3
        local s = 0.12 + 0.36 * e
        p.Size = V(s, s, 0.02)
        dec.Transparency = math.clamp(0.15 + math.max(0, k - 0.35) * 1.4, 0, 1)
    end, function() p:Destroy() end)
end

-- ===== FLASH FREEZE kill (FX roll-out 2026-10-14; was FROST BLOOM -- the body tinted pale ice + a fern decal: "a recolour").
-- ONE idea: the enemy is flash-frozen and shatters. A frost burst races across the real floor (a deep-blue fern ~6 studs
-- across), blue ice crystals race UP the body from the feet in 0.2 s, it hangs frozen for a beat (a glint runs up the ice),
-- then it SHATTERS: every crystal flies out as a tumbling shard, drops, skids and melts into the floor. The crystals grow on
-- the body's outline, tilted outward -- the crosshair line stays between them; the frozen body is see-through. 1.25 s.
-- Budget: full 10 crystals + <= 4 frozen pieces + floor + host = 16 parts, 22 shard sprites; low 5 crystals + floor, 10. =====
local function PfBody(pos: Vector3, H: any): ({ BasePart }, CFrame, Vector3)
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
        local list = {}
        for _, p in ipairs(best:GetDescendants()) do
            if p:IsA("BasePart") and p.Transparency < 0.6 and p.Size.Magnitude < 12 then table.insert(list, p) end
        end
        table.sort(list, function(a, b) return a.Size.Magnitude > b.Size.Magnitude end)
        for i = 1, math.min(4, #list) do out[i] = list[i] end
        local ok, cf, size = pcall(function() return best:GetBoundingBox() end)
        if ok and size.Magnitude < 20 then return out, cf, size end
    end
    return out, CFrame.new(pos - V(0, 1.4, 0)), V(1.8, 3.8, 1.2)
end
Set.Kill = function(H: any, pos: Vector3, low: boolean)
    local parts, bcf, bsz = PfBody(pos, H)
    local g = H.Ground(pos)
    local center = bcf.Position
    local top = math.max(center.Y + bsz.Y / 2, g.Y + 2.4)
    local hgt = top - g.Y
    local rad = math.clamp(math.max(bsz.X, bsz.Z) * 0.5, 0.7, 1.6)
    local model = Instance.new("Model")
    model.Name = "PermafrostKill"
    model.Parent = H.FxFolder()
    -- the floor burst: a deep-blue frost fern (dark on a bright floor, lit lume on a dark one: two decals)
    local disc = H.FxPart({ Transparency = 1, Size = V(0.5, 0.02, 0.5), CFrame = CFrame.new(g + V(0, 0.04, 0)) * CFrame.Angles(0, math.random() * TAU, 0) }, model)
    local dec = Instance.new("Decal")
    dec.Texture = Tex("pf_bloom", Tex("pf_emblem", "")); dec.Face = Enum.NormalId.Top; dec.Color3 = P.Sheet; dec.Transparency = 1
    dec.Parent = disc
    local dec2 = Instance.new("Decal")
    dec2.Texture = dec.Texture; dec2.Face = Enum.NormalId.Top; dec2.Color3 = LUME; dec2.Transparency = 1
    dec2.Parent = disc
    -- the frozen body: its biggest pieces, held, pale and see-through (they go with the shatter)
    local frozen = {}
    if not low then
        for _, src in ipairs(parts) do
            table.insert(frozen, H.FxPart({ Material = Enum.Material.SmoothPlastic, Size = src.Size * 1.04, CFrame = src.CFrame, Color = ICE:Lerp(FROST, 0.4),
                Transparency = 1, Shape = (src:IsA("Part") and src.Shape == Enum.PartType.Ball) and Enum.PartType.Ball or nil }, model))
        end
    end
    -- the crystals: wedge shards rooted on the body's left and right outline (in your view), feet -> head, tilted outward;
    -- three tones so they read on any floor: clear ice, deep sheet blue, and a lit lume core every third
    local N = low and 5 or 10
    local cam = workspace.CurrentCamera
    local rt = cam and cam.CFrame.RightVector or Vector3.xAxis
    rt = V(rt.X, 0, rt.Z)
    rt = (rt.Magnitude > 0.05) and rt.Unit or Vector3.xAxis
    local fwd = rt:Cross(Vector3.yAxis) -- (along your view, flat)
    local crystals = {}
    for i = 1, N do
        local side = (i % 2 == 0) and 1 or -1
        local f = math.floor((i - 1) / 2) / math.max(1, math.floor((N - 1) / 2))
        local top = (f >= 0.99)
        local root = V(center.X, g.Y + 0.05 + hgt * 0.78 * f, center.Z) + rt * side * rad * (top and 0.35 or (0.95 - 0.3 * f)) + fwd * ((math.random() - 0.5) * rad * 0.8)
        local outward = top and (rt * side * 0.4 + Vector3.yAxis).Unit or rt * side
        local len = top and (1.3 + math.random() * 0.4) or ((1.5 + 1.3 * (1 - f) + math.random() * 0.5) * (low and 1.2 or 1))
        local wid = 0.6 + 0.35 * (1 - f)
        local tilt = top and math.rad(8) or math.rad(22 + 26 * f + math.random() * 10)
        local axis = (Vector3.yAxis * math.cos(tilt) + V(outward.X, 0, outward.Z).Unit * math.sin(tilt)).Unit
        local tone = (i % 3 == 0) and "lit" or ((i % 3 == 1) and "ice" or "deep")
        local col = (tone == "lit") and LUME or ((tone == "ice") and ICE or P.Sheet)
        local p = H.FxPart({ Wedge = true, Material = (tone == "lit") and Enum.Material.Neon or Enum.Material.SmoothPlastic, Size = V(wid, 0.05, wid),
            Color = col, Transparency = 1, CFrame = CFrame.new(root) }, model)
        local ref = math.abs(axis:Dot(fwd)) < 0.95 and fwd or rt
        local rx = ref:Cross(axis).Unit
        local rot = CFrame.fromMatrix(Vector3.zero, rx, axis) * CFrame.Angles(0, math.random() * TAU, 0)
        table.insert(crystals, { P = p, Root = root, Axis = axis, Rot = rot, Len = len, Wid = wid, Start = 0.2 * f, Lit = (tone == "lit"), Col = col,
            Out = V(outward.X, 0, outward.Z).Magnitude > 0.05 and V(outward.X, 0, outward.Z).Unit or rt * side })
    end
    local host = H.FxPart({ Transparency = 1, Size = V(rad * 2, hgt * 0.8, rad * 2), CFrame = CFrame.new(V(center.X, g.Y + hgt * 0.45, center.Z)) }, model)
    local shards = H.Emitter(host, { Name = "PfShards", Texture = Tex("pf_shard", H.SPARK), Color = { ICE, P.Sheet }, Size = { 0.42, 0.2 }, Life = { 0.45, 0.75 },
        Speed = { 8, 14 }, Spread = 80, Dir = Enum.NormalId.Top, Accel = V(0, -40, 0), Drag = 0.8, Light = 0.3, Influence = 0.6,
        Spin = { -300, 300 }, Rot = { 0, 360 } })
    shards.Shape = Enum.ParticleEmitterShape.Box
    local BREAK = 0.45
    local broke = false
    H.Animate(low and 1.0 or 1.25, function(t, dt)
        -- the floor fern races out (0 -> 0.2) and melts (0.8 ->)
        local grow = 1 - (1 - math.min(1, t / 0.2)) ^ 3
        local s = 0.6 + 5.6 * grow
        disc.Size = V(s, 0.02, s)
        local melt = math.clamp((t - 0.8) / 0.4, 0, 1)
        dec.Transparency = 0.15 + 0.85 * math.max(melt, 1 - grow)
        dec2.Transparency = 0.55 + 0.45 * math.max(melt, 1 - grow)
        -- the frozen body (see-through, unlit) until the shatter
        for _, f in ipairs(frozen) do f.Transparency = (t < BREAK) and (1 - 0.6 * math.min(1, t / 0.12)) or 1 end
        if t >= BREAK and not broke then
            broke = true
            shards:Emit(low and 10 or 22)
            local inward = Vector3.zero
            if cam then
                local vp = cam:WorldToViewportPoint(center)
                inward = (vp.X < cam.ViewportSize.X / 2) and rt or -rt -- (toward the screen centre)
            end
            for _, c in ipairs(crystals) do
                local cf = c.P.CFrame
                c.Pos, c.R = cf.Position, cf - cf.Position
                c.Vel = c.Out * (3.5 + math.random() * 2.5) * ((c.Out:Dot(inward) > 0.5) and 0.3 or 1) + V(0, 4 + math.random() * 3, 0) -- (sideways in your view + up: never at you, barely toward the centre)
                c.Spin = V(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14
                c.Half = c.Wid * 0.5
            end
        end
        local step = math.clamp(dt, 0, 1 / 20)
        for i, c in ipairs(crystals) do
            local p = c.P
            if not broke then
                -- 1) GROW: from its root along its axis, feet first (0 -> 0.2 + 0.12)
                local k = 1 - (1 - math.clamp((t - c.Start) / 0.12, 0, 1)) ^ 2
                local L = math.max(0.05, c.Len * k)
                p.Size = V(c.Wid, L, c.Wid)
                p.CFrame = CFrame.new(c.Root + c.Axis * (L / 2)) * c.Rot
                p.Transparency = (k <= 0) and 1 or (c.Lit and 0.25 or 0.08)
                -- 2) HOLD: a glint runs up the ice (0.26 -> 0.42)
                local gl = math.exp(-((t - 0.26 - 0.16 * (i - 1) / N) / 0.03) ^ 2)
                p.Color = c.Col:Lerp(HOT, gl)
            else
                -- 3) SHATTER: shards fly out, fall, skid once, then melt into the floor
                if not c.Landed then
                    c.Vel += V(0, -42, 0) * step
                    c.Pos += c.Vel * step
                    c.R = c.R * CFrame.Angles(c.Spin.X * step, c.Spin.Y * step, c.Spin.Z * step)
                    if c.Pos.Y - c.Half <= g.Y then
                        c.Pos = V(c.Pos.X, g.Y + c.Half, c.Pos.Z)
                        if c.Vel.Y < -7 then c.Vel = V(c.Vel.X * 0.5, -c.Vel.Y * 0.25, c.Vel.Z * 0.5); c.Spin *= 0.4 else c.Landed = true end
                    end
                end
                local m = math.clamp((t - 0.9) / 0.3, 0, 1)
                p.CFrame = CFrame.new(c.Pos - V(0, m * c.Half * 2, 0)) * c.R
                p.Transparency = math.clamp((c.Lit and 0.25 or 0.08) + m, 0, 1)
                p.Color = c.Col
            end
        end
    end, function() model:Destroy() end)
end

-- ===== the CRYSTAL banner (lower right, beside the weapon card): a dark ice plate in which a six-arm frost star grows one
-- more arm per kill in the streak (1-5; the fifth completes the sixth arm and the star flares) =====
local banner
local NUMFONT = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold)
local WORDS = { "CHILL", "HOARFROST", "WHITEOUT", "GLACIAL", "FROZEN SOLID" } -- (skin_name_check: all clear; "RIME" alone matched "prime")
Set.Banner = function(H: any, streak: number)
    local gui, root = H.BannerRoot("Permafrost", Vector2.new(180, 90), "Side")
    if not root then return end
    local New = H.New
    if not banner or banner.Root ~= root then
        local plate = New("Frame", { BackgroundColor3 = P.Plate, BackgroundTransparency = 0.08, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, root,
            { New("UICorner", { CornerRadius = UDim.new(0, 6) }), New("UIStroke", { Color = FROST, Thickness = 1.5, Transparency = 0.35 }),
              New("UIGradient", { Color = ColorSequence.new(C(255, 255, 255), C(150, 170, 200)), Rotation = 90 }) })
        -- the star: six arms + two twig pairs each, drawn as rotated bars round a centre (our own six-arm design)
        local cx, cy, R = 46, 45, 34
        local arms = {}
        for i = 1, 6 do
            local holder = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(2 * R, 2 * R),
                Rotation = 60 * (i - 1), ZIndex = 3 }, root)
            local bars = {}
            -- (holder space: the arm runs up from the centre (R, R) to the top (R, 0); a bar from (x, y), length L, turned rot deg
            -- clockwise from straight up)
            local function bar(x, y, w, L, rot)
                local r = math.rad(rot)
                local b = New("Frame", { BorderSizePixel = 0, BackgroundColor3 = LUME, AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromOffset(x + math.sin(r) * L / 2, y - math.cos(r) * L / 2), Size = UDim2.fromOffset(w, L), Rotation = rot, ZIndex = 3 }, holder)
                table.insert(bars, b)
            end
            bar(R, R, 3, R, 0)
            for _, f in ipairs({ { 0.45, 0.42 }, { 0.72, 0.27 } }) do
                local y = R - R * f[1]
                bar(R, y, 2, R * f[2], -58)
                bar(R, y, 2, R * f[2], 58)
            end
            arms[i] = bars
        end
        local core = New("Frame", { BorderSizePixel = 0, BackgroundColor3 = HOT, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy),
            Size = UDim2.fromOffset(9, 9), Rotation = 45, ZIndex = 4 }, root)
        local glow = New("ImageLabel", { BackgroundTransparency = 1, Image = H.Art.Glow, ImageColor3 = LUME, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(96, 96), ImageTransparency = 0.8, ZIndex = 2 }, root)
        local num = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(92, 30), Size = UDim2.fromOffset(84, 30),
            FontFace = NUMFONT, TextSize = 28, TextColor3 = P.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 3 }, root)
        num:SetAttribute("KeepFont", true)
        local word = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(92, 60), Size = UDim2.fromOffset(84, 18),
            FontFace = NUMFONT, TextSize = 13, TextColor3 = FROST, TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextScaled = false, ZIndex = 3 }, root)
        word:SetAttribute("KeepFont", true)
        banner = { Root = root, Plate = plate, Arms = arms, Core = core, Glow = glow, Num = num, Word = word, Token = 0 }
    end
    local b = banner
    b.Token += 1
    local token = b.Token
    local st = math.clamp(streak or 1, 1, 5)
    root.Visible = true
    b.Plate.BackgroundTransparency = 0.08
    b.Num.TextTransparency = 0
    b.Word.TextTransparency = 0
    b.Num.Text = "x" .. st
    b.Word.Text = WORDS[st]
    b.Num.TextColor3 = (st >= 5) and LUME or P.Text
    b.Core.BackgroundTransparency = 0
    local lit = (st >= 5) and 6 or st
    for i, bars in ipairs(b.Arms) do
        for _, bar in ipairs(bars) do
            bar.BackgroundTransparency = (i <= lit) and 0 or 0.82
            bar.BackgroundColor3 = (i <= lit) and LUME or FROST
        end
    end
    -- the newest arm grows out from the centre (and at 5 the sixth with it), the star flares
    local new = (st >= 5) and { 5, 6 } or { st }
    H.Animate(0.32, function(t)
        if b.Token ~= token then return end
        local k = 1 - (1 - t / 0.32) ^ 3
        for _, i in ipairs(new) do
            for j, bar in ipairs(b.Arms[i]) do
                bar.BackgroundTransparency = 1 - math.clamp(k * 1.6 - (j - 1) * 0.12, 0, 1)
                bar.BackgroundColor3 = HOT:Lerp(LUME, k)
            end
        end
        b.Glow.ImageTransparency = 0.8 - 0.4 * math.sin(k * math.pi) * (st >= 5 and 1.4 or 0.7)
    end)
    task.delay(1.6, function()
        if b.Token ~= token then return end
        local ti = TweenInfo.new(0.3)
        H.TweenService:Create(b.Plate, ti, { BackgroundTransparency = 1 }):Play()
        H.TweenService:Create(b.Num, ti, { TextTransparency = 1 }):Play()
        H.TweenService:Create(b.Word, ti, { TextTransparency = 1 }):Play()
        H.TweenService:Create(b.Core, ti, { BackgroundTransparency = 1 }):Play()
        H.TweenService:Create(b.Glow, ti, { ImageTransparency = 1 }):Play()
        for _, bars in ipairs(b.Arms) do for _, bar in ipairs(bars) do H.TweenService:Create(bar, ti, { BackgroundTransparency = 1 }):Play() end end
        task.delay(0.32, function() if b.Token == token then root.Visible = false end end)
    end)
end

-- ===== the RIME SABRE (melee, Sword class): WeaponAssets.MeleeModels.Permafrost -- a slightly curved sabre of clear
-- glacial ice over a frosted steel spine, a cyan core line down the blade, a frost-rimed steel guard, a wrapped grip with
-- a faceted ice pommel. Frost climbs the blade while you inspect it. =====
Set.Melee = {
    Skin = { Name = "Rime Sabre", Price = 449, ProductId = 0,
        Desc = "A slightly curved sabre of clear glacial ice over a frosted steel spine, a cold cyan core running down the blade, a frost-rimed steel guard and a faceted ice pommel. Frost climbs the blade while you turn it in the light. Every kill brings the FROST BLOOM." },
    Rig = { Class = "Sword", BladeLen = 1.25 },
    FlatBlade = true,
    -- (the frost climb + the tinkle ride the class inspect: Drive reads the anim time, OnEvent "Flip" plays Sounds.Tinkle)
    Build = function(m: Model, o: any, H: any)
        local parts = H.CloneModel(m, "MeleeModels", "Permafrost", VAR, { [1] = LUME })
        for _, p in pairs(parts) do
            if p:IsA("BasePart") and p:GetAttribute("IceClear") then p.Color = ICE; p.Reflectance = 0; p.CastShadow = false end
        end
        local blade = parts.Blade
        if not blade then return end
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Name, a1.Name = "TrailBase", "TrailTip"
        a0.Position = blade.CFrame:PointToObjectSpace(V(0.02, 0.45, 0))
        a1.Position = blade.CFrame:PointToObjectSpace(V(0.1, 1.3, 0))
        a0.Parent, a1.Parent = blade, blade
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Color = ColorSequence.new(HOT, LUME)
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
        tr.LightEmission = 0.7; tr.LightInfluence = 0
        tr.Lifetime = 0.14; tr.MinLength = 0.02; tr.FaceCamera = true
        tr.Enabled = false
        tr:SetAttribute("SwingTrail", true)
        tr.Parent = blade
    end,
}

-- ===== arms: FROSTBITE GLOVES + RIME VAMBRACES (sculpted mesh pieces, WeaponAssets.ArmsModels.Permafrost) =====
-- Glove: a navy insulated glove with frost-rimed fingertips and knuckles; ONE effect: a tiny ice crystal on the back of the
-- hand slowly grows a frost fern and resets (~8 s), flaring on a kill. Sleeve: a navy cloth sleeve under a sculpted frost-
-- crusted steel vambrace with ice crystals along its edge.
Set.Glove = function(K: any)
    local V3 = K.V
    return {
        Id = "FrostbiteGloves", Name = "Frostbite Gloves", Price = 449,
        Desc = "Navy insulated gloves with frost-rimed knuckles and fingertips. On the back of the hand a tiny ice crystal slowly grows a frost fern, melts back and grows again; it flares with every kill. Part of the Permafrost set.",
        Base = { Color = P.Deep, Material = Enum.Material.SmoothPlastic },
        Parts = {
            { Mesh = "Permafrost/Knuckle", MeshV = VAR, Size = V3(0.9, 0.14, 0.34), Off = V3(0, 0.53, -0.22), Seat = true },
            { Mesh = "Permafrost/Cuff", MeshV = VAR, Size = V3(1.12, 1.12, 0.18), Off = V3(0, 0, 0.42) },
            -- (flat pieces built in their own X / Y with the thickness along Z: Rot 90 lays them on the back of the hand)
            { Mesh = "Permafrost/Crystal", MeshV = VAR, Size = V3(0.17, 0.17, 0.06), Off = V3(0, 0.58, 0.08), Rot = V3(90, 0, 0), Seat = true },
            -- the ONE effect: a frost star grows slowly out of the crystal, melts back and grows again (~8 s); flares on a kill
            { Mesh = "Permafrost/Fern", MeshV = VAR, Size = V3(0.24, 0.24, 0.012), Off = V3(0, 0.616, 0.08), Rot = V3(90, 0, 0), Seat = true,
              Glow = true, Color = LUME, Anim = "Grow", Period = 8, Dur = 6.5, MinScale = 0.12, BurstOn = "Kill" },
        },
    }
end
Set.Sleeve = function(K: any)
    local V3 = K.V
    return {
        Id = "RimeVambraces", Name = "Rime Vambraces", Price = 299,
        Desc = "A navy cloth sleeve under a sculpted frost-steel vambrace, its edges crusted with hoar frost and a row of small ice crystals. Part of the Permafrost set.",
        Base = { Color = P.Deep:Lerp(C(0, 0, 0), 0.1), Material = Enum.Material.SmoothPlastic },
        Parts = {
            { Mesh = "Permafrost/Vambrace", MeshV = VAR, Size = V3(1.14, 1.14, 0.62), Off = V3(0, 0, -0.1) },
            { Mesh = "Permafrost/Crystals", MeshV = VAR, Size = V3(0.28, 0.16, 0.5), Off = V3(0, 0.62, -0.1), Seat = true },
        },
    }
end

-- ===== health bar: clear blue ice frosted at the edges, a cyan fill; a hit spreads cracks from the hit point that
-- refreeze =====
Set.Bar = { Id = "Permafrost", Name = "Permafrost", Price = 149,
    Desc = "A bar of clear blue ice with a cold cyan fill. Lost health SHATTERS -- the piece breaks into ice shards that drop away -- and cracks spread from the hit and freeze over again. Part of the Permafrost set.",
    Look = "Ink", FillColor = LUME, Tex = "tex_pf_bar", TexColor = LUME:Lerp(HOT, 0.3), TexSpeed = 0, ChipMotion = "Shatter", Chip = HOT,
    Back = C(8, 16, 30), Glow = LUME, Segments = 5, Decor = { "FrostEdge", "Cracks" } }
Set.BarDecor = {
    -- (BARS v2) a rime edge along the top of the fill: a thin pale line that thickens in two crystals near the fill's end
    FrostEdge = function(ctx: any, K: any)
        local f = K.Fader()
        local rim = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = HOT, AnchorPoint = Vector2.new(0, 0), ZIndex = 11 }, ctx.Holder)
        f.Add(rim, 0.25, "BackgroundTransparency")
        local tip = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = HOT, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, ZIndex = 12 }, ctx.Holder)
        K.New("UIStroke", { Color = P.Ink, Thickness = 1 }, tip)
        f.Add(tip, 0, "BackgroundTransparency")
        return function(now, dt, alpha, info)
            local x = ctx.W * math.clamp(info.Shown, 0, 1)
            rim.Size = UDim2.fromOffset(math.max(0, x - 2), math.max(1, math.floor(ctx.H * 0.18)))
            local s = math.max(3, math.floor(ctx.H * 0.55))
            tip.Size = UDim2.fromOffset(s, s)
            tip.Position = UDim2.fromOffset(x, 1)
            f.Apply(alpha)
        end
    end,
    IceFill = function(ctx: any, K: any)
        for _, c in ipairs(ctx.Inner:GetChildren()) do if c:IsA("ImageLabel") then c.ImageColor3 = LUME end end
        return function() end
    end,
    Cracks = function(ctx: any, K: any)
        local f = K.Fader()
        local crack = f.Add(K.Img(Tex("pf_crack", Tex("pf_emblem", "")), { AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = HOT, ZIndex = 11 }, ctx.Holder), 1)
        local k = 1
        local lastHit = 0
        local x = 0.5
        return function(now, dt, alpha, info)
            if (info.Hit or 0) > lastHit + 0.05 then k = 0; x = math.clamp(info.Shown, 0.03, 1) end
            lastHit = info.Hit or 0
            k = math.min(1, k + dt / 0.6)
            -- the cracks spread out fast, then freeze over (fade) slowly
            local s = ctx.H * (1.4 + 1.2 * (1 - (1 - math.min(1, k * 3)) ^ 2))
            crack.Size = UDim2.fromOffset(s * 1.8, s)
            crack.Position = UDim2.fromOffset(ctx.W * x, ctx.H / 2)
            crack.ImageTransparency = 1 - alpha * (1 - k) * 0.85
        end
    end,
}

local P1 = PALETTES[1]
-- ===== UI theme v2 (FX roll-out 2026-10-14; v1 = the shared template: ice texture + 4 corner sprites + watermark + snow
-- ambient + the shared Implode). Its own pieces in the icon look (flat lit faces, one hard facet, ink edges): ICE SHARD
-- clusters growing out of the two bottom corners (faceted blue shards, one glint running up a shard now and
-- then), ICICLES hanging under every title (one lets a drop fall now and then), and windows open with FROST: rime creeps in
-- from all four edges and the shards shoot out of the corners, then the rime melts back. Colours from the theme table. =====
local function PfFacet(ctx, o, lit, shade, th)
    local g = Instance.new("UIGradient")
    g.Color = ctx.UIStyle.Facet(lit, shade)
    g.Rotation = 90
    g.Parent = o
    if th then ctx.UIStyle.InkEdge(th).Parent = o end
    return g
end
-- a cluster of shards from corner (ax, ay): long thin faceted diamonds fanning out of the corner
local SHARDS = { { 0, 1.0, 0.26 }, { 22, 0.72, 0.22 }, { -22, 0.62, 0.2 }, { 40, 0.45, 0.18 }, { -40, 0.4, 0.16 } } -- (angle off the diagonal, length, width)
local function Cluster(ctx, parent, ax, ay, len)
    local t = ctx.Theme
    local out = {}
    local diag = math.deg(math.atan2((ay == 0) and 1 or -1, (ax == 0) and 1 or -1)) -- (screen angle pointing into the window)
    for i, sh in ipairs(SHARDS) do
        local L, W = math.floor(len * sh[2]), math.max(5, math.floor(len * sh[3]))
        local holder = Instance.new("Frame")
        holder.Name = "PfShard"; holder.BackgroundTransparency = 1; holder.Size = UDim2.fromOffset(0, 0)
        holder.Position = UDim2.new(ax, (ax == 0) and 3 or -3, ay, (ay == 0) and 3 or -3); holder.Rotation = diag + sh[1] - 90
        holder.ZIndex = parent.ZIndex + 1; holder.Parent = parent
        -- (a shard = a long rectangle with a 45-deg diamond tip: two frames sharing the facet)
        local body = Instance.new("Frame")
        body.BorderSizePixel = 0; body.BackgroundColor3 = Color3.new(1, 1, 1); body.AnchorPoint = Vector2.new(0.5, 0)
        body.Size = UDim2.fromOffset(W, L); body.Position = UDim2.fromOffset(0, 0); body.ZIndex = holder.ZIndex; body.Parent = holder
        local g = PfFacet(ctx, body, t.IceLit, t.IceShade, 2)
        g.Rotation = 0
        local tip = Instance.new("Frame")
        tip.BorderSizePixel = 0; tip.BackgroundColor3 = Color3.new(1, 1, 1); tip.AnchorPoint = Vector2.new(0.5, 0.5); tip.Rotation = 45
        tip.Size = UDim2.fromOffset(W * 0.71, W * 0.71); tip.Position = UDim2.fromOffset(0, L); tip.ZIndex = holder.ZIndex; tip.Parent = holder
        local g2 = PfFacet(ctx, tip, t.IceLit, t.IceShade, 2)
        g2.Rotation = -45
        out[i] = { H = holder, Body = body, Tip = tip, G = g, G2 = g2, L = L }
    end
    return out
end
local function PfDeco(ctx)
    local t = ctx.Theme
    if ctx.Kind ~= "Window" then return nil end -- (HUD panels stay clean)
    local host = ctx.Root or ctx.Surface
    local f = Instance.new("Frame")
    f.Name = "PfOverlay"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 20; f.Active = false; f.ClipsDescendants = true
    f:SetAttribute("NoSkin", true); f:SetAttribute("Skinned", true)
    f.Parent = host
    local abs = host.AbsoluteSize
    local small = math.min(abs.X, abs.Y) < 260
    local len = math.clamp(math.floor(math.min(abs.X, abs.Y) * 0.12), small and 16 or 30, small and 28 or 56)
    local shards = {}
    -- (bottom corners: at the top they covered the window title / close button -- seen in play)
    for _, c in ipairs({ { 0, 1 }, { 1, 1 } }) do
        for _, s in ipairs(Cluster(ctx, f, c[1], c[2], len)) do table.insert(shards, s) end
    end
    -- a glint runs up one shard every 4-7 s (its facet flicks to the hot edge colour and back)
    local nextGlint, glint, glintAt = os.clock() + 2, nil, -9
    return function(now, dt)
        if now >= nextGlint then
            nextGlint = now + 4 + math.random() * 3
            glint, glintAt = shards[math.random(1, #shards)], now
        end
        if glint then
            local k = (now - glintAt) / 0.4
            if k >= 1 then
                glint.G.Color = ctx.UIStyle.Facet(t.IceLit, t.IceShade); glint = nil
            else
                glint.G.Color = ctx.UIStyle.Facet(t.IceLit:Lerp(t.Rime, math.sin(k * math.pi)), t.IceShade)
            end
        end
    end, { f }
end
local function PfOpen(ctx)
    -- FROST: rime creeps in from all four edges (0.22 s) while the shards shoot out of their corners, then melts back (0.35 s)
    local t = ctx.Theme
    local f = (ctx.Root and ctx.Root:FindFirstChild("PfOverlay")) or ctx.Frame
    local edges = {}
    for i, e in ipairs({ { 0, 0, 1, 0, 90 }, { 0, 1, 1, 0, -90 }, { 0, 0, 0, 1, 0 }, { 1, 0, 0, 1, 180 } }) do
        local r = Instance.new("Frame")
        r.Name = "PfRime"; r.BorderSizePixel = 0; r.BackgroundColor3 = t.Rime; r.ZIndex = f.ZIndex + 4
        r.AnchorPoint = Vector2.new(e[1], e[2]); r.Position = UDim2.fromScale(e[1], e[2])
        local horiz = e[3] == 1
        r.Size = horiz and UDim2.new(1, 0, 0, 0) or UDim2.new(0, 0, 1, 0)
        local g = Instance.new("UIGradient"); g.Rotation = e[5]
        g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.35, 0.55), NumberSequenceKeypoint.new(1, 1) })
        g.Parent = r
        r.Parent = f
        edges[i] = { F = r, Horiz = horiz }
    end
    local shards = {}
    for _, d in ipairs(f:GetChildren()) do if d.Name == "PfShard" then table.insert(shards, d) end end
    local depth = math.max(18, math.min(f.AbsoluteSize.X, f.AbsoluteSize.Y) * 0.16)
    local t0 = os.clock()
    local conn
    conn = game:GetService("RunService").RenderStepped:Connect(function()
        local a = os.clock() - t0
        local creep = 1 - (1 - math.min(1, a / 0.22)) ^ 2
        local melt = math.clamp((a - 0.22) / 0.35, 0, 1)
        for _, e in ipairs(edges) do
            local d = depth * creep * (1 - 0.4 * melt)
            e.F.Size = e.Horiz and UDim2.new(1, 0, 0, d) or UDim2.new(0, d, 1, 0)
            e.F.BackgroundTransparency = melt
        end
        for _, s in ipairs(shards) do
            local sc = s:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
            sc.Scale = 0.2 + 0.8 * creep + 0.1 * math.sin(math.min(1, a / 0.3) * math.pi)
            sc.Parent = s
        end
        if a >= 0.57 then
            conn:Disconnect()
            for _, e in ipairs(edges) do e.F:Destroy() end
            for _, s in ipairs(shards) do local sc = s:FindFirstChildOfClass("UIScale"); if sc then sc.Scale = 1 end end
        end
    end)
end
local function PfTitle(ctx)
    -- ICICLES hanging from the title bar's top edge, in the clear middle of the bar (the title text is left, the emblem and
    -- close button right): six tapered pale-blue spikes of different lengths
    local bar, t = ctx.Title, ctx.Theme
    local row = Instance.new("Frame")
    row.Name = "PfIcicles"; row.BackgroundTransparency = 1; row.AnchorPoint = Vector2.new(0, 0); row.Position = UDim2.new(0.5, 0, 0, 0)
    row.Size = UDim2.new(0.22, 0, 0, 14); row.ZIndex = bar.ZIndex + 2; row.Parent = bar
    local lens = { 11, 6, 14, 7, 10, 5 }
    for i, L in ipairs(lens) do
        local ic = Instance.new("Frame")
        ic.BorderSizePixel = 0; ic.BackgroundColor3 = t.IceLit; ic.AnchorPoint = Vector2.new(0.5, 0)
        ic.Size = UDim2.fromOffset(4, L); ic.Position = UDim2.fromScale((i - 0.5) / #lens, 0); ic.ZIndex = row.ZIndex; ic.Parent = row
        local g = Instance.new("UIGradient"); g.Rotation = 90
        g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 0.9) })
        g.Color = ColorSequence.new(t.Rime, t.IceLit); g.Parent = ic
    end
    return { row }
end
-- numbers v3 (SKIN UI 2026-10-29, owner: numbers "unique to the skin and the colorways you have equipped"): FLASH FROZEN. A
-- crisp face (Ubuntu; Sarpanch is Ferroflux's) that snaps in small and crystallises to size, rises slowly and straight and frosts over as it
-- ages (its colour creeps to this colourway's frost). CRIT = the set's six-arm FROST STAR grows behind the digits arm by arm
-- in the fern light (the kill banner grows one arm per kill); WEAK SPOT = a RIME edge: the outline turns to frost; a KILL =
-- the digits freeze solid white and CRACK: two ice shards split apart either side while the star flares. Every colour is
-- this copy's palette (P = the colourway: Glacier, Black Ice, Meltwater, Ember Ice).
local function PfMotion(e, age, pa, life)
    local snap = math.min(1, age / 0.07)
    local scale = 0.8 + 0.2 * snap + ((pa < 0.05 and age > 0.08) and 0.05 or 0)
    local up = 0.9 * (1 - (1 - math.min(1, age / life)) ^ 2)
    local dy = (pa < 0.06 and age > 0.08) and ((math.floor(pa * 120) % 2 == 0) and 1 or -1) or 0 -- (a cold 1 px shiver on a merge)
    if e.Killed and e.KillAt then -- (frozen solid: it stops rising the moment it dies)
        local kt = os.clock() - e.KillAt
        scale += 0.06 * math.exp(-kt * 10)
        dy += (kt < 0.1) and ((math.floor(kt * 140) % 2 == 0) and 2 or -2) or 0
    end
    return up, 0, scale, dy, 0, 0
end
local PF_ARM = 3 -- (a six-arm star = three crossing bars)
local function PfAccent(e)
    local f = Instance.new("Frame")
    f.Name = "PfFrost"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 0
    local star = Instance.new("Frame")
    star.Name = "Star"; star.BackgroundTransparency = 1; star.AnchorPoint = Vector2.new(0.5, 0.5); star.Position = UDim2.fromScale(0.5, 0.5)
    star.Size = UDim2.fromOffset(2, 2); star.ZIndex = 0; star.Parent = f
    for i = 1, PF_ARM do
        local arm = Instance.new("Frame")
        arm.Name = "Arm" .. i; arm.BorderSizePixel = 0; arm.AnchorPoint = Vector2.new(0.5, 0.5); arm.Position = UDim2.fromScale(0.5, 0.5)
        arm.Rotation = (i - 1) * 60 + 90; arm.ZIndex = 0; arm.Parent = star
        -- the fern barbs on each arm: two short ticks near both tips
        for j = 1, 4 do
            local b = Instance.new("Frame")
            b.Name = "Barb"; b.BorderSizePixel = 0; b.AnchorPoint = Vector2.new(0.5, 0.5); b.Size = UDim2.fromOffset(6, 2)
            b.Position = UDim2.new((j <= 2) and 0.16 or 0.84, 0, 0.5, ((j % 2 == 0) and -3 or 3))
            b.Rotation = ((j % 2 == 0) and -1 or 1) * ((j <= 2) and -50 or 50); b.ZIndex = 0; b.Parent = arm
        end
    end
    for i = 1, 2 do
        local d = Instance.new("Frame")
        d.Name = "S" .. i; d.BorderSizePixel = 0; d.AnchorPoint = Vector2.new(0.5, 0.5); d.Size = UDim2.fromOffset(6, 14)
        d.ZIndex = 2; d.Parent = f
        local st = Instance.new("UIStroke"); st.Thickness = 1.5; st.Color = P.Ink; st.Parent = d
        local g = Instance.new("UIGradient"); g.Rotation = 90
        g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.6, 0.6, 0.6)); g.Parent = d
    end
    return f
end
local function PfAccentStep(e, f, age, pa, alpha)
    local tb = e.Label.TextBounds
    local life = e.Expire - e.Born
    local now = os.clock()
    local kt = (e.Killed and e.KillAt) and (now - e.KillAt) or nil
    if not e.Dot then
        -- the digits frost over as they rise; a kill freezes them white at once
        local frost = kt and math.min(1, kt / 0.08) or math.clamp(age / math.max(0.3, life), 0, 1) * 0.7
        e.Label.TextColor3 = e.Color:Lerp(kt and P.Hot or P.Frost, frost)
        -- the rime edge on a weak-spot hit: the outline is frost, not ink
        if e.Weak then e.Stroke.Color = P.Frost; e.Stroke.Thickness = 2.5 end
    end
    -- the frost star: grows out arm by arm behind a crit (and flares on a kill)
    local star = f:FindFirstChild("Star")
    if star then
        local on = (e.Crit or e.Killed) and not e.Dot
        star.Visible = on
        if on then
            local L = math.max(tb.X, tb.Y) * 1.25 + 14
            local flare = kt and math.exp(-kt * 5) or 0
            star.Rotation = age * 12
            for i = 1, PF_ARM do
                local arm = star:FindFirstChild("Arm" .. i)
                if arm then
                    local k = math.clamp((age - (i - 1) * 0.05) / 0.07, 0, 1)
                    local len = math.floor(L * (1 - (1 - k) ^ 2) * (1 + 0.3 * flare))
                    arm.Size = UDim2.fromOffset(len, 2)
                    arm.BackgroundColor3 = P.Lume:Lerp(P.Hot, flare)
                    local tr = math.clamp(alpha + 0.25 - 0.2 * flare, 0, 1)
                    arm.BackgroundTransparency = tr
                    for _, b in ipairs(arm:GetChildren()) do
                        b.BackgroundColor3 = arm.BackgroundColor3
                        b.BackgroundTransparency = (k < 1) and 1 or tr
                    end
                end
            end
        end
    end
    -- the crack on a kill: two shards either side split apart and fall away
    for i = 1, 2 do
        local d = f:FindFirstChild("S" .. i)
        if d then
            d.Visible = kt ~= nil and not e.Dot
            if kt then
                local k = math.clamp(kt / 0.5, 0, 1)
                local side = (i == 1) and -1 or 1
                d.Position = UDim2.new(0.5, side * (tb.X / 2 + 6 + 16 * k), 0.5, 10 * k * k)
                d.Rotation = side * (18 + 50 * k)
                d.BackgroundColor3 = P.Frost
                local tr = math.clamp(alpha + k * 0.5, 0, 1)
                d.BackgroundTransparency = tr
                d:FindFirstChildOfClass("UIStroke").Transparency = tr
            end
        end
    end
end
-- ===== UI THEME v4 (SKIN UI THEMES, roll-out 2026-10-29): the clean language in this colourway's colours (UITheme Clean)
-- + two touches of a glacier. Hooks read only the palette they get (a colourway copy shares these functions):
--   TAB MARK  a frosted bar (rime white on top, ice under it) with three ICICLES hanging off it -- on the top bar the long one
--             slowly grows a drip at its point
--   FIELD     FROST FERNS: dendritic ice crystals grown out of both lower corners of the screen (stems, barbs and sub-barbs, the
--             gun's fern light language), a glint of the fern light crawling up the main stem from its root now and then, and a
--             six-arm frost star at the tip of the longest frond that turns very slowly
local PF_CLEAN = {
    Field = P.Dark:Lerp(P.Deep, 0.3), Surface = P.Deep:Lerp(P.Plate, 0.5), Raised = P.Plate:Lerp(P.Body, 0.6), Hover = P.Body:Lerp(P.Sheet, 0.35),
    Well = P.Ink, Line = P.Mid:Lerp(P.Deep, 0.45), Tip = P.Deep:Lerp(P.Ink, 0.3),
    Accent = P.Lume, Mark = P.Frost, Hair = P.Ice,
    Text = P.Text, Sub = P.Frost:Lerp(P.Mid, 0.35), Muted = P.Mid:Lerp(P.Frost, 0.3), Ink = P.Ink,
    Rime = P.Frost, Ice = P.Ice, Glint = P.Hot, Fern = P.Lume,
}
-- (HudThemes.Variant keeps a colourway copy's Clean colour only where it DIFFERS from colourway 1's -- an equal one goes through
-- the hue map and can come out wrong: nudge every copy colour a hair so this palette wins)
if VAR ~= 1 then for k, v in pairs(PF_CLEAN) do if typeof(v) == "Color3" then PF_CLEAN[k] = v:Lerp(Color3.new(0, 0, 0), 0.003) end end end
local function PfLine(parent, a, b, th, col, z, name)
    local d = b - a
    local f = Instance.new("Frame")
    f.Name = name or "PfLine"; f.BorderSizePixel = 0; f.BackgroundColor3 = col; f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Size = UDim2.fromOffset(math.max(1, d.Magnitude), th); f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
    f.Rotation = math.deg(math.atan2(d.Y, d.X)); f.ZIndex = z; f.Parent = parent
    return f
end
PF_CLEAN.TabMark = function(mark, Q)
    -- (rime on top, ice under it: a gradient over the mark's own frost colour)
    local g = Instance.new("UIGradient")
    g.Rotation = 90
    g.Color = ColorSequence.new(Color3.new(1, 1, 1), Q.Ice:Lerp(Color3.new(1, 1, 1), 0.3))
    g.Parent = mark
    -- three icicles hanging off it (anchored left, inside the mark's width: tab buttons size themselves to their children)
    local made = { g }
    for i, ic in ipairs({ { 0, 3, 5 }, { 0.5, -1, 3 }, { 1, -7, 7 } }) do
        local c = Instance.new("Frame")
        c.Name = (i == 3) and "PfDrip" or "PfIcicle"; c.BorderSizePixel = 0; c.BackgroundColor3 = Q.Rime; c.AnchorPoint = Vector2.new(0, 0)
        c.Position = UDim2.new(ic[1], ic[2], 1, 0); c.Size = UDim2.fromOffset(2, ic[3]); c.ZIndex = mark.ZIndex; c.Parent = mark
        local t = Instance.new("UIGradient"); t.Rotation = 90
        t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.85) }); t.Parent = c
        table.insert(made, c)
    end
    return made
end
PF_CLEAN.Sig = function(ctx)
    local Q, f = ctx.P, ctx.Frame
    local cam = workspace.CurrentCamera
    local vh = (cam and cam.ViewportSize.Y or 800)
    local R = ctx.Phone and math.clamp(math.floor(vh * 0.14), 60, 110) or math.clamp(math.floor(vh * 0.26), 96, 230)
    local rng = Random.new(29)
    local mains = {}
    local function Fern(holder, o, ang, len, depth, list)
        -- one dendrite: a stem with barbs leaning out toward its tip, the barbs with sub-barbs
        local tip = o + Vector2.new(math.cos(ang), math.sin(ang)) * len
        local th = (depth == 0) and 2 or 1
        local ln = PfLine(holder, o, tip, th, Q.Rime, 0, "PfFern")
        ln.BackgroundTransparency = ({ 0.56, 0.68, 0.8 })[depth + 1]
        if list then table.insert(list, { o, tip }) end
        if depth >= 2 then return tip end
        local n = (depth == 0) and 4 or 2
        for i = 1, n do
            local at = o + (tip - o) * (0.18 + 0.72 * (i - 0.5) / n)
            local bl = len * ((depth == 0) and 0.34 or 0.4) * (1 - 0.55 * (i - 1) / n) * (0.85 + rng:NextNumber() * 0.3)
            for _, s in ipairs({ -1, 1 }) do Fern(holder, at, ang + s * math.rad(58), bl, depth + 1, nil) end
        end
        return tip
    end
    -- (built the first time this field shows -- the Sig runs for every menu field at once, and ~250 frost lines a field add
    -- up; built unparented and marked UITKeep before it goes in, so the palette walk never touches it)
    local glint, star, arms, seg
    local function Build()
    local tipMain
    local holders = {}
    for side = 0, 1 do
        local holder = Instance.new("Frame")
        holder.Name = "PfCorner"; holder.BackgroundTransparency = 1; holder.Size = UDim2.fromOffset(R + 10, R + 10)
        holder.AnchorPoint = Vector2.new(side, 1); holder.Position = UDim2.fromScale(side, 1); holder.ZIndex = 0
        holders[#holders + 1] = holder
        local o = Vector2.new(side == 0 and 0 or (R + 10), R + 10)
        local dir = (side == 0) and 1 or -1
        -- three fronds fan out of the corner (the left corner's middle one is the main stem the glint climbs)
        for i, a in ipairs({ -12, -36, -64 }) do
            local ang = math.rad(a)
            local v = Vector2.new(math.cos(ang) * dir, math.sin(ang))
            local len = R * ({ 0.62, 1.0, 0.7 })[i] * ((side == 1) and 0.8 or 1)
            local list = (side == 0 and i == 2) and mains or nil
            local tip = Fern(holder, o, math.atan2(v.Y, v.X), len, 0, list)
            if side == 0 and i == 2 then tipMain = { holder, tip } end
        end
    end
    -- the glint (one bright diamond) and the frost star at the main frond's tip
    local holder, tip = tipMain[1], tipMain[2]
    glint = Instance.new("Frame")
    glint.Name = "PfGlint"; glint.BorderSizePixel = 0; glint.BackgroundColor3 = Q.Glint; glint.AnchorPoint = Vector2.new(0.5, 0.5)
    glint.Size = UDim2.fromOffset(5, 5); glint.Rotation = 45; glint.ZIndex = 1; glint.BackgroundTransparency = 1; glint.Parent = holder
    star = Instance.new("Frame")
    star.Name = "PfStar"; star.BackgroundTransparency = 1; star.AnchorPoint = Vector2.new(0.5, 0.5); star.Size = UDim2.fromOffset(2, 2)
    star.Position = UDim2.fromOffset(tip.X, tip.Y); star.ZIndex = 1; star.Parent = holder
    arms = {}
    for i = 1, 3 do
        local arm = Instance.new("Frame")
        arms[i] = arm
        arm.BorderSizePixel = 0; arm.BackgroundColor3 = Q.Fern; arm.BackgroundTransparency = 0.3; arm.AnchorPoint = Vector2.new(0.5, 0.5)
        arm.Position = UDim2.fromScale(0.5, 0.5); arm.Size = UDim2.fromOffset(18, 2); arm.Rotation = (i - 1) * 60; arm.ZIndex = 1; arm.Parent = star
    end
    seg = mains[1]
    for _, h in ipairs(holders) do
        h:SetAttribute("UITKeep", true)
        for _, d in ipairs(h:GetDescendants()) do d:SetAttribute("UITKeep", true) end
        h.Parent = f
    end
    end
    local seed = math.random() * 9
    return function(now, _dt)
        if not glint then Build() end
        -- every ~9 s the fern light crawls up the main stem from its root to the star, which flares as it arrives
        local k = ((now + seed) % 9) / 1.6
        if k < 1 and seg then
            local p = seg[1] + (seg[2] - seg[1]) * (k * k * (3 - 2 * k))
            glint.Position = UDim2.fromOffset(p.X, p.Y)
            glint.BackgroundTransparency = 0.1 + 0.6 * math.abs(k - 0.5)
        elseif glint.BackgroundTransparency < 1 then
            glint.BackgroundTransparency = 1
        end
        local fl = (k >= 1 and k < 1.5) and (1 - (k - 1) / 0.5) or 0
        star.Rotation = now * 4
        if fl > 0 or arms[1].Size.X.Offset ~= 18 then
            for _, a in ipairs(arms) do a.Size = UDim2.fromOffset(math.floor(18 + 14 * fl), 2); a.BackgroundTransparency = 0.3 - 0.25 * fl end
        end
        -- the long icicle on the selected tab grows a drip at its point, then lets it go
        local d = ((now + seed) % 5) / 5
        for _, m in ipairs(ctx.Marks()) do
            local ic = m.Visible and m:FindFirstChild("PfDrip")
            if ic then ic.Size = UDim2.fromOffset(2, 7 + math.floor(4 * d * d)) end
        end
    end, nil
end
local function PG(top, bottom) return { Top = top, Bottom = bottom } end
Set.Theme = { Name = "Permafrost", Desc = "Menus cut from glacier ice: clusters of faceted ice shards grow out of the two lower corners and a glint runs up one now and then, and icicles hang from every title bar.",
    Panel = PG(C(12, 30, 56), C(4, 10, 22)), Card = PG(C(18, 44, 76), C(8, 18, 34)), Title = PG(C(60, 140, 210), C(20, 50, 100)),
    Accent = C(120, 225, 255), Accent2 = C(220, 240, 255), HpFill = C(120, 225, 255), HpBg = C(8, 16, 30), XpFill = C(170, 235, 255), Text = C(220, 240, 255),
    IceLit = C(150, 214, 248), IceShade = C(36, 92, 160), Rime = C(236, 248, 255),
    Tex = "tex_pf_ice", TexT = 0.9, TexTile = 96,
    Emblem = "EmblemPermafrost", BorderThick = 2,
    Deco = PfDeco, OpenFn = PfOpen, TitleDeco = PfTitle,
    Clean = PF_CLEAN, -- (SKIN UI THEMES roll-out: the clean palette + frosted tab marks with icicles + frost ferns out of the lower corners; the old art is not drawn)
    -- (SKIN UI 2026-10-29: FLASH FROZEN -- crystallise, frost over, a frost star on crits, a rime edge on weak spots, a crack on a kill; this colourway's P)
    Numbers = { Font = "Ubuntu", Glyph = "◆", NoBang = true, Motion = PfMotion, Accent = PfAccent, AccentStep = PfAccentStep,
        Normal = P.Ice:Lerp(P.Text, 0.6), Crit = P.Lume, Weak = P.Hot, Stroke = P.Ink, Size = 1.05 } }

-- ===== bundle / kill effect / store hero =====
Set.KillEffect = { Id = "FrostBloom", Name = "Frost Bloom", Image = Tex("pf_emblem", ""),
    How = "Own any Permafrost skin (or the Permafrost bundle)",
    Desc = "Flash freeze: frost races across the floor, blue ice crystals shoot up the body from the feet, it hangs frozen for a beat -- then it shatters, the shards tumbling across the floor and melting away. With the crystal kill banner that grows one arm of a frost star per kill." }
Set.Bundle = { Id = "PermafrostBundle", Name = "Permafrost Bundle", Price = 2199, BP = 799, ProductId = 0,
    Desc = "The whole Permafrost set: the Permafrost M82, PKM and MP40, the Rime Sabre, Frostbite Gloves + Rime Vambraces, the Permafrost health bar, the Permafrost UI theme and the Frost Bloom kill effect.",
    Contents = { "WeaponSkin:PermafrostM82", "WeaponSkin:PermafrostPKM", "WeaponSkin:PermafrostMP40", "MeleeSkin:Permafrost", "Glove:FrostbiteGloves", "Sleeve:RimeVambraces",
        "HealthBar:Permafrost", "KillEffect:FrostBloom" } }
Set.Hero = { Grad = { C(20, 48, 90), C(4, 10, 22) }, Stroke = LUME, Emblem = Tex("pf_emblem", ""), Name = C(226, 240, 252), Chip = C(20, 70, 120) }

return Set
