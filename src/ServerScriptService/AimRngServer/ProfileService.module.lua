--!nocheck
-- ============================================================================================
-- PLAYER PROFILES (2026-10-20, owner: "lets do that, just do the other things" = PLAYER INSPECT + AIM PROFILE; loadouts dropped).
-- Profile(userId) = a public snapshot: level, class, specialization, title, Marksman Grade, crew tag, the gun + gear + melee
-- (full item tables -> client tooltips), equipped passives, tree points, gems socketed, equipped cosmetics, and the AIM part:
-- lifetime shots / hits / weak-spot hits / kills / weak-spot kills / deaths / best headshot streak / play time, Aim Trial bests +
-- ranks, per-gun numbers (state.AimGuns) and the last runs (state.AimLog). Online players = live state; anyone else (a statue,
-- a leaderboard name) = a READ-ONLY peek at their save (SaveService.PeekSave; never written, no session lock), cached 60 s.
-- Where you stand: your accuracy vs everyone in this server.
-- RUN LOG: CombatServer.ClearRunLives -> ProfileService.LogRun(state, record) (RunStats.Finish's record): AimLog keeps LOG_MAX runs
-- { G gun, S shots, H hits, W weak, P pellet hits, K kills, D difficulty, T seconds, O outcome, At, Dm damage + Ct fighting seconds
-- (QOL2 R3, newer entries only) }, AimGuns[gun] adds them up. RunStats.Averages reads it for the RUN SUMMARY's "vs avg" lines.
-- Remote ProfileAction: ("Get", userId?) -> profile | ("List") -> players in this server.
-- ============================================================================================
local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))

local ProfileService = {}
ProfileService.LOG_MAX = 20
ProfileService.GUNS_MAX = 40
ProfileService.PEEK_GAP = 2 -- seconds between one player's save peeks (cache hits are free)
ProfileService.PEEK_PER_MIN = 30 -- save peeks a server makes a minute at most (DataStore GetAsync budget is shared with saves)
local CombatServer, SaveService
local peekCache = {} -- uid -> { At, Prof | false }: misses are cached too; pruned when it grows
local peekAt, peekTimes = {}, {}

-- ===== the run log =====
function ProfileService.LogRun(state: any, r: any)
    if type(state) ~= "table" or type(r) ~= "table" or (r.Shots or 0) <= 0 then return end
    local gun = tostring(r.Gun or (state.EquippedWeapon and state.EquippedWeapon.BaseId) or "?")
    local e = { G = gun, S = r.Shots or 0, H = r.Hits or 0, W = r.Weak or 0, P = r.PelletHits or 0, K = r.Kills or 0,
        D = r.Difficulty, T = math.floor(((r.EndedAt or os.clock()) - (r.StartedAt or os.clock())) + 0.5), O = r.Outcome, At = os.time(),
        Dm = math.round(tonumber(r.Damage) or 0), Ct = math.round((tonumber(r.CombatTime) or 0) * 10) / 10 } -- (QOL2 R3: DPS "vs your average")
    state.AimLog = type(state.AimLog) == "table" and state.AimLog or {}
    table.insert(state.AimLog, e)
    while #state.AimLog > ProfileService.LOG_MAX do table.remove(state.AimLog, 1) end
    state.AimGuns = type(state.AimGuns) == "table" and state.AimGuns or {}
    local g = state.AimGuns[gun]
    if not g then
        local n = 0
        for _ in pairs(state.AimGuns) do n += 1 end
        if n >= ProfileService.GUNS_MAX then return end
        g = { S = 0, H = 0, W = 0, P = 0, K = 0, R = 0 }
        state.AimGuns[gun] = g
    end
    g.S += e.S; g.H += e.H; g.W += e.W; g.P += e.P; g.K += e.K; g.R += 1
end

-- ===== the snapshot =====
local function Num(v) return tonumber(v) or 0 end
local function AimOf(st: any): any
    local stt = type(st.StatsTracking) == "table" and st.StatsTracking or {}
    local trials = {}
    local okA, AimTrials = pcall(require, Shared:WaitForChild("AimTrials"))
    if okA then
        for _, s in ipairs(AimTrials.Scenarios) do
            local best = type(st.TrialBest) == "table" and Num(st.TrialBest[s.Id]) or 0
            table.insert(trials, { Id = s.Id, Name = s.Name, Best = best, Rank = AimTrials.RankName(AimTrials.RankOf(s.Id, best)) })
        end
    end
    local guns = {}
    for id, g in pairs(type(st.AimGuns) == "table" and st.AimGuns or {}) do
        if type(g) == "table" then
            local def = ItemData.BaseWeapons and ItemData.BaseWeapons[id]
            table.insert(guns, { Id = id, Name = (ItemData.LineupShortNames and ItemData.LineupShortNames[id]) or (def and def.Name) or id,
                S = Num(g.S), H = Num(g.H), W = Num(g.W), P = Num(g.P), K = Num(g.K), R = Num(g.R) })
        end
    end
    table.sort(guns, function(a, b) return a.S > b.S end)
    return {
        Shots = Num(stt.Shots), Hits = Num(stt.Hits), Weak = Num(stt.WeakSpotHits), Kills = Num(stt.OwnKills), WeakKills = Num(stt.WeakSpotKills),
        Deaths = Num(stt.Deaths), BestHs = Num(stt.BestHeadshotRun), Play = Num(stt.PlaySeconds), Runs = Num(stt.Runs),
        Trials = trials, Guns = guns, Log = type(st.AimLog) == "table" and st.AimLog or {},
    }
end

local function Snapshot(st: any, uid: number, name: string, online: boolean): any
    local okC, ClassData = pcall(require, Shared:WaitForChild("ClassData"))
    local okS, Asc = pcall(require, Shared:WaitForChild("AscendancyData"))
    local okT, TreeData = pcall(require, Shared:WaitForChild("SkillTreeData"))
    local okM, MR = pcall(require, Shared:WaitForChild("MasteryRank"))
    local okK, Cosmetics = pcall(require, Shared:WaitForChild("Cosmetics"))
    local cls = okC and st.Class and ClassData.ById[st.Class] or nil
    local spec = okS and st.Ascendancy and Asc.ById[st.Ascendancy] or nil
    local passives = {}
    for _, id in ipairs(type(st.EquippedPassives) == "table" and st.EquippedPassives or {}) do
        local n = okT and TreeData[id]
        if n then table.insert(passives, { Name = n.Name, Desc = n.Description }) end
    end
    local gems = 0
    for _ in pairs(type(st.SocketedGems) == "table" and st.SocketedGems or {}) do gems += 1 end
    local cos = {}
    if okK then
        for _, e in ipairs(Cosmetics.All()) do
            local okE, on = pcall(Cosmetics.Equipped, st, e)
            if okE and on and e.Unlock ~= "Free" then
                local cat = Cosmetics.CategoryById[e.Cat]
                table.insert(cos, { Cat = cat and cat.Label or e.Cat, Name = e.Name, Rarity = e.Rarity })
                if #cos >= 16 then break end
            end
        end
    end
    local title = st.EquippedTitle and ItemData.Titles[st.EquippedTitle]
    return {
        UserId = uid, Name = name, Online = online, Level = Num(st.Level), Class = cls and cls.Name or nil, Spec = spec and spec.Name or nil,
        Title = title and title.Title or nil, TitleColor = title and title.Color or nil, Grade = okM and MR.Rank(st) or 0,
        Crew = st.GuildTag, CrewColor = st.GuildColor,
        Weapon = st.EquippedWeapon, Gear = type(st.EquippedGear) == "table" and st.EquippedGear or {}, Melee = st.EquippedKnife,
        Passives = passives, TreePoints = #(type(st.AllocatedNodes) == "table" and st.AllocatedNodes or {}), Gems = gems,
        Cosmetics = cos, Aim = AimOf(st),
    }
end

local function Accuracy(st: any): number?
    local stt = type(st) == "table" and type(st.StatsTracking) == "table" and st.StatsTracking or nil
    local s = stt and Num(stt.Shots) or 0
    if s < 50 then return nil end
    return Num(stt.Hits) / s
end

function ProfileService.Get(asker: Player, uid: number): (boolean, any)
    uid = math.floor(tonumber(uid) or asker.UserId)
    local p = Players:GetPlayerByUserId(uid)
    local prof
    if p then
        -- (GetState WAITS for a save that is still loading: never let one joining player stall the remote)
        local st = SaveService.IsReady(p) and CombatServer.GetState(p) or nil
        if not st then return false, "Their save is still loading." end
        local okP, res = pcall(Snapshot, st, uid, p.DisplayName, true)
        if not okP then warn("[ProfileService] snapshot of " .. uid .. ": " .. tostring(res)); return false, "That profile couldn't be read." end
        prof = res
    else
        local now = os.clock()
        local c = peekCache[uid]
        if c and now - c.At < 60 then
            prof = c.Prof
            if not prof then return false, "That player's profile isn't available." end
        else
            -- (live-only: every peek is a DataStore read; one player can't drain the server's budget that joins + saves use)
            if peekAt[asker] and now - peekAt[asker] < ProfileService.PEEK_GAP then return false, "One moment..." end
            while peekTimes[1] and now - peekTimes[1] > 60 do table.remove(peekTimes, 1) end
            if #peekTimes >= ProfileService.PEEK_PER_MIN then return false, "Profiles are busy, try again in a moment." end
            peekAt[asker] = now
            table.insert(peekTimes, now)
            local data = SaveService.PeekSave(uid)
            if type(data) == "table" and data.EquippedWeapon == nil and data.EquippedWeaponUid ~= nil then
                for _, w in ipairs(type(data.Inventory) == "table" and data.Inventory or {}) do -- (a save keeps the gun by Uid)
                    if type(w) == "table" and w.Uid == data.EquippedWeaponUid then data.EquippedWeapon = w; break end
                end
            end
            if type(data) == "table" then
                local okN, nm = pcall(function() return Players:GetNameFromUserIdAsync(uid) end)
                local okP, res = pcall(Snapshot, data, uid, okN and nm or ("Player " .. uid), false)
                if okP then prof = res else warn("[ProfileService] snapshot of " .. uid .. ": " .. tostring(res)) end
            end
            local n = 0
            for k, e in pairs(peekCache) do if now - e.At >= 60 then peekCache[k] = nil else n += 1 end end
            if n < 500 then peekCache[uid] = { At = now, Prof = prof or false } end
            if not prof then return false, "That player's profile isn't available." end
        end
    end
    -- where they stand: accuracy vs everyone in this server (50+ shots)
    local mine = p and Accuracy(SaveService.IsReady(p) and CombatServer.GetState(p) or nil) or ((prof.Aim.Shots >= 50) and prof.Aim.Hits / prof.Aim.Shots or nil)
    if mine then
        local n, below = 0, 0
        for _, o in ipairs(Players:GetPlayers()) do
            local a = SaveService.IsReady(o) and Accuracy(CombatServer.GetState(o)) or nil
            if a then n += 1; if a < mine then below += 1 end end
        end
        prof.Server = { Players = n, Better = below }
    end
    return true, prof
end

function ProfileService.List(): any
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local st = SaveService.IsReady(p) and CombatServer.GetState(p) or nil
        table.insert(out, { UserId = p.UserId, Name = p.DisplayName, Level = st and st.Level or 1 })
    end
    table.sort(out, function(a, b) return a.Level > b.Level end)
    return out
end

-- Studio: DevCmd ["aimfake", n] = n sample runs in your aim log (random guns / accuracy) + matching lifetime counters
function ProfileService.Dev(player: Player, cmd: string, a: any): string
    local st = CombatServer.GetState(player)
    if cmd == "aimfake" then
        local guns = { "AK47", "M4A1", "MP5", "AWP", "SCAR" }
        local stt = st.StatsTracking
        for i = 1, math.clamp(tonumber(a) or 10, 1, 40) do
            local s = math.random(120, 400)
            local acc = 0.3 + math.random() * 0.45
            local h = math.floor(s * acc)
            local r = { Shots = s, Hits = h, Weak = math.floor(h * (0.15 + math.random() * 0.3)), PelletHits = h, Kills = math.random(15, 60),
                Difficulty = "Hard", StartedAt = os.clock() - math.random(300, 900), EndedAt = os.clock(), Outcome = "VICTORY", Gun = guns[(i - 1) % #guns + 1] }
            ProfileService.LogRun(st, r)
            stt.Shots = (stt.Shots or 0) + s; stt.Hits = (stt.Hits or 0) + h; stt.WeakSpotHits = (stt.WeakSpotHits or 0) + r.Weak
            stt.OwnKills = (stt.OwnKills or 0) + r.Kills; stt.WeakSpotKills = (stt.WeakSpotKills or 0) + math.floor(r.Kills * 0.3)
        end
        stt.Runs = (stt.Runs or 0) + (tonumber(a) or 10)
        return "logged " .. #st.AimLog
    end
    return "?"
end

function ProfileService.Init(combat: any)
    CombatServer = combat
    SaveService = require(script.Parent:WaitForChild("SaveService"))
    local last = {}
    Remotes.GetFunction("ProfileAction").OnServerInvoke = function(player: Player, action: any, a: any)
        if action == "List" then return true, ProfileService.List() end
        local now = os.clock()
        if last[player] and now - last[player] < 0.3 then return false, "One moment..." end
        last[player] = now
        if action == "Get" then return ProfileService.Get(player, a) end
        return false, "?"
    end
    Players.PlayerRemoving:Connect(function(p) last[p] = nil; peekAt[p] = nil end)
end

return ProfileService
