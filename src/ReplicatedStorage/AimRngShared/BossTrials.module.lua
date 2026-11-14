--!nocheck
-- ============================================================================================
-- BOSS TRIALS (endgame boss fights, overnight task 4 -- owner: "once the bosses are optimized, begin working on the
-- endgame bossfights. Make sure they have learnable, unique mechanics"; plan: a Challenges BOSSES tab with standalone
-- fights, tiers + titles, exclusive loot and clear-time leaderboards).
--
-- Each trial is ONE fight in its own arena (a single boss floor). Five tiers: tier 1 is open, each clear unlocks the
-- next. Every boss has one signature mechanic you have to learn (shown on its card) -- you can't out-gear it:
--   SERAPH ARCHON  -- "AVERT YOUR EYES": it charges a blinding judgement; anyone LOOKING at it when it fires is struck.
--                     "SCALES OF JUDGEMENT": it raises one wing -- that half of the arena is safe, the other burns.
--   CHRONARCH      -- "OFF-BEAT": it fights to a metronome. Armored on the beat; every 4th beat its core opens and
--                     takes triple damage. Countdown bombs and the clock hands also move on the beat.
--   ECHO WARDEN    -- "ECHOES": every attack it makes happens AGAIN a few seconds later in the same place (purple
--                     ghost telegraph). Remember where it struck; in phase 3 echoes echo twice.
--   FORGEHEART     -- "BRANDS": a slag shell that takes 15% damage; three white-hot BRANDS crawl over its body and only
--                     they take full damage (a moving-target aim check). "MAGMA TIDE": basalt pillars rise and the
--                     floor floods with lava -- get up high. "HAMMERFALL": it leaps onto you; jump the shock ring.
--                     (overnight 2026-10-03; the shell rule is server-side in CombatServer, part name "Brand")
-- Rewards: first clear of a tier pays a bounty; every clear pays gold + Prism; every boss can drop one of its EXOTICS
-- (BossTrials.EXOTIC_POOL, ExoticChance) and the first four have two titles (tier 3, tier 5). (The old exclusive glove
-- drops are gone -- owner after 0.92: "Boss drops still say the old cosmetics we used, replace it with the exotic".)
-- Leaderboards: fastest clear per boss per tier ("BossTrial_<Id>_T<tier>", lower is better).
-- State: state.BossTrials = { [bossId] = { Best = highest tier cleared, Times = { ["<tier>"] = best seconds } } }.
-- Flow: Challenges > BOSSES > START -> remote StartBossTrial(id, tier) (EndgameServer) -> DungeonRuns floor with
-- config.BossTrial -> roster = that boss (DungeonGenerator.CreateTrialBoss, BossAI kit) -> kill -> BossTrialFinished.
-- ============================================================================================
local BossTrials = {}

BossTrials.FLOOR = 5 -- a boss-chamber floor number (the arena layout); the banner shows the trial instead

BossTrials.Bosses = {
    {
        Id = "Archon", Name = "SERAPH ARCHON", Biome = "Ice", Color = Color3.fromRGB(255, 214, 120),
        Blurb = "A six-winged judge of light. It punishes the careless and the curious.",
        Mechanics = { -- (0.68 AIM ROUNDS: the old signature lines are gone)
            "AVERT YOUR EYES: when it shouts and starts to blaze, TURN AWAY. Anyone looking at it when the light fires is struck hard.",
            "SCALES OF JUDGEMENT: it raises one wing. Get to the side of that wing; the other half of the arena burns.",
            "Feathers fall where you stand and lances of light lock onto you.",
            "TARGETS: it guards (half damage) and lime targets appear (several at once, one gliding round it, or one after another). Break them all in time: STAGGERED, +75% damage. Too slow: they fire at you.",
            "Enrages after 4 minutes.",
        },
        Titles = { [3] = "ArchonBane", [5] = "Godslayer" },
    },
    {
        Id = "Chronarch", Name = "CHRONARCH", Biome = "Cyber", Color = Color3.fromRGB(90, 230, 255),
        Blurb = "A clockwork tyrant that fights to the tick of its own heart.",
        Mechanics = { -- (0.68 AIM ROUNDS: the old signature lines are gone)
            "COUNTDOWN BOMBS go off exactly on a beat. Listen to the tick, not your nerves.",
            "The CLOCK HANDS sweep the floor; the tempo rises every phase.",
            "TARGETS: it guards (half damage) and lime targets appear (several at once, one gliding round it, or one after another). Break them all in time: STAGGERED, +75% damage. Too slow: they fire at you.",
            "Enrages after 4 minutes.",
        },
        Titles = { [3] = "Timekeeper", [5] = "Chronobreaker" },
    },
    {
        Id = "EchoWarden", Name = "ECHO WARDEN", Biome = "Void", Color = Color3.fromRGB(190, 110, 255),
        Blurb = "It remembers every blow, and strikes each one twice.",
        Mechanics = { -- (0.68 AIM ROUNDS: the old signature lines are gone)
            "ECHOES: every attack happens AGAIN a few seconds later in the same spot (the purple ghost telegraph). Don't step back into it.",
            "It LEAPS onto where you stood and hunts you with death marks, and those blasts echo too.",
            "TARGETS: it guards (half damage) and lime targets appear (several at once, one gliding round it, or one after another). Break them all in time: STAGGERED, +75% damage. Too slow: they fire at you.",
            "Enrages after 4 minutes.",
        },
        Titles = { [3] = "EchoBreaker", [5] = "VoidWarden" },
    },
    {
        Id = "Forgeheart", Name = "FORGEHEART", Biome = "Fire", Color = Color3.fromRGB(255, 130, 40),
        Blurb = "A walking furnace in a shell of cooling slag.",
        Mechanics = { -- (0.68 AIM ROUNDS: the old signature lines are gone)
            "MAGMA TIDE: basalt pillars rise, then the floor floods with lava. Get up on a pillar until it drains.",
            "HAMMERFALL: it leaps onto where you stand, then the impact strikes your spot again. Keep moving.",
            "TARGETS: it guards (half damage) and lime targets appear (several at once, one gliding round it, or one after another). Break them all in time: STAGGERED, +75% damage. Too slow: they fire at you.",
            "Its white-hot BRANDS are weak spots. Enrages after 4 minutes.",
        },
        Titles = { [3] = "Slagbreaker", [5] = "Forgeborn" },
    },
    -- ===== MAJOR BOSSES (0.52, owner: "add 4 more bosses, all with VERY unique attacks, phases and mechanics ... these
    -- SHOULD be difficult, as you are going to farm exotics from these"). Major = more health (MAJOR_HP), harder hits
    -- (MAJOR_DMG), an ENRAGE timer, and later each one's exotics (docs/exotics_ideas.md). BossAI kits + SIG of the same id.
    {
        Id = "Lockwarden", Name = "THE LOCKWARDEN", Biome = "Storm", Color = Color3.fromRGB(120, 200, 255), Major = true,
        Blurb = "The vault's last guard. Nothing gets past it.",
        Mechanics = { -- (0.68 AIM ROUNDS: the old signature lines are gone)
            "The vault's guard fights with lock-down sweeps and alarms across the arena.",
            "TARGETS: it guards (half damage) and lime targets appear (several at once, one gliding round it, or one after another). Break them all in time: STAGGERED, +75% damage. Too slow: they fire at you.",
            "Enrages after 4 minutes.",
        },
        Titles = {},
    },
    {
        Id = "Broodmother", Name = "THE BROODMOTHER", Biome = "Fire", Color = Color3.fromRGB(255, 120, 60), Major = true,
        Blurb = "She nests in the magma. Every clutch she lays is a race you can't afford to lose.",
        Mechanics = { -- (0.68 AIM ROUNDS: the old signature lines are gone)
            "She burrows, webs the floor and in her last phase climbs out of reach to rain fire.",
            "TARGETS: it guards (half damage) and lime targets appear (several at once, one gliding round it, or one after another). Break them all in time: STAGGERED, +75% damage. Too slow: they fire at you.",
            "Enrages after 4 minutes.",
        },
        Titles = {},
    },
    {
        Id = "Duelist", Name = "THE DUELIST", Biome = "Void", Color = Color3.fromRGB(200, 120, 255), Major = true,
        Blurb = "It has never lost a duel. Be the first.",
        Mechanics = { -- (0.68 AIM ROUNDS: the old signature lines are gone)
            "It lunges across the arena and, from phase 2, its afterimages repeat its cuts.",
            "TARGETS: it guards (half damage) and lime targets appear (several at once, one gliding round it, or one after another). Break them all in time: STAGGERED, +75% damage. Too slow: they fire at you.",
            "Enrages after 4 minutes.",
        },
        Titles = {},
    },
    {
        Id = "FortuneEngine", Name = "THE FORTUNE ENGINE", Biome = "Cyber", Color = Color3.fromRGB(255, 210, 60), Major = true,
        Blurb = "The house always wins. Unless you outshoot it.",
        Mechanics = { -- (0.68 AIM ROUNDS: the old signature lines are gone)
            "It spins its reels and throws the house's attacks at you, faster every phase.",
            "TARGETS: it guards (half damage) and lime targets appear (several at once, one gliding round it, or one after another). Break them all in time: STAGGERED, +75% damage. Too slow: they fire at you.",
            "Enrages after 4 minutes.",
        },
        Titles = {},
    },
}
-- ===== MAPS-ONLY BOSSES (MAPS V2 2026-10-30, owner's Next List F21: "A new boss for maps (Phantom-style: human-sized, always
-- moving, target switching)") ===== guardians that only live on map floor 5 (Rifts.BAND_GUARDIANS): they are in ById (the
-- guardian pipeline, DungeonGenerator.CreateTrialBoss, the device's name) but NOT in Bosses, so the Challenges BOSSES tab, the
-- weekly rotation, Party Finder and the trial leaderboards never see them; StartBossTrial / PartyService refuse MapOnly ids.
-- No EXOTIC_POOL row: a guardian pays the map relics (Rifts.EXOTICS). BossAI kit: AimRngShared/MapBosses.
BossTrials.MapBosses = {
    {
        Id = "Lamplighter", Name = "THE LAMPLIGHTER", Biome = "Void", Color = Color3.fromRGB(255, 178, 76), Major = true, MapOnly = true,
        Blurb = "When the world goes dark he keeps the last lamps lit. Reach him, and you put them out.",
        Mechanics = {
            "Never stands still: he circles you, side-steps your aim and glides to a new spot (the ghost shows where).",
            "WICK SHOT / LAMPLINE: aimed shots and lanes from his lantern, one at a time, after a clear wind-up. SNUFF drops circles where you stand.",
            "TARGETS are his LAMPS: hanging lamps that sway (switch), one lantern swinging on its chain (track), lamps that flare up one by one round you (flick). Break them all in time: STAGGERED, +75% damage.",
        },
        Titles = {},
    },
}
BossTrials.ById = {}
for _, b in ipairs(BossTrials.Bosses) do BossTrials.ById[b.Id] = b end
for _, b in ipairs(BossTrials.MapBosses) do BossTrials.ById[b.Id] = b end

-- Tiers: the difficulty the fight runs at, extra boss health, and pace (<1 = faster attacks).
BossTrials.Tiers = {
    -- (0.99u BOSS PACE: Hp was 1 / 1.25 / 1.6 / 2.1 / 2.8 / 3.2 / 3.6 / 4 / 4.5 / 5 on top of the difficulty's own climb -- tier X
    -- took over an hour on-level. Health now comes from a fight time (DungeonGenerator.BossHp); the tier adds a little.)
    { Name = "I", Difficulty = "Hard", Hp = 1.0, Pace = 1.0 },
    { Name = "II", Difficulty = "Brutal", Hp = 1.01, Pace = 0.95 },
    { Name = "III", Difficulty = "Nightmare", Hp = 1.02, Pace = 0.9 },
    { Name = "IV", Difficulty = "Torment", Hp = 1.03, Pace = 0.85 },
    { Name = "V", Difficulty = "Oblivion", Hp = 1.04, Pace = 0.78 },
    -- (0.52: up to Singularity, so the major bosses can be farmed at the level cap)
    { Name = "VI", Difficulty = "Ruin", Hp = 1.05, Pace = 0.75 },
    { Name = "VII", Difficulty = "Dread", Hp = 1.06, Pace = 0.72 },
    { Name = "VIII", Difficulty = "Apocalypse", Hp = 1.07, Pace = 0.70 },
    { Name = "IX", Difficulty = "Eternity", Hp = 1.08, Pace = 0.68 },
    { Name = "X", Difficulty = "Singularity", Hp = 1.1, Pace = 0.66 },
}
BossTrials.MAX_TIER = #BossTrials.Tiers
-- every trial boss's health x this on top of the tier's Hp (owner 2026-10-03: "the bosses HP wise feel far too easy";
-- tier I at x1 took a geared player too little time -- raise / lower this one number to retune them all)
BossTrials.HpScale = 1 -- (0.99u BOSS PACE: was 2.5; the fight time sets trial health now)
-- MAJOR bosses on top: health and hit strength, and the enrage (seconds) -- they're the exotic farm, so they hurt
-- (0.99u BOSS PACE: MAJOR_HP no longer used -- majors get BOSS_PACE.MajorTrial seconds; ENRAGE 420 -> 240 with ~45-60 s fights)
BossTrials.MAJOR_HP, BossTrials.MAJOR_DMG, BossTrials.ENRAGE = 1, 1.35, 240

-- EXOTICS (0.53): each major boss drops its own exotics (ItemData.Exotics). (0.86, owner: "a super super low drop chance
-- (getting slightly higher at higher difficulties)": per clear 1% at tier I, +0.25% a tier (3.25% at X; was 6% .. 20%),
-- x ItemData.ExoticFalloff for the trial's difficulty vs your highest unlocked one -- EndgameServer applies it.) The
-- FIRST clear of tiers I, V and X still always drops one (once each: it can't be farmed). Stats roll at the trial's window.
BossTrials.EXOTIC_POOL = {
    -- (0.93: the first four trial bosses drop exotics too, in place of their old gloves -- one weapon + one gear piece each,
    -- spread over the classes; the major bosses keep theirs)
    Archon = { "LastWord", "PrismCore" },
    Chronarch = { "IronChoir", "DrifterBoots" },
    EchoWarden = { "TwinFang", "HawkeyeVisor" },
    Forgeheart = { "DragonsMaw", "BastionShell" },
    Lockwarden = { "IronChoir", "Bandolier", "HawkeyeVisor" },
    Broodmother = { "DragonsMaw", "BastionShell", "PrismCore" },
    Duelist = { "LastWord", "TwinFang", "HawkeyeVisor" },
    FortuneEngine = { "ArcLance", "DrifterBoots", "Bandolier" },
}
function BossTrials.ExoticChance(tier: number, first: boolean): number
    if first and (tier == 1 or tier == 5 or tier == 10) then return 1 end
    return 0.01 + 0.0025 * (tier - 1)
end

-- (0.93: the exclusive glove drops are retired -- every boss drops exotics instead; owners keep their gloves)
function BossTrials.DropChance(_tier: number): number
    return 0
end

-- Pay for a clear: every clear + a first-clear bounty
-- (0.52: tiers VI-X pay more with their monster level -- x1.7 at VI .. x4.5 at X; major bosses x1.5)
function BossTrials.Reward(tier: number, first: boolean, major: boolean?): any
    local k = (1 + math.max(0, tier - 5) * 0.7) * (major and 1.5 or 1)
    local r = { Gold = math.round((1500 + 900 * tier) * k), Prism = math.round((tier + 1) * (major and 1.5 or 1)) }
    if first then r.Gold += math.round(3000 * tier * k); r.Prism += 3 * tier; r.Gem = (tier >= 6 and "Mythic") or (tier >= 4 and "Legendary") or (tier >= 2 and "Epic") or "Rare" end
    return r
end
-- the level a tier needs (its difficulty's dungeon level; tiers I-V stay open to anyone who cleared the tier below)
function BossTrials.MinLevel(tier: number): number
    local t = BossTrials.Tiers[tier]
    if not t or tier <= 5 then return 1 end
    local ok, ItemData = pcall(require, script.Parent:WaitForChild("ItemData"))
    return ok and (ItemData.DifficultyMinLevel[t.Difficulty] or 1) or 1
end

function BossTrials.Board(id: string, tier: number): string
    return "BossTrial_" .. id .. "_T" .. tier
end

-- Saved progress
function BossTrials.Progress(state: any, id: string): any
    local all = type(state) == "table" and type(state.BossTrials) == "table" and state.BossTrials or {}
    local p = all[id]
    if type(p) ~= "table" then p = { Best = 0, Times = {} } end
    if type(p.Times) ~= "table" then p.Times = {} end
    return p
end
function BossTrials.Unlocked(state: any, id: string, tier: number): boolean
    return tier <= 1 or BossTrials.Progress(state, id).Best >= tier - 1
end

-- The roster entry carries "<id>:<tier>" (client builds read it from the stand-in's Archetype)
function BossTrials.Encode(id: string, tier: number): string return id .. ":" .. tier end
-- "Archon:3" = a trial boss at tier III; "Archon:6:G" = a MAP GUARDIAN (0.66, Rifts.GUARDIANS): tier VI's pace, map health
function BossTrials.Decode(s: string?): (string?, number, boolean)
    local id, t, g = string.match(tostring(s or ""), "^(%w+):(%d+)(:?G?)$")
    return id, tonumber(t) or 1, g == ":G"
end

return BossTrials
