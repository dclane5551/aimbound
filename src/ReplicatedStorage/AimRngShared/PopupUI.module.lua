--!strict
-- POPUP UI (0.58): two small house-style pieces any menu can use (client only).
--   PopupUI.Confirm(title, body, yesText, yesColor, onYes) -- a modal: CANCEL / yes. Clicking outside cancels.
--   PopupUI.Dropdown(anchor, items, onPick)                  -- a list under (or over) a button; items = { { Text, Color?, Value } }
-- First users: the inventory's AUTO-SELL and SELL UP TO pickers (owner: "Auto sell needs to go up to a higher rarity (with
-- a confirm popup before allowing you to go through with higher rarities), and the sell button should be one button with
-- a drop down").
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local Shared = script.Parent
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local C = UIStyle.Colors
local New = UIStyle.New

local PopupUI = {}

local function Gui(): ScreenGui
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
    local g = pg:FindFirstChild("PopupUI") :: ScreenGui?
    if not g then
        g = New("ScreenGui", { Name = "PopupUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg }) :: ScreenGui
    end
    return g :: ScreenGui
end

function PopupUI.Close()
    local g = Gui()
    for _, n in ipairs({ "Confirm", "Dropdown" }) do
        local o = g:FindFirstChild(n)
        if o then o:Destroy() end
    end
end

function PopupUI.Confirm(title: string, body: string, yesText: string?, yesColor: Color3?, onYes: () -> ())
    local g = Gui()
    PopupUI.Close()
    local accent = yesColor or C.Gold
    local shade = New("TextButton", { Name = "Confirm", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Ink,
        BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), Parent = g }) :: TextButton
    -- (UI CLEAN R-C: the window body -- flat Bg0, square, ONE 1 px hairline; title in display caps (Title role), body in Roblox
    -- Sub; the yes button keeps its role colour (a danger confirm stays a Bad tint), a short fade when it opens)
    local box = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 220),
        BackgroundColor3 = C.Bg0, BackgroundTransparency = UIStyle.WINDOW_T or 0.04, BorderSizePixel = 0, Active = true, Parent = shade }) :: Frame
    local edge = UIStyle.Stroke(C.Text, 1); edge.Transparency = 0.84; edge.Parent = box
    box:SetAttribute("NoSkin", true)
    local pop = New("UIScale", { Parent = box }) :: UIScale
    task.defer(function() if box.Parent then UIStyle.Motion.Open(box, pop) end end)
    local t = UIStyle.Text({ Text = string.upper(title), TextSize = 22, Size = UDim2.new(1, -48, 0, 30), Position = UDim2.fromOffset(24, 20), Parent = box })
    UIStyle.TextRole(t, "Title"); t.FontFace = UIStyle.RoleFace("Label")
    local b = UIStyle.Text({ Text = body, TextSize = 15, TextColor3 = C.Sub, TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, -48, 0, 92), Position = UDim2.fromOffset(24, 58), Parent = box })
    UIStyle.TextRole(b, "Label"); b.FontFace = UIStyle.RoleFace("Body"); b.TextSize = 15
    local function Close() shade:Destroy() end
    local no = UIStyle.Button(box, "CANCEL", C.Steel, UDim2.fromOffset(196, 44), UDim2.new(0, 24, 1, -64))
    local yes = UIStyle.Button(box, yesText or "CONFIRM", accent, UDim2.fromOffset(196, 44), UDim2.new(1, -220, 1, -64))
    no.Button.MouseButton1Click:Connect(Close)
    shade.MouseButton1Click:Connect(Close)
    yes.Button.MouseButton1Click:Connect(function()
        Close()
        onYes()
    end)
    if UIStyle.InstallType then pcall(UIStyle.InstallType, shade) end
end

function PopupUI.Dropdown(anchor: GuiObject, items: { any }, onPick: (any) -> ())
    local g = Gui()
    PopupUI.Close()
    local catcher = New("TextButton", { Name = "Dropdown", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), Parent = g }) :: TextButton
    -- (the anchor's own ScreenGui may sit under the top bar inset; this one ignores it)
    local sg = anchor:FindFirstAncestorWhichIsA("ScreenGui")
    local insetY = (sg and not sg.IgnoreGuiInset) and GuiService:GetGuiInset().Y or 0
    local ap, as = anchor.AbsolutePosition, anchor.AbsoluteSize
    local rowH = 28
    local vp = Workspace.CurrentCamera.ViewportSize
    local h = math.min(#items * rowH + 8, vp.Y - 20)
    local y = ap.Y + insetY + as.Y + 4
    if y + h > vp.Y - 10 then y = math.max(10, ap.Y + insetY - h - 4) end
    local w = math.max(as.X, 190)
    local list = New("ScrollingFrame", { Position = UDim2.fromOffset(math.min(ap.X, vp.X - w - 10), y), Size = UDim2.fromOffset(w, h),
        CanvasSize = UDim2.fromOffset(0, #items * rowH + 8), ScrollBarThickness = 4, ScrollBarImageColor3 = C.Steel,
        BackgroundColor3 = C.Bg0, BorderSizePixel = 0, Active = true, Parent = catcher },
        { UIStyle.Stroke(C.Line, 1), -- (UI CLEAN R-C: flat, square, one hairline)
          New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
          New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }) })
    for i, it in ipairs(items) do
        local col = it.Color or C.Text
        -- (UI CLEAN R-C: rows are words on the menu's slate -- the colour is the text (rarity), hover = one surface step)
        local b = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.Bg2, BackgroundTransparency = 1, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, rowH - 2), LayoutOrder = i, Parent = list }) :: TextButton
        local lt = UIStyle.Text({ Text = it.Text, TextSize = 15, TextColor3 = col, Size = UDim2.new(1, -18, 1, 0), Position = UDim2.fromOffset(10, 0), Parent = b })
        lt:SetAttribute("TypeRole", "Label")
        b.MouseEnter:Connect(function() b.BackgroundTransparency = 0 end)
        b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
        b.SelectionGained:Connect(function() b.BackgroundTransparency = 0 end)
        b.SelectionLost:Connect(function() b.BackgroundTransparency = 1 end)
        b.MouseButton1Click:Connect(function()
            catcher:Destroy()
            onPick(it.Value)
        end)
    end
    catcher.MouseButton1Click:Connect(function() catcher:Destroy() end)
    if UIStyle.InstallType then pcall(UIStyle.InstallType, catcher) end
end

return PopupUI
