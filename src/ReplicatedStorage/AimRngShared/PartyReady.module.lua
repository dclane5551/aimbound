--!nocheck
-- READY CHECK pop-up (QOL F4, 2026-10-28; server = PartyService handlers.Start / Ready / ReadyCancel). The party leader's START asks
-- every member READY? for PartyService.READY_SECONDS (15 s). This card shows who is ready (✓), not ready or hasn't answered
-- (...); members answer READY / NOT READY, the leader sees START ANYWAY once the timer runs out (or START when everyone is ready --
-- the server starts by itself then) and CANCEL. Left side under the MENU button, away from the crosshair; no flashing; the countdown ticks 4x a second
-- only while the card is up.
--
--   PartyReady.Init({ Parent = hudGui, Click = fn(), Toast = fn(text) })
--   PartyReady.Dev(action) -- (Studio) "ready" / "notready" / "start" / "cancel" = the card's buttons
local Players = game:GetService("Players")
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))

local PartyReady = {}
local C = UIStyle.Colors
local LocalPlayer = Players.LocalPlayer
local GOOD, BAD = UIStyle.Colors.Good, UIStyle.Colors.Bad -- (UI CLEAN R-C: the quiet semantic colours)

local hooks: any = {}
local card: Frame? = nil
local ui: any = {}
local snap: any = nil
local ticking = false

local function Request(action: string, arg: any)
    task.spawn(function()
        local ok, a, b = pcall(function() return Remotes.GetFunction("PartyRequest"):InvokeServer(action, arg) end)
        if ok and a == false and type(b) == "string" and hooks.Toast then hooks.Toast(b) end
    end)
end

local function IsHost(): boolean
    return snap ~= nil and snap.HostUserId == LocalPlayer.UserId
end

local function Left(): number
    if not (snap and snap.Ready) then return 0 end
    return math.max(0, (snap.Ready.Until or 0) - workspace:GetServerTimeNow())
end

local function Build(parent: Instance)
    local f = Instance.new("Frame")
    f.Name = "ReadyCheck"; f.AnchorPoint = Vector2.new(0, 0); f.Position = UDim2.new(0, 16, 0, 200) -- (left, under the MENU button: the top centre holds the login / tutorial cards)
    f.Size = UDim2.fromOffset(340, 200); f.Visible = false; f.ZIndex = 30
    -- (UI CLEAN R-C: a small card -- the run HUD slate nearly solid, square, no facet / ink edge / gold top band; the title in
    -- display caps, the countdown a display number, the time line 2 px off-white; READY = the primary, NOT READY = secondary)
    local RunHud = require(script.Parent:WaitForChild("RunHud"))
    RunHud.Plate(f, RunHud.CARD_T)
    ui.Title = UIStyle.Text({ Text = "READY CHECK", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 12),
        Size = UDim2.new(1, -110, 0, 26), ZIndex = 31, Parent = f })
    RunHud.Role(ui.Title, "Title")
    ui.Timer = UIStyle.Text({ Text = "", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -96, 0, 12),
        Size = UDim2.fromOffset(80, 26), ZIndex = 31, Parent = f })
    RunHud.Num(ui.Timer, 20, C.Text)
    ui.Sub = UIStyle.Text({ Text = "", TextSize = 13, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(16, 38), Size = UDim2.new(1, -32, 0, 18), ZIndex = 31, Parent = f })
    RunHud.Role(ui.Sub, "Label"); ui.Sub.TextSize = 13
    -- the time line (a steady drain, no flashing)
    local bg = Instance.new("Frame"); bg.BorderSizePixel = 0; bg.BackgroundColor3 = C.Text; bg.BackgroundTransparency = 0.86; bg.Position = UDim2.fromOffset(16, 60)
    bg.Size = UDim2.new(1, -32, 0, 2); bg.ZIndex = 31; bg.Parent = f
    ui.Bar = Instance.new("Frame"); ui.Bar.BorderSizePixel = 0; ui.Bar.BackgroundColor3 = C.Text
    ui.Bar.Size = UDim2.fromScale(1, 1); ui.Bar.ZIndex = 32; ui.Bar.Parent = bg
    ui.List = Instance.new("Frame"); ui.List.BackgroundTransparency = 1; ui.List.Position = UDim2.fromOffset(16, 70)
    ui.List.Size = UDim2.new(1, -32, 0, 0); ui.List.ZIndex = 31; ui.List.Parent = f
    local lay = Instance.new("UIListLayout"); lay.Padding = UDim.new(0, 4); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Parent = ui.List
    ui.BtnA = UIStyle.Button(f, "READY", C.Accent, UDim2.fromOffset(148, 40), UDim2.new(0, 16, 1, -52), "ReadyA")
    ui.BtnB = UIStyle.Button(f, "NOT READY", C.Steel, UDim2.fromOffset(148, 40), UDim2.new(1, -164, 1, -52), "ReadyB")
    for _, b in ipairs({ ui.BtnA, ui.BtnB }) do b.Button.ZIndex = 31; b.Label.ZIndex = 32 end
    ui.BtnA.Button.MouseButton1Click:Connect(function() if ui.BtnA.Button.Active then PartyReady.Dev(IsHost() and "start" or "ready") end end)
    ui.BtnB.Button.MouseButton1Click:Connect(function() if ui.BtnB.Button.Active then PartyReady.Dev(IsHost() and "cancel" or "notready") end end)
    f.Parent = parent
    return f
end

local function Render(full: boolean?)
    if not card then return end
    local rc = snap and snap.Ready
    local show = rc ~= nil and snap.State == "Lobby"
    card.Visible = show
    if not show then return end
    local secs = rc.Secs or 15
    local left = Left()
    local answers = rc.Answers or {}
    -- rows: every member, the leader first (rebuilt only when the room changes, not on the countdown ticks)
    if full then for _, c in ipairs(ui.List:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end end
    local nReady = 0
    for i, m in ipairs(snap.Members or {}) do
        local a = answers[tostring(m.UserId)]
        if a == true then nReady += 1 end
        if not full then continue end
        local mark, col = "...", C.Sub
        if a == true then mark, col = "✓ READY", GOOD elseif a == false then mark, col = "NOT READY", BAD end -- (the cross glyph has no shape in this font)
        local row = UIStyle.Text({ Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
            Text = string.format('%s%s  <font color="#%s">%s</font>', m.IsHost and "★ " or "", m.Name, col:ToHex(), mark),
            Size = UDim2.new(1, 0, 0, 22), LayoutOrder = m.IsHost and 0 or i, ZIndex = 31, Parent = ui.List })
        row.Name = "M" .. i
        row:SetAttribute("TextRole", "Body")
    end
    local n = #(snap.Members or {})
    ui.List.Size = UDim2.new(1, -32, 0, n * 26)
    card.Size = UDim2.fromOffset(340, 70 + n * 26 + 62)
    ui.Timer.Text = (left > 0) and (math.ceil(left) .. " s") or "0 s"
    ui.Bar.Size = UDim2.fromScale(math.clamp(left / secs, 0, 1), 1)
    local all = nReady >= n
    if IsHost() then
        ui.Sub.Text = all and "Everyone is ready: starting..." or (left > 0 and string.format("%d / %d ready. Waiting for your party.", nReady, n)
            or string.format("%d / %d ready. Time's up: you can start anyway.", nReady, n))
        ui.BtnA.SetText(all and "START" or "START ANYWAY")
        ui.BtnA.SetEnabled(all or left <= 0)
        ui.BtnB.SetText("CANCEL")
        ui.BtnB.SetEnabled(true)
    else
        local mine = answers[tostring(LocalPlayer.UserId)]
        ui.Sub.Text = (mine == nil) and "Your leader wants to start the run. Are you ready?" or string.format("%d / %d ready. Waiting for the leader.", nReady, n)
        ui.BtnA.SetText("READY"); ui.BtnB.SetText("NOT READY")
        ui.BtnA.SetEnabled(mine ~= true); ui.BtnB.SetEnabled(mine ~= false)
    end
end

-- the countdown: 4 times a second while the card is up (nothing runs while it's hidden)
local function Tick()
    if ticking then return end
    ticking = true
    task.spawn(function()
        while card and card.Visible do
            Render(false)
            task.wait(0.25)
        end
        ticking = false
    end)
end

function PartyReady.Dev(action: string)
    if hooks.Click then hooks.Click() end
    if action == "ready" then Request("Ready", true)
    elseif action == "notready" then Request("Ready", false)
    elseif action == "start" then Request("Start")
    elseif action == "cancel" then Request("ReadyCancel") end
end

function PartyReady.Init(h: any)
    hooks = h or {}
    card = Build(hooks.Parent)
    Remotes.GetEvent("PartyUpdate").OnClientEvent:Connect(function(s)
        snap = s
        Render(true)
        if card.Visible then Tick() end
    end)
    if game:GetService("RunService"):IsStudio() then -- (Studio: Player attr DevReadySnap = a room snapshot as JSON, drawn as if the server sent it)
        LocalPlayer:GetAttributeChangedSignal("DevReadySnap"):Connect(function()
            local ok, s = pcall(function() return game:GetService("HttpService"):JSONDecode(LocalPlayer:GetAttribute("DevReadySnap") or "null") end)
            snap = ok and s or nil
            Render(true)
            if card.Visible then Tick() end
        end)
    end
    return PartyReady
end

return PartyReady
