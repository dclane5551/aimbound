--!nocheck
-- ============================================================================================
-- CALIBRATION (UPDATE 7 B2, the vault's "Awakening" renamed in Loot Economy Plan section 11; placeholder name): every gun
-- MODEL (BaseId) has 5 calibration tiers. Each tier is earned by an AIM FEAT done with that gun model (weak-spot kills,
-- weak-spot hits in a row, elite kills, hits without a miss), then claimed for gold + an encounter currency (a sink), and
-- each claimed tier is a CHOICE of two sideways perks (moving vs planted, long vs close range ...). Switching a claimed
-- tier's pick costs a little gold. Whole set ~ +5-10% with that gun (the class passive scale), never a straight upgrade.
-- From level UNLOCK. State: Calibration = { [BaseId] = { T = tiers claimed 0..5, P = progress on the next feat, C = { pick
-- per tier 1 | 2 } } } (saved). Feats are counted on the server (CombatServer.CalibrationFeat); the perks reach the gun
-- through Progression.StatsFor -> StatCalculator (the tree layer, under its ceilings).
-- ============================================================================================
local Calibration = {}

Calibration.ON = true
Calibration.UNLOCK = 65
Calibration.MAX = 5
Calibration.COLOR = Color3.fromRGB(120, 220, 210)
Calibration.SWITCH_SHARE = 0.25 -- (switching a pick costs this share of the tier's gold)

-- Feat kinds: WeakKills / EliteKills add up; HsRun (weak-spot hits in a row) / HitRun (hits in a row, no miss) keep the best run.
Calibration.TIERS = {
    { Feat = "WeakKills", Need = 150, Text = "Get %d weak-spot kills", Key = "Graft", Keys = 2,
        Choices = {
            { Id = "MOVING", Name = "Run and Gun", Stats = { MovingDamage = 0.08 }, Desc = "+8% damage while moving" },
            { Id = "STILL", Name = "Planted", Stats = { StillDamage = 0.08 }, Desc = "+8% damage while standing still" },
        } },
    { Feat = "HsRun", Need = 12, Text = "Land %d weak-spot hits in a row", Key = "StripShard", Keys = 2,
        Choices = {
            { Id = "WEAK", Name = "Fine Sight", Stats = { WeakSpotMultiplier = 0.08 }, Desc = "+8% weak-spot damage" },
            { Id = "CRIT", Name = "Hair Trigger", Stats = { CritChance = 0.03 }, Desc = "+3% crit chance" },
        } },
    { Feat = "EliteKills", Need = 30, Text = "Kill %d elites", Key = "Temper", Keys = 2,
        Choices = {
            { Id = "RELOAD", Name = "Quick Hands", Stats = { ReloadSpeedBonus = 0.12 }, Desc = "+12% reload speed" },
            { Id = "MAG", Name = "Deep Mag", Stats = { MagSizeBonus = 0.12 }, Desc = "+12% magazine size" },
        } },
    { Feat = "HitRun", Need = 60, Text = "Land %d hits in a row without a miss", Key = "ShiftShard", Keys = 3,
        Choices = {
            { Id = "LONG", Name = "Long Sight", Stats = { LongRangeDamage = 0.10 }, Desc = "+10% damage at long range" },
            { Id = "CLOSE", Name = "Close Work", Stats = { CloseRangeDamage = 0.10 }, Desc = "+10% damage at close range" },
        } },
    { Feat = "HsRun", Need = 25, Text = "Land %d weak-spot hits in a row", Key = "StormCore", Keys = 1,
        Choices = {
            { Id = "RELOADED", Name = "Fresh Load", Stats = { ReloadedDamage = 0.12 }, Desc = "+12% damage for 3 s after a reload" },
            { Id = "FULLMAG", Name = "Full Chamber", Stats = { FreshMagDamage = 0.12 }, Desc = "+12% damage while the magazine is over 70% full" },
        } },
}
Calibration.RUN_FEAT = { HsRun = true, HitRun = true }
Calibration.NUMERALS = { "I", "II", "III", "IV", "V" }

function Calibration.Unlocked(state: any): boolean
    return Calibration.ON and type(state) == "table" and (state.Level or 1) >= Calibration.UNLOCK
end

-- the record for a gun model (nil-safe read; Ensure = create)
function Calibration.Of(state: any, gun: string?): any
    local all = type(state) == "table" and state.Calibration
    local c = type(all) == "table" and gun and all[gun]
    return type(c) == "table" and c or nil
end
function Calibration.Ensure(state: any, gun: string): any
    state.Calibration = type(state.Calibration) == "table" and state.Calibration or {}
    local c = state.Calibration[gun]
    if type(c) ~= "table" then c = { T = 0, P = 0, C = {} }; state.Calibration[gun] = c end
    c.T = math.clamp(math.floor(tonumber(c.T) or 0), 0, Calibration.MAX)
    c.P = tonumber(c.P) or 0
    c.C = type(c.C) == "table" and c.C or {}
    return c
end

-- the feat text for tier t
function Calibration.FeatText(t: number): string
    local d = Calibration.TIERS[t]
    return d and string.format(d.Text, d.Need) or ""
end

-- the claim cost of tier t at a level: gold + the tier's currency
function Calibration.Cost(t: number, level: number?): (number, string, number)
    local d = Calibration.TIERS[t]
    local gold = math.round(20000 * t * (1 + (level or 1) / 50) / 100) * 100
    return gold, d and d.Key or "Graft", d and d.Keys or 1
end
function Calibration.SwitchCost(t: number, level: number?): number
    local gold = Calibration.Cost(t, level)
    return math.round(gold * Calibration.SWITCH_SHARE / 100) * 100
end

-- ready to claim the next tier?
function Calibration.Ready(c: any): boolean
    if not c or (c.T or 0) >= Calibration.MAX then return false end
    local d = Calibration.TIERS[(c.T or 0) + 1]
    return (c.P or 0) >= d.Need
end

-- the pick on tier t (1 | 2; saves may hold string keys after a JSON round trip)
function Calibration.PickOf(c: any, t: number): number
    if not c or type(c.C) ~= "table" then return 1 end
    local v = tonumber(c.C[t]) or tonumber(c.C[tostring(t)]) or 1
    return (v == 2) and 2 or 1
end

-- the perks of a gun model for this player (stat -> value)
function Calibration.StatsFor(state: any, gun: string?): { [string]: number }
    local out = {}
    if not Calibration.Unlocked(state) then return out end
    local c = Calibration.Of(state, gun)
    if not c then return out end
    for t = 1, math.min(Calibration.MAX, tonumber(c.T) or 0) do
        local d = Calibration.TIERS[t]
        local pick = d and d.Choices[Calibration.PickOf(c, t)]
        if pick then for k, v in pairs(pick.Stats) do out[k] = (out[k] or 0) + v end end
    end
    return out
end

return Calibration
