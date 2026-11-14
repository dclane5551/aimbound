--!nocheck
-- HUD THEMES, builder A half (SKIN UI roll-out 2026-10-29): the Clean tables (palette roles + TabMark + Sig) of the store
-- themes Midnight, Emerald, Crimson, Ocean, Sunset, Royal, Frost (Glacier), GoldRush, Seraphim and Prismatic, keyed by theme
-- Id. HudThemes sets t.Clean from this table after its List is built. Requires nothing (UITheme passes the palette + ctx).
local C = Color3.fromRGB
-- ===== CLEAN STORE THEMES, builder A half (SKIN UI THEMES roll-out 2026-10-29, owner: themes must "change up the colorways
-- and provide a bit more style than the default", no stretched header art): the 8 drop recolours + Seraphim + Prismatic wear
-- the UI CLEAN language in their own colours (UITheme Clean: roles below, contrast lifted by code) + one tab mark and one quiet
-- field touch each, made for that theme (UITheme header: Clean.TabMark(mark, P) adds offset children / gradients / strokes
-- inside the mark's width; Clean.Sig(ctx) builds into ctx.Frame under the content and returns ONE tick for the one loop).
-- Hooks read only the palette they are given (P / ctx.P). The old art (ambient particles, corners, emblems) is not drawn.
local W1 = Color3.new(1, 1, 1)
local function HtDot(parent, d, col, tr, z)
    local f = Instance.new("Frame")
    f.BorderSizePixel = 0; f.BackgroundColor3 = col; f.BackgroundTransparency = tr or 0; f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Size = UDim2.fromOffset(d, d); f.ZIndex = z or 0
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = f
    f.Parent = parent
    return f
end
local function HtBar(parent, x, y, w, h, col, tr, rot)
    local f = Instance.new("Frame")
    f.BorderSizePixel = 0; f.BackgroundColor3 = col; f.BackgroundTransparency = tr or 0; f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.fromOffset(x, y); f.Size = UDim2.fromOffset(w, h); f.Rotation = rot or 0; f.ZIndex = 0
    f.Parent = parent
    return f
end
local function HtTopY(ctx)
    local f, top = ctx.Frame, ctx.Top
    if top then return top.AbsolutePosition.Y - f.AbsolutePosition.Y + top.AbsoluteSize.Y end
    return 66
end
-- a white band that slides across a mark's own colour (a gradient can only darken it, so the band is the mark's colour)
local function HtSheenMark(mark, name, edge)
    local g = Instance.new("UIGradient")
    g.Name = name
    g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, edge), ColorSequenceKeypoint.new(0.42, edge), ColorSequenceKeypoint.new(0.5, W1),
        ColorSequenceKeypoint.new(0.58, edge), ColorSequenceKeypoint.new(1, edge) })
    g.Offset = Vector2.new(-1, 0)
    g.Parent = mark
    return g
end
local function HtSlideMarks(ctx, name, now, period, dur, seed)
    local k = ((now + (seed or 0)) % period) / dur
    local x = (k < 1) and (-0.6 + 1.2 * k) or -1
    for _, m in ipairs(ctx.Marks()) do
        local g = m.Visible and m:FindFirstChild(name)
        if g then g.Offset = Vector2.new(x, 0) end
    end
end
local A_CLEAN = {}

-- MIDNIGHT: navy night glass, a silver primary; tab mark = silver with a moonlight gleam sliding over it; field = a crescent
-- moon low on the right and a few stars round it that twinkle in turn
A_CLEAN.Midnight = {
    Field = C(6, 8, 18), Surface = C(12, 15, 30), Raised = C(22, 28, 52), Hover = C(34, 42, 74), Well = C(4, 5, 12), Line = C(46, 56, 92),
    Accent = C(196, 206, 230), Mark = C(205, 215, 240), Hair = C(150, 165, 205), Text = C(228, 234, 255), Sub = C(165, 176, 212), Muted = C(134, 145, 184),
    Ink = C(8, 10, 22), Moon = C(214, 222, 244), Star = C(200, 214, 255),
    TabMark = function(mark, Q) return { HtSheenMark(mark, "HtGleam", C(150, 160, 190)) } end,
    Sig = function(ctx)
        local Q, f = ctx.P, ctx.Frame
        local moon = HtDot(f, 46, Q.Moon, 0.25)
        moon.AnchorPoint = Vector2.new(1, 1); moon.Position = UDim2.new(1, -46, 1, -70)
        local cut = HtDot(moon, 42, Q.Field, 0, 1) -- (the shadow that carves the crescent: the field colour)
        cut.Position = UDim2.new(0.5, -12, 0.5, -6)
        local stars = {}
        for i, s in ipairs({ { -130, -150, 3 }, { -96, -196, 2 }, { -168, -110, 2 }, { -60, -170, 3 }, { -210, -160, 2 }, { -36, -132, 2 }, { -150, -64, 2 } }) do
            local d = HtDot(f, s[3], Q.Star, 0.4)
            d.Position = UDim2.new(1, s[1], 1, s[2])
            stars[i] = { F = d, Ph = i * 1.37 }
        end
        return function(now, _dt)
            for _, s in ipairs(stars) do s.F.BackgroundTransparency = 0.25 + 0.6 * (0.5 + 0.5 * math.sin(now * 1.3 + s.Ph * 2.1)) end
            HtSlideMarks(ctx, "HtGleam", now, 6, 0.9)
        end, nil
    end,
}
-- EMERALD: jungle-dark glass, emerald primary; tab mark = the bar with a small leaf on its left end; field = a vine let down
-- the left margin from under the top bar, its leaves swaying in turn
A_CLEAN.Emerald = {
    Field = C(4, 12, 9), Surface = C(9, 24, 18), Raised = C(16, 40, 30), Hover = C(26, 58, 44), Well = C(3, 9, 6), Line = C(34, 74, 54),
    Accent = C(60, 220, 140), Mark = C(60, 220, 140), Hair = C(110, 190, 150), Text = C(218, 255, 234), Sub = C(150, 210, 180), Muted = C(120, 175, 148),
    Ink = C(4, 16, 10), Leaf = C(70, 200, 120), Vine = C(60, 130, 90),
    TabMark = function(mark, Q)
        local l = Instance.new("Frame")
        l.Name = "HtLeaf"; l.BorderSizePixel = 0; l.BackgroundColor3 = Q.Leaf; l.Rotation = 45; l.Size = UDim2.fromOffset(6, 6)
        l.Position = UDim2.fromOffset(0, -6); l.ZIndex = mark.ZIndex
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 3); c.Parent = l
        l.Parent = mark
        return { l }
    end,
    Sig = function(ctx)
        local Q, f = ctx.P, ctx.Frame
        local vine = HtBar(f, 7, 0, 2, 10, Q.Vine, 0.25)
        local leaves = {}
        for i = 1, 16 do
            local side = (i % 2 == 0) and 1 or -1
            local l = Instance.new("Frame")
            l.BorderSizePixel = 0; l.BackgroundColor3 = Q.Leaf; l.BackgroundTransparency = 0.2; l.AnchorPoint = Vector2.new(0.5, 0.5)
            l.Size = UDim2.fromOffset(10, 5); l.ZIndex = 0; l.Visible = false
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = l
            l.Parent = f
            leaves[i] = { F = l, Side = side, Base = side * 35, Ph = i * 0.7 }
        end
        local lastH, lastTop = -1, -1
        return function(now, _dt)
            -- (laid out again only when the field / top bar change size: at build time the top bar has no size yet)
            local h, y0 = f.AbsoluteSize.Y, HtTopY(ctx)
            if h ~= lastH or y0 ~= lastTop then
                lastH, lastTop = h, y0
                local len = math.clamp(h - y0 - 40, 120, 740)
                vine.Position = UDim2.fromOffset(7, y0 + len / 2); vine.Size = UDim2.fromOffset(2, len)
                for i, l in ipairs(leaves) do
                    local y = i * 46 - 20
                    l.F.Visible = y < len
                    l.F.Position = UDim2.fromOffset(7 + l.Side * 5, y0 + y)
                end
            end
            for _, l in ipairs(leaves) do l.F.Rotation = l.Base + 10 * math.sin(now * 1.1 + l.Ph) end
        end, nil
    end,
}
-- CRIMSON: blood-red glass with black-steel edges, crimson primary; tab mark = a blade: steel to a bright edge with a glint
-- that runs along it; field = a longsword laid across the lower right (tapering blade with a fuller, crossguard, grip, pommel
-- in black steel), a glint running down the blade now and then (two crossed lines read as an X -- replaced)
A_CLEAN.Crimson = {
    Field = C(12, 3, 6), Surface = C(24, 6, 10), Raised = C(44, 12, 18), Hover = C(66, 20, 28), Well = C(8, 2, 4), Line = C(84, 30, 38),
    Accent = C(230, 60, 72), Mark = C(255, 120, 128), Hair = C(150, 150, 160), Text = C(255, 228, 230), Sub = C(212, 165, 170), Muted = C(178, 134, 140),
    Ink = C(14, 2, 4), Steel = C(60, 56, 64), Blade = C(176, 176, 190), Grip = C(110, 30, 40),
    TabMark = function(mark, Q) return { HtSheenMark(mark, "HtEdge", C(170, 120, 125)) } end,
    Sig = function(ctx)
        local Q, f = ctx.P, ctx.Frame
        local sword = Instance.new("Frame")
        sword.Name = "HtSword"; sword.BackgroundTransparency = 1; sword.AnchorPoint = Vector2.new(0.5, 0.5); sword.Size = UDim2.fromOffset(300, 30)
        sword.Position = UDim2.new(1, -190, 1, -120); sword.Rotation = -28; sword.ZIndex = 0; sword.Parent = f
        -- (laid out along the sword's own length: pommel at x 0, tip at x 300)
        local blade = HtBar(sword, 52 + 124, 15, 248, 7, Q.Blade, 0.5)
        local bg = Instance.new("UIGradient")
        bg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.2) })
        bg.Parent = blade
        local tip = HtBar(sword, 299, 15, 5, 5, Q.Blade, 0.55, 45) -- (the point)
        HtBar(sword, 52 + 110, 15, 210, 1, W1, 0.6) -- (the fuller)
        HtBar(sword, 50, 15, 5, 34, Q.Steel, 0.2) -- (crossguard)
        HtBar(sword, 28, 15, 40, 6, Q.Grip, 0.3) -- (grip)
        local pom = HtDot(sword, 11, Q.Steel, 0.2); pom.Position = UDim2.fromOffset(6, 15)
        local glint = HtBar(blade, 0, 3, 30, 7, W1, 1)
        local gg = Instance.new("UIGradient")
        gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 1) })
        gg.Parent = glint
        blade.ClipsDescendants = true
        return function(now, _dt)
            local k = (now % 7) / 0.8
            glint.Visible = k < 1
            if k < 1 then glint.BackgroundTransparency = 0; glint.Position = UDim2.new(k, 0, 0.5, 0) end
            HtSlideMarks(ctx, "HtEdge", now, 5, 0.6)
        end, nil
    end,
}
-- ABYSSAL OCEAN: deep-sea teal, turquoise primary; tab mark = a ripple that runs along the bar; field = bubbles rising up the
-- right side, wobbling, popping near the top of their rise
A_CLEAN.Ocean = {
    Field = C(2, 10, 15), Surface = C(4, 20, 28), Raised = C(8, 40, 52), Hover = C(14, 58, 74), Well = C(1, 7, 11), Line = C(20, 74, 90),
    Accent = C(70, 230, 230), Mark = C(90, 235, 235), Hair = C(110, 200, 210), Text = C(215, 252, 255), Sub = C(150, 215, 222), Muted = C(115, 180, 190),
    Ink = C(2, 14, 20), Bubble = C(150, 240, 255),
    TabMark = function(mark, Q)
        local g = Instance.new("UIGradient")
        g.Name = "HtRipple"
        g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.55), NumberSequenceKeypoint.new(0.4, 0),
            NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 0.55) })
        g.Parent = mark
        return { g }
    end,
    Sig = function(ctx)
        local Q, f = ctx.P, ctx.Frame
        local bubbles = {}
        for i = 1, 9 do
            local d = 4 + (i * 7) % 9
            local b = Instance.new("Frame")
            b.BackgroundTransparency = 1; b.AnchorPoint = Vector2.new(0.5, 0.5); b.Size = UDim2.fromOffset(d, d); b.ZIndex = 0
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = b
            local st = Instance.new("UIStroke"); st.Color = Q.Bubble; st.Thickness = 1; st.Transparency = 0.4; st.Parent = b
            b.Parent = f
            bubbles[i] = { F = b, S = st, X = 30 + (i * 37) % 120, Sp = 26 + (i * 13) % 30, Ph = i * 0.83 }
        end
        return function(now, _dt)
            local sz = f.AbsoluteSize
            for _, b in ipairs(bubbles) do
                local rise = (now * b.Sp + b.Ph * 140) % (sz.Y * 0.62)
                local q = rise / (sz.Y * 0.62)
                b.F.Position = UDim2.fromOffset(sz.X - b.X + math.sin(now * 2 + b.Ph) * 5, sz.Y - 12 - rise)
                b.S.Transparency = 0.35 + 0.6 * q
            end
            for _, m in ipairs(ctx.Marks()) do
                local g = m.Visible and m:FindFirstChild("HtRipple")
                if g then g.Offset = Vector2.new((now * 0.25) % 0.4 - 0.2, 0) end
            end
        end, nil
    end,
}
-- SUNSET: dusk plum glass, sunset-orange primary; tab mark = the bar burning orange into violet; field = a small low sun setting
-- in the lower-right corner, cut by horizon bands, dim behind the content (a quiet horizon, not a poster), slowly breathing
A_CLEAN.Sunset = {
    Field = C(16, 7, 20), Surface = C(30, 13, 30), Raised = C(56, 24, 40), Hover = C(80, 36, 52), Well = C(10, 4, 14), Line = C(100, 46, 66),
    Accent = C(255, 160, 80), Mark = C(255, 200, 150), Hair = C(220, 140, 150), Text = C(255, 234, 214), Sub = C(230, 182, 172), Muted = C(196, 148, 152),
    Ink = C(20, 8, 16), SunTop = C(255, 190, 100), SunLow = C(230, 80, 140), Dusk = C(140, 60, 160),
    TabMark = function(mark, Q)
        local g = Instance.new("UIGradient")
        g.Name = "HtDusk"
        g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Q.SunTop), ColorSequenceKeypoint.new(0.55, Q.SunLow), ColorSequenceKeypoint.new(1, Q.Dusk) })
        g.Parent = mark
        return { g }
    end,
    Sig = function(ctx)
        local Q, f = ctx.P, ctx.Frame
        local cam = workspace.CurrentCamera
        local D = math.clamp(math.floor((cam and cam.ViewportSize.Y or 800) * 0.2), 100, 190)
        local sun = HtDot(f, D, W1, 0.72)
        sun.AnchorPoint = Vector2.new(0.5, 0.5); sun.Position = UDim2.new(1, -math.floor(D * 0.5) - 30, 1, math.floor(D * 0.04))
        local g = Instance.new("UIGradient"); g.Rotation = 90
        g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Q.SunTop), ColorSequenceKeypoint.new(0.45, Q.SunLow), ColorSequenceKeypoint.new(1, Q.Dusk) })
        g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.25), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) })
        g.Parent = sun
        for i = 1, 4 do -- (horizon bands cut across the lower half, thicker toward the horizon)
            local b = Instance.new("Frame")
            b.BorderSizePixel = 0; b.BackgroundColor3 = Q.Field; b.AnchorPoint = Vector2.new(0.5, 0.5); b.ZIndex = 1
            b.Position = UDim2.new(0.5, 0, 0.2 + i * 0.065, 0); b.Size = UDim2.new(1.1, 0, 0, 1 + math.floor(i / 2)); b.Parent = sun
        end
        return function(now, _dt) sun.BackgroundTransparency = 0.72 + 0.05 * math.sin(now * 0.6) end, nil
    end,
}
-- ROYAL AMETHYST: amethyst glass with a gold edge, gold primary; tab mark = the gold bar with a small cut gem set over its
-- middle; field = gold filigree brackets in the four corners of the screen, their gems glinting in turn
A_CLEAN.Royal = {
    Field = C(10, 4, 20), Surface = C(20, 9, 36), Raised = C(40, 18, 62), Hover = C(58, 28, 86), Well = C(7, 3, 14), Line = C(78, 44, 110),
    Accent = C(255, 205, 100), Mark = C(255, 210, 110), Hair = C(200, 170, 120), Text = C(244, 232, 255), Sub = C(200, 182, 226), Muted = C(168, 152, 196),
    Ink = C(14, 6, 24), Gold = C(230, 185, 90), Gem = C(190, 110, 255),
    TabMark = function(mark, Q)
        local gem = Instance.new("Frame")
        gem.Name = "HtGem"; gem.BorderSizePixel = 0; gem.BackgroundColor3 = Q.Gem; gem.Rotation = 45; gem.Size = UDim2.fromOffset(5, 5)
        gem.Position = UDim2.new(0.5, -3, 0, -2); gem.ZIndex = mark.ZIndex + 1
        local st = Instance.new("UIStroke"); st.Color = Q.Gold; st.Thickness = 1; st.Parent = gem
        gem.Parent = mark
        return { gem }
    end,
    Sig = function(ctx)
        local Q, f = ctx.P, ctx.Frame
        local gems, tops = {}, {}
        local function Bracket(ax, ay, sx, sy)
            local holder = Instance.new("Frame")
            holder.BackgroundTransparency = 1; holder.AnchorPoint = Vector2.new(ax, ay); holder.Size = UDim2.fromOffset(60, 60); holder.ZIndex = 0
            holder.Position = UDim2.new(ax, (ax == 0) and 12 or -12, ay, (ay == 0) and 76 or -12); holder.Parent = f
            if ay == 0 then table.insert(tops, holder) end
            local ox, oy = (ax == 0) and 0 or 60, (ay == 0) and 0 or 60
            for k, L in ipairs({ { 56, 0 }, { 34, 6 } }) do
                local tr = (k == 1) and 0.35 or 0.6
                local h = HtBar(holder, ox + sx * (L[2] + L[1] / 2), oy + sy * L[2], L[1], 1, Q.Gold, tr)
                local v = HtBar(holder, ox + sx * L[2], oy + sy * (L[2] + L[1] / 2), 1, L[1], Q.Gold, tr)
            end
            local g = HtBar(holder, ox + sx * 3, oy + sy * 3, 6, 6, Q.Gem, 0.2, 45)
            table.insert(gems, g)
        end
        Bracket(0, 0, 1, 1); Bracket(1, 0, -1, 1); Bracket(0, 1, 1, -1); Bracket(1, 1, -1, -1)
        local lastTop = -1
        return function(now, _dt)
            local y0 = HtTopY(ctx) + 10
            if y0 ~= lastTop then
                lastTop = y0
                for _, h in ipairs(tops) do h.Position = UDim2.new(h.Position.X.Scale, h.Position.X.Offset, 0, y0) end
            end
            for i, g in ipairs(gems) do
                local k = math.max(0, math.sin(now * 0.9 - i * 1.4)) ^ 6
                g.BackgroundColor3 = Q.Gem:Lerp(W1, 0.6 * k)
            end
        end, nil
    end,
}
-- GLACIER: pale ice-blue glass, ice primary; tab mark = the bar with a cold light sliding over the ice; field = slow snowfall
-- over the whole screen (a few flakes, drifting)
A_CLEAN.Frost = {
    Field = C(8, 16, 28), Surface = C(16, 28, 44), Raised = C(34, 54, 76), Hover = C(48, 72, 98), Well = C(5, 11, 20), Line = C(62, 92, 120),
    Accent = C(196, 234, 255), Mark = C(220, 245, 255), Hair = C(160, 200, 230), Text = C(234, 248, 255), Sub = C(178, 206, 228), Muted = C(142, 174, 200),
    Ink = C(8, 18, 30), Flake = C(235, 248, 255),
    TabMark = function(mark, Q) return { HtSheenMark(mark, "HtIce", C(150, 190, 215)) } end,
    Sig = function(ctx)
        local Q, f = ctx.P, ctx.Frame
        local flakes = {}
        for i = 1, 16 do
            local d = 2 + (i % 3)
            flakes[i] = { F = HtDot(f, d, Q.Flake, 0.35 + 0.1 * (i % 3)), X = ((i * 0.618) % 1), Sp = 14 + (i * 7) % 16, Ph = i * 1.9 }
        end
        return function(now, _dt)
            local sz = f.AbsoluteSize
            for _, fl in ipairs(flakes) do
                local y = (now * fl.Sp + fl.Ph * 90) % (sz.Y + 20)
                fl.F.Position = UDim2.fromOffset(fl.X * sz.X + math.sin(now * 0.7 + fl.Ph) * 18, y - 10)
            end
            HtSlideMarks(ctx, "HtIce", now, 5.5, 0.9)
        end, nil
    end,
}
-- GOLD RUSH: black glass and gold, gold primary; tab mark = gold with a shine sweeping across; field = a gilded edge under the
-- top bar that a shine runs along, and three stacks of gold coins in the lower right
A_CLEAN.GoldRush = {
    Field = C(8, 7, 4), Surface = C(16, 14, 9), Raised = C(30, 26, 18), Hover = C(44, 38, 26), Well = C(5, 4, 2), Line = C(64, 54, 32),
    Accent = C(255, 200, 80), Mark = C(255, 210, 100), Hair = C(190, 160, 90), Text = C(255, 238, 200), Sub = C(215, 196, 152), Muted = C(180, 162, 122),
    Ink = C(12, 10, 4), Gold = C(240, 190, 70), GoldDeep = C(150, 105, 30),
    TabMark = function(mark, Q) return { HtSheenMark(mark, "HtShine", C(200, 150, 60)) } end,
    Sig = function(ctx)
        local Q, f = ctx.P, ctx.Frame
        local made = {}
        local top = ctx.Top
        local shine
        if top then
            local edge = Instance.new("Frame")
            edge.Name = "HtGilt"; edge.BorderSizePixel = 0; edge.BackgroundColor3 = Q.Gold; edge.BackgroundTransparency = 0.45
            edge.Position = UDim2.new(0, 0, 1, 0); edge.Size = UDim2.new(1, 0, 0, 2); edge.ZIndex = 0; edge.ClipsDescendants = true
            shine = Instance.new("Frame")
            shine.BorderSizePixel = 0; shine.BackgroundColor3 = W1; shine.AnchorPoint = Vector2.new(0.5, 0); shine.Size = UDim2.new(0, 90, 1, 0); shine.ZIndex = 1
            local sg = Instance.new("UIGradient")
            sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1) })
            sg.Parent = shine
            shine.Parent = edge
            edge.Parent = top
            table.insert(made, edge)
        end
        for s, n in ipairs({ 4, 6, 3 }) do -- (three coin stacks, each coin a gold disc seen edge-on with a darker rim)
            for c = 1, n do
                local coin = HtBar(f, 0, 0, 24, 7, Q.Gold, 0.15)
                coin.Position = UDim2.new(1, -150 + s * 30, 1, -24 - c * 5)
                local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(1, 0); cr.Parent = coin
                local st = Instance.new("UIStroke"); st.Color = Q.GoldDeep; st.Thickness = 1; st.Parent = coin
            end
        end
        return function(now, _dt)
            if shine then
                local k = (now % 4.5) / 1.2
                shine.Visible = k < 1
                if k < 1 then shine.Position = UDim2.new(-0.05 + 1.1 * k, 0, 0, 0) end
            end
            HtSlideMarks(ctx, "HtShine", now, 4.5, 0.7, 0.4)
        end, made
    end,
}
-- SERAPHIM ASCENDANT: warm pearl glass and living gold, gold primary; tab mark = the gold bar with a small halo floating over
-- it that breathes; field = a pair of wings, one per lower corner, mirrored (arched leading edge, coverts, tapering primaries),
-- in the band above the corner's bottom row and under the column text; hidden on phones; gold motes rising
A_CLEAN.Seraphim = {
    Field = C(14, 12, 9), Surface = C(26, 23, 18), Raised = C(48, 43, 36), Hover = C(66, 59, 48), Well = C(9, 8, 6), Line = C(90, 78, 58),
    Accent = C(255, 214, 120), Mark = C(255, 226, 150), Hair = C(230, 210, 170), Text = C(255, 246, 225), Sub = C(226, 208, 176), Muted = C(190, 176, 146),
    Ink = C(30, 22, 10), Halo = C(255, 226, 150), Feather = C(255, 244, 220), Mote = C(255, 220, 140),
    TabMark = function(mark, Q)
        local h = Instance.new("Frame")
        h.Name = "HtHalo"; h.BackgroundTransparency = 1; h.Size = UDim2.fromOffset(14, 5); h.Position = UDim2.new(0.5, -7, 0, -9); h.ZIndex = mark.ZIndex
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = h
        local st = Instance.new("UIStroke"); st.Color = Q.Halo; st.Thickness = 1.5; st.Parent = h
        h.Parent = mark
        return { h }
    end,
    Sig = function(ctx)
        local Q, f = ctx.P, ctx.Frame
        -- one wing per lower corner, mirrored, in the band ABOVE the corner's bottom row (the ALL STATS button / the bag's foot) and
        -- below the column text (a strip under the content was too thin to read as a wing): an arched LEADING EDGE from the shoulder
        -- (inner bottom) up and out to the wingtip, COVERTS layered over its root, and PRIMARY feathers hanging from it that taper to
        -- points, longest toward the tip, their tips forming the scalloped trailing edge. Drawn in a W x H box; the right one mirrors.
        local wings = {}
        local function Piece(box, x, y, len, wid, rot, tr, taper)
            local fe = Instance.new("Frame")
            fe.BorderSizePixel = 0; fe.BackgroundColor3 = Q.Feather; fe.BackgroundTransparency = tr; fe.AnchorPoint = Vector2.new(0.5, 0.5)
            fe.Position = UDim2.fromOffset(x, y); fe.Size = UDim2.fromOffset(len, wid); fe.Rotation = rot; fe.ZIndex = 0
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = fe
            if taper then -- (opaque at the root, fading to a point at the tip: a piece's own +X runs root -> tip, mirrored or not)
                local g = Instance.new("UIGradient")
                g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.1), NumberSequenceKeypoint.new(1, 0.95) })
                g.Rotation = taper
                g.Parent = fe
            end
            fe.Parent = box
            return fe
        end
        local function Bez(u, W, H) -- (the arm: shoulder (inner bottom) -> wingtip (outer top), arched)
            local sx, sy, cx, cy, tx, ty = W * 0.9, H * 0.78, W * 0.52, -H * 0.05, W * 0.14, H * 0.14
            local a, b2 = (1 - u) ^ 2, 2 * (1 - u) * u
            return a * sx + b2 * cx + u * u * tx, a * sy + b2 * cy + u * u * ty
        end
        local function Build(side, W, H, lift)
            local box = Instance.new("Frame")
            box.Name = "HtWing"; box.BackgroundTransparency = 1; box.ZIndex = 0
            box.AnchorPoint = Vector2.new((side == 1) and 0 or 1, 1); box.Position = UDim2.new((side == 1) and 0 or 1, side * 6, 1, -lift)
            box.Size = UDim2.fromOffset(W, H); box.Parent = f
            local function X(x) return (side == 1) and x or (W - x) end -- (mirror)
            local function R(deg) return (side == 1) and deg or (180 - deg) end
            -- primaries first (under), from the arm, pointing down and out
            local n = 13
            for i = 1, n do
                local u = 0.1 + 0.9 * (i - 1) / (n - 1)
                local rx, ry = Bez(u, W, H)
                local ang = 96 + 52 * u -- (screen degrees: 90 = straight down, 180 = out to the side)
                local tipY = H * (0.98 - 0.42 * u)
                local len = math.max(14, (tipY - ry) / math.max(0.25, math.sin(math.rad(ang))) + 6 * u)
                local cx, cy = rx + math.cos(math.rad(ang)) * len / 2, ry + math.sin(math.rad(ang)) * len / 2
                Piece(box, X(cx), cy, len, math.floor(12 - 3 * u), R(ang), 0.66, 0)
            end
            -- coverts: short, broad, over the roots
            for i = 1, 6 do
                local u = 0.08 + 0.8 * (i - 1) / 5
                local rx, ry = Bez(u, W, H)
                local ang = 100 + 40 * u
                local len = H * 0.26
                Piece(box, X(rx + math.cos(math.rad(ang)) * len / 2), ry + math.sin(math.rad(ang)) * len / 2, len, 10, R(ang), 0.55, 0)
            end
            -- the arm on top: four segments along the arch, thick at the shoulder
            for k = 0, 3 do
                local x0, y0 = Bez(k / 4, W, H)
                local x1, y1 = Bez((k + 1) / 4, W, H)
                local len = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2) + 4
                Piece(box, X((x0 + x1) / 2), (y0 + y1) / 2, len, 5 - k, R(math.deg(math.atan2(y1 - y0, x1 - x0))), 0.5)
            end
            return box
        end
        local lastW, lastH = -1, -1
        local function Layout()
            for _, w in ipairs(wings) do w:Destroy() end
            table.clear(wings)
            local sz = f.AbsoluteSize
            if ctx.Phone or sz.Y < 520 then return end -- (phones run their content to the bottom edge: no free band)
            -- (the band: above the bottom row -- ALL STATS / the bag foot end ~20 px over the bottom, ~34 px tall -- under the text)
            local lift = math.floor(sz.Y * 0.075)
            local W, H = math.clamp(math.floor(sz.X * 0.12), 130, 210), math.clamp(math.floor(sz.Y * 0.11), 70, 96)
            table.insert(wings, Build(1, W, H, lift)); table.insert(wings, Build(-1, W, H, lift))
        end
        local motes = {}
        for i = 1, 6 do motes[i] = { F = HtDot(f, 3, Q.Mote, 0.3), X = 0.15 + 0.7 * ((i * 0.618) % 1), Sp = 10 + i * 2, Ph = i * 2.3 } end
        return function(now, _dt)
            local sz = f.AbsoluteSize
            if sz.X ~= lastW or sz.Y ~= lastH then lastW, lastH = sz.X, sz.Y; Layout() end
            for _, m in ipairs(motes) do
                local y = (now * m.Sp + m.Ph * 60) % (sz.Y * 0.45)
                m.F.Position = UDim2.fromOffset(m.X * sz.X + math.sin(now * 0.9 + m.Ph) * 10, sz.Y - 20 - y)
                m.F.BackgroundTransparency = 0.25 + 0.7 * (y / (sz.Y * 0.45))
            end
            local b = 0.5 + 0.5 * math.sin(now * 1.4)
            for _, mk in ipairs(ctx.Marks()) do
                local h = mk.Visible and mk:FindFirstChild("HtHalo")
                local st = h and h:FindFirstChildOfClass("UIStroke")
                if st then st.Transparency = 0.1 + 0.45 * b end
            end
        end, nil
    end,
}
-- PRISMATIC: holographic dark glass, a pale primary; tab mark = a rainbow bar whose colours slide; field = a cut crystal low on
-- the right: a white beam comes in from the left and fans out the other side into a spectrum that slowly cycles
A_CLEAN.Prismatic = {
    Field = C(7, 7, 12), Surface = C(14, 14, 22), Raised = C(26, 26, 38), Hover = C(38, 38, 54), Well = C(5, 5, 9), Line = C(56, 56, 78),
    Accent = C(236, 236, 255), Mark = C(255, 255, 255), Hair = C(170, 170, 200), Text = C(242, 242, 255), Sub = C(182, 182, 206), Muted = C(150, 150, 176),
    Ink = C(10, 10, 18), Prism = C(220, 225, 255),
    TabMark = function(mark, Q)
        local g = Instance.new("UIGradient")
        g.Name = "HtSpectrum"
        local ks = {}
        for i = 0, 6 do ks[#ks + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.55, 1)) end
        g.Color = ColorSequence.new(ks)
        g.Parent = mark
        return { g }
    end,
    Sig = function(ctx)
        local Q, f = ctx.P, ctx.Frame
        local hub = Instance.new("Frame") -- (everything hangs off one point low on the right, so it follows the field's size)
        hub.BackgroundTransparency = 1; hub.Size = UDim2.fromOffset(2, 2); hub.AnchorPoint = Vector2.new(0.5, 0.5); hub.ZIndex = 0
        hub.Position = UDim2.new(1, -250, 1, -96); hub.Parent = f
        local prism = HtBar(hub, 1, 1, 26, 26, Q.Prism, 0.85, 45)
        local ps = Instance.new("UIStroke"); ps.Color = Q.Prism; ps.Thickness = 1.5; ps.Transparency = 0.25; ps.Parent = prism
        HtBar(hub, 1, 1, 12, 12, W1, 0.6, 45) -- (its bright heart)
        HtBar(hub, -60, 6, 110, 2, W1, 0.55, -6) -- (the white beam coming in)
        local rays = {}
        for i = 1, 7 do
            local a = -14 + i * 4.5
            local len = 250
            rays[i] = HtBar(hub, 1 + math.cos(math.rad(a)) * (len / 2 + 14), 1 + math.sin(math.rad(a)) * (len / 2 + 14), len, 2, Color3.fromHSV((i - 1) / 7, 0.6, 1), 0.5, a)
        end
        return function(now, _dt)
            for i, r in ipairs(rays) do r.BackgroundColor3 = Color3.fromHSV(((i - 1) / 7 + now * 0.03) % 1, 0.6, 1) end
            for _, m in ipairs(ctx.Marks()) do
                local g = m.Visible and m:FindFirstChild("HtSpectrum")
                if g then g.Offset = Vector2.new(math.sin(now * 0.5) * 0.3, 0) end
            end
        end, nil
    end,
}
return A_CLEAN
