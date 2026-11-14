--!nocheck
-- ============================================================================================
-- INVITE FRIENDS window (2026-10-20, client; rules AimRngShared/Referrals, server AimRngServer/ReferralService).
-- INVITE A FRIEND = Roblox's own invite window (SocialService). Shows the rules (why alts don't count), your invited friends
-- (playing / done + paid), who invited you + your progress (level, play time, days), and the 1 / 3 / 10 titles.
-- ReferralMenu.Init(menuFolder, hooks { Toast, Click, OpenFrame, Close }) -> api { Open(), Frame }
-- ============================================================================================
local Shared = script.Parent
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local Referrals = require(Shared:WaitForChild("Referrals"))
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local ReferralMenu = {}

function ReferralMenu.Init(menuFolder: Instance, hooks: any)
    local C = UIStyle.Colors
    local New, Text = UIStyle.New, UIStyle.Text
    local RC = Referrals.COLOR
    local lp = Players.LocalPlayer
    local function Click() if hooks.Click then hooks.Click() end end
    local function Toast(t) if hooks.Toast then hooks.Toast(t) end end
    local root = UIStyle.Panel(menuFolder, { Name = "ReferralMenu", Size = UDim2.fromOffset(840, 610), Accent = RC })
    UIStyle.TitleBar(root, "INVITE FRIENDS", RC, "Bring a friend who's new to Aimbound: you both get " .. Referrals.REWARD_BP .. " BOUND points.", function()
        Click()
        if hooks.Close then hooks.Close() else root.Visible = false end
    end)

    -- the invite card
    local top = UIStyle.Card(root, { Name = "Invite", Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 0, 76) }, RC)
    Text({ Text = "INVITE A FRIEND", TextSize = 20, TextColor3 = RC, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 8),
        Size = UDim2.new(1, -300, 0, 26), Parent = top })
    local countText = Text({ Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
        Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -300, 0, 34), Text = "", Parent = top })
    local inviteBtn = UIStyle.Button(top, "INVITE A FRIEND", RC, UDim2.fromOffset(240, 50), UDim2.new(1, -254, 0.5, -25), "InviteBtn")
    inviteBtn.SetStrong(true) -- (UI v4: the call to action)
    inviteBtn.Label.TextSize = 17
    inviteBtn.Button.MouseButton1Click:Connect(function()
        Click()
        task.spawn(function()
            local okC, can = pcall(function() return SocialService:CanSendGameInviteAsync(lp) end)
            if okC and can then
                local okP = pcall(function() SocialService:PromptGameInvite(lp) end)
                if not okP then Toast("Couldn't open the invite window. Try again.") end
            else
                Toast("Invites aren't available on this account or device.")
            end
        end)
    end)

    -- the rules
    local rules = UIStyle.Card(root, { Name = "Rules", Position = UDim2.fromOffset(16, 162), Size = UDim2.new(1, -32, 0, 118) })
    Text({ Text = "A FRIEND COUNTS WHEN", TextSize = 15, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 6),
        Size = UDim2.new(1, -32, 0, 20), Parent = rules })
    for i, line in ipairs(Referrals.RULES) do
        Text({ Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
            Position = UDim2.fromOffset(16, 28 + (i - 1) * 21), Size = UDim2.new(1, -32, 0, 20), Text = "•  " .. line, Parent = rules })
    end

    -- your friends (left) | invited by + titles (right)
    local left = UIStyle.Card(root, { Name = "Mine", Position = UDim2.fromOffset(16, 290), Size = UDim2.new(0.56, -22, 1, -306) })
    Text({ Text = "FRIENDS YOU INVITED", TextSize = 15, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 6),
        Size = UDim2.new(1, -28, 0, 20), Parent = left })
    local list = New("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 32), Size = UDim2.new(1, -16, 1, -40),
        ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = left },
        { New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
    local right = UIStyle.Card(root, { Name = "Side", Position = UDim2.new(0.56, 2, 0, 290), Size = UDim2.new(0.44, -18, 1, -306) }, RC)
    local byBox = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 150), Parent = right })
    local titleBox = New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 14, 1, -112), Size = UDim2.new(1, -28, 0, 104), Parent = right })

    local function Bar(parent, y, label, pair)
        local have, need = pair[1], pair[2]
        Text({ Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, y),
            Size = UDim2.new(1, 0, 0, 18), Text = string.format("%s  %s / %s", label, ItemData.FormatNumber(have), ItemData.FormatNumber(need)), Parent = parent })
        local track = New("Frame", { BackgroundColor3 = C.Well, BorderSizePixel = 0, Position = UDim2.fromOffset(0, y + 19), Size = UDim2.new(1, 0, 0, 6), Parent = parent })
        New("Frame", { BackgroundColor3 = have >= need and C.Good or RC, BorderSizePixel = 0, Size = UDim2.fromScale(math.clamp(have / math.max(need, 1), 0, 1), 1), Parent = track })
    end

    local function Render(v)
        v = v or {}
        local counted = v.Counted or 0
        local paid = 0
        for _, e in ipairs(v.Mine or {}) do if e.Paid then paid += 1 end end
        countText.Text = string.format("%d friend%s got going (%d / %d paid). Titles at 1, 3 and 10 friends. Your friend must be NEW to Aimbound and play for real.",
            counted, counted == 1 and "" or "s", paid, Referrals.MAX_PAID)
        for _, c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        if #(v.Mine or {}) == 0 then
            Text({ Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(1, -6, 0, 60),
                Text = "Nobody yet. Press INVITE A FRIEND: when they join from it, they show up here.", Parent = list })
        end
        for i, e in ipairs(v.Mine or {}) do
            local row = New("Frame", { LayoutOrder = i, Size = UDim2.new(1, -6, 0, 40), BackgroundColor3 = C.CardDark or C.Bg2, BorderSizePixel = 0, Parent = list })
            Text({ Font = UIStyle.BodyFont, TextSize = 15, Text = e.Name, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(10, 0),
                Size = UDim2.new(0.5, -10, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
            Text({ Font = UIStyle.BodyFont, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -10, 1, 0),
                TextColor3 = e.Done and C.Good or C.Sub,
                Text = e.Done and (e.Paid and ("✓ DONE  +" .. Referrals.REWARD_BP .. " BOUND") or "✓ DONE") or "PLAYING: on the way to level " .. Referrals.LEVEL, Parent = row })
        end
        -- invited by
        for _, c in ipairs(byBox:GetChildren()) do c:Destroy() end
        local by = v.By
        Text({ Text = by and ("INVITED BY " .. string.upper(tostring(by.Name))) or "INVITED BY", TextSize = 15, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd, Parent = byBox })
        if not by then
            Text({ Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, TextWrapped = true, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 40),
                Text = "Nobody: you didn't join from an invite.", Parent = byBox })
        elseif by.No then
            Text({ Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Warn, TextWrapped = true, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 56),
                Text = "This invite doesn't count: " .. tostring(by.No) .. ".", Parent = byBox })
        elseif by.Paid then
            Text({ Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Good, TextWrapped = true, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 40),
                Text = "✓ Done! You both got " .. Referrals.REWARD_BP .. " BOUND points.", Parent = byBox })
        elseif by.Progress then
            Bar(byBox, 26, "LEVEL", by.Progress.Level)
            Bar(byBox, 60, "MINUTES PLAYED", by.Progress.Play)
            Bar(byBox, 94, "DAYS PLAYED", by.Progress.Days)
        end
        -- titles
        for _, c in ipairs(titleBox:GetChildren()) do c:Destroy() end
        Text({ Text = "TITLES", TextSize = 15, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 20), Parent = titleBox })
        for i, m in ipairs(Referrals.TITLES) do
            local got = counted >= m.Need
            local t = ItemData.Titles[m.Title]
            Text({ Font = UIStyle.BodyFont, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 2 + i * 24), Size = UDim2.new(1, 0, 0, 22),
                TextColor3 = got and (t and t.Color or C.Good) or C.Muted,
                Text = (got and "✓ " or "") .. string.upper(t and t.Title or m.Title) .. "  •  " .. m.Need .. " friend" .. (m.Need == 1 and "" or "s"), Parent = titleBox })
        end
    end

    local function Fetch()
        local okC, ok, v = pcall(function() return Remotes.GetFunction("ReferralAction"):InvokeServer("Get") end)
        if okC and ok then Render(v) end
    end

    local api = { Frame = root }
    function api.Open()
        Render(nil)
        if hooks.OpenFrame then hooks.OpenFrame(root) else root.Visible = true end
        task.spawn(Fetch)
    end
    Remotes.GetEvent("SyncPlayerState").OnClientEvent:Connect(function() if root.Visible then task.spawn(Fetch) end end)
    return api
end

return ReferralMenu
