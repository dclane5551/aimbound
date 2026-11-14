--!nocheck
-- ===================================================================================================================
-- KINTSUGI (Skins V3, bundle 15 of docs/SKINS_V3_PLAN.md; SKINS BUILDER 9 "skins9"): M60 + P226 + Mk 11 | Kintsugi Kunai |
-- 1,199 BP. Thrown, glazed stoneware broken and mended with gold. The guns are RESCULPTED models
-- (WeaponAssets.SkinModels.Kintsugi_<GUN>, tools/skins_v3/kintsugi_build.py, painted by tools/skin_v3_paint.py with
-- tools/skins_v3/kintsugi.json; v5 = tools/skins_v3/kintsugi_v5.py: satin glaze, the gold a crack network over the whole
-- gun, no gold patch): every shell is a vessel on its side -- a deep glaze that pools darker underneath, a rolled
-- lip, soft throwing ridges, a bare clay foot where the glaze stops in a drip line -- and each piece carries ONE deliberate
-- break, mended with a raised gold seam whose thin core holds light. This module brings their motion:
--   ASSEMBLE  drawn, the loose shard of the M60's receiver slides home against its twin (ShiftDrive "Gap") and the seams
--             fill with light grip -> muzzle; the inspect lets the shard breathe out a hair and settle
--   FLOW      light runs along the seams (S1..S7, numbered butt -> muzzle by kintsugi_v5.flow_order: a travelling wave every
--             few seconds through the whole network), a flick with each shot
--   MEND      the streak mends up to three fine gold branches off the main seam (CountDrive "Mend")
--   DUST      a pinch of gold dust falls from the mag well on a reload
-- Muzzle: a small warm flash and a few gold flecks. Tracer: a dark line with a gold vein flickering along it. Impact: a
-- small gold fracture star on the surface that glows and fades. Kill MENDED: gold fracture lines run over the body, it
-- parts into shards that drift apart and fade, leaving a soft gold glow. Banner: a ceramic disc with a gold seam that grows
-- a branch per kill. Original design (plan "Originality"): kintsugi -- real breaks mended with gold that grow with the
-- streak -- in a dark glazed stoneware; no crystal, no blue-and-white porcelain print, no gold scrollwork.
-- ===================================================================================================================
local Set = { Kind = "Kintsugi" }

local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local V = Vector3.new
-- (owner on the v3 renders: "Don't we have a lot of blue guns though?" -> CELADON, the jade-green glaze, is the default;
-- Indigo Glaze, Kaki (persimmon red-brown) and Tenmoku (near-black brown, copper) are the colourways)
local PALETTES = {
    { Name = "Celadon", Glaze = C(18, 86, 62), Pool = C(132, 176, 148), Clay = C(122, 92, 62), Gold = C(204, 148, 50), Iron = C(28, 30, 30),
      Lume = C(255, 196, 80), Hot = C(255, 236, 190), Text = C(236, 240, 230), Ink = C(4, 10, 8), Plate = C(198, 214, 204), Linen = C(22, 40, 34) },
    { Name = "Indigo Glaze", Glaze = C(14, 22, 78), Pool = C(84, 118, 196), Clay = C(118, 88, 62), Gold = C(204, 148, 50), Iron = C(30, 30, 36),
      Lume = C(255, 196, 80), Hot = C(255, 236, 190), Text = C(240, 232, 220), Ink = C(8, 8, 24), Plate = C(200, 196, 214), Linen = C(18, 20, 44) },
    { Name = "Kaki", Glaze = C(128, 38, 12), Pool = C(206, 132, 66), Clay = C(122, 92, 64), Gold = C(210, 150, 52), Iron = C(30, 26, 24),
      Lume = C(255, 190, 90), Hot = C(255, 232, 190), Text = C(244, 232, 218), Ink = C(12, 4, 2), Plate = C(220, 196, 176), Linen = C(40, 18, 12) },
    { Name = "Tenmoku", Glaze = C(22, 14, 10), Pool = C(150, 82, 34), Clay = C(118, 90, 66), Gold = C(176, 96, 44), Iron = C(32, 28, 26),
      Lume = C(255, 140, 60), Hot = C(255, 214, 170), Text = C(244, 230, 214), Ink = C(10, 5, 3), Plate = C(214, 196, 178), Linen = C(28, 18, 13) },
}
local P = PALETTES[VAR] or PALETTES[1]
local GOLD, LUME, HOT = P.Gold, P.Lume, P.Hot
Set.Palettes = PALETTES
Set.Colors = { Glow = LUME, Hot = HOT, Accent = GOLD, Mid = P.Pool }
-- art (tools/make_kintsugi_art.py, uploaded as decals; these are the IMAGE ids, resolved in Studio)
Set.Art = {
    EmblemKintsugi = "rbxassetid://134158670976542",
    kt_br1 = "rbxassetid://72822044050240", kt_br2 = "rbxassetid://140076930084400", kt_br3 = "rbxassetid://135815279854301",
    kt_br4 = "rbxassetid://117625395746598", kt_br5 = "rbxassetid://118147970226874", kt_corner = "rbxassetid://104967273927598",
    kt_dust = "rbxassetid://138684853919882", kt_emblem = "rbxassetid://134158670976542", kt_emblem_mask = "rbxassetid://118582918979354",
    kt_lines = "rbxassetid://96427977836864", kt_plate = "rbxassetid://124007795093802", kt_star = "rbxassetid://102351917718463",
    tex_kt_bar = "rbxassetid://109263919617728", tex_kt_glaze = "rbxassetid://104068450807633",
}
local ART = Set.Art

local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

local function GunDesc(gun: string): string
    -- (v5, skinsB 2026-10-13; owner: "the shiny weird texture" + "a random yellow blob": satin glaze, no gold patch, the gold
    -- is one network of mended cracks over the whole gun)
    -- (v6 SHATTERED, skinsA 2026-10-13: struck and really broken, a gold heart, one splintered crack through the whole gun)
    local what = (gun == "P226") and "the slide struck at the rear, one shard missing from the break and floating free on threads of molten gold, the crack splintering forward to the muzzle and down the grip to the butt"
        or (gun == "MK11") and "the receiver struck, one shard missing from the break and floating free on threads of molten gold, the crack splintering out along the handguard to the muzzle and back down the stock"
        or "the ammo box struck square on, one shard missing from the break and floating free on threads of molten gold over a glowing socket, a sliver broken off the receiver, a band off the stock, one splintered crack running muzzle to butt"
    return "Deep-glazed stoneware with a gold heart: " .. what .. ". Gold light flows through every crack; a kill knocks the pieces loose and sends a surge through them. Inspect it and the whole gun breaks apart off its gold skeleton, then snaps back together, MENDED."
end

-- ===== the guns =====
Set.GunSkins = {
    { Id = "KintsugiM60", Name = "Kintsugi M60", Gun = "M60", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("M60"),
      Model = "Kintsugi_M60", V3 = true, Color = LUME, Deco = "KintsugiGun", Fit = { G = "M60" } },
    { Id = "KintsugiP226", Name = "Kintsugi P226", Gun = "P226", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("P226"),
      Model = "Kintsugi_P226", V3 = true, Color = LUME, Deco = "KintsugiGun", Fit = { G = "P226" } },
    { Id = "KintsugiMK11", Name = "Kintsugi M110", Gun = "MK11", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("MK11"),
      Model = "Kintsugi_MK11", V3 = true, Color = LUME, Deco = "KintsugiGun", Fit = { G = "MK11" } },
}

-- ===== small Roblox bits: ONE gold-dust emitter on the magazine (the reload's dust) =====
Set.Build = {}
Set.Build.KintsugiGun = function(model: Model, frame: BasePart, f: any, forView: boolean, H: any)
    local mag = model:FindFirstChild("Magazine")
    local host = (mag and mag:IsA("BasePart")) and mag or frame
    local a = Instance.new("Attachment")
    a.Name = "KTDust"
    a.Position = (host == mag) and V(0, host.Size.Y * 0.5, 0) or V(0, 0, 0)
    a.Parent = host
    H.Emitter(a, { Name = "KTDust", Texture = ART.kt_dust ~= "" and ART.kt_dust or H.SPARK, Color = { HOT, GOLD:Lerp(LUME, 0.5) },
        Size = { 0.025, forView and 0.012 or 0.02 }, Life = { 0.5, 0.9 }, Speed = { 0.2, 0.6 }, Spread = 40, Accel = V(0, -2.5, 0),
        Drag = 1.5, Trans = { 0.1, 1 }, Light = 0.6, Influence = 0.6, Dir = Enum.NormalId.Bottom, SkinFx = true })
end

-- ===== sounds (tools/skins_v3/kintsugi_sfx.py: each gun's own recorded shot + a dry ceramic chink; the moments from CC0
-- recordings -- tools/sound_sources.json). Id 0 = silent until uploaded. =====
Set.Sounds = {
    Equip = { Id = 112197900613197, Volume = 0.42 }, MagOut = { Id = 75324169018326, Volume = 0.34 }, MagIn = { Id = 118683555340900, Volume = 0.4 }, Kill = { Id = 85364963708303, Volume = 0.5 },
    Impact = { Id = 139058977327585, Volume = 0.2 }, Swing = { Id = 83605053358773, Volume = 0.38 }, MeleeHit = { Id = 73804256612663, Volume = 0.42 }, Mend = { Id = 124426357190642, Volume = 0.25 },
    FireGun = { M60 = { Id = 106884189228304, Volume = 0.8 }, P226 = { Id = 93163669696516, Volume = 0.8 }, MK11 = { Id = 94780114163632, Volume = 0.8 } },
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
    H.Debris:AddItem(s, 2)
end
local function Dust(gun: Model?, n: number)
    if not gun then return end
    for _, d in ipairs(gun:GetDescendants()) do
        if d:IsA("ParticleEmitter") and d.Name == "KTDust" then d:Emit(n) return end
    end
end

-- ===== motion =====
-- st.Gap (1 = the shard lifted off its twin, 0 = home), st.S1..S4 (the light along the seam segments), st.Mend (the streak's
-- branches 0..3), st.MendA (their glow), st.Seam (the kunai's seam). v = rig.SkinVars / rec.Vars
local function Keys(st: any, v: any, dt: number, now: number, anim: string?, animT: number?, beats: any?)
    local ss = st.SinceShot or 99
    local se = st.SinceEquip or 99
    local streak = math.min(st.Streak or 0, 5)
    local insp = anim == "Inspect" and animT or nil
    -- assemble on the draw; the inspect lets the shard breathe out and settle on the signature beat
    local gap = 0
    if se < 0.7 then gap = 1 - smooth((se - 0.08) / 0.42) end
    if insp then
        local a, b = (beats and beats.Present) or 0.6, (beats and (beats.Tilt or beats.Flip or beats.Rack)) or 1.9
        gap = math.max(gap, 0.9 * math.sin(math.clamp((insp - a) / math.max(0.2, b - a), 0, 1) * math.pi))
    end
    st.Gap = gap
    -- (v4, owner: "stronger motion") the FLOW: gold light runs along every seam segment S1..S7 in turn (the second break
    -- network continues the wave), brighter + faster with the streak; the draw fills the seams grip -> muzzle; a shot flicks.
    -- A KILL sends a bright surge racing through all the cracks (CRACKS SPREAD) and lights the mend branches.
    local sk0 = st.Streak or 0
    if sk0 > (v.FlowStreak or 0) then v.SurgeAt = now end
    v.FlowStreak = sk0
    local base = 0.32 + 0.08 * streak
    local per = 2.8 - 0.25 * streak
    local ph = (now % per) / per
    local fill = (se < 1.0) and smooth((se - 0.15) / 0.7) or 1
    local flick = 0.55 * math.exp(-ss / 0.12)
    local sa = v.SurgeAt and (now - v.SurgeAt) or 99
    for i = 1, 7 do
        local d = (ph * 2.2 - (i - 1) * 0.22)
        local wave = math.exp(-((d - 0.15) / 0.13) ^ 2)
        local lit = base + 0.75 * wave + flick
        if sa < 1.2 then
            -- the surge: a hot front through S1 -> S7 in 0.5 s, then a glow that settles
            local front = math.exp(-(((sa * 2.4) - (i - 1) * 0.16) / 0.12) ^ 2)
            lit = math.max(lit, front, 0.85 * (1 - smooth(sa / 1.2)))
        end
        if insp then
            local t = (insp - ((beats and beats.Present) or 0.6)) * 1.4 - (i - 1) * 0.16
            lit = math.max(lit, math.exp(-((t - 0.3) / 0.25) ^ 2))
        end
        if se < 1.0 then lit = lit * smooth(fill * 4 - (i - 1) * 0.6) end
        st["S" .. i] = math.clamp(lit, 0, 1)
    end
    -- (v4) up to five mend branches with the streak; they flare with the surge
    st.Mend = math.min(streak, 5)
    st.MendA = math.clamp(0.5 + 0.3 * math.sin(now * 1.3) + flick + ((sa < 0.8) and (1 - sa / 0.8) or 0), 0, 1)
    -- (v4) FLOATING SHARDS: the inspect lifts the gold-edged flakes off the break (each drifts its own way), they hang, then
    -- re-mend on the settle beat with a flash along the seams; a kill nudges them out a hair
    local fl = 0
    if insp then
        local a = (beats and beats.Present) or 0.6
        local b = (beats and beats.Settle) or 2.9
        fl = smooth((insp - a) / 0.45) * (1 - smooth((insp - (b - 0.45)) / 0.4))
        if insp > b - 0.1 and insp < b + 0.35 then
            local f = 1 - math.abs(insp - (b + 0.1)) / 0.25
            if f > 0 then for i = 1, 7 do st["S" .. i] = math.max(st["S" .. i], f) end end
        end
    end
    if sa < 0.6 then fl = math.max(fl, 0.18 * math.sin(math.clamp(sa / 0.6, 0, 1) * math.pi)) end
    -- (live check: at 1x the flakes drifted ~6 cm and the float barely read in first person -> 2x)
    st.Float = fl * 2
    -- (v6 SHATTERED, skinsA 2026-10-13; owner on v5: "the inspect effects ... bugged / very bad") the M60's struck ammo box:
    -- Lift = the missing HERO shard floating out of its socket on three threads of molten gold (0 = home in the socket,
    -- 1 = the end of its threads), Burst = every shard of the break lifted off the gold heart, Pool = the molten socket.
    --   idle   the hero hangs out of the socket and drifts; the socket breathes
    --   draw   the pieces fly together (Burst 0.8 -> 0) and the hero rises out of its socket
    --   kill   the shards jump out a hair and back, the hero is knocked out further, the surge runs the seams
    --   INSPECT the gun BREAKS APART: every shard lifts off the gold skeleton, the hero swings out to the end of its threads,
    --          they hang ... and on the settle beat snap home in one hit with a flash through every seam (MENDED); the hero
    --          then slowly works loose again
    local burst, lift = 0, 0.42 + 0.05 * math.sin(now * 1.3) + 0.02 * streak
    if se < 0.5 then
        -- (clip check: at 0.85 the box shards flew into the right fist on the draw)
        burst = 0.4 * (1 - smooth((se - 0.08) / 0.3))
        lift = lift * smooth((se - 0.25) / 0.5)
    end
    if sa < 0.45 then
        local k = math.sin(math.clamp(sa / 0.45, 0, 1) * math.pi)
        burst = math.max(burst, 0.24 * k)
        lift = lift + 0.22 * k
    end
    if insp then
        local a = (beats and beats.Present) or 0.6
        local b = (beats and beats.Settle) or 2.9
        local snap = b - 0.12
        if insp < snap then
            local up = smooth((insp - (a - 0.1)) / 0.4)
            local breathe = 0.04 * math.sin((insp - a) * 5.0)
            burst = math.max(burst, up * (0.92 + breathe))
            lift = lift + (1 - lift) * up
            if up > 0.05 and not v.BrokeAt then v.BrokeAt = now; v.SndBreak = true end
        else
            -- the snap: home in 0.1 s
            local k = smooth((insp - snap) / 0.1)
            burst = math.max(burst * k, (1 - k))
            lift = 1 - k
            if not v.MendAt or (now - v.MendAt) > 1.5 then
                if v.BrokeAt then v.MendAt = now; v.SndMend = true end
            end
            v.BrokeAt = nil
        end
    else
        v.BrokeAt = nil
    end
    if v.MendAt then
        local m = now - v.MendAt
        if m < 1.9 and not (insp and insp < ((beats and beats.Settle) or 2.9) - 0.12) then
            -- (mended: the hero sits home, then works loose again)
            lift = lift * smooth((m - 0.5) / 1.4)
        end
        if m < 0.5 then
            local f = 1 - m / 0.5
            for i = 1, 7 do st["S" .. i] = math.max(st["S" .. i], f) end
        end
    end
    st.Burst = math.clamp(burst, 0, 1)
    st.Lift = math.clamp(lift, 0, 1)
    local pool = 0.5 + 0.18 * math.sin(now * 2.1) + 0.06 * streak + 0.5 * st.Burst + flick
    if sa < 0.8 then pool = math.max(pool, 1 - sa / 0.8) end
    if v.MendAt and now - v.MendAt < 0.5 then pool = 1 end
    st.Pool = math.clamp(pool, 0, 1)
    -- the hero GOLD PATCH glint: a bright bar sweeps across the gold on every kill (and once on the inspect's present beat);
    -- a faint one passes every ~9 s on its own. GlintS = where it is across the patch, Glint = how bright
    local sk = st.Streak or 0
    if sk > (v.LastStreak or 0) then v.GlintAt = now end
    v.LastStreak = sk
    local ga, gk = -9, 0
    if v.GlintAt then ga = now - v.GlintAt end
    if ga >= 0 and ga < 0.55 then
        gk = 1
    elseif insp then
        local pb = (beats and beats.Present) or 0.6
        if insp >= pb and insp < pb + 0.7 then ga = (insp - pb) * 0.8; gk = 0.9 end
    end
    if gk == 0 then
        local idle = now % 9.0
        if idle < 0.7 then ga = idle * 0.78; gk = 0.45 end
    end
    if gk > 0 then
        local t = math.clamp(ga / 0.55, 0, 1)
        st.GlintS = smooth(t)
        st.Glint = gk * math.sin(t * math.pi)
    else
        st.GlintS = 0; st.Glint = 0
    end
    -- the silk cord CHARM: a damped pendulum kicked by the draw, every shot, the mag change and the inspect's tilt
    local x, vel = v.SwX or 0, v.SwV or 0
    local kick = 0
    if se < 0.05 and not v.SwEq then kick += 2.2; v.SwEq = true elseif se > 0.2 then v.SwEq = nil end
    if ss < (v.SwLastSs or 99) - 0.001 then kick += 0.5 * (math.random() < 0.5 and -1 or 1) end   -- (a new shot: SinceShot fell)
    v.SwLastSs = ss
    if v.SwKick then kick += v.SwKick; v.SwKick = nil end
    vel += kick + (-26 * x - 2.6 * vel) * math.min(dt, 0.05)
    x += vel * math.min(dt, 0.05)
    if insp then x = x * 0.9 + 0.1 * 0.6 * math.sin(insp * 2.4) end
    v.SwX, v.SwV = x, vel
    st.Swing = math.clamp(x + 0.06 * math.sin(now * 1.7), -1, 1)
end
-- (v6 kunai, skinsA 2026-10-13: the gun language on the blade) Lift = the broken TIP floating beyond the blade on its
-- threads, Burst = the blade's shards off the gold skeleton, Pool = the glowing break, Seam = the lit mends.
--   draw    the shards fly together as the ring spin lands, the tip drifts out to its rest
--   swing   a hit / kill (the streak) knocks the tip out further and pops the shards
--   inspect after the spins, held up to look at: the blade BREAKS APART -- the shards lift off the skeleton, the tip
--           swings to the end of its threads -- turned over to the other face, and on the settle snaps home in one hit with
--           a flash through every mend (MENDED), then the tip slowly works loose again
local function MeleeKeys(st: any, v: any, now: number, anim: string?, animT: number?, beats: any?, alen: number?)
    -- (owner: "it still stutters for a moment at the end of the inspect" -- measured per RenderStepped frame on the real
    -- client: the tip SNAPPED home at Settle - 0.12 in 0.1 s while the knife was already sweeping back (tip 1.6 -> 4.8 ->
    -- 2.1 studs/s in one frame), and once the knife had stopped dead at 3.0 the tip started moving again ("works loose",
    -- 0.06 studs/s for 1.4 s). Now the mend snaps during the HELD look, before the return starts, and the tip eases back out
    -- to its idle spot over the return itself, with the same ease, landing exactly when the knife stops. The draw too: the
    -- pieces settle and the tip reaches its idle spot by the end of the draw (0.6 s), not after it.)
    local se = st.SinceEquip or 99
    local lit = 0.3 + 0.15 * math.sin(now * 1.1) + 0.6 * (v.LandA or 0)
    if se < 0.6 then lit = math.max(lit, 1 - se / 0.6) end
    v.LandA = math.max(0, (v.LandA or 0) - 1 / 40)
    local sk = st.Streak or 0
    if sk > (v.MStreak or 0) then v.MHitAt = now end
    v.MStreak = sk
    local ha = v.MHitAt and (now - v.MHitAt) or 99
    local idle = 0.45 + 0.06 * math.sin(now * 1.4)
    local burst, lift = 0, idle
    if se < 0.6 then
        burst = 0.5 * (1 - smooth((se - 0.2) / 0.3))
        lift = idle * smooth((se - 0.3) / 0.3)
    end
    if ha < 0.4 then
        local k = math.sin(math.clamp(ha / 0.4, 0, 1) * math.pi)
        burst = math.max(burst, 0.3 * k)
        lift = lift + 0.3 * k
        lit = math.max(lit, k)
    end
    local insp = anim == "Inspect" and animT or nil
    if insp then
        -- (breaks apart as the knife swings up into the held look -- the tip lifts out while the knife is still moving, so
        -- there is no stop-then-start)
        local a = (beats and beats.Look and beats.Look - 0.25) or (((beats and beats.Flip) or 0.68) + 0.5)
        local snap = ((beats and beats.Settle) or 2.8) - 0.45   -- (inside the held look: the hand is still)
        local back = snap + 0.1                                 -- (the return to rest starts here)
        local stop = alen or 3.0
        if insp < snap then
            local up = smooth((insp - a) / 0.35)
            burst = math.max(burst, up * (0.92 + 0.05 * math.sin((insp - a) * 6)))
            lift = lift + (1 - lift) * up
            lit = math.max(lit, 0.55 * up)
            if up > 0.05 and not v.MBroke then v.MBroke = true; v.SndBreak = true end
        elseif insp < back then
            local k = smooth((insp - snap) / 0.1)
            burst = 1 - k
            lift = 1 - k
            if v.MBroke then v.MBroke = nil; v.MMendAt = now; v.SndMend = true end
        else
            burst = 0
            lift = idle * smooth((insp - back) / math.max(0.1, stop - back))
        end
    else
        v.MBroke = nil
    end
    if v.MMendAt and now - v.MMendAt < 0.5 then lit = math.max(lit, 1 - (now - v.MMendAt) / 0.5) end
    st.Seam = math.clamp(lit, 0, 1)
    st.Burst = math.clamp(burst, 0, 1)
    st.Lift = math.clamp(lift, 0, 1)
    local pool = 0.5 + 0.2 * math.sin(now * 2.3) + 0.5 * st.Burst
    if v.MMendAt and now - v.MMendAt < 0.5 then pool = 1 end
    st.Pool = math.clamp(math.max(pool, ha < 0.5 and 1 - ha / 0.5 or 0), 0, 1)
end
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    local v = rig.SkinVars
    if rig.Def and rig.Def.IsMelee then
        MeleeKeys(st, v, now, rig.AnimName, rig.AnimTime, (rig.AnimName == "Inspect" and rig.Anim and rig.Anim.Beats) or nil,
            rig.Anim and rig.Anim.Length)
        if v.SndBreak then v.SndBreak = nil; PlaySound(H, { Id = Set.Sounds.Kill.Id, Volume = 0.24 }, 1.25) end
        if v.SndMend then v.SndMend = nil; PlaySound(H, { Id = Set.Sounds.Mend.Id, Volume = 0.55 }, 1.12) end
        return
    end
    local beats = (rig.AnimName == "Inspect" and rig.Anim and rig.Anim.Beats) or nil
    Keys(st, v, dt, now, rig.AnimName, rig.AnimTime, beats)
    -- (a new mend branch lights: the soft trickle)
    local m = st.Mend or 0
    if m > (v.LastMend or 0) then PlaySound(H, Set.Sounds.Mend, 0.95 + 0.1 * math.random()) end
    v.LastMend = m
    -- (v6) the inspect's break (a dry ceramic crack) and the mend (the gold trickle, louder, a touch higher)
    if v.SndBreak then v.SndBreak = nil; PlaySound(H, { Id = Set.Sounds.Kill.Id, Volume = 0.28 }, 1.12) end
    if v.SndMend then v.SndMend = nil; PlaySound(H, { Id = Set.Sounds.Mend.Id, Volume = 0.6 }, 1.08) end
end
Set.OnEvent = function(rig: any, name: string, H: any, data: any)
    local v = rig.SkinVars
    if not v then return end
    if name == "MagOut" then
        Dust(rig.Gun, 8)
        v.SwKick = 1.4
    elseif name == "Flip" or name == "OBLand" then
        v.LandA = 1   -- (the kunai's seam lights as it lands)
    end
end
Set.World = function(rec: any, now: number, st: any)
    local v = rec.Vars
    local dt = v.LastNow and math.clamp(now - v.LastNow, 0, 0.2) or 0
    v.LastNow = now
    st.SinceShot = 99; st.SinceEquip = 99; st.Reload = 0; st.Streak = 1
    Keys(st, v, dt, now, nil, nil, nil)
end

-- ===== muzzle: a small warm flash + a few gold flecks (no fireball) =====
Set.Muzzle = function(rig: any, flash: ParticleEmitter, light: PointLight, muzzle: Attachment, H: any)
    flash.Color = ColorSequence.new(HOT, LUME)
    flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.13), NumberSequenceKeypoint.new(1, 0.03) })
    light.Color = LUME
    light.Brightness = math.min(light.Brightness, 0.7)
    rig.Fx.KTFlecks = H.Emitter(muzzle, { Name = "KTFlecks", Texture = ART.kt_dust ~= "" and ART.kt_dust or H.SPARK, Color = { HOT, LUME },
        Size = { 0.03, 0.012 }, Life = { 0.18, 0.32 }, Speed = { 2.5, 5 }, Spread = 22, Drag = 3, Trans = { 0.1, 1 }, Light = 1, Dir = Enum.NormalId.Right })
end
Set.OnFire = function(rig: any, H: any)
    if rig.Fx and rig.Fx.KTFlecks then rig.Fx.KTFlecks:Emit(math.random(2, 3)) end
end

-- ===== the CRACKED-GOLD tracer: a thin dark line with a gold vein that flickers along it as it "cracks" =====
Set.Tracer = function(H: any, from: Vector3, to: Vector3, peer: boolean?)
    local dist = (to - from).Magnitude
    if dist < 1.5 then return end
    local host = H.FxPart({ Transparency = 1, Size = V(0.05, 0.05, 0.05), CFrame = CFrame.new(from) })
    local a0, a1 = H.Att(host, from), H.Att(host, to)
    local dark = Instance.new("Beam")
    dark.Attachment0, dark.Attachment1 = a0, a1
    dark.Color = ColorSequence.new(P.Ink:Lerp(P.Glaze, 0.5)); dark.LightEmission = 0; dark.LightInfluence = 1; dark.FaceCamera = true; dark.Segments = 1
    dark.Width0, dark.Width1 = 0.035, 0.045
    dark.Parent = host
    local vein = Instance.new("Beam")
    vein.Attachment0, vein.Attachment1 = a0, a1
    vein.Color = ColorSequence.new(HOT, LUME); vein.LightEmission = 1; vein.LightInfluence = 0; vein.FaceCamera = true; vein.Segments = 1
    vein.Width0, vein.Width1 = 0.012, 0.016
    vein.Parent = host
    local dir = (to - from).Unit
    local travel = H.TRAVEL -- (hitscan: the shot is there at once, nothing flies)
    local dur = travel + (peer and 0.14 or 0.24)
    H.Animate(dur, function(t)
        local hk = math.clamp(t / travel, 0, 1)
        a1.WorldPosition = from + dir * dist * hk
        local k = math.clamp((t - travel) / (dur - travel), 0, 1)
        local fl = 0.25 * math.sin(t * 90)
        dark.Transparency = NumberSequence.new(math.clamp(0.25 + k * 0.9, 0, 1))
        vein.Transparency = NumberSequence.new(math.clamp(0.05 + fl + k * 1.1, 0, 1))
    end, function() host:Destroy() end)
end

-- ===== impact: a small gold FRACTURE STAR on the surface that glows and fades (no light) =====
Set.Impact = function(H: any, pos: Vector3, normal: Vector3?, peer: boolean?)
    if not H.Budget("KintsugiImpact", peer and 3 or 7, 0.4) then return end
    local n = (normal and normal.Magnitude > 0.1) and normal.Unit or V(0, 1, 0)
    local p = H.FxPart({ Transparency = 1, Size = V(0.5, 0.5, 0.02), CFrame = CFrame.lookAt(pos + n * 0.02, pos + n * 2) })
    local d = Instance.new("Decal")
    d.Texture = ART.kt_star ~= "" and ART.kt_star or H.Art.Glow
    d.Color3 = LUME
    d.Face = Enum.NormalId.Front
    d.Parent = p
    local s = math.random(80, 120) / 100
    p.Size = V(0.5 * s, 0.5 * s, 0.02)
    H.Animate(0.9, function(t)
        local k = t / 0.9
        d.Transparency = math.clamp(0.05 + smooth((k - 0.35) / 0.65), 0, 1)
        d.Color3 = HOT:Lerp(GOLD, smooth(k))
    end, function() p:Destroy() end)
end

-- (the dying body's visible parts, for the kill below)
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
    end
    return out
end
-- ===== MENDED kill v2 (FX roll-out 2026-10-14; v1 = a flat gold-crack sticker over the body + its pieces drifting, the mend
-- itself never shown). ONE idea, BREAK + MEND: the body cracks into glazed shards that float apart (0.1 -> 0.5 s) while
-- molten-gold SEAMS stretch between them; on the beat (0.62 s) they snap back together -- the seams flare white-gold as
-- they close -- and settle down to the floor as one squat MENDED BOWL whose gold lines glow, then sink (1.4 s). Motion is
-- out, then down; nothing bright stays on the crosshair (the seams are thin). Budget: full <= 8 shards + 7 seams; low:
-- 4 shards + 3 seams. =====
Set.Kill = function(H: any, pos: Vector3, low: boolean)
    local ground = H.Ground(pos)
    local SM = Enum.Material.SmoothPlastic
    local model = Instance.new("Model")
    model.Name = "KintsugiKill"
    model.Parent = H.FxFolder()
    local center = pos
    local shards = {}
    local cap = low and 4 or 8
    local srcs = BodyParts(pos, H)
    table.sort(srcs, function(a, b) return a.Size.Magnitude > b.Size.Magnitude end)
    -- each body part (biggest first) becomes 1-2 shards: a part taller than 1.6 breaks across its long side
    for _, src in ipairs(srcs) do
        if #shards >= cap then break end
        local sz, cf = src.Size, src.CFrame
        local list = { { Vector3.xAxis, sz.X }, { Vector3.yAxis, sz.Y }, { Vector3.zAxis, sz.Z } }
        table.sort(list, function(a, b) return a[2] > b[2] end)
        local ax, len = list[1][1], list[1][2]
        local n = (len > 1.6 and #shards + 2 <= cap) and 2 or 1
        local piece = sz - ax * (len - len / n)
        for i = 1, n do
            local off = cf:VectorToWorldSpace(ax * ((i - (n + 1) / 2) * len / n))
            local glaze = (#shards % 2 == 0) and P.Glaze or P.Glaze:Lerp(P.Pool, 0.35)
            local p = H.FxPart({ Material = SM, Color = glaze, Size = piece * 0.94, CFrame = cf + off }, model)
            local out = (p.Position - center)
            out = V(out.X, out.Y * 0.6, out.Z)
            out = (out.Magnitude > 0.05) and out.Unit or V(math.random() - 0.5, 0.2, math.random() - 0.5).Unit
            table.insert(shards, { P = p, Home = p.CFrame, Size = p.Size, D = out * (1.5 + math.random() * 0.6),
                R = V(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.9 })
        end
    end
    if #shards == 0 then model:Destroy() return end
    -- the bowl the shards settle into: squat, centred on the body's footprint, sitting on the floor
    local bowlC = V(center.X, ground.Y, center.Z)
    local nS = #shards
    for i, s in ipairs(shards) do
        local a = (i - 1) / nS * math.pi * 2
        local r = 1.05 + (i % 2) * 0.25
        s.Bowl = CFrame.new(bowlC + V(math.cos(a) * r, 0.4 + (i % 3) * 0.14, math.sin(a) * r)) * CFrame.Angles(0, -a, 0.5 * ((i % 2 == 0) and 1 or -1))
        s.BowlSize = V(1.0, 0.7, 0.5)
    end
    -- seams: each shard joined to the one before it (pieces of one part are neighbours; in the bowl ring they sit side by
    -- side) by molten gold: a bar while they are apart, a gold PLATE in the joint once they close (the mend you see)
    local seams = {}
    for i = 2, nS do
        local sm = H.FxPart({ Material = Enum.Material.Neon, Color = GOLD, Size = V(0.12, 0.12, 0.1), Transparency = 1 }, model)
        table.insert(seams, { P = sm, A = i, B = i - 1 })
    end
    local function place(sm, pa: Vector3, pb: Vector3, th: number, m: number, cross: number)
        local d = pb - pa
        local L = d.Magnitude
        if L < 0.02 then sm.P.Transparency = 1 return end
        local up = (math.abs(d.Unit.Y) > 0.95) and Vector3.xAxis or Vector3.yAxis
        local w = th + (cross - th) * m
        sm.P.Size = V(w, w, L + (0.08 - L) * m)
        sm.P.CFrame = CFrame.lookAt((pa + pb) / 2, pb, up)
    end
    local BEAT = 0.62
    H.Animate(low and 1.1 or 1.4, function(t, dt)
        -- 1) CRACK + PART (0.06 -> 0.5): shards float out and turn a little; the seams stretch between them, molten
        local part = smooth((t - 0.06) / 0.44)
        -- 2) MEND (0.5 -> 0.62): they snap back together; 3) SETTLE (0.62 -> 0.95): down into the bowl on the floor
        local mend = smooth((t - 0.5) / 0.12)
        local settle = smooth((t - BEAT) / 0.33)
        local sink = smooth((t - (low and 0.85 or 1.1)) / 0.3)
        for _, s in ipairs(shards) do
            local floatCF = CFrame.new(s.D * part * (1 - mend)) * s.Home * CFrame.Angles(s.R.X * part * (1 - mend), s.R.Y * part * (1 - mend), s.R.Z * part * (1 - mend))
            local cf = floatCF:Lerp(s.Bowl, settle)
            s.P.CFrame = cf - V(0, sink * 0.9, 0)
            s.P.Size = s.Size:Lerp(s.BowlSize, settle)
            s.P.Transparency = sink
        end
        -- the seams: molten gold while parted, a white-gold flare as they close, then glowing lines on the bowl
        local th = 0.07 + 0.08 * part * (1 - settle) + 0.06 * math.exp(-((t - BEAT) / 0.06) ^ 2)
        local col = GOLD:Lerp(LUME, part):Lerp(HOT, math.exp(-((t - BEAT) / 0.07) ^ 2))
        local plate = mend * (1 - settle * 0.6)
        for _, sm in ipairs(seams) do
            local a, b = shards[sm.A].P, shards[sm.B].P
            local cross = math.min(a.Size.X, a.Size.Z, b.Size.X, b.Size.Z) * 1.08
            place(sm, a.Position, b.Position, th, plate, cross)
            sm.P.Color = col
            sm.P.Transparency = (t < 0.08) and 1 or math.max(sink, 0)
        end
    end, function() model:Destroy() end)
end

-- ===== the MENDED DISC banner (beside the HUD's weapon card, <= 180 x 90): a ceramic disc; its gold seam grows a branch per
-- kill (1-5); at five the seam glows =====
local banner
local NUMFONT = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold)
Set.Banner = function(H: any, streak: number)
    local gui, root = H.BannerRoot("Kintsugi", Vector2.new(180, 90), "Side")
    if not root then return end
    local New = H.New
    if not banner or banner.Root ~= root then
        local glow = New("ImageLabel", { BackgroundTransparency = 1, Image = H.Art.Glow, ImageColor3 = LUME, AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(120, 120), Position = UDim2.fromOffset(45, 45), ImageTransparency = 0.94, ZIndex = 1 }, root)
        local plate = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.kt_plate, ImageColor3 = P.Plate,
            Size = UDim2.fromOffset(84, 84), Position = UDim2.fromOffset(3, 3), ZIndex = 2 }, root)
        local brs = {}
        for i = 1, 5 do
            brs[i] = New("ImageLabel", { BackgroundTransparency = 1, Image = ART["kt_br" .. i], ImageColor3 = GOLD:Lerp(LUME, 0.5),
                Size = UDim2.fromOffset(84, 84), Position = UDim2.fromOffset(3, 3), ImageTransparency = 1, ZIndex = 3 }, root)
        end
        local num = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(96, 42), Size = UDim2.fromOffset(80, 40),
            FontFace = NUMFONT, TextSize = 32, TextColor3 = P.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 6 }, root)
        num:SetAttribute("KeepFont", true)
        New("UIStroke", { Color = P.Ink, Thickness = 2 }, num)
        banner = { Root = root, Plate = plate, Brs = brs, Glow = glow, Num = num, Token = 0 }
    end
    local b = banner
    b.Token += 1
    local token = b.Token
    local st = math.clamp(streak or 1, 1, 5)
    root.Visible = true
    b.Plate.ImageTransparency = 0
    b.Num.TextTransparency = 0
    b.Num.Text = "x" .. st
    b.Num.TextColor3 = (st >= 5) and LUME or P.Text
    for i, br in ipairs(b.Brs) do br.ImageTransparency = (i < st) and 0 or 1; br.ImageColor3 = GOLD:Lerp(LUME, 0.5) end
    H.Animate(0.5, function(t)
        if b.Token ~= token then return end
        local k = t / 0.5
        b.Brs[st].ImageTransparency = 1 - smooth(k)          -- the newest branch fills with gold
        if st >= 5 then
            for _, br in ipairs(b.Brs) do br.ImageColor3 = GOLD:Lerp(LUME, 0.5 + 0.5 * smooth(k)) end
            b.Glow.ImageTransparency = 0.94 - 0.4 * math.sin(k * math.pi)
        end
    end)
    task.delay(1.6, function()
        if b.Token ~= token then return end
        local ti = TweenInfo.new(0.3)
        H.TweenService:Create(b.Plate, ti, { ImageTransparency = 1 }):Play()
        H.TweenService:Create(b.Glow, ti, { ImageTransparency = 1 }):Play()
        for _, br in ipairs(b.Brs) do H.TweenService:Create(br, ti, { ImageTransparency = 1 }):Play() end
        H.TweenService:Create(b.Num, ti, { TextTransparency = 1 }):Play()
        task.delay(0.32, function() if b.Token == token then root.Visible = false end end)
    end)
end

-- ===== the KINTSUGI KUNAI (Kunai class): WeaponAssets.MeleeModels.Kintsugi -- a thick glazed leaf blade broken once down
-- its length and mended in gold (its core lights as it lands on the inspect), a gold collar, a dark cord grip, a gold ring
-- pommel with a gold wrap =====
Set.Melee = {
    Skin = { Name = "Kintsugi Kunai", Price = 449, ProductId = 0,
        Desc = "A deep-glazed stoneware kunai with a gold heart, truly broken: a splintered crack down the blade and one across, bare porcelain on every break, and the tip snapped clean off, floating beyond the blade on threads of molten gold. A gold wire-bound grip and a ring broken in three, mended in gold. Inspect it and the blade breaks apart off its gold skeleton, then snaps back together, MENDED." },
    Rig = { Class = "Kunai", BladeLen = 0.55 },
    FlatBlade = true,
    InspectEvents = { { "Flip", "OBLand" } },
    Build = function(m: Model, o: any, H: any)
        local parts = H.CloneModel(m, "MeleeModels", "Kintsugi", VAR, { [1] = LUME })
        local blade = parts.Blade
        if not blade then return end
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Name, a1.Name = "TrailBase", "TrailTip"
        a0.Position = blade.CFrame:PointToObjectSpace(V(0, 0.22, 0))
        a1.Position = blade.CFrame:PointToObjectSpace(V(0, 0.62, 0))
        a0.Parent, a1.Parent = blade, blade
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        -- (v6) the gold MEND trail: molten gold off the blade, hot at the edge, cooling to gold
        tr.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, HOT), ColorSequenceKeypoint.new(0.4, LUME), ColorSequenceKeypoint.new(1, GOLD) })
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.6, 0.6), NumberSequenceKeypoint.new(1, 1) })
        tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3) })
        tr.LightEmission = 0.85; tr.LightInfluence = 0
        tr.Lifetime = 0.16; tr.MinLength = 0.02; tr.FaceCamera = true
        tr.Enabled = false
        tr:SetAttribute("SwingTrail", true)
        tr.Parent = blade
    end,
}

-- ===== arms: GLAZE GLOVES + MENDED SLEEVES (sculpted mesh pieces, WeaponAssets.ArmsModels.Kintsugi) =====
Set.Glove = function(K: any)
    local V3 = K.V
    return {
        Id = "GlazeGloves", Name = "Glaze Gloves", Price = 449,
        Desc = "Linen gloves under a dark leather hand wrap with a gold rivet, and a glazed ceramic knuckle plate shattered and mended in gold: shards with bare porcelain edges, a few set a hair proud, raised gold mends with a splintered crack, light flowing slowly along them now and then. Part of the Kintsugi set.",
        Base = { Color = P.Linen, Material = Enum.Material.SmoothPlastic, Reflectance = 0 },
        Parts = {
            { Mesh = "Kintsugi/Plate", MeshV = VAR, Uniform = true, Size = V3(0.88, 0.1, 0.42), Off = V3(0, 0.5, -0.22), OffW = V3(0, 0.05, 0), Seat = true },
            -- (arms v2: a dark leather hand wrap behind the plate, stepped edges + a gold rivet -- three materials, not one flat colour)
            { Mesh = "Kintsugi/Wrap", MeshV = VAR, Size = V3(1.06, 1.06, 0.3), Off = V3(0, 0, 0.17) },
            -- the ONE effect: the seam's core breathing slowly
            { Mesh = "Kintsugi/Seam", MeshV = VAR, Glow = true, Color = LUME, Uniform = true, Size = V3(0.88, 0.1, 0.42), Off = V3(0, 0.5, -0.22),
              OffW = V3(0, 0.05, 0), Seat = true, Anim = "Pulse", PulseMin = 0.2, PulseMax = 0.75, Speed = 0.7, FlashOn = "Kill" },
        },
    }
end
Set.Sleeve = function(K: any)
    local V3 = K.V
    return {
        Id = "MendedSleeves", Name = "Mended Sleeves", Price = 299,
        Desc = "A soft linen sleeve with leather piping under a glazed ceramic vambrace that was shattered and mended in gold (porcelain edges, a splintered gold crack), a leather cuff with gold cord rings, a glazed bead toggle and one gold mending stitch. Part of the Kintsugi set.",
        Base = { Color = P.Linen, Material = Enum.Material.SmoothPlastic, Reflectance = 0 },
        Parts = {
            { Mesh = "Kintsugi/Sleeve", MeshV = VAR, Size = V3(1.08, 1.08, 0.92), Off = V3(0, 0, 0.02) },
            { Mesh = "Kintsugi/Cuff", MeshV = VAR, Size = V3(1.15, 1.15, 0.16), Off = V3(0, 0, -0.43) },
            { Mesh = "Kintsugi/Toggle", MeshV = VAR, Uniform = true, Size = V3(0.2, 0.07, 0.07), Off = V3(0, 0.56, -0.38), Seat = true },
            { Mesh = "Kintsugi/Stitch", MeshV = VAR, Uniform = true, Size = V3(0.36, 0.08, 0.02), Off = V3(0, 0.55, 0.12), Rot = V3(90, 0, 0), Seat = true },
        },
    }
end

-- ===== health bar v2 (BARS v2, FX roll-out): the house ink frame round a celadon glaze fill; lost health SHATTERS off as
-- porcelain flakes, and the cut it leaves is MENDED: a gold seam stays on the fill's end and slowly fades =====
Set.Bar = { Id = "Kintsugi", Name = "Kintsugi", Price = 149,
    Desc = "A celadon-glazed health bar in an ink frame. A hit breaks the lost piece off as porcelain flakes and the break is mended with a line of gold that glows and slowly fades. Part of the Kintsugi set.",
    Look = "Ink", FillColor = P.Pool, ChipMotion = "Shatter", Chip = P.Plate, Back = P.Ink, Segments = 0, Decor = { "GoldMend" } }
Set.BarDecor = {
    GoldMend = function(ctx: any, K: any)
        -- up to 3 gold mends (a short crooked seam: two slanted strokes) left where hits cut the fill; each glows hot, cools to gold, fades
        local pool = {}
        for i = 1, 3 do
            local a = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = LUME, AnchorPoint = Vector2.new(0.5, 1), ZIndex = 9, Visible = false }, ctx.Holder)
            local b = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = LUME, AnchorPoint = Vector2.new(0.5, 0), ZIndex = 9, Visible = false }, ctx.Holder)
            pool[i] = { A = a, B = b, T = 99 }
        end
        local nextI = 1
        return function(now, dt, alpha, info)
            if (info.Drop or 0) > 0.004 and info.DropX0 then
                local m = pool[nextI]
                nextI = nextI % 3 + 1
                m.T, m.X = 0, info.DropX0
            end
            for _, m in ipairs(pool) do
                m.T += dt
                local on = m.T < 1.6
                m.A.Visible, m.B.Visible = on, on
                if on then
                    local w = math.max(2, math.floor(ctx.H * 0.22 + 0.5))
                    local x = math.min(m.X, ctx.W * math.clamp(info.Shown or 1, 0, 1))
                    m.A.Size = UDim2.fromOffset(w, ctx.H * 0.6); m.A.Position = UDim2.fromOffset(x, ctx.H * 0.55); m.A.Rotation = 18
                    m.B.Size = UDim2.fromOffset(w, ctx.H * 0.55); m.B.Position = UDim2.fromOffset(x - ctx.H * 0.08, ctx.H * 0.5); m.B.Rotation = -22
                    local col = HOT:Lerp(GOLD, math.min(1, m.T / 0.4))
                    local tr = 1 - alpha * (1 - smooth((m.T - 1.0) / 0.6))
                    m.A.BackgroundColor3, m.B.BackgroundColor3 = col, col
                    m.A.BackgroundTransparency, m.B.BackgroundTransparency = tr, tr
                end
            end
        end
    end,
}

-- ===== UI theme v2 (FX roll-out 2026-10-14; v1 = the shared template): a MENDED BOWL, icon look. Two corners of every
-- window are broken and mended -- a crooked gold seam (three strokes, ink-edged) runs in from the top-left and bottom-right
-- corners with a glint travelling along it now and then; windows open with GOLD MENDING: gold lines grow along all four
-- edges from the corners and settle; every title gets a short gold seam under it. Colours from the theme table
-- (Gold / Hot / Ink) so colourways recolour them. =====
local function KtSeam(parent, pts, th, col, ink, z)
    -- a polyline of gold strokes, each with an ink edge; pts in scale-offset pairs { xs, xo, ys, yo }
    local segs = {}
    for i = 1, #pts - 1 do
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0; f.BackgroundColor3 = col; f.AnchorPoint = Vector2.new(0.5, 0.5); f.ZIndex = z
        local st = Instance.new("UIStroke"); st.Color = ink; st.Thickness = 1.5; st.Parent = f
        f.Parent = parent
        segs[i] = { F = f, A = pts[i], B = pts[i + 1] }
    end
    return segs
end
local function KtLayout(segs, abs: Vector2, th: number)
    for _, s in ipairs(segs) do
        local ax, ay = s.A[1] * abs.X + s.A[2], s.A[3] * abs.Y + s.A[4]
        local bx, by = s.B[1] * abs.X + s.B[2], s.B[3] * abs.Y + s.B[4]
        local dx, dy = bx - ax, by - ay
        local L = math.sqrt(dx * dx + dy * dy)
        s.F.Size = UDim2.fromOffset(L + th, th)
        s.F.Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2)
        s.F.Rotation = math.deg(math.atan2(dy, dx))
        s.L, s.AX, s.AY, s.DX, s.DY = L, ax, ay, dx, dy
    end
end
local function KtDeco(ctx)
    if ctx.Kind ~= "Window" then return nil end
    local t = ctx.Theme
    local host = ctx.Root or ctx.Surface
    local f = Instance.new("Frame")
    f.Name = "KtOverlay"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 20; f.Active = false
    f:SetAttribute("NoSkin", true); f:SetAttribute("Skinned", true)
    f.Parent = host
    local abs = host.AbsoluteSize
    local small = math.min(abs.X, abs.Y) < 260
    local u = small and 0.8 or 1.45
    local th = small and 3 or 4
    -- top-left: in from the corner, a crook, out along the top edge; bottom-right: the mirror
    local tl = KtSeam(f, { { 0, 0, 0, 34 * u }, { 0, 22 * u, 0, 22 * u }, { 0, 30 * u, 0, 8 * u }, { 0, 70 * u, 0, 0 } }, th, t.Gold, t.Ink, f.ZIndex + 1)
    local br = KtSeam(f, { { 1, 0, 1, -40 * u }, { 1, -18 * u, 1, -26 * u }, { 1, -34 * u, 1, -14 * u }, { 1, -84 * u, 1, 0 } }, th, t.Gold, t.Ink, f.ZIndex + 1)
    KtLayout(tl, abs, th); KtLayout(br, abs, th)
    local glint = Instance.new("Frame")
    glint.BorderSizePixel = 0; glint.BackgroundColor3 = t.Hot; glint.AnchorPoint = Vector2.new(0.5, 0.5); glint.Size = UDim2.fromOffset(th * 2.2, th * 2.2)
    glint.ZIndex = f.ZIndex + 2
    local gc = Instance.new("UICorner"); gc.CornerRadius = UDim.new(1, 0); gc.Parent = glint
    glint.Parent = f
    local runs = { tl, br }
    local lastAbs = abs
    return function(now, dt)
        local a = host.AbsoluteSize
        if a ~= lastAbs then lastAbs = a; KtLayout(tl, a, th); KtLayout(br, a, th) end
        -- a glint runs along one seam every ~4 s (0.6 s run)
        local cyc = now % 4.2
        local run = runs[(math.floor(now / 4.2) % 2) + 1]
        if cyc < 0.6 then
            glint.Visible = true
            local total = 0
            for _, s in ipairs(run) do total += (s.L or 0) end
            local d = total * (cyc / 0.6)
            for _, s in ipairs(run) do
                if d <= (s.L or 0) then
                    local k = (s.L > 0) and d / s.L or 0
                    glint.Position = UDim2.fromOffset(s.AX + s.DX * k, s.AY + s.DY * k)
                    break
                end
                d -= (s.L or 0)
            end
            glint.BackgroundTransparency = math.sin(cyc / 0.6 * math.pi) < 0.2 and 0.6 or 0
        else
            glint.Visible = false
        end
    end, { f }
end
local function KtOpen(ctx)
    -- GOLD MENDING (0.5 s): gold lines grow along all four edges out of the corners, flare, then cool away
    local t = ctx.Theme
    local root = ctx.Root
    if not root then return end
    local f = root:FindFirstChild("KtOverlay") or ctx.Frame
    local made = {}
    local edges = {
        { AP = Vector2.new(0, 0), Pos = UDim2.fromScale(0, 0), From = UDim2.fromOffset(0, 3), To = UDim2.new(1, 0, 0, 3) },
        { AP = Vector2.new(1, 1), Pos = UDim2.fromScale(1, 1), From = UDim2.fromOffset(0, 3), To = UDim2.new(1, 0, 0, 3) },
        { AP = Vector2.new(0, 1), Pos = UDim2.fromScale(0, 1), From = UDim2.fromOffset(3, 0), To = UDim2.new(0, 3, 1, 0) },
        { AP = Vector2.new(1, 0), Pos = UDim2.fromScale(1, 0), From = UDim2.fromOffset(3, 0), To = UDim2.new(0, 3, 1, 0) },
    }
    for _, e in ipairs(edges) do
        local l = Instance.new("Frame")
        l.BorderSizePixel = 0; l.BackgroundColor3 = t.Hot; l.AnchorPoint = e.AP; l.Position = e.Pos; l.Size = e.From; l.ZIndex = f.ZIndex + 6
        l.Parent = f
        ctx.Tween:Create(l, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = e.To, BackgroundColor3 = t.Gold }):Play()
        table.insert(made, l)
    end
    task.delay(0.32, function()
        for _, l in ipairs(made) do if l.Parent then ctx.Tween:Create(l, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play() end end
    end)
    task.delay(0.56, function() for _, l in ipairs(made) do l:Destroy() end end)
end
local function KtTitle(ctx)
    -- a short crooked gold seam under the title (two strokes, ink-edged)
    local bar, t = ctx.Title, ctx.Theme
    local holder = Instance.new("Frame")
    holder.Name = "KtTitleSeam"; holder.BackgroundTransparency = 1; holder.AnchorPoint = Vector2.new(0, 1)
    holder.Position = UDim2.new(0, 12, 1, -1); holder.Size = UDim2.fromOffset(60, 8); holder.ZIndex = bar.ZIndex + 1
    holder.Parent = bar
    local segs = KtSeam(holder, { { 0, 0, 0, 6 }, { 0, 24, 0, 3 }, { 0, 30, 0, 7 }, { 0, 58, 0, 4 } }, 2, t.Gold, t.Ink, bar.ZIndex + 1)
    KtLayout(segs, Vector2.new(60, 8), 2)
    return { holder }
end
-- numbers v3 (SKIN UI roll-out 2026-10-29, owner: numbers "unique to the skin and the colorways you have equipped"): CRACKED AND
-- MENDED. A calligraphic face (Fondamento) in porcelain white, edged in this colourway's GLAZE (celadon / indigo / persimmon /
-- tenmoku), that is SET DOWN like a bowl (lands from just above, settles, then lifts slowly); a hairline CRACK breaks down through the
-- digits and molten gold flows into it from one end (again on every merged hit). CRIT = the crack branches and the digits turn
-- gold; WEAK SPOT = a pinch of gold dust falls from the break (the set's reload dust); a KILL = a gold fracture star (the set's
-- impact) shoots out of the number's edge. Every colour is this copy's palette (P = the colourway).
local function KtMotion(e, age, pa, life)
    local settle = 1 - smooth(math.min(1, age / 0.22))
    local b = math.min(1, pa / 0.1)
    return 1.15 + 0.45 * settle + math.max(0, age - 0.22) * 0.45, 0, 1 + 0.08 * (1 - b), 0, 0, 0
end
-- the crack: a zig-zag break running DOWN through the digits (top edge to bottom edge, in units of the text box from its centre:
-- a horizontal one read as a strikethrough); the branches only on a crit
local KT_CRACK = { { -0.1, -0.52 }, { 0.05, -0.16 }, { -0.07, 0.14 }, { 0.08, 0.52 } }
local KT_BRANCH = { { 0.05, -0.16 }, { 0.2, -0.44 }, { -0.07, 0.14 }, { -0.2, 0.44 } } -- (two short forks off the break: pairs of points; wider read as a cross)
local KT_RAYS = 6
local function KtAccent(e)
    local box = Instance.new("Frame")
    box.Name = "KtMend"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 0
    for i = 1, KT_RAYS do -- (a kill: a gold fracture star -- seams radiating out of the number)
        local r = Instance.new("Frame")
        r.Name = "Ray" .. i; r.BorderSizePixel = 0; r.AnchorPoint = Vector2.new(0.5, 0.5); r.ZIndex = 1; r.Parent = box
    end
    for i = 1, 5 do -- (the crack's strokes: gold with a fine ink edge, so it reads on gold crit digits too)
        local s = Instance.new("Frame")
        s.Name = "S" .. i; s.BorderSizePixel = 0; s.AnchorPoint = Vector2.new(0.5, 0.5); s.ZIndex = 3
        local st = Instance.new("UIStroke"); st.Thickness = 1; st.Parent = s
        s.Parent = box
    end
    for i = 1, 3 do
        local d = Instance.new("Frame")
        d.Name = "Dust" .. i; d.BorderSizePixel = 0; d.AnchorPoint = Vector2.new(0.5, 0.5); d.Size = UDim2.fromOffset(3, 3); d.Rotation = 45; d.ZIndex = 3
        d.Parent = box
    end
    return box
end
local function KtSeg(s, ax, ay, bx, by, th)
    local dx, dy = bx - ax, by - ay
    s.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + 1, th)
    s.Position = UDim2.new(0.5, (ax + bx) / 2, 0.5, (ay + by) / 2)
    s.Rotation = math.deg(math.atan2(dy, dx))
end
local function KtAccentStep(e, box, age, pa, alpha)
    local tb = e.Label.TextBounds
    local W, H = tb.X, tb.Y * 0.85
    local crit = e.Crit and not e.Dot
    local th = crit and 2 or 1
    -- the gold flows in along the crack: segment i fills (ink -> gold light -> gold) 0.06 s after the one before it
    for i = 1, 3 do
        local s = box:FindFirstChild("S" .. i)
        if s then
            s.Visible = not e.Dot
            local a, b = KT_CRACK[i], KT_CRACK[i + 1]
            KtSeg(s, a[1] * W, a[2] * H, b[1] * W, b[2] * H, th)
            local f = math.clamp((pa - (i - 1) * 0.05) / 0.08, 0, 1)
            local cool = math.clamp((age - 0.35) / 0.4, 0, 1)
            s.BackgroundColor3 = P.Ink:Lerp(P.Hot, f):Lerp(P.Lume:Lerp(P.Hot, 0.3), cool)
            s.BackgroundTransparency = alpha
            local st = s:FindFirstChildOfClass("UIStroke"); if st then st.Color = P.Ink; st.Transparency = math.clamp(alpha + 0.3, 0, 1) end
        end
    end
    for i = 4, 5 do
        local s = box:FindFirstChild("S" .. i)
        if s then
            s.Visible = crit
            if crit then
                local a, b = KT_BRANCH[(i - 4) * 2 + 1], KT_BRANCH[(i - 4) * 2 + 2]
                local grow = math.clamp((age - 0.12) / 0.12, 0, 1)
                KtSeg(s, a[1] * W, a[2] * H, (a[1] + (b[1] - a[1]) * grow) * W, (a[2] + (b[2] - a[2]) * grow) * H, 1.5)
                s.BackgroundColor3 = P.Hot:Lerp(P.Lume, math.clamp((age - 0.3) / 0.3, 0, 1))
                s.BackgroundTransparency = alpha
                local st = s:FindFirstChildOfClass("UIStroke"); if st then st.Color = P.Ink; st.Transparency = math.clamp(alpha + 0.3, 0, 1) end
            end
        end
    end
    -- weak spot: three flecks of gold dust fall from the break and fade
    for i = 1, 3 do
        local d = box:FindFirstChild("Dust" .. i)
        if d then
            local t = age - 0.08 - i * 0.07
            local on = e.Weak and not e.Dot and t > 0 and t < 0.7
            d.Visible = on
            if on then
                local k = t / 0.7
                d.Position = UDim2.new(0.5, math.floor((i - 2) * W * 0.22 + math.sin(t * 9 + i) * 2), 0.5, math.floor(H * 0.35 + 46 * k * k))
                d.BackgroundColor3 = P.Lume; d.BackgroundTransparency = math.clamp(alpha + k * 0.8, 0, 1)
            end
        end
    end
    -- kill: a gold fracture star -- six seams shoot out of the number's edge and fade (the set's impact)
    local kt = (e.Killed and e.KillAt) and (os.clock() - e.KillAt) or -1
    local r0 = math.max(tb.X * 0.5, tb.Y * 0.5) + 3
    for i = 1, KT_RAYS do
        local r = box:FindFirstChild("Ray" .. i)
        if r then
            local on = kt >= 0 and kt < 0.9 and not e.Dot
            r.Visible = on
            if on then
                local a = math.rad((i - 1) * 60 + 18 + e.Seed * 10)
                local grow = smooth(kt / 0.16)
                local len = (8 + 10 * ((i % 2 == 0) and 0.6 or 1)) * grow
                local ax, ay = math.cos(a) * r0, math.sin(a) * r0 * 0.7
                KtSeg(r, ax, ay, ax + math.cos(a) * len, ay + math.sin(a) * len, 2)
                r.BackgroundColor3 = P.Hot:Lerp(P.Lume, math.clamp(kt / 0.3, 0, 1))
                r.BackgroundTransparency = math.clamp(alpha + smooth((kt - 0.4) / 0.5), 0, 1)
            end
        end
    end
end
-- ===== UI THEME v4 (SKIN UI THEMES roll-out 2026-10-29): the clean language in this colourway's glaze (UITheme Clean) + the
-- mend. Hooks read only the palette they are given (a colourway copy shares these functions):
--   TAB MARK  the underline is a GOLD SEAM with two little kinks breaking off it; a glint runs along the top bar's seam
--   FIELD     the top bar's lower edge is BROKEN AND MENDED: a crooked gold seam runs the whole width with three short branches
--             running down off it, a glint of light travels along it now and then; a chip off the lower-right corner of the
--             screen is mended the same way
local KT_CLEAN = {
    Field = P.Ink:Lerp(P.Glaze, 0.3), Surface = P.Linen:Lerp(P.Ink, 0.3), Raised = P.Linen:Lerp(P.Glaze, 0.28), Hover = P.Glaze:Lerp(P.Linen, 0.42):Lerp(P.Pool, 0.08),
    Well = P.Ink, Line = P.Linen:Lerp(P.Glaze, 0.4):Lerp(P.Gold, 0.22), Tip = P.Linen:Lerp(P.Ink, 0.45),
    Accent = P.Lume, Mark = P.Gold:Lerp(P.Lume, 0.45), Hair = P.Gold,
    Text = P.Text, Sub = P.Text:Lerp(P.Pool, 0.35), Muted = P.Pool:Lerp(P.Text, 0.3), Ink = P.Ink,
    Gold = P.Gold, Seam = P.Gold:Lerp(P.Lume, 0.25), Glint = P.Hot, InkLine = P.Ink,
}
-- (HudThemes.Variant keeps a colourway copy's Clean colour only when it DIFFERS from colourway 1's; one that is the same in
-- both palettes (the gold, a shared brass ...) went through the hue map instead -- Indigo's gold seam came out green. A
-- hair's difference keeps this copy's own colour.)
if VAR ~= 1 then for k, v in pairs(KT_CLEAN) do if typeof(v) == "Color3" then KT_CLEAN[k] = v:Lerp(Color3.new(0, 0, 0), 0.003) end end end
KT_CLEAN.TabMark = function(mark, Q)
    -- (children of a tab mark: offset-sized, inside the mark's width -- tab buttons are AutomaticSize X)
    local g = Instance.new("UIGradient")
    g.Name = "KtGlint"
    g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Q.Seam), ColorSequenceKeypoint.new(0.42, Q.Seam), ColorSequenceKeypoint.new(0.5, Q.Glint),
        ColorSequenceKeypoint.new(0.58, Q.Seam), ColorSequenceKeypoint.new(1, Q.Seam) })
    g.Offset = Vector2.new(-1, 0)
    g.Parent = mark
    local made = { g }
    for _, k in ipairs({ { 0.3, -2, -28 }, { 0.68, 1, 32 } }) do
        local b = Instance.new("Frame")
        b.Name = "KtKink"; b.BorderSizePixel = 0; b.BackgroundColor3 = Q.Seam; b.Size = UDim2.fromOffset(7, 2); b.Rotation = k[3]
        b.Position = UDim2.new(k[1], 0, 0, k[2]); b.ZIndex = mark.ZIndex; b.Parent = mark
        table.insert(made, b)
    end
    return made
end
-- (a polyline of seam strokes in a holder, laid out in the holder's own units: pts = { x scale, x offset, y offset })
local function KtSeamLine(holder, pts, th, Q)
    local segs = {}
    for i = 1, #pts - 1 do
        local s = Instance.new("Frame")
        s.Name = "KtSeam"; s.BorderSizePixel = 0; s.BackgroundColor3 = Q.Seam; s.BackgroundTransparency = 0.2; s.AnchorPoint = Vector2.new(0.5, 0.5); s.ZIndex = 0
        local st = Instance.new("UIStroke"); st.Color = Q.InkLine; st.Thickness = 1; st.Transparency = 0.5; st.Parent = s
        s.Parent = holder
        segs[i] = { F = s, A = pts[i], B = pts[i + 1], Th = th }
    end
    return segs
end
local function KtLay(segs, w)
    local L = 0
    for _, s in ipairs(segs) do
        local ax, ay = s.A[1] * w + s.A[2], s.A[3]
        local bx, by = s.B[1] * w + s.B[2], s.B[3]
        local dx, dy = bx - ax, by - ay
        s.L0, s.AX, s.AY, s.DX, s.DY = L, ax, ay, dx, dy
        s.L = math.sqrt(dx * dx + dy * dy)
        L += s.L
        s.F.Size = UDim2.fromOffset(s.L + s.Th, s.Th)
        s.F.Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2)
        s.F.Rotation = math.deg(math.atan2(dy, dx))
    end
    return L
end
local KT_TOP = { { 0, 0, 3 }, { 0.05, 0, 8 }, { 0.09, 0, 2 }, { 0.16, 0, 6 }, { 0.21, 0, 10 }, { 0.27, 0, 1 }, { 0.33, 0, 5 }, { 0.4, 0, 0 },
    { 0.46, 0, 7 }, { 0.54, 0, 3 }, { 0.58, 0, 9 }, { 0.65, 0, 2 }, { 0.72, 0, 6 }, { 0.79, 0, 11 }, { 0.84, 0, 3 }, { 0.9, 0, 7 }, { 0.95, 0, 1 },
    { 1, 0, 4 } }
local KT_TOP_BRANCH = { { { 0.21, 0, 10 }, { 0.215, 7, 20 }, { 0.21, 1, 31 } }, { { 0.54, 0, 3 }, { 0.545, -9, 15 }, { 0.556, 0, 25 }, { 0.552, 6, 37 } },
    { { 0.79, 0, 11 }, { 0.795, 8, 19 } } }
KT_CLEAN.Sig = function(ctx)
    local Q, f = ctx.P, ctx.Frame
    local made = {}
    local top, holder, main, all = ctx.Top, nil, nil, {}
    if top then
        holder = Instance.new("Frame")
        holder.Name = "KtMendTop"; holder.BackgroundTransparency = 1; holder.Position = UDim2.new(0, 0, 1, -3); holder.Size = UDim2.new(1, 0, 0, 40)
        holder.ZIndex = 0; holder.Active = false; holder.Parent = top
        main = KtSeamLine(holder, KT_TOP, 2, Q)
        for _, s in ipairs(main) do table.insert(all, s) end
        for _, br in ipairs(KT_TOP_BRANCH) do for _, s in ipairs(KtSeamLine(holder, br, 1.5, Q)) do table.insert(all, s) end end
        table.insert(made, holder)
    end
    -- the mended chip off the lower-right corner of the screen
    local chip = Instance.new("Frame")
    chip.Name = "KtChip"; chip.BackgroundTransparency = 1; chip.AnchorPoint = Vector2.new(1, 1); chip.Position = UDim2.fromScale(1, 1)
    chip.Size = UDim2.fromOffset(110, 110); chip.ZIndex = 0; chip.Parent = f
    local cs = KtSeamLine(chip, { { 0, 0, 112 }, { 0, 26, 86 }, { 0, 40, 76 }, { 0, 62, 50 }, { 0, 78, 42 }, { 0, 112, 22 } }, 2, Q)
    local cb = KtSeamLine(chip, { { 0, 62, 50 }, { 0, 70, 70 }, { 0, 66, 84 } }, 1.5, Q)
    KtLay(cs, 0); KtLay(cb, 0)
    local glint = Instance.new("Frame")
    glint.Name = "KtGlintDot"; glint.BorderSizePixel = 0; glint.BackgroundColor3 = Q.Glint; glint.AnchorPoint = Vector2.new(0.5, 0.5)
    glint.Size = UDim2.fromOffset(10, 3); glint.BackgroundTransparency = 1; glint.ZIndex = 1
    if holder then glint.Parent = holder end
    local w, total, ph = -1, 0, math.random() * 6
    return function(now, _dt)
        if holder then
            -- (lay the seam out in the holder's own units whenever its width changes: AbsoluteSize is after the HUD scale)
            local abs = holder.AbsoluteSize
            local k = (abs.Y > 0) and (abs.Y / 40) or 1
            local lw = math.floor(abs.X / k + 0.5)
            if lw ~= w and lw > 0 then
                w = lw
                total = KtLay(main, w)
                for _, s in ipairs(all) do if not table.find(main, s) then KtLay({ s }, w) end end
            end
            -- every ~7 s a glint of light runs the length of the seam (1.6 s)
            local t = ((now + ph) % 7) / 1.6
            if t < 1 and total > 0 then
                local d = t * total
                for _, s in ipairs(main) do
                    if d <= s.L0 + s.L then
                        local u = (s.L > 0) and (d - s.L0) / s.L or 0
                        glint.Position = UDim2.fromOffset(s.AX + s.DX * u, s.AY + s.DY * u)
                        glint.Rotation = s.F.Rotation
                        break
                    end
                end
                glint.BackgroundTransparency = 0.1 + 0.9 * math.abs(t * 2 - 1) ^ 4
            elseif glint.BackgroundTransparency < 1 then glint.BackgroundTransparency = 1 end
        end
        -- the selected tab's seam catches the light now and then
        for _, m in ipairs(ctx.Marks()) do
            local g = m.Visible and m:FindFirstChild("KtGlint")
            if g then
                local t = ((now + ph + 3) % 5) / 0.9
                g.Offset = Vector2.new((t < 1) and (-1 + 2 * t) or -1, 0)
            end
        end
    end, made
end
-- (the old window colours stay the v1 celadon glaze; colourways remap the theme table)
local function PG(top, bottom) return { Top = top, Bottom = bottom } end
local P1 = PALETTES[1]
Set.Theme = { Name = "Kintsugi", Desc = "Every menu in your colourway's glaze, broken and mended with gold: a crooked gold seam runs under the top bar with a glint travelling along it, a corner of the screen is chipped and mended, and every tab is underlined with a gold seam.",
    Panel = PG(C(18, 40, 32), C(4, 12, 9)), Card = PG(C(26, 54, 44), C(9, 22, 17)), Title = PG(C(60, 104, 84), C(18, 42, 32)),
    Accent = P1.Lume, Accent2 = C(190, 140, 50), HpFill = P1.Lume, HpBg = C(14, 10, 4), XpFill = C(190, 140, 50), Text = P1.Text,
    Tex = "tex_kt_glaze", TexT = 0.9, TexTile = 256,
    Emblem = "EmblemKintsugi", BorderThick = 2,
    Gold = C(214, 160, 60), Hot = P1.Hot, Ink = C(4, 10, 8),
    Deco = KtDeco, OpenFn = KtOpen, TitleDeco = KtTitle,
    Clean = KT_CLEAN, -- (SKIN UI THEMES: the clean glaze palette + gold-seam tab marks + the mended top edge and corner; the old art is not drawn)
    -- (SKIN UI 2026-10-29: cracked and mended -- gold flows into a crack across the digits; crit branches, weak = gold dust, kill = a gold fracture star)
    Numbers = { Font = "Fondamento", Glyph = "", NoBang = true, Motion = KtMotion, Accent = KtAccent, AccentStep = KtAccentStep,
        Normal = P.Plate:Lerp(P.Text, 0.5), Crit = P.Lume, Weak = P.Hot, Stroke = P.Glaze:Lerp(P.Ink, 0.45), StrokeThick = 2.5, Size = 1.08 } }

-- (the HUD colours of a colourway copy: the gold is the same in every glaze but Tenmoku's copper, and a colour that is the same
-- as colourway 1's goes through the hue map -- Indigo's health bar came out green; take them from this palette, a hair apart)
if VAR ~= 1 then
    local function O(c) return c:Lerp(Color3.new(0, 0, 0), 0.003) end
    local T = Set.Theme
    T.Accent, T.HpFill, T.XpFill, T.Accent2, T.Gold, T.Hot, T.Text = O(P.Lume), O(P.Lume), O(P.Gold), O(P.Gold), O(P.Gold:Lerp(P.Lume, 0.2)), O(P.Hot), O(P.Text)
end

-- ===== kill effect / bundle / store hero =====
Set.KillEffect = { Id = "Mended", Name = "Mended", Image = ART.kt_emblem,
    How = "Own any Kintsugi skin (or the Kintsugi bundle)",
    Desc = "The body cracks into glazed shards that float apart on threads of molten gold, then snaps back together and settles to the floor as a bowl mended in glowing gold. With the Mended Disc kill banner." }
Set.Bundle = { Id = "KintsugiBundle", Name = "Kintsugi Bundle", Price = 2199, BP = 799, ProductId = 0,
    Desc = "The whole Kintsugi set: the Kintsugi M60, P226 and M110, the Kintsugi Kunai, Glaze Gloves + Mended Sleeves, the Kintsugi health bar, the Kintsugi UI theme and the Mended kill effect.",
    Contents = { "WeaponSkin:KintsugiM60", "WeaponSkin:KintsugiP226", "WeaponSkin:KintsugiMK11", "MeleeSkin:Kintsugi", "Glove:GlazeGloves",
        "Sleeve:MendedSleeves", "HealthBar:Kintsugi", "KillEffect:Mended" } }
Set.Hero = { Grad = { C(36, 78, 60), C(6, 18, 13) }, Stroke = C(210, 160, 70), Emblem = ART.kt_emblem, Name = C(240, 232, 220), Chip = C(120, 86, 30) }

return Set
