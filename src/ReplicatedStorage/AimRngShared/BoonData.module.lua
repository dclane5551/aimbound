--!nocheck
-- ============================================================================================
-- RUN BOONS (roguelite run power-ups, Hades-style). Offered by Boon Shrines (a dungeon event, DungeonEvents)
-- and by boss floors -- a handful per run, not every room. Pick 1 of 3 (keys 1/2/3). They last the run
-- (until you leave or die solo), cap at MAX_BOONS, and every boon held makes enemies HEAT_PER_BOON tougher.
-- Rarities: Common (plain stats), Rare (mechanics: on-hit ailments, conditional damage), Epic (big
-- mechanics), Cursed (a strong upside with a real downside). Boss floors (every 5th) roll better offers.
-- Stats use the same names as the passive tree (StatCalculator ApplyStat / COND_STATS).
-- ============================================================================================
local BoonData = {}
-- (UPDATE 8 "The Revamp" Phase 5, owner: "Boons and boon combos are cut ... All power now comes from your build and gear"):
-- ON = false -> nothing offers boons (CombatServer.OfferBoons / the merchant), StatCalculator ignores RunBoons, no boon heat,
-- no Boon Shrine, BLESSED doesn't roll. The data stays (old code paths / the bestiary-style Index) until the cleanup.
BoonData.ON = false

BoonData.Pool = {
    -- (2026-10-03, owner: "Boons are currently far too powerful" -- every boon roughly halved; curses keep their full cost)
    -- Common: one stat
    { Id = "SHARP", Name = "Sharpened Rounds", Rarity = "Common", Stats = { IncreasedDamage = 0.10 } },
    { Id = "HAIR_TRIGGER", Name = "Hair Trigger", Rarity = "Common", Stats = { FireRateBonus = 0.07 } },
    { Id = "KEEN", Name = "Keen Eye", Rarity = "Common", Stats = { CritChance = 0.03, CritMultiplier = 0.05 } },
    { Id = "HEADHUNT", Name = "Keen Sight", Rarity = "Common", Stats = { WeakSpotMultiplier = 0.15 } },
    { Id = "DEEP_MAG", Name = "Deep Magazine", Rarity = "Common", Stats = { MagSizeBonus = 0.2, ReloadSpeedBonus = 0.08 } },
    { Id = "VIGOR", Name = "Vigor", Rarity = "Common", Stats = { MaxHPPct = 0.12, HPRegenPct = 0.001 } },
    { Id = "WARD", Name = "Elemental Ward", Rarity = "Common", Stats = { AllResist = 0.08, BaseArmor = 8 } },
    { Id = "FLEET", Name = "Fleet Foot", Rarity = "Common", Stats = { MovementSpeed = 0.06, ReloadSpeedBonus = 0.05 } },
    -- Rare: a new mechanic for the run
    { Id = "IGNITE", Name = "Incendiary Rounds", Rarity = "Rare", Stats = { BurnOnHit = 0.08, BurnDamage = 0.18 } },
    { Id = "CRYO", Name = "Cryo Rounds", Rarity = "Rare", Stats = { ChillOnHit = 0.08, FreezeEffect = 0.18 } },
    { Id = "SERRATED", Name = "Serrated Rounds", Rarity = "Rare", Stats = { BleedOnHit = 0.08, BleedDamage = 0.18 } },
    { Id = "BLIGHT", Name = "Rot Rounds", Rarity = "Rare", Stats = { DecayOnHit = 0.08, DecayEffect = 0.15 } },
    { Id = "KILL_RUSH", Name = "Kill Rush", Rarity = "Rare", Stats = { ChainKillDamage = 0.03 } },
    { Id = "VAMPIRIC", Name = "Vampiric Rounds", Rarity = "Rare", Stats = { LifeLeech = 0.006 } },
    { Id = "HARVEST", Name = "Reaper's Due", Rarity = "Rare", Stats = { KillHeal = 0.02, LowHealthEnemyDamage = 0.1 } },
    { Id = "FLICK", Name = "Flick Master", Rarity = "Rare", Stats = { SwitchDamage = 0.2 } },
    { Id = "AMBUSH", Name = "Ambush", Rarity = "Rare", Stats = { FirstHitDamage = 0.35 } },
    { Id = "OVERFLOW", Name = "Overflow", Rarity = "Rare", Stats = { OverkillCarry = 0.3 } },
    { Id = "AP_ROUNDS", Name = "Armor-Piercing Rounds", Rarity = "Rare", Stats = { PierceDamage = 0.2, PierceCount = 1 } },
    { Id = "SLAYER", Name = "Giant Slayer", Rarity = "Rare", Stats = { EliteDamage = 0.25 } },
    { Id = "ON_THE_MOVE", Name = "On the Move", Rarity = "Rare", Stats = { MovingDamage = 0.15, MovementSpeed = 0.03 } },
    { Id = "LAST_ROUNDS", Name = "Last Rounds", Rarity = "Rare", Stats = { LastMagDamage = 0.3 } },
    -- PRECISION BOONS (2026-10-06, NEXT GOALS 4): each rewards one way of aiming (the hit conditions CombatServer checks)
    { Id = "LONG_SHOT", Name = "Long Shot", Rarity = "Rare", Stats = { LongRangeDamage = 0.22 } },
    { Id = "POINT_BLANK", Name = "Point Blank", Rarity = "Rare", Stats = { CloseRangeDamage = 0.22 } },
    { Id = "FRESH_BRASS", Name = "Fresh Brass", Rarity = "Rare", Stats = { FreshMagDamage = 0.18 } },
    { Id = "QUICK_HANDS", Name = "Quick Hands", Rarity = "Rare", Stats = { ReloadedDamage = 0.2, ReloadSpeedBonus = 0.06 } },
    { Id = "STEADY_AIM", Name = "Steady Aim", Rarity = "Rare", Stats = { StillDamage = 0.15, StillDR = 0.05 } },
    -- Epic: run-defining
    { Id = "CULLING", Name = "Culling Edge", Rarity = "Epic", Stats = { ExecutePct = 0.06 } },
    { Id = "SHATTERPOINT", Name = "Brittle", Rarity = "Epic", Stats = { ChillOnHit = 0.1, AilmentedDamage = 0.18 } },
    { Id = "FOCUS_LOCK", Name = "Focus Lock", Rarity = "Epic", Stats = { FocusRetain = 1, StreakDamageBonus = 0.004 } },
    { Id = "OVERCLOCK", Name = "Overclock", Rarity = "Epic", Stats = { FireRateBonus = 0.15, MagSizeBonus = 0.2 } },
    { Id = "TITAN_BLOOD", Name = "Titan Blood", Rarity = "Epic", Stats = { MaxHPPct = 0.25, HPRegenPct = 0.003 } },
    { Id = "WILDFIRE", Name = "Inferno Rounds", Rarity = "Epic", Stats = { BurnOnHit = 0.12, BurnDamage = 0.3 } },
    { Id = "RAMPAGE", Name = "Rampage", Rarity = "Epic", Stats = { ChainKillDamage = 0.035, MovementSpeed = 0.03 } },
    { Id = "SURGEON", Name = "Surgeon", Rarity = "Epic", Stats = { WeakSpotCritChance = 0.2, WeakSpotMultiplier = 0.1 } },
    -- Cursed: a big upside with a real cost
    { Id = "GLASS_JAW", Name = "Glass Jaw", Rarity = "Cursed", Stats = { IncreasedDamage = 0.3, MaxHPPct = -0.35 } },
    { Id = "BERSERKER", Name = "Berserker", Rarity = "Cursed", Stats = { FireRateBonus = 0.2, AllResist = -0.3 } },
    { Id = "GREED", Name = "Gambler's Greed", Rarity = "Cursed", Stats = { LootLuck = 0.35, GoldBonus = 0.35, IncreasedDamage = -0.15 } },
    { Id = "RECKLESS", Name = "Reckless", Rarity = "Cursed", Stats = { CritMultiplier = 0.4, ArmorPct = -0.6 } },
}
BoonData.ById = {}
for _, b in ipairs(BoonData.Pool) do BoonData.ById[b.Id] = b end

-- ===== BOON COMBOS (2026-10-04, owner: "boon combos" -- Hades duo boons) =====
-- Hold BOTH boons of a pair and the combo switches on for the rest of the run: extra stats on top of the two boons.
-- Offers lean toward boons that would complete a combo (COMBO_BIAS), and the card says which combo it finishes.
BoonData.Combos = {
    { Id = "THERMAL_SHOCK", Name = "Thermal Shock", Needs = { "IGNITE", "CRYO" }, Stats = { AilmentedDamage = 0.20, AilmentChance = 0.10 } },
    { Id = "BLOODLETTING", Name = "Bloodletting", Needs = { "SERRATED", "VAMPIRIC" }, Stats = { BleedDamage = 0.25, LifeLeech = 0.004 } },
    { Id = "AVALANCHE", Name = "Avalanche", Needs = { "KILL_RUSH", "OVERFLOW" }, Stats = { ChainKillDamage = 0.02, OverkillCarry = 0.25 } },
    { Id = "DEADSHOT", Name = "Deadshot", Needs = { "HEADHUNT", "KEEN" }, Stats = { WeakSpotCritChance = 0.15, WeakSpotMultiplier = 0.10 } },
    { Id = "PHANTOM_DRAW", Name = "Phantom Draw", Needs = { "FLICK", "AMBUSH" }, Stats = { SwitchDamage = 0.15, FirstHitDamage = 0.20 } },
    { Id = "LEAD_STORM", Name = "Lead Storm", Needs = { "HAIR_TRIGGER", "DEEP_MAG" }, Stats = { FireRateBonus = 0.08, MagSizeBonus = 0.25 } },
    { Id = "BULWARK", Name = "Bulwark", Needs = { "VIGOR", "WARD" }, Stats = { MaxHPPct = 0.10, AllResist = 0.08, LowLifeDR = 0.10 } },
    { Id = "SLIPSTREAM", Name = "Slipstream", Needs = { "FLEET", "ON_THE_MOVE" }, Stats = { MovingDamage = 0.15, MovementSpeed = 0.04 } },
    { Id = "HEADSMAN", Name = "Headsman", Needs = { "SLAYER", "CULLING" }, Stats = { EliteDamage = 0.20, ExecutePct = 0.03 } },
    { Id = "ROT_AND_FROST", Name = "Rot and Frost", Needs = { "BLIGHT", "SHATTERPOINT" }, Stats = { DecayEffect = 0.15, AilmentedDamage = 0.15 } },
    { Id = "RAILGUN", Name = "Railgun", Needs = { "AP_ROUNDS", "SHARP" }, Stats = { PierceDamage = 0.25, IncreasedDamage = 0.06 } },
    { Id = "FINAL_VOLLEY", Name = "Final Volley", Needs = { "LAST_ROUNDS", "OVERCLOCK" }, Stats = { LastMagDamage = 0.30, ReloadSpeedBonus = 0.15 } },
    { Id = "UNDYING", Name = "Undying", Needs = { "HARVEST", "TITAN_BLOOD" }, Stats = { KillHeal = 0.02, HPRegenPct = 0.002 } },
    { Id = "FIRESTORM", Name = "Firestorm", Needs = { "IGNITE", "WILDFIRE" }, Stats = { BurnDamage = 0.30 } },
    { Id = "ZEN", Name = "Zen Marksman", Needs = { "FOCUS_LOCK", "HEADHUNT" }, Stats = { StreakDamageBonus = 0.004, WeakSpotMultiplier = 0.08 } },
    { Id = "DEATH_WISH", Name = "Death Wish", Needs = { "GLASS_JAW", "RECKLESS" }, Stats = { IncreasedDamage = 0.20, CritMultiplier = 0.25 } },
    -- (2026-10-06) the precision boons' combos
    { Id = "SNIPERS_NEST", Name = "Sniper's Nest", Needs = { "LONG_SHOT", "STEADY_AIM" }, Stats = { LongRangeDamage = 0.15, StillDamage = 0.10 } },
    { Id = "RUN_AND_GUN", Name = "Run and Gun", Needs = { "POINT_BLANK", "ON_THE_MOVE" }, Stats = { CloseRangeDamage = 0.15, MovingDamage = 0.10 } },
    { Id = "SPEED_LOADER", Name = "Speed Loader", Needs = { "QUICK_HANDS", "FRESH_BRASS" }, Stats = { ReloadedDamage = 0.15, FreshMagDamage = 0.10, ReloadSpeedBonus = 0.08 } },
    { Id = "SURGICAL", Name = "Scalpel", Needs = { "SURGEON", "CULLING" }, Stats = { WeakSpotMultiplier = 0.12, ExecutePct = 0.02 } },
}
BoonData.ComboById = {}
for _, c in ipairs(BoonData.Combos) do BoonData.ComboById[c.Id] = c end
BoonData.COMBO_COLOR = Color3.fromRGB(255, 205, 90)
BoonData.COMBO_BIAS = 0.35 -- chance an offer swaps one card for a boon that completes a combo you're halfway into

-- Combos active for a set of held boons.
function BoonData.ActiveCombos(owned: { string }?): { any }
    local have = {}
    for _, id in ipairs(owned or {}) do have[id] = true end
    local out = {}
    for _, c in ipairs(BoonData.Combos) do
        if have[c.Needs[1]] and have[c.Needs[2]] then table.insert(out, c) end
    end
    return out
end

-- The combos picking `id` would complete (given what's held).
function BoonData.CombosCompletedBy(id: string, owned: { string }?): { any }
    local have = {}
    for _, o in ipairs(owned or {}) do have[o] = true end
    if have[id] then return {} end
    local out = {}
    for _, c in ipairs(BoonData.Combos) do
        local a, b = c.Needs[1], c.Needs[2]
        if (a == id and have[b]) or (b == id and have[a]) then table.insert(out, c) end
    end
    return out
end

BoonData.RarityColors = {
    Common = Color3.fromRGB(200, 205, 215), Rare = Color3.fromRGB(80, 170, 255),
    Epic = Color3.fromRGB(190, 110, 255), Cursed = Color3.fromRGB(255, 80, 90),
}
-- Offer weights (normal floor / boss floor).
BoonData.Weights = {
    Normal = { Common = 50, Rare = 34, Epic = 8, Cursed = 8 },
    Boss = { Common = 30, Rare = 42, Epic = 18, Cursed = 10 },
}
BoonData.OFFER_SIZE = 3
BoonData.MAX_BOONS = 8 -- per run
BoonData.HEAT_PER_BOON = 0.06 -- every boon held: this run's enemies +6% health (DungeonRuns.SpawnProxy)

-- Three distinct boons (no repeat of an Epic / Cursed boon you already hold).
function BoonData.RollOffer(owned: { string }?, isBossFloor: boolean?, rng: Random?): { string }
    local r = rng or Random.new()
    local weights = isBossFloor and BoonData.Weights.Boss or BoonData.Weights.Normal
    local have = {}
    for _, id in ipairs(owned or {}) do have[id] = true end
    local out, picked = {}, {}
    for _ = 1, 60 do
        if #out >= BoonData.OFFER_SIZE then break end
        local total = 0
        for _, w in pairs(weights) do total += w end
        local roll = r:NextNumber() * total
        local rarity = "Common"
        for k, w in pairs(weights) do
            roll -= w
            if roll <= 0 then rarity = k; break end
        end
        local candidates = {}
        for _, b in ipairs(BoonData.Pool) do
            local unique = b.Rarity == "Epic" or b.Rarity == "Cursed"
            if b.Rarity == rarity and not picked[b.Id] and not (unique and have[b.Id]) then table.insert(candidates, b) end
        end
        if #candidates > 0 then
            local b = candidates[r:NextInteger(1, #candidates)]
            picked[b.Id] = true
            table.insert(out, b.Id)
        end
    end
    -- combo bias: sometimes the last card becomes a boon that completes a combo you're halfway into
    if #out > 0 and r:NextNumber() < BoonData.COMBO_BIAS then
        local finishers = {}
        for _, bb in ipairs(BoonData.Pool) do
            if not picked[bb.Id] and #BoonData.CombosCompletedBy(bb.Id, owned) > 0 then table.insert(finishers, bb.Id) end
        end
        if #finishers > 0 then out[#out] = finishers[r:NextInteger(1, #finishers)] end
    end
    return out
end

-- Text lines for a boon card ("+12% Weapon Damage").
function BoonData.Lines(id: string, formatStat: (string, number) -> string): { string }
    local b = BoonData.ById[id]
    local out = {}
    if not b then return out end
    local keys = {}
    for k in pairs(b.Stats) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do table.insert(out, formatStat(k, b.Stats[k])) end
    return out
end

return BoonData
