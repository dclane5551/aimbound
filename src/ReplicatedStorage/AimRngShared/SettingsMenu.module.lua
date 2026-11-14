--!nocheck
-- The Settings window (client UI, UIStyle look). Every row is generated from GameSettings.Defs, edits go
-- through GameSettings.Set (which saves), and every row listens for changes so presets / loading / reset
-- show up immediately.
--
--   local frame = SettingsMenu.Build(parentFolder, { PlayClick = fn, OnClose = fn })
--   SettingsMenu.DrawCrosshair(pieces)  -- pieces = { Dot, L, R, T, B } Frames (used by the HUD too)
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local GameSettings = require(script.Parent:WaitForChild("GameSettings"))
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))

local SettingsMenu = {}
-- "button" rows call SettingsMenu.Actions[def.Action]() (set by the client, e.g. Actions.BarStyles opens that window)
SettingsMenu.Actions = {}

local S = UIStyle.Colors
local C = { -- (Update 5: neutral wells, the brand accent on sliders, steel arrows)
    Accent = S.Accent,
    Text = S.Text,
    Sub = S.Sub,
    Track = S.Well,
    Field = S.Well,
    Off = S.Off,
    On = S.Text, -- (UI CLEAN R-A: a switch that is on = the off-white accent, not green)
    Warn = S.Gold,
    Arrow = S.Steel,
}
-- (UI CLEAN R-A, AimRngShared/MenuKit: the target's language -- rows are open lines split by hairlines (no slabs), word tabs with a
-- left tick, flat square controls: a 4 px track with an off-white fill + a small square knob, square fields with a 1 px line,
-- a square switch. No gradients, no thick strokes, no pills.)
local MenuKit = require(script.Parent:WaitForChild("MenuKit"))
local function Line1(o: Instance) local st = Instance.new("UIStroke"); st.Color = S.Text; st.Transparency = 0.84; st.Thickness = 1; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = o; return st end
local New, Text = UIStyle.New, UIStyle.Text
local Corner, Stroke = UIStyle.Corner, UIStyle.Stroke
local function Tween(inst: Instance, t: number, props: { [string]: any })
    TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out), props):Play()
end

---------------------------------------------------------------------------------------------------
-- Crosshair drawing (shared with the HUD crosshair)
---------------------------------------------------------------------------------------------------
function SettingsMenu.DrawCrosshair(p: { [string]: Frame })
    local G = GameSettings.Get
    local col = GameSettings.CrosshairColors[G("CrossColor")] or GameSettings.CrosshairColors.Cyan
    local dot, L, T, gap = G("CrossDot"), G("CrossLength"), G("CrossThickness"), G("CrossGap")
    local alpha = 1 - G("CrossOpacity") / 100
    local outline = G("CrossOutline")
    p.Dot.Visible = dot > 0
    p.Dot.Size = UDim2.fromOffset(dot, dot)
    p.Dot.Position = UDim2.new(0.5, -dot / 2, 0.5, -dot / 2)
    for _, k in ipairs({ "L", "R", "T", "B" }) do p[k].Visible = L > 0 end
    p.L.Size = UDim2.fromOffset(L, T); p.L.Position = UDim2.new(0.5, -gap - L, 0.5, -T / 2)
    p.R.Size = UDim2.fromOffset(L, T); p.R.Position = UDim2.new(0.5, gap, 0.5, -T / 2)
    p.T.Size = UDim2.fromOffset(T, L); p.T.Position = UDim2.new(0.5, -T / 2, 0.5, -gap - L)
    p.B.Size = UDim2.fromOffset(T, L); p.B.Position = UDim2.new(0.5, -T / 2, 0.5, gap)
    for _, k in ipairs({ "Dot", "L", "R", "T", "B" }) do
        local f = p[k]
        f.BackgroundColor3 = col
        f.BackgroundTransparency = alpha
        f.BorderSizePixel = 0
        local s = f:FindFirstChild("CrossOutline") or New("UIStroke", { Name = "CrossOutline", Color = Color3.new(0, 0, 0), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
        s.Enabled = outline
        s.Transparency = 0.45 + alpha * 0.55
    end
    local corner = p.Dot:FindFirstChild("DotRound") or New("UICorner", { Name = "DotRound", CornerRadius = UDim.new(0.5, 0), Parent = p.Dot })
    corner.CornerRadius = UDim.new(0.5, 0)
end

function SettingsMenu.MakeCrosshairPieces(parent: Instance, zindex: number?): { [string]: Frame }
    local p = {}
    for _, k in ipairs({ "Dot", "L", "R", "T", "B" }) do
        p[k] = New("Frame", { Name = "Cross" .. k, BorderSizePixel = 0, ZIndex = zindex or 1, Parent = parent })
    end
    return p
end

---------------------------------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------------------------------
local activeSlider: any = nil -- one drag at a time, handled by a single InputChanged connection
local capturingKey: any = nil

local function SliderControl(area: Frame, d: any, click: () -> ())
    -- (the track stays a 16 px tall hit area; the visible bar is 4 px inside it)
    local track = New("TextButton", { Name = "Track", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -96, 0, 16), Position = UDim2.new(0, 4, 0.5, -8), Parent = area })
    New("Frame", { Name = "Bar", BackgroundColor3 = S.Text, BackgroundTransparency = 0.86, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 4), Parent = track })
    local fill = New("Frame", { BackgroundColor3 = S.Text, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 0, 0, 4), BorderSizePixel = 0, Parent = track })
    local knob = New("Frame", { BackgroundColor3 = S.Text, BorderSizePixel = 0, Size = UDim2.fromOffset(12, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), ZIndex = 2, Parent = track })
    local box = New("TextBox", {
        Name = "Value", BackgroundColor3 = C.Field, BackgroundTransparency = 0.3, BorderSizePixel = 0, Size = UDim2.fromOffset(78, 32), Position = UDim2.new(1, -78, 0.5, -16),
        Font = UIStyle.Font, TextSize = 15, TextColor3 = C.Text, ClearTextOnFocus = false, Text = "", Parent = area,
    })
    Line1(box)
    UIStyle.TextRole(box, "Value")

    local function Show(v)
        local rel = (v - d.Min) / (d.Max - d.Min)
        fill.Size = UDim2.new(rel, 0, 0, 4)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        if not box:IsFocused() then box.Text = GameSettings.Format(d.Key, v) end
    end
    GameSettings.OnChanged(d.Key, Show)

    local function SetFromX(x: number)
        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
        GameSettings.Set(d.Key, d.Min + rel * (d.Max - d.Min))
    end
    track.MouseButton1Down:Connect(function(x) activeSlider = SetFromX; SetFromX(x) end)
    knob.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then activeSlider = SetFromX end
    end)
    box.FocusLost:Connect(function()
        local n = tonumber((box.Text:gsub("[^%d%.%-]", "")))
        if n then GameSettings.Set(d.Key, n) end
        box.Text = GameSettings.Format(d.Key, GameSettings.Get(d.Key))
    end)
end

local function ToggleControl(area: Frame, d: any, click: () -> ())
    local pill = New("TextButton", { Name = "Switch", Text = "", AutoButtonColor = false, BorderSizePixel = 0, Size = UDim2.fromOffset(52, 26), Position = UDim2.new(1, -52, 0.5, -13), BackgroundColor3 = C.Off, Parent = area })
    Line1(pill)
    local knob = New("Frame", { Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0, 3, 0.5, -10), BorderSizePixel = 0, BackgroundColor3 = S.Sub, Parent = pill })
    local lbl = Text({ Size = UDim2.new(1, -64, 1, 0), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.Sub, Parent = area })
    UIStyle.TextRole(lbl, "Label")
    UIStyle.Hover(pill, 0.06)
    GameSettings.OnChanged(d.Key, function(v)
        TweenService:Create(pill, TweenInfo.new(0.15), { BackgroundColor3 = v and C.On or C.Off }):Play()
        knob.BackgroundColor3 = v and S.Bg0 or S.Sub
        TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Position = v and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10) }):Play()
        lbl.Text = v and "ON" or "OFF"
        lbl.TextColor3 = v and S.Text or C.Sub
    end)
    pill.MouseButton1Click:Connect(function()
        click()
        GameSettings.Set(d.Key, not GameSettings.Get(d.Key))
    end)
end

local function ChoiceControl(area: Frame, d: any, click: () -> ())
    local left = UIStyle.Button(area, "<", C.Arrow, UDim2.fromOffset(36, 34), UDim2.new(0, 0, 0.5, -17), "Prev")
    local right = UIStyle.Button(area, ">", C.Arrow, UDim2.fromOffset(36, 34), UDim2.new(1, -36, 0.5, -17), "Next")
    local mid = New("TextButton", { Name = "Value", AutoButtonColor = false, BackgroundColor3 = C.Field, BackgroundTransparency = 0.3, BorderSizePixel = 0, Size = UDim2.new(1, -86, 0, 34), Position = UDim2.new(0, 43, 0.5, -17),
        Font = UIStyle.Font, TextSize = 15, TextColor3 = C.Text, Parent = area })
    Line1(mid)
    UIStyle.TextRole(mid, "Value")
    -- dots under the value: which option of how many
    local dots = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 1, -7), Parent = mid }, {
        New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 3) }),
    })
    local dotFrames = {}
    for i = 1, #d.Options do
        dotFrames[i] = New("Frame", { Size = UDim2.fromOffset(6, 2), BackgroundColor3 = S.Line, BorderSizePixel = 0, LayoutOrder = i, Parent = dots })
    end
    GameSettings.OnChanged(d.Key, function(v)
        mid.Text = v
        if d.Key == "CrossColor" or d.Key == "EnemyOutlineColor2" then
            mid.TextColor3 = GameSettings.CrosshairColors[v] or C.Text
        end
        local idx = table.find(d.Options, v) or 1
        for i, f in ipairs(dotFrames) do f.BackgroundColor3 = (i == idx) and S.Text or S.Line end
    end)
    local function Step(dir: number)
        click()
        local idx = table.find(d.Options, GameSettings.Get(d.Key)) or 1
        idx = (idx - 1 + dir) % #d.Options + 1
        GameSettings.Set(d.Key, d.Options[idx])
    end
    left.Button.MouseButton1Click:Connect(function() Step(-1) end)
    right.Button.MouseButton1Click:Connect(function() Step(1) end)
    mid.MouseButton1Click:Connect(function() Step(1) end)
end

local function KeyControl(area: Frame, d: any, click: () -> ())
    local b = UIStyle.Button(area, "", S.Steel, UDim2.fromOffset(160, 34), UDim2.new(1, -160, 0.5, -17), "Bind")
    local function Show()
        if capturingKey and capturingKey.Key == d.Key then
            b.SetText("PRESS A KEY...")
            b.SetColor(S.Accent)
        else
            b.SetText(string.upper(GameSettings.KeyLabel(GameSettings.Get(d.Key))))
            b.SetColor(S.Steel)
        end
    end
    GameSettings.OnChanged(d.Key, Show)
    b.Button.MouseButton1Click:Connect(function()
        click()
        local prev = capturingKey
        capturingKey = { Key = d.Key, Refresh = Show }
        if prev and prev.Refresh then prev.Refresh() end
        Show()
    end)
end

-- True while the Controls tab is waiting for a key: the game's own keybind handler should ignore input.
-- (Also true for a moment after the key was taken, since the game's handler may run after ours.)
local capturedAt = 0
function SettingsMenu.IsCapturingKey(): boolean
    return capturingKey ~= nil or os.clock() - capturedAt < 0.2
end

UserInputService.InputChanged:Connect(function(inp)
    -- (2026-10-13: touch drags too -- on a phone the sliders only took a tap, a drag did nothing)
    if activeSlider and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then activeSlider(inp.Position.X) end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then activeSlider = nil end
end)
UserInputService.InputBegan:Connect(function(inp)
    if not capturingKey then return end
    -- a key, or a mouse button (left / right / middle)
    local isMouse = GameSettings.MouseBinds[inp.UserInputType.Name] == true
    if inp.UserInputType ~= Enum.UserInputType.Keyboard and not isMouse then return end
    local cap = capturingKey
    capturingKey = nil
    capturedAt = os.clock()
    local name = isMouse and inp.UserInputType.Name or inp.KeyCode.Name
    if inp.KeyCode ~= Enum.KeyCode.Escape and not GameSettings.ReservedKeys[name] then
        GameSettings.Set(cap.Key, name)
    end
    cap.Refresh()
end)

---------------------------------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------------------------------
local TAB_COLORS = {
    Gameplay = S.Blue, Video = S.Purple, Audio = S.Green, Interface = S.Orange,
    Crosshair = S.Pink, Enemies = S.Red, Controls = S.Gold,
}

function SettingsMenu.Build(parent: Instance, opts: any): Frame
    opts = opts or {}
    local click = opts.PlayClick or function() end

    local root = UIStyle.Panel(parent, { Name = "SetMenu", Size = UDim2.fromOffset(900, 620), Accent = S.Blue })
    -- keep the window on screen on small displays (interface scale also shrinks it)
    local fit = New("UIScale", { Name = "FitScale", Parent = root })
    root:SetAttribute("PhoneMinH", 300) -- (sidebar + pages scroll on their own: a phone gets a window its own height)
    local function Fit()
        -- (UI CLEAN R-A2, main: "the settings scroll area stops ~120 px above the bottom" -- in the full-screen menu the window
        -- is as tall as the room under the top bar (to the bottom margin), so the pages run to the bottom; phones keep 620)
        local H = 620
        if UIStyle.MENU_WINDOWS and UIStyle.MENU_WINDOWS.SetMenu and not UIStyle.IsPhone() and workspace.CurrentCamera then
            local gui = parent:FindFirstAncestorWhichIsA("ScreenGui")
            local sc = gui and gui:FindFirstChildOfClass("UIScale")
            local k = math.max(sc and sc.Scale or 1, 0.05)
            local V = workspace.CurrentCamera.ViewportSize.Y / k
            local B = math.floor(UIStyle.TopInset() * UIStyle.SimK() / k + 0.5) + (UIStyle.MENU_TOP_H or 64)
            H = math.clamp(math.floor(V - B + 66 - 24 - (UIStyle.MARGIN or 16)), 620, 1000)
        end
        if root.Size.Y.Offset ~= H then root.Size = UDim2.fromOffset(900, H) end
        UIStyle.Fit(root, fit, 900, H, 40) -- (phones: fit the width, as tall as the screen: PhoneMinH)
    end
    Fit()
    if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Fit) end
    root:GetPropertyChangedSignal("Visible"):Connect(function() if root.Visible then Fit() end end)

    local defaultStatus = "Changes apply instantly and save to your profile."
    local _, status = UIStyle.TitleBar(root, "SETTINGS", S.Blue, defaultStatus, function()
        click()
        if opts.OnClose then opts.OnClose() end
    end)
    local statusColor = status.TextColor3

    -- saved indicator
    local statusToken = 0
    GameSettings.OnChanged("*", function()
        statusToken += 1
        local my = statusToken
        status.Text = "Saving..."
        status.TextColor3 = C.Warn
        task.delay(1.8, function()
            if my ~= statusToken then return end
            status.Text = "Saved to your profile"
            status.TextColor3 = S.Good
            task.delay(2.5, function()
                if my ~= statusToken then return end
                status.Text = defaultStatus
                status.TextColor3 = statusColor
            end)
        end)
    end)

    -- sidebar
    local side = UIStyle.Card(root, { Name = "Sidebar", Position = UDim2.fromOffset(14, 78), Size = UDim2.new(0, 206, 1, -92) })
    -- (UI v4 LAYOUT: the nav floats on the window -- no card round it, so it isn't a box of boxes)
    side.BackgroundTransparency = 1
    do local ss = side:FindFirstChildOfClass("UIStroke"); if ss then ss.Transparency = 1 end end
    -- (2026-10-13 phones: the tabs scroll inside the card -- on a phone the window is only as tall as the screen)
    local sideList = New("ScrollingFrame", { Name = "Tabs", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
        ScrollBarThickness = 4, ScrollBarImageColor3 = S.Sub, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, Parent = side })
    New("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = sideList })
    New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sideList })

    -- content
    local content = New("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(232, 78), Size = UDim2.new(1, -246, 1, -92), Parent = root })
    local tabTitle = Text({ Position = UDim2.fromOffset(6, 2), Size = UDim2.new(1, -200, 0, 38), TextSize = UIStyle.Size.Title, Parent = content })
    UIStyle.TextRole(tabTitle, "Title")
    local resetBtn = UIStyle.Button(content, "RESET TAB", S.Steel, UDim2.fromOffset(140, 38), UDim2.new(1, -144, 0, 2), "ResetTab")
    resetBtn.Label.TextSize = 14

    local pages = {}
    local tabButtons = {}
    local currentTab = nil

    local BuildRows: (string) -> () -- (below: a tab's rows are built the first time it is shown)
    local function SelectTab(id: string)
        BuildRows(id)
        currentTab = id
        for tid, page in pairs(pages) do
            page.Visible = (tid == id)
            if tid == id then page.CanvasPosition = Vector2.zero end
        end
        -- (Update 5: the selected tab is the accent slab, the rest neutral -- one colour means "selected")
        for tid, b in pairs(tabButtons) do
            b.SetSelected(tid == id, "Left") -- (v4: a neon mark + bright label, not a filled slab)
            local icon = b.Button:FindFirstChild("TabIcon")
            if icon then icon.ImageColor3 = (tid == id) and S.Text or S.Muted end
        end
        for _, t in ipairs(GameSettings.Tabs) do
            if t.Id == id then
                tabTitle.Text = string.upper(t.Label)
                tabTitle.TextColor3 = S.Text
            end
        end
    end
    resetBtn.Button.MouseButton1Click:Connect(function()
        click()
        if currentTab then GameSettings.ResetTab(currentTab) end
    end)

    for i, tab in ipairs(GameSettings.Tabs) do
        local b = UIStyle.Button(sideList, string.upper(tab.Label), S.Bg2, UDim2.new(1, 0, 0, 40), nil, "Tab_" .. tab.Id)
        b.Button.LayoutOrder = i
        b.Label.TextXAlignment = Enum.TextXAlignment.Left
        MenuKit.WordTab(b, "Left") -- (UI CLEAN R-A: words + a 2 px left tick on the selected one, no slab)
        -- (0.61f) custom tab icon instead of a Roblox emoji
        New("UIPadding", { PaddingLeft = UDim.new(0, UIStyle.HasIcon(tab.IconKey) and 46 or 14), Parent = b.Label })
        if UIStyle.HasIcon(tab.IconKey) then
            UIStyle.Icon(tab.IconKey, { Name = "TabIcon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(28, 28), ZIndex = b.Label.ZIndex, Parent = b.Button })
        end
        tabButtons[tab.Id] = b
        b.Button.MouseButton1Click:Connect(function() click(); SelectTab(tab.Id) end)

        local page = New("ScrollingFrame", {
            Name = tab.Id, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50),
            ScrollBarThickness = 6, ScrollBarImageColor3 = S.Sub, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false, Parent = content,
        }, {
            New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
            New("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 12) }),
        })
        pages[tab.Id] = page

        if tab.Id == "Crosshair" then
            -- live preview on a split dark/bright backdrop (shows why the outline matters)
            local prev = UIStyle.Card(page, { Name = "Preview", Size = UDim2.new(1, 0, 0, 140), LayoutOrder = 0, ClipsDescendants = true })
            New("Frame", { BorderSizePixel = 0, Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromScale(0.5, 0), BackgroundColor3 = Color3.fromRGB(196, 206, 214), Parent = prev }, {
                New("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(160, 175, 190), Color3.fromRGB(235, 225, 205)), Rotation = 90 }),
            })
            Text({ Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(200, 20), TextSize = 16, Text = "PREVIEW", Stroke = 1.5, Parent = prev })
            local holder = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.5, 1), Parent = prev })
            local pieces = SettingsMenu.MakeCrosshairPieces(holder, 3)
            local holder2 = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0), Parent = prev })
            local pieces2 = SettingsMenu.MakeCrosshairPieces(holder2, 3)
            for _, k in ipairs({ "CrossColor", "CrossDot", "CrossLength", "CrossThickness", "CrossGap", "CrossOutline", "CrossOpacity" }) do
                GameSettings.OnChanged(k, function()
                    SettingsMenu.DrawCrosshair(pieces)
                    SettingsMenu.DrawCrosshair(pieces2)
                end)
            end
        end
    end

    -- rows (optimization pass 2026-10-27: ~1,700 UI objects for every tab were built at join; now each tab's rows are
    -- built the first time that tab is shown -- nothing outside this menu looks the rows up)
    local builtTabs = {}
    BuildRows = function(tabId: string)
        if builtTabs[tabId] then return end
        builtTabs[tabId] = true
        for _, d in ipairs(GameSettings.Defs) do
            local page = pages[d.Tab]
            if page and d.Tab == tabId then
                local hasHint = d.Hint and d.Hint ~= ""
                -- (Update 5 type scale: label Subhead 18, hint Caption 13 -- it was 12)
                local row = UIStyle.Card(page, { Name = "Row_" .. d.Key, Size = UDim2.new(1, 0, 0, hasHint and 68 or 48), LayoutOrder = d.Order })
                -- (UI CLEAN R-A: an open line -- no slab, one hairline under it; the name in body Text, the hint Meta)
                MenuKit.Flat(row)
                New("Frame", { Name = "KitRule", BackgroundColor3 = S.Text, BackgroundTransparency = 0.9, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
                    Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), Parent = row })
                local nm = Text({ Position = UDim2.fromOffset(4, hasHint and 10 or 0), Size = UDim2.new(1, -350, 0, hasHint and 22 or 48), TextSize = 15, Text = d.Label, Parent = row })
                UIStyle.TextRole(nm, "Body"); nm.TextSize = 15
                if hasHint then
                    local ht = Text({ Font = UIStyle.BodyFont, Position = UDim2.fromOffset(4, 32), Size = UDim2.new(1, -350, 0, 32), TextSize = 13, TextColor3 = C.Sub,
                        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Text = d.Hint, Parent = row })
                    UIStyle.TextRole(ht, "Meta")
                    -- (UI CLEAN audit: long hints were cut at 2 lines -- the row grows to fit, 68 at least)
                    ht.Size = UDim2.new(1, -350, 0, 0); ht.AutomaticSize = Enum.AutomaticSize.Y
                    New("UIPadding", { PaddingBottom = UDim.new(0, 10), Parent = ht })
                    row.AutomaticSize = Enum.AutomaticSize.Y
                end
                local area = New("Frame", { Name = "Control", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(320, 40), Parent = row })
                if d.Type == "slider" then SliderControl(area, d, click)
                elseif d.Type == "toggle" then ToggleControl(area, d, click)
                elseif d.Type == "choice" then ChoiceControl(area, d, click)
                elseif d.Type == "key" then KeyControl(area, d, click)
                elseif d.Type == "button" then
                    -- (UI CLEAN audit: opening an editor is a secondary action -- the page has no primary)
                    local b = UIStyle.Button(area, d.Button or "OPEN", S.Bg1, UDim2.fromOffset(160, 36), UDim2.new(1, -160, 0.5, -18), "Open")
                    b.Button.MouseButton1Click:Connect(function()
                        click()
                        local fn = SettingsMenu.Actions[d.Action]
                        if fn then fn() end
                    end)
                end
            end
        end

        -- Controls footnote
        if tabId == "Controls" and pages.Controls then
            Text({
                Font = UIStyle.BodyFont, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 10000, TextSize = 13,
                TextColor3 = C.Sub, TextWrapped = true,
                Text = "Click a binding, then press the new key (Esc cancels). Binding a key that's already used swaps the two. Left mouse fires, right mouse aims.",
                Parent = pages.Controls,
            })
        end
    end

    SelectTab("Gameplay")
    if game:GetService("RunService"):IsStudio() then -- (Studio test hook: window attr DevTab = a tab id selects it, no mouse needed)
        root:GetAttributeChangedSignal("DevTab"):Connect(function()
            local t = root:GetAttribute("DevTab")
            if type(t) == "string" and pages[t] then SelectTab(t) end
        end)
    end
    return root
end

return SettingsMenu
