--!nocheck
-- LOADOUT SCORE (QOL2 I4 2026-10-28): EQUIP BEST's one score per loadout, shared by the server (CombatServer's EquipBest) and the
-- client (the gear upgrade signal: "+x% vs equipped" on a gear loot card + the up arrow on gear bag rows). Moved here from
-- CombatServer unchanged (EQUIP BEST v2, owner 2026-10-05): offence^0.75 x toughness^0.25 (Tank: the other way round),
-- toughness = StatCalculator.Toughness at the difficulty; Burn / Freeze / Bleed / Decay weight DPS by how reliably and how
-- hard you apply that ailment; Crit by crit chance x multiplier.
local Shared = script.Parent
local ItemData = require(Shared:WaitForChild("ItemData"))
local StatCalculator = require(Shared:WaitForChild("StatCalculator"))

local LoadoutScore = {}

LoadoutScore.ELEMENT = {
    Burn = { Cond = "BurnOnHit", Stat = "BurnDamage" }, Freeze = { Cond = "ChillOnHit", Stat = "FreezeEffect" },
    Bleed = { Cond = "BleedOnHit", Stat = "BleedDamage" }, Decay = { Cond = "DecayOnHit", Stat = "DecayEffect" },
}
-- the client's EQUIP BEST build preset (the dropdown sets it), for the client-side signals
LoadoutScore.Mode = "DPS"

function LoadoutScore.AilmentChance(mode: string, weapon: any, s: any): number
    local el = LoadoutScore.ELEMENT[mode]
    if not el then return 0 end
    local c = (s.Cond or {})[el.Cond] or 0
    if weapon and weapon.Proc and weapon.Proc.Id == mode then c += ItemData.ProcChance(weapon, s.AilmentChance or 0) end
    return c
end

-- state = a player state (server state or the client's clientState), weapon + gear = the loadout to score
function LoadoutScore.Score(state: any, weapon: any, gear: any, mode: string?, difficulty: string?): number
    local s = StatCalculator.Calculate(weapon, state.AllocatedNodes, 0, state.Level, state.Attributes, gear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
    local dps = s.Damage * s.FireRate * math.max(1, s.PelletCount or 1) * math.max(1, s.BurstCount or 1) * (1 + s.CritChance * (s.CritMultiplier - 1))
    local ehp = StatCalculator.Toughness(s, difficulty)
    local off = dps
    if mode == "Crit" then off = dps * (0.5 + s.CritChance) * s.CritMultiplier end
    local el = LoadoutScore.ELEMENT[mode or ""]
    if el then
        local chance = math.min(1, LoadoutScore.AilmentChance(mode :: string, weapon, s))
        local power = 1 + (s[el.Stat] or 0) + (s.AilmentDuration or 0)
        off = dps * (0.25 + chance * power * 4)
    end
    off, ehp = math.max(off, 1e-6), math.max(ehp, 1e-6)
    if mode == "Tank" then return ehp ^ 0.75 * off ^ 0.25 end
    return off ^ 0.75 * ehp ^ 0.25
end

-- GEAR GAIN: how much the build score changes if this gear piece replaces what you wear in its slot (rings: the better of the
-- two ring slots). Returns (fraction, equippedItem?) -- 0.05 = +5% -- or nil when it can't say (no gun, not gear, worn).
-- Cached per (loadout, tree, level, mode, difficulty) so a bag of 60 rows costs one Calculate per piece, once.
local cache, cacheSig = {}, nil
local function Sig(state: any, mode: string, diff: string): string
    local t = { mode, diff, tostring(state.Level), tostring(state.AllocatedNodes), tostring(state.SocketedGems), tostring(state.Attributes),
        tostring(state.EquippedTitle), tostring(state.RunBoons), tostring(state.EquippedWeapon and state.EquippedWeapon.Uid) }
    for _, slot in ipairs(ItemData.GEAR_EQUIP_SLOTS) do
        local g = (state.EquippedGear or {})[slot]
        table.insert(t, type(g) == "table" and tostring(g.Uid) or "-")
    end
    return table.concat(t, "|")
end
function LoadoutScore.GearGain(state: any, item: any, mode: string?, difficulty: string?): (number?, any?)
    if type(state) ~= "table" or type(item) ~= "table" or not item.Slot or not state.EquippedWeapon then return nil end
    mode = mode or LoadoutScore.Mode or "DPS"
    difficulty = difficulty or state.DungeonDifficulty or "Easy"
    local eq = state.EquippedGear or {}
    local gType = ItemData.GearType(item.Slot)
    local slots = (gType == "Ring") and { "Ring1", "Ring2" } or { gType }
    for _, sl in ipairs(slots) do if type(eq[sl]) == "table" and eq[sl].Uid == item.Uid then return nil end end
    local sig = Sig(state, mode :: string, difficulty :: string)
    if sig ~= cacheSig then cache, cacheSig = {}, sig end
    local key = tostring(item.Uid) .. "#" .. tostring(item)
    local hit = cache[key]
    if hit then return hit[1], hit[2] end
    local ok, gain, vs = pcall(function()
        local base = cache["#base"]
        if not base then
            base = LoadoutScore.Score(state, state.EquippedWeapon, eq, mode, difficulty)
            cache["#base"] = base
        end
        local best, bestVs = nil, nil
        for _, sl in ipairs(slots) do
            local trial = table.clone(eq)
            trial[sl] = item
            local sc = LoadoutScore.Score(state, state.EquippedWeapon, trial, mode, difficulty)
            if best == nil or sc > best then best, bestVs = sc, eq[sl] end
        end
        return (best / math.max(base, 1e-9)) - 1, bestVs
    end)
    if not ok then return nil end
    cache[key] = { gain, vs }
    return gain, vs
end

return LoadoutScore
