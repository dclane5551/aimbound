--!nocheck
-- ============================================================================================
-- TOAST STACK (QOL L4 2026-10-28, owner audit: "one message overwrites the last"): the client's ShowToast lines stack --
-- up to MAX lines (3 on short screens), newest on top, each fading on its own. Important lines (BAG FULL, REVIVED, items left
-- behind / still on the ground, or Show(text, true)) stay IMPORTANT_S instead of NORMAL_S. The same text again only refreshes
-- its line (no duplicates). Below the crosshair: the stack's bottom edge sits where the old single toast sat (above the
-- HUD) and grows upward; with a window open it sits on the screen's bottom edge (3 lines at most) and grows upward --
-- PRE-PUBLISH 2026-10-31: at the top centre it covered the full-screen windows' top bar (nav + buttons) and at the old spot
-- the RUN SUMMARY's footer (RUN AGAIN). No per-frame work: tweens + delays.
--   ToastStack.Init(template: TextLabel, parent: Instance)   -- template = the old toast label (cloned per line, kept hidden)
--   ToastStack.Show(text: string, important: boolean?, atTop: boolean?)
-- ============================================================================================
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ToastStack = {}

local MAX, MAX_SHORT, MAX_WINDOW = 4, 3, 3
local WINDOW_Y = -12 -- (the stack's bottom edge with a window open, HUD units from the screen bottom)
local windowMode = false
local NORMAL_S, IMPORTANT_S = 3.5, 7
local IMPORTANT_WORDS = { "BAG FULL", "REVIVED", "LEFT BEHIND", "YOU LEFT BEHIND", "STILL ON THE GROUND", "LOST LOOT" }

local template: TextLabel? = nil
local holder: Frame? = nil
local layout: UIListLayout? = nil
local lines = {} -- { { Label, Text, Token, Seq } } oldest first
local seq = 0

local function Tw(o: Instance, t: number, goal: any)
    TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), goal):Play()
end

local function Fade(lbl: TextLabel, show: boolean, t: number)
    local a = show and 0 or 1
    Tw(lbl, t, { TextTransparency = a, BackgroundTransparency = show and (lbl:GetAttribute("PlateT") or 0.04) or 1 })
    local edge, blk = lbl:FindFirstChild("ToastEdge"), lbl:FindFirstChild("Block")
    if edge then Tw(edge, t, { Transparency = a }) end
    if blk then Tw(blk, t, { BackgroundTransparency = a }) end
end

local function Remove(e: any, fast: boolean?)
    local i = table.find(lines, e)
    if i then table.remove(lines, i) end
    if e.Gone then return end
    e.Gone = true
    local lbl = e.Label
    Fade(lbl, false, fast and 0.1 or 0.22)
    task.delay(fast and 0.11 or 0.24, function() lbl:Destroy() end)
end

local function Arm(e: any, important: boolean)
    e.Token += 1
    local my = e.Token
    task.delay(important and IMPORTANT_S or NORMAL_S, function()
        if e.Token == my then Remove(e) end
    end)
end

-- (UI CLEAN P2: the bottom edge of the stack, HUD units from the screen bottom; HudClean moves it above the phone's centred
-- HUD column)
local bottomY = -128
function ToastStack.SetBottom(y: number)
    bottomY = y
    if holder and not windowMode then holder.Position = UDim2.new(0.5, 0, 1, bottomY) end
end

function ToastStack.Init(tpl: TextLabel, parent: Instance)
    template = tpl
    tpl.Visible = false
    holder = Instance.new("Frame")
    holder.Name = "ToastStack"
    holder.BackgroundTransparency = 1
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.Size = UDim2.fromOffset(660, 0)
    holder.AnchorPoint = Vector2.new(0.5, 1)
    holder.Position = UDim2.new(0.5, 0, 1, bottomY)
    holder.ZIndex = 50
    holder:SetAttribute("NoSkin", true)
    holder.Parent = parent
    layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.Padding = UDim.new(0, 6)
    layout.Parent = holder
end

function ToastStack.Show(text: string, important: boolean?, atTop: boolean?)
    if not template or not holder then return end
    text = tostring(text)
    if important == nil then
        local up = string.upper(text)
        for _, w in ipairs(IMPORTANT_WORDS) do
            if string.find(up, w, 1, true) then important = true; break end
        end
    end
    -- where: above the HUD, or on the screen's bottom edge while a window is open (both grow up). The param keeps its old
    -- name: callers pass "a window is open".
    local win = atTop == true
    if win ~= windowMode then
        windowMode = win
        holder.AnchorPoint = Vector2.new(0.5, 1)
        holder.Position = UDim2.new(0.5, 0, 1, win and WINDOW_Y or bottomY)
        if layout then layout.VerticalAlignment = Enum.VerticalAlignment.Bottom end
    end
    seq += 1
    -- the same line again: refresh it (and bring it to the top)
    for _, e in ipairs(lines) do
        if e.Text == text and not e.Gone then
            e.Label.LayoutOrder = -seq
            e.Important = e.Important or important == true
            Arm(e, e.Important)
            return
        end
    end
    local cam = Workspace.CurrentCamera
    local cap = windowMode and MAX_WINDOW or ((cam and cam.ViewportSize.Y < 600) and MAX_SHORT or MAX)
    while #lines >= cap do -- (full: the oldest everyday line goes first; an important one only if every line is important)
        local victim = lines[1]
        for _, e in ipairs(lines) do if not e.Important then victim = e; break end end
        Remove(victim, true)
    end
    local lbl = template:Clone()
    lbl.Name = "Toast"
    lbl.Text = text
    lbl.TextWrapped = #text > 76 -- (UI CLEAN R-C: one line sized to the words; only a long line wraps -- auto-size + wrap made narrow 2-line boxes)
    lbl.AnchorPoint = Vector2.zero
    lbl.Position = UDim2.new()
    lbl.LayoutOrder = -seq -- (newest on top)
    lbl.TextTransparency, lbl.BackgroundTransparency = 1, 1
    if important and not lbl:FindFirstChild("Block") then -- (UI CLEAN R-C: an important line = ONE 2 px off-white tick on its left)
        local b = Instance.new("Frame")
        b.Name = "Block"; b.BorderSizePixel = 0; b.BackgroundColor3 = Color3.fromRGB(236, 232, 225); b.ZIndex = lbl.ZIndex
        local pad = lbl:FindFirstChildOfClass("UIPadding")
        local pl, pt = pad and pad.PaddingLeft.Offset or 0, pad and pad.PaddingTop.Offset or 0
        b.Size = UDim2.new(0, 2, 1, pt * 2); b.Position = UDim2.fromOffset(-pl, -pt)
        b:SetAttribute("Skinned", true); b.Parent = lbl
    end
    local edge, blk = lbl:FindFirstChild("ToastEdge"), lbl:FindFirstChild("Block")
    if edge then edge.Transparency = 1 end
    if blk then blk.BackgroundTransparency = 1 end
    lbl.Visible = true
    lbl.Parent = holder
    Fade(lbl, true, 0.16)
    local e = { Label = lbl, Text = text, Token = 0, Important = important == true }
    table.insert(lines, e)
    Arm(e, e.Important)
end

return ToastStack
