--!nocheck
-- ============================================================================================
-- STASH TABS (UPDATE 7 C7 "Stash v2", owner's final tab table in vault "UPDATE 7 - Depth": 1 free general, 1 free trade,
-- 1 free skin tab; more general / trade tabs 49, special tabs 99; 2026-10-20 owner "Stashes and such should cost
-- boundpoints": the one-off 1,000,000 gold trade tab is gone -- a tab already bought with gold stays).
-- Every buy goes through BoundShop.Confirm (the price, your balance, how many more you need).
-- Prices in BOUND points (1 BP ~ 1 R$: every hideout Robux buy goes through BOUND points since 0.97), so no new
-- developer products are needed.
--
-- NOTHING MOVES IN OLD SAVES: tab "STASH" IS the old state.Hideout.Stash (its cap still grows with the bought expansions).
-- Extra tabs live in state.Hideout.Tabs = { { Id, Kind, Name, W = {}, G = {} } } (the free TRADE tab is added on load).
-- "SKINS" is a view of your tradeable cosmetics + copies (nothing is stored there). Trade tabs are storage until the
-- market ships (they'll be what you list from). Special GEM / MAP tabs: not built yet (the gem bag + sigils keep their
-- own storage), listed here as "coming".
-- Server: Hideouts HideoutAction Store / Take (4th arg = tab id; nil = STASH) + BuyTab(kind) + RenameTab(id, name).
-- ============================================================================================
local StashTabs = {}

StashTabs.TAB_CAP = 100 -- (items in every tab but STASH; STASH keeps HideoutData.StashCap)
StashTabs.MAX_TABS = 40 -- (bought tabs, a sanity cap on the save's size)
StashTabs.Kinds = {
    General = { Name = "STASH", Color = Color3.fromRGB(150, 110, 40), BP = 49, Text = "100 more items." },
    Trade = { Name = "TRADE", Color = Color3.fromRGB(80, 170, 120), BP = 49, Text = "Items you list on the Exchange come from these." },
    -- SPECIAL TABS (owner: "Special tabs (currency / gem / map) 99 R$ each" -> BOUND points like the others): not item boxes, they raise a
    -- bag's room (state.Hideout.Special = { Gem = n, Map = n }, SPECIAL_MAX each). A currency tab isn't needed: currencies have no cap.
    Gem = { Name = "GEM", Color = Color3.fromRGB(170, 120, 255), BP = 99, Special = true, Extra = 50, Text = "+50 room in your gem bag." },
    Map = { Name = "MAP", Color = Color3.fromRGB(120, 180, 255), BP = 99, Special = true, Extra = 30, Text = "+30 room for maps (sigils)." },
}
StashTabs.SPECIAL_MAX = 5
function StashTabs.Special(st: any, kind: string): number
    local h = type(st) == "table" and type(st.Hideout) == "table" and st.Hideout or {}
    local s = type(h.Special) == "table" and h.Special or {}
    return math.clamp(math.floor(tonumber(s[kind]) or 0), 0, StashTabs.SPECIAL_MAX)
end
-- the gem bag / map bag caps with the special tabs
function StashTabs.GemCap(st: any): number
    return require(script.Parent:WaitForChild("GemData")).MAX_OWNED + StashTabs.Kinds.Gem.Extra * StashTabs.Special(st, "Gem")
end
function StashTabs.SigilCap(st: any): number
    return require(script.Parent:WaitForChild("Rifts")).MAX_SIGILS + StashTabs.Kinds.Map.Extra * StashTabs.Special(st, "Map")
end

local function HD() return require(script.Parent:WaitForChild("HideoutData")) end

-- the save's hideout table with Tabs normalised (both sides; the server also adds the free TRADE tab)
function StashTabs.Ensure(st: any): any
    local h = type(st) == "table" and type(st.Hideout) == "table" and st.Hideout or {}
    h.Tabs = type(h.Tabs) == "table" and h.Tabs or {}
    for _, t in ipairs(h.Tabs) do
        t.W = type(t.W) == "table" and t.W or {}
        t.G = type(t.G) == "table" and t.G or {}
    end
    local hasTrade = false
    for _, t in ipairs(h.Tabs) do if t.Id == "TRADE1" then hasTrade = true end end
    if not hasTrade then table.insert(h.Tabs, 1, { Id = "TRADE1", Kind = "Trade", Name = "TRADE", W = {}, G = {} }) end
    return h
end

-- every tab in order: STASH, the extra tabs, SKINS  ->  { Id, Kind, Name, Color, Box? }
function StashTabs.List(st: any): { any }
    local h = type(st) == "table" and type(st.Hideout) == "table" and st.Hideout or {}
    local out = { { Id = "STASH", Kind = "General", Name = "STASH", Color = StashTabs.Kinds.General.Color, Box = type(h.Stash) == "table" and h.Stash or { W = {}, G = {} } } }
    for _, t in ipairs(type(h.Tabs) == "table" and h.Tabs or {}) do
        local k = StashTabs.Kinds[t.Kind] or StashTabs.Kinds.General
        table.insert(out, { Id = t.Id, Kind = t.Kind, Name = t.Name or k.Name, Color = k.Color, Box = t })
    end
    table.insert(out, { Id = "SKINS", Kind = "Skin", Name = "SKINS", Color = Color3.fromRGB(190, 120, 255) })
    return out
end

-- a tab's item box ({ W, G }) or nil (SKINS / unknown)
function StashTabs.Box(st: any, id: string?): any
    for _, t in ipairs(StashTabs.List(st)) do if t.Id == (id or "STASH") then return t.Box end end
    return nil
end
function StashTabs.Count(box: any): number
    if type(box) ~= "table" then return 0 end
    return #(type(box.W) == "table" and box.W or {}) + #(type(box.G) == "table" and box.G or {})
end
function StashTabs.Cap(st: any, id: string?): number
    if (id or "STASH") == "STASH" then local H = HD() return H.StashCap(H.ExpLevel(st)) end
    return StashTabs.TAB_CAP
end
-- every item box (STASH + tabs): for "find anywhere" checks (racks, exotics, the archive)
function StashTabs.AllBoxes(st: any): { any }
    local out = {}
    for _, t in ipairs(StashTabs.List(st)) do if t.Box then table.insert(out, t.Box) end end
    return out
end
-- bought tabs of a kind (the free TRADE1 doesn't count)
function StashTabs.Bought(st: any, kind: string): number
    local n = 0
    local h = type(st) == "table" and type(st.Hideout) == "table" and st.Hideout or {}
    for _, t in ipairs(type(h.Tabs) == "table" and h.Tabs or {}) do if t.Kind == kind and t.Id ~= "TRADE1" then n += 1 end end
    return n
end

-- ==================== CLIENT VIEW (AimRngClient's inventory STASH tab) ====================
-- the strip of tab chips (+ BUY TAB) as the first row of the stash list
function StashTabs.RenderStrip(scroll: ScrollingFrame, st: any, current: string, onPick: (string) -> (), onBuy: () -> (), onMarket: (() -> ())?)
    local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
    local row = Instance.new("ScrollingFrame")
    row.Name = "StashTabStrip"
    row.LayoutOrder = -2
    row.Size = UDim2.new(1, -6, 0, 34)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.ScrollBarThickness = 3
    row.ScrollingDirection = Enum.ScrollingDirection.X
    row.AutomaticCanvasSize = Enum.AutomaticSize.X
    row.CanvasSize = UDim2.new()
    row.Parent = scroll
    local ll = Instance.new("UIListLayout")
    ll.FillDirection = Enum.FillDirection.Horizontal
    ll.Padding = UDim.new(0, 4)
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Parent = row
    for i, t in ipairs(StashTabs.List(st)) do
        local on = t.Id == current
        local b = Instance.new("TextButton")
        b.Name = "Tab_" .. t.Id
        b.LayoutOrder = i
        b.AutoButtonColor = false
        -- (UI CLEAN R-B: the stash tabs are words like the bag tabs -- Sub, the open one off-white with a 2 px underline; the
        -- tab's own colour is a small square before its name, not a coloured box)
        b.Size = UDim2.fromOffset(0, 30)
        b.AutomaticSize = Enum.AutomaticSize.X
        b.BackgroundTransparency = 1
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold
        b.RichText = true
        local n = t.Box and ("  " .. StashTabs.Count(t.Box)) or ""
        b.Text = string.format('<font color="#%s">■</font> %s<font color="#%s">%s</font>  ', t.Color:ToHex(), string.upper(t.Name), UIStyle.Colors.Muted:ToHex(), n)
        UIStyle.TextRole(b, "Tab", { Color = on and "Text" or "Sub" })
        b:SetAttribute("NoNeon", true); b:SetAttribute("Skinned", true)
        if on then
            local u = Instance.new("Frame"); u.Name = "Under"; u.BorderSizePixel = 0; u.BackgroundColor3 = UIStyle.Colors.Text
            u.AnchorPoint = Vector2.new(0, 1); u.Position = UDim2.new(0, 0, 1, 0); u.Size = UDim2.new(1, -8, 0, 2); u:SetAttribute("Skinned", true); u.Parent = b
        end
        b.Parent = row
        b.MouseButton1Click:Connect(function() onPick(t.Id) end)
    end
    local buy = Instance.new("TextButton")
    buy.Name = "BuyTab"
    buy.LayoutOrder = 999
    buy.AutoButtonColor = false
    buy.Size = UDim2.fromOffset(86, 30)
    buy.BackgroundTransparency = 1 -- (UI CLEAN R-B: a quiet outline, not a gold slab)
    buy.BorderSizePixel = 0
    buy.Font = Enum.Font.GothamBlack
    buy.TextSize = 13
    buy.TextColor3 = UIStyle.Colors.Text
    buy.Text = "+ TAB"
    UIStyle.TextRole(buy, "Button")
    buy:SetAttribute("NoNeon", true); buy:SetAttribute("Skinned", true)
    do local st = Instance.new("UIStroke"); st.Color = UIStyle.Colors.Text; st.Transparency = 0.84; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = buy end
    buy.Size = UDim2.fromOffset(70, 28)
    buy.Parent = row
    buy.MouseButton1Click:Connect(onBuy)
    if onMarket and not UIStyle.NavOpen then -- (UPDATE 7 C7: the market, from the stash; UI CLEAN R-B: the top bar's EXCHANGE does it now)
        local mk = buy:Clone()
        mk.Name = "Market"
        mk.LayoutOrder = 1000
        mk.Size = UDim2.fromOffset(96, 30)
        mk.BackgroundColor3 = Color3.fromRGB(110, 230, 150)
        mk.Text = "EXCHANGE"
        mk.Parent = row
        mk.MouseButton1Click:Connect(onMarket)
    end
    return row
end

-- the buy list (a small card under the strip): kind, price(s), BUY buttons -> buy(kind, currency)
function StashTabs.RenderBuy(scroll: ScrollingFrame, st: any, buy: (string, string) -> ())
    local card = Instance.new("Frame")
    card.Name = "BuyTabs"
    card.LayoutOrder = -1
    card.Size = UDim2.new(1, -6, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = Color3.fromRGB(22, 23, 28)
    card.BorderSizePixel = 0
    card.Parent = scroll
    local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 8); pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10); pad.Parent = card
    local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 6); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = card
    local function Line(order: number, text: string, col: Color3, buttons: { any })
        local f = Instance.new("Frame"); f.LayoutOrder = order; f.BackgroundTransparency = 1; f.Size = UDim2.new(1, 0, 0, 30); f.Parent = card
        local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Size = UDim2.new(1, -124 * math.max(1, #buttons) - 6, 1, 0); l.Font = Enum.Font.GothamMedium; l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left; l.TextWrapped = true; l.TextColor3 = col; l.Text = text; l.Parent = f
        for i, bt in ipairs(buttons) do
            local b = Instance.new("TextButton"); b.Size = UDim2.fromOffset(118, 26); b.Position = UDim2.new(1, -124 * (#buttons - i + 1), 0.5, -13)
            b.BackgroundColor3 = bt.Color; b.BorderSizePixel = 0; b.Font = Enum.Font.GothamBold; b.TextSize = 12; b.TextColor3 = Color3.fromRGB(20, 20, 24)
            b.Text = bt.Text; b.AutoButtonColor = true; b.Parent = f
            b.MouseButton1Click:Connect(bt.Fn)
        end
    end
    local BP = Color3.fromRGB(150, 200, 255)
    Line(1, "GENERAL TAB: " .. StashTabs.Kinds.General.Text, Color3.fromRGB(220, 222, 230),
        { { Text = StashTabs.Kinds.General.BP .. " BOUND", Color = BP, Fn = function() buy("General", "BP") end } })
    Line(2, "TRADE TAB: " .. StashTabs.Kinds.Trade.Text, Color3.fromRGB(220, 222, 230),
        { { Text = StashTabs.Kinds.Trade.BP .. " BOUND", Color = BP, Fn = function() buy("Trade", "BP") end } })
    for i, kind in ipairs({ "Gem", "Map" }) do
        local d = StashTabs.Kinds[kind]
        local have = StashTabs.Special(st, kind)
        Line(2 + i, d.Name .. " TAB: " .. d.Text .. "  (you have " .. have .. " / " .. StashTabs.SPECIAL_MAX .. ")", Color3.fromRGB(220, 222, 230),
            (have < StashTabs.SPECIAL_MAX) and { { Text = d.BP .. " BOUND", Color = BP, Fn = function() buy(kind, "BP") end } } or {})
    end
end

-- the SKINS tab: every tradeable cosmetic you own, with your copies
function StashTabs.RenderSkins(scroll: ScrollingFrame, st: any)
    local Cosmetics = require(script.Parent:WaitForChild("Cosmetics"))
    local rows = {}
    for _, e in ipairs(Cosmetics.All()) do
        if Cosmetics.Tradeable(e) and Cosmetics.Owns(st, e) then table.insert(rows, e) end
    end
    table.sort(rows, function(a, b) if a.Cat ~= b.Cat then return tostring(a.Cat) < tostring(b.Cat) end return tostring(a.Name) < tostring(b.Name) end)
    for i, e in ipairs(rows) do
        local f = Instance.new("Frame"); f.LayoutOrder = i; f.Size = UDim2.new(1, -6, 0, 34); f.BackgroundColor3 = Color3.fromRGB(24, 25, 30); f.BorderSizePixel = 0; f.Parent = scroll
        local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Position = UDim2.fromOffset(10, 0); l.Size = UDim2.new(1, -130, 1, 0); l.Font = Enum.Font.GothamBold
        l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextColor3 = Color3.fromRGB(225, 228, 236); l.Text = tostring(e.Name); l.Parent = f
        local r = Instance.new("TextLabel"); r.BackgroundTransparency = 1; r.Position = UDim2.new(1, -120, 0, 0); r.Size = UDim2.fromOffset(110, 34); r.Font = Enum.Font.GothamMedium
        r.TextSize = 12; r.TextXAlignment = Enum.TextXAlignment.Right; r.TextColor3 = Color3.fromRGB(160, 164, 176)
        local cat = Cosmetics.CategoryById and Cosmetics.CategoryById[e.Cat]
        r.Text = string.upper(tostring(cat and cat.Label or e.Cat)) .. "  x" .. Cosmetics.Copies(st, e); r.Parent = f
    end
    if #rows == 0 then
        local l = Instance.new("TextLabel"); l.LayoutOrder = 1; l.BackgroundTransparency = 1; l.Size = UDim2.new(1, 0, 0, 40); l.Font = Enum.Font.GothamMedium; l.TextSize = 13
        l.TextWrapped = true; l.TextColor3 = Color3.fromRGB(150, 154, 166); l.Text = "No tradeable skins yet. Store skins and season pieces show here with how many copies you own."; l.Parent = scroll
    end
end

return StashTabs
