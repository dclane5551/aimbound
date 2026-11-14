--!nocheck
-- ============================================================================================
-- PROFILE window (2026-10-20, client; server AimRngServer/ProfileService). Left: YOU + everyone in this server. Right: the
-- picked player's header (avatar, title, level, class / specialization, Marksman Grade, crew) and two tabs:
--   OVERVIEW: their gun + gear + melee (hover = the full item card), build (passives, tree points, gems), cosmetics worn.
--   AIM: accuracy, weak-spot hits, weak-spot kills, K/D, best headshot streak, runs, play time, where they stand in this
--        server; Aim Trial bests + ranks; per-gun numbers; the last runs' accuracy as a bar chart.
-- Opened from MENU > PROFILES (you, AIM tab), clicking a player in the city, a Hall of Aim statue (OpenMenu "Profile", uid).
-- ProfileMenu.Init(menuFolder, hooks { Toast, Click, OpenFrame, Close, HookItemTooltip(gui, item, isGear) }) -> api { Open(uid?, tab?) }
-- ============================================================================================
local Shared = script.Parent
local UIStyle = require(Shared:WaitForChild("UIStyle"))
-- (UI CLEAN R-A, AimRngShared/MenuKit: cards = the target's raised card (a state / accent colour = ONE 2 px bottom line), tabs /
-- filters = words with the 2 px underline)
local MenuKit = require(Shared:WaitForChild("MenuKit"))
local function KCard(parent: Instance, props: any, accent: Color3?): Frame
    return MenuKit.Card(UIStyle.Card(parent, props, nil), accent) :: Frame
end
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local Players = game:GetService("Players")

local ProfileMenu = {}
local ACCENT = Color3.fromRGB(255, 184, 28)
local GEAR_ORDER = { "Helmet", "ChestPiece", "Gloves", "Leggings", "Boots", "Ring1", "Ring2", "Necklace" } -- (UPDATE 8: + Gloves)

local function Pct(a, b) return (b and b > 0) and string.format("%.1f%%", 100 * a / b) or "-" end
local function Hours(s) s = tonumber(s) or 0; return (s >= 3600) and string.format("%.1f h", s / 3600) or string.format("%d min", math.floor(s / 60)) end

function ProfileMenu.Init(menuFolder: Instance, hooks: any)
    local C = UIStyle.Colors
    local New, Text = UIStyle.New, UIStyle.Text
    local lp = Players.LocalPlayer
    local function Click() if hooks.Click then hooks.Click() end end
    local root = UIStyle.Panel(menuFolder, { Name = "ProfileMenu", Size = UDim2.fromOffset(1060, 660), Accent = ACCENT })
    UIStyle.TitleBar(root, "PROFILES", ACCENT, "Anyone's gear, build and aim. Click a player in the city to open theirs.", function()
        Click()
        if hooks.Close then hooks.Close() else root.Visible = false end
    end)
    local current, tab = lp.UserId, "Overview"
    local prof

    -- left: players here
    local left = KCard(root, { Name = "Players", Position = UDim2.fromOffset(16, 76), Size = UDim2.new(0, 220, 1, -92) })
    Text({ Text = "PLAYERS HERE", TextSize = 15, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(1, -24, 0, 20), Parent = left })
    local plist = New("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 30), Size = UDim2.new(1, -16, 1, -38),
        ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = left },
        { New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

    -- right: header + tabs + body
    local head = KCard(root, { Name = "Head", Position = UDim2.fromOffset(248, 76), Size = UDim2.new(1, -264, 0, 92) }, nil) -- (UI CLEAN R-A: no gold line)
    local avatar = New("ImageLabel", { BackgroundColor3 = C.Well, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(72, 72), Image = "", Parent = head })
    local hName = Text({ Text = "", TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(94, 6), Size = UDim2.new(1, -330, 0, 30), TextTruncate = Enum.TextTruncate.AtEnd, Parent = head })
    local hTitle = Text({ Font = UIStyle.BodyFont, Text = "", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(94, 36), Size = UDim2.new(1, -330, 0, 20), Parent = head })
    local hLine = Text({ Font = UIStyle.BodyFont, Text = "", TextSize = 13, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(94, 60), Size = UDim2.new(1, -330, 0, 20), Parent = head })
    local tabBtns = {}
    for i, t in ipairs({ { "Overview", "OVERVIEW" }, { "Aim", "AIM" } }) do
        local b = UIStyle.Button(head, t[2], C.Bg2, UDim2.fromOffset(110, 36), UDim2.new(1, -236 + (i - 1) * 116, 0.5, -18), "Tab" .. t[1])
        b.Label.TextSize = 14
        tabBtns[t[1]] = b
        MenuKit.WordTab(b) -- (UI CLEAN R-A)
        b.Button.MouseButton1Click:Connect(function() Click(); tab = t[1]; ProfileMenu._Render() end)
    end
    local body = New("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(248, 178), Size = UDim2.new(1, -264, 1, -194), Parent = root })

    local function Section(parent, title)
        Text({ Text = title, TextSize = 15, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 6),
            Size = UDim2.new(1, -24, 0, 20), Parent = parent })
        return New("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 30), Size = UDim2.new(1, -16, 1, -38),
            ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = parent },
            { New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
    end
    local function Row(list, order, a, b, colA, h, split)
        split = split or 0.62
        local r = New("Frame", { LayoutOrder = order, Size = UDim2.new(1, -6, 0, h or 30), BackgroundColor3 = C.CardDark or C.Bg2, BorderSizePixel = 0, Parent = list })
        Text({ Font = UIStyle.BodyFont, TextSize = 14, Text = a, TextColor3 = colA or C.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(8, 0), Size = UDim2.new(b and split or 1, -12, 1, 0), Parent = r })
        if b then
            Text({ Font = UIStyle.BodyFont, TextSize = 13, Text = b, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
                Position = UDim2.new(split, 0, 0, 0), Size = UDim2.new(1 - split, -8, 1, 0), Parent = r })
        end
        return r
    end

    local function Overview(p)
        local w = 1 / 3
        local c1 = KCard(body, { Position = UDim2.fromScale(0, 0), Size = UDim2.new(w, -6, 1, 0) })
        local c2 = KCard(body, { Position = UDim2.new(w, 3, 0, 0), Size = UDim2.new(w, -6, 1, 0) })
        local c3 = KCard(body, { Position = UDim2.new(2 * w, 6, 0, 0), Size = UDim2.new(w, -6, 1, 0) })
        local l1 = Section(c1, "LOADOUT")
        local o = 0
        local function ItemRow(item, label, isGear)
            o += 1
            local col = ItemData.ItemColor and ItemData.ItemColor(item) or (ItemData.RarityColors[item.Rarity] or C.Text)
            local nm = (ItemData.DisplayName and ItemData.DisplayName(item)) or tostring(item.Name or item.BaseId or "?")
            local r = Row(l1, o, nm, label, col, 38)
            if hooks.HookItemTooltip then pcall(hooks.HookItemTooltip, r, item, isGear) end
        end
        if type(p.Weapon) == "table" then ItemRow(p.Weapon, "GUN", false) end
        for _, slot in ipairs(GEAR_ORDER) do
            local g = p.Gear and p.Gear[slot]
            if type(g) == "table" then ItemRow(g, string.upper(slot), true) end
        end
        if p.Melee then o += 1; Row(l1, o, tostring(p.Melee), "MELEE") end
        local l2 = Section(c2, "BUILD")
        o = 0
        local function R2(a, b, col) o += 1; Row(l2, o, a, b, col) end
        R2("Tree nodes", tostring(p.TreePoints or 0))
        R2("Gems socketed", tostring(p.Gems or 0))
        if p.Spec then R2("Specialization", p.Spec) end
        if #(p.Passives or {}) == 0 then R2("No passive skills equipped", nil, C.Sub) end
        for _, ps in ipairs(p.Passives or {}) do
            o += 1
            local r = Row(l2, o, "★ " .. tostring(ps.Name), nil, Color3.fromRGB(255, 210, 90), 44)
            if ps.Desc then
                local d = r:FindFirstChildOfClass("TextLabel")
                if d then d.Text = "★ " .. tostring(ps.Name) .. "\n" .. tostring(ps.Desc); d.TextSize = 12; d.TextWrapped = true; d.TextTruncate = Enum.TextTruncate.AtEnd end
            end
        end
        local l3 = Section(c3, "COSMETICS WORN")
        if #(p.Cosmetics or {}) == 0 then Row(l3, 1, "Just the defaults", nil, C.Sub) end
        for i, c in ipairs(p.Cosmetics or {}) do
            Row(l3, i, tostring(c.Name), tostring(c.Cat), ItemData.RarityColors[c.Rarity or ""] or C.Text)
        end
    end

    local function Aim(p)
        local a = p.Aim or {}
        local tiles = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 132), Parent = body })
        local tl = New("UIGridLayout", { CellSize = UDim2.new(0.25, -6, 0, 62), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tiles })
        local _ = tl
        local srv = p.Server and p.Server.Players > 1 and string.format("better than %d of %d here", p.Server.Better, p.Server.Players - 1) or "only player here"
        local items = {
            { "ACCURACY", Pct(a.Hits or 0, a.Shots or 0), (a.Shots or 0) < 50 and "needs 50 shots" or srv },
            { "WEAK-SPOT HITS", Pct(math.min(a.Weak or 0, a.Hits or 0), a.Hits or 0), "of hits" },
            { "WEAK-SPOT KILLS", Pct(a.WeakKills or 0, a.Kills or 0), ItemData.FormatNumber(a.Kills or 0) .. " kills" },
            { "K / D", (a.Deaths or 0) > 0 and string.format("%.1f", (a.Kills or 0) / a.Deaths) or tostring(a.Kills or 0), ItemData.FormatNumber(a.Deaths or 0) .. " deaths" },
            { "BEST HEADSHOT STREAK", tostring(a.BestHs or 0), "in a row" },
            { "RUNS", ItemData.FormatNumber(a.Runs or 0), Hours(a.Play) .. " played" },
            { "SHOTS", ItemData.FormatNumber(a.Shots or 0), ItemData.FormatNumber(a.Hits or 0) .. " hit" },
            { "LAST RUNS", (function()
                local s, h = 0, 0
                for _, r in ipairs(a.Log or {}) do s += r.S or 0; h += r.H or 0 end
                return Pct(h, s)
            end)(), #(a.Log or {}) .. " runs logged" },
        }
        for i, t in ipairs(items) do
            local c = KCard(tiles, { LayoutOrder = i, Size = UDim2.fromOffset(10, 10) })
            Text({ Text = t[1], TextSize = 12, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 16), Parent = c })
            Text({ Text = t[2], TextSize = 22, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(10, 18), Size = UDim2.new(1, -20, 0, 26), Parent = c })
            Text({ Font = UIStyle.BodyFont, Text = t[3], TextSize = 12, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(10, 43), Size = UDim2.new(1, -20, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = c })
        end
        -- trials | guns | chart
        local lower = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 140), Size = UDim2.new(1, 0, 1, -140), Parent = body })
        local cT = KCard(lower, { Size = UDim2.new(0.3, -6, 1, 0) })
        local lT = Section(cT, "AIM TRIAL BESTS")
        for i, t in ipairs(a.Trials or {}) do Row(lT, i, tostring(t.Name), (t.Best or 0) > 0 and (ItemData.FormatNumber(t.Best) .. "  " .. tostring(t.Rank or "")) or "-") end
        local cG = KCard(lower, { Position = UDim2.new(0.3, 0, 0, 0), Size = UDim2.new(0.4, -6, 1, 0) })
        local lG = Section(cG, "BY GUN  (runs • accuracy • weak spot • kills)")
        if #(a.Guns or {}) == 0 then Row(lG, 1, "No runs logged yet.", nil, C.Sub) end
        for i, g in ipairs(a.Guns or {}) do
            if i > 12 then break end
            Row(lG, i, tostring(g.Name), string.format("%d • %s • %s • %s", g.R or 0, Pct(g.H or 0, g.S or 0), Pct(g.W or 0, g.P or 0), ItemData.FormatNumber(g.K or 0)), nil, nil, 0.36)
        end
        local cC = KCard(lower, { Position = UDim2.new(0.7, 0, 0, 0), Size = UDim2.new(0.3, 0, 1, 0) })
        Text({ Text = "ACCURACY, LAST RUNS", TextSize = 15, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 20), Parent = cC })
        local chart = New("Frame", { BackgroundColor3 = C.Well, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 1, -64), Parent = cC })
        local log = a.Log or {}
        if #log == 0 then
            Text({ Font = UIStyle.BodyFont, Text = "Play a run: each one adds a bar.", TextSize = 13, TextColor3 = C.Sub, Size = UDim2.fromScale(1, 1), TextWrapped = true, Parent = chart })
        end
        local n = math.max(#log, 1)
        for i, r in ipairs(log) do
            local acc = (r.S or 0) > 0 and (r.H or 0) / r.S or 0
            local col = acc >= 0.6 and C.Good or (acc >= 0.4 and C.Gold or C.Bad) -- (the legend says gold)
            New("Frame", { BackgroundColor3 = col, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
                Position = UDim2.new((i - 1) / n, 1, 1, 0), Size = UDim2.new(1 / n, -2, math.clamp(acc, 0.02, 1), 0), Parent = chart })
        end
        Text({ Font = UIStyle.BodyFont, Text = "oldest  →  newest   (green 60%+, gold 40%+)", TextSize = 11, TextColor3 = C.Sub, Position = UDim2.new(0, 12, 1, -28), Size = UDim2.new(1, -24, 0, 20), Parent = cC })
    end

    function ProfileMenu._Render()
        for id, b in pairs(tabBtns) do b.SetSelected(id == tab) end -- (v4 NEON)
        for _, c in ipairs(body:GetChildren()) do c:Destroy() end
        if not prof then
            hName.Text, hTitle.Text, hLine.Text = "Loading...", "", ""
            return
        end
        local p = prof
        hName.Text = (p.Crew and ("[" .. tostring(p.Crew) .. "] ") or "") .. tostring(p.Name)
        hTitle.Text = p.Title or "No title"
        hTitle.TextColor3 = p.TitleColor or C.Sub
        hLine.Text = string.format("Level %d  •  %s%s  •  Marksman Grade %d  •  %s", p.Level or 1, p.Class or "No class", p.Spec and (" / " .. p.Spec) or "",
            p.Grade or 0, p.Online and "in this server" or "not in this server")
        task.spawn(function()
            local ok, img = pcall(function() return Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
            if ok and prof == p then avatar.Image = img end
        end)
        if tab == "Aim" then Aim(p) else Overview(p) end
    end

    local function Load(uid)
        current = uid
        prof = nil
        ProfileMenu._Render()
        task.spawn(function()
            local okC, ok, res = pcall(function() return Remotes.GetFunction("ProfileAction"):InvokeServer("Get", uid) end)
            if current ~= uid then return end
            if okC and ok and type(res) == "table" then prof = res; ProfileMenu._Render()
            else
                hName.Text = "Not available"
                hLine.Text = tostring(okC and res or "Couldn't reach the server.")
            end
        end)
    end

    local function LoadList()
        for _, c in ipairs(plist:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local okC, ok, rows = pcall(function() return Remotes.GetFunction("ProfileAction"):InvokeServer("List") end)
        if not (okC and ok and type(rows) == "table") then return end
        table.sort(rows, function(a, b) if (a.UserId == lp.UserId) ~= (b.UserId == lp.UserId) then return a.UserId == lp.UserId end return (a.Level or 0) > (b.Level or 0) end)
        for i, r in ipairs(rows) do
            local b = UIStyle.Button(plist, (r.UserId == lp.UserId and "YOU" or tostring(r.Name)) .. "  •  " .. tostring(r.Level or 1),
                C.Bg1, UDim2.new(1, -6, 0, 34), nil, "P" .. i)
            if r.UserId == current then b.SetSelected(true, "Left") end -- (UI v4 NEON)
            b.Button.LayoutOrder = i
            b.Label.TextSize = 13
            b.Button.MouseButton1Click:Connect(function()
                Click()
                Load(r.UserId)
                task.spawn(LoadList)
            end)
        end
    end

    local api = { Frame = root }
    function api.Open(uid, whichTab)
        tab = whichTab or (uid and uid ~= lp.UserId and "Overview") or tab
        if hooks.OpenFrame then hooks.OpenFrame(root) else root.Visible = true end
        Load(tonumber(uid) or lp.UserId)
        task.spawn(LoadList)
    end
    return api
end

return ProfileMenu
