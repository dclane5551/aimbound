--!nocheck
-- MAP TREE window (client). Opened from the map device (MAP TREE button). A pannable / zoomable web of map passives
-- (AtlasData): drag to move, scroll to zoom, click a node for its card, TAKE / REFUND there. The server (AtlasService)
-- checks every take / refund. AtlasMenu.Init(menuFolder, hooks) -> { Open = fn }
-- hooks = { GetState, OpenFrame, CloseAll, Click, Toast }
local Shared = script.Parent
local UIS = game:GetService("UserInputService")
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AtlasData = require(Shared:WaitForChild("AtlasData"))

local AtlasMenu = {}
local C = UIStyle.Colors
local ACCENT = Color3.fromRGB(150, 120, 255)
local DIM = Color3.fromRGB(46, 50, 66)
local SIZE = { Small = 26, Notable = 44, Keystone = 58, Start = 54 }
local CANVAS = 2000 -- canvas pixels (tree units map 1:1, centre at CANVAS / 2)
local SPAN = 1780 -- the tree's width incl. labels: the first open zooms so all of it fits the view
local LABEL_PX = { Notable = 12, Keystone = 15 } -- label size ON SCREEN (kept the same at every zoom)

local STAT_LABEL = {
    Quantity = "guardian item quantity", Luck = "map floor loot luck", TopItems = "top-rarity guardian items", Gems = "guardian gems",
    Gold = "guardian gold", Mats = "guardian material chances", Reward = "map XP and gold", Prism = "Prism per guardian cache",
    SigilChance = "map drop chance inside maps", SigilTier = "chance a map drop climbs an extra tier", SigilRarity = "map drops at least Charged",
    UniqueChance = "chance a map drop is Storied", Time = "seconds on the timer", CraftDiscount = "less Prism for map crafting",
    Elites = "elite chance", Goblin = "loot goblin chance a floor", NormalQuantity = "Plain map item quantity",
}
local FLAT = { TopItems = true, Gems = true, Prism = true, Time = true }

function AtlasMenu.Init(menuFolder: Instance, hooks: any)
    local panel = UIStyle.Panel(menuFolder, { Name = "AtlasMenu", Size = UDim2.fromOffset(1060, 660), Accent = ACCENT })
    local title = UIStyle.TitleBar(panel, "MAP TREE", ACCENT, "map passives: points from your best tier in time, COMPLETION (map types beaten in time per band) and maps finished", function() hooks.CloseAll() end)
    panel:SetAttribute("PhoneMinH", 300) -- (2026-10-13 phones: as tall as the screen; the tree pans / pinches, the totals wrap)
    local _ = title
    -- viewport (left) + info card (right)
    local view = Instance.new("Frame")
    view.Name = "View"; view.BackgroundColor3 = Color3.fromRGB(12, 13, 20); view.BorderSizePixel = 0; view.ClipsDescendants = true
    view.Position = UDim2.fromOffset(16, 76); view.Size = UDim2.new(1, -332, 1, -92); view.Parent = panel
    local canvas = Instance.new("Frame")
    canvas.Name = "Canvas"; canvas.BackgroundTransparency = 1; canvas.AnchorPoint = Vector2.new(0.5, 0.5)
    canvas.Size = UDim2.fromOffset(CANVAS, CANVAS); canvas.Position = UDim2.fromScale(0.5, 0.5); canvas.Parent = view
    local scale = Instance.new("UIScale"); scale.Scale = 0.42; scale.Parent = canvas
    local card = UIStyle.Card(panel, { Name = "Info", Size = UDim2.new(0, 300, 1, -92), Position = UDim2.new(1, -316, 0, 76) })
    local pointsT = UIStyle.Text({ Text = "", TextSize = 18, TextColor3 = C.Gold or Color3.fromRGB(255, 196, 70), Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 24), Parent = card })
    local howT = UIStyle.Text({ Text = "", TextSize = 12, Font = UIStyle.BodyFont, TextWrapped = true, TextColor3 = C.Sub, TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -28, 0, 48), Parent = card })
    local nameT = UIStyle.Text({ Text = "Click a node", TextSize = 20, TextWrapped = true, Position = UDim2.fromOffset(14, 92), Size = UDim2.new(1, -28, 0, 28), Parent = card })
    local typeT = UIStyle.Text({ Text = "", TextSize = 12, Font = UIStyle.BodyFont, TextColor3 = C.Sub, Position = UDim2.fromOffset(14, 120), Size = UDim2.new(1, -28, 0, 16), Parent = card })
    local descT = UIStyle.Text({ Text = "", TextSize = 14, Font = UIStyle.BodyFont, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.fromOffset(14, 140), Size = UDim2.new(1, -28, 0, 78), Parent = card })
    local takeB = UIStyle.Button(card, "TAKE", Color3.fromRGB(70, 200, 120), UDim2.new(1, -28, 0, 38), UDim2.fromOffset(14, 222), "Take")
    local refundB = UIStyle.Button(card, "REFUND", Color3.fromRGB(200, 80, 80), UDim2.new(1, -28, 0, 38), UDim2.fromOffset(14, 222), "Refund")
    local totalT = UIStyle.Text({ Text = "", TextSize = 12, Font = UIStyle.BodyFont, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, RichText = true,
        Position = UDim2.fromOffset(14, 272), Size = UDim2.new(1, -28, 1, -284), Parent = card })

    local branchColor = {}
    for _, b in ipairs(AtlasData.Branches) do branchColor[b.Id] = b.Color end
    local function ColorOf(n) return branchColor[n.Branch] or ACCENT end
    local function P(n) return UDim2.fromOffset(CANVAS / 2 + n.X, CANVAS / 2 + n.Y) end

    -- links (each pair once), then nodes on top
    local lines, buttons = {}, {}
    for id, n in pairs(AtlasData.Nodes) do
        for _, l in ipairs(n.Links) do
            if id < l and AtlasData.Nodes[l] then
                local m = AtlasData.Nodes[l]
                local dx, dy = m.X - n.X, m.Y - n.Y
                local f = Instance.new("Frame")
                f.AnchorPoint = Vector2.new(0.5, 0.5); f.BorderSizePixel = 0; f.BackgroundColor3 = DIM
                f.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), 5)
                f.Position = UDim2.fromOffset(CANVAS / 2 + (n.X + m.X) / 2, CANVAS / 2 + (n.Y + m.Y) / 2)
                f.Rotation = math.deg(math.atan2(dy, dx)); f.ZIndex = 2; f.Parent = canvas
                table.insert(lines, { F = f, A = id, B = l })
            end
        end
    end
    local selected = nil
    local Render
    for id, n in pairs(AtlasData.Nodes) do
        local sz = SIZE[n.Type] or 22
        local b = Instance.new("TextButton")
        b.Name = id; b.Text = ""; b.AutoButtonColor = false; b.AnchorPoint = Vector2.new(0.5, 0.5)
        b.Size = UDim2.fromOffset(sz, sz); b.Position = P(n); b.BorderSizePixel = 0; b.ZIndex = 4
        b.BackgroundColor3 = DIM; b.Parent = canvas
        local corner = Instance.new("UICorner"); corner.CornerRadius = (n.Type == "Keystone") and UDim.new(0.25, 0) or UDim.new(1, 0); corner.Parent = b
        if n.Type == "Keystone" then b.Rotation = 45 end
        local st = Instance.new("UIStroke"); st.Thickness = (n.Type == "Small") and 2 or 3; st.Color = Color3.fromRGB(20, 22, 30); st.Parent = b
        b.MouseButton1Click:Connect(function() hooks.Click(); selected = id; Render() end)
        buttons[id] = { B = b, S = st, N = n }
    end
    -- labels for notables + keystones (resized by ApplyZoom so they read the same at every zoom)
    local labels = {}
    for _, n in pairs(AtlasData.Nodes) do
        if n.Type == "Notable" or n.Type == "Keystone" then
            local t = UIStyle.Text({ Text = string.upper(n.Name), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center,
                TextColor3 = ColorOf(n), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(220, 24),
                Position = UDim2.fromOffset(CANVAS / 2 + n.X, CANVAS / 2 + n.Y + (SIZE[n.Type] or 30) / 2 + 6), ZIndex = 5, Parent = canvas })
            t.TextStrokeTransparency = 0.3
            table.insert(labels, { T = t, N = n })
        end
    end
    -- outline width in SCREEN pixels per node (set by Render), kept the same at every zoom like the labels
    local strokePx = {}
    local function ApplyZoom(z)
        scale.Scale = z
        for _, l in ipairs(labels) do
            local px = LABEL_PX[l.N.Type] or 12
            l.T.TextSize = math.floor(px / z + 0.5)
            l.T.Size = UDim2.fromOffset(150 / z, (px + 4) / z)
            l.T.Position = UDim2.fromOffset(CANVAS / 2 + l.N.X, CANVAS / 2 + l.N.Y + (SIZE[l.N.Type] or 30) / 2 + 3 / z)
        end
        for id, r in pairs(buttons) do r.S.Thickness = (strokePx[id] or 1) / z end
    end

    local function Owned() return AtlasData.Owned(hooks.GetState() or {}) end
    Render = function()
        local st = hooks.GetState() or {}
        local owned = Owned()
        local free = AtlasData.Free(st)
        for id, r in pairs(buttons) do
            local n = r.N
            local has = owned[id] or id == AtlasData.START
            local can = (not has) and AtlasData.CanAllocate(st, id)
            -- taken: branch colour; takeable now: half-lit branch colour + gold ring; else dark
            r.B.BackgroundColor3 = has and ColorOf(n) or (can and DIM:Lerp(ColorOf(n), 0.5)) or (n.Type == "Keystone" and Color3.fromRGB(60, 52, 74) or DIM)
            r.S.Color = (id == selected and Color3.new(1, 1, 1)) or (can and Color3.fromRGB(255, 220, 110)) or Color3.fromRGB(20, 22, 30)
            strokePx[id] = (id == selected) and 3 or (can and 2 or 1)
            r.S.Thickness = strokePx[id] / scale.Scale
        end
        for _, ln in ipairs(lines) do
            local a = owned[ln.A] or ln.A == AtlasData.START
            local b = owned[ln.B] or ln.B == AtlasData.START
            ln.F.BackgroundColor3 = (a and b) and ColorOf(AtlasData.Nodes[ln.A].Branch ~= "Core" and AtlasData.Nodes[ln.A] or AtlasData.Nodes[ln.B]) or DIM
            ln.F.Size = UDim2.fromOffset(ln.F.Size.X.Offset, (a and b) and 7 or 4)
        end
        pointsT.Text = string.format("MAP POINTS  %d / %d free", free, AtlasData.PointsFor(st))
        do -- (MAPS V2 L2) where the points come from (AtlasData.Breakdown)
            local bd = AtlasData.Breakdown(st)
            howT.Text = string.format("Best tier in time: %d  •  completions %d / %d (a point every %d)  •  maps finished %d (a point every %d, up to %d)%s. Refunds cost %d Prism.",
                bd.Tier, bd.CompDone, bd.CompTotal, AtlasData.COMPLETIONS_PER_POINT, math.floor(tonumber(st.MapsDone) or 0), AtlasData.MAPS_PER_POINT_V2,
                AtlasData.MAX_MAP_POINTS_V2, (bd.Legacy > bd.New) and string.format("  •  kept from before: %d", bd.Legacy) or "", AtlasData.REFUND_COST)
        end
        local n = selected and AtlasData.Nodes[selected]
        if n then
            nameT.Text = n.Name; nameT.TextColor3 = ColorOf(n)
            local bn = "Core"
            for _, b in ipairs(AtlasData.Branches) do if b.Id == n.Branch then bn = b.Name end end
            typeT.Text = string.upper(n.Type) .. "  •  " .. string.upper(bn)
            descT.Text = n.Desc
            local has = owned[selected] == true
            takeB.Button.Visible = not has and selected ~= AtlasData.START
            refundB.Button.Visible = has
            takeB.SetEnabled(AtlasData.CanAllocate(st, selected) == true)
            refundB.SetEnabled(AtlasData.CanRefund(st, selected) == true)
        else
            nameT.Text = "Click a node"; typeT.Text = ""; descT.Text = "Drag to move the tree, scroll to zoom. Start next to the map device in the middle."
            takeB.Button.Visible, refundB.Button.Visible = false, false
        end
        -- totals of everything taken
        local A = AtlasData.Stats(st)
        local rows = {}
        for k, v in pairs(A) do
            if type(v) == "number" and STAT_LABEL[k] then
                table.insert(rows, FLAT[k] and string.format("+%g %s", v, STAT_LABEL[k]) or string.format("+%d%% %s", math.round(v * 100), STAT_LABEL[k]))
            end
        end
        table.sort(rows)
        for k, v in pairs(A) do
            if v == true then
                for _, nn in pairs(AtlasData.Nodes) do if nn.Key == k then table.insert(rows, 1, "<b>" .. string.upper(nn.Name) .. "</b>") end end
            end
        end
        totalT.Text = (#rows > 0) and ("<b>YOUR MAP TREE</b>\n" .. table.concat(rows, "\n")) or "Nothing taken yet."
    end
    local function Act(action)
        if not selected then return end
        hooks.Click()
        local ok, a, b = pcall(function() return Remotes.GetFunction("AtlasAction"):InvokeServer(action, selected) end)
        if not ok then hooks.Toast("Couldn't reach the server.") return end
        if b then hooks.Toast(b) end
        task.delay(0.25, Render) -- (the state sync lands first)
    end
    takeB.Button.MouseButton1Click:Connect(function() if takeB.Button.Active then Act("Allocate") end end)
    refundB.Button.MouseButton1Click:Connect(function() if refundB.Button.Active then Act("Refund") end end)

    local fitted = false
    -- pan (drag) + zoom (wheel)
    local dragging, last = false, nil
    view.InputBegan:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then dragging, last = true, io.Position end
    end)
    UIS.InputEnded:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    UIS.InputChanged:Connect(function(io)
        if not panel.Visible then return end
        if dragging and (io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch) then
            local d = io.Position - last
            last = io.Position
            canvas.Position = canvas.Position + UDim2.fromOffset(d.X, d.Y)
        elseif io.UserInputType == Enum.UserInputType.MouseWheel then
            local m = UIS:GetMouseLocation()
            local vp, vs = view.AbsolutePosition, view.AbsoluteSize
            if m.X >= vp.X and m.X <= vp.X + vs.X and m.Y >= vp.Y and m.Y <= vp.Y + vs.Y + 60 then
                ApplyZoom(math.clamp(scale.Scale * (io.Position.Z > 0 and 1.15 or 1 / 1.15), 0.25, 1.4))
            end
        end
    end)

    -- (2026-10-13 phones: a pinch zooms the tree -- it only had the mouse wheel)
    local pinchZ = nil
    UIS.TouchPinch:Connect(function(_, pinchScale, _, state)
        if not panel.Visible then return end
        if state == Enum.UserInputState.Begin then pinchZ = scale.Scale
        elseif state == Enum.UserInputState.Change and pinchZ then ApplyZoom(math.clamp(pinchZ * pinchScale, 0.25, 1.4))
        elseif state == Enum.UserInputState.End then pinchZ = nil end
    end)

    return {
        Frame = panel,
        Open = function()
            Render()
            hooks.OpenFrame(panel)
            if not fitted then -- first open: zoom so the whole tree fits, centred on the start
                fitted = true
                task.defer(function()
                    local vs = view.AbsoluteSize
                    local px = (vs.X > 0 and vs.Y > 0) and math.min(vs.X, vs.Y) or 568
                    -- (AbsoluteSize includes any screen-size scale on the panel; the canvas UIScale works in the view's own units)
                    local own = view.Size.Y.Offset + 660 -- the view's height in panel units (660 tall panel)
                    local ui = (own > 0) and (vs.Y / own) or 1
                    local fit = math.clamp((px / ui) / SPAN, 0.25, 1.4)
                    canvas.Position = UDim2.fromScale(0.5, 0.5)
                    ApplyZoom(fit)
                end)
            end
        end,
        Render = Render,
    }
end

return AtlasMenu
