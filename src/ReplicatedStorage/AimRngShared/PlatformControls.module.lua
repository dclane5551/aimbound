--!nocheck
-- PLATFORM CONTROLS (client): phones / tablets (touch buttons + drag to look) and gamepads (right stick look, triggers).
-- Owner (2026-10-02): "Ensure the game properly functions on all platforms." Keyboard + mouse stay in AimRngClient /
-- MovementController; this module only turns touch / gamepad input into the SAME actions through hooks:
--   PlatformControls.Start({
--     Look(deltaPx: Vector2)      -- first-person look, in mouse pixels (the camera applies sensitivity / zoom)
--     Orbit(deltaPx: Vector2)     -- the third-person hub camera
--     Fire(down) Aim(down) Reload() Melee() Swap() Inspect()
--     Move(name, down)            -- MovementController.Action: "Dash" | "Slide" | "Jump"
--     Menu() Back()               -- gamepad Start = settings, B with a menu open = close it
--     Mode() -> "Play" | "Hub" | "Menu" | "Off"   -- what the screen is doing right now
--     Assist = { Allowed(), Nudge(yawRad, pitchRad), Exclude() }  -- touch AIM ASSIST (AimRngShared/AimAssist), PvE only
--   })
-- Touch layout scales with the screen's short side; the Roblox thumbstick (left) and jump button (bottom right) stay.
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Shared = script.Parent
local GameSettings = require(Shared:WaitForChild("GameSettings"))
local okUI, UIStyle = pcall(function() return require(Shared:WaitForChild("UIStyle")) end)
if not okUI then UIStyle = nil end

local PC = {}
local started = false

-- ==================== touch ====================
-- buttons: offsets from the bottom-right corner in units of s (centre point), size in s
local BUTTONS = {
    { Id = "Fire",    Label = "FIRE",  X = -3.25, Y = -1.55, Size = 1.45, Hold = true, Col = Color3.fromRGB(235, 70, 70), LookDrag = true },
    { Id = "Aim",     Label = "AIM",   X = -4.75, Y = -0.95, Size = 0.95, Hold = true, Col = Color3.fromRGB(90, 160, 255) },
    { Id = "Reload",  Label = "R",     X = -1.05, Y = -3.05, Size = 0.8, Col = Color3.fromRGB(255, 200, 70) },
    { Id = "Dash",    Label = "DASH",  X = -2.25, Y = -2.85, Size = 0.85, Col = Color3.fromRGB(80, 220, 200) },
    { Id = "Slide",   Label = "SLIDE", X = -3.5,  Y = -3.15, Size = 0.85, Hold = true, Col = Color3.fromRGB(80, 220, 200) },
    { Id = "Swap",    Label = "SWAP",  X = -4.7,  Y = -2.25, Size = 0.75, Col = Color3.fromRGB(190, 190, 210) },
    { Id = "Melee",   Label = "MELEE", X = -5.75, Y = -1.45, Size = 0.75, Col = Color3.fromRGB(255, 140, 70) },
    { Id = "Inspect", Label = "T",     X = -3.45, Y = -4.35, Size = 0.62, Col = Color3.fromRGB(190, 190, 210) },
    -- the duel ability (2026-10-15; only shown in a duel; PC.AbilityFn is set by PvpClient)
    { Id = "Ability", Label = "SKILL", X = -2.15, Y = -4.2,  Size = 0.75, Col = Color3.fromRGB(255, 70, 70), DuelOnly = true },
    -- a second trigger above the thumbstick (left thumb shoots, right thumb aims)
    { Id = "FireL",   Label = "FIRE",  X = 1.35,  Y = -4.1,  Size = 0.95, Hold = true, Col = Color3.fromRGB(235, 70, 70), Left = true },
}
-- PHONES (UIStyle.IsPhone): per-button overrides of X / Y / Size (same units); a button not listed keeps BUTTONS. The
-- corner right of FIRE stays free for Roblox's own JUMP button; the left FIRE always sits right of the side dock (Layout).
PC.PHONE_POS = {
}

local function StartTouch(h)
    local lp = Players.LocalPlayer
    local gui = Instance.new("ScreenGui")
    gui.Name = "AimRngTouch"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 4
    gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
    gui.Parent = lp:WaitForChild("PlayerGui")
    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.fromScale(1, 1)
    holder.Parent = gui

    local buttons = {}
    PC._buttons = buttons
    local lookTouches = {} -- InputObject -> true (drags that turn the camera)
    local fireDown = {}    -- button id -> true

    -- (2026-10-13, owner's phone test) sized on the PLANNED screen (UIStyle.Screen / SimK: a Studio DevPhone preview now
    -- draws the buttons at the size a real phone of that height gets). Phones (UIStyle.IsPhone) use PC.PHONE_POS: the
    -- cluster hugs the bottom-right corner (thumb arc round FIRE), clear of the HUD column, the dock and the crosshair; the
    -- left FIRE sits right of the dock. Tablets keep BUTTONS as they were (owner: tablets "did better").
    local function Layout()
        local cam = workspace.CurrentCamera
        local real = cam and cam.ViewportSize or Vector2.new(1280, 720)
        local plan = (UIStyle and UIStyle.Screen) and UIStyle.Screen() or real
        local k = (UIStyle and UIStyle.SimK) and UIStyle.SimK() or 1
        local phone = (UIStyle and UIStyle.IsPhone and UIStyle.IsPhone()) or false
        local s = math.clamp(math.min(plan.X, plan.Y) * 0.105, 48, 92) * k * ((tonumber(GameSettings.Get("TouchButtonSize")) or 100) / 100)
        PC._s, PC._phone = s, phone
        for _, b in ipairs(BUTTONS) do
            local f = buttons[b.Id]
            if f then
                local pp = (phone and PC.PHONE_POS[b.Id]) or b
                local px = (pp.Size or b.Size) * s
                f.Size = UDim2.fromOffset(px, px)
                f.AnchorPoint = Vector2.new(0.5, 0.5)
                if b.Left then
                    local x = pp.X * s
                    -- (phones: right of the side dock, whatever width it wrapped to)
                    local dock = phone and PC._dock
                    if dock and dock.Parent and dock.Visible and dock.AbsoluteSize.X > 0 then
                        x = math.max(x, dock.AbsolutePosition.X + dock.AbsoluteSize.X + px * 0.5 + 0.25 * s)
                    end
                    f.Position = UDim2.new(0, x, 1, pp.Y * s)
                else
                    f.Position = UDim2.new(1, pp.X * s, 1, pp.Y * s)
                end
                local lbl = f:FindFirstChild("Label")
                if lbl then lbl.TextSize = math.max(10, px * (#b.Label > 2 and 0.24 or 0.42)) end
            end
        end
    end
    PC.Layout = Layout

    local function Press(id, down)
        if id == "Fire" or id == "FireL" then
            fireDown[id] = down or nil
            if PC._assist then PC._assist.SetFiring(next(fireDown) ~= nil) end
            h.Fire(next(fireDown) ~= nil)
        elseif id == "Aim" then h.Aim(down)
        elseif id == "Slide" then h.Move("Slide", down)
        elseif down then
            if id == "Reload" then h.Reload()
            elseif id == "Dash" then h.Move("Dash", true)
            elseif id == "Swap" then h.Swap()
            elseif id == "Melee" then h.Melee()
            elseif id == "Inspect" then h.Inspect()
            elseif id == "Ability" then if PC.AbilityFn then PC.AbilityFn() end end
        end
    end

    for _, b in ipairs(BUTTONS) do
        local f = Instance.new("TextButton")
        f.Name = b.Id
        f.Text = ""
        f.AutoButtonColor = false
        -- (UI CLEAN R-C: the run HUD look -- a round slate (round is right for a thumb button), ONE 1.5 px off-white ring
        -- (brighter on the FIRE buttons), the label in display caps; pressed = the ring's light fills in. No per-button hues.)
        local fire = b.Id == "Fire" or b.Id == "FireL"
        local REST = Color3.fromRGB(16, 18, 22)
        f.BackgroundColor3 = REST
        f.BackgroundTransparency = 0.4
        f.Parent = holder
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = f
        local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(236, 232, 225); st.Thickness = 1.5; st.Transparency = fire and 0.25 or 0.6
        st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = f
        local lbl = Instance.new("TextLabel")
        lbl.Name = "Label"
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.Font = Enum.Font.GothamBlack
        lbl:SetAttribute("TypeRole", "Label")
        lbl.Text = b.Label
        lbl.TextColor3 = Color3.fromRGB(236, 232, 225)
        lbl.TextStrokeTransparency = 0.8
        lbl.Parent = f
        buttons[b.Id] = f
        if b.DuelOnly then -- (only in a duel)
            local function Show() f.Visible = lp:GetAttribute("PvpDuel") ~= nil end
            Show()
            lp:GetAttributeChangedSignal("PvpDuel"):Connect(Show)
        end
        local held = nil
        f.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Touch or held then return end
            held = input
            f.BackgroundColor3 = Color3.fromRGB(236, 232, 225); f.BackgroundTransparency = 0.7 -- (pressed: the ring's light fills in)
            if b.LookDrag then lookTouches[input] = true end -- (drag the fire button to aim while shooting)
            Press(b.Id, true)
        end)
        local function Release(input)
            if input ~= held then return end
            held = nil
            lookTouches[input] = nil
            f.BackgroundColor3 = REST; f.BackgroundTransparency = 0.4
            if b.Hold then Press(b.Id, false) end
        end
        f.InputEnded:Connect(Release)
        UserInputService.TouchEnded:Connect(function(input) Release(input) end) -- (finger slid off the button)
    end
    Layout()
    if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Layout) end
    GameSettings.OnChanged("TouchButtonSize", Layout)
    lp:GetAttributeChangedSignal("DevPhone"):Connect(function() task.defer(Layout) end)
    -- the side dock (the left FIRE goes right of it on phones): found once the HUD exists, re-laid out when it changes
    task.spawn(function()
        for _ = 1, 60 do
            local hud = lp.PlayerGui:FindFirstChild("AimRngMasterHUD")
            local dock = hud and hud:FindFirstChild("SideDock")
            if dock then
                PC._dock = dock
                dock:GetPropertyChangedSignal("AbsoluteSize"):Connect(Layout)
                dock:GetPropertyChangedSignal("Visible"):Connect(Layout)
                Layout()
                return
            end
            task.wait(1)
        end
    end)

    -- AIM ASSIST (touch only, PvE only; AimRngShared/AimAssist)
    if h.Assist then
        local okA, mod = pcall(function() return require(Shared:WaitForChild("AimAssist")) end)
        if okA and mod then
            PC._assist = mod
            mod.Start(h.Assist)
        end
    end

    -- drag anywhere on the right part of the screen (not on a button / menu) to look
    -- (2026-10-13, owner's phone test: "you cant shoot with the tutorial menu open") a touch the engine marks as processed
    -- still starts a look drag when what's under the finger is only text / panels (a tutorial card, a feed row's label,
    -- a HUD frame): only a real control under it -- a button, a text box, an Active frame (Roblox's thumbstick / jump) --
    -- keeps the touch for itself. (Checked once per touch start, never per frame.)
    local function OverControl(pos: Vector3): boolean
        local ok, list = pcall(function() return lp.PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y) end)
        if not ok then return true end
        for _, o in ipairs(list) do
            if o.Visible and (o:IsA("GuiButton") or o:IsA("TextBox") or o.Active) then return true end
        end
        return false
    end
    UserInputService.TouchStarted:Connect(function(input, gp)
        local cam = workspace.CurrentCamera
        local w = cam and cam.ViewportSize.X or 1280
        if input.Position.X < w * 0.38 then return end -- (left side = Roblox's thumbstick)
        if gp and OverControl(input.Position) then return end
        lookTouches[input] = true
    end)
    local function LookBy(d: Vector2)
        local mode = h.Mode()
        if mode == "Play" then
            if PC._assist then d *= PC._assist.LookScale(); PC._assist.Looked() end -- (aim assist friction)
            h.Look(d)
        elseif mode == "Hub" then
            h.Orbit(d)
        end
    end
    UserInputService.TouchMoved:Connect(function(input)
        if not lookTouches[input] then return end
        LookBy(Vector2.new(input.Delta.X, input.Delta.Y) * 0.45 * ((tonumber(GameSettings.Get("TouchSensitivity")) or 1)))
    end)
    -- Studio test hook (the tooling can't touch the screen): Player attr DevTouchPress = "<Id>:1" / "<Id>:0" presses /
    -- releases a touch button through the same path a finger takes (Fire, FireL, Aim, Reload, Dash, Slide, Swap, Melee,
    -- Inspect); "look:dx,dy[,frames]" drags the look area (friction included). DevTouchResult = mode + whether it showed.
    if RunService:IsStudio() then
        lp:GetAttributeChangedSignal("DevTouchPress"):Connect(function()
            local v = lp:GetAttribute("DevTouchPress")
            if type(v) ~= "string" or v == "" then return end
            lp:SetAttribute("DevTouchPress", nil)
            local id, rest = v:match("^(%w+):?(.*)$")
            if id == "look" then
                local dx, dy, n = rest:match("^([%-%d%.]+),([%-%d%.]+),?(%d*)$")
                local frames = tonumber(n) or 1
                task.spawn(function()
                    for _ = 1, frames do
                        LookBy(Vector2.new(tonumber(dx) or 0, tonumber(dy) or 0) * 0.45 * ((tonumber(GameSettings.Get("TouchSensitivity")) or 1)))
                        RunService.RenderStepped:Wait()
                    end
                end)
            elseif id and buttons[id] then
                local f = buttons[id]
                lp:SetAttribute("DevTouchResult", string.format("%s mode=%s shown=%s", id, tostring(h.Mode()), tostring(holder.Visible and f.Visible)))
                if holder.Visible and f.Visible then Press(id, rest ~= "0") end
            end
        end)
    end
    UserInputService.TouchEnded:Connect(function(input) lookTouches[input] = nil end)

    -- show the combat buttons only while playing (not in menus, the hub hall, or dead)
    local lastMode = nil
    RunService.Heartbeat:Connect(function()
        local mode = h.Mode()
        if mode == lastMode then return end
        lastMode = mode
        holder.Visible = (mode == "Play" or mode == "Hub")
        -- the hub: only the movement buttons (no weapons there)
        for id, f in pairs(buttons) do f.Visible = ((mode == "Play") or id == "Dash" or id == "Slide") and (id ~= "Ability" or lp:GetAttribute("PvpDuel") ~= nil) end -- (the duel SKILL button only in a duel)
        if mode ~= "Play" then
            if next(fireDown) then fireDown = {}; h.Fire(false) end
            h.Aim(false)
            h.Move("Slide", false)
        end
    end)
end

-- ==================== gamepad ====================
-- (QOL L3 2026-10-28: ButtonR1 = every ProximityPrompt (pick up / use; the client's prompt Adopt), not listed here.
-- MovementController owns A / B / L1 / L3.)
local PAD_DOWN = {
    [Enum.KeyCode.ButtonR2] = "Fire", [Enum.KeyCode.ButtonL2] = "Aim", [Enum.KeyCode.ButtonX] = "Reload",
    [Enum.KeyCode.ButtonY] = "Swap", [Enum.KeyCode.ButtonR3] = "Melee", [Enum.KeyCode.DPadUp] = "Inspect",
    [Enum.KeyCode.ButtonStart] = "Menu", [Enum.KeyCode.ButtonB] = "Back", [Enum.KeyCode.DPadDown] = "Ability",
    -- (taken elsewhere: ButtonL1 / L3 Dash + ButtonB Slide = MovementController PAD; ButtonR1 = loot / prompts (QOL L3);
    -- DPadRight = the minimap cycle (QOL M1, AimRngShared/MiniMap); DPadLeft = pick up all nearby
    -- (QOL L2, the client); ButtonSelect = toggle affix ranges on an item card (QOL2 I1, the client))
}
local function StartGamepad(h)
    local stick = Vector2.zero
    UserInputService.InputChanged:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Thumbstick2 then stick = Vector2.new(input.Position.X, input.Position.Y) end
    end)
    UserInputService.InputBegan:Connect(function(input)
        local a = PAD_DOWN[input.KeyCode]
        if not a then return end
        if GameSettings.IsTyping() then return end
        local mode = h.Mode()
        if a == "Menu" then h.Menu() return end
        if a == "Back" then if mode == "Menu" then h.Back() end return end
        if mode ~= "Play" then return end
        if a == "Fire" then h.Fire(true)
        elseif a == "Aim" then h.Aim(true)
        elseif a == "Reload" then h.Reload()
        elseif a == "Swap" then h.Swap()
        elseif a == "Melee" then h.Melee()
        elseif a == "Inspect" then h.Inspect()
        elseif a == "Ability" then if PC.AbilityFn then PC.AbilityFn() end end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.ButtonR2 then h.Fire(false)
        elseif input.KeyCode == Enum.KeyCode.ButtonL2 then h.Aim(false)
        elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then stick = Vector2.zero end
    end)
    -- right stick: a deadzone + response curve, ~260 deg/s at full tilt (x the stick sensitivity setting)
    RunService.RenderStepped:Connect(function(dt)
        local m = stick.Magnitude
        if m < 0.14 then return end
        local mode = h.Mode()
        if mode ~= "Play" and mode ~= "Hub" then return end
        local k = ((m - 0.14) / 0.86) ^ 1.7 / m
        local rate = 520 * ((tonumber(GameSettings.Get("StickSensitivity")) or 1))
        local d = Vector2.new(stick.X, -stick.Y) * k * rate * math.min(dt, 0.1)
        if mode == "Play" then h.Look(d) else h.Orbit(d) end
    end)
end

-- relabel a touch button (the client: AIM -> DASH while the melee is out)
function PC.SetLabel(id: string, text: string)
    local f = PC._buttons and PC._buttons[id]
    local lbl = f and f:FindFirstChild("Label")
    if lbl then lbl.Text = text end
end

function PC.Start(h)
    if started then return end
    started = true
    -- both are wired regardless of the current device: a phone can pair a controller, a PC can have a touch screen
    if UserInputService.TouchEnabled then StartTouch(h)
    elseif RunService:IsStudio() then
        -- Studio test hook: Player attribute DevTouch = true shows the touch layout on a PC
        local lp = Players.LocalPlayer
        local function Check() if lp:GetAttribute("DevTouch") and not PC._touch then PC._touch = true; StartTouch(h) end end
        lp:GetAttributeChangedSignal("DevTouch"):Connect(Check)
        Check()
    end
    StartGamepad(h)
end

return PC
