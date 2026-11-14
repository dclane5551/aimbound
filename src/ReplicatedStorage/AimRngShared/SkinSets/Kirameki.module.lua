--!nocheck
-- ===================================================================================================================
-- KIRAMEKI (Skins V3, the ANIME line's pilot; skins12): USAS-12 + PX4 Storm + Arc Projector | set melee | arms.
-- Owner: an anime bundle "like CS Temukau but in our style with custom effects, animations, tracers etc" -- NO character art:
-- bold INK LINEWORK (inverted-hull outline parts "Ink*"), CEL-SHADED flat colour panels (hard value bands in the paint),
-- manga screentone + speed lines, big hand-lettered SFX (our own katakana lettering), hot magenta / electric yellow /
-- white / ink, a star / heart / lightning motif. tools/skins_v3/kirameki_build.py, tools/make_kirameki_art.py.
--   INSPECT  "power-up": the ink outlines light up into a glowing aura (Neon in the palette's Glow), then settle back to ink
-- USAS-12 + PX4 Storm + Arc Projector built; HELD.
-- ===================================================================================================================
local Set = { Kind = "Kirameki" }

local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local V = Vector3.new
local PALETTES = {
    { Name = "Kirameki", Body = C(204, 26, 112), Plum = C(62, 26, 66), Card = C(236, 230, 238), Ink = C(16, 8, 22), Glow = C(255, 90, 180), Hot = C(255, 230, 120), Star = C(255, 214, 40), Pink = C(255, 60, 150) },
    { Name = "Lemon Soda", Body = C(238, 190, 24), Plum = C(70, 40, 30), Card = C(238, 234, 226), Ink = C(18, 10, 14), Glow = C(255, 226, 80), Hot = C(255, 250, 200), Star = C(255, 72, 150), Pink = C(255, 72, 150) },
    { Name = "Midnight Idol", Body = C(70, 34, 130), Plum = C(34, 22, 60), Card = C(232, 226, 246), Ink = C(10, 6, 20), Glow = C(150, 240, 255), Hot = C(225, 250, 255), Star = C(255, 96, 190), Pink = C(255, 96, 190) },
}
local P = PALETTES[VAR] or PALETTES[1]
Set.Palettes = PALETTES
Set.Colors = { Glow = P.Glow, Hot = P.Hot, Accent = P.Star, Mid = P.Pink }

-- art (tools/make_kirameki_art.py, uploaded as decals; IMAGE ids resolved in Studio)
local A = "rbxassetid://"
Set.Art = {
    kr_sfx_dodon = A .. "94295242227126", kr_sfx_bang = A .. "122572110227598", kr_sfx_kira = A .. "108436752152706", kr_tone = A .. "101118152224644", kr_star = A .. "72995212196862",
    kr_heart = A .. "97422292152012", kr_speed = A .. "82641313126289", tex_kr_dots = A .. "70813985514222", tex_kr_bar = A .. "79555877133695", kr_burst = A .. "107426486554598", kr_spark = A .. "81202451963828",
}
local ART = Set.Art
local function Tex(key: string, fallback: string): string
    local t = ART[key]
    if t and t ~= A .. "0" then return t end
    return fallback
end
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local GLOW, HOT, STAR, PINK, INK = P.Glow, P.Hot, P.Star, P.Pink, P.Ink
local TAU = math.pi * 2

Set.GunSkins = {
    { Id = "KiramekiUSAS12", Name = "Kirameki Komrad 12", Gun = "USAS12", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = "Anime cel-shaded: hot magenta in flat colour panels with bold ink outlines, sharp white armour plates, a yellow lightning bolt and a hand-lettered DODON! on the receiver, screentone and speed lines down the stock. On the inspect the ink outlines power up into a glowing aura.",
      Model = "Kirameki_USAS12", V3 = true, Color = P.Glow, Color2 = P.Star, Deco = "KiramekiGun", Fit = { G = "USAS12", N = 3 } },
    { Id = "KiramekiPX4", Name = "Kirameki PX4 Storm", Gun = "PX4", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = "Anime cel-shaded: a hot magenta slide over an ink-plum frame with bold ink outlines, a white armour plate on the slide lettered BANG!, a yellow lightning bolt under it and a star on the grip. On the inspect the ink outlines power up into a glowing aura.",
      Model = "Kirameki_PX4", V3 = true, Color = P.Glow, Color2 = P.Star, Deco = "KiramekiGun", Fit = { G = "PX4", N = 3 } },
    { Id = "KiramekiArc", Name = "Kirameki Arc Projector", Gun = "BEAM", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = "Anime cel-shaded: hot magenta in flat colour panels with bold ink outlines, a big white armour plate lettered BANG!, a yellow lightning bolt on top, screentone and a star on the stock, and an energy tube that glows in the set's colour. On the inspect the ink outlines power up into a glowing aura.",
      Model = "Kirameki_BEAM", V3 = true, Color = P.Glow, Color2 = P.Star, Deco = "KiramekiGun", Fit = { G = "BEAM", N = 3 }, BeamColor = P.Glow },
}

-- decal spots on the plates' flat faces (gun space = frame space at build time; tools/skins_v3/kirameki_decals_<GUN>.json)
-- BEGIN KIRAMEKI DATA
local DECALS = {
    USAS12 = {
        { Img = "kr_sfx_bang", C = V(-0.41, 0.23, -0.0585), S = V(0.46, 0.14), Follow = nil },
        { Img = "kr_tone", C = V(-1.2, 0.1175, -0.0605), S = V(0.6, 0.175) },
        { Img = "kr_star", C = V(-0.99, 0.12, -0.0625), S = V(0.16, 0.16) },
        { Img = "kr_heart", C = V(0.21, -0.2525, -0.0305), S = V(0.16, 0.16), Follow = "Magazine" },
    },
    PX4 = {
        { Img = "kr_sfx_bang", C = V(-0.03, 0.205, -0.0685), S = V(0.42, 0.09), Follow = "Slide" },
        { Img = "kr_star", C = V(-0.17, -0.04, -0.0745), S = V(0.13, 0.13), Card = P.Plum },
    },
    BEAM = {
        { Img = "kr_sfx_bang", C = V(0.46, 0.305, -0.1505), S = V(0.88, 0.23) },
        { Img = "kr_tone", C = V(-0.68, 0.08, -0.1165), S = V(0.48, 0.56) },
        { Img = "kr_star", C = V(-0.74, 0.24, -0.1185), S = V(0.24, 0.24) },
    },
}
-- END KIRAMEKI DATA

local function Ink(model: Model)
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p:GetAttribute("Ink") then
            p.Color = P.Ink
            p.Material = Enum.Material.SmoothPlastic
            p.Transparency = 0
            p.Reflectance = 0
            p.CastShadow = false
        end
    end
end

Set.Build = {}
Set.Build.KiramekiGun = function(model: Model, frame: BasePart, f: any, forView: boolean, H: any)
    Ink(model)
    local base = frame.CFrame
    -- (a Decal ignores LocalTransparencyModifier: on your own world gun (hidden in first person) the stickers floated in view
    -- -> the world model gets none; other players see the painted gun without the lettering)
    if not forView then return end
    for _, d in ipairs(DECALS[f.G or ""] or {}) do
        -- (the sticker = an opaque white card on the white plate, its Decal on the Front (camera-side) face -- read the right
        -- way round in play with the frame's own axes)
        local p = H.Deco(model, { Name = "Sticker", Size = V(d.S.X, d.S.Y, 0.002), CFrame = base * CFrame.new(d.C),
            Color = d.Card or P.Card })
        if d.Follow then p:SetAttribute("Follow", d.Follow) end
        local dc = Instance.new("Decal")
        dc.Texture = ART[d.Img] or ""
        dc.Face = Enum.NormalId.Front
        dc.Parent = p
    end
end

-- the inspect "power-up": the ink hull turns into a glowing aura in the palette's Glow, pulsing, then back to ink
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    local v = rig.SkinVars
    local model = rig.Gun
    if model and v.InkFor ~= model then
        v.InkFor, v.Inks = model, {}
        for _, p in ipairs(model:GetDescendants()) do
            if p:IsA("BasePart") and p:GetAttribute("Ink") then table.insert(v.Inks, p) end
        end
    end
    local inspecting = rig.AnimName == "Inspect"
    local t = rig.AnimTime or 0
    local aura = inspecting and math.clamp(math.min(t / 0.35, 1) * math.clamp((3.2 - t) / 0.5, 0, 1), 0, 1) or 0
    -- the equip "transformation": the outlines flash bright and fade in 0.45 s
    local eq = st.SinceEquip or 99
    if eq < 0.45 then aura = math.max(aura, 1 - smooth(eq / 0.45)) end
    if v.Inks and (aura > 0 or v.InkLit) then
        v.InkLit = aura > 0
        local col = P.Ink:Lerp(P.Glow:Lerp(P.Hot, 0.12 + 0.12 * math.sin(now * 9)), aura)
        for _, p in ipairs(v.Inks) do
            p.Material = (aura > 0.05) and Enum.Material.Neon or Enum.Material.SmoothPlastic
            p.Color = col
        end
    end
end

-- ===== equip: a sparkle burst at the muzzle (with the outline flash in Drive) =====
Set.OnEquip = function(rig: any, H: any)
    if rig.Fx and rig.Fx.KrSpark then rig.Fx.KrSpark:Emit(5) end
    if not Set._Preloaded then
        Set._Preloaded = true
        task.spawn(function()
            local list = {}
            for _, k in ipairs({ "kr_speed", "kr_burst", "kr_spark", "kr_sfx_dodon", "kr_sfx_kira", "kr_sfx_bang" }) do
                if Tex(k, "") ~= "" then table.insert(list, Tex(k, "")) end
            end
            pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
        end)
    end
end

-- ===== muzzle: a hot pink-white flash, an anime IMPACT FRAME (a ring of speed lines round the muzzle for one blink, off
-- the crosshair: it sits on the muzzle, low right) and a little star =====
Set.Muzzle = function(rig: any, flash: ParticleEmitter, light: PointLight, muzzle: Attachment, H: any)
    flash.Color = ColorSequence.new(HOT, GLOW)
    flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.16), NumberSequenceKeypoint.new(1, 0.04) })
    light.Color = GLOW
    light.Brightness = 0.7
    rig.Fx.KrLines = H.Emitter(muzzle, { Name = "KrLines", Texture = Tex("kr_speed", H.SPARK), Color = { C(255, 255, 255), HOT }, Size = { 0.55, 0.85 },
        Life = { 0.06, 0.08 }, Speed = { 0, 0 }, Spread = 0, Trans = { 0.05, 1 }, Light = 1, Rate = 0 })
    rig.Fx.KrLines.Rotation = NumberRange.new(0, 360)
    rig.Fx.KrSpark = H.Emitter(muzzle, { Name = "KrSpark", Texture = Tex("kr_spark", H.SPARK), Color = { C(255, 255, 255), STAR }, Size = { 0.09, 0.0 },
        Life = { 0.18, 0.3 }, Speed = { 2, 5 }, Spread = 50, Trans = { 0, 1 }, Light = 1, Rate = 0, Drag = 4 })
    rig.Fx.KrSpark.Rotation = NumberRange.new(0, 90)
end
Set.OnFire = function(rig: any, H: any)
    if rig.Fx then
        if rig.Fx.KrLines then rig.Fx.KrLines:Emit(1) end
        if rig.Fx.KrSpark then rig.Fx.KrSpark:Emit(2) end
    end
end

-- ===== tracer: a CEL STREAK -- a flat white core inside a hard magenta band (no soft glow ramp), a spinning star at its
-- head and a second, smaller star trailing behind =====
Set.Tracer = function(H: any, from: Vector3, to: Vector3, peer: boolean?)
    local dist = (to - from).Magnitude
    if dist < 1.5 then return end
    local host = H.FxPart({ Transparency = 1, Size = V(0.05, 0.05, 0.05), CFrame = CFrame.new(from) })
    local a0, a1 = H.Att(host, from), H.Att(host, to)
    local function band(w0, w1, col, z)
        local b = Instance.new("Beam")
        b.Attachment0, b.Attachment1 = a0, a1
        b.Color = ColorSequence.new(col); b.LightEmission = 1; b.LightInfluence = 0; b.FaceCamera = true; b.Segments = 1
        b.Width0, b.Width1 = w0, w1; b.ZOffset = z
        b.Parent = host
        return b
    end
    local k = peer and 0.6 or 1
    local outer = band(0.02 * k, 0.07 * k, GLOW, 0)
    local core = band(0.008 * k, 0.03 * k, C(255, 255, 255), 0.01)
    local stars = {}
    for i, sz in ipairs({ peer and 0.3 or 0.45, peer and 0.18 or 0.26 }) do
        local hp = H.FxPart({ Transparency = 1, Size = V(0.05, 0.05, 0.05), CFrame = CFrame.new(from) })
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.fromScale(sz, sz); bb.LightInfluence = 0; bb.Adornee = hp
        local img = Instance.new("ImageLabel"); img.BackgroundTransparency = 1; img.Size = UDim2.fromScale(1, 1)
        img.Image = Tex("kr_spark", ""); img.ImageColor3 = (i == 1) and C(255, 255, 255) or STAR; img.Parent = bb
        bb.Parent = hp
        stars[i] = { P = hp, I = img, Lag = (i == 1) and 0 or 0.35 }
    end
    local dir = (to - from).Unit
    local travel = H.TRAVEL -- (hitscan: the shot is there at once, nothing flies)
    local dur = travel + 0.22
    H.Animate(dur, function(t)
        local hk = math.clamp(t / travel, 0, 1)
        a1.WorldPosition = from + dir * dist * hk
        for _, st in ipairs(stars) do
            local f = math.clamp((t - st.Lag * travel) / travel, 0, 1)
            st.P.CFrame = CFrame.new(from + dir * dist * f)
            st.I.Rotation = t * 600
        end
        local after = math.max(0, t - travel) / (dur - travel)
        -- (a hard cel fade: the band steps out instead of a soft ramp)
        local tr = (after < 0.45) and 0 or ((after < 0.75) and 0.5 or 1)
        outer.Transparency = NumberSequence.new(tr)
        core.Transparency = NumberSequence.new(tr)
        for _, st in ipairs(stars) do st.I.ImageTransparency = math.clamp(after * 1.3, 0, 1) end
    end, function() host:Destroy(); for _, st in ipairs(stars) do st.P:Destroy() end end)
end

-- ===== impact: a small pink manga burst stamped on the surface + two sparkles =====
Set.Impact = function(H: any, pos: Vector3, normal: Vector3?, peer: boolean?)
    if not H.Budget("KiramekiImpact", peer and 3 or 8, 0.45) then return end
    local n = (normal and normal.Magnitude > 0.1) and normal.Unit or V(0, 1, 0)
    local face = CFrame.lookAt(pos + n * 0.02, pos + n * 2) * CFrame.Angles(0, 0, math.random() * TAU)
    local p = H.FxPart({ Transparency = 1, Size = V(0.2, 0.2, 0.02), CFrame = face })
    local st = Instance.new("Decal")
    st.Texture = Tex("kr_burst", ""); st.Face = Enum.NormalId.Front; st.Color3 = PINK; st.Transparency = 0
    st.Parent = p
    local att = H.Att(p, pos + n * 0.03)
    local em = H.Emitter(att, { Name = "KrPop", Texture = Tex("kr_spark", H.SPARK), Color = { C(255, 255, 255), STAR }, Size = { 0.08, 0.0 },
        Life = { 0.2, 0.32 }, Speed = { 1.5, 3 }, Spread = 45, Trans = { 0, 1 }, Light = 1, Drag = 4 })
    em.EmissionDirection = Enum.NormalId.Front
    em:Emit(peer and 1 or 2)
    H.Animate(0.4, function(t)
        local k = t / 0.4
        local s = 0.12 + 0.3 * (1 - (1 - math.min(1, k * 4)) ^ 3)
        p.Size = V(s, s, 0.02)
        st.Transparency = (k < 0.6) and 0 or 1
    end, function() p:Destroy() end)
end

-- ===== KIRA FINISH v2 (FX roll-out 2026-10-14: the bar was raised past v1, a flat sticker above the head while the body
-- just vanished). ONE idea: the kill is a MANGA FREEZE FRAME -- the body stops dead as a cel-shaded silhouette (flat
-- white card, a hard ink outline: a Highlight over clones of its parts) in front of an ink-framed panel whose speed lines
-- punch in behind it, the hand-lettered boom slams in above; on the beat (0.3 s) the frame SHATTERS: the silhouette
-- bursts outward into stars and the panel drops away (1.2 s). The silhouette leaves the crosshair from 0.3 s; motion is
-- out + up + down, never at the screen. Budget: full <= 12 clones + 2 panel parts + 1 emitter (<= 22 stars) + 1
-- billboard; low: the panel + <= 4 clones + 8 stars, no speed lines. =====
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
    local ground = H.Ground(pos)
    local cam = workspace.CurrentCamera
    local rt = cam and cam.CFrame.RightVector or Vector3.xAxis
    rt = V(rt.X, 0, rt.Z)
    rt = (rt.Magnitude > 0.01) and rt.Unit or Vector3.xAxis
    local mid = ground + V(0, 2.7, 0)
    local base = CFrame.fromMatrix(mid, rt, Vector3.yAxis) -- (+Z faces the camera)
    local model = Instance.new("Model")
    model.Name = "KiramekiKill"
    model.Parent = H.FxFolder()
    local SM = Enum.Material.SmoothPlastic
    -- the PANEL behind the body: plum, an ink frame behind it, pink speed lines + a screentone wash on its face
    local panelCF = base * CFrame.new(0, 0.15, -1.7)
    local frame = H.FxPart({ Material = SM, Color = INK, Size = V(4.7, 5.9, 0.04), Transparency = 1, CFrame = panelCF * CFrame.new(0, 0, -0.06) }, model)
    local panel = H.FxPart({ Material = SM, Color = P.Plum, Size = V(4.3, 5.5, 0.04), Transparency = 1, CFrame = panelCF }, model)
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Back; sg.LightInfluence = 0; sg.AlwaysOnTop = false; sg.CanvasSize = Vector2.new(430, 550)
    sg.Parent = panel
    local New = H.New
    local lines = (not low) and New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("kr_speed", ""), ImageColor3 = PINK, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromScale(1.7, 1.35), ImageTransparency = 1, ZIndex = 2 }, sg) or nil
    local tone = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("kr_tone", ""), ImageColor3 = GLOW, ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(120, 120), Size = UDim2.fromScale(1, 1), ImageTransparency = 1, ZIndex = 1 }, sg)
    -- the FREEZE FRAME: clones of the body in flat magenta with a hard ink outline
    local frozen = Instance.new("Model")
    frozen.Name = "Frozen"
    frozen.Parent = model
    local bits = {}
    local center = mid
    for _, src in ipairs(BodyParts(pos, H)) do
        if #bits >= (low and 4 or 12) then break end
        local ok, c = pcall(function() return src:Clone() end)
        if ok and c then
            for _, ch in ipairs(c:GetChildren()) do
                if not (ch:IsA("SpecialMesh") or ch:IsA("DataModelMesh")) then ch:Destroy() end
            end
            c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
            c.Material = SM
            c.Color = P.Card
            c.Transparency = 0
            c.Reflectance = 0
            if c:IsA("MeshPart") then c.TextureID = "" end
            c.Name = "Frame"
            c.Parent = frozen
            local out = c.Position - center
            out = V(out.X, 0, out.Z) + rt * (math.random() - 0.5) * 0.8
            out = (out.Magnitude > 0.05) and out.Unit or rt
            table.insert(bits, { P = c, CF = c.CFrame, Size = c.Size, D = out * (5 + math.random() * 3) + V(0, 3 + math.random() * 4, 0),
                R = V(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 10 })
        end
    end
    local hl = Instance.new("Highlight")
    hl.Adornee = frozen; hl.DepthMode = Enum.HighlightDepthMode.Occluded
    hl.FillColor = P.Card; hl.FillTransparency = 0; hl.OutlineColor = INK; hl.OutlineTransparency = 0
    hl.Parent = frozen
    -- the STARS the frame shatters into (dark-on-bright safe: no light emission)
    local host = H.FxPart({ Transparency = 1, Size = V(0.1, 0.1, 0.1), CFrame = CFrame.new(center) }, model)
    local stars = H.Emitter(H.Att(host, center), { Texture = Tex("kr_star", H.SPARK), Color = { STAR, C(255, 255, 255) }, Size = { 1.0, 0.35 }, Life = { 0.55, 0.85 },
        Speed = { 7, 12 }, Spread = 180, Accel = V(0, -9, 0), Drag = 2.2, Light = 0.25, Influence = 0, Rot = { 0, 360 }, Spin = { -260, 260 },
        Trans = { 0, 0.2 } })
    -- the boom above the panel (v1's word + burst, smaller, sitting on the panel's top edge)
    local hp = H.FxPart({ Transparency = 1, Size = V(0.05, 0.05, 0.05), CFrame = CFrame.new(mid + V(0, 3.0, 0)) }, model)
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromScale(3.6, 1.8); bb.LightInfluence = 0; bb.Adornee = hp; bb.AlwaysOnTop = false
    local burst = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("kr_burst", ""), ImageColor3 = STAR, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 1.2), ImageTransparency = 1, ZIndex = 1 }, bb)
    local word = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("kr_sfx_dodon", ""), ImageColor3 = C(255, 255, 255), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ImageTransparency = 1, ZIndex = 2 }, bb)
    bb.Parent = hp
    local dur = low and 0.95 or 1.2
    local BEAT = 0.3
    local shattered = false
    H.Animate(dur, function(t, dt)
        -- 1) the panel SNAPS in (overshoot) and the speed lines punch in from outside
        local pin = math.min(1, t / 0.09)
        local over = 1 + 0.12 * math.sin(math.min(1, t / 0.2) * math.pi) * (1 - math.min(1, t / 0.2))
        local drop = smooth((t - (dur - 0.38)) / 0.38)
        local pcf = panelCF * CFrame.new(0, -drop * 1.6, 0)
        panel.Size = V(4.3, 5.5, 0.04) * V(pin * over, pin * over, 1)
        frame.Size = V(4.7, 5.9, 0.04) * V(pin * over, pin * over, 1)
        panel.CFrame = pcf; frame.CFrame = pcf * CFrame.new(0, 0, -0.06)
        local pa = (pin > 0.05) and drop or 1
        panel.Transparency = pa; frame.Transparency = pa
        tone.ImageTransparency = 0.72 + 0.28 * pa
        if lines then
            local lk = smooth(t / 0.22)
            lines.Size = UDim2.fromScale(2.4 - 0.7 * lk, 1.9 - 0.55 * lk)
            lines.Rotation = t * 14
            lines.ImageTransparency = math.max(1 - lk, pa)
        end
        -- 2) the FREEZE: the silhouette holds dead still (a hairline tremble) until the beat
        if t < BEAT then
            local tr = (t > 0.2) and 0.035 * math.sin(t * 90) or 0
            for _, b in ipairs(bits) do b.P.CFrame = b.CF + rt * tr end
        else
            -- 3) the SHATTER: every piece flies out and up, spinning, shrinking to nothing; the stars burst
            if not shattered then
                shattered = true
                if stars then stars:Emit(low and 8 or 22) end
                hl.FillColor = STAR
            end
            local k = math.clamp((t - BEAT) / 0.42, 0, 1)
            local e = 1 - (1 - k) ^ 2
            local shrink = smooth((k - 0.45) / 0.55)
            for _, b in ipairs(bits) do
                local p = b.P
                if p.Parent then
                    p.CFrame = CFrame.new(b.D * e * 0.32 + V(0, -4 * k * k * 0.32, 0)) * b.CF * CFrame.Angles(b.R.X * e, b.R.Y * e, b.R.Z * e)
                    p.Size = b.Size * math.max(0.02, 1 - shrink)
                end
            end
            hl.FillColor = STAR:Lerp(P.Body, math.min(1, k * 2.5))
            if k >= 1 and frozen.Parent then frozen:Destroy() end
        end
        -- 4) the boom slams in a hair after the panel, holds, snaps out with the panel
        local wk = math.clamp((t - 0.05) / 0.11, 0, 1)
        local ws = 1 + 0.35 * (1 - wk)
        word.Size = UDim2.fromScale(ws, ws)
        local out = (t > dur - 0.2)
        word.ImageTransparency = (out or wk == 0) and 1 or 0
        burst.ImageTransparency = (out or wk == 0) and 1 or 0
        burst.Rotation = 10 * math.sin(t * 40) * (1 - wk)
    end, function() model:Destroy() end)
end

-- ===== the banner (lower right, beside the weapon card): a pink manga burst with the streak count + a word in comic
-- lettering; it slams in with a little shake =====
local banner
local NUMFONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json", Enum.FontWeight.Regular)
local WORDS = { "NICE!", "COMBO!", "SUPER!", "HYPER!", "KIRA KIRA!" }
Set.Banner = function(H: any, streak: number)
    local gui, root = H.BannerRoot("Kirameki", Vector2.new(180, 90), "Side")
    if not root then return end
    local New = H.New
    if not banner or banner.Root ~= root then
        local burst = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("kr_burst", ""), ImageColor3 = PINK, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(46, 45), Size = UDim2.fromOffset(84, 84), ZIndex = 2 }, root)
        local num = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(46, 47), Size = UDim2.fromOffset(70, 40),
            FontFace = NUMFONT, TextSize = 30, TextColor3 = C(255, 255, 255), TextStrokeColor3 = INK, TextStrokeTransparency = 0, Text = "", ZIndex = 3 }, root)
        num:SetAttribute("KeepFont", true)
        local word = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(92, 45), Size = UDim2.fromOffset(88, 40),
            FontFace = NUMFONT, TextSize = 20, TextColor3 = STAR, TextStrokeColor3 = INK, TextStrokeTransparency = 0, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 3, Rotation = -6 }, root)
        word:SetAttribute("KeepFont", true)
        banner = { Root = root, Burst = burst, Num = num, Word = word, Token = 0 }
    end
    local b = banner
    b.Token += 1
    local token = b.Token
    local st = math.clamp(streak or 1, 1, 5)
    root.Visible = true
    b.Num.Text = "x" .. st
    b.Word.Text = WORDS[st]
    b.Burst.ImageColor3 = (st >= 5) and STAR or PINK
    H.Animate(1.6, function(t)
        if b.Token ~= token then return end
        local k = smooth(t / 0.12)
        local s = 1.3 - 0.3 * k
        b.Burst.Size = UDim2.fromOffset(84 * s, 84 * s)
        b.Burst.Rotation = (1 - k) * 12 * math.sin(t * 60)
        local a = (t > 1.3) and smooth((t - 1.3) / 0.3) or 0
        b.Burst.ImageTransparency = a; b.Num.TextTransparency = a; b.Word.TextTransparency = a
        b.Num.TextStrokeTransparency = a; b.Word.TextStrokeTransparency = a
    end, function() if b.Token == token then root.Visible = false end end)
end

-- sounds (tools/skins_v3/kirameki_sfx.py: real CC0 recordings -- each gun's own shot + a tiny wind-chime tick; bead-jar
-- shimmers, a brush of chimes, a glass tap, a blade swish; every clip passed tools/audio_screen.py). The shots sit ~3 dB
-- under the plain ones in the file, so FireGun volumes = the plain gun's volume x that factor.
Set.Sounds = {
    Fire = { Id = 0, Volume = 0 }, Equip = { Id = 79560516836213, Volume = 0.4 }, MagOut = { Id = 118117852452707, Volume = 0.36 },
    MagIn = { Id = 74248553954004, Volume = 0.36 }, Kill = { Id = 126212501129695, Volume = 0.5 }, Impact = { Id = 133892012812954, Volume = 0.2 },
    Swing = { Id = 84171382611749, Volume = 0.38 }, MeleeHit = { Id = 120379428753934, Volume = 0.42 },
    FireGun = { USAS12 = { Id = 76664034297226, Volume = 1.24 }, PX4 = { Id = 139860620496244, Volume = 1.06 },
        BEAM = { Id = 123563575174035, Volume = 0.99 } },
}

-- ===== set melee: KIRA SABER (Sword class; WeaponAssets.MeleeModels.Kirameki, tools/skins_v3/kirameki_build.py) -- a white
-- double-edged blade with hard pink cel bevels, a magenta fuller with two yellow sparkles, a magenta heart guard with a lit
-- star gem and two little white wings, an ink-plum grip, a yellow star pommel, all inside a bold ink line (the Drive above
-- powers the line up into the aura on the inspect, like the guns). The swing leaves a SPARKLE trail (a ribbon of little
-- stars in pink -> yellow) and the strike throws a few sparkles off the blade. =====
Set.Melee = {
    Skin = { Name = "Kira Saber", Price = 449, ProductId = 0,
        Desc = "A magical-girl saber, cel-shaded: a white blade with hot pink bevels and a magenta fuller set with two sparkles, a magenta heart guard with a glowing star gem and little white wings, a star pommel, all inside a bold ink line. The swing leaves a trail of sparkles; on the inspect the ink line powers up into a glowing aura." },
    Rig = { Class = "Sword", BladeLen = 1.1 },
    FlatBlade = true,
    Build = function(m: Model, o: any, H: any)
        local parts = H.CloneModel(m, "MeleeModels", "Kirameki", VAR, { [1] = GLOW, [2] = STAR })
        Ink(m)
        local blade = parts.Blade
        if not blade then return end
        local cf = blade.CFrame
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Name, a1.Name = "TrailBase", "TrailTip"
        a0.Position = cf:PointToObjectSpace(cf.Position + cf.UpVector * blade.Size.Y * 0.05)
        a1.Position = cf:PointToObjectSpace(cf.Position + cf.UpVector * blade.Size.Y * 0.47)
        a0.Parent, a1.Parent = blade, blade
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Texture = Tex("kr_spark", "")
        tr.TextureMode = Enum.TextureMode.Wrap
        tr.TextureLength = 0.35
        tr.Color = ColorSequence.new(PINK, STAR)
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
        tr.LightEmission = 0.8; tr.LightInfluence = 0
        tr.Lifetime = 0.14; tr.MinLength = 0.02; tr.FaceCamera = true
        tr.Enabled = false
        tr:SetAttribute("SwingTrail", true)
        tr.Parent = blade
        -- the strike's sparkles (emitted from the outer half of the blade in OnEvent "Swing")
        local sa = Instance.new("Attachment")
        sa.Name = "KrSparkAt"
        sa.Position = cf:PointToObjectSpace(cf.Position + cf.UpVector * blade.Size.Y * 0.3)
        sa.Parent = blade
        local em = H.Emitter(sa, { Name = "KrSwingSpark", Texture = Tex("kr_spark", H.SPARK), Color = { C(255, 255, 255), STAR }, Size = { 0.07, 0.0 },
            Life = { 0.2, 0.35 }, Speed = { 1, 3 }, Spread = 180, Trans = { 0, 1 }, Light = 1, Rate = 0, Drag = 5 })
        em.Rotation = NumberRange.new(0, 90)
    end,
}
-- the melee strike: a little burst of sparkles off the blade (the hit itself plays the set's MeleeHit)
Set.OnEvent = function(rig: any, name: string, H: any, data: any)
    if name == "Swing" and rig.Gun then
        local em = rig.Gun:FindFirstChild("KrSwingSpark", true)
        if em then em:Emit(4) end
    end
end

-- ===== arms: KIRA GLOVES + IDOL SLEEVES (cel-shaded parts with ink piping; GloveFX blocks). Glove: a white glove with a
-- magenta back plate edged in ink, a magenta cuff ringed with an ink line, a star badge on the back; ONE effect: a tiny
-- sparkle twinkles beside the star every few seconds. Sleeve: an ink-plum sleeve under a halftone screentone, a magenta
-- stripe piped in ink down each side, a white cuff with an ink ring and a heart patch on the forearm. =====
Set.Glove = function(K: any)
    local V3 = K.V
    return {
        Id = "KiraGloves", Name = "Kira Gloves", Price = 449,
        Desc = "Cel-shaded white gloves with a magenta back plate edged in ink, a magenta cuff and a star badge on the back; a little sparkle twinkles beside the star now and then. Part of the Kirameki set.",
        Base = { Color = P.Card, Material = K.SMOOTH, Reflectance = 0 },
        Parts = {
            { Size = V3(0.86, 0.09, 0.66), Off = V3(0, 0.5, -0.06), Color = P.Body, Material = K.SMOOTH },
            { Size = V3(0.04, 0.1, 0.68), Off = V3(0.44, 0.51, -0.06), Color = INK, Material = K.SMOOTH },
            { Size = V3(0.04, 0.1, 0.68), Off = V3(-0.44, 0.51, -0.06), Color = INK, Material = K.SMOOTH },
            { Size = V3(1.12, 1.12, 0.18), Off = V3(0, 0, 0.42), Color = P.Body, Material = K.SMOOTH },
            { Size = V3(1.15, 1.15, 0.035), Off = V3(0, 0, 0.32), Color = INK, Material = K.SMOOTH },
            -- (ONE whole star: Uniform keeps the badge square in block widths so one tile = the badge; unscaled, the short hand
            -- block squashed the badge to 0.087 x 0.060 under a 0.106 tile and cropped the star)
            { Size = V3(0.3, 0.03, 0.3), Uniform = true, Off = V3(0, 0.55, -0.06), Seat = true, Color = P.Body, Material = K.SMOOTH, Tex = "kr_star", TexTile = 0.31, TexT = 0 },
            { Size = V3(0.07, 0.015, 0.07), Off = V3(0.22, 0.58, -0.22), Seat = true, Color = STAR, Glow = true, Uniform = true,
              Anim = "Twinkle", Period = 4.0, Dur = 0.35, PulseMin = 0.05, PulseMax = 1 },
        },
    }
end
Set.Sleeve = function(K: any)
    local V3 = K.V
    return {
        Id = "IdolSleeves", Name = "Idol Sleeves", Price = 299,
        Desc = "An ink-plum stage sleeve under a halftone screentone, a magenta stripe piped in ink down each side, a white cuff with an ink ring and a heart patch on the forearm. Part of the Kirameki set.",
        Base = { Color = P.Plum, Material = K.SMOOTH, Reflectance = 0, Tex = "tex_kr_dots", TexTile = 0.5, TexT = 0.25, TexColor = P.Plum:Lerp(C(255, 255, 255), 0.3) },
        Parts = {
            { Size = V3(0.06, 0.16, 0.86), Off = V3(0.5, 0.1, 0.04), Color = P.Body, Material = K.SMOOTH },
            { Size = V3(0.065, 0.025, 0.86), Off = V3(0.5, 0.19, 0.04), Color = INK, Material = K.SMOOTH },
            { Size = V3(0.06, 0.16, 0.86), Off = V3(-0.5, 0.1, 0.04), Color = P.Body, Material = K.SMOOTH },
            { Size = V3(0.065, 0.025, 0.86), Off = V3(-0.5, 0.19, 0.04), Color = INK, Material = K.SMOOTH },
            { Size = V3(1.16, 1.16, 0.2), Off = V3(0, 0, -0.41), Color = P.Card, Material = K.SMOOTH },
            { Size = V3(1.19, 1.19, 0.035), Off = V3(0, 0, -0.31), Color = INK, Material = K.SMOOTH },
            -- (ONE heart: Uniform keeps the patch square in units of the block width, so the tile (TexTile x w) is exactly the
            -- patch -- unscaled, the forearm's length stretched it into a row of hearts along the stripe)
            { Size = V3(0.36, 0.03, 0.36), Uniform = true, Off = V3(0, 0.53, 0.12), Seat = true, Color = P.Plum, Material = K.SMOOTH, Tex = "kr_heart", TexTile = 0.37, TexT = 0 },
        },
    }
end

-- ===== health bar v2 (BARS v2, FX roll-out): the house ink frame round the magenta speed-stripe fill; lost health drains
-- out in YELLOW and pops off as little stars; elites / bosses add a star that twinkles on the fill's end =====
Set.Bar = { Id = "Kirameki", Name = "Kirameki", Price = 149,
    Desc = "A manga-panel health bar: an ink frame round a magenta fill with speed stripes. Every hit pops the lost piece off as little stars, and on elites and bosses a star twinkles on the end of the fill. Part of the Kirameki set.",
    Look = "Ink", Tex = "tex_kr_bar", TexSpeed = 8, TexColor = PINK, ChipMotion = "Drain", Chip = STAR, Back = INK, Segments = 0, Decor = { "StarPop", "KiraEnd" } }
Set.BarDecor = {
    StarPop = function(ctx: any, K: any)
        -- 2-4 stars jump out of the piece a hit took off and fall away spinning (pooled)
        local ps = K.Particles(ctx.Holder, { Image = Tex("kr_star", "glow"), Gravity = 260, Shrink = true, Z = 11, Spawn = function() end })
        return function(now, dt, alpha, info)
            if (info.Drop or 0) > 0.004 and info.DropX0 and info.DropX1 then
                local n = (ctx.Tier == "Small") and 2 or 4
                for i = 1, n do
                    local x = info.DropX0 + (info.DropX1 - info.DropX0) * (i - 0.5) / n
                    local sz = math.max(7, ctx.H * 1.3)
                    ps.Emit(x, ctx.H * 0.4, (math.random() - 0.5) * 60, -70 - math.random() * 60, 0.45 + math.random() * 0.2, sz,
                        (i % 2 == 0) and PINK or STAR, (math.random() - 0.5) * 600)
                end
            end
            ps.Step(dt, alpha)
        end
    end,
    KiraEnd = function(ctx: any, K: any)
        if ctx.Tier == "Small" then return function() end end
        local ink = K.New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("kr_star", ""), ImageColor3 = INK, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 11 }, ctx.Holder)
        local star = K.New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("kr_star", ""), ImageColor3 = STAR, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 12 }, ctx.Holder)
        return function(now, dt, alpha, info)
            local s = ctx.H * 2.1
            local tw = ((now % 2.6) < 0.18) and (1 + 0.35 * math.sin(((now % 2.6) / 0.18) * math.pi)) or 1
            local x = ctx.W * math.clamp(info.Shown or 1, 0, 1)
            star.Size = UDim2.fromOffset(s * tw, s * tw); ink.Size = UDim2.fromOffset(s * tw + 5, s * tw + 5)
            star.Position = UDim2.fromOffset(x, ctx.H / 2); ink.Position = star.Position
            star.Rotation = 12 * math.sin(now * 1.7); ink.Rotation = star.Rotation
            star.ImageTransparency = 1 - alpha; ink.ImageTransparency = 1 - alpha
        end
    end,
}

-- ===== UI theme v2 (FX roll-out 2026-10-14; v1 = the shared template): a MANGA PAGE, icon look (flat colour + ink edge).
-- Two inked STAR stickers stuck over the top corners that twinkle now and then, a screentone wash in the lower corner
-- under the content, windows open with a PANEL SLAM (an ink panel border snaps in from bigger + a pink impact burst that
-- fades from the middle), every title gets a tilted yellow star. Colours from the theme table (Star / Pink / Ink / Tone). =====
local function KrDeco(ctx)
    if ctx.Kind ~= "Window" then return nil end
    local t = ctx.Theme
    local host = ctx.Root or ctx.Surface
    local f = Instance.new("Frame")
    f.Name = "KrOverlay"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 20; f.Active = false
    f:SetAttribute("NoSkin", true); f:SetAttribute("Skinned", true)
    f.Parent = host
    local abs = host.AbsoluteSize
    local small = math.min(abs.X, abs.Y) < 260
    local S = small and 30 or 52
    local stars = {}
    for i, c in ipairs({ { 0, -14 }, { 1, 16 } }) do
        local ink = Instance.new("ImageLabel")
        ink.BackgroundTransparency = 1; ink.Image = Tex("kr_star", ""); ink.ImageColor3 = t.Ink; ink.AnchorPoint = Vector2.new(0.5, 0.5)
        ink.Position = UDim2.new(c[1], (c[1] == 0) and 4 or -4, 0, 2); ink.Size = UDim2.fromOffset(S + 8, S + 8); ink.Rotation = c[2]; ink.ZIndex = f.ZIndex + 1
        ink.Parent = f
        local st = ink:Clone()
        st.ImageColor3 = t.Star; st.Size = UDim2.fromOffset(S, S); st.ZIndex = f.ZIndex + 2
        st.Parent = f
        stars[i] = { I = ink, S = st, Rot = c[2], Ph = i * 1.3 }
    end
    -- the screentone wash (under the content, in the deco layer)
    local tone = Instance.new("ImageLabel")
    tone.Name = "KrTone"; tone.BackgroundTransparency = 1; tone.Image = Tex("kr_tone", ""); tone.ImageColor3 = t.Tone
    tone.ScaleType = Enum.ScaleType.Tile; tone.TileSize = UDim2.fromOffset(90, 90); tone.ImageTransparency = 0.82
    tone.AnchorPoint = Vector2.new(1, 1); tone.Position = UDim2.fromScale(1, 1); tone.Size = UDim2.new(0.34, 0, 0.3, 0)
    tone.ZIndex = 1
    local g = Instance.new("UIGradient")
    g.Rotation = -135; g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.6), NumberSequenceKeypoint.new(1, 1) })
    g.Parent = tone
    tone.Parent = ctx.Frame or host
    return function(now, dt)
        for _, s in ipairs(stars) do
            local p = (now + s.Ph) % 3.2
            local tw = (p < 0.22) and (1 + 0.3 * math.sin(p / 0.22 * math.pi)) or 1
            local r = s.Rot + 6 * math.sin(now * 0.9 + s.Ph)
            s.S.Size = UDim2.fromOffset(S * tw, S * tw); s.I.Size = UDim2.fromOffset((S + 8) * tw, (S + 8) * tw)
            s.S.Rotation = r; s.I.Rotation = r
        end
    end, { f, tone }
end
local function KrOpen(ctx)
    -- PANEL SLAM (0.32 s): an ink panel border snaps in from 6% bigger, a pink impact burst fades out of the middle
    local t = ctx.Theme
    local root = ctx.Root
    if not root then return end
    local f = root:FindFirstChild("KrOverlay") or ctx.Frame
    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1; box.AnchorPoint = Vector2.new(0.5, 0.5); box.Position = UDim2.fromScale(0.5, 0.5); box.Size = UDim2.fromScale(1.06, 1.06)
    box.ZIndex = f.ZIndex + 6
    local st = Instance.new("UIStroke"); st.Color = t.Ink; st.Thickness = 5; st.Parent = box
    box.Parent = f
    ctx.Tween:Create(box, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) }):Play()
    task.delay(0.18, function() if st.Parent then ctx.Tween:Create(st, TweenInfo.new(0.14), { Transparency = 1 }):Play() end end)
    local abs = root.AbsoluteSize
    local d = math.min(abs.X, abs.Y)
    local burst = Instance.new("ImageLabel")
    burst.BackgroundTransparency = 1; burst.Image = Tex("kr_burst", ""); burst.ImageColor3 = t.Pink; burst.AnchorPoint = Vector2.new(0.5, 0.5)
    burst.Position = UDim2.fromScale(0.5, 0.5); burst.Size = UDim2.fromOffset(d * 0.35, d * 0.35); burst.ImageTransparency = 0.55; burst.ZIndex = f.ZIndex + 5
    burst.Parent = f
    ctx.Tween:Create(burst, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.fromOffset(d * 1.1, d * 1.1), ImageTransparency = 1, Rotation = 18 }):Play()
    task.delay(0.34, function() box:Destroy(); burst:Destroy() end)
end
local function KrTitle(ctx)
    -- a tilted yellow star with an ink edge on the title bar (right side, left of the emblem + close button)
    local bar, t = ctx.Title, ctx.Theme
    local h = math.max(bar.AbsoluteSize.Y, 30)
    local ink = Instance.new("ImageLabel")
    ink.Name = "KrTitleStar"; ink.BackgroundTransparency = 1; ink.Image = Tex("kr_star", ""); ink.ImageColor3 = t.Ink; ink.AnchorPoint = Vector2.new(1, 0.5)
    ink.Size = UDim2.fromOffset(26, 26); ink.Position = UDim2.new(1, -(h * 2.9 + 16), 0.5, 0); ink.Rotation = -14; ink.ZIndex = bar.ZIndex + 1
    local st = ink:Clone()
    st.ImageColor3 = t.Star; st.Size = UDim2.fromOffset(20, 20); st.Position = UDim2.new(1, -(h * 2.9 + 19), 0.5, 0); st.ZIndex = bar.ZIndex + 2
    ink.Parent = bar; st.Parent = bar
    return { ink, st }
end
-- numbers v3 (SKIN UI 2026-10-28, owner: numbers "unique to the skin and the colorways"): a MANGA STICKER. Paper-white
-- LuckiestGuy digits with a heavy ink outline and a hard print shadow in the set's hot colour (a die-cut sticker, a little
-- off-register), slapped on tilted off the beat; a KIRA sparkle twinkles on its corner. CRIT = a speech burst pops behind it
-- and the digits go star-coloured; WEAK SPOT = a star in front; a KILL = the burst turns star-gold and the sparkle flares.
-- Every colour is this copy's palette (P = the colourway).
local function KrMotion(e, age, pa, life)
    local k = math.min(1, age / 0.5)
    local ease = 1 - (1 - k) ^ 3
    local dir = (e.Seed > math.pi) and 1 or -1
    local b = math.min(1, pa / 0.13)
    local sc = 1 + 0.28 * (e.BumpAmp or 1) * (1 - b) ^ 2
    return 0.5 + ease * 1.3, dir * 0.35 * ease, sc, 0, 0, -dir * (5 + 5 * (1 - b))
end
local function KrAccent(e)
    local box = Instance.new("Frame")
    box.Name = "KrSticker"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 0
    local burst = Instance.new("ImageLabel")
    burst.Name = "Burst"; burst.BackgroundTransparency = 1; burst.Image = Tex("kr_burst", ""); burst.AnchorPoint = Vector2.new(0.5, 0.5)
    burst.Position = UDim2.fromScale(0.5, 0.5); burst.ZIndex = 0; burst.Parent = box
    local shadow = Instance.new("TextLabel")
    shadow.Name = "Shadow"; shadow.BackgroundTransparency = 1; shadow.Size = UDim2.fromScale(1, 1); shadow.Position = UDim2.fromOffset(3, 3)
    shadow.ZIndex = 0; shadow:SetAttribute("KeepFont", true); shadow.Parent = box
    local sst = Instance.new("UIStroke"); sst.Thickness = 3; sst.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; sst.Parent = shadow
    local spark = Instance.new("ImageLabel")
    spark.Name = "Kira"; spark.BackgroundTransparency = 1; spark.Image = Tex("kr_spark", ""); spark.AnchorPoint = Vector2.new(0.5, 0.5)
    spark.Size = UDim2.fromOffset(18, 18); spark.ZIndex = 3; spark.Parent = box
    return box
end
local function KrAccentStep(e, box, age, pa, alpha)
    local lbl = e.Label
    local tb = lbl.TextBounds
    local shadow, burst, spark = box:FindFirstChild("Shadow"), box:FindFirstChild("Burst"), box:FindFirstChild("Kira")
    if shadow then
        if shadow.Text ~= lbl.Text then shadow.Text = lbl.Text end
        shadow.FontFace = lbl.FontFace; shadow.TextSize = lbl.TextSize
        shadow.TextColor3 = P.Body; shadow.TextTransparency = math.clamp(alpha + 0.1, 0, 1)
        local st = shadow:FindFirstChildOfClass("UIStroke"); if st then st.Color = INK; st.Transparency = alpha end
    end
    if burst then
        local on = (e.Crit or e.Killed) and not e.Dot
        burst.Visible = on
        if on then
            local b = math.min(1, pa / 0.12)
            local k = 0.8 + 0.3 * b
            burst.Size = UDim2.fromOffset((tb.X + 26) * k * 1.3, (tb.Y + 20) * k * 1.5)
            burst.Rotation = e.Seed * 30 + age * 20
            burst.ImageColor3 = e.Killed and STAR or GLOW -- (the colourway's glow: magenta / lemon / ice-cyan)
            burst.ImageTransparency = math.max(alpha, 0.05)
        end
    end
    if spark then
        local tw = 0.5 + 0.5 * math.sin(age * 14 + e.Seed) -- (a twinkle)
        local big = e.Killed and 1.6 or (e.Crit and 1.25 or 1)
        local sz = math.floor((10 + 10 * tw) * big)
        spark.Size = UDim2.fromOffset(sz, sz)
        spark.Rotation = age * 120
        spark.Position = UDim2.new(0.5, math.floor(tb.X / 2) + 2, 0.5, -math.floor(tb.Y / 2) + 2)
        spark.ImageColor3 = STAR; spark.ImageTransparency = math.clamp(alpha + 0.15 * (1 - tw), 0, 1)
    end
end
-- ===== UI THEME v4 (SKIN UI THEMES 2026-10-28, owner: themes "lazy and not much different", header art stretched): the clean
-- language in this colourway's colours (UITheme Clean) + two touches of a manga page. Hooks read only the palette they get:
--   TAB MARK  a bold star-coloured underline inked round in the hot colour (a print edge) and an inked star sticker at its end
--             (the top bar's star twinkles)
--   FIELD     a SCREENTONE wash rising out of the lower-left corner (dot tone, fading out) and three kira sparkles under the
--             top bar on the right that twinkle in turn
local function KrV(c) local _, _, v = c:ToHSV() return v end
local KR_CLEAN = {
    Field = P.Ink:Lerp(P.Plum, 0.3), Surface = P.Ink:Lerp(P.Plum, 0.45), Raised = P.Plum:Lerp(P.Ink, 0.15):Lerp(P.Body, 0.1), Hover = P.Plum:Lerp(P.Body, 0.22),
    Well = P.Ink, Line = P.Plum:Lerp(P.Glow, 0.28), Tip = P.Ink:Lerp(P.Plum, 0.35),
    Accent = (KrV(P.Body) >= 0.7) and P.Body or P.Glow, Mark = P.Star, Hair = P.Glow,
    Text = P.Card, Sub = P.Card:Lerp(P.Plum, 0.32), Muted = P.Card:Lerp(P.Plum, 0.45), Ink = P.Ink,
    Star = P.Star, Shadow = P.Glow, Tone = P.Glow, InkLine = P.Ink,
}
local function KrStar(parent, Q, size, z)
    local st = Instance.new("TextLabel")
    st.Name = "KrStar"; st.BackgroundTransparency = 1; st.Text = "\u{2605}"; st.Font = Enum.Font.GothamBlack; st.TextSize = size
    st.TextColor3 = Q.Star; st.AnchorPoint = Vector2.new(0, 0.5); st.Size = UDim2.fromOffset(18, 18); st.ZIndex = z
    st:SetAttribute("NoSnap", true); st:SetAttribute("KeepFont", true); st:SetAttribute("TextRole", "Glyph")
    local o = Instance.new("UIStroke"); o.Color = Q.InkLine; o.Thickness = 1.5; o.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; o.Parent = st
    st.Parent = parent
    return st
end
KR_CLEAN.TabMark = function(mark, Q)
    -- (tab buttons size themselves to their children: a SCALE-sized frame inside the mark grew the tab across the screen --
    -- only offset-sized children inside the mark's width, and the hot print edge is a stroke, which never counts)
    local sh = Instance.new("UIStroke")
    sh.Name = "KrPrint"; sh.Color = Q.Shadow; sh.Thickness = 1.5; sh.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; sh.Parent = mark
    local star = KrStar(mark, Q, 13, mark.ZIndex + 1)
    star.Position = UDim2.new(1, -18, 0, -3)
    return { sh, star }
end
KR_CLEAN.Sig = function(ctx)
    local Q, f = ctx.P, ctx.Frame
    -- screentone: the dot texture tiled at a fixed size (never stretched) over the field's lower-left, faded out by a gradient
    local tone = Instance.new("ImageLabel")
    tone.Name = "KrTone"; tone.BackgroundTransparency = 1; tone.Image = ART.tex_kr_dots or ""; tone.ScaleType = Enum.ScaleType.Tile
    tone.TileSize = UDim2.fromOffset(128, 128); tone.ImageColor3 = Q.Tone; tone.ImageTransparency = 0.65; tone.AnchorPoint = Vector2.new(0, 1)
    tone.Position = UDim2.fromScale(0, 1); tone.Size = UDim2.fromScale(0.4, 0.6); tone.ZIndex = 0; tone.Parent = f
    local g = Instance.new("UIGradient")
    g.Rotation = -38
    g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.32, 0.75), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 1) })
    g.Parent = tone
    -- three kira sparkles under the top bar, right side
    local topY = 64
    if ctx.Top then topY = ctx.Top.AbsolutePosition.Y - f.AbsolutePosition.Y + ctx.Top.AbsoluteSize.Y end
    local sparks = {}
    for i, sp in ipairs({ { -70, 26, 22 }, { -112, 54, 14 }, { -40, 70, 11 } }) do
        local im = Instance.new("ImageLabel")
        im.Name = "KrKira" .. i; im.BackgroundTransparency = 1; im.Image = ART.kr_spark or ""; im.ScaleType = Enum.ScaleType.Fit
        im.ImageColor3 = (i == 2) and Q.Shadow or Q.Star; im.AnchorPoint = Vector2.new(0.5, 0.5)
        im.Position = UDim2.new(1, sp[1], 0, topY + sp[2]); im.Size = UDim2.fromOffset(sp[3], sp[3]); im.ZIndex = 0; im.Parent = f
        sparks[i] = { Img = im, S = sp[3], Ph = i * 2.1 }
    end
    return function(now, _dt)
        for _, s in ipairs(sparks) do
            local k = math.max(0, math.sin(now * 1.7 + s.Ph)) ^ 3
            local z = s.S * (0.55 + 0.6 * k)
            s.Img.Size = UDim2.fromOffset(z, z)
            s.Img.ImageTransparency = 0.55 - 0.5 * k
            s.Img.Rotation = 20 * k
        end
        for _, m in ipairs(ctx.Marks()) do
            local st = m.Visible and m:FindFirstChild("KrStar")
            if st then
                local k = math.max(0, math.sin(now * 2.4)) ^ 4
                st.TextSize = 13 + 4 * k
                st.TextTransparency = 0.25 * (1 - k)
            end
        end
    end, nil
end

local function PG(top, bottom) return { Top = top, Bottom = bottom } end
Set.Theme = { Name = "Kirameki", Desc = "Menus like a manga page: ink-dark panels, hot magenta title bars, inked star stickers over the top corners that twinkle, a screentone wash in the corner, and a yellow star on every title.",
    Panel = PG(C(36, 18, 40), C(12, 6, 16)), Card = PG(C(46, 22, 52), C(16, 8, 20)), Title = PG(C(204, 26, 112), C(90, 10, 54)),
    Accent = C(255, 214, 40), Accent2 = C(255, 90, 180), HpFill = C(255, 60, 150), HpBg = C(20, 8, 22), XpFill = C(255, 214, 40), Text = C(255, 244, 250),
    Emblem = "EmblemKirameki", BorderThick = 2,
    Star = C(255, 214, 40), Pink = C(255, 90, 180), Ink = C(16, 8, 22), Tone = C(255, 90, 180),
    Deco = KrDeco, OpenFn = KrOpen, TitleDeco = KrTitle,
    Clean = KR_CLEAN, -- (SKIN UI THEMES: the clean palette + print-shadow star tab marks + screentone + kira sparkles; the old art is not drawn)
    -- (SKIN UI 2026-10-28: a manga sticker -- ink outline, a hot print shadow, a kira sparkle; colours from this colourway's P)
    Numbers = { Font = "LuckiestGuy", Glyph = "★", Motion = KrMotion, Accent = KrAccent, AccentStep = KrAccentStep,
        Normal = P.Card, Crit = STAR, Weak = PINK, Stroke = INK, StrokeThick = 3, Size = 1.05 } }

-- ===== bundle / kill effect / store hero =====
Set.KillEffect = { Id = "KiraFinish", Name = "Kira Finish", Image = Tex("kr_burst", ""),
    How = "Own any Kirameki skin (or the Kirameki bundle)",
    Desc = "A manga freeze frame: the body stops dead as an ink-outlined silhouette in front of a panel of speed lines, a hand-lettered boom slams in above, then the frame shatters into stars. With the burst banner that counts your streak up to KIRA KIRA!" }
Set.Bundle = { Id = "KiramekiBundle", Name = "Kirameki Bundle", Price = 2199, BP = 799, ProductId = 0,
    Desc = "The whole Kirameki set: the Kirameki Komrad 12, PX4 Storm and Arc Projector, the Kira Saber, Kira Gloves + Idol Sleeves, the Kirameki health bar, the Kira Finish kill effect",
    Contents = { "WeaponSkin:KiramekiUSAS12", "WeaponSkin:KiramekiPX4", "WeaponSkin:KiramekiArc", "Glove:KiraGloves", "Sleeve:IdolSleeves",
        "MeleeSkin:Kirameki", "HealthBar:Kirameki", "KillEffect:KiraFinish" } }
Set.Hero = { Grad = { C(204, 26, 112), C(36, 10, 40) }, Stroke = STAR, Emblem = Tex("kr_star", ""), Name = C(255, 244, 250), Chip = C(204, 26, 112) }

return Set
