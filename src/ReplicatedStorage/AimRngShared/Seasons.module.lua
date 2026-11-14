--!nocheck
-- ============================================================================================
-- SEASON JOURNEY (free season pass: Diablo 4 / Fortnite style). A season runs for a few weeks. Everything you
-- do earns Season XP (kills, floors, contracts, the Daily Challenge, rifts, Aim Trial ranks, logging in);
-- every tier (each costs a little more than the last: Seasons.TierCost) is a reward you claim in Challenges > SEASON. Tier 25 and 50 grant
-- season-exclusive titles. When a new season starts, everyone's season progress starts over (gear, levels
-- and everything else are kept).
-- PREMIUM TRACK (2026-10-02): a Robux pass (Seasons.Premium) unlocks a second reward row on every tier
-- (Seasons.PremiumReward: more gold / materials / gems / sigils, two cosmetic-only titles, BOUND points on every tier
-- (~700 over the season: the pass pays for itself), and at tier 50 the season's arms + knife) and +25% Season XP.
-- Bought any time in the season; every tier already reached can be claimed on the premium row at once.
-- State: Season = { Id, XP, Claimed = { [tierString] = true }, Premium = bool, ClaimedP = { [tierString] = true } }
-- ============================================================================================
local Seasons = {}

Seasons.Current = {
    Id = "S1",
    Name = "Season 1: Open Fire",
    -- (2026-10-22: was 13 Nov 2026 -- the game hasn't launched yet, so a fixed date three weeks out would end the pass as players
    -- arrive. PLACEHOLDER 31 Jan 2027 until the owner picks a launch day; then set it ~6 weeks after launch, the pace the tiers
    -- were tuned for.)
    Ends = DateTime.fromUniversalTime(2027, 1, 31, 0, 0, 0).UnixTimestamp,
}
Seasons.TIERS = 50
-- (SEASON PASS REWORK 2026-10-13, owner: "we dont want players to get it super fast, it should feel slow but rewarding to get
-- levels"; retune same day: "tier 50 at about 40 hours"): tiers COST MORE AS YOU GO -- tier t costs TIER_BASE + TIER_STEP x
-- (t - 1) Season XP (tier 1 = 2,100 .. tier 50 = 6,167; 206,675 in all). Measured 2026-10-13 (Studio, real kill pipeline):
-- a 5-floor Normal run = 482 Season XP (a floor 58, a boss floor 150) in ~12 min of real play (the leveling model's 4.4
-- kills / min + walking) = ~2,400 / h of runs, plus per play day the login 200 + contracts ~1,000 + the daily 800 (~2,000
-- a day). An average player playing 40 h over the 6-week season (~35 play days) earns ~166k free / ~207k premium (+25%)
-- -> premium finishes at ~40 h, free reaches ~tier 43 at 40 h (tier 50 at ~50 h). Before the rework: a flat 1,000 a tier =
-- 50,000 in all (tier 50 in ~11-14 h); the first rework pass 2,500 + 105 (253,625: premium ~50-55 h).
Seasons.TIER_BASE = 2100
Seasons.TIER_STEP = 83
Seasons.XP_PER_TIER = Seasons.TIER_BASE -- (old name; the cost of tier 1 -- use Seasons.TierCost / Seasons.Progress)

-- Season XP per action (CombatServer.AddSeasonXP callers use these keys).
Seasons.XP = {
    Kill = 2, EliteKill = 10, BossKill = 100, FloorClear = 50, Contract = 300, ContractsAll = 500,
    Daily = 250, DailyFirst = 800, RiftBase = 200, RiftPerTier = 40, TrialRank = 150, Login = 200,
}

-- the premium pass: Robux price + developer product (0 = not on sale yet; Studio grants it free)
Seasons.Premium = { Price = 499, RobuxPrice = 499, ProductId = 3716099635, XPBonus = 0.25 } -- (Price = BOUND points; RobuxPrice = the dev product's)
-- THE SEASON'S FINAL REWARD (premium only, tier 50): a list of "Category:Id" refs (Cosmetics) -- the season arms (a Glove +
-- a Sleeve) and a knife (MeleeSkin). Empty = "coming soon" (the window shows a placeholder until the ids are filled in).
Seasons.PremiumSkins = {
    [50] = {
        "Glove:TorchbearerGauntlets", "Sleeve:TorchbearerSleeves", "MeleeSkin:Torchbearer", -- (skinsB: the TORCHBEARER champion set)
    },
}
Seasons.SKIN_TIERS = { [50] = true }
-- BOUND points on the premium row: the pass pays back MORE than its R$ 499 (owner: ~700 BP over the season, 1 BP ~ 1 R$)
-- 5 on every ordinary tier, 30 on 5 / 15 / 25 / 35 / 45, 70 on the old skin tiers 10 / 20 / 30 / 40, 70 on tier 50 = 700
Seasons.PREMIUM_BP = { Base = 5, Five = 30, Ten = 70, Final = 70 }
-- the free row gets a taste: 10 on 10 / 20 / 30 / 40 and 30 on tier 50 = 70
Seasons.FREE_BP = { Ten = 10, Final = 30 }

local TITLE_NAMES = { S1Contender = "Season 1 Contender", S1Champion = "Season 1 Champion", S1Elite = "S1 Elite", S1Apex = "S1 Apex" }
local function Describe(r: any): string
    local parts = {}
    if r.Cosmetics then table.insert(parts, "SEASON ARMS + KNIFE") elseif r.SkinSlot then table.insert(parts, "Season arms + knife (coming soon)") end
    if r.BP then table.insert(parts, r.BP .. " BOUND points") end
    if r.Gold then table.insert(parts, r.Gold .. " gold") end
    if r.Mats.Alloy then table.insert(parts, r.Mats.Alloy .. " Alloy") end
    if r.Mats.Prism then table.insert(parts, r.Mats.Prism .. " Prism") end
    if r.Mats.ReforgeToken then table.insert(parts, r.Mats.ReforgeToken .. " Reforge Token" .. (r.Mats.ReforgeToken == 1 and "" or "s")) end
    if r.Mats.TuningKit then table.insert(parts, r.Mats.TuningKit .. " Tuning Kit" .. (r.Mats.TuningKit == 1 and "" or "s")) end
    if r.Sigil then table.insert(parts, "Tier " .. r.Sigil .. " Rift Sigil") end
    if r.Gem then table.insert(parts, r.Gem .. " skill gem") end
    if r.Title then table.insert(parts, "TITLE: " .. (TITLE_NAMES[r.Title] or r.Title)) end
    return table.concat(parts, ", ")
end

-- the final reward's refs (a list, maybe empty)
function Seasons.FinalRefs(): { string }
    local v = Seasons.PremiumSkins[Seasons.TIERS]
    if type(v) == "string" then return { v } end
    return type(v) == "table" and v or {}
end

-- Premium reward of a tier (same shape as Reward, plus Cosmetics = { "Cat:Id", ... } / SkinSlot = true on the final tier)
function Seasons.PremiumReward(tier: number): any
    local r = { Gold = 200 + tier * 15, Mats = {} }
    if tier % 5 == 0 then r.Mats = { Alloy = 4 + tier // 10, Prism = 2 + tier // 15 } end
    if tier % 10 == 8 then r.Mats.Prism = (r.Mats.Prism or 0) + 2 end -- (0.97: was 2 Reforge Tokens)
    if tier == 12 or tier == 32 then r.Mats.Prism = (r.Mats.Prism or 0) + 1 end -- (0.97: was a Tuning Kit)
    if tier == 5 or tier == 25 or tier == 45 then r.Sigil = tier // 20 + 1 end -- (0.61 map ladder: Tier 1 / 2 / 3)
    if tier == 15 or tier == 35 then r.Gem = "Legendary" end
    local B = Seasons.PREMIUM_BP
    r.BP = (tier == Seasons.TIERS and B.Final) or (tier % 10 == 0 and B.Ten) or (tier % 5 == 0 and B.Five) or B.Base
    if tier == 1 then r.Title = "S1Elite" end
    if tier == Seasons.TIERS then
        r.Title = "S1Apex"; r.Mats = { Prism = 22 }
        local refs = Seasons.FinalRefs()
        if #refs > 0 then r.Cosmetics = refs else r.SkinSlot = true end
    end
    r.Text = Describe(r)
    return r
end

-- Reward of a tier (the free row): { Text, Gold, Mats, BP?, Sigil?, Gem?, Title? } -- something on every tier: gold always,
-- Alloy on the even tiers, a Prism on x3 / x7, a material bundle every 5th, a sigil every 10th, gems, BOUND points on the 10s
function Seasons.Reward(tier: number): any
    local r = { Gold = 150 + tier * 12, Mats = {} }
    if tier % 5 == 0 then
        r.Mats = { Alloy = 3 + tier // 10, Prism = 1 + tier // 20 }
    elseif tier % 2 == 0 then
        r.Mats = { Alloy = 1 + tier // 25 }
    elseif tier % 10 == 3 or tier % 10 == 7 then
        r.Mats = { Prism = 1 }
    end
    if tier == 10 or tier == 20 or tier == 30 or tier == 40 then r.Sigil = math.min(3, tier // 10) end -- (0.61 map ladder: Tier 1 / 2 / 3 / 3)
    if tier == 15 then r.Gem = "Rare" end
    if tier == 25 or tier == 35 then r.Gem = "Epic" end
    if tier == 45 then r.Gem = "Legendary" end
    if tier % 10 == 0 then r.BP = (tier == Seasons.TIERS) and Seasons.FREE_BP.Final or Seasons.FREE_BP.Ten end
    if tier == 25 then r.Title = "S1Contender" end
    if tier == Seasons.TIERS then r.Gem = "Legendary"; r.Title = "S1Champion"; r.Mats = { Prism = 15 } end
    r.Text = Describe(r)
    return r
end

-- Season XP a tier costs, the total to reach it, and the tier / progress of an XP total
function Seasons.TierCost(tier: number): number
    return Seasons.TIER_BASE + Seasons.TIER_STEP * (math.max(1, tier) - 1)
end
function Seasons.XPForTier(tier: number): number
    tier = math.clamp(math.floor(tier), 0, Seasons.TIERS)
    return Seasons.TIER_BASE * tier + Seasons.TIER_STEP * tier * (tier - 1) // 2
end
function Seasons.TierOf(xp: number?): number
    xp = xp or 0
    local t = 0
    while t < Seasons.TIERS and xp >= Seasons.XPForTier(t + 1) do t += 1 end
    return t
end
-- (tier, XP into the next tier, that tier's cost, fraction 0..1)
function Seasons.Progress(xp: number?): (number, number, number, number)
    local t = Seasons.TierOf(xp)
    if t >= Seasons.TIERS then return t, 0, 0, 1 end
    local into = (xp or 0) - Seasons.XPForTier(t)
    local cost = Seasons.TierCost(t + 1)
    return t, into, cost, math.clamp(into / cost, 0, 1)
end

function Seasons.Active(): boolean
    return os.time() < Seasons.Current.Ends
end

-- The player's season record for the current season (resets when the season id changes).
function Seasons.Ensure(state: any): any
    local s = state.Season
    if type(s) ~= "table" or s.Id ~= Seasons.Current.Id then
        s = { Id = Seasons.Current.Id, XP = 0, Claimed = {} }
        state.Season = s
    end
    s.Claimed = type(s.Claimed) == "table" and s.Claimed or {}
    s.ClaimedP = type(s.ClaimedP) == "table" and s.ClaimedP or {}
    return s
end

return Seasons
