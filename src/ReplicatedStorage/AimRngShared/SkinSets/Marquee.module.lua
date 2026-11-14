--!nocheck
-- ===================================================================================================================
-- MARQUEE (Skins V3, bundle 14 of docs/SKINS_V3_PLAN.md; SKINS BUILDER 10 "skins10"): PPSh-41 + 590 Pump | Cane Sword |
-- 999 BP. An ART-DECO PICTURE PALACE: deep piano-black lacquer, champagne brushed brass in RAISED stepped deco relief
-- (chevrons, stepped fans, flutes, stepped collars / bands / spines -- never a flat pattern sheet), small velvet-red inserts,
-- and warm marquee BULBS (Neon). ONE signature per gun: the PPSh's drum is a MARQUEE DISC (a brass sunburst on its rear face
-- toward the shooter, bulbs standing out of its edge: Bulb1..4 chase groups riding the magazine) with a small three-bulb
-- marquee panel on the rear receiver (Marq1..3); the 590's receiver carries a brass FAN PLATE with five bulbs on its arc
-- (Bulb1..5). The guns are RESCULPTED models (WeaponAssets.SkinModels.Marquee_<GUN>, tools/skins_v3/marquee_build.py, painted
-- by tools/skin_v3_paint.py with tools/skins_v3/marquee.json). The PPSh drum is built in the place's TURNED orientation
-- (WeaponAssets.PPSH.Magazine DrumTurned: round faces along the bore).
--   ALIVE    the bulbs chase slowly (a dark gap travelling round the marquee); faster while you fire; the 590's fan steps
--            one bulb per pump stroke
--   EQUIP    curtain up: the bulbs switch on in sequence grip -> muzzle with a relay click
--   INSPECT  a showtime flash (all bulbs blink twice) on the Present beat, then a fast chase; a glint on the Tilt
--   RELOAD   "intermission": the bulbs dim while the magazine is out and come back on, in sequence, as it seats
-- Muzzle: a warm gold flash + a small deco star. Tracer: a warm gold line with a twinkling star at its head. Impact: an
-- 8-point gold deco starburst stamped on the surface + dust. Kill CURTAIN CALL: two velvet curtains sweep closed round the
-- body, a spotlight circle on the ground fades, the curtains rise away (1.4 s; low = the spotlight only). Banner: a stepped
-- sunburst plaque with five bulb sockets that light one per kill and chase at five. Original (plan "Originality"): no ivory
-- body, no gold truss, no toy-console colours, no art-nouveau swirls; bulbs + a sunburst drum + a cane sword + a curtain
-- call are ours.
-- ===================================================================================================================
local Set = { Kind = "Marquee" }

local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local V = Vector3.new
local PALETTES = {
    { Name = "Opening Night", Lacquer = C(22, 20, 27), Brass = C(150, 118, 70), Velvet = C(104, 14, 32), Dark = C(6, 6, 8), Lume = C(255, 226, 170),
      Hot = C(255, 244, 220), Warm = C(255, 190, 110), Plate = C(16, 14, 18), Text = C(250, 236, 210), Satin = C(14, 13, 17), Ivory = C(188, 182, 166),
      Spot = C(255, 236, 200) },
    { Name = "Emerald Room", Lacquer = C(8, 34, 26), Brass = C(150, 118, 70), Velvet = C(96, 18, 40), Dark = C(4, 10, 8), Lume = C(255, 220, 150),
      Hot = C(255, 240, 214), Warm = C(255, 180, 100), Plate = C(6, 20, 16), Text = C(236, 246, 230), Satin = C(8, 24, 18), Ivory = C(188, 182, 166),
      Spot = C(255, 232, 190) },
    { Name = "Silver Screen", Lacquer = C(34, 34, 40), Brass = C(132, 136, 150), Velvet = C(52, 54, 66), Dark = C(8, 8, 10), Lume = C(220, 235, 255),
      Hot = C(240, 248, 255), Warm = C(190, 215, 255), Plate = C(20, 20, 24), Text = C(236, 240, 250), Satin = C(24, 24, 28), Ivory = C(200, 200, 206),
      Spot = C(225, 238, 255) },
}
local P = PALETTES[VAR] or PALETTES[1]
local BRASS, VELVET, LUME, HOT, WARM = P.Brass, P.Velvet, P.Lume, P.Hot, P.Warm
Set.Palettes = PALETTES
Set.Colors = { Glow = LUME, Hot = HOT, Accent = BRASS, Mid = BRASS }
-- art (tools/make_marquee_art.py, uploaded as decals; these are IMAGE ids). "" = not uploaded yet: every user has a fallback.
local A = "rbxassetid://"
Set.Art = {   -- (IMAGE ids, resolved in Studio from the decal uploads in tools/skins_v3/marquee_ids.json)
    EmblemMarquee = A .. "103753711193088", mq_emblem = A .. "103753711193088", mq_emblem_mask = A .. "109449724522035", mq_bulb = A .. "83141090012749",
    mq_star = A .. "135746687596513", mq_corner = A .. "99924595578854", mq_spot = A .. "81141431830546", mq_plate = A .. "134217716310052",
    tex_mq_curtain = A .. "116443925031263", tex_mq_bar = A .. "92701639432479",
    tex_mq_satin = A .. "136685000858086", tex_mq_wool = A .. "121156806831546",   -- (the arms blocks: satin glove, barathea wool sleeve)
}
local ART = Set.Art
local function Tex(key: string, fallback: string): string
    local t = ART[key]
    return (t and t ~= "") and t or fallback
end

local TAU = math.pi * 2
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

local function GunDesc(gun: string): string
    local what = (gun == "PPSH") and "the drum a marquee disc -- a brass sunburst on its face and warm bulbs standing out of its rim -- with a little three-bulb marquee panel on the receiver"
        or "a stepped brass fan plate on the receiver with five warm bulbs on its arc and a velvet pump between stepped brass bands"
    return "An art-deco picture palace: deep piano-black lacquer, champagne brass in raised stepped deco relief -- chevrons, fans, flutes, stepped bands -- and " .. what .. ". The bulbs chase, run faster while you fire and dim for the intermission on a reload. Gold deco-star muzzle, a twinkling tracer, and every kill takes a CURTAIN CALL."
end

-- ===== the guns =====
Set.GunSkins = {
    { Id = "MarqueePPSH", Name = "Marquee PPSh-41", Gun = "PPSH", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("PPSH"),
      Model = "Marquee_PPSH", V3 = true, Color = LUME, Color2 = WARM, Deco = "MarqueeGun", Fit = { G = "PPSH" } },
    { Id = "MarqueeM590", Name = "Marquee 590 Pump", Gun = "M590", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("M590"),
      Model = "Marquee_M590", V3 = true, Color = LUME, Color2 = WARM, Deco = "MarqueeGun", Fit = { G = "M590" } },
}

Set.Build = {}
Set.Build.MarqueeGun = function(model: Model, frame: BasePart, f: any, forView: boolean, H: any)
    -- (nothing extra: the bulbs are Neon parts in the model, coloured by the colourway's bulb light)
end

-- ===== sounds (tools/skins_v3/marquee_sfx.py: each gun's own recorded shot + a soft velvet thump + a short warm hall tail;
-- every moment from CC0 recordings, all screened). =====
Set.Sounds = {
    Fire = { Id = 0, Volume = 0 }, Equip = { Id = 88519280773575, Volume = 0.42 }, MagOut = { Id = 101469060195897, Volume = 0.36 },
    MagIn = { Id = 84517980917197, Volume = 0.36 }, Kill = { Id = 108398336959969, Volume = 0.5 }, Impact = { Id = 113536960234131, Volume = 0.2 },
    Swing = { Id = 102683542727656, Volume = 0.38 }, MeleeHit = { Id = 134450059851999, Volume = 0.42 }, Chase = { Id = 125965112682133, Volume = 0.22 },
    Draw = { Id = 89788223596145, Volume = 0.4 },
    -- (each gun's own full shot; vs the base shot +3.1 / +1.6 dB, then quietened by audio_screen 2.0 / 0.4 dB -> +1.1 / +1.2 dB:
    -- base volumes 0.72 / 0.95 x 0.88 / 0.87)
    FireGun = { PPSH = { Id = 128456488942733, Volume = 0.63 }, M590 = { Id = 80531910261404, Volume = 0.83 } },
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
-- Bulb1..N (the chase groups: PPSh drum 4, 590 fan 5), Marq1..3 (the PPSh receiver panel), Jewel (the cane knob), Sheath /
-- SheathOn (the cane's sheath: 0 = on the blade, 1 = slid off / its visibility). v = rig.SkinVars.
local function BulbKeys(st: any, v: any, now: number, gun: string?, anim: string?, animT: number?, dt: number)
    local ss = st.SinceShot or 99
    local se = st.SinceEquip or 99
    local rl = st.Reload or 0
    local n = (gun == "M590") and 5 or 4
    -- the chase position: slow at rest, fast while firing, fast after the inspect's showtime flash; the 590 also steps on
    -- every pump stroke (each shot)
    local rate = (ss < 0.35) and 9 or 2.2
    if anim == "Inspect" and animT and animT > (v.Present or 0.6) + 0.5 then rate = 7 end
    v.Chase = (v.Chase or 0) + dt * rate
    -- (a new shot = SinceShot reset)
    if gun == "M590" and ss < (v.LastSS or 99) - 0.001 then v.Chase += 1 end
    v.LastSS = ss
    local step = math.floor(v.Chase)
    local function level(i: number, count: number): number
        -- a classic marquee chase: every bulb on, one dark gap travelling round (every other one on the 590's short arc)
        local on = (count == 5) and (((i + step) % 2) == 0) or (((i + step) % count) ~= 0)
        local g = on and 0.95 or 0.28
        -- intermission on the reload: everything dims, then the bulbs come back on in sequence as the magazine seats
        if rl > 0.1 and rl < 0.62 then g = 0.12 end
        if rl >= 0.62 and rl < 0.98 then g = (smooth((rl - 0.62) * 9 - i * 0.6) > 0.5) and g or 0.12 end
        -- curtain up on the draw: on one by one
        if se < 1.0 then g = (se > 0.1 + i * 0.09) and g or 0.05 end
        -- showtime on the inspect's Present: two blinks of everything
        if anim == "Inspect" and animT then
            local t = animT - (v.Present or 0.6)
            if t > 0 and t < 0.5 then g = (math.floor(t * 8) % 2 == 0) and 1 or 0.1 end
        end
        return math.clamp(g, 0, 1)
    end
    for i = 1, 5 do st["Bulb" .. i] = level(i, n) end
    for i = 1, 3 do st["Marq" .. i] = level(i + 1, 3) end
end
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    local v = rig.SkinVars
    local an, at = rig.AnimName, rig.AnimTime
    if rig.Def and rig.Def.IsMelee then
        -- the cane sword: the sheath slides off forward on the draw, comes back for the inspect's sheathe-and-draw
        local se = st.SinceEquip or 99
        local off = smooth((se - 0.08) / 0.32)
        if an == "Inspect" and at then
            local back = smooth((at - 0.35) / 0.35) * (1 - smooth((at - 1.55) / 0.3))
            off = math.min(off, 1 - back)
        end
        st.Sheath = off
        st.SheathOn = 1 - smooth((off - 0.55) / 0.4)
        st.Jewel = math.clamp(0.55 + 0.25 * math.sin(now * TAU / 2.6), 0, 1)
        return
    end
    if an == "Inspect" and rig.Anim and rig.Anim.Beats then v.Present = rig.Anim.Beats.Present or v.Present end
    BulbKeys(st, v, now, rig.GunId, an, at, dt)
end
Set.OnEvent = function(rig: any, name: string, H: any, data: any)
    if name == "Present" then
        PlaySound(H, Set.Sounds.Chase, 1.0)
    elseif name == "MagIn" or name == "PumpForward" then
        PlaySound(H, Set.Sounds.Chase, 1.1)
    end
    if rig.Def and rig.Def.IsMelee and (name == "Raise" or name == "Settle") then
        PlaySound(H, Set.Sounds.Draw, (name == "Raise") and 1.0 or 1.08)
    end
end
Set.OnEquip = function(rig: any, H: any)
    if rig.SkinVars then rig.SkinVars.Chase = math.random() * 4 end
    if rig.Def and rig.Def.IsMelee then PlaySound(H, Set.Sounds.Draw, 1.0) end
    if not Set._Preloaded then
        Set._Preloaded = true
        task.spawn(function()
            local list = {}
            for _, k in ipairs({ "mq_bulb", "mq_star", "mq_spot", "mq_plate", "tex_mq_curtain", "mq_emblem" }) do
                if ART[k] ~= "" then table.insert(list, ART[k]) end
            end
            pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
        end)
    end
end
-- other players' guns: the slow chase
Set.World = function(rec: any, now: number, st: any)
    local v = rec.Vars
    st.SinceShot = 99; st.SinceEquip = 99; st.Reload = 0
    BulbKeys(st, v, now, nil, nil, nil, 1 / 30)
    st.Sheath = 1; st.SheathOn = 0; st.Jewel = 0.6
end

-- ===== muzzle: a warm gold flash + one small deco star card =====
Set.Muzzle = function(rig: any, flash: ParticleEmitter, light: PointLight, muzzle: Attachment, H: any)
    flash.Color = ColorSequence.new(HOT, LUME)
    flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.03) })
    light.Color = LUME
    light.Brightness = 0.6
    rig.Fx.MqStar = H.Emitter(muzzle, { Name = "MqStar", Texture = Tex("mq_star", H.SPARK), Color = { HOT, LUME }, Size = { 0.16, 0.05 },
        Life = { 0.06, 0.09 }, Speed = { 0, 0 }, Spread = 0, Trans = { 0.1, 1 }, Light = 1, Rate = 0 })
    rig.Fx.MqStar.Rotation = NumberRange.new(0, 45)
end
Set.OnFire = function(rig: any, H: any)
    if rig.Fx and rig.Fx.MqStar then rig.Fx.MqStar:Emit(1) end
end

-- ===== tracer: a warm gold line with a twinkling deco star at its head =====
Set.Tracer = function(H: any, from: Vector3, to: Vector3, peer: boolean?)
    local dist = (to - from).Magnitude
    if dist < 1.5 then return end
    local host = H.FxPart({ Transparency = 1, Size = V(0.05, 0.05, 0.05), CFrame = CFrame.new(from) })
    local a0, a1 = H.Att(host, from), H.Att(host, to)
    local core = Instance.new("Beam")
    core.Attachment0, core.Attachment1 = a0, a1
    core.Color = ColorSequence.new(HOT, LUME); core.LightEmission = 1; core.LightInfluence = 0; core.FaceCamera = true; core.Segments = 1
    core.Width0, core.Width1 = 0.012, peer and 0.028 or 0.04
    core.Parent = host
    local head = Instance.new("BillboardGui")
    head.Size = UDim2.fromScale(peer and 0.35 or 0.5, peer and 0.35 or 0.5); head.LightInfluence = 0; head.Adornee = host
    local img = Instance.new("ImageLabel"); img.BackgroundTransparency = 1; img.Size = UDim2.fromScale(1, 1); img.Image = Tex("mq_star", H.Art.Glow or "")
    img.ImageColor3 = LUME; img.Parent = head
    local hp = H.FxPart({ Transparency = 1, Size = V(0.05, 0.05, 0.05), CFrame = CFrame.new(from) })
    head.Adornee = hp; head.Parent = hp
    local dir = (to - from).Unit
    local travel = H.TRAVEL -- (hitscan: the shot is there at once, nothing flies)
    local dur = travel + 0.28
    H.Animate(dur, function(t)
        local hk = math.clamp(t / travel, 0, 1)
        local p = from + dir * dist * hk
        a1.WorldPosition = p
        hp.CFrame = CFrame.new(p)
        img.Rotation = t * 400
        local after = math.max(0, t - travel) / (dur - travel)
        core.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7 + 0.3 * after), NumberSequenceKeypoint.new(1, math.clamp(0.1 + after * 1.6, 0, 1)) })
        img.ImageTransparency = math.clamp(0.1 + after * 1.2, 0, 1)
    end, function() host:Destroy(); hp:Destroy() end)
end

-- ===== impact: an 8-point gold deco starburst stamped on the surface + a little dust =====
Set.Impact = function(H: any, pos: Vector3, normal: Vector3?, peer: boolean?)
    if not H.Budget("MarqueeImpact", peer and 3 or 8, 0.5) then return end
    local n = (normal and normal.Magnitude > 0.1) and normal.Unit or V(0, 1, 0)
    local face = CFrame.lookAt(pos + n * 0.02, pos + n * 2) * CFrame.Angles(0, 0, math.random() * TAU)
    local p = H.FxPart({ Transparency = 1, Size = V(0.2, 0.2, 0.02), CFrame = face })
    local st = Instance.new("Decal")
    st.Texture = Tex("mq_star", ""); st.Face = Enum.NormalId.Front; st.Color3 = LUME; st.Transparency = 0.05
    st.Parent = p
    local att = H.Att(p, pos + n * 0.03)
    local em = H.Emitter(att, { Name = "MqDust", Texture = H.SPARK, Color = { HOT, BRASS }, Size = { 0.05, 0.02 }, Life = { 0.2, 0.35 },
        Speed = { 1.5, 3.2 }, Spread = 40, Trans = { 0.1, 1 }, Light = 0.6, Drag = 4 })
    em.EmissionDirection = Enum.NormalId.Front
    em:Emit(peer and 3 or 5)
    H.Animate(0.55, function(t)
        local k = t / 0.55
        local s = 0.1 + 0.4 * (1 - (1 - math.min(1, k * 3)) ^ 3)
        p.Size = V(s, s, 0.02)
        st.Transparency = math.clamp(0.05 + math.max(0, k - 0.35) * 1.5, 0, 1)
    end, function() p:Destroy() end)
end

-- ===== CURTAIN CALL v2 kill (FX roll-out 2026-10-14; v1 = two curtains + a valance, read as theatrical but small and an
-- empty frame, scored 3). ONE idea: THE FINAL BOW. A gilded marquee arch -- two stepped brass pilasters and a sunburst
-- header, studded with chasing bulbs -- RISES OUT OF THE FLOOR round the body (0.25 s), two velvet curtains drop into it
-- at the sides (framing the body, never across it), a spotlight pool lights the floor, the bulbs chase; on the beat
-- (0.85 s) the bulbs go out in a cascade from the top, the spotlight SNAPS OFF and the whole stage sinks back into the
-- floor. 1.35 s. Self-lit SurfaceGuis on dark lacquer (reads on any floor). Nothing crosses the body: everything stands
-- beside it or above the head. Budget: full 6 parts (2 pilasters, header, 2 curtains, pool); low: pilasters + header + pool. =====
local function LitFace(part: BasePart, face: Enum.NormalId, ppu: number, build: (Frame) -> ())
    local sg = Instance.new("SurfaceGui")
    sg.Face = face; sg.LightInfluence = 0; sg.Brightness = 1.3; sg.AlwaysOnTop = false
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = ppu
    sg.Parent = part
    local root = Instance.new("Frame"); root.BackgroundTransparency = 1; root.Size = UDim2.fromScale(1, 1); root.Parent = sg
    build(root)
    return sg
end
local function MqBody(pos: Vector3, H: any): (CFrame, Vector3)
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
    if best then
        local ok, cf, size = pcall(function() return best:GetBoundingBox() end)
        if ok and size.Magnitude < 20 then return cf, size end
    end
    return CFrame.new(pos - V(0, 1.4, 0)), V(1.8, 3.8, 1.2)
end
Set.Kill = function(H: any, pos: Vector3, low: boolean)
    local g = H.Ground(pos)
    local bcf, bsz = MqBody(pos, H)
    local cam = workspace.CurrentCamera
    local rt = cam and cam.CFrame.RightVector or V(1, 0, 0)
    rt = V(rt.X, 0, rt.Z)
    rt = (rt.Magnitude > 0.05) and rt.Unit or V(1, 0, 0)
    local half = math.clamp(math.max(bsz.X, bsz.Z) * 0.5 + 1.3, 2.1, 3.4)            -- (half the opening's width)
    local tall = math.clamp((bcf.Position.Y + bsz.Y / 2) - g.Y + 0.7, 4.2, 8)          -- (the opening's height, over the head)
    local base = CFrame.fromMatrix(V(bcf.Position.X, g.Y, bcf.Position.Z), rt, V(0, 1, 0)) * CFrame.new(0, 0, -math.min(bsz.X, bsz.Z) * 0.5) -- (+Z toward you)
    local model = Instance.new("Model"); model.Name = "MarqueeKill"; model.Parent = H.FxFolder()
    local bulbs = {} -- { Img, Order (0..1 from the top of the arch) }
    local fades = {}
    local function Bulb(parent, x, y, s, order)
        local b = Instance.new("ImageLabel"); b.BackgroundTransparency = 1; b.Image = Tex("mq_bulb", H.Art.Glow or ""); b.ImageColor3 = LUME
        b.AnchorPoint = Vector2.new(0.5, 0.5); b.Position = UDim2.fromScale(x, y); b.Size = UDim2.fromOffset(s, s); b.ImageTransparency = 1; b.ZIndex = 3
        b.Parent = parent
        table.insert(bulbs, { I = b, O = order })
    end
    local function Lacquer(parent, steps)
        -- a dark lacquer face with a brass stepped border (faceted, ink edged) -- the house icon look
        local face = Instance.new("Frame"); face.BorderSizePixel = 0; face.BackgroundColor3 = P.Lacquer; face.Size = UDim2.fromScale(1, 1)
        face.BackgroundTransparency = 1; face.Parent = parent
        local ink = Instance.new("UIStroke"); ink.Color = P.Dark; ink.Thickness = 6; ink.Transparency = 1; ink.Parent = face
        local brass = Instance.new("UIStroke"); brass.Color = BRASS:Lerp(C(255, 230, 170), 0.3); brass.Thickness = 3; brass.Transparency = 1
        brass.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        local inner = Instance.new("Frame"); inner.BackgroundTransparency = 1; inner.AnchorPoint = Vector2.new(0.5, 0.5); inner.Position = UDim2.fromScale(0.5, 0.5)
        inner.Size = UDim2.new(1, -10, 1, -10); inner.Parent = face; brass.Parent = inner
        table.insert(fades, { F = face, Base = 0.02 }); table.insert(fades, { S = ink, Base = 0 }); table.insert(fades, { S = brass, Base = 0 })
        return face
    end
    -- the pilasters (each a lacquer column with a vertical run of bulbs), the sunburst header
    local PW = 0.55
    local stage = {}
    for _, sd in ipairs({ -1, 1 }) do
        local p = H.FxPart({ Transparency = 1, Size = V(PW, tall, 0.12), CFrame = base }, model)
        LitFace(p, Enum.NormalId.Back, 40, function(r)
            local face = Lacquer(r)
            for k = 1, 6 do Bulb(face, 0.5, 1 - (k - 0.5) / 6, 15, 0.35 + 0.65 * (1 - (k - 0.5) / 6) * 0.9 + 0.1) end
        end)
        table.insert(stage, { P = p, X = sd * (half + PW / 2), Y = tall / 2 })
    end
    local HW, HH = half * 2 + PW * 2 + 0.4, 1.05
    local header = H.FxPart({ Transparency = 1, Size = V(HW, HH, 0.12), CFrame = base }, model)
    LitFace(header, Enum.NormalId.Back, 40, function(r)
        local face = Lacquer(r)
        -- the sunburst: a fan of brass rays from the bottom middle (flat bars, no glow), bulbs along the top edge
        for k = 0, 6 do
            local ray = Instance.new("Frame"); ray.BorderSizePixel = 0; ray.BackgroundColor3 = BRASS:Lerp(C(255, 230, 170), 0.15)
            ray.AnchorPoint = Vector2.new(0.5, 1); ray.Position = UDim2.fromScale(0.5, 0.92); ray.Size = UDim2.new(0, 5, 0.62, 0)
            ray.Rotation = -60 + k * 20; ray.BackgroundTransparency = 1; ray.Parent = face
            table.insert(fades, { F = ray, Base = 0.05 })
        end
        local n = 9
        for k = 1, n do Bulb(face, (k - 0.5) / n, 0.2, 16, 0.15 * math.abs((k - 0.5) / n - 0.5) * 2) end
    end)
    table.insert(stage, { P = header, X = 0, Y = tall + HH / 2 })
    -- the curtains: velvet panels hanging just inside the pilasters (beside the body, never across it)
    local curtains = {}
    if not low then
        for _, sd in ipairs({ -1, 1 }) do
            local c = H.FxPart({ Transparency = 1, Size = V(0.8, tall - 0.2, 0.04), CFrame = base }, model)
            LitFace(c, Enum.NormalId.Back, 30, function(r)
                local im = Instance.new("ImageLabel"); im.BackgroundTransparency = 1; im.Size = UDim2.fromScale(1, 1)
                im.Image = Tex("tex_mq_curtain", ""); im.ImageColor3 = VELVET:Lerp(C(255, 255, 255), 0.18); im.ImageTransparency = 1
                im.ScaleType = Enum.ScaleType.Stretch; im.Parent = r
                table.insert(fades, { I = im, Base = 0.05 })
                local ink = Instance.new("UIStroke"); ink.Color = P.Dark; ink.Thickness = 4; ink.Transparency = 1; ink.Parent = im
                table.insert(fades, { S = ink, Base = 0, Curtain = true })
            end)
            table.insert(curtains, { P = c, X = sd * (half - 0.45), Y = (tall - 0.2) / 2 })
        end
    end
    -- the spotlight pool (self-lit) on the floor
    local spot = H.FxPart({ Transparency = 1, Size = V(half * 2.1, 0.02, half * 2.1), CFrame = CFrame.new(V(bcf.Position.X, g.Y + 0.05, bcf.Position.Z)) }, model)
    local spotImg
    LitFace(spot, Enum.NormalId.Top, 20, function(r)
        spotImg = Instance.new("ImageLabel"); spotImg.BackgroundTransparency = 1; spotImg.Size = UDim2.fromScale(1, 1)
        spotImg.Image = Tex("mq_spot", H.Art.Glow or ""); spotImg.ImageColor3 = P.Spot; spotImg.ImageTransparency = 1; spotImg.Parent = r
    end)
    local dur = low and 1.0 or 1.35
    local BEAT = low and 0.6 or 0.85
    H.Animate(dur, function(t)
        -- 1) the stage rises out of the floor (0 -> 0.25), a little overshoot; 4) sinks back after the beat
        local rise = smooth(t / 0.25)
        local over = 0.25 * math.sin(math.clamp((t - 0.18) / 0.2, 0, 1) * math.pi)
        local sink = smooth((t - BEAT - 0.08) / 0.38)
        local lift = (rise - 1) * (tall + HH) + over - sink * (tall + HH + 0.2)
        for _, st in ipairs(stage) do st.P.CFrame = base * CFrame.new(st.X, st.Y + lift, 0) end
        -- 2) the curtains drop in at the sides (0.2 -> 0.42)
        local drop = smooth((t - 0.2) / 0.22)
        for _, c in ipairs(curtains) do c.P.CFrame = base * CFrame.new(c.X, c.Y + (1 - drop) * tall * 0.6 + lift * 0.0 - sink * (tall + 0.2), 0.08) end
        local a = math.clamp(smooth(t / 0.08) - smooth((t - (dur - 0.2)) / 0.18), 0, 1)
        for _, f in ipairs(fades) do
            local tr = 1 - (1 - f.Base) * a
            if f.I then f.I.ImageTransparency = (f.I.Parent and drop > 0.02) and tr or 1
            elseif f.S then f.S.Transparency = (f.Curtain and drop <= 0.02) and 1 or tr
            else f.F.BackgroundTransparency = tr end
        end
        -- 3) the bulbs: light in a chase as the stage rises, chase while it stands, go out top-down on the beat
        local step = math.floor(t * 12)
        for i, b in ipairs(bulbs) do
            local lit = t > 0.05 + b.O * 0.2
            local chase = ((i + step) % 3) ~= 0
            local out = t > BEAT + b.O * 0.12
            b.I.ImageTransparency = (lit and not out) and ((chase and 0.02 or 0.45) + (1 - a)) or 1
        end
        -- the spotlight: on as the curtains land, SNAPS off on the beat
        if spotImg then
            spotImg.ImageTransparency = (t > 0.22 and t < BEAT) and 0.25 or 1
        end
    end, function() model:Destroy() end)
end


-- ===== the SUNBURST banner (lower right, beside the weapon card): a stepped sunburst plaque with five bulb sockets; each kill
-- in the streak lights one more bulb, at five they chase =====
local banner
local NUMFONT = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold)
local WORDS = { "OPENING", "ENCORE", "BRAVO", "STANDING OVATION", "SHOWSTOPPER" }
-- (socket centres in the 180 x 90 banner: the plaque's fan centre (0.33 W, 0.84 H), radius 0.6 H x 0.93, angles 198..342 deg)
local SOCK = {}
for k = 1, 5 do
    local a = math.rad(180 + 180 * (k - 0.5) / 5)
    SOCK[k] = { 180 * 0.33 + math.cos(a) * 90 * 0.6 * 0.93, 90 * 0.84 + math.sin(a) * 90 * 0.6 * 0.93 }
end
Set.Banner = function(H: any, streak: number)
    local gui, root = H.BannerRoot("Marquee", Vector2.new(180, 90), "Side")
    if not root then return end
    local New = H.New
    if not banner or banner.Root ~= root then
        local plateBg = New("Frame", { BackgroundColor3 = P.Plate, BackgroundTransparency = 0.1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, root,
            { New("UICorner", { CornerRadius = UDim.new(0, 4) }), New("UIStroke", { Color = BRASS, Thickness = 1.5, Transparency = 0.15 }) })
        local plaque = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("mq_plate", ""), ImageColor3 = BRASS, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, root)
        local bulbs = {}
        for i = 1, 5 do
            local b = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("mq_bulb", H.Art.Glow or ""), ImageColor3 = LUME, AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(SOCK[i][1], SOCK[i][2]), Size = UDim2.fromOffset(14, 14), ZIndex = 3, ImageTransparency = 1 }, root)
            bulbs[i] = b
        end
        local num = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(118, 32), Size = UDim2.fromOffset(60, 30),
            FontFace = NUMFONT, TextSize = 28, TextColor3 = P.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 3 }, root)
        num:SetAttribute("KeepFont", true)
        local word = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(118, 62), Size = UDim2.fromOffset(60, 22),
            FontFace = NUMFONT, TextSize = 12, TextColor3 = BRASS, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Text = "", ZIndex = 3 }, root)
        word:SetAttribute("KeepFont", true)
        banner = { Root = root, Bg = plateBg, Plaque = plaque, Bulbs = bulbs, Num = num, Word = word, Token = 0 }
    end
    local b = banner
    b.Token += 1
    local token = b.Token
    local st = math.clamp(streak or 1, 1, 5)
    root.Visible = true
    b.Bg.BackgroundTransparency = 0.1; b.Plaque.ImageTransparency = 0
    b.Num.TextTransparency = 0; b.Word.TextTransparency = 0
    b.Num.Text = "x" .. st
    b.Word.Text = WORDS[st]
    b.Num.TextColor3 = (st >= 5) and LUME or P.Text
    for i, bl in ipairs(b.Bulbs) do bl.ImageTransparency = (i < st) and 0.05 or 0.85 end
    local t0 = os.clock()
    H.Animate(1.6, function(t)
        if b.Token ~= token then return end
        if st >= 5 then
            local step = math.floor(t * 10)
            for i, bl in ipairs(b.Bulbs) do bl.ImageTransparency = ((i + step) % 2 == 0) and 0.02 or 0.7 end
        else
            local nb = b.Bulbs[st]
            nb.ImageTransparency = (t < 0.25) and ((math.floor(t * 16) % 2 == 0) and 0 or 0.6) or 0.02
        end
    end)
    task.delay(1.6, function()
        if b.Token ~= token then return end
        local ti = TweenInfo.new(0.3)
        H.TweenService:Create(b.Bg, ti, { BackgroundTransparency = 1 }):Play()
        H.TweenService:Create(b.Plaque, ti, { ImageTransparency = 1 }):Play()
        H.TweenService:Create(b.Num, ti, { TextTransparency = 1 }):Play()
        H.TweenService:Create(b.Word, ti, { TextTransparency = 1 }):Play()
        for _, bl in ipairs(b.Bulbs) do H.TweenService:Create(bl, ti, { ImageTransparency = 1 }):Play() end
        task.delay(0.32, function() if b.Token == token then root.Visible = false end end)
    end)
end

-- ===== the CANE SWORD (melee, Sword class): WeaponAssets.MeleeModels.Marquee -- a slim steel blade drawn from a black-lacquer
-- cane (the sheath slides off on the draw), a stepped brass collar, an octagonal lacquer grip with brass rings and a stepped
-- brass skyscraper knob with a tiny lit jewel. =====
Set.Melee = {
    Skin = { Name = "Cane Sword", Price = 449, ProductId = 0,
        Desc = "A gentleman's sword cane: a slim steel blade drawn from a black-lacquer cane with a brass ferrule, a stepped brass collar, an octagonal lacquer grip and a stepped brass skyscraper knob set with a tiny lit jewel. The cane slides away on the draw and comes back for the inspect. Every kill takes a CURTAIN CALL." },
    Rig = { Class = "Sword", BladeLen = 1.1 },
    FlatBlade = true,
    Build = function(m: Model, o: any, H: any)
        local parts = H.CloneModel(m, "MeleeModels", "Marquee", VAR, { [1] = LUME })
        local blade = parts.Blade
        if not blade then return end
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Name, a1.Name = "TrailBase", "TrailTip"
        a0.Position = blade.CFrame:PointToObjectSpace(blade.Position - blade.CFrame.UpVector * blade.Size.Y * 0.3)
        a1.Position = blade.CFrame:PointToObjectSpace(blade.Position + blade.CFrame.UpVector * blade.Size.Y * 0.48)
        a0.Parent, a1.Parent = blade, blade
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Color = ColorSequence.new(HOT, LUME)
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
        tr.LightEmission = 0.6; tr.LightInfluence = 0
        tr.Lifetime = 0.12; tr.MinLength = 0.02; tr.FaceCamera = true
        tr.Enabled = false
        tr:SetAttribute("SwingTrail", true)
        tr.Parent = blade
    end,
}

-- ===== arms: EVENING GLOVES + TUXEDO SLEEVES (mesh pieces, WeaponAssets.ArmsModels.Marquee). Glove: black satin with three
-- raised gold "points" lines on the back and a stepped brass deco band at the wrist; ONE effect: a tiny diamond on the band
-- catches a brief star twinkle every few seconds. Sleeve: a black tuxedo sleeve with a satin stripe (gold piping) down the
-- outer arm, a starched ivory shirt cuff and a stepped brass cufflink. =====
Set.Glove = function(K: any)
    local V3 = K.V
    return {
        Id = "EveningGloves", Name = "Evening Gloves", Price = 449,
        Desc = "Black satin evening gloves with three raised gold points on the back and a stepped brass deco band at the wrist, set with a tiny diamond that catches a star twinkle now and then, brighter on a kill. Part of the Marquee set.",
        Base = { Color = P.Satin, Material = Enum.Material.SmoothPlastic, Reflectance = 0, Tex = "tex_mq_satin", TexTile = 1.6, TexT = 0, TexColor = P.Satin:Lerp(C(255, 255, 255), 0.13) },
        Parts = {
            { Mesh = "Marquee/Back", MeshV = VAR, Size = V3(0.9, 0.09, 0.78), Off = V3(0, 0.53, 0.02) },
            { Mesh = "Marquee/Band", MeshV = VAR, Size = V3(1.18, 1.18, 0.2), Off = V3(0, 0, 0.42) },
            { Mesh = "Marquee/Diamond", MeshV = VAR, Size = V3(0.09, 0.09, 0.12), Off = V3(0, 0.6, 0.42), Seat = true,
              Glow = true, Color = LUME, Anim = "Twinkle", Period = 4.5, Dur = 0.45, PulseMin = 0.05, PulseMax = 0.8 },
        },
    }
end
Set.Sleeve = function(K: any)
    local V3 = K.V
    return {
        Id = "TuxedoSleeves", Name = "Tuxedo Sleeves", Price = 299,
        Desc = "A black tuxedo sleeve with a satin stripe piped in gold down the outer arm, a starched ivory shirt cuff and a stepped brass deco cufflink. Part of the Marquee set.",
        Base = { Color = P.Satin, Material = Enum.Material.SmoothPlastic, Reflectance = 0, Tex = "tex_mq_wool", TexTile = 2.0, TexT = 0, TexColor = P.Satin:Lerp(C(255, 255, 255), 0.1) },
        Parts = {
            { Mesh = "Marquee/Stripe", MeshV = VAR, Size = V3(0.4, 0.07, 0.9), Off = V3(0, 0.52, 0.04), Seat = true },
            { Mesh = "Marquee/Cuff", MeshV = VAR, Size = V3(1.14, 1.14, 0.2), Off = V3(0, 0, -0.38) },
            { Mesh = "Marquee/Link", MeshV = VAR, Size = V3(0.12, 0.12, 0.06), Off = V3(-0.58, 0, -0.38), Rot = V3(0, 90, 0), Seat = true },
        },
    }
end

-- ===== health bar (BARS v2, FX roll-out): the house ink frame round a champagne-gold marquee fill with a row of bulbs
-- running inside it; lost health holds for a beat then goes out in three clicks, like a sign switching off; every hit
-- makes the bulbs blink; elites / bosses add a stepped brass end cap =====
Set.Bar = { Id = "Marquee", Name = "Marquee", Price = 149,
    Desc = "A marquee sign of a health bar: a champagne-gold fill with a row of warm bulbs chasing inside it. Lost health holds for a beat, then switches off in three clicks, and every hit makes the bulbs blink. On elites and bosses a stepped brass cap ends it. Part of the Marquee set.",
    Look = "Ink", FillColor = WARM:Lerp(BRASS, 0.45), ChipMotion = "Snap", Chip = HOT, Back = P.Plate, Segments = 0, Decor = { "Bulbs", "DecoCap" } }
Set.BarDecor = {
    Bulbs = function(ctx: any, K: any)
        local f = K.Fader()
        local bulbs = {}
        local n = (ctx.Tier == "Small") and 6 or 12
        for i = 1, n do
            local b = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = HOT, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6 }, ctx.Inner)
            K.New("UICorner", { CornerRadius = UDim.new(0.5, 0) }, b)
            K.New("UIStroke", { Color = P.Dark, Thickness = 1.5 }, b)
            bulbs[i] = b
        end
        local lastHit, blinkT = 0, 99
        return function(now, dt, alpha, info)
            if (info.Hit or 0) > lastHit + 0.05 then blinkT = 0 end
            lastHit = info.Hit or 0
            blinkT += dt
            local step = math.floor(now * 4)
            local s = math.max(3, math.floor(ctx.H * 0.5))
            for i, b in ipairs(bulbs) do
                b.Size = UDim2.fromOffset(s, s)
                b.Position = UDim2.fromScale((i - 0.5) / n, 0.5)
                local on = ((i + step) % 3) ~= 0
                if blinkT < 0.3 then on = (math.floor(blinkT * 14) % 2 == 0) end
                b.BackgroundTransparency = 1 - alpha * (on and 1 or 0.35)
            end
        end
    end,
    DecoCap = function(ctx: any, K: any)
        if ctx.Tier == "Small" then return function() end end
        local steps = {}
        for k = 1, 3 do
            local st = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = BRASS:Lerp(C(255, 230, 170), 0.35 - k * 0.08), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 10 }, ctx.Holder)
            K.New("UIStroke", { Color = P.Dark, Thickness = 1.5 }, st)
            steps[k] = st
        end
        return function(now, dt, alpha, info)
            for k, st in ipairs(steps) do
                st.Size = UDim2.fromOffset(math.max(3, ctx.H * 0.35), ctx.H * (1.6 - (k - 1) * 0.35))
                st.Position = UDim2.fromOffset(ctx.W + 2 + (k - 1) * ctx.H * 0.38, ctx.H / 2)
                st.BackgroundTransparency = 1 - alpha
            end
        end
    end,
}

-- ===== UI theme v2 (FX roll-out 2026-10-14; v1 = the shared template: a deco corner sprite + watermark + sparkles + a
-- flare). Its own pieces, in the icon look: every window is a MARQUEE -- a row of warm bulbs runs along the top edge and
-- chases slowly (one in three dark), stepped brass deco brackets (three faceted steps, ink edged) sit in the four corners;
-- OPEN = the curtain goes up: two velvet curtains cover the window and part to the sides as the bulbs light from the middle
-- out (0.5 s). Title bars get a stepped gold chevron. Colours from the theme table (Brass / Bulb / Velvet / Ink).
local function MqFacet(ctx, o, lit, shade, inkW)
    local g = Instance.new("UIGradient")
    g.Color = ctx.UIStyle.Facet(lit, shade)
    g.Rotation = ctx.UIStyle.FACET_ROT or 35
    g.Parent = o
    local ink = ctx.UIStyle.InkEdge(inkW or 2)
    ink.Parent = o
end
local function MqDeco(ctx)
    if ctx.Kind ~= "Window" then return nil end
    local t = ctx.Theme
    local host = ctx.Root or ctx.Surface
    local f = Instance.new("Frame")
    f.Name = "MqOverlay"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 20; f.Active = false
    f:SetAttribute("NoSkin", true); f:SetAttribute("Skinned", true)
    f.Parent = host
    local small = math.min(host.AbsoluteSize.X, host.AbsoluteSize.Y) < 260
    -- stepped deco brackets: three brass steps in each corner
    local st = small and 4 or 6
    for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
        for k = 1, 3 do
            local L = (small and 14 or 30) - (k - 1) * (small and 4 or 8)
            for i = 1, 2 do
                local b = Instance.new("Frame")
                b.Name = "MqStep"; b.BorderSizePixel = 0; b.BackgroundColor3 = Color3.new(1, 1, 1); b.ZIndex = f.ZIndex + 1
                b.AnchorPoint = Vector2.new(c[1], c[2])
                local o = 4 + (k - 1) * (st + 2)
                b.Position = UDim2.new(c[1], (c[1] == 0) and o or -o, c[2], (c[2] == 0) and o or -o)
                b.Size = (i == 1) and UDim2.fromOffset(L, st) or UDim2.fromOffset(st, L)
                b.Parent = f
                MqFacet(ctx, b, t.BrassFace, t.BrassShade, 1)
            end
        end
    end
    -- the bulb row along the top edge
    local n = small and 6 or math.clamp(math.floor(host.AbsoluteSize.X / 46), 8, 26)
    local bs = small and 7 or 11
    local bulbs = {}
    for i = 1, n do
        local b = Instance.new("Frame")
        b.Name = "MqBulb"; b.BorderSizePixel = 0; b.BackgroundColor3 = t.Bulb; b.AnchorPoint = Vector2.new(0.5, 0.5)
        b.Position = UDim2.new((i - 0.5) / n * 0.7 + 0.15, 0, 0, small and 5 or 8); b.Size = UDim2.fromOffset(bs, bs); b.ZIndex = f.ZIndex + 2; b.Parent = f
        local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0.5, 0); cr.Parent = b
        local ink = Instance.new("UIStroke"); ink.Color = t.Ink; ink.Thickness = 2; ink.Parent = b
        bulbs[i] = b
    end
    f:SetAttribute("MqHouse", 1)
    return function(now, dt)
        local house = f:GetAttribute("MqHouse") or 1
        local step = math.floor(now * 3)
        for i, b in ipairs(bulbs) do
            local fromMid = math.abs((i - 0.5) / n - 0.5) * 2
            local lit = house >= fromMid
            local on = ((i + step) % 3) ~= 0
            b.BackgroundColor3 = (lit and on) and t.Bulb or t.BulbOff
        end
    end, { f }
end
local function MqOpen(ctx)
    -- THE CURTAIN GOES UP: two velvet curtains cover the window and part to the sides; the bulbs light from the middle out
    local t = ctx.Theme
    local f = ctx.Root and ctx.Root:FindFirstChild("MqOverlay")
    if not f then return end
    local halves = {}
    for i, ax in ipairs({ 0, 1 }) do
        local c = Instance.new("Frame")
        c.Name = "MqCurtain"; c.BorderSizePixel = 0; c.BackgroundColor3 = Color3.new(1, 1, 1); c.AnchorPoint = Vector2.new(ax, 0)
        c.Position = UDim2.fromScale(ax, 0); c.Size = UDim2.fromScale(0.5, 1); c.ZIndex = f.ZIndex + 4; c.Parent = f
        local g = Instance.new("UIGradient"); g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, t.VelvetFace), ColorSequenceKeypoint.new(0.5, t.VelvetShade),
            ColorSequenceKeypoint.new(1, t.VelvetFace) }); g.Parent = c
        local ink = ctx.UIStyle.InkEdge(2); ink.Parent = c
        local fringe = Instance.new("Frame")
        fringe.BorderSizePixel = 0; fringe.BackgroundColor3 = t.BrassFace; fringe.AnchorPoint = Vector2.new(1 - ax, 0)
        fringe.Position = UDim2.fromScale(1 - ax, 0); fringe.Size = UDim2.new(0, 4, 1, 0); fringe.ZIndex = c.ZIndex + 1; fringe.Parent = c
        halves[i] = { F = c, AX = ax }
    end
    local t0 = os.clock()
    f:SetAttribute("MqHouse", 0)
    local conn
    conn = game:GetService("RunService").RenderStepped:Connect(function()
        local k = math.clamp((os.clock() - t0) / 0.5, 0, 1)
        if not f.Parent then conn:Disconnect() return end
        local e = k * k * (3 - 2 * k)
        for _, h in ipairs(halves) do
            -- (the curtains are gathered up and away: they shrink to the sides and lift a little)
            h.F.Size = UDim2.fromScale(0.5 * (1 - e), 1 - 0.3 * e)
            h.F.BackgroundTransparency = math.max(0, e - 0.6) / 0.4
        end
        f:SetAttribute("MqHouse", math.clamp((k - 0.1) / 0.6, 0, 1))
        if k >= 1 then conn:Disconnect(); for _, h in ipairs(halves) do h.F:Destroy() end; f:SetAttribute("MqHouse", 1) end
    end)
end
local function MqTitle(ctx)
    -- a gold rule under the title ending in three stepped deco uprights (rising), clear of the subtitle text
    local bar, t = ctx.Title, ctx.Theme
    local rule = Instance.new("Frame")
    rule.Name = "MqRule"; rule.BorderSizePixel = 0; rule.BackgroundColor3 = t.BrassFace; rule.AnchorPoint = Vector2.new(0, 1)
    rule.Position = UDim2.new(0, 10, 1, -1); rule.Size = UDim2.new(0.26, 0, 0, 2); rule.ZIndex = bar.ZIndex + 1; rule.Parent = bar
    local made = { rule }
    for k = 1, 3 do
        local s = Instance.new("Frame")
        s.Name = "MqStep"; s.BorderSizePixel = 0; s.BackgroundColor3 = t.BrassFace; s.AnchorPoint = Vector2.new(0, 1)
        s.Position = UDim2.new(0.26, 14 + (k - 1) * 6, 1, -1); s.Size = UDim2.fromOffset(3, 3 + k * 3); s.ZIndex = bar.ZIndex + 1; s.Parent = bar
        table.insert(made, s)
    end
    return made
end
-- numbers v3 (SKIN UI roll-out 2026-10-29, owner: numbers "unique to the skin and the colorways you have equipped"; the old row
-- of bulbs UNDER the number read like the Silkfang underline): IN LIGHTS. A wide deco face (Michroma) that flickers on like a
-- marquee letter, with ONE small marquee bulb at its top-right corner that flashes on every (merged) hit and dims back
-- (coordinator 2026-10-29: a bulb ring on every number made 4 hits a cloud of dots -- the ring is for crits and kills only).
-- CRIT = SHOWTIME: a RING OF BULBS switches on round the digits, every bulb blinks twice, then a fast chase (a dark gap
-- travelling round), a deco star stands behind the digits and they glow warm; WEAK SPOT = a ★ leads the digits; a KILL = CURTAIN CALL: the bulbs all hold on white-hot and the ring bursts
-- outward as a spotlight blooms behind the number. Every colour is this copy's palette (P = the colourway: Opening Night warm gold, Emerald Room, Silver Screen cool white).
local MQ_BULBS = 8
local function MqMotion(e, age, pa, life)
    local rise = 1 - (1 - math.min(1, age / 0.85)) ^ 3
    local flick = (pa < 0.16) and ((math.floor(pa * 40) % 3 == 0) and 0.5 or 0) or 0
    return 0.4 + rise * 1.3, 0, 1, 0, flick, 0
end
local function MqAccent(e)
    local box = Instance.new("Frame")
    box.Name = "MqLights"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 0
    local spot = Instance.new("ImageLabel")
    spot.Name = "Spot"; spot.BackgroundTransparency = 1; spot.Image = Tex("mq_spot", ""); spot.AnchorPoint = Vector2.new(0.5, 0.5)
    spot.Position = UDim2.fromScale(0.5, 0.5); spot.ScaleType = Enum.ScaleType.Fit; spot.ZIndex = 0; spot.Parent = box
    local star = Instance.new("ImageLabel")
    star.Name = "Star"; star.BackgroundTransparency = 1; star.Image = Tex("mq_star", ""); star.AnchorPoint = Vector2.new(0.5, 0.5)
    star.Position = UDim2.fromScale(0.5, 0.5); star.ScaleType = Enum.ScaleType.Fit; star.ZIndex = 0; star.Parent = box
    local pip = Instance.new("Frame") -- (the one bulb every number carries)
    pip.Name = "Pip"; pip.BorderSizePixel = 0; pip.AnchorPoint = Vector2.new(0.5, 0.5); pip.Size = UDim2.fromOffset(5, 5); pip.ZIndex = 2
    local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0.5, 0); pc.Parent = pip
    local ps = Instance.new("UIStroke"); ps.Thickness = 1; ps.Parent = pip
    pip.Parent = box
    for i = 1, MQ_BULBS do
        local b = Instance.new("Frame")
        b.Name = "B" .. i; b.BorderSizePixel = 0; b.AnchorPoint = Vector2.new(0.5, 0.5); b.Size = UDim2.fromOffset(4, 4); b.ZIndex = 2
        local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0.5, 0); cr.Parent = b
        b.Parent = box
    end
    return box
end
local function MqAccentStep(e, box, age, pa, alpha)
    local tb = e.Label.TextBounds
    local crit = e.Crit and not e.Dot
    local killT = (e.Killed and e.KillAt) and (os.clock() - e.KillAt) or -1
    -- (a kill: CURTAIN CALL -- every bulb holds on white-hot and the ring bursts outward as the spotlight blooms)
    local burst = (killT >= 0) and smooth(killT / 0.45) or 0
    local rx, ry = (tb.X / 2 + 9) * (1 + 0.7 * burst), (tb.Y / 2 + 6) * (1 + 1.1 * burst)
    local step = math.floor(age * (crit and 22 or 11))
    local off = P.Brass:Lerp(P.Dark, 0.5)
    local ring = (crit or killT >= 0) and not e.Dot
    local pip = box:FindFirstChild("Pip")
    if pip then
        pip.Visible = not e.Dot and not ring
        if pip.Visible then
            local f = math.exp(-pa * 9) -- (flashes on each hit, dims back)
            pip.Position = UDim2.new(0.5, math.floor(tb.X / 2 + 5), 0.5, math.floor(-tb.Y / 2 + 3))
            pip.BackgroundColor3 = P.Lume:Lerp(P.Hot, f)
            pip.BackgroundTransparency = math.clamp(alpha + 0.35 * (1 - f), 0, 1)
            local st = pip:FindFirstChildOfClass("UIStroke"); if st then st.Color = P.Brass; st.Transparency = math.clamp(alpha + 0.2, 0, 1) end
        end
    end
    for i = 1, MQ_BULBS do
        local b = box:FindFirstChild("B" .. i)
        if b then
            b.Visible = ring
            local a = (i - 1) / MQ_BULBS * math.pi * 2 - math.pi / 2
            b.Position = UDim2.new(0.5, math.floor(math.cos(a) * rx), 0.5, math.floor(math.sin(a) * ry))
            local lit = pa > (i - 1) * 0.02 -- (they switch on round the ring)
            if crit and age < 0.4 then lit = lit and (math.floor(age / 0.1) % 2 == 0) -- (showtime: two blinks)
            elseif killT < 0 then lit = lit and ((i + step) % 5 ~= 0) end -- (the chase: a dark gap travels round)
            b.BackgroundColor3 = lit and ((killT >= 0) and P.Hot or P.Lume) or off
            -- (bright while the sign lights up / on a crit or kill, then the ring settles back so the digits lead)
            local rest = (killT >= 0) and 0.7 * smooth((killT - 0.3) / 0.4) or 0.5 * smooth((age - 0.45) / 0.3)
            b.BackgroundTransparency = math.clamp((lit and alpha or alpha + 0.35) + rest, 0, 1)
        end
    end
    local star = box:FindFirstChild("Star")
    if star then
        star.Visible = crit
        if crit then
            local k = smooth(age / 0.16)
            local sz = math.floor((tb.Y + 26) * (0.7 + 0.45 * k))
            star.Size = UDim2.fromOffset(sz, sz); star.Rotation = age * 25
            star.ImageColor3 = P.Brass:Lerp(P.Lume, 0.5); star.ImageTransparency = math.clamp(alpha + 0.3, 0, 1)
        end
    end
    local spot = box:FindFirstChild("Spot")
    if spot then
        spot.Visible = killT >= 0 and not e.Dot
        if spot.Visible then
            local k = smooth(killT / 0.3)
            local sz = math.floor((tb.X + 50) * (0.6 + 0.6 * k))
            spot.Size = UDim2.fromOffset(sz, sz)
            spot.ImageColor3 = P.Spot; spot.ImageTransparency = math.clamp(alpha + 0.5 * smooth((killT - 0.35) / 0.6), 0, 1)
        end
    end
end
-- ===== UI THEME v4 (SKIN UI THEMES roll-out 2026-10-29): the clean language in this colourway's lacquer + brass (UITheme
-- Clean) + the picture palace. Hooks read only the palette they are given (a colourway copy shares these functions):
--   TAB MARK  the underline is a BRASS RULE set with five tiny marquee bulbs; on the top bar they chase
--   FIELD     an art-deco SUNBURST rises from the bottom centre of the screen: stepped brass rays fanning out of a half sun,
--             a bulb arc round it whose lights chase slowly
local MQ_CLEAN = {
    Field = P.Dark:Lerp(P.Lacquer, 0.5):Lerp(P.Velvet, 0.06), Surface = P.Satin:Lerp(P.Velvet, 0.08), Raised = P.Lacquer:Lerp(P.Velvet, 0.14):Lerp(P.Brass, 0.05),
    Hover = P.Lacquer:Lerp(P.Brass, 0.14):Lerp(P.Velvet, 0.1), Well = P.Dark, Line = P.Lacquer:Lerp(P.Brass, 0.35), Tip = P.Plate,
    Accent = P.Lume, Mark = P.Brass:Lerp(P.Lume, 0.5), Hair = P.Brass:Lerp(P.Lume, 0.25),
    Text = P.Text, Sub = P.Text:Lerp(P.Brass, 0.4), Muted = P.Brass:Lerp(P.Text, 0.25), Ink = P.Dark,
    Brass = P.Brass, BrassLit = P.Brass:Lerp(P.Lume, 0.5), Bulb = P.Lume, BulbOff = P.Brass:Lerp(P.Dark, 0.55), Velvet = P.Velvet, Spot = P.Spot,
}
-- (HudThemes.Variant keeps a colourway copy's Clean colour only when it DIFFERS from colourway 1's; one that is the same in
-- both palettes (the gold, a shared brass ...) went through the hue map instead -- Indigo's gold seam came out green. A
-- hair's difference keeps this copy's own colour.)
if VAR ~= 1 then for k, v in pairs(MQ_CLEAN) do if typeof(v) == "Color3" then MQ_CLEAN[k] = v:Lerp(Color3.new(0, 0, 0), 0.003) end end end
MQ_CLEAN.TabMark = function(mark, Q)
    -- (children of a tab mark: offset-sized, inside the mark's width -- tab buttons are AutomaticSize X)
    local g = Instance.new("UIGradient")
    g.Name = "MqBrass"; g.Rotation = 90; g.Color = ColorSequence.new(Q.BrassLit:Lerp(Color3.new(1, 1, 1), 0.2), Q.Brass)
    g.Parent = mark
    local made = { g }
    for i = 1, 5 do
        local b = Instance.new("Frame")
        b.Name = "MqBulb" .. i; b.BorderSizePixel = 0; b.BackgroundColor3 = Q.Bulb; b.Size = UDim2.fromOffset(4, 4)
        b.Position = UDim2.new((i - 0.5) / 5, -2, 0, -1); b.ZIndex = mark.ZIndex + 1; b.Parent = mark
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = b
        table.insert(made, b)
    end
    return made
end
MQ_CLEAN.Sig = function(ctx)
    local Q, f = ctx.P, ctx.Frame
    local cam = workspace.CurrentCamera
    local vh = cam and cam.ViewportSize.Y or 800
    local R = math.clamp(math.floor(vh * 0.36), 150, 320)
    local sun = Instance.new("Frame")
    sun.Name = "MqSunburst"; sun.BackgroundTransparency = 1; sun.AnchorPoint = Vector2.new(0.5, 1); sun.Position = UDim2.fromScale(0.5, 1)
    sun.Size = UDim2.fromOffset(R * 2 + 20, R + 10); sun.ClipsDescendants = true; sun.ZIndex = 0; sun.Parent = f
    local o = Vector2.new(R + 10, R + 10)
    -- the rays: 11 of them over the half circle, long and short in turn (stepped deco)
    for i = 0, 10 do
        local a = math.rad(180 + 9 + i * 16.2)
        local len = (i % 2 == 0) and R or R * 0.78
        local r0 = R * 0.22
        local dir = Vector2.new(math.cos(a), math.sin(a))
        local mid = o + dir * (r0 + (len - r0) / 2)
        local ray = Instance.new("Frame")
        ray.Name = "Ray"; ray.BorderSizePixel = 0; ray.BackgroundColor3 = Q.Brass; ray.BackgroundTransparency = (i % 2 == 0) and 0.7 or 0.8
        ray.AnchorPoint = Vector2.new(0.5, 0.5); ray.Position = UDim2.fromOffset(mid.X, mid.Y); ray.Size = UDim2.fromOffset(len - r0, (i % 2 == 0) and 2 or 1)
        ray.Rotation = math.deg(a); ray.ZIndex = 0; ray.Parent = sun
        local g = Instance.new("UIGradient")
        g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
        g.Parent = ray
    end
    -- the half sun at the foot, two stepped rings
    for i, rr in ipairs({ R * 0.18, R * 0.24 }) do
        local d = Instance.new("Frame")
        d.Name = "Sun" .. i; d.AnchorPoint = Vector2.new(0.5, 0.5); d.Position = UDim2.fromOffset(o.X, o.Y); d.Size = UDim2.fromOffset(rr * 2, rr * 2)
        d.BackgroundColor3 = Q.Velvet; d.BackgroundTransparency = (i == 1) and 0.55 or 1; d.ZIndex = 0
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = d
        local st = Instance.new("UIStroke"); st.Color = Q.BrassLit; st.Thickness = (i == 1) and 2 or 1; st.Transparency = 0.45; st.Parent = d
        d.Parent = sun
    end
    -- the bulb arc
    local bulbs = {}
    local N = 15
    for i = 0, N - 1 do
        local a = math.rad(180 + 6 + i * (168 / (N - 1)))
        local p = o + Vector2.new(math.cos(a), math.sin(a)) * (R * 0.5)
        local b = Instance.new("Frame")
        b.Name = "Bulb"; b.BorderSizePixel = 0; b.AnchorPoint = Vector2.new(0.5, 0.5); b.Position = UDim2.fromOffset(p.X, p.Y); b.Size = UDim2.fromOffset(5, 5)
        b.BackgroundColor3 = Q.Bulb; b.ZIndex = 1
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = b
        b.Parent = sun
        bulbs[i + 1] = b
    end
    local lastStep = -1
    return function(now, _dt)
        -- the chase: two dark gaps travel round the arc (only repainted when the step changes, ~6 times a second)
        local step = math.floor(now * 6)
        if step ~= lastStep then
            lastStep = step
            for i, b in ipairs(bulbs) do
                local on = ((i + step) % 7) ~= 0
                b.BackgroundColor3 = on and Q.Bulb or Q.BulbOff
                b.BackgroundTransparency = on and 0.25 or 0.5
            end
            for _, m in ipairs(ctx.Marks()) do
                if m.Visible then
                    for i = 1, 5 do
                        local b = m:FindFirstChild("MqBulb" .. i)
                        if b then b.BackgroundColor3 = (((i + step) % 3) ~= 0) and Q.Bulb or Q.BulbOff end
                    end
                end
            end
        end
    end, nil
end
local P1 = PALETTES[1]
local function PG(top, bottom) return { Top = top, Bottom = bottom } end
Set.Theme = { Name = "Marquee", Desc = "Every menu is a picture palace in your colourway's lacquer and brass: an art-deco sunburst rises from the foot of the screen with a ring of bulbs chasing round it, and every tab is underlined with a brass rule of tiny chasing bulbs.",
    Panel = PG(C(26, 20, 24), C(8, 6, 8)), Card = PG(C(34, 26, 30), C(12, 9, 11)), Title = PG(C(120, 20, 40), C(40, 6, 14)),
    Accent = C(220, 180, 110), Accent2 = C(255, 226, 170), HpFill = C(255, 210, 130), HpBg = C(20, 12, 14), XpFill = C(255, 226, 170), Text = C(250, 236, 210),
    BrassFace = C(226, 186, 116), BrassShade = P1.Brass, Bulb = P1.Lume, BulbOff = C(70, 52, 34), VelvetFace = P1.Velvet:Lerp(C(255, 255, 255), 0.1),
    VelvetShade = P1.Velvet:Lerp(C(0, 0, 0), 0.45), Ink = C(10, 6, 6),
    Emblem = "EmblemMarquee", BorderThick = 2,
    Deco = MqDeco, OpenFn = MqOpen, TitleDeco = MqTitle,
    Clean = MQ_CLEAN, -- (SKIN UI THEMES: the clean lacquer + brass palette + bulb tab marks + the deco sunburst; the old art is not drawn)
    -- (SKIN UI 2026-10-29: in lights -- one bulb per number; crit = showtime (a chasing bulb ring + a deco star), kill = ring burst + a spotlight)
    Numbers = { Font = "Michroma", Glyph = "★", NoBang = true, Motion = MqMotion, Accent = MqAccent, AccentStep = MqAccentStep,
        Normal = P.Text, Crit = P.Warm, Weak = P.Lume, Stroke = P.Dark, StrokeThick = 2 } }

-- (the HUD colours of a colourway copy: Emerald Room's hue map turns every hue 100 deg, so its fixed brass / bulb colours
-- came out magenta; take them from this palette, a hair apart from colourway 1's so the hue map leaves them)
if VAR ~= 1 then
    local function O(c) return c:Lerp(Color3.new(0, 0, 0), 0.003) end
    local T = Set.Theme
    T.Accent, T.Accent2, T.HpFill, T.XpFill, T.Text = O(P.Brass:Lerp(P.Lume, 0.6)), O(P.Lume), O(P.Lume:Lerp(P.Warm, 0.3)), O(P.Lume), O(P.Text)
    T.BrassFace, T.Bulb = O(P.Brass:Lerp(P.Lume, 0.55)), O(P.Lume)
end

-- ===== bundle / kill effect / store hero =====
Set.KillEffect = { Id = "CurtainCall", Name = "Curtain Call", Image = Tex("mq_emblem", ""),
    How = "Own any Marquee skin (or the Marquee bundle)",
    Desc = "The final bow: a gilded marquee arch studded with chasing bulbs rises out of the floor round the body, velvet curtains drop in at its sides under a spotlight, then the bulbs go out top-down, the spotlight snaps off and the stage sinks away. With the sunburst banner whose bulbs light one per kill." }
Set.Bundle = { Id = "MarqueeBundle", Name = "Marquee Bundle", Price = 1799, BP = 699, ProductId = 0,
    Desc = "The whole Marquee set: the Marquee PPSh-41 and 590 Pump, the Cane Sword, Evening Gloves + Tuxedo Sleeves, the Marquee health bar, the Marquee UI theme and the Curtain Call kill effect.",
    Contents = { "WeaponSkin:MarqueePPSH", "WeaponSkin:MarqueeM590", "MeleeSkin:Marquee", "Glove:EveningGloves", "Sleeve:TuxedoSleeves",
        "HealthBar:Marquee", "KillEffect:CurtainCall" } }
Set.Hero = { Grad = { C(70, 14, 28), C(10, 6, 8) }, Stroke = LUME, Emblem = Tex("mq_emblem", ""), Name = C(250, 236, 210), Chip = C(120, 20, 40) }

return Set
