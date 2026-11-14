--!nocheck
-- ============================================================================================
-- GUILD window (UPDATE 7 B9, client). No guild: FOUND one (name + tag, gold), ASK TO JOIN one by name, your invites.
-- In a guild: the header (name [TAG], bank, members), MEMBERS (rank, gold given; KICK / PROMOTE by rank), RESEARCH (fund from the
-- bank: officers + the leader), DONATE, INVITE by player name, join REQUESTS (approve / deny), tag colours, LEAVE.
-- GuildMenu.Init(menuFolder, hooks { Toast, Click, OpenFrame }) -> api { Open() }
-- ============================================================================================
local Shared = script.Parent
local UIStyle = require(Shared:WaitForChild("UIStyle"))
-- (UI CLEAN R-B2) every button on the role styles: a confirm / buy (green, gold, the window accent) = the off-white primary,
-- any other hue (blue / purple / red / a material colour) = the quiet outlined secondary; neutral slates keep their own role
local function RoleCol(col: Color3?): Color3?
    local CC = UIStyle.Colors
    if not col then return col end
    if col == CC.Green or col == CC.Gold or col == CC.Accent then return CC.Accent end
    local _, sat = col:ToHSV()
    if sat < 0.25 then return col end
    return CC.Steel
end
local function RoleBtn(parent, text, col, ...) return UIStyle.Button(parent, text, RoleCol(col), ...) end
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local Guilds = require(Shared:WaitForChild("Guilds"))
local Players = game:GetService("Players")

local GuildMenu = {}

function GuildMenu.Init(menuFolder: Instance, hooks: any)
    local C = UIStyle.Colors
    local New, Text = UIStyle.New, UIStyle.Text
    local GC = UIStyle.Colors.Accent -- (UI CLEAN R-B2: the window's accent = the off-white primary; Guilds.COLOR stays for the crew's own marks)
    local root = UIStyle.Panel(menuFolder, { Name = "GuildMenu", Size = UDim2.fromOffset(940, 620), Accent = GC })
    -- (phones: no PhoneMinH reshape -- the fixed layout keeps its height and the window scrolls)
    UIStyle.TitleBar(root, "CREW", GC, "Play together across servers: a shared tag, a bank and research that helps every member.", function() root.Visible = false end)
    local body = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 1, -92), Parent = root })
    local Render
    local function Call(action, a)
        local ok, r1, r2 = pcall(function() return Remotes.GetFunction("GuildAction"):InvokeServer(action, a) end)
        if not ok then return false, "Couldn't reach the server." end
        return r1, r2
    end
    local function Act(action, a)
        if hooks.Click then hooks.Click() end
        task.spawn(function()
            local ok, msg = Call(action, a)
            if hooks.Toast then hooks.Toast(tostring(msg)) end
            task.delay(0.3, function() if root.Visible then Render() end end)
        end)
    end
    local function Box(parent, pos, size, placeholder)
        return New("TextBox", { Position = pos, Size = size, BackgroundColor3 = C.Well or C.Bg0, BorderSizePixel = 0, Text = "", PlaceholderText = placeholder,
            ClearTextOnFocus = false, Font = UIStyle.BodyFont, TextSize = 15, TextColor3 = C.Text, Parent = parent })
    end
    local function Btn(parent, label, color, size, pos, fn)
        local b = RoleBtn(parent, label, color, size, pos, "B" .. label)
        b.Label.TextSize = 13
        b.Button.MouseButton1Click:Connect(function() if b.Button.Active then fn() end end)
        return b
    end
    local function RenderNone(v)
        local found = UIStyle.Card(body, { Size = UDim2.new(0.5, -6, 0, 250) }) -- (R-B2: no accent card)
        Text({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 26), Text = "FOUND A CREW", TextSize = 20, TextColor3 = GC, Parent = found })
        Text({ Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -28, 0, 36), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, TextWrapped = true,
            Text = "Costs " .. ItemData.FormatNumber(Guilds.CREATE_COST) .. " gold (level " .. Guilds.UNLOCK .. "+). The tag shows on every member's name tag.", Parent = found })
        local nb = Box(found, UDim2.fromOffset(14, 80), UDim2.new(1, -28, 0, 36), "crew name (3-20)")
        local tb = Box(found, UDim2.fromOffset(14, 124), UDim2.new(1, -28, 0, 36), "tag (2-4 letters)")
        Btn(found, "FOUND IT", GC, UDim2.new(1, -28, 0, 44), UDim2.fromOffset(14, 176), function() Act("Create", { Name = nb.Text, Tag = tb.Text }) end)
        local join = UIStyle.Card(body, { Position = UDim2.new(0.5, 6, 0, 0), Size = UDim2.new(0.5, -6, 0, 250) })
        Text({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 26), Text = "ASK TO JOIN", TextSize = 20, TextColor3 = C.Text, Parent = join })
        Text({ Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -28, 0, 36), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, TextWrapped = true,
            Text = "Type a crew's exact name. An officer can let you in, even when you're offline.", Parent = join })
        local jb = Box(join, UDim2.fromOffset(14, 80), UDim2.new(1, -28, 0, 36), "crew name")
        Btn(join, "SEND REQUEST", C.Steel, UDim2.new(1, -28, 0, 44), UDim2.fromOffset(14, 124), function() Act("Request", jb.Text) end)
        local invs = UIStyle.Card(body, { Position = UDim2.fromOffset(0, 262), Size = UDim2.new(1, 0, 1, -262) })
        Text({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 24), Text = "INVITES", TextSize = 17, TextColor3 = C.Sub, Parent = invs })
        if #(v.Invites or {}) == 0 then
            Text({ Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -28, 0, 20), Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, Text = "No invites right now.", Parent = invs })
        end
        for i, inv in ipairs(v.Invites or {}) do
            local y = 34 + (i - 1) * 44
            Text({ Position = UDim2.fromOffset(14, y + 8), Size = UDim2.new(1, -180, 0, 22), Font = UIStyle.BodyFont, TextSize = 14, Text = inv.Name .. "  (from " .. inv.From .. ")", Parent = invs })
            Btn(invs, "JOIN", GC, UDim2.fromOffset(140, 36), UDim2.new(1, -154, 0, y), function() Act("Accept", inv.Id) end)
        end
    end
    local function RenderGuild(v)
        local g, my = v.Guild, v.MyRank or 1
        local col = Color3.fromHex("#" .. tostring((function() for i, c in ipairs(Guilds.TAG_COLORS) do if c.Id == g.Color then return c.Color:ToHex() end end return Guilds.TAG_COLORS[1].Color:ToHex() end)()))
        local n = 0
        for _ in pairs(g.Members or {}) do n += 1 end
        local head = UIStyle.Card(body, { Size = UDim2.new(1, 0, 0, 84) }, col)
        Text({ Position = UDim2.fromOffset(14, 6), Size = UDim2.new(0.6, 0, 0, 30), Text = string.upper(g.Name) .. "  [" .. g.Tag .. "]", TextSize = 24, Stroke = 2, TextColor3 = col, Parent = head })
        Text({ Position = UDim2.fromOffset(14, 40), Size = UDim2.new(0.6, 0, 0, 20), Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub,
            Text = string.format("%d / %d members  •  bank %s gold  •  you: %s", n, Guilds.MAX_MEMBERS, ItemData.FormatNumber(g.Bank or 0), (my >= 3 and "Leader") or (my == 2 and "Officer") or "Member"), Parent = head })
        local db = Box(head, UDim2.new(0.6, 0, 0, 10), UDim2.new(0.2, -8, 0, 32), "gold to donate")
        Btn(head, "DONATE", C.Gold, UDim2.new(0.2, -8, 0, 32), UDim2.new(0.8, 0, 0, 10), function() Act("Donate", tonumber(db.Text)) end)
        Btn(head, "LEAVE", C.Red, UDim2.new(0.2, -8, 0, 28), UDim2.new(0.8, 0, 0, 48), function() Act("Leave") end)
        -- members
        local left = UIStyle.Card(body, { Position = UDim2.fromOffset(0, 92), Size = UDim2.new(0.42, -6, 1, -92) })
        Text({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 22), Text = "MEMBERS", TextSize = 16, TextColor3 = C.Sub, Parent = left })
        local ls = New("ScrollingFrame", { Position = UDim2.fromOffset(8, 32), Size = UDim2.new(1, -16, 1, -84), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = left }, { New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
        local list = {}
        for uid, m in pairs(g.Members or {}) do table.insert(list, { Uid = tonumber(uid), M = m }) end
        table.sort(list, function(a, b) local ra, rb = Guilds.RANKS[a.M.Rank] or 1, Guilds.RANKS[b.M.Rank] or 1; if ra ~= rb then return ra > rb end return (a.M.Gave or 0) > (b.M.Gave or 0) end)
        local me = Players.LocalPlayer.UserId
        for i, e in ipairs(list) do
            local row = New("Frame", { LayoutOrder = i, Size = UDim2.new(1, -6, 0, 40), BackgroundColor3 = C.CardDark or C.Bg2, BorderSizePixel = 0, Parent = ls })
            Text({ Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -150, 0, 20), Font = UIStyle.BodyFont, TextSize = 14, Text = tostring(e.M.Name), Parent = row })
            Text({ Position = UDim2.fromOffset(8, 20), Size = UDim2.new(1, -150, 0, 16), Font = UIStyle.BodyFont, TextSize = 11, TextColor3 = C.Sub,
                Text = string.upper(tostring(e.M.Rank)) .. "  •  gave " .. ItemData.FormatNumber(e.M.Gave or 0), Parent = row })
            local tr = Guilds.RANKS[e.M.Rank] or 1
            if e.Uid ~= me and my > tr then Btn(row, "KICK", C.Red, UDim2.fromOffset(62, 28), UDim2.new(1, -66, 0, 6), function() Act("Kick", e.Uid) end) end
            if e.Uid ~= me and my >= 3 and tr < 3 then Btn(row, tr == 2 and "DEMOTE" or "PROMOTE", C.Steel, UDim2.fromOffset(72, 28), UDim2.new(1, -142, 0, 6), function() Act("Promote", e.Uid) end) end
        end
        local ib = Box(left, UDim2.new(0, 8, 1, -44), UDim2.new(1, -116, 0, 36), "invite a player here")
        Btn(left, "INVITE", GC, UDim2.fromOffset(92, 36), UDim2.new(1, -100, 1, -44), function() Act("Invite", ib.Text) end).SetEnabled(my >= 2)
        -- research + requests
        local right = UIStyle.Card(body, { Position = UDim2.new(0.42, 6, 0, 92), Size = UDim2.new(0.58, -6, 1, -92) }, col)
        Text({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 22), Text = "RESEARCH (paid from the bank, helps every member)", TextSize = 15, TextColor3 = C.Sub, Parent = right })
        for i, r in ipairs(Guilds.RESEARCH) do
            local lvl = (g.Research or {})[r.Id] or 0
            local y = 32 + (i - 1) * 46
            local row = New("Frame", { Position = UDim2.fromOffset(10, y), Size = UDim2.new(1, -20, 0, 42), BackgroundColor3 = C.CardDark or C.Bg2, BorderSizePixel = 0, Parent = right })
            Text({ Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -150, 0, 20), Font = UIStyle.BodyFont, TextSize = 14, Text = string.format("%s  %d / %d", r.Name, lvl, #r.Costs), Parent = row })
            Text({ Position = UDim2.fromOffset(8, 20), Size = UDim2.new(1, -150, 0, 18), Font = UIStyle.BodyFont, TextSize = 11, TextColor3 = C.Sub, Text = r.Text, Parent = row })
            local cost = r.Costs[lvl + 1]
            local b = Btn(row, cost and ItemData.FormatNumber(cost) or "DONE", cost and col or C.Steel, UDim2.fromOffset(130, 32), UDim2.new(1, -136, 0, 5), function() Act("Research", r.Id) end)
            b.SetEnabled(cost ~= nil and my >= 2 and (g.Bank or 0) >= cost)
        end
        local yq = 32 + #Guilds.RESEARCH * 46 + 6
        Text({ Position = UDim2.fromOffset(12, yq), Size = UDim2.new(0.5, 0, 0, 20), Text = "TAG COLOUR", TextSize = 13, TextColor3 = C.Sub, Parent = right })
        local perks = v.Perks or {}
        for i, c in ipairs(Guilds.TAG_COLORS) do
            local ok = i == 1 or (perks.Colors or 0) >= i - 1
            local b = UIStyle.Button(right, string.upper(c.Id), ok and c.Color or C.Steel, UDim2.fromOffset(78, 26), UDim2.fromOffset(110 + (i - 1) * 84, yq - 3), "Col" .. i)
            b.Label.TextSize = 11
            b.SetEnabled(ok and my >= 3)
            b.Button.MouseButton1Click:Connect(function() if b.Button.Active then Act("SetColor", c.Id) end end)
        end
        local reqs = {}
        for uid, name in pairs(g.Requests or {}) do table.insert(reqs, { Uid = tonumber(uid), Name = name }) end
        local yr = yq + 30
        Text({ Position = UDim2.fromOffset(12, yr), Size = UDim2.new(1, -24, 0, 20), Text = "JOIN REQUESTS (" .. #reqs .. ")", TextSize = 13, TextColor3 = C.Sub, Parent = right })
        for i, rq in ipairs(reqs) do
            if i > 3 then break end
            local y = yr + 22 + (i - 1) * 34
            Text({ Position = UDim2.fromOffset(14, y + 4), Size = UDim2.new(1, -230, 0, 20), Font = UIStyle.BodyFont, TextSize = 13, Text = tostring(rq.Name), Parent = right })
            Btn(right, "LET IN", GC, UDim2.fromOffset(96, 28), UDim2.new(1, -206, 0, y), function() Act("Approve", rq.Uid) end).SetEnabled(my >= 2)
            Btn(right, "DENY", C.Steel, UDim2.fromOffset(96, 28), UDim2.new(1, -106, 0, y), function() Act("Deny", rq.Uid) end).SetEnabled(my >= 2)
        end
    end
    Render = function()
        for _, c in ipairs(body:GetChildren()) do c:Destroy() end
        Text({ Size = UDim2.new(1, 0, 0, 20), Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, Text = "Loading...", Name = "Loading", Parent = body })
        task.spawn(function()
            local ok, v = Call("Get")
            if not root.Visible and not ok then return end
            for _, c in ipairs(body:GetChildren()) do c:Destroy() end
            if not ok or type(v) ~= "table" then
                Text({ Size = UDim2.new(1, 0, 0, 20), Font = UIStyle.BodyFont, TextSize = 13, Text = tostring(v), Parent = body })
                return
            end
            if v.Guild then RenderGuild(v) else RenderNone(v) end
        end)
    end
    Remotes.GetEvent("GuildInvite").OnClientEvent:Connect(function(id, name, from)
        if hooks.Toast then hooks.Toast(tostring(from) .. " invited you to the crew " .. tostring(name) .. ". Open MENU > CREW to join.") end
        if root.Visible then Render() end
    end)
    local api = {}
    function api.Open()
        Render()
        if not root.Visible and hooks.OpenFrame then hooks.OpenFrame(root) end
    end
    api.Frame = root
    return api
end

return GuildMenu
