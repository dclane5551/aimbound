--!nocheck
-- The Forge window (client UI, UIStyle look): pick any weapon or gear piece you own, then Upgrade / Reforge / Tune /
-- Change Prefix / Re-level / Augment / Purge / Ascend it, or build a new one at the BENCH. Every number shown comes
-- from ItemData (the functions the server charges with).
--
--   local forge = ForgeMenu.Build(parentFolder, {
--       GetState = fn() -> clientState,
--       OnItemChanged = fn(weapon),      -- HUD / viewmodel / inventory refresh after a change
--       PlayClick = fn(), PlaySuccess = fn(), PlayFail = fn(),
--       OnClose = fn(),
--   })
--   forge.Frame, forge.Refresh(), forge.Select(uid)
local TweenService = game:GetService("TweenService")
local ItemData = require(script.Parent:WaitForChild("ItemData"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local InvLayout = require(script.Parent:WaitForChild("InvLayout")) -- (UI CLEAN R-B: the item row cards + icons)

local ForgeMenu = {}
local C = UIStyle.Colors
local New, Text = UIStyle.New, UIStyle.Text

local function Fmt(n: number): string return ItemData.FormatNumber(n) end
local function Hex(c: Color3): string return string.format("#%02X%02X%02X", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255)) end

function ForgeMenu.Build(parent: Instance, hooks: any)
    local click = hooks.PlayClick or function() end
    -- (UI CLEAN R-B2: the target's three zones across the screen -- items | the item card | the actions; 940 x 830 -> 1240 x 720)
    local FW, FH = 1440, 760 -- (the actions zone takes the extra width; smaller screens scale the whole window)
    local root = UIStyle.Panel(parent, { Name = "UpgMenu", Size = UDim2.fromOffset(FW, FH), Accent = C.Orange })
    local fit = New("UIScale", { Name = "FitScale", Parent = root })
    -- (2026-10-13 phones: the weapon list + the actions list scroll on their own -- a phone gets the forge 600 tall instead
    -- of 830, so it scrolls less than half as far)
    root:SetAttribute("PhoneMinH", 600)
    -- (PopScale animates opening; FitScale keeps it on small screens -- UIScales multiply)
    local ApplyZones: (() -> ())? = nil -- (R-B2 audit: phones get the narrow 2-zone layout -- the 3 zones at phone scale were ~7 px text)
    local function Fit()
        if ApplyZones then ApplyZones() end
        UIStyle.Fit(root, fit, root.Size.X.Offset, FH - 20, 40) -- (the HUD's interface scale multiplies in; phones: fit the width + swipe)
    end
    Fit()
    if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Fit) end

    UIStyle.TitleBar(root, "THE FORGE", C.Orange, "Upgrade your weapons and reroll affixes. Materials come from dungeons and dismantling.", function()
        click()
        if hooks.OnClose then hooks.OnClose() end
    end)

    -- YOUR MATERIALS (owner after 0.92: "the crafting system is still a bit confusing and cluttered ... unclear what does what,
    -- what material you use, how many you have"): every Forge material with its icon, count and name in a two-row grid
    -- (none = dimmed); hovering one says what it's for in the line under the grid. (Was a row of icon-only chips that
    -- needed a hover to even show the name.)
    -- (0.97 CRAFTING v4: only upgrades + affix rerolls remain -> the upgrade materials; rerolls cost Prism Shards)
    -- (UPDATE 7 CRAFTING v5: + Shift Shard / Graft / Strip Shard / Temper / Storm Core, each shown from its unlock level)
    local FORGE_MATS = { "Scrap", "Alloy", "Prism" }
    for _, k in ipairs(ItemData.CURRENCY_V5) do table.insert(FORGE_MATS, k) end
    for _, k in ipairs(ItemData.LOOT_MATS or {}) do if k ~= "ModBurnish" then table.insert(FORGE_MATS, k) end end -- (UPDATE 8: Ascension Essence + the socket currencies; Burnish lives in the MODS window)
    local matBar = New("Frame", { Name = "Materials", BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 74), Size = UDim2.new(1, -48, 0, 52), Parent = root }, {
        New("UIGridLayout", { CellSize = UDim2.new(1 / 10, -4, 0, 24), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder }), -- (R-B2: 10 a row, quiet cells)
    })
    local okGS, GS = pcall(require, script.Parent:WaitForChild("GameSettings"))
    local MAT_HINT = (okGS and GS.TouchOnly and GS.TouchOnly()) and "YOUR MATERIALS  •  tap one to see what it's for" or "YOUR MATERIALS  •  hover one to see what it's for"
    local matHint = UIStyle.Text({ Name = "MaterialHint", Text = MAT_HINT, TextSize = 13, Font = UIStyle.BodyFont, TextColor3 = C.Sub,
        TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(24, 130), Size = UDim2.new(1, -48, 0, 16), Parent = root })
    UIStyle.TextRole(matHint, "Meta")
    local chips = {}
    local function MatCell(key: string, order: number, color: Color3, iconKey: string?, short: string, name: string, desc: string)
        -- (UI CLEAN R-B2: the inventory's currency row -- icon + display number + the short name, no box, no coloured edge bar)
        local cell = New("Frame", { Name = "M_" .. key, BackgroundTransparency = 1, LayoutOrder = order, Parent = matBar }, {
            New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
        })
        cell.ClipsDescendants = true
        local icon = (iconKey and UIStyle.HasIcon(iconKey)) and UIStyle.Icon(iconKey, { Size = UDim2.fromOffset(18, 18), LayoutOrder = 1, Parent = cell }) or nil
        local count = Text({ TextSize = 16, TextColor3 = C.Text, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = cell })
        UIStyle.TextRole(count, "SectionHead", { Keep = true }); count.TextSize = 16
        local lbl = Text({ Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, Text = short, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3, Parent = cell })
        UIStyle.TextRole(lbl, "Meta")
        chips[key] = { Cell = cell, Count = count, Name = lbl, Icon = icon, Color = color }
        UIStyle.HoverTip(cell, function() matHint.Text = string.format("%s  •  you have %s  •  %s", name, count.Text, desc) end,
            function() matHint.Text = MAT_HINT end) -- (a tap shows it on phones)
    end
    MatCell("Gold", 0, C.Gold, "cur_gold", "Gold", "Gold", "Every craft also costs some gold (the item's sell value).")
    for i, key in ipairs(FORGE_MATS) do
        local def = ItemData.MaterialDefs[key]
        MatCell(key, i, def.Color, def.IconKey, def.Short, def.Name, def.Desc or "")
    end

    -- left: weapon list
    local listCard = UIStyle.Card(root, { Name = "WeaponListCard", Position = UDim2.fromOffset(24, 156), Size = UDim2.new(0, 300, 1, -172) })
    -- (R-B2) the middle zone: the inventory's own item card (hooks.ItemCard builds it), scrolling when it is tall
    local cardHost = New("ScrollingFrame", { Name = "CardHost", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(340, 156),
        Size = UDim2.new(0, 346, 1, -172), ScrollBarThickness = 3, ScrollBarImageColor3 = C.Sub, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = hooks.ItemCard ~= nil, Parent = root })
    -- (0.61f FORGE CRAFTING, owner: "you should be able to reroll all types of gear (not just weapons), add more features
    -- to the armory"): WEAPONS / GEAR share every reroll; BENCH builds a new item
    local mode = "Weapon"
    local function ItemType(): string return mode == "Gear" and "Gear" or "Weapon" end
    local tabBar = New("Frame", { Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 30), Parent = listCard }, {
        New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    local tabs = {}
    for i, t in ipairs({ { "Weapon", "WEAPONS" }, { "Gear", "GEAR" } }) do -- (0.97: the BENCH tab is gone)
        local b = UIStyle.Button(tabBar, t[2], C.Steel, UDim2.new(1 / 2, -3, 1, 0), UDim2.new(), "Tab" .. t[1])
        b.Button.LayoutOrder = i
        b.Label.TextSize = 14
        tabs[t[1]] = b
    end
    local list = New("ScrollingFrame", {
        Name = "WeaponList", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(6, 44), Size = UDim2.new(1, -12, 1, -50),
        ScrollBarThickness = 6, ScrollBarImageColor3 = C.Sub, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = listCard,
    }, {
        New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
        New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8) }),
    })

    -- right: weapon card + actions
    local right = New("Frame", { Name = "Detail", BackgroundTransparency = 1, Position = UDim2.fromOffset(hooks.ItemCard and 702 or 340, 156),
        Size = UDim2.new(1, -(hooks.ItemCard and 726 or 364), 1, -172), Parent = root })
    local card = UIStyle.Card(right, { Name = "Card", Size = UDim2.new(1, 0, 0, 252) }) -- (UI CLEAN R-B: 208 -> 252, the stat lines ran past it)
    local cardStroke = card:FindFirstChildOfClass("UIStroke")
    local rarityBadge = New("Frame", { Name = "Badge", BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Parent = card }, {
        UIStyle.Corner(12), New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
    })
    local badgeGrad = UIStyle.Gradient(C.Off, C.Off); badgeGrad.Parent = rarityBadge
    UIStyle.Stroke(C.Border, 2).Parent = rarityBadge
    local badgeText = Text({ TextSize = 14, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Stroke = 1.5, Parent = rarityBadge })
    -- (UI CLEAN R-B: the badge is a plain caps word in the rarity colour; the card gets a 2 px rarity edge + a faint tint)
    rarityBadge.BackgroundTransparency = 1
    for _, o in ipairs(rarityBadge:GetChildren()) do if o:IsA("UIStroke") or o:IsA("UICorner") then o:Destroy() end end
    badgeGrad.Enabled = false
    local pad = rarityBadge:FindFirstChildOfClass("UIPadding"); if pad then pad.PaddingLeft = UDim.new(0, 2) end
    UIStyle.TextRole(badgeText, "SectionHead", { Keep = true })
    local cardEdge = New("Frame", { Name = "RarityEdge", BorderSizePixel = 0, BackgroundColor3 = C.Text, Size = UDim2.new(1, 0, 0, 2), Parent = card })
    cardEdge:SetAttribute("Skinned", true)
    local cardIcon = New("ImageLabel", { Name = "ItemIcon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14),
        ScaleType = Enum.ScaleType.Fit, ImageColor3 = C.Text, Parent = card })
    cardIcon:SetAttribute("Skinned", true)
    local title = Text({ TextSize = 28, Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -150, 0, 34), Stroke = 2.5, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
    UIStyle.TextRole(title, "WindowTitle", { Keep = true }); title.TextSize = 24
    for _, o in ipairs(title:GetChildren()) do if o:IsA("UIStroke") then o.Enabled = false end end
    local subtitle = Text({ Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, Position = UDim2.fromOffset(16, 72), Size = UDim2.new(1, -170, 0, 18), Parent = card })
    UIStyle.TextRole(subtitle, "Label")
    -- two columns: base stats | prefix, affixes, unique effect
    local body = Text({ Font = UIStyle.BodyFont, TextSize = 13, Position = UDim2.fromOffset(16, 96), Size = UDim2.new(0.36, -16, 1, -100), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, RichText = true, Parent = card })
    UIStyle.TextRole(body, "Body"); body.TextSize = 13 -- (UI CLEAN R-B: the stat lines on the body face)
    do -- (UI CLEAN R-B: long guns' stat lines ran out of the card -- the column scrolls instead)
        local bodyScroll = New("ScrollingFrame", { Name = "BodyScroll", BackgroundTransparency = 1, BorderSizePixel = 0, Position = body.Position, Size = body.Size,
            ScrollBarThickness = 3, ScrollBarImageColor3 = C.Sub, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = card })
        body.Position = UDim2.new(); body.Size = UDim2.new(1, -6, 0, 0); body.AutomaticSize = Enum.AutomaticSize.Y
        body.Parent = bodyScroll
    end
    -- AFFIX LOCKS (0.61 AFFIX SEALS): the right column lists the prefix, the affixes and the unique effect; click an affix
    -- to LOCK it for the next Reforge (locked ones stay, the rest reroll; Affix Seals pay for the locks)
    local affixList = New("ScrollingFrame", {
        Name = "Affixes", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0.36, 8, 0, 96), Size = UDim2.new(0.64, -24, 1, -100),
        ScrollBarThickness = 4, ScrollBarImageColor3 = C.Sub, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = card,
    }, {
        New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    local locks: { [number]: boolean } = {}
    local locksFor: string? = nil
    local function LockList(): { number }
        local out = {}
        for i in pairs(locks) do table.insert(out, i) end
        table.sort(out)
        return out
    end

    if hooks.ItemCard then card.Visible = false end -- (R-B2: the middle zone's item card replaces the old detail card)
    local ACT_Y = hooks.ItemCard and 0 or 260
    local actionsRef: ScrollingFrame? = nil
    ApplyZones = function()
        if not hooks.ItemCard then return end
        local phone = UIStyle.IsPhone()
        root.Size = UDim2.fromOffset(phone and 960 or FW, FH)
        cardHost.Visible = not phone
        card.Visible = phone
        right.Position = UDim2.fromOffset(phone and 340 or 702, 156)
        right.Size = UDim2.new(1, -(phone and 364 or 726), 1, -172)
        local y = phone and 260 or 0
        if actionsRef then actionsRef.Position = UDim2.fromOffset(0, y); actionsRef.Size = UDim2.new(1, 0, 1, -(y + 36)) end
    end
    local actions = New("ScrollingFrame", { Name = "Actions", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, ACT_Y), Size = UDim2.new(1, 0, 1, -(ACT_Y + 36)),
        ScrollBarThickness = 6, ScrollBarImageColor3 = C.Sub, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = right }, {
        New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
        New("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 4) }),
    })
    actionsRef = actions
    Fit()
    root:GetPropertyChangedSignal("Visible"):Connect(function() if root.Visible then Fit() end end)
    do local lp0 = game:GetService("Players").LocalPlayer; if lp0 then lp0:GetAttributeChangedSignal("DevPhone"):Connect(function() task.delay(0.1, Fit) end) end end
    -- BENCH panel (shown instead of the actions): rarity picker, live cost, BUILD
    local bench = UIStyle.Card(right, { Name = "Bench", Position = UDim2.fromOffset(0, 260), Size = UDim2.new(1, 0, 0, 200) })
    bench.Visible = false
    Text({ Text = "RARITY", TextSize = 15, TextColor3 = C.Sub, Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(120, 22), Stroke = 1.5, Parent = bench })
    local benchPrev = UIStyle.Button(bench, "<", C.Steel, UDim2.fromOffset(44, 40), UDim2.fromOffset(16, 38), "Prev")
    local benchRarity = Text({ TextSize = 22, Position = UDim2.fromOffset(68, 38), Size = UDim2.fromOffset(200, 40), TextXAlignment = Enum.TextXAlignment.Center, Stroke = 2, Parent = bench })
    local benchNext = UIStyle.Button(bench, ">", C.Steel, UDim2.fromOffset(44, 40), UDim2.fromOffset(276, 38), "Next")
    local benchInfo = Text({ Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.fromOffset(16, 88), Size = UDim2.new(1, -32, 0, 34), Parent = bench })
    local benchCost = Text({ Font = UIStyle.BodyFont, TextSize = 14, RichText = true, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.fromOffset(16, 126), Size = UDim2.new(1, -196, 0, 60), Parent = bench })
    local benchBuild = UIStyle.Button(bench, "BUILD", C.Green, UDim2.fromOffset(160, 48), UDim2.new(1, -176, 1, -64), "Build")
    local resultLbl = Text({ Name = "Result", TextSize = 18, Position = UDim2.new(0, 4, 1, -30), Size = UDim2.new(1, -8, 0, 28), Stroke = 2, Text = "", Parent = right })
    UIStyle.TextRole(resultLbl, "Body", { Keep = true }); resultLbl.TextSize = 15

    -- ACTIONS v2 (owner after 0.92: "unclear what does what, what material you use, how many you have"): grouped under
    -- headers; every row says in plain words what it does (always shown), then its cost as chips -- icon, how many it
    -- takes and how many you have, green when you have enough, red when not -- or why it can't be used right now.
    local function Section(order: number, label: string)
        -- (Update 5: the design system's section header -- caps in the secondary colour with a rule, not gold)
        local h = UIStyle.SectionHeader(actions, label, { Height = 24, LayoutOrder = order })
        h.Name = "H_" .. label
        return h
    end
    local function ActionRow(order: number, name: string, icon: string, accent: Color3)
        -- (UI CLEAN R-B: every action row is the same card -- an off-white icon with no coloured box, the name on the Title
        -- role, what it does on Label, the button a quiet outline (the accent colours are gone: one look for every craft))
        local row = UIStyle.Card(actions, { Name = name, Size = UDim2.new(1, 0, 0, 74), LayoutOrder = order })
        local iconBg = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 8, 0, 8), Parent = row })
        if UIStyle.HasIcon(icon) then
            local ic = UIStyle.Icon(icon, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), Parent = iconBg })
            if ic:IsA("ImageLabel") then ic.ImageColor3 = C.Text; ic.ImageTransparency = 0.1 end
        else
            Text({ Text = string.sub(name, 1, 1), TextSize = 22, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = iconBg })
        end
        local t = Text({ Position = UDim2.fromOffset(62, 6), Size = UDim2.new(1, -220, 0, 20), TextSize = 17, RichText = true, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
        UIStyle.TextRole(t, "Title"); t.TextSize = 17
        local what = Text({ Font = UIStyle.BodyFont, Position = UDim2.fromOffset(62, 27), Size = UDim2.new(1, -220, 0, 16), TextSize = 13, TextColor3 = C.Sub, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
        UIStyle.TextRole(what, "Label"); what.TextSize = 13
        local cost = New("Frame", { Name = "Cost", BackgroundTransparency = 1, Position = UDim2.fromOffset(62, 46), Size = UDim2.new(1, -220, 0, 22), Parent = row }, {
            New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
        })
        local _ = accent
        local btn = UIStyle.Button(row, "", (name == "Upgrade") and C.Accent or C.Steel, UDim2.fromOffset(140, 40), UDim2.new(1, -150, 0.5, -20), "Do") -- (R-B2: UPGRADE = the main action)
        row.BackgroundTransparency = 0; row.BackgroundColor3 = C.Bg1
        local rst = row:FindFirstChildOfClass("UIStroke"); if rst then rst.Transparency = 1 end
        return { Row = row, Title = t, What = what, Cost = cost, Btn = btn }
    end
    Section(10, "IMPROVE IT")
    local rowUpgrade = ActionRow(11, "Upgrade", "f_upgrade", C.Blue)
    local rowRelevel = ActionRow(12, "Relevel", "f_relevel", C.Purple)
    local rowAscend = ActionRow(13, "Ascend", "mat_ascend", C.Pink)
    Section(20, (okGS and GS.TouchOnly and GS.TouchOnly()) and "REROLL IT" or "REROLL IT  •  SHIFT-CLICK: UP TO 5 IN A ROW, STOPS ON A ★ ROLL") -- (QOL F3)
    local hdrAdd
    local rowReforge = ActionRow(21, "Reforge", "mat_reforge", C.Orange)
    local rowRetype = ActionRow(24, "Retype", "mat_schematic", C.Green) -- (fixes 2026-10-16 #2: REROLL GUN)
    -- (UPDATE 7 CRAFTING v5) one random job per currency; a row only shows from its currency's unlock level
    local rowGraft = ActionRow(25, "Graft", "mat_infusion", C.Blue)
    local rowStrip = ActionRow(26, "Strip", "mat_purge", C.Red)
    local rowTemper = ActionRow(27, "Temper", "mat_ascend", C.Orange)
    local rowStorm = ActionRow(28, "Storm", "mat_reforge", C.Purple)
    local rowOver = ActionRow(29, "Overcharge", "mat_purge", C.Pink) -- (UPDATE 7 C5)
    -- (UPDATE 8 LOOT) the three socket currencies (guns only; hidden for gear)
    local hdrSock = Section(33, "SOCKETS")
    local rowSockets = ActionRow(34, "Sockets", "mat_schematic", C.Steel or C.Blue)
    local rowLinks = ActionRow(35, "Links", "mat_infusion", C.Orange)
    local rowColours = ActionRow(36, "Colours", "mat_catalyst", C.Blue)
    -- (CHASE ITEMS 2026-11-06) TWIN GLASS: an exact copy; both become TWINNED (shown once you hold one, or once Zeniths are live)
    local hdrTwin = Section(37, "TWIN GLASS")
    local rowTwin = ActionRow(38, "Twin", "mat_catalyst", C.Blue)
    local rowTune = ActionRow(22, "Tune", "mat_tuning", C.Green)
    local rowPrefix = ActionRow(23, "Prefix", "mat_catalyst", C.Pink)
    hdrAdd = Section(30, "ADD OR REMOVE AFFIXES")
    local rowAugment = ActionRow(31, "Augment", "mat_infusion", C.Blue)
    local rowPurge = ActionRow(32, "Purge", "mat_purge", C.Red)
    -- Codex of Power (Diablo 4 / Borderlands anointments): dismantling a Legendary or Mythic weapon unlocks its unique power
    -- for good; IMPRINT opens a picker (weapon -> power -> confirm). A Fate Shard rerolls the power a weapon has.
    local hdrPower = Section(40, "UNIQUE POWER")
    local rowImprint = ActionRow(41, "Imprint", "f_imprint", C.Gold)
    local rowTrait = ActionRow(42, "Fate", "mat_fate", C.Gold)
    -- CRAFTING v4 (0.97, owner: "remove purge, augment, imprint system, power rerolling, prefix changing, and tuning ... only
    -- be able to reroll affixes for a very expensive price, and upgrade weapons"): these rows stay built (the server refuses
    -- them) but are never shown
    local REMOVED_ROWS = { rowRelevel, rowTune, rowPrefix, rowAugment, rowPurge, rowImprint, rowTrait } -- (UPDATE 8: ASCEND is back, as a v5 craft)
    for _, r in ipairs(REMOVED_ROWS) do r.Row.Visible = false end
    hdrAdd.Visible = false
    hdrPower.Visible = false
    local function CodexList(state: any): { any }
        local out = {}
        for _, t in ipairs(ItemData.UniqueTraitsCatalog) do
            if type(state.Codex) == "table" and state.Codex[t.Id] then table.insert(out, t) end
        end
        return out
    end

    local selectedUid: string? = nil
    local busy = false

    local function Have(state: any, key: string): number
        if key == "Gold" then return state.Gold or 0 end
        return (state.Materials or {})[key] or 0
    end
    local function CostText(state: any, key: string, amount: number): string
        local name = key == "Gold" and "gold" or ItemData.MaterialDefs[key].Name
        local col = (Have(state, key) >= amount) and "#D7E0F5" or "#FF6B6B"
        return string.format('<font color="%s">%s %s</font>', col, Fmt(amount), name)
    end
    -- cost chips: costs = { { key, amount }, ... } (key = a material or "Gold"), or a string = why it can't be used now
    local function CostChips(holder: Frame, state: any, costs: any)
        for _, c in ipairs(holder:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        if type(costs) == "string" then
            local why = Text({ Font = UIStyle.BodyFont, Text = costs, TextSize = 13, TextColor3 = C.Muted, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Parent = holder })
            UIStyle.TextRole(why, "Meta") -- (R-B2: why a row can't be used = a quiet line, not a red warning)
            return
        end
        for i, c in ipairs(costs) do
            local key, n = c[1], c[2]
            local def = ItemData.MaterialDefs[key]
            local have = Have(state, key)
            local ok = have >= n
            -- (UI CLEAN R-B2: a neutral icon + number pair, no coloured chip; the number is Bad red only when you can't afford it)
            local chip = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i, Parent = holder }, {
                New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
                New("UIPadding", { PaddingRight = UDim.new(0, 12) }),
            })
            local iconKey = (key == "Gold") and "cur_gold" or (def and def.IconKey)
            if iconKey and UIStyle.HasIcon(iconKey) then UIStyle.Icon(iconKey, { Size = UDim2.fromOffset(16, 16), LayoutOrder = 1, Parent = chip }) end
            local num = Text({ TextSize = 15, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = chip,
                TextColor3 = ok and C.Text or C.Bad, Text = Fmt(n) })
            UIStyle.TextRole(num, "Value", { Keep = true }); num.TextColor3 = ok and C.Text or C.Bad
            local nm = Text({ Font = UIStyle.BodyFont, TextSize = 13, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 3, Parent = chip,
                TextColor3 = C.Muted, Text = string.format("%s  (have %s)", (key == "Gold") and "gold" or (def and def.Short or key), Fmt(have)) })
            UIStyle.TextRole(nm, "Meta")
        end
    end
    local function Afford(state: any, costs: any): boolean
        if type(costs) ~= "table" then return false end
        for _, c in ipairs(costs) do if Have(state, c[1]) < c[2] then return false end end
        return true
    end
    -- a row: title, what it does, costs (a list, or a reason string), button text, an extra condition (default true)
    local function SetRow(r: any, titleText: string, whatText: string, costs: any, btnText: string, extra: boolean?)
        local state = hooks.GetState() or {}
        r.Title.Text = titleText
        r.What.Text = whatText
        CostChips(r.Cost, state, costs)
        r.Btn.SetText(btnText)
        r.Btn.SetEnabled(extra ~= false and Afford(state, costs))
    end

    local Refresh: () -> ()

    local GEAR_SLOTS = { "Helmet", "ChestPiece", "Gloves", "Leggings", "Boots", "Ring1", "Ring2", "Necklace" } -- (UPDATE 8: + Gloves)
    local SLOT_LABEL = { Helmet = "Helmet", ChestPiece = "Chest", Gloves = "Gloves", Leggings = "Legs", Boots = "Boots", Ring = "Ring", Necklace = "Necklace" }
    local function Selected(state: any): any
        if mode == "Gear" then
            for _, g in ipairs(state.GearInventory or {}) do if g.Uid == selectedUid then return g end end
            for _, g in pairs(state.EquippedGear or {}) do if type(g) == "table" and g.Uid == selectedUid then return g end end
            local eqg = state.EquippedGear or {}
            for _, s in ipairs(GEAR_SLOTS) do
                if type(eqg[s]) == "table" then selectedUid = eqg[s].Uid; return eqg[s] end
            end
            local first = (state.GearInventory or {})[1]
            selectedUid = first and first.Uid or nil
            return first
        end
        for _, w in ipairs(state.Inventory or {}) do
            if w.Uid == selectedUid then return w end
        end
        local eq = state.EquippedWeapon
        selectedUid = eq and eq.Uid or nil
        return eq
    end

    local function RenderList(state: any)
        for _, c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local items, eqSet = {}, {}
        if mode == "Gear" then
            for _, g in pairs(state.EquippedGear or {}) do
                if type(g) == "table" and g.Uid and not eqSet[g.Uid] then table.insert(items, g); eqSet[g.Uid] = true end
            end
            for _, g in ipairs(state.GearInventory or {}) do if not eqSet[g.Uid] then table.insert(items, g) end end
        else
            items = table.clone(state.Inventory or {})
            if state.EquippedWeapon then eqSet[state.EquippedWeapon.Uid] = true end
        end
        table.sort(items, function(a, b)
            if (eqSet[a.Uid] == true) ~= (eqSet[b.Uid] == true) then return eqSet[a.Uid] == true end
            local ra, rb = ItemData.RarityRank[a.Rarity] or 1, ItemData.RarityRank[b.Rarity] or 1
            if ra ~= rb then return ra > rb end
            return (a.ItemLevel or 1) > (b.ItemLevel or 1)
        end)
        if #items == 0 then
            Text({ Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40), Parent = list,
                Text = (mode == "Gear") and "No gear yet. Gear drops in dungeons." or "No weapons." })
        end
        for i, w in ipairs(items) do
            local sel = w.Uid == selectedUid
            local rc = ItemData.ItemColor(w) -- (CHASE ITEMS: Zenith / Relic colours)
            -- (UI CLEAN R-B: the shared item row card -- rarity edge + tint, display name, sub-line, the icon in its own box)
            local b = InvLayout.ItemRow(list, { Item = w, Color = rc, Selected = sel, Order = i, ArtW = 52, ArtH = 22, Name = ItemData.DisplayName(w),
                Sub = (mode == "Gear") and string.format("%s  •  iLvl %d  •  %s", ItemData.RarityLabel(w), w.ItemLevel or 1, SLOT_LABEL[ItemData.GearType(w.Slot)] or "Gear")
                    or string.format("%s  •  iLvl %d  •  +%d/%d", ItemData.RarityLabel(w), w.ItemLevel or 1, w.UpgradeLevel or 0, (ItemData.UpgradeCapFor(w))),
            }).Btn
            b.Name = "W_" .. i
            if eqSet[w.Uid] then local sb = b:FindFirstChild("Sub"); if sb then sb.Text = "EQUIPPED  •  " .. sb.Text end end
            b.MouseButton1Click:Connect(function()
                click()
                selectedUid = w.Uid
                resultLbl.Text = ""
                Refresh()
            end)
        end
    end

    -- BENCH: pick a gear slot or a gun, then a rarity (up to ItemData.BenchMaxRank)
    local benchPick = { Kind = "Gear", Base = "Helmet" }
    local benchRank: number? = nil
    local function BenchName(p: any): string
        if p.Kind == "Gear" then return (SLOT_LABEL[p.Base] or p.Base) end
        local b = ItemData.BaseWeapons[p.Base]
        return b and b.Name or p.Base
    end
    local function RenderBench(state: any)
        for _, c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local order = 0
        local function Header(t: string)
            order += 1
            Text({ Text = t, TextSize = 13, TextColor3 = C.Sub, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = order, Stroke = 1, Parent = list })
        end
        local function Pick(kind: string, base: string, sub: string)
            order += 1
            local sel = benchPick.Kind == kind and benchPick.Base == base
            local b = New("TextButton", { Name = "B_" .. base, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order, Parent = list }, { UIStyle.Corner(10) })
            UIStyle.Gradient(sel and UIStyle.Darken(C.Green, 0.45) or C.Card, sel and UIStyle.Darken(C.Green, 0.7) or C.CardDark).Parent = b
            UIStyle.Stroke(sel and C.Green or C.Border, sel and 3 or 2).Parent = b
            Text({ Position = UDim2.fromOffset(14, 3), Size = UDim2.new(1, -20, 0, 20), TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd, Stroke = 1.5,
                Text = BenchName({ Kind = kind, Base = base }), Parent = b })
            Text({ Font = UIStyle.BodyFont, Position = UDim2.fromOffset(14, 22), Size = UDim2.new(1, -20, 0, 14), TextSize = 11, TextColor3 = C.Sub, Text = sub, Parent = b })
            UIStyle.Hover(b, 0.03)
            b.MouseButton1Click:Connect(function()
                click()
                benchPick = { Kind = kind, Base = base }
                resultLbl.Text = ""
                Refresh()
            end)
        end
        Header("GEAR")
        for _, slot in ipairs(ItemData.BENCH_SLOTS) do Pick("Gear", slot, "Random stat lines for the slot") end
        Header("GUNS")
        for _, id in ipairs(ItemData.BenchGuns()) do
            local b = ItemData.BaseWeapons[id]
            Pick("Gun", id, b and ItemData.WeaponTypeLine(b, id) or "Gun")
        end
    end
    local function RefreshBench(state: any)
        RenderBench(state)
        local lvl = state.Level or 1
        local top = ItemData.BenchMaxRank(lvl)
        benchRank = top
        local rarity = ItemData.Rarities[benchRank]
        local rc = ItemData.RarityColors[rarity] or C.Text
        badgeText.Text = "BENCH"
        badgeGrad.Color = ColorSequence.new(UIStyle.Lighten(C.Green, 0.1), UIStyle.Darken(C.Green, 0.35))
        title.Text = "RANDOM RARITY " .. string.upper(BenchName(benchPick))
        title.TextColor3 = rc
        cardEdge.BackgroundColor3 = rc
        if cardStroke then cardStroke.Color = C.Text; cardStroke.Transparency = 0.86 end
        subtitle.Text = "Built at item level " .. lvl .. "  •  affixes roll like a drop"
        body.Text = "The bench builds the base you pick at a RANDOM rarity, rolled like a drop, up to " .. ItemData.Rarities[top] .. " at your level."
        for _, c in ipairs(affixList:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        benchRarity.Text = "UP TO " .. string.upper(rarity)
        benchRarity.TextColor3 = rc
        benchPrev.SetEnabled(false)
        benchNext.SetEnabled(false)
        local cost = ItemData.BenchRollCost(lvl)
        local parts, afford = {}, true
        for _, key in ipairs({ "Schematic", "Alloy", "Prism", "Gold" }) do
            if (cost[key] or 0) > 0 then
                table.insert(parts, CostText(state, key, cost[key]))
                if Have(state, key) < cost[key] then afford = false end
            end
        end
        local room = ItemData.BagRoom(state) > 0
        benchInfo.Text = room and ("The rarity is rolled when you build (up to " .. ItemData.Rarities[top] .. ").") or "Your bag is full: sell or dismantle something first."
        benchCost.Text = table.concat(parts, "  •  ")
        benchBuild.SetEnabled(afford and room and not busy)
    end

    Refresh = function()
        local state = hooks.GetState()
        if not state then return end
        for key, chip in pairs(chips) do
            chip.Cell.Visible = ItemData.MaterialUnlocked(key, state.Level) -- (CRAFTING v5: hidden before its unlock level)
            local n = Have(state, key)
            chip.Count.Text = Fmt(n)
            chip.Count.TextColor3 = (n > 0) and C.Text or C.Muted -- (R-B2: neutral numbers; the icon carries the colour)
            chip.Name.TextColor3 = (n > 0) and C.Sub or C.Muted
            if chip.Icon then chip.Icon.ImageTransparency = (n > 0) and 0 or 0.6 end
        end
        if mode == "Bench" then mode = "Weapon" end
        for _, k in ipairs({ "Weapon", "Gear" }) do tabs[k].SetSelected(mode == k) end -- (UI v4 NEON)
        actions.Visible = mode ~= "Bench"
        bench.Visible = mode == "Bench"
        if mode == "Bench" then RefreshBench(state); return end
        local isGear = mode == "Gear"
        local w = Selected(state)
        RenderList(state)
        if not w then
            for _, c in ipairs(cardHost:GetChildren()) do if c:IsA("GuiObject") then c.Visible = false end end
            title.Text = isGear and "No gear" or "No weapon"
            subtitle.Text, body.Text, badgeText.Text = "", "", ""
            for _, c in ipairs(affixList:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
            return
        end

        if hooks.ItemCard then pcall(hooks.ItemCard, cardHost, w, isGear) end -- (R-B2: the inventory's card for this item)
        local d = isGear and ItemData.DescribeGear(w) or ItemData.DescribeWeapon(w)
        local rc = ItemData.ItemColor(w) -- (CHASE ITEMS: Zenith / Relic colours)
        badgeText.Text = string.upper(ItemData.RarityLabel(w))
        badgeGrad.Color = ColorSequence.new(UIStyle.Lighten(rc, 0.1), UIStyle.Darken(rc, 0.35))
        title.Text = string.upper(d.Title or "")
        card.BackgroundColor3 = C.Bg1:Lerp(rc, 0.07)
        title.TextColor3 = InvLayout.Readable(rc, card.BackgroundColor3)
        badgeText.TextColor3 = title.TextColor3
        cardEdge.BackgroundColor3 = rc
        InvLayout.ApplyIcon(cardIcon, InvLayout.IconFor(w, isGear and nil or "Weapon"), 130, 50, 46)
        if cardStroke then cardStroke.Color = C.Text; cardStroke.Transparency = 0.86 end
        subtitle.Text = d.Subtitle
        local statLines = {}
        for _, l in ipairs(d.Lines) do
            if l.Kind ~= "affix" and l.Kind ~= "trait" and l.Kind ~= "proc" then table.insert(statLines, l.Text) end
        end
        body.Text = table.concat(statLines, "\n")

        local rank = ItemData.RarityRank[w.Rarity] or 1
        -- the affix column (proc first, then affixes + unique effects in tooltip order; affix i = index i for the server)
        local total = ItemData.AffixTotal(w, isGear)
        if locksFor ~= w.Uid then locks = {}; locksFor = w.Uid end
        for i in pairs(locks) do if i > total then locks[i] = nil end end
        local frozen = w.Exotic and not (ItemData.RelicTunable and ItemData.RelicTunable(w)) -- (relics: fixed lines; UPDATE 8 LOOT: REROLL VALUES rolls them in their ranges)
        local canLock = false -- (0.97 CRAFTING v4: "Affix rolling should no longer be lockable")
        for _, c in ipairs(affixList:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        do
            local order, idx = 0, 0
            local function Line(txt: string, color: Color3)
                order += 1
                Text({ Font = UIStyle.BodyFont, TextSize = 13, TextWrapped = true, TextColor3 = color, Text = txt,
                    Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = affixList })
            end
            if canLock then
                order += 1
                Text({ TextSize = 11, TextColor3 = C.Sub, Text = "CLICK AN AFFIX TO SEAL IT FOR THE NEXT REFORGE", Size = UDim2.new(1, -6, 0, 14), LayoutOrder = order, Parent = affixList })
            end
            for _, l in ipairs(d.Lines) do
                if l.Kind == "proc" then Line(l.Text, Color3.fromRGB(255, 143, 176)) end
            end
            for _, l in ipairs(d.Lines) do
                if l.Kind == "trait" then
                    Line(l.Text, l.Color or C.Orange)
                elseif l.Kind == "affix" then
                    idx += 1
                    local i = idx
                    local on = locks[i] == true
                    order += 1
                    local b = New("TextButton", {
                        Name = "Affix" .. i, Text = "", AutoButtonColor = false, BackgroundColor3 = on and UIStyle.Darken(C.Gold, 0.6) or C.CardDark,
                        BackgroundTransparency = on and 0.05 or 0.6, Size = UDim2.new(1, -6, 0, 18), LayoutOrder = order, Parent = affixList,
                    }, { UIStyle.Corner(2) })
                    if on then
                        UIStyle.Stroke(C.Gold, 1).Parent = b
                        New("Frame", { BackgroundColor3 = C.Gold, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0), Parent = b })
                    end
                    Text({ Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = on and C.Gold or ((l.Kind == "affix" and not l.Negative) and C.Text or (l.Color or C.Text)), TextTruncate = Enum.TextTruncate.AtEnd, -- (UI CLEAN audit: affixes off-white, not light blue)
                        Text = (on and "LOCKED  " or "") .. l.Text, Position = UDim2.fromOffset(7, 0), Size = UDim2.new(1, -10, 1, 0), Parent = b })
                    b.MouseButton1Click:Connect(function()
                        if not canLock or busy then return end
                        click()
                        if locks[i] then
                            locks[i] = nil
                        elseif total < 2 then
                            resultLbl.TextColor3 = C.Bad
                            resultLbl.Text = "Leave at least one affix unlocked."
                            return
                        else
                            locks = { [i] = true } -- (0.75 CRAFTING v3: ONE sealed affix per Reforge -- picking another moves it)
                        end
                        Refresh()
                    end)
                end
            end
            if idx == 0 and order <= (canLock and 1 or 0) then Line("No affixes.", C.Sub) end
        end
        local gold = ItemData.CraftGold(w, isGear)
        local lvl, ilvl = state.Level or 1, w.ItemLevel or 1
        local function CostList(cost: any): { any }
            local out = {}
            for _, key in ipairs(ItemData.MaterialOrder) do if (cost[key] or 0) > 0 then table.insert(out, { key, cost[key] }) end end
            if (cost.Gold or 0) > 0 then table.insert(out, { "Gold", cost.Gold }) end
            return out
        end
        local function Dim(t: string): string return '  <font color="#9A9CA4">' .. t .. "</font>" end
        rowUpgrade.Row.Visible = not isGear -- (weapon-only)
        for _, r in ipairs(REMOVED_ROWS) do r.Row.Visible = false end
        -- IMPROVE IT
        local upg = w.UpgradeLevel or 0
        local cap, nextIlvl = ItemData.UpgradeCapFor(w) -- (LOOT SCARCITY 2026-11-07: item level gates the cap)
        if upg >= cap then
            SetRow(rowUpgrade, "UPGRADE" .. Dim("+" .. upg .. " / " .. cap), "More damage, one step at a time.",
                nextIlvl and ("Item level " .. (w.ItemLevel or 1) .. " stops at +" .. cap .. ". The next step opens at item level " .. nextIlvl .. ".")
                    or (w.Rarity .. " weapons max out at +" .. cap .. "."), nextIlvl and "ITEM LEVEL" or "MAXED", false)
        else
            local c = ItemData.UpgradeStepCost(w.Rarity, upg + 1)
            SetRow(rowUpgrade, string.format("UPGRADE  +%d → +%d", upg, upg + 1) .. Dim(math.round(c.Chance * 100) .. "% success"),
                "More damage. If it fails you lose the materials, never the weapon." .. (((upg + 1) % 5 == 0) and " This step also raises an affix tier." or ""),
                { { c.Material, c.Amount }, { "Gold", c.Gold } }, "UPGRADE")
        end
        local relWhat = "Raises the item level to yours. Keeps affixes and upgrades."
        if rank < 3 then
            SetRow(rowRelevel, "RE-LEVEL", relWhat, "Rare and better only.", "RE-LEVEL", false)
        elseif ilvl >= lvl then
            SetRow(rowRelevel, "RE-LEVEL" .. Dim("iLvl " .. ilvl), relWhat, "Already at your level (" .. lvl .. ").", "RE-LEVEL", false)
        else
            local prism, rgold = ItemData.RelevelCost(w.Rarity, ilvl, lvl)
            SetRow(rowRelevel, string.format("RE-LEVEL  iLvl %d → %d", ilvl, lvl), relWhat, { { "Prism", prism }, { "Gold", rgold } }, "RE-LEVEL")
        end
        do -- (UPDATE 8 RARITY v4: Ascension Essence -- a Rare becomes a Mythic and gains its Mythic line; ItemData.CraftV5Check says why not)
            local ok, why = ItemData.CraftV5Check("Ascend", w, isGear)
            SetRow(rowAscend, "ASCEND  Rare → Mythic", "A Rare becomes a Mythic: its numbers rise to Mythic's and it gains one more line (the Mythic line).",
                ok and { { "AscensionEssence", 1 }, { "Gold", gold } } or tostring(why), "ASCEND")
        end
        -- REROLL IT (0.97 CRAFTING v4: no locks; Prism Shards + gold, dearer with every reroll of this item)
        -- (UPDATE 7 CRAFTING v5: Prism = REROLL VALUES -- same lines and tiers, new numbers; the full reroll is the Storm Core)
        local VALUES_WHAT = "Keeps every line and its tier, and rerolls the numbers inside each tier. Every reroll of this item costs more."
        if w.Twinned then -- (CHASE ITEMS: no craft of any kind on a twinned item)
            SetRow(rowReforge, "REROLL VALUES", VALUES_WHAT, "Twinned items can't be crafted.", "REROLL", false)
        elseif frozen then
            SetRow(rowReforge, "REROLL VALUES", VALUES_WHAT, "This relic's lines are fixed.", "REROLL", false)
        elseif rank < 2 or total == 0 then
            SetRow(rowReforge, "REROLL VALUES", VALUES_WHAT, "No lines to reroll.", "REROLL", false)
        else
            local rc2 = ItemData.RerollCost(w, isGear, (hooks.GetState() or {}).Level)
            local n = tonumber(w.Rerolls) or 0
            SetRow(rowReforge, "REROLL VALUES" .. Dim(n == 0 and ("all " .. total .. " lines") or (n .. " reroll" .. (n == 1 and "" or "s") .. " so far")),
                VALUES_WHAT, { { "Prism", rc2.Prism }, { "Gold", rc2.Gold } }, "REROLL")
        end
        -- REROLL GUN (fixes 2026-10-16 #2): a random other gun of your class, same rarity / level / power, new affixes
        rowRetype.Row.Visible = not isGear and ItemData.MaterialUnlocked("ShiftShard", lvl)
        if rowRetype.Row.Visible then
            local ClassData = require(script.Parent:WaitForChild("ClassData"))
            local group = ClassData.GroupOf(state.Class)
            local can, why = ItemData.CanRetype(w, group)
            local cls = group and ItemData.WeaponGroups.Label[group] or "your class"
            local what = group and ("Becomes a random " .. cls .. " of the same rarity and level. New affixes; upgrades reset.")
                or "Becomes a random gun of your class, same rarity and level. New affixes; upgrades reset."
            if can then
                local rt = ItemData.RetypeCost(w, lvl)
                SetRow(rowRetype, "REROLL GUN" .. Dim("random " .. cls), what, { { "ShiftShard", rt.ShiftShard }, { "Gold", rt.Gold } }, "REROLL")
            else
                SetRow(rowRetype, "REROLL GUN", what, tostring(why), "REROLL", false)
            end
        end
        -- CRAFTING v5 rows (ItemData.CraftV5Check says why one can't be used)
        do
            local V5 = {
                { rowGraft, "Graft", "RIVET", "Adds one random line (it can be a penalty line, like any roll).", "RIVET" },
                { rowStrip, "Strip", "SCRAPE", "Removes one random line.", "SCRAPE" },
                { rowTemper, "Temper", "HONE", "Raises one random line one tier, up to what this item's level allows (T" .. ItemData.AffixTierCap(w.Rarity, ilvl) .. ").", "HONE" },
                { rowStorm, "Storm", "WILDFIRE REROLL", "Rerolls everything: how many lines (inside this rarity's band), which ones and their tiers.", "WILDFIRE" },
                { rowOver, "Overcharge", "REDLINE", "A gamble, then LOCKED for good: 30% nothing, 30% a bonus line past the limit at the top tier, 25% a full reroll, 15% one good line turns bad.", "REDLINE" },
                { rowSockets, "Sockets", "BORE  " .. Dim(w.Sockets or "no sockets"), "Rerolls how many sockets (rarity + item level set the odds). Mods that no longer fit go back to your bag.", "BORE", true },
                { rowLinks, "Links", "SOLDER", "Rerolls which sockets are linked (only the biggest linked group's mods work).", "SOLDER", true },
                { rowColours, "Colours", "TINT", "Rerolls the socket colours, leaning to this gun's usual colours.", "TINT", true },
            }
            hdrSock.Visible = (not isGear) and ItemData.MaterialUnlocked("SocketBore", lvl)
            do -- (CHASE ITEMS) TWIN GLASS
                local st = hooks.GetState() or {}
                local have = (type(st.Materials) == "table" and st.Materials.TwinGlass) or 0
                local show = ItemData.ZENITH_LIVE == true or have > 0
                hdrTwin.Visible, rowTwin.Row.Visible = show, show
                if show then
                    local ok, why = ItemData.CanTwin(w)
                    SetRow(rowTwin, "TWIN GLASS", "An exact copy of this item goes into your bag. Both copies become TWINNED: no crafting of any kind, and neither can be twinned again. The copy comes out locked.",
                        ok and { { "TwinGlass", 1 } } or tostring(why), "TWIN")
                end
            end
            for _, v in ipairs(V5) do
                local row, action, title, what, btn = v[1], v[2], v[3], v[4], v[5]
                local key = ItemData.CRAFT_V5_KEY[action]
                row.Row.Visible = ItemData.MaterialUnlocked(key, lvl) and not (v[6] and isGear)
                if row.Row.Visible then
                    local ok, why = ItemData.CraftV5Check(action, w, isGear)
                    SetRow(row, title, what, ok and { { key, 1 }, { "Gold", gold } } or tostring(why), btn)
                end
            end
        end
        if frozen then
            SetRow(rowTune, "TUNE", "Same affixes, new numbers.", "Relic gear can't be rerolled.", "TUNE", false)
        elseif total == 0 then
            SetRow(rowTune, "TUNE", "Same affixes, new numbers.", "No affixes to tune.", "TUNE", false)
        else
            SetRow(rowTune, "TUNE", "Keeps the same affixes and rerolls their numbers inside their ranges.", { { "TuningKit", 1 }, { "Gold", gold } }, "TUNE")
        end
        if rank < 3 then
            SetRow(rowPrefix, "CHANGE PREFIX", "A new elemental or special prefix.", "Rare and better only.", "CHANGE", false)
        else
            SetRow(rowPrefix, "CHANGE PREFIX", "Rolls a new elemental or special prefix.", { { "PrefixCatalyst", 1 }, { "Gold", gold } }, "CHANGE")
        end
        -- ADD OR REMOVE AFFIXES
        do
            local ok, why = ItemData.CanCraft("Augment", w, isGear, lvl)
            SetRow(rowAugment, "AUGMENT" .. Dim(string.format("%d / %d affixes", total, ItemData.AffixCap(w, isGear))), "Adds one random affix to a free slot.",
                ok and CostList(ItemData.CraftCost("Augment", w, isGear)) or tostring(why), "AUGMENT")
        end
        do
            local ok, why = ItemData.CanCraft("Purge", w, isGear, lvl)
            SetRow(rowPurge, "PURGE", "Removes one affix at random (a sealed one too) to free a slot.",
                ok and CostList(ItemData.CraftCost("Purge", w, isGear)) or tostring(why), "PURGE") -- (0.75: seals don't choose it)
        end
        -- UNIQUE POWER
        if not isGear then
            local codex = CodexList(state)
            local cur = w.UniqueTrait and (w.UniqueTrait.Name or w.UniqueTrait.Id)
            local impWhat = "Choose a weapon and a power from your Codex, then confirm."
            if #codex == 0 then
                SetRow(rowImprint, "IMPRINT A POWER" .. Dim("Codex empty"), impWhat, "Dismantle a weapon that has a unique power to unlock that power for good.", "CHOOSE", false)
            elseif not ItemData.ImprintCost[w.Rarity] then
                SetRow(rowImprint, "IMPRINT A POWER" .. Dim(#codex .. " in your Codex"), impWhat, "This weapon is below Rare: pick another one in the next step.", "CHOOSE", false)
            else
                SetRow(rowImprint, "IMPRINT A POWER" .. Dim(#codex .. " in your Codex"), impWhat, { { "Prism", ItemData.ImprintCost[w.Rarity] }, { "Gold", gold } }, "CHOOSE")
            end
            rowImprint.Btn.SetEnabled(#codex > 0 and not busy) -- (the picker checks the cost for the weapon you pick)
            if not cur then
                SetRow(rowTrait, "REROLL POWER", "Turns this weapon's unique power into a different random one.", "This weapon has no unique power.", "REROLL", false)
            else
                SetRow(rowTrait, "REROLL POWER" .. Dim(cur .. " → random"), "Turns this weapon's unique power into a different random one.",
                    { { "FateShard", 1 }, { "Gold", gold } }, "REROLL")
            end
        end
    end

    local function Flash(good: boolean, msg: string)
        resultLbl.TextColor3 = good and C.Good or C.Bad
        resultLbl.Text = msg
        local s = resultLbl:FindFirstChildOfClass("UIScale") or New("UIScale", { Parent = resultLbl })
        s.Scale = 1.25
        TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        -- the card pulses on a good result
        if good and cardStroke then -- (UI CLEAN: a brief brighter edge, no thick flash)
            cardStroke.Transparency = 0.2
            TweenService:Create(cardStroke, TweenInfo.new(0.5), { Transparency = 0.86 }):Play()
        end
    end

    -- (QOL F3 2026-10-28) SAFE CRAFTING: opts.Guard = a craft that can lose lines asks "CLICK AGAIN" first on a Mythic+ / relic item
    -- or one with a ★ perfect roll; opts.Repeat = SHIFT-click does up to REPEAT_N in a row and stops early when a craft fails (out of
    -- currency, can't be used) or the result gains a ★ perfect roll / its first top-tier line (the next roll would lose it).
    local REPEAT_N = 5
    local armed: { [any]: any } = {}
    local function KeepScore(w: any): (number, boolean)
        local stars = 0
        for _, l in ipairs(ItemData.LinesOf(w, ItemType() == "Gear")) do if ItemData.PerfectMark(l) ~= "" then stars += 1 end end
        local okTop, top = pcall(ItemData.HasTopTierLine, w)
        return stars, okTop and top == true
    end
    local function Risky(w: any): boolean
        if w.Exotic or (ItemData.RarityRank[w.Rarity] or 1) >= (ItemData.RarityRank.Mythic or 4) then return true end
        return (KeepScore(w)) > 0
    end
    local function ShiftDown(): boolean
        local UIS = game:GetService("UserInputService")
        return UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)
    end
    local devClicks: { [string]: any } = {} -- (QOL F3 Studio hook: Player attr DevForgeClick = "<row name>[:shift]")
    local function Run(r: any, fn: (any) -> (), opts: any?)
        local function OnClick(forceShift: boolean?)
            if busy or not r.Btn.Button.Active then return end
            local state = hooks.GetState()
            local w = state and Selected(state)
            if not w then return end
            if opts and opts.Guard and Risky(w) then
                local a = armed[r]
                if not (a and a.Uid == w.Uid and os.clock() - a.At < 4) then
                    click()
                    local at = os.clock()
                    armed[r] = { Uid = w.Uid, At = at }
                    r.Btn.SetText("CLICK AGAIN")
                    Flash(false, (w.Exotic or (ItemData.RarityRank[w.Rarity] or 1) >= (ItemData.RarityRank.Mythic or 4)) and "A " .. string.upper(w.Exotic and "Relic" or w.Rarity) .. " item: click again to craft it."
                        or "It has a ★ perfect roll that can be lost: click again to craft it.")
                    task.delay(4, function() if armed[r] and armed[r].At == at then armed[r] = nil; Refresh() end end)
                    return
                end
                armed[r] = nil
            end
            local reps = (opts and opts.Repeat and (ShiftDown() or forceShift == true)) and REPEAT_N or 1
            busy = true
            click()
            local stars0, top0 = KeepScore(w)
            for i = 1, reps do
                local ok, res = pcall(fn, w)
                if not ok then Flash(false, "Something went wrong: " .. tostring(res)); break end
                if res == false or i == reps then break end
                Refresh()
                w = Selected(hooks.GetState())
                if not w or not r.Btn.Button.Active then break end
                local stars, top = KeepScore(w)
                if stars > stars0 or (top and not top0) then
                    Flash(true, string.format("Stopped after %d: %s", i, stars > stars0 and "a ★ perfect roll landed" or "a top-tier line landed"))
                    break
                end
            end
            busy = false
            Refresh()
        end
        r.Btn.Button.MouseButton1Click:Connect(function() OnClick(false) end)
        devClicks[r.Row.Name] = OnClick
    end
    if game:GetService("RunService"):IsStudio() then
        local lp = game:GetService("Players").LocalPlayer
        lp:GetAttributeChangedSignal("DevForgeClick"):Connect(function()
            local v = tostring(lp:GetAttribute("DevForgeClick") or "")
            local name, mod = string.match(v, "^(%w+):?(%a*)$")
            if name and devClicks[name] then task.spawn(devClicks[name], mod == "shift") end
        end)
    end
    local function Apply(w: any, updated: any)
        if updated then for k, v in pairs(updated) do w[k] = v end end
        if hooks.OnItemChanged then hooks.OnItemChanged(w) end
    end

    Run(rowUpgrade, function(w)
        local ok, msg, outcome = Remotes.GetFunction("UpgradeWeapon"):InvokeServer(w.Uid)
        if ok and outcome == "success" then
            if hooks.PlaySuccess then hooks.PlaySuccess() end
            Flash(true, tostring(msg))
        else
            if ok and hooks.PlayFail then hooks.PlayFail() end
            Flash(false, tostring(msg))
        end
        task.wait(0.15) -- the state sync (materials, upgrade level) lands first
        if hooks.OnItemChanged then hooks.OnItemChanged(w) end
    end)
    local function Craft(kind: string, label: string)
        return function(w)
            local lockArg = (kind == "Reforge" and next(locks) ~= nil) and LockList() or nil -- (0.61 AFFIX SEALS)
            local ok, err, updated = Remotes.GetFunction("ForgeReroll"):InvokeServer(w.Uid, ItemType(), kind, nil, lockArg)
            if ok then
                Apply(w, updated)
                if hooks.PlaySuccess then hooks.PlaySuccess() end
                Flash(true, label .. ": " .. ((updated and updated.Name) or w.Name))
            else
                Flash(false, tostring(err))
            end
            task.wait(0.15)
            return ok == true -- (QOL F3: a SHIFT repeat stops on a failed craft)
        end
    end
    -- (QOL F3: Guard = CLICK AGAIN on a Mythic+ / ★ item, Repeat = SHIFT-click up to 5)
    local GUARD, GUARD_REPEAT = { Guard = true }, { Guard = true, Repeat = true }
    Run(rowReforge, Craft("Reforge", "Rerolled"), GUARD_REPEAT)
    Run(rowRetype, Craft("Retype", "New gun"), GUARD)
    -- (CRAFTING v5: the server answers with what happened -- "Grafted: +12% Fire Rate (T4)")
    local function CraftV5(kind: string)
        return function(w)
            local ok, msg, updated = Remotes.GetFunction("ForgeReroll"):InvokeServer(w.Uid, ItemType(), kind)
            if ok then
                Apply(w, updated)
                if hooks.PlaySuccess then hooks.PlaySuccess() end
                Flash(true, tostring(msg))
            else
                Flash(false, tostring(msg))
            end
            task.wait(0.15)
            return ok == true -- (QOL F3: a SHIFT repeat stops on a failed craft)
        end
    end
    Run(rowGraft, CraftV5("Graft"))
    Run(rowStrip, CraftV5("Strip"), GUARD) -- (QOL F3)
    Run(rowTemper, CraftV5("Temper"))
    Run(rowStorm, CraftV5("Storm"), GUARD_REPEAT) -- (QOL F3)
    Run(rowOver, CraftV5("Overcharge"), GUARD) -- (QOL F3)
    Run(rowSockets, CraftV5("Sockets"))
    Run(rowLinks, CraftV5("Links"))
    Run(rowColours, CraftV5("Colours"))
    Run(rowTwin, CraftV5("Twin"), GUARD) -- (CHASE ITEMS: ForgeReroll "Twin" = ZenithServer.Twin)
    Run(rowTune, Craft("Tune", "Tuned"), GUARD_REPEAT) -- (QOL F3)
    Run(rowPrefix, Craft("Prefix", "New prefix"), GUARD) -- (QOL F3)
    Run(rowTrait, Craft("Trait", "New trait"))
    Run(rowRelevel, function(w)
        local ok, err, updated = Remotes.GetFunction("ForgeLevelUp"):InvokeServer(w.Uid, ItemType())
        if ok then
            Apply(w, updated)
            if hooks.PlaySuccess then hooks.PlaySuccess() end
            Flash(true, "Re-leveled to item level " .. tostring((updated and updated.ItemLevel) or w.ItemLevel))
        else
            Flash(false, tostring(err))
        end
        task.wait(0.15)
    end)

    -- FORGE CRAFTING (0.61f): Augment / Purge / Ascend
    local function CraftAction(action: string)
        return function(w)
            local lockArg = nil -- (0.75 CRAFTING v3: Purge is always random)
            local ok, msg, updated = Remotes.GetFunction("ForgeCraft"):InvokeServer(action, w.Uid, ItemType(), lockArg)
            if ok then
                Apply(w, updated)
                if action == "Purge" then locks = {} end -- (the affixes moved up: old lock indices no longer match)
                if hooks.PlaySuccess then hooks.PlaySuccess() end
                Flash(true, tostring(msg))
            else
                Flash(false, tostring(msg))
            end
            task.wait(0.15)
        end
    end
    Run(rowAugment, CraftAction("Augment"))
    Run(rowPurge, CraftAction("Purge"), GUARD) -- (QOL F3)
    Run(rowAscend, CraftV5("Ascend")) -- (UPDATE 8: the v5 path, ForgeReroll "Ascend")

    -- IMPRINT PICKER (owner: "The imprinting also doesnt make sense, it should allow you to pick a weapon, show you which
    -- weapon its on, confirm etc"): 1 = the weapon (Rare and better, each with the power it has now), 2 = a power from your
    -- Codex (what it does + which of your weapons already carry it), then what changes, the cost, CONFIRM / CANCEL.
    local imp = { Weapon = nil, Power = nil }
    local impShade = New("TextButton", { Name = "ImprintPicker", Text = "", AutoButtonColor = false, Active = true, BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ZIndex = 20, Visible = false, Parent = root })
    local impCard = UIStyle.Card(impShade, { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -60, 1, -110) }, C.Gold)
    Text({ Text = "IMPRINT A POWER", TextSize = 24, TextColor3 = C.Gold, Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -120, 0, 30), Parent = impCard })
    Text({ Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, TextWrapped = true, Position = UDim2.fromOffset(18, 40), Size = UDim2.new(1, -90, 0, 30), Parent = impCard,
        Text = "Your Codex holds every power you've unlocked: dismantle a weapon that has a unique power to keep that power forever. Imprinting puts it on a weapon and replaces the power it had." })
    local impClose = UIStyle.Button(impCard, "X", C.Red, UDim2.fromOffset(40, 36), UDim2.new(1, -54, 0, 12), "Close")
    local function Column(x: number, wScale: number, label: string): ScrollingFrame
        Text({ Text = label, TextSize = 15, Position = UDim2.new(x, 18, 0, 78), Size = UDim2.new(wScale, -30, 0, 20), Parent = impCard })
        return New("ScrollingFrame", { BackgroundColor3 = C.CardDark, BorderSizePixel = 0, Position = UDim2.new(x, 18, 0, 102), Size = UDim2.new(wScale, -30, 1, -212),
            ScrollBarThickness = 6, ScrollBarImageColor3 = C.Sub, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = impCard }, {
            UIStyle.Corner(2), New("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
            New("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 5) }),
        }) :: ScrollingFrame
    end
    local impWeapons = Column(0, 0.42, "1   PICK THE WEAPON")
    local impPowers = Column(0.42, 0.58, "2   PICK A POWER")
    local impSummary = Text({ Font = UIStyle.BodyFont, TextSize = 14, RichText = true, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.new(0, 18, 1, -100), Size = UDim2.new(1, -250, 0, 40), Parent = impCard })
    local impCost = New("Frame", { Name = "Cost", BackgroundTransparency = 1, Position = UDim2.new(0, 18, 1, -52), Size = UDim2.new(1, -250, 0, 22), Parent = impCard }, {
        New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    local impCancel = UIStyle.Button(impCard, "CANCEL", C.Steel, UDim2.fromOffset(100, 46), UDim2.new(1, -226, 1, -66), "Cancel")
    local impConfirm = UIStyle.Button(impCard, "CONFIRM", C.Gold, UDim2.fromOffset(110, 46), UDim2.new(1, -120, 1, -66), "Confirm")
    local function PickRow(parent: Instance, order: number, sel: boolean, color: Color3, titleText: string, subText: string, onClick: () -> ())
        local b = New("TextButton", { Name = "P" .. order, Text = "", AutoButtonColor = false, BackgroundColor3 = sel and UIStyle.Darken(color, 0.6) or C.Card,
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = parent }, {
            UIStyle.Corner(2), New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
            New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 7), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 8) }),
        })
        UIStyle.Stroke(sel and color or C.Border, sel and 2 or 1).Parent = b
        Text({ Text = titleText, TextSize = 15, TextColor3 = color, RichText = true, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = b })
        Text({ Font = UIStyle.BodyFont, Text = subText, TextSize = 12, TextColor3 = C.Sub, RichText = true, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = b })
        b.MouseButton1Click:Connect(onClick)
        return b
    end
    local function ImpTarget(state: any): any
        for _, w in ipairs(state.Inventory or {}) do if w.Uid == imp.Weapon then return w end end
        return nil
    end
    local RenderImprint
    RenderImprint = function()
        local state = hooks.GetState() or {}
        for _, f in ipairs({ impWeapons, impPowers }) do for _, c in ipairs(f:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end end
        local weapons = {}
        for _, w in ipairs(state.Inventory or {}) do if ItemData.ImprintCost[w.Rarity] then table.insert(weapons, w) end end
        table.sort(weapons, function(a, b)
            local ra, rb = ItemData.RarityRank[a.Rarity] or 1, ItemData.RarityRank[b.Rarity] or 1
            if ra ~= rb then return ra > rb end
            return (a.ItemLevel or 1) > (b.ItemLevel or 1)
        end)
        local target = ImpTarget(state)
        local eqUid = state.EquippedWeapon and state.EquippedWeapon.Uid
        if #weapons == 0 then
            Text({ Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40), Text = "You have no Rare or better weapons.", Parent = impWeapons })
        end
        for i, w in ipairs(weapons) do
            local cur = w.UniqueTrait and (w.UniqueTrait.Name or w.UniqueTrait.Id)
            PickRow(impWeapons, i, w.Uid == imp.Weapon, ItemData.RarityColors[w.Rarity] or C.Text, ItemData.DisplayName(w) .. ((w.Uid == eqUid) and "  ★" or ""),
                string.format("%s  •  iLvl %d  •  %s", w.Rarity, w.ItemLevel or 1, cur and ('power: <font color="#FFB81C">' .. cur .. "</font>") or "no power yet"),
                function() click(); imp.Weapon = w.Uid; RenderImprint() end)
        end
        local carriers = {}
        for _, w in ipairs(state.Inventory or {}) do
            local id = w.UniqueTrait and w.UniqueTrait.Id
            if id then carriers[id] = carriers[id] or {}; table.insert(carriers[id], ItemData.DisplayName(w)) end
        end
        local codex = CodexList(state)
        if #codex == 0 then
            Text({ Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(1, 0, 0, 60), Parent = impPowers,
                Text = "Your Codex is empty. Dismantle a weapon that has a unique power (most Rare and better ones do) to unlock it here." })
        end
        for i, t in ipairs(codex) do
            local col = ItemData.RarityColors[t.Tier] or C.Gold
            local on = carriers[t.Id]
            local onTarget = target and target.UniqueTrait and target.UniqueTrait.Id == t.Id
            local where = onTarget and '<font color="#FFB81C">Already on the weapon you picked.</font>'
                or (on and ("On your: " .. table.concat(on, ", ")) or "Not on any of your weapons.")
            PickRow(impPowers, i, t.Id == imp.Power, col, t.Name .. '  <font color="#9A9CA4">' .. string.upper(t.Tier or "") .. "</font>",
                (t.Description or "") .. "\n" .. where, function() click(); imp.Power = t.Id; RenderImprint() end)
        end
        local power = imp.Power and ItemData.TraitById[imp.Power]
        local costs = nil
        if not target then
            impSummary.Text = "Pick the weapon to imprint (left)."
        elseif not power then
            impSummary.Text = "Pick a power (right)."
        else
            local cur = target.UniqueTrait and (target.UniqueTrait.Name or target.UniqueTrait.Id)
            local same = target.UniqueTrait and target.UniqueTrait.Id == power.Id
            impSummary.Text = string.format('Imprint <font color="#FFB81C">%s</font> onto <font color="%s">%s</font>.  %s', power.Name,
                Hex(ItemData.RarityColors[target.Rarity] or C.Text), ItemData.DisplayName(target),
                same and "It already has this power." or (cur and ("It replaces " .. cur .. ".") or "It has no power now."))
            costs = { { "Prism", ItemData.ImprintCost[target.Rarity] }, { "Gold", ItemData.CraftGold(target, false) } }
        end
        CostChips(impCost, state, costs or {})
        impConfirm.SetEnabled(costs ~= nil and Afford(state, costs) and not (target.UniqueTrait and target.UniqueTrait.Id == imp.Power) and not busy)
    end
    local function CloseImprint() impShade.Visible = false end
    rowImprint.Btn.Button.MouseButton1Click:Connect(function()
        if busy or not rowImprint.Btn.Button.Active then return end
        click()
        local state = hooks.GetState() or {}
        local w = Selected(state)
        imp.Weapon = (w and ItemData.ImprintCost[w.Rarity]) and w.Uid or nil
        imp.Power = nil
        impShade.Visible = true
        RenderImprint()
    end)
    impClose.Button.MouseButton1Click:Connect(function() click(); CloseImprint() end)
    impCancel.Button.MouseButton1Click:Connect(function() click(); CloseImprint() end)
    impConfirm.Button.MouseButton1Click:Connect(function()
        if busy or not impConfirm.Button.Active then return end
        local state = hooks.GetState() or {}
        local target = ImpTarget(state)
        local power = imp.Power and ItemData.TraitById[imp.Power]
        if not (target and power) then return end
        busy = true
        click()
        local okCall, ok, err, updated = pcall(function() return Remotes.GetFunction("ForgeReroll"):InvokeServer(target.Uid, "Weapon", "Imprint", power.Id) end)
        busy = false
        if okCall and ok then
            Apply(target, updated)
            if hooks.PlaySuccess then hooks.PlaySuccess() end
            CloseImprint()
            selectedUid = target.Uid
            Flash(true, "Imprinted " .. power.Name .. " on " .. ItemData.DisplayName(updated or target))
            task.wait(0.15)
            Refresh()
        else
            impSummary.Text = '<font color="#FF8080">' .. tostring(okCall and err or ok) .. "</font>"
        end
    end)

    benchPrev.Button.MouseButton1Click:Connect(function()
        if not benchPrev.Button.Active then return end
        click()
        benchRank = math.max(1, (benchRank or 1) - 1)
        Refresh()
    end)
    benchNext.Button.MouseButton1Click:Connect(function()
        if not benchNext.Button.Active then return end
        click()
        benchRank = (benchRank or 1) + 1
        Refresh()
    end)
    benchBuild.Button.MouseButton1Click:Connect(function()
        if busy or not benchBuild.Button.Active then return end
        local state = hooks.GetState()
        if not state then return end
        busy = true
        click()
        local rarity = ItemData.Rarities[benchRank or 1]
        local ok, msg, item = Remotes.GetFunction("ForgeCraft"):InvokeServer("Bench", benchPick.Kind, benchPick.Base, rarity)
        if ok then
            if hooks.PlaySuccess then hooks.PlaySuccess() end
            Flash(true, tostring(msg) .. "  (in your bag)")
            if item and hooks.OnItemChanged then hooks.OnItemChanged(item) end
        else
            Flash(false, tostring(msg))
        end
        task.wait(0.15)
        busy = false
        Refresh()
    end)
    for k, b in pairs(tabs) do
        b.Button.MouseButton1Click:Connect(function()
            if busy or mode == k then return end
            click()
            mode = k
            selectedUid = nil
            locks, locksFor = {}, nil
            resultLbl.Text = ""
            Refresh()
        end)
    end

    -- opening the Forge starts on your equipped weapon
    root:GetPropertyChangedSignal("Visible"):Connect(function()
        if root.Visible then
            CloseImprint()
            Fit()
            selectedUid = nil
            resultLbl.Text = ""
            Refresh()
        end
    end)

    return { Frame = root, Refresh = function() Refresh() end, Select = function(uid: string) selectedUid = uid end }
end

return ForgeMenu
