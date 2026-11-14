--!nocheck
-- ============================================================================================
-- AIM TRIALS (Kovaak's / Aim Lab scenarios): short, pure aim challenges played in a private room. Score
-- ranks Bronze -> Grandmaster per scenario; reaching a rank the first time pays a reward, and every day has
-- a leaderboard per scenario. Played with ONE universal trial weapon (FireRate per scenario, no recoil, no spread,
-- a single exact ray per shot) so every score on a board is comparable (playtester 2026-10-02: "Aim Trials need
-- universal weapons for consistent leaderboards"). Unlimited ammo.
-- Client: TrialRunner runs the scenario and reports (scenarioId, score, hits, shots); server: EndgameServer
-- sanity-checks the score (MaxScore, duration since start) and records it.
-- ============================================================================================
local AimTrials = {}

AimTrials.Scenarios = {
    -- (0.93, owner: "Aim trials are still really bad, bots dont even make sense and the hitreg feels super off"): Flick /
    -- Tracking / Switch use hovering trial bots (body + head weak spot) that move like the dungeon bots; the fire rates went
    -- up (a click inside the cooldown is dropped -- at 3.5-4.5 shots/s fast clicking lost shots and felt like missed hits)
    { Id = "GRIDSHOT", Name = "Gridshot", Duration = 30, FireRate = 8, Color = Color3.fromRGB(255, 120, 60),
        Text = "3 targets on the wall. Hit one, another appears. Speed AND accuracy: misses cost points.",
        MaxScore = 40000, Ranks = { 4000, 8000, 12000, 16000, 20000, 25000 } },
    { Id = "FLICK", Name = "Flick", Duration = 40, FireRate = 7, Color = Color3.fromRGB(90, 200, 255),
        Text = "One bot at a time, anywhere in front of you, near or far. Kill it fast: faster = more points, headshots +25%.",
        MaxScore = 40000, Ranks = { 1500, 3000, 4500, 6000, 7500, 9000 } },
    { Id = "TRACKING", Name = "Tracking", Duration = 30, FireRate = 10, Color = Color3.fromRGB(120, 255, 140),
        Text = "A ball floats through the air in front of you, curving smoothly in every direction and bouncing off the edges. Keep your shots on it. Score = hits, accuracy bonus.",
        MaxScore = 20000, Ranks = { 1500, 3000, 4500, 6500, 8500, 11000 } },
    { Id = "SWITCH", Name = "Target Switch", Duration = 35, FireRate = 8, Color = Color3.fromRGB(255, 200, 70),
        Text = "3 bots strafe in their own lanes, near to far. 3 hits each (a headshot counts double); a new one takes its lane. Score = kills and speed.",
        MaxScore = 25000, Ranks = { 1200, 2500, 3800, 5000, 6500, 8000 } },
}
AimTrials.ById = {}
for _, s in ipairs(AimTrials.Scenarios) do AimTrials.ById[s.Id] = s end

-- Difficulty: smaller / faster targets for a bigger score multiplier (ranks and leaderboards use the final,
-- multiplied score, so harder runs climb faster).
AimTrials.Difficulties = {
    { Id = "Rookie", Size = 1.3, Speed = 0.75, Life = 1.4, Mult = 0.6, Color = Color3.fromRGB(120, 220, 120) },
    { Id = "Standard", Size = 1.0, Speed = 1.0, Life = 1.0, Mult = 1.0, Color = Color3.fromRGB(80, 170, 255) },
    { Id = "Expert", Size = 0.78, Speed = 1.3, Life = 0.8, Mult = 1.5, Color = Color3.fromRGB(255, 160, 50) },
    { Id = "Insane", Size = 0.58, Speed = 1.65, Life = 0.62, Mult = 2.2, Color = Color3.fromRGB(255, 70, 90) },
}
AimTrials.DifficultyById = {}
for _, d in ipairs(AimTrials.Difficulties) do AimTrials.DifficultyById[d.Id] = d end

-- Every finished run pays a little (gold + Scrap by score); only the first RUN_REWARDS_PER_DAY runs a day pay.
AimTrials.RUN_REWARDS_PER_DAY = 8
function AimTrials.RunReward(score: number): any
    return { Gold = math.min(800, math.floor(score / 25)), Scrap = math.min(10, math.floor(score / 2500)) }
end

AimTrials.RankNames = { "Bronze", "Silver", "Gold", "Platinum", "Diamond", "Grandmaster" }
AimTrials.RankColors = {
    Bronze = Color3.fromRGB(205, 127, 50), Silver = Color3.fromRGB(200, 205, 215), Gold = Color3.fromRGB(255, 205, 60),
    Platinum = Color3.fromRGB(110, 230, 220), Diamond = Color3.fromRGB(120, 170, 255), Grandmaster = Color3.fromRGB(255, 80, 120),
}
-- First time reaching a rank in a scenario: gold + materials (+ a gem at Diamond / Grandmaster).
AimTrials.RankRewards = {
    Bronze = { Gold = 150, Mats = { Scrap = 5 } },
    Silver = { Gold = 300, Mats = { Scrap = 8, Alloy = 2 } },
    Gold = { Gold = 500, Mats = { Alloy = 4 } },
    Platinum = { Gold = 800, Mats = { Alloy = 6, Prism = 1 } },
    Diamond = { Gold = 1200, Mats = { Prism = 3 }, Gem = "Rare" },
    Grandmaster = { Gold = 2000, Mats = { Prism = 5 }, Gem = "Epic" },
}

-- Rank index 0..6 for a score.
function AimTrials.RankOf(scenarioId: string, score: number): number
    local s = AimTrials.ById[scenarioId]
    if not s then return 0 end
    local r = 0
    for i, need in ipairs(s.Ranks) do
        if score >= need then r = i end
    end
    return r
end

function AimTrials.RankName(idx: number): string?
    return AimTrials.RankNames[idx]
end

return AimTrials
