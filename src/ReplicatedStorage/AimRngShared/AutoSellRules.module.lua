--!nocheck
-- ============================================================================================
-- AUTO-SELL FILTER (2026-11-09, builder inv; owner: "we need a more in depth filter for auto sell aside from rarity (panel that
-- opens up so you can select certain number of slots, stats etc to filter out from autoselling)").
-- Two saved fields (SaveService PLAIN_FIELDS): state.AutoSellThreshold = the rarity ("OFF" | Common .. Mythic, as before) and
-- state.AutoSellRules = the KEEP rules (a clean table, nil = none):
--   { MinSockets = 0 | 2-6, MinLinks = 0 | 2-6, MinIlvl = 0 | 1-MAX_LEVEL_BUILT, Types = { "Assault", ..., "Gear:Helmet", ... },
--     Stats = { { S = stat id, T = min tier 0-15 (0 = any tier) }, ... (max MAX_STATS) }, StatCount = 1-#Stats }
--   (0 / empty = that rule is off). Every value the client sends goes through AutoSellRules.Clean (known ids only, clamped).
-- THE RULE: a new gun / gear drop is auto-sold only if its rarity is AT OR UNDER the threshold AND it matches NO keep rule (any one
-- rule keeps it). Relics + Zeniths are never auto-sold; given items (TARGET LOOT, contracts, the goblin's promise) skip auto-sell.
-- AutoSellRules.Decide is the ONE test: CombatServer.TryAutoSell (every drop path on the server) and the panel's bag preview.
-- Client window: AutoSellRules.Open(hooks) (the inventory's SELL > AUTO-SELL); Studio: Player attr DevAutoSell = "open" | "close".
-- ============================================================================================
local AutoSellRules = {}

AutoSellRules.MAX_STATS = 10
AutoSellRules.MAX_TYPES = 16

local function ID() return require(script.Parent:WaitForChild("ItemData")) end

-- the gun types (ItemData.WeaponGroups = the one place they are grouped) + the gear types; ids are saved, labels are text
local GEAR_TYPES = { { "Helmet", "HELMET" }, { "ChestPiece", "CHEST" }, { "Gloves", "GLOVES" }, { "Leggings", "LEGS" }, { "Boots", "BOOTS" },
    { "Ring", "RING" }, { "Necklace", "AMULET" } }
local typeCache = nil
function AutoSellRules.Types(): { any }
    if typeCache then return typeCache end
    local I = ID()
    local out = {}
    for _, g in ipairs(I.WeaponGroups.Order) do
        table.insert(out, { Id = g, Label = string.upper(I.WeaponGroups.Label[g] or g), Kind = "Weapon" })
    end
    for _, g in ipairs(GEAR_TYPES) do table.insert(out, { Id = "Gear:" .. g[1], Label = g[2], Kind = "Gear" }) end
    typeCache = out
    return out
end
function AutoSellRules.TypeOf(item: any, kind: string): string?
    local I = ID()
    if kind == "Gear" then return item and item.Slot and ("Gear:" .. I.GearType(item.Slot)) or nil end
    return I.WeaponGroupOf(item)
end

-- every stat that can roll on a gun or a piece of gear (the live pools), labelled from StatDefs; Where = "gun" | "gear" | "gun + gear"
local statCache, statSet = nil, nil
function AutoSellRules.Stats(): ({ any }, { [string]: any })
    if statCache then return statCache, statSet end
    local I = ID()
    local seen, out = {}, {}
    local function Add(stat: string, where: string)
        if type(stat) ~= "string" then return end
        local e = seen[stat]
        if e then
            if e.Where ~= where and e.Where ~= "gun + gear" then e.Where = "gun + gear" end
            return
        end
        local def = I.StatDefs[stat]
        e = { Id = stat, Label = (def and def.Label) or stat, Where = where }
        seen[stat] = e
        table.insert(out, e)
    end
    local pre, suf = I.WeaponAffixPools()
    for _, a in ipairs(pre or {}) do Add(a.Stat, "gun") end
    for _, a in ipairs(suf or {}) do Add(a.Stat, "gun") end
    for _, e in ipairs(I.GEAR_POOL_V3 or {}) do Add(e.Stat, "gear") end
    table.sort(out, function(a, b) return a.Label < b.Label end)
    statCache, statSet = out, seen
    return out, seen
end

function AutoSellRules.MaxTier(): number return #(ID().TIER_ILVL or {}) > 0 and #ID().TIER_ILVL or 15 end
function AutoSellRules.MaxSockets(): number
    local t = ID().SOCKETS and ID().SOCKETS.MaxByIlvl
    return (t and t[#t] and t[#t][2]) or 6
end
function AutoSellRules.MaxIlvl(): number local I = ID(); return math.max(I.MAX_LEVEL or 200, I.MAX_LEVEL_BUILT or 0) end

local function Int(v: any, lo: number, hi: number): number
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return 0 end
    return math.clamp(math.floor(v), lo, hi)
end

-- anything from a client / an old save -> a clean rules table, or nil when every rule is off
function AutoSellRules.Clean(raw: any): any?
    if type(raw) ~= "table" then return nil end
    local out = { MinSockets = Int(raw.MinSockets, 0, AutoSellRules.MaxSockets()), MinLinks = Int(raw.MinLinks, 0, AutoSellRules.MaxSockets()),
        MinIlvl = Int(raw.MinIlvl, 0, AutoSellRules.MaxIlvl()), Types = {}, Stats = {}, StatCount = 1 }
    if out.MinSockets < 2 then out.MinSockets = 0 end -- (every gun has a socket: "1 or more" would keep them all)
    if out.MinLinks < 2 then out.MinLinks = 0 end
    if type(raw.Types) == "table" then
        local valid = {}
        for _, t in ipairs(AutoSellRules.Types()) do valid[t.Id] = true end
        local had = {}
        for i = 1, math.min(#raw.Types, 40) do
            local id = raw.Types[i]
            if type(id) == "string" and valid[id] and not had[id] and #out.Types < AutoSellRules.MAX_TYPES then
                had[id] = true
                table.insert(out.Types, id)
            end
        end
    end
    if type(raw.Stats) == "table" then
        local _, set = AutoSellRules.Stats()
        local had = {}
        for i = 1, math.min(#raw.Stats, 40) do
            local s = raw.Stats[i]
            if type(s) == "table" and type(s.S) == "string" and set[s.S] and not had[s.S] and #out.Stats < AutoSellRules.MAX_STATS then
                had[s.S] = true
                table.insert(out.Stats, { S = s.S, T = Int(s.T, 0, AutoSellRules.MaxTier()) })
            end
        end
    end
    out.StatCount = math.clamp(Int(raw.StatCount, 1, AutoSellRules.MAX_STATS), 1, math.max(1, #out.Stats))
    if out.MinSockets == 0 and out.MinLinks == 0 and out.MinIlvl == 0 and #out.Types == 0 and #out.Stats == 0 then return nil end
    return out
end

-- the keep rule an item matches (player text), or nil
function AutoSellRules.Keeps(rules: any, item: any, kind: string): string?
    if type(rules) ~= "table" or type(item) ~= "table" then return nil end
    local I = ID()
    if kind == "Weapon" and ((rules.MinSockets or 0) >= 2 or (rules.MinLinks or 0) >= 2) then
        local _, n, big = I.SocketGroups(item.Sockets)
        if (rules.MinSockets or 0) >= 2 and n >= rules.MinSockets then return n .. " sockets" end
        if (rules.MinLinks or 0) >= 2 and big >= rules.MinLinks then return big .. "-link" end
    end
    if (rules.MinIlvl or 0) > 0 and (tonumber(item.ItemLevel) or 0) >= rules.MinIlvl then return "item level " .. tostring(item.ItemLevel) end
    if type(rules.Types) == "table" and #rules.Types > 0 then
        local id = AutoSellRules.TypeOf(item, kind)
        if id and table.find(rules.Types, id) then
            for _, t in ipairs(AutoSellRules.Types()) do if t.Id == id then return "type " .. t.Label end end
        end
    end
    if type(rules.Stats) == "table" and #rules.Stats > 0 then
        local want = {}
        for _, s in ipairs(rules.Stats) do want[s.S] = s.T or 0 end
        local hit, names = 0, {}
        local _, set = AutoSellRules.Stats()
        for _, l in ipairs(I.LinesOf(item, kind == "Gear")) do
            local need = type(l) == "table" and want[l.Stat]
            -- (a line without a tier = a fixed build line: it counts at any tier; a negative line never counts)
            if need and (tonumber(l.Value) or 1) > 0 and (l.Tier == nil or (tonumber(l.Tier) or 0) >= need) then
                want[l.Stat] = nil -- (each picked stat counts once)
                hit += 1
                table.insert(names, set[l.Stat] and set[l.Stat].Label or l.Stat)
            end
        end
        if hit >= math.max(1, rules.StatCount or 1) then return table.concat(names, " + ") end
    end
    return nil
end

-- THE TEST: sells?, why (player text)
function AutoSellRules.Decide(threshold: any, rules: any, item: any, kind: string): (boolean, string)
    if kind ~= "Weapon" and kind ~= "Gear" then return false, "not a gun or gear" end
    if type(item) ~= "table" then return false, "no item" end
    local I = ID()
    if item.Exotic or (I.ZenithOf and I.ZenithOf(item)) then return false, "relics are never auto-sold" end
    local th = (type(threshold) == "string" and I.RarityRank[threshold]) or 0
    if th <= 0 then return false, "auto-sell is off" end
    if (I.RarityRank[item.Rarity] or 1) > th then return false, "above the rarity" end
    local why = AutoSellRules.Keeps(rules, item, kind)
    if why then return false, "kept: " .. why end
    return true, "sold"
end

-- one short line for buttons / menus: "RARE + 3 KEEP RULES"
function AutoSellRules.Count(rules: any): number
    local r = AutoSellRules.Clean(rules)
    if not r then return 0 end
    local n = 0
    if r.MinSockets > 0 then n += 1 end
    if r.MinLinks > 0 then n += 1 end
    if r.MinIlvl > 0 then n += 1 end
    if #r.Types > 0 then n += 1 end
    if #r.Stats > 0 then n += 1 end
    return n
end
function AutoSellRules.Short(threshold: any, rules: any): string
    local th = string.upper(tostring(threshold or "OFF"))
    local n = AutoSellRules.Count(rules)
    if th == "OFF" or n == 0 then return th end
    return th .. " + " .. n .. " KEEP RULE" .. (n == 1 and "" or "S")
end

-- ===================================== THE WINDOW (client) =====================================
-- hooks = { Parent (the HUD ScreenGui), State() -> clientState, Save(threshold, rules) -> (ok, msg), Toast(text), Click(),
--           Tip(gui, getLines) (the client's HookTooltip), CloseWith (a window: closing it closes this) }
local open = nil
function AutoSellRules.Close()
    if open then
        local o = open
        open = nil
        if o.Root then o.Root:Destroy() end
        for _, c in ipairs(o.Conns or {}) do c:Disconnect() end
    end
end
function AutoSellRules.IsOpen(): boolean return open ~= nil end

function AutoSellRules.Open(hooks: any)
    AutoSellRules.Close()
    local I = ID()
    local Shared = script.Parent
    local UIStyle = require(Shared:WaitForChild("UIStyle"))
    local PopupUI = require(Shared:WaitForChild("PopupUI"))
    local UIS = game:GetService("UserInputService")
    local GuiService = game:GetService("GuiService")
    local C = UIStyle.Colors
    local New = UIStyle.New
    local state = (hooks.State and hooks.State()) or {}
    local W, H = 600, 700
    local rec = { Conns = {} }
    open = rec

    local threshold = (type(state.AutoSellThreshold) == "string" and (state.AutoSellThreshold == "OFF" or I.RarityRank[state.AutoSellThreshold])) and state.AutoSellThreshold or "OFF"
    local startThreshold = threshold
    local base = AutoSellRules.Clean(state.AutoSellRules) or {}
    local draft = { MinSockets = base.MinSockets or 0, MinLinks = base.MinLinks or 0, MinIlvl = base.MinIlvl or 0, Types = table.clone(base.Types or {}),
        Stats = {}, StatCount = base.StatCount or 1 }
    for _, s in ipairs(base.Stats or {}) do table.insert(draft.Stats, { S = s.S, T = s.T }) end

    local function Click() if hooks.Click then hooks.Click() end end
    local function M(o: Instance) o:SetAttribute("Skinned", true); return o end
    local function Lbl(parent: Instance, role: string, props: any): TextLabel
        props.Parent = parent
        props.BackgroundTransparency = 1
        props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
        local l = M(UIStyle.Text(props)) :: TextLabel
        UIStyle.TextRole(l, role, props.TextColor3 and { Keep = true } or nil)
        return l
    end
    local function Tip(gui: GuiObject, title: string, body: string)
        if hooks.Tip then hooks.Tip(gui, function() return { { Text = title, Bold = true, Size = 14 }, { Text = body, Color = C.Sub } }, C.Text end) end
    end

    -- root: a full-screen shade (click = cancel) + the window, on the popup layer of the HUD gui (its item / hint cards draw over it)
    local root = M(New("Frame", { Name = "AutoSellPanel", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = UIStyle.Z.Popup, Parent = hooks.Parent }))
    root:SetAttribute("NoSkin", true)
    rec.Root = root
    local shade = M(New("TextButton", { Name = "Shade", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Ink, BackgroundTransparency = 0.3,
        Size = UDim2.fromScale(1, 1), Parent = root }))
    local win = M(New("Frame", { Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H),
        BackgroundColor3 = C.Bg0, BackgroundTransparency = UIStyle.WINDOW_T or 0.04, BorderSizePixel = 0, Active = true, Parent = root }))
    do local st = UIStyle.Stroke(C.Text, 1); st.Transparency = 0.84; st.Parent = win end
    local fit = New("UIScale", { Name = "FitScale", Parent = win }) :: UIScale
    local function Fit()
        local gui = root:FindFirstAncestorWhichIsA("LayerCollector")
        local hs = gui and gui:FindFirstChildOfClass("UIScale")
        local k = math.max((hs and hs.Scale) or 1, 0.05)
        local vs = UIStyle.Screen()
        local sk = UIStyle.SimK()
        local inset = UIStyle.TopInset()
        local t = UIStyle.IsPhone() and UIStyle.PhoneScale() or math.min(1, (vs.X - 32) / W)
        local h = math.min(H, (vs.Y - inset - 20) / t)
        win.Size = UDim2.fromOffset(W, math.floor(h))
        fit.Scale = t * sk / k
        win.Position = UDim2.new(0.5, 0, 0.5, (inset / 2) * sk / k)
    end
    Fit()
    if workspace.CurrentCamera then table.insert(rec.Conns, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Fit)) end

    local Close = function() Click(); AutoSellRules.Close() end
    UIStyle.TitleBar(win, "AUTO-SELL", C.Text, "Sells drops at or under a rarity. KEEP rules protect the rest.", Close)
    shade.MouseButton1Click:Connect(Close)
    table.insert(rec.Conns, UIS.InputBegan:Connect(function(io, gp)
        if io.KeyCode == Enum.KeyCode.Escape or io.KeyCode == Enum.KeyCode.ButtonB then AutoSellRules.Close() end
    end))
    if hooks.CloseWith then
        table.insert(rec.Conns, hooks.CloseWith:GetPropertyChangedSignal("Visible"):Connect(function() if not hooks.CloseWith.Visible then AutoSellRules.Close() end end))
    end

    local body = M(New("ScrollingFrame", { Name = "Body", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 74),
        Size = UDim2.new(1, 0, 1, -74 - 68), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarImageColor3 = C.Sub, Parent = win }))
    New("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 12), Parent = body })
    New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
    M(New("Frame", { Name = "FootRule", BorderSizePixel = 0, BackgroundColor3 = C.Line, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -68),
        Size = UDim2.new(1, 0, 0, 1), Parent = win }))

    -- small building blocks (all flat: hairlines, raised Bg1 cards, the 2 px mark on a picked chip)
    local order = 0
    local function Next() order += 1; return order end
    local function Head(text: string)
        local f = M(New("Frame", { Name = "Head", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = Next(), Parent = body }))
        Lbl(f, "SectionHead", { Text = text, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 20) })
        return f
    end
    local function Note(text: string, color: Color3?)
        local l = Lbl(body, "Meta", { Text = text, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, LayoutOrder = Next(), TextColor3 = color })
        return l
    end
    local function Chip(parent: Instance, text: string, col: Color3?, on: boolean, onClick: () -> ()): TextButton
        local b = M(New("TextButton", { Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = on and C.Bg2 or C.Bg1, Parent = parent }))
        b:SetAttribute("NoNeon", true)
        local st = UIStyle.Stroke(C.Text, 1); st.Transparency = on and 0.6 or 0.88; st.Parent = b
        local l = Lbl(b, "Button", { Text = text, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = col or (on and C.Text or C.Sub),
            TextTruncate = Enum.TextTruncate.AtEnd })
        l.TextSize = 14
        if on then
            M(New("Frame", { Name = "Mark", BorderSizePixel = 0, BackgroundColor3 = col or C.Text, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
                Size = UDim2.new(1, 0, 0, 2), Parent = b }))
        end
        b.MouseEnter:Connect(function() b.BackgroundColor3 = C.Bg2 end)
        b.MouseLeave:Connect(function() b.BackgroundColor3 = on and C.Bg2 or C.Bg1 end)
        b.MouseButton1Click:Connect(function() Click(); onClick() end)
        return b
    end
    local function Grid(cols: number, n: number, h: number?)
        local rows = math.ceil(n / cols)
        local ch = h or 40
        local f = M(New("Frame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, rows * ch + (rows - 1) * 6), LayoutOrder = Next(), Parent = body }))
        New("UIGridLayout", { CellSize = UDim2.new(1 / cols, -math.ceil(6 * (cols - 1) / cols), 0, ch), CellPadding = UDim2.fromOffset(6, 6),
            SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
        return f
    end
    local function Step(parent: Instance, text: string, x: number, onClick: () -> ())
        local b = UIStyle.Button(parent, text, C.Bg1, UDim2.fromOffset(40, 40), UDim2.new(1, x, 0.5, -20))
        b.Label.TextSize = 24
        b.Label.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold)
        b.Label:SetAttribute("KeepFont", true)
        b.Button.MouseButton1Click:Connect(function() Click(); onClick() end)
        return b
    end
    -- a rule card: name + hint on the left, [-] value [+] on the right; value = a TextBox when typeable
    local function RuleCard(name: string, hint: string, tipBody: string, valueText: string, active: boolean, onMinus: () -> (), onPlus: () -> (), onType: ((string) -> ())?)
        local card = M(New("Frame", { Name = "Rule_" .. name, BackgroundColor3 = C.Bg1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 58), LayoutOrder = Next(), Parent = body }))
        if active then M(New("Frame", { Name = "On", BorderSizePixel = 0, BackgroundColor3 = C.Text, Size = UDim2.new(0, 2, 1, 0), Parent = card })) end
        local nm = Lbl(card, "SectionHead", { Text = name, Position = UDim2.fromOffset(14, 9), Size = UDim2.new(1, -220, 0, 20), TextColor3 = active and C.Text or C.Sub })
        Lbl(card, "Meta", { Text = hint, Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -220, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
        Step(card, "−", -196, onMinus)
        Step(card, "+", -50, onPlus)
        local valueBox
        if onType then
            valueBox = M(New("TextBox", { Name = "Value", Text = valueText, ClearTextOnFocus = true, PlaceholderText = "OFF", BackgroundColor3 = C.Well, BorderSizePixel = 0,
                AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -150, 0.5, 0), Size = UDim2.fromOffset(94, 40), TextColor3 = active and C.Text or C.Sub,
                Font = Enum.Font.GothamBold, TextSize = 15, Parent = card }))
            do local st = UIStyle.Stroke(C.Text, 1); st.Transparency = 0.86; st.Parent = valueBox end
            valueBox.FocusLost:Connect(function() onType(valueBox.Text) end)
        else
            valueBox = Lbl(card, "Value", { Text = valueText, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -150, 0.5, 0), Size = UDim2.fromOffset(94, 40),
                TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = active and C.Text or C.Sub })
        end
        valueBox.Name = "Value"
        Tip(card, name, tipBody)
        return card
    end

    local Render
    local previewLbl
    local function Preview()
        if not previewLbl then return end
        local rules = AutoSellRules.Clean(draft)
        local sold, kept, above, n = 0, 0, 0, 0
        local function Run(list: any, kind: string)
            for _, it in ipairs(type(list) == "table" and list or {}) do
                n += 1
                local sells, why = AutoSellRules.Decide(threshold, rules, it, kind)
                if sells then sold += 1
                elseif string.sub(why, 1, 5) == "kept:" then kept += 1
                else above += 1 end
            end
        end
        Run(state.Inventory, "Weapon")
        Run(state.GearInventory, "Gear")
        if threshold == "OFF" then
            previewLbl.Text = "Auto-sell is OFF: every drop is kept."
        else
            previewLbl.Text = string.format("If the %d guns + gear in your bag dropped now: %d would SELL, %d kept by a rule, %d above the rarity.", n, sold, kept, above)
        end
        win:SetAttribute("PreviewSold", sold); win:SetAttribute("PreviewKept", kept); win:SetAttribute("PreviewAbove", above)
    end

    Render = function()
        for _, c in ipairs(body:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        order = 0
        -- 1. the rarity
        Head("SELL AT OR UNDER")
        local list = { "OFF" }
        for i, r in ipairs(I.Rarities) do if i <= (I.RarityRank.Mythic or 4) then table.insert(list, r) end end
        local g = Grid(#list, #list)
        for i, r in ipairs(list) do
            local c = Chip(g, string.upper(r), (r ~= "OFF") and I.RarityColors[r] or nil, threshold == r, function() threshold = r; Render() end)
            c.Name = "Rarity_" .. r
            c.LayoutOrder = i
            Tip(c, (r == "OFF") and "Auto-sell off" or ("Sell " .. string.upper(r) .. " and below"),
                (r == "OFF") and "Nothing is sold as it drops." or ("New " .. string.upper(r) .. " drops and everything under them are sold for gold as they drop, unless a KEEP rule below matches. Relics are never sold."))
        end
        Note("Relics, Zeniths and items a reward promises you are never auto-sold. Auto-sold items can be bought back for what they sold for (SELL > BUYBACK, your last 10).")

        -- 2. the keep rules
        local h = Head("KEEP RULES")
        local clear = UIStyle.Button(h, "CLEAR ALL", C.Bg1, UDim2.fromOffset(110, 26), UDim2.new(1, -110, 0, 4), "ClearRules")
        clear.Label.TextSize = 13
        clear.Button.MouseButton1Click:Connect(function() Click(); draft.MinSockets, draft.MinLinks, draft.MinIlvl, draft.Types, draft.Stats, draft.StatCount = 0, 0, 0, {}, {}, 1; Render() end)
        Note("An item that matches ANY rule here is kept, whatever its rarity. Rules you leave OFF do nothing.", C.Sub)
        local maxS = AutoSellRules.MaxSockets()
        RuleCard("SOCKETS", "Keep guns with at least this many sockets", "Keeps any gun with at least this many sockets, linked or not. 3 sockets roll from item level 10, 4 from 25, 5 from 50, 6 from 100.",
            draft.MinSockets > 0 and (draft.MinSockets .. "+") or "OFF", draft.MinSockets > 0,
            function() draft.MinSockets = (draft.MinSockets <= 2) and 0 or draft.MinSockets - 1; Render() end,
            function() draft.MinSockets = math.min(maxS, math.max(2, draft.MinSockets + 1)); Render() end)
        RuleCard("LINKED SOCKETS", "Keep guns whose biggest linked group is at least this big", "Keeps any gun with a linked group of at least this size (sockets joined by a bar). Only the biggest linked group's mods work.",
            draft.MinLinks > 0 and (draft.MinLinks .. "-LINK") or "OFF", draft.MinLinks > 0,
            function() draft.MinLinks = (draft.MinLinks <= 2) and 0 or draft.MinLinks - 1; Render() end,
            function() draft.MinLinks = math.min(maxS, math.max(2, draft.MinLinks + 1)); Render() end)
        local maxI = I.MAX_LEVEL or 200
        RuleCard("ITEM LEVEL", "Keep anything at or above this item level (tap to type)", "Keeps any gun or gear piece of at least this item level. Item level decides the best tiers its lines can roll (T6 from 65, T8 from 100 ...).",
            draft.MinIlvl > 0 and tostring(draft.MinIlvl) or "OFF", draft.MinIlvl > 0,
            function() draft.MinIlvl = (draft.MinIlvl <= 5) and 0 or draft.MinIlvl - 5; Render() end,
            function() draft.MinIlvl = math.min(maxI, (draft.MinIlvl < 5) and 5 or draft.MinIlvl + 5); Render() end,
            function(txt) local v = tonumber(string.match(txt or "", "%d+")); draft.MinIlvl = v and math.clamp(math.floor(v), 0, maxI) or 0; Render() end)

        -- types
        local types = AutoSellRules.Types()
        local th = Head("ITEM TYPES")
        th.Name = "TypesHead"
        Note("Keep every item of the types you pick: a gun class, or a gear slot.")
        local tg = Grid(4, #types, 38)
        for i, t in ipairs(types) do
            local on = table.find(draft.Types, t.Id) ~= nil
            local c = Chip(tg, t.Label, nil, on, function()
                local at = table.find(draft.Types, t.Id)
                if at then table.remove(draft.Types, at) else table.insert(draft.Types, t.Id) end
                Render()
            end)
            c.Name = "Type_" .. t.Id
            c.LayoutOrder = i
            Tip(c, t.Label, (t.Kind == "Weapon") and ("Keeps every " .. t.Label .. " gun you find, at any rarity.") or ("Keeps every " .. t.Label .. " piece you find, at any rarity."))
        end

        -- stats
        local sh = Head("STATS")
        sh.Name = "StatsHead"
        local nStats = #draft.Stats
        draft.StatCount = math.clamp(draft.StatCount or 1, 1, math.max(1, nStats))
        if nStats > 0 then
            RuleCard("LINES NEEDED", string.format("Keep when it has at least %d of the %d stat%s below", draft.StatCount, nStats, nStats == 1 and "" or "s"),
                "1 = any one of these lines keeps the item. More = it needs that many of them (each at its tier or better), e.g. crit chance AND crit damage.",
                tostring(draft.StatCount), true,
                function() draft.StatCount = math.max(1, draft.StatCount - 1); Render() end,
                function() draft.StatCount = math.min(nStats, draft.StatCount + 1); Render() end)
        else
            Note("Pick the stat lines you hunt for. An item with one (at the tier you pick or better) is kept.")
        end
        local all, set = AutoSellRules.Stats()
        local maxT = AutoSellRules.MaxTier()
        for i, s in ipairs(draft.Stats) do
            local e = set[s.S]
            local row = M(New("Frame", { Name = "Stat_" .. s.S, BackgroundColor3 = C.Bg1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = Next(), Parent = body }))
            M(New("Frame", { Name = "On", BorderSizePixel = 0, BackgroundColor3 = C.Text, Size = UDim2.new(0, 2, 1, 0), Parent = row }))
            local nm = Lbl(row, "Body", { Text = string.upper(e and e.Label or s.S), Position = UDim2.fromOffset(14, 7), Size = UDim2.new(1, -270, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
            nm.FontFace = UIStyle.RoleFace("Label")
            Lbl(row, "Meta", { Text = "on " .. (e and e.Where or "gun + gear"), Position = UDim2.fromOffset(14, 27), Size = UDim2.new(1, -270, 0, 18) })
            Step(row, "−", -246, function() s.T = math.max(0, (s.T or 0) - 1); Render() end)
            Lbl(row, "Value", { Name = "Tier", Text = (s.T or 0) > 0 and ("T" .. s.T .. "+") or "ANY TIER", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -200, 0.5, 0),
                Size = UDim2.fromOffset(94, 40), TextXAlignment = Enum.TextXAlignment.Center })
            Step(row, "+", -100, function() s.T = math.min(maxT, (s.T or 0) + 1); Render() end)
            local x = UIStyle.Button(row, "X", C.Bg1, UDim2.fromOffset(40, 40), UDim2.new(1, -50, 0.5, -20), "Remove")
            x.Label.TextSize = 16
            x.SetQuiet(true)
            x.Button.MouseButton1Click:Connect(function() Click(); table.remove(draft.Stats, i); Render() end)
            Tip(nm, e and e.Label or s.S, "Counts when the item has this line at " .. ((s.T or 0) > 0 and ("tier " .. s.T .. " or better") or "any tier") .. ". Higher tiers roll at higher item levels. X removes it.")
        end
        if nStats < AutoSellRules.MAX_STATS then
            local addRow = M(New("Frame", { Name = "AddStatRow", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = Next(), Parent = body }))
            local add = UIStyle.Button(addRow, "+ ADD A STAT", C.Bg1, UDim2.fromOffset(200, 40), UDim2.fromOffset(0, 1), "AddStat")
            add.Label.TextSize = 14
            add.Button.MouseButton1Click:Connect(function()
                Click()
                local items = {}
                for _, e in ipairs(all) do
                    local have = false
                    for _, s in ipairs(draft.Stats) do if s.S == e.Id then have = true end end
                    if not have then table.insert(items, { Text = string.upper(e.Label) .. "   (" .. e.Where .. ")", Value = e.Id }) end
                end
                PopupUI.Dropdown(add.Button, items, function(id)
                    if #draft.Stats < AutoSellRules.MAX_STATS then table.insert(draft.Stats, { S = id, T = 0 }) end
                    Render()
                end)
            end)
            Tip(add.Button, "Add a stat", "Pick from every line a gun or gear piece can roll. Up to " .. AutoSellRules.MAX_STATS .. " stats.")
        end

        -- 3. what it means for your bag right now
        Head("IN YOUR BAG RIGHT NOW")
        previewLbl = Note("", C.Text)
        previewLbl.Name = "Preview"
        Preview()
    end
    Render()

    -- footer: CANCEL / SAVE
    local cancel = UIStyle.Button(win, "CANCEL", C.Bg1, UDim2.fromOffset(150, 44), UDim2.new(1, -332, 1, -56), "Cancel")
    cancel.Button.MouseButton1Click:Connect(Close)
    local save = UIStyle.Button(win, "SAVE", C.Accent, UDim2.fromOffset(160, 44), UDim2.new(1, -176, 1, -56), "Save")
    local summary = Lbl(win, "Meta", { Name = "Summary", Text = "", Position = UDim2.new(0, 20, 1, -56), Size = UDim2.new(1, -372, 0, 44), TextWrapped = true })
    local function Sum() summary.Text = "Auto-sell: " .. AutoSellRules.Short(threshold, draft) end
    Sum()
    local renderInner = Render
    Render = function() renderInner(); Sum() end
    local function DoSave()
        task.spawn(function()
            local ok, msg = false, nil
            if hooks.Save then ok, msg = hooks.Save(threshold, draft) end
            if hooks.Toast then hooks.Toast(tostring(msg or (ok and ("Auto-sell saved: " .. AutoSellRules.Short(threshold, draft)) or "Couldn't save auto-sell."))) end
            if ok then AutoSellRules.Close() end
        end)
    end
    save.Button.MouseButton1Click:Connect(function()
        Click()
        local r = I.RarityRank[threshold] or 0
        if threshold ~= startThreshold and r >= (I.RarityRank.Rare or 3) then
            PopupUI.Confirm("Are you sure?", "This sells new " .. string.upper(threshold) .. " drops and everything below them, unless a keep rule matches. Only the last 10 items you sell can be bought back (BUYBACK, this session).",
                "YES, " .. string.upper(threshold), I.RarityColors[threshold] or C.Accent, DoSave)
        else
            DoSave()
        end
    end)
    rec.Save = DoSave
    rec.Draft = draft
    rec.SetThreshold = function(t) threshold = t; Render() end
    rec.Render = function() Render() end
    if UIStyle.InstallType then pcall(UIStyle.InstallType, root) end
    if UIStyle.Motion and UIStyle.Motion.Open then pcall(UIStyle.Motion.Open, win, nil) end
    return rec
end
-- (Studio tests) the open window's draft + save / render
function AutoSellRules.Current(): any return open end

return AutoSellRules
