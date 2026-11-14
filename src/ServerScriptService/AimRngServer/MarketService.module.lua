--!nocheck
-- ============================================================================================
-- THE MARKET (UPDATE 7 C7, offline trading the stash-tab way; owner 2026-10-16: market at L30, prices in ANY currency).
-- LIST an item from one of your TRADE stash tabs (or a Riftmod from your bag) at a price in gold / Prism / a crafting currency.
-- The item moves into ESCROW (the listing record) the moment it's listed, so it can't be used, traded or sold twice. Anyone in
-- any server can BROWSE the market and BUY it, even while you're offline: a purchase is ONE atomic claim on the listing
-- (UpdateAsync: Open -> Sold), so only one buyer ever wins. The price minus TAX goes into your PROCEEDS (an atomic counter per
-- seller), which you COLLECT from the market window. CANCEL brings an open listing back to a trade tab.
-- Storage (live): DataStore Market_v1 -- "L_<id>" listing { Id, Seller, SellerName, Kind, Item, Price { Key, N }, At, Status
-- Pending | Open | Sold | Cancelled, Buyer?, BuyerName? }, "S_<userId>" { ids }, "P_<userId>" { [currency] = n }; the browse
-- INDEX = MemoryStore sorted map MarketIndex_v1 (id -> summary, EXPIRES days). Studio: the same calls on in-memory tables.
-- LISTING SAFETY: the record is written Pending, the seller's save is forced, then it's opened; a Pending listing found on the
-- seller's next load (a crash in between) is settled then (Reconcile).
-- Remote MarketAction: Browse(filters) / Mine() / List(tabId, kind, uid, key, n) / Cancel(id) / Buy(id) / Collect().
-- Mastery perks: +2 listings / -2% tax at ranks 13 and 19 (MasteryRank).
-- ============================================================================================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local StashTabs = require(Shared:WaitForChild("StashTabs"))

local MarketService = {}
MarketService.ON = true
MarketService.UNLOCK = 30
MarketService.MAX_LISTINGS = 10
MarketService.TAX = 0.10
MarketService.EXPIRES = 30 * 86400
MarketService.BROWSE_MAX = 60
MarketService.CURRENCIES = { "Gold", "Prism" }
for _, k in ipairs(ItemData.CURRENCY_V5) do table.insert(MarketService.CURRENCIES, k) end
if ItemData.ZenithShown() then for _, k in ipairs(ItemData.ZENITH_MATS or {}) do table.insert(MarketService.CURRENCIES, k) end end -- (CHASE ITEMS: Twin Glass, once live; Studio: workspace DevZenithLive)
MarketService.MEMORY = RunService:IsStudio() -- (Studio: in-memory store + index, like the mock save)

local CombatServer
local busy = {}

-- ===== storage =====
local mem, memIndex = {}, {}
local ds, index = nil, nil
local function DS()
    if not ds then ds = game:GetService("DataStoreService"):GetDataStore("Market_v1" .. (require(script.Parent:WaitForChild("SaveService")).MARKET_SUFFIX or "")) end -- (WIPE 5: per-wipe stores)
    return ds
end
local function Index()
    if not index then index = game:GetService("MemoryStoreService"):GetSortedMap("MarketIndex_v1" .. (require(script.Parent:WaitForChild("SaveService")).MARKET_SUFFIX or "")) end
    return index
end
local function Get(key: string): any
    if MarketService.MEMORY then return mem[key] and HttpService:JSONDecode(mem[key]) or nil end
    local ok, v = pcall(function() return DS():GetAsync(key) end)
    return ok and v or nil
end
-- atomic read-modify-write: fn(old) -> new | nil (nil = leave as is); returns ok, the value written
local function Update(key: string, fn: (any) -> any): (boolean, any)
    if MarketService.MEMORY then
        local old = mem[key] and HttpService:JSONDecode(mem[key]) or nil
        local new = fn(old)
        if new == nil then return false, old end
        mem[key] = HttpService:JSONEncode(new)
        return true, new
    end
    local wrote, out = false, nil
    local ok = pcall(function()
        DS():UpdateAsync(key, function(old)
            local new = fn(old)
            if new == nil then out = old; return nil end
            wrote, out = true, new
            return new
        end)
    end)
    return ok and wrote, out
end
local function IndexSet(id: string, summary: any)
    if MarketService.MEMORY then memIndex[id] = summary; return end
    pcall(function() Index():SetAsync(id, summary, MarketService.EXPIRES) end)
end
local function IndexRemove(id: string)
    if MarketService.MEMORY then memIndex[id] = nil; return end
    pcall(function() Index():RemoveAsync(id) end)
end
local function IndexAll(): { any }
    local out = {}
    if MarketService.MEMORY then
        for _, s in pairs(memIndex) do table.insert(out, s) end
        return out
    end
    local lower = nil
    for _ = 1, 3 do
        local ok, page = pcall(function() return Index():GetRangeAsync(Enum.SortDirection.Descending, 200, nil, lower) end)
        if not ok or not page or #page == 0 then break end
        for _, e in ipairs(page) do table.insert(out, e.value) end
        if #page < 200 then break end
        lower = { key = page[#page].key } -- (the next page starts below the last key)
    end
    return out
end

-- ===== helpers =====
local function MR() return require(Shared:WaitForChild("MasteryRank")) end
function MarketService.MaxListings(state: any): number
    local m = MR()
    return MarketService.MAX_LISTINGS + 2 * ((m.ExtraListingPerks and m.ExtraListingPerks(m.Rank(state))) or 0)
        + ((type(state) == "table" and type(state.GuildPerks) == "table" and state.GuildPerks.Listings) or 0) -- (UPDATE 7 B9: guild research)
end
function MarketService.Tax(state: any): number
    local m = MR()
    return math.max(0.05, MarketService.TAX - 0.02 * ((m.ExtraListingPerks and m.ExtraListingPerks(m.Rank(state))) or 0))
end
local function CurName(key: string): string
    if key == "Gold" then return "gold" end
    local d = ItemData.MaterialDefs[key]
    return d and d.Name or key
end
function MarketService.PriceText(p: any): string
    return ItemData.FormatNumber(p.N) .. " " .. CurName(p.Key)
end
local function LinesText(item: any, kind: string): { string }
    local out = {}
    if kind == "Riftmod" then
        for _, a in ipairs(item.Lines or {}) do table.insert(out, ItemData.FormatStat(a.Stat, a.Value)) end
    elseif kind == "ShotMod" then -- (UPDATE 8 phase 3)
        table.insert(out, require(Shared:WaitForChild("ShotMods")).Describe(item))
    else
        for _, a in ipairs(ItemData.LinesOf(item, kind == "Gear")) do table.insert(out, ItemData.FormatStat(a.Stat, a.Value) .. (a.Tier and (" (T" .. a.Tier .. ")") or "")) end
    end
    return out
end
-- an item's name for messages (a shot mod has none of its own: "Mod: Chain 5")
function MarketService.ItemName(it: any): string
    if type(it) == "table" and it.Kind == "ShotMod" then return "Mod: " .. require(Shared:WaitForChild("ShotMods")).Name(it) end
    return tostring(type(it) == "table" and it.Name or "?")
end
local function Summary(rec: any): any
    local it = rec.Item or {}
    if rec.Kind == "Weapon" or rec.Kind == "Riftmod" then ItemData.FixGunName(it) end -- (GUN NAMES = THE MODEL, 2026-10-24)
    local smName = (rec.Kind == "ShotMod") and require(Shared:WaitForChild("ShotMods")).Name(it) or nil -- (UPDATE 8 phase 3: "Mod: Chain 5")
    return { Id = rec.Id, Kind = rec.Kind, Name = smName and ("Mod: " .. smName) or it.Name or "?", Rarity = it.Rarity or (rec.Kind == "Riftmod" and "Riftmod") or (smName and "Mod") or "Common",
        BaseId = it.BaseId or it.Gun, Slot = it.Slot, ItemLevel = it.ItemLevel, Lines = LinesText(it, rec.Kind), Price = rec.Price,
        Exotic = it.Exotic, Zenith = (ItemData.ZenithOf(it) ~= nil) or nil, -- (CHASE ITEMS: the ZENITH filter + an exact price check)
        Seller = rec.Seller, SellerName = rec.SellerName, At = rec.At, Item = it }
end
local function Sync(player: Player, state: any)
    CombatServer.RecalculateMaxHealth(state)
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
end
local function Save(player: Player, state: any): boolean
    local ok, res = pcall(function() return require(script.Parent:WaitForChild("SaveService")).Save(player, state) end)
    if MarketService.MEMORY then return true end -- (Studio: the mock save)
    return ok and res == true
end
-- put an item back into the first trade tab with room (else the stash / bag)
local function ReturnItem(state: any, kind: string, item: any)
    if kind == "Riftmod" then
        state.Riftmods = type(state.Riftmods) == "table" and state.Riftmods or {}
        table.insert(state.Riftmods, item)
        return
    end
    if kind == "ShotMod" then
        state.ShotMods = type(state.ShotMods) == "table" and state.ShotMods or {}
        table.insert(state.ShotMods, item)
        return
    end
    for _, t in ipairs(StashTabs.List(state)) do
        if t.Kind == "Trade" and t.Box and StashTabs.Count(t.Box) < StashTabs.Cap(state, t.Id) then
            local list = (kind == "Weapon") and t.Box.W or t.Box.G
            table.insert(list, item)
            return
        end
    end
    table.insert((kind == "Weapon") and state.Inventory or state.GearInventory, item)
end

-- ===== actions =====
function MarketService.List(player: Player, tabId: any, kind: any, uid: any, key: any, n: any): (boolean, string?)
    local state = CombatServer.GetState(player)
    if not state then return false, "?" end
    if (state.Level or 1) < MarketService.UNLOCK then return false, "The Exchange opens at level " .. MarketService.UNLOCK .. "." end
    if not table.find(MarketService.CURRENCIES, key) then return false, "Pick a currency." end
    n = math.floor(tonumber(n) or 0)
    if n < 1 or n > 1e12 then return false, "Set a price." end
    if kind ~= "Weapon" and kind ~= "Gear" and kind ~= "Riftmod" and kind ~= "ShotMod" then return false, "Only guns, gear, mods and Gunwrights can be listed." end
    local seller = Get("S_" .. player.UserId) or { Ids = {} }
    local open = 0
    for _, id in ipairs(seller.Ids or {}) do
        local r = Get("L_" .. id)
        if r and (r.Status == "Open" or r.Status == "Pending") then open += 1 end
    end
    if open >= MarketService.MaxListings(state) then return false, "You have " .. open .. " listings (the most you can)." end
    -- find + check the item
    local list, idx
    if kind == "Riftmod" or kind == "ShotMod" then
        list = (kind == "Riftmod") and (type(state.Riftmods) == "table" and state.Riftmods or {}) or (type(state.ShotMods) == "table" and state.ShotMods or {})
        for i, it in ipairs(list) do if it.Uid == uid then idx = i end end
    else
        local box = StashTabs.Box(state, tabId)
        local tab
        for _, t in ipairs(StashTabs.List(state)) do if t.Id == tabId then tab = t end end
        if not box or not tab or tab.Kind ~= "Trade" then return false, "List items from a TRADE tab." end
        list = (kind == "Weapon") and box.W or box.G
        for i, it in ipairs(list or {}) do if it.Uid == uid then idx = i end end
    end
    if not idx then return false, "That item isn't there any more." end
    local item = list[idx]
    if item.Locked then return false, "Unlock the item first." end
    -- escrow: Pending record -> remove + save -> Open
    local id = HttpService:GenerateGUID(false)
    local rec = { Id = id, Seller = player.UserId, SellerName = player.DisplayName, Kind = kind, Item = item, Price = { Key = key, N = n }, At = os.time(), Status = "Pending" }
    local ok = Update("L_" .. id, function(old) if old then return nil end return rec end)
    if not ok then return false, "The Exchange didn't answer. Try again." end
    table.remove(list, idx)
    if not Save(player, state) then
        table.insert(list, idx, item)
        Update("L_" .. id, function(old) if old then old.Status = "Cancelled"; return old end return nil end)
        return false, "Couldn't save. Try again."
    end
    Update("L_" .. id, function(old) if old and old.Status == "Pending" then old.Status = "Open"; return old end return nil end)
    Update("S_" .. player.UserId, function(old)
        old = type(old) == "table" and old or { Ids = {} }
        old.Ids = type(old.Ids) == "table" and old.Ids or {}
        table.insert(old.Ids, id)
        while #old.Ids > 60 do table.remove(old.Ids, 1) end
        return old
    end)
    rec.Status = "Open"
    IndexSet(id, Summary(rec))
    Sync(player, state)
    return true, "Listed: " .. MarketService.ItemName(item) .. " for " .. MarketService.PriceText(rec.Price) .. "."
end

function MarketService.Cancel(player: Player, id: any): (boolean, string?)
    local state = CombatServer.GetState(player)
    if not state or type(id) ~= "string" then return false, "?" end
    local ok, rec = Update("L_" .. id, function(old)
        if not old or old.Seller ~= player.UserId or old.Status ~= "Open" then return nil end
        old.Status = "Cancelled"
        return old
    end)
    if not ok then return false, (rec and rec.Status == "Sold") and "It already sold: collect your proceeds." or "That listing isn't open." end
    IndexRemove(id)
    ReturnItem(state, rec.Kind, rec.Item)
    Save(player, state)
    Sync(player, state)
    return true, MarketService.ItemName(rec.Item) .. " is back in your trade tab."
end

-- buyerOverride (Studio test bot): a fake buyer id with no state (the item is thrown away, proceeds still paid)
function MarketService.Buy(player: Player?, id: any, botBuyer: number?): (boolean, string?)
    local state = player and CombatServer.GetState(player)
    if type(id) ~= "string" then return false, "?" end
    local rec0 = Get("L_" .. id)
    if not rec0 or rec0.Status ~= "Open" then IndexRemove(id); return false, "Someone else bought it." end
    if state then
        if (state.Level or 1) < MarketService.UNLOCK then return false, "The Exchange opens at level " .. MarketService.UNLOCK .. "." end
        if rec0.Seller == player.UserId then return false, "That's your own listing." end
        local key, n = rec0.Price.Key, rec0.Price.N
        local have = (key == "Gold") and (state.Gold or 0) or ((state.Materials or {})[key] or 0)
        if have < n then return false, "You need " .. MarketService.PriceText(rec0.Price) .. "." end
        if rec0.Kind == "Riftmod" and #(state.Riftmods or {}) >= require(Shared:WaitForChild("Riftmods")).BAG then return false, "Your Gunwright bag is full." end
        if rec0.Kind == "ShotMod" and #(state.ShotMods or {}) >= require(Shared:WaitForChild("ShotMods")).BAG then return false, "Your mod bag is full." end
    end
    local buyerId = state and player.UserId or botBuyer or 0
    local ok, rec = Update("L_" .. id, function(old)
        if not old or old.Status ~= "Open" then return nil end
        old.Status = "Sold"
        old.Buyer = buyerId
        old.BuyerName = player and player.DisplayName or "a buyer"
        old.SoldAt = os.time()
        return old
    end)
    if not ok then IndexRemove(id); return false, "Someone else bought it." end
    IndexRemove(id)
    if state then
        local key, n = rec.Price.Key, rec.Price.N
        if key == "Gold" then state.Gold -= n else state.Materials[key] -= n end
        if rec.Kind == "Riftmod" then
            state.Riftmods = type(state.Riftmods) == "table" and state.Riftmods or {}
            table.insert(state.Riftmods, rec.Item)
        elseif rec.Kind == "ShotMod" then
            ReturnItem(state, "ShotMod", rec.Item)
        elseif ItemData.BagRoom(state) > 0 then
            table.insert((rec.Kind == "Weapon") and state.Inventory or state.GearInventory, rec.Item)
            if rec.Kind == "Weapon" and rec.Item.BaseId then state.StatsTracking.DiscoveredWeapons[rec.Item.BaseId] = true end
        else
            ReturnItem(state, rec.Kind, rec.Item) -- (bag full: into a trade tab / the stash)
        end
        Save(player, state)
        Sync(player, state)
    end
    -- the seller's proceeds (price - tax), atomic; if they're in this server, tell them
    local sellerPlayer = Players:GetPlayerByUserId(rec.Seller)
    local sellerState = sellerPlayer and CombatServer.GetState(sellerPlayer)
    local tax = sellerState and MarketService.Tax(sellerState) or MarketService.TAX
    local net = math.max(1, math.floor(rec.Price.N * (1 - tax)))
    Update("P_" .. rec.Seller, function(old)
        old = type(old) == "table" and old or {}
        old[rec.Price.Key] = (old[rec.Price.Key] or 0) + net
        return old
    end)
    if sellerPlayer then
        if sellerPlayer:GetAttribute("ExchangeSold") == nil then sellerPlayer:SetAttribute("ExchangeSold", "sale") end -- (QOL2 H3: the MENU dot; the line below is the notice)
        Remotes.GetEvent("CombatFx"):FireClient(sellerPlayer, "Text", "EXCHANGE: " .. MarketService.ItemName(rec.Item) .. " sold for " .. MarketService.PriceText(rec.Price)
            .. " (" .. ItemData.FormatNumber(net) .. " after tax). Collect it at the Exchange.", Color3.fromRGB(110, 230, 150))
    end
    if state then pcall(CombatServer.ContractEvent, player, state, "MarketBuy", 1) end
    return true, "Bought " .. MarketService.ItemName(rec.Item) .. " for " .. MarketService.PriceText(rec.Price) .. "."
end

function MarketService.Collect(player: Player): (boolean, string?)
    local state = CombatServer.GetState(player)
    if not state then return false, "?" end
    local taken = nil
    local ok = Update("P_" .. player.UserId, function(old)
        if type(old) ~= "table" or next(old) == nil then return nil end
        taken = old
        return {}
    end)
    if not ok or not taken then return false, "Nothing to collect." end
    local parts = {}
    for key, n in pairs(taken) do
        if key == "Gold" then state.Gold += n else state.Materials = state.Materials or {}; state.Materials[key] = (state.Materials[key] or 0) + n end
        table.insert(parts, ItemData.FormatNumber(n) .. " " .. CurName(key))
    end
    Save(player, state)
    Sync(player, state)
    player:SetAttribute("ExchangeSold", nil) -- (QOL2 H3)
    return true, "Collected " .. table.concat(parts, ", ") .. "."
end

-- QOL2 H3 (2026-10-28, audit: an offline sale only showed when you opened the Exchange): ONE read of your proceeds per join
-- (from the join loop in Init, no polling) -> Player attr ExchangeSold = "join" (the client toasts + dots the MENU / EXCHANGE
-- tile); a sale while you're here sets "sale" (Buy: the dot only, the sale line already shows); COLLECT clears it.
function MarketService.SaleNotice(player: Player)
    local p = Get("P_" .. player.UserId)
    if type(p) ~= "table" then return end
    for _, n in pairs(p) do
        if (tonumber(n) or 0) > 0 then player:SetAttribute("ExchangeSold", "join"); return end
    end
end

function MarketService.Mine(player: Player): any
    local seller = Get("S_" .. player.UserId) or { Ids = {} }
    local out = {}
    for i = #(seller.Ids or {}), 1, -1 do
        local r = Get("L_" .. seller.Ids[i])
        if r and r.Status ~= "Cancelled" then table.insert(out, { Summary = Summary(r), Status = r.Status, BuyerName = r.BuyerName }) end
        if #out >= 30 then break end
    end
    local proceeds = Get("P_" .. player.UserId) or {}
    if next(proceeds) == nil and player:GetAttribute("ExchangeSold") ~= nil then player:SetAttribute("ExchangeSold", nil) end -- (QOL2 H3: collected in another server)
    return { Listings = out, Proceeds = proceeds, Max = MarketService.MaxListings(CombatServer.GetState(player)), Tax = MarketService.Tax(CombatServer.GetState(player)) }
end

-- filters { Kind = "Any" | "Weapon" | "Gear" | "Riftmod", MinRarity, Text, Currency, Sort = "Cheap" | "New" }
-- + (QOL2 I5 PRICE CHECK, all optional, exact): Rarity, BaseId (a gun's base / a Riftmod's gun), Slot (gear: rings match either ring)
function MarketService.Browse(player: Player, f: any): any
    f = type(f) == "table" and f or {}
    local all = IndexAll()
    local out = {}
    local minRank = ItemData.RarityRank[f.MinRarity or ""] or 0
    local text = type(f.Text) == "string" and string.lower(string.sub(f.Text, 1, 30)) or ""
    for _, s in ipairs(all) do
        local ok = true
        if f.Kind and f.Kind ~= "Any" and s.Kind ~= f.Kind then ok = false end
        if ok and f.MinRarity == "Zenith" then ok = s.Zenith == true -- (CHASE ITEMS)
        elseif ok and minRank > 0 and (ItemData.RarityRank[s.Rarity] or 0) < minRank then ok = false end
        if ok and type(f.Exotic) == "string" and s.Exotic ~= f.Exotic then ok = false end -- (CHASE ITEMS: a named relic / Zenith)
        if ok and f.Currency and f.Currency ~= "Any" and s.Price and s.Price.Key ~= f.Currency then ok = false end
        if ok and type(f.Rarity) == "string" and s.Rarity ~= f.Rarity then ok = false end -- (QOL2 I5)
        if ok and type(f.BaseId) == "string" and s.BaseId ~= f.BaseId then ok = false end
        if ok and type(f.Slot) == "string" and ItemData.GearType(tostring(s.Slot or "")) ~= ItemData.GearType(f.Slot) then ok = false end
        if ok and text ~= "" then
            local hay = string.lower(table.concat({ tostring(s.Name), tostring(s.BaseId or ""), tostring(s.Slot or ""), tostring(s.Rarity), table.concat(s.Lines or {}, " ") }, " "))
            ok = string.find(hay, text, 1, true) ~= nil
        end
        if ok then table.insert(out, s) end
    end
    if f.Sort == "New" then table.sort(out, function(a, b) return (a.At or 0) > (b.At or 0) end)
    else -- (cheapest within each currency: the currencies grouped in their own order, gold first)
        local order = {}
        for i, k in ipairs(MarketService.CURRENCIES) do order[k] = i end
        table.sort(out, function(a, b)
            local ka, kb = order[a.Price and a.Price.Key or ""] or 99, order[b.Price and b.Price.Key or ""] or 99
            if ka ~= kb then return ka < kb end
            return (a.Price and a.Price.N or 0) < (b.Price and b.Price.N or 0)
        end)
    end
    while #out > MarketService.BROWSE_MAX do table.remove(out) end
    return { Results = out, Total = #all }
end

-- a Pending listing left by a crash: settled on the seller's next load (the item is either in the save or in escrow)
function MarketService.Reconcile(player: Player, state: any)
    local seller = Get("S_" .. player.UserId)
    for _, id in ipairs(seller and seller.Ids or {}) do
        local r = Get("L_" .. id)
        if r and r.Status == "Pending" then
            local uid = r.Item and r.Item.Uid
            local found = false
            for _, box in ipairs(StashTabs.AllBoxes(state)) do
                for _, list in ipairs({ box.W or {}, box.G or {} }) do for _, it in ipairs(list) do if it.Uid == uid then found = true end end end
            end
            for _, it in ipairs(state.Riftmods or {}) do if it.Uid == uid then found = true end end
            for _, it in ipairs(state.ShotMods or {}) do if it.Uid == uid then found = true end end
            Update("L_" .. id, function(old)
                if not old or old.Status ~= "Pending" then return nil end
                old.Status = found and "Cancelled" or "Open"
                return old
            end)
            if not found then IndexSet(id, Summary(r)) end
        end
    end
end

-- (Studio tests only, QOL2 H3: proceeds waiting for a player, as a sale in another server would leave them)
function MarketService._TestProceeds(userId: number, t: any)
    if not MarketService.MEMORY then return end
    Update("P_" .. userId, function() return t end)
end

-- (Studio tests only: put a ready listing in place, as a seller elsewhere would have)
function MarketService._TestPut(id: string, rec: any)
    if not MarketService.MEMORY then return end
    Update("L_" .. id, function() return rec end)
    IndexSet(id, Summary(rec))
end

function MarketService.Init(combat: any)
    CombatServer = combat
    Remotes.GetFunction("MarketAction").OnServerInvoke = function(player: Player, action: any, a: any, b: any, c: any, d: any, e: any)
        if not MarketService.ON then return false, "The Exchange is closed." end
        local now = os.clock()
        if busy[player] and now - busy[player] < 0.4 then return false, "One moment..." end
        busy[player] = now
        if action == "Browse" then return true, MarketService.Browse(player, a) end
        if action == "Mine" then return true, MarketService.Mine(player) end
        if action == "List" then return MarketService.List(player, a, b, c, d, e) end
        if action == "Cancel" then return MarketService.Cancel(player, a) end
        if action == "Buy" then return MarketService.Buy(player, a) end
        if action == "Collect" then return MarketService.Collect(player) end
        return false, "?"
    end
    Players.PlayerRemoving:Connect(function(p) busy[p] = nil end)
    task.spawn(function() -- (each player's leftover Pending listings, once their save is in)
        local done = {}
        while true do
            task.wait(5)
            for _, p in ipairs(Players:GetPlayers()) do
                if not done[p] then
                    local st = CombatServer.GetState(p)
                    if st then done[p] = true; pcall(MarketService.Reconcile, p, st); pcall(MarketService.SaleNotice, p) end -- (QOL2 H3: + the sale notice)
                end
            end
            for p in pairs(done) do if not p.Parent then done[p] = nil end end
        end
    end)
end

return MarketService
