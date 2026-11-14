--!nocheck
-- STYLE STUDIO: the character creator window (client). Left: category tabs + option grid; the rest of the screen
-- shows your real character from the front (HubCamera's creator framing) -- every pick previews live on it
-- (AvatarAction "Preview"), drag anywhere outside the panel to spin it, SAVE keeps the look, CANCEL / closing reverts.
-- AimRngClient builds it once (CharacterCreator.Build) and opens it like any menu (OpenMenuFrame(panel)).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local AvatarData = require(Shared:WaitForChild("AvatarData"))
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData")) -- (rarity colours)

local CharacterCreator = {}
local LocalPlayer = Players.LocalPlayer
local C = UIStyle.Colors
local ACCENT = Color3.fromRGB(255, 120, 200)

local COLOR_CATS = { Skin = true, HairColor = true, Shirt = true, Pants = true, Trim = true }

-- Front-view layout of the body parts for the little slot drawings: centre (x = the character's right, y up) and size, studs.
local FIGURE = {
    UpperTorso = { C = Vector2.new(0, 0.95), S = Vector2.new(2, 1.6) },
    LowerTorso = { C = Vector2.new(0, -0.05), S = Vector2.new(2, 0.4) },
    LeftUpperArm = { C = Vector2.new(-1.5, 1.15), S = Vector2.new(1, 1.1) },
    RightUpperArm = { C = Vector2.new(1.5, 1.15), S = Vector2.new(1, 1.1) },
    LeftLowerArm = { C = Vector2.new(-1.5, 0.15), S = Vector2.new(1, 0.9) },
    RightLowerArm = { C = Vector2.new(1.5, 0.15), S = Vector2.new(1, 0.9) },
    LeftUpperLeg = { C = Vector2.new(-0.5, -0.8), S = Vector2.new(1, 1.2) },
    RightUpperLeg = { C = Vector2.new(0.5, -0.8), S = Vector2.new(1, 1.2) },
    LeftLowerLeg = { C = Vector2.new(-0.5, -1.85), S = Vector2.new(1, 0.9) },
    RightLowerLeg = { C = Vector2.new(0.5, -1.85), S = Vector2.new(1, 0.9) },
    LeftFoot = { C = Vector2.new(-0.5, -2.45), S = Vector2.new(1, 0.3) },
    RightFoot = { C = Vector2.new(0.5, -2.45), S = Vector2.new(1, 0.3) },
}
local TOP_PARTS = { "UpperTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" }
local BOTTOM_PARTS = { "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" }

-- ctx: { GetState = () -> clientState, OnClose = () -> (), Toast = (string) -> (), Click = () -> () }
function CharacterCreator.Build(parent: Instance, ctx: any)
    local api = {}
    local panel = UIStyle.Panel(parent, { Name = "CharacterCreator", Size = UDim2.new(0, 470, 1, -140), Accent = ACCENT })
    panel.AnchorPoint = Vector2.new(0, 0.5)
    panel.Position = UDim2.new(0, 36, 0.5, 0)
    local _, subtitle = UIStyle.TitleBar(panel, "STYLE STUDIO", ACCENT, "pick a look. It previews live on your character", function() ctx.OnClose() end)

    -- category tabs (two rows of chips)
    local tabs = UIStyle.New("Frame", { Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 0, 118), Parent = panel })
    UIStyle.New("UIGridLayout", { CellSize = UDim2.new(0.2, -6, 0, 34), CellPadding = UDim2.fromOffset(7, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabs })

    local catTitle = UIStyle.Text({ Name = "CatTitle", Text = "", TextSize = 22, Stroke = 2, Position = UDim2.fromOffset(18, 200), Size = UDim2.new(1, -36, 0, 28), Parent = panel })

    local grid = UIStyle.New("ScrollingFrame", {
        Name = "Options", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(14, 232), Size = UDim2.new(1, -28, 1, -306),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ScrollBarImageColor3 = ACCENT, Parent = panel,
    })
    UIStyle.New("UIGridLayout", { CellSize = UDim2.fromOffset(102, 102), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
    UIStyle.New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10), Parent = grid })

    -- bottom buttons
    local btnRow = UIStyle.New("Frame", { Name = "Buttons", BackgroundTransparency = 1, Position = UDim2.new(0, 16, 1, -62), Size = UDim2.new(1, -32, 0, 48), Parent = panel })
    local randomBtn = UIStyle.Button(btnRow, "RANDOM", C.Purple, UDim2.new(0.3, -6, 1, 0), UDim2.new(0, 0, 0, 0), "Random")
    local cancelBtn = UIStyle.Button(btnRow, "CANCEL", C.Off, UDim2.new(0.3, -6, 1, 0), UDim2.new(0.3, 3, 0, 0), "Cancel")
    local saveBtn = UIStyle.Button(btnRow, "SAVE", C.Green, UDim2.new(0.4, -3, 1, 0), UDim2.new(0.6, 6, 0, 0), "Save")

    -- "drag to rotate" hint at the bottom of the screen (outside the panel)
    local hint = UIStyle.Text({ Name = "CreatorHint", Text = "drag to rotate", Font = UIStyle.BodyFont, TextSize = 15, TextColor3 = C.Sub,
        TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.62, 0, 1, -40), Size = UDim2.fromOffset(300, 24),
        Visible = false, Stroke = 1, Parent = parent })

    local look = AvatarData.Normalize(nil)
    local savedLook = AvatarData.Normalize(nil)
    local firstTime = false
    local activeCat = "Body"
    local saved = false
    local session = false
    local tabButtons = {}

    -- previews: send the newest look, never more than one call in flight
    local inFlight, pending = false, false
    local function Preview()
        if inFlight then pending = true return end
        inFlight = true
        task.spawn(function()
            repeat
                pending = false
                pcall(function() Remotes.GetFunction("AvatarAction"):InvokeServer("Preview", look) end)
                task.wait(0.09)
            until not pending
            inFlight = false
        end)
    end

    local RenderOptions
    local function SetTab(id: string)
        activeCat = id
        for cid, b in pairs(tabButtons) do b.SetSelected(cid == id) end -- (UI v4 NEON)
        RenderOptions()
    end
    for i, cat in ipairs(AvatarData.Categories) do
        local b = UIStyle.Button(tabs, cat.Label, C.CardDark, nil, nil, "Tab_" .. cat.Id)
        b.Button.LayoutOrder = i
        b.Label.TextSize = 12
        b.Button.MouseButton1Click:Connect(function() ctx.Click(); SetTab(cat.Id) end)
        tabButtons[cat.Id] = b
    end

    local function Tile(entry: any, order: number)
        local state = ctx.GetState()
        local unlocked, why = AvatarData.IsUnlocked(entry, state)
        local selected = look[activeCat] == entry.Id
        local tile = UIStyle.New("TextButton", { Name = entry.Id, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, Parent = grid }, { UIStyle.Corner(12) })
        UIStyle.Gradient(C.Card, C.CardDark).Parent = tile
        local rarCol = entry.Rarity and ItemData.RarityColors[entry.Rarity]
        local stroke = UIStyle.Stroke(selected and ACCENT or (rarCol or C.Border), selected and 3.5 or (rarCol and 2.5 or 2))
        stroke.Parent = tile
        if rarCol then
            -- rarity: a soft wash of its colour behind the art + a label
            local wash = UIStyle.New("Frame", { Name = "RarityWash", BackgroundColor3 = rarCol, BackgroundTransparency = 0.82, Size = UDim2.fromScale(1, 1), Parent = tile }, { UIStyle.Corner(12) })
            UIStyle.New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.2, 1), Parent = wash })
            UIStyle.Text({ Name = "Rarity", Text = string.upper(entry.Rarity), TextSize = 10, Stroke = 1, TextColor3 = rarCol, TextXAlignment = Enum.TextXAlignment.Center,
                Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, 12), ZIndex = 8, Parent = tile })
        end
        UIStyle.Hover(tile, 0.04)
        -- picture
        local art = UIStyle.New("Frame", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 58), Parent = tile })
        if COLOR_CATS[activeCat] then
            local sw = UIStyle.New("Frame", { BackgroundColor3 = entry.Color, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(48, 48), Parent = art }, { UIStyle.Corner(24) })
            UIStyle.Stroke(C.Border, 3).Parent = sw
            if entry.Material == "Metal" then
                UIStyle.New("UIGradient", { Rotation = 45, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.5, entry.Color), ColorSequenceKeypoint.new(1, entry.Color:Lerp(Color3.new(0, 0, 0), 0.4)) }), Parent = sw })
            end
        elseif activeCat == "Face" then
            local skin = AvatarData.Find("Skin", look.Skin)
            local bg = UIStyle.New("Frame", { BackgroundColor3 = skin and skin.Color or Color3.fromRGB(214, 160, 118), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(56, 56), Parent = art }, { UIStyle.Corner(10) })
            UIStyle.New("ImageLabel", { BackgroundTransparency = 1, Image = entry.Texture, Size = UDim2.fromScale(1, 1), Parent = bg })
        else
            -- a little block drawing of the shape
            local skin = AvatarData.Find("Skin", look.Skin).Color
            local hairCol = AvatarData.Find("HairColor", look.HairColor).Color
            local function Box(x, y, w, h, col, round)
                local f = UIStyle.New("Frame", { BackgroundColor3 = col, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, 0.5, y), Size = UDim2.fromOffset(w, h), Parent = art }, { UIStyle.Corner(round or 3) })
                UIStyle.Stroke(C.Border, 1.5).Parent = f
                return f
            end
            if activeCat == "Body" then
                local w, h = 26 * entry.W, 22 * entry.H
                Box(0, -h / 2 - 6, 14 * entry.Head, 14 * entry.Head, skin)
                Box(0, 0, w, h, AvatarData.Find("Shirt", look.Shirt).Color)
                Box(-w / 2 - 5, 0, 8, h, skin); Box(w / 2 + 5, 0, 8, h, skin)
                Box(0, h / 2 + 9 * entry.H, w, 16 * entry.H, AvatarData.Find("Pants", look.Pants).Color)
            elseif activeCat == "Head" then
                local s = entry.Size or Vector3.new(1.2, 1.2, 1.2)
                Box(0, 4, 36 * s.X, 36 * s.Y, skin, entry.Sphere and 30 or (entry.ClassicMesh and 12 or 4))
            elseif entry.Pieces then
                -- hair / headwear / tops / bottoms: the body region in front view, then the pieces on it
                local shirt = AvatarData.Find("Shirt", look.Shirt).Color
                local pants = AvatarData.Find("Pants", look.Pants).Color
                local named = { Hair = hairCol, Skin = skin, Shirt = shirt, Pants = pants,
                    ShirtDark = shirt:Lerp(Color3.new(0, 0, 0), 0.35), PantsDark = pants:Lerp(Color3.new(0, 0, 0), 0.35),
                    Trim = (AvatarData.Find("Trim", look.Trim) or AvatarData.Trim[1]).Color }
                local cat
                for _, c in ipairs(AvatarData.Categories) do if c.Id == activeCat then cat = c end end
                local attachDefault = (cat and cat.Attach) or "Head"
                local function Draw(pc, unitPx: Vector2, centre: Vector2, defaultCol)
                    local col = (typeof(pc.Color) == "Color3" and pc.Color) or named[pc.Color] or defaultCol
                    -- front view: the character's right is on the viewer's left
                    local f = Box(centre.X - pc.P.X * unitPx.X, centre.Y - pc.P.Y * unitPx.Y, math.max(2, pc.S.X * unitPx.X), math.max(2, pc.S.Y * unitPx.Y), col, (pc.Ball and 20) or 2)
                    if pc.R then f.Rotation = -pc.R.Z end
                    if pc.Transparency then f.BackgroundTransparency = pc.Transparency end
                    f.ZIndex = (pc.P.Z > 0.3) and 0 or 3
                end
                if attachDefault == "Head" then
                    Box(0, 8, 40, 40, skin, 4).ZIndex = 1
                    for _, pc in ipairs(entry.Pieces) do Draw(pc, Vector2.new(40, 40), Vector2.new(0, 8), activeCat == "Hair" and hairCol or shirt) end
                else
                    local parts = (attachDefault == "UpperTorso") and TOP_PARTS or BOTTOM_PARTS
                    local px = (attachDefault == "UpperTorso") and 15 or 11
                    local mid = (attachDefault == "UpperTorso") and Vector2.new(0, 0.65) or Vector2.new(0, -1.25)
                    local function Screen(part): (Vector2, Vector2)
                        local fg = FIGURE[part]
                        return Vector2.new(-(fg.C.X - mid.X) * px, -(fg.C.Y - mid.Y) * px), fg.S * px
                    end
                    for _, part in ipairs(parts) do
                        local c, s = Screen(part)
                        local col = skin
                        if part == "UpperTorso" or ((part == "LeftUpperArm" or part == "RightUpperArm") and look.Sleeves ~= "None")
                            or ((part == "LeftLowerArm" or part == "RightLowerArm") and look.Sleeves == "Long") then col = shirt end
                        if table.find(BOTTOM_PARTS, part) then col = pants end
                        Box(c.X, c.Y, s.X, s.Y, col).ZIndex = 1
                    end
                    for _, pc in ipairs(entry.Pieces) do
                        local part = pc.Attach or attachDefault
                        if FIGURE[part] and table.find(parts, part) then
                            local c, s = Screen(part)
                            Draw(pc, s, c, shirt)
                        end
                    end
                end
            elseif activeCat == "Sleeves" then
                local shirt = AvatarData.Find("Shirt", look.Shirt).Color
                Box(0, 0, 26, 30, shirt)
                for _, s in ipairs({ -1, 1 }) do
                    Box(s * 18, -7, 9, 15, entry.Id == "None" and skin or shirt)
                    Box(s * 18, 8, 9, 15, entry.Id == "Long" and shirt or skin)
                end
            end
        end
        UIStyle.Text({ Name = "Name", Text = entry.Name, Font = UIStyle.BodyFont, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true,
            Position = UDim2.new(0, 4, 1, -32), Size = UDim2.new(1, -8, 0, 28), Parent = tile })
        if not unlocked then
            local veil = UIStyle.New("Frame", { Name = "Locked", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = tile }, { UIStyle.Corner(12) })
            if UIStyle.HasIcon("lock") then -- (0.61f: custom padlock, not the Roblox emoji)
                UIStyle.Icon("lock", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(26, 26), ZIndex = 6, Parent = veil })
            end
            UIStyle.Text({ Text = why or "Locked", TextSize = 13, Stroke = 1.5, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true,
                Position = UDim2.fromOffset(4, 44), Size = UDim2.new(1, -8, 0, 18), ZIndex = 6, Parent = veil })
        end
        tile.MouseButton1Click:Connect(function()
            ctx.Click()
            -- locked items still preview (so you can see what you're working toward); SAVE checks unlocks
            look[activeCat] = entry.Id
            RenderOptions()
            Preview()
        end)
    end

    local function AllUnlocked(): (boolean, string?)
        local state = ctx.GetState()
        for _, cat in ipairs(AvatarData.Categories) do
            local ok, why = AvatarData.IsUnlocked(AvatarData.Find(cat.Id, look[cat.Id]), state)
            if not ok then return false, AvatarData.Find(cat.Id, look[cat.Id]).Name .. " (" .. cat.Label:lower() .. "): " .. (why or "locked") end
        end
        return true
    end

    RenderOptions = function()
        for _, c in ipairs(grid:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        for _, cat in ipairs(AvatarData.Categories) do if cat.Id == activeCat then catTitle.Text = cat.Label end end
        local n, st = 0, ctx.GetState()
        for _, entry in ipairs(AvatarData[activeCat]) do
            -- (retired legacy pieces: only if owned, or what you're wearing now)
            if AvatarData.Listed(entry, st) or look[activeCat] == entry.Id then n += 1; Tile(entry, n) end
        end
        local ok, why = AllUnlocked()
        saveBtn.SetEnabled(ok)
        saveBtn.SetText(ok and "SAVE" or "LOCKED")
        if not ok then subtitle.Text = why else subtitle.Text = firstTime and "make your character. You can change it any time at the Style Studio" or "pick a look. It previews live on your character" end
    end

    randomBtn.Button.MouseButton1Click:Connect(function()
        ctx.Click()
        local state = ctx.GetState()
        for _, cat in ipairs(AvatarData.Categories) do
            local pool = {}
            for _, e in ipairs(AvatarData[cat.Id]) do if AvatarData.IsUnlocked(e, state) and not e.Legacy then table.insert(pool, e.Id) end end
            if #pool > 0 then look[cat.Id] = pool[math.random(1, #pool)] end
        end
        RenderOptions()
        Preview()
    end)
    saveBtn.Button.MouseButton1Click:Connect(function()
        if not saveBtn.Button.Active then return end
        ctx.Click()
        local ok, res = Remotes.GetFunction("AvatarAction"):InvokeServer("Save", look)
        if ok then
            saved = true
            savedLook = AvatarData.Normalize(res)
            local st = ctx.GetState()
            if st then st.Avatar = savedLook end
            ctx.OnClose()
        else
            ctx.Toast(type(res) == "string" and res or "Couldn't save that look")
        end
    end)
    cancelBtn.Button.MouseButton1Click:Connect(function() ctx.Click(); ctx.OnClose() end)

    -- drag outside the panel to spin the character (turntable)
    local dragging, lastX = false, 0
    UserInputService.InputBegan:Connect(function(input, gp)
        if not session or gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; lastX = input.Position.X end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not (session and dragging) or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local dx = input.Position.X - lastX
        lastX = input.Position.X
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(dx * 0.6), 0) end
    end)

    local function Controls(on: boolean)
        pcall(function()
            local pm = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
            local controls = pm:GetControls()
            if on then controls:Enable() else controls:Disable() end
        end)
    end

    local function Begin()
        session = true
        saved = false
        local st = ctx.GetState()
        firstTime = not (st and st.Avatar)
        savedLook = AvatarData.Normalize(st and st.Avatar)
        look = table.clone(savedLook)
        cancelBtn.Button.Visible = true
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local f = root.CFrame.LookVector
            LocalPlayer:SetAttribute("CreatorFrameYaw", math.atan2(f.X, f.Z))
        end
        LocalPlayer:SetAttribute("CreatorOpen", true)
        Controls(false)
        hint.Visible = true
        SetTab("Body")
    end
    local function Finish()
        if not session then return end
        session = false
        dragging = false
        hint.Visible = false
        LocalPlayer:SetAttribute("CreatorOpen", nil)
        Controls(true)
        if not saved then
            if firstTime then
                -- closing the very first creator keeps the default look as your saved one
                task.spawn(function() Remotes.GetFunction("AvatarAction"):InvokeServer("Save", savedLook) end)
                local st = ctx.GetState()
                if st then st.Avatar = savedLook end
            else
                task.spawn(function() Remotes.GetFunction("AvatarAction"):InvokeServer("Revert") end)
            end
        end
    end
    panel:GetPropertyChangedSignal("Visible"):Connect(function()
        if panel.Visible then Begin() else Finish() end
    end)

    api.Panel = panel
    return api
end

return CharacterCreator
