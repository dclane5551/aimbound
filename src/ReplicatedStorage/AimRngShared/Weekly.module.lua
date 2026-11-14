--!nocheck
-- ============================================================================================
-- THE WEEK (UPDATE 7 "DEPTH" A5; vault "UPDATE 7 - Depth" + "Loot Economy Plan" section 5: "a reliable big currency stack").
-- Names are placeholders until the owner picks them (Loot Economy Plan section 12).
--
-- WEEKLY BOSS (from level UNLOCK_BOSS 22): one Boss Trial boss a week (BossOf, every boss in turn) with a weekly MODIFIER
-- (ModOf). Fought from the Challenges window's WEEKLY tab at the tier your level reaches (TierFor). Its FIRST clear of the
-- week pays the weekly stack (Reward) on top of the normal trial rewards; after that it's a normal trial.
--   The modifier reaches the boss through config.WeeklyMod (DungeonGenerator.CreateTrialBoss: Pace / Dmg / Enrage) and
--   the boss's health through DungeonRuns (solo stand-in) / PartyRuns (party spec): Hp.
-- BOUNTY BOARD (from level UNLOCK_BOUNTIES 12): COUNT bounties a week (Roll), bigger than the daily contracts, fed by the
-- SAME events (CombatServer.ContractEvent: "Kill", "WeakKill", "FloorClear", "Streak", "BoonPick", "Daily", "Rift",
-- "Trial", + "Encounter" (Vault Lock) and "BossTrial"). Each pays on its own; all of them pay a bonus. REROLLS a week to
-- swap an unfinished one.
-- State: Weekly = { Week = n, Bounties = { { Id, Target, Progress, Done } }, BonusPaid, BossDone, Rerolls (used) } (saved).
-- A week starts Monday 00:00 UTC.
-- ============================================================================================
local Weekly = {}

Weekly.ON = true
Weekly.UNLOCK_BOUNTIES = 12
Weekly.UNLOCK_BOSS = 22 -- (2026-10-22, owner: "move quarry to 22" -- level 18 opened four things at once)
Weekly.COUNT = 5
Weekly.REROLLS = 1 -- (a week; mastery rank adds more: ExtraRerolls)
function Weekly.ExtraRerolls(state: any): number
    return require(script.Parent:WaitForChild("MasteryRank")).ExtraRerolls(type(state) == "table" and state.MasteryRank or 0)
        + ((type(state) == "table" and type(state.GuildPerks) == "table" and state.GuildPerks.Rerolls) or 0) -- (UPDATE 7 B9: guild research)
end

-- the week number (Monday 00:00 UTC) and the seconds left in it
function Weekly.Week(t: number?): number
    return ((t or os.time()) // 86400 + 3) // 7
end
function Weekly.SecondsLeft(t: number?): number
    local now = t or os.time()
    return (Weekly.Week(now) + 1) * 7 * 86400 - 3 * 86400 - now
end

-- ---------- the boss ----------
Weekly.Mods = {
    IRONHIDE = { Name = "IRONHIDE", Text = "The boss has 40% more health.", Hp = 1.4 },
    OVERCLOCKED = { Name = "OVERCLOCKED", Text = "The boss attacks 15% faster.", Pace = 0.85 },
    HEAVY_HANDS = { Name = "HEAVY HANDS", Text = "The boss hits 30% harder.", Dmg = 1.3 },
    SHORT_FUSE = { Name = "SHORT FUSE", Text = "The boss enrages after 2.5 minutes, not 4.", Enrage = 150 }, -- (0.99u: 240 of 420 -> 150 of 240)
    -- (UPDATE 7 C1 APEX HUNT: never rolled as the week's twist -- not in ModOrder)
    APEX = { Name = "THE SUMMIT", Text = "120% more health, hits 25% harder, attacks 15% faster.", Hp = 2.2, Dmg = 1.25, Pace = 0.85 },
    UBER_APEX = { Name = "SUMMIT UNBOUND", Text = "250% more health, hits 50% harder, attacks 25% faster, enrages at 3.5 minutes.", Hp = 3.5, Dmg = 1.5, Pace = 0.75, Enrage = 210 }, -- (0.99u: 300 of 420 -> 210 of 240)
}
Weekly.ModOrder = { "IRONHIDE", "OVERCLOCKED", "HEAVY_HANDS", "SHORT_FUSE" }

local function Trials()
    return require(script.Parent:WaitForChild("BossTrials"))
end

-- this week's boss (a BossTrials.Bosses entry) and modifier id; the step 5 walks all 8 bosses before repeating
function Weekly.BossOf(week: number?): any
    local list = Trials().Bosses
    local w = week or Weekly.Week()
    return list[((w * Weekly.Step(#list, 5)) % #list) + 1]
end
-- (FUTURE-PROOF 2026-10-25) the walk's step: `want` if it shares no factor with n (every entry comes up before a repeat), else the
-- next number that doesn't -- a step of 5 over 10 bosses only ever showed 2 of them. Today's counts keep today's step.
function Weekly.Step(n: number, want: number): number
    local function Gcd(a: number, b: number): number while b ~= 0 do a, b = b, a % b end return a end
    if n <= 1 then return 1 end
    local s = want
    while Gcd(s, n) ~= 1 do s += 1 end
    return s
end
function Weekly.ModOf(week: number?): string
    -- (Studio test hook: workspace attr DevWeeklyMod = a Mods id forces this week's modifier)
    local dev = game:GetService("RunService"):IsStudio() and workspace:GetAttribute("DevWeeklyMod")
    if not week and type(dev) == "string" and Weekly.Mods[dev] then return dev end
    local w = week or Weekly.Week()
    return Weekly.ModOrder[((w * Weekly.Step(#Weekly.ModOrder, 3)) % #Weekly.ModOrder) + 1]
end

-- the tier you fight it at: the hardest tier whose difficulty your level has reached (tier I = Hard, level 8)
function Weekly.TierFor(level: number?): number
    local BT = Trials()
    local ItemData = require(script.Parent:WaitForChild("ItemData"))
    local best = 1
    for t, def in ipairs(BT.Tiers) do
        if (level or 1) >= (ItemData.DifficultyMinLevel[def.Difficulty] or 1) then best = t end
    end
    return best
end

-- the weekly stack (first clear of the week): gold + Prism that grow with level, 2 of every currency you've unlocked, an
-- item of the tier's top two rarities
function Weekly.Reward(level: number?): any
    local lv = level or 1
    return { Gold = math.round(2000 * (1 + lv / 20)), Prism = math.round(15 * (1 + lv / 25)), EachCurrency = 2, Item = "Top2", Riftmod = true }
end

-- ---------- the bounty board ----------
-- (FUTURE-PROOF 2026-10-25: ItemData.DifficultyRank, read lazily -- the hand copy gave a NEW tier rank 1, so "Brutal or harder"
-- jobs didn't count it)
local DIFF_RANK = setmetatable({}, { __index = function(_, k)
    return require(script.Parent:WaitForChild("ItemData")).DifficultyRank[k]
end })
Weekly.Defs = {
    KILLS = { Text = "Defeat %d enemies", Target = 500, Event = "Kill", Weight = 10 },
    ELITES = { Text = "Defeat %d elite enemies", Target = 40, Event = "Kill", Match = function(c) return c.Elite == true end, Weight = 8 },
    BOSSES = { Text = "Defeat %d bosses", Target = 8, Event = "Kill", Match = function(c) return c.Boss == true end, Weight = 8 },
    WEAK = { Text = "Finish %d enemies with a weak-spot hit", Target = 200, Event = "WeakKill", Weight = 9 },
    FLOORS = { Text = "Clear %d dungeon floors", Target = 20, -- (UPDATE 8 packs: floor jobs ~1/3 lower)
        Event = "FloorClear", Weight = 10 },
    BRUTAL_FLOORS = { Text = "Clear %d floors on Brutal or harder", Target = 13, Event = "FloorClear", MinLevel = 18,
        Match = function(c) return (DIFF_RANK[c.Difficulty] or 1) >= 4 end, Weight = 8 },
    NO_HIT = { Text = "Clear %d floors without taking a heavy hit", Target = 3, Event = "FloorClear", Match = function(c) return c.NoHit == true end, Weight = 6 },
    STREAK = { Text = "Reach a Focus streak of %d", Target = 40, Event = "Streak", Value = "max", Weight = 6 },
    BOONS = { Text = "Pick %d run boons", Target = 25, Event = "BoonPick", Weight = 0 }, -- (UPDATE 8: boons are cut -- Weight 0, def kept for old saves)
    RARE_ELITES = { Text = "Defeat %d Rare (yellow) elites", Target = 20, Event = "Kill", Match = function(c) return c.RareElite == true end, Weight = 5 }, -- (UPDATE 8)
    GOBLINS = { Text = "Catch %d loot goblins", Target = 3, Event = "Kill", Match = function(c) return c.Goblin == true end, Weight = 0 }, -- (2026-10-22: goblins are 1 in 100 floors -- out of the pool; def kept for old saves)
    VAULTS = { Text = "Crack %d Tumblers", Target = 3, Event = "Encounter", MinLevel = 8, Match = function(c) return c.Id == "VAULT_LOCK" end, Weight = 8 },
    CLEAN_VAULT = { Text = "Crack %d Tumbler without a reset", Target = 1, Event = "Encounter", MinLevel = 8,
        Match = function(c) return c.Id == "VAULT_LOCK" and c.Clean == true end, Weight = 5 },
    MARKS = { Text = "Catch %d Runners", Target = 2, Event = "Encounter", MinLevel = 18, Match = function(c) return c.Id == "BOUNTY_MARK" end, Weight = 6 },
    TEARS = { Text = "Close %d Breaches", Target = 2, Event = "Encounter", MinLevel = 30, Match = function(c) return c.Id == "RIFT_TEAR" end, Weight = 6 },
    ECHOES = { Text = "Win %d Mirror Matches", Target = 2, Event = "Encounter", MinLevel = 45, Match = function(c) return c.Id == "ECHO_DUEL" end, Weight = 6 },
    ENCOUNTERS = { Text = "Finish %d floor encounters", Target = 6, Event = "Encounter", MinLevel = 18, Weight = 6 },
    TRIALS = { Text = "Clear %d Boss Trials", Target = 3, Event = "BossTrial", MinLevel = 8, Weight = 6 },
    WEEKLY_BOSS = { Text = "Defeat this week's boss (%d)", Target = 1, Event = "BossTrial", MinLevel = 22,
        Match = function(c) return c.Weekly == true end, Weight = 7 },
    DAILY = { Text = "Clear the Daily Challenge %d times", Target = 3, Event = "Daily", Weight = 5 },
    MAPS = { Text = "Beat %d maps within their time limit", Target = 3, Event = "Rift", MinLevel = 100, Match = function(c) return c.InTime == true end, Weight = 7 },
    AIM_GOLD = { Text = "Reach Gold rank in %d Aim Trial runs", Target = 3, Event = "Trial", Match = function(c) return (c.Rank or 0) >= 3 end, Weight = 5 },
}

-- one bounty's pay (gold + Prism by level, + one currency you've unlocked, picked by the server); all of them: the bonus
function Weekly.BountyReward(level: number?): any
    local lv = level or 1
    return { Gold = math.round(1500 * (1 + lv / 40)), Prism = math.round(5 * (1 + lv / 50)), Currency = 1 }
end
function Weekly.BonusReward(level: number?): any
    local lv = level or 1
    return { Gold = math.round(4000 * (1 + lv / 40)), Prism = math.round(12 * (1 + lv / 50)), EachCurrency = 1, Item = "Top3" }
end

local function Pool(level: number?, exclude: { [string]: boolean }?): { string }
    local ids = {}
    for id, d in pairs(Weekly.Defs) do
        if (level or 1) >= (d.MinLevel or 1) and (d.Weight or 0) > 0 and not (exclude and exclude[id]) then table.insert(ids, id) end
    end
    table.sort(ids)
    return ids
end
local function Pick(r: Random, ids: { string }): string?
    local total = 0
    for _, id in ipairs(ids) do total += Weekly.Defs[id].Weight end
    if total <= 0 then return nil end
    local roll = r:NextNumber() * total
    for _, id in ipairs(ids) do
        roll -= Weekly.Defs[id].Weight
        if roll <= 0 then return id end
    end
    return ids[#ids]
end
local function Entry(id: string): any
    return { Id = id, Target = Weekly.Defs[id].Target, Progress = 0, Done = false }
end

-- the week's bounties for a player (deterministic per player, week and level band)
function Weekly.Roll(userId: number, week: number, level: number?): { any }
    local r = Random.new((userId % 100000) * 7919 + week)
    local out, used = {}, {}
    for _ = 1, Weekly.COUNT do
        local id = Pick(r, Pool(level, used))
        if not id then break end
        used[id] = true
        table.insert(out, Entry(id))
    end
    return out
end

-- swap bounty i (unfinished) for one not on the list; returns the new entry or nil
function Weekly.Reroll(list: { any }, i: number, level: number?): any
    local c = list[i]
    if not c or c.Done then return nil end
    local used = {}
    for _, x in ipairs(list) do used[x.Id] = true end
    local id = Pick(Random.new(), Pool(level, used))
    if not id then return nil end
    list[i] = Entry(id)
    return list[i]
end

function Weekly.Text(c: any): string
    local def = Weekly.Defs[c and c.Id or ""]
    if not def then return tostring(c and c.Id) end
    return string.format(def.Text, c.Target)
end

-- one event onto the list; returns the bounties that just finished (same rules as Contracts.Apply)
function Weekly.Apply(list: { any }, event: string, amount: number?, ctx: any?): { any }
    local finished = {}
    for _, c in ipairs(list) do
        local def = Weekly.Defs[c.Id]
        if def and not c.Done and def.Event == event and (not def.Match or def.Match(ctx or {})) then
            if def.Value == "max" then
                c.Progress = math.max(c.Progress, math.min(c.Target, amount or 0))
            else
                c.Progress = math.min(c.Target, c.Progress + (amount or 1))
            end
            if c.Progress >= c.Target then
                c.Done = true
                table.insert(finished, c)
            end
        end
    end
    return finished
end

-- "3d 4h" / "5h 12m"
function Weekly.LeftText(secs: number?): string
    local s = math.max(0, math.floor(secs or Weekly.SecondsLeft()))
    local d, h, m = s // 86400, (s % 86400) // 3600, (s % 3600) // 60
    if d > 0 then return string.format("%dd %dh", d, h) end
    return string.format("%dh %02dm", h, m)
end

return Weekly
