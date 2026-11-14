--!nocheck
-- ============================================================================================
-- DAILY CONTRACTS: 3 personal challenges per UTC day (same 3 all day, new ones at midnight UTC), paid out
-- automatically when finished; finishing all 3 pays a bonus (a Rare+ skill gem + Prism Shards).
-- State: Contracts = { Day = n, List = { { Id, Target, Progress, Done } }, BonusPaid = bool } (saved).
-- Server events (CombatServer.ContractEvent): "Kill" {Elite, Boss, Goblin}, "WeakKill", "FloorClear"
-- (UPDATE 8 packs: floor-count jobs about a third lower -- a pack floor takes ~1.5x as long)
-- {Difficulty, Mods, Elapsed, NoHit}, "Streak" (value), "BoonPick".
-- ============================================================================================
local Contracts = {}

-- (FUTURE-PROOF 2026-10-25: ItemData.DifficultyRank, read lazily -- the hand copy gave a NEW tier rank 1, so "Brutal or harder"
-- jobs didn't count it)
local DIFF_RANK = setmetatable({}, { __index = function(_, k)
    return require(script.Parent:WaitForChild("ItemData")).DifficultyRank[k]
end })

-- Event / Match(ctx) = does this event count; Value = "max" means progress = best value seen.
Contracts.Defs = {
    KILLS = { Text = "Defeat %d enemies", Target = 80, Event = "Kill", Weight = 10 },
    WEAK_KILLS = { Text = "Finish %d enemies with a weak-spot hit", Target = 30, Event = "WeakKill", Weight = 10 },
    ELITES = { Text = "Defeat %d elite enemies", Target = 8, Event = "Kill", Match = function(c) return c.Elite == true end, Weight = 8, Tier = 2 },
    BOSS = { Text = "Defeat %d boss", Target = 1, Event = "Kill", Match = function(c) return c.Boss == true end, Weight = 6, Tier = 3 },
    FLOORS = { Text = "Clear %d dungeon floors", Target = 4, Event = "FloorClear", Weight = 10 },
    NORMAL_FLOORS = { Text = "Clear %d floors on Normal or harder", Target = 3, Event = "FloorClear", Match = function(c) return (DIFF_RANK[c.Difficulty] or 1) >= 2 end, Weight = 7, Tier = 2 },
    MOD_FLOORS = { Text = "Clear %d floors that have a floor modifier", Target = 1, Event = "FloorClear", Match = function(c) return (c.Mods or "") ~= "" end, Weight = 6, Tier = 3 },
    NO_HIT = { Text = "Clear %d floor without taking a heavy hit", Target = 1, Event = "FloorClear", Match = function(c) return c.NoHit == true end, Weight = 6, Tier = 3 },
    FAST = { Text = "Clear %d floor in under 60 seconds", Target = 1, Event = "FloorClear", Match = function(c) return (c.Elapsed or 999) < 60 end, Weight = 6, Tier = 3 },
    STREAK = { Text = "Reach a Focus streak of %d", Target = 20, Event = "Streak", Value = "max", Weight = 7, Tier = 2 },
    BOONS = { Text = "Pick %d run boons", Target = 5, Event = "BoonPick", Weight = 0, Tier = 2 }, -- (UPDATE 8: boons are cut -- Weight 0, def kept for old saves)
    RARE_ELITES = { Text = "Defeat %d Rare (yellow) elites", Target = 3, Event = "Kill", Match = function(c) return c.RareElite == true end, Weight = 6, Tier = 2 }, -- (UPDATE 8)
    GOBLIN = { Text = "Catch %d loot goblin", Target = 1, Event = "Kill", Match = function(c) return c.Goblin == true end, Weight = 0, Tier = 3 }, -- (2026-10-22: goblins are 1 in 100 floors now -- out of the daily pool; Weight 0 = never rolled, the def stays for old saves)
    DAILY = { Text = "Clear the Daily Challenge %d time", Target = 1, Event = "Daily", Weight = 6, Tier = 2 },
    RIFT = { Text = "Beat %d rift within its time limit", Target = 1, Event = "Rift", Match = function(c) return c.InTime == true end, Weight = 5, Tier = 3 },
    TRIAL_GOLD = { Text = "Reach Gold rank in %d Aim Trial run", Target = 1, Event = "Trial", Match = function(c) return (c.Rank or 0) >= 3 end, Weight = 6, Tier = 3 },
}
Contracts.COUNT = 3
-- Per finished contract, by its Tier (1 = easy, 2 = medium, 3 = hard; raw, not scaled by difficulty). Item = the
-- least rarity of the item it drops (your level, at your feet in a run / straight into the bag in the hub).
-- (owner 2026-10-05: "Add daily contract rewards" -- every contract now shows what it pays, and the harder ones pay
-- an item too.)
Contracts.Rewards = {
    [1] = { Gold = 300, Mats = { Scrap = 8, Alloy = 3 }, Chances = { Prism = 0.3 } },
    [2] = { Gold = 450, Mats = { Scrap = 10, Alloy = 5 }, Chances = { Prism = 0.6 }, Item = "Rare" },
    [3] = { Gold = 650, Mats = { Scrap = 12, Alloy = 6, Prism = 1 }, Chances = { Prism = 0.9 }, Item = "Rare" }, -- (UPDATE 8 RARITY v4: was Epic)
}
Contracts.Reward = Contracts.Rewards[1] -- (old name)
-- (LOOT SCARCITY 2026-11-07: the tier-2 contract's item = ItemData.LOOT_SCARCITY.ContractItem2 -- "Uncommon"; tier 3 keeps its Rare)
do
    local ok, ID = pcall(function() return require(script.Parent:WaitForChild("ItemData")) end)
    if ok and ID.LOOT_SCARCITY and ID.LOOT_SCARCITY.ON and ID.LOOT_SCARCITY.ContractItem2 then Contracts.Rewards[2].Item = ID.LOOT_SCARCITY.ContractItem2 end
end
-- All three done: a Rare+ skill gem, Prism Shards and an Epic-or-better item (15% Legendary).
Contracts.BonusMats = { Prism = 2 }
Contracts.BonusItem = "Rare" -- (UPDATE 8 RARITY v4: a Rare-or-better item; was Epic)
Contracts.BonusLegendaryChance = 0.02 -- (RARITY v4: the chance it's a Mythic instead -- only where Mythics drop; was 15% Legendary)

function Contracts.RewardOf(c: any): any
    local def = Contracts.Defs[c and c.Id or ""]
    return Contracts.Rewards[def and def.Tier or 1] or Contracts.Rewards[1]
end
-- "+450 gold, Rare item"
function Contracts.RewardText(c: any): string
    local r = Contracts.RewardOf(c)
    return string.format("+%d gold%s", r.Gold, r.Item and (", " .. r.Item .. " item") or ", materials")
end

function Contracts.Today(): number
    return os.time() // 86400
end

-- The day's contracts for a player (deterministic per player and day; count = COUNT + mastery-rank slots, UPDATE 7).
function Contracts.Roll(userId: number, day: number, count: number?): { any }
    local r = Random.new((userId % 100000) * 100000 + day)
    local ids = {}
    for id, d in pairs(Contracts.Defs) do if (d.Weight or 0) > 0 then table.insert(ids, id) end end
    table.sort(ids)
    local out = {}
    for _ = 1, math.min(count or Contracts.COUNT, #ids) do
        local total = 0
        for _, id in ipairs(ids) do total += Contracts.Defs[id].Weight end
        local roll = r:NextNumber() * total
        local pick = ids[#ids]
        for _, id in ipairs(ids) do
            roll -= Contracts.Defs[id].Weight
            if roll <= 0 then pick = id; break end
        end
        table.insert(out, { Id = pick, Target = Contracts.Defs[pick].Target, Progress = 0, Done = false })
        table.remove(ids, table.find(ids, pick))
    end
    return out
end

function Contracts.Text(c: any): string
    local def = Contracts.Defs[c.Id]
    if not def then return c.Id end
    return string.format(def.Text, c.Target)
end

-- Apply one event to a contract list; returns the contracts that just finished.
function Contracts.Apply(list: { any }, event: string, amount: number?, ctx: any?): { any }
    local finished = {}
    for _, c in ipairs(list) do
        local def = Contracts.Defs[c.Id]
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

return Contracts
