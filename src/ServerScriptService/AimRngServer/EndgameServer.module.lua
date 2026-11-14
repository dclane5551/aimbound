--!nocheck
-- Endgame / replayability systems (server side):
--   Daily Challenge StartDailyChallenge(), DungeonRuns calls DailyFinished (DailyChallenge module)
--   Aim Trials      BeginTrial(id), SubmitTrial(id, score, hits, shots)   (AimTrials module)
--   GetChallengeData() -> everything the Challenges window shows (today's challenge, bests, leaderboards)
-- Leaderboards: OrderedDataStores per day ("Daily_<day>", "Trial_<id>_<day>"); Studio play-tests and
-- unpublished places use an in-memory board so real boards stay clean.
-- Player state: DailyBest = { Day, Time, Rewarded }, TrialBest = { [id] = score }, TrialRanks = { [id] = rank }
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Progression = require(Shared:WaitForChild("Progression"))
local DailyChallenge = require(Shared:WaitForChild("DailyChallenge"))
local AimTrials = require(Shared:WaitForChild("AimTrials"))
local Rifts = require(Shared:WaitForChild("Rifts"))
local AtlasData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("AtlasData")) -- (MAP TREE)
local MapCompletion = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("MapCompletion")) -- (MAPS V2 L2)
local BossTrials = require(Shared:WaitForChild("BossTrials"))
local AscensionTrials = require(Shared:WaitForChild("AscensionTrials"))
local Seasons = require(Shared:WaitForChild("Seasons"))
local ItemDataTop = require(Shared:WaitForChild("ItemData"))

local EndgameServer = {}
local CombatServer: any = nil

-- ===================== leaderboards =====================
local useMemory = RunService:IsStudio() or game.PlaceId == 0
-- (Studio test hook: workspace attr DevRealBoards = true at server start READS the real boards through the paced reader;
-- scores submitted in Studio still go to the in-memory boards)
local readMemory = useMemory and not workspace:GetAttribute("DevRealBoards")
local memoryBoards: { [string]: { [string]: number } } = {}
local boardCache: { [string]: { At: number, Rows: { any }, Count: number } } = {}
local boardDirty: { [string]: boolean } = {}
-- (each save wipe gets fresh leaderboards: SaveService.BOARD_SUFFIX, "" before the first wipe)
local BOARD_SUFFIX = require(script.Parent:WaitForChild("SaveService")).BOARD_SUFFIX

-- ascending = lower is better (times); otherwise higher is better (scores)
local function SubmitScore(boardName: string, player: Player, value: number, ascending: boolean)
    local key = tostring(player.UserId)
    if useMemory then
        local b = memoryBoards[boardName] or {}
        memoryBoards[boardName] = b
        local cur = b[key]
        if cur == nil or (ascending and value < cur) or (not ascending and value > cur) then b[key] = value end
        boardDirty[boardName] = true
        return
    end
    task.spawn(function()
        local ok, err = pcall(function()
            local store = DataStoreService:GetOrderedDataStore(boardName .. BOARD_SUFFIX)
            -- stored as integers: times in tenths of a second, scores as-is
            local v = ascending and math.round(value * 10) or math.round(value)
            store:UpdateAsync(key, function(old)
                if old == nil then return v end
                if ascending then return math.min(old, v) end
                return math.max(old, v)
            end)
        end)
        if not ok then warn("[EndgameServer] leaderboard submit failed: " .. tostring(err)) end
        boardDirty[boardName] = true -- (re-read by the paced reader, not at once: see TopOf)
    end)
end

local nameCache: { [number]: string } = {}
local function NameOf(userId: number): string
    if nameCache[userId] then return nameCache[userId] end
    local p = Players:GetPlayerByUserId(userId)
    local n = p and p.DisplayName
    if not n and not useMemory then
        local ok, res = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
        n = ok and res or nil
    end
    n = n or ("Player " .. userId)
    nameCache[userId] = n
    return n
end

-- Top rows { Name, Value }.
-- READS ARE PACED (owner's live console 2026-10-12: "DataStore request was added to queue" for BossTrial_*, Daily_*,
-- Trial_* every few seconds -- the hub loop read all ~90 boards with GetSortedAsync in one burst every 60 s, and the
-- GetSortedAsync budget is only ~5 + 2 per player a minute):
--   * a board's rows are cached BOARD_TTL s (a board that came back empty: BOARD_TTL_COLD s -- most Boss Trial tiers);
--     a score submitted on this server marks the board dirty, re-read after BOARD_DIRTY_MIN s;
--   * a stale board returns its old rows at once and is queued; ONE reader drains the queue, one board at a time,
--     BOARD_READ_GAP s apart and only while the request budget keeps BOARD_BUDGET_KEEP spare (on-demand reads too);
--   * a board never read yet is read on the spot only if the budget allows it, else queued (an empty list meanwhile).
local BOARD_TTL, BOARD_TTL_COLD, BOARD_DIRTY_MIN = 180, 1800, 20
local BOARD_READ_GAP, BOARD_BUDGET_KEEP = 4, 2
local readQueue: { any } = {}
local queued: { [string]: boolean } = {}

local function SortedBudget(): number
    local ok, b = pcall(function() return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetSortedAsync) end)
    return ok and b or 0
end

local function ReadBoard(boardName: string, ascending: boolean, count: number)
    local rows = {}
    if readMemory then
        for key, v in pairs(memoryBoards[boardName] or {}) do table.insert(rows, { UserId = tonumber(key), Value = v }) end
        table.sort(rows, function(a, b) if ascending then return a.Value < b.Value end return a.Value > b.Value end)
        while #rows > count do table.remove(rows) end
    else
        boardDirty[boardName] = nil
        workspace:SetAttribute("BoardReads", (workspace:GetAttribute("BoardReads") or 0) + 1) -- (pacing probe)
        local ok, pages = pcall(function()
            return DataStoreService:GetOrderedDataStore(boardName .. BOARD_SUFFIX):GetSortedAsync(ascending, count)
        end)
        if not ok then
            -- keep what we had (a failed read must not blank a board); try again after the normal TTL
            local c = boardCache[boardName]
            if c then c.At = os.clock() return end
        elseif pages then
            for _, entry in ipairs(pages:GetCurrentPage()) do
                table.insert(rows, { UserId = tonumber(entry.key), Value = ascending and entry.value / 10 or entry.value })
            end
        end
    end
    for _, r in ipairs(rows) do r.Name = NameOf(r.UserId or 0) end
    boardCache[boardName] = { At = os.clock(), Rows = rows, Count = count }
end

local function Queue(boardName: string, ascending: boolean, count: number)
    if queued[boardName] then return end
    queued[boardName] = true
    table.insert(readQueue, { Name = boardName, Asc = ascending, Count = count })
end

task.spawn(function()
    while true do
        task.wait(BOARD_READ_GAP)
        if #readQueue > 0 and SortedBudget() > BOARD_BUDGET_KEEP then
            local job = table.remove(readQueue, 1)
            queued[job.Name] = nil
            local c = boardCache[job.Name]
            pcall(ReadBoard, job.Name, job.Asc, math.max(job.Count, c and c.Count or 0))
        end
    end
end)

local function Slice(rows: { any }, count: number): { any }
    if #rows <= count then return rows end
    local out = table.create(count)
    for i = 1, count do out[i] = rows[i] end
    return out
end

local function TopOf(boardName: string, ascending: boolean, count: number, ttl: number?): { any }
    if readMemory then
        local c = boardCache[boardName]
        if not c or os.clock() - c.At > 5 or c.Count < count or boardDirty[boardName] then
            boardDirty[boardName] = nil
            ReadBoard(boardName, ascending, count)
        end
        return Slice(boardCache[boardName].Rows, count)
    end
    local c = boardCache[boardName]
    if c then
        local age = os.clock() - c.At
        local life = (#c.Rows == 0) and BOARD_TTL_COLD or (ttl or BOARD_TTL)
        if age > life or c.Count < count or (boardDirty[boardName] and age > BOARD_DIRTY_MIN) then
            Queue(boardName, ascending, count)
        end
        return Slice(c.Rows, count)
    end
    if SortedBudget() > BOARD_BUDGET_KEEP then
        pcall(ReadBoard, boardName, ascending, count)
        if boardCache[boardName] then return Slice(boardCache[boardName].Rows, count) end
    end
    Queue(boardName, ascending, count)
    return {}
end

EndgameServer.TopOf = TopOf -- (UPDATE 7 LIVING HUB: the Hall of Aim statues read HIGHEST LEVEL)
local function Sync(player: Player, state: any)
    CombatServer.RecalculateMaxHealth(state)
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
end

local function InDungeon(player: Player): boolean
    local DungeonRuns = require(script.Parent:WaitForChild("DungeonRuns"))
    local PartyRuns = require(script.Parent:WaitForChild("PartyRuns"))
    return DungeonRuns.Attr(player, "RaidActive") == true or PartyRuns.RunOfPlayer(player) ~= nil
end

local function StatsOf(state: any): any
    local StatCalculator = require(Shared:WaitForChild("StatCalculator"))
    return StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
end

-- ===================== rifts / sigils =====================
function EndgameServer.GiveSigil(player: Player, state: any, sigil: any, quiet: boolean?)
    state.Sigils = type(state.Sigils) == "table" and state.Sigils or {}
    if AtlasData.Stats(state).K_ARTISAN and sigil.Rarity ~= "Normal" then -- (MAP TREE: Master Artisan)
        sigil.Rarity, sigil.Mods, sigil.Unique, sigil.Name = "Normal", {}, nil, nil
    end
    Rifts.Migrate(state) -- (0.61 ladder: an old bag shifts before a new sigil joins it)
    if #state.Sigils >= require(Shared:WaitForChild("StashTabs")).SigilCap(state) then -- (UPDATE 7: + MAP tabs)
        -- bag full: replace the lowest-tier sigil if this one is better
        local lowI, low = nil, math.huge
        for i, s in ipairs(state.Sigils) do if s.Tier < low then lowI, low = i, s.Tier end end
        if not lowI or low >= sigil.Tier then return end
        table.remove(state.Sigils, lowI)
    end
    table.insert(state.Sigils, sigil)
    if not quiet then
        local where = ((state.Level or 1) >= Rifts.MIN_LEVEL) and "open it at the map device in your hideout" or ("maps open at level " .. Rifts.MIN_LEVEL)
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "SIGIL: Tier " .. sigil.Tier .. " " .. string.upper(Rifts.DifficultyFor(sigil.Tier)) .. "  (" .. where .. ")")
    end
end

-- A boss died (CombatServer): sigil drop. (0.61: only from level 100, when maps open; an empty bag always gets a
-- Tier 1, so you're never locked out of maps. Ruin+ bosses drop their band's first tier, everything below Tier 1.)
function EndgameServer.OnBossKilled(player: Player, state: any, difficulty: string?, inRift: boolean)
    if inRift then return end
    if (state.Level or 1) < Rifts.MIN_LEVEL then return end
    Rifts.Migrate(state)
    local first = #(type(state.Sigils) == "table" and state.Sigils or {}) == 0
    if first then
        state.GotFirstSigil = true
        EndgameServer.GiveSigil(player, state, Rifts.NewSigil(Rifts.DropTier(difficulty)))
    elseif math.random() < Rifts.SIGIL_BOSS_CHANCE then
        EndgameServer.GiveSigil(player, state, Rifts.NewSigil(Rifts.DropTier(difficulty)))
    end
end

-- ===================== MAPS V2 L1 + L3 (2026-10-30): maps drop FROM maps =====================
-- A new map from a map source, after the map tree's rarity nodes (Keen Eye / Map Weaver: at least Charged, a third of that Rare;
-- Relic Seeker: Storied). GiveSigil still applies Master Artisan (Plain) and the bag-full rule.
function EndgameServer.MapSigil(tier: number, A: any?): any
    A = A or {}
    local r = math.random()
    local minR = (r < (A.SigilRarity or 0) / 3 and "Rare") or (r < (A.SigilRarity or 0) and "Magic") or nil
    if math.random() < (A.UniqueChance or 0) then return Rifts.NewSigil(tier, nil, "Unique") end
    return Rifts.NewSigil(tier, nil, nil, minR)
end
function EndgameServer.MapDropToast(player: Player, sigil: any, who: string)
    local rar = Rifts.RarityOf(sigil)
    local row = Rifts.RARITIES[rar]
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", string.format("%s A MAP: TIER %d %s  •  %s", who, sigil.Tier,
        string.upper(Rifts.DifficultyFor(sigil.Tier)), string.upper(Rifts.DisplayName(sigil))), row and row.Color or nil)
end
-- the solo map run a player is on (DungeonRuns run.Rift), or nil
local function MapRun(player: Player): (any, any)
    local run = require(script.Parent:WaitForChild("DungeonRuns")).Get(player)
    local rift = run and (run :: any).Rift
    return run, rift
end
-- a Charged / Rare elite died on a map floor (CombatServer GiveKillRewards): a small chance of a map (x the map's item quantity),
-- and (L3) a Chart Shard / a Sigil Mark
function EndgameServer.MapEliteDrop(player: Player, state: any, eliteTier: string)
    local run, rift = MapRun(player)
    if not rift or ((run.Config and run.Config.FloorNumber) or 1) >= Rifts.FLOORS then return end
    local A = rift.Atlas or {}
    local q = math.max(0, Rifts.Quantity(rift))
    local rare = eliteTier == "Rare"
    if math.random() < Rifts.MapDropChance(rare and "Rare" or "Magic", q, A) then
        local s = EndgameServer.MapSigil(Rifts.DropTierFrom(rift.Tier, "Floor", A), A)
        EndgameServer.GiveSigil(player, state, s, true)
        EndgameServer.MapDropToast(player, s, "AN ELITE DROPPED")
        ;(state :: any)._MapRefund = nil -- (QOL2 R5: a map that already paid a map back is never refunded on a quit)
    end
    local MD = Rifts.MAP_DROP
    local got = {}
    if math.random() < (rare and MD.EliteShardRare or MD.EliteShard) * (1 + q) then got.ChartShard = 1 end
    local MI = require(Shared:WaitForChild("MapInks"))
    if MI.ON and (state.Level or 1) >= MI.UNLOCK and math.random() < MD.EliteInk * (1 + q) then got[MI.Order[math.random(1, #MI.Order)]] = 1 end
    if next(got) then CombatServer.GrantMaterials(player, state, got, nil, true) end
end
-- (L3) the MAP CACHE: a map floor's victory chest by the exit portal (DungeonRuns OpenChest "Vault" on floors 1-4). A floor chest's
-- loot (1-2 items, gold, scrap, alloy) + the map's item quantity's extras (a 2nd item chance, gold) + per floor unit (a linked floor
-- = 2) a Chart Shard / Sigil Mark / map chance. The guardian's cache (RiftFinished) stays the big payout.
function EndgameServer.MapFloorCache(player: Player, run: any, units: number?)
    CombatServer.GiveFloorLoot(player, false)
    local state = CombatServer.GetState(player)
    local rift = run and run.Rift
    if not rift or not state then return end
    local A = rift.Atlas or {}
    local q = math.max(0, Rifts.Quantity(rift))
    local MD = Rifts.MAP_DROP
    local said = {}
    if q > 0 and math.random() < math.min(0.95, MD.CacheItemQty * q) then
        CombatServer.DropInFront(player, state)
        CombatServer.DropItemFor(player, state, StatsOf(state), 1.2 * (1 + ((Rifts :: any).Rarity and (Rifts :: any).Rarity(rift) or 0)))
        ;(state :: any)._DropAt = nil; (state :: any)._DropFan = nil
        table.insert(said, "+1 item")
    end
    local gold = math.round(MD.CacheGold * q * (1 + (CombatServer.ContentLevel(player, state) - 1) * 0.05))
    if gold > 0 then state.Gold += gold; table.insert(said, "+" .. ItemDataTop.FormatNumber(gold) .. " gold") end
    local MI = require(Shared:WaitForChild("MapInks"))
    local got, maps = {}, {}
    for _ = 1, math.max(1, math.floor(tonumber(units) or 1)) do
        if math.random() < MD.CacheShard * (1 + q) then got.ChartShard = (got.ChartShard or 0) + 1 end
        if MI.ON and (state.Level or 1) >= MI.UNLOCK and math.random() < MD.CacheInk * (1 + q) then
            local k = MI.Order[math.random(1, #MI.Order)]
            got[k] = (got[k] or 0) + 1
        end
        if math.random() < Rifts.MapDropChance("Cache", q, A) then
            local s = EndgameServer.MapSigil(Rifts.DropTierFrom(rift.Tier, "Floor", A), A)
            EndgameServer.GiveSigil(player, state, s, true)
            table.insert(maps, s)
        end
    end
    if next(got) then
        CombatServer.GrantMaterials(player, state, got, nil, true)
        for k, n in pairs(got) do table.insert(said, (n > 1 and (n .. " ") or "") .. ItemDataTop.MaterialDefs[k].Name) end
    end
    if #said > 0 then
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "MAP CACHE  •  " .. table.concat(said, ", "), Color3.fromRGB(150, 180, 255))
    end
    for _, s in ipairs(maps) do EndgameServer.MapDropToast(player, s, "THE CACHE HELD") end
    Sync(player, state)
end

-- Boss Trial cleared (DungeonRuns calls this): records, rewards, the exclusive drop roll, the leaderboard, then home.
function EndgameServer.BossTrialFinished(player: Player, trial: any, seconds: number)
    local state = CombatServer.GetState(player)
    local def = BossTrials.ById[trial.Id]
    if not (state and def) then return end
    local tier = math.clamp(math.floor(trial.Tier or 1), 1, BossTrials.MAX_TIER)
    state.BossTrials = type(state.BossTrials) == "table" and state.BossTrials or {}
    local prog = BossTrials.Progress(state, def.Id)
    local first = prog.Best < tier
    local AscendancyData = require(Shared:WaitForChild("AscendancyData"))
    local ascBefore = AscendancyData.PointsFor(state)
    if first then prog.Best = tier end
    local key = tostring(tier)
    local prevBest = prog.Times[key]
    local newBest = prevBest == nil or seconds < prevBest
    if newBest then prog.Times[key] = math.round(seconds * 10) / 10 end
    state.BossTrials[def.Id] = prog
    -- rewards
    local rw = BossTrials.Reward(tier, first, def.Major)
    state.Gold += rw.Gold
    CombatServer.GrantMaterials(player, state, { Prism = rw.Prism }, nil, true)
    if rw.Gem then CombatServer.DropGem(player, state, StatsOf(state), 2.0, rw.Gem) end
    local dropText -- (0.93: the old exclusive glove roll is gone; every boss drops exotics now)
    -- EXOTICS (0.53): major bosses drop one of their own exotics (BossTrials.EXOTIC_POOL / ExoticChance); rarity rolls at
    -- the tier's window, item level = yours, capped at the tier's monster level (+5) so low tiers stay low
    local pool = BossTrials.EXOTIC_POOL and BossTrials.EXOTIC_POOL[def.Id] -- (0.93: every boss, not just the majors)
    -- (0.86: x the tier falloff -- a trial far under your highest unlocked difficulty rolls exotics far less; first clears stay)
    local exoChance = BossTrials.ExoticChance(tier, first)
    if exoChance < 1 then exoChance *= ItemDataTop.ExoticFalloff(state, BossTrials.Tiers[tier] and BossTrials.Tiers[tier].Difficulty) end
    if pool and math.random() < exoChance then
        local t = BossTrials.Tiers[tier]
        local ml = ItemDataTop.MONSTER_LEVEL and ItemDataTop.MONSTER_LEVEL[t.Difficulty]
        local ilvl = math.max(1, math.min(state.Level or 1, ml and (ml[2] + 5) or (state.Level or 1)))
        -- (0.59: exotics are their own category -- always the TOP rarity of the tier for their power, not a random roll)
        local rarity = ItemDataTop.Rarities[ItemDataTop.MaxRarityRank(t.Difficulty)] or "Legendary"
        local tp = ItemDataTop.FilterRelics and ItemDataTop.FilterRelics(pool, t.Difficulty) or pool -- (UPDATE 8 LOOT: MinDiff + hooks)
        local id = tp[math.random(1, #tp)]
        local item = ItemDataTop.MakeExotic(id, rarity, ilvl)
        if item then
            local def2 = ItemDataTop.Exotics[id]
            if def2.Kind == "Weapon" then
                state.StatsTracking.DiscoveredWeapons[item.BaseId] = true
                table.insert(state.Inventory, item)
            else
                table.insert(state.GearInventory, item)
            end
            Remotes.GetEvent("LootAnnounce"):FireClient(player, item, nil, false)
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "RELIC DROP: " .. item.Name .. "!", ItemDataTop.EXOTIC_COLOR)
            dropText = (dropText and (dropText .. "  ") or "") .. "RELIC: " .. item.Name .. "!"
        end
    end
    -- BOSS TROPHY TITLES (0.93): tier VI+ only, never while outlevelled, x the tier falloff
    do
        local tt = ItemDataTop.TROPHY_TITLES and ItemDataTop.TROPHY_TITLES[def.Id]
        local tdiff = BossTrials.Tiers[tier] and BossTrials.Tiers[tier].Difficulty
        state.UnlockedTitles = state.UnlockedTitles or {}
        if tt and tier >= ItemDataTop.TROPHY_MIN_TIER and not table.find(state.UnlockedTitles, tt)
            and (state.Level or 1) <= ItemDataTop.TitleMaxLevel(tdiff)
            and math.random() < ItemDataTop.TrophyTitleChance(tier) * ItemDataTop.ExoticFalloff(state, tdiff) then
            table.insert(state.UnlockedTitles, tt)
            local tdef = ItemDataTop.Titles[tt]
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "TITLE DROP: " .. (tdef and tdef.Title or tt) .. "!  (equip it in TITLES)", tdef and tdef.Color or Color3.fromRGB(255, 215, 80))
            dropText = (dropText and (dropText .. "  ") or "") .. "TITLE: " .. (tdef and tdef.Title or tt) .. "!"
        end
    end
    -- THE WEEK (UPDATE 7, Weekly): the weekly boss's first clear this week pays the weekly stack; any trial counts for bounties
    local Weekly = require(Shared:WaitForChild("Weekly"))
    if trial.Apex then -- (UPDATE 7 C1 APEX HUNT: its own big reward, no board time)
        local parts = CombatServer.PayApex(player, state, trial.Apex == "Uber", def.Id, StatsOf(state))
        dropText = (dropText and (dropText .. "  ") or "") .. (trial.Apex == "Uber" and "UBER SUMMIT" or "THE SUMMIT") .. " FELL: " .. table.concat(parts, ", ") .. "!"
        CombatServer.ContractEvent(player, state, "Apex", 1, { Uber = trial.Apex == "Uber" })
    elseif trial.Weekly then
        local w = CombatServer.EnsureWeekly(player, state)
        if not w.BossDone and Weekly.BossOf().Id == def.Id and (state.Level or 1) >= Weekly.UNLOCK_BOSS then
            w.BossDone = true
            local parts = CombatServer.PayWeekly(player, state, Weekly.Reward(state.Level), StatsOf(state))
            dropText = (dropText and (dropText .. "  ") or "") .. "WEEKLY STACK: " .. table.concat(parts, ", ") .. "!"
        end
    else
        SubmitScore(BossTrials.Board(def.Id, tier), player, seconds, true) -- (a modified weekly run isn't a fair board time)
    end
    CombatServer.ContractEvent(player, state, "BossTrial", 1, { Id = def.Id, Tier = tier, Weekly = trial.Weekly ~= nil })
    CombatServer.AddSeasonXP(player, state, 400 + 150 * tier)
    local msg = string.format("%s TIER %s CLEARED in %d:%02d%s  +%s gold, +%d Prism%s", def.Name, BossTrials.Tiers[tier].Name,
        math.floor(seconds / 60), math.floor(seconds % 60), newBest and " (new best!)" or "", tostring(rw.Gold), rw.Prism,
        first and ". First clear bounty!" or "")
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "TRIAL CLEARED", def.Color)
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", msg)
    if dropText then Remotes.GetEvent("CombatFx"):FireClient(player, "Text", dropText) end
    local ascAfter = AscendancyData.PointsFor(state)
    if ascAfter > ascBefore then
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", string.format("SPECIALIZATION POINTS: %d / %d. Spend them from the passive tree (SPECIALIZATION)", ascAfter, AscendancyData.MAX_POINTS), Color3.fromRGB(255, 220, 140))
    end
    state.RunKeep = true -- anything that dropped in the fight is yours
    Sync(player, state)
    -- (owner 2026-10-03: "it auto returns you, this should not happen") you stay to loot; the gold RETURN TO HUB portal
    -- (DungeonGenerator.SpawnVictoryVault, TrialDone) takes you home
end

-- TRIAL OF ASCENSION cleared (DungeonRuns / PartyRuns call this): the first clear of a tier you were eligible for raises
-- AscTrialBest (+2 ascendancy points); every clear pays gold + Prism + a guaranteed item. Then the gold hub portal.
function EndgameServer.AscTrialFinished(player: Player, trial: any, seconds: number)
    local state = CombatServer.GetState(player)
    if not state then return end
    local tier = math.clamp(math.floor(tonumber(trial and trial.Tier) or 1), 1, AscensionTrials.MAX_TIER)
    local AscendancyData = require(Shared:WaitForChild("AscendancyData"))
    local before = AscendancyData.PointsFor(state)
    local best = AscensionTrials.Best(state)
    local eligible = AscensionTrials.CanStart(state, tier)
    local first = eligible and best < tier
    if first then state.AscTrialBest = tier end
    local rw = AscensionTrials.Reward(tier, first)
    state.Gold += rw.Gold
    CombatServer.GrantMaterials(player, state, { Prism = rw.Prism }, nil, true)
    CombatServer.DropInFront(player, state)
    CombatServer.DropItemFor(player, state, StatsOf(state), 2.5, rw.Item)
    CombatServer.AddSeasonXP(player, state, 500 + 200 * tier)
    local def = AscensionTrials.Tiers[tier]
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "THE PROVING " .. def.Name .. " CLEARED", AscensionTrials.Color)
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", string.format("%d:%02d  +%s gold, +%d Prism, a %s item%s", math.floor(seconds / 60), math.floor(seconds % 60),
        tostring(rw.Gold), rw.Prism, rw.Item, first and ". First clear bounty!" or ""))
    local after = AscendancyData.PointsFor(state)
    if after > before then
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", string.format("SPECIALIZATION POINTS: %d / %d. Spend them from the passive tree (SPECIALIZATION)", after, AscendancyData.MAX_POINTS), Color3.fromRGB(255, 220, 140))
    elseif not eligible and best < tier then
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "No points this time: " .. tostring(select(2, AscensionTrials.CanStart(state, tier))), Color3.fromRGB(255, 200, 150))
    end
    state.RunKeep = true
    Sync(player, state)
end

-- Rift guardian down (DungeonRuns calls this): the guardian's map drop, completion, loot, leaderboard.
function EndgameServer.RiftFinished(player: Player, rift: any, seconds: number)
    local state = CombatServer.GetState(player)
    -- (2026-10-22, owner: a finished map's run summary said EXTRACTED) the summary's word is MAP CLEARED (the hub portal keeps it)
    if CombatServer.RS and CombatServer.RS.Note then pcall(CombatServer.RS.Note, player, "MAPCLEARED") end
    local A = rift.Atlas or {}
    local limit = rift.Limit or Rifts.TIME_LIMIT
    local inTime = seconds <= limit
    -- (MAPS V2 L1 2026-10-30, owner: "maps drop from maps") no guaranteed next sigil: the guardian DROPS a map by chance
    -- (Rifts.MAP_DROP Guardian in time / GuardianOver), its tier around this one (Rifts.DROP_STEPS: in time it may climb, over time
    -- never). Map tree: SigilChance (Cartography) raises the chance, SigilTier one more step, Surveyor's Gamble = always in time
    -- (never more than +1), Race the Clock = a RaceSecond chance of a second one in time, Collector = never above this tier.
    local dropped = {}
    do
        local chance = Rifts.MapDropChance(inTime and "Guardian" or "GuardianOver", nil, A)
        if inTime and A.K_SURVEYOR then chance = 1 end
        local n = (math.random() < chance) and 1 or 0
        if inTime and A.K_RACE and math.random() < (Rifts.MAP_DROP.RaceSecond or 0) then n += 1 end
        for _ = 1, n do
            local s = EndgameServer.MapSigil(Rifts.DropTierFrom(rift.Tier, inTime and "InTime" or "OverTime", A), A)
            EndgameServer.GiveSigil(player, state, s, true)
            table.insert(dropped, s)
        end
    end
    local completion
    if inTime then
        if rift.Unique then state.UniquesDone = type(state.UniquesDone) == "table" and state.UniquesDone or {}; state.UniquesDone[rift.Unique] = true end
        -- (MAPS V2 L2) this map type beaten in time on this band = a COMPLETION (map points: AtlasData.PointsFor)
        local before = AtlasData.PointsFor(state)
        local new, band, typ = MapCompletion.Mark(state, rift)
        if new then
            local gain = AtlasData.PointsFor(state) - before
            completion = string.format("NEW COMPLETION: %s on %s  (%d / %d)%s", MapCompletion.Name(typ), string.upper(band),
                MapCompletion.Count(state), MapCompletion.Total(), gain > 0 and string.format("  •  +%d MAP POINT%s", gain, gain == 1 and "" or "S") or "")
        end
    end
    state.MapsDone = (tonumber(state.MapsDone) or 0) + 1
    local stats = StatsOf(state)
    -- (0.61 MAPS v2) Rifts.Reward: items at least Floor steps under the tier's top rarity, Top of them one step under
    local rw = Rifts.Reward(rift.Tier, inTime, rift, A) -- (0.62: the map's rarity / quantity / unique bonus; MAP TREE)
    local top = ItemDataTop.MaxRarityRank(Rifts.DifficultyFor(rift.Tier))
    -- (0.99n RARITY LADDER v3: relative "TopN" floors -- luck, never a guarantee; a NAMED rarity is a promise now, and these
    -- sat one to three steps under the tier's top: a guaranteed near-top drop every map)
    local function RarityAt(off: number): string return "Top" .. math.max(1, off) end
    for i = 1, rw.Items do
        CombatServer.DropItemFor(player, state, stats, rw.Luck, RarityAt(i <= rw.Top and 1 or rw.Floor))
    end
    -- (0.66 MAPS) Chart Shards (map-only currency) + a map-only exotic from the guardian (Rifts.EXOTICS)
    CombatServer.GrantMaterials(player, state, { ChartShard = Rifts.ShardsFor(rift.Tier, inTime) }, nil, true)
    -- (UPDATE 7 C1 APEX HUNT + C3 MAP INKS) Coordinates + Rift Taint from level 125, a map ink from 100
    do
        local AH = require(Shared:WaitForChild("ApexHunt"))
        local MI = require(Shared:WaitForChild("MapInks"))
        local got = {}
        local lvl = state.Level or 1
        if AH.ON and lvl >= AH.UNLOCK then
            if MI.Has(rift, "InkCompass") or math.random() < AH.COORD_CHANCE then
                local k = AH.COORDS[math.random(1, #AH.COORDS)]
                got[k] = 1
            end
            if math.random() < AH.TAINT_CHANCE then got.RiftTaint = 1 end
        end
        if MI.ON and lvl >= MI.UNLOCK then
            local n = (math.random() < MI.DROP_CHANCE and 1 or 0) + ((inTime and math.random() < 0.25) and 1 or 0)
            for _ = 1, n do
                local k = MI.Order[math.random(1, #MI.Order)]
                got[k] = (got[k] or 0) + 1
            end
        end
        if next(got) then
            CombatServer.GrantMaterials(player, state, got, nil, true)
            local t = {}
            for k, n in pairs(got) do table.insert(t, (n > 1 and (n .. " ") or "") .. ItemDataTop.MaterialDefs[k].Name) end
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "THE GUARDIAN DROPPED: " .. table.concat(t, ", "), Color3.fromRGB(255, 120, 160))
        end
    end
    if inTime and math.random() < Rifts.ExoticChance(rift.Tier, rift.Unique ~= nil, state.RiftBest) then
        -- (UPDATE 8 LOOT RELICS: the map-only relics x3 + every relic the map's difficulty allows)
        local id = ItemDataTop.RollRelicId and ItemDataTop.RollRelicId("Map", Rifts.DifficultyFor(rift.Tier)) or Rifts.EXOTICS[math.random(1, #Rifts.EXOTICS)]
        local rarity = ItemDataTop.Rarities[top] or "Legendary" -- (exotics: the tier's top rarity, like the major bosses')
        local item = ItemDataTop.MakeExotic(id, rarity, math.max(1, math.min(state.Level or 1, rift.Level or state.Level or 1)))
        if item then
            if item.BaseId then -- (UPDATE 8 LOOT: a map can drop a relic gun now)
                state.StatsTracking.DiscoveredWeapons[item.BaseId] = true
                table.insert(state.Inventory, item)
            else
                table.insert(state.GearInventory, item)
            end
            Remotes.GetEvent("LootAnnounce"):FireClient(player, item, nil, false)
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "MAP RELIC: " .. item.Name .. "!", ItemDataTop.EXOTIC_COLOR)
        end
    end
    if rw.AllIn then
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", inTime and "ALL IN: the guardian pays double!" or "ALL IN: over time, the guardian keeps its loot", Color3.fromRGB(255, 215, 80))
    end
    if inTime then
        for _ = 1, rw.Gems do CombatServer.DropGem(player, state, stats, rw.Luck, RarityAt(rw.Floor)) end
        CombatServer.GrantMaterials(player, state, { Prism = rw.Prism, Alloy = rw.Alloy }, rw.Chances, true, true) -- (LOOT SCARCITY: earned -> LOOT_SCARCITY.Mats)
        local gold = math.round(320 * (1 + (CombatServer.ContentLevel(player, state) - 1) * 0.05) * rw.GoldMult)
        state.Gold += gold
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", string.format("GUARDIAN CACHE  •  %d items (better odds), %d gem%s, +%s gold",
            rw.Items, rw.Gems, rw.Gems == 1 and "" or "s", ItemDataTop.FormatNumber(gold)), Color3.fromRGB(200, 150, 255))
        if rift.Tier > (state.RiftBest or 0) then state.RiftBest = rift.Tier end
        SubmitScore("RiftHighest", player, rift.Tier, false)
        SubmitScore("RiftWeekly_" .. EndgameServer.WeekOf(), player, rift.Tier, false)
    end
    local dropText = "the guardian dropped no map"
    if #dropped > 0 then
        local t = {}
        for _, s in ipairs(dropped) do table.insert(t, string.format("Tier %d %s", s.Tier, (Rifts.RARITIES[Rifts.RarityOf(s)] or {}).Name or "")) end
        dropText = (#dropped == 1 and "the guardian dropped a map: " or ("the guardian dropped " .. #dropped .. " maps: ")) .. table.concat(t, ", ")
    end
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", string.format("MAP T%d %s in %s  •  %s",
        rift.Tier, inTime and "CLEARED" or "FINISHED (over time)", DailyChallenge.FormatTime(seconds), dropText))
    if completion then Remotes.GetEvent("CombatFx"):FireClient(player, "Text", completion, Color3.fromRGB(255, 215, 80)) end
    CombatServer.ContractEvent(player, state, "Rift", 1, { InTime = inTime, Tier = rift.Tier })
    CombatServer.AddSeasonXP(player, state, Seasons.XP.RiftBase + Seasons.XP.RiftPerTier * rift.Tier * (inTime and 1 or 0.5))
    Sync(player, state)
end

-- ===================== leaderboard catalog, hub publishing, winner rewards =====================
-- Every board the game keeps. Kind: "time" (lower is better), "score", "tier", "level".
local function WeekOf(t: number?): number return (t or os.time()) // (7 * 86400) end
EndgameServer.WeekOf = WeekOf
local function Boards(day: number, week: number): { any }
    local list = {
        { Id = "Daily", Key = "Daily_" .. day, Title = "DAILY CHALLENGE  (today)", Kind = "time", Ascending = true },
        { Id = "Line", Key = "Line_" .. day, Title = "THE GAUNTLET RUN  (today)", Kind = "time", Ascending = true }, -- (UPDATE 7 B6)
        { Id = "RiftWeekly", Key = "RiftWeekly_" .. week, Title = "MAPS  (this week)", Kind = "tier" },
        { Id = "RiftHighest", Key = "RiftHighest", Title = "MAPS  (all time)", Kind = "tier", Ttl = 600 },
        { Id = "PlayerLevel", Key = "PlayerLevel", Title = "HIGHEST LEVEL", Kind = "level", Ttl = 600 },
    }
    for _, s in ipairs(AimTrials.Scenarios) do
        table.insert(list, { Id = "Trial_" .. s.Id, Key = "Trial_" .. s.Id .. "_" .. day, Title = string.upper(s.Name) .. "  (today)", Kind = "score" })
    end
    -- Boss Trials: fastest clear per boss per tier (all time)
    for _, b in ipairs(BossTrials.Bosses) do
        for t = 1, BossTrials.MAX_TIER do
            local key = BossTrials.Board(b.Id, t)
            table.insert(list, { Id = key, Key = key, Title = b.Name .. "  TIER " .. BossTrials.Tiers[t].Name .. "  (fastest clear)", Kind = "time", Ascending = true,
                Ttl = 900 }) -- (all-time boards: a clear on this server marks its board for a re-read anyway)
        end
    end
    return list
end
EndgameServer.Boards = Boards

-- Placement rewards for yesterday's daily boards and last week's rift board (top 10).
EndgameServer.PlaceRewards = {
    { Gold = 2000, Prism = 4, Gem = "Epic" }, { Gold = 1400, Prism = 3, Gem = "Rare" }, { Gold = 1000, Prism = 2, Gem = "Rare" },
}
EndgameServer.PlaceRewardRest = { Gold = 400, Prism = 1 } -- places 4-10
function EndgameServer.ClaimBoardRewards(player: Player)
    local state = CombatServer.GetState(player)
    state.BoardClaims = type(state.BoardClaims) == "table" and state.BoardClaims or {}
    local day, week = DailyChallenge.Today(), WeekOf()
    local past = { { Key = "Daily_" .. (day - 1), Title = "yesterday's Daily Challenge", Asc = true }, { Key = "RiftWeekly_" .. (week - 1), Title = "last week's map ladder" } }
    for _, s in ipairs(AimTrials.Scenarios) do table.insert(past, { Key = "Trial_" .. s.Id .. "_" .. (day - 1), Title = "yesterday's " .. s.Name }) end
    local paid = false
    for _, b in ipairs(past) do
        if not state.BoardClaims[b.Key] then
            local rows = TopOf(b.Key, b.Asc == true, 10)
            for place, r in ipairs(rows) do
                if r.UserId == player.UserId then
                    state.BoardClaims[b.Key] = true
                    local rw = EndgameServer.PlaceRewards[place] or EndgameServer.PlaceRewardRest
                    state.Gold += rw.Gold
                    CombatServer.GrantMaterials(player, state, { Prism = rw.Prism }, nil, true)
                    if rw.Gem then CombatServer.DropGem(player, state, StatsOf(state), 2.0, rw.Gem) end
                    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", string.format("LEADERBOARD REWARD: #%d on %s  (+%d gold, %d Prism%s)", place, b.Title, rw.Gold, rw.Prism, rw.Gem and (", " .. rw.Gem .. " gem") or ""))
                    paid = true
                    break
                end
            end
        end
    end
    -- forget claims older than two weeks
    for k in pairs(state.BoardClaims) do
        local n = tonumber(string.match(k, "_(%d+)$"))
        if n and n < day - 14 and not string.find(k, "RiftWeekly") then state.BoardClaims[k] = nil end
    end
    if paid then Sync(player, state) end
end

-- ===================== daily login calendar =====================
-- One reward per UTC day you play, cycling through 7 days (missing a day doesn't reset you -- it just waits).
EndgameServer.LoginRewards = {
    { Text = "300 gold", Gold = 300 },
    { Text = "15 Scrap, 3 Alloy", Mats = { Scrap = 15, Alloy = 3 } },
    { Text = "400 gold + a Prism Shard", Gold = 400, Mats = { Prism = 1 } },
    { Text = "a Tier 1 sigil (maps open at level 100)", Sigil = 1 },
    { Text = "3 Prism Shards", Mats = { Prism = 3 } },
    { Text = "800 gold + 6 Alloy", Gold = 800, Mats = { Alloy = 6 } },
    { Text = "GOLDEN CACHE: a Rare+ item, a Rare+ skill gem, 3 Prism Shards", Golden = true, Mats = { Prism = 3 } },
}
function EndgameServer.CheckLogin(player: Player)
    local state = CombatServer.GetState(player)
    local day = DailyChallenge.Today()
    local login = type(state.Login) == "table" and state.Login or { LastDay = 0, Count = 0 }
    if login.LastDay == day then return end
    login.LastDay = day
    login.Count = (login.Count or 0) + 1
    state.Login = login
    local idx = ((login.Count - 1) % #EndgameServer.LoginRewards) + 1
    local rw = EndgameServer.LoginRewards[idx]
    if rw.Gold then state.Gold += rw.Gold end
    if rw.Mats then CombatServer.GrantMaterials(player, state, rw.Mats, nil, true) end
    if rw.Sigil then EndgameServer.GiveSigil(player, state, Rifts.NewSigil(rw.Sigil), true) end
    if rw.Golden then
        local stats = StatsOf(state)
        CombatServer.DropItemFor(player, state, stats, 3.0, "Rare") -- (RARITY v4: was Epic)
        CombatServer.DropGem(player, state, stats, 2.0, "Rare")
    end
    CombatServer.AddSeasonXP(player, state, Seasons.XP.Login)
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", string.format("DAILY LOGIN  day %d of 7: %s", idx, rw.Text))
    Sync(player, state)
end

-- ===================== loot storms (server-wide timed event) =====================
EndgameServer.STORM_EVERY = 40 * 60
EndgameServer.STORM_LENGTH = 5 * 60
EndgameServer.STORM_FIRST = 10 * 60
function EndgameServer.StormActive(): boolean
    return workspace:GetServerTimeNow() < (workspace:GetAttribute("LootStormUntil") or 0)
end

-- ===================== THE DAILY LINE finish (UPDATE 7 B6; DungeonRuns calls this on floor 3's clear) =====================
function EndgameServer.LineFinished(player: Player, seconds: number)
    local state = CombatServer.GetState(player)
    local DailyLine = require(Shared:WaitForChild("DailyLine"))
    local rec = DailyLine.Record(state)
    if rec.Done then return end
    rec.Done, rec.Tried, rec.Time = true, true, math.round(seconds * 10) / 10
    state.DailyLine = rec
    local r = DailyLine.Reward(state.Level)
    state.Gold += r.Gold
    local mats = { Prism = r.Prism }
    for _ = 1, r.Currencies do
        local k = CombatServer.RandomUnlockedCurrency(state)
        if k then mats[k] = (mats[k] or 0) + 1 end
    end
    local MI = require(Shared:WaitForChild("MapInks"))
    for _ = 1, r.Ink do local k = MI.Order[math.random(1, #MI.Order)]; mats[k] = (mats[k] or 0) + 1 end
    CombatServer.GrantMaterials(player, state, mats, nil, true)
    local StatCalculator = require(Shared:WaitForChild("StatCalculator"))
    local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
    for _ = 1, r.Items do CombatServer.DropItemFor(player, state, stats, 2.5, "Top1") end
    local exo = ""
    if math.random() < r.Exotic then
        local id = ItemDataTop.RollRelicId("Boss", state.DungeonDifficulty) -- (UPDATE 8 LOOT: RelicPool)
        local item = id and ItemDataTop.MakeExotic(id, ItemDataTop.Rarities[ItemDataTop.MaxRarityRank(state.DungeonDifficulty)] or "Legendary", state.Level or 1)
        if item then
            if ItemDataTop.Exotics[id].Kind == "Weapon" then table.insert(state.Inventory, item) else table.insert(state.GearInventory, item) end
            Remotes.GetEvent("LootAnnounce"):FireClient(player, item, nil, false)
            exo = "  RELIC: " .. item.Name .. "!"
        end
    end
    SubmitScore("Line_" .. DailyLine.Today(), player, seconds, true)
    CombatServer.ContractEvent(player, state, "Line", 1)
    CombatServer.AddSeasonXP(player, state, Seasons.XP.DailyFirst or 800)
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "THE GAUNTLET RUN CLEARED in " .. DailyChallenge.FormatTime(seconds) .. ": +"
        .. ItemDataTop.FormatNumber(r.Gold) .. " gold, " .. r.Prism .. " Prism, currencies, Sigil Marks and " .. r.Items .. " top items." .. exo, DailyLine.COLOR)
    Sync(player, state)
end

-- ===================== daily challenge finish (DungeonRuns calls this) =====================
function EndgameServer.DailyFinished(player: Player, seconds: number)
    local state = CombatServer.GetState(player)
    local day = DailyChallenge.Today()
    local best = state.DailyBest
    if type(best) ~= "table" or best.Day ~= day then best = { Day = day, Time = math.huge, Rewarded = false } end
    local improved = seconds < (best.Time or math.huge)
    if improved then best.Time = seconds end
    local msg = "DAILY CHALLENGE CLEARED in " .. DailyChallenge.FormatTime(seconds) .. (improved and "  (new best!)" or "")
    CombatServer.AddSeasonXP(player, state, best.Rewarded and Seasons.XP.Daily or Seasons.XP.DailyFirst)
    if not best.Rewarded then
        best.Rewarded = true
        state.Gold += 600
        CombatServer.GrantMaterials(player, state, { Prism = 3, Alloy = 4 }, nil, true)
        local StatCalculator = require(Shared:WaitForChild("StatCalculator"))
        local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
        CombatServer.DropGem(player, state, stats, 2.0, "Rare")
        msg ..= ". First clear today: +600 gold, Prism Shards and a skill gem!"
    end
    state.DailyBest = best
    SubmitScore("Daily_" .. day, player, seconds, true)
    CombatServer.ContractEvent(player, state, "Daily", 1)
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", msg)
    Sync(player, state)
end

function EndgameServer.Init(combat: any)
    CombatServer = combat

    -- ----- Daily challenge -----
    Remotes.GetFunction("StartDailyChallenge").OnServerInvoke = function(player: Player): any
        if InDungeon(player) then return false, "Leave your current run first." end
        local DungeonRuns = require(script.Parent:WaitForChild("DungeonRuns"))
        local PartyService = require(script.Parent:WaitForChild("PartyService"))
        local state = CombatServer.GetState(player)
        local c = DailyChallenge.ForDay(DailyChallenge.Today())
        PartyService.Leave(player)
        state.DungeonDifficulty = c.Difficulty
        local info = DungeonRuns.StartFloor(player, {
            Biome = c.Biome, Difficulty = c.Difficulty, FloorNumber = 1, PlayerLevel = state.Level, BotSkill = c.BotSkill, Daily = true,
        })
        if not info then return false, "Couldn't start." end
        Remotes.GetEvent("DungeonUpdate"):FireClient(player, {
            Biome = info.Biome, Difficulty = c.Difficulty, Floor = 1, Remaining = DungeonRuns.Attr(player, "RemainingEnemies") or 0,
        })
        return true
    end

    -- ----- THE DAILY LINE (UPDATE 7 B6): one try a day, on the hardest difficulty you've unlocked -----
    EndgameServer.StartDailyLine = function(player: Player): (boolean, string?)
        if InDungeon(player) then return false, "Leave your current run first." end
        local DailyLine = require(Shared:WaitForChild("DailyLine"))
        local state = CombatServer.GetState(player)
        local ok, why = DailyLine.CanStart(state)
        if not ok then return false, why end
        local DungeonRuns = require(script.Parent:WaitForChild("DungeonRuns"))
        local PartyService = require(script.Parent:WaitForChild("PartyService"))
        local diff = ItemDataTop.DifficultyOrder[ItemDataTop.TopUnlockedRank(state)] or "Normal"
        local c = DailyLine.ForDay(DailyLine.Today())
        PartyService.Leave(player)
        state.DungeonDifficulty = diff
        local rec = DailyLine.Record(state)
        rec.Tried = true -- (the one try is spent when it starts)
        state.DailyLine = rec
        local info = DungeonRuns.StartFloor(player, {
            Biome = c.Biomes[1], Difficulty = diff, FloorNumber = 1, PlayerLevel = state.Level, BotSkill = c.BotSkill, Line = true,
        })
        if not info then rec.Tried = false; return false, "Couldn't start." end
        Remotes.GetEvent("DungeonUpdate"):FireClient(player, {
            Biome = info.Biome, Difficulty = diff, Floor = 1, Remaining = DungeonRuns.Attr(player, "RemainingEnemies") or 0,
        })
        Sync(player, state)
        return true
    end
    Remotes.GetFunction("StartDailyLine").OnServerInvoke = EndgameServer.StartDailyLine

    -- ----- Rifts -----
    -- (0.58: rifts open from the hideout MAP DEVICE now -- Hideouts "EnterPortal" calls this; the Challenges RIFTS tab is gone)
    function EndgameServer.StartRift(player: Player, uid: any, skillPick: any): (boolean, string?)
        if InDungeon(player) then return false, "Leave your current run first." end
        local state = CombatServer.GetState(player)
        local sigil, idx
        Rifts.Migrate(state)
        for i, s in ipairs(state.Sigils or {}) do if s.Uid == uid then sigil, idx = s, i end end
        if not sigil then return false, "Sigil not found." end
        if (state.Level or 1) < Rifts.MIN_LEVEL then return false, "Maps open at level " .. Rifts.MIN_LEVEL .. "." end
        local DungeonRuns = require(script.Parent:WaitForChild("DungeonRuns"))
        local PartyService = require(script.Parent:WaitForChild("PartyService"))
        PartyService.Leave(player)
        table.remove(state.Sigils, idx) -- consumed
        local diff = Rifts.DifficultyFor(sigil.Tier)
        state.DungeonDifficulty = diff
        -- (MAP TREE) the tree's stats for this map: level / skill / timer keystones now, the rest on the floors + the cache
        local A = AtlasData.Stats(state)
        local level = Rifts.MapLevel(sigil, state.Level)
        if A.K_DEEP then level = math.min(level + 5, (state.Level or 1) + 15, ItemDataTop.MAX_LEVEL_BUILT) end -- (FUTURE-PROOF: was 400)
        -- bot skill: the map device's pick (1-10) or the map's own roll; Hunter's Pact forces 10
        local pick = tonumber(skillPick)
        if pick ~= pick then pick = nil end -- (BOT MOVEMENT POE review: a NaN pick from the client)
        local skill = A.K_HUNTER and 10 or (pick and math.clamp(math.floor(pick), 1, 10)) or Rifts.SkillOf(sigil)
        -- (BOT MOVEMENT POE) the map's bots move at `skill` (Standard unless the device / Hunter's Pact picked one); its guardian keeps
        -- the pace it had (the old roll), and the map pays Rifts.MapReward(skill) (DevMoveOld: the old reward = the skill's own)
        -- (review) the guardian is NEVER easier than its map's roll: a pick only makes it faster (max), so "4" can't beat STANDARD
        local moveOld = game:GetService("RunService"):IsStudio() and workspace:GetAttribute("DevMoveOld") == true
        local bossSkill = A.K_HUNTER and 10 or math.max(Rifts.LegacySkill(sigil), pick and math.clamp(math.floor(pick), 1, 10) or 0)
        if moveOld then bossSkill = A.K_HUNTER and 10 or (pick and math.clamp(math.floor(pick), 1, 10)) or Rifts.LegacySkill(sigil) end -- (A/B: the old rule)
        local skillReward = (not moveOld) and Rifts.MapReward(skill) or nil
        local limit = Rifts.TimeLimit(sigil.Tier) + (A.Time or 0) -- (2026-10-22: per tier, from measured map floors)
        if A.K_RACE then limit = math.round(limit * 0.5) end
        if table.find(sigil.Mods or {}, "SHORT_FUSE") then -- (0.66 map mod Short Fuse; MAPS V2: x0.7 at T1, shorter on higher tiers)
            limit = math.round(limit * (1 - require(Shared:WaitForChild("FloorMods")).V("SHORT_FUSE", Rifts.ModScale(sigil.Tier))))
        end
        local info = DungeonRuns.StartFloor(player, {
            Biome = sigil.Biome or "Fire", Difficulty = diff, FloorNumber = 1, PlayerLevel = state.Level, BotSkill = skill,
            Rift = { Uid = sigil.Uid, Tier = sigil.Tier, Mods = sigil.Mods, Rarity = Rifts.RarityOf(sigil), Unique = sigil.Unique, Name = sigil.Name, Layout = Rifts.LayoutOf(sigil), Biome = sigil.Biome, -- (0.62 MAPS v3)
                Guardian = sigil.Guardian, GBand = sigil.GBand, -- (MAPS V2: the guardian the device showed, Rifts.GuardianOf)
                Corrupted = sigil.Corrupted, Quality = sigil.Quality, Ruptured = sigil.Ruptured, RuptureQty = sigil.RuptureQty, RuptureRar = sigil.RuptureRar, -- (MAPS V2: quantity / rarity / boosting reach the guardian + floors)
                Level = level, PowerLevel = Rifts.PowerLevel(sigil, level), Skill = skill, BossSkill = bossSkill, SkillReward = skillReward, -- (BOT MOVEMENT POE: bots at Standard, the guardian's pace, the reward)
                Limit = limit, Atlas = A, Inks = sigil.Inks }, -- (map level = yours + 0..10, MAP TREE; UPDATE 7 MAP INKS)
        })
        if not info then
            table.insert(state.Sigils, sigil)
            return false, "Couldn't open the map."
        end
        Remotes.GetEvent("DungeonUpdate"):FireClient(player, {
            Biome = info.Biome, Difficulty = diff, Floor = 1, Remaining = DungeonRuns.Attr(player, "RemainingEnemies") or 0,
        })
        pcall(function() require(script.Parent.RunAgain).Note(player, { Kind = "Map", Tier = sigil.Tier, Biome = sigil.Biome, Skill = pick }) end) -- (QOL F1: RUN AGAIN = another map of this tier)
        pcall(function() require(script.Parent.MapRefund).Opened(state, sigil) end) -- (QOL2 R5: leaving the game before floor 1 is cleared returns it once)
        Sync(player, state)
        return true
    end
    Remotes.GetFunction("StartRift").OnServerInvoke = EndgameServer.StartRift

    -- ----- Boss Trials: one endgame boss fight at a tier (tier 1 open; each clear unlocks the next) -----
    -- mode (owner 2026-10-05: "challenge boss fights dont have multiplayer option, but when you start one it brings all
    -- players with you"): "Party" = the room's host takes the whole room; "Solo" (or nil) = only you, your room stays put
    -- weekly = true: THIS WEEK'S BOSS (UPDATE 7, Weekly): the week's boss at the tier your level reaches, with the week's
    -- modifier (config.WeeklyMod); its first clear of the week pays the weekly stack (BossTrialFinished)
    -- apex = "Apex" | "Uber" (UPDATE 7 C1, from ApexAction only): the APEX modifier instead of the week's, no unlock checks
    EndgameServer.StartBossTrial = function(player: Player, id: any, tier: any, mode: any, weekly: any, apex: any): (boolean, string?) -- (+ DevCmd "weekly")
        if InDungeon(player) then return false, "Leave your current run first." end
        local def = type(id) == "string" and BossTrials.ById[id]
        tier = tonumber(tier)
        if not def or not tier or def.MapOnly then return false, "Unknown trial." end -- (MAPS V2: a maps-only boss has no trial)
        tier = math.clamp(math.floor(tier), 1, BossTrials.MAX_TIER)
        local state = CombatServer.GetState(player)
        local Weekly = require(Shared:WaitForChild("Weekly"))
        local weeklyMod = nil
        if apex == "Apex" or apex == "Uber" then
            weeklyMod = (apex == "Uber") and "UBER_APEX" or "APEX"
        elseif weekly == true then
            if not Weekly.ON then return false, "The Week's Quarry is off." end
            if (state.Level or 1) < Weekly.UNLOCK_BOSS then return false, "The Week's Quarry unlocks at level " .. Weekly.UNLOCK_BOSS .. "." end
            if Weekly.BossOf().Id ~= def.Id or Weekly.TierFor(state.Level) ~= tier then return false, "That isn't this week's boss." end
            weeklyMod = Weekly.ModOf()
        elseif not BossTrials.Unlocked(state, def.Id, tier) and not RunService:IsStudio() then
            return false, "Clear tier " .. BossTrials.Tiers[tier - 1].Name .. " first."
        end
        -- (0.52 tiers VI-X: also the difficulty's level, like the dungeon tiers)
        local minLv = BossTrials.MinLevel(tier)
        if not weeklyMod and (state.Level or 1) < minLv and not RunService:IsStudio() then return false, "Tier " .. BossTrials.Tiers[tier].Name .. " needs level " .. minLv .. "." end
        local DungeonRuns = require(script.Parent:WaitForChild("DungeonRuns"))
        local PartyService = require(script.Parent:WaitForChild("PartyService"))
        local t = BossTrials.Tiers[tier]
        -- WITH PARTY: the room's host starts it for everyone in the room (boss health x players -- PartyRuns)
        if mode == "Party" and not apex then
            local pok, pwhy = PartyService.StartSpecial(player, { BossTrial = { Id = def.Id, Tier = tier, Weekly = weeklyMod }, Difficulty = t.Difficulty,
                FloorNumber = BossTrials.FLOOR, Biome = def.Biome, FixedBiome = def.Biome, BotSkill = 5, WeeklyMod = weeklyMod })
            if pok == nil then return false, "Open a party room first (2+ players)." end
            return pok, pwhy
        end
        PartyService.Leave(player)
        state.DungeonDifficulty = t.Difficulty
        local info = DungeonRuns.StartFloor(player, {
            Biome = def.Biome, Difficulty = t.Difficulty, FloorNumber = BossTrials.FLOOR, PlayerLevel = state.Level, BotSkill = 5,
            BossTrial = { Id = def.Id, Tier = tier, Weekly = weeklyMod, Apex = (apex == "Apex" or apex == "Uber") and apex or nil }, WeeklyMod = weeklyMod,
        })
        if not info then return false, "Couldn't start the trial." end
        Remotes.GetEvent("DungeonUpdate"):FireClient(player, {
            Biome = def.Biome, Difficulty = t.Difficulty, Floor = BossTrials.FLOOR, Remaining = DungeonRuns.Attr(player, "RemainingEnemies") or 0,
            Trial = (apex and ((apex == "Uber" and "UBER SUMMIT: " or "THE SUMMIT: ") .. def.Name .. "  TIER " .. t.Name))
                or ((weeklyMod and "WEEKLY: " or "") .. def.Name .. "  TIER " .. t.Name .. (weeklyMod and ("  •  " .. Weekly.Mods[weeklyMod].Name) or "")),
        })
        Sync(player, state)
        return true
    end
    Remotes.GetFunction("StartBossTrial").OnServerInvoke = function(player, id, tier, mode, weekly)
        return EndgameServer.StartBossTrial(player, id, tier, mode, weekly) -- (a client can't pass the apex flag: ApexAction does)
    end

    -- ----- APEX HUNT (UPDATE 7 C1): "Start"(uber) uses one (two for the Uber) of each Coordinate and starts the fight -----
    EndgameServer.ApexAction = function(player: Player, action: any, uber: any): (boolean, string?)
        local state = CombatServer.GetState(player)
        if not state or action ~= "Start" then return false, "?" end
        local AH = require(Shared:WaitForChild("ApexHunt"))
        uber = uber == true
        local ok, why = AH.CanStart(state, uber)
        if not ok then return false, why end
        if InDungeon(player) then return false, "Leave your current run first." end
        local Weekly = require(Shared:WaitForChild("Weekly"))
        local tier = Weekly.TierFor(state.Level)
        if uber then tier = math.min(BossTrials.MAX_TIER, tier + 1) end
        local boss = AH.BOSSES[math.random(1, #AH.BOSSES)]
        local need = AH.Need(uber)
        for _, k in ipairs(AH.COORDS) do state.Materials[k] -= need end
        local sok, swhy = EndgameServer.StartBossTrial(player, boss, tier, "Solo", nil, uber and "Uber" or "Apex")
        if not sok then
            for _, k in ipairs(AH.COORDS) do state.Materials[k] += need end
            Sync(player, state)
            return false, swhy
        end
        return true, (uber and "The Summit Unbound" or "The Summit") .. " is waiting."
    end
    Remotes.GetFunction("ApexAction").OnServerInvoke = EndgameServer.ApexAction

    -- ----- THE WEEK (UPDATE 7, Weekly): "Reroll"(i) swaps an unfinished bounty (Weekly.REROLLS a week + mastery rank) -----
    EndgameServer.WeeklyAction = function(player: Player, action: any, i: any): (boolean, string?)
        local state = CombatServer.GetState(player)
        local Weekly = require(Shared:WaitForChild("Weekly"))
        if not state or (state.Level or 1) < Weekly.UNLOCK_BOUNTIES then return false, "The Job Board unlocks at level " .. Weekly.UNLOCK_BOUNTIES .. "." end
        local w = CombatServer.EnsureWeekly(player, state)
        if action == "Reroll" then
            local allowed = Weekly.REROLLS + Weekly.ExtraRerolls(state)
            if (w.Rerolls or 0) >= allowed then return false, "No rerolls left this week." end
            local idx = math.floor(tonumber(i) or 0)
            local c = w.Bounties[idx]
            if not c then return false, "Pick a bounty." end
            if c.Done then return false, "That bounty is already done." end
            local new = Weekly.Reroll(w.Bounties, idx, state.Level)
            if not new then return false, "Nothing to swap it for." end
            w.Rerolls = (w.Rerolls or 0) + 1
            Sync(player, state)
            return true, "New bounty: " .. Weekly.Text(new)
        end
        return false, "?"
    end
    Remotes.GetFunction("WeeklyAction").OnServerInvoke = EndgameServer.WeeklyAction

    -- ----- Trial of Ascension (AscensionTrials): two hard floors + The Ascendant; solo, or the host of a party room -----
    Remotes.GetFunction("StartAscTrial").OnServerInvoke = function(player: Player, tier: any, mode: any): (boolean, string?)
        if InDungeon(player) then return false, "Leave your current run first." end
        tier = tonumber(tier)
        if not tier or not AscensionTrials.Tiers[math.floor(tier)] or math.floor(tier) > AscensionTrials.MAX_TIER then return false, "Unknown trial." end -- (LAUNCH CAP)
        tier = math.floor(tier)
        local state = CombatServer.GetState(player)
        local can, why = AscensionTrials.CanStart(state, tier)
        if not can and not RunService:IsStudio() then return false, why end
        local def = AscensionTrials.Tiers[tier]
        local DungeonRuns = require(script.Parent:WaitForChild("DungeonRuns"))
        local PartyService = require(script.Parent:WaitForChild("PartyService"))
        if mode == "Party" then -- (WITH PARTY: the host takes the room; SOLO: only you)
            local pok, pwhy = PartyService.StartSpecial(player, { AscTrial = { Tier = tier }, Difficulty = def.Difficulty, FloorNumber = 1, BotSkill = 5 })
            if pok == nil then return false, "Open a party room first (2+ players)." end
            return pok, pwhy
        end
        PartyService.Leave(player)
        state.DungeonDifficulty = def.Difficulty
        local info = DungeonRuns.StartFloor(player, {
            Biome = "Fire", Difficulty = def.Difficulty, FloorNumber = 1, PlayerLevel = state.Level, BotSkill = 5,
            AscTrial = { Tier = tier },
        })
        if not info then return false, "Couldn't start the trial." end
        Remotes.GetEvent("DungeonUpdate"):FireClient(player, {
            Biome = info.Biome, Difficulty = def.Difficulty, Floor = 1, Remaining = DungeonRuns.Attr(player, "RemainingEnemies") or 0,
            Trial = "THE PROVING " .. def.Name,
        })
        Sync(player, state)
        return true
    end

    -- ----- Season journey: claim every reached tier -----
    Remotes.GetFunction("ClaimSeason").OnServerInvoke = function(player: Player): (boolean, string?)
        local state = CombatServer.GetState(player)
        local s = Seasons.Ensure(state)
        local tier = Seasons.TierOf(s.XP)
        local got = 0
        local function Give(r: any)
            state.Gold += r.Gold or 0
            if r.BP and CombatServer.GrantBoundPoints then CombatServer.GrantBoundPoints(player, state, r.BP) end -- (0.93)
            if r.Mats and next(r.Mats) then CombatServer.GrantMaterials(player, state, r.Mats, nil, true) end
            if r.Sigil then EndgameServer.GiveSigil(player, state, Rifts.NewSigil(r.Sigil), true) end
            if r.Gem then CombatServer.DropGem(player, state, StatsOf(state), 2.0, r.Gem) end
            if r.Title and not table.find(state.UnlockedTitles, r.Title) then table.insert(state.UnlockedTitles, r.Title) end
            -- the season's final reward (premium tier 50): a list of "Category:Id" (the arms' glove + sleeve and the knife)
            for _, ref in ipairs(r.Cosmetics or (r.Cosmetic and { r.Cosmetic }) or {}) do
                local cat, id = string.match(ref, "^(.-):(.*)$")
                if cat then pcall(CombatServer.GrantCosmetic, player, state, cat, id, false) end
            end
        end
        for t = 1, tier do
            local key = tostring(t)
            if not s.Claimed[key] then
                s.Claimed[key] = true
                Give(Seasons.Reward(t))
                got += 1
            end
            -- the premium row (once the pass is owned; tiers reached before buying are claimable too)
            if s.Premium and not s.ClaimedP[key] then
                s.ClaimedP[key] = true
                Give(Seasons.PremiumReward(t))
                got += 1
            end
        end
        if got == 0 then return false, "Nothing to claim yet." end
        Sync(player, state)
        return true, "Claimed " .. got .. " season reward" .. (got == 1 and "" or "s") .. "!"
    end

    -- ----- Aim trials -----
    local trialStarts: { [Player]: { Id: string, At: number } } = {}
    Remotes.GetFunction("BeginTrial").OnServerInvoke = function(player: Player, id: any, diffId: any): boolean
        if type(id) ~= "string" or not AimTrials.ById[id] or InDungeon(player) then return false end
        local d = (type(diffId) == "string" and AimTrials.DifficultyById[diffId]) or AimTrials.DifficultyById.Standard
        trialStarts[player] = { Id = id, At = os.clock(), Diff = d }
        return true
    end
    Remotes.GetFunction("SubmitTrial").OnServerInvoke = function(player: Player, id: any, score: any, hits: any, shots: any): any
        local def = type(id) == "string" and AimTrials.ById[id]
        local start = trialStarts[player]
        trialStarts[player] = nil
        if not def or not start or start.Id ~= id then return false end
        -- the run must have actually lasted (countdown + duration, with slack) and the score must be possible
        local elapsed = os.clock() - start.At
        if elapsed < def.Duration - 1 or elapsed > def.Duration + 30 then return false end
        if type(score) ~= "number" or score ~= score or score < 0 or score > def.MaxScore * (start.Diff and start.Diff.Mult or 1) then return false end
        score = math.floor(score)
        local state = CombatServer.GetState(player)
        -- every run pays a little (first RUN_REWARDS_PER_DAY runs of the day)
        local today = DailyChallenge.Today()
        if type(state.TrialRuns) ~= "table" or state.TrialRuns.Day ~= today then state.TrialRuns = { Day = today, N = 0 } end
        local runReward = nil
        if state.TrialRuns.N < AimTrials.RUN_REWARDS_PER_DAY and score > 0 then
            state.TrialRuns.N += 1
            runReward = AimTrials.RunReward(score)
            state.Gold += runReward.Gold
            if runReward.Scrap > 0 then CombatServer.GrantMaterials(player, state, { Scrap = runReward.Scrap }, nil, true, true) end -- (LOOT SCARCITY: earned)
        end
        state.TrialBest = type(state.TrialBest) == "table" and state.TrialBest or {}
        state.TrialRanks = type(state.TrialRanks) == "table" and state.TrialRanks or {}
        local prevBest = state.TrialBest[id] or 0
        local isBest = score > prevBest
        if isBest then state.TrialBest[id] = score end
        local rank = AimTrials.RankOf(id, score)
        local oldRank = state.TrialRanks[id] or 0
        local unlocked = {}
        if rank > oldRank then
            state.TrialRanks[id] = rank
            local StatCalculator = require(Shared:WaitForChild("StatCalculator"))
            for r = oldRank + 1, rank do
                local name = AimTrials.RankName(r)
                local rw = AimTrials.RankRewards[name]
                if rw then
                    state.Gold += rw.Gold or 0
                    CombatServer.GrantMaterials(player, state, rw.Mats, nil, true)
                    if rw.Gem then
                        local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
                        CombatServer.DropGem(player, state, stats, 2.0, rw.Gem)
                    end
                end
                table.insert(unlocked, name)
                CombatServer.AddSeasonXP(player, state, Seasons.XP.TrialRank)
            end
        end
        SubmitScore("Trial_" .. id .. "_" .. DailyChallenge.Today(), player, score, false)
        CombatServer.ContractEvent(player, state, "Trial", score, { Id = id, Rank = rank })
        local rankedUp = CombatServer.MasteryExam(player, state, id, rank) -- (UPDATE 7 MASTERY RANK: the exam)
        Sync(player, state)
        return { Score = score, Best = math.max(score, prevBest), IsBest = isBest, Rank = rank, Unlocked = unlocked, Reward = runReward,
            RunsLeft = AimTrials.RUN_REWARDS_PER_DAY - state.TrialRuns.N, MasteryRankUp = rankedUp or nil }
    end

    -- ----- everything the Challenges window shows -----
    Remotes.GetFunction("GetChallengeData").OnServerInvoke = function(player: Player): any
        local day = DailyChallenge.Today()
        local out = { Day = day, Daily = DailyChallenge.ForDay(day), DailyBoard = TopOf("Daily_" .. day, true, 10), TrialBoards = {},
            LineBoard = TopOf("Line_" .. day, true, 10), -- (UPDATE 7 B6)
            RiftBoard = TopOf("RiftHighest", false, 10), RiftWeekly = TopOf("RiftWeekly_" .. WeekOf(), false, 10) }
        for _, s in ipairs(AimTrials.Scenarios) do
            out.TrialBoards[s.Id] = TopOf("Trial_" .. s.Id .. "_" .. day, false, 10)
        end
        return out
    end

    Players.PlayerRemoving:Connect(function(p) trialStarts[p] = nil end)

    -- daily login reward a few seconds after joining (the client is ready by then)
    local function SubmitLevel(p: Player)
        local st = CombatServer.GetState(p)
        SubmitScore("PlayerLevel", p, (st.Level or 1) * 10000, false) -- (x10000: old scores carried a Paragon tiebreak)
    end
    EndgameServer.SubmitLevel = SubmitLevel
    local function OnJoin(p: Player)
        task.delay(8, function()
            if p.Parent then pcall(EndgameServer.CheckLogin, p) end
            if p.Parent then pcall(EndgameServer.ClaimBoardRewards, p) end
            if p.Parent then pcall(SubmitLevel, p) end
            -- (0.61: old sigils move onto the level 100+ ladder)
            local st = p.Parent and CombatServer.GetState(p)
            if st and Rifts.Migrate(st) then pcall(Sync, p, st) end
        end)
    end
    Players.PlayerAdded:Connect(OnJoin)
    for _, p in ipairs(Players:GetPlayers()) do OnJoin(p) end

    -- Hub leaderboards: every board's top 50 is published to ReplicatedStorage.Leaderboards (JSON StringValues,
    -- refreshed every 60 s); the client draws them on the Hall of Fame boards. Online players' levels and
    -- yesterday's placement rewards are re-checked on the same beat.
    task.spawn(function()
        local HttpService = game:GetService("HttpService")
        local folder = game.ReplicatedStorage:FindFirstChild("Leaderboards") or Instance.new("Folder")
        folder.Name = "Leaderboards"
        folder.Parent = game.ReplicatedStorage
        local beat = 0
        while true do
            beat += 1
            local day, week = DailyChallenge.Today(), WeekOf()
            for i, b in ipairs(Boards(day, week)) do
                local ok, rows = pcall(TopOf, b.Key, b.Ascending == true, 50, b.Ttl)
                if ok then
                    local out = {}
                    for place, r in ipairs(rows) do
                        local v = r.Value
                        local shown
                        if b.Kind == "time" then shown = DailyChallenge.FormatTime(v)
                        elseif b.Kind == "tier" then shown = "Tier " .. tostring(v)
                        elseif b.Kind == "level" then
                            local lv, pg = math.floor((v or 0) / 10000), (v or 0) % 10000
                            shown = "Lv " .. lv .. ((pg > 0) and ("  P" .. pg) or "")
                        else shown = tostring(v) end
                        table.insert(out, { Rank = place, Name = r.Name, Value = shown, UserId = r.UserId })
                    end
                    local sv = folder:FindFirstChild("B" .. i) or Instance.new("StringValue")
                    sv.Name = "B" .. i
                    sv:SetAttribute("Title", b.Title)
                    sv:SetAttribute("Kind", b.Kind)
                    sv:SetAttribute("Id", b.Id) -- stable id the in-menu leaderboard buttons look boards up by
                    local js = HttpService:JSONEncode(out)
                    if sv.Value ~= js then sv.Value = js end -- (no replication when nothing changed)
                    sv.Parent = folder
                end
            end
            if beat % 5 == 0 then
                for _, p in ipairs(Players:GetPlayers()) do
                    pcall(SubmitLevel, p)
                    pcall(EndgameServer.ClaimBoardRewards, p)
                end
            end
            task.wait(60)
        end
    end)

    -- loot storm schedule (attributes on workspace replicate to everyone)
    task.spawn(function()
        local nextAt = workspace:GetServerTimeNow() + EndgameServer.STORM_FIRST
        workspace:SetAttribute("NextLootStorm", nextAt)
        while true do
            task.wait(1)
            local now = workspace:GetServerTimeNow()
            if now >= nextAt then
                workspace:SetAttribute("LootStormUntil", now + EndgameServer.STORM_LENGTH)
                nextAt = now + EndgameServer.STORM_EVERY
                workspace:SetAttribute("NextLootStorm", nextAt)
                for _, p in ipairs(Players:GetPlayers()) do
                    Remotes.GetEvent("CombatFx"):FireClient(p, "Text", "LOOT STORM! 5 minutes of +50% loot luck, XP and gold, double gem drops")
                end
            end
        end
    end)
end

return EndgameServer
