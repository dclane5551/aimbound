--!nocheck
-- ============================================================================================
-- PARTY HUD (QOL2 H4, 2026-10-28; audit: teammates' state was invisible in a party run). NOT a revive: it only shows.
-- H4b (owner: "The party healthbars and stuff is horrible" -> slim lines over your own HUD, no boxed cards): one ~18 px line per
-- teammate in the bottom-left HUD column, stacked UP from just above the Build / Status chip rows (UI.HudStack.TopY): the
-- name (small caps label, like ROOKIE), a short flat 4 px bar in YOUR health bar's fill colour on the same dark track, and
-- lives as plain pips (UI CLEAN 2026-10-28: the hearts read "cheesy"): HudClean.Pips, the same as your own lives -- off-white
-- = a life left, dim = lost. DOWN (red) / OUT (grey) replace the bar + pips. No panel,
-- no card chrome -- only the HUD's own faint text stroke so it reads over bright floors.
-- Server feed = AimRngServer/PartyHud: Player attributes PartyHud (party id) + HpPct (5 % steps), plus the LIVES attributes
-- Lives / Downed / Spectating. Members = other players whose PartyHud equals yours; hidden solo and in the hub (yours is nil).
-- Event-driven: attribute-changed signals only (+ a re-place on a resize / phone preview), no per-frame work.
--   PartyHud.Init({ Parent = hudGui, HpColor = fn -> Color3, X = fn -> px, Bottom = fn -> offset from the screen bottom })
-- Studio: Player attr DevPartyHud = JSON list of fake members [{ "Name", "Hp", "Lives", "Down", "Out" }] (drawn as-is; "" = off);
--         DevPartyHudSelf = true lists you too (with the server's workspace attr DevPartyHudSolo: the real feed on a solo party run).
-- ============================================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))

local PartyHud = {}
local C = UIStyle.Colors
local LP = Players.LocalPlayer
local ROW_H, GAP = 18, 3
local NAME_W, BAR_W, BAR_H, HEARTS_W = 112, 100, 4, 80
local PER_RUN, HEART_MAX = 3, 5
local HudClean = require(script.Parent:WaitForChild("HudClean"))
local DOWN_C = C.Bad
local HP_DEFAULT = C.Text -- (the HUD's own HP fill when no getter)

local hooks: any = {}
local holder: Frame? = nil
local rows = {}
local conns = {}
local fake: any = nil
local queued = false

local function Mark(o: Instance) o:SetAttribute("Skinned", true); return o end

local function Lbl(parent: Instance, props: any): TextLabel
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.BorderSizePixel = 0
    l.Font = Enum.Font.GothamBlack; l.TextSize = 13; l.TextColor3 = C.Text
    l.TextStrokeTransparency = 0.72; l.TextStrokeColor3 = Color3.new(0, 0, 0)
    l.TextXAlignment = Enum.TextXAlignment.Left; l.TextYAlignment = Enum.TextYAlignment.Center
    for k, v in pairs(props) do l[k] = v end
    l:SetAttribute("TypeRole", "Label")
    Mark(l)
    l.Parent = parent
    return l
end

local function Row(i: number)
    if rows[i] then return rows[i] end
    local f = Instance.new("Frame")
    f.Name = "Mate" .. i; f.BackgroundTransparency = 1; f.BorderSizePixel = 0
    f.Size = UDim2.new(1, 0, 0, ROW_H); f.LayoutOrder = i
    Mark(f)
    local r = { Frame = f }
    r.Name = Lbl(f, { Name = "Name", Text = "", TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.fromOffset(NAME_W, ROW_H) })
    -- the bar: a flat dark track + the fill, vertically centred on the name
    local track = Instance.new("Frame")
    track.Name = "Bar"; track.BorderSizePixel = 0; track.BackgroundColor3 = C.Well or Color3.fromRGB(8, 8, 13); track.BackgroundTransparency = 0.15
    track.AnchorPoint = Vector2.new(0, 0.5); track.Position = UDim2.new(0, NAME_W + 8, 0.5, 0); track.Size = UDim2.fromOffset(BAR_W, BAR_H)
    Mark(track).Parent = f
    r.Track = track
    r.Fill = Instance.new("Frame")
    r.Fill.Name = "Fill"; r.Fill.BorderSizePixel = 0; r.Fill.Size = UDim2.fromScale(1, 1)
    Mark(r.Fill).Parent = track
    -- the lives: plain pips (HudClean.Pips, like your own lives)
    r.Hearts = Lbl(f, { Name = "Hearts", Text = "", RichText = true, TextSize = 12, Position = UDim2.fromOffset(NAME_W + 8 + BAR_W + 7, 0),
        Size = UDim2.fromOffset(HEARTS_W, ROW_H) })
    -- DOWN / OUT: in place of the bar + hearts
    r.State = Lbl(f, { Name = "State", Text = "", Position = UDim2.fromOffset(NAME_W + 8, 0), Size = UDim2.fromOffset(BAR_W, ROW_H), Visible = false })
    f.Parent = holder
    rows[i] = r
    return r
end

local function Paint(r: any, d: any)
    r.Name.Text = string.upper(tostring(d.Name or "?"))
    local hp = math.clamp(tonumber(d.Hp) or 100, 0, 100)
    local state = (d.Out and "OUT") or (d.Down and "DOWN") or nil
    r.Track.Visible = state == nil
    r.Hearts.Visible = state == nil
    r.State.Visible = state ~= nil
    r.Name.TextColor3 = d.Out and C.Sub or C.Text
    if state then
        r.State.Text = state
        r.State.TextColor3 = d.Out and C.Sub or DOWN_C
        return
    end
    r.Fill.Size = UDim2.fromScale(hp / 100, 1)
    r.Fill.BackgroundColor3 = (hooks.HpColor and hooks.HpColor()) or HP_DEFAULT
    local lives = math.max(0, math.floor(tonumber(d.Lives) or 0))
    local n = math.clamp(math.max(PER_RUN, lives), 1, HEART_MAX)
    local have = math.min(lives, n)
    r.Hearts.Text = HudClean.Pips(have, n)
end

local function DataOf(p: Player): any
    return { Name = p.DisplayName, Hp = p:GetAttribute("HpPct") or 100, Lives = p:GetAttribute("Lives") or 0,
        Down = p:GetAttribute("Downed") == true, Out = p:GetAttribute("Spectating") == true }
end

-- bottom-left column, its bottom edge just above the Build / Status chip rows (follows the phone layout)
-- (R1's DEATH RECAP card shows in the same column for 7 s after a life is lost: the lines step above it meanwhile)
local recapHooked = false
local function Place()
    if not holder then return end
    local x = hooks.X and hooks.X() or 16
    local bottom = hooks.Bottom and hooks.Bottom() or -278
    local card = hooks.Parent and hooks.Parent:FindFirstChild("DeathRecapCard")
    if card and card:IsA("GuiObject") then
        if not recapHooked then
            recapHooked = true
            card:GetPropertyChangedSignal("Visible"):Connect(Place)
            card:GetPropertyChangedSignal("Size"):Connect(Place)
        end
        if card.Visible then bottom = math.min(bottom, card.Position.Y.Offset - card.Size.Y.Offset - 6) end
    end
    holder.Position = UDim2.new(0, x, 1, bottom)
end

local function Refresh()
    queued = false
    if not holder then return end
    for _, c in ipairs(conns) do c:Disconnect() end
    table.clear(conns)
    local list = {} -- { data, player? }
    if fake then
        for _, d in ipairs(fake) do table.insert(list, { d }) end
    else
        local key = LP:GetAttribute("PartyHud")
        if key ~= nil then
            local incSelf = RunService:IsStudio() and LP:GetAttribute("DevPartyHudSelf") == true
            local mates = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if (p ~= LP or incSelf) and p:GetAttribute("PartyHud") == key then table.insert(mates, p) end
            end
            table.sort(mates, function(a, b) return a.DisplayName < b.DisplayName end)
            for _, p in ipairs(mates) do table.insert(list, { DataOf(p), p }) end
        end
    end
    holder.Visible = #list > 0
    for i, e in ipairs(list) do
        local r = Row(i)
        r.Frame.Visible = true
        Paint(r, e[1])
        local p = e[2]
        if p then
            for _, a in ipairs({ "HpPct", "Lives", "Downed", "Spectating" }) do
                table.insert(conns, p:GetAttributeChangedSignal(a):Connect(function() Paint(r, DataOf(p)) end))
            end
        end
    end
    for i = #list + 1, #rows do rows[i].Frame.Visible = false end
    holder.Size = UDim2.fromOffset(NAME_W + 8 + BAR_W + 7 + HEARTS_W, math.max(0, #list * (ROW_H + GAP) - GAP))
    Place()
end

local function Queue()
    if queued then return end
    queued = true
    task.defer(Refresh)
end

local function Watch(p: Player)
    p:GetAttributeChangedSignal("PartyHud"):Connect(Queue) -- (who is in my party changed; per-member stats are row signals)
end

function PartyHud.Init(h: any)
    hooks = h or {}
    holder = Instance.new("Frame")
    holder.Name = "PartyHud"; holder.BackgroundTransparency = 1; holder.Visible = false
    holder.AnchorPoint = Vector2.new(0, 1); holder.Size = UDim2.fromOffset(0, 0); holder.ZIndex = 5
    holder:SetAttribute("NoSkin", true)
    Mark(holder)
    local lay = Instance.new("UIListLayout"); lay.Padding = UDim.new(0, GAP); lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.VerticalAlignment = Enum.VerticalAlignment.Bottom; lay.Parent = holder
    holder.Parent = hooks.Parent
    Place()
    for _, p in ipairs(Players:GetPlayers()) do Watch(p) end
    Players.PlayerAdded:Connect(function(p) Watch(p); Queue() end)
    Players.PlayerRemoving:Connect(function() Queue() end)
    -- the HUD column moves on a phone (PhoneHUD re-lays it out deferred): re-place after it
    local function Later() task.delay(0.1, Place) end
    if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Later) end
    LP:GetAttributeChangedSignal("DevPhone"):Connect(Later)
    if RunService:IsStudio() then
        local function Dev()
            local raw = LP:GetAttribute("DevPartyHud")
            local ok, v = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
            fake = (type(raw) == "string" and raw ~= "" and ok and type(v) == "table") and v or nil
            Queue()
        end
        LP:GetAttributeChangedSignal("DevPartyHud"):Connect(Dev)
        LP:GetAttributeChangedSignal("DevPartyHudSelf"):Connect(Queue)
    end
    Queue()
    return PartyHud
end

return PartyHud
