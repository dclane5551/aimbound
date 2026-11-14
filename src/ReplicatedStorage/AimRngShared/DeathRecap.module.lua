--!nocheck
-- DEATH RECAP (QOL PASS 2 R1, 2026-10-28; server side = AimRngServer/DeathLog via CombatServer.DamagePlayer's src tag).
-- The server sets the Player attribute "DeathRecap" (JSON { K = killer, H = { { S, D, E, A }, ... newest first }, L = lives left,
-- N = serial }) on every run death. This module shows it:
--   * a life lost (L > 0): a small card bottom-left above the HUD stack ("KILLED BY ..." + the last hits), 7 s, then gone;
--   * out of lives (L = 0): a panel on the OUT OF LIVES screen (bottom centre; top on phones -- the buttons fill the middle);
--   * the RUN SUMMARY: DeathRecap.SummaryRow(body, me, order) = a full-width DEATH row (me.Killer / me.KillHits from RunStats).
-- Nothing over the crosshair, no flashes, no per-frame work (one attribute signal + one delay).
--
--   DeathRecap.Init({ Hud = hudGui, Overlay = hudGui.OutOfLives, Stack = UI.HudStack })
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local DamageTypes = require(script.Parent:WaitForChild("DamageTypes"))

local DeathRecap = {}
local C = UIStyle.Colors
local LocalPlayer = Players.LocalPlayer
local KILL_COL = Color3.fromRGB(255, 120, 120) -- (UI CLEAN R-C: no longer drawn -- the killer reads in Text)
local CARD_SECONDS = 7
local W = 380

local card, outPanel = nil, nil
local hideToken = 0

local function TypeColor(e: string?): Color3
    return (e and (DamageTypes.COLOR[e] or DamageTypes.AILMENT_COLOR[e])) or C.Sub
end
local function TypeLabel(e: string?): string
    return string.upper((e and (DamageTypes.LABEL[e] or e)) or "")
end
function DeathRecap.Decode(js: any): any
    if type(js) ~= "string" or js == "" then return nil end
    local ok, r = pcall(HttpService.JSONDecode, HttpService, js)
    return (ok and type(r) == "table") and r or nil
end
-- one hit as a line: "-142   HEAT   RARE SNIPER   0.4 s before"
function DeathRecap.HitText(h: any): string
    local a = tonumber(h.A) or 0
    return string.format("-%s   %s   %s   %s", tostring(math.round(tonumber(h.D) or 0)), TypeLabel(h.E), string.upper(tostring(h.S or "?")),
        (a < 0.15) and "killing blow" or string.format("%.1f s before", a))
end

-- (UI CLEAN R-C: text by role -- Label = small caps head (Sub), Title = the killer (display caps Text), Body lines)
local RunHud = require(script.Parent:WaitForChild("RunHud"))
local function Label(parent, props, role)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.TextColor3 = C.Text; l.Font = UIStyle.Font; l.TextSize = 15
    l.TextXAlignment = Enum.TextXAlignment.Left; l.TextTruncate = Enum.TextTruncate.AtEnd
    for k, v in pairs(props) do l[k] = v end
    l.Parent = parent
    if role then
        local keep = props.TextColor3 ~= nil
        RunHud.Role(l, role, { Keep = keep })
        if props.TextSize then l.TextSize = props.TextSize end
    end
    return l
end
-- the card body (UI CLEAN R-C: the run HUD plate -- flat, no facet, no ink edge, no red side block) with a small caps head,
-- the killer in display caps and up to 5 hit lines
local function Build(parent: Instance, name: string): any
    local f = Instance.new("Frame")
    f.Name = name; f.Visible = false
    f.Size = UDim2.fromOffset(W, 60)
    RunHud.Plate(f, RunHud.PLATE_T)
    local head = Label(f, { Name = "Head", Text = "KILLED BY", TextSize = 13, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 16) }, "Label")
    head.FontFace = UIStyle.RoleFace("Label")
    local killer = Label(f, { Name = "Killer", Text = "", Position = UDim2.fromOffset(14, 24), Size = UDim2.new(1, -28, 0, 24) }, "Title")
    local lines = {}
    for i = 1, 5 do
        lines[i] = Label(f, { Name = "Hit" .. i, Text = "", TextSize = 13, TextColor3 = C.Sub, Position = UDim2.fromOffset(14, 50 + (i - 1) * 18), Size = UDim2.new(1, -28, 0, 16), Visible = false }, "Body")
    end
    f.Parent = parent
    return { Frame = f, Head = head, Killer = killer, Lines = lines }
end
local function Fill(c: any, r: any, headText: string)
    c.Head.Text = headText
    c.Killer.Text = string.upper(tostring(r.K or "Unknown"))
    local hits = type(r.H) == "table" and r.H or {}
    local n = 0
    for i = 1, 5 do
        local h = hits[i]
        local l = c.Lines[i]
        l.Visible = h ~= nil
        if h then
            n = i
            l.Text = DeathRecap.HitText(h)
            l.TextColor3 = ((i == 1) and C.Text or C.Sub):Lerp(TypeColor(h.E), 0.25) -- (the newest hit brightest, a hint of its type's colour)
        end
    end
    c.Frame.Size = UDim2.fromOffset(W, 54 + n * 18 + (n > 0 and 8 or 0))
    return n
end

function DeathRecap.Show(r: any)
    if type(r) ~= "table" then return end
    if (tonumber(r.L) or 0) > 0 then
        if not card then return end
        local left = tonumber(r.L) or 0
        Fill(card, r, string.format("LIFE LOST  •  %d %s LEFT  •  KILLED BY", left, left == 1 and "LIFE" or "LIVES"))
        card.Frame.Visible = true
        hideToken += 1
        local tok = hideToken
        task.delay(CARD_SECONDS, function() if tok == hideToken and card then card.Frame.Visible = false end end)
    else
        if card then card.Frame.Visible = false end
        if not outPanel then return end
        Fill(outPanel, r, "KILLED BY")
        local phone = UIStyle.IsPhone()
        outPanel.Frame.AnchorPoint = phone and Vector2.new(0.5, 0) or Vector2.new(0.5, 1)
        outPanel.Frame.Position = phone and UDim2.new(0.5, 0, 0, UIStyle.BelowTopBarY(outPanel.Frame, 8)) or UDim2.new(0.5, 0, 1, -18)
        outPanel.Frame.Visible = true
    end
end

function DeathRecap.Init(ctx: any)
    local hs = ctx.Stack or { X = 16, TopY = -260 }
    card = Build(ctx.Hud, "DeathRecapCard")
    card.Frame.AnchorPoint = Vector2.new(0, 1)
    card.Frame.Position = UDim2.new(0, hs.X or 16, 1, (hs.TopY or -260) - 62) -- (above the status / build chips over the HUD stack)
    card.Frame.ZIndex = 5
    if ctx.Overlay then
        outPanel = Build(ctx.Overlay, "DeathRecapPanel")
        outPanel.Frame.ZIndex = 41
        for _, d in ipairs(outPanel.Frame:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex = 42 end end
    end
    local function Read()
        local r = DeathRecap.Decode(LocalPlayer:GetAttribute("DeathRecap"))
        if r then DeathRecap.Show(r) end
    end
    LocalPlayer:GetAttributeChangedSignal("DeathRecap"):Connect(Read)
    -- a fresh run (lives set again) or the hub: the card goes
    LocalPlayer:GetAttributeChangedSignal("Lives"):Connect(function()
        if LocalPlayer:GetAttribute("Lives") == nil and card then card.Frame.Visible = false end
    end)
    return DeathRecap
end

-- RUN SUMMARY: a full-width DEATH row (the run's last death) -- nil when the run had none
function DeathRecap.SummaryRow(body: Instance, me: any, order: number): Instance?
    if type(me) ~= "table" or type(me.Killer) ~= "string" then return nil end
    local row = Instance.new("Frame")
    row.Name = "DeathRecap"; row.LayoutOrder = order; row.BackgroundColor3 = C.Text; row.BackgroundTransparency = 0.955; row.BorderSizePixel = 0
    row.Size = UDim2.new(1, -8, 0, 58); row:SetAttribute("Skinned", true); row:SetAttribute("NoSkin", true); row.Parent = body
    -- (UI CLEAN R-C: one summary card -- the target's raised surface, no facet / stroke / red side block)
    local hd = Label(row, { Text = ((tonumber(me.Deaths) or 0) > 1) and "LAST DEATH  •  KILLED BY" or "DEATH  •  KILLED BY", TextSize = 13, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 16) }, "Label")
    hd.FontFace = UIStyle.RoleFace("Label")
    Label(row, { Text = string.upper(me.Killer), Position = UDim2.fromOffset(14, 26), Size = UDim2.new(0.45, -14, 0, 26) }, "Title")
    local parts = {}
    for i, h in ipairs(type(me.KillHits) == "table" and me.KillHits or {}) do
        if i > 3 then break end
        table.insert(parts, string.format("-%s %s", tostring(math.round(tonumber(h.D) or 0)), string.upper(tostring(h.S or "?"))))
    end
    Label(row, { Text = (#parts > 0) and ("Last hits: " .. table.concat(parts, "  •  ")) or "", TextSize = 13, TextColor3 = C.Sub,
        Position = UDim2.new(0.45, 0, 0, 26), Size = UDim2.new(0.55, -14, 0, 26), TextXAlignment = Enum.TextXAlignment.Right }, "Body")
    return row
end

return DeathRecap
