--!nocheck
-- The Dungeons window (client UI, UIStyle look): set up a run (difficulty, bot skill 1-10 -- biomes are mixed) and
-- play SOLO, or open a FRIENDS-only / PUBLIC room that others join (max 4), Dungeon Lootr-style.
-- The right side shows your party (host can kick / start) or, when you're not in one, the open rooms.
--
--   local lobby = LobbyMenu.Build(parentFolder, {
--       StartSolo = fn(biome, difficulty, botSkill),   -- solo run on this client
--       PlayClick = fn(), OnClose = fn(), Toast = fn(text),
--   })
local Players = game:GetService("Players")
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local DungeonGenerator = require(script.Parent:WaitForChild("DungeonGenerator"))
local StatCalculator = require(script.Parent:WaitForChild("StatCalculator"))
local ItemData = require(script.Parent:WaitForChild("ItemData"))

local LobbyMenu = {}
local C = UIStyle.Colors
local New, Text = UIStyle.New, UIStyle.Text
local LocalPlayer = Players.LocalPlayer

local BIOMES = {
    { Id = "Fire", Title = "MOLTEN", Color = Color3.fromRGB(255, 100, 40) },
    { Id = "Ice", Title = "CRYO", Color = Color3.fromRGB(80, 200, 255) },
    { Id = "Cyber", Title = "CYBER", Color = Color3.fromRGB(50, 220, 170) },
    { Id = "Void", Title = "VOID", Color = Color3.fromRGB(170, 80, 255) },
    { Id = "Storm", Title = "STORM", Color = Color3.fromRGB(150, 210, 255) },
    { Id = "Dream", Title = "DREAM", Color = Color3.fromRGB(255, 150, 230) }, -- (0.53)
    { Id = "Flats", Title = "FLATS", Color = Color3.fromRGB(255, 140, 80) },  -- (0.53)
}
do -- (0.87 WORLDS: the twelve world biomes)
    local ok, WB = pcall(require, script.Parent:WaitForChild("WorldBiomes"))
    if ok then
        for _, id in ipairs(WB.LIST) do table.insert(BIOMES, { Id = id, Title = WB.Titles[id].Name, Color = WB.Titles[id].Color }) end
    end
end
-- the difficulty ladder (ItemData.DifficultyOrder); ENDLESS is a separate game type played at any of them
local DIFF_COLORS = {
    Easy = Color3.fromRGB(70, 200, 90), Normal = Color3.fromRGB(40, 150, 240), Hard = Color3.fromRGB(240, 70, 70),
    Brutal = Color3.fromRGB(255, 130, 30), Nightmare = Color3.fromRGB(180, 40, 110), Torment = Color3.fromRGB(200, 30, 40),
    Cataclysm = Color3.fromRGB(255, 120, 20), Oblivion = Color3.fromRGB(225, 225, 235),
    Ruin = Color3.fromRGB(200, 90, 50), Dread = Color3.fromRGB(150, 60, 200), Apocalypse = Color3.fromRGB(255, 70, 30),
    Annihilation = Color3.fromRGB(220, 30, 70), Eternity = Color3.fromRGB(120, 210, 255), Singularity = Color3.fromRGB(255, 215, 110),
}
LobbyMenu.DIFF_COLORS = DIFF_COLORS -- (the Party Finder colours its rows the same way)
local DIFFS = {}
for _, id in ipairs(ItemData.OpenDifficulties and ItemData.OpenDifficulties() or ItemData.DifficultyOrder) do -- (LAUNCH CAP: closed tiers aren't listed)
    local m = ItemData.DifficultyModes[id]
    table.insert(DIFFS, { Id = id, Title = string.upper(id), Floors = m and m.MaxWaves or 10, Color = DIFF_COLORS[id] or Color3.fromRGB(150, 150, 160) })
end
local GAME_TYPES = {
    { Id = "Standard", Title = "STANDARD", Color = Color3.fromRGB(80, 200, 255) }, -- (UI v4: was the old primary gold)
    { Id = "Endless", Title = "ENDLESS", Color = Color3.fromRGB(150, 70, 240) },
    { Id = "Raid", Title = "RAID  8-12", Color = Color3.fromRGB(230, 60, 60) }, -- (owner 2026-10-05: "Add raids (8-12 players)")
}
-- RAIDS OFF (owner 2026-10-05: "just remove raids for now"): no RAID button (the server refuses raid rooms too:
-- PartyService.RAIDS_ON). Flip both to bring them back.
local RAIDS_ON = false
if not RAIDS_ON then table.remove(GAME_TYPES, 3) end
local MODES = {
    { Id = "Solo", Title = "SOLO", Color = C.Blue },
    { Id = "Friends", Title = "FRIENDS", Color = C.Green },
    { Id = "Public", Title = "PUBLIC", Color = C.Orange },
}
local function Find(list, id) for _, v in ipairs(list) do if v.Id == id then return v end end return list[1] end

function LobbyMenu.Build(parent: Instance, hooks: any)
    local click = hooks.PlayClick or function() end
    local toast = hooks.Toast or function() end
    local root = UIStyle.Panel(parent, { Name = "DungMenu", Size = UDim2.fromOffset(1000, 700), Accent = C.Purple })
    local fit = New("UIScale", { Name = "FitScale", Parent = root })
    local function Fit()
        UIStyle.Fit(root, fit, 1000, 700, 40) -- (700 tall since the 14-tier grid; phones: fit the width + swipe)
    end
    Fit()
    if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Fit) end
    UIStyle.TitleBar(root, "DUNGEONS", C.Purple, RAIDS_ON and "Play solo, open a room for up to 4, or gather 8-12 for a RAID." or "Play solo or open a room for up to 4.", function()
        click()
        if hooks.OnClose then hooks.OnClose() end
    end)

    -- state
    local sel = { Biome = "Fire", Difficulty = "Easy", Endless = false, Raid = false, BotSkill = DungeonGenerator.DEFAULT_BOT_SKILL, Mode = "Solo" }
    local function SelKey(): string return ItemData.RunKey(sel.Difficulty, sel.Endless) end
    local room: any = nil -- my room snapshot (PartyUpdate)
    local busy = false
    local quietLeave = false -- starting alone closes the room: no "you left" message for that

    ---------------------------------------------------------------- left: run setup
    local setup = UIStyle.Card(root, { Name = "Setup", Position = UDim2.fromOffset(14, 78), Size = UDim2.new(0, 560, 1, -92) })
    local y = 10
    local function Header(t: string)
        -- (UI v4 NEON LAYOUT: section labels are small caps in the secondary colour, not big white titles)
        local l = Text({ Text = t, TextSize = 13, TextColor3 = C.Sub, Position = UDim2.fromOffset(16, y + 6), Size = UDim2.new(1, -32, 0, 18), Parent = setup })
        l:SetAttribute("TypeRole", "Label")
        y += 28
    end

    -- MIXED RUNS (2026-10-03): no biome pick -- every floor rolls its own. The row just shows what you can get.
    Header(#BIOMES .. " BIOMES  •  a new one every floor")
    local biomeBtns = {} -- (none: nothing to pick)
    -- (0.62, owner: "the biomes in the dungeons menu ... go off the screen": 7 x 91 px ran past the 560 px card) -- the
    -- chips share the card's width. (0.87: 19 biomes -- colour swatches with their icon or initials, the name on hover)
    local gap = 4
    local chipW = math.floor((560 - 32 - gap * (#BIOMES - 1)) / #BIOMES)
    local hoverName = Text({ Text = "", TextSize = 12, Position = UDim2.fromOffset(300, y - 24), Size = UDim2.fromOffset(244, 20),
        TextXAlignment = Enum.TextXAlignment.Right, Stroke = 1.5, Parent = setup })
    for i, b in ipairs(BIOMES) do
        -- (UI v4: dark chips with the biome's icon in its colour -- a strip of 19 filled swatches read as a rainbow bar)
        local chipStroke = UIStyle.Stroke(b.Color, 1); chipStroke.Transparency = 0.55
        local chip = New("Frame", { Name = "Biome_" .. b.Id, BackgroundColor3 = C.Bg1, BackgroundTransparency = 0, Size = UDim2.fromOffset(chipW, 30),
            Position = UDim2.fromOffset(16 + (i - 1) * (chipW + gap), y), Parent = setup }, { UIStyle.Corner(4), chipStroke })
        local key = "b_" .. string.lower(b.Id)
        if UIStyle.HasIcon and UIStyle.HasIcon(key) then
            UIStyle.Icon(key, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(math.min(20, chipW - 4), math.min(20, chipW - 4)),
                ImageColor3 = b.Color:Lerp(Color3.new(1, 1, 1), 0.25), Parent = chip })
        else
            Text({ Text = string.sub(b.Title, 1, 1), TextSize = 14, Size = UDim2.fromScale(1, 1), Stroke = 1.5, Parent = chip })
        end
        UIStyle.HoverTip(chip, function() hoverName.Text = b.Title; hoverName.TextColor3 = b.Color end,
            function() if hoverName.Text == b.Title then hoverName.Text = "" end end) -- (a tap shows it on phones)
    end
    y += 42 -- (compacted 2026-10-04 for the game-type row)

    -- GAME TYPE (owner 2026-10-04: "Endless should be its own gametype, and you can then select a difficulty within that")
    Header("GAME TYPE")
    local typeBtns = {}
    for i, g in ipairs(GAME_TYPES) do
        local btn = UIStyle.Button(setup, g.Title, g.Color, UDim2.fromOffset(172, 38), UDim2.fromOffset(16 + (i - 1) * 178, y), "Type_" .. g.Id)
        btn.Label.TextSize = 16
        typeBtns[g.Id] = btn
        btn.Button.MouseButton1Click:Connect(function()
            if not btn.Button.Active then return end
            click(); sel.Endless = (g.Id == "Endless"); sel.Raid = (g.Id == "Raid")
            if sel.Raid and sel.Mode == "Solo" then sel.Mode = "Public" end -- (a raid is always a room)
            LobbyMenu._Changed()
        end)
    end
    y += 42
    Header("DIFFICULTY")
    local diffBtns = {}
    for i, d in ipairs(DIFFS) do
        -- (14 tiers since 2026-10-05: 5 x 3 instead of 4 x 2)
        local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
        local btn = UIStyle.Button(setup, d.Title, d.Color, UDim2.fromOffset(102, 32), UDim2.fromOffset(16 + col * 106, y + row * 36), "Diff_" .. d.Id)
        btn.Label.TextSize = 14
        -- (Update 5: a locked tier shows a lock SHAPE + dim name instead of "LOCKED  NAME" squeezed to 9 px)
        if UIStyle.HasIcon("lock") then
            btn.Lock = UIStyle.Icon("lock", { Name = "Lock", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(15, 15),
                ImageColor3 = C.Sub, Visible = false, ZIndex = btn.Label.ZIndex + 1, Parent = btn.Button })
            New("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 4), Parent = btn.Label })
        end
        diffBtns[d.Id] = btn
        btn.Button.MouseButton1Click:Connect(function()
            if not btn.Button.Active then return end
            click(); sel.Difficulty = d.Id; LobbyMenu._Changed()
        end)
    end
    y += 108
    -- what the selected difficulty does (vs Easy): enemies, rewards, loot, resist penalty
    local diffInfo = Text({ Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 40),
        RichText = true, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = setup })
    y += 38

    local yB = y -- (PHONE LAYOUT: what's above this goes in the left column, the rest in the right)
    Header("BOT SKILL")
    local skillName = Text({ TextSize = 24, Position = UDim2.fromOffset(16, y - 2), Size = UDim2.new(1, -32, 0, 30), Stroke = 2, Parent = setup })
    local skillInfo = Text({ Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, Position = UDim2.fromOffset(16, y + 28), Size = UDim2.new(1, -32, 0, 18), RichText = true, Parent = setup })
    y += 48
    -- 10 notched steps
    local track = New("Frame", { Name = "SkillTrack", BackgroundColor3 = Color3.fromRGB(22, 26, 40), Position = UDim2.fromOffset(28, y + 10), Size = UDim2.new(1, -56, 0, 14), Parent = setup }, { UIStyle.Corner(7), UIStyle.Stroke(C.Border, 2) })
    local fill = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0.3, 1), BorderSizePixel = 0, Parent = track }, { UIStyle.Corner(7) })
    local fillGrad = UIStyle.Gradient(C.Green, C.Green, 0); fillGrad.Parent = fill
    local stepBtns = {}
    for i = 1, 10 do
        local b = New("TextButton", { Name = "Step" .. i, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new((i - 1) / 9, 0, 0.5, 0),
            Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = track }, { UIStyle.Corner(13), UIStyle.Stroke(C.Border, 3) })
        Text({ Text = tostring(i), TextSize = 13, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Border, ZIndex = 3, Parent = b })
        UIStyle.Hover(b, 0.15)
        stepBtns[i] = b
        b.MouseButton1Click:Connect(function()
            if room and room.HostUserId ~= LocalPlayer.UserId then return end
            click(); sel.BotSkill = i; LobbyMenu._Changed()
        end)
    end
    Text({ Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, Position = UDim2.fromOffset(16, y + 30), Size = UDim2.fromOffset(200, 16), Text = "slower bots, 0.75x rewards", Parent = setup })
    Text({ Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, Position = UDim2.new(1, -216, 0, y + 30), Size = UDim2.fromOffset(200, 16), TextXAlignment = Enum.TextXAlignment.Right, Text = "the sharpest bots, 2x rewards", Parent = setup })
    y += 50

    local modeY = y -- (UI v4: the mode hint sits on this header row, right-aligned)
    Header("MODE")
    local modeBtns = {}
    for i, m in ipairs(MODES) do
        local btn = UIStyle.Button(setup, m.Title, m.Color, UDim2.fromOffset(170, 44), UDim2.fromOffset(16 + (i - 1) * 178, y), "Mode_" .. m.Id)
        modeBtns[m.Id] = btn
        btn.Button.MouseButton1Click:Connect(function()
            if not btn.Button.Active then return end
            click(); sel.Mode = m.Id; LobbyMenu._Changed()
        end)
    end
    y += 56
    local modeHint = Text({ Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, Position = UDim2.fromOffset(90, modeY + 6), Size = UDim2.new(1, -106, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Parent = setup })

    -- (2026-10-13: 50 tall from the bottom -- at 56 / -70 it covered the mode hint line above it)
    local goBtn = UIStyle.Button(setup, "START", C.Green, UDim2.new(1, -32, 0, 50), UDim2.new(0, 16, 1, -60), "Go")
    goBtn.SetStrong(true) -- (UI v4: the window's one call to action stays a filled slab)
    goBtn.Label.TextSize = 26

    ---------------------------------------------------------------- right: party / rooms
    local side = UIStyle.Card(root, { Name = "Side", Position = UDim2.fromOffset(586, 78), Size = UDim2.new(1, -600, 1, -92) })
    local sideTitle = Text({ TextSize = 20, Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -266, 0, 26), Stroke = 2, Parent = side })
    local refreshBtn = UIStyle.Button(side, "REFRESH", C.Steel, UDim2.fromOffset(110, 32), UDim2.new(1, -124, 0, 8), "Refresh")
    refreshBtn.Label.TextSize = 14
    -- (2026-10-20 PARTY FINDER) open rooms in EVERY server, next to this server's list
    local finderBtn = UIStyle.Button(side, "ALL SERVERS", C.Steel, UDim2.fromOffset(120, 32), UDim2.new(1, -250, 0, 8), "Finder")
    finderBtn.Label.TextSize = 13
    finderBtn.Button.MouseButton1Click:Connect(function() click(); if hooks.OpenFinder then hooks.OpenFinder() end end)
    local list = New("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 48), Size = UDim2.new(1, -16, 1, -116),
        ScrollBarThickness = 6, ScrollBarImageColor3 = C.Sub, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = side }, {
        New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
        New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4) }),
    })
    local leaveBtn = UIStyle.Button(side, "LEAVE ROOM", C.Red, UDim2.new(1, -32, 0, 46), UDim2.new(0, 16, 1, -60), "Leave")

    ---------------------------------------------------------------- TARGET LOOT (pity, ItemData.Pity) under the rooms
    list.Size = UDim2.new(1, -16, 1, -300)
    local tl = UIStyle.Card(side, { Name = "TargetLoot", Position = UDim2.new(0, 8, 1, -246), Size = UDim2.new(1, -16, 0, 176) })
    Text({ Text = "TARGET LOOT", TextSize = 17, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 22), Stroke = 1.5, Parent = tl })
    local tlInfo = Text({ Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 28), TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top, Text = "Every chest fills a meter toward a drop of your picks (at your level). 1 rare weapon + 1 rare gear a day, then unlimited at normal odds.", Parent = tl })
    local wBtn = UIStyle.Button(tl, "WEAPON: none", C.Steel, UDim2.new(0.5, -16, 0, 32), UDim2.fromOffset(12, 60), "PickWeapon")
    wBtn.Label.TextSize = 13
    local gBtn = UIStyle.Button(tl, "GEAR: none", C.Steel, UDim2.new(0.5, -16, 0, 32), UDim2.new(0.5, 4, 0, 60), "PickGear")
    gBtn.Label.TextSize = 13
    local tlMeters = Text({ Font = UIStyle.BodyFont, TextSize = 12, Position = UDim2.fromOffset(12, 98), Size = UDim2.new(1, -24, 0, 72), RichText = true, TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top, Parent = tl })
    -- the pick list (covers the setup card while open)
    local pickPanel = UIStyle.Card(root, { Name = "PickList", Position = UDim2.fromOffset(14, 78), Size = UDim2.new(0, 560, 1, -92) }, C.Gold)
    pickPanel.Visible = false
    pickPanel.ZIndex = 10
    local pickTitle = Text({ TextSize = 18, Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -140, 0, 24), Stroke = 1.5, ZIndex = 11, Parent = pickPanel })
    local pickClose = UIStyle.Button(pickPanel, "BACK", C.Red, UDim2.fromOffset(100, 32), UDim2.new(1, -112, 0, 8), "PickBack")
    pickClose.Button.ZIndex = 11
    local pickGrid = New("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 50), Size = UDim2.new(1, -20, 1, -60),
        ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 11, Parent = pickPanel }, {
        New("UIGridLayout", { CellSize = UDim2.fromOffset(170, 40), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    local function MyPity() return ItemData.PityState(hooks.GetState and hooks.GetState() or nil) end
    local function SetTargets(w, g)
        task.spawn(function()
            local ok, msg = Remotes.GetFunction("SetPityTargets"):InvokeServer(w, g)
            if not ok and msg then toast(msg) end
            task.wait(0.3)
            LobbyMenu._RenderPity()
        end)
    end
    local function Pct(x) return string.format("%d%%", math.floor((x or 0) * 100 + 0.5)) end
    function LobbyMenu._RenderPity()
        local p = MyPity()
        local wb = p.W and ItemData.BaseWeapons[p.W]
        wBtn.SetText("WEAPON: " .. (wb and string.upper(wb.Name or p.W) or "none"))
        gBtn.SetText("GEAR: " .. (p.G and string.upper(ItemData.GearBaseNames[p.G] or p.G) or "none"))
        local function Line(label, has, claimed, d, i)
            if not has then return label .. ": <font color=\"#8a8f9c\">pick one above</font>" end
            return string.format("%s: daily rare %s  •  unlimited %s", label, claimed and "<font color=\"#7dd88a\">claimed today</font>" or ("<font color=\"#ffd25a\">" .. Pct(d) .. "</font>"), Pct(i))
        end
        local st = hooks.GetState and hooks.GetState()
        local gain = ItemData.PityGain(st and st.Level or 1, SelKey())
        tlMeters.Text = Line("Weapon", p.W ~= nil, p.CW, p.DW, p.IW) .. "\n" .. Line("Gear", p.G ~= nil, p.CG, p.DG, p.IG)
            .. ((gain < 1) and string.format("\n<font color=\"#ff8a6a\">You out-level %s: chests fill only %s as fast here.</font>", sel.Difficulty, Pct(gain)) or "")
    end
    local function OpenPicker(kind)
        for _, c in ipairs(pickGrid:GetChildren()) do if c:IsA("GuiButton") then c:Destroy() end end
        local p = MyPity()
        local entries = {}
        if kind == "W" then
            pickTitle.Text = "TARGET WEAPON"
            for i, id in ipairs(ItemData.Lineup) do
                local b = ItemData.BaseWeapons[id]
                if b then table.insert(entries, { Id = id, Name = b.Name or id, Sub = ItemData.WeaponTypeLine(b, id):gsub(" class", ""), Order = i }) end
            end
        else
            pickTitle.Text = "TARGET GEAR"
            for i, g in ipairs(ItemData.Pity.GEAR) do table.insert(entries, { Id = g, Name = ItemData.GearBaseNames[g] or g, Order = i }) end
        end
        table.insert(entries, 1, { Id = false, Name = "None", Order = 0 })
        for _, e in ipairs(entries) do
            local cur = (kind == "W" and p.W or p.G) == (e.Id or nil)
            local b = New("TextButton", { Name = "P_" .. tostring(e.Id), Text = (e.Sub and (e.Name .. "\n" .. e.Sub) or e.Name), Font = UIStyle.Font, TextSize = 12,
                TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = cur and Color3.fromRGB(150, 110, 30) or Color3.fromRGB(34, 38, 50), AutoButtonColor = true,
                LayoutOrder = e.Order, ZIndex = 12, Parent = pickGrid }, { UIStyle.Corner(4) })
            b.MouseButton1Click:Connect(function()
                click()
                pickPanel.Visible = false
                local id = e.Id or nil
                if kind == "W" then SetTargets(id, p.G) else SetTargets(p.W, id) end
            end)
        end
        pickPanel.Visible = true
    end
    wBtn.Button.MouseButton1Click:Connect(function() click(); OpenPicker("W") end)
    gBtn.Button.MouseButton1Click:Connect(function() click(); OpenPicker("G") end)
    pickClose.Button.MouseButton1Click:Connect(function() click(); pickPanel.Visible = false end)

    local function Request(action: string, arg: any)
        local ok, res = Remotes.GetFunction("PartyRequest"):InvokeServer(action, arg)
        if not ok and type(res) == "string" then toast(res) end
        return ok, res
    end

    local rooms = {}
    local function RenderSide()
        for _, c in ipairs(list:GetChildren()) do if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end end
        if room then
            sideTitle.Text = "YOUR PARTY  " .. #room.Members .. "/" .. room.Max
            refreshBtn.Button.Visible = false
            finderBtn.Button.Visible = false
            leaveBtn.Button.Visible = true
            local isHost = room.HostUserId == LocalPlayer.UserId
            for i, m in ipairs(room.Members) do
                local row = UIStyle.Card(list, { Name = "M" .. i, Size = UDim2.new(1, 0, 0, 50), LayoutOrder = i })
                Text({ Text = (m.IsHost and "★ " or "") .. m.Name, TextSize = 18, Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -120, 0, 24), Stroke = 1.5, Parent = row })
                Text({ Font = UIStyle.BodyFont, Text = "Level " .. m.Level, TextSize = 12, TextColor3 = C.Sub, Position = UDim2.fromOffset(14, 27), Size = UDim2.new(1, -120, 0, 16), Parent = row })
                if isHost and m.UserId ~= LocalPlayer.UserId then
                    local k = UIStyle.Button(row, "KICK", C.Red, UDim2.fromOffset(70, 32), UDim2.new(1, -80, 0.5, -16), "Kick")
                    k.Label.TextSize = 14
                    k.Button.MouseButton1Click:Connect(function() click(); Request("Kick", m.UserId) end)
                end
            end
            for i = #room.Members + 1, room.Max do
                local row = UIStyle.Card(list, { Name = "Empty" .. i, Size = UDim2.new(1, 0, 0, 50), LayoutOrder = i })
                Text({ Font = UIStyle.BodyFont, Text = "Waiting for a player...", TextSize = 13, TextColor3 = C.Sub, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), Parent = row })
            end
            Text({ Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 99, TextWrapped = true,
                Text = (room.Privacy == "Friends" and "Friends-only room: your Roblox friends in this server can join from their Dungeons menu." or "Public room: anyone in this server can join from their Dungeons menu.")
                    .. (room.Raid and string.format(" RAID: needs %d-%d players.", room.RaidMin or 8, room.Max) or "")
                    .. (room.Privacy == "Public" and " Players in every server can find it in the PARTY FINDER." or "") .. " Bots get +60% health per extra player.", Parent = list })
        else
            sideTitle.Text = "OPEN ROOMS"
            refreshBtn.Button.Visible = true
            finderBtn.Button.Visible = hooks.OpenFinder ~= nil
            leaveBtn.Button.Visible = false
            if #rooms == 0 then
                Text({ Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Sub, Size = UDim2.new(1, 0, 0, 60), TextWrapped = true,
                    Text = "No open rooms in this server. Pick FRIENDS or PUBLIC on the left to open one, or look in every server with ALL SERVERS.", Parent = list })
            end
            for i, r in ipairs(rooms) do
                local rd, rEndless = ItemData.ParseRunKey(r.Difficulty)
                local d = Find(DIFFS, rd)
                local row = UIStyle.Card(list, { Name = "Room" .. r.Id, Size = UDim2.new(1, 0, 0, 64), LayoutOrder = i }, d.Color)
                local BT = require(script.Parent:WaitForChild("BossTrials"))
                local trialDef = r.Trial and BT.ById[r.Trial.Id]
                Text({ Text = r.HostName .. (r.Raid and "'s RAID" or (trialDef and ("'s " .. trialDef.Name .. " T" .. BT.Tiers[r.Trial.Tier].Name) or "'s room")), TextSize = 18, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -110, 0, 24), Stroke = 1.5, Parent = row })
                local skill = DungeonGenerator.BotSkillLevels[r.BotSkill] or DungeonGenerator.BotSkillLevels[4]
                Text({ Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -110, 0, 26), TextWrapped = true,
                    Text = string.format("%s  •  %s  •  Bot skill %d %s  •  %d/%d  •  %s", "Mixed biomes", (rEndless and "ENDLESS " or "") .. d.Title, r.BotSkill, skill.Name, #r.Members, r.Max, (r.Privacy == "Friends") and "Friends" or "Public"), Parent = row })
                local full = #r.Members >= r.Max or r.State ~= "Lobby"
                local j = UIStyle.Button(row, full and (r.State ~= "Lobby" and "IN RUN" or "FULL") or "JOIN", C.Green, UDim2.fromOffset(84, 40), UDim2.new(1, -94, 0.5, -20), "Join")
                j.SetEnabled(not full)
                j.Button.MouseButton1Click:Connect(function()
                    if not j.Button.Active or busy then return end
                    busy = true
                    click()
                    local ok, snap = Request("Join", r.Id)
                    if ok then room = snap; LobbyMenu._Changed() end
                    busy = false
                end)
            end
        end
    end

    local function RefreshRooms()
        if room then return end
        local ok, res = Remotes.GetFunction("PartyRequest"):InvokeServer("List")
        rooms = (ok and type(res) == "table") and res or {}
        RenderSide()
    end

    -- Redraw the setup side (selection highlight, host-only locks, labels).
    function LobbyMenu._Changed()
        local isHost = room ~= nil and room.HostUserId == LocalPlayer.UserId
        local canEdit = (room == nil) or isHost
        if room then
            -- the room's settings are what count
            if isHost then
                if sel.Biome ~= room.Biome or SelKey() ~= room.Difficulty or sel.BotSkill ~= room.BotSkill or sel.Mode ~= room.Privacy or sel.Raid ~= (room.Raid == true) then
                    if sel.Mode == "Solo" then sel.Mode = room.Privacy end
                    task.spawn(Request, "Update", { Biome = sel.Biome, Difficulty = SelKey(), BotSkill = sel.BotSkill, Privacy = sel.Mode, Raid = sel.Raid })
                end
            else
                sel.Biome, sel.BotSkill, sel.Mode, sel.Raid = room.Biome, room.BotSkill, room.Privacy, room.Raid == true
                local rd, re = ItemData.ParseRunKey(room.Difficulty)
                sel.Difficulty, sel.Endless = rd or "Easy", re
            end
        end
        for id, btn in pairs(biomeBtns) do
            btn.SetColor(id == sel.Biome and Find(BIOMES, id).Color or Color3.fromRGB(58, 68, 100))
            btn.Button.Active = canEdit
        end
        -- locked difficulties (ItemData.DifficultyUnlock): dimmed with a lock; picking one shows how to open it
        local st = hooks.GetState and hooks.GetState() or nil
        for id, btn in pairs(diffBtns) do
            local open = not st or ItemData.DifficultyUnlock(st, id)
            btn.SetText(string.upper(id))
            -- (UI CLEAN R-B: a choice is the neutral slab + the 2 px off-white mark when picked, not a slab in its colour; the
            -- picked difficulty keeps its colour on the label)
            btn.SetColor(open and C.Bg2 or C.Well)
            btn.SetSelected(id == sel.Difficulty)
            if id == sel.Difficulty then btn.Label.TextColor3 = Find(DIFFS, id).Color:Lerp(C.Text, 0.25) end
            if btn.Lock then btn.Lock.Visible = not open end
            if not open and id ~= sel.Difficulty then btn.Label.TextColor3 = C.Muted end
            btn.Button.Active = canEdit
        end
        local selOpen, selWhy = true, nil
        if st then selOpen, selWhy = ItemData.DifficultyUnlock(st, sel.Difficulty) end
        for id, btn in pairs(typeBtns) do
            local on = (id == "Raid" and sel.Raid) or (not sel.Raid and ((id == "Endless") == sel.Endless) and id ~= "Raid")
            btn.SetColor(C.Steel); btn.SetSelected(on) -- (UI CLEAN R-B)
            btn.Button.Active = canEdit
        end
        for id, btn in pairs(modeBtns) do
            local on = id == sel.Mode
            btn.SetColor(C.Steel); btn.SetSelected(on) -- (UI CLEAN R-B)
            btn.Button.Active = canEdit and not ((room or sel.Raid) and id == "Solo")
        end
        do
            local inf = DungeonGenerator.DifficultyInfo(sel.Difficulty)
            local pen = StatCalculator.ResistPenalty(sel.Difficulty) -- (UPDATE 8 DEFENCE: DamageTypes.RESIST_PENALTY)
            local function X(v: number): string return string.format("<b>%.2fx</b>", v) end
            diffInfo.Text = string.format(
                '<font color="#FFFFFF">%s</font>  •  <font color="#FF8A8A">Monster level %s</font>%s\n<font color="#9BE89B">XP %s  •  Gold %s  •  Loot amount %s%s%s</font>',
                (sel.Raid and "RAID: 8-12 players, 3 floors ending on a RAID BOSS (shoot its shield orbs as a team). Everyone there gets a top item.")
                or (sel.Endless and "ENDLESS: no last floor. Go as deep as you can (a boss every 5th floor)") or (function()
                    -- estimated full-clear time: ~1.4 minutes a floor (fights + walking + looting)
                    local floors = Find(DIFFS, sel.Difficulty).Floors
                    if not selOpen then return '<font color="#FF8A8A">LOCKED: ' .. tostring(selWhy) .. "</font>" end
                    return string.format("%d floors, ending on a boss  •  about %d min", floors, math.round(floors * 1.6))
                end)(),
                (function() local ml = inf.MonsterLevel return sel.Endless and (ml[1] .. "+") or (ml[1] .. "-" .. ml[2]) end)(), (pen ~= 0) and string.format("  •  your resistances %d%%", math.round(pen * 100)) or "",
                X(inf.XP), X(inf.Gold), X(inf.Qty), "", inf.TopRarity and ("  •  drops up to " .. inf.TopRarity .. " (very rare)") or "")
        end
        local sk = DungeonGenerator.BotSkillLevels[sel.BotSkill]
        local t = (sel.BotSkill - 1) / 9
        -- (UI CLEAN R-A2 sweep: no green -> gold -> red ramp of slabs: the track is off-white up to your pick, the rest dim)
        local col = C.Text
        skillName.Text = sel.BotSkill .. "  •  " .. string.upper(sk.Name)
        skillName.TextColor3 = col
        skillInfo.Text = string.format("Bot speed %d%%  •  Rewards <b>%.2fx</b> (XP, gold and loot)%s", math.round(sk.Speed / DungeonGenerator.BotSkillLevels[6].Speed * 100), sk.Reward,
            sel.BotSkill == DungeonGenerator.DEFAULT_BOT_SKILL and "  •  recommended" or "")
        fill.Size = UDim2.new(t, 0, 1, 0)
        fillGrad.Color = ColorSequence.new(col, col)
        for i, b in ipairs(stepBtns) do
            b.BackgroundColor3 = (i <= sel.BotSkill) and col or C.Bg2
            local dl = b:FindFirstChildOfClass("TextLabel"); if dl then dl.TextColor3 = (i <= sel.BotSkill) and C.Bg0 or C.Sub end
            b.Size = (i == sel.BotSkill) and UDim2.fromOffset(34, 34) or UDim2.fromOffset(24, 24)
        end
        if room then
            modeHint.Text = isHost and "You're the host: pick the settings, then start when everyone's in." or "Waiting for the host to start."
            goBtn.SetText(isHost and ((room.Raid and string.format("START RAID (%d/%d, need %d)", #room.Members, room.Max, room.RaidMin or 8))
                or ("START DUNGEON (" .. #room.Members .. "/" .. room.Max .. ")")) or "WAITING FOR HOST...")
            if isHost and room.Ready then -- (QOL F4: a READY CHECK is running -- the pop-up shows who's ready)
                local n = 0
                for _, v in pairs(room.Ready.Answers or {}) do if v == true then n += 1 end end
                local late = workspace:GetServerTimeNow() >= (room.Ready.Until or 0)
                goBtn.SetText(late and string.format("START ANYWAY (%d/%d READY)", n, #room.Members) or string.format("READY CHECK (%d/%d)", n, #room.Members))
            end
            goBtn.SetColor(C.Accent) -- (UI CLEAN R-B: START = the primary, off-white)
            goBtn.SetEnabled(isHost)
        elseif sel.Mode == "Solo" then
            modeHint.Text = "Just you: the smoothest bots (they run on your computer)."
            goBtn.SetText(selOpen and "START SOLO RUN" or "LOCKED")
            goBtn.SetColor(C.Accent) -- (UI CLEAN R-B: START = the primary, off-white; was the blue SOLO colour)
            goBtn.SetEnabled(selOpen)
        else
            modeHint.Text = (sel.Mode == "Friends") and "Only your Roblox friends in this server can join." or "Anyone in this server can join."
            goBtn.SetText(selOpen and ("CREATE " .. string.upper(sel.Mode) .. (sel.Raid and " RAID" or " ROOM")) or "LOCKED")
            goBtn.SetColor(C.Accent) -- (UI CLEAN R-B: START = the primary)
            goBtn.SetEnabled(selOpen)
        end
        RenderSide()
        LobbyMenu._RenderPity()
    end

    goBtn.Button.MouseButton1Click:Connect(function()
        if busy or not goBtn.Button.Active then return end
        busy = true
        click()
        if room then
            local ok, res = Request("Start")
            if ok and type(res) == "table" and res.ReadyCheck then -- (QOL F4: the READY CHECK pop-up is up; the window stays)
                LobbyMenu._Changed()
            elseif ok and type(res) == "table" and res.Solo then
                quietLeave = true
                if hooks.OnClose then hooks.OnClose() end
                hooks.StartSolo(res.Biome, res.Difficulty, res.BotSkill) -- (res.Difficulty is the room's key)
            elseif ok then
                if hooks.OnClose then hooks.OnClose() end
            end
        elseif sel.Mode == "Solo" then
            if hooks.OnClose then hooks.OnClose() end
            hooks.StartSolo(sel.Biome, SelKey(), sel.BotSkill)
        else
            local ok, snap = Request("Create", { Privacy = sel.Mode, Biome = sel.Biome, Difficulty = SelKey(), BotSkill = sel.BotSkill, Raid = sel.Raid })
            if ok then room = snap end
            LobbyMenu._Changed()
        end
        busy = false
    end)
    leaveBtn.Button.MouseButton1Click:Connect(function()
        click()
        Request("Leave")
        room = nil
        sel.Mode = "Solo"
        LobbyMenu._Changed()
        RefreshRooms()
    end)
    refreshBtn.Button.MouseButton1Click:Connect(function() click(); RefreshRooms() end)

    Remotes.GetEvent("PartyUpdate").OnClientEvent:Connect(function(snap)
        local wasIn = room ~= nil
        room = snap
        if snap and snap.State == "Running" and root.Visible and hooks.OnClose then hooks.OnClose() end
        if not snap and wasIn and not quietLeave then toast("You left the room.") end
        if not snap then quietLeave = false end
        LobbyMenu._Changed()
        if not snap then RefreshRooms() end
    end)
    Remotes.GetEvent("PartyRoomsChanged").OnClientEvent:Connect(function()
        if root.Visible and not room then RefreshRooms() end
    end)
    root:GetPropertyChangedSignal("Visible"):Connect(function()
        if root.Visible then
            LobbyMenu._Changed()
            RefreshRooms()
        end
    end)

    ---------------------------------------------------------------- PHONE LAYOUT (2026-10-13, owner on a real phone:
    -- "a lot of stuff is either too big or doesnt work"). A phone gets the window only as tall as its screen (PhoneMinH)
    -- and the run setup splits into two columns -- WHAT to play (biomes, game type, difficulty; it scrolls, TARGET LOOT
    -- at its end) | HOW (bot skill, mode and START, always on screen) -- with the rooms list in the right third. Desktop
    -- keeps the one tall setup card; switching back (a phone preview turned off) restores every moved piece.
    root:SetAttribute("PhoneMinH", 300)
    local phoneUI = nil -- { Saved = { {obj, prop, value} }, ColA, ColB }
    local function Save(o: Instance, prop: string, v: any)
        table.insert(phoneUI.Saved, { o, prop, (o :: any)[prop] })
        if v ~= nil then (o :: any)[prop] = v end
    end
    local function PhoneLayout()
        local phone = UIStyle.IsPhone()
        if phone == (phoneUI ~= nil) then return end
        if not phone then
            for i = #phoneUI.Saved, 1, -1 do
                local e = phoneUI.Saved[i]
                if e[1].Parent then (e[1] :: any)[e[2]] = e[3] end
            end
            phoneUI.ColA:Destroy(); phoneUI.ColB:Destroy()
            phoneUI = nil
            return
        end
        phoneUI = { Saved = {} }
        local SETUP_W = 640
        Save(setup, "Size", UDim2.new(0, SETUP_W, 1, -92))
        local colA = New("ScrollingFrame", { Name = "PhoneWhat", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(0.5, -2, 1, 0),
            CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Parent = setup })
        UIStyle.StyleScroll(colA, 4)
        -- (the HOW column scrolls too -- a 360 pt phone is shorter still -- with START pinned under it)
        local colB = New("ScrollingFrame", { Name = "PhoneHow", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0.5, 2, 0, 0),
            Size = UDim2.new(0.5, -2, 1, -64), CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Parent = setup })
        UIStyle.StyleScroll(colB, 4)
        phoneUI.ColA, phoneUI.ColB = colA, colB
        -- y shifts in the narrow left column: the biome chips wrap to 2 rows (+34), the difficulty grid to 3 x 5 (+72)
        local chipY = math.huge
        for _, c in ipairs(setup:GetChildren()) do
            if c:IsA("GuiObject") and string.sub(c.Name, 1, 6) == "Biome_" then chipY = math.min(chipY, c.Position.Y.Offset) end
        end
        local diffY = math.huge
        for _, b in pairs(diffBtns) do diffY = math.min(diffY, b.Button.Position.Y.Offset) end
        local function ShiftA(oy: number): number
            return oy + ((oy > chipY) and 34 or 0) + ((oy > diffY + 80) and 72 or 0)
        end
        for _, c in ipairs(setup:GetChildren()) do
            if c:IsA("GuiObject") and c ~= colA and c ~= colB and c ~= goBtn.Button and c.Position.Y.Scale == 0 then
                local oy = c.Position.Y.Offset
                if oy < yB then
                    Save(c, "Parent", colA)
                    Save(c, "Position", UDim2.new(c.Position.X.Scale, c.Position.X.Offset, 0, ShiftA(oy)))
                else
                    Save(c, "Parent", colB)
                    Save(c, "Position", UDim2.new(c.Position.X.Scale, c.Position.X.Offset, 0, oy - yB + 6))
                end
            end
        end
        -- left column fix-ups (318 px wide instead of 560)
        local per, gap = 10, 4
        local chipW = math.floor((SETUP_W / 2 - 2 - 32 - gap * (per - 1)) / per)
        local i = 0
        for _, b in ipairs(BIOMES) do
            local chip = colA:FindFirstChild("Biome_" .. b.Id)
            if chip then
                local col, row = i % per, math.floor(i / per)
                Save(chip, "Size", UDim2.fromOffset(chipW, 30))
                Save(chip, "Position", UDim2.fromOffset(16 + col * (chipW + gap), chipY + row * 34))
                i += 1
            end
        end
        Save(hoverName, "Position", UDim2.new(1, -170, 0, hoverName.Position.Y.Offset))
        Save(hoverName, "Size", UDim2.fromOffset(156, 20))
        local k = 0
        for _, g in ipairs(GAME_TYPES) do
            local btn = typeBtns[g.Id]
            if btn then
                Save(btn.Button, "Size", UDim2.fromOffset(138, 38))
                Save(btn.Button, "Position", UDim2.fromOffset(16 + k * 144, btn.Button.Position.Y.Offset))
                k += 1
            end
        end
        for n, d in ipairs(DIFFS) do
            local btn = diffBtns[d.Id]
            local col, row = (n - 1) % 3, math.floor((n - 1) / 3)
            Save(btn.Button, "Size", UDim2.fromOffset(92, 32))
            Save(btn.Button, "Position", UDim2.fromOffset(16 + col * 96, ShiftA(diffY) + row * 36))
        end
        Save(diffInfo, "Size", UDim2.new(1, -32, 0, 72))
        local endA = diffInfo.Position.Y.Offset + 76
        -- TARGET LOOT goes to the end of the left column (the rooms list keeps the right third)
        Save(tl, "Parent", colA)
        Save(tl, "Position", UDim2.fromOffset(8, endA + 6))
        Save(tl, "Size", UDim2.new(1, -16, 0, 176))
        colA.CanvasSize = UDim2.fromOffset(0, endA + 6 + 176 + 12)
        -- right column fix-ups: the bot-skill line wraps to 2 lines, the two step captions share the width (2 lines), the
        -- MODE header goes (the three buttons say it), the mode buttons shrink, START is pinned under the column
        Save(skillInfo, "Size", UDim2.new(1, -32, 0, 34))
        Save(skillInfo, "TextWrapped", true)
        local infoY = skillInfo.Position.Y.Offset
        for _, c in ipairs(colB:GetChildren()) do
            if c:IsA("GuiObject") and c ~= skillInfo and c.Position.Y.Offset > infoY then
                Save(c, "Position", UDim2.new(c.Position.X.Scale, c.Position.X.Offset, 0, c.Position.Y.Offset + 14))
            end
        end
        local below = math.huge
        for _, c in ipairs(colB:GetChildren()) do
            if c:IsA("TextLabel") and (c.Text == "slower bots, 0.75x rewards" or c.Text == "the sharpest bots, 2x rewards") then
                local right = c.Text ~= "slower bots, 0.75x rewards"
                below = math.min(below, c.Position.Y.Offset)
                Save(c, "Position", UDim2.new(right and 0.5 or 0, right and 4 or 16, 0, c.Position.Y.Offset))
                Save(c, "Size", UDim2.new(0.5, -20, 0, 30))
                Save(c, "TextWrapped", true)
            end
        end
        for _, c in ipairs(colB:GetChildren()) do -- (everything under the captions moves down 12 to make room for line 2)
            if c:IsA("GuiObject") and c.Position.Y.Offset > below and c.Position.Y.Scale == 0 then
                Save(c, "Position", UDim2.new(c.Position.X.Scale, c.Position.X.Offset, 0, c.Position.Y.Offset + 12))
            end
        end
        local modeY = math.huge
        for _, c in ipairs(colB:GetChildren()) do
            if c:IsA("TextLabel") and c.Text == "MODE" then
                modeY = c.Position.Y.Offset
                Save(c, "Visible", false)
            end
        end
        for _, c in ipairs(colB:GetChildren()) do
            if c:IsA("GuiObject") and c.Position.Y.Offset > modeY then
                Save(c, "Position", UDim2.new(c.Position.X.Scale, c.Position.X.Offset, 0, c.Position.Y.Offset - 28))
            end
        end
        local m = 0
        for _, md in ipairs(MODES) do
            local btn = modeBtns[md.Id]
            if btn then
                Save(btn.Button, "Size", UDim2.fromOffset(94, 44))
                Save(btn.Button, "Position", UDim2.fromOffset(16 + m * 98, btn.Button.Position.Y.Offset))
                m += 1
            end
        end
        Save(modeHint, "Size", UDim2.new(1, -32, 0, 34))
        Save(modeHint, "TextWrapped", true)
        colB.CanvasSize = UDim2.fromOffset(0, modeHint.Position.Y.Offset + 40)
        Save(goBtn.Button, "Size", UDim2.new(0.5, -34, 0, 48))
        Save(goBtn.Button, "Position", UDim2.new(0.5, 18, 1, -58))
        -- rooms: the right third, its list as tall as the card (TARGET LOOT moved out)
        Save(side, "Position", UDim2.fromOffset(14 + SETUP_W + 12, 78))
        Save(side, "Size", UDim2.new(1, -(14 + SETUP_W + 12 + 14), 1, -92))
        Save(list, "Size", UDim2.new(1, -16, 1, -116))
        Save(pickPanel, "Size", UDim2.new(0, SETUP_W, 1, -92))
    end
    PhoneLayout()
    LocalPlayer:GetAttributeChangedSignal("DevPhone"):Connect(function() task.defer(PhoneLayout) end)
    if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(PhoneLayout) end

    LobbyMenu._Changed()
    return { Frame = root }
end

return LobbyMenu
