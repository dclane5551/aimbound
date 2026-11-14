-- ZENITH client half (CHASE ITEMS 2026-11-06, contract docs/CHASE_ITEMS_2026-11-06.md). The server rules are AimRngServer/ZenithServer;
-- the numbers are ItemData.ZENITH_TUNE (one table, so text / server / client never drift). AimRngClient calls in from its
-- ;(function() blocks (UI.Zen = this module):
--   FURNACE HEART  Pull / AfterPull in FireWeapon (the same drain + lockout rule the server runs: the server corrects on every hit),
--                  IsFurnace (no reload), ShowAmmo (the ammo readout becomes a HEAT bar: "HEAT 63%", red + LOCKED in the lockout)
--   LONG PROMISE   AutoReload (a one-round gun reloads by itself after the shot), AdsTick -> Player attr ZenAdsSlow (MovementController
--                  BaseSpeed multiplies by it: x0.7 while aiming down sights)
--   BLOOMSHOT      SpreadMult (x1.4 pellet spread)
--   UNBROKEN THREAD  a small counter above the ammo block (never near the crosshair): "THREAD 7  +28%" in the Zenith colour,
--                  "FRAYED 1.6s  +15% DAMAGE TAKEN" in amber after a miss (no flash); reads Player attrs ZenThread / ZenFray;
--                  the 5 s DECAY (owner 2026-11-06) = "... • 3.2s" + a 2 px line under it that drains (Player attr ZenThreadAt)
--   SELL ASK       SellAsk(item, isGear, dismantle, go): a Zenith asks "Sell ZENITH <name>?" first (PopupUI.Confirm); the server
--                  refuses a Zenith sell / dismantle without the flag go(true) sends. Studio: Player attr DevZenSell = "<uid>|sell" |
--                  "<uid>|dismantle" opens it, "yes" = the popup's YES, "<uid>|raw" = the remote with no flag -> DevZenSellOut
--   FX             CombatFx "ZenFx" (ZenithServer.Fx: the ricochet / fork / burst lines + Bloomshot's burst ring, sent to you and
--                  your party): a POOL of 24 neon parts (no new instance per effect, no lights), each fades in ~0.3 s
--   BROADCAST      workspace attr ZenithCall (ZenithServer.Broadcast) -> an important toast + Call(now) = the World Alerts line's text
--                  for CALL_SECONDS
-- Studio: Player attr DevZenHeat = true prints the heat state to DevZenHeatOut every 0.1 s (tests); DevZenFxHold = n slows the FX fades
-- n times (screenshots).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ItemData = require(script.Parent:WaitForChild("ItemData"))

local ZC = {}
local LocalPlayer = Players.LocalPlayer
local ZT = ItemData.ZENITH_TUNE
local hooks: any = {}
ZC.CALL_SECONDS = 14

local function Zen(w: any, id: string): boolean
    return type(w) == "table" and w.Exotic == id
end
function ZC.IsFurnace(cs: any): boolean
    return cs ~= nil and Zen(cs.EquippedWeapon, "FurnaceHeart")
end

-- ===== FURNACE HEART (heat in rounds: CurrentMag counts down as heat builds) =====
-- the last pull's time + the lockout live HERE, not on clientState: a full SyncPlayerState replaces clientState and used to wipe
-- them (the drain then read "no shot for ages" and refilled the gun mid-burst -- seen in Studio 2026-11-06)
local zLast, zLock = -99, nil
-- the magazine as the next pull would see it (drain after Idle s without firing), and the lockout left
local function Effective(cs: any): (number, number, number?)
    local F = ZT.FurnaceHeart
    local mx = math.max(1, cs.MaxMag or 1)
    local now = os.clock()
    if zLock then
        if now < zLock then return 0, mx, zLock - now end
        return mx, mx, nil
    end
    local cur = cs.CurrentMag or mx
    local gap = now - zLast
    if gap > F.Idle then cur = math.min(mx, cur + math.floor((gap - F.Idle) * F.Drain * mx)) end
    return cur, mx, nil
end
ZC.Effective = Effective
function ZC.Pull(cs: any): boolean
    if not ZC.IsFurnace(cs) then return true end
    local cur, mx, lockLeft = Effective(cs)
    if lockLeft then return false end
    zLock = nil
    cs.CurrentMag = math.min(mx, cur)
    cs.IsReloading = false
    zLast = os.clock()
    return true
end
function ZC.AfterPull(cs: any)
    if not ZC.IsFurnace(cs) then return end
    if (cs.CurrentMag or 0) <= 0 then zLock = os.clock() + ZT.FurnaceHeart.Lock end
end
-- the ammo readout -> a heat bar (true = handled)
function ZC.ShowAmmo(_cur: number, _max: number): boolean
    local cs = hooks.GetState and hooks.GetState()
    local U = hooks.UI
    if not ZC.IsFurnace(cs) or not (U and U.ammoCounterLbl and U.ammoMagLbl and U.ammoBarFill) then return false end
    local cur, mx, lockLeft = Effective(cs)
    local heat = math.clamp(1 - cur / mx, 0, 1)
    local hot = heat >= 0.75 or lockLeft ~= nil
    local red, warm, white = Color3.fromRGB(255, 96, 70), Color3.fromRGB(255, 170, 90), Color3.fromRGB(240, 240, 240)
    U.ammoCounterLbl.Text = lockLeft and "LOCKED" or (tostring(math.floor(heat * 100 + 0.5)) .. "%")
    U.ammoCounterLbl.TextColor3 = lockLeft and red or (hot and warm or white)
    U.ammoMagLbl.Text = lockLeft and string.format("HEAT  %.1fs", lockLeft) or "HEAT"
    U.ammoMagLbl.TextColor3 = (lockLeft or hot) and red or Color3.fromRGB(176, 173, 167)
    U.ammoBarFill.Size = UDim2.new(lockLeft and 1 or heat, 0, 1, 0)
    U.ammoBarFill.BackgroundColor3 = lockLeft and red or (hot and warm or white)
    return true
end

-- ===== LONG PROMISE / BLOOMSHOT =====
function ZC.AutoReload(w: any): boolean return Zen(w, "LongPromise") end
function ZC.SpreadMult(w: any): number return Zen(w, "Bloomshot") and ZT.Bloomshot.Spread or 1 end
local adsOn = false
function ZC.AdsTick(aiming: boolean, w: any)
    local on = aiming and Zen(w, "LongPromise")
    if on == adsOn then return end
    adsOn = on
    LocalPlayer:SetAttribute("ZenAdsSlow", on and ZT.LongPromise.AdsMove or nil)
end

-- ===== UNBROKEN THREAD: the stack counter =====
local threadLbl: TextLabel? = nil
local function ThreadWorn(cs: any): boolean
    local z = cs and ItemData.ZenithActive(nil, cs.EquippedGear)
    return z ~= nil and z.UnbrokenThread == true
end
function ZC.ThreadTick()
    local cs = hooks.GetState and hooks.GetState()
    local U = hooks.UI
    local card = U and U.weaponCard
    local worn = ThreadWorn(cs)
    if not worn then
        if threadLbl then threadLbl.Visible = false end
        return
    end
    if not card then return end
    if not threadLbl or not threadLbl.Parent then
        -- on top of the bottom-left HUD plate (the weapon card's panel), left-aligned: far from the crosshair, clear of the
        -- plate's own lines (the first try sat on the health / weapon divider)
        local plate = card.Parent and card.Parent:FindFirstChild("HudPlate")
        local l = Instance.new("TextLabel")
        l.Name = "ZenThread"
        l.AnchorPoint = Vector2.new(0, 1)
        l.Position = plate and UDim2.new(0, 8, 0, -6) or UDim2.new(0, 0, 0, -6)
        l.Size = UDim2.new(0, 0, 0, 20)
        l.AutomaticSize = Enum.AutomaticSize.X
        l.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
        l.BackgroundTransparency = 0.25
        l.BorderSizePixel = 0
        l.Font = Enum.Font.GothamBold
        l.TextSize = 13
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.ZIndex = 6
        local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8); pad.Parent = l
        local edge = Instance.new("Frame"); edge.Name = "Edge"; edge.BorderSizePixel = 0; edge.BackgroundColor3 = ItemData.ZENITH_COLOR
        edge.Size = UDim2.new(0, 2, 1, 0); edge.Position = UDim2.new(0, -8, 0, 0); edge.ZIndex = 7; edge.Parent = l
        l:SetAttribute("Skinned", true)
        l:SetAttribute("NoSnap", true)
        l.Parent = plate or card
        threadLbl = l
    end
    local T = ZT.UnbrokenThread
    local n = tonumber(LocalPlayer:GetAttribute("ZenThread")) or 0
    local fray = tonumber(LocalPlayer:GetAttribute("ZenFray")) or 0
    local now = workspace:GetServerTimeNow()
    local left = fray - now
    local l = threadLbl :: TextLabel
    l.Visible = true
    -- the decay: seconds until the stacks fade (Decay s after the last hit; the server clears them then)
    local at = tonumber(LocalPlayer:GetAttribute("ZenThreadAt"))
    local fade = (n > 0 and at) and math.clamp((T.Decay or 5) - (now - at), 0, T.Decay or 5) or nil
    local bar = l:FindFirstChild("Decay") :: Frame?
    if not bar then
        local b = Instance.new("Frame"); b.Name = "Decay"; b.BorderSizePixel = 0; b.BackgroundColor3 = ItemData.ZENITH_COLOR
        b.AnchorPoint = Vector2.new(0, 1); b.Position = UDim2.new(0, 0, 1, 0); b.ZIndex = 7; b.Parent = l
        bar = b
    end
    if left > 0 and n == 0 then
        l.Text = string.format("FRAYED %.1fs  •  +%d%% DAMAGE TAKEN", left, math.floor((T.Taken - 1) * 100 + 0.5))
        l.TextColor3 = Color3.fromRGB(255, 190, 110)
    else
        l.Text = string.format("THREAD %d/%d  •  +%d%%", n, T.Max, math.floor(n * T.Per * 100 + 0.5)) .. (fade and string.format("  •  %.1fs", fade) or "")
        l.TextColor3 = (n >= T.Max) and ItemData.ZENITH_COLOR or ((n > 0) and Color3.fromRGB(205, 240, 232) or Color3.fromRGB(150, 160, 170))
    end
    local b = bar :: Frame
    b.Visible = fade ~= nil
    if fade then
        b.Size = UDim2.new(fade / (T.Decay or 5), 0, 0, 2)
        b.BackgroundColor3 = (fade <= 1.5) and Color3.fromRGB(255, 190, 110) or ItemData.ZENITH_COLOR
    end
end

-- ===== SELL / DISMANTLE A ZENITH: ask first (owner 2026-11-06). false = not a Zenith (the caller sells as before) =====
local pendingYes: any = nil
function ZC.SellAsk(item: any, _isGear: boolean, dismantle: boolean, go: (boolean) -> ()): boolean
    if not ItemData.ZenithOf(item) then return false end
    local PopupUI = require(script.Parent:WaitForChild("PopupUI"))
    local name = tostring(item.Name or "?")
    pendingYes = function() pendingYes = nil; go(true) end
    PopupUI.Confirm(dismantle and "Dismantle Zenith" or "Sell Zenith",
        dismantle and ("Dismantle ZENITH " .. name .. "? This can't be undone.") or ("Sell ZENITH " .. name .. "? This can't be undone after you leave."),
        dismantle and "DISMANTLE" or "SELL", Color3.fromRGB(176, 72, 60), function() if pendingYes then pendingYes() end end)
    return true
end

-- ===== ZENITH FX: pooled lines + rings (the clutter cap is the pool: 24 at most, the oldest is reused) =====
local TweenService = game:GetService("TweenService")
local POOL_N = 24
local pool: { BasePart } = {}
local poolI = 0
local fxFolder: Folder? = nil
local fades: { [BasePart]: Tween } = {}
local function PoolPart(): BasePart
    poolI = poolI % POOL_N + 1
    local p = pool[poolI]
    if not p or not p.Parent then
        if not fxFolder or not fxFolder.Parent then
            local f = Instance.new("Folder"); f.Name = "ZenithFx"
            f:SetAttribute("KeepNeon", true) -- (gameplay feedback: NeonTamer leaves it lit)
            f.Parent = workspace
            fxFolder = f
        end
        p = Instance.new("Part")
        p.Name = "ZenFx"; p.Material = Enum.Material.Neon
        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
        p.Transparency = 1
        p.Parent = fxFolder
        pool[poolI] = p
    end
    return p
end
local function Fade(p: BasePart, t: number, goal: any)
    if RunService:IsStudio() then t *= tonumber(LocalPlayer:GetAttribute("DevZenFxHold")) or 1 end -- (Studio: slow fades for screenshots)
    local old = fades[p]
    if old then old:Cancel() end
    local tw = TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
    fades[p] = tw
    tw:Play()
end
-- a solo floor's server stand-ins sit at ground height: an end point snaps to the real enemy model it stands for (the nearest
-- enemy within SNAP studs across the ground), so the line runs body to body
local CollectionService = game:GetService("CollectionService")
local SNAP = 7
local function Snap(at: Vector3): Vector3
    local best, bd = nil, SNAP
    for _, m in ipairs(CollectionService:GetTagged("AimRngEnemy")) do
        if m:IsA("Model") and m.Parent then
            local part = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso") or m:FindFirstChild("Head")
            if part and part:IsA("BasePart") then
                local d = Vector2.new(part.Position.X - at.X, part.Position.Z - at.Z).Magnitude
                if d < bd then best, bd = part.Position, d end
            end
        end
    end
    return best or at
end
function ZC.Fx(sub: string, a: any, b: any, color: any)
    if typeof(a) ~= "Vector3" or typeof(color) ~= "Color3" then return end
    a = Snap(a)
    if typeof(b) == "Vector3" then b = Snap(b) end
    if sub == "Line" and typeof(b) == "Vector3" then
        local len = (b - a).Magnitude
        if len < 0.5 or len > 250 then return end
        local p = PoolPart()
        p.Shape = Enum.PartType.Block
        p.Size = Vector3.new(0.35, 0.35, len)
        p.CFrame = CFrame.lookAt((a + b) / 2, b)
        p.Color = color
        p.Transparency = 0.05
        Fade(p, 0.3, { Transparency = 1, Size = Vector3.new(0.06, 0.06, len) })
    elseif sub == "Ring" then -- (a flat disc that grows + fades: seen edge-on at eye height, so it never covers the crosshair)
        local r = math.clamp(tonumber(b) or 6, 1, 30)
        local p = PoolPart()
        p.Shape = Enum.PartType.Cylinder
        p.Size = Vector3.new(0.1, r * 0.4, r * 0.4)
        p.CFrame = CFrame.new(a) * CFrame.Angles(0, 0, math.pi / 2)
        p.Color = color
        p.Transparency = 0.35
        Fade(p, 0.32, { Transparency = 1, Size = Vector3.new(0.1, r * 2, r * 2) })
    end
end

-- ===== THE SERVER-WIDE CALL =====
local call: any = nil
local function ReadCall()
    local raw = workspace:GetAttribute("ZenithCall")
    if type(raw) ~= "string" or raw == "" then return end
    local ok, d = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or type(d) ~= "table" then return end
    local what = (d.C == "TwinGlass") and "TWIN GLASS" or ("ZENITH " .. string.upper(tostring(d.I or "?")))
    call = { Text = string.format("CITY BROADCAST: %s found %s", tostring(d.N or "Someone"), what), T = tonumber(d.T) or workspace:GetServerTimeNow() }
    return call
end
function ZC.Call(now: number): string?
    if call and now - call.T <= ZC.CALL_SECONDS and now >= call.T - 2 then return call.Text end
    return nil
end

-- ===== INDEX (TRAITS / RARITIES page): the ZENITH section -- only once the tier is live (Studio: workspace DevZenithLive) =====
function ZC.Shown(): boolean
    return ItemData.ZenithShown()
end
function ZC.IndexSection(parent: ScrollingFrame, posY: number): number
    local okS, UIStyle = pcall(require, script.Parent:WaitForChild("UIStyle"))
    local col = ItemData.ZENITH_COLOR
    local function Label(text: string, y: number, h: number, size: number, color: Color3, role: string?, p: Instance): TextLabel
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextYAlignment = Enum.TextYAlignment.Top
        l.TextWrapped = true; l.RichText = false; l.Text = text; l.TextSize = size; l.TextColor3 = color
        l.Font = Enum.Font.GothamMedium
        if okS and role then pcall(function() l.FontFace = UIStyle.RoleFace(role) end) end
        l:SetAttribute("NoSnap", true)
        l.Position = UDim2.new(0, 10, 0, y); l.Size = UDim2.new(1, -20, 0, h)
        l.Parent = p
        return l
    end
    local head = Instance.new("Frame")
    head.Size = UDim2.new(0.96, 0, 0, 62); head.Position = UDim2.new(0.02, 0, 0, posY); head.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
    head.BorderSizePixel = 1; head.BorderColor3 = col; head.Name = "ZenithTier"; head.Parent = parent
    Label("❖ ZENITH", 4, 22, 18, col, "Label", head)
    Label("Above Relics: named items that change how you play, each with a real catch. Two pieces of gear can drop from any kill; five guns, one for each class, only from the Summit. Twin Glass copies an item.", 26, 34, 13, Color3.fromRGB(190, 200, 215), nil, head)
    posY += 70
    do -- (the drop chances in words, not numbers)
        local note = Instance.new("Frame")
        note.Size = UDim2.new(0.96, 0, 0, 44); note.Position = UDim2.new(0.02, 0, 0, posY); note.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
        note.BorderSizePixel = 1; note.BorderColor3 = Color3.fromRGB(60, 70, 80); note.Name = "ZenithOdds"; note.Parent = parent
        Label("ZENITH DROP CHANCE  •  gear: exceedingly rare, from any kill, more often on harder tiers  •  guns: a slim chance from each Summit kill, better from the Unbound", 4, 18, 13, col, nil, note)
        Label("TWIN GLASS  •  the rarest drop there is: any kill, more often on harder tiers. Most players will trade for one.", 24, 18, 13, Color3.fromRGB(190, 200, 215), nil, note)
        posY += 52
    end
    for _, id in ipairs(ItemData.ZENITH_ORDER) do
        local d = ItemData.Exotics[id]
        if d then
            local card = Instance.new("Frame")
            card.Size = UDim2.new(0.96, 0, 0, 92); card.Position = UDim2.new(0.02, 0, 0, posY); card.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
            card.BorderSizePixel = 1; card.BorderColor3 = Color3.fromRGB(60, 70, 80); card.Name = "Zenith_" .. id; card.Parent = parent
            local what = (d.Kind == "Weapon") and ((ItemData.BaseWeapons[d.Base] and ItemData.BaseWeapons[d.Base].Name or d.Base) .. "  •  " .. tostring(d.Class))
                or (tostring(d.Slot) .. "  •  any class")
            Label(string.upper(d.Name) .. "   " .. what .. "   •   " .. (d.Global and "any kill" or "the Summit"), 4, 18, 15, col, "Label", card)
            Label(d.Desc, 24, 30, 13, Color3.fromRGB(225, 225, 225), nil, card)
            Label("CATCH: " .. d.Catch, 54, 16, 13, Color3.fromRGB(255, 130, 120), nil, card)
            Label(d.Global and "Drop chance: exceedingly rare  •  any kill, more often on harder tiers" or "Drop chance: very rare  •  the Summit only (Apex, better from the Unbound)", 72, 16, 12, Color3.fromRGB(160, 175, 190), nil, card)
            posY += 100
        end
    end
    parent.CanvasSize = UDim2.new(0, 0, 0, math.max(parent.CanvasSize.Y.Offset + 122 + 100 * #ItemData.ZENITH_ORDER, posY + 400))
    return posY
end

function ZC.Init(h: any)
    hooks = h or {}
    pcall(function()
        require(script.Parent:WaitForChild("Remotes")).GetEvent("CombatFx").OnClientEvent:Connect(function(kind, sub, a, b, c)
            if kind == "ZenFx" then pcall(ZC.Fx, sub, a, b, c) end
        end)
    end)
    if RunService:IsStudio() then -- (Studio: DevZenSell, see the header)
        LocalPlayer:GetAttributeChangedSignal("DevZenSell"):Connect(function()
            local v = tostring(LocalPlayer:GetAttribute("DevZenSell") or "")
            if v == "" then return end
            local Remotes = require(script.Parent:WaitForChild("Remotes"))
            local out = "?"
            if v == "yes" then
                if pendingYes then pcall(function() require(script.Parent:WaitForChild("PopupUI")).Close() end); pendingYes(); out = nil else out = "no popup" end -- (the remote's answer is the output)
            else
                local uid, act = string.match(v, "^([^|]+)|(%a+)$")
                local cs = hooks.GetState and hooks.GetState() or {}
                local item, isGear = nil, false
                for _, it in ipairs(cs.Inventory or {}) do if it.Uid == uid then item = it end end
                for _, it in ipairs(cs.GearInventory or {}) do if it.Uid == uid then item, isGear = it, true end end
                local function Send(flag: boolean?)
                    local ok, r
                    if act == "dismantle" then ok, r = Remotes.GetFunction("DismantleItem"):InvokeServer(uid, isGear and "Gear" or "Weapon", flag)
                    else ok, r = Remotes.GetFunction(isGear and "SellGear" or "SellWeapon"):InvokeServer(uid, flag) end
                    LocalPlayer:SetAttribute("DevZenSellOut", tostring(ok) .. " " .. (type(r) == "table" and "mats" or tostring(r)))
                end
                if not item then out = "no item"
                elseif act == "raw" then Send(nil); out = nil
                else
                    local asked = ZC.SellAsk(item, isGear, act == "dismantle", function(f) Send(f) end)
                    out = asked and "popup open" or "not a zenith"
                end
            end
            if out then LocalPlayer:SetAttribute("DevZenSellOut", out) end
        end)
    end
    workspace:GetAttributeChangedSignal("ZenithCall"):Connect(function()
        local c = ReadCall()
        if c and hooks.Toast then hooks.Toast(c.Text, true) end
        if c and hooks.Sound then pcall(hooks.Sound) end
    end)
    -- the heat bar drains on screen while you hold fire (10 Hz, only while a Furnace Heart is in hand)
    task.spawn(function()
        while true do
            task.wait(0.1)
            local cs = hooks.GetState and hooks.GetState()
            if ZC.IsFurnace(cs) and hooks.Refresh then pcall(hooks.Refresh) end
            pcall(ZC.ThreadTick)
            if RunService:IsStudio() and LocalPlayer:GetAttribute("DevZenHeat") and cs then
                local cur, mx, lockLeft = Effective(cs)
                LocalPlayer:SetAttribute("DevZenHeatOut", string.format("cur=%s max=%s lock=%s mag=%s", tostring(cur), tostring(mx), tostring(lockLeft), tostring(cs.CurrentMag)))
            end
        end
    end)
end

return ZC
