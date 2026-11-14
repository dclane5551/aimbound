--!nocheck
-- ============================================================================================
-- PAD MENUS (QOL Q1 2026-10-28): controller play in the windows. What Roblox gives for free: every TextButton / ImageButton is
-- Selectable, the D-pad / left stick move GuiService.SelectedObject between them, A clicks the selected one (MouseButton1Click
-- + Activated fire), a ScrollingFrame scrolls to keep the selection in view -- but only once SOMETHING is selected (the
-- player had to find the Select / View button first), and the default highlight is a grey box. This adds:
--   * a first selection when a window opens with a pad in hand (OpenMenuFrame -> PadMenus.OnOpen) or when the pad is picked
--     up while a window is open: a window's own pick (PadMenus.SetFirst), else its first button in reading order (title-bar
--     X close buttons skipped);
--   * the selection is dropped when its window closes (no invisible selection eating A presses in play);
--   * an icon-look highlight (accent edge, no fill) for every selection (PlayerGui.SelectionImageObject).
-- B closes the window already (PlatformControls PAD_DOWN "Back" -> CloseAllMenus). No per-frame work: events only.
--   PadMenus.Init({ IsMenuOpen = fn -> bool, OpenFrame = fn -> Frame?, Accent = Color3 })
--   PadMenus.OnOpen(frame)              -- a window just opened
--   PadMenus.SetFirst(frame, fn)        -- fn(frame) -> GuiObject? = that window's first selection
-- Studio test hook: Player attr DevPad = true counts as a pad; DevPadPick -> the selected object's full name.
-- ============================================================================================
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PadMenus = {}

local hooks: any = {}
local firsts = setmetatable({}, { __mode = "k" })
local watched = setmetatable({}, { __mode = "k" })
local LocalPlayer = Players.LocalPlayer

local function IsPadInput(t: Enum.UserInputType): boolean
    return string.sub(t.Name, 1, 7) == "Gamepad"
end

function PadMenus.IsPad(): boolean
    if RunService:IsStudio() and LocalPlayer:GetAttribute("DevPad") then return true end
    if IsPadInput(UserInputService:GetLastInputType()) then return true end
    return UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
end

-- every ancestor up to `root` is shown
local function Shown(o: GuiObject, root: Instance): boolean
    local p: Instance? = o
    while p and p ~= root do
        if p:IsA("GuiObject") and not p.Visible then return false end
        if p:IsA("LayerCollector") and not p.Enabled then return false end
        p = p.Parent
    end
    return true
end

local function Usable(o: Instance, root: Instance): boolean
    if not (o:IsA("GuiButton") and o.Selectable and o.Active) then return false end
    if o.AbsoluteSize.X < 4 or o.AbsoluteSize.Y < 4 then return false end
    if o:IsA("TextButton") then
        local t = string.upper(o.Text)
        if t == "X" or t == "✕" or t == "×" then return false end -- (title-bar close: B does that)
    end
    if o.Name == "Close" or o.Name == "CloseButton" then return false end
    return Shown(o, root)
end

-- the window's first button in reading order (top row first, then left to right)
function PadMenus.FirstButton(frame: Instance): GuiObject?
    local best, by, bx = nil, math.huge, math.huge
    for _, d in ipairs(frame:GetDescendants()) do
        if Usable(d, frame) then
            local p = d.AbsolutePosition
            local y = math.floor(p.Y / 8) -- (buttons on one row differ by a few px)
            if y < by or (y == by and p.X < bx) then best, by, bx = d, y, p.X end
        end
    end
    return best
end

local function Select(frame: Instance)
    if not frame or not frame.Parent then return end
    local pick = nil
    local fn = firsts[frame]
    if fn then
        local ok, r = pcall(fn, frame)
        if ok and typeof(r) == "Instance" and r:IsA("GuiObject") and Usable(r, frame) then pick = r end
    end
    pick = pick or PadMenus.FirstButton(frame)
    if pick then
        pcall(function() GuiService.SelectedObject = pick end)
        if RunService:IsStudio() then LocalPlayer:SetAttribute("DevPadPick", pick:GetFullName()) end
    end
end

local function Watch(frame: Instance)
    if watched[frame] or not frame:IsA("GuiObject") then return end
    watched[frame] = true
    frame:GetPropertyChangedSignal("Visible"):Connect(function()
        if frame.Visible then return end
        local sel = GuiService.SelectedObject
        if sel and sel:IsDescendantOf(frame) then pcall(function() GuiService.SelectedObject = nil end) end
    end)
end

function PadMenus.SetFirst(frame: Instance, fn: (Instance) -> GuiObject?)
    firsts[frame] = fn
end

function PadMenus.OnOpen(frame: Instance?)
    if not frame then return end
    Watch(frame)
    if not PadMenus.IsPad() then return end
    -- (after the window's own refresh has built its rows)
    task.delay(0.05, function()
        if frame:IsA("GuiObject") and not frame.Visible then return end
        local sel = GuiService.SelectedObject
        if sel and sel:IsDescendantOf(frame) and sel.Visible then return end
        Select(frame)
    end)
end

function PadMenus.Init(h: any)
    hooks = h or {}
    -- the highlight: an accent edge round the selected button, no fill (icon-look UI: ink + accent, no grey box)
    local img = Instance.new("Frame")
    img.Name = "PadSelection"
    img.BackgroundTransparency = 1
    img.Size = UDim2.new(1, 6, 1, 6)
    img.Position = UDim2.fromOffset(-3, -3)
    img:SetAttribute("NoSkin", true)
    local st = Instance.new("UIStroke")
    st.Color = hooks.Accent or Color3.fromRGB(80, 220, 255)
    st.Thickness = 2
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    st.Parent = img
    local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0, 4); cr.Parent = img
    pcall(function() LocalPlayer:WaitForChild("PlayerGui").SelectionImageObject = img end)
    -- picked the pad up with a window open: select something in it
    UserInputService.LastInputTypeChanged:Connect(function(t)
        if not IsPadInput(t) or GuiService.SelectedObject then return end
        if hooks.IsMenuOpen and hooks.IsMenuOpen() and hooks.OpenFrame then
            local f = hooks.OpenFrame()
            if f and f.Visible then Select(f) end
        end
    end)
end

return PadMenus
