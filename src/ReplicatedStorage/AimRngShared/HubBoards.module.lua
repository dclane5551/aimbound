--!nocheck
-- ============================================================================================
-- HUB LEADERBOARDS (client): draws the live boards on the hub's leaderboard walls (HubGenerator BuildBoards:
-- HubWorld.Leaderboards.BoardPanel, attrs BoardId / Face / Accent). A panel shows the child of
-- ReplicatedStorage.Leaderboards whose Id attribute is its BoardId (EndgameServer publishes the top 50 of every board every
-- 60 s as JSON rows { Rank, Name, Value, UserId }, attrs Title + Kind + Id; LivingHub publishes "Drops", Kind "drop": the
-- server's recent big drops, rows { Name, Item, Rarity, Color, OneIn }). Each board: title, a RANK / PLAYER / stat header, a
-- scrollable list (it also drifts slowly by itself; free the cursor to scroll it by hand) and a "YOU" line.
--   HubBoards.Init()
-- ============================================================================================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local HubBoards = {}

local KIND_LABEL = { time = "TIME", tier = "TIER", level = "LEVEL", score = "SCORE" }
local MEDAL = { Color3.fromRGB(255, 205, 60), Color3.fromRGB(205, 215, 230), Color3.fromRGB(215, 140, 80) }
local ROW_H = 34
-- (HUB LOOK v2 2026-10-24: the boards' rounded cartoon face (FredokaOne) -> GothamBlack, the same lettering as the shop and
-- gate signs, so the walls read as one city's signage)

local function Label(parent, props)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold
    t.TextColor3 = Color3.fromRGB(225, 230, 245)
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextSize = 20
    for k, v in pairs(props) do (t :: any)[k] = v end
    t.Parent = parent
    return t
end

local function BuildBoard(panel: BasePart)
    local idx = panel:GetAttribute("BoardId") or panel:GetAttribute("BoardIndex")
    local accent = panel:GetAttribute("Accent") or Color3.fromRGB(80, 200, 255)
    local sg = Instance.new("SurfaceGui")
    sg.Name = "HubBoard" .. tostring(idx)
    sg.Adornee = panel
    sg.Face = Enum.NormalId[panel:GetAttribute("Face") or "Front"]
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 26
    sg.LightInfluence = 0
    sg.Brightness = 1.4
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.ResetOnSpawn = false
    sg.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local root = Instance.new("Frame")
    root.Size = UDim2.fromScale(1, 1)
    root.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
    root.BorderSizePixel = 0
    root.Parent = sg
    local g = Instance.new("UIGradient"); g.Rotation = 90; g.Color = ColorSequence.new(Color3.fromRGB(30, 34, 52), Color3.fromRGB(10, 11, 18)); g.Parent = root

    local title = Label(root, { Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = accent,
        Size = UDim2.new(1, -30, 0, 54), Position = UDim2.fromOffset(15, 10), Text = "LOADING..." })
    local ts = Instance.new("UIStroke"); ts.Thickness = 2.5; ts.Color = Color3.fromRGB(5, 6, 12); ts.Parent = title
    local bar = Instance.new("Frame"); bar.BorderSizePixel = 0; bar.BackgroundColor3 = accent; bar.Size = UDim2.new(1, -30, 0, 3); bar.Position = UDim2.fromOffset(15, 68); bar.Parent = root

    -- column header
    local hdrY = 78
    local hdrRank = Label(root, { Text = "RANK", Size = UDim2.fromOffset(80, 26), Position = UDim2.fromOffset(20, hdrY), TextColor3 = Color3.fromRGB(150, 160, 190), TextSize = 18 })
    local hdrPlayer = Label(root, { Text = "PLAYER", Size = UDim2.fromOffset(250, 26), Position = UDim2.fromOffset(100, hdrY), TextColor3 = Color3.fromRGB(150, 160, 190), TextSize = 18 })
    local statHdr = Label(root, { Text = "SCORE", Size = UDim2.new(0, 160, 0, 26), Position = UDim2.new(1, -180, 0, hdrY), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(150, 160, 190), TextSize = 18 })

    local list = Instance.new("ScrollingFrame")
    list.Name = "List"
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.Position = UDim2.fromOffset(10, hdrY + 30)
    list.Size = UDim2.new(1, -20, 1, -(hdrY + 30) - 58)
    list.ScrollBarThickness = 8
    list.ScrollBarImageColor3 = accent
    list.CanvasSize = UDim2.new()
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    list.Parent = root
    local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 4); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = list

    local you = Label(root, { RichText = true, Size = UDim2.new(1, -30, 0, 40), Position = UDim2.new(0, 15, 1, -50), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundTransparency = 0.2, BackgroundColor3 = Color3.fromRGB(26, 30, 46), Text = "" })
    local yc = Instance.new("UICorner"); yc.CornerRadius = UDim.new(0, 8); yc.Parent = you

    local lastInput = 0
    list:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if not list:GetAttribute("AutoScrolling") then lastInput = os.clock() end
    end)

    local function Render(sv: StringValue?)
        for _, c in ipairs(list:GetChildren()) do if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end end
        if not sv then
            title.Text = "LEADERBOARD"
            you.Text = "waiting for the first update..."
            return
        end
        title.Text = sv:GetAttribute("Title") or "LEADERBOARD"
        statHdr.Text = KIND_LABEL[sv:GetAttribute("Kind") or ""] or "SCORE"
        local ok, rows = pcall(HttpService.JSONDecode, HttpService, sv.Value)
        rows = ok and type(rows) == "table" and rows or {}
        if sv:GetAttribute("Kind") == "drop" then
            -- RECENT BIG DROPS: the item in its rarity colour over who found it
            hdrRank.Text, hdrPlayer.Text, statHdr.Text = "", "ITEM  /  FOUND BY", ""
            for i, r in ipairs(rows) do
                local row = Instance.new("Frame")
                row.LayoutOrder = i
                row.Size = UDim2.new(1, -12, 0, 58)
                row.BorderSizePixel = 0
                row.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(22, 25, 38) or Color3.fromRGB(28, 32, 48)
                row.Parent = list
                local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 6); rc.Parent = row
                local okC, c = pcall(Color3.fromHex, tostring(r.Color or "ffffff"))
                Label(row, { Text = tostring(r.Item or "?"), Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 2), TextTruncate = Enum.TextTruncate.AtEnd,
                    Font = Enum.Font.GothamBlack, TextSize = 23, TextColor3 = okC and c or Color3.new(1, 1, 1) })
                local odds = (tonumber(r.OneIn) or 0) > 1 and ("  •  1 in " .. tostring(r.OneIn)) or ""
                Label(row, { Text = tostring(r.Name or "?") .. "  •  " .. tostring(r.Rarity or "") .. odds, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 32),
                    TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 17, TextColor3 = Color3.fromRGB(170, 178, 200) })
            end
            if #rows == 0 then
                Label(list, { LayoutOrder = 1, Size = UDim2.new(1, -12, 0, 150), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextSize = 120,
                    TextColor3 = accent, Text = "★" })
                Label(list, { LayoutOrder = 2, Size = UDim2.new(1, -12, 0, 56), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextSize = 44,
                    TextColor3 = Color3.fromRGB(240, 236, 226), Text = "NO BIG DROPS YET" })
                Label(list, { LayoutOrder = 3, Size = UDim2.new(1, -12, 0, 70), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, TextSize = 26,
                    TextColor3 = accent, Text = "Nothing rare on this server yet. Go make history." })
            end
            you.Text = '<font color="#9AA4C0">The rarest finds on this server, newest first</font>'
            return
        end
        hdrRank.Text, hdrPlayer.Text = "RANK", "PLAYER"
        local mine = nil
        for i, r in ipairs(rows) do
            local isMe = (r.UserId == LocalPlayer.UserId)
            if isMe then mine = r end
            local row = Instance.new("Frame")
            row.LayoutOrder = i
            row.Size = UDim2.new(1, -12, 0, ROW_H)
            row.BorderSizePixel = 0
            row.BackgroundColor3 = isMe and Color3.fromRGB(40, 70, 110) or ((i % 2 == 0) and Color3.fromRGB(22, 25, 38) or Color3.fromRGB(28, 32, 48))
            row.Parent = list
            local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 6); rc.Parent = row
            local medal = MEDAL[r.Rank or i]
            Label(row, { Text = "#" .. tostring(r.Rank or i), Size = UDim2.fromOffset(80, ROW_H), Position = UDim2.fromOffset(10, 0), Font = Enum.Font.GothamBlack, TextSize = medal and 24 or 20,
                TextColor3 = medal or Color3.fromRGB(170, 180, 205) })
            Label(row, { Text = tostring(r.Name or "?"), Size = UDim2.new(1, -280, 1, 0), Position = UDim2.fromOffset(90, 0), TextTruncate = Enum.TextTruncate.AtEnd,
                TextColor3 = isMe and Color3.fromRGB(140, 220, 255) or Color3.fromRGB(235, 238, 248) })
            Label(row, { Text = tostring(r.Value or ""), Size = UDim2.new(0, 170, 1, 0), Position = UDim2.new(1, -180, 0, 0), TextXAlignment = Enum.TextXAlignment.Right,
                Font = Enum.Font.GothamBlack, TextSize = 21, TextColor3 = medal or accent })
        end
        if #rows == 0 then -- (UPDATE 4: a styled "be the first" state instead of a line of grey text on black)
            Label(list, { LayoutOrder = 1, Size = UDim2.new(1, -12, 0, 150), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextSize = 120,
                TextColor3 = accent, Text = "★" })
            Label(list, { LayoutOrder = 2, Size = UDim2.new(1, -12, 0, 56), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextSize = 44,
                TextColor3 = Color3.fromRGB(240, 236, 226), Text = "NO RECORD YET" })
            Label(list, { LayoutOrder = 3, Size = UDim2.new(1, -12, 0, 70), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, TextSize = 26,
                TextColor3 = accent, Text = "Be the first: set it and this board is yours" })
        end
        if mine then
            you.Text = string.format('YOU:  <font color="#8CDCFF"><b>#%d</b></font>   %s', mine.Rank or 0, tostring(mine.Value or ""))
        else
            you.Text = '<font color="#9AA4C0">You are not in the top ' .. math.max(50, #rows) .. ' yet</font>'
        end
    end

    -- data binding: the board's value may appear later; re-render when it changes
    local folder = ReplicatedStorage:WaitForChild("Leaderboards", 120)
    local bound: StringValue? = nil
    local function Find(): StringValue?
        if not folder then return nil end
        if type(idx) == "number" then return folder:FindFirstChild("B" .. tostring(idx)) end
        for _, c in ipairs(folder:GetChildren()) do
            if c:IsA("StringValue") and c:GetAttribute("Id") == idx then return c end
        end
        return nil
    end
    local function Bind()
        local sv = Find()
        if sv and sv ~= bound then
            bound = sv
            sv:GetPropertyChangedSignal("Value"):Connect(function() Render(sv) end)
            sv.AttributeChanged:Connect(function() Render(sv) end)
        end
        Render(bound)
    end
    if folder then folder.ChildAdded:Connect(Bind) end
    Bind()

    -- slow auto-scroll while nobody is scrolling it by hand
    task.spawn(function()
        local dir = 1
        while sg.Parent do
            task.wait(6)
            local maxY = math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y)
            if maxY > 4 and os.clock() - lastInput > 10 then
                local target = (dir > 0) and math.min(maxY, list.CanvasPosition.Y + ROW_H * 6) or 0
                if target >= maxY then dir = -1 elseif target <= 0 then dir = 1 end
                list:SetAttribute("AutoScrolling", true)
                local tw = TweenService:Create(list, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { CanvasPosition = Vector2.new(0, target) })
                tw:Play()
                tw.Completed:Wait()
                list:SetAttribute("AutoScrolling", false)
            end
        end
    end)
end

function HubBoards.Init()
    task.spawn(function()
        local hub = workspace:WaitForChild("HubWorld", 60)
        local boards = hub and hub:WaitForChild("Leaderboards", 30)
        if not boards then return end
        for _, p in ipairs(boards:GetChildren()) do
            if p.Name == "BoardPanel" then BuildBoard(p) end
        end
    end)
end

return HubBoards
