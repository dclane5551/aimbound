--!nocheck
-- RUN SUMMARY (0.49, owner: "Add a summary after a run is completed / or you die so you can in detail view your stats
-- (time, accuracy, total hits, etc). This should also work in parties to compare accuracy dps etc.")
--
-- One record per player per run: Begin (CombatServer.StartRunLives = a solo run's first floor / a party run's start),
-- counted by the combat pipeline (CombatServer: shots / hits per trigger pull, pellet hits, weak spots, crits, damage,
-- kills, damage taken, deaths, floors), Finish (CombatServer.ClearRunLives = every way a run ends) sends "RunSummary"
-- to the player. Party runs share a key (PartyRuns party id): every member's record is in the summary; members who are
-- still playing show as "in run" with their numbers so far, and finished members get a refreshed table when the next
-- one finishes.
local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Remotes"))

local RunStats = {}
local live: { [Player]: any } = {}
local parties: { [string]: { [number]: any } } = {} -- party key -> userId -> record (live or finished)

local function Fresh(player: Player, key: string?, state: any): any
    return {
        UserId = player.UserId, Name = player.DisplayName, Party = key,
        StartedAt = os.clock(), EndedAt = nil, Outcome = nil,
        Shots = 0, Hits = 0, Pellets = 0, PelletHits = 0, Weak = 0, Crits = 0,
        Damage = 0, Highest = 0, Kills = 0, Elites = 0, Bosses = 0,
        Taken = 0, Deaths = 0, Floors = 0, BestFloor = 0, BestStreak = 0, Items = 0,
        GoldStart = state and state.Gold or 0, Gold = 0, LevelStart = state and state.Level or 1, Levels = 0,
        Weapon = state and state.EquippedWeapon and state.EquippedWeapon.Name or nil,
        Gun = state and state.EquippedWeapon and state.EquippedWeapon.BaseId or nil, -- (2026-10-20 AIM PROFILE: per-gun numbers)
        Difficulty = state and state.DungeonDifficulty or nil,
        LastHitAt = 0, CombatTime = 0, -- (DPS = damage over time spent fighting: hits within 2 s of each other)
    }
end

function RunStats.Begin(player: Player, key: string?, state: any)
    local r = Fresh(player, key, state)
    live[player] = r
    if key then
        parties[key] = parties[key] or {}
        parties[key][player.UserId] = r
    end
end

function RunStats.Get(player: Player): any
    return live[player]
end

function RunStats.Add(player: Player, field: string, n: number?)
    local r = live[player]
    if r then r[field] = (r[field] or 0) + (n or 1) end
end

function RunStats.Max(player: Player, field: string, v: number)
    local r = live[player]
    if r and v > (r[field] or 0) then r[field] = v end
end

-- a damage event (any kind: shots, ailments, splash); feeds DPS's fighting time
function RunStats.Damage(player: Player, amount: number, isShot: boolean?)
    local r = live[player]
    if not r then return end
    r.Damage += amount
    if isShot and amount > r.Highest then r.Highest = amount end
    local now = os.clock()
    local gap = now - r.LastHitAt
    r.CombatTime += (gap < 2) and gap or 0.25 -- (a fresh engagement counts its first quarter second)
    r.LastHitAt = now
end

-- BEST DROP (2026-10-23 loot feel, owner: getting good drops should feel satisfying): every item kept from the run (ground drop or
-- straight into the bag -- CombatServer.TagRunLoot; auto-sold / auto-salvaged ones don't count) is scored and the best one is kept
-- for the RUN SUMMARY's BEST DROP line: Relic > Mythic > Rare > ..., then a top-tier line, then item level.
function RunStats.NoteDrop(player: Player, item: any)
    local r = live[player]
    if not r or type(item) ~= "table" or item.Kind == "Gem" then return end
    local ItemData = require(game.ReplicatedStorage.AimRngShared.ItemData)
    local relic = item.Exotic ~= nil or item.Rarity == "Relic"
    local rank = relic and 99 or (ItemData.RarityRank[item.Rarity or ""] or 1)
    local okTop, top = pcall(ItemData.HasTopTierLine, item)
    local score = rank * 1e6 + ((okTop and top) and 5e5 or 0) + (tonumber(item.ItemLevel) or 0)
    if score > (r.BestScore or -1) then
        r.BestScore, r.Best = score, item
        r.BestTop = (okTop and top) or false
    end
end

-- (QOL2 R3 "vs your average") your averages BEFORE this run, from the AIM PROFILE's run log (state.AimLog = the last
-- ProfileService.LOG_MAX runs): accuracy = hits / shots, weak spot = weak / pellet hits, DPS = damage / fighting time (only entries
-- logged from QOL2 on carry Dm / Ct). nil = not enough logged yet -- the summary hides that line.
function RunStats.Averages(state: any): (number?, number?, number?)
    local log = (type(state) == "table" and type(state.AimLog) == "table") and state.AimLog or {}
    local s, h, w, p, dm, ct = 0, 0, 0, 0, 0, 0
    for _, e in ipairs(log) do
        if type(e) == "table" then
            s += tonumber(e.S) or 0; h += tonumber(e.H) or 0; w += tonumber(e.W) or 0; p += tonumber(e.P) or 0
            if tonumber(e.Ct) and tonumber(e.Dm) then dm += tonumber(e.Dm); ct += tonumber(e.Ct) end
        end
    end
    return (s >= 50) and h / s or nil, (p >= 30) and w / p or nil, (ct >= 20) and dm / ct or nil
end

function RunStats.Note(player: Player, outcome: string?)
    local r = live[player]
    if r then r.Pending = outcome end
end

local function Row(r: any): any
    local t = (r.EndedAt or os.clock()) - r.StartedAt
    return {
        Name = r.Name, UserId = r.UserId, Outcome = r.Outcome or "IN RUN", Time = t,
        Shots = r.Shots, Hits = r.Hits, Accuracy = (r.Shots > 0) and r.Hits / r.Shots or 0,
        PelletHits = r.PelletHits, WeakPct = (r.PelletHits > 0) and r.Weak / r.PelletHits or 0,
        CritPct = (r.PelletHits > 0) and r.Crits / r.PelletHits or 0,
        Damage = r.Damage, DPS = r.Damage / math.max(1, r.CombatTime), Highest = r.Highest,
        Kills = r.Kills, Elites = r.Elites, Bosses = r.Bosses, Taken = r.Taken, Deaths = r.Deaths,
        Floors = r.Floors, BestFloor = r.BestFloor, BestStreak = r.BestStreak, Items = r.Items,
        Gold = r.Gold, Levels = r.Levels, Weapon = r.Weapon, Difficulty = r.Difficulty,
        Best = r.Best, BestTop = r.BestTop, -- (BEST DROP: the item itself, for the summary's line + its tooltip)
        Killer = r.Killer, KillHits = r.KillHits, -- (QOL2 R1 DEATH RECAP: the last death this run -- CombatServer OnRunDeath)
        AvgAcc = r.AvgAcc, AvgWeak = r.AvgWeak, AvgDps = r.AvgDps, -- (QOL2 R3: your averages before this run; nil = hidden)
    }
end

local function Send(player: Player, mine: any)
    local rows = { Row(mine) }
    if mine.Party and parties[mine.Party] then
        for uid, r in pairs(parties[mine.Party]) do
            if uid ~= mine.UserId then table.insert(rows, Row(r)) end
        end
    end
    Remotes.GetEvent("RunSummary"):FireClient(player, rows)
end

-- the run ended for this player: outcome "VICTORY" | "EXTRACTED" | "DEFEATED" | "LEFT". Returns the record (nil for a run
-- that was only walked into) -- ProfileService.LogRun keeps it for the AIM PROFILE.
function RunStats.Finish(player: Player, outcome: string?, state: any): any
    local r = live[player]
    if not r then return nil end
    live[player] = nil
    r.EndedAt = os.clock()
    r.Outcome = outcome or r.Pending or "LEFT"
    if state then
        r.Gold = math.max(0, (state.Gold or 0) - r.GoldStart)
        r.Levels = math.max(0, (state.Level or 1) - r.LevelStart)
    end
    if r.Shots == 0 and r.Kills == 0 and r.EndedAt - r.StartedAt < 20 then return nil end -- (walked in and straight out)
    if state then r.AvgAcc, r.AvgWeak, r.AvgDps = RunStats.Averages(state) end -- (QOL2 R3: read before LogRun adds this run)
    if player.Parent then Send(player, r) end
    -- party: everyone who already finished sees the newcomer's final numbers
    if r.Party and parties[r.Party] then
        local anyLive = false
        for uid, o in pairs(parties[r.Party]) do
            if o ~= r and o.EndedAt then
                local p = Players:GetPlayerByUserId(uid)
                if p then Send(p, o) end
            elseif not o.EndedAt then
                anyLive = true
            end
        end
        if not anyLive then
            local key = r.Party
            task.delay(600, function() if parties[key] then parties[key] = nil end end)
        end
    end
    return r
end

Players.PlayerRemoving:Connect(function(p)
    local r = live[p]
    live[p] = nil
    if r then r.EndedAt, r.Outcome = os.clock(), "LEFT" end -- (stays in the party's table with its final numbers)
end)

return RunStats
