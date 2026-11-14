--!nocheck
-- ============================================================================================
-- SHARED SPOILS window (UPDATE 7 B4, client): the pooled items of the seals your party broke; PICK one (first come first
-- served). Shown when the Spoils event arrives (SharedSpoils server), closes itself a few seconds after the pick time.
-- SpoilsMenu.Init(parentGui, hooks { Toast, Click, Tooltip(item, kind)?, HideTooltip? })
-- ============================================================================================
local Shared = script.Parent
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local Players = game:GetService("Players")

local SpoilsMenu = {}

function SpoilsMenu.Init(parentGui: Instance, hooks: any)
    local C = UIStyle.Colors
    local New, Text = UIStyle.New, UIStyle.Text
    local root = UIStyle.Panel(parentGui, { Name = "SpoilsWindow", Size = UDim2.fromOffset(760, 430), Accent = C.Gold })
    UIStyle.TitleBar(root, "SPLIT THE HAUL", C.Gold, "Every Haul Tag your party spent added two items. Pick one: first come, first served.", function() root.Visible = false end)
    local timer = Text({ Position = UDim2.new(1, -200, 0, 76), Size = UDim2.fromOffset(184, 20), TextSize = 14, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Right, Parent = root })
    local pickersLbl = Text({ Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -230, 0, 20), Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Sub, Parent = root })
    local grid = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 104), Size = UDim2.new(1, -32, 1, -120), Parent = root }, {
        New("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 0, 140), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    local session = nil
    local function Render()
        for _, c in ipairs(grid:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        if not session then return end
        local me = Players.LocalPlayer.UserId
        local picked = false
        local names = {}
        for _, p in ipairs(session.Pickers or {}) do
            table.insert(names, p.Name .. (p.Picked and " ✓" or ""))
            if p.UserId == me and p.Picked then picked = true end
        end
        pickersLbl.Text = "Tags spent by: " .. table.concat(names, ", ")
        for i, e in ipairs(session.Items or {}) do
            local item = e.Item or {}
            local col = (ItemData.ItemColor and ItemData.ItemColor(item)) or ItemData.RarityColors[item.Rarity] or C.Text
            local card = UIStyle.Card(grid, { LayoutOrder = i, Size = UDim2.fromScale(1, 1) }, (not e.TakenBy) and col or nil)
            Text({ Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 40), Text = tostring(item.Name or "?"), TextSize = 15, TextWrapped = true, TextColor3 = col,
                TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
            local sub = (e.Kind == "Weapon") and ((ItemData.WeaponTypeName and ItemData.WeaponTypeName(item)) or "Weapon") or (tostring(item.Slot or "Gear"))
            Text({ Position = UDim2.fromOffset(10, 50), Size = UDim2.new(1, -20, 0, 32), Font = UIStyle.BodyFont, TextSize = 12, TextColor3 = C.Sub, TextWrapped = true,
                Text = tostring(item.Rarity) .. " " .. sub .. "  •  iLvl " .. tostring(item.ItemLevel or 1) .. "\nfrom " .. tostring(e.From), Parent = card })
            local b = UIStyle.Button(card, e.TakenBy and ("TAKEN: " .. string.upper(e.TakenBy)) or "PICK", e.TakenBy and C.Steel or C.Accent, UDim2.new(1, -20, 0, 34), UDim2.new(0, 10, 1, -42), "Pick" .. i)
            b.Label.TextSize = 13
            b.SetEnabled(not e.TakenBy and not picked)
            if hooks.Tooltip then
                b.Button.MouseEnter:Connect(function() hooks.Tooltip(item, e.Kind) end)
                b.Button.MouseLeave:Connect(function() if hooks.HideTooltip then hooks.HideTooltip() end end)
            end
            b.Button.MouseButton1Click:Connect(function()
                if not b.Button.Active then return end
                if hooks.Click then hooks.Click() end
                task.spawn(function()
                    local ok, okRes, msg = pcall(function() return Remotes.GetFunction("SpoilsAction"):InvokeServer("Pick", session.Id, i) end)
                    if hooks.Toast then hooks.Toast(tostring(ok and msg or "Couldn't reach the server.")) end
                end)
            end)
        end
    end
    Remotes.GetEvent("Spoils").OnClientEvent:Connect(function(s)
        if type(s) ~= "table" then return end
        session = s
        root.Visible = true
        Render()
    end)
    task.spawn(function()
        while true do
            task.wait(0.5)
            if session and root.Visible then
                local left = math.floor((session.EndsAt or 0) - workspace:GetServerTimeNow())
                timer.Text = left > 0 and ("picks close in " .. left .. " s") or "picks closed"
                if left < -6 then root.Visible = false; session = nil end
            end
        end
    end)
    return { Frame = root }
end

return SpoilsMenu
