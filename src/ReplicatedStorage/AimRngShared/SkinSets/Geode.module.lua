--!nocheck
-- ===================================================================================================================
-- GEODE (Skins V3, bundle 17 of docs/SKINS_V3_PLAN.md; SKINS BUILDER 10 "skins10"): USAS-12 + PX4 Storm + Arc Projector |
-- Agate Karambit. v5 CARVED GEMSTONE (owner: "I more so meant the gun looking like a gem"): the stock, receiver flanks,
-- handguard flanks and magazine are CUT STONES -- a girdle following the gun's outline, a two-step crown of flat facets to a
-- table, semi-transparent crystal (Clear SmoothPlastic) over a darker opaque core, internal facet planes, tiny lit
-- inclusions, the colour graded deep -> light inside each stone; small metal prongs clasp them to a dark satin setting.
--   FIRE   a glint runs across the facets (the shell tones lift toward white for a blink, never Neon)
--   KILL   the cores pulse (the inclusions flare, then settle)
-- (T3 = the facets facing the key light: a mid-light SATURATED tone -- a pale lavender washed to white on Ice, the
-- pale-on-big-areas lesson)
-- WeaponAssets.SkinModels.Geode_<GUN> (tools/skins_v3/geode_v5.py). CONCEPT ROUND: only the USAS-12 is built; HELD.
-- ===================================================================================================================
local Set = { Kind = "Geode" }

local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local PALETTES = {
    { Name = "Amethyst", T1 = C(44, 12, 88), T2 = C(112, 44, 182), T3 = C(158, 96, 232), Hi = C(238, 222, 255), Core = C(30, 10, 52), Lume = C(214, 150, 255) },
    { Name = "Citrine", T1 = C(120, 52, 6), T2 = C(214, 128, 24), T3 = C(250, 180, 64), Hi = C(255, 244, 214), Core = C(64, 28, 6), Lume = C(255, 206, 110) },
    { Name = "Rose Quartz", T1 = C(120, 40, 70), T2 = C(212, 104, 142), T3 = C(240, 150, 182), Hi = C(255, 230, 238), Core = C(66, 20, 38), Lume = C(255, 176, 200) },
    { Name = "Peridot", T1 = C(28, 76, 12), T2 = C(98, 158, 34), T3 = C(150, 206, 70), Hi = C(232, 252, 200), Core = C(18, 42, 8), Lume = C(206, 255, 136) },
}
local P = PALETTES[VAR] or PALETTES[1]
Set.Palettes = PALETTES
Set.Colors = { Glow = P.Lume, Hot = P.T3, Accent = P.T2, Mid = P.T2 }
local TONE = { T1 = P.T1, T2 = P.T2, T3 = P.T3, Hi = P.Hi, Core = P.Core, Lume = P.Lume }
Set.Art = {}

local function bump(x, w) return math.max(0, 1 - math.abs(x) / w) end

Set.GunSkins = {
    { Id = "GeodeUSAS12", Name = "Geode Komrad 12", Gun = "USAS12", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = "Carved gemstone: the stock, the receiver, the handguard and the magazine are cut stones -- flat facets rising to a table, clear crystal over a darker heart with tiny lit inclusions, the colour deepening toward the bottom of each stone, held by small metal prongs. A glint runs across the facets on every shot and the hearts pulse on a kill.",
      Model = "Geode_USAS12", V3 = true, Color = P.Lume, Color2 = P.T2, Deco = "GeodeGun", Fit = { G = "USAS12", N = 3 } },
    { Id = "GeodePX4", Name = "Geode PX4 Storm", Gun = "PX4", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = "Carved gemstone: the slide's flanks and the grip panels are cut stones set side by side in a dark metal setting with polished bezels and prongs -- dozens of facets, deep to near-white. A glint runs across the facets on every shot and the hearts pulse on a kill.",
      Model = "Geode_PX4", V3 = true, Color = P.Lume, Color2 = P.T2, Deco = "GeodeGun", Fit = { G = "PX4", N = 3 } },
    { Id = "GeodeArc", Name = "Geode Arc Projector", Gun = "BEAM", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = "Carved gemstone: the stock, the body's flanks and the battery are cut stones set in a dark metal frame with polished bezels and prongs -- dozens of facets, deep to near-white. A glint runs across the facets on every shot and the hearts pulse on a kill.",
      Model = "Geode_BEAM", V3 = true, Color = P.Lume, Color2 = P.T2, Deco = "GeodeGun", Fit = { G = "BEAM", N = 3 }, BeamColor = P.T3 },
}

local function Tint(root: Instance)
    for _, p in ipairs(root:GetDescendants()) do
        if p:IsA("BasePart") then
            local col = TONE[p:GetAttribute("Tone") or ""]
            local sh = p:GetAttribute("Shade")
            if col and sh and sh ~= 1 then col = Color3.new(math.clamp(col.R * sh, 0, 1), math.clamp(col.G * sh, 0, 1), math.clamp(col.B * sh, 0, 1)) end
            if col then
                p.Color = col
                p.CastShadow = false
                p.Reflectance = 0
            end
        end
    end
end
Set.Build = {}
Set.Build.GeodeGun = function(model: Model, frame: BasePart, f: any, forView: boolean, H: any)
    Tint(model)
end

local lastKill = -99
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    local v = rig.SkinVars
    local model = rig.Gun
    if model and v.GemFor ~= model then
        v.GemFor, v.Gems = model, {}
        for _, p in ipairs(model:GetDescendants()) do
            local t = p:IsA("BasePart") and p:GetAttribute("Tone")
            if t == "T1" or t == "T2" or t == "T3" or t == "Hi" then table.insert(v.Gems, { P = p, C = p.Color, K = (t == "T3" or t == "Hi") and 1 or (t == "T2") and 0.7 or 0.45 }) end
        end
    end
    -- the glint: a blink after each shot, strongest on the top (lightest) facets
    local g = bump(st.SinceShot or 99, 0.1)
    if v.Gems and (g > 0 or v.GemLit) then
        v.GemLit = g > 0
        for _, e in ipairs(v.Gems) do e.P.Color = e.C:Lerp(Color3.new(1, 1, 1), 0.5 * g * e.K) end
    end
    -- the hearts: breathe softly, flare on a kill
    local since = os.clock() - lastKill
    st.Core = math.clamp(0.25 + 0.08 * math.sin(now * 2.2) + 0.75 * math.max(0, 1 - since / 0.9), 0, 1)
end
Set.Kill = function(H: any, pos: Vector3, low: boolean)
    lastKill = os.clock()
end

-- ===== numbers (SKIN UI 2026-10-29, owner: numbers "unique to the skin and the colorways you have equipped"): CUT GEMS.
-- Every number is a cut stone: a wide geometric face whose digits are FACETED -- hard bands of the stone's tones cut across
-- them on a slant (light table, mid crown, deep pavilion) -- with a dark setting round them; the set's GLINT runs across the
-- facets on every hit (the facet bands flash toward white and slide). CRIT = a gem outline (a turned square, the stone's
-- girdle) pops out behind the number in the lume colour; WEAK SPOT = a cut-stone glyph in front; a KILL = the HEART PULSES:
-- the outline rings out twice. Every colour is this copy's palette P (the stone).
local WHITE = Color3.new(1, 1, 1)
local function GdFacets(col, g)
    -- four slanted facet bands (hard edges): table (light), crown, the hit colour, pavilion (deep)
    local hi, lo = col:Lerp(WHITE, 0.7 + 0.3 * g), col:Lerp(Color3.new(0, 0, 0), 0.5 * (1 - g))
    local mid = col:Lerp(WHITE, 0.3 + 0.5 * g)
    return ColorSequence.new({ ColorSequenceKeypoint.new(0, hi), ColorSequenceKeypoint.new(0.3, hi), ColorSequenceKeypoint.new(0.301, mid),
        ColorSequenceKeypoint.new(0.55, mid), ColorSequenceKeypoint.new(0.551, col:Lerp(Color3.new(0, 0, 0), 0.15 * (1 - g))), ColorSequenceKeypoint.new(0.78, col:Lerp(Color3.new(0, 0, 0), 0.15 * (1 - g))),
        ColorSequenceKeypoint.new(0.781, lo), ColorSequenceKeypoint.new(1, lo) })
end
local function GdMotion(e, age, pa, life)
    local b = math.min(1, pa / 0.09)
    local s = 1 + 0.12 * (e.BumpAmp or 1) * (1 - b) ^ 2
    local up = 0.4 + 1.1 * (1 - (1 - math.min(1, age / 0.85)) ^ 3)
    return up, 0, s, 0, 0, 0
end
local function GdAccent(e)
    local box = Instance.new("Frame")
    box.Name = "GdGem"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 2
    local cut = Instance.new("TextLabel")
    cut.Name = "Cut"; cut.BackgroundTransparency = 1; cut.Size = UDim2.fromScale(1, 1); cut.ZIndex = 3; cut.TextColor3 = WHITE
    cut:SetAttribute("KeepFont", true); cut.Parent = box
    local g = Instance.new("UIGradient"); g.Rotation = 68; g.Parent = cut
    for i = 1, 2 do
        local o = Instance.new("Frame")
        o.Name = "Girdle" .. i; o.BackgroundTransparency = 1; o.AnchorPoint = Vector2.new(0.5, 0.5); o.Position = UDim2.fromScale(0.5, 0.5); o.Rotation = 45; o.ZIndex = 1
        local st = Instance.new("UIStroke"); st.Thickness = 2; st.Parent = o
        o.Parent = box
    end
    return box
end
local function GdAccentStep(e, box, age, pa, alpha)
    local lbl = e.Label
    local tb = lbl.TextBounds
    local cut = box:FindFirstChild("Cut")
    if cut then
        if cut.Text ~= lbl.Text then cut.Text = lbl.Text end
        if cut.FontFace ~= lbl.FontFace then cut.FontFace = lbl.FontFace end
        cut.TextSize = lbl.TextSize
        cut.TextTransparency = alpha
        local g = cut:FindFirstChildOfClass("UIGradient")
        if g then
            local glint = math.max(0, 1 - pa / 0.22)
            g.Color = GdFacets(e.Color or P.T3, glint)
            g.Offset = Vector2.new(0.25 * glint, 0)
        end
    end
    local kt = (e.Killed and e.KillAt) and (os.clock() - e.KillAt) or nil
    for i = 1, 2 do
        local o = box:FindFirstChild("Girdle" .. i)
        if o then
            local q
            if kt then q = (kt - (i - 1) * 0.32) / 0.45
            elseif e.Crit and not e.Dot and i == 1 then q = math.min(pa, age) / 0.3 end
            local on = q ~= nil and q >= 0 and q < 1
            o.Visible = on
            if on then
                local d = (tb.Y + 10) * (0.8 + 0.9 * (1 - (1 - q) ^ 2))
                o.Size = UDim2.fromOffset(d, d)
                local st = o:FindFirstChildOfClass("UIStroke")
                if st then st.Color = P.Lume; st.Transparency = math.clamp(alpha + q * 0.85, 0, 1) end
            end
        end
    end
end
-- ===== UI THEME (SKIN UI THEMES 2026-10-29 roll-out, owner: themes must "change up the colorways and provide a bit more style
-- than the default"; the set's first theme, Clean only -- no old window art): the clean language in the stone's own colours
-- (UITheme Clean: roles from P) + two touches of a cut geode. Hooks read only the palette they are given:
--   TAB MARK  a CUT-STONE BAR: the underline is faceted (hard steps deep -> light -> table -> light -> deep across it) and the
--             selected tab's facets catch a glint that runs across them every ~5 s
--   FIELD     a SLICED GEODE in the lower-left corner: a dark rind, agate bands in the stone's tones and a ring of crystal points
--             (druzy) round its hollow heart; a glint runs round the crystals now and then and the heart breathes
local GD_CLEAN = {
    Field = P.Core:Lerp(C(0, 0, 0), 0.6), Surface = P.Core:Lerp(C(0, 0, 0), 0.35), Raised = P.Core:Lerp(P.T1, 0.3), Hover = P.T1:Lerp(P.Core, 0.2),
    Well = P.Core:Lerp(C(0, 0, 0), 0.7), Line = P.T1:Lerp(P.T2, 0.35), Tip = P.Core:Lerp(C(0, 0, 0), 0.45),
    Accent = P.Lume, Mark = P.Hi, Hair = P.T3:Lerp(P.Hi, 0.2),
    Text = P.Hi, Sub = P.Hi:Lerp(P.T3, 0.5), Muted = P.T3:Lerp(P.Hi, 0.15), Ink = P.Core:Lerp(C(0, 0, 0), 0.6),
    T1 = P.T1, T2 = P.T2, T3 = P.T3, Gem = P.Hi, Lume = P.Lume, Core = P.Core, InkLine = P.Core:Lerp(C(0, 0, 0), 0.6),
}
local function GdBar(Q, g)
    -- the cut-stone bar's facets (the mark's own colour is the stone's light tone; a gradient can only darken it)
    local function D(c) return c:Lerp(WHITE, 0.15) end
    return ColorSequence.new({ ColorSequenceKeypoint.new(0, D(Q.T2)), ColorSequenceKeypoint.new(0.22, D(Q.T2)), ColorSequenceKeypoint.new(0.221, D(Q.T3)),
        ColorSequenceKeypoint.new(0.44, D(Q.T3)), ColorSequenceKeypoint.new(0.441, WHITE), ColorSequenceKeypoint.new(0.56, WHITE),
        ColorSequenceKeypoint.new(0.561, D(Q.T3)), ColorSequenceKeypoint.new(0.78, D(Q.T3)), ColorSequenceKeypoint.new(0.781, D(Q.T2)), ColorSequenceKeypoint.new(1, D(Q.T2)) })
end
GD_CLEAN.TabMark = function(mark, Q)
    local g = Instance.new("UIGradient")
    g.Name = "GdFacet"; g.Color = GdBar(Q); g.Parent = mark
    return { g }
end
GD_CLEAN.Sig = function(ctx)
    local Q, f = ctx.P, ctx.Frame
    local cam = workspace.CurrentCamera
    local vh = (cam and cam.ViewportSize.Y or 800)
    local R = math.clamp(math.floor(vh * 0.26), 120, 230)
    local geo = Instance.new("Frame")
    geo.Name = "GdGeode"; geo.BackgroundTransparency = 1; geo.AnchorPoint = Vector2.new(0.5, 0.5); geo.Position = UDim2.new(0, 0, 1, 0)
    geo.Size = UDim2.fromOffset(2 * R, 2 * R); geo.ZIndex = 0; geo.Parent = f
    local function Ring(r, col, th, tr)
        local o = Instance.new("Frame")
        o.Name = "GdBand"; o.BackgroundTransparency = 1; o.AnchorPoint = Vector2.new(0.5, 0.5); o.Position = UDim2.fromScale(0.5, 0.5)
        o.Size = UDim2.fromOffset(2 * r, 2 * r); o.ZIndex = 0
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = o
        local st = Instance.new("UIStroke"); st.Color = col; st.Thickness = th; st.Transparency = tr; st.Parent = o
        o.Parent = geo
        return o, st
    end
    -- the rind, then agate bands inward (thick / thin, light / deep, a little irregular)
    Ring(R - 5, Q.T1:Lerp(C(0, 0, 0), 0.4), 10, 0.45)
    local bands = { { 0.9, Q.T2, 3, 0.6 }, { 0.85, Q.Gem, 1, 0.65 }, { 0.8, Q.T1, 5, 0.55 }, { 0.74, Q.T3, 2, 0.6 }, { 0.7, Q.T2, 1, 0.65 }, { 0.66, Q.Gem, 1, 0.7 } }
    for _, b in ipairs(bands) do Ring(R * b[1], b[2], b[3], b[4]) end
    -- the hollow heart that breathes
    local heart = Instance.new("Frame")
    heart.Name = "GdHeart"; heart.BorderSizePixel = 0; heart.BackgroundColor3 = Q.Lume; heart.BackgroundTransparency = 0.9; heart.AnchorPoint = Vector2.new(0.5, 0.5)
    heart.Position = UDim2.fromScale(0.5, 0.5); heart.Size = UDim2.fromOffset(R * 0.9, R * 0.9); heart.ZIndex = 0
    local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(1, 0); hc.Parent = heart
    heart.Parent = geo
    -- DRUZY: a cluster of small crystal points (cut squares turned on edge, two-tone facets) grown on the inside of the agate
    -- bands, thickest near the rind, thinning toward the hollow heart (only the quarter that shows: up and right of the corner)
    local crystals = {}
    local rng = Random.new(41)
    local n = 22
    for i = 1, n do
        local a = math.rad(-86 + rng:NextNumber() * 82) -- (screen angles: -90 = up, 0 = right)
        local depth = rng:NextNumber() ^ 0.7
        local r0 = R * (0.62 - 0.26 * depth)
        local sz = math.floor(R * (0.085 - 0.045 * depth) * (0.75 + 0.5 * rng:NextNumber()))
        local c = Instance.new("Frame")
        c.Name = "GdCrystal"; c.BorderSizePixel = 0; c.BackgroundColor3 = WHITE; c.AnchorPoint = Vector2.new(0.5, 0.5); c.ZIndex = 0
        c.Size = UDim2.fromOffset(math.max(5, sz), math.max(5, sz))
        c.Position = UDim2.new(0.5, math.cos(a) * r0, 0.5, math.sin(a) * r0); c.Rotation = 45 + rng:NextNumber() * 12 - 6
        local g = Instance.new("UIGradient"); g.Rotation = -45 + math.deg(a); g.Parent = c
        c.BackgroundTransparency = 0.35 + 0.3 * depth
        c.Parent = geo
        crystals[i] = { F = c, G = g, U = (math.deg(a) + 86) / 82 }
    end
    local function Facet(c, glint)
        local hi = Q.Gem:Lerp(WHITE, 0.4 * glint)
        return ColorSequence.new({ ColorSequenceKeypoint.new(0, hi), ColorSequenceKeypoint.new(0.5, hi), ColorSequenceKeypoint.new(0.501, Q.T3:Lerp(WHITE, 0.5 * glint)),
            ColorSequenceKeypoint.new(1, Q.T2:Lerp(WHITE, 0.3 * glint)) })
    end
    for _, c in ipairs(crystals) do c.G.Color = Facet(c, 0) end
    local seed = math.random() * 5
    local lit = {}
    return function(now, _dt)
        -- a glint runs round the crystals every ~5 s (only the ones it passes are re-coloured)
        local k = ((now + seed) % 5.5) / 1.1
        for i, c in ipairs(crystals) do
            local g = (k < 1.2) and math.max(0, 1 - math.abs(k - c.U) * 6) or 0
            if g > 0 or lit[i] then
                lit[i] = g > 0
                c.G.Color = Facet(c, g)
            end
        end
        heart.BackgroundTransparency = 0.86 + 0.06 * math.sin(now * 1.3)
        -- the selected tab's facets: a glint slides across them every ~5 s
        local t = ((now + seed) % 5) / 0.6
        for _, m in ipairs(ctx.Marks()) do
            local gr = m.Visible and m:FindFirstChild("GdFacet")
            if gr then gr.Offset = Vector2.new((t < 1) and (-0.5 + t) or 0, 0) end
        end
    end, nil
end
local function PG(top, bottom) return { Top = top, Bottom = bottom } end
Set.Theme = { Name = "Geode", Desc = "Menus cut from the stone: the tabs are faceted bars that catch a glint, and a sliced geode sits in the corner -- a dark rind, agate bands and a ring of crystal points round its glowing heart.",
    Panel = PG(P.Core:Lerp(P.T1, 0.3), P.Core:Lerp(C(0, 0, 0), 0.4)), Card = PG(P.T1:Lerp(P.Core, 0.3), P.Core), Title = PG(P.T2, P.T1),
    Accent = P.Lume, Accent2 = P.T3, HpFill = P.T3, HpBg = P.Core:Lerp(C(0, 0, 0), 0.5), XpFill = P.Lume, Text = P.Hi,
    BorderThick = 2,
    Clean = GD_CLEAN, -- (SKIN UI THEMES: the clean palette + cut-stone tab marks + the sliced geode)
    -- (SKIN UI 2026-10-29: faceted gem digits, a glint per hit, a girdle on crits, the heart pulsing on a kill; this stone's P)
    Numbers = { Font = "Michroma", Glyph = "◆", NoBang = true, Motion = GdMotion, Accent = GdAccent, AccentStep = GdAccentStep,
        Normal = P.T3:Lerp(P.Hi, 0.3), Crit = P.Lume, Weak = P.Hi, Stroke = P.Core:Lerp(C(0, 0, 0), 0.5), StrokeThick = 2, Size = 0.92 } }

return Set
