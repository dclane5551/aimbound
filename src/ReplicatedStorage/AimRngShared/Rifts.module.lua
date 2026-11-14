--!nocheck
-- ============================================================================================
-- RIFTS (the endgame key loop: Diablo 3 Greater Rifts / Diablo 4 Nightmare Sigils / PoE maps).
-- A SIGIL is a key with a TIER and 1-3 rolled floor modifiers. Use one (the MAP DEVICE in your hideout's map room, 0.58) to open
-- a timed 5-floor rift (floor 5 = the Rift Guardian, a boss). Higher tiers = tougher enemies, more modifiers,
-- better loot. (MAPS V2 2026-10-30: maps DROP inside maps -- the guardian, map elites, map caches: Rifts.MAP_DROP; the old
-- "beat the timer = a sigil one tier higher" is gone.) Your highest tier beaten in time is on the leaderboard.
-- Sigils drop from bosses (every boss kill: SIGIL_BOSS_CHANCE; the first boss ever: guaranteed Tier 1).
-- A sigil is consumed when the rift starts. Dying ends the attempt.
-- State: Sigils = { { Uid, Tier, Mods = {ids} } } (cap MAX_SIGILS), RiftBest = highest tier beaten in time.
-- MAPS v2 (0.61, owner: "the map scaling no longer makes sense, maps should unlock at level 100+ and offer far better loot
-- for harder challenges"): maps are the level 100+ endgame. The map device (and StartRift) refuse below MIN_LEVEL, and
-- sigils only drop from bosses once you're 100 (an empty bag always gets one). Tiers climb the top six difficulties
-- three at a time (1-3 Ruin, 4-6 Dread, 7-9 Apocalypse, 10-12 Annihilation, 13-15 Eternity, 16+ Singularity); monsters
-- keep that difficulty's monster level, health grows 8% a tier inside a band (and keeps growing past 16). The guardian
-- pays Rifts.Reward(tier): 3-8 items at least two steps under the tier's top rarity, 1-3 of them one step under, gems,
-- materials and gold. Old sigils (Tier 1-50 on the 0.53 ladder, no V field) shift down 25 tiers once (Rifts.Migrate).
-- MAP LEVEL + BOT SKILL (owner after 0.63: "Maps should be within 10 of your level range so you can actually use loot,
-- and the bot difficulty should always be 6+ (randomized)"): a map's monsters are YOUR level + 0..10 (Rifts.MapLevel:
-- deeper tier steps and rarer maps sit higher), fixed when the map opens, so every drop is wearable. The tier still
-- picks the difficulty (rarity window, challenge, +8% health a step). Every map rolled a bot skill 6..10 (sigil.Skill) --
-- (BOT MOVEMENT POE 2026-10-30, owner: T12 map bots "moving so fast that they arent even fun to shoot" -> "do what POE does":
-- tier makes monsters tougher, not faster) every map now plays at the STANDARD bot skill (Rifts.MAP_SKILL 4); the map device's
-- BOT SKILL row is the opt-in (faster bots, more reward); the old roll only sets the guardian's pace (Rifts.LegacySkill, so the
-- bosses are unchanged) and the map pays Rifts.MapReward(skill) (Standard = the old roll's average: map loot doesn't drop).
-- ============================================================================================
local HttpService = game:GetService("HttpService")
local Rifts = {}

Rifts.FLOORS = 5
Rifts.TIME_LIMIT = 300 -- (old flat limit for all 5 floors; kept for old callers -- the timer is Rifts.TimeLimit(tier) now)
-- (2026-10-22, owner after the autoplay map runs: an average build never made the 300 s clock -- one LINKED map floor alone took
-- 365 s on Ruin and ~600 s on Annihilation, full clear, 0.65-ish build) the map timer per TIER, from those measured floors: 2 linked
-- floors + the guardian (~120 s) + ~10-20% margin, before LinkedRooms.MAP_TIME (x1.1 on linked maps) and the map tree / Short Fuse.
-- T1 820 .. T12 1425 s (x1.1 linked: 902 .. 1568 s = 15:02 .. 26:08).
Rifts.TIME_BASE, Rifts.TIME_PER_TIER = 820, 55
function Rifts.TimeLimit(tier: number?): number
    return Rifts.TIME_BASE + Rifts.TIME_PER_TIER * (math.max(1, math.floor(tonumber(tier) or 1)) - 1)
end
Rifts.MAX_SIGILS = 30
Rifts.SIGIL_BOSS_CHANCE = 0.35
Rifts.MIN_LEVEL = 100 -- (0.61: maps open at level 100; HideoutData.MAP_ROOM.Level matches)
Rifts.BAND = 3 -- tiers per difficulty
Rifts.VERSION = 2 -- sigil.V (0.61 ladder)
Rifts.LADDER = { "Ruin", "Dread", "Apocalypse", "Annihilation", "Eternity", "Singularity" }
-- (0.62 MAPS v3) the bigger pool: the regular risks + the map-only mods (FloorMods MapOnly)
local MOD_POOL = { "FRENZIED", "FORTIFIED", "SWARMING", "ELITE_PACK", "GLASS_ARENA", "HEADHUNTER", "KEEP_DISTANCE",
    "BRUTAL", "NO_REGEN", "ARMORED", "SHARPSHOOTERS", "RELENTLESS", "SMALL_TARGETS", "ELEMENTAL",
    "SHORT_FUSE", "EMPOWERED", "STEEL_SKIN", "MENDING", "ALL_IN", -- (0.66: + the five risk / reward map mods)
    -- (UPDATE 8 MAPS ON THE NEW SYSTEMS: typed damage, resists, Ward, packs, elites -- FloorMods defs)
    "EXTRA_HEAT", "EXTRA_CRYO", "EXTRA_VOLT", "EXTRA_VOID", "RESIST_HEAT", "RESIST_CRYO", "RESIST_VOLT", "RESIST_VOID",
    "WARDED", "MAX_RES_DOWN", "SLOW_WARD", "LOW_AGILITY", "BIG_PACKS", "RARE_ELITES", "COMMANDERS" }
Rifts.MOD_POOL = MOD_POOL

-- ===== 0.66 MAPS PASS (NEXT_LIST C8 / C9) =====
-- GUARDIANS: every tier band has its own guardian on floor 5 -- a trial boss with its full mechanics, at map strength
-- (DungeonGenerator.CreateTrialBoss with the ":G" archetype: health from the Titan's formula x GUARDIAN_HP). The trial
-- tier only sets its pace. (Before 0.66 the guardian was the Titan or the biome boss on every tier.)
Rifts.GUARDIANS = {
    -- (MAPS V2 2026-10-30: Annihilation's pace 8 -> 9 -- it fought at Apocalypse's trial pace; now every open band is a step faster)
    Ruin = { Boss = "Archon", Pace = 6 }, Dread = { Boss = "Chronarch", Pace = 7 }, Apocalypse = { Boss = "EchoWarden", Pace = 8 },
    Annihilation = { Boss = "Forgeheart", Pace = 9 }, Eternity = { Boss = "Broodmother", Pace = 9 }, Singularity = { Boss = "Duelist", Pace = 10 },
}
Rifts.GUARDIAN_HP = { Normal = 1, Major = 1.1 } -- (0.99u BOSS PACE: x a ~30 s guardian fight, DungeonGenerator.BossHp; was 1.3 / 0.8 x the Titan's health)
-- (0.92, owner: "Why do all maps appear to have the same guardian?" -- one guardian per BAND meant every map you farm had
-- the same boss). Each MAP now rolls its guardian from every trial + major boss, picked by the map's Uid (stable: the
-- device shows the boss you will meet, old sigils included). The band still sets the pace (+ the health via GUARDIAN_HP).
Rifts.GUARDIAN_POOL = { "Archon", "Chronarch", "EchoWarden", "Forgeheart", "Lockwarden", "Broodmother", "Duelist", "FortuneEngine" }
-- (FUTURE-PROOF 2026-10-25) a map's guardian is STORED on it (sigil.Guardian: NewSigil, and Migrate stamps the older ones) -- picked
-- by Uid % #GUARDIAN_POOL, a new guardian in the pool reassigned most existing maps after the device had shown their boss. A
-- band without a GUARDIANS row takes the TOP band's pace (a new harder band must not fight like Ruin).
function Rifts.HashGuardian(uid: string): string
    local h = 0
    for i = 1, #uid do h = (h * 31 + string.byte(uid, i)) % 1000003 end
    return Rifts.GUARDIAN_POOL[h % #Rifts.GUARDIAN_POOL + 1]
end
-- ===== MAPS V2 (2026-10-30, owner picked "a boss per band"): BAND GUARDIAN POOLS =====
-- Every band has its own 2-3 guardians; a map rolls one of its band's by its Uid (the same hash, inside the band's list), so
-- the device still shows the boss you will meet. Lower bands get the plainer fights, the top open band the hardest ones +
-- THE LAMPLIGHTER (the maps-only boss, BossTrials.MapBosses). The band still sets pace + health (GUARDIANS row, GUARDIAN_HP)
-- and the target rounds ask for more hits a band (BossAI M.AimNeed, GUARDIAN_AIM). STORIED maps keep the guardian they
-- rolled from the old all-boss GUARDIAN_POOL (frozen above: never add to it, or Storied maps without a stored pick reshuffle).
-- A sigil stores its pick + the band it was picked for (sigil.Guardian / sigil.GBand: NewSigil, Migrate). A map whose tier
-- moves into another band (a corruption) re-picks inside the new band, by the same Uid. FUTURE-PROOF: a new band = a new row
-- here (a band without one takes the top row); a new guardian = append to a band's list (maps that already stored theirs keep it).
Rifts.BAND_GUARDIANS = {
    Ruin = { "Archon", "Chronarch" },
    Dread = { "EchoWarden", "Forgeheart" },
    Apocalypse = { "Lockwarden", "Broodmother" },
    Annihilation = { "Duelist", "FortuneEngine", "Lamplighter" },
    -- (closed at launch: the top open band's pool until those bands get their own bosses)
    Eternity = { "Duelist", "FortuneEngine", "Lamplighter" },
    Singularity = { "Duelist", "FortuneEngine", "Lamplighter" },
}
Rifts.GUARDIAN_AIM = 0.08 -- (target-round hits needed: +8% a band above Ruin, BossAI M.AimNeed via config.GuardianBand)
function Rifts.BandPool(band: string?): { string }
    return Rifts.BAND_GUARDIANS[band or ""] or Rifts.BAND_GUARDIANS[Rifts.LADDER[#Rifts.LADDER]] or Rifts.GUARDIAN_POOL
end
function Rifts.PickGuardian(uid: string, band: string?): string
    local pool = Rifts.BandPool(band)
    local h = 0
    for i = 1, #uid do h = (h * 31 + string.byte(uid, i)) % 1000003 end
    return pool[h % #pool + 1]
end
-- stamp sigil.Guardian / GBand for its current band (Storied: its old pick only); true when something changed
function Rifts.StampGuardian(s: any): boolean
    if type(s) ~= "table" or type(s.Uid) ~= "string" then return false end
    if s.Unique then
        if type(s.Guardian) ~= "string" then s.Guardian = Rifts.HashGuardian(s.Uid); return true end
        return false
    end
    local band = Rifts.DifficultyFor(tonumber(s.Tier) or 1)
    if type(s.Guardian) == "string" and s.GBand == band then return false end
    s.Guardian, s.GBand = Rifts.PickGuardian(s.Uid, band), band
    return true
end
function Rifts.GuardianOf(tier: number, sigil: any?): any
    local bandName = Rifts.DifficultyFor(tier)
    local band = Rifts.GUARDIANS[bandName] or Rifts.GUARDIANS[Rifts.LADDER[#Rifts.LADDER]] or Rifts.GUARDIANS.Ruin
    if type(sigil) ~= "table" then return band end
    local uid = type(sigil.Uid) == "string" and sigil.Uid or nil
    local boss
    if sigil.Unique then -- (STORIED: the guardian it always had)
        boss = (type(sigil.Guardian) == "string" and sigil.Guardian) or (uid and Rifts.HashGuardian(uid)) or nil
    elseif type(sigil.Guardian) == "string" and sigil.GBand == bandName then
        boss = sigil.Guardian
    elseif uid then
        boss = Rifts.PickGuardian(uid, bandName)
    end
    if not boss then return band end
    return { Boss = boss, Pace = band.Pace }
end
-- the roster archetype for a map's guardian ("Archon:6:G")
function Rifts.GuardianArchetype(tier: number, sigil: any?): string
    local g = Rifts.GuardianOf(tier, sigil)
    return g.Boss .. ":" .. g.Pace .. ":G"
end
-- MAP-ONLY EXOTICS: only a map guardian drops these (in time). 2% + 0.25% a tier (max 8%), double on a Unique map.
Rifts.EXOTICS = { "WayfinderCompass", "AtlasMantle", "RiftLens" }
-- (0.86, owner: exotics at "a super super low drop chance"): 0.4% + 0.05% a tier, max 1.5% (was 2% .. 8%), x2 on a
-- Unique map; best = your RiftBest -- full chance within 5 tiers of it, then x ItemData.EXOTIC_FALLOFF per 5 tiers lower
function Rifts.ExoticChance(tier: number, unique: boolean?, best: number?): number
    local c = math.min(0.015, 0.004 + 0.0005 * math.max(1, tier)) * (unique and 2 or 1)
    local gap = math.floor((math.max(0, (best or tier) - tier)) / 5)
    if gap > 1 then c *= 0.25 ^ (gap - 1) end
    return c
end
-- CHART SHARDS (map-only currency, ItemData material "ChartShard"): 30% per map floor cleared before the guardian, and
-- the guardian cache (in time 2 + tier / 5, over time 1). Spent on the CHART / CORRUPT / ENGRAVE crafts below.
Rifts.SHARD_FLOOR_CHANCE = 0.3
function Rifts.ShardsFor(tier: number, inTime: boolean): number
    return inTime and (2 + math.floor(math.max(1, tier) / 5)) or 1
end
-- ===== MAPS V2 L1 (2026-10-30, owner: "maps drop from maps"; contract docs/MAPS_V2_2026-10-30.md) =====
-- A finished map no longer hands back a sigil. Sigils DROP INSIDE maps: the guardian (big chance; in time it may climb, over time
-- it stays at the map's tier), Magic / Rare elites and the floor caches (small chances, x the map's item quantity at
-- QuantityShare). Death = the map is gone, drops already found stay. Every number here is read by tools/sim/mapsupply.py --
-- re-run it after a change (targets in the contract: ~70% in-time player sustains ~1.0-1.15 maps a map at T1-9, T12 in ~35-60
-- maps, T12 sustain ~0.9-1.0 without the map tree, ~1.05-1.15 with the Cartography nodes).
-- Shard / Ink rows (L3): Chart Shards + Sigil Marks from map elites and floor caches (x the map's quantity too).
Rifts.MAP_DROP = {
    Guardian = 0.85, GuardianOver = 0.50, -- the guardian drops a map: in time / over time
    RaceSecond = 0.80, -- (map tree Race the Clock) the chance of a second guardian map in time
    Magic = 0.025, Rare = 0.05, -- a map elite (Charged / Rare) drops a map
    Cache = 0.035, -- a MAP CACHE holds a map: a roll per floor unit (a linked map floor = LinkedRooms.FLOOR_STEP 2 rolls)
    QuantityShare = 0.5, QuantityCap = 1.0, -- elites + caches: chance x (1 + QuantityShare x the map's item quantity (Rifts.Quantity), counted up to QuantityCap)
    EliteShard = 0.06, EliteShardRare = 0.12, EliteInk = 0.02, -- an elite (Charged / Rare) drops a Chart Shard / a Sigil Mark, x (1 + quantity)
    CacheShard = 0.30, CacheInk = 0.04, -- a MAP CACHE, per floor unit, x (1 + quantity): a Chart Shard (was 30% a floor unit at the clear) / a Sigil Mark
    CacheItemQty = 0.5, CacheGold = 100, -- a MAP CACHE's extras on top of a floor chest: a 2nd item chance (x quantity), + gold x quantity
}
-- the tier of a map drop: { tier offset from the map's tier, weight }. InTime / OverTime = the guardian, Floor = elites + caches.
Rifts.DROP_STEPS = {
    InTime = { { -1, 5 }, { 0, 40 }, { 1, 40 }, { 2, 15 } },
    OverTime = { { -1, 30 }, { 0, 70 } },
    Floor = { { -1, 25 }, { 0, 50 }, { 1, 25 } },
}
-- the tier a drop of `kind` ("InTime" | "OverTime" | "Floor") from a map of `tier` comes out at. A = AtlasData.Stats or {}:
-- SigilTier = a chance of one more step up, K_COLLECTOR = never above the map, K_SURVEYOR = never more than one above it.
function Rifts.DropTierFrom(tier: number, kind: string, A: any?, rng: Random?): number
    A = A or {}
    local r = rng or Random.new()
    local rows = Rifts.DROP_STEPS[kind] or Rifts.DROP_STEPS.Floor
    local total = 0
    for _, w in ipairs(rows) do total += w[2] end
    local x, off = r:NextNumber() * total, 0
    for _, w in ipairs(rows) do
        x -= w[2]
        if x <= 0 then off = w[1]; break end
    end
    if off >= 0 and r:NextNumber() < (A.SigilTier or 0) then off += 1 end
    if A.K_COLLECTOR then off = math.min(off, 0) end
    if A.K_SURVEYOR then off = math.min(off, 1) end
    return math.clamp(math.floor(tonumber(tier) or 1) + off, 1, Rifts.MaxTier())
end
-- the chance a map source drops a sigil. src = "Guardian" | "GuardianOver" | "Magic" | "Rare" | "Cache"; q = the map's item
-- quantity (elites + caches only); A = AtlasData.Stats (SigilChance: + every source)
function Rifts.MapDropChance(src: string, q: number?, A: any?): number
    if game:GetService("RunService"):IsStudio() and type(workspace:GetAttribute("DevMapDrop")) == "number" then -- (Studio test hook: every map source drops at this chance)
        return workspace:GetAttribute("DevMapDrop")
    end
    local c = Rifts.MAP_DROP[src] or 0
    if src ~= "Guardian" and src ~= "GuardianOver" then c *= 1 + Rifts.MAP_DROP.QuantityShare * math.clamp(tonumber(q) or 0, 0, Rifts.MAP_DROP.QuantityCap or 1) end
    return math.min(1, c * (1 + ((A or {}).SigilChance or 0)))
end
local BIOMES = { "Fire", "Ice", "Cyber", "Void", "Storm", "Dream", "Flats" }
do -- (0.87 WORLDS: maps roll the worlds too)
    local ok, WB = pcall(require, script.Parent:WaitForChild("WorldBiomes"))
    if ok then for _, id in ipairs(WB.LIST) do table.insert(BIOMES, id) end end
end
Rifts.BIOMES = BIOMES -- (MAPS V2 L2: the map types MapCompletion tracks = these + every Storied map)

-- LAUNCH CAP (ItemData.CONTENT_CAP): the bands whose difficulty is closed are gone -- sigils stop at the last open band's top
-- tier (12 at a 200 cap: Ruin / Dread / Apocalypse / Annihilation); older sigils above it play and show as that tier.
function Rifts.MaxTier(): number
    if Rifts._maxTier then return Rifts._maxTier end
    local ok, ID = pcall(function() return require(script.Parent:WaitForChild("ItemData")) end)
    if not (ok and type(ID) == "table" and ID.DifficultyOpen) then return 1 end -- (FUTURE-PROOF: never cache "no cap" off a failed require)
    local n = 0
    for i, d in ipairs(Rifts.LADDER) do if ID.DifficultyOpen(d) then n = i else break end end
    Rifts._maxTier = (n >= #Rifts.LADDER) and math.huge or math.max(1, n * Rifts.BAND)
    return Rifts._maxTier
end
-- tier -> (band index into LADDER, step inside the band: 0..2, past the last band it keeps counting)
local function Band(tier: number): (number, number)
    tier = math.min(math.max(1, math.floor(tonumber(tier) or 1)), Rifts.MaxTier()) -- (LAUNCH CAP)
    local b = math.min(#Rifts.LADDER, (tier - 1) // Rifts.BAND + 1)
    return b, tier - ((b - 1) * Rifts.BAND + 1)
end
Rifts.Band = Band
function Rifts.DifficultyFor(tier: number): string
    return Rifts.LADDER[(Band(tier))]
end
-- the first tier of a difficulty on the ladder (nil below Ruin)
function Rifts.FirstTierOf(difficulty: string?): number?
    local i = table.find(Rifts.LADDER, difficulty or "")
    return i and (i - 1) * Rifts.BAND + 1 or nil
end
-- enemy health on top of the difficulty's own: +8% a tier inside the band (Singularity: past tier 16, no end)
function Rifts.HealthMult(tier: number): number
    local _, step = Band(tier)
    return 1.08 ^ step
end
-- Floor reward bonus (XP, gold and loot luck through DungeonRuns' ModReward / FloorLuckMult), on top of the mods' own.
-- (0.61: 0.15 x tier -> 0.5 + 0.1 x tier: Tier 1 +60%, Tier 10 +150%, Tier 20 +250%)
function Rifts.RewardBonus(tier: number): number
    return 0.5 + 0.1 * math.max(1, tier)
end
-- What the Rift Guardian pays (EndgameServer.RiftFinished). Rarity offsets count down from the tier's top rarity
-- (ItemData.MaxRarityRank of its difficulty): Floor = every item at least that many steps under the top, Top = how many
-- of the items are only one step under. Over the time limit: one item at the floor, nothing else.
-- (0.62 MAPS v3) sigil = the map that was run: its QUANTITY adds items (each full 25% = +1, the rest a chance), a Rare
-- map +1 Top item, a Unique map its own Bonus (items / top items / gold).
-- (MAP TREE) A = AtlasData.Stats(state) or nil: quantity, top items, gems, gold, materials, Prism, keystones
function Rifts.Reward(tier: number, inTime: boolean, sigil: any?, A: any?): any
    tier = math.max(1, math.floor(tier))
    if not inTime then
        local allIn = sigil and table.find(sigil.Mods or {}, "ALL_IN") ~= nil -- (0.66 All In: nothing over time)
        return { Items = allIn and 0 or 1, Top = 0, Floor = 2, Gems = 0, Luck = 2 + tier * 0.2, Prism = 0, Alloy = 0, GoldMult = 0, Chances = {}, AllIn = allIn }
    end
    A = A or {}
    local q = sigil and Rifts.Quantity(sigil) or 0
    local normal = Rifts.RarityOf(sigil) == "Normal"
    q += (A.Quantity or 0) + (normal and (A.NormalQuantity or 0) or 0)
    if A.K_HUNTER then q += 0.4 end
    if A.K_DEEP then q += 0.25 end
    if A.K_CLEAN then q += normal and 0.6 or -0.2 end
    q = math.max(0, q)
    local extra = math.floor(q / 0.25) + ((math.random() < (q % 0.25) / 0.25) and 1 or 0)
    local u = sigil and sigil.Unique and Rifts.UNIQUES[sigil.Unique]
    local rare = sigil and Rifts.RarityOf(sigil) == "Rare"
    local mats = 1 + (A.Mats or 0)
    local r = {
        Items = math.max(1, math.min(8, 3 + tier // 3) + extra + (u and u.Bonus.Items or 0) + (A.K_COLLECTOR and 2 or 0) - (A.K_GOLDEN and 2 or 0)),
        Top = math.min(3, (tier + 3) // 6) + (rare and 1 or 0) + (u and u.Bonus.Top or 0) + (A.TopItems or 0) + (A.K_COLLECTOR and 1 or 0) + (A.K_RACE and 1 or 0),
        Quantity = q,
        Floor = 2,
        Gems = 1 + (tier >= 8 and 1 or 0) + (tier >= 16 and 1 or 0) + (A.Gems or 0),
        Luck = (3 + tier * 0.25) * (1 + Rifts.Rarity(sigil)), -- (MAPS V2: the map's ITEM RARITY)
        Prism = math.round((3 + tier) * mats) + (A.Prism or 0), Alloy = math.round((8 + 2 * tier) * mats),
        GoldMult = (4 + tier) * (u and u.Bonus.Gold or 1) * (1 + q) * (1 + (A.Gold or 0)), -- x an objective's gold at the rift's monster level
        Chances = { Prism = math.min(1, 0.6 + 0.04 * tier) }, -- (0.97 CRAFTING v4: the retired currencies' chances -> one more Prism)
    }
    for k, v in pairs(r.Chances) do r.Chances[k] = math.min(1, v * mats) end
    if sigil and table.find(sigil.Mods or {}, "ALL_IN") then r.Items *= 2; r.AllIn = true end -- (0.66 map mod: double or nothing)
    r.Top = math.min(r.Top, r.Items)
    return r
end
-- MAP LEVEL: your level + an offset 0..10 (+2 per step inside the tier's band, Magic +2 / Rare +4 / Unique +6)
local RARITY_LEVEL = { Normal = 0, Magic = 2, Rare = 4, Unique = 6 }
function Rifts.LevelOffset(sigil: any): number
    local _, step = Band(type(sigil) == "table" and sigil.Tier or 1)
    return math.min(10, step * 2 + (RARITY_LEVEL[Rifts.RarityOf(sigil)] or 0))
end
function Rifts.MapLevel(sigil: any, level: number): number
    return math.clamp(math.floor(tonumber(level) or 1) + Rifts.LevelOffset(sigil), 1, require(script.Parent:WaitForChild("ItemData")).MAX_LEVEL_BUILT) -- (FUTURE-PROOF: was 400)
end
-- (MAP PACING 2026-10-31, owner: "Make it more akin to POE") the map's POWER level = its map level without the rarity's part:
-- a Rare map's +4 levels made every monster ~26% tougher (LevelCurve 1.06 a level: bots via GetScalingMultiplier, the guardian
-- via BossHp) on top of its mods -- in PoE a map's rarity never changes the monsters' level. Enemy health / damage use this
-- (config.PowerLevel); loot item level, XP and gold keep the full map level, so the rarity still pays.
function Rifts.PowerOffset(sigil: any): number
    local _, step = Band(type(sigil) == "table" and sigil.Tier or 1)
    return math.min(10, step * 2)
end
function Rifts.PowerLevel(sigil: any, mapLevel: number): number
    return math.max(1, math.floor(tonumber(mapLevel) or 1) - math.max(0, Rifts.LevelOffset(sigil) - Rifts.PowerOffset(sigil)))
end
-- BOT SKILL 6..10, rolled per map (maps from before this pick one from their Uid, so it never changes). (BOT MOVEMENT POE) that
-- roll is the LEGACY skill now: the guardian's pace (StartRift -> BossSkill) and the Studio A/B (workspace DevMoveOld = the old
-- maps); the bots of a map move at SkillOf = MAP_SKILL. New sigils still write Skill (same random stream; ignored for the bots).
Rifts.SKILL_MIN, Rifts.SKILL_MAX = 6, 10
Rifts.MAP_SKILL = 4 -- (DungeonGenerator.DEFAULT_BOT_SKILL: "Standard")
-- the map's kill-reward multiplier at a bot-skill step (CombatServer.RewardMultFor reads the run folder's SkillReward): Standard
-- = 1.59, the average of the old 6-10 roll's BotSkillLevels rewards (1.25 / 1.4 / 1.55 / 1.75 / 2.0); lower steps scale like the
-- Dungeons window (x their reward / Standard's). (BOT MOVEMENT POE review) the steps ABOVE Standard pay for the difficulty MEASURED
-- with tools/move_probe.luau on T12 maps (docs/BOT_MOVEMENT_2026-10-30.md "REVIEW ROUND": angular speed across the screen, p90 +
-- p99 vs Standard): 5-7 ~x1.35, 8-9 ~x1.5, 10 ~x1.75 -- the steps inside one group measured the same (the readability cap + the
-- step's own tempo), so they pay the same; reward = 1.59 x (1 + 0.35 x (difficulty - 1)), 10 = 2.0 = the old top
Rifts.MAP_REWARD = { 1.19, 1.32, 1.46, 1.59, 1.79, 1.79, 1.79, 1.86, 1.86, 2.0 }
function Rifts.MapReward(skill: number?): number
    local s = math.clamp(math.floor(tonumber(skill) or Rifts.MAP_SKILL), 1, #Rifts.MAP_REWARD)
    return Rifts.MAP_REWARD[s]
end
local function MoveOld(): boolean
    return game:GetService("RunService"):IsStudio() and workspace:GetAttribute("DevMoveOld") == true
end
function Rifts.SkillOf(sigil: any): number
    if not MoveOld() then return Rifts.MAP_SKILL end
    return Rifts.LegacySkill(sigil)
end
function Rifts.LegacySkill(sigil: any): number
    if type(sigil) ~= "table" then return Rifts.SKILL_MIN end
    local s = tonumber(sigil.Skill)
    if s then return math.clamp(math.floor(s), Rifts.SKILL_MIN, Rifts.SKILL_MAX) end
    local h = 7
    for i = 1, #tostring(sigil.Uid or "") do h = (h * 33 + string.byte(tostring(sigil.Uid), i)) % 10007 end
    return Rifts.SKILL_MIN + h % (Rifts.SKILL_MAX - Rifts.SKILL_MIN + 1)
end
-- (FUTURE-PROOF 2026-10-25) how many mods a map of this rarity + tier rolls: its RARITIES span (Charged 1-2); a Rare uses
-- Rifts.ModCount(tier) (MAPS V2: 4-6, more on higher tiers). RARE_BONUS is the pre-V2 rule (+1 from T10), kept for old callers.
Rifts.RARE_BONUS = { Tier = 10, Mods = 1 }
function Rifts.ModRoll(rarity: string, tier: number, r: Random): number
    if rarity == "Rare" then
        local lo, hi = Rifts.ModCount(tier)
        return r:NextInteger(lo, hi)
    end
    local row = Rifts.RARITIES[rarity]
    local span = row and row.Mods or { 0, 0 }
    return r:NextInteger(span[1], span[2])
end
-- (MAPS V2 2026-10-30) a Rare map's mod count by tier: (lo, hi). APPEND rows for higher bands (the last row whose Tier <= the
-- map's tier wins). T1-3 4, T4-6 4-5, T7-9 5, T10+ 5-6.
Rifts.RARE_MODS = { { Tier = 1, Lo = 4, Hi = 4 }, { Tier = 4, Lo = 4, Hi = 5 }, { Tier = 7, Lo = 5, Hi = 5 }, { Tier = 10, Lo = 5, Hi = 6 } }
function Rifts.ModCount(tier: number): (number, number)
    local t, row = tonumber(tier) or 1, Rifts.RARE_MODS[1]
    for _, r in ipairs(Rifts.RARE_MODS) do if t >= r.Tier then row = r end end
    return row.Lo, row.Hi
end
-- (MAPS V2 2026-10-30, owner: "mods scale with tier") how strong a map's mods are: T1 x1.0 .. T12 x1.6 of their base value (and
-- of their quantity / rarity reward). Past T12 (future bands) it keeps climbing at the same rate. FloorMods.V / TextOf read it.
Rifts.MOD_SCALE_TOP, Rifts.MOD_SCALE_AT = 1.6, 12
function Rifts.ModScale(tier: number?): number
    local t = math.max(1, math.floor(tonumber(tier) or 1))
    return 1 + (Rifts.MOD_SCALE_TOP - 1) * (t - 1) / (Rifts.MOD_SCALE_AT - 1)
end

-- ===== MAPS v3 (0.62, owner: "maps need WAY more depth to them ... make them like POE maps and included rarities") =====
-- Every map (sigil) has a RARITY: Normal (no mods), Magic (1-2), Rare (4-6 by tier, Rifts.ModCount), Unique (a named map with
-- its own fixed mods and a bigger guardian cache). Each mod adds item QUANTITY (Rifts.Quantity: its FloorMods reward x 0.4,
-- e.g. Brutal +12%) = extra guardian items; Rare maps also turn one more item a step rarer. Maps can be CRAFTED at the map
-- device (Rifts.CRAFT): Imbue a Normal into a Magic, Empower a Magic into a Rare, Reroll a Magic / Rare's mods.
Rifts.RARITIES = {
    Normal = { Name = "Plain", Color = Color3.fromRGB(220, 220, 225), Mods = { 0, 0 } },
    Magic = { Name = "Charged", Color = Color3.fromRGB(110, 150, 255), Mods = { 1, 2 } },
    Rare = { Name = "Rare", Color = Color3.fromRGB(255, 215, 80), Mods = { 4, 6 } }, -- (MAPS V2: the real count is Rifts.ModCount(tier))
    Unique = { Name = "Storied", Color = Color3.fromRGB(255, 140, 40) },
}
Rifts.RARITY_ORDER = { "Normal", "Magic", "Rare", "Unique" }
Rifts.RARITY_WEIGHTS = { { "Normal", 40 }, { "Magic", 38 }, { "Rare", 20 }, { "Unique", 2 } }
-- named maps: fixed mods; Bonus = extra guardian items / extra top items / gold multiplier
Rifts.UNIQUES = {
    GlassGarden = { Name = "The Glass Garden", Biome = "Dream", Mods = { "GLASS_ARENA", "HEADHUNTER", "SMALL_TARGETS" },
        Text = "A fragile paradise: everything breaks fast, only clean headshots count.", Bonus = { Items = 2, Top = 1, Gold = 1.5 } },
    HallOfGiants = { Name = "Hall of Giants", Biome = "Ice", Mods = { "FORTIFIED", "ELITE_PACK", "ARMORED", "RARE_ELITES" },
        Text = "Every hall is a fortress of champions.", Bonus = { Items = 3, Top = 1, Gold = 1 } },
    ClockworkSiege = { Name = "Clockwork Siege", Biome = "Cyber", Mods = { "FRENZIED", "RELENTLESS", "SHARPSHOOTERS" },
        Text = "Fast, relentless and covered by snipers.", Bonus = { Items = 2, Top = 2, Gold = 2 } },
    EmberWake = { Name = "Ember Wake", Biome = "Fire", Mods = { "BRUTAL", "NO_REGEN", "ELEMENTAL", "EXTRA_HEAT" },
        Text = "No healing, no mercy, everything burns.", Bonus = { Items = 3, Top = 1, Gold = 1.5 } },
}
Rifts.UNIQUE_ORDER = { "GlassGarden", "HallOfGiants", "ClockworkSiege", "EmberWake" }
-- LAYOUTS: every map rolls the room layout all its floors are built on (DungeonGenerator BuildTraversal variants)
Rifts.LAYOUTS = {
    Gauntlet = "Gauntlet Run: wall panels down a long lane", Towers = "Tower Yard: high platforms and bridges",
    Ring = "Ring Arena: a raised ring round the middle", Pillars = "Pillar Hall: a forest of pillars",
    Terraces = "Terraces: high side ledges and ramps", Bunkers = "Bunker Field: low bunkers to fight through",
}
Rifts.LAYOUT_ORDER = { "Gauntlet", "Towers", "Ring", "Pillars", "Terraces", "Bunkers" }
Rifts.UNIQUE_LAYOUT = { GlassGarden = "Ring", HallOfGiants = "Pillars", ClockworkSiege = "Towers", EmberWake = "Bunkers" }
-- a map's layout (old maps: one picked from its Uid so it stays the same every time you look)
function Rifts.LayoutOf(sigil: any): string
    if type(sigil) ~= "table" then return "Gauntlet" end
    if sigil.Layout and Rifts.LAYOUTS[sigil.Layout] then return sigil.Layout end
    if sigil.Unique and Rifts.UNIQUE_LAYOUT[sigil.Unique] then return Rifts.UNIQUE_LAYOUT[sigil.Unique] end
    local h = 0
    for i = 1, #tostring(sigil.Uid or "") do h = (h * 31 + string.byte(tostring(sigil.Uid), i)) % 9973 end
    return Rifts.LAYOUT_ORDER[h % #Rifts.LAYOUT_ORDER + 1]
end
-- (FUTURE-PROOF 2026-10-25, PoE-style map mods) the pool = MOD_POOL + every FloorMods def marked MapOnly that isn't in it (a new
-- map-only mod rolls without a second list to keep). A def may carry, all optional: MinTier = the lowest map tier it rolls on (harder
-- mods for higher maps), Weight = how often it rolls (default 1), Group = a name no two mods of a map may share (e.g. two
-- "+% enemy damage" mods). Rifts.ModAllowed says whether one id may join a map's mods.
function Rifts.ModPool(): { string }
    if Rifts._pool then return Rifts._pool end
    local pool = table.clone(MOD_POOL)
    local ok, FM = pcall(function() return require(script.Parent:WaitForChild("FloorMods")) end)
    if ok and type(FM) == "table" and FM.Defs then
        local extra = {}
        for id, d in pairs(FM.Defs) do if d.MapOnly and not table.find(pool, id) then table.insert(extra, id) end end
        table.sort(extra)
        for _, id in ipairs(extra) do table.insert(pool, id) end
        Rifts._defs = FM.Defs
    end
    Rifts._pool = pool
    return pool
end
-- ===== MAP PACING (2026-10-31, owner: "Make it more akin to POE": Rare maps ran ~2x a plain map; PoE's take ~10-30% longer) =====
-- A map mod is a DANGER (it hurts you more) or a LOAD (it makes the clear take longer: tougher, more or harder-to-hit enemies).
-- def.Load = how much longer a T12 map's clear takes with it, MEASURED with the scripted test player and the typical kit
-- (tools/map_pace.luau, docs/MAPS_PACING_2026-10-31.md; 0.1 = +10%; 0 = pure danger). Rifts.LoadAt scales it with the mod's own
-- value at the map's tier (a T1 Fortified is weaker, so it loads less). A map's loads add up to at most LOAD_CAP: every roll
-- (new maps, IMBUE / EMPOWER / REROLL, CORRUPT, RUPTURE) skips a mod that would go over, so a Rare map is at most ~+20-25% of the
-- plain map's time and the rest of its mods are danger. Storied maps keep their fixed lists. FUTURE-PROOF: every map-pool def
-- needs a Load (ContentCheck); measure a new one with tools/map_pace.luau (a one-mod T12 cell vs a plain cell).
Rifts.LOAD_CAP = 0.2
Rifts.LOAD_AT = 12 -- (the tier the Loads were measured at)
function Rifts.LoadAt(id: string, tier: number?): number
    if not Rifts._defs then Rifts.ModPool() end
    local d = Rifts._defs and Rifts._defs[id]
    local base = d and tonumber(d.Load) or 0
    if base <= 0 then return 0 end
    if type(d.V) == "number" then
        local FM = require(script.Parent:WaitForChild("FloorMods"))
        local at = FM.V(id, Rifts.ModScale(Rifts.LOAD_AT), true)
        if at > 0 then return base * FM.V(id, Rifts.ModScale(tier), true) / at end
    end
    return base
end
function Rifts.MapLoad(mods: { string }?, tier: number?): number
    local s = 0
    for _, m in ipairs(type(mods) == "table" and mods or {}) do s += Rifts.LoadAt(m, tier) end
    return s
end
-- (MAP HEALTH 2026-11-05, owner: "rare maps CAN have modifiers that buff enemy health, but not to an insane extent") under the
-- one budget a health mod hardly ever rolled (11-18% of Rare maps: any earlier load mod filled the cap). A def whose Group is in
-- LOAD_FREE_GROUPS gets its own slot OUTSIDE LOAD_CAP: Health = Fortified / Warded, one per map (their Group), ~36-46% of Rare
-- maps, Fortified +20% (T1) .. +32% (T12), Warded +15% .. +24%, never the guardian. A Rare map: mean +19-29% clear time, at most
-- ~+47% (tools/sim/mappace.py). BudgetLoad = the part of a map's load that counts against LOAD_CAP.
Rifts.LOAD_FREE_GROUPS = { Health = true }
function Rifts.LoadFree(id: string): boolean
    if not Rifts._defs then Rifts.ModPool() end
    local d = Rifts._defs and Rifts._defs[id]
    return d ~= nil and d.Group ~= nil and Rifts.LOAD_FREE_GROUPS[d.Group] == true
end
function Rifts.BudgetLoad(mods: { string }?, tier: number?): number
    local s = 0
    for _, m in ipairs(type(mods) == "table" and mods or {}) do
        if not Rifts.LoadFree(m) then s += Rifts.LoadAt(m, tier) end
    end
    return s
end
-- loadTier (optional): the tier the load is counted at when `tier` is only a MinTier override (RUPTURE's Warp rolls at 99)
function Rifts.ModAllowed(id: string, tier: number?, have: { string }?, loadTier: number?): boolean
    local d = Rifts._defs and Rifts._defs[id]
    if have and table.find(have, id) then return false end
    if d and d.MinTier and (tonumber(tier) or 1) < d.MinTier then return false end
    if d and d.Group and have then
        for _, h in ipairs(have) do
            local hd = Rifts._defs[h]
            if hd and hd.Group == d.Group then return false end
        end
    end
    if have and d and (tonumber(d.Load) or 0) > 0 and not Rifts.LoadFree(id) then -- (MAP PACING: the map's load budget)
        local lt = loadTier or tier
        if Rifts.BudgetLoad(have, lt) + Rifts.LoadAt(id, lt) > Rifts.LOAD_CAP + 1e-6 then return false end
    end
    return true
end
local function RollMods(n: number, r: Random, exclude: { string }?, tier: number?, loadTier: number?): { string }
    local pool = Rifts.ModPool()
    local mods = {}
    local have = table.clone(exclude or {})
    for _ = 1, n do
        local cands, total = {}, 0
        for _, m in ipairs(pool) do
            if Rifts.ModAllowed(m, tier, have, loadTier) then
                local d = Rifts._defs and Rifts._defs[m]
                local w = math.max(0, tonumber(d and d.Weight) or 1)
                if w > 0 then table.insert(cands, { m, w }); total += w end
            end
        end
        if #cands == 0 or total <= 0 then break end
        local x = r:NextNumber() * total
        local pick = cands[#cands][1]
        for _, c in ipairs(cands) do
            x -= c[2]
            if x <= 0 then pick = c[1]; break end
        end
        table.insert(mods, pick)
        table.insert(have, pick)
    end
    return mods
end
local function RollRarity(r: Random, minRarity: string?): string
    local total = 0
    for _, w in ipairs(Rifts.RARITY_WEIGHTS) do total += w[2] end
    local x, pick = r:NextNumber() * total, "Normal"
    for _, w in ipairs(Rifts.RARITY_WEIGHTS) do
        x -= w[2]
        if x <= 0 then pick = w[1] break end
    end
    if minRarity and (table.find(Rifts.RARITY_ORDER, pick) or 1) < (table.find(Rifts.RARITY_ORDER, minRarity) or 1) then pick = minRarity end
    return pick
end
-- maps from before 0.62 have no rarity: their mod count decides it
function Rifts.RarityOf(sigil: any): string
    if type(sigil) ~= "table" then return "Normal" end
    if sigil.Rarity and Rifts.RARITIES[sigil.Rarity] then return sigil.Rarity end
    local n = #(sigil.Mods or {})
    return (n >= 3 and "Rare") or (n >= 1 and "Magic") or "Normal"
end
-- item quantity bonus of a map (each mod: its FloorMods reward x 0.4 x the tier's ModScale; a Unique +30% on top)
-- (MAPS V2) + QUALITY (1% a point), + a Rupture's quantity. Works on a sigil or a run's Rift table (EndgameServer copies the fields).
Rifts.QTY_PER_REWARD = 0.4 -- a mod's Reward -> item quantity
Rifts.RARITY_PER_REWARD = 0.5 -- a mod's Reward -> item rarity (the floor loot luck DungeonRuns' FloorLuckMult always gave it)
function Rifts.ModReward(sigil: any): number
    local FM = require(script.Parent:WaitForChild("FloorMods"))
    local tier = type(sigil) == "table" and sigil.Tier or 1
    return FM.RewardBonus(type(sigil) == "table" and sigil.Mods or {}, Rifts.ModScale(tier))
end
function Rifts.Quantity(sigil: any): number
    local q = Rifts.ModReward(sigil) * Rifts.QTY_PER_REWARD
    if Rifts.RarityOf(sigil) == "Unique" then q += 0.3 end
    if type(sigil) == "table" and sigil.Corrupted then q += 0.2 end -- (0.66 CORRUPT)
    q += require(script.Parent:WaitForChild("MapInks")).Sum(sigil, "Quantity") -- (UPDATE 7 MAP INKS)
    q += Rifts.QualityOf(sigil) / 100 -- (MAPS V2 QUALITY)
    q += type(sigil) == "table" and tonumber(sigil.RuptureQty) or 0 -- (MAPS V2 RUPTURE)
    return q
end
-- (MAPS V2) ITEM RARITY of a map: its mods' share of the floor loot luck (Reward x 0.5 x ModScale; the same number DungeonRuns puts
-- into FloorLuckMult) + a Rupture's rarity. The guardian cache's luck is x (1 + this) too (Rifts.Reward).
function Rifts.ExtraRarity(sigil: any): number
    return type(sigil) == "table" and tonumber(sigil.RuptureRar) or 0
end
function Rifts.Rarity(sigil: any): number
    return Rifts.ModReward(sigil) * Rifts.RARITY_PER_REWARD + Rifts.ExtraRarity(sigil)
end
-- (MAPS V2) PACK SIZE of a map: Swarming (more packs) x Teeming (bigger packs), the real numbers the floors use
function Rifts.PackSize(sigil: any): number
    local FM = require(script.Parent:WaitForChild("FloorMods"))
    local mods = type(sigil) == "table" and sigil.Mods or {}
    local sc = Rifts.ModScale(type(sigil) == "table" and sigil.Tier or 1)
    local m = 1
    for _, id in ipairs({ "SWARMING", "BIG_PACKS" }) do
        if table.find(mods, id) then m *= 1 + FM.V(id, sc, true) end
    end
    return m - 1
end
-- (MAPS V2) QUALITY 0..MAX_QUALITY (HONE at the map device, Chart Shards): +1% item quantity a point
Rifts.MAX_QUALITY, Rifts.HONE_STEP = 20, 5
function Rifts.QualityOf(sigil: any): number
    return math.clamp(math.floor(type(sigil) == "table" and tonumber(sigil.Quality) or 0), 0, Rifts.MAX_QUALITY)
end
function Rifts.DisplayName(sigil: any): string
    local pre = (type(sigil) == "table" and sigil.Corrupted) and "Corrupted " or "" -- (0.66 CORRUPT)
    if type(sigil) == "table" and sigil.Ruptured then pre = "Ruptured " end -- (MAPS V2 RUPTURE: the second corruption)
    if type(sigil) == "table" and sigil.Name then return pre .. sigil.Name end
    local r = Rifts.RarityOf(sigil) -- (FUTURE-PROOF 2026-10-25: the player name -- it printed the internal key, "MAGIC MAP")
    return string.format("%s%s Map", pre, (Rifts.RARITIES[r] and Rifts.RARITIES[r].Name) or r)
end
-- NewSigil(tier, rng?, rarity?, minRarity?): rarity rolled from RARITY_WEIGHTS unless given
function Rifts.NewSigil(tier: number, rng: Random?, rarity: string?, minRarity: string?): any
    local r = rng or Random.new()
    tier = math.min(math.max(1, math.floor(tier)), Rifts.MaxTier()) -- (LAUNCH CAP)
    rarity = (rarity and Rifts.RARITIES[rarity]) and rarity or RollRarity(r, minRarity)
    local s = { Uid = HttpService:GenerateGUID(false), Tier = tier, Rarity = rarity, V = Rifts.VERSION, Skill = r:NextInteger(Rifts.SKILL_MIN, Rifts.SKILL_MAX) }
    if rarity == "Unique" then
        local id = Rifts.UNIQUE_ORDER[r:NextInteger(1, #Rifts.UNIQUE_ORDER)]
        local u = Rifts.UNIQUES[id]
        s.Unique, s.Name, s.Biome, s.Mods, s.Layout = id, u.Name, u.Biome, table.clone(u.Mods), Rifts.UNIQUE_LAYOUT[id]
    else
        local span = Rifts.RARITIES[rarity].Mods
        s.Mods = RollMods(Rifts.ModRoll(rarity, tier, r), r, nil, tier)
        s.Biome = BIOMES[r:NextInteger(1, #BIOMES)]
        s.Layout = Rifts.LAYOUT_ORDER[r:NextInteger(1, #Rifts.LAYOUT_ORDER)]
    end
    Rifts.StampGuardian(s) -- (FUTURE-PROOF: stored, see GuardianOf; MAPS V2: picked inside its band, Storied from the old pool)
    return s
end
-- CRAFTING at the map device: action -> material cost, the rarity it needs
Rifts.CRAFT = {
    Imbue = { Name = "IMBUE", Needs = { Normal = true }, Cost = 3, Text = "Plain -> Charged (1-2 mods)" },
    Empower = { Name = "EMPOWER", Needs = { Magic = true }, Cost = 6, Text = "Charged -> Rare (4-6 mods, more on higher tiers)" },
    Reroll = { Name = "REROLL", Needs = { Magic = true, Rare = true }, Cost = 4, Text = "new mods, same rarity" },
    -- (0.66 map-only currency: Chart Shards)
    Chart = { Name = "CHART", Needs = { Normal = true, Magic = true, Rare = true }, Cost = 2, Material = "ChartShard", Text = "a new biome and room layout, same mods" },
    Corrupt = { Name = "CORRUPT", Needs = { Normal = true, Magic = true, Rare = true, Unique = true }, Cost = 3, Material = "ChartShard",
        Text = "a gamble: 40% +1 tier and +1 mod, 30% +1 mod, 30% nothing. Always +20% item quantity, and it can never be crafted again" },
    Engrave = { Name = "ENGRAVE", Needs = { Rare = true }, Cost = 12, Material = "ChartShard", Text = "Rare -> a random Storied map (same tier)" },
    -- (MAPS V2 2026-10-30 BOOSTING; owner: "just do whatever POE does") HONE = +5% quality (max 20%, +1% item quantity a point);
    -- RUPTURE = a second corruption on a Corrupted map, once: it never destroys the map, the risk is the mods it can roll. Fixed =
    -- always full price (the map tree's discount and Master Artisan don't touch quality or a corruption). Odds: Rifts.RUPTURE.
    Hone = { Name = "HONE", Needs = { Normal = true, Magic = true, Rare = true, Unique = true }, Cost = 2, Material = "ChartShard", Fixed = true,
        Text = "+5% quality (up to 20%): +1% item quantity for every 1%" },
    Rupture = { Name = "RUPTURE", Needs = { Normal = true, Magic = true, Rare = true, Unique = true }, Cost = 4, Material = "ChartShard", Fixed = true,
        Corrupted = true, Text = "corrupt it a second time: one of four results, then it is locked for good (marks still go on)" },
}
Rifts.CRAFT_ORDER = { "Imbue", "Empower", "Reroll", "Chart", "Hone", "Corrupt", "Engrave", "Rupture" }
-- RUPTURE outcomes (rolled on the server, Rifts.ApplyCraft; Odds sum to 1). Every result marks the map Ruptured (no more crafts,
-- Sigil Marks still allowed). Ascend: +1 tier (at the top tier: +1 mod). Warp: the mods are rerolled as a Rare map at the HIGH end
-- of its tier (Rifts.ModCount hi) + WARP_EXTRA corrupted mods that ignore the tier limits (the nasty ones can show up). Bounty:
-- +BOUNTY_QTY item quantity, +BOUNTY_RAR item rarity. A Storied map can't take mods: Warp / a top-tier Ascend become Bounty.
Rifts.RUPTURE = {
    BOUNTY_QTY = 0.3, BOUNTY_RAR = 0.2, WARP_EXTRA = { 1, 2 },
    Outcomes = {
        { Id = "Still", Odds = 0.25, Text = "no change" },
        { Id = "Ascend", Odds = 0.25, Text = "+1 tier (top tier: +1 mod)" },
        { Id = "Warp", Odds = 0.25, Text = "new Rare mods + 1-2 corrupted ones" },
        { Id = "Bounty", Odds = 0.25, Text = "+30% quantity, +20% rarity" },
    },
}
function Rifts.RuptureOddsText(): string
    local t = {}
    for _, o in ipairs(Rifts.RUPTURE.Outcomes) do table.insert(t, string.format("%d%%  %s", math.round(o.Odds * 100), o.Text)) end
    return table.concat(t, "\n")
end
function Rifts.CraftMaterial(action: string): string
    local c = Rifts.CRAFT[action]
    return (c and c.Material) or Rifts.CRAFT_MATERIAL
end
Rifts.CRAFT_MATERIAL = "Prism" -- paid in Prism (ItemData materials)
function Rifts.CanCraft(sigil: any, action: string): (boolean, string?)
    local c = Rifts.CRAFT[action]
    if not c then return false, "Unknown craft." end
    local rar = Rifts.RarityOf(sigil)
    if c.Corrupted then -- (MAPS V2 RUPTURE: only on a Corrupted map, once)
        if type(sigil) ~= "table" or not sigil.Corrupted then return false, c.Name .. " needs a Corrupted map." end
        if sigil.Ruptured then return false, "This map is already Ruptured." end
        return true
    end
    if type(sigil) == "table" and sigil.Corrupted then return false, "Corrupted maps can't be changed." end
    if action == "Hone" and Rifts.QualityOf(sigil) >= Rifts.MAX_QUALITY then return false, "This map is already at " .. Rifts.MAX_QUALITY .. "% quality." end
    if rar == "Unique" and not c.Needs.Unique then return false, "Storied maps can't be changed." end
    if not c.Needs[rar] then return false, c.Name .. " needs a " .. (c.Needs.Rare and "Charged or Rare" or ((Rifts.RARITIES[next(c.Needs)] or {}).Name or next(c.Needs))) .. " map." end
    return true
end
function Rifts.ApplyCraft(sigil: any, action: string, rng: Random?): string?
    local r = rng or Random.new()
    sigil.Mods = sigil.Mods or {}
    if action == "Chart" then
        local b, l = sigil.Biome, sigil.Layout
        for _ = 1, 8 do
            b = BIOMES[r:NextInteger(1, #BIOMES)]
            l = Rifts.LAYOUT_ORDER[r:NextInteger(1, #Rifts.LAYOUT_ORDER)]
            if b ~= sigil.Biome or l ~= sigil.Layout then break end
        end
        sigil.Biome, sigil.Layout = b, l
        return string.format("now %s, %s", b, (string.split(Rifts.LAYOUTS[l], ":"))[1])
    elseif action == "Corrupt" then
        sigil.Corrupted = true
        local unique = Rifts.RarityOf(sigil) == "Unique"
        local function AddMod(): boolean
            if unique then return false end
            local add = RollMods(1, r, sigil.Mods, sigil.Tier)
            if #add == 0 then return false end
            table.insert(sigil.Mods, add[1])
            if Rifts.RarityOf(sigil) == "Normal" or sigil.Rarity == "Normal" then sigil.Rarity = "Magic" end
            return true
        end
        local roll = r:NextNumber()
        local top = (sigil.Tier or 1) >= Rifts.MaxTier() -- (MAPS V2: no climb past the open top tier)
        if roll < 0.4 then
            local up = not top
            if up then sigil.Tier = (sigil.Tier or 1) + 1 end
            local added = AddMod()
            return (up and "+1 tier" or "") .. ((up and added) and " and " or "") .. (added and "+1 mod" or "") .. ((not up and not added) and "no change" or "")
        elseif roll < 0.7 then
            if AddMod() then return "+1 mod" end
            if top then return "no change" end
            sigil.Tier = (sigil.Tier or 1) + 1
            return "+1 tier"
        end
        return "no change"
    elseif action == "Hone" then -- (MAPS V2 QUALITY)
        sigil.Quality = math.min(Rifts.MAX_QUALITY, Rifts.QualityOf(sigil) + Rifts.HONE_STEP)
        return string.format("%d%% quality", sigil.Quality)
    elseif action == "Rupture" then -- (MAPS V2: the second corruption; never destroys the map)
        local x, pick = r:NextNumber(), Rifts.RUPTURE.Outcomes[#Rifts.RUPTURE.Outcomes]
        for _, o in ipairs(Rifts.RUPTURE.Outcomes) do
            x -= o.Odds
            if x < 0 then pick = o; break end
        end
        sigil.Ruptured = true
        local unique = Rifts.RarityOf(sigil) == "Unique"
        local id, msg = pick.Id, "no change"
        if id == "Ascend" then
            if (sigil.Tier or 1) < Rifts.MaxTier() then
                sigil.Tier = (sigil.Tier or 1) + 1
                msg = "+1 tier"
            elseif not unique then
                local add = RollMods(1, r, sigil.Mods, sigil.Tier)
                if #add > 0 then
                    table.insert(sigil.Mods, add[1])
                    if Rifts.RarityOf(sigil) == "Normal" then sigil.Rarity = "Magic" end
                    msg = "+1 mod"
                else id = "Bounty" end
            else id = "Bounty" end
        elseif id == "Warp" then
            if unique then id = "Bounty" else
                local _, hi = Rifts.ModCount(sigil.Tier or 1)
                sigil.Rarity = "Rare"
                sigil.Mods = RollMods(hi, r, nil, sigil.Tier)
                local ex = Rifts.RUPTURE.WARP_EXTRA
                local extra = RollMods(r:NextInteger(ex[1], ex[2]), r, sigil.Mods, 99, sigil.Tier) -- (any tier's mods: the risk; MAP PACING: load at the map's tier)
                for _, m in ipairs(extra) do table.insert(sigil.Mods, m) end
                msg = string.format("new mods: %d (%d corrupted)", #sigil.Mods, #extra)
            end
        end
        if id == "Bounty" then
            sigil.RuptureQty = (tonumber(sigil.RuptureQty) or 0) + Rifts.RUPTURE.BOUNTY_QTY
            sigil.RuptureRar = (tonumber(sigil.RuptureRar) or 0) + Rifts.RUPTURE.BOUNTY_RAR
            msg = string.format("+%d%% item quantity, +%d%% item rarity", math.round(Rifts.RUPTURE.BOUNTY_QTY * 100), math.round(Rifts.RUPTURE.BOUNTY_RAR * 100))
        end
        sigil.RuptureResult = id -- (the device shows which result it got)
        return msg
    elseif action == "Engrave" then
        local id = Rifts.UNIQUE_ORDER[r:NextInteger(1, #Rifts.UNIQUE_ORDER)]
        local u = Rifts.UNIQUES[id]
        sigil.Rarity, sigil.Unique, sigil.Name, sigil.Biome, sigil.Mods, sigil.Layout = "Unique", id, u.Name, u.Biome, table.clone(u.Mods), Rifts.UNIQUE_LAYOUT[id]
        return nil -- (the new name is the message)
    elseif action == "Imbue" then
        sigil.Rarity = "Magic"
        sigil.Mods = RollMods(Rifts.ModRoll("Magic", sigil.Tier or 1, r), r, nil, sigil.Tier)
    elseif action == "Empower" then
        sigil.Rarity = "Rare"
        local want = Rifts.ModRoll("Rare", sigil.Tier or 1, r)
        for _, m in ipairs(RollMods(want - #sigil.Mods, r, sigil.Mods, sigil.Tier)) do table.insert(sigil.Mods, m) end
    elseif action == "Reroll" then
        local rar = Rifts.RarityOf(sigil)
        sigil.Rarity = rar
        local span = Rifts.RARITIES[rar].Mods
        sigil.Mods = RollMods(Rifts.ModRoll(rar, sigil.Tier or 1, r), r, nil, sigil.Tier)
    end
end

-- Tier of a sigil dropped by a boss on a difficulty: the first tier of that difficulty's band, Tier 1 below Ruin.
function Rifts.DropTier(difficulty: string?): number
    return Rifts.FirstTierOf(difficulty) or 1
end

-- 0.53-ladder save -> 0.61 ladder, once (state.RiftScale): old sigils without V shift down 25 tiers (old 26-28 were
-- Ruin, which is new 1-3), and RiftBest with them. Returns true when something changed.
function Rifts.Migrate(state: any): boolean
    if type(state) ~= "table" then return false end
    local clamped = false -- (LAUNCH CAP: a sigil above the open bands comes down to the top open tier)
    for _, s in ipairs(type(state.Sigils) == "table" and state.Sigils or {}) do
        if type(s) == "table" and s.V == Rifts.VERSION and (tonumber(s.Tier) or 1) > Rifts.MaxTier() then s.Tier = Rifts.MaxTier(); clamped = true end
    end
    for _, s in ipairs(type(state.Sigils) == "table" and state.Sigils or {}) do -- (FUTURE-PROOF: freeze every map's guardian + layout)
        if type(s) == "table" and type(s.Uid) == "string" then
            if Rifts.StampGuardian(s) then clamped = true end -- (MAPS V2: band pools -- an old all-boss pick is re-rolled inside its band once)
            if s.Layout == nil and not s.Unique then s.Layout = Rifts.LayoutOf(s); clamped = true end
        end
    end
    if state.RiftScale == Rifts.VERSION then return clamped end
    for _, s in ipairs(type(state.Sigils) == "table" and state.Sigils or {}) do
        if type(s) == "table" and s.V ~= Rifts.VERSION then
            s.Tier = math.max(1, math.floor(tonumber(s.Tier) or 1) - 25)
            s.V = Rifts.VERSION
        end
    end
    state.RiftBest = math.max(0, math.floor(tonumber(state.RiftBest) or 0) - 25)
    state.RiftScale = Rifts.VERSION
    return true
end

-- (MAPS V2 L1: Rifts.Upgrade -- "the next sigil after a rift, +1 / +2 tiers by time" -- is gone: maps drop inside maps, see
-- Rifts.MAP_DROP / DropTierFrom.)

return Rifts
