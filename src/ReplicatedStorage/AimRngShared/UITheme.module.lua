--!nocheck
-- UI THEME ENGINE (client). Draws a HudThemes entry over the WHOLE interface:
--   * UIStyle tags what it builds -- window surfaces (UIT_Window), title bars (UIT_Title), cards (UIT_Card), chips
--     (UIT_Chip) -- and the client tags the HUD panels (UIT_Hud). Every tagged object (now or created later) is styled.
--   * colours: window glass, cards, chips, title bars, borders, the accent glow, HUD panels + bars (SetBars)
--   * premium extras, all in a "UIT_Deco" layer under each window's content: tiled art (Tex / Tex2, scrolling or
--     pulsing), corner ornaments, ambient particles; a title emblem; an animated border (a UIGradient on the window's
--     UIStroke); the theme's header typeface on every heading in the game; an effect when a window opens.
--   * Default restores every touched property exactly (snapshots) and removes the decorations.
-- UITheme.Preview(parent, theme) builds a miniature themed window (store cards), animated by the same loop.
-- (v3, FX AUDIT 2026-10-14, owner: "the ... UI are very lack luster ... everything feels incredibly samey"): a theme may
-- bring its OWN frame ornaments, motion and open instead of the shared corner sprite / ambient / open list -- hooks on the
-- theme table (a set's Set.Theme), each called with a ctx { Frame (the UIT_Deco layer), Surface, Kind, Root, Theme,
-- UIStyle, Art, Tween, Small }:
--   Deco(ctx) -> tick?, extras?   builds its ornaments into ctx.Frame (under the content) or an overlay of its own on
--                        ctx.Root (over it; return those instances as extras); tick(now, dt) runs while the window shows
--   OpenFn(ctx)          its own window-open motion (replaces Open)
--   TitleDeco(ctx)       a type accent on every title bar (ctx.Title = the bar); returns the instances it made
-- Rules (icon look): flat lit faces + one hard facet + ink edges, no gloss, no hazard stripes, nothing over the crosshair.
local UITheme = {}

local CS = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Shared = script.Parent
local Art = require(Shared:WaitForChild("CosmeticArt"))
local UIStyle = require(Shared:WaitForChild("UIStyle"))

local TAG = { Window = "UIT_Window", Title = "UIT_Title", Card = "UIT_Card", Chip = "UIT_Chip", Hud = "UIT_Hud", Field = "UIT_Field" }
UITheme.Tags = TAG
local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
local WHITE = Color3.new(1, 1, 1)

local current = nil -- the applied theme (nil = Default)
-- (STRONG tables, pruned of destroyed objects every few seconds: an Instance used as a weak key can vanish while the
-- instance still exists -- its Lua handle gets collected -- which lost decorations / snapshots and stacked themes)
local snaps = {} -- instance -> { prop = original }
local recs = {} -- tagged instance -> { Kind, Deco, StrokeGrad, Motes, ... }
local fontTouched = {} -- text object -> true (font swapped)
local previews = {} -- preview root -> rec list
local function Prune()
    for _, tbl in ipairs({ snaps, recs, fontTouched, previews }) do
        for inst in pairs(tbl) do
            if typeof(inst) == "Instance" and not inst.Parent then tbl[inst] = nil end
        end
    end
end
local bars = {}
local changedFns = {}

-- ===== property snapshots =====
local function Snap(inst, prop)
    local s = snaps[inst]
    if not s then s = {}; snaps[inst] = s end
    if s[prop] == nil then s[prop] = inst[prop] end
end
local function Set(inst, prop, v)
    if not inst then return end
    Snap(inst, prop)
    if inst[prop] ~= v then inst[prop] = v end
end
local function Restore(inst)
    local s = snaps[inst]
    if not s then return end
    for k, v in pairs(s) do pcall(function() inst[k] = v end) end
    snaps[inst] = nil
end

local function Seq(a, b) return ColorSequence.new(a, b) end
local function K(t, c) return ColorSequenceKeypoint.new(t, c) end
local RAINBOW = ColorSequence.new({ K(0, Color3.fromRGB(255, 80, 80)), K(0.17, Color3.fromRGB(255, 200, 60)), K(0.33, Color3.fromRGB(90, 255, 120)),
    K(0.5, Color3.fromRGB(60, 220, 255)), K(0.67, Color3.fromRGB(110, 110, 255)), K(0.83, Color3.fromRGB(255, 90, 230)), K(1, Color3.fromRGB(255, 80, 80)) })
local function BorderStroke(g)
    for _, c in ipairs(g:GetChildren()) do
        if c:IsA("UIStroke") and c.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then return c end
    end
    return nil
end
local function Grad(g)
    for _, c in ipairs(g:GetChildren()) do if c:IsA("UIGradient") and c.Name ~= "UIT_StrokeGrad" then return c end end
    return nil
end
local function Darken(c, t) return c:Lerp(Color3.new(0, 0, 0), t) end

-- ===== CLEAN PALETTE (SKIN UI THEMES 2026-10-28) =====
-- owner: "the images on the top of menu get stretched for every one, and they just feel lazy and not much different. It
-- should change up the colorways and provide a bit more style than the default". A theme with a Clean table re-colours the
-- UI CLEAN language itself instead of laying old art over it:
--   PALETTE  roles Field (the full-screen menu field) / Surface (Bg0) / Raised (Bg1: cards, rows, tiles) / Hover (Bg2) / Well /
--            Line / Border / Steel / CardDark / Tip (the item card) / Accent (primary + selection) / Mark (tab underlines) /
--            Hair (hairlines, quiet outlines) / Text / Sub / Muted / OnAccent. A missing role is derived from the theme's Panel /
--            Card / Accent; Text / Sub / Muted are lifted until they reach 7 / 4.5 / 4.5 : 1 on the lightest surface (Hover);
--            OnAccent = ink or white, whichever reads on the accent. Colourways: HudThemes.Variant maps Clean like every colour
--            (the set's colourway copy wins), so hooks read ctx.P / the P they are given, never their module's own palette.
--   HOW      UIStyle.Colors is re-pointed (whatever paints later uses the theme) and every object under the menu roots
--            (UITheme.SetMenuRoots: the HUD's Menus folder + the item cards) whose colour IS a palette token is re-painted once
--            and watched for repaints (one property signal per touched object; event-driven, no per-frame work).
--            Default = back to UI CLEAN exactly (the same token walk with the Default palette).
--   STYLE    Clean.Sig(ctx) -> tick?, extras?  the set's signature touches on every full-screen menu field (tag UIT_Field;
--            ctx = { Frame (a layer under the content), Field, Top (the top bar), P, Art, Marks () -> the top bar's tab marks,
--            Phone, Keep(o) }); tick(now, dt) runs in the one loop while the field shows. Clean.TabMark(mark, P) -> instances:
--            dresses every tab mark (frames named Under / SelEdge / KitMark; code re-sizes them, so a hook ADDS children).
--            RULE for those children: tab buttons are AutomaticSize X and read a child's Position + Size WITHOUT its
--            AnchorPoint -- anchor them left and keep Position.X + Size.X inside the mark (a star at Position (1, 0) with
--            AnchorPoint (1, 0.5) grew the tab across the whole screen, and a scale-sized mark never shrinks back).
--   A Clean theme draws none of the old art (window Deco / corners / watermark / motes / title emblem / TitleDeco).
local function Lum(c)
    local function L(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
    return 0.2126 * L(c.R) + 0.7152 * L(c.G) + 0.0722 * L(c.B)
end
local function Contrast(a, b)
    local x, y = Lum(a), Lum(b)
    if x < y then x, y = y, x end
    return (x + 0.05) / (y + 0.05)
end
UITheme.Contrast = Contrast
local function Lift(c, bg, need)
    for _ = 1, 24 do
        if Contrast(c, bg) >= need then return c end
        c = c:Lerp(WHITE, 0.08)
    end
    return c
end
local UC = UIStyle.Colors
local DEF = { -- UI CLEAN (Default), read once before any theme re-points UIStyle.Colors
    Field = UC.Field or Color3.fromRGB(13, 16, 21), Surface = UC.Bg0, Raised = UC.Bg1, Hover = UC.Bg2, Well = UC.Well, Line = UC.Line,
    Border = UC.Border, Steel = UC.Steel, CardDark = UC.CardDark, Tip = Color3.fromRGB(10, 12, 16), Accent = UC.Accent, Mark = UC.Text,
    Hair = UC.Text, Text = UC.Text, Sub = UC.Sub, Muted = UC.Muted, OnAccent = UC.OnAccent }
UITheme.CLEAN_DEFAULT = DEF
local ROLE_KEYS = { Field = { "Field" }, Surface = { "Bg0", "BgTop", "BgBottom" }, Raised = { "Bg1", "Card" }, Hover = { "Bg2" }, Well = { "Well" },
    Line = { "Line" }, Border = { "Border" }, Steel = { "Steel", "Off" }, CardDark = { "CardDark" }, Accent = { "Accent", "Neon", "Neon2" },
    OnAccent = { "OnAccent" }, Text = { "Text" }, Sub = { "Sub" }, Muted = { "Muted" } }
local MARK_NAMES = { Under = true, SelEdge = true, KitMark = true }
UITheme.MARK_NAMES = MARK_NAMES
local palCache = setmetatable({}, { __mode = "k" })
local function Palette(t)
    if not (t and type(t.Clean) == "table") then return nil end
    local hit = palCache[t]
    if hit then return hit end
    local cl = t.Clean
    local acc = cl.Accent or t.Accent or DEF.Accent
    local surf = cl.Surface or (t.Panel and t.Panel.Bottom:Lerp(t.Panel.Top, 0.3)) or DEF.Surface
    local P = { Accent = acc, Surface = surf }
    P.Field = cl.Field or Darken(surf, 0.25)
    P.Raised = cl.Raised or (t.Card and t.Card.Bottom:Lerp(t.Card.Top, 0.5)) or surf:Lerp(WHITE, 0.05)
    P.Hover = cl.Hover or P.Raised:Lerp(acc, 0.1):Lerp(WHITE, 0.04)
    P.Well = cl.Well or Darken(P.Field, 0.35)
    P.Line = cl.Line or P.Raised:Lerp(acc, 0.22):Lerp(WHITE, 0.06)
    P.Border = cl.Border or P.Line:Lerp(WHITE, 0.05)
    P.Steel = cl.Steel or surf:Lerp(P.Raised, 0.5)
    P.CardDark = cl.CardDark or Darken(surf, 0.2)
    P.Tip = cl.Tip or Darken(surf, 0.15)
    P.Mark = cl.Mark or acc
    P.Hair = cl.Hair or acc
    P.Text = Lift(cl.Text or DEF.Text, P.Hover, 7)
    P.Sub = Lift(cl.Sub or DEF.Sub, P.Hover, 4.5)
    P.Muted = Lift(cl.Muted or DEF.Muted, P.Hover, 4.5)
    local ink = cl.Ink or Color3.fromRGB(10, 10, 12)
    P.OnAccent = (Contrast(ink, acc) >= Contrast(WHITE, acc)) and ink or WHITE
    for k, v in pairs(cl) do if P[k] == nil then P[k] = v end end -- (the set's own extra colours: Silk, Star, Ember ...)
    palCache[t] = P
    return P
end
UITheme.Palette = Palette

-- every palette applied this session (Default first): a colour that is a token of ANY of them is re-painted to the live one
local palAll = {}
local bgRole, txtRole, strokeRole, AH = {}, {}, {}, {}
local function Learn(P)
    for _, q in ipairs(palAll) do if q == P then return end end
    for r, v in pairs(DEF) do if typeof(P[r]) ~= "Color3" then P[r] = v end end -- (a role that isn't a colour = Default's)
    table.insert(palAll, P)
    for _, r in ipairs({ "Field", "Surface", "Raised", "Hover", "Well", "Line", "Border", "Steel", "CardDark", "Tip" }) do
        local h = P[r]:ToHex()
        if bgRole[h] == nil then bgRole[h] = r end
    end
    -- (Accent / Mark / Hair / Text as a BACKGROUND = a mark or a primary when solid, a hairline when see-through)
    for _, r in ipairs({ "Accent", "Mark", "Hair", "Text" }) do AH[P[r]:ToHex()] = true end
    for _, r in ipairs({ "Text", "Sub", "Muted", "OnAccent" }) do
        local h = P[r]:ToHex()
        if txtRole[h] == nil then txtRole[h] = r end
    end
    for _, r in ipairs({ "Line", "Border" }) do
        local h = P[r]:ToHex()
        if strokeRole[h] == nil then strokeRole[h] = r end
    end
    -- (a button made with any theme's accent stays the primary: UIStyle.IsPrimary reads this list)
    UIStyle.PRIMARY_KNOWN = UIStyle.PRIMARY_KNOWN or {}
    table.insert(UIStyle.PRIMARY_KNOWN, P.Accent)
end
Learn(DEF)
local pal = DEF -- the live palette
local cleanUsed = false -- (nothing is walked or watched until a Clean theme has been worn once)
local watched = {} -- object -> { prop = connection }
local markX = {} -- tab mark -> instances its theme hook made
local menuRoots = {}
local function PaintProp(o, prop)
    if prop == "BackgroundColor3" then
        local h = o.BackgroundColor3:ToHex()
        local c
        if AH[h] then
            if MARK_NAMES[o.Name] then c = pal.Mark
            else c = (o.BackgroundTransparency >= 0.5) and pal.Hair or pal.Accent end
        else
            local r = bgRole[h]
            c = r and pal[r]
        end
        if c and o.BackgroundColor3 ~= c then o.BackgroundColor3 = c end
        return c ~= nil
    elseif prop == "TextColor3" then
        local r = txtRole[o.TextColor3:ToHex()]
        local c = r and pal[r]
        if c and o.TextColor3 ~= c then o.TextColor3 = c end
        return c ~= nil
    else -- UIStroke.Color
        local h = o.Color:ToHex()
        local c
        if AH[h] then c = (o.Transparency >= 0.5) and pal.Hair or pal.Accent
        else
            local r = strokeRole[h]
            c = r and pal[r]
        end
        if c and o.Color ~= c then o.Color = c end
        return c ~= nil
    end
end
local function Watch(o, prop)
    local w = watched[o]
    if not w then w = {}; watched[o] = w end
    if w[prop] then return end
    w[prop] = o:GetPropertyChangedSignal(prop):Connect(function() PaintProp(o, prop) end)
end
local function DressMark(o)
    local old = markX[o]
    if old then
        for _, x in ipairs(old) do if typeof(x) == "Instance" then x:Destroy() end end
        markX[o] = nil
    end
    local hook = current and current.Clean and current.Clean.TabMark
    if pal ~= DEF and type(hook) == "function" then
        local ok, made = pcall(hook, o, pal)
        if ok and type(made) == "table" then
            for _, x in ipairs(made) do
                if typeof(x) == "Instance" then
                    x:SetAttribute("UITKeep", true)
                    for _, d in ipairs(x:GetDescendants()) do d:SetAttribute("UITKeep", true) end
                end
            end
            markX[o] = made
        elseif not ok then warn("[UITheme] Mark: " .. tostring(made)) end
    end
end
local function Remap(o)
    if o:GetAttribute("UITKeep") then return end
    if o:IsA("GuiObject") then
        if PaintProp(o, "BackgroundColor3") then Watch(o, "BackgroundColor3") end
        if (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")) and PaintProp(o, "TextColor3") then Watch(o, "TextColor3") end
        if MARK_NAMES[o.Name] and o:IsA("Frame") then DressMark(o) end
    elseif o:IsA("UIStroke") then
        if PaintProp(o, "Color") then Watch(o, "Color") end
    end
end
local function WalkRoots()
    for _, r in ipairs(menuRoots) do
        if r.Parent then
            Remap(r)
            for _, d in ipairs(r:GetDescendants()) do Remap(d) end
        end
    end
end
local function ApplyPalette(P)
    local target = P or DEF
    if target == pal then return end
    if not P and not cleanUsed then return end
    cleanUsed = true
    Learn(target)
    pal = target
    for role, keys in pairs(ROLE_KEYS) do
        for _, k in ipairs(keys) do UC[k] = target[role] end
    end
    -- (MenuKit.Sweep turns hued strokes / slabs neutral: the theme's own colours are not "hues" to it -- see MenuKit Hue)
    local hues = {}
    if P then for _, v in pairs(target) do if typeof(v) == "Color3" then hues[v:ToHex()] = true end end end
    UIStyle.ThemeHues = hues
    WalkRoots()
end
-- containers whose descendants follow the palette (the client: the HUD's Menus folder, the item cards)
function UITheme.SetMenuRoots(list)
    for _, r in ipairs(list or {}) do
        if typeof(r) == "Instance" and not table.find(menuRoots, r) then
            table.insert(menuRoots, r)
            r.DescendantAdded:Connect(function(d)
                if not cleanUsed then return end
                task.defer(function() if d.Parent then Remap(d) end end)
            end)
            if cleanUsed then
                Remap(r)
                for _, d in ipairs(r:GetDescendants()) do Remap(d) end
            end
        end
    end
end
-- the live palette (Default = UI CLEAN's) -- for code that draws its own colours
function UITheme.Clean() return pal end
local function PruneClean()
    for _, tbl in ipairs({ watched, markX }) do
        for inst in pairs(tbl) do
            if not inst.Parent then tbl[inst] = nil end
        end
    end
end

-- ===== decorations =====
local function NewImage(parent, props)
    local im = Instance.new("ImageLabel")
    im.BackgroundTransparency = 1
    im.BorderSizePixel = 0
    for k, v in pairs(props) do im[k] = v end
    im:SetAttribute("Skinned", true)
    im.Parent = parent
    return im
end

local function StrokeFx(rec, stroke, t, thick)
    if not stroke then return end
    Set(stroke, "Color", t.Border and WHITE or t.Accent)
    Set(stroke, "Thickness", thick)
    Set(stroke, "Transparency", 0)
    if not t.Border then return end
    local g = Instance.new("UIGradient")
    g.Name = "UIT_StrokeGrad"
    local a, b = t.Accent, t.Accent2 or t.Accent
    if t.Border == "Rainbow" then
        g.Color = RAINBOW
    elseif t.Border == "Shimmer" then
        g.Color = ColorSequence.new({ K(0, a), K(0.42, a), K(0.5, b), K(0.58, a), K(1, a) })
        g.Rotation = 25
    elseif t.Border == "Pulse" then
        g.Color = Seq(a, b)
        g.Rotation = 90
    else -- Flow / Duo: two colours chasing round the window
        g.Color = ColorSequence.new({ K(0, a), K(0.5, b), K(1, a) })
    end
    g.Parent = stroke
    rec.StrokeGrad, rec.Stroke, rec.Border, rec.BaseThick = g, stroke, t.Border, thick
end

local AMBIENT = {
    Motes = { N = 9, Size = { 5, 10 }, Vel = Vector2.new(0, -14), Wobble = 10, Tex = "Glow" },
    Embers = { N = 11, Size = { 4, 8 }, Vel = Vector2.new(0, -34), Wobble = 14, Tex = "Glow" },
    Stars = { N = 12, Size = { 3, 7 }, Vel = Vector2.new(-6, 0), Wobble = 3, Tex = "Glow", Twinkle = true },
    Data = { N = 10, Size = { 3, 5 }, Vel = Vector2.new(0, -44), Wobble = 0, Tex = "Glow", Square = true },
    Sparkle = { N = 10, Size = { 4, 9 }, Vel = Vector2.new(4, -8), Wobble = 6, Tex = "Glow", Twinkle = true, Rainbow = true },
    -- (0.58, owner: "the UI themes in general need to feel higher effort") SHAPED particles: white sprites
    -- (tools/make_theme_sprites.py) tinted with the theme's AmbientColor, tumbling (Spin deg/s) as they drift
    Petals = { N = 9, Size = { 11, 19 }, Vel = Vector2.new(9, 24), Wobble = 18, Tex = "SpPetal", Spin = 70 },
    Leaves = { N = 8, Size = { 13, 21 }, Vel = Vector2.new(7, 22), Wobble = 24, Tex = "SpLeaf", Spin = 55 },
    Bubbles = { N = 10, Size = { 7, 20 }, Vel = Vector2.new(0, -24), Wobble = 9, Tex = "SpBubble" },
    Hearts = { N = 8, Size = { 9, 16 }, Vel = Vector2.new(0, -17), Wobble = 11, Tex = "SpHeart", Twinkle = true },
    Snowfall = { N = 10, Size = { 8, 15 }, Vel = Vector2.new(4, 15), Wobble = 10, Tex = "SpSnow", Spin = 25 },
    Sparkles = { N = 9, Size = { 9, 17 }, Vel = Vector2.new(3, -6), Wobble = 5, Tex = "SpSparkle", Twinkle = true, Spin = 20 },
    Bolts = { N = 5, Size = { 12, 20 }, Vel = Vector2.new(0, 10), Wobble = 0, Tex = "SpBolt", Flicker = true },
    Coins = { N = 7, Size = { 10, 16 }, Vel = Vector2.new(0, 20), Wobble = 6, Tex = "SpCoin", Flip = true },
    Bats = { N = 6, Size = { 14, 22 }, Vel = Vector2.new(-22, -5), Wobble = 14, Tex = "SpBat", Flap = true },
    Paws = { N = 6, Size = { 10, 15 }, Vel = Vector2.new(5, -9), Wobble = 4, Tex = "SpPaw", Twinkle = true, Spin = 8 },
    Notes = { N = 7, Size = { 11, 17 }, Vel = Vector2.new(5, -16), Wobble = 12, Tex = "SpNote", Spin = 12 },
    Bokeh = { N = 7, Size = { 18, 34 }, Vel = Vector2.new(3, -4), Wobble = 6, Tex = "SpBokeh", Twinkle = true },
    -- (SKINS V3 bundle 3, TOURBILLON) slow watch wheels drifting and turning; the sprite comes with the set (Set.Art.SpGear)
    Gears = { N = 5, Size = { 16, 30 }, Vel = Vector2.new(2, -3), Wobble = 2, Tex = "SpGear", Spin = 14 },
    -- (SKINS V3 bundle 6, CARAPACE) glowing motes that wander slowly and blink; the sprite comes with the set (Set.Art.SpFirefly)
    Fireflies = { N = 8, Size = { 6, 12 }, Vel = Vector2.new(3, -5), Wobble = 16, Tex = "SpFirefly", Twinkle = true },
    -- (SKINS V3 bundle 10, SLIPSTREAM) a few thin speed streaks slipping past to the left; the sprite comes with the set (Set.Art.SpStreak)
    Streaks = { N = 5, Size = { 16, 30 }, Vel = Vector2.new(-70, 0), Wobble = 1, Tex = "SpStreak" },
    -- (SKINS V3 bundle 13, SILKFANG) a few silk threads with a dewdrop letting down slowly; the sprite comes with the set (Set.Art.SpThread)
    Threads = { N = 5, Size = { 18, 30 }, Vel = Vector2.new(0, 16), Wobble = 3, Tex = "SpThread", Twinkle = true },
}

local function HasLayout(g)
    for _, c in ipairs(g:GetChildren()) do
        if c:IsA("UIGridStyleLayout") or c:IsA("UIPageLayout") or c:IsA("UITableLayout") then return true end
    end
    return false
end
local function MakeDeco(rec, surface, t, kind)
    -- (a surface that lays its children out in a list / grid would take the art layer as one more item -- and grow
    -- to fit it: those get the colours + border only)
    if HasLayout(surface) then return end
    local f = Instance.new("Frame")
    f.Name = "UIT_Deco"
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.Size = UDim2.fromScale(1, 1)
    f.ClipsDescendants = true
    f.ZIndex = rec.DecoZ or 0
    f:SetAttribute("Skinned", true)
    f:SetAttribute("NoSkin", true)
    local corner = surface:FindFirstChildOfClass("UICorner")
    if corner then corner:Clone().Parent = f end
    f.Parent = surface
    rec.Deco = f
    local small = kind == "Hud" or kind == "Card" or kind == "Chip"
    -- tiled art layers
    local function Layer(key, tr, tile, scroll, pulse, name)
        if not (key and Art[key]) then return end
        tile = tile or 220
        if small then tile = math.floor(tile * 0.6) end
        local im = NewImage(f, { Name = name, Image = Art[key], ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(tile, tile),
            Size = UDim2.new(1, tile * 2, 1, tile * 2), Position = UDim2.fromOffset(-tile, -tile), ImageTransparency = math.min(0.97, (tr or 0.8) + (small and 0.06 or 0)), ZIndex = f.ZIndex })
        table.insert(rec.Layers, { Img = im, Tile = tile, Scroll = scroll, Pulse = pulse, BaseT = im.ImageTransparency })
    end
    rec.Layers = {}
    Layer(t.Tex, t.TexT, t.TexTile, t.TexScroll, t.TexPulse, "Tex")
    Layer(t.Tex2, t.Tex2T, t.Tex2Tile, t.Tex2Scroll, t.Tex2Pulse, "Tex2")
    -- corner ornaments (windows / HUD panels)
    if t.Corner and Art[t.Corner] and (kind == "Window" or kind == "Hud") then
        local abs = surface.AbsoluteSize
        local s = math.clamp(math.min(abs.X, abs.Y) * 0.2, 22, kind == "Hud" and 34 or 86)
        for _, c in ipairs({ { 0, 0, 0 }, { 1, 0, 90 }, { 1, 1, 180 }, { 0, 1, 270 } }) do
            NewImage(f, { Name = "Corner", Image = Art[t.Corner], Size = UDim2.fromOffset(s, s), AnchorPoint = Vector2.new(c[1], c[2]),
                Position = UDim2.fromScale(c[1], c[2]), Rotation = c[3], ZIndex = f.ZIndex + 1, ImageColor3 = t.CornerColor or WHITE,
                ImageTransparency = t.CornerT or 0 })
        end
    end
    -- WATERMARK (0.58): the set's emblem, big and faint, in the lower right of every window (breathes slowly)
    if t.Watermark and Art[t.Watermark] and kind == "Window" then
        local abs = surface.AbsoluteSize
        local s = math.clamp(math.min(abs.X, abs.Y) * 0.55, 120, 380)
        rec.Watermark = NewImage(f, { Name = "Watermark", Image = Art[t.Watermark], ImageColor3 = t.WatermarkColor or WHITE,
            ImageTransparency = t.WatermarkT or 0.9, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(s * 1.6, s),
            AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, s * 0.18, 1, s * 0.12), Rotation = -8, ZIndex = f.ZIndex })
        rec.WatermarkT = t.WatermarkT or 0.9
    end
    -- ambient particles drifting through the window
    if kind == "Window" then
        rec.Motes = {}
        -- (two layers: Ambient + an optional Ambient2, each with its own colour -- e.g. petals over soft bokeh)
        for _, L in ipairs({ { t.Ambient, t.AmbientColor }, { t.Ambient2, t.Ambient2Color or t.AmbientColor } }) do
            local amb = L[1] and AMBIENT[L[1]]
            if amb then
                local col = L[2] or WHITE
                for _ = 1, amb.N do
                    local sz = math.random(amb.Size[1], amb.Size[2])
                    local m = NewImage(f, { Name = "Mote", Image = amb.Square and "" or (Art[amb.Tex] or Art.Glow), BackgroundTransparency = amb.Square and 0.2 or 1,
                        BackgroundColor3 = col, ImageColor3 = col, Size = UDim2.fromOffset(sz, amb.Square and sz * 3 or sz),
                        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(math.random(), math.random()), ZIndex = f.ZIndex + 1, ImageTransparency = 0.2,
                        Rotation = math.random(0, 359) })
                    table.insert(rec.Motes, { Img = m, X = math.random(), Y = math.random(), Ph = math.random() * 6.28, Sp = 0.6 + math.random() * 0.8,
                        Amb = amb, Rot = m.Rotation, Size = sz })
                end
            end
        end
        if #rec.Motes == 0 then rec.Motes = nil end
    end
    -- (v3) the theme's own ornaments + motion
    if type(t.Deco) == "function" then
        local ok, tick, extra = pcall(t.Deco, { Frame = f, Surface = surface, Kind = kind, Root = rec.Root, Theme = t, UIStyle = UIStyle, Art = Art,
            Tween = TweenService, Small = small })
        if ok and type(tick) == "function" then rec.Tick = tick
        elseif not ok then warn("[UITheme] Deco: " .. tostring(tick)) end
        -- (ornaments that must sit OVER the window's title bar / content -- an overlay on the root -- come back as `extra`
        -- and are destroyed with the rest of the styling)
        if ok and type(extra) == "table" then
            rec.Extra = rec.Extra or {}
            for _, x in ipairs(extra) do table.insert(rec.Extra, x) end
        end
    end
end

-- an effect when a window opens. OFF (2026-10-15, owner: "Remove the menu effects from the UI themes for now (opening
-- stuff etc). Right now theyre horrible, we will redo them another time"): themes keep their look, no open motion.
UITheme.OPEN_FX = false
local function OpenFx(rec, t)
    if not UITheme.OPEN_FX then return end
    local f = rec.Deco
    local root = rec.Root
    if not (f and root and (t.Open or t.OpenFn)) then return end
    local col = t.OpenColor or t.Accent
    if type(t.OpenFn) == "function" then
        local ok, err = pcall(t.OpenFn, { Frame = f, Root = root, Theme = t, UIStyle = UIStyle, Art = Art, Tween = TweenService })
        if not ok then warn("[UITheme] OpenFn: " .. tostring(err)) end
        return
    end
    if t.Open == "Flash" then
        local fl = Instance.new("Frame"); fl.BackgroundColor3 = col; fl.BackgroundTransparency = 0.35; fl.BorderSizePixel = 0
        fl.Size = UDim2.fromScale(1, 1); fl.ZIndex = f.ZIndex + 2; fl.Parent = f
        TweenService:Create(fl, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
        local rays = NewImage(f, { Image = Art.Rays, ImageColor3 = col, ImageTransparency = 0.25, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.12), Size = UDim2.fromOffset(520, 520), ZIndex = f.ZIndex + 1 })
        TweenService:Create(rays, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { ImageTransparency = 1, Rotation = 40, Size = UDim2.fromOffset(700, 700) }):Play()
        task.delay(1.2, function() fl:Destroy(); rays:Destroy() end)
    elseif t.Open == "Glitch" then
        local base = root.Position
        task.spawn(function()
            for i = 1, 7 do
                if not root.Parent then break end
                -- (owner 2026-10-04: "I dont want the inventory to shake when you open it" -- the window stays put, only the slices flash)
                local sl = Instance.new("Frame"); sl.BorderSizePixel = 0; sl.BackgroundColor3 = (i % 2 == 0) and t.Accent or col
                sl.BackgroundTransparency = 0.45; sl.Size = UDim2.new(1, 0, 0, math.random(4, 16)); sl.Position = UDim2.fromScale(0, math.random())
                sl.ZIndex = f.ZIndex + 2; sl.Parent = f
                task.delay(0.06, function() sl:Destroy() end)
                task.wait(0.035)
            end
            if root.Parent then root.Position = base end
        end)
    elseif t.Open == "Flare" then
        local fl = Instance.new("Frame"); fl.BackgroundColor3 = col; fl.BorderSizePixel = 0; fl.Size = UDim2.fromScale(1, 1); fl.ZIndex = f.ZIndex + 2
        local g = Instance.new("UIGradient"); g.Rotation = -90
        g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.6, 0.85), NumberSequenceKeypoint.new(1, 1) }); g.Parent = fl
        fl.Parent = f
        TweenService:Create(fl, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
        task.delay(0.7, function() fl:Destroy() end)
    elseif t.Open == "Implode" then
        local pop = root:FindFirstChild("PopScale")
        if pop and pop:IsA("UIScale") then
            local fit = tonumber(pop:GetAttribute("Fit")) or 1
            pop.Scale = fit -- (no bounce on open: it read as a shake)
        end
        local fl = Instance.new("Frame"); fl.BackgroundColor3 = col; fl.BackgroundTransparency = 0.3; fl.BorderSizePixel = 0; fl.Size = UDim2.fromScale(1, 1)
        fl.ZIndex = f.ZIndex + 2; fl.Parent = f
        TweenService:Create(fl, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
        task.delay(0.5, function() fl:Destroy() end)
    elseif t.Open == "Burst" then
        -- (0.58) a soft flash + the theme's particle sprite bursting out from the middle + its emblem blooming
        local fl = Instance.new("Frame"); fl.BackgroundColor3 = col; fl.BackgroundTransparency = 0.55; fl.BorderSizePixel = 0
        fl.Size = UDim2.fromScale(1, 1); fl.ZIndex = f.ZIndex + 2; fl.Parent = f
        TweenService:Create(fl, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
        local amb = t.Ambient and AMBIENT[t.Ambient]
        local img = amb and Art[amb.Tex] or Art.Glow
        local bits = {}
        for i = 1, 14 do
            local a = (i / 14) * math.pi * 2 + math.random() * 0.3
            local sz = math.random(14, 26)
            local b = NewImage(f, { Image = img, ImageColor3 = (i % 2 == 0) and col or (t.Accent2 or t.Accent), Size = UDim2.fromOffset(sz, sz),
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Rotation = math.random(0, 359), ZIndex = f.ZIndex + 3 })
            local d = math.random(160, 300)
            TweenService:Create(b, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                { Position = UDim2.new(0.5, math.cos(a) * d, 0.45, math.sin(a) * d * 0.7), Rotation = b.Rotation + math.random(-160, 160), ImageTransparency = 1 }):Play()
            table.insert(bits, b)
        end
        local em = (t.Watermark and Art[t.Watermark]) or (t.Emblem and Art[t.Emblem])
        local bloom = em and NewImage(f, { Image = em, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
            Size = UDim2.fromOffset(120, 80), ImageTransparency = 0.2, ZIndex = f.ZIndex + 3 })
        if bloom then TweenService:Create(bloom, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(330, 220), ImageTransparency = 1 }):Play() end
        task.delay(0.8, function() fl:Destroy(); if bloom then bloom:Destroy() end; for _, b in ipairs(bits) do b:Destroy() end end)
    elseif t.Open == "Sweep" then
        local bar = Instance.new("Frame"); bar.BorderSizePixel = 0; bar.BackgroundColor3 = WHITE; bar.BackgroundTransparency = 0.2
        bar.Size = UDim2.new(0.25, 0, 2, 0); bar.AnchorPoint = Vector2.new(0.5, 0.5); bar.Position = UDim2.fromScale(-0.2, 0.5); bar.Rotation = 20
        bar.ZIndex = f.ZIndex + 2
        local g = Instance.new("UIGradient"); g.Color = RAINBOW
        g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }); g.Parent = bar
        bar.Parent = f
        TweenService:Create(bar, TweenInfo.new(0.55, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(1.2, 0.5) }):Play()
        task.delay(0.6, function() bar:Destroy() end)
    end
end

-- ===== styling one tagged object =====
local function Unstyle(inst)
    local rec = recs[inst]
    if rec then
        if rec.Deco then rec.Deco:Destroy() end
        if rec.StrokeGrad then rec.StrokeGrad:Destroy() end
        if rec.Emblem then rec.Emblem:Destroy() end
        for _, x in ipairs(rec.Extra or {}) do if typeof(x) == "Instance" then x:Destroy() end end
        if rec.VisConn then rec.VisConn:Disconnect() end
        if rec.BodyConn then rec.BodyConn:Disconnect() end
        for _, o in ipairs(rec.Touched or {}) do Restore(o) end
        recs[inst] = nil
    end
    Restore(inst)
end

local function Style(inst, kind, t)
    Unstyle(inst)
    if not t or not t.Panel or not inst.Parent then return end
    local rec = { Kind = kind, Touched = {} }
    recs[inst] = rec
    local function Touch(o) table.insert(rec.Touched, o) end
    local grad = Grad(inst)
    local stroke = BorderStroke(inst)
    if grad then Touch(grad) end
    if stroke then Touch(stroke) end
    local P = Palette(t)
    if kind == "Field" then
        -- (SKIN UI THEMES) the set's signature touches on a full-screen menu field (old themes leave the field alone)
        local sig = P and t.Clean.Sig
        if type(sig) ~= "function" then return end
        rec.Root = inst
        local f = Instance.new("Frame")
        f.Name = "UIT_Sig"; f.BackgroundTransparency = 1; f.BorderSizePixel = 0; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 0
        f.ClipsDescendants = true; f.Active = false
        f:SetAttribute("Skinned", true); f:SetAttribute("NoSkin", true); f:SetAttribute("UITKeep", true)
        f.Parent = inst
        rec.Deco = f
        local content = inst:FindFirstChild("InvContent")
        local top = inst:FindFirstChild("MenuTop") or (content and content:FindFirstChild("TopBar"))
        local marks, marksAt = {}, -99
        local function Marks()
            local now = os.clock()
            if now - marksAt > 1 and top then
                marksAt = now
                table.clear(marks)
                for _, d in ipairs(top:GetDescendants()) do if MARK_NAMES[d.Name] then table.insert(marks, d) end end
            end
            return marks
        end
        local function Keep(o) o:SetAttribute("UITKeep", true); return o end
        local ok, tick, extra = pcall(sig, { Frame = f, Field = inst, Top = top, P = P, Art = Art, Theme = t, Marks = Marks, Keep = Keep,
            Phone = UIStyle.IsPhone(), Tween = TweenService })
        if ok and type(tick) == "function" then rec.Tick = tick elseif not ok then warn("[UITheme] Sig: " .. tostring(tick)) end
        if ok and type(extra) == "table" then rec.Extra = extra end
        for _, d in ipairs(f:GetDescendants()) do d:SetAttribute("UITKeep", true) end
        for _, x in ipairs(rec.Extra or {}) do
            if typeof(x) == "Instance" then
                x:SetAttribute("UITKeep", true)
                for _, d in ipairs(x:GetDescendants()) do d:SetAttribute("UITKeep", true) end
            end
        end
        return
    end
    if P then
        -- (a Clean theme: the palette walk paints windows / cards / chips; HUD plates take its surface; no old art)
        if kind == "Hud" then Set(inst, "BackgroundColor3", P.Surface) end
        return
    end
    if kind == "Window" then
        if grad then Set(grad, "Color", Seq(t.Panel.Top, t.Panel.Bottom)) else Set(inst, "BackgroundColor3", t.Panel.Bottom) end
        StrokeFx(rec, stroke, t, t.BorderThick or 4)
        local glow = inst:FindFirstChild("AccentGlow")
        if glow then Touch(glow); Set(glow, "BackgroundColor3", t.Accent) end
        -- window root (for open effects): a UIStyle.Panel body sits inside its panel frame
        rec.Root = (inst.Name == "Body" and inst.Parent and inst.Parent:IsA("GuiObject")) and inst.Parent or inst
        rec.DecoZ = (inst.Name == "Body") and 1 or 0
        MakeDeco(rec, inst, t, kind)
        -- (SKIN UI THEMES: a full-screen menu's body is see-through on desktop -- the art drawn for its box floated mid-screen)
        if inst.Name == "Body" and rec.Root:GetAttribute("MenuField") then
            local function Follow()
                local on = inst.BackgroundTransparency < 0.99
                if rec.Deco then rec.Deco.Visible = on end
                for _, x in ipairs(rec.Extra or {}) do if typeof(x) == "Instance" and x:IsA("GuiObject") then x.Visible = on end end
            end
            Follow()
            rec.BodyConn = inst:GetPropertyChangedSignal("BackgroundTransparency"):Connect(Follow)
        end
        if (t.Open or t.OpenFn) and UITheme.OPEN_FX then
            rec.VisConn = rec.Root:GetPropertyChangedSignal("Visible"):Connect(function()
                if rec.Root.Visible and current == t then OpenFx(rec, t) end
            end)
        end
    elseif kind == "Title" then
        if grad then Set(grad, "Color", Seq(t.Title.Top, t.Title.Bottom)) else Set(inst, "BackgroundColor3", t.Title.Bottom) end
        if stroke then Set(stroke, "Color", Darken(t.Accent, 0.55)) end
        if t.Emblem and Art[t.Emblem] then
            local h = math.max(inst.AbsoluteSize.Y, 30)
            local hasClose = inst:FindFirstChild("Close") ~= nil
            -- (SKIN UI THEMES: Fit, never Stretch -- the emblem keeps its own aspect inside the box)
            rec.Emblem = NewImage(inst, { Name = "UIT_Emblem", Image = Art[t.Emblem], AnchorPoint = Vector2.new(1, 0.5), ScaleType = Enum.ScaleType.Fit,
                Position = UDim2.new(1, hasClose and -(h + 6) or -8, 0.5, 0), Size = UDim2.fromOffset(h * 1.9, h * 0.95), ImageTransparency = 0.12, ZIndex = 0 })
        end
        if type(t.TitleDeco) == "function" then
            local ok, made = pcall(t.TitleDeco, { Title = inst, Theme = t, UIStyle = UIStyle, Art = Art, Tween = TweenService })
            if ok and type(made) == "table" then rec.Extra = made elseif not ok then warn("[UITheme] TitleDeco: " .. tostring(made)) end
        end
        -- (a full-screen menu hides its window's own title on desktop -- the top bar has it: the emblem + title accent go with
        -- it instead of floating in an empty strip)
        local titleL = inst:FindFirstChild("Title")
        if titleL and titleL:IsA("GuiObject") then
            local function Follow()
                if rec.Emblem then rec.Emblem.Visible = titleL.Visible end
                for _, x in ipairs(rec.Extra or {}) do if typeof(x) == "Instance" and x:IsA("GuiObject") then x.Visible = titleL.Visible end end
            end
            Follow()
            rec.VisConn = titleL:GetPropertyChangedSignal("Visible"):Connect(Follow)
        end
        local title = inst:FindFirstChild("Title")
        if title and title:IsA("TextLabel") and t.Font and UIStyle.THEME_FONTS then
            Touch(title)
            Set(title, "FontFace", Font.new("rbxasset://fonts/families/" .. t.Font .. ".json", Enum.FontWeight.Bold))
        end
    elseif kind == "Card" or kind == "Chip" then
        if grad then Set(grad, "Color", Seq(t.Card.Top, t.Card.Bottom)) else Set(inst, "BackgroundColor3", t.Card.Bottom) end
        -- (a card outlined in its own accent colour keeps it; the plain dark border takes the theme's)
        if stroke and stroke.Color:ToHex() == UIStyle.Colors.Border:ToHex() then Set(stroke, "Color", Darken(t.Accent, 0.45)) end
        if kind == "Card" and t.Tex then MakeDeco(rec, inst, { Tex = t.Tex, TexT = math.min(0.95, (t.TexT or 0.8) + 0.08), TexTile = t.TexTile, TexScroll = t.TexScroll }, kind) end
    elseif kind == "Hud" then
        if grad then Set(grad, "Color", Seq(t.Panel.Top, t.Panel.Bottom)) end
        Set(inst, "BackgroundColor3", grad and WHITE or t.Panel.Bottom)
        StrokeFx(rec, stroke, t, (t.BorderThick or 3) - 1)
        rec.DecoZ = 0
        MakeDeco(rec, inst, t, kind)
    end
end

-- ===== the animation loop (one for everything) =====
local function Visible(g)
    local o = g
    while o and o:IsA("GuiObject") do
        if not o.Visible then return false end
        o = o.Parent
    end
    return true
end
local function AnimRec(rec, now, dt, t)
    if rec.Tick then
        local ok, err = pcall(rec.Tick, now, dt)
        if not ok then warn("[UITheme] tick: " .. tostring(err)); rec.Tick = nil end
    end
    if rec.StrokeGrad and rec.StrokeGrad.Parent then
        local g = rec.StrokeGrad
        if rec.Border == "Shimmer" then
            g.Offset = Vector2.new(((now * 0.35) % 2.4) - 1.2, 0)
        elseif rec.Border == "Pulse" then
            local k = 0.5 + 0.5 * math.sin(now * 3.2)
            rec.Stroke.Thickness = rec.BaseThick * (0.75 + 0.5 * k)
            g.Offset = Vector2.new(0, (k - 0.5) * 0.8)
        else
            g.Rotation = (now * (rec.Border == "Rainbow" and 70 or 55)) % 360
        end
    end
    for _, L in ipairs(rec.Layers or {}) do
        if L.Scroll then
            local x = (now * L.Scroll.X) % L.Tile
            local y = (now * L.Scroll.Y) % L.Tile
            L.Img.Position = UDim2.fromOffset(-L.Tile + x, -L.Tile + y)
        end
        if L.Pulse then L.Img.ImageTransparency = math.clamp(L.BaseT + 0.08 * math.sin(now * 2.2), 0, 1) end
    end
    if rec.Watermark then
        rec.Watermark.ImageTransparency = math.clamp(rec.WatermarkT + 0.03 * math.sin(now * 0.9), 0, 1)
    end
    if rec.Motes and rec.Deco then
        local abs = rec.Deco.AbsoluteSize
        if abs.X > 0 and abs.Y > 0 then
            for _, m in ipairs(rec.Motes) do
                local amb = m.Amb or rec.Amb
                m.X = (m.X + (amb.Vel.X * m.Sp * dt) / abs.X) % 1
                m.Y = (m.Y + (amb.Vel.Y * m.Sp * dt) / abs.Y) % 1
                local wob = math.sin(now * 1.3 + m.Ph) * amb.Wobble / abs.X
                m.Img.Position = UDim2.fromScale(m.X + wob, m.Y)
                local tw = amb.Twinkle and (0.5 + 0.5 * math.sin(now * 3 + m.Ph)) or 1
                if amb.Flicker then tw = (math.sin(now * 23 + m.Ph * 7) > 0.55) and 1 or 0.05 end
                local edge = math.min(m.Y, 1 - m.Y) * 6
                local tr = 1 - math.clamp(edge, 0, 1) * (0.25 + 0.6 * tw)
                if amb.Square then m.Img.BackgroundTransparency = tr else m.Img.ImageTransparency = tr end
                if amb.Rainbow then m.Img.ImageColor3 = Color3.fromHSV((now * 0.2 + m.Ph) % 1, 0.5, 1) end
                if amb.Spin then
                    m.Rot = (m.Rot or 0) + amb.Spin * m.Sp * dt * ((m.Ph > 3.14) and -1 or 1)
                    m.Img.Rotation = m.Rot
                end
                if amb.Flip or amb.Flap then -- (a coin turning over / a bat beating its wings: squash one axis)
                    local k = math.abs(math.cos(now * (amb.Flap and 9 or 3) + m.Ph))
                    m.Img.Size = amb.Flap and UDim2.fromOffset(m.Size, m.Size * (0.45 + 0.55 * k)) or UDim2.fromOffset(m.Size * (0.15 + 0.85 * k), m.Size)
                end
            end
        end
    end
end

local loopConn
local function EnsureLoop()
    if loopConn then return end
    local last = os.clock()
    local lastPrune = os.clock()
    loopConn = RunService.RenderStepped:Connect(function()
        local now = os.clock()
        local dt = math.min(now - last, 0.1)
        last = now
        if now - lastPrune > 5 then lastPrune = now; Prune(); PruneClean() end
        for inst, rec in pairs(recs) do
            if inst.Parent and (rec.StrokeGrad or rec.Layers or rec.Motes or rec.Watermark or rec.Tick) and Visible(inst) then AnimRec(rec, now, dt, current) end
        end
        for root, list in pairs(previews) do
            if root.Parent then
                for _, rec in ipairs(list) do AnimRec(rec, now, dt, rec.Theme) end
            else
                previews[root] = nil
            end
        end
    end)
end

-- ===== public =====
local hooked = false
local function Hook()
    if hooked then return end
    hooked = true
    for kind, tag in pairs(TAG) do
        CS:GetInstanceAddedSignal(tag):Connect(function(inst)
            -- (deferred: builders tag, then finish building / sizing the object)
            task.defer(function() if current and inst.Parent then Style(inst, kind, current) end end)
        end)
        CS:GetInstanceRemovedSignal(tag):Connect(function(inst) recs[inst] = nil end)
    end
end

-- the HUD bars (health / XP / level text) -- the client passes them once
function UITheme.SetBars(b) bars = b or {} end

function UITheme.Apply(t)
    Hook()
    if t and not t.Panel then t = nil end -- (Default)
    if current == t then return end
    current = t
    -- (SKIN UI THEMES) the clean palette first: everything styled / built after this paints with the theme's roles
    ApplyPalette(Palette(t))
    for kind, tag in pairs(TAG) do
        for _, inst in ipairs(CS:GetTagged(tag)) do
            if t then Style(inst, kind, t) else Unstyle(inst) end
        end
    end
    -- type: the theme's header / body / accent kit on every text in the game (UIStyle type system v2)
    UIStyle.SetTypeKit(t and t.Id or "Default")
    for _, f in ipairs(changedFns) do task.spawn(f, t) end
    -- HUD bars
    for k, inst in pairs(bars) do if inst then Restore(inst) end end
    if t then
        if bars.HpFill then Set(bars.HpFill, "BackgroundColor3", t.HpFill) end
        if bars.HpBg then Set(bars.HpBg, "BackgroundColor3", t.HpBg) end
        if bars.XpFill then Set(bars.XpFill, "BackgroundColor3", t.XpFill) end
        if bars.Lvl then Set(bars.Lvl, "TextColor3", t.Text) end
    end
    EnsureLoop()
end

function UITheme.Current() return current end
-- the accent colour of the equipped theme (default: nil -> callers keep their own colours)
function UITheme.Accent() return current and current.Accent or nil end
-- fn(theme or nil) after every theme change (dock icons etc.)
function UITheme.OnChanged(fn) table.insert(changedFns, fn) end

-- A miniature themed window for the store / locker cards: a window with a title bar (emblem + font), a card with a
-- health bar, all animated. Returns the root frame.
function UITheme.Preview(parent, t)
    local New = function(class, props, kids)
        local o = Instance.new(class)
        for k, v in pairs(props) do if k ~= "Parent" then o[k] = v end end
        for _, c in ipairs(kids or {}) do c.Parent = o end
        o.Parent = props.Parent
        return o
    end
    local corner = function(r) return New("UICorner", { CornerRadius = UDim.new(0, r) }) end
    local std = not (t and t.Panel)
    local panel = std and { Top = Color3.fromRGB(34, 40, 62), Bottom = Color3.fromRGB(18, 21, 34) } or t.Panel
    local title = std and { Top = Color3.fromRGB(80, 170, 255), Bottom = Color3.fromRGB(30, 100, 200) } or t.Title
    local card = std and { Top = Color3.fromRGB(42, 49, 74), Bottom = Color3.fromRGB(27, 32, 50) } or t.Card
    local accent = std and Color3.fromRGB(10, 12, 20) or t.Accent
    local root = New("Frame", { Name = "UITPreview", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0.86, 0),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = parent }, { corner(10) })
    root:SetAttribute("NoSkin", true)
    New("UIGradient", { Rotation = 90, Color = Seq(panel.Top, panel.Bottom), Parent = root })
    local st = New("UIStroke", { Thickness = 2.5, Color = accent, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = root })
    local list = {}
    local rec = { Theme = t, Touched = {}, DecoZ = 0, Root = root }
    if not std then
        StrokeFx(rec, st, t, 2.5)
        MakeDeco(rec, root, t, "Window")
        for _, m in ipairs(rec.Motes or {}) do
            m.Size = (m.Amb and m.Amb.Tex ~= "Glow") and math.max(6, math.floor(m.Size * 0.55)) or 4
            m.Img.Size = UDim2.fromOffset(m.Size, m.Size)
        end
        if rec.Watermark then rec.Watermark.Size = UDim2.fromScale(0.75, 0.75); rec.Watermark.Position = UDim2.fromScale(1.08, 1.06) end
    end
    table.insert(list, rec)
    local bar = New("Frame", { Name = "Bar", Position = UDim2.new(0, 6, 0, 6), Size = UDim2.new(1, -12, 0.3, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 3, Parent = root }, { corner(7) })
    New("UIGradient", { Rotation = 90, Color = Seq(title.Top, title.Bottom), Parent = bar })
    New("UIStroke", { Thickness = 1.5, Color = std and accent or Darken(t.Accent, 0.5), Parent = bar })
    local lbl = New("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.6, 0, 1, 0), Text = "COSMETICS", TextScaled = true,
        TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = bar,
        FontFace = (UIStyle.TypeKits[UIStyle.THEME_FONTS and t.Id or "Default"] or UIStyle.TypeKits.Default).Header })
    lbl:SetAttribute("KeepFont", true)
    New("UIStroke", { Thickness = 1.2, Color = Color3.new(0, 0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = lbl })
    if not std and t.Emblem and Art[t.Emblem] then
        NewImage(bar, { Image = Art[t.Emblem], AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.new(0.42, 0, 1.1, 0), ZIndex = 4,
            ScaleType = Enum.ScaleType.Fit })
    end
    local c = New("Frame", { Name = "Card", Position = UDim2.new(0, 6, 0.42, 0), Size = UDim2.new(1, -12, 0.5, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 3, Parent = root }, { corner(6) })
    New("UIGradient", { Rotation = 90, Color = Seq(card.Top, card.Bottom), Parent = c })
    local hpBg = New("Frame", { Position = UDim2.new(0.06, 0, 0.55, 0), Size = UDim2.new(0.88, 0, 0.3, 0), BorderSizePixel = 0, ZIndex = 4,
        BackgroundColor3 = std and Color3.fromRGB(30, 12, 12) or t.HpBg, Parent = c }, { corner(4) })
    New("Frame", { Size = UDim2.fromScale(0.72, 1), BorderSizePixel = 0, ZIndex = 5, BackgroundColor3 = std and Color3.fromRGB(235, 45, 45) or t.HpFill, Parent = hpBg }, { corner(4) })
    local xpBg = New("Frame", { Position = UDim2.new(0.06, 0, 0.2, 0), Size = UDim2.new(0.88, 0, 0.14, 0), BorderSizePixel = 0, ZIndex = 4,
        BackgroundColor3 = Color3.fromRGB(10, 12, 18), Parent = c }, { corner(3) })
    New("Frame", { Size = UDim2.fromScale(0.45, 1), BorderSizePixel = 0, ZIndex = 5, BackgroundColor3 = std and Color3.fromRGB(0, 220, 255) or t.XpFill, Parent = xpBg }, { corner(3) })
    previews[root] = list
    EnsureLoop()
    return root
end
-- (v3) replay a preview's own open motion (the store showcase loop); false when the theme has none of its own
function UITheme.PreviewOpen(root): boolean
    local list = previews[root]
    local rec = list and list[1]
    local t = rec and rec.Theme
    if not (UITheme.OPEN_FX and t and type(t.OpenFn) == "function" and rec.Deco) then return false end
    OpenFx(rec, t)
    return true
end

return UITheme
