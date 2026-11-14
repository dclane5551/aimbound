--!nocheck
-- The Challenges window (client UI, UIStyle look), key L. Four tabs:
--   DAILY       today's fixed 5-floor Daily Challenge, your best time, the day's top 10
--   AIM TRIALS  Kovaak-style scenarios: personal best, rank, next rank, START, today's top 5
--   MASTERY     kills and mastery level for every gun
--   local menu = ChallengesMenu.Build(parentFolder, {
--       GetState = fn() -> clientState, PlayClick = fn(), OnClose = fn(), Toast = fn(text),
--       StartTrial = fn(scenarioId), StartDaily = fn(),
--   })  -> { Frame, Refresh(), ShowTab(name) }
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local ItemData = require(script.Parent:WaitForChild("ItemData"))
local Progression = require(script.Parent:WaitForChild("Progression"))
local DailyChallenge = require(script.Parent:WaitForChild("DailyChallenge"))
local AimTrials = require(script.Parent:WaitForChild("AimTrials"))
local FloorMods = require(script.Parent:WaitForChild("FloorMods"))
local DungeonEvents = require(script.Parent:WaitForChild("DungeonEvents"))
local Rifts = require(script.Parent:WaitForChild("Rifts"))
local Seasons = require(script.Parent:WaitForChild("Seasons"))
local LeaderboardView = require(script.Parent:WaitForChild("LeaderboardView"))
local BossTrials = require(script.Parent:WaitForChild("BossTrials"))
local AscensionTrials = require(script.Parent:WaitForChild("AscensionTrials"))
local Weekly = require(script.Parent:WaitForChild("Weekly")) -- (UPDATE 7 A5: the WEEKLY tab)
local MasteryRank = require(script.Parent:WaitForChild("MasteryRank")) -- (UPDATE 7 A3: the MASTERY tab's rank header)
local Calibration = require(script.Parent:WaitForChild("Calibration")) -- (UPDATE 7 B2: the gun cards' calibration)
local DailyLine = require(script.Parent:WaitForChild("DailyLine")) -- (UPDATE 7 B6: the LINE tab)
local SeasonGoals = require(script.Parent:WaitForChild("SeasonGoals")) -- (UPDATE 7 C8: the GOALS tab)

local ChallengesMenu = {}
local IS_STUDIO_TIERS = game:GetService("RunService"):IsStudio() -- (Studio tests can start any tier)
-- your party room (PartyService sets these): how many are in it, and whether you're its host
local function PartyInfo(): (number, boolean)
    local lp = game:GetService("Players").LocalPlayer
    return tonumber(lp and lp:GetAttribute("PartySize")) or 0, lp ~= nil and lp:GetAttribute("PartyHost") == true
end
local C = UIStyle.Colors
local New, Text = UIStyle.New, UIStyle.Text
-- (UI CLEAN R-A, AimRngShared/MenuKit: every card is the target's raised card -- no box stroke; a card's state colour (chosen /
-- done / ready / premium) is ONE 2 px line along its bottom. Tabs are words. Gold stays on prices only.)
local MenuKit = require(script.Parent:WaitForChild("MenuKit"))
local function KCard(parent: Instance, props: any, accent: Color3?): Frame
    return MenuKit.Card(UIStyle.Card(parent, props, nil), accent) :: Frame
end

local W, H = 1040, 660
local TABS = {
    { Id = "Season", Title = "SEASON", Color = C.Pink },
    { Id = "Weekly", Title = "WEEKLY", Color = Color3.fromRGB(255, 196, 70) }, -- (UPDATE 7: weekly boss + bounty board)
    { Id = "Bosses", Title = "BOSSES", Color = Color3.fromRGB(255, 196, 70) },
    { Id = "Ascension", Title = "PROVING", Color = Color3.fromRGB(60, 240, 210) },
    -- (RIFTS tab removed 0.58: rifts open from your hideout's MAP ROOM -- HideoutClient map device)
    { Id = "Daily", Title = "DAILY", Color = C.Orange },
    { Id = "Trials", Title = "AIM TRIALS", Color = C.Blue },
    { Id = "Line", Title = "GAUNTLET RUN", Color = C.Red }, -- (UPDATE 7 B6)
    { Id = "Goals", Title = "FEATS", Color = C.Pink }, -- (UPDATE 7 C8)
    { Id = "Mastery", Title = "MASTERY", Color = C.Green },
}
local BIOME_NAMES = { Fire = "MOLTEN", Ice = "CRYO", Cyber = "CYBER", Void = "VOID", Storm = "STORMSPIRE", Dream = "DREAMSCAPE", Flats = "NEON FLATS" }
local BIOME_COLORS = { Fire = Color3.fromRGB(255, 120, 50), Ice = Color3.fromRGB(110, 210, 255), Cyber = Color3.fromRGB(60, 230, 170),
    Void = Color3.fromRGB(180, 100, 255), Storm = Color3.fromRGB(160, 215, 255),
    Dream = Color3.fromRGB(255, 150, 230), Flats = Color3.fromRGB(255, 140, 80) }
do -- (0.87 WORLDS)
    local ok, WB = pcall(require, script.Parent:WaitForChild("WorldBiomes"))
    if ok then for id, t in pairs(WB.Titles) do BIOME_NAMES[id] = t.Name; BIOME_COLORS[id] = t.Color end end
end

local function Pct(v: number): string
    local x = v * 100
    if math.abs(x - math.round(x)) < 0.05 then return tostring(math.round(x)) .. "%" end
    return string.format("%.1f%%", x)
end

function ChallengesMenu.Build(parent: Instance, hooks: any)
    local click = hooks.PlayClick or function() end
    local toast = hooks.Toast or function() end
    -- hooks.Only = "Season": the standalone SEASON JOURNEY window (the season stand) -- just the season track, no tabs.
    -- Otherwise the CHALLENGES window, which no longer carries the season.
    local only = hooks.Only
    local tabs = {}
    for _, t in ipairs(TABS) do
        if (only and t.Id == only) or (not only and t.Id ~= "Season") then table.insert(tabs, t) end
    end
    local root = UIStyle.Panel(parent, { Name = only and (only .. "Menu") or "ChallengesMenu", Size = UDim2.fromOffset(W, H), Accent = only and C.Pink or C.Orange })
    local fit = New("UIScale", { Name = "FitScale", Parent = root })
    -- (2026-10-13 phones: as tall as the screen -- the SEASON track scrolls and its reward panel splits its height; on
    -- the Challenges tabs the lists scroll and every detail card scrolls inside itself, UIStyle.PhoneScrollCard)
    root:SetAttribute("PhoneMinH", 300)
    local function Fit()
        UIStyle.Fit(root, fit, W, H, 40) -- (phones: fit the width + swipe to scroll)
    end
    Fit()
    if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Fit) end
    local title, sub = "CHALLENGES", "The Week's Quarry and bounties, Boss Trials, the Proving, Daily Challenge, Aim Trials and weapon mastery."
    if only == "Season" then title, sub = "SEASON PASS", "50 tiers, a reward on every tier, and a premium row that pays back BOUND points, more loot and the season's arms + knife at tier 50." end
    UIStyle.TitleBar(root, title, only and C.Pink or C.Orange, sub, function()
        click()
        if hooks.OnClose then hooks.OnClose() end
    end)

    local current = tabs[1].Id
    local data: any = nil -- GetChallengeData result
    local tabButtons = {}
    local top = only and 76 or 128 -- (no tab row in a single-section window)
    local body = New("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, top), Size = UDim2.new(1, -32, 1, -top - 16), Parent = root })
    local Render: () -> ()
    local SeasonShowcase: (boolean, number, boolean) -> ()

    local tabW = math.min(136, math.floor((W - 32 - (#tabs - 1) * 8) / math.max(1, #tabs))) -- (the row always fits)
    for i, t in ipairs(only and {} or tabs) do
        local b = UIStyle.Button(root, t.Title, C.Bg1, UDim2.fromOffset(tabW, 40), UDim2.fromOffset(16 + (i - 1) * (tabW + 8), 78), "Tab" .. t.Id)
        MenuKit.WordTab(b) -- (UI CLEAN R-A: words, the selected one Text + a 2 px underline)
        b.Button.MouseButton1Click:Connect(function()
            click()
            current = t.Id
            Render()
        end)
        tabButtons[t.Id] = b
    end

    local function Clear()
        for _, c in ipairs(body:GetChildren()) do c:Destroy() end
    end
    local function Card(props: any, accent: Color3?): Frame
        props.Parent = body
        return KCard(body, props, accent)
    end
    local function Row(parentFrame: Instance, y: number, left: string, right: string, color: Color3?, size: number?)
        Text({ Position = UDim2.fromOffset(14, y), Size = UDim2.new(0.62, -14, 0, 22), Text = left, Font = UIStyle.BodyFont, TextSize = size or 14, TextColor3 = color or C.Text, TextTruncate = Enum.TextTruncate.AtEnd, Parent = parentFrame })
        Text({ Position = UDim2.new(0.62, 0, 0, y), Size = UDim2.new(0.38, -14, 0, 22), Text = right, TextSize = size or 15, TextColor3 = color or C.Text, TextXAlignment = Enum.TextXAlignment.Right, Parent = parentFrame })
    end

    -- hover card for the boss card's exotic chips (name, slot / class, effect); nil = hide
    local exoTip = New("Frame", { Name = "ExoTip", BackgroundColor3 = Color3.fromRGB(16, 17, 20), Size = UDim2.fromOffset(320, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false, ZIndex = 50, Parent = root }, {
        UIStyle.Corner(2), New("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
        New("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    local tipStroke = UIStyle.Stroke(C.Gold, 2)
    tipStroke.Parent = exoTip
    local tipName = Text({ TextSize = 17, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, ZIndex = 51, Parent = exoTip })
    local tipSub = Text({ Font = UIStyle.BodyFont, TextSize = 11, TextColor3 = C.Sub, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2, ZIndex = 51, Parent = exoTip })
    local tipBody = Text({ Font = UIStyle.BodyFont, TextSize = 13, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, ZIndex = 51, Parent = exoTip })
    local function ShowExoTip(anchor: GuiObject?, name: string?, sub: string?, body: string?, col: Color3?)
        if not anchor then exoTip.Visible = false; return end
        local k = root.AbsoluteSize.X / math.max(1, root.Size.X.Offset) -- (window UIScale)
        local x = (anchor.AbsolutePosition.X - root.AbsolutePosition.X) / k
        local yy = (anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y - root.AbsolutePosition.Y) / k + 6
        exoTip.Position = UDim2.fromOffset(math.min(x, root.Size.X.Offset - 330), yy)
        tipName.Text, tipName.TextColor3 = name or "", col or C.Gold
        tipSub.Text, tipBody.Text = sub or "", body or ""
        tipStroke.Color = col or C.Gold
        exoTip.Visible = true
    end

    -- ===================== SEASON =====================
    -- SEASON SHOWCASE (season pass rework 2026-10-13, owner: "good cosmetics at the final level"): a panel left of the tier
    -- track with the tier-50 premium arms + knife turning in live 3D previews (ShopShowcase loops), so players see what
    -- they grind for. An empty Seasons.PremiumSkins[50] shows a "revealed soon" card.
    local SHOW_W = 290
    local seasonShows = {}
    local okSC, ShopShowcase = pcall(require, script.Parent:WaitForChild("ShopShowcase"))
    local okCo, Cosmetics = pcall(require, script.Parent:WaitForChild("Cosmetics"))
    game:GetService("RunService").RenderStepped:Connect(function()
        if #seasonShows == 0 or not root.Visible then return end
        local now = os.clock()
        for i = #seasonShows, 1, -1 do
            local sh = seasonShows[i]
            if not (sh.Frame and sh.Frame.Parent) then table.remove(seasonShows, i)
            else pcall(sh.Step, now) end
        end
    end)
    SeasonShowcase = function(premium: boolean, tier: number, got: boolean)
        table.clear(seasonShows)
        local GOLD = C.Text -- (UI CLEAN R-A: heads in Text; gold is for currency)
        local card = KCard(body, { Position = UDim2.fromOffset(0, 104), Size = UDim2.new(0, SHOW_W, 1, -104) }, GOLD)
        Text({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 26), Text = "TIER 50 REWARD", TextSize = 22, Stroke = 2, TextColor3 = GOLD, Parent = card })
        Text({ Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 16), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub,
            Text = "Premium pass  •  season exclusive arms + knife", Parent = card })
        local refs = Seasons.FinalRefs()
        local glove, sleeve, knife
        for _, ref in ipairs(refs) do
            local cat, id = string.match(ref, "^(.-):(.*)$")
            local e = okCo and cat and Cosmetics.Find(cat, id)
            if e and cat == "Glove" then glove = e
            elseif e and cat == "Sleeve" then sleeve = e
            elseif e and cat == "MeleeSkin" then knife = e
            elseif e and cat == "Arms" then
                glove = glove or { Name = e.Name, Src = e.Src and e.Src.Glove }
                sleeve = sleeve or { Name = e.Name, Src = e.Src and e.Src.Sleeve }
            end
        end
        local stageH = 172
        -- (phones: the window is only as tall as the screen -- the stages share the card's height instead of 172 px each)
        local short = UIStyle.IsPhone() and root:GetAttribute("PhoneMinH") ~= nil
        local function Stage(y: number, h: number, label: string): Frame
            local pos, size = UDim2.fromOffset(10, y), UDim2.new(1, -20, 0, h)
            if short then
                if h > stageH then pos, size = UDim2.fromOffset(10, 54), UDim2.new(1, -20, 1, -116)
                elseif y > 54 then pos, size = UDim2.new(0, 10, 0.5, 0), UDim2.new(1, -20, 0.5, -62)
                else pos, size = UDim2.fromOffset(10, 54), UDim2.new(1, -20, 0.5, -62) end
            end
            local pv = New("Frame", { Position = pos, Size = size, BackgroundColor3 = Color3.fromRGB(20, 18, 26),
                BorderSizePixel = 0, ClipsDescendants = true, Parent = card }, { UIStyle.Corner(6), New("UIStroke", { Color = GOLD, Thickness = 1, Transparency = 0.55 }) })
            if label ~= "" then
                Text({ Position = UDim2.new(0, 8, 1, -22), Size = UDim2.new(1, -16, 0, 18), Text = label, TextSize = 14, Stroke = 1.5, TextColor3 = C.Text, ZIndex = 5, Parent = pv })
            end
            return pv
        end
        if (glove or sleeve) and okSC then
            local pv = Stage(54, stageH, string.upper((glove and glove.Name) or (sleeve and sleeve.Name) or "Season arms"))
            local ok, show = pcall(ShopShowcase.Arms, pv, { Src = { Glove = glove and glove.Src, Sleeve = sleeve and sleeve.Src } })
            if ok and show then show.Frame = pv; table.insert(seasonShows, show) end
        end
        if knife and okSC then
            local pv = Stage(54 + stageH + 8, stageH, string.upper(knife.Name or "Season knife"))
            local st = hooks.GetState and hooks.GetState() or nil
            local ok, show = pcall(ShopShowcase.Melee, pv, knife, st)
            if ok and show then show.Frame = pv; table.insert(seasonShows, show) end
        end
        if not (glove or sleeve or knife) then
            local pv = Stage(54, stageH * 2 + 8, "")
            Text({ Position = UDim2.fromScale(0, 0.34), Size = UDim2.new(1, 0, 0, 34), Text = "SEASON ARMS + KNIFE", TextSize = 24, Stroke = 2,
                TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, Parent = pv })
            Text({ Position = UDim2.new(0, 16, 0.34, 40), Size = UDim2.new(1, -32, 0, 40), Font = UIStyle.BodyFont, TextSize = 13, TextWrapped = true,
                TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Center, Text = "Revealed soon. A pair of arms and a knife you can only get here.", Parent = pv })
        end
        local reached = tier >= Seasons.TIERS
        Text({ Position = UDim2.new(0, 12, 1, -54), Size = UDim2.new(1, -24, 0, 20), TextSize = 15, Stroke = 1.5, TextColor3 = reached and C.Good or GOLD,
            Text = (got and "CLAIMED: it's yours") or (reached and (premium and "UNLOCKED: claim it!" or "Reached: get Premium to claim it")) or string.format("TIER %d / %d", tier, Seasons.TIERS), Parent = card })
        local payBack = Text({ Position = UDim2.new(0, 12, 1, -32), Size = UDim2.new(1, -24, 0, 26), Font = UIStyle.BodyFont, TextSize = 12, TextWrapped = true, TextColor3 = C.Sub,
            Text = premium and "Plus 700 BOUND points across the premium row." or "Premium also pays back 700 BOUND points, more than its price.", Parent = card })
        do -- (PLAYTEST 2026-10-31: on a phone the narrow card cut this line after 'points,' -- it steps down to fit)
            local function Fit() -- (from 12 down, only once it has a real size: a 0-size label never fits)
                if payBack.AbsoluteSize.X < 2 then return end
                payBack.TextSize = 12
                while not payBack.TextFits and payBack.TextSize > 9 do payBack.TextSize -= 1 end
            end
            payBack:GetPropertyChangedSignal("AbsoluteSize"):Connect(Fit)
            payBack:GetPropertyChangedSignal("FontFace"):Connect(Fit)
            task.defer(Fit)
        end
    end
    local function RenderSeason(state: any)
        local s = state.Season
        local cur = type(s) == "table" and s.Id == Seasons.Current.Id
        local xp = cur and (s.XP or 0) or 0
        local claimed = (cur and type(s.Claimed) == "table") and s.Claimed or {}
        local claimedP = (cur and type(s.ClaimedP) == "table") and s.ClaimedP or {}
        local premium = cur and s.Premium == true
        local tier = Seasons.TierOf(xp)
        local PREM = Color3.fromRGB(255, 196, 70)
        local head = Card({ Size = UDim2.new(1, 0, 0, 92) }, nil)
        Text({ Position = UDim2.fromOffset(16, 6), Size = UDim2.new(0.6, 0, 0, 34), Text = string.upper(Seasons.Current.Name), TextSize = 26, Stroke = 2.5, TextColor3 = C.Text, Parent = head })
        local left = math.max(0, Seasons.Current.Ends - os.time())
        Text({ Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -420, 0, 20), Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = premium and PREM or C.Sub, TextWrapped = true,
            Text = string.format("Tier %d / %d   •   ends in %dd %dh   •   %s", tier, Seasons.TIERS, left // 86400, (left % 86400) // 3600,
                premium and "PREMIUM PASS ACTIVE: +25% Season XP and the premium row" or "every kill, floor, contract, daily, map and trial rank earns Season XP"), Parent = head })
        local bar = New("Frame", { Position = UDim2.fromOffset(16, 70), Size = UDim2.new(1, -640, 0, 4), BackgroundColor3 = C.Text, BackgroundTransparency = 0.86, BorderSizePixel = 0, Parent = head }) -- (UI CLEAN R-A: a 4 px line)
        local _, intoXP, costXP, into = Seasons.Progress(xp) -- (tiers cost more as you go: Seasons.TierCost)
        New("Frame", { Size = UDim2.new(into, 0, 1, 0), BackgroundColor3 = C.Text, BorderSizePixel = 0, Parent = bar })
        local unclaimed = 0
        for t = 1, tier do
            if not claimed[tostring(t)] then unclaimed += 1 end
            if premium and not claimedP[tostring(t)] then unclaimed += 1 end
        end
        -- the premium pass button (or a badge once owned)
        -- (UI CLEAN audit: ONE primary -- CLAIM while there is something to claim, else GET PREMIUM; the other a quiet outline)
        local buy = UIStyle.Button(head, premium and "PREMIUM OWNED" or string.format("GET PREMIUM  %d BOUND", Seasons.Premium.Price), (unclaimed > 0) and C.Steel or C.Accent, UDim2.fromOffset(200, 56), UDim2.new(1, -404, 0.5, -28))
        buy.SetEnabled(not premium)
        buy.Button.MouseButton1Click:Connect(function()
            if not buy.Button.Active then return end
            click()
            -- (2026-10-20: the pass costs BOUND points, behind the popup that shows how many you need)
            require(script.Parent:WaitForChild("BoundShop")).Confirm({ Name = "the premium season pass", Price = Seasons.Premium.Price,
                Desc = "+25% Season XP and the premium reward row (it pays back more BOUND points than it costs).",
                OnBuy = function() return Remotes.GetFunction("BoundBuy"):InvokeServer("SeasonPremium") end,
                -- (2026-10-20 owner: also straight for Robux -- SeasonAction "BuyPremium" prompts Seasons.Premium.ProductId)
                Robux = (Seasons.Premium.ProductId or 0) ~= 0 and { Price = Seasons.Premium.RobuxPrice or Seasons.Premium.Price, OnBuy = function()
                    local ok, msg = Remotes.GetFunction("SeasonAction"):InvokeServer("BuyPremium")
                    if msg and msg ~= "Prompted" then toast(msg) end
                    return ok, msg
                end } or nil })
        end)
        local claimBtn = UIStyle.Button(head, unclaimed > 0 and ("CLAIM " .. unclaimed) or (tier > 0 and "ALL CLAIMED" or "NOTHING TO CLAIM"), (unclaimed > 0) and C.Accent or C.Steel, UDim2.fromOffset(180, 56), UDim2.new(1, -194, 0.5, -28))
        claimBtn.SetEnabled(unclaimed > 0)
        claimBtn.Button.MouseButton1Click:Connect(function()
            if not claimBtn.Button.Active then return end
            click()
            local ok, msg = Remotes.GetFunction("ClaimSeason"):InvokeServer()
            if msg then toast(msg) end
        end)
        if tier < Seasons.TIERS then
            Text({ Position = UDim2.new(1, -404 - 216, 0, 63), Size = UDim2.fromOffset(208, 20), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub,
                TextXAlignment = Enum.TextXAlignment.Right, Text = string.format("%s / %s XP to tier %d", ItemData.FormatNumber(intoXP), ItemData.FormatNumber(costXP), tier + 1), Parent = head })
        end
        -- THE FINAL REWARD (premium, tier 50) on show from the start: the season's arms + knife turning in a big preview
        SeasonShowcase(premium, tier, claimedP[tostring(Seasons.TIERS)] == true)
        local scroll = New("ScrollingFrame", { Position = UDim2.fromOffset(SHOW_W + 12, 104), Size = UDim2.new(1, -(SHOW_W + 12), 1, -104), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 8, ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), Parent = body })
        New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
        -- every tier: the FREE reward on top, the PREMIUM reward underneath (gold; locked until the pass is owned)
        for t = 1, Seasons.TIERS do
            local r, pr = Seasons.Reward(t), Seasons.PremiumReward(t)
            local big = r.Gem or r.Title or r.Sigil or r.BP
            local reached = t <= tier
            local isClaimed = claimed[tostring(t)] == true
            local accent = (reached and C.Text) or nil -- (UI CLEAN R-A: a reached tier = the off-white line; big rewards read from their words)
            local card = KCard(scroll, { LayoutOrder = t, Size = UDim2.new(0, 160, 1, -14) }, accent)
            Text({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 28), Text = "TIER " .. t, TextSize = 20, TextColor3 = reached and C.Text or C.Sub, Parent = card })
            -- free half
            Text({ Position = UDim2.fromOffset(10, 34), Size = UDim2.new(1, -20, 0, 14), Text = "FREE", TextSize = 12, TextColor3 = C.Sub, Parent = card })
            Text({ Position = UDim2.fromOffset(10, 50), Size = UDim2.new(1, -20, 0.5, -84), Text = r.Text, Font = UIStyle.BodyFont, TextSize = 13, TextWrapped = true,
                TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.Text, Parent = card })
            Text({ Position = UDim2.new(0, 10, 0.5, -30), Size = UDim2.new(1, -20, 0, 22), Text = isClaimed and "CLAIMED" or (reached and "READY" or "LOCKED"), TextSize = 15, Stroke = 1.5,
                TextColor3 = isClaimed and C.Good or (reached and C.Text or C.Muted), Parent = card })
            -- premium half
            local pClaimed = claimedP[tostring(t)] == true
            local skin = pr.Cosmetics or pr.SkinSlot
            -- (UI CLEAN R-A: the premium half = a faint gold tint on the card with one 2 px gold line on top -- no rounded gold box)
            local pane = New("Frame", { Position = UDim2.new(0, 0, 0.5, -4), Size = UDim2.new(1, 0, 0.5, 4), BackgroundColor3 = PREM, BackgroundTransparency = premium and 0.9 or 0.95,
                BorderSizePixel = 0, Parent = card }, { New("Frame", { BackgroundColor3 = PREM, BackgroundTransparency = premium and 0 or 0.5, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 2) }) })
            Text({ Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 14), Text = premium and "PREMIUM" or "PREMIUM  •  LOCKED", TextSize = 12, TextColor3 = PREM, Parent = pane })
            Text({ Position = UDim2.fromOffset(6, 20), Size = UDim2.new(1, -12, 1, -50), Text = pr.Text, Font = UIStyle.BodyFont, TextSize = 13, TextWrapped = true,
                TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = skin and Color3.fromRGB(255, 150, 220) or (premium and C.Text or C.Sub), Parent = pane })
            Text({ Position = UDim2.new(0, 6, 1, -26), Size = UDim2.new(1, -12, 0, 22), TextSize = 15, Stroke = 1.5,
                Text = (not premium and "PREMIUM") or (pClaimed and "CLAIMED") or (reached and "READY") or "LOCKED",
                TextColor3 = (not premium and C.Muted) or (pClaimed and C.Good) or (reached and PREM) or C.Muted, Parent = pane })
        end
    end

    -- ===================== BOSS TRIALS (BossTrials) =====================
    local selBoss = BossTrials.Bosses[1].Id
    local myRoom: any = nil -- (BOSS ROOMS: your room snapshot, PartyUpdate)
    local bossScroll = Vector2.zero
    local bossRooms: { any } = {} -- (rooms you can join; PartyRequest List)
    local function RefreshBossRooms()
        task.spawn(function()
            local ok, good, list = pcall(function() return Remotes.GetFunction("PartyRequest"):InvokeServer("List") end)
            bossRooms = (ok and good and type(list) == "table") and list or {}
            if root.Visible and current == "Bosses" then Render() end
        end)
    end
    Remotes.GetEvent("PartyUpdate").OnClientEvent:Connect(function(snap)
        myRoom = snap
        if root.Visible and current == "Bosses" then Render() end
    end)
    Remotes.GetEvent("PartyRoomsChanged").OnClientEvent:Connect(function()
        if root.Visible and current == "Bosses" then RefreshBossRooms() end
    end)
    local selTier: { [string]: number } = {}
    local function TimeText(sec: number?): string
        if not sec then return "--" end
        return string.format("%d:%04.1f", math.floor(sec / 60), sec % 60)
    end
    local function RenderBosses(state: any)
        local GOLD = C.Text -- (UI CLEAN R-A: heads in Text; gold is for currency)
        -- left: the trial bosses (a scrolling list since the 0.52 bosses)
        local left = New("ScrollingFrame", { Size = UDim2.new(0.56, -8, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = body })
        -- (keep the scroll across re-renders: picking a boss further down jumped the list back to the top)
        task.defer(function() if left.Parent then left.CanvasPosition = bossScroll end end)
        left:GetPropertyChangedSignal("CanvasPosition"):Connect(function() bossScroll = left.CanvasPosition end)
        New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
        for i, b in ipairs(BossTrials.Bosses) do
            local prog = BossTrials.Progress(state, b.Id)
            local chosen = b.Id == selBoss
            local card = KCard(left, { LayoutOrder = i, Size = UDim2.new(1, -10, 0, 118) }, chosen and b.Color or nil)
            Text({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -150, 0, 30), Text = b.Name, TextSize = 24, Stroke = 2, TextColor3 = b.Color, Parent = card })
            Text({ Position = UDim2.fromOffset(16, 38), Size = UDim2.new(1, -150, 0, 34), Text = b.Blurb, Font = UIStyle.BodyFont, TextSize = 13, TextWrapped = true,
                TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.Sub, Parent = card })
            -- tier pips
            for t = 1, BossTrials.MAX_TIER do
                local done = prog.Best >= t
                local pip = New("Frame", { Position = UDim2.new(0, 16 + (t - 1) * 34, 1, -38), Size = UDim2.fromOffset(30, 26), BorderSizePixel = 0,
                    BackgroundColor3 = done and b.Color or C.CardDark, Parent = card }, { UIStyle.Corner(6) })
                Text({ Size = UDim2.fromScale(1, 1), Text = BossTrials.Tiers[t].Name, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center,
                    TextColor3 = done and Color3.fromRGB(20, 20, 26) or C.Sub, Parent = pip })
            end
            Text({ Position = UDim2.new(0, 16, 0, 72), Size = UDim2.new(1, -170, 0, 16), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub,
                Text = (b.Major and "MAJOR BOSS  •  " or "") .. (prog.Best > 0 and ("best: tier " .. BossTrials.Tiers[prog.Best].Name) or "not cleared yet"), Parent = card })
            local pick = UIStyle.Button(card, chosen and "SELECTED" or "SELECT", chosen and UIStyle.Darken(b.Color, 0.2) or C.Blue, UDim2.fromOffset(120, 42), UDim2.new(1, -134, 0.5, -21))
            pick.Button.MouseButton1Click:Connect(function()
                click()
                selBoss = b.Id
                Render()
            end)
        end
        -- right: the chosen boss -- its mechanics, tier picker, rewards, start + leaderboard
        local b = BossTrials.ById[selBoss]
        local prog = BossTrials.Progress(state, b.Id)
        local tier = selTier[b.Id] or math.min(BossTrials.MAX_TIER, prog.Best + 1)
        selTier[b.Id] = tier
        local right = Card({ Position = UDim2.new(0.56, 8, 0, 0), Size = UDim2.new(0.44, -8, 1, 0) }, b.Color)
        Text({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 30), Text = "HOW TO BEAT IT", TextSize = 20, Stroke = 2, TextColor3 = b.Color, Parent = right })
        local y = 42
        for _, m in ipairs(b.Mechanics) do
            Text({ Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 44), Text = "•  " .. m, Font = UIStyle.BodyFont, TextSize = 12, TextWrapped = true,
                TextYAlignment = Enum.TextYAlignment.Top, Parent = right })
            y += 44
        end
        -- tier picker
        Text({ Position = UDim2.fromOffset(16, y + 2), Size = UDim2.new(1, -32, 0, 22), Text = "TIER", TextSize = 16, TextColor3 = C.Sub, Parent = right })
        for t = 1, BossTrials.MAX_TIER do
            local open = BossTrials.Unlocked(state, b.Id, t)
            -- (Update 5: a locked tier keeps its numeral, dimmed by SetEnabled -- "LOCKED" squeezed into 34 px wrapped)
            local tb = UIStyle.Button(right, BossTrials.Tiers[t].Name, (t == tier) and b.Color or C.Bg2, UDim2.fromOffset(34, 32), UDim2.fromOffset(60 + (t - 1) * 37, y - 4))
            tb.Label.TextSize = 14
            tb.SetEnabled(open or IS_STUDIO_TIERS)
            tb.Button.MouseButton1Click:Connect(function()
                if not tb.Button.Active then return end
                click()
                selTier[b.Id] = t
                Render()
            end)
        end
        y += 42
        local td = BossTrials.Tiers[tier]
        local rw = BossTrials.Reward(tier, prog.Best < tier, b.Major)
        Row(right, y, "Difficulty", string.upper(td.Difficulty) .. "  •  boss HP x" .. td.Hp, nil, 13); y += 24
        Row(right, y, "Your best time (tier " .. td.Name .. ")", TimeText(prog.Times[tostring(tier)]), GOLD, 13); y += 24
        Row(right, y, (prog.Best < tier) and "First clear pays" or "Each clear pays", rw.Gold .. " gold  •  " .. rw.Prism .. " Prism" .. (rw.Gem and ("  •  " .. rw.Gem .. " gem") or ""), nil, 13); y += 24
        -- EXOTIC DROPS (0.93, owner: "Boss drops still say the old cosmetics we used, replace it with the exotic (and when
        -- hovered show what the exotic is)"): one chip per exotic in the boss's pool; hovering shows its slot, class and effect
        do
            local okI, IDat = pcall(require, script.Parent:WaitForChild("ItemData"))
            local pool = BossTrials.EXOTIC_POOL and BossTrials.EXOTIC_POOL[b.Id] or {}
            local ch = BossTrials.ExoticChance(tier, prog.Best < tier) -- (0.86: the real chance x your tier falloff)
            if ch < 1 and okI and hooks.GetState then ch *= IDat.ExoticFalloff(hooks.GetState() or {}, BossTrials.Tiers[tier] and BossTrials.Tiers[tier].Difficulty) end
            local EXO = Color3.fromRGB(255, 140, 40)
            if okI and IDat.EXOTIC_COLOR then EXO = IDat.EXOTIC_COLOR end
            Row(right, y, "Relic drop (hover one)", string.format("%s%% a clear", (ch >= 1) and "100" or string.format("%.2g", ch * 100)), EXO, 13); y += 22
            local strip = New("Frame", { Name = "ExoticChips", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -28, 0, 26), Parent = right }, {
                New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
            })
            for i, id in ipairs(pool) do
                local ex = okI and IDat.Exotics[id]
                local chip = New("TextButton", { Name = "Exo_" .. id, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(46, 30, 18),
                    Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i, Parent = strip }, {
                    UIStyle.Corner(2), New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
                })
                UIStyle.Stroke(EXO, 1).Parent = chip
                Text({ Text = "◆ " .. (ex and ex.Name or id), TextSize = 13, TextColor3 = EXO, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, Parent = chip })
                if ex then
                    local what
                    if ex.Kind == "Weapon" then
                        local base = IDat.BaseWeapons[ex.Base]
                        what = (base and IDat.WeaponTypeName and IDat.WeaponTypeName(base, ex.Base)) or (base and base.Name) or "Weapon"
                    else
                        what = ({ Helmet = "Helmet", ChestPiece = "Chest", Gloves = "Gloves", Leggings = "Legs", Boots = "Boots", Necklace = "Necklace", Ring = "Ring" })[ex.Slot] or "Gear"
                    end
                    UIStyle.HoverTip(chip, function() ShowExoTip(chip, ex.Name, string.format("RELIC %s  •  %s", string.upper(what), ex.Class or "Any class"), ex.Desc or "", EXO) end,
                        function() ShowExoTip(nil) end) -- (a tap shows it on phones)
                end
            end
            y += 32
        end
        -- (ascendancy points come from the Trial of Ascension now -- the ASCENSION tab)
        -- SOLO / WITH PARTY (owner 2026-10-05: "challenge boss fights dont have multiplayer option, but when you start one it
        -- brings all players with you"): you choose -- only the room's host can take the party along
        local party, isHost = PartyInfo()
        Row(right, y, "With a party", (party >= 2) and string.format("%d in your room  •  boss HP x%d", party, party)
            or "open a room below  •  boss HP x players", Color3.fromRGB(160, 220, 255), 13); y += 26
        -- BOSS ROOMS (owner 0.52: "You should be able to create a party at the bosses too"): open a Friends / Public room
        -- for THIS boss + tier, or join someone else's; the host starts it with WITH PARTY
        if myRoom then
            local tr = myRoom.Trial and BossTrials.ById[myRoom.Trial.Id]
            Text({ Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -150, 0, 30), Font = UIStyle.BodyFont, TextSize = 12, TextWrapped = true, TextColor3 = C.Sub,
                Text = string.format("In %s room (%d/%d)%s", myRoom.HostName .. "'s", #myRoom.Members, myRoom.Max,
                    tr and ("  •  " .. tr.Name .. " tier " .. BossTrials.Tiers[myRoom.Trial.Tier].Name) or ""), Parent = right })
            local lv = UIStyle.Button(right, "LEAVE ROOM", C.Red, UDim2.fromOffset(120, 30), UDim2.new(1, -134, 0, y))
            lv.Label.TextSize = 12
            lv.Button.MouseButton1Click:Connect(function()
                click()
                task.spawn(function() Remotes.GetFunction("PartyRequest"):InvokeServer("Leave") end)
            end)
            y += 36
        else
            for k, privacy in ipairs({ "Friends", "Public" }) do
                local ob = UIStyle.Button(right, "OPEN " .. string.upper(privacy) .. " ROOM", (privacy == "Friends") and C.Green or C.Orange,
                    UDim2.new(0.5, -20, 0, 30), UDim2.new((k - 1) * 0.5, 14 + (k - 1) * 2, 0, y))
                ob.Label.TextSize = 12
                ob.SetEnabled(BossTrials.Unlocked(state, b.Id, tier) or IS_STUDIO_TIERS)
                ob.Button.MouseButton1Click:Connect(function()
                    if not ob.Button.Active then return end
                    click()
                    task.spawn(function()
                        local ok, res = Remotes.GetFunction("PartyRequest"):InvokeServer("Create", { Privacy = privacy, Trial = { Id = b.Id, Tier = tier } })
                        if not ok and type(res) == "string" then toast(res) end
                    end)
                end)
            end
            y += 36
            local shown = 0
            for _, r in ipairs(bossRooms) do
                if r.Trial and r.Trial.Id == b.Id and shown < 2 then
                    shown += 1
                    Text({ Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -120, 0, 28), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Text,
                        Text = string.format("%s's room  •  tier %s  •  %d/%d", r.HostName, BossTrials.Tiers[r.Trial.Tier].Name, #r.Members, r.Max), Parent = right })
                    local jb = UIStyle.Button(right, "JOIN", C.Green, UDim2.fromOffset(80, 26), UDim2.new(1, -94, 0, y + 1))
                    jb.Label.TextSize = 12
                    jb.SetEnabled(r.State == "Lobby" and #r.Members < r.Max)
                    jb.Button.MouseButton1Click:Connect(function()
                        if not jb.Button.Active then return end
                        click()
                        task.spawn(function()
                            local ok, res = Remotes.GetFunction("PartyRequest"):InvokeServer("Join", r.Id)
                            if not ok and type(res) == "string" then toast(res) end
                        end)
                    end)
                    y += 30
                end
            end
        end
        local canStart = BossTrials.Unlocked(state, b.Id, tier) or IS_STUDIO_TIERS
        local solo = UIStyle.Button(right, "SOLO  •  TIER " .. td.Name, b.Color, UDim2.new(0.3, -16, 0, 50), UDim2.new(0, 14, 1, -62))
        solo.Label.TextSize = 15
        solo.SetEnabled(canStart)
        solo.Button.MouseButton1Click:Connect(function()
            if not solo.Button.Active then return end
            click()
            if hooks.StartBossTrial then hooks.StartBossTrial(b.Id, tier, "Solo") end
        end)
        local withParty = UIStyle.Button(right, (party >= 2) and ("WITH PARTY (" .. party .. ")") or "WITH PARTY", Color3.fromRGB(90, 160, 230),
            UDim2.new(0.28, -12, 0, 50), UDim2.new(0.3, 4, 1, -62))
        withParty.Label.TextSize = 14
        withParty.SetEnabled(canStart and party >= 2 and isHost)
        withParty.Button.MouseButton1Click:Connect(function()
            if not withParty.Button.Active then return end
            click()
            if hooks.StartBossTrial then hooks.StartBossTrial(b.Id, tier, "Party") end
        end)
        local ids = {}
        for t = 1, BossTrials.MAX_TIER do table.insert(ids, BossTrials.Board(b.Id, t)) end
        LeaderboardView.Button(right, UDim2.new(0.42, -14, 0, 50), UDim2.new(0.58, 0, 1, -62), ids, function() return BossTrials.Board(b.Id, tier) end, click, "FASTEST CLEARS")
        UIStyle.ScrollCard(right, 68) -- (phones: the card scrolls above SOLO / WITH PARTY / FASTEST CLEARS)
    end

    -- ===================== TRIAL OF ASCENSION (AscensionTrials) =====================
    local function RenderAscension(state: any)
        local TEAL = AscensionTrials.Color
        local best = AscensionTrials.Best(state)
        -- (phones: the four tiers scroll at a fixed 110 px each instead of sharing a short window's height)
        local phone = UIStyle.IsPhone()
        local left = New(phone and "ScrollingFrame" or "Frame", { Size = UDim2.new(0.56, -8, 1, 0), BackgroundTransparency = 1, Parent = body })
        if phone then
            left.BorderSizePixel, left.ScrollBarThickness, left.CanvasSize, left.AutomaticCanvasSize = 0, 4, UDim2.new(), Enum.AutomaticSize.Y
        end
        New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
        for t, def in ipairs(AscensionTrials.Tiers) do
            if t > AscensionTrials.MAX_TIER then break end -- (LAUNCH CAP: tiers past the cap aren't shown)
            local done = best >= t
            local can, why = AscensionTrials.CanStart(state, t)
            local card = KCard(left, { LayoutOrder = t, Size = phone and UDim2.new(1, -8, 0, 110) or UDim2.new(1, 0, 0.25, -6) }, (done or can) and TEAL or nil)
            Text({ Position = UDim2.fromOffset(16, 6), Size = UDim2.new(1, -190, 0, 28), Text = "THE PROVING " .. def.Name, TextSize = 22, Stroke = 2,
                TextColor3 = (done or can) and TEAL or C.Sub, Parent = card })
            Text({ Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -190, 0, 18), Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub,
                Text = string.format("Level %d  •  %s  •  2 hard floors + %s", def.Level, string.upper(def.Difficulty), AscensionTrials.BOSS_NAME), Parent = card })
            Text({ Position = UDim2.fromOffset(16, 58), Size = UDim2.new(1, -190, 0, 20), TextSize = 15, Stroke = 1.5,
                Text = done and "CLEARED  •  +2 specialization points earned" or (can and "READY  •  first clear: +2 specialization points" or ("LOCKED  •  " .. tostring(why))),
                TextColor3 = done and C.Good or (can and Color3.fromRGB(255, 220, 140) or C.Off), Parent = card })
            local go = UIStyle.Button(card, done and "SOLO AGAIN" or "SOLO", TEAL, UDim2.fromOffset(120, 40), UDim2.new(1, -134, 0.5, -44))
            go.SetEnabled(can or IS_STUDIO_TIERS)
            go.Button.MouseButton1Click:Connect(function()
                if not go.Button.Active then return end
                click()
                if hooks.StartAscTrial then hooks.StartAscTrial(t, "Solo") end
            end)
            local party, isHost = PartyInfo()
            local gp = UIStyle.Button(card, (party >= 2) and ("PARTY (" .. party .. ")") or "PARTY", Color3.fromRGB(90, 160, 230), UDim2.fromOffset(120, 36), UDim2.new(1, -134, 0.5, 2))
            gp.Label.TextSize = 13
            gp.SetEnabled((can or IS_STUDIO_TIERS) and party >= 2 and isHost)
            gp.Button.MouseButton1Click:Connect(function()
                if not gp.Button.Active then return end
                click()
                if hooks.StartAscTrial then hooks.StartAscTrial(t, "Party") end
            end)
        end
        local right = Card({ Position = UDim2.new(0.56, 8, 0, 0), Size = UDim2.new(0.44, -8, 1, 0) }, TEAL)
        Text({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 30), Text = AscensionTrials.BOSS_NAME, TextSize = 22, Stroke = 2, TextColor3 = TEAL, Parent = right })
        local y = 44
        for _, m in ipairs(AscensionTrials.Mechanics) do
            Text({ Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 56), Text = "•  " .. m, Font = UIStyle.BodyFont, TextSize = 13, TextWrapped = true,
                TextYAlignment = Enum.TextYAlignment.Top, Parent = right })
            y += 58
        end
        y += 6
        local okA, AD = pcall(require, script.Parent:WaitForChild("AscendancyData"))
        if okA then
            Row(right, y, "Specialization points", string.format("%d / %d", AD.PointsFor(state), AD.MAX_POINTS), Color3.fromRGB(255, 220, 140), 14); y += 26
        end
        Row(right, y, "Each trial's first clear", "+2 points  •  a bounty", nil, 13); y += 24
        Row(right, y, "Every clear", "gold  •  Prism  •  an item near the tier's top rarity", nil, 13); y += 24
        Row(right, y, "With a party", "the room's host starts it  •  boss HP x players", Color3.fromRGB(160, 220, 255), 13); y += 24
        Text({ Position = UDim2.new(0, 16, 1, -64), Size = UDim2.new(1, -32, 0, 52), Font = UIStyle.BodyFont, TextSize = 12, TextWrapped = true, TextColor3 = C.Sub,
            Text = "Spend specialization points from the SPECIALIZATION button at the top of the passive tree. Each trial needs the one before it.", Parent = right })
        UIStyle.ScrollCard(right, 68)
    end

    -- ===================== RIFTS =====================
    local function RenderRifts(state: any)
        local sigils = table.clone(type(state.Sigils) == "table" and state.Sigils or {})
        table.sort(sigils, function(a, b) return a.Tier > b.Tier end)
        local left = Card({ Size = UDim2.new(0.6, -8, 1, 0) }, C.Red)
        Text({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 32), Text = "YOUR SIGILS  (" .. #sigils .. ")", TextSize = 24, Stroke = 2, TextColor3 = Color3.fromRGB(255, 120, 120), Parent = left })
        local scroll = New("ScrollingFrame", { Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 1, -54), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = left })
        New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
        if #sigils == 0 then
            Text({ Size = UDim2.new(1, -10, 0, 60), Text = "No sigils yet. Bosses drop them. Your first boss kill always does. Higher difficulties drop higher tiers.",
                Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Sub, TextWrapped = true, Parent = scroll })
        end
        for i, s in ipairs(sigils) do
            local row = New("Frame", { LayoutOrder = i, Size = UDim2.new(1, -10, 0, 86), BackgroundColor3 = C.CardDark, Parent = scroll }, { UIStyle.Corner(12) })
            local tierCol = Color3.fromRGB(255, 90, 90):Lerp(Color3.fromRGB(255, 210, 60), math.clamp(s.Tier / 15, 0, 1))
            Text({ Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(120, 34), Text = "TIER " .. s.Tier, TextSize = 26, Stroke = 2, TextColor3 = tierCol, Parent = row })
            local names = {}
            for _, id in ipairs(s.Mods or {}) do if FloorMods.Defs[id] then table.insert(names, FloorMods.Defs[id].Name) end end
            Text({ Position = UDim2.fromOffset(140, 8), Size = UDim2.new(1, -310, 0, 22), Text = table.concat(names, "  •  "), TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
            Text({ Position = UDim2.fromOffset(14, 44), Size = UDim2.new(1, -180, 0, 36), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, TextWrapped = true,
                Text = string.format("%s  •  %s  •  enemies +%d%% health  •  +%d%% rewards  •  %d:%02d time limit", "Mixed biomes", string.upper(Rifts.DifficultyFor(s.Tier)),
                    math.round((Rifts.HealthMult(s.Tier) - 1) * 100), math.round(Rifts.RewardBonus(s.Tier) * 100), Rifts.TimeLimit(s.Tier) // 60, Rifts.TimeLimit(s.Tier) % 60), Parent = row })
            local open = UIStyle.Button(row, "OPEN RIFT", C.Red, UDim2.fromOffset(150, 46), UDim2.new(1, -162, 0.5, -23))
            open.Button.MouseButton1Click:Connect(function()
                click()
                if hooks.StartRift then hooks.StartRift(s.Uid) end
            end)
        end
        local right = Card({ Position = UDim2.new(0.6, 8, 0, 0), Size = UDim2.new(0.4, -8, 1, 0) }, C.Gold)
        Text({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 30), Text = "HIGHEST TIERS", TextSize = 22, Stroke = 2, TextColor3 = C.Gold, Parent = right })
        Text({ Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 72), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, TextWrapped = true,
            Text = "A map is 5 floors; floor 5 is the guardian. Maps drop inside maps (the guardian, elites, map caches); beat the timer and the guardian's map often climbs a tier. Your best tier in time goes on the board." , Parent = right })
        Row(right, 116, "Your best (in time)", ((state.RiftBest or 0) > 0) and ("Tier " .. state.RiftBest) or "--", C.Gold, 16)
        local rows = data and data.RiftBoard or {}
        for i, r in ipairs(rows) do
            Row(right, 148 + (i - 1) * 28, string.format("%d.  %s", i, r.Name or "?"), "Tier " .. tostring(r.Value), (i == 1) and C.Gold or C.Text, 14)
        end
        if #rows == 0 then Row(right, 148, data and "Nobody yet" or "Loading...", "", C.Sub, 13) end
        LeaderboardView.Button(right, UDim2.new(1, -28, 0, 46), UDim2.new(0, 14, 1, -58), { "RiftWeekly", "RiftHighest" }, nil, click)
    end

    -- ===================== WEEKLY (UPDATE 7 A5, Weekly module) =====================
    local function RenderWeekly(state: any)
        local GOLD = C.Text -- (UI CLEAN R-A: heads in Text; gold is for currency)
        local lvl = state.Level or 1
        local week = Weekly.Week()
        local w = (type(state.Weekly) == "table" and state.Weekly.Week == week) and state.Weekly or { Bounties = {}, Rerolls = 0 }
        -- left: this week's boss
        local b = Weekly.BossOf(week)
        local modId = Weekly.ModOf(week)
        local mod = Weekly.Mods[modId]
        local tier = Weekly.TierFor(lvl)
        local td = BossTrials.Tiers[tier]
        local left = Card({ Size = UDim2.new(0.46, -8, 1, 0) }, b.Color)
        Text({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 18), Text = "THIS WEEK'S BOSS  •  a new one in " .. Weekly.LeftText(), TextSize = 13, TextColor3 = C.Sub, Parent = left })
        Text({ Position = UDim2.fromOffset(16, 28), Size = UDim2.new(1, -32, 0, 34), Text = b.Name, TextSize = 28, Stroke = 2, TextColor3 = b.Color, Parent = left })
        Text({ Position = UDim2.fromOffset(16, 64), Size = UDim2.new(1, -32, 0, 34), Text = b.Blurb, Font = UIStyle.BodyFont, TextSize = 13, TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.Sub, Parent = left })
        -- the modifier
        local modBox = New("Frame", { Name = "Modifier", Position = UDim2.fromOffset(14, 104), Size = UDim2.new(1, -28, 0, 54), BackgroundColor3 = C.CardDark, BorderSizePixel = 0, Parent = left }, { UIStyle.Corner(4) })
        -- (UI CLEAN R-A: the modifier box is a raised card, its name keeps the warning colour -- no red box)
        Text({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 22), Text = "MODIFIER: " .. mod.Name, TextSize = 16, TextColor3 = Color3.fromRGB(255, 130, 100), Parent = modBox })
        Text({ Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 0, 22), Text = mod.Text, Font = UIStyle.BodyFont, TextSize = 13, Parent = modBox })
        local y = 168
        Row(left, y, "Your tier", "TIER " .. td.Name .. "  •  " .. string.upper(td.Difficulty), nil, 13); y += 24
        local rw = Weekly.Reward(lvl)
        Row(left, y, "First clear this week", ItemData.FormatNumber(rw.Gold) .. " gold  •  " .. rw.Prism .. " Prism", GOLD, 13); y += 22
        Text({ Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 20), Text = "+ " .. rw.EachCurrency .. " of every crafting currency you've unlocked + an item of the tier's top two rarities",
            Font = UIStyle.BodyFont, TextSize = 12, TextWrapped = true, TextColor3 = GOLD, Parent = left }); y += 38
        Text({ Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 34), Font = UIStyle.BodyFont, TextSize = 12, TextWrapped = true, TextColor3 = C.Sub,
            Text = "Paid on top of the boss's normal trial rewards. After that it's a normal trial; modified runs don't go on the leaderboard.", Parent = left })
        y += 40
        -- how it fights (its first mechanics, so you know what you're walking into; BOSSES has the full list)
        Text({ Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 18), Text = "HOW IT FIGHTS", TextSize = 13, TextColor3 = C.Sub, Parent = left }); y += 20
        for mi = 1, math.min(2, #b.Mechanics) do
            Text({ Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 42), Text = "•  " .. b.Mechanics[mi], Font = UIStyle.BodyFont, TextSize = 12, TextWrapped = true,
                TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Top, Parent = left })
            y += 44
        end
        local locked = lvl < Weekly.UNLOCK_BOSS
        local status = locked and ("Unlocks at level " .. Weekly.UNLOCK_BOSS .. ".") or (w.BossDone and "✓ CLEARED THIS WEEK: the stack is claimed." or "Not cleared this week.")
        Text({ Name = "Status", Position = UDim2.new(0, 16, 1, -94), Size = UDim2.new(1, -32, 0, 22), Text = status, TextSize = 14,
            TextColor3 = locked and C.Sub or (w.BossDone and C.Green or C.Text), Parent = left })
        local party, isHost = PartyInfo()
        local solo = UIStyle.Button(left, "FIGHT SOLO", b.Color, UDim2.new(0.5, -18, 0, 50), UDim2.new(0, 14, 1, -64), "WeeklySolo")
        solo.Label.TextSize = 16
        solo.SetEnabled(not locked)
        solo.Button.MouseButton1Click:Connect(function()
            if not solo.Button.Active then return end
            click()
            if hooks.StartBossTrial then hooks.StartBossTrial(b.Id, tier, "Solo", true) end
        end)
        local withParty = UIStyle.Button(left, (party >= 2) and ("WITH PARTY (" .. party .. ")") or "WITH PARTY", Color3.fromRGB(90, 160, 230),
            UDim2.new(0.5, -18, 0, 50), UDim2.new(0.5, 4, 1, -64), "WeeklyParty")
        withParty.Label.TextSize = 14
        withParty.SetEnabled(not locked and party >= 2 and isHost)
        withParty.Button.MouseButton1Click:Connect(function()
            if not withParty.Button.Active then return end
            click()
            if hooks.StartBossTrial then hooks.StartBossTrial(b.Id, tier, "Party", true) end
        end)
        UIStyle.PhoneScrollCard(left, 100) -- (UI CLEAN R-A2: on a phone the boss card's lines scroll above the status + buttons -- they overlapped)

        -- right: the bounty board
        local right = Card({ Position = UDim2.new(0.46, 8, 0, 0), Size = UDim2.new(0.54, -8, 1, 0) }, GOLD)
        Text({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 30), Text = "JOB BOARD", TextSize = 24, Stroke = 2, TextColor3 = GOLD, Parent = right })
        if lvl < Weekly.UNLOCK_BOUNTIES then
            Text({ Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 0, 60), Font = UIStyle.BodyFont, TextSize = 14, TextWrapped = true, TextColor3 = C.Sub,
                Text = "The Job Board unlocks at level " .. Weekly.UNLOCK_BOUNTIES .. ": " .. Weekly.COUNT .. " big jobs a week, each paying gold, Prism and a crafting currency.", Parent = right })
            UIStyle.ScrollCard(left, 68)
            return
        end
        local allowed = Weekly.REROLLS + (Weekly.ExtraRerolls and Weekly.ExtraRerolls(state) or 0)
        local rerollsLeft = math.max(0, allowed - (w.Rerolls or 0))
        Text({ Position = UDim2.fromOffset(16, 38), Size = UDim2.new(1, -32, 0, 18), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub,
            Text = string.format("%d jobs a week; the same things count as for your daily contracts. Rerolls left: %d.", Weekly.COUNT, rerollsLeft), Parent = right })
        local br = Weekly.BountyReward(lvl)
        local yy = 64
        local bounties = w.Bounties or {}
        if #bounties == 0 then
            Text({ Position = UDim2.fromOffset(16, yy), Size = UDim2.new(1, -32, 0, 24), Text = "Your board fills in as soon as you play.", Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, Parent = right })
            yy += 32 -- (the reward rows below used to sit on top of this line)
        end
        -- (QOL2 R4 GOAL TRACKER) TRACK / TRACKED: which goals the run's tracker panel shows (AimRngShared/GoalTracker, per session)
        local GT = require(script.Parent:WaitForChild("GoalTracker"))
        local function TrackBtn(parentFrame: Instance, key: string, pos: UDim2)
            local function Label() return GT.IsPinned(key, state) and "✓ TRACKED" or "TRACK" end
            local tb = UIStyle.Button(parentFrame, Label(), Color3.fromRGB(90, 160, 230), UDim2.fromOffset(92, 30), pos, "Track")
            tb.Label.TextSize = 12
            tb.Button.MouseButton1Click:Connect(function()
                click()
                local ok, msg = GT.Toggle(key, state)
                if not ok and msg then toast(msg) end
                tb.Label.Text = Label()
            end)
            local cn = GT.Changed:Connect(function() if tb.Label.Parent then tb.Label.Text = Label() end end)
            tb.Button.Destroying:Connect(function() cn:Disconnect() end) -- (a re-render drops the old buttons: no leaked connections)
            return tb
        end
        for i, c in ipairs(bounties) do
            local row = New("Frame", { Name = "Bounty" .. i, Position = UDim2.fromOffset(14, yy), Size = UDim2.new(1, -28, 0, 56), BackgroundColor3 = C.CardDark, BorderSizePixel = 0, Parent = right }, { UIStyle.Corner(4) })
            if c.Done then UIStyle.Stroke(C.Green, 1).Parent = row end
            Text({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -216, 0, 22), Text = (c.Done and "✓ " or "") .. Weekly.Text(c), TextSize = 14,
                TextColor3 = c.Done and C.Green or C.Text, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
            if not c.Done then TrackBtn(row, "W:" .. i .. ":" .. tostring(c.Id), UDim2.new(1, -204, 0.5, -15)) end -- (QOL2 R4)
            local bar = New("Frame", { Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -226, 0, 8), BackgroundColor3 = C.Off, BorderSizePixel = 0, Parent = row })
            New("Frame", { Size = UDim2.new(math.clamp(c.Progress / math.max(1, c.Target), 0, 1), 0, 1, 0), BackgroundColor3 = c.Done and C.Green or GOLD, BorderSizePixel = 0, Parent = bar })
            Text({ Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -130, 0, 16), Text = string.format("%s / %s", ItemData.FormatNumber(c.Progress), ItemData.FormatNumber(c.Target)),
                Font = UIStyle.BodyFont, TextSize = 11, TextColor3 = C.Sub, Parent = row })
            if not c.Done then
                local rr = UIStyle.Button(row, "REROLL", C.Steel, UDim2.fromOffset(96, 36), UDim2.new(1, -106, 0.5, -18), "Reroll" .. i)
                rr.Label.TextSize = 14
                rr.SetEnabled(rerollsLeft > 0)
                rr.Button.MouseButton1Click:Connect(function()
                    if not rr.Button.Active then return end
                    click()
                    task.spawn(function()
                        local ok, msg = Remotes.GetFunction("WeeklyAction"):InvokeServer("Reroll", i)
                        toast(tostring(msg or (ok and "Rerolled." or "Couldn't reroll.")))
                    end)
                end)
            end
            yy += 62
        end
        local bonus = Weekly.BonusReward(lvl)
        Row(right, yy + 2, "Each job", ItemData.FormatNumber(br.Gold) .. " gold  •  " .. br.Prism .. " Prism  •  a currency", GOLD, 12)
        Row(right, yy + 24, w.BonusPaid and "✓ All five: claimed" or "All five", ItemData.FormatNumber(bonus.Gold) .. " gold  •  " .. bonus.Prism .. " Prism  •  a currency set  •  an item",
            w.BonusPaid and C.Green or GOLD, 12)
        -- (MASTERY RANK perk: next week's boss + modifier, early)
        if MasteryRank.SeesNextWeek(MasteryRank.Rank(state)) then
            local nb, nm = Weekly.BossOf(week + 1), Weekly.Mods[Weekly.ModOf(week + 1)]
            Row(right, yy + 48, "Next week (Marksman Grade perk)", nb.Name .. "  •  " .. nm.Name, MasteryRank.Color, 12)
        end
        do -- (QOL2 R4) today's daily contracts, so they can be tracked in runs too
            local cs = state.Contracts
            local list = (type(cs) == "table" and cs.Day == require(script.Parent:WaitForChild("Contracts")).Today() and type(cs.List) == "table") and cs.List or {}
            local cy = yy + 80
            if #list > 0 then
                Text({ Position = UDim2.fromOffset(16, cy), Size = UDim2.new(1, -32, 0, 22), Text = "DAILY CONTRACTS  •  track them in runs", TextSize = 15, TextColor3 = C.Sub, Parent = right })
                cy += 28
            end
            local CT = require(script.Parent:WaitForChild("Contracts"))
            for i, c in ipairs(list) do
                local row = New("Frame", { Name = "Contract" .. i, Position = UDim2.fromOffset(14, cy), Size = UDim2.new(1, -28, 0, 40), BackgroundColor3 = C.CardDark, BorderSizePixel = 0, Parent = right }, { UIStyle.Corner(4) })
                Text({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -120, 1, 0), Text = (c.Done and "✓ " or "") .. CT.Text(c) .. string.format("   %s / %s", ItemData.FormatNumber(c.Progress or 0), ItemData.FormatNumber(c.Target or 1)),
                    TextSize = 13, Font = UIStyle.BodyFont, TextColor3 = c.Done and C.Green or C.Text, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
                if not c.Done then TrackBtn(row, "C:" .. tostring(c.Id), UDim2.new(1, -102, 0.5, -15)) end
                cy += 46
            end
        end
        UIStyle.ScrollCard(left, 68)
        UIStyle.ScrollCard(right, 0)
    end

    -- ===================== DAILY =====================
    local function RenderDaily(state: any)
        local day = DailyChallenge.Today()
        local c = (data and data.Daily) or DailyChallenge.ForDay(day)
        local left = Card({ Size = UDim2.new(0.56, -8, 1, 0) }, C.Orange)
        Text({ Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 32), Text = "TODAY'S CHALLENGE  •  " .. string.upper(c.Difficulty), TextSize = 22, Stroke = 2, TextColor3 = C.Gold, Parent = left })
        Text({ Position = UDim2.fromOffset(16, 42), Size = UDim2.new(1, -32, 0, 34), Text = "Clear 5 floors as fast as you can (floor 5 is a boss). Same run for everyone today. Dying ends the attempt; retry as often as you like.",
            Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, TextWrapped = true, Parent = left })
        for floor = 1, DailyChallenge.FLOORS do
            local parts = {}
            for _, id in ipairs(c.Mods[floor] or {}) do
                local d = FloorMods.Defs[id]
                if d then table.insert(parts, d.Name) end
            end
            local ev = c.Events[floor]
            if ev and ev ~= "" and DungeonEvents.Defs[ev] then table.insert(parts, "+ " .. DungeonEvents.Defs[ev].Name) end
            if floor == DailyChallenge.FLOORS then table.insert(parts, "BOSS") end
            local y = 84 + (floor - 1) * 44
            local row = New("Frame", { Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -28, 0, 38), BackgroundColor3 = C.CardDark, Parent = left }, { UIStyle.Corner(10) })
            Text({ Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(90, 38), Text = "FLOOR " .. floor, TextSize = 16, Stroke = 1.5, Parent = row })
            -- (MIXED RUNS: every floor names its biome)
            local bio = DailyChallenge.BiomeOf(c, floor)
            Text({ Position = UDim2.fromOffset(100, 0), Size = UDim2.fromOffset(110, 38), Text = BIOME_NAMES[bio] or bio, TextSize = 13, Stroke = 1.5,
                TextColor3 = BIOME_COLORS[bio] or C.Text, Parent = row })
            Text({ Position = UDim2.fromOffset(214, 0), Size = UDim2.new(1, -222, 1, 0), Text = (#parts > 0) and table.concat(parts, "  •  ") or "No modifiers",
                Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = (#parts > 0) and C.Text or C.Sub, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
        end
        local best = state.DailyBest
        local bestToday = (type(best) == "table" and best.Day == day) and best.Time or nil
        Row(left, 312, "Your best today", DailyChallenge.FormatTime(bestToday), C.Gold, 16)
        Row(left, 338, "First clear today", (type(best) == "table" and best.Day == day and best.Rewarded) and "claimed" or "Rare+ gem, Prism Shards, 600 gold", C.Sub, 13)
        local secs = (day + 1) * 86400 - os.time()
        Row(left, 362, "New challenge in", string.format("%dh %02dm", secs // 3600, (secs % 3600) // 60), C.Sub, 13)
        local start = UIStyle.Button(left, "START DAILY CHALLENGE", C.Orange, UDim2.new(1, -28, 0, 56), UDim2.new(0, 14, 1, -70))
        start.Label.TextSize = 22
        start.Button.MouseButton1Click:Connect(function()
            click()
            if hooks.StartDaily then hooks.StartDaily() end
        end)

        local right = Card({ Position = UDim2.new(0.56, 8, 0, 0), Size = UDim2.new(0.44, -8, 1, 0) }, C.Gold)
        Text({ Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 32), Text = "TODAY'S FASTEST", TextSize = 22, Stroke = 2, TextColor3 = C.Gold, Parent = right })
        local rows = data and data.DailyBoard or {}
        if #rows == 0 then
            Text({ Position = UDim2.fromOffset(16, 50), Size = UDim2.new(1, -32, 0, 40), Text = data and "No clears yet today. Be the first!" or "Loading...", Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Sub, TextWrapped = true, Parent = right })
        end
        for i, r in ipairs(rows) do
            local col = (i == 1 and C.Gold) or (i == 2 and Color3.fromRGB(210, 215, 225)) or (i == 3 and Color3.fromRGB(215, 140, 70)) or C.Text
            Row(right, 50 + (i - 1) * 30, string.format("%d.  %s", i, r.Name or "?"), DailyChallenge.FormatTime(r.Value), col, 15)
        end
        LeaderboardView.Button(right, UDim2.new(1, -28, 0, 46), UDim2.new(0, 14, 1, -58), { "Daily" }, nil, click)
        UIStyle.ScrollCard(left, 74) -- (phones: the floor list scrolls above START, the board above its button)
        UIStyle.ScrollCard(right, 62)
    end

    -- ===================== SEASON GOALS (UPDATE 7 C8) =====================
    local function RenderGoals(state: any)
        local s = type(state.SeasonGoals) == "table" and state.SeasonGoals or {}
        if s.Id ~= SeasonGoals.SeasonId() then s = { Prog = {}, Done = {}, Paid = {} } end
        local GC = SeasonGoals.COLOR
        local n = SeasonGoals.DoneCount(s)
        local head = Card({ Name = "GoalsHead", Size = UDim2.new(1, 0, 0, 96) }, GC)
        Text({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(0.5, 0, 0, 30), Text = string.upper(Seasons.Current.Name) .. "  •  FEATS " .. n .. " / " .. #SeasonGoals.List,
            TextSize = 22, Stroke = 2, TextColor3 = GC, Parent = head })
        Text({ Position = UDim2.fromOffset(16, 40), Size = UDim2.new(0.5, -16, 0, 44), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top, Text = "Big feats across the whole game, counted from every run. Every 10 you finish pays a season title, BOUND points and gold. They reset with the season.", Parent = head })
        for i, m in ipairs(SeasonGoals.MILESTONES) do
            local paid = s.Paid and s.Paid[tostring(m.Need)]
            local x = 0.5 + (i - 1) * (0.5 / 3)
            local chip = New("Frame", { Position = UDim2.new(x, 4, 0, 10), Size = UDim2.new(0.5 / 3, -12, 0, 76), BackgroundColor3 = paid and UIStyle.Darken(GC, 0.5) or (C.CardDark or C.Bg2),
                BorderSizePixel = 0, Parent = head })
            Text({ Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 22), Text = (paid and "✓ " or "") .. m.Need .. " FEATS", TextSize = 16, TextColor3 = paid and C.Green or GC, Parent = chip })
            Text({ Position = UDim2.fromOffset(8, 28), Size = UDim2.new(1, -16, 0, 44), Font = UIStyle.BodyFont, TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
                Text = ((ItemData.Titles[m.Title] or {}).Title or "a title") .. "  •  " .. m.BP .. " BOUND  •  " .. ItemData.FormatNumber(m.Gold) .. " gold"
                    .. ((m.Need == 30) and ((#(SeasonGoals.MILESTONE_COSMETICS[30] or {}) > 0) and "  •  the season's exclusive piece" or "  •  + an exclusive piece (coming soon)") or ""), Parent = chip })
        end
        local scroll = New("ScrollingFrame", { Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 1, -104), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = body })
        New("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 50), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
        local lvl = state.Level or 1
        for i, g in ipairs(SeasonGoals.List) do
            local done = s.Done and s.Done[g.Id]
            local prog = (s.Prog and tonumber(s.Prog[g.Id])) or 0
            local locked = (g.MinLevel or 1) > lvl
            local row = New("Frame", { LayoutOrder = i, BackgroundColor3 = C.CardDark or C.Bg2, BorderSizePixel = 0, Parent = scroll })
            Text({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 20), Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = done and C.Green or (locked and C.Sub or C.Text),
                TextTruncate = Enum.TextTruncate.AtEnd, Text = (done and "✓ " or "") .. SeasonGoals.Text(g) .. (locked and ("  (level " .. g.MinLevel .. ")") or ""), Parent = row })
            local pb = New("Frame", { Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -110, 0, 8), BackgroundColor3 = C.Off, BorderSizePixel = 0, Parent = row })
            New("Frame", { Size = UDim2.new(math.clamp(prog / g.Target, 0, 1), 0, 1, 0), BackgroundColor3 = done and C.Green or GC, BorderSizePixel = 0, Parent = pb })
            Text({ Position = UDim2.new(1, -96, 0, 22), Size = UDim2.fromOffset(86, 20), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Right,
                Text = ItemData.FormatNumber(prog) .. " / " .. ItemData.FormatNumber(g.Target), Parent = row })
        end
    end

    -- ===================== THE DAILY LINE (UPDATE 7 B6) =====================
    local function RenderLine(state: any)
        local day = DailyLine.Today()
        local c = DailyLine.ForDay(day)
        local LC = DailyLine.COLOR
        local rec = DailyLine.Record(state)
        local diff = ItemData.DifficultyOrder[ItemData.TopUnlockedRank(state)] or "Normal"
        local left = Card({ Size = UDim2.new(0.56, -8, 1, 0) }, LC)
        Text({ Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 32), Text = "THE GAUNTLET RUN  •  " .. string.upper(diff), TextSize = 22, Stroke = 2, TextColor3 = LC, Parent = left })
        Text({ Position = UDim2.fromOffset(16, 42), Size = UDim2.new(1, -32, 0, 50), Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, TextWrapped = true, Parent = left,
            Text = "Three harsh floors, the same for everyone today, on the hardest difficulty you've unlocked (floor 3 is a boss). ONE try a day: dying or leaving spends it. Level " .. DailyLine.UNLOCK .. "+." })
        for floor = 1, DailyLine.FLOORS do
            local parts = {}
            for _, id in ipairs(c.Mods[floor] or {}) do
                local d = FloorMods.Defs[id]
                if d then table.insert(parts, d.Name) end
            end
            if floor == DailyLine.FLOORS then table.insert(parts, "BOSS") end
            local y = 98 + (floor - 1) * 44
            local row = New("Frame", { Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -28, 0, 38), BackgroundColor3 = C.CardDark, Parent = left }, { UIStyle.Corner(10) })
            Text({ Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(90, 38), Text = "FLOOR " .. floor, TextSize = 16, Stroke = 1.5, Parent = row })
            local bio = c.Biomes[floor]
            Text({ Position = UDim2.fromOffset(100, 0), Size = UDim2.fromOffset(110, 38), Text = BIOME_NAMES[bio] or string.upper(bio or "?"), TextSize = 13, Stroke = 1.5,
                TextColor3 = BIOME_COLORS[bio] or C.Text, Parent = row })
            Text({ Position = UDim2.fromOffset(214, 0), Size = UDim2.new(1, -222, 1, 0), Text = table.concat(parts, "  •  "), Font = UIStyle.BodyFont, TextSize = 13,
                TextColor3 = C.Text, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
        end
        local status = rec.Done and ("cleared in " .. DailyChallenge.FormatTime(rec.Time)) or (rec.Tried and "tried (no clear)") or "not tried yet"
        Row(left, 240, "Today", status, rec.Done and C.Green or (rec.Tried and C.Sub or C.Gold), 15)
        local rw = DailyLine.Reward(state.Level)
        Row(left, 266, "A clear pays", ItemData.FormatNumber(rw.Gold) .. " gold  •  " .. rw.Prism .. " Prism  •  currencies  •  Sigil Marks  •  2 top items", C.Sub, 12)
        local secs = (day + 1) * 86400 - os.time()
        Row(left, 290, "New line in", string.format("%dh %02dm", secs // 3600, (secs % 3600) // 60), C.Sub, 13)
        local can, why = DailyLine.CanStart(state)
        local start = UIStyle.Button(left, can and "RUN THE LINE" or string.upper(tostring(why)), LC, UDim2.new(1, -28, 0, 56), UDim2.new(0, 14, 1, -70))
        start.Label.TextSize = can and 22 or 13
        start.SetEnabled(can)
        start.Button.MouseButton1Click:Connect(function()
            if not start.Button.Active then return end
            click()
            if hooks.StartLine then hooks.StartLine() end
        end)
        local right = Card({ Position = UDim2.new(0.56, 8, 0, 0), Size = UDim2.new(0.44, -8, 1, 0) }, C.Gold)
        Text({ Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 32), Text = "TODAY'S FASTEST", TextSize = 22, Stroke = 2, TextColor3 = C.Gold, Parent = right })
        local rows = data and data.LineBoard or {}
        if #rows == 0 then
            Text({ Position = UDim2.fromOffset(16, 50), Size = UDim2.new(1, -32, 0, 40), Text = data and "Nobody has cleared today's line yet." or "Loading...", Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Sub, TextWrapped = true, Parent = right })
        end
        for i, r in ipairs(rows) do
            local col = (i == 1 and C.Gold) or (i == 2 and Color3.fromRGB(210, 215, 225)) or (i == 3 and Color3.fromRGB(215, 140, 70)) or C.Text
            Row(right, 50 + (i - 1) * 30, string.format("%d.  %s", i, r.Name or "?"), DailyChallenge.FormatTime(r.Value), col, 15)
        end
        LeaderboardView.Button(right, UDim2.new(1, -28, 0, 46), UDim2.new(0, 14, 1, -58), { "Line" }, nil, click)
        UIStyle.ScrollCard(left, 74)
        UIStyle.ScrollCard(right, 62)
    end

    -- ===================== AIM TRIALS =====================
    local trialSel = AimTrials.Scenarios[1].Id
    local trialDiff = "Standard"
    local function RenderTrials(state: any)
        local bests = type(state.TrialBest) == "table" and state.TrialBest or {}
        -- left: the scenarios
        local listCol = New(UIStyle.IsPhone() and "ScrollingFrame" or "Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.42, -8, 1, 0), Parent = body })
        if listCol:IsA("ScrollingFrame") then -- (phones: the scenarios scroll)
            listCol.BorderSizePixel, listCol.ScrollBarThickness, listCol.CanvasSize, listCol.AutomaticCanvasSize = 0, 4, UDim2.new(), Enum.AutomaticSize.Y
        end
        New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = listCol })
        for i, s in ipairs(AimTrials.Scenarios) do
            local sel = s.Id == trialSel
            local best = bests[s.Id] or 0
            local rankName = AimTrials.RankName(AimTrials.RankOf(s.Id, best))
            local row = New("TextButton", { Text = "", AutoButtonColor = false, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 108), BackgroundColor3 = Color3.new(1, 1, 1), Parent = listCol }, { UIStyle.Corner(12) })
            UIStyle.Gradient(sel and UIStyle.Darken(s.Color, 0.45) or C.Card, sel and UIStyle.Darken(s.Color, 0.72) or C.CardDark).Parent = row
            local rs = UIStyle.Stroke(sel and C.Text or C.Text, 1); rs.Transparency = sel and 0.2 or 0.86; rs.Parent = row -- (UI CLEAN R-A: one hairline, brighter when picked)
            UIStyle.Hover(row, 0.02)
            Text({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 30), Text = string.upper(s.Name), TextSize = 24, Stroke = 2, TextColor3 = s.Color, Parent = row })
            Text({ Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 20), Text = s.Duration .. " seconds", Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, Parent = row })
            Text({ Position = UDim2.fromOffset(14, 66), Size = UDim2.new(0.5, -14, 0, 30), Text = "BEST " .. best, TextSize = 18, Stroke = 1.5, Parent = row })
            Text({ Position = UDim2.new(0.5, 0, 0, 66), Size = UDim2.new(0.5, -14, 0, 30), Text = rankName and string.upper(rankName) or "UNRANKED", TextSize = 18, Stroke = 1.5,
                TextColor3 = rankName and AimTrials.RankColors[rankName] or C.Sub, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
            row.MouseButton1Click:Connect(function()
                click()
                trialSel = s.Id
                Render()
            end)
        end
        -- right: the selected scenario + its leaderboard
        local s = AimTrials.ById[trialSel]
        local best = bests[s.Id] or 0
        local rank = AimTrials.RankOf(s.Id, best)
        local nextNeed = s.Ranks[rank + 1]
        local right = Card({ Position = UDim2.new(0.42, 8, 0, 0), Size = UDim2.new(0.58, -8, 1, 0) }, s.Color)
        Text({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -200, 0, 34), Text = string.upper(s.Name), TextSize = 28, Stroke = 2.5, TextColor3 = s.Color, Parent = right })
        Text({ Position = UDim2.fromOffset(16, 44), Size = UDim2.new(1, -214, 0, 36), Text = s.Text, Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, TextWrapped = true, Parent = right })
        local start = UIStyle.Button(right, "START", s.Color, UDim2.fromOffset(170, 56), UDim2.new(1, -184, 0, 12))
        start.Label.TextSize = 24
        start.Button.MouseButton1Click:Connect(function()
            click()
            if hooks.StartTrial then hooks.StartTrial(s.Id, trialDiff) end
        end)
        -- difficulty: smaller / faster targets, bigger score multiplier
        local dRow = New("Frame", { Position = UDim2.new(1, -184, 0, 74), Size = UDim2.fromOffset(170, 26), BackgroundTransparency = 1, Parent = right })
        New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2), Parent = dRow })
        for _, d in ipairs(AimTrials.Difficulties) do
            local on = d.Id == trialDiff
            local b = New("TextButton", { Size = UDim2.new(0.25, -2, 1, 0), Text = string.sub(d.Id, 1, 3):upper(), Font = UIStyle.Font, TextSize = 13,
                TextColor3 = on and C.Text or C.Sub, BackgroundColor3 = on and d.Color or C.CardDark, AutoButtonColor = false, Parent = dRow }, { UIStyle.Corner(6) })
            b.MouseButton1Click:Connect(function()
                click()
                trialDiff = d.Id
                Render()
            end)
        end
        local dd = AimTrials.DifficultyById[trialDiff]
        Text({ Position = UDim2.new(1, -184, 0, 102), Size = UDim2.fromOffset(170, 18), Font = UIStyle.BodyFont, TextSize = 11, TextColor3 = dd.Color, TextXAlignment = Enum.TextXAlignment.Center,
            Text = string.format("%s: x%.1f score", string.upper(dd.Id), dd.Mult), Parent = right })
        Row(right, 126, "Your best", tostring(best), C.Text, 16)
        local runsLeft = AimTrials.RUN_REWARDS_PER_DAY - ((type(state.TrialRuns) == "table" and state.TrialRuns.Day == DailyChallenge.Today()) and state.TrialRuns.N or 0)
        Text({ Position = UDim2.fromOffset(16, 84), Size = UDim2.new(1, -214, 0, 30), Font = UIStyle.BodyFont, TextSize = 11, TextColor3 = C.Gold, TextWrapped = true,
            Text = string.format("Every run pays gold + Scrap by score (%d paid runs left today). Top 10 each day win prizes.", math.max(0, runsLeft)), Parent = right })
        Row(right, 150, "Next rank", nextNeed and (AimTrials.RankNames[rank + 1] .. " at " .. nextNeed) or "MAXED", C.Sub, 14)
        -- rank ladder
        local ladder = New("Frame", { Position = UDim2.fromOffset(14, 180), Size = UDim2.new(1, -28, 0, 26), BackgroundTransparency = 1, Parent = right })
        New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = ladder })
        for ri, rn in ipairs(AimTrials.RankNames) do
            local got = rank >= ri
            local chip = New("Frame", { Size = UDim2.new(1 / 6, -4, 1, 0), BackgroundColor3 = got and UIStyle.Darken(AimTrials.RankColors[rn], 0.35) or C.CardDark, Parent = ladder }, { UIStyle.Corner(8) })
            Text({ Size = UDim2.fromScale(1, 1), Text = s.Ranks[ri] .. "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = got and C.Text or C.Sub, Parent = chip })
        end
        Text({ Position = UDim2.fromOffset(16, 214), Size = UDim2.new(1, -32, 0, 28), Text = "TODAY'S TOP 10", TextSize = 20, Stroke = 2, TextColor3 = C.Gold, Parent = right })
        do
            local ids = {}
            for _, sc in ipairs(AimTrials.Scenarios) do table.insert(ids, "Trial_" .. sc.Id) end
            LeaderboardView.Button(right, UDim2.fromOffset(170, 32), UDim2.new(1, -184, 0, 212), ids, function() return "Trial_" .. trialSel end, click)
        end
        local rows = data and data.TrialBoards and data.TrialBoards[s.Id] or {}
        if #rows == 0 then
            Text({ Position = UDim2.fromOffset(16, 246), Size = UDim2.new(1, -32, 0, 24), Text = data and "No scores yet today. Set the first one!" or "Loading...", Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Sub, Parent = right })
        end
        for i, r in ipairs(rows) do
            local col = (i == 1 and C.Gold) or (i == 2 and Color3.fromRGB(210, 215, 225)) or (i == 3 and Color3.fromRGB(215, 140, 70)) or C.Text
            local rn = AimTrials.RankName(AimTrials.RankOf(s.Id, r.Value or 0))
            Row(right, 244 + (i - 1) * 26, string.format("%d.  %s", i, r.Name or "?"), tostring(r.Value) .. (rn and ("  " .. rn) or ""), col, 14)
        end
        UIStyle.ScrollCard(right, 0) -- (phones: the whole card scrolls)
    end

    -- ===================== MASTERY =====================
    local function RenderMastery(state: any)
        local kills = (state.StatsTracking and state.StatsTracking.WeaponKills) or {}
        -- (the TOP LEVELS board lived on the Paragon tab until Paragon was removed, 2026-10-13)
        -- MASTERY RANK (UPDATE 7 A3): every gun's mastery level is a point; points open the next rank, an aim exam takes it
        local MRC = MasteryRank.Color
        local rank = MasteryRank.Rank(state)
        local pts = MasteryRank.Points(state)
        local nextNeed = MasteryRank.POINTS[rank + 1]
        local prevNeed = MasteryRank.POINTS[rank] or 0
        local head = Card({ Name = "RankCard", Size = UDim2.new(1, 0, 0, 150) }, MRC)
        Text({ Position = UDim2.fromOffset(16, 6), Size = UDim2.new(0.5, 0, 0, 30), Text = "MARKSMAN GRADE " .. rank .. ((rank >= MasteryRank.MAX) and "  (MAX)" or ""), TextSize = 26, Stroke = 2, TextColor3 = MRC, Parent = head })
        Text({ Position = UDim2.fromOffset(16, 38), Size = UDim2.new(0.5, -16, 0, 18), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub,
            Text = "Every mastery level on every gun is a point. Points open the next grade; pass its aim exam to take it.", TextWrapped = true, Parent = head })
        local bar = New("Frame", { Position = UDim2.fromOffset(16, 62), Size = UDim2.new(0.5, -16, 0, 10), BackgroundColor3 = C.Off, BorderSizePixel = 0, Parent = head })
        local frac = nextNeed and math.clamp((pts - prevNeed) / math.max(1, nextNeed - prevNeed), 0, 1) or 1
        New("Frame", { Size = UDim2.new(frac, 0, 1, 0), BackgroundColor3 = MRC, BorderSizePixel = 0, Parent = bar })
        Text({ Position = UDim2.fromOffset(16, 74), Size = UDim2.new(0.5, -16, 0, 18), Font = UIStyle.BodyFont, TextSize = 12,
            Text = nextNeed and string.format("%d / %d mastery points for grade %d", pts, nextNeed, rank + 1) or (pts .. " mastery points"), Parent = head })
        -- the exam
        local can, why = MasteryRank.CanExam(state)
        if nextNeed then
            local exam = MasteryRank.Exam(rank + 1)
            local sc = AimTrials.ById[exam.Scenario]
            Text({ Position = UDim2.fromOffset(16, 96), Size = UDim2.new(0.5, -200, 0, 40), Font = UIStyle.BodyFont, TextSize = 12, TextWrapped = true,
                TextColor3 = can and C.Text or C.Sub, TextYAlignment = Enum.TextYAlignment.Top,
                Text = string.format("RANK %d EXAM: %s, %s rank or better (any difficulty, no time limit, retry freely).%s", rank + 1, string.upper(sc and sc.Name or exam.Scenario),
                    string.upper(exam.NeedName or "?"), can and "" or ("  " .. tostring(why))), Parent = head })
            local go = UIStyle.Button(head, "TAKE THE EXAM", MRC, UDim2.fromOffset(170, 44), UDim2.new(0.5, -186, 0, 94), "TakeExam")
            go.Label.TextSize = 15
            go.SetEnabled(can)
            go.Button.MouseButton1Click:Connect(function()
                if not go.Button.Active then return end
                click()
                if hooks.StartTrial then hooks.StartTrial(exam.Scenario, "Standard") end
            end)
        end
        -- perks: what you have + what the next rank gives
        local have = {}
        if MasteryRank.BagBonus(rank) > 0 then table.insert(have, "+" .. MasteryRank.BagBonus(rank) .. " bag slots") end
        if MasteryRank.ExtraRerolls(rank) > 0 then table.insert(have, "+" .. MasteryRank.ExtraRerolls(rank) .. " bounty reroll" .. (MasteryRank.ExtraRerolls(rank) == 1 and "" or "s")) end
        if MasteryRank.ExtraContracts(rank) > 0 then table.insert(have, "+" .. MasteryRank.ExtraContracts(rank) .. " daily contract" .. (MasteryRank.ExtraContracts(rank) == 1 and "" or "s")) end
        if MasteryRank.SeesNextWeek(rank) then table.insert(have, "next week's Quarry early") end
        if rank >= 1 then table.insert(have, "rank emblem R" .. rank) end
        Text({ Position = UDim2.new(0.5, 8, 0, 8), Size = UDim2.new(0.5, -190, 0, 18), Text = "YOUR PERKS", TextSize = 13, TextColor3 = C.Sub, Parent = head })
        Text({ Position = UDim2.new(0.5, 8, 0, 26), Size = UDim2.new(0.5, -190, 0, 40), Font = UIStyle.BodyFont, TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
            Text = (#have > 0) and table.concat(have, "  •  ") or "None yet: rank 1 puts your emblem on your name tag.", Parent = head })
        local nextPerks = {}
        for r2 = rank + 1, MasteryRank.MAX do
            if MasteryRank.Perks[r2] then nextPerks = { "RANK " .. r2 .. ": " .. table.concat(MasteryRank.Perks[r2], ", ") }; break end
        end
        Text({ Position = UDim2.new(0.5, 8, 0, 70), Size = UDim2.new(0.5, -190, 0, 18), Text = "NEXT", TextSize = 13, TextColor3 = C.Sub, Parent = head })
        Text({ Position = UDim2.new(0.5, 8, 0, 88), Size = UDim2.new(0.5, -190, 0, 40), Font = UIStyle.BodyFont, TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
            TextColor3 = MRC, Text = nextPerks[1] or "You have every perk.", Parent = head })
        Text({ Position = UDim2.new(1, -172, 0, 8), Size = UDim2.fromOffset(160, 40), Font = UIStyle.BodyFont, TextSize = 11, TextWrapped = true, TextColor3 = C.Sub,
            Text = "Perks are never damage: storage, rerolls, contracts and show-off.", Parent = head })
        LeaderboardView.Button(head, UDim2.fromOffset(160, 40), UDim2.new(1, -172, 1, -52), { "PlayerLevel" }, nil, click, "TOP LEVELS")
        local scroll = New("ScrollingFrame", { Position = UDim2.fromOffset(0, 158), Size = UDim2.new(1, 0, 1, -158), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = body })
        local calOn = Calibration.Unlocked(state) -- (UPDATE 7 B2: from level 65 each gun card shows its calibration; click = its tiers)
        New("UIGridLayout", { CellSize = UDim2.new(0.333, -8, 0, calOn and 112 or 92), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
        local ids = table.clone(ItemData.Lineup)
        table.sort(ids, function(a, b)
            local ka, kb = kills[a] or 0, kills[b] or 0
            if ka ~= kb then return ka > kb end
            return a < b
        end)
        for i, id in ipairs(ids) do
            local def = ItemData.BaseWeapons[id]
            local k = math.floor(kills[id] or 0) -- (UPDATE 8: fodder kills count 1/5 -- fractional counts, shown whole)
            local lvl = Progression.MasteryLevel(k)
            local _, need = Progression.MasteryProgress(k)
            local prevNeed = Progression.MasteryKills[lvl] or 0
            local col = (lvl >= 10) and C.Gold or ((lvl >= 5) and C.Purple or C.Blue)
            local card = KCard(scroll, { LayoutOrder = i, Size = UDim2.fromScale(1, 1) }, (lvl > 0) and col or nil)
            Text({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -90, 0, 26), Text = def and def.ShortName or id, TextSize = 19, Stroke = 1.5, Parent = card })
            Text({ Position = UDim2.new(1, -86, 0, 6), Size = UDim2.fromOffset(74, 26), Text = (lvl >= 10) and "MASTERED" or ("LV " .. lvl), TextSize = 16, TextColor3 = col, TextXAlignment = Enum.TextXAlignment.Right, Stroke = 1.5, Parent = card })
            local bonus = Progression.MasteryStats(lvl)
            local bonusText = (lvl > 0) and ("+" .. Pct(bonus.IncreasedDamage or 0) .. " damage" .. (bonus.WeakSpotMultiplier and ", +10% weak-spot" or "") .. (bonus.CritMultiplier and ", +15% crit dmg" or "")) or "No kills yet"
            Text({ Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 20), Text = bonusText, Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
            local bar = New("Frame", { Position = UDim2.fromOffset(12, 62), Size = UDim2.new(1, -24, 0, 10), BackgroundColor3 = C.Off, BorderSizePixel = 0, Parent = card }, { UIStyle.Corner(5) })
            local frac = need and math.clamp((k - prevNeed) / math.max(1, need - prevNeed), 0, 1) or 1
            New("Frame", { Size = UDim2.new(frac, 0, 1, 0), BackgroundColor3 = col, BorderSizePixel = 0, Parent = bar }, { UIStyle.Corner(5) })
            Text({ Position = UDim2.fromOffset(12, 72), Size = UDim2.new(1, -24, 0, 18), Text = need and string.format("%d / %d kills", k, need) or (k .. " kills"), Font = UIStyle.BodyFont, TextSize = 11, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Right, Parent = card })
            if calOn then
                local cc = Calibration.Of(state, id)
                local ct = cc and cc.T or 0
                local line
                if ct >= Calibration.MAX then line = "◆ ZEROED V"
                elseif Calibration.Ready(cc) then line = "◆ ZEROING " .. Calibration.NUMERALS[ct + 1] .. " READY: CLICK TO CLAIM"
                else line = string.format("ZEROING %d / %d  •  next %d / %d", ct, Calibration.MAX, math.floor(cc and cc.P or 0), Calibration.TIERS[ct + 1].Need) end
                Text({ Position = UDim2.fromOffset(12, 90), Size = UDim2.new(1, -24, 0, 18), Text = line, Font = UIStyle.BodyFont, TextSize = 12,
                    TextColor3 = Calibration.COLOR, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
                local hit = New("TextButton", { Name = "CalOpen", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = card })
                hit.MouseButton1Click:Connect(function()
                    click()
                    root:SetAttribute("CalGun", id)
                    Render()
                end)
            end
        end
        -- (UPDATE 7 B2) CALIBRATION PANEL over the tab: the picked gun's 5 tiers (root attr CalGun = the gun, "" = closed)
        local calId = root:GetAttribute("CalGun")
        if calOn and type(calId) == "string" and ItemData.BaseWeapons[calId] then
            local def = ItemData.BaseWeapons[calId]
            local cc = Calibration.Of(state, calId)
            local ct = cc and cc.T or 0
            local CC = Calibration.COLOR
            local pane = New("TextButton", { Name = "CalPanel", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Bg0 or Color3.fromRGB(16, 17, 20),
                BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = body })
            Text({ Position = UDim2.fromOffset(16, 4), Size = UDim2.new(1, -200, 0, 30), Text = "ZEROING  •  " .. string.upper(def.ShortName or def.Name or calId), TextSize = 24, Stroke = 2, TextColor3 = CC, ZIndex = 21, Parent = pane })
            Text({ Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -200, 0, 32), Font = UIStyle.BodyFont, TextSize = 12, TextWrapped = true, TextColor3 = C.Sub, ZIndex = 21,
                TextYAlignment = Enum.TextYAlignment.Top,
                Text = "Do each tier's aim feat with this gun, then claim it and pick one of its two perks. Claimed tiers can be switched for a little gold. The perks count for every " .. (def.ShortName or calId) .. " you own.",
                Parent = pane })
            local back = UIStyle.Button(pane, "BACK", C.Steel, UDim2.fromOffset(120, 40), UDim2.new(1, -136, 0, 8), "CalBack")
            back.Button.ZIndex = 22
            back.Button.MouseButton1Click:Connect(function()
                click()
                root:SetAttribute("CalGun", "")
                Render()
            end)
            local function Act(action, ...)
                local args = table.pack(...)
                task.spawn(function()
                    local ok, msg = Remotes.GetFunction("CalibrationAction"):InvokeServer(action, calId, table.unpack(args, 1, args.n))
                    toast(tostring(msg or (ok and "Done." or "Couldn't do that.")))
                    task.delay(0.25, function() if root.Visible then Render() end end)
                end)
            end
            local lvl = state.Level or 1
            for t = 1, Calibration.MAX do
                local d = Calibration.TIERS[t]
                local y = 76 + (t - 1) * 96
                local claimed = t <= ct
                local isNext = t == ct + 1
                local ready = isNext and Calibration.Ready(cc)
                local row = KCard(pane, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 88), ZIndex = 21 }, (claimed or ready) and CC or nil)
                Text({ Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(60, 40), Text = Calibration.NUMERALS[t], TextSize = 30, Stroke = 2, ZIndex = 22,
                    TextColor3 = (claimed or isNext) and CC or C.Sub, Parent = row })
                local status
                if claimed then status = "✓ " .. Calibration.FeatText(t)
                elseif isNext then status = string.format("%s:  %d / %d", Calibration.FeatText(t), math.floor(math.min(cc and cc.P or 0, d.Need)), d.Need)
                else status = Calibration.FeatText(t) .. "  (after tier " .. Calibration.NUMERALS[t - 1] .. ")" end
                Text({ Position = UDim2.fromOffset(70, 8), Size = UDim2.new(0.38, -70, 0, 36), Font = UIStyle.BodyFont, TextSize = 13, TextWrapped = true, ZIndex = 22,
                    TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = (claimed or isNext) and C.Text or C.Sub, Text = status, Parent = row })
                if isNext and not ready then
                    local bar = New("Frame", { Position = UDim2.fromOffset(70, 50), Size = UDim2.new(0.38, -80, 0, 8), BackgroundColor3 = C.Off, BorderSizePixel = 0, ZIndex = 22, Parent = row })
                    New("Frame", { Size = UDim2.new(math.clamp((cc and cc.P or 0) / d.Need, 0, 1), 0, 1, 0), BackgroundColor3 = CC, BorderSizePixel = 0, ZIndex = 23, Parent = bar })
                end
                local gold, key, n = Calibration.Cost(t, lvl)
                if isNext then
                    local have = (state.Materials and state.Materials[key]) or 0
                    Text({ Position = UDim2.fromOffset(70, 62), Size = UDim2.new(0.38, -80, 0, 18), Font = UIStyle.BodyFont, TextSize = 11, ZIndex = 22,
                        TextColor3 = ((state.Gold or 0) >= gold and have >= n) and C.Sub or (C.Bad or C.Red),
                        Text = string.format("Claim: %s gold + %d %s (have %d)", ItemData.FormatNumber(gold), n, ItemData.MaterialDefs[key] and ItemData.MaterialDefs[key].Name or key, have), Parent = row })
                end
                local pick = claimed and Calibration.PickOf(cc, t) or 0
                for i, ch in ipairs(d.Choices) do
                    local x = (i == 1) and 0.38 or 0.69
                    local mine = claimed and pick == i
                    local label
                    if claimed then label = mine and ("✓ " .. string.upper(ch.Name)) or ("SWITCH: " .. ItemData.FormatNumber(Calibration.SwitchCost(t, lvl)) .. " GOLD")
                    elseif ready then label = "CLAIM: " .. string.upper(ch.Name)
                    else label = string.upper(ch.Name) end
                    local b = UIStyle.Button(row, label, mine and CC or (ready and C.Accent or C.Bg2), UDim2.new(0.31, -12, 0, 40), UDim2.new(x, 0, 0, 8), "Cal" .. t .. "_" .. i)
                    b.Button.ZIndex = 22
                    b.Label.TextSize = 13
                    b.SetEnabled(ready or claimed) -- (the picked perk stays lit: it reads as selected, a click does nothing)
                    Text({ Position = UDim2.new(x, 0, 0, 52), Size = UDim2.new(0.31, -12, 0, 30), Font = UIStyle.BodyFont, TextSize = 12, TextWrapped = true, ZIndex = 22,
                        TextColor3 = (claimed and not mine) and C.Sub or C.Text, TextYAlignment = Enum.TextYAlignment.Top, Text = ch.Desc, Parent = row })
                    b.Button.MouseButton1Click:Connect(function()
                        if not b.Button.Active or mine then return end
                        click()
                        if ready then Act("Claim", i) else Act("Pick", t, i) end
                    end)
                end
            end
        end
    end

    Render = function()
        Clear()
        -- (Update 5: one colour means "selected" -- the accent; the rest neutral. The rainbow tab row read as noise.)
        for id, b in pairs(tabButtons) do
            b.SetSelected(id == current) -- (v4 NEON)
        end
        local state = hooks.GetState and hooks.GetState() or {}
        if current == "Season" then RenderSeason(state)
        elseif current == "Rifts" then RenderRifts(state)
        elseif current == "Bosses" then RenderBosses(state)
        elseif current == "Weekly" then RenderWeekly(state)
        elseif current == "Ascension" then RenderAscension(state)
        elseif current == "Daily" then RenderDaily(state)
        elseif current == "Trials" then RenderTrials(state)
        elseif current == "Line" then RenderLine(state)
        elseif current == "Goals" then RenderGoals(state)
        else RenderMastery(state) end
    end

    local fetching = false
    local function Refresh()
        Render()
        if fetching then return end
        fetching = true
        task.spawn(function()
            local ok, res = pcall(function() return Remotes.GetFunction("GetChallengeData"):InvokeServer() end)
            fetching = false
            if ok and type(res) == "table" then
                data = res
                if root.Visible then Render() end
            end
        end)
    end
    root:GetPropertyChangedSignal("Visible"):Connect(function()
        if root.Visible then root:SetAttribute("CalGun", ""); Refresh(); RefreshBossRooms() end -- (a fresh open starts off the calibration panel)
    end)

    return {
        Frame = root,
        Refresh = function() if root.Visible then Render() end end,
        ShowTab = function(name: string)
            for _, t in ipairs(tabs) do if t.Id == name then current = name end end
            Refresh()
        end,
    }
end

return ChallengesMenu
