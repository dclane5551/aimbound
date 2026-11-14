--!nocheck
-- Compiles every source of stats (weapon + its affixes, attributes, gear, skill tree, title) into the
-- final numbers combat uses and the character sheet shows.
--
-- Scaling model (see ItemData.LevelCurve): weapon damage comes from the weapon's own item level;
-- player health, regen, armor and melee grow with the player's level along the same curve that
-- enemies use, so on-level fights stay consistent while gear/skills/attributes provide the power.
local SkillTreeData = require(script.Parent:WaitForChild("SkillTreeData"))
local ItemData = require(script.Parent:WaitForChild("ItemData"))
local GemData = require(script.Parent:WaitForChild("GemData"))
local BoonData = require(script.Parent:WaitForChild("BoonData"))
local Progression = require(script.Parent:WaitForChild("Progression"))
local AscendancyData = require(script.Parent:WaitForChild("AscendancyData"))
local ClassData = require(script.Parent:WaitForChild("ClassData"))
local ExpertiseData = require(script.Parent:WaitForChild("ExpertiseData"))
local DamageTypes = require(script.Parent:WaitForChild("DamageTypes")) -- (UPDATE 8 OFFENSE: the five damage types)

-- Conditional / mechanic stats from the passive tree and gems. They are summed and handed to combat
-- (CombatServer reads stats.Cond.<Name>); ItemData.StatDefs says what each does.
local COND_STATS = {
    "BurnOnHit", "ChillOnHit", "BleedOnHit", "DecayOnHit", "ExplodeOnHit",
    "FirstHitDamage", "LowHealthEnemyDamage", "MovingDamage", "StillDamage", "StillDR", "LastMagDamage",
    "AilmentedDamage", "EliteDamage", "SwitchDamage", "KillHeal", "LowLifeDR", "HPToDamage",
    "WeakSpotCritChance", "FocusRetain", "BurnSpread", "ShatterPct", "CorpseExplode", "BleedStacks",
    "ExplosionRadiusPct", "RicochetPct",
    -- precision (2026-10-02): chain kills, overkill carry, pierce, executes (CombatServer)
    "ChainKillDamage", "OverkillCarry", "PierceDamage", "PierceCount", "ExecutePct",
    -- gun-agnostic playstyle damage (2026-10-05: replaced the tree's weapon-type nodes; CombatServer checks the condition)
    "CloseRangeDamage", "LongRangeDamage", "ReloadedDamage", "FreshMagDamage",
    -- (UPDATE 8 OFFENSE phase 4) the tree's AREA stats (they reshape stats.ShotFx: shot mods' chains / bursts) + relic hooks
    "AreaDamage", "AreaRadius", "ExtraChains", "ChainAlwaysCrit", "WeakKillBlast",
}
local IS_COND = {}
for _, k in ipairs(COND_STATS) do IS_COND[k] = true end

-- (passive tree v4, 2026-10-05) WEAPON-TYPE stats: "<Group><Stat>" only counts while the equipped gun is of that group,
-- e.g. CloseDamage = increased damage with SMGs / pistols. Groups = the five weapon classes (ClassData.Group).
-- (groups: ItemData.WeaponGroups -- the one place to add a gun type)
local WEAPON_GROUP = ItemData.WeaponGroups.ByClass
local GROUP_STAT: { [string]: { string } } = {}
for _, grp in ipairs(ItemData.WeaponGroups.Order) do
    for suffix, base in pairs({ Damage = "IncreasedDamage", FireRate = "FireRateBonus", CritChance = "CritChance",
        CritMultiplier = "CritMultiplier", ReloadSpeed = "ReloadSpeedBonus", MagSize = "MagSizeBonus", WeakSpot = "WeakSpotMultiplier" }) do
        GROUP_STAT[grp .. suffix] = { grp, base }
    end
end

export type CompiledStats = {
    Damage: number,
    FireRate: number,
    WeakSpotMultiplier: number,
    StreakBonusPerStack: number,
    CritChance: number,
    CritMultiplier: number,
    MaxHP: number,
    Armor: number,
    DamageReduction: number,
    MovementSpeedMult: number,
    HPRegen: number,
    GoldBonusMult: number,
    LuckMultiplier: number,
    MagazineSize: number,
    ReloadSpeed: number,
    MeleeDamage: number,
    LifeLeechPct: number,
    RecoilMultiplier: number,
    ExplosionRadius: number?,
    BurstCount: number?,
    PelletCount: number?,
    IsContinuousBeam: boolean?,
    SpecialMechanics: { [string]: boolean },
    UniqueTrait: ItemData.UniqueTrait?,
    -- character-sheet extras
    DamageBonusPct: number,
    FireRateBonusPct: number,
    TotalStrength: number,
    TotalDexterity: number,
    TotalVitality: number,
    TotalLuck: number,
    StreakMultiplier: number,
    -- elements, ailments & keystones
    FireResist: number, ColdResist: number, ChaosResist: number, MaxResist: number,
    AilmentChance: number, AilmentDuration: number,
    BurnDamage: number, FreezeEffect: number, BleedDamage: number, DecayEffect: number, ExplosionDamage: number,
    BodyShotMult: number, MaxFocusStacks: number, NoRegen: boolean,
    MaxHPPct: number, ArmorPct: number,
}

local StatCalculator = {}
StatCalculator.ShotMods = require(script.Parent:WaitForChild("ShotMods")) -- (UPDATE 8 OFFENSE phase 3: shot mods in gun sockets)

-- Attribute effects (also described in ItemData.StatDefs, keep in sync).
-- ATTRIBUTES v2 (owner 2026-10-05: "changes to how many attributes and their values should be considered"): fewer points
-- (1 a level + 4 every 10th: ItemData.AttrPointsAt, ~560 at level 400 instead of ~800) worth more each, against their own
-- ceilings (ATTR_CEILINGS) -- one attribute pumped alone flattens out, a spread keeps paying.
StatCalculator.STR_DAMAGE = 0.015
StatCalculator.DEX_FIRERATE = 0 -- (owner 2026-10-04: Dexterity no longer gives fire rate -- "every gun kind of turns into a minigun")
StatCalculator.DEX_CRIT = 0.004
StatCalculator.DEX_RELOAD = 0.015
StatCalculator.FIRERATE_SOFT = 0.4
StatCalculator.FIRERATE_CAP = 0.8
StatCalculator.VIT_HP = 0.03
StatCalculator.LCK_LUCK = 0.025
StatCalculator.LCK_PROC = 0.002 -- (tree v4: Luck also raises Proc Chance -- Luck travel nodes were loot-only)
-- LOOT FARMING BALANCE (owner 2026-10-05: "Hexslinger / luck / proc builds will be incredibly overpowered for loot
-- farming"): Luck paid twice and without limit -- better drops AND more ailment procs (= faster clears). Now:
--   * loot luck from your character has diminishing returns: +x becomes LOOT_LUCK_CAP x (1 - e^(-x / cap)), so it can
--     never pass +125% (x = +50% -> +42%, +100% -> +69%, +300% -> +113%). Difficulty / sources still multiply on top.
--   * Luck's proc chance is 0.2% a point (was 0.5%), at most +12% in total.
StatCalculator.LOOT_LUCK_CAP = 1.25 -- (owner 2026-10-05: "capped at 125% for now as a trial"; was 0.75)
StatCalculator.LUCK_PROC_CAP = 0.12
StatCalculator.BASE_HP = 100
StatCalculator.BASE_ATTRIBUTE = 5 -- every character starts with 5 in each attribute; only points above that add HP
-- (UPDATE 8 OFFENSE phase 4) ATTRIBUTES the PoE way: Strength / Dexterity / Intellect from the tree + gear only (ItemData.ATTRS,
-- ItemData.ATTR_BASE 10 each; hand-placed points are ignored). Their built-in bonuses per point (tree layer, no ceiling):
StatCalculator.ATTR_BONUS = { StrLife = 0.001, StrPlating = 0.002, DexAgility = 0.002, DexCrit = 0.0002, IntWard = 0.002, IntElemental = 0.001 }
-- (phase 4, owner: "no ceilings; strong builds 2-4x") the passive tree / gems / specialization layer has NO level ceiling any more
-- (CeilingCap -> huge for the tree layer); gear keeps its own until Phase 6 re-fits the power curve. true = the old ceilings.
StatCalculator.TREE_CEILINGS = false
-- ===== STAT CEILINGS (owner 2026-10-05: "Gear, tree, attributes allow the player to hit ridiculous firerate and crit / luck
-- etc numbers. Shouldnt it be scaled so that only starts to happen in the very end game? I dont want the player to get
-- overpowered until end game" + "players can just max out certain stats really early on ... basically EVERY stat") =====
-- Measured before (treesim best tree, no gear): crit 76-87% at level 60, ~96% x3.8-4.7 at 100, +280-500% damage at 100.
-- Now every stackable total runs into a CEILING that rises with your level: effective = cap x (1 - e^(-raw / cap)) -- small
-- bonuses count almost fully, heavy stacking flattens, nothing passes the cap. The cap grows slowly early and fast at the
-- end: cap(L) = lo + (hi - lo) x (L / 400) ^ CEILING_CURVE, so the "ridiculous" numbers (100% crit, +1200% damage...) only
-- open up in the very end game. Raw totals keep counting (more raw still helps, and it all pays off as you level).
-- Tooltip / sheet: CompiledStats.Ceilings[key] = { Raw, Cap }. Re-measure enemies after changing these: DevCmd powercurve.
-- THREE LAYERS (owner 2026-10-05: "Doesnt this completely remove the gear aspect of the game?" -> "lets make that change
-- to gear"): one shared cap made gear's % affixes worthless once the tree reached it. Now each SOURCE has its own ceiling
-- and they ADD: the passive tree (+ gems, boons, titles, ascendancy, mastery) -> CEILINGS, your attribute points ->
-- ATTR_CEILINGS, gear lines + weapon affixes (+ attribute lines on gear) -> GEAR_CEILINGS. Gear is the chase on top of the
-- character: its lines grow with item level (0.70 ItemData.GearLevelScale / tiers by rarity) and these caps follow YOUR level.
StatCalculator.CEILING_CURVE = 1.6
-- (2026-10-21 PASSIVE TREE v5, the reference game's point income + value bands): the TREE layer's caps rise on a gentler
-- curve so the early / mid game has room for what a node gives (the 1.6 curve left +144% damage room at level 100 for ~116
-- points: every node read as ~0). Level 400 is unchanged; the attribute layer keeps CEILING_CURVE.
StatCalculator.TREE_CEILING_CURVE = 1.0
StatCalculator.AUTO_FIRE_RATE = 7     -- shots / s from which a gun counts as full-auto for the fire-rate share below
StatCalculator.AUTO_FR_SHARE = 0.6    -- share of increased fire rate a full-auto gun gets
StatCalculator.GEAR_CEILING_CURVE = 1.3
StatCalculator.CEILING_MAX_LEVEL = 400
StatCalculator.ATTR_CEILINGS = {
    Damage = { 0.25, 3.0 }, CritChance = { 0.04, 0.25 }, Reload = { 0.15, 0.8 }, MaxHP = { 0.4, 4.0 }, Luck = { 0.2, 0.75 },
}
StatCalculator.GEAR_CEILINGS = {
    Damage = { 0.6, 5.0 }, FireRate = { 0.1, 0.3 }, CritChance = { 0.08, 0.45 }, CritMulti = { 0.3, 2.5 }, WeakSpot = { 0.25, 2.0 },
    MaxHP = { 0.4, 4.0 }, Armor = { 0.5, 4.0 }, MoveSpeed = { 0.06, 0.2 }, Reload = { 0.2, 0.8 }, MagSize = { 0.3, 1.2 },
    Luck = { 0.3, 1.0 }, Gold = { 0.4, 2.5 }, Leech = { 0.01, 0.04 }, Regen = { 0.004, 0.02 }, AilChance = { 0.3, 2.0 },
    AilDuration = { 0.3, 1.2 }, AilPower = { 0.5, 5.0 }, Streak = { 0.01, 0.06 }, CondDamage = { 0.3, 3.0 }, OnHit = { 0.06, 0.3 },
}
StatCalculator.CEILINGS = {
    -- key = { cap at level 1, cap at level 400 }   (bonuses on top of the base value)
    Damage = { 0.4, 10 },          -- increased damage from the tree / gems / boons / titles
    FireRate = { 0.12, 0.6 },      -- increased fire rate (2026-10-07: was 0.2 -> 1.0; owner: "Fire rate is still an issue with
                                   -- auto weapons, it gets out of hand a bit too much")
    CritChance = { 0.15, 0.95 },   -- crit chance above the 5% base
    CritMulti = { 0.4, 4.0 },      -- crit damage above the base +50%
    WeakSpot = { 0.4, 4.0 },       -- weak-spot multiplier above the gun's own
    MaxHP = { 0.8, 10 },           -- increased max health
    Armor = { 0.8, 8 },            -- increased armor
    MoveSpeed = { 0.12, 0.5 },
    Reload = { 0.3, 1.5 },
    MagSize = { 0.4, 2.0 },
    Luck = { 0.3, 1.0 },           -- loot luck (replaces LOOT_LUCK_CAP's curve)
    Gold = { 0.6, 4.0 },
    Leech = { 0.015, 0.06 },
    Regen = { 0.006, 0.03 },       -- % max health per second
    AilChance = { 0.4, 3.0 },      -- Proc Chance
    AilDuration = { 0.4, 2.0 },
    AilPower = { 0.8, 8.0 },       -- Burn / Bleed damage, Freeze / Decay effect, explosion damage
    Streak = { 0.02, 0.1 },        -- Focus damage per stack above the base 2%
    CondDamage = { 0.5, 6.0 },     -- each conditional damage (moving, still, close / long range, elites, new target...)
    OnHit = { 0.12, 0.6 },         -- each tree "chance to X on hit"
}
function StatCalculator.CeilingCap(key: string, level: number?, layer: string?): number
    if not layer and StatCalculator.TREE_CEILINGS == false then return math.huge end -- (phase 4: no tree ceilings)
    local tbl = (layer == "Gear" and StatCalculator.GEAR_CEILINGS) or (layer == "Attr" and StatCalculator.ATTR_CEILINGS) or StatCalculator.CEILINGS
    local c = tbl[key]
    if not c then return math.huge end
    local curve = (layer == "Gear") and StatCalculator.GEAR_CEILING_CURVE or (layer == "Attr") and StatCalculator.CEILING_CURVE
        or StatCalculator.TREE_CEILING_CURVE
    local t = math.clamp((level or 1) / StatCalculator.CEILING_MAX_LEVEL, 0, 1) ^ curve
    return c[1] + (c[2] - c[1]) * t
end
-- (2026-10-20 CEILING NOTABLES) tree stats that RAISE a tree-layer ceiling: Ceil<X> = +x of that row's base cap (e.g. 0.25 =
-- +25%). Filled by ApplyStat for the build being calculated (cleared at the start of every Calculate; nothing yields).
-- SAME STAT DOESN'T STACK (balance 2026-10-20: a greedy L400 Gunslinger pathed to 5 of them, two Damage ones from other
-- classes, +83% power): only the biggest Ceil<X> of each row counts. CEIL_N = how many the build has (tooltips).
StatCalculator.CEIL_STATS = { CeilDamage = "Damage", CeilMaxHP = "MaxHP", CeilCritChance = "CritChance", CeilCritMulti = "CritMulti",
    CeilWeakSpot = "WeakSpot", CeilArmor = "Armor", CeilAilPower = "AilPower" }
local CEIL_BONUS: { [string]: number } = {}
local CEIL_N: { [string]: number } = {}
function StatCalculator.SoftCap(raw: number, cap: number): number
    if raw <= 0 or cap == math.huge then return raw end
    return cap * (1 - math.exp(-raw / cap))
end

-- (2026-10-20, owner: the skill tree "should show the stat increase relative to your level, not the uncapped") which
-- ceiling a tree / gem / ascendancy stat feeds: ceilKey (the CompiledStats.Ceilings record), capKey (CEILINGS row); nil = no
-- ceiling (resists, MORE multipliers, flat armour, attributes ...); 3rd value true = a weapon-type stat for another gun type
local TREE_CEIL = { IncreasedDamage = "Damage", FireRateBonus = "FireRate", CritChance = "CritChance", CritMultiplier = "CritMulti",
    WeakSpotMultiplier = "WeakSpot", StreakDamageBonus = "Streak", MagSizeBonus = "MagSize", ReloadSpeedBonus = "Reload",
    MovementSpeed = "MoveSpeed", MaxHPPct = "MaxHP", ArmorPct = "Armor", HPRegenPct = "Regen", LifeLeech = "Leech",
    AilmentChance = "AilChance", AilmentDuration = "AilDuration", LootLuck = "Luck", GoldBonus = "Gold",
    BurnDamage = "Burn", FreezeEffect = "Freeze", BleedDamage = "Bleed", DecayEffect = "Decay", ExplosionDamage = "Explosion" }
local AIL_POWER = { Burn = true, Freeze = true, Bleed = true, Decay = true, Explosion = true }
function StatCalculator.TreeCeilKey(statName: string, weaponGroup: string?): (string?, string?, boolean?)
    local gs = GROUP_STAT[statName]
    if gs then
        if gs[1] ~= weaponGroup then return nil, nil, true end
        statName = gs[2]
    end
    local k = TREE_CEIL[statName]
    if k then return k, AIL_POWER[k] and "AilPower" or k end
    if IS_COND[statName] then
        if string.sub(statName, -6) == "Damage" then return statName, "CondDamage" end
        if string.sub(statName, -5) == "OnHit" then return statName, "OnHit" end
    end
    return nil
end
-- what `v` of a stat is really worth on top of your build at your level (ceilings = CompiledStats.Ceilings of the build).
-- removing = the stat is already in the build (an allocated node: what it gives now). Returns (value, "offgun"?).
function StatCalculator.TreeEffective(statName: string, v: number, ceilings: any, level: number?, weaponGroup: string?, removing: boolean?): (number, string?)
    local key, capKey, offGun = StatCalculator.TreeCeilKey(statName, weaponGroup)
    if offGun then -- (another gun type's stat: what it would add while holding one of those)
        key, capKey = StatCalculator.TreeCeilKey(GROUP_STAT[statName][2], nil)
        if not key or type(v) ~= "number" then return v, "offgun" end
        local rec = type(ceilings) == "table" and ceilings[key] or nil
        local raw = (rec and rec.Tree and tonumber(rec.Tree[1])) or 0
        local cap = StatCalculator.CeilingCap(capKey :: string, level)
        return StatCalculator.SoftCap(raw + v, cap) - StatCalculator.SoftCap(raw, cap), "offgun"
    end
    if not key or type(v) ~= "number" then return v end
    local rec = type(ceilings) == "table" and ceilings[key] or nil
    local raw = (rec and rec.Tree and tonumber(rec.Tree[1])) or 0
    local cap = (rec and rec.Tree and tonumber(rec.Tree[3])) or StatCalculator.CeilingCap(capKey :: string, level)
    if removing then return StatCalculator.SoftCap(raw, cap) - StatCalculator.SoftCap(math.max(0, raw - v), cap) end
    return StatCalculator.SoftCap(raw + v, cap) - StatCalculator.SoftCap(raw, cap)
end
-- (CEILING NOTABLES) what +v of a Ceil<X> stat would add to your build right now (its stat, at your level): the build's
-- biggest tree raw for that ceiling row, its current cap -> the cap + v x the row's base cap. nil = not a ceiling stat.
-- have = CompiledStats.CeilNotables: one of that row already counts -> gain 0 + dup true (they don't stack).
function StatCalculator.CeilGain(statName: string, v: number, ceilings: any, level: number?, removing: boolean?, have: any?): (number?, string?, boolean?)
    local ck = StatCalculator.CEIL_STATS[statName]
    if not ck then return nil end
    local n = (type(have) == "table" and tonumber(have[ck])) or 0
    if (removing and n >= 2) or (not removing and n >= 1) then return 0, ck, true end
    local keys = (ck == "AilPower") and { "Burn", "Freeze", "Bleed", "Decay", "Explosion" } or { ck }
    local best, raw, cap = nil, 0, StatCalculator.CeilingCap(ck, level)
    for _, k in ipairs(keys) do
        local rec = type(ceilings) == "table" and ceilings[k] or nil
        if rec and rec.Tree and (tonumber(rec.Tree[1]) or 0) > raw then best, raw, cap = k, rec.Tree[1], rec.Tree[3] or cap end
    end
    local base = StatCalculator.CeilingCap(ck, level)
    local newCap = removing and math.max(base * 0.1, cap - v * base) or (cap + v * base)
    local gain = removing and (StatCalculator.SoftCap(raw, cap) - StatCalculator.SoftCap(raw, newCap)) or (StatCalculator.SoftCap(raw, newCap) - StatCalculator.SoftCap(raw, cap))
    return gain, best or keys[1]
end
-- the share of a stat's whole tree layer that counts at your level (the side panel's totals)
function StatCalculator.TreeShare(statName: string, ceilings: any, weaponGroup: string?): (number, string?)
    local key, _, offGun = StatCalculator.TreeCeilKey(statName, weaponGroup)
    if offGun then return 0, "offgun" end
    local rec = key and type(ceilings) == "table" and ceilings[key] or nil
    if not (rec and rec.Tree and (tonumber(rec.Tree[1]) or 0) > 0) then return 1 end
    return math.clamp(rec.Tree[2] / rec.Tree[1], 0, 1)
end

StatCalculator.BASE_CRIT_CHANCE = 0.05
StatCalculator.BASE_CRIT_MULT = 1.5
StatCalculator.ARMOR_CONSTANT = 100 -- damage reduction = armor / (armor + 100 x level curve)
StatCalculator.BASE_MAX_RESIST = 0.75
-- DAMAGE REDUCTION CAP (launch sweep 2026-10-13, docs/BALANCE_2026-10-13.md decision 1): the armour reduction cap is 75%,
-- and 4 of 5 classes reached it by level 200 (power-curve rule: no stat maxes early). DR_CAP_BY_LEVEL = true makes the cap
-- rise with level on the same curve as the CEILINGS: DR_CAP_LO at level 1 -> DR_CAP at 400 (~53% at 100, ~58% at 200).
-- ON (owner 2026-10-13: "Scale the cap"). Studio A/B: workspace attr DevDRCapByLevel = true / false overrides the flag.
StatCalculator.DR_CAP = 0.75
StatCalculator.DR_CAP_LO = 0.5
StatCalculator.DR_CAP_BY_LEVEL = true
local IS_STUDIO = game:GetService("RunService"):IsStudio()
-- ARCWRIGHT MID-GAME BOOST (docs/BALANCE_2026-10-13.md decision 2): measured Arcwright damage at 0.5-0.8x the power table
-- from level 20 to 200; raw treesim DPS vs the five-class mean: 0.75x L50, 0.62x L100, 0.41x L200, back in the pack at L300
-- (between Vanguard and Marksman). NOTE powercurve can't show a flat boost: it divides by the class's own level-1 numbers. ARC_BOOST_ON = true gives the Arcwright's class
-- guns more damage by level: ARC_BOOST_BY_LEVEL { level, extra } points, straight lines between them, the last held past it.
-- ON (owner 2026-10-13). (2026-10-20 SCALING CHECK, owner "just do what you recommended": the old fade to none at 270 left the
-- Arcwright behind the other four classes' kill speed by x1.18 at 200, x1.39 at 300, x1.88 at 400 (with +50% everywhere) ->
-- the boost now rises to the cap.)
-- (2026-10-21 CLASS BALANCE, owner approved changing the numbers: "every class within +-15% of the five-class mean kill time"):
-- measured OFFLINE with tools/sim/classbal (the same StatCalculator + treesim greedy, run by tools/bin/luau.exe; every point
-- spent, 9 routes per class -- plain + seeded with each of its passives -- the best by kill speed x toughness^0.3 kept). The old
-- single greedy got trapped (at L300 / 400 the Arcwright's route never entered its own region, and from L325 it left 100-200
-- points unspent), which is why the boost above had climbed to +180%: with a real route the Arcwright killed 1.8x faster
-- than the mean at 300-400 and 1.25x faster everywhere below. Now one table per class gun group (CLASS_BOOST_BY_LEVEL;
-- the Beam row = ARC_BOOST_BY_LEVEL): MORE damage with your class's guns, same interpolation. Before -> after, kill time
-- vs the five-class mean (L50 / 100 / 200 / 300 / 400): Gunslinger 1.26 1.21 1.23 1.60 1.55 -> 1.03 1.00 0.94 1.09 1.03;
-- Breacher 1.12 1.14 1.38 1.13 1.54 -> 0.97 0.98 1.06 0.87 1.07; Marksman 0.78 0.77 0.71 0.92 0.76 -> 0.96 0.95 0.90 1.09
-- 0.96; Arcwright 0.83 0.79 0.77 0.55 0.56 -> 1.03 0.99 1.09 0.94 1.01; Vanguard (no row) 1.10 1.19 1.08 1.09 0.97 -> 1.01
-- 1.09 1.02 1.03 0.94. Studio A/B: workspace attr DevArcBoost (Beam row) / DevClassBoost (the other rows) = true / false.
StatCalculator.ARC_BOOST_ON = false -- (UPDATE 8 phase 4: classes are no longer tuned to +-10%; builds decide power)
StatCalculator.ARC_BOOST_BY_LEVEL = { { 1, 0.02 }, { 50, -0.02 }, { 100, 0.00 }, { 150, 0.05 }, { 200, 0.09 }, { 250, 0.19 }, { 300, 0.29 }, { 350, 0.34 }, { 400, 0.38 } } -- (2026-10-22 gun tune: /1.09 for the BEAM buff, was 1 .11, 100 .09, 200 .19, 400 .50; expertise refit; tree v5 was 1 .12, 100 .09, 200 .31, 400 .43; 0.99u night: 1 .12, 150 .10, 200 .10, 300 .18, 400 .50)
StatCalculator.CLASS_BOOST_ON = false -- (UPDATE 8 phase 4: off -- the table was fitted to the old tree)
StatCalculator.CLASS_BOOST_BY_LEVEL = {
    -- (PASSIVE TREE v5, 2026-10-21: re-fitted with tools/sim/classbal/fitboost.py on the new tree -- no-boost sweep, the bt
    -- route pick, each class's kill time over the five-class mean, smoothed over neighbouring levels, the five centred on x1.
    -- Uncapped crit / weak-spot stacking made the Marksman ~2x faster than the mean at 300+ and the Breacher ~1.6x slower.)
    -- (2026-10-22: re-fitted again with EXPERTISE + the mechanic notables in the greedy builds; same method.)
    -- (2026-10-22 GUN TUNE: Shotgun row / 1.07 and Beam row / 1.09 -- their reference guns BM4 / BEAM got that much damage)
    Beam = StatCalculator.ARC_BOOST_BY_LEVEL, -- Arcwright
    Close = { { 1, -0.03 }, { 50, 0.02 }, { 100, 0.03 }, { 150, -0.05 }, { 200, -0.15 }, { 250, -0.18 }, { 300, -0.18 }, { 350, -0.23 }, { 400, -0.27 } }, -- Gunslinger
    Shotgun = { { 1, 0.04 }, { 50, 0.07 }, { 100, 0.20 }, { 150, 0.39 }, { 200, 0.57 }, { 250, 0.67 }, { 300, 0.67 }, { 350, 0.70 }, { 400, 0.77 } }, -- Breacher
    Precision = { { 1, -0.15 }, { 50, -0.09 }, { 100, -0.15 }, { 150, -0.26 }, { 200, -0.34 }, { 250, -0.40 }, { 300, -0.44 }, { 350, -0.47 }, { 400, -0.49 } }, -- Marksman
    Assault = { { 1, -0.02 }, { 50, -0.12 }, { 100, -0.17 }, { 150, -0.15 }, { 200, -0.12 }, { 250, -0.13 }, { 300, -0.13 }, { 350, -0.08 }, { 400, -0.05 } }, -- Vanguard
}
function StatCalculator.ClassBoost(group: string?, level: number?): number
    local pts = group and StatCalculator.CLASS_BOOST_BY_LEVEL[group]
    if not pts then return 1 end
    local on = (group == "Beam") and StatCalculator.ARC_BOOST_ON or StatCalculator.CLASS_BOOST_ON
    if IS_STUDIO then
        local dev = workspace:GetAttribute(group == "Beam" and "DevArcBoost" or "DevClassBoost")
        if type(dev) == "boolean" then on = dev end
    end
    if not on then return 1 end
    local L = level or 1
    if L >= pts[#pts][1] then return 1 + pts[#pts][2] end
    for i = 1, #pts - 1 do
        local a, b = pts[i], pts[i + 1]
        if L <= b[1] then return 1 + a[2] + (b[2] - a[2]) * math.clamp((L - a[1]) / (b[1] - a[1]), 0, 1) end
    end
    return 1 + pts[#pts][2]
end
function StatCalculator.ArcwrightBoost(level: number?): number return StatCalculator.ClassBoost("Beam", level) end
-- CLASS EDGE (Phase 6, 2026-10-21): a flat "more damage" for a class's own guns where its PLAIN tree route lags -- route-independent,
-- so it moves the average and the strong build alike (a bigger region scale only fed the strong routes: Marksman 0.75 left the plain
-- route ~as slow at L50-100 and took the strong one from x7.6 to x9.6 its average). Marksman's plain route was ~1.55x the five-class
-- mean kill time at L50-100 and ~1.2x at L200 (scratch fit.py harness, avg mode).
StatCalculator.CLASS_EDGE = {
    Precision = { { 1, 0 }, { 20, 0.1 }, { 50, 0.35 }, { 100, 0.35 }, { 150, 0.2 }, { 200, 0.1 }, { 250, 0 } },
    -- (Phase 6 strong-build fix: the Arcwright's own sector 5.0 -> 1.4 in gen_tree_v4; this keeps its deep plain route at pace)
    Beam = { { 1, 0 }, { 100, 0.02 }, { 150, 0.065 }, { 200, 0.85 } },
    -- ((CLASS BUILDS) balance) the Breacher's deep own-sector OFFENCE 3.6 -> 1.5 (gen_tree_v4 DEEP_SCALE): this keeps its plain route's pace
    Shotgun = { { 1, 0 }, { 50, 0 }, { 100, 0.12 }, { 150, 0.10 }, { 200, 0.20 } },
    -- ((CLASS BUILDS) balance) the Vanguard's plain route lost a little at L200 (Breacher deep offence it passed through, Rifle crit nodes re-pointed to pierce)
    Assault = { { 1, 0 }, { 150, 0.02 }, { 200, 0.135 } },
}
-- ((CLASS BUILDS) CLASS LEANS, owner 2026-10-22: "Some classes are glass cannons, some in the middle, some tankier, to
-- encourage trying a ton of different builds"): one flat MORE-damage factor per class gun group on top of ClassBoost x ClassEdge.
-- Owner's targets vs the class-average build: Marksman +25%, Gunslinger +20%, Vanguard 0, Arcwright -10%, Breacher -20%; divided by
-- their geometric mean (1.0155) so the five-class average damage -- what POWER_ANCHORS / enemy health are fitted to -- stays put.
-- Toughness already leans the other way (tree defence factors, cbtree TOUGHNESS SPREAD): MAR ~0.6x, GUN ~0.5x, VAN ~1x, ARC ~1.5x,
-- BRE ~2x the five-class mean from L100. A multiplier never changes a route (the sims' greedy picks the same nodes).
-- (VANGUARD UP, 2026-10-24; owner: "For vanguard, we can just increase the damage a bit") Assault 0.985 -> 1.11 (+12.7%): still the
-- middle (below Close 1.182, above Beam 0.886). The others are NOT re-normalised (owner: don't lower them) and POWER_ANCHORS are not
-- re-fitted: the five-class geometric-mean damage rises x1.024 (accepted; enemies unchanged).
StatCalculator.CLASS_LEAN = { Precision = 1.231, Close = 1.182, Assault = 1.11, Beam = 0.886, Shotgun = 0.788 }
function StatCalculator.ClassEdge(group: string?, level: number?): number
    local pts = group and StatCalculator.CLASS_EDGE[group]
    if not pts then return 1 end
    local L = level or 1
    if L >= pts[#pts][1] then return 1 + pts[#pts][2] end
    for i = 1, #pts - 1 do
        local a, b = pts[i], pts[i + 1]
        if L <= b[1] then return 1 + a[2] + (b[2] - a[2]) * math.clamp((L - a[1]) / (b[1] - a[1]), 0, 1) end
    end
    return 1 + pts[#pts][2]
end
-- ===== (CLASS BUILDS) CORNERSTONE (TREE builder, docs/CLASS_BUILDS.md section 3; texts in tools/tree_v8.py CB_NEW) =====
-- Slug Rounds (K_SLUG): a shotgun fires ONE slug = all its pellets' damage in a single shot (stats.Slug, PelletCount 1;
-- the client fires one ray with no spread, CombatServer treats it as one pellet). Carom Shot (K_TRICK_SHOT): fx.Carom in
-- the shot-mod Fx (CombatServer.Off.ShotModFx) + body hits x0.8 (BodyShotMult). Field Commander lives in CombatServer.CBCorner.
StatCalculator.CBCorner = { CAROM_R = 25, CAROM_PCT = 0.5, CAROM_BODY = 0.8, SLUG_MORE = 1.1 }
function StatCalculator.CBCorner.IsSlug(mech: any, weapon: any): boolean
    return type(mech) == "table" and mech["K_SLUG"] == true and ((weapon and weapon.PelletCount) or 1) > 1
end
-- the slug's damage factor (= the pellet count); scales the typed hit in place so DamageByType matches
function StatCalculator.CBCorner.SlugMult(mech: any, weapon: any, typedHit: { [string]: number }): number
    if not StatCalculator.CBCorner.IsSlug(mech, weapon) then return 1 end
    local n = weapon.PelletCount
    n *= StatCalculator.CBCorner.SLUG_MORE -- (PART B balance: a slug = all the pellets +10%)
    for k, v in pairs(typedHit) do typedHit[k] = v * n end
    return n
end
function StatCalculator.DamageReductionCap(level: number?): number
    local on = StatCalculator.DR_CAP_BY_LEVEL
    if IS_STUDIO then
        local dev = workspace:GetAttribute("DevDRCapByLevel")
        if type(dev) == "boolean" then on = dev end
    end
    if not on then return StatCalculator.DR_CAP end
    local t = math.clamp((level or 1) / StatCalculator.CEILING_MAX_LEVEL, 0, 1) ^ StatCalculator.CEILING_CURVE
    return StatCalculator.DR_CAP_LO + (StatCalculator.DR_CAP - StatCalculator.DR_CAP_LO) * t
end

-- Harder difficulties lower your resistances (Path of Exile style), so elemental defense matters more
-- the deeper you push. Shown on the character sheet as "(x% after difficulty)".
StatCalculator.DifficultyResistPenalty = {
    Easy = 0, Normal = 0, Hard = -0.10, Brutal = -0.20, Nightmare = -0.30, Torment = -0.40, Cataclysm = -0.50, Oblivion = -0.60, Endless = -0.30,
    Ruin = -0.64, Dread = -0.68, Apocalypse = -0.72, Annihilation = -0.76, Eternity = -0.80, Singularity = -0.84,
}
-- ===== (UPDATE 8 DEFENCE) LIFE / PLATING / AGILITY / WARD / RESISTANCES (DEFENCE builder; docs/UPDATE8.md) =====
-- Layers of a hit on you (CombatServer.DamagePlayer): Agility (a chance an ORDINARY hit misses: never boss hits, mechanics,
-- hazards) -> Plating (Kinetic) / resistance (Heat / Cryo / Volt / Void, minus the difficulty penalty) -> Ward (a pool in
-- front of life, recharges WARD_DELAY s after the last damage; Void skips it) -> life. No level ceilings in this math:
-- the level curve only NORMALISES (gear Plating / Agility grow with item level on the same curve), nothing caps by level.
--   Plating vs a hit: P / (P + PLATING_K x LevelCurve(level) x (hit / ordinary hit)^PLATING_HIT_EXP), + DamageReduction
--     lines, at most PLATING_MAX. An ORDINARY hit (a plain bot's swing on that floor) = exactly the old armour formula, so an
--     average build takes today's damage; fodder chip is cut more, boss slams less (PoE: big hits are reduced less).
--   Agility: A / (A + AGILITY_K x LevelCurve(level)), at most AGILITY_MAX.
-- Old stats keep working until WIPE 5: Armor / ArmorPct / BaseArmor / MoreArmor = Plating, FireResist = Heat, ColdResist =
-- Cryo, ChaosResist = Void AND Volt (the Storm biome's element was Chaos-resisted), AllResist = all four, MaxResist = all.
local DEF_DT = require(script.Parent:WaitForChild("DamageTypes"))
StatCalculator.PLATING_K = 100
StatCalculator.PLATING_HIT_EXP = 0.5
StatCalculator.PLATING_MAX = 0.9
StatCalculator.AGILITY_K = 100
StatCalculator.AGILITY_MAX = 0.75
StatCalculator.WARD_DELAY = 2.0 -- seconds without taking damage before Ward recharges
StatCalculator.WARD_RATE = 0.25 -- of max Ward per second while recharging
StatCalculator.RESIST_FLOOR = -0.6
StatCalculator.RESIST_TYPES = { "Heat", "Cryo", "Volt", "Void" }
-- stat key -> what it adds (gear lines, tree / gem / boon / ascendancy stats; see DefApply)
local DEF_STAT = { Plating = true, PlatingPct = true, MorePlating = true, Agility = true, AgilityPct = true, MoreAgility = true,
    Ward = true, WardPct = true, MoreWard = true, WardRecharge = true, WardStart = true,
    HeatResist = true, CryoResist = true, VoltResist = true, VoidResist = true, AllElemResist = true,
    PlatingVsElements = true, WardVsVoid = true, VoltCanFreeze = true, -- (UPDATE 8 GEAR v3 build lines)
    MovingWard = true, -- (relic Wardstep: CombatServer.WardHitNow)
    MaxHeatResist = true, MaxCryoResist = true, MaxVoltResist = true, MaxVoidResist = true, MaxAllElemResist = true }
StatCalculator.DEF_STAT = DEF_STAT
local function DefNew(): any
    return { Plat = 0, PlatInc = 0, PlatMore = 1, Agi = 0, AgiInc = 0, AgiMore = 1, Ward = 0, WardInc = 0, WardMore = 1, WardRech = 0, WardFast = 0,
        Res = { Heat = 0, Cryo = 0, Volt = 0, Void = 0 }, Max = { Heat = 0, Cryo = 0, Volt = 0, Void = 0 }, Out = {} }
end
local function DefApply(def: any, s: string, v: number)
    if s == "Plating" then def.Plat += v
    elseif s == "PlatingPct" then def.PlatInc += v
    elseif s == "MorePlating" then def.PlatMore *= (1 + v)
    elseif s == "Agility" then def.Agi += v
    elseif s == "AgilityPct" then def.AgiInc += v
    elseif s == "MoreAgility" then def.AgiMore *= (1 + v)
    elseif s == "Ward" then def.Ward += v
    elseif s == "WardPct" then def.WardInc += v
    elseif s == "MoreWard" then def.WardMore *= (1 + v)
    elseif s == "WardRecharge" then def.WardRech += v
    elseif s == "WardStart" then def.WardFast += v
    elseif s == "PlatingVsElements" or s == "WardVsVoid" or s == "VoltCanFreeze" or s == "MovingWard" then def[s] = math.max(def[s] or 0, v) -- (build lines don't stack)
    elseif s == "AllElemResist" then def.Res.Heat += v; def.Res.Cryo += v; def.Res.Volt += v
    elseif s == "MaxAllElemResist" then def.Max.Heat += v; def.Max.Cryo += v; def.Max.Volt += v
    elseif string.sub(s, 1, 3) == "Max" then def.Max[string.sub(s, 4, -7)] += v
    else def.Res[string.sub(s, 1, -7)] += v end
end
-- the finished defence numbers (into def.Out; Calculate's return table reads them)
local function DefFinal(def: any, curve: number, fire: number, cold: number, chaos: number, maxResist: number)
    local o = def.Out
    o.Agility = math.max(0, def.Agi) * math.max(0, 1 + def.AgiInc) * def.AgiMore
    o.Evade = (o.Agility > 0) and math.min(StatCalculator.AGILITY_MAX, o.Agility / (o.Agility + StatCalculator.AGILITY_K * curve)) or 0
    o.Ward = math.max(0, def.Ward * math.max(0, 1 + def.WardInc) * def.WardMore)
    o.WardRate = StatCalculator.WARD_RATE * math.max(0.1, 1 + def.WardRech)
    o.WardDelay = StatCalculator.WARD_DELAY / math.max(0.25, 1 + def.WardFast)
    o.Heat = fire + def.Res.Heat
    o.Cryo = cold + def.Res.Cryo
    o.Volt = chaos + def.Res.Volt -- (old Chaos resist also covers Volt until WIPE 5: Storm hits were Chaos)
    o.Void = chaos + def.Res.Void
    for _, t in ipairs(StatCalculator.RESIST_TYPES) do o["Max" .. t] = math.clamp(maxResist + def.Max[t], 0.5, 0.9) end
end
-- the difficulty's resist penalty (DamageTypes.RESIST_PENALTY; the old table for a tier it doesn't list, e.g. Endless)
function StatCalculator.ResistPenalty(difficulty: string?): number
    local d = difficulty or "Easy"
    if DEF_DT.RESIST_PENALTY[d] ~= nil then return DEF_DT.RESIST_PENALTY[d] end
    return StatCalculator.DifficultyResistPenalty[d] or DEF_DT.ResistPenalty(d)
end
-- Effective resistance for one type (old element names work: Fire / Cold / Chaos / Shock ...) at a difficulty: raw + the
-- penalty, between RESIST_FLOOR and that type's max. Kinetic / unknown = 0.
function StatCalculator.EffectiveResist(stats: any, element: string, difficulty: string?): number
    local t = DEF_DT.Normalize(element)
    if not t or t == "Kinetic" then return 0 end
    local raw = stats[t .. "Resist"]
    if raw == nil then -- (a stats table from before UPDATE 8)
        raw = (t == "Heat" and stats.FireResist) or (t == "Cryo" and stats.ColdResist) or stats.ChaosResist or 0
    end
    local cap = stats["Max" .. t .. "Resist"] or stats.MaxResist or StatCalculator.BASE_MAX_RESIST
    return math.clamp(raw + StatCalculator.ResistPenalty(difficulty), StatCalculator.RESIST_FLOOR, cap)
end
-- Plating's cut of one Kinetic hit; rel = the hit / an ordinary hit on that floor (1 = ordinary, nil = 1)
function StatCalculator.PlatingReduction(stats: any, rel: number?): number
    local p = stats.Plating or stats.Armor or 0
    local k = stats.PlatingScale or StatCalculator.PLATING_K
    local dr = 0
    if p > 0 then dr = p / (p + k * math.max(0.05, rel or 1) ^ StatCalculator.PLATING_HIT_EXP) end
    return math.clamp(dr + (stats.DRBonus or 0), 0, StatCalculator.PLATING_MAX)
end
-- TOUGHNESS (UPDATE 8 GEAR v3: Equip Best + the sims): effective health over a typical mix of hits -- TOUGH_MIX of Kinetic /
-- elemental (Heat / Cryo / Volt alike) / Void at this difficulty, TOUGH_ORDINARY of them ordinary (Agility can dodge those),
-- Ward counted at TOUGH_WARD (it recharges, Void skips it).
StatCalculator.TOUGH_MIX = { Kinetic = 0.5, Elemental = 0.4, Void = 0.1 }
StatCalculator.TOUGH_ORDINARY, StatCalculator.TOUGH_WARD = 0.6, 0.9
-- (AGILITY vs BOSSES, 2026-10-24) a boss's PLAIN hits can be dodged too (BossAI M.PLAIN allow-list), at BOSS_EVADE x your chance
-- (CombatServer.DamagePlayer reads it). TOUGH_BOSS: bosses' share of the hits you take (Share, an estimate) x the share of boss
-- moves that are plain (Plain: 9 allow-listed moves in 6 of the 34 boss kits, ~0.3 of those six fights' moves, 0.053 over all
-- kits by move slots) -- added to TOUGH_ORDINARY's dodgeable share.
StatCalculator.BOSS_EVADE = 1.0
StatCalculator.TOUGH_BOSS = { Share = 0.3, Plain = 0.053 }
function StatCalculator.Toughness(s: any, difficulty: string?): number
    local M = StatCalculator.TOUGH_MIX
    local ele = 0
    for _, t in ipairs({ "Heat", "Cryo", "Volt" }) do ele += (1 - StatCalculator.EffectiveResist(s, t, difficulty)) / 3 end
    local taken = M.Kinetic * (1 - (s.DamageReduction or 0)) + M.Elemental * ele + M.Void * (1 - StatCalculator.EffectiveResist(s, "Void", difficulty))
    local TB = StatCalculator.TOUGH_BOSS
    taken *= 1 - (StatCalculator.TOUGH_ORDINARY + TB.Share * TB.Plain * StatCalculator.BOSS_EVADE) * (s.EvadeChance or 0)
    return ((s.MaxHP or 1) + StatCalculator.TOUGH_WARD * (s.Ward or 0)) / math.max(0.05, taken)
end
-- a hit after Plating / resistance (no Agility, no Ward): returns the damage left, the resist used and the type
function StatCalculator.MitigateHit(stats: any, raw: number, dtype: string?, difficulty: string?, rel: number?): (number, number, string)
    local t = DEF_DT.Normalize(dtype) or "Kinetic"
    if t == "Kinetic" then return raw * (1 - StatCalculator.PlatingReduction(stats, rel)), 0, t end
    local res = StatCalculator.EffectiveResist(stats, t, difficulty)
    local m = raw * (1 - res)
    if stats.SpecialMechanics and stats.SpecialMechanics["IRON_REFLEXES"] then m *= (1 - StatCalculator.PlatingReduction(stats, rel) * 0.5) end
    if (stats.PlatingVsElements or 0) > 0 then m *= (1 - StatCalculator.PlatingReduction(stats, rel) * stats.PlatingVsElements) end -- (gear build line)
    return m, res, t
end

-- ===== (UPDATE 8 OFFENSE) TYPED HIT -- docs/UPDATE8.md "The hit formula" =====
-- per type: the gun's base (weapon.DamageTypes = { Kinetic = 0.7, Volt = 0.3 }, default all Kinetic) + flat added ->
-- conversion (left -> right) -> x (1 + increased for that type + generic) -> x more. Crit, weak spot and the enemy's
-- resistances are applied per hit by CombatServer (they scale every type alike, so the shares hold). off = the build's
-- new typed stats (DamageTypes.OFFENCE_STATS, no level ceilings); incGeneric = today's (capped) increased damage.
-- Old elemental prefixes convert DamageTypes.PROC_CONVERT of the Kinetic damage to their type.
function StatCalculator.TypedHit(weapon: any, weaponDamage: number, off: { [string]: number }?, incGeneric: number?, more: number?): { [string]: number }
    local DT = DamageTypes
    off = off or {}
    local base = DT.Empty()
    local split = type(weapon) == "table" and type(weapon.DamageTypes) == "table" and weapon.DamageTypes or nil
    if not split and type(weapon) == "table" and ItemData.GunTypes then split = ItemData.GunTypes(weapon) end -- (phase 2 gun bases)
    local tot = 0
    if split then for _, t in ipairs(DT.ORDER) do tot += math.max(0, tonumber(split[t]) or 0) end end
    if tot > 0 then
        for _, t in ipairs(DT.ORDER) do base[t] = weaponDamage * math.max(0, tonumber(split[t]) or 0) / tot end
    else
        base.Kinetic = weaponDamage
    end
    base.Kinetic *= math.max(0, 1 + (off.LocalKinetic or 0)) -- (phase 2: local increased Kinetic on the gun = its base)
    -- gear / tree flat added per hit x DT.AddedEffect (slow guns get more of it, fast ones less, shotguns split it per pellet)
    local eff = DT.AddedEffect(type(weapon) == "table" and weapon.BaseFireRate or nil, type(weapon) == "table" and weapon.PelletCount or nil)
    local added = DT.Empty()
    for _, t in ipairs(DT.ORDER) do
        added[t] = (off[DT.ADDED_STAT[t]] or 0) * eff + (off["LocalAdded" .. t] or 0) * weaponDamage -- (local added = a share of the base hit)
    end
    added.Kinetic += (off.FlatDamage or 0) * eff -- (the old "Sharpened" flat damage = flat Kinetic)
    local conv: { [string]: { [string]: number } } = {}
    for i, src in ipairs(DT.ORDER) do
        for j = i + 1, #DT.ORDER do
            local v = off[DT.ConvertStat(src, DT.ORDER[j])]
            if v and v > 0 then conv[src] = conv[src] or {}; conv[src][DT.ORDER[j]] = (conv[src][DT.ORDER[j]] or 0) + v end
        end
    end
    local procType = type(weapon) == "table" and weapon.Proc and DT.PROC_TYPE[weapon.Proc.Id]
    if procType and procType ~= "Kinetic" then
        conv.Kinetic = conv.Kinetic or {}
        conv.Kinetic[procType] = (conv.Kinetic[procType] or 0) + DT.PROC_CONVERT
    end
    local inc = DT.Empty()
    for _, t in ipairs(DT.ORDER) do inc[t] = (off[DT.INC_STAT[t]] or 0) + (DT.ELEMENTAL[t] and (off.ElementalDamage or 0) or 0) end
    return DT.BuildHit(base, added, conv, inc, math.max(-0.9, incGeneric or 0), more or 1)
end

-- ===== (CLASS BUILDS) SIGNATURE: the stat-like parts of the specializations' signature rules (docs/CLASS_BUILDS.md
-- section 2; the rest lives in CombatServer.CB.Sig). ascFx = Calculate's specialization Fx list ({ Fx, Key }); only the
-- spec's one "Sig" Fx counts. Kept as fields (Calculate's locals are full).
function StatCalculator.SigOf(ascFx: { any }?): (string?, any)
    for _, e in ipairs(ascFx or {}) do
        if e.Fx.Kind == "Sig" then return e.Fx.Id, e.Fx.P or {} end
    end
    return nil, nil
end
-- after the shot mods: CRYOSTASIS -- Cryo builds Freeze P.Build x as fast (the shot's FreezeBuild, read by TypeAilments)
function StatCalculator.SigStats(ascFx: { any }?, fx: any)
    local id, P = StatCalculator.SigOf(ascFx)
    if id == "SIG_FROSTBINDER" and type(fx) == "table" then fx.FreezeBuild = (fx.FreezeBuild or 1) * (P.Build or 2) end
end
-- OVERCAP (Bastion): every 1% of resist above its max (Heat / Cryo / Volt / Void summed, before the difficulty penalty) =
-- P.Per of max health regenerated a second, at most P.Max -> health a second to add to HPRegen
function StatCalculator.SigRegen(ascFx: { any }?, out: any, maxHP: number, noRegen: boolean?): number
    local id, P = StatCalculator.SigOf(ascFx)
    if id ~= "SIG_BASTION" or noRegen or type(out) ~= "table" then return 0 end
    local over = 0
    for _, t in ipairs(StatCalculator.RESIST_TYPES) do
        over += math.max(0, (out[t] or 0) - (out["Max" .. t] or StatCalculator.BASE_MAX_RESIST))
    end
    return maxHP * math.min(P.Max or 0.04, (P.Per or 0.003) * over * 100)
end
-- the overcap a stats table shows (the sheet / the spec panel): sum of resist above max, as a fraction
function StatCalculator.SigOvercap(stats: any): number
    local over = 0
    for _, t in ipairs(StatCalculator.RESIST_TYPES) do
        over += math.max(0, (stats[t .. "Resist"] or 0) - (stats["Max" .. t .. "Resist"] or StatCalculator.BASE_MAX_RESIST))
    end
    return over
end

function StatCalculator.Calculate(
    weapon: ItemData.WeaponInstance,
    allocatedNodeIds: { string },
    currentStreak: number,
    playerLevel: number?,
    playerStats: { Strength: number, Dexterity: number, Vitality: number, Luck: number }?,
    equippedGear: { [string]: ItemData.GearInstance }?,
    equippedTitle: string?,
    socketedGems: { [string]: any }?,
    runBoons: { string }?, -- this run's boons (BoonData ids)
    progress: any? -- the player state: weapon mastery (StatsTracking.WeaponKills, see Progression)
): CompiledStats
    local lvl = playerLevel or 1
    local curve = ItemData.LevelCurve(lvl)
    local pStats = playerStats or { Strength = 5, Dexterity = 5, Vitality = 5, Luck = 5 }
    table.clear(CEIL_BONUS); table.clear(CEIL_N) -- (CEILING NOTABLES of this build, from ApplyStat)
    local noCeil = IS_STUDIO and workspace:GetAttribute("DevNoCeil") == true -- (Studio A/B: ceiling notables off)

    -- ===== Gear =====
    local g: { [string]: number } = {}
    local function Add(stat: string, v: number) g[stat] = (g[stat] or 0) + v end
    if equippedGear then
        for _, piece in pairs(equippedGear) do
            if piece then
                if piece.Armor then Add("Armor", piece.Armor) end
                if piece.Base then -- (UPDATE 8 GEAR v3: the base's defences, its LocalDefence lines applied, + its implicit)
                    local d = ItemData.GearDefOf(piece)
                    if d.Plating > 0 then Add("Armor", d.Plating) end
                    if d.Agility > 0 then Add("Agility", d.Agility) end
                    if d.Ward > 0 then Add("Ward", d.Ward) end
                    if type(piece.Implicit) == "table" and piece.Implicit.Stat then Add(piece.Implicit.Stat, piece.Implicit.Value or 0) end
                else
                    if piece.Plating then Add("Armor", piece.Plating) end -- (UPDATE 8 DEFENCE: gear base defences)
                    if piece.Agility then Add("Agility", piece.Agility) end
                    if piece.Ward then Add("Ward", piece.Ward) end
                end
                for _, line in ipairs(piece.StatLines or {}) do
                    local hy = ItemData.GEAR_HYBRID and ItemData.GEAR_HYBRID[line.Stat] -- (GEAR v3 hybrid lines: life + a defence)
                    if hy then for k, r in pairs(hy) do Add(k, line.Value * r) end else Add(line.Stat, line.Value) end
                end
            end
        end
    end
    local allAttr = g.AllAttributes or 0
    -- (UPDATE 8 OFFENSE phase 4) attributes = the base + tree + gear only (hand-placed points are gone: pStats is ignored);
    -- old Vitality / Luck gear lines count as Strength / Intellect until WIPE 5. Their bonuses are added before the ceilings.
    local _ = pStats
    local totalStr = ItemData.ATTR_BASE + (g.Strength or 0) + (g.Vitality or 0) + allAttr
    local totalDex = ItemData.ATTR_BASE + (g.Dexterity or 0) + allAttr
    local totalInt = ItemData.ATTR_BASE + (g.Intellect or 0) + (g.Luck or 0) + allAttr

    local incDamage = g.IncreasedDamage or 0
    local incFireRate = g.FireRateBonus or 0
    local critChance = StatCalculator.BASE_CRIT_CHANCE + (g.CritChance or 0)
    local critMultiplier = StatCalculator.BASE_CRIT_MULT + (g.CritMultiplier or 0)
    local reloadSpeedBonus = g.ReloadSpeedBonus or 0
    local magSizeBonus = g.MagSizeBonus or 0
    local lootLuck = g.LootLuck or 0
    local flatWeakSpot = g.WeakSpotMultiplier or 0
    local moveSpeed = g.MovementSpeed or 0
    local goldBonus = g.GoldBonus or 0
    local armor = g.Armor or 0
    local drBonus = g.DamageReduction or 0 -- only from titles now
    local maxHPFlat = StatCalculator.BASE_HP * curve + (g.MaxHP or 0)
    local maxHPPct = g.MaxHPPct or 0
    local armorPct = g.ArmorPct or 0
    local regenPct = g.HPRegenPct or 0
    local allRes = g.AllResist or 0
    local fireRes = (g.FireResist or 0) + allRes
    local coldRes = (g.ColdResist or 0) + allRes
    local chaosRes = (g.ChaosResist or 0) + allRes
    local maxResist = StatCalculator.BASE_MAX_RESIST
    local def = DefNew() -- (UPDATE 8 DEFENCE: Plating / Agility / Ward / typed resists; one table, Calculate is near the local limit)
    for k in pairs(DEF_STAT) do if g[k] then DefApply(def, k, g[k]) end end
    local ailmentChance = g.AilmentChance or 0 -- (Luck's share is added once, capped, at the end)
    local ailmentDuration = g.AilmentDuration or 0
    local burnDamage = g.BurnDamage or 0
    local freezeEffect = g.FreezeEffect or 0
    local bleedDamage = g.BleedDamage or 0
    local decayEffect = g.DecayEffect or 0
    local explosionDamage = g.ExplosionDamage or 0
    local moreFireRate = 1.0
    local moreMaxHP = 1.0
    local moreArmor = 1.0
    local moreCritChance = 1.0
    local bodyShotMult = 1.0
    local leechMore = 1.0
    local hpRegen = curve + (g.HPRegen or 0)
    local meleeDamage = (12 + totalStr * 0.5) * curve
    local streakDamageBase = 0.02
    local moreDamageMult = 1.0
    local moreWeakSpotMult = 1.0
    local recoilMultiplier = 1.0
    local lifeLeechPct = g.LifeLeech or 0
    local blastRadiusMult = 1.0
    local streakMultBonus = 0
    local specialMechanics: { [string]: boolean } = {}
    local weaponGroup = ItemData.WeaponGroupOf(weapon) -- (weapon-type stats + class passives; launchers have none)
    local _ = WEAPON_GROUP
    -- CLASS GUN (weapon classes, 2026-10-05): class passives (keystones with Group) and the ascendancy only work while
    -- you hold a gun of that group -- any gun can be used, off-class guns just don't get them
    local classGroup = type(progress) == "table" and ClassData.GroupOf(progress.Class) or nil
    local classGun = classGroup ~= nil and classGroup == weaponGroup
    local heavyGun = ItemData.IsHeavyGun(weapon) -- ("Heavy" stats: heavy classes + any gun firing 3 times a second or slower)
    local meleePct = 0
    -- (UPDATE 8 OFFENSE) the new typed offence stats from every source (DamageTypes.OFFENCE_STATS; uncapped)
    local offT: { [string]: number } = {}
    for k in pairs(DamageTypes.OFFENCE_STATS) do if g[k] then offT[k] = g[k] end end

    -- ===== Weapon + its affixes =====
    local weaponDamage = (weapon and weapon.BaseDamage or 1) * (weapon and ItemData.GunTune(weapon) or 1) * (1 + ItemData.UPGRADE_DAMAGE_PER_LEVEL * (weapon and weapon.UpgradeLevel or 0))
    local affixes = {}
    if weapon then
        for _, list in ipairs({ weapon.Prefixes or {}, weapon.Suffixes or {} }) do
            for _, a in ipairs(list) do table.insert(affixes, a) end
        end
        -- (UPDATE 7 RIFTMODS: a fitted mod's lines count like the gun's own affixes -- the gear-layer ceilings)
        if type(weapon.Riftmod) == "table" then for _, a in ipairs(weapon.Riftmod.Lines or {}) do table.insert(affixes, a) end end
    end
    local weaponCond: { [string]: number } = {}
    for _, affix in ipairs(affixes) do
        local s, v = affix.Stat, affix.Value
        if s == "IncreasedDamage" then incDamage += v
        elseif s == "FireRateBonus" then incFireRate += v
        elseif s == "CritChance" then critChance += v
        elseif s == "CritMultiplier" then critMultiplier += v
        elseif s == "WeakSpotMultiplier" then flatWeakSpot += v
        elseif s == "MagSizeBonus" then magSizeBonus += v
        elseif s == "ReloadSpeedBonus" then reloadSpeedBonus += v
        elseif s == "StreakDamageBonus" then streakDamageBase += v
        elseif s == "AilmentChance" then ailmentChance += v
        elseif s == "RecoilControl" or s == "AilmentDuration" then ailmentDuration += v -- (old recoil rolls count as duration)
        elseif s == "LifeLeech" then lifeLeechPct += v
        elseif s == "LootLuck" then lootLuck += v
        elseif IS_COND[s] then weaponCond[s] = (weaponCond[s] or 0) + v -- (precision affixes: chain kills, overkill...)
        elseif DamageTypes.OFFENCE_STATS[s] then offT[s] = (offT[s] or 0) + v -- (UPDATE 8 OFFENSE: typed lines on the gun)
        elseif s == "HybridKineticCrit" then -- (phase 2 hybrid gun mod: local Kinetic + a share as crit chance)
            offT.LocalKinetic = (offT.LocalKinetic or 0) + v
            critChance += v * (ItemData.HYBRID_CRIT or 0.25)
        end
    end

    -- ===== LAYERS: everything so far is attributes + gear lines + weapon affixes; snapshot it, split off your own points =====
    local layer0 = {
        Damage = incDamage, FireRate = incFireRate, CritChance = critChance - StatCalculator.BASE_CRIT_CHANCE,
        CritMulti = critMultiplier - StatCalculator.BASE_CRIT_MULT, WeakSpot = flatWeakSpot, MaxHP = maxHPPct, Armor = armorPct,
        MoveSpeed = moveSpeed, Reload = reloadSpeedBonus, MagSize = magSizeBonus, Luck = lootLuck, Gold = goldBonus,
        Leech = lifeLeechPct, Regen = regenPct, AilChance = ailmentChance, AilDuration = ailmentDuration, Burn = burnDamage,
        Freeze = freezeEffect, Bleed = bleedDamage, Decay = decayEffect, Explosion = explosionDamage, Streak = streakDamageBase - 0.02,
    }
    local attrPart = {} -- (phase 4: no hand-placed attribute layer any more)

    -- ===== Passive tree + gems (every node stat maps onto a character-sheet stat) =====
    local cond: { [string]: number } = {}
    for _, k in ipairs(COND_STATS) do cond[k] = (weaponCond[k] or 0) + (g[k] or 0) end -- (weapon affixes + gear lines)
    local condGear = table.clone(cond)
    local moreExplosion, bleedMore = 1.0, 1.0
    local function ApplyStat(statName: string, v: number)
        local gs = GROUP_STAT[statName]
        if gs then
            if gs[1] == weaponGroup then ApplyStat(gs[2], v) end
            return
        end
        if IS_COND[statName] then cond[statName] += v
        elseif StatCalculator.CEIL_STATS[statName] then
            if noCeil then return end
            local ck = StatCalculator.CEIL_STATS[statName]
            CEIL_BONUS[ck] = math.max(CEIL_BONUS[ck] or 0, v) -- (the same stat doesn't stack)
            CEIL_N[ck] = (CEIL_N[ck] or 0) + 1
        elseif DamageTypes.OFFENCE_STATS[statName] then offT[statName] = (offT[statName] or 0) + v -- (UPDATE 8 OFFENSE)
        elseif statName == "MeleeDamagePct" then meleePct += v
        elseif statName == "IncreasedDamage" then incDamage += v
        elseif statName == "FireRateBonus" then incFireRate += v
        elseif statName == "CritChance" then critChance += v
        elseif statName == "CritMultiplier" then critMultiplier += v
        elseif statName == "WeakSpotMultiplier" then flatWeakSpot += v
        elseif statName == "StreakDamageBonus" then streakDamageBase += v
        elseif statName == "MagSizeBonus" then magSizeBonus += v
        elseif statName == "ReloadSpeedBonus" then reloadSpeedBonus += v
        elseif statName == "RecoilControl" then recoilMultiplier *= math.max(0.2, 1 - v)
        elseif statName == "MovementSpeed" then moveSpeed += v
        elseif statName == "MaxHPPct" then maxHPPct += v
        elseif statName == "ArmorPct" then armorPct += v
        elseif statName == "BaseArmor" then armor += v * curve
        elseif statName == "HPRegenPct" then regenPct += v
        elseif statName == "FireResist" then fireRes += v
        elseif statName == "ColdResist" then coldRes += v
        elseif statName == "ChaosResist" then chaosRes += v
        elseif statName == "AllResist" then fireRes += v; coldRes += v; chaosRes += v
        elseif statName == "MaxResist" then maxResist += v
        elseif DEF_STAT[statName] then DefApply(def, statName, v) -- (UPDATE 8 DEFENCE)
        elseif statName == "LifeLeech" then lifeLeechPct += v
        elseif statName == "AilmentChance" then ailmentChance += v
        elseif statName == "AilmentDuration" then ailmentDuration += v
        elseif statName == "BurnDamage" then burnDamage += v
        elseif statName == "FreezeEffect" then freezeEffect += v
        elseif statName == "BleedDamage" then bleedDamage += v
        elseif statName == "DecayEffect" then decayEffect += v
        elseif statName == "ExplosionDamage" then explosionDamage += v
        elseif statName == "LootLuck" then lootLuck += v
        elseif statName == "GoldBonus" then goldBonus += v
        elseif statName == "Strength" or statName == "Vitality" then totalStr += v; meleeDamage += v * 0.5 * curve -- (phase 4: bonuses at the end)
        elseif statName == "Dexterity" then totalDex += v
        elseif statName == "Intellect" or statName == "Luck" then totalInt += v
        elseif statName == "AllAttributes" then totalStr += v; totalDex += v; totalInt += v
        -- keystone multipliers ("MORE" = multiplicative, separate from the additive "increased" pools)
        elseif statName == "MoreDamage" then moreDamageMult *= (1 + v)
        elseif statName == "MoreFireRate" then moreFireRate *= (1 + v)
        elseif statName == "MoreMaxHP" then moreMaxHP *= (1 + v)
        elseif statName == "MoreArmor" then moreArmor *= (1 + v)
        elseif statName == "MoreWeakSpotDamage" then moreWeakSpotMult *= (1 + v)
        elseif statName == "MoreCritChance" then moreCritChance *= (1 + v)
        elseif statName == "BodyShotMore" then bodyShotMult *= (1 + v)
        elseif statName == "LeechMore" then leechMore *= (1 + v)
        elseif statName == "BurnMore" then burnDamage = (1 + burnDamage) * (1 + v) - 1
        elseif statName == "MoreExplosion" then moreExplosion *= (1 + v)
        elseif statName == "BleedMore" then bleedMore *= (1 + v)
        end
    end

    local allocatedSet: { [string]: boolean } = {}
    for _, id in ipairs(allocatedNodeIds or {}) do allocatedSet[id] = true end
    local gemFx = GemData.Effects(socketedGems, allocatedSet)
    local ironWillHP = 0
    -- (0.49 PASSIVES: only EQUIPPED passive skills work; no list = every allocated one -- old saves / dev sims)
    local eqPassives: { [string]: boolean }? = nil
    if type(progress) == "table" and type(progress.EquippedPassives) == "table" then
        eqPassives = {}
        for _, id in ipairs(progress.EquippedPassives) do eqPassives[id] = true end
    end
    for nodeId in pairs(allocatedSet) do
        local node = SkillTreeData[nodeId]
        if node and node.Group and node.Group ~= weaponGroup then node = nil end -- (a class passive: only with its guns)
        if node and eqPassives and node.Type == "Keystone" and not eqPassives[nodeId] then node = nil end
        if node then
            if node.SpecialMechanic then specialMechanics[node.SpecialMechanic] = true end
            local mult = gemFx.NodeMult[nodeId] or 1
            local glass = gemFx.GlassLens[nodeId]
            local boost = gemFx.StatBoost and gemFx.StatBoost[nodeId]
            for statName, v in pairs(node.Stats) do
                local val = v * mult * (1 + (boost and boost[statName] or 0))
                if statName == "Strength" or statName == "Dexterity" or statName == "Intellect" or statName == "Vitality" or statName == "Luck" or statName == "BaseArmor" then
                    val = math.round(val)
                end
                if glass and GemData.DefensiveStats[statName] then
                    incDamage += val * 0.75 -- Glass Lens: defense becomes damage
                else
                    ApplyStat(statName, val)
                    if gemFx.IronWill[nodeId] and statName == "MaxHPPct" then ironWillHP += val end
                    -- Calibrated Scope: damage nodes also add weak-spot damage
                    if gemFx.Calibrated and gemFx.Calibrated[nodeId] and statName == "IncreasedDamage" then flatWeakSpot += val end
                end
            end
        end
    end
    incDamage += ironWillHP -- Iron Will: health nodes in its radius also add damage
    for statName, v in pairs(gemFx.Flat) do ApplyStat(statName, v) end
    for statName, v in pairs(Progression.StatsFor(progress, weapon)) do ApplyStat(statName, v) end
    if BoonData.ON == false then runBoons = nil end -- (UPDATE 8 Phase 5 LOOT/RUN: boons are cut; the parameter stays)
    for _, boonId in ipairs(runBoons or {}) do
        local b = BoonData.ById[boonId]
        if b then for statName, v in pairs(b.Stats) do ApplyStat(statName, v) end end
    end
    -- boon combos (BoonData.Combos): both halves held -> the combo's stats on top
    for _, combo in ipairs(BoonData.ActiveCombos(runBoons)) do
        for statName, v in pairs(combo.Stats) do ApplyStat(statName, v) end
    end
    for mech in pairs(gemFx.Mechanics) do specialMechanics[mech] = true end
    -- ===== ASCENDANCY (tree v4): the chosen ascendancy's allocated nodes. Stats apply here; Fx go to combat
    -- (CombatServer reads stats.AscFx); timed effects live in state.AscBuffs ([nodeId:i] = { U = server time, N = stacks })
    -- and add their Stats x stacks while they last. Special stats: MaxFocus, AttrDamage, BalancedMore, TakenLess.
    local ascFx: { any } = {}
    local ascMaxFocus, ascAttrDamage, ascBalanced, ascTakenLess = 0, 0, 0, 0
    if classGun and type(progress) == "table" and progress.Ascendancy and type(progress.AscNodes) == "table" then
        local now = workspace:GetServerTimeNow()
        local buffs = type(progress.AscBuffs) == "table" and progress.AscBuffs or {}
        local function AscStat(statName: string, v: number)
            if statName == "MaxFocus" then ascMaxFocus += v
            elseif statName == "AttrDamage" then ascAttrDamage += v
            elseif statName == "BalancedMore" then ascBalanced += v
            elseif statName == "TakenLess" then ascTakenLess = 1 - (1 - ascTakenLess) * (1 - v)
            else ApplyStat(statName, v) end
        end
        for _, node in ipairs(AscendancyData.Active(progress)) do
            for statName, v in pairs(node.Stats) do AscStat(statName, v) end
            for i, fx in ipairs(node.Fx) do
                local key = node.Id .. ":" .. i
                table.insert(ascFx, { Fx = fx, Key = key })
                local b = fx.Stats and buffs[key]
                if b and (b.U or 0) > now and (b.N or 0) > 0 then
                    for statName, v in pairs(fx.Stats) do AscStat(statName, v * b.N) end
                end
            end
        end
    end
    -- ===== TREE EFFECTS (2026-10-22): mechanic notables (node.Fx) + EXPERTISE picks (state.Expertise[nodeId] = effect id,
    -- ExpertiseData). Unlike the specialization these work with any gun (a "Group:<type>" When limits one to that gun).
    -- Expertise Stats go into the tree layer like node stats; Fx join stats.AscFx (keys "T:<node>:i" / "X:<effect>:i")
    -- and their timed buffs live in state.AscBuffs too.
    do
        local now = workspace:GetServerTimeNow()
        local buffs = type(progress) == "table" and type(progress.AscBuffs) == "table" and progress.AscBuffs or {}
        local function AddFx(list, prefix)
            for i, fx in ipairs(list) do
                local key = prefix .. ":" .. i
                table.insert(ascFx, { Fx = fx, Key = key })
                local b = fx.Stats and buffs[key]
                if b and (b.U or 0) > now and (b.N or 0) > 0 then
                    for statName, v in pairs(fx.Stats) do ApplyStat(statName, v * b.N) end
                end
            end
        end
        for nodeId in pairs(allocatedSet) do
            local node = SkillTreeData[nodeId]
            if node and node.Fx and node.Type == "Notable" then AddFx(node.Fx, "T:" .. nodeId) end
        end
        local picks = type(progress) == "table" and type(progress.Expertise) == "table" and progress.Expertise or nil
        if picks then
            local seen = {}
            for nodeId, effId in pairs(picks) do
                local node = SkillTreeData[nodeId]
                local e = type(effId) == "string" and ExpertiseData.Effects[effId]
                local held = false
                if node and node.Type == "Expertise" and e and e.Family == node.Family and not seen[effId] then
                    for _, nid in ipairs(node.Ring or {}) do if allocatedSet[nid] then held = true break end end
                end
                if held then
                    seen[effId] = true
                    for statName, v in pairs(e.Stats) do ApplyStat(statName, v) end
                    if e.Fx then AddFx(e.Fx, "X:" .. effId) end
                end
            end
        end
    end
    -- ===== tree v4 keystones (stat-only: the weapon-type conditions live here; unconditional parts are node Stats) =====
    local function Weapon(group) return weaponGroup == group or (group == "Heavy" and heavyGun) end
    -- (2026-10-05 GUN-AGNOSTIC TREE: these six keystones were tied to a weapon type; their damage conditions are about
    -- how you shoot now and live in CombatServer's hit (range / reload / standing still / magazine). Only the
    -- unconditional parts stay here.)
    local _ = Weapon
    if specialMechanics["SIDEARM"] then reloadSpeedBonus += 0.2 end
    if specialMechanics["SPRAY_AND_PRAY"] then moreFireRate *= 1.1; magSizeBonus += 0.3 end
    if specialMechanics["ASSAULT_DOCTRINE"] then moreFireRate *= 1.05 end
    if specialMechanics["BONECRUSHER"] then meleePct += 0.6 end
    if specialMechanics["MIDAS_TOUCH"] then moreDamageMult *= 0.9 end
    if specialMechanics["SURGEON"] then moreWeakSpotMult *= 1.25 end
    -- High Caliber: guns that don't pierce deal less
    if specialMechanics["HIGH_CALIBER"] and not ItemData.PierceOf(weapon) then moreDamageMult *= 0.9 end
    -- Titan's Might: part of your increased max health also counts as increased damage.
    if cond.HPToDamage > 0 then incDamage += math.max(0, maxHPPct) * cond.HPToDamage end
    -- ascendancy attribute notables (Savant): damage per total attribute point; MORE damage while balanced
    if ascAttrDamage > 0 then incDamage += (totalStr + totalDex + totalInt) * ascAttrDamage end
    if ascBalanced > 0 then
        local hi = math.max(totalStr, totalDex, totalInt)
        local lo = math.min(totalStr, totalDex, totalInt)
        if hi - lo <= 20 then moreDamageMult *= (1 + ascBalanced) end
    end
    if classGun then moreDamageMult *= StatCalculator.ClassBoost(classGroup, lvl) * StatCalculator.ClassEdge(classGroup, lvl) * (StatCalculator.CLASS_LEAN[classGroup] or 1) end -- (2026-10-21 CLASS BALANCE: per class gun group; CLASS LEANS)
    -- class passives that cut damage taken (CombatServer DamagePlayer reads AscTakenLess)
    if specialMechanics["P_IRON_FRAME"] then ascTakenLess = 1 - (1 - ascTakenLess) * 0.75 end -- (0.62 playstyle passives)
    if specialMechanics["P_THICK_SKIN"] then ascTakenLess = 1 - (1 - ascTakenLess) * 0.88 end
    if specialMechanics["U_GLASS"] then ascTakenLess = 1 - (1 - ascTakenLess) * 1.4 end -- (Glass Cannon: 40% more taken)
    explosionDamage = (1 + explosionDamage) * moreExplosion - 1
    bleedDamage = (1 + bleedDamage) * bleedMore - 1
    blastRadiusMult *= (1 + cond.ExplosionRadiusPct)

    -- ===== Title =====
    if equippedTitle then
        local tData = ItemData.Titles[equippedTitle]
        if tData and tData.StatBuffs then
            for sName, sVal in pairs(tData.StatBuffs) do
                if sName == "IncreasedDamage" then incDamage += sVal
                elseif sName == "MaxHP" then maxHPFlat += sVal * curve
                elseif sName == "MovementSpeed" then moveSpeed += sVal
                elseif sName == "FireRateBonus" then incFireRate += sVal
                elseif sName == "WeakSpotMultiplier" then flatWeakSpot += sVal
                elseif sName == "CritChance" then critChance += sVal
                elseif sName == "CritMultiplier" then critMultiplier += sVal
                elseif sName == "ReloadSpeedBonus" then reloadSpeedBonus += sVal
                elseif sName == "Armor" then armor += sVal * curve
                elseif sName == "DamageReduction" then drBonus += sVal
                elseif sName == "GoldBonus" then goldBonus += sVal
                elseif sName == "Luck" then lootLuck += sVal
                elseif sName == "HPRegen" then hpRegen += sVal * curve
                elseif sName == "MagSizeBonus" then magSizeBonus += sVal
                elseif sName == "MeleeDamage" then meleeDamage += sVal * 0.1 * curve
                end
            end
        end
    end

    do -- (UPDATE 8 OFFENSE phase 4) the attributes' built-in bonuses (tree layer: no ceiling)
        local B = StatCalculator.ATTR_BONUS
        maxHPPct += totalStr * B.StrLife
        armorPct += totalStr * B.StrPlating
        DefApply(def, "AgilityPct", totalDex * B.DexAgility)
        critChance += totalDex * B.DexCrit
        DefApply(def, "WardPct", totalInt * B.IntWard)
        offT.ElementalDamage = (offT.ElementalDamage or 0) + totalInt * B.IntElemental
        StatCalculator._ATTRS = { Strength = totalStr, Dexterity = totalDex, Intellect = totalInt } -- (shot mod requirements)
    end
    -- ===== STAT CEILINGS (see StatCalculator.CEILINGS): every stacked total against your level's cap =====
    -- (each source against its own cap, then added: tree = total - the attribute + gear layer, attributes = your points,
    -- gear = the rest of that layer)
    local ceilings = {}
    local function Cap(key: string, total: number, snap: number?, attr: number?, capKey: string?): number
        capKey = capKey or key
        local a = math.max(0, attr or 0)
        local gpart = (snap or 0) - a
        local tree = total - (snap or 0)
        local capT = StatCalculator.CeilingCap(capKey, lvl) * (1 + (CEIL_BONUS[capKey] or 0)) -- (CEILING NOTABLES)
        local capA = StatCalculator.CeilingCap(capKey, lvl, "Attr")
        local capG = StatCalculator.CeilingCap(capKey, lvl, "Gear")
        local eT, eA, eG = StatCalculator.SoftCap(tree, capT), StatCalculator.SoftCap(a, capA), StatCalculator.SoftCap(gpart, capG)
        local v = eT + eA + eG
        if total > 0 then
            local prev = ceilings[key]
            if not prev or total > prev.Raw then
                ceilings[key] = { Raw = total, Eff = v, Cap = (capT ~= math.huge and capT or 0) + (capA ~= math.huge and capA or 0) + (capG ~= math.huge and capG or 0),
                    Tree = { tree, eT, capT }, Attr = { a, eA, capA }, Gear = { gpart, eG, capG } }
            end
        end
        return v
    end
    local L0, AP = layer0, attrPart
    incDamage = Cap("Damage", incDamage, L0.Damage, AP.Damage)
    incFireRate = Cap("FireRate", incFireRate, L0.FireRate, AP.FireRate)
    critChance = StatCalculator.BASE_CRIT_CHANCE + Cap("CritChance", critChance - StatCalculator.BASE_CRIT_CHANCE, L0.CritChance, AP.CritChance)
    critMultiplier = StatCalculator.BASE_CRIT_MULT + Cap("CritMulti", critMultiplier - StatCalculator.BASE_CRIT_MULT, L0.CritMulti)
    flatWeakSpot = Cap("WeakSpot", flatWeakSpot, L0.WeakSpot)
    maxHPPct = Cap("MaxHP", maxHPPct, L0.MaxHP, AP.MaxHP)
    armorPct = Cap("Armor", armorPct, L0.Armor)
    moveSpeed = Cap("MoveSpeed", moveSpeed, L0.MoveSpeed)
    reloadSpeedBonus = Cap("Reload", reloadSpeedBonus, L0.Reload, AP.Reload)
    magSizeBonus = Cap("MagSize", magSizeBonus, L0.MagSize)
    lootLuck = Cap("Luck", lootLuck, L0.Luck, AP.Luck)
    goldBonus = Cap("Gold", goldBonus, L0.Gold)
    lifeLeechPct = Cap("Leech", lifeLeechPct, L0.Leech)
    regenPct = Cap("Regen", regenPct, L0.Regen)
    ailmentChance = Cap("AilChance", ailmentChance, L0.AilChance)
    ailmentDuration = Cap("AilDuration", ailmentDuration, L0.AilDuration)
    burnDamage = Cap("Burn", burnDamage, L0.Burn, nil, "AilPower")
    freezeEffect = Cap("Freeze", freezeEffect, L0.Freeze, nil, "AilPower")
    bleedDamage = Cap("Bleed", bleedDamage, L0.Bleed, nil, "AilPower")
    decayEffect = Cap("Decay", decayEffect, L0.Decay, nil, "AilPower")
    explosionDamage = Cap("Explosion", explosionDamage, L0.Explosion, nil, "AilPower")
    streakDamageBase = 0.02 + Cap("Streak", streakDamageBase - 0.02, L0.Streak)
    for k, v in pairs(cond) do
        if type(v) == "number" and v > 0 then
            if string.sub(k, -6) == "Damage" then cond[k] = Cap(k, v, condGear[k] or 0, nil, "CondDamage")
            elseif string.sub(k, -5) == "OnHit" then cond[k] = Cap(k, v, condGear[k] or 0, nil, "OnHit") end
        end
    end

    -- ===== Keystones =====
    local maxFocus = 25
    local effectiveStreakBonus = streakDamageBase
    if specialMechanics["PERFECTIONIST"] then
        effectiveStreakBonus *= 1.5
        maxFocus = 35
    end
    if specialMechanics["ETERNAL_FOCUS"] then maxFocus += 15 end
    maxFocus += ascMaxFocus
    effectiveStreakBonus *= (1 + streakMultBonus)
    local streakMultiplier = 1 + (math.min(maxFocus, currentStreak or 0) * effectiveStreakBonus)
    armor = math.max(0, (armor + def.Plat) * (1 + armorPct + def.PlatInc) * moreArmor * def.PlatMore) -- (UPDATE 8 DEFENCE: = Plating)
    lifeLeechPct *= leechMore

    -- (UPDATE 8 OFFENSE phase 3) SHOT MODS: the gun's active linked group (ShotMods.Compile; uncapped, PoE support rules):
    -- more / less damage, typed offence stats, cond stats (Execute / Overkill); fire rate + magazine after the caps below;
    -- the shot mechanics (chain, fork, blasts ...) go to CombatServer as stats.ShotFx. Kept in a field (Calculate's locals are full).
    do
        local sm = StatCalculator.ShotMods.Compile(weapon, lvl, StatCalculator._ATTRS) -- (a mod works at most at ShotMods.LevelCap(your level))
        StatCalculator._SM = sm
        moreDamageMult *= sm.More
        for k, x in pairs(sm.Off) do offT[k] = (offT[k] or 0) + x end
        for k, x in pairs(sm.Cond) do cond[k] = (cond[k] or 0) + x end
        -- (phase 4) the tree's area stats + the Cornerstones that change what a shot DOES, written into the shot's Fx
        -- (AreaDamage = more on every extra hit, AreaRadius = wider bursts / longer hops, ExtraChains = +n Chain hops)
        local fx = sm.Fx
        for _, k in ipairs({ "Chain", "Fork", "Volley", "Ricochet", "Impact", "Detonate", "Mark" }) do
            if type(fx[k]) == "table" then fx[k] = table.clone(fx[k]) end
        end
        if specialMechanics["K_BANK_SHOT"] then -- Bank Shot: +1 chain hop (one at 30% without a Chain mod), chains re-hit
            fx.Chain = fx.Chain or { N = 0, Pct = 0.30, R = 30 }
            fx.Chain.N += 1
            fx.Rehit = true
        end
        if specialMechanics["K_SHRAPNEL"] then -- Shrapnel: every hit bursts for 12% round it ((CLASS BUILDS) balance: 30% -> 12%)
            fx.Impact = fx.Impact or { R = 8, Pct = 0 }
            fx.Impact.Pct += 0.12
        end
        if specialMechanics["K_GLACIAL"] then fx.FreezeBuild = (fx.FreezeBuild or 1) * 2 end -- Glacial Shells
        if specialMechanics["K_TRICK_SHOT"] then fx.Carom = { R = StatCalculator.CBCorner.CAROM_R, Pct = StatCalculator.CBCorner.CAROM_PCT } end -- (CLASS BUILDS) CORNERSTONE: Carom Shot
        if next(fx) ~= nil then
            if (cond.ExtraChains or 0) > 0 and fx.Chain then fx.Chain.N += math.floor(cond.ExtraChains) end
            local r = 1 + math.max(-0.5, cond.AreaRadius or 0)
            for _, k in ipairs({ "Chain", "Fork", "Volley", "Ricochet", "Impact", "Detonate", "Mark" }) do
                if fx[k] and fx[k].R then fx[k].R *= r end
            end
            if (cond.AreaDamage or 0) ~= 0 then fx.AreaMult = (fx.AreaMult or 1) * math.max(0.1, 1 + cond.AreaDamage) end
        end
        if specialMechanics["K_LONE_ROUND"] then moreDamageMult *= 1.3 end -- Lone Round (magazine + reload below; Phase 6: 1.8 -> 1.3, on bolt rifles the 2x reload hid inside the shot gap)
    end
    StatCalculator.SigStats(ascFx, StatCalculator._SM.Fx) -- (CLASS BUILDS) SIGNATURE: Cryostasis

    -- ===== Final =====
    -- (UPDATE 8 OFFENSE) the hit is typed now: StatCalculator.TypedHit; a plain Kinetic gun = exactly the old number
    local typedHit = StatCalculator.TypedHit(weapon, weaponDamage, offT, incDamage, moreDamageMult * streakMultiplier)
    local finalDamage = DamageTypes.Sum(typedHit)
    -- fire rate keeps each gun's feel: increased fire rate past +40% counts at 35%, and the total stops at +80%
    -- (it used to stack freely -- every gun ended up a minigun)
    local effInc = incFireRate -- (STAT CEILINGS: already capped by your level -- the old +40% soft / +80% hard cap is gone)
    -- (2026-10-07) full-auto guns (7+ shots a second) get 60% of any increased fire rate and at most x1.15 "more": a
    -- 15 / s SMG used to reach ~28 / s by level 100 and ~47 / s at 400; now ~19 / s and ~27 / s
    local baseFR = weapon and weapon.BaseFireRate or 1
    if baseFR >= StatCalculator.AUTO_FIRE_RATE and effInc > 0 then effInc *= StatCalculator.AUTO_FR_SHARE end
    local moreCap = (baseFR >= StatCalculator.AUTO_FIRE_RATE) and 1.15 or 1.25
    local finalFireRate = math.clamp(baseFR * math.max(0.2, 1 + effInc) * math.min(moreFireRate, moreCap) * StatCalculator._SM.FireRate, 0.2, 30) -- (x shot mods)
    local finalWeakSpotMult = ((weapon and weapon.BaseWeakSpotMultiplier or 2.0) + flatWeakSpot) * moreWeakSpotMult
    local finalCritChance = math.clamp(critChance * moreCritChance, 0.01, 1.0)
    local finalCritMult = math.max(1.2, critMultiplier)
    local maxHP = maxHPFlat * math.max(0.25, 1 + maxHPPct) * moreMaxHP
    meleeDamage *= math.max(0.1, 1 + meleePct)
    hpRegen += maxHP * regenPct
    local noRegen = specialMechanics["BLOOD_PACT"] == true or specialMechanics["UNYIELDING"] == true
    if noRegen then hpRegen = 0 end
    -- (UPDATE 8 DEFENCE) Plating's cut of an ORDINARY hit (the sheet + sims; DamagePlayer uses PlatingReduction per hit).
    -- No level cap any more (was DamageReductionCap(lvl), 50% at L1 -> 75% at L400): at most PLATING_MAX.
    local damageReduction = math.clamp(armor / (armor + StatCalculator.PLATING_K * curve) + drBonus, 0, StatCalculator.PLATING_MAX)
    DefFinal(def, curve, fireRes, coldRes, chaosRes, maxResist)
    hpRegen += StatCalculator.SigRegen(ascFx, def.Out, maxHP, noRegen) -- (CLASS BUILDS) SIGNATURE: Overcap
    local moveSpeedMult = math.clamp(1.0 + moveSpeed, 0.7, 1.5)
    local finalMag = math.max(1, math.round((weapon and weapon.MagazineSize or 10) * (1 + magSizeBonus) * (1 + StatCalculator._SM.Mag))) -- (x shot mods)
    local finalReloadSpeed = math.clamp(1.0 + reloadSpeedBonus, 0.4, 2.5)
    do -- (UPDATE 8 OFFENSE phase 4) Cornerstones that change a rule (CombatServer reads AllWeak / Overload)
        if specialMechanics["K_LONE_ROUND"] then finalMag = 1; finalReloadSpeed *= 2 end
        if specialMechanics["K_POINT_OF_AIM"] then finalCritChance = 0 end
        finalDamage *= StatCalculator.CBCorner.SlugMult(specialMechanics, weapon, typedHit) -- (CLASS BUILDS) CORNERSTONE: Slug Rounds
        if specialMechanics["K_TRICK_SHOT"] then bodyShotMult *= StatCalculator.CBCorner.CAROM_BODY end -- (CLASS BUILDS) CORNERSTONE: Carom Shot
        if specialMechanics["K_WARD_BOUND"] then -- your life becomes Ward: 1 life, max health added to Ward
            def.Out.Ward = (def.Out.Ward or 0) + maxHP
            maxHP = 1; hpRegen = 0; lifeLeechPct = 0
        end
    end
    -- (CHASE ITEMS 2026-11-06) ZENITH rules that change a number (ItemData.ZENITH_TUNE; the rest is ZenithServer / ZenithClient)
    local zen = ItemData.ZenithActive and ItemData.ZenithActive(weapon, equippedGear) or nil
    if zen then
        local ZT = ItemData.ZENITH_TUNE
        if zen.GlassHalo then -- weak-spot BONUS x WeakBonus, body shots x Body
            finalWeakSpotMult = 1 + (finalWeakSpotMult - 1) * ZT.GlassHalo.WeakBonus
            bodyShotMult *= ZT.GlassHalo.Body
        end
        if zen.SaintsRicochet then -- half the magazine, reloads 40% longer
            finalMag = math.max(1, math.round(finalMag * ZT.SaintsRicochet.Mag))
            finalReloadSpeed /= ZT.SaintsRicochet.Reload
        end
        if zen.LongPromise then finalMag = 1 end -- one round
        for id in pairs(zen) do -- each Zenith's own "more damage" (ZENITH_TUNE[id].More; a card line)
            local m = ZT[id] and tonumber(ZT[id].More)
            if m then finalDamage *= m end
        end
    end

    return {
        -- Damage keeps 2 decimals: early-game guns deal single-digit damage, rounding would distort it.
        Damage = math.round(finalDamage * 100) / 100,
        FireRate = math.round(finalFireRate * 10) / 10,
        WeakSpotMultiplier = math.round(finalWeakSpotMult * 100) / 100,
        StreakBonusPerStack = math.round(effectiveStreakBonus * 1000) / 1000,
        CritChance = math.round(finalCritChance * 1000) / 1000,
        CritMultiplier = math.round(finalCritMult * 100) / 100,
        MaxHP = math.round(maxHP),
        Armor = math.round(armor),
        DamageReduction = math.round(damageReduction * 1000) / 1000,
        MovementSpeedMult = math.round(moveSpeedMult * 100) / 100,
        HPRegen = math.round(hpRegen * 10) / 10,
        GoldBonusMult = math.round((1 + goldBonus) * 100) / 100,
        LuckMultiplier = math.round((1 + lootLuck) * 100) / 100, -- (STAT CEILINGS "Luck": already diminished by your level's cap)
        MagazineSize = finalMag,
        ReloadSpeed = math.round(finalReloadSpeed * 100) / 100,
        MeleeDamage = math.round(meleeDamage * 10) / 10,
        LifeLeechPct = math.round(lifeLeechPct * 1000) / 1000,
        RecoilMultiplier = math.round(recoilMultiplier * 100) / 100,
        ExplosionRadius = weapon and weapon.ExplosionRadius and (weapon.ExplosionRadius * blastRadiusMult) or nil,
        BurstCount = weapon and weapon.BurstCount,
        PelletCount = (StatCalculator.CBCorner.IsSlug(specialMechanics, weapon) and 1) or (weapon and weapon.PelletCount), -- ((CLASS BUILDS) Slug Rounds: one slug)
        Slug = StatCalculator.CBCorner.IsSlug(specialMechanics, weapon), -- ((CLASS BUILDS) CORNERSTONE: cbguns' FAM_POINTBLANK / per-pellet lines skip it)
        IsContinuousBeam = weapon and weapon.IsContinuousBeam,
        SpecialMechanics = specialMechanics,
        AllWeak = specialMechanics["K_POINT_OF_AIM"] == true, Overload = specialMechanics["K_OVERLOAD"] == true, -- (phase 4)
        UniqueTrait = weapon and weapon.UniqueTrait,
        DamageBonusPct = math.round(incDamage * 100) / 100,
        FireRateBonusPct = math.round(incFireRate * 100) / 100,
        TotalStrength = totalStr,
        TotalDexterity = totalDex,
        TotalVitality = 0, -- (phase 4: gone)
        TotalLuck = 0,
        TotalIntellect = totalInt, -- (phase 4)
        StreakMultiplier = math.round(streakMultiplier * 100) / 100,
        FireResist = math.round(def.Out.Heat * 1000) / 1000, -- (old names = the new Heat / Cryo / Void totals)
        ColdResist = math.round(def.Out.Cryo * 1000) / 1000,
        ChaosResist = math.round(def.Out.Void * 1000) / 1000,
        MaxResist = math.clamp(maxResist, 0.5, 0.9),
        -- (UPDATE 8 DEFENCE) the new defences: Plating (= Armor) + its per-hit scale, Agility + evade chance vs an ordinary
        -- hit, max Ward + recharge, typed resists + their caps (StatCalculator.EffectiveResist adds the difficulty penalty)
        Plating = math.round(armor), PlatingScale = StatCalculator.PLATING_K * curve, DRBonus = drBonus,
        Agility = math.round(def.Out.Agility), EvadeChance = math.round(def.Out.Evade * 1000) / 1000,
        Ward = math.round(def.Out.Ward), WardRate = def.Out.WardRate, WardDelay = def.Out.WardDelay,
        HeatResist = math.round(def.Out.Heat * 1000) / 1000, CryoResist = math.round(def.Out.Cryo * 1000) / 1000,
        VoltResist = math.round(def.Out.Volt * 1000) / 1000, VoidResist = math.round(def.Out.Void * 1000) / 1000,
        MaxHeatResist = def.Out.MaxHeat, MaxCryoResist = def.Out.MaxCryo, MaxVoltResist = def.Out.MaxVolt, MaxVoidResist = def.Out.MaxVoid,
        PlatingVsElements = def.PlatingVsElements or 0, WardVsVoid = def.WardVsVoid or 0, VoltCanFreeze = def.VoltCanFreeze or 0, -- (GEAR v3 build lines)
        MovingWard = def.MovingWard or 0, -- (relic Wardstep)
        AilmentChance = ailmentChance,
        AilmentDuration = ailmentDuration,
        BurnDamage = (1 + burnDamage) * (StatCalculator._SM.AilMore.Heat or 1) - 1, -- (x shot mods' Burn more)
        FreezeEffect = freezeEffect,
        BleedDamage = (1 + bleedDamage) * (StatCalculator._SM.AilMore.Kinetic or 1) - 1,
        DecayEffect = decayEffect,
        ExplosionDamage = explosionDamage,
        BodyShotMult = bodyShotMult,
        MaxFocusStacks = maxFocus,
        NoRegen = noRegen,
        MaxHPPct = maxHPPct,
        ArmorPct = armorPct,
        ExplosionRadiusMult = blastRadiusMult,
        CeilNotables = table.clone(CEIL_N), -- (CEILING NOTABLES: how many of each row the build has; only one counts)
        Ceilings = ceilings, -- STAT CEILINGS: { [key] = { Raw, Cap, Eff } } for every total that hit a cap
        Cond = cond, -- conditional / mechanic stats (BurnOnHit, SwitchDamage, KillHeal...), see COND_STATS
        AscFx = ascFx, -- ascendancy effects for combat: { { Fx = <AscendancyData Fx>, Key = "nodeId:i" } }
        AscTakenLess = ascTakenLess, -- damage taken less from active ascendancy buffs (DamagePlayer)
        -- (UPDATE 8 OFFENSE) typed damage: the hit per type (before crit / weak spot / enemy resists), its shares, the main
        -- type (damage numbers), ailment chance stats per type, Shock / Wither effect, the raw typed stats (cards)
        DamageByType = (function() local o = {} for k, v in pairs(typedHit) do o[k] = math.round(v * 100) / 100 end return o end)(),
        DamageShares = DamageTypes.Shares(typedHit),
        DamageType = DamageTypes.MainType(typedHit),
        AilChanceByType = (function()
            local o = {}
            for t, s in pairs(DamageTypes.AIL_CHANCE_STAT) do o[t] = offT[s] or 0 end
            o.Cryo += offT.FreezeChance or 0
            return o
        end)(),
        ShockEffect = offT.ShockEffect or 0,
        WitherEffect = offT.WitherEffect or 0,
        Offence = offT,
        -- (UPDATE 8 OFFENSE phase 3) shot mods: mechanics for CombatServer.Off.ShotModFx, the active mods' names, their total more
        ShotFx = StatCalculator._SM.Fx, ShotMods = StatCalculator._SM.List, ShotModMore = StatCalculator._SM.More,
        GunFamily = ItemData.FamilyOf and (ItemData.FamilyOf(weapon)) or nil, -- (CLASS BUILDS) FAMILY: the gun's family id (its line: CombatServer.CB.Family)
        ClassGun = classGun and classGroup or nil, -- (BALANCE PASS 2026-10-23) the class gun group you hold as your class (Marksman LONG CARRY reads it)
        Zenith = zen, -- (CHASE ITEMS) { [zenith id] = true } for the gun + worn gear, or nil
    }
end

return StatCalculator
