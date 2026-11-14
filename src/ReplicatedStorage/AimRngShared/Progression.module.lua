--!nocheck
-- ============================================================================================
-- LONG-TERM PROGRESSION (account-style systems from Diablo / Borderlands):
--   WEAPON MASTERY  every gun model (BaseId) levels 0-10 from kills made with it
--                   (StatsTracking.WeaponKills[BaseId]). Each level: +2% damage with that gun; level 5 also
--                   +10% weak-spot damage, level 10 also +15% crit damage and the gun's "Mastered" badge.
--   (PARAGON removed 2026-10-13, owner: raising the level cap is the long-term progression. Saved Paragon tables stay
--   in the save, unused.)
-- StatCalculator reads mastery from the `progress` argument (the player state).
-- ============================================================================================
local Progression = {}

-- ----- Weapon mastery -----
Progression.MasteryKills = { 50, 150, 400, 900, 1800, 3500, 6000, 10000, 16000, 25000 } -- kills for level 1..10
Progression.MASTERY_DAMAGE_PER_LEVEL = 0.02

function Progression.MasteryLevel(kills: number?): number
    local k = kills or 0
    local lvl = 0
    for i, need in ipairs(Progression.MasteryKills) do
        if k >= need then lvl = i else break end
    end
    return lvl
end

-- Kills toward the next level: (have, need) for a progress bar (need = nil at max).
-- (UPDATE 8) a fodder (pack) kill counts this much toward weapon mastery (CombatServer GiveKillRewards); kill counts can be
-- fractional now -- shown rounded down
Progression.FODDER_MASTERY = 0.2
function Progression.MasteryProgress(kills: number?): (number, number?)
    local k = math.floor(kills or 0)
    local lvl = Progression.MasteryLevel(k)
    local need = Progression.MasteryKills[lvl + 1]
    return k, need
end

-- The stat bonus of a mastery level (stat -> value).
function Progression.MasteryStats(level: number): { [string]: number }
    local out = {}
    if level <= 0 then return out end
    out.IncreasedDamage = level * Progression.MASTERY_DAMAGE_PER_LEVEL
    if level >= 5 then out.WeakSpotMultiplier = 0.10 end
    if level >= 10 then out.CritMultiplier = 0.15 end
    return out
end

-- Everything long-term progression adds for this weapon + state (used by StatCalculator).
function Progression.StatsFor(state: any, weapon: any): { [string]: number }
    local out = {}
    if type(state) ~= "table" then return out end
    local kills = weapon and state.StatsTracking and state.StatsTracking.WeaponKills and state.StatsTracking.WeaponKills[weapon.BaseId]
    for k, v in pairs(Progression.MasteryStats(Progression.MasteryLevel(kills))) do out[k] = (out[k] or 0) + v end
    -- (UPDATE 7 B2) the gun model's claimed calibration perks
    if weapon and weapon.BaseId then
        for k, v in pairs(require(script.Parent:WaitForChild("Calibration")).StatsFor(state, weapon.BaseId)) do out[k] = (out[k] or 0) + v end
    end
    return out
end

return Progression
