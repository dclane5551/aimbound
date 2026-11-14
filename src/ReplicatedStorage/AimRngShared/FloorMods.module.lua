--!nocheck
-- ============================================================================================
-- FLOOR MODIFIERS ("anomalies"): from floor 2 on, a regular (non-boss) solo floor can roll 1-2 of these.
-- Harder ones pay a reward bonus (XP, gold and loot luck on that floor); a few are pure gifts. Shown on the
-- dungeon banner. Server: DungeonRuns.StartFloor rolls them (config.Mods, run folder attribute "Mods");
-- effects live in DungeonRuns (enemy HP / taken damage), DungeonGenerator (speed, count, elites, goblin),
-- CombatServer (player damage taken, weak-spot rules, rewards, boon offer).
-- ============================================================================================
local FloorMods = {}

FloorMods.Defs = {
    FRENZIED = { Name = "Frenzied", Text = "Enemies move and attack 25% faster.", Reward = 0.25,
        V = 0.25, Cap = 0.4, At = "Enemies move and attack {v}% faster.", Group = "Speed", Load = 0, Color = Color3.fromRGB(255, 120, 80) },
    FORTIFIED = { Name = "Fortified", Text = "Enemies have 40% more health.", Reward = 0.25,
        V = 0.4, At = "Enemies have {v}% more health (not the guardian).", Group = "Health", MapV = 0.2, MapReward = 0.15, Load = 0.27, Color = Color3.fromRGB(150, 170, 200) }, -- (MAP HEALTH 2026-11-05: own slot outside Rifts.LOAD_CAP, +20% T1 .. +32% T12; Load = 0.2 at +24% scaled)
    SWARMING = { Name = "Swarming", Text = "50% more enemies (and their packs).", Reward = 0.15,
        V = 0.5, MapV = 0.1, At = "{v}% more enemy packs.", Group = "Packs", MapReward = 0.1, Load = 0.15, Color = Color3.fromRGB(230, 200, 90) }, -- (MAPS V2 final check: Swarming + Teeming = +96% enemies at T12, never both)
    ELITE_PACK = { Name = "Elite Pack", Text = "Far more elites.", Reward = 0.30,
        V = 3, At = "Far more elites: at least {n} on every floor.", Load = 0.12, Color = Color3.fromRGB(255, 140, 220) },
    GLASS_ARENA = { Name = "Glass Arena", Text = "Everyone takes 35% more damage. You included.", Reward = 0.20,
        V = 0.35, Cap = 0.55, At = "Everyone takes {v}% more damage. You included.", MinTier = 4, Weight = 0.7, Group = "Damage", Load = 0, Color = Color3.fromRGB(140, 230, 255) },
    HEADHUNTER = { Name = "Aim High", -- (UPDATE 8 originality: was "Headhunter Rules")
        Text = "Body shots deal 50% less damage; weak-spot hits deal 30% more.", Reward = 0.25,
        V = 0.5, Cap = 0.7, At = "Body shots deal {v}% less damage; weak-spot hits deal 30% more.", MapV = 0.15, MapReward = 0.1, Load = 0.08, Color = Color3.fromRGB(255, 80, 80) },
    BOUNTIFUL = { Name = "Bountiful", Text = "+60% gold from this floor.", Reward = 0, Gift = true, Color = Color3.fromRGB(255, 215, 80) },
    BLESSED = { Name = "Blessed", Text = "A Boon Shrine stands on this floor.", Reward = 0, Gift = true, Color = Color3.fromRGB(200, 160, 255) },
    TREASURE = { Name = "Treasure Hunt", Text = "A loot goblin is hiding on this floor.", Reward = 0, Gift = true, Color = Color3.fromRGB(255, 230, 120) },
    -- (2026-10-06, NEXT GOALS 4) a range risk and a precision gift (CombatServer hit code)
    KEEP_DISTANCE = { Name = "Keep Your Distance", Text = "Hits from closer than 25 studs deal 40% less damage.", Reward = 0.20,
        V = 0.4, Cap = 0.6, At = "Hits from closer than 25 studs deal {v}% less damage.", MapV = 0.3, MapReward = 0.15, Load = 0.1, Color = Color3.fromRGB(120, 200, 255) },
    EAGLE_EYE = { Name = "Eagle Eye", Text = "Weak-spot hits deal 25% more damage on this floor.", Reward = 0, Gift = true, Color = Color3.fromRGB(255, 225, 120) },
    -- (0.62 MAPS v3, owner: "maps need WAY more depth ... make them like POE maps and included rarities"): more map mods.
    -- MapOnly ones only roll on maps (Rifts), never on regular floors / paths.
    BRUTAL = { Name = "Brutal", Text = "Enemies deal 40% more damage.", Reward = 0.30, MapOnly = true,
        V = 0.4, At = "Enemies deal {v}% more damage.", Group = "Damage", Load = 0, Color = Color3.fromRGB(255, 70, 60) },
    NO_REGEN = { Name = "Bleak", Text = "You don't regenerate health.", Reward = 0.25, MapOnly = true,
        MinTier = 4, Weight = 0.8, Load = 0, Color = Color3.fromRGB(170, 120, 160) },
    ARMORED = { Name = "Plated", Text = "Enemies have +30% Kinetic resistance.", Reward = 0.20, MapOnly = true,
        V = 0.3, Cap = 0.5, At = "Enemies have +{v}% Kinetic resistance.", Group = "Resist", MapV = 0.12, MapReward = 0.1, Load = 0.15, Color = Color3.fromRGB(160, 170, 190) }, -- (UPDATE 8: was "take 25% less damage")
    SHARPSHOOTERS = { Name = "Sharpshooters", Text = "Two extra Snipers guard every floor.", Reward = 0.20, MapOnly = true,
        V = 2, At = "{n} extra Snipers guard every floor.", Load = 0.03, Color = Color3.fromRGB(255, 200, 110) },
    RELENTLESS = { Name = "Relentless", Text = "Enemies move like two bot-skill steps higher.", Reward = 0.25, MapOnly = true,
        Group = "Speed", Load = 0, Color = Color3.fromRGB(255, 150, 60) },
    SMALL_TARGETS = { Name = "Small Targets", Text = "Enemies are 20% smaller.", Reward = 0.25, MapOnly = true,
        V = 0.2, Cap = 0.3, At = "Enemies are {v}% smaller.", Load = 0.12, Color = Color3.fromRGB(120, 230, 255) },
    ELEMENTAL = { Name = "Elemental", Text = "Every enemy carries an element: its hits are Heat, Cryo, Volt, Void or Kinetic and bring their ailment.", Reward = 0.20, MapOnly = true, Load = 0, Color = Color3.fromRGB(180, 255, 120) },
    -- (0.66 MAPS, NEXT_LIST C10: "more map modifiers with clear risk / reward")
    SHORT_FUSE = { Name = "Short Fuse", Text = "The map timer is 30% shorter.", Reward = 0.35, MapOnly = true,
        V = 0.3, Cap = 0.4, At = "The map timer is {v}% shorter.", MinTier = 4, Weight = 0.7, Load = 0, Color = Color3.fromRGB(255, 180, 60) },
    EMPOWERED = { Name = "Empowered Guardian", Text = "The guardian has 60% more health.", Reward = 0.25, MapOnly = true,
        V = 0.6, At = "The guardian has {v}% more health.", MinTier = 4, MapV = 0.3, MapReward = 0.15, Load = 0.06, Color = Color3.fromRGB(255, 110, 150) },
    STEEL_SKIN = { Name = "Steel Skin", Text = "Enemies can't be critically hit.", Reward = 0.30, MapOnly = true,
        MinTier = 4, Weight = 0.8, V = 1, MapV = 0.3, Cap = 0.5, At = "Critical hits deal {v}% less extra damage to enemies.", MapReward = 0.1, Load = 0.1, Color = Color3.fromRGB(190, 200, 215) },
    MENDING = { Name = "Mending", Text = "Enemies heal 2% of their health a second when they haven't been hit for 3 seconds (not the guardian).", Reward = 0.20, MapOnly = true,
        V = 0.02, At = "Enemies heal {v1}% of their health a second when they haven't been hit for 3 seconds (not the guardian).", Load = 0.05, Color = Color3.fromRGB(120, 230, 150) },
    ALL_IN = { Name = "All In", Text = "Beat the timer: the guardian drops twice the items. Miss it: the guardian drops nothing.", Reward = 0, MapOnly = true,
        MinTier = 7, Weight = 0.5, Load = 0, Color = Color3.fromRGB(255, 215, 80) },
    -- (UPDATE 8 MAPS ON THE NEW SYSTEMS, DEFENCE builder): typed monster damage, monster resists / Plating / Ward, your defences
    -- squeezed, bigger packs, more and nastier elites. Effects: CombatServer.DamagePlayer + the Ward loop (EXTRA_*, MAX_RES_DOWN,
    -- LOW_AGILITY, SLOW_WARD), DungeonGenerator (MapResist, RollEliteMods, AddPilotPacks), DungeonRuns (WARDED monsters).
    EXTRA_HEAT = { Name = "Searing", Text = "Enemy hits deal 25% extra damage as Heat.", Reward = 0.20, MapOnly = true,
        V = 0.25, At = "Enemy hits deal {v}% extra damage as Heat.", Group = "Extra", Load = 0, Color = Color3.fromRGB(255, 120, 40) },
    EXTRA_CRYO = { Name = "Frostbitten", Text = "Enemy hits deal 25% extra damage as Cryo.", Reward = 0.20, MapOnly = true,
        V = 0.25, At = "Enemy hits deal {v}% extra damage as Cryo.", Group = "Extra", Load = 0, Color = Color3.fromRGB(120, 210, 255) },
    EXTRA_VOLT = { Name = "Overcharged", Text = "Enemy hits deal 25% extra damage as Volt.", Reward = 0.20, MapOnly = true,
        V = 0.25, At = "Enemy hits deal {v}% extra damage as Volt.", Group = "Extra", Load = 0, Color = Color3.fromRGB(255, 230, 70) },
    EXTRA_VOID = { Name = "Hollow", Text = "Enemy hits deal 20% extra damage as Void (it goes straight past your Ward).", Reward = 0.25, MapOnly = true,
        V = 0.2, At = "Enemy hits deal {v}% extra damage as Void (it goes straight past your Ward).", MinTier = 7, Weight = 0.7, Group = "Extra", Load = 0, Color = Color3.fromRGB(175, 95, 255) },
    RESIST_HEAT = { Name = "Heatproof", Text = "Enemies have +30% Heat resistance.", Reward = 0.15, MapOnly = true,
        V = 0.3, Cap = 0.5, At = "Enemies have +{v}% Heat resistance.", Group = "Resist", MapV = 0.12, MapReward = 0.1, Load = 0.15, Color = Color3.fromRGB(255, 160, 100) },
    RESIST_CRYO = { Name = "Frostproof", Text = "Enemies have +30% Cryo resistance.", Reward = 0.15, MapOnly = true,
        V = 0.3, Cap = 0.5, At = "Enemies have +{v}% Cryo resistance.", Group = "Resist", MapV = 0.12, MapReward = 0.1, Load = 0.15, Color = Color3.fromRGB(160, 220, 255) },
    RESIST_VOLT = { Name = "Insulated", Text = "Enemies have +30% Volt resistance.", Reward = 0.15, MapOnly = true,
        V = 0.3, Cap = 0.5, At = "Enemies have +{v}% Volt resistance.", Group = "Resist", MapV = 0.12, MapReward = 0.1, Load = 0.15, Color = Color3.fromRGB(255, 235, 140) },
    RESIST_VOID = { Name = "Voidproof", Text = "Enemies have +30% Void resistance.", Reward = 0.15, MapOnly = true,
        V = 0.3, Cap = 0.5, At = "Enemies have +{v}% Void resistance.", Group = "Resist", MapV = 0.12, MapReward = 0.1, Load = 0.15, Color = Color3.fromRGB(200, 150, 255) },
    WARDED = { Name = "Warded", Text = "Enemies have 25% more health; that extra part comes back after 2 seconds without a hit.", Reward = 0.25, MapOnly = true,
        V = 0.25, At = "Enemies have {v}% more health; that extra part comes back after 2 seconds without a hit.", Group = "Health", MapV = 0.15, MapReward = 0.15, Load = 0.27, Color = Color3.fromRGB(90, 220, 255) }, -- (MAP HEALTH 2026-11-05: +15% T1 .. +24% T12; Load = 0.18 at +16% scaled)
    MAX_RES_DOWN = { Name = "Exposed", Text = "-10% to all your maximum resistances.", Reward = 0.25, MapOnly = true,
        V = 0.1, Cap = 0.2, At = "-{v}% to all your maximum resistances.", MinTier = 4, Weight = 0.8, Load = 0, Color = Color3.fromRGB(255, 90, 140) },
    SLOW_WARD = { Name = "Dampened", Text = "Your Ward recharges 50% slower.", Reward = 0.15, MapOnly = true,
        V = 0.5, Cap = 0.75, At = "Your Ward recharges {v}% slower.", Load = 0, Color = Color3.fromRGB(120, 170, 200) },
    LOW_AGILITY = { Name = "Sluggish", Text = "Your Agility dodges half as often.", Reward = 0.15, MapOnly = true,
        V = 0.5, Cap = 0.75, At = "Your Agility dodges {v}% less often.", Load = 0, Color = Color3.fromRGB(170, 200, 140) },
    BIG_PACKS = { Name = "Teeming", Text = "Every pack is 25% bigger.", Reward = 0.20, MapOnly = true,
        V = 0.25, Cap = 0.4, At = "Every pack is {v}% bigger.", Group = "Packs", MapV = 0.1, MapReward = 0.1, Load = 0.15, Color = Color3.fromRGB(230, 180, 90) },
    RARE_ELITES = { Name = "Champions", Text = "Every elite is a Rare elite (3-4 modifiers).", Reward = 0.30, MapOnly = true,
        MinTier = 4, Weight = 0.8, Load = 0.05, Color = Color3.fromRGB(250, 222, 64) },
    COMMANDERS = { Name = "Warbands", Text = "Every elite is also Commanding or Volatile.", Reward = 0.20, MapOnly = true, Load = 0.02, Color = Color3.fromRGB(255, 150, 110) },
    -- PATH REWARDS (2026-10-04): only offered by the path portals (never rolled at random), paid when the floor is cleared
    ARMORY = { Name = "Armory", Text = "Clear the floor for a guaranteed item from the top four rarities of this difficulty.", Reward = 0, Gift = true, PathOnly = true, Color = Color3.fromRGB(110, 180, 255) },
    VAULT = { Name = "War Vault", Text = "Clear the floor for a guaranteed item from the top four rarities of this difficulty.", Reward = 0, Gift = true, PathOnly = true, Color = Color3.fromRGB(200, 120, 255) },
    CACHE = { Name = "Supply Cache", Text = "Clear the floor for a pile of upgrade materials.", Reward = 0, Gift = true, PathOnly = true, Color = Color3.fromRGB(170, 230, 140) },
    MERCHANT = { Name = "Wandering Merchant", Text = "A merchant sells gear for your run gold on this floor.", Reward = 0, Gift = true, PathOnly = true, Color = Color3.fromRGB(255, 200, 120) },
}
-- (2026-10-22: TREASURE left the random pool and the path gifts -- loot goblins are 1 in 100 floors with a guaranteed Legendary,
-- so a mod that always spawns one would make them common / pickable. The def stays for old runs.)
FloorMods.Order = { "FRENZIED", "FORTIFIED", "SWARMING", "ELITE_PACK", "GLASS_ARENA", "HEADHUNTER", "KEEP_DISTANCE", "BOUNTIFUL", "EAGLE_EYE" } -- (UPDATE 8: no BLESSED -- boons are cut)
FloorMods.CHANCE_ONE = 0.35
FloorMods.CHANCE_TWO = 0.10

-- ===== PATH CHOICE (owner 2026-10-04): after a floor, two or three portals offer the next floor's risk + reward =====
-- CALM: one gift, no risk. RISKY: one hard modifier + a better gift. DEADLY (always from floor 4, else 50%): two hard
-- modifiers + a War Vault. Hard modifiers keep paying their reward bonus (XP / gold / loot luck). Boss floors, Rifts,
-- the Daily and party runs keep a single portal (DungeonRuns.MarkFloorCleared decides).
FloorMods.RISKS = { "FRENZIED", "FORTIFIED", "SWARMING", "ELITE_PACK", "GLASS_ARENA", "HEADHUNTER", "KEEP_DISTANCE" }
FloorMods.PATHS = {
    Calm = { Name = "CALM", Color = Color3.fromRGB(90, 230, 170), Gifts = { "BOUNTIFUL", "CACHE", "MERCHANT", "EAGLE_EYE" }, Risks = 0 },
    Risky = { Name = "RISKY", Color = Color3.fromRGB(255, 115, 25), Gifts = { "ARMORY", "BOUNTIFUL", "MERCHANT", "EAGLE_EYE" }, Risks = 1 }, -- (UPDATE 8: BLESSED -> BOUNTIFUL)
    Deadly = { Name = "DEADLY", Color = Color3.fromRGB(255, 70, 70), Gifts = { "VAULT" }, Risks = 2 },
}
function FloorMods.RollPaths(nextFloor: number, rng: Random?): { any }
    local r = rng or Random.new()
    local risks = table.clone(FloorMods.RISKS)
    for i = #risks, 2, -1 do local j = r:NextInteger(1, i); risks[i], risks[j] = risks[j], risks[i] end
    local order = { "Calm", "Risky" }
    if nextFloor >= 4 or r:NextNumber() < 0.5 then table.insert(order, "Deadly") end
    local out, usedGift = {}, {}
    for _, id in ipairs(order) do
        local def = FloorMods.PATHS[id]
        local mods = {}
        for _ = 1, def.Risks do table.insert(mods, table.remove(risks, 1)) end
        local gifts = {}
        for _, g in ipairs(def.Gifts) do if not usedGift[g] then table.insert(gifts, g) end end
        if #gifts == 0 then gifts = def.Gifts end
        local gift = gifts[r:NextInteger(1, #gifts)]
        usedGift[gift] = true
        table.insert(mods, gift)
        table.insert(out, { Id = id, Mods = table.concat(mods, ",") })
    end
    return out
end

-- Mods for a floor ({} for floor 1, boss floors and party floors).
function FloorMods.Roll(floorNumber: number, isBossFloor: boolean, rng: Random?): { string }
    if floorNumber < 2 or isBossFloor then return {} end
    local r = rng or Random.new()
    local roll = r:NextNumber()
    local n = (roll < FloorMods.CHANCE_TWO and 2) or (roll < FloorMods.CHANCE_ONE and 1) or 0
    local out = {}
    local pool = table.clone(FloorMods.Order)
    for _ = 1, n do
        local i = r:NextInteger(1, #pool)
        table.insert(out, pool[i])
        table.remove(pool, i)
    end
    return out
end

function FloorMods.Has(mods: any, id: string): boolean
    if type(mods) == "string" then return string.find("," .. mods .. ",", "," .. id .. ",", 1, true) ~= nil end
    if type(mods) == "table" then return table.find(mods, id) ~= nil end
    return false
end

function FloorMods.Parse(s: string?): { string }
    local out = {}
    for id in string.gmatch(s or "", "[^,]+") do
        if FloorMods.Defs[id] then table.insert(out, id) end
    end
    return out
end

-- Total reward bonus (0.25 = +25% XP / gold / loot luck). scale (MAPS V2) = a map's Rifts.ModScale(tier): every mod pays more on
-- higher tiers; nil on regular floors (x1). (MAP PACING 2026-10-31) on a map (scale given) a def's MapReward replaces its Reward:
-- the map value got weaker (MapV), so its pay follows it (Reward x MapV / V, rounded to 0.05, at least 0.1).
function FloorMods.RewardOf(id: string, map: boolean?): number
    local d = FloorMods.Defs[id]
    if not d then return 0 end
    if map and type(d.MapReward) == "number" then return d.MapReward end
    return d.Reward or 0
end
function FloorMods.RewardBonus(mods: { string }, scale: number?): number
    local b = 0
    for _, id in ipairs(mods) do b += FloorMods.RewardOf(id, scale ~= nil) end
    return b * (tonumber(scale) or 1)
end

-- ===== MAPS V2 (2026-10-30): MOD VALUES SCALE WITH THE MAP TIER =====
-- A def's V = its effect at scale 1 (= today's number on regular floors and T1 maps), MapV = a different base on maps (Swarming:
-- what a linked map floor really adds), Cap = the most it can reach, At = the text with {v} (V x 100, whole %), {v1} (one decimal)
-- or {n} (a whole count). A map passes scale = Rifts.ModScale(tier) (T1 x1.0 .. T12 x1.6); regular floors pass nil (x1, today).
-- The effect sites read FloorMods.V (DungeonGenerator: config.ModScale, DungeonRuns: run.Config.ModScale, CombatServer: the run
-- folder's ModScale attribute, EndgameServer: Short Fuse).
function FloorMods.V(id: string, scale: number?, map: boolean?): number
    local d = FloorMods.Defs[id]
    if not d or type(d.V) ~= "number" then return 0 end
    local onMap = (map == true) or (map == nil and scale ~= nil)
    local base = (onMap and type(d.MapV) == "number") and d.MapV or d.V
    local v = base * (tonumber(scale) or 1)
    if type(d.Cap) == "number" then v = math.min(v, math.max(d.Cap, base)) end
    return v
end
local function Pct(v: number, dec: boolean?): string
    if dec then
        local t = string.format("%.1f", v * 100)
        return (string.gsub(t, "%.0$", ""))
    end
    return tostring(math.round(v * 100))
end
-- the mod's text with its real numbers at this scale (nil scale = the regular floor text)
function FloorMods.TextOf(id: string, scale: number?): string
    local d = FloorMods.Defs[id]
    if not d then return tostring(id) end
    if scale == nil or type(d.At) ~= "string" or type(d.V) ~= "number" then return d.Text end
    local v = FloorMods.V(id, scale, true)
    local t = string.gsub(d.At, "{v1}", Pct(v, true))
    t = string.gsub(t, "{v}", Pct(v))
    t = string.gsub(t, "{n}", tostring(math.round(v)))
    return t
end

return FloorMods
