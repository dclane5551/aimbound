--!nocheck
-- ============================================================================================
-- BOUND SHOP POPUP (client; 2026-10-20 owner: "Stashes and such should cost boundpoints, and when clicking to buy
-- anything, it should give a popup of however many boundpoints you would need to purchase that item").
-- Every BOUND-point purchase goes through one confirm window: what you're buying, its price, your balance and, when
-- you're short, how many more you need + GET BOUND (the Robux packs, Colorways.PACKS via ColorwayAction "Points").
-- The balance is the player attribute BoundPoints (the server mirrors state.BoundPoints into it); the window updates
-- live, so buying a pack while it's open turns GET BOUND into BUY.
--   BoundShop.Confirm({ Name = "Gem Tab", Price = 99, Desc = "+50 gem room", OnBuy = function() -> (ok, msg?) end })
--     optional Robux = { Price = 499, OnBuy = function() -> (ok, msg?) end }: a second BUY WITH ROBUX button (2026-10-20
--     owner: the season pass also straight for Robux, next to the BOUND price)
--   BoundShop.OpenPacks()          -- the pack window on its own
--   BoundShop.Have() -> number
-- OnBuy runs the real purchase (the server checks and charges); a false result shows its message in the window.
-- ============================================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("AimRngShared")
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local Colorways = require(Shared:WaitForChild("Colorways"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local LocalPlayer = Players.LocalPlayer
local BoundShop = {}

local C = UIStyle.Colors
local BP_COL = Color3.fromRGB(48, 226, 255) -- (UI v4: the neon cyan)
local New = UIStyle.New

local gui: ScreenGui? = nil
local confirmCard: Frame? = nil
local packsCard: Frame? = nil
local pending: any = nil
local refs: any = {}

function BoundShop.Have(): number
    return math.floor(tonumber(LocalPlayer:GetAttribute("BoundPoints")) or 0)
end

local function Fmt(n: number): string
    return ItemData.FormatNumber and ItemData.FormatNumber(n) or tostring(n)
end

local function Click()
    pcall(function() require(Shared:WaitForChild("SoundHelper")).Play("Click") end)
end

local function Text(props: any): TextLabel
    props.BackgroundTransparency = 1
    props.Font = props.Font or UIStyle.Font
    props.TextColor3 = props.TextColor3 or C.Text
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
    return New("TextLabel", props) :: TextLabel
end

-- fits a fixed-size card on small screens (phones)
local function FitScale(card: Frame, _w: number, _h: number)
    local sc = New("UIScale", { Parent = card }) :: UIScale
    local function Upd() -- (UIStyle.Screen / SimK: the planned screen, so a Studio DevPhone preview shows the phone layout)
        local w, h = card.Size.X.Offset, card.Size.Y.Offset -- (the confirm card grows a row for the Robux option)
        local vp = UIStyle.Screen()
        sc.Scale = math.min(1, (vp.X - 24) / w, (vp.Y - 24 - UIStyle.TopInset()) / h) * UIStyle.SimK()
    end
    Upd()
    if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Upd) end
    LocalPlayer:GetAttributeChangedSignal("DevPhone"):Connect(Upd)
    card:GetPropertyChangedSignal("Size"):Connect(Upd)
end

local function Close()
    pending = nil
    -- (RUNFIX 2026-11-07) Confirm selects the BUY button (pads); a selection left on a hidden window keeps UI navigation on
    -- -- the revive popup closed straight back into the fight with it still set
    pcall(function()
        local sel = GuiService.SelectedObject
        if sel and gui and sel:IsDescendantOf(gui) then GuiService.SelectedObject = nil end
    end)
    if gui then gui.Enabled = false end
end

local function Render()
    if not (confirmCard and pending) then return end
    local have, price = BoundShop.Have(), math.floor(tonumber(pending.Price) or 0)
    local short = math.max(0, price - have)
    refs.Title.Text = "BUY " .. string.upper(tostring(pending.Name or "THIS"))
    refs.Desc.Text = tostring(pending.Desc or "")
    refs.Price.Text = Fmt(price)
    refs.Have.Text = "You have " .. Fmt(have) .. " BOUND"
    if short > 0 then
        refs.Need.Text = "You need " .. Fmt(short) .. " more BOUND points"
        refs.Need.TextColor3 = C.Bad
        refs.Buy.Label.Text = "GET BOUND"
    else
        refs.Need.Text = "After buying: " .. Fmt(have - price) .. " BOUND"
        refs.Need.TextColor3 = C.Sub
        refs.Buy.Label.Text = "BUY  -  " .. Fmt(price)
    end
    refs.Msg.Text = ""
end

local function Build()
    if gui then return end
    local g = New("ScreenGui", { Name = "BoundShopGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 250,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false, Parent = LocalPlayer:WaitForChild("PlayerGui") }) :: ScreenGui
    gui = g
    -- dim backdrop (a modal button: frees the mouse in first person, eats clicks behind the window)
    local dim = New("TextButton", { Name = "Dim", Text = "", AutoButtonColor = false, Modal = true, BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Parent = g })
    dim.MouseButton1Click:Connect(function() end)

    -- ===== the confirm card =====
    local W, H = 460, 300
    local card = New("Frame", { Name = "Confirm", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H),
        BackgroundColor3 = C.Bg0, Parent = g }, { UIStyle.Corner(2) }) :: Frame
    do local st = UIStyle.Stroke(C.Text, 1); st.Transparency = 0.84; st.Parent = card end -- (UI CLEAN R-A: the window body + one hairline, as PopupUI)
    FitScale(card, W, H)
    confirmCard = card
    refs.Title = Text({ Text = "BUY", TextSize = 24, TextColor3 = C.Accent, TextScaled = true, Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -40, 0, 30), Parent = card })
    New("UITextSizeConstraint", { MaxTextSize = 24, Parent = refs.Title })
    refs.Desc = Text({ Text = "", Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Sub, TextWrapped = true, Position = UDim2.fromOffset(24, 48), Size = UDim2.new(1, -48, 0, 36), Parent = card })
    refs.Price = Text({ Text = "0", TextSize = 46, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, 50), Parent = card })
    Text({ Text = "BOUND POINTS", TextSize = 13, TextColor3 = C.Sub, Position = UDim2.fromOffset(0, 136), Size = UDim2.new(1, 0, 0, 16), Parent = card })
    refs.Have = Text({ Text = "", Font = UIStyle.BodyFont, TextSize = 15, TextColor3 = C.Text, Position = UDim2.fromOffset(0, 164), Size = UDim2.new(1, 0, 0, 20), Parent = card })
    refs.Need = Text({ Text = "", Font = UIStyle.BodyFont, TextSize = 15, TextColor3 = C.Sub, Position = UDim2.fromOffset(0, 186), Size = UDim2.new(1, 0, 0, 20), Parent = card })
    refs.Msg = Text({ Text = "", Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = C.Bad, TextWrapped = true, Position = UDim2.fromOffset(20, 206), Size = UDim2.new(1, -40, 0, 18), Parent = card })
    local buy = UIStyle.Button(card, "BUY", C.Accent, UDim2.fromOffset(250, 48), UDim2.new(0, 20, 1, -66), "BoundBuy") -- (UI CLEAN R-A: the primary)
    local cancel = UIStyle.Button(card, "CANCEL", C.Steel, UDim2.fromOffset(160, 48), UDim2.new(1, -180, 1, -66), "BoundCancel")
    refs.Buy = buy
    local rbx = UIStyle.Button(card, "BUY WITH ROBUX", C.Steel, UDim2.new(1, -40, 0, 44), UDim2.new(0, 20, 1, -120), "BoundRobux")
    rbx.Button.Visible = false
    refs.Rbx = rbx
    rbx.Button.MouseButton1Click:Connect(function()
        Click()
        local p = pending
        if not (p and p.Robux and not refs.Busy) then return end
        local okCall, ok, msg = pcall(function() return p.Robux.OnBuy() end)
        if okCall and ok ~= false then Close() else refs.Msg.Text = tostring((okCall and msg) or "That didn't go through. Try again.") end
    end)
    local function Press()
        local p = pending
        if not p then return end
        if BoundShop.Have() < math.floor(tonumber(p.Price) or 0) then BoundShop.OpenPacks() return end
        if refs.Busy then return end
        refs.Busy = true
        refs.Buy.Label.Text = "..."
        local okCall, ok, msg = pcall(function() return p.OnBuy() end)
        refs.Busy = false
        if pending ~= p then return end
        if okCall and ok ~= false then
            Close()
        else
            Render()
            refs.Msg.Text = tostring((okCall and msg) or "That didn't go through. Try again.")
        end
    end
    refs.Press = Press
    buy.Button.MouseButton1Click:Connect(function() Click(); Press() end)
    cancel.Button.MouseButton1Click:Connect(function() Click(); Close() end)

    -- ===== the pack card =====
    local PW, PH = 700, 380
    local pc = New("Frame", { Name = "Packs", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(PW, PH),
        BackgroundColor3 = C.Bg0, Visible = false, ZIndex = 5, Parent = g }, { UIStyle.Corner(2) }) :: Frame
    do local st = UIStyle.Stroke(C.Text, 1); st.Transparency = 0.84; st.Parent = pc end
    FitScale(pc, PW, PH)
    packsCard = pc
    Text({ Text = "GET BOUND POINTS", TextSize = 26, TextColor3 = BP_COL, Position = UDim2.fromOffset(24, 14), Size = UDim2.new(1, -48, 0, 32), ZIndex = 6, Parent = pc })
    refs.PackHave = Text({ Text = "", Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Sub, Position = UDim2.fromOffset(24, 48), Size = UDim2.new(1, -48, 0, 20), ZIndex = 6, Parent = pc })
    local grid = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 78), Size = UDim2.new(1, -48, 0, 220), ZIndex = 6, Parent = pc }, {
        New("UIGridLayout", { CellSize = UDim2.new(0.25, -9, 0, 104), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Center }),
    })
    for i, pack in ipairs(Colorways.PACKS) do
        -- (UI CLEAN R-A: the target's card -- raised surface, no box; the price strip below stays the BOUND colour)
        local b = New("TextButton", { Name = "Pack_" .. pack.Id, Text = "", AutoButtonColor = false, BackgroundColor3 = C.Text, BackgroundTransparency = 0.955, BorderSizePixel = 0, LayoutOrder = i, ZIndex = 7, Parent = grid })
        b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.915 end)
        b.MouseLeave:Connect(function() b.BackgroundTransparency = 0.955 end)
        Text({ Text = Fmt(pack.Points), TextSize = 28, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 32), ZIndex = 8, Parent = b })
        Text({ Text = "BOUND POINTS", TextSize = 11, TextColor3 = C.Sub, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 14), ZIndex = 8, Parent = b })
        Text({ Text = pack.Note and ("BONUS " .. pack.Note) or "", TextSize = 11, TextColor3 = C.Gold, Position = UDim2.fromOffset(0, 55), Size = UDim2.new(1, 0, 0, 14), ZIndex = 8, Parent = b })
        local bar = New("Frame", { BackgroundColor3 = BP_COL, Position = UDim2.new(0, 8, 1, -30), Size = UDim2.new(1, -16, 0, 24), ZIndex = 8, Parent = b }, { UIStyle.Corner(2) })
        Text({ Text = "R$ " .. tostring(pack.Price), TextSize = 14, TextColor3 = Color3.fromRGB(10, 14, 22), Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = bar })
        b.MouseButton1Click:Connect(function()
            Click()
            local okCall, ok, msg = pcall(function() return Remotes.GetFunction("ColorwayAction"):InvokeServer("Points", pack.Id) end)
            if okCall and not ok then refs.PackHave.Text = tostring(msg or "Not available yet.") end
        end)
    end
    local back = UIStyle.Button(pc, "BACK", C.Steel, UDim2.fromOffset(160, 44), UDim2.new(1, -184, 1, -60), "PacksBack")
    back.Button.ZIndex = 7
    back.Button.MouseButton1Click:Connect(function()
        Click()
        pc.Visible = false
        if pending then card.Visible = true; Render() else Close() end
    end)

    LocalPlayer:GetAttributeChangedSignal("BoundPoints"):Connect(function()
        if refs.PackHave then refs.PackHave.Text = "You have " .. Fmt(BoundShop.Have()) .. " BOUND. Bigger packs give more points per Robux; points can also be traded." end
        if pending and not refs.Busy then Render() end
    end)
end

function BoundShop.OpenPacks()
    Build()
    if not (gui and packsCard and confirmCard) then return end
    refs.PackHave.Text = "You have " .. Fmt(BoundShop.Have()) .. " BOUND. Bigger packs give more points per Robux; points can also be traded."
    confirmCard.Visible = false
    packsCard.Visible = true
    gui.Enabled = true
end

function BoundShop.Confirm(opts: any)
    if type(opts) ~= "table" or type(opts.OnBuy) ~= "function" then return end
    Build()
    if not (gui and confirmCard and packsCard) then return end
    pending = opts
    refs.Busy = false
    packsCard.Visible = false
    confirmCard.Visible = true
    local r = type(opts.Robux) == "table" and type(opts.Robux.OnBuy) == "function" and opts.Robux or nil
    refs.Rbx.Button.Visible = r ~= nil
    if r then refs.Rbx.Label.Text = "BUY WITH ROBUX  -  R$ " .. tostring(r.Price or "") end
    confirmCard.Size = UDim2.fromOffset(460, r and 354 or 300)
    Render()
    gui.Enabled = true
    pcall(function() GuiService.SelectedObject = refs.Buy.Button end)
end

-- (Studio test hooks: Player attr DevAct "boundpress" / "boundcancel" -- agents can't click)
function BoundShop.DevPress()
    if refs.Press and gui and gui.Enabled and confirmCard and confirmCard.Visible then task.spawn(refs.Press) end
end
BoundShop.DevCancel = Close

function BoundShop.IsOpen(): boolean
    return gui ~= nil and gui.Enabled
end

return BoundShop
