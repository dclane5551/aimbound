--!nocheck
-- Hub welcome guide (an infographic of the game) + patch notes, Rivals-style: the guide pops up when you load into
-- the hub (Settings > Interface > "Welcome Guide on Join"), and two small buttons in the top-left corner of the hub
-- reopen the guide and the patch notes (NEW badge until the latest notes are read -- GameSettings "SeenPatch").
-- AimRngClient builds it once (WelcomeGuide.Build) and decides when to show it.
local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local GameSettings = require(Shared:WaitForChild("GameSettings"))
local PatchNotes = require(Shared:WaitForChild("PatchNotes"))

local WelcomeGuide = {}
local LocalPlayer = Players.LocalPlayer
local C = UIStyle.Colors
local MenuKit = require(Shared:WaitForChild("MenuKit")) -- (UI CLEAN R-A: the target's cards + word tabs)
local ACCENT = UIStyle.Colors.Neon -- (UI v4 NEON: cyan; was Justice gold)

-- the game in eight cards (UPDATE THESE + CONTROLS WITH EVERY CONTENT UPDATE, along with PatchNotes)
local CARDS = {
    -- (rewritten 2026-10-03, owner: "they read very AI and dont really match" -- plain words, what you actually do)
    { Icon = "g_aim", Title = "AIM", Color = Color3.fromRGB(0, 200, 255),
        Text = "Floors are linked rooms across every biome: clear each room to open the way on, raid the side room's cache. Packs hold their rooms and learn how you play. Shoot a COMMANDING elite first; anything glowing LIME is worth shooting." },
    { Icon = "g_loot", Title = "LOOT", Color = Color3.fromRGB(255, 190, 60),
        Text = "5 rarities: Common, Uncommon, yellow RARE (your workhorse), red MYTHIC (Torment+) and RELICS (named, build-changing). AUTO-SELL (bag > SELL) can keep drops by sockets, links or stats. Guns have sockets for MODS (MENU > MODS): they drop, and the city's MOD SUPPLY stall sells plain ones." },
    { Icon = "g_build", Title = "BUILD", Color = Color3.fromRGB(90, 230, 120),
        Text = "Open the skill tree [{Tree}] and pick a class. Nodes give damage, defences and STR / DEX / INT, which guns, gear and mods need. CORNERSTONES change a rule. Levels and first clears of each difficulty give points." },
    { Icon = "g_survive", Title = "SURVIVE", Color = Color3.fromRGB(255, 80, 100),
        Text = "Moving cuts damage, never all of it: gunner volleys can't be dodged, big attacks can. Hit a marksman's head while it glints. PLATING cuts small Kinetic hits, RESISTS cut elements, AGILITY dodges attacks, WARD soaks. 3 lives a run." },
    { Icon = "g_team", Title = "TEAM UP", Color = Color3.fromRGB(170, 110, 255),
        Text = "Party up at the Dungeons gate (up to 4) or join one from any server in the PARTY FINDER. INVITE FRIENDS for BOUND points. Join a CREW. Trade [{Trade}] or sell on the EXCHANGE. Duel anyone [{Duel}]." },
    { Icon = "g_endgame", Title = "ENDGAME", Color = Color3.fromRGB(255, 140, 40),
        Text = (function() -- (LAUNCH CAP: the open difficulties + their top monster level)
            local ok, ID = pcall(function() return require(Shared:WaitForChild("ItemData")) end)
            local n, top = 14, 400
            if ok and ID.OpenDifficulties then
                local open = ID.OpenDifficulties()
                n = #open
                local r = ID.MONSTER_LEVEL and ID.MONSTER_LEVEL[open[#open]]
                top = r and r[2] or top
            end
            return n .. " difficulties to monster level " .. top .. ". Floor encounters, gun Zeroing, city quarters, the Gauntlet Run, Week's Quarry, Season Feats. Maps (level 100+, hideout device): maps drop from maps, completions, Sigil Marks, guardians, the Summit, a MAP TREE."
        end)() },
    { Icon = "g_move", Title = "MOVE", Color = Color3.fromRGB(120, 230, 255),
        Text = "Hold space to bhop, tap crouch to slide, {Dash} to dash, right click with your melee out to dash-strike. They build only a little speed: you top out a bit above a run, so aim beats outrunning.",
        TouchText = "Hold JUMP to bhop, tap SLIDE to slide, DASH to dash, AIM with your melee out to dash-strike. They build only a little speed: you top out a bit above a run, so aim beats outrunning." },
    { Icon = "g_style", Title = "STYLE", Color = Color3.fromRGB(255, 120, 200),
        Text = "Try any skin set in your own lit test range, wear it from Cosmetics [{Cosmetics}], recolour it with COLORWAYS. Build your own HIDEOUT [{Hideout}]: trophies, a weapon rack, jukebox and arcade, your own stash, forge and portal, prebuilt themes." },
}
-- (QOL2 H2 2026-10-28: the 3rd field = the GameSettings action(s) whose CURRENT key the chip shows -- rebinds follow; the 1st
-- field is only the fallback. Card text: "{Action}" = that action's key, e.g. "[{Tree}]" -> "[P]".)
local CONTROLS = {
    { "WASD", "move" }, { "LMB", "shoot", "Fire" }, { "RMB", "aim / melee dash", "Aim" }, { "R", "reload", "Reload" }, { "T", "inspect", "Inspect" },
    { "Q / 3", "melee", { "SwapWeapon", "SlotMelee" } }, { "V", "quick melee", "Melee" },
    { "SHIFT", "dash", "Dash" }, { "C", "slide / crouch", "Slide" }, { "SPACE", "bhop (hold)" },
    { "TAB", "inventory + stats", "Inventory" }, { "P", "skill tree", "Tree" }, { "H", "cosmetics", "Cosmetics" }, { "B", "store", "Store" },
    { "G", "teleport", "Teleport" }, { "Y", "trade", "Trade" }, { "K", "duel", "Duel" }, { "U", "hideout", "Hideout" },
    { "O / I", "dungeons / forge", { "Dungeons", "ForgeWin" } }, { "Z", "pick up all", "PickupAll" }, { "N", "minimap", "Map" },
    { "L", "menu (every window)", "Menu" }, { "M", "settings", "Settings" }, { "CAPS", "shift lock (hub)", "ShiftLock" },
}
-- the strip's short names (the Settings window keeps GameSettings.KeyLabel's)
local STRIP_SHORT = { LeftShift = "SHIFT", LeftControl = "CTRL", LeftAlt = "ALT" }
local function KeyCap(action: string): string?
    local b = GameSettings.BindName(action)
    if not b then return nil end
    return STRIP_SHORT[b] or string.upper(GameSettings.KeyLabel(b))
end
local function ChipKey(k: any): string
    local a = k[3]
    if type(a) == "string" then return KeyCap(a) or k[1] end
    if type(a) == "table" then
        local parts = {}
        for _, x in ipairs(a) do
            local c = KeyCap(x)
            if not c then return k[1] end
            table.insert(parts, c)
        end
        return table.concat(parts, " / ")
    end
    return k[1]
end
-- "{Tree}" -> the Tree action's key (unknown names stay as written)
local function FillKeys(text: string): string
    return (string.gsub(text, "{(%w+)}", function(a) return KeyCap(a) end))
end
-- the same strip for controllers and touch screens (picked by the device you're on; PlatformControls)
local CONTROLS_PAD = {
    { "L STICK", "move" }, { "R STICK", "look" }, { "R2", "shoot" }, { "L2", "aim" }, { "X", "reload" }, { "Y", "swap" },
    { "R3", "melee" }, { "DPAD UP", "inspect" }, { "LB", "dash" }, { "B", "slide / crouch" }, { "A", "bhop (hold)" }, { "RB", "pick up" }, { "DPAD LEFT", "pick up all" }, { "DPAD RIGHT", "minimap" }, { "START", "settings" },
}
local CONTROLS_TOUCH = {
    { "LEFT STICK", "move" }, { "DRAG RIGHT", "look" }, { "FIRE", "shoot (drag it to aim too)" }, { "AIM", "aim (melee: DASH-strike)" }, { "R", "reload" },
    { "DASH / SLIDE", "move fast" }, { "JUMP", "bhop (hold)" }, { "SWAP / MELEE", "weapons" }, { "TAP ITEM", "see its stats" },
}

function WelcomeGuide.LatestPatch(): number
    return PatchNotes[1] and PatchNotes[1].Id or 0
end

-- ctx: { Open = (Frame) -> (), Close = () -> (), Click = () -> (), Parent = HUD gui for the corner buttons }
function WelcomeGuide.Build(menuParent: Instance, ctx: any)
    local api = {}

    -- ===== the guide =====
    local guide = UIStyle.Panel(menuParent, { Name = "WelcomeGuide", Size = UDim2.fromOffset(1000, 690), Accent = ACCENT })
    UIStyle.TitleBar(guide, "WELCOME TO AIMBOUND", ACCENT, "fight through dungeons, grab loot, get better at aiming", function() ctx.Close() end)
    -- (2026-10-13 phones: the cards + the keys strip sit in one scrolling body -- on a phone the guide is only as tall as
    -- the screen (PhoneMinH) and the body scrolls; on desktop it holds them exactly, no scroll)
    guide:SetAttribute("PhoneMinH", 300)
    local gBody = UIStyle.New("ScrollingFrame", { Name = "GuideBody", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(18, 78),
        Size = UDim2.new(1, -36, 1, -182), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, Parent = guide })
    UIStyle.StyleScroll(gBody, 4)
    local grid = UIStyle.New("Frame", { Name = "Cards", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 372), Parent = gBody })
    UIStyle.New("UIGridLayout", { CellSize = UDim2.new(1 / 4, -9, 0, 180), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
    -- (0.61f, owner: "Text on guide is always yellow, just add proper contrast that matches every color theme"): the
    -- highlights follow the equipped UI theme's accent; on the default look each card uses its OWN colour (they were all
    -- gold); key caps pick ink or light text by brightness so they stay readable on any accent
    local themed = {} -- { obj, prop, base, kind } kind "fill" (key caps: also recolour their text)
    local keyed = {} -- (QOL2 H2) { label, template } card texts with {Action} keys
    local chipKeys = {} -- (QOL2 H2) { KeyText label, CONTROLS row } chips that show a bound key
    local function Reg(obj: Instance, prop: string, base: Color3, kind: string?)
        table.insert(themed, { obj, prop, base, kind });
        (obj :: any)[prop] = base
        return obj
    end
    for i, c in ipairs(CARDS) do
        -- (Mega-City briefing cards: a coloured rule, a case number, a condensed title -- no emoji, no rainbow borders)
        -- (UI CLEAN R-A: the target's raised card; ONE mark = the 2 px rule in the card's colour; number + icon quiet, the title in
        -- display caps Text, the text in Roblox body Sub)
        local card = MenuKit.Card(UIStyle.Card(grid, { Name = c.Title, LayoutOrder = i }), nil)
        local rule = UIStyle.New("Frame", { BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 2), Parent = card })
        Reg(rule, "BackgroundColor3", c.Color)
        rule:SetAttribute("Skinned", true)
        local num = UIStyle.Text({ Text = string.format("%02d", i), TextSize = 20, TextColor3 = C.Sub, Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(36, 30), Parent = card })
        num:SetAttribute("TypeRole", "Accent"); num:SetAttribute("TextRole", "Number"); num.FontFace = UIStyle.RoleFace("Accent")
        local tl = UIStyle.Text({ Text = string.upper(c.Title), TextSize = 20, TextColor3 = C.Text, Position = UDim2.fromOffset(48, 10), Size = UDim2.new(1, -96, 0, 34), Parent = card })
        UIStyle.TextRole(tl, "Title"); tl.FontFace = UIStyle.RoleFace("Label")
        -- (0.53: the card's Mega-City icon, top right -- UIStyle.Icons g_*)
        if UIStyle.Icons[c.Icon] then
            UIStyle.Icon(c.Icon, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(28, 28), ImageColor3 = C.Sub, Parent = card })
        end
        UIStyle.New("Frame", { BackgroundColor3 = C.Text, BackgroundTransparency = 0.88, BorderSizePixel = 0, Position = UDim2.fromOffset(14, 48), Size = UDim2.new(1, -28, 0, 1), Parent = card }):SetAttribute("Skinned", true)
        -- (touch screens: the card's own touch words, and no [KEY] hints -- the side buttons open those windows)
        local cardText = c.Text
        if GameSettings.TouchOnly() then cardText = c.TouchText or (string.gsub(c.Text, "%s*%[[^%]]+%]", "")) end
        local hasKeys = string.find(cardText, "{%w+}") ~= nil
        local cardLbl = UIStyle.Text({ Text = FillKeys(cardText), TextSize = 14, TextColor3 = C.Sub, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
            Position = UDim2.fromOffset(14, 58), Size = UDim2.new(1, -28, 1, -66), Parent = card })
        UIStyle.TextRole(cardLbl, "Label"); cardLbl.FontFace = UIStyle.RoleFace("Body")
        if hasKeys then table.insert(keyed, { cardLbl, cardText }) end
    end
    -- controls strip
    -- (owner 2026-10-03: "the keybinds overlap with the info when you load in") the key chips wrap to 3 rows now; the
    -- strip used to be 2 rows tall and centred, so the 3rd row spilled up over the cards. 3 rows tall, filled from the top.
    local strip = UIStyle.New("Frame", { Name = "Controls", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 380), Size = UDim2.new(1, 0, 0, 128), Parent = gBody })
    local stripLayout = UIStyle.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Top,
        HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Wraps = true, Parent = strip })
    local UIS = game:GetService("UserInputService")
    local controls = (not UIS.KeyboardEnabled and UIS.GamepadEnabled) and CONTROLS_PAD
        or GameSettings.TouchOnly() and CONTROLS_TOUCH or CONTROLS
    for i, k in ipairs(controls) do
        local chip = UIStyle.New("Frame", { BackgroundColor3 = C.Text, BackgroundTransparency = MenuKit.RAISE_T, BorderSizePixel = 0, Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i, Parent = strip }, {
            UIStyle.New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 10) }),
            UIStyle.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }),
        }) -- (UI CLEAN R-A: the raised surface, no box)
        chip:SetAttribute("Skinned", true)
        local key = UIStyle.New("Frame", { Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Parent = chip }, {
            UIStyle.Corner(2), UIStyle.New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
        })
        local keyText = UIStyle.Text({ Name = "KeyText", Text = (controls == CONTROLS) and ChipKey(k) or k[1], TextSize = 13, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), TextColor3 = C.Ink, Parent = key })
        if controls == CONTROLS and k[3] then table.insert(chipKeys, { keyText, k }) end
        Reg(key, "BackgroundColor3", ACCENT, "fill")
        UIStyle.Text({ Text = k[2], Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), LayoutOrder = 2, Parent = chip })
    end
    local function Paint()
        local okT, UIT = pcall(require, Shared:WaitForChild("UITheme"))
        local acc = okT and UIT.Accent and UIT.Accent() or nil
        for _, e in ipairs(themed) do
            local col = acc or e[3]
            if e[1].Parent then
                (e[1] :: any)[e[2]] = col
                if e[4] == "fill" then
                    local lum = 0.299 * col.R + 0.587 * col.G + 0.114 * col.B
                    local t = e[1]:FindFirstChild("KeyText")
                    if t then t.TextColor3 = (lum > 0.55) and C.Ink or Color3.new(1, 1, 1) end
                end
            end
        end
    end
    Paint()
    -- (QOL2 H2) a rebind redraws the chips + card keys (coalesced, once a frame at most; nothing runs otherwise). Long key
    -- names could push the strip past its 3 rows: then the chips sit closer (gap 8 -> 4).
    local keysQueued = false
    local function RefreshKeys()
        keysQueued = false
        for _, e in ipairs(chipKeys) do e[1].Text = ChipKey(e[2]) end
        for _, e in ipairs(keyed) do e[1].Text = FillKeys(e[2]) end
        task.defer(function()
            stripLayout.Padding = UDim.new(0, 8)
            task.defer(function()
                if stripLayout.AbsoluteContentSize.Y > strip.AbsoluteSize.Y + 1 then stripLayout.Padding = UDim.new(0, 4) end
            end)
        end)
    end
    api.RefreshKeys = RefreshKeys
    GameSettings.OnChanged("*", function(key)
        if keysQueued or type(key) ~= "string" or string.sub(key, 1, 4) ~= "Key_" then return end
        keysQueued = true
        task.defer(RefreshKeys)
    end)
    task.spawn(function()
        local okT, UIT = pcall(require, Shared:WaitForChild("UITheme"))
        if okT and UIT.OnChanged then UIT.OnChanged(function() Paint() end) end
    end)
    -- (UPDATE 4: the Low graphics setting -- a one-line tip between the keys and the buttons)
    local tip = UIStyle.Text({ Name = "LowTip", Text = "New here? PLAY TUTORIAL walks you through a run, the hub and your hideout.   Slower computer? Settings > Video > Graphics Quality: Low (phones get it on Auto)", Font = UIStyle.BodyFont, TextSize = UIStyle.Size.Caption,
        TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 18, 1, -94), Size = UDim2.new(1, -36, 0, 20), Parent = guide })
    tip:SetAttribute("TypeRole", "Body")
    -- bottom row: "show on join" toggle + go
    local showBtn = UIStyle.Button(guide, "", C.CardDark, UDim2.fromOffset(244, 46), UDim2.new(0, 18, 1, -64), "ShowOnJoin")
    local function RefreshShow()
        local on = GameSettings.Get("WelcomeOnJoin") ~= false
        showBtn.SetText((on and "■" or "□") .. "  SHOW WHEN I JOIN")
        showBtn.Label.TextSize = 15
    end
    RefreshShow()
    showBtn.Button.MouseButton1Click:Connect(function()
        ctx.Click()
        GameSettings.Set("WelcomeOnJoin", not (GameSettings.Get("WelcomeOnJoin") ~= false))
        RefreshShow()
    end)
    GameSettings.OnChanged("WelcomeOnJoin", RefreshShow)
    -- (Update 6 TUTORIAL: replay the guided first run -- the basics hall, the hub and your hideout)
    local tutorialBtn = UIStyle.Button(guide, "PLAY TUTORIAL", C.Steel, UDim2.fromOffset(190, 46), UDim2.new(1, -728, 1, -64), "Tutorial")
    tutorialBtn.Button.MouseButton1Click:Connect(function() ctx.Click(); if ctx.Tutorial then ctx.Tutorial() end end)
    local creditsFromGuide = UIStyle.Button(guide, "CREDITS", C.Steel, UDim2.fromOffset(150, 46), UDim2.new(1, -528, 1, -64), "Credits")
    local notesFromGuide = UIStyle.Button(guide, "PATCH NOTES", C.Steel, UDim2.fromOffset(160, 46), UDim2.new(1, -368, 1, -64), "Notes")
    local go = UIStyle.Button(guide, "LET'S GO", C.Gold, UDim2.fromOffset(180, 46), UDim2.new(1, -198, 1, -64), "Go")
    do -- (UI CLEAN R-A2: on desktop the top bar already has PATCH NOTES + CREDITS: the footer copies go; phones (no top bar) keep them)
        local function Foot()
            local phone = UIStyle.IsPhone()
            creditsFromGuide.Button.Visible = phone
            notesFromGuide.Button.Visible = phone
        end
        guide:GetPropertyChangedSignal("Visible"):Connect(function() if guide.Visible then Foot() end end)
        Foot()
    end
    go.Button.MouseButton1Click:Connect(function() ctx.Click(); ctx.Close() end)

    -- ===== patch notes =====
    local notes = UIStyle.Panel(menuParent, { Name = "PatchNotes", Size = UDim2.fromOffset(820, 640), Accent = C.Purple })
    UIStyle.TitleBar(notes, "PATCH NOTES", C.Purple, "what's new in Aimbound", function() ctx.Close() end)
    notes:SetAttribute("PhoneMinH", 300) -- (phones: as tall as the screen, the list scrolls)
    local list = UIStyle.New("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(18, 78), Size = UDim2.new(1, -36, 1, -96),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = C.Sub, ScrollBarImageTransparency = 0.5, Parent = notes })
    UIStyle.New("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
    UIStyle.New("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8), Parent = list })
    -- (optimization pass 2026-10-27: every patch's cards were ~3,200 UI objects built at join for a window most players
    -- open rarely; built the first time it opens)
    local notesBuilt = false
    local function BuildNotes()
        if notesBuilt then return end
        notesBuilt = true
        for i, p in ipairs(PatchNotes) do
            -- (UI CLEAN R-A: a patch = the target's raised card; title display caps (Title), the version line Meta, section heads
            -- SectionHead in Text, lines in Roblox body -- regular weight, not the old bold)
            local card = MenuKit.Card(UIStyle.Card(list, { Name = "Patch" .. p.Id, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, nil), nil)
            UIStyle.New("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), Parent = card })
            UIStyle.New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
            local function R(t, role) UIStyle.TextRole(t, role); t.FontFace = UIStyle.RoleFace(UIStyle.TEXT_ROLES[role].Face); t.TextStrokeTransparency = 1; return t end
            R(UIStyle.Text({ Text = string.upper(p.Title) .. (i == 1 and "   •  LATEST" or ""), TextSize = 20, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1, Parent = card }), "Title").TextSize = 24 -- (a long reading page: the patch title a step up, Oswald caps read small)
            R(UIStyle.Text({ Text = "v" .. p.Version .. "  •  " .. p.Date, TextSize = 13, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 2, Parent = card }), "Meta")
            local order = 3
            for _, sec in ipairs(p.Sections) do
                R(UIStyle.Text({ Text = string.upper(sec.Head), TextSize = 15, Size = UDim2.new(1, 0, 0, 34), TextYAlignment = Enum.TextYAlignment.Bottom, LayoutOrder = order, Parent = card }), "SectionHead").TextSize = 19 -- (19: Oswald caps at 17 read the same size as the 14 px body under them)
                order += 1
                for _, line in ipairs(sec.Lines) do
                    R(UIStyle.Text({ Text = "•  " .. line, TextSize = 14, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = card }), "Body")
                    order += 1
                end
            end
        end
    end

    -- ===== credits (UPDATE 4 wrap-up, required before publishing: the CC BY models must be credited in game) =====
    -- AimRngShared/Credits = the data. One tab per group; a group page = what the licence is, what we changed (CC BY asks
    -- for both), then a two-column wall of cards: what it is in the game, "title" by author, the source as text (Roblox
    -- can't open links), the licence tag. Reached from the hub corner, the guide and Settings > Interface > Credits.
    local Credits = require(Shared:WaitForChild("Credits"))
    local CREDIT_ACCENT = C.Info
    local credits = UIStyle.Panel(menuParent, { Name = "Credits", Size = UDim2.fromOffset(920, 660), Accent = CREDIT_ACCENT })
    UIStyle.TitleBar(credits, "CREDITS", CREDIT_ACCENT, "the artists whose work is in Aimbound", function() ctx.Close() end)
    credits:SetAttribute("PhoneMinH", 300) -- (phones: as tall as the screen, the page scrolls)
    local cBody = UIStyle.New("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 76), Size = UDim2.new(1, -36, 1, -92), Parent = credits })
    local intro = UIStyle.Text({ Name = "Intro", Text = Credits.Intro, Font = UIStyle.BodyFont, TextSize = UIStyle.Size.Body, TextColor3 = C.Sub, TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 22), Parent = cBody })
    intro:SetAttribute("TypeRole", "Body")
    local page = UIStyle.New("ScrollingFrame", { Name = "Page", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 1, -74),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = cBody })
    UIStyle.StyleScroll(page, 6)
    UIStyle.New("UIListLayout", { Padding = UDim.new(0, UIStyle.Space.M), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
    UIStyle.New("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8), Parent = page })
    local function Line(parent: Instance, text: string, size: number, color: Color3, order: number, role: string?)
        local t = UIStyle.Text({ Text = text, Font = UIStyle.BodyFont, TextSize = size, TextColor3 = color, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = parent })
        t:SetAttribute("TypeRole", role or "Body")
        return t
    end
    local function LicenceTag(parent: Instance, text: string)
        local tag = UIStyle.New("TextLabel", { Name = "Licence", BackgroundColor3 = C.Bg2, BorderSizePixel = 0, Text = text, TextColor3 = C.Sub, TextSize = 12,
            Font = UIStyle.Font, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10),
            Parent = parent }, { UIStyle.Corner(2), UIStyle.New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }) })
        tag:SetAttribute("TypeRole", "Label")
        tag:SetAttribute("Skinned", true)
        return tag
    end
    local function ShowGroup(id: string)
        for _, ch in ipairs(page:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
        local g = nil
        for _, x in ipairs(Credits.Groups) do if x.Id == id then g = x end end
        if not g then return end
        local lic = Credits.Licences[g.Licence] or Credits.Licences.CCBY
        -- the group's header: the licence + what we changed + (CC BY) no endorsement
        local head = MenuKit.Card(UIStyle.Card(page, { Name = "Head", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, nil), nil) -- (UI CLEAN R-A)
        UIStyle.New("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = head })
        UIStyle.New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = head })
        local n = #g.Items
        UIStyle.SectionHeader(head, g.Head .. ((n > 0) and ("  •  " .. n) or ""), { LayoutOrder = 1 })
        Line(head, "Licence: " .. lic.Name .. " (" .. lic.Short .. ")  •  " .. lic.Link, UIStyle.Size.Label, C.Text, 2)
        if g.Changed then Line(head, g.Changed, UIStyle.Size.Label, C.Sub, 3) end
        if g.Licence == "CCBY" then Line(head, Credits.NoEndorse, UIStyle.Size.Caption, C.Muted, 4) end
        -- the wall of cards
        if n > 0 then
            local grid = UIStyle.New("Frame", { Name = "Items", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = page })
            UIStyle.New("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 104), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
            for i, it in ipairs(g.Items) do
                local card = MenuKit.Card(UIStyle.Card(grid, { Name = "Item" .. i, LayoutOrder = i }), nil)
                local use = UIStyle.Text({ Name = "Use", Text = string.upper(it.Use), TextSize = UIStyle.Size.Subhead, TextColor3 = C.Text, TextTruncate = Enum.TextTruncate.AtEnd,
                    Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -110, 0, 24), Parent = card })
                use:SetAttribute("TypeRole", "Header")
                LicenceTag(card, lic.Short)
                local by = UIStyle.Text({ Name = "By", Text = "\"" .. it.Title .. "\"  by  " .. it.Author, Font = UIStyle.BodyFont, TextSize = UIStyle.Size.Label, TextColor3 = C.Text,
                    TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -28, 0, 34), Parent = card })
                by:SetAttribute("TypeRole", "Body")
                local src = UIStyle.Text({ Name = "Source", Text = it.Link .. (it.Note and ("\n" .. it.Note) or ""), Font = UIStyle.BodyFont, TextSize = UIStyle.Size.Caption,
                    TextColor3 = C.Sub, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(14, 68),
                    Size = UDim2.new(1, -28, 0, 32), Parent = card })
                src:SetAttribute("TypeRole", "Body")
            end
        end
        -- thanks (CC0 / public domain / our own: credited as a courtesy)
        for i, th in ipairs(g.Thanks or {}) do
            local card = MenuKit.Card(UIStyle.Card(page, { Name = "Thanks" .. i, LayoutOrder = 10 + i, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }), nil)
            UIStyle.New("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = card })
            UIStyle.New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
            UIStyle.SectionHeader(card, th.Head, { LayoutOrder = 1 })
            Line(card, th.Text, UIStyle.Size.Label, C.Text, 2)
        end
        page.CanvasPosition = Vector2.new()
    end
    local tabs = {}
    for _, g in ipairs(Credits.Groups) do table.insert(tabs, { Id = g.Id, Text = g.Title }) end
    local tabBar = UIStyle.TabBar(cBody, tabs, ShowGroup, { Position = UDim2.fromOffset(0, 30), Height = 34, Accent = C.Accent })
    tabBar.Select(Credits.Groups[1].Id)
    ShowGroup(Credits.Groups[1].Id)

    -- ===== corner buttons (hub only) =====
    -- (parented to the HUD itself, not the menus folder: opening any window hides every frame in that folder, which
    -- made these buttons vanish until you left and re-entered the hub)
    local cornerParent = (ctx.Parent and ctx.Parent:IsA("Folder") and ctx.Parent.Parent) or ctx.Parent
    local corner = UIStyle.New("Frame", { Name = "GuideButtons", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 72), Size = UDim2.fromOffset(330, 58), Parent = cornerParent })
    corner:SetAttribute("NoSkin", true)
    task.defer(function() UIStyle.BelowTopBar(corner, 72) end) -- (phones: not under the Roblox top bar's buttons)
    UIStyle.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = corner }) -- (in order: GUIDE, PATCH NOTES, CREDITS)
    local function CornerButton(name: string, icon: string, label: string, color: Color3)
        -- (Mega-City: a gunmetal slab, its colour as a top edge, the glyph tinted to match)
        -- (0.60f icon look: a faceted slab with an ink edge, the glyph in the colour)
        local b = UIStyle.New("TextButton", { Name = name, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(100, 52), Parent = corner })
        -- (UI v4 NEON: a dark slab with a hairline and a 2 px colour edge; hover = the halo + the edge lighting up)
        -- (UI CLEAN R-A2: the HUD plate -- flat slate at 0.45, no facet / stroke / colour edge; glyph + word in the text colours,
        -- hover = a brighter plate + a 2 px off-white line along the bottom)
        b.BackgroundColor3 = C.Bg0; b.BackgroundTransparency = 0.45
        local line = UIStyle.New("Frame", { BackgroundColor3 = C.Text, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), Visible = false, Parent = b })
        b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.25; line.Visible = true end)
        b.MouseLeave:Connect(function() b.BackgroundTransparency = 0.45; line.Visible = false end)
        if UIStyle.Icons[icon] then
            UIStyle.Icon(icon, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(22, 22), ImageColor3 = C.Text, Parent = b })
        else
            UIStyle.Text({ Text = icon, TextSize = 22, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 28), Parent = b })
        end
        local lbl = UIStyle.Text({ Text = label, TextSize = 13, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 29), Size = UDim2.new(1, 0, 0, 18), Parent = b })
        lbl.FontFace = UIStyle.RoleFace("Label"); lbl.TextStrokeTransparency = 1; lbl:SetAttribute("NoSnap", true)
        return b
    end
    local guideBtn = CornerButton("Guide", "guide", "GUIDE", ACCENT)
    local notesBtn = CornerButton("Notes", "notes", "PATCH NOTES", C.Purple)
    local creditsBtn = CornerButton("Credits", "credits", "CREDITS", CREDIT_ACCENT)
    guideBtn.LayoutOrder, notesBtn.LayoutOrder, creditsBtn.LayoutOrder = 1, 2, 3
    -- (UI CLEAN R-A2: NEW = a small off-white dot in the corner, like the MENU button's, not a red slab)
    local newBadge = UIStyle.New("Frame", { Name = "New", BackgroundColor3 = C.Text, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6),
        Size = UDim2.fromOffset(7, 7), ZIndex = 3, Parent = notesBtn })
    local function RefreshBadge()
        newBadge.Visible = (tonumber(GameSettings.Get("SeenPatch")) or 0) < WelcomeGuide.LatestPatch()
    end
    GameSettings.OnChanged("SeenPatch", RefreshBadge)
    RefreshBadge()

    local function OpenNotes()
        BuildNotes()
        ctx.Open(notes)
        if (tonumber(GameSettings.Get("SeenPatch")) or 0) < WelcomeGuide.LatestPatch() then GameSettings.Set("SeenPatch", WelcomeGuide.LatestPatch()) end
    end
    guideBtn.MouseButton1Click:Connect(function() ctx.Click(); ctx.Open(guide) end)
    notesBtn.MouseButton1Click:Connect(function() ctx.Click(); OpenNotes() end)
    notesFromGuide.Button.MouseButton1Click:Connect(function() ctx.Click(); OpenNotes() end)
    local function OpenCredits() ctx.Open(credits) end
    creditsBtn.MouseButton1Click:Connect(function() ctx.Click(); OpenCredits() end)
    creditsFromGuide.Button.MouseButton1Click:Connect(function() ctx.Click(); OpenCredits() end)

    -- the corner buttons only show in the hub hall (third person) and not over the creator
    -- (and never over an open window: they sat on top of every window's title)
    -- (0.60f fix, owner: "The patch notes and guide are now gone": ctx.Parent is the HUD ScreenGui, so this scanned the
    -- health bar / dock / currencies -- always visible -- and hid the buttons for good. Scan the windows folder.)
    local function AnyWindow(): boolean
        local folder = menuParent
        if not folder then return false end
        for _, c in ipairs(folder:GetChildren()) do if c:IsA("GuiObject") and c.Visible then return true end end
        return false
    end
    local function RefreshCorner()
        local want = LocalPlayer:GetAttribute("ThirdPerson") == true and not LocalPlayer:GetAttribute("CreatorOpen") and not AnyWindow()
        if corner.Visible ~= want then corner.Visible = want end
    end
    LocalPlayer:GetAttributeChangedSignal("ThirdPerson"):Connect(RefreshCorner)
    LocalPlayer:GetAttributeChangedSignal("CreatorOpen"):Connect(RefreshCorner)
    RefreshCorner()
    task.spawn(function() while corner.Parent do task.wait(0.2) RefreshCorner() end end)

    api.Guide = guide
    api.Notes = notes
    api.OpenGuide = function() ctx.Open(guide) end
    api.OpenNotes = OpenNotes
    api.Credits = credits
    api.OpenCredits = OpenCredits
    return api
end

return WelcomeGuide
