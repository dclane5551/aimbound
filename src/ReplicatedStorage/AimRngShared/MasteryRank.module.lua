--!nocheck
-- ============================================================================================
-- MASTERY RANK (UPDATE 7 "DEPTH" A3; vault "UPDATE 7 - Depth" -> "Mastery rank perks"; the name is a placeholder until
-- the owner picks one -- Loot Economy Plan section 11 suggests "Marksman Grade").
--
-- POINTS = the sum of every lineup gun's weapon mastery level (Progression: 0-10 from kills with it). Enough points open
-- the next RANK, but a rank is only taken by passing its EXAM: an Aim Trial run (any difficulty; ranks use the final,
-- multiplied score) on the exam's scenario reaching its trial rank (Bronze for ranks 1-5, Silver 6-10, Gold 11-15,
-- Platinum 16-20). No timers and no cooldowns: retry as often as you like (owner: "shouldnt be time-gated").
-- PERKS are sideways only (owner-approved list, never damage / defence / loot luck): bag slots, weekly bounty rerolls,
-- daily contract slots, an early look at next week's boss, the rank emblem on your name tag and show-off titles.
-- State: MasteryRank = n (saved). Exams are judged in EndgameServer's SubmitTrial (CombatServer.MasteryExam).
-- ============================================================================================
local MasteryRank = {}

MasteryRank.ON = true
MasteryRank.UNLOCK = 15 -- (level: exams open; points count from the start)
MasteryRank.POINTS = { 4, 10, 18, 28, 40, 54, 70, 88, 108, 130, 154, 180, 208, 238, 270, 304, 340, 378, 418, 460 } -- points for rank n
MasteryRank.MAX = #MasteryRank.POINTS
MasteryRank.EXAM_ORDER = { "FLICK", "TRACKING", "SWITCH", "GRIDSHOT" }
MasteryRank.Color = Color3.fromRGB(110, 230, 170)

-- the perks, by the rank that gives them (Text is what the window shows)
MasteryRank.Perks = {
    [1] = { "Your rank emblem on your name tag" },
    [2] = { "+5 bag slots" },
    [3] = { "+1 weekly bounty reroll" },
    [4] = { "+5 bag slots", "+1 Loot Lens rule" },
    [5] = { "Title: CADET" },
    [6] = { "+5 bag slots", "See next week's Quarry early" },
    [7] = { "+1 daily contract" },
    [8] = { "+5 bag slots" },
    [9] = { "+1 weekly bounty reroll" },
    [10] = { "+5 bag slots", "Title: SHARPSHOOTER" },
    [11] = { "+1 Loot Lens rule" },
    [12] = { "+5 bag slots" },
    [13] = { "+2 Exchange listings, -2% Exchange tax" },
    [14] = { "+5 bag slots", "+1 daily contract" },
    [15] = { "+1 weekly bounty reroll", "Title: DEADEYE" },
    [16] = { "+5 bag slots" },
    [17] = { "+1 Loot Lens rule" },
    [18] = { "+5 bag slots" },
    [19] = { "+2 Exchange listings, -2% Exchange tax" },
    [20] = { "+5 bag slots", "Title: PARAGON OF AIM" },
}

local function Prog()
    return require(script.Parent:WaitForChild("Progression"))
end

function MasteryRank.Rank(state: any): number
    return math.clamp(math.floor(tonumber(type(state) == "table" and state.MasteryRank) or 0), 0, MasteryRank.MAX)
end

-- mastery points: every lineup gun's mastery level
function MasteryRank.Points(state: any): number
    local ItemData = require(script.Parent:WaitForChild("ItemData"))
    local kills = type(state) == "table" and state.StatsTracking and state.StatsTracking.WeaponKills or {}
    local P = Prog()
    local n = 0
    for _, id in ipairs(ItemData.Lineup) do n += P.MasteryLevel(kills[id]) end
    return n
end

-- the exam for rank r: { Scenario, Need (AimTrials rank index), NeedName }
function MasteryRank.Exam(r: number): any
    local need = math.clamp(math.ceil(r / 5), 1, 6)
    local AimTrials = require(script.Parent:WaitForChild("AimTrials"))
    return { Scenario = MasteryRank.EXAM_ORDER[((r - 1) % #MasteryRank.EXAM_ORDER) + 1], Need = need, NeedName = AimTrials.RankNames[need] }
end

-- can the next rank's exam be taken now? (ok, why)
function MasteryRank.CanExam(state: any): (boolean, string?)
    if not MasteryRank.ON then return false, "Marksman Grade is off." end
    local r = MasteryRank.Rank(state)
    if r >= MasteryRank.MAX then return false, "You're at the top rank." end
    if ((type(state) == "table" and state.Level) or 1) < MasteryRank.UNLOCK then return false, "Rank exams open at level " .. MasteryRank.UNLOCK .. "." end
    local need = MasteryRank.POINTS[r + 1]
    local have = MasteryRank.Points(state)
    if have < need then return false, string.format("%d / %d mastery points for grade %d.", have, need, r + 1) end
    return true
end

-- perk totals at a rank
local function CountPerk(rank: number, word: string): number
    local n = 0
    for r, list in pairs(MasteryRank.Perks) do
        if r <= rank then for _, t in ipairs(list) do if string.find(t, word, 1, true) then n += 1 end end end
    end
    return n
end
-- (ItemData.BagCap keeps its own copy of this rule -- 5 slots every 2 ranks -- so ItemData never requires this module)
function MasteryRank.BagBonus(rank: number?): number return 5 * CountPerk(rank or 0, "bag slots") end
function MasteryRank.ExtraRerolls(rank: number?): number return CountPerk(rank or 0, "bounty reroll") end
function MasteryRank.ExtraContracts(rank: number?): number return CountPerk(rank or 0, "daily contract") end
function MasteryRank.SeesNextWeek(rank: number?): boolean return CountPerk(rank or 0, "next week") > 0 end
function MasteryRank.ExtraDropRules(rank: number?): number return CountPerk(rank or 0, "Loot Lens rule") end -- (UPDATE 7 C9)
function MasteryRank.ExtraListingPerks(rank: number?): number return CountPerk(rank or 0, "Exchange listings") end -- (UPDATE 7 C7)

-- "R12" for name tags
function MasteryRank.Emblem(rank: number?): string?
    if (rank or 0) <= 0 then return nil end
    return "R" .. rank
end

return MasteryRank
