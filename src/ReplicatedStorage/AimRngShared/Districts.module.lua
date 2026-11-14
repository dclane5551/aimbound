--!nocheck
-- ============================================================================================
-- CITY DISTRICTS (UPDATE 7 B5, the vault's "factions" renamed in Loot Economy Plan section 11; placeholder names): three
-- districts of the walled city, each run by a leader standing in the hub (LivingHub), each liking one playstyle --
-- PRECISION (Lantern Row), TEMPO (Wire Market), SURVIVAL (Iron Stair). From level UNLOCK every district hands you COUNT
-- bounties a day (rolled per user + day), fed by the same events as contracts (CombatServer.ContractEvent -> DistrictEvent).
-- A finished bounty pays STANDING with that district (DAILY_CAP a day in all) and costs half as much with its RIVAL, so you
-- end up backing a side. Standing has two numbers: Earned (sets your RANK, can drop) and Bank (what you spend in the
-- district's shop: its crafting currency, sigils, Storm Cores and two show-off titles).
-- State: Districts = { Day, Bounties = { [id] = list }, Earned = { [id] = n }, Bank = { [id] = n }, DayEarned }.
-- ============================================================================================
local Districts = {}

Districts.ON = true
Districts.UNLOCK = 65
Districts.COUNT = 2
Districts.DAILY_CAP = 3000
Districts.RIVAL_SHARE = 0.5
Districts.RANKS = { 0, 1500, 4000, 9000, 18000, 32000 } -- (rank 0..5)
Districts.RANK_NAMES = { [0] = "Stranger", "Known", "Trusted", "Ally", "Champion", "Legend" }
Districts.Order = { "LANTERN", "WIRE", "IRON" }

local DIFF_RANK = {}
do
    local ok, ID = pcall(require, script.Parent:WaitForChild("ItemData"))
    if ok then for i, d in ipairs(ID.DifficultyOrder) do DIFF_RANK[d] = i end end
end

Districts.Defs = {
    LANTERN = {
        Name = "Lantern Row", Leader = "Ilsa Wick", Role = "keeper of the lantern-makers", Style = "PRECISION", Color = Color3.fromRGB(255, 196, 90), Rival = "WIRE",
        Blurb = "The lamp-makers' row prizes a steady hand: weak spots, long streaks, clean shots.",
        Currency = "StripShard", TitleRank3 = "LanternFriend", TitleRank5 = "LanternLegend",
        Pool = {
            { Id = "WEAK", Text = "Finish %d enemies with a weak-spot hit", Target = 60, Event = "WeakKill" },
            { Id = "FOCUS", Text = "Reach a Focus streak of %d", Target = 25, Event = "Streak", Value = "max" },
            { Id = "TEAR", Text = "Close %d Breach", Target = 1, Event = "Encounter", MinLevel = 30, Match = function(c) return c.Id == "RIFT_TEAR" end },
            { Id = "TRIAL", Text = "Reach Gold rank in %d Aim Trial run", Target = 1, Event = "Trial", Match = function(c) return (c.Rank or 0) >= 3 end },
        },
    },
    WIRE = {
        Name = "Wire Market", Leader = "Juno Vale", Role = "fixer of the cable stalls", Style = "TEMPO", Color = Color3.fromRGB(90, 220, 255), Rival = "IRON",
        Blurb = "The cable stalls never sleep: clear fast, keep moving, take every run.",
        Currency = "Graft", TitleRank3 = "WireFriend", TitleRank5 = "WireLegend",
        Pool = {
            { Id = "FAST", Text = "Clear %d floors in under 60 seconds", Target = 2, Event = "FloorClear", Match = function(c) return (c.Elapsed or 999) < 60 end },
            { Id = "FLOORS", Text = "Clear %d dungeon floors", Target = 7, -- (UPDATE 8 packs: ~1/3 lower)
                Event = "FloorClear" },
            { Id = "MARK", Text = "Catch %d Runner", Target = 1, Event = "Encounter", MinLevel = 18, Match = function(c) return c.Id == "BOUNTY_MARK" end },
            { Id = "KILLS", Text = "Defeat %d enemies", Target = 120, Event = "Kill" }, -- (UPDATE 8: was "Pick 5 run boons"; packs: fodder counts 1 in 5)
        },
    },
    IRON = {
        Name = "Iron Stair", Leader = "Old Brann", Role = "foreman of the stair gangs", Style = "SURVIVAL", Color = Color3.fromRGB(235, 110, 80), Rival = "LANTERN",
        Blurb = "The stair gangs respect whoever walks out standing: no hits taken, elites and bosses down.",
        Currency = "Temper", TitleRank3 = "IronFriend", TitleRank5 = "IronLegend",
        Pool = {
            { Id = "NOHIT", Text = "Clear %d floors without taking a heavy hit", Target = 2, Event = "FloorClear", Match = function(c) return c.NoHit == true end },
            { Id = "ELITES", Text = "Defeat %d elite enemies", Target = 12, Event = "Kill", Match = function(c) return c.Elite == true end },
            { Id = "BOSSES", Text = "Defeat %d bosses", Target = 2, Event = "Kill", Match = function(c) return c.Boss == true end },
            { Id = "ECHO", Text = "Win %d Mirror Match", Target = 1, Event = "Encounter", MinLevel = 45, Match = function(c) return c.Id == "ECHO_DUEL" end },
        },
    },
}

-- the shop of a district (cost = standing from its Bank; Rank = the rank it needs)
function Districts.Shop(id: string): { any }
    local d = Districts.Defs[id]
    if not d then return {} end
    return {
        { Id = "CUR", Name = "3 " .. (d.Currency == "StripShard" and "Scrapes" or (d.Currency == "Graft" and "Rivets" or "Hones")), Cost = 600, Rank = 1, Mats = { [d.Currency] = 3 } },
        { Id = "SIGIL", Name = "A map (level 100+)", Cost = 900, Rank = 2, Sigil = true, MinLevel = 100 },
        { Id = "STORM", Name = "A Wildfire Core", Cost = 1200, Rank = 3, Mats = { StormCore = 1 } },
        { Id = "T3", Name = "Title: " .. (d.TitleRank3Name or ("Friend of " .. d.Name)), Cost = 2000, Rank = 3, Title = d.TitleRank3 },
        { Id = "T5", Name = "Title: " .. d.Name .. " Legend", Cost = 5000, Rank = 5, Title = d.TitleRank5 },
    }
end

function Districts.Today(): number return os.time() // 86400 end

function Districts.Unlocked(state: any): boolean
    return Districts.ON and type(state) == "table" and (state.Level or 1) >= Districts.UNLOCK
end

local function Entry(def: any): any return { Id = def.Id, Target = def.Target, Progress = 0, Done = false } end

-- today's record (rolls a new day's bounties; keeps standing)
function Districts.Ensure(state: any, userId: number): any
    local s = type(state.Districts) == "table" and state.Districts or {}
    s.Earned = type(s.Earned) == "table" and s.Earned or {}
    s.Bank = type(s.Bank) == "table" and s.Bank or {}
    local day = Districts.Today()
    if s.Day ~= day or type(s.Bounties) ~= "table" then
        s.Day, s.DayEarned, s.Bounties = day, 0, {}
        for i, id in ipairs(Districts.Order) do
            local r = Random.new((userId % 100000) * 6151 + day * 7 + i)
            local pool = {}
            for _, def in ipairs(Districts.Defs[id].Pool) do
                if (state.Level or 1) >= (def.MinLevel or 1) then table.insert(pool, def) end
            end
            local list = {}
            for _ = 1, math.min(Districts.COUNT, #pool) do
                local j = r:NextInteger(1, #pool)
                table.insert(list, Entry(pool[j]))
                table.remove(pool, j)
            end
            s.Bounties[id] = list
        end
    end
    state.Districts = s
    return s
end

function Districts.DefOf(id: string, bountyId: string): any
    for _, def in ipairs((Districts.Defs[id] or {}).Pool or {}) do if def.Id == bountyId then return def end end
    return nil
end
function Districts.Text(id: string, b: any): string
    local def = Districts.DefOf(id, b.Id)
    return def and string.format(def.Text, b.Target) or tostring(b.Id)
end

-- one event onto every district's list: returns { { District, Bounty } } that just finished
function Districts.Apply(s: any, event: string, amount: number?, ctx: any?): { any }
    local finished = {}
    for _, id in ipairs(Districts.Order) do
        for _, b in ipairs(s.Bounties[id] or {}) do
            local def = Districts.DefOf(id, b.Id)
            if def and not b.Done and def.Event == event and (not def.Match or def.Match(ctx or {})) then
                if def.Value == "max" then b.Progress = math.max(b.Progress, math.min(b.Target, amount or 0))
                else b.Progress = math.min(b.Target, b.Progress + (amount or 1)) end
                if b.Progress >= b.Target then b.Done = true; table.insert(finished, { District = id, Bounty = b }) end
            end
        end
    end
    return finished
end

-- standing a finished bounty pays (before the daily cap)
function Districts.StandingFor(level: number?): number
    return math.round(500 * (1 + ((level or 1) - Districts.UNLOCK) / 200))
end

function Districts.Rank(earned: number?): number
    local r = 0
    for i, need in ipairs(Districts.RANKS) do if (earned or 0) >= need then r = i - 1 end end
    return r
end

-- adds standing to id (capped by today's room) and takes the rival's share; returns what was added
function Districts.Gain(s: any, id: string, amount: number): number
    local room = math.max(0, Districts.DAILY_CAP - (s.DayEarned or 0))
    local add = math.min(room, math.max(0, math.floor(amount)))
    if add <= 0 then return 0 end
    s.DayEarned = (s.DayEarned or 0) + add
    s.Earned[id] = (s.Earned[id] or 0) + add
    s.Bank[id] = (s.Bank[id] or 0) + add
    local rival = Districts.Defs[id].Rival
    local loss = math.floor(add * Districts.RIVAL_SHARE)
    s.Earned[rival] = math.max(0, (s.Earned[rival] or 0) - loss)
    s.Bank[rival] = math.max(0, (s.Bank[rival] or 0) - loss)
    return add
end

return Districts
