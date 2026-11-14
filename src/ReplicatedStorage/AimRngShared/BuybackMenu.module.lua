--!nocheck
-- BUYBACK (QOL2 I3 2026-10-28), the client half: a "BUYBACK n" button left of the BAG count in the inventory's bag column
-- (hidden until you've sold something this session: Player attr BuybackCount, set by AimRngServer/Buyback) opens a panel
-- over the bag list with the last 10 items you sold (row sell, SELL UP TO, auto-sell), newest first: rarity symbol + name,
-- type / slot, and a BUY <gold> button (the price it sold for). The server checks everything (gold, bag room, still listed).
-- Nothing runs per frame; the list is fetched when the panel opens and again when the count changes while it's open.
-- Studio hooks (Player attrs): DevBuyback = "open" | "close" | "buy:<n>" (n-th row, 1 = newest) | "buyuid:<uid>" |
-- "sellw:<n>" / "sellg:<n>" (sell the n-th unequipped bag weapon / gear through the real remotes) | "sellupto:<rarity>"
-- -> DevBuybackResult.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AimRngShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local InvLayout = require(script.Parent:WaitForChild("InvLayout")) -- (UI CLEAN R-B)
local ItemData = require(Shared:WaitForChild("ItemData"))
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local GameSettings = require(Shared:WaitForChild("GameSettings"))

local LocalPlayer = Players.LocalPlayer
local BuybackMenu = {}

local C = Color3.fromRGB
local GOLD = C(255, 200, 70)

-- h = { Panel, Search, InvFrame, Toast(text), Tooltip(gui, item, isGear), Refresh(), Click(), Coin(), Gold() -> number,
--       State() -> clientState, PadMenus() -> PadMenus? }
function BuybackMenu.Init(h: any)
    local panelParent = h.Panel
    local busy = false
    local entries = {}

    -- the button, left of the BAG count (the search box gives up the room only while it shows)
    local btn = Instance.new("TextButton")
    btn.Name = "BuybackButton"
    btn.AutoButtonColor = true
    btn.BackgroundColor3 = C(60, 52, 30)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextColor3 = GOLD
    btn.Text = "BUYBACK"
    btn.Position = UDim2.new(1, -222, 0, 112)
    btn.Size = UDim2.fromOffset(100, 26)
    btn.Visible = false
    btn.Parent = panelParent
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn end

    -- the panel over the bag list
    local panel = Instance.new("Frame")
    panel.Name = "BuybackPanel"
    panel.Position = UDim2.new(0, 10, 0, 144)
    panel.Size = UDim2.new(1, -20, 1, -152)
    panel.BackgroundColor3 = UIStyle.Colors.Bg0
    panel.BorderSizePixel = 0
    panel.ZIndex = 20
    panel.Visible = false
    panel.Parent = panelParent
    do
        local st = Instance.new("UIStroke"); st.Color = UIStyle.Colors.Text; st.Transparency = 0.86; st.Thickness = 1; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = panel
    end
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(10, 6); title.Size = UDim2.new(1, -60, 0, 20)
    title.Font = UIStyle.Font; title.TextSize = 16; title.TextColor3 = GOLD
    UIStyle.TextRole(title, "SectionHead")
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "BUYBACK"
    title.ZIndex = 21
    title.Parent = panel
    local sub = Instance.new("TextLabel")
    sub.BackgroundTransparency = 1
    sub.Position = UDim2.fromOffset(10, 26); sub.Size = UDim2.new(1, -20, 0, 16)
    sub.Font = Enum.Font.GothamMedium; sub.TextSize = 12; sub.TextColor3 = UIStyle.Colors.Sub
    UIStyle.TextRole(sub, "Meta")
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Text = "Your last 10 sales, for what they sold for. Cleared when you leave."
    sub.TextTruncate = Enum.TextTruncate.AtEnd
    sub.ZIndex = 21
    sub.Parent = panel
    local close = Instance.new("TextButton")
    close.Name = "Close"
    close.BackgroundColor3 = C(40, 42, 56); close.BorderSizePixel = 0
    close.Position = UDim2.new(1, -34, 0, 6); close.Size = UDim2.fromOffset(26, 22)
    close.Font = Enum.Font.GothamBold; close.TextSize = 13; close.TextColor3 = UIStyle.Colors.Text; close.Text = "X"
    close.ZIndex = 22
    close.Parent = panel
    local list = Instance.new("ScrollingFrame")
    list.Position = UDim2.fromOffset(6, 48); list.Size = UDim2.new(1, -12, 1, -54)
    list.BackgroundTransparency = 1; list.BorderSizePixel = 0
    list.ScrollBarThickness = 5
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y; list.CanvasSize = UDim2.new()
    list.ZIndex = 21
    list.Parent = panel
    local lay = Instance.new("UIListLayout"); lay.Padding = UDim.new(0, 4); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Parent = list

    local function SetShown(count: number)
        local on = count > 0
        btn.Visible = on
        btn.Text = "BUYBACK " .. count
        h.Search.Size = on and UDim2.new(1, -236, 0, 26) or UDim2.new(1, -130, 0, 26)
        if not on then panel.Visible = false end
    end

    local Buy
    local function Draw()
        for _, c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local gold = h.Gold() or 0
        for i, e in ipairs(entries) do
            local item = e.Item
            local isGear = e.Kind == "Gear"
            local col = ItemData.ItemColor(item)
            -- (UI CLEAN R-B: the shared item row card -- rarity edge + tint, display name, sub-line, icon in its own box)
            local what = isGear and tostring(ItemData.GearSlotLabels[item.Slot or ""] or item.Slot or "Gear") or ItemData.WeaponTypeLine(item)
            local r = InvLayout.ItemRow(list, { Item = item, Color = col, Order = i, Height = 50, RightPad = 88, ArtW = 48, ArtH = 20,
                Name = (GameSettings.Get("RaritySymbols") ~= false) and ItemData.SymbolName(item) or ItemData.DisplayName(item),
                Sub = ItemData.RarityLabel(item) .. " " .. what .. "  •  iLvl " .. tostring(item.ItemLevel or 1) })
            local row = r.Btn
            row.Name = "BuybackRow"
            row.Size = UDim2.new(1, -6, 0, 50)
            local can = gold >= (e.Gold or 0)
            local b = UIStyle.Button(row, "BUY " .. ItemData.FormatNumber(e.Gold or 0) .. "g", can and UIStyle.Colors.Gold or UIStyle.Colors.Steel,
                UDim2.fromOffset(84, 30), UDim2.new(1, -(r.Reserved + 86), 0.5, -16), "Buy")
            b.Label.TextSize = 13
            b.SetEnabled(can)
            b.Button.MouseButton1Click:Connect(function() Buy(e) end)
            if h.Tooltip then h.Tooltip(row, item, isGear) end
        end
        if #entries == 0 then
            local l = Instance.new("TextLabel")
            l.BackgroundTransparency = 1; l.Size = UDim2.new(1, -6, 0, 40)
            l.Font = Enum.Font.GothamMedium; l.TextSize = 13; l.TextColor3 = UIStyle.Colors.Sub
            l.Text = "Nothing to buy back."
            l.ZIndex = 22
            l.Parent = list
        end
    end

    local function Fetch()
        local ok, res = pcall(function() return Remotes.GetFunction("Buyback"):InvokeServer("List") end)
        entries = (ok and type(res) == "table") and res or {}
        if panel.Visible then Draw() end
    end

    Buy = function(e: any): (boolean, string?)
        if busy or not e then return false, "busy" end
        busy = true
        local ok, okBuy, msg = pcall(function() return Remotes.GetFunction("Buyback"):InvokeServer("Buy", e.Uid) end)
        busy = false
        if not ok then return false, "error" end
        if okBuy then h.Coin() else h.Click() end
        if msg and msg ~= "" then h.Toast(msg) end
        Fetch()
        if okBuy then h.Refresh() end
        return okBuy == true, msg
    end

    local function Open(on: boolean)
        panel.Visible = on
        if on then
            entries = {}
            Draw()
            Fetch()
            local pm = h.PadMenus and h.PadMenus()
            if pm and pm.IsPad() then -- (a pad: the newest row, its card beside it (I1); D-pad right = its BUY)
                task.delay(0.35, function()
                    if not panel.Visible then return end
                    local first = nil
                    for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") and c.LayoutOrder == 1 then first = c end end
                    pcall(function() game:GetService("GuiService").SelectedObject = first or close end)
                end)
            end
        end
    end
    btn.MouseButton1Click:Connect(function() h.Click(); Open(not panel.Visible) end)
    close.MouseButton1Click:Connect(function() h.Click(); Open(false) end)
    h.InvFrame:GetPropertyChangedSignal("Visible"):Connect(function() if not h.InvFrame.Visible then panel.Visible = false end end)
    local function OnCount()
        local n = tonumber(LocalPlayer:GetAttribute("BuybackCount")) or 0
        SetShown(n)
        if panel.Visible then Fetch() end
    end
    LocalPlayer:GetAttributeChangedSignal("BuybackCount"):Connect(OnCount)
    OnCount()

    BuybackMenu.Open = Open
    BuybackMenu.IsOpen = function() return panel.Visible end

    if RunService:IsStudio() then
        LocalPlayer:GetAttributeChangedSignal("DevBuyback"):Connect(function()
            local v = tostring(LocalPlayer:GetAttribute("DevBuyback") or "")
            local act, arg = string.match(v, "^(%a+):?(.*)$")
            local res = "?"
            if act == "open" then Open(true); task.wait(0.5); res = "open " .. #entries
            elseif act == "close" then Open(false); res = "closed"
            elseif act == "list" then Fetch(); local t = {} for _, e in ipairs(entries) do table.insert(t, tostring(e.Item.Name) .. "=" .. tostring(e.Gold)) end res = #entries .. ": " .. table.concat(t, ", ")
            elseif act == "buy" then Fetch(); local e = entries[tonumber(arg) or 1]; local ok, msg = Buy(e); res = tostring(ok) .. " " .. tostring(msg)
            elseif act == "buyuid" then local ok, msg = Buy({ Uid = arg }); res = tostring(ok) .. " " .. tostring(msg)
            elseif act == "sellw" or act == "sellg" then
                local st = h.State()
                local listOf = (act == "sellg") and (st.GearInventory or {}) or (st.Inventory or {})
                local n, pick = 0, nil
                for _, it in ipairs(listOf) do
                    if not (st.EquippedWeapon and it.Uid == st.EquippedWeapon.Uid) and it.Uid ~= "W_STARTER_PISTOL" and not it.Locked then
                        n += 1
                        if n == (tonumber(arg) or 1) then pick = it end
                    end
                end
                if pick then
                    local ok, g = Remotes.GetFunction(act == "sellg" and "SellGear" or "SellWeapon"):InvokeServer(pick.Uid)
                    res = tostring(ok) .. " " .. tostring(pick.Name) .. " " .. tostring(g) .. " " .. pick.Uid
                    h.Refresh()
                else res = "no item" end
            elseif act == "sellupto" then
                local c, g = Remotes.GetFunction("QuickSellRarity"):InvokeServer(arg, "AllUpTo")
                res = tostring(c) .. " sold for " .. tostring(g)
                h.Refresh()
            end
            LocalPlayer:SetAttribute("DevBuybackResult", res)
        end)
    end
end

return BuybackMenu
