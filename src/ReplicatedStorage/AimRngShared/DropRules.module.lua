--!nocheck
-- ============================================================================================
-- DROP RULES (UPDATE 7 C9, the loot filter; placeholder name): a short ordered list of rules that change how a drop on the
-- ground looks for YOU. Each rule: { K = kind ("Any" | "Weapon" | "Gear" | "Gem"), Op = ">=" | "<", R = a rarity,
-- T = words to find in the item's name / type / lines ("" = any), A = "Hide" | "Glow" | "Show" }. The FIRST rule that
-- matches wins; no match = the normal look. Hide = no beam, light, tag or sound (it can still be picked up); Glow = a gold
-- outline, a taller beam, a far-seen tag and a drop sound. Exotics are never hidden.
-- Saved on the server (state.DropRules, PLAIN_FIELDS) through the DropRulesAction remote; cap BASE + MasteryRank perks.
-- Client: GroundLoot asks DropRules.Match(rules, item, kind); the window = DropRules.Open (Settings > Gameplay > Drop Rules).
-- ============================================================================================
local DropRules = {}

DropRules.BASE = 4
DropRules.KINDS = { "Any", "Weapon", "Gear", "Gem" }
DropRules.ACTIONS = { "Hide", "Glow", "Show" }
DropRules.OPS = { ">=", "<" }
DropRules.MAX_TEXT = 24
DropRules.GLOW = Color3.fromRGB(255, 214, 90)

local function ID() return require(script.Parent:WaitForChild("ItemData")) end

function DropRules.Max(state: any): number
    local MR = require(script.Parent:WaitForChild("MasteryRank"))
    return DropRules.BASE + (MR.ExtraDropRules and MR.ExtraDropRules(MR.Rank(state)) or 0)
end

-- a list from the client -> a clean list (or nil): known values only, at most Max rules
function DropRules.Clean(list: any, state: any): { any }?
    if type(list) ~= "table" then return nil end
    local I = ID()
    local out = {}
    for i = 1, math.min(#list, DropRules.Max(state)) do
        local r = list[i]
        if type(r) ~= "table" then return nil end
        local k = table.find(DropRules.KINDS, r.K) and r.K or "Any"
        local op = table.find(DropRules.OPS, r.Op) and r.Op or ">="
        local rar = I.NormRarity(r.R) -- (UPDATE 8 RARITY v4: an old name -> its new rarity)
        rar = (rar and rawget(I.RarityRank, rar)) and rar or "Common"
        local a = table.find(DropRules.ACTIONS, r.A) and r.A or "Show"
        local t = type(r.T) == "string" and string.sub(string.gsub(r.T, "[%c]", ""), 1, DropRules.MAX_TEXT) or ""
        table.insert(out, { K = k, Op = op, R = rar, T = t, A = a })
    end
    return out
end

-- the words a rule's text is matched against (lower case)
local function Words(item: any, kind: string): string
    local I = ID()
    local parts = { tostring(item.Name or ""), tostring(item.Rarity or "") }
    if kind == "Weapon" then
        table.insert(parts, tostring(item.BaseId or ""))
        local ok, tn = pcall(I.WeaponTypeName, item)
        if ok and tn then table.insert(parts, tostring(tn)) end
    elseif kind == "Gear" then
        table.insert(parts, tostring(item.Slot or ""))
    end
    if kind ~= "Gem" then
        if I.HasTopTierLine(item) then table.insert(parts, "top tier toptier") end -- (RARITY v4: filter the item-level chase)
        for _, l in ipairs(I.LinesOf(item, kind == "Gear")) do
            local def = I.StatDefs[l.Stat]
            table.insert(parts, def and def.Label or tostring(l.Stat))
        end
    end
    return string.lower(table.concat(parts, " "))
end

-- the action for a drop ("Hide" | "Glow" | nil = normal)
function DropRules.Match(rules: any, item: any, kind: string?): string?
    if type(rules) ~= "table" or type(item) ~= "table" then return nil end
    local I = ID()
    kind = kind or "Weapon"
    local rank = I.RarityRank[item.Rarity] or 1
    local words
    for _, r in ipairs(rules) do
        local kindOk = r.K == "Any" or r.K == kind
        local rr = I.RarityRank[r.R] or 1
        local rarOk = (r.Op == "<") and (rank < rr) or (r.Op ~= "<" and rank >= rr)
        local textOk = true
        if kindOk and rarOk and type(r.T) == "string" and r.T ~= "" then
            words = words or Words(item, kind)
            textOk = string.find(words, string.lower(r.T), 1, true) ~= nil
        end
        if kindOk and rarOk and textOk then
            if r.A == "Hide" and item.Exotic then return nil end
            return (r.A ~= "Show") and r.A or nil
        end
    end
    return nil
end

-- ===== the window (client) =====
-- DropRules.Open(parentGui, hooks { GetState, Save(list) -> (ok, msg), Toast, Click })
local openFrame: Frame? = nil
function DropRules.Open(parentGui: Instance, hooks: any)
    local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
    local I = ID()
    local C = UIStyle.Colors
    local New, Text = UIStyle.New, UIStyle.Text
    if openFrame and openFrame.Parent then openFrame:Destroy() end
    local state = hooks.GetState and hooks.GetState() or {}
    local list = DropRules.Clean(state.DropRules, state) or {}
    local max = DropRules.Max(state)
    local root = UIStyle.Panel(parentGui, { Name = "DropRulesWindow", Size = UDim2.fromOffset(820, 560), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
    openFrame = root
    UIStyle.TitleBar(root, "LOOT LENS", C.Accent, "Change how drops on the ground look for you. The first rule that matches a drop wins.", function() root:Destroy() end)
    root.Visible = true
    local body = New("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 1, -150), Parent = root })
    local count = Text({ Position = UDim2.new(0, 16, 1, -64), Size = UDim2.fromOffset(330, 20), Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, Parent = root })
    local Render
    local function Cycle(options, cur)
        local i = table.find(options, cur) or 0
        return options[(i % #options) + 1]
    end
    local rarities = I.Rarities
    Render = function()
        for _, c in ipairs(body:GetChildren()) do c:Destroy() end
        count.Text = string.format("%d / %d rules  •  hidden drops can still be picked up  •  relics are never hidden", #list, max)
        for _, h in ipairs({ { 10, "#" }, { 40, "KIND" }, { 156, "RARITY" }, { 396, "WORDS" }, { 614, "DO" } }) do
            Text({ Position = UDim2.fromOffset(h[1], 0), Size = UDim2.fromOffset(220, 18), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, Text = h[2], Parent = body })
        end
        for i, r in ipairs(list) do
            local y = 24 + (i - 1) * 50
            local row = UIStyle.Card(body, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 44) })
            Text({ Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(24, 44), Text = tostring(i), TextSize = 18, Parent = row })
            local function Btn(label, x, w, color, fn)
                local b = UIStyle.Button(row, label, color or C.Bg2, UDim2.fromOffset(w, 32), UDim2.fromOffset(x, 6), "R" .. i .. "_" .. x)
                b.Label.TextSize = 13
                b.Button.MouseButton1Click:Connect(function() if hooks.Click then hooks.Click() end; fn(); Render() end)
                return b
            end
            Btn(string.upper(r.K), 40, 110, nil, function() r.K = Cycle(DropRules.KINDS, r.K) end)
            Btn(r.Op == "<" and "BELOW" or "AT LEAST", 156, 96, nil, function() r.Op = Cycle(DropRules.OPS, r.Op) end)
            local rb = Btn(string.upper(r.R), 258, 130, nil, function() r.R = Cycle(rarities, r.R) end)
            rb.Label.TextColor3 = I.RarityColors and I.RarityColors[r.R] or C.Text
            local box = New("TextBox", { Position = UDim2.fromOffset(396, 6), Size = UDim2.fromOffset(210, 32), BackgroundColor3 = C.Well or C.Bg0, BorderSizePixel = 0,
                Text = r.T, PlaceholderText = "any", ClearTextOnFocus = false, Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Text, Parent = row })
            box.FocusLost:Connect(function() r.T = string.sub(box.Text, 1, DropRules.MAX_TEXT) end)
            local actCol = (r.A == "Hide" and C.Steel) or (r.A == "Glow" and C.Accent) or C.Bg2
            Btn(string.upper(r.A), 614, 90, actCol, function() r.A = Cycle(DropRules.ACTIONS, r.A) end)
            Btn("X", 712, 40, C.Red, function() table.remove(list, i) end)
        end
        if #list == 0 then
            Text({ Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 60), Font = UIStyle.BodyFont, TextSize = 14, TextWrapped = true, TextColor3 = C.Sub,
                Text = "No rules yet: every drop looks normal. Try HIDE for any drop BELOW RARE, or GLOW for a weapon AT LEAST MYTHIC with \"weak-spot\".", Parent = body })
        end
    end
    local add = UIStyle.Button(root, "ADD RULE", C.Steel, UDim2.fromOffset(150, 40), UDim2.new(1, -332, 1, -72), "AddRule")
    add.Button.MouseButton1Click:Connect(function()
        if #list >= max then if hooks.Toast then hooks.Toast("You have every rule slot (more come with Marksman Grades).") end; return end
        if hooks.Click then hooks.Click() end
        table.insert(list, { K = "Any", Op = "<", R = "Rare", T = "", A = "Hide" })
        Render()
    end)
    local save = UIStyle.Button(root, "SAVE", C.Accent, UDim2.fromOffset(150, 40), UDim2.new(1, -166, 1, -72), "SaveRules")
    save.Button.MouseButton1Click:Connect(function()
        if hooks.Click then hooks.Click() end
        task.spawn(function()
            local ok, msg = false, "?"
            if hooks.Save then ok, msg = hooks.Save(list) end
            if hooks.Toast then hooks.Toast(tostring(msg or (ok and "Drop rules saved." or "Couldn't save."))) end
        end)
    end)
    Render()
    return root
end

return DropRules
