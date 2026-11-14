--!nocheck
-- ADMIN MENU (client). Only builds for admins (the server's AdminAction "Check"); opened with F6. Pick a player on the
-- left, then one of three tabs:
--   GIFTS     GIVE / TAKE any cosmetic, the premium season pass, or everything premium at once (+ a search box)
--   COMMANDS  every admin command (AimRngShared.AdminCommands: levels, gold, guns, floors, bosses, teleports, ...)
--   ERRORS    the live error log
--   MUSIC     (2026-10-24) the dev music audition (AimRngShared/MusicAudition: built the first time the tab opens)
-- Both lists are built from the game's own catalogs each time the menu opens, so new skins / guns / bosses show up here
-- without touching this file. The server (AdminService) re-checks every action, so the panel itself grants nothing.
-- AdminPanel.Init(parent, api) -- api = { Open(frame), Close(), Toast(msg), Click() }
local Shared = script.Parent
local UIS = game:GetService("UserInputService")
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local AdminCommands = require(Shared:WaitForChild("AdminCommands"))

local AdminPanel = {}
AdminPanel.KEY = Enum.KeyCode.F6

local CAT_ORDER = { "Bundle", "WeaponSkin", "MeleeSkin", "Glove", "Sleeve", "HudTheme", "HealthBar", "KillEffect", "Colorway", "BoundPoints", "HideoutTheme", "HideoutStash", "HideoutPortal" }
local DARK = Color3.fromRGB(20, 23, 32)
local MUTED = Color3.fromRGB(110, 116, 130)

local function Box(parent, props)
    local tb = Instance.new("TextBox")
    tb.BackgroundColor3 = DARK; tb.BorderSizePixel = 0; tb.ClearTextOnFocus = false; tb.Text = props.Text or ""
    tb.PlaceholderText = props.Placeholder or ""; tb.PlaceholderColor3 = MUTED; tb.TextColor3 = Color3.fromRGB(235, 235, 240)
    tb.Font = Enum.Font.GothamMedium; tb.TextSize = props.TextSize or 14; tb.TextXAlignment = Enum.TextXAlignment.Left
    tb.ClipsDescendants = true
    tb.Size = props.Size; tb.Position = props.Position or UDim2.new(); tb.Name = props.Name or "Box"; tb.ZIndex = props.ZIndex or 1
    tb.Parent = parent
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 4)
    local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8); pad.Parent = tb
    return tb
end
local function Scroller(parent, pos, size, pad)
    local s = Instance.new("ScrollingFrame")
    s.BackgroundTransparency = 1; s.BorderSizePixel = 0; s.Position = pos; s.Size = size
    s.ScrollBarThickness = 8; s.AutomaticCanvasSize = Enum.AutomaticSize.Y; s.CanvasSize = UDim2.new(); s.Parent = parent
    local l = Instance.new("UIListLayout"); l.Padding = UDim.new(0, pad or 4); l.SortOrder = Enum.SortOrder.LayoutOrder; l.Parent = s
    return s
end
local function Words(text)
    local w = {}
    for x in string.gmatch(string.lower(text or ""), "%S+") do table.insert(w, x) end
    return w
end
local function Matches(hay, words)
    hay = string.lower(hay)
    for _, w in ipairs(words) do if not string.find(hay, w, 1, true) then return false end end
    return true
end

function AdminPanel.Init(parent: Instance, api: any)
    local fn = Remotes.GetFunction("AdminAction")
    local ok, isAdmin = pcall(function() return fn:InvokeServer("Check") end)
    if not (ok and isAdmin == true) then return nil end

    local GOLD = Color3.fromRGB(255, 196, 70)
    local panel = UIStyle.Panel(parent, { Name = "AdminPanel", Size = UDim2.fromOffset(1100, 660), Accent = GOLD })
    UIStyle.TitleBar(panel, "ADMIN MENU", Color3.fromRGB(200, 140, 40), "only admins can open this, everything is checked on the server  •  F6 to close", function() AdminPanel._userCloseAt = os.clock(); api.Close() end)

    -- left: players
    local left = UIStyle.Card(panel, { Name = "Players", Size = UDim2.fromOffset(240, 574), Position = UDim2.fromOffset(16, 76) })
    UIStyle.Text({ Text = "PLAYERS", TextSize = 16, Stroke = 2, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 22), Parent = left })
    local refresh = UIStyle.Button(left, "REFRESH", Color3.fromRGB(70, 130, 220), UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 1, -46), "Refresh")
    local plist = Scroller(left, UDim2.fromOffset(10, 36), UDim2.new(1, -20, 1, -90), 6)

    -- right: the selected player + the three tabs
    local right = UIStyle.Card(panel, { Name = "Items", Size = UDim2.new(1, -288, 0, 574), Position = UDim2.fromOffset(272, 76) })
    local who = UIStyle.Text({ Text = "Pick a player", TextSize = 22, Stroke = 2, Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 28), Parent = right })
    local TABS = { { "Gifts", "GIFTS", GOLD }, { "Commands", "COMMANDS", Color3.fromRGB(90, 200, 255) }, { "Errors", "ERRORS", Color3.fromRGB(220, 80, 80) }, { "Music", "MUSIC", Color3.fromRGB(150, 140, 255) } }
    local tabBtns, views = {}, {}
    for i, t in ipairs(TABS) do
        tabBtns[t[1]] = UIStyle.Button(right, t[2], t[3], UDim2.fromOffset(150, 34), UDim2.fromOffset(16 + (i - 1) * 158, 42), "Tab" .. t[1])
        local v = Instance.new("Frame")
        v.Name = t[1] .. "View"; v.BackgroundTransparency = 1; v.Position = UDim2.fromOffset(12, 86); v.Size = UDim2.new(1, -24, 1, -98); v.Visible = false
        v.Parent = right
        views[t[1]] = v
    end

    local selected = nil -- { UserId, DisplayName, Name }
    local owned = {}
    local busy = false
    local tab = "Gifts"

    -- ===================== GIFTS =====================
    local gv = views.Gifts
    local passBtn = UIStyle.Button(gv, "SEASON PASS", GOLD, UDim2.fromOffset(230, 34), UDim2.fromOffset(4, 0), "Pass")
    local allBtn = UIStyle.Button(gv, "GIVE EVERYTHING PREMIUM", Color3.fromRGB(200, 90, 255), UDim2.fromOffset(250, 34), UDim2.fromOffset(242, 0), "All")
    local gsearch = Box(gv, { Name = "GiftSearch", Size = UDim2.new(1, -508, 0, 34), Position = UDim2.fromOffset(500, 0), Placeholder = "Search (name, set, gun, category...)" })
    local ilist = Scroller(gv, UDim2.fromOffset(0, 44), UDim2.new(1, 0, 1, -44), 4)

    local rows = {}
    local function Act(action, ref)
        if busy or not selected then return end
        busy = true
        api.Click()
        local okA, res, msg = pcall(function() return fn:InvokeServer(action, selected.UserId, ref) end)
        busy = false
        api.Toast(okA and (msg or (res and "Done." or "Failed.")) or "Failed.")
        AdminPanel._loadOwned()
    end
    local function Paint()
        for ref, r in pairs(rows) do
            local has = owned[ref] == true
            r.State.Text = has and "OWNED ✓" or ""
            r.State.TextColor3 = Color3.fromRGB(120, 230, 140)
            r.Btn.SetText(has and "TAKE" or "GIVE")
            r.Btn.SetColor(has and Color3.fromRGB(200, 80, 80) or Color3.fromRGB(70, 200, 120))
            r.Btn.SetEnabled(selected ~= nil)
        end
        passBtn.SetText(owned.SeasonPass and "TAKE SEASON PASS" or "GIVE SEASON PASS")
        passBtn.SetColor(owned.SeasonPass and Color3.fromRGB(200, 80, 80) or GOLD)
        passBtn.SetEnabled(selected ~= nil)
        allBtn.SetEnabled(selected ~= nil)
        who.Text = selected and (selected.DisplayName .. "  (@" .. selected.Name .. ")") or "Pick a player"
    end
    -- (re)built from the live catalog every time the menu opens: new skins / sets appear on their own
    local function BuildGifts()
        for _, c in ipairs(ilist:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        rows = {}
        local items = {}
        for _, e in ipairs(Cosmetics.All()) do
            if e.Unlock ~= "Free" and e.Unlock ~= "Level" then table.insert(items, e) end
        end
        -- (0.93) colourways + BOUND points live outside the Cosmetics catalog
        local Colorways = require(script.Parent:WaitForChild("Colorways"))
        for _, e in ipairs(Colorways.GiftRows()) do table.insert(items, e) end
        local order = {}
        for i, c in ipairs(CAT_ORDER) do order[c] = i end
        table.sort(items, function(a, b)
            local oa, ob = order[a.Cat] or 99, order[b.Cat] or 99
            if oa ~= ob then return oa < ob end
            return a.Name < b.Name
        end)
        local lastCat, headers = nil, {}
        for i, e in ipairs(items) do
            if e.Cat ~= lastCat then
                lastCat = e.Cat
                local cd = Cosmetics.CategoryById[e.Cat]
                local h = UIStyle.Text({ Text = cd and cd.Label or require(script.Parent:WaitForChild("Colorways")).GIFT_LABELS[e.Cat] or e.Cat, TextSize = 14, Stroke = 1.5, TextColor3 = cd and cd.Color or GOLD,
                    Size = UDim2.new(1, -12, 0, 26), LayoutOrder = i * 2 - 1, Parent = ilist })
                h.TextYAlignment = Enum.TextYAlignment.Bottom
                headers[e.Cat] = h
            end
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -12, 0, 40); row.BackgroundColor3 = Color3.fromRGB(26, 30, 44); row.BackgroundTransparency = 0.2; row.BorderSizePixel = 0
            row.LayoutOrder = i * 2; row.Name = "Row_" .. e.Cat .. "_" .. e.Id; row.Parent = ilist
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
            local rc = Cosmetics.RarityColor[e.Rarity] or Color3.new(1, 1, 1)
            local bar = Instance.new("Frame"); bar.Size = UDim2.new(0, 5, 1, -10); bar.Position = UDim2.fromOffset(6, 5); bar.BackgroundColor3 = rc; bar.BorderSizePixel = 0; bar.Parent = row
            UIStyle.Text({ Text = e.Name, TextSize = 16, Position = UDim2.fromOffset(20, 2), Size = UDim2.new(1, -260, 0, 22), Parent = row })
            UIStyle.Text({ Text = string.upper(e.Rarity) .. "  •  " .. (e.Unlock == "Robux" and ("R$ " .. tostring(e.Price or "?")) or string.lower(e.Unlock)),
                TextSize = 11, Font = UIStyle.BodyFont, TextColor3 = rc, Position = UDim2.fromOffset(20, 22), Size = UDim2.new(1, -260, 0, 14), Parent = row })
            local state = UIStyle.Text({ Text = "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -236, 0, 0), Size = UDim2.fromOffset(100, 40), Parent = row })
            local btn = UIStyle.Button(row, "GIVE", Color3.fromRGB(70, 200, 120), UDim2.fromOffset(110, 30), UDim2.new(1, -118, 0.5, -15), "Btn")
            btn.Label.TextSize = 14
            local ref = e.Cat .. ":" .. e.Id
            btn.Button.MouseButton1Click:Connect(function()
                if not btn.Button.Active then return end
                Act(owned[ref] and "Take" or "Give", ref)
            end)
            local cd = Cosmetics.CategoryById[e.Cat]
            rows[ref] = { Btn = btn, State = state, Row = row, Cat = e.Cat,
                Hay = table.concat({ e.Name, e.Id, e.Cat, cd and cd.Label or "", e.Rarity or "", e.Gun or "", e.Unlock or "" }, " ") }
        end
        AdminPanel._giftHeaders = headers
    end
    local function FilterGifts()
        local words = Words(gsearch.Text)
        local shown = {}
        for _, r in pairs(rows) do
            local on = #words == 0 or Matches(r.Hay, words)
            r.Row.Visible = on
            if on then shown[r.Cat] = true end
        end
        for cat, h in pairs(AdminPanel._giftHeaders or {}) do h.Visible = shown[cat] == true end
    end
    gsearch:GetPropertyChangedSignal("Text"):Connect(FilterGifts)

    function AdminPanel._loadOwned()
        owned = {}
        if selected then
            local okO, res = pcall(function() return fn:InvokeServer("Owned", selected.UserId) end)
            if okO and type(res) == "table" then owned = res end
        end
        Paint()
    end
    passBtn.Button.MouseButton1Click:Connect(function()
        if passBtn.Button.Active then Act(owned.SeasonPass and "Take" or "Give", "SeasonPass") end
    end)
    allBtn.Button.MouseButton1Click:Connect(function()
        if allBtn.Button.Active then Act("Give", "AllPremium") end
    end)

    -- ===================== COMMANDS =====================
    local cv = views.Commands
    local csearch = Box(cv, { Name = "CmdSearch", Size = UDim2.fromOffset(270, 34), Position = UDim2.fromOffset(0, 0), Placeholder = "Search commands..." })
    local clist = Scroller(cv, UDim2.fromOffset(0, 42), UDim2.new(0, 270, 1, -42), 3)
    local form = Instance.new("Frame")
    form.Name = "Form"; form.BackgroundColor3 = Color3.fromRGB(16, 18, 26); form.BorderSizePixel = 0
    form.Position = UDim2.fromOffset(282, 0); form.Size = UDim2.new(1, -282, 1, 0); form.Parent = cv
    Instance.new("UICorner", form).CornerRadius = UDim.new(0, 6)
    local cTitle = UIStyle.Text({ Text = "Pick a command", TextSize = 20, Stroke = 2, Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 26), Parent = form })
    local cDesc = UIStyle.Text({ Text = "Every command runs on the player picked on the left.", TextSize = 13, Font = UIStyle.BodyFont, TextWrapped = true,
        TextColor3 = Color3.fromRGB(180, 186, 200), TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 36), Parent = form })
    local fields = Instance.new("Frame")
    fields.Name = "Fields"; fields.BackgroundTransparency = 1; fields.Position = UDim2.fromOffset(14, 82); fields.Size = UDim2.new(1, -28, 0, 200); fields.Parent = form
    local runBtn = UIStyle.Button(form, "RUN", Color3.fromRGB(70, 200, 120), UDim2.fromOffset(160, 38), UDim2.fromOffset(14, 290), "Run")
    UIStyle.Text({ Text = "RESULT", TextSize = 13, Stroke = 1.5, TextColor3 = MUTED, Position = UDim2.fromOffset(14, 336), Size = UDim2.fromOffset(200, 18), Parent = form })
    local outBox = Instance.new("ScrollingFrame")
    outBox.Name = "Output"; outBox.BackgroundColor3 = DARK; outBox.BorderSizePixel = 0; outBox.Position = UDim2.fromOffset(14, 356)
    outBox.Size = UDim2.new(1, -28, 1, -370); outBox.ScrollBarThickness = 6; outBox.AutomaticCanvasSize = Enum.AutomaticSize.Y; outBox.CanvasSize = UDim2.new()
    outBox.Parent = form
    Instance.new("UICorner", outBox).CornerRadius = UDim.new(0, 4)
    local outText = UIStyle.Text({ Text = "", TextSize = 13, Font = UIStyle.BodyFont, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 0), Parent = outBox })
    outText.AutomaticSize = Enum.AutomaticSize.Y

    -- the option picker (pick fields): a search box + the list, over the form
    local picker = Instance.new("Frame")
    picker.Name = "Picker"; picker.Visible = false; picker.ZIndex = 20; picker.BackgroundColor3 = Color3.fromRGB(12, 14, 20); picker.BorderSizePixel = 0
    picker.Position = UDim2.fromOffset(10, 10); picker.Size = UDim2.new(1, -20, 1, -20); picker.Parent = form
    Instance.new("UICorner", picker).CornerRadius = UDim.new(0, 6)
    local pst = Instance.new("UIStroke"); pst.Color = GOLD; pst.Thickness = 1.5; pst.Parent = picker
    local pTitle = UIStyle.Text({ Text = "", TextSize = 16, Stroke = 1.5, ZIndex = 21, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -130, 0, 24), Parent = picker })
    local pClose = UIStyle.Button(picker, "CLOSE", Color3.fromRGB(120, 60, 60), UDim2.fromOffset(100, 30), UDim2.new(1, -110, 0, 6), "PClose")
    pClose.Button.ZIndex = 21; pClose.Label.ZIndex = 22
    local psearch = Box(picker, { Name = "PickSearch", Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 42), Placeholder = "Search...", ZIndex = 21 })
    local plistO = Scroller(picker, UDim2.fromOffset(12, 80), UDim2.new(1, -24, 1, -90), 2)
    plistO.ZIndex = 21
    local pickOpts, pickTarget = {}, nil
    local function FillPicker()
        for _, c in ipairs(plistO:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local words = Words(psearch.Text)
        local n = 0
        for _, o in ipairs(pickOpts) do
            if #words == 0 or Matches(o, words) then
                n += 1
                if n > 300 then break end
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(1, -10, 0, 26); b.BackgroundColor3 = Color3.fromRGB(30, 34, 48); b.BorderSizePixel = 0; b.AutoButtonColor = true
                b.Font = Enum.Font.GothamMedium; b.TextSize = 14; b.TextColor3 = Color3.fromRGB(230, 232, 240); b.TextXAlignment = Enum.TextXAlignment.Left
                b.Text = "  " .. o; b.LayoutOrder = n; b.ZIndex = 22; b.Parent = plistO
                Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
                b.MouseButton1Click:Connect(function()
                    api.Click()
                    if pickTarget then pickTarget.Text = o end
                    picker.Visible = false
                end)
            end
        end
    end
    psearch:GetPropertyChangedSignal("Text"):Connect(FillPicker)
    pClose.Button.MouseButton1Click:Connect(function() api.Click(); picker.Visible = false end)

    local current, inputs = nil, {}
    local function ShowCommand(cmd)
        current = cmd
        picker.Visible = false
        for _, c in ipairs(fields:GetChildren()) do c:Destroy() end
        inputs = {}
        cTitle.Text = string.upper(cmd.Label) .. (cmd.Studio and "  (STUDIO ONLY)" or "")
        cDesc.Text = cmd.Desc or ""
        for i, arg in ipairs(cmd.Args) do
            local y = (i - 1) * 40
            UIStyle.Text({ Text = arg.Name, TextSize = 14, Font = UIStyle.BodyFont, TextXAlignment = Enum.TextXAlignment.Left,
                Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(200, 34), Parent = fields })
            if arg.Kind == "bool" then
                local val = arg.Default == true
                local b = UIStyle.Button(fields, val and "ON" or "OFF", val and Color3.fromRGB(70, 200, 120) or Color3.fromRGB(120, 60, 60),
                    UDim2.fromOffset(120, 32), UDim2.fromOffset(210, y + 1), "Arg" .. i)
                local holder = { Text = val and "true" or "false" }
                b.Button.MouseButton1Click:Connect(function()
                    api.Click()
                    val = not val
                    holder.Text = val and "true" or "false"
                    b.SetText(val and "ON" or "OFF")
                    b.SetColor(val and Color3.fromRGB(70, 200, 120) or Color3.fromRGB(120, 60, 60))
                end)
                inputs[i] = holder
            else
                local tb = Box(fields, { Name = "Arg" .. i, Size = UDim2.new(1, arg.Kind == "pick" and -330 or -210, 0, 32), Position = UDim2.fromOffset(210, y + 1),
                    Text = arg.Default ~= nil and tostring(arg.Default) or "", Placeholder = arg.Kind == "num" and "number" or (arg.Kind == "pick" and "type or pick from the list" or "") })
                inputs[i] = tb
                if arg.Kind == "pick" then
                    local lb = UIStyle.Button(fields, "LIST", Color3.fromRGB(90, 110, 170), UDim2.fromOffset(110, 32), UDim2.new(1, -110, 0, y + 1), "List" .. i)
                    lb.Button.MouseButton1Click:Connect(function()
                        api.Click()
                        local okO, list = pcall(arg.Options)
                        pickOpts = (okO and type(list) == "table") and list or {}
                        pickTarget = tb
                        pTitle.Text = string.upper(arg.Name) .. "  (" .. #pickOpts .. ")"
                        psearch.Text = ""
                        FillPicker()
                        picker.Visible = true
                    end)
                end
            end
        end
        if #cmd.Args == 0 then
            UIStyle.Text({ Text = "No settings: press RUN.", TextSize = 14, Font = UIStyle.BodyFont, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left,
                Size = UDim2.fromOffset(300, 30), Parent = fields })
        end
        runBtn.SetEnabled(selected ~= nil)
    end

    local cmdRows = {}
    local function BuildCommands()
        for _, c in ipairs(clist:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        cmdRows = {}
        local order = 0
        for _, g in ipairs(AdminCommands.Groups) do
            order += 1
            local h = UIStyle.Text({ Text = string.upper(g), TextSize = 14, Stroke = 1.5, TextColor3 = AdminCommands.GroupColor[g] or GOLD,
                Size = UDim2.new(1, -12, 0, 24), LayoutOrder = order, Parent = clist })
            h.TextYAlignment = Enum.TextYAlignment.Bottom
            local entry = { Header = h, Items = {} }
            for _, cmd in ipairs(AdminCommands.List) do
                if cmd.Group == g then
                    order += 1
                    local b = Instance.new("TextButton")
                    b.Name = "Cmd_" .. cmd.Id; b.Size = UDim2.new(1, -12, 0, 30); b.BackgroundColor3 = Color3.fromRGB(28, 32, 46); b.BorderSizePixel = 0
                    b.AutoButtonColor = true; b.Font = Enum.Font.GothamBold; b.TextSize = 14; b.TextColor3 = Color3.fromRGB(230, 232, 240)
                    b.TextXAlignment = Enum.TextXAlignment.Left; b.Text = cmd.Label .. (cmd.Studio and "  (Studio)" or ""); b.LayoutOrder = order; b.Parent = clist
                    local bp = Instance.new("UIPadding"); bp.PaddingLeft = UDim.new(0, 14); bp.Parent = b
                    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
                    local stripe = Instance.new("Frame"); stripe.Size = UDim2.new(0, 3, 1, -8); stripe.Position = UDim2.fromOffset(-10, 4); stripe.BorderSizePixel = 0 -- (-10: inside the padding)
                    stripe.BackgroundColor3 = AdminCommands.GroupColor[g] or GOLD; stripe.Parent = b
                    b.MouseButton1Click:Connect(function()
                        api.Click()
                        for _, r in pairs(cmdRows) do for _, it in ipairs(r.Items) do it.Btn.BackgroundColor3 = Color3.fromRGB(28, 32, 46) end end
                        b.BackgroundColor3 = Color3.fromRGB(70, 60, 30)
                        ShowCommand(cmd)
                    end)
                    table.insert(entry.Items, { Btn = b, Hay = table.concat({ cmd.Label, cmd.Id, cmd.Group, cmd.Desc or "" }, " ") })
                end
            end
            cmdRows[g] = entry
        end
    end
    csearch:GetPropertyChangedSignal("Text"):Connect(function()
        local words = Words(csearch.Text)
        for _, entry in pairs(cmdRows) do
            local any = false
            for _, it in ipairs(entry.Items) do
                local on = #words == 0 or Matches(it.Hay, words)
                it.Btn.Visible = on
                any = any or on
            end
            entry.Header.Visible = any
        end
    end)
    runBtn.Button.MouseButton1Click:Connect(function()
        if busy or not current or not selected or not runBtn.Button.Active then return end
        busy = true
        api.Click()
        local raw = {}
        for i = 1, #current.Args do raw[i] = inputs[i] and inputs[i].Text or "" end
        outText.Text = "Running " .. current.Label .. " on " .. selected.DisplayName .. "..."
        local okR, res, msg = pcall(function() return fn:InvokeServer("Cmd", selected.UserId, current.Id, raw) end)
        busy = false
        local text = okR and tostring(msg or (res and "Done." or "Failed.")) or ("Failed: " .. tostring(res))
        outText.Text = os.date("%H:%M:%S") .. "  " .. current.Label .. " → " .. selected.DisplayName .. "\n" .. text
        outText.TextColor3 = (okR and res) and Color3.fromRGB(200, 240, 210) or Color3.fromRGB(255, 160, 150)
        api.Toast((okR and res) and (current.Label .. ": done") or (current.Label .. ": failed"))
        if current.Group == "Cosmetics" then AdminPanel._loadOwned() end
    end)

    -- ===================== ERRORS =====================
    local ev = views.Errors
    local clearBtn = UIStyle.Button(ev, "CLEAR LOG", Color3.fromRGB(120, 60, 60), UDim2.fromOffset(140, 34), UDim2.fromOffset(4, 0), "Clear")
    local reloadErr = UIStyle.Button(ev, "RELOAD", Color3.fromRGB(70, 130, 220), UDim2.fromOffset(120, 34), UDim2.fromOffset(152, 0), "Reload")
    local errView = Scroller(ev, UDim2.fromOffset(0, 44), UDim2.new(1, 0, 1, -44), 6)
    errView.Name = "ErrorView"
    local function Ago(t)
        local d = os.time() - (tonumber(t) or 0)
        if d < 3600 then return math.floor(d / 60) .. "m ago" elseif d < 86400 then return math.floor(d / 3600) .. "h ago" end
        return math.floor(d / 86400) .. "d ago"
    end
    local function LoadErrors()
        for _, c in ipairs(errView:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local okE, list = pcall(function() return fn:InvokeServer("Errors") end)
        if not (okE and type(list) == "table") then list = {} end
        if #list == 0 then
            UIStyle.Text({ Text = "No errors logged. Nice.", TextSize = 16, Size = UDim2.new(1, -12, 0, 30), Parent = errView })
        end
        for i, e in ipairs(list) do
            local t = UIStyle.Text({ Text = string.format("<b>%dx</b>  [%s]  %s  •  v%s  •  %s%s\n%s\n<font color=\"#8a90a8\">%s</font>",
                    e.N or 1, e.Side or "?", Ago(e.Last), tostring(e.V or "?"), e.Side == "Client" and "last: " or "", e.Who or "",
                    tostring(e.M or ""):gsub("<", "&lt;"), tostring(e.T or ""):gsub("<", "&lt;")),
                TextSize = 12, Font = UIStyle.BodyFont, RichText = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, -12, 0, 0), LayoutOrder = i, Parent = errView })
            t.AutomaticSize = Enum.AutomaticSize.Y
            t.TextColor3 = (e.Side == "Server") and Color3.fromRGB(255, 150, 140) or Color3.fromRGB(255, 210, 140)
        end
    end
    clearBtn.Button.MouseButton1Click:Connect(function()
        api.Click()
        local okC, _, msg = pcall(function() return fn:InvokeServer("ClearErrors") end)
        api.Toast(okC and (msg or "Cleared.") or "Failed.")
        LoadErrors()
    end)
    reloadErr.Button.MouseButton1Click:Connect(function() api.Click(); LoadErrors() end)

    -- ===================== tabs + players =====================
    local function ShowTab(name)
        tab = name
        for n, v in pairs(views) do v.Visible = (n == name) end
        for n, b in pairs(tabBtns) do b.Button.BackgroundTransparency = (n == name) and 0 or 0.5 end
        for _, t in ipairs(TABS) do tabBtns[t[1]].SetColor(t[1] == name and t[3] or Color3.fromRGB(60, 66, 86)) end
        if name == "Errors" then LoadErrors() end
        -- (2026-10-24) MUSIC AUDITION: nothing is built or loaded until the tab is opened once
        if name == "Music" and not AdminPanel._music then
            local okM, res = pcall(function()
                return require(Shared:WaitForChild("MusicAudition")).Build(views.Music, {
                    Click = api.Click, Toast = api.Toast, Panel = panel,
                    UserClosedAt = function() return AdminPanel._userCloseAt or -1 end, -- (F6 / X: a real close ends the audition)
                    Invoke = function(...) return fn:InvokeServer(...) end,
                })
            end)
            if okM then AdminPanel._music = res else warn("[MusicAudition] " .. tostring(res)) end
        end
    end
    for _, t in ipairs(TABS) do
        tabBtns[t[1]].Button.MouseButton1Click:Connect(function() api.Click(); ShowTab(t[1]) end)
    end

    local function LoadPlayers()
        for _, c in ipairs(plist:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local okP, list = pcall(function() return fn:InvokeServer("Players") end)
        if not (okP and type(list) == "table") then return end
        table.sort(list, function(a, b) return a.DisplayName:lower() < b.DisplayName:lower() end)
        -- (nobody picked yet: pick yourself, the usual target)
        if not selected then for _, p in ipairs(list) do if p.You then selected = p end end end
        for i, p in ipairs(list) do
            local b = UIStyle.Button(plist, p.DisplayName .. (p.You and "  (you)" or ""), (selected and selected.UserId == p.UserId) and GOLD or Color3.fromRGB(60, 70, 100),
                UDim2.new(1, -8, 0, 40), nil, "P" .. i)
            b.Button.LayoutOrder = i
            b.Label.TextSize = 15
            b.Button.MouseButton1Click:Connect(function()
                api.Click()
                selected = p
                LoadPlayers()
                AdminPanel._loadOwned()
                runBtn.SetEnabled(current ~= nil)
            end)
        end
    end
    refresh.Button.MouseButton1Click:Connect(function() api.Click(); LoadPlayers(); AdminPanel._loadOwned() end)

    local function Toggle()
        if panel.Visible then AdminPanel._userCloseAt = os.clock(); api.Close() return end
        BuildGifts()
        FilterGifts()
        BuildCommands()
        LoadPlayers()
        AdminPanel._loadOwned()
        runBtn.SetEnabled(selected ~= nil and current ~= nil)
        ShowTab(tab)
        api.Open(panel)
    end
    UIS.InputBegan:Connect(function(input, gp)
        if require(Shared:WaitForChild("GameSettings")).IsTyping() then return end
        if input.KeyCode == AdminPanel.KEY then Toggle() end
    end)
    -- (2026-10-24) STUDIO TEST HOOK (the tooling can't press keys / click): Player attr DevAdmin = "open" | "close" |
    -- "tab:<Name>" | "guide" (opens the welcome guide over it) | "play:<n>" | "next" | "prev" | "seek:<s>" | "keep:<n>:<0|1>" | "stop" | "state";
    -- the music audition's state lands in attr DevAdminResult (JSON)
    if game:GetService("RunService"):IsStudio() then
        local lp = game:GetService("Players").LocalPlayer
        lp:GetAttributeChangedSignal("DevAdmin"):Connect(function()
            local cmd = lp:GetAttribute("DevAdmin")
            if type(cmd) ~= "string" or cmd == "" then return end
            lp:SetAttribute("DevAdmin", nil)
            local a1, a2, a3 = string.match(cmd, "^([^:]+):?([^:]*):?(.*)$")
            local m = AdminPanel._music
            if a1 == "open" then if not panel.Visible then Toggle() end
            elseif a1 == "close" then if panel.Visible then AdminPanel._userCloseAt = os.clock(); api.Close() end
            elseif a1 == "guide" then local w = panel.Parent and panel.Parent:FindFirstChild("WelcomeGuide"); if w then api.Open(w) end -- (another window opening over it)
            elseif a1 == "tab" then ShowTab(a2)
            elseif m and a1 == "play" then m.Play(tonumber(a2) or 1)
            elseif m and a1 == "next" then local st = m.State(); m.Play((st.Cur or 0) + 1)
            elseif m and a1 == "prev" then local st = m.State(); m.Play((st.Cur or 2) - 1)
            elseif m and a1 == "seek" then m.Seek(tonumber(a2) or 0)
            elseif m and a1 == "stop" then m.Stop()
            elseif m and a1 == "keep" then
                local t = require(Shared.MusicAudition).LIST[tonumber(a2) or 0]
                if t then fn:InvokeServer("MusicKeep", t.Id, a3 == "1"); m.Reload() end
            end
            local st = m and m.State() or {}
            st.HubOverride = require(Shared.HubMusic).Override == true
            st.Open = panel.Visible
            lp:SetAttribute("DevAdminResult", game:GetService("HttpService"):JSONEncode(st))
        end)
    end
    runBtn.SetEnabled(false)
    ShowTab("Gifts")
    Paint()
    return { Frame = panel, Toggle = Toggle, ShowTab = ShowTab, Music = function() return AdminPanel._music end }
end

return AdminPanel
