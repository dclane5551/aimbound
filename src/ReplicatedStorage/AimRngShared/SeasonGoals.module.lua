--!nocheck
-- ============================================================================================
-- SEASON GOALS (UPDATE 7 C8, seasonal challenges; placeholder name): ~30 big goals per season (Seasons.Current.Id) that run
-- across everything in the game -- kills, encounters, maps, the Apex, districts, Riftmods... Each counts the same game events as
-- contracts (CombatServer.ContractEvent -> SeasonGoalEvent; a few systems call SeasonGoalEvent directly). Finishing 10 / 20 / 30
-- of them pays a milestone (MILESTONES: a season title (no stats), BOUND points, gold; the 30 milestone also grants the
-- season's EXCLUSIVE cosmetic refs in MILESTONE_COSMETICS once they exist). Progress resets with the season.
-- State: SeasonGoals = { Id, Prog = { [goalId] = n }, Done = { [goalId] = true }, Paid = { ["10"] = true, ... } }
-- ============================================================================================
local SeasonGoals = {}

SeasonGoals.ON = true
SeasonGoals.COLOR = Color3.fromRGB(255, 140, 200)
SeasonGoals.MILESTONES = {
    { Need = 10, Title = "S1Goal10", BP = 300, Gold = 50000 },
    { Need = 20, Title = "S1Goal20", BP = 500, Gold = 150000 },
    { Need = 30, Title = "S1Goal30", BP = 1000, Gold = 400000 },
}
SeasonGoals.MILESTONE_COSMETICS = { [30] = {} } -- (the season's exclusive piece(s), "Category:Id"; empty = shown as "coming soon")

-- the season's goals: Value "max" keeps the best value, else amounts add up; MinLevel is shown as a hint
SeasonGoals.List = {
    { Id = "KILLS", Text = "Defeat %d enemies", Target = 5000, Event = "Kill" },
    { Id = "WEAK", Text = "Finish %d enemies with a weak-spot hit", Target = 1500, Event = "WeakKill" },
    { Id = "ELITES", Text = "Defeat %d elites", Target = 300, Event = "Kill", Match = function(c) return c.Elite == true end },
    { Id = "BOSSES", Text = "Defeat %d bosses", Target = 60, Event = "Kill", Match = function(c) return c.Boss == true end },
    { Id = "GOBLINS", Text = "Catch %d loot goblin", Target = 1, Event = "Kill", Match = function(c) return c.Goblin == true end }, -- (2026-10-22: 1 in 100 floors now; was 10)
    { Id = "FLOORS", Text = "Clear %d floors", Target = 165, -- (UPDATE 8 packs: floor goals ~1/3 lower)
      Event = "FloorClear" },
    { Id = "NOHIT", Text = "Clear %d floors without taking a heavy hit", Target = 17, Event = "FloorClear", Match = function(c) return c.NoHit == true end },
    { Id = "FAST", Text = "Clear %d floors in under 60 seconds", Target = 17, Event = "FloorClear", Match = function(c) return (c.Elapsed or 999) < 60 end },
    { Id = "STREAK", Text = "Reach a Focus streak of %d", Target = 60, Event = "Streak", Value = "max" },
    { Id = "RARE_ELITES", Text = "Defeat %d Rare (yellow) elites", Target = 150, Event = "Kill", Match = function(c) return c.RareElite == true end }, -- (UPDATE 8: was "Pick 100 run boons")
    { Id = "DAILY", Text = "Clear the Daily Challenge %d times", Target = 10, Event = "Daily" },
    { Id = "AIM_GOLD", Text = "Reach Gold rank in %d Aim Trial runs", Target = 10, Event = "Trial", Match = function(c) return (c.Rank or 0) >= 3 end },
    { Id = "VAULTS", Text = "Crack %d Tumblers", Target = 10, Event = "Encounter", MinLevel = 8, Match = function(c) return c.Id == "VAULT_LOCK" end },
    { Id = "MARKS", Text = "Catch %d Runners", Target = 10, Event = "Encounter", MinLevel = 18, Match = function(c) return c.Id == "BOUNTY_MARK" end },
    { Id = "TEARS", Text = "Close %d Breaches", Target = 10, Event = "Encounter", MinLevel = 30, Match = function(c) return c.Id == "RIFT_TEAR" end },
    { Id = "ECHOES", Text = "Win %d Mirror Matches", Target = 10, Event = "Encounter", MinLevel = 45, Match = function(c) return c.Id == "ECHO_DUEL" end },
    { Id = "TRIALS", Text = "Clear %d Boss Trials", Target = 20, Event = "BossTrial", MinLevel = 8 },
    { Id = "WEEKLY", Text = "Bring down %d Week's Quarries", Target = 4, Event = "BossTrial", MinLevel = 22, Match = function(c) return c.Weekly == true end },
    { Id = "MASTERY", Text = "Reach Marksman Grade %d", Target = 8, Event = "MasteryRank", MinLevel = 15, Value = "max" },
    { Id = "RIFTMODS", Text = "Find %d Gunwrights", Target = 5, Event = "Riftmod", MinLevel = 45 },
    { Id = "CALIBRATE", Text = "Claim %d zeroing tiers", Target = 5, Event = "Calibration", MinLevel = 65 },
    { Id = "DISTRICT", Text = "Finish %d quarter bounties", Target = 20, Event = "District", MinLevel = 65 },
    { Id = "CONTRACT", Text = "Bring down your Marked Man %d times", Target = 3, Event = "ContractKill", MinLevel = 80 },
    { Id = "SPOILS", Text = "Spend %d Haul Tags with a party", Target = 5, Event = "Spoils", MinLevel = 80 },
    { Id = "MAPS", Text = "Beat %d maps within their time", Target = 25, Event = "Rift", MinLevel = 100, Match = function(c) return c.InTime == true end },
    { Id = "LINE", Text = "Clear the Gauntlet Run %d times", Target = 7, Event = "Line", MinLevel = 100 },
    { Id = "INKED", Text = "Draw %d Sigil Marks", Target = 10, Event = "MapInk", MinLevel = 100 },
    { Id = "APEX", Text = "Conquer the Summit %d time", Target = 1, Event = "Apex", MinLevel = 125 },
    { Id = "OVERCHARGE", Text = "Redline %d items", Target = 10, Event = "Overcharge", MinLevel = 125 },
    { Id = "ENCOUNTERS", Text = "Finish %d floor encounters", Target = 60, Event = "Encounter", MinLevel = 8 },
}
SeasonGoals.ById = {}
for _, g in ipairs(SeasonGoals.List) do SeasonGoals.ById[g.Id] = g end

function SeasonGoals.SeasonId(): string
    return require(script.Parent:WaitForChild("Seasons")).Current.Id
end

function SeasonGoals.Ensure(state: any): any
    local s = type(state.SeasonGoals) == "table" and state.SeasonGoals or nil
    if not s or s.Id ~= SeasonGoals.SeasonId() then
        s = { Id = SeasonGoals.SeasonId(), Prog = {}, Done = {}, Paid = {} }
        state.SeasonGoals = s
    end
    s.Prog = type(s.Prog) == "table" and s.Prog or {}
    s.Done = type(s.Done) == "table" and s.Done or {}
    s.Paid = type(s.Paid) == "table" and s.Paid or {}
    return s
end

function SeasonGoals.DoneCount(s: any): number
    local n = 0
    for _ in pairs(type(s) == "table" and s.Done or {}) do n += 1 end
    return n
end

-- one event onto the goals; returns the ids that just finished
function SeasonGoals.Apply(s: any, event: string, amount: number?, ctx: any?): { string }
    local finished = {}
    for _, g in ipairs(SeasonGoals.List) do
        if g.Event == event and not s.Done[g.Id] and (not g.Match or g.Match(ctx or {})) then
            local cur = tonumber(s.Prog[g.Id]) or 0
            if g.Value == "max" then cur = math.max(cur, amount or 0) else cur += (amount or 1) end
            cur = math.min(cur, g.Target)
            s.Prog[g.Id] = cur
            if cur >= g.Target then s.Done[g.Id] = true; table.insert(finished, g.Id) end
        end
    end
    return finished
end

function SeasonGoals.Text(g: any): string
    return string.format(g.Text, g.Target)
end

return SeasonGoals
