--!nocheck
-- STORE UI THEMES, second half (SKIN UI roll-out 2026-10-29, builder B; contract docs/SKIN_UI_2026-10-28.md): the clean-language
-- look (UITheme "Clean" palette + Sig + TabMark) and the damage numbers of four store themes -- NeonCyber (Neon Overdrive), Inferno
-- (Hellforge), VoidRift, InfernalPact. HudThemes puts T.<Id>.Clean / T.<Id>.Numbers on its own entries. Pure data + hooks:
-- requires nothing. Rules (UITheme header): hooks read only the palette they are given (Q / ctx.P); tab mark children are
-- offset-sized and stay inside the mark's width; one tick per field; no per-frame work per object beyond a handful of frames;
-- nothing over the crosshair (numbers keep HitNumbers' KEEP_OUT), no red screen flashes. The old art fields of the entries (Tex,
-- Corner, Emblem, Watermark, Ambient ...) are not drawn by a Clean theme.
local T = {}
local C = Color3.fromRGB
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function K(t, c) return ColorSequenceKeypoint.new(t, c) end
local function NK(t, v) return NumberSequenceKeypoint.new(t, v) end
local function Frame(name, parent, z)
    local f = Instance.new("Frame")
    f.Name = name; f.BorderSizePixel = 0; f.ZIndex = z or 0; f.Parent = parent
    return f
end
local function Round(f) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = f; return c end
local function Seg(s, ax, ay, bx, by, th)
    local dx, dy = bx - ax, by - ay
    s.AnchorPoint = Vector2.new(0.5, 0.5)
    s.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + th, th)
    s.Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2)
    s.Rotation = math.deg(math.atan2(dy, dx))
end
local function TopY(ctx)
    local top, f = ctx.Top, ctx.Frame
    if top and top.AbsoluteSize.Y > 0 then return top.AbsolutePosition.Y - f.AbsolutePosition.Y + top.AbsoluteSize.Y end
    return 64
end
-- a text copy of the number's label inside an accent box (same text / face / size, its own colour)
local function Copy(box, name, z)
    local l = Instance.new("TextLabel")
    l.Name = name; l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1, 1); l.ZIndex = z; l.TextStrokeTransparency = 1
    l:SetAttribute("KeepFont", true); l:SetAttribute("NoSnap", true); l.Parent = box
    return l
end
local function Mirror(l, lbl)
    if l.Text ~= lbl.Text then l.Text = lbl.Text end
    l.FontFace = lbl.FontFace; l.TextSize = lbl.TextSize
end

-- ===================================================================================================================
-- NEON OVERDRIVE: black glass, a cyan neon primary, magenta second.
--   TAB MARK  a NEON TUBE: the cyan bar with a soft glow round it; on the top bar the tube flickers now and then
--   FIELD     CIRCUIT TRACES run in from the upper-right and lower-right corners (right angles + 45 deg bends ending in pads) and
--             packets of magenta light run along them
--   NUMBERS   GLITCH: Michroma digits that land RGB-SPLIT (a cyan copy left, a magenta copy right) and snap together, again on every
--             merged hit; crit = the split jitters and a slice of the digits tears sideways; weak = ◈; kill = DEREZ (the copies tear
--             far apart and the digits flicker out)
-- ===================================================================================================================
do
    local P = { Ink = C(3, 4, 9), Glass = C(10, 14, 24), Card = C(16, 22, 36), Cyan = C(60, 240, 255), Magenta = C(255, 60, 220), Text = C(205, 250, 255), Steel = C(70, 90, 120) }
    local CL = {
        Field = P.Ink:Lerp(P.Glass, 0.4), Surface = P.Glass, Raised = P.Card, Hover = P.Card:Lerp(P.Cyan, 0.1), Well = P.Ink,
        Line = P.Card:Lerp(P.Cyan, 0.28), Tip = P.Ink:Lerp(P.Glass, 0.6), Accent = P.Cyan, Mark = P.Cyan, Hair = P.Cyan:Lerp(P.Steel, 0.35),
        Text = P.Text, Sub = P.Text:Lerp(P.Steel, 0.45), Muted = P.Steel:Lerp(P.Text, 0.3), Ink = P.Ink,
        Neon = P.Cyan, Neon2 = P.Magenta, Trace = P.Cyan:Lerp(P.Glass, 0.5),
    }
    CL.TabMark = function(mark, Q)
        local glow = Instance.new("UIStroke")
        glow.Name = "NeTube"; glow.Color = Q.Neon; glow.Thickness = 2; glow.Transparency = 0.55; glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        glow.Parent = mark
        return { glow }
    end
    -- trace paths in px from their corner (x right / y down for the upper-right one is mirrored: x measured leftward)
    local TRACES = {
        { { 0, 0 }, { 90, 0 }, { 120, 30 }, { 210, 30 } }, { { 0, 18 }, { 60, 18 }, { 96, 54 }, { 96, 120 } }, { { 0, 40 }, { 30, 40 }, { 50, 60 }, { 50, 170 }, { 70, 190 } },
    }
    CL.Sig = function(ctx)
        local Q, f = ctx.P, ctx.Frame
        local topY = TopY(ctx)
        local nets = {}
        local function Net(anchorX, anchorY, sx, sy, oy)
            local holder = Frame("NeCircuit", f, 0)
            holder.BackgroundTransparency = 1; holder.AnchorPoint = Vector2.new(anchorX, anchorY); holder.Position = UDim2.new(anchorX, 0, anchorY, oy)
            holder.Size = UDim2.fromOffset(240, 220)
            local paths = {}
            for _, tr in ipairs(TRACES) do
                local pts, L = {}, 0
                for i, p in ipairs(tr) do
                    local x = (sx > 0) and p[1] or (240 - p[1])
                    local y = (sy > 0) and p[2] or (220 - p[2])
                    pts[i] = Vector2.new(x, y)
                    if i > 1 then
                        local s = Frame("Trace", holder, 0)
                        s.BackgroundColor3 = Q.Trace; s.BackgroundTransparency = 0.45
                        Seg(s, pts[i - 1].X, pts[i - 1].Y, x, y, 2)
                        L += (pts[i] - pts[i - 1]).Magnitude
                    end
                end
                local pad = Frame("Pad", holder, 1)
                pad.BackgroundTransparency = 1; pad.AnchorPoint = Vector2.new(0.5, 0.5); pad.Size = UDim2.fromOffset(7, 7)
                pad.Position = UDim2.fromOffset(pts[#pts].X, pts[#pts].Y); Round(pad)
                local ps = Instance.new("UIStroke"); ps.Color = Q.Neon; ps.Thickness = 1.5; ps.Parent = pad
                local pk = Frame("Packet", holder, 2)
                pk.BackgroundColor3 = Q.Neon2; pk.AnchorPoint = Vector2.new(0.5, 0.5); pk.Size = UDim2.fromOffset(6, 3); pk.BackgroundTransparency = 1
                table.insert(paths, { Pts = pts, L = L, Pk = pk, Ph = #paths * 1.7 })
            end
            table.insert(nets, paths)
        end
        Net(1, 0, -1, 1, topY + 6) -- (upper right, under the top bar, running in from the right edge)
        Net(1, 1, -1, -1, 0) -- (lower right, running in from the right edge: the lower left ran behind the stat rows)
        return function(now, _dt)
            for _, paths in ipairs(nets) do
                for _, p in ipairs(paths) do
                    local u = ((now + p.Ph) % 3.4) / 1.4 -- (a packet every 3.4 s, 1.4 s along the trace)
                    if u < 1 then
                        local d = u * p.L
                        for i = 2, #p.Pts do
                            local seg = (p.Pts[i] - p.Pts[i - 1]).Magnitude
                            if d <= seg or i == #p.Pts then
                                local pos = p.Pts[i - 1]:Lerp(p.Pts[i], math.clamp(d / math.max(seg, 1), 0, 1))
                                p.Pk.Position = UDim2.fromOffset(pos.X, pos.Y)
                                p.Pk.Rotation = math.deg(math.atan2(p.Pts[i].Y - p.Pts[i - 1].Y, p.Pts[i].X - p.Pts[i - 1].X))
                                break
                            end
                            d -= seg
                        end
                        p.Pk.BackgroundTransparency = 0.05 + 0.6 * math.abs(u * 2 - 1) ^ 6
                    elseif p.Pk.BackgroundTransparency < 1 then p.Pk.BackgroundTransparency = 1 end
                end
            end
            -- the selected tab's neon tube flickers twice now and then
            local fl = ((now % 5.3) < 0.18) and ((math.floor(now * 30) % 2 == 0) and 0.9 or 0.4) or 0.55
            for _, m in ipairs(ctx.Marks()) do
                local g = m.Visible and m:FindFirstChild("NeTube")
                if g then g.Transparency = fl end
            end
        end, nil
    end
    local function Motion(e, age, pa, life)
        local rise = 1 - (1 - math.min(1, age / 0.8)) ^ 3
        local kill = (e.Killed and e.KillAt) and math.clamp((os.clock() - e.KillAt - 0.25) / 0.5, 0, 1) or 0
        local flick = (kill > 0 and (math.floor(os.clock() * 24) % 2 == 0)) and 0.55 or 0
        return 0.4 + rise * 1.4, 0, 1 + 0.08 * math.exp(-pa * 16), 0, math.max(flick, kill * 0.6), 0
    end
    local function Accent(e)
        local box = Instance.new("Frame")
        box.Name = "NeGlitch"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 0
        Copy(box, "Cy", 0); Copy(box, "Ma", 0)
        local slice = Instance.new("Frame") -- (a crit tears a slice of the digits sideways: a clipped copy)
        slice.Name = "Slice"; slice.BackgroundTransparency = 1; slice.ClipsDescendants = true; slice.AnchorPoint = Vector2.new(0.5, 0.5)
        slice.Position = UDim2.fromScale(0.5, 0.5); slice.ZIndex = 3; slice.Parent = box
        local sl = Copy(slice, "Txt", 3); sl.AnchorPoint = Vector2.new(0.5, 0.5); sl.Size = UDim2.fromOffset(220, 56)
        return box
    end
    local function AccentStep(e, box, age, pa, alpha)
        local lbl = e.Label
        local tb = lbl.TextBounds
        local crit = e.Crit and not e.Dot
        local kill = (e.Killed and e.KillAt) and smooth((os.clock() - e.KillAt) / 0.6) or 0
        local split = 7 * (1 - smooth(pa / 0.12)) + (crit and (age < 0.3) and math.random(-2, 2) or 0) + 26 * kill
        for i, name in ipairs({ "Cy", "Ma" }) do
            local l = box:FindFirstChild(name)
            if l then
                l.Visible = not e.Dot
                Mirror(l, lbl)
                l.TextColor3 = (i == 1) and P.Cyan or P.Magenta
                l.Position = UDim2.fromOffset(math.floor((i == 1 and -1 or 1) * split), 0)
                l.TextTransparency = math.clamp(alpha + 0.25 + (split < 1 and 0.4 or 0), 0, 1)
            end
        end
        local slice = box:FindFirstChild("Slice")
        if slice then
            local on = crit and age < 0.45 and (math.floor(age * 14) % 3 ~= 2)
            slice.Visible = on
            if on then
                slice.Size = UDim2.fromOffset(tb.X + 16, math.max(3, math.floor(tb.Y * 0.28)))
                slice.Position = UDim2.new(0.5, math.random(-5, 5), 0.5, math.floor(tb.Y * (math.random() - 0.5) * 0.5))
                local t = slice:FindFirstChild("Txt")
                if t then
                    Mirror(t, lbl)
                    t.Position = UDim2.new(0.5, 0, 0.5, -(slice.Position.Y.Offset))
                    t.TextColor3 = P.Magenta:Lerp(WHITE, 0.4); t.TextTransparency = alpha
                end
            end
        end
    end
    T.NeonCyber = { Clean = CL, Numbers = { Font = "Michroma", Glyph = "◈", NoBang = true, Motion = Motion, Accent = Accent, AccentStep = AccentStep,
        Normal = P.Text, Crit = P.Cyan, Weak = P.Magenta:Lerp(WHITE, 0.25), Stroke = C(10, 0, 30), StrokeThick = 1.5 } }
end

-- ===================================================================================================================
-- HELLFORGE: molten basalt, lava primary.
--   TAB MARK  a LAVA SEAM: the bar runs dark red -> orange -> yellow -> orange -> dark red and the molten light FLOWS along it on
--             the top bar
--   FIELD     a jagged row of obsidian TEETH rises out of both lower corners of the screen, rimmed with lava light that pulses like breathing,
--             and a few embers rise past them and wink out
--   NUMBERS   MOLTEN: GrenzeGotisch digits slammed down as molten metal (deep orange glyphs, a flickering white-yellow hot core);
--             crit = 3 tongues of flame flare up off the digits' top edge and the core burns whiter; weak = red-orange digits;
--             kill = a bigger flare + embers fly up off the number
-- ===================================================================================================================
do
    local P = { Ink = C(12, 4, 2), Basalt = C(30, 14, 10), Card = C(46, 20, 13), Lava = C(255, 120, 30), Yellow = C(255, 220, 110), Red = C(170, 30, 10), Text = C(255, 214, 170), Ash = C(120, 84, 70) }
    local CL = {
        Field = P.Ink:Lerp(P.Basalt, 0.45), Surface = P.Basalt:Lerp(P.Ink, 0.35), Raised = P.Card, Hover = P.Card:Lerp(P.Lava, 0.12), Well = P.Ink,
        Line = P.Card:Lerp(P.Lava, 0.25), Tip = P.Ink:Lerp(P.Basalt, 0.5), Accent = P.Lava, Mark = P.Lava, Hair = P.Lava:Lerp(P.Ash, 0.45),
        Text = P.Text, Sub = P.Text:Lerp(P.Ash, 0.42), Muted = P.Ash:Lerp(P.Text, 0.3), Ink = P.Ink,
        Lava = P.Lava, Molten = P.Yellow, Cinder = P.Red, Obsidian = C(8, 5, 6),
    }
    CL.TabMark = function(mark, Q)
        local g = Instance.new("UIGradient")
        g.Name = "HfLava"
        g.Color = ColorSequence.new({ K(0, Q.Cinder), K(0.3, Q.Lava), K(0.5, Q.Molten), K(0.7, Q.Lava), K(1, Q.Cinder) })
        g.Parent = mark
        return { g }
    end
    -- (obsidian teeth: squares turned 45 deg with their centre on the screen edge = a jagged row of points; a rotated rectangle
    -- read as planks)
    local THORNS = { { 10, 58 }, { 44, 92 }, { 80, 50 }, { 108, 70 }, { 138, 40 }, { 160, 28 } }
    CL.Sig = function(ctx)
        local Q, f = ctx.P, ctx.Frame
        local rims = {}
        for side = 0, 1 do
            local holder = Frame("HfThorns", f, 0)
            holder.BackgroundTransparency = 1; holder.AnchorPoint = Vector2.new(side, 1); holder.Position = UDim2.fromScale(side, 1)
            holder.Size = UDim2.fromOffset(190, 80); holder.ClipsDescendants = true
            for _, t in ipairs(THORNS) do
                local th = Frame("Thorn", holder, 0)
                th.BackgroundColor3 = Q.Obsidian; th.AnchorPoint = Vector2.new(0.5, 0.5); th.Rotation = 45
                local x = (side == 0) and t[1] or (190 - t[1])
                th.Position = UDim2.fromOffset(x, 80); th.Size = UDim2.fromOffset(t[2], t[2])
                local rim = Instance.new("UIStroke"); rim.Color = Q.Lava; rim.Thickness = 1.5; rim.Transparency = 0.3; rim.Parent = th
                table.insert(rims, rim)
            end
        end
        local embers = {}
        for i = 1, 8 do
            local em = Frame("Ember", f, 0)
            em.BackgroundColor3 = (i % 2 == 0) and Q.Molten or Q.Lava; em.AnchorPoint = Vector2.new(0.5, 0.5); em.Size = UDim2.fromOffset(3, 3)
            em.BackgroundTransparency = 1; Round(em)
            local left = i <= 4
            embers[i] = { F = em, X = left and (0.015 + 0.02 * i) or (0.985 - 0.02 * (i - 4)), Sp = 4 + (i % 3), Ph = i * 0.9 }
        end
        return function(now, _dt)
            local b = 0.5 + 0.5 * math.sin(now * 1.3) -- (the lava rims breathe)
            for _, r in ipairs(rims) do r.Transparency = 0.15 + 0.45 * b end
            for _, e in ipairs(embers) do
                local u = ((now + e.Ph) % e.Sp) / e.Sp
                e.F.Position = UDim2.new(e.X + 0.01 * math.sin(now * 2 + e.Ph), 0, 1 - 0.05 - u * 0.4, 0)
                e.F.BackgroundTransparency = 0.1 + 0.9 * u
            end
            for _, m in ipairs(ctx.Marks()) do
                local g = m.Visible and m:FindFirstChild("HfLava")
                if g then g.Offset = Vector2.new(0.35 * math.sin(now * 0.9), 0) end
            end
        end, nil
    end
    local function Motion(e, age, pa, life)
        local k = math.min(1, pa / 0.07)
        local rise = 1 - (1 - math.min(1, age / 0.85)) ^ 3
        return 0.4 + rise * 1.3, 0, 1 + 0.22 * (e.BumpAmp or 1) * (1 - k), -10 * (e.BumpAmp or 1) * (1 - k) ^ 2, 0, 0
    end
    local FLAMES = 3
    -- (v2, coordinator 2026-10-29: the first flames were thin streaks floating ABOVE the digits, detached) -- the fire IS the
    -- number now: the digits are molten metal (deep orange glyphs, a white-yellow hot core through their middle that flickers),
    -- and a crit / kill flares 3 short tongues of flame licking up off the digits' TOP edge (behind them, so they grow out of
    -- the glyphs), then they die down; a kill also throws embers up.
    local function Accent(e)
        local box = Instance.new("Frame")
        box.Name = "HfFire"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 0
        for i = 1, FLAMES do
            local fl = Frame("Flame" .. i, box, 0)
            fl.AnchorPoint = Vector2.new(0.5, 1); fl.BackgroundColor3 = WHITE; Round(fl)
            local g = Instance.new("UIGradient"); g.Rotation = -90
            g.Color = ColorSequence.new({ K(0, P.Yellow), K(0.45, P.Lava), K(1, P.Red) })
            g.Transparency = NumberSequence.new({ NK(0, 0), NK(0.6, 0.15), NK(1, 0.9) })
            g.Parent = fl
        end
        -- the hot core: the same digits in white-yellow over the label, faded out toward their top and bottom edges
        local core = Copy(box, "Core", 3)
        local cg = Instance.new("UIGradient"); cg.Rotation = 90
        cg.Transparency = NumberSequence.new({ NK(0, 1), NK(0.36, 0.7), NK(0.58, 0.08), NK(0.78, 0.7), NK(1, 1) })
        cg.Parent = core
        for i = 1, 4 do
            local em = Frame("Ember" .. i, box, 2)
            em.AnchorPoint = Vector2.new(0.5, 0.5); em.Size = UDim2.fromOffset(3, 3); Round(em)
        end
        return box
    end
    local function AccentStep(e, box, age, pa, alpha)
        local lbl = e.Label
        local tb = lbl.TextBounds
        local crit = e.Crit and not e.Dot
        local kt = (e.Killed and e.KillAt) and (os.clock() - e.KillAt) or -1
        local core = box:FindFirstChild("Core")
        if core then
            core.Visible = not e.Dot
            Mirror(core, lbl)
            -- (the core's box = one line of text, so the gradient's band sits on the glyphs, not on the 56 px holder)
            core.AnchorPoint = Vector2.new(0.5, 0.5); core.Position = UDim2.fromScale(0.5, 0.5)
            core.Size = UDim2.new(1, 0, 0, math.max(1, math.floor(tb.Y)))
            -- (a short flicker: two detuned sines, brighter for a beat on every merged hit)
            local fl = 0.5 + 0.25 * math.sin(age * 23 + e.Seed) + 0.25 * math.sin(age * 37)
            local hit = math.exp(-pa * 10)
            core.TextColor3 = (e.DType and e.DType ~= "Kinetic") and e.Color:Lerp(WHITE, 0.55) or P.Yellow:Lerp(WHITE, crit and 0.6 or 0.3)
            core.TextTransparency = math.clamp(alpha + 0.12 + 0.3 * (1 - fl) * (1 - hit), 0, 1)
        end
        -- the flare: on a crit (from the hit) and on a kill (from the kill), 0.55 s, attached to the top edge of the digits
        local ft = (kt >= 0) and kt or (crit and age or -1)
        local big = (kt >= 0) and 1.25 or 1
        for i = 1, FLAMES do
            local f = box:FindFirstChild("Flame" .. i)
            if f then
                local on = ft >= 0 and ft < 0.55 and not e.Dot
                f.Visible = on
                if on then
                    local grow = smooth(ft / 0.1) * (1 - smooth((ft - 0.25) / 0.3))
                    local lick = 0.8 + 0.2 * math.sin(age * 26 + i * 2)
                    local h = tb.Y * ((i == 2) and 1.05 or 0.8) * big * grow * lick
                    local w = math.max(7, tb.X * 0.3)
                    f.Size = UDim2.fromOffset(math.floor(w), math.floor(h + w * 0.5))
                    -- (the base sits a third of the way down the glyphs, behind them: the tongues grow out of the top edge)
                    f.Position = UDim2.new(0.5, math.floor((i - 2) * tb.X * 0.32), 0.5, math.floor(tb.Y * 0.2)) -- (the digits' ink sits low in the line)
                    f.Rotation = (i - 2) * 9 + math.sin(age * 14 + i) * 4
                    f.BackgroundTransparency = math.clamp(alpha, 0, 1)
                end
            end
        end
        for i = 1, 4 do
            local em = box:FindFirstChild("Ember" .. i)
            if em then
                local t = kt - (i - 1) * 0.05
                local on = kt >= 0 and t >= 0 and t < 0.7 and not e.Dot
                em.Visible = on
                if on then
                    local u = t / 0.7
                    em.Position = UDim2.new(0.5, math.floor((i - 2.5) * 12 * (0.4 + u)), 0.5, math.floor(-tb.Y * 0.5 - 50 * u))
                    em.BackgroundColor3 = P.Yellow:Lerp(P.Red, u); em.BackgroundTransparency = math.clamp(alpha + u * 0.9, 0, 1)
                end
            end
        end
    end
    T.Inferno = { Clean = CL, Numbers = { Font = "GrenzeGotisch", Glyph = "", NoBang = true, Motion = Motion, Accent = Accent, AccentStep = AccentStep, -- (the face has no cross glyph: it drew a box)
        Normal = C(255, 128, 34), Crit = C(255, 196, 60), Weak = C(255, 86, 40), Stroke = C(36, 6, 0), StrokeThick = 2.5, Size = 1.1 } }
end

-- ===================================================================================================================
-- VOID RIFT: deep space violet, a violet primary, pink second.
--   TAB MARK  a STARLIT RIFT: the violet bar with three points of starlight along it that twinkle in turn on the top bar
--   FIELD     an EVENT HORIZON in the lower-left corner of the screen: three thin rings round a dark core, slowly turning (their
--             light runs round them) and breathing, a scatter of faint stars round it that twinkle
--   NUMBERS   PULLED IN: Sarpanch digits that IMPLODE into place -- a ring collapses onto them from wide as they snap from nothing,
--             again on every merged hit; crit = two rings, the digits wobble; weak = ◉; kill = the number is SWALLOWED: it spins
--             down into a point and a pink ring flashes out
-- ===================================================================================================================
do
    local P = { Ink = C(6, 2, 14), Space = C(22, 10, 38), Card = C(34, 17, 54), Violet = C(190, 110, 255), Pink = C(255, 120, 220), Star = C(240, 228, 255), Text = C(230, 212, 255), Dust = C(120, 100, 150) }
    local CL = {
        Field = P.Ink:Lerp(P.Space, 0.4), Surface = P.Space:Lerp(P.Ink, 0.3), Raised = P.Card, Hover = P.Card:Lerp(P.Violet, 0.12), Well = P.Ink,
        Line = P.Card:Lerp(P.Violet, 0.3), Tip = P.Ink:Lerp(P.Space, 0.5), Accent = P.Violet, Mark = P.Violet, Hair = P.Violet:Lerp(P.Dust, 0.4),
        Text = P.Text, Sub = P.Text:Lerp(P.Dust, 0.42), Muted = P.Dust:Lerp(P.Text, 0.3), Ink = P.Ink,
        Rift = P.Violet, Rift2 = P.Pink, Starlight = P.Star, Core = C(2, 0, 6),
    }
    CL.TabMark = function(mark, Q)
        local made = {}
        for i, x in ipairs({ 0.2, 0.55, 0.85 }) do
            local s = Frame("VrStar" .. i, mark, mark.ZIndex + 1)
            s.BackgroundColor3 = Q.Starlight; s.Size = UDim2.fromOffset(3, 3); s.Position = UDim2.new(x, -1, 0, -1); s.Rotation = 45
            table.insert(made, s)
        end
        return made
    end
    CL.Sig = function(ctx)
        local Q, f = ctx.P, ctx.Frame
        local cam = workspace.CurrentCamera
        local vh = cam and cam.ViewportSize.Y or 800
        local R = math.clamp(math.floor(vh * 0.2), 80, 170)
        local hole = Frame("VrHorizon", f, 0)
        hole.BackgroundTransparency = 1; hole.AnchorPoint = Vector2.new(0.5, 0.5); hole.Position = UDim2.new(0, math.floor(R * 0.55), 1, -math.floor(R * 0.55))
        hole.Size = UDim2.fromOffset(R * 2, R * 2)
        local core = Frame("Core", hole, 0)
        core.BackgroundColor3 = Q.Core; core.BackgroundTransparency = 0.25; core.AnchorPoint = Vector2.new(0.5, 0.5); core.Position = UDim2.fromScale(0.5, 0.5)
        core.Size = UDim2.fromScale(0.36, 0.36); Round(core)
        local rings = {}
        for i, s in ipairs({ 0.42, 0.62, 0.9 }) do
            local r = Frame("Ring" .. i, hole, 0)
            r.BackgroundTransparency = 1; r.AnchorPoint = Vector2.new(0.5, 0.5); r.Position = UDim2.fromScale(0.5, 0.5); r.Size = UDim2.fromScale(s, s * 0.92)
            Round(r)
            local st = Instance.new("UIStroke"); st.Color = WHITE; st.Thickness = (i == 1) and 2 or 1; st.Transparency = 0.25 + i * 0.15; st.Parent = r
            local g = Instance.new("UIGradient")
            g.Color = ColorSequence.new({ K(0, Q.Rift), K(0.5, Q.Rift2), K(1, Q.Rift) })
            g.Transparency = NumberSequence.new({ NK(0, 0), NK(0.45, 0.7), NK(1, 0) })
            g.Parent = st
            rings[i] = { F = r, G = g, St = st, S = s, Sp = (i % 2 == 0) and -14 or 20 }
        end
        local stars = {}
        for i = 1, 10 do
            local s = Frame("Star", f, 0)
            s.BackgroundColor3 = Q.Starlight; s.AnchorPoint = Vector2.new(0.5, 0.5); local z = (i % 3 == 0) and 3 or 2
            s.Size = UDim2.fromOffset(z, z); s.Rotation = 45
            local a, d = i * 2.39, R * (0.9 + (i % 4) * 0.28)
            s.Position = UDim2.new(0, math.floor(R * 0.55 + math.cos(a) * d), 1, -math.floor(R * 0.55 + math.abs(math.sin(a)) * d))
            stars[i] = { F = s, Ph = i * 1.3 }
        end
        return function(now, _dt)
            for i, r in ipairs(rings) do
                r.G.Rotation = (now * r.Sp) % 360
                local b = 1 + 0.03 * math.sin(now * 0.8 + i)
                r.F.Size = UDim2.fromScale(r.S * b, r.S * 0.92 * b)
            end
            for _, s in ipairs(stars) do s.F.BackgroundTransparency = 0.3 + 0.6 * (0.5 + 0.5 * math.sin(now * 1.7 + s.Ph)) end
            for _, m in ipairs(ctx.Marks()) do
                if m.Visible then
                    for i = 1, 3 do
                        local s = m:FindFirstChild("VrStar" .. i)
                        if s then s.BackgroundTransparency = 1 - math.max(0, math.sin(now * 2 + i * 2.1)) ^ 3 end
                    end
                end
            end
        end, nil
    end
    local function Motion(e, age, pa, life)
        local rise = 1 - (1 - math.min(1, age / 0.85)) ^ 3
        local pop = smooth(pa / 0.12)
        local sc = 0.55 + 0.45 * pop + 0.12 * math.sin(math.clamp(pa / 0.2, 0, 1) * math.pi) * (e.BumpAmp or 1)
        local rot = (e.Crit and not e.Dot and age < 0.4) and math.sin(age * 40) * 5 * (1 - age / 0.4) or 0
        local kt = (e.Killed and e.KillAt) and (os.clock() - e.KillAt - 0.3) or -1
        local alpha = 0
        if kt > 0 then -- (swallowed: spins down to a point)
            local k = smooth(kt / 0.35)
            sc *= 1 - 0.9 * k; rot += 200 * k; alpha = k
        end
        return 0.4 + rise * 1.3, 0, sc, 0, alpha, rot
    end
    local function Accent(e)
        local box = Instance.new("Frame")
        box.Name = "VrRings"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 0
        for i = 1, 3 do
            local r = Frame("R" .. i, box, 1)
            r.BackgroundTransparency = 1; r.AnchorPoint = Vector2.new(0.5, 0.5); r.Position = UDim2.fromScale(0.5, 0.5); Round(r)
            local st = Instance.new("UIStroke"); st.Thickness = (i == 3) and 2 or 1.5; st.Parent = r
        end
        return box
    end
    local function AccentStep(e, box, age, pa, alpha)
        local tb = e.Label.TextBounds
        local crit = e.Crit and not e.Dot
        local base = math.max(tb.X, tb.Y) + 14
        for i = 1, 2 do -- (the collapse: wide -> onto the digits in 0.16 s; a crit sends a second ring 0.06 s later)
            local r = box:FindFirstChild("R" .. i)
            if r then
                local on = not e.Dot and (i == 1 or crit)
                local k = smooth((pa - (i - 1) * 0.06) / 0.16)
                r.Visible = on and k < 1
                if r.Visible then
                    local d = base * (1 + 1.6 * (1 - k))
                    r.Size = UDim2.fromOffset(math.floor(d), math.floor(d * 0.62))
                    local st = r:FindFirstChildOfClass("UIStroke")
                    if st then st.Color = (i == 1) and P.Violet or P.Pink; st.Transparency = math.clamp(alpha + 0.2 + 0.6 * (1 - k) ^ 3, 0, 1) end
                end
            end
        end
        local r3 = box:FindFirstChild("R3") -- (a kill: when it is swallowed, a pink ring flashes out of the point)
        if r3 then
            local kt = (e.Killed and e.KillAt) and (os.clock() - e.KillAt - 0.6) or -1
            r3.Visible = kt >= 0 and kt < 0.4 and not e.Dot
            if r3.Visible then
                local k = smooth(kt / 0.4)
                local d = 6 + base * 1.4 * k
                r3.Size = UDim2.fromOffset(math.floor(d), math.floor(d * 0.62))
                local st = r3:FindFirstChildOfClass("UIStroke"); if st then st.Color = P.Pink; st.Transparency = k end
            end
        end
    end
    T.VoidRift = { Clean = CL, Numbers = { Font = "Sarpanch", Glyph = "◉", NoBang = true, Motion = Motion, Accent = Accent, AccentStep = AccentStep,
        Normal = P.Text, Crit = P.Violet:Lerp(WHITE, 0.15), Weak = P.Pink, Stroke = C(20, 0, 40), StrokeThick = 1.5, Size = 1.05 } }
end

-- ===================================================================================================================
-- INFERNAL PACT: obsidian violet + crimson, the pact's two colours.
--   TAB MARK  a PACT BAR: crimson running into violet with a small sealed diamond at its end
--   FIELD     a PACT CIRCLE in the lower-right of the screen: two crisp rings with twelve ticks and six sealed diamonds set
--             inside, turning slowly, a crimson glow breathing behind it (abstract geometry only: no religious / occult symbol)
--   NUMBERS   THE PACT: crimson GrenzeGotisch digits with a VIOLET AFTERIMAGE that trails them (a ghost copy that follows a beat
--             behind and catches up); crit = a ring of ticks (a seal) stamps behind the digits and turns; weak = pale violet; kill = the
--             afterimage tears away upward and burns out
-- ===================================================================================================================
do
    local P = { Ink = C(8, 2, 8), Obsidian = C(28, 11, 24), Card = C(40, 17, 34), Crimson = C(235, 50, 75), Violet = C(170, 90, 255), Text = C(255, 214, 226), Dust = C(130, 92, 120) }
    local CL = {
        Field = P.Ink:Lerp(P.Obsidian, 0.45), Surface = P.Obsidian:Lerp(P.Ink, 0.3), Raised = P.Card, Hover = P.Card:Lerp(P.Crimson, 0.12), Well = P.Ink,
        Line = P.Card:Lerp(P.Violet, 0.25), Tip = P.Ink:Lerp(P.Obsidian, 0.5), Accent = P.Crimson, Mark = P.Crimson, Hair = P.Violet:Lerp(P.Dust, 0.35),
        Text = P.Text, Sub = P.Text:Lerp(P.Dust, 0.42), Muted = P.Dust:Lerp(P.Text, 0.3), Ink = P.Ink,
        Blood = P.Crimson, Pact = P.Violet, Sigil = P.Crimson:Lerp(P.Violet, 0.35),
    }
    CL.TabMark = function(mark, Q)
        local g = Instance.new("UIGradient")
        g.Name = "IpPact"; g.Color = ColorSequence.new(Q.Blood, Q.Pact); g.Parent = mark
        local d = Frame("IpSeal", mark, mark.ZIndex + 1)
        d.BackgroundColor3 = Q.Pact; d.Size = UDim2.fromOffset(6, 6); d.Position = UDim2.new(1, -6, 0, -2); d.Rotation = 45
        local st = Instance.new("UIStroke"); st.Color = Q.Ink; st.Thickness = 1; st.Parent = d
        return { g, d }
    end
    CL.Sig = function(ctx)
        local Q, f = ctx.P, ctx.Frame
        local cam = workspace.CurrentCamera
        local vh = cam and cam.ViewportSize.Y or 800
        local R = math.clamp(math.floor(vh * 0.24), 90, 200)
        local holder = Frame("IpCircle", f, 0)
        holder.BackgroundTransparency = 1; holder.AnchorPoint = Vector2.new(0.5, 0.5)
        holder.Position = UDim2.new(1, -math.floor(R * 0.7), 1, -math.floor(R * 0.7)); holder.Size = UDim2.fromOffset(R * 2, R * 2)
        local glow = Frame("Glow", holder, 0)
        glow.BackgroundColor3 = Q.Blood; glow.AnchorPoint = Vector2.new(0.5, 0.5); glow.Position = UDim2.fromScale(0.5, 0.5); glow.Size = UDim2.fromScale(0.95, 0.95)
        Round(glow)
        local gg = Instance.new("UIGradient"); gg.Transparency = NumberSequence.new({ NK(0, 1), NK(0.5, 0.82), NK(1, 1) }); gg.Rotation = 90; gg.Parent = glow
        local spin = Frame("Spin", holder, 0)
        spin.BackgroundTransparency = 1; spin.AnchorPoint = Vector2.new(0.5, 0.5); spin.Position = UDim2.fromScale(0.5, 0.5); spin.Size = UDim2.fromOffset(R * 2, R * 2)
        for i, s in ipairs({ 0.96, 0.78 }) do
            local r = Frame("Ring" .. i, spin, 0)
            r.BackgroundTransparency = 1; r.AnchorPoint = Vector2.new(0.5, 0.5); r.Position = UDim2.fromScale(0.5, 0.5); r.Size = UDim2.fromScale(s, s); Round(r)
            local st = Instance.new("UIStroke"); st.Color = Q.Sigil; st.Thickness = (i == 1) and 1.5 or 1; st.Transparency = 0.55; st.Parent = r
        end
        for i = 0, 11 do -- ticks between the rings
            local a = math.rad(i * 30)
            local t = Frame("Tick", spin, 0)
            t.BackgroundColor3 = Q.Sigil; t.BackgroundTransparency = 0.45
            Seg(t, R + math.cos(a) * R * 0.78, R + math.sin(a) * R * 0.78, R + math.cos(a) * R * 0.9, R + math.sin(a) * R * 0.9, 1)
        end
        for i = 0, 5 do -- six small sealed diamonds set round the inner ring (abstract: no religious or occult symbol)
            local a = math.rad(i * 60 + 15)
            local s = Frame("Gem", spin, 0)
            s.BackgroundColor3 = Q.Pact; s.BackgroundTransparency = 0.35; s.AnchorPoint = Vector2.new(0.5, 0.5); s.Rotation = 45 + i * 60
            s.Size = UDim2.fromOffset(7, 7); s.Position = UDim2.fromOffset(R + math.cos(a) * R * 0.66, R + math.sin(a) * R * 0.66)
        end
        return function(now, _dt)
            spin.Rotation = (now * 4) % 360
            glow.BackgroundTransparency = 0.35 + 0.25 * math.sin(now * 0.9)
        end, nil
    end
    local function Motion(e, age, pa, life)
        local k = math.min(1, pa / 0.07)
        local rise = 1 - (1 - math.min(1, age / 0.85)) ^ 3
        return 0.4 + rise * 1.3, 0, 1 + 0.18 * (e.BumpAmp or 1) * (1 - k), -8 * (e.BumpAmp or 1) * (1 - k) ^ 2, 0, 0
    end
    local function Accent(e)
        local box = Instance.new("Frame")
        box.Name = "IpPact"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 0
        Copy(box, "Ghost", 0)
        local seal = Frame("Seal", box, 0)
        seal.BackgroundTransparency = 1; seal.AnchorPoint = Vector2.new(0.5, 0.5); seal.Position = UDim2.fromScale(0.5, 0.5)
        local r = Frame("Ring", seal, 0); r.BackgroundTransparency = 1; r.Size = UDim2.fromScale(1, 1); Round(r)
        local st = Instance.new("UIStroke"); st.Thickness = 1.5; st.Parent = r
        for i = 1, 8 do
            local t = Frame("T" .. i, seal, 0); t.AnchorPoint = Vector2.new(0.5, 0.5)
        end
        return box
    end
    local function AccentStep(e, box, age, pa, alpha)
        local lbl = e.Label
        local tb = lbl.TextBounds
        local crit = e.Crit and not e.Dot
        local ghost = box:FindFirstChild("Ghost")
        if ghost then
            ghost.Visible = not e.Dot
            Mirror(ghost, lbl)
            -- (the afterimage trails a beat behind the strike and catches up; a kill tears it away upward)
            local lag = 1 - smooth(pa / 0.3)
            local kt = (e.Killed and e.KillAt) and smooth((os.clock() - e.KillAt) / 0.6) or 0
            ghost.Position = UDim2.fromOffset(math.floor(6 * lag), math.floor(10 * lag - 30 * kt))
            ghost.TextColor3 = P.Violet
            ghost.TextTransparency = math.clamp(alpha + 0.35 + 0.25 * (1 - lag) + 0.5 * kt, 0, 1)
        end
        local seal = box:FindFirstChild("Seal")
        if seal then
            seal.Visible = crit
            if crit then
                local k = smooth(age / 0.12)
                local d = (math.max(tb.X, tb.Y) + 22) * (1.5 - 0.5 * k)
                seal.Size = UDim2.fromOffset(math.floor(d), math.floor(d)); seal.Rotation = age * 60
                local tr = math.clamp(alpha + 0.25 + 0.4 * smooth((age - 0.4) / 0.4), 0, 1)
                local st = seal.Ring:FindFirstChildOfClass("UIStroke"); if st then st.Color = P.Crimson; st.Transparency = tr end
                for i = 1, 8 do
                    local t = seal:FindFirstChild("T" .. i)
                    if t then
                        local a = math.rad(i * 45)
                        Seg(t, d / 2 + math.cos(a) * d * 0.5, d / 2 + math.sin(a) * d * 0.5, d / 2 + math.cos(a) * d * 0.62, d / 2 + math.sin(a) * d * 0.62, 2)
                        t.BackgroundColor3 = P.Violet; t.BackgroundTransparency = tr
                    end
                end
            end
        end
    end
    T.InfernalPact = { Clean = CL, Numbers = { Font = "GrenzeGotisch", Glyph = "", NoBang = true, Motion = Motion, Accent = Accent, AccentStep = AccentStep, -- (the face has no cross glyph)
        Normal = P.Text, Crit = P.Crimson:Lerp(WHITE, 0.15), Weak = P.Violet:Lerp(WHITE, 0.2), Stroke = C(20, 0, 14), StrokeThick = 2, Size = 1.08 } }
end

return T
