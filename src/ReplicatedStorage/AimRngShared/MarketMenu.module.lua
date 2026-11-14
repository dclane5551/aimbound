--!nocheck
-- ============================================================================================
-- THE MARKET window (UPDATE 7 C7, client). BROWSE (filters: kind, minimum rarity, currency, words, cheapest / newest) -> BUY;
-- MY LISTINGS (open / sold, CANCEL, your proceeds + COLLECT); SELL (your TRADE tab items + Riftmods -> currency + price -> LIST).
-- Every action is MarketAction on the server (MarketService). MarketMenu.Init(menuFolder, hooks { GetState, Toast, Click,
-- OpenFrame(frame), Tooltip(item, kind)?, HideTooltip? }) -> api { Open(tab?) }
-- ============================================================================================
local Shared = script.Parent
local InvLayout = require(script.Parent:WaitForChild("InvLayout")) -- (UI CLEAN R-B: icons + readable rarity names)
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local StashTabs = require(Shared:WaitForChild("StashTabs"))

local MarketMenu = {}
local CURRENCIES = { "Gold", "Prism" }
for _, k in ipairs(ItemData.CURRENCY_V5) do table.insert(CURRENCIES, k) end
if ItemData.ZenithShown() then for _, k in ipairs(ItemData.ZENITH_MATS or {}) do table.insert(CURRENCIES, k) end end -- (CHASE ITEMS: Twin Glass, once live; Studio: workspace DevZenithLive)
local KINDS = { "Any", "Weapon", "Gear", "Riftmod", "ShotMod" } -- (UPDATE 8 phase 3: + shot mods)

local function CurName(key: string): string
    if key == "Gold" then return "Gold" end
    local d = ItemData.MaterialDefs[key]
    return d and d.Name or key
end
local function PriceText(p: any): string
    return p and (ItemData.FormatNumber(p.N) .. " " .. CurName(p.Key)) or "?"
end

function MarketMenu.Init(menuFolder: Instance, hooks: any)
    local C = UIStyle.Colors
    local New, Text = UIStyle.New, UIStyle.Text
    local MC = C.Accent -- (UI CLEAN R-B2: the window's primary = the off-white accent; the old green is gone)
    local root = UIStyle.Panel(menuFolder, { Name = "MarketMenu", Size = UDim2.fromOffset(1240, 700), Accent = MC }) -- (R-B2: wider, the full-screen menu)
    root:SetAttribute("PhoneMinH", 360)
    UIStyle.TitleBar(root, "THE EXCHANGE", MC, "Buy and sell with every player, even when they're offline. Level 30+.", function() root.Visible = false end)
    local tabsRow = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 0, 40), Parent = root })
    local body = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 124), Size = UDim2.new(1, -32, 1, -140), Parent = root })
    local tab = "Browse"
    local filters = { Kind = "Any", MinRarity = nil, Currency = "Any", Text = "", Sort = "Cheap" }
    local sell = { Pick = nil, Key = "Gold", N = "" }
    local Render
    local api = {}
    local tabBtns = {}
    -- (UI CLEAN R-B2: word tabs like the inventory's bag tabs -- Sub words, the open one off-white with a 2 px underline)
    New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 26), SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center, Parent = tabsRow })
    local tabRule = New("Frame", { Name = "TabsRule", BackgroundColor3 = C.Text, BackgroundTransparency = 0.9, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 16, 0, 116), Size = UDim2.new(1, -32, 0, 1), Parent = root })
    tabRule:SetAttribute("Skinned", true)
    for i, t in ipairs({ { "Browse", "BROWSE" }, { "Mine", "MY LISTINGS" }, { "Sell", "SELL" } }) do
        local tb = New("TextButton", { Name = "Tab" .. t[1], Text = t[2], AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0,
            Font = Enum.Font.GothamBlack, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = i, Parent = tabsRow })
        tb:SetAttribute("NoNeon", true); tb:SetAttribute("Skinned", true)
        UIStyle.TextRole(tb, "Tab")
        tb.TextSize = 17
        local under = New("Frame", { Name = "Under", BackgroundColor3 = C.Text, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, 2), Visible = false, Parent = tb })
        under:SetAttribute("Skinned", true)
        local on = false
        tb.MouseEnter:Connect(function() if not on then tb.TextColor3 = C.Text end end)
        tb.MouseLeave:Connect(function() if not on then tb.TextColor3 = C.Sub end end)
        tb.Activated:Connect(function() if hooks.Click then hooks.Click() end; tab = t[1]; Render() end)
        tabBtns[t[1]] = { Button = tb, SetSelected = function(v: boolean) on = v; under.Visible = v; tb.TextColor3 = v and C.Text or C.Sub end }
    end
    local function Call(...)
        local ok, a, b = pcall(function(...) return Remotes.GetFunction("MarketAction"):InvokeServer(...) end, ...)
        if not ok then return false, "Couldn't reach the server." end
        return a, b
    end
    local function Clear()
        if hooks.HideTooltip then hooks.HideTooltip() end -- (QOL2 I6: a pinned card goes with its row)
        for _, c in ipairs(body:GetChildren()) do c:Destroy() end
    end
    root:GetPropertyChangedSignal("Visible"):Connect(function() if not root.Visible and hooks.HideTooltip then hooks.HideTooltip() end end)
    -- (QOL2 I6) the row's lines: as many as fit + "+N more" (the card has them all), refitted when the row's width changes
    local TextService = game:GetService("TextService")
    local function FitLines(lbl: TextLabel, lines: { string })
        local function Do(): boolean
            local wpx = lbl.AbsoluteSize.X
            if wpx <= 0 then return false end
            local font = (lbl.Font ~= Enum.Font.Unknown) and lbl.Font or Enum.Font.GothamBold
            local n = #lines
            for k = n, 0, -1 do
                local t = table.concat(lines, "  •  ", 1, k)
                if k < n then t = (k > 0 and (t .. "  •  ") or "") .. "+" .. (n - k) .. " more" end
                local ok, size = pcall(function() return TextService:GetTextSize(t, lbl.TextSize, font, Vector2.new(10000, 100)) end)
                if not ok or size.X <= wpx * 0.95 or k == 0 then lbl.Text = t; return true end
            end
            return true
        end
        lbl.Text = table.concat(lines, "  •  ")
        task.defer(Do)
        lbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(Do)
    end
    local function Cycle(list, cur)
        local i = table.find(list, cur) or 0
        return list[(i % #list) + 1]
    end
    local function Scroll(pos, size)
        local sf = New("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = pos, Size = size, ScrollBarThickness = 6,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = body })
        New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf })
        return sf
    end
    -- one item row: name / sub / lines + a right-side price and button
    local function ItemRow(parent, order, s, price, btnText, btnColor, btnOn, onClick, note)
        local item = s.Item or {}
        local smDef = (s.Kind == "ShotMod") and require(script.Parent:WaitForChild("ShotMods")).Def(item) or nil
        local col = smDef and require(script.Parent:WaitForChild("ShotMods")).COLOR[smDef.Color]
            or (ItemData.ItemColor and s.Kind ~= "Riftmod" and ItemData.ItemColor(item)) or ItemData.RarityColors[s.Rarity] or Color3.fromRGB(120, 200, 255)
        -- (UI CLEAN R-B: the shared item-row language -- flat Bg1 with a faint tint, a 2 px rarity edge at the bottom, the icon in a
        -- reserved box on the left (aspect kept), the name in the display face, the sub-line Label, the lines Meta)
        local row = New("TextButton", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = C.Bg1:Lerp(col, 0.06), BorderSizePixel = 0,
            Text = "", AutoButtonColor = false, Parent = parent }) -- (QOL2 I6: a button -- click / tap / pad pins its card)
        row:SetAttribute("NoNeon", true)
        New("Frame", { Name = "RarityEdge", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = col, BorderSizePixel = 0, Parent = row })
        local TX = 14
        if s.Kind == "Weapon" or s.Kind == "Gear" then
            local img = New("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 14 + 42, 0.5, -1),
                ScaleType = Enum.ScaleType.Fit, ImageColor3 = C.Text, Parent = row })
            local spec = InvLayout.IconFor((item.BaseId or item.Slot) and item or (s.Kind == "Weapon" and s.BaseId and { BaseId = s.BaseId }) or item,
                s.Kind == "Weapon" and "Weapon" or (s.Slot and ItemData.GearType(s.Slot)) or nil)
            -- (2026-11-09 SOCKETS) a gun's sockets under its icon (the icon lifts 5 px for them)
            if s.Kind == "Weapon" and InvLayout.Sockets and InvLayout.Sockets(row, item, { Dot = 8, MaxW = 96, AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0, 14 + 42, 1, -7), ZIndex = row.ZIndex + 1 }) then
                img.Position = UDim2.new(0, 14 + 42, 0, 26)
                InvLayout.ApplyIcon(img, spec, 84, 30, 28)
            else
                InvLayout.ApplyIcon(img, spec, 84, 34, 30)
            end
            img.ImageTransparency = spec.Glyph and 0.3 or 0.1
            TX = 112
        end
        local nm = Text({ Position = UDim2.fromOffset(TX, 6), Size = UDim2.new(1, -(316 + TX), 0, 20), Text = string.upper(tostring(s.Name)), TextSize = 15, TextColor3 = col, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
        UIStyle.TextRole(nm, "ItemName", { Keep = true }); nm.TextSize = 17; nm.TextColor3 = InvLayout.Readable(col, row.BackgroundColor3)
        local def = s.BaseId and ItemData.BaseWeapons[s.BaseId]
        local gunName = def and (def.ShortName or def.Name) or tostring(s.BaseId or "")
        local sub = smDef and ("Mod for a " .. require(script.Parent:WaitForChild("ShotMods")).COLOR_NAME[smDef.Color] .. " socket") or (s.Kind == "Riftmod") and ("Gunwright for the " .. gunName) or ((((s.Kind == "Weapon" or s.Kind == "Gear") and s.Item) and ItemData.RarityLabel(item) or tostring(s.Rarity)) .. " " .. (s.Kind == "Weapon" and gunName or tostring(s.Slot or "Gear")) .. (item.Twinned and "  •  TWINNED" or "")) -- (CHASE ITEMS review: ZENITH label, twinned marked)
        local subL = Text({ Position = UDim2.fromOffset(TX, 25), Size = UDim2.new(1, -(316 + TX), 0, 16), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, TextTruncate = Enum.TextTruncate.AtEnd,
            Text = sub .. (s.ItemLevel and ("  •  iLvl " .. s.ItemLevel) or "") .. (s.SellerName and ("  •  sold by " .. s.SellerName) or "") .. (note and ("  •  " .. note) or ""), Parent = row })
        UIStyle.TextRole(subL, "Label"); subL.TextSize = 13
        local linesLbl = Text({ Position = UDim2.fromOffset(TX, 42), Size = UDim2.new(1, -(316 + TX), 0, 16), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Muted,
            TextTruncate = Enum.TextTruncate.AtEnd, Text = "", Name = "Lines", Parent = row })
        UIStyle.TextRole(linesLbl, "Meta")
        FitLines(linesLbl, s.Lines or {}) -- (QOL2 I6: what fits + "+N more")
        if price then
            local pl = Text({ Position = UDim2.new(1, -310, 0, 8), Size = UDim2.fromOffset(170, 48), Text = price, TextSize = 16, TextColor3 = C.Gold, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
            UIStyle.TextRole(pl, "Title", { Keep = true }); pl.TextSize = 18 -- (R-B2: the price in the display face)
        end
        if btnText then
            local b = UIStyle.Button(row, btnText, btnColor, UDim2.fromOffset(120, 40), UDim2.new(1, -128, 0, 12), "Act" .. order)
            b.Label.TextSize = 14
            b.SetEnabled(btnOn ~= false)
            b.Button.MouseButton1Click:Connect(function() if b.Button.Active then if hooks.Click then hooks.Click() end; onClick() end end)
        end
        -- (QOL2 I6 2026-10-28, owner: "if the gun has enough affixes they just go off screen, hovering over / clicking on the item
        -- should bring up a card for it") every row with an item: the bag's card (all lines, sockets, compare, ALT ranges) on hover,
        -- click / tap pins it, pad selection shows it. Shot mods / Riftmods: a short text card.
        if s.Kind == "Weapon" or s.Kind == "Gear" then
            if hooks.Card and s.Item then hooks.Card(row, item, s.Kind == "Gear") end
        elseif hooks.TextCard then
            hooks.TextCard(row, function()
                local lines = { { Text = tostring(s.Name), Color = col, Size = 16, Bold = true }, { Text = sub .. (s.ItemLevel and ("  •  iLvl " .. s.ItemLevel) or ""), Color = C.Sub, Size = 12 }, { Sep = true } }
                for _, l in ipairs(s.Lines or {}) do table.insert(lines, { Text = l, Color = Color3.fromRGB(150, 180, 255) }) end
                if price then table.insert(lines, { Text = price, Color = C.Gold, Size = 12 }) end
                return lines, col
            end)
        end
        return row
    end

    local function RenderBrowse()
        local bar = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Parent = body })
        local function FB(label, x, w, fn)
            local b = UIStyle.Button(bar, label .. "  ▼", C.Steel, UDim2.fromOffset(w, 34), UDim2.fromOffset(x, 0), "F" .. x) -- (UI CLEAN R-B2: quiet outlined pickers)
            b.Label.TextSize = 13
            b.Button.MouseButton1Click:Connect(function() if hooks.Click then hooks.Click() end; fn(); Render() end)
        end
        FB("KIND: " .. string.upper(filters.Kind), 0, 140, function() filters.Kind = Cycle(KINDS, filters.Kind) end)
        local rarities = { "Any" }
        for _, r in ipairs(ItemData.Rarities) do table.insert(rarities, r) end
        if ItemData.ZenithShown() then table.insert(rarities, "Zenith") end -- (CHASE ITEMS: Zeniths only)
        FB("RARITY: " .. string.upper(filters.MinRarity or "ANY") .. "+", 146, 190, function()
            local nx = Cycle(rarities, filters.MinRarity or "Any"); filters.MinRarity = (nx ~= "Any") and nx or nil end)
        local curs = { "Any" }
        for _, k in ipairs(CURRENCIES) do table.insert(curs, k) end
        FB("PAID IN: " .. string.upper(filters.Currency == "Any" and "ANY" or CurName(filters.Currency)), 342, 180, function() filters.Currency = Cycle(curs, filters.Currency) end)
        FB(filters.Sort == "New" and "NEWEST" or "CHEAPEST", 528, 110, function() filters.Sort = (filters.Sort == "New") and "Cheap" or "New" end)
        local box = New("TextBox", { Position = UDim2.fromOffset(644, 0), Size = UDim2.new(1, -644 - 112, 0, 34), BackgroundColor3 = C.Well or C.Bg0, BorderSizePixel = 0, Text = filters.Text,
            PlaceholderText = "words: AK, crit, ring...", ClearTextOnFocus = false, Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Text, Parent = bar })
        do -- (UI CLEAN R-B2: the inventory's inset search field)
            local st = Instance.new("UIStroke"); st.Color = C.Line; st.Thickness = 1; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = box
            local pd = Instance.new("UIPadding"); pd.PaddingLeft = UDim.new(0, 10); pd.Parent = box
            box.TextXAlignment = Enum.TextXAlignment.Left; box.PlaceholderColor3 = C.Muted
            UIStyle.TextRole(box, "Body")
        end
        box.FocusLost:Connect(function(enter) filters.Text = box.Text; if enter then Render() end end)
        local go = UIStyle.Button(bar, "SEARCH", MC, UDim2.fromOffset(104, 34), UDim2.new(1, -104, 0, 0), "Search")
        go.Label.TextSize = 13
        go.Button.MouseButton1Click:Connect(function() filters.Text = box.Text; Render() end)
        local list = Scroll(UDim2.fromOffset(0, 44), UDim2.new(1, 0, 1, -44))
        Text({ LayoutOrder = 0, Size = UDim2.new(1, -8, 0, 20), Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, Text = "Loading...", Parent = list, Name = "Status" })
        task.spawn(function()
            local ok, res = Call("Browse", filters)
            if not list.Parent then return end
            local status = list:FindFirstChild("Status")
            if not ok or type(res) ~= "table" then if status then status.Text = tostring(res or "Couldn't load the Exchange.") end return end
            if status then status.Text = string.format("%d listing%s match  •  %d on the Exchange", #res.Results, #res.Results == 1 and "" or "s", res.Total or 0) end
            local me = game:GetService("Players").LocalPlayer.UserId
            if #res.Results == 0 then -- (UI v4: an empty Exchange says so, calmly)
                UIStyle.EmptyState(list, (res.Total or 0) > 0 and "Nothing matches" or "The Exchange is quiet",
                    (res.Total or 0) > 0 and "Loosen the filters or try other words." or "List something under SELL and every player can buy it, even while you're offline.",
                    { Size = UDim2.new(1, -8, 0, 140), LayoutOrder = 1 })
            end
            for i, s in ipairs(res.Results) do
                local mine = s.Seller == me
                ItemRow(list, i, s, PriceText(s.Price), mine and "YOURS" or "BUY", C.Steel, not mine, function() -- (UI CLEAN R-B2: BUY = secondary)
                    task.spawn(function()
                        local bok, msg = Call("Buy", s.Id)
                        if hooks.Toast then hooks.Toast(tostring(msg)) end
                        task.delay(0.3, function() if root.Visible and tab == "Browse" then Render() end end)
                    end)
                end)
            end
        end)
    end

    local function RenderMine()
        local head = UIStyle.Card(body, { Size = UDim2.new(1, 0, 0, 64) })
        local proceedsLbl = Text({ Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -200, 0, 24), Text = "YOUR PROCEEDS", TextSize = 17, TextColor3 = MC, Parent = head })
        local proceedsTxt = Text({ Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -200, 0, 22), Font = UIStyle.BodyFont, TextSize = 13, Text = "...", Parent = head })
        local col = UIStyle.Button(head, "COLLECT", MC, UDim2.fromOffset(160, 44), UDim2.new(1, -172, 0, 10), "Collect")
        col.Button.MouseButton1Click:Connect(function()
            if hooks.Click then hooks.Click() end
            task.spawn(function()
                local ok, msg = Call("Collect")
                if hooks.Toast then hooks.Toast(tostring(msg)) end
                task.delay(0.3, function() if root.Visible then Render() end end)
            end)
        end)
        local list = Scroll(UDim2.fromOffset(0, 72), UDim2.new(1, 0, 1, -72))
        task.spawn(function()
            local ok, res = Call("Mine")
            if not list.Parent or not ok or type(res) ~= "table" then return end
            local parts = {}
            for k, n in pairs(res.Proceeds or {}) do if n > 0 then table.insert(parts, ItemData.FormatNumber(n) .. " " .. CurName(k)) end end
            proceedsTxt.Text = (#parts > 0 and table.concat(parts, "  •  ") or "Nothing waiting.") .. string.format("   (sales tax %d%%)", math.round((res.Tax or 0.1) * 100))
            col.SetEnabled(#parts > 0)
            local open = 0
            for _, l in ipairs(res.Listings or {}) do if l.Status == "Open" then open += 1 end end
            proceedsLbl.Text = string.format("YOUR PROCEEDS  •  %d / %d listings open", open, res.Max or 10)
            if #(res.Listings or {}) == 0 then
                Text({ LayoutOrder = 1, Size = UDim2.new(1, -8, 0, 40), Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Sub, TextWrapped = true, Parent = list,
                    Text = "Nothing listed. Put items in a TRADE tab of your stash, then list them under SELL." })
            end
            for i, l in ipairs(res.Listings or {}) do
                local s = l.Summary
                if l.Status == "Open" then
                    ItemRow(list, i, s, PriceText(s.Price), "CANCEL", C.Steel, true, function()
                        task.spawn(function()
                            local cok, msg = Call("Cancel", s.Id)
                            if hooks.Toast then hooks.Toast(tostring(msg)) end
                            task.delay(0.3, function() if root.Visible then Render() end end)
                        end)
                    end, "listed")
                else
                    ItemRow(list, i, s, PriceText(s.Price), nil, nil, nil, nil, (l.Status == "Sold") and ("SOLD to " .. tostring(l.BuyerName or "a buyer")) or string.lower(l.Status or ""))
                end
            end
        end)
    end

    local function RenderSell()
        local st = hooks.GetState and hooks.GetState() or {}
        if (st.Level or 1) < 30 then
            Text({ Size = UDim2.new(1, 0, 0, 40), Font = UIStyle.BodyFont, TextSize = 15, TextColor3 = C.Gold, Text = "The Exchange opens at level 30.", Parent = body })
            return
        end
        local left = Scroll(UDim2.fromOffset(0, 0), UDim2.new(0.62, -8, 1, 0))
        local n = 0
        for _, t in ipairs(StashTabs.List(st)) do
            if t.Kind == "Trade" and t.Box then
                for _, pair in ipairs({ { t.Box.W or {}, "Weapon" }, { t.Box.G or {}, "Gear" } }) do
                    for _, it in ipairs(pair[1]) do
                        n += 1
                        local s = { Item = it, Kind = pair[2], Name = it.Name, Rarity = it.Rarity, BaseId = it.BaseId, Slot = it.Slot, ItemLevel = it.ItemLevel, Lines = {} }
                        for _, a in ipairs(ItemData.LinesOf(it, pair[2] == "Gear")) do table.insert(s.Lines, ItemData.FormatStat(a.Stat, a.Value)) end
                        local picked = sell.Pick and sell.Pick.Uid == it.Uid
                        ItemRow(left, n, s, nil, picked and "PICKED" or "PICK", picked and MC or C.Bg2, true, function()
                            sell.Pick = { Uid = it.Uid, Kind = pair[2], Tab = t.Id, Name = it.Name, Rarity = it.Rarity, BaseId = it.BaseId, Slot = it.Slot, Exotic = it.Exotic }; sell.Check = nil; Render()
                        end, t.Name)
                    end
                end
            end
        end
        for _, m in ipairs(st.Riftmods or {}) do
            n += 1
            local s = { Item = m, Kind = "Riftmod", Name = m.Name, Rarity = "Riftmod", BaseId = m.Gun, ItemLevel = m.ItemLevel, Lines = {} }
            for _, a in ipairs(m.Lines or {}) do table.insert(s.Lines, ItemData.FormatStat(a.Stat, a.Value)) end
            local picked = sell.Pick and sell.Pick.Uid == m.Uid
            ItemRow(left, n, s, nil, picked and "PICKED" or "PICK", picked and MC or C.Bg2, true, function()
                sell.Pick = { Uid = m.Uid, Kind = "Riftmod", Name = m.Name, BaseId = m.Gun }; sell.Check = nil; Render()
            end, "Gunwright bag")
        end
        do -- (UPDATE 8 phase 3) the mod bag
            local SMod = require(script.Parent:WaitForChild("ShotMods"))
            for _, m in ipairs(st.ShotMods or {}) do
                n += 1
                local s = { Item = m, Kind = "ShotMod", Name = "Mod: " .. SMod.Name(m), Rarity = "Mod", Lines = { SMod.Describe(m) } }
                local picked = sell.Pick and sell.Pick.Uid == m.Uid
                ItemRow(left, n, s, nil, picked and "PICKED" or "PICK", picked and MC or C.Bg2, true, function()
                    sell.Pick = { Uid = m.Uid, Kind = "ShotMod", Name = s.Name, Text = SMod.Name(m) }; sell.Check = nil; Render()
                end, "mod bag")
            end
        end
        if n == 0 then
            Text({ LayoutOrder = 1, Size = UDim2.new(1, -8, 0, 60), Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Sub, TextWrapped = true, Parent = left,
                Text = "Your TRADE tabs are empty. Move items into a TRADE tab of your hideout stash (inventory > STASH > TRADE), then come back to list them." })
        end
        local right = UIStyle.Card(body, { Position = UDim2.new(0.62, 0, 0, 0), Size = UDim2.new(0.38, 0, 1, 0) })
        Text({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 24), Text = "LIST IT", TextSize = 18, TextColor3 = MC, Parent = right })
        Text({ Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -28, 0, 40), Font = UIStyle.BodyFont, TextSize = 14, TextWrapped = true,
            Text = sell.Pick and tostring(sell.Pick.Name) or "Pick an item on the left.", TextColor3 = sell.Pick and C.Text or C.Sub, Parent = right })
        local cb = UIStyle.Button(right, "PAID IN: " .. string.upper(CurName(sell.Key)), C.Bg2, UDim2.new(1, -28, 0, 36), UDim2.fromOffset(14, 84), "Cur")
        cb.Label.TextSize = 13
        cb.Button.MouseButton1Click:Connect(function() if hooks.Click then hooks.Click() end; sell.Key = Cycle(CURRENCIES, sell.Key); sell.Check = nil; Render() end)
        local box = New("TextBox", { Position = UDim2.fromOffset(14, 128), Size = UDim2.new(1, -150, 0, 36), BackgroundColor3 = C.Well or C.Bg0, BorderSizePixel = 0, Text = sell.N,
            PlaceholderText = "price (a whole number)", ClearTextOnFocus = false, Font = UIStyle.BodyFont, TextSize = 16, TextColor3 = C.Text, Parent = right })
        box:GetPropertyChangedSignal("Text"):Connect(function() sell.N = string.gsub(box.Text, "[^%d]", "") end)
        -- (QOL2 I5 2026-10-28) PRICE CHECK: the 3 cheapest open listings like the picked item (same kind + rarity + gun base / gear
        -- slot, paid in the currency picked above), through the same Browse as the BROWSE tab (its 0.4 s server limit + 2 s here)
        local pcb = UIStyle.Button(right, "PRICE CHECK", C.Bg2, UDim2.fromOffset(114, 36), UDim2.new(1, -128, 0, 128), "PriceCheck")
        pcb.Label.TextSize = 12
        pcb.SetEnabled(sell.Pick ~= nil)
        local pcl = Text({ Position = UDim2.fromOffset(14, 168), Size = UDim2.new(1, -28, 0, 34), Font = UIStyle.BodyFont, TextSize = 12, TextWrapped = true,
            TextColor3 = sell.Check and sell.Check.Color or C.Sub, Text = sell.Check and sell.Check.Text or (sell.Pick and "PRICE CHECK: what the same item is listed for right now." or ""), Parent = right, Name = "PriceCheckText" })
        pcb.Button.MouseButton1Click:Connect(function()
            if not pcb.Button.Active then return end
            if hooks.Click then hooks.Click() end
            pcl.Text = "Checking..."
            task.spawn(function() api.PriceCheck(sell.Pick, sell.Key) end)
        end)
        Text({ Position = UDim2.fromOffset(14, 206), Size = UDim2.new(1, -28, 0, 60), Font = UIStyle.BodyFont, TextSize = 12, TextWrapped = true, TextColor3 = C.Sub,
            Text = "The item leaves your tab while it's listed. A sale pays the price minus a 10% tax (less with Marksman Grades 13 and 19) into your proceeds. Cancel any time before it sells.", Parent = right })
        local lb = UIStyle.Button(right, "LIST", MC, UDim2.new(1, -28, 0, 48), UDim2.new(0, 14, 1, -62), "List")
        lb.Label.TextSize = 18
        lb.SetEnabled(sell.Pick ~= nil)
        lb.Button.MouseButton1Click:Connect(function()
            if not lb.Button.Active then return end
            if hooks.Click then hooks.Click() end
            local pick = sell.Pick
            task.spawn(function()
                local ok, msg = Call("List", pick.Tab, pick.Kind, pick.Uid, sell.Key, tonumber(sell.N))
                if hooks.Toast then hooks.Toast(tostring(msg)) end
                if ok then sell.Pick = nil; sell.N = "" end
                task.delay(0.3, function() if root.Visible then Render() end end)
            end)
        end)
    end

    -- (QOL2 I5) PRICE CHECK for a sell pick { Kind, Rarity?, BaseId?, Slot?, Text? } in currency key -> sell.Check + a redraw.
    -- Your own listings are left out. Studio: Player attr DevPriceCheck = "Kind|Rarity|BaseId|Slot|Key[|show]" -> DevPriceCheckResult.
    local lastCheck = -10
    function api.PriceCheck(pick: any, key: string): string?
        if type(pick) ~= "table" then return nil end
        if os.clock() - lastCheck < 2 then
            sell.Check = { Text = "One check every 2 seconds.", Color = C.Sub }
            if root.Visible and tab == "Sell" then Render() end
            return sell.Check.Text
        end
        lastCheck = os.clock()
        local f = { Kind = pick.Kind, Currency = key, Sort = "Cheap", Text = pick.Text or "" }
        if pick.Kind == "Weapon" or pick.Kind == "Gear" then f.Rarity = pick.Rarity end
        if pick.Kind == "Weapon" or pick.Kind == "Riftmod" then f.BaseId = pick.BaseId end
        if pick.Kind == "Gear" then f.Slot = pick.Slot end
        if type(pick.Exotic) == "string" then f.Exotic = pick.Exotic end -- (CHASE ITEMS: a relic / Zenith checks against the same named item)
        local ok, res = Call("Browse", f)
        local me = game:GetService("Players").LocalPlayer.UserId
        if not ok or type(res) ~= "table" then
            sell.Check = { Text = "Couldn't check: " .. tostring(res or "try again."), Color = C.Sub }
        else
            local prices, n = {}, 0
            for _, s in ipairs(res.Results or {}) do
                if s.Seller ~= me and s.Price and s.Price.Key == key then
                    n += 1
                    if #prices < 3 then table.insert(prices, ItemData.FormatNumber(s.Price.N)) end
                end
            end
            local like = (pick.Kind == "Weapon" or pick.Kind == "Gear") and (tostring(pick.Rarity or "") .. " ") or ""
            if n == 0 then
                sell.Check = { Text = "No " .. like .. "listings like it for " .. CurName(key) .. " right now: you set the price.", Color = C.Sub }
            else
                sell.Check = { Text = "Cheapest now: " .. table.concat(prices, "  •  ") .. " " .. CurName(key) .. "  (" .. n .. (n >= 60 and "+" or "") .. " listed)", Color = C.Gold }
            end
        end
        if root.Visible and tab == "Sell" then Render() end
        return sell.Check.Text
    end
    if game:GetService("RunService"):IsStudio() then
        local lp = game:GetService("Players").LocalPlayer
        lp:GetAttributeChangedSignal("DevPriceCheck"):Connect(function()
            local p = string.split(tostring(lp:GetAttribute("DevPriceCheck") or ""), "|")
            local function V(i) return (p[i] and p[i] ~= "") and p[i] or nil end
            lastCheck = -10
            local pick = { Kind = V(1) or "Weapon", Rarity = V(2), BaseId = V(3), Slot = V(4) }
            if V(6) == "show" then -- (6th field "show": the SELL tab with this as the pick, to see the card)
                tab = "Sell"; sell.Pick = pick; sell.Key = V(5) or "Gold"
                pick.Name = "Studio check: " .. tostring(pick.Rarity or "") .. " " .. tostring(pick.BaseId or pick.Slot or pick.Kind)
                api.Open("Sell")
            end
            local r = api.PriceCheck(pick, V(5) or "Gold")
            lp:SetAttribute("DevPriceCheckResult", tostring(r))
        end)
    end
    Render = function()
        Clear()
        for id, b in pairs(tabBtns) do b.SetSelected(id == tab) end -- (v4 NEON)
        if tab == "Browse" then RenderBrowse() elseif tab == "Mine" then RenderMine() else RenderSell() end
    end
    function api.Open(t: string?)
        if t == "Browse" or t == "Mine" or t == "Sell" then tab = t end
        Render()
        if not root.Visible and hooks.OpenFrame then hooks.OpenFrame(root) end
    end
    function api.Refresh() if root.Visible and tab == "Sell" then Render() end end
    api.Frame = root
    if game:GetService("RunService"):IsStudio() then -- (Studio: Player attr DevMarketTab = Browse | Mine | Sell)
        local lp0 = game:GetService("Players").LocalPlayer
        lp0:GetAttributeChangedSignal("DevMarketTab"):Connect(function()
            local t = lp0:GetAttribute("DevMarketTab")
            if t == "Browse" or t == "Mine" or t == "Sell" then tab = t; if root.Visible then Render() end end
        end)
    end
    return api
end

return MarketMenu
