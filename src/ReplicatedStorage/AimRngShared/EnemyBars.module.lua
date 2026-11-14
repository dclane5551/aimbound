--!nocheck
-- ENEMY HEALTH BARS (client, 2026-10-02). Owner: "the current one is annoying and stacks, incredibly bad to look at.
-- Draining the enemies' health should be super satisfying."
-- Replaces the old per-enemy BillboardGuis (still built by DungeonGenerator / HubGenerator, now always hidden) with
-- one screen-space layer:
--   * a regular enemy's bar shows only while it matters: you hit it in the last few seconds, or your crosshair is on
--     it. Elites keep theirs up while near. Full-health crowds draw nothing -> no wall of stacked bars.
--   * bars that would overlap: the nearer one wins, the farther one fades back.
--   * the drain: the fill snaps down at once, a bright CHIP segment hangs for a beat and then slides down after it,
--     the bar flashes white and kicks on every hit, pulses when low, and bursts away on the kill.
--   * bosses get a big bar at the top of the screen (name + phase, phase ticks, % left, shield state) instead.
--   * the look is your equipped health bar cosmetic (BarStyles; Player attribute "BarStyle").
-- Reads model attributes only (Health / MaxHealth / IsBoss / IsElite / BossTitle / BossColor / BossPhases /
-- DamageTakenMult / Dead), so solo (client-built) and party (server-built) enemies look the same.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local BarStyles = require(script.Parent:WaitForChild("BarStyles"))

local EnemyBars = {}

local LP = Players.LocalPlayer
local SHOW_AFTER_HIT = 3.5   -- seconds a regular bar stays up after the last hit
local CHIP_HOLD = 0.32       -- the chip hangs this long after a hit...
local CHIP_RATE = 1.6        -- ...then drains (plus an ease toward the fill)
local MAX_DIST = 140
local FILL_COL = Color3.fromRGB(235, 60, 60)
local ELITE_COL = { Magic = Color3.fromRGB(110, 150, 255), Rare = Color3.fromRGB(255, 200, 60) }
local SHIELD_COL = Color3.fromRGB(120, 200, 255)

local function New(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end

local function HeadOf(model)
    return model:FindFirstChild("Head") or model:FindFirstChild("Torso") or model.PrimaryPart
end

-- drain state: st = { Shown, Chip, Target, LastHit, Flash, Kick }
local function StepDrain(st, frac, dt, now)
    if frac < st.Target - 1e-4 then
        st.LastHit = now
        -- (0.78, owner: "The enemy health bar flashing when hit is annoying"): no white flash, no kick on hits any more --
        -- the fill drops and the chip drains, that's all
        st.Flash = 0
        st.Kick = 0
    elseif frac > st.Target + 1e-4 then
        st.Chip = math.max(st.Chip, frac) -- healed
    end
    st.Target = frac
    st.Shown += (frac - st.Shown) * math.min(1, dt * 28)
    -- (0.99u: under steady fire every hit restarted the hold, so a boss bar's whole lost part stayed a white chip and
    -- never read as drained -- the chip now drains CHIP_HOLD after the gap opened even while the hits keep coming)
    if st.Chip - st.Shown < 0.002 then st.GapAt = nil elseif not st.GapAt then st.GapAt = now end
    if now - st.LastHit > CHIP_HOLD or (st.GapAt and now - st.GapAt > CHIP_HOLD) then
        local gap = st.Chip - st.Shown
        st.Chip = math.max(st.Shown, st.Chip - (CHIP_RATE * 0.25 + gap * 4) * dt)
    end
    st.Chip = math.max(st.Chip, st.Shown)
    st.Flash = math.max(0, st.Flash - dt * 7)
    st.Kick = math.max(0, st.Kick - dt * 1.4)
end
EnemyBars.StepDrain = StepDrain

local function CurrentStyle()
    local id = LP:GetAttribute("BarStyle")
    return BarStyles.Get(type(id) == "string" and id or nil)
end

-- ===== boss bars (top of screen) =====
local BOSS_W, BOSS_H = 632, 18 -- (UI CLEAN R-C: 632 + the plate's 2 x 14 = the floor banner's 660)
local function MakeBossBar(parent, style, tint)
    -- (UI CLEAN R-C 2026-10-28: the run HUD plate behind name + bar + objective; name in display caps Text, % in the display
    -- face Sub, the objective in display caps Text without the diamond marks; the Clean (Standard) bar is 10 px, flat)
    local okU, UIStyle = pcall(require, script.Parent:WaitForChild("UIStyle"))
    local UC = okU and UIStyle.Colors or {}
    local function Face(t, role) if okU then t.FontFace = UIStyle.RoleFace(role) end; t:SetAttribute("TypeRole", role) end
    local barH = style.Clean and 10 or BOSS_H
    local root = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(BOSS_W, 56), AnchorPoint = Vector2.new(0.5, 0) }, parent)
    local plate = New("Frame", { Name = "Plate", BackgroundColor3 = UC.Bg0 or Color3.fromRGB(16, 18, 22), BackgroundTransparency = 0.45, BorderSizePixel = 0,
        Position = UDim2.fromOffset(-14, -6), Size = UDim2.new(1, 28, 0, 34 + barH + 12), ZIndex = 1 }, root)
    local name = New("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -70, 0, 28), TextSize = 20,
        TextColor3 = UC.Text or Color3.new(1, 1, 1), TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "", ZIndex = 10 }, root)
    Face(name, "Header")
    local pct = New("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 26), TextSize = 18,
        TextColor3 = UC.Text or Color3.fromRGB(230, 230, 230), TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Right, Text = "", ZIndex = 10 }, root)
    Face(pct, "Accent")
    local bar = BarStyles.MakeBar(root, BOSS_W, barH, style, tint, true)
    bar.Holder.AnchorPoint = Vector2.new(0, 0)
    bar.Holder.Position = UDim2.fromOffset(0, 34)
    local ticks = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8 }, bar.Clip)
    local tag = New("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Font = Enum.Font.GothamBlack, TextSize = 12,
        TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.2, Text = "", ZIndex = 9 }, bar.Clip)
    if style.Clean then -- (a 10 px bar can't hold words: SHIELDED / GUARDED sits right of the name, before the %)
        tag.Parent = root; tag.AnchorPoint = Vector2.new(1, 0); tag.Position = UDim2.new(1, -56, 0, 2); tag.Size = UDim2.fromOffset(160, 26)
        tag.TextXAlignment = Enum.TextXAlignment.Right; tag.TextStrokeTransparency = 1; tag.TextSize = 14; tag.TextColor3 = UC.Info or Color3.fromRGB(110, 170, 230)
        Face(tag, "Label")
    end
    -- (0.62, owner: "there is almost 0 indicator as to what youre suppose to even be shooting"): the boss's objective
    -- (BossInfo: "LOCKDOWN 0/4 ...", "POSTURE 40%", a tracking round) is its own big line under the bar, not 12 px inside it
    local goal = New("TextLabel", { Name = "Objective", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 34 + barH + 10), Size = UDim2.new(1, 0, 0, 24),
        TextSize = 17, TextColor3 = UC.Text or Color3.fromRGB(255, 220, 120), TextStrokeTransparency = 1, Text = "", ZIndex = 10 }, root)
    Face(goal, "Label")
    return { Root = root, Plate = plate, Name = name, Pct = pct, Bar = bar, Ticks = ticks, Tag = tag, Goal = goal, TickKey = nil, Style = style, Tint = tint, H = barH }
end

function EnemyBars.Start(enabledFn)
    -- (DisplayOrder -1, 0.58: at 2 the bars drew over the menus -- owner: "You can see enemy healthbars through your menus")
    local gui = New("ScreenGui", { Name = "EnemyBars", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = -1,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, LP:WaitForChild("PlayerGui"))
    local worldLayer = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
    local bossLayer = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
    -- (UI CLEAN R-C: the boss bars sit in the HUD's units -- the same scale as the floor banner above them, so the boss plate
    -- lines up with the banner's 660 at any screen size; the HUD's UIScale is mirrored, event-driven only)
    task.spawn(function()
        local hud = LP:WaitForChild("PlayerGui"):WaitForChild("AimRngMasterHUD", 30)
        local hs = hud and hud:FindFirstChildOfClass("UIScale")
        if not hs then return end
        local k = New("UIScale", { Scale = hs.Scale }, bossLayer)
        local function Sync()
            k.Scale = math.max(hs.Scale, 0.05)
            bossLayer.Size = UDim2.fromScale(1 / k.Scale, 1 / k.Scale) -- (the layer still spans the screen in screen pixels)
        end
        hs:GetPropertyChangedSignal("Scale"):Connect(Sync)
        Sync()
    end)

    local entries = {}   -- model -> entry
    local bossBars = {}  -- slot -> boss widget
    local hovered = nil
    local style = CurrentStyle()
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local function HideOld(model)
        local hud = model:FindFirstChild("HealthHUD")
        if hud and hud:IsA("BillboardGui") then hud.Enabled = false end
    end

    local function BuildBar(e)
        local model = e.Model
        local w, hgt = e.Elite and 124 or 84, e.Elite and 10 or 8
        local col = e.Elite and (ELITE_COL[model:GetAttribute("EliteTier")] or ELITE_COL.Magic) or FILL_COL
        e.Color = col
        local old = e.Bar
        e.Bar = BarStyles.MakeBar(worldLayer, w, hgt, style, col, false)
        e.Bar.Holder.Visible = false
        local hud = model:FindFirstChild("HealthHUD")
        local nl = hud and hud:FindFirstChild("NameLabel", true)
        e.Name = New("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0, 240, 0, 14), Position = UDim2.new(0.5, 0, 0, -4),
            AnchorPoint = Vector2.new(0.5, 1), Font = e.Elite and Enum.Font.GothamBlack or Enum.Font.GothamBold, TextSize = e.Elite and 13 or 12,
            TextColor3 = e.Elite and col or Color3.fromRGB(235, 235, 235), TextStrokeTransparency = 0.3, Text = nl and nl.Text or model.Name, ZIndex = 10 }, e.Bar.Holder)
        -- (ENEMY ATTACKS PILOT elite mod SHELLED) its typed shell: a 3 px strip in the type's colour just under the health bar
        e.Shell = nil
        local stype = model:GetAttribute("ShellType")
        if stype then
            local ok, DT = pcall(require, script.Parent:WaitForChild("DamageTypes"))
            local scol = ok and DT.COLOR[stype] or Color3.new(1, 1, 1)
            local track = New("Frame", { Name = "ShellTrack", BackgroundColor3 = Color3.fromRGB(10, 11, 14), BackgroundTransparency = 0.3, BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 1, 2), ZIndex = 4 }, e.Bar.Holder)
            e.Shell = New("Frame", { Name = "ShellFill", BackgroundColor3 = scol, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, track)
            e.ShellTrack = track
        end
        if old then old.Holder:Destroy() end
    end

    local Add
    function Add(model)
        if entries[model] or not model:IsA("Model") then return end
        if type(model:GetAttribute("MaxHealth")) ~= "number" then
            -- (tagged before its stats arrived: add it the moment they do, or it never gets a bar)
            local c; c = model:GetAttributeChangedSignal("MaxHealth"):Connect(function() c:Disconnect(); Add(model) end)
            return
        end
        local e = { Model = model, Boss = model:GetAttribute("IsBoss") == true, Elite = model:GetAttribute("IsElite") == true, Alpha = 0,
            St = { Shown = 1, Chip = 1, Target = 1, LastHit = -99, Flash = 0, Kick = 0 } }
        local h, mh = model:GetAttribute("Health"), model:GetAttribute("MaxHealth")
        if type(h) == "number" and mh > 0 then e.St.Shown = h / mh; e.St.Chip = e.St.Shown; e.St.Target = e.St.Shown end
        if not e.Boss then BuildBar(e) end
        HideOld(model)
        e.Conn = model.DescendantAdded:Connect(function(d)
            if d.Name == "HealthHUD" and d:IsA("BillboardGui") then task.defer(HideOld, model) end
        end)
        entries[model] = e
    end

    local function Remove(model)
        local e = entries[model]
        if not e then return end
        entries[model] = nil
        if e.Conn then e.Conn:Disconnect() end
        if not e.Bar then return end
        local bar = e.Bar
        if bar.Holder.Visible and e.Alpha > 0.05 then
            -- kill burst: the bar flashes white, swells and fades instead of just vanishing
            task.spawn(function()
                local t0 = os.clock()
                local base = bar.Scale.Scale
                while os.clock() - t0 < 0.28 do
                    local k = (os.clock() - t0) / 0.28
                    bar.Scale.Scale = base * (1 + 0.4 * k)
                    BarStyles.Paint(bar, 0, e.St.Chip * (1 - k), 1 - k * 0.5, e.Alpha * (1 - k), os.clock(), 1 / 60, false)
                    if e.Name then e.Name.TextTransparency = k; e.Name.TextStrokeTransparency = 0.3 + 0.7 * k end
                    RunService.RenderStepped:Wait()
                end
                bar.Holder:Destroy()
            end)
        else
            bar.Holder:Destroy()
        end
    end

    -- equipping a different cosmetic restyles everything live
    LP:GetAttributeChangedSignal("BarStyle"):Connect(function()
        style = CurrentStyle()
        for _, e in pairs(entries) do if not e.Boss then BuildBar(e) end end
        for i, w in pairs(bossBars) do w.Root:Destroy(); bossBars[i] = nil end
    end)

    for _, m in ipairs(CollectionService:GetTagged("AimRngEnemy")) do Add(m) end
    CollectionService:GetInstanceAddedSignal("AimRngEnemy"):Connect(function(m) task.defer(Add, m) end)
    CollectionService:GetInstanceRemovedSignal("AimRngEnemy"):Connect(Remove)

    local lastHoverCheck = 0
    RunService.RenderStepped:Connect(function(dt)
        local now = os.clock()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local on = enabledFn == nil or enabledFn()
        worldLayer.Visible = on
        local myRun = LP:GetAttribute("RunId")

        -- what the crosshair is on (10x/s)
        if now - lastHoverCheck > 0.1 then
            lastHoverCheck = now
            hovered = nil
            rayParams.FilterDescendantsInstances = { LP.Character or Workspace.Terrain }
            local vp = cam.ViewportSize
            local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
            local hit = Workspace:Raycast(ray.Origin, ray.Direction * 300, rayParams)
            local inst = hit and hit.Instance
            while inst and inst ~= Workspace do
                if entries[inst] then hovered = inst break end
                inst = inst.Parent
            end
        end

        local camPos = cam.CFrame.Position
        local shown = {}
        local bosses = {}
        for model, e in pairs(entries) do
            if not model.Parent then Remove(model) continue end
            local h, mh = model:GetAttribute("Health"), model:GetAttribute("MaxHealth")
            if type(h) ~= "number" or type(mh) ~= "number" or mh <= 0 then continue end
            local frac = math.clamp(h / mh, 0, 1)
            if model:GetAttribute("Dead") == true then frac = 0 end
            StepDrain(e.St, frac, dt, now)
            if e.Boss then
                if model:GetAttribute("RunId") == myRun and frac > 0 then table.insert(bosses, e) end
                continue
            end
            -- (optimization pass 2026-10-27: a bar that can't want to show -- full health or not hit lately, not hovered, not
            -- an elite -- and has already faded skips the head lookup + screen projection)
            if e.Alpha < 0.02 and model ~= hovered and not e.Elite and (not on or frac >= 0.999 or now - e.St.LastHit >= SHOW_AFTER_HIT) then
                if e.Bar and e.Bar.Holder.Visible then e.Bar.Holder.Visible = false end
                continue
            end
            local head = HeadOf(model)
            if not head then continue end
            -- (another floor's enemies -- a party member who went on ahead: their bars floated over your floor -- owner 2026-10-05)
            if model:GetAttribute("RunId") ~= myRun then
                if e.Bar then e.Bar.Holder.Visible = false end
                e.Alpha = 0
                continue
            end
            local wpos = head.Position + Vector3.new(0, head.Size.Y / 2 + 1.4, 0)
            local dist = (wpos - camPos).Magnitude
            local want = 0
            if on and dist < MAX_DIST then -- (at 0 it stays up for the kill: the chip drains out, then it bursts)
                if now - e.St.LastHit < SHOW_AFTER_HIT or model == hovered then want = 1
                elseif e.Elite and dist < 70 then want = 0.85 end
                if frac >= 0.999 and model ~= hovered and not e.Elite then want = 0 end
            end
            local sp, inView = cam:WorldToViewportPoint(wpos)
            if not inView then want = 0 end
            e.Alpha += (want - e.Alpha) * math.min(1, dt * (want > e.Alpha and 18 or 6))
            local bar = e.Bar
            if e.Alpha < 0.02 then
                bar.Holder.Visible = false
            else
                bar.Holder.Visible = true
                local sc = math.clamp(1.25 - dist / 160, 0.72, 1.1)
                -- (0.78: never over the crosshair -- a bar that would cover it moves above / below the keep-out square)
                local by = sp.Y
                do
                    local view = cam.ViewportSize
                    local cx, cy = view.X / 2, view.Y / 2
                    local K = 44
                    local hw, ht = bar.W * sc / 2, (bar.H + 16) * sc -- (anchored bottom-centre; the name sits above it)
                    if math.abs(sp.X - cx) < hw + K and by > cy - K and by - ht < cy + K then
                        by = (by - ht / 2 <= cy) and (cy - K) or (cy + K + ht)
                    end
                end
                bar.Holder.Position = UDim2.fromOffset(sp.X, by)
                bar.Scale.Scale = sc
                e.Name.Visible = e.Elite or model == hovered
                table.insert(shown, { E = e, X = sp.X, Y = sp.Y, D = dist, W = bar.W * sc, H = (bar.H + 16) * sc })
            end
        end

        -- declutter: nearer bars win, overlapped farther ones fade back
        table.sort(shown, function(a, b) return a.D < b.D end)
        for i, a in ipairs(shown) do
            local fade = 1
            for j = 1, i - 1 do
                local b = shown[j]
                if math.abs(a.X - b.X) < (a.W + b.W) / 2 and math.abs(a.Y - b.Y) < (a.H + b.H) / 2 then fade = 0.3 break end
            end
            local alpha = a.E.Alpha * fade
            local st = a.E.St
            BarStyles.Paint(a.E.Bar, st.Shown, st.Chip, st.Flash, alpha, now, dt, false)
            if a.E.Shell then
                local m = a.E.Model
                local sh, smax = m:GetAttribute("ShellHp"), m:GetAttribute("ShellMax")
                local sf = (type(sh) == "number" and type(smax) == "number" and smax > 0) and math.clamp(sh / smax, 0, 1) or ((sh == nil) and 1 or 0)
                -- (review N: writes only on a change)
                local key = math.round(sf * 200) * 1000 + math.round(alpha * 100)
                if a.E.ShellKey ~= key then
                    a.E.ShellKey = key
                    a.E.ShellTrack.Visible = sf > 0
                    a.E.Shell.Size = UDim2.fromScale(sf, 1)
                    a.E.Shell.BackgroundTransparency = 1 - alpha
                    a.E.ShellTrack.BackgroundTransparency = 1 - alpha * 0.7
                end
            end
            a.E.Name.TextTransparency = 1 - alpha
            a.E.Name.TextStrokeTransparency = 0.3 + 0.7 * (1 - alpha)
            a.E.Bar.Holder.ZIndex = 100 - i
        end

        -- boss bars
        table.sort(bosses, function(a, b) return (a.Model:GetAttribute("MaxHealth") or 0) > (b.Model:GetAttribute("MaxHealth") or 0) end)
        for slot = 1, math.max(#bosses, #bossBars, 2) do
            local e = slot <= 2 and bosses[slot] or nil
            local w = bossBars[slot]
            if e then
                local m = e.Model
                local col = m:GetAttribute("BossColor")
                if typeof(col) ~= "Color3" then col = FILL_COL end
                local shielded = (m:GetAttribute("DamageTakenMult") or 1) < 0.9
                local tint = shielded and SHIELD_COL or col
                -- Standard takes the boss's colour (and turns blue while shielded): rebuild when that changes
                if w and style.Id == "Standard" and w.Tint ~= tint then w.Root:Destroy(); w = nil end
                if not w then w = MakeBossBar(bossLayer, style, tint); bossBars[slot] = w end
                w.Root.Visible = true
                local title = m:GetAttribute("BossTitle")
                if not title then
                    local hud = m:FindFirstChild("HealthHUD")
                    local lbl = hud and hud:FindFirstChildWhichIsA("TextLabel", true)
                    title = lbl and lbl.Text or m.Name
                end
                w.Name.Text = string.upper(tostring(title))
                w.Pct.Text = string.format("%d%%", math.ceil(e.St.Target * 100))
                local info = m:GetAttribute("BossInfo")
                -- (0.99u BOSS PACE: an aim round GUARDS -- half damage -- instead of shielding)
                local mult = m:GetAttribute("DamageTakenMult") or 1
                w.Tag.Text = shielded and ((mult <= 0.01) and "SHIELDED" or "GUARDED  -50%") or ""
                local gt = (info and info ~= "") and string.upper(info) or "" -- (BossAI signatures: posture / heat / cannons ...)
                if w.Goal.Text ~= gt then -- (UI CLEAN R-C: the plate grows to hold the objective line)
                    w.Goal.Text = gt
                    w.Plate.Size = UDim2.new(1, 28, 0, 34 + w.H + 12 + ((gt ~= "") and 28 or 0))
                end
                local key = m:GetAttribute("BossPhases") or ""
                if w.TickKey ~= key then
                    w.TickKey = key
                    w.Ticks:ClearAllChildren()
                    for _, s in ipairs(string.split(key, ",")) do
                        local v = tonumber(s)
                        if v then New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 8,
                            Size = UDim2.new(0, 2, 1, 0), Position = UDim2.new(v, -1, 0, 0) }, w.Ticks) end
                    end
                    -- (0.99u HIT FEEDBACK) the bar reads as 10 CHUNKS: thin dark notches every 10% (the phase ticks stay white)
                    for i = 1, 9 do
                        New("Frame", { BackgroundColor3 = Color3.fromRGB(8, 8, 12), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 7,
                            Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(i / 10, 0, 0, 0) }, w.Ticks)
                    end
                end
                -- (0.99u HIT FEEDBACK) a chunk that breaks drops off the bar: a piece of the bar's colour falls and fades (no flash;
                -- top of the screen, far from the crosshair). BossAI flinches the boss on the same 10% steps.
                do
                    local chunk = math.ceil(e.St.Target * 10 - 1e-6)
                    if w.Chunk and chunk < w.Chunk and e.St.Target > 0 then
                        for c = chunk, math.min(9, w.Chunk - 1) do
                            local piece = New("Frame", { BackgroundColor3 = tint, BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 11,
                                Size = UDim2.fromOffset(BOSS_W / 10 - 2, w.H), Position = UDim2.fromOffset(c * BOSS_W / 10 + 1, 34) }, w.Root)
                            TweenService:Create(piece, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                                Position = UDim2.fromOffset(c * BOSS_W / 10 + 1 + (math.random() - 0.5) * 10, 34 + 26), Rotation = (math.random() - 0.5) * 24,
                                BackgroundTransparency = 1, Size = UDim2.fromOffset(BOSS_W / 10 - 8, math.max(2, w.H - 6)) }):Play()
                            task.delay(0.5, function() piece:Destroy() end)
                        end
                    end
                    w.Chunk = chunk
                end
                local kick = e.St.Kick
                -- (0.62: in the entry room the SAFE ZONE banner sits at y 96-126 -> the boss bars drop below it)
                local safeDrop = game:GetService("Players").LocalPlayer:GetAttribute("SafeZone") == true and 40 or 0
                w.Root.Position = UDim2.new(0.5, (math.random() - 0.5) * kick * 14, 0, 112 + safeDrop + (slot - 1) * 96 + (math.random() - 0.5) * kick * 6)
                w.Bar.Scale.Scale = 1 + kick * 0.2
                BarStyles.Paint(w.Bar, e.St.Shown, e.St.Chip, e.St.Flash, 1, now, dt, true)
            elseif w then
                w.Root.Visible = false
            end
        end
    end)
end

return EnemyBars
