--!nocheck
-- ============================================================================================
-- APEX HUNT (UPDATE 7 C1, the vault's "pinnacle boss + fragments" renamed in Loot Economy Plan section 11; placeholder):
-- from level UNLOCK, map guardians drop COORDINATES (four kinds: North / East / South / West; COORD_CHANCE each guardian,
-- a sure one with the Ink of the Compass). One of each reveals where the APEX hides: at the map device, TRACK THE APEX uses
-- the set and starts the fight -- a major boss at the hardest trial tier your level reaches, with the APEX modifier (more
-- health, harder hits, a faster pace; Weekly.Mods.APEX). From UBER_LEVEL the UBER APEX takes two of each (Weekly.Mods.UBER_APEX).
-- The Apex pays big (ApexHunt.Reward): gold, Prism, Rift Taint (the Overcharge currency), top-rarity items, an exotic chance,
-- and a show-off title on the first kill of each. Guardians also drop Rift Taint (TAINT_CHANCE).
-- Server: EndgameServer.StartBossTrial(..., apex) + BossTrialFinished (trial.Apex) -> CombatServer.PayApex; remote ApexAction.
-- ============================================================================================
local ApexHunt = {}

ApexHunt.ON = true
ApexHunt.UNLOCK = 125
ApexHunt.UBER_LEVEL = 158
ApexHunt.COORD_CHANCE = 0.25
ApexHunt.TAINT_CHANCE = 0.15
ApexHunt.COLOR = Color3.fromRGB(255, 120, 160)
ApexHunt.COORDS = { "CoordNorth", "CoordEast", "CoordSouth", "CoordWest" }
ApexHunt.BOSSES = { "Lockwarden", "Broodmother", "Duelist", "FortuneEngine" } -- (the major bosses: their own mechanics, at Apex strength)
ApexHunt.TITLE = { Apex = "ApexHunter", Uber = "UberApexHunter" }

-- how many of each Coordinate a hunt needs
function ApexHunt.Need(uber: boolean?): number return uber and 2 or 1 end

-- can this state start a hunt? (ok, why)
function ApexHunt.CanStart(state: any, uber: boolean?): (boolean, string?)
    if not ApexHunt.ON then return false, "The Summit is off." end
    local lvl = type(state) == "table" and state.Level or 1
    if lvl < ApexHunt.UNLOCK then return false, "The Summit opens at level " .. ApexHunt.UNLOCK .. "." end
    if uber and lvl < ApexHunt.UBER_LEVEL then return false, "The Summit Unbound opens at level " .. ApexHunt.UBER_LEVEL .. "." end
    local mats = type(state) == "table" and state.Materials or {}
    local need = ApexHunt.Need(uber)
    local missing = {}
    for _, k in ipairs(ApexHunt.COORDS) do
        if (mats[k] or 0) < need then table.insert(missing, (string.gsub(k, "Coord", ""))) end
    end
    if #missing > 0 then return false, "Missing " .. (need > 1 and (need .. " of each: ") or "") .. table.concat(missing, ", ") .. " Bearing" .. (#missing > 1 and "s" or "") .. "." end
    return true
end

-- the reward table for a kill (PayApex spends it)
function ApexHunt.Reward(level: number?, uber: boolean?): any
    local k = uber and 2.5 or 1
    return {
        Gold = math.round(60000 * (1 + (level or 1) / 40) * k),
        Prism = math.round(30 * k),
        Taint = uber and 4 or 2,
        Items = uber and 5 or 3, -- (TopN: the tier's top two rarities)
        Exotic = uber and 0.5 or 0.25,
    }
end

return ApexHunt
