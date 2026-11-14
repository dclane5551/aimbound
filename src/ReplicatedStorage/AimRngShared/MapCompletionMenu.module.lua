--!nocheck
-- MAP COMPLETION window (client; MAPS V2 L2, 2026-10-30). Opened from the map device (COMPLETION button). A grid: one row per map
-- type (MapCompletion.Types: each biome, then each Storied map), one column per open band (Ruin .. Annihilation). A cell is DONE
-- once that type was beaten IN TIME on that band (MapCompletion, saved state.MapComplete); "MAP IN BAG" marks a missing cell you
-- already hold a map for. Every AtlasData.COMPLETIONS_PER_POINT completions = a map tree point. Rebuilt on every Open (~100 cells).
-- MapCompletionMenu.Init(menuFolder, hooks) -> { Frame, Open }   hooks = { GetState, OpenFrame, CloseAll, Click }
local Shared = script.Parent
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local MC = require(Shared:WaitForChild("MapCompletion"))
local Rifts = require(Shared:WaitForChild("Rifts"))
local AtlasData = require(Shared:WaitForChild("AtlasData"))

local M = {}
local C = UIStyle.Colors
local ACCENT = Color3.fromRGB(150, 120, 255)
local NAME_W, ROW_H = 230, 26

function M.Init(menuFolder: Instance, hooks: any)
    local panel = UIStyle.Panel(menuFolder, { Name = "MapCompletionMenu", Size = UDim2.fromOffset(820, 640), Accent = ACCENT })
    UIStyle.TitleBar(panel, "MAP COMPLETION", ACCENT, "every map type beaten IN TIME on every band; every " .. AtlasData.COMPLETIONS_PER_POINT .. " completions = a map point",
        function() hooks.CloseAll() end)
    panel:SetAttribute("PhoneMinH", 300) -- (phones: as tall as the screen, the grid scrolls)
    local function Text(props) return UIStyle.Text(props) end
    local summary = Text({ Text = "", TextSize = 16, TextColor3 = C.Text, RichText = true, Position = UDim2.fromOffset(16, 74), Size = UDim2.new(1, -32, 0, 22), Parent = panel })
    local head = Instance.new("Frame")
    head.Name = "Head"; head.BackgroundTransparency = 1; head.Position = UDim2.fromOffset(16, 102); head.Size = UDim2.new(1, -32, 0, 24); head.Parent = panel
    local list = Instance.new("ScrollingFrame")
    list.Name = "Grid"; list.BackgroundTransparency = 1; list.BorderSizePixel = 0; list.ScrollBarThickness = 3
    list.Position = UDim2.fromOffset(16, 130); list.Size = UDim2.new(1, -32, 1, -178)
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y; list.CanvasSize = UDim2.new(); list.Parent = panel
    local lay = Instance.new("UIListLayout"); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Padding = UDim.new(0, 2); lay.Parent = list
    local foot = Text({ Text = "Missing one? CHART a map at the device for a new biome. Storied maps come from drops (the map tree's Relic Seeker helps) and from ENGRAVE (a Rare map + Chart Shards).",
        TextSize = 13, Font = UIStyle.BodyFont, TextColor3 = C.Sub, TextWrapped = true, Position = UDim2.new(0, 16, 1, -44), Size = UDim2.new(1, -32, 0, 36), Parent = panel })
    local _ = foot

    local function Clear(f) for _, c in ipairs(f:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end end
    local function Render()
        Clear(head); Clear(list)
        local st = hooks.GetState() or {}
        local bands = MC.Bands()
        local types = MC.Types()
        local colW = math.floor((788 - NAME_W) / math.max(1, #bands))
        -- maps you hold, by band + type (a missing cell you can fill right now)
        local held = {}
        for _, s in ipairs(type(st.Sigils) == "table" and st.Sigils or {}) do
            local id = MC.TypeOf(s)
            if id then held[Rifts.DifficultyFor(tonumber(s.Tier) or 1) .. "|" .. id] = true end
        end
        local bd = AtlasData.Breakdown(st)
        summary.Text = string.format("COMPLETIONS <b>%d / %d</b>   •   <font color=\"#ffd250\">%d map point%s</font> from them   •   map points in all: %d",
            bd.CompDone, bd.CompTotal, bd.Completion, bd.Completion == 1 and "" or "s", bd.Total)
        Text({ Text = "MAP TYPE", TextSize = 13, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(NAME_W, 24), Parent = head })
        for bi, band in ipairs(bands) do
            local n, total = MC.BandCount(st, band)
            Text({ Text = string.format("%s  %d/%d", string.upper(band), n, total), TextSize = 13, TextColor3 = (n >= total) and C.Good or C.Text,
                Position = UDim2.fromOffset(NAME_W + (bi - 1) * colW, 0), Size = UDim2.fromOffset(colW, 24), Parent = head })
        end
        for i, t in ipairs(types) do
            local row = Instance.new("Frame")
            row.Name = "Row_" .. t.Id; row.LayoutOrder = i; row.Size = UDim2.new(1, 0, 0, ROW_H); row.BorderSizePixel = 0
            row.BackgroundColor3 = C.Bg1 or Color3.fromRGB(25, 28, 34); row.BackgroundTransparency = (i % 2 == 0) and 0.4 or 0.7; row.Parent = list
            Text({ Text = t.Name, TextSize = 14, TextColor3 = t.Storied and Rifts.RARITIES.Unique.Color or C.Text, TextXAlignment = Enum.TextXAlignment.Left,
                Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(NAME_W - 8, ROW_H), Parent = row })
            for bi, band in ipairs(bands) do
                local done = MC.Has(st, band, t.Id)
                local have = (not done) and held[band .. "|" .. t.Id]
                local cell = Text({ Name = "C_" .. band, Text = done and "✓" or (have and "MAP IN BAG" or "—"), TextSize = done and 16 or 12,
                    Font = done and nil or UIStyle.BodyFont, TextColor3 = done and C.Good or (have and C.Gold or (C.Muted or C.Sub)),
                    Position = UDim2.fromOffset(NAME_W + (bi - 1) * colW, 0), Size = UDim2.fromOffset(colW, ROW_H), Parent = row })
                cell:SetAttribute("Done", done)
            end
        end
    end

    return {
        Frame = panel,
        Open = function()
            Render()
            hooks.OpenFrame(panel)
        end,
    }
end

return M
