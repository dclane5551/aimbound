--!nocheck
-- Private dungeon runs (server side). Every player's dungeon exists only on their own client: the client
-- builds the map and runs every enemy (DungeonGenerator, AimRngClient's DungeonClient section). The server
-- keeps, per player:
--   * a run folder  PlayerGui.AimRngRun  (replicates to that player only) whose attributes are the floor
--     state: Biome, Difficulty, Floor, Seed, PlayerLevel, RaidActive, IsBossFloor, BossDefeated,
--     TotalEnemies, RemainingEnemies, FloorCleared, FloorStartClock, RunToken
--   * one part-less stand-in Model per enemy in AimRngRun.Enemies (tag "AimRngProxy"). Its attributes are
--     the authoritative stats (Health, MaxHealth, rewards, IsBoss, EliteTier, Element, SlowMult, statuses,
--     Dead...) -- CombatServer damages it exactly like a real enemy model. The client mirrors these onto
--     its local enemy and removes the enemy when the stand-in is removed.
--   * each enemy's last reported position (EnemyPositions, ~10/s) for area effects and hit checks.
-- Client reports (enemy hits on the player, shields, summons, chests, hazards) are checked against the
-- stand-ins: damage caps from the enemy's own AttackDamage, rate limits, and run state.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Remotes = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Remotes"))
local ItemData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ItemData"))
local DungeonGenerator = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("DungeonGenerator"))

local HttpService = game:GetService("HttpService")
local DungeonRuns = {}
DungeonRuns.PROXY_TAG = "AimRngProxy"

local FloorMods = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("FloorMods"))
local FloorObjectives = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("FloorObjectives"))
local DungeonEvents = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("DungeonEvents"))
local Encounters = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Encounters")) -- (UPDATE 7 run encounters)
local DailyChallenge = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("DailyChallenge"))
local DailyLine = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("DailyLine")) -- (UPDATE 7 B6)
local Rifts = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Rifts"))
local BossTrials = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("BossTrials"))
local AscensionTrials = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("AscensionTrials"))
local PacksPilot = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("PacksPilot")) -- (PoE direction phase 1 pilot)
local LinkedRooms = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("LinkedRooms")) -- (LINKED ROOMS pilot)
local CombatServer: any = nil -- injected by Init (avoids a require cycle)

type Run = {
    Player: Player,
    Folder: Folder,
    Enemies: Folder,
    Config: any,
    NextId: number,
    Pos: { [Instance]: Vector3 },
    Recent: { [number]: any }, -- enemy id -> { AttackDamage, Until } for hits landing just after a death
    HitTimes: { [number]: { number } },
    ChestsOpened: { [number]: boolean },
    VaultOpened: boolean,
    LastHazard: number,
    LastSummon: number,
    ShieldUntil: { [Instance]: number },
    OutsideTicks: number,
}
local runs: { [Player]: Run } = {}
DungeonRuns.EXPOSE_EVERY = 4 -- (0.63 EXPOSED target rotation, below; 0.88: constant, a new bot every 4 s)

local ENEMY_ATTRS_TO_COPY = {
    "Health", "MaxHealth", "XpReward", "GoldReward", "IsBoss", "IsMiniBoss", "IsMajorBoss", "IsSuperBoss", "Lite",
    "IsElite", "EliteTier", "EliteMods", "Element", "BodyArmor", "DamageTakenMult", "DroneType",
    "IsLootGoblin", "AttackDamage",
    "ShellType", "Avenging", -- (ENEMY ATTACKS PILOT elite mods: the Shelled type -> ShellHp / ShellMax below, the Avenging pack mod)
    "EarlyPay", -- (EARLY DENSITY 2026-11-07: the item-chance pay of a thinner early floor, CombatServer GiveKillRewards)
}
-- (UPDATE 8 OFFENSE: DungeonGenerator.StampResists; FUTURE-PROOF 2026-10-25: DamageTypes.RES_ATTRS, every type -- was a copy)
for _, a in ipairs(require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("DamageTypes")).RES_ATTRS) do
    table.insert(ENEMY_ATTRS_TO_COPY, a)
end

local function RunFolder(player: Player): Folder?
    local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
    if not pg then return nil end
    local f = pg:FindFirstChild("AimRngRun")
    if not f then
        f = Instance.new("Folder")
        f.Name = "AimRngRun"
        f.Parent = pg
    end
    local e = f:FindFirstChild("Enemies")
    if not e then
        e = Instance.new("Folder")
        e.Name = "Enemies"
        e.Parent = f
    end
    return f
end

function DungeonRuns.Get(player: Player): Run?
    return runs[player]
end

-- The run folder's attribute (nil when no run).
function DungeonRuns.Attr(player: Player, key: string): any
    local r = runs[player]
    return r and r.Folder:GetAttribute(key)
end
-- (UPDATE 8 DEFENCE) the solo floor's config (CombatServer.DefHitSize: an ordinary hit on this floor)
function DungeonRuns.ConfigOf(player: Player): any
    local r = runs[player]
    return r and r.Config
end

-- (ENEMY ATTACKS PILOT, review A) a solo shot that popped a heavy's shell -- the shell only exists on the client -- is NEUTRAL for
-- Focus / headshot runs only while a Heavy (shell) stand-in of this floor is alive, and only up to its Count claims per
-- BotRoles.CLAIM_GAP x its old attack gap: a client can't keep its streak through misses by calling everything a shell
function DungeonRuns.ShellClaim(player: Player): boolean
    local run = runs[player]
    if not run or not run.Enemies then return false end
    local BR = require(game.ReplicatedStorage.AimRngShared.BotRoles)
    if BR.Old() then return false end
    local now = os.clock()
    run.ShellClaims = run.ShellClaims or setmetatable({}, { __mode = "k" })
    -- (ENEMY VARIETY 2026-11-07) any live stand-in whose ACTIVE row puts something shootable in the air (shells, seekers, beacons, a
    -- channel's shells: BotRoles.Shootable) -- and the fodder of a Seeker pack (config.VerbKinds, BotVerbs.ComposeRoster)
    local kinds = run.Config and (run.Config :: any).VerbKinds
    for _, m in ipairs(run.Enemies:GetChildren()) do
        if not m:GetAttribute("Dead") then
            local arch = m:GetAttribute("Archetype") or ""
            local row, n = nil, 0
            if m:GetAttribute("Fodder") then
                if kinds and BR.Verbs.On() and kinds[m:GetAttribute("LinkPack") or -1] == "Seeker" then row, n = BR.Verbs.LITE.Seeker or {}, 1 end
            else
                row, n = BR.Shootable(arch)
            end
            if row and n > 0 then
                local A = DungeonGenerator.BotArchetypes[arch]
                -- (review 2: a heavy with Every = n throws a shell only every n-th attack)
                local gap = (A and A.Fire or 3) * DungeonGenerator.BOT_PACE.Interval * BR.CLAIM_GAP * (row.Every or 1) / n
                if now - (run.ShellClaims[m] or -1e9) >= gap then
                    run.ShellClaims[m] = now
                    return true
                end
            end
        end
    end
    return false
end
function DungeonRuns.IsProxy(inst: Instance): boolean
    return CollectionService:HasTag(inst, DungeonRuns.PROXY_TAG)
end

function DungeonRuns.OwnerOf(proxy: Instance): Player?
    local uid = proxy:GetAttribute("OwnerUserId")
    return uid and Players:GetPlayerByUserId(uid) or nil
end

function DungeonRuns.PosOf(proxy: Instance): Vector3?
    local p = DungeonRuns.OwnerOf(proxy)
    local r = p and runs[p]
    return r and r.Pos[proxy] or proxy:GetAttribute("SpawnPos")
end

-- Living stand-ins of one player's run.
function DungeonRuns.EnemiesOf(player: Player): { Instance }
    local r = runs[player]
    if not r then return {} end
    local out = {}
    for _, m in ipairs(r.Enemies:GetChildren()) do
        if not m:GetAttribute("Dead") and (m:GetAttribute("Health") or 0) > 0 then table.insert(out, m) end
    end
    return out
end

-- Creates the stand-in for one roster entry. Stats come from a dry run of the same Create* function the
-- client will use, so both sides agree on every number.
local function SpawnProxy(run: Run, entry: any): Instance
    local mods, tier = entry.EliteMods, entry.EliteTier
    if entry.Kind == "Bot" and entry.Elite and not mods then mods, tier = DungeonGenerator.RollEliteMods(run.Config) end
    local dryCfg = (entry.LinkFloor and entry.LinkFloor ~= run.Config.FloorNumber) and DungeonRuns.LinkedCfg(run, entry.LinkFloor) or run.Config -- (LINKED ROOMS v2 ramp)
    local dry = DungeonGenerator.CreateOfKind(entry.Kind, entry.Archetype, mods, entry.Pos, dryCfg, nil, { DryRun = true, EliteTier = tier }) -- (the rolled tier: attr EliteTier)
    run.NextId += 1
    local id = run.NextId
    local proxy = Instance.new("Model")
    proxy.Name = "E" .. id
    for _, k in ipairs(ENEMY_ATTRS_TO_COPY) do
        local v = dry:GetAttribute(k)
        if v ~= nil then proxy:SetAttribute(k, v) end
    end
    local size = dry:GetExtentsSize()
    proxy:SetAttribute("HitRadius", math.max(size.X, size.Y, size.Z) * 0.5 + 1)
    proxy:SetAttribute("ModelName", dry.Name)
    proxy:SetAttribute("EnemyId", id)
    proxy:SetAttribute("Kind", entry.Kind)
    proxy:SetAttribute("Archetype", entry.Archetype)
    proxy:SetAttribute("SpawnPos", entry.Pos)
    proxy:SetAttribute("SlowMult", 1)
    proxy:SetAttribute("OwnerUserId", run.Player.UserId)
    if entry.IsSummon then proxy:SetAttribute("IsSummon", true) end
    if entry.LinkRoom then -- (LINKED ROOMS pilot: its room + pack; only the exit room's foes count toward the clear)
        proxy:SetAttribute("LinkRoom", entry.LinkRoom)
        if entry.LinkPack then proxy:SetAttribute("LinkPack", entry.LinkPack) end
        if entry.LinkPath then proxy:SetAttribute("LinkPath", entry.LinkPath) end -- (v2: a path's stragglers, leashed to the path)
        if entry.LinkFloor then proxy:SetAttribute("LinkFloor", entry.LinkFloor) end -- (v2 ramp: the floor its stats were rolled at)
        if not entry.Counted then proxy:SetAttribute("Uncounted", true) end
    end
    if entry.Fodder then -- (PACKS PILOT: a weak pack member; the client builds it from these numbers)
        proxy:SetAttribute("Fodder", true)
        local hp = math.max(1, math.round((proxy:GetAttribute("MaxHealth") or 1) * PacksPilot.HP))
        proxy:SetAttribute("MaxHealth", hp)
        proxy:SetAttribute("Health", hp)
        proxy:SetAttribute("AttackDamage", math.max(1, math.round((proxy:GetAttribute("AttackDamage") or 1) * PacksPilot.DMG)))
        proxy:SetAttribute("XpReward", math.round((proxy:GetAttribute("XpReward") or 0) * PacksPilot.XP))
        proxy:SetAttribute("GoldReward", math.round((proxy:GetAttribute("GoldReward") or 0) * PacksPilot.GOLD))
    end
    -- floor modifiers on the enemy itself
    local mods = run.Config.Mods
    local msc = run.Config.ModScale -- (MAPS V2: a map's mods scale with its tier; nil = today's numbers)
    -- (MAP PACING 2026-10-31) a map's Fortified is its monsters' health, not the guardian's: the guardian fight ran 2-3x longer
    -- under it (measured); Empowered Guardian is the guardian's own health mod
    local hpMult = (FloorMods.Has(mods, "FORTIFIED") and not (run.Rift and dry:GetAttribute("IsBoss"))) and (1 + FloorMods.V("FORTIFIED", msc)) or 1
    if FloorMods.Has(mods, "WARDED") and not dry:GetAttribute("IsBoss") then hpMult *= 1 + FloorMods.V("WARDED", msc) end -- (UPDATE 8 map mod Warded: that extra part is its ward)
    if run.Rift then hpMult *= Rifts.HealthMult(run.Rift.Tier) end
    if run.Rift and FloorMods.Has(mods, "EMPOWERED") and dry:GetAttribute("IsBoss") and (run.Config.FloorNumber or 1) >= Rifts.FLOORS then hpMult *= 1 + FloorMods.V("EMPOWERED", msc) end -- (0.66 map mod)
    if run.BossTrial and entry.Kind == "TrialBoss" then hpMult *= (BossTrials.Tiers[run.BossTrial.Tier] or BossTrials.Tiers[1]).Hp * (BossTrials.HpScale or 1) end
    if run.BossTrial and run.BossTrial.Weekly and entry.Kind == "TrialBoss" then -- (UPDATE 7: the weekly modifier's health)
        local wm = require(game.ReplicatedStorage.AimRngShared.Weekly).Mods[run.BossTrial.Weekly]
        hpMult *= wm and wm.Hp or 1
    end
    -- Boon heat: every boon you hold makes this run's enemies 6% tougher (BoonData.HEAT_PER_BOON).
    -- (UPDATE 8 Phase 5: boons are cut -- BoonData.ON false -- so no heat)
    if CombatServer then
        local BoonData = require(game.ReplicatedStorage.AimRngShared.BoonData)
        if BoonData.ON ~= false then hpMult *= 1 + BoonData.HEAT_PER_BOON * #(CombatServer.GetState(run.Player).RunBoons or {}) end
    end
    if hpMult ~= 1 then
        proxy:SetAttribute("MaxHealth", math.round((proxy:GetAttribute("MaxHealth") or 1) * hpMult))
        proxy:SetAttribute("Health", proxy:GetAttribute("MaxHealth"))
    end
    do -- (GLASS_ARENA: everything takes more; UPDATE 8: ARMORED is "Plated" now -- +30% Kinetic resist, DungeonGenerator.MapResist)
        local tm = (FloorMods.Has(mods, "GLASS_ARENA") and (1 + FloorMods.V("GLASS_ARENA", msc)) or 1)
        if tm ~= 1 then proxy:SetAttribute("ModTakenMult", tm) end
    end
    dry:Destroy()
    if proxy:GetAttribute("ShellType") then require(game.ReplicatedStorage.AimRngShared.BotRoles).InitShell(proxy) end -- (on the final health)
    CollectionService:AddTag(proxy, DungeonRuns.PROXY_TAG)
    run.Pos[proxy] = entry.Pos
    proxy.Parent = run.Enemies
    if entry.Kind == "LootGoblin" then -- escapes if not caught in time (the client removes its model with the proxy)
        task.delay(DungeonGenerator.LOOT_GOBLIN_LIFETIME, function()
            if proxy.Parent and not proxy:GetAttribute("Dead") then
                local owner = run.Player
                proxy:Destroy()
                if owner and owner.Parent then
                    Remotes.GetEvent("CombatFx"):FireClient(owner, "Text", "THE LOOT GOBLIN ESCAPED", Color3.fromRGB(255, 210, 90))
                end
            end
        end)
    end
    return proxy
end

local function ClearEnemies(run: Run)
    for _, m in ipairs(run.Enemies:GetChildren()) do
        -- (just-killed ones linger 0.15 s like OnProxyKilled: the floor's last kills get their death animation too)
        if m:GetAttribute("Dead") then task.delay(0.15, function() if m.Parent then m:Destroy() end end) else m:Destroy() end
    end
    table.clear(run.Pos)
    table.clear(run.ShieldUntil)
    ;(run :: any).PackQueue = nil
end

-- PACKS PILOT waves: a roster with Pack numbers spawns its first START_PACKS packs now; the rest wait in run.PackQueue and
-- ReleasePacks sends the next one in (away from you) whenever fewer than REFILL_BELOW enemies are alive. TotalEnemies /
-- RemainingEnemies already count the waiting ones, so the floor only clears when every pack is dead.
local function SpawnRoster(run: Run, roster: { any })
    local held, order = {}, {}
    local start = (run.Config and (run.Config :: any).MiniPacks) and PacksPilot.MINI_START
        or PacksPilot.StartPacks(run.Config and run.Config.Difficulty, run.Config and run.Config.FloorNumber) -- (UPDATE 8: mini-boss floors; 2026-10-23 EARLY RAMP)
    for _, e in ipairs(roster) do
        if e.Pack and e.Pack > start then
            if not held[e.Pack] then held[e.Pack] = {}; table.insert(order, e.Pack) end
            table.insert(held[e.Pack], e)
        else
            SpawnProxy(run, e)
        end
    end
    table.sort(order)
    local q = {}
    for _, k in ipairs(order) do table.insert(q, held[k]) end
    ;(run :: any).PackQueue = (#q > 0) and q or nil
end
local function ReleasePacks(run: Run)
    local q = (run :: any).PackQueue
    if not q then return end
    local alive = 0
    for _, m in ipairs(run.Enemies:GetChildren()) do
        if not m:GetAttribute("Dead") and m:GetAttribute("Kind") ~= "LootGoblin" then alive += 1 end
    end
    if alive >= (((run.Config :: any).MiniPacks) and PacksPilot.MINI_REFILL_BELOW or PacksPilot.RefillBelow(run.Config.Difficulty, run.Config.FloorNumber)) then return end
    local pack = table.remove(q, 1)
    if #q == 0 then (run :: any).PackQueue = nil end
    -- move the pack's ring to a spot away from you (keeps its shape; FindOpenSpot on the client sorts out cover)
    local layout = DungeonGenerator.GetChamberLayout(false)
    local half = layout.CombatSize / 2 - 12
    local root = run.Player.Character and run.Player.Character:FindFirstChild("HumanoidRootPart")
    local me = root and Vector3.new(root.Position.X, 0, root.Position.Z)
    local c0 = pack[1].Pos
    local best, bestD = nil, -1
    for _ = 1, 10 do
        local c = Vector3.new(math.random(-half, half), 0, layout.CombatZ + math.random(-half, half))
        local d = me and (c - me).Magnitude or 999
        if d >= PacksPilot.AWAY then best = c; break end
        if d > bestD then best, bestD = c, d end
    end
    local shift = Vector3.new(best.X - c0.X, 0, best.Z - c0.Z)
    for _, e in ipairs(pack) do
        e = table.clone(e)
        e.Pos += shift
        SpawnProxy(run, e)
    end
end

-- (UPDATE 8 Phase 5 ELITE MODS) SUMMONER: once it's in the fight (hurt, or 4 s after spawning), every SUMMON_EVERY s it calls
-- SUMMON_COUNT fodder at its side, SUMMON_MAX times at most. They count toward the clear (like a Splitter's halves).
DungeonRuns.SUMMON_EVERY, DungeonRuns.SUMMON_COUNT, DungeonRuns.SUMMON_MAX = 12, 2, 3
function DungeonRuns.SummonerTick(run: Run, now: number)
    for _, m in ipairs(run.Enemies:GetChildren()) do
        local mods = m:GetAttribute("EliteMods")
        if DungeonGenerator.HasEliteMod(mods, "Summoner") and not m:GetAttribute("Dead") and run.Pos[m]
            and (m:GetAttribute("LinkPack") == nil or m:GetAttribute("Awake")) then -- (LINKED ROOMS pilot: not while its pack sleeps)
            local done = m:GetAttribute("Summons") or 0
            local first = m:GetAttribute("SummonAt")
            if not first then m:SetAttribute("SummonAt", now + 4); first = now + 4 end
            if done < DungeonRuns.SUMMON_MAX and now >= first then
                m:SetAttribute("Summons", done + 1)
                m:SetAttribute("SummonAt", now + DungeonRuns.SUMMON_EVERY)
                local at = run.Pos[m]
                for i = 1, DungeonRuns.SUMMON_COUNT do
                    local a = math.random() * math.pi * 2
                    local arch = PacksPilot.FODDER[math.random(1, #PacksPilot.FODDER)]
                    local sp = SpawnProxy(run, { Kind = "Bot", Archetype = arch, Fodder = true, IsSummon = true,
                        LinkRoom = m:GetAttribute("LinkRoom"), LinkPack = m:GetAttribute("LinkPack"), Counted = not m:GetAttribute("Uncounted"), -- (LINKED ROOMS pilot)
                        LinkFloor = m:GetAttribute("LinkFloor"),
                        Pos = Vector3.new(at.X + math.cos(a) * 5, DungeonGenerator.IsGroundArchetype(arch) and 5 or at.Y, at.Z + math.sin(a) * 5) })
                    if m:GetAttribute("Awake") then sp:SetAttribute("Awake", true) end
                end
                if not m:GetAttribute("Uncounted") then -- (LINKED ROOMS pilot: a room that doesn't count adds nothing to the count)
                    run.Folder:SetAttribute("TotalEnemies", (run.Folder:GetAttribute("TotalEnemies") or 0) + DungeonRuns.SUMMON_COUNT)
                    run.Folder:SetAttribute("RemainingEnemies", (run.Folder:GetAttribute("RemainingEnemies") or 0) + DungeonRuns.SUMMON_COUNT)
                end
            end
        end
    end
end

-- (ENEMY VARIETY 2026-11-07; AimRngShared/BotVerbs) RAISE: a raiser stand-in brings a fallen fodder of its room back (the server
-- decides; the client draws the beam from the RaiseAt / RaisePos attrs). Counted like a Summoner's calls.
function DungeonRuns.BV(): any return require(game.ReplicatedStorage.AimRngShared.BotVerbs) end
function DungeonRuns.RaiseTick(run: Run, now: number)
    local BV = DungeonRuns.BV()
    if not BV.On() or not (run :: any).VerbCorpses then return end -- (cheap exit: no fodder has died on this floor yet)
    BV.RaiseTick({ Store = run, List = function() return run.Enemies:GetChildren() end, PosOf = function(m) return run.Pos[m] end,
        Spawn = function(e, m)
            e.Pos = Vector3.new(e.Pos.X, DungeonGenerator.IsGroundArchetype(e.Archetype) and 5 or e.Pos.Y, e.Pos.Z)
            local sp = SpawnProxy(run, e)
            if sp and e.Counted then
                run.Folder:SetAttribute("TotalEnemies", (run.Folder:GetAttribute("TotalEnemies") or 0) + 1)
                run.Folder:SetAttribute("RemainingEnemies", (run.Folder:GetAttribute("RemainingEnemies") or 0) + 1)
            end
            return sp
        end }, now)
end

-- (LIVE FIX 2026-11-06, owner on the live game: "after killing everything, nothing happened and it still said 6 enemies were
-- remaining") RECONCILE, every 0.5 s on a solo regular floor: the enemies really left = counted stand-ins alive (not Dead / a goblin /
-- Uncounted) + counted ones not made yet (a linked room's Pending, the pack queue). A count ABOVE that for RECONCILE_TICKS checks in a
-- row (a kill whose bookkeeping failed) is corrected -- and clears the floor at 0 through CombatServer.FloorCount, like a kill. Never
-- raises the count, waits while a linked room is still being made ("busy"), skips boss / trial / revisit floors. A Dead stand-in left
-- behind (OnProxyKilled never ran) is removed after DEAD_LINGER s. Each correction is reported to the F6 ERRORS log ([FloorReconcile]).
DungeonRuns.RECONCILE_TICKS = 4 -- (x 0.5 s = 2 s)
DungeonRuns.DEAD_LINGER = 3
function DungeonRuns.Reconcile(run: Run, now: number)
    local r: any = run
    local f = run.Folder
    if not CombatServer or f:GetAttribute("FloorCleared") == true or f:GetAttribute("IsBossFloor") == true or run.BossTrial
        or (f:GetAttribute("Revisit") or 0) ~= 0 then r.Drift = 0 return end
    local lk = r.Linked
    local actual = 0
    local deadSeen = r.DeadSeen or {}
    r.DeadSeen = deadSeen
    for _, m in ipairs(run.Enemies:GetChildren()) do
        if m:GetAttribute("Dead") then
            local t0 = deadSeen[m]
            if not t0 then
                deadSeen[m] = now
            elseif now - t0 >= DungeonRuns.DEAD_LINGER then
                deadSeen[m] = nil
                run.Pos[m] = nil
                run.ShieldUntil[m] = nil
                m:Destroy()
            end
        elseif not m:GetAttribute("IsLootGoblin") and m:GetAttribute("Kind") ~= "LootGoblin" and not m:GetAttribute("Uncounted") then
            actual += 1
        end
    end
    for m in pairs(deadSeen) do if not m.Parent then deadSeen[m] = nil end end
    if lk then
        for i, list in pairs(lk.Pending) do
            if lk.Spawned[i] == "busy" then r.Drift = 0 return end
            if not lk.Spawned[i] then
                for _, e in ipairs(list) do if e.Counted and e.Kind ~= "LootGoblin" then actual += 1 end end
            end
        end
    end
    for _, pack in ipairs(r.PackQueue or {}) do
        for _, e in ipairs(pack) do if e.Kind ~= "LootGoblin" and (not lk or e.Counted) then actual += 1 end end
    end
    local rem = f:GetAttribute("RemainingEnemies") or 0
    if actual >= rem then r.Drift = 0 return end
    r.Drift = (r.Drift or 0) + 1
    if r.Drift < DungeonRuns.RECONCILE_TICKS then return end
    r.Drift = 0
    task.spawn(error, string.format("[FloorReconcile] count %d but %d left (%s %s floor %s%s): corrected", rem, actual,
        tostring(f:GetAttribute("Biome")), tostring(run.Config.Difficulty), tostring(run.Config.FloorNumber), lk and ", linked" or ""), 0)
    f:SetAttribute("RemainingEnemies", actual)
    local state = CombatServer.GetState(run.Player)
    if state then CombatServer.FloorCount(run.Player, state, f, false, actual) end
end

-- ==================== LINKED ROOMS PILOT (docs/LINKED_ROOMS.md; tunables + layout: AimRngShared/LinkedRooms) ====================
-- A linked floor's roster is placed room by room (DungeonGenerator.RollLinkedRoster). Nothing is queued: a room's stand-ins are
-- made when you come within SPAWN_HOPS links of it (rooms you never near cost nothing at all), its packs stay idle (the client
-- bots mill round their spots) until you're within WAKE_DIST of a pack member or hurt one -- then the whole pack wakes (attr
-- Awake). Only the EXIT room's foes count toward the clear; the others are Uncounted (the floor clears when the exit room is
-- empty, the rest may be skipped). The side room's cache opens once its packs are dead (folder attr LinkCache LOCKED / OPEN / USED).
-- run.Linked = { L = the layout, Pending = { [room] = roster entries }, Spawned = { [room] = true }, Cur = the room you're in, Cache }
-- (v2 RAMP) the floor's config as floor f (scaling, combat level, kill XP of a room further down the linked floor), one per floor
function DungeonRuns.LinkedCfg(run: Run, f: number): any
    local lk = (run :: any).Linked
    local cache = lk and lk.Cfg
    if lk and not cache then cache = {}; lk.Cfg = cache end
    local c = cache and cache[f]
    if not c then
        c = table.clone(run.Config)
        c.FloorNumber = f
        if cache then cache[f] = c end
    end
    return c
end

function DungeonRuns.LinkedSpawnRoom(run: Run, i: number, now: boolean?)
    local lk = (run :: any).Linked
    if not lk or lk.Spawned[i] then return end
    local list = lk.Pending[i] or {}
    lk.Pending[i] = {}
    -- (2026-10-26 ARRIVAL FX) a room made as someone walks in: its stand-ins carry WarpIn (the client warps them in)
    local warp = not now and workspace:GetServerTimeNow() or nil
    local function Make(e)
        local px = SpawnProxy(run, e)
        if warp and px then px:SetAttribute("WarpIn", warp) end
    end
    if now or #list <= LinkedRooms.SPAWN_BATCH then
        for _, e in ipairs(list) do Make(e) end
        lk.Spawned[i] = true
        return
    end
    -- (v3 perf) SPAWN_BATCH stand-ins a frame: no server (or client) frame makes a whole room; "busy" until the last one exists
    lk.Spawned[i] = "busy"
    task.spawn(function()
        for k, e in ipairs(list) do
            if runs[run.Player] ~= run or (run :: any).Linked ~= lk then return end -- (the floor changed)
            Make(e)
            if k % LinkedRooms.SPAWN_BATCH == 0 then task.wait() end
        end
        if (run :: any).Linked == lk then lk.Spawned[i] = true end
    end)
end

-- (SEALED ROOMS) a path's stragglers, once someone steps into the path (a handful: made at once)
function DungeonRuns.LinkedSpawnPath(run: Run, k: number)
    local lk = (run :: any).Linked
    if not lk or lk.PathSpawned[k] then return end
    lk.PathSpawned[k] = true
    local list = lk.PathPending[k] or {}
    lk.PathPending[k] = {}
    for _, e in ipairs(list) do SpawnProxy(run, e) end
end

-- (SEALED ROOMS) the floor's seal from what is left in each main room (folder attr LinkSeal; LinkedRooms.SealState)
function DungeonRuns.LinkedSeal(run: Run, here: { [number]: boolean })
    local lk = (run :: any).Linked
    if not lk then return end
    local left = {}
    for _, m in ipairs(run.Enemies:GetChildren()) do
        local r = m:GetAttribute("LinkRoom")
        if r and not m:GetAttribute("LinkPath") and not m:GetAttribute("Dead") and not m:GetAttribute("IsLootGoblin") then left[r] = (left[r] or 0) + 1 end
    end
    for i, list in pairs(lk.Pending) do
        if not lk.Spawned[i] then
            for _, e in ipairs(list) do if e.Kind ~= "LootGoblin" then left[i] = (left[i] or 0) + 1 end end
        end
    end
    local seal = LinkedRooms.SealState(lk, lk.L, left, here, os.clock())
    if seal ~= lk.Seal then
        lk.Seal = seal
        run.Folder:SetAttribute("LinkSeal", seal)
    end
end

function DungeonRuns.LinkedStart(run: Run, roster: { any })
    local L = DungeonGenerator.LinkedLayout(run.Config)
    local lk = { L = L, Pending = {}, PathPending = {}, Spawned = {}, PathSpawned = {}, Cur = 1, Cache = L.Side and "LOCKED" or "",
        WakeAfter = os.clock() + 1.5 } -- (WakeAfter: you land in the entry room first)
    for i = 1, #L.Rooms do lk.Pending[i] = {} end
    for _, e in ipairs(roster) do
        if e.LinkPath then -- (SEALED ROOMS: stragglers wait for someone in their path)
            lk.PathPending[e.LinkPath] = lk.PathPending[e.LinkPath] or {}
            table.insert(lk.PathPending[e.LinkPath], e)
        else
            table.insert(lk.Pending[e.LinkRoom or 1], e)
        end
    end
    ;(run :: any).Linked = lk
    run.Folder:SetAttribute("LinkCache", lk.Cache)
    run.Folder:SetAttribute("LinkRoom", 1)
    run.Folder:SetAttribute("LinkSpawned", "")
    run.Folder:SetAttribute("LinkSeal", nil)
    DungeonRuns.LinkedSpawnRoom(run, 1, true) -- (you start in the entry room, next to room 1; SEALED ROOMS: the rest on arrival)
    DungeonRuns.LinkedSeal(run, {})
end

-- (2026-10-26) ARRIVAL on its own fast loop (LinkedRooms.ARRIVE_TICK): only the box test for rooms not made yet, so a room's bots
-- warp in as you cross its doorway (LinkedTick below still does it too, with everything else, every 0.5 s)
task.spawn(function()
    while true do
        task.wait(LinkedRooms.ARRIVE_TICK)
        for _, run in pairs(runs) do
            local lk = (run :: any).Linked
            if lk and os.clock() >= (lk.WakeAfter or 0) then
                local char = run.Player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root and root.Position.Z >= 450 then
                    for i = 1, #lk.L.Rooms do
                        if not lk.Spawned[i] and LinkedRooms.ArriveAt(lk.L, i, root.Position) then pcall(DungeonRuns.LinkedSpawnRoom, run, i) end
                    end
                end
            end
        end
    end
end)
-- every 0.5 s (the run loop): which room you're in, spawn the rooms near it, wake packs, the side cache
function DungeonRuns.LinkedTick(run: Run)
    local lk = (run :: any).Linked
    if not lk then return end
    local L = lk.L
    local char = run.Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or root.Position.Z < 450 or os.clock() < (lk.WakeAfter or 0) then return end
    local pos = root.Position
    local cur, inside = LinkedRooms.RoomAt(L, pos)
    if cur ~= lk.Cur then
        lk.Cur = cur
        run.Folder:SetAttribute("LinkRoom", cur)
    end
    -- (SEALED ROOMS) ARRIVAL: a room once you're in it or in the leg / band of a path into it, a path's stragglers once you're in it
    for i = 1, #L.Rooms do
        if not lk.Spawned[i] and LinkedRooms.ArriveAt(L, i, pos) then DungeonRuns.LinkedSpawnRoom(run, i) end
    end
    for k = 1, #L.Paths do
        if not lk.PathSpawned[k] and LinkedRooms.InPath(L, k, pos) then DungeonRuns.LinkedSpawnPath(run, k) end
    end
    -- WAKE (v3: rooms engage you): stepping inside a room wakes every pack in it, stepping into a path its stragglers; a pack member
    -- within WAKE_DIST or hurt wakes its pack. A pack that gave up (Homing, over AWAKE_CAP) only wakes in its own room or when hurt again.
    local inPath = nil
    for k, pa in ipairs(L.Paths) do
        local x0, x1, z0, z1 = LinkedRooms.PathBox(pa, 0)
        if pos.X >= x0 - 2 and pos.X <= x1 + 2 and pos.Z >= z0 and pos.Z <= z1 then inPath = k end
    end
    lk.WakeAt = lk.WakeAt or {}
    local wake = nil
    local awakeN = 0
    for _, m in ipairs(run.Enemies:GetChildren()) do
        local pk = m:GetAttribute("LinkPack")
        if pk and not m:GetAttribute("Dead") then
            if m:GetAttribute("Awake") then
                awakeN += 1
            else
                local p = run.Pos[m] or m:GetAttribute("SpawnPos")
                local h = m:GetAttribute("Health") or 0
                local home = (inside and m:GetAttribute("LinkRoom") == cur and not m:GetAttribute("LinkPath")) or (inPath ~= nil and m:GetAttribute("LinkPath") == inPath)
                local hurt
                if m:GetAttribute("Homing") then hurt = h < (m:GetAttribute("HomingHp") or 0) else hurt = h < (m:GetAttribute("MaxHealth") or 0) end
                local near = not m:GetAttribute("Homing") and p ~= nil and (p - pos).Magnitude <= LinkedRooms.WAKE_DIST
                    and LinkedRooms.WakeReach(L, m:GetAttribute("LinkRoom"), m:GetAttribute("LinkPath"), pos) -- (BOTFIX 2026-10-24: not through the rock)
                if home or hurt or near then
                    wake = wake or {}
                    wake[pk] = true
                end
            end
        end
    end
    if wake then
        local now = os.clock()
        for _, m in ipairs(run.Enemies:GetChildren()) do
            local pk = m:GetAttribute("LinkPack")
            if pk and wake[pk] and not m:GetAttribute("Awake") and not m:GetAttribute("Dead") then
                m:SetAttribute("Awake", true)
                m:SetAttribute("Homing", nil)
                awakeN += 1
            end
            if pk and wake[pk] then lk.WakeAt[pk] = lk.WakeAt[pk] or now end
        end
    end
    -- AWAKE CAP (v3, perf): past LinkedRooms.AWAKE_CAP awake bots the earliest-woken packs from other rooms give up and walk home
    if awakeN > LinkedRooms.AWAKE_CAP then
        local packs = {}
        for pk, at in pairs(lk.WakeAt) do table.insert(packs, { pk, at }) end
        table.sort(packs, function(a, b) return a[2] < b[2] end)
        local members = {}
        for _, m in ipairs(run.Enemies:GetChildren()) do
            local pk = m:GetAttribute("LinkPack")
            if pk and m:GetAttribute("Awake") and not m:GetAttribute("Dead") then
                members[pk] = members[pk] or {}
                table.insert(members[pk], m)
            end
        end
        for _, e in ipairs(packs) do
            if awakeN <= LinkedRooms.AWAKE_CAP then break end
            local list = members[e[1]]
            if list and list[1]:GetAttribute("LinkRoom") ~= cur then
                for _, m in ipairs(list) do
                    m:SetAttribute("Awake", false)
                    m:SetAttribute("Homing", true)
                    m:SetAttribute("HomingHp", m:GetAttribute("Health") or 0)
                    awakeN -= 1
                end
                lk.WakeAt[e[1]] = nil
            end
        end
    end
    run.Folder:SetAttribute("LinkAwake", awakeN)
    DungeonRuns.LinkedSeal(run, { [cur] = inside or nil })
    if L.Side and lk.Cache == "LOCKED" and lk.Spawned[L.Side] == true then
        local left = 0
        for _, m in ipairs(run.Enemies:GetChildren()) do
            if m:GetAttribute("LinkRoom") == L.Side and not m:GetAttribute("Dead") and not m:GetAttribute("IsLootGoblin") then left += 1 end
        end
        if left == 0 then
            lk.Cache = "OPEN"
            run.Folder:SetAttribute("LinkCache", "OPEN")
        end
    end
end

-- the exit room is clear: the floor's chest + portals (the client builds them there). The other rooms keep their packs -- you
-- may still go back for the side room and its cache; the next floor clears everything as usual.
function DungeonRuns.LinkedClearExit(run: Run)
    local lk = (run :: any).Linked
    for _, m in ipairs(run.Enemies:GetChildren()) do
        local room = m:GetAttribute("LinkRoom")
        if not lk or room == nil or room == lk.L.Exit then
            run.Pos[m] = nil
            run.ShieldUntil[m] = nil
            if m:GetAttribute("Dead") then task.delay(0.15, function() if m.Parent then m:Destroy() end end) else m:Destroy() end
        end
    end
    if lk then lk.Pending[lk.L.Exit] = {} end
end

-- (v2, owner: "Linked floor can count as 2") ONE HELPER for everything that counts floors cleared: a linked floor's clear is
-- credited once more as the floor it skipped (CombatServer's kill path already credited this one) -- the floor stats / title /
-- unlock record, the run summary, contracts / Job Board / Season Feats / bounties (ContractEvent "FloorClear") and the floor's
-- Season XP. The "clear a floor fast" job only counts the real clear (no Elapsed here).
function DungeonRuns.LinkedFloorCredit(player: Player, run: Run)
    if not CombatServer then return end
    local cfg = run.Config
    local state = CombatServer.GetState(player)
    local skipped = (cfg.FloorNumber or 1) + LinkedRooms.FLOOR_STEP - 1
    for f = (cfg.FloorNumber or 1) + 1, skipped do
        local st = state.StatsTracking
        if st and ItemData.RecordFloorClear(st, cfg.Difficulty, f, run.Folder:GetAttribute("BotSkill"), not (state :: any).FloorHitTaken, state.Level) and CombatServer.TreeClearBonus then
            CombatServer.TreeClearBonus(player, state, cfg.Difficulty)
        end
        if CombatServer.RS then CombatServer.RS.Add(player, "Floors"); CombatServer.RS.Max(player, "BestFloor", f) end
        CombatServer.ContractEvent(player, state, "FloorClear", 1, { Difficulty = cfg.Difficulty, Mods = run.Folder:GetAttribute("Mods"),
            NoHit = not (state :: any).FloorHitTaken, Biome = run.Folder:GetAttribute("Biome"), Linked = true })
        CombatServer.AddSeasonXP(player, state, require(game.ReplicatedStorage.AimRngShared.Seasons).XP.FloorClear)
    end
end

-- the side room's cache (OpenChest "LinkCache"): once, after its packs are dead, standing by it -> a floor chest's loot
function DungeonRuns.LinkedCache(player: Player, run: Run)
    local lk = (run :: any).Linked
    if not lk or lk.Cache ~= "OPEN" or not CombatServer then return end
    local side = lk.L.Side and lk.L.Rooms[lk.L.Side]
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not side or not root or Vector3.new(root.Position.X - side.X, 0, root.Position.Z - side.Z).Magnitude > 24 then return end
    lk.Cache = "USED"
    run.Folder:SetAttribute("LinkCache", "USED")
    CombatServer.GiveFloorLoot(player, false)
end

-- (Studio / F6 test hooks: DevCmd ["linkedrooms", "spawnall" | "wakeall" | "goto", room | "state" | "cache" | "stats"])
function DungeonRuns.LinkedDev(player: Player, action: string, a: any): string
    local run = runs[player]
    if action == "stats" and CombatServer then -- (pace probe: what the run has paid so far, any floor)
        local st = CombatServer.GetState(player)
        local rs = CombatServer.RS and CombatServer.RS.Get(player)
        local alive, hp, xp = 0, 0, 0
        for _, m in ipairs(run and run.Enemies:GetChildren() or {}) do
            if not m:GetAttribute("Dead") then alive += 1; hp += m:GetAttribute("MaxHealth") or 0; xp += m:GetAttribute("XpReward") or 0 end
        end
        return HttpService:JSONEncode({ Level = st.Level, XP = st.XP, Gold = st.Gold, Kills = rs and rs.Kills, Items = rs and rs.Items,
            Alive = alive, AliveHp = hp, AliveXp = xp, Queued = run and (run :: any).PackQueue and #(run :: any).PackQueue or 0,
            Remaining = run and run.Folder:GetAttribute("RemainingEnemies"), Cleared = run and run.Folder:GetAttribute("FloorCleared") })
    end
    local lk = run and (run :: any).Linked
    if not lk then return "not on a linked floor" end
    if action == "cache" then -- (the side cache through the real server path; stand by it first: "goto", side)
        DungeonRuns.LinkedCache(player, run)
        return "cache " .. tostring(lk.Cache)
    end
    local L = lk.L
    if action == "spawnall" then
        for i = 1, #L.Rooms do DungeonRuns.LinkedSpawnRoom(run, i, true) end
        for k = 1, #L.Paths do DungeonRuns.LinkedSpawnPath(run, k) end
        return "spawned every room"
    elseif action == "wakeall" then
        for _, m in ipairs(run.Enemies:GetChildren()) do if m:GetAttribute("LinkPack") then m:SetAttribute("Awake", true) end end
        return "woke every pack"
    elseif action == "goto" then
        local r = L.Rooms[math.clamp(tonumber(a) or 1, 1, #L.Rooms)]
        local char = player.Character
        if char then char:PivotTo(CFrame.lookAt(Vector3.new(r.X, 7, r.Z - L.Half + 14), Vector3.new(r.X, 7, r.Z))) end
        return "moved to room " .. tostring(a)
    end
    local rooms = {}
    for i, r in ipairs(L.Rooms) do
        local alive, awake, hp = 0, 0, 0
        for _, m in ipairs(run.Enemies:GetChildren()) do
            if m:GetAttribute("LinkRoom") == i and not m:GetAttribute("Dead") then
                alive += 1
                hp += m:GetAttribute("MaxHealth") or 0
                if m:GetAttribute("Awake") then awake += 1 end
            end
        end
        table.insert(rooms, { Room = i, Kind = r.Kind, X = r.X, Z = r.Z, Spawned = lk.Spawned[i] == true, Pending = #(lk.Pending[i] or {}), Alive = alive, Awake = awake, Hp = hp })
    end
    return HttpService:JSONEncode({ Cur = lk.Cur, Main = L.Main, Side = L.Side, Cache = lk.Cache, Rooms = rooms, Seal = lk.Seal,
        Total = run.Folder:GetAttribute("TotalEnemies"), Remaining = run.Folder:GetAttribute("RemainingEnemies"), Cleared = run.Folder:GetAttribute("FloorCleared") })
end

function DungeonRuns.ClearEnemies(player: Player)
    local r = runs[player]
    if r then ClearEnemies(r) end
end

-- timed objectives start when you walk out of the safe entry room (SafeLocked), not when the floor loads
local function ObjectiveTimer(player: Player, run: Run, seconds: number)
    local folder = run.Folder
    local token = folder:GetAttribute("RunToken")
    local obj = run.Objective
    task.spawn(function()
        -- (SafeLocked can still be true from the floor before for a moment: wait for the entry room first)
        local t0 = os.clock()
        while player:GetAttribute("SafeLocked") == true and os.clock() - t0 < 3 do task.wait(0.1) end
        while runs[player] == run and folder:GetAttribute("RunToken") == token and player:GetAttribute("SafeLocked") ~= true do
            task.wait(0.25)
        end
        if runs[player] ~= run or folder:GetAttribute("RunToken") ~= token or obj.State ~= "" then return end
        obj.Deadline = os.clock() + seconds
        folder:SetAttribute("ObjDeadline", workspace:GetServerTimeNow() + seconds)
        task.wait(seconds + 0.2)
        if runs[player] == run and folder:GetAttribute("RunToken") == token then DungeonRuns.FailObjective(player) end
    end)
end
-- BOUNTY CONTRACT (UPDATE 7, BountyContract): this week's named elite joins the floor (uncounted: like the goblin, it can
-- leave). The first hit starts its flee clock; not dead in FLEE_TIME s, or the floor clears / you leave with it alive = it
-- escapes (the floor's clean-up removes every enemy left, so killing it first is the point).
function DungeonRuns.SpawnContract(run: Run, force: boolean?): Instance?
    if not CombatServer then return nil end
    local BC = require(game.ReplicatedStorage.AimRngShared.BountyContract)
    local state = CombatServer.GetState(run.Player)
    local c = BC.Ensure(state, run.Player.UserId)
    if not c or c.Done then return nil end
    if not force and math.random() >= BC.APPEAR and not require(game.ReplicatedStorage.AimRngShared.WorldAlerts).Is("CONTRACT_HUNT") then return nil end
    local pool = {}
    for _, p in ipairs(run.Enemies:GetChildren()) do
        if p:GetAttribute("Kind") == "Bot" and not p:GetAttribute("IsSummon") and run.Pos[p] then table.insert(pool, p) end
    end
    if #pool == 0 then return nil end
    local base = pool[math.random(1, #pool)]
    local at = run.Pos[base] + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
    local proxy = SpawnProxy(run, { Kind = "Bot", Archetype = base:GetAttribute("Archetype"), Pos = at, Elite = true })
    proxy:SetAttribute("Contract", true)
    proxy:SetAttribute("Uncounted", true)
    proxy:SetAttribute("ContractName", c.Name) -- (before Bounty: the client builds the skull + name when Bounty arrives)
    proxy:SetAttribute("Bounty", true) -- (the client's gold skull)
    proxy:SetAttribute("MaxHealth", math.round((proxy:GetAttribute("MaxHealth") or 1) * BC.HpMult(c)))
    proxy:SetAttribute("Health", proxy:GetAttribute("MaxHealth"))
    require(game.ReplicatedStorage.AimRngShared.BotRoles).RescaleShell(proxy) -- (ENEMY ATTACKS PILOT, review L: a Shelled contract target)
    local owner, token = run.Player, run.Folder:GetAttribute("RunToken")
    Remotes.GetEvent("CombatFx"):FireClient(owner, "Text", "MARKED MAN: " .. string.upper(c.Name) .. " is here. Finish it fast or it runs.", Color3.fromRGB(255, 205, 80))
    local escaped = false
    local function Escape(why: string)
        if escaped or proxy:GetAttribute("Dead") or c.Done then return end
        escaped = true
        if proxy.Parent then proxy:Destroy() end
        c.Escapes = math.min(BC.MAX_ESCAPES, (c.Escapes or 0) + 1)
        if owner.Parent then
            Remotes.GetEvent("CombatFx"):FireClient(owner, "Text", string.upper(c.Name) .. " " .. why .. ". It'll be back tougher (escapes: " .. c.Escapes .. ").", Color3.fromRGB(255, 160, 80))
        end
    end
    local clock = false
    proxy:GetAttributeChangedSignal("Health"):Connect(function()
        if clock or not proxy.Parent then return end
        if (proxy:GetAttribute("Health") or 0) < (proxy:GetAttribute("MaxHealth") or 0) then
            clock = true
            proxy:SetAttribute("FleeAt", workspace:GetServerTimeNow() + BC.FLEE_TIME)
            task.delay(BC.FLEE_TIME, function() Escape("ESCAPED") end)
        end
    end)
    task.spawn(function() -- (the floor clears -- its clean-up takes every enemy left -- or you leave, with it alive: it slips away)
        while not proxy:GetAttribute("Dead") do
            task.wait(0.25)
            if proxy:GetAttribute("Dead") then return end
            if not proxy.Parent or runs[owner] ~= run or run.Folder:GetAttribute("RunToken") ~= token or run.Folder:GetAttribute("FloorCleared") == true then
                Escape("SLIPPED AWAY")
                return
            end
        end
    end)
    return proxy
end

-- BOUNTY objective: mark one ordinary bot (tougher; the client draws a gold skull over it). false = no bot to mark.
local function MarkBounty(run: Run): boolean
    local pool = {}
    for _, p in ipairs(run.Enemies:GetChildren()) do
        if p:GetAttribute("Kind") == "Bot" and not p:GetAttribute("IsSummon") then table.insert(pool, p) end
    end
    if #pool == 0 then return false end
    local target = pool[math.random(1, #pool)]
    target:SetAttribute("Bounty", true)
    target:SetAttribute("MaxHealth", math.round((target:GetAttribute("MaxHealth") or 1) * FloorObjectives.BOUNTY_HP))
    target:SetAttribute("Health", target:GetAttribute("MaxHealth"))
    require(game.ReplicatedStorage.AimRngShared.BotRoles).RescaleShell(target) -- (ENEMY ATTACKS PILOT, review L: a Shelled bounty)
    return true
end

-- Starts (or advances to) a floor. Returns what the client needs to build it.
function DungeonRuns.StartFloor(player: Player, config: any): any
    local folder = RunFolder(player)
    if not folder then return nil end
    local run = runs[player]
    -- (LINKED ROOMS v2: a linked floor counts as 2 -- the portal after it leads one floor further; the client asks for the next floor)
    if run and (run :: any).LinkNext and config.FloorNumber == (run :: any).LinkNext - 1 then config.FloorNumber = (run :: any).LinkNext end
    if run then (run :: any).LinkNext = nil end
    if not run then
        run = {
            Player = player, Folder = folder, Enemies = folder:FindFirstChild("Enemies"), Config = config, NextId = 0,
            Pos = {}, Recent = {}, HitTimes = {}, ChestsOpened = {}, VaultOpened = false, LastHazard = 0,
            LastSummon = 0, ShieldUntil = {}, OutsideTicks = 0,
        }
        runs[player] = run
        if CombatServer then CombatServer.ResetRunBoons(player) end -- a fresh run starts without boons
        if CombatServer then CombatServer.StartRunLives(player) end -- and with full lives
        if CombatServer then CombatServer.BeginRunLoot(player) end -- run loot starts fresh (unclaimed lost loot expires)
    else
        -- leaving the floor: its drops wait there (BACK PORTAL); anything older is missed (Legendary+ -> LOST LOOT)
        local leaving = run.Config and run.Config.FloorNumber
        local stepForward = not run.Revisit and leaving == config.FloorNumber - 1
        if CombatServer then CombatServer.MissGroundLoot(player, nil, stepForward and leaving or nil) end
        -- remember the floor you leave as it is now (cleared, chest opened): the next floor's back portal rebuilds it
        if run.CurSnap and stepForward then
            run.CurSnap.LeaveAttrs = folder:GetAttributes()
            run.PrevSnap = run.CurSnap
        else
            run.PrevSnap = nil
        end
        run.Revisit = nil
        folder:SetAttribute("Revisit", 0)
        ClearEnemies(run)
        run.Config = config
        run.ChestsOpened = {}
        if CombatServer and CombatServer.FullHeal then CombatServer.FullHeal(player) end -- (through a portal: full health)
        run.VaultOpened = false
        run.Recent = {}
        run.HitTimes = {}
        run.OutsideTicks = 0
    end
    config.Seed = math.random(1, 2 ^ 30)
    -- (Studio A/B hook, cbtree balance pass: workspace attr DevFloorSeed = the same floor layout + roster every time)
    if game:GetService("RunService"):IsStudio() and tonumber(workspace:GetAttribute("DevFloorSeed")) then config.Seed = tonumber(workspace:GetAttribute("DevFloorSeed")); math.randomseed(config.Seed) end
    -- (every floor at your CURRENT level: enemy XP / toughness follow you as you level mid-run -- LEVELING PACE)
    if CombatServer then config.PlayerLevel = CombatServer.GetState(player).Level or config.PlayerLevel end

    -- TRIAL OF ASCENSION (AscensionTrials): started by EndgameServer with config.AscTrial on floor 1; the run remembers it
    -- (later floors come through the normal portal), floor FLOORS is The Ascendant's arena
    if config.FloorNumber == 1 then run.AscTrial = config.AscTrial end
    if run.AscTrial then
        config.AscTrial = run.AscTrial
        config.BossArena = config.FloorNumber >= AscensionTrials.FLOORS
        if config.FloorNumber == 1 then run.AscTrial.StartClock = os.clock() end
    end
    folder:SetAttribute("AscTrial", run.AscTrial and run.AscTrial.Tier or 0)
    -- THE DAILY LINE (UPDATE 7 B6, DailyLine): started with config.Line on floor 1; floor 3 is a boss arena
    if config.FloorNumber == 1 then
        run.Line = config.Line == true
        run.LineStart = os.clock()
        folder:SetAttribute("Line", run.Line)
    end
    if run.Line then config.BossArena = config.FloorNumber >= DailyLine.FLOORS end
    -- (2026-10-22 RUN LENGTHS v4: runs are 6 floors with the boss on 6; maps and the Daily Challenge keep 5 floors with their
    -- boss on 5, pinned here -- they used to ride the old 5-floor schedules; everything else may roll the floor-3 mini-boss)
    do
        local first = config.FloorNumber == 1
        local rift = if first then config.Rift else run.Rift
        local daily = if first then (config.Daily == true) else run.Daily
        if rift then config.BossArena = config.FloorNumber >= Rifts.FLOORS
        elseif daily then config.BossArena = config.FloorNumber >= DailyChallenge.FLOORS
        elseif not run.AscTrial and not run.Line then ItemData.RollMidBoss(run, config) end
    end
    local isBossFloor = ItemData.IsBossConfig(config)
    -- Daily Challenge (DailyChallenge): started by EndgameServer with config.Daily; every floor's modifiers and
    -- event come from the day's fixed challenge, and floor 1 starts the clock.
    if config.FloorNumber == 1 then
        run.Daily = config.Daily == true
        run.DailyStart = os.clock()
        folder:SetAttribute("Daily", run.Daily)
        folder:SetAttribute("DailyStart", run.Daily and workspace:GetServerTimeNow() or 0)
        -- Rift (Rifts): opened with a sigil by EndgameServer; timed from floor 1
        run.Rift = config.Rift
        if run.Rift then run.Rift.StartClock = os.clock() end
        folder:SetAttribute("Rift", run.Rift and run.Rift.Tier or 0)
        folder:SetAttribute("MapLayout", run.Rift and run.Rift.Layout or nil) -- (0.62 MAPS v3)
        folder:SetAttribute("RiftStart", run.Rift and workspace:GetServerTimeNow() or 0)
        if run.Rift and LinkedRooms.For(player) and not run.Rift.LinkTime then -- (LINKED maps: a linked floor runs longer than the two it replaces)
            run.Rift.LinkTime = true
            run.Rift.Limit = math.round((run.Rift.Limit or Rifts.TIME_LIMIT) * LinkedRooms.MAP_TIME)
        end
        folder:SetAttribute("RiftLimit", run.Rift and run.Rift.Limit or Rifts.TIME_LIMIT) -- (MAP TREE timer)
    end
    do -- (LINKED ROOMS pilot, F6 "Linked rooms": this player's solo REGULAR floors are a line of rooms -- never a boss / mini-boss
        -- floor, a trial, the Daily, the Gauntlet Run or a map; v2: only when the floor after it is a regular one too, since a linked
        -- floor counts as LinkedRooms.FLOOR_STEP floors -- boss and mini-boss arenas stay where the schedule puts them)
        local mode = ItemData.RunMode(config.Difficulty, config.Endless)
        local nxt = (config.FloorNumber or 1) + 1
        local fits = not ItemData.IsBossFloor(config.Difficulty, config.Endless, nxt) and (mode.Endless or mode.MaxWaves == nil or nxt <= mode.MaxWaves)
        local rift = run.Rift or config.Rift
        if rift then fits = nxt < Rifts.FLOORS end -- (2026-10-22 MAPS linked too: floors 1-2 + 3-4, the guardian's floor 5 stays an arena)
        config.Linked = (LinkedRooms.For(player) and fits and not isBossFloor and not config.BossTrial and not run.AscTrial and not run.Daily
            and not run.Line) or nil
    end
    if run.Rift and config.FloorNumber <= Rifts.FLOORS then
        config.ForceMods = table.clone(run.Rift.Mods or {}) -- the sigil's modifiers apply to every rift floor
        config.MapTier = run.Rift.Tier or 1 -- (MAP XP 2026-10-24: ItemData.RunLengthXp -> MAP_XP_TIER)
        config.ModScale = Rifts.ModScale(run.Rift.Tier) -- (MAPS V2: every map mod's value x this; FloorMods.V)
        config.MonsterLevel = run.Rift.Level -- (MAP LEVEL: your level + 0..10 when it opened; drops stay wearable)
        config.PowerLevel = run.Rift.PowerLevel -- (MAP PACING 2026-10-31: enemy power without the rarity's levels, Rifts.PowerLevel)
        config.BotSkill = run.Rift.Skill or config.BotSkill -- (the map's bot skill: the device's pick or Standard, for the whole map)
        config.BossSkill = run.Rift.BossSkill -- (BOT MOVEMENT POE: the guardian keeps the pace of the map's old skill roll)
        config.SkillReward = run.Rift.SkillReward -- (BOT MOVEMENT POE: the map's kill-reward multiplier, Rifts.MapReward)
        local A = run.Rift.Atlas or {} -- (MAP TREE: more elites / goblins on map floors)
        local MI = require(game.ReplicatedStorage.AimRngShared.MapInks) -- (UPDATE 7 MAP INKS: more elites / goblins)
        config.AtlasElite = 1 + (A.Elites or 0) + MI.Sum(run.Rift, "Elites")
        config.AtlasGoblin = A.K_GOLDEN and 1 or math.min(1, (A.Goblin or 0) + MI.Sum(run.Rift, "Goblin"))
        -- (0.66) floor 5 = the tier band's own guardian (Rifts.GUARDIANS), not the regular boss pool
        config.MapGuardian = (config.FloorNumber >= Rifts.FLOORS) and Rifts.GuardianArchetype(run.Rift.Tier, run.Rift) or nil -- (0.92: per map)
    end
    if run.AscTrial then -- (two HARD floors: an elite pack each; the boss floor plain)
        config.ForceMods = (config.FloorNumber < AscensionTrials.FLOORS) and table.clone(AscensionTrials.HARD_MODS) or {}
        config.ForceEvent = nil
    end
    -- MIXED RUNS: every floor rolls its own biome (DungeonGenerator.NextBiome). The Daily's order is seeded by the
    -- day (same for everyone); Boss Trials and dev floors with a biome named (config.FixedBiome) keep theirs.
    if config.FloorNumber == 1 then
        run.BiomeBag, run.LastBiome = nil, nil
        run.MiniBag, run.LastMini, run.BossSeen = nil, nil, nil -- (BOSS PLAN: a fresh run, fresh bosses)
        run.BiomeRng = run.Daily and Random.new(DailyChallenge.Today() * 7919 + 101) or Random.new()
    end
    if run.Rift and run.Rift.Biome then
        config.Biome = run.Rift.Biome -- (0.62 MAPS v3: a map is one place -- every floor in its biome)
    elseif not config.BossTrial and not config.FixedBiome then
        config.Biome = (run.Daily and DailyChallenge.BiomeOf(DailyChallenge.ForDay(DailyChallenge.Today()), config.FloorNumber))
            or (run.Line and DailyLine.ForDay(DailyLine.Today()).Biomes[config.FloorNumber])
            or DungeonGenerator.NextBiome(run, run.BiomeRng)
    end
    -- Boss Trial (BossTrials): one fight, no floor modifiers / events, timed from the start
    folder:SetAttribute("TrialDone", false)
    if config.BossTrial then
        run.BossTrial = config.BossTrial
        run.BossTrial.StartClock = os.clock()
        config.ForceMods = {}
        folder:SetAttribute("BossTrial", config.BossTrial.Id)
        folder:SetAttribute("TrialTier", config.BossTrial.Tier)
        folder:SetAttribute("TrialStart", workspace:GetServerTimeNow())
    else
        folder:SetAttribute("BossTrial", "")
    end
    folder:SetAttribute("WeeklyMod", (config.BossTrial and config.WeeklyMod) or "") -- (UPDATE 7: the weekly boss's modifier)
    if run.Daily then
        local dc = DailyChallenge.ForDay(DailyChallenge.Today())
        if config.FloorNumber <= DailyChallenge.FLOORS then
            config.ForceMods = dc.Mods[config.FloorNumber] or {}
            config.ForceEvent = (dc.Events[config.FloorNumber] ~= "" and dc.Events[config.FloorNumber]) or nil
            config.BotSkill = dc.BotSkill
        end
    end
    if run.Line and config.FloorNumber <= DailyLine.FLOORS then
        local lc = DailyLine.ForDay(DailyLine.Today())
        config.ForceMods = table.clone(lc.Mods[config.FloorNumber] or {})
        config.ForceEvent = nil
        config.BotSkill = lc.BotSkill
    end
    -- Floor modifiers (FloorMods): rolled per floor; config.ForceMods (dev) overrides the roll.
    local mods = config.ForceMods or FloorMods.Roll(config.FloorNumber, isBossFloor)
    config.Mods = mods
    if FloorMods.Has(mods, "SWARMING") then
        if config.ModScale then config.SwarmMult = 1 + FloorMods.V("SWARMING", config.ModScale, true) -- (MAPS V2: the map's real packs-a-room number)
        else config.CountMult = (config.CountMult or 1) * 1.5 end
    end
    local modReward = FloorMods.RewardBonus(mods, config.ModScale) -- (MAPS V2: x the map's ModScale)
    if run.Rift then modReward += Rifts.RewardBonus(run.Rift.Tier) + ((run.Rift.Atlas or {}).Reward or 0) end
    if CombatServer then
        local st = CombatServer.GetState(player)
        st.FloorLuckMult = (1 + modReward * 0.5 + (run.Rift and Rifts.ExtraRarity(run.Rift) or 0)) * (1 + (run.Rift and (run.Rift.Atlas or {}).Luck or 0)) -- (MAPS V2: + a Rupture's rarity)
        st.FloorHitTaken = false -- "clear a floor without taking damage" contract
        if CombatServer.Zen then pcall(CombatServer.Zen.ThreadClear, player, st) end -- (ZENITH: Unbroken Thread starts every floor at 0)
    end
    -- Dungeon event (DungeonEvents): Blessed floors always get a Boon Shrine; config.ForceEvent (dev) overrides.
    local eventId = config.ForceEvent or ((not config.BossTrial and not run.AscTrial) and DungeonEvents.Roll(config.FloorNumber, isBossFloor)) or nil
    -- (UPDATE 8 Phase 5: boons are cut -- no Boon Shrines; BLESSED no longer rolls)
    run.Event = eventId and { Id = eventId, Uses = 0, Done = false } or nil
    run.AmbushLeft, run.TrialUntil, run.TrialKills = 0, 0, 0
    -- RUN ENCOUNTER (UPDATE 7, Encounters): an optional aim event from its unlock level (the Vault Lock pilot)
    local encId = nil
    if not config.BossTrial and not run.AscTrial and not run.Daily and not run.Line then
        local lvl = CombatServer and CombatServer.GetState(player) and CombatServer.GetState(player).Level or config.PlayerLevel or 1
        -- (Studio: workspace attr DevEncounter = "VAULT_LOCK" puts it on every floor that can have one)
        local dev = game:GetService("RunService"):IsStudio() and workspace:GetAttribute("DevEncounter") or nil
        encId = config.ForceEncounter or ((type(dev) == "string" and dev ~= "" and config.FloorNumber >= 2 and not isBossFloor) and dev or nil)
            or Encounters.Roll(lvl, config.FloorNumber, isBossFloor)
        -- (UPDATE 7 MAP INKS: the Ink of Echoes puts an encounter on every middle map floor; WORLD ALERTS: ENCOUNTER RUSH everywhere)
        if not encId and ((run.Rift and require(game.ReplicatedStorage.AimRngShared.MapInks).Has(run.Rift, "InkEchoes"))
            or require(game.ReplicatedStorage.AimRngShared.WorldAlerts).Is("ENCOUNTER_RUSH")) then
            for _ = 1, 30 do
                encId = Encounters.Roll(lvl, config.FloorNumber, isBossFloor)
                if encId or config.FloorNumber < 2 or isBossFloor then break end
            end
        end
    end
    if not encId and config.Linked and not config.BossTrial and not run.AscTrial then -- (LINKED ROOMS v2: counts as 2 floors -- a second roll; it stands in the side room)
        local lvl = CombatServer and CombatServer.GetState(player) and CombatServer.GetState(player).Level or config.PlayerLevel or 1
        encId = Encounters.Roll(lvl, config.FloorNumber + 1, isBossFloor)
    end
    run.Encounter = encId and { Id = encId, State = "" } or nil
    if require(game.ReplicatedStorage.AimRngShared.WorldAlerts).Is("ELITE_HUNT") then config.AtlasElite = (config.AtlasElite or 1) * 1.5 end -- (UPDATE 7 WORLD ALERTS)
    if CombatServer then (CombatServer.GetState(player) :: any).CurBiome = config.Biome end -- (WORLD SURGE: the world you're on)
    DungeonGenerator.PlanBoss(run, config) -- (no repeated bosses within a run)
    -- (UPDATE 8 Phase 5: PACKS EVERYWHERE -- every regular floor unless the player's F6 "Packs off" is set; never trials /
    -- Ascension / the Daily / the Gauntlet Run)
    config.PacksPilot = (PacksPilot.For(player) and not config.BossTrial and not run.AscTrial and not run.Daily and not run.Line) or nil
    config.SpecialRun = (config.BossTrial or run.AscTrial or run.Daily or run.Line or run.Rift) and true or nil -- (RUN PACE XP: ItemData.RunLengthXp skips it)
    config.LinkL, config.LinkBuild = nil, nil -- (LINKED ROOMS: config.Linked was decided above, before the encounter roll)
    ;(run :: any).Linked = nil
    ;(config :: any).MiniPacks = nil -- (RollFloorRoster sets it on a mini-boss floor with a pack wave)
    local roster = config.Linked and DungeonGenerator.RollLinkedRoster(config) or DungeonGenerator.RollFloorRoster(config)
    folder:SetAttribute("Linked", config.Linked == true) -- (LINKED ROOMS pilot: the client builds the same line of rooms)
    folder:SetAttribute("LinkNext", config.Linked and (config.FloorNumber + LinkedRooms.FLOOR_STEP) or 0) -- (v2: where its portal leads)
    if config.Linked then (run :: any).LinkNext = config.FloorNumber + LinkedRooms.FLOOR_STEP end
    folder:SetAttribute("Biome", config.Biome)
    folder:SetAttribute("Difficulty", config.Difficulty)
    folder:SetAttribute("Endless", config.Endless == true)
    folder:SetAttribute("Floor", config.FloorNumber)
    folder:SetAttribute("MonsterLevel", DungeonGenerator.MonsterLevel(config)) -- (CONTENT LEVEL: loot item level, XP, the HUD)
    folder:SetAttribute("BossArena", ItemData.IsBossConfig(config))
    folder:SetAttribute("PlayerLevel", config.PlayerLevel)
    folder:SetAttribute("BotSkill", config.BotSkill or 4)
    folder:SetAttribute("BossSkill", config.BossSkill) -- (BOT MOVEMENT POE: nil off maps)
    folder:SetAttribute("SkillReward", config.SkillReward) -- (BOT MOVEMENT POE: nil off maps -> the bot skill's own Reward)
    folder:SetAttribute("Seed", config.Seed)
    folder:SetAttribute("Mods", table.concat(mods, ","))
    folder:SetAttribute("ModScale", config.ModScale) -- (MAPS V2: nil off maps; CombatServer + the client read it)
    folder:SetAttribute("Event", eventId or "")
    folder:SetAttribute("EventState", "")
    folder:SetAttribute("Encounter", encId or "")
    folder:SetAttribute("EncounterState", "")
    folder:SetAttribute("TrialUntil", 0)
    folder:SetAttribute("TrialKills", 0)
    folder:SetAttribute("ModReward", modReward)
    folder:SetAttribute("IsBossFloor", isBossFloor)
    folder:SetAttribute("BossDefeated", not isBossFloor)
    folder:SetAttribute("FloorCleared", false)
    folder:SetAttribute("Paths", "") -- (path choice: rolled again when this floor is cleared)
    -- WANDERING MERCHANT (path reward): this floor's stock, priced at the player's level
    run.Merchant = nil
    folder:SetAttribute("Merchant", "")
    if FloorMods.Has(mods, "MERCHANT") then
        run.Merchant = {}
        for _, def in ipairs(DungeonEvents.MERCHANT_STOCK) do
            table.insert(run.Merchant, { Price = DungeonEvents.MerchantPrice(config.PlayerLevel or 1, def.Mult), Sold = false })
        end
        folder:SetAttribute("Merchant", HttpService:JSONEncode(run.Merchant))
    end
    run.Paths = nil
    local counted = 0 -- loot goblins don't count toward clearing the floor (they can escape)
    for _, e in ipairs(roster) do if e.Kind ~= "LootGoblin" and (not config.Linked or e.Counted) then counted += 1 end end -- (LINKED ROOMS: the exit room's)
    folder:SetAttribute("TotalEnemies", counted)
    folder:SetAttribute("RemainingEnemies", counted)
    -- Marks when this floor actually started (the "clear a floor fast" title uses it).
    folder:SetAttribute("FloorStartClock", os.clock())
    folder:SetAttribute("RaidActive", true)
    folder:SetAttribute("RunToken", (folder:GetAttribute("RunToken") or 0) + 1)
    if config.Linked then DungeonRuns.LinkedStart(run, roster) else -- (LINKED ROOMS pilot: rooms spawn as you near them)
        SpawnRoster(run, roster) -- (PACKS PILOT: packs past the first few wait in a queue; otherwise everything, as before)
    end
    -- FLOOR OBJECTIVE (FloorObjectives): optional, one per floor at most; config.ForceObjective (dev) picks one
    run.Objective = nil
    folder:SetAttribute("Objective", "")
    folder:SetAttribute("ObjState", "")
    folder:SetAttribute("ObjProgress", 0)
    folder:SetAttribute("ObjNeed", 0)
    folder:SetAttribute("ObjDeadline", 0)
    if not run.BossTrial and not run.Rift and not run.Daily and not run.AscTrial and not config.Linked then -- (LINKED ROOMS: no objectives)
        local o = (config.ForceObjective and FloorObjectives.Make(config.ForceObjective, counted))
            or (not config.ForceObjective and FloorObjectives.Roll(config.FloorNumber, isBossFloor, counted)) or nil
        if o and o.Id == "BOUNTY" and not MarkBounty(run) then o = nil end
        -- (the BOUNTY objective already marks a bot with the skull: no contract on that floor)
        if not (o and o.Id == "BOUNTY") and not isBossFloor and (config.FloorNumber or 1) >= 2 then
            local dev = game:GetService("RunService"):IsStudio() and workspace:GetAttribute("DevContract") == true
            pcall(DungeonRuns.SpawnContract, run, dev)
        end
        if o then
            run.Objective = { Id = o.Id, Need = o.Need, Progress = 0, State = "", Deadline = 0 }
            DungeonRuns.ObjectiveStart(player, run)
            folder:SetAttribute("Objective", o.Id)
            folder:SetAttribute("ObjNeed", o.Need)
            if o.Time > 0 then ObjectiveTimer(player, run, o.Time) end
        end
    end
    -- BACK PORTAL: this floor as it starts (the return trip from the floor before restores it exactly)
    folder:SetAttribute("CanBack", run.PrevSnap ~= nil and not run.BossTrial and not run.AscTrial and not config.Linked) -- (LINKED ROOMS: no back portal)
    folder:SetAttribute("BackOpen", false) -- (0.61: the cleared floor's BACK portal, set by MarkFloorCleared)
    folder:SetAttribute("ReturnCleared", false)
    run.CurSnap = { Config = config, Roster = roster, Attrs = folder:GetAttributes(), EventId = eventId,
        Merchant = run.Merchant and table.clone(run.Merchant), ObjectiveId = run.Objective and run.Objective.Id,
        ObjNeed = run.Objective and run.Objective.Need }
    if config.Linked then run.CurSnap = nil end -- (LINKED ROOMS pilot: no BACK portal to or from a linked floor)
    return DungeonRuns.FloorInfo(run)
end

-- What the client needs to build the floor the run folder describes now.
function DungeonRuns.FloorInfo(run: Run): any
    local f = run.Folder
    return {
        Biome = f:GetAttribute("Biome"), Difficulty = f:GetAttribute("Difficulty"), Endless = f:GetAttribute("Endless") == true,
        FloorNumber = f:GetAttribute("Floor"), PlayerLevel = f:GetAttribute("PlayerLevel"), Seed = f:GetAttribute("Seed"),
        RunToken = f:GetAttribute("RunToken"), BotSkill = f:GetAttribute("BotSkill") or 4, Mods = f:GetAttribute("Mods") or "",
        BossSkill = f:GetAttribute("BossSkill"), -- (BOT MOVEMENT POE: a map guardian's pace)
        ModScale = f:GetAttribute("ModScale"), -- (MAPS V2: the client-built floor scales the mods like the server)
        Event = f:GetAttribute("Event") or "",
        BossArena = f:GetAttribute("BossArena") == true, -- (the client builds the same arena: Boss Trials / the schedule)
        Layout = f:GetAttribute("MapLayout"), -- (0.62 MAPS v3)
        Revisit = f:GetAttribute("Revisit") or 0,
        WeeklyMod = f:GetAttribute("WeeklyMod") or "", -- (UPDATE 7: the weekly boss's modifier, for the client-built boss)
        Linked = f:GetAttribute("Linked") == true, -- (LINKED ROOMS pilot)
    }
end

-- ==================== BACK PORTAL (owner 2026-10-05: "portal back to previous floor (loot stays)") ====================
-- "Back": from the entry room of floor N (before you've stepped out or anything has died) to floor N-1 as you left it --
-- cleared, its chest open, your unclaimed drops still lying where they fell. "Return": from there back to floor N,
-- exactly as it started (same map, enemies, modifiers, event, objective). Only the floor right behind you.
function DungeonRuns.CanGoBack(player: Player): (boolean, string?)
    local run = runs[player]
    if not run or run.Revisit or not run.PrevSnap or not run.CurSnap then return false, "No floor behind you." end
    if run.BossTrial or run.AscTrial then return false, "Not in a trial." end
    local f = run.Folder
    -- (0.61, owner: "There needs to be a way to portal back in case of missed loot"): a CLEARED floor opens the way back
    -- again (a BACK portal by its chest), and Return brings you to this floor still cleared (DungeonRuns.Revisit)
    if f:GetAttribute("FloorCleared") == true then
        if f:GetAttribute("TrialDone") == true then return false, "Not in a trial." end
        return true
    end
    if player:GetAttribute("SafeLocked") == true then return false, "The way back closed when you entered the floor." end
    if (f:GetAttribute("RemainingEnemies") or 0) ~= (f:GetAttribute("TotalEnemies") or 0) then return false, "The way back closed when the fight began." end
    return true
end
function DungeonRuns.Revisit(player: Player, dir: string): any
    local run = runs[player]
    if not run then return nil end
    local f = run.Folder
    if dir == "Back" then
        if not DungeonRuns.CanGoBack(player) then return nil end
        local prev = run.PrevSnap
        -- (0.61) leaving a CLEARED floor: remember it as it is (chest, exit portals, merchant, event) for the way back
        if f:GetAttribute("FloorCleared") == true then
            run.CurSnap.Cleared = { Attrs = f:GetAttributes(), Paths = run.Paths, Vault = run.VaultOpened, Chests = table.clone(run.ChestsOpened or {}),
                Event = run.Event, Merchant = run.Merchant }
        else
            run.CurSnap.Cleared = nil
        end
        ClearEnemies(run)
        run.Revisit = true
        f:SetAttribute("ReturnCleared", false)
        -- (Revisit first: the client's FloorCleared watcher must already know this is a revisit, not a fresh clear)
        f:SetAttribute("Revisit", run.CurSnap.Config.FloorNumber)
        for k, v in pairs(prev.LeaveAttrs or prev.Attrs) do
            if k ~= "Revisit" and k ~= "RunToken" and k ~= "RaidActive" then f:SetAttribute(k, v) end
        end
        f:SetAttribute("RemainingEnemies", 0)
        f:SetAttribute("CanBack", false) -- (one floor back at most)
        f:SetAttribute("Paths", "")
        f:SetAttribute("Event", ""); f:SetAttribute("EventState", "")
        f:SetAttribute("Encounter", ""); f:SetAttribute("EncounterState", "") -- (UPDATE 7: an encounter doesn't come back on a revisit)
        run.Encounter = nil
        f:SetAttribute("Merchant", "")
        f:SetAttribute("Objective", ""); f:SetAttribute("ObjState", ""); f:SetAttribute("ObjDeadline", 0)
        f:SetAttribute("FloorCleared", true)
        run.Config = prev.Config
        run.VaultOpened, run.ChestsOpened = true, { true, true, true, true }
        run.Event, run.Merchant, run.Objective, run.Paths = nil, nil, nil, nil
        f:SetAttribute("RunToken", (f:GetAttribute("RunToken") or 0) + 1)
        return DungeonRuns.FloorInfo(run)
    elseif dir == "Return" then
        if not run.Revisit then return nil end
        local cur = run.CurSnap
        ClearEnemies(run)
        run.Revisit = nil
        f:SetAttribute("Revisit", 0)
        if cur.Cleared then
            -- (0.61) back to a floor you had already cleared: as you left it, no enemies, its portals and chest as they were
            local c = cur.Cleared
            for k, v in pairs(c.Attrs) do
                if k ~= "Revisit" and k ~= "RunToken" and k ~= "RaidActive" then f:SetAttribute(k, v) end
            end
            run.Config = cur.Config
            run.Paths, run.VaultOpened, run.ChestsOpened = c.Paths, c.Vault == true, c.Chests or {}
            run.Event, run.Merchant, run.Objective = c.Event, c.Merchant, nil
            run.AmbushLeft, run.TrialUntil, run.TrialKills = 0, 0, 0
            run.Recent, run.HitTimes, run.OutsideTicks = {}, {}, 0
            f:SetAttribute("RemainingEnemies", 0)
            f:SetAttribute("VaultWasOpened", c.Vault == true)
            f:SetAttribute("ReturnCleared", true)
            f:SetAttribute("RunToken", (f:GetAttribute("RunToken") or 0) + 1)
            return DungeonRuns.FloorInfo(run)
        end
        f:SetAttribute("ReturnCleared", false)
        for k, v in pairs(cur.Attrs) do
            if k ~= "Revisit" and k ~= "RunToken" and k ~= "RaidActive" then f:SetAttribute(k, v) end
        end
        f:SetAttribute("Encounter", ""); f:SetAttribute("EncounterState", ""); run.Encounter = nil -- (UPDATE 7: not on a return)
        run.Config = cur.Config
        run.VaultOpened, run.ChestsOpened = false, {}
        run.Event = cur.EventId and { Id = cur.EventId, Uses = 0, Done = false } or nil
        run.Merchant = cur.Merchant and table.clone(cur.Merchant) or nil
        run.AmbushLeft, run.TrialUntil, run.TrialKills = 0, 0, 0
        run.Recent, run.HitTimes, run.OutsideTicks = {}, {}, 0
        SpawnRoster(run, cur.Roster)
        if CombatServer and CombatServer.Zen then pcall(CombatServer.Zen.ThreadClear, player, CombatServer.GetState(player)) end -- (ZENITH: a revisited floor too)
        f:SetAttribute("FloorStartClock", os.clock())
        f:SetAttribute("RunToken", (f:GetAttribute("RunToken") or 0) + 1)
        run.Objective = nil
        if cur.ObjectiveId then
            local def = FloorObjectives.Make(cur.ObjectiveId, f:GetAttribute("TotalEnemies") or 0)
            if def and (def.Id ~= "BOUNTY" or MarkBounty(run)) then
                run.Objective = { Id = def.Id, Need = cur.ObjNeed or def.Need, Progress = 0, State = "", Deadline = 0 }
                DungeonRuns.ObjectiveStart(player, run)
                if (def.Time or 0) > 0 then ObjectiveTimer(player, run, def.Time) end
            else
                f:SetAttribute("Objective", "")
            end
        end
        return DungeonRuns.FloorInfo(run)
    end
    return nil
end

-- Leaving the dungeon (exit, death, disconnect): drop every stand-in and mark the run inactive.
function DungeonRuns.EndRun(player: Player)
    local run = runs[player]
    if not run then return end
    ClearEnemies(run)
    run.Folder:SetAttribute("RaidActive", false)
    run.Folder:SetAttribute("RemainingEnemies", 0)
    runs[player] = nil
    if CombatServer then CombatServer.MissGroundLoot(player) end
    run.Folder:SetAttribute("Mods", "")
    run.Folder:SetAttribute("ModReward", 0)
    if CombatServer then
        CombatServer.ResetRunBoons(player)
        CombatServer.GetState(player).FloorLuckMult = 1
        if CombatServer.Zen then pcall(CombatServer.Zen.ThreadClear, player, CombatServer.GetState(player)) end -- (ZENITH: no thread carried out of a run)
        CombatServer.ResolveRunLoot(player, CombatServer.GetState(player).RunKeep == true) -- won / extracted keeps it
        CombatServer.ClearRunLives(player)
    end
end

-- ===== floor objective progress (FloorObjectives) =====
local function ObjectiveFor(player: Player, id: string): any?
    local run = runs[player]
    local o = run and run.Objective
    if o and o.Id == id and o.State == "" then return o end
    return nil
end
function DungeonRuns.CompleteObjective(player: Player)
    local run = runs[player]
    local o = run and run.Objective
    if not o or o.State ~= "" then return end
    if o.Deadline > 0 and os.clock() > o.Deadline + 0.25 then DungeonRuns.FailObjective(player) return end
    o.State = "DONE"
    run.Folder:SetAttribute("ObjState", "DONE")
    if CombatServer and CombatServer.ObjectiveReward then CombatServer.ObjectiveReward(player, o.Id) end
end
function DungeonRuns.FailObjective(player: Player)
    local run = runs[player]
    local o = run and run.Objective
    if not o or o.State ~= "" then return end
    o.State = "FAILED"
    run.Folder:SetAttribute("ObjState", "FAILED")
    if o.Id == "BOUNTY" then -- (the mark comes off: the target is just another enemy now)
        for _, p in ipairs(run.Enemies:GetChildren()) do if p:GetAttribute("Bounty") then p:SetAttribute("Bounty", nil) end end
    end
end
local function Progress(player: Player, o: any, value: number)
    o.Progress = value
    runs[player].Folder:SetAttribute("ObjProgress", value)
    if value >= o.Need then DungeonRuns.CompleteObjective(player) end
end
-- (2026-10-06) SHARPSHOOTER counts from the run's shot record at the floor's start; CHAIN keeps recent kill times
function DungeonRuns.ObjectiveStart(player: Player, run: any)
    local o = run.Objective
    if not o then return end
    if o.Id == "SHARPSHOOTER" then
        local rec = CombatServer and CombatServer.RS and CombatServer.RS.Get(player)
        o.Shots0, o.Hits0 = rec and rec.Shots or 0, rec and rec.Hits or 0
    elseif o.Id == "CHAIN" then
        o.Kills = {}
    end
end
-- live accuracy for the HUD line (CombatServer calls it after each counted trigger pull)
function DungeonRuns.OnShot(player: Player)
    local o = ObjectiveFor(player, "SHARPSHOOTER")
    local rec = o and CombatServer and CombatServer.RS and CombatServer.RS.Get(player)
    if not rec then return end
    local shots = (rec.Shots or 0) - (o.Shots0 or 0)
    local acc = shots > 0 and math.floor(((rec.Hits or 0) - (o.Hits0 or 0)) / shots * 100 + 0.5) or 0
    if acc ~= o.Progress then o.Progress = acc; runs[player].Folder:SetAttribute("ObjProgress", acc) end
end
-- CombatServer hooks: a hit on you, your Focus streak, a weak-spot kill (OnWeakKill), a kill (OnProxyKilled)
function DungeonRuns.OnPlayerHit(player: Player)
    if ObjectiveFor(player, "UNTOUCHED") then DungeonRuns.FailObjective(player) end
end
function DungeonRuns.OnStreak(player: Player, streak: number)
    local o = ObjectiveFor(player, "FOCUS")
    if o and streak > o.Progress then Progress(player, o, streak) end
end

-- Called by CombatServer's kill pipeline. Keeps the enemy's damage on record for a moment so bolts already
-- in the air (and Volatile death blasts) can still land.
function DungeonRuns.OnProxyKilled(proxy: Instance)
    local p = DungeonRuns.OwnerOf(proxy)
    local run = p and runs[p]
    local id = proxy:GetAttribute("EnemyId")
    if run and proxy:GetAttribute("DroneType") == "Splitter" and proxy:GetAttribute("Dead") then
        local at = run.Pos[proxy] or proxy:GetAttribute("SpawnPos")
        if at then
            for _, side in ipairs({ -1, 1 }) do
                local sp = SpawnProxy(run, { Kind = "Bot", Archetype = "Splitling", Pos = at + Vector3.new(side * 4, 1, 0), IsSummon = true,
                    LinkRoom = proxy:GetAttribute("LinkRoom"), LinkPack = proxy:GetAttribute("LinkPack"), Counted = not proxy:GetAttribute("Uncounted") }) -- (LINKED ROOMS)
                sp:SetAttribute("XpReward", math.round((sp:GetAttribute("XpReward") or 0) * 0.4))
                if proxy:GetAttribute("LinkPack") then sp:SetAttribute("Awake", true) end
            end
            if not proxy:GetAttribute("Uncounted") then
                run.Folder:SetAttribute("TotalEnemies", (run.Folder:GetAttribute("TotalEnemies") or 0) + 2)
                run.Folder:SetAttribute("RemainingEnemies", (run.Folder:GetAttribute("RemainingEnemies") or 0) + 2)
            end
        end
    end
    local em = proxy:GetAttribute("EliteMods") -- (COMMANDER: its pack loses the buff the moment it dies)
    if run and DungeonGenerator.HasEliteMod(em, "Commander") then
        DungeonGenerator.CommanderTick(run.Enemies:GetChildren(), DungeonRuns.PosOf)
    end
    if run and proxy:GetAttribute("Bounty") and proxy:GetAttribute("Dead") and ObjectiveFor(p, "BOUNTY") then
        DungeonRuns.CompleteObjective(p)
    end
    local co = run and proxy:GetAttribute("Dead") and ObjectiveFor(p, "CHAIN")
    if co then -- CHAIN REACTION: kills within CHAIN_WINDOW of the previous one extend the chain
        local now = os.clock()
        local last = co.Kills[#co.Kills]
        if last and now - last > FloorObjectives.CHAIN_WINDOW then co.Kills = {} end
        table.insert(co.Kills, now)
        if #co.Kills > co.Progress then Progress(p, co, #co.Kills) end
    end
    if run and proxy:GetAttribute("Ambush") then
        run.AmbushLeft = math.max(0, (run.AmbushLeft or 0) - 1)
        if run.AmbushLeft == 0 and CombatServer then CombatServer.EventAmbushReward(p) end
    end
    if run and id then
        if proxy:GetAttribute("Dead") then pcall(DungeonRuns.BV().NoteCorpse, run, proxy, run.Pos[proxy]) end -- (ENEMY VARIETY: a raiser's corpse)
        run.Recent[id] = { AttackDamage = proxy:GetAttribute("AttackDamage") or 0, Until = os.clock() + 4, Commanded = proxy:GetAttribute("Commanded") == true }
        run.Pos[proxy] = nil
        run.ShieldUntil[proxy] = nil
    end
    if run and (run :: any).PackQueue and proxy:GetAttribute("Dead") then
        task.delay(0.2, function() if runs[p] == run then ReleasePacks(run) end end) -- (after the stand-in is gone)
    end
    -- (0.53: a killed stand-in stays 0.15 s so its Dead flag reaches the client first -- attribute changes on an
    -- instance destroyed the same frame never replicate, and the client then had no death to animate. Every enemy
    -- loop on the server already skips Dead ones.)
    if proxy:GetAttribute("Dead") then
        task.delay(0.15, function() if proxy.Parent then proxy:Destroy() end end)
    else
        proxy:Destroy()
    end
end

-- A weak-spot kill (CombatServer): counts toward a running Shrine of Precision trial.
function DungeonRuns.OnWeakKill(player: Player, proxy: Instance)
    local run = runs[player]
    local po = ObjectiveFor(player, "PRECISION")
    if po then Progress(player, po, po.Progress + 1) end
    if run and proxy:GetAttribute("Trial") and os.clock() <= (run.TrialUntil or 0) then
        run.TrialKills = (run.TrialKills or 0) + 1
        run.Folder:SetAttribute("TrialKills", run.TrialKills)
    end
end

-- Floor clear (all foes dead, boss confirmed): the client builds the victory chest + portal from this flag.
function DungeonRuns.MarkFloorCleared(player: Player)
    local run = runs[player]
    if not run then return end
    if (run :: any).Linked then DungeonRuns.LinkedClearExit(run); DungeonRuns.LinkedFloorCredit(player, run) else -- (LINKED ROOMS pilot: the skipped rooms keep their packs; v2: jobs count it twice)
        ClearEnemies(run) -- dismiss leftover summoned adds
    end
    if run.BossTrial then run.Folder:SetAttribute("TrialDone", true) end -- (before FloorCleared: the client builds the hub portal)
    local ascDone = run.AscTrial ~= nil and (run.Config.FloorNumber or 1) >= AscensionTrials.FLOORS
    if ascDone then run.Folder:SetAttribute("TrialDone", true) end -- (the Trial of Ascension's last floor: the hub portal)
    -- (2026-10-22 autoplay map run) a MAP / the Daily / the Gauntlet Run ends on its own last floor, but the client's portal rule
    -- reads the difficulty's run length (6 floors since RUN LENGTHS v4): after a map's guardian on floor 5 it built a NEXT FLOOR
    -- portal into a plain floor 6 of that difficulty. Their last floor gets the gold hub portal like a trial's.
    do
        local fl = run.Config.FloorNumber or 1
        if (run.Rift and fl >= Rifts.FLOORS) or (run.Daily and fl >= DailyChallenge.FLOORS) or (run.Line and fl >= DailyLine.FLOORS) then
            run.Folder:SetAttribute("TrialDone", true)
        end
    end
    -- PATH CHOICE: the next floor's options (set before FloorCleared -- the client builds the portals from it). Not
    -- before boss floors, after the run's last floor, or in a Rift / the Daily (their floors are fixed).
    do
        local cfg0 = run.Config
        local nextFloor = (cfg0.FloorNumber or 1) + (cfg0.Linked and LinkedRooms.FLOOR_STEP or 1) -- (LINKED ROOMS v2: counts as 2)
        local mode = ItemData.RunMode(cfg0.Difficulty, cfg0.Endless)
        local last = not mode.Endless and mode.MaxWaves ~= nil and cfg0.FloorNumber >= mode.MaxWaves
        if not run.BossTrial and not run.Rift and not run.Daily and not run.Line and not run.AscTrial and not last and not ItemData.IsBossFloor(cfg0.Difficulty, cfg0.Endless, nextFloor) then
            run.Paths = FloorMods.RollPaths(nextFloor)
            run.Folder:SetAttribute("Paths", HttpService:JSONEncode(run.Paths))
        else
            run.Paths = nil
            run.Folder:SetAttribute("Paths", "")
        end
    end
    -- (0.66 MAPS) Chart Shards a map floor: MAPS V2 L3 moved them into the floor's MAP CACHE (EndgameServer.MapFloorCache, the Vault chest)
    -- (0.61) the BACK portal by the chest: only with a floor behind you, never in a trial
    run.Folder:SetAttribute("BackOpen", run.PrevSnap ~= nil and not run.Revisit and not run.BossTrial and not ascDone and not run.AscTrial and not (run :: any).Linked)
    run.Folder:SetAttribute("FloorCleared", true)
    if run.BossTrial then
        -- a Boss Trial ends with the boss: pay out, post the time, then home
        local trial = run.BossTrial
        run.BossTrial = nil
        run.Folder:SetAttribute("BossTrial", "")
        require(script.Parent:WaitForChild("EndgameServer")).BossTrialFinished(player, trial, os.clock() - (trial.StartClock or os.clock()))
        return
    end
    if ascDone then
        local trial = run.AscTrial
        run.AscTrial = nil
        run.Folder:SetAttribute("AscTrial", 0)
        require(script.Parent:WaitForChild("EndgameServer")).AscTrialFinished(player, trial, os.clock() - (trial.StartClock or os.clock()))
        return
    end
    -- boss floors pay a boon (Boon Shrines are the other source) -- but not the boss that FINISHES the run (owner
    -- 2026-10-03: "room 5 of easy shouldnt give you a boon"): the last floor of the difficulty, a Rift or the Daily
    local cfg = run.Config
    local modeDef = ItemData.RunMode(cfg.Difficulty, cfg.Endless)
    local finalFloor = (not modeDef.Endless and modeDef.MaxWaves ~= nil and cfg.FloorNumber >= modeDef.MaxWaves)
        or (run.Rift ~= nil and cfg.FloorNumber >= Rifts.FLOORS) or (run.Daily == true and cfg.FloorNumber >= DailyChallenge.FLOORS)
        or (run.Line == true and cfg.FloorNumber >= DailyLine.FLOORS)
    if CombatServer and run.Folder:GetAttribute("IsBossFloor") == true and not finalFloor then
        CombatServer.OfferBoons(player, true) -- (UPDATE 8 Phase 5: boons are cut -- OfferBoons does nothing now)
    end
    -- floor objective: the clear finishes Untouchable / Blitz; anything else still open has failed
    if run.Objective and run.Objective.State == "" then
        if run.Objective.Id == "SHARPSHOOTER" then DungeonRuns.OnShot(player) end -- (final accuracy)
        if run.Objective.Id == "UNTOUCHED" or run.Objective.Id == "BLITZ"
            or (run.Objective.Id == "SHARPSHOOTER" and run.Objective.Progress >= run.Objective.Need) then DungeonRuns.CompleteObjective(player)
        else DungeonRuns.FailObjective(player) end
    end
    -- path rewards for the floor just cleared (Armory / War Vault / Supply Cache)
    if CombatServer and CombatServer.PathClearReward then CombatServer.PathClearReward(player, cfg.Mods or {}) end
    if run.Rift and run.Config.FloorNumber >= Rifts.FLOORS then
        local rift = run.Rift
        run.Rift = nil
        run.Folder:SetAttribute("Rift", 0)
        run.Folder:SetAttribute("RiftStart", 0)
        local elapsed = os.clock() - (rift.StartClock or os.clock())
        require(script.Parent:WaitForChild("EndgameServer")).RiftFinished(player, rift, elapsed)
    end
    if run.Line and run.Config.FloorNumber >= DailyLine.FLOORS then -- (UPDATE 7 B6)
        run.Line = false
        run.Folder:SetAttribute("Line", false)
        require(script.Parent:WaitForChild("EndgameServer")).LineFinished(player, os.clock() - (run.LineStart or os.clock()))
    end
    if run.Daily and run.Config.FloorNumber >= DailyChallenge.FLOORS then
        run.Daily = false
        run.Folder:SetAttribute("Daily", false)
        run.Folder:SetAttribute("DailyStart", 0)
        require(script.Parent:WaitForChild("EndgameServer")).DailyFinished(player, os.clock() - (run.DailyStart or os.clock()))
    end
end

-- The path the player walked into (its modifier list), or nil (no choice offered / bad index).
function DungeonRuns.TakePath(player: Player, index: any): { string }?
    local run = runs[player]
    if not run or type(run.Paths) ~= "table" or type(index) ~= "number" then return nil end
    local p = run.Paths[math.floor(index)]
    if not p then return nil end
    run.Paths = nil
    return FloorMods.Parse(p.Mods)
end

-- ==================== client reports ====================
local function FindProxy(run: Run, id: any): Instance?
    if type(id) ~= "number" then return nil end
    return run.Enemies:FindFirstChild("E" .. id)
end

local IS_STUDIO_PROBE = game:GetService("RunService"):IsStudio()
local function AllowHit(run: Run, id: number, perSecond: number): boolean
    local now = os.clock()
    local list = run.HitTimes[id]
    if not list then list = {}; run.HitTimes[id] = list end
    while list[1] and now - list[1] > 1 do table.remove(list, 1) end
    if #list >= perSecond then return false end
    table.insert(list, now)
    return true
end

function DungeonRuns.Init(combat: any)
    CombatServer = combat

    -- An enemy's attack landed on the player (their client simulates the attack).
    Remotes.GetEvent("EnemyHitPlayer").OnServerEvent:Connect(function(player: Player, id: any, dmg: any, elementKey: any, chance: any, evadable: any, src: any, bScale: any, bFollow: any, probeTag: any)
        local run = runs[player]
        if not run or type(dmg) ~= "number" or dmg ~= dmg then return end
        local proxy = FindProxy(run, id)
        local attack = proxy and proxy:GetAttribute("AttackDamage")
        if not attack then
            local rec = run.Recent[id]
            if rec and os.clock() < rec.Until then attack = rec.AttackDamage end
        end
        if not attack or attack <= 0 then return end
        if not AllowHit(run, id, 8) then return end
        dmg = math.clamp(dmg, 0, attack * 2.2 + 1) -- the biggest single hit any enemy deals is 2x its attack
        -- (UPDATE 8 COMMANDER elites; review 2: a dead stand-in's hits -- the POE death burst -- use its Commanded state at death, as party does)
        local rec0 = (not proxy) and run.Recent[id] or nil
        if (proxy and proxy:GetAttribute("Commanded")) or (rec0 and rec0.Commanded) then dmg *= DungeonGenerator.COMMAND_DMG end
        if dmg <= 0 then return end
        if not DungeonGenerator.IsHitKey(elementKey) then elementKey = nil end -- (UPDATE 8: an element key or a damage type)
        if type(chance) ~= "number" or chance ~= chance then chance = 0.35 end
        -- (UPDATE 8 DEFENCE) Agility dodges a strike the client's HitPlayer marked evadable; (AGILITY vs BOSSES 2026-10-24) a boss
        -- strike is marked only for BossAI's PLAIN allow-list moves. The stand-in says whether it's a boss (BOSS_EVADE, no Ghost).
        -- (a client that lied about the flag could equally not report the hit at all: no new trust)
        local isBoss = proxy and proxy:GetAttribute("IsBoss") and true or false
        evadable = evadable == true
        -- (QOL2 R1 DEATH RECAP) the client names the attacker (a boss's move lives on its local model); only shown back to this
        -- player, still clipped to letters / digits / a few marks; else the stand-in's own name
        if type(src) == "string" and #src <= 64 then src = string.sub(string.gsub(src, "[^%w%s%-%:',%.]", ""), 1, 40) else src = nil end
        if not src or src == "" then src = proxy and DungeonGenerator.SourceName(proxy) or nil end
        -- (ENEMY ATTACKS PILOT, review B) a burst's round: bScale = the burst's total / this round (Plating's hit size, 1-3), bFollow =
        -- not the burst's first landed round (no ailment roll, no Vampiric heal). Both only make the client's own hit milder or equal.
        if type(bScale) ~= "number" or bScale ~= bScale then bScale = nil else bScale = math.clamp(bScale, 1, 3) end
        bFollow = bFollow == true
        if bFollow then chance = 0 end
        if IS_STUDIO_PROBE then -- (POE DAMAGE MODEL probe: Studio only; the tag is the client's word and feeds nothing but the probe)
            pcall(function() -- (everything inside the pcall: the probe can never break a real hit)
                DungeonGenerator.ProbeHit("DevHitLogSrv", dmg, elementKey, evadable, bScale, type(probeTag) == "string" and probeTag or nil, DungeonGenerator.OrdinaryHit(run.Config))
            end)
        end
        DungeonGenerator.ApplyHitToPlayer(player, dmg, elementKey, math.clamp(chance, 0, 1), nil, evadable, isBoss, src, bScale)
        if proxy and not bFollow then DungeonGenerator.EliteOnHit(proxy) end -- (UPDATE 8 Phase 5 ELITE MODS: Vampiric heals on a landed hit; once a burst)
    end)

    -- Enemy positions for area effects (explosions, chain arcs) and hit checks, ~6/s, keyed by tostring(id).
    Remotes.GetEvent("EnemyPositions").OnServerEvent:Connect(function(player: Player, list: any)
        local run = runs[player]
        if not run or type(list) ~= "table" then return end
        local n = 0
        for id, pos in pairs(list) do
            n += 1
            if n > 300 then break end
            if typeof(pos) == "Vector3" and pos == pos then
                local proxy = FindProxy(run, tonumber(id))
                if proxy then run.Pos[proxy] = pos end
            end
        end
    end)

    -- Shield phases (Shielded elites, the Sentinel).
    Remotes.GetEvent("EnemyFlag").OnServerEvent:Connect(function(player: Player, id: any, key: any, value: any)
        local run = runs[player]
        if not run or key ~= "DamageTakenMult" then return end
        local proxy = FindProxy(run, id)
        if not proxy then return end
        -- boss SHIELD ORBS (BossAI): 0 = shield up (only makes your own fight harder), 1.75 = staggered -- only accepted
        -- right after this boss's orbs were being shot (CombatServer stamps LastOrbHit)
        -- BOSS SIGNATURES (BossAI SIG) run on this player's client for a solo boss: armour / light-well values (<= 1) are
        -- taken as sent; DAMAGE WINDOWS (> 1: posture break, overload, dazed, grounded, venting) at most 8 s at a time with
        -- 5 s between, and they lapse on their own (a client can't hold a boss open)
        -- (0.2 = a SUPERBOSS v3 encounter's immune state; inside an open window the value may change -- the Void's light
        -- well is x2 while you stand in it, x1 outside)
        local ALLOWED = { [0] = true, [0.1] = true, [0.15] = true, [0.2] = true, [0.25] = true, [0.3] = true, [0.5] = true, [0.6] = true, [1.5] = true, [1.75] = true, [2] = true }
        if proxy:GetAttribute("IsBoss") and type(value) == "number" and ALLOWED[value] then
            local now = os.clock()
            local open = run.BoostEnd and run.BoostEnd[proxy] and now < run.BoostEnd[proxy]
            if value > 1 and open then
                proxy:SetAttribute("DamageTakenMult", value)
                return
            elseif value > 1 then
                if now - (run.BoostEnd and run.BoostEnd[proxy] or -99) < 5 then return end
                run.BoostEnd = run.BoostEnd or {}
                run.BoostEnd[proxy] = now + 8
                task.delay(8, function()
                    if proxy.Parent and (proxy:GetAttribute("DamageTakenMult") or 1) > 1 then proxy:SetAttribute("DamageTakenMult", nil) end
                end)
            end
            proxy:SetAttribute("DamageTakenMult", value)
            run.ShieldUntil[proxy] = nil
            return
        end
        local isSentinel = proxy:GetAttribute("ModelName") == "SentinelMiniBoss"
        local mods = proxy:GetAttribute("EliteMods") or ""
        local shielded = DungeonGenerator.HasEliteMod(mods, "Shielded") or DungeonGenerator.HasEliteMod(mods, "Warded") -- (UPDATE 8: Warded)
        -- bosses (solo bosses run on this player's client): phase roars (0.15), the Chronarch's beat (0.3 armored /
        -- 3 core open) -- only those values, and x3 only for the Chronarch (2026-10-03: these were all ignored before)
        if proxy:GetAttribute("IsBoss") and not isSentinel then
            local chrono = proxy:GetAttribute("ModelName") == "TrialChronarch"
            if value == nil or value == 1 or value == 0.15 or value == 0.3 or (chrono and value == 3) then
                proxy:SetAttribute("DamageTakenMult", (value ~= 1) and value or nil)
            end
            return
        end
        if not isSentinel and not shielded then
            -- (ENEMY ATTACKS PILOT) a CASTER's ward on an ally (BotRoles: Warden / Smelter): half damage, only while a ward caster of this
            -- run is alive, at most 5 s at a time (it only makes your own fight harder; a lying client could equally skip it)
            if value == 0.5 or value == nil or value == 1 then
                local BR = require(game.ReplicatedStorage.AimRngShared.BotRoles)
                local caster = false
                for _, m in ipairs(run.Enemies:GetChildren()) do
                    local row = BR.ROWS[m:GetAttribute("Archetype") or ""]
                    if row and row.Attack == "Ward" and not m:GetAttribute("Dead") then caster = true break end
                end
                if value == 0.5 and caster and not proxy:GetAttribute("IsBoss") then
                    proxy:SetAttribute("DamageTakenMult", 0.5)
                    run.ShieldUntil[proxy] = os.clock() + 5
                elseif value ~= 0.5 and run.ShieldUntil[proxy] then
                    proxy:SetAttribute("DamageTakenMult", nil)
                    run.ShieldUntil[proxy] = nil
                end
            end
            return
        end
        if value == nil or value == 1 then
            proxy:SetAttribute("DamageTakenMult", isSentinel and 1 or nil)
            run.ShieldUntil[proxy] = nil
        elseif value == 0.2 or value == 0.25 or (shielded and value == 0.5) then -- (2026-10-22: an elite shield blocks 50% now)
            proxy:SetAttribute("DamageTakenMult", value)
            run.ShieldUntil[proxy] = os.clock() + (isSentinel and 8 or 3) -- can't be held up forever
        end
    end)

    -- Boss summons (the Titan's escort drones).
    Remotes.GetEvent("EnemySummon").OnServerEvent:Connect(function(player: Player, id: any, archetype: any, positions: any)
        local run = runs[player]
        if not run or type(positions) ~= "table" then return end
        local boss = FindProxy(run, id)
        if not boss or boss:GetAttribute("ModelName") ~= "ApexTitanMech" or boss:GetAttribute("Dead") then return end
        local now = os.clock()
        if now - run.LastSummon < 2 then return end
        -- at most 2 escorts alive at once (owner: the Titan spawned far too many); more only after you kill them
        local adds = 0
        for _, m in ipairs(run.Enemies:GetChildren()) do if m:GetAttribute("IsSummon") and not m:GetAttribute("Dead") then adds += 1 end end
        if adds >= 2 then return end
        run.LastSummon = now
        local made = 0
        for i = 1, math.min(2 - adds, #positions) do
            local pos = positions[i]
            if typeof(pos) == "Vector3" and pos == pos then
                SpawnProxy(run, { Kind = "Bot", Archetype = "Tracker", Pos = pos, IsSummon = true })
                made += 1
            end
        end
        -- these count as foes so the "remaining" number stays honest (the boss-defeated gate still decides the clear)
        run.Folder:SetAttribute("TotalEnemies", (run.Folder:GetAttribute("TotalEnemies") or 1) + made)
        run.Folder:SetAttribute("RemainingEnemies", (run.Folder:GetAttribute("RemainingEnemies") or 1) + made)
    end)

    -- Chests: the victory chest after the clear (once). (Supply caches are gone: see below.)
    Remotes.GetEvent("OpenChest").OnServerEvent:Connect(function(player: Player, kind: any, chestId: any)
        local run = runs[player]
        if not run then return end
        if kind == "Supply" then
            -- (launch sweep 2026-10-13) the corner supply caches were removed from the maps 2026-10-03, but this still paid
            -- out: a modified client could claim 4 caches on every floor. Nothing on a solo floor sends "Supply" now.
            return
        elseif kind == "Vault" then
            if run.VaultOpened or run.Folder:GetAttribute("FloorCleared") ~= true then return end
            run.VaultOpened = true
            local cfg = run.Config
            if run.Rift and (cfg.FloorNumber or 1) < Rifts.FLOORS then -- (MAPS V2 L3: a map floor's chest is the MAP CACHE)
                require(script.Parent:WaitForChild("EndgameServer")).MapFloorCache(player, run, cfg.Linked and LinkedRooms.FLOOR_STEP or 1)
                return
            end
            local modeDef = ItemData.RunMode(cfg.Difficulty, cfg.Endless)
            local isSuper = modeDef ~= nil and modeDef.SuperBossWave ~= nil and cfg.FloorNumber == modeDef.SuperBossWave
            CombatServer.GiveFloorLoot(player, isSuper or ItemData.IsBossConfig(cfg))
        elseif kind == "LinkCache" then -- (LINKED ROOMS pilot: the side room's cache)
            DungeonRuns.LinkedCache(player, run)
        end
    end)

    -- Dungeon events (DungeonEvents): the shrine's prompt on the client fires UseEvent.
    local function AddFoes(run: Run, n: number)
        run.Folder:SetAttribute("TotalEnemies", (run.Folder:GetAttribute("TotalEnemies") or 0) + n)
        run.Folder:SetAttribute("RemainingEnemies", (run.Folder:GetAttribute("RemainingEnemies") or 0) + n)
        if run.Folder:GetAttribute("FloorCleared") then
            -- the floor was already cleared: these are a bonus fight, the floor stays cleared
            run.Folder:SetAttribute("RemainingEnemies", n)
        end
    end
    Remotes.GetEvent("UseEvent").OnServerEvent:Connect(function(player: Player)
        local run = runs[player]
        local ev = run and run.Event
        if not ev or ev.Done or not CombatServer then return end
        local layout = DungeonGenerator.GetChamberLayout(ItemData.IsBossConfig(run.Config))
        local pos = DungeonEvents.Position(layout)
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root or (root.Position - pos).Magnitude > DungeonEvents.USE_RANGE then return end
        local id = ev.Id
        if id == "GAMBLE_ALTAR" then
            if CombatServer.EventGamble(player, ev.Uses) then
                ev.Uses += 1
                ev.Done = ev.Uses >= DungeonEvents.GAMBLE_USES
                run.Folder:SetAttribute("EventState", ev.Done and "USED" or ("USES:" .. ev.Uses))
            end
            return
        elseif id == "BOON_SHRINE" then
            if not CombatServer.OfferBoons(player, false) then return end
        elseif id == "FORTUNE_FOUNTAIN" then
            CombatServer.EventFortune(player)
        elseif id == "CURSED_CHEST" then
            for i = 1, 3 do
                local a = math.rad(i * 120)
                local proxy = SpawnProxy(run, {
                    Kind = "Bot", Archetype = DungeonGenerator.PickArchetype(math.max(3, run.Config.FloorNumber)), Elite = true,
                    Pos = pos + Vector3.new(math.cos(a) * 14, 12, math.sin(a) * 14 + 16),
                })
                proxy:SetAttribute("Ambush", true)
            end
            run.AmbushLeft = 3
            AddFoes(run, 3)
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "THE CHEST'S GUARDIANS AWAKEN! Defeat all 3.")
        elseif id == "TRIAL_SHRINE" then
            local n = DungeonEvents.TRIAL_TARGETS
            for i = 1, n do
                local a = math.rad(i * (360 / n))
                local proxy = SpawnProxy(run, {
                    Kind = "Bot", Archetype = DungeonGenerator.PickArchetype(run.Config.FloorNumber),
                    Pos = pos + Vector3.new(math.cos(a) * 24, 10 + (i % 3) * 3, math.sin(a) * 18 + 30),
                })
                proxy:SetAttribute("Trial", true)
            end
            AddFoes(run, n)
            run.TrialUntil = os.clock() + DungeonEvents.TRIAL_SECONDS
            run.TrialKills = 0
            run.Folder:SetAttribute("TrialUntil", workspace:GetServerTimeNow() + DungeonEvents.TRIAL_SECONDS)
            run.Folder:SetAttribute("TrialKills", 0)
            local token = run.Folder:GetAttribute("RunToken")
            task.delay(DungeonEvents.TRIAL_SECONDS, function()
                if runs[player] == run and run.Folder:GetAttribute("RunToken") == token then
                    run.Folder:SetAttribute("TrialUntil", 0)
                    CombatServer.EventTrialReward(player, run.TrialKills)
                end
            end)
        end
        ev.Done = true
        run.Folder:SetAttribute("EventState", "USED")
    end)

    -- RUN ENCOUNTER (UPDATE 7): "Start" = in range of the vault, not used -> the lock's numbers; "Finish"(ok, resets) =
    -- a plausible time since the start, still near -> the reward (CombatServer.EncounterReward). Once per floor.
    Remotes.GetFunction("EncounterAction").OnServerInvoke = function(player: Player, action: any, ok: any, resets: any): (boolean, any)
        local run = runs[player]
        local enc = run and run.Encounter
        if not enc or not CombatServer then return false, "No encounter here." end
        local def = Encounters.Defs[enc.Id]
        local layout = DungeonGenerator.GetChamberLayout(ItemData.IsBossConfig(run.Config))
        if (run :: any).Linked then layout = LinkedRooms.SideLayout((run :: any).Linked.L, layout) end -- (LINKED ROOMS v2: it stands in the side room)
        local pos = Encounters.Position(layout)
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local flat = root and Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z).Magnitude or math.huge
        if action == "Start" then
            if enc.State ~= "" then return false, "This vault is already used." end
            if flat > Encounters.USE_RANGE then return false, "Get closer to the vault." end
            local rank = ItemData.DifficultyRank and ItemData.DifficultyRank[run.Config.Difficulty] or 1
            enc.Params = Encounters.Params(enc.Id, rank, run.Config.BotSkill)
            enc.State = "PICKING"
            enc.StartedAt = os.clock()
            run.Folder:SetAttribute("EncounterState", "PICKING")
            return true, enc.Params
        elseif action == "Finish" then
            if enc.State ~= "PICKING" or not enc.Params then return false, "No lock running." end
            local elapsed = os.clock() - (enc.StartedAt or 0)
            local p = enc.Params
            local n = math.max(0, math.floor(tonumber(resets) or 0)) -- (the lock's resets / the tear's kills)
            -- plausibility per kind: fastest possible time, and (Rift Tear) kills it could really have had
            local minTime = (enc.Id == "VAULT_LOCK" and p.Pins * 0.15) or (enc.Id == "RIFT_TEAR" and 0) or (p.Hits and p.Hits * 0.06) or 0
            local range = (enc.Id == "VAULT_LOCK") and Encounters.FINISH_RANGE or 400 -- (the mark / echo / tear can take you across the room)
            local fair = elapsed >= minTime and elapsed <= p.Window + 3 and flat <= range
            if enc.Id == "RIFT_TEAR" then fair = fair and n <= math.ceil(math.min(elapsed, p.Window) * 3) end
            local cracked = ok == true and fair
            enc.State = cracked and "OPEN" or "JAMMED"
            run.Folder:SetAttribute("EncounterState", enc.State)
            if not cracked then return true, def and (def.Name .. ": failed") or "Failed" end
            return true, CombatServer.EncounterReward(player, enc.Id, { Resets = n, Kills = n, Clean = (enc.Id ~= "VAULT_LOCK") and (elapsed <= p.Window / 2) or n == 0 })
        end
        return false, "?"
    end

    -- Wandering merchant: buy ware i (gold, in range, once each)
    Remotes.GetFunction("MerchantBuy").OnServerInvoke = function(player: Player, index: any): (boolean, string?)
        local run = runs[player]
        if not run or type(run.Merchant) ~= "table" or type(index) ~= "number" then return false, "No merchant here." end
        local slot = run.Merchant[math.floor(index)]
        local def = DungeonEvents.MERCHANT_STOCK[math.floor(index)]
        if not slot or not def then return false, "Unknown ware." end
        if slot.Sold then return false, "Sold out." end
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local layout = DungeonGenerator.GetChamberLayout(run.Folder:GetAttribute("IsBossFloor") == true)
        if not root or (root.Position - DungeonEvents.MerchantPosition(layout)).Magnitude > DungeonEvents.USE_RANGE + 6 then return false, "Get closer to the stall." end
        local state = CombatServer.GetState(player)
        if (state.Gold or 0) < slot.Price then return false, string.format("You need %d gold.", slot.Price) end
        local ok, msg = CombatServer.MerchantGrant(player, def.Kind)
        if not ok then return false, msg end
        state.Gold -= slot.Price
        slot.Sold = true
        run.Folder:SetAttribute("Merchant", HttpService:JSONEncode(run.Merchant))
        Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
        return true, msg
    end

    -- Corridor hazard strips (the dungeon's own hazard damage is 3-5).
    Remotes.GetEvent("HazardHit").OnServerEvent:Connect(function(player: Player, dmg: any)
        local run = runs[player]
        if not run or type(dmg) ~= "number" or dmg ~= dmg then return end
        local now = os.clock()
        if now - run.LastHazard < 0.5 then return end
        run.LastHazard = now
        CombatServer.DamagePlayer(player, math.clamp(dmg, 0, 5), DungeonGenerator.BiomeHitType(run.Folder:GetAttribute("Biome")), nil, nil, nil, nil, "Hazard") -- (UPDATE 8: the biome's type; QOL2 R1: named)
    end)

    Players.PlayerRemoving:Connect(function(p) runs[p] = nil end)

    -- Regenerating elites, shield expiry, and ending runs the player walked out of (Z < 450 = the hub).
    task.spawn(function()
        local tick = 0
        while true do
            task.wait(0.5)
            tick += 1
            local now = os.clock()
            for player, run in pairs(runs) do
                for proxy, untilT in pairs(run.ShieldUntil) do
                    if now >= untilT then
                        run.ShieldUntil[proxy] = nil
                        if proxy.Parent then
                            proxy:SetAttribute("DamageTakenMult", proxy:GetAttribute("ModelName") == "SentinelMiniBoss" and 1 or nil)
                        end
                    end
                end
                -- Medics: every ~2.5 s heal allies within 32 studs by 6% of their max health (green beams)
                if tick % 5 == 0 then
                    for _, med in ipairs(run.Enemies:GetChildren()) do
                        if med:GetAttribute("DroneType") == "Medic" and not med:GetAttribute("Dead") and run.Pos[med] then
                            local mp = run.Pos[med]
                            for _, ally in ipairs(run.Enemies:GetChildren()) do
                                local ap = run.Pos[ally]
                                local h, mh = ally:GetAttribute("Health") or 0, ally:GetAttribute("MaxHealth") or 1
                                if ally ~= med and ap and not ally:GetAttribute("Dead") and h > 0 and h < mh and (ap - mp).Magnitude <= 32 then
                                    ally:SetAttribute("Health", math.min(mh, h + mh * 0.06))
                                    Remotes.GetEvent("CombatFx"):FireClient(player, "Arc", mp, ap, Color3.fromRGB(110, 255, 150))
                                end
                            end
                        end
                    end
                end
                -- EXPOSED (0.63, owner: bots should allow "more target switching"): one bot (never a boss / goblin) glows
                -- lime (BossCues) and takes CombatServer.EXPOSED_MULT damage -- switching to it pays. (0.88, owner: "should
                -- be constant with no downtime, just onto the next enemy. It should switch every 4 seconds"): always one up
                -- while a bot lives; it moves to a DIFFERENT bot every EXPOSE_EVERY, and at once (next 0.5 s tick) when the
                -- exposed one dies. With a single bot left it stays on that one.
                local ex = run.Exposed
                local lk = (run :: any).Linked
                if lk then DungeonRuns.LinkedTick(run) end -- (LINKED ROOMS pilot: rooms near you spawn, packs wake)
                pcall(DungeonRuns.Reconcile, run, now) -- (LIVE FIX 2026-11-06: a count that drifted above what's left)
                -- (LINKED ROOMS: the exposed bot is one of the AWAKE bots of the room you're in)
                local proot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                local function Near(m) -- (LINKED ROOMS v3: awake and within 100 studs -- chasers from the room behind count)
                    local mp = run.Pos[m]
                    return m:GetAttribute("Awake") == true and proot ~= nil and mp ~= nil and (mp - proot.Position).Magnitude <= 100
                end
                local gone = not ex or not ex.Parent or ex:GetAttribute("Dead") or (lk ~= nil and not Near(ex))
                if gone or now >= (run.NextExpose or 0) then
                    local pool = {}
                    for _, m in ipairs(run.Enemies:GetChildren()) do
                        if not m:GetAttribute("Dead") and not m:GetAttribute("IsBoss") and not m:GetAttribute("IsLootGoblin") and m ~= ex and run.Pos[m]
                            and (not lk or Near(m)) then
                            table.insert(pool, m)
                        end
                    end
                    if #pool > 0 then
                        if ex and ex.Parent then ex:SetAttribute("Exposed", nil) end
                        local pick = pool[math.random(1, #pool)]
                        pick:SetAttribute("Exposed", true)
                        run.Exposed = pick
                        run.NextExpose = now + DungeonRuns.EXPOSE_EVERY
                    elseif gone then
                        if ex and ex.Parent then ex:SetAttribute("Exposed", nil) end
                        run.Exposed = nil
                    end
                end
                DungeonRuns.SummonerTick(run, now) -- (UPDATE 8 Phase 5 ELITE MODS: Summoner elites call fodder)
                DungeonRuns.RaiseTick(run, now) -- (ENEMY VARIETY 2026-11-07: Seraphs raise fallen fodder)
                DungeonGenerator.CommanderTick(run.Enemies:GetChildren(), DungeonRuns.PosOf) -- (COMMANDER elites)
                local mending = FloorMods.Has(run.Config.Mods, "MENDING") -- (0.66 map mod: every non-boss enemy regenerates)
                local warded = FloorMods.Has(run.Config.Mods, "WARDED") -- (UPDATE 8 map mod: the top 20% of a monster's health is a ward)
                for _, m in ipairs(run.Enemies:GetChildren()) do
                    local mods = m:GetAttribute("EliteMods")
                    if warded and not m:GetAttribute("IsBoss") and not m:GetAttribute("Dead") then
                        local h, mh = m:GetAttribute("Health") or 0, m:GetAttribute("MaxHealth") or 1
                        local wv = FloorMods.V("WARDED", run.Config.ModScale) -- (MAPS V2: the band = the extra health, V / (1 + V))
                        local band = wv / (1 + wv)
                        if h >= mh * (1 - band) and h < mh and os.clock() - (m:GetAttribute("HurtAt") or 0) >= 2 then
                            m:SetAttribute("Health", math.min(mh, h + mh * band * 0.5 * 0.5)) -- (refills the ward band in 2 s)
                        end
                    end
                    if mending and not m:GetAttribute("IsBoss") and not m:GetAttribute("Dead") then
                        local h, mh = m:GetAttribute("Health") or 0, m:GetAttribute("MaxHealth") or 1
                        if h > 0 and h < mh and os.clock() - (m:GetAttribute("HurtAt") or 0) >= 3 then
                            m:SetAttribute("Health", math.min(mh, h + mh * FloorMods.V("MENDING", run.Config.ModScale) * 0.5)) -- (MAPS V2 scaled)
                        end
                    end
                    if DungeonGenerator.HasEliteMod(mods, "Regenerating") and not m:GetAttribute("Dead") then
                        local h, mh = m:GetAttribute("Health") or 0, m:GetAttribute("MaxHealth") or 1
                        if h > 0 and h < mh and os.clock() - (m:GetAttribute("HurtAt") or 0) >= DungeonGenerator.ELITE_REGEN_WAIT then
                            m:SetAttribute("Health", math.min(mh, h + mh * DungeonGenerator.ELITE_REGEN * 0.5))
                        end
                    end
                end
                if tick % 4 == 0 then
                    local char = player.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root and root.Position.Z < 450 then
                        run.OutsideTicks += 1
                        if run.OutsideTicks >= 4 then DungeonRuns.EndRun(player) end
                    else
                        run.OutsideTicks = 0
                    end
                end
            end
        end
    end)
end

return DungeonRuns
