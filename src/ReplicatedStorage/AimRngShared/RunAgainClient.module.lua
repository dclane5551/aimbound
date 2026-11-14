--!nocheck
-- RUN AGAIN (QOL F1, 2026-10-28; server side = AimRngServer/RunAgain): a RUN AGAIN button on the RUN SUMMARY window and on
-- the DUNGEON CLEARED banner. The server remembers how the last run was started and answers what the button can do ("Info":
-- { Show, Ok, Label, Sub, Why, Wait }); "Go" starts it through the real start path (a solo run: the client then calls the
-- same StartDungeonRaid the Dungeons window does; a map: the server consumes a map of the same tier; a party: the leader's
-- START with its ready check). Party members see WAITING FOR LEADER.
--
--   local RA = RunAgainClient.Init({ StartSolo = fn(biome, key, skill), Toast = fn(text), Click = fn(),
--       InRun = fn() -> bool, LeaveGate = fn() -> bool (false = loot still on the ground: warned, try again),
--       LeaveRun = fn() (client side of RETURN TO HUB: banners off, back to the hub spawn), CloseAll = fn() })
--   RA.AttachSummary(panel, body)          -- a footer row in the RUN SUMMARY window; RA.RefreshSummary()
--   RA.AttachBanner(banner, hubBtn, keepBtn) -- a middle button on the victory banner; RA.RefreshBanner()
--   RA.Busy() -> a RUN AGAIN is starting (the summary window doesn't pop open over the new run)
local Players = game:GetService("Players")
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))

local RunAgainClient = {}
local C = UIStyle.Colors
local LocalPlayer = Players.LocalPlayer
local GO_COL = Color3.fromRGB(70, 150, 240)

local hooks: any = {}
local busyUntil = 0
local summary: any = nil -- { Panel, Body, Row, Btn, Info }
local banner: any = nil -- { Frame, Hub, Keep, Btn }

function RunAgainClient.Busy(): boolean
    return os.clock() < busyUntil
end

local function Fetch(): any
    local ok, info = pcall(function() return Remotes.GetFunction("RunAgain"):InvokeServer("Info") end)
    return (ok and type(info) == "table") and info or { Show = false }
end

local function Go()
    if RunAgainClient.Busy() then return end
    if hooks.Click then hooks.Click() end
    local inRun = hooks.InRun and hooks.InRun()
    if inRun and hooks.LeaveGate and not hooks.LeaveGate() then return end -- (QOL L1: loot still on the ground -> warned once)
    busyUntil = os.clock() + 12
    if summary then summary.Btn.SetText("STARTING..."); summary.Btn.SetEnabled(false) end
    if banner then banner.Btn.Text = "STARTING..." end
    if inRun and hooks.LeaveRun then hooks.LeaveRun() end
    task.spawn(function()
        local ok, res = false, nil
        local okCall, err = pcall(function() ok, res = Remotes.GetFunction("RunAgain"):InvokeServer("Go") end)
        if not okCall then ok, res = false, "Couldn't start: " .. tostring(err) end
        if ok and type(res) == "table" and type(res.Solo) == "table" then
            if hooks.CloseAll then hooks.CloseAll() end
            hooks.StartSolo(res.Solo.Biome, res.Solo.Key, res.Solo.BotSkill) -- (StartDungeonRaid checks it all again)
        elseif ok and type(res) == "table" and res.ReadyCheck then
            busyUntil = 0
            if hooks.Toast then hooks.Toast("READY CHECK sent to your party: the run starts when everyone is ready") end
        elseif ok then
            if hooks.CloseAll then hooks.CloseAll() end -- (a map / a party run: the server moves you)
        else
            busyUntil = 0
            if hooks.Toast then hooks.Toast(tostring(res or "Couldn't start the run.")) end
        end
        task.delay(ok and 4 or 0, function()
            if summary and summary.Panel.Visible then RunAgainClient.RefreshSummary() end
        end)
        if not ok then RunAgainClient.RefreshSummary() end
    end)
end

RunAgainClient.Go = Go -- (Studio: client DevAct "ui:RunAgainGo" = a click on RUN AGAIN)

---------------------------------------------------------------- the RUN SUMMARY footer
local FOOT_H = 56
function RunAgainClient.AttachSummary(panel: Frame, body: GuiObject)
    local row = Instance.new("Frame")
    row.Name = "RunAgainRow"; row.BackgroundTransparency = 1; row.Visible = false
    row.AnchorPoint = Vector2.new(0, 1); row.Position = UDim2.new(0, 16, 1, -12); row.Size = UDim2.new(1, -32, 0, FOOT_H - 8)
    row.Parent = panel
    local sub = UIStyle.Text({ Name = "Sub", Font = UIStyle.BodyFont, TextSize = 14, TextColor3 = C.Sub, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -290, 1, 0), Parent = row })
    local btn = UIStyle.Button(row, "RUN AGAIN", C.Accent, UDim2.fromOffset(270, 46), UDim2.new(1, -270, 0, 0), "RunAgain") -- (UI CLEAN R-C: the primary)
    btn.Button.MouseButton1Click:Connect(function() if btn.Button.Active then Go() end end)
    summary = { Panel = panel, Body = body, Row = row, Btn = btn, Sub = sub, Body0 = body.Size }
    -- a party's room changes (everyone back -> Lobby, a new leader): the button follows
    Remotes.GetEvent("PartyUpdate").OnClientEvent:Connect(function()
        if panel.Visible and row.Visible then task.delay(0.3, RunAgainClient.RefreshSummary) end
    end)
end

-- the footer takes FOOT_H under the list: the window grows by it once (Render() re-sizes the window from scratch -- then
-- the height no longer matches PanelH and the footer is added again)
local function Fitted(s: any): boolean
    return s.Added == true and s.Panel.Size.Y.Offset == s.PanelH
end
local function ShowSummary(info: any)
    local s = summary
    if not s then return end
    local want = info.Show == true
    local fitted = Fitted(s)
    if want and not fitted then
        s.Panel.Size = UDim2.new(s.Panel.Size.X.Scale, s.Panel.Size.X.Offset, s.Panel.Size.Y.Scale, s.Panel.Size.Y.Offset + FOOT_H)
        s.PanelH, s.Added = s.Panel.Size.Y.Offset, true
    elseif not want and fitted then
        s.Panel.Size = UDim2.new(s.Panel.Size.X.Scale, s.Panel.Size.X.Offset, s.Panel.Size.Y.Scale, s.Panel.Size.Y.Offset - FOOT_H)
        s.Added = false
    end
    local b0 = s.Body0
    s.Body.Size = want and UDim2.new(b0.X.Scale, b0.X.Offset, b0.Y.Scale, b0.Y.Offset - FOOT_H) or b0
    s.Row.Visible = want
    if not want then return end
    s.Btn.SetText(RunAgainClient.Busy() and "STARTING..." or (info.Label or "RUN AGAIN"))
    s.Btn.SetEnabled(info.Ok == true and not RunAgainClient.Busy())
    s.Sub.Text = (info.Sub or "") .. ((not info.Ok and info.Why) and ("  •  " .. info.Why) or "")
    s.Sub.TextColor3 = (not info.Ok and not info.Wait) and C.Warn or C.Sub
end

-- after Render() (it re-sizes the window) or when the party changes
function RunAgainClient.RefreshSummary()
    local s = summary
    if not s then return end
    if not Fitted(s) then s.Row.Visible = false; s.Body.Size = s.Body0; s.Added = false end
    task.spawn(function() ShowSummary(Fetch()) end)
end

---------------------------------------------------------------- the DUNGEON CLEARED banner
function RunAgainClient.AttachBanner(frame: Frame, hubBtn: GuiButton, keepBtn: GuiButton)
    local b = Instance.new("TextButton")
    b.Name = "RunAgain"; b.Visible = false
    b.Size = hubBtn.Size; b.Text = "RUN AGAIN"
    b.Parent = frame
    require(script.Parent:WaitForChild("RunHud")).Btn(b, "Secondary") -- (UI CLEAN R-C: the banner's buttons in the UIStyle roles)
    b.MouseButton1Click:Connect(function() if b.Active then Go() end end)
    banner = { Frame = frame, Hub = hubBtn, Keep = keepBtn, Btn = b, W0 = frame.Size, HubPos = hubBtn.Position, KeepPos = keepBtn.Position, BtnSize = hubBtn.Size }
end

local function Layout3(on: boolean)
    local s = banner
    if on then -- KEEP LOOTING | RUN AGAIN | RETURN TO HUB, 184 wide each in a 620 banner
        s.Frame.Size = UDim2.new(s.W0.X.Scale, 620, s.W0.Y.Scale, s.W0.Y.Offset)
        local sz = UDim2.fromOffset(184, s.BtnSize.Y.Offset)
        s.Keep.Size, s.Btn.Size, s.Hub.Size = sz, sz, sz
        s.Keep.Position = UDim2.new(0.5, -288, 1, -55)
        s.Btn.Position = UDim2.new(0.5, -92, 1, -55)
        s.Hub.Position = UDim2.new(0.5, 104, 1, -55)
        s.Frame:SetAttribute("PhoneBoostW", 620)
    else
        s.Frame.Size = s.W0
        s.Keep.Size, s.Hub.Size = s.BtnSize, s.BtnSize
        s.Keep.Position, s.Hub.Position = s.KeepPos, s.HubPos
        s.Frame:SetAttribute("PhoneBoostW", s.W0.X.Offset)
    end
    s.Btn.Visible = on
end

function RunAgainClient.RefreshBanner()
    if not banner then return end
    Layout3(false)
    task.spawn(function()
        local info = Fetch()
        if not banner.Frame.Visible then return end
        Layout3(info.Show == true)
        local b = banner.Btn
        b.Text = info.Label or "RUN AGAIN"
        local on = info.Ok == true
        require(script.Parent:WaitForChild("RunHud")).BtnState(b, "Secondary", on) -- (UI CLEAN R-C: off = Muted words, no grey slab)
    end)
end

function RunAgainClient.Init(h: any)
    hooks = h or {}
    return RunAgainClient
end

return RunAgainClient
