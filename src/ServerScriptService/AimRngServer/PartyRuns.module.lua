--!nocheck
-- Server-run PARTY dungeons (2-4 players). Solo runs stay on the player's own client (DungeonRuns /
-- DungeonClient); a party needs one shared world, so the server builds the floor and runs the bots
-- (DungeonGenerator, the same code the client uses) in Workspace.PartyRuns.Run_<id>. Several parties and
-- solo players can be in dungeons at once at the same coordinates: every party instance carries a RunId
-- attribute, enemies only target / hit that party's members (Player attribute RunId), and each client hides
-- (and stops colliding with) every dungeon that isn't its own.
--
-- Party rules: enemies get +60% health per extra player and ~25% more bots per extra player; every member
-- gets full XP / gold and their OWN loot rolls (CombatServer.ProcessEnemyKill); chests open once per
-- member; a member who dies respawns at the floor entrance.
-- PORTALS ARE PER PLAYER (owner 2026-10-04: "have only the player who hits the portal teleport through ... they can
-- catch up through as many portals as they need"): every floor is its own run object + arena with its own RunId
-- ("<party>_<floor>"), so enemies, hits, visibility and spectating stay per floor. The first member through a portal
-- builds the next floor; later ones join it. A floor nobody is on any more is torn down. run.Party = the whole party.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Remotes = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Remotes"))
local ItemData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ItemData"))
local DungeonGenerator = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("DungeonGenerator"))
local BossTrials = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("BossTrials"))
local AscensionTrials = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("AscensionTrials"))
local PacksPilot = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("PacksPilot")) -- (UPDATE 8 Phase 5: packs in parties)

local PartyRuns = {}
local CombatServer: any = nil -- injected (require cycle)

PartyRuns.HEALTH_PER_EXTRA = 0.60
PartyRuns.COUNT_PER_EXTRA = 0.25
-- RAIDS (PartyService room.Raid, 8-12 players): RAID_FLOORS floors, the last one a raid boss (the biome superboss with
-- more shield orbs, BossAI); everyone who's there for the kill gets a guaranteed Legendary on top of the usual payout.
PartyRuns.RAID_FLOORS = 3
-- PARTY TRIALS (2026-10-05, owner: "have the bosses we have be multiplayer (scales to 2x,3x,4x health depending on player
-- count of party)"): a Boss Trial (Base.BossTrial: one boss floor) or a Trial of Ascension (Base.AscTrial: two hard floors +
-- The Ascendant) started by the room's host (PartyService.StartSpecial). The trial boss gets x players health (x tier).
local function MaxFloors(cfg: any): number?
    if cfg.BossTrial then return BossTrials.FLOOR end
    if cfg.AscTrial then return AscensionTrials.FLOORS end
    if cfg.Raid then return PartyRuns.RAID_FLOORS end
    if cfg.Endless then return nil end
    local modeDef = ItemData.RunMode(cfg.Difficulty, cfg.Endless)
    return modeDef and modeDef.MaxWaves or 10
end
PartyRuns.MaxFloors = MaxFloors

local runs: { [string]: any } = {}
local runOfPlayer: { [Player]: any } = {}
local nextId = 0

local container = Workspace:FindFirstChild("PartyRuns") or Instance.new("Folder")
container.Name = "PartyRuns"
container.Parent = Workspace

function PartyRuns.Get(runId: string?): any
    return runId and runs[runId] or nil
end
function PartyRuns.RunOfPlayer(player: Player): any
    return runOfPlayer[player]
end
function PartyRuns.RunOfModel(model: Instance): any
    return runs[DungeonGenerator.RunIdOf(model) or ""]
end
function PartyRuns.IsMember(run: any, player: Player): boolean
    return run ~= nil and table.find(run.Members, player) ~= nil
end

local function Entry(run: any): CFrame
    local layout = DungeonGenerator.GetChamberLayout(ItemData.IsBossConfig(run.Config))
    return CFrame.new(0, 7, layout.EntryZ)
end

local function MoveToEntry(run: any, player: Player)
    local char = player.Character
    local cf = Entry(run) * CFrame.new((table.find(run.Members, player) or 1) * 3 - 6, 0, 0)
    if char then
        char:PivotTo(cf)
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end
    Remotes.GetEvent("TeleportPlayer"):FireClient(player, "PartyDungeon", cf)
    if CombatServer and CombatServer.FullHeal then CombatServer.FullHeal(player) end -- (a new floor: full health)
end

function PartyRuns.PartyMembers(run: any): { Player }
    return (run and run.Party and run.Party.Members) or (run and run.Members) or {}
end

local function Broadcast(run: any)
    local f = run.Folder
    local remaining = run.Remaining
    if run.IsBossFloor and not run.BossDefeated then remaining = math.max(remaining, 1) end
    if run.Cleared then remaining = 0 end
    for _, p in ipairs(run.Members) do
        Remotes.GetEvent("DungeonUpdate"):FireClient(p, {
            Biome = run.Config.Biome, Difficulty = run.Config.Difficulty, Floor = run.Config.FloorNumber,
            Remaining = remaining, Party = true,
        })
    end
    if f then f:SetAttribute("RemainingEnemies", remaining) end
end

-- Builds the current floor (map + enemies) for the party.
-- CLEARED FLOORS STAY CLEARED (owner 2026-10-05: "a player is afk on floor 3 and another player is on floor 5, when the
-- player on floor 3 goes to floor 4, all of the mobs are there again ... Each floor should be saved as clear"): a floor
-- nobody stands on is still torn down (performance), but the party remembers its biome + seed and that it was cleared.
-- A late member walks into the SAME floor, empty, with its chest and portals waiting.
local function BuildFloor(run: any)
    local cfg = run.Config
    if run.Folder then run.Folder:Destroy() end
    local party = run.Party
    local saved = party and party.FloorSave and party.FloorSave[cfg.FloorNumber]
    cfg.Seed = saved and saved.Seed or math.random(1, 2 ^ 30)
    cfg.Biome = saved and saved.Biome or cfg.FixedBiome or DungeonGenerator.NextBiome(run.Party or run) -- MIXED RUNS: every floor its own biome (one bag per party; a Boss Trial keeps its own)
    if party then
        party.FloorSave = party.FloorSave or {}
        party.FloorSave[cfg.FloorNumber] = party.FloorSave[cfg.FloorNumber] or { Seed = cfg.Seed, Biome = cfg.Biome }
    end
    local wasCleared = saved and saved.Cleared
    cfg.FolderName = "Run_" .. run.Id
    cfg.FolderParent = container
    if cfg.Raid then cfg.BossArena = cfg.FloorNumber >= PartyRuns.RAID_FLOORS end -- (raid: only the last floor is a boss)
    ItemData.RollMidBoss(run.Party or run, cfg) -- (2026-10-22 RUN LENGTHS v4: the 10% floor-3 mini-boss, one roll per party run)
    if cfg.AscTrial then
        cfg.BossArena = cfg.FloorNumber >= AscensionTrials.FLOORS
        cfg.Mods = (cfg.FloorNumber < AscensionTrials.FLOORS) and table.clone(AscensionTrials.HARD_MODS) or {} -- (two hard floors)
    end
    -- (LINKED ROOMS: a party floor is a line of rooms too -- the same rule as solo; a saved floor keeps what it was)
    if saved and saved.Linked ~= nil then cfg.Linked = saved.Linked or nil else cfg.Linked = PartyRuns.LinkedWanted(run, cfg) or nil end
    if party and party.FloorSave[cfg.FloorNumber] then party.FloorSave[cfg.FloorNumber].Linked = cfg.Linked == true end
    run.Linked = nil
    -- (PARTY TWIN 2026-10-25, owner: "I want everyone to be able to see the same generated arenas in multiplayer"): the server
    -- builds the floor down the solo client's path (MIRRORED: same draws, same colliders, no terrain) and every member's client
    -- builds the full-detail copy from the folder's Twin attr (AimRngShared/PartyTwin). Studio A/B: workspace DevTwinOff = true
    -- = the old server-only party look.
    cfg.Mirror = not (game:GetService("RunService"):IsStudio() and workspace:GetAttribute("DevTwinOff") == true) or nil
    local folder = DungeonGenerator.BuildThemedDungeon(cfg) -- sets cfg.Geo / cfg.FxFolder
    folder:SetAttribute("RaidActive", true)
    folder:SetAttribute("Floor", cfg.FloorNumber)
    folder:SetAttribute("Linked", cfg.Linked == true) -- (LINKED ROOMS: clients rebuild the layout from these)
    folder:SetAttribute("LinkSeed", cfg.Seed)
    folder:SetAttribute("Difficulty", cfg.Difficulty)
    run.Folder = folder
    run.Cleared = false
    run.Opened = {}
    run.VaultOpened = {}
    run.FloorStart = os.clock()
    run.IsBossFloor = ItemData.IsBossConfig(cfg)
    run.BossDefeated = not run.IsBossFloor
    if not wasCleared then DungeonGenerator.PlanBoss(run.Party or run, cfg) end -- (no repeated bosses within a party's run)
    -- (UPDATE 8 Phase 5 PACKS EVERYWHERE: party floors get packs too -- not trials / Ascension; PacksPilot.ON is the global switch)
    cfg.PacksPilot = (PacksPilot.ON and not cfg.BossTrial and not cfg.AscTrial
        and not (game:GetService("RunService"):IsStudio() and workspace:GetAttribute("DevNoPacks"))) or nil -- (Studio A/B: DevNoPacks)
    cfg.MiniPacks = nil
    run.PackQueue = nil
    local roster = wasCleared and {} or (cfg.Linked and DungeonGenerator.RollLinkedRoster(cfg)) or DungeonGenerator.RollFloorRoster(cfg)
    run.Remaining = 0 -- (loot goblins don't count: they can escape; LINKED ROOMS: only the exit room counts)
    for _, e in ipairs(roster) do if e.Kind ~= "LootGoblin" and (not cfg.Linked or e.Counted) then run.Remaining += 1 end end
    local spec = { HealthScale = cfg.HealthScale }
    -- (party trials: the trial boss has x players health, a Boss Trial x its tier on top -- the solo path does that in
    -- DungeonRuns; The Ascendant applies its own tier)
    local bossSpec = nil
    if cfg.BossTrial then
        local t = BossTrials.Tiers[cfg.BossTrial.Tier] or BossTrials.Tiers[1]
        local wm = cfg.BossTrial.Weekly and require(game.ReplicatedStorage.AimRngShared.Weekly).Mods[cfg.BossTrial.Weekly] -- (UPDATE 7)
        bossSpec = { HealthScale = (cfg.BossHealthScale or 1) * t.Hp * (BossTrials.HpScale or 1) * (wm and wm.Hp or 1) }
    elseif cfg.AscTrial then
        bossSpec = { HealthScale = cfg.BossHealthScale or 1 }
    end
    -- (UPDATE 8 Phase 5: pack waves -- the first PartyRuns.StartPacks(run) packs now, the rest queued for PartyRuns.ReleasePacks)
    local start = PartyRuns.StartPacks(run)
    local held, order = {}, {}
    if cfg.Linked then PartyRuns.LinkedStart(run, roster); roster = {} end -- (LINKED ROOMS: placed packs, room by room)
    for _, e in ipairs(roster) do
        if e.Pack and e.Pack > start then
            if not held[e.Pack] then held[e.Pack] = {}; table.insert(order, e.Pack) end
            table.insert(held[e.Pack], e)
        else
            PartyRuns.SpawnEntry(run, e, bossSpec, spec)
        end
    end
    table.sort(order)
    if #order > 0 then
        run.PackQueue = {}
        for _, k in ipairs(order) do table.insert(run.PackQueue, held[k]) end
    end
    for _, p in ipairs(run.Members) do
        MoveToEntry(run, p)
        CombatServer.GetState(p).FloorHitTaken = false
        if CombatServer.Zen then pcall(CombatServer.Zen.ThreadClear, p, CombatServer.GetState(p)) end -- (ZENITH: Unbroken Thread starts every floor at 0)
    end
    if wasCleared then
        -- already cleared by the party: no enemies, the chest + portals are there
        run.Cleared = true
        run.BossDefeated = true
        folder:SetAttribute("FloorCleared", true)
        if cfg.Linked and run.Linked then -- (the exit room's chest + portals; the cache was taken the first time round)
            run.Linked.Cache = "USED"
            folder:SetAttribute("LinkCache", "USED")
            cfg.LinkedExitZ = run.Linked.L.Rooms[run.Linked.L.Exit].Z - DungeonGenerator.GetChamberLayout(false).CombatZ
            cfg.LinkedNext = (cfg.FloorNumber or 1) + PartyRuns.LR.FLOOR_STEP
        end
        DungeonGenerator.SpawnVictoryVault(folder, cfg)
    end
    Broadcast(run)
end

-- (UPDATE 8 Phase 5, LOOT/RUN builder) PARTY PACKS: the same packs as solo (DungeonGenerator.AddPilotPacks), run by the server.
-- More players = more packs live at once: START_PACKS + 1 per extra member (MINI_START on a mini-boss floor), the next pack when
-- fewer than REFILL_BELOW + 3 per extra member are alive, at least PacksPilot.AWAY studs from every member. Fodder = x PacksPilot.HP
-- health (on top of the party's HealthScale), x DMG damage, x XP / GOLD rewards (DungeonGenerator CreateBot spec.Fodder).
function PartyRuns.Size(run: any): number -- (members, or the Studio DevPartySize)
    local devN = game:GetService("RunService"):IsStudio() and tonumber(workspace:GetAttribute("DevPartySize")) or nil
    return devN or #(run.Members or {})
end
function PartyRuns.StartPacks(run: any): number
    local extra = math.max(0, PartyRuns.Size(run) - 1)
    if run.Config.MiniPacks then return PacksPilot.MINI_START end
    -- (PACK SIZE BY DIFFICULTY: packs are up to twice as big on the top tiers -> start fewer of them so a full party's opening wave
    -- stays under PacksPilot.PARTY_LIVE_CAP bots; the rest arrive through ReleasePacks as before)
    local lo, hi = PacksPilot.PackRange(run.Config.Difficulty)
    local per = 1 + (lo + hi) / 2
    local n = PacksPilot.START_PACKS + extra
    while n > PacksPilot.START_PACKS and n * per > PacksPilot.PARTY_LIVE_CAP do n -= 1 end
    return n
end
function PartyRuns.SpawnEntry(run: any, e: any, bossSpec: any?, spec: any?)
    local cfg = run.Config
    local mods, tier = nil, nil
    if e.Kind == "Bot" and e.Elite then mods, tier = DungeonGenerator.RollEliteMods(cfg) end
    local pos = DungeonGenerator.FindOpenSpot(e.Pos, 3, cfg.Geo)
    local s = ((e.Kind == "TrialBoss" or e.Kind == "Ascendant") and bossSpec) or spec or { HealthScale = cfg.HealthScale }
    if e.Fodder then s = { HealthScale = (cfg.HealthScale or 1) * PacksPilot.HP, DamageScale = PacksPilot.DMG, Fodder = true } end
    local lk = e.LinkRoom and run.Linked
    if lk and lk.L.Rooms[e.LinkRoom] then -- (LINKED ROOMS: its room's leash + chase boxes, its pack; rolled at its ramp floor)
        local LR = PartyRuns.LR
        cfg = PartyRuns.LinkedCfg(run, e.LinkFloor or cfg.FloorNumber)
        s = table.clone(s)
        local home, chase, hbb, cbb = LR.LeashBoxes(lk.L, e.LinkRoom, e.LinkPath)
        s.Link = { X0 = hbb[1], X1 = hbb[2], Z0 = hbb[3], Z1 = hbb[4], Home = pos, Pack = e.LinkPack, HomeBoxes = home, Chase = chase, HomeBB = hbb, ChaseBB = cbb }
        s.Link.Near = LR.NearBoxes(lk.L, e.LinkRoom, e.LinkPath) -- (BOTFIX: a distance wake only from its own room / a path into it)
    end
    if tier then s = table.clone(s); s.EliteTier = tier end -- (FUTURE-PROOF: the rolled tier, never re-counted from the mods)
    local ok, err = pcall(DungeonGenerator.CreateOfKind, e.Kind, e.Archetype, mods, pos, cfg, run.Folder, s)
    if not ok then warn("[PartyRuns] couldn't spawn " .. tostring(e.Kind) .. ": " .. tostring(err)) end
    if ok and lk and typeof(err) == "Instance" then
        err:SetAttribute("LinkRoom", e.LinkRoom)
        err:SetAttribute("LinkPath", e.LinkPath)
        err:SetAttribute("LinkFloor", e.LinkFloor)
        if not e.Counted then err:SetAttribute("Uncounted", true) end
    end
    return ok and err or nil
end
local function Alive(run: any): number
    local n = 0
    for _, m in ipairs(run.Folder:GetChildren()) do
        if m:IsA("Model") and (m:GetAttribute("Health") or 0) > 0 and m:GetAttribute("Dead") ~= true and not m:GetAttribute("IsLootGoblin") then n += 1 end
    end
    return n
end
function PartyRuns.ReleasePacks(run: any)
    local q = run.PackQueue
    if not q or run.Cleared or not run.Folder or not run.Folder.Parent then return end
    local extra = math.max(0, PartyRuns.Size(run) - 1)
    local below = run.Config.MiniPacks and PacksPilot.MINI_REFILL_BELOW or (PacksPilot.REFILL_BELOW + 3 * extra)
    if Alive(run) >= below then return end
    local pack = table.remove(q, 1)
    if #q == 0 then run.PackQueue = nil end
    local layout = DungeonGenerator.GetChamberLayout(false)
    local half = layout.CombatSize / 2 - 12
    local best, bestD = nil, -1
    for _ = 1, 12 do
        local c = Vector3.new(math.random(-half, half), 0, layout.CombatZ + math.random(-half, half))
        local d = math.huge
        for _, p in ipairs(run.Members) do
            local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if root then d = math.min(d, (Vector3.new(root.Position.X, 0, root.Position.Z) - c).Magnitude) end
        end
        if d >= PacksPilot.AWAY then best = c; break end
        if d > bestD then best, bestD = c, d end
    end
    local shift = Vector3.new(best.X - pack[1].Pos.X, 0, best.Z - pack[1].Pos.Z)
    for _, e in ipairs(pack) do
        e = table.clone(e)
        e.Pos += shift
        PartyRuns.SpawnEntry(run, e, nil, { HealthScale = run.Config.HealthScale })
    end
end
-- (UPDATE 8 COMMANDER) a party bot's position (models only)
function PartyRuns.PosOf(m: Instance): Vector3?
    if not m:IsA("Model") then return nil end
    local ok, p = pcall(function() return (m :: Model):GetPivot().Position end)
    return ok and p or nil
end
-- (ENEMY VARIETY 2026-11-07) RAISE on party floors: the same rule as solo (DungeonRuns.RaiseTick, AimRngShared/BotVerbs)
function PartyRuns.BV(): any return require(game.ReplicatedStorage.AimRngShared.BotVerbs) end
function PartyRuns.RaiseTick(run: any, now: number)
    local BV = PartyRuns.BV()
    if not BV.On() or not run.VerbCorpses or run.Cleared or not run.Folder or not run.Folder.Parent then return end
    BV.RaiseTick({ Store = run, List = function() return run.Folder:GetChildren() end, PosOf = PartyRuns.PosOf,
        Spawn = function(e, m)
            e.Pos = Vector3.new(e.Pos.X, DungeonGenerator.IsGroundArchetype(e.Archetype) and 5 or e.Pos.Y, e.Pos.Z)
            local sm = PartyRuns.SpawnEntry(run, e)
            if sm and e.Counted then run.Remaining += 1; Broadcast(run) end
            return sm
        end }, now)
end

-- (UPDATE 8 Phase 5 ELITE MODS) SUMMONER on party floors: the same rule as solo (DungeonRuns.SummonerTick)
function PartyRuns.SummonerTick(run: any, now: number)
    if run.Cleared or not run.Folder or not run.Folder.Parent then return end
    for _, m in ipairs(run.Folder:GetChildren()) do
        local mods = m:IsA("Model") and m:GetAttribute("EliteMods")
        if DungeonGenerator.HasEliteMod(mods, "Summoner") and m:GetAttribute("Dead") ~= true and (m:GetAttribute("Health") or 0) > 0 then
            local done = m:GetAttribute("Summons") or 0
            local first = m:GetAttribute("SummonAt")
            if not first then m:SetAttribute("SummonAt", now + 4); first = now + 4 end
            if done < 3 and now >= first then
                m:SetAttribute("Summons", done + 1)
                m:SetAttribute("SummonAt", now + 12)
                local at = m:GetPivot().Position
                for _ = 1, 2 do
                    local a = math.random() * math.pi * 2
                    local arch = PacksPilot.FODDER[math.random(1, #PacksPilot.FODDER)]
                    local sm = PartyRuns.SpawnEntry(run, { Kind = "Bot", Archetype = arch, Fodder = true,
                        LinkRoom = m:GetAttribute("LinkRoom"), LinkPack = m:GetAttribute("LinkPack"), LinkFloor = m:GetAttribute("LinkFloor"), -- (LINKED ROOMS)
                        Counted = not m:GetAttribute("Uncounted"),
                        Pos = Vector3.new(at.X + math.cos(a) * 5, DungeonGenerator.IsGroundArchetype(arch) and 5 or at.Y, at.Z + math.sin(a) * 5) })
                    if sm and m:GetAttribute("Awake") then sm:SetAttribute("Awake", true) end
                end
                if not m:GetAttribute("Uncounted") then run.Remaining += 2 end
                Broadcast(run)
            end
        end
    end
end

-- ==================== LINKED ROOMS ON PARTY FLOORS (2026-10-22: linked rooms are the normal game) ====================
-- The same line of rooms as solo (DungeonGenerator.BuildLinked builds it here on the server as PARTS: no terrain on a party
-- floor), the same placed packs (RollLinkedRoster: x CountMult packs a room), chase + leash (CreateBot LinkCheck reads the
-- nearest MEMBER on the server), rooms spawned near ANY member, the awake cap scaled with the party, the exit room's foes the
-- only ones that count, a linked floor counting as LinkedRooms.FLOOR_STEP floors (the portal skips one), the side cache once
-- per member. Clients draw the HUD / arrow / park far rooms / hold unrevealed rooms' bots (DungeonClient.LinkedStartParty).
PartyRuns.LR = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("LinkedRooms"))
-- may this party floor be linked? never a boss / mini-boss floor, a trial, a raid; only when the floor after it is regular
-- (it counts as two) and every member has linked rooms on (F6 "Linked rooms off" on anyone = single rooms for the party)
function PartyRuns.LinkedWanted(run: any, cfg: any): boolean
    local LR = PartyRuns.LR
    if not LR.ON or cfg.BossTrial or cfg.AscTrial or cfg.Raid or ItemData.IsBossConfig(cfg) then return false end
    for _, p in ipairs(run.Members) do if not LR.For(p) then return false end end
    local mode = ItemData.RunMode(cfg.Difficulty, cfg.Endless)
    local nxt = (cfg.FloorNumber or 1) + 1
    return not ItemData.IsBossFloor(cfg.Difficulty, cfg.Endless, nxt) and (mode == nil or mode.Endless or mode.MaxWaves == nil or nxt <= mode.MaxWaves)
end
-- a config copy at floor f (the v2 ramp: rooms past the middle are rolled one floor deeper)
function PartyRuns.LinkedCfg(run: any, f: number): any
    local lk = run.Linked
    local c = lk and lk.Cfg[f]
    if not c then
        c = table.clone(run.Config)
        c.FloorNumber = f
        if lk then lk.Cfg[f] = c end
    end
    return c
end
function PartyRuns.LinkedSpawnRoom(run: any, i: number, now: boolean?)
    local lk = run.Linked
    if not lk or lk.Spawned[i] then return end
    local list = lk.Pending[i] or {}
    lk.Pending[i] = {}
    -- (2026-10-26 ARRIVAL FX) a room made as a member walks in: its bots carry WarpIn (each client warps them in)
    local warp = not now and workspace:GetServerTimeNow() or nil
    local function Make(e)
        local m = PartyRuns.SpawnEntry(run, e)
        if warp and typeof(m) == "Instance" then
            m:SetAttribute("WarpIn", warp)
            -- (the server runs party bots: it holds them still while they form -- ArrivalFx.WARP_S)
            local was = m:GetAttribute("SlowMult")
            m:SetAttribute("SlowMult", 0)
            task.delay(require(game.ReplicatedStorage.AimRngShared.ArrivalFx).WARP_S, function()
                if m.Parent and m:GetAttribute("SlowMult") == 0 then m:SetAttribute("SlowMult", was) end
            end)
        end
    end
    if now or #list <= PartyRuns.LR.SPAWN_BATCH then
        for _, e in ipairs(list) do Make(e) end
        lk.Spawned[i] = true
        return
    end
    lk.Spawned[i] = "busy" -- (a few a frame: no server frame builds a whole room)
    task.spawn(function()
        for k, e in ipairs(list) do
            if run.Linked ~= lk or not run.Folder or not run.Folder.Parent then return end
            Make(e)
            if k % PartyRuns.LR.SPAWN_BATCH == 0 then task.wait() end
        end
        if run.Linked == lk then lk.Spawned[i] = true end
    end)
end
-- (SEALED ROOMS) a path's stragglers, once a member steps into the path
function PartyRuns.LinkedSpawnPath(run: any, k: number)
    local lk = run.Linked
    if not lk or lk.PathSpawned[k] then return end
    lk.PathSpawned[k] = true
    local list = lk.PathPending[k] or {}
    lk.PathPending[k] = {}
    for _, e in ipairs(list) do PartyRuns.SpawnEntry(run, e) end
end
-- (SEALED ROOMS) the floor's seal from what is left in each main room (folder attr LinkSeal; LinkedRooms.SealState)
function PartyRuns.LinkedSeal(run: any, here: { [number]: boolean })
    local lk = run.Linked
    if not lk or not run.Folder then return end
    local left = {}
    for _, m in ipairs(run.Folder:GetChildren()) do
        local r = m:IsA("Model") and m:GetAttribute("LinkRoom")
        if r and not m:GetAttribute("LinkPath") and m:GetAttribute("Dead") ~= true and (m:GetAttribute("Health") or 0) > 0 and not m:GetAttribute("IsLootGoblin") then
            left[r] = (left[r] or 0) + 1
        end
    end
    for i, list in pairs(lk.Pending) do
        if not lk.Spawned[i] then
            for _, e in ipairs(list) do if e.Kind ~= "LootGoblin" then left[i] = (left[i] or 0) + 1 end end
        end
    end
    local seal = PartyRuns.LR.SealState(lk, lk.L, left, here, os.clock())
    if seal ~= lk.Seal then
        lk.Seal = seal
        run.Folder:SetAttribute("LinkSeal", seal)
    end
end
function PartyRuns.LinkedStart(run: any, roster: { any })
    local LR = PartyRuns.LR
    local cfg = run.Config
    local L = DungeonGenerator.LinkedLayout(cfg)
    local lk = { L = L, Pending = {}, PathPending = {}, Spawned = {}, PathSpawned = {}, Cfg = {}, WakeAt = {}, Cache = L.Side and "LOCKED" or "",
        CacheTaken = {}, WakeAfter = os.clock() + 1.5 }
    for i = 1, #L.Rooms do lk.Pending[i] = {} end
    for _, e in ipairs(roster) do
        if e.LinkPath then -- (SEALED ROOMS: stragglers wait for a member in their path)
            lk.PathPending[e.LinkPath] = lk.PathPending[e.LinkPath] or {}
            table.insert(lk.PathPending[e.LinkPath], e)
        else
            table.insert(lk.Pending[e.LinkRoom or 1], e)
        end
    end
    run.Linked = lk
    local f = run.Folder
    f:SetAttribute("LinkCache", lk.Cache)
    f:SetAttribute("LinkNext", (cfg.FloorNumber or 1) + LR.FLOOR_STEP)
    PartyRuns.LinkedSpawnRoom(run, 1, true) -- (SEALED ROOMS: room 1 now, the rest when a member arrives)
    PartyRuns.LinkedSeal(run, {})
    -- the side room's cache: built here (a party floor's map is the server's), one take per member once its packs are dead
    local side = L.Side
    local vis = side and f:FindFirstChild("LinkedRooms") and f.LinkedRooms:FindFirstChild("R" .. side)
    local chest, open, prompt = DungeonGenerator.BuildLinkCache(f, cfg, vis or f)
    if chest then chest:SetAttribute("Live", true) end -- (PARTY TWIN: in a Scenery folder, but members' clients keep it shown)
    if prompt then
        lk.CachePrompt = prompt
        prompt.Triggered:Connect(function(plr: Player)
            if run.Linked ~= lk or lk.Cache ~= "OPEN" or lk.CacheTaken[plr] or not PartyRuns.IsMember(run, plr) or not CombatServer then return end
            lk.CacheTaken[plr] = true
            CombatServer.GiveFloorLoot(plr, false)
            if open and not lk.CacheLid then lk.CacheLid = true; open() end
        end)
    end
end
-- (2026-10-26) ARRIVAL on its own fast loop (LinkedRooms.ARRIVE_TICK; as DungeonRuns): a room's bots warp in as a member crosses
-- its doorway, not up to 0.5 s later
task.spawn(function()
    while true do
        task.wait(PartyRuns.LR.ARRIVE_TICK)
        for _, run in pairs(runs) do
            local lk = run.Linked
            if lk and run.Folder and run.Folder.Parent and os.clock() >= (lk.WakeAfter or 0) then
                for _, p in ipairs(run.Members) do
                    local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    if root and root.Position.Z > 450 then
                        for i = 1, #lk.L.Rooms do
                            if not lk.Spawned[i] and PartyRuns.LR.ArriveAt(lk.L, i, root.Position) then pcall(PartyRuns.LinkedSpawnRoom, run, i) end
                        end
                    end
                end
            end
        end
    end
end)
-- every 0.5 s: which rooms the members are in, spawn the rooms near any of them, wake packs, the awake cap, the cache
function PartyRuns.LinkedTick(run: any)
    local lk = run.Linked
    if not lk then return end
    if not run.Folder or not run.Folder.Parent or os.clock() < (lk.WakeAfter or 0) then return end
    local LR, L = PartyRuns.LR, lk.L
    local pts, rooms = {}, {}
    for _, p in ipairs(run.Members) do
        local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if root and root.Position.Z > 450 then
            local pos = root.Position
            local cur, inside = LR.RoomAt(L, pos)
            local inPath = nil
            for k, pa in ipairs(L.Paths) do
                if LR.InBoxes(LR.PathBoxes(pa, 1, 0), pos, 0) then inPath = k end
            end
            table.insert(pts, { pos, cur, inside, inPath })
            rooms[cur] = true
        end
    end
    if #pts == 0 then return end
    -- (SEALED ROOMS) ARRIVAL: a room once a member is in it or in the leg / band of a path into it; a path's stragglers once a
    -- member is in it
    local here = {}
    for i = 1, #L.Rooms do
        for _, q in ipairs(pts) do
            if not lk.Spawned[i] and LR.ArriveAt(L, i, q[1]) then PartyRuns.LinkedSpawnRoom(run, i) end
            if q[3] and q[2] == i then here[i] = true end
        end
    end
    for k = 1, #L.Paths do
        if not lk.PathSpawned[k] then
            for _, q in ipairs(pts) do
                if q[4] == k then PartyRuns.LinkedSpawnPath(run, k); break end
            end
        end
    end
    local kids = run.Folder:GetChildren()
    local wake, awakeN = nil, 0
    for _, m in ipairs(kids) do
        local pk = m:IsA("Model") and m:GetAttribute("LinkPack")
        if pk and m:GetAttribute("Dead") ~= true and (m:GetAttribute("Health") or 0) > 0 then
            if m:GetAttribute("Awake") then
                awakeN += 1
            else
                local h = m:GetAttribute("Health") or 0
                local homing = m:GetAttribute("Homing") == true
                local hit = (homing and h < (m:GetAttribute("HomingHp") or 0)) or (not homing and h < (m:GetAttribute("MaxHealth") or 0))
                if not hit then
                    local mp = PartyRuns.PosOf(m)
                    local room, path = m:GetAttribute("LinkRoom"), m:GetAttribute("LinkPath")
                    for _, q in ipairs(pts) do
                        if (q[3] and room == q[2] and not path) or (q[4] ~= nil and path == q[4])
                            or (not homing and mp ~= nil and (mp - q[1]).Magnitude <= LR.WAKE_DIST and LR.WakeReach(L, room, path, q[1])) then hit = true break end -- (BOTFIX: not through the rock)
                    end
                end
                if hit then wake = wake or {}; wake[pk] = true end
            end
        end
    end
    if wake then
        local now = os.clock()
        for _, m in ipairs(kids) do
            local pk = m:IsA("Model") and m:GetAttribute("LinkPack")
            if pk and wake[pk] and not m:GetAttribute("Awake") and m:GetAttribute("Dead") ~= true then
                m:SetAttribute("Awake", true)
                m:SetAttribute("Homing", nil)
                awakeN += 1
            end
            if pk and wake[pk] then lk.WakeAt[pk] = lk.WakeAt[pk] or now end
        end
    end
    -- AWAKE CAP scaled with the party (LinkedRooms.PARTY_AWAKE_PER a member past the first): the earliest-woken packs outside every
    -- member's room give up and walk home
    local cap = LR.AWAKE_CAP + (LR.PARTY_AWAKE_PER or 0) * math.max(0, PartyRuns.Size(run) - 1)
    if awakeN > cap then
        local packs, members = {}, {}
        for pk, at in pairs(lk.WakeAt) do table.insert(packs, { pk, at }) end
        table.sort(packs, function(a, b) return a[2] < b[2] end)
        for _, m in ipairs(kids) do
            local pk = m:IsA("Model") and m:GetAttribute("LinkPack")
            if pk and m:GetAttribute("Awake") and m:GetAttribute("Dead") ~= true then
                members[pk] = members[pk] or {}
                table.insert(members[pk], m)
            end
        end
        for _, e in ipairs(packs) do
            if awakeN <= cap then break end
            local list = members[e[1]]
            if list and not rooms[list[1]:GetAttribute("LinkRoom")] then
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
    PartyRuns.LinkedSeal(run, here)
    if L.Side and lk.Cache == "LOCKED" and lk.Spawned[L.Side] == true then
        local left = 0
        for _, m in ipairs(kids) do
            if m:IsA("Model") and m:GetAttribute("LinkRoom") == L.Side and m:GetAttribute("Dead") ~= true and (m:GetAttribute("Health") or 0) > 0 and not m:GetAttribute("IsLootGoblin") then left += 1 end
        end
        if left == 0 then
            lk.Cache = "OPEN"
            run.Folder:SetAttribute("LinkCache", "OPEN")
            if lk.CachePrompt then lk.CachePrompt.Enabled = true; lk.CachePrompt.ObjectText = "HIDDEN CACHE" end
        end
    end
end
-- the exit room is clear: the chest + portals stand there; the other rooms keep their packs (go back for the side cache)
function PartyRuns.LinkedClear(run: any, killed: Instance?)
    local lk = run.Linked
    local cfg = run.Config
    for _, m in ipairs(run.Folder:GetChildren()) do
        if m:IsA("Model") and m:GetAttribute("Health") and m ~= killed then
            local room = m:GetAttribute("LinkRoom")
            if room == nil or room == lk.L.Exit then m:Destroy() end
        end
    end
    lk.Pending[lk.L.Exit] = {}
    cfg.LinkedExitZ = lk.L.Rooms[lk.L.Exit].Z - DungeonGenerator.GetChamberLayout(false).CombatZ
    cfg.LinkedNext = (cfg.FloorNumber or 1) + PartyRuns.LR.FLOOR_STEP
    run.Folder:SetAttribute("FloorCleared", true)
    for _, p in ipairs(run.Members) do PartyRuns.LinkedCredit(p, run) end
end
-- a linked floor's clear also credits the floor it skipped (the same as DungeonRuns.LinkedFloorCredit for solo)
function PartyRuns.LinkedCredit(player: Player, run: any)
    if not CombatServer then return end
    local cfg = run.Config
    local state = CombatServer.GetState(player)
    for f = (cfg.FloorNumber or 1) + 1, (cfg.FloorNumber or 1) + PartyRuns.LR.FLOOR_STEP - 1 do
        local st = state.StatsTracking
        if st and ItemData.RecordFloorClear(st, cfg.Difficulty, f, cfg.BotSkill, not state.FloorHitTaken, state.Level) and CombatServer.TreeClearBonus then
            CombatServer.TreeClearBonus(player, state, cfg.Difficulty)
        end
        CombatServer.RS.Add(player, "Floors"); CombatServer.RS.Max(player, "BestFloor", f)
        CombatServer.ContractEvent(player, state, "FloorClear", 1, { Difficulty = cfg.Difficulty, NoHit = not state.FloorHitTaken, Biome = cfg.Biome, Linked = true })
        CombatServer.AddSeasonXP(player, state, require(game.ReplicatedStorage.AimRngShared.Seasons).XP.FloorClear)
    end
end

-- A floor of the party: its own run object (shared Config values, its own FloorNumber / RunId / Members).
local function NewFloor(party: any, floorNumber: number, members: { Player }): any
    local cfg = table.clone(party.Base)
    local run = { Id = party.Id .. "_" .. floorNumber, Party = party, Room = party.Room, Members = members, Config = cfg }
    cfg.FloorNumber = floorNumber
    cfg.RunId = run.Id
    cfg.Members = members -- (the same table: members who catch up become targets)
    runs[run.Id] = run
    party.Floors[floorNumber] = run
    for _, p in ipairs(members) do
        runOfPlayer[p] = run
        p:SetAttribute("RunId", run.Id)
    end
    BuildFloor(run)
    return run
end

local function DropFloor(run: any)
    if run.Folder then run.Folder:Destroy() end
    runs[run.Id] = nil
    if run.Party and run.Party.Floors[run.Config.FloorNumber] == run then run.Party.Floors[run.Config.FloorNumber] = nil end
end

-- Starts a party run for a lobby room (2-4 players). overrides: { BossTrial = { Id, Tier } | AscTrial = { Tier },
-- Difficulty, FloorNumber } for a party trial.
function PartyRuns.Start(room: any, overrides: any?): any
    nextId += 1
    local id = tostring(nextId)
    local members = {}
    local levelSum = 0
    for _, p in ipairs(room.Members) do
        if p.Parent then
            table.insert(members, p)
            levelSum += CombatServer.GetState(p).Level
        end
    end
    if #members == 0 then return nil end
    local n = #members
    -- (UPDATE 8 Phase 5, Studio only: workspace DevPartySize = pretend party size for the bot count / health -- server load tests)
    local devN = game:GetService("RunService"):IsStudio() and tonumber(workspace:GetAttribute("DevPartySize")) or nil
    if devN then n = math.clamp(math.floor(devN), 1, 12) end
    local party = {
        Id = id, Room = room, Members = members, Floors = {},
        Base = {
            Biome = room.Biome, Difficulty = (ItemData.ParseRunKey(room.Difficulty)) or "Easy", FloorNumber = 1,
            Endless = select(2, ItemData.ParseRunKey(room.Difficulty)) or nil, -- (ENDLESS game type: "Endless:<difficulty>")
            PlayerLevel = math.round(levelSum / n), BotSkill = room.BotSkill, Raid = room.Raid == true or nil,
            HealthScale = 1 + PartyRuns.HEALTH_PER_EXTRA * (n - 1),
            CountMult = 1 + PartyRuns.COUNT_PER_EXTRA * (n - 1),
            BossHealthScale = n, -- (trial bosses: x2 / x3 / x4)
        },
    }
    if overrides then
        for k, v in pairs(overrides) do party.Base[k] = v end
        if overrides.BossTrial or overrides.AscTrial then party.Base.Endless, party.Base.Raid = nil, nil end
        party.TrialStart = os.clock()
    end
    for _, p in ipairs(members) do
        local st = CombatServer.GetState(p)
        st.DungeonDifficulty = room.Difficulty
        CombatServer.ResetRunBoons(p)
        CombatServer.StartRunLives(p, "P" .. id) -- (RUN SUMMARY: the party shares a key -> compare everyone)
        CombatServer.BeginRunLoot(p)
    end
    return NewFloor(party, party.Base.FloorNumber or 1, table.clone(members))
end

local function EndRun(party: any)
    for _, f in pairs(table.clone(party.Floors)) do DropFloor(f) end
    if party.Room and party.Room.OnRunEnded then party.Room.OnRunEnded(party.Room) end
end

-- A member leaves the run (exit, out of the arena, disconnect). The last one out ends it.
function PartyRuns.RemoveMember(player: Player)
    local run = runOfPlayer[player]
    if not run then return end
    runOfPlayer[player] = nil
    if player.Parent then player:SetAttribute("RunId", nil) end
    CombatServer.ResetRunBoons(player)
    CombatServer.ResolveRunLoot(player, CombatServer.GetState(player).RunKeep == true) -- won / extracted keeps it
    CombatServer.ClearRunLives(player)
    local i = table.find(run.Members, player)
    if i then table.remove(run.Members, i) end
    local party = run.Party
    local j = party and table.find(party.Members, player)
    if j then table.remove(party.Members, j) end
    if #run.Members == 0 then DropFloor(run) else Broadcast(run) end
    if party and #party.Members == 0 then EndRun(party) end
end

-- A member died: back to the floor entrance at full health (the run goes on).
function PartyRuns.RespawnMember(player: Player)
    local run = runOfPlayer[player]
    if run then MoveToEntry(run, player) end
end

-- Kill bookkeeping (rewards are handed out by CombatServer before this).
function PartyRuns.OnEnemyKilled(run: any, model: Instance)
    if run.Cleared then return end
    if model:GetAttribute("IsLootGoblin") then return end -- (not counted toward the clear)
    pcall(function() PartyRuns.BV().NoteCorpse(run, model, PartyRuns.PosOf(model)) end) -- (ENEMY VARIETY: a raiser's corpse)
    local em = model:GetAttribute("EliteMods") -- (COMMANDER: its pack loses the buff the moment it dies)
    if DungeonGenerator.HasEliteMod(em, "Commander") and run.Folder then
        DungeonGenerator.CommanderTick(run.Folder:GetChildren(), PartyRuns.PosOf)
    end
    if model:GetAttribute("Uncounted") then return end -- (LINKED ROOMS: only the exit room's foes count toward the clear)
    run.Remaining = math.max(0, run.Remaining - 1)
    if model:GetAttribute("IsBoss") then run.BossDefeated = true end
    local cleared = (run.IsBossFloor and run.BossDefeated) or (not run.IsBossFloor and run.Remaining == 0)
    if cleared then
        run.Cleared = true
        if run.Party and run.Party.FloorSave and run.Party.FloorSave[run.Config.FloorNumber] then run.Party.FloorSave[run.Config.FloorNumber].Cleared = true end
        -- dismiss leftover adds (LINKED ROOMS: only the exit room's; the other rooms keep their packs)
        if run.Linked then
            PartyRuns.LinkedClear(run, model)
        else
            for _, m in ipairs(run.Folder:GetChildren()) do
                if m:IsA("Model") and m:GetAttribute("Health") and m ~= model then m:Destroy() end
            end
        end
        local cfg = run.Config
        local elapsed = os.clock() - (run.FloorStart or os.clock())
        for _, p in ipairs(run.Members) do
            local state = CombatServer.GetState(p)
            local st = state.StatsTracking
            if ItemData.RecordFloorClear(st, cfg.Difficulty, cfg.FloorNumber, cfg.BotSkill, not state.FloorHitTaken, state.Level) then
                CombatServer.TreeClearBonus(p, state, cfg.Difficulty)
            end
            CombatServer.RS.Add(p, "Floors"); CombatServer.RS.Max(p, "BestFloor", cfg.FloorNumber)
            if elapsed < (st.FastestFloorClearSeconds or math.huge) then st.FastestFloorClearSeconds = elapsed end
            CombatServer.ContractEvent(p, state, "FloorClear", 1, { Difficulty = cfg.Difficulty, Elapsed = elapsed, NoHit = not state.FloorHitTaken, Biome = cfg.Biome })
            CombatServer.AddSeasonXP(p, state, require(game.ReplicatedStorage.AimRngShared.Seasons).XP.FloorClear)
        end
        local maxWaves = MaxFloors(cfg) or math.huge
        if cfg.FloorNumber >= maxWaves and (cfg.BossTrial or cfg.AscTrial) then
            -- a party trial cleared: every member there gets their own finish (records, points, rewards), then the gold
            -- hub portal (TrialDone) takes them home
            local Endgame = require(script.Parent:WaitForChild("EndgameServer"))
            local secs = os.clock() - ((run.Party and run.Party.TrialStart) or run.FloorStart or os.clock())
            for _, p in ipairs(run.Members) do
                if cfg.BossTrial then
                    Endgame.BossTrialFinished(p, { Id = cfg.BossTrial.Id, Tier = cfg.BossTrial.Tier, Weekly = cfg.BossTrial.Weekly }, secs)
                else
                    Endgame.AscTrialFinished(p, { Tier = cfg.AscTrial.Tier }, secs)
                end
            end
            cfg.TrialDone = true
            DungeonGenerator.SpawnVictoryVault(run.Folder, cfg)
            Broadcast(run)
            return
        end
        if cfg.FloorNumber >= maxWaves then
            for _, p in ipairs(run.Members) do
                local st = CombatServer.GetState(p)
                if cfg.Raid then
                    -- the raid boss: a guaranteed Legendary for everyone there, plus extra materials
                    local StatCalculator = require(game.ReplicatedStorage.AimRngShared.StatCalculator)
                    local stats = StatCalculator.Calculate(st.EquippedWeapon, st.AllocatedNodes, st.Streak, st.Level, st.Attributes, st.EquippedGear, st.EquippedTitle, st.SocketedGems, st.RunBoons, st)
                    CombatServer.DropInFront(p, st)
                    CombatServer.DropItemFor(p, st, stats, 3.0, "Top2")
                    CombatServer.GrantMaterials(p, st, { Prism = 9 })
                    st.StatsTracking.RaidsCleared = (st.StatsTracking.RaidsCleared or 0) + 1
                    Remotes.GetEvent("CombatFx"):FireClient(p, "Text", "RAID CLEARED: a top item for every raider!", Color3.fromRGB(255, 200, 80))
                end
                st.Gold += 1800
                CombatServer.GrantMaterials(p, st, { Prism = 6 })
                st.RunKeep = true -- finished the run: run loot is kept
                CombatServer.RecordRunFinished(p, st, cfg.Difficulty)
                Remotes.GetEvent("DungeonVictory"):FireClient(p, cfg.Difficulty, cfg.FloorNumber)
            end
        end
        DungeonGenerator.SpawnVictoryVault(run.Folder, cfg)
        if run.IsBossFloor and not cfg.Raid then -- (UPDATE 7 B4 SHARED SPOILS: members carrying a seal break it)
            pcall(function() require(script.Parent:WaitForChild("SharedSpoils")).Open(run.Members, cfg) end)
        end
        -- (UPDATE 8 Phase 5: boons are cut -- no boss-floor boon any more)
        run.PackQueue = nil
    end
    Broadcast(run)
end

-- Party dungeon chests / portal (the prompts live on the server's copy of the map).
DungeonGenerator.ServerChestHandler = function(player: Player, kind: string, chestId: number, part: Instance?)
    local run = runs[DungeonGenerator.RunIdOf(part) or ""]
    if not PartyRuns.IsMember(run, player) then return end
    run.Opened[player] = run.Opened[player] or {}
    if kind == "Supply" then
        if run.Opened[player][chestId] then return end
        run.Opened[player][chestId] = true
        CombatServer.GiveSupplyChestLoot(player)
    elseif kind == "Vault" then
        if not run.Cleared or run.VaultOpened[player] then return end
        run.VaultOpened[player] = true
        local cfg = run.Config
        local modeDef = ItemData.RunMode(cfg.Difficulty, cfg.Endless)
        local isSuper = modeDef ~= nil and modeDef.SuperBossWave ~= nil and cfg.FloorNumber == modeDef.SuperBossWave
        CombatServer.GiveFloorLoot(player, isSuper or ItemData.IsBossConfig(cfg))
    end
end
DungeonGenerator.ServerPortalHandler = function(player: Player, part: Instance?)
    local run = runs[DungeonGenerator.RunIdOf(part) or ""]
    if not PartyRuns.IsMember(run, player) or not run.Cleared or run.Advancing then return end
    local cfg = run.Config
    local maxF = MaxFloors(cfg)
    if maxF and cfg.FloorNumber >= maxF then return end
    -- only THIS player goes through: into the next floor if a teammate already opened it, else a fresh one
    local party = run.Party
    local nextN = cfg.FloorNumber + ((cfg.Linked and PartyRuns.LR.FLOOR_STEP) or 1) -- (LINKED ROOMS: counts as two floors)
    CombatServer.MissGroundLoot(player) -- (drops left behind: Legendary+ -> LOST LOOT, like solo)
    local i = table.find(run.Members, player)
    if i then table.remove(run.Members, i) end
    local nextRun = party.Floors[nextN]
    if nextRun then
        table.insert(nextRun.Members, player)
        runOfPlayer[player] = nextRun
        player:SetAttribute("RunId", nextRun.Id)
        CombatServer.GetState(player).FloorHitTaken = false
        if CombatServer.Zen then pcall(CombatServer.Zen.ThreadClear, player, CombatServer.GetState(player)) end -- (ZENITH: a fresh floor)
        MoveToEntry(nextRun, player)
        Broadcast(nextRun)
    else
        run.Advancing = true
        NewFloor(party, nextN, { player })
        run.Advancing = false
    end
    if #run.Members == 0 then DropFloor(run) else Broadcast(run) end
end

-- Reward multiplier of the bot-skill step the player is fighting at (party or solo run).
function PartyRuns.BotSkillOf(player: Player): number?
    local run = runOfPlayer[player]
    return run and run.Config.BotSkill or nil
end

function PartyRuns.Init(combat: any)
    CombatServer = combat
    Players.PlayerRemoving:Connect(PartyRuns.RemoveMember)
    -- EXPOSED (0.63, same rule as solo runs -- DungeonRuns): one non-boss bot at a time glows lime and takes +40%
    task.spawn(function()
        -- (0.88: constant -- a new bot every 4 s, and at once when the exposed one dies; see DungeonRuns)
        local EVERY = 4
        while true do
            task.wait(0.5)
            local now = os.clock()
            for _, run in pairs(runs) do
                local f = run.Folder
                if f and f.Parent then
                    local ex = run.Exposed
                    local gone = not ex or not ex.Parent or ex:GetAttribute("Dead") == true
                    if gone or now >= (run.NextExpose or 0) then
                        local pool = {}
                        for _, m in ipairs(f:GetChildren()) do
                            if m:IsA("Model") and m:GetAttribute("Health") and m:GetAttribute("Dead") ~= true and not m:GetAttribute("IsBoss")
                                and not m:GetAttribute("IsLootGoblin") and m ~= ex and (m:GetAttribute("LinkPack") == nil or m:GetAttribute("Awake") == true) then
                                table.insert(pool, m)
                            end
                        end
                        if #pool > 0 then
                            if ex and ex.Parent then ex:SetAttribute("Exposed", nil) end
                            local pick = pool[math.random(1, #pool)]
                            pick:SetAttribute("Exposed", true)
                            run.Exposed = pick
                            run.NextExpose = now + EVERY
                        elseif gone then
                            if ex and ex.Parent then ex:SetAttribute("Exposed", nil) end
                            run.Exposed = nil
                        end
                    end
                end
            end
        end
    end)
    -- (UPDATE 8 Phase 5) pack waves + Summoner elites on party floors
    task.spawn(function()
        while true do
            task.wait(0.5)
            local now = os.clock()
            for _, run in pairs(runs) do
                local ok, err = pcall(function()
                    PartyRuns.ReleasePacks(run)
                    PartyRuns.SummonerTick(run, now)
                    PartyRuns.RaiseTick(run, now) -- (ENEMY VARIETY 2026-11-07: Seraphs raise fallen fodder)
                    PartyRuns.LinkedTick(run) -- (LINKED ROOMS)
                    if run.Folder and run.Folder.Parent and not run.Cleared then -- (UPDATE 8 COMMANDER elites)
                        DungeonGenerator.CommanderTick(run.Folder:GetChildren(), PartyRuns.PosOf)
                    end
                end)
                if not ok then warn("[PartyRuns] packs: " .. tostring(err)) end
            end
        end
    end)
    -- members who walk out of the arena (Z < 450 = the hub) for ~8s leave the run
    task.spawn(function()
        local outside: { [Player]: number } = {}
        while true do
            task.wait(2)
            for p, run in pairs(runOfPlayer) do
                local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if root and root.Position.Z < 450 then
                    outside[p] = (outside[p] or 0) + 1
                    if outside[p] >= 4 then
                        outside[p] = nil
                        PartyRuns.RemoveMember(p)
                    end
                else
                    outside[p] = nil
                end
            end
        end
    end)
end

return PartyRuns
