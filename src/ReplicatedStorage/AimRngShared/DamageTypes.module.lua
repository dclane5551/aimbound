-- DamageTypes (UPDATE 8 "The Revamp", owned by the OFFENSE builder -- message its owner before editing).
-- The five damage types, their colours + ailments, the old -> new name maps, the difficulty resist penalty, enemy
-- resistances and pure helpers for the hit formula (docs/UPDATE8.md):
--   per type t: base_t + flat added_t -> conversion (left -> right only) -> x (1 + increased that applies to t)
--   -> x product of "more" -> crit -> x weak spot -> x (1 - enemy resist_t) -> sum = the hit.
-- Pure data + functions: no Instances, no services, safe to require from server, client and the luau sims.

local DT = {}

-- ==================== [TYPES] (this order everywhere; conversion only moves damage to the right) ====================
DT.ORDER = { "Kinetic", "Heat", "Cryo", "Volt", "Void" }
DT.INDEX = {} :: { [string]: number }
for i, t in ipairs(DT.ORDER) do DT.INDEX[t] = i end

DT.COLOR = {
    Kinetic = Color3.fromRGB(235, 225, 205), -- warm white (plain gun damage)
    Heat = Color3.fromRGB(255, 120, 40),
    Cryo = Color3.fromRGB(120, 210, 255),
    Volt = Color3.fromRGB(255, 230, 70),
    Void = Color3.fromRGB(175, 95, 255),
}
DT.LABEL = { Kinetic = "Kinetic", Heat = "Heat", Cryo = "Cryo", Volt = "Volt", Void = "Void" } -- player text (placeholders)

-- ==================== [AILMENTS] ====================
-- Kinetic Bleed (DoT, worse while the target moves), Heat Burn (big DoT), Cryo Chill -> Freeze at high build-up,
-- Volt Shock (target takes increased damage for a few seconds), Void Wither (stacks of increased damage taken).
DT.AILMENT = { Kinetic = "Bleed", Heat = "Burn", Cryo = "Chill", Volt = "Shock", Void = "Wither" }
DT.AILMENT_TYPE = { Bleed = "Kinetic", Burn = "Heat", Chill = "Cryo", Freeze = "Cryo", Shock = "Volt", Wither = "Void" }
DT.AILMENT_COLOR = {
    Bleed = Color3.fromRGB(215, 40, 55), Burn = Color3.fromRGB(255, 120, 40), Chill = Color3.fromRGB(120, 210, 255),
    Freeze = Color3.fromRGB(170, 235, 255), Shock = Color3.fromRGB(255, 230, 70), Wither = Color3.fromRGB(175, 95, 255),
}

-- ==================== [OLD -> NEW] (old saves / items / attributes keep working until WIPE 5) ====================
DT.FROM_OLD = {
    Fire = "Heat", Cold = "Cryo", Chaos = "Void", Bleed = "Kinetic", Physical = "Kinetic", Shock = "Volt",
    Lightning = "Volt", Lucid = "Cryo", Scorch = "Heat", -- (Lucid / Scorch: the 0.53 biome elements, Cold / Fire based)
    Kinetic = "Kinetic", Heat = "Heat", Cryo = "Cryo", Volt = "Volt", Void = "Void",
}
-- (FUTURE-PROOF 2026-10-25: every type in ORDER is its own new name -- a NEW type missing here turned every hit of it Kinetic)
for _, t in ipairs(DT.ORDER) do DT.FROM_OLD[t] = DT.FROM_OLD[t] or t end
DT.AILMENT_FROM_OLD = {
    Decay = "Wither", Freeze = "Chill", Chill = "Chill", Burn = "Burn", Bleed = "Bleed", Shock = "Shock", Wither = "Wither",
}
-- old weapon proc id (ItemData.WeaponProcs) -> the damage type its element now deals
DT.PROC_TYPE = { Burn = "Heat", Freeze = "Cryo", Bleed = "Kinetic", Decay = "Void" }

-- normalise any old / new type name (nil for unknown / neutral)
function DT.Normalize(name: string?): string?
    return name and DT.FROM_OLD[name] or nil
end

-- ==================== [RESISTANCES] ====================
DT.RESIST_CAP = 0.75   -- player resist cap (MaxHeatResist ... raise it)
DT.ENEMY_RESIST_CAP = 0.75
DT.ENEMY_RESIST_FLOOR = -0.75 -- negative resist = takes more (Shock / Wither / curses never push past this)

-- Difficulty penalty on every PLAYER resist (a flat minus, PoE act-style). Easy / Normal none, then it grows tier by tier.
-- (main 2026-10-21: = today's StatCalculator.DifficultyResistPenalty, so an average build takes today's elemental damage.)
-- Tune here only. DEFENCE reads ResistPenalty / RESIST_CAP / FROM_OLD / AILMENT_FROM_OLD: keep those names stable.
DT.RESIST_PENALTY = {
    Easy = 0, Normal = 0, Hard = -0.10, Brutal = -0.20, Nightmare = -0.30, Torment = -0.40, Cataclysm = -0.50,
    Oblivion = -0.60, Ruin = -0.64, Dread = -0.68, Apocalypse = -0.72, Annihilation = -0.76, Eternity = -0.80,
    Singularity = -0.84, Endless = -0.30,
}
DT.RESIST_PENALTY_DEFAULT = -0.84 -- unknown / future tiers (as hard as the top one)
function DT.ResistPenalty(difficulty: string?): number
    if not difficulty then return 0 end
    local v = DT.RESIST_PENALTY[difficulty]
    if v == nil then return DT.RESIST_PENALTY_DEFAULT end
    return v
end

-- final resist after penalty + cap (player side helper; max defaults to DT.RESIST_CAP)
function DT.EffectiveResist(raw: number, difficulty: string?, cap: number?): number
    return math.min(raw + DT.ResistPenalty(difficulty), cap or DT.RESIST_CAP)
end

-- ==================== [ENEMY RESISTANCES] (data; DungeonGenerator writes attrs Res_<Type> from this) ====================
-- Keyed by the enemy's type key (ItemData.EnemyAffinity: its Element attr, else its floor's biome element). A biome
-- resists its own element a bit and is weak (negative) to one other. Kinetic stays 0 on biomes, so a plain gun kills at
-- the same pace everywhere (owner: balance stays roughly where it is for an average build).
DT.ENEMY_RES = {
    Fire = { Heat = 0.25, Cryo = -0.15 },     -- Molten: frost puts out the fire
    Cold = { Cryo = 0.25, Heat = -0.15 },     -- Ice: heat melts it
    Chaos = { Void = 0.25, Volt = -0.15 },    -- Void: a charge scatters the dark
    Bleed = { Volt = 0.25, Void = -0.15 },    -- Cyber: insulated machines; decay corrupts them
    Shock = { Volt = 0.25, Void = -0.15 },    -- Storm: the charge is home; decay grounds it
    Lucid = { Cryo = 0.25, Volt = -0.15 },    -- Dream: dreams are cold; a jolt wakes you up
    Scorch = { Heat = 0.25, Cryo = -0.15 },   -- Flats: sun-baked; cold snaps the heat
}
DT.ELITE_ELEMENT_RES = 0.40  -- an elite / boss with an elemental mod (Element attr) resists that type this much
DT.BOSS_BIOME_RES_MULT = 1.0 -- bosses resist like their floor (x this)

-- enemy resist table { Kinetic = r, ... } for a type key + optional elemental-mod element
function DT.EnemyResists(typeKey: string?, elementMod: string?, isBoss: boolean?): { [string]: number }
    local out = DT.Empty() -- (FUTURE-PROOF: every type in ORDER)
    local row = typeKey and DT.ENEMY_RES[typeKey]
    if row then
        local m = if isBoss then DT.BOSS_BIOME_RES_MULT else 1
        for t, v in pairs(row) do out[t] = v * m end
    end
    local et = DT.Normalize(elementMod)
    if et and et ~= "Kinetic" then out[et] = math.max(out[et], DT.ELITE_ELEMENT_RES) end
    for t, v in pairs(out) do out[t] = math.clamp(v, DT.ENEMY_RESIST_FLOOR, DT.ENEMY_RESIST_CAP) end
    return out
end

-- ==================== [OFFENCE STATS] (stat keys StatCalculator collects from gear / gun affixes / tree / gems ...) ====
-- The NEW offence math has NO level ceilings (owner: strong builds 2-4x an average one). Today's "IncreasedDamage" stays
-- the generic increased (and keeps its old ceiling until Phase 4 rebuilds the tree).
DT.ADDED_STAT = { Kinetic = "AddedKinetic", Heat = "AddedHeat", Cryo = "AddedCryo", Volt = "AddedVolt", Void = "AddedVoid" } -- flat per hit
DT.INC_STAT = { Kinetic = "KineticDamage", Heat = "HeatDamage", Cryo = "CryoDamage", Volt = "VoltDamage", Void = "VoidDamage" } -- increased
DT.ELEMENTAL = { Heat = true, Cryo = true, Volt = true } -- "ElementalDamage" (increased) applies to these three
DT.AIL_CHANCE_STAT = { Kinetic = "BleedChance", Heat = "BurnChance", Cryo = "ChillChance", Volt = "ShockChance", Void = "WitherChance" }
-- conversion stats: "Convert<Src>To<Dst>" (Dst right of Src), e.g. ConvertKineticToCryo = 0.4 = 40% of Kinetic becomes Cryo
function DT.ConvertStat(src: string, dst: string): string return "Convert" .. src .. "To" .. dst end
DT.OFFENCE_STATS = { FlatDamage = true, ElementalDamage = true, FreezeChance = true, ShockEffect = true, WitherEffect = true,
    -- (phase 2 LOCAL gun mods, rolled only on guns: LocalAdded<T> = added <T> as a share of the gun's own base hit,
    -- LocalKinetic = increased Kinetic that multiplies the gun's Kinetic base)
    LocalAddedKinetic = true, LocalAddedHeat = true, LocalAddedCryo = true, LocalAddedVolt = true, LocalAddedVoid = true,
    LocalKinetic = true } :: { [string]: boolean }
for i, t in ipairs(DT.ORDER) do
    DT.OFFENCE_STATS[DT.ADDED_STAT[t]] = true
    DT.OFFENCE_STATS[DT.INC_STAT[t]] = true
    DT.OFFENCE_STATS[DT.AIL_CHANCE_STAT[t]] = true
    for j = i + 1, #DT.ORDER do DT.OFFENCE_STATS[DT.ConvertStat(t, DT.ORDER[j])] = true end
end
-- ADDED-DAMAGE EFFECTIVENESS: flat added damage per hit from GEAR / the tree (AddedKinetic .. AddedVoid, FlatDamage) favours
-- fast guns, so it is scaled by clamp(ADDED_EFFECT_REF / the gun's base fire rate, MIN, MAX) and split across shotgun
-- pellets. A gun's own LOCAL added mods (LocalAdded<T>, a share of its base hit) are NOT scaled.
DT.ADDED_EFFECT_REF = 4      -- shots / s that get 100% of a flat added line
DT.ADDED_EFFECT_MIN = 0.25
DT.ADDED_EFFECT_MAX = 4
function DT.AddedEffect(fireRate: number?, pellets: number?): number
    local fr = math.max(0.1, fireRate or DT.ADDED_EFFECT_REF)
    return math.clamp(DT.ADDED_EFFECT_REF / fr, DT.ADDED_EFFECT_MIN, DT.ADDED_EFFECT_MAX) / math.max(1, pellets or 1)
end
-- old elemental gun prefixes (Burning / Freezing / Decaying) convert this share of the gun's Kinetic damage to their type
-- (they used to be a flat +-15% matchup; Bleeding stays Kinetic)
DT.PROC_CONVERT = 0.5

-- ==================== [AILMENTS BY TYPE] (CombatServer applies them; magnitude scales with the hit, the PoE way) ====
-- chance per hit = (BASE x the type's share of the hit + the type's chance stat) x the gun's proc-rate factor x
-- (1 + Proc Chance) / pellets, at most MAX. Kinetic has no base chance (a plain gun does what it did before).
DT.AILMENT_BASE_CHANCE = { Kinetic = 0, Heat = 0.10, Cryo = 0.10, Volt = 0.10, Void = 0.10 }
setmetatable(DT.AILMENT_BASE_CHANCE, { __index = function() return 0.10 end }) -- (FUTURE-PROOF: a NEW type's base chance, never nil)
DT.AILMENT_MAX_CHANCE = 0.75
-- SHOCK: the target takes increased damage; effect = Scale x (Volt part of the hit / max health)^Exp, Min..Max
DT.SHOCK = { Scale = 0.5, Exp = 0.4, Min = 0.05, Max = 0.5, Duration = 2.0 }
-- WITHER: stacks of increased damage taken (each stack lasts Duration on its own); per stack like Shock, total <= Cap
DT.WITHER = { Scale = 0.12, Exp = 0.4, Min = 0.01, Max = 0.06, MaxStacks = 10, Cap = 0.4, Duration = 3.0 }
-- FREEZE: Cryo hits build up (share of max health within Window s); at BuildPct the target freezes (bosses: slowed BossSlow)
DT.FREEZE = { BuildPct = 0.25, Window = 3.0, Duration = 0.8, BossSlow = 0.35, Cooldown = 1.5 }
-- BLEED: worse while the target moves (per tick: moved > MoveDist studs since the last tick)
DT.BLEED = { Moving = 1.25, Still = 0.8, MoveDist = 1.0 }

function DT.ShockEffect(part: number, maxHp: number, inc: number?): number
    if part <= 0 or maxHp <= 0 then return 0 end
    local s = DT.SHOCK
    return math.clamp(s.Scale * (part / maxHp) ^ s.Exp, s.Min, s.Max) * (1 + (inc or 0))
end
function DT.WitherStack(part: number, maxHp: number, inc: number?): number
    if part <= 0 or maxHp <= 0 then return 0 end
    local w = DT.WITHER
    return math.clamp(w.Scale * (part / maxHp) ^ w.Exp, w.Min, w.Max) * (1 + (inc or 0))
end

-- ==================== [PURE HELPERS] ====================
export type Typed = { [string]: number }

function DT.Empty(): Typed -- (FUTURE-PROOF 2026-10-25: built from ORDER -- a hand-written five made a NEW type's sums nil arithmetic)
    local out = {}
    for _, k in ipairs(DT.ORDER) do out[k] = 0 end
    return out
end

function DT.Sum(t: Typed?): number
    if not t then return 0 end
    local s = 0
    for _, k in ipairs(DT.ORDER) do s += t[k] or 0 end
    return s
end

-- the type with the biggest share (ties go to the leftmost); "Kinetic" for an empty table
function DT.MainType(t: Typed?): string
    local best, bv = "Kinetic", -1
    if t then
        for _, k in ipairs(DT.ORDER) do
            local v = t[k] or 0
            if v > bv then best, bv = k, v end
        end
    end
    return best
end

-- shares (0..1) per type
function DT.Shares(t: Typed?): Typed
    local out, s = DT.Empty(), DT.Sum(t)
    if s <= 0 or not t then out.Kinetic = 1 return out end
    for _, k in ipairs(DT.ORDER) do out[k] = (t[k] or 0) / s end
    return out
end

function DT.Scale(t: Typed, m: number): Typed
    local out = DT.Empty()
    for _, k in ipairs(DT.ORDER) do out[k] = (t[k] or 0) * m end
    return out
end

-- conv = { [src] = { [dst] = fraction } } (dst right of src only). A source's total converted share is capped at 100%
-- (scaled down proportionally above it). Runs left -> right, so converted damage can convert again further right.
-- Returns the converted typed table plus, per final type, the set of types each part passed through (for "increased
-- applies to converted damage from its old types too", the PoE rule) as chunks { Type, Origins = {..}, Amount }.
export type Chunk = { Type: string, Origins: { [string]: boolean }, Amount: number }
function DT.Convert(pre: Typed, conv: { [string]: { [string]: number } }?): (Typed, { Chunk })
    -- chunks per type: list of { origins set, amount }
    local buckets: { [string]: { Chunk } } = {}
    for _, k in ipairs(DT.ORDER) do
        buckets[k] = {}
        local v = pre[k] or 0
        if v > 0 then table.insert(buckets[k], { Type = k, Origins = { [k] = true }, Amount = v }) end
    end
    if conv then
        for i, src in ipairs(DT.ORDER) do
            local row = conv[src]
            if row then
                local total = 0
                for j = i + 1, #DT.ORDER do total += math.max(0, row[DT.ORDER[j]] or 0) end
                if total > 0 then
                    local scale = if total > 1 then 1 / total else 1
                    local kept = 1 - total * scale
                    local srcChunks = buckets[src]
                    buckets[src] = {}
                    for _, ch in ipairs(srcChunks) do
                        if kept > 0 then
                            table.insert(buckets[src], { Type = src, Origins = ch.Origins, Amount = ch.Amount * kept })
                        end
                        for j = i + 1, #DT.ORDER do
                            local dst = DT.ORDER[j]
                            local f = math.max(0, row[dst] or 0) * scale
                            if f > 0 then
                                local o = table.clone(ch.Origins)
                                o[dst] = true
                                table.insert(buckets[dst], { Type = dst, Origins = o, Amount = ch.Amount * f })
                            end
                        end
                    end
                end
            end
        end
    end
    local out, chunks = DT.Empty(), {}
    for _, k in ipairs(DT.ORDER) do
        for _, ch in ipairs(buckets[k]) do
            out[k] += ch.Amount
            table.insert(chunks, ch)
        end
    end
    return out, chunks
end

-- The pre-crit, pre-weak-spot typed hit:
--   base (gun, typed) + added (flat, typed) -> Convert -> x (1 + incGeneric + sum inc[t] over each part's origins)
--   -> x more (one number: the product of every "more").
-- inc = { Kinetic = 0.3, ... } (fractions); incGeneric = increased damage that applies to every type.
function DT.BuildHit(base: Typed, added: Typed?, conv: { [string]: { [string]: number } }?, inc: Typed?, incGeneric: number?, more: number?): Typed
    local pre = DT.Empty()
    for _, k in ipairs(DT.ORDER) do pre[k] = (base[k] or 0) + (if added then added[k] or 0 else 0) end
    local _, chunks = DT.Convert(pre, conv)
    local out = DT.Empty()
    local g, m = incGeneric or 0, more or 1
    for _, ch in ipairs(chunks) do
        local i = g
        if inc then for o in pairs(ch.Origins) do i += inc[o] or 0 end end
        out[ch.Type] += ch.Amount * math.max(0, 1 + i) * m
    end
    return out
end

-- apply enemy resistances per type: res = { Kinetic = r, ... } (missing = 0); returns the typed result + its sum
function DT.ApplyResists(hit: Typed, res: { [string]: number }?): (Typed, number)
    local out, s = DT.Empty(), 0
    for _, k in ipairs(DT.ORDER) do
        local r = if res then res[k] or 0 else 0
        r = math.clamp(r, DT.ENEMY_RESIST_FLOOR, DT.ENEMY_RESIST_CAP)
        local v = (hit[k] or 0) * (1 - r)
        out[k] = v
        s += v
    end
    return out, s
end

-- the multiplier a typed hit's resist step gives as a whole (damage after resists / damage before; 1 for empty)
function DT.ResistMult(shares: Typed?, res: { [string]: number }?): number
    if not shares then return 1 end
    local before, after = 0, 0
    for _, k in ipairs(DT.ORDER) do
        local v = shares[k] or 0
        local r = if res then math.clamp(res[k] or 0, DT.ENEMY_RESIST_FLOOR, DT.ENEMY_RESIST_CAP) else 0
        before += v
        after += v * (1 - r)
    end
    if before <= 0 then return 1 end
    return after / before
end

-- attribute name on enemy models / proxies
function DT.ResAttr(t: string): string
    return "Res_" .. t
end

-- read Res_<Type> attributes off an Instance into a table (missing = 0)
function DT.ReadResists(inst: Instance?): { [string]: number }
    local out = DT.Empty()
    if inst then
        for _, k in ipairs(DT.ORDER) do
            local v = inst:GetAttribute("Res_" .. k)
            if type(v) == "number" then out[k] = v end
        end
    end
    return out
end

-- writes Res_<Type> (only the non-zero ones) + ResSet = true (the marker that the enemy's resists were stamped)
function DT.WriteResists(inst: Instance, res: { [string]: number })
    for _, k in ipairs(DT.ORDER) do
        local v = res[k] or 0
        inst:SetAttribute("Res_" .. k, if v ~= 0 then math.round(v * 1000) / 1000 else nil)
    end
    inst:SetAttribute("ResSet", true)
end
-- every attribute name a stamped enemy may carry (DungeonRuns copies these onto the server stand-in)
DT.RES_ATTRS = { "ResSet" }
for _, k in ipairs(DT.ORDER) do table.insert(DT.RES_ATTRS, "Res_" .. k) end -- (FUTURE-PROOF: from ORDER)

return DT
