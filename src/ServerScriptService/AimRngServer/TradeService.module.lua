--!nocheck
-- TradeService (0.55, owner 2026-10-06: "Add trading while I'm gone too, and a trading hub for players").
-- Player-to-player trades of weapons, gear, gold, BOUND points and skins (2026-10-14: Cosmetics.Tradeable pieces), run
-- entirely on the server:
--   1. REQUEST: A asks B (both out of runs, in the city / Bazaar / a hideout, saves loaded; B's Settings
--      AllowTradeRequests must not be false; one request per target every 4 s; a request lives 30 s).
--   2. B ACCEPTS -> a session opens on both screens (one trade per player at a time).
--   3. Each side puts in up to MAX_ITEMS items (never the equipped gun / gear, never the starter pistol) + gold + up to
--      MAX_SKINS skins ("Cat:Id", one entry per copy: Cosmetics.Copies; the other side may own it already -> one more copy;
--      giving your last copy of a worn skin takes it off). Either side may give nothing (a gift).
--      ANY change clears both READY marks and unlocks the trade.
--   4. Both READY -> LOCKED: nothing can change; CONFIRM unlocks after LOCK_SECONDS (time to read the other side).
--   5. Both CONFIRM -> EXECUTE in one step on the server (no yields): re-check that every item is still in its owner's
--      stash and not equipped and the gold is there, move them, sync both players, save both right away.
-- Anything odd (an item sold / equipped meanwhile, a player leaving, starting a run, walking out of the trade areas)
-- drops that item or cancels the trade. Saves are per player and session-locked (SaveService), so a trade can't be
-- replayed from another server.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local Zones = require(Shared:WaitForChild("Zones"))
local SaveService = require(script.Parent:WaitForChild("SaveService"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))

local TradeService = {}
TradeService.MAX_ITEMS = 8
TradeService.MAX_SKINS = 8
TradeService.LOCK_SECONDS = 3
TradeService.REQUEST_LIFE = 30
TradeService.REQUEST_GAP = 4
TradeService.MAX_GOLD = 1e15

local Combat = nil -- CombatServer (Init)
local sessions = {} -- [party] = session (party = a Player, or the Studio test bot table)
local requests = {} -- [target Player] = { [from Player] = os.clock() }
local lastAsk = {} -- [from Player] = { [target Player] = os.clock() }
local nextId = 0

-- ===== who is who (a Player, or the Studio TRADE BOT: { IsBot = true, Name, UserId, State }) =====
local function StateOf(p: any): any
    if type(p) == "table" and p.IsBot then return p.State end
    return Combat and Combat.GetState(p)
end
local function NameOf(p: any): string
    if type(p) == "table" then return p.Name end
    return p.DisplayName ~= "" and p.DisplayName or p.Name
end
local function IdOf(p: any): number return p.UserId end
local function Fire(p: any, ...)
    if type(p) == "table" and p.IsBot then return end
    if p.Parent then Remotes.GetEvent("TradeUpdate"):FireClient(p, ...) end
end
local function Sync(p: any)
    if type(p) == "table" and p.IsBot then return end
    local st = StateOf(p)
    if st then
        pcall(function() Combat.RecalculateMaxHealth(st) end)
        Remotes.GetEvent("SyncPlayerState"):FireClient(p, st)
    end
end
local function Save(p: any)
    if type(p) == "table" and p.IsBot then return end
    task.spawn(function() SaveService.Save(p, StateOf(p), false) end)
end

-- can this player trade right now? -> ok, why
local function CanTrade(p: any): (boolean, string?)
    if type(p) == "table" and p.IsBot then return true end
    if not p or not p.Parent then return false, "That player left." end
    if not SaveService.IsReady(p) then return false, "Still loading." end
    if not StateOf(p) then return false, "Still loading." end
    if p:GetAttribute("RunId") or p:GetAttribute("Downed") or p:GetAttribute("Spectating") then return false, NameOf(p) .. " is in a run." end
    local char = p.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false, NameOf(p) .. " isn't spawned." end
    local kind = Zones.Kind(root.Position)
    if kind == "dungeon" or kind == "pvp" then return false, NameOf(p) .. " is busy." end
    return true
end

-- ===== items =====
-- the list a kind lives in (UPDATE 7: "Riftmod" = state.Riftmods)
local function ListOf(st: any, kind: string): { any }
    if kind == "Riftmod" then st.Riftmods = type(st.Riftmods) == "table" and st.Riftmods or {}; return st.Riftmods end
    if kind == "ShotMod" then st.ShotMods = type(st.ShotMods) == "table" and st.ShotMods or {}; return st.ShotMods end -- (UPDATE 8 phase 3)
    if kind == "Weapon" then st.Inventory = st.Inventory or {}; return st.Inventory end
    st.GearInventory = st.GearInventory or {}
    return st.GearInventory
end
local function FindItem(st: any, kind: string, uid: string): (any, number?)
    local list = ListOf(st, kind)
    for i, it in ipairs(list or {}) do
        if it.Uid == uid then return it, i end
    end
    return nil
end
local function IsEquipped(st: any, kind: string, uid: string): boolean
    if kind == "Weapon" then return st.EquippedWeapon ~= nil and st.EquippedWeapon.Uid == uid end
    for _, g in pairs(st.EquippedGear or {}) do
        if type(g) == "table" and g.Uid == uid then return true end
    end
    return false
end
-- why this item can't go into a trade (nil = it can)
local function ItemProblem(st: any, kind: string, uid: string): string?
    if kind ~= "Weapon" and kind ~= "Gear" and kind ~= "Riftmod" and kind ~= "ShotMod" then return "Only guns, gear, mods and Gunwrights can be traded." end
    if type(uid) ~= "string" then return "Unknown item." end
    local it = FindItem(st, kind, uid)
    if not it then return "That item isn't in your stash." end
    if IsEquipped(st, kind, uid) then return "Take it off first: equipped items can't be traded." end
    if uid == "W_STARTER_PISTOL" then return "The starter pistol can't be traded." end
    return nil
end

-- ===== skins (Cosmetics.TRADE_CATS) =====
local function SkinOf(ref: any): any
    if type(ref) ~= "string" then return nil end
    local cat, id = string.match(ref, "^(%w+):(.+)$")
    return cat and Cosmetics.Find(cat, id) or nil
end
local function CountOf(list: { string }, ref: string): number
    local n = 0
    for _, r in ipairs(list) do if r == ref then n += 1 end end
    return n
end
-- why n copies of this skin can't go into a trade (nil = they can)
local function SkinProblem(st: any, ref: any, n: number?): string?
    local e = SkinOf(ref)
    if not e then return "Unknown skin." end
    if not Cosmetics.Tradeable(e) then return e.Name .. " can't be traded." end
    local have = Cosmetics.Copies(st, e)
    if have == 0 then return "You don't own " .. e.Name .. "." end
    if (n or 1) > have then return "You only have " .. have .. " " .. e.Name .. (have == 1 and "." or " copies.") end
    return nil
end

-- ===== the session =====
local function Other(s: any, p: any): any return (s.A == p) and s.B or s.A end

-- what each side sees: both offers in full (so the other side's items get real tooltips), ready / confirm marks, the
-- phase and how long until CONFIRM opens
local function Snapshot(s: any, viewer: any): any
    local function Side(p: any)
        local st = StateOf(p) or {}
        local items = {}
        for _, e in ipairs(s.Offer[p].Items) do
            local it = FindItem(st, e.Kind, e.Uid)
            if it then table.insert(items, { Kind = e.Kind, Item = it }) end
        end
        local to = StateOf(Other(s, p)) or {}
        local skins = {}
        for _, ref in ipairs(s.Offer[p].Skins) do
            local e = SkinOf(ref)
            if e then
                local cat = Cosmetics.CategoryById[e.Cat]
                table.insert(skins, { Ref = ref, Name = e.Name, Rarity = e.Rarity, Cat = cat and cat.Label or e.Cat, TheyHave = Cosmetics.Copies(to, e) })
            end
        end
        return { Name = NameOf(p), UserId = IdOf(p), Items = items, Skins = skins, Gold = s.Offer[p].Gold, BP = s.Offer[p].BP or 0, Ready = s.Ready[p] == true,
            Confirm = s.Confirm[p] == true }
    end
    local other = Other(s, viewer)
    return {
        Id = s.Id, Phase = s.Phase, Me = Side(viewer), Them = Side(other),
        ConfirmIn = (s.Phase == "Locked") and math.max(0, TradeService.LOCK_SECONDS - (os.clock() - s.LockAt)) or nil,
        Max = TradeService.MAX_ITEMS, MaxSkins = TradeService.MAX_SKINS,
    }
end
local function Push(s: any)
    Fire(s.A, "Session", Snapshot(s, s.A))
    Fire(s.B, "Session", Snapshot(s, s.B))
end
local function Unready(s: any)
    s.Ready = {}
    s.Confirm = {}
    s.Phase = "Edit"
    s.LockAt = nil
end
local function Close(s: any, why: string?)
    if sessions[s.A] == s then sessions[s.A] = nil end
    if sessions[s.B] == s then sessions[s.B] = nil end
    s.Closed = true
    Fire(s.A, "Closed", why or "Trade cancelled.")
    Fire(s.B, "Closed", why or "Trade cancelled.")
end
TradeService.Close = Close
-- (REVIEW 2026-11-06) an open trade session (ZenithServer.Twin refuses while one is open: offered items stay in the bag by Uid)
function TradeService.Busy(p: any): boolean
    local s = sessions[p]
    return s ~= nil and not s.Closed
end
-- (owner 2026-11-06) is this item / mod (by Uid) in p's offer of an open trade? CombatServer.TradeHold refuses every craft on it
function TradeService.Offered(p: any, uid: any): boolean
    local s = sessions[p]
    if not s or s.Closed or type(uid) ~= "string" then return false end
    for _, e in ipairs((s.Offer[p] or {}).Items or {}) do if e.Uid == uid then return true end end
    return false
end

local function Open(a: any, b: any): any
    nextId += 1
    local s = { Id = nextId, A = a, B = b, Offer = { [a] = { Items = {}, Skins = {}, Gold = 0, BP = 0 }, [b] = { Items = {}, Skins = {}, Gold = 0, BP = 0 } },
        Ready = {}, Confirm = {}, Phase = "Edit", Started = os.clock() }
    sessions[a], sessions[b] = s, s
    Push(s)
    return s
end
TradeService.Open = Open

-- drop offered items that are gone / equipped now, and gold the player no longer has (true = something changed)
local function Revalidate(s: any): boolean
    local changed = false
    for _, p in ipairs({ s.A, s.B }) do
        local st = StateOf(p)
        if not st then return true end
        local keep = {}
        for _, e in ipairs(s.Offer[p].Items) do
            if ItemProblem(st, e.Kind, e.Uid) then changed = true else table.insert(keep, e) end
        end
        s.Offer[p].Items = keep
        local keepS = {}
        for _, ref in ipairs(s.Offer[p].Skins) do
            if SkinProblem(st, ref, CountOf(keepS, ref) + 1) then changed = true else table.insert(keepS, ref) end
        end
        s.Offer[p].Skins = keepS
        if s.Offer[p].Gold > (st.Gold or 0) then s.Offer[p].Gold = math.max(0, math.floor(st.Gold or 0)); changed = true end
        if (s.Offer[p].BP or 0) > math.floor(tonumber(st.BoundPoints) or 0) then s.Offer[p].BP = math.max(0, math.floor(tonumber(st.BoundPoints) or 0)); changed = true end
    end
    if changed then Unready(s) end
    return changed
end

-- THE SWAP. No yields between the checks and the moves.
local function Execute(s: any): (boolean, string?)
    local sa, sb = StateOf(s.A), StateOf(s.B)
    if not (sa and sb) then return false, "A player left." end
    for _, p in ipairs({ s.A, s.B }) do
        local st = StateOf(p)
        for _, e in ipairs(s.Offer[p].Items) do
            local why = ItemProblem(st, e.Kind, e.Uid)
            if why then return false, NameOf(p) .. ": " .. why end
        end
        if s.Offer[p].Gold > (st.Gold or 0) then return false, NameOf(p) .. " doesn't have that much gold any more." end
        if (s.Offer[p].BP or 0) > math.floor(tonumber(st.BoundPoints) or 0) then return false, NameOf(p) .. " doesn't have that many BOUND points any more." end
        for _, ref in ipairs(s.Offer[p].Skins) do
            local why = SkinProblem(st, ref, CountOf(s.Offer[p].Skins, ref))
            if why then return false, NameOf(p) .. ": " .. why end
        end
        -- (the bag cap: what comes in minus what goes out must fit; Riftmods and shot mods have their own bags)
        local function N(list, kind) local n = 0 for _, e in ipairs(list) do if (kind == nil and e.Kind ~= "Riftmod" and e.Kind ~= "ShotMod") or e.Kind == kind then n += 1 end end return n end
        local incoming = N(s.Offer[Other(s, p)].Items, nil) - N(s.Offer[p].Items, nil)
        if incoming > 0 and ItemData.BagRoom(st) < incoming then return false, NameOf(p) .. "'s bag is full." end
        local inMods = N(s.Offer[Other(s, p)].Items, "Riftmod") - N(s.Offer[p].Items, "Riftmod")
        if inMods > 0 and #ListOf(st, "Riftmod") + inMods > require(game.ReplicatedStorage.AimRngShared.Riftmods).BAG then return false, NameOf(p) .. "'s Gunwright bag is full." end
        local inShot = N(s.Offer[Other(s, p)].Items, "ShotMod") - N(s.Offer[p].Items, "ShotMod")
        if inShot > 0 and #ListOf(st, "ShotMod") + inShot > require(game.ReplicatedStorage.AimRngShared.ShotMods).BAG then return false, NameOf(p) .. "'s mod bag is full." end
    end
    -- take everything out first, then hand it over (an item can't end up in both stashes)
    local moving = {}
    for _, p in ipairs({ s.A, s.B }) do
        local st = StateOf(p)
        moving[p] = {}
        for _, e in ipairs(s.Offer[p].Items) do
            local it, idx = FindItem(st, e.Kind, e.Uid)
            local list = ListOf(st, e.Kind)
            table.remove(list, idx)
            table.insert(moving[p], { Kind = e.Kind, Item = it })
        end
        for _, ref in ipairs(s.Offer[p].Skins) do Cosmetics.TakeCopy(st, SkinOf(ref)) end
        st.Gold = (st.Gold or 0) - s.Offer[p].Gold
        st.BoundPoints = math.floor(tonumber(st.BoundPoints) or 0) - (s.Offer[p].BP or 0)
        if not (type(p) == "table" and p.IsBot) then p:SetAttribute("BoundPoints", st.BoundPoints) end -- (the Studio trade bot is a table)
    end
    local summary = {}
    for _, p in ipairs({ s.A, s.B }) do
        local to = Other(s, p)
        local st = StateOf(to)
        st.Inventory = st.Inventory or {}
        st.GearInventory = st.GearInventory or {}
        for _, m in ipairs(moving[p]) do
            local it = m.Item
            -- (Uids are random: re-roll one that would clash in the new stash)
            if FindItem(st, m.Kind, it.Uid) then it.Uid = ((m.Kind == "Weapon") and "W_" or (m.Kind == "Riftmod") and "R_" or (m.Kind == "ShotMod") and "SM_" or "G_") .. math.random(10000000, 99999999) end
            it.RunLoot = nil
            table.insert(ListOf(st, m.Kind), it)
            table.insert(summary, NameOf(p) .. " -> " .. NameOf(to) .. ": " .. tostring(it.Rarity) .. " " .. tostring(it.Name) .. " [" .. tostring(it.Uid) .. "]")
        end
        for _, ref in ipairs(s.Offer[p].Skins) do
            Cosmetics.AddCopy(st, SkinOf(ref))
            table.insert(summary, NameOf(p) .. " -> " .. NameOf(to) .. ": skin " .. ref)
        end
        st.Gold = (st.Gold or 0) + s.Offer[p].Gold
        if (s.Offer[p].BP or 0) > 0 then
            st.BoundPoints = math.floor(tonumber(st.BoundPoints) or 0) + s.Offer[p].BP
            if not (type(to) == "table" and to.IsBot) then to:SetAttribute("BoundPoints", st.BoundPoints) end
            table.insert(summary, NameOf(p) .. " -> " .. NameOf(to) .. ": " .. s.Offer[p].BP .. " BOUND points")
        end
        if s.Offer[p].Gold > 0 then table.insert(summary, NameOf(p) .. " -> " .. NameOf(to) .. ": " .. ItemData.FormatNumber(s.Offer[p].Gold) .. " gold") end
    end
    print("[Trade] #" .. s.Id .. " done: " .. (#summary > 0 and table.concat(summary, "; ") or "nothing"))
    if #s.Offer[s.A].Skins + #s.Offer[s.B].Skins > 0 and Combat.SyncBarStyle then -- (worn looks other players read from attrs)
        for _, p in ipairs({ s.A, s.B }) do
            if not (type(p) == "table" and p.IsBot) then pcall(Combat.SyncBarStyle, p, StateOf(p)) end
        end
    end
    Sync(s.A); Sync(s.B)
    Save(s.A); Save(s.B)
    return true
end

-- ===== actions (RemoteFunction TradeAction) =====
local function Act(player: any, action: string, a: any, b: any, c: any): (boolean, string?)
    if action == "Request" then
        local target = Players:GetPlayerByUserId(tonumber(a) or 0)
        if not target or target == player then return false, "Pick another player." end
        local ok, why = CanTrade(player); if not ok then return false, why end
        ok, why = CanTrade(target); if not ok then return false, why end
        if sessions[player] then return false, "Finish your current trade first." end
        if sessions[target] then return false, NameOf(target) .. " is already trading." end
        local tst = StateOf(target)
        if tst and tst.Settings and tst.Settings.AllowTradeRequests == false then return false, NameOf(target) .. " isn't taking trade requests." end
        lastAsk[player] = lastAsk[player] or {}
        if os.clock() - (lastAsk[player][target] or -99) < TradeService.REQUEST_GAP then return false, "Wait a moment before asking again." end
        lastAsk[player][target] = os.clock()
        -- they asked you too: that's a yes
        if requests[player] and requests[player][target] and os.clock() - requests[player][target] < TradeService.REQUEST_LIFE then
            requests[player][target] = nil
            Open(target, player)
            return true, "Trade opened."
        end
        requests[target] = requests[target] or {}
        requests[target][player] = os.clock()
        Fire(target, "Request", { From = NameOf(player), FromId = player.UserId, Life = TradeService.REQUEST_LIFE })
        return true, "Trade request sent to " .. NameOf(target) .. "."
    elseif action == "Respond" then
        local from = Players:GetPlayerByUserId(tonumber(a) or 0)
        local list = requests[player]
        local at = from and list and list[from]
        if list and from then list[from] = nil end
        if not at or os.clock() - at > TradeService.REQUEST_LIFE then return false, "That request expired." end
        if b ~= true then Fire(from, "Declined", NameOf(player)); return true end
        local ok, why = CanTrade(player); if not ok then return false, why end
        ok, why = CanTrade(from); if not ok then return false, why end
        if sessions[player] or sessions[from] then return false, "One of you is already trading." end
        Open(from, player)
        return true
    end
    local s = sessions[player]
    if not s or s.Closed then return false, "You're not trading." end
    if action == "Cancel" then
        Close(s, NameOf(player) .. " cancelled the trade.")
        return true
    elseif action == "SetItem" then
        -- (0.62: a change in the LOCKED phase reopens the trade -- both un-ready -- instead of being refused)
        local kind, uid, on = a, b, c == true
        local mine = s.Offer[player].Items
        local at = nil
        for i, e in ipairs(mine) do if e.Kind == kind and e.Uid == uid then at = i end end
        if on then
            if at then return true end
            if #mine >= TradeService.MAX_ITEMS then return false, "Up to " .. TradeService.MAX_ITEMS .. " items per trade." end
            local why = ItemProblem(StateOf(player), kind, uid)
            if why then return false, why end
            table.insert(mine, { Kind = kind, Uid = uid })
        elseif at then
            table.remove(mine, at)
        end
        Unready(s)
        Push(s)
        return true
    elseif action == "SetSkin" then -- (on = one more copy in the offer, off = one copy out)
        local ref, on = a, b == true
        local mine = s.Offer[player].Skins
        local at = type(ref) == "string" and table.find(mine, ref) or nil
        if on then
            if #mine >= TradeService.MAX_SKINS then return false, "Up to " .. TradeService.MAX_SKINS .. " skins per trade." end
            local why = SkinProblem(StateOf(player), ref, CountOf(mine, ref) + 1)
            if why then return false, why end
            table.insert(mine, ref)
        elseif at then
            table.remove(mine, at)
        end
        Unready(s)
        Push(s)
        return true
    elseif action == "SetBP" then
        local n = math.floor(tonumber(a) or 0)
        if n ~= n or n < 0 then n = 0 end
        n = math.min(n, math.floor(tonumber(StateOf(player).BoundPoints) or 0), 1000000)
        s.Offer[player].BP = n
        Unready(s)
        Push(s)
        return true
    elseif action == "SetGold" then
        local n = math.floor(tonumber(a) or 0)
        if n ~= n or n < 0 then n = 0 end
        n = math.min(n, math.floor(StateOf(player).Gold or 0), TradeService.MAX_GOLD)
        s.Offer[player].Gold = n
        Unready(s)
        Push(s)
        return true
    elseif action == "Ready" then
        if a == false then Unready(s); Push(s); return true end
        if Revalidate(s) then Push(s); return false, "Something in the trade changed: check it again." end
        s.Ready[player] = true
        if s.Ready[s.A] and s.Ready[s.B] then
            s.Phase = "Locked"
            s.LockAt = os.clock()
        end
        Push(s)
        return true
    elseif action == "Confirm" then
        if s.Phase ~= "Locked" then return false, "Both of you need to be ready." end
        if os.clock() - s.LockAt < TradeService.LOCK_SECONDS - 0.05 then return false, "Read the trade first." end
        s.Confirm[player] = true
        if s.Confirm[s.A] and s.Confirm[s.B] then
            local ok, why = Execute(s)
            if ok then
                Fire(s.A, "Done", NameOf(s.B)); Fire(s.B, "Done", NameOf(s.A))
                if sessions[s.A] == s then sessions[s.A] = nil end
                if sessions[s.B] == s then sessions[s.B] = nil end
                s.Closed = true
            else
                Unready(s)
                Push(s)
                return false, why
            end
            return true
        end
        Push(s)
        return true
    end
    return false, "Unknown trade action."
end
TradeService.Act = Act

-- ===== Studio TRADE BOT (DevCommands "tradebot"): a fake partner so one person can test the whole flow =====
function TradeService.DevBot(player: Player, cmd: string, a: any): string
    if not RunService:IsStudio() then return "studio only" end
    local s = sessions[player]
    local bot = s and type(Other(s, player)) == "table" and Other(s, player) or nil
    if cmd == "start" then
        if s then Close(s, "restart") end
        local st = { Inventory = {}, GearInventory = {}, Gold = 5000, EquippedGear = {}, Settings = {}, CosmeticsOwned = {}, CosmeticsEquipped = {} }
        for i, r in ipairs({ "Rare", "Rare", "Mythic" }) do -- (RARITY v4)
            local w = ItemData.GenerateWeaponOfBase(({ "AK47", "AWP", "M249" })[i], r, 1)
            if w then table.insert(st.Inventory, w) end
        end
        local g = ItemData.GenerateRandomGear("Helmet", "Rare", nil, 1)
        if g then table.insert(st.GearInventory, g) end
        bot = { IsBot = true, Name = "TradeBot", UserId = -1, State = st }
        Open(player, bot)
        return "bot trade open: bot has " .. #st.Inventory .. " guns, " .. #st.GearInventory .. " gear, 5000 gold"
    end
    if not (s and bot) then return "no bot trade (tradebot start)" end
    if cmd == "offer" then
        local n = tonumber(a) or 1
        for i = 1, n do
            local w = bot.State.Inventory[i]
            if w then Act(bot, "SetItem", "Weapon", w.Uid, true) end
        end
        Act(bot, "SetGold", 1234)
        return "bot offered " .. n .. " gun(s) + 1234 gold"
    elseif cmd == "skin" then -- (a = "Cat:Id": the bot gets it and offers it)
        local e = SkinOf(a)
        if not e then return "unknown skin " .. tostring(a) end
        Cosmetics.AddCopy(bot.State, e)
        local ok, why = Act(bot, "SetSkin", a, true)
        return "bot offered skin " .. tostring(a) .. ": " .. tostring(ok) .. " " .. tostring(why)
    elseif cmd == "riftmod" then -- (UPDATE 7: the bot gets an AK-47 Riftmod and offers it)
        local m = require(game.ReplicatedStorage.AimRngShared.Riftmods).New("AK47", 60)
        table.insert(ListOf(bot.State, "Riftmod"), m)
        local ok, why = Act(bot, "SetItem", "Riftmod", m.Uid, true)
        return "bot offered " .. m.Name .. ": " .. tostring(ok) .. " " .. tostring(why)
    elseif cmd == "me" then -- (UPDATE 7: your side: "offermod" = your first Riftmod / "ready" / "confirm")
        local st = StateOf(player)
        local uid = type(st.Riftmods) == "table" and st.Riftmods[1] and st.Riftmods[1].Uid
        local ok, why
        if a == "offermod" then ok, why = Act(player, "SetItem", "Riftmod", uid, true)
        elseif type(a) == "string" and string.sub(a, 1, 6) == "offer:" then -- ("offer:<uid>": your gun / gear piece by Uid)
            local u = string.sub(a, 7)
            local kind = string.sub(u, 1, 2) == "G_" and "Gear" or "Weapon"
            ok, why = Act(player, "SetItem", kind, u, true)
        elseif a == "ready" then ok, why = Act(player, "Ready", true)
        elseif a == "confirm" then ok, why = Act(player, "Confirm") end
        return "me " .. tostring(a) .. ": " .. tostring(ok) .. " " .. tostring(why)
    elseif cmd == "ready" then
        local ok, why = Act(bot, "Ready", true); return "bot ready: " .. tostring(ok) .. " " .. tostring(why)
    elseif cmd == "confirm" then
        local ok, why = Act(bot, "Confirm"); return "bot confirm: " .. tostring(ok) .. " " .. tostring(why)
    elseif cmd == "state" then
        local names = {}
        for _, w in ipairs(bot.State.Inventory) do table.insert(names, w.Name) end
        for _, g in ipairs(bot.State.GearInventory) do table.insert(names, g.Name) end
        local skins = {}
        for _, cat in ipairs(Cosmetics.TRADE_CATS) do
            for _, e in ipairs(Cosmetics.List(cat)) do
                local n = Cosmetics.Tradeable(e) and Cosmetics.Copies(bot.State, e) or 0
                if n > 0 then table.insert(skins, cat .. ":" .. e.Id .. (n > 1 and (" x" .. n) or "")) end
            end
        end
        return string.format("bot gold %d, items: %s | skins: %s | phase %s", bot.State.Gold, table.concat(names, ", "), table.concat(skins, ", "), s.Phase)
    end
    return "tradebot start | offer n | skin Cat:Id | ready | confirm | state"
end

function TradeService.Init(combat: any)
    Combat = combat
    Remotes.GetFunction("TradeAction").OnServerInvoke = function(player: Player, action: any, a: any, b: any, c: any)
        if type(action) ~= "string" then return false, "?" end
        local ok, r1, r2 = pcall(Act, player, action, a, b, c)
        if not ok then warn("[Trade] " .. tostring(r1)); return false, "Trade error." end
        return r1, r2
    end
    Players.PlayerRemoving:Connect(function(p)
        local s = sessions[p]
        if s then Close(s, NameOf(p) .. " left.") end
        requests[p] = nil
        lastAsk[p] = nil
        for _, list in pairs(requests) do list[p] = nil end
    end)
    -- watchdog: a player who starts a run / goes down / leaves the trade areas ends the trade; offers stay valid
    task.spawn(function()
        while true do
            task.wait(1)
            local seen = {}
            for _, s in pairs(sessions) do
                if not seen[s] and not s.Closed then
                    seen[s] = true
                    local okA, whyA = CanTrade(s.A)
                    local okB, whyB = CanTrade(s.B)
                    if not okA or not okB then
                        Close(s, whyA or whyB)
                    elseif s.Phase == "Edit" and Revalidate(s) then
                        Push(s)
                    elseif s.Phase == "Locked" then
                        Push(s) -- (the CONFIRM countdown)
                    end
                end
            end
        end
    end)
end

return TradeService
