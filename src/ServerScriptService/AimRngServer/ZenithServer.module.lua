-- ZENITH (CHASE ITEMS 2026-11-06, contract docs/CHASE_ITEMS_2026-11-06.md): the server half of the tier above Relics.
-- Data + numbers = ItemData "ZENITH" block (ZENITH_TUNE, defs in ItemData.Exotics with Zenith = true); magazine / reload /
-- weak-spot / body numbers = StatCalculator (stats.Zenith); the heat HUD, aim slow and spread = AimRngShared/ZenithClient.
-- CombatServer calls in (CombatServer.Zen = this module, Init(deps) once its locals exist):
--   KillRoll       GiveKillRewards, every kill: the two GLOBAL Zeniths (gear) + Twin Glass (ZENITH_TUNE.Drops x the difficulty's area)
--   Apex           PayApex: Apex / Unbound chance (ZENITH_TUNE.Drops) for one of the five PINNACLE guns (+ GlassUber, 0 today)
--   ThreadPull / ThreadHit / ThreadKeep  the hit remote (Unbroken Thread: a stack per pull that lands; a pull with nothing = a miss)
--   OnPull/AfterPull  the hit remote's trigger pull (Furnace Heart: heat drain + the lockout; never a reload)
--   CanReload      the Reload remote (Furnace Heart refuses)
--   Pierce         PierceShot (Long Promise: every enemy in the line, +20% per enemy passed, full damage)
--   PostHit        after ShotModFx: Glass Halo refund, Saint's Ricochet, Furnace vent, Bloomshot burst, Lattice forks
--   TakenMult      DamagePlayer (Lattice: +15% damage taken while firing; Unbroken Thread: +15% for 2 s after a miss)
--   Twin           ForgeReroll mode "Twin": TWIN GLASS (server-atomic copy)
-- SHIP DARK: nothing here drops unless ZS.Live() (ItemData.ZENITH_LIVE, or Studio workspace attr DevZenithLive). Studio hooks:
-- workspace DevZenithDrop = n (every kill rolls the global Zenith AND Twin Glass at chance n, ignores the switch), DevZenithApex = n
-- (the Summit roll at chance n). Gifts (F6 GIFTS / DevCmd zenith) never look at the switch.
-- BROADCAST: workspace attr ZenithCall = JSON { N = finder, I = what, C = "Zenith" | "TwinGlass", T = server time } -> every client
-- shows "CITY BROADCAST: <player> found ZENITH <name>" on the World Alerts line + an important toast (AimRngClient); the drop
-- itself goes through the normal ground drop (beam / tag / sound / DROP FEED).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local ItemData = require(Shared:WaitForChild("ItemData"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ZS = {}
local D: any = nil -- deps (CombatServer locals): Deal, Nearest, RootPos, ResistMult, DropGiven, Grant, ContentLevel, Sync
local ZT = ItemData.ZENITH_TUNE
local IS_STUDIO = RunService:IsStudio()

function ZS.Init(deps: any)
    D = deps
end

function ZS.Live(): boolean
    if ItemData.ZENITH_LIVE == true then return true end
    return IS_STUDIO and workspace:GetAttribute("DevZenithLive") == true
end
local function DevChance(attr: string): number?
    if not IS_STUDIO then return nil end
    local v = workspace:GetAttribute(attr)
    return type(v) == "number" and v or nil
end

-- ===== BROADCAST (server-wide) =====
function ZS.Broadcast(player: Player, what: string, kind: string)
    pcall(function()
        workspace:SetAttribute("ZenithCall", HttpService:JSONEncode({ N = player.DisplayName, I = what, C = kind, T = workspace:GetServerTimeNow() }))
    end)
end

-- ===== DROPS =====
-- one Zenith of `id` for `player` onto the ground in front of them (never auto-sold), + the server-wide call
function ZS.Award(player: Player, state: any, id: string, source: string?): any
    local item = ItemData.MakeZenith(id, ItemData.ZenithLevel(state.Level)) -- (owner 2026-11-06: the player's level, not the floor's)
    if not item then return nil end
    local kind = (ItemData.Exotics[id].Kind == "Weapon") and "Weapon" or "Gear"
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "ZENITH: " .. string.upper(item.Name) .. "!", ItemData.ZENITH_COLOR)
    D.DropGiven(player, state, item, kind)
    ZS.Broadcast(player, item.Name, "Zenith")
    player:SetAttribute("ZenithLast", item.Name .. "|" .. tostring(source or "?")) -- (Studio checks / logs)
    return item
end
function ZS.GiveTwinGlass(player: Player, state: any, n: number?)
    D.Grant(player, state, { TwinGlass = n or 1 }, nil, true)
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "TWIN GLASS FOUND: copy any weapon or gear piece at the Forge", ItemData.ZENITH_COLOR)
    ZS.Broadcast(player, "Twin Glass", "TwinGlass")
end
-- every kill (CombatServer GiveKillRewards): kind "Mob" | "Elite" | "Boss" | "SuperBoss"; rare = the fodder share (PacksPilot.RARE)
function ZS.KillRoll(player: Player, state: any, kind: string, rare: number?, diff: string?)
    local dev = DevChance("DevZenithDrop")
    if not dev and not ZS.Live() then return end
    local mult = (kind == "Mob") and (rare or 1) or 1
    local zc = dev or ItemData.ZenithKillChance(ItemData.ZENITH_KILL, kind, diff) * mult
    if math.random() < zc then
        local list = ItemData.ZENITH_GLOBAL
        ZS.Award(player, state, list[math.random(1, #list)], "Kill")
    end
    local tc = dev or ItemData.ZenithKillChance(ItemData.TWIN_GLASS_KILL, kind, diff) * mult
    if math.random() < tc then ZS.GiveTwinGlass(player, state, 1) end
end
-- the Summit (CombatServer.PayApex): returns lines for the reward summary
function ZS.Apex(player: Player, state: any, uber: boolean): { string }
    local out = {}
    local dev = DevChance("DevZenithApex")
    if not dev and not ZS.Live() then return out end
    if math.random() < (dev or ItemData.ZenithApexChance(uber)) then
        local list = ItemData.ZENITH_PINNACLE
        local item = ZS.Award(player, state, list[math.random(1, #list)], uber and "Unbound" or "Summit")
        if item then table.insert(out, "ZENITH: " .. item.Name) end
    end
    if uber and math.random() < (dev or ItemData.TwinGlassUberChance()) then
        ZS.GiveTwinGlass(player, state, 1)
        table.insert(out, "Twin Glass")
    end
    return out
end

-- ===== FURNACE HEART: heat (= the magazine counted down; capacity = magazine size) =====
local function Furnace(state: any): boolean
    local w = state.EquippedWeapon
    return type(w) == "table" and w.Exotic == "FurnaceHeart"
end
ZS.IsFurnace = Furnace
-- before a trigger pull is accepted: drain + lockout. false = locked (the pull is refused)
function ZS.OnPull(state: any): boolean
    if not Furnace(state) then return true end
    local s = state :: any
    local now = os.clock()
    local F = ZT.FurnaceHeart
    local mx = math.max(1, state.MaxMag or 1)
    if s.ZLockUntil then
        if now < s.ZLockUntil then return false end
        s.ZLockUntil = nil
        state.CurrentMag = mx -- (vented: the lockout clears all the heat)
    end
    local gap = now - (s.ZLastShot or -99)
    if gap > F.Idle then
        local back = math.floor((gap - F.Idle) * F.Drain * mx)
        if back > 0 then state.CurrentMag = math.min(mx, (state.CurrentMag or 0) + back) end
    end
    state.IsReloading = false
    s.ZLastShot = now
    return true
end
-- after the round is counted: full heat -> the lockout starts
function ZS.AfterPull(player: Player, state: any)
    if not Furnace(state) then return end
    if (state.CurrentMag or 0) <= 0 then
        (state :: any).ZLockUntil = os.clock() + ZT.FurnaceHeart.Lock
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "OVERHEATED", Color3.fromRGB(255, 120, 60))
    end
end
function ZS.CanReload(state: any): boolean
    return not Furnace(state)
end

-- ===== LONG PROMISE: PierceShot's rule (every enemy in the line, no falloff, +Grow per enemy passed) =====
function ZS.Pierce(stats: any, pr: any): any
    if not (stats.Zenith and stats.Zenith.LongPromise) then return pr end
    local L = ZT.LongPromise
    return { Targets = L.Cap, Falloff = 1, Grow = L.Grow, Cap = L.Cap }
end

-- ===== DAMAGE TAKEN: Lattice +15% while firing, Unbroken Thread +15% for 2 s after a miss =====
function ZS.TakenMult(state: any, stats: any): number
    local z = stats and stats.Zenith
    if not z then return 1 end
    local m, now = 1, os.clock()
    if z.Lattice and now - ((state :: any).P_ShotAt or -99) <= ZT.Lattice.Firing then m *= ZT.Lattice.Taken end
    if z.UnbrokenThread and now < ((state :: any).ZT_FrayUntil or 0) then m *= ZT.UnbrokenThread.Taken end
    return m
end

-- ===== UNBROKEN THREAD (gloves): +4% damage a hit in a row, a miss clears it all + 2 s of +15% damage taken =====
-- A PULL = one trigger pull (the hit remote's consumesAmmo report: a shotgun's pellets and a burst's rounds are one pull). It lands
-- if any of its reports hits an enemy (ThreadHit) or a neutral target (ThreadKeep: a boss's shield orb, an enemy's shell); a pull
-- that landed nothing is a MISS -- found at the next pull or Grace s later, whichever is first. Beams pull 10x a second: a stack per
-- BeamEvery s of continuous on-target beam instead (a tick off target is still a miss). HUD: Player attrs ZenThread (stacks) +
-- ZenFray (server time the debuff ends) -> ZenithClient's counter beside the ammo.
local function ThreadOn(state: any): boolean
    local z = ItemData.ZenithActive(nil, state.EquippedGear)
    return z ~= nil and z.UnbrokenThread == true
end
local function ThreadSet(player: Player, s: any, n: number?)
    if s.ZT_N ~= n then
        s.ZT_N = n
        player:SetAttribute("ZenThread", n)
    end
end
-- DECAY (owner 2026-11-06): Decay s with no hit -> every stack goes (no fray). ZT_LastHit = os.clock() of the last landed pull;
-- Player attr ZenThreadAt = its server time (ZenithClient draws the fade). One watcher a player at most (re-arms itself).
local function DecayWatch(player: Player, s: any)
    if s.ZT_Watch then return end
    s.ZT_Watch = true
    local function Check()
        local left = ZT.UnbrokenThread.Decay - (os.clock() - (s.ZT_LastHit or 0))
        if left > 0.02 then task.delay(left, Check); return end
        s.ZT_Watch = nil
        if (s.ZT_N or 0) > 0 then s.ZT_Acc = 0; ThreadSet(player, s, 0) end
    end
    task.delay(ZT.UnbrokenThread.Decay, Check)
end
local function ThreadTouch(player: Player, s: any)
    s.ZT_LastHit = os.clock()
    player:SetAttribute("ZenThreadAt", workspace:GetServerTimeNow())
    DecayWatch(player, s)
end
local function ThreadMiss(player: Player, s: any)
    local U = ZT.UnbrokenThread
    s.ZT_Acc = 0
    s.ZT_Misses = (s.ZT_Misses or 0) + 1
    s.ZT_FrayUntil = os.clock() + U.Fray
    player:SetAttribute("ZenFray", workspace:GetServerTimeNow() + U.Fray)
    ThreadSet(player, s, 0)
end
local function IsBeam(w: any): boolean
    if type(w) ~= "table" then return false end
    local b = ItemData.BaseWeapons[w.BaseId or ""]
    return w.IsContinuousBeam == true or (b ~= nil and b.IsContinuousBeam == true)
end
function ZS.ThreadPull(player: Player, state: any)
    local s = state :: any
    if not ThreadOn(state) then
        if s.ZT_N ~= nil then ThreadSet(player, s, nil); s.ZT_Pull = nil end -- (the gloves came off: the counter goes)
        return
    end
    if s.ZT_Pull and not s.ZT_Hit then s.ZT_Pull = nil; ThreadMiss(player, s) end -- (the last pull landed nothing)
    s.ZT_PullN = (s.ZT_PullN or 0) + 1
    local id = s.ZT_PullN
    s.ZT_Pull, s.ZT_Hit = id, false
    if s.ZT_N == nil then ThreadSet(player, s, 0) end
    task.delay(ZT.UnbrokenThread.Grace, function()
        if s.ZT_Pull == id and not s.ZT_Hit then s.ZT_Pull = nil; ThreadMiss(player, s) end
    end)
end
-- an enemy hit: returns the damage multiplier (the stacks BEFORE this pull's), adds the pull's stack once
function ZS.ThreadHit(player: Player, state: any, weapon: any): number
    local s = state :: any
    local U = ZT.UnbrokenThread
    if (s.ZT_N or 0) > 0 and os.clock() - (s.ZT_LastHit or 0) > U.Decay then s.ZT_Acc = 0; ThreadSet(player, s, 0) end -- (faded)
    local mult = 1 + U.Per * (s.ZT_N or 0)
    if s.ZT_Pull and not s.ZT_Hit then
        s.ZT_Hit = true
        ThreadTouch(player, s)
        local n = s.ZT_N or 0
        if IsBeam(weapon) then
            local now = os.clock()
            local gap = now - (s.ZT_BeamAt or -99)
            s.ZT_BeamAt = now
            s.ZT_Acc = (s.ZT_Acc or 0) + math.min(gap, 0.15) -- (a fresh beam counts one tick, not the pause before it)
            while s.ZT_Acc >= U.BeamEvery do s.ZT_Acc -= U.BeamEvery; n += 1 end
        else
            n += 1
        end
        ThreadSet(player, s, math.min(U.Max, n))
    end
    return mult
end
-- a neutral target (a boss's shield orb / an enemy's shell): the pull counts as landed, no stack (it still holds off the decay)
function ZS.ThreadKeep(state: any, player: Player?)
    local s = state :: any
    if s.ZT_Pull and not s.ZT_Hit then
        s.ZT_Hit = true
        if player and (s.ZT_N or 0) > 0 then ThreadTouch(player, s) end
    end
end
-- a floor / run starts (DungeonRuns solo floors + revisits, PartyRuns floors, the run's end): every stack, the pending pull and
-- the fray go -- the hub's dummy can't pre-build a full thread (owner 2026-11-06)
function ZS.ThreadClear(player: Player, state: any)
    local s = state :: any
    if not s then return end
    s.ZT_Pull, s.ZT_Hit, s.ZT_Acc, s.ZT_FrayUntil, s.ZT_LastHit = nil, nil, 0, nil, nil
    player:SetAttribute("ZenFray", nil)
    player:SetAttribute("ZenThreadAt", nil)
    ThreadSet(player, s, ThreadOn(state) and 0 or nil)
end

-- ===== AFTER A HIT (CombatServer hit remote, after ShotModFx) =====
-- damage = the hit as dealt (weak spot, crit and the target's resists in it); rm = the target's resist share; realWeak = a real
-- head hit (Point of Aim's "every hit is a weak spot" doesn't count: these reward real aim)
local fxAt = setmetatable({}, { __mode = "k" })
local function Draw(player: Player): boolean
    local now = os.clock()
    if now - (fxAt[player] or 0) < 0.1 then return false end
    fxAt[player] = now
    return true
end
local COL = { Ricochet = Color3.fromRGB(255, 214, 110), Bloom = Color3.fromRGB(255, 150, 60), Lattice = Color3.fromRGB(110, 215, 255) }
-- the mechanic's lines / burst ring (ZenithClient.Fx: a pooled, capped effect) -- to the player and their party on the same floor
local function Fx(player: Player, sub: string, a: Vector3, b: any, color: Color3)
    local ev = Remotes.GetEvent("CombatFx")
    local run = player:GetAttribute("RunId")
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl == player or (run ~= nil and run ~= "" and pl:GetAttribute("RunId") == run) then ev:FireClient(pl, "ZenFx", sub, a, b, color) end
    end
end

local function Bloom(player: Player, state: any, stats: any, corpse: Instance, at: Vector3, perPellet: number, frags: number, depth: number)
    local B = ZT.Bloomshot
    if frags <= 0 or depth > B.Depth then return end
    local targets = D.Nearest(at, B.R, corpse, player, math.min(frags, 12))
    if #targets == 0 then return end
    local hits = {}
    for i = 1, frags do
        local m = targets[((i - 1) % #targets) + 1]
        hits[m] = (hits[m] or 0) + 1
    end
    local shares = stats.DamageShares or { Kinetic = 1 }
    local drawn = 0
    for _, m in ipairs(targets) do
        local n = hits[m] or 0
        if n > 0 and m.Parent and not m:GetAttribute("Dead") then
            local to = D.RootPos(m)
            if to and drawn < 6 then Fx(player, "Line", at, to, COL.Bloom); drawn += 1 end
            local maxHp = m:GetAttribute("MaxHealth") or 0
            local _, k = D.Deal(player, state, m, perPellet * n * D.ResistMult(m, player, shares), stats, { Kind = "Arc", DType = stats.DamageType, Depth = depth })
            if k and to and maxHp > 0 then Bloom(player, state, stats, m, to, perPellet, n, depth + 1) end
        end
    end
end

function ZS.PostHit(player: Player, state: any, stats: any, weapon: any, model: Instance, damage: number, rm: number, hitPos: Vector3,
    isWeak: boolean, realWeak: boolean, isCrit: boolean, killed: boolean, pellets: number, consumesAmmo: boolean)
    local zen = stats.Zenith
    if not zen or model:GetAttribute("IsPracticeDummy") then return end
    rm = (rm and rm > 0) and rm or 1
    local shares = stats.DamageShares or { Kinetic = 1 }
    local s = state :: any
    -- GLASS HALO: a weak-spot kill puts the round back
    if zen.GlassHalo and killed and realWeak and not Furnace(state) then
        state.CurrentMag = math.min(state.MaxMag or 0, (state.CurrentMag or 0) + 1)
    end
    -- FURNACE HEART: weak-spot hits vent heat (Vent rounds a hit, kept as a fraction)
    if zen.FurnaceHeart and realWeak and Furnace(state) and not s.ZLockUntil then
        s.ZVent = (s.ZVent or 0) + ZT.FurnaceHeart.Vent
        if s.ZVent >= 1 then
            local n = math.floor(s.ZVent)
            s.ZVent -= n
            state.CurrentMag = math.min(state.MaxMag or 0, (state.CurrentMag or 0) + n)
        end
    end
    -- SAINT'S RICOCHET: a weak-spot hit jumps to the nearest enemy's weak spot for the full hit, up to 3 jumps
    if zen.SaintsRicochet and realWeak and consumesAmmo then
        local R = ZT.SaintsRicochet
        local base = damage / rm -- (the full weak-spot hit, before this target's resists)
        local done = { [model] = true }
        local from = D.RootPos(model) or hitPos
        local draw = Draw(player)
        for _ = 1, R.Jumps do
            local nxt = nil
            for _, m in ipairs(D.Nearest(from, R.R, nil, player, 8)) do
                if not done[m] then nxt = m; break end
            end
            if not nxt then break end
            done[nxt] = true
            local to = D.RootPos(nxt)
            if draw and to then Fx(player, "Line", from, to, COL.Ricochet) end
            local head = nxt:FindFirstChild("Head")
            D.Deal(player, state, nxt, base * D.ResistMult(nxt, player, shares), stats, { Kind = "Arc", IsWeakSpot = true, IsCrit = isCrit,
                Position = (head and head:IsA("BasePart") and head.Position) or to, DType = stats.DamageType, Depth = 1 })
            s.ZRicochets = (s.ZRicochets or 0) + 1
            from = to or from
        end
    end
    -- BLOOMSHOT: a kill bursts the body -- the killing pellet + the pull's pellets still to land fly on (15 studs)
    if zen.Bloomshot and killed then
        local landed = (pellets > 1) and (s.HR_N or 1) or 1
        local frags = 1 + math.max(0, pellets - landed)
        local per = damage / (rm * (isWeak and (stats.WeakSpotMultiplier or 1) or 1) * (isCrit and (stats.CritMultiplier or 1) or 1))
        local at = D.RootPos(model) or hitPos
        Fx(player, "Ring", at, ZT.Bloomshot.R * 0.6, COL.Bloom) -- (the body bursts)
        Bloom(player, state, stats, model, at, per, frags, 1)
        s.ZBlooms = (s.ZBlooms or 0) + frags
    end
    -- LATTICE: every beam tick forks from its target to up to 4 more enemies within 12 studs at 60% (body damage)
    if zen.Lattice then
        local L = ZT.Lattice
        local from = D.RootPos(model) or hitPos
        local body = damage / (rm * (isWeak and (stats.WeakSpotMultiplier or 1) or 1) * (isCrit and (stats.CritMultiplier or 1) or 1))
        local draw = Draw(player)
        for _, m in ipairs(D.Nearest(from, L.R, model, player, L.N)) do
            local to = D.RootPos(m)
            if draw and to then Fx(player, "Line", from, to, COL.Lattice) end
            D.Deal(player, state, m, body * L.Pct * D.ResistMult(m, player, shares), stats, { Kind = "Arc", DType = stats.DamageType, Depth = 1 })
            s.ZForks = (s.ZForks or 0) + 1
        end
    end
end

-- ===== TWIN GLASS: an exact copy (ForgeReroll mode "Twin") =====
-- atomic: the item is found + checked, the bag room checked, THEN one Twin Glass is spent and the copy goes in -- no yield between
local twinBusy = setmetatable({}, { __mode = "k" })
function ZS.Twin(player: Player, state: any, uid: any, itemType: any): (boolean, string?, any?)
    if twinBusy[player] and os.clock() - twinBusy[player] < 0.3 then return false, "Hold on." end
    twinBusy[player] = os.clock()
    if type(uid) ~= "string" then return false, "That's not an item." end
    -- (REVIEW 2026-11-06) not while a trade / duel wager is open: an offered item is held by Uid and stays in the bag, so a twin
    -- would change it under the other player's READY (they'd receive a twinned item they agreed to as untwinned)
    local svc = script.Parent
    for _, name in ipairs({ "TradeService", "PvpService" }) do
        local m = svc:FindFirstChild(name)
        local okM, mod = pcall(function() return m and require(m) end)
        local busy = okM and type(mod) == "table" and (mod.Busy or mod.InDuel) -- (TradeService.Busy / PvpService.InDuel)
        if busy and busy(player) then
            return false, (name == "TradeService") and "Finish or cancel your trade first." or "Not while a duel is set up."
        end
    end
    local item: any, isGear = nil, itemType == "Gear"
    if isGear then
        for _, g in ipairs(state.GearInventory or {}) do if g.Uid == uid then item = g; break end end
        if not item then for _, g in pairs(state.EquippedGear or {}) do if type(g) == "table" and g.Uid == uid then item = g; break end end end
    else
        for _, w in ipairs(state.Inventory or {}) do if w.Uid == uid then item = w; break end end
        if not item and state.EquippedWeapon and state.EquippedWeapon.Uid == uid then item = state.EquippedWeapon end
    end
    if not item then return false, "That's not an item you hold." end
    if item.Uid == "W_STARTER_PISTOL" then return false, "The starter pistol can't be twinned." end
    local ok, why = ItemData.CanTwin(item)
    if not ok then return false, why end
    state.Materials = state.Materials or ItemData.NewMaterials()
    if (state.Materials.TwinGlass or 0) < 1 then return false, "Needs a Twin Glass." end
    if ItemData.BagRoom(state) <= 0 then return false, "Your bag is full: make room for the copy first (nothing was spent)." end
    state.Materials.TwinGlass -= 1
    local copy = ItemData.TwinCopy(item)
    do -- (REVIEW 2026-11-06) the copy's random Uid must not clash with anything this player holds (bag, worn, stash tabs)
        local held = {}
        local function Note(list: any) for _, it in pairs(type(list) == "table" and list or {}) do if type(it) == "table" and it.Uid then held[it.Uid] = true end end end
        Note(state.Inventory); Note(state.GearInventory); Note(state.EquippedGear)
        if state.EquippedWeapon then held[state.EquippedWeapon.Uid or ""] = true end
        pcall(function()
            for _, box in ipairs(require(game.ReplicatedStorage.AimRngShared.StashTabs).AllBoxes(state)) do Note(box.W); Note(box.G) end
        end)
        while held[copy.Uid] do copy.Uid = string.sub(copy.Uid, 1, 2) .. math.random(10000000, 99999999) end
    end
    if isGear then table.insert(state.GearInventory, copy) else table.insert(state.Inventory, copy) end
    D.Sync(player, state)
    return true, "TWINNED: " .. tostring(item.Name) .. " -- the copy is in your bag (locked). Both are twinned now.", item
end

return ZS
