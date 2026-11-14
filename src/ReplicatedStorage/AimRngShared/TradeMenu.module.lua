--!nocheck
-- TradeMenu (0.55): the client side of TradeService.
--   * TRADE window: with no trade open, a list of players in the server (REQUEST) and requests you got (ACCEPT);
--     during a trade: YOUR STASH (ITEMS / SKINS, click to add) | YOUR OFFER (+ gold) | THEIR OFFER (+ gold), READY -> CONFIRM.
--     (2026-10-14) SKINS = every Cosmetics.Tradeable piece you own, with its copy count (Cosmetics.Copies): each click puts
--     one more copy in; the server re-checks the counts at the swap. Giving nothing back (a gift) is fine.
--   * the incoming-request popup (top of the screen, outside the menu folder so it never closes your window).
-- Built by AimRngClient: TradeMenu.Build(menuFolder, hudGui, hooks). Every rule is checked again on the server.
local Players = game:GetService("Players")
local Shared = script.Parent
local InvLayout = require(script.Parent:WaitForChild("InvLayout")) -- (UI CLEAN R-B)
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))

local TradeMenu = {}
local C = UIStyle.Colors
local New = UIStyle.New
local ACCENT = Color3.fromRGB(64, 200, 160)
local LocalPlayer = Players.LocalPlayer

function TradeMenu.Build(menuFolder: Instance, hudGui: Instance, hooks: any)
    local api = {}
    local session = nil -- the last Snapshot from the server (nil = no trade open)
    local incoming = {} -- [userId] = { From, FromId, Until }
    local busy = false
    local stashTab = "Items" -- (column 1: "Items" | "Skins")

    -- (0.62, owner: "When taking an item out of a trade or putting something back, the trade bugs out and doesn't go
    -- through"): a click while the last one was still on its way used to be DROPPED (take out + put back = the put-back
    -- vanished). Clicks now wait their turn.
    local function Act(...)
        local t0 = os.clock()
        while busy and os.clock() - t0 < 4 do task.wait(0.03) end
        if busy then return false end
        busy = true
        local ok, a, b = pcall(function(...) return Remotes.GetFunction("TradeAction"):InvokeServer(...) end, ...)
        busy = false
        if not ok then return false, "Couldn't reach the server." end
        if a == false and b then hooks.Toast(b) end
        return a, b
    end

    -- ===== the window =====
    local panel = UIStyle.Panel(menuFolder, { Name = "TradeMenu", Size = UDim2.fromOffset(980, 640), Accent = ACCENT })
    local bar = UIStyle.TitleBar(panel, "TRADE", ACCENT, "swap guns, gear, skins, gold and BOUND points with another player", function()
        hooks.CloseAll()
    end)
    local body = New("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 1, -92), Parent = panel })
    panel:SetAttribute("PhoneMinH", 300) -- (2026-10-13 phones: as tall as the screen; the lists scroll)

    local function Clear(f: Instance) for _, c in ipairs(f:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end end
    local function Header(parent, text, y)
        -- (Update 5: section-header style -- condensed caps in the secondary colour, not gold)
        local h = UIStyle.Text({ Text = text, TextSize = 16, TextColor3 = C.Sub, Position = UDim2.fromOffset(0, y or 0), Size = UDim2.new(1, 0, 0, 24), Parent = parent })
        h:SetAttribute("TypeRole", "Label")
        return h
    end
    -- (owner 2026-10-07: "When trading and adding items, the menu jumps back up") every redraw rebuilt the lists at the
    -- top; a keyed list remembers where you'd scrolled to
    local scrollMem = {}
    local function Scroll(parent, pos, size, key: string?)
        local sf = New("ScrollingFrame", { BackgroundColor3 = C.CardDark, BorderSizePixel = 0, Position = pos, Size = size, ScrollBarThickness = 6,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = parent }, { UIStyle.Corner(2) })
        New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf })
        New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), Parent = sf })
        if key then
            local want = scrollMem[key]
            if want then
                -- (the canvas only grows once the rows are laid out: put the scroll back after that)
                task.defer(function() if sf.Parent then sf.CanvasPosition = want end end)
                task.delay(0.05, function() if sf.Parent then sf.CanvasPosition = want end end)
            end
            sf:GetPropertyChangedSignal("CanvasPosition"):Connect(function() scrollMem[key] = sf.CanvasPosition end)
        end
        return sf
    end
    -- one item row: colour bar, name (exotic orange / rarity), type line; click = onClick
    local function ItemRow(parent, entry, order, onClick, tag)
        local it, isGear = entry.Item, entry.Kind == "Gear"
        local isMod = entry.Kind == "Riftmod" -- (UPDATE 7)
        local SMod = (entry.Kind == "ShotMod") and require(script.Parent:WaitForChild("ShotMods")) or nil -- (UPDATE 8 phase 3: shot mods)
        local smDef = SMod and SMod.Def(it)
        local col = smDef and SMod.COLOR[smDef.Color] or isMod and Color3.fromRGB(120, 200, 255) or ItemData.ItemColor(it)
        local sub = smDef and (SMod.COLOR_NAME[smDef.Color] .. " socket  •  " .. SMod.Describe(it)) or isMod and require(script.Parent:WaitForChild("Riftmods")).LinesText(it) or isGear and (ItemData.RarityLabel(it) .. " " .. tostring(it.Slot or "gear") .. "  •  iLvl " .. tostring(it.ItemLevel or 1) .. (it.Twinned and "  •  TWINNED" or ""))
            or (ItemData.RarityLabel(it) .. "  •  " .. ItemData.WeaponTypeLine(it) .. "  •  iLvl " .. tostring(it.ItemLevel or 1) .. (it.Twinned and "  •  TWINNED" or "")) -- (CHASE ITEMS review: ZENITH label + a twinned item says so on its row)
        -- (UI CLEAN R-B: the shared item row card)
        local row = InvLayout.ItemRow(parent, { Item = it, Color = col, Order = order, Height = 50, NoIcon = (isMod or smDef) and true or nil, Tag = tag, TagColor = C.Text,
            Name = smDef and ("Mod: " .. SMod.Name(it)) or isMod and tostring(it.Name) or ItemData.DisplayName(it), Sub = sub }).Btn
        if onClick then row.MouseButton1Click:Connect(onClick) end
        if hooks.Tooltip and not isMod and not smDef then hooks.Tooltip(row, it, isGear) end
        return row
    end
    -- one skin row: rarity bar, name, category (+ a note: worn / they own it)
    local function SkinRow(parent, info, order, onClick, tag, note, noteBad)
        local col = Cosmetics.RarityColor[info.Rarity or "Common"] or C.Text
        local rr = InvLayout.ItemRow(parent, { Color = col, Order = order, Height = 50, NoIcon = true, Tag = tag, TagColor = C.Text, Name = tostring(info.Name),
            Sub = tostring(info.Rarity or "") .. "  •  " .. tostring(info.Cat or "Skin") .. (note and ("  •  " .. note) or "") })
        if noteBad then rr.Sub.TextColor3 = C.Bad end
        local row = rr.Btn
        if onClick then row.MouseButton1Click:Connect(onClick) end
        return row
    end
    -- the tradeable skins you own (Cosmetics.TRADE_CATS order, then rarity / name)
    local function MySkins(st)
        local out = {}
        for ci, cat in ipairs(Cosmetics.TRADE_CATS) do
            local def = Cosmetics.CategoryById[cat]
            for _, e in ipairs(Cosmetics.List(cat)) do
                local n = Cosmetics.Tradeable(e) and Cosmetics.Copies(st, e) or 0
                if n > 0 then
                    table.insert(out, { Ref = cat .. ":" .. e.Id, Name = e.Name, Rarity = e.Rarity, Cat = def and def.Label or cat, CatOrder = ci,
                        Worn = Cosmetics.Equipped(st, e), Copies = n })
                end
            end
        end
        table.sort(out, function(a, b)
            if a.CatOrder ~= b.CatOrder then return a.CatOrder < b.CatOrder end
            local ra, rb = Cosmetics.RarityOrder[a.Rarity] or 0, Cosmetics.RarityOrder[b.Rarity] or 0
            if ra ~= rb then return ra > rb end
            return a.Name < b.Name
        end)
        return out
    end

    -- ===== no trade open: players + requests =====
    local function RenderLobby()
        Clear(body)
        Header(body, "PLAYERS IN THIS SERVER")
        UIStyle.Text({ Text = "Ask someone to trade. They get a request they can accept; both of you then put in items, skins and gold, press READY, and CONFIRM.",
            TextSize = 13, Font = UIStyle.BodyFont, TextColor3 = C.Sub, TextWrapped = true, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(0.6, -10, 0, 36), Parent = body })
        local list = Scroll(body, UDim2.fromOffset(0, 68), UDim2.new(0.6, -10, 1, -68))
        local others = {}
        for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(others, p) end end
        table.sort(others, function(a, b) return a.DisplayName < b.DisplayName end)
        if #others == 0 then
            UIStyle.EmptyState(list, "Nobody else here yet", "The Bazaar is the place to meet traders.", { Size = UDim2.new(1, 0, 0, 120) }) -- (UI v4)
        end
        for i, p in ipairs(others) do
            local row = New("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = i, Parent = list }, { UIStyle.Corner(2) })
            UIStyle.Text({ Text = p.DisplayName, TextSize = 17, Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -180, 0, 22), Parent = row })
            local where = p:GetAttribute("RunId") and "in a run" or "in the hub"
            UIStyle.Text({ Text = "@" .. p.Name .. "  •  " .. where, TextSize = 12, Font = UIStyle.BodyFont, TextColor3 = C.Sub, Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -180, 0, 16), Parent = row })
            local b = UIStyle.Button(row, "REQUEST", ACCENT, UDim2.fromOffset(150, 36), UDim2.new(1, -158, 0, 6))
            b.Button.MouseButton1Click:Connect(function()
                hooks.Click()
                local ok, msg = Act("Request", p.UserId)
                if ok and msg then hooks.Toast(msg) end
            end)
        end
        local right = New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.6, 10, 0, 0), Size = UDim2.new(0.4, -10, 1, 0), Parent = body })
        Header(right, "REQUESTS FOR YOU")
        local rl = Scroll(right, UDim2.fromOffset(0, 30), UDim2.new(1, 0, 1, -30))
        local n = 0
        for id, r in pairs(incoming) do
            if os.clock() < r.Until then
                n += 1
                local row = New("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, 0, 0, 84), LayoutOrder = n, Parent = rl }, { UIStyle.Corner(2) })
                UIStyle.Text({ Text = r.From .. " wants to trade", TextSize = 16, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 22), Parent = row })
                local acc = UIStyle.Button(row, "ACCEPT", C.Green, UDim2.fromOffset(120, 36), UDim2.fromOffset(10, 38))
                local dec = UIStyle.Button(row, "DECLINE", C.Red, UDim2.fromOffset(120, 36), UDim2.fromOffset(140, 38))
                acc.Button.MouseButton1Click:Connect(function() hooks.Click(); incoming[id] = nil; Act("Respond", id, true) end)
                dec.Button.MouseButton1Click:Connect(function() hooks.Click(); incoming[id] = nil; Act("Respond", id, false); RenderLobby() end)
            end
        end
        if n == 0 then UIStyle.EmptyState(rl, "No requests", "Trade requests from other players show up here.", { Size = UDim2.new(1, 0, 0, 120) }) end
    end

    -- ===== a trade is open =====
    local goldBox, stashList
    local function RenderSession()
        local s = session
        if hooks.HideTooltip then hooks.HideTooltip() end -- (the row under the mouse is about to be rebuilt)
        Clear(body)
        local st = hooks.GetState() or {}
        local inOffer = {}
        for _, e in ipairs(s.Me.Items) do inOffer[e.Item.Uid] = true end
        local offered = {} -- (copies of each skin already in your offer)
        for _, k in ipairs(s.Me.Skins or {}) do offered[k.Ref] = (offered[k.Ref] or 0) + 1 end
        local locked = s.Phase == "Locked"

        -- column 1: your stash (tradable items only)
        local c1 = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.34, -8, 1, -70), Parent = body })
        Header(c1, "YOUR STASH  (click to add)")
        for i, t in ipairs({ { "Items", "ITEMS" }, { "Skins", "SKINS" } }) do
            local on = stashTab == t[1]
            local tb = UIStyle.Button(c1, t[2], on and C.Gold or C.Steel, UDim2.new(0.5, -3, 0, 30), UDim2.new((i - 1) * 0.5, (i - 1) * 3, 0, 28), "Tab" .. t[1])
            tb.Button.MouseButton1Click:Connect(function()
                if stashTab ~= t[1] then hooks.Click(); stashTab = t[1]; RenderSession() end
            end)
        end
        stashList = Scroll(c1, UDim2.fromOffset(0, 64), UDim2.new(1, 0, 1, -64), "stash" .. stashTab)
        local eqW = st.EquippedWeapon and st.EquippedWeapon.Uid
        local eqG = {}
        for _, g in pairs(st.EquippedGear or {}) do if type(g) == "table" and g.Uid then eqG[g.Uid] = true end end
        local order = 0
        local function AddList(list, kind)
            for _, it in ipairs(list or {}) do
                local equipped = (kind == "Weapon" and it.Uid == eqW) or (kind == "Gear" and eqG[it.Uid])
                if not inOffer[it.Uid] and not equipped and it.Uid ~= "W_STARTER_PISTOL" then
                    order += 1
                    ItemRow(stashList, { Kind = kind, Item = it }, order, function()
                        hooks.Click(); Act("SetItem", kind, it.Uid, true) -- (a locked trade reopens: both un-ready)
                    end, "ADD")
                end
            end
        end
        if stashTab == "Skins" then
            for _, k in ipairs(MySkins(st)) do
                local left = k.Copies - (offered[k.Ref] or 0)
                if left > 0 then
                    order += 1
                    local note = (k.Copies > 1) and ("x" .. left .. " left") or nil
                    if k.Worn and left == 1 then note = (note and (note .. "  •  ") or "") .. "worn: comes off if traded" end
                    SkinRow(stashList, k, order, function()
                        hooks.Click(); Act("SetSkin", k.Ref, true)
                    end, "ADD", note)
                end
            end
            if order == 0 then UIStyle.Text({ Text = "No tradeable skins. Store pieces and season pass rewards can be traded; bundles go piece by piece.", TextSize = 13, TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(1, 0, 0, 56), Parent = stashList }) end
        else
            AddList(st.Inventory, "Weapon")
            AddList(st.GearInventory, "Gear")
            AddList(st.Riftmods, "Riftmod") -- (UPDATE 7)
            AddList(st.ShotMods, "ShotMod") -- (UPDATE 8 phase 3)
            if order == 0 then UIStyle.Text({ Text = "Nothing to trade (equipped items stay with you).", TextSize = 13, TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40), Parent = stashList }) end
        end

        -- column 2 + 3: the two offers
        local function OfferColumn(x, side, mine)
            local col = New("Frame", { BackgroundColor3 = C.CardDark, Position = UDim2.new(x, 8, 0, 0), Size = UDim2.new(0.33, -8, 1, -70), Parent = body }, { UIStyle.Corner(2) })
            local ready = side.Confirm and "   •   CONFIRMED" or (side.Ready and "   •   READY" or "")
            local h = Header(col, (mine and "YOU OFFER" or (string.upper(side.Name) .. " OFFERS")) .. ready)
            h.Position = UDim2.fromOffset(8, 4)
            h.TextColor3 = side.Ready and C.Good or C.Gold
            local list = Scroll(col, UDim2.fromOffset(6, 32), UDim2.new(1, -12, 1, -86), mine and "mine" or "theirs")
            for i, e in ipairs(side.Items) do
                ItemRow(list, e, i, mine and function()
                    hooks.Click(); Act("SetItem", e.Kind, e.Item.Uid, false) -- (a locked trade reopens: both un-ready)
                end or nil, mine and "TAKE" or nil)
            end
            local skins = side.Skins or {}
            for i, k in ipairs(skins) do
                -- (TheyHave = copies the RECEIVER owns now: this one is an extra copy for them)
                local have = tonumber(k.TheyHave) or 0
                local note = have > 0 and (mine and ("they own " .. have) or ("you own " .. have)) or nil
                SkinRow(list, k, #side.Items + i, mine and function()
                    hooks.Click(); Act("SetSkin", k.Ref, false)
                end or nil, mine and "TAKE" or nil, note)
            end
            if #side.Items + #skins == 0 then UIStyle.Text({ Text = mine and "Click items or skins on the left to offer them." or "Nothing yet.", TextSize = 13, TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(1, 0, 0, 36), Parent = list }) end
            UIStyle.Text({ Text = string.format("%d / %d items  •  %d / %d skins", #side.Items, s.Max, #skins, s.MaxSkins or 8), TextSize = 12, TextColor3 = C.Sub, Font = UIStyle.BodyFont,
                Position = UDim2.new(0, 8, 1, -50), Size = UDim2.new(1, -16, 0, 16), Parent = col })
            -- gold
            local gy = UDim2.new(0, 8, 1, -32)
            -- (0.97 BOUND SHOP: BOUND points trade too -- gold on the left half, BP on the right)
            UIStyle.Text({ Text = "GOLD", TextSize = 14, TextColor3 = C.Gold, Position = gy, Size = UDim2.fromOffset(46, 26), Parent = col })
            UIStyle.Text({ Text = "BP", TextSize = 14, TextColor3 = Color3.fromRGB(110, 200, 255), Position = UDim2.new(0.5, 4, 1, -32), Size = UDim2.fromOffset(26, 26), Parent = col })
            if mine then
                goldBox = New("TextBox", { Text = tostring(side.Gold), PlaceholderText = "0", ClearTextOnFocus = false, Font = UIStyle.BodyFont, TextSize = 15,
                    TextColor3 = C.Text, BackgroundColor3 = C.Card, Position = UDim2.new(0, 56, 1, -32), Size = UDim2.new(0.5, -60, 0, 26), Parent = col }, { UIStyle.Corner(2) })
                goldBox.TextEditable = true
                goldBox.FocusLost:Connect(function()
                    local n = math.floor(tonumber((goldBox.Text:gsub("[^%d]", ""))) or 0)
                    if n ~= side.Gold then Act("SetGold", n) end
                end)
                local bpBox = New("TextBox", { Name = "BPBox", Text = tostring(side.BP or 0), PlaceholderText = "0", ClearTextOnFocus = false, Font = UIStyle.BodyFont, TextSize = 15,
                    TextColor3 = C.Text, BackgroundColor3 = C.Card, Position = UDim2.new(0.5, 32, 1, -32), Size = UDim2.new(0.5, -40, 0, 26), Parent = col }, { UIStyle.Corner(2) })
                bpBox.TextEditable = true
                bpBox.FocusLost:Connect(function()
                    local n = math.floor(tonumber((bpBox.Text:gsub("[^%d]", ""))) or 0)
                    if n ~= (side.BP or 0) then Act("SetBP", n) end
                end)
            else
                UIStyle.Text({ Text = ItemData.FormatNumber(side.Gold), TextSize = 16, Position = UDim2.new(0, 56, 1, -32), Size = UDim2.new(0.5, -60, 0, 26), Parent = col })
                UIStyle.Text({ Text = ItemData.FormatNumber(side.BP or 0), TextSize = 16, Position = UDim2.new(0.5, 32, 1, -32), Size = UDim2.new(0.5, -40, 0, 26), Parent = col })
            end
        end
        OfferColumn(0.34, s.Me, true)
        OfferColumn(0.67, s.Them, false)

        -- bottom bar: status + buttons
        local status
        if s.Phase == "Edit" then
            status = s.Me.Ready and ("Waiting for " .. s.Them.Name .. " to be ready...") or "Put in what you want to give, then press READY. Any change un-readies both of you."
        elseif s.ConfirmIn and s.ConfirmIn > 0 then
            status = string.format("LOCKED. Check what you get. CONFIRM opens in %d...", math.ceil(s.ConfirmIn))
        else
            status = s.Me.Confirm and ("Waiting for " .. s.Them.Name .. " to confirm...") or "LOCKED. Press CONFIRM to complete the trade."
        end
        UIStyle.Text({ Text = status, TextSize = 15, TextWrapped = true, TextColor3 = locked and C.Gold or C.Text, Position = UDim2.new(0, 0, 1, -58), Size = UDim2.new(1, -420, 0, 50), Parent = body })
        local cancel = UIStyle.Button(body, "CANCEL", C.Red, UDim2.fromOffset(120, 46), UDim2.new(1, -400, 1, -54))
        cancel.Button.MouseButton1Click:Connect(function() hooks.Click(); Act("Cancel") end)
        if s.Phase == "Edit" then
            local rb = UIStyle.Button(body, s.Me.Ready and "UNREADY" or "READY", s.Me.Ready and C.Steel or C.Green, UDim2.fromOffset(260, 46), UDim2.new(1, -264, 1, -54), "ReadyButton")
            rb.Button.MouseButton1Click:Connect(function() hooks.Click(); Act("Ready", not s.Me.Ready) end)
        else
            local open = not s.ConfirmIn or s.ConfirmIn <= 0
            local cb = UIStyle.Button(body, s.Me.Confirm and "CONFIRMED" or (open and "CONFIRM TRADE" or ("CONFIRM (" .. math.ceil(s.ConfirmIn) .. ")")), open and C.Gold or C.Steel, UDim2.fromOffset(260, 46), UDim2.new(1, -264, 1, -54), "ConfirmButton")
            cb.SetEnabled(open and not s.Me.Confirm)
            cb.Button.MouseButton1Click:Connect(function() if open and not s.Me.Confirm then hooks.Click(); Act("Confirm") end end)
            local ub = UIStyle.Button(body, "UNREADY", C.Steel, UDim2.fromOffset(120, 46), UDim2.new(1, -530, 1, -54))
            ub.Button.MouseButton1Click:Connect(function() hooks.Click(); Act("Ready", false) end)
        end
    end

    local function Render()
        if not panel.Visible then return end
        if session then RenderSession() else RenderLobby() end
    end
    api.Render = Render

    -- ===== the request popup =====
    local pop = New("Frame", { Name = "TradeRequestPopup", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.fromOffset(420, 92),
        BackgroundColor3 = C.Card, Visible = false, ZIndex = 50, Parent = hudGui }, { UIStyle.Corner(2), UIStyle.Stroke(ACCENT, 2) })
    local popText = UIStyle.Text({ Text = "", TextSize = 17, ZIndex = 51, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 24), Parent = pop })
    local popAcc = UIStyle.Button(pop, "ACCEPT", C.Green, UDim2.fromOffset(120, 38), UDim2.fromOffset(14, 44))
    local popView = UIStyle.Button(pop, "LATER", C.Steel, UDim2.fromOffset(110, 38), UDim2.fromOffset(144, 44))
    local popDec = UIStyle.Button(pop, "DECLINE", C.Red, UDim2.fromOffset(120, 38), UDim2.fromOffset(264, 44))
    for _, b in ipairs({ popAcc, popView, popDec }) do b.Button.ZIndex = 51 for _, d in ipairs(b.Button:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex = 52 end end end
    local popFor = nil
    popAcc.Button.MouseButton1Click:Connect(function()
        pop.Visible = false
        if popFor then hooks.Click(); incoming[popFor] = nil; Act("Respond", popFor, true) end
    end)
    popDec.Button.MouseButton1Click:Connect(function()
        pop.Visible = false
        if popFor then hooks.Click(); incoming[popFor] = nil; Act("Respond", popFor, false) end
    end)
    popView.Button.MouseButton1Click:Connect(function() pop.Visible = false end)

    Remotes.GetEvent("TradeUpdate").OnClientEvent:Connect(function(kind: string, data: any)
        if kind == "Request" then
            incoming[data.FromId] = { From = data.From, FromId = data.FromId, Until = os.clock() + (data.Life or 30) }
            popFor = data.FromId
            popText.Text = data.From .. " wants to trade with you"
            pop.Visible = true
            hooks.Sound("Click")
            task.delay(data.Life or 30, function() if popFor == data.FromId then pop.Visible = false end end)
            if panel.Visible and not session then RenderLobby() end
        elseif kind == "Session" then
            local first = session == nil
            -- the OTHER player changed the trade and un-readied you: say so (you used to sit "ready" waiting forever)
            local was = session
            if was and data and was.Me and data.Me and (was.Me.Ready or was.Me.Confirm) and not data.Me.Ready and not busy then
                hooks.Toast((data.Them and data.Them.Name or "They") .. " changed the trade: check it and press READY again.")
                hooks.Sound("Click")
            end
            session = data
            pop.Visible = false
            if first and not panel.Visible then hooks.OpenFrame(panel) end
            Render()
        elseif kind == "Closed" then
            session = nil
            hooks.Toast(tostring(data))
            if panel.Visible then Render() end
        elseif kind == "Done" then
            session = nil
            hooks.Toast("Trade with " .. tostring(data) .. " complete!")
            hooks.Sound("Upgrade")
            if panel.Visible then hooks.CloseAll() end
        elseif kind == "Declined" then
            hooks.Toast(tostring(data) .. " declined your trade request.")
        end
    end)
    -- your stash changes (a sync) while trading: refresh the stash column
    api.OnState = function() if session and panel.Visible then Render() end end
    panel:GetPropertyChangedSignal("Visible"):Connect(function()
        if panel.Visible then Render() end
        -- closing the window during a trade cancels it (nothing is half-done)
        if not panel.Visible and session then Act("Cancel") end
    end)

    api.Open = function()
        if not panel.Visible then hooks.OpenFrame(panel) end
        Render()
    end
    api.Panel = panel
    api.InTrade = function() return session ~= nil end
    return api
end

return TradeMenu
