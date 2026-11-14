--!nocheck
-- THE ARCHIVE view (UPDATE 7 A4, ArchiveData): the Index window's ARCHIVE tab. ArchiveView.Render(scroll, state) fills the
-- Index's content ScrollingFrame: per page a header (found / total, the next milestone and what it pays, a bar) and a chip
-- per entry (found = its colour, missing = dim). Lives in its own module: AimRngClient's main chunk is at the local limit.
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local ArchiveData = require(script.Parent:WaitForChild("ArchiveData"))

local ArchiveView = {}
local C = UIStyle.Colors
local New, Text = UIStyle.New, UIStyle.Text

function ArchiveView.Render(scroll: ScrollingFrame, state: any)
    scroll.CanvasSize = UDim2.new()
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    local holder = New("Frame", { Name = "ArchiveHolder", BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(6, 6), Parent = scroll }, {
        New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    local a = ArchiveData.Ensure(type(state) == "table" and state or {})
    Text({ Name = "Intro", LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 34), Font = UIStyle.BodyFont, TextSize = 13, TextWrapped = true, TextColor3 = C.Sub,
        Text = "THE LEDGER: everything you've found and beaten. Each page pays out at its milestones, automatically. Items you own count.", Parent = holder })
    for i, page in ipairs(ArchiveData.Pages) do
        local entries = page.Entries(state)
        local n, total = 0, #entries
        for _, e in ipairs(entries) do if e.Found then n += 1 end end
        local paid = tonumber(a.Paid[page.Id]) or 0
        local nextM = page.Milestones[paid + 1]
        local card = New("Frame", { Name = "Page_" .. page.Id, LayoutOrder = i, BackgroundColor3 = C.Bg1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, Parent = holder }, {
            New("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
            New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
        })
        -- (UI CLEAN audit: the raised card, no coloured edge; the page's colour stays on its progress bar only)
        card.BackgroundColor3 = C.Text; card.BackgroundTransparency = 0.955
        local head = New("Frame", { LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), Parent = card })
        Text({ Size = UDim2.new(0.5, 0, 1, 0), Text = string.upper(page.Title) .. "   " .. n .. " / " .. total, TextSize = 18, TextColor3 = C.Text, Parent = head })
        Text({ Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Font = UIStyle.BodyFont, TextSize = 12,
            TextColor3 = nextM and C.Sub or C.Good,
            Text = nextM and string.format("next at %d: %s", nextM, ArchiveData.RewardText(ArchiveData.MilestoneReward(page, paid + 1))) or "✓ every milestone paid", Parent = head })
        Text({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 16), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, Text = page.Text, Parent = card })
        local bar = New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.Off, BorderSizePixel = 0, Parent = card })
        New("Frame", { Size = UDim2.new(math.clamp(n / math.max(1, total), 0, 1), 0, 1, 0), BackgroundColor3 = page.Color, BorderSizePixel = 0, Parent = bar })
        if page.Id == "Bosses" then
            -- (one row per boss: its name + a pip per tier, I .. X)
            local BT = require(script.Parent:WaitForChild("BossTrials"))
            for bi, b in ipairs(BT.Bosses) do
                local row = New("Frame", { LayoutOrder = 3 + bi, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Parent = card })
                Text({ Size = UDim2.fromOffset(200, 22), Text = string.upper(b.Name), TextSize = 13, TextColor3 = C.Text, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
                for t = 1, BT.MAX_TIER do
                    local got = false
                    for _, e in ipairs(entries) do if e.Key == b.Id .. ":" .. t then got = e.Found end end
                    local pip = New("Frame", { Position = UDim2.fromOffset(206 + (t - 1) * 40, 1), Size = UDim2.fromOffset(36, 20), BorderSizePixel = 0,
                        BackgroundColor3 = got and UIStyle.Darken(b.Color, 0.55) or C.CardDark, Parent = row })
                    Text({ Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11, Text = BT.Tiers[t].Name,
                        TextColor3 = got and b.Color or C.Muted, Parent = pip })
                end
            end
            continue
        end
        local grid = New("Frame", { LayoutOrder = 4, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card }, {
            New("UIGridLayout", { CellSize = UDim2.fromOffset(132, 24), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
        })
        for j, e in ipairs(entries) do
            local col = e.Color or page.Color
            local chip = New("Frame", { Name = "E_" .. e.Key, LayoutOrder = j, BorderSizePixel = 0,
                BackgroundColor3 = e.Found and UIStyle.Darken(col, 0.62) or C.CardDark, Parent = grid })
            if e.Found then UIStyle.Stroke(col:Lerp(C.Bg1, 0.3), 1).Parent = chip else chip:SetAttribute("Skinned", true) end
            Text({ Size = UDim2.new(1, -6, 1, 0), Position = UDim2.fromOffset(3, 0), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11,
                TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = e.Found and col or C.Muted,
                Text = e.Name, Parent = chip })
        end
    end
end

return ArchiveView
