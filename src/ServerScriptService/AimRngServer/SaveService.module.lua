--!nocheck
-- Player save/load (DataStore). CombatServer owns the live PlayerState; this module turns it into a
-- plain JSON-safe table and back, and handles the DataStore session lifecycle:
--   * BeginLoad on join (session-locked UpdateAsync, retries), WaitForLoad blocks GetState until done
--   * autosave every AUTOSAVE_SECONDS, final save + lock release on leave, BindToClose on shutdown
--   * a failed load kicks the player instead of handing them a fresh character that would then
--     overwrite their real save
-- Unpublished places (PlaceId 0) have no DataStore access: a per-session mock store is used, so
-- nothing persists there but every code path still runs.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local ItemData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ItemData"))

local SaveService = {}

-- WIPES (fresh start for everyone): bump WIPE and publish. Each wipe reads + writes its own store
-- ("PlayerSave_v<WIPE>") and its own leaderboards (SaveService.BOARD_SUFFIX, used by EndgameServer), so nothing is
-- deleted: setting WIPE back restores the old saves. On a player's FIRST load after a wipe, CARRY_FIELDS (cosmetics
-- they own -- possibly bought with Robux) are copied from the previous wipe's store, unless that wipe is listed in
-- NO_CARRY. History: 1 = launch .. 2026-10-05; 2 = 2026-10-05 owner reset ("everyone fresh start", nothing bought yet,
-- so nothing carried); 3 = 2026-10-14 launch wipe after the move to the group (purchases carried); 4 = 2026-10-20 after
-- UPDATE 7 (owner: "lets do everything on our list and then do that [wipe]" -- the loot rules, crafting currencies and the
-- Exchange changed under every old item; purchases carried, + the BOUND-bought parts of the hideout: CarryPurchases); 5 = UPDATE 8
-- "THE REVAMP" (set 2026-10-21 overnight, owner: damage types, defences, gun / gear bases, sockets + shot mods, 5 rarities,
-- Relics -- every old item is from the old game; carried exactly like WIPE 4: CARRY_FIELDS + CarryPurchases; items, gear, shot
-- mods, levels, gold and currencies stay behind. The Exchange gets fresh stores too: MARKET_SUFFIX); 6 = LOOT SCARCITY (2026-11-07,
-- owner: "Just wipe the game again, its fine. Nobody has played yet" -- far fewer items / currencies, upgrades gated by item level:
-- docs/LOOT_SCARCITY_2026-11-07.md; carried exactly like WIPE 5, boards "_w6", Exchange "_w6", crews' bank / research / Gave reset once).
local WIPE = 6
local NO_CARRY = { [2] = true }
local CARRY_FIELDS = {
    "CosmeticsOwned", "CosmeticsEquipped", "BarStyle", "BarStylesOwned", "OwnedMeleeSkins", "MeleeSkinFor", "AvatarOwned",
    "BoundPoints", "Colorways", -- (0.93: bought with Robux)
    "SkinCopies", -- (2026-10-14: extra copies of tradeable skins, bought with BOUND points)
    "Settings", -- (keybinds / sensitivity: not progress)
}
local function StoreFor(wipe: number): string return "PlayerSave_v" .. wipe end
local STORE_NAME = StoreFor(WIPE)
SaveService.WIPE = WIPE
SaveService.BOARD_SUFFIX = WIPE <= 1 and "" or ("_w" .. WIPE) -- (wipe 1's boards had no suffix)
-- (WIPE 5) the Exchange's stores (MarketService: Market_v1 / MarketIndex_v1) get a suffix from wipe 5 on, so old-game items
-- listed before the wipe (and their unsold gold) stay behind with the old saves; "" keeps wipe 4's stores
SaveService.MARKET_SUFFIX = WIPE >= 5 and ("_w" .. WIPE) or ""
local SAVE_VERSION = 2 -- 2 = progression overhaul (older saves load as a fresh character)
local AUTOSAVE_SECONDS = 90
local LOCK_STALE_SECONDS = 150 -- a lock older than this belongs to a crashed server and is taken over
local LOCK_WAIT_TRIES = 6 -- ~30s waiting for another server to finish its final save
local MAX_SETTINGS_KEYS = 120

-- Fields copied straight from PlayerState (all JSON-safe plain data). Health / mag / streak /
-- reloading are deliberately NOT saved: they reset on rejoin like after a death.
local PLAIN_FIELDS = {
    "Inventory", "EquippedGear", "GearInventory", "AllocatedNodes", "SkillPoints", "StatPoints",
    "Hideout", -- (0.55: { Owned = { [id] = n }, Layout = { { I, X, Z, R } } } -- Hideouts)
    "Attributes", "Gold", "UpgradeShards", "ForgeCores", "RollsCount", "AutoSellThreshold", "GemAutoSalvage",
    "AutoSellV4", -- (UPDATE 8 RARITY v4: the old auto-sell threshold was re-mapped once -- ItemData.NormalizeRarities)
    "AutoSellRules", -- (2026-11-09 AUTO-SELL FILTER: the KEEP rules table, AutoSellRules.Clean on every load + every client set; nil = none)
    "GemSalvageV4", -- (UPDATE 8 GEM GRADES v4: the gem auto-salvage threshold was re-mapped once -- GemData.NormalizeState)
    "Level", "XP", "MaxXP",
    "EquippedGlove", "GloveInventory", "EquippedKnife", "KnifeInventory", "EquippedSleeve",
    "SleeveInventory", "EquippedWeaponSkin", "WeaponSkinInventory", "EquippedTitle", "UnlockedTitles",
    "DungeonDifficulty", "StatsTracking", "Settings", "Materials", "LastDailyRoll",
    "Gems", "SocketedGems", "TreeVersion", "Class", "Ascendancy", "AscNodes", "Contracts", "Weekly", "MasteryRank", "Archive", "Riftmods", "ShotMods", "BountyContract", "Calibration", "DropRules", "DailyLine", "Districts", "SeasonGoals", "Guild", "Paragon", "DailyBest", "TrialBest", "TrialRanks", "Sigils", "RiftBest", "RiftScale", "Atlas", "MapsDone", "UniquesDone", "MapComplete", "GotFirstSigil", "Blueprints", "Login", "Season", "Codex", "TrialRuns", "BoardClaims", "PendingLoot", "ShopStock", "OwnedMeleeSkins", "MeleeSkinFor", "ReviveCredits", "LostLoot",
    "Avatar", "AvatarOwned", -- character creator look + Robux-bought looks (AvatarData)
    "BarStyle", "BarStylesOwned", -- health bar cosmetic equipped + owned (BarStyles)
    "CosmeticsOwned", "CosmeticsEquipped", -- generic cosmetic storage for new categories (Cosmetics)
    "BoundPoints", "Colorways", -- (0.93) premium currency + set colourways { [kind] = { Own, Set, Items } } (Colorways)
    "SkinCopies", -- (2026-10-14) extra copies of tradeable skins { ["Cat:Id"] = n } (Cosmetics.Copies / AddCopy / TakeCopy)
    "AimLog", "AimGuns", -- (2026-10-20 AIM PROFILE) last runs' accuracy / per-gun totals (ProfileService.LogRun)
    "ReferredBy", "Referrals", -- (2026-10-20 FRIEND INVITES) who invited you { Id, Name, Days, Paid | No } / friends you invited { Paid } (ReferralService)
    "BossTrials", -- endgame Boss Trials progress { [bossId] = { Best, Times } } (BossTrials)
    "AscTrialBest", -- highest Trial of Ascension cleared, 0-4 (AscensionTrials; 2 ascendancy points each)
    "GrappleNodes", -- grapple skill tree { [nodeId] = true } (GrappleData)
    "Pity", -- TARGET LOOT picks + meters (ItemData.Pity / PityState)
    "PvpEscrow", -- (0.59) a duel's wagered items while it runs (given back on load if the duel never finished: PvpService)
    "PendingMapRefund", -- (QOL2 R5) a map left before its floor 1 was cleared: back into Sigils on the next join (MapRefund; nil = none)
    "PvpStats", -- (0.59) duels { W, L, Frags, Shots, Hits }
    "Expertise", -- (2026-10-22) the passive tree's Expertise picks { [node id] = effect id } (SkillTreeServer)
    "EquippedPassives", -- the passive skills (tree keystones) in use, max ClassData.PASSIVE_LIMIT (SkillTreeServer)
    "Receipts", -- (live-save check 2026-10-13) Robux purchases already granted { [PurchaseId] = os.time() }: a receipt Roblox
                -- re-sends is never granted twice (CombatServer ProcessReceipt); the newest RECEIPTS_KEEP are kept
}

---------------------------------------------------------------------------------------------------
-- Store (real or mock)
---------------------------------------------------------------------------------------------------
-- Studio playtests ALWAYS use the throwaway mock store (even once the place is published), so dev commands
-- and test sessions never touch real player saves. Set the place attribute UseRealSaves = true (in Studio,
-- on Workspace) only to deliberately test against the live DataStore.
local inStudio = RunService:IsStudio()
local useMock = game.PlaceId == 0 or (inStudio and not workspace:GetAttribute("UseRealSaves"))
local store, prevStore
local mockData, mockPrev = {}, {}
if not useMock then
    local ok, res = pcall(function() return DataStoreService:GetDataStore(STORE_NAME) end)
    if ok then store = res else useMock = true; warn("[SaveService] DataStore unavailable, using mock store: " .. tostring(res)) end
    if store and WIPE > 1 then
        local ok2, res2 = pcall(function() return DataStoreService:GetDataStore(StoreFor(WIPE - 1)) end)
        if ok2 then prevStore = res2 end
    end
elseif inStudio then
    warn("[SaveService] Studio playtest: using a throwaway save (real saves are untouched).")
else
    warn("[SaveService] Place isn't published (PlaceId 0): saves only last for this session.")
end

local function Update(key: string, fn: (any) -> any): (boolean, any)
    if useMock then
        local cur = mockData[key] and HttpService:JSONDecode(mockData[key]) or nil
        local new = fn(cur)
        if new ~= nil then mockData[key] = HttpService:JSONEncode(new) end
        return true, new
    end
    return pcall(function() return store:UpdateAsync(key, fn) end)
end

local function KeyFor(player: Player): string return "u_" .. player.UserId end

-- First load after a wipe: copy the carried fields from the previous wipe's save (READ ONLY -- the old save is never
-- written). Studio test hooks (mock store only): workspace attribute DevPrevSave = JSON of a previous-wipe save for
-- every joining player, DevForceCarry = true to carry even when this wipe is in NO_CARRY.
-- Returns false only when the previous store could not be READ (DataStore error / throttle, 3 tries): the caller then retries
-- the whole load (2026-10-21 review: a failed read used to load a fresh save with nothing carried -- the first save then
-- wrote Version and the bought cosmetics never came over -- and counted the player as "never played" for FRIEND INVITES).
local function CarryOver(key: string, data: any): boolean
    local force = useMock and workspace:GetAttribute("DevForceCarry")
    if NO_CARRY[WIPE] and not force then return true end
    local old
    if useMock then
        local seed = workspace:GetAttribute("DevPrevSave")
        old = mockPrev[key] or (type(seed) == "string" and HttpService:JSONDecode(seed)) or nil
    elseif prevStore then
        local ok, res
        for try = 1, 3 do
            ok, res = pcall(function() return prevStore:GetAsync(key) end)
            if ok then break end
            warn("[SaveService] couldn't read the pre-wipe save (try " .. try .. "): " .. tostring(res))
            task.wait(try)
        end
        if not ok then return false end
        old = res
    end
    if type(old) ~= "table" then return true end
    local n = 0
    for _, f in ipairs(CARRY_FIELDS) do
        if old[f] ~= nil then data[f] = old[f]; n += 1 end
    end
    n += SaveService.CarryPurchases(old, data)
    if n > 0 then
        data.Version = SAVE_VERSION -- (Apply only reads saves of the current version)
        data.CarriedFrom = WIPE - 1
        print(string.format("[SaveService] carried %d field(s) over the wipe for %s", n, key))
    end
    return true
end

-- (WIPE 4) what was bought but lives inside progress tables: the hideout's BOUND / Robux purchases (stash tabs -- emptied,
-- GEM / MAP tabs, themes, expansions, the map room, premium pieces), the premium season pass of the running season (its
-- XP / claims reset), stored revive credits and the receipt ledger (a receipt Roblox re-sends is never granted twice).
-- Items, gold, levels, currencies and everything earned in play stay behind.
function SaveService.CarryPurchases(old: any, data: any): number
    local n = 0
    local oh = type(old.Hideout) == "table" and old.Hideout or nil
    if oh then
        local h = {}
        if type(oh.Tabs) == "table" then
            h.Tabs = {}
            for _, t in ipairs(oh.Tabs) do
                if type(t) == "table" and t.Id then table.insert(h.Tabs, { Id = t.Id, Kind = t.Kind, Name = t.Name, W = {}, G = {} }) end
            end
        end
        if type(oh.Special) == "table" then h.Special = oh.Special end
        if type(oh.Themes) == "table" then h.Themes = oh.Themes; h.Theme = oh.Theme end
        if tonumber(oh.Exp) then h.Exp = oh.Exp end
        if oh.MapRoom then h.MapRoom = true end
        if oh.GoldTradeTab then h.GoldTradeTab = true end
        if type(oh.Owned) == "table" then
            local okHD, HD = pcall(function() return require(game.ReplicatedStorage.AimRngShared.HideoutData) end)
            h.Owned = {}
            for id, cnt in pairs(oh.Owned) do
                local def = okHD and HD.Items[id]
                if def and def.Source == "Robux" then h.Owned[id] = cnt end
            end
        end
        data.Hideout = h
        n += 1
    end
    local os_ = type(old.Season) == "table" and old.Season or nil
    if os_ and os_.Premium then
        data.Season = { Id = os_.Id, XP = 0, Claimed = {}, Premium = true, ClaimedP = {} }
        n += 1
    end
    if (tonumber(old.ReviveCredits) or 0) > 0 then data.ReviveCredits = old.ReviveCredits; n += 1 end
    if type(old.Receipts) == "table" then data.Receipts = old.Receipts; n += 1 end
    return n
end

---------------------------------------------------------------------------------------------------
-- Serialization
---------------------------------------------------------------------------------------------------
-- Deep copy keeping only JSON-safe values (string/bool/finite number, tables with string keys or a
-- proper array). Anything else (Instances, Color3, inf/nan, functions) is dropped.
local function Clean(v: any, depth: number?): any
    depth = depth or 0
    if depth > 12 then return nil end
    local t = type(v)
    if t == "string" or t == "boolean" then return v end
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return nil end
        return v
    end
    if t ~= "table" then return nil end
    local n = #v
    local out = {}
    if n > 0 then
        for i = 1, n do
            local c = Clean(v[i], depth + 1)
            if c ~= nil then table.insert(out, c) end
        end
    else
        for k, x in pairs(v) do
            if type(k) == "string" then
                local c = Clean(x, depth + 1)
                if c ~= nil then out[k] = c end
            end
        end
    end
    return out
end

function SaveService.Serialize(state: any): any
    -- (Update 5 lifetime stats: play time ticks in at every save -- autosave every 90 s + on leave)
    local stt = type(state.StatsTracking) == "table" and state.StatsTracking or nil
    if stt then
        local now = os.clock()
        local last = tonumber((state :: any)._PlayTick)
        if last then stt.PlaySeconds = (tonumber(stt.PlaySeconds) or 0) + math.clamp(now - last, 0, 3600) end
        ;(state :: any)._PlayTick = now
    end
    local data = { Version = SAVE_VERSION }
    for _, f in ipairs(PLAIN_FIELDS) do
        if state[f] ~= nil then data[f] = Clean(state[f]) end
    end
    data.EquippedWeaponUid = state.EquippedWeapon and state.EquippedWeapon.Uid or nil
    data.PointsV = 3 -- (passive points v4: ItemData.TreePointsAt, see Apply)
    data.AttrV = 3 -- (attribute points v3 = none: UPDATE 8 phase 4, see Apply)
    data.RunLenV = 2 -- (6-floor Easy / Normal, see Apply)
    return data
end

-- Overlay saved data onto a freshly built default state. Unknown/mistyped fields keep the default,
-- so adding new state fields later never breaks old saves.
function SaveService.Apply(state: any, data: any)
    if type(data) ~= "table" then return end
    -- Saves from before the progression overhaul don't fit the new item/level rules: start fresh
    -- (settings are kept -- they don't depend on the economy).
    if (data.Version or 1) < SAVE_VERSION then
        if type(data.Settings) == "table" then state.Settings = data.Settings end
        return
    end
    -- Saves from before passive tree v2 have no TreeVersion: SkillTreeServer.Validate refunds their tree.
    if data.TreeVersion == nil then data.TreeVersion = 1 end
    for _, f in ipairs(PLAIN_FIELDS) do
        local v, def = data[f], state[f]
        if v ~= nil and (def == nil or type(v) == type(def)) then
            if type(v) == "table" and type(def) == "table" and (f == "Attributes" or f == "StatsTracking" or f == "Materials") then
                for k, x in pairs(v) do
                    if def[k] == nil or type(def[k]) == type(x) or def[k] == math.huge then def[k] = x end
                end
            else
                state[f] = v
            end
        end
    end

    -- Drop weapons whose base gun no longer exists (the weapon overhaul removes pack guns) and pay
    -- the player their sell value so nothing is silently lost.
    local kept, refund = {}, 0
    for _, w in ipairs(state.Inventory or {}) do
        local def = type(w) == "table" and w.BaseId and ItemData.BaseWeapons[w.BaseId]
        if def and not def.Legacy then
            table.insert(kept, w)
        else
            refund += (ItemData.BaseSellPrices and ItemData.BaseSellPrices[w and w.Rarity] or 25)
        end
    end
    state.Inventory = kept
    state.Gold += refund

    -- LAUNCH CAP (ItemData.MAX_LEVEL 200): a character above the cap (Studio / mock saves from the 400 days; live is wiped at
    -- WIPE 5) comes down to the cap with its XP bar empty
    if (tonumber(state.Level) or 1) > ItemData.MAX_LEVEL then state.Level = ItemData.MAX_LEVEL; state.XP = 0 end

    -- Passive points v2 (owner 2026-10-04: "one every level and then every 5th level you get 5 points (make sure to
    -- update existing players)"): saves from before get the 4 extra points for each 5th level they already reached.
    -- RUN LENGTHS v4 (2026-10-22): Easy / Normal went 5 -> 6 floors, and a clear means FloorsByDifficulty >= MaxWaves
    -- (ItemData.DifficultyUnlock / DifficultyCleared): a full 5-floor clear from before counts as the new full clear, or
    -- Normal / Hard re-lock and the clear's passive points vanish.
    if (data.RunLenV or 1) < 2 then
        local fb = type(state.StatsTracking) == "table" and state.StatsTracking.FloorsByDifficulty
        if type(fb) == "table" then
            for _, d in ipairs({ "Easy", "Normal" }) do
                local m = ItemData.DifficultyModes[d]
                if (tonumber(fb[d]) or 0) >= 5 and m then fb[d] = math.max(fb[d], m.MaxWaves) end
            end
        end
    end
    if (data.AttrV or 1) < 2 then
        -- ATTRIBUTES v2 (2026-10-05: 1 a level + 4 every 10th, worth more each): every attribute back to the base 5 and the
        -- points the level earns now to spend again (one free respec)
        local lvl = math.min(tonumber(state.Level) or 1, ItemData.MAX_LEVEL)
        state.Attributes = { Strength = 5, Dexterity = 5, Vitality = 5, Luck = 5 }
        state.StatPoints = ItemData.AttrPointsAt(lvl)
    end
    if (data.AttrV or 1) < 3 then
        -- (UPDATE 8 OFFENSE phase 4) ATTRIBUTES the PoE way: they come only from the tree + gear. Hand-placed points are
        -- refunded to nothing (the Strength / Dexterity / Intellect totals ignore state.Attributes); no SAVE_VERSION bump.
        state.Attributes = { Strength = 5, Dexterity = 5, Vitality = 5, Luck = 5 }
        state.StatPoints = 0
    end
    if (data.PointsV or 1) < 3 then
        -- PASSIVE POINTS v4 (2026-10-05: 1 a level + 5 every 5th, 800 at 400): unspent = what the level earns minus the
        -- nodes already allocated (class starts are free). Replaces the v2 top-up.
        local lvl = math.min(tonumber(state.Level) or 1, ItemData.MAX_LEVEL)
        local spent = 0
        for _, id in ipairs(type(state.AllocatedNodes) == "table" and state.AllocatedNodes or {}) do
            if type(id) == "string" and string.sub(id, 1, 6) ~= "CLASS_" then spent += 1 end
        end
        state.SkillPoints = math.max(0, ItemData.TreePointsTotal(state) - spent) -- (v5 points: SkillTreeServer.Validate recomputes too)
    end

    -- Precision rework (2026-10-02, no AOE): Explosive prefixes became Echo, and traits take their current text
    -- (same ids, new single-target effects).
    local function Refresh(w)
        if type(w) ~= "table" then return end
        if type(w.Proc) == "table" and w.Proc.Id == "Explosive" then
            w.Proc.Id = "Echo"
            if type(w.Name) == "string" then w.Name = string.gsub(w.Name, "^Explosive ", "Echoing ") end
        end
        -- (2026-10-04) recoil affixes are gone: an old RecoilControl roll becomes Effect Duration
        for _, list in ipairs({ w.Prefixes, w.Suffixes, w.Affixes }) do
            if type(list) == "table" then
                for _, a in ipairs(list) do if type(a) == "table" and a.Stat == "RecoilControl" then a.Stat = "AilmentDuration" end end
            end
        end
        local t = type(w.UniqueTrait) == "table" and ItemData.TraitById[w.UniqueTrait.Id]
        if t then w.UniqueTrait = table.clone(t) elseif type(w.UniqueTrait) == "table" then w.UniqueTrait = nil end
    end
    for _, w in ipairs(state.Inventory or {}) do Refresh(w) end
    Refresh(state.EquippedWeapon)
    for _, e in ipairs(type(state.LostLoot) == "table" and state.LostLoot or {}) do Refresh(type(e) == "table" and (e.Item or e) or nil) end

    -- Retired melees (only ItemData.MeleeLineup is in the game): refund what they cost, Crowbar back in hand.
    if type(state.KnifeInventory) == "table" then
        local melees = {}
        for _, id in ipairs(state.KnifeInventory) do
            local kd = ItemData.MeleeWeapons[id]
            if ItemData.IsActiveMelee(id) then
                table.insert(melees, id)
            elseif kd then
                state.Gold += kd.CostGold or 0
                state.UpgradeShards = (state.UpgradeShards or 0) + (kd.CostShards or 0)
            end
        end
        if not table.find(melees, "Knife") then table.insert(melees, 1, "Knife") end -- (0.97: the knife replaced the crowbar)
        state.KnifeInventory = melees
    end
    if not ItemData.IsActiveMelee(state.EquippedKnife) then state.EquippedKnife = "Knife" end

    local equipped
    for _, w in ipairs(state.Inventory) do
        if w.Uid == data.EquippedWeaponUid then equipped = w break end
    end
    if not equipped then
        equipped = state.Inventory[1]
        if not equipped then
            equipped = ItemData.CreateStarterPistol()
            table.insert(state.Inventory, equipped)
        end
    end
    state.EquippedWeapon = equipped
    -- (tree v4: the tree's root is your class start -- SkillTreeServer.Validate adds it; no "Origin" any more)
end

-- Settings come from the client: accept only a flat table of short primitive values (plus one level
-- of nesting for things like keybinds) so a client can't bloat the save.
function SaveService.SanitizeSettings(s: any): any?
    if type(s) ~= "table" then return nil end
    local out, count = {}, 0
    local function prim(v)
        local t = type(v)
        if t == "boolean" then return v end
        if t == "number" and v == v and math.abs(v) < 1e6 then return v end
        if t == "string" and #v <= 40 then return v end
        return nil
    end
    for k, v in pairs(s) do
        if type(k) == "string" and #k <= 40 then
            if type(v) == "table" then
                local sub = {}
                for k2, v2 in pairs(v) do
                    if type(k2) == "string" and #k2 <= 40 and prim(v2) ~= nil then
                        count += 1
                        sub[k2] = prim(v2)
                    end
                end
                out[k] = sub
            elseif prim(v) ~= nil then
                out[k] = prim(v)
            end
            count += 1
            if count > MAX_SETTINGS_KEYS then break end
        end
    end
    return out
end

---------------------------------------------------------------------------------------------------
-- Session lifecycle
---------------------------------------------------------------------------------------------------
-- sessions[player] = { Status = "loading" | "ready" | "failed" | "released", Data = table?, Signal = BindableEvent }
local sessions = {}

local function NewLock() return { JobId = game.JobId ~= "" and game.JobId or "studio", Time = os.time() } end

function SaveService.BeginLoad(player: Player)
    if sessions[player] then return end
    local sess = { Status = "loading", Signal = Instance.new("BindableEvent") }
    sessions[player] = sess
    task.spawn(function()
        local key = KeyFor(player)
        local loaded, lockedOut = nil, false
        for attempt = 1, LOCK_WAIT_TRIES + 3 do
            if player.Parent == nil then break end
            lockedOut = false
            local ok, res = Update(key, function(cur)
                cur = cur or {}
                local lock = cur.Lock
                if lock and lock.JobId ~= NewLock().JobId and os.time() - (lock.Time or 0) < LOCK_STALE_SECONDS
                    and attempt <= LOCK_WAIT_TRIES then
                    lockedOut = true
                    return nil -- leave the record untouched; another server is still writing it
                end
                cur.Lock = NewLock()
                return cur
            end)
            if ok and not lockedOut then
                local got = res or {}
                local fresh = got.Version == nil and got.CarriedFrom == nil
                if not (fresh and WIPE > 1) or CarryOver(key, got) then
                    loaded = got
                    -- (2026-10-20 FRIEND INVITES) never played Aimbound: no save in this wipe AND nothing carried from the last one
                    sess.New = fresh and loaded.CarriedFrom == nil
                    break
                end
                warn("[SaveService] pre-wipe save unreadable for " .. player.Name .. "; retrying the load")
            end
            if not ok then warn("[SaveService] load failed for " .. player.Name .. ": " .. tostring(res)) end
            task.wait(lockedOut and 5 or math.min(2 ^ attempt, 8))
        end
        if loaded then
            sess.Data = loaded
            sess.Status = "ready"
        else
            sess.Status = "failed"
            if player.Parent then
                player:Kick("Couldn't load your save data (Roblox data servers may be busy). Please rejoin in a minute. Your progress is safe.")
            end
        end
        sess.Signal:Fire()
    end)
end

-- Yields until the player's save has loaded. Returns (data, canSave). data is {} for a new player.
function SaveService.WaitForLoad(player: Player): (any, boolean)
    local sess = sessions[player]
    if not sess then
        if player.Parent == nil then return nil, false end
        SaveService.BeginLoad(player)
        sess = sessions[player]
    end
    if sess.Status == "loading" then sess.Signal.Event:Wait() end
    if sess.Status == "ready" then return sess.Data, true end
    return nil, false
end

-- (2026-10-20 PLAYER PROFILES) a READ-ONLY look at someone's save (a statue / leaderboard player who isn't here): no lock, never
-- written. Studio's mock store has only this session's players: nil.
function SaveService.PeekSave(userId: number): any
    if useMock or not store then return nil end
    local ok, v = pcall(function() return store:GetAsync("u_" .. tostring(math.floor(tonumber(userId) or 0))) end)
    return (ok and type(v) == "table") and v or nil
end

-- true when this player had never played (no save in this wipe or the previous one) -- FRIEND INVITES only count them
function SaveService.IsNewPlayer(player: Player): boolean
    local sess = sessions[player]
    return sess ~= nil and sess.New == true
end

function SaveService.IsReady(player: Player): boolean
    local sess = sessions[player]
    return sess ~= nil and sess.Status == "ready"
end

-- release = true on leave/shutdown: clears the session lock so the next server loads instantly.
function SaveService.Save(player: Player, state: any, release: boolean?): boolean
    local sess = sessions[player]
    if not sess or sess.Status ~= "ready" or not state then return false end
    if sess.Saving then
        -- never run two UpdateAsyncs for one key at once; wait for the running one
        while sess.Saving do task.wait(0.1) end
        if sess.Status ~= "ready" then return false end
    end
    sess.Saving = true
    local data = SaveService.Serialize(state)
    data.Lock = (not release) and NewLock() or nil
    data.SavedAt = os.time()
    local stolen = false
    local ok, err
    for attempt = 1, 3 do
        ok, err = Update(KeyFor(player), function(cur)
            -- someone else took the save over (we were treated as crashed): don't clobber them
            if cur and cur.Lock and cur.Lock.JobId ~= NewLock().JobId then stolen = true return nil end
            return data
        end)
        if ok then break end
        task.wait(attempt)
    end
    sess.Saving = false
    if not ok then warn("[SaveService] save failed for " .. player.Name .. ": " .. tostring(err)) end
    if stolen then
        warn("[SaveService] " .. player.Name .. "'s save is locked by another server; not saving here.")
        sess.Status = "released"
    end
    if release then sess.Status = "released" end
    return ok and not stolen
end

function SaveService.Forget(player: Player)
    local sess = sessions[player]
    if sess then sess.Signal:Destroy() end
    sessions[player] = nil
end

-- getState(player) -> live state or nil. onReleased(player) lets CombatServer drop its copy.
function SaveService.Start(getState: (Player) -> any?, onReleased: (Player) -> ())
    Players.PlayerAdded:Connect(SaveService.BeginLoad)
    for _, p in ipairs(Players:GetPlayers()) do SaveService.BeginLoad(p) end

    Players.PlayerRemoving:Connect(function(p)
        local sess = sessions[p]
        if sess and sess.Status == "loading" then sess.Signal.Event:Wait() end
        for _, f in ipairs(SaveService.LeaveHooks or {}) do -- (0.59: a duel forfeit settles the wager before this save)
            local ok, err = pcall(f, p, getState(p))
            if not ok then warn("[SaveService] leave hook: " .. tostring(err)) end
        end
        SaveService.Save(p, getState(p), true)
        onReleased(p)
        SaveService.Forget(p)
    end)

    task.spawn(function()
        while true do
            task.wait(AUTOSAVE_SECONDS)
            for _, p in ipairs(Players:GetPlayers()) do
                if SaveService.IsReady(p) then
                    task.spawn(SaveService.Save, p, getState(p), false)
                    task.wait(0.5) -- spread requests out
                end
            end
        end
    end)

    game:BindToClose(function()
        if useMock or RunService:IsStudio() and #Players:GetPlayers() == 0 then return end
        local pending = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if SaveService.IsReady(p) then
                pending += 1
                task.spawn(function()
                    SaveService.Save(p, getState(p), true)
                    pending -= 1
                end)
            end
        end
        local t0 = os.clock()
        while pending > 0 and os.clock() - t0 < 25 do task.wait(0.1) end
    end)
end

SaveService.UsingMock = function() return useMock end

return SaveService
