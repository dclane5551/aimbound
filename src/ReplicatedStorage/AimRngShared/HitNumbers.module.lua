--!nocheck
-- HIT NUMBERS v2 (0.58, owner: "Hit numbers need a complete revamp and should be customized by the UI chosen").
-- Client only. HitNumbers.Show(amount, worldPos, { Weak, Crit, Kind, Culled, Elem, Killed, Target }):
--   * hits on the same enemy (Target = the server's per-enemy key; else the same spot) within MERGE_WINDOW stack into
--     ONE number that grows, re-pops and follows the newest hit (full-auto no longer sprays a cloud of numbers);
--     weak-spot and body hits stack apart (each number keeps the look of the hits in it);
--     damage-over-time ticks stack separately in their element colour
--   * a pop on every hit (bounce / slam / glitch / implode, by theme), crits shake, weak spots get the theme's glyph, a
--     kill punches the final number up, the element matchup shows as ▲ / ▼
--   * STYLE = the equipped UI theme (UITheme.Current()): recolours colour the numbers from their Text / Accent /
--     Accent2 / Panel; premium themes add theme.Numbers = { Font, Normal, Crit, Weak, Stroke, Glyph, Pop, Rainbow }
--   * SCREEN-SPACE labels in one ScreenGui (DisplayOrder -1: under every menu, like the enemy bars), pooled (MAX live),
--     placed by one RenderStepped loop: no parts per hit. (AlwaysOnTop BillboardGuis did not draw at all in Studio
--     captures -- measured 2026-10-06 -- and depth-tested ones clip into big enemies.)
--   * (v3, FX AUDIT 2026-10-14, owner: "the damage numbers ... everything feels incredibly samey"): a bundle's numbers can
--     carry their own MOTION and ACCENT, not just a colour -- theme.Numbers fields (all optional, old themes unchanged):
--       Motion = "Drift" (no pop: fades in, rises with a firefly wobble, blinks on each merged hit) | "Tick" (an instrument
--         readout: steps up in three detents, digits count up, no scale) | "Stamp" (slams down into place from above, a
--         1 px shake, rises slowly);  Count = true (the digits roll up to the new total);  Bar = { Color } (a meter bar
--         under the number that refills on every hit);  Shine = { a, b } (an iridescent sweep across the digits);
--         Cool = { Hot, Iron } (the number is struck white-hot and cools to iron over its life);  CritGlyph (a mark in
--         front of crits).  Everything stays in one pooled ScreenGui and one RenderStepped, and keeps the KEEP_OUT.
--       Motion may also be a FUNCTION motion(e, age, pa, life) -> up, side, scale, dy, alpha, rot (any nil = default):
--         up / side in studs (side along the camera's right), scale (1 = normal), dy in pixels (+ = down), alpha 0..1
--         (0 = solid; the end fade still applies on top), rot in degrees. age = seconds since it appeared, pa = since the
--         last merged hit, life = its lifetime. e: Crit, Weak, Killed, Dot, Count, Amount, Seed (0..2pi), Label, Holder,
--         Stroke, Color. KEEP_OUT is applied AFTER the motion.  Italic = true (an italic face).
--       Accent(e) -> Instance: made once per pooled label (parent it to e.Holder or return it unparented), hidden when
--         another style reuses the label, shown again for every new number of this style;
--       AccentStep(e, inst, age, pa, alpha) every frame (alpha = the label's current transparency).
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Shared = script.Parent
local UITheme = require(Shared:WaitForChild("UITheme"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local DamageTypes = require(Shared:WaitForChild("DamageTypes")) -- (UPDATE 8 OFFENSE: numbers coloured by the hit's main type)

local HitNumbers = {}
local MAX = 24
local LIFE, LIFE_DOT = 0.85, 0.6
local MERGE_WINDOW, MERGE_DIST = 0.45, 4
local KIND_COLORS = {
    Burn = Color3.fromRGB(255, 140, 50), Bleed = Color3.fromRGB(230, 50, 70), Freeze = Color3.fromRGB(130, 215, 255),
    Explosion = Color3.fromRGB(255, 190, 70), Arc = Color3.fromRGB(150, 200, 255), Shatter = Color3.fromRGB(180, 235, 255),
}
local DEFAULT = {
    Normal = Color3.fromRGB(255, 255, 255), Crit = Color3.fromRGB(255, 214, 60), Weak = Color3.fromRGB(255, 70, 60),
    Stroke = Color3.fromRGB(12, 10, 14), Glyph = "◆", Pop = "Bounce",
}

local gui
local pool, live = {}, {}
local MAX_DIST = 400
-- (0.78, owner: "Text should NEVER appear in front of the crosshair, you can easily lose it"): a keep-out square round the
-- screen centre (px each side, plus the label's own half size). A number that would land in it is pushed out above /
-- below it.
HitNumbers.KEEP_OUT = 44

local function Make()
    if not gui or not gui.Parent then
        gui = Instance.new("ScreenGui")
        gui.Name = "HitNumbers"; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false; gui.DisplayOrder = -1
        gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    local holder = Instance.new("Frame")
    holder.Name = "HitNumber"; holder.BackgroundTransparency = 1; holder.AnchorPoint = Vector2.new(0.5, 0.5); holder.Size = UDim2.fromOffset(220, 56)
    holder.Visible = false
    holder.Parent = gui
    local sc = Instance.new("UIScale"); sc.Parent = holder
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1; lbl.Size = UDim2.fromScale(1, 1); lbl.TextSize = 24; lbl.RichText = false
    lbl:SetAttribute("KeepFont", true) -- (the UI type system leaves it alone: the theme picks the face here)
    lbl.Parent = holder
    local stroke = Instance.new("UIStroke"); stroke.Thickness = 2; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; stroke.Parent = lbl
    return { Holder = holder, Scale = sc, Label = lbl, Stroke = stroke }
end
-- (v3) the optional accent pieces, made the first time a style asks for them and hidden otherwise
local function Accents(e: any, st: any)
    if st.Shine and not e.Grad then
        e.Grad = Instance.new("UIGradient"); e.Grad.Parent = e.Label
    end
    if e.Grad then e.Grad.Enabled = st.Shine ~= nil end
    if st.Bar and not e.Bar then
        local b = Instance.new("Frame")
        b.Name = "Bar"; b.BorderSizePixel = 0; b.AnchorPoint = Vector2.new(0.5, 0); b.Position = UDim2.new(0.5, 0, 0.5, 13)
        b.Size = UDim2.fromOffset(0, 4); b.Parent = e.Holder
        local ink = Instance.new("UIStroke"); ink.Thickness = 1.5; ink.Color = Color3.fromRGB(10, 10, 12); ink.Parent = b
        e.Bar = b
    end
    if e.Bar then e.Bar.Visible = st.Bar ~= nil; if st.Bar then e.Bar.BackgroundColor3 = st.Bar.Color or st.Crit end end
    -- (v3 hooks) Numbers.Accent(e) -> Instance: made ONCE per pooled label per Accent function, hidden for other styles
    e.AccentMap = e.AccentMap or {}
    for fn, inst in pairs(e.AccentMap) do if fn ~= st.Accent and inst.Parent then pcall(function() inst.Visible = false end) end end
    e.AccentInst = nil
    if type(st.Accent) == "function" then
        local inst = e.AccentMap[st.Accent]
        if not (inst and inst.Parent) then
            local ok, made = pcall(st.Accent, e)
            inst = (ok and typeof(made) == "Instance") and made or nil
            if not ok then warn("[HitNumbers] Accent: " .. tostring(made)) end
            if inst and not inst.Parent then inst.Parent = e.Holder end
            e.AccentMap[st.Accent] = inst
        end
        if inst then pcall(function() inst.Visible = true end) end
        e.AccentInst = inst
    end
end

-- a Numbers.Font is an Enum.Font name when Roblox has one (FredokaOne, Bangers, Creepster...), else a font family
local faces = {}
local function FaceFor(name: string?, italic: boolean?): Font
    if not name and not italic then return Font.fromEnum(Enum.Font.GothamBlack) end
    local key = (name or "GothamBlack") .. (italic and "/i" or "")
    if faces[key] then return faces[key] end
    local okE, e = pcall(function() return (Enum.Font :: any)[name or "GothamBlack"] end)
    local f = (okE and e) and Font.fromEnum(e) or Font.new("rbxasset://fonts/families/" .. name .. ".json", Enum.FontWeight.Heavy)
    f.Bold = true
    if italic then f.Style = Enum.FontStyle.Italic end
    faces[key] = f
    return f
end

-- (SKIN UI 2026-10-28, owner: "The damage numbers should be unique to the skin and the colorways you have equipped"): the
-- numbers follow the GUN SKIN IN YOUR HANDS first -- SkinFX.CurrentKind ("Silkfang", "Silkfang#2" = its colourway copy, whose
-- palette is already that colourway) -> SkinFX.Sets[kind].Theme.Numbers (or .Numbers); no skin (or a set without numbers) =
-- the equipped UI theme's numbers, else the default. Extra fields: NoBang (no "!" after a crit), StrokeThick, Size (x the
-- base sizes). The style is read when a number appears; merged hits keep it.
local SkinFX -- (lazy: SkinFX is already loaded by ViewmodelRig on the client)
local function SkinNumbers(): any
    if SkinFX == nil then
        local ok, m = pcall(function() return require(Shared:WaitForChild("SkinFX", 2)) end)
        SkinFX = ok and m or false
    end
    local kind = SkinFX and SkinFX.CurrentKind
    if not kind then return nil end
    local ok, set = pcall(function() return SkinFX.Sets[kind] end)
    if not (ok and type(set) == "table") then return nil end
    local n = (type(set.Theme) == "table" and set.Theme.Numbers) or set.Numbers
    return type(n) == "table" and n or nil
end
HitNumbers.SkinNumbers = SkinNumbers
local function StyleNow(): any
    local skinN = SkinNumbers()
    local t = skinN and {} or (UITheme.Current() or {})
    local n = skinN or t.Numbers or {}
    local font = n.Font -- (only the numbers' own face: UI themes don't change the UI's fonts, UIStyle.THEME_FONTS)
    return {
        Face = FaceFor(font, n.Italic == true),
        Normal = n.Normal or t.Text or DEFAULT.Normal,
        Crit = n.Crit or t.Accent or DEFAULT.Crit,
        Weak = n.Weak or t.Accent2 or DEFAULT.Weak,
        Stroke = n.Stroke or (t.Panel and t.Panel.Bottom) or DEFAULT.Stroke,
        Glyph = n.Glyph or DEFAULT.Glyph,
        Pop = n.Pop or DEFAULT.Pop,
        Rainbow = n.Rainbow == true,
        Motion = n.Motion, Accent = n.Accent, AccentStep = n.AccentStep, Count = n.Count == true, Bar = n.Bar, Shine = n.Shine, Cool = n.Cool, CritGlyph = n.CritGlyph,
        NoBang = n.NoBang == true, StrokeThick = n.StrokeThick, Size = n.Size, Skin = skinN ~= nil,
    }
end

local function Paint(e: any)
    local st = e.Style
    local lbl = e.Label
    lbl.FontFace = st.Face
    local text
    if e.Culled then
        text = "EXECUTED"
    else
        -- (PLAYTEST 2026-10-31: a 27,520.1 hit showed its decimal -- FormatNumber keeps one under 100K; only small ticks keep it)
        local amt = (st.Count and e.Shown) and math.floor(e.Shown + 0.5) or e.Amount
        if type(amt) == "number" and math.abs(amt) >= 10 then amt = math.floor(amt + 0.5) end
        text = ItemData.FormatNumber(amt)
        if e.Weak and not e.Dot then text = (st.Glyph ~= "" and (st.Glyph .. " ") or "") .. text
        elseif e.Crit and not e.Dot and st.CritGlyph then text = st.CritGlyph .. " " .. text end
        if e.Crit and not e.Dot and not st.CritGlyph and not st.NoBang then text ..= "!" end
        if e.Elem == "Strong" then text ..= " ▲" elseif e.Elem == "Weak" then text ..= " ▼" end
    end
    lbl.Text = text
    local col
    if e.Culled then col = Color3.fromRGB(255, 215, 90)
    elseif e.Dot then col = KIND_COLORS[e.Kind] or st.Normal
    elseif e.DType and e.DType ~= "Kinetic" and DamageTypes.COLOR[e.DType] then col = DamageTypes.COLOR[e.DType] -- (UPDATE 8: Heat / Cryo / Volt / Void; crits + weak spots keep their glyph + size)
    elseif e.Weak then col = st.Weak
    elseif e.Crit then col = st.Crit
    else col = st.Normal end
    e.Color = col
    lbl.TextColor3 = col
    if e.Grad and st.Shine then
        -- (an iridescent sweep: the digits keep their hit colour in the middle, the two shine colours at the edges)
        local a, b = st.Shine[1], st.Shine[2] or st.Shine[1]
        lbl.TextColor3 = Color3.new(1, 1, 1)
        e.Grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, col:Lerp(a, 0.65)), ColorSequenceKeypoint.new(0.5, col),
            ColorSequenceKeypoint.new(1, col:Lerp(b, 0.65)) })
    end
    e.Stroke.Color = st.Stroke
    e.Stroke.Thickness = st.StrokeThick or 2
    local size = e.Culled and 26 or (e.Dot and 17 or (e.Weak and 30 or (e.Crit and 28 or 24)))
    lbl.TextSize = math.floor((size + math.min(4, (e.Count - 1) * 0.35)) * (st.Size or 1) + 0.5)
end

local function Recycle(e: any, i: number?)
    e.Holder.Visible = false
    if i then table.remove(live, i) else
        local k = table.find(live, e)
        if k then table.remove(live, k) end
    end
    table.insert(pool, e)
end

function HitNumbers.Show(amount: number, pos: Vector3, o: any?)
    o = o or {}
    local now = os.clock()
    local kind = o.Kind or "Hit"
    local dot = kind ~= "Hit" and kind ~= "Melee"
    if not o.Culled then
        for _, e in ipairs(live) do
            local same = (o.Target ~= nil and e.Target == o.Target) or (o.Target == nil and (e.Anchor - pos).Magnitude < MERGE_DIST)
            -- (head and body hits stack separately: a merged head number kept its look on the body hits after it)
            if e.Kind == kind and not e.Culled and now - e.LastHit < MERGE_WINDOW and same and (not e.Weak) == (not o.Weak) then
                e.Amount += amount
                e.World = e.World:Lerp(pos, 0.5) -- (drifts after a moving target)
                e.LastHit, e.Bump, e.BumpAmp = now, now, 0.35 -- (a merged hit only nudges: re-popping at 10 shots/s pulsed)
                e.Crit = e.Crit or o.Crit
                e.Elem = o.Elem or e.Elem
                e.DType = o.DType or e.DType
                e.Count += 1
                e.From, e.FromAt = e.Shown or e.Amount, now
                if o.Killed then e.Killed = true; e.KillAt = now end
                e.Expire = now + (dot and LIFE_DOT or LIFE) * ((RunService:IsStudio() and tonumber(Workspace:GetAttribute("DevNumLife"))) or 1)
                Paint(e)
                return
            end
        end
    end
    if #live >= MAX then Recycle(live[1], 1) end
    local e = table.remove(pool) or Make()
    e.Style = StyleNow()
    Accents(e, e.Style)
    e.Amount, e.Kind, e.Dot, e.Count = amount, kind, dot, 1
    e.Shown, e.From, e.FromAt, e.Seed = (e.Style.Count and 0 or amount), 0, now, math.random() * 6.28
    e.Crit, e.Weak, e.Culled, e.Elem = o.Crit, o.Weak, o.Culled, o.Elem
    e.DType = o.DType -- (UPDATE 8 OFFENSE)
    e.Killed, e.KillAt = o.Killed, o.Killed and now or nil
    e.Born, e.LastHit, e.Bump, e.BumpAmp = now, now, now, 1
    e.Expire = now + (dot and LIFE_DOT or LIFE) * ((RunService:IsStudio() and tonumber(Workspace:GetAttribute("DevNumLife"))) or 1) -- (Studio: hold numbers for screenshots)
    e.Anchor, e.Target = pos, o.Target
    e.Lane = 0 -- (a head number and a body number on one enemy: the newer sits one line above, not on top of the other)
    if not dot then
        local used = {}
        for _, x in ipairs(live) do
            if not x.Dot and x.Kind == kind and ((o.Target ~= nil and x.Target == o.Target) or (o.Target == nil and (x.Anchor - pos).Magnitude < MERGE_DIST)) then used[x.Lane or 0] = true end
        end
        while used[e.Lane] and e.Lane < 2 do e.Lane += 1 end
    end
    e.DriftX = (math.random() - 0.5) * (dot and 1.6 or 1.0)
    e.World = pos + (dot and Vector3.new((math.random() - 0.5) * 1.6, math.random() * 0.8, (math.random() - 0.5) * 1.6) or Vector3.zero)
    e.Holder.Rotation = 0
    e.Label.TextTransparency = 0
    Paint(e)
    table.insert(live, e)
end

-- (0.97, owner: "Damage numbers POP way too much"): every style keeps its character at about a third of the punch;
-- amp = 1 for a new number, 0.35 for a hit merged into one
local function PopScale(kind: string, pa: number, amp: number): number
    if kind == "Slam" then
        if pa < 0.07 then return 1 + amp * (0.25 - (pa / 0.07) * 0.25) end
        return 1
    elseif kind == "Implode" then
        if pa < 0.1 then return 1 - amp * 0.2 * (1 - pa / 0.1) end
        return 1
    elseif kind == "Glitch" then
        return 1 + amp * 0.1 * math.exp(-pa * 15)
    end
    return 1 + amp * 0.14 * math.exp(-pa * 14) * math.cos(pa * 22) -- (Bounce)
end

RunService.RenderStepped:Connect(function()
    if #live == 0 then return end
    local now = os.clock()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local camPos, right = cam.CFrame.Position, cam.CFrame.RightVector
    for i = #live, 1, -1 do
        local e = live[i]
        local left = e.Expire - now
        if left <= 0 then Recycle(e, i); continue end
        local age = now - e.Born
        local rise = math.min(1, age / 0.8)
        local ease = 1 - (1 - rise) ^ 3
        local st = e.Style
        local motion = st.Motion
        local up, side = ease * 2.1, e.DriftX * ease
        local custom, cScale, cDy, cAlpha, cRot
        if type(motion) == "function" then
            -- (v3 hook) motion(e, age, pa, life) -> up (studs), side (studs, camera right), scale, dy (px), alpha (0 = solid), rot (deg)
            local ok, u, sd, sc, dyy, al, rot = pcall(motion, e, age, now - e.Bump, e.Expire - e.Born)
            if ok then
                custom = true
                up, side = u or up, sd or side
                cScale, cDy, cAlpha, cRot = sc or 1, dyy or 0, al or 0, rot or 0
            elseif not e.MotionWarned then
                e.MotionWarned = true; warn("[HitNumbers] Motion: " .. tostring(u))
            end
        elseif motion == "Drift" then -- (a firefly: rises less, wobbles side to side)
            up, side = ease * 1.6, e.DriftX * 0.4 * ease + math.sin(age * 9 + e.Seed) * 0.22
        elseif motion == "Tick" then -- (three hard detents, like a needle stepping)
            up, side = math.floor(ease * 3 + 0.0001) / 3 * 1.8, 0
        elseif motion == "Stamp" then -- (struck into place, then a slow lift)
            up, side = ease * 1.1, e.DriftX * 0.3 * ease
        end
        local w = e.World + Vector3.new(0, 1.2 + up, 0) + right * side
        local vp, onScreen = cam:WorldToViewportPoint(w)
        if not onScreen or vp.Z <= 0 or (w - camPos).Magnitude > MAX_DIST then
            e.Holder.Visible = false
            continue
        end
        e.Holder.Visible = true
        local pa = now - e.Bump
        local s, dy, alpha = 1, 0, 0
        if custom then
            s, dy, alpha = cScale, cDy, cAlpha
        elseif motion == "Drift" then
            alpha = math.max(1 - math.min(1, age / 0.08), (pa < 0.09 and pa > 0 and age > 0.1) and 0.45 or 0)
        elseif motion == "Tick" then
            s = 1
        elseif motion == "Stamp" then
            local k = math.min(1, pa / 0.07)
            s = 1 + 0.3 * (e.BumpAmp or 1) * (1 - k)
            dy = -14 * (e.BumpAmp or 1) * (1 - k) * (1 - k)
        else
            s = PopScale(st.Pop, pa, e.BumpAmp or 1)
        end
        if e.KillAt then s *= 1 + 0.12 * math.exp(-(now - e.KillAt) * 8) end
        e.Scale.Scale = s
        if st.Count and e.Shown ~= e.Amount then -- (the digits roll up to the new total over 0.12 s)
            local k = math.min(1, (now - (e.FromAt or now)) / 0.12)
            e.Shown = (e.From or 0) + (e.Amount - (e.From or 0)) * (1 - (1 - k) ^ 2)
            if k >= 1 then e.Shown = e.Amount end
            Paint(e)
        end
        if st.Cool and not e.Dot then -- (struck white-hot, settles to its colour, cools to iron)
            local c = e.Color
            local life = (e.Expire - e.Born)
            if pa < 0.18 then c = st.Cool[1]:Lerp(c, pa / 0.18)
            elseif age > life * 0.45 then c = c:Lerp(st.Cool[2], math.clamp((age - life * 0.45) / (life * 0.5), 0, 0.85)) end
            e.Label.TextColor3 = c
        end
        if e.Bar and st.Bar then
            local tw = e.Label.TextBounds.X
            local k = math.min(1, pa / 0.1)
            e.Bar.Size = UDim2.fromOffset(math.floor(tw * (0.25 + 0.75 * k)), 4)
        end
        if e.Grad and st.Shine then e.Grad.Offset = Vector2.new(math.sin(now * 2.2 + e.Seed) * 0.45, 0) end
        local fade = (left < 0.25) and (1 - left / 0.25) or 0
        local tt = math.max(fade, alpha)
        e.Label.TextTransparency = tt
        e.Stroke.Transparency = (st.StrokeThick and 0 or 0.35) + (st.StrokeThick and 1 or 0.65) * tt
        if e.Bar and st.Bar then e.Bar.BackgroundTransparency = tt end
        if e.AccentInst and type(st.AccentStep) == "function" then
            local ok, err = pcall(st.AccentStep, e, e.AccentInst, age, pa, tt)
            if not ok and not e.AccentWarned then e.AccentWarned = true; warn("[HitNumbers] AccentStep: " .. tostring(err)) end
        end
        if custom then
            e.Holder.Rotation = cRot
        elseif motion == "Tick" or motion == "Drift" then
            if e.Holder.Rotation ~= 0 then e.Holder.Rotation = 0 end
            if motion == "Tick" and e.Crit and not e.Dot and st.CritGlyph then -- (the standby LED in front blinks twice)
                e.Label.TextTransparency = (pa < 0.3 and (pa * 13) % 2 > 1) and math.max(tt, 0.35) or tt
            end
        elseif motion == "Stamp" and pa < 0.12 then
            e.Holder.Rotation = 0
            dy += math.random(-1, 1)
        elseif e.Crit and not e.Dot and pa < 0.2 then
            e.Holder.Rotation = math.sin(pa * 90) * 2 * (1 - pa / 0.2) * (e.BumpAmp or 1)
        elseif e.Holder.Rotation ~= 0 then
            e.Holder.Rotation = 0
        end
        local gx, gy = 0, 0
        if e.Style.Pop == "Glitch" and pa < 0.14 then gx, gy = math.random(-3, 3), math.random(-1, 1) end
        local px, py = vp.X + gx, vp.Y + gy + dy
        if e.Lane and e.Lane > 0 then py -= e.Lane * (e.Label.TextBounds.Y * s + 4) end
        do
            local view = cam.ViewportSize
            local cx, cy = view.X / 2, view.Y / 2
            local tb = e.Label.TextBounds
            local hw, hh = tb.X / 2 * s + HitNumbers.KEEP_OUT, tb.Y / 2 * s + HitNumbers.KEEP_OUT
            if math.abs(px - cx) < hw and math.abs(py - cy) < hh then
                py = (py <= cy) and (cy - hh) or (cy + hh)
            end
        end
        e.Holder.Position = UDim2.fromOffset(px, py)
        if e.Style.Rainbow and (e.Crit or e.Weak) and not e.Dot then
            e.Label.TextColor3 = Color3.fromHSV((now * 0.9 + e.Born) % 1, 0.55, 1)
        end
    end
end)

return HitNumbers
