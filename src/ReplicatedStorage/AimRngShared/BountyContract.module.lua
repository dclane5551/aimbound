--!nocheck
-- ============================================================================================
-- BOUNTY CONTRACT (UPDATE 7, the owner-approved replacement for a "nemesis": vault Loot Economy Plan section 11 + 12 -- "a
-- named elite marked on you for one week, appears in your runs, flees when hurt, and gets harder each escape. No memory or
-- hierarchy; it resets weekly. Reward: its gun"). Placeholder name. NOT a nemesis system: nothing is remembered about you,
-- there are no ranks or followers, and the whole contract is replaced every Monday.
--
-- From level UNLOCK, each week rolls ONE contract per player (Ensure): a name, an epithet and the GUN it carries. On an
-- eligible solo floor (APPEAR chance; floor 2+, not boss / trial / map / daily floors) it joins the fight as an extra elite
-- (gold skull + its name; it doesn't count toward clearing the floor). The first hit starts a FLEE_TIME s clock: not dead by
-- then (or the floor clears / you leave with it alive) = it ESCAPES, +1 Escapes = more health next time (HP_PER_ESCAPE) and a better gun. Killed: its gun
-- drops for you + gold; done for the week.
-- State: BountyContract = { Week, Name, Gun, Escapes, Done } (saved). Server: DungeonRuns (spawn / flee) + CombatServer
-- (the kill: CombatServer.ContractKill).
-- ============================================================================================
local BountyContract = {}

BountyContract.ON = true
BountyContract.UNLOCK = 80
BountyContract.APPEAR = 0.3
BountyContract.FLEE_TIME = 6
BountyContract.HP = 4 -- (x an ordinary bot's health)
BountyContract.HP_PER_ESCAPE = 0.35
BountyContract.MAX_ESCAPES = 4

local FIRST = { "Vask", "Morrow", "Kesh", "Ilse", "Dray", "Okon", "Teva", "Rook", "Sable", "Corin", "Nyx", "Halden", "Brisa", "Quill", "Vey", "Tamsin" }
local EPITHET = { "the Quick", "the Unseen", "the Gilded", "Twice-Shot", "the Cold", "the Last Light", "No-Shadow", "the Patient",
    "the Lucky", "Ironjaw", "the Smiling", "Half-Mask", "the Long Fuse", "the Saint", "Ninefold", "the Rust Crown" }

local function ID() return require(script.Parent:WaitForChild("ItemData")) end

-- this week's contract for a player (rolled once per week, only from UNLOCK); nil before the unlock
function BountyContract.Ensure(state: any, userId: number): any
    if not BountyContract.ON or type(state) ~= "table" or (state.Level or 1) < BountyContract.UNLOCK then return nil end
    local week = require(script.Parent:WaitForChild("Weekly")).Week()
    local c = state.BountyContract
    if type(c) ~= "table" or c.Week ~= week then
        local r = Random.new((userId % 100000) * 104729 + week)
        local I = ID()
        c = { Week = week, Name = FIRST[r:NextInteger(1, #FIRST)] .. " " .. EPITHET[r:NextInteger(1, #EPITHET)],
            Gun = I.Lineup[r:NextInteger(1, #I.Lineup)], Escapes = 0, Done = false }
        state.BountyContract = c
    end
    return c
end

-- the target's health multiplier and the gun's rarity rank for a difficulty (more escapes = tougher + better gun)
function BountyContract.HpMult(c: any): number
    return BountyContract.HP * (1 + BountyContract.HP_PER_ESCAPE * math.min(BountyContract.MAX_ESCAPES, c and c.Escapes or 0))
end
function BountyContract.GunRarity(c: any, difficulty: string?): string
    local I = ID()
    -- (UPDATE 8 RARITY v4: a Rare; after 2 escapes a Mythic where Mythics drop)
    local top = I.MaxRarityRank(difficulty)
    local rank = math.min(top, I.RarityRank.Rare + (((c and c.Escapes or 0) >= 2) and 1 or 0))
    return I.Rarities[rank]
end
function BountyContract.Gold(c: any, level: number?): number
    return math.round(5000 * (1 + (level or 1) / 40) * (1 + 0.5 * math.min(BountyContract.MAX_ESCAPES, c and c.Escapes or 0)))
end

return BountyContract
