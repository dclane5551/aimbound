--!nocheck
-- GOAL TRACKER (QOL PASS 2 R4, 2026-10-28; audit 13: "you can't see your bounty / contract progress while you play").
-- A small panel top-left (right of the MENU column, under the floor-modifier line, far from the crosshair) IN RUNS with up to 3 pinned goals: today's daily
-- contracts (state.Contracts) and this week's Job Board bounties (state.Weekly), each with its live progress. The hub keeps its
-- own top-right contracts box, so the panel shows only in a run.
-- Pins: the Challenges window's WEEKLY tab (TRACK buttons on the Job Board + the daily contracts list there). Default (nothing
-- pinned yet this session) = the first 3 unfinished (contracts first). Pins are per session (not saved).
-- Live numbers: server AimRngServer/GoalTrack sets the Player attribute "GoalProg" ("<day>:<p>,<p>|<week>:<p>,...") at most once
-- a second when progress changed (kills / floor clears, never per hit); the lists themselves come with SyncPlayerState.
-- Setting Interface "Goal Tracker" (GameSettings GoalTracker) On / Off. Event-driven; a 2 Hz visibility check runs only in a run.
--
--   GoalTracker.Init({ Hud = hudGui, GetState = fn -> clientState, MenuOpen = fn -> bool, Y = number? })
--   GoalTracker.Goals(state) -> { { Key, Kind "C" | "W", Text, P, T, Done } }   GoalTracker.Shown(state) -> up to 3 of them
--   GoalTracker.IsPinned(key, state) / GoalTracker.Toggle(key, state) -> ok, msg   GoalTracker.Refresh()
local Players = game:GetService("Players")
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local Contracts = require(script.Parent:WaitForChild("Contracts"))
local Weekly = require(script.Parent:WaitForChild("Weekly"))
local GameSettings = require(script.Parent:WaitForChild("GameSettings"))

local GoalTracker = {}
GoalTracker.MAX = 3
local C = UIStyle.Colors
local LP = Players.LocalPlayer
local W, ROW_H = 260, 34
local GOLD = C.Text -- (UI CLEAN P5: one accent; weekly jobs say JOB in words)

local pins: { [string]: boolean }? = nil -- nil = the default pick
local hooks: any = {}
local ui: any = nil
local changed = Instance.new("BindableEvent")
GoalTracker.Changed = changed.Event

-- live progress from the attribute, by list: { C = { day, {p...} }, W = { week, {p...} } }
local function Live(): any
    local s = LP and LP:GetAttribute("GoalProg")
    if type(s) ~= "string" then return nil end
    local cd, cl, wk, wl = string.match(s, "^(%d+):([%d,]*)|(%d+):([%d,]*)$")
    if not cd then return nil end
    local function Nums(t) local o = {} for n in string.gmatch(t, "%d+") do table.insert(o, tonumber(n)) end return o end
    return { C = { tonumber(cd), Nums(cl) }, W = { tonumber(wk), Nums(wl) } }
end

function GoalTracker.Goals(state: any): { any }
    local out = {}
    if type(state) ~= "table" then return out end
    local live = Live()
    local c = state.Contracts
    if type(c) == "table" and c.Day == Contracts.Today() and type(c.List) == "table" then
        local lp = live and live.C[1] == c.Day and live.C[2] or nil
        for i, it in ipairs(c.List) do
            if type(it) == "table" then
                local t = tonumber(it.Target) or 1
                local p = math.max(tonumber(it.Progress) or 0, lp and lp[i] or 0)
                table.insert(out, { Key = "C:" .. tostring(it.Id), Kind = "C", Text = Contracts.Text(it), P = math.min(p, t), T = t, Done = it.Done == true or p >= t })
            end
        end
    end
    local w = state.Weekly
    if type(w) == "table" and w.Week == Weekly.Week() and type(w.Bounties) == "table" then
        local lp = live and live.W[1] == w.Week and live.W[2] or nil
        for i, it in ipairs(w.Bounties) do
            if type(it) == "table" then
                local t = tonumber(it.Target) or 1
                local p = math.max(tonumber(it.Progress) or 0, lp and lp[i] or 0)
                table.insert(out, { Key = "W:" .. i .. ":" .. tostring(it.Id), Kind = "W", Text = Weekly.Text(it), P = math.min(p, t), T = t, Done = it.Done == true or p >= t })
            end
        end
    end
    return out
end

function GoalTracker.Shown(state: any): { any }
    local all = GoalTracker.Goals(state)
    local out = {}
    if pins then
        for _, g in ipairs(all) do if pins[g.Key] and #out < GoalTracker.MAX then table.insert(out, g) end end
    else
        for _, g in ipairs(all) do if not g.Done and #out < GoalTracker.MAX then table.insert(out, g) end end
    end
    return out
end

function GoalTracker.IsPinned(key: string, state: any): boolean
    for _, g in ipairs(GoalTracker.Shown(state)) do if g.Key == key then return true end end
    return false
end

-- pin / unpin one goal (the first change copies the default pick into real pins)
function GoalTracker.Toggle(key: string, state: any): (boolean, string?)
    if not pins then
        local first = {}
        for _, g in ipairs(GoalTracker.Shown(state)) do first[g.Key] = true end -- (the default pick, read before pins exist)
        pins = first
    end
    if pins[key] then
        pins[key] = nil
    else
        local n = 0
        for _, g in ipairs(GoalTracker.Goals(state)) do if pins[g.Key] then n += 1 end end
        if n >= GoalTracker.MAX then return false, "The tracker holds 3 goals: untrack one first." end
        pins[key] = true
    end
    changed:Fire()
    GoalTracker.Refresh()
    return true
end

local function InRun(): boolean
    return LP:GetAttribute("Lives") ~= nil and not LP:GetAttribute("Downed") and not LP:GetAttribute("Spectating")
end
local function Wanted(): boolean
    if GameSettings.Get("GoalTracker") == false then return false end
    if not InRun() then return false end
    if hooks.MenuOpen and hooks.MenuOpen() then return false end
    return true
end

-- (UI CLEAN P5: the HUD's flat see-through plate (Bg0 0.45, no edge, no facet), a small caps head, rows without boxes: the goal
-- in body text, its progress right-aligned in the display face, a 2 px line under it)
local function Build(parent: Instance)
    local f = Instance.new("Frame")
    f.Name = "GoalTracker"; f.BackgroundColor3 = C.Bg0; f.BackgroundTransparency = 0.45; f.BorderSizePixel = 0; f.Visible = false
    f.Size = UDim2.fromOffset(W, 24); f:SetAttribute("NoSkin", true); f:SetAttribute("Skinned", true)
    local head = Instance.new("TextLabel")
    head.Name = "Head"; head.BackgroundTransparency = 1; head.Font = Enum.Font.GothamBlack; head.TextSize = 13
    head.TextXAlignment = Enum.TextXAlignment.Left; head.Position = UDim2.fromOffset(10, 6); head.Size = UDim2.new(1, -20, 0, 16)
    head.Text = "TRACKED GOALS"; head.Parent = f
    UIStyle.TextRole(head, "SectionHead"); head.TextSize = 13 -- (HUD scale: the HUD's small caps size)
    local rows = {}
    for i = 1, GoalTracker.MAX do
        local r = Instance.new("Frame")
        r.Name = "Goal" .. i; r.BackgroundTransparency = 1; r.Position = UDim2.fromOffset(10, 26 + (i - 1) * ROW_H); r.Size = UDim2.new(1, -20, 0, ROW_H - 6)
        r.Parent = f
        local txt = Instance.new("TextLabel")
        txt.Name = "Text"; txt.BackgroundTransparency = 1; txt.Font = UIStyle.BodyFont; txt.TextColor3 = C.Text
        txt.TextXAlignment = Enum.TextXAlignment.Left; txt.TextTruncate = Enum.TextTruncate.AtEnd; txt.Size = UDim2.new(1, -60, 0, 18); txt.Parent = r
        UIStyle.TextRole(txt, "Body"); txt.TextSize = 13
        local num = Instance.new("TextLabel")
        num.Name = "Num"; num.BackgroundTransparency = 1; num.Font = UIStyle.Font
        num.TextXAlignment = Enum.TextXAlignment.Right; num.AnchorPoint = Vector2.new(1, 0); num.Position = UDim2.new(1, 0, 0, 0); num.Size = UDim2.fromOffset(58, 18); num.Parent = r
        UIStyle.TextRole(num, "Value")
        local bg = Instance.new("Frame")
        bg.BackgroundColor3 = C.Text; bg.BackgroundTransparency = 0.85; bg.BorderSizePixel = 0; bg.Position = UDim2.fromOffset(0, 21); bg.Size = UDim2.new(1, 0, 0, 2); bg.Parent = r
        local fill = Instance.new("Frame")
        fill.Name = "Fill"; fill.BackgroundColor3 = C.Accent; fill.BorderSizePixel = 0; fill.Size = UDim2.new(0, 0, 1, 0); fill.Parent = bg
        rows[i] = { Row = r, Txt = txt, Num = num, Fill = fill }
    end
    f.Parent = parent
    return { Frame = f, Rows = rows }
end

function GoalTracker.Refresh()
    if not ui then return end
    local want = Wanted()
    local shown = want and GoalTracker.Shown(hooks.GetState and hooks.GetState() or nil) or {}
    ui.Frame.Visible = want and #shown > 0
    if not ui.Frame.Visible then return end
    for i, r in ipairs(ui.Rows) do
        local g = shown[i]
        r.Row.Visible = g ~= nil
        if g then
            r.Txt.Text = ((g.Kind == "W") and "JOB  " or "DAILY  ") .. g.Text
            r.Txt.TextColor3 = g.Done and C.Good or C.Text
            r.Num.Text = g.Done and "DONE" or string.format("%d / %d", g.P, g.T)
            r.Num.TextColor3 = g.Done and C.Good or C.Text
            r.Fill.Size = UDim2.new(math.clamp(g.P / math.max(1, g.T), 0, 1), 0, 1, 0)
            r.Fill.BackgroundColor3 = g.Done and C.Good or ((g.Kind == "W") and GOLD or C.Accent)
        end
    end
    ui.Frame.Size = UDim2.fromOffset(W, 26 + #shown * ROW_H - 2)
    GoalTracker.Place()
end
-- (UI CLEAN P5: on the screen grid -- its left edge = the MENU button's (UIStyle.MARGIN), its top = under the MENU button + GAP;
-- hooks.Anchor() -> x, y in the HUD gui's units; without it the old spot)
function GoalTracker.Place()
    if not ui then return end
    local x, y = UIStyle.MARGIN, hooks.Y or 206
    if hooks.Anchor then
        local ok, ax, ay = pcall(hooks.Anchor)
        if ok and ax and ay then x, y = ax, ay end
    end
    local pos = UDim2.fromOffset(x, y)
    if ui.Frame.Position ~= pos then ui.Frame.Position = pos end
end

function GoalTracker.Init(ctx: any)
    hooks = ctx or {}
    ui = Build(hooks.Hud)
    GoalTracker.Place()
    local function Q() task.defer(GoalTracker.Refresh) end
    for _, a in ipairs({ "GoalProg", "Lives", "Downed", "Spectating" }) do LP:GetAttributeChangedSignal(a):Connect(Q) end
    GameSettings.OnChanged("GoalTracker", Q)
    if game:GetService("RunService"):IsStudio() then -- (Studio hook: Player attr DevTrack = a goal key -> Toggle; DevTrackResult = the shown keys)
        LP:GetAttributeChangedSignal("DevTrack"):Connect(function()
            local k = LP:GetAttribute("DevTrack")
            if type(k) ~= "string" or k == "" then return end
            local st = hooks.GetState and hooks.GetState()
            local okT, msg = GoalTracker.Toggle(k, st)
            local keys = {}
            for _, g in ipairs(GoalTracker.Shown(st)) do table.insert(keys, g.Key) end
            LP:SetAttribute("DevTrackResult", tostring(okT) .. " " .. tostring(msg or "") .. " | " .. table.concat(keys, ","))
            LP:SetAttribute("DevTrack", nil)
        end)
    end
    local okR, Remotes = pcall(require, script.Parent:WaitForChild("Remotes"))
    if okR then Remotes.GetEvent("SyncPlayerState").OnClientEvent:Connect(function() task.delay(0.1, GoalTracker.Refresh) end) end
    -- windows opening / closing: a 2 Hz check, only while in a run (nothing runs in the hub)
    task.spawn(function()
        local last = nil
        while true do
            task.wait(0.5)
            if InRun() then
                local w = Wanted()
                if w ~= last then last = w; GoalTracker.Refresh() elseif ui.Frame.Visible then GoalTracker.Place() end -- (the MENU button moves on a resize)
            elseif ui.Frame.Visible then
                last = nil; ui.Frame.Visible = false
            end
        end
    end)
    Q()
    return GoalTracker
end

return GoalTracker
