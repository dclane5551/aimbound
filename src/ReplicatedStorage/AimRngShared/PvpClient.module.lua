--!nocheck
-- PvpClient (0.59): the client side of duels (PvpService runs every rule; PvpData has the numbers + arenas).
--   * DUEL window [K]: players in the server (CHALLENGE), the arena pick, the WAGER switch, challenges you got, your record.
--     During a wager: your bag (click to add) | your wager | theirs, READY -> CONFIRM.
--   * the incoming-challenge popup (top of the screen, outside the menu folder).
--   * the DUEL HUD: score + clock on top, your health / armour bottom centre (big, like the classic arena shooters),
--     the opponent's on the right, countdown, frag callouts, the results screen.
--   * THE SHOT (AimRngClient's FireWeapon hands over through UI.PvpDef / UI.PvpShot): a fixed fire rate, one exact ray
--     that only tests the arena + the opponent's standard hitbox, range PvpData.RANGE; the server checks the report.
-- Built by AimRngClient: PvpClient.Build(menuFolder, hudGui, hooks).
-- DUELS v3 (2026-10-14): a MODE pick (PvpData.MODES) in the window + on challenges, shots fired in the air spread
-- (PvpData.AIR_SPREAD), Instagib numbers via PvpData.GunStatsFor, health pickups spin + sound.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Shared = script.Parent
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameSettings = require(Shared:WaitForChild("GameSettings")) -- (ABILITIES: the key name)
local PvpData = require(Shared:WaitForChild("PvpData"))

local PvpClient = {}
local C = UIStyle.Colors
local New = UIStyle.New
local ACCENT = Color3.fromRGB(255, 70, 70)
local LocalPlayer = Players.LocalPlayer

function PvpClient.Build(menuFolder: Instance, hudGui: Instance, hooks: any)
    local api = {}
    local duel = nil -- the last "Duel" snapshot (nil = none)
    local incoming = {}
    local busy = false
    local pickArena = PvpData.ARENAS[1].Id
    local pickWager = false
    local pickGun = nil -- (0.77: the gun BOTH duelists will use; nil / "Random" = a random gun, rolled when the duel starts)
    local pickMode = PvpData.MODES[1].Id -- (DUELS v3)
    local function MyMode(): string return LocalPlayer:GetAttribute("PvpMode") or pickMode end
    local pickAbility = PvpData.ABILITIES[1].Id -- (ABILITIES 2026-10-15: your one ability; sent with SetAbility on a pick)

    local function Act(...)
        if busy then return false end
        busy = true
        local ok, a, b = pcall(function(...) return Remotes.GetFunction("PvpAction"):InvokeServer(...) end, ...)
        busy = false
        if not ok then return false, "Couldn't reach the server." end
        if a == false and b then hooks.Toast(b) end
        return a, b
    end
    local function InDuel(): boolean return LocalPlayer:GetAttribute("PvpDuel") ~= nil end

    -- ===== the window =====
    local panel = UIStyle.Panel(menuFolder, { Name = "DuelMenu", Size = UDim2.fromOffset(1100, 680), Accent = ACCENT })
    UIStyle.TitleBar(panel, "DUEL", ACCENT, "one on one, first to 5. Only your aim and movement count", function() hooks.CloseAll() end)
    local body = New("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 1, -92), Parent = panel })
    -- (2026-10-13 phones: as tall as the screen -- the three columns scroll on their own, the ARENA column too on a phone)
    panel:SetAttribute("PhoneMinH", 300)
    local function Clear(f) for _, c in ipairs(f:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end end
    local function Header(parent, text, y)
        -- (Update 5: section-header style -- condensed caps in the secondary colour, not gold)
        local h = UIStyle.Text({ Text = text, TextSize = 16, TextColor3 = C.Sub, Position = UDim2.fromOffset(0, y or 0), Size = UDim2.new(1, 0, 0, 24), Parent = parent })
        h:SetAttribute("TypeRole", "Label")
        return h
    end
    local function Scroll(parent, pos, size)
        local sf = New("ScrollingFrame", { BackgroundColor3 = C.CardDark, BorderSizePixel = 0, Position = pos, Size = size, ScrollBarThickness = 6,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = parent }, { UIStyle.Corner(2) })
        New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf })
        New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), Parent = sf })
        return sf
    end
    local function ItemRow(parent, entry, order, onClick, tag)
        local it, isGear = entry.Item, entry.Kind == "Gear"
        local col = ItemData.ItemColor(it)
        local row = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.Card, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = order, Parent = parent }, { UIStyle.Corner(2) })
        New("Frame", { BackgroundColor3 = col, BorderSizePixel = 0, Size = UDim2.new(0, 5, 1, -8), Position = UDim2.fromOffset(4, 4), Parent = row })
        UIStyle.Text({ Text = ItemData.DisplayName(it), TextSize = 15, TextColor3 = col, Position = UDim2.fromOffset(16, 3), Size = UDim2.new(1, -60, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
        local sub = isGear and (ItemData.RarityLabel(it) .. " " .. tostring(it.Slot or "gear") .. "  •  iLvl " .. tostring(it.ItemLevel or 1))
            or (ItemData.RarityLabel(it) .. "  •  " .. ItemData.WeaponTypeLine(it) .. "  •  iLvl " .. tostring(it.ItemLevel or 1))
        UIStyle.Text({ Text = sub, TextSize = 11, TextColor3 = C.Sub, Font = UIStyle.BodyFont, Position = UDim2.fromOffset(16, 23), Size = UDim2.new(1, -60, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
        if tag then UIStyle.Text({ Text = tag, TextSize = 14, TextColor3 = ACCENT, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -54, 0, 0), Size = UDim2.new(0, 48, 1, 0), Parent = row }) end
        if onClick then row.MouseButton1Click:Connect(onClick) end
        if hooks.Tooltip then hooks.Tooltip(row, it, isGear) end
        return row
    end

    local RenderLobby, RenderWager
    -- the gun the duel will use (shown + sent to the server)
    local function MyGun(): string -- (what you ask for / counterpick with: "Random" or one gun)
        return pickGun or "Random"
    end
    local function Counter(id: number)
        -- a COUNTERPICK needs a specific gun: with RANDOM selected, open the window to pick one first
        if MyGun() == "Random" then
            hooks.Toast("Pick a gun in the DUEL window (DUEL GUN), then press COUNTER.")
            if not panel.Visible then hooks.OpenFrame(panel) end
            if RenderLobby then RenderLobby() end
            return
        end
        incoming[id] = nil
        Act("Respond", id, true, MyGun())
    end
    local function Fmt(n: number): string
        if n >= 10 then return tostring(math.floor(n + 0.5)) end
        return string.format("%.1f", n)
    end
    local CLASS_COL = { Pistol = Color3.fromRGB(120, 200, 255), SMG = Color3.fromRGB(110, 230, 160), Rifle = Color3.fromRGB(255, 190, 70),
        Heavy = Color3.fromRGB(255, 140, 60), Shotgun = Color3.fromRGB(255, 100, 100), Sniper = Color3.fromRGB(190, 130, 255), Laser = Color3.fromRGB(90, 230, 255) }
    local function ClassCol(c: string?): Color3 return CLASS_COL[c or ""] or C.Gold end
    local function Section(parent, text, x, y, w)
        local h = New("Frame", { BackgroundColor3 = C.CardDark, BorderSizePixel = 0, Position = UDim2.new(x, 0, 0, y), Size = UDim2.new(w, -8, 0, 26), Parent = parent }, { UIStyle.Corner(2) })
        New("Frame", { BackgroundColor3 = ACCENT, BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, 0), Parent = h })
        UIStyle.Text({ Text = text, TextSize = 15, TextColor3 = C.Gold, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -12, 1, 0), Parent = h })
        return h
    end
    local thumbs = {}
    RenderLobby = function()
        Clear(body)
        local st = hooks.GetState() or {}
        -- RECORD STRIP
        local rec = type(st.PvpStats) == "table" and st.PvpStats or {}
        local acc = (rec.Shots or 0) > 0 and math.floor((rec.Hits or 0) / rec.Shots * 100 + 0.5) or 0
        local strip = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), Parent = body })
        for i, t in ipairs({ { "WINS", rec.W or 0, Color3.fromRGB(120, 255, 140) }, { "LOSSES", rec.L or 0, Color3.fromRGB(255, 110, 110) },
            { "FRAGS", rec.Frags or 0, C.Gold }, { "ACCURACY", acc .. "%", Color3.fromRGB(90, 220, 255) } }) do
            local tile = New("Frame", { BackgroundColor3 = C.Card, Position = UDim2.new((i - 1) / 4, 0, 0, 0), Size = UDim2.new(0.25, -8, 1, 0), Parent = strip }, { UIStyle.Corner(2) })
            -- (UI CLEAN R-A2: the record tiles = a label + a display number in Text; no coloured top band)
            UIStyle.Text({ Text = tostring(t[2]), TextSize = 26, Font = Enum.Font.GothamBlack, TextColor3 = t[3], Position = UDim2.fromOffset(14, 6), Size = UDim2.new(0.5, 0, 1, -8), Parent = tile })
            UIStyle.Text({ Text = t[1], TextSize = 13, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(0.5, -14, 1, -8), Parent = tile })
        end
        local top = 62
        -- COLUMN 1: opponents (+ challenges for you on top)
        Section(body, "OPPONENTS", 0, top, 0.3)
        local list = Scroll(body, UDim2.new(0, 0, 0, top + 32), UDim2.new(0.3, -8, 1, -(top + 32)))
        local order = 0
        for id, r in pairs(incoming) do
            if os.clock() < r.Until then
                order += 1
                local row = New("Frame", { BackgroundColor3 = Color3.fromRGB(60, 30, 34), Size = UDim2.new(1, 0, 0, 86), LayoutOrder = order, Parent = list }, { UIStyle.Corner(2),
                    New("UIStroke", { Color = ACCENT, Thickness = 1.5 }) })
                UIStyle.Text({ Text = r.From .. " challenges you", TextSize = 15, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 20), Parent = row })
                UIStyle.Text({ Text = (r.ModeName or "CLASSIC") .. "  •  " .. r.ArenaName .. "  •  " .. (r.GunName or "RANDOM GUN") .. (r.Wager and "  •  GEAR WAGER" or ""), TextSize = 12, TextColor3 = r.Wager and C.Gold or C.Sub, Font = UIStyle.BodyFont,
                    Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -20, 0, 16), Parent = row })
                local accB = UIStyle.Button(row, "ACCEPT", C.Green, UDim2.new(0.34, -10, 0, 34), UDim2.fromOffset(10, 44))
                local ctrB = UIStyle.Button(row, "COUNTER", C.Gold, UDim2.new(0.33, -6, 0, 34), UDim2.new(0.34, 4, 0, 44))
                local decB = UIStyle.Button(row, "DECLINE", C.Red, UDim2.new(0.33, -10, 0, 34), UDim2.new(0.67, 2, 0, 44))
                accB.Button.MouseButton1Click:Connect(function() hooks.Click(); incoming[id] = nil; Act("Respond", id, true) end)
                ctrB.Button.MouseButton1Click:Connect(function() hooks.Click(); Counter(id) end)
                decB.Button.MouseButton1Click:Connect(function() hooks.Click(); incoming[id] = nil; Act("Respond", id, false); RenderLobby() end)
            end
        end
        local others = {}
        for _, pl in ipairs(Players:GetPlayers()) do if pl ~= LocalPlayer then table.insert(others, pl) end end
        table.sort(others, function(x, y) return x.DisplayName < y.DisplayName end)
        if #others == 0 then
            order += 1
            UIStyle.Text({ Text = "Nobody else is in this server yet. Invite a friend to duel.", TextSize = 14, TextColor3 = C.Sub, TextWrapped = true,
                Size = UDim2.new(1, 0, 0, 44), LayoutOrder = order, Parent = list })
        end
        for _, pl in ipairs(others) do
            order += 1
            local busyNow = pl:GetAttribute("PvpDuel") ~= nil or pl:GetAttribute("RunId") ~= nil
            local row = New("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, 0, 0, 64), LayoutOrder = order, Parent = list }, { UIStyle.Corner(2) })
            local img = New("ImageLabel", { BackgroundColor3 = C.CardDark, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(48, 48), Image = thumbs[pl.UserId] or "", Parent = row }, { UIStyle.Corner(2) })
            if not thumbs[pl.UserId] then
                task.spawn(function()
                    local ok, url = pcall(function() return Players:GetUserThumbnailAsync(pl.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48) end)
                    if ok and url then thumbs[pl.UserId] = url; if img.Parent then img.Image = url end end
                end)
            end
            UIStyle.Text({ Text = pl.DisplayName, TextSize = 16, Position = UDim2.fromOffset(64, 8), Size = UDim2.new(1, -72, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
            local where = pl:GetAttribute("PvpDuel") and "IN A DUEL" or (pl:GetAttribute("RunId") and "IN A RUN" or "AVAILABLE")
            local pill = New("Frame", { BackgroundColor3 = busyNow and Color3.fromRGB(70, 60, 40) or Color3.fromRGB(36, 70, 46), Position = UDim2.fromOffset(64, 32),
                Size = UDim2.fromOffset(78, 18), Parent = row }, { UIStyle.Corner(2) })
            UIStyle.Text({ Text = where, TextSize = 10, TextColor3 = busyNow and C.Gold or Color3.fromRGB(120, 255, 140), TextXAlignment = Enum.TextXAlignment.Center,
                Size = UDim2.fromScale(1, 1), Parent = pill })
            local inDuel = pl:GetAttribute("PvpDuel") ~= nil
            local b = UIStyle.Button(row, inDuel and "WATCH" or "DUEL", inDuel and Color3.fromRGB(120, 200, 255) or (busyNow and C.CardDark or ACCENT), UDim2.fromOffset(70, 30), UDim2.new(1, -78, 0, 28))
            b.Button.MouseButton1Click:Connect(function()
                if inDuel and hooks.Watch then -- (0.79 SPECTATE: watch their duel through their eyes)
                    hooks.Click()
                    hooks.Watch(pl.UserId)
                    return
                end
                hooks.Click()
                local ok, msg = Act("Challenge", pl.UserId, pickArena, pickWager, MyGun(), pickMode)
                if ok and msg then hooks.Toast(msg) end
            end)
        end
        -- COLUMN 2: your weapon (any gun; the same damage a second)
        Section(body, "DUEL GUN  (both players use it)", 0.3, top, 0.42)
        local gunCol = New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.3, 0, 0, top + 32), Size = UDim2.new(0.42, -8, 1, -(top + 32)), Parent = body })
        local isRandom = MyGun() == "Random"
        local me = PvpData.GunStats(isRandom and "AK47" or MyGun())
        local selCol = isRandom and C.Gold or ClassCol(me.Class)
        local sel = New("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, 0, 0, 78), Parent = gunCol }, { UIStyle.Corner(2), New("UIStroke", { Color = selCol, Thickness = 2 }) })
        UIStyle.Text({ Text = isRandom and "RANDOM GUN" or string.upper(me.Name), TextSize = 24, Font = Enum.Font.GothamBlack, TextColor3 = selCol, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 28), Parent = sel })
        UIStyle.Text({ Text = isRandom and "A gun is rolled when the duel starts: both of you get it." or string.format("%s damage  x  %s shots/s%s  =  %d damage a second", Fmt(me.PerShot), Fmt(me.Rate),
            me.Pellets > 1 and string.format("  (%d pellets)", me.Pellets) or "", PvpData.DPS), TextSize = 13, TextColor3 = C.Text, Font = UIStyle.BodyFont,
            Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 18), Parent = sel })
        local modeNote = (pickMode == "Instagib") and "INSTAGIB: everyone gets the rail, so the gun you pick is ignored."
            or ((pickMode == "Rotation") and "GUN ROTATION: this is round 1's gun; every frag rolls a new one of another class."
            or "Your challenges use this gun for BOTH players. On a challenge you get, COUNTER offers this gun instead: a coin flip decides.")
        UIStyle.Text({ Text = modeNote, TextSize = 11, TextColor3 = (pickMode ~= "Classic") and C.Gold or C.Sub, Font = UIStyle.BodyFont,
            TextWrapped = true, Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -24, 0, 22), Parent = sel })
        local grid = New("ScrollingFrame", { BackgroundColor3 = C.CardDark, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 86), Size = UDim2.new(1, 0, 1, -86),
            ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = gunCol }, { UIStyle.Corner(2) })
        New("UIGridLayout", { CellSize = UDim2.new(0.25, -6, 0, 50), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
        New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10), Parent = grid })
        do -- the RANDOM tile first
            local t = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = isRandom and UIStyle.Lighten(C.Card, 0.12) or C.Card, LayoutOrder = 0, Parent = grid }, { UIStyle.Corner(2) })
            New("Frame", { BackgroundColor3 = C.Gold, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0), Parent = t })
            if isRandom then New("UIStroke", { Color = C.Gold, Thickness = 2, Parent = t }) end
            UIStyle.Text({ Text = "RANDOM", TextSize = 13, TextColor3 = C.Gold, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -12, 0, 18), Parent = t })
            UIStyle.Text({ Text = "any gun", TextSize = 11, TextColor3 = C.Sub, Font = UIStyle.BodyFont, Position = UDim2.fromOffset(8, 24), Size = UDim2.new(1, -12, 0, 16), Parent = t })
            t.MouseButton1Click:Connect(function() hooks.Click(); pickGun = nil; RenderLobby() end)
        end
        local guns = {}
        for _, id in ipairs(PvpData.GunChoices()) do table.insert(guns, PvpData.GunStats(id)) end
        local CLASS_ORDER = { Pistol = 1, SMG = 2, Rifle = 3, Burst = 3, Heavy = 4, Shotgun = 5, Sniper = 6, Laser = 7 }
        table.sort(guns, function(x, y)
            local cx, cy = CLASS_ORDER[x.Class or ""] or 9, CLASS_ORDER[y.Class or ""] or 9
            if cx ~= cy then return cx < cy end
            return x.Rate > y.Rate
        end)
        for i, g in ipairs(guns) do
            local on = (not isRandom) and g.Id == me.Id
            local col = ClassCol(g.Class)
            local t = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = on and UIStyle.Lighten(C.Card, 0.12) or C.Card, LayoutOrder = i, Parent = grid }, { UIStyle.Corner(2) })
            New("Frame", { BackgroundColor3 = col, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0), Parent = t })
            if on then New("UIStroke", { Color = col, Thickness = 2, Parent = t }) end
            UIStyle.Text({ Text = g.Name, TextSize = 13, TextColor3 = on and col or C.Text, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -12, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, Parent = t })
            UIStyle.Text({ Text = Fmt(g.PerShot) .. " x " .. Fmt(g.Rate) .. "/s", TextSize = 11, TextColor3 = C.Sub, Font = UIStyle.BodyFont, Position = UDim2.fromOffset(8, 24), Size = UDim2.new(1, -12, 0, 16), Parent = t })
            t.MouseButton1Click:Connect(function()
                hooks.Click()
                pickGun = g.Id
                RenderLobby()
            end)
        end
        -- COLUMN 3: arena, wager, the rules
        Section(body, "ABILITY  •  ARENA", 0.72, top, 0.28)
        local phone = UIStyle.IsPhone()
        local right = New(phone and "ScrollingFrame" or "Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.72, 0, 0, top + 32), Size = UDim2.new(0.28, 0, 1, -(top + 32)), Parent = body })
        if phone then right.BorderSizePixel, right.ScrollBarThickness, right.CanvasSize = 0, 4, UDim2.fromOffset(0, 92 + #PvpData.ARENAS * 96 + 4 + 44 + 190) end
        local ART = { Rooftops = { Color3.fromRGB(255, 60, 170), Color3.fromRGB(60, 220, 255) }, Foundry = { Color3.fromRGB(255, 110, 30), Color3.fromRGB(255, 200, 80) } }
        -- MODE (DUELS v3): three buttons + what the picked one is
        -- ABILITY (2026-10-15): one each, picked here (the mode row is gone: only CLASSIC is left)
        local MY = 92 -- (height the ability block takes)
        for i, ab in ipairs(PvpData.ABILITIES) do
            local on = pickAbility == ab.Id
            local bb = UIStyle.Button(right, ab.Name, on and ACCENT or C.CardDark, UDim2.new(1 / #PvpData.ABILITIES, -4, 0, 30), UDim2.new((i - 1) / #PvpData.ABILITIES, 2, 0, 0))
            bb.Label.TextSize = 12
            bb.Button.MouseButton1Click:Connect(function()
                hooks.Click()
                local ok = Act("SetAbility", ab.Id)
                if ok then pickAbility = ab.Id end
                RenderLobby()
            end)
        end
        do
            local ab = PvpData.AbilityOf(pickAbility)
            UIStyle.Text({ Text = ab.Desc .. "  [" .. (GameSettings.BindName("Ability") or "F") .. "], every " .. ab.Cooldown .. " s.", TextSize = 11, Font = UIStyle.BodyFont,
                TextColor3 = C.Text, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(2, 34), Size = UDim2.new(1, -4, 0, MY - 38), Parent = right })
        end
        for i, m in ipairs(#PvpData.MODES > 1 and PvpData.MODES or {}) do
            local on = pickMode == m.Id
            local mb = UIStyle.Button(right, m.Name, on and ACCENT or C.CardDark, UDim2.new(1 / #PvpData.MODES, -4, 0, 30), UDim2.new((i - 1) / #PvpData.MODES, 2, 0, 0))
            mb.Label.TextSize = 12
            mb.Button.MouseButton1Click:Connect(function() hooks.Click(); pickMode = m.Id; RenderLobby() end)
        end
        if #PvpData.MODES > 1 then UIStyle.Text({ Text = PvpData.ModeOf(pickMode).Desc, TextSize = 11, Font = UIStyle.BodyFont, TextColor3 = C.Text, TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(2, 34), Size = UDim2.new(1, -4, 0, MY - 38), Parent = right }) end
        for i, a in ipairs(PvpData.ARENAS) do
            local on = pickArena == a.Id
            local cols = ART[a.Id] or { ACCENT, C.Gold }
            local card = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = on and UIStyle.Lighten(C.Card, 0.1) or C.Card,
                Position = UDim2.fromOffset(0, MY + (i - 1) * 96), Size = UDim2.new(1, 0, 0, 90), Parent = right }, { UIStyle.Corner(2) })
            -- (UI CLEAN R-A2: the arena's colour as ONE flat 2 px line along the bottom, not a 6 px gradient band on top)
            New("Frame", { BorderSizePixel = 0, BackgroundColor3 = cols[1], AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), Parent = card })
            if on then New("UIStroke", { Color = cols[1], Thickness = 2, Parent = card }) end
            UIStyle.Text({ Text = (on and "▶ " or "") .. a.Name, TextSize = 15, TextColor3 = on and cols[1] or C.Text, Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 20), Parent = card })
            UIStyle.Text({ Text = a.Desc, TextSize = 11, Font = UIStyle.BodyFont, TextColor3 = C.Sub, TextWrapped = true, Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 54), Parent = card })
            card.MouseButton1Click:Connect(function() hooks.Click(); pickArena = a.Id; RenderLobby() end)
        end
        local wy = MY + #PvpData.ARENAS * 96 + 4
        local wb = UIStyle.Button(right, pickWager and "GEAR WAGER: ON" or "GEAR WAGER: OFF", pickWager and C.Gold or C.CardDark, UDim2.new(1, 0, 0, 36), UDim2.fromOffset(0, wy))
        wb.Button.MouseButton1Click:Connect(function() hooks.Click(); pickWager = not pickWager; RenderLobby() end)
        local rules = New("Frame", { BackgroundColor3 = C.Card, Position = UDim2.fromOffset(0, wy + 44), Size = phone and UDim2.new(1, -6, 0, 186) or UDim2.new(1, 0, 1, -(wy + 44)), Parent = right }, { UIStyle.Corner(2) })
        UIStyle.Text({ Text = "RULES", TextSize = 13, TextColor3 = C.Gold, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 18), Parent = rules })
        local pm = PvpData.ModeOf(pickMode)
        UIStyle.Text({ Text = (pm.Instagib and "• one hit kills, no healing" or ("• spawn with " .. PvpData.HEALTH .. " health; headshots +" .. math.round((PvpData.HEADSHOT_MULT - 1) * 100) .. "%; " .. math.round(PvpData.VAMPIRIC * 100) .. "% of your damage heals you (up to "
            .. PvpData.MAX_HEALTH .. ")")) .. "\n• first to "
            .. pm.FragsToWin .. " frags, " .. math.floor(PvpData.TIME_LIMIT / 60) .. " min, then sudden death\n• dash (1 charge) + slide; a jump every " .. PvpData.JUMP_GAP .. " s, and shots fired in the air spread\n"
            .. "• one ability each [" .. (GameSettings.BindName("Ability") or "F") .. "]: BLINK, GUARD or PULSE\n"
            .. (pickWager and "• wager: up to " .. PvpData.WAGER_MAX .. " items each, the winner takes all" or "• gear and build don't count"),
            TextSize = 12, Font = UIStyle.BodyFont, TextColor3 = C.Text, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
            Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 1, -30), Parent = rules })
    end

    RenderWager = function()
        local s = duel
        Clear(body)
        local st = hooks.GetState() or {}
        local inOffer = {}
        for _, e in ipairs(s.Me.Items) do inOffer[e.Item.Uid] = true end
        local locked = s.Phase == "Locked"
        local c1 = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.34, -8, 1, -70), Parent = body })
        Header(c1, "YOUR BAG  (click to wager)")
        local bag = Scroll(c1, UDim2.fromOffset(0, 28), UDim2.new(1, 0, 1, -28))
        local eqW = st.EquippedWeapon and st.EquippedWeapon.Uid
        local eqG = {}
        for _, g in pairs(st.EquippedGear or {}) do if type(g) == "table" then eqG[g.Uid] = true end end
        local order = 0
        for _, w in ipairs(st.Inventory or {}) do
            if w.Uid ~= eqW and w.Uid ~= "W_STARTER_PISTOL" and not inOffer[w.Uid] then
                order += 1
                ItemRow(bag, { Kind = "Weapon", Item = w }, order, function() if not locked then hooks.Click(); Act("SetItem", "Weapon", w.Uid, true) end end, "+")
            end
        end
        for _, g in ipairs(st.GearInventory or {}) do
            if not eqG[g.Uid] and not inOffer[g.Uid] then
                order += 1
                ItemRow(bag, { Kind = "Gear", Item = g }, order, function() if not locked then hooks.Click(); Act("SetItem", "Gear", g.Uid, true) end end, "+")
            end
        end
        local function Side(x, title, side, mine)
            local f = New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(x, 8, 0, 0), Size = UDim2.new(0.33, -8, 1, -70), Parent = body })
            Header(f, title .. (side.Ready and "   •   READY" or "") .. (side.Confirm and "  ✓✓" or ""))
            local l = Scroll(f, UDim2.fromOffset(0, 28), UDim2.new(1, 0, 1, -28))
            for i, e in ipairs(side.Items) do
                ItemRow(l, e, i, mine and function() if not locked then hooks.Click(); Act("SetItem", e.Kind, e.Item.Uid, false) end end or nil, mine and "x" or nil)
            end
            if #side.Items == 0 then UIStyle.Text({ Text = "Nothing yet.", TextSize = 14, TextColor3 = C.Sub, Size = UDim2.new(1, 0, 0, 30), Parent = l }) end
        end
        Side(0.34, "YOUR WAGER (" .. #s.Me.Items .. "/" .. s.Max .. ")", s.Me, true)
        Side(0.67, string.upper(s.Them.Name) .. "'S WAGER", s.Them, false)
        local foot = New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -60), Size = UDim2.new(1, 0, 0, 60), Parent = body })
        UIStyle.Text({ Text = "Arena: " .. s.ArenaName .. ".  The winner takes both wagers. Wagered items leave your bag when the duel starts.", TextSize = 13,
            Font = UIStyle.BodyFont, TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(0.5, 0, 1, 0), Parent = foot })
        local ready = UIStyle.Button(foot, s.Me.Ready and "UNREADY" or "READY", s.Me.Ready and C.CardDark or C.Green, UDim2.fromOffset(150, 44), UDim2.new(0.5, 10, 0, 8))
        ready.Button.MouseButton1Click:Connect(function() hooks.Click(); Act("Ready", not s.Me.Ready) end)
        local cLabel = locked and ((s.ConfirmIn or 0) > 0.05 and string.format("CONFIRM (%d)", math.ceil(s.ConfirmIn)) or "CONFIRM") or "CONFIRM"
        local conf = UIStyle.Button(foot, cLabel, locked and ACCENT or C.CardDark, UDim2.fromOffset(150, 44), UDim2.new(0.5, 170, 0, 8))
        conf.Button.MouseButton1Click:Connect(function() hooks.Click(); Act("Confirm") end)
        local cancel = UIStyle.Button(foot, "CANCEL", C.Red, UDim2.fromOffset(120, 44), UDim2.new(1, -120, 0, 8))
        cancel.Button.MouseButton1Click:Connect(function() hooks.Click(); Act("Cancel") end)
    end

    local function Render()
        if not panel.Visible then return end
        if duel and (duel.Phase == "Wager" or duel.Phase == "Locked") then RenderWager() else RenderLobby() end
    end
    function api.Open()
        if InDuel() then return end
        hooks.OpenFrame(panel)
        Render()
    end
    api.Panel = panel

    -- ===== incoming challenge popup =====
    -- (UI CLEAN R-C: the duel HUD pieces on the run HUD plate (AimRngShared/RunHud) -- flat, square, no red strokes; the HUD's one
    -- accent is off-white (HUD_ACC); the duel's red stays on the world effects + the DUEL window only)
    local RunHud = require(script.Parent:WaitForChild("RunHud"))
    local HUD_ACC = C.Text
    local pop = New("Frame", { Name = "DuelRequest", Visible = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 92), Size = UDim2.fromOffset(440, 96),
        Parent = hudGui })
    RunHud.Plate(pop, RunHud.CARD_T)
    local popText = UIStyle.Text({ Text = "", TextSize = 15, TextWrapped = true, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 40), Parent = pop })
    RunHud.Role(popText, "Body")
    local pa = UIStyle.Button(pop, "ACCEPT", C.Accent, UDim2.fromOffset(130, 36), UDim2.fromOffset(12, 52))
    local pc = UIStyle.Button(pop, "COUNTER", C.Steel, UDim2.fromOffset(130, 36), UDim2.fromOffset(152, 52))
    local pd = UIStyle.Button(pop, "DECLINE", C.Steel, UDim2.fromOffset(130, 36), UDim2.fromOffset(292, 52))
    UIStyle.PhoneBoost(pop, 440, 96) -- (phones: a tappable challenge popup, not the HUD's 0.55)
    local popId = nil
    pa.Button.MouseButton1Click:Connect(function() hooks.Click(); pop.Visible = false; if popId then incoming[popId] = nil; Act("Respond", popId, true) end end)
    pc.Button.MouseButton1Click:Connect(function() hooks.Click(); pop.Visible = false; if popId then Counter(popId) end end)
    pd.Button.MouseButton1Click:Connect(function() hooks.Click(); pop.Visible = false; if popId then incoming[popId] = nil; Act("Respond", popId, false) end end)

    -- ===== the duel HUD =====
    local hud = New("ScreenGui", { Name = "PvpHud", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5, Enabled = false, Parent = LocalPlayer:WaitForChild("PlayerGui") })
    UIStyle.ScaleGui(hud) -- (Update 5: Interface Scale)
    local top = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(420, 64), Parent = hud })
    RunHud.Plate(top)
    local scoreL = UIStyle.Text({ Text = "", TextSize = 26, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 34), Parent = top })
    RunHud.Num(scoreL, 26)
    local clockL = UIStyle.Text({ Text = "", TextSize = 14, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 22), Parent = top })
    RunHud.Role(clockL, "Label"); clockL.TextSize = 13; clockL.FontFace = UIStyle.RoleFace("Label")
    local me = New("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.fromOffset(360, 70), BackgroundTransparency = 1, Parent = hud })
    local hpL = UIStyle.Text({ Text = "100", TextSize = 54, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.5, -16, 1, 0), Parent = me })
    local arL = UIStyle.Text({ Text = "100", TextSize = 54, Font = Enum.Font.GothamBlack, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0.5, 16, 0, 0), Size = UDim2.new(0.5, -16, 1, 0), Parent = me })
    RunHud.Num(hpL, 54, C.Text); RunHud.Num(arL, 54, C.Sub)
    hpL.TextStrokeTransparency = 0.7; arL.TextStrokeTransparency = 0.7 -- (no plate under the big numbers: a faint edge keeps them readable)
    local gunL = UIStyle.Text({ Text = "", TextSize = 13, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, 14),
        Size = UDim2.new(1, 0, 0, 16), Parent = me })
    UIStyle.Text({ Text = "HEALTH", TextSize = 11, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(0.5, -16, 0, 14), Parent = me })
    UIStyle.Text({ Text = PvpData.ARMOR > 0 and "ARMOUR" or "", TextSize = 11, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0.5, 16, 1, 0), Size = UDim2.new(0.5, -16, 0, 14), Parent = me })
    New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1, 40), BackgroundColor3 = HUD_ACC, BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = me })
    local opp = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 114), Size = UDim2.fromOffset(300, 52), Parent = hud })
    RunHud.Plate(opp)
    local oppName = UIStyle.Text({ Text = "", TextSize = 14, TextColor3 = HUD_ACC, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 18), Parent = opp })
    RunHud.Role(oppName, "SectionHead"); oppName.TextSize = 14
    local oppBar = New("Frame", { Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 6), BackgroundColor3 = C.Well, BorderSizePixel = 0, Parent = opp })
    local oppFill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Bad, BorderSizePixel = 0, Parent = oppBar })
    local oppArBar = New("Frame", { Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, 3), BackgroundColor3 = C.Well, BorderSizePixel = 0, Parent = opp })
    local oppArFill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Sub, BorderSizePixel = 0, Parent = oppArBar })
    local big = UIStyle.Text({ Text = "", TextSize = 72, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(900, 90), Parent = hud })
    local feed = UIStyle.Text({ Text = "", TextSize = 22, TextColor3 = HUD_ACC, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 178), Size = UDim2.fromOffset(700, 30), Parent = hud })
    local hurtV = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0, Parent = hud })
    -- YOUR HEALTH BAR (0.93, owner: "PVP should have a better indication for when youre getting hit, i think remove the red
    -- and make your hp more obvious"): a wide bar over the big number -- the fill drops at once, a white CHIP shows what the
    -- hit took and drains after a beat, the number punches and a -damage pops beside it. No red anywhere: amber when low.
    local HP_OK, HP_LOW, HP_OVER = C.Text, C.Warn, C.Info -- (UI CLEAN R-C: the main HUD's off-white bar; amber when low, never red)
    local hpBar = New("Frame", { Name = "MyHpBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -104), Size = UDim2.fromOffset(460, 8),
        BackgroundColor3 = C.Well, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = hud }) -- (UI CLEAN R-C: a flat 8 px bar, no ink stroke)
    local hpChip = New("Frame", { Name = "Chip", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = hpBar })
    local hpFill = New("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = HP_OK, BorderSizePixel = 0, Parent = hpBar })
    local hpPunch = New("UIScale", { Parent = hpL })
    local hpChipAt = 0 -- (the chip waits until this clock before it drains)
    -- results
    local res = New("Frame", { Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(620, 380), Parent = hud })
    RunHud.Plate(res, RunHud.CARD_T)
    do local e = UIStyle.Stroke(C.Text, 1); e.Transparency = 0.84; e.Name = "RunHudEdge"; e.Parent = res end
    local resTitle = UIStyle.Text({ Text = "", TextSize = 44, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 52), Parent = res })
    RunHud.Role(resTitle, "WindowTitle", { Keep = true }); resTitle.TextSize = 44
    local resBody = UIStyle.Text({ Text = "", TextSize = 17, TextWrapped = true, RichText = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.fromOffset(20, 78), Size = UDim2.new(1, -40, 1, -96), Parent = res })
    local forfeit = UIStyle.Button(hud, "FORFEIT", C.Steel, UDim2.fromOffset(110, 30), UDim2.new(1, -134, 1, -46))
    forfeit.Button.MouseButton1Click:Connect(function() hooks.Click(); Act("Forfeit") end)
    -- ABILITY slot (2026-10-15): right of your health, name + key, a fill that refills over the cooldown
    local abSlot = New("Frame", { Name = "AbilitySlot", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 244, 1, -28), Size = UDim2.fromOffset(132, 70), Parent = hud })
    RunHud.Plate(abSlot)
    local abStroke = New("UIStroke", { Name = "RunHudEdge", Color = HUD_ACC, Thickness = 1, Transparency = 0.5, Parent = abSlot })
    local abFill = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = HUD_ACC,
        BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = abSlot })
    local abName = UIStyle.Text({ Text = "", TextSize = 20, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 24), Parent = abSlot })
    local abState = UIStyle.Text({ Text = "", TextSize = 13, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 18), Parent = abSlot })

    local function OppPlayer(): any
        local id = LocalPlayer:GetAttribute("PvpOpp")
        if id == -1 then return Workspace:FindFirstChild("DuelBot") end
        return id and Players:GetPlayerByUserId(id)
    end
    local function OppModel(): Model?
        local o = OppPlayer()
        if not o then return nil end
        if o:IsA("Model") then return o end
        return o.Character
    end
    local function OppAttr(k: string): any
        local o = OppPlayer()
        return o and o:GetAttribute(k)
    end

    local feedToken = 0
    local function Feed(text: string, col: Color3?)
        feedToken += 1
        local t = feedToken
        feed.Text = text
        feed.TextColor3 = col or HUD_ACC
        task.delay(2.5, function() if feedToken == t then feed.Text = "" end end)
    end

    local function Refresh()
        local on = InDuel()
        hud.Enabled = on
        if hooks.SetMainHud then hooks.SetMainHud(not on) end
        if not on then res.Visible = false; big.Text = ""; return end
        local s = duel
        local mf = LocalPlayer:GetAttribute("PvpFrags") or 0
        local of = OppAttr("PvpFrags") or 0
        scoreL.Text = string.format("YOU  %d  —  %d  %s", mf, of, s and string.upper(s.Them.Name) or "")
        scoreL.TextColor3 = (mf > of) and C.Good or ((mf < of) and C.Bad or C.Text)
        local now = Workspace:GetServerTimeNow()
        if s and s.Phase == "Live" then
            if s.Sudden then clockL.Text = "SUDDEN DEATH: next frag wins"
            else
                local left = math.max(0, (s.EndsAt or now) - now)
                clockL.Text = string.format("%d:%02d  •  %s  •  first to %d", left // 60, left % 60, s.ModeName or "CLASSIC", s.Need or PvpData.FRAGS_TO_WIN)
            end
        elseif s and s.Phase == "Countdown" then
            clockL.Text = s.ArenaName or ""
        end
        local hp, ar = LocalPlayer:GetAttribute("PvpHP") or 0, LocalPlayer:GetAttribute("PvpArmor") or 0
        hpL.Text = tostring(math.ceil(hp))
        local low = hp <= PvpData.BASE_HEALTH * 0.3
        hpL.TextColor3 = low and HP_LOW or Color3.new(1, 1, 1) -- (0.93: amber, not red)
        local frac = math.clamp(hp / PvpData.BASE_HEALTH, 0, 1)
        hpFill.Size = UDim2.fromScale(frac, 1)
        hpFill.BackgroundColor3 = (hp > PvpData.BASE_HEALTH) and HP_OVER or (low and HP_LOW or HP_OK)
        if hpChip.Size.X.Scale < frac or os.clock() >= hpChipAt then hpChip.Size = UDim2.fromScale(frac, 1) end
        arL.Text = tostring(math.ceil(ar))
        arL.Visible = PvpData.ARMOR > 0 -- (0.77: no armour in duels)
        do
            local g = PvpData.GunStatsFor(MyMode(), LocalPlayer:GetAttribute("PvpGun"))
            gunL.Text = string.upper(g.Name) .. "  •  " .. (g.Instagib and "ONE HIT KILLS" or (string.format("%.0f", g.PerShot) .. " x " .. string.format("%.1f", g.Rate) .. "/s"))
        end
        oppName.Text = s and s.Them.Name or "?"
        oppFill.Size = UDim2.fromScale(math.clamp((OppAttr("PvpHP") or 0) / PvpData.MAX_HEALTH, 0, 1), 1)
        oppArFill.Size = UDim2.fromScale(math.clamp((OppAttr("PvpArmor") or 0) / math.max(1, PvpData.ARMOR), 0, 1), 1)
        oppArFill.Parent.Visible = PvpData.ARMOR > 0
        if s and s.Phase == "Countdown" then
            big.Text = tostring(math.max(1, math.ceil((s.LiveAt or now) - now)))
        elseif LocalPlayer:GetAttribute("PvpDead") then
            big.Text = "FRAGGED"
        elseif s and s.Phase == "Live" and big.Text ~= "FIGHT!" then
            big.Text = ""
        end
        forfeit.Button.Visible = s ~= nil and s.Phase ~= "Over"
        do -- (ABILITIES) the slot: READY [F] / seconds left / ACTIVE
            local ab = PvpData.AbilityOf(LocalPlayer:GetAttribute("PvpAbility"))
            local ready = LocalPlayer:GetAttribute("PvpAbilityReady") or 0
            local left = ready - now
            local active = (ab.Id == "Guard" and (LocalPlayer:GetAttribute("PvpGuardUntil") or 0) > now) or (ab.Id == "Pulse" and (LocalPlayer:GetAttribute("PvpPulseUntil") or 0) > now)
            abName.Text = ab.Name
            abFill.Size = UDim2.fromScale(1, (left > 0) and math.clamp(1 - left / ab.Cooldown, 0, 1) or 1)
            abState.Text = active and "ACTIVE" or ((left > 0) and string.format("%d", math.ceil(left)) or ("READY  [" .. (GameSettings.BindName("Ability") or "F") .. "]"))
            abState.TextColor3 = (active or left <= 0) and Color3.fromRGB(120, 255, 150) or C.Sub
            abStroke.Color = (left <= 0) and HUD_ACC or C.Line
            abSlot.Visible = s ~= nil and s.Phase ~= "Over"
        end
    end

    local function ShowResults(s: any)
        res.Visible = true
        big.Text = ""
        resTitle.Text = s.WinnerIsMe and "VICTORY" or (s.Winner and "DEFEAT" or "NO CONTEST")
        resTitle.TextColor3 = s.WinnerIsMe and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(255, 110, 110)
        local function Acc(side) return side.Shots > 0 and math.floor(side.Hits / side.Shots * 100 + 0.5) or 0 end
        local lines = {
            string.format("<b>%d  —  %d</b>   (%s)", s.Me.Frags, s.Them.Frags, tostring(s.Why or "")),
            string.format("YOU: %d%% accuracy, %d damage", Acc(s.Me), s.Me.Dealt),
            string.format("%s: %d%% accuracy, %d damage", s.Them.Name, Acc(s.Them), s.Them.Dealt),
        }
        if s.Wager then
            local won = {}
            for _, side in ipairs({ s.Me, s.Them }) do
                for _, e in ipairs(side.Items) do table.insert(won, ItemData.DisplayName(e.Item)) end
            end
            if #won > 0 then
                table.insert(lines, "")
                table.insert(lines, (s.WinnerIsMe and "<font color=\"#78FF8C\">YOU WIN: </font>" or (s.Winner and "<font color=\"#FF6E6E\">" .. s.Winner .. " TAKES: </font>" or "RETURNED: ")) .. table.concat(won, ", "))
            end
        end
        table.insert(lines, "")
        table.insert(lines, "Back to the city in a few seconds.")
        resBody.Text = table.concat(lines, "\n")
    end

    -- hide a fragged duelist until they respawn (their body vanishes in a burst)
    local hidden = {}
    local function SetHidden(model: Model?, on: boolean)
        if not model then return end
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = on and 1 or 0 end
        end
        hidden[model] = on or nil
    end
    local function Burst(pos: Vector3)
        local p = New("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one, Position = pos, Parent = Workspace })
        local e = New("ParticleEmitter", { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(ACCENT, Color3.new(1, 1, 1)),
            Size = NumberSequence.new(0.6, 0), Speed = NumberRange.new(12, 26), Lifetime = NumberRange.new(0.4, 0.8), SpreadAngle = Vector2.new(180, 180),
            LightEmission = 1, Rate = 0, Parent = p })
        e:Emit(60)
        game:GetService("Debris"):AddItem(p, 1.2)
    end

    Remotes.GetEvent("PvpUpdate").OnClientEvent:Connect(function(kind, data)
        if kind == "Request" then
            incoming[data.FromId] = { From = data.From, ArenaName = data.ArenaName, Wager = data.Wager, GunName = data.GunName, ModeName = data.ModeName, Until = os.clock() + (data.Life or 30) }
            popId = data.FromId
            popText.Text = data.From .. " challenges you to a " .. (data.ModeName or "CLASSIC") .. " DUEL in " .. data.ArenaName .. " with " .. (data.GunName or "RANDOM GUN") .. (data.Wager and ".  WAGER: the winner takes both sides' gear." or ".")
            pop.Visible = true
            hooks.Sound("Upgrade")
            task.delay(data.Life or 30, function() if popId == data.FromId then pop.Visible = false end end)
            Render()
        elseif kind == "GunPicked" then -- (0.77: the shared gun + how it was decided; DUELS v3: Gun Rotation's new rounds)
            hooks.Toast(tostring(data))
            if InDuel() and string.sub(tostring(data), 1, 6) == "ROUND " then Feed(tostring(data), Color3.fromRGB(255, 200, 60)) end
        elseif kind == "Pickup" then -- (DUELS v3 health pickups)
            hooks.Sound("Upgrade")
            Feed("+" .. tostring(data and data.Heal or "") .. " HEALTH" .. ((data and data.Mega) and "  (MEGA)" or ""), (data and data.Mega) and Color3.fromRGB(110, 190, 255) or Color3.fromRGB(120, 255, 150))
        elseif kind == "PickupOther" then
            if data and data.Mega then Feed("THEY TOOK THE MEGA HEALTH", Color3.fromRGB(110, 190, 255)) end
        elseif kind == "Declined" then
            hooks.Toast(tostring(data) .. " declined your duel.")
        elseif kind == "Closed" then
            duel = nil
            hooks.Toast(tostring(data))
            Render()
        elseif kind == "Duel" then
            local was = duel and duel.Phase
            duel = data
            if data.Phase == "Wager" or data.Phase == "Locked" then
                if not panel.Visible then hooks.OpenFrame(panel) end
                Render()
            elseif data.Phase == "Countdown" then
                if panel.Visible then hooks.CloseAll() end
                res.Visible = false
            elseif data.Phase == "Live" and was == "Countdown" then
                big.Text = "FIGHT!"
                hooks.Sound("Upgrade")
                task.delay(0.9, function() if big.Text == "FIGHT!" then big.Text = "" end end)
            elseif data.Phase == "Over" and was ~= "Over" then
                ShowResults(data)
                hooks.Sound(data.WinnerIsMe and "Victory" or "Upgrade")
            end
            if data.Sudden and was and not (duel and duel.SuddenSeen) then duel.SuddenSeen = true; Feed("SUDDEN DEATH", Color3.fromRGB(255, 200, 60)) end
            Refresh()
        elseif kind == "Hit" then
            if hooks.Hitmarker then hooks.Hitmarker() end
            if data and data.Head then hooks.Sound("HitCrit") end -- (0.77: a headshot sounds like one)
        elseif kind == "Hurt" then
            -- (0.78, owner: "Screen flashing red in pvp is annoying"): no full-screen flash -- the hit arc round the
            -- crosshair (pointing at the shooter) + the hurt sound, from hooks.Hurt
            if hooks.Hurt then hooks.Hurt(data.Dmg, data.From) end
            -- (0.93) the bar chip holds for a beat, the number punches, the damage pops beside it
            hpChipAt = os.clock() + 0.45
            task.delay(0.46, Refresh)
            hpPunch.Scale = 1.28
            TweenService:Create(hpPunch, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
            local n = tonumber(data and data.Dmg)
            if n and n > 0 then
                local pop = UIStyle.Text({ Text = "-" .. tostring(math.ceil(n)), TextSize = 30, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1),
                    AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, -250, 1, -100), Size = UDim2.fromOffset(120, 34), Parent = hud })
                TweenService:Create(pop, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, -250, 1, -140), TextTransparency = 1 }):Play()
                task.delay(0.75, function() pop:Destroy() end)
            end
            Refresh()
        elseif kind == "OppAbility" then -- (ABILITIES: what your opponent just used)
            local ab = PvpData.AbilityOf(data)
            Feed(ab.Id == "Pulse" and "THEY CAN SEE YOU THROUGH WALLS" or ("THEY USED " .. ab.Name), Color3.fromRGB(255, 200, 60))
        elseif kind == "Frag" then
            local mine = data.Killer == (LocalPlayer.DisplayName ~= "" and LocalPlayer.DisplayName or LocalPlayer.Name)
            Feed(mine and ("YOU FRAGGED " .. string.upper(data.Victim)) or (string.upper(data.Killer) .. " FRAGGED YOU"), mine and C.Good or C.Bad)
            if data.Pos then Burst(data.Pos) end
            hooks.Sound(mine and "Kill" or "PlayerHurt")
        elseif kind == "BotShot" then
            local a, b = data.From, data.To
            local beam = New("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Material = Enum.Material.Neon, Color = ACCENT,
                Size = Vector3.new(0.08, 0.08, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Parent = Workspace })
            game:GetService("Debris"):AddItem(beam, 0.04)
        end
    end)

    LocalPlayer:GetAttributeChangedSignal("PvpDuel"):Connect(function()
        if not InDuel() then duel = nil; for m in pairs(hidden) do SetHidden(m, false) end end
        if hooks.OnDuelChanged then hooks.OnDuelChanged(InDuel()) end
        Refresh()
    end)
    -- (DUELS v3) the health pickups turn + bob (client-only look; the server only reads where they are)
    RunService.RenderStepped:Connect(function()
        if not InDuel() then return end
        local arena = Workspace:FindFirstChild("PvpWorld")
        arena = arena and arena:FindFirstChild("PvpArena_" .. tostring(LocalPlayer:GetAttribute("PvpDuel")))
        local box = arena and arena:FindFirstChild("Pickups")
        if not box then return end
        local t = os.clock()
        for _, m in ipairs(box:GetChildren()) do
            if m:IsA("Model") and m:GetAttribute("Spin") then
                local base = m:GetAttribute("Base")
                if not base then base = m:GetPivot().Position; m:SetAttribute("Base", base) end
                m:PivotTo(CFrame.new(base + Vector3.new(0, math.sin(t * 2) * 0.25, 0)) * CFrame.Angles(0, t * 1.6, 0))
            end
        end
    end)
    -- the HUD numbers + hiding fragged bodies (10 Hz is plenty)
    task.spawn(function()
        while true do
            task.wait(0.1)
            if InDuel() then
                Refresh()
                local om = OppModel()
                local deadO = OppAttr("PvpDead") == true
                if om and (hidden[om] == true) ~= deadO then SetHidden(om, deadO) end
            end
        end
    end)

    -- ===== ABILITIES (2026-10-15) ===== (no sounds: owner "the noises are really bad. dont use those")
    local function Blink()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local v = root.AssemblyLinearVelocity
        local flat = Vector3.new(v.X, 0, v.Z)
        local dir = flat.Magnitude > 2 and flat.Unit or nil
        if not dir then
            local look = Workspace.CurrentCamera.CFrame.LookVector
            dir = Vector3.new(look.X, 0, look.Z)
            dir = dir.Magnitude > 0.01 and dir.Unit or root.CFrame.LookVector
        end
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        local skip = { char, Workspace.CurrentCamera }
        local om = OppModel()
        if om then table.insert(skip, om) end
        rp.FilterDescendantsInstances = skip
        local from = root.Position
        local dist = PvpData.BLINK_DIST
        for _, h in ipairs({ 0, 1.6, -1.6 }) do -- (waist, head and feet height: stop short of any wall)
            local hit = Workspace:Raycast(from + Vector3.new(0, h, 0), dir * PvpData.BLINK_DIST, rp)
            if hit then dist = math.min(dist, hit.Distance - 1.6) end
        end
        dist = math.max(0, dist)
        root.CFrame = root.CFrame + dir * dist
        root.AssemblyLinearVelocity = v
        -- a short streak where you were
        local trail = New("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Material = Enum.Material.Neon, Color = ACCENT,
            Transparency = 0.4, Size = Vector3.new(0.25, 0.25, math.max(0.5, dist)), CFrame = CFrame.lookAt(from + dir * dist / 2, from + dir * dist), Parent = Workspace })
        TweenService:Create(trail, TweenInfo.new(0.35), { Transparency = 1, Size = Vector3.new(0.05, 0.05, math.max(0.5, dist)) }):Play()
        task.delay(0.4, function() trail:Destroy() end)
    end
    local abilityBusy = false
    function api.UseAbility()
        if not InDuel() or not duel or duel.Phase ~= "Live" or abilityBusy then return end
        if LocalPlayer:GetAttribute("PvpDead") then return end
        local now = Workspace:GetServerTimeNow()
        if now < (LocalPlayer:GetAttribute("PvpAbilityReady") or 0) - 0.05 then Feed("ABILITY NOT READY", C.Sub); return end
        local ab = PvpData.AbilityOf(LocalPlayer:GetAttribute("PvpAbility"))
        if ab.Id == "Blink" then Blink() end -- (BLINK moves at once on your screen; the server only books the cooldown)
        abilityBusy = true
        task.spawn(function()
            local ok, okUse = pcall(function() return Remotes.GetFunction("PvpAction"):InvokeServer("UseAbility") end)
            abilityBusy = false
            if ok and okUse and ab.Id ~= "Blink" then
                Feed(ab.Id == "Guard" and "GUARD UP" or "PULSE: YOU SEE THEM", Color3.fromRGB(120, 255, 150))
            end
            Refresh()
        end)
    end
    pcall(function() require(script.Parent:WaitForChild("PlatformControls")).AbilityFn = api.UseAbility end) -- (touch SKILL button / DPad down)
    -- the looks: PULSE = your opponent outlined through walls (only you); their GUARD = a pale shield glow on them
    local abHL = Instance.new("Highlight")
    abHL.Name = "PvpAbilityHL"
    abHL.Enabled = false
    RunService.Heartbeat:Connect(function()
        if not InDuel() then
            if abHL.Enabled then abHL.Enabled = false end
            return
        end
        local now = Workspace:GetServerTimeNow()
        local om = OppModel()
        local pulse = (LocalPlayer:GetAttribute("PvpPulseUntil") or 0) > now
        local guard = (OppAttr("PvpGuardUntil") or 0) > now
        if om and (pulse or guard) and not OppAttr("PvpDead") then
            if abHL.Parent ~= om then abHL.Parent = om; abHL.Adornee = om end
            abHL.DepthMode = pulse and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            abHL.OutlineColor = pulse and ACCENT or Color3.fromRGB(150, 220, 255)
            abHL.FillColor = guard and Color3.fromRGB(150, 220, 255) or ACCENT
            abHL.FillTransparency = guard and 0.55 or 0.8
            abHL.OutlineTransparency = 0
            abHL.Enabled = true
        elseif abHL.Enabled then
            abHL.Enabled = false
        end
    end)

    -- ===== the duel gun (0.60: the picked gun goes in your hands for the duel; your own comes back after) =====
    local realWeapon, duelGun = nil, nil
    local function DuelGunId(): string return LocalPlayer:GetAttribute("PvpGun") or MyGun() end
    local function ApplyGun()
        local id = DuelGunId()
        if duelGun and duelGun.BaseId == id then return end
        local w = ItemData.GenerateWeaponOfBase and ItemData.GenerateWeaponOfBase(id, "Rare", 1)
        if type(w) ~= "table" then return end
        w.Uid = "__pvp"
        w.Procs, w.Proc, w.UniqueTrait, w.Trait, w.Exotic = nil, nil, nil, nil, nil
        local st = hooks.GetState()
        if type(st) ~= "table" then return end
        if not duelGun then realWeapon = st.EquippedWeapon end
        duelGun = w
        st.EquippedWeapon = w
        st.CurrentMag = w.MagSize or st.CurrentMag
        st.IsReloading = false
        if hooks.SetSlot then hooks.SetSlot("Gun") end
        if hooks.Rebuild then pcall(hooks.Rebuild, w) end
    end
    local function DropGun()
        if not duelGun then return end
        local st = hooks.GetState()
        duelGun = nil
        if type(st) == "table" and realWeapon then
            st.EquippedWeapon = realWeapon
            if hooks.Rebuild then pcall(hooks.Rebuild, realWeapon) end
        end
        realWeapon = nil
    end
    -- a state sync mid-duel: remember the real gun, keep the duel gun in hand
    function api.Reapply(newState: any): any
        if duelGun and type(newState) == "table" and InDuel() then
            realWeapon = newState.EquippedWeapon
            newState.EquippedWeapon = duelGun
            newState.CurrentMag = duelGun.MagSize or newState.CurrentMag
        end
        return newState
    end
    LocalPlayer:GetAttributeChangedSignal("PvpGun"):Connect(function() if InDuel() then ApplyGun() end end)
    LocalPlayer:GetAttributeChangedSignal("PvpDuel"):Connect(function()
        if InDuel() then task.defer(ApplyGun) else DropGun() end
    end)

    -- ===== the shot (AimRngClient FireWeapon / ExecuteRaycastShot): the duel gun's fire rate, every pellet tested
    -- against the arena + the opponent's body (the standard R6 limbs: what you see is what you hit) =====
    function api.Def(): any
        if not InDuel() then return nil end
        return { FireRate = PvpData.GunStatsFor(MyMode(), DuelGunId()).Rate }
    end
    function api.Shot(origin: Vector3, dir: Vector3): boolean
        if not InDuel() then return false end
        local s = duel
        if not s or s.Phase ~= "Live" or LocalPlayer:GetAttribute("PvpDead") then return true end
        local g = PvpData.GunStatsFor(MyMode(), DuelGunId())
        -- (DUELS v3: a shot fired in the air spreads -- jumping is a choice, not the default)
        local myHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local airborne = myHum ~= nil and myHum.FloorMaterial == Enum.Material.Air
        local arena = Workspace:FindFirstChild("PvpWorld")
        arena = arena and arena:FindFirstChild("PvpArena_" .. tostring(LocalPlayer:GetAttribute("PvpDuel")))
        local om = OppModel()
        local list = {}
        if arena and arena:FindFirstChild("Geo") then table.insert(list, arena.Geo) end
        local limbs = {}
        if om then
            for _, c in ipairs(om:GetChildren()) do
                if c:IsA("BasePart") and c.Name ~= "HumanoidRootPart" and c.Name ~= "PvpHitbox" then table.insert(list, c); limbs[c] = true end
            end
        end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = list
        local hits, heads, firstPos, endPos = 0, 0, nil, nil
        for k = 1, g.Pellets do
            local d = dir.Unit
            if g.Spread > 0 and k > 1 then
                d = (d + Vector3.new((math.random() - 0.5) * g.Spread, (math.random() - 0.5) * g.Spread, (math.random() - 0.5) * g.Spread)).Unit
            end
            if airborne then
                local a = PvpData.AIR_SPREAD
                d = (d + Vector3.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, (math.random() - 0.5) * a)).Unit
            end
            local r = Workspace:Raycast(origin, d * PvpData.RANGE, params)
            if r and limbs[r.Instance] then
                hits += 1
                if r.Instance.Name == "Head" then heads += 1 end -- (0.77: headshots deal PvpData.HEADSHOT_MULT)
                firstPos = firstPos or r.Position
            end
            endPos = endPos or (r and r.Position or origin + d * PvpData.RANGE)
        end
        Remotes.GetEvent("PvpShot"):FireServer(firstPos or endPos, hits, heads)
        if hits > 0 and hooks.LocalHit then hooks.LocalHit() end
        return true
    end

    return api
end

return PvpClient
