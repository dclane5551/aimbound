--!nocheck
-- THE STORE / COSMETICS WINDOW v2 (client). Owner (2026-10-02): "the cosmetics shop is a little overwhelming right now,
-- and still has no previews. Make sure everything can be inspected in both third and first person".
--   STORE      = only what Robux buys (FEATURED opens on the bundle hero), COSMETICS = the whole collection + equip.
--   Layout: categories (left) | a clean grid of cards -- live preview, name, price / status (middle) | the DETAIL panel
--   (right): a big live preview you can drag to turn (and scroll to zoom), the full description, bundle contents with
--   their worth, the main action (BUY / EQUIP / TAKE OFF / how to unlock) and the inspect buttons:
--     TRY IN FIRST PERSON  -- the item on you, in your own view, with a target dummy (guns, melees, gloves, sleeves,
--                             UI themes); VIEW ON CHARACTER -- third-person showcase (bundles, gloves, guns)
--   (hooks.TryOn(entry, "FP" | "TP") -> TryOn module in the client.)
--   local m = CosmeticsMenu.Build(menuFolder, { GetState, PlayClick, OnClose, Toast, OnEquipped(cat, id), TryOn })
--   m.Open("Shop" | "Locker", categoryId?, itemId?)  m.Refresh()  m.Frame
-- v3 (0.93, owner: "the cosmetics menu and store feel incredibly cluttered and unintuitive" -> picked "bundles-first +
-- loadout"): STORE = a chip row (HOME / GUN SKINS / MELEE / GLOVES / SLEEVES / HEALTH BARS / UI THEMES / HIDEOUT) instead
-- of a 13-row sidebar; HOME = the featured bundle carousel (< >) + bundle cards (flat art, no 3D: 24 viewports were heavy);
-- a bundle card opens the BUNDLE VIEW (its pieces as cards, each inspected / bought on the right, back to all bundles).
-- MY COSMETICS = loadout SLOTS on the left (each shows what you wear), the grid shows only what you own (SHOW ALL toggle).
local RunService = game:GetService("RunService")

local Shared = script.Parent
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local CosmeticPreview = require(Shared:WaitForChild("CosmeticPreview"))
local BarStyles = require(Shared:WaitForChild("BarStyles"))
local EnemyBars = require(Shared:WaitForChild("EnemyBars"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Colorways = require(Shared:WaitForChild("Colorways")) -- (0.97 BOUND SHOP: the BOUND points packs)
local ItemData = require(Shared:WaitForChild("ItemData"))
local CosmeticArt = require(Shared:WaitForChild("CosmeticArt"))
local StoreIcons = require(Shared:WaitForChild("StoreIcons")) -- (2026-10-14 store pilot: pre-rendered art where it exists)

local CosmeticsMenu = {}
local S = UIStyle.Colors
local New, Text = UIStyle.New, UIStyle.Text
local IS_STUDIO = RunService:IsStudio()

local MODE_COL = { Shop = Color3.fromRGB(255, 70, 190), Locker = Color3.fromRGB(48, 226, 255) } -- (UI v4 NEON: the store wears the magenta line, your cosmetics the cyan)
-- which categories can be tried on, and how
local TRY_FP = { WeaponSkin = true, MeleeSkin = true, Glove = true, Sleeve = true, Arms = true, HudTheme = true, Bundle = true }
local TRY_TP = { Bundle = true, Glove = true, Arms = true, WeaponSkin = true }

local function RarCol(r) return Cosmetics.RarityColor[r] or S.Sub end

-- health bar demo: keeps taking hits, dies, refills
local function BarDemo(bar)
    local d = { Bar = bar, St = { Shown = 1, Chip = 1, Target = 1, LastHit = -99, Flash = 0, Kick = 0 }, Hp = 1, NextHit = os.clock() + math.random(), DeadUntil = 0 }
    function d.Step(now, dt)
        if now >= d.NextHit then
            if d.Hp <= 0 then
                if now >= d.DeadUntil then d.Hp = 1; d.St.Chip = 1 end
            else
                d.Hp = math.max(0, d.Hp - (0.06 + math.random() * 0.12))
                if d.Hp <= 0 then d.DeadUntil = now + 0.8 end
            end
            d.NextHit = now + 0.3 + math.random() * 0.45
        end
        EnemyBars.StepDrain(d.St, d.Hp, dt, now)
        d.Bar.Scale.Scale = 1 + d.St.Kick * 0.5
        BarStyles.Paint(d.Bar, d.St.Shown, d.St.Chip, d.St.Flash, 1, now, dt, false)
    end
    return d
end

-- the live preview for an entry inside a frame -> { Step = fn(now, dt) } or nil. big = the detail panel (drag to turn)
local function Preview(pv, e, st, big)
    local catDef = Cosmetics.CategoryById[e.Cat]
    -- (Update 6 SHOP SHOWCASE, owner: "Every cosmetic should have a full preview ... a short 3 second video or so"): the big
    -- detail preview plays a ~3.4 s live loop (fire burst / swing / glove effects / kill + banner / theme open); cards keep
    -- their small still previews (one live showcase at a time)
    if big then
        local okS, ShopShowcase = pcall(require, Shared:WaitForChild("ShopShowcase"))
        local okR, show = false, nil
        if okS then okR, show = pcall(ShopShowcase.For, pv, e, st) end
        if okR and show then return show end
        for _, c in ipairs(pv:GetChildren()) do if c:IsA("ViewportFrame") or c.Name == "ShowcaseBanner" or c.Name == "UITPreview" then c:Destroy() end end
    end
    local kind = catDef and catDef.Preview or "Icon"
    local opts = big and { Drag = true } or nil
    local cardFit = (kind == "Melee" or kind == "Gun" or kind == "Glove" or kind == "Arms") -- (0.97 STORE ICONS v2: cards and the big detail view)
    if kind == "Bar" then
        local bar = BarStyles.MakeBar(pv, big and 220 or 120, big and 16 or 11, e.Src, Color3.fromRGB(235, 60, 60), false)
        bar.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
        bar.Holder.Position = UDim2.fromScale(0.5, 0.56)
        return BarDemo(bar)
    elseif kind == "Avatar" then
        local look = Cosmetics.Look(st)
        look[e.Cat] = e.Id
        local vp = CosmeticPreview.Viewport(pv, CosmeticPreview.Avatar(look), CosmeticPreview.Focus[catDef.Focus or e.Cat], opts)
        return { Step = function(now) vp.Step(now) end }
    elseif kind == "Hud" then
        require(Shared:WaitForChild("UITheme")).Preview(pv, e.Src)
        return nil
    elseif kind == "Armor" or kind == "Bundle" then
        local defs, extras = {}, nil
        local ArmorFX = require(Shared:WaitForChild("ArmorFX"))
        if kind == "Armor" then
            defs = { e.Src }
        else
            -- the full set: armor on the figure, its gloves on the hands, its guns beside it
            extras = { Guns = {} }
            for _, ref in ipairs(e.Contents or {}) do
                local cat, id = ref:match("^(.-):(.*)$")
                if cat == "Armor" and ArmorFX.PieceById[id] then table.insert(defs, ArmorFX.PieceById[id]) end
                local ce = Cosmetics.Find(cat, id)
                if ce and cat == "Glove" then extras.Glove = ce.Src end
                if ce and cat == "Sleeve" then extras.Sleeve = ce.Src end
                if ce and cat == "Arms" then extras.Glove, extras.Sleeve = ce.Src.Glove, ce.Src.Sleeve end -- (0.97 ARMS)
                if ce and cat == "WeaponSkin" then table.insert(extras.Guns, { Gun = ce.Gun, Skin = ce.Src }) end
            end
        end
        -- a bundle shows on YOUR avatar (own Roblox avatars since 2026-10-02); armor keeps the mannequin
        local model = (kind == "Bundle") and CosmeticPreview.Bundle(extras, Cosmetics.Look(st)) or CosmeticPreview.Armor(defs, Cosmetics.Look(st), extras)
        if not model then return nil end
        local focus = CosmeticPreview.Focus[(kind == "Armor") and ("Armor_" .. tostring(e.Slot)) or "Armor_Set"]
        local o = opts or {}
        o.Yaw = (kind == "Armor" and e.Slot == "Back") and math.pi or 0.5 -- (wings: from behind)
        local vp = CosmeticPreview.Viewport(pv, model, focus, o)
        return { Step = function(now) vp.Step(now) end }
    elseif kind == "Melee" or kind == "Gun" or kind == "Glove" or kind == "Arms" or kind == "Grapple" then
        local model
        if kind == "Grapple" then model = CosmeticPreview.Grapple(e.Src)
        elseif kind == "Glove" then model = CosmeticPreview.Glove(e.Src, e.IsSleeve)
        elseif kind == "Arms" then model = CosmeticPreview.Arms(e.Src.Glove, e.Src.Sleeve)
        elseif kind == "Gun" then model = CosmeticPreview.Gun(e.Gun, e.Src)
        else model = CosmeticPreview.Melee(st.EquippedKnife or "Knife", e.Id) end
        if model then
            local o = opts or {}
            o.Spin = (kind == "Grapple") and nil or "full" -- (a rope reads best side-on, swaying)
            if cardFit then
                o.Fit = big and 0.82 or ((kind == "Gun") and 0.9 or 0.78)
                o.BaseYaw = (kind == "Glove" or kind == "Arms") and 0.9 or 0.32
                o.Sway = big and 0.35 or 0.16
            end
            local vp = CosmeticPreview.Viewport(pv, model, nil, o)
            return { Step = function(now) vp.Step(now) end }
        end
        return nil
    end
    if e.Image then
        New("ImageLabel", { BackgroundTransparency = 1, Image = e.Image, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromScale(0.75, 0.8), Parent = pv })
    elseif e.Color then
        New("Frame", { BackgroundColor3 = e.Color, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(big and 120 or 72, big and 120 or 72), Parent = pv },
            { New("UICorner", { CornerRadius = UDim.new(1, 0) }), UIStyle.Stroke(Color3.new(1, 1, 1), 3) })
    elseif catDef and UIStyle.HasIcon(catDef.IconKey) then -- (0.61f: the category's custom icon, not a Roblox emoji)
        UIStyle.Icon(catDef.IconKey, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(big and 110 or 64, big and 110 or 64), ImageColor3 = catDef.Color, Parent = pv })
    else
        Text({ Size = UDim2.fromScale(1, 1), TextSize = big and 80 or 56, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, Text = "?", Parent = pv })
    end
    return nil
end

-- the total store price of a bundle's contents (what it's worth bought one by one)
local function BundleWorth(e)
    local sum = 0
    for _, ref in ipairs(e.Contents or {}) do
        local cat, id = ref:match("^(.-):(.*)$")
        local ce = Cosmetics.Find(cat, id)
        if ce then sum += Cosmetics.BPPrice(ce) or 0 end -- (0.97: BOUND points)
    end
    return sum
end

function CosmeticsMenu.Build(parent, hooks)
    hooks = hooks or {}
    local click = hooks.PlayClick or function() end
    local function State() return hooks.GetState and hooks.GetState() or {} end

    local panel = UIStyle.Panel(parent, { Name = "CosmeticsWindow", Size = UDim2.fromOffset(1220, 720), Accent = MODE_COL.Shop })
    local scale = New("UIScale", { Name = "FitScale", Parent = panel })
    -- (2026-10-13 phones: a 980 wide phone arrangement -- ~0.84x instead of 0.64x -- see PHONE below; the grid and the
    -- detail text scroll on their own, so the window is about as tall as the screen)
    panel:SetAttribute("PhoneMinH", 420)
    local _, subtitle = UIStyle.TitleBar(panel, "STORE", Color3.fromRGB(255, 120, 200), "Premium looks, bought with BOUND points.", function()
        click()
        if hooks.OnClose then hooks.OnClose() else panel.Visible = false end
    end)
    -- fit smaller screens (phones / tablets): scale the whole window down to the viewport
    local PHONE_W = 980
    local function Fit()
        -- (phones: the narrower phone arrangement; the HUD's interface scale multiplies in)
        local w = UIStyle.IsPhone() and PHONE_W or 1220
        if panel.Size.X.Offset ~= w then panel.Size = UDim2.fromOffset(w, panel.Size.Y.Offset) end
        UIStyle.Fit(panel, scale, w, 720, 24)
    end
    Fit()
    if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Fit) end

    local mode, category, selected = "Shop", "Home", nil
    local openBundle = nil -- (store BUNDLE VIEW: the bundle whose pieces fill the grid)
    local heroIndex = 1
    local lockerAll = false -- (MY COSMETICS: false = only what you own)
    -- the store's chips: category ids (HIDEOUT merges the three hideout categories)
    local SHOP_CHIPS = {
        { Id = "Home", Label = "HOME", Color = Color3.fromRGB(255, 200, 60) },
        { Id = "WeaponSkin", Label = "GUN SKINS" }, { Id = "MeleeSkin", Label = "MELEE" }, { Id = "Arms", Label = "ARMS" }, -- (0.97: gloves + sleeves = ARMS)
        { Id = "HealthBar", Label = "HEALTH BARS" }, { Id = "HudTheme", Label = "UI THEMES" }, { Id = "KillEffect", Label = "KILL EFFECTS" }, -- (2026-10-14 owner)
        { Id = "Hideout", Label = "HIDEOUT", Cats = { "HideoutTheme", "HideoutStash", "HideoutPortal" }, Color = Color3.fromRGB(255, 150, 90) },
    }
    local CHIP_OF_CAT = { HideoutTheme = "Hideout", HideoutStash = "Hideout", HideoutPortal = "Hideout" }
    local live = {} -- previews to animate: { Step = fn(now, dt) }
    local detailLive = nil

    -- ===== mode tabs + collection counter =====
    local tabs = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -32, 0, 44), Position = UDim2.fromOffset(16, 74), Parent = panel }, {
        New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
    })
    local shopTab = UIStyle.Button(tabs, "STORE", S.Bg1, UDim2.fromOffset(120, 42), nil, "ShopTab")
    local lockTab = UIStyle.Button(tabs, "MY COSMETICS", S.Bg1, UDim2.fromOffset(160, 42), nil, "LockerTab")
    do -- (UI CLEAN R-A, AimRngShared/MenuKit: STORE / MY COSMETICS are words with the 2 px underline; category chips too)
        local MK = require(script.Parent:WaitForChild("MenuKit"))
        MK.WordTab(shopTab); MK.WordTab(lockTab)
        CosmeticsMenu._MK = MK
    end
    shopTab.Button.LayoutOrder, lockTab.Button.LayoutOrder = 1, 2
    local ownedLbl = Text({ Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = S.Sub, Size = UDim2.new(1, -740, 0, 42), TextXAlignment = Enum.TextXAlignment.Right, Text = "", LayoutOrder = 3, Parent = tabs })
    -- BOUND SHOP (0.97, owner: "Everything in the shop will be purchasable with the bound points ... purchasable in set
    -- amounts"): the balance chip opens the pack window (Colorways.PACKS, bought through ColorwayAction "Points")
    local BP_COL = Color3.fromRGB(110, 200, 255)
    local bpBtn = UIStyle.Button(tabs, "BOUND  0   +", S.Steel, UDim2.fromOffset(260, 42), nil, "BoundPoints") -- (UI CLEAN R-A2: quiet -- the balance, not a blue slab)
    bpBtn.Button.LayoutOrder = 4
    local packs = New("Frame", { Name = "BPPacks", BackgroundColor3 = Color3.fromRGB(8, 9, 14), BackgroundTransparency = 0.25, Size = UDim2.fromScale(1, 1),
        ZIndex = 50, Visible = false, Active = true, Parent = panel })
    local packCard = New("Frame", { BackgroundColor3 = Color3.fromRGB(22, 24, 34), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(760, 430), ZIndex = 51, Parent = packs }, { UIStyle.Corner(2) })
    UIStyle.Stroke(BP_COL, 2).Parent = packCard
    Text({ Text = "GET BOUND POINTS", TextSize = 26, TextColor3 = BP_COL, Position = UDim2.fromOffset(24, 16), Size = UDim2.new(1, -48, 0, 32), ZIndex = 52, Parent = packCard })
    Text({ Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = S.Sub, TextWrapped = true, Position = UDim2.fromOffset(24, 50), Size = UDim2.new(1, -48, 0, 36),
        Text = "Everything in the store is bought with BOUND points. Bigger packs give more points per Robux. Points can also be traded.", ZIndex = 52, Parent = packCard })
    local packGrid = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 96), Size = UDim2.new(1, -48, 0, 260), ZIndex = 52, Parent = packCard }, {
        New("UIGridLayout", { CellSize = UDim2.new(0.25, -9, 0, 120), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    for i, pack in ipairs(Colorways.PACKS) do
        local b = New("TextButton", { Name = "Pack_" .. pack.Id, Text = "", AutoButtonColor = true, BackgroundColor3 = Color3.fromRGB(30, 40, 58), LayoutOrder = i, ZIndex = 53, Parent = packGrid }, { UIStyle.Corner(2) })
        UIStyle.Stroke(BP_COL:Lerp(Color3.new(0, 0, 0), 0.3), 1).Parent = b
        Text({ Text = ItemData.FormatNumber(pack.Points), TextSize = 30, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 54, Parent = b })
        Text({ Text = "BOUND POINTS", TextSize = 12, TextColor3 = BP_COL, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 54, Parent = b })
        Text({ Text = pack.Note and ("BONUS " .. pack.Note) or "", TextSize = 12, TextColor3 = S.Gold, Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 54, Parent = b })
        local priceBar = New("Frame", { BackgroundColor3 = BP_COL, Position = UDim2.new(0, 8, 1, -34), Size = UDim2.new(1, -16, 0, 26), ZIndex = 54, Parent = b }, { UIStyle.Corner(2) })
        Text({ Text = "R$ " .. tostring(pack.Price), TextSize = 15, TextColor3 = Color3.fromRGB(10, 14, 22), Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 55, Parent = priceBar })
        b.MouseButton1Click:Connect(function()
            click()
            local ok, msg = Remotes.GetFunction("ColorwayAction"):InvokeServer("Points", pack.Id)
            if hooks.Toast then
                if ok and msg == "Granted" then hooks.Toast("+" .. pack.Points .. " BOUND points")
                elseif not ok then hooks.Toast(tostring(msg or "Not available yet.")) end
            end
            task.delay(0.3, function() if CosmeticsMenu._render then CosmeticsMenu._render() end end)
        end)
    end
    local packClose = UIStyle.Button(packCard, "CLOSE", Color3.fromRGB(70, 76, 96), UDim2.fromOffset(160, 40), UDim2.new(1, -184, 1, -56), "ClosePacks")
    packClose.Button.ZIndex = 53
    packClose.Button.MouseButton1Click:Connect(function() click(); packs.Visible = false end)
    local function OpenPacks() packs.Visible = true end
    bpBtn.Button.MouseButton1Click:Connect(function() click(); OpenPacks() end)
    local function BPHave(st) return math.floor(tonumber(st and st.BoundPoints) or 0) end

    -- ===== category sidebar =====
    local side = New("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(0, 196, 1, -144), Position = UDim2.fromOffset(16, 128),
        ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = panel }, {
        New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
        New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 6) }),
    })

    -- ===== content (middle) =====
    local content = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -606, 1, -144), Position = UDim2.fromOffset(222, 128), Parent = panel })
    local chipRow = New("Frame", { Name = "Chips", BackgroundTransparency = 1, Size = UDim2.new(1, -262, 0, 30), Parent = content }, {
        New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
    })
    local catTitle = Text({ Size = UDim2.new(1, -150, 0, 28), Position = UDim2.fromOffset(0, 38), TextSize = 24, Text = "", Parent = content })
    local catDesc = Text({ Font = UIStyle.BodyFont, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 66), TextSize = 13, TextColor3 = S.Sub, TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top, Text = "", Parent = content })
    -- (UI CLEAN R-A2: the heading in the section-head role (off-white display caps), its line in Meta)
    UIStyle.TextRole(catTitle, "SectionHead"); catTitle.FontFace = UIStyle.RoleFace("Label"); catTitle.TextSize = 18; catTitle.TextStrokeTransparency = 1; catTitle:SetAttribute("NoSnap", true)
    UIStyle.TextRole(catDesc, "Meta"); catDesc.FontFace = UIStyle.RoleFace("Body"); catDesc:SetAttribute("NoSnap", true)
    -- (bundle view) back to every bundle / (locker) show everything, not only what you own
    local backBtn = UIStyle.Button(content, "◀  ALL BUNDLES", S.Steel, UDim2.fromOffset(140, 28), UDim2.new(1, -140, 0, 38), "BackToBundles")
    backBtn.Label.TextSize = 13
    backBtn.Button.Visible = false
    local allBtn = UIStyle.Button(content, "SHOW ALL", S.Steel, UDim2.fromOffset(140, 28), UDim2.new(1, -140, 0, 38), "ShowAll")
    allBtn.Label.TextSize = 13
    allBtn.Button.Visible = false
    local grid = New("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -100), Position = UDim2.fromOffset(0, 100),
        ScrollBarThickness = 6, ScrollBarImageColor3 = S.Sub, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = content }, {
        New("UIGridLayout", { CellSize = UDim2.fromOffset(186, 236), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
        New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingBottom = UDim.new(0, 14) }),
    })
    -- SEARCH (owner 2026-10-07: "I need a search function within the inventory, and cosmetics"): typing searches EVERY
    -- category (name, set, category, rarity); clearing it goes back to the category you were on
    local search = New("TextBox", { Name = "CosmeticSearch", Size = UDim2.fromOffset(250, 28), Position = UDim2.new(1, -254, 0, 0), BackgroundColor3 = Color3.fromRGB(20, 23, 32),
        BorderSizePixel = 0, ClearTextOnFocus = false, Text = "", PlaceholderText = "Search (name, gun, LMG, SMG, sniper...)", PlaceholderColor3 = Color3.fromRGB(110, 116, 130),
        TextColor3 = Color3.fromRGB(235, 235, 240), Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = content },
        { UIStyle.Corner(4), New("UIPadding", { PaddingLeft = UDim.new(0, 8) }) })
    local function Query(): { string }
        local words = {}
        for w in string.gmatch(string.lower(search.Text), "%S+") do table.insert(words, w) end
        return words
    end
    local heroHolder = New("Frame", { Name = "HeroHolder", BackgroundTransparency = 1, Size = UDim2.new(1, -10, 0, 196), Position = UDim2.fromOffset(4, 40), Visible = false, Parent = content })
    local empty = Text({ Font = UIStyle.BodyFont, Size = UDim2.new(1, -40, 0, 60), Position = UDim2.fromOffset(20, 120), TextSize = 16, TextColor3 = S.Sub,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Text = "", Visible = false, Parent = content })

    -- ===== detail panel (right) =====
    local detail = UIStyle.Card(panel, { Name = "Detail", Size = UDim2.new(0, 368, 1, -144), Position = UDim2.new(1, -384, 0, 128), ClipsDescendants = true })
    if CosmeticsMenu._MK then CosmeticsMenu._MK.Card(detail, nil) end -- (UI CLEAN R-A2: the raised card, no box)
    local dPreview = New("Frame", { Name = "Preview", BorderSizePixel = 0, Size = UDim2.new(1, -16, 0, 270), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.fromRGB(10, 12, 20), Parent = detail }, { UIStyle.Corner(10) })
    local dGrad = New("UIGradient", { Rotation = 90, Parent = dPreview })
    local dHint = Text({ Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = S.Sub, Text = "drag to turn  •  scroll to zoom", TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -20), ZIndex = 6, Parent = dPreview })
    -- (UI CLEAN R-A2: the rarity as a quiet tag -- its word in the rarity colour on a dark square tag, no coloured pill)
    local dRarity = Text({ Font = UIStyle.Font, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(92, 20),
        Position = UDim2.fromOffset(16, 16), ZIndex = 6, Parent = detail })
    dRarity.BackgroundTransparency = 0.25
    dRarity:SetAttribute("NoSnap", true)
    local dName = Text({ Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 284), TextSize = 22, Text = "", TextTruncate = Enum.TextTruncate.AtEnd, Parent = detail })
    dName.FontFace = UIStyle.RoleFace("Label"); dName:SetAttribute("TextRole", "Title"); dName:SetAttribute("NoSnap", true); dName.TextStrokeTransparency = 1
    local dCat = Text({ Font = UIStyle.BodyFont, Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 314), TextSize = 13, TextColor3 = S.Sub, Text = "", Parent = detail })
    local dScroll = New("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -16, 1, -478), Position = UDim2.fromOffset(8, 334),
        ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = detail }, {
        New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
        New("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6) }),
    })
    local dDesc = Text({ Font = UIStyle.BodyFont, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 14, TextColor3 = S.Text,
        TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Text = "", LayoutOrder = 1, Parent = dScroll })
    local dExtra = Text({ Font = UIStyle.BodyFont, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 13, TextColor3 = S.Text, -- (UI CLEAN R-A2: off-white body, types in grey)
        TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, RichText = true, Text = "", LayoutOrder = 2, Parent = dScroll })
    local dMain = UIStyle.Button(detail, "", S.Blue, UDim2.new(1, -24, 0, 46), UDim2.new(0, 12, 1, -140), "MainAction")
    dMain.Label.TextSize = 17
    -- (Update 5: the two inspect buttons are secondary actions -- steel, not two more colours under the main one)
    local dTryFP = UIStyle.Button(detail, "TRY IN FIRST PERSON", S.Steel, UDim2.new(1, -24, 0, 36), UDim2.new(0, 12, 1, -88), "TryFP")
    local dTryTP = UIStyle.Button(detail, "VIEW ON CHARACTER", S.Steel, UDim2.new(1, -24, 0, 36), UDim2.new(0, 12, 1, -46), "TryTP")
    dTryFP.Label.TextSize, dTryTP.Label.TextSize = 15, 15
    -- (2026-10-14 COPIES) an owned tradeable piece / bundle can be bought again: one more copy to trade or give away
    local dCopy = UIStyle.Button(detail, "", S.Gold, UDim2.new(1, -24, 0, 36), UDim2.new(0, 12, 1, -184), "BuyCopy")
    dCopy.Label.TextSize = 15
    dCopy.Button.Visible = false
    local copyHandler = nil
    -- (0.93 COLORWAYS) on a set piece = recolour that piece (or the set), on the set's bundle = the whole set
    local ColorwayMenu = require(Shared:WaitForChild("ColorwayMenu"))
    local cwMenu = ColorwayMenu.Build(panel, { GetState = hooks.GetState, PlayClick = click, Toast = hooks.Toast,
        OnChanged = function() if CosmeticsMenu._render then CosmeticsMenu._render() end end })
    local dColor = UIStyle.Button(detail, "COLORWAYS", S.Steel, UDim2.fromOffset(118, 26), UDim2.new(1, -134, 0, 16), "Colorways") -- (UI CLEAN R-A2: a quiet tag-button)
    dColor.Label.TextSize = 13
    dColor.Button.ZIndex = 7
    dColor.Button.Visible = false
    local mainHandler = nil
    local detailSub = nil -- a bundle's item picked in its chip row (nil = the full set)

    -- the inspect buttons for an entry, stacked at the bottom under the main action
    local function StackButtons(t)
        dTryFP.Button.Visible = TRY_FP[t.Cat] == true and hooks.TryOn ~= nil
        dTryTP.Button.Visible = TRY_TP[t.Cat] == true and hooks.TryOn ~= nil
        dColor.Button.Visible = ColorwayMenu.SetOf(t) ~= nil
        if UIStyle.IsPhone() then -- (phones: the two try-on buttons share one row under the main action, see PhoneArrange)
            local both = dTryFP.Button.Visible and dTryTP.Button.Visible
            local any = dTryFP.Button.Visible or dTryTP.Button.Visible
            dTryFP.Button.Size = both and UDim2.new(0.5, -15, 0, 38) or UDim2.new(1, -24, 0, 38)
            dTryTP.Button.Size = dTryFP.Button.Size
            dTryFP.Button.Position = UDim2.new(0, 12, 1, -44)
            dTryTP.Button.Position = both and UDim2.new(0.5, 3, 1, -44) or UDim2.new(0, 12, 1, -44)
            local y = any and -92 or -50
            dMain.Button.Position = UDim2.new(0, 12, 1, y)
            if dCopy.Button.Visible then y -= 42; dCopy.Button.Position = UDim2.new(0, 12, 1, y) end
            dScroll.Size = UDim2.new(1, -16, 1, -180 + y - 6)
            return
        end
        local y = -46
        for _, b in ipairs({ dTryTP, dTryFP }) do
            if b.Button.Visible then b.Button.Position = UDim2.new(0, 12, 1, y); y -= 42 end
        end
        dMain.Button.Position = UDim2.new(0, 12, 1, y - 10)
        if dCopy.Button.Visible then y -= 42; dCopy.Button.Position = UDim2.new(0, 12, 1, y - 10) end
        dScroll.Size = UDim2.new(1, -16, 1, -334 + y - 18)
    end
    -- the big preview: the entry itself, or one item of a bundle (keeps the chip row + hint)
    local function ShowPreview(t, st)
        for _, c in ipairs(dPreview:GetChildren()) do
            if c:IsA("GuiObject") and c ~= dHint and c.Name ~= "BundleBar" then c:Destroy() end
        end
        -- (STORE ICONS v3 pilot) the set's stage behind the live showcase; a bundle shows its whole set (the bundle art),
        -- a place shot (hideout theme) shows the real frame big
        local stage = StoreIcons.StageFor(t)
        local icon = StoreIcons.CardFor(t)
        if stage then
            New("ImageLabel", { Name = "Stage", BackgroundTransparency = 1, Image = stage, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = dPreview })
        end
        if t.Cat == "Bundle" and StoreIcons.BundleDetail[t.Id] then
            New("ImageLabel", { Name = "BundleArt", BackgroundTransparency = 1, Image = StoreIcons.BundleDetail[t.Id], ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = dPreview })
            detailLive = nil
            dHint.Visible = false
            return
        end
        if icon and icon.Shot and t.Cat ~= "KillEffect" then
            New("ImageLabel", { Name = "ShotArt", BackgroundTransparency = 1, Image = icon.Image, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = dPreview })
            detailLive = nil
            dHint.Visible = false
            return
        end
        local okP, live1 = pcall(Preview, dPreview, t, st, true)
        detailLive = okP and live1 or nil
        if stage then -- a brighter, frontal key light on the stage (the store's default lighting read dark graphite as black)
            for _, c in ipairs(dPreview:GetChildren()) do
                if c:IsA("ViewportFrame") then
                    c.Ambient = Color3.fromRGB(205, 205, 215)
                    c.LightColor = Color3.fromRGB(255, 252, 245)
                    c.LightDirection = Vector3.new(-0.45, -0.75, 0.5)
                end
            end
        end
        local k = (Cosmetics.CategoryById[t.Cat] or {}).Preview
        dHint.Visible = (k == "Armor" or k == "Bundle" or k == "Avatar" or k == "Gun" or k == "Melee" or k == "Glove" or k == "Arms" or k == "Grapple" or t.Cat == "KillEffect")
    end

    -- ===== data =====
    local gunWords = {}
    local function GunWords(gun: string): string
        if gunWords[gun] then return gunWords[gun] end
        local ID = require(Shared:WaitForChild("ItemData"))
        local bw = ID.BaseWeapons[gun]
        local words = { gun }
        if bw then
            local w = { BaseId = gun, Class = bw.Class }
            local grp = ID.WeaponGroupOf(w)
            table.insert(words, tostring(bw.Name or ""))
            table.insert(words, ID.WeaponTypeName(w, gun))
            table.insert(words, tostring(bw.Class or ""))
            if grp then
                table.insert(words, ID.WeaponGroups.Label[grp] or grp)
                table.insert(words, ID.WeaponGroups.ClassName[grp] or "")
                table.insert(words, grp)
            end
        end
        gunWords[gun] = string.lower(table.concat(words, " "))
        return gunWords[gun]
    end
    local function Owns(e) return Cosmetics.Owns(State(), e) end
    local function ChipOf(id) for _, c in ipairs(SHOP_CHIPS) do if c.Id == id then return c end end return nil end
    local function Entries()
        local st = State()
        local list = {}
        local words = Query()
        if #words > 0 then
            for _, e in ipairs(Cosmetics.All()) do
                local cat = Cosmetics.CategoryById[e.Cat]
                local hay = string.lower(table.concat({ tostring(e.Name), tostring(e.Id), tostring(e.Rarity), tostring(e.Set or ""), tostring(cat and cat.Label or e.Cat), tostring(e.Desc or "") }, " "))
                -- (0.62, owner: "keyword search in the shop with things like LMG SMG etc and have guns pop up"): a gun skin
                -- also matches its gun's name, type ("LMG", "SMG", "Sniper"), group ("AR / LMG") and class ("Vanguard")
                if e.Gun then hay ..= " " .. GunWords(e.Gun) end
                local ok = true
                for _, w in ipairs(words) do if not string.find(hay, w, 1, true) then ok = false break end end
                if ok and not (cat and cat.Hidden) then table.insert(list, e) end
            end
            if mode == "Shop" then
                local buy = {}
                for _, e in ipairs(list) do if Cosmetics.Buyable(e) then table.insert(buy, e) end end
                list = buy
            else
                if not lockerAll then
                    local own = {}
                    for _, e in ipairs(list) do if Cosmetics.Owns(st, e) then table.insert(own, e) end end
                    list = own
                end
            end
        elseif mode == "Shop" and category == "Home" then
            local bl = Cosmetics.ShelfBundles()
            for i = #bl, 1, -1 do table.insert(list, bl[i]) end -- (newest first)
            return list
        elseif mode == "Shop" and category == "Bundle" and openBundle then
            for _, ref in ipairs(openBundle.Contents or {}) do
                local cat, id = ref:match("^(.-):(.*)$")
                local ce = cat and Cosmetics.Find(cat, id)
                if ce then table.insert(list, ce) end
            end
            return list -- (the bundle's own order)
        elseif mode == "Shop" then
            local chip = ChipOf(category)
            for _, cid in ipairs(chip and chip.Cats or { category }) do
                for _, e in ipairs(Cosmetics.List(cid)) do
                    -- (2026-10-14: kill effects are bundle exclusive -- listed with BUNDLE ONLY + GET THE ... BUNDLE)
                    if Cosmetics.Buyable(e) or (cid == "KillEffect" and e.Unlock == "Bundle" and not e.Retired and e.FX ~= "Seraphim" and e.FX ~= "Infernal") then
                        table.insert(list, e)
                    end
                end
            end
        else
            for _, e in ipairs(Cosmetics.List(category)) do
                if lockerAll or Cosmetics.Owns(st, e) then table.insert(list, e) end
            end
        end
        table.sort(list, function(a, b)
            if mode == "Shop" then
                local ao, bo = Cosmetics.Owns(st, a) and 1 or 0, Cosmetics.Owns(st, b) and 1 or 0
                if ao ~= bo then return ao < bo end -- things you don't own first
            else
                local ae, be = Cosmetics.Equipped(st, a) and 0 or 1, Cosmetics.Equipped(st, b) and 0 or 1
                if ae ~= be then return ae < be end -- what you're wearing first
                local ao, bo = Cosmetics.Owns(st, a) and 0 or 1, Cosmetics.Owns(st, b) and 0 or 1
                if ao ~= bo then return ao < bo end -- then what you own
            end
            local ar, br = Cosmetics.RarityOrder[a.Rarity] or 0, Cosmetics.RarityOrder[b.Rarity] or 0
            if ar ~= br then return ar > br end
            return a.Name < b.Name
        end)
        return list
    end
    local function Counts(catId)
        local st = State()
        local own, total = 0, 0
        for _, e in ipairs(Cosmetics.List(catId)) do
            total += 1
            if Cosmetics.Owns(st, e) then own += 1 end
        end
        return own, total
    end

    local function Act(action, e)
        local ok, msg = Remotes.GetFunction("CosmeticAction"):InvokeServer(action, e.Cat, e.Id)
        if not ok and msg and hooks.Toast then hooks.Toast(tostring(msg)) end
        if ok and action == "Equip" and hooks.OnEquipped then hooks.OnEquipped(e.Cat, e.Id) end
        if ok and action == "Buy" and msg == "Granted" and hooks.Toast then hooks.Toast("★ " .. e.Name .. " is yours. Find it in MY COSMETICS") end
        if ok and action == "Buy" and msg == "Copy" and hooks.Toast then hooks.Toast("★ +1 " .. e.Name .. ". Trade or gift your extra copies [Y]") end
        return ok
    end
    -- (2026-10-20 owner: every buy shows the BOUND points it needs first) BoundShop.Confirm -> CosmeticAction "Buy"
    local function BuyConfirm(e, copy: boolean?)
        require(script.Parent:WaitForChild("BoundShop")).Confirm({ Name = (copy and "another " or "") .. tostring(e.Name), Price = Cosmetics.BPPrice(e) or 0,
            Desc = copy and "An extra copy to trade or gift." or (e.Cat == "Bundle" and "The whole set." or nil), OnBuy = function()
                local ok, msg = Remotes.GetFunction("CosmeticAction"):InvokeServer("Buy", e.Cat, e.Id)
                if ok then
                    if msg == "Granted" and hooks.Toast then hooks.Toast("★ " .. e.Name .. " is yours. Find it in MY COSMETICS") end
                    if msg == "Copy" and hooks.Toast then hooks.Toast("★ +1 " .. e.Name .. ". Trade or gift your extra copies [Y]") end
                    task.delay(0.3, function() CosmeticsMenu._render() end)
                end
                return ok, msg
            end })
    end

    -- the status / price line of an entry: text, colour
    local function Status(e, st)
        local owned, equipped = Cosmetics.Owns(st, e), Cosmetics.Equipped(st, e)
        local n = owned and Cosmetics.Copies(st, e) or 0
        local xn = (n > 1) and ("  x" .. n) or "" -- (2026-10-14 COPIES)
        if equipped then return "✓ EQUIPPED" .. xn, S.Green end
        if owned then return "OWNED" .. xn, Color3.fromRGB(140, 200, 255) end
        if e.Unlock == "Robux" and e.Price then return ((mode == "Locker") and "STORE  " or "") .. tostring(Cosmetics.BPPrice(e)) .. " BP", S.Gold end
        if e.Unlock == "Level" then return "LOCKED  •  LEVEL " .. tostring(e.Level), S.Sub end
        if e.Unlock == "Bundle" then return "BUNDLE ONLY", S.Gold end
        if e.Unlock == "Drop" then return "DROP ONLY", Color3.fromRGB(255, 150, 90) end
        if e.Unlock == "Achievement" then return "ACHIEVEMENT", S.Sub end
        if e.Unlock == "Season" then return "SEASON PASS REWARD", S.Gold end
        return "FREE", S.Sub
    end

    -- ===== detail panel =====
    local function ShowDetail(e)
        selected = e
        for _, c in ipairs(dPreview:GetChildren()) do if c:IsA("GuiObject") and c ~= dHint then c:Destroy() end end
        detailLive = nil
        if not e then
            dName.Text = ""; dCat.Text = ""; dDesc.Text = "Pick something to see it up close."; dExtra.Text = ""
            dRarity.Visible = false; dMain.Button.Visible = false; dTryFP.Button.Visible = false; dTryTP.Button.Visible = false; dColor.Button.Visible = false
            dCopy.Button.Visible = false
            return
        end
        local st = State()
        local rc = RarCol(e.Rarity)
        dGrad.Color = ColorSequence.new(Color3.fromRGB(28, 30, 46), rc:Lerp(Color3.fromRGB(10, 10, 16), 0.65))
        detailSub = nil
        ShowPreview(e, st)
        local catDef = Cosmetics.CategoryById[e.Cat]
        -- a bundle: a chip per item under the preview -- pick one to see (and try) it on its own
        if e.Cat == "Bundle" and false then -- (v3: the bundle's pieces are cards in the grid now; this chip row was a second copy)
            local bar = New("ScrollingFrame", { Name = "BundleBar", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -12, 0, 26),
                Position = UDim2.new(0, 6, 1, -32), ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 3, CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.X, ZIndex = 7, Parent = dPreview }, {
                New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
            })
            dHint.Position = UDim2.new(0, 0, 0, 6)
            dHint.Visible = false -- (the chip row says what to do; the hint ran under the COLORWAYS button)
            local chips = {}
            local function Paint()
                for t, c in pairs(chips) do
                    local on = (t == "full" and detailSub == nil) or (detailSub ~= nil and t == detailSub)
                    c.BackgroundColor3 = on and RarCol(e.Rarity):Lerp(Color3.new(0, 0, 0), 0.25) or Color3.fromRGB(20, 22, 34)
                end
            end
            local function Chip(order, text, item)
                local c = New("TextButton", { Name = "Chip_" .. (item and ((item.Cat and (item.Cat .. "_") or "") .. item.Id) or "FullSet"), AutoButtonColor = false, Text = text, TextSize = 11, Font = UIStyle.BodyFont, TextColor3 = Color3.new(1, 1, 1),
                    Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order, ZIndex = 8, Parent = bar },
                    { UIStyle.Corner(12), New("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }), New("UIStroke", { Color = RarCol(e.Rarity), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
                c:SetAttribute("Skinned", true)
                chips[item or "full"] = c
                c.MouseButton1Click:Connect(function()
                    click()
                    detailSub = item
                    ShowPreview(item or e, State())
                    StackButtons(item or e)
                    Paint()
                end)
            end
            Chip(0, "FULL SET", nil)
            for i, ref in ipairs(e.Contents or {}) do
                local cat, id = ref:match("^(.-):(.*)$")
                local ce = Cosmetics.Find(cat, id)
                if ce then Chip(i, ce.Name, ce) end
            end
            Paint()
        else
            dHint.Position = UDim2.new(0, 0, 1, -20)
        end
        dRarity.Visible = true
        dRarity.Text = string.upper(e.Rarity)
        dRarity.BackgroundColor3 = S.Bg0
        dRarity.TextColor3 = rc:Lerp(S.Text, 0.25)
        dName.Text = string.upper(e.Name)
        dName.TextColor3 = S.Text
        local catLabel = catDef and catDef.Label or ""
        if e.SlotLabel then catLabel = catLabel .. "  •  " .. string.upper(e.SlotLabel) .. " SLOT" end
        if e.Gun then -- (the gun's in-game name: the raw id said "HK21" where every other menu says "21E")
            local bw = require(Shared:WaitForChild("ItemData")).BaseWeapons[e.Gun]
            catLabel = catLabel .. "  •  FITS THE " .. string.upper(bw and (bw.ShortName or bw.Name) or e.Gun)
        end
        if Cosmetics.Tradeable(e) then -- (2026-10-14 COPIES: always in sight, the long text below may scroll)
            local n = Cosmetics.Copies(st, e)
            if n > 0 then catLabel = catLabel .. "  •  YOU OWN " .. n end
        end
        dCat.Text = catLabel
        dDesc.Text = e.Desc or ""
        -- extra lines: where it comes from, bundle contents + worth
        local extra = {}
        if e.Cat == "Bundle" then
            local worth = BundleWorth(e)
            table.insert(extra, "<b>INCLUDES</b>")
            for _, ref in ipairs(e.Contents or {}) do
                local cat, id = ref:match("^(.-):(.*)$")
                local ce = Cosmetics.Find(cat, id)
                if ce then
                    local have = Cosmetics.Owns(st, ce)
                    table.insert(extra, string.format("%s %s <font color=\"#%s\">(%s)</font>", have and "✓" or "•", ce.Name, S.Sub:ToHex(), (Cosmetics.CategoryById[cat] or {}).Label or cat))
                end
            end
            local bpP = Cosmetics.BPPrice(e)
            if bpP and worth > bpP then
                table.insert(extra, string.format("<b>Worth %d BP bought piece by piece: you save %d%%</b>", worth, math.floor((1 - bpP / worth) * 100 + 0.5)))
            end
        elseif e.How and e.Unlock ~= "Robux" then
            table.insert(extra, "HOW TO GET IT: " .. e.How)
        end
        if Cosmetics.Tradeable(e) then
            local n = Cosmetics.Copies(st, e)
            if n > 0 then
                table.insert(extra, string.format("<b>YOU OWN %d %s.</b> Extra copies can be traded or given away in a trade [Y].", n, n == 1 and "COPY" or "COPIES"))
            else
                table.insert(extra, "Tradeable: you can trade it or give it away in a trade [Y], and own more than one.")
            end
        end
        dExtra.Text = table.concat(extra, "\n")
        dScroll.CanvasPosition = Vector2.zero
        -- main action
        local owned, equipped = Cosmetics.Owns(st, e), Cosmetics.Equipped(st, e)
        dMain.Button.Visible = true
        -- (2026-10-14 COPIES) owned + sold in the store + tradeable (or a bundle): BUY ANOTHER COPY above the main action
        copyHandler = nil
        dCopy.Button.Visible = false
        if owned and mode ~= "Locker" and Cosmetics.Buyable(e) and (Cosmetics.Tradeable(e) or e.Cat == "Bundle") then
            local bpP = Cosmetics.BPPrice(e) or 0
            dCopy.Button.Visible = true
            dCopy.SetText("BUY ANOTHER COPY  -  " .. bpP .. " BOUND"); dCopy.SetColor(S.Gold)
            copyHandler = function() BuyConfirm(e, true) end
        end
        local function Set(text, col, enabled, fn)
            dMain.SetText(text); dMain.SetColor(col); dMain.SetEnabled(enabled); mainHandler = fn
        end
        if equipped and catDef and catDef.Toggle then
            Set("✓ EQUIPPED  -  TAKE OFF", S.Green, true, function() Act("Equip", e) end)
        elseif equipped then
            Set("✓ EQUIPPED", S.Green, false)
        elseif owned then
            Set(e.Cat == "Bundle" and "EQUIP THE WHOLE SET" or "EQUIP", S.Blue, true, function() Act("Equip", e) end)
        elseif e.Unlock == "Bundle" then
            -- bundle-only piece: jump to the bundle that has it
            local ref, bundle = e.Cat .. ":" .. e.Id, nil
            for _, b in ipairs(Cosmetics.List("Bundle")) do
                if table.find(b.Contents or {}, ref) then bundle = b; break end
            end
            if bundle then
                local bn = string.upper(bundle.Name)
                if not bn:find("BUNDLE$") then bn = bn .. " BUNDLE" end
                Set("GET THE " .. bn, S.Gold, true, function()
                    mode, category, selected, openBundle = "Shop", "Bundle", bundle, bundle
                    CosmeticsMenu._render()
                end)
            else
                Set("BUNDLE ONLY", Color3.fromRGB(70, 76, 96), false)
            end
        elseif e.Unlock == "Robux" and e.Price and mode == "Locker" then
            -- (MY COSMETICS lists premium items too; buying happens in the STORE, opened on this item)
            Set("GET IT IN THE STORE  -  " .. tostring(Cosmetics.BPPrice(e)) .. " BP", S.Gold, true, function()
                mode, category, selected = "Shop", CHIP_OF_CAT[e.Cat] or e.Cat, e
                if e.Cat == "Bundle" then openBundle = e end -- (a bundle opens on its pieces)
                CosmeticsMenu._render()
            end)
        elseif e.Unlock == "Robux" and e.Price then
            local bpP = Cosmetics.BPPrice(e) or 0 -- (0.97 BOUND SHOP)
            Set("BUY  -  " .. bpP .. " BOUND POINTS", S.Gold, true, function() BuyConfirm(e) end) -- (the popup shows how many more you need)
        else
            local txt = Status(e, st)
            Set(txt, Color3.fromRGB(70, 76, 96), false)
        end
        -- inspect buttons
        StackButtons(e)
    end
    dMain.Button.MouseButton1Click:Connect(function()
        if not dMain.Button.Active or not mainHandler then return end
        click()
        mainHandler()
    end)
    dCopy.Button.MouseButton1Click:Connect(function()
        if not dCopy.Button.Visible or not copyHandler then return end
        click()
        copyHandler()
    end)
    dColor.Button.MouseButton1Click:Connect(function()
        local t = detailSub or selected
        if t and ColorwayMenu.SetOf(t) then click(); cwMenu.Open(t) end
    end)
    dTryFP.Button.MouseButton1Click:Connect(function()
        if selected and hooks.TryOn then click(); hooks.TryOn(detailSub or selected, "FP") end
    end)
    dTryTP.Button.MouseButton1Click:Connect(function()
        if selected and hooks.TryOn then click(); hooks.TryOn(detailSub or selected, "TP") end
    end)

    -- ===== cards =====
    local cardFrames = {}
    local function Card(e, order)
        local st = State()
        local rc = RarCol(e.Rarity)
        local isSel = selected and selected.Cat == e.Cat and selected.Id == e.Id
        local card = UIStyle.Card(grid, { Name = e.Cat .. "_" .. e.Id, LayoutOrder = order, ClipsDescendants = true }, isSel and Color3.new(1, 1, 1) or rc:Lerp(Color3.fromRGB(40, 42, 56), 0.55))
        if CosmeticsMenu._MK then -- (UI CLEAN R-A: the target's tile -- raised surface, the rarity as a 2 px bottom line; picked = a 1 px off-white edge)
            CosmeticsMenu._MK.Card(card, rc)
            if isSel then local es = UIStyle.Stroke(S.Text, 1); es.Transparency = 0.2; es.Parent = card end
        end
        local btn = New("TextButton", { Name = "Select", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = card })
        btn:SetAttribute("Skinned", true)
        -- (0.97 STORE ICONS v2: a lit stage in the item's rarity colour -- tinted top, soft halo behind the item, dark floor --
        -- instead of a near-black box)
        local pv = New("Frame", { BorderSizePixel = 0, Size = UDim2.new(1, -12, 0, 150), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = card }, { UIStyle.Corner(2) })
        local icon = (not workspace:GetAttribute("DevNoStoreIcons")) and StoreIcons.CardFor(e) -- (Studio: the booth shoots the live models)
        if icon then
            -- (STORE ICONS v3 pilot) the pre-rendered card: the real item, lit + framed in its set's colours (no live 3D)
            pv.BackgroundColor3 = Color3.fromRGB(12, 13, 19)
            New("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = icon.Image, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = pv })
        else
            New("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rc:Lerp(Color3.fromRGB(30, 32, 46), 0.7)),
                ColorSequenceKeypoint.new(0.6, rc:Lerp(Color3.fromRGB(20, 21, 30), 0.86)), ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 13, 19)) }), Parent = pv })
            -- a soft glow: many faint stacked ovals read as one smooth falloff (three strong ones looked like a target)
            for k = 1, 9 do
                local f = 1.25 - (k - 1) * 0.11
                New("Frame", { Name = "Halo" .. k, BorderSizePixel = 0, BackgroundColor3 = rc:Lerp(Color3.new(1, 1, 1), 0.55), BackgroundTransparency = 0.965, AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(f * 0.66, f * 0.92), ZIndex = 1, Parent = pv }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
            end
            local okP, lv = pcall(Preview, pv, e, st, false)
            if okP and lv then table.insert(live, lv) end
            -- rarity strip along the top of the preview
            New("Frame", { BorderSizePixel = 0, BackgroundColor3 = rc, Size = UDim2.new(1, 0, 0, 3), Parent = pv })
        end
        Text({ Position = UDim2.fromOffset(10, 160), Size = UDim2.new(1, -20, 0, 22), TextSize = 16, Stroke = 1.5, Text = e.Name, TextColor3 = rc, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
        local catLabel = (Cosmetics.CategoryById[e.Cat] and Cosmetics.CategoryById[e.Cat].Label or "")
        if e.SlotLabel then catLabel = string.upper(e.SlotLabel) end
        Text({ Font = UIStyle.BodyFont, Position = UDim2.fromOffset(10, 182), Size = UDim2.new(1, -20, 0, 14), TextSize = 11, TextColor3 = S.Sub, Text = catLabel, Parent = card })
        local stText, stCol = Status(e, st)
        local chip = Text({ Font = UIStyle.Font, TextSize = 13, Text = stText, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center,
            Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 1, -34), Parent = card })
        chip.BackgroundTransparency = 0
        chip.BackgroundColor3 = stCol:Lerp(Color3.new(0, 0, 0), 0.45)
        New("UICorner", { CornerRadius = UDim.new(0, 8), Parent = chip })
        New("UIStroke", { Color = stCol, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = chip })
        UIStyle.Hover(btn, 0.02)
        btn.MouseButton1Click:Connect(function()
            click()
            ShowDetail(e)
            for k, f in pairs(cardFrames) do
                local st2 = f:FindFirstChildOfClass("UIStroke")
                if st2 then st2.Color = (k == e.Cat .. "_" .. e.Id) and Color3.new(1, 1, 1) or RarCol((Cosmetics.Find(k:match("^(.-)_"), k:match("^.-_(.*)$")) or {}).Rarity) end
            end
        end)
        cardFrames[e.Cat .. "_" .. e.Id] = card
        return card
    end

    -- the FEATURED hero: a carousel over the bundles (newest first), big, in each set's own colours
    local HERO_STYLE = {
        Infernal = { Grad = { Color3.fromRGB(70, 18, 40), Color3.fromRGB(14, 6, 16) }, Stroke = Color3.fromRGB(235, 50, 80), Emblem = "EmblemInfernal",
            Name = Color3.fromRGB(255, 170, 190), Chip = Color3.fromRGB(150, 24, 50) },
    }
    -- every SkinSets set styles its own hero (set.Hero = { Grad = {a, b}, Stroke, Emblem = asset id or CosmeticArt key, Name, Chip })
    for _, set in ipairs(require(Shared:WaitForChild("SkinFX")).SetOrder or {}) do
        if set.Hero then HERO_STYLE[set.Kind] = set.Hero end
    end
    local function HeroStyle(b) return HERO_STYLE[b.Src and b.Src.Set or b.Set or ""] or {} end
    local function Emblem(hs) return CosmeticArt[hs.Emblem or "EmblemSeraph"] or (type(hs.Emblem) == "string" and hs.Emblem:find("rbxassetid") and hs.Emblem) or CosmeticArt.EmblemSeraph end
    local NOUN = { WeaponSkin = "gun skins", MeleeSkin = "a melee", Glove = "gloves", Sleeve = "sleeves", Arms = "arms", HealthBar = "a health bar", HudTheme = "a UI theme", KillEffect = "a kill effect" }
    local function BundleBlurb(b)
        local kinds, seen = {}, {}
        for _, ref in ipairs(b.Contents or {}) do
            local cat = ref:match("^(.-):")
            if cat and NOUN[cat] and not seen[cat] then seen[cat] = true; table.insert(kinds, NOUN[cat]) end
        end
        return (#kinds > 1) and (table.concat(kinds, ", ", 1, #kinds - 1) .. " and " .. kinds[#kinds]) or (kinds[1] or "")
    end
    local function PriceTag(b, st)
        local worth = BundleWorth(b)
        if Cosmetics.Owns(st, b) then return "✓ OWNED", S.Green end
        local bpP = Cosmetics.BPPrice(b) or 0
        return tostring(bpP) .. " BP" .. ((worth > bpP) and string.format("   SAVE %d%%", math.floor((1 - bpP / worth) * 100 + 0.5)) or ""), nil
    end
    -- (UI CLEAN R-A2) the price as parts: "799 BP" (display number), "SAVE 40%" (a small tag) or owned
    local function PriceParts(b, st)
        if mode == "Locker" and Cosmetics.Equipped(st, b) then return "✓ EQUIPPED", nil, true end
        if Cosmetics.Owns(st, b) then return "✓ OWNED", nil, true end
        local worth = BundleWorth(b)
        local bpP = Cosmetics.BPPrice(b) or 0
        return ItemData.FormatNumber(bpP) .. " BP", (worth > bpP) and string.format("SAVE %d%%", math.floor((1 - bpP / worth) * 100 + 0.5)) or nil, false
    end
    -- a price line: the number in the display face (Text), the save tag small (off-white words on a faint off-white tag)
    local function PriceLine(parent, b, st, pos, size, align, z)
        local row = New("Frame", { Name = "Price", BackgroundTransparency = 1, Position = pos, Size = size, ZIndex = z or 3, Parent = parent }, {
            New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8),
                HorizontalAlignment = align or Enum.HorizontalAlignment.Left, SortOrder = Enum.SortOrder.LayoutOrder }) })
        row:SetAttribute("Skinned", true)
        local main, save, owned = PriceParts(b, st)
        local n = Text({ Text = main, TextSize = 17, TextColor3 = owned and S.Good or S.Text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), LayoutOrder = 1, ZIndex = (z or 3) + 1, Parent = row })
        n:SetAttribute("TypeRole", "Accent"); n:SetAttribute("TextRole", "Number"); n:SetAttribute("NoSnap", true); n.FontFace = UIStyle.RoleFace("Accent")
        if save then
            local t = Text({ Text = save, TextSize = 12, TextColor3 = S.Text, BackgroundColor3 = S.Text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), LayoutOrder = 2, ZIndex = (z or 3) + 1, Parent = row })
            t.BackgroundTransparency = 0.86
            New("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = t })
            t:SetAttribute("TypeRole", "Label"); t:SetAttribute("TextRole", "Meta"); t:SetAttribute("NoSnap", true); t.FontFace = UIStyle.RoleFace("Label")
        end
        return row
    end
    local function OpenBundle(b)
        mode, category, openBundle, selected = "Shop", "Bundle", b, b
        CosmeticsMenu._render()
    end
    local function Hero()
        local bl = Cosmetics.ShelfBundles()
        if #bl == 0 then return false end
        heroIndex = ((heroIndex - 1) % #bl) + 1
        local b = bl[#bl - heroIndex + 1] -- (1 = the newest)
        local hs = HeroStyle(b)
        local st = State()
        -- (UI CLEAN R-A2: square, no set-colour outline -- the artwork carries the colour; the set colour = ONE 2 px line under it)
        local hero = New("Frame", { Name = "Hero", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, Parent = heroHolder })
        New("UIGradient", { Rotation = 20, Color = ColorSequence.new((hs.Grad or {})[1] or Color3.fromRGB(70, 56, 30), (hs.Grad or {})[2] or Color3.fromRGB(18, 16, 22)), Parent = hero })
        New("Frame", { Name = "SetLine", BackgroundColor3 = hs.Stroke or S.Text, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), ZIndex = 8, Parent = hero })
        local heroArt = StoreIcons.Hero[b.Id]
        if heroArt then
            -- (STORE ICONS v3 pilot) the whole set on one stage (arms, melee, every gun) in the set's colours; the title,
            -- blurb and button stay live text on the art's deep left panel
            New("ImageLabel", { Name = "HeroArt", BackgroundTransparency = 1, Image = heroArt, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = hero })
            local eb = Text({ Font = UIStyle.Font, Position = UDim2.fromOffset(46, 20), Size = UDim2.new(0.36, -46, 0, 18), TextSize = 13, TextColor3 = S.Text,
                Text = "FEATURED BUNDLE", ZIndex = 3, Parent = hero })
            eb:SetAttribute("TypeRole", "Label"); eb:SetAttribute("NoSnap", true); eb.FontFace = UIStyle.RoleFace("Label") -- (UI CLEAN R-A2: an off-white caps eyebrow)
        else
            local pv = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 300, 1, 0), Position = UDim2.new(1, -330, 0, 0), Parent = hero })
            local okP, lv = pcall(Preview, pv, b, st, false)
            if okP and lv then table.insert(live, lv) end
            New("ImageLabel", { BackgroundTransparency = 1, Image = Emblem(hs), ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(200, 84), Position = UDim2.fromOffset(46, 10), Parent = hero })
        end
        local textW = heroArt and UDim2.new(0.36, -46, 0, 0) or UDim2.new(1, -400, 0, 0)
        Text({ Position = UDim2.fromOffset(46, heroArt and 42 or 96), Size = textW + UDim2.fromOffset(0, heroArt and 62 or 30), TextSize = heroArt and 30 or 24, Stroke = 2, Text = string.upper(b.Name), TextColor3 = S.Text or Color3.fromRGB(255, 226, 150),
            TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3, Parent = hero })
        Text({ Font = UIStyle.BodyFont, Position = UDim2.fromOffset(46, heroArt and 106 or 126), Size = textW + UDim2.fromOffset(0, heroArt and 36 or 18), TextSize = 13, TextColor3 = Color3.fromRGB(230, 222, 200), TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top, Text = string.format("%d items: %s", #(b.Contents or {}), BundleBlurb(b)), ZIndex = 3, Parent = hero })
        -- (UI CLEAN R-A2: VIEW BUNDLE = the secondary outlined button; the price as its own neutral line above it)
        PriceLine(hero, b, st, UDim2.fromOffset(46, 158), UDim2.fromOffset(150, 28), nil, 3)
        local view = UIStyle.Button(hero, "VIEW BUNDLE", S.Steel, UDim2.fromOffset(150, 32), UDim2.fromOffset(200, 156), "ViewBundle") -- (one row with the price: the hero is 196 tall)
        view.Label.TextSize = 14
        view.Button.ZIndex = 9
        view.Button.MouseButton1Click:Connect(function() click(); OpenBundle(b) end)
        -- carousel arrows + dots
        for _, d in ipairs({ { "<", 0, -1 }, { ">", 1, 1 } }) do
            local a = UIStyle.Button(hero, d[1], Color3.fromRGB(30, 30, 40), UDim2.fromOffset(32, 64), UDim2.new(d[2], d[2] == 0 and 6 or -38, 0.5, -32), "Arrow" .. d[1])
            a.Label.TextSize = 22
            a.Button.ZIndex = 9
            a.Button.MouseButton1Click:Connect(function()
                click()
                heroIndex += d[3]
                for _, c in ipairs(heroHolder:GetChildren()) do c:Destroy() end
                Hero()
            end)
        end
        Text({ Font = UIStyle.BodyFont, Position = UDim2.new(1, -330, 1, -24), Size = UDim2.fromOffset(300, 18), TextSize = 12, TextColor3 = Color3.fromRGB(220, 220, 230),
            TextXAlignment = Enum.TextXAlignment.Center, Text = string.format("%d / %d", heroIndex, #bl), ZIndex = 9, Parent = hero })
        return true
    end
    -- a bundle as a flat card (its set's colours + emblem + price): cheap, no 3D
    local function BundleCard(b, order)
        local hs = HeroStyle(b)
        local st = State()
        -- (UI CLEAN R-A2: the target's tile -- square, no outline, no glow; the set colour = ONE 2 px bottom line; hover = a 1 px off-white edge)
        local card = New("TextButton", { Name = "Bundle_" .. b.Id, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, LayoutOrder = order, Parent = grid })
        card:SetAttribute("Skinned", true)
        New("UIGradient", { Rotation = 90, Color = ColorSequence.new((hs.Grad or {})[1] or Color3.fromRGB(70, 56, 30), (hs.Grad or {})[2] or Color3.fromRGB(18, 16, 22)), Parent = card })
        local picked = mode == "Locker" and selected ~= nil and selected.Cat == "Bundle" and selected.Id == b.Id
        local cardStroke = New("UIStroke", { Color = S.Text, Thickness = 1, Transparency = picked and 0.2 or 1, Parent = card })
        New("Frame", { Name = "SetLine", BackgroundColor3 = hs.Stroke or S.Text, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), ZIndex = 5, Parent = card })
        local art = StoreIcons.BundleCard[b.Id]
        if art then -- (STORE ICONS v3 pilot) the set's pieces together on its stage; the name sits on the art's dark floor
            New("ImageLabel", { Name = "Art", BackgroundTransparency = 1, Image = art, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), Parent = card })
            local nm = Text({ Position = UDim2.new(0, 12, 1, -58), Size = UDim2.new(1, -24, 0, 22), TextSize = 17, Text = string.upper((b.Name:gsub("%s*Bundle$", ""))),
                TextColor3 = S.Text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = card })
            nm:SetAttribute("TypeRole", "Label"); nm:SetAttribute("NoSnap", true); nm.FontFace = UIStyle.RoleFace("Label")
        else
            New("ImageLabel", { BackgroundTransparency = 1, Image = Emblem(hs), ScaleType = Enum.ScaleType.Fit, Size = UDim2.new(1, -24, 0, 92), Position = UDim2.fromOffset(12, 10), Parent = card })
            Text({ Position = UDim2.fromOffset(12, 106), Size = UDim2.new(1, -24, 0, 38), TextSize = 15, TextWrapped = true, Text = string.upper((b.Name:gsub("%s*Bundle$", ""))),
                TextColor3 = S.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
        end
        PriceLine(card, b, st, UDim2.new(0, 12, 1, -34), UDim2.new(1, -24, 0, 24), nil, 3) -- (UI CLEAN R-A2: a neutral price line, no pill)
        local function Lit(on) UIStyle.Motion.Tween(cardStroke, 0.12, { Transparency = picked and 0.2 or (on and 0.3 or 1) }) end
        card.MouseEnter:Connect(function() Lit(true) end)
        card.MouseLeave:Connect(function() Lit(false) end)
        card.SelectionGained:Connect(function() Lit(true) end)
        card.SelectionLost:Connect(function() Lit(false) end)
        card.MouseButton1Click:Connect(function()
            click()
            -- (MY COSMETICS BUNDLES: a card picks the bundle for the detail panel -- EQUIP THE WHOLE SET -- the store opens its pieces)
            if mode == "Locker" then selected = b; CosmeticsMenu._render() else OpenBundle(b) end
        end)
        return card
    end

    -- ===== render =====
    local sideButtons = {}
    local chipButtons = {}
    local function RenderChips()
        for _, b in pairs(chipButtons) do b.Button:Destroy() end
        chipButtons = {}
        chipRow.Visible = mode == "Shop"
        if mode ~= "Shop" then return end
        for i, c in ipairs(SHOP_CHIPS) do
            local cd = Cosmetics.CategoryById[c.Id]
            local col = c.Color or (cd and cd.Color) or S.Blue
            local on = (category == c.Id) or (c.Id == "Home" and category == "Bundle")
            local _ = col
            -- (Update 5: the chosen chip is the accent slab, the rest neutral -- one colour means "selected")
            local b = UIStyle.Button(chipRow, c.Label, S.Bg1, UDim2.fromOffset(0, 30), nil, "Chip_" .. c.Id)
            if CosmeticsMenu._MK then CosmeticsMenu._MK.WordTab(b) end -- (UI CLEAN R-A: words)
            b.SetSelected(on)
            b.Button.AutomaticSize = Enum.AutomaticSize.X
            b.Button.LayoutOrder = i
            b.Label.TextSize = 14
            b.Label.Size = UDim2.new(0, 0, 1, 0)
            b.Label.AutomaticSize = Enum.AutomaticSize.X
            New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = b.Button })
            b.Button.MouseButton1Click:Connect(function()
                click()
                category, openBundle, selected = c.Id, nil, nil
                search.Text = ""
                CosmeticsMenu._render()
            end)
            chipButtons[c.Id] = b
        end
    end
    -- MY COSMETICS: one slot per category, showing what you wear in it
    local function EquippedName(catId)
        local st = State()
        local names = {}
        for _, e in ipairs(Cosmetics.List(catId)) do
            if Cosmetics.Equipped(st, e) and e.Unlock ~= "Free" then table.insert(names, e.Name) end
        end
        if #names == 0 then return "Default" end
        if #names > 1 then return #names .. " equipped" end
        return names[1]
    end
    local function RenderSide()
        for _, b in pairs(sideButtons) do b:Destroy() end
        sideButtons = {}
        side.Visible = mode == "Locker"
        if mode ~= "Locker" then return end
        local cats = {}
        -- (2026-10-29, owner: "There is no bundle section in our inventory, only in the store"): BUNDLES is the first slot
        local bundleCat = Cosmetics.CategoryById.Bundle
        if bundleCat then table.insert(cats, bundleCat) end
        for _, c in ipairs(Cosmetics.Categories) do
            if not c.Hidden and not c.Soon and c.Id ~= "Bundle" then table.insert(cats, c) end
        end
        for i, c in ipairs(cats) do
            local own, total = Counts(c.Id)
            local on = c.Id == category
            -- (Update 5: neutral slots; the picked one lit with a gold edge -- the category colour stays on its icon + name)
            local b = New("TextButton", { Name = c.Id, Text = "", AutoButtonColor = false, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 58),
                BackgroundColor3 = S.Text, BackgroundTransparency = on and 0.915 or 0.955, BorderSizePixel = 0, Parent = side }) -- (UI CLEAN R-A: the target's card, brighter when picked)
            if on then New("Frame", { BackgroundColor3 = S.Text, BorderSizePixel = 0, Size = UDim2.new(0, 2, 1, 0), Parent = b }) end
            if c.IconKey then
                UIStyle.Icon(c.IconKey, { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(9, 15), ImageColor3 = c.Color, Parent = b })
            end
            Text({ Size = UDim2.new(1, -50, 0, 18), Position = UDim2.fromOffset(44, 5), TextSize = 14, Text = c.Label, TextColor3 = S.Text, Parent = b }) -- (UI CLEAN audit: the slot name in Text; its colour stays on the icon)
            Text({ Font = UIStyle.BodyFont, Size = UDim2.new(1, -50, 0, 16), Position = UDim2.fromOffset(44, 23), TextSize = 13, TextColor3 = S.Text,
                TextTruncate = Enum.TextTruncate.AtEnd, Text = EquippedName(c.Id), Parent = b })
            Text({ Font = UIStyle.BodyFont, Size = UDim2.new(1, -50, 0, 14), Position = UDim2.fromOffset(44, 39), TextSize = 12, TextColor3 = S.Sub,
                Text = string.format("%d owned", own), Parent = b })
            UIStyle.Hover(b, 0.03)
            b.MouseButton1Click:Connect(function()
                click()
                category = c.Id
                selected = nil
                CosmeticsMenu._render()
            end)
            sideButtons[c.Id] = b
        end
    end

    -- PHONE (2026-10-13, owner on a real phone): the window is 980 wide instead of 1220 (drawn ~0.84x instead of 0.64x):
    -- the STORE / MY COSMETICS / BOUND POINTS row moves up into the title bar, the slot list is 170 wide, the detail panel
    -- 300 wide with a short preview and the try-on buttons side by side, the store's hero carousel steps aside (the
    -- bundles are the grid's first cards). Desktop values are restored when it isn't a phone.
    local arranged = false -- (built as the desktop arrangement: only a change of device / preview re-arranges)
    local function PhoneArrange(phone: boolean)
        if phone == arranged then return end
        arranged = phone
        if phone then
            tabs.Position, tabs.Size = UDim2.fromOffset(212, 14), UDim2.new(1, -290, 0, 44)
            shopTab.Button.Size, lockTab.Button.Size, bpBtn.Button.Size = UDim2.fromOffset(150, 40), UDim2.fromOffset(190, 40), UDim2.fromOffset(220, 40)
            ownedLbl.Visible = false
            if subtitle then subtitle.Visible = false end
            side.Size, side.Position = UDim2.new(0, 170, 1, -90), UDim2.fromOffset(16, 74)
            detail.Size, detail.Position = UDim2.new(0, 300, 1, -90), UDim2.new(1, -316, 0, 74)
            dPreview.Size = UDim2.new(1, -16, 0, 120)
            dName.Position, dCat.Position = UDim2.fromOffset(12, 132), UDim2.fromOffset(12, 160)
            dScroll.Position, dScroll.Size = UDim2.fromOffset(8, 180), UDim2.new(1, -16, 1, -276)
            dMain.Button.Size, dMain.Button.Position = UDim2.new(1, -24, 0, 42), UDim2.new(0, 12, 1, -92)
            dTryFP.Button.Size, dTryFP.Button.Position = UDim2.new(0.5, -15, 0, 38), UDim2.new(0, 12, 1, -44)
            dTryTP.Button.Size, dTryTP.Button.Position = UDim2.new(0.5, -15, 0, 38), UDim2.new(0.5, 3, 1, -44)
            dTryFP.SetText("TRY IT"); dTryTP.SetText("ON CHARACTER")
            search.Size = UDim2.fromOffset(170, 28); search.Position = UDim2.new(1, -174, 0, 0)
            chipRow.Size = UDim2.new(1, -180, 0, 30)
        else
            tabs.Position, tabs.Size = UDim2.fromOffset(16, 74), UDim2.new(1, -32, 0, 44)
            shopTab.Button.Size, lockTab.Button.Size, bpBtn.Button.Size = UDim2.fromOffset(200, 42), UDim2.fromOffset(240, 42), UDim2.fromOffset(260, 42)
            ownedLbl.Visible = true
            if subtitle then subtitle.Visible = true end
            side.Size, side.Position = UDim2.new(0, 196, 1, -144), UDim2.fromOffset(16, 128)
            detail.Size, detail.Position = UDim2.new(0, 368, 1, -144), UDim2.new(1, -384, 0, 128)
            dPreview.Size = UDim2.new(1, -16, 0, 270)
            dName.Position, dCat.Position = UDim2.fromOffset(12, 284), UDim2.fromOffset(12, 314)
            dScroll.Position, dScroll.Size = UDim2.fromOffset(8, 334), UDim2.new(1, -16, 1, -478)
            dMain.Button.Size, dMain.Button.Position = UDim2.new(1, -24, 0, 46), UDim2.new(0, 12, 1, -140)
            dTryFP.Button.Size, dTryFP.Button.Position = UDim2.new(1, -24, 0, 36), UDim2.new(0, 12, 1, -88)
            dTryTP.Button.Size, dTryTP.Button.Position = UDim2.new(1, -24, 0, 36), UDim2.new(0, 12, 1, -46)
            dTryFP.SetText("TRY IN FIRST PERSON"); dTryTP.SetText("VIEW ON CHARACTER")
            search.Size = UDim2.fromOffset(250, 28); search.Position = UDim2.new(1, -254, 0, 0)
            chipRow.Size = UDim2.new(1, -262, 0, 30)
        end
    end
    local function Layout()
        local phone = UIStyle.IsPhone()
        PhoneArrange(phone)
        local top0 = phone and 74 or 128
        if mode == "Shop" then
            content.Position = UDim2.fromOffset(16, top0)
            content.Size = UDim2.new(1, phone and -342 or -416, 1, -(top0 + 16))
        else
            content.Position = UDim2.fromOffset(phone and 196 or 222, top0)
            content.Size = UDim2.new(1, phone and -522 or -622, 1, -(top0 + 16))
        end
        -- (locker: no chip row, so the title + SHOW ALL move up beside the search box)
        local base = (mode == "Shop") and 38 or 0
        catTitle.Position, catDesc.Position = UDim2.fromOffset(0, base), UDim2.fromOffset(0, base + 28)
        catTitle.Size = UDim2.new(1, (mode == "Shop") and -150 or -420, 0, 28)
        allBtn.Button.Position = UDim2.new(1, -404, 0, 0)
        local gl = grid:FindFirstChildOfClass("UIGridLayout")
        local bundleTiles = (mode == "Shop" and category == "Home") or (mode == "Locker" and category == "Bundle" and #Query() == 0)
        if gl then gl.CellSize = bundleTiles and UDim2.fromOffset(196, 186) or UDim2.fromOffset(186, 236) end
    end

    local function RenderGrid()
        live = {}
        cardFrames = {}
        for _, c in ipairs(grid:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        Layout()
        local searching = #Query() > 0
        local cat = Cosmetics.CategoryById[category]
        local chip = ChipOf(category)
        backBtn.Button.Visible = mode == "Shop" and category == "Bundle" and not searching
        allBtn.Button.Visible = mode == "Locker"
        allBtn.SetText(lockerAll and "ONLY MINE" or "SHOW ALL")
        do -- (2026-10-15, owner: "The search bar blocks the hideout items in the store"): with 8 category chips the row ran
            -- under the search box (HIDEOUT hidden) -- in the STORE the chips take the whole row and search moves to the title line
            local sw = search.Size.X.Offset -- (PhoneArrange: 250, or 170 on a phone)
            if mode == "Shop" then
                local shift = backBtn.Button.Visible and 146 or 0 -- (left of ALL BUNDLES in a bundle view)
                chipRow.Size = UDim2.new(1, 0, 0, 30)
                search.Position = UDim2.new(1, -sw - 4 - shift, 0, 38)
                catTitle.Size = UDim2.new(1, -(sw + 12 + shift), 0, 28)
            else
                chipRow.Size = UDim2.new(1, -(sw + 12), 0, 30)
                search.Position = UDim2.new(1, -sw - 4, 0, 0)
                catTitle.Size = UDim2.new(1, -150, 0, 28)
            end
        end
        if searching then
            catTitle.Text = "SEARCH: " .. string.upper(search.Text)
            catTitle.TextColor3 = S.Text
            catDesc.Text = (mode == "Shop") and "Everything in the store that matches." or "Your cosmetics that match."
        elseif mode == "Shop" and category == "Home" then
            catTitle.Text, catTitle.TextColor3 = "BUNDLES", S.Text -- (UI CLEAN R-A: heads in Text)
            catDesc.Text = "Every bundle is a full set: gun skins, a melee, gloves, sleeves, a health bar and a kill effect, cheaper than its pieces. Open one to see (and buy) each piece."
        elseif mode == "Shop" and category == "Bundle" and openBundle then
            catTitle.Text, catTitle.TextColor3 = string.upper(openBundle.Name), HeroStyle(openBundle).Name or Color3.fromRGB(255, 210, 80)
            catDesc.Text = "Everything in this bundle. Click a piece to inspect it and buy it on its own, or get the whole set on the right."
        elseif mode == "Locker" and category == "Bundle" then
            catTitle.Text, catTitle.TextColor3 = "BUNDLES", S.Text
            catDesc.Text = lockerAll and "Every bundle, owned or not. Click one to see what it has and where to get it."
                or "The sets you own. Pick one and EQUIP THE WHOLE SET to wear every piece at once."
        else
            catTitle.Text = chip and chip.Label or (cat and cat.Label or "")
            catTitle.TextColor3 = S.Text -- (UI CLEAN R-A: heads in Text; the category colour stays on its icon)
            catDesc.Text = (mode == "Locker") and (lockerAll and "Everything in this slot, owned or not. Click one to see where to get it." or "What you own for this slot. Click one to equip it.")
                or ((cat and cat.Desc) or "Hideout themes, stash skins and portal skins.")
        end
        local list = Entries()
        for _, c in ipairs(heroHolder:GetChildren()) do c:Destroy() end
        local hero = (not searching) and category == "Home" and mode == "Shop" and not UIStyle.IsPhone() and Hero()
        heroHolder.Visible = hero == true
        if hero then catTitle.Position = UDim2.fromOffset(0, 244); catDesc.Position = UDim2.fromOffset(0, 272) end
        local top = hero and 304 or ((mode == "Shop") and 100 or 62)
        grid.Position = UDim2.fromOffset(0, top)
        grid.Size = UDim2.new(1, 0, 1, -top)
        for i, e in ipairs(list) do
            if ((mode == "Shop" and category == "Home") or (mode == "Locker" and category == "Bundle")) and not searching and e.Cat == "Bundle" then BundleCard(e, i) else Card(e, i) end
        end
        empty.Visible = #list == 0
        empty.Position = UDim2.fromOffset(20, top + 20)
        empty.Text = searching and "Nothing matches that search." or ((mode == "Locker" and not lockerAll) and (category == "Bundle" and "You don't own a bundle yet. Press SHOW ALL to see them all, or open the STORE."
            or "You don't own anything for this slot yet. Press SHOW ALL to see where to get them.") or "Nothing here yet.")
        grid.CanvasPosition = Vector2.zero
        -- keep (or pick) a selection for the detail panel
        if selected then
            ShowDetail(Cosmetics.Find(selected.Cat, selected.Id) or selected)
        elseif mode == "Shop" and category == "Home" then
            local bl = Cosmetics.ShelfBundles()
            ShowDetail(bl[#bl - ((heroIndex - 1) % math.max(1, #bl))])
        else
            ShowDetail(list[1])
        end
    end

    function CosmeticsMenu._render()
        local col = MODE_COL[mode]
        shopTab.SetSelected(mode == "Shop") -- (v4 NEON)
        lockTab.SetSelected(mode == "Locker")
        local body = panel:FindFirstChild("Body")
        local glow = body and body:FindFirstChild("AccentGlow")
        if glow then glow.BackgroundColor3 = col end
        local st, own, total = State(), 0, 0
        for _, e in ipairs(Cosmetics.All()) do total += 1; if Cosmetics.Owns(st, e) then own += 1 end end
        ownedLbl.Text = string.format("Collection: %d / %d", own, total)
        -- (UI CLEAN R-A2: phones share the title row with the STORE / MY COSMETICS tabs: the short line only)
        if subtitle then subtitle.Text = UIStyle.IsPhone() and ((mode == "Shop") and "Premium looks, bought with BOUND points." or "Your loadout.")
            or ((mode == "Shop") and "Premium looks, bought with BOUND points. Open a bundle, inspect anything, try it on before you buy." or "Your loadout: pick a slot, click what you own to wear it.") end
        -- (UI CLEAN audit: the full-screen top bar names the mode too -- it said STORE + the shop line over MY COSMETICS)
        local fld = panel.Parent and panel.Parent:FindFirstChild(panel.Name .. "_Field")
        if fld and subtitle then
            local meta = fld:FindFirstChild("Meta", true)
            if meta and meta:IsA("TextLabel") then meta.Text = subtitle.Text end
            for _, o in ipairs(fld:GetDescendants()) do
                if o:IsA("TextButton") and (o.Text == "STORE" or o.Text == "COSMETICS") then o.Text = (mode == "Shop") and "STORE" or "COSMETICS" end
            end
        end
        bpBtn.SetText("BOUND  " .. ItemData.FormatNumber(BPHave(st)) .. "   +")
        local title = panel:FindFirstChild("TitleBar") and panel.TitleBar:FindFirstChild("Title")
        if title then title.Text = (mode == "Shop") and "STORE" or "MY COSMETICS" end
        RenderChips()
        RenderSide()
        RenderGrid()
    end
    backBtn.Button.MouseButton1Click:Connect(function()
        click(); category, openBundle, selected = "Home", nil, nil; CosmeticsMenu._render()
    end)
    allBtn.Button.MouseButton1Click:Connect(function()
        click(); lockerAll = not lockerAll; selected = nil; CosmeticsMenu._render()
    end)

    do
        local token = 0
        search:GetPropertyChangedSignal("Text"):Connect(function()
            token += 1
            local t = token
            task.delay(0.2, function() if t == token and panel.Visible then selected = nil; RenderGrid() end end)
        end)
    end
    shopTab.Button.MouseButton1Click:Connect(function()
        click(); mode = "Shop"; category = "Home"; openBundle = nil; selected = nil; CosmeticsMenu._render()
    end)
    lockTab.Button.MouseButton1Click:Connect(function()
        click(); mode = "Locker"; category = "WeaponSkin"; openBundle = nil; selected = nil; CosmeticsMenu._render()
    end)

    RunService.RenderStepped:Connect(function(dt)
        if not panel.Visible then return end
        local now = os.clock()
        for _, p in ipairs(live) do pcall(p.Step, now, dt) end
        if detailLive then pcall(detailLive.Step, now, dt) end
    end)

    local api = { Frame = panel }
    function api.Open(m, cat, itemId)
        cwMenu.Close()
        mode = (m == "Locker") and "Locker" or "Shop"
        openBundle = nil
        selected = (cat and itemId) and Cosmetics.Find(cat, itemId) or nil
        if mode == "Shop" then
            if cat == "Bundle" and selected then category, openBundle = "Bundle", selected
            elseif cat and cat ~= "Featured" and cat ~= "Bundle" then category = CHIP_OF_CAT[cat] or cat
            else category = "Home" end
        else
            category = (cat and cat ~= "Featured" and cat ~= "Home") and cat or "WeaponSkin"
        end
        Fit()
        CosmeticsMenu._render()
    end
    -- re-render after the server syncs your state (bought / equipped something), keeping the scroll + selection
    function api.Refresh()
        if not panel.Visible then return end
        cwMenu.Refresh()
        local pos = grid.CanvasPosition
        CosmeticsMenu._render()
        grid.CanvasPosition = pos
    end
    function api.Selected() return selected, mode, category end
    return api
end

return CosmeticsMenu
