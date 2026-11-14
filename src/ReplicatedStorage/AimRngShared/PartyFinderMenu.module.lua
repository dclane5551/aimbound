--!nocheck
-- ============================================================================================
-- PARTY FINDER window (2026-10-20, client; server = AimRngServer/PartyFinder). Every open PUBLIC party from every server:
-- what they're playing (dungeon tier / Endless / boss trial), the host + level, bot skill, how full, and which server
-- (THIS SERVER or another one + its player count). JOIN: same server = straight into the room; another server = the
-- server teleports you there and puts you in the party on arrival. Filters: ALL / DUNGEONS / ENDLESS / BOSSES and
-- ONLY ONES I CAN PLAY (difficulty unlocked). MAKE A PARTY opens the Dungeons window (a PUBLIC room shows up here for
-- everyone). Refreshes every 10 s while open.
-- PartyFinderMenu.Init(menuFolder, hooks { Toast, Click, OpenFrame, GetState, OpenDungeons }) -> api { Open(), Frame }
-- ============================================================================================
local Shared = script.Parent
local UIStyle = require(Shared:WaitForChild("UIStyle"))
-- (UI CLEAN R-A, AimRngShared/MenuKit: cards = the target's raised card (a state / accent colour = ONE 2 px bottom line), tabs /
-- filters = words with the 2 px underline)
local MenuKit = require(Shared:WaitForChild("MenuKit"))
local function KCard(parent: Instance, props: any, accent: Color3?): Frame
    return MenuKit.Card(UIStyle.Card(parent, props, nil), accent) :: Frame
end
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local Players = game:GetService("Players")

local PartyFinderMenu = {}
local ACCENT = Color3.fromRGB(70, 168, 228)
local FILTERS = {
    { Id = "All", Label = "ALL" }, { Id = "Dungeon", Label = "DUNGEONS" }, { Id = "Endless", Label = "ENDLESS" }, { Id = "Boss", Label = "BOSSES" },
}

function PartyFinderMenu.Init(menuFolder: Instance, hooks: any)
    local C = UIStyle.Colors
    local New, Text = UIStyle.New, UIStyle.Text
    local LobbyMenu = require(Shared:WaitForChild("LobbyMenu"))
    local DIFF_COLORS = LobbyMenu.DIFF_COLORS or {}
    local root = UIStyle.Panel(menuFolder, { Name = "PartyFinder", Size = UDim2.fromOffset(900, 620), Accent = ACCENT })
    root:SetAttribute("PhoneMinH", 320) -- (phones: as tall as the screen; the list scrolls)
    UIStyle.TitleBar(root, "PARTY FINDER", ACCENT, "Open parties from every server. JOIN takes you to theirs.", function()
        if hooks.Click then hooks.Click() end
        if hooks.Close then hooks.Close() else root.Visible = false end
    end)
    local function Click() if hooks.Click then hooks.Click() end end
    local filter, onlyMine = "All", true
    local busy = false
    local data = { Rooms = {}, Listed = false }
    local Render
    local rowJoin = {} -- (row number -> its JOIN press; the Studio hook uses it)

    -- toolbar: filters | ONLY ONES I CAN PLAY | REFRESH
    local bar = New("Frame", { Name = "Toolbar", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 0, 36), Parent = root })
    local fBtns = {}
    for i, f in ipairs(FILTERS) do
        local b = UIStyle.Button(bar, f.Label, C.Bg2, UDim2.fromOffset(118, 34), UDim2.fromOffset((i - 1) * 124, 0), "F" .. f.Id)
        b.Label.TextSize = 14
        fBtns[f.Id] = b
        MenuKit.WordTab(b) -- (UI CLEAN R-A)
        b.Button.MouseButton1Click:Connect(function() Click(); filter = f.Id; Render() end)
    end
    local mineBtn = UIStyle.Button(bar, "", C.Bg2, UDim2.fromOffset(196, 34), UDim2.new(1, -312, 0, 0), "OnlyMine")
    mineBtn.Label.TextSize = 13
    -- (UI CLEAN R-A2: the toggle = the words + the flat square switch from Settings, not a boxed button)
    local mineSw, mineKnob
    do
        if mineBtn.SetQuiet then mineBtn.SetQuiet(true) end
        for _, c in ipairs(mineBtn.Button:GetChildren()) do if c:IsA("UIStroke") then c.Enabled = false end end
        mineBtn.Label.TextXAlignment = Enum.TextXAlignment.Left
        mineBtn.Label.Size = UDim2.new(1, -60, 1, 0)
        mineSw = New("Frame", { Name = "Switch", BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(44, 22),
            BackgroundColor3 = C.Off, ZIndex = mineBtn.Button.ZIndex + 1, Parent = mineBtn.Button })
        local st = Instance.new("UIStroke"); st.Color = C.Text; st.Transparency = 0.84; st.Thickness = 1; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = mineSw
        mineKnob = New("Frame", { BorderSizePixel = 0, Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = C.Sub, ZIndex = mineSw.ZIndex + 1, Parent = mineSw })
    end
    mineBtn.Button.MouseButton1Click:Connect(function() Click(); onlyMine = not onlyMine; Render() end)
    local refreshBtn = UIStyle.Button(bar, "REFRESH", C.Steel, UDim2.fromOffset(104, 34), UDim2.new(1, -104, 0, 0), "Refresh")
    refreshBtn.Label.TextSize = 14

    -- your status + MAKE A PARTY
    local status = KCard(root, { Name = "Status", Position = UDim2.fromOffset(16, 120), Size = UDim2.new(1, -32, 0, 52) }, nil)
    local statusText = Text({ Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Text, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -220, 1, 0), Text = "", Parent = status })
    local makeBtn = UIStyle.Button(status, "MAKE A PARTY", ACCENT, UDim2.fromOffset(180, 38), UDim2.new(1, -192, 0.5, -19), "Make")
    makeBtn.Label.TextSize = 15
    makeBtn.Button.MouseButton1Click:Connect(function() Click(); if hooks.OpenDungeons then hooks.OpenDungeons() end end)

    -- the list
    local list = New("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 182),
        Size = UDim2.new(1, -32, 1, -198), ScrollBarThickness = 6, ScrollBarImageColor3 = C.Sub, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = root }, {
        New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
        New("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2) }),
    })

    local function Activity(r): (string, Color3, string)
        local diff, endless = ItemData.ParseRunKey(r.D or "Easy")
        diff = diff or "Easy"
        local col = DIFF_COLORS[diff] or ACCENT
        if type(r.T) == "table" then
            local okB, BT = pcall(require, Shared:WaitForChild("BossTrials"))
            local def = okB and BT.ById and BT.ById[r.T.Id]
            local tier = okB and BT.Tiers and BT.Tiers[r.T.Tier]
            return "BOSS TRIAL  •  " .. string.upper(def and def.Name or tostring(r.T.Id)) .. (tier and (" " .. tostring(tier.Name)) or ""), col, "Boss"
        end
        if endless then return "ENDLESS  •  " .. string.upper(diff), col, "Endless" end
        return string.upper(diff) .. " DUNGEON", col, "Dungeon"
    end

    function Render()
        for id, b in pairs(fBtns) do b.SetSelected(id == filter) end -- (v4 NEON)
        mineBtn.SetText("ONLY ONES I CAN PLAY") -- (UI CLEAN R-A2: the switch says on / off)
        mineBtn.Label.TextColor3 = onlyMine and C.Text or C.Sub
        mineSw.BackgroundColor3 = onlyMine and C.Text or C.Off
        mineKnob.BackgroundColor3 = onlyMine and C.Bg0 or C.Sub
        mineKnob.Position = onlyMine and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        local lp = Players.LocalPlayer
        local size = lp:GetAttribute("PartySize") or 0
        if data.Listed then
            statusText.Text = string.format("Your party (%d / 4) is listed for every server. Players who join show up in your Dungeons window.", size)
            makeBtn.SetText("YOUR PARTY")
        elseif size > 0 then
            statusText.Text = "You're in a party. Only PUBLIC rooms show up here: make it public in the Dungeons window to find more players."
            makeBtn.SetText("YOUR PARTY")
        else
            statusText.Text = "Want people to find you? MAKE A PARTY: open a PUBLIC room in the Dungeons window and it shows up here in every server."
            makeBtn.SetText("MAKE A PARTY")
        end
        for _, c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        table.clear(rowJoin)
        local st = hooks.GetState and hooks.GetState() or nil
        local shown = 0
        for _, r in ipairs(data.Rooms or {}) do
            local title, col, kind = Activity(r)
            local diffId = ItemData.ParseRunKey(r.D or "Easy") or "Easy"
            local open, why = true, nil
            if st then open, why = ItemData.DifficultyUnlock(st, diffId) end
            if (filter == "All" or filter == kind) and (open or not onlyMine) then
                shown += 1
                local row = KCard(list, { Name = "Room" .. shown, LayoutOrder = shown, Size = UDim2.new(1, 0, 0, 68) }, col)
                Text({ Text = title, TextSize = 18, TextColor3 = col, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 7),
                    Size = UDim2.new(1, -360, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
                local okG, DG = pcall(require, Shared:WaitForChild("DungeonGenerator"))
                local skill = okG and DG.BotSkillLevels and DG.BotSkillLevels[r.S or 4]
                Text({ Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 36),
                    Size = UDim2.new(1, -360, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd,
                    Text = string.format("%s  •  Level %d  •  Bot skill %d%s  •  %d / %d players", tostring(r.H or "?"), tonumber(r.L) or 1, tonumber(r.S) or 4,
                        skill and skill.Name and (" " .. skill.Name) or "", tonumber(r.N) or 1, tonumber(r.M) or 4), Parent = row })
                local serverFull = not r.Here and (tonumber(r.P) or 0) >= 12
                Text({ Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = r.Here and C.Good or C.Sub, TextXAlignment = Enum.TextXAlignment.Right,
                    Position = UDim2.new(1, -340, 0, 0), Size = UDim2.fromOffset(220, 68),
                    Text = r.Here and "THIS SERVER" or string.format("OTHER SERVER  •  %d / 12", tonumber(r.P) or 0), Parent = row })
                local full = (tonumber(r.N) or 0) >= (tonumber(r.M) or 4)
                local label = (full and "FULL") or (serverFull and "SERVER FULL") or ((not open) and "LOCKED") or "JOIN"
                local j = UIStyle.Button(row, label, C.Green, UDim2.fromOffset(104, 42), UDim2.new(1, -114, 0.5, -21), "Join")
                j.Label.TextSize = (#label > 6) and 12 or 16
                j.SetEnabled(not full and not serverFull)
                if not open then j.SetColor(C.Steel) end -- (LOCKED: a click says why)
                local function Press()
                    if busy or not j.Button.Active then return end
                    if not open then
                        Click()
                        if hooks.Toast then hooks.Toast(tostring(why or "You haven't unlocked that difficulty yet.")) end
                        return
                    end
                    busy = true
                    Click()
                    j.SetText("...")
                    task.spawn(function()
                        local okC, ok, msg, here = pcall(function() return Remotes.GetFunction("PartyFinderAction"):InvokeServer("Join", r.J, r.R) end)
                        busy = false
                        if not okC then ok, msg = false, "Couldn't reach the server." end
                        if hooks.Toast and msg then hooks.Toast(tostring(msg)) end
                        if ok and here and hooks.OpenDungeons then hooks.OpenDungeons()
                        elseif not ok and root.Visible then j.SetText(label) end
                    end)
                end
                rowJoin[shown] = Press
                j.Button.MouseButton1Click:Connect(Press)
            end
        end
        if shown == 0 then
            Text({ Font = UIStyle.BodyFont, TextSize = 15, TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(1, 0, 0, 80), LayoutOrder = 1,
                Text = (#(data.Rooms or {}) == 0) and "No open parties right now. MAKE A PARTY and it shows up here for every player in every server."
                    or "No parties match these filters. Try ALL, or switch off ONLY ONES I CAN PLAY.", Parent = list })
        end
    end

    local function Fetch()
        local okC, ok, res = pcall(function() return Remotes.GetFunction("PartyFinderAction"):InvokeServer("List") end)
        if okC and ok and type(res) == "table" then data = res end
        if root.Visible then Render() end
    end
    refreshBtn.Button.MouseButton1Click:Connect(function() Click(); task.spawn(Fetch) end)
    task.spawn(function() -- (10 s refresh while open)
        while root.Parent do
            task.wait(10)
            if root.Visible then pcall(Fetch) end
        end
    end)

    local api = { Frame = root }
    -- Studio test hook (client DevAct "pf:<filter>:<0|1 only mine>[:join row]"): set the filters, optionally press JOIN on a row
    function api.Dev(f, mine, joinRow)
        if f and f ~= "" then filter = f end
        onlyMine = mine ~= "0"
        Render()
        local fn = joinRow and rowJoin[tonumber(joinRow) or 0]
        if fn then fn() end
    end
    function api.Open()
        Render()
        if hooks.OpenFrame then hooks.OpenFrame(root) else root.Visible = true end
        task.spawn(Fetch)
    end
    return api
end

return PartyFinderMenu
