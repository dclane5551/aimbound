--!nocheck
-- ============================================================================================
-- MODS window (UPDATE 8 phase 3, OFFENSE; data AimRngShared/ShotMods, server CombatServer.Off.ShotModAct / remote
-- ShotModAction). Left: your guns with sockets (the one in hand first). Middle: the picked gun's sockets drawn as rings
-- with their links, the ACTIVE group (the gun's biggest linked group) lit, other groups IDLE; under it what the shot does
-- now. Right: the mod bag (filter by colour). Click a socket, then SOCKET on a mod of its colour; a filled socket shows
-- TAKE OUT. Nothing is lost taking a mod out.
-- ShotModMenu.Init(menuFolder, hooks { Toast, Click, OpenFrame, Close, GetState, HookItemTooltip(gui, item, isGear) })
--   -> api { Open(gunUid?), Refresh(), Root }
-- ShotModMenu.RenderBag(scroll, state, open) = the short MODS block in the inventory ITEMS tab.
-- ============================================================================================
local Shared = script.Parent
local InvLayout = require(script.Parent:WaitForChild("InvLayout")) -- (UI CLEAN R-B)
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShotMods = require(Shared:WaitForChild("ShotMods"))

local ShotModMenu = {}
local FILTERS = { { "All", "ALL" }, { "R", "RED" }, { "G", "GREEN" }, { "B", "BLUE" } }

local function Pct(x) return string.format("%+d%%", math.round((x - 1) * 100)) end

-- the guns you can socket: the one in hand, then bag guns that have sockets
local function GunsOf(st: any): { any }
    local out, seen = {}, {}
    local eq = type(st) == "table" and st.EquippedWeapon or nil
    if type(eq) == "table" and eq.Uid then table.insert(out, eq); seen[eq.Uid] = true end
    for _, w in ipairs(type(st) == "table" and st.Inventory or {}) do
        if type(w) == "table" and w.Uid and not seen[w.Uid] and type(w.Sockets) == "string" and w.Sockets ~= "" then
            table.insert(out, w); seen[w.Uid] = true
        end
    end
    return out
end
-- the shot summary lines for a gun (its active group, at your level's cap)
function ShotModMenu.Summary(gun: any, level: number?, attrs: any?): { string }
    local r = ShotMods.Compile(gun, level, attrs)
    local out = {}
    local ID = require(Shared:WaitForChild("ItemData")) -- ((CLASS BUILDS) FAMILY: the gun's built-in line comes first, mods can't change it)
    if ID.FamilyLine and ID.FamilyLine(gun) then table.insert(out, ID.FamilyLine(gun)) end
    if #r.List == 0 then return out end
    local parts = {}
    if math.abs(r.More - 1) > 0.005 then table.insert(parts, "Damage " .. Pct(r.More) .. " more") end
    if math.abs(r.FireRate - 1) > 0.005 then table.insert(parts, "Fire rate " .. Pct(r.FireRate)) end
    if r.Mag > 0 then table.insert(parts, "Magazine +" .. math.round(r.Mag * 100) .. "%") end
    if #parts > 0 then table.insert(out, table.concat(parts, "   •   ")) end
    for ai, a in ipairs(ShotMods.Active(gun, level, attrs)) do
        local weak = ShotMods.LinkPower and ShotMods.LinkPower(ai) < 1
        table.insert(out, a.Def.Name .. " " .. a.Level .. ":  " .. ShotMods.Describe({ Mod = a.Item.Mod, Level = a.Level, Quality = a.Item.Quality })
            .. (weak and "  (link " .. ai .. ": its damage and fire-rate bonus count at square root)" or ""))
        local note = ID.FamilyModNote and ID.FamilyModNote(gun, a.Item.Mod) -- (CLASS BUILDS) FAMILY: how this mod works on this family
        if note then table.insert(out, "   " .. note) end
    end
    return out
end

function ShotModMenu.Init(menuFolder: Instance, hooks: any)
    local C = UIStyle.Colors
    local New, Text = UIStyle.New, UIStyle.Text
    local function Click() if hooks.Click then hooks.Click() end end
    local function St() return hooks.GetState and hooks.GetState() or {} end
    local root = UIStyle.Panel(menuFolder, { Name = "ShotModMenu", Size = UDim2.fromOffset(1080, 640), Accent = C.Neon })
    root:SetAttribute("PhoneMinH", 520) -- (phones: the columns stretch, so the window is made only as tall as the phone, never under 520)
    UIStyle.TitleBar(root, "MODS", C.Neon, "Mods change what your shot does. Only the gun's biggest linked group works.", function()
        Click()
        if hooks.Close then hooks.Close() else root.Visible = false end
    end)
    local gunUid, sel, filter, confirmUid = nil, nil, "All", nil
    local view = "Bag" -- (MOD SUPPLY 2026-11-07) the right column: "Bag" = your mods, "Supply" = the city's MOD SUPPLY stock
    local api = { Root = root }

    local function Scroll(parent)
        local sf = New("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 34), Size = UDim2.new(1, -16, 1, -42),
            ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = parent },
            { New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
        UIStyle.StyleScroll(sf)
        return sf
    end
    local function Head(parent, text)
        local h = Text({ Text = text, TextSize = 15, TextColor3 = C.Sub, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 22), Parent = parent })
        UIStyle.TextRole(h, "SectionHead") -- (UI CLEAN R-B)
        return h
    end
    local left = UIStyle.Card(root, { Name = "Guns", Position = UDim2.fromOffset(16, 76), Size = UDim2.new(0, 250, 1, -92) })
    Head(left, "GUNS")
    local gunList = Scroll(left)
    local midCard = UIStyle.Card(root, { Name = "Sockets", Position = UDim2.fromOffset(278, 76), Size = UDim2.new(1, -616, 1, -92) })
    local mid = New("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = midCard })
    local right = UIStyle.Card(root, { Name = "Bag", Position = UDim2.new(1, -330, 0, 76), Size = UDim2.new(0, 314, 1, -92) })
    local bagHead = Head(right, "MOD BAG")
    bagHead.Size = UDim2.new(1, -170, 0, 22)
    -- (MOD SUPPLY 2026-11-07) BAG | SUPPLY word tabs on the column's head line
    local viewBtns = {}
    for i, v in ipairs({ { "Bag", "BAG", 54 }, { "Supply", "SUPPLY", 78 } }) do
        local b = UIStyle.Button(right, v[2], C.Bg1, UDim2.fromOffset(v[3], 24), UDim2.new(1, (i == 1) and -146 or -86, 0, 4), "View" .. v[1])
        b.Label.TextSize = 13
        viewBtns[v[1]] = b
        pcall(function() require(script.Parent:WaitForChild("MenuKit")).WordTab(b) end)
        b.Button.MouseButton1Click:Connect(function() Click(); view = v[1]; confirmUid = nil; api.Refresh() end)
    end
    local filterRow = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 32), Size = UDim2.new(1, -16, 0, 28), Parent = right })
    local filterBtns = {}
    for i, f in ipairs(FILTERS) do
        local b = UIStyle.Button(filterRow, f[2], C.Bg1, UDim2.new(0.25, -4, 1, 0), UDim2.new((i - 1) * 0.25, 2, 0, 0), "Filter" .. f[1])
        b.Label.TextSize = 13
        filterBtns[f[1]] = b
        pcall(function() require(script.Parent:WaitForChild("MenuKit")).WordTab(b) end) -- (UI CLEAN audit: word tabs, not boxes)
        b.Button.MouseButton1Click:Connect(function() Click(); filter = f[1]; api.Refresh() end)
    end
    local bagList = Scroll(right)
    bagList.Position = UDim2.fromOffset(8, 66); bagList.Size = UDim2.new(1, -16, 1, -74)

    local function Act(action, a, b, c)
        Click()
        task.spawn(function()
            local ok, msg = Remotes.GetFunction("ShotModAction"):InvokeServer(action, a, b, c)
            if msg and hooks.Toast then hooks.Toast(tostring(msg)) end
            if not ok then api.Refresh() end
        end)
    end
    local function Clear(f) for _, ch in ipairs(f:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end end
    local function Gun()
        local st = St()
        local guns = GunsOf(st)
        for _, g in ipairs(guns) do if g.Uid == gunUid then return g, guns end end
        gunUid = guns[1] and guns[1].Uid
        return guns[1], guns
    end

    local function RenderGuns(guns, eqUid)
        Clear(gunList)
        for i, g in ipairs(guns) do
            -- (UI CLEAN R-B: the shared item row card -- the gun's icon, name in its rarity colour, the sockets line)
            local _, rich = nil, nil
            local ItemData = require(Shared:WaitForChild("ItemData"))
            if ItemData.SocketLine then _, rich = ItemData.SocketLine(g.Sockets) end
            local n = #ShotMods.InGun(g)
            local r = InvLayout.ItemRow(gunList, { Item = g, Order = i, Height = 52, ArtW = 52, ArtH = 22, Selected = g.Uid == gunUid, Name = tostring(g.Name or g.BaseId),
                Sub = ((g.Uid == eqUid) and "IN HAND  •  " or "") .. (rich or "no sockets") .. ((n > 0) and ("  •  " .. n .. " mod" .. (n == 1 and "" or "s")) or "") })
            r.Sub.RichText = true
            r.Btn.Name = "Gun" .. i
            r.Btn.Size = UDim2.new(1, -6, 0, 52)
            local b = r.Btn
            b.MouseButton1Click:Connect(function() Click(); gunUid = g.Uid; sel = nil; api.Refresh() end)
            if hooks.HookItemTooltip then hooks.HookItemTooltip(b, g, false) end
        end
    end

    local function RenderSockets(g, level)
        Clear(mid)
        if not g then
            UIStyle.EmptyState(mid, "No gun", "Equip a gun to socket mods.", { Size = UDim2.new(1, 0, 1, 0) })
            return
        end
        local gt = Text({ Text = string.upper(tostring(g.Name or g.BaseId)), TextSize = 20, Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 26),
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = mid })
        UIStyle.TextRole(gt, "Title", { Keep = true }) -- (UI CLEAN R-B: the gun's name in its readable rarity colour)
        gt.TextColor3 = InvLayout.Readable(require(Shared:WaitForChild("ItemData")).ItemColor(g), C.Bg1)
        local groups = ShotMods.Groups(g.Sockets)
        if #groups == 0 then
            UIStyle.EmptyState(mid, "No sockets", "This gun has none. Rarer guns and higher item levels roll more sockets and links.", { Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 100) })
            return
        end
        local active = ShotMods.ActiveSet(g)
        local sm = type(g.SocketMods) == "table" and g.SocketMods or {}
        -- the socket row: rings (filled = a mod), link bars inside a group, a gap between groups
        local D, LINK, GAP = 58, 14, 30
        local total = 0
        for gi, grp in ipairs(groups) do total += #grp * D + (#grp - 1) * LINK + ((gi > 1) and GAP or 0) end
        local row = New("Frame", { Name = "SocketRow", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62),
            Size = UDim2.fromOffset(total, D + 54), Parent = mid })
        local x = 0
        for gi, grp in ipairs(groups) do
            if gi > 1 then x += GAP end
            local grpAct = active[grp[1]] == true
            local gw = #grp * D + (#grp - 1) * LINK
            local nAct = 0
            for _, idx in ipairs(grp) do if active[idx] then nAct += 1 end end
            Text({ Text = grpAct and ((nAct < #grp) and ("ACTIVE: FIRST " .. nAct) or "ACTIVE") or "IDLE", TextSize = 12, TextColor3 = isAct and C.Neon or C.Muted, TextXAlignment = Enum.TextXAlignment.Center,
                Position = UDim2.fromOffset(x, -20), Size = UDim2.fromOffset(gw, 16), Parent = row })
            for si, idx in ipairs(grp) do
                local isAct = active[idx] == true -- (per socket: the item-level link gate can cut a group short)
                if si > 1 then
                    New("Frame", { BorderSizePixel = 0, BackgroundColor3 = isAct and C.Neon or C.Line, Size = UDim2.fromOffset(LINK + 4, 6),
                        Position = UDim2.fromOffset(x - LINK - 2, D / 2 - 3), Parent = row })
                end
                local col = ShotMods.COLOR[ShotMods.SocketColor(g.Sockets, idx) or "W"]
                local it = sm[tostring(idx)]
                local d = ShotMods.Def(it)
                local btn = New("TextButton", { Name = "Socket" .. idx, Text = "", AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset(x, 0),
                    Size = UDim2.fromOffset(D, D), BackgroundColor3 = d and col or C.Well, BackgroundTransparency = d and (isAct and 0.15 or 0.6) or 0, Parent = row },
                    { New("UICorner", { CornerRadius = UDim.new(1, 0) }),
                      New("UIStroke", { Color = (sel == idx) and C.Text or col, Thickness = (sel == idx) and 4 or 3, Transparency = isAct and 0 or 0.45, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
                if d then
                    Text({ Text = tostring(it.Level or 1), TextSize = 18, TextColor3 = C.Ink, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = btn })
                end
                Text({ Font = UIStyle.BodyFont, Text = d and d.Name or "empty", TextSize = 12, TextWrapped = true, TextColor3 = d and (isAct and C.Text or C.Muted) or C.Muted,
                    TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(x - 8, D + 4), Size = UDim2.fromOffset(D + 16, 32), Parent = row })
                btn.MouseButton1Click:Connect(function() Click(); sel = (sel == idx) and nil or idx; api.Refresh() end)
                x += D + ((si < #grp) and LINK or 0)
            end
        end
        -- the picked socket
        local info = New("Frame", { Name = "Picked", BackgroundColor3 = C.Bg1, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 184), Size = UDim2.new(1, -32, 0, 76), Parent = mid })
        if sel and ShotMods.SocketColor(g.Sockets, sel) then
            local c = ShotMods.SocketColor(g.Sockets, sel)
            local it = sm[tostring(sel)]
            local d = ShotMods.Def(it)
            Text({ RichText = true, TextSize = 15, Text = string.format('<font color="%s">%s SOCKET</font>  %s', ShotMods.HEX[c], string.upper(ShotMods.COLOR_NAME[c]),
                active[sel] and "(active group)" or "(idle: not in the biggest linked group)"), Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -150, 0, 20), Parent = info })
            Text({ Font = UIStyle.BodyFont, TextSize = 13, TextWrapped = true, TextColor3 = C.Sub, TextYAlignment = Enum.TextYAlignment.Top,
                Text = d and (ShotMods.Name(it) .. ":  " .. ShotMods.Describe(it)) or ("Empty. Pick a " .. ShotMods.COLOR_NAME[c] .. " mod in the bag and press SOCKET."),
                Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -150, 1, -30), Parent = info })
            if d then
                local b = UIStyle.Button(info, "TAKE OUT", C.Steel, UDim2.fromOffset(120, 36), UDim2.new(1, -130, 0.5, -18), "TakeOut")
                b.Button.MouseButton1Click:Connect(function() Act("Unsocket", g.Uid, sel) end)
            end
        else
            Text({ Font = UIStyle.BodyFont, TextSize = 13, TextWrapped = true, TextColor3 = C.Sub, TextYAlignment = Enum.TextYAlignment.Center,
                Text = "Click a socket. A mod fits a socket of its own colour. Linked sockets share a bar; the biggest linked group is the one that works.",
                Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -162, 1, 0), Parent = info })
            if next(sm) ~= nil then
                local b = UIStyle.Button(info, "TAKE ALL OUT", C.Steel, UDim2.fromOffset(130, 36), UDim2.new(1, -140, 0.5, -18), "TakeAll")
                b.Button.MouseButton1Click:Connect(function() Act("UnsocketAll", g.Uid) end)
            end
        end
        -- what the shot does now
        UIStyle.SectionHeader(mid, "WHAT YOUR SHOT DOES", { Position = UDim2.fromOffset(16, 272), Size = UDim2.new(1, -32, 0, 24) })
        -- (UPDATE 8 OFFENSE phase 4) a mod needs its colour's attribute (ShotMods.Req); unmet = idle, said here
        local attrs = nil
        do
            local okA, SC = pcall(require, Shared:WaitForChild("StatCalculator"))
            local st = hooks.GetState and hooks.GetState() or {}
            if okA and st.Level then
                local okS, cs = pcall(SC.Calculate, st.EquippedWeapon, st.AllocatedNodes or {}, 0, st.Level, st.Attributes, st.EquippedGear, st.EquippedTitle, st.SocketedGems, st.RunBoons, st)
                if okS and cs then attrs = { Strength = cs.TotalStrength or 0, Dexterity = cs.TotalDexterity or 0, Intellect = cs.TotalIntellect or 0 } end
            end
        end
        local lines = ShotModMenu.Summary(g, level, attrs)
        local idle = {}
        for k, it in pairs(sm) do if not active[tonumber(k)] and ShotMods.Def(it) then table.insert(idle, ShotMods.Name(it)) end end
        if #idle > 0 then table.insert(lines, "IDLE (doing nothing): " .. table.concat(idle, ", ")) end
        do -- (UPDATE 8 phase 4) say when the item-level link gate is what cut the group short
            local best = 0
            for _, grp in ipairs(groups) do best = math.max(best, #grp) end
            local capL = ShotMods.MaxLinks(g.ItemLevel or 1)
            if best > capL then
                table.insert(lines, "This gun's item level (" .. tostring(g.ItemLevel or 1) .. ") only links " .. capL .. " sockets: a 3-link needs item level 10, 4-link 25, 5-link 45, 6-link 75.")
            end
        end
        local unmet = {}
        for k, it in pairs(sm) do
            local why = active[tonumber(k)] and ShotMods.Def(it) and ShotMods.Unmet(it, level, attrs)
            if why then table.insert(unmet, ShotMods.Name(it) .. " (" .. why .. ")") end
        end
        if #unmet > 0 then table.insert(lines, "IDLE until you meet its attribute: " .. table.concat(unmet, ", ")) end
        if #lines == 0 then lines = { "Nothing yet: a plain shot. Socket mods into the active group." } end
        local cap = ShotMods.LevelCap(level)
        if cap < ShotMods.MAX_LEVEL then table.insert(lines, "Mods work up to level " .. cap .. " at your level (+1 every 8 levels).") end
        local sum = New("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 300), Size = UDim2.new(1, -32, 1, -312),
            ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = mid },
            { New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
        for i, ln in ipairs(lines) do
            Text({ Font = UIStyle.BodyFont, TextSize = 13, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i,
                TextColor3 = (i == 1 and #ShotMods.Active(g) > 0) and C.Text or C.Sub, Text = ln, Size = UDim2.new(1, -8, 0, 18), Parent = sum })
        end
    end

    local function RenderBag(st, g, level)
        Clear(bagList)
        local mods = type(st.ShotMods) == "table" and st.ShotMods or {}
        bagHead.Text = "MOD BAG  (" .. #mods .. " / " .. ShotMods.BAG .. ")"
        for k, b in pairs(filterBtns) do b.SetSelected(k == filter) end
        local selCol = g and sel and ShotMods.SocketColor(g.Sockets, sel)
        local list = {}
        for _, it in ipairs(mods) do
            local d = ShotMods.Def(it)
            if d and (filter == "All" or d.Color == filter) then table.insert(list, it) end
        end
        table.sort(list, function(a, b)
            local da, db = ShotMods.Def(a), ShotMods.Def(b)
            local fa, fb = (selCol and (da.Color == selCol)) and 0 or 1, (selCol and (db.Color == selCol)) and 0 or 1
            if fa ~= fb then return fa < fb end
            if da.Color ~= db.Color then return da.Color < db.Color end
            if da.Name ~= db.Name then return da.Name < db.Name end
            return (a.Level or 1) > (b.Level or 1)
        end)
        if #list == 0 then
            UIStyle.EmptyState(bagList, (#mods == 0) and "No mods yet" or "None of that colour",
                (#mods == 0) and ("Enemies drop them from level " .. ShotMods.DROP.Unlock .. "; bosses drop better ones.") or nil)
            return
        end
        local cap = ShotMods.LevelCap(level)
        for i, it in ipairs(list) do
            local d = ShotMods.Def(it)
            local col = ShotMods.COLOR[d.Color]
            local fits = selCol and (selCol == d.Color or selCol == "W")
            local r = New("Frame", { Name = "Mod" .. i, LayoutOrder = i, BackgroundColor3 = C.Bg1, BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = bagList },
                { New("UIPadding", { PaddingBottom = UDim.new(0, 8) }) })
            New("Frame", { BorderSizePixel = 0, BackgroundColor3 = col, Size = UDim2.new(0, 3, 1, 0), Parent = r })
            Text({ TextSize = 15, Text = ShotMods.Name(it) .. (((it.Level or 1) > cap) and ("  (works at " .. cap .. ")") or ""), Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -110, 0, 20),
                TextTruncate = Enum.TextTruncate.AtEnd, Parent = r })
            -- xp to the next level
            local track = New("Frame", { BorderSizePixel = 0, BackgroundColor3 = C.Well, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -120, 0, 4), Parent = r })
            New("Frame", { BorderSizePixel = 0, BackgroundColor3 = col, Size = UDim2.new(((it.Level or 1) >= ShotMods.MAX_LEVEL) and 1 or math.clamp(it.Xp or 0, 0, 1), 0, 1, 0), Parent = track })
            Text({ Font = UIStyle.BodyFont, TextSize = 13, TextWrapped = true, TextColor3 = C.Sub, AutomaticSize = Enum.AutomaticSize.Y, Text = ShotMods.Describe(it),
                Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -112, 0, 16), Parent = r }) -- (UPDATE 8 LOOT: clear of the DISCARD / BURNISH buttons)
            local sb = UIStyle.Button(r, fits and "SOCKET" or (selCol and "WRONG COLOUR" or "PICK SOCKET"), fits and C.Neon or C.Steel, UDim2.fromOffset(96, 26), UDim2.new(1, -102, 0, 6), "Socket")
            sb.Label.TextSize = 12
            sb.SetEnabled(fits == true)
            sb.Button.MouseButton1Click:Connect(function() if fits then Act("Socket", it.Uid, g.Uid, sel) end end)
            local db = UIStyle.Button(r, (confirmUid == it.Uid) and "SURE?" or "DISCARD", (confirmUid == it.Uid) and C.Red or C.Steel, UDim2.fromOffset(66, 20), UDim2.new(1, -72, 0, 34), "Discard")
            db.Label.TextSize = 11
            db.Button.MouseButton1Click:Connect(function()
                if confirmUid == it.Uid then confirmUid = nil; Act("Discard", it.Uid) else Click(); confirmUid = it.Uid; api.Refresh() end
            end)
            -- (UPDATE 8 LOOT) BURNISH: +1-5% quality, one random roll (shown while you hold one and the mod is under 20%)
            local burn = (St().Materials or {}).ModBurnish or 0
            if burn > 0 and (tonumber(it.Quality) or 0) < ShotMods.MAX_QUALITY then
                local bb = UIStyle.Button(r, "BURNISH (" .. burn .. ")", C.Steel, UDim2.fromOffset(96, 20), UDim2.new(1, -102, 0, 58), "Burnish")
                bb.Label.TextSize = 11
                bb.Button.MouseButton1Click:Connect(function() Act("Burnish", it.Uid) end)
            end
        end
    end

    -- (MOD SUPPLY 2026-11-07) the city's stock (ShotMods.SUPPLY): plain level-1 mods for Scrap / Alloy / Prism + gold, by level
    local function RenderSupply(st, g, level)
        Clear(bagList)
        bagHead.Text = ShotMods.SUPPLY_NAME
        for k, b in pairs(filterBtns) do b.SetSelected(k == filter) end
        local selCol = g and sel and ShotMods.SocketColor(g.Sockets, sel)
        local intro = Text({ Font = UIStyle.BodyFont, TextSize = 13, TextWrapped = true, TextColor3 = C.Sub, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 0,
            Text = "Plain level-1 mods for Scrap, Alloy and gold. New ones open as you level. Buy them in the city, not during a run. Chain, Fork, Detonate and the rarer mods only drop.",
            Size = UDim2.new(1, -8, 0, 16), Parent = bagList })
        UIStyle.TextRole(intro, "Meta", { Keep = true })
        local mats, gold = (type(st.Materials) == "table" and st.Materials) or {}, st.Gold or 0
        local n = 0
        for i, row in ipairs(ShotMods.SUPPLY) do
            local d = ShotMods.DEFS[row.Mod]
            if d and (filter == "All" or d.Color == filter) then
                n += 1
                local col = ShotMods.COLOR[d.Color]
                local locked = level < row.Level
                local short = ShotMods.SupplyShort(row.Cost, mats, gold)
                local r = New("Frame", { Name = "Supply" .. i, LayoutOrder = i, BackgroundColor3 = C.Bg1, BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y, Parent = bagList })
                New("Frame", { BorderSizePixel = 0, BackgroundColor3 = col, BackgroundTransparency = locked and 0.6 or 0, Size = UDim2.new(0, 3, 1, 0), Parent = r })
                -- the words stack in a body column (name, what it does, the cost); the BUY button sits to the right
                local body = New("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -120, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y, Parent = r }, { New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
                    New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }) })
                Text({ RichText = true, TextSize = 15, LayoutOrder = 1, TextColor3 = locked and C.Muted or C.Text, Size = UDim2.new(1, 0, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd,
                    Text = d.Name .. " 1" .. ((d.Tag == "Area") and '  <font size="12" color="#a09d98">AREA</font>' or "")
                        .. ((selCol and (selCol == d.Color or selCol == "W")) and '  <font size="12" color="#a09d98">FITS</font>' or ""), Parent = body })
                Text({ Font = UIStyle.BodyFont, TextSize = 13, LayoutOrder = 2, TextWrapped = true, TextColor3 = C.Sub, AutomaticSize = Enum.AutomaticSize.Y,
                    Text = ShotMods.Describe({ Mod = row.Mod, Level = 1, Quality = 0 }), Size = UDim2.new(1, 0, 0, 16), Parent = body })
                Text({ Font = UIStyle.BodyFont, TextSize = 13, LayoutOrder = 3, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
                    TextColor3 = (short and not locked) and C.Muted or C.Text, Size = UDim2.new(1, 0, 0, 16),
                    Text = ShotMods.CostText(row.Cost) .. (locked and ("  •  opens at level " .. row.Level) or ""), Parent = body })
                local label = locked and ("LEVEL " .. row.Level) or (short and ("NEED " .. string.upper(short)) or "BUY")
                local bb = UIStyle.Button(r, label, (not locked and not short) and C.Neon or C.Steel, UDim2.fromOffset(96, 26), UDim2.new(1, -102, 0, 6), "Buy")
                bb.Label.TextSize = 12
                bb.SetEnabled(not locked and not short)
                bb.Button.MouseButton1Click:Connect(function() if not locked and not short then Act("SupplyBuy", row.Mod) end end)
            end
        end
        if n == 0 then UIStyle.EmptyState(bagList, "None of that colour", nil) end
    end

    function api.Refresh()
        local st = St()
        local g, guns = Gun()
        local level = st.Level or 1
        RenderGuns(guns, st.EquippedWeapon and st.EquippedWeapon.Uid)
        RenderSockets(g, level)
        for k, b in pairs(viewBtns) do b.SetSelected(k == view) end
        if view == "Supply" then RenderSupply(st, g, level) else RenderBag(st, g, level) end
    end
    -- uid = a gun to show, or "SUPPLY" (the city stall's prompt) = open on the MOD SUPPLY stock
    function api.Open(uid)
        view = (uid == "SUPPLY") and "Supply" or "Bag"
        if uid == "SUPPLY" then uid = nil end
        if uid then gunUid = uid end
        sel, confirmUid = nil, nil
        api.Refresh()
        if hooks.OpenFrame then hooks.OpenFrame(root) else root.Visible = true end
    end
    -- the server's state sync after an action / a drop / a level up: re-draw while open (deferred so the client copy is new)
    Remotes.GetEvent("SyncPlayerState").OnClientEvent:Connect(function()
        if root.Visible then task.defer(function() if root.Visible then api.Refresh() end end) end
    end)
    return api
end

-- the inventory ITEMS tab: a short MODS block (count, the gun in hand's active mods, OPEN MODS)
function ShotModMenu.RenderBag(scroll: Instance, st: any, open: () -> ())
    local C = UIStyle.Colors
    local mods = type(st) == "table" and type(st.ShotMods) == "table" and st.ShotMods or {}
    local eq = type(st) == "table" and st.EquippedWeapon or nil
    if #mods == 0 and #ShotMods.InGun(eq) == 0 and ((type(st) == "table" and st.Level) or 1) < ShotMods.DROP.Unlock then return end
    local r = UIStyle.New("Frame", { Name = "ShotModsHead", LayoutOrder = 480, BackgroundColor3 = C.Bg1, BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, 58), Parent = scroll })
    UIStyle.Text({ TextSize = 15, Text = "MODS  (" .. #mods .. " in the bag)", Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -170, 0, 20), Parent = r })
    local act = ShotMods.Active(eq, st.Level)
    local names = {}
    for _, a in ipairs(act) do table.insert(names, a.Def.Name .. " " .. a.Level) end
    UIStyle.Text({ Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, TextTruncate = Enum.TextTruncate.AtEnd,
        Text = (#names > 0) and ("Your gun: " .. table.concat(names, ", ")) or "Socket mods into your gun to change what its shot does.",
        Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -170, 0, 20), Parent = r })
    local b = UIStyle.Button(r, "OPEN MODS", C.Neon, UDim2.fromOffset(140, 36), UDim2.new(1, -150, 0.5, -18), "OpenMods")
    b.Button.MouseButton1Click:Connect(open)
end

return ShotModMenu
