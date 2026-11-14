--!nocheck
-- ============================================================================================
-- TRIAL OF ASCENSION (2026-10-05, owner: "revamp how they get their ascendancy points. Right now its through the bosses,
-- but I dont think I like that ... make a seperate trial of ascension. This would include 2 hard normal floors, and then a
-- special boss fight at the end"; picked: 4 trials x 2 points).
-- Four escalating trials, unlocked by level (35 / 100 / 200 / 305 since 0.93). Each run = two HARD floors (an elite pack on every floor) then THE ASCENDANT,
-- a boss built only for the trial (DungeonGenerator.CreateAscendant, BossAI KITS / SIG.Ascendant). The FIRST clear of each
-- tier gives 2 ascendancy points (max 8 = all four); later clears pay gold + a guaranteed item. Solo or a party room (the
-- host starts it; the boss has x2 / x3 / x4 health for 2 / 3 / 4 players).
-- State: state.AscTrialBest = highest tier cleared (0-4). AscendancyData.PointsFor reads it.
-- Flow: Challenges > ASCENSION > START -> remote StartAscTrial(tier) (EndgameServer) -> DungeonRuns floor 1 with
-- config.AscTrial = { Tier } (party: PartyRuns.Start with the same) -> floor 3 = boss arena -> AscTrialFinished.
-- ============================================================================================
local AscensionTrials = {}

AscensionTrials.FLOORS = 3 -- two hard floors + the boss
AscensionTrials.POINTS_PER_TIER = 2
AscensionTrials.HARD_MODS = { "ELITE_PACK" } -- what makes the first two floors "hard"
-- (0.93, owner: "Ascension runs are outdated level wise, scale them properly"): the four trials were spread over levels
-- 15-75 (Hard..Cataclysm) from before the level-400 / Singularity ladder, so every point was done in the first hours. Now
-- they span the whole game, each just past the level its difficulty opens (ItemData.DifficultyMinLevel): Nightmare 30,
-- Ruin 98, Annihilation 198, Singularity 303. Pace = the Boss Trials' pace at the same difficulty; Item = one step under
-- the difficulty's top rarity as luck ("Top1", 0.99n: a named rarity is a promise now); GoldK = the late Boss Trial tiers' gold scaling.
-- Old characters keep the points they already earned (state.AscTrialBest is untouched).
AscensionTrials.Tiers = {
    { Name = "I", Level = 35, Difficulty = "Nightmare", Hp = 1.0, Pace = 0.9, Item = "Top1", GoldK = 1 },
    { Name = "II", Level = 100, Difficulty = "Ruin", Hp = 1.03, Pace = 0.75, Item = "Top1", GoldK = 1.7 },
    { Name = "III", Level = 200, Difficulty = "Annihilation", Hp = 1.06, Pace = 0.69, Item = "Top1", GoldK = 3.1 },
    { Name = "IV", Level = 305, Difficulty = "Singularity", Hp = 1.1, Pace = 0.66, Item = "Top1", GoldK = 4.5 },
}
AscensionTrials.MAX_TIER = #AscensionTrials.Tiers
AscensionTrials.BOSS_NAME = "THE ASCENDANT"
AscensionTrials.Color = Color3.fromRGB(60, 240, 210)
AscensionTrials.Mechanics = {
    "TRIAL OF PRECISION: its ward shrugs off damage. Small sigils whirl round it: break them all to drop the ward.",
    "TRIAL OF NERVE (phase 2): one quarter of the arena is sanctified. Fight from inside it, and be in it when judgement falls.",
    "FINAL ASCENSION (phase 3): faster sigils, and near the end it starts to ascend. Kill it before it gets there.",
}

function AscensionTrials.Best(state: any): number
    local b = type(state) == "table" and state.AscTrialBest
    return (type(b) == "number") and math.clamp(math.floor(b), 0, AscensionTrials.MAX_TIER) or 0
end
-- can this player start tier t? (level + the tier before cleared)
function AscensionTrials.CanStart(state: any, t: number): (boolean, string?)
    local def = AscensionTrials.Tiers[t]
    if not def then return false, "Unknown trial." end
    if (state and state.Level or 1) < def.Level then return false, string.format("Reach level %d first.", def.Level) end
    if AscensionTrials.Best(state) < t - 1 then return false, "Clear Trial " .. AscensionTrials.Tiers[t - 1].Name .. " first." end
    return true
end
function AscensionTrials.Reward(tier: number, first: boolean): any
    local t = AscensionTrials.Tiers[tier]
    return { Gold = math.round((2000 + 1500 * tier + (first and 2500 * tier or 0)) * (t.GoldK or 1)), Prism = tier * 2 + (first and 3 or 0), Item = t.Item }
end

return AscensionTrials
