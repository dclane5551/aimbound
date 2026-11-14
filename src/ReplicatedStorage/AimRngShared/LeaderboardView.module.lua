--!nocheck
-- ============================================================================================
-- LEADERBOARD POPUP (client): the full top-50 view opened by the 🏆 LEADERBOARD buttons in mode windows
-- (Challenges: Daily, Rifts, Aim Trials, Mastery / top levels). Reads ReplicatedStorage.Leaderboards (EndgameServer publishes
-- every board as a JSON StringValue with attributes Id / Title / Kind, refreshed every 60 s). Several boards
-- open as tabs across the top.
--   LeaderboardView.Open(parentFrame, { "RiftWeekly", "RiftHighest" }, startId?, playClick?)
--   LeaderboardView.Button(parent, size, position, ids, startId?, playClick?) -> the 🏆 button
-- ============================================================================================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local C = UIStyle.Colors
local New, Text = UIStyle.New, UIStyle.Text

local LeaderboardView = {}
local KIND_LABEL = { time = "TIME", tier = "TIER", level = "LEVEL", score = "SCORE" }
local MEDAL = { Color3.fromRGB(255, 205, 60), Color3.fromRGB(205, 215, 230), Color3.fromRGB(215, 140, 80) }
local SHORT = { Daily = "DAILY", RiftWeekly = "THIS WEEK", RiftHighest = "ALL TIME", PlayerLevel = "LEVEL" }

local function FindBoard(id: string): StringValue?
    local folder = ReplicatedStorage:FindFirstChild("Leaderboards")
    if not folder then return nil end
    for _, sv in ipairs(folder:GetChildren()) do
        if sv:GetAttribute("Id") == id then return sv end
    end
    return nil
end

local function ShortName(id: string, sv: StringValue?): string
    if SHORT[id] then return SHORT[id] end
    local title = sv and sv:GetAttribute("Title") or id
    return (string.gsub(title, "%s*%(.*%)", ""))
end

function LeaderboardView.Open(parent: Instance, ids: { string }, startId: string?, playClick: (() -> ())?)
    local click = playClick or function() end
    local old = parent:FindFirstChild("LeaderboardPopup")
    if old then old:Destroy() end
    -- dim the window behind; clicking the dimmed area closes the popup
    local overlay = New("TextButton", { Name = "LeaderboardPopup", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.35, ZIndex = 50, Parent = parent }, { UIStyle.Corner(14) })
    overlay:SetAttribute("NoSkin", true)
    local panel = New("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(620, 560),
        BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 51, Parent = overlay }, { UIStyle.Corner(14) })
    UIStyle.Gradient(C.BgTop, C.BgBottom).Parent = panel
    UIStyle.Stroke(C.Gold, 3).Parent = panel
    local title = Text({ Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -90, 0, 36), TextSize = 26, Stroke = 2.5, TextColor3 = C.Gold, ZIndex = 52, Text = "LEADERBOARD", Parent = panel })
    local close = UIStyle.Button(panel, "X", C.Red, UDim2.fromOffset(44, 40), UDim2.new(1, -58, 0, 10))
    close.Button.ZIndex = 52
    for _, d in ipairs(close.Button:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex = 53 end end
    local function Close() click(); overlay:Destroy() end
    close.Button.MouseButton1Click:Connect(Close)
    overlay.MouseButton1Click:Connect(Close)

    local current = startId or ids[1]
    local tabRow = New("Frame", { Position = UDim2.fromOffset(16, 52), Size = UDim2.new(1, -32, 0, 34), BackgroundTransparency = 1, ZIndex = 52, Parent = panel })
    New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = tabRow })
    local hdr = New("Frame", { Position = UDim2.fromOffset(16, 92), Size = UDim2.new(1, -32, 0, 24), BackgroundTransparency = 1, ZIndex = 52, Parent = panel })
    Text({ Size = UDim2.fromOffset(70, 24), Position = UDim2.fromOffset(10, 0), Text = "RANK", TextSize = 14, TextColor3 = C.Sub, ZIndex = 52, Parent = hdr })
    Text({ Size = UDim2.fromOffset(250, 24), Position = UDim2.fromOffset(84, 0), Text = "PLAYER", TextSize = 14, TextColor3 = C.Sub, ZIndex = 52, Parent = hdr })
    local statHdr = Text({ Size = UDim2.fromOffset(160, 24), Position = UDim2.new(1, -176, 0, 0), Text = "SCORE", TextSize = 14, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 52, Parent = hdr })
    local list = New("ScrollingFrame", { Position = UDim2.fromOffset(16, 118), Size = UDim2.new(1, -32, 1, -186), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8,
        ScrollBarImageColor3 = C.Gold, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 52, Parent = panel })
    New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
    local you = Text({ Position = UDim2.new(0, 16, 1, -58), Size = UDim2.new(1, -32, 0, 44), RichText = true, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundTransparency = 0.1, BackgroundColor3 = C.CardDark, ZIndex = 52, Parent = panel })
    New("UICorner", { CornerRadius = UDim.new(0, 10), Parent = you })

    local Render
    local function Tabs()
        for _, c in ipairs(tabRow:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        if #ids < 2 then return end
        -- (2026-10-13, owner: the tabs overlapped -- ten "SERAPH ARCHON TIER I" names in 53 px each): drop the words every
        -- tab shares, so a boss's tier tabs read I .. X and the full name stays in the title
        local names, words = {}, {}
        for i, id in ipairs(ids) do
            names[i] = ShortName(id, FindBoard(id))
            words[i] = {}
            for w in string.gmatch(names[i], "[^%s_]+") do table.insert(words[i], w) end
        end
        local common = 0
        while true do
            local w = words[1][common + 1]
            local same = w ~= nil
            for i = 2, #words do if words[i][common + 1] ~= w or #words[i] <= common + 1 then same = false end end
            if not same or #words[1] <= common + 1 then break end
            common += 1
        end
        if common > 0 then
            for i = 1, #names do names[i] = table.concat(words[i], " ", common + 1) end
        end
        for i, id in ipairs(ids) do
            local on = id == current
            local b = New("TextButton", { Size = UDim2.fromOffset(math.floor((588 - 6 * (#ids - 1)) / #ids), 34), Text = names[i], Font = UIStyle.Font, TextSize = 15,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextColor3 = on and C.Text or C.Sub, BackgroundColor3 = on and UIStyle.Darken(C.Gold, 0.35) or C.CardDark, AutoButtonColor = false, ZIndex = 53, Parent = tabRow }, { UIStyle.Corner(8) })
            b:SetAttribute("NoSkin", true)
            b.MouseButton1Click:Connect(function()
                click()
                current = id
                Tabs()
                Render()
            end)
        end
    end

    Render = function()
        for _, c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local sv = FindBoard(current)
        title.Text = sv and (sv:GetAttribute("Title") or "LEADERBOARD") or "LEADERBOARD"
        statHdr.Text = sv and (KIND_LABEL[sv:GetAttribute("Kind") or ""] or "SCORE") or "SCORE"
        local rows = {}
        if sv then
            local ok, r = pcall(HttpService.JSONDecode, HttpService, sv.Value)
            if ok and type(r) == "table" then rows = r end
        end
        local me = Players.LocalPlayer.UserId
        local mine
        for i, r in ipairs(rows) do
            local isMe = r.UserId == me
            if isMe then mine = r end
            local row = New("Frame", { LayoutOrder = i, Size = UDim2.new(1, -12, 0, 34), BackgroundColor3 = isMe and Color3.fromRGB(40, 70, 110) or ((i % 2 == 0) and C.CardDark or C.Card), ZIndex = 53, Parent = list }, { UIStyle.Corner(8) })
            local medal = MEDAL[r.Rank or i]
            Text({ Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(70, 34), Text = "#" .. tostring(r.Rank or i), TextSize = medal and 20 or 16, Stroke = 1.5, TextColor3 = medal or C.Sub, ZIndex = 54, Parent = row })
            Text({ Position = UDim2.fromOffset(84, 0), Size = UDim2.new(1, -270, 1, 0), Text = tostring(r.Name or "?"), Font = UIStyle.BodyFont, TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd,
                TextColor3 = isMe and Color3.fromRGB(140, 220, 255) or C.Text, ZIndex = 54, Parent = row })
            Text({ Position = UDim2.new(1, -176, 0, 0), Size = UDim2.fromOffset(166, 34), Text = tostring(r.Value or ""), TextSize = 17, Stroke = 1.5, TextColor3 = medal or C.Gold,
                TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 54, Parent = row })
        end
        if #rows == 0 then
            Text({ LayoutOrder = 1, Size = UDim2.new(1, -12, 0, 60), Text = sv and "No entries yet: be the first!" or "Loading the boards... (they update every minute)", Font = UIStyle.BodyFont,
                TextSize = 15, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, ZIndex = 53, Parent = list })
        end
        you.Text = mine and string.format('YOU:  <font color="#8CDCFF"><b>#%d</b></font>   %s', mine.Rank or 0, tostring(mine.Value or ""))
            or '<font color="#9AA4C0">You are not in the top 50 yet</font>'
    end
    Tabs()
    Render()
    -- (2026-10-13, owner: overlaps) the 620 x 560 panel shrinks to fit the window it opens over (a phone's window is short)
    local fitS = New("UIScale", { Parent = panel })
    local function Fit()
        if not overlay.Parent then return end
        local ps = panel.AbsoluteSize / math.max(fitS.Scale, 0.01)
        local os_ = overlay.AbsoluteSize
        if ps.X < 1 or ps.Y < 1 or os_.Y < 1 then return end
        fitS.Scale = math.clamp(math.min((os_.X - 16) / ps.X, (os_.Y - 16) / ps.Y), 0.4, 1)
    end
    task.defer(Fit)
    overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(Fit)
    -- live: re-render when the server publishes new numbers
    local folder = ReplicatedStorage:FindFirstChild("Leaderboards")
    if folder then
        local conns = {}
        for _, sv in ipairs(folder:GetChildren()) do
            if sv:IsA("StringValue") then
                table.insert(conns, sv:GetPropertyChangedSignal("Value"):Connect(function() if overlay.Parent then Render() end end))
            end
        end
        overlay.Destroying:Connect(function() for _, c in ipairs(conns) do c:Disconnect() end end)
    end
    return overlay
end

-- A gold "🏆 LEADERBOARD" button that opens the popup over the window that contains it.
function LeaderboardView.Button(parent: Instance, size: UDim2, position: UDim2, ids: { string }, startId: (() -> string?)?, playClick: (() -> ())?, label: string?)
    local b = UIStyle.Button(parent, label or "LEADERBOARD", C.Gold, size, position)
    b.Label.TextSize = 15
    b.Button.MouseButton1Click:Connect(function()
        -- open over the whole window (the top-level UIStyle panel), not just the card the button sits in
        local host = parent
        while host.Parent and not host:GetAttribute("UIStyled") do host = host.Parent end
        LeaderboardView.Open(host, ids, startId and startId() or nil, playClick)
        if playClick then playClick() end
    end)
    return b
end

return LeaderboardView
