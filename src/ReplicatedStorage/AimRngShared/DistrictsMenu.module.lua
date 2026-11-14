--!nocheck
-- ============================================================================================
-- DISTRICTS window (UPDATE 7 B5, client): a tab per city district -- its leader, your rank + standing, today's bounties, the
-- rival it costs you standing with, and its shop (DistrictAction "Buy"). Opened by talking to a leader in the hub
-- (LivingHub -> OpenMenu "Districts", id) or DistrictsMenu.Open(id).
-- DistrictsMenu.Init(menuFolder, hooks { GetState, Toast, Click, OpenFrame(frame) }) -> api { Open(id), Refresh() }
-- ============================================================================================
local Shared = script.Parent
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Districts = require(Shared:WaitForChild("Districts"))
local ItemData = require(Shared:WaitForChild("ItemData"))

local DistrictsMenu = {}

function DistrictsMenu.Init(menuFolder: Instance, hooks: any)
    local C = UIStyle.Colors
    local New, Text = UIStyle.New, UIStyle.Text
    local root = UIStyle.Panel(menuFolder, { Name = "DistrictsMenu", Size = UDim2.fromOffset(900, 620), Accent = C.Gold })
    -- (phones: no PhoneMinH reshape -- the fixed layout keeps its height and the window scrolls)
    UIStyle.TitleBar(root, "CITY QUARTERS", C.Gold, "Help a quarter with its bounties for standing; it costs you standing with its rival.", function() root.Visible = false end)
    local tabsRow = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 0, 44), Parent = root })
    local body = New("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 128), Size = UDim2.new(1, -32, 1, -144), Parent = root })
    local current = Districts.Order[1]
    local Render
    local tabs = {}
    for i, id in ipairs(Districts.Order) do
        local d = Districts.Defs[id]
        local b = UIStyle.Button(tabsRow, string.upper(d.Name), C.Bg2, UDim2.new(1 / 3, -6, 1, 0), UDim2.new((i - 1) / 3, 3, 0, 0), "Tab" .. id)
        b.Button.MouseButton1Click:Connect(function() if hooks.Click then hooks.Click() end; current = id; Render() end)
        tabs[id] = b
        pcall(function() require(script.Parent:WaitForChild("MenuKit")).WordTab(b) end) -- (UI CLEAN audit: word tabs)
    end
    local function Clear() for _, c in ipairs(body:GetChildren()) do c:Destroy() end end
    Render = function()
        Clear()
        for id, b in pairs(tabs) do b.SetSelected(id == current) end -- (v4 NEON)
        local st = hooks.GetState and hooks.GetState() or {}
        local d = Districts.Defs[current]
        local s = type(st.Districts) == "table" and st.Districts or {}
        local earned = (s.Earned or {})[current] or 0
        local bank = (s.Bank or {})[current] or 0
        local rank = Districts.Rank(earned)
        local nextNeed = Districts.RANKS[rank + 2]
        -- header: the leader + your standing
        local head = UIStyle.Card(body, { Size = UDim2.new(1, 0, 0, 132) }, d.Color)
        pcall(function() require(script.Parent:WaitForChild("MenuKit")).Card(head, d.Color) end) -- (UI CLEAN audit: raised card, the quarter's colour as a 2 px line)
        Text({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(0.6, 0, 0, 30), Text = string.upper(d.Name) .. "  •  " .. d.Style, TextSize = 24, TextColor3 = C.Text, Parent = head })
        Text({ Position = UDim2.fromOffset(16, 38), Size = UDim2.new(0.6, -16, 0, 18), Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub,
            Text = d.Leader .. ", " .. d.Role .. ".", Parent = head })
        Text({ Position = UDim2.fromOffset(16, 58), Size = UDim2.new(0.6, -16, 0, 34), Font = UIStyle.BodyFont, TextSize = 13, TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top, Text = d.Blurb, Parent = head })
        local rival = Districts.Defs[d.Rival]
        Text({ Position = UDim2.fromOffset(16, 98), Size = UDim2.new(0.6, -16, 0, 18), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub,
            Text = "RIVAL: " .. rival.Name .. " (every bit of standing here costs half as much there)", Parent = head })
        Text({ Position = UDim2.new(0.62, 0, 0, 10), Size = UDim2.new(0.38, -16, 0, 28), Text = "RANK " .. rank .. ": " .. string.upper(Districts.RANK_NAMES[rank]), TextSize = 20,
            TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Right, Parent = head })
        local bar = New("Frame", { Position = UDim2.new(0.62, 0, 0, 44), Size = UDim2.new(0.38, -16, 0, 10), BackgroundColor3 = C.Off, BorderSizePixel = 0, Parent = head })
        local prev = Districts.RANKS[rank + 1] or 0
        New("Frame", { Size = UDim2.new(nextNeed and math.clamp((earned - prev) / math.max(1, nextNeed - prev), 0, 1) or 1, 0, 1, 0), BackgroundColor3 = d.Color, BorderSizePixel = 0, Parent = bar })
        Text({ Position = UDim2.new(0.62, 0, 0, 58), Size = UDim2.new(0.38, -16, 0, 18), Font = UIStyle.BodyFont, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right,
            Text = nextNeed and string.format("%s / %s standing to rank %d", ItemData.FormatNumber(earned), ItemData.FormatNumber(nextNeed), rank + 1) or (ItemData.FormatNumber(earned) .. " standing (top rank)"), Parent = head })
        Text({ Position = UDim2.new(0.62, 0, 0, 80), Size = UDim2.new(0.38, -16, 0, 22), TextSize = 17, TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Right,
            Text = ItemData.FormatNumber(bank) .. " TO SPEND", Parent = head })
        Text({ Position = UDim2.new(0.62, 0, 0, 104), Size = UDim2.new(0.38, -16, 0, 18), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Right,
            Text = string.format("today: %s / %s standing (all quarters)", ItemData.FormatNumber(s.DayEarned or 0), ItemData.FormatNumber(Districts.DAILY_CAP)), Parent = head })
        if (st.Level or 1) < Districts.UNLOCK then
            Text({ Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 40), Font = UIStyle.BodyFont, TextSize = 16, TextColor3 = C.Text, TextWrapped = true,
                Text = "The quarters don't trust strangers: come back at level " .. Districts.UNLOCK .. ".", Parent = body })
            return
        end
        -- today's bounties
        local left = UIStyle.Card(body, { Position = UDim2.fromOffset(0, 142), Size = UDim2.new(0.48, -6, 1, -142) })
        Text({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 24), Text = "TODAY'S BOUNTIES", TextSize = 17, TextColor3 = C.Sub, Parent = left })
        local per = Districts.StandingFor(st.Level)
        for i, b in ipairs((s.Bounties or {})[current] or {}) do
            local y = 40 + (i - 1) * 74
            local row = New("Frame", { Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -24, 0, 66), BackgroundColor3 = C.CardDark or C.Bg2, BorderSizePixel = 0, Parent = left })
            Text({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 20), Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = b.Done and C.Green or C.Text,
                Text = (b.Done and "✓ " or "") .. Districts.Text(current, b), Parent = row })
            local pb = New("Frame", { Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 8), BackgroundColor3 = C.Off, BorderSizePixel = 0, Parent = row })
            New("Frame", { Size = UDim2.new(math.clamp((b.Progress or 0) / math.max(1, b.Target or 1), 0, 1), 0, 1, 0), BackgroundColor3 = b.Done and C.Green or d.Color, BorderSizePixel = 0, Parent = pb })
            Text({ Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 0, 18), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub,
                Text = string.format("%d / %d  •  +%s standing, -%s with %s", b.Progress or 0, b.Target or 1, ItemData.FormatNumber(per), ItemData.FormatNumber(math.floor(per * Districts.RIVAL_SHARE)), rival.Name), Parent = row })
        end
        Text({ Position = UDim2.new(0, 14, 1, -44), Size = UDim2.new(1, -28, 0, 36), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, TextWrapped = true,
            Text = "New bounties every day (UTC). They count from any run, like your daily contracts.", Parent = left })
        -- the shop
        local right = UIStyle.Card(body, { Position = UDim2.new(0.48, 6, 0, 142), Size = UDim2.new(0.52, -6, 1, -142) })
        Text({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 24), Text = string.upper(d.Name) .. " STALL", TextSize = 17, TextColor3 = C.Sub, Parent = right })
        local titles = st.UnlockedTitles or {}
        for i, it in ipairs(Districts.Shop(current)) do
            local y = 38 + (i - 1) * 50
            local row = New("Frame", { Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -24, 0, 44), BackgroundColor3 = C.CardDark or C.Bg2, BorderSizePixel = 0, Parent = right })
            local owned = it.Title and table.find(titles, it.Title) ~= nil
            local okRank = rank >= it.Rank
            Text({ Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -150, 0, 22), Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = okRank and C.Text or C.Sub, Text = it.Name, Parent = row })
            Text({ Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -150, 0, 18), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub,
                Text = string.format("%s standing  •  rank %d (%s)", ItemData.FormatNumber(it.Cost), it.Rank, Districts.RANK_NAMES[it.Rank]), Parent = row })
            local can = okRank and bank >= it.Cost and not owned and (not it.MinLevel or (st.Level or 1) >= it.MinLevel)
            local b = UIStyle.Button(row, owned and "OWNED" or "BUY", can and C.Accent or C.Steel, UDim2.fromOffset(110, 32), UDim2.new(1, -118, 0, 6), "Buy" .. it.Id)
            b.Label.TextSize = 14
            b.SetEnabled(can)
            b.Button.MouseButton1Click:Connect(function()
                if not b.Button.Active then return end
                if hooks.Click then hooks.Click() end
                task.spawn(function()
                    local ok, okRes, msg = pcall(function() return Remotes.GetFunction("DistrictAction"):InvokeServer("Buy", current, it.Id) end)
                    if hooks.Toast then hooks.Toast(tostring(ok and (msg or (okRes and "Bought." or "Couldn't buy that.")) or "Couldn't reach the server.")) end
                    task.delay(0.25, function() if root.Visible then Render() end end)
                end)
            end)
        end
    end
    local api = {}
    function api.Open(id: string?)
        if id and Districts.Defs[id] then current = id end
        Render()
        if not root.Visible and hooks.OpenFrame then hooks.OpenFrame(root) end
    end
    function api.Refresh() if root.Visible then Render() end end
    api.Frame = root
    return api
end

return DistrictsMenu
