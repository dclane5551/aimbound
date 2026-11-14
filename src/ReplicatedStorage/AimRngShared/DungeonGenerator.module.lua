--!nocheck
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Remotes = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Remotes"))
local ItemData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ItemData"))
local EnemyAttacks = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("EnemyAttacks"))
local BossAI = require(script.Parent:WaitForChild("BossAI"))
local EnemyModels = require(script.Parent:WaitForChild("EnemyModels"))
local EnemyMind = require(script.Parent:WaitForChild("EnemyMind")) -- (enemies learn your strafe rhythm, dodge side, peeks)
local BotRoles = require(script.Parent:WaitForChild("BotRoles")) -- (ENEMY ATTACKS PILOT 2026-10-30: roles, visible shots, the new elite mods)
local RunService = game:GetService("RunService")

-- Dungeons are private: each one is built and run on its owner's CLIENT (map, enemy AI, attacks, chests).
-- The server never builds a dungeon any more -- it only rolls each enemy's stats (every Create* function
-- with spec.DryRun = true returns the stat-carrying model without building AI) and keeps a part-less
-- stand-in ("proxy") per enemy that holds the authoritative health / status (see DungeonRuns). The client
-- passes the proxy's attributes back in as `spec`, so its enemy uses exactly the server's numbers.
local IS_CLIENT = RunService:IsClient()
local LocalPlayer = Players.LocalPlayer
-- Who enemy AI targets: on the client only its owner (other players may stand at the same coordinates
-- inside their own private dungeons); in a server-run party dungeon only that party's members.
-- In the floor's entry room (the SAFE ZONE, same rule as CombatServer.InSafeZone)? Enemies -- bosses included --
-- don't target you there (owner 2026-10-02: "the bosses attack you in the spawn room, they should de-aggro").
local safeEndZ = nil
local function InSafeZone(p: Player): boolean
    if p:GetAttribute("SafeZone") == true then return true end -- (the server's word: covers the respawn protection too)
    local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if not root or p:GetAttribute("SafeLocked") then return false end
    local z = root.Position.Z
    return safeEndZ ~= nil and z > 450 and z < safeEndZ
end
local function TargetPlayers(config: any?): { Player }
    if IS_CLIENT then
        if InSafeZone(LocalPlayer) or LocalPlayer:GetAttribute("WatchUid") then return {} end -- (0.62: a watcher's puppet floor targets nobody)
        return { LocalPlayer }
    end
    local out = {}
    local list = (config and config.Members) or Players:GetPlayers()
    for _, p in ipairs(list) do
        -- (downed players stay targets so the room keeps moving -- DamagePlayer ignores them; spectators are gone)
        if p.Parent and not p:GetAttribute("Spectating") and not InSafeZone(p) then table.insert(out, p) end
    end
    return out
end

-- Is any member still in the arena at all (a target or not: in the safe room, downed or respawning all count)?
local function AnyoneInArena(config: any?): boolean
    local list = (config and config.Members) or Players:GetPlayers()
    for _, p in ipairs(list) do
        if p.Parent and not p:GetAttribute("Spectating") then
            if p:GetAttribute("Downed") then return true end
            local c = p.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if not hrp or (hrp :: BasePart).Position.Z > 450 then return true end -- (no body yet = respawning)
        end
    end
    return false
end

local hurtFx = nil
local function HurtFX() -- (client only)
    hurtFx = hurtFx or require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("HurtFX"))
    return hurtFx
end
local function ServerCombat(): any
    return require(game:GetService("ServerScriptService"):WaitForChild("AimRngServer"):WaitForChild("CombatServer"))
end

export type DungeonConfig = {
    Biome: "Fire" | "Ice" | "Void" | "Cyber" | "Storm",
    Difficulty: "Easy" | "Normal" | "Hard" | "Brutal" | "Nightmare" | "Endless",
    FloorNumber: number,
    PlayerLevel: number?,
}

local DungeonGenerator = {}

-- ==================== [BOT SKILL: the per-run movement difficulty slider (1-10)] ====================
-- Speed multiplies how fast bots move; Freq how often they change direction / blink / hop (pattern
-- tempo); Reward multiplies the run's XP, gold and loot quantity. Step 4 is the default ("a little
-- challenging but doable"); step 6 is about how bots moved before the slider existed; 10 is Celestial-level.
DungeonGenerator.BotSkillLevels = { -- 2026-10-02 (2nd pass): steps 1-6 ~12% slower again -- too hard for average players
    { Name = "Relaxed", Speed = 0.38, Freq = 0.47, Reward = 0.75 },
    { Name = "Casual", Speed = 0.45, Freq = 0.55, Reward = 0.83 },
    { Name = "Steady", Speed = 0.53, Freq = 0.63, Reward = 0.92 },
    { Name = "Standard", Speed = 0.59, Freq = 0.69, Reward = 1.00 },
    { Name = "Sharp", Speed = 0.71, Freq = 0.80, Reward = 1.12 },
    { Name = "Veteran", Speed = 0.84, Freq = 0.90, Reward = 1.25 },
    { Name = "Elite", Speed = 1.02, Freq = 1.07, Reward = 1.4 },
    { Name = "Pro", Speed = 1.11, Freq = 1.16, Reward = 1.55 },
    { Name = "Master", Speed = 1.22, Freq = 1.27, Reward = 1.75 },
    { Name = "Celestial", Speed = 1.38, Freq = 1.43, Reward = 2.0 }, -- (was "Voltaic"; owner 2026-10-04)
}
DungeonGenerator.DEFAULT_BOT_SKILL = 4
local FloorModsRef: any = nil
function DungeonGenerator.BotSkill(config: any?): any
    local lvl = math.clamp(math.floor((config and config.BotSkill) or DungeonGenerator.DEFAULT_BOT_SKILL), 1, 10)
    local base = DungeonGenerator.BotSkillLevels[lvl]
    if config and config.Mods then
        FloorModsRef = FloorModsRef or require(script.Parent:WaitForChild("FloorMods"))
        if FloorModsRef.Has(config.Mods, "RELENTLESS") then -- (0.62 map mod: two bot-skill steps up)
            base = DungeonGenerator.BotSkillLevels[math.min(10, lvl + 2)]
        end
        if FloorModsRef.Has(config.Mods, "FRENZIED") then -- floor modifier: faster enemies (MAPS V2: x the map's ModScale)
            local f = 1 + FloorModsRef.V("FRENZIED", config.ModScale)
            return { Name = base.Name, Speed = base.Speed * f, Freq = base.Freq * f, Reward = base.Reward }
        end
    end
    return base
end
-- (BOT MOVEMENT POE review) BOSSES' skill: a map's guardian / bosses / the loot goblin keep the pace of the map's old 6-10 roll
-- (config.BossSkill, Rifts.LegacySkill via StartRift) while its bots move at Standard; off maps it is the run's BotSkill
function DungeonGenerator.BossBotSkill(config: any?): any
    if config and config.BossSkill then
        return DungeonGenerator.BotSkill({ BotSkill = config.BossSkill, Mods = config.Mods, ModScale = config.ModScale })
    end
    return DungeonGenerator.BotSkill(config)
end
local function HasMod(config: any, id: string): boolean
    if not (config and config.Mods) then return false end
    FloorModsRef = FloorModsRef or require(script.Parent:WaitForChild("FloorMods"))
    return FloorModsRef.Has(config.Mods, id)
end
-- (MAPS V2 2026-10-30) a floor mod's value on this floor: x config.ModScale on a map (Rifts.ModScale(tier)), today's number elsewhere
function DungeonGenerator.ModV(config: any, id: string): number
    FloorModsRef = FloorModsRef or require(script.Parent:WaitForChild("FloorMods"))
    return FloorModsRef.V(id, config and config.ModScale)
end

-- Where attack effects (bolts, rings, lasers) are parented: the run's own folder for server-run party
-- dungeons (so other players' clients can hide them), Workspace otherwise.
-- live bots per floor config (for spacing them apart); weak keys so finished floors drop out
local BotGroups = setmetatable({}, { __mode = "k" })

local function FxParent(config: any?): Instance
    return (config and config.FxFolder) or Workspace
end

-- Attack wind-up scale (EnemyAttacks): shorter on harder difficulties and on Frenzied floors
local function WindupScale(config: any?): number
    local w = (config and EnemyAttacks.DifficultyWindup[config.Difficulty]) or 1
    if config and config.Mods then
        FloorModsRef = FloorModsRef or require(script.Parent:WaitForChild("FloorMods"))
        if FloorModsRef.Has(config.Mods, "FRENZIED") then w *= 1 - 0.6 * FloorModsRef.V("FRENZIED", config.ModScale) end -- (0.85 at x1)
    end
    return w
end
DungeonGenerator.WindupScale = WindupScale
-- ===== METHODICAL BOTS (0.61, owner: "some of the bots, specifically in the later level, still feel very spammy ... things
-- should hit way harder, but be a bit slow / easier to see / dodge ... more methodical, bringing back the focus to aiming
-- ... The bosses are fine being a bit more spammy"). Regular enemies only (CreateBot; bosses keep their own kits):
--   Windup   every bot wind-up is this long on EVERY difficulty (it used to shrink to 0.58x on the top tiers -- the spam)
--   Interval the gap between a bot's attacks (x1.8: about half as many attacks)
--   Hit      each hit lands this much harder (x1.9: the damage you take over a fight stays about the same if you never
--            dodge, and dodging is now what decides it)
--   Slots    at most this many bots winding up on you at once (elites: one more)
DungeonGenerator.BOT_PACE = { Windup = 1.3, Interval = 1.8, Hit = 1.9, Slots = 2 }
local function BotWindup(config: any?): number
    local w = DungeonGenerator.BOT_PACE.Windup
    if config and config.Mods then
        FloorModsRef = FloorModsRef or require(script.Parent:WaitForChild("FloorMods"))
        if FloorModsRef.Has(config.Mods, "FRENZIED") then w *= 1 - 0.6 * FloorModsRef.V("FRENZIED", config.ModScale) end -- (0.85 at x1)
    end
    return w
end
DungeonGenerator.BotWindup = BotWindup
-- ===== A SMOOTH CURVE THROUGH A RUN (0.61, owner: "floors 1-4 are like incredibly easy, and then after that everything
-- feels like 2-3x harder ... The difficulty increase throughout should be a small curve"). How far through the run a
-- floor is (0 = first floor, 1 = last; Endless climbs over its first 9 floors). Bots read their health / damage at a
-- COMBAT level that starts a third of the way up the tier's monster-level range (floor 1 was the very bottom) and ends
-- at the top, and specialists / elites phase in along it instead of switching on at floors 2, 3 and 4.
function DungeonGenerator.RunProgress(config: any): number
    local f = math.max(1, math.floor(config.FloorNumber or 1))
    local mode = ItemData.RunMode(config.Difficulty, (config :: any).Endless == true)
    local n = (mode and mode.MaxWaves) or 5
    if (config :: any).Endless or n > 100 then return math.clamp((f - 1) / 8, 0, 1) end
    return (n <= 1) and 1 or math.clamp((f - 1) / (n - 1), 0, 1)
end
DungeonGenerator.CURVE_START = 0.35
function DungeonGenerator.CombatLevel(config: any): number
    local ml = DungeonGenerator.MonsterLevel(config)
    local r = ItemData.MONSTER_LEVEL[config.Difficulty or "Easy"]
    if not r or (config :: any).Endless then return ml end
    local t = DungeonGenerator.RunProgress(config)
    return math.floor(r[1] + (r[2] - r[1]) * (DungeonGenerator.CURVE_START + (1 - DungeonGenerator.CURVE_START) * t) + 0.5)
end

-- ===== enemy projectiles =====
-- Every enemy shot is an anchored ball stepped by Fly: a spherecast each frame against the room geometry and
-- the targeted players. Walls and cover STOP shots (small spark) -- hiding behind cover works, and shots fly at
-- PROJECTILE_SPEED of their old speed so they can be dodged. (They used to be unanchored balls pushed by a
-- BodyVelocity that only listened for touching a player, so they flew straight through walls.)
-- Which red-area attack each ranged bot uses (no projectiles -- every attack is a telegraphed area):
--   Circle (r6) default, Quick (small, fast), Big (wide, slow), Strip (a lane from the bot through you),
--   Snipe (long thin lane, hits hard), Barrage (several circles around you)
local RANGED_KIND = {
    Tracker = "Strip", Runner = "Strip", Warden = "Strip", Comet = "Quick",
    Strafer = "Quick", Skirmisher = "Quick", Splitling = "Quick", Medic = "Quick",
    Drifter = "Big", Sniper = "Snipe", Gunship = "Barrage",
    Popper = "Quick", Zipper = "Quick", Seraph = "Strip", Orbiter = "Strip",
    -- STORMSPIRE: Chain (three strikes hopping along your path), Cross (a strip ACROSS the line to you -- step forward or
    -- back), Clap (a strike + a shockwave rolling out of it), Triad (three strikes around you, then one on you)
    Stormcaller = "Chain", Gale = "Cross", Arcwalker = "Clap", Spark = "Quick", Conductor = "Triad",
    -- BIOME ROSTERS: MOLTEN Flare (a burst that keeps burning), Fissure (a line of bursts racing from it through you),
    -- Scorch (a narrow fire fan), Crucible (a big burning pool); CRYO Shatter (a burst that throws four shards),
    -- FrozenLane (a lane that stays icy), Sleet (two lanes either side of you), CryoLock (a hunting mark); VOID Echo
    -- (strikes twice in one place), Twin (where you are + your reflection), RiftLance (a lane, then one across it),
    -- Gaze (a tracking beam); CYBER Gridlock (a plus through you), Ping (small and fast), Trident (three lanes), Firewall
    -- (a floor laser sweeping round it)
    Cinder = "Flare", Magmaw = "Fissure", Ashwing = "Scorch", Smelter = "Crucible",
    Shardling = "Shatter", Frostbite = "FrozenLane", Flurry = "Sleet", Cryomancer = "CryoLock",
    Phasewing = "Echo", Mirrorshade = "Twin", Riftling = "RiftLance", Watcher = "Gaze",
    Raster = "Gridlock", Tracer = "Ping", Uplink = "Trident", Firewall = "Firewall",
    -- ROSTER v2 (2026-10-04, owner: "continue to add more enemy variety"): MOLTEN Carom (a lane to you that BOUNCES off
    -- your spot at an angle), CRYO Icefall (a ring of strikes round you, then one on you -- slip out through a gap), VOID
    -- Collapse (rings of strikes closing in on you), CYBER Bitstream (a zig-zag lane ending on you)
    Slagroller = "Carom", Rimewyrm = "Icefall", Antipode = "Collapse", Glitch = "Bitstream",
}
local PROJECTILE_SPEED = 1.55 -- (raised 2026-10-02 with the movement tech: shots must be fast enough to really threaten)
local function Fly(config: any?, part: BasePart, velocity: Vector3, life: number, onPlayer: (Player) -> ())
    part.Anchored = true
    part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
    velocity *= PROJECTILE_SPEED
    local geo = config and config.Geo
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    local born = os.clock()
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if not part.Parent or os.clock() - born > life then
            conn:Disconnect()
            if part.Parent then part:Destroy() end
            return
        end
        local list = {}
        if geo and geo.Parent then table.insert(list, geo) end
        for _, pl in ipairs(TargetPlayers(config)) do
            if pl.Character then table.insert(list, pl.Character) end
        end
        params.FilterDescendantsInstances = list
        local from = part.Position
        local step = velocity * math.min(dt, 0.1)
        local hit = Workspace:Spherecast(from, math.max(0.2, part.Size.X / 2), step, params)
        if hit then
            conn:Disconnect()
            local who = Players:GetPlayerFromCharacter(hit.Instance:FindFirstAncestorOfClass("Model"))
            if who then
                onPlayer(who)
            else
                local spark = Instance.new("Part")
                spark.Name = "PulseSpark"; spark.Shape = Enum.PartType.Ball; spark.Size = Vector3.new(1.2, 1.2, 1.2)
                spark.CFrame = CFrame.new(hit.Position); spark.Material = Enum.Material.Neon; spark.Color = part.Color
                spark.Transparency = 0.4; spark.Anchored = true; spark.CanCollide = false; spark.CanQuery = false; spark.CanTouch = false
                spark.Parent = part.Parent
                Debris:AddItem(spark, 0.12)
            end
            part:Destroy()
            return
        end
        part.CFrame = CFrame.new(from + step)
    end)
end
DungeonGenerator.Fly = Fly

-- RunId of the party dungeon an instance belongs to (nil = not in one).
local function RunIdOf(inst: Instance?): string?
    local node = inst
    while node and node ~= Workspace do
        local id = node:GetAttribute("RunId")
        if id then return id end
        node = node.Parent
    end
    return nil
end
DungeonGenerator.RunIdOf = RunIdOf

-- MIXED RUNS (2026-10-03, owner: "the biome selection is honestly kind of pointless... every room that you get is
-- random and has specific enemy types for that biome"): there is no biome pick any more. Every floor of a run rolls
-- its own biome from a shuffle bag -- all five come up before any repeats, and never the same one twice in a row.
-- The server rolls it (DungeonRuns.StartFloor / PartyRuns.BuildFloor); Boss Trials keep their own biome.
DungeonGenerator.BIOMES = { "Fire", "Ice", "Cyber", "Void", "Storm", "Dream", "Flats" } -- (0.53: + Dreamscape, Neon Flats -- NewBiomes)
DungeonGenerator.NB = require(script.Parent:WaitForChild("NewBiomes"))
-- (0.87 WORLDS: the twelve world biomes join the rotation -- NB.BIOMES carries them, merged by WorldBiomes)
for _, b in ipairs(DungeonGenerator.NB.BIOMES) do
    if not table.find(DungeonGenerator.BIOMES, b) then table.insert(DungeonGenerator.BIOMES, b) end
end
DungeonGenerator.BIOME_TITLES = {
    Fire = { Name = "MOLTEN", Color = Color3.fromRGB(255, 120, 50) },
    Ice = { Name = "CRYO", Color = Color3.fromRGB(110, 210, 255) },
    Cyber = { Name = "CYBER", Color = Color3.fromRGB(60, 230, 170) },
    Void = { Name = "VOID", Color = Color3.fromRGB(180, 100, 255) },
    Storm = { Name = "STORMSPIRE", Color = Color3.fromRGB(160, 215, 255) },
}
-- holder: any table that keeps the bag between floors (a run); rng: a Random (the Daily passes a seeded one)
function DungeonGenerator.NextBiome(holder: any, rng: Random?): string
    local r = rng or Random.new()
    local bag = holder.BiomeBag
    if not bag or #bag == 0 then
        bag = table.clone(DungeonGenerator.BIOMES)
        for i = #bag, 2, -1 do
            local j = r:NextInteger(1, i)
            bag[i], bag[j] = bag[j], bag[i]
        end
        -- (popped from the end: never open a new bag with the biome you just left)
        if #bag > 1 and bag[#bag] == holder.LastBiome then bag[#bag], bag[1] = bag[1], bag[#bag] end
        holder.BiomeBag = bag
    end
    local b = table.remove(bag)
    holder.LastBiome = b
    return b
end

-- ==================== BOSS PLAN (owner 2026-10-05: "A run shouldn't really be repeating bosses often") ====================
-- The mini-boss used to be picked by floor number (floor 3 = Goliath on every 5-floor run) and the major boss was a coin
-- flip. Now the SERVER plans each boss floor from a per-run holder (the solo run / the party): mini-bosses come out of a
-- shuffle bag (all three before a repeat, never the same twice running), a major boss is a fight not yet seen this run
-- (the Titan or the floor's biome boss). The plan rides in config.BossPlan; RollFloorRoster reads it (clients get the
-- roster, not the plan, so party floors match).
DungeonGenerator.MINI_BOSSES = { "Goliath", "Phantom", "Sentinel", "Ravager", "Hexcaller" } -- (2026-10-07: + Ravager / Hexcaller, owner: "more miniboss variation")
function DungeonGenerator.PlanBoss(holder: any, config: any)
    config.BossPlan = nil
    if config.BossTrial or config.AscTrial or config.Raid or not ItemData.IsBossConfig(config) then return end
    holder.BossSeen = holder.BossSeen or {}
    local seen = holder.BossSeen
    local floor = config.FloorNumber
    local mode = ItemData.RunMode(config.Difficulty, config.Endless)
    local isSuper = mode and mode.SuperBossWave and floor == mode.SuperBossWave
    local isMajor = (mode and mode.BossWaves and table.find(mode.BossWaves, floor) ~= nil) or (floor > 100 and floor % 10 == 0)
    if isSuper then
        seen["Super:" .. tostring(config.Biome)] = floor
        return
    end
    if isMajor then
        local liteKey = "Super:" .. tostring(config.Biome)
        local opts = {}
        if not seen.Titan then table.insert(opts, "Titan") end
        if not seen[liteKey] then table.insert(opts, "Lite") end
        if #opts == 0 then -- both seen: the one seen longest ago
            opts = { ((seen.Titan or 0) <= (seen[liteKey] or 0)) and "Titan" or "Lite" }
        end
        local pick = opts[math.random(1, #opts)]
        seen[pick == "Titan" and "Titan" or liteKey] = floor
        config.BossPlan = pick
        return
    end
    local bag = holder.MiniBag
    if not bag or #bag == 0 then
        bag = table.clone(DungeonGenerator.MINI_BOSSES)
        for i = #bag, 2, -1 do local j = math.random(1, i); bag[i], bag[j] = bag[j], bag[i] end
        if #bag > 1 and bag[#bag] == holder.LastMini then bag[#bag], bag[1] = bag[1], bag[#bag] end
        holder.MiniBag = bag
    end
    local kind = table.remove(bag)
    -- (Studio test hook: workspace attribute DevMiniBoss = "Ravager" etc. forces that mini-boss)
    local dev = game:GetService("RunService"):IsStudio() and workspace:GetAttribute("DevMiniBoss")
    if type(dev) == "string" and table.find(DungeonGenerator.MINI_BOSSES, dev) then kind = dev end
    holder.LastMini = kind
    seen[kind] = floor
    config.BossPlan = kind
end

local BiomePalettes = {
    Fire = {
        FloorColor = BrickColor.new("Dark stone grey"),
        WallColor = BrickColor.new("Really black"),
        AccentColor = BrickColor.new("Bright orange"),
        LightColor = Color3.fromRGB(255, 90, 20),
        FloorMaterial = Enum.Material.Slate,
        HazardColor = BrickColor.new("Bright red"),
        HazardName = "Molten Fissure",
    },
    Ice = {
        FloorColor = BrickColor.new("Institutional white"),
        WallColor = BrickColor.new("Medium stone grey"),
        AccentColor = BrickColor.new("Cyan"),
        LightColor = Color3.fromRGB(40, 220, 255),
        FloorMaterial = Enum.Material.Glacier,
        HazardColor = BrickColor.new("Cyan"),
        HazardName = "Cryogenic Vent",
    },
    Void = {
        FloorColor = BrickColor.new("Black"),
        WallColor = BrickColor.new("Really black"),
        AccentColor = BrickColor.new("Bright violet"),
        LightColor = Color3.fromRGB(180, 40, 255),
        FloorMaterial = Enum.Material.CorrodedMetal,
        HazardColor = BrickColor.new("Magenta"),
        HazardName = "Void Singularity",
    },
    Cyber = {
        FloorColor = BrickColor.new("Dark stone grey"),
        WallColor = BrickColor.new("Black"),
        AccentColor = BrickColor.new("Lime green"),
        LightColor = Color3.fromRGB(40, 255, 120),
        FloorMaterial = Enum.Material.DiamondPlate,
        HazardColor = BrickColor.new("Lime green"),
        HazardName = "Overcharged Conduit",
    },
    -- STORMSPIRE (overnight 2026-10-03): a ruined sky citadel in a permanent thunderstorm -- weathered white stone,
    -- copper lightning rods, rain and lightning; its own enemies (Stormcaller, Gale, Arcwalker, Spark, Conductor) and
    -- the TEMPEST SOVEREIGN superboss
    Storm = {
        FloorColor = BrickColor.new("Medium stone grey"),
        WallColor = BrickColor.new("Dark stone grey"),
        AccentColor = BrickColor.new("Pastel Blue"),
        LightColor = Color3.fromRGB(150, 205, 255),
        FloorMaterial = Enum.Material.Slate,
        HazardColor = BrickColor.new("Pastel Blue"),
        HazardName = "Lightning Rod",
    },
}

-- 6 tiers now (was 4) -- Brutal/Nightmare give real, meaningful steps between "Hard" and "Endless"
-- instead of the two extremes sitting right next to each other. Combined with the per-level scaling
-- in GetScalingMultiplier below, a hardest-difficulty run at a high character level should still be
-- a genuine fight, not something any single upgrade trivializes.
local DifficultyScaling = {
    -- HealthMult / Damage are the difficulty multipliers on top of the level curve (Damage x 0.1 = damage
    -- multiplier): Easy 1x HP / 1x dmg ... Endless 6x HP / 3.5x dmg. HealthMult includes the 0.4 base that
    -- matches the new weapon damage scale (an L1 starter pistol kills an L1 Easy Scout in ~1.2s).
    -- (2026-10-02 tuning, owner feedback "slightly too hard everywhere": HP -15%, damage -15..20%, attack tempo down)
    -- CONTENT LEVEL (2026-10-05): HealthMult / Damage are now the CHALLENGE on top of the monster level -- enemy health =
    -- base x LevelCurve(ML) x ItemData.EnemyHpIndex(ML) x HealthMult, damage = base x LevelCurve(ML) x EnemyDmgIndex(ML) x
    -- Damage x 0.1 (ML = ItemData.MonsterLevel(difficulty, endless, floor)). The index already follows a typical build's
    -- power at that level, so these only climb gently: every tier is a little harder for an on-level player than the last.
    -- (Before, enemies took YOUR level and these alone made tiers harder -- vs a built character the top tiers were ~15x
    -- easier than Hard. Easy / Normal match the old numbers at their levels.)
    Easy = { Damage = 8, SpeedMult = 1.0, HealthMult = 0.34, XpReward = 50, GoldMin = 30, GoldMax = 60 },
    Normal = { Damage = 9.5, SpeedMult = 1.05, HealthMult = 0.42, XpReward = 85, GoldMin = 55, GoldMax = 110 },
    Hard = { Damage = 12, SpeedMult = 1.25, HealthMult = 0.5, XpReward = 140, GoldMin = 90, GoldMax = 180 },
    Brutal = { Damage = 15, SpeedMult = 1.5, HealthMult = 0.58, XpReward = 210, GoldMin = 140, GoldMax = 260 },
    Nightmare = { Damage = 18, SpeedMult = 1.65, HealthMult = 0.66, XpReward = 300, GoldMin = 200, GoldMax = 380 },
    Torment = { Damage = 22, SpeedMult = 1.9, HealthMult = 0.75, XpReward = 560, GoldMin = 360, GoldMax = 680 },
    Cataclysm = { Damage = 26, SpeedMult = 2.0, HealthMult = 0.84, XpReward = 720, GoldMin = 460, GoldMax = 860 },
    Oblivion = { Damage = 30, SpeedMult = 2.1, HealthMult = 0.93, XpReward = 920, GoldMin = 580, GoldMax = 1080 },
    Ruin = { Damage = 34, SpeedMult = 2.2, HealthMult = 1.02, XpReward = 1100, GoldMin = 680, GoldMax = 1260 },
    Dread = { Damage = 38, SpeedMult = 2.3, HealthMult = 1.12, XpReward = 1300, GoldMin = 780, GoldMax = 1450 },
    Apocalypse = { Damage = 42, SpeedMult = 2.4, HealthMult = 1.22, XpReward = 1500, GoldMin = 900, GoldMax = 1670 },
    Annihilation = { Damage = 46, SpeedMult = 2.5, HealthMult = 1.33, XpReward = 1750, GoldMin = 1040, GoldMax = 1920 },
    Eternity = { Damage = 50, SpeedMult = 2.6, HealthMult = 1.45, XpReward = 2000, GoldMin = 1190, GoldMax = 2200 },
    Singularity = { Damage = 55, SpeedMult = 2.7, HealthMult = 1.6, XpReward = 2300, GoldMin = 1370, GoldMax = 2530 },
    Endless = { Damage = 18, SpeedMult = 1.8, HealthMult = 0.66, XpReward = 420, GoldMin = 280, GoldMax = 520 }, -- (legacy)
}

-- Loot by difficulty (CombatServer uses these): Qty multiplies item / material drop amounts, Luck the rarity odds.
DungeonGenerator.DifficultyScaling = DifficultyScaling -- (FUTURE-PROOF: read by ContentCheck)
DungeonGenerator.DifficultyLoot = {
    Qty = { Easy = 1.0, Normal = 1.25, Hard = 1.55, Brutal = 1.9, Nightmare = 2.3, Torment = 2.7, Cataclysm = 3.1, Oblivion = 3.6,
        Ruin = 4.0, Dread = 4.4, Apocalypse = 4.8, Annihilation = 5.2, Eternity = 5.6, Singularity = 6.0, Endless = 2.3 }, -- (2026-10-02: drops felt too generous)
    -- rarity luck (owner 2026-10-04: "the loot rarity for the floors also isnt great, make that scale way better")
    -- (DROPS v3, 2026-10-05: gentler -- the rarity weights' exponents do the work; ItemData.RarityBaseShare)
    -- (0.99n RARITY LADDER v3: the difficulty's nudge on the fixed rarity ladder -- one table, ItemData.RARITY_AREA)
    Luck = ItemData.RARITY_AREA,
}
-- Everything a difficulty changes, relative to Easy (the Dungeons window shows it).
function DungeonGenerator.DifficultyInfo(diff: string): any
    local d = DifficultyScaling[diff] or DifficultyScaling.Easy
    local e = DifficultyScaling.Easy
    return {
        HP = d.HealthMult / e.HealthMult, Damage = d.Damage / e.Damage, XP = d.XpReward / e.XpReward,
        Gold = (d.GoldMin + d.GoldMax) / (e.GoldMin + e.GoldMax),
        Luck = DungeonGenerator.DifficultyLoot.Luck[diff] or 1, Qty = DungeonGenerator.DifficultyLoot.Qty[diff] or 1,
        Mythic = ItemData.MaxRarityRank(diff) >= ItemData.RarityRank.Mythic, -- (UPDATE 8 RARITY v4: Mythics from Torment)
        MonsterLevel = ItemData.MONSTER_LEVEL[diff] or ItemData.MONSTER_LEVEL.Easy, -- { lo, hi }
        TopRarity = ItemData.Rarities[ItemData.MaxRarityRank(diff)], -- (RARITY v4: Rare, or Mythic from Torment)
    }
end

-- Scales an enemy's stats by BOTH the floor number (later floors in one run are tougher, same as
-- before) and the player's own character level. Previously HP/damage only ever tracked FloorNumber,
-- so once a player out-leveled the content (any weapon upgrade, skill node, gear piece), every floor
-- forever after became trivial -- there was nothing in the formula that cared how strong the player
-- had gotten. floorRate is how steeply floor number matters for THIS enemy type (bosses use a steeper
-- rate than trash mobs, same per-function rates as before); the level half is flat across every enemy
-- type on purpose, so the whole game keeps pace with the player's own progression evenly.
-- Enemy POWER (health & damage): the same exponential level curve the player's gear follows
-- (ItemData.LevelCurve at the player's level) plus a small +4% per floor within a run. Difficulty
-- multipliers are applied on top via DifficultyScaling.
function DungeonGenerator.GetScalingMultiplier(config: DungeonConfig, _floorRate: number?): number
    -- CONTENT LEVEL (2026-10-05): the curve at the floor's MONSTER LEVEL (ItemData.MonsterLevel), not the player's level.
    -- The small per-floor bonus stays (later floors in a run are a bit tougher on top).
    -- (MAP PACING 2026-10-31: a map's enemies use its POWER level -- the map level without the rarity's part, Rifts.PowerLevel)
    return ItemData.LevelCurve((config :: any).PowerLevel or DungeonGenerator.MonsterLevel(config)) * (1 + (math.max(1, config.FloorNumber) - 1) * 0.03)
end
function DungeonGenerator.MonsterLevel(config: any): number
    if (config :: any).MonsterLevel then return (config :: any).MonsterLevel end -- (set by the run builders / trials)
    return ItemData.MonsterLevel(config.Difficulty, (config :: any).Endless == true, config.FloorNumber)
end
-- enemy health / damage on top of the curve: a typical build's power at the monster level (ItemData.EnemyHpIndex)
function DungeonGenerator.HpScale(config: any): number return ItemData.EnemyHpIndex(DungeonGenerator.MonsterLevel(config)) end
function DungeonGenerator.DmgScale(config: any): number return ItemData.EnemyDmgIndex(DungeonGenerator.MonsterLevel(config)) end

-- Enemy REWARDS (XP & gold) grow gently (linear), not with the exponential power curve -- the XP needed
-- per level and all gold prices are tuned for this pace.
-- XP for an enemy worth `units` (LEVELING PACE, ItemData.KillXp): built from the player level, the difficulty and floor
function DungeonGenerator.EnemyXp(config: DungeonConfig, units: number): number
    -- (2026-10-23 EARLY RAMP: a ramped floor's fewer kills each pay a little more)
    local PP = require(script.Parent:WaitForChild("PacksPilot"))
    return math.max(1, math.round(ItemData.KillXp(math.max(1, config.PlayerLevel or 1), config.Difficulty, config.FloorNumber, units) * ((units <= 5) and PP.EarlyXp(config.Difficulty, config.FloorNumber) * DungeonGenerator.EarlyPayOf(config) or 1)
        / ItemData.RunLengthXp(config))) -- (EarlyXp: bots + elites, not bosses; RunLengthXp: every kill on a normal run, bosses too)
end
-- (EARLY DENSITY 2026-11-07) a regular run floor's per-kill pay for the thinner early packs (PacksPilot.EarlyPay): XP (EnemyXp), gold
-- (CreateBot) and the item chance (attr EarlyPay -> CombatServer GiveKillRewards). Maps / trials / special runs: 1.
function DungeonGenerator.EarlyPayOf(config: any): number
    if type(config) ~= "table" or config.SpecialRun or config.Rift or config.MapTier or config.MonsterLevel or config.BossTrial or config.AscTrial or config.MapGuardian then return 1 end
    return require(script.Parent:WaitForChild("PacksPilot")).EarlyPay(config.Difficulty, config.FloorNumber)
end
function DungeonGenerator.GetRewardMultiplier(config: DungeonConfig): number
    -- (gold grows linearly with the MONSTER level: farming a tier far below you pays what that tier pays)
    return (1 + config.FloorNumber * 0.1) * (1 + (DungeonGenerator.MonsterLevel(config) - 1) * 0.05)
end

local function MakePart(props: { [string]: any }): Part
    local p = Instance.new("Part")
    for k, v in pairs(props) do
        if k == "Parent" then
            -- Set Parent last
        elseif k == "Position" then
            p.CFrame = CFrame.new(v)
        else
            (p :: any)[k] = v
        end
    end
    if props.Anchored == nil then p.Anchored = true end
    if props.CanCollide == nil then p.CanCollide = true end
    p.Parent = props.Parent
    return p
end

-- ==================== [ENEMY OBSTACLE AVOIDANCE] ====================
-- All room geometry lives in DungeonFacility.StaticGeometry. Enemies used to fly in straight lines
-- right through pillars, props and platforms; now every movement step sweeps a sphere the size of the
-- enemy ahead of it and, if blocked, steers to the first clear heading (sideways / over / under).
local paramsByGeo: { [Instance]: { any } } = setmetatable({}, { __mode = "k" }) :: any

-- geo = a dungeon's StaticGeometry folder (config.Geo); nil = the local Workspace.DungeonFacility's.
local function ObstacleParams(geo: Instance?): (RaycastParams?, OverlapParams?)
    if not geo then
        local dungeon = Workspace:FindFirstChild("DungeonFacility")
        geo = dungeon and dungeon:FindFirstChild("StaticGeometry")
    end
    if not geo or not geo.Parent then return nil, nil end
    local cached = paramsByGeo[geo]
    if not cached then
        -- (fixes 2026-10-16 #7, playtester: "enemies can sometimes clip into geometry"): the floor's BotObstacles folder
        -- (dungeon events: shrines, the gamble altar, the merchant stall -- DungeonEvents parents them there) is solid to
        -- bots too; they used to walk straight through anything outside StaticGeometry
        local dungeon = geo.Parent
        local obs = dungeon and dungeon:FindFirstChild("BotObstacles")
        if dungeon and not obs then
            obs = Instance.new("Folder"); obs.Name = "BotObstacles"; obs.Parent = dungeon
        end
        local list = obs and { geo, obs } or { geo }
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Include
        rp.FilterDescendantsInstances = list
        local op = OverlapParams.new()
        op.FilterType = Enum.RaycastFilterType.Include
        op.FilterDescendantsInstances = list
        cached = { rp, op }
        paramsByGeo[geo] = cached
    end
    return cached[1], cached[2]
end

function DungeonGenerator.IsSpotBlocked(pos: Vector3, radius: number, geo: Instance?): boolean
    local _, op = ObstacleParams(geo)
    if not op then return false end
    return #Workspace:GetPartBoundsInRadius(pos, radius, op) > 0
end
-- (MOVEMENT ROUND 2, owner: bots "get stuck behind objects under certain circumstances or angles") can a bot's BODY walk from a to
-- b in a straight line? A body-wide cast (started half a body back, like SteerStep's: casts skip what they start in) through the
-- floor's geometry + its BotObstacles, and on the client the terrain (one ray + the body at the half-way point: rims / boulders have
-- no collider). BotMove's spot picks + stall detours use it; the old thin ray let a detour pick a spot past a corner it then brushed.
function DungeonGenerator.PathClear(a: Vector3, b: Vector3, radius: number, geo: Instance?): boolean
    local d = b - a
    local m = d.Magnitude
    if m < 0.5 then return true end
    local rp = ObstacleParams(geo)
    if rp then
        local back = d / m * (radius * 0.5)
        if Workspace:Spherecast(a - back, radius * 0.9, d + back, rp) ~= nil then return false end
    end
    if IS_CLIENT and geo then
        if not DungeonGenerator.LinkSees(a, b, geo) then return false end
        if m > radius * 3 and DungeonGenerator.BodyInTerrain(a + d * 0.5, radius * 0.9) then return false end
    end
    return true
end

-- (0.60d, owner: "Blinking enemies blink far too often, make them blink about 66% less often ... so you actually have a
-- chance to kill them"): every teleport / phase / dash-blink / snap timer is stretched by BLINK_SLOW (Blinker, Blinking
-- elites, Antipode flips, Phasewing phases, Tracer + Roadrunner dashes, Glitch snaps)
DungeonGenerator.BLINK_SLOW = 6 -- (0.62, owner: "Blinking / teleporting enemies need to tp half as much": 3 -> 6)
-- TURN TEMPO (0.62, owner: "the speed of the highest difficulty is fine, the problem is they are constantly changing
-- directions. They need to do longer strafes so the player can shoot"): direction-change timers (Zipper, Raster, Ashwing,
-- Seraph, Gale's hover) speed up with the bot-skill Freq only up to TURN_FREQ_MAX -- above it bots still MOVE faster
-- (Speed, phase), but don't turn more often.
DungeonGenerator.TURN_FREQ_MAX = 0.8 -- (0.62 bot revamp: 0.9 -> 0.8)
local function TurnFreq(skill: any): number return math.min(skill.Freq, DungeonGenerator.TURN_FREQ_MAX) end
-- (BOTFIX 2026-10-24) is this point inside solid terrain? (one 4-stud voxel read; client floors only -- terrain is client-built)
function DungeonGenerator.InTerrain(pos: Vector3): boolean
    local ok, solid = pcall(function()
        local reg = Region3.new(pos - Vector3.new(0.05, 0.05, 0.05), pos + Vector3.new(0.05, 0.05, 0.05)):ExpandToGrid(4)
        local mats, occ = Workspace.Terrain:ReadVoxels(reg, 4)
        local m = mats[1] and mats[1][1] and mats[1][1][1]
        return m ~= nil and m ~= Enum.Material.Air and m ~= Enum.Material.Water and occ[1][1][1] > 0.5
    end)
    return ok and solid == true
end
-- (RUNFIX 2026-10-25) is the bot's BODY in solid terrain? InTerrain read one voxel at the centre, so a bot half inside a canyon
-- wall / boulder passed. One ReadVoxels over the body's box: a half-solid cell (occupancy >= 0.5: the rock surface runs
-- through it, so a bot there looks half buried; 0.7 let bots sit in the surface) that the body's core reaches
-- (the centre within r x 0.35 of the cell) counts. `minY` = ignore cells whose middle is below it (walkers: the ground under them).
function DungeonGenerator.BodyInTerrain(pos: Vector3, r: number, minY: number?): boolean
    local ok, solid = pcall(function()
        local e = Vector3.new(r, r, r)
        local reg = Region3.new(pos - e, pos + e):ExpandToGrid(4)
        local mats, occ = Workspace.Terrain:ReadVoxels(reg, 4)
        local o = reg.CFrame.Position - reg.Size / 2
        local reach = r * 0.35
        local sz = occ.Size
        for x = 1, sz.X do
            for y = 1, sz.Y do
                for z = 1, sz.Z do
                    local m = mats[x][y][z]
                    if m ~= Enum.Material.Air and m ~= Enum.Material.Water and occ[x][y][z] >= 0.5 then
                        local lo = o + Vector3.new(x * 4 - 4, y * 4 - 4, z * 4 - 4)
                        if not minY or lo.Y + 2 >= minY then
                            local q = Vector3.new(math.clamp(pos.X, lo.X, lo.X + 4), math.clamp(pos.Y, lo.Y, lo.Y + 4), math.clamp(pos.Z, lo.Z, lo.Z + 4))
                            if (q - pos).Magnitude <= reach then return true end
                        end
                    end
                end
            end
        end
        return false
    end)
    return ok and solid == true
end
-- (RUNFIX 2026-10-25) TERRAIN GUARD: terrain has no collider, so a bot whose target (its post / strafe spot / chase point)
-- sat in a rim, bank or boulder flew straight into it, and after a step-out flew straight back. Twice a second (bots within
-- TERR_GUARD_DIST of the camera, client only) the target and the point TERR_AHEAD studs along the way to it are read
-- (BodyInTerrain); in rock -> the bot holds at the furthest free point toward it (0.75 / 0.5 / 0.25 of the way, else where it
-- is) until a later read finds the target free. A step-out pins the hold to its new spot for TERR_PIN s.
DungeonGenerator.TERR_GUARD_DIST, DungeonGenerator.TERR_AHEAD, DungeonGenerator.TERR_PIN = 120, 4, 1.2
function DungeonGenerator.TerrGuard(kv: any, cur: Vector3, desired: Vector3, r: number, minY: number?, now: number, spd: number): Vector3
    if now >= (kv.tgAt or 0) then
        local cam = Workspace.CurrentCamera
        kv.tgNear = cam ~= nil and (cam.CFrame.Position - cur).Magnitude <= DungeonGenerator.TERR_GUARD_DIST
        kv.tgAt = now + (kv.tgNear and 0.22 or 0.9) + math.random() * 0.06
        if not kv.tgNear then
            kv.tgHold = nil
            return desired
        end
        local way = desired - cur
        local bad = DungeonGenerator.BodyInTerrain(desired, r, minY)
        -- (the look-ahead covers what the bot can travel before the next read: fast walkers outran a fixed 4 studs)
        local ahead = math.min(way.Magnitude, math.max(DungeonGenerator.TERR_AHEAD, spd * 0.3) + r)
        if not bad and ahead > r + 1 then
            bad = DungeonGenerator.BodyInTerrain(cur + way.Unit * ahead, r, minY)
                or (ahead > 2 * r + 2 and DungeonGenerator.BodyInTerrain(cur + way.Unit * (ahead * 0.5), r, minY))
        end
        if bad then
            local hold = nil
            for _, t in ipairs({ 0.75, 0.5, 0.25 }) do
                local p = cur + way * t
                if not DungeonGenerator.BodyInTerrain(p, r, minY) then hold = p break end
            end
            kv.tgHold, kv.tgUntil = hold or cur, now + 0.5
        elseif now >= (kv.tgPin or 0) then
            kv.tgHold = nil
        end
    end
    if kv.tgHold and now < (kv.tgUntil or 0) then return kv.tgHold end
    return desired
end
-- Nearest unobstructed point to `pos` (for spawns, waypoints and blink/teleport abilities). (RUNFIX 2026-10-25: never in
-- terrain on the client either -- blinks / peeks / redeploys landed in rim rock)
function DungeonGenerator.OpenAt(p: Vector3, radius: number, geo: Instance?): boolean
    return not DungeonGenerator.IsSpotBlocked(p, radius, geo) and not (IS_CLIENT and DungeonGenerator.BodyInTerrain(p, radius))
end
function DungeonGenerator.FindOpenSpot(pos: Vector3, radius: number, geo: Instance?): Vector3
    if DungeonGenerator.OpenAt(pos, radius, geo) then return pos end
    for ring = 1, 6 do
        local dist = ring * radius * 1.6
        for i = 0, 7 do
            local ang = i * math.pi / 4 + ring * 0.4
            local cand = pos + Vector3.new(math.cos(ang) * dist, (ring % 2 == 0) and ring * 1.5 or 0, math.sin(ang) * dist)
            if DungeonGenerator.OpenAt(cand, radius, geo) then return cand end
        end
    end
    return pos + Vector3.new(0, 10, 0)
end

local STEER_OFFSETS = { 35, -35, 70, -70, 110, -110, 150, -150 }
-- Move from currentPos toward targetPos by up to stepDist without passing through room geometry.
-- flat = a walker: it can't climb over things (it gets snapped back to the floor), so when boxed in it waits
function DungeonGenerator.SteerStep(currentPos: Vector3, targetPos: Vector3, stepDist: number, radius: number, geo: Instance?, flat: boolean?): Vector3
    local delta = targetPos - currentPos
    local dist = delta.Magnitude
    if dist < 0.05 or stepDist <= 0 then return currentPos end
    local step = math.min(stepDist, dist)
    local dir = delta / dist
    local rp = ObstacleParams(geo)
    if not rp then return currentPos + dir * step end

    local look = math.max(step * 3, radius * 2.2)
    -- (fixes 2026-10-16 #7) two clip holes closed: (1) shapecasts skip whatever they START inside, so a bot already
    -- touching a wall saw "clear" deeper into it -- every cast now starts half a body BEHIND the bot; (2) a walker's
    -- sphere sits round its middle, so a ramp's low end / a low ledge slid under it while the pill body went in --
    -- walkers also cast a sphere at foot height (bottom ~2 radii under the root: just above the floor, measured on the
    -- ridge covers -- two wedges back to back, 4 high -- where the pill's lower cap went into the slope).
    local function Clear(d: Vector3): boolean
        local back = d * (radius * 0.5)
        if Workspace:Spherecast(currentPos - back, radius, d * (look + radius * 0.5), rp) ~= nil then return false end
        if flat and Workspace:Spherecast(currentPos - back - Vector3.new(0, radius * 1.25, 0), radius * 0.8, d * (look + radius * 0.5), rp) ~= nil then return false end
        return true
    end
    if Clear(dir) then return currentPos + dir * step end
    for _, deg in ipairs(STEER_OFFSETS) do
        local d = (CFrame.fromAxisAngle(Vector3.yAxis, math.rad(deg)) * dir)
        if Clear(d) then return currentPos + d * step end
    end
    if flat then return currentPos end
    local up, down = (dir + Vector3.new(0, 1.2, 0)).Unit, (dir - Vector3.new(0, 1.2, 0)).Unit
    if Clear(up) then return currentPos + up * step end
    if Clear(down) then return currentPos + down * step end
    return currentPos + Vector3.new(0, step * 0.5, 0) -- boxed in: rise out of it
end

-- ==================== [ENEMY VISUAL SOFTENING] ====================
-- Enemies were built entirely from Neon parts plus PointLights, which bloomed into blinding blobs
-- (especially white/cyan ones in the Cryo biome). Bodies become matte; weak spots (Head/Core) keep a
-- dimmed glow so they still read as the thing to aim at.
local function Darken(c: Color3, amount: number): Color3
    return c:Lerp(Color3.new(0, 0, 0), amount)
end
function DungeonGenerator.SoftenEnemyVisuals(model: Instance)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            if d.Material == Enum.Material.Neon then
                local isWeakSpot = d.Name == "Head" -- (0.76: the head is the only weak spot -- cores no longer glow like one)
                if d:GetAttribute("Glow") then
                    d.Color = Darken(d.Color, 0.12) -- EnemyModels accents: stay lit
                elseif isWeakSpot then
                    d.Color = Darken(d.Color, 0.35)
                else
                    d.Material = Enum.Material.SmoothPlastic
                    d.Color = Darken(d.Color, 0.2)
                end
            end
            d.CastShadow = false
        elseif d:IsA("PointLight") or d:IsA("SurfaceLight") or d:IsA("SpotLight") then
            d.Brightness *= 0.35
            d.Range *= 0.6
            d.Shadows = false
        end
    end
end

-- ==================== [MULTI-CHAMBER ARENA LAYOUT] ====================
-- Every floor is three connected chambers -- Entry, Combat, Boss/Vault -- linked by open
-- corridors along +Z, instead of one static room. Every function that needs to know where
-- a chamber sits calls this so enemy roam bounds, spawn points, the vault and the room shell
-- itself all agree. isBossFloor mirrors BuildThemedDungeon's own ItemData.IsBossConfig check,
-- since that decides whether the Combat chamber is built at boss size. EntryZ never moves
-- (client-side teleport-in code hardcodes it as 550; keep that in sync if this changes).
DungeonGenerator.ROOM_SIZE = 123 -- (0.63, owner: "make ALL rooms smaller by another 25% or so": 150 -> 112, boss arenas 240 -> 180;
-- 0.65, owner: "Increase biome sizes by like another 10%, they feel a little to small now": 112 -> 123, 180 -> 198)
DungeonGenerator.BOSS_ROOM_SIZE = 198
DungeonGenerator.TRAVERSAL_DESIGN = 220 -- (the traversal layouts are drawn for a 220 room and shrunk to fit -- ScaleTraversal)
function DungeonGenerator.GetChamberLayout(isBossFloor: boolean)
    -- (0.62, owner: "biomes feel a little too big now after movement speed changes, running to the portals is annoying.
    -- They should be smaller rooms different from the boss rooms, as it would make the game feel more stressful and
    -- confined"): regular rooms 220 -> 150 (about half the floor); boss arenas keep 240
    local combatSize = isBossFloor and DungeonGenerator.BOSS_ROOM_SIZE or DungeonGenerator.ROOM_SIZE
    local entrySize = 40
    local bossSize = 90
    local corridorLen = 10
    local corridorWidth = 20

    local entryZ = 550
    local corAStart = entryZ + entrySize / 2
    local corAEnd = corAStart + corridorLen
    local combatZ = corAEnd + combatSize / 2
    local corBStart = combatZ + combatSize / 2
    local corBEnd = corBStart
    -- (2026-10-02, owner: the bosses sat in a back room doing nothing -- the room is gone; every boss fights in the
    -- arena, and the reward vault + portal appear there too)
    local bossZ = combatZ
    bossSize = combatSize

    return {
        EntryZ = entryZ, EntrySize = entrySize,
        CombatZ = combatZ, CombatSize = combatSize,
        BossZ = bossZ, BossSize = bossSize,
        CorridorAStart = corAStart, CorridorAEnd = corAEnd,
        CorridorBStart = corBStart, CorridorBEnd = corBEnd,
        CorridorWidth = corridorWidth,
    }
end
safeEndZ = DungeonGenerator.GetChamberLayout(false).CorridorAStart -- (the safe entry room ends here; TargetPlayers)

-- ==================== [AIM-TRAINER BOTS] ====================
-- Each archetype moves like a different aim-trainer scenario, relative to the player it's fighting
-- (movement happens mostly sideways/vertical to your line of sight, which is what you actually aim at):
--   Tracker   smooth, flowing curves           -> smooth control tracking
--   Strafer   fast A-D strafes, sudden flips   -> reactive tracking / fast target switching
--   Drifter   slow long strafes that ease out  -> slow, precise tracking
--   Blinker   holds still, then teleports      -> dynamic clicking (flick + confirm)
--   Hopper    arcing jumps, changing sides     -> air / vertical tracking
--   Charger   stalks, winds up, dives, recovers -> a readable lunge, then a free shot (Update 6)
--   Juggernaut slow tank with a big weak spot  -> sustained tracking, damage check
--   Sniper    relocates, shows a laser, fires  -> threat priority: flick it before the shot lands
-- Frozen / slowed bots run their pattern in slow motion (SlowMult attribute, set by CombatServer).
local BotArchetypes: { [string]: any } = {
    Tracker = { Style = "Tracker", Label = "Tracker", Hp = 90, Dmg = 9, Speed = 16, Body = 2.2, Head = 1.3, Color = Color3.fromRGB(80, 190, 255), Range = { 26, 40 }, Fire = 2.6, Pattern = "Tracking" },
    Strafer = { Style = "Strafer", Label = "Strafer", Hp = 70, Dmg = 8, Speed = 23, Body = 1.9, Head = 1.15, Color = Color3.fromRGB(255, 220, 70), Range = { 20, 32 }, Fire = 2.0, Pattern = "FastStrafe" },
    Drifter = { Style = "Heavy", Label = "Drifter", Hp = 120, Dmg = 11, Speed = 10, Body = 2.5, Head = 1.45, Color = Color3.fromRGB(120, 235, 150), Range = { 28, 44 }, Fire = 3.0, Pattern = "SlowStrafe" },
    Blinker = { Style = "Crystal", Label = "Blinker", Hp = 60, Dmg = 10, Speed = 0, Body = 1.7, Head = 1.05, Color = Color3.fromRGB(205, 120, 255), Range = { 22, 40 }, Fire = 2.8, Pattern = "Blink" },
    Hopper = { Style = "Hopper", Label = "Hopper", Hp = 85, Dmg = 10, Speed = 18, Body = 2.0, Head = 1.2, Color = Color3.fromRGB(255, 150, 80), Range = { 18, 32 }, Fire = 2.6, Pattern = "Bounce" },
    -- Melee = true: no gun -- runs you down and strikes at arm's length after a short wind-up (see the melee attack below)
    Charger = { Style = "Charger", Label = "Charger", Hp = 120, Dmg = 14, Speed = 25, Body = 2.4, Head = 1.4, Color = Color3.fromRGB(255, 95, 95), Range = { 8, 30 }, Fire = 1.6, Pattern = "Charge", Melee = true },
    Juggernaut = { Style = "Heavy", Label = "Juggernaut", Hp = 290, Dmg = 18, Speed = 13, Body = 3.8, Head = 2.2, Color = Color3.fromRGB(255, 140, 40), Range = { 24, 38 }, Fire = 2.2, Pattern = "SlowStrafe", Melee = true },
    Sniper = { Style = "Sniper", Label = "Sniper", Hp = 90, Dmg = 24, Speed = 14, Body = 2.1, Head = 1.35, Color = Color3.fromRGB(255, 70, 70), Range = { 45, 68 }, Fire = 4.4, Pattern = "Peek" },
    -- Ground walkers (upright torso + legs + head, on the floor): strafe-heavy aim-trainer targets.
    -- Strafe profile tweaks the strafe brain: Short / Long = extra weight on short or long strafes, Jump = extra jump chance.
    Runner = { Label = "Runner", Hp = 95, Dmg = 9, Speed = 17, Body = 2.0, Head = 1.25, Color = Color3.fromRGB(90, 225, 255), Range = { 20, 34 }, Fire = 2.7, Pattern = "GroundStrafe", Ground = true },
    Skirmisher = { Label = "Skirmisher", Hp = 75, Dmg = 8, Speed = 21, Body = 1.8, Head = 1.15, Color = Color3.fromRGB(255, 205, 80), Range = { 16, 28 }, Fire = 2.5, Pattern = "GroundStrafe", Ground = true, Profile = { Short = 0.2, Jump = 0.15 } },
    Brute = { Style = "Brute", Label = "Brute", Hp = 260, Dmg = 16, Speed = 15, Body = 2.9, Head = 1.7, Color = Color3.fromRGB(245, 120, 70), Range = { 22, 34 }, Fire = 2.0, Pattern = "GroundStrafe", Ground = true, Melee = true, Profile = { Long = 0.3, Jump = -0.1 } },
    -- Specialists (2026-10-02, "too many swarmy enemies"): fewer bots per floor, each one asks something different.
    Warden = { Label = "Warden", Hp = 170, Dmg = 12, Speed = 9, Body = 2.6, Head = 1.35, Color = Color3.fromRGB(120, 200, 255), Range = { 18, 30 }, Fire = 3.0, Pattern = "GroundStrafe", Ground = true, Shield = true, Profile = { Long = 0.3, Jump = -1 } },
    Medic = { Style = "Medic", Label = "Medic", Hp = 85, Dmg = 6, Speed = 12, Body = 1.9, Head = 1.2, Color = Color3.fromRGB(90, 255, 140), Range = { 34, 48 }, Fire = 3.6, Pattern = "SlowStrafe", Healer = true },
    Splitter = { Style = "Splitter", Label = "Splitter", Hp = 140, Dmg = 10, Speed = 14, Body = 2.4, Head = 1.35, Color = Color3.fromRGB(200, 90, 255), Range = { 24, 38 }, Fire = 2.8, Pattern = "Tracking", Splits = true },
    Splitling = { Style = "Orb", Label = "Splitling", Hp = 40, Dmg = 5, Speed = 24, Body = 1.3, Head = 0.85, Color = Color3.fromRGB(235, 150, 255), Range = { 14, 26 }, Fire = 2.2, Pattern = "FastStrafe" },
    -- KovaaK's-inspired movers (2026-10-02, owner: "more variation -- movements inspired by kovaaks scenarios"):
    Popper = { Style = "Popper", Label = "Popper", Hp = 70, Dmg = 8, Speed = 14, Body = 1.8, Head = 1.1, Color = Color3.fromRGB(255, 230, 120), Range = { 20, 34 }, Fire = 2.6, Pattern = "Popcorn" },
    Pasu = { Style = "Pasu", Label = "Pasu", Hp = 80, Dmg = 9, Speed = 18, Body = 1.9, Head = 1.15, Color = Color3.fromRGB(80, 255, 200), Range = { 22, 36 }, Fire = 2.6, Pattern = "Pasu" },
    Seraph = { Style = "Angel", Label = "Seraph Drone", Hp = 95, Dmg = 9, Speed = 16, Body = 2.0, Head = 1.2, Color = Color3.fromRGB(255, 236, 190), Range = { 26, 40 }, Fire = 2.8, Pattern = "Angelic" },
    Zipper = { Style = "Zipper", Label = "Zipper", Hp = 60, Dmg = 8, Speed = 22, Body = 1.6, Head = 1.0, Color = Color3.fromRGB(255, 90, 200), Range = { 20, 32 }, Fire = 2.4, Pattern = "Zigzag" },
    Orbiter = { Style = "Orbiter", Label = "Orbiter", Hp = 90, Dmg = 9, Speed = 17, Body = 2.0, Head = 1.2, Color = Color3.fromRGB(150, 170, 255), Range = { 20, 30 }, Fire = 2.8, Pattern = "Orbit" },
    Leaper = { Style = "Leaper", Label = "Leaper", Hp = 100, Dmg = 10, Speed = 16, Body = 2.0, Head = 1.25, Color = Color3.fromRGB(170, 255, 90), Range = { 20, 32 }, Fire = 2.8, Pattern = "Leap", Ground = true },
    Gunship = { Style = "Gunship", Label = "Gunship", Hp = 210, Dmg = 6, Speed = 11, Body = 3.0, Head = 1.5, Color = Color3.fromRGB(255, 110, 60), Range = { 34, 50 }, Fire = 4.2, Pattern = "SlowStrafe", Burst = 4 },
    -- STORMSPIRE ONLY (Biome = "Storm": PickArchetype / PickSpecialist only roll them there)
    Stormcaller = { Style = "Stormcaller", Label = "Stormcaller", Hp = 95, Dmg = 10, Speed = 14, Body = 2.3, Head = 1.3, Color = Color3.fromRGB(140, 200, 255), Range = { 26, 40 }, Fire = 3.0, Pattern = "Thunderhead", Biome = "Storm" },
    Gale = { Style = "Gale", Label = "Gale", Hp = 70, Dmg = 8, Speed = 24, Body = 1.8, Head = 1.1, Color = Color3.fromRGB(205, 235, 255), Range = { 20, 34 }, Fire = 2.4, Pattern = "Gust", Biome = "Storm" },
    Arcwalker = { Style = "Arc", Label = "Arcwalker", Hp = 130, Dmg = 11, Speed = 15, Body = 2.2, Head = 1.3, Color = Color3.fromRGB(110, 165, 255), Range = { 18, 30 }, Fire = 2.8, Pattern = "ArcStep", Ground = true, Biome = "Storm" },
    Spark = { Style = "Spark", Label = "Spark", Hp = 50, Dmg = 7, Speed = 26, Body = 1.4, Head = 0.9, Color = Color3.fromRGB(255, 248, 170), Range = { 16, 30 }, Fire = 2.2, Pattern = "Ricochet", Biome = "Storm" },
    Conductor = { Style = "Conductor", Label = "Conductor", Hp = 180, Dmg = 9, Speed = 9, Body = 2.8, Head = 1.4, Color = Color3.fromRGB(230, 160, 90), Range = { 32, 46 }, Fire = 3.8, Pattern = "SlowStrafe", Biome = "Storm" },
    -- BIOME ROSTERS (2026-10-03, MIXED RUNS -- owner: "every room... has specific enemy types for that biome"): every
    -- biome has its own enemies like Stormspire (3 + a specialist each), each with its own movement, attack and look.
    -- MOLTEN
    Cinder = { Style = "Cinder", Label = "Cinder", Hp = 80, Dmg = 9, Speed = 16, Body = 1.9, Head = 1.15, Color = Color3.fromRGB(255, 140, 50), Range = { 22, 36 }, Fire = 2.8, Pattern = "Corkscrew", Biome = "Fire" },
    Magmaw = { Style = "Magmaw", Label = "Magmaw", Hp = 150, Dmg = 12, Speed = 15, Body = 2.4, Head = 1.35, Color = Color3.fromRGB(255, 95, 35), Range = { 18, 30 }, Fire = 3.0, Pattern = "Burrow", Ground = true, Biome = "Fire" },
    Ashwing = { Style = "Ashwing", Label = "Ashwing", Hp = 75, Dmg = 10, Speed = 20, Body = 1.8, Head = 1.1, Color = Color3.fromRGB(215, 95, 50), Range = { 26, 40 }, Fire = 2.8, Pattern = "Flap", Biome = "Fire" },
    Smelter = { Style = "Smelter", Label = "Smelter", Hp = 190, Dmg = 8, Speed = 9, Body = 2.8, Head = 1.4, Color = Color3.fromRGB(255, 175, 70), Range = { 30, 44 }, Fire = 4.0, Pattern = "SlowStrafe", Biome = "Fire" },
    -- CRYO
    Shardling = { Style = "Shard", Label = "Shardling", Hp = 70, Dmg = 8, Speed = 20, Body = 1.7, Head = 1.05, Color = Color3.fromRGB(170, 230, 255), Range = { 22, 36 }, Fire = 2.6, Pattern = "Skate", Biome = "Ice" },
    Frostbite = { Style = "Frostbite", Label = "Frostbite", Hp = 130, Dmg = 11, Speed = 16, Body = 2.2, Head = 1.3, Color = Color3.fromRGB(120, 200, 255), Range = { 18, 30 }, Fire = 2.9, Pattern = "Stutter", Ground = true, Biome = "Ice" },
    Flurry = { Style = "Flurry", Label = "Flurry", Hp = 80, Dmg = 9, Speed = 14, Body = 1.9, Head = 1.15, Color = Color3.fromRGB(230, 246, 255), Range = { 24, 38 }, Fire = 2.8, Pattern = "Leaf", Biome = "Ice" },
    Cryomancer = { Style = "Cryomancer", Label = "Cryomancer", Hp = 170, Dmg = 10, Speed = 9, Body = 2.6, Head = 1.35, Color = Color3.fromRGB(90, 170, 255), Range = { 30, 44 }, Fire = 4.2, Pattern = "SlowStrafe", Biome = "Ice" },
    -- VOID
    Phasewing = { Style = "Phase", Label = "Phasewing", Hp = 85, Dmg = 9, Speed = 18, Body = 1.9, Head = 1.15, Color = Color3.fromRGB(190, 110, 255), Range = { 22, 36 }, Fire = 2.8, Pattern = "Phase", Biome = "Void" },
    Mirrorshade = { Style = "Mirror", Label = "Mirrorshade", Hp = 120, Dmg = 10, Speed = 16, Body = 2.1, Head = 1.3, Color = Color3.fromRGB(215, 165, 255), Range = { 18, 30 }, Fire = 2.8, Pattern = "Mirror", Ground = true, Biome = "Void" },
    Riftling = { Style = "Riftling", Label = "Riftling", Hp = 75, Dmg = 10, Speed = 0, Body = 1.7, Head = 1.05, Color = Color3.fromRGB(150, 75, 255), Range = { 24, 40 }, Fire = 3.0, Pattern = "Constellation", Biome = "Void" },
    Watcher = { Style = "Watcher", Label = "Watcher", Hp = 160, Dmg = 15, Speed = 8, Body = 2.6, Head = 1.6, Color = Color3.fromRGB(255, 90, 200), Range = { 34, 50 }, Fire = 4.6, Pattern = "SlowStrafe", Biome = "Void" },
    -- CYBER
    Raster = { Style = "Raster", Label = "Raster", Hp = 80, Dmg = 9, Speed = 20, Body = 1.8, Head = 1.1, Color = Color3.fromRGB(60, 255, 180), Range = { 22, 36 }, Fire = 2.7, Pattern = "Raster", Biome = "Cyber" },
    Tracer = { Style = "Tracer", Label = "Tracer", Hp = 110, Dmg = 6, Speed = 16, Body = 2.0, Head = 1.2, Color = Color3.fromRGB(80, 220, 255), Range = { 18, 30 }, Fire = 1.6, Pattern = "Afterimage", Ground = true, Biome = "Cyber" },
    Uplink = { Style = "Uplink", Label = "Uplink", Hp = 90, Dmg = 9, Speed = 16, Body = 2.3, Head = 1.4, Color = Color3.fromRGB(130, 255, 120), Range = { 24, 38 }, Fire = 3.8, Pattern = "Pendulum", Biome = "Cyber" },
    Firewall = { Style = "Firewall", Label = "Firewall", Hp = 200, Dmg = 10, Speed = 8, Body = 2.8, Head = 1.4, Color = Color3.fromRGB(255, 120, 70), Range = { 26, 38 }, Fire = 4.6, Pattern = "SlowStrafe", Biome = "Cyber" },
    -- ROSTER v2 (2026-10-04): a fifth type for Molten, Cryo, Void and Cyber (Stormspire already had five)
    Slagroller = { Style = "Slagroller", Label = "Slagroller", Hp = 140, Dmg = 11, Speed = 18, Body = 2.4, Head = 1.2, Color = Color3.fromRGB(255, 120, 40), Range = { 18, 30 }, Fire = 3.0, Pattern = "Roll", Biome = "Fire" },
    Rimewyrm = { Style = "Rimewyrm", Label = "Rimewyrm", Hp = 95, Dmg = 9, Speed = 15, Body = 1.9, Head = 1.15, Color = Color3.fromRGB(150, 220, 255), Range = { 24, 38 }, Fire = 3.0, Pattern = "Serpent", Biome = "Ice" },
    Antipode = { Style = "Antipode", Label = "Antipode", Hp = 90, Dmg = 10, Speed = 14, Body = 2.0, Head = 1.2, Color = Color3.fromRGB(230, 200, 255), Range = { 20, 30 }, Fire = 3.2, Pattern = "Antipode", Biome = "Void" },
    Glitch = { Style = "Glitch", Label = "Glitch", Hp = 75, Dmg = 9, Speed = 16, Body = 1.8, Head = 1.1, Color = Color3.fromRGB(255, 60, 160), Range = { 22, 34 }, Fire = 2.8, Pattern = "Glitch", Biome = "Cyber" },
    -- HARD TIER (2026-10-05, owner: "difficulties 5+ ... make a mixture of those, plus smooth but very fast tracking
    -- bots"): only rolled by the hard-tier mix (PickArchetype on Nightmare+), never on easier floors
    Comet = { Style = "Tracker", Label = "Comet", Hp = 65, Dmg = 8, Speed = 26, Body = 1.65, Head = 1.05, Color = Color3.fromRGB(205, 245, 255), Range = { 24, 38 }, Fire = 2.8, Pattern = "Comet", HardTier = true },
}
-- Bestiary text (Index > Bestiary). Keep in sync when adding an archetype.
DungeonGenerator.BotLore = {
    Tracker = { Role = "Gunner: flying tracker", Text = "Holds its distance and keeps gliding from spot to spot. Stops briefly to fire quick volleys of three glowing tracer rounds in a small fan.", Tip = "Too fast to sidestep: break its line with cover or kill it first. Plating (vs Kinetic) or the matching resistance takes the sting out." },
    Strafer = { Role = "Gunner: fast flyer", Text = "Keeps its distance and darts from spot to spot, stopping briefly to fire a quick three-round burst.", Tip = "Shoot it while it stands and fires. Its volleys chip you while it lives: kill it fast or break its line." },
    Drifter = { Role = "Heavy: slow flyer", Text = "Tanky and slow: it plods toward you and stops to lob a slow shell that marks where it will land.", Tip = "Step off the marked spot, or shoot the shell down in the air. Go for the head to save ammo." },
    Blinker = { Role = "Marksman: teleporter", Text = "Holds still, charges one hard shot (a glint grows on it, then flickers as it locks), fires, then teleports a short way.", Tip = "Hit its head while it charges: that cancels the shot and staggers it. Pre-aim where it lands." },
    Hopper = { Role = "Gunner: bouncer", Text = "Hops from spot to spot in low arcs, then stands to fire three-round bursts.", Tip = "Shoot it when it lands and fires. Its volleys chip you: the sooner it drops, the less you take." },
    Charger = { Role = "Rusher: melee diver", Text = "Hangs back, stops and glows, then dives straight through you and stands winded for a moment. Up close it jabs you fast. No gun.", Tip = "Sidestep the dive when it glows, then shoot it while it recovers. Don't let it stay on you." },
    Juggernaut = { Role = "Heavy: brawler", Text = "Slams a circle around itself; every third attack slams down on your spot instead.", Tip = "Leave the circle before it fills, and step off the mark under you. Its big head is an easy weak spot." },
    Sniper = { Role = "Marksman", Text = "Charges one hard, fast shot from far away: a glint grows on its head, then flickers as it locks.", Tip = "Hit its head during the charge to cancel the shot (it staggers). Too late? Move the moment the glint flickers." },
    Runner = { Role = "Gunner: ground strafer", Text = "Keeps walking from spot to spot and stops briefly to fire three-round bursts.", Tip = "Track it across, then punish the stop: it stands still while it fires." },
    Skirmisher = { Role = "Gunner: quick ground strafer", Text = "Fast and fragile: quick dashes to new spots, a short stop to fire two-round bursts.", Tip = "A priority target: it goes down in a few hits. Catch it on the stop." },
    Brute = { Role = "Rusher: melee walker", Text = "Walks you down; a glow grows on its front as it winds up, then it swings a wide arc in front of it. Up close it also jabs you fast. No gun.", Tip = "Back off or step to its side when it glows, or kill it before it reaches you." },
    Warden = { Role = "Caster: shield bearer", Text = "Holds an energy shield in front (shots into it deal 10%). Wards an ally: a bubble and a tether, half damage for 4 s. With no one to ward it fires single rounds. The ground around it hurts while it fights.", Tip = "Kill it first: its wards drop the moment it dies. Aim over its shield for the head. Resistances help in its ground." },
    Medic = { Role = "Caster: support", Text = "Stays behind its allies and heals them every few seconds (green beams). Lays a slow pool on you, and the ground around it hurts while it fights.", Tip = "Kill it first, or the fight drags on. Step out of its pool." },
    Splitter = { Role = "Gunner: splitter", Text = "Fires three-round bursts and splits into two fast Splitlings when destroyed.", Tip = "Keep some ammo for the pieces." },
    Splitling = { Role = "Gunner: fragment", Text = "Tiny, fast pieces of a Splitter that fire single rounds.", Tip = "One or two shots each. Flick them down." },
    Popper = { Role = "Gunner: popcorn", Text = "Pops from spot to spot in high arcs and stands to fire two-round bursts.", Tip = "Shoot it when it lands and fires." },
    Pasu = { Role = "Gunner: box bouncer", Text = "Glides in straight lines to a new spot every few seconds, then stands to fire three-round bursts.", Tip = "Track the straight line, or wait for the stop." },
    Seraph = { Role = "Gunner: angelic flyer", Text = "Glides smoothly between spots at mid range and stands to fire three-round bursts.", Tip = "Smooth tracking on the glide, a free shot on the stop." },
    Zipper = { Role = "Gunner: zig-zagger", Text = "Fast and fragile: it zips to a new spot every second or two and stops to fire two-round bursts.", Tip = "A priority target: a few hits drop it. Aim where it stops." },
    Orbiter = { Role = "Gunner: orbiter", Text = "Works its way round you, one smooth step at a time, and stands to fire three-round bursts.", Tip = "Track it across; it slows into each spot." },
    Leaper = { Role = "Gunner: leaper", Text = "A walker that leaps from spot to spot in long arcs, then stands to fire three-round bursts.", Tip = "Track the leap's arc. It can't change direction mid-air." },
    Gunship = { Role = "Heavy: suppressor", Text = "Slow and armoured; lobs two shells, one at you and one where you're heading, each landing spot marked.", Tip = "Shoot the shells down or keep moving between the marks; it's an easy target between volleys." },
    Stormcaller = { Role = "Stormspire flyer", Text = "Drifts high, then STRIKE-DIVES straight down and climbs back. Its chain lightning hops three times along your path.", Tip = "Flick down with the dive. Change direction to break the chain." },
    Gale = { Role = "Stormspire glider", Text = "Glides in long, smooth sweeps that ease in and out, hovers, then sweeps again at a new height. Its crosswind cuts ACROSS your line to it.", Tip = "Track the glide, shoot the hover. Step forward or back out of the crosswind, not sideways." },
    Arcwalker = { Role = "Stormspire walker", Text = "Strafes on the floor and arc-steps, vanishes into a lightning streak and reappears 9-15 studs aside. Its thunderclap strikes where you are, then strikes you again a moment later.", Tip = "Follow the streak. Keep moving after the first strike." },
    Spark = { Role = "Stormspire spark", Text = "A loose spark pinging around a wide box in straight lines at high speed.", Tip = "Small and fast: lead it along its line, catch it at a bounce." },
    Conductor = { Role = "Stormspire suppressor", Text = "A copper lightning totem. Calls three wide strikes around you, then one on you.", Tip = "Hold still for the ring, then move. Kill it early. It locks you down." },
    Cinder = { Role = "Gunner: molten flyer", Text = "A burning coal that drifts from spot to spot and stands to fire three-round bursts.", Tip = "Catch it when it stops to fire. Its volleys chip you: kill it fast." },
    Magmaw = { Role = "Heavy: molten burrower", Text = "Strafes on the floor, then DIVES into it and bursts out where a glowing crack leads. Lobs a magma shell that leaves a burning pool where it lands.", Tip = "Pre-aim the crack. Shoot the shell down, or stay off its pool." },
    Ashwing = { Role = "Marksman: molten glider", Text = "An ash bat that hangs far back and glides to a new perch after it fires. Charges a fire bolt (a glint grows on its head) and fires it.", Tip = "Hit its head while it charges to cancel the bolt. It moves after the shot." },
    Smelter = { Role = "Caster: molten crucible", Text = "A floating crucible that hangs back behind its allies. Tempers an ally (half damage, an orange bubble and a tether); with no one to temper it pours a molten pool on you. The ground around it hurts while it fights.", Tip = "Kill it first: the temper drops when it dies. Leave the pool fast. Resistances help on harder tiers." },
    Shardling = { Role = "Cryo skater", Text = "Skates on the air like ice. It pushes toward a new spot but can't stop, overshooting and curving back. Its shatter splits into four shards that fly out.", Tip = "Aim where it's sliding, not where it's pushing. Dodge the burst, then the shards." },
    Frostbite = { Role = "Cryo walker", Text = "Strafes, then FREEZES dead still in a shell of frost, then bursts off at double speed. Its frozen lane stays icy for a moment.", Tip = "Free shots while it's frozen. Be ready for the burst." },
    Flurry = { Role = "Cryo drifter", Text = "Drifts down like a falling snowflake, swaying side to side, then whirls back up to the top. Its sleet falls in two lanes either side of you.", Tip = "Smooth sway tracking. Against sleet, don't strafe. Stay in the gap." },
    Cryomancer = { Role = "Cryo suppressor", Text = "An ice totem. Its frost lock hunts you across the floor, locks, then shatters.", Tip = "Keep moving while it hunts; change direction the moment it locks." },
    Phasewing = { Role = "Void flyer", Text = "Flickers, then PHASES OUT: see-through and untouchable, while it slides somewhere new. Its rift strikes twice in the same place.", Tip = "Shots pass through it while it's phased: wait for it to arrive. Don't step back into the rift." },
    Mirrorshade = { Role = "Void walker", Text = "Your reflection: it strafes the OPPOSITE way to you, crossing your screen twice as fast. Strikes where you are and where your reflection would be.", Tip = "Strafe less to track it. Against the twin strike, stand still between the circles." },
    Riftling = { Role = "Void star", Text = "Hops between the same four points, always in the same order, with a pause on each.", Tip = "Learn its shape and pre-aim the next point. Its lance comes along, then across, side-step, then step back." },
    Watcher = { Role = "Void marksman", Text = "A great eye. Its gaze tracks you, LOCKS (flickers), then fires a beam.", Tip = "Move the moment it locks, or break line of sight." },
    Raster = { Role = "Cyber flyer", Text = "Moves only in straight lines along a grid, across, then up or down, turning in hard right angles. Its gridlock strikes a plus through you.", Tip = "No curves: snap with the corners. Escape gridlock diagonally." },
    Tracer = { Role = "Cyber walker", Text = "Drifts, then DASHES 10-14 studs in a blink, leaving a fading hologram where it stood. Pings you with small, fast strikes.", Tip = "Ignore the hologram: follow the dash. Keep moving against the pings." },
    Uplink = { Role = "Cyber swinger", Text = "Hangs off a data tether and swings, fastest at the bottom, hanging still at each end. Fires three lanes at once.", Tip = "Shoot it at the ends of the swing. Stand between the lanes." },
    Firewall = { Role = "Cyber suppressor", Text = "A shield projector. Sweeps a floor laser around itself.", Tip = "Jump the laser or outrun its turn. Kill it early." },
    Slagroller = { Role = "Rusher: molten roller", Text = "A ball of cooling slag that rolls in close, halts and glows, then ROLLS straight through you. Up close it jabs you.", Tip = "When it halts and glows, sidestep. Shoot it while it cools." },
    Rimewyrm = { Role = "Cryo serpent", Text = "A frost serpent that weaves up and down in a tight wave while it slides across the room.", Tip = "Track the slide, ignore the weave. Aim at the middle of the wave. Icefall: stand still for the ring, then slip out through a gap." },
    Antipode = { Role = "Void orbiter", Text = "Sweeps an arc around you, then FLIPS to the mirrored point of that arc, across your view.", Tip = "When it flickers, look to the other side of where it was. Collapse rings close in: wait for the outer ring, then step out through it." },
    Comet = { Role = "Gunner: hard-tier tracker", Text = "Small, very fast and fragile: it sweeps to a new spot in a long, smooth curve, then stops to fire two-round bursts. Only on Nightmare and above.", Tip = "A priority target: stay on it through the curve, and it drops in a few hits." },
    Glitch = { Role = "Cyber glitch", Text = "A corrupted cube that jitters: it drifts, but snaps a few studs at a time several times a second.", Tip = "Don't chase every snap. Hold your aim on the middle of its drift. Bitstream zig-zags: read the last segment." },
}
DungeonGenerator.BossLore = {
    { Id = "GoliathMiniBoss", Name = "Goliath", Role = "Miniboss (early floors)", Tip = "A tracked juggernaut that CHARGES down a lane and quakes the floor: step out of the lane. TARGETS: now and then it guards (half damage) and lime targets appear round it; break them all in time to STAGGER it (+75% damage)." },
    { Id = "PhantomMiniBoss", Name = "Phantom", Role = "Miniboss (later floors)", Tip = "Never stands still: it strafes and dodges, and marks the floor where you stand. TARGETS: now and then it guards (half damage) and lime targets appear round it; break them all in time to STAGGER it (+75% damage)." },
    { Id = "RavagerMiniBoss", Name = "Ravager", Role = "Miniboss", Tip = "A beast that POUNCES where you stand: keep moving, its rakes cover the ground in front of it. TARGETS: now and then it guards (half damage) and lime targets appear round it; break them all in time to STAGGER it (+75% damage)." },
    { Id = "HexcallerMiniBoss", Name = "Hexcaller", Role = "Miniboss", Tip = "Its hexes are slow circles and sigils on the floor: keep moving and keep shooting. TARGETS: now and then it guards (half damage) and lime targets appear round it; break them all in time to STAGGER it (+75% damage)." },
    { Id = "SentinelMiniBoss", Name = "Sentinel", Role = "Miniboss (Endless)", Tip = "A crystal fortress that pulses strikes onto your spot: keep moving. TARGETS: now and then it guards (half damage) and lime targets appear round it; break them all in time to STAGGER it (+75% damage)." },
    { Id = "ApexTitanMech", Name = "Apex Titan", Role = "Boss (mid-run; the finale on Easy / Normal)", Tip = "A four-legged siege walker: artillery rains where you stand and its escorts join the fight. TARGETS: now and then it guards (half damage) and lime targets appear round it; break them all in time to STAGGER it (+75% damage)." },
    { Id = "BiomeSuperBoss", Name = "Biome Superboss", Role = "Superboss (the last floor, Hard and up)", Tip = "Each of the original seven biomes has its own superboss with its own attacks (the newer worlds summon a related one), the hardest fight of a run. TARGETS: now and then it guards (half damage) and lime targets appear round it; break them all in time to STAGGER it (+75% damage)." },
    { Id = "TrialLamplighter", Name = "The Lamplighter", Role = "Map guardian (Annihilation maps, tier 10-12)", Tip = "Human-sized and never still: he circles you, side-steps and glides to a new spot. His shots and lanes come one at a time after a clear wind-up. TARGETS are his lamps: hanging lamps that sway, one lantern swinging on its chain, lamps that flare up one by one round you. Break them all in time to STAGGER him (+75% damage). His head is the weak point." },
    { Id = "LootGoblin", Name = "Loot Goblin", Role = "Treasure (rare)", Tip = "Rare: about 1 floor in 100. Runs from you. Catch it: everything it drops is Rare or better." },
}
DungeonGenerator.BotArchetypes = BotArchetypes
local LEGACY_BOT = { Scout = "Tracker", Heavy = "Juggernaut", Sniper = "Sniper", Rusher = "Charger" }

-- Which archetypes can appear, by floor (the roster widens as a run goes deeper).
-- About half the bots are ground walkers.
-- DevCmd ["roster", "Pasu,Orbiter"]: every bot (and specialist) rolled from now on is one of these (Studio tests)
DungeonGenerator.ForceArchetypes = nil :: { string }?
-- BIOME ROSTERS: well over half of a floor's bots are its biome's own types (never seen anywhere else) -- with every
-- floor a different biome (MIXED RUNS), each floor fights differently
local BIOME_POOLS = {
    Storm = { "Stormcaller", "Gale", "Arcwalker", "Arcwalker", "Spark" },
    Fire = { "Cinder", "Magmaw", "Magmaw", "Ashwing", "Slagroller" },
    Ice = { "Shardling", "Frostbite", "Frostbite", "Flurry", "Rimewyrm" },
    Void = { "Phasewing", "Mirrorshade", "Mirrorshade", "Riftling", "Antipode" },
    Cyber = { "Raster", "Tracer", "Tracer", "Uplink", "Glitch" },
}
local BIOME_SPECIALIST = { Storm = "Conductor", Fire = "Smelter", Ice = "Cryomancer", Void = "Watcher", Cyber = "Firewall" }
DungeonGenerator.BIOME_POOLS, DungeonGenerator.BIOME_SPECIALIST = BIOME_POOLS, BIOME_SPECIALIST
-- HARD TIER MIX (2026-10-05, owner: "Difficulties 5+ are inconsistent, only the small flying ones are hard to hit,
-- everything else is slow and rather easy, the only hard ones are the fast reactive ones"): on Nightmare+ (rank 5+) a
-- growing share of bots roll from HARD_MOVERS (small fast fliers, twitchy reactive strafers, the smooth Comet), and a
-- slow type that still comes up is re-rolled half the time. CreateBot adds the speed floor / size (HARD_TIER).
-- (0.62 BOT REVAMP: the hard tiers lean on SMOOTH movers -- fast trackers, curves, long strafes -- not twitch)
local HARD_MOVERS = { "Comet", "Seraph", "Seraph", "Tracker", "Strafer", "Runner", "Pasu" } -- (0.67: Orbiter out, one Comet: owner "circling bots are still INCREDIBLY overpowered", "comets need a bit of a nerf")
local HARD_BIOME = { Storm = { "Gale", "Gale" }, Fire = { "Ashwing", "Cinder" }, Ice = { "Shardling", "Rimewyrm" }, Void = { "Antipode", "Phasewing" }, Cyber = { "Raster", "Tracer" } }
local SLOW_TYPES = { Drifter = true, Juggernaut = true, Gunship = true, Medic = true, Warden = true, Smelter = true, Cryomancer = true, Watcher = true, Firewall = true, Conductor = true }
DungeonGenerator.SLOW_TYPES = SLOW_TYPES
-- HARD PACE (0.65, owner: "the only really hard bots are the small flying ones (and the one that circles you, its kind
-- of broken.) The erratic fliers are fine, they just need to be slightly slower. Other bots, the smooth ones
-- especially, need to be a little faster"): on Nightmare+ each bot's PATTERN runs at this pace (its sweeps, curves and
-- strafes play out faster or slower; timing of attacks is unchanged). Comet + Orbit keep 1 (Orbit was fixed instead).
DungeonGenerator.HARD_PACE = {
    Erratic = { FastStrafe = true, Zigzag = true, Popcorn = true, Pasu = true, Ricochet = true, Gust = true, Raster = true, Glitch = true },
    Smooth = { Tracking = true, Angelic = true, SlowStrafe = true, Leaf = true, Serpent = true, Pendulum = true, Corkscrew = true, Flap = true, Skate = true },
    Keep = { Comet = true, Orbit = true, Blink = true, Constellation = true, Antipode = true },
}
-- TINY FLIERS (owner after 0.92: "Some of the tiny fliers are still a bit overtuned on high difficulties"; measured on
-- floor 1, skill 4: Hummingbird / Spark 21-25 studs/s on Torment -> 29-31 on Singularity, and ~13% smaller): small
-- airborne bots (Body <= TINY_BODY, not Ground) gain speed above Cataclysm at half the rate (Singularity +39%, was +60%)
-- and stop shrinking at Cataclysm (-12%, was -20%) -- their size already makes them the hardest targets.
DungeonGenerator.TINY_BODY = 1.7
function DungeonGenerator.IsTinyFlier(A: any): boolean
    return (A.Speed or 0) > 0 and not A.Ground and (A.Body or 2) <= DungeonGenerator.TINY_BODY
end
function DungeonGenerator.HardSpeed(A: any, tier: number): number
    if DungeonGenerator.IsTinyFlier(A) then
        local cap = DungeonGenerator.PATTERN_TIER_CAP
        return 1 + 0.06 * math.min(tier, cap) + 0.03 * math.max(0, tier - cap)
    end
    return 1 + 0.06 * tier
end
-- FAST FLIERS (owner: "Its really on all maps, scan the fliers on all biomes and find which ones move substantially faster
-- than others. Lower the speed by about 10%"): measured every airborne type (tools/bot_motion.luau, Endless Singularity
-- floor 41, skill 4, 12 bots a floor): most fliers 19-24 studs/s; these ran 25-35 (Ashwing 34.8, Spark 32.5, Vinelash
-- 30.2, Idolfly 29.4, Cinder 27.1, Strafer 26.5, Glow Eel 26.1, Hopper 25.8, Xeno Larva 25.5, Pollen Moth 25.4, Koi
-- Spirit 25.3, Repair Bot / Voodoo Doll 25.1). Their pattern clock runs x FAST_FLIER_PACE (every move of the pattern).
DungeonGenerator.FAST_FLIER_PACE = 0.9
-- CHARGER (Update 6, owner: "Chargers are still incredibly broken and dont work as intended ... It still circles you
-- incredibly fast and isn't remotely fun to shoot"): it ran the generic melee chase -- stop at arm's length, weave +-9
-- studs at 0.8 x its speed -- i.e. it orbited you at point blank. Now a STALKER with a clear rhythm: hold CHARGE_STAND
-- studs out on its own bearing (turning round you at most CHARGE_TURN rad/s toward its post, moving at most CHARGE_MOVE x
-- its speed), WIND UP standing still (the strip on the floor + a glow, CHARGE_WINDUP x the bot wind-up), DIVE straight
-- along the strip (CHARGE_DIVE s), then RECOVER: it hangs where the dive ended for CHARGE_RECOVER s (a big, still target)
-- and backs straight out (no orbit) before the next wind-up.
DungeonGenerator.CHARGE_STAND = 18
DungeonGenerator.CHARGE_TURN = 0.3
DungeonGenerator.CHARGE_MOVE = 0.6
DungeonGenerator.CHARGE_WINDUP = 0.8
DungeonGenerator.CHARGE_DIVE = 0.3
DungeonGenerator.CHARGE_RECOVER = 1.4
DungeonGenerator.FAST_FLIERS = { Ashwing = true, Spark = true, Vinelash = true, Idolfly = true, Cinder = true, Strafer = true,
    GlowEel = true, Hopper = true, XenoLarva = true, PollenMoth = true, KoiSpirit = true, RepairBot = true, VoodooDoll = true }
function DungeonGenerator.HardShrink(A: any, tier: number): number
    return 1 - 0.04 * math.min(tier, DungeonGenerator.IsTinyFlier(A) and DungeonGenerator.PATTERN_TIER_CAP or 5)
end
function DungeonGenerator.HardPace(pattern: string?, tier: number): number
    if tier <= 0 or not pattern then return 1 end
    local P = DungeonGenerator.HARD_PACE
    if P.Keep[pattern] then return 1 end
    if P.Erratic[pattern] then return 0.88 end
    if P.Smooth[pattern] then return math.min(1.25, 1.08 + 0.02 * tier) end -- Nightmare +10% .. +25% at the top
    return math.min(1.12, 1.04 + 0.01 * tier)
end
function DungeonGenerator.HardTier(diff: string?): number -- 0 below Nightmare, 1..4 Nightmare..Oblivion
    local r = (diff and ItemData.DifficultyRank[diff]) or 1
    return math.max(0, r - 4) -- (1..10 since the six new tiers: the share / size / speed below are capped)
end
-- PATTERN CAP (0.73, owner: "The enemies on difficulty 6 and 7 move exactly how I want the bots to move. Make the higher
-- difficulties like those patterns, just the literal speed of the bots should be faster"): the movement MIX (share of
-- hard movers) and the pattern PACE (how quickly sweeps / curves / strafes cycle) stop at Cataclysm (hard tier 3). Above
-- it only the movement speed keeps climbing: +6% a tier, no cap (Cataclysm +18% .. Singularity +60%).
DungeonGenerator.PATTERN_TIER_CAP = 3
-- PATTERN TEMPO (0.89, measured): most patterns keep a bot in a +-18 stud lane and turn it on timers, so the extra move
-- speed alone barely showed (Trackers averaged 11.6 studs/s on Hard AND Singularity; Runners +25%). Above Cataclysm the
-- same patterns now also run on a faster clock: +5% a tier (Ruin +5% .. Singularity +35%). 0 = the 0.73 behaviour.
DungeonGenerator.PATTERN_TEMPO = 0.05
function DungeonGenerator.PatternTier(diff: string?): number
    return math.min(DungeonGenerator.HardTier(diff), DungeonGenerator.PATTERN_TIER_CAP)
end
local PickArchetypeBase
local function PickArchetype(floor: number, biome: string?, diff: string?): string
    local f = DungeonGenerator.ForceArchetypes
    if f and #f > 0 then return f[math.random(1, #f)] end
    local tier = DungeonGenerator.PatternTier(diff) -- (0.73: the Torment / Cataclysm mix on every tier above them)
    if tier > 0 then
        if math.random() < math.min(0.6, 0.18 + 0.07 * tier) then -- Nightmare 25% .. Oblivion 46% .. 60% max
            local hb = biome and HARD_BIOME[biome]
            if hb and math.random() < 0.4 then return hb[math.random(1, #hb)] end
            return HARD_MOVERS[math.random(1, #HARD_MOVERS)]
        end
        local a = PickArchetypeBase(floor, biome)
        if SLOW_TYPES[a] and math.random() < 0.5 then a = PickArchetypeBase(floor, biome) end
        return a
    end
    return PickArchetypeBase(floor, biome)
end
PickArchetypeBase = function(floor: number, biome: string?): string
    local bp = biome and BIOME_POOLS[biome]
    if bp and math.random() < 0.62 then return bp[math.random(1, #bp)] end
    -- (0.62 BOT REVAMP: smooth trackers -- Tracker / Orbiter / Seraph / Drifter -- and long strafers make up most of the
    -- pool; the twitchy ones -- Skirmisher, Zipper, Popper, Blinker -- are rarer)
    local pool = { "Tracker", "Tracker", "Strafer", "Drifter", "Charger", "Runner", "Runner", "Runner", "Pasu", "Orbiter", "Orbiter" }
    if floor >= 2 then
        for _, a in ipairs({ "Blinker", "Hopper", "Strafer", "Runner", "Brute", "Seraph", "Tracker", "Leaper", "Skirmisher" }) do table.insert(pool, a) end
    end
    if floor >= 3 then
        for _, a in ipairs({ "Sniper", "Juggernaut", "Brute", "Runner", "Seraph", "Orbiter", "Leaper", "Zipper", "Popper" }) do table.insert(pool, a) end
    end
    return pool[math.random(1, #pool)]
end
-- Specialists (each floor gets a few, see RollFloorRoster).
local SPECIALISTS = { "Warden", "Medic", "Splitter", "Gunship", "Sniper", "Juggernaut" }
DungeonGenerator.PickSpecialist = function(floor: number, biome: string?, diff: string?): string
    local f = DungeonGenerator.ForceArchetypes
    if f and #f > 0 then return f[math.random(1, #f)] end
    if biome and BIOME_SPECIALIST[biome] and math.random() < 0.55 then return BIOME_SPECIALIST[biome] end
    local pool = (floor < 4) and { "Warden", "Splitter", "Gunship" } or SPECIALISTS
    return pool[math.random(1, #pool)]
end
DungeonGenerator.IsGroundArchetype = function(a: string?): boolean
    local def = a and BotArchetypes[a]
    return def ~= nil and def.Ground == true
end
DungeonGenerator.PickArchetype = PickArchetype

-- ----- Strafe brain (ground walkers + air strafers) -----
-- Driven ONLY by the bot-skill slider (never by the dungeon difficulty). Chaos 0 (skill 1-3) = steady,
-- learnable rhythm: equal-length A-D strafes and a jump every third strafe. Rising chaos mixes short, medium
-- and long strafes, double-taps (same direction again), stop-and-go pauses, speed changes, snappier
-- reversals and random jumps -- aim-trainer style unpredictability at Voltaic.
function DungeonGenerator.StrafeChaos(config: any?): number
    local lvl = math.clamp(math.floor((config and config.BotSkill) or DungeonGenerator.DEFAULT_BOT_SKILL), 1, 10)
    return math.clamp((lvl - 3) / 7, 0, 1)
end

-- profile: { Short, Long, Jump } extra weights; durMul stretches every strafe (slow strafers).
local function NewStrafeBrain(rng: Random, chaos: number, speed: number, range: number, profile: any?, durMul: number?)
    local pr = profile or {}
    local b = { Lat = 0, Vel = 0, Dir = (rng:NextNumber() < 0.5) and -1 or 1, T = 0, Dur = 0.85, SpeedMul = 1, Pause = 0, Seg = 0, JumpAt = nil :: number? }
    local function NextSegment()
        b.Seg += 1
        b.T = 0
        if chaos < 0.05 then
            -- steady rhythm: always reverse, same length, jump every third strafe
            b.Dir = -b.Dir
            b.Dur = 0.85 * (1 + (rng:NextNumber() - 0.5) * 0.08)
            b.SpeedMul = 1
            b.Pause = 0
            b.JumpAt = nil -- (0.67, owner: "strafing bots should not jump")
        else
            if rng:NextNumber() > 0.15 * chaos then b.Dir = -b.Dir end -- else a double-tap the same way
            local r = rng:NextNumber()
            -- (0.62 BOT REVAMP, owner: "Right now theyre still incredibly reactive ... There needs to be majority smooth
            -- tracking and target switching, long & close strafes etc."): LONG strafes are the core now (40%+, 1.3-2.2 s
            -- across a wider lane), medium ones fill in, a short one is rare and still 0.5 s+. Higher skill adds speed
            -- variety and the odd burst -- NOT more direction flips.
            local pShort = math.clamp(0.08 + 0.07 * chaos + (pr.Short or 0), 0, 0.9)
            local pLong = math.clamp(0.4 + (pr.Long or 0), 0, 0.9)
            if r < pShort then b.Dur = rng:NextNumber(0.5, 0.8); b.Lane = 0.55 -- (a close, tight strafe)
            elseif r < pShort + pLong then b.Dur = rng:NextNumber(1.3, 2.2); b.Lane = 1.35
            else b.Dur = rng:NextNumber(0.8, 1.3); b.Lane = 1 end
            b.SpeedMul = 1 + (rng:NextNumber() * 2 - 1) * 0.25 * chaos
            if rng:NextNumber() < 0.1 * chaos then b.SpeedMul *= 1.2 end -- burst
            b.Pause = (rng:NextNumber() < 0.1 * chaos) and rng:NextNumber(0.1, 0.3) or 0
            b.JumpAt = nil -- (0.67, owner: "strafing bots should not jump": strafes stay on one height)
        end
        b.Dur *= (durMul or 1)
        if math.abs(b.Lat) > range * 0.8 then b.Dir = -math.sign(b.Lat) end
    end
    NextSegment()
    -- returns lateral offset and whether a jump starts this frame
    function b.Step(dt: number): (number, boolean)
        b.T += dt
        local target = 0
        if b.Pause > 0 then
            b.Pause -= dt
        else
            target = b.Dir * speed * b.SpeedMul
        end
        -- acceleration is LIMITED (studs/s^2), so even Voltaic reversals are a quick, continuous swing
        -- instead of a one-frame snap: full reversal ~0.45s at chaos 0, ~0.22s at chaos 1 (0.62: was 0.17s)
        local maxAccel = speed * (4.5 + 4.5 * chaos)
        local dv = math.clamp(target - b.Vel, -maxAccel * dt, maxAccel * dt)
        b.Vel += dv
        -- brake early before the edge of the strafe lane so it never slams into it
        local stopDist = b.Vel * b.Vel / (2 * maxAccel)
        local lane = range * (b.Lane or 1)
        if b.Vel ~= 0 and math.sign(b.Vel) == b.Dir and math.abs(b.Lat) + stopDist >= lane and math.sign(b.Lat) == b.Dir then
            NextSegment()
            b.Dir = -math.sign(b.Lat)
        end
        b.Lat += b.Vel * dt
        local jump = false
        if b.JumpAt and b.T >= b.JumpAt then
            b.JumpAt = nil
            jump = true
        end
        if math.abs(b.Lat) > range * 1.5 then
            b.Lat = math.clamp(b.Lat, -range * 1.5, range * 1.5)
            b.Vel = 0
        end
        if b.T >= b.Dur then
            NextSegment()
        end
        return b.Lat, jump
    end
    return b
end

-- ----- Elements -----
-- Harder difficulties give more bots an element; the biome decides which (with some variety).
local ElementChanceByDiff = setmetatable({ Easy = 0, Normal = 0.10, Hard = 0.30, Brutal = 0.55, Nightmare = 0.80, Torment = 1.0, Cataclysm = 1.0, Oblivion = 1.0, Endless = 1.0 }, { __index = function() return 1.0 end })
-- (Storm = "Shock": lightning-charged enemies that inflict Decay -- you take more damage -- resisted with Chaos)
local BiomeElement = { Fire = "Fire", Ice = "Cold", Void = "Chaos", Cyber = "Bleed", Storm = "Shock" }
local ElementDefs = {
    Fire = { Element = "Fire", Ailment = "Burn", Word = "Burning", Color = Color3.fromRGB(255, 120, 40) },
    Cold = { Element = "Cold", Ailment = "Chill", Word = "Frozen", Color = Color3.fromRGB(120, 210, 255) },
    Chaos = { Element = "Chaos", Ailment = "Decay", Word = "Withering", Color = Color3.fromRGB(150, 220, 70) },
    Bleed = { Element = "Physical", Ailment = "Bleed", Word = "Lacerating", Color = Color3.fromRGB(220, 40, 60) },
    Shock = { Element = "Chaos", Ailment = "Decay", Word = "Storm-charged", Color = Color3.fromRGB(150, 210, 255) },
}
DungeonGenerator.ElementDefs = ElementDefs
local function RollElement(config: DungeonConfig, force: boolean?): string?
    if not force and not HasMod(config, "ELEMENTAL") and math.random() >= (ElementChanceByDiff[config.Difficulty] or 0) then return nil end -- (0.62 map mod ELEMENTAL: all)
    if math.random() < 0.75 then return BiomeElement[config.Biome] or "Fire" end
    local all = { "Fire", "Cold", "Chaos", "Bleed" }
    return all[math.random(1, #all)]
end

-- ===== (UPDATE 8 DEFENCE) every enemy hit carries a DAMAGE TYPE (DamageTypes: Kinetic / Heat / Cryo / Volt / Void) =====
-- An element key (ElementDefs: the bot's element, or a boss's biome element on Hard+) -> its type: Fire / Scorch = Heat,
-- Cold / Lucid = Cryo, Chaos = Void, Bleed = Kinetic (+ Bleed), Shock (Storm) = Volt (+ Shock; it was Chaos / Decay).
-- A type name works as a key too. No key = Kinetic. EVADABLE (Agility can dodge it): a plain enemy's strike
-- (EnemyAttacks.Strike: Circle / Line / Cone / Beam) from a non-boss, and (AGILITY vs BOSSES, 2026-10-24) a BOSS's strike only
-- when its move is on BossAI's allow-list (M.PLAIN -> EnemyAttacks.StrikePlain: plain swings / thrusts / claws / its own shot);
-- every other boss hit (area, big telegraphed moves, mechanics, aim rounds), rings / sweeps / zones / arena wipes / marks,
-- hazards and damage over time never miss.
DungeonGenerator.HIT_TYPE_OF_KEY = { Shock = "Volt" }
DungeonGenerator.HIT_AILMENT_OF_KEY = { Shock = "Shock" }
function DungeonGenerator.TypeOfKey(key: string?): string
    DungeonGenerator._DT = DungeonGenerator._DT or require(script.Parent:WaitForChild("DamageTypes"))
    if not key then return "Kinetic" end
    local t = DungeonGenerator.HIT_TYPE_OF_KEY[key]
    if t then return t end
    local def = ElementDefs[key]
    return DungeonGenerator._DT.Normalize(def and def.Element or key) or "Kinetic"
end
-- a valid hit key from a client report (an ElementDefs key or a type name)
function DungeonGenerator.IsHitKey(key: any): boolean
    DungeonGenerator._DT = DungeonGenerator._DT or require(script.Parent:WaitForChild("DamageTypes"))
    return type(key) == "string" and (ElementDefs[key] ~= nil or DungeonGenerator._DT.INDEX[key] ~= nil)
end
-- the type a biome's hazards hit with (its element; Kinetic when it has none)
function DungeonGenerator.BiomeHitType(biome: string?): string
    local key = biome and BiomeElement[biome]
    return key and DungeonGenerator.TypeOfKey(key) or "Kinetic"
end
-- (ENEMY ATTACKS PILOT 2026-10-30) the colour of a bot's rounds = the damage type its hits carry (HitPlayer's own key rule)
-- (review F: a bot's ctx.Hit passes no config, so HitPlayer's biome fallback never applies to bot hits -- the colour reads the same
-- elementKey the hit carries, never the biome)
function DungeonGenerator.ShotColor(elementKey: string?, config: any?): Color3
    DungeonGenerator._DT = DungeonGenerator._DT or require(script.Parent:WaitForChild("DamageTypes"))
    local key = elementKey
    local c = DungeonGenerator._DT.COLOR
    return c[DungeonGenerator.TypeOfKey(key)] or c.Kinetic
end
DungeonGenerator.BotRoles = BotRoles
DungeonGenerator.BOT_ROLES = BotRoles.ROWS -- (the role table: AimRngShared/BotRoles, append a row to convert a bot)
-- (BOT MOVEMENT POE 2026-10-30) role bots MOVE by their role too (AimRngShared/BotMove: brains, speed by archetype, the readability
-- cap on every bot, the tier speed stopped at Torment); a field, not a local (this chunk is near the local limit)
DungeonGenerator.BotMove = require(script.Parent:WaitForChild("BotMove"))
DungeonGenerator.BotMove.DG = DungeonGenerator
-- an ORDINARY hit on this floor: a plain bot's (Tracker, Dmg 9) swing, as CreateBot builds it. Plating judges each hit's
-- size against this (StatCalculator.PlatingReduction); fodder chip is smaller, boss slams bigger.
function DungeonGenerator.OrdinaryHit(config: any): number
    local diff = DifficultyScaling[config.Difficulty] or DifficultyScaling.Easy
    return 9 * DungeonGenerator.GetScalingMultiplier(config, 0.10) * diff.Damage * ItemData.EnemyDmgIndex(DungeonGenerator.CombatLevel(config)) * 0.1 * DungeonGenerator.BOT_PACE.Hit
end

-- (QOL2 R1 DEATH RECAP) the name a hit on you is credited to: a boss = its name (phase dropped) + the move it is doing
-- ("IGNIS, THE FORGE TYRANT: METEORS", from BossTitle), a bot = its archetype label (+ "Magic" / "Rare" for elites), else the
-- kind / model name. A plain string (the per-hit tag: a few attribute reads, no tables).
function DungeonGenerator.SourceName(m: Instance?): string?
    if not m then return nil end
    local t = m:GetAttribute("BossTitle")
    if type(t) == "string" and t ~= "" then
        local name, move = string.match(t, "^(.-)%s+>>%s+(.+)$")
        name = name or t
        name = string.gsub(name, "%s*%[.*$", "")
        name = string.match(name, "^(.-):") or name
        if move then move = string.gsub(string.gsub(move, "%s*%(%d+s%)%s*$", ""), "%s*%[.*$", "") end
        local out = (move and move ~= "") and (name .. ": " .. move) or name
        return string.sub(out, 1, 40)
    end
    local a = m:GetAttribute("DroneType") or m:GetAttribute("Archetype")
    local def = type(a) == "string" and BotArchetypes[LEGACY_BOT[a] or a] or nil
    local label = def and def.Label
    if not label then
        if m:GetAttribute("IsLootGoblin") then label = "Loot Goblin"
        else
            local k = m:GetAttribute("Kind")
            label = (type(k) == "string" and k ~= "Bot") and k or m.Name
        end
    end
    local tier = m:GetAttribute("EliteTier")
    if type(tier) == "string" and def then label = tier .. " " .. label end
    return string.sub(label, 1, 40)
end

-- (POE DAMAGE MODEL probe, Studio only) every landed enemy hit, on the SERVER (solo: DungeonRuns' EnemyHitPlayer, which gets the
-- client's tag as a Studio-only 9th arg; party: HitPlayer), appended to workspace attr DevHitLogSrv as
-- "<tag><type><raw>,<plating size>,<evadable>,<seconds since the log started>;" -- tag c = Chip / s = Spike / o = no tag (old attacks, bosses), type K / H / C / V / X
-- (Void), plating size = raw x burst scale / the floor's ordinary hit, evadable 1 / 0. Totals per tag: DevHitLogSrvChip / Spike /
-- Other. tools/poe_dmg_kits.py applies defence kits to a log offline. DevHitLogReset (any value) clears the log + totals.
local TYPE_CHAR = { Kinetic = "K", Heat = "H", Cryo = "C", Volt = "V", Void = "X" }
function DungeonGenerator.ProbeHit(attr: string, dmg: number, key: string?, evadable: boolean, bScale: number?, tag: string?, ord: number?)
    tag = tag or EnemyAttacks.HitTag
    local t = (tag == "Chip") and "c" or (tag == "Spike") and "s" or "o"
    ord = ord or Workspace:GetAttribute("DevOrdinaryHit")
    local rel = (type(ord) == "number" and ord > 0) and dmg * math.clamp(bScale or 1, 1, 3) / ord or 0
    local prev = Workspace:GetAttribute(attr)
    if type(prev) ~= "string" or prev == "" or Workspace:GetAttribute("DevHitLogReset") then
        prev = ""
        Workspace:SetAttribute(attr .. "T0", os.clock()) -- (each hit's time since the log started: the Ward model needs it)
        Workspace:SetAttribute("DevHitLogReset", nil)
        for _, k in ipairs({ "Chip", "Spike", "Other" }) do Workspace:SetAttribute(attr .. k, nil) end
    end
    if #prev > 180000 then return end
    Workspace:SetAttribute(attr, prev .. string.format("%s%s%d,%.3f,%d,%.2f;", t, TYPE_CHAR[DungeonGenerator.TypeOfKey(key)] or "K", math.round(dmg), rel, evadable and 1 or 0,
        os.clock() - (Workspace:GetAttribute(attr .. "T0") or os.clock())))
    local ck = (t == "c") and "Chip" or (t == "s") and "Spike" or "Other"
    Workspace:SetAttribute(attr .. ck, (Workspace:GetAttribute(attr .. ck) or 0) + dmg)
end

-- Player hit helper used by bots and bosses: bosses on Hard+ hit with their biome's element.
-- source = the enemy model that landed the hit. On the client this reports the hit to the server, which
-- checks it against that enemy's stand-in (damage cap, rate) before applying it.
function DungeonGenerator.HitPlayer(p: Player, dmg: number, config: DungeonConfig?, elementKey: string?, ailmentChance: number?, source: Instance?)
    local key = elementKey
    if not key and config and (ElementChanceByDiff[config.Difficulty] or 0) >= 0.3 then
        key = BiomeElement[config.Biome]
    end
    -- (UPDATE 8 DEFENCE) Agility can dodge a plain enemy's strike, never a mechanic; (AGILITY vs BOSSES) a boss's only when the
    -- move is on BossAI's PLAIN allow-list
    local isBoss = source and source:GetAttribute("IsBoss") and true or false
    local evadable = EnemyAttacks.Strike == true and (not isBoss or EnemyAttacks.StrikePlain == true)
    if type(EnemyAttacks.AilScale) == "number" then ailmentChance = (ailmentChance or 0.35) * EnemyAttacks.AilScale end -- (POE DAMAGE MODEL: a jab's ailment chance)
    -- where the hit came from (HurtFX points an arc at it); pools you stand in don't point anywhere
    local from = nil
    if source and not EnemyAttacks.AreaHit then
        local ok, pos = pcall(function() return (source :: any):GetPivot().Position end)
        if ok then from = pos end
    end
    if IS_CLIENT then
        if p ~= LocalPlayer then return end
        if RunService:IsStudio() then -- (ENEMY ATTACKS PILOT probe: hits / damage a solo floor's enemies landed on you)
            Workspace:SetAttribute("DevHitsTaken", (Workspace:GetAttribute("DevHitsTaken") or 0) + 1)
            Workspace:SetAttribute("DevDmgTaken", (Workspace:GetAttribute("DevDmgTaken") or 0) + dmg)
        end
        local id = source and source:GetAttribute("EnemyId")
        if from then HurtFX().Arc(from) end -- (solo: the client decided the hit, show where from right away)
        -- (ENEMY ATTACKS PILOT, review B) a burst's round: the burst's total / this round (Plating's hit size) + "not the first round
        -- of the burst to land" (no ailment roll, no Vampiric heal)
        local bScale, bFollow = EnemyAttacks.BurstScale, EnemyAttacks.BurstFollow == true
        Remotes.GetEvent("EnemyHitPlayer"):FireServer(id, dmg, key, bFollow and 0 or (ailmentChance or 0.35), evadable, DungeonGenerator.SourceName(source), bScale, bFollow,
            RunService:IsStudio() and EnemyAttacks.HitTag or nil) -- (QOL2 R1: + who hit you; POE DAMAGE MODEL: the Studio probe's tag)
        return
    end
    -- server-run party dungeon: only that party's members can be hit by its enemies
    local runId = source and RunIdOf(source)
    if runId and p:GetAttribute("RunId") ~= runId then return end
    if RunService:IsStudio() then -- (ENEMY ATTACKS PILOT probe: a party floor's (server) hits; its own attrs, never the solo client's)
        Workspace:SetAttribute("DevHitsTakenSrv", (Workspace:GetAttribute("DevHitsTakenSrv") or 0) + 1)
        Workspace:SetAttribute("DevDmgTakenSrv", (Workspace:GetAttribute("DevDmgTakenSrv") or 0) + dmg)
        pcall(DungeonGenerator.ProbeHit, "DevHitLogSrv", dmg, key, evadable, EnemyAttacks.BurstScale)
    end
    if source and source:GetAttribute("Commanded") then dmg *= DungeonGenerator.COMMAND_DMG end -- (UPDATE 8 COMMANDER elites)
    local bScale, bFollow = EnemyAttacks.BurstScale, EnemyAttacks.BurstFollow == true -- (ENEMY ATTACKS PILOT, review B: see above)
    DungeonGenerator.ApplyHitToPlayer(p, dmg, key, bFollow and 0 or ailmentChance, from, evadable, isBoss, DungeonGenerator.SourceName(source), bScale)
    if not bFollow then DungeonGenerator.EliteOnHit(source) end -- (UPDATE 8 Phase 5: Vampiric party bots; once a burst)
end

-- Server side of a landed enemy hit (also used by DungeonRuns after validating a client report).
-- from = the attacker's position (party dungeons send it to the client for the hit arc); evadable: see TypeOfKey above;
-- boss = the hit came from a boss (CombatServer: BOSS_EVADE on the chance, Ghost's forced misses don't apply)
-- hitScale (ENEMY ATTACKS PILOT, review B): a burst round's burst-total / round ratio -> Plating judges the hit as the whole burst
function DungeonGenerator.ApplyHitToPlayer(p: Player, dmg: number, key: string?, ailmentChance: number?, from: Vector3?, evadable: boolean?, boss: boolean?, src: string?, hitScale: number?)
    local def = key and ElementDefs[key]
    local opts = evadable and { Evadable = true, Boss = boss == true } or nil
    if type(hitScale) == "number" and hitScale > 1 then
        opts = opts or {}
        opts.HitScale = math.min(hitScale, 3)
    end
    if def then
        ServerCombat().DamagePlayer(p, dmg, DungeonGenerator.TypeOfKey(key), DungeonGenerator.HIT_AILMENT_OF_KEY[key] or def.Ailment, ailmentChance or 0.35, from, opts, src)
    else
        ServerCombat().DamagePlayer(p, dmg, key and DungeonGenerator.TypeOfKey(key) or nil, nil, nil, from, opts, src)
    end
end

-- Shields / armor phases change how much damage an enemy takes; the server's stand-in has to know.
function DungeonGenerator.SetTakenMult(model: Instance, v: number?)
    model:SetAttribute("DamageTakenMult", v)
    if IS_CLIENT then
        local id = model:GetAttribute("EnemyId")
        if id then Remotes.GetEvent("EnemyFlag"):FireServer(id, "DamageTakenMult", v) end
    end
end

-- Corridor hazard strips.
function DungeonGenerator.HazardHit(p: Player, dmg: number, part: Instance?)
    if IS_CLIENT then
        if p == LocalPlayer then Remotes.GetEvent("HazardHit"):FireServer(dmg) end
        return
    end
    local runId = part and RunIdOf(part)
    if runId and p:GetAttribute("RunId") ~= runId then return end
    -- (UPDATE 8 DEFENCE) a hazard hits with its biome's type (lava = Heat ...)
    local node, biome = part, nil
    while node and node ~= Workspace and not biome do biome = node:GetAttribute("Biome"); node = node.Parent end
    ServerCombat().DamagePlayer(p, dmg, DungeonGenerator.BiomeHitType(biome), nil, nil, nil, nil, "Hazard")
end

-- Chest opened (kind "Supply" + its id, or "Vault"): the server decides whether it pays out.
-- Server-run party dungeons: set by PartyRuns. (player, kind, chestId, chestPart) / (player, portalPart)
DungeonGenerator.ServerChestHandler = nil :: any
DungeonGenerator.ServerPortalHandler = nil :: any

function DungeonGenerator.ChestOpened(p: Player, kind: string, chestId: number, part: Instance?)
    if IS_CLIENT then
        if p == LocalPlayer then Remotes.GetEvent("OpenChest"):FireServer(kind, chestId) end
    elseif DungeonGenerator.ServerChestHandler then
        DungeonGenerator.ServerChestHandler(p, kind, chestId, part)
    end
end

-- How many non-boss enemies of this dungeon are alive (bosses cap their adds with it).
function DungeonGenerator.LiveAdds(config: any): number
    local n = 0
    for _, m in ipairs(CollectionService:GetTagged("AimRngEnemy")) do
        if m:IsA("Model") and m.Parent and not m:GetAttribute("IsBoss") and m:GetAttribute("Dead") ~= true
            and m.Name ~= "DpsDummy" and not m:GetAttribute("RangeBot") and m:GetPivot().Position.Z > 450
            and m:GetAttribute("RunId") == ((config and config.RunId) or nil) then
            n += 1
        end
    end
    return n
end

-- Boss summons: the client asks, the server rolls the adds and creates their stand-ins.
function DungeonGenerator.RequestSummon(boss: Instance, archetype: string, positions: { Vector3 })
    if IS_CLIENT then
        local id = boss:GetAttribute("EnemyId")
        if id then Remotes.GetEvent("EnemySummon"):FireServer(id, archetype, positions) end
    end
end

-- Set by the client: called when the player enters the next-floor portal.
DungeonGenerator.OnPortal = nil :: ((number?) -> ())?
DungeonGenerator.OnRevisit = nil :: ((string) -> ())? -- BACK PORTAL: "Back" / "Return" (AimRngClient -> DungeonClient.Revisit)

-- ----- Elite modifiers (Path of Exile style: Magic = 1, Rare = 2-3) -----
local EliteModDefs = {
    Hasted = { Word = "Hasted", Desc = "moves 20% faster and attacks 20% faster" }, -- (0.74, owner: "hasted should be faster, but not QUITE as fast": 40% / 30% -> 20% / 20%)
    Armored = { Word = "Armored", Desc = "body shots deal 25% less damage. Aim for the weak spot" },
    Regenerating = { Word = "Regenerating", Desc = "regenerates 1.25% of its health per second" },
    Shielded = { Word = "Shielded", Desc = "now and then raises a shield that blocks half the damage" },
    Volatile = { Word = "Volatile", Desc = "explodes shortly after dying. Don't stand next to it" },
    Multishot = { Word = "Multishot", Desc = "fires three bolts in a spread" },
    Elemental = { Word = "Empowered", Desc = "every attack carries its element" },
    Blinking = { Word = "Blinking", Desc = "teleports every few seconds" },
    Giant = { Word = "Giant", Desc = "much larger with 25% more health" },
    -- (UPDATE 8 Phase 5 ELITE MODS, PoE-style: Magic (blue) elites 1-2 of these, Rare (yellow) 3-4; at most ONE toughness mod)
    Warded = { Word = "Warded", Desc = "now and then raises a ward that blocks half the damage for 2 seconds" },
    Vampiric = { Word = "Vampiric", Desc = "heals 6% of its health whenever it hits you" },
    Summoner = { Word = "Summoning", Desc = "calls two weak bots to its side every 12 seconds (3 times at most)" },
    ExtraHeat = { Word = "Burning", Desc = "its attacks deal extra Heat damage (and can Burn)" },
    ExtraCryo = { Word = "Frozen", Desc = "its attacks deal extra Cryo damage (and can Chill)" },
    ExtraVolt = { Word = "Storm-charged", Desc = "its attacks deal extra Volt damage (and can Shock)" },
    ResistHeat = { Word = "Heatproof", Desc = "+40% Heat resistance" },
    ResistCryo = { Word = "Frostproof", Desc = "+40% Cryo resistance" },
    ResistVolt = { Word = "Grounded", Desc = "+40% Volt resistance" },
    ResistVoid = { Word = "Voidproof", Desc = "+40% Void resistance" },
    -- (UPDATE 8, owner: "Dont have hasted, just make something else" -- then "no splitter either") COMMANDER replaces Hasted:
    -- while it lives, the enemies within COMMAND_RANGE of it deal +20% and take -10% damage (DungeonGenerator.CommanderTick);
    -- a thin gold band round its body marks it (2026-11-07: was a 25-stud reach ring). Shoot the leader first. Not a toughness mod.
    Commander = { Word = "Commanding", Desc = "the enemies around it deal 20% more damage and take 10% less while it lives -- shoot it first" },
    -- (ENEMY ATTACKS PILOT 2026-10-30; numbers + code: AimRngShared/BotRoles) SHELLED = one of five typed shells (a toughness mod):
    -- 40% of its health in a shell that the MATCHING damage type breaks 2.5x as fast (others 0.75x); breaking it staggers it.
    ShellKinetic = { Word = "Iron-shelled", Desc = "a Kinetic shell soaks 40% of its health first: Kinetic damage breaks it 2.5x as fast (other types 0.75x). Breaking it staggers it" },
    ShellHeat = { Word = "Ember-shelled", Desc = "a Heat shell soaks 40% of its health first: Heat damage breaks it 2.5x as fast (other types 0.75x). Breaking it staggers it" },
    ShellCryo = { Word = "Frost-shelled", Desc = "a Cryo shell soaks 40% of its health first: Cryo damage breaks it 2.5x as fast (other types 0.75x). Breaking it staggers it" },
    ShellVolt = { Word = "Storm-shelled", Desc = "a Volt shell soaks 40% of its health first: Volt damage breaks it 2.5x as fast (other types 0.75x). Breaking it staggers it" },
    ShellVoid = { Word = "Void-shelled", Desc = "a Void shell soaks 40% of its health first: Void damage breaks it 2.5x as fast (other types 0.75x). Breaking it staggers it" },
    -- AVENGING (a pack mod): an ally's death speeds up the attacks of everything around it; SKITTISH: it blinks aside when hit
    Avenging = { Word = "Avenging", Desc = "when an enemy near it dies, it and the enemies around it attack 15% more often for 6 s (stacks 3 times). Kill it first" },
    Skittish = { Word = "Skittish", Desc = "blinks a few studs aside when you hit it (at most every 5 s). Follow the blink" },
}
EliteModDefs.Hasted.Desc = "moves and attacks 12% faster" -- (UPDATE 8: no longer rolls and does nothing -- Commander took its place; the def names old stand-ins)
EliteModDefs.Armored.Word = "Armoured" -- (UPDATE 8: Plating-style, body shots -25%)
-- Regenerating (owner 0.49: "a little difficult to kill sometimes"; then "regen should be constant, just make it
-- 1.25% a second"): 2.5%/s -> 1.25%/s, always on (no pause after hits)
local ELITE_REGEN, ELITE_REGEN_WAIT = 0.0125, 0
DungeonGenerator.ELITE_REGEN, DungeonGenerator.ELITE_REGEN_WAIT = ELITE_REGEN, ELITE_REGEN_WAIT
-- (0.82, owner: "Can we just remove the hasted modifier? It makes bots not very fun to shoot"): Hasted no longer rolls
-- and does nothing (its def stays so a bot rolled before the update still gets a name)
-- (UPDATE 8 Phase 5: the PoE-style table; "Resistant" rolls one of ResistHeat / Cryo / Volt / Void, "Extra" one of ExtraHeat /
-- Cryo / Volt. Old keys (Shielded, Multishot, Elemental, Blinking, Giant) keep their defs for old stand-ins but no longer roll.)
local ELITE_MOD_KEYS = { "Commander", "Volatile", "Extra", "Regenerating", "Armored", "Warded", "Vampiric", "Summoner", "Resistant",
    "Shelled", "Avenging", "Skittish" } -- (ENEMY ATTACKS PILOT 2026-10-30: + Shelled (a group), Avenging, Skittish)
DungeonGenerator.EliteMods = EliteModDefs -- bestiary
DungeonGenerator.EliteModKeys = ELITE_MOD_KEYS
local RareEliteChance = { Easy = 0.15, Normal = 0.25, Hard = 0.35, Brutal = 0.45, Nightmare = 0.55, Torment = 0.65, Cataclysm = 0.7, Oblivion = 0.75,
    Ruin = 0.78, Dread = 0.8, Apocalypse = 0.82, Annihilation = 0.85, Eternity = 0.88, Singularity = 0.9, Endless = 0.65 }
-- (2026-10-22 KILL PACE, owner: "Some elites still feel incredibly tanky"): a Rare with 3 mods could stack Giant (x1.6 health) +
-- Armored (-40% body damage) + Shielded (75% blocked ~30% of the time) on its x3 health -- ~8x a plain bot. Now an elite gets
-- at most ONE of the tough mods below (the rest of its mods come from the others), and they're softer: Giant x1.25, Armored
-- -25% body damage, Shielded blocks 50% for 2 s every 8-10 s. Worst case ~x3.75 of a plain bot.
local TOUGH_MODS = { Armored = true, Regenerating = true, Shielded = true, Giant = true, Warded = true, Resistant = true, -- (UPDATE 8: + Warded / Resistant)
    Shelled = true } -- (ENEMY ATTACKS PILOT: a shell is toughness)
DungeonGenerator.TOUGH_MODS = TOUGH_MODS
-- (UPDATE 8 Phase 5: Magic = 1-2 mods, Rare = 3-4 (the tier is read from the count: 3+ = Rare); loot / XP scale with the count)
DungeonGenerator.ELITE_RESIST = { "ResistHeat", "ResistCryo", "ResistVolt", "ResistVoid" }
DungeonGenerator.ELITE_EXTRA = { "ExtraHeat", "ExtraCryo", "ExtraVolt" }
-- (FUTURE-PROOF 2026-10-25) a GROUP key in ELITE_MOD_KEYS rolls one of its variants (a new variant = one row in its list + its def)
DungeonGenerator.ELITE_SHELL = { "ShellKinetic", "ShellHeat", "ShellCryo", "ShellVolt", "ShellVoid" } -- (ENEMY ATTACKS PILOT; type = BotRoles.SHELL_TYPE)
DungeonGenerator.ELITE_GROUPS = { Resistant = DungeonGenerator.ELITE_RESIST, Extra = DungeonGenerator.ELITE_EXTRA, Shelled = DungeonGenerator.ELITE_SHELL }
-- an Extra variant's element key (TypeOfKey maps it to a damage type)
DungeonGenerator.ELITE_EXTRA_KEY = { ExtraHeat = "Fire", ExtraCryo = "Cold", ExtraVolt = "Shock" }
DungeonGenerator.RareEliteChance = RareEliteChance
-- the per-bot elite chance of a floor's roster by difficulty (RollFloorRoster + RollLinkedRoster; was written out in both)
DungeonGenerator.ELITE_CHANCE = { Easy = 0.06, Normal = 0.08, Hard = 0.10, Brutal = 0.12, Nightmare = 0.14, Torment = 0.16, Cataclysm = 0.18,
    Oblivion = 0.2, Ruin = 0.21, Dread = 0.22, Apocalypse = 0.24, Annihilation = 0.26, Eternity = 0.28, Singularity = 0.3, Endless = 0.16 }
-- is elite mod `id` in a model's EliteMods string ("A,B,C")? EXACT ids -- a substring match let "GreaterSummoner" count as "Summoner"
function DungeonGenerator.HasEliteMod(mods: any, id: string): boolean
    if type(mods) ~= "string" or mods == "" then return false end
    return string.find("," .. mods .. ",", "," .. id .. ",", 1, true) ~= nil
end
-- -> the mod ids, the tier ("Magic" | "Rare"). The TIER is decided here and carried (spec.EliteTier, attr EliteTier): a map mod that
-- ADDS a mod (Warbands) must never turn a Magic elite Rare by the count (it did: x3 health, Rare loot).
local function RollEliteMods(config: DungeonConfig): ({ string }, string)
    -- (ENEMY ATTACKS PILOT, Studio test hook) workspace attr DevEliteMods = "ShellHeat,Avenging" -> every elite gets exactly these
    local dev = RunService:IsStudio() and Workspace:GetAttribute("DevEliteMods")
    if type(dev) == "string" and dev ~= "" then
        local list = string.split(dev, ",")
        return list, (#list >= 3) and "Rare" or "Magic"
    end
    local isRare = HasMod(config, "RARE_ELITES") or math.random() < (RareEliteChance[config.Difficulty] or 0.2) -- (UPDATE 8 map mod Champions)
    local count = isRare and ((math.random() < 0.4) and 4 or 3) or ((math.random() < 0.5) and 2 or 1)
    local bag = table.clone(ELITE_MOD_KEYS)
    if BotRoles.Old() then -- (review H: the Studio A/B "old attacks" switch = the old elite pool too)
        for i = #bag, 1, -1 do if BotRoles.PILOT_MODS[bag[i]] then table.remove(bag, i) end end
    end
    local out = {}
    for _ = 1, count do
        if #bag == 0 then break end
        local m = table.remove(bag, math.random(1, #bag))
        local pick = m
        local group = DungeonGenerator.ELITE_GROUPS[m]
        if group then pick = group[math.random(1, #group)] end
        table.insert(out, pick)
        if TOUGH_MODS[m] then -- (one tough mod per elite)
            for i = #bag, 1, -1 do if TOUGH_MODS[bag[i]] then table.remove(bag, i) end end
        end
    end
    -- (UPDATE 8 map mod Warbands: every elite is also Commanding or Volatile)
    if HasMod(config, "COMMANDERS") and not table.find(out, "Commander") and not table.find(out, "Volatile") then
        table.insert(out, (math.random() < 0.5) and "Commander" or "Volatile")
    end
    return out, isRare and "Rare" or "Magic"
end
DungeonGenerator.RollEliteMods = RollEliteMods

-- ----- KILL PACE (2026-10-22, owner: "the game just feels like a slog when killing enemies. Elite rooms take forever, and
-- bosses too ... There needs to be an in between of allowing the player to actually aim, but also not taking mags and mags to kill
-- something") -----
-- Measured from the class harness (an optimal build kills a 100-HP bot in 2.05 x HealthMult s of burst) for a DECENT build
-- (BOSS_DECENT 0.65) landing ~75% of shots, reloads in: a plain bot took ~2 s on Normal, ~4 s Torment, ~5.5 s Ruin, ~8 s
-- Singularity (an AR mag lasts ~3 s), elites x2.4 / x3.6 on top (10-30 s), bosses ~25 s / ~45 s / ~90 s. Now a plain bot's
-- health = BOT_HP_K x (HealthMult / 0.75) ^ BOT_HP_SLOPE instead of HealthMult: ~1 s Easy / Normal, ~1.5 s Torment, ~1.8 s
-- Ruin, ~2.3 s Singularity (the harder tiers still ask more through speed, damage and smaller bodies, not health); elites
-- x2.0 / x3.0 (~3 s / ~4.5 s on Torment); boss seconds (BOSS_PACE) roughly halved. DifficultyScaling HealthMult itself is
-- unchanged (boss tier slope, loot goblins, the class harness all read it).
DungeonGenerator.BOT_HP_K = 0.31
DungeonGenerator.BOT_HP_SLOPE = 0.5
DungeonGenerator.ELITE_HP = { Magic = 2.0, Rare = 3.0 } -- (were 2.4 / 3.6)
-- (RUN PACE 2026-10-24) a per-tier trim on bot / elite / fodder health where the on-level typical kit (treesim + its typical
-- 4-link) still took ~2.6-3.5 s a kill on floor 1 after the room + ramp cuts (Torment / Brutal / Hard ~1.5-1.9 s): Ruin and
-- Annihilation runs were 10-13 min vs 6.5-9 elsewhere. Bosses unchanged (BossHp).
DungeonGenerator.BOT_HP_TIER = { Ruin = 0.85, Annihilation = 0.75 }
function DungeonGenerator.BotHealthMult(difficulty: string?): number
    local hm = (DifficultyScaling[difficulty or ""] or DifficultyScaling.Easy).HealthMult
    return DungeonGenerator.BOT_HP_K * (hm / 0.75) ^ DungeonGenerator.BOT_HP_SLOPE * (DungeonGenerator.BOT_HP_TIER[difficulty or ""] or 1)
end
-- ----- RUN PACE (2026-10-24, owner: runs ~13 min+ -> "how long do poe maps take"; target 6-9 min a run on every tier) -----
-- Measured (autoplay, on-level typical kits + a typical 4-link, docs/RUN_TIMING_2026-10-24.md): fighting is 85-95% of a
-- high-tier run and the LATE floors are the slow ones -- a run's monster level climbs the whole band (Ruin 100 -> 130,
-- Annihilation 200 -> 250) while you stay the same, so floor 5 bots had 3-18x floor 1's health (LevelCurve(ML)) and floor 5 /
-- the finale took 2-5x as long a kill as floor 1. RAMP_HP[tier] = k: inside a run, health follows the monster level's curve
-- only to the power k (1 = as before) -- floor 1 is unchanged, the climb to floor 6 is k as steep (Ruin k 0.5: floor 5 x0.50,
-- the finale x0.42). Damage, XP, gold, loot and item level still follow the full monster level. Bots, elites, fodder (RAMP_HP)
-- and the run's bosses (RAMP_HP_BOSS, BossHp); never maps / trials (their own levels); Endless only within the band (see RampHp). Measured after k 0.5 + 2 rooms:
-- Ruin L109 floors 3-4 still ~6 min -> bots k 0.35 (floor 5 x0.40); bosses at 0.5 came out 30-67 s (Torment / Dread 45 s,
-- were 165 / 204) -> 0.65 (owner's 0.99u pick: a run finale ~60 s for a decent build). The low tiers too (measured runs Normal
-- L4 14 min with a 265 s finale, Hard L12 14 min with a 294 s superboss, Brutal L23 11.7 min): Normal / Hard / Brutal ramps below.
-- Easy keeps the full ramp (a fresh run was 9.5 min: in range).
DungeonGenerator.RAMP_HP = { Easy = 1, Normal = 0.7, Hard = 0.6, Brutal = 0.6, Nightmare = 0.6, Torment = 0.35, Cataclysm = 0.35, Oblivion = 0.35,
    Ruin = 0.35, Dread = 0.35, Apocalypse = 0.35, Annihilation = 0.35, Eternity = 0.35, Singularity = 0.35 }
DungeonGenerator.RAMP_HP_BOSS = { Easy = 1, Normal = 0.5, Hard = 0.5, Brutal = 0.85, Nightmare = 0.8, Torment = 0.65, Cataclysm = 0.65,
    Oblivion = 0.65, Ruin = 0.65, Dread = 0.65, Apocalypse = 0.65, Annihilation = 0.65, Eternity = 0.65, Singularity = 0.65 }
function DungeonGenerator.RampHp(config: any, boss: boolean?): number
    local k = (boss and DungeonGenerator.RAMP_HP_BOSS or DungeonGenerator.RAMP_HP)[config and config.Difficulty or ""]
    if not k or k >= 1 then return 1 end
    if config.MonsterLevel or config.BossTrial or config.AscTrial or config.MapGuardian or config.Rift then return 1 end
    local r = ItemData.MONSTER_LEVEL[config.Difficulty]
    if not r then return 1 end
    local ml = DungeonGenerator.MonsterLevel(config)
    -- (ENDLESS, 2026-10-24 mode check: its floors 1-6 climb the band like a run -- they were up to 1.3x a run floor and its first
    -- bosses 2-5x -- so they get the same flattening; past the band (+2 levels a floor) the climb goes on at full steepness from the
    -- band top's flattened health, so the deep floors stay the wall they were, just from a run's floor-6 start)
    if config.Endless then ml = math.min(ml, r[2]) end
    if ml <= r[1] then return 1 end
    return (ItemData.LevelCurve(r[1]) / ItemData.LevelCurve(ml)) ^ (1 - k)
end

-- ----- the bot -----
function DungeonGenerator.CreateBot(archetype: string, spawnPos: Vector3, config: DungeonConfig, parent: Instance?, eliteMods: { string }?, spec: any?): Model
    archetype = LEGACY_BOT[archetype] or archetype
    local A = BotArchetypes[archetype] or BotArchetypes.Tracker
    local diff = DifficultyScaling[config.Difficulty] or DifficultyScaling.Easy
    local scale = DungeonGenerator.GetScalingMultiplier(config, 0.10)
    local mods: { [string]: boolean } = {}
    for _, m in ipairs(eliteMods or {}) do mods[m] = true end
    local isElite = eliteMods ~= nil and #eliteMods > 0
    local eliteTier = isElite and ((spec and spec.EliteTier) or ((#eliteMods >= 3) and "Rare" or "Magic")) or nil -- (UPDATE 8: Magic 1-2 mods, Rare 3-4; FUTURE-PROOF: the rolled tier wins)

    local elementKey = if spec and not spec.DryRun then spec.Element else RollElement(config, mods.Elemental)
    -- (UPDATE 8 ELITE MODS: Extra Heat / Cryo / Volt -- its attacks carry that type; DungeonGenerator.TypeOfKey maps the key)
    local extraKey = nil
    for k, key in pairs(DungeonGenerator.ELITE_EXTRA_KEY) do if mods[k] then extraKey = key end end
    if extraKey then elementKey = extraKey end
    local elem = elementKey and ElementDefs[elementKey] or nil

    -- (0.61: health / damage at the run's smooth COMBAT level, and each hit x BOT_PACE.Hit)
    local cl = DungeonGenerator.CombatLevel(config)
    local hp = A.Hp * DungeonGenerator.BotHealthMult(config.Difficulty) * ItemData.EnemyHpIndex(cl) * scale * DungeonGenerator.RampHp(config) -- (RUN PACE 2026-10-24)
    local dmg = A.Dmg * scale * diff.Damage * ItemData.EnemyDmgIndex(cl) * 0.1 * DungeonGenerator.BOT_PACE.Hit
    local sizeMult = 1
    if isElite then
        hp *= (eliteTier == "Rare") and DungeonGenerator.ELITE_HP.Rare or DungeonGenerator.ELITE_HP.Magic
        dmg *= (eliteTier == "Rare") and 1.5 or 1.3
        sizeMult = (eliteTier == "Rare") and 1.35 or 1.22
    end
    if mods.Giant then hp *= 1.25; sizeMult *= 1.3 end -- (2026-10-22: was x1.6)
    -- (BOT MOVEMENT POE) the FAST archetypes are fragile too: they die in a few hits (only where they move with a brain: same
    -- rules as their role row -- not a range bay, not a boss floor; every builder of the bot reads this: server stand-in + client)
    if DungeonGenerator.BotMove.FAST[archetype] and not config.Range and not ItemData.IsBossConfig(config) then
        hp *= DungeonGenerator.BotMove.HpMult(archetype, A, BotRoles.RowFor(archetype, spec ~= nil and (spec.Fodder == true or spec.NoAura == true)))
    end
    if extraKey then dmg *= 1.15 end -- (UPDATE 8: the "extra" element damage)
    -- HARD TIER (Nightmare+): smaller bodies (harder to hit), 4% per tier
    local hardTier = DungeonGenerator.HardTier(config.Difficulty)
    if hardTier > 0 and not (spec and spec.DryRun) then sizeMult *= DungeonGenerator.HardShrink(A, hardTier) end -- (tiny fliers stop at Cataclysm)
    if HasMod(config, "SMALL_TARGETS") and not (spec and spec.DryRun) then sizeMult *= 1 - DungeonGenerator.ModV(config, "SMALL_TARGETS") end -- (0.62 map mod; MAPS V2 scaled)
    -- (0.62: the top bot skills make bodies smaller too -- 6% at 9, 12% at 10 -- precision, not reaction)
    do
        local sl = math.clamp(math.floor((config and config.BotSkill) or DungeonGenerator.DEFAULT_BOT_SKILL), 1, 10)
        if sl >= 9 and not (spec and spec.DryRun) then sizeMult *= 1 - 0.06 * (sl - 8) end
    end
    hp = math.max(1, math.round(hp))
    dmg = math.max(1, math.round(dmg))
    if spec and spec.MaxHealth then hp = spec.MaxHealth end
    if spec and spec.HealthScale then hp = math.max(1, math.round(hp * spec.HealthScale)) end
    if spec and spec.AttackDamage then dmg = spec.AttackDamage end
    if spec and spec.DamageScale then dmg = math.max(1, math.round(dmg * spec.DamageScale)) end -- (UPDATE 8: party pack fodder)
    local skill = DungeonGenerator.BotSkill(config)
    -- movement comes from the bot-skill slider only (the dungeon difficulty sets health / damage / loot)
    local moveSpeed = A.Speed * skill.Speed -- (0.82: no Hasted)
    -- HARD TIER (Nightmare+): +6% speed per tier, and the slow types get a floor (they were the "slow, easy" ones)
    if hardTier > 0 and A.Speed > 0 then
        moveSpeed = math.max(moveSpeed, (SLOW_TYPES[archetype] and 12 or 14) * skill.Speed) * DungeonGenerator.HardSpeed(A, DungeonGenerator.BotMove.SpeedTier(hardTier)) -- (BOT MOVEMENT POE: the tier speed stops at Torment; 0.73: no cap -- the speed is what grows; tiny fliers half as fast above Cataclysm)
    end
    local fireInterval = A.Fire * DungeonGenerator.BOT_PACE.Interval -- (0.82: no Hasted)

    local model = Instance.new("Model")
    model.Name = isElite and "EliteDrone" or "AimDrone"
    model:SetAttribute("Health", hp)
    model:SetAttribute("MaxHealth", hp)
    local rewardMult = DungeonGenerator.GetRewardMultiplier(config)
    -- (UPDATE 8 ELITE MODS: rewards scale with the mod count -- 1 mod x2 XP .. 4 mods x5; was Magic x3 / Rare x5)
    local nMods = isElite and #(eliteMods :: { string }) or 0
    local xpMult = isElite and (1 + nMods) or 1
    local goldMult = isElite and (1 + 0.75 * nMods) or 1
    model:SetAttribute("XpReward", DungeonGenerator.EnemyXp(config, xpMult * (A.Hp / 100) ^ 0.5)) -- (LEVELING PACE: ItemData.KillXp)
    local pay = DungeonGenerator.EarlyPayOf(config) -- (EARLY DENSITY 2026-11-07: fewer early kills, each pays more)
    model:SetAttribute("GoldReward", math.round((math.random(diff.GoldMin, diff.GoldMax) / 6) * rewardMult * goldMult * pay))
    if pay ~= 1 then model:SetAttribute("EarlyPay", math.round(pay * 1000) / 1000) end
    model:SetAttribute("DroneType", archetype)
    model:SetAttribute("AttackDamage", dmg)
    if spec and spec.Fodder and not spec.DryRun then -- (UPDATE 8 Phase 5: a server-run (party) pack's fodder; solo stand-ins get this in DungeonRuns)
        local PP = require(script.Parent:WaitForChild("PacksPilot"))
        model:SetAttribute("Fodder", true)
        model:SetAttribute("XpReward", math.round((model:GetAttribute("XpReward") or 0) * PP.XP))
        model:SetAttribute("GoldReward", math.round((model:GetAttribute("GoldReward") or 0) * PP.GOLD))
    end
    -- on the client this bot moves every frame itself (no interpolation needed); server-run party bots DO
    -- need the clients' interpolation (their positions arrive over the network)
    if IS_CLIENT then model:SetAttribute("NoSmooth", true) end
    model:SetAttribute("SpawnId", math.random(1, 100))
    model:SetAttribute("SlowMult", 1)
    if isElite then
        model:SetAttribute("IsElite", true)
        model:SetAttribute("EliteTier", eliteTier)
        model:SetAttribute("EliteMods", table.concat(eliteMods :: { string }, ","))
    end
    if elementKey then model:SetAttribute("Element", elementKey) end
    do -- (ENEMY ATTACKS PILOT elite mods: Shelled's type (the server keeps its ShellHp), Avenging rallies its pack)
        local st = BotRoles.ShellTypeOf(mods)
        if st then model:SetAttribute("ShellType", st) end
        if mods.Avenging then model:SetAttribute("Avenging", true) end
    end
    if mods.Armored then model:SetAttribute("BodyArmor", 0.75) end -- (2026-10-22: was 0.6)

    local isGround = A.Ground == true
    local bodySize = isGround and (Vector3.new(A.Body * 0.95, A.Body * 1.3, A.Body * 0.6) * sizeMult) or (Vector3.new(A.Body, A.Body * 1.12, A.Body) * sizeMult)
    local headSize = Vector3.new(A.Head, A.Head, A.Head) * sizeMult
    local bodyColor = A.Color
    if elem then bodyColor = A.Color:Lerp(elem.Color, 0.35) end
    -- walkers stand on the floor: root (torso center) height above the floor top
    local legH = A.Body * 0.85 * sizeMult
    local groundRootY = 2 + legH + bodySize.Y / 2 -- 2 = chamber floor top (FLOOR_TOP, defined further down)
    if isGround then spawnPos = Vector3.new(spawnPos.X, groundRootY, spawnPos.Z) end

    local root = MakePart({ Name = "DroneRoot", Size = Vector3.new(2, 2, 2), Position = spawnPos, Transparency = 1,
        CanCollide = false, CanTouch = false, CanQuery = false, Anchored = true, Parent = model })
    model.PrimaryPart = root
    if mods.Commander then -- (UPDATE 8 COMMANDER: a thin, steady ring = which bot it is; follows the bot, no part, no light, no flashing)
        -- (2026-11-07, owner: "Orbiters have this giant annoying circle around them") it was the 25-stud REACH ring (50 across), set
        -- 3 studs under a flier's root -- and a flier's root turns to face you, so the ring tilted with it, a giant hoop round the bot
        -- in mid-air. Now a thin band hugging the body (COMMAND_BAND studs out), on the body's own tilt: it marks the bot to shoot first.
        local ring = Instance.new("CylinderHandleAdornment")
        ring.Name = "CommandRing"
        local rr = math.max(bodySize.X, bodySize.Z) * 0.5 + DungeonGenerator.COMMAND_BAND
        ring.Radius, ring.InnerRadius, ring.Height = rr, rr - 0.16, 0.05
        ring.CFrame = CFrame.Angles(math.pi / 2, 0, 0)
        ring.Color3, ring.Transparency, ring.AlwaysOnTop, ring.ZIndex = Color3.fromRGB(255, 196, 90), 0.3, false, 0
        ring.Adornee = root
        ring.Parent = model
    end
    local torso = MakePart({ Name = "Torso", Shape = isGround and Enum.PartType.Block or Enum.PartType.Ball, Size = bodySize, CFrame = CFrame.new(spawnPos),
        Color = bodyColor, Material = Enum.Material.SmoothPlastic, CanCollide = true, CanQuery = true, Anchored = true, Parent = model })
    local legs: { BasePart } = {}
    if isGround and not EnemyModels.PILL_BOTS then -- (0.97 PILL BOTS: the capsule reaches the floor -- no legs)
        -- shoulders + two legs (legs swing with the strafe, see the AI loop)
        MakePart({ Name = "Shoulders", Size = Vector3.new(bodySize.X * 1.25, bodySize.Y * 0.22, bodySize.Z * 1.05), CFrame = CFrame.new(spawnPos + Vector3.new(0, bodySize.Y * 0.36, 0)),
            Color = bodyColor:Lerp(Color3.new(0, 0, 0), 0.25), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = true, Anchored = true, Parent = model })
        for _, side in ipairs({ -1, 1 }) do
            local leg = MakePart({ Name = side < 0 and "LegL" or "LegR", Size = Vector3.new(bodySize.X * 0.32, legH, bodySize.Z * 0.75),
                CFrame = CFrame.new(spawnPos + Vector3.new(side * bodySize.X * 0.26, -bodySize.Y / 2 - legH / 2, 0)),
                Color = bodyColor:Lerp(Color3.new(0, 0, 0), 0.4), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = true, Anchored = true, Parent = model })
            table.insert(legs, leg)
        end
    end
    local headY = bodySize.Y / 2 + headSize.Y / 2 - 0.2
    local head = MakePart({ Name = "Head", Shape = Enum.PartType.Ball, Size = headSize, CFrame = CFrame.new(spawnPos + Vector3.new(0, headY, 0)),
        Color = A.Color, Material = Enum.Material.Neon, CanCollide = true, CanQuery = true, Anchored = true, Parent = model })
    MakePart({ Name = "Visor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(headSize.X * 0.34, headSize.Y * 1.04, headSize.Y * 1.04),
        CFrame = head.CFrame * CFrame.Angles(0, 0, math.rad(90)), BrickColor = BrickColor.new("Really black"), Material = Enum.Material.SmoothPlastic,
        Transparency = 0.25, CanCollide = false, CanQuery = false, CanTouch = false, Anchored = true, Parent = model })
    for _, p in ipairs({ torso, head }) do p:SetAttribute("Damageable", true) end
    if A.Shield then
        -- Warden: an energy shield in front of the body (the head pokes out above it). Shots into "Shield" deal
        -- 10% (CombatServer). It turns with the model (models face their target along -Z).
        local sh = MakePart({ Name = "Shield", Size = Vector3.new(bodySize.X * 2.0, bodySize.Y * 0.95 + legH * 0.9, 0.35),
            CFrame = CFrame.new(spawnPos + Vector3.new(0, -legH * 0.5, -(bodySize.Z / 2 + 1.1))), -- top at shoulder height: the head stays exposed Color = Color3.fromRGB(120, 200, 255),
            Material = Enum.Material.Neon, Transparency = 0.72, CanCollide = false, CanQuery = true, Anchored = true, Parent = model })
        sh.CastShadow = false
        -- bright rim so the shield edge reads at a distance
        for _, yo in ipairs({ 1, -1 }) do
            MakePart({ Name = "ShieldRim", Size = Vector3.new(sh.Size.X, 0.25, 0.45), CFrame = sh.CFrame * CFrame.new(0, yo * sh.Size.Y / 2, 0),
                Color = Color3.fromRGB(200, 240, 255), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, Anchored = true, Parent = model })
        end
    end
    if A.Burst then
        -- Gunship: twin gun pods on the sides
        for _, side in ipairs({ -1, 1 }) do
            MakePart({ Name = "GunPod", Size = Vector3.new(bodySize.X * 0.5, bodySize.Y * 0.3, bodySize.Z * 0.9),
                CFrame = CFrame.new(spawnPos + Vector3.new(side * bodySize.X * 0.68, -bodySize.Y * 0.1, 0)), Color = Color3.fromRGB(60, 60, 70),
                Material = Enum.Material.Metal, CanCollide = false, CanQuery = true, Anchored = true, Parent = model })
        end
    end
    if A.Healer then
        -- Medic: a glowing green cross on the body
        local front = spawnPos + Vector3.new(0, 0, -bodySize.Z * 0.48)
        for _, sz in ipairs({ Vector3.new(bodySize.X * 0.22, bodySize.Y * 0.7, 0.2), Vector3.new(bodySize.X * 0.7, bodySize.Y * 0.22, 0.2) }) do
            MakePart({ Name = "Cross", Size = sz, CFrame = CFrame.new(front), Color = Color3.fromRGB(120, 255, 150), Material = Enum.Material.Neon,
                CanCollide = false, CanQuery = false, CanTouch = false, Anchored = true, Parent = model })
        end
    end

    -- Elite crown ring (tier-colored) and element aura
    local halo: BasePart? = nil
    if isElite then
        local tierColor = (eliteTier == "Rare") and Color3.fromRGB(255, 205, 60) or Color3.fromRGB(110, 150, 255)
        halo = MakePart({ Name = "EliteHalo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, bodySize.X * 1.6, bodySize.X * 1.6),
            CFrame = CFrame.new(spawnPos) * CFrame.Angles(0, 0, math.rad(90)), Color = tierColor, Material = Enum.Material.ForceField, -- (0.53: a shimmering ring, not a solid plate)
            Transparency = 0, CanCollide = false, CanQuery = false, CanTouch = false, Anchored = true, Parent = model })
    end
    if elem and not (spec and (spec.Fodder or spec.NoAura)) then -- (PACK SIZE BY DIFFICULTY: fodder wear no aura -- packs double in size on the top tiers; the leader shows the element)
        local att = Instance.new("Attachment")
        att.Parent = torso
        local pe = Instance.new("ParticleEmitter")
        pe.Name = "ElementAura"
        pe.Color = ColorSequence.new(elem.Color)
        pe.LightEmission = 0.4
        pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 * sizeMult), NumberSequenceKeypoint.new(1, 0) })
        pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
        pe.Lifetime = NumberRange.new(0.5, 0.9)
        pe.Rate = 10
        pe.Speed = NumberRange.new(1, 2.5)
        pe.SpreadAngle = Vector2.new(180, 180)
        pe.Parent = att
    end

    -- Health bar + name ("Hasted Armored Frozen Strafer")
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "HealthHUD"
    billboard.Enabled = false -- (never shown: EnemyBars draws every bar; an enabled one doubled the name + bar)
    billboard.Size = UDim2.new(0, isElite and 170 or 116, 0, isElite and 30 or 16)
    billboard.StudsOffset = Vector3.new(0, 2.4 + headSize.Y, 0)
    billboard.MaxDistance = isElite and 130 or 90
    billboard.Adornee = head
    billboard.Parent = model
    local bgBar = Instance.new("Frame")
    bgBar.Name = "Background"
    bgBar.Size = UDim2.new(1, 0, isElite and 0.55 or 1, 0)
    bgBar.Position = UDim2.new(0, 0, isElite and 0.45 or 0, 0)
    bgBar.BackgroundColor3 = Color3.fromRGB(15, 20, 25)
    bgBar.BorderSizePixel = 1
    bgBar.BorderColor3 = elem and elem.Color or A.Color
    bgBar.Parent = billboard
    local fillBar = Instance.new("Frame")
    fillBar.Name = "Fill"
    fillBar.Size = UDim2.new(1, 0, 1, 0)
    fillBar.BackgroundColor3 = elem and elem.Color or A.Color
    fillBar.BorderSizePixel = 0
    fillBar.Parent = bgBar
    local words = {}
    for _, m in ipairs(eliteMods or {}) do
        -- (UPDATE 8: an Extra-element mod's word is the element's own word, added below)
        if m ~= "Elemental" and string.sub(m, 1, 5) ~= "Extra" and EliteModDefs[m] then table.insert(words, EliteModDefs[m].Word) end
    end
    if elem then table.insert(words, elem.Word) end
    table.insert(words, A.Label)
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "NameLabel"
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = isElite and Enum.Font.GothamBlack or Enum.Font.GothamBold
    nameLbl.TextStrokeTransparency = 0.3
    if isElite then
        nameLbl.Size = UDim2.new(1, 0, 0.45, 0)
        nameLbl.TextSize = 12
        nameLbl.TextColor3 = (eliteTier == "Rare") and Color3.fromRGB(255, 215, 80) or Color3.fromRGB(140, 170, 255)
        nameLbl.Text = table.concat(words, " ")
        nameLbl.Parent = billboard
    else
        nameLbl.Size = UDim2.new(1, 0, 1, 0)
        nameLbl.TextSize = 10
        nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLbl.Text = table.concat(words, " ")
        nameLbl.Parent = bgBar
    end

    -- the look (EnemyModels): armor, glowing eye, fins / thrusters / weapons, arms for walkers. kv also holds the
    -- per-bot state of the newer movement patterns (one table keeps CreateBot under Luau's local-variable limit)
    -- Party floors run on the SERVER: there every moved part replicates 10-20x a second, so the server bot stays plain
    -- and each client dresses it locally (DecoArgs -> DungeonGenerator.DecorateReplicated, moved with the body)
    local partyServer = (not IS_CLIENT) and not (spec and spec.DryRun)
    local pillBiome = tostring(config.Biome or A.Biome or "Fire")
    local pillTiny = (not isGround) and A.Body <= (DungeonGenerator.TINY_BODY or 1.7)
    local kv = { Deco = {} }
    if mods.Commander and IS_CLIENT and not (spec and spec.DryRun) then kv.cmdFloor = DungeonGenerator.CommandFloorRing(model, spawnPos) end -- (COMMAND REACH: solo floors)
    if spec and spec.Link and not spec.DryRun then -- (LINKED ROOMS pilot: its room's leash box + its pack's spot; idle until woken)
        kv.lnk = spec.Link
        model:SetAttribute("LinkPack", spec.Link.Pack)
    end
    if not (spec and spec.DryRun) and not partyServer then
        if EnemyModels.PILL_BOTS then -- (0.97 PILL BOTS)
            local pc, ph = DungeonGenerator.PillColors(pillBiome, archetype)
            kv.Deco = EnemyModels.Pill(model, { Arch = A, Pos = spawnPos, Body = bodySize, Head = headSize, Ground = isGround, LegH = legH,
                Color = pc, HeadColor = ph, Biome = pillBiome, Scale = sizeMult, Tiny = pillTiny })
        else
            kv.Deco = EnemyModels.Decorate(model, { Arch = A, Pos = spawnPos, Body = bodySize, Head = headSize,
                Ground = isGround, LegH = legH, Color = bodyColor, Scale = sizeMult, Melee = A.Melee })
        end
    end
    if partyServer then
        model:SetAttribute("DecoArgs", string.format("%s|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%d|%.3f|%d,%d,%d|%.3f|%s", archetype,
            bodySize.X, bodySize.Y, bodySize.Z, headSize.X, headSize.Y, headSize.Z, isGround and 1 or 0, legH or 0,
            math.round(bodyColor.R * 255), math.round(bodyColor.G * 255), math.round(bodyColor.B * 255), sizeMult or 1, pillBiome))
    end
    DungeonGenerator.SoftenEnemyVisuals(model)
    if not (spec and spec.DryRun) and not partyServer then EnemyModels.MakeHittable(model) end -- (every visible part takes hits)
    model:SetAttribute("AnimStyle", A.Style or "Orb") -- (EnemyAnim: how it moves)
    if isGround then model:SetAttribute("AnimGround", true) end
    CollectionService:AddTag(model, "AimRngEnemy") -- lets clients find & smooth enemy motion (see AimRngClient)
    if spec and spec.DryRun then return model end -- server: stats only (see DungeonRuns)
    if spec and spec.EnemyId then model:SetAttribute("EnemyId", spec.EnemyId) end
    if config.RunId then model:SetAttribute("RunId", config.RunId) end
    model.Parent = parent

    task.spawn(function()
        local rng = Random.new()
        local currentPos = spawnPos
        local lastTick = os.clock()
        local phase = rng:NextNumber(0, 100)       -- pattern clock (runs slower while frozen)
        local bearing = rng:NextNumber(0, math.pi * 2)
        local prefDist = rng:NextNumber(A.Range[1], A.Range[2])
        local baseHeight = rng:NextNumber(7, 14)
        local lateral, latVel, latDir = 0, 0, (rng:NextNumber() < 0.5) and -1 or 1
        local nextFlip = os.clock() + rng:NextNumber(0.3, 0.8)
        local nextBlink = os.clock() + rng:NextNumber(0.6, 1.2) * DungeonGenerator.BLINK_SLOW
        local blinkOffset = Vector3.zero
        local hopT, hopDur, hopHeight = 0, rng:NextNumber(1.1, 1.6), rng:NextNumber(3, 5.5)
        local peekSpot: Vector3? = nil
        local peekDeadline = 0
        local nextAttack = os.clock() + rng:NextNumber(1.2, 2.6)
        -- TELEGRAPHED ATTACKS (EnemyAttacks): every attack shows what's coming and when
        -- (POE DAMAGE MODEL) the tier's role-attack scaling: round / shell speed, lead share, spread (EnemyAttacks.TierScale)
        kv.tier = EnemyAttacks.TierScale(ItemData.DifficultyRank[config.Difficulty or ""] or 1)
        if not IS_CLIENT and RunService:IsStudio() and not R then Workspace:SetAttribute("DevOrdinaryHit", DungeonGenerator.OrdinaryHit(config)) end -- (party probe)
        local atk = EnemyAttacks.Context({
            Geo = config.Geo, Fx = FxParent(config), Color = elem and elem.Color or nil, Windup = BotWindup(config), Model = model, -- (Model: EnemyAnim's wind-up pose; 0.61 BOT_PACE)
            ShotColor = DungeonGenerator.ShotColor(elementKey, config), -- (ENEMY ATTACKS PILOT: rounds in the colour of the type they hit with)
            TrailColor = A.Color, -- (ENEMY ATTACKS PILOT: the trail = the shooter's own colour, a fire bot's rounds read as fire on any tier)
            TierSpeed = kv.tier.Speed, -- (POE DAMAGE MODEL: only the role attacks' Shot / Shell / Aim read it)
            Targets = function() return TargetPlayers(config) end,
            Alive = function() return model.Parent ~= nil and model:GetAttribute("Dead") ~= true and model:GetAttribute("PredictedDead") ~= true end,
            Hit = function(p, mult) DungeonGenerator.HitPlayer(p, dmg * (mult or 1), nil, elementKey, (mods.Elemental or isElite) and 1 or 0.5, model) end,
        })
        local holdUntil = 0            -- melee wind-up: the bot holds still so its floor telegraph stays honest
        local dashFrom: Vector3?, dashTo: Vector3?, dashT0 = nil, nil, 0 -- Charger lunge
        local meleeCount = 0
        local inSafeNow = false
        local aimingUntil = 0
        local laser: BasePart? = nil
        local nextShield = os.clock() + rng:NextNumber(3, 6)
        local shieldUntil = 0
        local shieldPart: BasePart? = nil
        local nextEliteBlink = os.clock() + rng:NextNumber(3, 5) * DungeonGenerator.BLINK_SLOW
        local emptyArenaTimer = 0
        -- line of sight (checked 4x/s): no shooting into cover; the longer you stay hidden, the more the bot
        -- circles round and closes in to find an angle on you
        local hasLos, nextLosCheck, coverT = true, 0, 0
        -- attack slots: a bot without one circles to a new side (repoDir) and, for melee, hangs back a moment
        local repoDir = (rng:NextNumber() < 0.5) and -1 or 1
        local backoffUntil = 0
        local function Slot(nowT: number, holdFor: number, target: Instance?): boolean
            if not target then return true end
            -- (0.60c: elites queue too, with one extra slot; they used to skip the limit and pile on late in a run)
            -- (0.61: the slot is held for the whole, longer wind-up, and BOT_PACE.Slots caps it on every difficulty)
            if EnemyAttacks.TakeSlot(target, model, holdFor * atk.Windup * EnemyAttacks.REACT, config.Difficulty, model:GetAttribute("EliteTier") and 1 or 0, DungeonGenerator.BOT_PACE.Slots) then return true end
            bearing += repoDir * rng:NextNumber(0.5, 1.0)
            backoffUntil = nowT + rng:NextNumber(0.8, 1.4)
            nextAttack = nowT + rng:NextNumber(0.35, 0.75)
            return false
        end
        local learn = EnemyMind.LearnByDifficulty[config.Difficulty] or 0.65
        -- aggression: every few seconds the bot pushes in (half its usual distance) for a moment, so bots don't
        -- just mirror your movement from a fixed distance
        local nextPush, pushUntil = os.clock() + rng:NextNumber(3, 7), 0
        local lastPos = currentPos

        local isBossFloor = ItemData.IsBossConfig(config)
        local layout = DungeonGenerator.GetChamberLayout(isBossFloor)
        -- (0.75, owner: "Flying bots can go outside of the map so they cant be shot"): the box was a fixed +-70 while rooms
        -- are 123 wide (+-61.5) -- fliers drifted up to 8 studs past the walls. Now it's the room, 4 studs in from the walls.
        local half = layout.CombatSize / 2 - 4
        local minX, maxX = -half, half
        local minZ, maxZ = layout.CombatZ - half, layout.CombatZ + half
        if kv.lnk then minX, maxX, minZ, maxZ = kv.lnk.X0, kv.lnk.X1, kv.lnk.Z0, kv.lnk.Z1 end -- (LINKED ROOMS pilot: its own room)
        local minY, maxY = 5, 30
        -- hub Training Grounds (config.Range): the bot stays inside its bay and never attacks
        local R = config.Range
        if R then minX, maxX, minY, maxY, minZ, maxZ = R.MinX, R.MaxX, R.MinY or minY, R.MaxY or maxY, R.MinZ, R.MaxZ end
        -- the entry room is a SAFE ZONE (no damage there, see CombatServer.InSafeZone): bots stay in the arena and,
        -- while you're in it, spread out and patrol instead of lining up at the doorway
        local safeZ = layout.CorridorAStart
        local wanderPt: Vector3? = nil
        local nextWander = 0
        local group = BotGroups[config]
        if not group then group = {}; BotGroups[config] = group end
        -- in a range bay the bot works around its own spot down the middle of the bay (not around the player)
        local rangeAnchorX = R and ((R.MinX + R.MaxX) / 2 + rng:NextNumber(-2, 2)) or 0
        local rangeAnchorZ = R and rng:NextNumber(R.MinZ + 8, R.MaxZ - 8) or 0
        local radius = math.max(bodySize.X, bodySize.Y) * 0.5
        if isGround then radius = math.max(bodySize.X, bodySize.Z) * 0.6 end
        -- (ENEMY ATTACKS PILOT 2026-10-30) the bot's ROLE (AimRngShared/BotRoles): nil = its old attack (no row / DevAttacksOld)
        do
            -- (review D: never on a boss floor -- the Titan's escort Trackers, a mini-boss arena's pack wave -- bosses are unchanged)
            local roleRow = (not R) and not isBossFloor and BotRoles.RowFor(archetype, spec ~= nil and (spec.Fodder == true or spec.NoAura == true)) or nil
            if roleRow then
                kv.role = { Row = roleRow, Model = model, Atk = atk, PosFn = function() return currentPos end, Radius = radius, Head = head,
                    Group = group, Fx = FxParent(config), SetTaken = DungeonGenerator.SetTakenMult, Tier = kv.tier,
                    -- (POE DAMAGE MODEL) auras / caster pools / the death burst: the bot's OWN damage key, like its rounds (review 2: the
                    -- biome key overrode Kinetic on Easy / Normal and an Extra-X elite's type), never evadable (EnemyAttacks.AreaHit)
                    AreaHit = function(p, mult) DungeonGenerator.HitPlayer(p, dmg * (mult or 1), nil, elementKey, 0.15, model) end }
                BotRoles.StartAura(kv.role, function() return kv.auraOn == true end) -- (casters with an Aura row; ends with the bot)
            end
            kv.shellT = model:GetAttribute("ShellType") -- (the Shelled elite mod's type; its bubble is drawn in the loop)
            -- (review N) the stagger time arrives as an attribute change (no per-frame read; the connection dies with the model)
            kv.stagU = model:GetAttribute("StaggerUntil")
            model:GetAttributeChangedSignal("StaggerUntil"):Connect(function() kv.stagU = model:GetAttribute("StaggerUntil") end)
        end
        -- strafe brains (movement difficulty = bot-skill slider only)
        local chaos = DungeonGenerator.StrafeChaos(config)
        local brain = nil
        if A.Pattern == "GroundStrafe" then
            brain = NewStrafeBrain(rng, chaos, moveSpeed, 16, A.Profile)
        elseif A.Pattern == "FastStrafe" then
            brain = NewStrafeBrain(rng, chaos, moveSpeed, 15, { Jump = -1 })
        elseif A.Pattern == "SlowStrafe" then
            brain = NewStrafeBrain(rng, chaos * 0.6, moveSpeed, 14, { Long = 0.3, Jump = -1 }, 1.8)
        elseif A.Pattern == "Orbit" then -- (0.74: the Orbiter strafes side to side in front of you -- see pat == "Orbit")
            brain = NewStrafeBrain(rng, chaos * 0.6, moveSpeed, 16, { Long = 0.5, Jump = -1 }, 1.8)
        end
        -- melee chasers weave with their own strafe brain (playtester 2026-10-02: "juggernauts have this weird movement
        -- following pattern, makes them stupid easy to shoot" -- it was a fixed +-3 stud sine wave)
        local meleeBrain = A.Melee and NewStrafeBrain(rng, math.max(0.35, chaos), moveSpeed * 0.8, 9, { Jump = -1 }) or nil
        local jumpT, jumpDur, jumpH = -1, 0.55, 5
        -- shared motion smoothing: every pattern's target is followed with a velocity whose ACCELERATION is
        -- capped, so state switches (charge/retreat, bounce flips, new peek spots) never snap -- at any
        -- bot-skill step or dungeon difficulty
        local smoothVel = Vector3.zero
        local lastDesired: Vector3? = nil
        -- unstick: no progress for ~1.2s while it still wants to move -> detour to a reachable open spot
        local unstick = { Pt = nil :: Vector3?, Until = 0, Next = 0, Count = 0, Ref = currentPos }
        local function Clamp(v: Vector3): Vector3
            if kv.lact then return DungeonGenerator.LinkClamp(kv.lact, v, kv.lowY or minY, maxY) end -- (LINKED ROOMS v3: its leash boxes)
            return Vector3.new(math.clamp(v.X, minX, maxX), math.clamp(v.Y, kv.lowY or minY, maxY), math.clamp(v.Z, minZ, maxZ)) -- (kv.lowY: Magmaw sinking)
        end
        -- (BOT MOVEMENT POE 2026-10-30) a role bot's MOVEMENT BRAIN (AimRngShared/BotMove; nil = its old pattern: no row, a kept
        -- pattern, DevMoveOld). Its speed = the role's x the bot-skill step x the speed mods x the tier speed (stopped at Torment).
        -- (review) it moves by its archetype's REAL row: a pack-fodder Drifter fires one round (FodderRow, a gunner row) but still plods
        if kv.role and DungeonGenerator.BotMove.Wants(archetype, A, BotRoles.ActiveRow(archetype) or kv.role.Row) then -- (ENEMY VARIETY: the pilot's row while it is on)
            local BM = DungeonGenerator.BotMove
            kv.mv = BM.New({ Rng = rng, Row = BotRoles.ActiveRow(archetype) or kv.role.Row, A = A, Arch = archetype, Radius = radius, Ground = isGround, GroundY = groundRootY,
                Height = baseHeight, Melee = A.Melee == true, Clamp = Clamp, Geo = config.Geo, Group = group, Model = model, Client = IS_CLIENT,
                Speed = skill.Speed / BM.STD_SPEED * ((hardTier > 0) and DungeonGenerator.HardSpeed(A, BM.SpeedTier(hardTier)) or 1), Freq = skill.Freq })
            kv.mvc = {} -- (review: the Step argument table, refilled every frame -- no garbage a frame)
            -- the model's wind-up window (EnemyAttacks stamps AtkEnd, server time): it PLANTS until it has fired
            kv.atkEnd = model:GetAttribute("AtkEnd")
            model:GetAttributeChangedSignal("AtkEnd"):Connect(function() kv.atkEnd = model:GetAttribute("AtkEnd") end)
        end
        -- (BOT MOVEMENT POE) the readability cap: every bot's own motion across the screen of the player it fights
        kv.capOn = not R and not DungeonGenerator.BotMove.Old()
        -- (Phasewing / Magmaw) fade the whole bot and switch its hitboxes off and on
        local fadeParts: { [BasePart]: number }? = nil
        local function FadeBot(vis: number, hittable: boolean)
            if not fadeParts then
                fadeParts = {}
                for _, d in ipairs(model:GetDescendants()) do
                    if d:IsA("BasePart") and d ~= root then (fadeParts :: any)[d] = d.Transparency end
                end
            end
            for p, t0 in pairs(fadeParts :: any) do if p.Parent then p.Transparency = 1 - (1 - t0) * vis end end
            for _, n in ipairs({ "Torso", "Head" }) do
                local h = model:FindFirstChild(n)
                if h and h:IsA("BasePart") then h.CanQuery = hittable end
            end
            for p in pairs(fadeParts :: any) do if p:GetAttribute("HitAs") then p.CanQuery = hittable end end
        end
        local function FxPart(props: any, life: number): BasePart
            local p = Instance.new("Part")
            p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
            p.Material = Enum.Material.Neon
            for k2, v in pairs(props) do p[k2] = v end
            p.Parent = FxParent(config)
            Debris:AddItem(p, life)
            return p
        end
        -- every teleport shows where it left and where it went (Blinker, Blinking elites)
        local function BlinkTell(from: Vector3, to: Vector3)
            local d = math.max(2.4, radius * 2.2)
            FxPart({ Name = "BlinkFlash", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), CFrame = CFrame.new(from), Color = A.Color, Transparency = 0.35 }, 0.3)
            FxPart({ Name = "BlinkFlash", Shape = Enum.PartType.Ball, Size = Vector3.new(d * 0.8, d * 0.8, d * 0.8), CFrame = CFrame.new(to), Color = Color3.new(1, 1, 1), Transparency = 0.4 }, 0.2)
            if (to - from).Magnitude > 1 then
                FxPart({ Name = "BlinkStreak", Size = Vector3.new(0.35, 0.35, (to - from).Magnitude), CFrame = CFrame.lookAt((from + to) / 2, to), Color = A.Color, Transparency = 0.25 }, 0.18)
            end
        end

        while model.Parent do
            local now = os.clock()
            local dt = math.min(0.2, now - lastTick)
            lastTick = now
            if kv.lnk then -- (LINKED ROOMS pilot: an idle pack far from you runs no AI at all; one nearby mills in slow motion)
                kv.lst = DungeonGenerator.LinkCheck(kv, model, currentPos, config.Geo, config)
                if kv.lbb then minX, maxX, minZ, maxZ = kv.lbb[1], kv.lbb[2], kv.lbb[3], kv.lbb[4] end -- (v3: home or chase area)
                if kv.lst == 0 then kv.auraOn = false; task.wait(0.25); continue end -- (review 2: an idle pack's caster hides its aura)
            end
            local slowMult = (model:GetAttribute("SlowMult") or 1) * ((kv.lst == 1) and DungeonGenerator.LR.IDLE_PACE or 1)
            local tdt = dt * slowMult

            -- nearest player in the arena
            local targetHrp: BasePart? = nil
            local minDist = math.huge
            local inArena = 0
            for _, player in ipairs(TargetPlayers(config)) do
                local c = player.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                if hrp and hrp:IsA("BasePart") and (R ~= nil or hrp.Position.Z > 450) then
                    inArena += 1
                    local d = (hrp.Position - currentPos).Magnitude
                    if d < minDist then minDist = d; targetHrp = hrp end
                end
            end
            -- nobody to chase (you're in the safe room, downed or respawning): only give up when the arena is really empty.
            -- (owner: "arena sometimes just has no enemies ... sitting in the safe room for too long or after reviving":
            -- a solo floor's bots treated "no target" as "no one here" and deleted themselves after 8 s, while the server
            -- still counted them -> an empty arena that could never be cleared. Solo floors are torn down by DungeonClient;
            -- a server (party) bot goes when every member has left the arena; a hub range bot when you've gone.)
            if inArena == 0 and (R ~= nil or (not IS_CLIENT and not AnyoneInArena(config))) then
                emptyArenaTimer += dt
                if emptyArenaTimer >= 8.0 then model:Destroy(); break end
            else
                emptyArenaTimer = 0
            end

            kv.pace = kv.pace or (DungeonGenerator.HardPace(A.Pattern, math.min(DungeonGenerator.BotMove.SpeedTier(hardTier), DungeonGenerator.PATTERN_TIER_CAP)) -- (0.73; BOT MOVEMENT POE: the pace stops at Torment too)
                * ((DungeonGenerator.HARD_PACE.Keep[A.Pattern] or DungeonGenerator.HARD_PACE.Erratic[A.Pattern]) and 1 or (1 + DungeonGenerator.PATTERN_TEMPO * math.max(0, DungeonGenerator.BotMove.SpeedTier(hardTier) - DungeonGenerator.PATTERN_TIER_CAP)))) -- (0.89 tempo; not the erratic ones: they were slowed on purpose)
                * (DungeonGenerator.FAST_FLIERS[archetype] and DungeonGenerator.FAST_FLIER_PACE or 1) -- (the measured fast fliers)
            phase += tdt * skill.Freq * kv.pace
            local desired = currentPos
            if targetHrp then
                local pPos = targetHrp.Position
                if not R and now >= nextLosCheck then
                    nextLosCheck = now + 0.25
                    local rp = ObstacleParams(config.Geo)
                    local was = hasLos
                    hasLos = not (rp and Workspace:Raycast(currentPos, pPos - currentPos, rp))
                    if hasLos and not was and coverT > 0.8 then EnemyMind.Peek(targetHrp) end -- (you stepped out of cover here)
                end
                if hasLos then coverT = math.max(0, coverT - dt * 1.5) else coverT = math.min(4, coverT + dt) end
                -- (playtester 2026-10-02: bots stuck on a corner while you jiggle-peek them -- they now swing round much
                -- sooner and faster to find an angle on you)
                local flank = math.clamp(coverT / 1.2, 0, 1)
                -- INDIVIDUAL MOVEMENT (owner 2026-10-03: "enemies tend to make like a wall... all end up mirroring the player
                -- and therefore each other"). Every bot used to stand at a fixed offset from your exact position and orbit at
                -- the same speed, so when you moved they all moved as one. Now each bot: follows a LAGGED copy of you (its own
                -- reaction time), drifts round you at its own speed and direction, re-picks its angle + distance every few
                -- seconds (at its own times), and keeps an angle around you clear of the other bots.
                local ind = kv
                ind.lagT = ind.lagT or rng:NextNumber(0.45, 1.6)
                ind.orb = ind.orb or (rng:NextNumber(0.04, 0.22) * ((rng:NextNumber() < 0.5) and -1 or 1))
                ind.fp = ind.fp and ind.fp:Lerp(pPos, 1 - math.exp(-tdt / ind.lagT)) or pPos
                ind.dj = ind.dj or rng:NextNumber(-0.3, 0.3) -- (its own distance band: they don't all stand on one arc)
                if now >= (ind.reloc or 0) then
                    if ind.reloc then
                        bearing += rng:NextNumber(-1.1, 1.1)
                        prefDist = rng:NextNumber(A.Range[1], A.Range[2])
                    end
                    ind.reloc = now + rng:NextNumber(3.5, 7.5)
                end
                if not kv.mv then -- (BOT MOVEMENT POE: a brain spreads itself)
                    local myA = math.atan2(currentPos.Z - pPos.Z, currentPos.X - pPos.X)
                    for other, op in pairs(group) do
                        if other ~= model and other.Parent then
                            local oa = math.atan2(op.Z - pPos.Z, op.X - pPos.X)
                            local dA = math.atan2(math.sin(myA - oa), math.cos(myA - oa))
                            -- (owner 2026-10-04: "bots still bunch / wall up" -- a wider clear angle, pushed harder)
                            if math.abs(dA) < 0.75 then bearing += ((dA >= 0) and 1 or -1) * (0.75 - math.abs(dA)) * 2.6 * tdt end
                        end
                    end
                end
                bearing += tdt * (ind.orb + 1.5 * flank * repoDir) -- its own orbit; fast while you're behind cover
                local pd = prefDist * (1 + ind.dj) * (1 - 0.55 * flank) -- and closes in
                if not R then
                    if now >= nextPush then
                        pushUntil = now + rng:NextNumber(1.8, 2.8)
                        nextPush = pushUntil + rng:NextNumber(5, 9) / math.max(0.5, skill.Freq)
                    end
                    if now < pushUntil then pd *= 0.7 end -- (0.67: 0.45 -> 0.7, the rush-in was half of the "all over the place")
                end
                local inSafe = not R and (pPos.Z < safeZ or (kv.lst ~= nil and kv.lst ~= 2)) -- (LINKED ROOMS pilot: idle = as if you were in the safe room)
                if inSafe then hasLos = false end -- no shooting into the safe zone
                local fp = ind.fp or pPos -- (the bot's own lagged idea of where you are)
                -- POSTS (owner 2026-10-04: "the bots tend to mirror your movement"): the anchor used to be glued to (a lagged
                -- copy of) you, so every strafe you made, the whole room made too. A bot now holds a spot in the WORLD,
                -- picked at its own range and angle around you, and only moves on when its timer runs out or you've got
                -- too far / too close -- its pattern still weaves around that spot.
                local want = Vector3.new(fp.X + math.cos(bearing) * pd, baseHeight, fp.Z + math.sin(bearing) * pd)
                if not R then
                    local post = ind.post
                    local d = post and Vector3.new(post.X - pPos.X, 0, post.Z - pPos.Z).Magnitude or 0
                    if not post or now >= (ind.postUntil or 0) or d > pd * 1.6 + 6 or d < pd * 0.45 then
                        ind.post = want
                        ind.postUntil = now + rng:NextNumber(2.2, 4.5)
                    end
                end
                -- (0.67, owner: "the bot movement feels all over the place ... very hard but FUN to shoot"): a new post used
                -- to move the anchor in one jump and the bot dashed after it. The anchor now GLIDES to the post (eased, at
                -- most ~8 studs/s), so a bot drifts to its new spot while its pattern plays on top -- smooth, readable lines.
                if not R and ind.post then
                    ind.ap = ind.ap or ind.post
                    local gd = (ind.post :: Vector3) - ind.ap
                    local gs = math.min(gd.Magnitude, math.max(2, gd.Magnitude * 1.5) * tdt, math.max(8, moveSpeed * 0.7) * tdt)
                    if gd.Magnitude > 1e-3 then ind.ap += gd.Unit * gs end
                end
                local anchor = R and Vector3.new(rangeAnchorX, baseHeight, rangeAnchorZ) or ((ind.ap or ind.post) :: Vector3)
                if inSafe then
                    if not wanderPt or now >= nextWander then
                        nextWander = now + rng:NextNumber(2.5, 5)
                        wanderPt = kv.lnk and DungeonGenerator.LinkWander(kv, rng, baseHeight) or Vector3.new(rng:NextNumber(minX + 10, maxX - 10), baseHeight, rng:NextNumber(minZ + 15, maxZ - 10))
                    end
                    anchor = wanderPt :: Vector3
                end
                -- (owner 2026-10-04: "bots still bunch / wall up") a spot round you that lies outside the arena -- you're
                -- in the doorway or by a wall -- was clamped onto the arena's edge, so every such bot stood on one straight
                -- line. Fold it back inside instead, each bot to its own depth.
                if not R and not inSafe then
                    local m = 6 + 10 * (0.5 + (ind.dj or 0))
                    local ax, az = anchor.X, anchor.Z
                    if az < minZ + 2 then az = minZ + m + (minZ - az) * 0.5 elseif az > maxZ - 2 then az = maxZ - m - (az - maxZ) * 0.5 end
                    if ax < minX + 2 then ax = minX + m + (minX - ax) * 0.5 elseif ax > maxX - 2 then ax = maxX - m - (ax - maxX) * 0.5 end
                    anchor = Vector3.new(math.clamp(ax, minX, maxX), anchor.Y, math.clamp(az, minZ, maxZ))
                end
                local toPlayer = Vector3.new(pPos.X - anchor.X, 0, pPos.Z - anchor.Z)
                local fwd = toPlayer.Magnitude > 0.1 and toPlayer.Unit or Vector3.new(0, 0, 1)
                local right = Vector3.yAxis:Cross(fwd)
                local pat = A.Pattern
                tdt *= kv.pace -- (HARD PACE: the pattern below runs at this bot's pace; undone after it)

                if kv.mv then
                    -- (BOT MOVEMENT POE: its brain moves it -- below, after the melee chase it also replaces)
                elseif pat == "Tracking" then
                    desired = anchor + right * (11 * math.sin(phase * 1.05)) + Vector3.yAxis * (4 * math.sin(phase * 0.73 + 1.3)) + fwd * (3 * math.sin(phase * 0.5))
                elseif pat == "Comet" then
                    -- smooth but very fast: two blended sweeps (never quite repeating) across a wide arc, gentle bob
                    -- (0.67, owner: "comets need a bit of a nerf": sweeps 16 + 8 -> 13 + 6 wide, 20% slower, a touch bigger body)
                    desired = anchor + right * (13 * math.sin(phase * 1.3) + 6 * math.sin(phase * 0.5 + 2)) + Vector3.yAxis * (4 * math.sin(phase * 0.9 + 1.3)) + fwd * (3 * math.sin(phase * 0.6))
                elseif pat == "GroundStrafe" then
                    -- on the floor, strafing across your view; jumps come from the brain
                    local lat, jump = brain.Step(tdt)
                    lateral = lat
                    if jump and jumpT < 0 then
                        jumpT = 0
                        jumpDur = 0.5 + rng:NextNumber() * 0.15
                        jumpH = (4 + rng:NextNumber() * 2.5) * (1 + chaos * 0.3)
                    end
                    local jy = 0
                    if jumpT >= 0 then
                        jumpT += tdt
                        if jumpT >= jumpDur then jumpT = -1 else jy = jumpH * math.sin(math.pi * jumpT / jumpDur) end
                    end
                    local groundAnchor = Vector3.new(anchor.X, groundRootY, anchor.Z)
                    desired = groundAnchor + right * lateral + Vector3.yAxis * jy
                elseif pat == "FastStrafe" then
                    lateral = brain.Step(tdt)
                    desired = anchor + right * lateral + Vector3.yAxis * (1.5 * math.sin(phase * 3))
                elseif pat == "SlowStrafe" then
                    lateral = brain.Step(tdt)
                    desired = anchor + right * lateral
                elseif pat == "Blink" then
                    if now >= nextBlink then
                        local holdMin = 0.75
                        nextBlink = now + rng:NextNumber(holdMin, holdMin + 0.7) / math.max(0.3, slowMult) / skill.Freq * DungeonGenerator.BLINK_SLOW
                        blinkOffset = right * rng:NextNumber(-14, 14) + Vector3.yAxis * rng:NextNumber(-3, 6)
                        local old = currentPos
                        local jump = DungeonGenerator.FindOpenSpot(Clamp(anchor + blinkOffset), radius + 0.5, config.Geo)
                        currentPos = jump
                        BlinkTell(old, jump)
                    end
                    desired = currentPos + Vector3.yAxis * (0.25 * math.sin(phase * 4)) * tdt
                elseif pat == "Bounce" then
                    -- (0.93, owner: "Shroomling bot (and other biome equivalents) are annoying to shoot"): the hops were
                    -- 5-9 studs tall, ~1 s, with a hard V at every landing and a 60% side flip -- jerky to track. Now
                    -- lower, longer hops on a smooth wave (no cusp at the bottom) and fewer side flips.
                    hopT += tdt * skill.Freq
                    if hopT >= hopDur then
                        hopT = 0
                        hopDur = rng:NextNumber(1.1, 1.6)
                        hopHeight = rng:NextNumber(3, 5.5)
                        latDir = (math.abs(lateral) > 10) and -math.sign(lateral) or ((rng:NextNumber() < 0.35) and -latDir or latDir)
                    end
                    lateral += latDir * moveSpeed * 0.55 * tdt
                    local y = hopHeight * 0.5 * (1 - math.cos(2 * math.pi * hopT / hopDur))
                    desired = Vector3.new(anchor.X, baseHeight - 3, anchor.Z) + right * lateral + Vector3.yAxis * y
                elseif pat == "Charge" then
                    -- (Update 6) STALK at CHARGE_STAND on its own bearing, drifting toward its post's bearing at <=
                    -- CHARGE_TURN rad/s; after a dive it RECOVERS in place, then backs straight out (see CHARGE_STAND)
                    local k = kv
                    local rel = Vector3.new(currentPos.X - pPos.X, 0, currentPos.Z - pPos.Z)
                    local post = Vector3.new(anchor.X - pPos.X, 0, anchor.Z - pPos.Z)
                    local tb = post.Magnitude > 0.5 and math.atan2(post.Z, post.X) or 0
                    local cb = rel.Magnitude > 0.5 and math.atan2(rel.Z, rel.X) or tb
                    local turn = DungeonGenerator.CHARGE_TURN * tdt
                    local b = cb + math.clamp((tb - cb + math.pi) % (2 * math.pi) - math.pi, -turn, turn)
                    local y = math.max(5, pPos.Y + 3) + 0.6 * math.sin(phase * 1.6)
                    if now < (k.recUntil or 0) then
                        desired = Vector3.new(currentPos.X, y - 0.8, currentPos.Z) -- winded: hangs still, sags a little
                    else
                        desired = Vector3.new(pPos.X + math.cos(b) * DungeonGenerator.CHARGE_STAND, y, pPos.Z + math.sin(b) * DungeonGenerator.CHARGE_STAND)
                    end
                    if inSafe then desired = anchor end
                elseif pat == "Peek" then
                    -- re-pick after each shot, or if it couldn't reach its spot in time (walls / arena edge)
                    if not peekSpot or (now >= aimingUntil and aimingUntil > 0) or (aimingUntil == 0 and now >= peekDeadline) then
                        local b = bearing + rng:NextNumber(-1.2, 1.2)
                        local raw = Vector3.new(pPos.X + math.cos(b) * prefDist, rng:NextNumber(16, 28), pPos.Z + math.sin(b) * prefDist)
                        peekSpot = DungeonGenerator.FindOpenSpot(Clamp(raw), radius + 0.5, config.Geo)
                        peekDeadline = math.max(now + 3.5, nextAttack + 1.0)
                        aimingUntil = 0
                    end
                    desired = (peekSpot :: Vector3) + Vector3.yAxis * (0.6 * math.sin(phase * 2))
                elseif pat == "Popcorn" then
                    -- KovaaK's "Popcorn": launch, hang at the top of the arc, drop, pop again somewhere else
                    local k = kv
                    if not k.popT or k.popT >= k.popDur then
                        k.popT = 0
                        k.popDur = rng:NextNumber(1.25, 1.7) / math.max(0.4, skill.Freq)
                        k.popH = rng:NextNumber(9, 15)
                        k.popFrom = k.popTo or 0
                        k.popTo = math.clamp(k.popFrom + rng:NextNumber(-13, 13), -16, 16)
                    end
                    k.popT += tdt
                    local u = math.clamp(k.popT / k.popDur, 0, 1)
                    local x = k.popFrom + (k.popTo - k.popFrom) * u
                    local y = k.popH * (math.sin(math.pi * u) ^ 0.55) -- flattened top: it hangs at the peak
                    desired = Vector3.new(anchor.X, math.max(4, baseHeight - 6), anchor.Z) + right * x + Vector3.yAxis * y
                elseif pat == "Pasu" then
                    -- KovaaK's "Pasu": straight lines inside an invisible box, bouncing off its walls
                    local k = kv
                    if not k.pp then
                        k.pp = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-3, 3), 0)
                        local a = rng:NextNumber(0, math.pi * 2)
                        k.pv = Vector3.new(math.cos(a), math.sin(a) * 0.55, rng:NextNumber(-0.25, 0.25)).Unit
                    end
                    local spd = math.max(10, moveSpeed) * 0.9
                    local p, v = k.pp + k.pv * spd * tdt, k.pv
                    local bx, by, bz = 15, 6.5, 5
                    if math.abs(p.X) > bx then v = Vector3.new(-v.X, v.Y + rng:NextNumber(-0.2, 0.2), v.Z).Unit; p = Vector3.new(math.clamp(p.X, -bx, bx), p.Y, p.Z) end
                    if math.abs(p.Y) > by then v = Vector3.new(v.X, -v.Y, v.Z).Unit; p = Vector3.new(p.X, math.clamp(p.Y, -by, by), p.Z) end
                    if math.abs(p.Z) > bz then v = Vector3.new(v.X, v.Y, -v.Z).Unit; p = Vector3.new(p.X, p.Y, math.clamp(p.Z, -bz, bz)) end
                    k.pp, k.pv = p, v
                    desired = anchor + right * p.X + Vector3.yAxis * p.Y + fwd * p.Z
                elseif pat == "Angelic" then
                    -- KovaaK's "Air Angelic": smooth figure-eights with sudden reversals
                    local k = kv
                    k.dir = k.dir or 1
                    k.nextRev = k.nextRev or (now + rng:NextNumber(1.5, 3))
                    if now >= k.nextRev then k.dir = -k.dir; k.nextRev = now + rng:NextNumber(1.2, 3.2) / math.max(0.4, TurnFreq(skill)) end
                    k.ang = (k.ang or 0) + tdt * k.dir * (1.1 + 0.45 * math.sin(now * 0.8)) * skill.Freq
                    local a = k.ang
                    desired = anchor + right * (13 * math.sin(a)) + Vector3.yAxis * (5 * math.sin(2 * a)) + fwd * (4 * math.cos(a))
                elseif pat == "Zigzag" then
                    -- KovaaK's "Thin Gauntlet": fast diagonal zig-zags, sharp corners
                    local k = kv
                    k.zx, k.zy = k.zx or 0, k.zy or 0
                    if not k.zNext or now >= k.zNext then
                        k.zNext = now + rng:NextNumber(0.6, 1.0) / math.max(0.4, TurnFreq(skill)) -- (0.62: was 0.32-0.6 / Freq)
                        k.zdx = (math.abs(k.zx) > 11) and -math.sign(k.zx) or ((rng:NextNumber() < 0.5) and -1 or 1)
                        k.zdy = (math.abs(k.zy) > 4) and -math.sign(k.zy) or ((rng:NextNumber() < 0.5) and -1 or 1)
                    end
                    local spd = math.max(12, moveSpeed) * 1.05
                    k.zx = math.clamp(k.zx + k.zdx * spd * 0.85 * tdt, -15, 15)
                    k.zy = math.clamp(k.zy + k.zdy * spd * 0.45 * tdt, -6, 6)
                    desired = anchor + right * k.zx + Vector3.yAxis * k.zy
                elseif pat == "Orbit" then
                    -- KovaaK's "Centering": circles you at a fixed distance, flipping direction now and then
                    -- (0.65, owner: "the one that circles you, its kind of broken": it ran full circles round your exact
                    -- position -- behind you, through cover, copying every step. Now it sweeps an ARC on its own side of you
                    -- (+-60 deg around its bearing), round a lagged copy of you, at a capped turn rate)
                    -- (0.67: wider arc, eased turns.) (0.74, owner: "Circlers shouldnt actually fully circle you, they
                    -- should just strafe back and forth IN FRONT of you"): no arc round you at all now -- long, smooth
                    -- side-to-side strafes across its spot in front of you (the slow strafers' brain, a wider lane), with
                    -- a gentle bob
                    lateral = brain and brain.Step(tdt) or lateral
                    desired = anchor + right * lateral + Vector3.yAxis * (2.5 * math.sin(phase * 1.3))
                    if inSafe then desired = anchor end
                elseif pat == "Leap" then
                    -- KovaaK's "Leaptrack": strafes on the floor, then takes long arcing leaps
                    local k = kv
                    k.sd = k.sd or 1
                    if not k.leap and now >= (k.nextLeap or (now + 1.5)) then
                        local to = math.clamp(lateral + ((rng:NextNumber() < 0.5) and -1 or 1) * rng:NextNumber(10, 16), -18, 18)
                        k.leap = { t = 0, dur = rng:NextNumber(0.75, 1.0), from = lateral, to = to, h = rng:NextNumber(6, 9) }
                    end
                    if not k.nextLeap then k.nextLeap = now + rng:NextNumber(1.2, 2.5) end
                    local jy = 0
                    if k.leap then
                        k.leap.t += tdt
                        local u = math.clamp(k.leap.t / k.leap.dur, 0, 1)
                        lateral = k.leap.from + (k.leap.to - k.leap.from) * u
                        jy = k.leap.h * math.sin(math.pi * u)
                        if u >= 1 then k.leap = nil; k.nextLeap = now + rng:NextNumber(1.6, 3.2) / math.max(0.4, skill.Freq) end
                    else
                        if not k.sFlip or now >= k.sFlip or math.abs(lateral) > 14 then
                            k.sd = (math.abs(lateral) > 14) and -math.sign(lateral) or -k.sd
                            k.sFlip = now + rng:NextNumber(0.6, 1.4)
                        end
                        lateral += k.sd * moveSpeed * 0.8 * tdt
                    end
                    kv.leaping = k.leap ~= nil
                    desired = Vector3.new(anchor.X, groundRootY, anchor.Z) + right * lateral + Vector3.yAxis * jy
                elseif pat == "Thunderhead" then
                    -- STORMSPIRE Stormcaller: drifts high and slow, then STRIKE-DIVES -- a sharp drop, a beat at the
                    -- bottom, a slower climb back (a vertical flick target)
                    local k = kv
                    k.td = k.td or 1
                    if not k.tFlip or now >= k.tFlip or math.abs(lateral) > 14 then
                        k.td = (math.abs(lateral) > 14) and -math.sign(lateral) or -k.td
                        k.tFlip = now + rng:NextNumber(1.4, 2.6)
                    end
                    lateral += k.td * moveSpeed * 0.45 * tdt
                    if not k.nextDive then k.nextDive = now + rng:NextNumber(2, 3.5) end
                    if not k.dive and now >= k.nextDive then k.dive = 0 end
                    local dy = 0
                    if k.dive then
                        k.dive += tdt * skill.Freq
                        local d = k.dive
                        if d < 0.28 then dy = -11 * (d / 0.28) ^ 1.6
                        elseif d < 0.55 then dy = -11
                        elseif d < 1.35 then dy = -11 * (1 - (d - 0.55) / 0.8)
                        else k.dive = nil; k.nextDive = now + rng:NextNumber(2.2, 3.8) / math.max(0.4, skill.Freq) end
                    end
                    desired = anchor + right * lateral + Vector3.yAxis * (5 + dy + 0.8 * math.sin(phase * 1.7))
                elseif pat == "Gust" then
                    -- STORMSPIRE Gale: long gliding sweeps that ease in and out, a short hover, the next sweep at a new height
                    local k = kv
                    if not k.g or k.g.t >= k.g.dur + k.g.hold then
                        local from = k.g and k.g.to or 0
                        local to = math.clamp(from + ((rng:NextNumber() < 0.5) and -1 or 1) * rng:NextNumber(14, 24), -20, 20)
                        if math.abs(to - from) < 10 then to = (from > 0) and -16 or 16 end
                        k.g = { t = 0, dur = math.abs(to - from) / math.max(10, moveSpeed) * 1.4, hold = rng:NextNumber(0.35, 0.7) / math.max(0.4, TurnFreq(skill)),
                            from = from, to = to, y0 = k.g and k.g.y1 or 0, y1 = rng:NextNumber(-3, 5) }
                    end
                    k.g.t += tdt
                    local u = math.clamp(k.g.t / k.g.dur, 0, 1)
                    local e = u * u * (3 - 2 * u) -- (smoothstep: eases in and out)
                    desired = anchor + right * (k.g.from + (k.g.to - k.g.from) * e) + Vector3.yAxis * (k.g.y0 + (k.g.y1 - k.g.y0) * e)
                elseif pat == "Ricochet" then
                    -- STORMSPIRE Spark: pings around a WIDE box in straight lines (much bigger and faster than Pasu)
                    local k = kv
                    if not k.rp then
                        k.rp = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-3, 3), 0)
                        local a = rng:NextNumber(0, math.pi * 2)
                        k.rv = Vector3.new(math.cos(a), math.sin(a) * 0.4, rng:NextNumber(-0.3, 0.3)).Unit
                    end
                    local spd = math.max(14, moveSpeed) * 1.05
                    local p, v = k.rp + k.rv * spd * tdt, k.rv
                    local bx, by, bz = 24, 7, 9
                    if math.abs(p.X) > bx then v = Vector3.new(-v.X, v.Y, v.Z); p = Vector3.new(math.clamp(p.X, -bx, bx), p.Y, p.Z) end
                    if math.abs(p.Y) > by then v = Vector3.new(v.X, -v.Y, v.Z); p = Vector3.new(p.X, math.clamp(p.Y, -by, by), p.Z) end
                    if math.abs(p.Z) > bz then v = Vector3.new(v.X, v.Y, -v.Z); p = Vector3.new(p.X, p.Y, math.clamp(p.Z, -bz, bz)) end
                    k.rp, k.rv = p, v.Unit
                    desired = anchor + right * p.X + Vector3.yAxis * p.Y + fwd * p.Z
                elseif pat == "ArcStep" then
                    -- STORMSPIRE Arcwalker: strafes on the floor, then ARC-STEPS -- vanishes into a lightning streak and is
                    -- simply there, 9-15 studs to the side
                    local k = kv
                    k.sd = k.sd or 1
                    if not k.sFlip or now >= k.sFlip or math.abs(lateral) > 16 then
                        k.sd = (math.abs(lateral) > 16) and -math.sign(lateral) or -k.sd
                        k.sFlip = now + rng:NextNumber(0.5, 1.2)
                    end
                    lateral += k.sd * moveSpeed * 0.75 * tdt
                    if not k.nextArc then k.nextArc = now + rng:NextNumber(1.4, 2.4) end
                    if now >= k.nextArc then
                        k.nextArc = now + rng:NextNumber(1.6, 2.8) / math.max(0.4, skill.Freq)
                        local from = Vector3.new(anchor.X, groundRootY, anchor.Z) + right * lateral
                        lateral = math.clamp(lateral + ((lateral > 0) and -1 or 1) * rng:NextNumber(9, 15), -18, 18)
                        local to = Vector3.new(anchor.X, groundRootY, anchor.Z) + right * lateral
                        if (to - from).Magnitude > 1 then
                            local bolt = Instance.new("Part")
                            bolt.Name = "ArcStreak"; bolt.Anchored = true; bolt.CanCollide = false; bolt.CanQuery = false; bolt.CanTouch = false
                            bolt.CastShadow = false; bolt.Material = Enum.Material.Neon; bolt.Color = A.Color
                            bolt.Size = Vector3.new(0.35, 0.35, (to - from).Magnitude)
                            bolt.CFrame = CFrame.lookAt((from + to) / 2, to)
                            bolt.Parent = FxParent(config)
                            Debris:AddItem(bolt, 0.18)
                        end
                        currentPos = to
                    end
                    desired = Vector3.new(anchor.X, groundRootY, anchor.Z) + right * lateral
                elseif pat == "Corkscrew" then
                    -- MOLTEN Cinder: climbs in a tight helix like a rising ember, then gutters -- plunges to the bottom -- and
                    -- climbs again (spiral tracking with a fast vertical flick)
                    local k = kv
                    k.ca = (k.ca or rng:NextNumber(0, 6.3)) + tdt * 2.6 * skill.Freq
                    k.cy = k.cy or -3
                    if k.plunge then
                        k.cy -= tdt * 26
                        if k.cy <= -3 then k.cy = -3; k.plunge = nil end
                    else
                        k.cy += tdt * (3.0 + 0.8 * skill.Freq)
                        if k.cy >= 8 then k.plunge = true end
                    end
                    desired = anchor + right * (math.cos(k.ca) * 7) + fwd * (math.sin(k.ca) * 4) + Vector3.yAxis * k.cy
                elseif pat == "Flap" then
                    -- MOLTEN Ashwing: a sharp wingbeat up, then a long glide down and across (a sawtooth to track)
                    local k = kv
                    k.fd = k.fd or 1
                    if not k.fc or k.ft >= k.fc then
                        k.fc = rng:NextNumber(1.0, 1.35) / math.max(0.4, TurnFreq(skill))
                        k.ft = 0
                        if math.abs(lateral) > 15 then k.fd = -math.sign(lateral) elseif rng:NextNumber() < 0.3 then k.fd = -k.fd end
                    end
                    k.ft += tdt
                    local flapT = 0.22
                    local y
                    if k.ft < flapT then y = 4.5 * (1 - (1 - k.ft / flapT) ^ 2) else y = 4.5 * (1 - (k.ft - flapT) / math.max(0.1, k.fc - flapT)) end
                    lateral = math.clamp(lateral + k.fd * moveSpeed * ((k.ft < flapT) and 0.3 or 0.85) * tdt, -18, 18)
                    desired = anchor + right * lateral + Vector3.yAxis * (y - 1)
                elseif pat == "Burrow" then
                    -- MOLTEN Magmaw: strafes on the floor, then DIVES into it -- a glowing crack races along the ground to the
                    -- spot where it bursts back out (pre-aim the crack)
                    local k = kv
                    k.sd = k.sd or 1
                    k.bs = k.bs or "Up"
                    k.bUntil = k.bUntil or (now + rng:NextNumber(2, 3.2))
                    local sink = bodySize.Y * 0.95
                    if k.bs == "Up" then
                        if not k.sFlip or now >= k.sFlip or math.abs(lateral) > 15 then
                            k.sd = (math.abs(lateral) > 15) and -math.sign(lateral) or -k.sd
                            k.sFlip = now + rng:NextNumber(0.6, 1.3)
                        end
                        lateral += k.sd * moveSpeed * 0.7 * tdt
                        k.depth = math.max(0, (k.depth or 0) - tdt * sink / 0.25)
                        if k.depth <= 0 and now >= k.bUntil then k.bs = "Sink"; k.bUntil = now + 0.35 end
                        desired = Vector3.new(anchor.X, groundRootY - k.depth, anchor.Z) + right * lateral
                    elseif k.bs == "Sink" then
                        k.depth = math.min(sink, (k.depth or 0) + tdt * sink / 0.35)
                        FadeBot(1 - 0.6 * k.depth / sink, true)
                        if now >= k.bUntil then
                            local dur = rng:NextNumber(0.8, 1.1) / math.max(0.6, skill.Freq)
                            k.bs, k.bUntil, k.bDur = "Under", now + dur, dur
                            local to = math.clamp(lateral + ((lateral > 0) and -1 or 1) * rng:NextNumber(10, 18), -18, 18)
                            k.bFrom = Vector3.new(currentPos.X, 0, currentPos.Z)
                            local spot = DungeonGenerator.FindOpenSpot(Clamp(Vector3.new(anchor.X, groundRootY, anchor.Z) + right * to), radius + 0.5, config.Geo)
                            k.bTo = Vector3.new(spot.X, 0, spot.Z)
                            FadeBot(0, false)
                            -- where it will burst out: a glowing crack on the floor
                            FxPart({ Name = "MagmaCrack", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, radius * 2.6, radius * 2.6),
                                CFrame = CFrame.new(k.bTo.X, 2.08, k.bTo.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 120, 30), Transparency = 0.25 }, dur + 0.25)
                            k.trail = FxPart({ Name = "MagmaTrail", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, radius * 1.4, radius * 1.4),
                                CFrame = CFrame.new(k.bFrom.X, 2.1, k.bFrom.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 190, 80), Transparency = 0.1 }, dur + 0.1)
                        end
                        desired = Vector3.new(currentPos.X, groundRootY - k.depth, currentPos.Z)
                    else -- Under: invisible and untouchable, the crack racing along the floor
                        local u = math.clamp(1 - (k.bUntil - now) / k.bDur, 0, 1)
                        local at = k.bFrom:Lerp(k.bTo, u * u * (3 - 2 * u))
                        if k.trail and k.trail.Parent then k.trail.CFrame = CFrame.new(at.X, 2.1, at.Z) * CFrame.Angles(0, 0, math.rad(90)) end
                        currentPos = Vector3.new(at.X, groundRootY - sink, at.Z)
                        desired = currentPos
                        if now >= k.bUntil then
                            k.bs = "Up"
                            k.bUntil = now + rng:NextNumber(2.2, 3.5) / math.max(0.4, skill.Freq)
                            local flat = Vector3.new(at.X - anchor.X, 0, at.Z - anchor.Z)
                            lateral = flat:Dot(right)
                            FadeBot(1, true)
                            FxPart({ Name = "MagmaBurst", Shape = Enum.PartType.Ball, Size = Vector3.new(radius * 3, radius * 3, radius * 3),
                                CFrame = CFrame.new(at.X, 2.5, at.Z), Color = Color3.fromRGB(255, 150, 50), Transparency = 0.35 }, 0.18)
                        end
                    end
                    k.noAttack = k.bs ~= "Up"
                    kv.lowY = ((k.depth or 0) > 0.01) and (groundRootY - sink - 0.5) or nil
                elseif pat == "Skate" then
                    -- CRYO Shardling: skates on the air like ice -- pushes toward a new spot but can't stop, overshooting and
                    -- curving back (tracking with momentum)
                    local k = kv
                    k.sp = k.sp or Vector3.zero
                    k.sv = k.sv or Vector3.zero
                    if not k.sGoal or now >= k.sNext then
                        k.sGoal = Vector3.new(rng:NextNumber(-16, 16), rng:NextNumber(-4, 5), 0)
                        k.sNext = now + rng:NextNumber(0.9, 1.5) / math.max(0.4, skill.Freq)
                    end
                    local to = k.sGoal - k.sp
                    local spd = math.max(12, moveSpeed)
                    if to.Magnitude > 0.5 then k.sv += to.Unit * spd * 2.2 * tdt end
                    k.sv *= (1 - math.min(1, 0.55 * tdt)) -- (barely any friction: it glides past)
                    if k.sv.Magnitude > spd * 1.15 then k.sv = k.sv.Unit * spd * 1.15 end
                    k.sp += k.sv * tdt
                    if math.abs(k.sp.X) > 20 then k.sv = Vector3.new(-k.sv.X * 0.6, k.sv.Y, 0); k.sp = Vector3.new(math.clamp(k.sp.X, -20, 20), k.sp.Y, 0) end
                    if math.abs(k.sp.Y) > 6 then k.sv = Vector3.new(k.sv.X, -k.sv.Y * 0.6, 0); k.sp = Vector3.new(k.sp.X, math.clamp(k.sp.Y, -6, 6), 0) end
                    desired = anchor + right * k.sp.X + Vector3.yAxis * k.sp.Y
                elseif pat == "Stutter" then
                    -- CRYO Frostbite: strafes, then FREEZES dead still in a shell of frost -- then bursts off at double speed
                    local k = kv
                    k.sd = k.sd or 1
                    k.st = k.st or "Move"
                    k.sUntil = k.sUntil or (now + rng:NextNumber(0.9, 1.5))
                    if now >= k.sUntil then
                        if k.st == "Move" then
                            k.st = "Freeze"
                            local hold = rng:NextNumber(0.5, 0.85)
                            k.sUntil = now + hold
                            k.frz = currentPos
                            FxPart({ Name = "FrostShell", Size = bodySize * 1.25 + Vector3.new(0, legH, 0), CFrame = CFrame.new(currentPos - Vector3.new(0, legH * 0.5, 0)),
                                Color = Color3.fromRGB(190, 235, 255), Material = Enum.Material.Ice, Transparency = 0.45 }, hold)
                        elseif k.st == "Freeze" then
                            k.st = "Burst"
                            k.sUntil = now + 0.35
                            local flat = Vector3.new(currentPos.X - anchor.X, 0, currentPos.Z - anchor.Z)
                            lateral = flat:Dot(right)
                            k.sd = (math.abs(lateral) > 10) and -math.sign(lateral) or ((rng:NextNumber() < 0.5) and -1 or 1)
                        else
                            k.st = "Move"
                            k.sUntil = now + rng:NextNumber(0.9, 1.6) / math.max(0.4, skill.Freq)
                        end
                    end
                    if k.st == "Freeze" then
                        desired = k.frz
                    else
                        if k.st == "Move" and (not k.sFlip or now >= k.sFlip or math.abs(lateral) > 16) then
                            k.sd = (math.abs(lateral) > 16) and -math.sign(lateral) or -k.sd
                            k.sFlip = now + rng:NextNumber(0.6, 1.2)
                        end
                        lateral = math.clamp(lateral + k.sd * moveSpeed * ((k.st == "Burst") and 2.2 or 0.7) * tdt, -18, 18)
                        desired = Vector3.new(anchor.X, groundRootY, anchor.Z) + right * lateral
                    end
                elseif pat == "Leaf" then
                    -- CRYO Flurry: drifts down like a falling snowflake, swaying (and lifting at the end of each sway), then
                    -- whirls back up to the top in one quick rush
                    local k = kv
                    k.ly = k.ly or 7
                    k.lx0 = k.lx0 or 0
                    k.la = (k.la or rng:NextNumber(0, 6.3)) + tdt * 1.9 * skill.Freq
                    if k.rise then
                        k.ly += tdt * 20
                        if k.ly >= 7 then k.ly = 7; k.rise = nil; k.lx0 = rng:NextNumber(-8, 8) end
                    else
                        k.ly -= tdt * (2.4 + 0.5 * skill.Freq)
                        if k.ly <= -3 then k.rise = true end
                    end
                    local sw = math.sin(k.la)
                    desired = anchor + right * (k.lx0 + 10 * sw) + Vector3.yAxis * (k.ly + 1.4 * sw * sw)
                elseif pat == "Phase" then
                    -- VOID Phasewing: drifts in slow loops, flickers, then PHASES OUT -- see-through and untouchable -- while
                    -- it slides somewhere new; solid again when it arrives
                    local k = kv
                    k.pa = (k.pa or 0) + tdt * 1.1 * skill.Freq
                    k.po = k.po or Vector3.zero
                    k.ps = k.ps or "Solid"
                    k.pUntil = k.pUntil or (now + rng:NextNumber(1.4, 2.2) * DungeonGenerator.BLINK_SLOW)
                    if now >= k.pUntil then
                        if k.ps == "Solid" then
                            k.ps, k.pUntil = "Flicker", now + 0.3
                        elseif k.ps == "Flicker" then
                            k.ps = "Phased"
                            k.pT0, k.pUntil = now, now + rng:NextNumber(0.55, 0.8)
                            k.pFrom = k.po
                            local tx = (k.po.X > 0) and rng:NextNumber(-15, -3) or rng:NextNumber(3, 15)
                            k.pTo = Vector3.new(tx, rng:NextNumber(-3, 5), 0)
                            FadeBot(0.2, false)
                        else
                            k.ps, k.pUntil = "Solid", now + rng:NextNumber(1.3, 2.2) / math.max(0.4, skill.Freq) * DungeonGenerator.BLINK_SLOW
                            FadeBot(1, true)
                        end
                    end
                    if k.ps == "Flicker" then FadeBot((math.floor(now * 20) % 2 == 0) and 0.4 or 1, true) end
                    if k.ps == "Phased" then
                        local u = math.clamp((now - k.pT0) / (k.pUntil - k.pT0), 0, 1)
                        k.po = k.pFrom:Lerp(k.pTo, u * u * (3 - 2 * u))
                    end
                    k.noAttack = k.ps ~= "Solid"
                    desired = anchor + right * (k.po.X + 3 * math.sin(k.pa)) + Vector3.yAxis * (k.po.Y + 1.5 * math.sin(k.pa * 2))
                elseif pat == "Mirror" then
                    -- VOID Mirrorshade: your reflection -- it strafes the OPPOSITE way to you (crossing your screen twice as
                    -- fast); stand still and it drifts on its own
                    local k = kv
                    local v = targetHrp.AssemblyLinearVelocity
                    local vlat = v.X * right.X + v.Z * right.Z
                    k.sd = k.sd or 1
                    if math.abs(vlat) > 3 then
                        lateral -= vlat * 1.6 * tdt
                    else
                        if not k.sFlip or now >= k.sFlip then k.sd = -k.sd; k.sFlip = now + rng:NextNumber(0.8, 1.6) end
                        lateral += k.sd * moveSpeed * 0.5 * tdt
                    end
                    lateral = math.clamp(lateral * (1 - math.min(1, 0.25 * tdt)), -18, 18)
                    desired = Vector3.new(anchor.X, groundRootY, anchor.Z) + right * lateral
                elseif pat == "Constellation" then
                    -- VOID Riftling: hops between the same four stars, always in the same order -- a streak of void, a pause on
                    -- each (learn the shape, pre-aim the next star)
                    local k = kv
                    if not k.stars then
                        k.stars = {}
                        local a0 = rng:NextNumber(0, math.pi * 2)
                        for i = 1, 4 do
                            local a = a0 + (i - 1) * math.pi / 2 + rng:NextNumber(-0.35, 0.35)
                            table.insert(k.stars, Vector3.new(math.cos(a) * rng:NextNumber(9, 14), math.sin(a) * rng:NextNumber(3.5, 6), 0))
                        end
                        k.si, k.sNext = 1, now + 0.8
                    end
                    if now >= k.sNext then
                        k.si = k.si % #k.stars + 1
                        local s = k.stars[k.si]
                        local to = DungeonGenerator.FindOpenSpot(Clamp(anchor + right * s.X + Vector3.yAxis * s.Y), radius + 0.5, config.Geo)
                        local from = currentPos
                        if (to - from).Magnitude > 1 then
                            FxPart({ Name = "RiftStreak", Size = Vector3.new(0.3, 0.3, (to - from).Magnitude), CFrame = CFrame.lookAt((from + to) / 2, to), Color = A.Color, Transparency = 0.2 }, 0.2)
                        end
                        currentPos = to
                        k.sNext = now + rng:NextNumber(0.55, 0.85) / math.max(0.4, skill.Freq)
                    end
                    local s = k.stars[k.si]
                    desired = anchor + right * s.X + Vector3.yAxis * (s.Y + 0.3 * math.sin(phase * 3))
                elseif pat == "Raster" then
                    -- CYBER Raster: only straight lines along a grid -- across, then up or down -- turning in hard right angles
                    local k = kv
                    k.rx, k.ry = k.rx or 0, k.ry or 0
                    if not k.rNext or now >= k.rNext then
                        if k.rAxis == "X" then
                            k.rAxis = "Y"
                            k.rd = (math.abs(k.ry) > 3) and -math.sign(k.ry) or ((rng:NextNumber() < 0.5) and -1 or 1)
                            k.rNext = now + rng:NextNumber(0.3, 0.5) / math.max(0.4, TurnFreq(skill))
                        else
                            k.rAxis = "X"
                            k.rd = (math.abs(k.rx) > 11) and -math.sign(k.rx) or ((rng:NextNumber() < 0.5) and -1 or 1)
                            k.rNext = now + rng:NextNumber(0.7, 1.2) / math.max(0.4, TurnFreq(skill)) -- (0.62: was 0.35-0.75)
                        end
                    end
                    local spd = math.max(12, moveSpeed)
                    if k.rAxis == "X" then k.rx = math.clamp(k.rx + k.rd * spd * tdt, -18, 18) else k.ry = math.clamp(k.ry + k.rd * spd * 0.75 * tdt, -5, 6) end
                    desired = anchor + right * k.rx + Vector3.yAxis * k.ry
                elseif pat == "Afterimage" then
                    -- CYBER Tracer: drifts, then DASHES 10-14 studs in a blink, leaving a fading hologram where it stood
                    local k = kv
                    k.sd = k.sd or 1
                    if not k.aFlip or now >= k.aFlip then k.sd = -k.sd; k.aFlip = now + rng:NextNumber(0.7, 1.4) end
                    if math.abs(lateral) > 16 then k.sd = -math.sign(lateral) end
                    k.aNext = k.aNext or (now + rng:NextNumber(1.2, 2.0) * DungeonGenerator.BLINK_SLOW)
                    if k.dash then
                        local u = math.clamp((now - k.dash.t0) / 0.14, 0, 1)
                        lateral = k.dash.from + (k.dash.to - k.dash.from) * u
                        if u >= 1 then k.dash = nil end
                    else
                        lateral += k.sd * moveSpeed * 0.45 * tdt
                        if now >= k.aNext then
                            k.aNext = now + rng:NextNumber(1.3, 2.3) / math.max(0.4, skill.Freq) * DungeonGenerator.BLINK_SLOW
                            k.dash = { t0 = now, from = lateral, to = math.clamp(lateral + ((lateral > 0) and -1 or 1) * rng:NextNumber(10, 14), -18, 18) }
                            for _, n in ipairs({ "Torso", "Head" }) do
                                local src = model:FindFirstChild(n)
                                if src and src:IsA("BasePart") then
                                    local g = FxPart({ Name = "Hologram", Shape = src.Shape, Size = src.Size, CFrame = src.CFrame, Color = A.Color, Transparency = 0.5 }, 0.75)
                                    TweenService:Create(g, TweenInfo.new(0.7), { Transparency = 1 }):Play()
                                end
                            end
                        end
                    end
                    desired = Vector3.new(anchor.X, groundRootY, anchor.Z) + right * lateral
                    if k.dash then currentPos = DungeonGenerator.SteerStep(currentPos, Vector3.new(desired.X, currentPos.Y, desired.Z), 8, radius, config.Geo, true) end -- (never through walls)
                elseif pat == "Roll" then
                    -- MOLTEN Slagroller: rolls LOW along the floor in fast curves, then halts to cool (free shots), then rolls on
                    local k = kv
                    k.rd = k.rd or ((rng:NextNumber() < 0.5) and -1 or 1)
                    k.rUntil = k.rUntil or (now + rng:NextNumber(0.9, 1.5))
                    if now >= k.rUntil then
                        k.halt = not k.halt
                        if k.halt then
                            k.rUntil = now + rng:NextNumber(0.45, 0.8)
                        else
                            k.rUntil = now + rng:NextNumber(0.9, 1.5) / math.max(0.4, skill.Freq)
                            k.rd = (math.abs(lateral) > 12) and -math.sign(lateral) or ((rng:NextNumber() < 0.6) and -k.rd or k.rd)
                        end
                    end
                    if not k.halt then lateral = math.clamp(lateral + k.rd * moveSpeed * 1.5 * tdt, -18, 18) end
                    local arc = 5 * math.sin(lateral / 6)
                    desired = Vector3.new(anchor.X, groundRootY + 0.6, anchor.Z) + right * lateral + fwd * arc
                elseif pat == "Serpent" then
                    -- CRYO Rimewyrm: slides across the room while weaving up and down in a tight wave
                    local k = kv
                    k.sd = k.sd or ((rng:NextNumber() < 0.5) and -1 or 1)
                    if math.abs(lateral) > 15 then k.sd = -math.sign(lateral) end
                    lateral += k.sd * moveSpeed * 0.65 * tdt
                    k.sw = (k.sw or rng:NextNumber(0, 6.3)) + tdt * 4.2 * skill.Freq
                    desired = anchor + right * lateral + Vector3.yAxis * (2 + 3.2 * math.sin(k.sw)) + fwd * (1.5 * math.cos(k.sw * 0.5))
                elseif pat == "Antipode" then
                    -- VOID Antipode: sweeps an ARC on its own side of you, then FLIPS to the mirrored point of that arc (a
                    -- flicker first). (Owner after 0.92: "a weird bot that circles you way too fast": it ran full circles
                    -- round you at ~55-70 deg/s on Singularity and flipped to the far side, behind you. Now the Orbiter's
                    -- 0.67 rules: +-0.8 rad round its home bearing, <= ~0.47 rad/s, eased reversals; the flip mirrors across
                    -- the home bearing, so it never lands behind you.)
                    local k = kv
                    local fp0 = ind.fp or pPos
                    if not k.home then
                        local rel = currentPos - fp0
                        k.home = math.atan2(rel.Z, rel.X)
                        k.oa = k.home + rng:NextNumber(-0.4, 0.4)
                        k.od = (rng:NextNumber() < 0.5) and -1 or 1
                        k.ow = 0
                    end
                    local off = k.oa - k.home
                    if math.abs(off) > 0.7 then k.od = -math.sign(off) end
                    k.ow += math.clamp(k.od * (0.3 + 0.12 * skill.Freq) - k.ow, -0.6 * tdt, 0.6 * tdt)
                    k.oa += k.ow * tdt
                    k.flipAt = k.flipAt or (now + rng:NextNumber(1.8, 2.8) * DungeonGenerator.BLINK_SLOW)
                    local d = math.clamp(prefDist, 18, 30)
                    if now >= k.flipAt - 0.3 and not k.warned then
                        k.warned = true
                        FadeBot(0.4, true)
                    end
                    if now >= k.flipAt then
                        k.flipAt = now + rng:NextNumber(1.8, 2.8) / math.max(0.4, skill.Freq) * DungeonGenerator.BLINK_SLOW
                        k.warned = nil
                        FadeBot(1, true)
                        local old = currentPos
                        off = k.oa - k.home
                        k.oa = k.home - ((math.abs(off) < 0.35) and ((off >= 0) and 0.6 or -0.6) or off)
                        k.ow, k.od = -k.ow, -k.od
                        local to = DungeonGenerator.FindOpenSpot(Clamp(Vector3.new(fp0.X + math.cos(k.oa) * d, baseHeight, fp0.Z + math.sin(k.oa) * d)), radius + 0.5, config.Geo)
                        currentPos = to
                        BlinkTell(old, to)
                    end
                    desired = Vector3.new(fp0.X + math.cos(k.oa) * d, baseHeight + 1.5 * math.sin(phase * 1.7), fp0.Z + math.sin(k.oa) * d)
                elseif pat == "Glitch" then
                    -- CYBER Glitch: drifts in a slow strafe, but SNAPS a few studs at a time several times a second
                    local k = kv
                    k.sd = k.sd or 1
                    if not k.gFlip or now >= k.gFlip or math.abs(lateral) > 15 then
                        k.sd = (math.abs(lateral) > 15) and -math.sign(lateral) or -k.sd
                        k.gFlip = now + rng:NextNumber(0.9, 1.8)
                    end
                    lateral += k.sd * moveSpeed * 0.5 * tdt
                    k.go = k.go or Vector3.zero
                    if not k.gNext or now >= k.gNext then
                        k.gNext = now + rng:NextNumber(0.14, 0.32) / math.max(0.5, skill.Freq) * DungeonGenerator.BLINK_SLOW
                        local new = right * rng:NextNumber(-3.5, 3.5) + Vector3.yAxis * rng:NextNumber(-2, 2.5)
                        currentPos += (new - k.go) -- a hard snap, not a slide
                        k.go = new
                    end
                    desired = anchor + right * lateral + k.go
                elseif pat == "Pendulum" then
                    -- CYBER Uplink: hangs off a data tether and SWINGS -- fastest at the bottom, hanging still at each end; the
                    -- swing turns slowly toward and away from you
                    local k = kv
                    -- (0.82, owner: "nerf the satellite a bit more. Its still really annoying to shoot"): the swing was 1.05 rad
                    -- at 1.5 -> ~19 studs/s through the bottom; now 0.7 rad at 1.0 -> ~8 studs/s, a slower turn, a bigger body
                    k.pw = (k.pw or rng:NextNumber(0, 6.3)) + tdt * 1.0 * skill.Freq -- (0.78: 2.2 -> 1.5; 0.82: -> 1.0)
                    k.pp = (k.pp or 0) + tdt * 0.2
                    local th = 0.7 * math.sin(k.pw)
                    local tilt = 0.6 * math.sin(k.pp)
                    local plane = right * math.cos(tilt) + fwd * math.sin(tilt)
                    local pivot = anchor + Vector3.yAxis * 9
                    k.tetherPivot = pivot
                    desired = pivot + plane * (math.sin(th) * 12) - Vector3.yAxis * (math.cos(th) * 12)
                end
                tdt /= kv.pace

                if A.Melee and A.Pattern ~= "Charge" and not kv.mv then -- (Update 6: the Charger has its own stalk / dive / recover)
                    -- melee bruisers: run you down and stop at arm's length, weaving a little so they're not trivial to track
                    local toP = Vector3.new(pPos.X - currentPos.X, 0, pPos.Z - currentPos.Z)
                    local dirP = toP.Magnitude > 0.1 and toP.Unit or fwd
                    local side = Vector3.yAxis:Cross(dirP)
                    local stop = pPos - dirP * (radius + ((now < backoffUntil) and 10 or 2)) -- (no slot: hang back, circling)
                    local y = isGround and groundRootY or math.max(4, pPos.Y + 0.5)
                    -- wide, irregular weave on the approach, tightening as it closes in
                    local weave = meleeBrain and meleeBrain.Step(tdt) or (3 * math.sin(phase * 3))
                    desired = Vector3.new(stop.X, y, stop.Z) + side * weave * math.clamp(toP.Magnitude / 16, 0.4, 1)
                    if inSafe then desired = anchor end
                end
                if kv.mv then
                    -- (BOT MOVEMENT POE) the brain: plants through any wind-up (+ the volley just after it), a dive, a stagger
                    local ae = kv.atkEnd
                    local c = kv.mvc
                    c.Now, c.Dt, c.Pos, c.Target, c.Slow = now, tdt, currentPos, pPos, slowMult
                    -- (MOVEMENT ROUND 2) the ranged wind-up's plant is the brain's call now (c.AtkEnd / c.SrvNow: a gunner walks through the
                    -- start of its wind-up and plants for the end of it; marksmen / casters plant for all of it)
                    c.Plant = now < holdUntil or kv.dashPlan ~= nil or dashTo ~= nil or kv.stag == true
                    c.AtkEnd, c.SrvNow = ae, Workspace:GetServerTimeNow()
                    c.Dash, c.Recover, c.Safe, c.Wander, c.Los, c.AtkIn = dashTo ~= nil, now < (kv.recUntil or 0), inSafe, inSafe and anchor or nil, hasLos, nextAttack - now
                    desired = DungeonGenerator.BotMove.Step(kv.mv, c)
                end
                inSafeNow = inSafe
                if now < holdUntil and not kv.mv then desired = currentPos end -- winding up an attack: stand your ground (a brain brakes itself)
                -- (ENEMY ATTACKS PILOT) STAGGERED (a cancelled charge, a broken shell): it reels in place, no attacks (see Attacks)
                local stagU = kv.stagU
                kv.stag = type(stagU) == "number" and stagU > Workspace:GetServerTimeNow()
                if kv.stag then desired = currentPos end
                -- (ENEMY ATTACKS PILOT elite mod SKITTISH) hit -> it blinks a few studs aside (at most once every SKIT_CD s)
                if mods.Skittish then
                    local hNow = model:GetAttribute("Health")
                    if type(hNow) == "number" and type(kv.skH) == "number" and hNow < kv.skH - 0.01 and now >= (kv.skAt or 0) and not dashTo then
                        kv.skAt = now + BotRoles.SKIT_CD
                        local old = currentPos
                        local side = (rng:NextNumber() < 0.5) and -1 or 1
                        local to = DungeonGenerator.FindOpenSpot(Clamp(currentPos + right * side * rng:NextNumber(BotRoles.SKIT_DIST[1], BotRoles.SKIT_DIST[2])), radius + 0.5, config.Geo)
                        FadeBot(0.35, true)
                        task.delay(0.12, function() if model.Parent then FadeBot(1, true) end end)
                        currentPos = to
                        desired = to
                        smoothVel = Vector3.zero
                        if kv.mv then kv.mv.Jump = true end -- (BOT MOVEMENT POE review: the brain starts over from the new spot)
                        BlinkTell(old, to)
                    end
                    kv.skH = hNow
                end

                if mods.Blinking and now >= nextEliteBlink then
                    -- (owner 2026-10-03: "why do the enemies seem to randomly teleport sometimes?" -- Blinking elites did, with
                    -- no tell at all) a flicker first, then a flash + streak to where it lands
                    nextEliteBlink = now + rng:NextNumber(3, 5) * DungeonGenerator.BLINK_SLOW
                    local old = currentPos
                    local to = DungeonGenerator.FindOpenSpot(Clamp(currentPos + right * rng:NextNumber(-16, 16) + Vector3.yAxis * rng:NextNumber(-2, 5)), radius + 0.5, config.Geo)
                    FadeBot(0.35, true)
                    task.delay(0.12, function() if model.Parent then FadeBot(1, true) end end)
                    currentPos = to
                    if kv.mv then kv.mv.Jump = true; desired = to end -- (BOT MOVEMENT POE review: no pull back toward the old spot)
                    BlinkTell(old, to)
                end
            end

            -- personal space: bots push apart instead of stacking into a wall
            group[model] = currentPos
            if not kv.mv then -- (BOT MOVEMENT POE: a brain keeps its own space -- BotMove's throttled push, which also drops removed bots)
                local sep = Vector3.zero
                for other, op in pairs(group) do
                    if other ~= model then
                        if not other.Parent then group[other] = nil else
                            local d = currentPos - op
                            local m = d.Magnitude
                            if m < 11 and m > 0.01 then sep += d.Unit * (11 - m) end
                        end
                    end
                end
                desired += Vector3.new(sep.X, isGround and 0 or sep.Y * 0.5, sep.Z) * 1.25
            end
            desired = Clamp(desired)

            -- UNSTICK: the steering only looks straight ahead, so a target behind a tower / wall panel / platform
            -- used to pin bots against it. Watch progress; when stalled, detour to an open spot it can reach.
            if A.Pattern ~= "Blink" then
                local u = unstick
                if u.Pt then
                    if now >= u.Until or (u.Pt - currentPos).Magnitude < radius + 2 then u.Pt = nil else desired = u.Pt end
                end
                if now >= u.Next then
                    u.Next = now + 0.4 -- (MOVEMENT ROUND 2, owner: "bots shouldnt be stuck for more than about a second": 2 x 0.6 s -> 2 x 0.4 s)
                    local want = desired - currentPos
                    if isGround then want = Vector3.new(want.X, 0, want.Z) end
                    local moved = (currentPos - u.Ref).Magnitude
                    u.Ref = currentPos
                    if not u.Pt and want.Magnitude > radius + 4 and moved < 0.8 then u.Count += 1 else u.Count = 0 end
                    local rp = u.Count >= 2 and ObstacleParams(config.Geo)
                    if rp then
                        u.Count = 0
                        local best, bestScore = nil, math.huge
                        local pPos = targetHrp and targetHrp.Position
                        for ring = 1, 3 do
                            local dist = 8 + ring * 8
                            for i = 0, 11 do
                                local ang = i * math.pi / 6 + ring * 0.37
                                local y = isGround and currentPos.Y or (currentPos.Y + ((i % 3) - 1) * 6 * ring * 0.5)
                                local cand = Clamp(Vector3.new(currentPos.X + math.cos(ang) * dist, y, currentPos.Z + math.sin(ang) * dist))
                                local path = cand - currentPos
                                if path.Magnitude > 2 and not Workspace:Spherecast(currentPos, radius, path, rp)
                                    and not DungeonGenerator.IsSpotBlocked(cand, radius, config.Geo) and not (IS_CLIENT and DungeonGenerator.BodyInTerrain(cand, radius)) then
                                    local score = (cand - desired).Magnitude
                                    if pPos and Workspace:Raycast(cand, pPos - cand, rp) then score += 25 end -- prefer spots that can see you
                                    if score < bestScore then best, bestScore = cand, score end
                                end
                            end
                        end
                        if not best and not isGround then best = Clamp(currentPos + Vector3.new(0, 12, 0)) end -- boxed in: rise
                        if best then
                            u.Pt = isGround and Vector3.new(best.X, groundRootY, best.Z) or best
                            u.Until = now + 2.5
                            desired = u.Pt
                            bearing += rng:NextNumber(0.8, 1.6) -- and orbit to a different side of you afterwards
                        end
                    end
                end
            end
            -- LINE-OF-SIGHT WATCHDOG (owner 2026-10-05: "Bots still get stuck on the other side of environments"): UNSTICK only
            -- fires when a bot STALLS -- one happily strafing behind a cliff / kit wall / tower never did. If it hasn't seen
            -- you for 7 s (Peek snipers 11 s: hiding is their pattern), it flickers out and redeploys to an open spot at its
            -- range that CAN see you (the Blinking elites' tell: flicker, flash, streak). (Fields on `unstick`: no new locals.)
            do
                local u = unstick
                local pPos = targetHrp and targetHrp.Position
                if pPos and not inSafeNow and now >= (u.SightNext or 0) then
                    u.SightNext = now + 0.5
                    local rp = ObstacleParams(config.Geo)
                    if rp then -- (the open maps' rims / cliffs are terrain, outside StaticGeometry: count them too)
                        local sp = RaycastParams.new()
                        sp.FilterType = Enum.RaycastFilterType.Include
                        sp.FilterDescendantsInstances = { config.Geo or rp.FilterDescendantsInstances[1], Workspace.Terrain }
                        rp = sp
                    end
                    if not rp or not Workspace:Raycast(currentPos, pPos - currentPos, rp) then
                        u.SightAt = now
                    elseif not u.SightAt then
                        u.SightAt = now
                    elseif now - u.SightAt > ((A.Pattern == "Peek") and 11 or 7) then
                        u.SightAt = now -- (nothing found: try again in a few seconds)
                        local best = nil
                        for _ = 1, 12 do
                            local ang = rng:NextNumber(0, math.pi * 2)
                            local d = rng:NextNumber(A.Range[1], A.Range[2])
                            local cand = Clamp(Vector3.new(pPos.X + math.cos(ang) * d, isGround and groundRootY or (pPos.Y + rng:NextNumber(3, 10)), pPos.Z + math.sin(ang) * d))
                            if not DungeonGenerator.IsSpotBlocked(cand, radius, config.Geo) and not Workspace:Raycast(cand, pPos - cand, rp) and not (IS_CLIENT and DungeonGenerator.BodyInTerrain(cand, radius)) then best = cand break end
                        end
                        if best then
                            local old = currentPos
                            FadeBot(0.35, true)
                            task.delay(0.12, function() if model.Parent then FadeBot(1, true) end end)
                            currentPos, smoothVel, u.Pt = best, Vector3.zero, nil
                            if kv.mv then kv.mv.Jump = true end -- (BOT MOVEMENT POE review)
                            BlinkTell(old, best)
                        end
                    end
                end
            end
            if IS_CLIENT then desired = DungeonGenerator.TerrGuard(kv, currentPos, desired, radius, isGround and (currentPos.Y - radius * 0.2) or nil, now, smoothVel.Magnitude) end -- (RUNFIX: terrain guard)
            if A.Pattern ~= "Blink" then
                local maxSpd = math.max(moveSpeed, 12) * 2.2
                if isGround then maxSpd = math.max(moveSpeed * 1.6, 14) * 1.8 end
                if A.Pattern == "Charge" then maxSpd = math.max(8, moveSpeed * DungeonGenerator.CHARGE_MOVE) end -- (Update 6: no fast repositioning round you)
                if kv.mv then maxSpd = kv.mv.Top * 1.4 + 3 end -- (BOT MOVEMENT POE: it follows its brain, no faster)
                if tdt > 1e-4 then
                    -- feed-forward the target's own motion (so strafes aren't lagged) + pull toward it
                    local ff = lastDesired and (desired - lastDesired) / tdt or Vector3.zero
                    if ff.Magnitude > maxSpd * 1.5 then ff = Vector3.zero end -- a jump in the target (new state), not motion
                    local want = ff + (desired - currentPos) * 9
                    if want.Magnitude > maxSpd then want = want.Unit * maxSpd end
                    local accelLim = kv.mv and (kv.mv.Acc * DungeonGenerator.BotMove.BRAKE * 1.5) or (math.max(moveSpeed, 12) * (14 + 12 * chaos))
                    local dv = want - smoothVel
                    if dv.Magnitude > accelLim * tdt then dv = dv.Unit * accelLim * tdt end
                    smoothVel += dv
                    -- (BOT MOVEMENT POE) READABILITY CAP: its motion across your screen <= BotMove.CAP_DEG deg/s, whatever the tier / mods /
                    -- skill; the part toward / away from you is free (DevMoveOld: off)
                    if kv.capOn and targetHrp and targetHrp.Parent then smoothVel = DungeonGenerator.BotMove.Cap(smoothVel, currentPos, targetHrp.Position + Vector3.new(0, 1.5, 0)) end
                    local before = currentPos
                    local move = smoothVel * tdt
                    if move.Magnitude < 0.05 then
                        -- tiny steps (SteerStep would round them to zero), but never INTO a wall: pressed against
                        -- cover these used to add up and let bots creep through it
                        local np = currentPos + move
                        if not DungeonGenerator.IsSpotBlocked(np, radius * 0.8, config.Geo) then currentPos = np end
                        -- (velocity is kept: a refused tiny step used to zero it, so every next step was tiny too and a
                        -- bot touching a wall's bounding box froze for good. Kept, it grows into a real step that
                        -- SteerStep routes around the wall.)
                    else
                        currentPos = DungeonGenerator.SteerStep(currentPos, currentPos + Vector3.new(move.X, isGround and 0 or move.Y, move.Z), move.Magnitude + 0.02, radius, config.Geo, isGround)
                        smoothVel = (currentPos - before) / tdt -- walls/edges eat velocity instead of storing it
                    end
                end
                lastDesired = desired
                if isGround then currentPos = Vector3.new(currentPos.X, desired.Y, currentPos.Z) end -- walkers stay on the floor (or mid-jump)
            end
            if kv.dashPlan and now >= kv.dashPlan.At then
                -- (ENEMY ATTACKS PILOT RUSHER) the wind-up is over: dive / roll along the line it locked when it started
                local pl = kv.dashPlan
                kv.dashPlan = nil
                if not kv.stag and model:GetAttribute("Dead") ~= true and pl.Leap then
                    -- (ENEMY VARIETY leap slam) the landing is locked on you NOW and marked; the body arcs there (no hit on the way: the
                    -- marked circle strikes as it lands)
                    local ok, land, dur = pcall(BotRoles.Verbs.LeapStart, kv.role, pl.Leap, currentPos)
                    if ok then
                        dashFrom, dashTo, dashT0 = currentPos, land, os.clock()
                        kv.dashDur, kv.dashLeap, kv.dashHit = dur, pl.Leap.Apex, nil
                    end
                elseif not kv.stag and model:GetAttribute("Dead") ~= true then
                    dashFrom, dashTo, dashT0 = currentPos, currentPos + pl.Dir * pl.Len, os.clock()
                    kv.dashDur = pl.Dur
                    kv.dashHit = { Mult = pl.Mult, Reach = pl.Reach, Done = {} }
                    pcall(function() require(script.Parent:WaitForChild("SoundHelper")).PlayAt("Dash", root) end)
                end
            end
            if dashTo and dashFrom then
                -- Charger lunge: dive along the telegraphed strip
                local k = math.clamp((now - dashT0) / (kv.dashDur or DungeonGenerator.CHARGE_DIVE), 0, 1)
                local want = dashFrom:Lerp(dashTo, k)
                -- (always flat, and the dive ends at whatever it hits: Chargers float, and a blocked dive used to take
                -- SteerStep's "boxed in: rise out" path with the whole dive length as the step -- straight to the
                -- ceiling. Playtester 2026-10-02: "charger enemies teleporting to the ceiling after rushing")
                local before = currentPos
                currentPos = DungeonGenerator.SteerStep(currentPos, want, (want - currentPos).Magnitude + 0.05, radius, config.Geo, true)
                currentPos = Vector3.new(currentPos.X, dashFrom.Y + (kv.dashLeap and 4 * kv.dashLeap * k * (1 - k) or 0), currentPos.Z) -- (ENEMY VARIETY: a leap arcs)
                smoothVel = Vector3.zero
                local dh = kv.dashHit
                if dh then -- (ENEMY ATTACKS PILOT RUSHER: the dive itself is the hit -- anyone it passes close to, once)
                    for _, pl in ipairs(TargetPlayers(config)) do
                        local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
                        if r and not dh.Done[pl] then
                            local rel = r.Position - currentPos
                            local seg = EnemyAttacks.SegSeg(before, currentPos, r.Position + Vector3.new(0, -2.5, 0), r.Position + Vector3.new(0, 1.5, 0))
                            if seg <= dh.Reach + EnemyAttacks.TOL and math.abs(rel.Y) < 6 then
                                dh.Done[pl] = true
                                EnemyAttacks.HitTag = "Spike" -- (POE DAMAGE MODEL probe)
                                EnemyAttacks.StrikeHit(atk, pl, dh.Mult, nil)
                                EnemyAttacks.HitTag = nil
                            end
                        end
                    end
                end
                if k >= 1 or (currentPos - before).Magnitude < 0.01 then
                    if kv.dashLeap then currentPos = Vector3.new(currentPos.X, dashFrom.Y, currentPos.Z) end
                    dashTo, dashFrom = nil, nil
                    kv.dashHit, kv.dashDur, kv.dashLeap = nil, nil, nil
                    kv.recUntil = now + DungeonGenerator.CHARGE_RECOVER -- (Update 6: winded after the dive: a free shot)
                    lastDesired = nil
                end
            end
            do
                -- (fixes 2026-10-16 #7) the room-box clamp runs after the steering and never looked at geometry: a bot
                -- pressed to the edge of its box was shoved into props standing on that edge (measured: Frostbite 13 of
                -- 192 samples inside a kit prop's hitbox by the north door). A clamp into something keeps the last free spot.
                local clamped = Clamp(currentPos)
                if (clamped - currentPos).Magnitude > 0.01 and kv.freePos then
                    local probe = isGround and (clamped + Vector3.new(0, radius * 0.35, 0)) or clamped
                    if DungeonGenerator.IsSpotBlocked(probe, radius * 0.6, config.Geo) then clamped = kv.freePos; smoothVel = Vector3.zero end
                end
                currentPos = clamped
                kv.freePos = currentPos
            end
            -- EMBEDDED (owner 2026-10-04: "certain things within the arena environment tend to glitch out the bots"): the
            -- steering can't see geometry it's already inside (shapecasts skip whatever they start in), so a bot that
            -- ended up in a prop / terrace / bunker (a blink, a spawn, a dive) slid on through it and jittered. Step out
            -- to the nearest open spot instead (walkers stay on the floor).
            if A.Pattern ~= "Blink" and now >= (kv.embedCheck or 0) then
                kv.embedCheck = now + (kv.tgNear and 0.25 or 0.4)
                local probe = isGround and (currentPos + Vector3.new(0, radius * 0.35, 0)) or currentPos
                -- (BOTFIX 2026-10-24) terrain has no collider: once a second a client bot also checks the terrain voxel it's in
                -- (RUNFIX 2026-10-25: the gate used to re-arm itself every check, so the terrain test ran ONCE per bot, at spawn)
                if IS_CLIENT and now >= (kv.terrAt or 0) then
                    kv.inTerr = DungeonGenerator.BodyInTerrain(probe, radius, isGround and (currentPos.Y - radius * 0.2) or nil)
                    kv.terrAt = now + (kv.tgNear and 0.25 or 1) -- (RUNFIX: 4x a second near the camera)
                else
                    kv.inTerr = false
                end
                if kv.inTerr or DungeonGenerator.IsSpotBlocked(probe, radius * 0.55, config.Geo) then
                    local out = nil
                    for ring = 1, 5 do
                        local dist = ring * math.max(2, radius * 1.4)
                        for i = 0, 11 do
                            local ang = i * math.pi / 6 + ring * 0.5
                            local cand = Clamp(Vector3.new(currentPos.X + math.cos(ang) * dist, currentPos.Y + (isGround and 0 or ((i % 3) - 1) * ring), currentPos.Z + math.sin(ang) * dist))
                            local cp = isGround and (cand + Vector3.new(0, radius * 0.35, 0)) or cand
                            if not DungeonGenerator.IsSpotBlocked(cp, radius * 0.75, config.Geo) and not (kv.inTerr and DungeonGenerator.BodyInTerrain(cp, radius, isGround and (cand.Y - radius * 0.2) or nil)) then out = cand; break end
                        end
                        if out then break end
                    end
                    if out then
                        currentPos = out
                        smoothVel = Vector3.zero
                        if kv.mv then kv.mv.Jump = true end -- (BOT MOVEMENT POE review: an unembed step-out is a teleport for the brain)
                        if kv.inTerr then kv.tgHold, kv.tgUntil, kv.tgPin = out, now + DungeonGenerator.TERR_PIN, now + DungeonGenerator.TERR_PIN end -- (RUNFIX: don't fly straight back in)
                        model:SetAttribute("Unembeds", (model:GetAttribute("Unembeds") or 0) + 1) -- (play-test counter)
                    end
                end
            end

            local look
            if isGround then
                -- upright: turn to face you, never tilt
                look = targetHrp and CFrame.lookAt(currentPos, Vector3.new(targetHrp.Position.X, currentPos.Y, targetHrp.Position.Z)) or CFrame.new(currentPos)
            else
                look = targetHrp and CFrame.lookAt(currentPos, targetHrp.Position) or CFrame.new(currentPos)
            end
            model:PivotTo(look)
            if kv.cmdFloor then DungeonGenerator.CommandFloorStep(kv.cmdFloor, model, currentPos, now) end -- (COMMAND REACH: the floor ring under it)
            if kv.tetherPivot then
                -- (Uplink) the data tether from its pivot to the body
                if not kv.tether then
                    local t = Instance.new("Part")
                    t.Name = "DataTether"; t.Anchored = true; t.CanCollide = false; t.CanQuery = false; t.CanTouch = false; t.CastShadow = false
                    t.Material = Enum.Material.Neon; t.Color = A.Color; t.Transparency = 0.35; t.Parent = model
                    kv.tether = t
                end
                local a, b = kv.tetherPivot, currentPos
                kv.tether.Size = Vector3.new(0.12, 0.12, math.max(0.2, (b - a).Magnitude))
                kv.tether.CFrame = CFrame.lookAt((a + b) / 2, b)
            end
            if isGround and #legs == 2 then
                -- legs swing with the strafe speed; tucked while airborne
                local stepVel = (currentPos - lastPos).Magnitude / math.max(dt, 1 / 240)
                local swing = math.clamp(stepVel / math.max(moveSpeed, 1), 0, 1.4) * math.rad(28) * math.sin(now * 14)
                local tuck = (jumpT >= 0 or kv.leaping) and math.rad(25) or 0
                for i, leg in ipairs(legs) do
                    local side = (i == 1) and -1 or 1
                    local hip = look * CFrame.new(side * bodySize.X * 0.26, -bodySize.Y / 2, 0)
                    leg.CFrame = hip * CFrame.Angles(side * swing - tuck, 0, 0) * CFrame.new(0, -legH / 2, 0)
                end
                local deco = kv.Deco
                if deco.Arms then
                    local aimRaise = (now < holdUntil or now < aimingUntil) and math.rad(70) or 0 -- arms up while winding up
                    for i, arm in ipairs(deco.Arms) do
                        local side = (i == 1) and -1 or 1
                        local shoulder = look * CFrame.new(side * bodySize.X * 0.66, bodySize.Y * 0.32, 0)
                        local raise = (i == 2 and not A.Melee) and math.rad(80) or aimRaise -- the gun arm points forward
                        arm.CFrame = shoulder * CFrame.Angles(-side * swing * 0.8 + raise, 0, 0) * CFrame.new(0, -deco.ArmLen / 2, 0)
                        local h = deco.Hand and deco.Hand[i]
                        if h then h.Part.CFrame = arm.CFrame * h.Off end
                    end
                    if deco.Hand and deco.Hand.Muzzle then deco.Hand.Muzzle.Part.CFrame = deco.Arms[2].CFrame * deco.Hand.Muzzle.Off end
                end
            end
            if halo then
                halo.CFrame = CFrame.new(currentPos + Vector3.new(0, headY + headSize.Y * 0.6, 0)) * CFrame.Angles(0, now * 2, math.rad(90))
            end

            -- Regenerating / Shielded elites
            if mods.Regenerating and not IS_CLIENT then
                local h, mh = model:GetAttribute("Health") or 0, model:GetAttribute("MaxHealth") or 1
                if h > 0 and h < mh and os.clock() - (model:GetAttribute("HurtAt") or 0) >= ELITE_REGEN_WAIT then
                    local nh = math.min(mh, h + mh * ELITE_REGEN * dt)
                    model:SetAttribute("Health", nh)
                    fillBar.Size = UDim2.new(nh / mh, 0, 1, 0)
                end
            end
            if mods.Shielded or mods.Warded then -- (UPDATE 8: Warded = the ward phase)
                if now >= nextShield then
                    nextShield = now + rng:NextNumber(8, 10)
                    shieldUntil = now + 2 -- (2026-10-22: 2.5 s at 75% blocked every 7-9 s -> 2 s at 50% every 8-10 s)
                    DungeonGenerator.SetTakenMult(model, 0.5)
                    local sp = Instance.new("Part")
                    sp.Name = "EliteShield"; sp.Shape = Enum.PartType.Ball
                    sp.Size = Vector3.new(1, 1, 1) * (bodySize.X * 2.1)
                    sp.Material = Enum.Material.ForceField; sp.Color = Color3.fromRGB(140, 200, 255)
                    sp.Transparency = 0.2; sp.Anchored = true; sp.CanCollide = false; sp.CanQuery = false; sp.CanTouch = false; sp.CastShadow = false
                    sp.Parent = model
                    shieldPart = sp
                elseif shieldUntil > 0 and now >= shieldUntil then
                    shieldUntil = 0
                    DungeonGenerator.SetTakenMult(model, nil)
                    if shieldPart then shieldPart:Destroy(); shieldPart = nil end
                end
                if shieldPart then shieldPart.CFrame = CFrame.new(currentPos) end
            end
            -- (ENEMY ATTACKS PILOT elite mod SHELLED) its typed shell: a bubble in the type's colour while ShellHp > 0 (the server's
            -- number; a solo model mirrors it), the bar under its health bar (EnemyBars); it shatters + staggers when it breaks
            if kv.shellT then
                local sh = model:GetAttribute("ShellHp")
                local up = (sh == nil) or sh > 0
                if up and not kv.shellPart then
                    DungeonGenerator._DT = DungeonGenerator._DT or require(script.Parent:WaitForChild("DamageTypes"))
                    local d = math.max(bodySize.X * 2.2, (bodySize.Y + (isGround and legH or 0)) * 1.35)
                    local sp = Instance.new("Part")
                    sp.Name = "EliteShell"; sp.Shape = Enum.PartType.Ball; sp.Size = Vector3.new(d, d, d)
                    sp.Material = Enum.Material.ForceField; sp.Color = DungeonGenerator._DT.COLOR[kv.shellT] or Color3.new(1, 1, 1)
                    sp.Transparency = 0.1; sp.Anchored = true; sp.CanCollide = false; sp.CanQuery = false; sp.CanTouch = false; sp.CastShadow = false
                    sp.CFrame = CFrame.new(currentPos)
                    sp.Parent = model
                    kv.shellPart = sp
                end
                if kv.shellPart then
                    if up then
                        kv.shellPart.CFrame = CFrame.new(currentPos)
                    else
                        local sp = kv.shellPart
                        kv.shellPart, kv.shellT = nil, nil
                        task.spawn(function()
                            local d0, t0 = sp.Size.X, os.clock()
                            while sp.Parent and os.clock() - t0 < 0.25 do
                                local k = (os.clock() - t0) / 0.25
                                sp.Size = Vector3.one * d0 * (1 + 0.35 * k)
                                sp.Transparency = 0.1 + 0.9 * k
                                RunService.Heartbeat:Wait()
                            end
                            sp:Destroy()
                        end)
                        pcall(function() require(script.Parent:WaitForChild("SoundHelper")).PlayAt("ShieldDown", root) end)
                        EnemyAttacks.Stagger(model, BotRoles.SHELL_STAGGER, FxParent(config))
                    end
                end
            end

            -- (POE DAMAGE MODEL) a caster's aura shows / ticks only while it is fighting you (not in a range bay or the safe room)
            if kv.role then kv.auraOn = targetHrp ~= nil and not R and not inSafeNow and not kv.stag and targetHrp.Position.Z > 450 and not model:GetAttribute("PredictedDead") end
            -- Attacks
            if not targetHrp and laser then
                laser:Destroy(); laser = nil
                aimingUntil = 0
            end
            if targetHrp and not R and targetHrp.Position.Z > 450 and A.Melee then
                -- MELEE (telegraphed on the floor): Charger lunges along a strip, Juggernaut slams a circle (every 3rd: a
                -- shockwave you jump over), Brute swings a cone. Out of the marked area when it fills = no damage.
                local toP = Vector3.new(targetHrp.Position.X - currentPos.X, 0, targetHrp.Position.Z - currentPos.Z)
                local dist = toP.Magnitude
                local face = dist > 0.1 and toP.Unit or Vector3.new(0, 0, 1)
                -- (POE DAMAGE MODEL) RUSHER CONTACT: a short jab once it is on you (chip; no slot; not inside a big wind-up / dive)
                if kv.role and kv.role.Row.Contact and not inSafeNow and not model:GetAttribute("PredictedDead") then
                    BotRoles.Contact(kv.role, targetHrp, now < holdUntil or dashTo ~= nil or kv.dashPlan ~= nil or kv.stag == true)
                end
                if now >= nextAttack and now >= holdUntil and not dashTo and not kv.dashPlan and not kv.stag and not inSafeNow
                    and not (kv.role and now < (kv.role.JabUntil or 0)) and Slot(now, 1.3, targetHrp) then
                    local interval = fireInterval * rng:NextNumber(0.85, 1.15) / math.max(0.4, slowMult) * BotRoles.RallyMult(model)
                    local role = kv.role and not kv.role.Row.Keep and kv.role or nil
                    if role and role.Row.Attack == "Dash" and dist <= 30 and dist >= 7 and now >= (kv.recUntil or 0) + 0.6 then
                        -- (ENEMY ATTACKS PILOT RUSHER) it stops and glows on its body (no strip on the floor), then dives
                        local pl = BotRoles.DashPlan(role, dist, face)
                        holdUntil = now + pl.Scaled
                        nextAttack = now + pl.Wu * atk.Windup + interval
                        kv.dashPlan = { At = now + pl.Scaled, Dir = face, Len = pl.Len, Dur = pl.Dur, Mult = pl.Mult, Reach = pl.Reach }
                    elseif role and role.Row.Attack == "Swing" and dist <= radius + 7 then
                        -- (ENEMY ATTACKS PILOT RUSHER) a swing told on its body: same reach / arc / damage as the old floor cone
                        local wu = BotRoles.Swing(role, function()
                            local tp = targetHrp and targetHrp.Parent and targetHrp.Position or (currentPos + face)
                            local f = Vector3.new(tp.X - currentPos.X, 0, tp.Z - currentPos.Z)
                            return f.Magnitude > 0.1 and f.Unit or face
                        end)
                        holdUntil = now + wu.Scaled
                        nextAttack = now + wu.Raw * atk.Windup + interval
                    elseif role then
                        nextAttack = now + 0.3 -- (out of its reach: keep closing in)
                    elseif A.Pattern == "Charge" and dist <= 30 and dist >= 7 and now >= (kv.recUntil or 0) + 0.6 then
                        -- (Update 6) a clear wind-up: it stops, glows and marks the strip, then dives straight along it
                        local wu = DungeonGenerator.CHARGE_WINDUP
                        local len = math.clamp(dist + 4, 12, 34)
                        local to = currentPos + face * len
                        holdUntil = now + wu * atk.Windup
                        nextAttack = now + wu * atk.Windup + interval
                        local stopGlow = EnemyAttacks.Charge(atk, function() return currentPos end, radius * 0.7, wu, elem and elem.Color or nil)
                        task.delay(wu * atk.Windup, stopGlow)
                        EnemyAttacks.Line(atk, currentPos, to, 6, wu, { Mult = 1.35, OnStrike = function()
                            dashFrom, dashTo, dashT0 = currentPos, Vector3.new(to.X, currentPos.Y, to.Z), os.clock()
                        end })
                    elseif A.Pattern ~= "Charge" and dist <= radius + 7 then
                        meleeCount += 1
                        local wu
                        if A.Label == "Juggernaut" and meleeCount % 3 == 0 then
                            wu = 0.8
                            EnemyAttacks.Ring(atk, currentPos, 38, wu, { Mult = 1.1 })
                        elseif A.Label == "Juggernaut" then
                            wu = 0.75
                            EnemyAttacks.Circle(atk, currentPos, radius + 9, wu, { Mult = 1.4 })
                        else
                            wu = 0.5
                            EnemyAttacks.Cone(atk, currentPos, face, radius + 10, 55, wu, { Mult = 1.35 })
                        end
                        holdUntil = now + wu * atk.Windup
                        nextAttack = now + wu * atk.Windup + interval
                    end
                end
            elseif targetHrp and not R and targetHrp.Position.Z > 450 then
                -- (POE DAMAGE MODEL) a ranged-pattern RUSHER (Slagroller) jabs too once it is on you
                if kv.role and kv.role.Row.Contact and not inSafeNow and not model:GetAttribute("PredictedDead") then
                    BotRoles.Contact(kv.role, targetHrp, now < holdUntil or dashTo ~= nil or kv.dashPlan ~= nil or kv.stag == true)
                end
                -- RANGED = AREA ATTACKS, no projectiles (owner: "once the red area goes off, if you are in it, you get hit").
                -- The bot glows while it winds up; the red area appears where you are (leading you a little) and fills.
                local peekSpot = (now >= nextAttack and not hasLos and not inSafeNow and coverT > 1.2 and not kv.role) and EnemyMind.PeekSpot(targetHrp) -- (role bots don't pre-fire a corner)
                if peekSpot and rng:NextNumber() < 0.5 * learn and Slot(now, 1.2, targetHrp) then
                    -- you keep stepping out of the same corner: pre-fire it while you're hidden
                    local wu = 1.0
                    EnemyAttacks.Circle(atk, Vector3.new(peekSpot.X, targetHrp.Position.Y, peekSpot.Z), 7, wu, { Mult = 0.9 })
                    EnemyMind.Cue(model)
                    local stopGlow = EnemyAttacks.Charge(atk, function() return currentPos end, radius * 0.7, wu, elem and elem.Color or nil)
                    task.delay(wu * atk.Windup, stopGlow)
                    nextAttack = now + wu * atk.Windup + fireInterval * rng:NextNumber(1.0, 1.3) / math.max(0.4, slowMult)
                elseif now >= nextAttack and not hasLos then
                    nextAttack = now + 0.3 -- you're behind cover: no line on you, reposition
                elseif now >= nextAttack and kv.role and (kv.stag or kv.dashPlan or dashTo or now < (kv.role.JabUntil or 0) or not BotRoles.Ready(kv.role, targetHrp) or DungeonGenerator.BotMove.Busy(kv.mv)) then
                    nextAttack = now + 0.25 -- (ENEMY ATTACKS PILOT: staggered / mid-dash / SHOT_CAP rounds already in the air at you: wait)
                elseif now >= nextAttack and kv.role and not inSafeNow and not kv.noAttack and not model:GetAttribute("PredictedDead") and Slot(now, 1.2, targetHrp) then
                    -- (ENEMY ATTACKS PILOT 2026-10-30) ROLE ATTACKS (AimRngShared/BotRoles): visible rounds / a charged shot / a shell / a ward
                    local role = kv.role
                    local interval = fireInterval * rng:NextNumber(0.85, 1.15) / math.max(0.4, slowMult) * BotRoles.RallyMult(model)
                    if role.Row.Attack == "Dash" or role.Row.Attack == "Leap" then
                        -- a ranged-pattern RUSHER (Slagroller): it halts and glows, then rolls through you; out of reach = no attack
                        -- (ENEMY VARIETY: a Leap row crouches the same way, then leaps onto your spot -- see the dash release)
                        local toP = Vector3.new(targetHrp.Position.X - currentPos.X, 0, targetHrp.Position.Z - currentPos.Z)
                        local dist = toP.Magnitude
                        if dist <= 32 and dist >= 5 then
                            local pl = BotRoles.DashPlan(role, dist, toP, targetHrp)
                            holdUntil = now + pl.Scaled
                            nextAttack = now + pl.Wu * atk.Windup + interval
                            kv.dashPlan = { At = now + pl.Scaled, Dir = toP.Unit, Len = pl.Len, Dur = pl.Dur, Mult = pl.Mult, Reach = pl.Reach, Leap = pl.Leap }
                        else
                            nextAttack = now + 0.4
                        end
                    else
                        local wu = BotRoles.Ranged(role, targetHrp) or 0.6
                        nextAttack = now + wu * atk.Windup + interval
                        if role.Row.Attack == "Aimed" then
                            if A.Pattern == "Peek" then aimingUntil = now + wu * atk.Windup end
                            -- (a Blinker holds its spot while it charges, then blinks: the shot never leaves from a new place)
                            nextBlink = math.max(nextBlink, now + wu * atk.Windup * EnemyAttacks.REACT + 0.5)
                        end
                    end
                elseif now >= nextAttack and not kv.role and not kv.stag and not inSafeNow and not kv.noAttack and not model:GetAttribute("PredictedDead") and Slot(now, 1.2, targetHrp) then
                    local kind = RANGED_KIND[A.Label] or "Circle"
                    -- where it aims: you + a little lead, or -- once it has learned your habits -- where you're about to be
                    local wuGuess = (kind == "Snipe" or kind == "Big") and 1.0 or (kind == "Quick") and 0.6 or (kind == "Ping") and 0.45 or (kind == "Strip") and 0.75 or 0.8
                    local lead, read = EnemyMind.Aim(targetHrp, currentPos, wuGuess * atk.Windup, learn)
                    if read then EnemyMind.Cue(model) end
                    EnemyMind.RecordDodge(targetHrp, currentPos, lead, wuGuess * atk.Windup)
                    local wu
                    if kind == "Strip" or kind == "Snipe" then
                        local width = (kind == "Snipe") and 3 or 4.5
                        wu = (kind == "Snipe") and 1.0 or 0.75
                        local flat = Vector3.new(lead.X - currentPos.X, 0, lead.Z - currentPos.Z)
                        local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, 1)
                        local len = math.min(flat.Magnitude + 14, (kind == "Snipe") and 110 or 60)
                        local from = Vector3.new(currentPos.X, targetHrp.Position.Y, currentPos.Z)
                        EnemyAttacks.Line(atk, from, from + dir * len, width, wu, { Height = 9, Mult = (kind == "Snipe") and 1.6 or 1 })
                        if A.Pattern == "Peek" then aimingUntil = now + wu * atk.Windup end
                    elseif kind == "Barrage" or mods.Multishot then
                        wu = 0.8
                        local n = (kind == "Barrage") and (A.Burst or 4) or 3
                        for i = 1, n do
                            local off = (i == 1) and Vector3.zero or Vector3.new(rng:NextNumber(-9, 9), 0, rng:NextNumber(-9, 9))
                            local at = lead + off
                            task.delay((i - 1) * 0.12, function()
                                if model.Parent then EnemyAttacks.Circle(atk, at, 5, wu, { Mult = 0.8 }) end
                            end)
                        end
                    elseif kind == "Chain" then
                        -- chain lightning: three quick strikes hopping along the way you're moving
                        wu = 0.6
                        local v = targetHrp.AssemblyLinearVelocity
                        local step = Vector3.new(v.X, 0, v.Z)
                        if step.Magnitude > 2 then step = step.Unit * 6 else
                            local a = rng:NextNumber(0, math.pi * 2); step = Vector3.new(math.cos(a), 0, math.sin(a)) * 6
                        end
                        for i = 0, 2 do
                            local at = lead + step * i
                            task.delay(i * 0.22, function() if model.Parent then EnemyAttacks.Circle(atk, at, 4, wu, { Mult = 0.75 }) end end)
                        end
                    elseif kind == "Cross" then
                        -- crosswind: a wide strip ACROSS the line between you and it -- step forward or back, not sideways
                        wu = 0.8
                        local flat = Vector3.new(lead.X - currentPos.X, 0, lead.Z - currentPos.Z)
                        local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, 1)
                        local side = Vector3.new(-dir.Z, 0, dir.X)
                        EnemyAttacks.Line(atk, lead - side * 16, lead + side * 16, 5, wu, { Height = 9 })
                    elseif kind == "Clap" then
                        -- thunderclap: a strike where you stand, then a shockwave rolling out of it (jump it)
                        wu = 0.8
                        EnemyAttacks.Circle(atk, lead, 5, wu, {})
                        local at = lead
                        task.delay(wu * atk.Windup, function() if model.Parent then EnemyAttacks.Ring(atk, at, 26, 0.05, { Mult = 0.7, Speed = 26 }) end end)
                    elseif kind == "Triad" then
                        -- storm strike: three wide strikes around you, then one on you -- hold still, then move
                        wu = 1.05
                        local a0 = rng:NextNumber(0, math.pi * 2)
                        for i = 0, 2 do
                            local a = a0 + i * math.pi * 2 / 3
                            EnemyAttacks.Circle(atk, lead + Vector3.new(math.cos(a) * 9, 0, math.sin(a) * 9), 6, wu, { Mult = 0.9 })
                        end
                        local at = lead
                        task.delay(0.45, function() if model.Parent then EnemyAttacks.Circle(atk, at, 5, wu, { Mult = 0.9 }) end end)
                    elseif kind == "Flare" or kind == "Fissure" or kind == "Scorch" or kind == "Crucible" or kind == "Shatter" or kind == "FrozenLane"
                        or kind == "Sleet" or kind == "CryoLock" or kind == "Echo" or kind == "Twin" or kind == "RiftLance" or kind == "Gaze"
                        or kind == "Gridlock" or kind == "Ping" or kind == "Trident" or kind == "Firewall"
                        or kind == "Carom" or kind == "Icefall" or kind == "Collapse" or kind == "Bitstream" then
                        wu = DungeonGenerator.BiomeAttack(kind, atk, model, currentPos, lead, targetHrp, rng, function() return currentPos end)
                    else
                        local r, w = 6, 0.8
                        if kind == "Quick" then r, w = 4.5, 0.6 elseif kind == "Big" then r, w = 9, 1.0 end
                        wu = w
                        EnemyAttacks.Circle(atk, lead, r, wu, {})
                    end
                    local stopGlow = EnemyAttacks.Charge(atk, function() return currentPos end, radius * 0.7, wu, elem and elem.Color or nil)
                    task.delay(wu * atk.Windup, stopGlow)
                    nextAttack = now + wu * atk.Windup + fireInterval * rng:NextNumber(0.85, 1.15) / math.max(0.4, slowMult) * BotRoles.RallyMult(model)
                end
            end

            lastPos = currentPos
            -- (optimization pass 2026-10-27: an IDLE linked-room bot -- kv.lst 1, milling at IDLE_PACE in a room you're not
            -- fighting in -- thinks at 20 Hz; its motion is scaled by the real dt, EnemyAnim keeps posing it every frame)
            if kv.lnk and kv.lst == 1 and IS_CLIENT then task.wait(1 / 20) else
            RunService.Heartbeat:Wait() end -- every frame (server-run party bots too: smoother network updates)
        end

        if laser then laser:Destroy() end
        -- (ENEMY ATTACKS PILOT elite mod AVENGING) an ally's death rallies an Avenging elite's pack (only a real kill)
        if model:GetAttribute("Dead") == true then pcall(BotRoles.AllyDown, group, lastPos, model, FxParent(config)) end
        -- (POE DAMAGE MODEL) a role ELITE's short death burst (chip, not evadable, its own type); a Volatile one keeps its own blast
        if kv.role and isElite and not mods.Volatile and model:GetAttribute("Dead") == true then
            pcall(BotRoles.DeathBurst, kv.role, EnemyAttacks.Context({ Geo = config.Geo, Fx = FxParent(config), Color = elem and elem.Color or nil,
                Windup = atk.Windup, Targets = function() return TargetPlayers(config) end }), lastPos)
        end
        -- Volatile: a delayed blast where it died (only when actually killed, not on floor cleanup) -- telegraphed circle
        if mods.Volatile and model:GetAttribute("Dead") == true then
            local boom = EnemyAttacks.Context({
                Geo = config.Geo, Fx = FxParent(config), Color = Color3.fromRGB(255, 90, 40), Windup = atk.Windup,
                Targets = function() return TargetPlayers(config) end,
                Hit = function(p) DungeonGenerator.HitPlayer(p, math.round(dmg * 2), nil, "Fire", 1, model) end,
            })
            EnemyAttacks.Circle(boom, lastPos, 11, 1.2, { Height = 14 })
        end
    end)

    return model
end

-- BIOME ROSTER ATTACKS (see RANGED_KIND). Returns the wind-up used (CreateBot times its next attack and charge glow off it).
function DungeonGenerator.BiomeAttack(kind: string, atk: any, model: Model, pos: Vector3, lead: Vector3, target: BasePart, rng: Random, posFn: () -> Vector3): number
    local EA = EnemyAttacks
    local nbw = DungeonGenerator.NB.Attack(EA, kind, atk, model, pos, lead, rng) -- (the new biomes' attacks)
    if nbw then return nbw end
    local function Alive() return model.Parent ~= nil and model:GetAttribute("Dead") ~= true end
    local from = Vector3.new(pos.X, lead.Y, pos.Z)
    local flat = Vector3.new(lead.X - pos.X, 0, lead.Z - pos.Z)
    local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, 1)
    local side = Vector3.new(-dir.Z, 0, dir.X)
    if kind == "Flare" then
        -- a burst of fire where you stand that keeps burning a moment (don't step back in)
        EA.Circle(atk, lead, 5, 0.8, { OnStrike = function(c) if Alive() then EA.Zone(atk, c, 4, 0.05, 2.4, { Mult = 0.3, Height = 5 }) end end })
        return 0.8
    elseif kind == "Fissure" then
        -- the floor splits open from it to you and on past: a line of bursts racing along the ground
        local total = math.min(flat.Magnitude + 10, 50)
        local n = math.max(4, math.floor(total / 5))
        for i = 1, n do
            local at = from + dir * (i * total / n)
            task.delay(i * 0.07, function() if Alive() then EA.Circle(atk, at, 3.2, 0.7, { Mult = 0.6 }) end end)
        end
        return 0.7
    elseif kind == "Scorch" then
        -- a narrow fan of fire breath
        EA.Cone(atk, from, dir, math.min(flat.Magnitude + 12, 55), 13, 0.75, { Mult = 0.9 })
        return 0.75
    elseif kind == "Crucible" then
        -- a big pool of molten metal on you that sits and burns
        EA.Zone(atk, lead, 7.5, 1.1, 4.5, { Mult = 0.35, Height = 5 })
        return 1.1
    elseif kind == "Shatter" then
        -- a burst on you that throws four shards out (dodge the burst, then the shards)
        local a0 = rng:NextNumber(0, math.pi / 2)
        EA.Circle(atk, lead, 4.5, 0.7, { OnStrike = function(c)
            if not Alive() then return end
            for i = 0, 3 do
                local a = a0 + i * math.pi / 2
                EA.Circle(atk, c + Vector3.new(math.cos(a) * 8, 0, math.sin(a) * 8), 3, 0.45, { Mult = 0.6 })
            end
        end })
        return 0.7
    elseif kind == "FrozenLane" then
        -- a lane from it through you that stays icy a moment
        local len = math.min(flat.Magnitude + 10, 50)
        EA.Line(atk, from, from + dir * len, 4, 0.75, { Height = 9, OnStrike = function(a, b)
            if not Alive() then return end
            for i = 1, 3 do EA.Zone(atk, a:Lerp(b, i / 4), 3, 0.05, 2.2, { Mult = 0.25, Height = 5 }) end
        end })
        return 0.75
    elseif kind == "Sleet" then
        -- two lanes either side of you (stay in the gap: don't strafe)
        for _, sx in ipairs({ -1, 1 }) do
            local o = side * (sx * 4.5)
            EA.Line(atk, from + o, lead + dir * 14 + o, 3.2, 0.8, { Height = 9, Mult = 0.9 })
        end
        return 0.8
    elseif kind == "CryoLock" then
        -- a frost mark hunts you, locks, then shatters
        EA.Mark(atk, target, 6, 1.5, { Mult = 1.1, Lock = 0.4 })
        return 1.9
    elseif kind == "Echo" then
        -- strikes, then strikes the same spot again (don't step back in)
        local at = lead
        EA.Circle(atk, at, 5, 0.7, { Mult = 0.8 })
        task.delay(0.7 * atk.Windup + 0.15, function() if Alive() then EA.Circle(atk, at, 5, 0.5, { Mult = 0.8 }) end end)
        return 0.7
    elseif kind == "Twin" then
        -- where you're going AND where your reflection would be -- stand still between them
        local p = target.Position
        local o = (lead - p):Dot(side)
        if math.abs(o) < 0.5 then o = (rng:NextNumber() < 0.5) and -1 or 1 end
        o = math.sign(o) * math.max(math.abs(o), 6.5)
        EA.Circle(atk, p + side * o, 4.5, 0.8, { Mult = 0.85 })
        EA.Circle(atk, p - side * o, 4.5, 0.8, { Mult = 0.85 })
        return 0.8
    elseif kind == "RiftLance" then
        -- a lane through you, then one ACROSS it (side-step, then step forward or back)
        local len = math.min(flat.Magnitude + 16, 70)
        EA.Line(atk, from, from + dir * len, 3.5, 0.75, { Height = 9, Mult = 0.85 })
        local at = lead
        task.delay(0.35, function() if Alive() then EA.Line(atk, at - side * 14, at + side * 14, 3.5, 0.75, { Height = 9, Mult = 0.85 }) end end)
        return 0.75
    elseif kind == "Gaze" then
        -- a beam that tracks you, locks, then fires
        EA.Beam(atk, posFn, target, 1.3, { Mult = 1.3, LockTime = 0.3 })
        return 1.3
    elseif kind == "Gridlock" then
        -- a plus along the floor grid through you (escape diagonally)
        local at = lead
        EA.Line(atk, at - Vector3.new(16, 0, 0), at + Vector3.new(16, 0, 0), 3.2, 0.8, { Height = 9, Mult = 0.7 })
        EA.Line(atk, at - Vector3.new(0, 0, 16), at + Vector3.new(0, 0, 16), 3.2, 0.8, { Height = 9, Mult = 0.7 })
        return 0.8
    elseif kind == "Carom" then
        -- MOLTEN Slagroller: a lane from it to you, then a second lane bouncing off your spot at an angle
        local at = lead
        local len = math.min(flat.Magnitude + 4, 50)
        EA.Line(atk, from, from + dir * len, 3.2, 0.75, { Height = 9, Mult = 0.8 })
        local turn = ((rng:NextNumber() < 0.5) and -1 or 1) * math.rad(rng:NextNumber(55, 75))
        local bounce = CFrame.Angles(0, turn, 0):VectorToWorldSpace(dir)
        task.delay(0.35, function() if Alive() then EA.Line(atk, at, at + bounce * 26, 3.2, 0.75, { Height = 9, Mult = 0.8 }) end end)
        return 0.75
    elseif kind == "Icefall" then
        -- CRYO Rimewyrm: a ring of strikes around you (stand still), then one ON you -- slip out through a gap
        local at = lead
        local a0 = rng:NextNumber(0, math.pi * 2)
        for i = 0, 5 do
            local a = a0 + i * math.pi / 3
            EA.Circle(atk, at + Vector3.new(math.cos(a) * 8.5, 0, math.sin(a) * 8.5), 3.4, 0.8, { Mult = 0.7 })
        end
        task.delay(0.5, function() if Alive() then EA.Circle(atk, at, 5, 0.8, { Mult = 0.9 }) end end)
        return 0.8
    elseif kind == "Collapse" then
        -- VOID Antipode: rings of strikes closing in on you -- wait for the outer ring, then step out through it
        local at = lead
        local a0 = rng:NextNumber(0, math.pi * 2)
        for ring, spec in ipairs({ { 13, 9, 0.7 }, { 7.5, 6, 1.05 } }) do
            for i = 0, spec[2] - 1 do
                local a = a0 + (i + ring * 0.5) * math.pi * 2 / spec[2]
                EA.Circle(atk, at + Vector3.new(math.cos(a) * spec[1], 0, math.sin(a) * spec[1]), 2.8, spec[3], { Mult = 0.6 })
            end
        end
        EA.Circle(atk, at, 3.8, 1.4, { Mult = 0.9 })
        return 1.4
    elseif kind == "Bitstream" then
        -- CYBER Glitch: a zig-zag lane from it that ends on you (three corrupted segments)
        local total = math.min(flat.Magnitude, 46)
        local p0 = from
        local zig = (rng:NextNumber() < 0.5) and -1 or 1
        for i = 1, 3 do
            local p1 = (i == 3) and Vector3.new(lead.X, from.Y, lead.Z) or (from + dir * (total * i / 3) + side * (zig * rng:NextNumber(5, 8)))
            local a = p0
            task.delay((i - 1) * 0.12, function() if Alive() then EA.Line(atk, a, p1, 2.8, 0.7, { Height = 9, Mult = 0.75 }) end end)
            p0 = p1
            zig = -zig
        end
        return 0.95
    elseif kind == "Ping" then
        -- small, fast, often
        EA.Circle(atk, lead, 3.5, 0.45, { Mult = 0.7 })
        return 0.45
    elseif kind == "Trident" then
        -- three lanes fanned out from it (stand between them). (0.78, owner: "The satellite bots are still incredibly
        -- overpowered"): the fan was 11 deg -- at range the gaps were narrower than you -- now 20 deg, thinner lanes, a
        -- longer warning, less damage each
        local len = math.min(flat.Magnitude + 12, 60)
        for _, deg in ipairs({ -20, 0, 20 }) do
            local d = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(dir)
            EA.Line(atk, from, from + d * len, 2.0, 1.1, { Height = 9, Mult = 0.55 })
        end
        return 1.1
    else -- Firewall
        -- a floor laser sweeping round it (jump it or outrun the turn)
        local to = target.Position - pos
        local a = math.atan2(to.X, to.Z)
        local sgn = (rng:NextNumber() < 0.5) and -1 or 1
        EA.Sweep(atk, posFn, a - sgn * 0.9, sgn * 1.8, 1.3, 46, { Mult = 1.0, Warn = 0.6 })
        return 1.9
    end
end

-- Back-compat wrappers (bosses spawn plain adds through CreateDrone).
function DungeonGenerator.CreateDrone(droneType: string, spawnPos: Vector3, config: DungeonConfig, parent: Instance?, spec: any?): Model
    return DungeonGenerator.CreateBot(droneType, spawnPos, config, parent, nil, spec)
end
function DungeonGenerator.CreateEliteDrone(droneType: string, spawnPos: Vector3, config: DungeonConfig, parent: Instance?, spec: any?): Model
    return DungeonGenerator.CreateBot(droneType, spawnPos, config, parent, RollEliteMods(config), spec)
end

-- ==================== [RARE LOOT GOBLIN: FLEES ON SIGHT, GUARANTEES A HIGH-QUALITY DROP IF CAUGHT] ====================
DungeonGenerator.LOOT_GOBLIN_LIFETIME = 30 -- seconds before it escapes
DungeonGenerator.LOOT_GOBLIN_CHANCE = 0.01 -- a floor's (room's) chance of a goblin (2026-10-22 owner: 1 in 100; was 0.15)
DungeonGenerator.OnGoblinEscaped = nil :: ((Instance) -> ())?
function DungeonGenerator.CreateLootGoblin(spawnPos: Vector3, config: DungeonConfig, parent: Instance?, spec: any?): Model
    local floorBonus = DungeonGenerator.GetScalingMultiplier(config, 0.10)

    local model = Instance.new("Model")
    model.Name = "LootGoblin"

    local hp = math.round(45 * 0.4 * floorBonus * ((DifficultyScaling[config.Difficulty] or DifficultyScaling.Easy).HealthMult / 0.4) * DungeonGenerator.HpScale(config))
    if spec and spec.MaxHealth then hp = spec.MaxHealth end
    if spec and spec.HealthScale then hp = math.max(1, math.round(hp * spec.HealthScale)) end
    model:SetAttribute("AttackDamage", 0)
    model:SetAttribute("Health", hp)
    model:SetAttribute("MaxHealth", hp)
    model:SetAttribute("XpReward", DungeonGenerator.EnemyXp(config, 3))
    model:SetAttribute("GoldReward", math.round(80 * DungeonGenerator.GetRewardMultiplier(config)))
    model:SetAttribute("IsLootGoblin", true)
    model:SetAttribute("SpawnId", math.random(1, 100))

    -- small: a hard target (the old one was a big glowing ball that sat in a corner)
    local root = MakePart({
        Name = "DroneRoot", Size = Vector3.new(1, 1, 1), Position = spawnPos, Transparency = 1,
        CanCollide = false, CanTouch = false, CanQuery = false, Anchored = true, Parent = model,
    })
    model.PrimaryPart = root

    local body = MakePart({
        Name = "Torso", Shape = Enum.PartType.Ball, Size = Vector3.new(1.25, 1.35, 1.25), CFrame = CFrame.new(spawnPos),
        BrickColor = BrickColor.new("New Yeller"), Material = Enum.Material.Neon, CanCollide = true, CanQuery = true, Anchored = true, Parent = model,
    })
    local head = MakePart({
        Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = CFrame.new(spawnPos + Vector3.new(0, 0.95, 0)),
        BrickColor = BrickColor.new("Gold"), Material = Enum.Material.Neon, CanCollide = true, CanQuery = true, Anchored = true, Parent = model,
    })
    for _, side in ipairs({ -1, 1 }) do
        MakePart({
            Name = "LootSack", Shape = Enum.PartType.Ball, Size = Vector3.new(0.55, 0.55, 0.55),
            CFrame = CFrame.new(spawnPos + Vector3.new(side * 0.8, 0.25, 0)), BrickColor = BrickColor.new("Bright yellow"),
            Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, Anchored = true, Parent = model,
        })
    end
    -- a sparkle trail so it's easy to spot, just not easy to hit
    local trail = Instance.new("ParticleEmitter")
    trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    trail.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90))
    trail.Size = NumberSequence.new(0.35, 0)
    trail.Lifetime = NumberRange.new(0.4, 0.7)
    trail.Rate = 18
    trail.Speed = NumberRange.new(0)
    trail.LightEmission = 1
    trail.Parent = body

    for _, p in ipairs({ body, head }) do
        p:SetAttribute("Damageable", true)
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "HealthHUD"
    billboard.Enabled = false -- (never shown: EnemyBars draws every bar; an enabled one doubled the name + bar)
    billboard.Size = UDim2.new(0, 150, 0, 16)
    billboard.StudsOffset = Vector3.new(0, 2.2, 0)
    billboard.MaxDistance = 160
    billboard.Adornee = head
    billboard.Parent = model
    local bg = Instance.new("Frame")
    bg.Name = "Background" -- health-bar updaters look for Background/Fill
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(15, 20, 25)
    bg.BorderSizePixel = 1
    bg.BorderColor3 = Color3.fromRGB(255, 215, 60)
    bg.Parent = billboard
    local goblinFill = Instance.new("Frame")
    goblinFill.Name = "Fill"
    goblinFill.Size = UDim2.new(1, 0, 1, 0)
    goblinFill.BackgroundColor3 = Color3.fromRGB(200, 160, 30)
    goblinFill.BorderSizePixel = 0
    goblinFill.Parent = bg
    local title = Instance.new("TextLabel")
    title.ZIndex = 2
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 11
    title.TextColor3 = Color3.fromRGB(255, 230, 120)
    title.Text = "$ LOOT GOBLIN $"
    title.Parent = bg

    DungeonGenerator.SoftenEnemyVisuals(model)
    CollectionService:AddTag(model, "AimRngEnemy") -- lets clients find & smooth enemy motion (see AimRngClient)
    if spec and spec.DryRun then return model end -- server: stats only (see DungeonRuns)
    if spec and spec.EnemyId then model:SetAttribute("EnemyId", spec.EnemyId) end
    if config.RunId then model:SetAttribute("RunId", config.RunId) end
    model.Parent = parent

    -- Flight AI: darts between random spots of the arena, steering away from the nearest player and back
    -- toward the middle when near a wall (it used to run straight away and pin itself in a corner), with
    -- quick jukes and hops. It escapes after LOOT_GOBLIN_LIFETIME seconds (the server removes it then).
    task.spawn(function()
        local currentPos = spawnPos
        local isBossFloor = ItemData.IsBossConfig(config)
        local layout = DungeonGenerator.GetChamberLayout(isBossFloor)
        local cx, cz = 0, layout.CombatZ
        local gHalf = layout.CombatSize / 2 - 6 -- (0.75: inside the room's walls, not a fixed +-66)
        local minX, maxX = -gHalf, gHalf
        local minZ, maxZ = layout.CombatZ - gHalf, layout.CombatZ + gHalf
        local born = os.clock()
        local target = currentPos
        local nextPick = 0
        local speed = 22 + 10 * math.min(1.4, DungeonGenerator.BossBotSkill(config).Speed) -- studs/s (BOT MOVEMENT POE review: a map's old pace)
        -- (2026-10-07, owner: "Loot goblins sometimes bug out and glitch about the map": it moved in 20 Hz jumps, flipped
        -- to a new random direction AND height every tick it was blocked, and spun fast. Now it steers a smoothed
        -- velocity every frame, hovers at one bobbing height, and only re-picks after being blocked for a moment.)
        local vel = Vector3.zero
        local stuckFor = 0
        local hover = 7
        local last = os.clock()
        while model.Parent do
            local now = os.clock()
            local dt = math.min(now - last, 0.1)
            last = now
            local left = DungeonGenerator.LOOT_GOBLIN_LIFETIME - (now - born)
            title.Text = string.format("$ LOOT GOBLIN $  %ds", math.max(0, math.ceil(left)))
            local nearest: BasePart? = nil
            local minDist = math.huge
            for _, player in ipairs(TargetPlayers(config)) do
                local c = player.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
                if hrp and hrp.Position.Z > 450 then
                    local d = (hrp.Position - currentPos).Magnitude
                    if d < minDist then minDist = d; nearest = hrp end
                end
            end
            if now >= nextPick or stuckFor > 0.35 or (Vector3.new(target.X - currentPos.X, 0, target.Z - currentPos.Z)).Magnitude < 3 then
                local dir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
                if nearest then
                    local away = Vector3.new(currentPos.X - nearest.Position.X, 0, currentPos.Z - nearest.Position.Z)
                    if away.Magnitude > 0.1 then dir += away.Unit * (minDist < 30 and 0.9 or 0.35) end
                end
                local toMid = Vector3.new(cx - currentPos.X, 0, cz - currentPos.Z)
                local edge = math.max(math.abs(currentPos.X - cx) / 66, math.abs(currentPos.Z - cz) / 66)
                if edge > 0.6 and toMid.Magnitude > 0.1 then dir += toMid.Unit * (edge - 0.4) * 2.5 end
                if stuckFor > 0.35 and toMid.Magnitude > 0.1 then dir = toMid.Unit + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) end -- (blocked: head for open floor)
                if dir.Magnitude < 0.05 then dir = Vector3.new(1, 0, 0) end
                local dist = 14 + math.random() * 18
                target = currentPos + dir.Unit * dist
                target = Vector3.new(math.clamp(target.X, minX, maxX), 0, math.clamp(target.Z, minZ, maxZ))
                nextPick = now + 0.7 + math.random() * 0.7
                stuckFor = 0
            end
            -- steer: the velocity eases toward the wanted direction (no instant flips)
            local want = Vector3.new(target.X - currentPos.X, 0, target.Z - currentPos.Z)
            want = (want.Magnitude > 0.1) and want.Unit * speed or Vector3.zero
            vel = vel:Lerp(want, 1 - math.exp(-6 * dt))
            local from = Vector3.new(currentPos.X, hover, currentPos.Z)
            local stepped = DungeonGenerator.SteerStep(from, from + vel * dt, vel.Magnitude * dt, 1.2, config.Geo)
            local moved = (Vector3.new(stepped.X - currentPos.X, 0, stepped.Z - currentPos.Z)).Magnitude
            if vel.Magnitude * dt > 0.05 and moved < vel.Magnitude * dt * 0.3 then stuckFor += dt else stuckFor = math.max(0, stuckFor - dt) end
            currentPos = Vector3.new(math.clamp(stepped.X, minX, maxX), hover + math.sin(now * 3) * 0.8, math.clamp(stepped.Z, minZ, maxZ))
            local face = (vel.Magnitude > 0.5) and math.atan2(-vel.X, -vel.Z) or 0
            model:PivotTo(CFrame.new(currentPos) * CFrame.Angles(0, face, 0))
            if not IS_CLIENT and left <= 0 then -- (party runs: the server owns it)
                if DungeonGenerator.OnGoblinEscaped then DungeonGenerator.OnGoblinEscaped(model) end
                model:Destroy()
                break
            end
            if IS_CLIENT then RunService.Heartbeat:Wait() else task.wait(0.05) end
        end
    end)

    return model
end

-- ==================== [SHARED BOSS MOVEMENT: continuous repositioning so bosses are real moving targets] ====================
-- Every boss below used to only rotate in place to face the nearest player, occasionally SNAPPING to a
-- new spot every several seconds (or, for a couple of them, never moving from spawnPos at all) -- which
-- made them trivial stationary turrets almost the whole fight. BOSS_MOVE_SPEED sets how fast a boss
-- drifts (studs/sec) toward its frequently-refreshed strafe target; each boss loop below interpolates
-- `currentPos` toward that target every tick instead of teleporting, so they're always weaving and have
-- to be tracked/led, not just point-and-clicked.
local BOSS_MOVE_SPEED_BASE = 15

local function StepTowards(currentPos: Vector3, targetPos: Vector3, studsPerSec: number, dt: number, geo: Instance?): Vector3
    local delta = targetPos - currentPos
    local dist = delta.Magnitude
    if dist < 0.05 then return currentPos end
    return DungeonGenerator.SteerStep(currentPos, targetPos, math.min(dist, studsPerSec * dt), 4.5, geo)
end

-- BOSS HIT EASE (owner 2026-10-05: "Boss attacks ... a lot of them just insta kill you"): measured with a geared, on-level
-- treesim character, a plain (x1) boss hit took 15% of its health on Easy but 45-61% from Cataclysm up -- and the heavy
-- moves are x1.4-2.0. This scales boss hits so a plain one is ~15% (Easy) -> ~35% (Singularity) of an on-level character's
-- health; heavy moves stay heavy, and CombatServer.ONE_HIT_CAP stops any single hit taking more than 70%.
DungeonGenerator.BOSS_HIT_EASE = { Easy = 1.0, Normal = 0.95, Hard = 0.79, Brutal = 0.72, Nightmare = 0.65, Torment = 0.62, Cataclysm = 0.6,
    Oblivion = 0.7, Ruin = 0.6, Dread = 0.63, Apocalypse = 0.54, Annihilation = 0.6, Eternity = 0.68, Singularity = 0.59, Endless = 0.65 }
-- HUMAN-SIZED BOSSES (0.62, owner: "make the bosses way harder in terms of shootability. They should be human sized / way
-- smaller, and far harder to hit. You can lower their health a bit to compensate. Apply this to ALL bosses"): every boss
-- model is shrunk (Model:ScaleTo, weak spots + decorations with it) so its height / width is at most BOSS_SIZE studs (a
-- Roblox character is ~5); its lowest point stays where it was, so walkers keep their feet on the floor. BossAI.Pose scales
-- its hinges by the model's scale. BOSS_HP_SIZE trims every boss's health (applied in each Create*, so the server's DryRun
-- stats match).
DungeonGenerator.BOSS_SIZE = 7.2 -- (0.62, owner: "make some of them like 10% bigger": 6.5 -> 7.2)
DungeonGenerator.BOSS_HP_SIZE = 0.6 -- (0.62, owner: "drop the hp a bit more": 0.75 -> 0.6)
-- (2026-10-14, owner: "Final stage bosses are way too grindy. Reduce their health by like 30%"): the boss on a run's LAST
-- floor (the superboss on Hard+, the apex Titan / major on Easy / Normal) takes x0.7 health. Not Endless, trials, maps, raids.
DungeonGenerator.FINAL_BOSS_HP = 0.7
function DungeonGenerator.FinalBossHpMult(config: any): number
    if config.Endless or config.BossTrial or config.AscTrial or config.Raid or config.MapGuardian then return 1 end
    local mode = ItemData.RunMode(config.Difficulty, false)
    return (mode and config.FloorNumber == mode.MaxWaves) and DungeonGenerator.FINAL_BOSS_HP or 1
end
-- ==================== BOSS PACE (0.99u, owner: "Bosses are still tedious to kill and fight, they just feel like bullet
-- sponges" -> picked SHORT fights: mini-bosses ~15 s, major / floor bosses ~30 s, superbosses / run finales ~60 s, "bosses become
-- a quick spike in the run, not an event") ====================
-- Every boss's health now comes from a FIGHT TIME: seconds x the damage an ON-LEVEL player with a DECENT build deals at the
-- boss's monster level. The 0.99t scaling check measured the five-class geomean (optimal treesim build + gear, 35% weak spots)
-- killing a 100 x HealthMult x EnemyHpIndex x LevelCurve bot in 2.2 x HealthMult s, so that DPS is 100 x EnemyHpIndex(ML) x
-- LevelCurve(ML) / 2.2; a decent build = BOSS_DECENT (0.65) of it. Bosses take full damage outside aim rounds now (BossAI), so
-- the seconds ARE the fight. Tiers still climb a little: x (HealthMult / 0.66) ^ BOSS_TIER_SLOPE (Hard 0.95 .. Singularity 1.19).
-- The old per-boss base numbers (1100 / 3200 / 7500 / 9000 ...), BOSS_HP_SIZE, FINAL_BOSS_HP and BossTrials.HpScale no longer
-- set boss health; the finale rule lives in the seconds (Easy / Normal finale major x1.5, superboss 60 s).
-- Endless keeps its per-floor climb (+3% a floor on top); party health (spec.HealthScale), trial tiers, weekly / apex
-- modifiers, map tiers and floor mods still multiply on top.
DungeonGenerator.BOSS_DECENT = 0.65
DungeonGenerator.BOSS_TIER_SLOPE = 0.2
-- (2026-10-22 KILL PACE, owner: "Elite rooms take forever, and bosses too": these are seconds of PERFECT decent-build fire;
-- with misses + reloads a fight runs ~1.5x them. Was mini 15, floor 30, super 60, trials 45 / 60, guardian 30 -> real fights of
-- ~25 s / ~45 s / ~90 s. Now ~11 s / ~20 s / ~38 s real.)
DungeonGenerator.BOSS_PACE = {
    Goliath = 7, Phantom = 6.5, Sentinel = 8, Ravager = 7, Hexcaller = 6.5, -- mini-bosses (~7 s of fire, ~11 s real)
    Titan = 13, Lite = 12, FinaleMajor = 1.5, -- floor bosses (~13 s, ~20 s real); the Titan / Lite as an Easy / Normal finale x1.5
    Super = 24, -- the biome superboss (the run finale on Hard+, raids): ~38 s real
    Trial = 20, MajorTrial = 24, Ascendant = 24, Guardian = 13, -- Boss Trials (tier I), The Ascendant (tier I), map guardians
}
-- (2026-10-22, owner after the autoplay pace runs: an average build lost to the floor-6 superboss on Brutal and on Ruin) the run's
-- FINALE superboss (Hard+ floor 6, IsFinale, not the Lite major) is ~20% easier: x0.8 health (a fifth shorter fight) and x0.9
-- damage. Superbosses anywhere else (raids, Endless), the Easy / Normal finale majors and every other boss are unchanged.
-- (2026-10-22 MEASURED, owner "measure a real build first"): the boss pace's "decent build" is right for a player AT the finale's
-- monster level (Ruin floor 6 = ML 130: an L130 treesim kit + a level-12 4-link killed the 475M finale in ~65 s, autoplay, real aim).
-- But a Ruin run is played from L98 (Dread opens at 125), and the finale sits at the TOP of the tier's monster-level ramp: an L110
-- kit with a level-10 4-link (Overcharge / Added Heat / Rapid / Chain: x2.0 its plain DPS) did ~2.3M/s -> 475M = ~205 s and lost
-- 3 lives in ~140 s. Health x0.45 (~105 s for that L110 kit, ~30 s on-level) and damage x0.8.
DungeonGenerator.FINALE_SUPER = { Hp = 0.45, Dmg = 0.8 }
function DungeonGenerator.BossHp(config: any, seconds: number): number
    local ml = config.PowerLevel or DungeonGenerator.MonsterLevel(config) -- (MAP PACING 2026-10-31: a map's power level, Rifts.PowerLevel)
    local diff = DifficultyScaling[config.Difficulty] or DifficultyScaling.Hard
    local dps = 100 * ItemData.EnemyHpIndex(ml) * ItemData.LevelCurve(ml) / 2.2 * DungeonGenerator.BOSS_DECENT
    local tierK = (diff.HealthMult / 0.66) ^ DungeonGenerator.BOSS_TIER_SLOPE
    local floorK = config.Endless and (1 + (math.max(1, config.FloorNumber or 1) - 1) * 0.03) or 1
    return math.max(1, math.round(seconds * dps * tierK * floorK * DungeonGenerator.RampHp(config, true))) -- (RUN PACE 2026-10-24: a run's bosses too)
end
-- a run's LAST floor (the finale): Easy / Normal end on a Titan / Lite (x BOSS_PACE.FinaleMajor)
function DungeonGenerator.IsFinale(config: any): boolean
    if config.Endless or config.BossTrial or config.AscTrial or config.Raid or config.MapGuardian then return false end
    local mode = ItemData.RunMode(config.Difficulty, false)
    return mode ~= nil and config.FloorNumber == mode.MaxWaves
end
-- (0.62, owner: "Make them even faster"): every boss moves BOSS_SPEED x faster -- chase speed, orbit rate and the
-- signature side-strafe's sweep (BossAI d.Boost). Turn rhythm unchanged: faster, not twitchier.
DungeonGenerator.BOSS_SPEED = 1.5
local function ShrinkBoss(model: Model, spawnPos: Vector3): Vector3
    local pivot = model:GetPivot()
    local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p.Transparency < 0.9 then -- (the invisible root / an idle shield don't count)
            local cf, h = pivot:ToObjectSpace(p.CFrame), p.Size / 2
            for _, c in ipairs({ Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
                Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) }) do
                local v = cf * (h * c)
                lo, hi = lo:Min(v), hi:Max(v)
            end
        end
    end
    if lo.X == math.huge then return spawnPos end
    local ext = hi - lo
    local k = math.min(1, DungeonGenerator.BOSS_SIZE / math.max(ext.Y, ext.X, ext.Z, 0.1)) -- (its full length too: the Ravager was 12 long)
    if k > 0.97 then return spawnPos end
    -- (out of the world while it shrinks: the client's enemy smoothing registers a model the moment it's parented and kept
    -- re-drawing the full-size part positions -- small parts spread over a full-size body. Re-parenting re-registers it.)
    local parent = model.Parent
    model.Parent = nil
    model:ScaleTo(model:GetScale() * k)
    local pos = spawnPos + Vector3.new(0, lo.Y * (1 - k), 0) -- (keep the lowest point at the same height)
    -- (0.62, owner: "A lot of the bosses get stuck in the floor now that theyre smaller"): a full-size body sat partly
    -- sunk in the floor and hid it; small, it reads as stuck. Its lowest point now clears the floor.
    local bottom = pos.Y + lo.Y * k
    local floorTop = 2 -- (= FLOOR_TOP, declared further down this file)
    if bottom < floorTop + 0.3 then pos += Vector3.new(0, floorTop + 0.3 - bottom, 0) end
    model:PivotTo(pivot.Rotation + pos)
    model.Parent = parent
    return pos
end
-- What BossAI needs from the dungeon (arena bounds, targets, hits, summons)
local function BossDeps(model: Model, spawnPos: Vector3, config: DungeonConfig, bossDmg: number): any
    bossDmg *= DungeonGenerator.BOSS_HIT_EASE[config.Difficulty] or 0.7
    spawnPos = ShrinkBoss(model, spawnPos)
    local layout = DungeonGenerator.GetChamberLayout(ItemData.IsBossConfig(config)) -- (0.62: a miniboss on a regular floor too)
    local half = layout.CombatSize / 2 - 8
    -- (0.62) on a BOSS ARENA floor the fight floor is a disc (radius 84, a curb ring just outside): bosses stay 8 inside it
    local arenaR = ItemData.IsBossConfig(config) and (84 - 8) or nil
    if RunService:IsStudio() then -- (BOT MOVEMENT POE review, Studio check: the boss's movement inputs -- base speed x the skill it reads)
        model:SetAttribute("DevBossSpeed", BOSS_MOVE_SPEED_BASE * DungeonGenerator.BossBotSkill(config).Speed)
        model:SetAttribute("DevBossSkill", config.BossSkill or config.BotSkill or 4)
    end
    return {
        SpawnPos = spawnPos, Geo = config.Geo, Fx = FxParent(config), Windup = WindupScale(config),
        Speed = BOSS_MOVE_SPEED_BASE * DungeonGenerator.BossBotSkill(config).Speed, Boost = DungeonGenerator.BOSS_SPEED, -- (BOT MOVEMENT POE review: a map guardian keeps its old pace)
        Bounds = { MinX = -math.min(50, half), MaxX = math.min(50, half), MinZ = layout.CombatZ - half, MaxZ = layout.CombatZ + half, R = arenaR, CX = 0, CZ = layout.CombatZ },
        Targets = function() return TargetPlayers(config) end,
        Hit = function(p, mult) DungeonGenerator.HitPlayer(p, math.round(bossDmg * (mult or 1)), config, nil, nil, model) end,
        SetTakenMult = DungeonGenerator.SetTakenMult,
        Step = function(cur, want, speed, dt) return StepTowards(cur, want, speed, dt, config.Geo) end,
        Summon = function(spots) DungeonGenerator.RequestSummon(model, "Scout", spots) end,
        LiveAdds = function() return DungeonGenerator.LiveAdds(config) end,
    }
end

-- ==================== [MINI-BOSS: GOLIATH ENFORCER (WAVES 5, 15, 25)] ====================
function DungeonGenerator.CreateMiniBossGoliath(spawnPos: Vector3, config: DungeonConfig, parent: Instance?, spec: any?): Model
    local diff = DifficultyScaling[config.Difficulty] or DifficultyScaling.Easy
    local floorBonus = DungeonGenerator.GetScalingMultiplier(config, 0.12)
    local palette = BiomePalettes[config.Biome] or BiomePalettes.Fire

    local isBossFloor = ItemData.IsBossConfig(config)
    local layout = DungeonGenerator.GetChamberLayout(isBossFloor)

    local model = Instance.new("Model")
    model.Name = "GoliathMiniBoss"

    local bossHp = DungeonGenerator.BossHp(config, DungeonGenerator.BOSS_PACE.Goliath) -- (0.99u BOSS PACE: health from the fight time)
    local bossDmg = math.round(18 * diff.Damage * DungeonGenerator.DmgScale(config) * 0.1 * floorBonus)
    if spec and spec.MaxHealth then bossHp = spec.MaxHealth end
    if spec and spec.HealthScale then bossHp = math.max(1, math.round(bossHp * spec.HealthScale)) end
    if spec and spec.AttackDamage then bossDmg = spec.AttackDamage end
    model:SetAttribute("AttackDamage", bossDmg)

    model:SetAttribute("Health", bossHp)
    model:SetAttribute("MaxHealth", bossHp)
    model:SetAttribute("IsBoss", true)
    model:SetAttribute("IsMiniBoss", true)
    model:SetAttribute("XpReward", DungeonGenerator.EnemyXp(config, 10))
    model:SetAttribute("GoldReward", math.round(diff.GoldMax * 2.8 * DungeonGenerator.GetRewardMultiplier(config)))

    local root = MakePart({
        Name = "DroneRoot",
        Size = Vector3.new(5, 5, 5),
        Position = spawnPos,
        Transparency = 1,
        CanCollide = false, CanTouch = false, CanQuery = false,
        Anchored = true,
        Parent = model,
    })
    model.PrimaryPart = root

    -- Armored Quad Frame
    local chassis = MakePart({
        Name = "Torso",
        Size = Vector3.new(7, 6, 6),
        CFrame = CFrame.new(spawnPos),
        BrickColor = BrickColor.new("Dark stone grey"),
        Material = Enum.Material.DiamondPlate,
        Parent = model,
    })

    -- Frontal Kinetic Shield (Toggles during Move 3)
    local shield = MakePart({
        Name = "BarrierShield",
        Size = Vector3.new(9, 8, 0.5),
        CFrame = CFrame.new(spawnPos + Vector3.new(0, 0, -3.5)),
        BrickColor = BrickColor.new("Bright blue"),
        Material = Enum.Material.Neon,
        Transparency = 0.9, -- Inactive by default
        CanCollide = false,
        Parent = model,
    })

    -- Glowing Core Weakspot on BACK (Encourages flanking!)
    local rearCore = MakePart({
        Name = "Core",
        Shape = Enum.PartType.Ball,
        Size = Vector3.new(2.8, 2.8, 2.8),
        CFrame = CFrame.new(spawnPos + Vector3.new(0, 0.5, 3.2)),
        BrickColor = BrickColor.new("Really red"),
        Material = Enum.Material.Neon,
        Parent = model,
    })

    -- Glowing Sensor Visor
    local visor = MakePart({
        Name = "Head",
        Size = Vector3.new(3.5, 1.2, 1.5),
        CFrame = CFrame.new(spawnPos + Vector3.new(0, 2.6, -3.1)),
        BrickColor = BrickColor.new("Bright yellow"),
        Material = Enum.Material.Neon,
        Parent = model,
    })

    for _, p in ipairs({ chassis, rearCore, visor }) do
        p:SetAttribute("Damageable", true)
    end

    -- Billboard Health Bar
    local bb = Instance.new("BillboardGui")
    bb.Name = "HealthHUD"
    bb.Enabled = false -- (never shown: EnemyBars draws every bar; an enabled one doubled the name + bar)
    bb.Size = UDim2.new(0, 220, 0, 28)
    bb.StudsOffset = Vector3.new(0, 7.5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 150
    bb.Adornee = visor
    bb.Parent = model

    local bg = Instance.new("Frame")
    bg.Name = "Background"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    bg.BorderSizePixel = 2
    bg.BorderColor3 = Color3.fromRGB(255, 140, 20)
    bg.Parent = bb

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 140, 20)
    fill.BorderSizePixel = 0
    fill.Parent = bg

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 12
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "◆ GOLIATH ENFORCER (WAVE " .. config.FloorNumber .. " MINI-BOSS) ◆"
    title.Parent = bg

    if not (spec and spec.DryRun) then EnemyModels.DecorateBoss(model, "Goliath", spawnPos, config.Biome) end -- the boss silhouette (EnemyModels)
    DungeonGenerator.SoftenEnemyVisuals(model)
    CollectionService:AddTag(model, "AimRngEnemy") -- lets clients find & smooth enemy motion (see AimRngClient)
    if spec and spec.DryRun then return model end -- server: stats only (see DungeonRuns)
    if spec and spec.EnemyId then model:SetAttribute("EnemyId", spec.EnemyId) end
    if config.RunId then model:SetAttribute("RunId", config.RunId) end
    model.Parent = parent

    -- fight brain: BossAI (boss revamp stage 2) -- phases, telegraphed area attacks, custom VFX
    BossAI.Run("Goliath", model, config, BossDeps(model, spawnPos, config, bossDmg))

    return model
end

-- ==================== [MINI-BOSS: PHANTOM STALKER (ALTERNATE WAVES 5/15/25 MINI-BOSS)] ====================
function DungeonGenerator.CreateMiniBossPhantom(spawnPos: Vector3, config: DungeonConfig, parent: Instance?, spec: any?): Model
    local diff = DifficultyScaling[config.Difficulty] or DifficultyScaling.Easy
    local floorBonus = DungeonGenerator.GetScalingMultiplier(config, 0.12)

    local model = Instance.new("Model")
    model.Name = "PhantomMiniBoss"

    local bossHp = DungeonGenerator.BossHp(config, DungeonGenerator.BOSS_PACE.Phantom) -- (0.99u BOSS PACE)
    local bossDmg = math.round(20 * diff.Damage * DungeonGenerator.DmgScale(config) * 0.1 * floorBonus)
    if spec and spec.MaxHealth then bossHp = spec.MaxHealth end
    if spec and spec.HealthScale then bossHp = math.max(1, math.round(bossHp * spec.HealthScale)) end
    if spec and spec.AttackDamage then bossDmg = spec.AttackDamage end
    model:SetAttribute("AttackDamage", bossDmg)

    model:SetAttribute("Health", bossHp)
    model:SetAttribute("MaxHealth", bossHp)
    model:SetAttribute("IsBoss", true)
    model:SetAttribute("IsMiniBoss", true)
    model:SetAttribute("XpReward", DungeonGenerator.EnemyXp(config, 10))
    model:SetAttribute("GoldReward", math.round(diff.GoldMax * 2.9 * DungeonGenerator.GetRewardMultiplier(config)))

    local root = MakePart({
        Name = "DroneRoot", Size = Vector3.new(4, 4, 4), Position = spawnPos, Transparency = 1,
        CanCollide = false, CanTouch = false, CanQuery = false, Anchored = true, Parent = model,
    })
    model.PrimaryPart = root

    local chassis = MakePart({
        Name = "Torso", Shape = Enum.PartType.Ball, Size = Vector3.new(4.6, 5.4, 4.6), CFrame = CFrame.new(spawnPos),
        BrickColor = BrickColor.new("Black"), Material = Enum.Material.Neon, Transparency = 0.35, Parent = model,
    })
    local core = MakePart({
        Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(2.0, 2.0, 2.0),
        CFrame = CFrame.new(spawnPos + Vector3.new(0, 0.3, 0)), BrickColor = BrickColor.new("Bright violet"), Material = Enum.Material.Neon, Parent = model,
    })
    local head = MakePart({
        Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8),
        CFrame = CFrame.new(spawnPos + Vector3.new(0, 3.4, 0)), BrickColor = BrickColor.new("Bright violet"), Material = Enum.Material.Neon,
        Transparency = 0.35, Parent = model,
    })
    local coreLight = Instance.new("PointLight")
    coreLight.Color = Color3.fromRGB(180, 40, 255)
    coreLight.Range = 24
    coreLight.Brightness = 3.5
    coreLight.Parent = core

    for _, p in ipairs({ chassis, core, head }) do
        p:SetAttribute("Damageable", true)
    end

    local bb = Instance.new("BillboardGui")
    bb.Name = "HealthHUD"
    bb.Enabled = false -- (never shown: EnemyBars draws every bar; an enabled one doubled the name + bar)
    bb.Size = UDim2.new(0, 220, 0, 28)
    bb.StudsOffset = Vector3.new(0, 5.5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 150
    bb.Adornee = head
    bb.Parent = model
    local bg = Instance.new("Frame")
    bg.Name = "Background"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    bg.BorderSizePixel = 2
    bg.BorderColor3 = Color3.fromRGB(180, 40, 255)
    bg.Parent = bb
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(180, 40, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bg
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 12
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "\u{25C6} PHANTOM STALKER (WAVE " .. config.FloorNumber .. " MINI-BOSS) \u{25C6}"
    title.Parent = bg

    if not (spec and spec.DryRun) then EnemyModels.DecorateBoss(model, "Phantom", spawnPos, config.Biome) end -- the boss silhouette (EnemyModels)
    DungeonGenerator.SoftenEnemyVisuals(model)
    CollectionService:AddTag(model, "AimRngEnemy") -- lets clients find & smooth enemy motion (see AimRngClient)
    if spec and spec.DryRun then return model end -- server: stats only (see DungeonRuns)
    if spec and spec.EnemyId then model:SetAttribute("EnemyId", spec.EnemyId) end
    if config.RunId then model:SetAttribute("RunId", config.RunId) end
    model.Parent = parent

    -- fight brain: BossAI (boss revamp stage 2) -- phases, telegraphed area attacks, custom VFX
    BossAI.Run("Phantom", model, config, BossDeps(model, spawnPos, config, bossDmg))

    return model
end

-- ==================== [MINI-BOSSES: RAVAGER + HEXCALLER (2026-10-07, owner: "More miniboss variation is needed")] ====================
-- Same contract as the Phantom (Torso / Core / Head hit zones, a DroneRoot pivot, attributes, BossAI.Run); the body
-- shapes + dress live in EnemyModels.DecorateBoss, the fights in BossAI (KITS / SIG Ravager, Hexcaller).
DungeonGenerator.CUSTOM_MINI = {
    Ravager = { Name = "RavagerMiniBoss", Title = "RAVAGER", Hp = 1000, Dmg = 22, Gold = 2.9, Color = Color3.fromRGB(255, 96, 60),
        Torso = Vector3.new(6, 4.4, 8), TorsoShape = Enum.PartType.Block, Head = { Size = Vector3.new(2.6, 2.4, 2.6), At = Vector3.new(0, 1.2, -5) },
        Core = { Size = Vector3.new(1.6, 1.6, 1.6), At = Vector3.new(0, 1.6, 2.6) } },
    Hexcaller = { Name = "HexcallerMiniBoss", Title = "HEXCALLER", Hp = 900, Dmg = 20, Gold = 2.9, Color = Color3.fromRGB(70, 235, 190),
        Torso = Vector3.new(4.4, 6, 4.4), TorsoShape = Enum.PartType.Ball, Head = { Size = Vector3.new(1.8, 1.8, 1.8), At = Vector3.new(0, 3.8, 0) },
        Core = { Size = Vector3.new(1.8, 1.8, 1.8), At = Vector3.new(0, 0.6, -1.4) } },
}
function DungeonGenerator.CreateMiniBossCustom(kind: string, spawnPos: Vector3, config: DungeonConfig, parent: Instance?, spec: any?): Model
    local def = DungeonGenerator.CUSTOM_MINI[kind]
    local diff = DifficultyScaling[config.Difficulty] or DifficultyScaling.Easy
    local floorBonus = DungeonGenerator.GetScalingMultiplier(config, 0.12)
    local model = Instance.new("Model")
    model.Name = def.Name
    local bossHp = DungeonGenerator.BossHp(config, DungeonGenerator.BOSS_PACE[kind] or 7) -- (0.99u BOSS PACE; def.Hp unused)
    local bossDmg = math.round(def.Dmg * diff.Damage * DungeonGenerator.DmgScale(config) * 0.1 * floorBonus)
    if spec and spec.MaxHealth then bossHp = spec.MaxHealth end
    if spec and spec.HealthScale then bossHp = math.max(1, math.round(bossHp * spec.HealthScale)) end
    if spec and spec.AttackDamage then bossDmg = spec.AttackDamage end
    model:SetAttribute("AttackDamage", bossDmg)
    model:SetAttribute("Health", bossHp)
    model:SetAttribute("MaxHealth", bossHp)
    model:SetAttribute("IsBoss", true)
    model:SetAttribute("IsMiniBoss", true)
    model:SetAttribute("XpReward", DungeonGenerator.EnemyXp(config, 10))
    model:SetAttribute("GoldReward", math.round(diff.GoldMax * def.Gold * DungeonGenerator.GetRewardMultiplier(config)))
    local root = MakePart({ Name = "DroneRoot", Size = Vector3.new(4, 4, 4), Position = spawnPos, Transparency = 1,
        CanCollide = false, CanTouch = false, CanQuery = false, Anchored = true, Parent = model })
    model.PrimaryPart = root
    local torso = MakePart({ Name = "Torso", Shape = def.TorsoShape, Size = def.Torso, CFrame = CFrame.new(spawnPos),
        Color = Color3.fromRGB(30, 26, 32), Material = Enum.Material.SmoothPlastic, Parent = model })
    local core = MakePart({ Name = "Core", Shape = Enum.PartType.Ball, Size = def.Core.Size, CFrame = CFrame.new(spawnPos + def.Core.At),
        Color = def.Color, Material = Enum.Material.Neon, Parent = model })
    local head = MakePart({ Name = "Head", Shape = Enum.PartType.Ball, Size = def.Head.Size, CFrame = CFrame.new(spawnPos + def.Head.At),
        Color = Color3.fromRGB(40, 34, 40), Material = Enum.Material.SmoothPlastic, Parent = model })
    for _, p in ipairs({ torso, core, head }) do p:SetAttribute("Damageable", true) end
    local bb = Instance.new("BillboardGui") -- (never shown: EnemyBars draws every bar; kept for the old adornee lookups)
    bb.Name = "HealthHUD"
    bb.Enabled = false
    bb.Size = UDim2.new(0, 220, 0, 28)
    bb.StudsOffset = Vector3.new(0, 5.5, 0)
    bb.Adornee = head
    bb.Parent = model
    if not (spec and spec.DryRun) then EnemyModels.DecorateBoss(model, kind, spawnPos, config.Biome) end
    DungeonGenerator.SoftenEnemyVisuals(model)
    CollectionService:AddTag(model, "AimRngEnemy")
    if spec and spec.DryRun then return model end
    if spec and spec.EnemyId then model:SetAttribute("EnemyId", spec.EnemyId) end
    if config.RunId then model:SetAttribute("RunId", config.RunId) end
    model.Parent = parent
    BossAI.Run(kind, model, config, BossDeps(model, spawnPos, config, bossDmg))
    return model
end

-- ==================== [MINI-BOSS: BULWARK SENTINEL (ALTERNATE WAVES 5/15/25 MINI-BOSS)] ====================
function DungeonGenerator.CreateMiniBossSentinel(spawnPos: Vector3, config: DungeonConfig, parent: Instance?, spec: any?): Model
    local diff = DifficultyScaling[config.Difficulty] or DifficultyScaling.Easy
    local floorBonus = DungeonGenerator.GetScalingMultiplier(config, 0.12)

    local model = Instance.new("Model")
    model.Name = "SentinelMiniBoss"

    local bossHp = DungeonGenerator.BossHp(config, DungeonGenerator.BOSS_PACE.Sentinel) -- (0.99u BOSS PACE)
    local bossDmg = math.round(16 * diff.Damage * DungeonGenerator.DmgScale(config) * 0.1 * floorBonus)
    if spec and spec.MaxHealth then bossHp = spec.MaxHealth end
    if spec and spec.HealthScale then bossHp = math.max(1, math.round(bossHp * spec.HealthScale)) end
    if spec and spec.AttackDamage then bossDmg = spec.AttackDamage end
    model:SetAttribute("AttackDamage", bossDmg)

    model:SetAttribute("Health", bossHp)
    model:SetAttribute("MaxHealth", bossHp)
    model:SetAttribute("IsBoss", true)
    model:SetAttribute("IsMiniBoss", true)
    model:SetAttribute("XpReward", DungeonGenerator.EnemyXp(config, 10))
    model:SetAttribute("GoldReward", math.round(diff.GoldMax * 3.0 * DungeonGenerator.GetRewardMultiplier(config)))
    model:SetAttribute("DamageTakenMult", 1.0)

    local root = MakePart({
        Name = "DroneRoot", Size = Vector3.new(6, 6, 6), Position = spawnPos, Transparency = 1,
        CanCollide = false, CanTouch = false, CanQuery = false, Anchored = true, Parent = model,
    })
    model.PrimaryPart = root

    local chassis = MakePart({
        Name = "Torso", Size = Vector3.new(8, 9, 8), CFrame = CFrame.new(spawnPos),
        BrickColor = BrickColor.new("Dark stone grey"), Material = Enum.Material.Metal, Parent = model,
    })
    local shieldPanel = MakePart({
        Name = "ShieldPanel", Size = Vector3.new(8.4, 8, 0.6), CFrame = CFrame.new(spawnPos + Vector3.new(0, 0, -4.3)),
        BrickColor = BrickColor.new("Cyan"), Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, Parent = model,
    })
    local core = MakePart({
        Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4),
        CFrame = CFrame.new(spawnPos + Vector3.new(0, 0.5, 4.3)), BrickColor = BrickColor.new("Really red"), Material = Enum.Material.Neon, Parent = model,
    })
    local head = MakePart({
        Name = "Head", Size = Vector3.new(3, 1.3, 1.6), CFrame = CFrame.new(spawnPos + Vector3.new(0, 3.8, -3.9)),
        BrickColor = BrickColor.new("Bright blue"), Material = Enum.Material.Neon, Parent = model,
    })
    local shieldLight = Instance.new("PointLight")
    shieldLight.Color = Color3.fromRGB(80, 200, 255)
    shieldLight.Range = 20
    shieldLight.Brightness = 2.0
    shieldLight.Parent = shieldPanel

    for _, p in ipairs({ chassis, core, head }) do
        p:SetAttribute("Damageable", true)
    end

    local bb = Instance.new("BillboardGui")
    bb.Name = "HealthHUD"
    bb.Enabled = false -- (never shown: EnemyBars draws every bar; an enabled one doubled the name + bar)
    bb.Size = UDim2.new(0, 230, 0, 28)
    bb.StudsOffset = Vector3.new(0, 8.5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 150
    bb.Adornee = head
    bb.Parent = model
    local bg = Instance.new("Frame")
    bg.Name = "Background"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    bg.BorderSizePixel = 2
    bg.BorderColor3 = Color3.fromRGB(80, 200, 255)
    bg.Parent = bb
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(80, 200, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bg
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 12
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "\u{25C6} BULWARK SENTINEL (WAVE " .. config.FloorNumber .. " MINI-BOSS) \u{25C6}"
    title.Parent = bg

    if not (spec and spec.DryRun) then EnemyModels.DecorateBoss(model, "Sentinel", spawnPos, config.Biome) end -- the boss silhouette (EnemyModels)
    DungeonGenerator.SoftenEnemyVisuals(model)
    CollectionService:AddTag(model, "AimRngEnemy") -- lets clients find & smooth enemy motion (see AimRngClient)
    if spec and spec.DryRun then return model end -- server: stats only (see DungeonRuns)
    if spec and spec.EnemyId then model:SetAttribute("EnemyId", spec.EnemyId) end
    if config.RunId then model:SetAttribute("RunId", config.RunId) end
    model.Parent = parent

    -- fight brain: BossAI (boss revamp stage 2) -- phases, telegraphed area attacks, custom VFX
    BossAI.Run("Sentinel", model, config, BossDeps(model, spawnPos, config, bossDmg))

    return model
end

-- ==================== [MAJOR BOSS: APEX TITAN MECH (WAVES 10, 20)] ====================
function DungeonGenerator.CreateMajorBossTitan(spawnPos: Vector3, config: DungeonConfig, parent: Instance?, spec: any?): Model
    local diff = DifficultyScaling[config.Difficulty] or DifficultyScaling.Easy
    local floorBonus = DungeonGenerator.GetScalingMultiplier(config, 0.15)

    local model = Instance.new("Model")
    model.Name = "ApexTitanMech"

    local bossHp = DungeonGenerator.BossHp(config, DungeonGenerator.BOSS_PACE.Titan * (DungeonGenerator.IsFinale(config) and DungeonGenerator.BOSS_PACE.FinaleMajor or 1)) -- (0.99u BOSS PACE)
    local bossDmg = math.round(26 * diff.Damage * DungeonGenerator.DmgScale(config) * 0.1 * floorBonus)
    if spec and spec.MaxHealth then bossHp = spec.MaxHealth end
    if spec and spec.HealthScale then bossHp = math.max(1, math.round(bossHp * spec.HealthScale)) end
    if spec and spec.AttackDamage then bossDmg = spec.AttackDamage end
    model:SetAttribute("AttackDamage", bossDmg)

    model:SetAttribute("Health", bossHp)
    model:SetAttribute("MaxHealth", bossHp)
    model:SetAttribute("IsBoss", true)
    model:SetAttribute("IsMajorBoss", true)
    model:SetAttribute("XpReward", DungeonGenerator.EnemyXp(config, 16))
    model:SetAttribute("GoldReward", math.round(diff.GoldMax * 4.5 * DungeonGenerator.GetRewardMultiplier(config)))

    local root = MakePart({
        Name = "DroneRoot",
        Size = Vector3.new(8, 8, 8),
        Position = spawnPos,
        Transparency = 1,
        CanCollide = false, CanTouch = false, CanQuery = false,
        Anchored = true,
        Parent = model,
    })
    model.PrimaryPart = root

    -- Giant Titan Chassis
    local torso = MakePart({
        Name = "Torso",
        Size = Vector3.new(10, 14, 7),
        CFrame = CFrame.new(spawnPos),
        Anchored = true, CanCollide = true, CanQuery = true,
        BrickColor = BrickColor.new("Black"), Material = Enum.Material.DiamondPlate,
        Parent = model,
    })

    -- Chest Beam Core
    local core = MakePart({
        Name = "Core", Shape = Enum.PartType.Ball,
        Size = Vector3.new(4.2, 4.2, 4.2),
        CFrame = CFrame.new(spawnPos + Vector3.new(0, 2.0, -3.6)),
        Anchored = true, CanCollide = true, CanQuery = true,
        BrickColor = BrickColor.new("Really red"), Material = Enum.Material.Neon,
        Parent = model,
    })

    -- Armored Head Visor
    local head = MakePart({
        Name = "Head", Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(3.0, 3.6, 3.6),
        CFrame = CFrame.new(spawnPos + Vector3.new(0, 8.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        Anchored = true, CanCollide = true, CanQuery = true,
        BrickColor = BrickColor.new("Bright yellow"), Material = Enum.Material.Neon,
        Parent = model,
    })

    for _, p in ipairs({ torso, core, head }) do
        p:SetAttribute("Damageable", true)
    end

    -- Boss Health HUD
    local bb = Instance.new("BillboardGui")
    bb.Name = "HealthHUD"
    bb.Enabled = false -- (never shown: EnemyBars draws every bar; an enabled one doubled the name + bar)
    bb.Size = UDim2.new(0, 280, 0, 34)
    bb.StudsOffset = Vector3.new(0, 12, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 200
    bb.Adornee = head
    bb.Parent = model

    local bg = Instance.new("Frame")
    bg.Name = "Background"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(15, 10, 10)
    bg.BorderSizePixel = 2
    bg.BorderColor3 = Color3.fromRGB(255, 30, 30)
    bg.Parent = bb

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
    fill.BorderSizePixel = 0
    fill.Parent = bg

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 13
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "★ APEX TITAN MECH (WAVE " .. config.FloorNumber .. " MAJOR BOSS) ★"
    title.Parent = bg

    if not (spec and spec.DryRun) then EnemyModels.DecorateBoss(model, "Titan", spawnPos, config.Biome) end -- the boss silhouette (EnemyModels)
    DungeonGenerator.SoftenEnemyVisuals(model)
    CollectionService:AddTag(model, "AimRngEnemy") -- lets clients find & smooth enemy motion (see AimRngClient)
    if spec and spec.DryRun then return model end -- server: stats only (see DungeonRuns)
    if spec and spec.EnemyId then model:SetAttribute("EnemyId", spec.EnemyId) end
    if config.RunId then model:SetAttribute("RunId", config.RunId) end
    model.Parent = parent

    -- fight brain: BossAI (boss revamp stage 2) -- phases, telegraphed area attacks, custom VFX
    BossAI.Run("Titan", model, config, BossDeps(model, spawnPos, config, bossDmg))

    return model
end

-- ==================== [SPECIAL BIOME SUPERBOSS (WAVE 30 HARDEST MODE)] ====================
-- lite = the floor's biome boss as a MAJOR boss (Easy / Normal finales roll it or the Titan -- owner 2026-10-05: "You seem
-- to fight the same final floor boss every time"): the Titan's health / damage / rewards, the biome boss's fight.
function DungeonGenerator.CreateBiomeSuperBoss(spawnPos: Vector3, config: DungeonConfig, parent: Instance?, spec: any?, lite: boolean?): Model
    -- (0.87 WORLDS: a world borrows its sister biome's colossus -- name, body, kit, signature -- on a copy of the config;
    -- the floor keeps its own look)
    local bossOf = DungeonGenerator.NB.BOSS_OF and DungeonGenerator.NB.BOSS_OF[config.Biome]
    if bossOf then
        config = table.clone(config)
        config.Biome = bossOf
    end
    local diff = DifficultyScaling[config.Difficulty] or DifficultyScaling.Hard
    local palette = BiomePalettes[config.Biome] or BiomePalettes.Fire

    local bossNames = {
        Fire = "IGNIS, THE FORGE TYRANT",
        Ice = "THE FROST SOVEREIGN",
        Void = "THE UNBLINKING",
        Cyber = "OMNISCIENCE CORE",
        Storm = "TEMPEST SOVEREIGN",
    }
    local bossName = bossNames[config.Biome] or DungeonGenerator.NB.SUPER_NAMES[config.Biome] or "THE UNBLINKING"

    local model = Instance.new("Model")
    model.Name = "BiomeSuperBoss"

    local superPower = DungeonGenerator.GetScalingMultiplier(config)
    -- (x0.7 since SUPERBOSSES v3: it's immune outside its damage phases, so the same health took ~1.5x as long)
    -- (0.60b, owner: "Im not strong enough to win yet because of how tanky the bosses are": the full superboss 0.7 -> 0.5,
    -- ~2-2.5 min -> ~1.5 min at the expected level; the Lite major keeps its old health)
    -- (0.99u BOSS PACE: the Lite major ~28 s (x1.5 as an Easy / Normal finale), the full superboss ~60 s)
    local bossHp = DungeonGenerator.BossHp(config, lite and (DungeonGenerator.BOSS_PACE.Lite * (DungeonGenerator.IsFinale(config) and DungeonGenerator.BOSS_PACE.FinaleMajor or 1)) or DungeonGenerator.BOSS_PACE.Super)
    local bossDmg = math.round(36 * diff.Damage * DungeonGenerator.DmgScale(config) * 0.1 * superPower * (lite and 0.72 or 1))
    if not lite and DungeonGenerator.IsFinale(config) then -- (FINALE_SUPER: the run's last boss on Hard+)
        bossHp = math.max(1, math.round(bossHp * DungeonGenerator.FINALE_SUPER.Hp))
        bossDmg = math.max(1, math.round(bossDmg * DungeonGenerator.FINALE_SUPER.Dmg))
    end
    if spec and spec.MaxHealth then bossHp = spec.MaxHealth end
    if spec and spec.HealthScale then bossHp = math.max(1, math.round(bossHp * spec.HealthScale)) end
    if spec and spec.AttackDamage then bossDmg = spec.AttackDamage end
    model:SetAttribute("AttackDamage", bossDmg)

    model:SetAttribute("Health", bossHp)
    model:SetAttribute("MaxHealth", bossHp)
    model:SetAttribute("IsBoss", true)
    model:SetAttribute("IsSuperBoss", not lite)
    model:SetAttribute("IsMajorBoss", lite == true)
    model:SetAttribute("Lite", lite == true)
    model:SetAttribute("XpReward", DungeonGenerator.EnemyXp(config, lite and 16 or 36))
    model:SetAttribute("GoldReward", lite and math.round(diff.GoldMax * 4.5 * DungeonGenerator.GetRewardMultiplier(config)) or 4000)

    local root = MakePart({
        Name = "DroneRoot",
        Size = Vector3.new(10, 10, 10),
        Position = spawnPos,
        Transparency = 1,
        CanCollide = false, CanTouch = false, CanQuery = false,
        Anchored = true,
        Parent = model,
    })
    model.PrimaryPart = root

    -- the hit zones, laid out per boss (SUPERBOSSES v3: EnemyModels.SUPER_HITBOX -- a lava titan, an ice warden, an eye, a
    -- server core, a storm angel); EnemyModels.SuperBody dresses them
    local hb = EnemyModels.SUPER_HITBOX[config.Biome] or EnemyModels.SUPER_HITBOX.Fire
    local zones = {}
    for _, nm in ipairs({ "Torso", "Core", "Head" }) do
        local z = hb[nm]
        local p = MakePart({
            Name = nm,
            Shape = (z[3] == "Ball") and Enum.PartType.Ball or Enum.PartType.Block,
            Size = z[1],
            CFrame = CFrame.new(spawnPos + z[2]),
            BrickColor = (nm == "Torso") and palette.WallColor or palette.AccentColor,
            Material = (nm == "Torso") and Enum.Material.DiamondPlate or Enum.Material.Neon,
            Parent = model,
        })
        p:SetAttribute("Damageable", true)
        zones[nm] = p
    end
    local crown = zones.Head

    -- Superboss Giant Health HUD
    local bb = Instance.new("BillboardGui")
    bb.Name = "HealthHUD"
    bb.Enabled = false -- (never shown: EnemyBars draws every bar; an enabled one doubled the name + bar)
    bb.Size = UDim2.new(0, 340, 0, 42)
    bb.StudsOffset = Vector3.new(0, 16, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 300
    bb.Adornee = crown
    bb.Parent = model

    local bg = Instance.new("Frame")
    bg.Name = "Background"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(15, 8, 25)
    bg.BorderSizePixel = 3
    bg.BorderColor3 = palette.AccentColor.Color
    bg.Parent = bb

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = palette.AccentColor.Color
    fill.BorderSizePixel = 0
    fill.Parent = bg

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "✠ [FINAL BIOME SUPERBOSS] " .. bossName .. " ✠"
    title.Parent = bg

    if not (spec and spec.DryRun) then EnemyModels.DecorateBoss(model, "SuperBoss", spawnPos, config.Biome) end -- the boss silhouette (EnemyModels)
    DungeonGenerator.SoftenEnemyVisuals(model)
    CollectionService:AddTag(model, "AimRngEnemy") -- lets clients find & smooth enemy motion (see AimRngClient)
    if spec and spec.DryRun then return model end -- server: stats only (see DungeonRuns)
    if spec and spec.EnemyId then model:SetAttribute("EnemyId", spec.EnemyId) end
    if config.RunId then model:SetAttribute("RunId", config.RunId) end
    model.Parent = parent

    -- fight brain: BossAI (boss revamp stage 2) -- phases, telegraphed area attacks, custom VFX
    BossAI.Run("SuperBoss", model, config, BossDeps(model, spawnPos, config, bossDmg))

    return model
end

-- ==================== [CLEAR ALL FOES ON ARENA EXIT] ====================
function DungeonGenerator.ClearAllEnemies(dungeon: Folder)
    for _, child in ipairs(dungeon:GetChildren()) do
        if child.Name == "AimDrone" or child.Name == "EliteDrone" or child.Name == "LootGoblin" or child.Name == "ApexTitanMech" or child.Name == "GoliathMiniBoss" or child.Name == "PhantomMiniBoss" or child.Name == "SentinelMiniBoss" or child.Name == "RavagerMiniBoss" or child.Name == "HexcallerMiniBoss" or child.Name == "BiomeSuperBoss" then
            child:Destroy()
        end
    end
    for _, item in ipairs(Workspace:GetChildren()) do
        if item.Name == "EnemyPulse" or item.Name == "ShockwaveRing" or item.Name == "SweepingLaser" or item.Name == "SniperLaser" or item.Name == "VolatileCore" then
            item:Destroy()
        end
    end
end

-- ==================== [ENDGAME TRIAL BOSSES (BossTrials): Seraph Archon / Chronarch / Echo Warden / Forgeheart] ====================
-- archetype = "<id>:<tier>" (BossTrials.Encode). Hitboxes (Torso / Core / Head) per boss; EnemyModels.DecorateTrialBoss
-- dresses it; BossAI runs its kit (tier pace on top of the difficulty's). The server scales health by tier.
local TRIAL_BODIES = {
    Archon = { Torso = Vector3.new(5, 8, 3), TorsoColor = Color3.fromRGB(236, 232, 222), CoreSize = 2.2, CorePos = Vector3.new(0, 1.6, -1.7),
        CoreColor = Color3.fromRGB(255, 220, 120), HeadSize = Vector3.new(2.4, 2.4, 2.4), HeadPos = Vector3.new(0, 5.4, 0), HeadColor = Color3.fromRGB(250, 246, 236), Y = 13 },
    Chronarch = { Torso = Vector3.new(9, 9, 3), TorsoColor = Color3.fromRGB(70, 52, 36), CoreSize = 1.8, CorePos = Vector3.new(0, 0, -2.25),
        CoreColor = Color3.fromRGB(90, 230, 255), HeadSize = Vector3.new(3, 2.4, 3), HeadPos = Vector3.new(0, 5.8, 0), HeadColor = Color3.fromRGB(230, 180, 80), Y = 13 },
    EchoWarden = { Torso = Vector3.new(4.5, 9, 4.5), TorsoColor = Color3.fromRGB(34, 20, 52), CoreSize = 2.6, CorePos = Vector3.new(0, 1, -2.4),
        CoreColor = Color3.fromRGB(190, 110, 255), HeadSize = Vector3.new(2.2, 2.2, 2.2), HeadPos = Vector3.new(0, 6, 0), HeadColor = Color3.fromRGB(230, 200, 255), Y = 12 },
    -- a hunched furnace golem: wide slag torso, the furnace mouth (core) low on its chest, a small head sunk between the shoulders
    Forgeheart = { Torso = Vector3.new(9, 8, 6), TorsoColor = Color3.fromRGB(46, 38, 36), CoreSize = 2.4, CorePos = Vector3.new(0, -0.8, -2.4),
        CoreColor = Color3.fromRGB(255, 150, 50), HeadSize = Vector3.new(2.6, 2.6, 2.6), HeadPos = Vector3.new(0, 4.6, -1.2), HeadColor = Color3.fromRGB(40, 32, 30), Y = 10 },
    -- MAJOR BOSSES (0.52; dressed by EnemyModels.MajorDecor)
    Lockwarden = { Torso = Vector3.new(5.2, 10, 5.2), TorsoColor = Color3.fromRGB(96, 108, 124), CoreSize = 2.0, CorePos = Vector3.new(0, 0.6, -4.4),
        CoreColor = Color3.fromRGB(150, 210, 255), HeadSize = Vector3.new(3.6, 2.6, 3.6), HeadPos = Vector3.new(0, 6.2, 0), HeadColor = Color3.fromRGB(80, 90, 104), Y = 11, Mat = Enum.Material.Metal },
    Broodmother = { Torso = Vector3.new(8, 5, 9), TorsoColor = Color3.fromRGB(58, 30, 26), CoreSize = 3.2, CorePos = Vector3.new(0, 1.5, 12.6),
        CoreColor = Color3.fromRGB(255, 120, 40), HeadSize = Vector3.new(3.4, 3, 3.2), HeadPos = Vector3.new(0, -0.2, -4.4), HeadColor = Color3.fromRGB(40, 22, 20), Y = 7, Mat = Enum.Material.Basalt },
    Duelist = { Torso = Vector3.new(3.2, 6.4, 2.2), TorsoColor = Color3.fromRGB(40, 26, 58), CoreSize = 1.2, CorePos = Vector3.new(0, 1.4, -1.2),
        CoreColor = Color3.fromRGB(200, 120, 255), HeadSize = Vector3.new(1.5, 2.2, 1.6), HeadPos = Vector3.new(0, 5.3, 0), HeadColor = Color3.fromRGB(30, 22, 40), Y = 10, Mat = Enum.Material.Fabric },
    FortuneEngine = { Torso = Vector3.new(10.6, 9.6, 5.6), TorsoColor = Color3.fromRGB(120, 20, 40), CoreSize = 2.4, CorePos = Vector3.new(0, 8.6, -0.5),
        CoreColor = Color3.fromRGB(255, 220, 90), HeadSize = Vector3.new(11.4, 2.6, 3.6), HeadPos = Vector3.new(0, 6.4, 0.2), HeadColor = Color3.fromRGB(210, 160, 50), Y = 9, Mat = Enum.Material.SmoothPlastic },
    -- MAPS-ONLY (MAPS V2 2026-10-30): THE LAMPLIGHTER -- a slim human-sized pill (BossLook/Lamplighter; EnemyModels.MajorDecor fallback)
    Lamplighter = { Torso = Vector3.new(2.8, 6.2, 2.2), TorsoColor = Color3.fromRGB(30, 32, 46), CoreSize = 1.1, CorePos = Vector3.new(0, 1.2, -1.1),
        CoreColor = Color3.fromRGB(255, 178, 76), HeadSize = Vector3.new(1.6, 1.6, 1.6), HeadPos = Vector3.new(0, 4.4, 0), HeadColor = Color3.fromRGB(240, 200, 150), Y = 10, Mat = Enum.Material.SmoothPlastic },
}
DungeonGenerator.TRIAL_BODIES = TRIAL_BODIES -- (FUTURE-PROOF: read by ContentCheck)
function DungeonGenerator.CreateTrialBoss(archetype: string?, spawnPos: Vector3, config: DungeonConfig, parent: Instance?, spec: any?): Model
    local BossTrials = require(script.Parent:WaitForChild("BossTrials"))
    local id, tier, guardian = BossTrials.Decode(archetype)
    local def = BossTrials.ById[id or ""] or BossTrials.Bosses[1]
    id = def.Id
    local body = TRIAL_BODIES[id] -- (FUTURE-PROOF: a new trial boss without its own body borrows one instead of crashing)
    if not body then warn("[DungeonGenerator] no TRIAL_BODIES entry for " .. tostring(id)); body = TRIAL_BODIES.Archon or select(2, next(TRIAL_BODIES)) end
    local diff = DifficultyScaling[config.Difficulty] or DifficultyScaling.Hard
    local power = DungeonGenerator.GetScalingMultiplier(config)
    spawnPos = Vector3.new(spawnPos.X, body.Y, spawnPos.Z)

    local model = Instance.new("Model")
    model.Name = "Trial" .. id
    -- (0.99u BOSS PACE: a trial boss ~45 s at tier I, a major ~60 s; the tier's Hp + the weekly / apex health go on top server-side)
    local bossHp = DungeonGenerator.BossHp(config, def.Major and DungeonGenerator.BOSS_PACE.MajorTrial or DungeonGenerator.BOSS_PACE.Trial)
    local bossDmg = math.round(34 * diff.Damage * DungeonGenerator.DmgScale(config) * 0.1 * power)
    if def.Major then -- (0.52 major bosses: the exotic farm -- harder-hitting)
        bossDmg = math.round(bossDmg * BossTrials.MAJOR_DMG)
    end
    if guardian then
        -- MAP GUARDIAN (0.66, Rifts.GUARDIANS): the Titan's health / damage at this map's level, x GUARDIAN_HP (a trial
        -- boss's own numbers are built for a long trial fight, not floor 5 of a timed map)
        local Rifts = require(script.Parent:WaitForChild("Rifts"))
        local fb = DungeonGenerator.GetScalingMultiplier(config, 0.15)
        bossHp = math.round(DungeonGenerator.BossHp(config, DungeonGenerator.BOSS_PACE.Guardian) -- (0.99u BOSS PACE: ~30 s, x the map tier on the server)
            * (def.Major and Rifts.GUARDIAN_HP.Major or Rifts.GUARDIAN_HP.Normal))
        bossDmg = math.round(30 * diff.Damage * DungeonGenerator.DmgScale(config) * 0.1 * fb)
        model:SetAttribute("MapGuardian", true)
    end
    -- THE WEEK (UPDATE 7, Weekly): the weekly boss's modifier (health is the server's: DungeonRuns / PartyRuns). Before the spec
    -- overrides: a client-built solo boss gets the server stand-in's AttackDamage, which already carries it (it was doubled)
    local weeklyMod = (type(config.WeeklyMod) == "string" and config.WeeklyMod ~= "") and require(script.Parent:WaitForChild("Weekly")).Mods[config.WeeklyMod] or nil
    if weeklyMod and weeklyMod.Dmg then bossDmg = math.round(bossDmg * weeklyMod.Dmg) end
    if spec and spec.MaxHealth then bossHp = spec.MaxHealth end
    if spec and spec.HealthScale then bossHp = math.max(1, math.round(bossHp * spec.HealthScale)) end -- (party trials: x players x tier)
    if spec and spec.AttackDamage then bossDmg = spec.AttackDamage end
    model:SetAttribute("AttackDamage", bossDmg)
    model:SetAttribute("Health", bossHp)
    model:SetAttribute("MaxHealth", bossHp)
    model:SetAttribute("IsBoss", true)
    model:SetAttribute("IsMajorBoss", true)
    model:SetAttribute("TrialBoss", id)
    if weeklyMod then model:SetAttribute("WeeklyMod", config.WeeklyMod) end
    model:SetAttribute("XpReward", DungeonGenerator.EnemyXp(config, 20))
    model:SetAttribute("GoldReward", math.round(diff.GoldMax * 5 * DungeonGenerator.GetRewardMultiplier(config)))

    local root = MakePart({ Name = "DroneRoot", Size = Vector3.new(8, 8, 8), Position = spawnPos, Transparency = 1,
        CanCollide = false, CanTouch = false, CanQuery = false, Anchored = true, Parent = model })
    model.PrimaryPart = root
    local torso = MakePart({ Name = "Torso", Size = body.Torso, CFrame = CFrame.new(spawnPos), Anchored = true, CanCollide = true, CanQuery = true,
        Color = body.TorsoColor, Material = body.Mat or ((id == "EchoWarden") and Enum.Material.Glass or (id == "Forgeheart") and Enum.Material.Basalt or Enum.Material.SmoothPlastic), Parent = model })
    local core = MakePart({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(body.CoreSize, body.CoreSize, body.CoreSize),
        CFrame = CFrame.new(spawnPos + body.CorePos), Anchored = true, CanCollide = true, CanQuery = true, Color = body.CoreColor, Material = Enum.Material.Neon, Parent = model })
    core:SetAttribute("Glow", true)
    local head = MakePart({ Name = "Head", Shape = (id == "Chronarch") and Enum.PartType.Block or Enum.PartType.Ball, Size = body.HeadSize,
        CFrame = CFrame.new(spawnPos + body.HeadPos), Anchored = true, CanCollide = true, CanQuery = true, Color = body.HeadColor,
        Material = (id == "Chronarch" or id == "Forgeheart") and Enum.Material.Metal or Enum.Material.SmoothPlastic, Parent = model })
    for _, p in ipairs({ torso, core, head }) do p:SetAttribute("Damageable", true) end

    local bb = Instance.new("BillboardGui") -- (kept for code that looks for it; EnemyBars draws the real bar)
    bb.Name = "HealthHUD"; bb.Size = UDim2.new(0, 10, 0, 10); bb.Adornee = head; bb.Enabled = false; bb.Parent = model
    local lbl = Instance.new("TextLabel"); lbl.Name = "Title"; lbl.Text = def.Name; lbl.Parent = bb

    if not (spec and spec.DryRun) then EnemyModels.DecorateTrialBoss(model, id, spawnPos) end
    DungeonGenerator.SoftenEnemyVisuals(model)
    CollectionService:AddTag(model, "AimRngEnemy")
    if spec and spec.DryRun then return model end
    if spec and spec.EnemyId then model:SetAttribute("EnemyId", spec.EnemyId) end
    if config.RunId then model:SetAttribute("RunId", config.RunId) end
    model.Parent = parent

    local t = BossTrials.Tiers[tier] or BossTrials.Tiers[1]
    local cfg = table.clone(config)
    cfg.TrialPace = t.Pace
    cfg.TrialTier = tier
    cfg.MajorBoss = def.Major == true
    cfg.EnrageAt = BossTrials.ENRAGE -- (BossAI: every trial boss enrages; its signature runs in the trial too)
    if guardian then -- (MAPS V2: the map band 1.. (Ruin = 1) -- BossAI M.AimNeed asks a little more of the target rounds a band)
        local okR, RF = pcall(require, script.Parent:WaitForChild("Rifts"))
        cfg.GuardianBand = okR and table.find(RF.LADDER, config.Difficulty) or 1
    end
    if weeklyMod then
        if weeklyMod.Pace then cfg.TrialPace *= weeklyMod.Pace end
        if weeklyMod.Enrage then cfg.EnrageAt = weeklyMod.Enrage end
    end
    if game:GetService("RunService"):IsStudio() and tonumber(workspace:GetAttribute("DevEnrageAt")) then
        cfg.EnrageAt = tonumber(workspace:GetAttribute("DevEnrageAt")) -- (Studio test hook: enrage after N seconds)
    end
    BossAI.Run(id, model, cfg, BossDeps(model, spawnPos, config, bossDmg))
    return model
end

-- ==================== [THE ASCENDANT: the Trial of Ascension's boss (AscensionTrials)] ====================
-- archetype = the trial tier ("1".."4"). Its tier health / pace are applied HERE (the server's stand-in is built by this
-- same code), a party's x players comes in through spec.HealthScale. EnemyModels.DecorateAscendant dresses it, BossAI
-- runs KITS.Ascendant + SIG.Ascendant (the three trials).
function DungeonGenerator.CreateAscendant(archetype: string?, spawnPos: Vector3, config: DungeonConfig, parent: Instance?, spec: any?): Model
    local AscensionTrials = require(script.Parent:WaitForChild("AscensionTrials"))
    local tier = math.clamp(tonumber(archetype) or 1, 1, AscensionTrials.MAX_TIER)
    local t = AscensionTrials.Tiers[tier]
    local diff = DifficultyScaling[config.Difficulty] or DifficultyScaling.Hard
    local power = DungeonGenerator.GetScalingMultiplier(config)
    spawnPos = Vector3.new(spawnPos.X, 12, spawnPos.Z)
    local model = Instance.new("Model")
    model.Name = "AscendantBoss"
    local bossHp = math.round(DungeonGenerator.BossHp(config, DungeonGenerator.BOSS_PACE.Ascendant) * t.Hp) -- (0.99u BOSS PACE: ~60 s at tier I)
    local bossDmg = math.round(34 * diff.Damage * DungeonGenerator.DmgScale(config) * 0.1 * power)
    if spec and spec.MaxHealth then bossHp = spec.MaxHealth end
    if spec and spec.HealthScale then bossHp = math.max(1, math.round(bossHp * spec.HealthScale)) end
    if spec and spec.AttackDamage then bossDmg = spec.AttackDamage end
    model:SetAttribute("AttackDamage", bossDmg)
    model:SetAttribute("Health", bossHp)
    model:SetAttribute("MaxHealth", bossHp)
    model:SetAttribute("IsBoss", true)
    model:SetAttribute("IsMajorBoss", true)
    model:SetAttribute("AscendantTier", tier)
    model:SetAttribute("XpReward", DungeonGenerator.EnemyXp(config, 24))
    model:SetAttribute("GoldReward", math.round(diff.GoldMax * 6 * DungeonGenerator.GetRewardMultiplier(config)))
    local root = MakePart({ Name = "DroneRoot", Size = Vector3.new(8, 8, 8), Position = spawnPos, Transparency = 1,
        CanCollide = false, CanTouch = false, CanQuery = false, Anchored = true, Parent = model })
    model.PrimaryPart = root
    local zones = {
        { "Torso", Vector3.new(5, 9, 3.4), Vector3.new(0, 0, 0), nil, Color3.fromRGB(26, 28, 38), Enum.Material.Slate },
        { "Core", Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 1.4, -1.9), "Ball", AscensionTrials.Color, Enum.Material.Neon },
        { "Head", Vector3.new(2.4, 2.8, 2.4), Vector3.new(0, 6.1, 0), nil, Color3.fromRGB(205, 210, 220), Enum.Material.Marble },
    }
    local head
    for _, z in ipairs(zones) do
        local p = MakePart({ Name = z[1], Shape = (z[4] == "Ball") and Enum.PartType.Ball or Enum.PartType.Block, Size = z[2], CFrame = CFrame.new(spawnPos + z[3]),
            Anchored = true, CanCollide = true, CanQuery = true, Color = z[5], Material = z[6], Parent = model })
        p:SetAttribute("Damageable", true)
        if z[1] == "Core" then p:SetAttribute("Glow", true) end
        if z[1] == "Head" then head = p end
    end
    local bb = Instance.new("BillboardGui") -- (kept for code that looks for it; EnemyBars draws the real bar)
    bb.Name = "HealthHUD"; bb.Size = UDim2.new(0, 10, 0, 10); bb.Adornee = head; bb.Enabled = false; bb.Parent = model
    local lbl = Instance.new("TextLabel"); lbl.Name = "Title"; lbl.Text = AscensionTrials.BOSS_NAME; lbl.Parent = bb
    if not (spec and spec.DryRun) then EnemyModels.DecorateAscendant(model, spawnPos) end
    DungeonGenerator.SoftenEnemyVisuals(model)
    CollectionService:AddTag(model, "AimRngEnemy")
    if spec and spec.DryRun then return model end
    if spec and spec.EnemyId then model:SetAttribute("EnemyId", spec.EnemyId) end
    if config.RunId then model:SetAttribute("RunId", config.RunId) end
    model.Parent = parent
    local cfg = table.clone(config)
    cfg.TrialPace = t.Pace
    cfg.AscTier = tier
    BossAI.Run("Ascendant", model, cfg, BossDeps(model, spawnPos, config, bossDmg))
    return model
end

-- ==================== [FLOOR ROSTER: WHICH FOES A FLOOR STARTS WITH] ====================
-- Pure data (the server turns each entry into an enemy stand-in, the client into the real enemy):
--   { Kind = "Bot" | "LootGoblin" | "Goliath" | "Phantom" | "Sentinel" | "Titan" | "SuperBoss",
--     Archetype = bot type, Elite = true for elite bots, Pos = spawn point }
-- Spawn points are rough (the server has no map); the client nudges each to the nearest open spot.
-- PACKS PILOT (PacksPilot): every regular bot on the roster leads a pack of fodder in a ring round it. Each entry of a pack
-- carries Pack = its number (DungeonRuns releases the packs in waves); fodder entries carry Fodder = true (DungeonRuns
-- scales their stand-in's health / damage / rewards).
function DungeonGenerator.AddPilotPacks(roster: { any }, layout: any, config: any?)
    local PP = require(script.Parent:WaitForChild("PacksPilot"))
    local teem = (config and HasMod(config, "BIG_PACKS")) and DungeonGenerator.ModV(config, "BIG_PACKS") or 0 -- (UPDATE 8 map mod Teeming; MAPS V2: +V of the pack, was +2)
    local half = layout.CombatSize / 2 - 8
    local leaders = {}
    for _, e in ipairs(roster) do if e.Kind == "Bot" then table.insert(leaders, e) end end
    for pack, lead in ipairs(leaders) do
        lead.Pack = pack
        local nF = PP.RollFodder(config and config.Difficulty, config and config.FloorNumber)
        for _ = 1, nF + math.round(nF * teem) do -- (PACK SIZE BY DIFFICULTY: 4-5 on Easy .. 8-10 on Annihilation; EARLY RAMP)
            local arch = PP.FODDER[math.random(1, #PP.FODDER)]
            local a, r = math.random() * math.pi * 2, PP.PACK_R[1] + math.random() * (PP.PACK_R[2] - PP.PACK_R[1])
            local x = math.clamp(lead.Pos.X + math.cos(a) * r, -half, half)
            local z = math.clamp(lead.Pos.Z + math.sin(a) * r, layout.CombatZ - half, layout.CombatZ + half)
            table.insert(roster, { Kind = "Bot", Archetype = arch, Elite = false, Fodder = true, Pack = pack,
                Pos = Vector3.new(x, DungeonGenerator.IsGroundArchetype(arch) and 5 or math.random(9, 18), z) })
        end
    end
end

function DungeonGenerator.RollFloorRoster(config: DungeonConfig): { any }
    local floor = config.FloorNumber
    local diff = config.Difficulty
    local isBossFloor = ItemData.IsBossConfig(config)
    local layout = DungeonGenerator.GetChamberLayout(isBossFloor)
    local roster = {}

    -- Final Biome Superboss on whichever floor that difficulty tier defines as its SuperBossWave
    -- (15 on Hard, 20 on Brutal, 30 on Nightmare -- each tier's own capstone fight); major bosses on the tier's
    -- BossWaves (Easy's finale on 5 is one), mini-bosses on the other multiples of 5.
    -- an endgame Boss Trial (BossTrials): just that boss, alone in its arena
    if (config :: any).BossTrial then
        local bt = (config :: any).BossTrial
        table.insert(roster, { Kind = "TrialBoss", Archetype = bt.Id .. ":" .. tostring(bt.Tier), Pos = Vector3.new(0, 12, layout.CombatZ + 30) })
        return roster
    end
    -- the Trial of Ascension's last floor (AscensionTrials): The Ascendant, alone
    if (config :: any).AscTrial and isBossFloor then
        table.insert(roster, { Kind = "Ascendant", Archetype = tostring((config :: any).AscTrial.Tier or 1), Pos = Vector3.new(0, 12, layout.CombatZ + 30) })
        return roster
    end
    -- a MAP's last floor: its tier band's guardian (0.66, Rifts.GUARDIANS; DungeonRuns sets config.MapGuardian)
    if (config :: any).MapGuardian and isBossFloor then
        table.insert(roster, { Kind = "TrialBoss", Archetype = (config :: any).MapGuardian, Pos = Vector3.new(0, 12, layout.CombatZ + 30) })
        return roster
    end
    local diffMode = ItemData.RunMode(diff, (config :: any).Endless)
    local isMajor = (diffMode and diffMode.BossWaves and table.find(diffMode.BossWaves, floor) ~= nil) or (floor > 100 and floor % 10 == 0)
    if (config :: any).Raid then
        -- RAID (PartyRuns): the last floor is the raid boss (the biome superboss, BossAI gives it more shield orbs); the
        -- floors before it are regular waves (CountMult already scales them to the raid's size)
        isMajor = false
        if isBossFloor then
            table.insert(roster, { Kind = "SuperBoss", Pos = Vector3.new(0, 10, layout.CombatZ + 30) })
            return roster
        end
    end
    if not (config :: any).Raid and diffMode and diffMode.SuperBossWave and floor == diffMode.SuperBossWave then
        table.insert(roster, { Kind = "SuperBoss", Pos = Vector3.new(0, 10, layout.CombatZ + 30) })
    elseif isMajor then
        -- Major boss: the Titan, or the floor's biome boss at the Titan's strength (Lite) -- so a 5-floor run doesn't end
        -- on the same fight every time
        local plan = (config :: any).BossPlan
        if plan == "Lite" or (plan == nil and math.random() < 0.5) then
            table.insert(roster, { Kind = "SuperBoss", Archetype = "Lite", Pos = Vector3.new(0, 10, layout.CombatZ + 30) })
        else
            table.insert(roster, { Kind = "Titan", Pos = Vector3.new(0, 10, layout.CombatZ + 30) })
        end
    elseif isBossFloor then
        -- the schedule's mini-boss floors: Mini-Boss (rotates through three distinct archetypes as floors climb)
        local plan = (config :: any).BossPlan
        local kind = table.find(DungeonGenerator.MINI_BOSSES, plan) and plan or DungeonGenerator.MINI_BOSSES[math.random(1, #DungeonGenerator.MINI_BOSSES)]
        table.insert(roster, { Kind = kind, Pos = Vector3.new(0, 7, layout.CombatZ + 30) })
        -- (UPDATE 8 Phase 5 RUN: a small pack wave with the mini-boss -- PacksPilot.MINI_PACKS plain leaders + their fodder;
        -- DungeonRuns / PartyRuns start MINI_START of them and send the rest mid-fight. The floor still clears when the boss dies.)
        if (config :: any).PacksPilot then
            local PP = require(script.Parent:WaitForChild("PacksPilot"))
            for _ = 1, PP.MINI_PACKS do
                local arch = DungeonGenerator.PickArchetype(floor, config.Biome, diff)
                table.insert(roster, { Kind = "Bot", Archetype = arch, Elite = false,
                    Pos = Vector3.new(math.random(-45, 45), DungeonGenerator.IsGroundArchetype(arch) and 5 or math.random(10, 18), layout.CombatZ + math.random(-45, 15)) })
            end
            DungeonGenerator.AddPilotPacks(roster, layout, config)
            ;(config :: any).MiniPacks = true
        end
    else
        -- Regular combat waves (owner 2026-10-04: "clearing the rooms can feel tedious ... keep enemy scaling quantity wise
        -- really low, with an increase of 1 enemy every 5 rooms"): 4 bots, +1 every 5 floors, the same on every
        -- difficulty (harder difficulties make each one tougher instead), specialists mixed in
        local droneCount = math.min(12, 4 + math.floor((floor - 1) / 5))
        droneCount = math.round(droneCount * ((config :: any).CountMult or 1) * ((config :: any).SwarmMult or 1)) -- parties fight more bots (MAPS V2: + a map's Swarming)
        -- (0.62 BOT REVAMP, owner: "The final level(s) of the bot difficulty should still be very hard, just in a different
        -- way"): the top bot skills add TARGETS (switching under pressure) instead of twitch -- +1 / +2 / +3 at 8 / 9 / 10
        local skillLvl = math.clamp(math.floor((config and config.BotSkill) or DungeonGenerator.DEFAULT_BOT_SKILL), 1, 10)
        droneCount += math.max(0, skillLvl - 7)
        -- (0.61 smooth curve: specialists 0 -> 2 and elites phase in over the run, not at fixed floors 2 / 3 / 4)
        local prog = DungeonGenerator.RunProgress(config)
        local specialists = math.min(2, math.floor(0.4 + 2 * prog))
        if HasMod(config, "SHARPSHOOTERS") then -- (0.62 map mod: two extra Snipers)
            for _ = 1, math.round(DungeonGenerator.ModV(config, "SHARPSHOOTERS")) do table.insert(roster, { Kind = "Bot", Archetype = "Sniper", Elite = false, Pos = Vector3.new(math.random(-45, 45), math.random(14, 22), layout.CombatZ + math.random(-45, 45)) }) end
        end
        -- Elites: from floor 3 on, a per-bot chance that grows with difficulty and depth (min. one per floor).
        local eliteChance = math.min(0.3, DungeonGenerator.ELITE_CHANCE[diff] or 0.08) -- (FUTURE-PROOF: one table, ELITE_CHANCE)
        eliteChance = math.min(0.3, eliteChance + floor * 0.004) * (0.35 + 0.65 * prog)
        local minElites = (prog >= 0.45) and 1 or 0
        if HasMod(config, "ELITE_PACK") then eliteChance = math.min(0.6, eliteChance * 2.5); minElites = math.round(DungeonGenerator.ModV(config, "ELITE_PACK")) end
        eliteChance = math.min(0.75, eliteChance * ((config :: any).AtlasElite or 1)) -- (MAP TREE: The Hunt)
        if RunService:IsStudio() and type(Workspace:GetAttribute("DevEliteChance")) == "number" then eliteChance = Workspace:GetAttribute("DevEliteChance"); prog = math.max(prog, 0.2) end -- (Studio test hook)
        local elites = 0
        -- (0.75, owner: "Each room should have at least some enemy variety, the same enemy type shouldn't be spammed in one
        -- room"): one type fills at most ~30% of a room (2 at least); a pick over the cap is rerolled (forced dev rosters exempt)
        local typeCount, typeCap = {}, math.max(2, math.ceil(droneCount * 0.3))
        for d = 1, droneCount do
            local makeElite = (prog >= 0.2 or minElites > 1) and (math.random() < eliteChance or (elites < minElites and d > droneCount - minElites))
            if makeElite then elites += 1 end
            local arch = (d <= specialists) and DungeonGenerator.PickSpecialist(floor, config.Biome, diff) or DungeonGenerator.PickArchetype(floor, config.Biome, diff)
            if not DungeonGenerator.ForceArchetypes then
                for _ = 1, 12 do
                    if (typeCount[arch] or 0) < typeCap then break end
                    arch = DungeonGenerator.PickArchetype(floor, config.Biome, diff)
                end
            end
            typeCount[arch] = (typeCount[arch] or 0) + 1
            table.insert(roster, {
                Kind = "Bot", Archetype = arch, Elite = makeElite,
                Pos = Vector3.new(math.random(-50, 50), DungeonGenerator.IsGroundArchetype(arch) and 5 or math.random(10, 22), layout.CombatZ + math.random(-50, 50)),
            })
        end
        if (config :: any).PacksPilot then DungeonGenerator.AddPilotPacks(roster, layout, config) end -- (PACKS PILOT: fodder round every bot)
        -- Loot Goblin: rare bonus spawn that flees on sight and guarantees a high-quality drop if caught
        -- (2026-10-22, owner: "Loot goblins are far too common. They should be rare spawns in any room (1/100)": was 15% a floor;
        -- the map tree / Mark of Greed / the Treasure Hunt mod still add on top -- they're opt-in map investments)
        if math.random() < DungeonGenerator.LOOT_GOBLIN_CHANCE + ((config :: any).AtlasGoblin or 0) or HasMod(config, "TREASURE") then -- (MAP TREE: Fortune)
            table.insert(roster, { Kind = "LootGoblin", Pos = Vector3.new(math.random(-45, 45), math.random(10, 18), layout.CombatZ + math.random(-45, 45)) })
        end
    end
    return roster
end

-- Client side of a server-run (party) bot: build its EnemyModels look locally from the DecoArgs attribute.
-- Returns the new parts with their offsets from the model's pivot (the client moves them with the body).
function DungeonGenerator.DecorateReplicated(model: Model): { any }?
    local args = model:GetAttribute("DecoArgs")
    if type(args) ~= "string" or model:GetAttribute("DecoDone") then return nil end
    local f = string.split(args, "|")
    local A = BotArchetypes[f[1]] or BotArchetypes.Tracker
    local function V3(s) local t = string.split(s, ","); return Vector3.new(tonumber(t[1]) or 1, tonumber(t[2]) or 1, tonumber(t[3]) or 1) end
    local c = string.split(f[6] or "200,200,200", ",")
    local pv = model:GetPivot()
    local before = {}
    for _, d in ipairs(model:GetDescendants()) do before[d] = true end
    if EnemyModels.PILL_BOTS then -- (0.97 PILL BOTS: the same look as solo floors, biome from the args)
        local biome = f[8] or "Fire"
        local pc, ph = DungeonGenerator.PillColors(biome, f[1])
        local body = V3(f[2])
        -- (built around an unturned body like Decorate; the Torso / Head moves below are relative to the pivot too)
        EnemyModels.Pill(model, { Arch = A, Pos = pv.Position, Body = body, Head = V3(f[3]), Ground = f[4] == "1", LegH = tonumber(f[5]) or 0,
            Color = pc, HeadColor = ph, Biome = biome, Scale = tonumber(f[7]) or 1, Tiny = f[4] ~= "1" and (A.Body <= (DungeonGenerator.TINY_BODY or 1.7)) })
    else
        EnemyModels.Decorate(model, { Arch = A, Pos = pv.Position, Body = V3(f[2]), Head = V3(f[3]), Ground = f[4] == "1", LegH = tonumber(f[5]) or 0,
            Color = Color3.fromRGB(tonumber(c[1]) or 200, tonumber(c[2]) or 200, tonumber(c[3]) or 200), Scale = tonumber(f[7]) or 1, Melee = A.Melee })
    end
    model:SetAttribute("DecoDone", true)
    local base = CFrame.new(pv.Position)
    local out = {}
    for _, d in ipairs(model:GetDescendants()) do
        if not before[d] and d:IsA("BasePart") then
            local off = base:ToObjectSpace(d.CFrame) -- built around an unturned body
            d.CFrame = pv * off
            d:SetAttribute("LocalDeco", true)
            table.insert(out, { Part = d, Off = off })
        end
    end
    local parts = {}
    for _, e in ipairs(out) do table.insert(parts, e.Part) end
    EnemyModels.MakeHittable(model, parts) -- (a hit on one is reported as the real part it sits on -- AimRngClient)
    return out
end

-- (UPDATE 8 OFFENSE) ENEMY RESISTANCES: every enemy built through CreateOfKind (solo client model, the server's dry run
-- for the stand-in, party floors) gets attrs Res_<Type> + ResSet from DamageTypes.EnemyResists -- its type key (its
-- elemental mod, else the floor's biome: ItemData.EnemyAffinity), the mod itself, boss or not. Same inputs on both sides,
-- so the stand-in and the client model agree. Practice dummies / hub targets are not built here (no resists).
function DungeonGenerator.StampResists(model: Instance, config: any)
    local DT = require(script.Parent:WaitForChild("DamageTypes"))
    local el = model:GetAttribute("Element") -- (Torment+ every bot carries one: its type, like the old matchups)
    local key = ItemData.EnemyAffinity(el, config and config.Biome)
    local mods = model:GetAttribute("EliteMods")
    local elemMod = DungeonGenerator.HasEliteMod(mods, "Elemental") and el or nil -- (only the Elemental elite mod resists more)
    DT.WriteResists(model, DT.EnemyResists(key, elemMod, model:GetAttribute("IsBoss") == true))
end

-- (UPDATE 8 MAPS, DEFENCE builder) map mods that raise a monster resistance: +MAP_RESIST on that type, on top of the stamp
-- (ARMORED "Plated" = Kinetic). Runs on the client model and the server's dry run alike (same config.Mods).
DungeonGenerator.MAP_RESIST = { ARMORED = "Kinetic", RESIST_HEAT = "Heat", RESIST_CRYO = "Cryo", RESIST_VOLT = "Volt", RESIST_VOID = "Void" }
DungeonGenerator.MAP_RESIST_ADD = 0.3
function DungeonGenerator.MapResist(model: Instance, config: any)
    if not (config and config.Mods) then return end
    for id, t in pairs(DungeonGenerator.MAP_RESIST) do
        if HasMod(config, id) then
            local cur = model:GetAttribute("Res_" .. t) or 0
            local add = DungeonGenerator.ModV(config, id) -- (MAPS V2: x the map's ModScale; MAP_RESIST_ADD at x1)
            if add <= 0 then add = DungeonGenerator.MAP_RESIST_ADD end
            model:SetAttribute("Res_" .. t, math.min(0.75, math.round((cur + add) * 1000) / 1000))
            model:SetAttribute("ResSet", true)
        end
    end
end

-- Builds one enemy of a roster Kind. spec = stand-in attributes (client) or { DryRun = true } (server).
function DungeonGenerator.CreateOfKind(kind: string, archetype: string?, eliteMods: { string }?, pos: Vector3, config: DungeonConfig, parent: Instance?, spec: any?): Model
    local model = DungeonGenerator.CreateOfKindRaw(kind, archetype, eliteMods, pos, config, parent, spec)
    if model then
        local ok, err = pcall(DungeonGenerator.StampResists, model, config)
        if not ok then warn("[DungeonGenerator] resists: " .. tostring(err)) end
        DungeonGenerator.EliteResist(model, eliteMods) -- (UPDATE 8 Phase 5: the Resistant elite mod, on top of the stamp)
        pcall(DungeonGenerator.MapResist, model, config) -- (UPDATE 8 MAPS: map mods' monster resists)
    end
    return model
end
-- (UPDATE 8 Phase 5 ELITE MODS, LOOT/RUN builder) Resistant: +ELITE_RESIST_ADD of one type (capped 0.75) on top of the stamped
-- resists; Vampiric: heals ELITE_VAMP of its max health on every landed hit (DungeonRuns' EnemyHitPlayer for solo stand-ins,
-- HitPlayer's server branch for party bots).
DungeonGenerator.ELITE_RESIST_ADD, DungeonGenerator.ELITE_VAMP = 0.4, 0.06
function DungeonGenerator.EliteResist(model: Instance, eliteMods: { string }?)
    for _, m in ipairs(eliteMods or {}) do
        local t = string.match(m, "^Resist(%a+)$")
        if t then
            local k = "Res_" .. t
            model:SetAttribute(k, math.min(0.75, (model:GetAttribute(k) or 0) + DungeonGenerator.ELITE_RESIST_ADD))
            model:SetAttribute("ResSet", true)
        end
    end
end
-- COMMANDER (UPDATE 8 elite mod): every tick (DungeonRuns' 0.5 s floor loop / PartyRuns' pack loop, and right after a
-- Commander dies) each non-boss enemy within COMMAND_RANGE of a living Commander (not the Commander itself) is "Commanded":
-- its hits on you x COMMAND_DMG (EnemyHitPlayer / HitPlayer) and it takes x COMMAND_TAKEN (folded into ModTakenMult, which
-- CombatServer's EnemyTakenMult already reads). posOf(model) -> Vector3? (solo stand-ins: the client-reported position).
DungeonGenerator.COMMAND_RANGE, DungeonGenerator.COMMAND_DMG, DungeonGenerator.COMMAND_TAKEN = 25, 1.2, 0.9
DungeonGenerator.COMMAND_BAND = 0.7 -- (2026-11-07: the Commander's marker band, studs past its body -- was the 25-stud reach ring)
-- COMMAND REACH (2026-11-07, owner: keep the band AND "a faint ring on the floor" showing how far the buff reaches): a thin, faint
-- outline (not a disc) of COMMAND_RANGE on the GROUND under a Commander. Flat in world space -- adorned to the Terrain, never to
-- the root, so a flier's face-you tilt never touches it -- at the floor height a downward ray finds at spawn, cast again only
-- after the bot has moved REACH.Move studs across (at most once every REACH.Recheck s). Per frame: one CFrame write while the bot
-- moves, no rays. One adornment per Commander, in its model (it goes with it), hidden once the bot is (predicted) dead. Built by
-- whoever draws the bot: CreateBot on the client (solo floors), AimRngClient's party-bot smoothing (server-run party bots: built
-- on each client, so nothing extra replicates).
DungeonGenerator.COMMAND_REACH = { Width = 0.3, Transparency = 0.72, Lift = 0.08, Recheck = 1, Move = 6, MinPart = 30 }
DungeonGenerator.COMMAND_FLAT = CFrame.Angles(math.pi / 2, 0, 0)
-- the walkable ground under pos: Terrain or a big part (a floor slab / terrace); props, pillars, bots, players are looked past
function DungeonGenerator.CommandGround(model: Instance, pos: Vector3): number
    local ex = { model }
    for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(ex, p.Character) end end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.RespectCanCollide = true
    for _ = 1, 4 do
        rp.FilterDescendantsInstances = ex
        local hit = Workspace:Raycast(pos, Vector3.new(0, -160, 0), rp)
        if not hit then break end
        local inst = hit.Instance
        if inst:IsA("Terrain") or math.max(inst.Size.X, inst.Size.Z) >= DungeonGenerator.COMMAND_REACH.MinPart then return hit.Position.Y end
        table.insert(ex, inst)
    end
    return 2 -- (FLOOR_TOP: every chamber floor's top)
end
function DungeonGenerator.CommandFloorRing(model: Instance, pos: Vector3): any
    if model:FindFirstChild("CommandReach") then return nil end
    local R, cr = DungeonGenerator.COMMAND_RANGE, DungeonGenerator.COMMAND_REACH
    local ring = Instance.new("CylinderHandleAdornment")
    ring.Name = "CommandReach"
    ring.Radius, ring.InnerRadius, ring.Height = R, R - cr.Width, 0.04
    ring.Color3, ring.Transparency, ring.AlwaysOnTop, ring.ZIndex = Color3.fromRGB(255, 196, 90), cr.Transparency, false, 0
    local st = { Ring = ring, Y = DungeonGenerator.CommandGround(model, pos), GX = pos.X, GZ = pos.Z, At = os.clock() + cr.Recheck, Last = pos }
    ring.CFrame = CFrame.new(pos.X, st.Y + cr.Lift, pos.Z) * DungeonGenerator.COMMAND_FLAT
    ring.Adornee = Workspace.Terrain
    ring.Parent = model
    return st
end
function DungeonGenerator.CommandFloorStep(st: any, model: Instance, pos: Vector3, now: number)
    local cr = DungeonGenerator.COMMAND_REACH
    local dead = model:GetAttribute("PredictedDead") == true or model:GetAttribute("Dead") == true or (model:GetAttribute("Health") or 1) <= 0
    if st.Ring.Visible == dead then st.Ring.Visible = not dead end
    if dead then return end
    local moved = false
    if now >= st.At and (pos.X - st.GX) ^ 2 + (pos.Z - st.GZ) ^ 2 >= cr.Move * cr.Move then
        st.At, st.GX, st.GZ = now + cr.Recheck, pos.X, pos.Z
        local y = DungeonGenerator.CommandGround(model, pos)
        if y ~= st.Y then st.Y, moved = y, true end
    end
    if moved or (pos.X - st.Last.X) ^ 2 + (pos.Z - st.Last.Z) ^ 2 > 0.0025 then
        st.Last = pos
        st.Ring.CFrame = CFrame.new(pos.X, st.Y + cr.Lift, pos.Z) * DungeonGenerator.COMMAND_FLAT
    end
end
function DungeonGenerator.CommanderTick(list: { Instance }, posOf: (Instance) -> Vector3?)
    local leaders = {}
    for _, m in ipairs(list) do
        local mods = m:GetAttribute("EliteMods")
        if DungeonGenerator.HasEliteMod(mods, "Commander") and not m:GetAttribute("Dead") and (m:GetAttribute("Health") or 0) > 0 then
            local p = posOf(m)
            if p then table.insert(leaders, { m, p }) end
        end
    end
    local R = DungeonGenerator.COMMAND_RANGE
    for _, m in ipairs(list) do
        local was = m:GetAttribute("Commanded") == true
        local on = false
        if #leaders > 0 and not m:GetAttribute("IsBoss") and not m:GetAttribute("Dead") and m:GetAttribute("Health") then
            local p = posOf(m)
            if p then for _, l in ipairs(leaders) do if l[1] ~= m and (p - l[2]).Magnitude <= R then on = true break end end end
        end
        if on ~= was then
            m:SetAttribute("Commanded", on or nil)
            local t = m:GetAttribute("ModTakenMult") or 1
            t = on and (t * DungeonGenerator.COMMAND_TAKEN) or (t / DungeonGenerator.COMMAND_TAKEN)
            t = math.round(t * 10000) / 10000
            m:SetAttribute("ModTakenMult", (t ~= 1) and t or nil)
        end
    end
end
DungeonGenerator.VAMP_GAP = 1.0 -- (ENEMY ATTACKS POE DAMAGE MODEL, review 2: chip lands ~30x a minute -- one heal a second per Vampiric source)
DungeonGenerator._VampAt = setmetatable({}, { __mode = "k" })
function DungeonGenerator.EliteOnHit(source: Instance?)
    if not source or IS_CLIENT then return end
    local mods = source:GetAttribute("EliteMods")
    if not DungeonGenerator.HasEliteMod(mods, "Vampiric") or source:GetAttribute("Dead") then return end
    local now = os.clock()
    if now - (DungeonGenerator._VampAt[source] or -1e9) < DungeonGenerator.VAMP_GAP then return end
    DungeonGenerator._VampAt[source] = now
    local h, mh = source:GetAttribute("Health") or 0, source:GetAttribute("MaxHealth") or 1
    if h > 0 and h < mh then source:SetAttribute("Health", math.min(mh, h + mh * DungeonGenerator.ELITE_VAMP)) end
end
function DungeonGenerator.CreateOfKindRaw(kind: string, archetype: string?, eliteMods: { string }?, pos: Vector3, config: DungeonConfig, parent: Instance?, spec: any?): Model
    if kind == "Bot" then
        return DungeonGenerator.CreateBot(archetype or "Tracker", pos, config, parent, eliteMods, spec)
    elseif kind == "LootGoblin" then
        return DungeonGenerator.CreateLootGoblin(pos, config, parent, spec)
    elseif kind == "Goliath" then
        return DungeonGenerator.CreateMiniBossGoliath(pos, config, parent, spec)
    elseif kind == "Phantom" then
        return DungeonGenerator.CreateMiniBossPhantom(pos, config, parent, spec)
    elseif kind == "Sentinel" then
        return DungeonGenerator.CreateMiniBossSentinel(pos, config, parent, spec)
    elseif kind == "Ravager" or kind == "Hexcaller" then
        return DungeonGenerator.CreateMiniBossCustom(kind, pos, config, parent, spec)
    elseif kind == "Titan" then
        return DungeonGenerator.CreateMajorBossTitan(pos, config, parent, spec)
    elseif kind == "SuperBoss" then
        return DungeonGenerator.CreateBiomeSuperBoss(pos, config, parent, spec, archetype == "Lite")
    elseif kind == "TrialBoss" then
        return DungeonGenerator.CreateTrialBoss(archetype, pos, config, parent, spec)
    elseif kind == "Ascendant" then
        return DungeonGenerator.CreateAscendant(archetype, pos, config, parent, spec)
    end
    -- (FUTURE-PROOF: an unknown kind -- a new boss kind not wired here yet -- is a plain bot and a warning, not a crash mid-floor)
    warn("[DungeonGenerator] unknown enemy kind " .. tostring(kind) .. " -- built as a Tracker")
    return DungeonGenerator.CreateBot("Tracker", pos, config, parent, eliteMods, spec)
end

-- ==================== [BIOME THEMES] ====================
-- Every chamber is built from its biome's own materials, and lit by a handful of soft, shadowless lamp
-- fixtures instead of the old full-Neon skylights / trims / cover shields and 110-140 stud PointLights
-- (which, together with the hub's daytime lighting, made rooms -- and Cryo especially -- blinding).
-- The client also switches to a per-biome Lighting profile inside the dungeon (see AimRngClient).
local FLOOR_TOP = 2 -- every chamber floor is a 4-thick slab centered at y=0
local MapShell: any = {} -- (arena map shells; filled in by the MAP SHELLS section further down)
DungeonGenerator.MapShell = MapShell -- (FUTURE-PROOF: read by ContentCheck)
-- PARTY TWIN (2026-10-25, owner: "I want everyone to be able to see the same generated arenas in multiplayer"): a party floor
-- (server-built) is MIRRORED -- the server runs the solo client's build path draw for draw (terrain, prop sets, rims) with its
-- terrain writes going nowhere, so its colliders are the ones every member's full-detail local copy has (AimRngShared/
-- PartyTwin builds that copy from the folder's Twin attr). Set by BuildThemedDungeon from config.Mirror (PartyRuns).
MapShell.Mirror = false
MapShell.NULL_T = setmetatable({}, { __index = function() return function() end end }) -- (every Terrain method: a no-op)
function MapShell.Full(): boolean return IS_CLIENT or MapShell.Mirror == true end -- (the client's build path: solo, a twin, a mirror)
function MapShell.T(): any return (MapShell.Mirror and not IS_CLIENT) and MapShell.NULL_T or Workspace.Terrain end

type Surface = { Color: Color3, Material: Enum.Material, Transparency: number? }
type BiomeTheme = {
    Name: string,
    Floor: Surface, FloorAlt: Surface, Wall: Surface, WallTrim: Surface, Ceiling: Surface,
    Prop: Surface, PropAlt: Surface, Hazard: Surface,
    Accent: Color3, Light: Color3, LampBrightness: number, LampRange: number,
}
local C3 = Color3.fromRGB
local BiomeThemes: { [string]: BiomeTheme } = {
    Fire = {
        Name = "Volcanic Forge",
        Floor = { Color = C3(66, 56, 52), Material = Enum.Material.Basalt },
        FloorAlt = { Color = C3(226, 212, 202), Material = Enum.Material.CrackedLava }, -- (UPDATE 4: the crust map carries its colours)
        Wall = { Color = C3(58, 48, 45), Material = Enum.Material.Rock },
        WallTrim = { Color = C3(40, 34, 32), Material = Enum.Material.Slate },
        Ceiling = { Color = C3(36, 31, 30), Material = Enum.Material.Rock },
        Prop = { Color = C3(48, 42, 40), Material = Enum.Material.Basalt },
        PropAlt = { Color = C3(84, 70, 62), Material = Enum.Material.Rock },
        Hazard = { Color = C3(170, 70, 30), Material = Enum.Material.CrackedLava },
        Accent = C3(210, 110, 50), Light = C3(255, 175, 120), LampBrightness = 2.1, LampRange = 62, -- (brighter: the molten rooms read too dark)
        OpenSky = true, -- (2026-10-03 visual pass: a broken roof under a deck of lava-lit smoke)
    },
    Ice = {
        Name = "Frozen Cavern",
        Floor = { Color = C3(158, 172, 186), Material = Enum.Material.Snow },
        FloorAlt = { Color = C3(118, 156, 184), Material = Enum.Material.Ice },
        Wall = { Color = C3(104, 120, 136), Material = Enum.Material.Glacier },
        WallTrim = { Color = C3(78, 90, 104), Material = Enum.Material.Slate },
        Ceiling = { Color = C3(86, 98, 112), Material = Enum.Material.Rock },
        Prop = { Color = C3(140, 180, 206), Material = Enum.Material.Ice, Transparency = 0.12 },
        PropAlt = { Color = C3(196, 206, 216), Material = Enum.Material.Snow },
        Hazard = { Color = C3(110, 160, 200), Material = Enum.Material.Glacier, Transparency = 0.15 },
        Accent = C3(140, 190, 225), Light = C3(205, 228, 255), LampBrightness = 1.05, LampRange = 46,
        OpenSky = true, -- (the clear polar sky overhead)
    },
    -- (Void + Cyber surfaces lifted 2026-10-02, playtester: "cyber is extremely dark, void is also pretty dark" -- they
    -- were near-black, so no amount of lighting could show them)
    Void = {
        Name = "Shattered Rift",
        Floor = { Color = C3(96, 84, 118), Material = Enum.Material.Slate },
        FloorAlt = { Color = C3(72, 62, 92), Material = Enum.Material.Basalt },
        Wall = { Color = C3(88, 76, 110), Material = Enum.Material.Slate },
        WallTrim = { Color = C3(112, 94, 140), Material = Enum.Material.Pavement },
        Ceiling = { Color = C3(64, 56, 80), Material = Enum.Material.Slate },
        Prop = { Color = C3(80, 70, 100), Material = Enum.Material.Slate },
        PropAlt = { Color = C3(130, 92, 186), Material = Enum.Material.Glass, Transparency = 0.25 },
        Hazard = { Color = C3(90, 40, 140), Material = Enum.Material.Glass, Transparency = 0.3 },
        Accent = C3(170, 110, 240), Light = C3(205, 180, 255), LampBrightness = 1.6, LampRange = 54,
        OpenSky = true, -- (2026-10-03: open to the stars and a black hole)
    },
    Cyber = {
        Name = "Data Foundry",
        -- (2026-10-03: a little darker again -- the pale steel washed out under the fog; the neon grid lights it now)
        Floor = { Color = C3(74, 82, 92), Material = Enum.Material.Metal },
        FloorAlt = { Color = C3(60, 66, 76), Material = Enum.Material.DiamondPlate },
        Wall = { Color = C3(80, 88, 98), Material = Enum.Material.Metal },
        WallTrim = { Color = C3(44, 50, 58), Material = Enum.Material.SmoothPlastic },
        Ceiling = { Color = C3(40, 44, 52), Material = Enum.Material.Metal },
        Prop = { Color = C3(88, 96, 104), Material = Enum.Material.Metal },
        PropAlt = { Color = C3(110, 124, 132), Material = Enum.Material.CorrodedMetal },
        Hazard = { Color = C3(60, 150, 110), Material = Enum.Material.SmoothPlastic },
        Accent = C3(80, 225, 170), Light = C3(200, 255, 236), LampBrightness = 1.6, LampRange = 54,
    },
    Storm = {
        Name = "Stormspire Citadel",
        Floor = { Color = C3(150, 156, 166), Material = Enum.Material.Slate },
        FloorAlt = { Color = C3(196, 196, 188), Material = Enum.Material.Limestone },
        Wall = { Color = C3(166, 166, 162), Material = Enum.Material.Limestone },
        WallTrim = { Color = C3(184, 112, 62), Material = Enum.Material.Metal },
        Ceiling = { Color = C3(84, 90, 104), Material = Enum.Material.Slate },
        Prop = { Color = C3(206, 204, 196), Material = Enum.Material.Marble },
        PropAlt = { Color = C3(172, 104, 58), Material = Enum.Material.Metal },
        Hazard = { Color = C3(120, 180, 240), Material = Enum.Material.Glass, Transparency = 0.2 },
        Accent = C3(150, 210, 255), Light = C3(215, 232, 255), LampBrightness = 1.5, LampRange = 52,
        OpenSky = true, -- (BuildChamber: a broken roof -- the storm shows through)
    },
}

-- ===== small building helpers (everything goes into the StaticGeometry folder) =====
local function Block(parent: Instance, size: Vector3, cf: CFrame, surf: Surface, class: string?): BasePart
    local p = Instance.new(class or "Part") :: BasePart
    p.Anchored = true
    p.Size = size
    p.CFrame = cf
    p.Color = surf.Color
    p.Material = surf.Material
    p.Transparency = surf.Transparency or 0
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end
local function Shade(surf: Surface, rng: Random, amt: number?): Surface
    local k = 1 + rng:NextNumber(-(amt or 0.08), amt or 0.08)
    local c = surf.Color
    return { Color = Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1)), Material = surf.Material, Transparency = surf.Transparency }
end
local function VCyl(parent: Instance, dia: number, h: number, pos: Vector3, surf: Surface): BasePart
    local p = Block(parent, Vector3.new(h, dia, dia), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), surf)
    ;(p :: Part).Shape = Enum.PartType.Cylinder
    return p
end
local function HCyl(parent: Instance, dia: number, len: number, cf: CFrame, surf: Surface): BasePart
    local p = Block(parent, Vector3.new(len, dia, dia), cf, surf)
    ;(p :: Part).Shape = Enum.PartType.Cylinder
    return p
end
local function Ball(parent: Instance, dia: number, pos: Vector3, surf: Surface): BasePart
    local p = Block(parent, Vector3.new(dia, dia, dia), CFrame.new(pos), surf)
    ;(p :: Part).Shape = Enum.PartType.Ball
    return p
end
local function Yaw(rng: Random): CFrame return CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) end

-- Soft ceiling lamp: dark housing + dim lens + one shadowless light.
local function Lamp(parent: Instance, theme: BiomeTheme, pos: Vector3, scale: number?, noLight: boolean?)
    local s = scale or 1
    Block(parent, Vector3.new(3.4 * s, 0.8, 3.4 * s), CFrame.new(pos), { Color = C3(30, 30, 34), Material = Enum.Material.Metal })
    local lens = Block(parent, Vector3.new(2.6 * s, 0.2, 2.6 * s), CFrame.new(pos - Vector3.new(0, 0.5, 0)),
        { Color = theme.Light:Lerp(Color3.new(0, 0, 0), 0.5), Material = Enum.Material.Neon })
    lens.CanCollide = false
    lens.CanQuery = false
    if noLight then return end -- (PERFORMANCE 2026-10-03: half the lamps carry a light, each a little stronger)
    local light = Instance.new("PointLight")
    light.Color = theme.Light
    light.Brightness = theme.LampBrightness * 1.15
    light.Range = math.min(60, theme.LampRange * 1.2)
    light.Shadows = false
    light.Parent = lens
end

-- A chamber shell: floor, ceiling, walls with doorways (N/S) matching the corridor, trims, pilasters, lamps.
local function BuildChamber(geo: Instance, theme: BiomeTheme, centerZ: number, size: number, height: number,
    doorNorth: boolean, doorSouth: boolean, doorWidth: number, lampGrid: number, open: boolean?, hideFloor: boolean?, solidRoof: boolean?)
    local half = size / 2
    local floor = Block(geo, Vector3.new(size, 4, size), CFrame.new(0, 0, centerZ), theme.Floor)
    if hideFloor then floor.Transparency = 1 end -- (MAP SHELL on a solo floor: terrain is the ground you see)
    if open then
        -- (MAP SHELL: the room is open -- its walls stay as invisible colliders, no ceiling, no trims or lamps; the
        -- shell's rim + sky are what you see. An invisible lid keeps everyone in.)
        for _, sx in ipairs({ -1, 1 }) do
            local w = Block(geo, Vector3.new(4, height, size), CFrame.new(sx * half, height / 2, centerZ), theme.Wall)
            w.Transparency = 1; w.CastShadow = false
        end
        for _, side in ipairs({ { z = centerZ - half, door = doorNorth }, { z = centerZ + half, door = doorSouth } }) do
            if side.door then
                local segW = (size - doorWidth) / 2
                for _, sx in ipairs({ -1, 1 }) do
                    local w = Block(geo, Vector3.new(segW, height, 4), CFrame.new(sx * (doorWidth / 2 + segW / 2), height / 2, side.z), theme.Wall)
                    w.Transparency = 1; w.CastShadow = false
                end
                local top = Block(geo, Vector3.new(doorWidth, height - 14, 4), CFrame.new(0, 14 + (height - 14) / 2, side.z), theme.Wall)
                top.Transparency = 1; top.CastShadow = false
            else
                local w = Block(geo, Vector3.new(size, height, 4), CFrame.new(0, height / 2, side.z), theme.Wall)
                w.Transparency = 1; w.CastShadow = false
            end
        end
        local lid = Block(geo, Vector3.new(size, 2, size), CFrame.new(0, height + 1.5, centerZ), theme.Ceiling)
        lid.Transparency = 1; lid.CanQuery = false; lid.CastShadow = false; lid.Name = "SkyLid"
        return
    end
    if (theme :: any).OpenSky and not solidRoof then
        -- (STORMSPIRE) a BROKEN ROOF: the storm sky shows through -- three stone ribs across the room carry the hanging
        -- lamps, a ragged ledge runs round the top of the walls, the rest is open (rain falls in, lightning lights it)
        local n = lampGrid
        for iz = 1, n do
            local fz = (iz - (n + 1) / 2) / n
            -- (ribs 2.6 tall inside the 3-tall ledges and the end ledges cut between the side ones: every piece used to be
            -- 3 tall at the same height, so the overlapping top / bottom faces z-fought -- owner 2026-10-05: "saferoom
            -- textures still flicker and glitch out")
            Block(geo, Vector3.new(size - 20.4, 2.6, 6), CFrame.new(0, height - 1, centerZ + fz * size * 0.9), theme.Ceiling)
        end
        for _, sx in ipairs({ -1, 1 }) do
            Block(geo, Vector3.new(10, 3, size), CFrame.new(sx * (half - 5), height - 1, centerZ), theme.Ceiling)
            Block(geo, Vector3.new(size - 20, 2.8, 10), CFrame.new(0, height - 1, centerZ + sx * (half - 5)), theme.Ceiling)
        end
        -- an invisible lid: nobody leaves through the open roof (shots and the rain ignore it)
        local lid = Block(geo, Vector3.new(size, 2, size), CFrame.new(0, height + 1.5, centerZ), theme.Ceiling)
        lid.Transparency = 1; lid.CanQuery = false; lid.CastShadow = false; lid.Name = "SkyLid"
    else
        Block(geo, Vector3.new(size, 4, size), CFrame.new(0, height, centerZ), theme.Ceiling)
    end
    for _, sx in ipairs({ -1, 1 }) do
        Block(geo, Vector3.new(4, height, size), CFrame.new(sx * half, height / 2, centerZ), theme.Wall)
        Block(geo, Vector3.new(1.2, 3, size), CFrame.new(sx * (half - 2.5), FLOOR_TOP + 1.5, centerZ), theme.WallTrim)
    end
    local doorTop = 14
    for _, side in ipairs({ { z = centerZ - half, door = doorNorth }, { z = centerZ + half, door = doorSouth } }) do
        if side.door then
            local segW = (size - doorWidth) / 2
            for _, sx in ipairs({ -1, 1 }) do
                Block(geo, Vector3.new(segW, height, 4), CFrame.new(sx * (doorWidth / 2 + segW / 2), height / 2, side.z), theme.Wall)
            end
            Block(geo, Vector3.new(doorWidth, height - doorTop, 4), CFrame.new(0, doorTop + (height - doorTop) / 2, side.z), theme.Wall)
            Block(geo, Vector3.new(doorWidth + 3, 1.5, 5), CFrame.new(0, doorTop + 0.65, side.z), theme.WallTrim) -- lintel (0.1 below the wall's underside: they z-fought)
        else
            Block(geo, Vector3.new(size, height, 4), CFrame.new(0, height / 2, side.z), theme.Wall)
        end
    end
    -- pilasters break up the long walls -- nearly flush and not solid, so you slide straight past them
    local step = 22
    for x = -half + step, half - step, step do
        for _, sz in ipairs({ -1, 1 }) do
            if math.abs(x) > doorWidth / 2 + 3 then
                local pl = Block(geo, Vector3.new(3, height - 2, 0.8), CFrame.new(x, height / 2 - 1, centerZ + sz * (half - 2.4)), theme.WallTrim)
                pl.CanCollide = false
                pl.CanQuery = false
            end
        end
    end
    for z = -half + step, half - step, step do
        for _, sx in ipairs({ -1, 1 }) do
            local pl = Block(geo, Vector3.new(0.8, height - 2, 3), CFrame.new(sx * (half - 2.4), height / 2 - 1, centerZ + z), theme.WallTrim)
            pl.CanCollide = false
            pl.CanQuery = false
        end
    end
    -- lamps
    local n = lampGrid
    for ix = 1, n do
        for iz = 1, n do
            local fx = (ix - (n + 1) / 2) / n
            local fz = (iz - (n + 1) / 2) / n
            Lamp(geo, theme, Vector3.new(fx * size * 0.9, height - 2.4, centerZ + fz * size * 0.9), nil, (ix + iz) % 2 == 1)
        end
    end
end

local function BuildCorridor(geo: Instance, theme: BiomeTheme, z0: number, z1: number, width: number, hazardDamage: number)
    local len = z1 - z0
    local mid = (z0 + z1) / 2
    Block(geo, Vector3.new(width, 4, len), CFrame.new(0, 0, mid), theme.Floor)
    Block(geo, Vector3.new(width + 8, 4, len), CFrame.new(0, 16.1, mid), theme.Ceiling) -- (0.1 up: its underside met the door walls' at y 14)
    for _, sx in ipairs({ -1, 1 }) do
        Block(geo, Vector3.new(4, 16, len), CFrame.new(sx * width / 2, 8, mid), theme.Wall)
    end
    local before = #geo:GetChildren()
    Lamp(geo, theme, Vector3.new(0, 13.6, mid), 0.8, true)
    -- (UPDATE 4: a SPOT light aimed down from the lamp's lens -- the old point light shone through the walls and lit the
    -- entry massif's face outside like a floodlight; this cone only reaches the corridor floor + walls)
    local kids = geo:GetChildren()
    local lens = kids[#kids]
    if #kids > before and lens:IsA("BasePart") then
        local spot = Instance.new("SpotLight")
        spot.Color = theme.Light
        spot.Brightness = theme.LampBrightness * 1.3
        spot.Range = 16
        spot.Angle = 80
        spot.Face = Enum.NormalId.Bottom
        spot.Shadows = false
        spot.Parent = lens
    end
    -- (the damaging hazard strips were removed 2026-10-02 at the owner's request)
end

-- (UPDATE 4 PROPS) a scanned / generated kit mesh as a COVER prop: the visual mesh in the floor folder, ONE box hitbox
-- in geo (shots stop, bots steer round it); false when the kit isn't in the place (the caller builds its old parts)
function DungeonGenerator.KitCover(set: string, names: { string }, geo: Instance, rng: Random, pos: Vector3, lo: number, hi: number): boolean
    local EK = require(script.Parent:WaitForChild("EnvKit"))
    local name = names[rng:NextInteger(1, #names)]
    if not EK.Has(set, name) then return false end
    EK.Place(set, name, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
        { Scale = rng:NextNumber(lo, hi), Parent = geo.Parent or geo, Hitbox = true, HitParent = geo, HitScale = 0.75 })
    return true
end

-- ==================== [BIOME PROPS] ====================
-- Each builder places one prop standing on the floor at `pos` (floor-level point).
type PropFn = (geo: Instance, theme: BiomeTheme, rng: Random, pos: Vector3) -> ()

local Props: { [string]: { Cover: { PropFn }, Tall: { PropFn }, Air: { PropFn } } } = {}

-- ----- Fire: Volcanic Forge -----
local function BasaltCluster(geo, theme, rng, pos)
    -- (UPDATE 4 PROPS, owner: "A lot of the props also dont fit / look lower quality"): real hexagonal basalt columns
    -- (one mesh, tools/biome_mesh_prep.py basalt_columns) with ONE box hitbox in geo; the plain cylinders stay as the
    -- fallback for an unsaved place
    local kit = (rng:NextNumber() < 0.5) and "BasaltColsA" or "BasaltColsB"
    local EK = require(script.Parent:WaitForChild("EnvKit")) -- (the chunk's EnvKit local comes later in the file)
    if EK.Has("Fire", kit) then
        EK.Place("Fire", kit, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
            { Scale = rng:NextNumber(0.85, 1.15), Parent = geo.Parent or geo, Hitbox = true, HitParent = geo, HitScale = 0.75 })
        return
    end
    for _ = 1, rng:NextInteger(3, 6) do
        local off = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
        local h = rng:NextNumber(4, 15)
        VCyl(geo, rng:NextNumber(2.2, 3.8), h, pos + off + Vector3.new(0, h / 2, 0), Shade(theme.Prop, rng))
    end
end
local function ObsidianSpire(geo, theme, rng, pos)
    local h = rng:NextNumber(8, 14)
    local base = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * Yaw(rng)
    local surf = { Color = C3(30, 26, 30), Material = Enum.Material.Basalt }
    local w1 = Block(geo, Vector3.new(3, h, 3), base * CFrame.new(0, 0, -1.5), surf, "WedgePart")
    local w2 = Block(geo, Vector3.new(3, h * 0.8, 3), base * CFrame.new(0, -h * 0.1, 1.5) * CFrame.Angles(0, math.pi, 0), surf, "WedgePart")
    w1.Reflectance, w2.Reflectance = 0.08, 0.08
end
local function RuinedWall(geo, theme, rng, pos)
    local cf = CFrame.new(pos) * Yaw(rng)
    local len, h = rng:NextNumber(9, 14), rng:NextNumber(4.5, 7)
    Block(geo, Vector3.new(len, h, 2.4), cf * CFrame.new(0, h / 2, 0), Shade(theme.Wall, rng))
    Block(geo, Vector3.new(len * 0.45, 1.6, 2.4), cf * CFrame.new(-len * 0.2, h + 0.8, 0), Shade(theme.Wall, rng))
    Block(geo, Vector3.new(2.2, 1.6, 2), cf * CFrame.new(len * 0.3, 0.8, 2.6) * CFrame.Angles(0, 0.4, 0.2), Shade(theme.PropAlt, rng))
end
local function LavaVent(geo, theme, rng, pos)
    local cf = CFrame.new(pos) * Yaw(rng)
    local strip = Block(geo, Vector3.new(3.5, 0.3, rng:NextNumber(12, 22)), cf * CFrame.new(0, 0.12, 0), theme.FloorAlt)
    strip.CanCollide = false
    -- (UPDATE 4 LAVA) molten rock running down the vent
    local half = strip.Size.Z / 2 - 0.8
    DungeonGenerator.Lava().Flow(geo.Parent or geo, (cf * CFrame.new(0, 0.27, -half)).Position, (cf * CFrame.new(0, 0.27, half)).Position, 2.6,
        { Light = false, Smoke = false, Speed = 0.07 })
    for i = -1, 1, 2 do
        Block(geo, Vector3.new(1.4, 1.1, strip.Size.Z), cf * CFrame.new(i * 2.4, 0.55, 0), Shade(theme.PropAlt, rng))
    end
end
local function Brazier(geo, theme, rng, pos)
    VCyl(geo, 1.4, 3, pos + Vector3.new(0, 1.5, 0), { Color = C3(40, 36, 36), Material = Enum.Material.Metal })
    local bowl = VCyl(geo, 3.2, 0.9, pos + Vector3.new(0, 3.3, 0), { Color = C3(52, 46, 44), Material = Enum.Material.CorrodedMetal })
    -- (UPDATE 4 LAVA) glowing coals in the bowl
    DungeonGenerator.Lava().Pool(geo.Parent or geo, CFrame.new(pos + Vector3.new(0, 3.76, 0)), 1.35, { Light = false, Smoke = false })
    local fire = Instance.new("Fire")
    fire.Size = 4
    fire.Heat = 7
    fire.Color = C3(255, 120, 40)
    fire.SecondaryColor = C3(255, 60, 20)
    fire.Parent = bowl
    -- (no PointLight: the fire lights itself well enough -- PERFORMANCE 2026-10-03)
end
Props.Fire = { Cover = { RuinedWall, RuinedWall, LavaVent }, Tall = { BasaltCluster, ObsidianSpire }, Air = {} }

-- ----- Ice: Frozen Cavern -----
local function IceSpire(geo, theme, rng, pos)
    -- (UPDATE 4 PROPS) an ice crystal cluster mesh with one box hitbox; the stacked cylinders are the fallback
    local EK = require(script.Parent:WaitForChild("EnvKit"))
    local kit = (rng:NextNumber() < 0.5) and "IceCrystalsA" or "IceCrystalsB"
    if EK.Has("Ice", kit) then
        EK.Place("Ice", kit, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
            { Scale = rng:NextNumber(0.9, 1.25), Parent = geo.Parent or geo, Hitbox = true, HitParent = geo, HitScale = 0.7 })
        return
    end
    local y = 0
    local d = rng:NextNumber(4, 5.5)
    for _ = 1, 3 do
        local h = rng:NextNumber(3.5, 6)
        VCyl(geo, d, h, pos + Vector3.new(rng:NextNumber(-0.3, 0.3), y + h / 2, rng:NextNumber(-0.3, 0.3)), Shade(theme.Prop, rng, 0.05))
        y += h
        d *= 0.62
    end
end
local function SnowRidge(geo, theme, rng, pos)
    local len, h, depth = rng:NextNumber(10, 16), rng:NextNumber(3, 5), rng:NextNumber(3.5, 5)
    local cf = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * Yaw(rng)
    Block(geo, Vector3.new(len, h, depth), cf * CFrame.new(0, 0, -depth / 2), theme.PropAlt, "WedgePart")
    Block(geo, Vector3.new(len, h, depth), cf * CFrame.new(0, 0, depth / 2) * CFrame.Angles(0, math.pi, 0), theme.PropAlt, "WedgePart")
end
local function FrozenCrate(geo, theme, rng, pos)
    local cf = CFrame.new(pos) * Yaw(rng)
    local s = rng:NextNumber(3.5, 4.5)
    Block(geo, Vector3.new(s, s, s), cf * CFrame.new(0, s / 2, 0), { Color = C3(92, 78, 64), Material = Enum.Material.WoodPlanks })
    Block(geo, Vector3.new(s + 0.3, 0.5, s + 0.3), cf * CFrame.new(0, s + 0.25, 0), theme.PropAlt)
    if rng:NextNumber() < 0.5 then
        Block(geo, Vector3.new(s * 0.8, s * 0.8, s * 0.8), cf * CFrame.new(s * 0.2, s * 1.4 + 0.5, 0) * CFrame.Angles(0, 0.5, 0), { Color = C3(92, 78, 64), Material = Enum.Material.WoodPlanks })
    end
end
local function IceBoulder(geo, theme, rng, pos)
    if DungeonGenerator.KitCover("Ice", { "SnowBoulder", "SnowRockB" }, geo, rng, pos, 0.9, 1.3) then return end -- (UPDATE 4 PROPS)
    local d = rng:NextNumber(5, 9)
    Ball(geo, d, pos + Vector3.new(0, d * 0.3, 0), Shade(theme.Prop, rng, 0.05))
end
Props.Ice = { Cover = { SnowRidge, FrozenCrate, IceBoulder }, Tall = { IceSpire }, Air = {} }

-- ----- Void: Shattered Rift -----
local function Monolith(geo, theme, rng, pos)
    -- (UPDATE 4 PROPS: a scanned rock slab stood on end, a small crystal cluster at its foot; the block + neon strip =
    -- the fallback)
    if DungeonGenerator.KitCover("Void", { "VoidMonolith" }, geo, rng, pos, 0.85, 1.25) then
        local EK = require(script.Parent:WaitForChild("EnvKit"))
        EK.Place("Void", "VoidCrystalsA", CFrame.new(pos + Vector3.new(rng:NextNumber(-3.5, 3.5), 0, rng:NextNumber(-3.5, 3.5))) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
            { Scale = rng:NextNumber(0.3, 0.45), Parent = geo.Parent or geo, Shadow = false })
        return
    end
    local h = rng:NextNumber(10, 18)
    local cf = CFrame.new(pos + Vector3.new(0, h / 2 - 0.5, 0)) * Yaw(rng) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
    Block(geo, Vector3.new(3.5, h, 7), cf, Shade(theme.Prop, rng))
    Block(geo, Vector3.new(0.3, h * 0.7, 1.2), cf * CFrame.new(1.8, 0, 0), theme.PropAlt)
end
local function RiftCrystal(geo, theme, rng, pos)
    if DungeonGenerator.KitCover("Void", { "VoidCrystalsA", "VoidCrystalsB" }, geo, rng, pos, 0.75, 1.05) then return end -- (UPDATE 4 PROPS)
    for _ = 1, rng:NextInteger(3, 5) do
        local h = rng:NextNumber(3, 7)
        local cf = CFrame.new(pos + Vector3.new(rng:NextNumber(-1.5, 1.5), h / 2 - 0.5, rng:NextNumber(-1.5, 1.5)))
            * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4))
        local c = Block(geo, Vector3.new(rng:NextNumber(1.2, 2), h, rng:NextNumber(1.2, 2)), cf, theme.PropAlt)
        c.Reflectance = 0.1
    end
end
local function BrokenColumn(geo, theme, rng, pos)
    if DungeonGenerator.KitCover("Void", { "VoidSpire", "VoidStatue" }, geo, rng, pos, 0.6, 0.9) then return end -- (UPDATE 4 PROPS)
    local h = rng:NextNumber(4, 11)
    VCyl(geo, 3.6, h, pos + Vector3.new(0, h / 2, 0), theme.WallTrim)
    local drumCF = CFrame.new(pos + Vector3.new(rng:NextNumber(3, 5), 1.7, rng:NextNumber(-2, 2))) * Yaw(rng)
    HCyl(geo, 3.4, rng:NextNumber(3, 6), drumCF, theme.WallTrim)
end
local function FloatingRock(geo, theme, rng, pos)
    local d = rng:NextNumber(4, 7)
    Ball(geo, d, pos + Vector3.new(0, rng:NextNumber(9, 17), 0), Shade(theme.Prop, rng))
end
Props.Void = { Cover = { BrokenColumn, RiftCrystal }, Tall = { Monolith }, Air = { FloatingRock } }

-- ----- Cyber: Data Foundry -----
local function ServerRack(geo, theme, rng, pos)
    if DungeonGenerator.KitCover("Cyber", { "ServerRack" }, geo, rng, pos, 1.05, 1.2) then return end -- (UPDATE 4 PROPS: the kit rack; the block = fallback)
    local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(90 * rng:NextInteger(0, 3)), 0)
    Block(geo, Vector3.new(3, 8, 5), cf * CFrame.new(0, 4, 0), theme.Prop)
    Block(geo, Vector3.new(0.2, 7.2, 4.4), cf * CFrame.new(1.55, 4, 0), { Color = C3(26, 28, 32), Material = Enum.Material.SmoothPlastic })
    for i = 1, rng:NextInteger(3, 5) do
        local led = Block(geo, Vector3.new(0.12, 0.12, rng:NextNumber(1, 3)), cf * CFrame.new(1.66, 1 + i * 1.2, rng:NextNumber(-0.8, 0.8)),
            { Color = theme.Accent:Lerp(Color3.new(0, 0, 0), 0.55), Material = Enum.Material.Neon })
        led.CanCollide = false
    end
end
local function MetalCrate(geo, theme, rng, pos)
    -- (UPDATE 4 PROPS: scanned sci-fi crates / cases; the trimmed block = the fallback)
    if DungeonGenerator.KitCover("Cyber", { "CyberCrates", "CyberCase" }, geo, rng, pos, 0.9, 1.15) then return end
    local cf = CFrame.new(pos) * Yaw(rng)
    Block(geo, Vector3.new(4, 4, 4), cf * CFrame.new(0, 2, 0), Shade(theme.PropAlt, rng))
    Block(geo, Vector3.new(4.2, 0.3, 4.2), cf * CFrame.new(0, 4.15, 0), theme.FloorAlt)
    for _, sx in ipairs({ -1, 1 }) do
        Block(geo, Vector3.new(0.3, 4.1, 4.1), cf * CFrame.new(sx * 1.4, 2, 0), theme.WallTrim)
    end
end
local function CoolantTank(geo, theme, rng, pos)
    if DungeonGenerator.KitCover("Cyber", { "CyberBarrel" }, geo, rng, pos, 1.7, 2.1) then return end -- (UPDATE 4 PROPS: a scanned canister)
    VCyl(geo, 4.5, 9, pos + Vector3.new(0, 4.5, 0), { Color = C3(84, 92, 98), Material = Enum.Material.Metal })
    for _, y in ipairs({ 2, 7 }) do
        VCyl(geo, 4.8, 0.5, pos + Vector3.new(0, y, 0), theme.WallTrim)
    end
    Ball(geo, 4.4, pos + Vector3.new(0, 9, 0), { Color = C3(84, 92, 98), Material = Enum.Material.Metal })
end
local function PipeRun(geo, theme, rng, pos)
    local cf = CFrame.new(pos) * Yaw(rng)
    local len = rng:NextNumber(12, 18)
    HCyl(geo, 1.4, len, cf * CFrame.new(0, 2.6, 0), Shade(theme.PropAlt, rng))
    for x = -len / 2 + 2, len / 2 - 2, 5 do
        Block(geo, Vector3.new(0.6, 2, 1.2), cf * CFrame.new(x, 1, 0), theme.WallTrim)
    end
end
Props.Cyber = { Cover = { MetalCrate, MetalCrate, PipeRun }, Tall = { ServerRack, CoolantTank }, Air = {} }

-- ----- Storm: Stormspire Citadel -----
local function LightningRod(geo, theme, rng, pos)
    -- a copper spire on a stone footing with a glowing tip (the storm's conductors)
    local h = rng:NextNumber(11, 16)
    -- (UPDATE 4 PROPS: weathered copper -- the scanned CorrodedMetal -- instead of plain Metal cylinders)
    local copper = { Color = theme.PropAlt.Color, Material = Enum.Material.CorrodedMetal }
    local band = { Color = theme.WallTrim.Color, Material = Enum.Material.CorrodedMetal }
    Block(geo, Vector3.new(3.4, 1.2, 3.4), CFrame.new(pos + Vector3.new(0, 0.6, 0)) * Yaw(rng), theme.Prop)
    VCyl(geo, 0.9, h, pos + Vector3.new(0, 1.2 + h / 2, 0), copper)
    for _, y in ipairs({ h * 0.35, h * 0.7 }) do VCyl(geo, 1.5, 0.35, pos + Vector3.new(0, 1.2 + y, 0), band) end
    local tip = Ball(geo, 1.2, pos + Vector3.new(0, 1.4 + h, 0), { Color = theme.Accent, Material = Enum.Material.Neon })
    tip.CanCollide = false
end
local function FallenColumn(geo, theme, rng, pos)
    -- a toppled white column in two pieces + its capital (low cover)
    if DungeonGenerator.KitCover("Storm", { "DeadTrunk", "StormBoulder", "StormSlab" }, geo, rng, pos, 0.8, 1.1) then return end -- (UPDATE 4 PROPS)
    local cf = CFrame.new(pos) * Yaw(rng)
    HCyl(geo, 3, rng:NextNumber(7, 10), cf * CFrame.new(-3, 1.5, 0), Shade(theme.Prop, rng))
    HCyl(geo, 3, rng:NextNumber(4, 6), cf * CFrame.new(5, 1.5, 0.6) * CFrame.Angles(0, math.rad(rng:NextNumber(-15, 15)), 0), Shade(theme.Prop, rng))
    Block(geo, Vector3.new(4, 1.4, 4), cf * CFrame.new(9, 0.7, 0) * CFrame.Angles(0, math.rad(20), 0), theme.FloorAlt)
end
local function TeslaCoil(geo, theme, rng, pos)
    -- a copper coil tower: stacked rings round a core, a glowing torus on top (tall cover)
    local copper = { Color = theme.PropAlt.Color, Material = Enum.Material.CorrodedMetal } -- (UPDATE 4 PROPS: weathered copper)
    VCyl(geo, 3.2, 1.2, pos + Vector3.new(0, 0.6, 0), theme.Prop)
    VCyl(geo, 1.6, 8, pos + Vector3.new(0, 5.2, 0), copper)
    for i = 1, 6 do VCyl(geo, 2.4, 0.3, pos + Vector3.new(0, 1.8 + i * 1.05, 0), { Color = theme.WallTrim.Color, Material = Enum.Material.CorrodedMetal }) end
    local top = Block(geo, Vector3.new(0.6, 4.2, 4.2), CFrame.new(pos + Vector3.new(0, 9.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), { Color = theme.Accent, Material = Enum.Material.Neon })
    ;(top :: Part).Shape = Enum.PartType.Cylinder
    top.CanCollide = false
end
local function StormBlock(geo, theme, rng, pos)
    -- a squared stone block with a copper band (cover)
    local cf = CFrame.new(pos) * Yaw(rng)
    Block(geo, Vector3.new(5, 4.4, 5), cf * CFrame.new(0, 2.2, 0), Shade(theme.Prop, rng))
    Block(geo, Vector3.new(5.2, 0.5, 5.2), cf * CFrame.new(0, 3.2, 0), theme.WallTrim)
end
local function FloatingShard(geo, theme, rng, pos)
    -- broken masonry hanging in the storm air
    local p = Block(geo, Vector3.new(rng:NextNumber(3, 5), rng:NextNumber(2, 3.5), rng:NextNumber(3, 5)),
        CFrame.new(pos + Vector3.new(0, rng:NextNumber(12, 20), 0)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), rng:NextNumber(0, 1)), Shade(theme.Prop, rng))
    p.CanCollide = false
end
Props.Storm = { Cover = { StormBlock, FallenColumn, StormBlock }, Tall = { LightningRod, TeslaCoil }, Air = { FloatingShard } }

-- ==================== [LANDMARKS] ====================
-- Two per biome, picked at random each floor, arranged around the (kept-clear) center plaza.
local Landmarks: { [string]: { (geo: Instance, theme: BiomeTheme, rng: Random, center: Vector3) -> () } } = {
    Fire = {
        function(geo, theme, rng, c) -- Caldera: ring of basalt with lava vents radiating out
            for i = 0, 7 do
                local a = i * math.pi / 4
                BasaltCluster(geo, theme, rng, c + Vector3.new(math.cos(a) * 28, 0, math.sin(a) * 28))
            end
            for i = 0, 3 do
                local a = i * math.pi / 2 + math.pi / 4
                local cf = CFrame.new(c + Vector3.new(math.cos(a) * 30, 0.12, math.sin(a) * 30)) * CFrame.Angles(0, -a, 0)
                local strip = Block(geo, Vector3.new(16, 0.3, 3.2), cf, theme.FloorAlt)
                strip.CanCollide = false
                -- (UPDATE 4 LAVA) molten rock runs out of each vent (decor: in the floor folder, not the steering geo)
                local dir = Vector3.new(math.cos(a), 0, math.sin(a))
                local mid = c + dir * 30 + Vector3.new(0, 0.27, 0)
                DungeonGenerator.Lava().Flow(geo.Parent or geo, mid - dir * 7.4, mid + dir * 7.4, 2.4, { Light = false, Smoke = false, Speed = 0.08 })
            end
        end,
        function(geo, theme, rng, c) -- Forge Hall: long ruined walls + four braziers
            for _, sx in ipairs({ -1, 1 }) do
                for _, sz in ipairs({ -1, 1 }) do
                    RuinedWall(geo, theme, rng, c + Vector3.new(sx * 26, 0, sz * 16))
                    Brazier(geo, theme, rng, c + Vector3.new(sx * 17, 0, sz * 17))
                end
            end
        end,
    },
    Ice = {
        function(geo, theme, rng, c) -- Frozen Lake: an ice sheet ringed by spires
            local lake = Block(geo, Vector3.new(0.4, 64, 64), CFrame.new(c + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), theme.FloorAlt)
            ;(lake :: Part).Shape = Enum.PartType.Cylinder
            for i = 0, 5 do
                local a = i * math.pi / 3 + 0.3
                IceSpire(geo, theme, rng, c + Vector3.new(math.cos(a) * 33, 0, math.sin(a) * 33))
            end
        end,
        function(geo, theme, rng, c) -- Glacier Ridges: snow ridges framing the plaza + boulders
            for i = 0, 3 do
                local a = i * math.pi / 2
                SnowRidge(geo, theme, rng, c + Vector3.new(math.cos(a) * 25, 0, math.sin(a) * 25))
                IceBoulder(geo, theme, rng, c + Vector3.new(math.cos(a + 0.8) * 32, 0, math.sin(a + 0.8) * 32))
            end
        end,
    },
    Void = {
        function(geo, theme, rng, c) -- Obelisk Circle
            for i = 0, 5 do
                local a = i * math.pi / 3
                Monolith(geo, theme, rng, c + Vector3.new(math.cos(a) * 28, 0, math.sin(a) * 28))
            end
        end,
        function(geo, theme, rng, c) -- Shattered Isles: floating rocks over crystal outcrops
            for i = 0, 4 do
                local a = i * math.pi * 2 / 5
                FloatingRock(geo, theme, rng, c + Vector3.new(math.cos(a) * 26, 0, math.sin(a) * 26))
                RiftCrystal(geo, theme, rng, c + Vector3.new(math.cos(a + 0.6) * 32, 0, math.sin(a + 0.6) * 32))
            end
        end,
    },
    Cyber = {
        function(geo, theme, rng, c) -- Server Rows
            for _, sx in ipairs({ -1, 1 }) do
                for i = -1, 1 do
                    ServerRack(geo, theme, rng, c + Vector3.new(sx * 24, 0, i * 7 - 12))
                    ServerRack(geo, theme, rng, c + Vector3.new(sx * 24, 0, i * 7 + 14))
                end
            end
        end,
        function(geo, theme, rng, c) -- Coolant Plant
            for _, sx in ipairs({ -1, 1 }) do
                for _, sz in ipairs({ -1, 1 }) do
                    CoolantTank(geo, theme, rng, c + Vector3.new(sx * 26, 0, sz * 26))
                end
                PipeRun(geo, theme, rng, c + Vector3.new(sx * 26, 0, 0))
            end
        end,
    },
    Storm = {
        function(geo, theme, rng, c) -- Conductor Ring: eight lightning rods round the plaza
            for i = 0, 7 do
                local a = i * math.pi / 4 + 0.2
                LightningRod(geo, theme, rng, c + Vector3.new(math.cos(a) * 30, 0, math.sin(a) * 30))
            end
        end,
        function(geo, theme, rng, c) -- Broken Bastion: tesla coils at the corners, fallen columns between
            for _, sx in ipairs({ -1, 1 }) do
                for _, sz in ipairs({ -1, 1 }) do
                    TeslaCoil(geo, theme, rng, c + Vector3.new(sx * 27, 0, sz * 27))
                end
                FallenColumn(geo, theme, rng, c + Vector3.new(sx * 30, 0, 0))
            end
        end,
    },
}

-- Scatter props across a chamber, keeping out of reserved zones and away from each other.
local function ScatterProps(geo: Instance, theme: BiomeTheme, set: any, rng: Random, centerZ: number, halfExtent: number,
    count: number, reserved: { { Pos: Vector3, R: number } })
    local placed: { Vector3 } = {}
    local pools = { set.Cover, set.Cover, set.Tall }
    if #set.Air > 0 then table.insert(pools, set.Air) end
    local attempts = 0
    while #placed < count and attempts < count * 12 do
        attempts += 1
        local pos = Vector3.new(rng:NextNumber(-halfExtent, halfExtent), FLOOR_TOP, centerZ + rng:NextNumber(-halfExtent, halfExtent))
        local ok = true
        for _, r in ipairs(reserved) do
            local d = Vector2.new(pos.X - r.Pos.X, pos.Z - r.Pos.Z).Magnitude
            if r.Ring then
                if d > r.R and d < r.Ring then ok = false break end
            elseif d < r.R + 6 then ok = false break end -- (0.61e: + the prop's own footprint -- centres were checked alone)
        end
        if ok then
            for _, q in ipairs(placed) do
                if (q - pos).Magnitude < 12 then ok = false break end
            end
        end
        if ok then
            local pool = pools[rng:NextInteger(1, #pools)]
            if #pool > 0 then
                pool[rng:NextInteger(1, #pool)](geo, theme, rng, pos)
                table.insert(placed, pos)
            end
        end
    end
end

-- ==================== [CHESTS] ====================
-- CHESTS v3 (owner 2026-10-11: "Portals and chests are still very underwhelming, they ALL need to be heavily improved
-- cosmetic wise"): reference = an ARPG strongbox / league chest. A heavy iron-banded box on a metal skirt, corner posts,
-- rivets, a glowing CRACK all round under the lid, a hipped lid with its own bands + caps, a glowing lock and a gem sigil
-- on the lid; the tier adds ornament (Victory < MiniBoss handles < Titan crest spikes < SuperBoss orbiting runes). Inside: a
-- treasure heap that only shows once the lid swings back. Opening = the lid swings on its back hinge, a flash, a burst
-- of motes, a light shaft that pinches out, a sound; the interior keeps glowing.
-- Animation: ONE shared Heartbeat loop for every chest + portal (FxAnim below), client only, culled past 220 studs.
type ChestStyle = { Wood: Color3, Band: Color3, Lock: Color3, Scale: number, Glow: Color3?, Tier: number?, Iron: Color3?,
    Trim: Color3?, Gem: Color3?, BodyMat: Enum.Material? }
local ChestStyles: { [string]: ChestStyle } = {
    Supply = { Wood = C3(92, 64, 40), Band = C3(84, 88, 96), Lock = C3(150, 156, 164), Scale = 0.72, Tier = 0, Iron = C3(58, 62, 70),
        Trim = C3(120, 126, 136), Gem = C3(110, 210, 255) },
    Victory = { Wood = C3(96, 60, 34), Band = C3(70, 66, 64), Lock = C3(232, 192, 84), Scale = 1, Glow = C3(255, 200, 110), Tier = 1,
        Iron = C3(52, 50, 50), Trim = C3(214, 168, 66), Gem = C3(255, 196, 80) },
    MiniBoss = { Wood = C3(64, 36, 26), Band = C3(62, 52, 48), Lock = C3(240, 150, 70), Scale = 1.1, Glow = C3(255, 150, 80), Tier = 2,
        Iron = C3(46, 40, 38), Trim = C3(208, 120, 58), Gem = C3(255, 120, 60) },
    Titan = { Wood = C3(70, 28, 26), Band = C3(48, 44, 46), Lock = C3(250, 214, 110), Scale = 1.2, Glow = C3(255, 205, 100), Tier = 3,
        Iron = C3(40, 36, 38), Trim = C3(230, 186, 70), Gem = C3(255, 70, 60), BodyMat = Enum.Material.Metal },
    SuperBoss = { Wood = C3(30, 22, 40), Band = C3(40, 34, 52), Lock = C3(214, 184, 255), Scale = 1.3, Glow = C3(190, 140, 255), Tier = 4,
        Iron = C3(30, 26, 38), Trim = C3(226, 190, 96), Gem = C3(170, 110, 255), BodyMat = Enum.Material.Metal },
}

-- SHARED FX LOOP (chests + portals): FxAnim.Add(kind, part, data) -- kinds Spin (about the part's base Z), Bob (bob +
-- turn about Y), Pulse (Transparency between T0 and T1), Orbit (round Center at Radius, Height bob). Client only.
local FxAnim = { List = {}, Conn = nil :: RBXScriptConnection? }
function FxAnim.Add(kind: string, part: BasePart, data: any)
    if not IS_CLIENT then return end
    data.Kind, data.Part = kind, part
    data.Base = data.Base or part.CFrame
    data.Phase = data.Phase or math.random() * 6.283
    table.insert(FxAnim.List, data)
    if FxAnim.Conn then return end
    FxAnim.Conn = RunService.Heartbeat:Connect(function()
        local list = FxAnim.List
        if #list == 0 then
            if FxAnim.Conn then FxAnim.Conn:Disconnect(); FxAnim.Conn = nil end
            return
        end
        local t = os.clock()
        local cam = Workspace.CurrentCamera
        local eye = cam and cam.CFrame.Position or Vector3.zero
        for i = #list, 1, -1 do
            local a = list[i]
            local p = a.Part
            if not p.Parent then
                table.remove(list, i)
            elseif (a.Base.Position - eye).Magnitude < 220 then
                local k = t + a.Phase
                if a.Kind == "Spin" then
                    p.CFrame = a.Base * CFrame.Angles(0, 0, t * a.Rate)
                elseif a.Kind == "Bob" then
                    p.CFrame = a.Base * CFrame.new(0, math.sin(k * (a.Speed or 1.4)) * (a.Amp or 0.25), 0) * CFrame.Angles(0, t * (a.Turn or 0.8), 0)
                elseif a.Kind == "Pulse" then
                    p.Transparency = a.T0 + (a.T1 - a.T0) * (0.5 + 0.5 * math.sin(k * (a.Speed or 2)))
                elseif a.Kind == "Orbit" then
                    local ang = t * (a.Rate or 0.6) + a.Phase
                    p.CFrame = a.Center * CFrame.Angles(0, ang, 0) * CFrame.new(a.Radius, math.sin(k * 1.7) * 0.25, 0) * CFrame.Angles(0, -ang + t * 1.2, 0)
                elseif a.Kind == "GuiSpin" then -- (UPDATE 4: an image layer turns (deg/s); T0 / T1 pulse its ImageTransparency)
                    a.Label.Rotation = (t * a.Rate) % 360
                    if a.T0 then a.Label.ImageTransparency = a.T0 + (a.T1 - a.T0) * (0.5 + 0.5 * math.sin(k * (a.Speed or 2))) end
                end
            end
        end
    end)
end
-- (UPDATE 4) SELF-LIT FX IMAGES for portals + chests (tools/make_fx_art.py; white + alpha, tinted per biome / path). They sit
-- on SurfaceGuis with LightInfluence 0: the same glow under every biome's light, no parts per detail.
DungeonGenerator.FX_IMG = { Depth = "rbxassetid://115595887092843", Swirl = "rbxassetid://93462311289317", Swirl2 = "rbxassetid://74215633658541",
    Rim = "rbxassetid://122867097434751", Rune = "rbxassetid://81084540294861", Glow = "rbxassetid://136808539004321",
    Filigree = "rbxassetid://137392550012423", Lid = "rbxassetid://136537405395833" }
-- (UPDATE 4 LAVA) the LavaFX module (molten pools / rivers / falls / glows: AimRngShared/LavaFX), required on first use
function DungeonGenerator.Lava()
    local L = DungeonGenerator._lava
    if not L then
        L = require(script.Parent:WaitForChild("LavaFX"))
        DungeonGenerator._lava = L
    end
    return L
end
-- (helpers live on FxAnim: this chunk is near the 200-local limit)
-- FxAnim.Face = a flat invisible part carrying a SurfaceGui on `face`; returns (part, Layer(img, scale, color, transparency, z) -> ImageLabel)
function FxAnim.Face(model: Instance, size: Vector3, cf: CFrame, face: Enum.NormalId, pps: number, bright: number)
    local p = Instance.new("Part")
    p.Name = "FxFace"; p.Size = size; p.CFrame = cf; p.Anchored = true; p.Transparency = 1
    p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
    p.Parent = model
    local sg = Instance.new("SurfaceGui")
    sg.Face = face; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = pps
    sg.LightInfluence = 0; sg.Brightness = bright; sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = p
    local function Layer(img: string, scale: number, col: Color3, t: number, z: number): ImageLabel
        local l = Instance.new("ImageLabel")
        l.BackgroundTransparency = 1; l.AnchorPoint = Vector2.new(0.5, 0.5); l.Position = UDim2.fromScale(0.5, 0.5)
        l.Size = UDim2.fromScale(scale, scale); l.Image = img; l.ImageColor3 = col; l.ImageTransparency = t; l.ZIndex = z
        l.Parent = sg
        return l
    end
    return p, Layer
end
-- particles a portal / chest can live without: off on Graphics Quality Low (QualityMode's "QDetail" tag replicates)
function FxAnim.Low(e: Instance) CollectionService:AddTag(e, "QDetail") end
-- the visible ground under a spot: open maps' terrain renders up to ~1 stud over FLOOR_TOP (same probe as the chests)
function FxAnim.Ground(p: Vector3): number
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { Workspace.Terrain }
    local hit = Workspace:Raycast(p + Vector3.new(0, 12, 0), Vector3.new(0, -30, 0), rp)
    return hit and math.max(p.Y, hit.Position.Y) or p.Y
end
local function FxPart(model: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, t: number?, shape: Enum.PartType?): Part
    local p = Block(model, size, cf, { Color = color, Material = mat, Transparency = t }) :: Part
    if shape then p.Shape = shape end
    p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
    if mat == Enum.Material.Neon or (t or 0) > 0.2 then p.CastShadow = false end
    return p
end

-- Builds a chest standing on the floor at `floorCF` (facing -Z: the lock side). Returns (model, openFn).
local function BuildChest(parent: Instance, floorCF: CFrame, styleName: string, label: string?): (Model, () -> ())
    do -- (owner 2026-10-05: "Chests are kind of in the ground"): the open maps' terrain renders up to ~1 stud above the
        -- arena's floor part, so a chest built at FLOOR_TOP sank into it -- stand it on whichever surface is higher
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Include
        rp.FilterDescendantsInstances = { Workspace.Terrain }
        local p = floorCF.Position
        -- (sample round the footprint, not just the centre: the terrain right under a vault can be cleared while the ground
        -- round it renders 2 studs higher -- the chest sat in a pit)
        local top = p.Y
        for _, o in ipairs({ Vector3.zero, Vector3.new(4, 0, 0), Vector3.new(-4, 0, 0), Vector3.new(0, 0, 4), Vector3.new(0, 0, -4) }) do
            local hit = Workspace:Raycast(p + o + Vector3.new(0, 12, 0), Vector3.new(0, -30, 0), rp)
            if hit then top = math.max(top, hit.Position.Y) end
        end
        if top > p.Y then floorCF = floorCF + Vector3.new(0, top - p.Y + 0.05, 0) end
    end
    local st = ChestStyles[styleName] or ChestStyles.Victory
    local s = st.Scale
    local tier = st.Tier or 1
    local glowC = st.Glow or C3(110, 210, 255) -- (supply caches: a cool cyan glow so they read on any floor)
    local iron, trim, gemC = st.Iron or st.Band, st.Trim or st.Lock, st.Gem or glowC
    local W, H, D = 4.6 * s, 2.3 * s, 3.0 * s
    local Lh = 1.15 * s -- lid height (box + hipped top)
    local G = 0.08 * s -- the glowing crack between the box and the lid
    local model = Instance.new("Model")
    model.Name = "Chest_" .. styleName
    local metal = Enum.Material.Metal
    local bodySurf = { Color = st.Wood, Material = st.BodyMat or Enum.Material.WoodPlanks }
    local base = floorCF * CFrame.new(0, H / 2, 0)
    local body = Block(model, Vector3.new(W, H, D), base, bodySurf)
    model.PrimaryPart = body
    -- (UPDATE 4, owner: chests "should be redone to look absolutely stunning") gilded FILIGREE on the front + back: a
    -- Decal in the trim colour (it takes the scene light like the metal round it) -- scrolls, vines, a medallion at the lock
    local FX = DungeonGenerator.FX_IMG
    for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
        local dcl = Instance.new("Decal"); dcl.Name = "ChestFiligree"; dcl.Face = f; dcl.Texture = FX.Filigree; dcl.Color3 = trim; dcl.Parent = body
    end

    -- BODY: metal skirt, iron bands front-to-back, corner posts, a rim under the lid, rivets on the front bands
    Block(model, Vector3.new(W + 0.34 * s, 0.32 * s, D + 0.34 * s), floorCF * CFrame.new(0, 0.16 * s, 0), { Color = iron, Material = metal })
    for _, fx in ipairs({ -0.3, 0.3 }) do
        Block(model, Vector3.new(0.38 * s, H + 0.04, D + 0.12), base * CFrame.new(fx * W, 0, 0), { Color = iron, Material = metal })
        for _, fy in ipairs({ -0.22, 0.24 }) do
            FxPart(model, Vector3.new(0.2, 0.2, 0.2) * s, base * CFrame.new(fx * W, fy * H, -D / 2 - 0.07), trim, metal, nil, Enum.PartType.Ball)
        end
    end
    for _, cx in ipairs({ -1, 1 }) do
        for _, cz in ipairs({ -1, 1 }) do
            Block(model, Vector3.new(0.46 * s, H + 0.06, 0.46 * s), base * CFrame.new(cx * (W / 2 - 0.14 * s), 0, cz * (D / 2 - 0.14 * s)), { Color = trim, Material = metal })
        end
    end
    Block(model, Vector3.new(W + 0.12, 0.24 * s, D + 0.12), floorCF * CFrame.new(0, H - 0.2 * s, 0), { Color = iron, Material = metal })
    if tier >= 2 then -- side handles (heavy iron grips)
        for _, sx in ipairs({ -1, 1 }) do
            Block(model, Vector3.new(0.16 * s, 0.22 * s, 1.3 * s), base * CFrame.new(sx * (W / 2 + 0.2 * s), 0.12 * H, 0), { Color = trim, Material = metal })
        end
    end
    -- the glowing CRACK all round under the lid (it stays lit once open: the interior glow)
    local seam = FxPart(model, Vector3.new(W + 0.02, G + 0.08 * s, D + 0.02), floorCF * CFrame.new(0, H + G / 2, 0), glowC, Enum.Material.Neon, tier == 0 and 0.55 or 0.25)
    seam.Name = "ChestSeam"
    FxAnim.Add("Pulse", seam, { T0 = tier == 0 and 0.45 or 0.12, T1 = tier == 0 and 0.75 or 0.5, Speed = 2.2 })
    -- the inside (seen once the lid is up): dark until opened, then it glows; a treasure heap sits under the lid
    local inside = Block(model, Vector3.new(W - 0.4 * s, 0.05, D - 0.4 * s), floorCF * CFrame.new(0, H + 0.03, 0), { Color = C3(26, 20, 16), Material = Enum.Material.Wood })
    inside.Name = "ChestInside"
    local pile = FxPart(model, Vector3.new(W * 0.66, 0.55 * s, D * 0.56), floorCF * CFrame.new(0, H + 0.04, 0.1 * s),
        tier == 0 and C3(150, 156, 166) or trim:Lerp(C3(255, 240, 190), 0.25), metal)
    local pm = Instance.new("SpecialMesh"); pm.MeshType = Enum.MeshType.Sphere; pm.Parent = pile
    pile.Name = "ChestTreasure"

    -- LID (everything in lidParts swings open on the back hinge): box + hipped top, bands, a gilded front lip, corner caps,
    -- the glowing lock + keyhole on the front, a gem sigil on top, crest spikes on Titan+, runes float over a SuperBoss chest
    local lidParts: { BasePart } = {}
    local function L(p: BasePart): BasePart table.insert(lidParts, p) return p end
    local lidBox = floorCF * CFrame.new(0, H + G + Lh * 0.28, 0)
    L(Block(model, Vector3.new(W + 0.06, Lh * 0.56, D + 0.06), lidBox, bodySurf))
    local lidTop = L(Block(model, Vector3.new(W - 0.55 * s, Lh * 0.44, D - 0.7 * s), floorCF * CFrame.new(0, H + G + Lh * 0.78, 0), bodySurf))
    local lidDcl = Instance.new("Decal"); lidDcl.Name = "ChestFiligree"; lidDcl.Face = Enum.NormalId.Top; lidDcl.Texture = FX.Lid; lidDcl.Color3 = trim; lidDcl.Parent = lidTop
    for _, fx in ipairs({ -0.3, 0.3 }) do
        L(Block(model, Vector3.new(0.38 * s, Lh * 0.56 + 0.04, D + 0.14), lidBox * CFrame.new(fx * W, 0, 0), { Color = iron, Material = metal }))
        L(Block(model, Vector3.new(0.38 * s, 0.1 * s, D - 0.6 * s), floorCF * CFrame.new(fx * W, H + G + Lh, 0), { Color = iron, Material = metal }))
    end
    L(Block(model, Vector3.new(W + 0.14, 0.18 * s, 0.14 * s), floorCF * CFrame.new(0, H + G + 0.1 * s, -D / 2 - 0.05), { Color = trim, Material = metal }))
    for _, cx in ipairs({ -1, 1 }) do
        for _, cz in ipairs({ -1, 1 }) do
            L(Block(model, Vector3.new(0.5 * s, Lh * 0.56 + 0.08, 0.5 * s), lidBox * CFrame.new(cx * (W / 2 - 0.12 * s), 0, cz * (D / 2 - 0.12 * s)), { Color = trim, Material = metal }))
            if tier >= 3 then -- crest spikes (tilted outward)
                local c = L(FxPart(model, Vector3.new(0.26, 0.85, 0.26) * s, lidBox * CFrame.new(cx * (W / 2 - 0.12 * s), Lh * 0.5, cz * (D / 2 - 0.12 * s))
                    * CFrame.Angles(math.rad(-22 * cz), 0, math.rad(22 * cx)) * CFrame.new(0, 0.32 * s, 0), trim, metal))
                c.CanCollide = false
            end
        end
    end
    local lock = L(Block(model, Vector3.new(0.85 * s, 0.95 * s, 0.22 * s), floorCF * CFrame.new(0, H + 0.02 * s, -D / 2 - 0.12 * s), { Color = st.Lock, Material = metal }))
    local keyhole = L(FxPart(model, Vector3.new(0.16 * s, 0.34 * s, 0.06), lock.CFrame * CFrame.new(0, -0.08 * s, -0.13 * s), glowC, Enum.Material.Neon, 0.1))
    FxAnim.Add("Pulse", keyhole, { T0 = 0, T1 = 0.45, Speed = 3.1 })
    local gem = L(FxPart(model, Vector3.new(0.5, 0.5, 0.5) * s, floorCF * CFrame.new(0, H + G + Lh + 0.12 * s, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), gemC, Enum.Material.Neon, 0.1))
    gem.Name = "ChestSigil"
    FxAnim.Add("Pulse", gem, { T0 = 0.02, T1 = 0.4, Speed = 1.6 })
    if tier >= 4 then -- three runes orbiting over the lid
        local center = floorCF * CFrame.new(0, H + Lh + 1.6 * s, 0)
        for i = 0, 2 do
            local r = FxPart(model, Vector3.new(0.5, 0.75, 0.08) * s, center * CFrame.new(W * 0.5, 0, 0), gemC, Enum.Material.Neon, 0.15)
            r.Name = "ChestRune"
            FxAnim.Add("Orbit", r, { Center = center, Radius = W * 0.52, Rate = 0.7, Phase = i * 2.094 })
        end
    end

    -- (UPDATE 4) a self-lit RUNE CIRCLE on the floor round it (was a flat Neon disc that read as a solid plate): a soft
    -- glow + a band of glyphs turning slowly; it flares when the lid opens. Soft motes rise off the chest.
    local ring, RingLayer = FxAnim.Face(model, Vector3.new(W * 2.3, 0.05, W * 2.3), floorCF * CFrame.new(0, 0.3, 0), Enum.NormalId.Top, 24, 1.3) -- (0.3: terrain is bumpy at voxel scale)
    ring.Name = "ChestRing"
    local ringGlow = RingLayer(FX.Glow, 0.95, glowC, tier == 0 and 0.6 or 0.42, 1)
    local ringRune = RingLayer(FX.Rune, 0.86, glowC:Lerp(Color3.new(1, 1, 1), 0.3), tier == 0 and 0.5 or 0.25, 2)
    FxAnim.Add("GuiSpin", ring, { Label = ringRune, Rate = 10 + tier * 3 })
    local sparkAt = Instance.new("Attachment")
    sparkAt.Position = Vector3.new(0, H / 2, 0)
    sparkAt.Parent = body
    local sparks = Instance.new("ParticleEmitter")
    sparks.Name = "ChestSparkles"
    sparks.Color = ColorSequence.new(glowC:Lerp(Color3.new(1, 1, 1), 0.35), glowC)
    sparks.LightEmission = 1
    sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.16 * s), NumberSequenceKeypoint.new(1, 0) })
    sparks.Transparency = NumberSequence.new(0.1, 1)
    sparks.Lifetime = NumberRange.new(1.2, 2.2)
    sparks.Rate = tier == 0 and 3 or (3 + tier * 1.5)
    sparks.Speed = NumberRange.new(0.6, 1.6)
    sparks.SpreadAngle = Vector2.new(60, 60)
    sparks.Acceleration = Vector3.new(0, 0.8, 0)
    sparks.Parent = sparkAt
    FxAnim.Low(sparks) -- (the open burst still plays: Emit works on a switched-off emitter)
    do
        local glow = Instance.new("PointLight")
        glow.Color = glowC
        glow.Brightness = tier == 0 and 0.7 or 1
        glow.Range = tier == 0 and 10 or (12 + tier * 1.5)
        glow.Shadows = false
        glow.Parent = body
    end
    if label then
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0, 170, 0, 26)
        bb.StudsOffset = Vector3.new(0, H + Lh + (tier >= 4 and 2.6 or 1.4) * s, 0)
        bb.MaxDistance = 70
        bb.Adornee = body
        bb.Parent = model
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, 0, 1, 0)
        t.BackgroundTransparency = 1
        t.Font = Enum.Font.GothamBold
        t.TextSize = 15
        t.TextColor3 = st.Lock
        t.TextStrokeTransparency = 0.4
        t.Text = label
        t.Parent = bb
    end
    -- (owner 2026-10-03: "walking under / on the back of the chest slides you under it" -- the lid pieces acted as a
    -- ramp and the swinging lid shoved you) one plain box takes every collision; the pieces are all non-solid
    for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide = false end end
    local col = Instance.new("Part")
    col.Name = "ChestCollider"; col.Anchored = true; col.Transparency = 1; col.CanQuery = false; col.CanTouch = false; col.CastShadow = false
    col.Size = Vector3.new(W + 0.3, H + G + Lh, D + 0.3)
    col.CFrame = floorCF * CFrame.new(0, (H + G + Lh) / 2, 0)
    col.Parent = model
    model.Parent = parent

    local opened = false
    local function Open()
        if opened then return end
        opened = true
        model:SetAttribute("Opened", true) -- (GroundLoot lines this chest's loot up in front of it)
        local hinge = floorCF * CFrame.new(0, H + G, D / 2)
        local swing = hinge * CFrame.Angles(math.rad(105), 0, 0) * hinge:Inverse()
        for _, p in ipairs(lidParts) do
            if IS_CLIENT then -- (the lid swings open; server-built party chests snap open -- tweens there would stutter)
                TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = swing * p.CFrame }):Play()
            else
                p.CFrame = swing * p.CFrame
            end
        end
        -- (the swinging parts + the crack leave the animation list: the lid pose is final, the open glow stays steady)
        for i = #FxAnim.List, 1, -1 do
            local a = FxAnim.List[i]
            if a.Part == gem or a.Part == keyhole or a.Part == seam then table.remove(FxAnim.List, i) end
        end
        inside.Material = Enum.Material.Neon
        inside.Color = glowC:Lerp(Color3.new(1, 1, 1), 0.2)
        inside.Transparency = 0.15
        pile.Material = Enum.Material.Neon
        pile.Color = trim:Lerp(glowC, 0.35)
        pile.Transparency = 0.1
        seam.Transparency = 0.05
        local burst = Instance.new("PointLight")
        burst.Color = glowC
        burst.Brightness = 2.5
        burst.Range = 18 + tier * 2
        burst.Shadows = false
        burst.Parent = body
        Debris:AddItem(burst, 1.4)
        if IS_CLIENT then
            TweenService:Create(burst, TweenInfo.new(1.3), { Brightness = 0 }):Play()
            -- a shaft of light out of the box that pinches out
            local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, H / 2, 0); a0.Parent = body
            local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, H / 2 + 9 + tier * 3, 0); a1.Parent = body
            local shaft = Instance.new("Beam")
            shaft.Attachment0, shaft.Attachment1 = a0, a1
            shaft.Color = ColorSequence.new(glowC:Lerp(Color3.new(1, 1, 1), 0.5), glowC)
            shaft.Transparency = NumberSequence.new(0.2, 1)
            shaft.Width0, shaft.Width1 = W * 0.7, W * 0.25
            shaft.LightEmission = 1; shaft.LightInfluence = 0; shaft.FaceCamera = true; shaft.Segments = 2
            shaft.Parent = body
            TweenService:Create(shaft, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Width0 = 0, Width1 = 0 }):Play()
            Debris:AddItem(shaft, 1.2); Debris:AddItem(a0, 1.2); Debris:AddItem(a1, 1.2)
            local snd = Instance.new("Sound")
            snd.SoundId = "rbxassetid://138494756401216" -- (SoundHelper "ChestOpen", v4 game sounds: latch + wooden lid)
            snd.Volume = 0.69
            pcall(function() -- (v4 FALLBACK: the old clip until the new one is confirmed loadable -- SoundHelper.Resolve)
                local SH = require(script.Parent:FindFirstChild("SoundHelper") :: ModuleScript)
                local id, vol = SH.Resolve(SH.Custom.ChestOpen)
                snd.SoundId, snd.Volume = "rbxassetid://" .. tostring(id), vol
            end)
            snd.PlaybackSpeed = 1.08 - tier * 0.07 -- (bigger chests sound heavier)
            snd.RollOffMode = Enum.RollOffMode.InverseTapered; snd.RollOffMinDistance = 8; snd.RollOffMaxDistance = 70
            snd.Parent = body
            snd:Play()
            Debris:AddItem(snd, 4)
        end
        -- a puff of light out of the chest
        sparks.Speed = NumberRange.new(6, 12)
        sparks:Emit(tier == 0 and 16 or (20 + tier * 10))
        sparks.Speed = NumberRange.new(0.6, 1.6)
        sparks.Rate = tier == 0 and 0 or 2 -- (the open box keeps breathing a little light)
        -- the rune circle flares, then settles brighter than before (the opened chest keeps glowing)
        ringRune.ImageTransparency, ringGlow.ImageTransparency = 0, 0.1
        if IS_CLIENT then
            TweenService:Create(ringRune, TweenInfo.new(1.4), { ImageTransparency = 0.2 }):Play()
            TweenService:Create(ringGlow, TweenInfo.new(1.4), { ImageTransparency = 0.35 }):Play()
        end
    end
    return model, Open
end

-- Supply cache on top of each vantage platform.
function DungeonGenerator.CreateSupplyChest(pos: Vector3, chestId: number, dungeon: Instance, _palette: any)
    local model, open = BuildChest(dungeon, CFrame.new(pos) * CFrame.Angles(0, math.rad(90 * (chestId % 4)), 0), "Supply", nil)
    model.Name = "ArenaSupplyChest_" .. chestId
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "PromptSupplyChest"
    prompt.ActionText = "Open"
    prompt.ObjectText = "Supply Cache"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 11
    prompt.Parent = model.PrimaryPart
    prompt.Triggered:Connect(function(player)
        if IS_CLIENT then prompt.Enabled = false end
        open()
        DungeonGenerator.ChestOpened(player, "Supply", chestId, model)
    end)
end

-- ==================== [FLOOR-CLEAR: VICTORY CHEST + NEXT-FLOOR PORTAL] ====================
-- The old walk-in portal sat right next to the vault and teleported you the moment you brushed it.
-- Now the portal is a separate structure well away from the chest, and you enter it deliberately by
-- looking at it and pressing [E] (a short hold, so a stray tap mid-loot can't send you onward).
-- extract = true: the EXTRACTION portal (gold, leaves the run and keeps your run loot)
-- extract = "Hub": the one portal after a Boss Trial (gold, back to the hub keeping the drops)
-- path = { Index, Id, Mods } (PATH CHOICE, FloorMods.RollPaths): this portal leads to that version of the next floor;
-- it takes the path's colour and lists its modifiers + rewards under its name
local function BuildPortal(parent: Instance, floorPos: Vector3, theme: BiomeTheme, nextFloor: number, extract: (boolean | string)?, path: any?)
    -- BACK PORTAL: extract "Back" (entry room -> the floor behind you) / "Return" (that floor -> the one you came from)
    local revisit = (extract == "Back" or extract == "Return") and extract or nil
    if revisit then extract = nil end
    local hub = extract == "Hub"
    local model = Instance.new("Model")
    model.Name = hub and "HubPortal" or extract and "ExtractPortal" or (revisit and (revisit .. "Portal")) or "NextFloorPortal"
    if extract then theme = table.clone(theme); theme.Accent = C3(255, 200, 60) end
    if revisit then theme = table.clone(theme); theme.Accent = C3(110, 190, 255) end
    FloorModsRef = FloorModsRef or require(script.Parent:WaitForChild("FloorMods"))
    local pathDef = path and FloorModsRef.PATHS[path.Id]
    if pathDef then theme = table.clone(theme); theme.Accent = pathDef.Color; model.Name = "PathPortal" .. tostring(path.Index) end
    local acc = theme.Accent
    -- PORTALS v3 (owner 2026-10-11: "Portals and chests are still very underwhelming ... heavily improved cosmetic wise"):
    -- reference = an ARPG waystone portal. A carved archway (stepped plinth, two rune-cut pillars with glowing rune strips,
    -- capitals, a ring of voussoirs and a jewelled keystone; gilded on the gold Extract / Hub portals) framing a deep
    -- VORTEX: a dark backing, a bright rim, a deep inner field, a near-black eye, and two hubs of light arms (Beams)
    -- spiralling the opposite ways, motes drawn into the eye, embers rising off a light pool on the floor, a low hum.
    -- ~30 parts, 1 light, 2 emitters, 1 sound; animation rides the shared FxAnim loop (client only).
    local gold = (extract ~= nil and extract ~= false) or hub
    local stone = theme.WallTrim.Color:Lerp(C3(92, 92, 102), 0.45)
    -- (UPDATE 4: Marble, not Slate -- the Slate scan read as rubble on the small blocks)
    local frameSurf = { Color = stone, Material = Enum.Material.Marble }
    local frameDark = { Color = stone:Lerp(C3(18, 18, 22), 0.35), Material = Enum.Material.Marble }
    local trimSurf = { Color = gold and C3(222, 178, 70) or acc:Lerp(C3(40, 40, 46), 0.45), Material = Enum.Material.Metal }
    local R = 4.3 -- the vortex radius
    local CY = 6.0 -- its centre height over the floor
    local centerCF = CFrame.new(floorPos + Vector3.new(0, CY, 0)) -- faces -Z (back toward the chest / room)
    local PX = R + 1.0 -- pillar centre x
    local function Deco(size: Vector3, cf: CFrame, surf: any): BasePart
        local p = Block(model, size, cf, surf)
        p.CanCollide = false
        p.CanQuery = false
        return p
    end
    -- stepped plinth + a threshold step in front
    Block(model, Vector3.new(2 * PX + 3.4, 0.6, 5.2), CFrame.new(floorPos + Vector3.new(0, 0.3, 0)), frameDark)
    Block(model, Vector3.new(2 * PX + 2.2, 0.6, 3.8), CFrame.new(floorPos + Vector3.new(0, 0.9, 0)), frameSurf)
    Block(model, Vector3.new(2 * R, 0.32, 1.2), CFrame.new(floorPos + Vector3.new(0, 0.16, -3.1)), frameSurf)
    -- (UPDATE 4) THE RING: a full carved stone ring hugging the vortex, set into the plinth (segments under its top are
    -- skipped), alternating tones; four accent CHEVRONS on its face light in turn; a gilded keystone + jewel on top; two
    -- feet on the plinth; the waystone crystals hover at its sides. (Was: two pillars + a half arch of big voussoirs.)
    local AR = R + 0.55 -- ring centre line
    local N = 16
    for i = 0, N - 1 do
        local a = (i + 0.5) * 2 * math.pi / N
        local y = CY + math.sin(a) * AR
        if y > 1.5 and math.abs(a - math.pi / 2) > 0.2 then
            local chord = 2 * AR * math.sin(math.pi / N) + 0.1
            Block(model, Vector3.new(1.05, chord, 1.5), centerCF * CFrame.new(math.cos(a) * AR, math.sin(a) * AR, 0.05) * CFrame.Angles(0, 0, a),
                (i % 2 == 0) and frameSurf or frameDark)
        end
    end
    for k, deg in ipairs({ 30, 150, 210, 330 }) do
        local a = math.rad(deg)
        local ch = Deco(Vector3.new(0.5, 0.75, 0.12), centerCF * CFrame.new(math.cos(a) * AR, math.sin(a) * AR, -0.76) * CFrame.Angles(0, 0, a),
            { Color = acc, Material = Enum.Material.Neon, Transparency = 0.1 })
        ch.Name = "PortalChevron"
        ch.CastShadow = false
        FxAnim.Add("Pulse", ch, { T0 = 0.05, T1 = 0.75, Speed = 2.0, Phase = k * 1.57 })
    end
    Block(model, Vector3.new(1.5, 1.7, 1.9), centerCF * CFrame.new(0, AR + 0.1, 0.05), trimSurf)
    local jewel = Deco(Vector3.new(0.7, 0.7, 0.7), centerCF * CFrame.new(0, AR + 0.15, -1.0) * CFrame.Angles(0, 0, math.rad(45)),
        { Color = acc, Material = Enum.Material.Neon, Transparency = 0.05 })
    jewel.CastShadow = false
    FxAnim.Add("Pulse", jewel, { T0 = 0, T1 = 0.35, Speed = 2.4 })
    for _, sx in ipairs({ -1, 1 }) do
        Block(model, Vector3.new(2.3, 1.1, 2.0), CFrame.new(floorPos + Vector3.new(sx * 2.9, 1.75, 0.05)), frameDark)
        Block(model, Vector3.new(1.0, 0.2, 2.1), CFrame.new(floorPos + Vector3.new(sx * 2.9, 2.38, 0.05)), trimSurf)
        local crystal = Deco(Vector3.new(0.6, 0.6, 0.6), CFrame.new(floorPos + Vector3.new(sx * (AR + 1.45), CY + 0.4, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(35)),
            { Color = acc, Material = Enum.Material.Neon, Transparency = 0.15 })
        crystal.CastShadow = false
        FxAnim.Add("Bob", crystal, { Amp = 0.22, Speed = 1.3, Turn = 0.9 })
    end

    -- THE VORTEX v4 (UPDATE 4, owner: portals "should be redone to look absolutely stunning" -- the v3 Neon discs read as a
    -- flat target): a dark backing, then SELF-LIT image layers on one invisible face (FxFace): a tunnel of rings closing on a
    -- black eye, fibrous streaks + bright arms spiralling opposite ways, a rune band turning slowly, a hot event-horizon rim.
    -- The membrane (prompt, label, light, hum) is invisible now. Emitters are FxAnim.Low (off on the Low setting).
    local function Disc(r: number, dz: number, color: Color3, mat: Enum.Material, t: number): Part
        local p = Block(model, Vector3.new(0.12, 2 * r, 2 * r), centerCF * CFrame.new(0, 0, dz) * CFrame.Angles(0, math.rad(90), 0),
            { Color = color, Material = mat, Transparency = t }) :: Part
        p.Shape = Enum.PartType.Cylinder
        p.CanCollide = false
        p.CastShadow = false
        return p
    end
    local backing = Disc(R + 0.15, 0.32, acc:Lerp(C3(4, 4, 10), 0.9), Enum.Material.SmoothPlastic, 0)
    backing.CanQuery = false
    local membrane = Disc(R, 0.16, acc, Enum.Material.SmoothPlastic, 1)
    membrane.Name = "PortalMembrane"
    local FX = DungeonGenerator.FX_IMG
    local white = Color3.new(1, 1, 1)
    local face, Layer = FxAnim.Face(model, Vector3.new(2 * R, 2 * R, 0.05), centerCF * CFrame.new(0, 0, 0.06), Enum.NormalId.Front, 48, 1.5)
    face.Name = "PortalFace"
    Layer(FX.Depth, 1, acc, 0, 1)
    FxAnim.Add("GuiSpin", face, { Label = Layer(FX.Swirl2, 0.98, acc:Lerp(white, 0.2), 0.1, 2), Rate = -38 })
    FxAnim.Add("GuiSpin", face, { Label = Layer(FX.Swirl, 0.96, acc:Lerp(white, 0.3), 0.2, 3), Rate = 70 })
    FxAnim.Add("GuiSpin", face, { Label = Layer(FX.Rune, 1, acc:Lerp(white, 0.45), 0.05, 4), Rate = -9 })
    FxAnim.Add("GuiSpin", face, { Label = Layer(FX.Rim, 1.06, acc:Lerp(white, 0.55), 0, 5), Rate = 14, T0 = 0, T1 = 0.3, Speed = 2.2 })
    -- motes drawn into the eye
    local swirlAt = Instance.new("Attachment")
    swirlAt.CFrame = CFrame.Angles(0, 0, math.rad(-90)) -- (the disc emitter's axis along the portal's facing)
    swirlAt.Parent = membrane
    local swirl = Instance.new("ParticleEmitter")
    swirl.Name = "PortalSwirl"
    swirl.Shape = Enum.ParticleEmitterShape.Disc
    swirl.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
    swirl.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
    swirl.Color = ColorSequence.new(acc:Lerp(white, 0.5), acc)
    swirl.LightEmission = 1
    swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
    swirl.Transparency = NumberSequence.new(0.15, 0.9)
    swirl.Lifetime = NumberRange.new(0.8, 1.2)
    swirl.Rate = 16
    swirl.Speed = NumberRange.new(2.5, 4)
    swirl.RotSpeed = NumberRange.new(-180, 180)
    swirl.Parent = swirlAt
    FxAnim.Low(swirl)
    -- the light pool on the ground in front (a self-lit soft glow on the visible ground) + embers rising off it
    local gp = floorPos + Vector3.new(0, 0, -4.2)
    local pool, PoolLayer = FxAnim.Face(model, Vector3.new(11, 0.05, 11), CFrame.new(gp.X, FxAnim.Ground(gp) + 0.06, gp.Z), Enum.NormalId.Top, 16, 1.2)
    pool.Name = "PortalPool"
    PoolLayer(FX.Glow, 1, acc, 0.3, 1)
    local emberAt = Instance.new("Attachment")
    emberAt.Parent = pool
    local embers = Instance.new("ParticleEmitter")
    embers.Name = "PortalEmbers"
    embers.Shape = Enum.ParticleEmitterShape.Box
    embers.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
    embers.EmissionDirection = Enum.NormalId.Top
    embers.Color = ColorSequence.new(acc:Lerp(white, 0.3), acc)
    embers.LightEmission = 1
    embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
    embers.Transparency = NumberSequence.new(0.2, 1)
    embers.Lifetime = NumberRange.new(1.6, 2.6)
    embers.Rate = 5
    embers.Speed = NumberRange.new(1.2, 2.2)
    embers.SpreadAngle = Vector2.new(15, 15)
    embers.Parent = emberAt
    FxAnim.Low(embers)
    local light = Instance.new("PointLight")
    light.Color = acc
    light.Brightness = 1
    light.Range = 20
    light.Shadows = false
    light.Parent = membrane
    local hum = Instance.new("Sound")
    hum.Name = "PortalHum"
    hum.SoundId = "rbxassetid://72034839624325" -- (the Riftgate hideout portal's hum)
    hum.Volume = 0.16
    hum.Looped = true
    hum.RollOffMode = Enum.RollOffMode.InverseTapered
    hum.RollOffMinDistance = 6
    hum.RollOffMaxDistance = 42
    hum.Parent = membrane
    if IS_CLIENT then hum:Play() else hum.Playing = true end

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 200, 0, 30)
    bb.StudsOffset = Vector3.new(0, AR + 2.3, 0)
    bb.MaxDistance = 120
    bb.Adornee = membrane
    bb.Parent = model
    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, 0, 1, 0)
    txt.BackgroundTransparency = 1
    txt.Font = Enum.Font.GothamBold
    txt.TextSize = 17
    txt.TextColor3 = acc:Lerp(Color3.new(1, 1, 1), 0.4)
    txt.TextStrokeTransparency = 0.4
    txt.Text = hub and "RETURN TO HUB" or extract and "EXTRACT · keep your loot" or (revisit == "Back" and ("◀ BACK TO FLOOR " .. nextFloor))
        or (revisit == "Return" and ("RETURN TO FLOOR " .. nextFloor .. " ▶")) or (pathDef and (pathDef.Name .. "  →  FLOOR " .. nextFloor)) or ("PORTAL → FLOOR " .. nextFloor)
    txt.Parent = bb
    if pathDef then
        -- what this path holds: each modifier in its colour, the reward bonus last
        -- (one billboard, name on top + this text under it: two billboards drifted into each other at range)
        bb.Size = UDim2.new(0, 280, 0, 84)
        txt.Size = UDim2.new(1, 0, 0, 26)
        local lines = {}
        local mods = FloorModsRef.Parse(path.Mods)
        for _, id in ipairs(mods) do
            local d = FloorModsRef.Defs[id]
            if d then
                local c = d.Color or Color3.new(1, 1, 1)
                table.insert(lines, string.format('<font color="#%02X%02X%02X">%s</font>', math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), d.Name))
            end
        end
        local bonus = FloorModsRef.RewardBonus(mods)
        local it = Instance.new("TextLabel")
        it.Name = "PathInfo"
        it.Position = UDim2.fromOffset(0, 26)
        it.Size = UDim2.new(1, 0, 1, -26)
        it.BackgroundTransparency = 1
        it.Font = Enum.Font.GothamBold
        it.TextSize = 14
        it.RichText = true
        it.TextWrapped = true
        it.TextYAlignment = Enum.TextYAlignment.Top
        it.TextColor3 = Color3.new(1, 1, 1)
        it.TextStrokeTransparency = 0.35
        it.Text = table.concat(lines, "  ·  ") .. (bonus > 0 and string.format('\n<font color="#FFE08A">+%d%% XP, gold and loot luck</font>', math.round(bonus * 100)) or "")
        it.Parent = bb
        bb.StudsOffset = Vector3.new(0, AR + 3.3, 0)
    end

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "PromptPortal"
    prompt.ActionText = hub and "Return to Hub" or extract and "Extract" or (revisit == "Back" and "Go back for your loot")
        or (revisit == "Return" and "Return") or (pathDef and ("Take the " .. string.lower(pathDef.Name) .. " path")) or "Enter Portal"
    prompt.ObjectText = hub and "Trial complete" or extract and "Leave the run with your loot" or ("Floor " .. nextFloor)
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0.35
    prompt.RequiresLineOfSight = true
    prompt.MaxActivationDistance = 13
    prompt.Parent = membrane
    local used: { [number]: boolean } = {}
    prompt.Triggered:Connect(function(player)
        if used[player.UserId] then return end
        if revisit then -- (solo floors only: built on this client; the server decides -- a refusal lets you try again)
            if IS_CLIENT and DungeonGenerator.OnRevisit then
                used[player.UserId] = true
                task.spawn(function()
                    DungeonGenerator.OnRevisit(revisit)
                    used[player.UserId] = nil
                end)
            end
            return
        end
        -- (QOL L1 2026-10-28: drops still on the ground -> a warning first, the next press leaves. Client = GroundLoot (solo
        -- floors), server = CombatServer.LeaveLootGate (party floors). Nothing is collected for you.)
        if not hub and DungeonGenerator.LeaveGate and DungeonGenerator.LeaveGate(player, extract and "extract" or "portal") == false then return end
        used[player.UserId] = true
        if extract then
            if IS_CLIENT then
                Remotes.GetEvent("ExtractRun"):FireServer()
            elseif DungeonGenerator.ServerExtractHandler then
                DungeonGenerator.ServerExtractHandler(player)
            end
            return
        end
        if IS_CLIENT then
            if DungeonGenerator.OnPortal then DungeonGenerator.OnPortal(path and path.Index or nil) end
        elseif DungeonGenerator.ServerPortalHandler then
            used[player.UserId] = nil -- the party handler decides (only this player goes through: PartyRuns)
            DungeonGenerator.ServerPortalHandler(player, model)
        else
            Remotes.GetEvent("PortalNextFloor"):FireClient(player)
        end
    end)
    model.Parent = parent
    return model
end

-- BACK PORTAL: the way back to the floor behind you, against the entry room's back wall (solo floors; the client
-- removes it once the way back closes -- you stepped out or something died)
-- (0.86 BIOME MOODS) the floor's theme under its mood (stamped on the folder by BuildThemedDungeon)
function DungeonGenerator.MoodTheme(dungeon: Instance?, config: any): any
    local base = BiomeThemes[config.Biome] or BiomeThemes.Fire
    local BM = require(script.Parent:WaitForChild("BiomeMood"))
    return BM.Theme(base, BM.FromFolder(dungeon))
end

function DungeonGenerator.BuildBackPortal(dungeon: Instance, config: DungeonConfig, prevFloor: number): Model
    local layout = DungeonGenerator.GetChamberLayout(ItemData.IsBossConfig(config))
    local theme = DungeonGenerator.MoodTheme(dungeon, config)
    local m = BuildPortal(dungeon, Vector3.new(0, FLOOR_TOP, layout.EntryZ - layout.EntrySize / 2 + 3.5), theme, prevFloor, "Back")
    return m
end

-- (0.61) the cleared floor's BACK portal: off to the right of the walk from the chest to the exit portals (z + 16 row, kept
-- clear of props), so missed loot on the floor behind you is a short walk away
function DungeonGenerator.BuildClearedBackPortal(dungeon: Instance, config: DungeonConfig, prevFloor: number): Model
    local layout = DungeonGenerator.GetChamberLayout(ItemData.IsBossConfig(config))
    local theme = DungeonGenerator.MoodTheme(dungeon, config)
    return BuildPortal(dungeon, Vector3.new(-30, FLOOR_TOP, layout.CombatZ + 16), theme, prevFloor, "Back")
end

function DungeonGenerator.SpawnVictoryVault(dungeon: Instance, config: DungeonConfig): Model?
    local vaultDiffMode = ItemData.RunMode(config.Difficulty, (config :: any).Endless)
    local isSuperBoss = (vaultDiffMode ~= nil and vaultDiffMode.SuperBossWave ~= nil and config.FloorNumber == vaultDiffMode.SuperBossWave)
    local vdm = ItemData.RunMode(config.Difficulty, (config :: any).Endless)
    local isMajorBoss = (vdm and vdm.BossWaves and table.find(vdm.BossWaves, config.FloorNumber) ~= nil) or (config.FloorNumber > 100 and config.FloorNumber % 10 == 0)
    local isMiniBoss = ItemData.IsBossConfig(config)
    local isAnyBoss = isSuperBoss or isMajorBoss or isMiniBoss
    local layout = DungeonGenerator.GetChamberLayout(isMiniBoss)
    local theme = DungeonGenerator.MoodTheme(dungeon, config)

    -- Chest where the fight happened (Combat chamber center, or the Boss chamber on boss floors);
    -- the portal stands well away from it near that chamber's far wall.
    local chestZ = layout.CombatZ + ((config :: any).LinkedExitZ or 0) -- (LINKED ROOMS pilot: in the exit room, further down the line)
    -- (0.60, owner: "portals need to be far closer because you cant run there as fast"): 30 past the chest, not 62 --
    -- clear of every traversal layout (pillar grid z 20 / x +-35, bunkers x +-33..55, gauntlet panels x +-76)
    local portalZ = chestZ + 30
    local SPACE = 18 -- (path portals side by side; 0.61e: back to 18 -- at 14 the v3 portals' labels ran into each other)
    local nextF = (config :: any).LinkedNext or (config.FloorNumber + 1) -- (LINKED ROOMS v2: a linked floor counts as 2)
    local style = isSuperBoss and "SuperBoss" or (isMajorBoss and "Titan" or (isMiniBoss and "MiniBoss" or "Victory"))
    local label = isSuperBoss and "SUPERBOSS RELIC CHEST" or (isMajorBoss and "TITAN CHEST" or (isMiniBoss and "BOSS CHEST" or "VICTORY CHEST"))
    do -- (MAPS V2 L3) a map floor's chest is the MAP CACHE (the server pays it: EndgameServer.MapFloorCache)
        local lp = IS_CLIENT and game:GetService("Players").LocalPlayer
        local rf = lp and lp:FindFirstChild("PlayerGui") and lp.PlayerGui:FindFirstChild("AimRngRun")
        if not isAnyBoss and rf and (tonumber(rf:GetAttribute("Rift")) or 0) > 0 then label = "MAP CACHE" end
    end

    local chestModel, open = BuildChest(dungeon, CFrame.new(0, FLOOR_TOP, chestZ), style, label)
    chestModel.Name = "VictoryVaultChest"
    -- faint shimmering column so the chest is easy to spot across a big room (not a neon beacon)
    local beacon = Instance.new("Part")
    beacon.Name = "ChestBeacon"
    beacon.Anchored = true
    beacon.CanCollide = false
    beacon.CanQuery = false
    beacon.Transparency = 1
    beacon.Size = Vector3.new(0.2, 0.2, 0.2)
    beacon.CFrame = CFrame.new(0, FLOOR_TOP + 2, chestZ)
    beacon.Parent = chestModel
    do -- a soft beam of light rising out of the chest, fading upward (easy to spot across the room)
        local bc = ChestStyles[style].Glow or C3(255, 220, 150)
        local a0 = Instance.new("Attachment"); a0.Parent = beacon
        local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, 34, 0); a1.Parent = beacon
        for i, w in ipairs({ 1.2, 3.4 }) do
            local bm = Instance.new("Beam")
            bm.Attachment0, bm.Attachment1 = a0, a1
            bm.Color = ColorSequence.new(bc:Lerp(Color3.new(1, 1, 1), 0.3), bc)
            bm.Width0, bm.Width1 = w, w * 0.4
            bm.LightEmission = 1; bm.LightInfluence = 0; bm.FaceCamera = true; bm.Segments = 2
            bm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, i == 1 and 0.35 or 0.8), NumberSequenceKeypoint.new(1, 1) })
            bm.Parent = beacon
        end
    end

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "PromptVault"
    prompt.ActionText = "Open"
    prompt.ObjectText = label
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 12
    prompt.Parent = chestModel.PrimaryPart
    prompt.Triggered:Connect(function(player)
        if IS_CLIENT then
            prompt.Enabled = false
            beacon:Destroy()
        end
        open()
        DungeonGenerator.ChestOpened(player, "Vault", 0, chestModel)
    end)

    local modeDef = ItemData.RunMode(config.Difficulty, (config :: any).Endless)
    local isFinalFloor = modeDef and modeDef.MaxWaves and config.FloorNumber >= modeDef.MaxWaves and not modeDef.Endless
    if (config :: any).ChestOpened and not (config :: any).ReturnTo then
        -- (0.61) back on a floor you had cleared: its chest stays open
        open()
        prompt.Enabled = false
        beacon:Destroy()
    end
    if (config :: any).ReturnTo then
        -- BACK PORTAL revisit: the chest was opened before you left; one portal takes you back where you came from
        open()
        prompt.Enabled = false
        beacon:Destroy()
        BuildPortal(chestModel, Vector3.new(0, FLOOR_TOP, portalZ), theme, (config :: any).ReturnTo, "Return")
    elseif (config :: any).TrialDone or isFinalFloor then
        -- (bug sweep 2026-10-03: a final-floor win had no portal at all -- only a toast about a key) -> the same gold
        -- RETURN TO HUB portal as a Boss Trial
        -- (owner 2026-10-03: "two portals at the end of the challenge boss fight; those should be their own entity, and
        -- just have one that brings you back to hub") -- a Boss Trial ends with one gold portal home, no floors after it
        BuildPortal(chestModel, Vector3.new(0, FLOOR_TOP, portalZ), theme, nextF, "Hub")
    elseif not isFinalFloor then
        local extract = ItemData.IsExtractFloor(config.Difficulty, config.FloorNumber)
        local paths = (config :: any).Paths
        if type(paths) == "table" and #paths > 0 then
            -- PATH CHOICE: one portal per path, calm on the left (portals face -Z, so +X is the player's left) and the
            -- gold extract portal on the right, 18 studs apart
            local n = #paths + (extract and 1 or 0)
            for i, p in ipairs(paths) do
                local x = (n - 1) * SPACE / 2 - (i - 1) * SPACE
                BuildPortal(chestModel, Vector3.new(x, FLOOR_TOP, portalZ), theme, nextF, nil, { Index = i, Id = p.Id, Mods = p.Mods })
            end
            if extract then BuildPortal(chestModel, Vector3.new(-(n - 1) * SPACE / 2, FLOOR_TOP, portalZ), theme, nextF, true) end
        else
            BuildPortal(chestModel, Vector3.new(extract and -SPACE / 2 or 0, FLOOR_TOP, portalZ), theme, nextF)
            if extract then BuildPortal(chestModel, Vector3.new(SPACE / 2, FLOOR_TOP, portalZ), theme, nextF, true) end
        end
    end
    return chestModel
end

-- ==================== [AMBIENCE: make the rooms feel alive] ====================
-- Moving light and particles per biome (built with the room; party rooms replicate them). Molten gets the full
-- treatment: glowing lava channels that light the floor, lavafalls down the walls with sparks + smoke, drifting embers,
-- hanging chains and cages. Other biomes get drifting particles (snow / motes / data sparks) and accent lights.
local AMBIENCE = {
    Fire = { Mote = C3(255, 140, 50), Mote2 = C3(255, 70, 30), MoteRise = true, Glow = C3(255, 110, 40) },
    Ice = { Mote = C3(235, 245, 255), Mote2 = C3(190, 220, 255), MoteRise = false, Glow = C3(150, 200, 255) },
    Void = { Mote = C3(200, 140, 255), Mote2 = C3(120, 70, 220), MoteRise = true, Glow = C3(170, 90, 255) },
    Cyber = { Mote = C3(90, 255, 200), Mote2 = C3(40, 200, 255), MoteRise = true, Glow = C3(60, 255, 190) },
    Storm = { Mote = C3(200, 225, 255), Mote2 = C3(150, 200, 255), MoteRise = false, Glow = C3(150, 210, 255) },
}

local function Emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
    local e = Instance.new("ParticleEmitter")
    for k, v in pairs(props) do (e :: any)[k] = v end
    e.Parent = parent
    return e
end

local function Invisible(parent: Instance, size: Vector3, cf: CFrame): Part
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.Transparency = 1; p.Size = size; p.CFrame = cf; p.Name = "Ambience"
    p.Parent = parent
    return p
end

local function GlowLight(parent: BasePart, color: Color3, range: number, brightness: number)
    local l = Instance.new("PointLight")
    l.Color = color; l.Range = range; l.Brightness = brightness; l.Shadows = false
    l.Parent = parent
end


-- ==================== [BIOME SCENERY (2026-10-03 visual pass)] ====================
-- Owner: "Some of the biomes look lower quality than others... make them all higher quality". Stormspire set the bar
-- (open roof, a sky with something happening in it, signature details on the floor); every biome now has the same:
--   Molten  open roof under a deck of smoke lit orange from below, falling ash, magma veins across the floor, geysers
--   Cryo    open roof under a shimmering aurora, icicles along the roof ribs, snowfall, glassy ice sheets, crystal clusters
--   Void    open roof onto a starfield with a black hole and a turning accretion ring, drifting rock islands, rift cracks
--   Cyber   (keeps its roof: a data hall) a neon grid on floor and ceiling, data pillars streaming upward, a scan bar
-- All decoration: no collision, no shot blocking. Animations run only where the room is built on a client.
local function FlatPart(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, transparency: number?): BasePart
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.Size = size; p.CFrame = cf; p.Color = color; p.Material = material or Enum.Material.Neon; p.Transparency = transparency or 0
    p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end
-- a jagged glowing crack along the floor (magma veins / rift cracks)
local function FloorCrack(parent: Instance, rng: Random, start: Vector3, color: Color3, segs: number)
    local p = start
    local heading = rng:NextNumber(0, math.pi * 2)
    for _ = 1, segs do
        heading += rng:NextNumber(-0.7, 0.7)
        local len = rng:NextNumber(3, 6)
        local q = p + Vector3.new(math.cos(heading) * len, 0, math.sin(heading) * len)
        FlatPart(parent, Vector3.new(rng:NextNumber(0.5, 0.8), 0.06, (q - p).Magnitude + 0.3), CFrame.lookAt((p + q) / 2, q), color)
        if rng:NextNumber() < 0.25 then -- a short branch
            local a = heading + (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(0.6, 1.2)
            local b = q + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(1.5, 3)
            FlatPart(parent, Vector3.new(0.35, 0.06, (b - q).Magnitude), CFrame.lookAt((q + b) / 2, b), color)
        end
        p = q
    end
end
-- a SOFT CLOUD BANK (0.58, owner: "the clouds look incredibly bad in the sky" -- they were hard-edged flat sphere
-- meshes with a neon disc under them, flying saucers). Now: one invisible slab d wide that holds a few huge, slow,
-- soft smoke sprites (pre-filled on the client), fading in and out -- `under` tints them toward a glow from below.
-- About 6 particles a bank: far cheaper than the part decks.
local function CloudPuff(parent: Instance, pos: Vector3, d: number, color: Color3, transparency: number, under: Color3?)
    local slab = Invisible(parent, Vector3.new(d, math.max(2, d * 0.1), d), CFrame.new(pos))
    slab.Name = "SkyCloud"
    local n = 6
    local life = 36
    local sz = math.min(100, d * 0.55)
    local e = Emitter(slab, { Texture = "rbxasset://textures/particles/smoke_main.dds",
        Color = ColorSequence.new(color, under and color:Lerp(under, 0.45) or color),
        Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, sz * 0.75), NumberSequenceKeypoint.new(1, sz) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, transparency),
            NumberSequenceKeypoint.new(0.8, transparency), NumberSequenceKeypoint.new(1, 1) }),
        Lifetime = NumberRange.new(life * 0.8, life), Rate = n / life, Speed = NumberRange.new(0.3, 0.9), SpreadAngle = Vector2.new(180, 180),
        Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-2, 2), LightEmission = under and 0.12 or 0, LightInfluence = 0.5,
        Drag = 0.2 })
    if IS_CLIENT then -- (the sky starts full: once the floor is in the world)
        task.spawn(function()
            for _ = 1, 60 do
                if slab:IsDescendantOf(workspace) then e:Emit(n) return end
                task.wait(0.1)
            end
        end)
    end
    return slab
end

local function BuildBiomeScenery(fx: Instance, theme: BiomeTheme, biome: string, rng: Random, zC: number, arena: number, height: number)
    if DungeonGenerator.NB.Scenery[biome] then DungeonGenerator.NB.Scenery[biome](fx, theme, rng, zC, arena, height, Invisible, Emitter) return end
    local half = arena / 2
    local F = FLOOR_TOP
    local live = IS_CLIENT -- (animations: only on the machine that renders the room)
    if biome == "Fire" then
        -- a deck of smoke over the open roof, lit orange from below by the lava
        for _ = 1, 8 do
            local pos = Vector3.new(rng:NextNumber(-half * 1.2, half * 1.2), height + rng:NextNumber(28, 40), zC + rng:NextNumber(-half * 1.2, half * 1.2))
            CloudPuff(fx, pos, rng:NextNumber(110, 160), C3(52, 34, 30), 0.35, C3(200, 70, 24)) -- (lit orange from below by the lava)
        end
        -- ash drifting down through the roof
        local ash = Invisible(fx, Vector3.new(arena - 10, 1, arena - 10), CFrame.new(0, height + 4, zC))
        Emitter(ash, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C3(120, 110, 104), C3(70, 64, 60)),
            LightEmission = 0, LightInfluence = 1, Rate = 18, Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(2, 4),
            EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(30, 30), RotSpeed = NumberRange.new(-60, 60),
            Size = NumberSequence.new(0.18), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.2), NumberSequenceKeypoint.new(1, 0.6) }) })
        -- magma veins cracking across the floor
        for _ = 1, 12 do
            FloorCrack(fx, rng, Vector3.new(rng:NextNumber(-half + 8, half - 8), F + 0.05, zC + rng:NextNumber(-half + 8, half - 8)), C3(255, 110, 30), rng:NextInteger(4, 7))
        end
        -- geysers along the walls: a crusted vent that erupts now and then (decoration -- no damage)
        for i = 1, 4 do
            local sx = (i % 2 == 0) and 1 or -1
            local pos = Vector3.new(sx * (half - 9), F, zC + (-0.6 + (i - 1) * 0.4) * half)
            local rim = FlatPart(fx, Vector3.new(0.8, 5, 5), CFrame.new(pos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), C3(40, 34, 32), Enum.Material.Basalt)
            ;(rim :: Part).Shape = Enum.PartType.Cylinder
            local core = FlatPart(fx, Vector3.new(0.9, 3, 3), CFrame.new(pos + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90)), C3(255, 140, 40))
            ;(core :: Part).Shape = Enum.PartType.Cylinder
            local src = Invisible(fx, Vector3.new(2, 1, 2), CFrame.new(pos + Vector3.new(0, 1.2, 0)))
            local plume = Emitter(src, { Texture = "rbxasset://textures/particles/fire_main.dds", Color = ColorSequence.new(C3(255, 230, 120), C3(255, 70, 20)),
                LightEmission = 0.9, Rate = 0, Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(26, 36), SpreadAngle = Vector2.new(8, 8),
                EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -12, 0), Size = NumberSequence.new(2.4, 0.6),
                Transparency = NumberSequence.new(0.1, 1) })
            local idle = Emitter(src, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(90, 64, 54)),
                LightInfluence = 0.5, Rate = 2, Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(3, 5), SpreadAngle = Vector2.new(10, 10),
                EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new(1.5, 4), Transparency = NumberSequence.new(0.6, 1) })
            local light = core -- (no PointLight -- PERFORMANCE: the vent's core flares white instead)
            if live then
                task.spawn(function()
                    local r = Random.new()
                    task.wait(r:NextNumber(1, 6))
                    while fx.Parent do
                        plume:Emit(30)
                        light.Color = C3(255, 235, 180)
                        task.wait(0.6)
                        light.Color = C3(255, 140, 40)
                        task.wait(r:NextNumber(5, 10))
                    end
                end)
            end
            local _ = idle
        end
    elseif biome == "Ice" then
        -- (owner 2026-10-05: "glacier ... needs a more ice themed skybox (remove the aurora too)": the aurora is gone --
        -- the Glacier sky is a clear polar day now, see tools/make_skies.py)
        -- icicles hanging from the roof ledges and ribs (three tapering blocks each) -- not on an open map shell
        local function Icicle(top: Vector3, len: number)
            local w = rng:NextNumber(0.9, 1.4)
            for k = 0, 2 do
                local seg = len * (0.45 - k * 0.1)
                local y = top.Y - len * ({ 0, 0.45, 0.8 })[k + 1] - seg / 2
                FlatPart(fx, Vector3.new(w * (1 - k * 0.3), seg, w * (1 - k * 0.3)), CFrame.new(top.X, y, top.Z), C3(205, 238, 255), Enum.Material.Ice, 0.12)
            end
        end
        for _, sx in ipairs(MapShell.Open and {} or { -1, 1 }) do
            for t = -half + 6, half - 6, 7 do
                if rng:NextNumber() < 0.8 then
                    Icicle(Vector3.new(sx * (half - 10.5), height - 2.5, zC + t + rng:NextNumber(-1.5, 1.5)), rng:NextNumber(3, 7))
                    Icicle(Vector3.new(t + rng:NextNumber(-1.5, 1.5), height - 2.5, zC + sx * (half - 10.5)), rng:NextNumber(3, 7))
                end
            end
        end
        -- snow falling through the open roof
        local snow = Invisible(fx, Vector3.new(arena - 10, 1, arena - 10), CFrame.new(0, height + 4, zC))
        Emitter(snow, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C3(255, 255, 255)),
            LightEmission = 0.3, LightInfluence = 0.6, Rate = 35, Lifetime = NumberRange.new(7, 10), Speed = NumberRange.new(3, 6),
            EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(1.5, 0, 0.5), RotSpeed = NumberRange.new(-90, 90),
            Size = NumberSequence.new(0.22), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, 0.05), NumberSequenceKeypoint.new(1, 0.3) }) })
        -- glassy ice sheets on the floor
        for _ = 1, 7 do
            local d = rng:NextNumber(10, 20)
            local sheet = FlatPart(fx, Vector3.new(0.12, d, d * rng:NextNumber(0.6, 1)), CFrame.new(rng:NextNumber(-half + 12, half - 12), F + 0.04, zC + rng:NextNumber(-half + 12, half - 12)) * CFrame.Angles(0, rng:NextNumber(0, 3), math.rad(90)),
                C3(170, 215, 240), Enum.Material.Ice, 0.1)
            ;(sheet :: Part).Shape = Enum.PartType.Cylinder
            sheet.Reflectance = 0.35
        end
        -- crystal clusters against the walls, glowing from inside (UPDATE 4 PROPS: the kit's faceted IceCrystals when the
        -- place has them -- the tilted glass blocks read as flat slabs; the rng draws stay the same either way)
        local EK = require(script.Parent:WaitForChild("EnvKit"))
        local kitIce = EK.Has("Ice", "IceCrystalsA") and EK.Has("Ice", "IceCrystalsB")
        for i = 1, 8 do
            local sx = (i % 2 == 0) and 1 or -1
            local base = Vector3.new(sx * (half - 6), F, zC + (-0.8 + (i - 1) * 0.23) * half)
            for k = 1, rng:NextInteger(3, 5) do
                local h = rng:NextNumber(4, 10)
                local w1, w2 = rng:NextNumber(1.2, 2.2), rng:NextNumber(1.2, 2.2)
                local ox, oz = rng:NextNumber(-2, 2), rng:NextNumber(-2, 2)
                local ax, ay, az = rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)
                if not kitIce then
                    FlatPart(fx, Vector3.new(w1, h, w2), CFrame.new(base + Vector3.new(ox, h * 0.4, oz)) * CFrame.Angles(ax, ay, az),
                        C3(150, 220, 255), Enum.Material.Glass, 0.25)
                end
            end
            if kitIce then
                EK.Place("Ice", (i % 2 == 0) and "IceCrystalsA" or "IceCrystalsB", CFrame.new(base) * CFrame.Angles(0, i * 1.9, 0),
                    { Scale = 0.9 + (i % 3) * 0.12, Parent = fx, Shadow = false })
            end
            local glow = FlatPart(fx, Vector3.new(1, 1, 1), CFrame.new(base + Vector3.new(0, 2.5, 0)), C3(130, 220, 255))
            glow.Shape = Enum.PartType.Ball
            if i % 2 == 0 then GlowLight(glow, C3(130, 210, 255), 26, 1.6) end -- (half: PERFORMANCE)
        end
    elseif biome == "Void" then
        -- the sky: a field of stars, a black hole with a turning accretion ring, all far above the open roof
        for _ = 1, 110 do
            local d = rng:NextNumber(0.3, 0.9)
            local star = FlatPart(fx, Vector3.new(d, d, d), CFrame.new(rng:NextNumber(-arena, arena), height + rng:NextNumber(40, 110), zC + rng:NextNumber(-arena, arena)),
                (rng:NextNumber() < 0.3) and C3(220, 180, 255) or C3(255, 255, 255))
            star.Shape = Enum.PartType.Ball
        end
        local hole = Vector3.new(-half * 0.15, height + 62, zC + half * 0.45) -- (ahead of you as you come in)
        local core = FlatPart(fx, Vector3.new(28, 28, 28), CFrame.new(hole), C3(0, 0, 0), Enum.Material.SmoothPlastic)
        core.Shape = Enum.PartType.Ball
        local tilt = CFrame.new(hole) * CFrame.Angles(math.rad(70), 0, math.rad(15))
        local rings = {}
        for k, r in ipairs({ { 64, C3(255, 120, 220), 0.25 }, { 50, C3(255, 200, 140), 0.15 }, { 36, C3(170, 90, 255), 0.35 } }) do
            local ring = FlatPart(fx, Vector3.new(0.4 + k * 0.1, r[1], r[1]), tilt * CFrame.Angles(0, 0, math.rad(90)), r[2], Enum.Material.Neon, r[3])
            ring.Shape = Enum.PartType.Cylinder
            table.insert(rings, ring)
        end
        FlatPart(fx, Vector3.new(30, 30, 30), CFrame.new(hole), C3(0, 0, 0), Enum.Material.SmoothPlastic, 0).Shape = Enum.PartType.Ball -- (the event horizon in front of the rings)
        -- drifting rock islands above the arena edges, a few with a glowing crystal
        local islands = {}
        for i = 1, 7 do
            local a = (i / 7) * math.pi * 2
            local pos = Vector3.new(math.cos(a) * half * 0.75, height + rng:NextNumber(6, 22), zC + math.sin(a) * half * 0.75)
            local m = {}
            for k = 1, 3 do
                local s = Vector3.new(rng:NextNumber(5, 10), rng:NextNumber(3, 6), rng:NextNumber(5, 10)) * (1 - (k - 1) * 0.3)
                table.insert(m, { P = FlatPart(fx, s, CFrame.new(pos - Vector3.new(0, (k - 1) * 2.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2)), C3(70, 58, 90), Enum.Material.Basalt), Off = Vector3.new(0, -(k - 1) * 2.5, 0) })
            end
            if i % 2 == 0 then
                table.insert(m, { P = FlatPart(fx, Vector3.new(1.2, 4, 1.2), CFrame.new(pos + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, 0.3), C3(200, 110, 255)), Off = Vector3.new(0, 3.5, 0) })
            end
            table.insert(islands, { Base = pos, Parts = m, Ph = rng:NextNumber(0, 6) })
        end
        if live then
            task.spawn(function()
                local angle = 0
                while fx.Parent do
                    local t = os.clock()
                    angle += 0.012
                    for _, ring in ipairs(rings) do ring.CFrame = tilt * CFrame.Angles(0, angle, 0) * CFrame.Angles(0, 0, math.rad(90)) end
                    for _, isl in ipairs(islands) do
                        local dy = 1.6 * math.sin(t * 0.5 + isl.Ph)
                        for _, e in ipairs(isl.Parts) do
                            local cf = e.P.CFrame
                            e.P.CFrame = (cf - cf.Position) + isl.Base + e.Off + Vector3.new(0, dy, 0)
                        end
                    end
                    task.wait(0.05)
                end
            end)
        end
        -- rift cracks across the floor
        for _ = 1, 10 do
            FloorCrack(fx, rng, Vector3.new(rng:NextNumber(-half + 8, half - 8), F + 0.05, zC + rng:NextNumber(-half + 8, half - 8)), C3(110, 80, 255), rng:NextInteger(4, 7)) -- (violet-blue: the attack markers here are pink)
        end
    elseif biome == "Cyber" then
        -- a neon grid on the floor and the ceiling
        local GRID = C3(40, 255, 200)
        for t = -half + 12, half - 12, 12 do
            FlatPart(fx, Vector3.new(0.22, 0.06, arena - 8), CFrame.new(t, F + 0.04, zC), GRID, Enum.Material.Neon, 0.35)
            FlatPart(fx, Vector3.new(arena - 8, 0.06, 0.22), CFrame.new(0, F + 0.04, zC + t), GRID, Enum.Material.Neon, 0.35)
            if not MapShell.Open then
                FlatPart(fx, Vector3.new(0.3, 0.1, arena - 8), CFrame.new(t, height - 2.05, zC), GRID, Enum.Material.Neon, 0.3)
                FlatPart(fx, Vector3.new(arena - 8, 0.1, 0.3), CFrame.new(0, height - 2.05, zC + t), GRID, Enum.Material.Neon, 0.3)
            end
        end
        -- data pillars: glass columns with data streaming up inside
        for i = 1, 6 do
            local sx = (i % 2 == 0) and 1 or -1
            local pos = Vector3.new(sx * (half - 7), F, zC + (-0.7 + (i - 1) * 0.28) * half)
            local h = height - 4
            FlatPart(fx, Vector3.new(3, h, 3), CFrame.new(pos + Vector3.new(0, h / 2, 0)), C3(40, 200, 255), Enum.Material.Glass, 0.6)
            for _, y in ipairs({ 0.3, 0.9, h - 0.3 }) do
                FlatPart(fx, Vector3.new(3.6, 0.6, 3.6), CFrame.new(pos + Vector3.new(0, y, 0)), C3(36, 42, 50), Enum.Material.Metal)
            end
            local src = Invisible(fx, Vector3.new(2, 1, 2), CFrame.new(pos + Vector3.new(0, 1.5, 0)))
            Emitter(src, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C3(80, 255, 200), C3(60, 180, 255)),
                LightEmission = 1, LightInfluence = 0, Rate = 9, Lifetime = NumberRange.new(1.8, 2.6), Speed = NumberRange.new(7, 11),
                EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(4, 4), Size = NumberSequence.new(0.35, 0.1),
                Transparency = NumberSequence.new(0, 1), Shape = Enum.ParticleEmitterShape.Box })
            if i % 2 == 0 then GlowLight(src, C3(60, 230, 220), 26, 1.5) end -- (half: PERFORMANCE)
        end
        -- a scan bar sweeping across the ceiling, end to end
        local bar = FlatPart(fx, Vector3.new(arena - 8, 0.3, 1.2), CFrame.new(0, height - 2.3, zC - half + 6), C3(120, 255, 230), Enum.Material.Neon, 0.1)
        if MapShell.Open then bar.Transparency = 1; live = false end -- (no ceiling to sweep on an open rooftop)
        local barLight = Instance.new("SurfaceLight"); barLight.Face = Enum.NormalId.Bottom; barLight.Color = C3(120, 255, 230)
        barLight.Range = 30; barLight.Brightness = 1.4; barLight.Angle = 70; barLight.Parent = bar
        if live then
            task.spawn(function()
                while fx.Parent do
                    local t0 = os.clock()
                    while fx.Parent and os.clock() - t0 < 7 do
                        local u = (os.clock() - t0) / 7
                        bar.CFrame = CFrame.new(0, height - 2.3, zC - half + 6 + u * (arena - 12))
                        task.wait(0.05)
                    end
                    task.wait(3)
                end
            end)
        end
    end
end

local function BuildAmbience(dungeon: Instance, geo: Instance, theme: BiomeTheme, biome: string, rng: Random, zC: number, arena: number, height: number)
    local look = AMBIENCE[biome] or AMBIENCE.Fire
    local half = arena / 2
    local F = FLOOR_TOP
    local fx = Instance.new("Folder")
    fx.Name = "Ambience"
    fx.Parent = dungeon

    -- drifting motes through the whole room (embers rise, snow falls)
    for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
        local y = look.MoteRise and (F + 3) or (height - 4)
        local src = Invisible(fx, Vector3.new(half - 6, 1, half - 6), CFrame.new(q[1] * half / 2, y, zC + q[2] * half / 2))
        Emitter(src, {
            Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(look.Mote, look.Mote2),
            LightEmission = 1, LightInfluence = 0, Rate = 8, Lifetime = NumberRange.new(6, 11),
            Speed = NumberRange.new(look.MoteRise and 2 or 1, look.MoteRise and 5 or 3), SpreadAngle = Vector2.new(25, 25),
            EmissionDirection = look.MoteRise and Enum.NormalId.Top or Enum.NormalId.Bottom,
            Acceleration = Vector3.new(0, look.MoteRise and 0.4 or -0.6, 0), Drag = 0.4,
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(0.5, 0.26), NumberSequenceKeypoint.new(1, 0) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 1) }),
            RotSpeed = NumberRange.new(-40, 40),
        })
    end

    if biome == "Storm" then
        -- RAIN: fast streaks falling through the whole room
        for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
            local src = Invisible(fx, Vector3.new(half - 4, 1, half - 4), CFrame.new(q[1] * half / 2, height - 2, zC + q[2] * half / 2))
            Emitter(src, {
                Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C3(200, 220, 245)),
                LightEmission = 0.7, LightInfluence = 0.4, Rate = 28, Lifetime = NumberRange.new(0.9, 1.3), -- (60 -> 28: particle budget, open maps 2026-10-05)
                Speed = NumberRange.new(48, 60), SpreadAngle = Vector2.new(4, 4), EmissionDirection = Enum.NormalId.Bottom,
                Size = NumberSequence.new(0.16), Transparency = NumberSequence.new(0.15), Orientation = Enum.ParticleOrientation.VelocityParallel,
                Squash = NumberSequence.new(-2.5),
            })
        end
        -- LIGHTNING: the room flashes now and then -- four big lights just under the broken roof (a PointLight reaches 60
        -- studs at most, so one high above the room wouldn't reach the floor); on whoever's machine runs the room
        local flashes = {}
        for _, q in ipairs({ { -1, 0 }, { 1, 0 } }) do -- (two flash lights, not four: PERFORMANCE)
            local src = Invisible(fx, Vector3.new(1, 1, 1), CFrame.new(q[1] * half / 2, height - 8, zC + q[2] * half / 2))
            local l = Instance.new("PointLight"); l.Color = C3(205, 225, 255); l.Range = 60; l.Brightness = 0; l.Shadows = false; l.Parent = src
            table.insert(flashes, l)
        end
        -- the storm itself above the broken roof: a low deck of grey cloud, and forked bolts cracking across it
        for _ = 1, 7 do -- (soft cloud banks, see CloudPuff)
            local cloud = CloudPuff(fx, Vector3.new(rng:NextNumber(-half, half), height + rng:NextNumber(28, 40), zC + rng:NextNumber(-half, half)),
                rng:NextNumber(110, 150), C3(64, 70, 86), 0.3, C3(150, 180, 230))
            cloud.Name = "StormCloud"
        end
        local function Bolt(r: Random)
            -- a jagged chain of neon segments from the clouds toward the roofline
            local p = Vector3.new(r:NextNumber(-half * 0.8, half * 0.8), height + 30, zC + r:NextNumber(-half * 0.8, half * 0.8))
            local parts = {}
            for _ = 1, r:NextInteger(5, 8) do
                local q = p + Vector3.new(r:NextNumber(-7, 7), -r:NextNumber(3, 6), r:NextNumber(-7, 7))
                local seg = Instance.new("Part")
                seg.Anchored = true; seg.CanCollide = false; seg.CanQuery = false; seg.CanTouch = false; seg.CastShadow = false
                seg.Material = Enum.Material.Neon; seg.Color = C3(220, 235, 255)
                seg.Size = Vector3.new(0.5, 0.5, (q - p).Magnitude); seg.CFrame = CFrame.lookAt((p + q) / 2, q)
                seg.Parent = fx
                table.insert(parts, seg)
                p = q
            end
            return parts
        end
        task.spawn(function()
            local r = Random.new()
            while fx.Parent do
                task.wait(r:NextNumber(4, 9))
                if not fx.Parent then break end
                local bolt = Bolt(r)
                task.delay(0.35, function() for _, seg in ipairs(bolt) do seg:Destroy() end end)
                for _ = 1, r:NextInteger(1, 3) do
                    local b = r:NextNumber(3, 6)
                    for _, l in ipairs(flashes) do l.Brightness = b end
                    task.wait(r:NextNumber(0.04, 0.09))
                    for _, l in ipairs(flashes) do l.Brightness = 0 end
                    task.wait(r:NextNumber(0.05, 0.14))
                end
            end
        end)
    end
    BuildBiomeScenery(fx, theme, biome, rng, zC, arena, height)
    if biome ~= "Fire" then
        -- accent glow pools along the walls so the room isn't flat (closed rooms only: an open map has no walls)
        for i = 1, (MapShell.Open and 0 or 6) do
            local sx = (i % 2 == 0) and 1 or -1
            local z = zC + (-half * 0.75) + (i - 1) * (half * 0.3)
            local orb = Ball(fx, 1.6, Vector3.new(sx * (half - 3), F + 10, z), { Color = look.Glow, Material = Enum.Material.Neon })
            orb.CanCollide = false; orb.CanQuery = false
            if i % 2 == 1 then GlowLight(orb, look.Glow, 36, 1.5) end -- (half of them: PERFORMANCE)
        end
        return
    end

    -- ===== Molten =====
    local LAVA = C3(255, 108, 36)
    -- lava channels across the floor (decorative, flush with it; they light the room from below). UPDATE 4 LAVA: a crusted
    -- bed under a flowing molten river (LavaFX.Flow) instead of a Neon core strip; on solo open maps the ground is terrain
    -- ~1 stud over the floor (it buried the channels), so they're skipped there -- MapShell.LavaPools takes over.
    local Lava = DungeonGenerator.Lava()
    local onTerrain = MapShell.Open and MapShell.Ctx and MapShell.Ctx.terrain
    MapShell.LavaChannelZ = {} -- (the pools keep off them: MapShell.PlaceLavaPools, party floors)
    for _, z in ipairs(onTerrain and {} or { -0.62, 0.38 }) do
        local zz = zC + z * half
        table.insert(MapShell.LavaChannelZ, zz)
        local ch = Block(fx, Vector3.new(arena - 10, 0.3, 5), CFrame.new(0, F + 0.06, zz), { Color = C3(232, 220, 210), Material = Enum.Material.CrackedLava })
        ch.CanCollide = false; ch.CanQuery = false
        local reach = (arena - 12) / 2
        Lava.Flow(fx, Vector3.new(-reach, F + 0.21, zz), Vector3.new(reach, F + 0.21, zz), 4.4, { Light = 30, Speed = 0.05 })
        for _, sx in ipairs({ -1, 1 }) do
            local rim = Block(fx, Vector3.new(arena - 10, 0.5, 0.8), CFrame.new(0, F + 0.2, zz + sx * 2.9), theme.WallTrim)
            rim.CanCollide = false; rim.CanQuery = false
        end
    end
    -- lavafalls pouring down the side walls into glowing pools
    for _, spot in ipairs(MapShell.Open and {} or { { -1, -0.45 }, { 1, -0.15 }, { -1, 0.25 }, { 1, 0.6 } }) do -- (lavafalls need walls)
        local sx, z = spot[1], zC + spot[2] * half
        local x = sx * (half - 2.4)
        local mouth = Block(fx, Vector3.new(1.6, 2.4, 7), CFrame.new(x, height - 2.2, z), theme.WallTrim)
        mouth.CanCollide = false
        local pool = Block(fx, Vector3.new(0.4, 12, 12), CFrame.new(x - sx * 4.5, F + 0.1, z) * CFrame.Angles(0, 0, math.rad(90)), { Color = C3(232, 220, 210), Material = Enum.Material.CrackedLava })
        ;(pool :: Part).Shape = Enum.PartType.Cylinder
        pool.CanCollide = false; pool.CanQuery = false
        -- (UPDATE 4 LAVA) a streaming molten curtain (LavaFX.Fall: Beam + splash + its own foot pool + light), not a Neon slab
        Lava.Fall(fx, Vector3.new(x - sx * 0.85, height - 3.4, z), Vector3.new(x - sx * 0.85, F + 0.3, z), 4.2, Vector3.new(-sx, 0, 0), { Light = 34 })
        local base = Invisible(fx, Vector3.new(6, 1, 6), CFrame.new(x - sx * 3, F + 1, z))
        Emitter(base, { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(90, 60, 50), C3(30, 26, 26)),
            LightInfluence = 0.5, Rate = 3, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(15, 15),
            EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new(3, 9),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.7), NumberSequenceKeypoint.new(1, 1) }) })
    end
    -- hanging chains and cages from the ceiling (not under an open roof: they'd hang from the sky)
    for i = 1, ((theme :: any).OpenSky and 0 or 6) do
        local x = rng:NextNumber(-half + 20, half - 20)
        local z = zC + rng:NextNumber(-half + 20, half - 20)
        if math.abs(x) > 16 or math.abs(z - zC) > 16 then
            local len = rng:NextNumber(10, 22)
            local top = height - 2
            local chain = Block(fx, Vector3.new(len, 0.35, 0.35), CFrame.new(x, top - len / 2, z) * CFrame.Angles(0, 0, math.rad(90)), { Color = C3(40, 36, 34), Material = Enum.Material.CorrodedMetal })
            ;(chain :: Part).Shape = Enum.PartType.Cylinder
            chain.CanCollide = false
            if i % 2 == 0 then
                local cageY = top - len - 2
                for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
                    local bar = Block(fx, Vector3.new(0.25, 4, 0.25), CFrame.new(x + c[1] * 1.4, cageY, z + c[2] * 1.4), { Color = C3(44, 40, 38), Material = Enum.Material.CorrodedMetal })
                    bar.CanCollide = false
                end
                Block(fx, Vector3.new(3.2, 0.3, 3.2), CFrame.new(x, cageY - 2, z), { Color = C3(44, 40, 38), Material = Enum.Material.CorrodedMetal }).CanCollide = false
                local ember = Ball(fx, 0.9, Vector3.new(x, cageY - 1.3, z), { Color = LAVA, Material = Enum.Material.Neon })
                ember.CanCollide = false; ember.CanQuery = false
                GlowLight(ember, C3(255, 130, 60), 16, 1.6)
            end
        end
    end
end

-- ==================== [TRAVERSAL: cover + height] ====================
-- Every combat chamber gets one of six layouts (rng): freestanding wall panels, raised platforms / bridges with gaps
-- to dash across, ramps up; ROOMS v2 (2026-10-04, owner: "more room variety"): a pillar grid to peek around, raised
-- side terraces at two heights, low L-shaped bunkers. All keep the room's centre (chest), the portal row and the
-- entrance (events / merchant) clear. Returns reserved spots so props don't land inside it. Panels / platforms go in geo
-- (enemies steer around them). (2026-10-03, owner: grappling + wall running removed -- the grapple anchors and the
-- panels' glowing "runnable" top strip are gone; the panels stay as cover.)
local function WallPanel(geo: Instance, theme: BiomeTheme, a: Vector3, b: Vector3, height: number)
    -- a freestanding wall from a to b (floor points): cover, with a thin accent band along each face
    local mid = (a + b) / 2
    local len = (b - a).Magnitude
    local cf = CFrame.lookAt(mid, mid + (b - a)) * CFrame.Angles(0, math.rad(90), 0)
    Block(geo, Vector3.new(len, height, 2.2), cf * CFrame.new(0, height / 2, 0), theme.Wall)
    for _, s in ipairs({ -1, 1 }) do
        local band = Block(geo, Vector3.new(len, 0.35, 0.2), cf * CFrame.new(0, height * 0.55, s * 1.15), { Color = theme.Accent:Lerp(Color3.new(0, 0, 0), 0.35), Material = Enum.Material.Neon })
        band.CanCollide = false
        band.CanQuery = false
    end
end

local function Ramp(geo: Instance, theme: BiomeTheme, foot: Vector3, top: Vector3, width: number)
    -- a wedge from a floor point up to a platform edge
    local run = Vector3.new(top.X - foot.X, 0, top.Z - foot.Z)
    local h = top.Y - foot.Y
    local w = Block(geo, Vector3.new(width, h, run.Magnitude), CFrame.lookAt(foot + run / 2 + Vector3.new(0, h / 2, 0), foot + run + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, math.pi, 0), theme.WallTrim, "WedgePart")
    return w
end

local function Platform(geo: Instance, theme: BiomeTheme, pos: Vector3, size: Vector3)
    -- a slab whose TOP is at pos.Y, on a support column
    Block(geo, size, CFrame.new(pos - Vector3.new(0, size.Y / 2, 0)), theme.Floor)
    local trim = Block(geo, Vector3.new(size.X + 0.4, 0.3, size.Z + 0.4), CFrame.new(pos - Vector3.new(0, size.Y + 0.15, 0)), { Color = theme.Accent:Lerp(Color3.new(0, 0, 0), 0.4), Material = Enum.Material.Neon })
    trim.CanCollide = false
    trim.CanQuery = false
end

local function Anchor(_folder: Instance?, _theme: BiomeTheme, _pos: Vector3)
    -- (grapple anchors were built here; the grapple is gone -- the layouts still name the spots, nothing is built)
end

local function BuildTraversal(dungeon: Instance, geo: Instance, theme: BiomeTheme, rng: Random, zC: number, arena: number, height: number): { any }
    local half = arena / 2
    local reserved = {}
    local anchors = nil
    local F = FLOOR_TOP
    local function R(x, z, r) table.insert(reserved, { Pos = Vector3.new(x, 0, zC + z), R = r }) end

    local variants = { "Gauntlet", "Towers", "Ring", "Pillars", "Terraces", "Bunkers" }
    local variant = variants[rng:NextInteger(1, #variants)]
    -- (0.62 MAPS v3: a map item carries its own layout -- every floor of that map is built on it)
    if DungeonGenerator.ForceLayout and table.find(variants, DungeonGenerator.ForceLayout) then variant = DungeonGenerator.ForceLayout end
    dungeon:SetAttribute("Traversal", variant)

    if variant == "Gauntlet" then
        -- staggered wall panels down both sides (cover)
        for _, sx in ipairs({ -1, 1 }) do
            local xs = { sx * (half - 34), sx * (half - 18) }
            for i, zc in ipairs({ -60, -18, 24, 66 }) do
                local x = xs[(i % 2) + 1]
                WallPanel(geo, theme, Vector3.new(x, F, zC + zc - 17), Vector3.new(x, F, zC + zc + 17), 20)
                R(x, zc - 12, 6); R(x, zc, 6); R(x, zc + 12, 6)
            end
        end
        -- broken bridges between the corner pillar platforms (dash the gap)
        for _, sz in ipairs({ -1, 1 }) do
            for _, sx in ipairs({ -1, 1 }) do
                Platform(geo, theme, Vector3.new(sx * 25, 25.25, zC + sz * 50), Vector3.new(34, 1.5, 7)) -- (meets the pillar top; a 16-stud gap in the middle)
            end
        end
        for _, p in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
            Anchor(anchors, theme, Vector3.new(p[1] * (half - 26), height - 7, zC + p[2] * 20))
        end
        Anchor(anchors, theme, Vector3.new(0, height - 6, zC - 50))
        Anchor(anchors, theme, Vector3.new(0, height - 6, zC + 50))

    elseif variant == "Towers" then
        -- five towers of different heights, wall-run panels slung between neighbours, ramps onto the low ones
        local towers = {
            { Vector3.new(-62, 0, -10), 18 }, { Vector3.new(62, 0, 10), 18 }, { Vector3.new(-22, 0, -70), 26 },
            { Vector3.new(22, 0, 70), 26 }, { Vector3.new(80, 0, -70), 32 },
        }
        for i, t in ipairs(towers) do
            local p, h = t[1], t[2] + rng:NextNumber(-2, 2)
            if (theme :: any).OpenSky then
                -- (STORMSPIRE) stone towers banded in copper, not slabs of solid copper
                Block(geo, Vector3.new(12, h, 12), CFrame.new(p.X, F + h / 2, zC + p.Z), theme.Wall)
                for _, by in ipairs({ 0.3, 0.65 }) do
                    Block(geo, Vector3.new(12.4, 0.8, 12.4), CFrame.new(p.X, F + h * by, zC + p.Z), theme.WallTrim)
                end
            else
                Block(geo, Vector3.new(12, h, 12), CFrame.new(p.X, F + h / 2, zC + p.Z), theme.WallTrim)
            end
            Platform(geo, theme, Vector3.new(p.X, F + h + 0.75, zC + p.Z), Vector3.new(16, 1.5, 16))
            Anchor(anchors, theme, Vector3.new(p.X, math.min(height - 5, F + h + 16), zC + p.Z))
            R(p.X, p.Z, 13)
            if i <= 2 then
                local dir = (p.X < 0) and 1 or -1
                Ramp(geo, theme, Vector3.new(p.X + dir * 30, F, zC + p.Z), Vector3.new(p.X + dir * 8, F + h + 0.75, zC + p.Z), 8)
                R(p.X + dir * 19, p.Z, 7)
            end
        end
        WallPanel(geo, theme, Vector3.new(-54, F, zC - 24), Vector3.new(-30, F, zC - 60), 22)
        WallPanel(geo, theme, Vector3.new(54, F, zC + 24), Vector3.new(30, F, zC + 60), 22)
        WallPanel(geo, theme, Vector3.new(72, F, zC - 55), Vector3.new(68, F, zC - 5), 22)
        R(-42, -42, 8); R(42, 42, 8); R(70, -30, 8)

    elseif variant == "Pillars" then
        -- a grid of tall square pillars: peek out, take the shot, duck back (the centre column stays open)
        local spots = {}
        for _, x in ipairs({ -70, -35, 35, 70 }) do
            for _, z in ipairs({ -60, -20, 20 }) do table.insert(spots, { x, z }) end
        end
        table.insert(spots, { -70, 62 }); table.insert(spots, { 70, 62 })
        for _, sp in ipairs(spots) do
            local x, z = sp[1] + rng:NextNumber(-3, 3), sp[2] + rng:NextNumber(-3, 3)
            local h = 22 + rng:NextNumber(-2, 4)
            Block(geo, Vector3.new(7, h, 7), CFrame.new(x, F + h / 2, zC + z), theme.Wall)
            Block(geo, Vector3.new(7.8, 1, 7.8), CFrame.new(x, F + 0.5, zC + z), theme.WallTrim) -- plinth
            Block(geo, Vector3.new(7.6, 0.8, 7.6), CFrame.new(x, F + h * 0.62, zC + z), theme.WallTrim) -- a band
            local glow = Block(geo, Vector3.new(7.9, 0.3, 7.9), CFrame.new(x, F + h * 0.62 + 0.55, zC + z), { Color = theme.Accent:Lerp(Color3.new(0, 0, 0), 0.35), Material = Enum.Material.Neon })
            glow.CanCollide = false; glow.CanQuery = false
            R(x, z, 8)
        end

    elseif variant == "Terraces" then
        -- a raised terrace down each side at two heights (shoot down into the middle, or fight up the ramps)
        for _, side in ipairs({ { -1, 7 }, { 1, 12 } }) do
            local sx, h = side[1], side[2]
            local x = sx * (half - 18)
            Block(geo, Vector3.new(30, h, 150), CFrame.new(x, F + h / 2, zC - 10), theme.WallTrim)
            local edge = Block(geo, Vector3.new(0.4, 0.3, 150), CFrame.new(x - sx * 15.1, F + h - 0.2, zC - 10), { Color = theme.Accent:Lerp(Color3.new(0, 0, 0), 0.35), Material = Enum.Material.Neon })
            edge.CanCollide = false; edge.CanQuery = false
            -- a low parapet along the terrace's inner edge with a gap in the middle (cover up top)
            for _, zz in ipairs({ -55, 35 }) do
                Block(geo, Vector3.new(1.4, 3.2, 40), CFrame.new(x - sx * 13.6, F + h + 1.6, zC + zz), theme.Wall)
            end
            for _, rz in ipairs({ -60, 40 }) do
                Ramp(geo, theme, Vector3.new(x - sx * 40, F, zC + rz), Vector3.new(x - sx * 15, F + h, zC + rz), 9)
                R(x - sx * 27, rz, 8)
            end
            for z = -80, 60, 20 do R(x, z, 16) end
        end

    elseif variant == "Bunkers" then
        -- four low L-shaped bunkers (crouch-height cover) facing the middle, and two short walls by the entrance
        for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
            local cx, cz = q[1] * 55, q[2] * 42
            local a = Vector3.new(cx, F, zC + cz)
            WallPanel(geo, theme, a, a + Vector3.new(-q[1] * 22, 0, 0), 5.5)
            WallPanel(geo, theme, a, a + Vector3.new(0, 0, -q[2] * 18), 5.5)
            R(cx - q[1] * 11, cz, 7); R(cx, cz - q[2] * 9, 7); R(cx, cz, 6)
        end
        for _, sx in ipairs({ -1, 1 }) do
            WallPanel(geo, theme, Vector3.new(sx * 38, F, zC - 70), Vector3.new(sx * 58, F, zC - 70), 8)
            R(sx * 48, -70, 9)
        end

    else -- "Ring"
        -- a raised catwalk around the room with gaps to dash / jump, ramps up at four points
        local y, w, inset = F + 16, 9, half - 14
        local seg = {
            { Vector3.new(0, y, -inset), Vector3.new(arena - 60, 1.5, w) }, { Vector3.new(0, y, inset), Vector3.new(arena - 60, 1.5, w) },
            { Vector3.new(-inset, y, -half * 0.45), Vector3.new(w, 1.5, half * 0.7) }, { Vector3.new(-inset, y, half * 0.45), Vector3.new(w, 1.5, half * 0.7) },
            { Vector3.new(inset, y, -half * 0.45), Vector3.new(w, 1.5, half * 0.7) }, { Vector3.new(inset, y, half * 0.45), Vector3.new(w, 1.5, half * 0.7) },
        }
        for _, s in ipairs(seg) do
            Platform(geo, theme, Vector3.new(s[1].X, s[1].Y, zC + s[1].Z), s[2])
        end
        for _, sx in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                Ramp(geo, theme, Vector3.new(sx * 50, F, zC + sz * (inset - 30)), Vector3.new(sx * 50, y, zC + sz * (inset - w / 2)), 7)
                Anchor(anchors, theme, Vector3.new(sx * (half - 40), height - 6, zC + sz * (half - 40)))
            end
        end
        -- two centre panels to wall-run between the catwalk sides
        WallPanel(geo, theme, Vector3.new(-64, F, zC - 18), Vector3.new(-64, F, zC + 18), 18)
        WallPanel(geo, theme, Vector3.new(64, F, zC - 18), Vector3.new(64, F, zC + 18), 18)
        R(-64, 0, 20); R(64, 0, 20)
        for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do R(sx * 50, sz * (inset - 17), 8) end end
        Anchor(anchors, theme, Vector3.new(0, height - 6, zC))
    end
    return reserved
end

-- ==================== [PROCEDURAL BIOME ARENA] ====================
-- ==================== [MAP SHELLS: arenas as reference-style maps] ====================
-- (2026-10-05, owner: "the hub and arenas ... come across as a bit low effort ... use Path of exile towns and maps /
-- missions for reference"). The combat chamber keeps its gameplay box -- floor + four walls stay as INVISIBLE colliders,
-- so movement, bots (they steer round StaticGeometry), portals and the chest are untouched -- and the world round it is
-- rebuilt per biome TEMPLATE (3 each, picked by the floor seed): a layered ground, a broken rim of cliffs / ruins / a
-- chasm edge just outside the box, a far landmark, kit props (EnvKit, AI-made meshes) along the edges + on the rim.
-- SOLO floors are built on the client: the ground and the cliffs are TERRAIN (cheap, organic; only this client sees
-- it). PARTY floors are built on the server at the same spot for every party -- terrain can't be hidden per client --
-- so there the rim is made of kit rocks (parts) on the regular floor. Cyber templates are part-built everywhere.
-- (PARTY TWIN 2026-10-25: that part-built party look is now only the Studio DevTwinOff path -- a party floor is MIRRORED on the
-- server and every member builds the solo look locally, AimRngShared/PartyTwin.)
local EnvKit = require(script.Parent:WaitForChild("EnvKit"))
MapShell.Open = false -- (set while a floor builds: true = the combat room has no visible walls / ceiling)
local M = Enum.Material
MapShell.TEMPLATES = {
    Fire = {
        -- (UPDATE 4 PROPS: scanned fort ruins, basalt columns, scoria, fire pits and brick kilns replace the AI kit)
        { Name = "Foundry", Rim = "Ruins", Ground = M.Basalt, Patch = { M.CrackedLava, M.Slate }, Edge = { "Kiln", "Outcrop", "FirePit", "FortEnd", "ScoriaB" },
            RimKit = { "Kiln", "FortWall", "FortEnd", "BasaltSpire", "FortTower" }, Hero = "Volcano",
            Glow = { Kiln = Color3.fromRGB(255, 140, 60), FirePit = Color3.fromRGB(255, 140, 60) } },
        { Name = "Caldera", PartyRim = "BasaltColsB", Rim = "Cliffs", RimMat = { M.Basalt, M.Slate }, RimAccent = M.CrackedLava, Ground = M.Basalt, Patch = { M.CrackedLava, M.Rock },
            Edge = { "Outcrop", "BasaltColsA", "ScoriaB", "BasaltColsB" }, RimKit = { "BasaltSpire", "Outcrop", "BasaltColsB" }, Hero = "Volcano",
            Glow = { BasaltColsA = Color3.fromRGB(255, 120, 50) } },
        { Name = "Cinder Keep", Rim = "Ruins", Ground = M.Basalt, Patch = { M.Slate, M.CrackedLava }, Edge = { "FortEnd", "FirePit", "Outcrop", "FortCorner" },
            RimKit = { "FortWall", "FortTower", "FortEnd", "BasaltSpire" }, Hero = nil, Glow = { FirePit = Color3.fromRGB(255, 120, 50) } },
    },
    Ice = {
        -- (UPDATE 4 PROPS: scanned statues + boulders, monastery stonework, ice crystal clusters replace the AI kit;
        -- the pines + sled stay)
        { Name = "Frozen Monastery", Rim = "Ruins", RimMat = { M.Slate, M.Rock }, Ground = M.Snow, Patch = { M.Glacier, M.Ice }, Edge = { "FrozenStatue", "IceCrystalsA", "SnowBoulder" },
            RimKit = { "MonasteryWall", "MonasteryTower", "FrozenStatue", "SnowBoulder" }, Hero = "GiantStatue", Glow = { IceCrystalsA = Color3.fromRGB(130, 210, 255) } },
        { Name = "Glacier Rift", PartyRim = "SnowBoulder", Rim = "Cliffs", RimMat = { M.Glacier, M.Rock }, Ground = M.Snow, Patch = { M.Glacier, M.Ice },
            Edge = { "IceCrystalsA", "SnowBoulder", "IceCrystalsB", "SnowRockB" }, RimKit = { "IceCrystalsB", "SnowBoulder" }, Hero = nil,
            Glow = { IceCrystalsA = Color3.fromRGB(130, 210, 255) } },
        { Name = "Pine Hollow", PartyRim = "Pine", Rim = "Cliffs", RimMat = { M.Rock, M.Slate }, Ground = M.Snow, Patch = { M.Ground, M.Glacier },
            Edge = { "Pine", "Sled", "SnowBoulder" }, RimKit = { "Pine", "Pine", "SnowBoulder" }, Hero = nil, Glow = {} },
    },
    Void = {
        -- (UPDATE 4 PROPS: an eldritch idol, violet crystals, obsidian spires, scanned roots and dark ruins replace the AI kit)
        { Name = "Shattered Sanctum", Rim = "Ruins", Ground = M.Slate, Patch = { M.Glacier, M.Asphalt }, Edge = { "VoidStatue", "VoidSpire", "VoidCrystalsA" },
            RimKit = { "RuinWall", "RuinTower", "VoidSpire", "VoidRoots" }, Hero = "FloatingRuins",
            Glow = { VoidCrystalsA = Color3.fromRGB(170, 110, 255), VoidStatue = Color3.fromRGB(190, 120, 255) } },
        { Name = "Floating Isles", Rim = "Edge", Ground = M.Slate, Patch = { M.Glacier, M.Asphalt }, Edge = { "VoidCrystalsA", "VoidRoots", "VoidCrystalsB" },
            RimKit = { "VoidCrystalsB", "VoidRoots" }, Hero = "FloatingRuins", Glow = { VoidCrystalsA = Color3.fromRGB(170, 110, 255) } },
        { Name = "Rootwood", PartyRim = "VoidRoots", Rim = "Cliffs", RimMat = { M.Slate, M.Glacier }, Ground = M.Mud, Patch = { M.Slate, M.Glacier },
            Edge = { "VoidRoots", "VoidCrystalsA", "VoidStatue" }, RimKit = { "VoidRoots", "VoidRoots", "VoidSpire" }, Hero = "FloatingRuins",
            Glow = { VoidCrystalsA = Color3.fromRGB(170, 110, 255) } },
    },
    Cyber = {
        -- (UPDATE 4 PROPS: scanned sci-fi cases / crates / a high-voltage canister for the AI containers; scanned utility
        -- cabinets for the AI cables / terminal, a transformer pole for the AI neon pole)
        { Name = "Server Vault", Closed = true, Rows = "ServerRack", Edge = { "ServerRack", "CyberBoxA", "CyberBoxB", "CyberCrates", "CyberBarrel" }, Glow = { CyberBoxB = Color3.fromRGB(60, 230, 220) } },
        { Name = "Rooftop", Rim = "Edge", Parts = true, Edge = { "CyberCrates", "CyberPole", "CyberBarrel", "CyberBoxA" }, RimKit = { "CyberCase", "CyberPole" }, Hero = "Skyline",
            Glow = { CyberPole = Color3.fromRGB(255, 80, 200) } },
        { Name = "Data Yard", Rim = "Ruins", Parts = true, Edge = { "CyberCrates", "ServerRack", "CyberBarrel", "CyberCase", "CyberBoxB" }, RimKit = { "CyberCrates", "CyberBarrel", "CyberPole" }, Hero = "Skyline",
            Glow = { CyberBoxB = Color3.fromRGB(60, 230, 220) } },
    },
    Storm = {
        -- (UPDATE 4 PROPS: scanned slate boulders / slabs, a felled trunk + stumps, aqueduct stonework; tesla towers, rods
        -- and the lighthouse stay)
        { Name = "Lighthouse Cliffs", PartyRim = "StormBoulder", Rim = "Cliffs", RimMat = { M.Rock, M.Basalt }, Ground = M.Grass, Patch = { M.Slate, M.Mud, M.Ground },
            Edge = { "StormBoulder", "RodStone", "Stump", "StormSlab" }, RimKit = { "StormBoulder", "StormRock", "RodStone" }, Hero = "Lighthouse", Glow = {} },
        { Name = "Tesla Works", Rim = "Ruins", Ground = M.Slate, Patch = { M.Pavement, M.Mud }, Edge = { "TeslaTower", "RodStone", "StormBoulder" },
            RimKit = { "TeslaTower", "AqueductWall", "RodStone" }, Hero = nil, Glow = { TeslaTower = Color3.fromRGB(150, 200, 255) } },
        { Name = "Sunken Aqueduct", Rim = "Ruins", Ground = M.Mud, Patch = { M.Slate, M.Grass }, Edge = { "DeadTrunk", "StormBoulder", "RodStone", "Stump" },
            RimKit = { "AqueductWall", "AqueductEnd", "StormBoulder" }, Hero = "Lighthouse", Glow = {} },
    },
}
function MapShell.Pick(biome: string, rng: Random): any
    local list = MapShell.TEMPLATES[biome] or MapShell.TEMPLATES.Fire
    local pick = list[rng:NextInteger(1, #list)]
    -- (Studio test hook: workspace attribute DevMapTemplate = a template name forces it for that biome)
    local force = game:GetService("RunService"):IsStudio() and Workspace:GetAttribute("DevMapTemplate")
    if force then for _, t in ipairs(list) do if t.Name == force then pick = t end end end
    return pick
end

-- is a floor point free of the reserved spots (centre plaza, portal, doorways, pillars, traversal)?
local function FreeSpot(reserved: { any }, p: Vector3, r: number): boolean
    for _, s in ipairs(reserved) do
        local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(s.Pos.X, 0, s.Pos.Z)).Magnitude
        if s.Ring then
            if math.abs(d - s.Ring) < s.R + r then return false end
        elseif d < s.R + r then
            return false
        end
    end
    return true
end

local function GlowAt(parent: Instance, pos: Vector3, color: Color3, range: number)
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.Transparency = 1; p.Size = Vector3.new(1, 1, 1); p.Position = pos; p.Name = "ShellGlow"; p.Parent = parent
    local l = Instance.new("PointLight"); l.Color = color; l.Range = range; l.Brightness = 1.8; l.Shadows = false; l.Parent = p
end

-- "Outcrop": a rock pile built fresh every time from 3-5 tilted slabs of the map's own stone (owner 2026-10-05: "Pyro
-- dungeon rock piles look all exactly the same and very out of place" -- one boulder mesh, repeated). Terrain on solo
-- floors (it melts into the ground), stone parts on party floors. Used like a kit name in the templates' lists.
local ROCK_COLORS = { [M.Basalt] = Color3.fromRGB(58, 52, 52), [M.Slate] = Color3.fromRGB(78, 74, 72), [M.Rock] = Color3.fromRGB(96, 88, 82),
    [M.Glacier] = Color3.fromRGB(150, 190, 215), [M.Snow] = Color3.fromRGB(220, 228, 235) }
local function Outcrop(fx: Instance, cf: CFrame, s: number, rng: Random, mat: Enum.Material, terrain: boolean, seam: Enum.Material?, hitParent: Instance?): Instance
    local m = Instance.new("Model")
    m.Name = "Outcrop"
    local base = cf.Position
    local n = rng:NextInteger(3, 5)
    local top = 0
    for i = 1, n do
        local h = rng:NextNumber(2.6, 6.5) * s * ((i == 1) and 1.25 or 1)
        local off = (i == 1) and Vector3.zero or Vector3.new(rng:NextNumber(-2, 2) * s, 0, rng:NextNumber(-2, 2) * s)
        local size = Vector3.new(rng:NextNumber(2.2, 4.2) * s, h, rng:NextNumber(1.8, 3.4) * s)
        local scf = CFrame.new(base + off + Vector3.new(0, h * 0.32, 0)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4))
        top = math.max(top, h * 0.32 + h / 2)
        if terrain then
            MapShell.T():FillBlock(scf, size, mat)
        else
            local p = Instance.new("Part")
            p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
            p.CastShadow = s > 2.5
            p.Size = size; p.CFrame = scf; p.Material = mat
            p.Color = (ROCK_COLORS[mat] or Color3.fromRGB(80, 74, 70)):Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.18))
            p.Parent = m
        end
    end
    if seam and terrain and rng:NextNumber() < 0.6 then
        MapShell.T():FillBall(base + Vector3.new(rng:NextNumber(-1, 1) * s, 0.4 * s, rng:NextNumber(-1, 1) * s), 1.6 * s, seam)
    end
    if hitParent then
        local h = Instance.new("Part")
        h.Name = "Hitbox"; h.Anchored = true; h.Transparency = 1; h.CastShadow = false; h.CanTouch = false
        h.Size = Vector3.new(3.4 * s, math.max(top * 0.85, 3), 3.4 * s) -- (inside the rock: invisible box edges blocked shots)
        h.CFrame = CFrame.new(base + Vector3.new(0, h.Size.Y / 2, 0))
        h.Parent = hitParent
    end
    m.Parent = fx
    return m
end
-- (UPDATE 4 PROPS, owner: "A lot of the props also dont fit / look lower quality throughout the biomes") Molten kit
-- pieces that need life on top of their stonework. The rest of the new Molten kit are scanned / generated meshes in
-- EnvKit.Fire (tools/biome_mesh_import.py: BasaltSpire, BasaltColsA/B, FortEnd / FortCorner / FortWall / FortTower,
-- ScoriaA/B, FirePit) placed by EnvKit.Place like the old AI kit (Spire, Furnace, BrokenColumn, Cage stay as fallbacks).
MapShell.FireKit = {}
function MapShell.KitHitbox(opts: any, size: Vector3, cf: CFrame) -- (a field: this chunk is near the 200-local limit)
    if not opts.Hitbox then return end
    local h = Instance.new("Part")
    h.Name = "Hitbox"; h.Anchored = true; h.Transparency = 1; h.CastShadow = false; h.CanTouch = false
    h.Size = typeof(opts.Hitbox) == "Vector3" and opts.Hitbox or size * (opts.HitScale or 0.9)
    h.CFrame = cf
    h.Parent = opts.HitParent or opts.Parent
end
-- a brick forge kiln: plinth, firebox with iron bands, a glowing coal mouth (LavaFX.Panel), shoulder + chimney smoking
function MapShell.FireKit.Kiln(_biome: string, cf: CFrame, opts: any, rng: Random): Instance
    local s = (opts.Scale or 1) * 0.9
    local m = Instance.new("Model"); m.Name = opts.Name or "Kiln"
    local soot = { Color = C3(98, 76, 66), Material = Enum.Material.Brick }
    local dark = { Color = C3(44, 37, 35), Material = Enum.Material.Slate }
    local iron = { Color = C3(60, 52, 48), Material = Enum.Material.CorrodedMetal }
    local function B(size: Vector3, off: Vector3, surf: any): BasePart
        local p = Block(m, size * s, cf * CFrame.new(off * s), surf)
        p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
        return p
    end
    B(Vector3.new(7.6, 1.0, 7.6), Vector3.new(0, 0.5, 0), dark) -- plinth
    B(Vector3.new(6.6, 5.2, 6.6), Vector3.new(0, 3.6, 0), soot) -- firebox
    B(Vector3.new(7.0, 0.5, 7.0), Vector3.new(0, 6.45, 0), dark) -- cornice
    B(Vector3.new(5.0, 1.6, 5.0), Vector3.new(0, 7.5, 0), soot) -- shoulder
    B(Vector3.new(2.2, 6.0, 2.2), Vector3.new(0.9, 11.3, 0.6), soot) -- chimney
    local cap = B(Vector3.new(2.7, 0.5, 2.7), Vector3.new(0.9, 14.55, 0.6), dark)
    for _, y in ipairs({ 1.6, 5.2 }) do B(Vector3.new(6.8, 0.35, 6.8), Vector3.new(0, y, 0), iron) end -- iron bands
    -- the mouth on the front (-Z): jambs + lintel round a recessed molten face
    B(Vector3.new(0.6, 3.0, 0.7), Vector3.new(-1.5, 2.9, -3.35), dark)
    B(Vector3.new(0.6, 3.0, 0.7), Vector3.new(1.5, 2.9, -3.35), dark)
    B(Vector3.new(3.6, 0.6, 0.7), Vector3.new(0, 4.6, -3.35), dark)
    local mouth = B(Vector3.new(2.4, 2.6, 0.2), Vector3.new(0, 2.75, -3.32), { Color = C3(30, 14, 10), Material = Enum.Material.Basalt })
    DungeonGenerator.Lava().Panel(mouth, Enum.NormalId.Front, { PPS = 50 })
    local smoke = Instance.new("ParticleEmitter")
    smoke.Name = "KilnSmoke"
    smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
    smoke.Color = ColorSequence.new(C3(70, 58, 54), C3(28, 24, 24))
    smoke.LightInfluence = 0.6; smoke.Rate = 1.2
    smoke.Lifetime = NumberRange.new(5, 8); smoke.Speed = NumberRange.new(3, 5)
    smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5 * s), NumberSequenceKeypoint.new(1, 6 * s) })
    smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.6), NumberSequenceKeypoint.new(1, 1) })
    smoke.Acceleration = Vector3.new(1, 0.8, 0); smoke.EmissionDirection = Enum.NormalId.Top
    smoke.Parent = cap
    FxAnim.Low(smoke)
    local sparks = Instance.new("ParticleEmitter")
    sparks.Name = "KilnSparks"
    sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparks.Color = ColorSequence.new(C3(255, 210, 110), C3(255, 80, 20))
    sparks.LightEmission = 1; sparks.LightInfluence = 0; sparks.Rate = 3
    sparks.Lifetime = NumberRange.new(0.6, 1.3); sparks.Speed = NumberRange.new(4, 9); sparks.SpreadAngle = Vector2.new(25, 25)
    sparks.Acceleration = Vector3.new(0, -14, 0)
    sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
    sparks.Transparency = NumberSequence.new(0, 1); sparks.EmissionDirection = Enum.NormalId.Front
    sparks.Parent = mouth
    FxAnim.Low(sparks)
    MapShell.KitHitbox(opts, Vector3.new(7.2, 7.2, 7.2) * s, cf * CFrame.new(0, 3.6 * s, 0))
    m.Parent = opts.Parent
    return m
end
-- the scanned stone fire pit with a bed of coals and flames in it
function MapShell.FireKit.FirePit(_biome: string, cf: CFrame, opts: any, rng: Random): Instance?
    local inst = EnvKit.Place("Fire", "FirePit", cf, opts)
    if not inst then return nil end
    local _, size = (inst :: Model):GetBoundingBox()
    local parent = opts.Parent
    DungeonGenerator.Lava().Pool(parent, cf * CFrame.new(0, size.Y * 0.42, 0), size.X * 0.3, { Light = false, Smoke = false })
    local at = Instance.new("Part")
    at.Name = "PitFlame"; at.Anchored = true; at.Transparency = 1; at.CanCollide = false; at.CanQuery = false; at.CanTouch = false
    at.Size = Vector3.new(size.X * 0.4, 0.4, size.Z * 0.4); at.CFrame = cf * CFrame.new(0, size.Y * 0.55, 0); at.Parent = parent
    local fire = Instance.new("Fire")
    fire.Size = math.clamp(size.X * 0.9, 3, 10); fire.Heat = 9
    fire.Color = C3(255, 120, 40); fire.SecondaryColor = C3(255, 200, 90)
    fire.Parent = at
    return inst
end
-- EnvKit.Place, or an Outcrop when the template names one (ctx: { mat, terrain, seam })
local function ShellPlace(biome: string, kit: string, cf: CFrame, opts: any, rng: Random, ctx: any): Instance?
    if kit == "Outcrop" then
        return Outcrop(opts.Parent, cf, (opts.Scale or 1) * 0.75, rng, ctx.mat or M.Basalt, ctx.terrain, ctx.seam, opts.Hitbox and (opts.HitParent or opts.Parent) or nil)
    end
    local fk = MapShell.FireKit[kit] -- (UPDATE 4 PROPS: kits with life -- coals, flames, smoke -- on their stonework)
    if fk then return fk(biome, cf, opts, rng) end
    local nbk = DungeonGenerator.NB.Kit(kit, cf, opts) -- (the new biomes' procedural kits)
    if nbk then return nbk end
    return (EnvKit.Place(biome, kit, cf, opts))
end

-- VISTA (owner 2026-10-05: "Skyboxes and outside areas ... shouldn't just be black. Just add the illusion of the biome
-- being continued (mountains, land etc without actually doing much)"): a ground plane out to the horizon + a ring of
-- big mountain silhouettes far out (one tilted cube each, corner up, half sunk -- reads as a peak), in the biome's
-- colours; the client's per-biome Atmosphere hazes them into the sky. ~20 parts, no shadows, nothing collides.
-- CYBER MEGACITY TOWER (owner 2026-10-05: "cyber skybox is boring (big brutalist shapes in distance)"): a stepped tower
-- instead of a plain box -- a dark body, one or two setback tiers, LED piping up its front corners, a lit crown, a spire
-- with an aircraft-warning light on the tallest, and now and then a holo billboard. detail 1 = far (4-5 parts), 2 = near.
local CYBER_NEON = { Color3.fromRGB(60, 230, 220), Color3.fromRGB(255, 70, 190), Color3.fromRGB(255, 170, 60), Color3.fromRGB(160, 90, 255) }
local function CyberTower(fx: Instance, foot: Vector3, w: number, h: number, r: Random, detail: number, face: Vector3?)
    local function P(size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, transp: number?)
        local p = Instance.new("Part")
        p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
        p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat; p.Transparency = transp or 0
        p.Parent = fx
        return p
    end
    -- face the arena (the lit side is the one you see)
    local look = face or Vector3.new(-foot.X, 0, -foot.Z)
    local yaw = math.atan2(-look.X, -look.Z)
    local rot = CFrame.Angles(0, yaw + r:NextNumber(-0.2, 0.2), 0)
    local body = Color3.fromRGB(14 + r:NextInteger(0, 8), 16 + r:NextInteger(0, 8), 26 + r:NextInteger(0, 12))
    local neon = CYBER_NEON[r:NextInteger(1, #CYBER_NEON)]
    local d = w * r:NextNumber(0.7, 1.0)
    local h1 = h * r:NextNumber(0.55, 0.72)
    local base = CFrame.new(foot) * rot
    P(Vector3.new(w, h1, d), base * CFrame.new(0, h1 / 2, 0), body, M.Metal)
    -- setback tier(s)
    local w2, d2, h2 = w * 0.68, d * 0.68, h - h1
    P(Vector3.new(w2, h2, d2), base * CFrame.new(0, h1 + h2 / 2, 0), body:Lerp(Color3.new(0, 0, 0), 0.15), M.Metal)
    -- the crown: a lit band round the top of each tier
    P(Vector3.new(w + 0.4, 1.6, d + 0.4), base * CFrame.new(0, h1 - 1.2, 0), neon, M.Neon, 0.15)
    P(Vector3.new(w2 + 0.4, 1.4, d2 + 0.4), base * CFrame.new(0, h - 1, 0), neon, M.Neon, 0.1)
    if detail >= 2 then
        -- LED piping up the two front corners, a second colour on the upper tier
        local n2 = CYBER_NEON[r:NextInteger(1, #CYBER_NEON)]
        for _, sx in ipairs({ -1, 1 }) do
            P(Vector3.new(0.7, h1 - 4, 0.7), base * CFrame.new(sx * (w / 2), h1 / 2, -d / 2), neon, M.Neon, 0.2)
            P(Vector3.new(0.6, h2 - 3, 0.6), base * CFrame.new(sx * (w2 / 2), h1 + h2 / 2, -d2 / 2), n2, M.Neon, 0.2)
        end
        -- window rows: a few faint horizontal strips on the front face
        for k = 1, r:NextInteger(2, 4) do
            local y = h1 * (0.18 + 0.18 * k)
            if y < h1 - 6 then
                P(Vector3.new(w * 0.8, 0.5, 0.2), base * CFrame.new(0, y, -d / 2 - 0.1), Color3.fromRGB(150, 190, 230), M.Neon, 0.65)
            end
        end
        -- a holo billboard on the front, high up
        if r:NextNumber() < 0.35 then
            local bw, bh = math.min(w * 0.75, 26), math.min(h1 * 0.18, 16)
            P(Vector3.new(bw, bh, 0.3), base * CFrame.new(0, h1 * 0.78, -d / 2 - 1.2), CYBER_NEON[r:NextInteger(1, #CYBER_NEON)], M.Neon, 0.35)
        end
    end
    -- a spire with a warning light on the tall ones
    if h > (detail >= 2 and 120 or 260) then
        local sh = h * r:NextNumber(0.12, 0.22)
        P(Vector3.new(1.4, sh, 1.4), base * CFrame.new(0, h + sh / 2, 0), body, M.Metal)
        P(Vector3.new(2.6, 2.6, 2.6), base * CFrame.new(0, h + sh + 1, 0), Color3.fromRGB(255, 40, 40), M.Neon)
    end
end

local VISTA = {
    Fire = { Ground = Color3.fromRGB(40, 24, 20), GroundMat = Enum.Material.Basalt, Peak = Color3.fromRGB(44, 28, 24), PeakMat = Enum.Material.Basalt, Tip = Color3.fromRGB(255, 110, 40) },
    Ice = { Ground = Color3.fromRGB(206, 220, 234), GroundMat = Enum.Material.Snow, Peak = Color3.fromRGB(150, 168, 190), PeakMat = Enum.Material.Rock, Tip = Color3.fromRGB(236, 244, 255) },
    Void = { Ground = Color3.fromRGB(26, 18, 38), GroundMat = Enum.Material.Basalt, Peak = Color3.fromRGB(52, 34, 78), PeakMat = Enum.Material.Slate, Tip = Color3.fromRGB(190, 110, 255) },
    Cyber = { Ground = Color3.fromRGB(12, 14, 22), GroundMat = Enum.Material.Asphalt, Peak = Color3.fromRGB(20, 28, 36), PeakMat = Enum.Material.Metal, Tip = Color3.fromRGB(60, 230, 220) },
    Storm = { Ground = Color3.fromRGB(64, 78, 62), GroundMat = Enum.Material.Grass, Peak = Color3.fromRGB(70, 76, 88), PeakMat = Enum.Material.Rock, Tip = Color3.fromRGB(190, 205, 225) },
}
-- (BIOME SKIES 2026-10-05: each biome's far scenery matches its painted sky -- tools/make_skies.py -- Molten: the erupting
-- volcano under the sky's ash column, east; Glacier: ice spires and snow peaks; Void: floating rock islands; Cyber: a
-- megacity; Storm: the mountain ring.)
local ERUPTION_DIR = Vector3.new(0.85, 0, 0.52).Unit -- (make_skies.py paint_fire: plume_dir)
function MapShell.Vista(fx: Instance, biome: string, tpl: any, zC: number, half: number)
    local v = VISTA[biome] or VISTA.Fire
    local r = Random.new(math.floor(zC) + #tostring(tpl.Name) * 131)
    local function P(props)
        local p = Instance.new("Part")
        p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
        for k, val in pairs(props) do (p :: any)[k] = val end
        p.Parent = fx
        return p
    end
    local edge = tpl.Rim == "Edge"
    -- the land carries on to the horizon (a chasm map's floor is far below instead)
    local gy = edge and (FLOOR_TOP - (tpl.Parts and 140 or 220)) or (FLOOR_TOP - 5)
    P({ Name = "VistaGround", Size = Vector3.new(6000, 2, 6000), CFrame = CFrame.new(0, gy - 1, zC), Color = v.Ground, Material = v.GroundMat })
    local centre = Vector3.new(0, gy, zC)
    if DungeonGenerator.NB.Vista(fx, biome, P, centre, gy, zC, r) then return end
    if biome == "Cyber" then
        -- a megacity to the horizon (the Skyline hero is the near ring)
        for _ = 1, 30 do
            local a = r:NextNumber(0, math.pi * 2)
            local d = r:NextNumber(650, 1300)
            CyberTower(fx, centre + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), r:NextNumber(36, 80), r:NextNumber(160, 480), r, 1)
        end
        return
    end
    local function Peak(a: number, d: number, sz: number, color: Color3, mat: Enum.Material, tip: boolean)
        local base = CFrame.new(math.cos(a) * d, gy - sz * 0.32, zC + math.sin(a) * d)
            * CFrame.Angles(0, r:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(math.rad(45), 0, math.rad(35.264))
        P({ Name = "VistaPeak", Size = Vector3.one * sz, CFrame = base, Color = color:Lerp(Color3.new(0, 0, 0), r:NextNumber(0, 0.25)), Material = mat })
        if tip and biome ~= "Fire" and biome ~= "Void" then -- (UPDATE 4: glowing Neon tips read as coloured cubes on the ridges)
            P({ Name = "VistaTip", Size = Vector3.one * sz * 0.34, CFrame = base * CFrame.new(Vector3.one * sz * 0.33), Color = v.Tip,
                Material = (biome == "Ice" or biome == "Storm") and Enum.Material.Snow or Enum.Material.Neon, Transparency = (biome == "Ice" or biome == "Storm") and 0 or 0.35 })
        end
    end
    if biome == "Fire" then
        -- THE VOLCANO: a broad dark cone on the eastern horizon (four stacked, narrowing blocks turned to read as a
        -- cone in the haze), a glowing crater, lava runs down its flanks, smoke boiling out of the top
        local vd = 1150
        local vc = centre + ERUPTION_DIR * vd
        local H = 380
        for k = 0, 3 do
            local w = 760 * (1 - k * 0.24)
            local hh = H * 0.3
            -- (MAPLOOK: round tiers -- the turned boxes read as a stack of crates on the horizon, plain to see down a path)
            local round = MapShell.LookOn()
            P({ Name = "VolcanoTier", Shape = round and Enum.PartType.Cylinder or Enum.PartType.Block,
                Size = round and Vector3.new(hh, w, w) or Vector3.new(w, hh, w * 0.9),
                CFrame = CFrame.new(vc + Vector3.new(0, hh * (k + 0.5) - 10, 0)) * CFrame.Angles(0, k * 0.4, round and math.rad(90) or 0),
                Color = v.Peak:Lerp(Color3.new(0, 0, 0), k * 0.08), Material = Enum.Material.Basalt })
        end
        local top = vc + Vector3.new(0, H * 1.2 - 10, 0)
        -- (UPDATE 4 LAVA) a dark crater rim with the glow of the vent above it (self-lit soft glows, not a flat Neon disc)
        local Lava = DungeonGenerator.Lava()
        P({ Name = "VolcanoCrater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 140, 140), CFrame = CFrame.new(top) * CFrame.Angles(0, 0, math.rad(90)),
            Color = Color3.fromRGB(34, 26, 24), Material = Enum.Material.Basalt })
        Lava.Glow(fx, top + Vector3.new(0, 26, 0), 260, Color3.fromRGB(255, 96, 34), 0.45, { Name = "CraterHalo", Pulse = 0.05 })
        Lava.Glow(fx, top + Vector3.new(0, 10, 0), 110, Color3.fromRGB(255, 170, 70), 0.15, { Name = "CraterCore" })
        for k = 1, 5 do -- lava runs: molten rivers (LavaFX.Flow) down the face toward the arena
            local side = (k - 3) * 55
            local toward = (-ERUPTION_DIR + ERUPTION_DIR:Cross(Vector3.yAxis) * (side / 300)).Unit
            local from = top + toward * 40
            local to = vc + toward * (300 + r:NextNumber(-40, 60)) + Vector3.new(0, 20, 0)
            local w = r:NextNumber(8, 14)
            local dir = (to - from).Unit
            local up = dir:Cross(Vector3.yAxis).Unit:Cross(dir).Unit
            Lava.Flow(fx, from + up * 3, to + up * 3, w * 1.4, { Up = up, Light = false, Smoke = false, Sparks = false, Speed = 0.015, Bright = 2.3, Name = "LavaRun" })
        end
        local smokeAt = Instance.new("Attachment")
        local anchor = P({ Name = "VolcanoSmoke", Size = Vector3.new(4, 4, 4), CFrame = CFrame.new(top + Vector3.new(0, 30, 0)), Transparency = 1 })
        smokeAt.Parent = anchor
        local pe = Instance.new("ParticleEmitter")
        pe.Name = "Ash"
        pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
        pe.Color = ColorSequence.new(Color3.fromRGB(150, 70, 40), Color3.fromRGB(30, 22, 20)) -- (lit from below by the vent)
        pe.LightEmission = 0.25
        pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 90), NumberSequenceKeypoint.new(1, 260) })
        pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
        pe.Lifetime = NumberRange.new(16, 22)
        pe.Rate = 2.5
        pe.Speed = NumberRange.new(22, 34)
        pe.SpreadAngle = Vector2.new(18, 18)
        pe.Acceleration = Vector3.new(4, 2, 0)
        pe.RotSpeed = NumberRange.new(-8, 8)
        pe.Parent = smokeAt
        -- lower basalt ridges round the rest of the horizon, a few with ember-lit tops
        for i = 1, 14 do
            local a = (i / 14) * math.pi * 2 + r:NextNumber(-0.12, 0.12)
            local dir = Vector3.new(math.cos(a), 0, math.sin(a))
            if dir:Dot(ERUPTION_DIR) < 0.93 then
                Peak(a, r:NextNumber(650, 1150), r:NextNumber(180, 380), v.Peak, v.PeakMat, r:NextNumber() < 0.3)
            end
        end
        return
    end
    if biome == "Ice" then
        -- ICE SPIRES: tall blue-white shards of glacier ice standing out of the snowfield, between snow-capped peaks
        for i = 1, 16 do
            local a = (i / 16) * math.pi * 2 + r:NextNumber(-0.15, 0.15)
            local d = r:NextNumber(600, 1100)
            local h = r:NextNumber(200, 520)
            local w = h * r:NextNumber(0.16, 0.26)
            local at = Vector3.new(math.cos(a) * d, gy, zC + math.sin(a) * d)
            local lean = CFrame.Angles(math.rad(r:NextNumber(-8, 8)), r:NextNumber(0, math.pi), math.rad(r:NextNumber(-8, 8)))
            local cf = CFrame.new(at) * lean
            local shard = r:NextNumber() < 0.5
            -- (UPDATE 4 PROPS: a giant crystal cluster mesh, not a box + a corner-up cube tip; boxes stay as the fallback)
            local kitName = shard and "IceCrystalsB" or "IceCrystalsA"
            if EnvKit.Has("Ice", kitName) then
                EnvKit.Place("Ice", kitName, CFrame.new(at - Vector3.new(0, 10, 0)) * CFrame.Angles(0, r:NextNumber(0, 6.28), 0), { Scale = h / 8, Parent = fx, Shadow = false })
                continue
            end
            P({ Name = "IceSpire", Size = Vector3.new(w, h, w * 0.7), CFrame = cf * CFrame.new(0, h / 2 - 10, 0) * CFrame.Angles(0, math.rad(45), 0),
                Color = Color3.fromRGB(150, 196, 232), Material = Enum.Material.Glacier, Transparency = 0.06 })
            P({ Name = "IceSpireTip", Size = Vector3.new(w * 0.62, w * 0.62, w * 0.62), CFrame = cf * CFrame.new(0, h - 10, 0) * CFrame.Angles(math.rad(45), 0, math.rad(35.264)),
                Color = Color3.fromRGB(196, 230, 255), Material = Enum.Material.Ice, Transparency = 0.05 })
            if shard then -- a smaller shard leaning off it
                local h2 = h * 0.45
                P({ Name = "IceShard", Size = Vector3.new(w * 0.5, h2, w * 0.4), CFrame = cf * CFrame.new(w * 0.8, h2 / 2 - 10, 0) * CFrame.Angles(0, 0, math.rad(-14)),
                    Color = Color3.fromRGB(170, 210, 240), Material = Enum.Material.Glacier, Transparency = 0.06 })
            end
        end
        for i = 1, 10 do
            local a = (i / 10) * math.pi * 2 + r:NextNumber(-0.2, 0.2) + 0.3
            Peak(a, r:NextNumber(900, 1300), r:NextNumber(260, 480), v.Peak, v.PeakMat, true)
        end
        return
    end
    if biome == "Void" then
        -- FLOATING ISLANDS: shattered rock hanging in the void, crystals glowing on top
        for i = 1, 12 do
            local a = (i / 12) * math.pi * 2 + r:NextNumber(-0.2, 0.2)
            local d = r:NextNumber(550, 1150)
            local sz = r:NextNumber(70, 190)
            local at = Vector3.new(math.cos(a) * d, gy + r:NextNumber(90, 420), zC + math.sin(a) * d)
            local spin = CFrame.Angles(0, r:NextNumber(0, math.pi * 2), 0)
            -- (UPDATE 4 PROPS) a scanned boulder hanging point-down, violet crystal clusters on its crown, a soft glow
            if EnvKit.Has("Void", "VoidIsle") then
                EnvKit.Place("Void", "VoidIsle", CFrame.new(at + Vector3.new(0, sz * 0.12, 0)) * spin * CFrame.Angles(math.pi, 0, 0), { Scale = sz / 7.5, Parent = fx, Shadow = false })
                for k = 1, r:NextInteger(1, 3) do
                    EnvKit.Place("Void", (k % 2 == 0) and "VoidCrystalsB" or "VoidCrystalsA", CFrame.new(at + Vector3.new(r:NextNumber(-0.3, 0.3) * sz, sz * 0.08, r:NextNumber(-0.3, 0.3) * sz)) * CFrame.Angles(0, r:NextNumber(0, 6.28), 0),
                        { Scale = sz * r:NextNumber(0.04, 0.07), Parent = fx, Shadow = false })
                end
                DungeonGenerator.Lava().Glow(fx, at + Vector3.new(0, sz * 0.35, 0), sz * 0.9, v.Tip, 0.6, { Name = "IsleGlow", MaxDistance = 6000 })
                continue
            end
            -- the underside: an upside-down point (a tilted cube, corner down), a flat top slab
            P({ Name = "IslandRoot", Size = Vector3.one * sz, CFrame = CFrame.new(at - Vector3.new(0, sz * 0.38, 0)) * spin * CFrame.Angles(math.rad(45), 0, math.rad(35.264)),
                Color = v.Peak:Lerp(Color3.new(0, 0, 0), r:NextNumber(0, 0.3)), Material = Enum.Material.Slate })
            P({ Name = "IslandTop", Size = Vector3.new(sz * 1.25, sz * 0.12, sz * 1.1), CFrame = CFrame.new(at + Vector3.new(0, sz * 0.18, 0)) * spin,
                Color = Color3.fromRGB(40, 30, 56), Material = Enum.Material.Basalt })
            for k = 1, r:NextInteger(1, 3) do
                local ch = sz * r:NextNumber(0.25, 0.55)
                P({ Name = "IslandCrystal", Size = Vector3.new(ch * 0.25, ch, ch * 0.25),
                    CFrame = CFrame.new(at + Vector3.new(r:NextNumber(-0.35, 0.35) * sz, sz * 0.24 + ch / 2, r:NextNumber(-0.3, 0.3) * sz)) * CFrame.Angles(math.rad(r:NextNumber(-15, 15)), 0, math.rad(r:NextNumber(-15, 15))),
                    Color = (k % 2 == 0) and Color3.fromRGB(80, 220, 230) or v.Tip, Material = Enum.Material.Neon, Transparency = 0.15 })
            end
        end
        for i = 1, 10 do
            local a = (i / 10) * math.pi * 2 + r:NextNumber(-0.15, 0.15)
            Peak(a, r:NextNumber(800, 1250), r:NextNumber(200, 420), v.Peak, v.PeakMat, r:NextNumber() < 0.35)
        end
        return
    end
    -- (Storm) a mountain ring
    for i = 1, 18 do
        local a = (i / 18) * math.pi * 2 + r:NextNumber(-0.12, 0.12)
        local sz = r:NextNumber(220, 480)
        Peak(a, r:NextNumber(650, 1200), sz, v.Peak, v.PeakMat, sz > 330)
    end
end

-- the far landmark, seen over the rim
-- The entry room + corridor sit just outside the arena's north wall: nothing of the shell may grow into them (owner
-- 2026-10-05: "props block the entrance of all dungeons" -- the north rim's cliffs / kit filled the doorway).
-- MapShell.KeepOut = { X = half width, Z0, Z1 } (set by BuildThemedDungeon); r = the piece's reach.
local function KeptOut(p: Vector3, r: number): boolean
    local k = MapShell.KeepOut
    if k ~= nil and math.abs(p.X) < k.X + r and p.Z > k.Z0 - r and p.Z < k.Z1 + r then return true end
    -- (LINKED ROOMS pilot: the floor's other rooms + their paths keep room 1's shell out too -- MapShell.KeepOuts boxes)
    for _, b in ipairs(MapShell.KeepOuts or {}) do
        if p.X > b.X0 - r and p.X < b.X1 + r and p.Z > b.Z0 - r and p.Z < b.Z1 + r then return true end
    end
    return false
end

local HEROES = {}
function HEROES.Volcano(fx: Instance, ctx: any)
    local base = Vector3.new(ctx.half * 1.9, FLOOR_TOP, ctx.zC + ctx.half * 2.2)
    if ctx.terrain then
        local T = MapShell.T()
        for i = 0, 5 do
            T:FillBall(base + Vector3.new(0, i * 18, 0), 70 - i * 11, (i < 4) and M.Basalt or M.Rock)
        end
        T:FillCylinder(CFrame.new(base + Vector3.new(0, 104, 0)), 6, 14, M.CrackedLava)
    else
        for i = 0, 3 do
            local w = Instance.new("Part")
            w.Anchored = true; w.CanCollide = false; w.CanQuery = false; w.CastShadow = false
            w.Shape = Enum.PartType.Ball; w.Size = Vector3.one * (130 - i * 26); w.Position = base + Vector3.new(0, i * 22, 0)
            w.Color = Color3.fromRGB(40, 32, 30); w.Material = M.Basalt; w.Parent = fx
        end
    end
    -- (UPDATE 4 LAVA) the vent glows above the crater (self-lit soft glows) instead of a flat Neon disc on top; the smoke
    -- rises from an invisible host there
    local glow = Instance.new("Part")
    glow.Anchored = true; glow.CanCollide = false; glow.CanQuery = false; glow.CastShadow = false; glow.Transparency = 1
    glow.Shape = Enum.PartType.Cylinder; glow.Size = Vector3.new(1, 26, 26); glow.CFrame = CFrame.new(base + Vector3.new(0, 108, 0)) * CFrame.Angles(0, 0, math.rad(90))
    glow.Name = "VolcanoVent"; glow.Parent = fx
    local Lava = DungeonGenerator.Lava()
    Lava.Glow(fx, base + Vector3.new(0, 118, 0), 90, Color3.fromRGB(255, 96, 34), 0.4, { Name = "VentHalo", Pulse = 0.06 })
    Lava.Glow(fx, base + Vector3.new(0, 111, 0), 34, Color3.fromRGB(255, 176, 80), 0.1, { Name = "VentCore" })
    local smoke = Instance.new("ParticleEmitter")
    smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"; smoke.Color = ColorSequence.new(Color3.fromRGB(150, 74, 44), Color3.fromRGB(30, 26, 26))
    smoke.Rate = 2; smoke.Lifetime = NumberRange.new(10, 14); smoke.Speed = NumberRange.new(6, 10); smoke.Size = NumberSequence.new(14, 40)
    smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.6), NumberSequenceKeypoint.new(1, 1) })
    smoke.LightInfluence = 0.6; smoke.EmissionDirection = Enum.NormalId.Right; smoke.Parent = glow
end
function HEROES.GiantStatue(fx: Instance, ctx: any)
    EnvKit.Place("Ice", EnvKit.Has("Ice", "FrozenStatue") and "FrozenStatue" or "IceStatue", CFrame.new(-ctx.half * 1.25, FLOOR_TOP - 4, ctx.zC + ctx.half * 1.35) * CFrame.Angles(0, math.rad(150), 0), { Scale = 9, Parent = fx, Shadow = false })
end
function HEROES.FloatingRuins(fx: Instance, ctx: any)
    local r = ctx.rng
    for i = 1, 7 do
        local a = (i / 7) * math.pi * 2 + r:NextNumber(-0.3, 0.3)
        local d = ctx.half * r:NextNumber(1.35, 1.9)
        EnvKit.Place("Void", EnvKit.Has("Void", "VoidIsle") and "VoidIsle" or "FloatingRuin", CFrame.new(math.cos(a) * d, FLOOR_TOP + r:NextNumber(30, 80), ctx.zC + math.sin(a) * d) * CFrame.Angles(0, r:NextNumber(0, 6), 0),
            { Scale = r:NextNumber(2.5, 5), Parent = fx, Shadow = false })
    end
end
function HEROES.Lighthouse(fx: Instance, ctx: any)
    local pos = Vector3.new(-ctx.half * 1.45, FLOOR_TOP + 40, ctx.zC + ctx.half * 1.1)
    if ctx.terrain then
        -- a headland tall enough to lift the tower over the rim cliffs
        MapShell.T():FillBall(pos - Vector3.new(0, 30, 0), 36, M.Rock)
        MapShell.T():FillCylinder(CFrame.new(pos - Vector3.new(0, 3, 0)), 6, 14, M.Grass)
    else
        pos -= Vector3.new(0, 30, 0) -- (party floors: no headland, the tower stands on the plain)
    end
    EnvKit.Place("Storm", "Lighthouse", CFrame.new(pos), { Scale = 3.6, Parent = fx, Shadow = false })
    -- the beam: a slow sweeping cone of light (a Beam; client-only turning)
    local lamp = Instance.new("Part")
    lamp.Anchored = true; lamp.CanCollide = false; lamp.CanQuery = false; lamp.CastShadow = false
    lamp.Shape = Enum.PartType.Ball; lamp.Size = Vector3.one * 4; lamp.Position = pos + Vector3.new(0, 44, 0)
    lamp.Color = Color3.fromRGB(255, 240, 200); lamp.Material = M.Neon; lamp.Name = "LighthouseLamp"; lamp.Parent = fx
    local a0 = Instance.new("Attachment"); a0.Parent = lamp
    local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(160, -10, 0); a1.Parent = lamp
    local b = Instance.new("Beam")
    b.Attachment0, b.Attachment1 = a0, a1; b.Width0, b.Width1 = 3, 40; b.LightEmission = 1; b.FaceCamera = true
    b.Color = ColorSequence.new(Color3.fromRGB(255, 240, 200)); b.Transparency = NumberSequence.new(0.6, 1); b.Parent = lamp
    if IS_CLIENT then
        task.spawn(function()
            local t0 = os.clock()
            while lamp.Parent do
                local a = (os.clock() - t0) * 0.6
                a1.Position = Vector3.new(math.cos(a) * 160, -10, math.sin(a) * 160)
                task.wait(1 / 15) -- (15 Hz is plenty for a slow sweep)
            end
        end)
    end
end
function HEROES.Skyline(fx: Instance, ctx: any)
    -- the near ring of towers round the rooftop / data yard (CyberTower: stepped, lit, a few parts each)
    local r = ctx.rng
    for i = 1, 12 do
        local a = (i / 12) * math.pi * 2 + r:NextNumber(-0.15, 0.15)
        local d = ctx.half * r:NextNumber(1.3, 1.8)
        local h = r:NextNumber(80, 190)
        local w = r:NextNumber(18, 32)
        local foot = Vector3.new(math.cos(a) * d, FLOOR_TOP - 40, ctx.zC + math.sin(a) * d)
        if KeptOut(foot + Vector3.new(0, 40 + h / 2, 0), w * 0.75) then continue end -- (not on the entry room / corridor)
        CyberTower(fx, foot, w, h, r, 2, Vector3.new(-math.cos(a), 0, -math.sin(a)))
    end
end

-- TERRAINIFY (open maps): every solid cover / platform / pillar block inside the combat box becomes TERRAIN rock of the
-- same shape (solo floors) -- the part stays as an invisible collider, so movement and bot steering are unchanged, but
-- what you see is a rock outcrop blending into the ground instead of a box with neon trim. Neon trims are hidden. On
-- party floors (no terrain) the blocks only lose their neon trim and take the template's stone.
-- (UPDATE 4 PARTY FLOORS) the rock colour a party (server-built, no terrain) floor's cover / pillars / walls take with
-- the template stone -- the solo terrain palette's look, a touch lighter (parts get no terrain shading)
MapShell.PARTY_ROCK = { Fire = C3(78, 66, 62), Ice = C3(124, 134, 150), Void = C3(70, 60, 92), Storm = C3(92, 96, 106),
    Dream = C3(186, 170, 220), Flats = C3(146, 84, 78) }
-- (on TERRAIN maps the cover stone sits beside terrain rock, which renders lighter than a part of the same colour:
-- Molten's walls read as black blocks -- the stone goes a value step up and on Slate, the Basalt scan's dark plates
-- swallowed it)
MapShell.TERRAIN_LIFT = { Fire = 1.6 }
MapShell.TERRAIN_STONE = { Fire = M.Slate }
-- the ground rock's colour for a biome's cover stone (a world's own terrain palette, else the table above)
function MapShell.RockColor(biome: string?, mat: Enum.Material): Color3?
    if not biome then return nil end
    if MapShell.WB == nil then
        local ok, wb = pcall(function() return require(script.Parent:WaitForChild("WorldBiomes")) end)
        MapShell.WB = ok and wb or false
    end
    local w = MapShell.WB and MapShell.WB.Terrain[biome]
    if w then return w[mat] or w[M.Rock] or w[M.Slate] end
    return MapShell.PARTY_ROCK[biome]
end
-- one solid cover block as terrain of the same shape (filled a little UNDER its collider; see Terrainify)
function MapShell.FillPart(p: BasePart, mat: Enum.Material)
    local T = MapShell.T()
    local shape = p:IsA("Part") and (p :: Part).Shape or nil
    if p:IsA("WedgePart") then
        T:FillWedge(p.CFrame, p.Size, mat)
    elseif shape == Enum.PartType.Ball then
        T:FillBall(p.Position, p.Size.X / 2, mat)
    elseif shape == Enum.PartType.Cylinder then
        T:FillCylinder(p.CFrame * CFrame.Angles(0, 0, math.rad(90)), p.Size.X, p.Size.Y / 2, mat)
    else
        T:FillBlock(p.CFrame, p.Size - Vector3.new(1.2, 0.6, 1.2), mat)
    end
end
-- (BOTFIX 2026-10-24, owner: bots "like stuck in terrain") the rims (cliff balls + slabs 8-24 studs out, up to 16 across) and
-- the banks' broken skyline (balls up to 11 past the gap) reached up to ~10 studs INTO the rooms, and bots steer round
-- StaticGeometry only -- terrain has no collider -- so they flew / walked into that rock and hung there, half inside it.
-- After the world is built: the room's interior above the floor is cleared, then its own rock cover (the parts Terrainify
-- tagged TFill) is filled back. The rock now stops at the room's (invisible) walls; the bots' leash is BOX_INSET inside them.
function MapShell.ClearInterior(geo: Instance, xC: number, zC: number, half: number)
    local T = Workspace.Terrain
    local H = 90
    T:FillBlock(CFrame.new(xC, FLOOR_TOP + 1 + H / 2, zC), Vector3.new(half * 2, H, half * 2), M.Air)
    for _, p in ipairs(geo:GetDescendants()) do
        local m = p:IsA("BasePart") and p:GetAttribute("TFill")
        if m and math.abs(p.Position.X - xC) < half + 1 and math.abs(p.Position.Z - zC) < half + 1 then
            local ok, mat = pcall(function() return (Enum.Material :: any)[m] end)
            if ok and mat then MapShell.FillPart(p, mat) end
        end
    end
end
-- FLUSH GROUND (MAPVIBE 2026-10-25, owner: "Yes you can fix" = maplook not-done #2). The open floor's terrain ground is a
-- FillBlock y -4.05 .. 1.95, so the voxel cell y 0..4 sits at occupancy ~0.49 and Roblox renders it lumpy at ~y 3.9 (the
-- "crumpled foil", ~12 deg average tilt, ~2 studs over the floor part bots walk on). Measured (WriteVoxels test): with the
-- cells below y 0 full, the surface = ~1.95 + 4 x the y 0..4 occupancy -> 0 gives a flat ground at y 1.9-2.0 (tilt 2.4 deg)
-- flush with FLOOR_TOP. After ClearInterior / CarveFaces, over every room box + the walk boxes of the paths: a column whose
-- y -4..0 cell is solid, y 0..4 partial (< 0.75) and y 4..8 empty (= plain ground, not cover / rim rock) gets y 0..4 set
-- to air and its material copied down into y -4..0 (patch colours kept). Columns under a Terrainify'd cover piece (TFill)
-- are never touched (a low block / wedge ramp lives in that cell). No rng draw, no collider change. Studio A/B: workspace
-- attr DevFlushOff = true keeps the old raised ground.
function MapShell.FlushOn(): boolean
    return not (game:GetService("RunService"):IsStudio() and Workspace:GetAttribute("DevFlushOff") == true)
end
-- boxes = { { x0, x1, z0, z1 } }; geo = StaticGeometry (TFill cover footprints are protected). Returns columns flattened.
function MapShell.FlushGround(boxes: { any }, geo: Instance): number
    local T = Workspace.Terrain
    local guard = {}
    for _, p in ipairs(geo:GetDescendants()) do
        if p:IsA("BasePart") and p:GetAttribute("TFill") then
            local cf, s = p.CFrame, p.Size / 2
            local ex = math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z
            local ez = math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
            table.insert(guard, { p.Position.X - ex - 2, p.Position.X + ex + 2, p.Position.Z - ez - 2, p.Position.Z + ez + 2 })
        end
    end
    local n = 0
    for _, b in ipairs(boxes) do
        local reg = Region3.new(Vector3.new(b[1], -4, b[3]), Vector3.new(b[2], 8, b[4])):ExpandToGrid(4)
        local mats, occ = T:ReadVoxels(reg, 4)
        local sz = mats.Size
        if sz.Y >= 3 then
            local lo = reg.CFrame.Position - reg.Size / 2
            local y0 = math.floor((-4 - lo.Y) / 4 + 0.5) + 1 -- (the y -4..0 layer)
            local changed = false
            for i = 1, sz.X do
                local cx = lo.X + (i - 0.5) * 4
                for k = 1, sz.Z do
                    local cz = lo.Z + (k - 0.5) * 4
                    local m1, m2, m3 = mats[i][y0][k], mats[i][y0 + 1][k], mats[i][y0 + 2] and mats[i][y0 + 2][k]
                    local o1, o2, o3 = occ[i][y0][k], occ[i][y0 + 1][k], (occ[i][y0 + 2] and occ[i][y0 + 2][k]) or 0
                    if m1 ~= M.Air and m1 ~= M.Water and o1 > 0.9 and o2 > 0 and o2 < 0.75 and m2 ~= M.Water
                        and (m3 == nil or m3 == M.Air or o3 < 0.02) then
                        local hit = false
                        for _, g in ipairs(guard) do
                            if cx > g[1] and cx < g[2] and cz > g[3] and cz < g[4] then hit = true; break end
                        end
                        if not hit then
                            if m2 ~= M.Air then mats[i][y0][k] = m2 end
                            mats[i][y0 + 1][k] = M.Air
                            occ[i][y0 + 1][k] = 0
                            changed = true
                            n += 1
                        end
                    end
                end
            end
            if changed then T:WriteVoxels(reg, 4, mats, occ) end
        end
    end
    return n
end

-- ==================== MAPLOOK (2026-10-24) ====================
-- (owner: "continue to improve the look of the hub and maps? Right now they still feel kind of scuffed and unprofessional" +
-- "a part of the problem is using copy and paste items within the maps"; docs/MAPLOOK_2026-10-24.md). Pure scenery: no
-- collider, room box, path, cover, spawn spot or sight line changes. Studio A/B: workspace attr DevMapLookOff = true builds
-- the old look on the same seed.
--   FACES: ClearInterior (BOTFIX) and the dogleg banks left every room wall as a flat vertical rock plane with a flat top
--     edge (the banks are one big box). MapShell.CarveFaces leans each wall face back (a terrain wedge of AIR outside the
--     wall, in segments with their own start height / lean) and bites scallops out of it -- only OUTSIDE the walls, never
--     inside a room; the band of rock that hides the next room (the leg of every dogleg + Pad) is only notched (Notch studs
--     deep of its 6) and gets a crest of boulders on its flat top, so nothing new can be seen through it (measured: the same
--     clear sight rays between rooms before / after). Big rim hills get slabs on their crowns (MapShell.Craggy).
--   NEW ROCKS: 7 new Poly Haven CC0 rock scans (EnvKit.Rocks, MapShell.ROCKS) swapped in for a share of the rim pieces.
--   PATCHES: ground patches were rotated FillBlocks = rectangles with ruler-straight edges on every floor -> stadium shapes
--     from discs (MapShell.Patch, the same rng draws and height).
--   VARIATION: rim kit pieces were the same few models at the same scale every ~12 studs round every room ("copy and
--     paste"). MapShell.RimPiece (its own seeded stream, the map rng is untouched): one in five thinned out, a repeat of the
--     piece just placed on that side mostly dropped, the rest scaled (a quarter of them big anchors), leaned and sunk into
--     the ground, every piece its own tint. Gameplay pieces (edge dressing / scatter with hitboxes) only take the tint.
MapShell.OUT = { Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, 0, 1) } -- (RimPoint sides 1..4 = W E N S)
MapShell.FACE = { From = { 4, 9 }, Lean = { 0.2, 0.42 }, Top = 64, Seg = { 9, 18 }, Pad = 6, Notch = 2.4 }
function MapShell.LookOn(): boolean
    return not (game:GetService("RunService"):IsStudio() and Workspace:GetAttribute("DevMapLookOff") == true)
end
-- rooms = { { Index, X, Z, Half, Skip = { N = true } } }, paths = LinkedRooms paths (or {}), vr = a seeded Random
function MapShell.CarveFaces(rooms: { any }, paths: { any }, vr: Random)
    local T = Workspace.Terrain
    local C = MapShell.FACE
    local F = FLOOR_TOP
    local up = Vector3.yAxis
    local SIDES = { N = Vector3.new(0, 0, -1), S = Vector3.new(0, 0, 1), W = Vector3.new(-1, 0, 0), E = Vector3.new(1, 0, 0) }
    local BAND = (DungeonGenerator.LR and DungeonGenerator.LR.BAND) or 6
    for _, r in ipairs(rooms) do
        for _, key in ipairs({ "N", "S", "W", "E" }) do
            if not (r.Skip and r.Skip[key]) then
                local n = SIDES[key]
                local alongX = (key == "N" or key == "S")
                local t = alongX and Vector3.xAxis or Vector3.zAxis
                local c0 = alongX and r.X or r.Z
                local w0 = Vector3.new(r.X, F, r.Z) + n * r.Half -- (the wall line's middle at floor height)
                -- the dogleg legs leaving through this wall (+ Pad): the rock band there hides the next room -> notches only
                local excl = {}
                for _, p in ipairs(paths) do
                    local side
                    if p.Axis == "Z" then
                        if p.A == r.Index then side = "S" elseif p.B == r.Index then side = "N" end
                    else
                        if p.A == r.Index then side = (p.Dir > 0) and "E" or "W" elseif p.B == r.Index then side = (p.Dir > 0) and "W" or "E" end
                    end
                    if side == key then
                        table.insert(excl, { p.V0 + math.min(0, p.Off) - p.W / 2 - C.Pad - c0, p.V0 + math.max(0, p.Off) + p.W / 2 + C.Pad - c0 })
                    end
                end
                table.sort(excl, function(a, b) return a[1] < b[1] end)
                local free, cur = {}, -r.Half - C.Pad
                for _, e in ipairs(excl) do
                    if e[1] > cur then table.insert(free, { cur, e[1] }) end
                    cur = math.max(cur, e[2])
                end
                if cur < r.Half + C.Pad then table.insert(free, { cur, r.Half + C.Pad }) end
                for _, iv in ipairs(free) do
                    local a = iv[1]
                    while a < iv[2] - 2 do
                        local b = math.min(iv[2], a + vr:NextNumber(C.Seg[1], C.Seg[2]))
                        if iv[2] - b < 4 then b = iv[2] end
                        local len = b - a
                        local y0, y1 = F + vr:NextNumber(C.From[1], C.From[2]), F + C.Top
                        local h = y1 - y0
                        local lean = vr:NextNumber(C.Lean[1], C.Lean[2])
                        local depth = h * lean
                        -- a wedge of air: right angle at the wall line up top, down to y0 at the wall, out to `depth` at the top
                        -- (WedgePart space: +Y = world down, -Z = outward)
                        local p0 = w0 + t * ((a + b) / 2) + up * (y1 - F)
                        local Y, Z = -up, -n
                        T:FillWedge(CFrame.fromMatrix(p0 + n * (depth / 2) - up * (h / 2), Y:Cross(Z), Y, Z), Vector3.new(len + 0.6, h, depth), M.Air)
                        -- scallops bitten out of the leaning face (never reaching back over the wall line)
                        for _ = 1, math.max(1, math.floor(len / 6)) do
                            local rr = vr:NextNumber(2.5, 5.5)
                            local y = vr:NextNumber(y0 + rr * 0.5, y1 - 8)
                            local s = (y - y0) * lean
                            local u = math.max(s + rr * 0.3, rr + 0.4)
                            T:FillBall(w0 + t * vr:NextNumber(a, b) + up * (y - F) + n * u, rr, M.Air)
                        end
                        a = b
                    end
                end
                for _, e in ipairs(excl) do
                    local a, b = math.max(e[1], -r.Half), math.min(e[2], r.Half)
                    local tt = a + 2
                    while tt < b - 2 do
                        if vr:NextNumber() < 0.65 then
                            local rr = vr:NextNumber(2.4, 3.4)
                            local y = vr:NextNumber(F + 8, F + 30)
                            T:FillBall(w0 + t * (tt + vr:NextNumber(-1, 1)) + up * (y - F) + n * (C.Notch - rr), rr, M.Air)
                        end
                        tt += vr:NextNumber(3.5, 5.5)
                    end
                    -- the band's top was ruler-flat (the bank's skyline boulders keep clear of the walk path): a crest of boulders
                    -- sitting ON the band (centred over its middle, high above any head or flier), the rim's own stone
                    tt = a + vr:NextNumber(1, 4)
                    while tt < b - 1 do
                        local c = w0 + t * tt + n * (BAND / 2)
                        local top = MapShell.TopAt(c)
                        if top and top > F + 14 then
                            local rr = vr:NextNumber(2.8, 4.3)
                            local bc = Vector3.new(c.X, top + rr * vr:NextNumber(0.05, 0.35), c.Z) + t * vr:NextNumber(-1, 1)
                            -- (RUNFIX 2026-10-25) never over a doorway slot / the path (bots fly through there)
                            local clear = true
                            for _, p in ipairs(paths) do
                                if DungeonGenerator.LR and DungeonGenerator.LR.InBoxes(DungeonGenerator.LR.PathBoxes(p, rr + 1.5, 0), bc, 0) then clear = false; break end
                            end
                            if clear then T:FillBall(bc, rr, r.Mat or M.Rock) end
                        end
                        tt += vr:NextNumber(4.5, 7.5)
                    end
                end
                -- the doorways' top corners rounded off (they were the hard corners of a box)
                for _, p in ipairs(paths) do
                    local vd
                    if p.Axis == "Z" then
                        if p.A == r.Index and key == "S" then vd = p.V0 elseif p.B == r.Index and key == "N" then vd = p.V0 + p.Off end
                    else
                        local aSide = (p.Dir > 0) and "E" or "W"
                        if p.A == r.Index and key == aSide then vd = p.V0 elseif p.B == r.Index and key ~= aSide and (key == "E" or key == "W") then vd = p.V0 + p.Off end
                    end
                    if vd then
                        for _, s in ipairs({ -1, 1 }) do
                            local c = w0 + t * (vd - c0 + s * (p.W / 2 + 1.5)) + n * (BAND / 2)
                            local top = MapShell.TopAt(c)
                            if top and top > F + 18 then
                                T:FillBall(Vector3.new(c.X, top - 1, c.Z), vr:NextNumber(3.5, 5), M.Air)
                            end
                        end
                    end
                end
            end
        end
    end
end
-- a big rim hill ball was a bald dome on the skyline: a few tilted slabs and a knuckle of rock break its crown (terrain, its
-- own stream; kept(p, r) = true where nothing may grow -- KeptOut / the linked rooms' Free)
function MapShell.Craggy(c: Vector3, r: number, mat: Enum.Material, vr: Random?, kept: ((Vector3, number) -> boolean)?)
    if not vr or not MapShell.LookOn() or not MapShell.Full() then return end -- (PARTY TWIN: a mirror draws the same)
    local T = MapShell.T()
    for _ = 1, vr:NextInteger(2, 4) do
        local a = vr:NextNumber(0, math.pi * 2)
        local up = vr:NextNumber(0.35, 0.95)
        local dir = Vector3.new(math.cos(a) * math.sqrt(1 - up * up), up, math.sin(a) * math.sqrt(1 - up * up))
        local p = c + dir * r * vr:NextNumber(0.72, 0.9)
        local sz = Vector3.new(r * vr:NextNumber(0.3, 0.55), r * vr:NextNumber(0.45, 0.85), r * vr:NextNumber(0.2, 0.4))
        if not (kept and kept(p, math.max(sz.X, sz.Y) * 0.6)) then
            if vr:NextNumber() < 0.7 then
                T:FillBlock(CFrame.new(p) * CFrame.Angles(vr:NextNumber(-0.5, 0.5), vr:NextNumber(0, 3.14), vr:NextNumber(-0.5, 0.5)), sz, mat)
            else
                T:FillBall(p, sz.X * 0.8, mat)
            end
        end
    end
end
-- the top of the terrain column over p (voxel read: same-frame fills are there, raycasts don't see them yet), nil = none
function MapShell.TopAt(p: Vector3): number?
    local reg = Region3.new(Vector3.new(p.X - 1, FLOOR_TOP, p.Z - 1), Vector3.new(p.X + 1, FLOOR_TOP + 72, p.Z + 1)):ExpandToGrid(4)
    local mats, occ = Workspace.Terrain:ReadVoxels(reg, 4)
    local y0 = reg.CFrame.Position.Y - reg.Size.Y / 2
    local top = nil
    for y = 1, occ.Size.Y do
        if mats[1][y][1] ~= M.Air and occ[1][y][1] > 0.5 then top = y0 + (y - 1) * 4 + occ[1][y][1] * 4 end
    end
    return top
end
-- a ground patch as a stadium of discs (was a rotated block: ruler-straight edges)
function MapShell.Patch(cf: CFrame, size: Vector3, mat: Enum.Material)
    local T = MapShell.T()
    if not MapShell.LookOn() then T:FillBlock(cf, size, mat); return end
    local long, short = math.max(size.X, size.Z), math.min(size.X, size.Z)
    local axis = (size.X >= size.Z) and cf.RightVector or cf.LookVector
    local off = (long - short) / 2
    T:FillCylinder(CFrame.new(cf.Position), size.Y, short / 2 + 0.6, mat)
    if off > 1 then
        for _, s in ipairs({ -1, 1 }) do
            T:FillCylinder(CFrame.new(cf.Position + axis * (s * off * 0.95)), size.Y, short / 2 * 0.9, mat)
        end
    end
end
function MapShell.Jitter(c: Color3, k: number, dh: number): Color3
    local h, s, v = c:ToHSV()
    return Color3.fromHSV((h + dh) % 1, s, math.clamp(v * k, 0, 1))
end
-- one placed kit piece's own look: always its own tint; mode "Rim" (scenery outside the walls, no hitbox) also a scale, a
-- lean and a sink into the ground. Never call "Rim" on a piece with a hitbox (the box was measured at placement).
function MapShell.Vary(inst: Instance?, vr: Random, mode: string)
    if not inst or not inst.Parent or not MapShell.LookOn() then return end
    local k, dh = vr:NextNumber(0.84, 1.1), vr:NextNumber(-0.014, 0.014)
    local list = {}
    if inst:IsA("BasePart") then table.insert(list, inst) end
    for _, d in ipairs(inst:GetDescendants()) do if d:IsA("BasePart") then table.insert(list, d) end end
    for _, d in ipairs(list) do
        if d.Material ~= Enum.Material.Neon and d.Transparency < 0.9 then
            local sa = d:FindFirstChildOfClass("SurfaceAppearance")
            if sa then sa.Color = MapShell.Jitter(sa.Color, k, dh) else d.Color = MapShell.Jitter(d.Color, k, dh) end
        end
    end
    if mode == "Rim" and inst:IsA("Model") and #list > 0 then
        local m = inst :: Model
        local s = (vr:NextNumber() < 0.25) and vr:NextNumber(1.12, 1.3) or vr:NextNumber(0.72, 1.02)
        pcall(function() m:ScaleTo(m:GetScale() * s) end)
        local _, sz = m:GetBoundingBox()
        local a = vr:NextNumber(0, math.pi * 2)
        local lean = CFrame.fromAxisAngle(Vector3.new(math.cos(a), 0, math.sin(a)), math.rad(vr:NextNumber(2, 8)))
        local pv = m:GetPivot()
        m:PivotTo(CFrame.new(pv.Position - Vector3.new(0, sz.Y * vr:NextNumber(0.03, 0.12), 0)) * lean * pv.Rotation)
    end
end
-- NEW rock scans (MAPLOOK, owner: "couldn't we add new models too"): EnvKit.Rocks (tools/biome_mesh_import.py "Rocks/..."),
-- swapped in for some rim pieces. Flat = a low spread of rocks stood up on edge as a leaning slab. Scale = kit scale range.
MapShell.ROCKS = {
    { Name = "CliffShardA", Scale = { 0.55, 0.9 } }, { Name = "CliffShardB", Scale = { 0.55, 0.85 }, Flat = true },
    { Name = "BoulderC", Scale = { 0.7, 1.15 } }, { Name = "BoulderD", Scale = { 0.65, 1.05 } },
    { Name = "RockStackA", Scale = { 0.5, 0.8 }, Flat = true }, { Name = "PitRockA", Scale = { 0.8, 1.3 } },
    { Name = "LedgeRockA", Scale = { 0.55, 0.85 }, Flat = true },
}
MapShell.ROCK_SWAP = 0.35 -- (share of the kept rim pieces that become one of the new rocks; a dropped repeat may too)
-- one of the new rocks at pos, pushed out past the wall (out = the wall's outward normal): nothing of it reaches a room
function MapShell.RockAt(parent: Instance, pos: Vector3, out: Vector3?, vr: Random): Instance?
    if not EnvKit.Has("Rocks", "BoulderC") then return nil end
    local spec = MapShell.ROCKS[vr:NextInteger(1, #MapShell.ROCKS)]
    if not EnvKit.Has("Rocks", spec.Name) then return nil end
    local s = vr:NextNumber(spec.Scale[1], spec.Scale[2])
    local yaw = CFrame.Angles(0, vr:NextNumber(0, math.pi * 2), 0)
    local rot = yaw
    if spec.Flat then -- (stood on edge, leaning, half buried: a shard / slab)
        rot = yaw * CFrame.Angles(math.rad(vr:NextNumber(58, 78)), 0, math.rad(vr:NextNumber(-12, 12)))
    end
    local m = EnvKit.Place("Rocks", spec.Name, CFrame.new(pos) * rot, { Scale = s, Parent = parent, Shadow = false, Tint = MapShell.RockTint })
    if not m or not m:IsA("Model") then return m end
    local cf, sz = (m :: Model):GetBoundingBox()
    local push = out and math.max(0, math.max(sz.X, sz.Z) / 2 - 2) or 0
    local sink = spec.Flat and sz.Y * vr:NextNumber(0.3, 0.42) or sz.Y * vr:NextNumber(0.1, 0.22)
    local lift = (pos.Y - (cf.Position.Y - sz.Y / 2)) - sink
    ;(m :: Model):PivotTo((m :: Model):GetPivot() + (out or Vector3.zero) * push + Vector3.new(0, lift, 0))
    m:SetAttribute("NewRock", true)
    MapShell.Vary(m, vr, "Tint")
    return m
end
-- a rim kit piece just placed (ShellPlace's result): thin out / drop repeats / swap for a new rock / vary. key = which run of
-- pieces (a side), out = that side's outward normal.
function MapShell.RimPiece(inst: Instance?, vr: Random?, key: string, out: Vector3?)
    if not inst or not vr or not MapShell.LookOn() then return end
    MapShell.RimLast = MapShell.RimLast or {}
    local pos = inst:IsA("Model") and (inst :: Model):GetPivot().Position or (inst :: BasePart).Position
    local last = MapShell.RimLast[key]
    local dup = last ~= nil and last.Name == inst.Name and (last.Pos - pos).Magnitude < 28
    local thin, drop, swap = vr:NextNumber(), vr:NextNumber(), vr:NextNumber()
    local hasParts = #inst:GetDescendants() > 0 -- (a terrain Outcrop is an empty model: its rock can't be taken back)
    if hasParts and thin < 0.2 then inst:Destroy(); return end
    if hasParts and (swap < MapShell.ROCK_SWAP or (dup and drop < 0.6)) then
        local parent = inst.Parent
        inst:Destroy()
        if parent and (not dup or drop < 0.3) then
            local r = MapShell.RockAt(parent, Vector3.new(pos.X, FLOOR_TOP, pos.Z), out, vr)
            if r then MapShell.RimLast[key] = { Name = r.Name, Pos = pos } end
        end
        return
    end
    MapShell.Vary(inst, vr, "Rim")
    MapShell.RimLast[key] = { Name = inst.Name, Pos = pos }
end
function MapShell.Terrainify(geo: Instance, zC: number, half: number, mat: Enum.Material, terrain: boolean, biome: string?)
    local rock = MapShell.RockColor(biome, mat)
    local lift = terrain and biome and MapShell.TERRAIN_LIFT[biome] or 1
    local stone = terrain and biome and MapShell.TERRAIN_STONE[biome]
    local function Tone(p: BasePart) -- (UPDATE 4 COVER: RoomGen stone takes the ground rock x its own shade, any open map)
        local k = p:GetAttribute("Shade")
        if k then k *= lift end
        if stone and k then p.Material = stone end
        if rock and k then
            p.Color = Color3.new(math.clamp(rock.R * k, 0, 1), math.clamp(rock.G * k, 0, 1), math.clamp(rock.B * k, 0, 1))
        elseif rock and not terrain then
            p.Color = rock:Lerp(p.Color, 0.15)
        end
    end
    for _, p in ipairs(geo:GetDescendants()) do
        if p:IsA("BasePart") and p.Transparency < 0.5 and p.Name ~= "SkyLid" and not string.find(p.Name, "JumpPad") and not p:GetAttribute("WP") then -- (0.87: world pieces keep their own look)
            local pos = p.Position
            local inside = math.abs(pos.X) < half + 1 and math.abs(pos.Z - zC) < half + 1
            if inside then
                if p.Material == Enum.Material.Neon then
                    p.Transparency = 1 -- (the neon accent bands / trims)
                elseif p:GetAttribute("Keep") then
                    -- (UPDATE 4 COVER: timber / tech dressing keeps its own wood and metal)
                elseif terrain and p:GetAttribute("RockTrim") then
                    p.Transparency = 1 -- (0.86 RoomGen: bands / caps on a piece that is rock now)
                    p.CanCollide = false
                elseif p.CanCollide and p.Size.Y >= 1.5 and p.Size.X > 0.9 and p.Size.Z > 0.9 then
                    -- (terrain is 4-stud voxels: a thin panel turned to rock bulges past its collider and enemies seem to
                    -- glide through the rock -- owner 2026-10-05 "some mobs still glitch through terrain". Thin pieces
                    -- stay parts in the template stone; solid blocks are filled a little UNDER their collider.)
                    local thin = math.min(p.Size.X, p.Size.Z) < 5
                    if terrain and not thin then
                        MapShell.FillPart(p, mat)
                        p:SetAttribute("TFill", mat.Name) -- (BOTFIX: MapShell.ClearInterior re-fills it)
                        p.Transparency = 1
                        p.CastShadow = false
                    else
                        p.Material = mat
                        Tone(p)
                    end
                elseif p:GetAttribute("Shade") then -- (capstones, dressing stones, rubble: the same stone)
                    p.Material = mat
                    Tone(p)
                end
            end
        end
    end
end

-- ==================== PROP SETS (MAPVIBE 2026-10-25) ====================
-- (owner: "The maps literally just copy and paste the same few props around. It looks bad and lazy.") The props INSIDE the
-- rooms (edge dressing along the walls + the mid-room scatter, room 1 and every linked room) drew from the template's Edge
-- list = 2-5 models for 18-28 placements a floor. Now every placement picks from the biome's whole PROP POOL -- all its
-- templates' Edge kits + MapShell.PROPS (NEW Poly Haven CC0 models in EnvKit.Props, tools/biome_mesh_import.py "Props/..."),
-- and composes SET PIECES: a big anchor with a mid piece and small clutter at its foot (a forge yard of barrels, tools and
-- sacks; a fallen idol with offerings; a dumped car with tyres and cans). NO-REPEAT rules (MapShell.PROP_RULE): the same
-- model never within Gap studs of itself, at most PerRoom of one model in a room, the least-used allowed model wins ties.
-- FEWER, BETTER: a share of the wall spots stays empty (Skip). The map rng draws exactly what it drew before (spot, kit index,
-- scale, yaw): the choice + the set piece run on MapShell.VR. Anchors / mids keep a hitbox (bots steer round them, shots stop);
-- smalls are under ~2 studs and have none. Spots never moved, so aim lanes / sight lines are what they were. Studio A/B:
-- workspace attr DevPropsOff = true = the old picks.
-- Pools: A = anchors (cover size), M = mids (crate / barrel size, hitbox), S = smalls (clutter, no hitbox); "Set/Name" = an
-- EnvKit model, a bare name = a ShellPlace kit (template Edge kits join A by themselves). Giant = scale for the DREAM biome's
-- outsized everyday objects. Tint = the biome's multiplier on each prop's own tint.
MapShell.PROPS = {
    Fire = { A = { "Props/BarrelStove", "Props/Compressor" }, M = { "Props/WBarrel", "Props/MilCrate", "Props/CementSack", "Props/BarrelStaves", "Rocks/PitRockA" },
        S = { "Props/Sledge", "Props/Pick", "Props/Jerrycan", "Props/Bucket" }, Tint = Color3.fromRGB(156, 134, 122) },
    Ice = { A = { "Props/DeadLog", "Props/Bust", "Props/PineRoots" }, M = { "Props/Crate", "Props/MoonRockB", "Props/WBarrel", "Props/MilCrate" },
        S = { "Props/Lantern", "Props/Shield", "Props/Basket", "Props/Bucket" }, Tint = Color3.fromRGB(206, 220, 240) },
    Void = { A = { "Props/LionHead", "Props/BullHead", "Props/RootCluster" }, M = { "Props/HorseHead", "Props/Vase", "Props/MoonRockB", "Props/Bust" },
        S = { "Props/Root", "Props/MoonRockC", "Props/Shield", "Props/Lantern" }, Tint = Color3.fromRGB(176, 160, 214) },
    Cyber = { A = { "Props/Barrier", "Props/Compressor", "Props/BarrierB" }, M = { "Props/TrashCan", "Props/LpgTank", "Props/Hydrant", "Props/PlasticCrate" },
        S = { "Props/Tyre", "Props/Trashbag", "Props/Cardboard", "Props/Propane" }, Tint = Color3.fromRGB(186, 196, 214) },
    Storm = { A = { "Props/Buoy", "Props/SeaMarker", "Props/Compressor", "Props/DeadLog" }, M = { "Props/WBarrel", "Props/Crate", "Props/MossRock", "Props/BarrelStaves" },
        S = { "Props/Lifebuoy", "Props/Bucket", "Props/Lantern", "Props/Basket" }, Tint = Color3.fromRGB(190, 196, 206) },
    Flats = { A = { "Props/CoveredCar", "Props/BarrierB", "Props/Barrier" }, M = { "Props/TrashCan", "Props/LpgTank", "Props/Tyre", "Props/WBarrel" },
        S = { "Props/JerrycanG", "Props/Propane", "Props/Trashbag", "Props/Cardboard" }, Tint = Color3.fromRGB(196, 168, 156) },
    Dream = { A = { "Props/Teapot", "Props/AlarmClock", "Props/ChessKing", "Props/Suitcase" }, M = { "Props/TeaCup", "Props/ChessRook", "Props/PocketWatch" },
        S = { "Props/Basket", "Props/Lantern", "Props/Vase" }, Tint = Color3.fromRGB(236, 222, 250) },
    -- the 12 worlds by family (their own kits join A from their templates)
    Ruin = { A = { "Props/LionHead", "Props/Bust", "Props/BoulderE" }, M = { "Props/Vase", "Props/MossRock", "Props/HorseHead" },
        S = { "Props/Root", "Props/Basket", "Props/MoonRockC" } },
    Farm = { A = { "Props/DeadLog", "Props/WBarrel" }, M = { "Props/Crate", "Props/BarrelStaves", "Props/MossRock" }, S = { "Props/Bucket", "Props/Basket", "Props/Pick", "Props/Lantern" } },
    Industrial = { A = { "Props/Compressor", "Props/Barrier", "Props/LpgTank" }, M = { "Props/TrashCan", "Props/MilCrate", "Props/WBarrel", "Props/BarrierB" },
        S = { "Props/Jerrycan", "Props/Tyre", "Props/Propane", "Props/Cardboard" } },
    Nature = { A = { "Props/RootCluster", "Props/BoulderE", "Props/DeadLog" }, M = { "Props/MoonRockB", "Props/MossRock", "Props/PineRoots" }, S = { "Props/Root", "Props/MoonRockC" } },
    Sea = { A = { "Props/Buoy", "Props/SeaMarker", "Props/RootCluster" }, M = { "Props/MoonRockB", "Props/WBarrel", "Props/BarrelStaves" }, S = { "Props/Lifebuoy", "Props/Bucket", "Props/MoonRockC" } },
    -- (hubfix 2026-10-25: Fungal's own row -- the Nature family's untinted scans read as pale tan planks and pale rocks on the
    -- dark spore floor; same picks, mossy ones first, a dark violet-grey multiplier)
    Fungal = { A = { "Props/RootCluster", "Props/DeadLog", "Props/BoulderE" }, M = { "Props/MossRock", "Props/PineRoots", "Props/MoonRockB" },
        S = { "Props/Root", "Props/MoonRockC" }, Tint = Color3.fromRGB(110, 100, 125) },
    Swamp = { A = { "Props/DeadLog", "Props/RootCluster" }, M = { "Props/WBarrel", "Props/Crate", "Props/BarrelStaves" }, S = { "Props/Bucket", "Props/Lantern", "Props/Basket", "Props/Root" } },
}
MapShell.PROP_FAMILY = { Jungle = "Ruin", Aztec = "Ruin", Desert = "Ruin", Gothic = "Ruin", Sakura = "Ruin", Autumn = "Farm",
    Station = "Industrial", Waste = "Industrial", Sky = "Industrial", Fungal = "Nature", Abyss = "Sea", Bayou = "Swamp" }
MapShell.PROP_RULE = { Gap = 32, PerRoom = { A = 3, M = 3, S = 5 }, Cluster = 0.45, Row = 0.25, Skip = 0.2, Giant = { Dream = 1 },
    Bays = { -0.74, -0.38, 0.38, 0.74 }, Inner = 0.65 }
-- (pass 3, owner: rooms "look only half completed": random sides + a 20% bare roll dressed one wall and left the next bare.
-- Now MapShell.DressWalls dresses EVERY wall of every room the same way, in fixed bays -- the corners always, the inner bays
-- most of the time; what stands there varies, whether something does doesn't. Doorways keep their pair, the centre nothing.)
MapShell.BAYS = { -0.78, -0.52, -0.26, 0.26, 0.52, 0.78 } -- (stations along a wall, x the room's half: props stand in bays, never anywhere)
function MapShell.Bay(t: number): number
    local best, bd = 0, math.huge
    for _, b in ipairs(MapShell.BAYS) do if math.abs(b - t) < bd then best, bd = b, math.abs(b - t) end end
    return best
end
function MapShell.PropsOn(): boolean
    return not (game:GetService("RunService"):IsStudio() and Workspace:GetAttribute("DevPropsOff") == true)
end
-- this floor's pool (cached per biome + template): { A = { names }, M, S, Tint }
function MapShell.PropPool(biome: string, tpl: any): any
    MapShell.PoolCache = MapShell.PoolCache or {}
    local key = biome .. "|" .. tostring(tpl and tpl.Name)
    if MapShell.PoolCache[key] then return MapShell.PoolCache[key] end
    local base = MapShell.PROPS[biome] or MapShell.PROPS[MapShell.PROP_FAMILY[biome] or ""] or {}
    local pool = { A = {}, M = {}, S = {}, Tint = base.Tint }
    local seen = {}
    local function Add(role: string, name: string)
        if seen[name] then return end
        local set, nm = string.match(name, "^(.-)/(.+)$")
        if set and not EnvKit.Has(set, nm) then return end -- (a model not in this place yet: never a fallback block)
        seen[name] = true
        table.insert(pool[role], name)
    end
    if tpl and tpl.Edge then for _, k in ipairs(tpl.Edge) do Add("A", k) end end -- (this template's own first)
    for _, t in ipairs(MapShell.TEMPLATES[biome] or {}) do
        if t.Edge and not t.Parts == not (tpl and tpl.Parts) then for _, k in ipairs(t.Edge) do Add("A", k) end end
    end
    for _, role in ipairs({ "A", "M", "S" }) do for _, n in ipairs(base[role] or {}) do Add(role, n) end end
    MapShell.PoolCache[key] = pool
    return pool
end
-- pick a model of `role` allowed at pos in room `rk` (no-repeat rules), or nil
function MapShell.PickProp(pool: any, role: string, pos: Vector3, rk: string, vr: Random, filter: ((string) -> boolean)?): string?
    local R = MapShell.PROP_RULE
    MapShell.PropUse = MapShell.PropUse or {}
    local U = MapShell.PropUse
    local best, bestN = {}, math.huge
    for _, name in ipairs(pool[role] or {}) do
        if filter and not filter(name) then continue end
        local u = U[name]
        local ok = true
        local inRoom = 0
        if u then
            for _, q in ipairs(u) do
                if q.Room == rk then inRoom += 1 end
                if not MapShell.Relax and (Vector3.new(q.Pos.X - pos.X, 0, q.Pos.Z - pos.Z)).Magnitude < R.Gap then ok = false; break end
            end
        end
        if ok and inRoom < (R.PerRoom[role] or 2) + (MapShell.Relax and 2 or 0) then
            local n = u and #u or 0
            if n < bestN then best, bestN = { name }, n elseif n == bestN then table.insert(best, name) end
        end
    end
    if #best == 0 then return nil end
    return best[vr:NextInteger(1, #best)]
end
function MapShell.NoteProp(name: string, pos: Vector3, rk: string)
    MapShell.PropUse = MapShell.PropUse or {}
    MapShell.PropUse[name] = MapShell.PropUse[name] or {}
    table.insert(MapShell.PropUse[name], { Pos = pos, Room = rk })
end
-- (MAPVIBE pass 2, owner: "Make sure the props dont just look randomly placed, it should look methodical") Placement
-- follows the room, as if someone stacked / left things there: every piece BACKS ONTO A WALL (its back MapShell.BACK off
-- it), faces into the room square to the wall (a few degrees of jitter, never a free spin); the mid piece of a set stands
-- beside its anchor on the same line; smalls sit at their feet turned to the room's axes; tools / rings / roots LEAN on
-- the wall; ROWS of one crate / barrel / sack stand shoulder to shoulder like a stack; each doorway gets a matched PAIR
-- flanking it (one side carries an extra small: symmetric, not mirrored). The mid-room scatter moved onto the nearest
-- wall: the open floor is for fighting.
MapShell.BACK = 0.7
MapShell.PROP_SCALE = { A = 1.5, M = 1.4, S = 1.25 }
MapShell.LEAN = { Sledge = true, Pick = true, Shield = true, Lifebuoy = true, Tyre = true, Root = true }
MapShell.ROW = { WBarrel = true, MilCrate = true, Crate = true, CementSack = true, PlasticCrate = true, TrashCan = true, LpgTank = true,
    Cardboard = true, Propane = true, Trashbag = true, Barrier = true, BarrierB = true, Vase = true, ChessRook = true, TeaCup = true }
local function PropBare(name: string): string
    return string.match(name, "/(.+)$") or name
end
-- move a placed prop (model + the hitboxes it made) by delta
function MapShell.ShiftProp(inst: Instance, hits: { Instance }, delta: Vector3)
    if inst:IsA("Model") then inst:PivotTo(inst:GetPivot() + delta) elseif inst:IsA("BasePart") then inst.CFrame += delta end
    for _, h in ipairs(hits) do
        if h:IsA("BasePart") then h.CFrame += delta elseif h:IsA("Model") then h:PivotTo(h:GetPivot() + delta) end
    end
end
-- how far the prop reaches along dir from its centre, + its centre
function MapShell.PropExtent(inst: Instance, dir: Vector3): (number, Vector3)
    local cf, sz
    if inst:IsA("Model") then cf, sz = inst:GetBoundingBox() elseif inst:IsA("BasePart") then cf, sz = inst.CFrame, inst.Size else return 1, Vector3.zero end
    local e = math.abs(cf.RightVector:Dot(dir)) * sz.X / 2 + math.abs(cf.UpVector:Dot(dir)) * sz.Y / 2 + math.abs(cf.LookVector:Dot(dir)) * sz.Z / 2
    return e, cf.Position
end
-- one prop: an EnvKit model ("Set/Name") or a ShellPlace kit; role sets its size + hitbox. Returns the instance, its
-- half-width across cf's right axis, the hitboxes it made (smalls: no hitbox)
function MapShell.PlaceProp(biome: string, tpl: any, pool: any, name: string, role: string, cf: CFrame, scale: number, opts: any, vr: Random): (Instance?, number, { Instance })
    local set, nm = string.match(name, "^(.-)/(.+)$")
    local giant = MapShell.PROP_RULE.Giant[biome] and set == "Props" and 1 or nil
    local hp = opts.HitParent or opts.Parent
    local n0 = hp and #hp:GetChildren() or 0
    local o = { Parent = opts.Parent, Shadow = false, Hitbox = role ~= "S", HitScale = 0.7, HitParent = opts.HitParent }
    local inst
    if set then
        local k = (role == "S") and vr:NextNumber(0.9, 1.1) or vr:NextNumber(0.95, 1.15)
        k *= MapShell.PROP_SCALE[role] or 1 -- (a touch over life size: the rooms are 120 studs across under 20-stud cliffs)
        if giant then k *= (role == "A") and 1 or 0.9 end
        o.Scale = k
        local base = (EnvKit.Get(set, nm) :: any):GetAttribute("Tint") or Color3.new(0.7, 0.7, 0.7)
        local bt = pool.Tint or Color3.new(1, 1, 1)
        o.Tint = Color3.new(math.clamp(base.R * bt.R, 0, 1), math.clamp(base.G * bt.G, 0, 1), math.clamp(base.B * bt.B, 0, 1))
        inst = EnvKit.Place(set, nm, cf, o)
    else
        if name == "Outcrop" and not MapShell.Ctx then return nil, 0, {} end -- (terrain rock needs the shell's context)
        o.Scale = scale
        o.Tint = tpl.Tint and tpl.Tint[name]
        o.HitScale = 0.65
        inst = ShellPlace(biome, name, cf, o, opts.Rng or vr, MapShell.Ctx)
    end
    local hits = {}
    if hp then
        local ch = hp:GetChildren()
        for i = n0 + 1, #ch do
            if ch[i] ~= inst then table.insert(hits, ch[i]) end
        end
    end
    if not inst then return nil, 0, hits end
    MapShell.Vary(inst, vr, "Tint")
    local half = 2
    if inst:IsA("Model") then
        local bcf, sz = inst:GetBoundingBox()
        half = math.abs(bcf.RightVector:Dot(cf.RightVector)) * sz.X / 2 + math.abs(bcf.LookVector:Dot(cf.RightVector)) * sz.Z / 2
    end
    return inst, half, hits
end
-- set the prop's back `back` studs off the wall (wall = a point on the wall line, out = its outward normal)
local function ToWall(inst: Instance?, hits: { Instance }, wall: Vector3, out: Vector3, back: number?)
    if not inst then return end
    local e, c = MapShell.PropExtent(inst, out)
    local d = (c - wall):Dot(out) + e -- (+ = its back pokes past the wall)
    MapShell.ShiftProp(inst, hits, out * (-(back or MapShell.BACK) - d))
end
-- the room's axes: the wall's facing turned a multiple of 90 deg (turns), a few degrees off
local function Square(cf: CFrame, vr: Random, turns: boolean?): CFrame
    local q = turns and vr:NextInteger(0, 3) or 0
    local j = vr:NextNumber(-0.07, 0.07)
    return cf * CFrame.Angles(0, q * math.pi / 2 + (MapShell.NoJitter and 0 or j), 0)
end
-- a placement against a wall: wall = the point on the wall line, out = the wall's outward normal. A SET PIECE (anchor +
-- the mid beside it + smalls at their feet + maybe a tool leaning on the wall), a ROW (2-3 of one stackable piece
-- shoulder to shoulder) or a lone piece. Returns the anchor (nil = left bare: fewer, better), the radius it reserves, its
-- centre
function MapShell.Compose(biome: string, tpl: any, wall: Vector3, out: Vector3, scale: number, rk: string, opts: any, vr: Random): (Instance?, number, Vector3?)
    local pool = MapShell.PropPool(biome, tpl)
    local R = MapShell.PROP_RULE
    if not opts.NoSkip and vr:NextNumber() < R.Skip then return nil, 0, nil end
    local along = Vector3.new(-out.Z, 0, out.X)
    local rot = CFrame.lookAt(wall, wall - out).Rotation -- (-Z = into the room)
    local probe = wall - out * 4
    local roll = vr:NextNumber()
    local mode = opts.Mode or ((roll < R.Cluster) and "Set" or ((roll < R.Cluster + R.Row) and "Row" or "One"))
    if mode == "Low" then
        local first, cursor = nil, vr:NextNumber(-1.5, 0)
        for _ = 1, vr:NextInteger(2, 3) do
            local sname = MapShell.PickProp(pool, "S", probe, rk, vr)
            if not sname then
                local was = MapShell.Relax
                MapShell.Relax = true
                sname = MapShell.PickProp(pool, "S", probe, rk, vr)
                MapShell.Relax = was
            end
            if not sname then break end
            local sp = wall - out * vr:NextNumber(1.2, 2.6) + along * cursor
            local lean = MapShell.LEAN[PropBare(sname)] == true
            local cf = Square(CFrame.new(sp) * rot, vr, not lean)
            if lean then cf *= CFrame.Angles(math.rad(vr:NextNumber(10, 18)), 0, 0) end
            local s, hw, sh = MapShell.PlaceProp(biome, tpl, pool, sname, "S", cf, 1, opts, vr)
            if s then
                ToWall(s, sh, wall, out, lean and 0.15 or MapShell.BACK + vr:NextNumber(0, 1.2))
                MapShell.NoteProp(sname, sp, rk)
                first = first or s
                cursor += hw * 2 + vr:NextNumber(0.4, 1.4)
            end
        end
        return first, 4, wall - out * 2
    end
    if mode == "Row" then
        local rname = MapShell.PickProp(pool, "M", probe, rk, vr, function(n) return MapShell.ROW[PropBare(n)] == true end)
        if rname then
            local n = vr:NextInteger(2, 3)
            local first, firstHalf = nil, 0
            local cursor = 0
            local turn = vr:NextNumber() < 0.5 and CFrame.Angles(0, math.pi / 2, 0) or CFrame.identity -- (the row turned: crates end-on)
            MapShell.SetN = (MapShell.SetN or 0) + 1
            local sid = "Row" .. MapShell.SetN -- (attr MVSet: one deliberate group -- the copy-paste scan doesn't count it as repeats)
            for i = 1, n do
                local cf = Square(CFrame.new(wall - out * 3 + along * cursor) * rot, vr) * turn
                local inst, hw, hits = MapShell.PlaceProp(biome, tpl, pool, rname, "M", cf, scale, opts, vr)
                if not inst then break end
                inst:SetAttribute("MVSet", sid)
                local e, c = MapShell.PropExtent(inst, along)
                if i > 1 then -- (shoulder to shoulder: it just touches the one before)
                    local want = cursor + e
                    MapShell.ShiftProp(inst, hits, along * (want - (c - wall):Dot(along)))
                    cursor = want + e + vr:NextNumber(0.1, 0.35)
                else
                    cursor = (c - wall):Dot(along) + e + vr:NextNumber(0.1, 0.35)
                    first, firstHalf = inst, hw
                end
                ToWall(inst, hits, wall, out)
            end
            if first then
                MapShell.NoteProp(rname, probe, rk)
                local centre = wall - out * 3 + along * (cursor / 2)
                if vr:NextNumber() < 0.3 then -- (a small dropped at the row's end)
                    local sname = MapShell.PickProp(pool, "S", centre, rk, vr, function(nm) return not MapShell.LEAN[PropBare(nm)] end)
                    if sname then
                        local sp = wall - out * 2 + along * (cursor + 1.2)
                        local s, _, sh = MapShell.PlaceProp(biome, tpl, pool, sname, "S", Square(CFrame.new(sp) * rot, vr, true), 1, opts, vr)
                        if s then ToWall(s, sh, wall, out, MapShell.BACK + vr:NextNumber(0, 1.2)); MapShell.NoteProp(sname, sp, rk) end
                    end
                end
                return first, math.max(firstHalf, cursor / 2) + 3, centre
            end
        end
        mode = "One"
    end
    -- the anchor: a big piece for a set, else a big or a mid piece
    local role = (mode == "Set" or vr:NextNumber() < 0.5) and "A" or "M"
    local name = MapShell.PickProp(pool, role, probe, rk, vr) or MapShell.PickProp(pool, role == "A" and "M" or "A", probe, rk, vr)
    if not name then return nil, 0, nil end
    role = table.find(pool.A, name) and "A" or "M"
    local anchor, ah, ahits = MapShell.PlaceProp(biome, tpl, pool, name, role, Square(CFrame.new(wall - out * 4) * rot, vr), scale, opts, vr)
    if not anchor then return nil, 0, nil end
    ToWall(anchor, ahits, wall, out)
    MapShell.NoteProp(name, probe, rk)
    local _, ac = MapShell.PropExtent(anchor, out)
    local acW = (ac - wall):Dot(along)
    local reach = ah + 2
    local side = (vr:NextNumber() < 0.5) and -1 or 1
    if mode == "Set" then
        -- the mid piece on the same line, just beside it
        local mname = MapShell.PickProp(pool, "M", probe + along * side * (ah + 3), rk, vr)
        local mh = 0
        if mname then
            local mp = wall - out * 3 + along * (acW + side * (ah + 2.5))
            local m, hw, mhits = MapShell.PlaceProp(biome, tpl, pool, mname, "M", Square(CFrame.new(mp) * rot, vr, MapShell.ROW[PropBare(mname)] == true), scale, opts, vr)
            if m then
                local e, c = MapShell.PropExtent(m, along)
                local want = acW + side * (ah + vr:NextNumber(0.3, 1.0) + e)
                MapShell.ShiftProp(m, mhits, along * (want - (c - wall):Dot(along)))
                ToWall(m, mhits, wall, out)
                MapShell.NoteProp(mname, mp, rk)
                mh = hw
                reach = math.max(reach, ah + 2 * hw + 3)
            end
        end
        -- smalls at their feet (square to the room), maybe a tool leaning on the wall on the other side
        for k = 1, vr:NextInteger(0, 2) do -- (perf: smalls are the bulk of the parts)
            local lean = k == 1 and vr:NextNumber() < 0.45
            local sname = MapShell.PickProp(pool, "S", probe, rk, vr, function(nm) return (MapShell.LEAN[PropBare(nm)] == true) == lean end)
            if sname then
                if lean then
                    local bp = wall - out * 0.6 + along * (acW - side * (ah + vr:NextNumber(0.8, 1.6)))
                    local cf = CFrame.new(bp) * rot * CFrame.Angles(0, vr:NextNumber(-0.15, 0.15), 0) * CFrame.Angles(math.rad(vr:NextNumber(10, 18)), 0, 0)
                    local s, _, sh = MapShell.PlaceProp(biome, tpl, pool, sname, "S", cf, 1, opts, vr)
                    if s then ToWall(s, sh, wall, out, 0.15); MapShell.NoteProp(sname, bp, rk) end
                else
                    local u = acW + side * vr:NextNumber(-0.3, 1) * (ah + mh)
                    local adepth = MapShell.PropExtent(anchor, out)
                    local sp = wall - out * (MapShell.BACK + 2 * adepth + vr:NextNumber(0.8, 1.8)) + along * u
                    local s = MapShell.PlaceProp(biome, tpl, pool, sname, "S", Square(CFrame.new(sp) * rot, vr, true), 1, opts, vr)
                    if s then MapShell.NoteProp(sname, sp, rk) end
                end
            end
        end
    elseif vr:NextNumber() < 0.3 then
        -- a lone piece gets one small thing beside it, on the wall line
        local sname = MapShell.PickProp(pool, "S", probe, rk, vr)
        if sname then
            local lean = MapShell.LEAN[PropBare(sname)] == true
            local bp = wall - out * 2 + along * (acW + side * (ah + vr:NextNumber(0.8, 1.6)))
            local cf = Square(CFrame.new(bp) * rot, vr, not lean)
            if lean then cf *= CFrame.Angles(math.rad(vr:NextNumber(10, 18)), 0, 0) end
            local s, _, sh = MapShell.PlaceProp(biome, tpl, pool, sname, "S", cf, 1, opts, vr)
            if s then ToWall(s, sh, wall, out, lean and 0.15 or MapShell.BACK); MapShell.NoteProp(sname, bp, rk) end
        end
    end
    return anchor, reach, wall - out * 4 + along * acW
end
-- each doorway of a room gets a matched pair flanking it (both against the wall either side, facing in; one carries an
-- extra small). doors = points on the room's walls; reserved = the room's kept-clear spots (the pair joins it)
function MapShell.Flank(biome: string, tpl: any, doors: { Vector3 }, cx: number, cz: number, half: number, reserved: { any }, rk: string, opts: any, vr: Random)
    if not MapShell.PropsOn() then return end
    local pool = MapShell.PropPool(biome, tpl)
    local c = Vector3.new(cx, FLOOR_TOP, cz)
    for _, door in ipairs(doors) do
        local d = Vector3.new(door.X - cx, 0, door.Z - cz)
        local out = (math.abs(d.X) > math.abs(d.Z)) and Vector3.new(math.sign(d.X), 0, 0) or Vector3.new(0, 0, math.sign(d.Z))
        local along = Vector3.new(-out.Z, 0, out.X)
        local dp = Vector3.new(door.X, FLOOR_TOP, door.Z)
        dp = dp - out * ((dp - c):Dot(out) - half) -- (onto the wall line)
        local rot = CFrame.lookAt(dp, dp - out).Rotation
        local name = MapShell.PickProp(pool, "M", dp - out * 4, rk, vr)
        if name then
            for gap = 10, 34, 3 do
                local qa, qb = dp + along * gap - out * 4, dp - along * gap - out * 4
                local ia, ib = math.abs((qa - c):Dot(along)), math.abs((qb - c):Dot(along))
                if ia < half - 6 and ib < half - 6 and FreeSpot(reserved, qa, 4) and FreeSpot(reserved, qb, 4) then
                    local extra = (vr:NextNumber() < 0.5) and 1 or -1
                    MapShell.SetN = (MapShell.SetN or 0) + 1
                    local yawJ = vr:NextNumber(-0.06, 0.06)
                    for _, s in ipairs({ 1, -1 }) do
                        local wp = dp + along * s * gap
                        local inst, hw, hits = MapShell.PlaceProp(biome, tpl, pool, name, "M", CFrame.new(wp - out * 3) * rot * CFrame.Angles(0, s * yawJ, 0), 1.3, opts, vr)
                        if inst then
                            inst:SetAttribute("MVSet", "Pair" .. MapShell.SetN)
                            ToWall(inst, hits, wp, out)
                            table.insert(reserved, { Pos = wp - out * 4, R = math.max(5, hw + 3) })
                            if s == extra then
                                local sname = MapShell.PickProp(pool, "S", wp - out * 4, rk, vr, function(nm) return not MapShell.LEAN[PropBare(nm)] end)
                                if sname then
                                    local sp = wp - out * 2 + along * s * (hw + vr:NextNumber(0.8, 1.5))
                                    local sm, _, sh = MapShell.PlaceProp(biome, tpl, pool, sname, "S", Square(CFrame.new(sp) * rot, vr, true), 1, opts, vr)
                                    if sm then ToWall(sm, sh, wp, out, MapShell.BACK + vr:NextNumber(0, 1)); MapShell.NoteProp(sname, sp, rk) end
                                end
                            end
                        end
                    end
                    MapShell.NoteProp(name, qa, rk)
                    MapShell.NoteProp(name, qb, rk)
                    break
                end
            end
        end
    end
end
-- DEDUPE (MAPVIBE): after a floor is built, two copies of one model standing close (the scan's "near-identical neighbours":
-- same model, size within 12 %, < 30 studs apart) read as stamped -- the landmark rings, RoomGen's mirrored cover, two
-- kits that rolled the same. The second of each such pair swaps its LOOK for another model of the biome's pool that fits
-- its footprint (a basalt cluster next to a scoria mound, a sedan next to a covered car): visual-only pieces only (every
-- visible part non-colliding: the hitbox / collider stays exactly where it was), never a deliberate row / pair (attr
-- MVSet), a pillar clad, a crown, an enemy or anything with a prompt. Inside the room boxes only. Returns the swaps.
function MapShell.Dedupe(dungeon: Instance, biome: string, tpl: any, boxes: { any }, vr: Random): number
    local pool = MapShell.PropPool(biome, tpl)
    local cands = {}
    for _, role in ipairs({ "A", "M" }) do
        for _, n in ipairs(pool[role]) do
            local set, nm = string.match(n, "^(.-)/(.+)$")
            if not set then set, nm = biome, n end
            local s = EnvKit.Size(set, nm)
            if s then table.insert(cands, { Set = set, Name = nm, Size = s }) end
        end
    end
    if #cands == 0 then return 0 end
    local function Inside(p: Vector3): boolean
        for _, b in ipairs(boxes) do
            if p.X > b[1] and p.X < b[2] and p.Z > b[3] and p.Z < b[4] then return true end
        end
        return false
    end
    local list = {}
    for _, m in ipairs(dungeon:GetDescendants()) do
        if m:IsA("Model") and not m:GetAttribute("MVSet") and not m:GetAttribute("RoomDress") and m.Name ~= "TallDress"
            and not CollectionService:HasTag(m, "AimRngEnemy") and not m:FindFirstChildOfClass("Humanoid") then
            local p, top = m.Parent, true
            -- (pass 2's room-1 dressing is its own design: never swapped -- a Cyber rack row came back as CyberPoles)
            while p and p ~= dungeon do if p:IsA("Model") or p.Name == "RoomAtmo" then top = false; break end p = p.Parent end
            if top then
                local vis, solid = false, false
                for _, q in ipairs(m:GetDescendants()) do
                    if q:IsA("BasePart") and q.Transparency < 0.95 then
                        vis = true
                        if q.CanCollide then solid = true; break end
                    elseif q:IsA("ProximityPrompt") then solid = true; break end
                end
                local flyer = false
                for _, pat in ipairs(MapShell.SETTLE_FLY) do if string.find(m.Name, pat) then flyer = true; break end end
                local anc = m.Parent
                while anc and anc ~= dungeon do if anc.Name == "Ambience" or anc.Name == "Scenery" then flyer = true end anc = anc.Parent end
                if vis and not solid and not flyer then
                    local cf, sz = m:GetBoundingBox()
                    if Inside(cf.Position) and cf.Position.Y - sz.Y / 2 < FLOOR_TOP + 6 then -- (standing on the floor: never sky / ambience pieces)
                        table.insert(list, { M = m, P = cf.Position, CF = cf, S = sz, N = m:GetAttribute("Src") or m.Name })
                    end
                end
            end
        end
    end
    local swapped, done = 0, {}
    -- (a room with 3+ of one model: every copy past the second is due too, however far apart -- four yellow barrels
    -- across one roof read stamped from anywhere)
    local roomOf = {}
    for _, e in ipairs(list) do
        for bi, bx in ipairs(boxes) do
            if e.P.X > bx[1] and e.P.X < bx[2] and e.P.Z > bx[3] and e.P.Z < bx[4] then roomOf[e] = bi; break end
        end
    end
    local seenN, due = {}, {}
    for _, e in ipairs(list) do
        local k = e.N .. "#" .. tostring(roomOf[e])
        seenN[k] = (seenN[k] or 0) + 1
        if seenN[k] > 2 then due[e] = true end
    end
    for i = 1, #list do
        local a = list[i]
        for j = i + 1, #list do
            local b = list[j]
            if not done[b] and not done[a] and a.N == b.N then
                local la, lb = math.max(a.S.X, a.S.Y, a.S.Z), math.max(b.S.X, b.S.Y, b.S.Z)
                if due[b] or (math.abs(la - lb) / math.max(la, lb) < 0.12 and (Vector3.new(a.P.X - b.P.X, 0, a.P.Z - b.P.Z)).Magnitude < 30) then
                    -- the best other model for b's footprint: scale its longest side across to b's, height within 1.6x
                    local fw = math.max(b.S.X, b.S.Z)
                    local best, bestScore = {}, math.huge
                    for _, c in ipairs(cands) do
                        if c.Name ~= b.N then
                            local k = fw / math.max(c.Size.X, c.Size.Z, 0.1)
                            if k > 0.55 and k < 1.9 then
                                local hr = (c.Size.Y * k) / math.max(b.S.Y, 0.1)
                                if hr > 0.6 and hr < 1.6 then
                                    local score = math.abs(math.log(hr)) + math.abs(math.log(k)) * 0.5
                                    if score < bestScore - 0.15 then best, bestScore = { { c, k } }, score
                                    elseif score < bestScore + 0.15 then table.insert(best, { c, k }) end
                                end
                            end
                        end
                    end
                    if #best > 0 then
                        local pick = best[vr:NextInteger(1, #best)]
                        local yaw = select(2, b.M:GetPivot():ToEulerAnglesYXZ())
                        local foot = CFrame.new(b.P.X, b.P.Y - b.S.Y / 2, b.P.Z) * CFrame.Angles(0, yaw + vr:NextNumber(-0.4, 0.4), 0)
                        -- (the biome's pool tint too, as MapShell.PlaceProp gives it: Fungal's swapped-in logs stayed pale tan)
                        local tmpl = EnvKit.Get(pick[1].Set, pick[1].Name)
                        local bt, base = pool.Tint, tmpl and (tmpl :: any):GetAttribute("Tint")
                        local tint = (bt and typeof(base) == "Color3") and Color3.new(math.clamp(base.R * bt.R, 0, 1), math.clamp(base.G * bt.G, 0, 1), math.clamp(base.B * bt.B, 0, 1)) or nil
                        local inst = EnvKit.Place(pick[1].Set, pick[1].Name, foot, { Scale = pick[2], Parent = b.M.Parent, Hitbox = false, Shadow = false, Tint = tint })
                        if inst then
                            inst:SetAttribute("Swapped", b.N)
                            MapShell.Vary(inst, vr, "Tint")
                            b.M:Destroy()
                            done[b] = true
                            swapped += 1
                        end
                    end
                end
            end
        end
    end
    -- MIRRORED PAIRS (RoomGen mirrors its room 62 % of the time: two obelisks / braziers / trees at x = +-a): symmetry
    -- kept, the mirror broken -- the second stands a little smaller and turned its own way
    for i = 1, #list do
        local a = list[i]
        if not done[a] and a.M.Parent then
            for j = i + 1, #list do
                local b = list[j]
                local bx = roomOf[b] and boxes[roomOf[b]]
                if bx and not done[b] and b.M.Parent and a.N == b.N and roomOf[a] == roomOf[b] then
                    local cx = (bx[1] + bx[2]) / 2
                    if math.abs((a.P.X - cx) + (b.P.X - cx)) < 3 and math.abs(a.P.Z - b.P.Z) < 3 and math.abs(a.P.X - cx) > 4 then
                        local m = b.M :: Model
                        local foot = Vector3.new(b.P.X, b.P.Y - b.S.Y / 2, b.P.Z)
                        local k = vr:NextNumber(0.8, 0.9)
                        pcall(function() m:ScaleTo(m:GetScale() * k) end)
                        local pv = m:GetPivot()
                        m:PivotTo(CFrame.new(foot) * CFrame.Angles(0, vr:NextNumber(0.35, 0.7) * ((vr:NextNumber() < 0.5) and -1 or 1), 0) * CFrame.new(-foot) * pv)
                        local cf2, sz2 = m:GetBoundingBox()
                        m:PivotTo(m:GetPivot() + Vector3.new(0, foot.Y - (cf2.Position.Y - sz2.Y / 2), 0))
                        MapShell.Vary(m, vr, "Tint")
                        done[b] = true
                        swapped += 1
                        break
                    end
                end
            end
        end
    end
    return swapped
end
-- SETTLE (MAPVIBE, owner: "make sure theres no floating props in the sky (like i see in the mushroom biome)"). Two causes
-- were measured: (1) every prop placed before the terrain edits (MAPLOOK rim rocks, RoomGen cover, kit dressing) stood on
-- the OLD raised ground and FlushGround / CarveFaces then took that ground away -- 1-3 studs of air under them; (2) on the
-- Edge maps (rooms are islands over a drop) rim / bank pieces and the hero landmark past the exit room (the spore world's
-- giant mushrooms) were placed where there is no ground at all. Once every terrain edit is done, each top-level dressing
-- model is read against what is really under it (5 footprint points cast down from above its top: terrain + visible parts
-- + colliders at floor height, never itself): a gap -> it drops onto its highest support, sunk a little more on a slope so
-- no air shows downhill (its box hitboxes move with it); nothing under it -> a small piece is removed, a landmark-sized one
-- (25+ studs) gets a rock islet under its foot, in the rim's stone (an island over the void, the map's own theme).
-- Intended flyers (creatures, sky islands, lanterns, far vista copies, the sun / moon, chests, portals) are skipped by name.
MapShell.SETTLE_FLY = { "^Life", "^Far", "Butterfly", "Airship", "Balloon", "Jelly", "Bat$", "Macaw", "SkyLantern", "Isle", "Island",
    "Floater", "Floating", "Cloud", "Meteor", "Moon", "Sun", "Planet", "Star", "Halo", "Glow", "Mote", "Spore", "Orb", "Drone",
    "Wire", "Cable", "Beacon", "Vista", "Portal", "Chest", "Encounter", "LinkCache", "Merchant", "Hitbox" }
function MapShell.Settle(dungeon: Instance, tpl: any, terrain: boolean, useRay: boolean?): (number, number, number)
    local function Fly(n: string): boolean
        for _, p in ipairs(MapShell.SETTLE_FLY) do if string.find(n, p) then return true end end
        return false
    end
    local items, hits = {}, {}
    local function Walk(root: Instance)
        for _, x in ipairs(root:GetChildren()) do
            if x:IsA("Model") and (string.match(x.Name, "^R%d+$") or x.Name == "LinkedRooms") then
                Walk(x) -- (a linked room's folder is a Model: its pieces are the items)
            elseif x:IsA("Model") then
                if not CollectionService:HasTag(x, "AimRngEnemy") and not x:FindFirstChildOfClass("Humanoid") and not Fly(x.Name)
                    and not x:FindFirstChildWhichIsA("ProximityPrompt", true) then
                    table.insert(items, x)
                end
            elseif x:IsA("Folder") then
                -- (the ambient life layers float on purpose; pass 2's RoomAtmo seats its own pieces -- and the Skyport's cargo
                -- HANGS from its davits on purpose)
                if x.Name ~= "Ambience" and x.Name ~= "Scenery" and x.Name ~= "RoomAtmo" then Walk(x) end
            elseif x:IsA("BasePart") and x.Name == "Hitbox" then
                table.insert(hits, x)
            end
        end
    end
    Walk(dungeon)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local chars = {}
    for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(chars, pl.Character) end end
    local T = Workspace.Terrain
    local moved, removed, isles = 0, 0, 0
    -- (hills, isles, decks drawn as art are CanQuery off: raycasts can't see them -- they count as ground for this pass)
    local unq = {}
    for _, p in ipairs(dungeon:GetDescendants()) do
        if p:IsA("BasePart") and not p.CanQuery and p.Transparency < 0.95 and p.Size.Magnitude > 6 then
            p.CanQuery = true
            table.insert(unq, p)
        end
    end
    -- (terrain written this frame is not in the raycast world yet -- FlushGround / CarveFaces / ClearInterior just ran -- so
    -- terrain is read from the VOXELS: the top non-air cell under the point + its occupancy)
    local function TerrainTop(x: number, z: number, top: number): number?
        -- (2026-10-25 START FIX: a model far below / far above the floor -- or a NaN box -- made an empty / too-large region, and
        -- the error broke the whole floor build: "pressed START, nothing happened")
        if top ~= top or x ~= x or z ~= z or top < -56 then return nil end
        local y1 = math.clamp(math.floor((top + 4) / 4) * 4, -56, 512)
        local reg = Region3.new(Vector3.new(x - 1, -64, z - 1), Vector3.new(x + 1, y1, z + 1)):ExpandToGrid(4)
        local okR, mats, occ = pcall(T.ReadVoxels, T, reg, 4)
        if not okR then return nil end
        local lo = reg.CFrame.Position - reg.Size / 2
        local sx, sy, sz2 = mats.Size.X, mats.Size.Y, mats.Size.Z
        local i, k = math.clamp(math.floor((x - lo.X) / 4) + 1, 1, sx), math.clamp(math.floor((z - lo.Z) / 4) + 1, 1, sz2)
        for j = sy, 1, -1 do
            local mt, o = mats[i][j][k], occ[i][j][k]
            local below = (j > 1) and occ[i][j - 1][k] or 1
            -- (a thin cell over air renders as nothing: it counts only when it is mostly full or sits on a full one)
            if mt ~= M.Air and mt ~= M.Water and (o >= 0.6 or (o >= 0.25 and below >= 0.5)) then
                return lo.Y + (j - 1) * 4 + 4 * math.min(o, 1)
            end
        end
        return nil
    end
    local function Ground(m: Instance, x: number, z: number, top: number, bottom: number): number?
        local ex = table.clone(chars); table.insert(ex, m)
        if not useRay then table.insert(ex, T) end -- (terrain: the voxel read below; the second pass casts at it)
        rp.FilterDescendantsInstances = ex
        local tt = (not useRay) and TerrainTop(x, z, top) or nil
        local from = Vector3.new(x, top + 2, z)
        for _ = 1, 8 do
            local h = Workspace:Raycast(from, Vector3.new(0, -(top + 2 - bottom) - 400, 0), rp)
            if not h then return tt end
            local inst = h.Instance
            if inst == T then return h.Position.Y end
            if tt and tt >= h.Position.Y then return tt end
            local p = inst :: BasePart
            local invisible = p.Transparency >= 0.95
            -- (a visible part is ground; an invisible collider only at floor height -- the tall invisible room walls / lids
            -- are not; other props' hitboxes never)
            if p.Name ~= "Hitbox" and p.Name ~= "Baseplate" -- (the place's hidden baseplate under everything is never ground)
                and ((not invisible) or (p.CanCollide and h.Position.Y <= bottom + 1)) then return h.Position.Y end
            from = h.Position - Vector3.new(0, 0.05, 0)
        end
        return tt
    end
    local function Islet(cf: CFrame, sz: Vector3, wide: boolean?)
        local base = cf.Position - Vector3.new(0, sz.Y / 2, 0)
        local mat = (tpl and tpl.RimMat and tpl.RimMat[1]) or Enum.Material.Rock
        local top = (tpl and tpl.Ground) or mat
        local rx, rz = math.clamp(sz.X * 0.5, 5, 140), math.clamp(sz.Z * 0.5, 5, 140)
        local r = math.min(rx, rz)
        -- a flat-topped oval slab (the top 1.5 studs in the map's ground), then a rock underside tapering to a point
        local stretch = CFrame.new(base) * CFrame.Angles(0, (rx > rz) and math.pi / 2 or 0, 0)
        local long = math.max(rx, rz)
        local n = math.max(1, math.floor(long / r + 0.5))
        for i = 0, n - 1 do
            local off = (n == 1) and 0 or (-long + r + (2 * long - 2 * r) * i / (n - 1))
            local cfi = stretch * CFrame.new(0, 0, off)
            T:FillCylinder(cfi * CFrame.new(0, -2.2, 0), 4.4, r, mat)
            T:FillCylinder(cfi * CFrame.new(0, -0.6, 0), 1.6, r - 1, top)
            for k = 1, 4 do
                T:FillBall(cfi.Position - Vector3.new(0, 3 + k * r * 0.34, 0), r * (1 - k * 0.18), mat)
            end
        end
    end
    for _, m in ipairs(items) do
        if m.Parent and (not useRay or m:IsDescendantOf(Workspace)) then
            local cf, sz = (m :: Model):GetBoundingBox()
            if sz.Magnitude < 600 and sz.Y > 0.05 then
                local bottom, top = cf.Position.Y - sz.Y / 2, cf.Position.Y + sz.Y / 2
                local gs, gmin = nil, math.huge
                for _, o in ipairs({ { 0, 0 }, { 0.35, 0.35 }, { -0.35, 0.35 }, { 0.35, -0.35 }, { -0.35, -0.35 } }) do
                    local g = Ground(m, cf.Position.X + o[1] * sz.X, cf.Position.Z + o[2] * sz.Z, top, bottom)
                    if g then gs = math.max(gs or -math.huge, g); gmin = math.min(gmin, g) end
                end
                if gs and bottom - gs > 30 then gs = nil end -- (the vista floor far below an Edge map is not its ground)
                if not gs and MapShell.SettleSoft then
                    -- (second pass: nothing to do here)
                elseif not gs then
                    if sz.Y >= 25 and terrain then
                        -- a landmark: an islet under each of its pieces that has nothing under it
                        -- ONE island under the whole group (a sky island of giant mushrooms reads as a place; a rock under each
                        -- stem read as stuck-on lumps): its top is the group's foot, the map's ground stone on top
                        local x0, x1, z0, z1, yb = math.huge, -math.huge, math.huge, -math.huge, math.huge
                        local subs = {}
                        for _, c in ipairs(m:GetChildren()) do if c:IsA("Model") then table.insert(subs, c) end end
                        if #subs == 0 then subs = { m } end
                        for _, c in ipairs(subs) do
                            local ccf, csz = (c :: Model):GetBoundingBox()
                            local r = math.max(csz.X, csz.Z) * 0.5
                            x0, x1 = math.min(x0, ccf.Position.X - r), math.max(x1, ccf.Position.X + r)
                            z0, z1 = math.min(z0, ccf.Position.Z - r), math.max(z1, ccf.Position.Z + r)
                            yb = math.min(yb, ccf.Position.Y - csz.Y / 2)
                        end
                        local c = Vector3.new((x0 + x1) / 2, yb, (z0 + z1) / 2)
                        local ext = Vector3.new(x1 - x0, 0, z1 - z0)
                        Islet(CFrame.new(c + Vector3.new(0, 1, 0)), Vector3.new(ext.X + 16, 2, ext.Z + 16), true)
                        isles += 1
                    elseif sz.Y < 25 or not terrain then -- (a part map has no island to give it: off it goes)
                        for _, h in ipairs(hits) do
                            if h.Parent and math.abs(h.Position.X - cf.Position.X) < sz.X / 2 and math.abs(h.Position.Z - cf.Position.Z) < sz.Z / 2 then h:Destroy() end
                        end
                        m:Destroy()
                        removed += 1
                    end
                else
                    local gap = bottom - gs
                    local solid = false
                    for _, q in ipairs(m:GetDescendants()) do if q:IsA("BasePart") and q.CanCollide then solid = true; break end end
                    if gap > 0.3 and gap < (solid and 10 or 30) then
                        local slope = gs - gmin
                        local d = gap + 0.15 + math.min(slope * 0.7, sz.Y * 0.3)
                        local delta = Vector3.new(0, -d, 0)
                        ;(m :: Model):PivotTo((m :: Model):GetPivot() + delta)
                        for _, h in ipairs(hits) do
                            if h.Parent and math.abs(h.Position.X - cf.Position.X) < sz.X / 2 and math.abs(h.Position.Z - cf.Position.Z) < sz.Z / 2
                                and h.Position.Y > bottom - 2 and h.Position.Y < top + 2 then
                                h.CFrame += delta
                            end
                        end
                        moved += 1
                    end
                end
            end
        end
    end
    for _, p in ipairs(unq) do if p.Parent then p.CanQuery = false end end
    return moved, removed, isles
end
-- LAYOUT STYLES (per biome / world family; slot lists on the look stream). side 1..4 = W E N S (S = the exit / portal end).
MapShell.LAYOUT = { Fire = "Works", Waste = "Works", Flats = "Works", Ice = "Drift", Void = "Broken", Dream = "Broken",
    Cyber = "Grid", Station = "Grid", Sky = "Grid", Storm = "Wind", Ruin = "Ruin", Nature = "Organic", Farm = "Organic",
    Sea = "Organic", Swamp = "Organic", Industrial = "Works" }
local function Slot(side: number, u: number, t: any?): any
    local s = t or {}
    s[1], s[2] = side, u
    return s
end
MapShell.SLOTS = {
    -- WORKS (foundry, wastes, highway yard): ONE working wall holds a line of equipment / stacked stock, end to end; heaps in
    -- the two corners of the opposite wall; the doorway walls take one stack each by the door
    Works = function(vr: Random)
        local main = vr:NextInteger(1, 2)
        local t = {}
        for _, u in ipairs({ -0.72, -0.36, 0, 0.36, 0.72 }) do table.insert(t, Slot(main, u, { Mode = (u == 0) and "Row" or ((math.abs(u) < 0.5) and "One" or "Set"), Look = "Square" })) end
        local opp = 3 - main
        table.insert(t, Slot(opp, -0.78, { Mode = "Set", Look = "Heap" }))
        table.insert(t, Slot(opp, 0.78, { Mode = "Set", Look = "Heap" }))
        table.insert(t, Slot(3, vr:NextNumber() < 0.5 and -0.55 or 0.55, { Mode = "Row", Look = "Square" }))
        table.insert(t, Slot(4, vr:NextNumber() < 0.5 and -0.62 or 0.62, { Mode = "Row", Look = "Square" }))
        return t
    end,
    -- DRIFT (ice): the windward wall and its two corners hold drifted clusters, half sunk; the lee side stays nearly bare
    Drift = function(vr: Random)
        local wind = vr:NextInteger(1, 4)
        local t = {}
        for _, u in ipairs({ -0.8, -0.45, -0.1, 0.3, 0.7 }) do
            table.insert(t, Slot(wind, u + vr:NextNumber(-0.08, 0.08), { Mode = (vr:NextNumber() < 0.6) and "Set" or "One", Look = "Sunk" }))
        end
        local sides = (wind <= 2) and { 3, 4 } or { 1, 2 }
        for _, sd in ipairs(sides) do
            local near = (wind == 1 or wind == 3) and -0.8 or 0.8 -- (the end of that wall nearest the windward wall)
            table.insert(t, Slot(sd, near, { Mode = "Set", Look = "Sunk" }))
        end
        return t
    end,
    -- BROKEN (void, dream): uneven -- 1-3 pieces a wall at random spots, drifted off the wall, tilted
    Broken = function(vr: Random)
        local t = {}
        for side = 1, 4 do
            for _ = 1, vr:NextInteger(1, 3) do
                table.insert(t, Slot(side, vr:NextNumber(-0.85, 0.85), { Mode = (vr:NextNumber() < 0.5) and "One" or "Set", Depth = vr:NextInteger(0, 3) * 2, Look = "Tilt" }))
            end
        end
        return t
    end,
    -- GRID (cyber, station, skyport): two facing walls carry evenly spaced stacks, squared to the room, no jitter
    Grid = function(vr: Random)
        local a = vr:NextInteger(0, 1)
        local t = {}
        for _, sd in ipairs(a == 0 and { 1, 2 } or { 3, 4 }) do
            for i, u in ipairs({ -0.75, -0.45, -0.15, 0.15, 0.45, 0.75 }) do
                if vr:NextNumber() < 0.75 then table.insert(t, Slot(sd, u, { Mode = ({ "Row", "Set", "One" })[(i % 3) + 1], Square = true, Look = "Square" })) end
            end
        end
        return t
    end,
    -- WIND (storm): everything leans the same way; debris piles up on the downwind wall, little on the upwind one
    Wind = function(vr: Random)
        local down = vr:NextInteger(1, 4)
        local t = {}
        for _, u in ipairs({ -0.78, -0.5, -0.2, 0.15, 0.45, 0.78 }) do
            table.insert(t, Slot(down, u + vr:NextNumber(-0.06, 0.06), { Mode = (vr:NextNumber() < 0.5) and "Set" or "One", Look = "Lean", Dir = down }))
        end
        for side = 1, 4 do
            if side ~= down and vr:NextNumber() < 0.7 then
                table.insert(t, Slot(side, vr:NextNumber(-0.8, 0.8), { Mode = "One", Look = "Lean", Dir = down }))
            end
        end
        return t
    end,
    -- RUIN (temples, shrines, graveyards, dunes): along two opposite walls a line of pieces at a fixed step -- a colonnade --
    -- with gaps where it has fallen (a fallen one lies in its place); offerings (a set) at the middle of one end wall
    Ruin = function(vr: Random)
        local a = vr:NextInteger(0, 1)
        local t = {}
        for _, sd in ipairs(a == 0 and { 1, 2 } or { 3, 4 }) do
            for _, u in ipairs({ -0.7, -0.35, 0, 0.35, 0.7 }) do
                local r = vr:NextNumber()
                if r < 0.6 then table.insert(t, Slot(sd, u, { Mode = "One", Look = "Square", Depth = 3 }))
                elseif r < 0.85 then table.insert(t, Slot(sd, u, { Mode = "One", Look = "Fallen", Depth = 3 })) end
            end
        end
        table.insert(t, Slot(a == 0 and 3 or 1, vr:NextNumber(-0.15, 0.15), { Mode = "Set", Look = "Square" }))
        table.insert(t, Slot(a == 0 and 4 or 2, vr:NextNumber() < 0.5 and -0.8 or 0.8, { Mode = "Set" }))
        return t
    end,
    -- ORGANIC (highlands, spore woods, bayou, deep sea): clusters of different sizes at irregular spacing, all four walls,
    -- no rows, free facing
    Organic = function(vr: Random)
        local t = {}
        for side = 1, 4 do
            local u = -0.85 + vr:NextNumber(0, 0.3)
            while u < 0.85 do
                table.insert(t, Slot(side, u, { Mode = (vr:NextNumber() < 0.55) and "Set" or "One", Look = "Free", Depth = vr:NextInteger(0, 2) * 2 }))
                u += vr:NextNumber(0.45, 1.05)
            end
        end
        return t
    end,
}
MapShell.LOOK = {
    Square = function() end, -- (Compose already squares to the wall)
    Heap = function(m: Model, out: Vector3, vr: Random)
        local pv = m:GetPivot()
        m:PivotTo(pv * CFrame.Angles(0, vr:NextNumber(-0.5, 0.5), 0))
    end,
    Sunk = function(m: Model, out: Vector3, vr: Random)
        local _, sz = m:GetBoundingBox()
        m:PivotTo(m:GetPivot() - Vector3.new(0, sz.Y * vr:NextNumber(0.15, 0.3), 0))
    end,
    Tilt = function(m: Model, out: Vector3, vr: Random)
        local cf, sz = m:GetBoundingBox()
        local foot = cf.Position - Vector3.new(0, sz.Y / 2, 0)
        local a = vr:NextNumber(0, math.pi * 2)
        local T = CFrame.new(foot) * CFrame.fromAxisAngle(Vector3.new(math.cos(a), 0, math.sin(a)), math.rad(vr:NextNumber(5, 14))) * CFrame.new(-foot)
        m:PivotTo(T * m:GetPivot() - Vector3.new(0, sz.Y * 0.06, 0))
    end,
    Lean = function(m: Model, out: Vector3, vr: Random, s: any)
        local cf, sz = m:GetBoundingBox()
        local foot = cf.Position - Vector3.new(0, sz.Y / 2, 0)
        local dir = MapShell.OUT[s.Dir or 1]
        local axis = Vector3.new(-dir.Z, 0, dir.X)
        local T = CFrame.new(foot) * CFrame.fromAxisAngle(axis, -math.rad(vr:NextNumber(6, 11))) * CFrame.new(-foot)
        m:PivotTo(T * m:GetPivot() - Vector3.new(0, sz.Y * 0.05, 0))
    end,
    Fallen = function(m: Model, out: Vector3, vr: Random)
        local cf, sz = m:GetBoundingBox()
        if sz.Y < 3 then return end
        local foot = cf.Position - Vector3.new(0, sz.Y / 2, 0)
        local along = Vector3.new(-out.Z, 0, out.X)
        local T = CFrame.new(foot) * CFrame.fromAxisAngle(out, math.rad(84) * ((vr:NextNumber() < 0.5) and -1 or 1)) * CFrame.new(-foot)
        m:PivotTo(T * m:GetPivot())
        local cf2, sz2 = m:GetBoundingBox()
        m:PivotTo(m:GetPivot() + Vector3.new(0, foot.Y - (cf2.Position.Y - sz2.Y / 2) - 0.2, 0))
    end,
    Free = function(m: Model, out: Vector3, vr: Random)
        local cf, sz = m:GetBoundingBox()
        local foot = cf.Position - Vector3.new(0, sz.Y / 2, 0)
        m:PivotTo(CFrame.new(foot) * CFrame.Angles(0, vr:NextNumber(0, math.pi * 2), 0) * CFrame.new(-foot) * m:GetPivot())
    end,
}
function MapShell.DressWalls(biome: string, tpl: any, cx: number, cz: number, half: number, reserved: { any }, rk: string, opts: any, vr: Random, scale: number): number
    local n = 0
    local R = MapShell.PROP_RULE
    local o = table.clone(opts); o.NoSkip = true
    -- (what is really there: the reserved spots are coarse -- a Hall room's side massif reserves a 64-stud circle, i.e. the
    -- whole room -- so a spot is checked against the small reserved spots + the boxes of the room's real colliders)
    local small = {}
    for _, r in ipairs(reserved) do if not r.Ring and (r.R or 0) <= 30 then table.insert(small, r) end end
    local boxes = {}
    local geoF = opts.HitParent
    if geoF then
        for _, gp in ipairs(geoF:GetDescendants()) do
            if gp:IsA("BasePart") and gp.CanCollide and gp.Size.Y < 40 and gp.Position.Y + gp.Size.Y / 2 > FLOOR_TOP + 0.6
                and gp.Position.Y - gp.Size.Y / 2 < FLOOR_TOP + 8 -- (not the lid / anything overhead)
                and math.abs(gp.Position.X - cx) < half + 10 and math.abs(gp.Position.Z - cz) < half + 10 then
                local c, s = gp.CFrame, gp.Size / 2
                local ex = math.abs(c.RightVector.X) * s.X + math.abs(c.UpVector.X) * s.Y + math.abs(c.LookVector.X) * s.Z
                local ez = math.abs(c.RightVector.Z) * s.X + math.abs(c.UpVector.Z) * s.Y + math.abs(c.LookVector.Z) * s.Z
                table.insert(boxes, { gp.Position.X - ex, gp.Position.X + ex, gp.Position.Z - ez, gp.Position.Z + ez })
            end
        end
    end
    local function Free(pt: Vector3, r: number): boolean
        if not FreeSpot(small, pt, r) then return false end
        for _, bx in ipairs(boxes) do
            if pt.X > bx[1] - r and pt.X < bx[2] + r and pt.Z > bx[3] - r and pt.Z < bx[4] + r then return false end
        end
        return true
    end
    -- LAYOUT STYLE (owner: "make sure the biomes dont have the same placement patterns either"): each biome places by its
    -- own logic -- MapShell.SLOTS[style] makes the list of wall slots { side, u (-1..1 along the wall), mode, look } and
    -- MapShell.LOOK post-shapes what a slot placed (sunk in drifts, leaning with the wind, drifted / tilted, squared).
    local style = MapShell.LAYOUT[biome] or MapShell.LAYOUT[MapShell.PROP_FAMILY[biome] or ""] or "Organic"
    local slots = MapShell.SLOTS[style](vr)
    do
        local per = { 0, 0, 0, 0 }
        for _, s in ipairs(slots) do per[s[1]] += 1 end
        for side = 1, 4 do
            for k = per[side] + 1, 2 do
                table.insert(slots, Slot(side, (k == 1) and vr:NextNumber(-0.7, -0.15) or vr:NextNumber(0.15, 0.7), { Mode = "Low", R = 2.5 }))
            end
        end
    end
    local fx = opts.Parent
    for _, s in ipairs(slots) do
        do
            local side, b = s[1], s[2]
            local out = MapShell.OUT[side]
            local along = Vector3.new(-out.Z, 0, out.X)
            do
                local wall, q
                -- (the slot, or the nearest free stretch of wall either side; a massif / terrace along the wall: its face)
                for depth = s.Depth or 0, 30, 3 do
                    for _, off in ipairs({ 0, 4, -4, 8, -8, 13, -13 }) do
                        local u = math.clamp(b * half + off, -half + 6, half - 6)
                        local wv = Vector3.new(cx, FLOOR_TOP, cz) + out * (half - depth) + along * u
                        if Free(wv - out * 5, s.R or 4.5) then wall, q = wv, wv - out * 5; break end
                    end
                    if wall then break end
                end
                if not wall and s.Mode ~= "Low" then
                    -- (no room for a set here: a low drift of small clutter instead, so the wall is never bare)
                    for depth = 0, 30, 3 do
                        for _, off in ipairs({ 0, 4, -4, 8, -8 }) do
                            local u = math.clamp(b * half + off, -half + 5, half - 5)
                            local wv = Vector3.new(cx, FLOOR_TOP, cz) + out * (half - depth) + along * u
                            if Free(wv - out * 3, 2.5) then wall, q = wv, wv - out * 3; s.Mode = "Low"; break end
                        end
                        if wall then break end
                    end
                end
                if not wall then MapShell.DressMiss = (MapShell.DressMiss or 0) + 1 end
                if wall then
                    local before = {}
                    for _, c in ipairs(fx:GetChildren()) do before[c] = true end
                    local so = table.clone(o); so.Mode = s.Mode; so.Square = s.Square
                    MapShell.NoJitter = s.Square == true
                    local inst, reach, ctr = MapShell.Compose(biome, tpl, wall, out, scale * vr:NextNumber(0.9, 1.1), rk, so, vr)
                    if not inst then
                        MapShell.Relax = true -- (the no-repeat rules ran this slot dry: least-used pieces, never a bare slot)
                        inst, reach, ctr = MapShell.Compose(biome, tpl, wall, out, scale, rk, so, vr)
                        MapShell.Relax = false
                    end
                    MapShell.NoJitter = false
                    if inst then
                        n += 1
                        table.insert(reserved, { Pos = ctr or q, R = math.max(6, reach) })
                        table.insert(small, { Pos = ctr or q, R = math.max(6, reach) })
                        if s.Look and MapShell.LOOK[s.Look] then
                            for _, c in ipairs(fx:GetChildren()) do
                                if not before[c] and c:IsA("Model") then MapShell.LOOK[s.Look](c, out, vr, s) end
                            end
                        end
                    else
                        MapShell.DressEmpty = (MapShell.DressEmpty or 0) + 1
                    end
                end
            end
        end
    end
    return n
end
-- the nearest wall of a room box (centre cx, cz, half) to p: the point on the wall line + its outward normal
function MapShell.NearWall(p: Vector3, cx: number, cz: number, half: number): (Vector3, Vector3)
    local dx, dz = p.X - cx, p.Z - cz
    if math.abs(dx) > math.abs(dz) then
        local s = (dx < 0) and -1 or 1
        return Vector3.new(cx + s * half, FLOOR_TOP, p.Z), Vector3.new(s, 0, 0)
    end
    local s = (dz < 0) and -1 or 1
    return Vector3.new(p.X, FLOOR_TOP, cz + s * half), Vector3.new(0, 0, s)
end

-- kit cover through the open interior (replaces the primitive ScatterProps on open maps)
function MapShell.Scatter(geo: Instance, dungeon: Instance, biome: string, tpl: any, rng: Random, zC: number, half: number, count: number, reserved: { any }, xC: number?, doors: { Vector3 }?)
    local fx = dungeon:FindFirstChild("MapShell") or dungeon
    local placed = 0
    local rk = "R" .. math.floor((xC or 0) + 0.5) .. ":" .. math.floor(zC + 0.5)
    if doors and MapShell.PropsOn() then -- (MAPVIBE pass 2: a matched pair flanking each doorway, on the look stream)
        MapShell.Flank(biome, tpl, doors, xC or 0, zC, half, reserved, rk, { Parent = fx, HitParent = geo }, MapShell.VR or Random.new(math.floor(zC)))
    end
    if MapShell.PropsOn() and doors then -- (pass 3: the linked rooms -- every wall dressed in bays, nothing mid-room)
        dungeon:SetAttribute("Dressed" .. string.gsub(rk, "[^%w]", "_"), MapShell.DressWalls(biome, tpl, xC or 0, zC, half, reserved, rk, { Parent = fx, HitParent = geo }, MapShell.VR or Random.new(math.floor(zC)), 1.4))
        return
    end
    for _ = 1, count * 8 do
        if placed >= count then break end
        local p = Vector3.new((xC or 0) + rng:NextNumber(-half + 14, half - 14), FLOOR_TOP, zC + rng:NextNumber(-half + 14, half - 14)) -- (xC: LINKED ROOMS side room)
        if FreeSpot(reserved, p, 7) and MapShell.PropsOn() then -- (MAPVIBE PROP SETS: the same rng draws, the pick on its own stream)
            local _ = tpl.Edge[rng:NextInteger(1, #tpl.Edge)]
            local _, sc = rng:NextNumber(0, 6.28), rng:NextNumber(1.2, 1.7)
            local vr = MapShell.VR or Random.new(math.floor(p.X * 7 + p.Z * 13))
            -- (pass 2: not on the open floor -- moved onto the nearest wall, into its nearest bay)
            local wall, out = MapShell.NearWall(p, xC or 0, zC, half)
            local along = Vector3.new(-out.Z, 0, out.X)
            local cen = Vector3.new(xC or 0, FLOOR_TOP, zC)
            local u = (wall - cen):Dot(along)
            wall += along * (MapShell.Bay(u / half) * half - u)
            local q = wall - out * 6
            placed += 1
            if FreeSpot(reserved, q, 6) then
                local inst, reach, ctr = MapShell.Compose(biome, tpl, wall, out, sc, rk, { Parent = fx, HitParent = geo }, vr)
                table.insert(reserved, { Pos = ctr or q, R = inst and math.max(6, reach) or 6 })
            end
        elseif FreeSpot(reserved, p, 7) then
            local kit = tpl.Edge[rng:NextInteger(1, #tpl.Edge)]
            local inst = ShellPlace(biome, kit, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
                { Tint = tpl.Tint and tpl.Tint[kit], Scale = rng:NextNumber(1.2, 1.7), Parent = fx, Hitbox = true, HitScale = 0.65, HitParent = geo }, rng, MapShell.Ctx)
            if inst then placed += 1; table.insert(reserved, { Pos = p, R = 7 }); MapShell.Vary(inst, MapShell.VR or Random.new(placed), "Tint") end -- (MAPLOOK: own tint; it has a hitbox)
        end
    end
end


-- build the shell round the combat room. Returns nothing; adds hitboxes for edge props into geo.
-- ENTRY HOUSE (UPDATE 4, owner: "I dont like how the safe zones are completely open and you can see in the skybox when
-- walking out and looking back at them, and a lot of the materials flicker on the safezone"): the entry room + corridor
-- stood alone in the rim's gap (MapShell.KeepOut keeps the rim out) -- a little box against the sky. Now they are dug
-- into a rock massif that fills the gap and runs back behind them: solo open maps build it from TERRAIN in the rim's own
-- stone (it joins the cliffs), party (server) floors and part-built maps from a few big parts (part maps in the wall
-- surface: a built bulkhead, not rock). The arena side is a cliff face with a stone gate round the corridor mouth.
-- Nothing inside changes: the massif starts >= 0.6 stud outside every wall / ceiling face (no shared planes = no flicker).
-- Layout (GetChamberLayout): room walls x +-18..22, z 528..572, ceiling y 20..24; corridor walls x +-8..12, z 570..580,
-- its ceiling y 14.1..18.1 (x +-14); the arena's (invisible) north wall z 578..582.
function MapShell.EntryHouse(dungeon: Instance, theme: any, tpl: any, layout: any, rng: Random, zC: number, arena: number, biome: string?)
    if tpl.Closed then return end -- (a closed room hides everything outside its walls)
    tpl = setmetatable({ Biome = biome }, { __index = tpl })
    local fx = dungeon:FindFirstChild("MapShell") or dungeon
    local eh = layout.EntrySize / 2 -- 20
    local z0 = layout.EntryZ - eh -- 530 (room inner north face 528 is the wall's outer face)
    local zA = zC - arena / 2 + 1.6 -- (the face toward the arena, inside the invisible wall's volume)
    local zS = layout.CorridorAStart + 2.6 -- (just past the room's south wall outer face, 572)
    local W, TOP = 58, FLOOR_TOP + 34 -- (half width -- it overlaps the rim on both sides (the rim stops ~55 out) -- and the top)
    local bottom = (tpl.Rim == "Edge") and (FLOOR_TOP - 60) or (FLOOR_TOP - 6)
    local wallOut = eh + 2.6 -- 22.6
    local corOut = layout.CorridorWidth / 2 + 2.6 -- 12.6
    local boxes = {
        -- { x0, x1, y0, y1, z0, z1 }
        { -32, -wallOut, bottom, TOP, z0 - 30, zA }, -- west of the room, out to the face
        { wallOut, 32, bottom, TOP, z0 - 30, zA }, -- east
        { -W, -32, bottom, TOP - 6, z0 - 30, zA - 8 }, -- stepping back + down into the rim on both sides
        { 32, W, bottom, TOP - 6, z0 - 30, zA - 8 },
        { -wallOut, wallOut, bottom, TOP, z0 - 30, z0 - 2.6 }, -- behind the room
        { -wallOut, wallOut, 24.6, TOP, z0 - 2.6, zS }, -- over the room's roof
        { -wallOut, -corOut, bottom, TOP, zS, zA }, -- either side of the corridor
        { corOut, wallOut, bottom, TOP, zS, zA },
        { -corOut, corOut, 18.7, TOP, zS, zA }, -- over the corridor
    }
    local terrain = MapShell.Full() and not tpl.Parts -- (PARTY TWIN: a mirror takes the terrain path, writing nothing)
    if terrain then
        local T = MapShell.T()
        local mats = tpl.RimMat or { M.Rock, M.Slate }
        local main = mats[1]
        for _, b in ipairs(boxes) do
            local size = Vector3.new(b[2] - b[1], b[4] - b[3], b[6] - b[5])
            T:FillBlock(CFrame.new((b[1] + b[2]) / 2, (b[3] + b[4]) / 2, (b[5] + b[6]) / 2), size, main)
        end
        -- a broken skyline: boulders and tilted slabs along the top (behind the face, never over the corridor mouth)
        for i = 1, 9 do
            local x = rng:NextNumber(-W + 6, W - 6)
            local z = rng:NextNumber(z0 - 26, zA - 12)
            local r = rng:NextNumber(7, 13)
            T:FillBall(Vector3.new(x, TOP - 2 + rng:NextNumber(0, 6), z), r, mats[rng:NextInteger(1, #mats)])
            if i % 3 == 0 then
                local h = rng:NextNumber(12, 22)
                T:FillBlock(CFrame.new(x, TOP + h * 0.25, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3.14), rng:NextNumber(-0.3, 0.3)),
                    Vector3.new(rng:NextNumber(6, 10), h, rng:NextNumber(5, 8)), mats[rng:NextInteger(1, #mats)])
            end
        end
        -- the cliff foot: half-buried boulders along the face (never in front of the corridor mouth)
        for _ = 1, 7 do
            local x = rng:NextNumber(14, W - 6) * (rng:NextNumber() < 0.5 and -1 or 1)
            T:FillBall(Vector3.new(x, FLOOR_TOP + rng:NextNumber(-1, 2), zA - rng:NextNumber(1.5, 3)), rng:NextNumber(3.5, 5.5), mats[rng:NextInteger(1, #mats)])
        end
        -- the face toward the arena: a few shallow ledges so it isn't one flat wall (all behind the arena's wall line)
        for _ = 1, 6 do
            local x = rng:NextNumber(-W + 4, W - 4)
            if math.abs(x) > 18 and math.abs(x) < 30 then
                T:FillBlock(CFrame.new(x, rng:NextNumber(FLOOR_TOP + 8, TOP - 6), zA - 3) * CFrame.Angles(0, 0, rng:NextNumber(-0.4, 0.4)),
                    Vector3.new(rng:NextNumber(8, 16), rng:NextNumber(2, 4), 6), mats[rng:NextInteger(1, #mats)])
            end
        end
    else
        -- parts: natural maps get rock in the rim's stone, part-built maps a bulkhead in the room's wall surface
        local wc = (theme.Wall and theme.Wall.Color) or Color3.fromRGB(90, 90, 96)
        local dim = Color3.new(wc.R * 0.72, wc.G * 0.72, wc.B * 0.72) -- (a hair darker than the room: the face doesn't glare)
        local surf = tpl.Parts and { Color = dim, Material = theme.Wall.Material } or { Color = dim, Material = (tpl.RimMat and tpl.RimMat[1]) or M.Rock }
        -- (one surface for every block: Restyle skips blocks under 12 studs on their middle side, so the narrow boxes beside
        -- the corridor came out plain white plastic between textured panels)
        local mv = DungeonGenerator.RESTYLE[tpl.Biome or ""] and DungeonGenerator.RESTYLE[tpl.Biome][surf.Material.Name] or nil
        for _, b in ipairs(boxes) do
            if b[3] < FLOOR_TOP - 6 then b = { b[1], b[2], FLOOR_TOP - 6, b[4], b[5], b[6] } end -- (parts: no 60-deep pillars)
            local p = Block(fx, Vector3.new(b[2] - b[1], b[4] - b[3], b[6] - b[5]), CFrame.new((b[1] + b[2]) / 2, (b[3] + b[4]) / 2, (b[5] + b[6]) / 2), surf)
            p.CanQuery = false; p.CastShadow = false; p.Name = "EntryMassif"
            if mv then p.MaterialVariant = mv end
        end
        if tpl.Parts then
            -- a built bulkhead: structural ribs down the arena face + a cornice along the top (proud of every face, no shared planes)
            local trim = { Color = Color3.new(wc.R * 0.45, wc.G * 0.45, wc.B * 0.48), Material = M.DiamondPlate }
            for _, x in ipairs({ -30, -22, 22, 30 }) do
                local r = Block(fx, Vector3.new(2.2, TOP - FLOOR_TOP - 0.6, 1.3), CFrame.new(x, (FLOOR_TOP + TOP - 0.6) / 2, zA - 0.35), trim)
                r.CanQuery = false; r.CastShadow = false; r.Name = "EntryMassif"
            end
            local c = Block(fx, Vector3.new(66.6, 2.4, 2.3), CFrame.new(0, TOP - 0.9, zA - 0.75), trim) -- (front 0.1 past the ribs': never level)
            c.CanQuery = false; c.CastShadow = false; c.Name = "EntryMassif"
            for _, sx in ipairs({ -1, 1 }) do -- the stepped wings get their own cornice
                local w = Block(fx, Vector3.new(26.6, 1.8, 1.9), CFrame.new(sx * 45, TOP - 6.7, zA - 8.65), trim)
                w.CanQuery = false; w.CastShadow = false; w.Name = "EntryMassif"
            end
        end
        if not tpl.Parts then
            for _ = 1, 5 do -- a ragged top
                local p = Block(fx, Vector3.new(rng:NextNumber(10, 18), rng:NextNumber(6, 12), rng:NextNumber(8, 14)),
                    CFrame.new(rng:NextNumber(-W + 8, W - 8), TOP + 1, rng:NextNumber(z0 - 24, zA - 12)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 3.14), rng:NextNumber(-0.25, 0.25)), surf)
                p.CanQuery = false; p.CastShadow = false; p.Name = "EntryMassif"
            end
        end
    end
    -- the GATE round the corridor mouth (arena side): two jambs + a lintel, proud of the face, clear of every other plane.
    -- (MAPVIBE 2026-10-25, hubfix: with the darker pass-2 grades the gate in the world's raw trim colour read as a slab of
    -- paint -- Sakura's 26-stud vermilion lintel. Now the jambs + lintel are the room's own stone / wall (darkened like the
    -- massif), the trim colour is one band across the lintel's arena face (dimmed), and a darker cap beam sits on top.)
    local wcg = (theme.Wall and theme.Wall.Color) or Color3.fromRGB(90, 90, 96)
    local gateSurf = { Color = Color3.new(wcg.R * 0.62, wcg.G * 0.62, wcg.B * 0.62), Material = (theme.Wall and theme.Wall.Material) or M.Slate }
    local capSurf = { Color = Color3.new(wcg.R * 0.36, wcg.G * 0.36, wcg.B * 0.38), Material = (theme.Wall and theme.Wall.Material) or M.Slate }
    local tc = theme.WallTrim and theme.WallTrim.Color or nil
    local cw = layout.CorridorWidth / 2 -- 10 (corridor interior +-8)
    for _, sx in ipairs({ -1, 1 }) do
        local j = Block(fx, Vector3.new(4.2, 16.4, 3.4), CFrame.new(sx * (cw + 0.8), FLOOR_TOP + 6.2, zA - 0.4), gateSurf) -- (x 8.7..12.9: closes the slit to the massif)
        j.CanQuery = false; j.CastShadow = false; j.Name = "EntryGate"
    end
    local lin = Block(fx, Vector3.new(2 * cw + 6, 4, 3.8), CFrame.new(0, 16.65, zA - 0.2), gateSurf)
    lin.CanQuery = false; lin.CastShadow = false; lin.Name = "EntryGate"
    local cap = Block(fx, Vector3.new(2 * cw + 9, 1.1, 4.6), CFrame.new(0, 19.2, zA - 0.2), capSurf) -- (0.55 over the lintel top)
    cap.CanQuery = false; cap.CastShadow = false; cap.Name = "EntryGate"
    if tc then
        local band = Block(fx, Vector3.new(2 * cw + 5, 1.1, 0.3), CFrame.new(0, 16.65, zA + 1.85),
            { Color = Color3.new(tc.R * 0.78, tc.G * 0.78, tc.B * 0.78), Material = theme.WallTrim.Material or M.SmoothPlastic })
        band.CanQuery = false; band.CastShadow = false; band.Name = "EntryGate"
    end
end

-- (UPDATE 4 LAVA, owner: "The lava and such doesnt look as good as the other aspects") molten POOLS in a molten map's
-- CrackedLava ground patches (solo terrain floors): crust plates drifting over a churning core (LavaFX.Pool). Runs at the
-- END of the floor build (rims, kit, outcrops and later patches all fill terrain over the early patches): each spot is
-- raycast for the real surface (terrain renders ~2 studs over the floor), must still be CrackedLava, flat, clear of
-- parts, and out of the entry / chest plaza / portal row. Each lights the ground round it (range 30). Decoration only.
MapShell.LAVA_POOLS = 5
function MapShell.LavaPools()
    local job = MapShell.LavaSpots
    MapShell.LavaSpots = nil
    if not job or #job.Spots == 0 then return end
    if MapShell.Mirror and not IS_CLIENT then return end -- (PARTY TWIN: the members' copies pour their own)
    job.Channels = MapShell.LavaChannelZ or {} -- (this floor's lava channels, full width at these z)
    MapShell.LavaChannelZ = nil
    -- (the client's raycasts don't see terrain filled in the same frame: measure once the floor is in the world)
    task.spawn(function()
        for _ = 1, 20 do -- (up to ~6 s for the folder to be parented; gone = the floor was left)
            task.wait(0.3)
            if job.Fx:IsDescendantOf(Workspace) then MapShell.PlaceLavaPools(job); return end
            if not job.Fx.Parent then return end
        end
    end)
end
function MapShell.PlaceLavaPools(job: any)
    local Lava = DungeonGenerator.Lava()
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { Workspace.Terrain }
    local function Surface(x: number, z: number)
        if job.Party then return FLOOR_TOP, M.CrackedLava end -- (a server-built floor: the floor part is flat)
        local hit = Workspace:Raycast(Vector3.new(x, FLOOR_TOP + 40, z), Vector3.new(0, -60, 0), rp)
        return hit and hit.Position.Y, hit and hit.Material
    end
    local placed = {}
    local why = {} -- (Studio: the reason each spot was skipped, folder attr LavaPools)
    for _, s in ipairs(job.Spots) do
        if #placed >= MapShell.LAVA_POOLS then break end
        local p = s.P
        local r = math.clamp(s.R * 0.8, 3, 8)
        local dz = p.Z - job.ZC
        local ok = Vector3.new(p.X, 0, dz).Magnitude > 26 + r -- (the chest plaza)
            and not (math.abs(p.X) < 44 + r and dz > 10 - r and dz < 36 + r) -- (the portal row, zC + 16..30)
            and not KeptOut(Vector3.new(p.X, FLOOR_TOP, p.Z), r + 6)
        for _, cz in ipairs(job.Channels or {}) do
            if math.abs(p.Z - cz) < r + 6 then ok = false end -- (a crust bed over a lava channel)
        end
        for _, q in ipairs(placed) do
            if (q.P - p).Magnitude < q.R + r + 6 then ok = false end
        end
        local y, mat = Surface(p.X, p.Z)
        if not ok then table.insert(why, "zone") end
        if ok and not (y ~= nil and (mat == M.CrackedLava or s.Own) and y < FLOOR_TOP + 4) then
            ok = false; table.insert(why, string.format("surf %s %s", tostring(y and math.floor(y * 10) / 10), tostring(mat and mat.Name)))
        end
        if ok then
            for i = 0, 5 do -- flat all round (a pool over a slope cuts into it)
                local a = i / 6 * math.pi * 2
                local yy = Surface(p.X + math.cos(a) * r * 0.85, p.Z + math.sin(a) * r * 0.85)
                if not yy or math.abs(yy - y) > 0.7 then ok = false; table.insert(why, "slope"); break end
            end
        end
        if ok then -- nothing standing in it (kit props, cover, hitboxes)
            local o = OverlapParams.new()
            o.FilterType = Enum.RaycastFilterType.Exclude
            o.FilterDescendantsInstances = { Workspace.Terrain }
            local hits = Workspace:GetPartBoundsInBox(CFrame.new(p.X, y + 3.5, p.Z), Vector3.new(r * 1.7, 6, r * 1.7), o)
            if job.Party then -- (a server-built floor: lava channels / beds / rings lie AT floor level -- check from just under it)
                hits = {}
                for _, hp in ipairs(Workspace:GetPartBoundsInBox(CFrame.new(p.X, y + 3, p.Z), Vector3.new((r + 1.5) * 2, 6.6, (r + 1.5) * 2), o)) do
                    -- (hitboxes count; the floor slab, patch discs and the thin glowing floor veins -- which the bed covers -- don't)
                    if hp.Name ~= "GroundPatch" and not (hp.Size.X > 60 and hp.Size.Z > 60) and not (hp.Material == Enum.Material.Neon and hp.Size.Y < 0.5) then
                        table.insert(hits, hp)
                    end
                end
            end
            if #hits > 0 then ok = false; table.insert(why, "part " .. hits[1].Name) end
        end
        if ok then
            if s.Own and job.Party then -- (a crust disc on the floor part; the patch discs sit higher -- no shared planes)
                local bed = Block(job.Fx, Vector3.new(0.1, (r + 3) * 2, (r + 3) * 2), CFrame.new(p.X, y + 0.25, p.Z) * CFrame.Angles(0, 0, math.rad(90)),
                    { Color = C3(232, 220, 210), Material = M.CrackedLava })
                ;(bed :: Part).Shape = Enum.PartType.Cylinder
                bed.CanCollide = false; bed.CanQuery = false; bed.CanTouch = false; bed.CastShadow = false
                y += 0.25
            elseif s.Own then -- a round crust bed flush with the ground (fills down from the surface: the shape stays)
                Workspace.Terrain:FillCylinder(CFrame.new(p.X, y - 1.6, p.Z), 3.2, r + 3, M.CrackedLava)
            end
            Lava.Pool(job.Fx, CFrame.new(p.X, y + (s.Own and 0.12 or 0.04), p.Z), r, { Light = 30 }) -- (every pool lights its ground: the Molten floors read near-black)
            table.insert(placed, { P = p, R = r })
            table.insert(why, "POOL")
        end
    end
    if RunService:IsStudio() then job.Fx:SetAttribute("LavaPools", table.concat(why, "; ")) end
end
-- (UPDATE 4 wrap-up) stand rim pieces on the terrain hills they were placed in: placed = { { {instances}, spot } },
-- balls = { { centre, radius } } (the FillBall hills). The ground under a piece = the LOWEST hill surface over its
-- footprint (centre + 4 points), so a wide piece never hangs off a hump's shoulder; it sinks 12% of its height (cut base
-- hidden). The pieces get attr OnSurface (WorldKit.LiftLater leaves them alone: it would lift them a second time).
function MapShell.OnSurface(placed: { any }, balls: { any }, F: number)
    local function Ground(x: number, z: number): number
        local y = F
        for _, b in ipairs(balls) do
            local c, r = b[1], b[2]
            local dx, dz = x - c.X, z - c.Z
            local d2 = dx * dx + dz * dz
            if d2 < r * r then y = math.max(y, c.Y + math.sqrt(r * r - d2)) end
        end
        return y
    end
    for _, e in ipairs(placed) do
        local items, p = e[1], e[2]
        local main = items[1]
        if main then
            local size = main:IsA("Model") and select(2, (main :: Model):GetBoundingBox()) or (main :: BasePart).Size
            local rr = math.max(size.X, size.Z) * 0.3
            local g = Ground(p.X, p.Z)
            for _, o in ipairs({ Vector3.new(rr, 0, 0), Vector3.new(-rr, 0, 0), Vector3.new(0, 0, rr), Vector3.new(0, 0, -rr) }) do
                g = math.min(g, Ground(p.X + o.X, p.Z + o.Z))
            end
            local up = g - F - math.min(size.Y * 0.12, 1.6)
            if up > 0 then
                for _, it in ipairs(items) do
                    it:SetAttribute("OnSurface", true)
                    if it:IsA("Model") then it:PivotTo(it:GetPivot() + Vector3.new(0, up, 0))
                    elseif it:IsA("BasePart") then it.CFrame += Vector3.new(0, up, 0) end
                end
            end
        end
    end
end
function MapShell.Build(dungeon: Instance, geo: Instance, theme: any, biome: string, rng: Random, zC: number, arena: number, height: number, tpl: any, reserved: { any })
    MapShell.LavaSpots = nil -- (UPDATE 4 LAVA: a floor whose build broke off must not hand its spots to the next one)
    -- (MAPLOOK) the variation stream: a CLONE of the map rng seeds it, so the map rng's own draws (layout, cover) never move
    MapShell.VR = Random.new(rng:Clone():NextInteger(1, 1073741823) + 7)
    MapShell.RimLast = {}
    do -- (the new rock scans take the rim's own rock colour; the scan maps sit at a 0.6 mean, so the tint is lifted)
        local rm = (tpl.RimMat and tpl.RimMat[1]) or M.Rock
        local c = MapShell.RockColor(biome, rm) or ROCK_COLORS[rm] or Color3.fromRGB(96, 90, 86)
        MapShell.RockTint = Color3.new(math.min(c.R * 1.45, 1), math.min(c.G * 1.45, 1), math.min(c.B * 1.45, 1))
    end
    MapShell.LavaChannelZ = nil
    local fx = Instance.new("Folder")
    fx.Name = "MapShell"
    fx.Parent = dungeon
    local half = arena / 2
    local F = FLOOR_TOP
    local terrain = MapShell.Full() and not tpl.Parts and not tpl.Closed -- (PARTY TWIN: a mirror takes the terrain path, writing nothing)
    local ctx = { half = half, zC = zC, rng = rng, terrain = terrain }
    local T = MapShell.T()
    if not tpl.Closed then
        -- (after the previous floor's terrain is cleared, below) the arena's own blocks become rock
        ctx.coverMat = (tpl.RimMat and tpl.RimMat[1]) or (biome == "Ice" and M.Glacier) or (biome == "Void" and M.Slate) or (biome == "Storm" and M.Slate) or (biome == "Dream" and M.Glacier) or (biome == "Flats" and M.Sandstone) or M.Basalt
    end
    -- (what ShellPlace builds Outcrops from; Scatter, run after Build, reads it too)
    MapShell.Ctx = { mat = ctx.coverMat or M.Basalt, terrain = terrain, seam = (biome == "Fire") and M.CrackedLava or nil }
    local lights = 0
    local function Glow(name: string, pos: Vector3)
        local col = tpl.Glow and tpl.Glow[name]
        if col and not tpl.Closed and lights < 5 then lights += 1; GlowAt(fx, pos, col, 24) end -- (a closed room has its own lamps)
    end
    if IS_CLIENT then
        -- this client's previous floor terrain goes first (only the dungeon band: the hub's terrain is far north of it)
        local region = { CFrame.new(0, 40, zC), Vector3.new(arena + 300, 240, arena + 300) }
        T:FillBlock(region[1], region[2], M.Air)
        -- ...and it goes when this floor goes (back in the hub the cliffs would show over the walls). Generation guard:
        -- a newer floor may already have built its terrain here before the old folder is destroyed.
        MapShell.Gen = (MapShell.Gen or 0) + 1
        local gen = MapShell.Gen
        dungeon.AncestryChanged:Connect(function()
            if not dungeon:IsDescendantOf(game) and MapShell.Gen == gen then T:FillBlock(region[1], region[2], M.Air) end
        end)
    end
    -- (UPDATE 4 wrap-up: the room pieces take the biome's COVER STONE when it names one -- the rim's first material put
    -- square grass / sand / mud pillars and grass walls in half the worlds; RoomGen.DressFor)
    if not tpl.Closed and not tpl.Parts then
        local dress = require(script.Parent:WaitForChild("RoomGen")).DressFor(biome)
        MapShell.Terrainify(geo, zC, half, (dress and dress.Stone) or ctx.coverMat, terrain, biome)
    end
    if not tpl.Closed then
        -- ===== GROUND =====
        if terrain then
            T:FillBlock(CFrame.new(0, F - 3.05, zC), Vector3.new(arena + 220, 6, arena + 220), tpl.Ground)
            local lavaSpots = {} -- (UPDATE 4 LAVA: CrackedLava patches that can hold a molten pool; same rng order as before)
            for _ = 1, 26 do
                local p = Vector3.new(rng:NextNumber(-half - 10, half + 10), F - 3.05, zC + rng:NextNumber(-half - 10, half + 10))
                local yaw = rng:NextNumber(0, 3.14)
                local psz = Vector3.new(rng:NextNumber(8, 26), 6, rng:NextNumber(6, 18))
                local pmat = tpl.Patch[rng:NextInteger(1, #tpl.Patch)]
                MapShell.Patch(CFrame.new(p) * CFrame.Angles(0, yaw, 0), psz, pmat) -- (MAPLOOK: round, was a rectangle)
                if pmat == M.CrackedLava then table.insert(lavaSpots, { P = p, R = math.min(psz.X, psz.Z) / 2 }) end
            end
            if #lavaSpots > 0 then
                -- a few pools of their own on a molten map, each on a round crust bed (own seeded stream: the map's
                -- layout rng is untouched), tried before the random patches
                local lr = Random.new(math.floor(zC) * 31 + #tpl.Name * 7)
                local own = {}
                for i = 1, 7 do
                    local a = (i / 7) * math.pi * 2 + lr:NextNumber(-0.35, 0.35)
                    local d = lr:NextNumber(34, half + 8)
                    local pr = lr:NextNumber(4.5, 7.5)
                    local pp = Vector3.new(math.cos(a) * d, F - 3.05, zC + math.sin(a) * d)
                    table.insert(own, { P = pp, R = pr / 0.8, Own = true }) -- (its crust bed is laid when the pool goes in)
                end
                for _, sp in ipairs(lavaSpots) do table.insert(own, sp) end
                lavaSpots = own
            end
            MapShell.LavaSpots = { Fx = fx, Spots = lavaSpots, ZC = zC } -- (pools go in once ALL the terrain is built: MapShell.LavaPools)
        elseif not tpl.Parts then
            -- (UPDATE 4 PARTY FLOORS) no terrain on a server-built floor: round patch discs of the template's patch
            -- materials break up the floor part (each a little higher than the last: no shared planes), and a molten map
            -- gets its pools on crust beds (MapShell.LavaPools, party mode) -- own seeded stream, the layout rng untouched
            local pr = Random.new(math.floor(zC) * 17 + #tpl.Name * 3)
            local pal = { [M.CrackedLava] = C3(232, 220, 210) }
            local rockC = MapShell.PARTY_ROCK[biome]
            for i = 1, 12 do
                local pp = Vector3.new(pr:NextNumber(-half + 6, half - 6), F, zC + pr:NextNumber(-half + 6, half - 6))
                local pm = tpl.Patch[pr:NextInteger(1, #tpl.Patch)]
                local dia = pr:NextNumber(8, 20)
                local col = pal[pm] or (rockC and rockC:Lerp(Color3.new(1, 1, 1), pr:NextNumber(-0.05, 0.12))) or theme.FloorAlt.Color
                local d = Block(fx, Vector3.new(0.1, dia, dia * pr:NextNumber(0.7, 1)), CFrame.new(pp + Vector3.new(0, 0.03 + i * 0.012, 0))
                    * CFrame.Angles(0, pr:NextNumber(0, 6.28), 0) * CFrame.Angles(0, 0, math.rad(90)), { Color = col, Material = pm })
                ;(d :: Part).Shape = Enum.PartType.Cylinder
                d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.CastShadow = false
                d.Name = "GroundPatch"
            end
            local molten = false
            for _, pm in ipairs(tpl.Patch) do if pm == M.CrackedLava then molten = true end end
            if molten then
                local own = {}
                for i = 1, 14 do
                    local a = (i / 14) * math.pi * 2 + pr:NextNumber(-0.2, 0.2)
                    local dd = pr:NextNumber(32, half - 6)
                    local prr = pr:NextNumber(4.5, 7)
                    table.insert(own, { P = Vector3.new(math.cos(a) * dd, F, zC + math.sin(a) * dd), R = prr / 0.8, Own = true })
                end
                MapShell.LavaSpots = { Fx = fx, Spots = own, ZC = zC, Party = true }
            end
        end
        -- (the entry room + corridor have their own floors: no ground terrain humps poking up through them)
        local k = MapShell.KeepOut
        -- (from well under the room's own 4-stud floor: terrain left near its top surface z-fought with it -- owner 2026-10-05:
        -- "safe zone floors glitch out / flicker often")
        if terrain and k then T:FillBlock(CFrame.new(0, F + 26, (k.Z0 + k.Z1) / 2 - 1), Vector3.new(k.X * 2, 66, k.Z1 - k.Z0 - 2), M.Air) end
        -- ===== RIM: just outside the walls =====
        local rimMat = tpl.RimMat or { M.Rock, M.Slate }
        local function RimPoint(t: number, side: number, out: number): Vector3
            -- side 1..4 = west, east, north, south; t in -1..1 along the side
            local e = half + out
            if side == 1 then return Vector3.new(-e, F, zC + t * (half + out)) end
            if side == 2 then return Vector3.new(e, F, zC + t * (half + out)) end
            if side == 3 then return Vector3.new(t * (half + out), F, zC - e) end
            return Vector3.new(t * (half + out), F, zC + e)
        end
        if tpl.Rim == "Cliffs" and terrain then
            for side = 1, 4 do
                for t = -1, 1, 0.12 do
                    local p = RimPoint(t + rng:NextNumber(-0.04, 0.04), side, rng:NextNumber(8, 24))
                    local r = rng:NextNumber(9, 16)
                    local mat = rimMat[rng:NextInteger(1, #rimMat)]
                    if KeptOut(p, r + 14) then continue end
                    T:FillBall(p + Vector3.new(0, rng:NextNumber(-4, 8), 0), r, mat)
                    -- jagged faces: tilted slabs leaning out of the slope (balls alone read as round hills)
                    for _ = 1, 3 do
                        local h = rng:NextNumber(20, 46)
                        T:FillBlock(CFrame.new(p + Vector3.new(rng:NextNumber(-8, 8), h * 0.35, rng:NextNumber(-8, 8)))
                            * CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 3.14), rng:NextNumber(-0.35, 0.35)),
                            Vector3.new(rng:NextNumber(8, 16), h, rng:NextNumber(6, 12)), mat)
                    end
                    if rng:NextNumber() < 0.45 then
                        local q = RimPoint(t, side, rng:NextNumber(40, 70))
                        local qr = rng:NextNumber(28, 46)
                        if not KeptOut(q, qr) then
                            local hc = q + Vector3.new(0, rng:NextNumber(20, 55), 0)
                            local hm = rimMat[rng:NextInteger(1, #rimMat)]
                            T:FillBall(hc, qr, hm)
                            MapShell.Craggy(hc, qr, hm, MapShell.VR, KeptOut) -- (MAPLOOK: not a bald dome)
                        end
                    end
                end
            end
            -- the template's kit on the slopes (pines, crystals, spires...)
            for side = 1, 4 do
                for t = -1, 1, 0.22 do
                    local kit = tpl.RimKit[rng:NextInteger(1, #tpl.RimKit)]
                    local kp = RimPoint(t + rng:NextNumber(-0.06, 0.06), side, rng:NextNumber(3, 9))
                    if KeptOut(kp, 10) then continue end
                    MapShell.RimPiece(ShellPlace(biome, kit, CFrame.new(kp) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
                        { Tint = tpl.Tint and tpl.Tint[kit], Scale = rng:NextNumber(1.8, 3), Parent = fx, Shadow = false }, rng, MapShell.Ctx), MapShell.VR, "c" .. side, MapShell.OUT[side]) -- (MAPLOOK)
                end
            end
            if tpl.RimAccent then
                for _ = 1, 10 do
                    local p = RimPoint(rng:NextNumber(-1, 1), rng:NextInteger(1, 4), rng:NextNumber(10, 22))
                    if not KeptOut(p, 10) then T:FillBall(p + Vector3.new(0, rng:NextNumber(10, 30), 0), rng:NextNumber(5, 9), tpl.RimAccent) end
                end
            end
        elseif tpl.Rim == "Ruins" or (tpl.Rim == "Cliffs" and not terrain) then
            -- low broken ground + kit ruins along the rim; distant low hills (terrain) or bigger kit rocks (parts)
            -- (UPDATE 4 wrap-up: a template with RimSurface stands its rim kit ON the terrain hills -- Aztec's Sun Plaza sun
            -- stones stood at floor level inside the hill balls, buried. The balls are recorded (same rng draws, same
            -- order) and every piece the kit made is lifted onto the hills' surface: MapShell.OnSurface)
            local balls = (tpl.RimSurface and terrain) and {} or nil
            local placed = balls and {} or nil
            for side = 1, 4 do
                for t = -1, 1, 0.16 do
                    local p = RimPoint(t + rng:NextNumber(-0.05, 0.05), side, rng:NextNumber(6, 18))
                    if KeptOut(p, 18) then continue end
                    if terrain then
                        local dy = rng:NextNumber(-6, 4)
                        local br = rng:NextNumber(9, 16)
                        T:FillBall(p + Vector3.new(0, dy, 0), br, rimMat[rng:NextInteger(1, #rimMat)])
                        if balls then table.insert(balls, { p + Vector3.new(0, dy, 0), br }) end
                    end
                    local kit = tpl.RimKit[rng:NextInteger(1, #tpl.RimKit)]
                    local had = nil
                    if placed then had = {}; for _, c in ipairs(fx:GetChildren()) do had[c] = true end end
                    local rinst = ShellPlace(biome, kit, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), { Tint = tpl.Tint and tpl.Tint[kit], Scale = rng:NextNumber(2.2, 3.6), Parent = fx, Shadow = false }, rng, MapShell.Ctx)
                    if not had then MapShell.RimPiece(rinst, MapShell.VR, "r" .. side, MapShell.OUT[side]) end -- (MAPLOOK; RimSurface pieces are lifted by OnSurface)
                    if had then
                        local made = {}
                        for _, c in ipairs(fx:GetChildren()) do if not had[c] then table.insert(made, c) end end
                        table.insert(placed, { made, p })
                    end
                    if terrain and rng:NextNumber() < 0.4 then
                        local q, qr = RimPoint(t, side, rng:NextNumber(45, 80)), rng:NextNumber(24, 40)
                        if not KeptOut(q, qr) then
                            local qy = rng:NextNumber(0, 20)
                            local hm = rimMat[rng:NextInteger(1, #rimMat)]
                            T:FillBall(q + Vector3.new(0, qy, 0), qr, hm)
                            MapShell.Craggy(q + Vector3.new(0, qy, 0), qr, hm, MapShell.VR, KeptOut) -- (MAPLOOK: not a bald dome)
                            if balls then table.insert(balls, { q + Vector3.new(0, qy, 0), qr }) end
                        end
                    end
                end
            end
            if placed then MapShell.OnSurface(placed, balls, F) end
        elseif tpl.Rim == "Edge" then
            -- a chasm: the ground ends a little past the walls (the invisible walls keep everyone in); a few rocks cling on
            if terrain then
                for side = 1, 4 do
                    for t = -1, 1, 0.1 do
                        local p = RimPoint(t, side, rng:NextNumber(10, 22))
                        if not KeptOut(p, 18) then T:FillBall(p - Vector3.new(0, rng:NextNumber(10, 22), 0), rng:NextNumber(10, 18), rimMat[rng:NextInteger(1, #rimMat)]) end
                    end
                end
                -- cut the ground away beyond the edge
                for _, b in ipairs({ { Vector3.new(-(half + 130), 0, 0), Vector3.new(200, 60, arena + 400) }, { Vector3.new(half + 130, 0, 0), Vector3.new(200, 60, arena + 400) },
                    { Vector3.new(0, 0, -(half + 130)), Vector3.new(arena + 400, 60, 200) }, { Vector3.new(0, 0, half + 130), Vector3.new(arena + 400, 60, 200) } }) do
                    T:FillBlock(CFrame.new(b[1] + Vector3.new(0, F - 20, zC)), b[2], M.Air)
                end
            end
            for side = 1, 4 do
                for t = -1, 1, 0.25 do
                    local kit = tpl.RimKit[rng:NextInteger(1, #tpl.RimKit)]
                    local kp = RimPoint(t + rng:NextNumber(-0.08, 0.08), side, rng:NextNumber(4, 12))
                    if KeptOut(kp, 10) then continue end
                    MapShell.RimPiece(ShellPlace(biome, kit, CFrame.new(kp) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
                        { Tint = tpl.Tint and tpl.Tint[kit], Scale = rng:NextNumber(1.8, 3), Parent = fx, Shadow = false }, rng, MapShell.Ctx), MapShell.VR, "e" .. side, MapShell.OUT[side]) -- (MAPLOOK)
                end
            end
        end
        -- party (server) floors without terrain: a ring of big kit rocks so the edge isn't bare
        if not terrain and tpl.Rim == "Cliffs" then
            for side = 1, 4 do
                for t = -1, 1, 0.2 do
                    local kit = tpl.PartyRim or tpl.RimKit[1]
                    local kp = RimPoint(t, side, rng:NextNumber(14, 28))
                    if KeptOut(kp, 24) then continue end
                    MapShell.Vary(ShellPlace(biome, kit, CFrame.new(kp) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), { Tint = tpl.Tint and tpl.Tint[kit], Scale = rng:NextNumber(4, 6.5), Parent = fx, Shadow = false }, rng, MapShell.Ctx), MapShell.VR, "Rim") -- (MAPLOOK)
                end
            end
        end
        if tpl.Hero and HEROES[tpl.Hero] then
            local before = {}
            for _, d in ipairs(fx:GetDescendants()) do before[d] = true end
            -- (LINKED ROOMS pilot: the landmark stands past the EXIT room -- MapShell.LinkHeroZ -- not on top of room 2)
            HEROES[tpl.Hero](fx, MapShell.LinkHeroZ and setmetatable({ zC = MapShell.LinkHeroZ }, { __index = ctx }) or ctx)
            -- (no landmark piece may stand in the entry room / corridor -- owner 2026-10-05: "cyber room has a giant pillar
            -- prop in it" = a Skyline tower landing on the safe room; its neon band z-fought the room's floor glow)
            local k = MapShell.KeepOut
            if k then
                for _, d in ipairs(fx:GetDescendants()) do
                    if not before[d] and d:IsA("BasePart") and d.Parent then
                        local bb = d.Position.Y - d.Size.Y / 2
                        local ext = d.Size / 2
                        local reach = math.max(ext.X, ext.Z)
                        if bb < FLOOR_TOP + 40 and KeptOut(d.Position, reach) then d:Destroy() end
                    end
                end
            end
        end
        MapShell.Vista(fx, biome, tpl, zC, half)
    end
    if tpl.Closed and tpl.Rows then
        -- rows of the template's wall kit (server racks) flush along both side walls, facing in
        for _, sx in ipairs({ -1, 1 }) do
            for z = -half + 14, half - 14, 7 do
                local p = Vector3.new(sx * (half - 4.5), F, zC + z)
                if FreeSpot(reserved, p, 3) then
                    EnvKit.Place(biome, tpl.Rows, CFrame.lookAt(p, p + Vector3.new(-sx, 0, 0)), { Scale = 1.6, Parent = fx, Hitbox = true, HitScale = 0.7, HitParent = geo })
                end
            end
        end
    end
    -- ===== EDGE DRESSING: kit props inside the box along the walls (solid: box hitboxes in geo, bots steer round them) =====
    local placed = 0
    local rk0 = "R0:" .. math.floor(zC + 0.5)
    if MapShell.PropsOn() and MapShell.VR and not MapShell.Boss then -- (MAPVIBE pass 2: the entry + exit doorways get a matched pair each)
        MapShell.Flank(biome, tpl, { Vector3.new(0, F, zC - half), Vector3.new(0, F, zC + half) }, 0, zC, half, reserved, rk0, { Parent = fx, HitParent = geo }, MapShell.VR)
    end
    local edgeMax = 12
    if MapShell.PropsOn() and MapShell.VR and not MapShell.Boss then -- (pass 3: every wall in bays; the old loop is skipped)
        edgeMax = 0
        MapShell.DressMiss, MapShell.DressEmpty = 0, 0
        dungeon:SetAttribute("DressedR0", MapShell.DressWalls(biome, tpl, 0, zC, half, reserved, rk0, { Parent = fx, HitParent = geo }, MapShell.VR, 1.5))
        dungeon:SetAttribute("DressMissR0", MapShell.DressMiss .. "/" .. MapShell.DressEmpty .. " pool " .. #MapShell.PropPool(biome, tpl).A .. "," .. #MapShell.PropPool(biome, tpl).M .. "," .. #MapShell.PropPool(biome, tpl).S)
    end
    for _ = 1, (edgeMax > 0) and 60 or 0 do
        if placed >= edgeMax then break end -- (0.65: 16 -> 12, fewer props blocking shots; MAPVIBE pass 2: 8 + doorway pairs)
        local side = rng:NextInteger(1, 4)
        local t = rng:NextNumber(-0.9, 0.9)
        local inset = rng:NextNumber(5, 13)
        local p
        if side == 1 then p = Vector3.new(-half + inset, F, zC + t * half)
        elseif side == 2 then p = Vector3.new(half - inset, F, zC + t * half)
        elseif side == 3 then p = Vector3.new(t * half, F, zC - half + inset)
        else p = Vector3.new(t * half, F, zC + half - inset) end
        local out = MapShell.OUT[side]
        local wall = p + out * inset -- (MAPVIBE pass 2: on the wall line, in the nearest bay)
        if side <= 2 then wall = Vector3.new(wall.X, F, zC + MapShell.Bay(t) * half) else wall = Vector3.new(MapShell.Bay(t) * half, F, wall.Z) end
        local pv = (MapShell.PropsOn() and MapShell.VR) and (wall - out * 6) or p
        if FreeSpot(reserved, pv, 6) then
            local kit = tpl.Edge[rng:NextInteger(1, #tpl.Edge)]
            if MapShell.PropsOn() and MapShell.VR then -- (MAPVIBE PROP SETS: the pick + set piece on MapShell.VR)
                local _, sc = rng:NextNumber(0, 6.28), rng:NextNumber(1.3, 1.9)
                local inst, reach, ctr = MapShell.Compose(biome, tpl, wall, out, sc, rk0, { Parent = fx, HitParent = geo }, MapShell.VR)
                placed += 1 -- (a bare spot counts: fewer, better)
                table.insert(reserved, { Pos = ctr or pv, R = inst and math.max(6, reach) or 6 })
                if inst then Glow(inst.Name, (ctr or pv) + Vector3.new(0, 4, 0)) end
            else
            local inst = ShellPlace(biome, kit, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
                { Tint = tpl.Tint and tpl.Tint[kit], Scale = rng:NextNumber(1.3, 1.9), Parent = fx, Hitbox = true, HitScale = 0.65, HitParent = geo }, rng, MapShell.Ctx)
            if inst then
                placed += 1
                table.insert(reserved, { Pos = p, R = 6 })
                MapShell.Vary(inst, MapShell.VR, "Tint") -- (MAPLOOK: own tint only -- it has a hitbox)
                Glow(kit, p + Vector3.new(0, 4, 0))
            end
            end
        end
    end
    dungeon:SetAttribute("MapTemplate", tpl.Name)
end

-- ==================== BOSS ARENAS (0.48; owner: "Boss fight areas need to make more sense, they should have special,
-- incredibly well made arenas") ====================
-- Boss floors no longer reuse the regular combat room (vantage pillars, jump pads, wall-run traversal, scattered cover:
-- you could stand above attacks and the fight read as any other floor). Same gameplay box (BuildChamber walls, entry
-- doorway north, portal row at zC + 16..30 (0.60; was 46..62), victory chest in the middle) but a designed arena:
--   * one clean FIGHT FLOOR disk (radius RF) with inlaid rings -- every telegraph reads on it -- and a centre seal
--   * an ENTRANCE GATE framing the north doorway, so you walk INTO an arena
--   * 4 low curved COVER barriers (waist high: they block shots, you can't perch above an attack on them)
--   * a biome SET PIECE round the rim (r > RF): Molten caldera forge, Glacier frozen colosseum, Void shattered altar,
--     Cyber server core, Storm tesla crown. Static parts, <= 4 lights, ~150-230 parts.
-- Decoration that bosses / bots must steer round goes in geo (StaticGeometry); pure dressing in "ArenaDecor".
do
    local RF = 84 -- fight floor radius (the chamber walls stand at 120)
    local function Seg(parent, r, a0, a1, y, h, thick, surf, trim)
        -- one arc segment of a ring wall: a block tangent to the circle between angles a0..a1 (radians)
        local am = (a0 + a1) / 2
        local w = 2 * r * math.sin((a1 - a0) / 2) + 0.4
        local cf = CFrame.new(math.sin(am) * r, y, math.cos(am) * r) * CFrame.Angles(0, am, 0)
        return Block(parent, Vector3.new(w, h, thick), cf, surf)
    end
    local function Ring(parent, center, r, n, y, h, thick, surf, gaps)
        local parts = {}
        for i = 0, n - 1 do
            local a0, a1 = i / n * 2 * math.pi, (i + 1) / n * 2 * math.pi
            local am = (a0 + a1) / 2
            local skip = false
            for _, g in ipairs(gaps or {}) do
                local d = math.abs(((am - g[1] + math.pi) % (2 * math.pi)) - math.pi)
                if d < g[2] then skip = true end
            end
            if not skip then
                local p = Seg(parent, r, a0, a1, y, h, thick, surf)
                p.CFrame = CFrame.new(center) * p.CFrame
                table.insert(parts, p)
            end
        end
        return parts
    end
    local function Disk(parent, pos, dia, h, surf)
        local p = Block(parent, Vector3.new(h, dia, dia), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), surf)
        ;(p :: Part).Shape = Enum.PartType.Cylinder
        return p
    end
    local function Glow(p, color)
        p.Material = Enum.Material.Neon; p.Color = color; p.CastShadow = false
        p:SetAttribute("Glow", true)
        return p
    end
    local function Decor(p) p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false; return p end
    local function Light(parent, pos, color, range, bright)
        local a = Block(parent, Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), { Color = color, Material = Enum.Material.SmoothPlastic, Transparency = 1 })
        Decor(a)
        local l = Instance.new("PointLight"); l.Color = color; l.Range = range; l.Brightness = bright; l.Shadows = false; l.Parent = a
    end
    -- the north doorway (entry) and the south wall stay open: (angle, half-width) in radians; angle 0 = +z
    local GAPS = { { math.pi, math.rad(16) }, { 0, math.rad(12) } }

    local SETPIECE = {}

    -- MOLTEN: CALDERA FORGE -- a basalt fighting ring over a lava moat, forge spires with glowing seams, braziers
    SETPIECE.Fire = function(geo, deco, c, rng, F)
        local lava = { Color = C3(255, 110, 30), Material = Enum.Material.CrackedLava }
        Disk(deco, c + Vector3.new(0, F - 0.55, 0), (RF + 14) * 2, 1, { Color = C3(232, 220, 210), Material = Enum.Material.CrackedLava }) -- the moat crust under the rim
        Ring(geo, c, RF + 2, 28, F + 0.6, 1.2, 3, { Color = C3(46, 38, 36), Material = Enum.Material.Basalt }, GAPS) -- ring curb
        for i = 0, 5 do
            local a = (i + 0.5) / 6 * 2 * math.pi
            if math.abs(((a - math.pi + math.pi) % (2 * math.pi)) - math.pi) > 0.4 then
                local p = Vector3.new(math.sin(a) * 104, F, math.cos(a) * 104) + c
                local h = rng:NextNumber(34, 46)
                -- (UPDATE 4 PROPS + LAVA) a hexagonal basalt spire (EnvKit Fire/BasaltSpire) rising out of a molten pool;
                -- the stacked stones with Neon seams stay as the fallback for an unsaved place
                local EK = require(script.Parent:WaitForChild("EnvKit"))
                if EK.Has("Fire", "BasaltSpire") then
                    EK.Place("Fire", "BasaltSpire", CFrame.new(p) * CFrame.Angles(0, a + rng:NextNumber(-0.5, 0.5), 0),
                        { Scale = h / 17, Parent = deco, Hitbox = Vector3.new(12, h, 12), HitParent = geo, Shadow = false })
                    DungeonGenerator.Lava().Pool(deco, CFrame.new(p + Vector3.new(0, 0.1, 0)), 9, { Light = false, Smoke = false })
                    continue
                end
                for k = 0, 3 do -- a tapering spire in 4 stacked stones
                    local s = 13 - k * 2.6
                    local seg = Block(geo, Vector3.new(s, h / 4, s), CFrame.new(p + Vector3.new(0, h / 8 + k * h / 4, 0)) * CFrame.Angles(0, a + k * 0.3, 0),
                        { Color = C3(52 - k * 4, 42 - k * 3, 40 - k * 3), Material = Enum.Material.Basalt })
                    local _ = seg
                    Glow(Decor(Block(deco, Vector3.new(s + 0.3, 0.5, s + 0.3), CFrame.new(p + Vector3.new(0, (k + 1) * h / 4, 0)) * CFrame.Angles(0, a + k * 0.3, 0),
                        lava)), C3(255, 120 - k * 10, 40))                                               -- molten seam between stones
                end
            end
        end
        for _, a in ipairs({ math.rad(60), math.rad(-60), math.rad(130), math.rad(-130) }) do -- braziers on the rim
            local p = c + Vector3.new(math.sin(a) * (RF + 7), F, math.cos(a) * (RF + 7))
            Block(geo, Vector3.new(4, 5, 4), CFrame.new(p + Vector3.new(0, 2.5, 0)), { Color = C3(40, 34, 32), Material = Enum.Material.Slate })
            -- (UPDATE 4 LAVA) an iron bowl of glowing coals under the flames (was a Neon slab)
            local bowl = Decor(Block(deco, Vector3.new(4.6, 0.8, 4.6), CFrame.new(p + Vector3.new(0, 5.4, 0)), { Color = C3(58, 50, 46), Material = Enum.Material.CorrodedMetal }))
            DungeonGenerator.Lava().Pool(deco, CFrame.new(p + Vector3.new(0, 5.82, 0)), 1.9, { Light = false, Smoke = false })
            local fire = Instance.new("Fire"); fire.Size = 6; fire.Heat = 9; fire.Color = C3(255, 120, 40); fire.SecondaryColor = C3(255, 200, 80); fire.Parent = bowl
        end
        Light(deco, c + Vector3.new(0, F + 14, 0), C3(255, 140, 70), 60, 1.2)
        -- (UPDATE 4 LAVA: the moat lights the fight floor's edge and the stands -- the arena read near-black)
        for k = 0, 2 do
            local a = (k + 0.5) / 3 * 2 * math.pi + math.pi
            Light(deco, c + Vector3.new(math.sin(a) * (RF + 6), F + 6, math.cos(a) * (RF + 6)), C3(255, 120, 50), 48, 1.6)
        end
        return C3(255, 120, 40)
    end

    -- GLACIER: FROZEN COLOSSEUM -- tiered ice stands with arches round the ring, crystal obelisks, a frost seal
    SETPIECE.Ice = function(geo, deco, c, rng, F)
        local brick = { Color = C3(170, 196, 216), Material = Enum.Material.Glacier }
        local dark = { Color = C3(96, 116, 138), Material = Enum.Material.Slate }
        for tier = 0, 2 do -- three stepped tiers of stands
            Ring(geo, c, RF + 8 + tier * 7, 30, F + 2 + tier * 3.5, 4 + tier * 7, 6, tier % 2 == 0 and brick or dark, GAPS)
        end
        for i = 0, 11 do -- arches crowning the top tier
            local a = (i + 0.5) / 12 * 2 * math.pi
            if math.abs(((a - math.pi + math.pi) % (2 * math.pi)) - math.pi) > 0.35 and math.abs(((a + math.pi) % (2 * math.pi)) - math.pi) > 0.3 then
                local r = RF + 24
                local base = c + Vector3.new(math.sin(a) * r, F + 18, math.cos(a) * r)
                for _, side in ipairs({ -1, 1 }) do
                    local off = Vector3.new(math.cos(a), 0, -math.sin(a)) * 4 * side
                    Block(geo, Vector3.new(1.6, 10, 2), CFrame.new(base + off + Vector3.new(0, 5, 0)) * CFrame.Angles(0, a, 0), brick)
                end
                Block(geo, Vector3.new(10, 1.6, 2.4), CFrame.new(base + Vector3.new(0, 10.8, 0)) * CFrame.Angles(0, a, 0), dark)
            end
        end
        for _, a in ipairs({ math.rad(45), math.rad(-45), math.rad(135), math.rad(-135) }) do -- crystal obelisks
            local p = c + Vector3.new(math.sin(a) * (RF + 3), F, math.cos(a) * (RF + 3))
            local cr = Block(geo, Vector3.new(4, 22, 4), CFrame.new(p + Vector3.new(0, 11, 0)) * CFrame.Angles(0, a, math.rad(6)),
                { Color = C3(150, 210, 240), Material = Enum.Material.Ice, Transparency = 0.15 })
            local _ = cr
            Glow(Decor(Block(deco, Vector3.new(1.2, 18, 1.2), CFrame.new(p + Vector3.new(0, 11, 0)) * CFrame.Angles(0, a, math.rad(6)),
                { Color = C3(200, 240, 255), Material = Enum.Material.Neon })), C3(170, 230, 255))
        end
        Light(deco, c + Vector3.new(0, F + 18, 0), C3(200, 230, 255), 75, 0.9)
        return C3(140, 210, 255)
    end

    -- VOID: SHATTERED ALTAR -- a rune-carved altar disc, monolith shards hanging tilted round it, rune pylons
    SETPIECE.Void = function(geo, deco, c, rng, F)
        local stone = { Color = C3(70, 60, 92), Material = Enum.Material.Slate }
        Ring(geo, c, RF + 2, 30, F + 0.5, 1, 3, { Color = C3(54, 46, 72), Material = Enum.Material.Basalt }, GAPS)
        for i = 0, 9 do -- floating monolith shards (static, tilted, at different heights)
            local a = (i + 0.3) / 10 * 2 * math.pi
            local r = rng:NextNumber(98, 112)
            local p = c + Vector3.new(math.sin(a) * r, F + rng:NextNumber(14, 34), math.cos(a) * r)
            local h = rng:NextNumber(22, 38)
            Decor(Block(deco, Vector3.new(rng:NextNumber(6, 10), h, rng:NextNumber(4, 7)), CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), a, rng:NextNumber(-0.5, 0.5)), stone))
            Glow(Decor(Block(deco, Vector3.new(0.4, h * 0.7, 0.4), CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), a, rng:NextNumber(-0.5, 0.5)),
                { Color = C3(180, 120, 255), Material = Enum.Material.Neon })), C3(170, 110, 250))
        end
        for _, a in ipairs({ math.rad(50), math.rad(-50), math.rad(140), math.rad(-140) }) do -- rune pylons
            local p = c + Vector3.new(math.sin(a) * (RF + 6), F, math.cos(a) * (RF + 6))
            Block(geo, Vector3.new(5, 16, 5), CFrame.new(p + Vector3.new(0, 8, 0)) * CFrame.Angles(0, a, 0), stone)
            Glow(Decor(Block(deco, Vector3.new(5.3, 1, 5.3), CFrame.new(p + Vector3.new(0, 12, 0)) * CFrame.Angles(0, a, 0), stone)), C3(190, 130, 255))
            Glow(Decor(Block(deco, Vector3.new(2.4, 2.4, 2.4), CFrame.new(p + Vector3.new(0, 18, 0)) * CFrame.Angles(math.rad(45), a, math.rad(45)), stone)), C3(220, 170, 255))
        end
        for i = 0, 15 do -- the rune circle: glowing dashes inlaid round the fight floor
            if i % 4 ~= 0 then
                local s = Seg(deco, 68, i / 16 * 2 * math.pi + 0.04, (i + 1) / 16 * 2 * math.pi - 0.04, F + 0.24, 0.05, 1.2, stone)
                s.CFrame = CFrame.new(c) * s.CFrame
                Glow(Decor(s), C3(180, 120, 255))
            end
        end
        Light(deco, c + Vector3.new(0, F + 16, 0), C3(190, 150, 255), 75, 1.1)
        return C3(170, 110, 250)
    end

    -- CYBER: SERVER CORE -- an octagonal deck, data pylons with light strips, cable trenches, a holo ring overhead
    SETPIECE.Cyber = function(geo, deco, c, rng, F)
        local steel = { Color = C3(52, 58, 70), Material = Enum.Material.DiamondPlate }
        local dark = { Color = C3(28, 32, 40), Material = Enum.Material.Metal }
        for i = 0, 7 do -- octagon rim
            local a0, a1 = i / 8 * 2 * math.pi + math.pi / 8, (i + 1) / 8 * 2 * math.pi + math.pi / 8
            local am = (a0 + a1) / 2
            local gap = math.abs(((am - math.pi + math.pi) % (2 * math.pi)) - math.pi) < 0.3 or math.abs(((am + math.pi) % (2 * math.pi)) - math.pi) < 0.3
            if not gap then
                local p = Seg(geo, RF + 3, a0, a1, F + 0.9, 1.8, 3, dark); p.CFrame = CFrame.new(c) * p.CFrame
                local s = Seg(deco, RF + 3, a0, a1, F + 1.85, 0.25, 3.2, dark); s.CFrame = CFrame.new(c) * s.CFrame
                Glow(Decor(s), C3(60, 230, 255))
            end
        end
        for i = 0, 7 do -- data pylons
            local a = (i + 0.5) / 8 * 2 * math.pi + math.pi / 8
            if math.abs(((a - math.pi + math.pi) % (2 * math.pi)) - math.pi) > 0.3 then
                local p = c + Vector3.new(math.sin(a) * 104, F, math.cos(a) * 104)
                local h = rng:NextNumber(26, 36)
                Block(geo, Vector3.new(7, h, 7), CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, a, 0), steel)
                for k = 1, 3 do
                    Glow(Decor(Block(deco, Vector3.new(7.3, 0.4, 7.3), CFrame.new(p + Vector3.new(0, h * k / 4, 0)) * CFrame.Angles(0, a, 0), dark)),
                        (k % 2 == 0) and C3(255, 60, 180) or C3(60, 230, 255))
                end
            end
        end
        for i = 0, 7 do -- radial cable trenches into the core
            local a = (i + 0.5) / 8 * 2 * math.pi
            local mid = c + Vector3.new(math.sin(a) * 60, F + 0.14, math.cos(a) * 60)
            Decor(Block(deco, Vector3.new(2, 0.08, 36), CFrame.new(mid) * CFrame.Angles(0, a, 0), { Color = C3(20, 22, 28), Material = Enum.Material.Metal }))
        end
        local holo = Ring(deco, c + Vector3.new(0, F + 34, 0), 40, 20, 0, 0.6, 0.6, { Color = C3(60, 230, 255), Material = Enum.Material.Neon })
        for _, p in ipairs(holo) do Decor(p); p.Transparency = 0.35 end
        Light(deco, c + Vector3.new(0, F + 16, 0), C3(90, 220, 255), 75, 1.0)
        return C3(60, 230, 255)
    end

    -- STORMSPIRE: TESLA CROWN -- a grated deck ringed by lightning rods with copper coils, cables between them
    SETPIECE.Storm = function(geo, deco, c, rng, F)
        local metal = { Color = C3(70, 76, 84), Material = Enum.Material.Metal }
        local copper = { Color = C3(184, 110, 60), Material = Enum.Material.Metal }
        Ring(geo, c, RF + 2, 30, F + 0.5, 1, 3, { Color = C3(58, 62, 70), Material = Enum.Material.DiamondPlate }, GAPS)
        local tips = {}
        for i = 0, 7 do
            local a = (i + 0.5) / 8 * 2 * math.pi
            if math.abs(((a - math.pi + math.pi) % (2 * math.pi)) - math.pi) > 0.3 then
                local p = c + Vector3.new(math.sin(a) * 100, F, math.cos(a) * 100)
                local h = 50
                Block(geo, Vector3.new(10, 6, 10), CFrame.new(p + Vector3.new(0, 3, 0)), metal)
                Glow(Decor(Block(deco, Vector3.new(10.3, 0.5, 10.3), CFrame.new(p + Vector3.new(0, 5.6, 0)), metal)), C3(130, 190, 255))
                local rod = Block(geo, Vector3.new(h, 3.4, 3.4), CFrame.new(p + Vector3.new(0, h / 2 + 6, 0)) * CFrame.Angles(0, 0, math.rad(90)), metal)
                ;(rod :: Part).Shape = Enum.PartType.Cylinder
                for k = 1, 5 do
                    local coil = Block(deco, Vector3.new(1.4, 7 - k * 0.6, 7 - k * 0.6), CFrame.new(p + Vector3.new(0, 10 + k * 7, 0)) * CFrame.Angles(0, 0, math.rad(90)), copper)
                    ;(coil :: Part).Shape = Enum.PartType.Cylinder
                    Decor(coil)
                end
                local tip = Glow(Decor(Block(deco, Vector3.new(3.6, 3.6, 3.6), CFrame.new(p + Vector3.new(0, h + 8, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), metal)), C3(150, 200, 255))
                table.insert(tips, tip.Position)
            end
        end
        for i = 1, #tips - 1 do -- sagging cables between neighbouring rods
            local a, b = tips[i] - Vector3.new(0, 6, 0), tips[i + 1] - Vector3.new(0, 6, 0)
            local d = (b - a)
            Decor(Block(deco, Vector3.new(0.25, 0.25, d.Magnitude), CFrame.lookAt((a + b) / 2 - Vector3.new(0, 1.5, 0), b), { Color = C3(30, 32, 36), Material = Enum.Material.Metal }))
        end
        Light(deco, c + Vector3.new(0, F + 16, 0), C3(170, 205, 255), 75, 1.0)
        return C3(150, 200, 255)
    end

    -- ===== BOSS STAGES v2 (0.58, owner: "Boss stages need to feel more unique") =====
    -- Every biome's fight floor gets its OWN floor art instead of the shared inlaid rings (all flat decor a hair over the
    -- disc: telegraphs still read on it), and a MARQUEE over the far rim names the boss (its BossTitle, once it spawns).
    local function Strip(parent, a: Vector3, b: Vector3, w: number, surf: any, y: number)
        local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
        local mid = Vector3.new((a.X + b.X) / 2, y, (a.Z + b.Z) / 2)
        return Decor(Block(parent, Vector3.new(w, 0.04, d.Magnitude + w * 0.5), CFrame.lookAt(mid, mid + d), surf))
    end
    local function Polar(c: Vector3, r: number, a: number): Vector3 return c + Vector3.new(math.sin(a) * r, 0, math.cos(a) * r) end
    local FLOORART = {}
    -- MOLTEN: a cracked basalt seal, eight magma channels running out from a glowing core, rune diamonds round it
    FLOORART.Fire = function(deco, c, F, accent, rng)
        local y = F + 0.16
        -- (UPDATE 4 LAVA) molten channels (LavaFX.Flow ribbons, flowing out) round a molten core pool, not Neon strips;
        -- a little dimmer than the pools so the orange telegraphs still read on the fight floor
        local Lava = DungeonGenerator.Lava()
        local tint = Color3.new(1, 1, 1):Lerp(accent, 0.25)
        for i = 0, 7 do
            local a = i / 8 * math.pi * 2 + 0.2
            local p = Polar(c, 14, a)
            for k = 1, 5 do
                local q = Polar(c, 14 + k * 13, a + rng:NextNumber(-0.12, 0.12))
                Lava.Flow(deco, Vector3.new(p.X, y, p.Z), Vector3.new(q.X, y, q.Z), (1.6 - k * 0.18) * 1.7,
                    { Light = false, Smoke = false, Sparks = false, Speed = 0.12, Bright = 1.35, Tint = tint })
                p = q
            end
            local r = Polar(c, 42, a + math.pi / 8)
            Lava.Pool(deco, CFrame.new(r.X, y, r.Z), 1.9, { Light = false, Smoke = false, Sparks = false, Bright = 1.4, Tint = tint })
        end
        Lava.Pool(deco, CFrame.new(c.X, y, c.Z), 7, { Light = 44, Smoke = false, Bright = 1.5, Tint = tint })
    end
    -- GLACIER: a frozen lake -- pale ice over the floor, white crack lines, a frost rim
    FLOORART.Ice = function(deco, c, F, accent, rng)
        local y = F + 0.14
        local ice = Decor(Disk(deco, c + Vector3.new(0, y, 0), 156, 0.04, { Color = C3(170, 214, 240), Material = Enum.Material.Glacier }))
        ice.Reflectance = 0.12
        for _ = 1, 9 do
            local a = rng:NextNumber(0, math.pi * 2)
            local p = Polar(c, rng:NextNumber(4, 30), a)
            for _ = 1, rng:NextInteger(3, 5) do
                a += rng:NextNumber(-0.5, 0.5)
                local q = p + Vector3.new(math.sin(a), 0, math.cos(a)) * rng:NextNumber(8, 14)
                if (q - c).Magnitude > 74 then break end
                Strip(deco, p, q, 0.35, { Color = C3(240, 250, 255), Material = Enum.Material.SmoothPlastic, Transparency = 0.25 }, y + 0.03)
                p = q
            end
        end
        for _, part in ipairs(Ring(deco, c + Vector3.new(0, y + 0.03, 0), 76, 28, 0, 0.05, 2.2, { Color = C3(245, 252, 255), Material = Enum.Material.Snow })) do Decor(part) end
    end
    -- VOID: a SUMMONING CIRCLE -- double ring, a hexagram, glyph points, an inner ring
    FLOORART.Void = function(deco, c, F, accent, rng)
        local y = F + 0.16
        local glow = { Color = accent, Material = Enum.Material.Neon }
        for _, r in ipairs({ 72, 66, 20 }) do
            for _, part in ipairs(Ring(deco, c + Vector3.new(0, y, 0), r, 36, 0, 0.04, (r == 20) and 1 or 1.4, glow)) do Glow(Decor(part), accent) end
        end
        for t = 0, 1 do
            for i = 0, 2 do
                local a0 = (i / 3 + t / 6) * math.pi * 2
                local a1 = ((i + 1) / 3 + t / 6) * math.pi * 2
                Glow(Strip(deco, Polar(c, 66, a0), Polar(c, 66, a1), 1.1, glow, y + 0.01), accent)
            end
        end
        for i = 0, 5 do
            local q = Polar(c, 72, i / 6 * math.pi * 2)
            Glow(Decor(Block(deco, Vector3.new(4, 0.05, 4), CFrame.new(q.X, y + 0.02, q.Z) * CFrame.Angles(0, math.rad(45), 0), glow)), C3(255, 140, 230))
        end
    end
    -- CYBER: the floor is a lit circuit grid -- neon lines both ways, cut to the circle, cyan / magenta
    FLOORART.Cyber = function(deco, c, F, accent, rng)
        local y = F + 0.16
        for k = -4, 4 do
            local off = k * 16
            local half = math.sqrt(math.max(0, 76 * 76 - off * off))
            local col = (k % 2 == 0) and C3(60, 230, 255) or C3(255, 60, 180)
            local g = { Color = col, Material = Enum.Material.Neon, Transparency = 0.35 }
            Glow(Strip(deco, c + Vector3.new(off, 0, -half), c + Vector3.new(off, 0, half), 0.5, g, y), col).Transparency = 0.35
            Glow(Strip(deco, c + Vector3.new(-half, 0, off), c + Vector3.new(half, 0, off), 0.5, g, y + 0.01), col).Transparency = 0.35
        end
        Glow(Decor(Disk(deco, c + Vector3.new(0, y + 0.02, 0), 14, 0.04, { Color = accent, Material = Enum.Material.Neon })), C3(60, 230, 255))
    end
    -- STORM: rain-soaked flagstone -- dark puddles that catch the sky, three lightning scars burnt into it
    FLOORART.Storm = function(deco, c, F, accent, rng)
        local y = F + 0.15
        for _ = 1, 12 do
            local q = Polar(c, rng:NextNumber(10, 70), rng:NextNumber(0, math.pi * 2))
            local w = rng:NextNumber(6, 14)
            local pud = Decor(Block(deco, Vector3.new(0.04, w, w * rng:NextNumber(0.5, 0.9)), CFrame.new(q.X, y, q.Z) * CFrame.Angles(0, rng:NextNumber(0, 3), math.rad(90)),
                { Color = C3(40, 48, 62), Material = Enum.Material.SmoothPlastic }))
            ;(pud :: Part).Shape = Enum.PartType.Cylinder
            pud.Reflectance = 0.3
        end
        for _ = 1, 3 do
            local a = rng:NextNumber(0, math.pi * 2)
            local p = Polar(c, rng:NextNumber(4, 16), a)
            for _ = 1, 6 do
                a += rng:NextNumber(-0.7, 0.7)
                local q = p + Vector3.new(math.sin(a), 0, math.cos(a)) * rng:NextNumber(6, 10)
                Strip(deco, p, q, 0.7, { Color = C3(20, 20, 24), Material = Enum.Material.Basalt }, y + 0.02)
                Glow(Strip(deco, p, q, 0.25, { Color = accent, Material = Enum.Material.Neon }, y + 0.03), C3(150, 200, 255)).Transparency = 0.4
                p = q
            end
        end
    end
    -- DREAMSCAPE: a giant CLOCK FACE -- hour bars, minute ticks, and two hands that really turn
    FLOORART.Dream = function(deco, c, F, accent, rng)
        local y = F + 0.16
        local ink = { Color = C3(70, 56, 120), Material = Enum.Material.SmoothPlastic }
        for i = 0, 59 do
            local a = i / 60 * math.pi * 2
            local big = i % 5 == 0
            local p0, p1 = Polar(c, big and 62 or 68, a), Polar(c, 73, a)
            local st = Strip(deco, p0, p1, big and 3 or 0.8, big and { Color = accent, Material = Enum.Material.Neon } or ink, y)
            if big then Glow(st, C3(255, 170, 235)) end
        end
        for _, part in ipairs(Ring(deco, c + Vector3.new(0, y, 0), 76, 36, 0, 0.04, 1.2, ink)) do Decor(part) end
        local hands = {}
        for _, h in ipairs({ { 38, 3.2, 0.02 }, { 58, 1.8, 0.024 } }) do -- (length, width, turn rate rad/s)
            local hand = Decor(Block(deco, Vector3.new(h[2], 0.05, h[1]), CFrame.new(c.X, y + 0.03, c.Z + h[1] / 2), { Color = C3(255, 236, 250), Material = Enum.Material.Neon }))
            Glow(hand, C3(255, 220, 250))
            table.insert(hands, { Part = hand, Len = h[1], Rate = h[2] > 2 and 0.02 or 0.06, A = rng:NextNumber(0, 6) })
        end
        Glow(Decor(Disk(deco, c + Vector3.new(0, y + 0.05, 0), 7, 0.05, { Color = accent, Material = Enum.Material.Neon })), C3(255, 170, 235))
        if IS_CLIENT then
            task.spawn(function()
                while deco.Parent do
                    local dt = task.wait(0.1)
                    for _, h in ipairs(hands) do
                        h.A += h.Rate * dt
                        h.Part.CFrame = CFrame.new(c.X, y + 0.03, c.Z) * CFrame.Angles(0, h.A, 0) * CFrame.new(0, 0, h.Len / 2)
                    end
                end
            end)
        end
    end
    -- NEON FLATS: a CROSSROADS -- asphalt, dashed double yellow both ways, white edge lines, crosswalks
    FLOORART.Flats = function(deco, c, F, accent, rng)
        local y = F + 0.14
        Decor(Disk(deco, c + Vector3.new(0, y, 0), 156, 0.04, { Color = C3(38, 36, 44), Material = Enum.Material.Asphalt }))
        local yellow = { Color = C3(255, 200, 40), Material = Enum.Material.SmoothPlastic }
        local white = { Color = C3(236, 232, 226), Material = Enum.Material.SmoothPlastic }
        for _, dir in ipairs({ Vector3.xAxis, Vector3.zAxis }) do
            local side = Vector3.new(dir.Z, 0, dir.X)
            for k = -72, 64, 12 do
                if math.abs(k + 4) > 14 then
                    for _, o in ipairs({ -0.7, 0.7 }) do
                        Strip(deco, c + dir * k + side * o, c + dir * (k + 8) + side * o, 0.5, yellow, y + 0.02)
                    end
                end
            end
            for _, o in ipairs({ -22, 22 }) do Strip(deco, c - dir * 74 + side * o, c - dir * 24 + side * o, 0.6, white, y + 0.02); Strip(deco, c + dir * 24 + side * o, c + dir * 74 + side * o, 0.6, white, y + 0.02) end
            for k = -18, 18, 4 do -- crosswalk bars on both sides of the junction
                for _, at in ipairs({ -26, 26 }) do
                    local q = c + dir * at + side * k
                    Decor(Block(deco, Vector3.new(2, 0.04, 7), CFrame.lookAt(Vector3.new(q.X, y + 0.02, q.Z), Vector3.new(q.X, y + 0.02, q.Z) + dir), white))
                end
            end
        end
    end
    -- the MARQUEE over the far (south) rim: a framed sign with the boss's name, in the biome's colours
    local function Marquee(deco, geo, theme, c, F, accent, dungeon)
        local z = c.Z + RF + 22
        local base = CFrame.new(c.X, F, z) * CFrame.Angles(0, math.pi, 0) -- (faces north: toward the doorway you come in by)
        for _, sx in ipairs({ -1, 1 }) do
            Block(geo, Vector3.new(3, 40, 3), base * CFrame.new(sx * 33, 20, 0), theme.Wall)
        end
        local board = Block(deco, Vector3.new(66, 13, 1.6), base * CFrame.new(0, 33, 0), { Color = C3(14, 12, 18), Material = Enum.Material.Metal })
        board.Name = "BossMarquee"
        Decor(board)
        for _, yy in ipairs({ -7, 7 }) do Glow(Decor(Block(deco, Vector3.new(67, 0.7, 1.9), base * CFrame.new(0, 33 + yy, 0), theme.WallTrim)), accent) end
        for _, xx in ipairs({ -33.5, 33.5 }) do Glow(Decor(Block(deco, Vector3.new(0.7, 14.4, 1.9), base * CFrame.new(xx, 33, 0), theme.WallTrim)), accent) end
        local sg = Instance.new("SurfaceGui")
        sg.Name = "MarqueeGui"; sg.Face = Enum.NormalId.Back; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 12
        sg.LightInfluence = 0; sg.Brightness = 2.2; sg.Parent = board
        local t = Instance.new("TextLabel")
        -- (UI CLEAN R-A2: the display face, one line inside the frame with room at both ends -- the sign read cut off)
        t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(0.86, 0.72); t.Position = UDim2.fromScale(0.07, 0.14)
        -- (a fixed size fitted to the name below: the type skin turns TextScaled off on display-face labels -> 8 px text)
        t.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold); t.TextScaled = false; t.TextWrapped = false; t.TextSize = 96
        t:SetAttribute("NoSnap", true)
        t.TextColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.35); t.Text = "? ? ?"
        t.TextStrokeColor3 = Color3.new(0, 0, 0); t.TextStrokeTransparency = 0.3
        t:SetAttribute("KeepFont", true)
        t.Parent = sg
        -- the boss's own name, once it's in the room (BossAI stamps BossTitle on the model)
        task.spawn(function()
            for _ = 1, 240 do
                if not board.Parent then return end
                local twinOf = dungeon:GetAttribute("TwinRun") -- (PARTY TWIN: a member's copy names the party floor's boss)
                for _, m in ipairs(CollectionService:GetTagged("AimRngEnemy")) do
                    local title = m:GetAttribute("BossTitle")
                    if title and (m:IsDescendantOf(dungeon) or (twinOf ~= nil and RunIdOf(m) == twinOf)) then
                        -- (the NAME only: BossTitle also carries "  >> MOVE", [tags] and "(Ns)", which ran the sign out of its frame)
                        local nm = string.match(tostring(title), "^(.-)%s+>>") or tostring(title)
                        nm = string.gsub(nm, "%s*%[.*$", ""); nm = string.match(nm, "^(.-):") or nm
                        t.Text = string.upper(nm)
                        local okW, wv = pcall(function() return game:GetService("TextService"):GetTextSize(t.Text, 96, Enum.Font.Oswald, Vector2.new(1e5, 1e5)).X end)
                        t.TextSize = (okW and wv > 0) and math.clamp(math.floor(96 * 640 / wv), 40, 96) or 80
                        local bc = m:GetAttribute("BossColor")
                        if typeof(bc) == "Color3" then t.TextColor3 = bc:Lerp(Color3.new(1, 1, 1), 0.3) end
                        return
                    end
                end
                task.wait(0.5)
            end
        end)
    end

    function DungeonGenerator.BuildBossArena(dungeon: Instance, geo: Instance, theme: any, biome: string, rng: Random, zC: number)
        local deco = Instance.new("Folder"); deco.Name = "ArenaDecor"; deco.Parent = dungeon
        local F = FLOOR_TOP
        local c = Vector3.new(0, 0, zC)
        local build = SETPIECE[biome] or DungeonGenerator.NB.SetPiece[biome] or SETPIECE.Fire
        local accent = build(geo, deco, c, rng, F) or theme.Accent
        -- the fight floor: one clean disc + inlaid rings + a centre seal (raised a hair over the room floor)
        local floorSurf = { Color = theme.Floor.Color:Lerp(Color3.new(0, 0, 0), 0.08), Material = theme.Floor.Material }
        local fl = Disk(geo, c + Vector3.new(0, F - 0.4, 0), RF * 2, 1, floorSurf)
        fl.Name = "ArenaFloor"
        -- (a Glass wall trim -- Dreamscape -- would mirror the sky on a 166-stud floor disc and blow the floor out to white)
        local trimMat = (theme.WallTrim.Material == Enum.Material.Glass) and Enum.Material.SmoothPlastic or theme.WallTrim.Material
        local trim = { Color = theme.WallTrim.Color, Material = trimMat }
        Decor(Disk(deco, c + Vector3.new(0, F + 0.11, 0), RF * 2 - 2, 0.02, trim))           -- outer band
        Decor(Disk(deco, c + Vector3.new(0, F + 0.13, 0), RF * 2 - 6, 0.02, floorSurf))
        local art = FLOORART[biome]
        if art then
            art(deco, c, F, accent, rng) -- (0.58: the biome's own floor art)
        else
            for _, r in ipairs({ 54, 30 }) do                                                -- inner rings
                Decor(Disk(deco, c + Vector3.new(0, F + 0.15, 0), r * 2 + 1.6, 0.02, trim))
                Decor(Disk(deco, c + Vector3.new(0, F + 0.17, 0), r * 2, 0.02, floorSurf))
            end
            Glow(Decor(Disk(deco, c + Vector3.new(0, F + 0.19, 0), 18, 0.02, trim)), accent) -- centre seal
            Decor(Disk(deco, c + Vector3.new(0, F + 0.21, 0), 15, 0.02, floorSurf))
        end
        -- (0.62, owner: "Overall visibility is still incredibly bad, especially with bosses"): the floor art's neon lines were
        -- the brightest thing in the arena (bloom) and pulled the eye off the boss -- flat floor glow is toned well down
        for _, d in ipairs(deco:GetDescendants()) do
            if d:IsA("BasePart") and d.Material == Enum.Material.Neon and d.Position.Y < F + 1.5 and math.min(d.Size.X, d.Size.Y, d.Size.Z) <= 0.1 then
                d.Color = d.Color:Lerp(Color3.new(0, 0, 0), 0.5)
                d.Transparency = math.max(d.Transparency, 0.3)
            end
        end
        Marquee(deco, geo, theme, c, F, accent, dungeon)
        -- entrance gate over the north doorway: two towers + a lintel with a glowing band
        local gz = zC - RF - 6
        for _, sx in ipairs({ -1, 1 }) do
            Block(geo, Vector3.new(8, 30, 8), CFrame.new(sx * 17, F + 15, gz), theme.Wall)
            Block(geo, Vector3.new(9, 2, 9), CFrame.new(sx * 17, F + 30.5, gz), theme.WallTrim)
        end
        Block(geo, Vector3.new(42, 5, 6), CFrame.new(0, F + 27, gz), theme.WallTrim)
        Glow(Decor(Block(deco, Vector3.new(26, 0.6, 6.3), CFrame.new(0, F + 26, gz), theme.WallTrim)), accent)
        -- 4 low curved cover barriers at 45 degrees (waist high: shots, not perches)
        for _, a in ipairs({ math.rad(45), math.rad(135), math.rad(-45), math.rad(-135) }) do
            for k = -1, 1 do
                local aa = a + k * 0.09
                local p = c + Vector3.new(math.sin(aa) * 52, F + 1.8, math.cos(aa) * 52)
                Block(geo, Vector3.new(5, 3.6, 2.2), CFrame.new(p) * CFrame.Angles(0, aa, 0), MapShell.LookOn() and theme.Wall or theme.WallTrim) -- (MAPLOOK: the room's stone under the trim cap; plain WallTrim read as cardboard)
                Glow(Decor(Block(deco, Vector3.new(5.05, 0.2, 2.25), CFrame.new(p + Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, aa, 0), theme.WallTrim)), accent)
            end
        end
        dungeon:SetAttribute("BossArena", biome)
        return { { Pos = c, R = RF + 4 } } -- (nothing else is scattered on the fight floor)
    end
end

-- ==================== [LINKED ROOMS PILOT] ====================
-- (2026-10-21, docs/LINKED_ROOMS.md; the tunables + the pure-data layout live in AimRngShared/LinkedRooms.) A linked floor is
-- the normal floor (entry room, corridor, room 1 = today's combat room with its map shell round it) plus rooms 2..n further
-- down +Z and a side room off the middle, joined by short paths. Everything here is keyed by config.Linked (DungeonRuns sets
-- it on the server; DungeonClient passes it through FloorInfo): off = not one line of the normal floor changes.
--   BuildLinked(..., "A") before room 1's shell: the layout, the old linked terrain cleared, room 1's shell kept out of the
--     other rooms + paths (MapShell.KeepOuts) and its landmark moved past the exit room (MapShell.LinkHeroZ), then every
--     other room's floor / invisible walls with doorways / lid / RoomGen room, and the paths' floors + walls.
--   BuildLinked(..., "B") after it: terrain ground under the rooms and paths, rock BANKS either side of every path (a
--     canyon between rooms; Edge maps get land bridges over the drop instead), cliff / ruin rims round the rooms' outer
--     walls, the rooms' cover turned to rock (Terrainify), a few kit props. Part-built maps: low parapets + kit rims.
--   RollLinkedRoster (server): 2-3 placed packs a room, elites by the usual odds, + SIDE_ELITE in the side room.
--   LinkCheck / LinkWander (client bots): asleep / idle / fighting, the leash box, milling round the pack's spot.
-- Every room past room 1 has its own folders (dungeon.LinkedRooms.R<i> = what you see, StaticGeometry.LinkGeo<i> = what
-- collides): DungeonClient parks them out of the workspace when you're far away.
DungeonGenerator.LR = require(script.Parent:WaitForChild("LinkedRooms"))

function DungeonGenerator.LinkedLayout(config: any): any
    local L = (config :: any).LinkL
    if L then return L end
    local layout = DungeonGenerator.GetChamberLayout(false)
    L = DungeonGenerator.LR.Layout((config :: any).Seed, config.Difficulty, layout.CombatZ, layout.CombatSize)
    ;(config :: any).LinkL = L
    return L
end

-- a CLOSED map template (the server vault: one room with a ceiling) can't be linked to anything: pick another of the biome's
function DungeonGenerator.LinkedTemplate(config: any, tpl: any, rng: Random): any
    local list = MapShell.TEMPLATES[config.Biome] or MapShell.TEMPLATES.Fire
    for _ = 1, 8 do
        if not tpl.Closed then return tpl end
        tpl = list[rng:NextInteger(1, #list)]
    end
    for _, t in ipairs(list) do if not t.Closed then return t end end
    return tpl
end

-- the part of the world a linked floor adds terrain to (cleared before it builds and when it goes; the hub and the entry
-- room are far north of it, room 1's own region is MapShell's)
function DungeonGenerator.LinkedFootprint(L: any): (CFrame, Vector3)
    local z0 = math.max(((L.Rooms[2] and L.Rooms[2].Z) or L.Rooms[1].Z) - L.Half - 100, 600)
    local z1 = L.MaxZ + 110
    local x0, x1 = L.MinX - 110, L.MaxX + 110
    return CFrame.new((x0 + x1) / 2, 55, (z0 + z1) / 2), Vector3.new(x1 - x0, 150, z1 - z0)
end

-- one room past room 1: floor, invisible walls (56 high, like room 1's on an open map) with a doorway the path's width on
-- every linked side, the lid; part-built maps also get a low parapet you can see along the walls
function DungeonGenerator.LinkedShell(g: Instance, theme: any, L: any, i: number, hideFloor: boolean)
    local LR = DungeonGenerator.LR
    local r = L.Rooms[i]
    local size, half, H = L.Size, L.Half, 56
    local floor = Block(g, Vector3.new(size, 4, size), CFrame.new(r.X, 0, r.Z), theme.Floor)
    floor.Name = "LinkFloor"
    if hideFloor then floor.Transparency = 1 end
    local function Wall(sz: Vector3, pos: Vector3)
        local w = Block(g, sz, CFrame.new(pos), theme.Wall)
        w.Transparency = 1; w.CastShadow = false; w.Name = "LinkWall"
        return w
    end
    local function Parapet(sz: Vector3, pos: Vector3)
        if hideFloor then return end
        local w = Block(g, sz, CFrame.new(pos), Shade(theme.Wall, Random.new(i * 31 + math.floor(pos.X + pos.Z))))
        w.Name = "LinkParapet"; w.CastShadow = false
    end
    for _, sd in ipairs({ { "N", 0, -1 }, { "S", 0, 1 }, { "W", -1, 0 }, { "E", 1, 0 } }) do
        local key, sx, sz = sd[1], sd[2], sd[3]
        local dw = 0
        if r.Doors[key] then
            for _, j in ipairs(r.Links) do
                local p = LR.PathBetween(L, i, j)
                local o = L.Rooms[j]
                local dir = (p and p.Axis == "Z") and ((o.Z > r.Z) and "S" or "N") or ((o.X > r.X) and "E" or "W")
                if p and dir == key then dw = p.W + 2 end
            end
        end
        local cx, cz = r.X + sx * half, r.Z + sz * half
        local along = sz ~= 0 -- (a north / south wall runs along x)
        local inX, inZ = cx - sx * 1.6, cz - sz * 1.6 -- (the parapet: just inside the wall)
        if dw > 0 then
            local d0 = (type(r.Doors[key]) == "number") and r.Doors[key] or 0 -- (v4: the door's offset along the wall)
            for _, s in ipairs({ -1, 1 }) do
                local a, b = (s < 0) and -half or (d0 + dw / 2), (s < 0) and (d0 - dw / 2) or half
                local seg, off = b - a, (a + b) / 2
                if seg > 0.5 then
                    Wall(along and Vector3.new(seg, H, 4) or Vector3.new(4, H, seg), Vector3.new(cx + (along and off or 0), H / 2, cz + (along and 0 or off)))
                    Parapet(along and Vector3.new(seg, 3.2, 1.6) or Vector3.new(1.6, 3.2, seg), Vector3.new(inX + (along and off or 0), FLOOR_TOP + 1.6, inZ + (along and 0 or off)))
                end
            end
            local top = H - LR.PATH_H
            Wall(along and Vector3.new(dw, top, 4) or Vector3.new(4, top, dw), Vector3.new(cx + (along and d0 or 0), LR.PATH_H + top / 2, cz + (along and 0 or d0)))
        else
            Wall(along and Vector3.new(size, H, 4) or Vector3.new(4, H, size), Vector3.new(cx, H / 2, cz))
            Parapet(along and Vector3.new(size - 3.2, 3.2, 1.6) or Vector3.new(1.6, 3.2, size - 3.2), Vector3.new(inX, FLOOR_TOP + 1.6, inZ))
        end
    end
    local lid = Block(g, Vector3.new(size, 2, size), CFrame.new(r.X, H + 1.5, r.Z), theme.Ceiling)
    lid.Transparency = 1; lid.CanQuery = false; lid.CastShadow = false; lid.Name = "SkyLid"
end

-- one DOGLEG path (v4): a floor under each walkable segment, and the rest of the gap between the two rooms' walls SOLID --
-- invisible colliders on a terrain map (the terrain banks are what you see), walls you can see on a part-built map -- so the
-- next room only shows from the last stretch; one lid over the gap
function DungeonGenerator.LinkedPath(pg: Instance, theme: any, p: any, hideFloor: boolean, half: number)
    local LR = DungeonGenerator.LR
    local H = 56
    for _, b in ipairs(LR.PathBoxes(p, 0, 0)) do
        local floor = Block(pg, Vector3.new(b[2] - b[1], 4, b[4] - b[3]), CFrame.new((b[1] + b[2]) / 2, 0, (b[3] + b[4]) / 2), theme.Floor)
        floor.Name = "LinkPathFloor"
        if hideFloor then floor.Transparency = 1 end
    end
    -- the gap less the segments, as rectangles (coordinates compressed in the path's (u, v) frame, merged along v)
    local us, vs = { 0, p.Len }, { -half, half }
    for _, sg in ipairs(p.Segs) do table.insert(us, sg[1]); table.insert(us, sg[2]); table.insert(vs, sg[3]); table.insert(vs, sg[4]) end
    local function Uniq(t)
        table.sort(t)
        local out = {}
        for _, x in ipairs(t) do if #out == 0 or math.abs(out[#out] - x) > 0.01 then table.insert(out, x) end end
        return out
    end
    us, vs = Uniq(us), Uniq(vs)
    local function Covered(u, v)
        for _, sg in ipairs(p.Segs) do if u > sg[1] and u < sg[2] and v > sg[3] and v < sg[4] then return true end end
        return false
    end
    local wallC = Shade(theme.Wall, Random.new(math.floor(p.U0) * 7 + math.floor(p.V0)))
    for a = 1, #us - 1 do
        local runStart = nil
        for bI = 1, #vs do
            local solid = bI < #vs and not Covered((us[a] + us[a + 1]) / 2, (vs[bI] + vs[bI + 1]) / 2)
            if solid and not runStart then runStart = bI end
            if not solid and runStart then
                local x0, x1, z0, z1 = LR.PathRect(p, us[a], us[a + 1], vs[runStart], vs[bI])
                local c = Block(pg, Vector3.new(x1 - x0, H, z1 - z0), CFrame.new((x0 + x1) / 2, H / 2, (z0 + z1) / 2), theme.Wall)
                c.Transparency = 1; c.CastShadow = false; c.Name = "LinkPathWall"
                if not hideFloor then -- (part maps: a wall you can see, well over head height)
                    local v = Block(pg, Vector3.new(x1 - x0 - 0.2, 18, z1 - z0 - 0.2), CFrame.new((x0 + x1) / 2, FLOOR_TOP + 9, (z0 + z1) / 2), wallC)
                    v.Name = "LinkPathSide"; v.CanCollide = false; v.CastShadow = false
                    local cap = Block(pg, Vector3.new(x1 - x0 + 0.4, 0.8, z1 - z0 + 0.4), CFrame.new((x0 + x1) / 2, FLOOR_TOP + 18.4, (z0 + z1) / 2), theme.WallTrim)
                    cap.Name = "LinkPathCap"; cap.CanCollide = false; cap.CanQuery = false; cap.CastShadow = false
                end
                runStart = nil
            end
        end
    end
    local x0, x1, z0, z1 = LR.PathRect(p, 0, p.Len, -half, half)
    local lid = Block(pg, Vector3.new(x1 - x0, 2, z1 - z0), CFrame.new((x0 + x1) / 2, H + 1.5, (z0 + z1) / 2), theme.Ceiling)
    lid.Transparency = 1; lid.CanQuery = false; lid.CastShadow = false; lid.Name = "SkyLid"
end

function DungeonGenerator.BuildLinked(dungeon: Instance, geo: Instance, theme: any, propSet: any, config: any, tpl: any, hideFloor: boolean, phase: string)
    local LR = DungeonGenerator.LR
    local L = DungeonGenerator.LinkedLayout(config)
    local half, F = L.Half, FLOOR_TOP
    local terrain = hideFloor and MapShell.Full() -- (a solo open map: the world is terrain; PARTY TWIN: a mirror too, writing nothing)
    local T = MapShell.T()
    local seed = math.floor(tonumber((config :: any).Seed) or 1)
    local root = dungeon:FindFirstChild("LinkedRooms")
    if not root then root = Instance.new("Folder"); root.Name = "LinkedRooms"; root.Parent = dungeon end
    local function Folders(i: number): (Instance, Instance)
        local vis = root:FindFirstChild("R" .. i)
        if not vis then vis = Instance.new("Folder"); vis.Name = "R" .. i; vis.Parent = root end
        local g = geo:FindFirstChild("LinkGeo" .. i)
        if not g then g = Instance.new("Folder"); g.Name = "LinkGeo" .. i; g.Parent = geo end
        return vis, g
    end
    local RG = require(script.Parent:WaitForChild("RoomGen"))
    if phase == "A" then
        if terrain then
            local cf, size = DungeonGenerator.LinkedFootprint(L)
            T:FillBlock(cf, size, M.Air) -- (a linked floor before this one left its banks here)
        end
        local ko = {}
        for i = 2, #L.Rooms do
            local x0, x1, z0, z1 = LR.Box(L, i, -6)
            table.insert(ko, { X0 = x0, X1 = x1, Z0 = z0, Z1 = z1 })
        end
        for _, p in ipairs(L.Paths) do -- (v4: the dogleg's segments)
            for _, b in ipairs(LR.PathBoxes(p, 4, 2)) do table.insert(ko, { X0 = b[1], X1 = b[2], Z0 = b[3], Z1 = b[4] }) end
        end
        MapShell.KeepOuts = ko
        MapShell.LinkHeroZ = L.Rooms[L.Exit].Z
        local dress = RG.DressFor(config.Biome)
        local build = {}
        ;(config :: any).LinkBuild = build
        for i = 2, #L.Rooms do
            local r = L.Rooms[i]
            local _, g = Folders(i)
            local rr = Random.new((seed * 13 + i * 7919) % 2147483647)
            DungeonGenerator.LinkedShell(g, theme, L, i, hideFloor)
            -- a doorway on the east / west wall: a clear lane from the plaza to it (RoomGen always keeps the N-S spine clear),
            -- and only the shapes that leave that wall open
            local blocked, shapes = {}, nil
            for _, side in ipairs({ "E", "W" }) do
                if r.Doors[side] then
                    local s = (side == "E") and 1 or -1
                    local d0 = (type(r.Doors[side]) == "number") and r.Doors[side] or 0 -- (v4: offset doors)
                    for x = 22, half - 2, 8 do table.insert(blocked, { X = s * x, Z = d0, R = 10 }) end
                    if math.abs(d0) > 12 then for zz = 0, d0, (d0 > 0) and 7 or -7 do table.insert(blocked, { X = s * 22, Z = zz, R = 8 }) end end
                    shapes = { "Open", "Cross", "Courtyard" }
                end
            end
            local dn = r.Doors.N
            if type(dn) == "number" and math.abs(dn) > 12 then -- (v4: the north door off to one side: a clear lane in from it, no terrace across it)
                for zz = -half + 6, -half + 34, 7 do table.insert(blocked, { X = dn, Z = zz, R = 10 }) end
                for xx = 12, math.abs(dn), 7 do table.insert(blocked, { X = ((dn > 0) and 1 or -1) * xx, Z = -half + 24, R = 8 }) end
                shapes = shapes or { "Open", "Hall", "Cross", "Canyon", "Courtyard" }
            end
            local plan = RG.Plan(Random.new(rr:NextInteger(1, 1073741823)), L.Size, { Shape = shapes and shapes[rr:NextInteger(1, #shapes)] or nil, Blocked = blocked })
            local reserved = RG.Build(plan, { geo = g, theme = theme, propSet = propSet, rng = rr, zC = r.Z, xC = r.X, F = F,
                Block = Block, Ramp = Ramp, Shade = Shade, Arena = L.Size, Dress = dress, Terrain = hideFloor, Seed = i * 977 })
            -- the scatter keeps clear of: the plaza, every doorway, the exit room's chest + portal row, the side room's cache
            table.insert(reserved, { Pos = Vector3.new(r.X, 0, r.Z), R = 16 })
            for _, d in ipairs(LR.Doors(L, i)) do table.insert(reserved, { Pos = d, R = 22 }) end
            if r.Kind == "Exit" then
                for x = -40, 40, 8 do for _, dz in ipairs({ 10, 18, 26, 34, 40 }) do table.insert(reserved, { Pos = Vector3.new(r.X + x, 0, r.Z + dz), R = 7 }) end end
            end
            build[i] = { Reserved = reserved, Shape = plan.Shape }
            g:SetAttribute("Shape", plan.Shape)
        end
        local pg = geo:FindFirstChild("LinkPaths")
        if not pg then pg = Instance.new("Folder"); pg.Name = "LinkPaths"; pg.Parent = geo end
        for _, p in ipairs(L.Paths) do DungeonGenerator.LinkedPath(pg, theme, p, hideFloor, half) end
        dungeon:SetAttribute("LinkedRooms", #L.Rooms)
        return
    end

    -- ===== phase "B": the world round rooms 2.. (after room 1's own shell) =====
    MapShell.KeepOuts = nil
    MapShell.LinkHeroZ = nil
    local build = (config :: any).LinkBuild or {}
    local srng = Random.new((seed * 17 + 3) % 2147483647)
    local vrL = Random.new(srng:Clone():NextInteger(1, 1073741823) + 11) -- (MAPLOOK: variation stream; srng's draws never move)
    local rimStyle = tpl.Rim or "Cliffs"
    local rimMat = tpl.RimMat or { M.Rock, M.Slate }
    local dress = RG.DressFor(config.Biome)
    local coverMat = (dress and dress.Stone) or (MapShell.Ctx and MapShell.Ctx.mat) or M.Basalt
    local function Mat(): Enum.Material return rimMat[srng:NextInteger(1, #rimMat)] end
    -- may a lump of radius rad at p grow here? never into any room but `own`, nor into a path
    local function Free(p: Vector3, rad: number, own: number?): boolean
        for j, rm in ipairs(L.Rooms) do
            if j ~= own and math.abs(p.X - rm.X) < half + 3 + rad and math.abs(p.Z - rm.Z) < half + 3 + rad then return false end
        end
        for _, pa in ipairs(L.Paths) do
            if math.abs(p.X - pa.X) < pa.SX / 2 + 3 + rad and math.abs(p.Z - pa.Z) < pa.SZ / 2 + 3 + rad then return false end
        end
        return true
    end
    -- (MapShell's RimPoint for a room off the x = 0 axis: side 1..4 = west, east, north, south; t in -1..1 along it)
    local function RimPoint(r: any, side: number, t: number, out: number): Vector3
        local e = half + out
        if side == 1 then return Vector3.new(r.X - e, F, r.Z + t * e) end
        if side == 2 then return Vector3.new(r.X + e, F, r.Z + t * e) end
        if side == 3 then return Vector3.new(r.X + t * e, F, r.Z - e) end
        return Vector3.new(r.X + t * e, F, r.Z + e)
    end
    local SIDE_KEY = { "W", "E", "N", "S" }
    if terrain then
        -- ground under every room + path (Edge maps: only a little past the walls -- the drop stays a drop)
        for i = 2, #L.Rooms do
            local r = L.Rooms[i]
            local pad = (rimStyle == "Edge") and 12 or 60
            T:FillBlock(CFrame.new(r.X, F - 3.05, r.Z), Vector3.new(L.Size + pad, 6, L.Size + pad), tpl.Ground)
            for _ = 1, 8 do
                local p = Vector3.new(r.X + srng:NextNumber(-half, half), F - 3.05, r.Z + srng:NextNumber(-half, half))
                MapShell.Patch(CFrame.new(p) * CFrame.Angles(0, srng:NextNumber(0, 3.14), 0), Vector3.new(srng:NextNumber(8, 24), 6, srng:NextNumber(6, 16)), tpl.Patch[srng:NextInteger(1, #tpl.Patch)]) -- (MAPLOOK: round)
            end
        end
        for _, pa in ipairs(L.Paths) do -- (v4: under the dogleg's segments)
            for _, b in ipairs(LR.PathBoxes(pa, 3, 2)) do
                T:FillBlock(CFrame.new((b[1] + b[2]) / 2, F - 3.05, (b[3] + b[4]) / 2), Vector3.new(b[2] - b[1], 6, b[4] - b[3]), tpl.Ground)
            end
        end
        -- BANKS: the ground between two rooms is rock either side of the path, a canyon you walk down (Ruins: lower, broken)
        do -- (v4: Edge maps too -- a rock ridge only as wide as the dogleg between the islands, so the next one stays hidden)
            local edge = rimStyle == "Edge"
            for _, pa in ipairs(L.Paths) do
                local reach = edge and (math.abs(pa.Off) + pa.W / 2 + 10) or (half + LR.BANK_OUT)
                -- (v4 DOGLEG) the whole gap between the two rooms is rock, a broken skyline on top, then the walk is carved out of it:
                -- out of one door, the sideways leg, into the other door -- the rock between hides the next room
                local H = srng:NextNumber(LR.BANK_H[1], LR.BANK_H[2]) * ((rimStyle == "Ruins") and 0.55 or (edge and 0.7 or 1))
                if edge then -- (a ridge standing in the void: a tapering root under it)
                    local rx0, rx1, rz0, rz1 = LR.PathRect(pa, 2, pa.Len - 2, -reach + 6, reach - 6)
                    T:FillBlock(CFrame.new((rx0 + rx1) / 2, F - 9, (rz0 + rz1) / 2), Vector3.new(rx1 - rx0, 14, rz1 - rz0), Mat())
                end
                local x0, x1, z0, z1 = LR.PathRect(pa, 0.5, pa.Len - 0.5, -reach, reach)
                T:FillBlock(CFrame.new((x0 + x1) / 2, F - 1 + H / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, H + 2, z1 - z0), Mat())
                local walk = LR.PathBoxes(pa, 0, 0)
                for v = -reach + 6, reach - 6, 11 do
                    for u = 3, pa.Len - 3, 9 do
                        local br = srng:NextNumber(6, 11)
                        local px, _, pz = LR.PathRect(pa, u + srng:NextNumber(-2, 2), u, v + srng:NextNumber(-4, 4), v)
                        local pt = Vector3.new(px, F + H + srng:NextNumber(-5, 4), pz)
                        if not LR.InBoxes(walk, pt, br + 3) then T:FillBall(pt, br, Mat()) end
                        if srng:NextNumber() < 0.3 and not LR.InBoxes(walk, pt, 14) then
                            local sh = srng:NextNumber(10, 22)
                            T:FillBlock(CFrame.new(pt + Vector3.new(0, sh * 0.3, 0)) * CFrame.Angles(srng:NextNumber(-0.3, 0.3), srng:NextNumber(0, 3.14), srng:NextNumber(-0.3, 0.3)),
                                Vector3.new(srng:NextNumber(6, 12), sh, srng:NextNumber(5, 9)), Mat())
                        end
                    end
                end
                for _, wb in ipairs(LR.PathBoxes(pa, 1, 0)) do
                    T:FillBlock(CFrame.new((wb[1] + wb[2]) / 2, F + 0.5 + (H + 14) / 2, (wb[3] + wb[4]) / 2), Vector3.new(wb[2] - wb[1], H + 14, wb[4] - wb[3]), M.Air)
                end
            end
        end
    end
    -- RIMS round every outer wall of rooms 2.. (the walls with a doorway face a bank instead)
    for i = 2, #L.Rooms do
        local r = L.Rooms[i]
        local vis = Folders(i)
        for side = 1, 4 do
            if not r.Doors[SIDE_KEY[side]] then
                if terrain and rimStyle ~= "Edge" then
                    for t = -1, 1, 0.12 do
                        local p = RimPoint(r, side, t + srng:NextNumber(-0.04, 0.04), srng:NextNumber(8, 24))
                        local rad = srng:NextNumber(9, 16)
                        if Free(p, rad, i) then
                            if rimStyle == "Ruins" then
                                T:FillBall(p + Vector3.new(0, srng:NextNumber(-6, 4), 0), rad, Mat())
                            else
                                T:FillBall(p + Vector3.new(0, srng:NextNumber(-4, 8), 0), rad, Mat())
                                for _ = 1, 2 do
                                    local h = srng:NextNumber(20, 44)
                                    T:FillBlock(CFrame.new(p + Vector3.new(srng:NextNumber(-8, 8), h * 0.35, srng:NextNumber(-8, 8)))
                                        * CFrame.Angles(srng:NextNumber(-0.35, 0.35), srng:NextNumber(0, 3.14), srng:NextNumber(-0.35, 0.35)),
                                        Vector3.new(srng:NextNumber(8, 16), h, srng:NextNumber(6, 12)), Mat())
                                end
                            end
                        end
                        if srng:NextNumber() < 0.35 then
                            local q, qr = RimPoint(r, side, t, srng:NextNumber(40, 56)), srng:NextNumber(18, 28)
                            if Free(q, qr, i) then
                                local hc = q + Vector3.new(0, srng:NextNumber(8, 30), 0)
                                local hm = Mat()
                                T:FillBall(hc, qr, hm)
                                if terrain then MapShell.Craggy(hc, qr, hm, vrL, function(pp, rr) return not Free(pp, rr, i) end) end -- (MAPLOOK)
                            end
                        end
                    end
                end
                -- the template's kit along the rim (pines, crystals, ruins ...): what you see over the wall, parked with the room
                local kits = (not terrain and tpl.PartyRim) and { tpl.PartyRim } or tpl.RimKit
                if kits and #kits > 0 then
                    for t = -1, 1, terrain and 0.5 or 0.5 do
                        local kp = RimPoint(r, side, t + srng:NextNumber(-0.06, 0.06), srng:NextNumber(3, 10))
                        if Free(kp, 8, i) then
                            local kit = kits[srng:NextInteger(1, #kits)]
                            local rinst = ShellPlace(config.Biome, kit, CFrame.new(kp) * CFrame.Angles(0, srng:NextNumber(0, 6.28), 0),
                                { Tint = tpl.Tint and tpl.Tint[kit], Scale = terrain and srng:NextNumber(1.8, 3) or srng:NextNumber(3.5, 5.5), Parent = vis, Shadow = false }, srng, MapShell.Ctx or {})
                            if terrain then MapShell.RimPiece(rinst, vrL, "L" .. i .. "_" .. side, MapShell.OUT[side]) else MapShell.Vary(rinst, vrL, "Rim") end -- (MAPLOOK)
                        end
                    end
                end
            end
        end
    end
    -- each room's cover: rock on a terrain map (toned stone on a part map), then a few kit props through it
    for i = 2, #L.Rooms do
        local r = L.Rooms[i]
        local vis, g = Folders(i)
        MapShell.Terrainify(g, r.Z, 4000, coverMat, terrain, config.Biome)
        local b = build[i]
        if b and tpl.Edge and #tpl.Edge > 0 then
            MapShell.Scatter(g, vis, config.Biome, tpl, srng, r.Z, half, (r.Kind == "Side") and 4 or 5, b.Reserved, r.X, LR.Doors(L, i))
        end
        -- (MAPVIBE ROOM ATMOSPHERE: this room's own ground layers, light pools, air + set piece -- AimRngShared/RoomAtmo)
        if IS_CLIENT then
            pcall(function()
                require(script.Parent:WaitForChild("RoomAtmo")).Build(vis, { Biome = config.Biome, Tpl = tpl, X = r.X, Z = r.Z, Half = half,
                    Doors = LR.Doors(L, i), Seed = seed * 31 + i * 977, Lava = DungeonGenerator.Lava(), EnvKit = EnvKit, Kind = "Room",
                    Terrain = terrain and not tpl.Parts })
            end)
        end
    end
    if IS_CLIENT then -- (paths: a lighter share -- air + a worn patch -- in the room the path leaves)
        for pi, pa in ipairs(L.Paths) do
            local vis = Folders(pa.A == 1 and pa.B or pa.A)
            local x0, x1, z0, z1 = LR.PathBox(pa)
            pcall(function()
                require(script.Parent:WaitForChild("RoomAtmo")).Build(vis, { Biome = config.Biome, Kind = "Path", Box = { x0, x1, z0, z1 },
                    Seed = seed * 37 + pi * 131, Terrain = terrain and not tpl.Parts })
            end)
        end
    end
    if terrain then
        local cf, size = DungeonGenerator.LinkedFootprint(L)
        local gen = MapShell.Gen
        dungeon.AncestryChanged:Connect(function()
            if not dungeon:IsDescendantOf(game) and MapShell.Gen == gen then T:FillBlock(cf, size, M.Air) end
        end)
    end
end

-- the SIDE ROOM's cache (client): a closed chest in the middle of the side room; DungeonClient wires its prompt to the
-- server (OpenChest "LinkCache": only once the side room's packs are dead) -> (model, open, prompt)
function DungeonGenerator.BuildLinkCache(dungeon: Instance, config: any, parent: Instance?): (Model?, (() -> ())?, ProximityPrompt?)
    local L = DungeonGenerator.LinkedLayout(config)
    local side = L.Side and L.Rooms[L.Side]
    if not side then return nil, nil, nil end
    parent = parent or dungeon -- (the side room's own folder: parked with it)
    local chest, open = BuildChest(parent, CFrame.new(side.X, FLOOR_TOP, side.Z) * CFrame.Angles(0, (side.X > 0) and math.pi / 2 or -math.pi / 2, 0), "MiniBoss", "HIDDEN CACHE")
    chest.Name = "LinkCacheChest"
    for _, l in ipairs(chest:GetDescendants()) do if l:IsA("Light") then l:Destroy() end end -- (no extra light on a linked floor)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "PromptLinkCache"
    prompt.ActionText = "Open"
    prompt.ObjectText = "HIDDEN CACHE"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 12
    prompt.Enabled = false
    prompt.Parent = chest.PrimaryPart or chest
    return chest, open, prompt
end

-- ROSTER (server): placed packs, room by room. Entries as RollFloorRoster's + LinkRoom (room index), LinkPack (the pack), Counted
-- (only the EXIT room's foes count toward the clear: the floor clears when that room is empty). Elites: the same per-leader
-- chance as a regular floor (difficulty, depth, ELITE_PACK, the map tree), at least one on a late floor, + SIDE_ELITE forced
-- in the side room. Every leader leads PacksPilot fodder (BIG_PACKS: +2).
function DungeonGenerator.RollLinkedRoster(config: any): { any }
    local LR = DungeonGenerator.LR
    local PP = require(script.Parent:WaitForChild("PacksPilot"))
    local L = DungeonGenerator.LinkedLayout(config)
    local floor, diff = config.FloorNumber or 1, config.Difficulty
    local prog = DungeonGenerator.RunProgress(config)
    local eliteChance = math.min(0.3, DungeonGenerator.ELITE_CHANCE[diff] or 0.08) -- (FUTURE-PROOF: one table, ELITE_CHANCE)
    eliteChance = math.min(0.3, eliteChance + floor * 0.004) * (0.35 + 0.65 * prog) -- (the same curve as RollFloorRoster)
    local minElites = (prog >= 0.45) and 1 or 0
    if HasMod(config, "ELITE_PACK") then eliteChance = math.min(0.6, eliteChance * 2.5); minElites = math.round(DungeonGenerator.ModV(config, "ELITE_PACK")) end
    eliteChance = math.min(0.75, eliteChance * ((config :: any).AtlasElite or 1))
    if RunService:IsStudio() and type(Workspace:GetAttribute("DevEliteChance")) == "number" then eliteChance = Workspace:GetAttribute("DevEliteChance"); prog = math.max(prog, 0.2) end -- (Studio test hook)
    local specialists = math.min(2, math.floor(0.4 + 2 * prog))
    local teem = HasMod(config, "BIG_PACKS") and DungeonGenerator.ModV(config, "BIG_PACKS") or 0 -- (MAPS V2: Teeming = +V of every pack, was +2)
    local countMult = 1 + (((config :: any).CountMult or 1) - 1) * LR.PARTY_PACK_SCALE -- (party linked floors: half the extra packs a member)
    local early = PP.Early(diff, floor) -- (2026-10-23 EARLY RAMP: Easy / Normal's first floors start small)
    local roster, pack, elites, leaders, specs = {}, 0, 0, {}, 0
    local roomSpots = {} -- (2026-10-26: every room's pack spots, so a path's stragglers can wait in the next room clear of them)
    -- (v2 RAMP: a linked floor counts as floors n and n+1 -- its rooms' foes ramp from floor n's scaling in room 1 to floor n+1's in the
    -- last room; the horde room and the side room are always at n+1; a path's stragglers at the room they leave from. LinkFloor on
    -- every entry: DungeonRuns rolls the stand-in's stats / rewards at that floor)
    local function FloorOf(i: number): number
        local r = L.Rooms[i]
        local t = (r.Kind == "Side" or i == L.Horde) and 1 or ((L.Main <= 1) and 1 or (i - 1) / (L.Main - 1))
        return floor + ((t >= 0.5) and (LR.FLOOR_STEP - 1) or 0)
    end
    for i, r in ipairs(L.Rooms) do
        local ppr = (r.Kind == "Side") and ((L.Main <= 2) and LR.SIDE_PACKS_SHORT or LR.SIDE_PACKS) or ((L.Main >= 4 or L.Main <= 2) and LR.PACKS_PER_ROOM_HARD or LR.PACKS_PER_ROOM) -- (v2; RUN PACE 2026-10-24: a 2-room floor = 2 packs a room, side room SIDE_PACKS_SHORT)
        local n = math.max(1, math.round(math.random(ppr[1], ppr[2]) * countMult * early * ((config :: any).SwarmMult or 1))) -- (MAPS V2: a map's Swarming = SwarmMult)
        -- pack spots: inside the room, apart, clear of every doorway (you don't walk out of a path into a pack)
        local doors = LR.Doors(L, i)
        local spots = {}
        for _ = 1, 80 do
            if #spots >= n then break end
            local p = Vector3.new(r.X + math.random(-(L.Half - 14), L.Half - 14), 0, r.Z + math.random(-(L.Half - 14), L.Half - 14))
            local ok = true
            for _, d in ipairs(doors) do if (Vector3.new(d.X, 0, d.Z) - p).Magnitude < LR.DOOR_CLEAR then ok = false break end end
            for _, q in ipairs(spots) do if (q - p).Magnitude < LR.SPOT_GAP then ok = false break end end
            if r.Kind == "Side" and (Vector3.new(r.X, 0, r.Z) - p).Magnitude < 20 then ok = false end -- (BOTFIX: the cache chest stands there)
            if ok then table.insert(spots, p) end
        end
        local typeCount = {}
        roomSpots[i] = table.clone(spots)
        if i == L.Horde and r.Kind ~= "Side" then
            -- (v2 HORDE ROOM: one dense pack -- an elite + a crowd of fodder -- in place of the room's small packs; the spot is the
            -- first one rolled, pulled toward the middle)
            local spot = spots[1] and Vector3.new((spots[1].X + r.X) / 2, 0, (spots[1].Z + r.Z) / 2) or Vector3.new(r.X, 0, r.Z + 12)
            spots = {}
            pack += 1
            local arch = DungeonGenerator.PickArchetype(floor, config.Biome, diff)
            local counted = r.Kind == "Exit"
            local lead = { Kind = "Bot", Archetype = arch, Elite = true, Pack = pack, LinkRoom = i, LinkPack = pack, Counted = counted, Horde = true,
                Pos = Vector3.new(spot.X, DungeonGenerator.IsGroundArchetype(arch) and 5 or math.random(10, 18), spot.Z) }
            elites += 1
            table.insert(roster, lead)
            table.insert(leaders, lead)
            for _ = 1, math.max(4, math.round(math.random(LR.HORDE_FODDER[1], LR.HORDE_FODDER[2]) * early ^ 2)) + math.round(16 * teem) do -- (RUNFIX 2026-10-25: ^1.5 -> ^2: Easy f1 = an elite + 4-5)
                local fa = PP.FODDER[math.random(1, #PP.FODDER)]
                local a, rad = math.random() * math.pi * 2, LR.HORDE_R[1] + math.random() * (LR.HORDE_R[2] - LR.HORDE_R[1])
                local x = math.clamp(spot.X + math.cos(a) * rad, r.X - L.Half + 8, r.X + L.Half - 8)
                local z = math.clamp(spot.Z + math.sin(a) * rad, r.Z - L.Half + 8, r.Z + L.Half - 8)
                table.insert(roster, { Kind = "Bot", Archetype = fa, Elite = false, Fodder = true, Pack = pack, LinkRoom = i, LinkPack = pack, Counted = counted,
                    Pos = Vector3.new(x, DungeonGenerator.IsGroundArchetype(fa) and 5 or math.random(9, 18), z) })
            end
        end
        for k, spot in ipairs(spots) do
            pack += 1
            local arch
            if specs < specialists and k == 1 and i > 1 then
                arch = DungeonGenerator.PickSpecialist(floor, config.Biome, diff)
                specs += 1
            else
                arch = DungeonGenerator.PickArchetype(floor, config.Biome, diff)
            end
            if not DungeonGenerator.ForceArchetypes then
                for _ = 1, 12 do
                    if (typeCount[arch] or 0) < 1 then break end
                    arch = DungeonGenerator.PickArchetype(floor, config.Biome, diff)
                end
            end
            typeCount[arch] = (typeCount[arch] or 0) + 1
            local elite = (prog >= 0.2 or minElites > 1) and math.random() < eliteChance
            if r.Kind == "Side" and k <= LR.SIDE_ELITE then elite = true end
            if elite then elites += 1 end
            local counted = r.Kind == "Exit"
            local lead = { Kind = "Bot", Archetype = arch, Elite = elite, Pack = pack, LinkRoom = i, LinkPack = pack, Counted = counted,
                Pos = Vector3.new(spot.X, DungeonGenerator.IsGroundArchetype(arch) and 5 or math.random(10, 18), spot.Z) }
            table.insert(roster, lead)
            table.insert(leaders, lead)
            local nF = PP.RollFodder(config.Difficulty, floor)
            for _ = 1, nF + math.round(nF * teem) do -- (PACK SIZE BY DIFFICULTY; EARLY RAMP; MAPS V2 Teeming)
                local fa = PP.FODDER[math.random(1, #PP.FODDER)]
                local a, rad = math.random() * math.pi * 2, PP.PACK_R[1] + math.random() * (PP.PACK_R[2] - PP.PACK_R[1])
                local x = math.clamp(spot.X + math.cos(a) * rad, r.X - L.Half + 8, r.X + L.Half - 8)
                local z = math.clamp(spot.Z + math.sin(a) * rad, r.Z - L.Half + 8, r.Z + L.Half - 8)
                table.insert(roster, { Kind = "Bot", Archetype = fa, Elite = false, Fodder = true, Pack = pack, LinkRoom = i, LinkPack = pack, Counted = counted,
                    Pos = Vector3.new(x, DungeonGenerator.IsGroundArchetype(fa) and 5 or math.random(9, 18), z) })
            end
        end
    end
    -- (v2 PATH PACKS: a few stragglers in every longer path -- a plain leader + fodder, leashed to the path (LinkPath); they belong
    -- to the room the path leaves (spawned with it), never count toward the clear)
    for k, p in ipairs(L.Paths) do
        if p.Len >= LR.STRAGGLER_LEN then
            pack += 1
            local nf = math.max(1, math.round(math.random(LR.PATH_FODDER[1], LR.PATH_FODDER[2]) * early))
            local arch = DungeonGenerator.PickArchetype(floor, config.Biome, diff)
            if LR.PATH_PACKS_IN_ROOM then
                -- (2026-10-26, owner: bots should only appear when you ENTER the next area) the stragglers wait in the room the path
                -- leads to: a small pack at a spot clear of its doorways and its other packs, made (and counted) with that room
                local b, r = p.B, L.Rooms[p.B]
                local doors, used = LR.Doors(L, b), roomSpots[b] or {}
                local spot, bestD = nil, -1
                for _ = 1, 60 do
                    local q = Vector3.new(r.X + math.random(-(L.Half - 14), L.Half - 14), 0, r.Z + math.random(-(L.Half - 14), L.Half - 14))
                    local d = math.huge
                    for _, dp in ipairs(doors) do d = math.min(d, (Vector3.new(dp.X, 0, dp.Z) - q).Magnitude / LR.DOOR_CLEAR) end
                    for _, u in ipairs(used) do d = math.min(d, (u - q).Magnitude / LR.SPOT_GAP) end
                    if r.Kind == "Side" and (Vector3.new(r.X, 0, r.Z) - q).Magnitude < 20 then d = math.min(d, 0) end -- (the cache chest)
                    if d > bestD then spot, bestD = q, d end
                    if d >= 1 then break end
                end
                table.insert(used, spot)
                roomSpots[b] = used
                local counted = r.Kind == "Exit"
                table.insert(roster, { Kind = "Bot", Archetype = arch, Elite = false, Pack = pack, LinkRoom = b, LinkPack = pack, Counted = counted,
                    Pos = Vector3.new(spot.X, DungeonGenerator.IsGroundArchetype(arch) and 5 or math.random(10, 16), spot.Z) })
                for _ = 1, nf do
                    local fa = PP.FODDER[math.random(1, #PP.FODDER)]
                    local a, rad = math.random() * math.pi * 2, PP.PACK_R[1] + math.random() * (PP.PACK_R[2] - PP.PACK_R[1])
                    local x = math.clamp(spot.X + math.cos(a) * rad, r.X - L.Half + 8, r.X + L.Half - 8)
                    local z = math.clamp(spot.Z + math.sin(a) * rad, r.Z - L.Half + 8, r.Z + L.Half - 8)
                    table.insert(roster, { Kind = "Bot", Archetype = fa, Elite = false, Fodder = true, Pack = pack, LinkRoom = b, LinkPack = pack, Counted = counted,
                        Pos = Vector3.new(x, DungeonGenerator.IsGroundArchetype(fa) and 5 or math.random(9, 16), z) })
                end
                continue
            end
            local x0, x1, z0, z1 = LR.StragglerBox(p) -- (v4: in the dogleg's sideways leg; SEALED ROOMS: its far end, round the corner)
            table.insert(roster, { Kind = "Bot", Archetype = arch, Elite = false, Pack = pack, LinkRoom = p.A, LinkPack = pack, LinkPath = k, Counted = false,
                Pos = Vector3.new((x0 + x1) / 2, DungeonGenerator.IsGroundArchetype(arch) and 5 or math.random(10, 16), (z0 + z1) / 2) })
            for _ = 1, nf do
                local fa = PP.FODDER[math.random(1, #PP.FODDER)]
                table.insert(roster, { Kind = "Bot", Archetype = fa, Elite = false, Fodder = true, Pack = pack, LinkRoom = p.A, LinkPack = pack, LinkPath = k, Counted = false,
                    Pos = Vector3.new(x0 + math.random() * (x1 - x0), DungeonGenerator.IsGroundArchetype(fa) and 5 or math.random(9, 16), z0 + math.random() * (z1 - z0)) })
            end
        end
    end
    -- (a late floor always has an elite somewhere: the exit room's leaders first if the dice gave none)
    if elites < minElites then
        for _, lead in ipairs(leaders) do
            if elites >= minElites then break end
            if not lead.Elite and lead.LinkRoom == L.Exit then lead.Elite = true; elites += 1 end
        end
    end
    for _, e in ipairs(roster) do e.LinkFloor = FloorOf(e.LinkRoom or 1) end
    if math.random() < DungeonGenerator.LOOT_GOBLIN_CHANCE + ((config :: any).AtlasGoblin or 0) or HasMod(config, "TREASURE") then
        local i = 1 -- (a goblin runs round room 1's box: CreateLootGoblin keeps to the combat room)
        local r = L.Rooms[i]
        table.insert(roster, { Kind = "LootGoblin", LinkRoom = i, Pos = Vector3.new(r.X + math.random(-40, 40), math.random(10, 18), r.Z + math.random(-40, 40)) })
    end
    return roster
end

-- CLIENT BOTS (CreateBot, kv.lnk = { X0, X1, Z0, Z1 = the leash box, Home = its spot, Pack }): 0 = asleep (no AI this tick),
-- 1 = idle (no target: mills round its spot in slow motion, never attacks), 2 = fighting you. A bot wakes when you're within
-- WAKE_DIST or it's been hurt -- and wakes its whole pack; the server wakes packs the same way (DungeonRuns), the Awake
-- attribute mirrors back. An awake bot fights only while you're in its room or at its doorways; otherwise it goes home.
function DungeonGenerator.LinkCheck(kv: any, model: Model, pos: Vector3, geo: Instance?, config: any?): number
    local LR = DungeonGenerator.LR
    local lk = kv.lnk
    local hrp = nil
    if IS_CLIENT then
        local char = LocalPlayer and LocalPlayer.Character
        hrp = char and char:FindFirstChild("HumanoidRootPart")
    else -- (PARTY linked floors run on the server: the nearest member in the dungeon)
        local best = math.huge
        for _, pl in ipairs((config and (config :: any).Members) or {}) do
            local c = pl.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if r and r.Position.Z > 450 then
                local dd = (r.Position - pos).Magnitude
                if dd < best then best, hrp = dd, r end
            end
        end
    end
    if not hrp then return 1 end
    local p = (hrp :: BasePart).Position
    local d = (p - pos).Magnitude
    local awake = model:GetAttribute("Awake") == true
    local homing = model:GetAttribute("Homing") == true -- (v3: gave up past AWAKE_CAP -- only the server wakes it again)
    if not awake and not homing then
        local h, mh = model:GetAttribute("Health"), model:GetAttribute("MaxHealth")
        -- (v3: inside its room / path = the whole room wakes; within LOS_WAKE and it can see you)
        -- (BOTFIX 2026-10-24) a distance wake only from its own room / a path into it (lk.Near): never through the rock
        local wake = (d <= LR.WAKE_DIST and (lk.Near == nil or LR.InBoxes(lk.Near, p, 0))) or (type(h) == "number" and type(mh) == "number" and h < mh) or LR.InBoxes(lk.HomeBoxes, p, LR.BOX_INSET)
        if not wake and d <= LR.LOS_WAKE and os.clock() >= (kv.lnkLos or 0) then
            kv.lnkLos = os.clock() + 0.3
            wake = DungeonGenerator.LinkSees(pos, p, geo)
        end
        if wake then
            awake = true
            DungeonGenerator.LinkWakePack(model, lk.Pack)
        end
    end
    -- (v3 CHASE) awake: the chase area; a bot walking home keeps the chase area until it's back inside its own
    local chase = LR.CHASE and (awake or not LR.InBoxes(lk.HomeBoxes, pos, 1))
    local boxes = chase and lk.Chase or lk.HomeBoxes
    if kv.lact ~= boxes then kv.lact = boxes; kv.lbb = chase and lk.ChaseBB or lk.HomeBB end
    local st = (d > LR.SLEEP_DIST or (not awake and model:GetAttribute("LinkParked") == true)) and 0 or 1 -- (BOTFIX: parked room = asleep)
    if not IS_CLIENT and not awake then st = 0 end -- (PARTY floors run on the server: a pack that isn't awake stands still -- no idle AI to pay for)
    if awake and LR.InBoxes(boxes, p, LR.CHASE_MARGIN) then st = 2 end
    if (model:GetAttribute("LinkSleep") == true) ~= (st == 0) then model:SetAttribute("LinkSleep", st == 0); DungeonGenerator.LinkApplyFx(model) end
    return st
end
-- a bot's particles (element auras) are off while it's asleep (attr LinkSleep) or outside the FX_NEAREST bots nearest the camera
-- (attr LinkFxCut, DungeonClient's budget pass); LinkFxOff = what is applied now
function DungeonGenerator.LinkApplyFx(model: Model)
    local off = model:GetAttribute("LinkSleep") == true or model:GetAttribute("LinkFxCut") == true
    if (model:GetAttribute("LinkFxOff") == true) == off then return end
    model:SetAttribute("LinkFxOff", off)
    for _, e in ipairs(model:GetDescendants()) do
        if e:IsA("ParticleEmitter") then
            if off then
                e:SetAttribute("LinkWas", e.Enabled)
                e.Enabled = false
            elseif e:GetAttribute("LinkWas") ~= nil then
                e.Enabled = e:GetAttribute("LinkWas") == true
                e:SetAttribute("LinkWas", nil)
            end
        end
    end
end
function DungeonGenerator.LinkWakePack(model: Model, pack: any)
    model:SetAttribute("Awake", true)
    local parent = model.Parent
    if not parent or pack == nil then return end
    for _, m in ipairs(parent:GetChildren()) do
        if m ~= model and m:GetAttribute("LinkPack") == pack and m:GetAttribute("Awake") ~= true then m:SetAttribute("Awake", true) end
    end
end
-- (v3) can a bot at `from` see you at `to`? (room geometry + the terrain banks / rims)
DungeonGenerator._linkLos = setmetatable({}, { __mode = "k" }) -- (BOT MOVEMENT POE review: one params per floor geometry -- two party floors on one
-- server used to rebuild them on every call as they alternated)
function DungeonGenerator.LinkSees(from: Vector3, to: Vector3, geo: Instance?): boolean
    if not geo then return false end
    local rp = DungeonGenerator._linkLos[geo]
    if not rp then
        rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Include
        rp.FilterDescendantsInstances = { geo, Workspace.Terrain }
        DungeonGenerator._linkLos[geo] = rp
    end
    return Workspace:Raycast(from, to - from, rp) == nil
end
-- (v3) a point clamped into the nearest of the leash boxes (height clamped as the room box did)
function DungeonGenerator.LinkClamp(boxes: { any }, v: Vector3, lowY: number, maxY: number): Vector3
    local y = math.clamp(v.Y, lowY, maxY)
    local bx, bz, bd = v.X, v.Z, math.huge
    for _, b in ipairs(boxes) do
        local cx, cz = math.clamp(v.X, b[1], b[2]), math.clamp(v.Z, b[3], b[4])
        local dd = (cx - v.X) ^ 2 + (cz - v.Z) ^ 2
        if dd < bd then bx, bz, bd = cx, cz, dd end
        if dd == 0 then break end
    end
    return Vector3.new(bx, y, bz)
end
-- an idle bot's next spot: somewhere near its pack's spot, inside its room
function DungeonGenerator.LinkWander(kv: any, rng: Random, y: number): Vector3
    local lk = kv.lnk
    local w = DungeonGenerator.LR.IDLE_WANDER
    local h = lk.Home
    return Vector3.new(math.clamp(h.X + rng:NextNumber(-w, w), lk.X0 + 2, lk.X1 - 2), y, math.clamp(h.Z + rng:NextNumber(-w, w), lk.Z0 + 2, lk.Z1 - 2))
end

-- PARTY TWIN: a mirrored floor (server) just before it goes out -- the build config its members' copies need (attr Twin, JSON),
-- every folder it holds now marked Scenery (what a member's client hides under its own copy; anything put in one later carries
-- attr Live), and the pure dressing stripped: nobody draws the server's copy, so only what collides, is queried or carries a
-- prompt stays (the bots steer round it, shots stop on it).
DungeonGenerator.TWIN_CFG = { "Biome", "Seed", "FloorNumber", "Difficulty", "Endless", "Linked", "Layout", "Mood" }
DungeonGenerator.TWIN_FX = { "ParticleEmitter", "Light", "Beam", "Trail", "Fire", "Smoke", "Sparkles", "Decal", "Texture", "SurfaceAppearance", "LayerCollector" }
function DungeonGenerator.MirrorStamp(dungeon: Instance, config: any, isBoss: boolean)
    local t = { BossArena = isBoss }
    for _, k in ipairs(DungeonGenerator.TWIN_CFG) do
        local v = config[k]
        if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then t[k] = v end
    end
    dungeon:SetAttribute("Twin", game:GetService("HttpService"):JSONEncode(t))
    local cut = 0
    for _, c in ipairs(dungeon:GetChildren()) do
        c:SetAttribute("Scenery", true)
        for _, d in ipairs(c:GetDescendants()) do
            if d.Parent then
                local drop = false
                for _, cls in ipairs(DungeonGenerator.TWIN_FX) do if d:IsA(cls) then drop = true; break end end
                if not drop and d:IsA("BasePart") and not d.CanCollide and not d.CanQuery then
                    drop = true
                    for _, q in ipairs(d:GetDescendants()) do
                        if q:IsA("ProximityPrompt") or (q:IsA("BasePart") and (q.CanCollide or q.CanQuery)) then drop = false; break end
                    end
                end
                if drop then d:Destroy(); cut += 1 end
            end
        end
    end
    dungeon:SetAttribute("MirrorCut", cut)
end

function DungeonGenerator.BuildThemedDungeon(config: DungeonConfig): Folder
    DungeonGenerator.ForceLayout = (config :: any).Layout -- (0.62 MAPS v3, read by BuildTraversal)
    MapShell.Mirror = (not IS_CLIENT) and (config :: any).Mirror == true -- (PARTY TWIN: the client's build path on the server)
    MapShell.KeepOuts, MapShell.LinkHeroZ = nil, nil -- (LINKED ROOMS pilot: a build that broke off can't leave them set)
    -- config.FolderName / FolderParent: server-run party dungeons build side by side (Workspace.PartyRuns);
    -- the client's own private dungeon is Workspace.DungeonFacility.
    local folderName = (config :: any).FolderName or "DungeonFacility"
    local folderParent = (config :: any).FolderParent or Workspace
    local old = folderParent:FindFirstChild(folderName)
    if old then old:Destroy() end

    local theme = BiomeThemes[config.Biome] or BiomeThemes.Fire
    local propSet = Props[config.Biome] or Props.Fire
    local isBossFloor = ItemData.IsBossConfig(config)
    local rng = Random.new((config :: any).Seed or (math.floor(os.clock() * 1000) + config.FloorNumber * 7919))
    -- (0.86 BIOME MOODS, owner: "infinite biome possibilities in terms of colors, aesthetics etc sort of like poe does. Just
    -- make sure they still LOOK GOOD and HIGH QUALITY"): the floor rolls a mood -- a hand-picked look + a seeded jitter
    -- (BiomeMood). The theme's surfaces / accent / light turn with it; the client grades its light + haze + terrain from
    -- the folder stamp. Studio hook: workspace attr DevMood = a mood Id.
    do
        local BM = require(script.Parent:WaitForChild("BiomeMood"))
        local force = (config :: any).Mood
        if RunService:IsStudio() and Workspace:GetAttribute("DevMood") then force = Workspace:GetAttribute("DevMood") end
        local m = BM.Roll(config.Biome, Random.new(rng:NextInteger(1, 1073741823)), force)
        theme = BM.Theme(theme, m)
        ;(config :: any).MoodData = m
    end

    local dungeon = Instance.new("Folder")
    dungeon.Name = folderName
    if (config :: any).RunId then dungeon:SetAttribute("RunId", (config :: any).RunId) end
    if (config :: any).TwinRun then dungeon:SetAttribute("TwinRun", (config :: any).TwinRun) end -- (PARTY TWIN: whose floor this copies)
    dungeon:SetAttribute("Biome", config.Biome)
    dungeon:SetAttribute("MonsterLevel", DungeonGenerator.MonsterLevel(config)) -- (CONTENT LEVEL)
    dungeon:SetAttribute("BiomeName", theme.Name)
    require(script.Parent:WaitForChild("BiomeMood")).Stamp(dungeon, (config :: any).MoodData)
    dungeon:SetAttribute("Difficulty", config.Difficulty)
    dungeon:SetAttribute("Endless", (config :: any).Endless == true)
    dungeon:SetAttribute("Floor", config.FloorNumber)
    dungeon:SetAttribute("IsBossFloor", isBossFloor)
    dungeon:SetAttribute("TotalEnemies", 0)
    dungeon:SetAttribute("RemainingEnemies", 0)
    dungeon:SetAttribute("RaidActive", false)

    -- All static room geometry goes here: enemies steer around exactly this (see SteerStep).
    local geo = Instance.new("Folder")
    geo.Name = "StaticGeometry"
    geo.Parent = dungeon
    -- enemies built for this floor steer around exactly this geometry; party effects go in this folder
    ;(config :: any).Geo = geo
    if (config :: any).RunId then (config :: any).FxFolder = dungeon end

    local layout = DungeonGenerator.GetChamberLayout(isBossFloor)
    local wallHeight = 56
    local corW = layout.CorridorWidth

    -- ===== Entry chamber: calm landing room (no loot here -- it was pointless) =====
    -- (UPDATE 4, owner: "I dont like how the safe zones are completely open and you can see in the skybox when walking out
    -- and looking back at them"): a real roof (no broken ribs); MapShell.EntryHouse builds the rock round the outside
    BuildChamber(geo, theme, layout.EntryZ, layout.EntrySize, 22, false, true, corW, 1, nil, nil, true)
    local entryHalf = layout.EntrySize / 2 - 6
    for _, sx in ipairs({ -1, 1 }) do
        local pool = propSet.Cover
        pool[rng:NextInteger(1, #pool)](geo, theme, rng, Vector3.new(sx * entryHalf, FLOOR_TOP, layout.EntryZ - entryHalf * 0.5))
    end

    -- ===== Corridors =====
    BuildCorridor(geo, theme, layout.CorridorAStart, layout.CorridorAEnd, corW, 3)

    -- ===== Combat chamber =====
    local zC = layout.CombatZ
    local arena = layout.CombatSize
    local tpl = MapShell.Pick(config.Biome, rng) -- (MAP SHELL template for this floor; the floor seed keeps party clients in step)
    if (config :: any).Linked then tpl = DungeonGenerator.LinkedTemplate(config, tpl, rng) end -- (LINKED ROOMS pilot: never a closed room)
    MapShell.Open = not tpl.Closed
    local hideFloor = MapShell.Open and MapShell.Full() and not tpl.Parts
    BuildChamber(geo, theme, zC, arena, wallHeight, true, (config :: any).Linked == true, corW, 3, MapShell.Open, hideFloor) -- (no back door: the old boss room is gone; LINKED ROOMS pilot: the door to room 2)
    local center = Vector3.new(0, FLOOR_TOP, zC)

    -- Landmark around the center plaza (plaza itself stays clear: the victory chest spawns there). Boss floors keep
    -- the middle open -- that's where the fight happens.
    local landmarkParts: { [Instance]: boolean } = {} -- (PORTAL CLEARANCE: the landmark's rubble ring reached the portals)
    if not isBossFloor then
        local had, hadD = {}, {}
        for _, c in ipairs(geo:GetChildren()) do had[c] = true end
        for _, c in ipairs(dungeon:GetChildren()) do hadD[c] = true end
        local variants = Landmarks[config.Biome] or Landmarks.Fire
        variants[rng:NextInteger(1, #variants)](geo, theme, rng, center)
        for _, c in ipairs(geo:GetChildren()) do if not had[c] then landmarkParts[c] = true end end
        if MapShell.PropsOn() then
            -- (MAPVIBE, owner: the rooms looked "almost too ritualistic (like a circle in the middle)": the plaza landmark
            -- -- a ring of 6-8 identical pieces round the centre -- is taken down again (built first so the map rng draws
            -- what it always did). RoomGen plans the room's cover over that ground instead; the fight floor stays open.)
            for c in pairs(landmarkParts) do c:Destroy() end
            for _, c in ipairs(dungeon:GetChildren()) do if not hadD[c] and c ~= geo then c:Destroy() end end
            landmarkParts = {}
        end
    end
    -- plaza inlay (MAPVIBE: not with the prop sets -- a disc marking the room's centre read ceremonial)
    if not MapShell.PropsOn() then
    local plaza = Block(geo, Vector3.new(0.3, 22, 22), CFrame.new(center + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), theme.WallTrim)
    ;(plaza :: Part).Shape = Enum.PartType.Cylinder
    -- (UPDATE 4 PARTY FLOORS: the plain disc read cheap where the floor shows -- the biome's accent floor inside a 1-stud
    -- trim ring; the inner disc's top sits 0.04 above the ring's)
    local inner = Block(geo, Vector3.new(0.38, 20, 20), CFrame.new(center + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        { Color = theme.Floor.Color:Lerp(theme.FloorAlt.Color, 0.35), Material = theme.Floor.Material }) -- (an asphalt FloorAlt read as a hole)
    ;(inner :: Part).Shape = Enum.PartType.Cylinder
    inner.CanCollide = false
    end

    -- (0.86 PROCEDURAL ROOMS, owner: "I want rooms to be procedurally generated ... just ensure that it doesnt look bad or
    -- place things that get in the way of aiming"): every non-boss floor's combat room is planned by RoomGen (shape,
    -- symmetry, cover, decks, validated paths) from its own seeded stream -- party servers, clients and spectators build
    -- the same room. A map's fixed layout name picks its shape (RoomGen.LAYOUT_SHAPE); the pieces still roll per floor.
    local procPlan, RG = nil, nil
    if not isBossFloor then
        RG = require(script.Parent:WaitForChild("RoomGen"))
        local forced = DungeonGenerator.ForceLayout and RG.LAYOUT_SHAPE[DungeonGenerator.ForceLayout] or nil
        if RunService:IsStudio() and Workspace:GetAttribute("DevRoomShape") then forced = Workspace:GetAttribute("DevRoomShape") end -- (Studio test hook)
        -- (0.87: the plaza landmark's parts are occupied space -- low walls used to be able to land in the idol ring)
        local blocked = {}
        for part in pairs(landmarkParts) do
            if part:IsA("BasePart") and part.CanCollide then
                table.insert(blocked, { X = part.Position.X, Z = part.Position.Z - zC, R = math.max(part.Size.X, part.Size.Z) / 2 + 1 })
            elseif part:IsA("Model") then
                local cf, size = part:GetBoundingBox()
                table.insert(blocked, { X = cf.Position.X, Z = cf.Position.Z - zC, R = math.max(size.X, size.Z) / 2 + 1 })
            end
        end
        procPlan = RG.Plan(Random.new(rng:NextInteger(1, 1073741823)), arena, { Shape = forced, Blocked = blocked })
    end
    -- Corner vantage pillars (the supply caches on top were removed 2026-10-03 at the owner's request).
    -- (BOSS ARENAS 0.48: none on boss floors -- the arena has its own low cover, no perches above the attacks)
    -- (0.86: rooms whose shape fills the corners -- Cross / Hall / Split / Canyon -- drop them)
    local pillarXZ = (isBossFloor or (procPlan and not procPlan.Pillars)) and {}
        or { Vector2.new(-50, -50), Vector2.new(50, -50), Vector2.new(-50, 50), Vector2.new(50, 50) }
    for idx, xz in ipairs(pillarXZ) do
        local pos = Vector3.new(xz.X, 12, zC + xz.Y)
        -- (UPDATE 4 COVER: the pillar in the room's own style -- stacked stone drums / a ribbed tech column, RoomGen.Pillar,
        -- on its own seeded stream (the layout rng is untouched); the trim column + band read as plain slabs. Same 10-stud
        -- collider footprint, the walkable top unchanged.)
        local RGm = RG or require(script.Parent:WaitForChild("RoomGen"))
        RGm.Pillar({ geo = geo, theme = theme, rng = Random.new(idx * 7919 + math.floor(zC)),
            zC = zC, F = FLOOR_TOP, Block = Block, Shade = Shade, Seed = idx * 31, Dress = RGm.DressFor(config.Biome), Terrain = hideFloor }, xz.X, xz.Y, 10, 24 - FLOOR_TOP - 1.6)
        Block(geo, Vector3.new(16, 1.5, 16), CFrame.new(pos + Vector3.new(0, 12.5, 0)), theme.Floor):SetAttribute("Shade", 1.15) -- (stone on open maps)
    end

    -- Jump pads that launched you onto the vantage platforms -- REMOVED 0.65 (owner: "Remove bounce pads from biomes")
    local padXZ = {}
    for jIdx, xz in ipairs(padXZ) do
        local jPos = Vector3.new(xz.X, FLOOR_TOP + 0.25, zC + xz.Y)
        local ring = Block(geo, Vector3.new(0.5, 7.4, 7.4), CFrame.new(jPos) * CFrame.Angles(0, 0, math.rad(90)), { Color = C3(40, 40, 44), Material = Enum.Material.Metal })
        ;(ring :: Part).Shape = Enum.PartType.Cylinder
        local pad = Block(geo, Vector3.new(0.6, 5.6, 5.6), CFrame.new(jPos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
            { Color = theme.Accent:Lerp(C3(40, 40, 44), 0.35), Material = Enum.Material.SmoothPlastic })
        ;(pad :: Part).Shape = Enum.PartType.Cylinder
        pad.Name = "JumpPad_" .. jIdx
        -- Launches onto this corner's vantage platform. The launch itself runs on the client (the player's
        -- character is physically owned by their client, so a server-side velocity set was often ignored).
        pad:SetAttribute("LaunchTarget", Vector3.new(math.sign(xz.X) * 50, 25.25, zC + math.sign(xz.Y) * 50))
        CollectionService:AddTag(pad, "AimRngJumpPad")
    end

    -- Randomized biome props through the rest of the room.
    local reserved = {
        { Pos = center, R = 14 },
        (not MapShell.PropsOn()) and { Pos = center, R = 14, Ring = 40 } or { Pos = center, R = 14 }, -- landmark ring (MAPVIBE: no landmark ring with the prop sets)
        { Pos = Vector3.new(0, 0, zC + 30), R = 12 }, -- portal spot (0.60: 30 past the chest)
        { Pos = Vector3.new(0, 0, zC - arena / 2), R = 26 }, -- north doorway (wide: the way in must read clear)
        { Pos = Vector3.new(0, 0, zC + arena / 2), R = 16 }, -- south doorway
    }
    -- the PORTAL ROW (path choice: up to 4 portals 14 studs apart at zC + 30, SpawnVictoryVault) + room to walk up to it --
    -- owner 2026-10-05: "Props should never block the portals in maps" (only the middle spot was kept clear)
    -- (0.61e, owner: "A lot of props block the portals at the end on the biomes"): the v3 portals are ~14 wide x 5 deep with
    -- a step in front, and the BACK portal stands at (-30, zC + 16) -- the whole block from the chest to behind the
    -- portals is kept clear now (x -40..40, zC + 10..40), not just a row of points
    for x = -40, 40, 8 do
        for _, dz in ipairs({ 10, 18, 26, 34, 40 }) do
            table.insert(reserved, { Pos = Vector3.new(x, 0, zC + dz), R = 7 })
        end
    end
    for _, xz in ipairs(pillarXZ) do table.insert(reserved, { Pos = Vector3.new(xz.X, 0, zC + xz.Y), R = 11 }) end
    for _, xz in ipairs(padXZ) do table.insert(reserved, { Pos = Vector3.new(xz.X, 0, zC + xz.Y), R = 7 }) end

    -- traversal (wall panels, platforms, ramps) -- props keep clear of it (not on boss floors: the BOSS ARENA instead)
    if procPlan then
        -- (0.86) the generated room, built at its real size
        -- (UPDATE 4 wrap-up WORLD DRESS: the biome's cover stone + Tall crowns / clads, RoomGen.DressFor; Terrain = solo
        -- open map, where Terrainify turns the pieces to rock)
        for _, r in ipairs(RG.Build(procPlan, { geo = geo, theme = theme, propSet = propSet, rng = rng, zC = zC, F = FLOOR_TOP,
            Block = Block, Ramp = Ramp, Shade = Shade, Arena = arena, Dress = RG.DressFor(config.Biome), Terrain = hideFloor })) do
            table.insert(reserved, r)
        end
        dungeon:SetAttribute("Traversal", "Proc:" .. procPlan.Shape)
        dungeon:SetAttribute("RoomShape", procPlan.Shape)
    elseif not isBossFloor then
        -- (0.62 smaller rooms: built at the design size, then pulled in round the room's centre -- ScaleTraversal)
        local had = {}
        for _, ch in ipairs(geo:GetChildren()) do had[ch] = true end
        local design = DungeonGenerator.TRAVERSAL_DESIGN
        local k = math.min(1, arena / design)
        for _, r in ipairs(BuildTraversal(dungeon, geo, theme, rng, zC, design, wallHeight)) do
            table.insert(reserved, { Pos = Vector3.new(r.Pos.X * k, 0, zC + (r.Pos.Z - zC) * k), R = r.R * k, Ring = r.Ring and r.Ring * k or nil })
        end
        if k < 1 then
            for _, ch in ipairs(geo:GetChildren()) do
                if not had[ch] and ch:IsA("BasePart") then
                    -- (traversal pieces only ever turn round the vertical axis: scaling X / Z keeps them true)
                    local cf, sz = ch.CFrame, ch.Size
                    local pos = Vector3.new(cf.X * k, cf.Y, zC + (cf.Z - zC) * k)
                    local horiz = math.abs(cf.UpVector.Y) > 0.99
                    ch.Size = horiz and Vector3.new(sz.X * k, sz.Y, sz.Z * k) or sz * Vector3.new(k, 1, k)
                    ch.CFrame = cf.Rotation + pos
                end
            end
        end
    end
    MapShell.KeepOut = { X = layout.EntrySize / 2 + 8, Z0 = layout.EntryZ - layout.EntrySize / 2 - 8, Z1 = zC - arena / 2 + 1 }
    MapShell.PropUse = {} -- (MAPVIBE PROP SETS: this floor's no-repeat record)
    -- (LINKED ROOMS pilot: the other rooms + paths, before room 1's shell -- it keeps out of them)
    if (config :: any).Linked then DungeonGenerator.BuildLinked(dungeon, geo, theme, propSet, config, tpl, hideFloor == true, "A") end
    local beforeProps = {} -- (PORTAL CLEARANCE below: what the prop passes add)
    for _, c in ipairs(geo:GetChildren()) do beforeProps[c] = true end
    MapShell.T0 = os.clock() -- (MAPLOOK: folder attr ShellMs = the world shell's build time, rims + linked banks + clears)
    MapShell.Boss = isBossFloor -- (MAPVIBE: boss arenas keep their own designed dressing)
    MapShell.Build(dungeon, geo, theme, config.Biome, rng, zC, arena, wallHeight, tpl, reserved) -- the world round the arena
    MapShell.EntryHouse(dungeon, theme, tpl, layout, rng, zC, arena, config.Biome)
    if (config :: any).Linked then DungeonGenerator.BuildLinked(dungeon, geo, theme, propSet, config, tpl, hideFloor == true, "B") end -- (LINKED ROOMS pilot: their world)
    if IS_CLIENT and hideFloor == true and not tpl.Closed and not tpl.Parts and not isBossFloor then -- (BOTFIX: no rim / bank rock inside a room)
        MapShell.ClearInterior(geo, 0, zC, arena / 2)
        if (config :: any).Linked then
            local L = DungeonGenerator.LinkedLayout(config)
            for i = 2, #L.Rooms do MapShell.ClearInterior(geo, L.Rooms[i].X, L.Rooms[i].Z, L.Half) end
        end
        -- (MAPLOOK) lean + scallop the rock faces the clear left flat at every wall (not room 1's entry side, not chasm maps)
        if tpl.Rim ~= "Edge" and MapShell.LookOn() then
            local rmat = (tpl.RimMat and tpl.RimMat[1]) or M.Rock
            local rooms, paths = { { Index = 1, X = 0, Z = zC, Half = arena / 2, Skip = { N = true }, Mat = rmat } }, {}
            if (config :: any).Linked then
                local L = DungeonGenerator.LinkedLayout(config)
                for i = 2, #L.Rooms do table.insert(rooms, { Index = i, X = L.Rooms[i].X, Z = L.Rooms[i].Z, Half = L.Half, Mat = rmat }) end
                paths = L.Paths
            end
            MapShell.CarveFaces(rooms, paths, Random.new(math.floor(tonumber((config :: any).Seed) or zC) % 1000003 + 29))
        end
        if MapShell.FlushOn() then -- (MAPVIBE FLUSH GROUND: the open floor flat + flush with the floor part, every room + path)
            local h = arena / 2
            local boxes = { { -h, h, zC - h, zC + h } }
            if (config :: any).Linked then
                local L = DungeonGenerator.LinkedLayout(config)
                for i = 2, #L.Rooms do
                    local r = L.Rooms[i]
                    table.insert(boxes, { r.X - L.Half, r.X + L.Half, r.Z - L.Half, r.Z + L.Half })
                end
                for _, pa in ipairs(L.Paths) do
                    for _, b in ipairs(DungeonGenerator.LR.PathBoxes(pa, 0, 1)) do table.insert(boxes, b) end
                end
            end
            dungeon:SetAttribute("FlushCols", MapShell.FlushGround(boxes, geo))
        end
    end
    if MapShell.T0 then dungeon:SetAttribute("ShellMs", math.floor((os.clock() - MapShell.T0) * 10000) / 10); MapShell.T0 = nil end
    MapShell.KeepOut = nil
    BuildAmbience(dungeon, geo, theme, config.Biome, rng, zC, arena, wallHeight) -- light + motion so the room feels alive
    if isBossFloor then
        -- BOSS ARENA: on solo open maps the ground is terrain (renders ~2 studs over the floor part): clear it under the
        -- fight floor so the arena disc IS the floor there
        if MapShell.Open and IS_CLIENT and not tpl.Parts then
            Workspace.Terrain:FillCylinder(CFrame.new(0, FLOOR_TOP + 4, zC), 9, 84 + 16, Enum.Material.Air)
        end
        DungeonGenerator.BuildBossArena(dungeon, geo, theme, config.Biome, rng, zC)
    elseif MapShell.Open and not tpl.Parts then
        -- (0.65, owner: "overall have less props blocking the shooting": mid-room props 12 -> 6 / 16 -> 9)
        MapShell.Scatter(geo, dungeon, config.Biome, tpl, rng, zC, arena / 2, MapShell.PropsOn() and 0 or 6, reserved) -- (pass 3: room 1's walls are dressed in MapShell.Build)
    elseif MapShell.PropsOn() and MapShell.VR and tpl and tpl.Edge and #tpl.Edge > 0 and MapShell.Full() then
        -- (MAPVIBE pass 2: part-built maps -- Rooftop, Data Yard, the Station -- scattered 9 cover props over the open floor
        -- too (a row of the same barrel across the roof); they get the wall-backed set pieces of the open maps)
        MapShell.DressWalls(config.Biome, tpl, 0, zC, arena / 2 - 2, reserved, "R0:" .. math.floor(zC + 0.5), { Parent = dungeon:FindFirstChild("MapShell") or dungeon, HitParent = geo }, MapShell.VR, 1.4)
    else
        ScatterProps(geo, theme, propSet, rng, zC, arena / 2 - 10, 9, reserved)
    end
    if not isBossFloor then DungeonGenerator.ClearPortalZone(dungeon, geo, zC, beforeProps, landmarkParts) end
    if IS_CLIENT and not isBossFloor and tpl then -- (MAPVIBE ROOM 1: the biome's pass 2 in the first room too -- RoomAtmo.BuildRoom1)
        pcall(function()
            local h = arena / 2
            local doors = (config :: any).Linked and DungeonGenerator.LR.Doors(DungeonGenerator.LinkedLayout(config), 1) or { Vector3.new(0, FLOOR_TOP, zC - h) }
            require(script.Parent:WaitForChild("RoomAtmo")).BuildRoom1(dungeon, { Biome = config.Biome, Tpl = tpl, X = 0, Z = zC, Half = h, Doors = doors,
                Keep = { { -h - 40, h + 40, zC - h - 40, zC - h + 3 }, { -30, 30, zC - h, zC - h + 30 }, -- (entry wall + rim, merchant / event)
                    { -36, 36, zC + DungeonGenerator.PORTAL_ZONE.Z0, zC + DungeonGenerator.PORTAL_ZONE.Z1 } }, -- (chest + portal row)
                Seed = math.floor(tonumber((config :: any).Seed) or zC) * 31 + 977, Lava = DungeonGenerator.Lava(), EnvKit = EnvKit, Kind = "Room",
                Terrain = hideFloor == true and not tpl.Parts and not tpl.Closed })
        end)
    end

    if IS_CLIENT and MapShell.PropsOn() and not isBossFloor and tpl then -- (MAPVIBE: the second of two close copies changes its look)
        local h = arena / 2
        local boxes = { { -h, h, zC - h, zC + h } }
        if (config :: any).Linked then
            local L = DungeonGenerator.LinkedLayout(config)
            for i = 2, #L.Rooms do
                local r = L.Rooms[i]
                table.insert(boxes, { r.X - L.Half, r.X + L.Half, r.Z - L.Half, r.Z + L.Half })
            end
        end
        local okD, nD = pcall(MapShell.Dedupe, dungeon, config.Biome, tpl, boxes, Random.new(math.floor(tonumber((config :: any).Seed) or zC) % 1000003 + 83))
        dungeon:SetAttribute("Deduped", okD and nD or ("ERR " .. tostring(nD))) -- (START FIX: dressing never breaks a floor)
    end
    local settleOpen = MapShell.Open and tpl ~= nil and not tpl.Parts
    MapShell.LavaPools() -- (UPDATE 4 LAVA: molten pools in the lava patches, once all the terrain is down)
    MapShell.Open = false
    DungeonGenerator.Restyle(dungeon, config.Biome) -- (0.90 stylized materials on the biome's big plain surfaces)
    DungeonGenerator.QualityTag(dungeon, zC, arena / 2) -- (UPDATE 4: what Graphics Quality = Low may drop)
    if MapShell.Mirror then DungeonGenerator.MirrorStamp(dungeon, config, isBossFloor); MapShell.Mirror = false end
    dungeon.Parent = folderParent
    -- (MAPVIBE SETTLE: after every terrain edit and once the floor is in the workspace -- raycasts only see the workspace)
    if IS_CLIENT and MapShell.PropsOn() and tpl and dungeon:IsDescendantOf(Workspace) then
        -- (START FIX: dressing never breaks a floor -- an error here used to abort the build after the floor was parented)
        local okS, mv, rm, il = pcall(MapShell.Settle, dungeon, tpl, settleOpen)
        dungeon:SetAttribute("Settled", okS and (mv .. "/" .. rm .. "/" .. il) or ("ERR " .. tostring(mv)))
        if not okS then warn("[MapShell] Settle: " .. tostring(mv)) end
        if tpl.Parts and (config.Biome == "Cyber" or config.Biome == "Station") then -- (MAPVIBE: rim kit out over the drop; before the
            -- linked rooms are parked out of the workspace)
            local ok2, f = pcall(MapShell.DropFloaters, dungeon)
            dungeon:SetAttribute("Floaters", ok2 and f or tostring(f))
        end
        -- (a second pass once the terrain edits are in the collision world: what is drawn, not the voxel estimate; no removals
        -- or islets there -- only drops onto what is really under it)
        task.spawn(function()
            RunService.Heartbeat:Wait(); RunService.Heartbeat:Wait()
            if dungeon.Parent and dungeon:IsDescendantOf(Workspace) then
                MapShell.SettleSoft = true
                local ok, a = pcall(MapShell.Settle, dungeon, tpl, settleOpen, true)
                MapShell.SettleSoft = false
                if ok then dungeon:SetAttribute("Settled2", a) end
            end
        end)
    end
    return dungeon
end
-- (MAPVIBE 2026-10-25, the Cyber Rooftop / Station floaters) on a PART-built map every dressing model must stand on something
-- you can see: 5 rays down from its world footprint, only visible parts / terrain count (the Studio place's hidden baseplate,
-- invisible colliders and hitboxes never). Nothing within 30 studs (an Edge map's rim kit out over the drop) -> it goes, with
-- its hitboxes; a gap -> it drops onto what is under it. Settle's ground test let these through. Returns "dropped/removed".
function MapShell.DropFloaters(dungeon: Instance): string
    local FLY = MapShell.SETTLE_FLY
    local items, hits = {}, {}
    local function Walk(root: Instance)
        for _, x in ipairs(root:GetChildren()) do
            if x:IsA("Model") and (string.match(x.Name, "^R%d+$") or x.Name == "LinkedRooms") then Walk(x)
            elseif x:IsA("Model") then
                local fly = CollectionService:HasTag(x, "AimRngEnemy") or x:FindFirstChildOfClass("Humanoid") ~= nil or x:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil
                for _, pat in ipairs(FLY) do if string.find(x.Name, pat) then fly = true break end end
                if not fly then table.insert(items, x) end
            elseif x:IsA("Folder") then
                if x.Name ~= "Ambience" and x.Name ~= "Scenery" and x.Name ~= "RoomAtmo" then Walk(x) end
            elseif x:IsA("BasePart") and x.Name == "Hitbox" then table.insert(hits, x)
            end
        end
    end
    Walk(dungeon)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local ex = {}
    for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
    local dropped, removed = 0, 0
    for _, m in ipairs(items) do
        if m.Parent and m:IsDescendantOf(Workspace) then
            local cf, sz = (m :: Model):GetBoundingBox()
            if sz.Magnitude < 300 and sz.Magnitude > 0.1 then
                local bottom = cf.Position.Y - sz.Y / 2
                local e2 = table.clone(ex); table.insert(e2, m)
                rp.FilterDescendantsInstances = e2
                local best = nil
                for _, o in ipairs({ { 0, 0 }, { 0.35, 0.35 }, { -0.35, 0.35 }, { 0.35, -0.35 }, { -0.35, -0.35 } }) do
                    -- (from over its top: a sunk piece starts inside its ground, and a ray never sees the part it starts in)
                    local from = Vector3.new(cf.Position.X + o[1] * sz.X, bottom + sz.Y + 1, cf.Position.Z + o[2] * sz.Z)
                    for _ = 1, 8 do
                        local h = Workspace:Raycast(from, Vector3.new(0, -(from.Y - bottom) - 30, 0), rp)
                        if not h then break end
                        local q = h.Instance
                        if q == Workspace.Terrain or (q:IsA("BasePart") and q.Transparency < 0.95 and q.Name ~= "Hitbox" and q.Name ~= "Baseplate") then
                            best = math.max(best or -math.huge, h.Position.Y)
                            break
                        end
                        from = h.Position - Vector3.new(0, 0.05, 0)
                    end
                end
                local function Hits(fn: (BasePart) -> ())
                    for _, h in ipairs(hits) do
                        if h.Parent and math.abs(h.Position.X - cf.Position.X) < sz.X / 2 + 1 and math.abs(h.Position.Z - cf.Position.Z) < sz.Z / 2 + 1 then fn(h) end
                    end
                end
                if not best then
                    if game:GetService("RunService"):IsStudio() then
                        dungeon:SetAttribute("FloaterLog", string.sub(tostring(dungeon:GetAttribute("FloaterLog") or "") .. string.format(" %s@%d,%d,%d", m.Name, cf.Position.X, bottom, cf.Position.Z), -900))
                    end
                    Hits(function(h) h:Destroy() end)
                    m:Destroy()
                    removed += 1
                elseif bottom - best > 0.6 then
                    local d = Vector3.new(0, -(bottom - best) - 0.1, 0)
                    ;(m :: Model):PivotTo((m :: Model):GetPivot() + d)
                    Hits(function(h) h.CFrame += d end)
                    dropped += 1
                end
            end
        end
    end
    return dropped .. "/" .. removed
end

-- STYLIZED MATERIALS (0.90, owner: "make it so the textures of everything better fits the aesthetic of each part of the
-- game ... a complete revamp in quality"): the painted set (tools/make_textures.py) replaces the base materials game-wide
-- through MaterialService overrides (tools/materials_rebuild.luau -- terrain, rock, grass, wood, brick ... everywhere).
-- SmoothPlastic / Metal can't be overridden globally (enemies, glows, skins use them), so the biomes whose big shapes are
-- plain plastic / metal get a THEMED variant here: only large surfaces (second-largest side >= 12 studs), never an enemy.
DungeonGenerator.RESTYLE = {
    Station = { SmoothPlastic = "AB_Panel", Metal = "AB_Panel" },
    Cyber = { Metal = "AB_TechMetal" },
    Dream = { SmoothPlastic = "AB_DreamStone" },
    Sky = { SmoothPlastic = "AB_Canvas" },
    Fungal = { SmoothPlastic = "AB_ShroomCap" },
}
-- QUALITY TAGS (UPDATE 4, owner: "a low quality option in the settings for players with worse computers"): after a floor
-- is built, its pure decoration is tagged for AimRngShared.QualityMode -- ambience / scenery / map-shell emitters are
-- THINNED on Low (rain, ash, motes keep the mood at a third of the rate), their decorative lights and the far vista pieces
-- (> VISTA_KEEP studs past the arena wall; never the vista ground, or the void would show) are HIDDEN. Gameplay parts are
-- never in these folders (StaticGeometry, enemies, portals, chests, telegraphs live elsewhere).
DungeonGenerator.VISTA_KEEP = 160
function DungeonGenerator.QualityTag(dungeon: Instance, zC: number, half: number)
    local QM = DungeonGenerator.QM
    if QM == nil then
        local ok, m = pcall(function() return require(script.Parent:WaitForChild("QualityMode", 5) :: ModuleScript) end)
        QM = ok and m or false
        DungeonGenerator.QM = QM
    end
    if not QM then return end
    local far = half + DungeonGenerator.VISTA_KEEP
    for _, name in ipairs({ "Ambience", "MapShell" }) do
        local f = dungeon:FindFirstChild(name)
        if f then
            for _, d in ipairs(f:GetDescendants()) do
                if d:IsA("ParticleEmitter") then
                    QM.Thin(d)
                elseif d:IsA("Light") then
                    QM.Detail(d)
                elseif d:IsA("BasePart") and name == "MapShell" and d.Name ~= "VistaGround" and not d:GetAttribute("KeepOnLow") then
                    local p = d.Position
                    if math.max(math.abs(p.X), math.abs(p.Z - zC)) - d.Size.Magnitude / 2 > far then QM.Detail(d) end
                end
            end
        end
    end
end

function DungeonGenerator.Restyle(root: Instance, biome: string?)
    local map = biome and DungeonGenerator.RESTYLE[biome]
    if not map then return end
    for _, p in ipairs(root:GetDescendants()) do
        if p:IsA("BasePart") and p.MaterialVariant == "" and p.Transparency < 0.5 then
            local v = map[p.Material.Name]
            if v then
                local s = p.Size
                local a, b, c = s.X, s.Y, s.Z
                if a > b then a, b = b, a end
                if b > c then b, c = c, b end
                if a > b then a, b = b, a end
                -- (b = the middle side: a big panel / hull, not a rod or a trim strip)
                if b >= 12 then
                    local m = p:FindFirstAncestorWhichIsA("Model")
                    if not (m and (m:GetAttribute("DroneType") or m:GetAttribute("IsBoss") or m:GetAttribute("MaxHealth"))) then
                        p.MaterialVariant = v
                    end
                end
            end
        end
    end
end

-- PORTAL CLEARANCE (0.62, owner: "Fix the props blocking the next floor portals on ice and molten biomes"): the reserved
-- points only check a prop's CENTRE against a guessed radius, and the Ice / Molten kits (pines, ice statues, crystals,
-- furnaces, terrain Outcrops at up to 1.9x) reach far past it, and the centre LANDMARK's ring (Molten rubble slabs) was
-- never checked at all. After every prop pass this removes, WHOLE, any prop / landmark piece whose
-- real bounds reach into the portal block (the path portal row at zC + 30, up to 5 portals 18 apart, the back portal at
-- (-30, zC + 16), and the walk up to them from the chest), plus its hitbox, and clears terrain lumps there.
DungeonGenerator.PORTAL_ZONE = { X = 48, Z0 = 8, Z1 = 40, Top = 30 } -- (x +-X, z zC + Z0..Z1, anything below FLOOR_TOP + Top)
function DungeonGenerator.ClearPortalZone(dungeon: Instance, geo: Instance, zC: number, beforeGeo: { [Instance]: boolean }, landmark: { [Instance]: boolean }?)
    local Z = DungeonGenerator.PORTAL_ZONE
    local z0, z1, top = zC + Z.Z0, zC + Z.Z1, FLOOR_TOP + Z.Top
    local function Hits(p: BasePart): boolean
        local cf, h = p.CFrame, p.Size / 2
        -- world-axis half extents of the (possibly rotated) part
        local ex = math.abs(cf.RightVector.X) * h.X + math.abs(cf.UpVector.X) * h.Y + math.abs(cf.LookVector.X) * h.Z
        local ey = math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z
        local ez = math.abs(cf.RightVector.Z) * h.X + math.abs(cf.UpVector.Z) * h.Y + math.abs(cf.LookVector.Z) * h.Z
        local c = cf.Position
        return c.X + ex > -Z.X and c.X - ex < Z.X and c.Z + ez > z0 and c.Z - ez < z1 and c.Y - ey < top and c.Y + ey > FLOOR_TOP + 1 -- (flat floor inlays / pads are fine)
    end
    local function Sweep(root: Instance, skip: { [Instance]: boolean }?, only: { [Instance]: boolean }?)
        for _, c in ipairs(root:GetChildren()) do
            if not (skip and skip[c]) and (not only or only[c]) then
                local bad = c:IsA("BasePart") and Hits(c)
                if not bad then
                    for _, d in ipairs(c:GetDescendants()) do
                        if d:IsA("BasePart") and Hits(d) then bad = true; break end
                    end
                end
                if bad then c:Destroy() end
            end
        end
    end
    local shell = dungeon:FindFirstChild("MapShell")
    if shell then Sweep(shell) end
    Sweep(geo, beforeGeo) -- (only what the prop passes added: hitboxes, ScatterProps; never walls / floor / traversal)
    if landmark then Sweep(geo, nil, landmark) end -- (the centre landmark's ring pieces -- the Molten rubble sat in front of the portals)
    if IS_CLIENT then -- (terrain Outcrops: only above the floor -- the ground terrain sits just under it)
        Workspace.Terrain:FillBlock(CFrame.new(0, FLOOR_TOP + 2 + Z.Top / 2, (z0 + z1) / 2), Vector3.new(Z.X * 2, Z.Top, z1 - z0), Enum.Material.Air)
    end
end

-- ===== NEW BIOMES (0.53): merge NewBiomes' data into the generator's tables =====
do
    local NB = DungeonGenerator.NB
    for k, v in pairs(NB.TITLES) do DungeonGenerator.BIOME_TITLES[k] = v end
    for k, v in pairs(NB.PALETTE) do BiomePalettes[k] = v end
    for k, v in pairs(NB.THEMES) do BiomeThemes[k] = v end
    -- PILL COLOURS (0.97, owner: "Make the colors of the bots dependent on the area too, JUST MAKE SURE THE COLORS OF THE
    -- BOTS CONTRAST WITH ALL OF THE COLORS IN THAT BIOME. Make each biomes bots look a bit unique"): every hue on the wheel
    -- is scored against the biome's surfaces + accent + lamp (saturated colours count most; greys barely constrain hue);
    -- the bots take one of the three least-used hues (picked per archetype, so a biome's bots differ a little), bright on
    -- dark biomes, deep + saturated on bright ones. Head = the same hue, lighter.
    DungeonGenerator._pillCache = {}
    function DungeonGenerator.PillColors(biome: string, archetype: string?): (Color3, Color3)
        local key = tostring(biome) .. "|" .. tostring(archetype)
        local hit = DungeonGenerator._pillCache[key]
        if hit then return hit[1], hit[2] end
        local th = BiomeThemes[biome] or BiomeThemes.Fire
        local cols, lumSum, lumN = {}, 0, 0
        for _, k in ipairs({ "Floor", "FloorAlt", "Wall", "WallTrim", "Prop", "PropAlt", "Hazard", "Ceiling" }) do
            local e = th[k]
            local c = type(e) == "table" and e.Color or nil
            if c then
                table.insert(cols, c)
                if k == "Floor" or k == "Wall" or k == "Prop" then lumSum += 0.299 * c.R + 0.587 * c.G + 0.114 * c.B; lumN += 1 end
            end
        end
        if th.Accent then table.insert(cols, th.Accent); table.insert(cols, th.Accent) end -- (the accent glows: counts double)
        if th.Light then table.insert(cols, th.Light) end
        local cands = {}
        for hue = 0, 350, 10 do
            local pen = 0
            for _, c in ipairs(cols) do
                local h, sat, val = c:ToHSV()
                local d = math.abs(h * 360 - hue); d = math.min(d, 360 - d)
                pen += (sat * math.sqrt(val)) * math.max(0, 1 - d / 70)
            end
            table.insert(cands, { hue, pen })
        end
        table.sort(cands, function(a, b) return a[2] < b[2] end)
        local hsh = 0
        for i = 1, #tostring(archetype) do hsh = (hsh * 31 + string.byte(tostring(archetype), i)) % 1000003 end
        local pick = cands[1 + hsh % 3][1] + ((hsh // 3) % 3 - 1) * 5
        local lum = lumN > 0 and lumSum / lumN or 0.3
        local bright = lum > 0.5
        local body = Color3.fromHSV((pick % 360) / 360, bright and 0.95 or 0.82, bright and 0.62 or 0.95)
        local headC = Color3.fromHSV((pick % 360) / 360, bright and 0.7 or 0.45, 1)
        DungeonGenerator._pillCache[key] = { body, headC }
        return body, headC
    end
    for k, v in pairs(NB.AMBIENCE) do AMBIENCE[k] = v end
    for k, v in pairs(NB.ARCHETYPES) do BotArchetypes[k] = v end
    for k, v in pairs(NB.LORE) do DungeonGenerator.BotLore[k] = v end
    for k, v in pairs(NB.RANGED_KIND) do RANGED_KIND[k] = v end
    for k, v in pairs(NB.POOLS) do BIOME_POOLS[k] = v end
    for k, v in pairs(NB.SPECIALIST) do BIOME_SPECIALIST[k] = v end
    for k, v in pairs(NB.HARD) do HARD_BIOME[k] = v end
    for k, v in pairs(NB.SLOW) do SLOW_TYPES[k] = v end
    for k, v in pairs(NB.ELEMENT) do BiomeElement[k] = v end
    for k, v in pairs(NB.ELEMENT_DEFS) do ElementDefs[k] = v end
    for k, v in pairs(NB.Props) do Props[k] = v end
    for k, v in pairs(NB.Landmarks) do Landmarks[k] = v end
    for k, v in pairs(NB.VISTA) do VISTA[k] = v end
    for k, v in pairs(NB.TEMPLATES) do MapShell.TEMPLATES[k] = v end
    for k, v in pairs(NB.Heroes) do HEROES[k] = v end
    -- (0.87 WORLDS, "worlds first": a world fights with its SISTER biome's roster until it has its own)
    for k, sis in pairs(NB.SISTER or {}) do
        BIOME_POOLS[k] = BIOME_POOLS[k] or BIOME_POOLS[sis]
        BIOME_SPECIALIST[k] = BIOME_SPECIALIST[k] or BIOME_SPECIALIST[sis]
        HARD_BIOME[k] = HARD_BIOME[k] or HARD_BIOME[sis]
        if not BiomeElement[k] then BiomeElement[k] = BiomeElement[sis] end
    end
end

-- (UPDATE 4 LAVA) load LavaFX on every client, so its runner turns pool layers on server-built (party) floors too
if IS_CLIENT then task.defer(function() pcall(DungeonGenerator.Lava) end) end
-- (ENEMY VARIETY 2026-11-07) the pilot's room pairing (wraps RollLinkedRoster) + its bestiary text: AimRngShared/BotVerbs
pcall(BotRoles.Verbs.Install, DungeonGenerator)

return DungeonGenerator
