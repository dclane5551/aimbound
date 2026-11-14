--!nocheck
-- ============================================================================================
-- SKILL-TREE GEMS (PoE jewel style). The passive tree has 12 Socket nodes (2 per sector, between
-- branches). Allocate a socket, then put a gem in it (hub only).
--   Common     1 stat                     Uncommon  2 stats
--   Rare       2 stats + a radius bonus   (every ALLOCATED node within the radius adds a little stat)
--   Epic       3 stats + a stronger radius bonus (or: notables in the radius are 30% stronger)
--   Legendary  2 stats + a transform of the nodes in its radius (fixed list, see Legendaries)
--   Mythic     1 stat  + one build-defining rule (fixed list, see Mythics)
-- At most 1 Mythic and MAX_LEGENDARY (6, was 2) Legendary-effect gems socketed at once (each effect once). Gem numbers roll within ranges (Tuning Kit
-- rerolls them at the Forge -- not built yet). Mythic gems only drop on Brutal and harder.
-- (0.61) Celestial..Infinite gems too: GemData.Generate rolls their shape, and their power keeps climbing.
-- A gem is plain data (saved as-is): { Uid, Kind = "Gem", Rarity, Name, Lines = { {Stat, Value} },
--   Radius = { Kind = "NodeStat", Stat, Value } | { Kind = "NotableBoost", Value } | nil, Unique = id | nil }
-- ============================================================================================
local HttpService = game:GetService("HttpService")
local ItemData = require(script.Parent:WaitForChild("ItemData"))
local SkillTreeData = require(script.Parent:WaitForChild("SkillTreeData"))

local GemData = {}

GemData.RADIUS = 250 -- tree canvas units (tree v4: ~8.5 nodes in reach on average, like the old tree's 175)
GemData.MAX_MYTHIC = 1
GemData.MAX_LEGENDARY = 6 -- (2026-10-14, owner: "only allowing up to 2 legendary gems with effects doesnt make sense ...
-- increase that limit a lot": 2 -> 6; the strongest effects are rarer drops instead, GemData.LegendaryWeight)
GemData.MAX_OWNED = 60 -- gem inventory cap (salvage the rest)

-- (UPDATE 8 RARITY v4: items now have 5 rarities; GEMS keep the old 15-step ladder until Phase 3 replaces them --
-- GemData.Rank / GemData.Rarities = ItemData.LegacyRank / LEGACY_RARITIES, rolled by ItemData.LegacyRollRarity)
local Rank = ItemData.LegacyRank
GemData.Rank = ItemData.LegacyRank
GemData.Rarities = ItemData.LEGACY_RARITIES
-- GEM GRADES v4 (UPDATE 8 LOOT): a gem's LABEL is one of the 5 rarities; the old 15-step ladder stays INSIDE GemData as the
-- roll (same odds, same shapes, same power -- g.OldRarity keeps it). Label by old step + shape (GemData.NewRarity):
--   Common / Uncommon as before; Rare + Epic -> Rare; a transform (old Legendary) or a big stat gem (old Celestial+) -> Mythic;
--   a build rule (old Mythic, or any rule gem above it) -> Relic.
-- The power is stored on the gem (g.PowerMult, g.RadiusMultV) so a relabelled old gem keeps its numbers and Tune. Old saves:
-- GemData.NormalizeGem (ItemData.NormalizeRarities calls it; g.GemV = 4 marks a done gem). Everything that ranks gems
-- (auto-salvage, SALVAGE UP TO, sorting) reads the new ranks (ItemData.RarityRank).
GemData.GRADES = { "Common", "Uncommon", "Rare", "Mythic", "Relic" }

-- Stat lines (Common ranges; higher rarities roll x RarityPower).
GemData.StatPool = {
    { Stat = "IncreasedDamage", Min = 0.04, Max = 0.07 },
    { Stat = "FireRateBonus", Min = 0.03, Max = 0.05 },
    { Stat = "CritChance", Min = 0.008, Max = 0.015 },
    { Stat = "CritMultiplier", Min = 0.06, Max = 0.12 },
    { Stat = "WeakSpotMultiplier", Min = 0.06, Max = 0.12 },
    { Stat = "MaxHPPct", Min = 0.04, Max = 0.07 },
    { Stat = "ArmorPct", Min = 0.08, Max = 0.14 },
    { Stat = "AllResist", Min = 0.03, Max = 0.06 },
    { Stat = "AilmentChance", Min = 0.05, Max = 0.10 },
    { Stat = "AilmentDuration", Min = 0.05, Max = 0.08 },
    { Stat = "BurnDamage", Min = 0.08, Max = 0.15 },
    { Stat = "BleedDamage", Min = 0.08, Max = 0.15 },
    { Stat = "FreezeEffect", Min = 0.06, Max = 0.12 },
    { Stat = "DecayEffect", Min = 0.06, Max = 0.12 },
    { Stat = "ChainKillDamage", Min = 0.008, Max = 0.015 },
    { Stat = "OverkillCarry", Min = 0.04, Max = 0.08 },
    { Stat = "PierceDamage", Min = 0.06, Max = 0.12 },
    { Stat = "ExecutePct", Min = 0.006, Max = 0.012 },
    { Stat = "MovementSpeed", Min = 0.02, Max = 0.04 },
    { Stat = "ReloadSpeedBonus", Min = 0.04, Max = 0.08 },
    { Stat = "MagSizeBonus", Min = 0.05, Max = 0.10 },
    { Stat = "LifeLeech", Min = 0.002, Max = 0.004 },
    { Stat = "StreakDamageBonus", Min = 0.002, Max = 0.004 },
    { Stat = "HPRegenPct", Min = 0.001, Max = 0.002 },
    { Stat = "SwitchDamage", Min = 0.05, Max = 0.10 },
    { Stat = "EliteDamage", Min = 0.06, Max = 0.12 },
    { Stat = "LowHealthEnemyDamage", Min = 0.06, Max = 0.12 },
}
-- Radius bonus: per ALLOCATED node in the radius (Rare range; Epic x1.5).
GemData.RadiusPool = {
    { Stat = "IncreasedDamage", Min = 0.008, Max = 0.012 },
    { Stat = "CritChance", Min = 0.002, Max = 0.004 },
    { Stat = "CritMultiplier", Min = 0.012, Max = 0.02 },
    { Stat = "WeakSpotMultiplier", Min = 0.01, Max = 0.02 },
    { Stat = "FireRateBonus", Min = 0.004, Max = 0.007 },
    { Stat = "MaxHPPct", Min = 0.006, Max = 0.01 },
    { Stat = "AilmentChance", Min = 0.01, Max = 0.015 },
    { Stat = "ChainKillDamage", Min = 0.0015, Max = 0.0025 },
    { Stat = "OverkillCarry", Min = 0.008, Max = 0.014 },
    { Stat = "LifeLeech", Min = 0.0004, Max = 0.0007 },
    { Stat = "AllResist", Min = 0.004, Max = 0.007 },
}
-- (0.61, owner: "Make sure gems also now scale to the rarity of loot we are up to"): gems use the whole 15-rarity ladder.
-- Above Mythic the power keeps climbing ~10% a step (about weapon RarityPowerMult ^ 0.35) up to ~3.9x at Infinite.
GemData.RarityPower = { Common = 1.0, Uncommon = 1.12, Rare = 1.25, Epic = 1.4, Legendary = 1.5, Mythic = 1.6,
    Celestial = 1.76, Transcendent = 1.95, Astral = 2.16, Empyrean = 2.39, Primordial = 2.64, Sovereign = 2.9,
    Eclipse = 3.21, Genesis = 3.54, Infinite = 3.93 }
GemData.LineCount = { Common = 1, Uncommon = 2, Rare = 2, Epic = 3, Legendary = 2, Mythic = 1 }
-- Above Mythic (rank 7+) a gem is one of three shapes, rolled at drop time; its numbers use its own rarity's power:
--   a Mythic build rule (1 line; only where Mythics may drop) / a Legendary transform (2 lines) / a stat gem (3 lines + radius)
GemData.HIGH_RULE, GemData.HIGH_UNIQUE = 0.30, 0.25
local function RadiusMult(rarity: string): number
    local rank = ItemData.LegacyRank[rarity] or 1
    if rank <= 3 then return 1.0 end
    return 1.5 * (GemData.RarityPower[rarity] or 1.4) / 1.4
end
GemData.RadiusMult = RadiusMult

-- Legendary: transforms the nodes in its radius.
GemData.Legendaries = {
    RESONANCE = { Name = "Resonant Prism", Icon = "◈",
        Text = "Minor nodes in its radius have DOUBLE effect." },
    CROWN = { Name = "Crown of Notables", Icon = "★",
        Text = "Notable nodes in its radius are 60% stronger." },
    THREAD = { Name = "Thread of Fate", Icon = "≈",
        Text = "Nodes in its radius can be allocated without being connected to your tree." },
    IRON_WILL = { Name = "Iron Will", Icon = "▣",
        Text = "Increased Max Health from nodes in its radius also counts as the same amount of Increased Damage." },
    GLASS_LENS = { Name = "Glass Lens", Icon = "◎",
        Text = "Defensive stats on nodes in its radius are converted: 75% of their value becomes Increased Damage instead." },
    CALIBRATED = { Name = "Calibrated Scope", Icon = "⊕",
        Text = "Increased Damage on nodes in its radius also counts as the same amount of Weak-Spot Damage." },
    HAIR_TRIGGER = { Name = "Hair Trigger", Icon = "↯",
        Text = "Fire Rate, Reload Speed and Magazine Size on nodes in its radius have DOUBLE effect." },
}
GemData.LegendaryOrder = { "RESONANCE", "CROWN", "THREAD", "IRON_WILL", "GLASS_LENS", "CALIBRATED", "HAIR_TRIGGER" }
-- (2026-10-14, owner: "maybe make the bigger effects more rare"): drop weights (of 100) -- the doublers are the rare ones
GemData.LegendaryWeight = { RESONANCE = 6, HAIR_TRIGGER = 8, CROWN = 12, THREAD = 14, CALIBRATED = 18, IRON_WILL = 20, GLASS_LENS = 22 }
local function RollLegendary(): string
    local total = 0
    for _, id in ipairs(GemData.LegendaryOrder) do total += GemData.LegendaryWeight[id] or 10 end
    local x = math.random() * total
    for _, id in ipairs(GemData.LegendaryOrder) do
        x -= GemData.LegendaryWeight[id] or 10
        if x <= 0 then return id end
    end
    return GemData.LegendaryOrder[#GemData.LegendaryOrder]
end

-- Mythic: one build-defining rule (read as SpecialMechanics flags by StatCalculator / CombatServer).
GemData.Mythics = {
    EMBER_HEART = { Name = "Ember Heart", Icon = "♦",
        Text = "Your Burns stack without limit (up to 20) but each deals 40% LESS damage." },
    CHAIN_OF_COMMAND = { Name = "Chain of Command", Icon = "∞",
        Text = "Weak-spot kills empower your next 3 hits: each deals 50% MORE damage." },
    ETERNAL_FOCUS = { Name = "Eternal Focus", Icon = "◉",
        Text = "Your Focus is never lost to misses or hits taken, and caps 15 higher." },
    HYDRA_COIL = { Name = "Hydra's Coil", Icon = "§",
        Text = "Your Bleeds stack up to 10 times." },
    REACTOR_CORE = { Name = "Reactor Core", Icon = "◈",
        Text = "Every 8th trigger pull that hits overloads: its target takes 150% extra damage." },
    UNDYING = { Name = "Undying", Icon = "♥",
        Text = "Once every 90 seconds, a killing blow leaves you at 40% health instead." },
    GLACIAL_TOMB = { Name = "Glacial Tomb", Icon = "✚",
        Text = "Enemies you Chill are frozen solid (cannot move) for the first second. Bosses are immune." },
    MIDAS_TOUCH = { Name = "Midas Touch", Icon = "¤",
        Text = "Kills have a 12% chance to pay 6x their gold. Your hits deal 10% LESS damage." },
    -- precision mythics (2026-10-02)
    SURGEON = { Name = "Surgeon's Hand", Icon = "✚",
        Text = "Weak-spot hits deal 25% MORE damage. Body shots can never crit." },
    HIGH_CALIBER = { Name = "High Caliber", Icon = "▲",
        Text = "Piercing guns pierce 1 more enemy and lose no damage passing through. Guns that don't pierce deal 10% LESS damage." },
    LAST_WORD = { Name = "Last Word", Icon = "†",
        Text = "The last round of every magazine always crits and deals 50% MORE damage." },
    TUNNEL_VISION = { Name = "Tunnel Vision", Icon = "◐",
        Text = "Each hit in a row on the same enemy deals 3% MORE damage (up to 45%). Switching targets resets it." },
}
GemData.MythicOrder = { "EMBER_HEART", "CHAIN_OF_COMMAND", "ETERNAL_FOCUS", "HYDRA_COIL", "REACTOR_CORE", "UNDYING", "GLACIAL_TOMB", "MIDAS_TOUCH",
    "SURGEON", "HIGH_CALIBER", "LAST_WORD", "TUNNEL_VISION" }

-- Defensive stats Glass Lens converts.
local DEFENSIVE = { MaxHPPct = true, ArmorPct = true, AllResist = true, FireResist = true, ColdResist = true,
    ChaosResist = true, HPRegenPct = true, LowLifeDR = true, StillDR = true }
GemData.DefensiveStats = DEFENSIVE

local function RoundTo(stat: string, v: number): number
    if math.abs(v) < 0.01 then return math.round(v * 100000) / 100000 end
    return math.round(v * 1000) / 1000
end

local function RollLine(def: any, power: number): { Stat: string, Value: number }
    -- (0.60f: movement speed stops at Mythic strength, ~6.4% -- the player stays slower than the bots)
    if def.Stat == "MovementSpeed" then power = math.min(power, GemData.RarityPower.Mythic) end
    local v = (def.Min + math.random() * (def.Max - def.Min)) * power
    return { Stat = def.Stat, Value = RoundTo(def.Stat, v) }
end

local function PickDistinct(pool: { any }, n: number): { any }
    local idx = {}
    for i = 1, #pool do idx[i] = i end
    local out = {}
    for _ = 1, math.min(n, #idx) do
        local k = math.random(1, #idx)
        table.insert(out, pool[idx[k]])
        table.remove(idx, k)
    end
    return out
end

-- Name: "<Rarity word> <best stat noun> Gem", or the unique's name (above Mythic: "<Rarity> <unique name>").
local RarityWord = { Common = "Rough", Uncommon = "Polished", Rare = "Radiant", Epic = "Flawless", Legendary = "", Mythic = "Flawless", Relic = "Flawless" }
local function GemName(g: any): string
    local high = g.GemV ~= 4 and (ItemData.LegacyRank[g.Rarity] or 1) > 6 -- (GEM GRADES v4: no old-grade prefix on a relabelled gem)
    if g.Unique then
        local u = GemData.Legendaries[g.Unique] or GemData.Mythics[g.Unique]
        if u then return high and (g.Rarity .. " " .. u.Name) or u.Name end
    end
    local first = g.Lines and g.Lines[1]
    local noun = first and ItemData.StatDefs[first.Stat] and ItemData.StatDefs[first.Stat].Noun or "Power"
    return (RarityWord[g.Rarity] or tostring(g.Rarity)) .. " Gem of " .. noun
end
GemData.GemName = GemName

-- Which shape a gem is: "Stat" (lines + maybe a radius), "Legendary" (a transform) or "Mythic" (a build rule).
function GemData.Shape(g: any): string
    if g.Unique and GemData.Mythics[g.Unique] then return "Mythic" end
    if g.Unique and GemData.Legendaries[g.Unique] then return "Legendary" end
    return "Stat"
end

-- allowRule: may this gem carry a Mythic build rule? (nil = yes, for dev / reward callers; drops pass whether the source
-- is a Mythic source). A Mythic roll from a source that can't give rules becomes a Legendary-shape gem instead.
function GemData.Generate(rarity: string, uniqueId: string?, allowRule: boolean?): any
    if rarity == "Relic" then rarity = "Mythic" end -- (GEM GRADES v4: a Relic gem = an old-ladder rule gem)
    rarity = Rank[rarity] and rarity or "Common"
    local rank = ItemData.LegacyRank[rarity] or 1
    local power = GemData.RarityPower[rarity] or 1
    local g = { Uid = HttpService:GenerateGUID(false), Kind = "Gem", Rarity = rarity, Lines = {} }
    -- the shape: fixed up to Mythic, rolled above it (or forced by a uniqueId)
    local shape = "Stat"
    if uniqueId and GemData.Mythics[uniqueId] then shape = "Mythic"
    elseif uniqueId and GemData.Legendaries[uniqueId] then shape = "Legendary"
    elseif rank == 5 then shape = "Legendary"
    elseif rank == 6 then shape = (allowRule ~= false) and "Mythic" or "Legendary"
    elseif rank > 6 then
        local x = math.random()
        if allowRule ~= false and x < GemData.HIGH_RULE then shape = "Mythic"
        elseif x < GemData.HIGH_RULE + GemData.HIGH_UNIQUE then shape = "Legendary" end
    end
    local lines = (shape == "Mythic" and 1) or (shape == "Legendary" and 2) or (rank > 6 and 3) or GemData.LineCount[rarity] or 1
    for _, def in ipairs(PickDistinct(GemData.StatPool, lines)) do
        table.insert(g.Lines, RollLine(def, power))
    end
    if shape == "Stat" and rank >= 3 then
        if rank >= 4 and math.random() < 0.35 then
            g.Radius = { Kind = "NotableBoost", Value = math.round(0.20 * RadiusMult(rarity) * 100) / 100 } -- (Epic 0.30)
        else
            local def = GemData.RadiusPool[math.random(1, #GemData.RadiusPool)]
            local l = RollLine(def, RadiusMult(rarity))
            g.Radius = { Kind = "NodeStat", Stat = l.Stat, Value = l.Value }
        end
    elseif shape == "Legendary" then
        g.Unique = uniqueId or RollLegendary()
    elseif shape == "Mythic" then
        g.Unique = uniqueId or GemData.MythicOrder[math.random(1, #GemData.MythicOrder)]
    end
    -- (GEM GRADES v4) the label goes onto the 5 rarities; the roll's power stays on the gem
    g.OldRarity, g.PowerMult, g.RadiusMultV = rarity, power, RadiusMult(rarity)
    g.Rarity, g.GemV = GemData.NewRarity(rarity, g.Unique), 4
    g.Name = GemName(g)
    return g
end
-- old ladder step + shape -> the 5-rarity label
function GemData.NewRarity(old: string, unique: string?): string
    local rank = ItemData.LegacyRank[old] or 1
    if rank <= 2 then return ItemData.LEGACY_RARITIES[rank] end
    if rank <= 4 then return "Rare" end
    if unique and GemData.Mythics[unique] then return "Relic" end
    return "Mythic"
end
-- an old save's gem -> GEM GRADES v4 (once; true = changed)
function GemData.NormalizeGem(g: any): boolean
    if type(g) ~= "table" or g.GemV == 4 or type(g.Rarity) ~= "string" then return false end
    local old = g.Rarity
    g.OldRarity = old
    g.PowerMult = GemData.RarityPower[old] or 1
    g.RadiusMultV = RadiusMult(old)
    g.Rarity, g.GemV = GemData.NewRarity(old, g.Unique), 4
    g.Name = GemName(g)
    return true
end
-- every gem in a save (bag, sockets, ground); returns how many changed
function GemData.NormalizeState(state: any): number
    local n = 0
    if type(state) ~= "table" then return 0 end
    for _, g in ipairs(type(state.Gems) == "table" and state.Gems or {}) do if GemData.NormalizeGem(g) then n += 1 end end
    for _, g in pairs(type(state.SocketedGems) == "table" and state.SocketedGems or {}) do if GemData.NormalizeGem(g) then n += 1 end end
    for _, d in pairs(type(state.PendingLoot) == "table" and state.PendingLoot or {}) do
        if type(d) == "table" and d.Kind == "Gem" and GemData.NormalizeGem(d.Item) then n += 1 end
    end
    -- the gem auto-salvage threshold (once: GemSalvageV4) -- an old grade above Rare becomes Rare (transforms / rules stay kept)
    if not state.GemSalvageV4 then
        local th = state.GemAutoSalvage
        if type(th) == "string" and th ~= "OFF" then
            local r = ItemData.LegacyRank[th] or 0
            state.GemAutoSalvage = (r <= 0 and "OFF") or (r <= 2 and ItemData.LEGACY_RARITIES[r]) or "Rare"
        end
        state.GemSalvageV4 = true
    end
    return n
end
-- salvage yield of one gem: by its label, bigger for an old high-power gem (Prism 14 x (power / 1.6)^3.5 from Mythic power up)
function GemData.Yield(g: any): { [string]: number }
    local r = type(g) == "table" and g.Rarity or "Common"
    local p = type(g) == "table" and tonumber(g.PowerMult) or nil
    if p and p > 1.6 then return { Prism = math.round(14 * (p / 1.6) ^ 3.5) } end -- (= the old +40% a grade above Mythic)
    if r == "Relic" then return { Prism = 14 } end
    if r == "Mythic" then return GemData.SalvageYield.Legendary end
    if r == "Rare" and p and p >= 1.4 then return GemData.SalvageYield.Epic end
    return GemData.SalvageYield[r] or {}
end

-- Rerolls a gem's numbers (same stats, same unique) -- the Tuning Kit action.
function GemData.Tune(g: any)
    local power = tonumber(g.PowerMult) or GemData.RarityPower[g.Rarity] or 1 -- (GEM GRADES v4: the roll's power)
    for _, line in ipairs(g.Lines or {}) do
        for _, def in ipairs(GemData.StatPool) do
            if def.Stat == line.Stat then line.Value = RollLine(def, power).Value end
        end
    end
    if g.Radius and g.Radius.Kind == "NodeStat" then
        for _, def in ipairs(GemData.RadiusPool) do
            if def.Stat == g.Radius.Stat then g.Radius.Value = RollLine(def, tonumber(g.RadiusMultV) or RadiusMult(g.Rarity)).Value end
        end
    end
end

-- Drop rarity: the SAME difficulty window as weapons (tierCap = ItemData.MaxRarityRank of the run), then clamped to the
-- gem cap (Legendary; Mythic only when allowed). (0.60e, owner: "Why am I getting so many uncommons and rares on
-- torments?" -- gems rolled the Legendary-topped window on every difficulty: ~30% Common / 40% Uncommon / 25% Rare even
-- on Torment.) (0.61: no gem cap any more -- a Singularity gem is Eclipse..Infinite like its weapons; whether it may
-- carry a Mythic RULE is GemData.Generate's allowRule.) Without a tierCap: the old Legendary/Mythic-topped window.
-- (RARITY v4: tierCap = ItemData.LegacyMaxRarityRank of the run -- the old ladder)
function GemData.RollRarity(luck: number?, allowMythic: boolean?, tierCap: number?): string
    if not tierCap then return ItemData.LegacyRollRarity(luck, allowMythic and 6 or 5) end
    return ItemData.LegacyRollRarity(luck, tierCap)
end
-- (0.71, owner: "Gems over legendary ... feel too common"): a gem sits in the tree for good (no item level, no replacing it
-- every few levels like a gun), so it can't follow the weapon ladder 1:1 -- from Oblivion up every gem was above Legendary.
-- After the normal roll, every rarity step above Legendary has to be EARNED: HIGH_KEEP per step, stop at the first miss.
-- A rolled Infinite stays Infinite 0.1% of the time; a rolled Mythic stays Mythic half the time.
GemData.HIGH_KEEP = 1 -- (0.99n RARITY LADDER v3: off -- the fixed ladder already makes every step above Legendary rare;
-- the extra thinning on top made high gems near impossible. Was 0.5)
function GemData.ThinRarity(rarity: string): string
    local rank = ItemData.LegacyRank[rarity] or 1
    if rank <= 5 then return rarity end
    local out = 5
    for step = 6, rank do
        if math.random() < GemData.HIGH_KEEP then out = step else break end
    end
    return ItemData.LEGACY_RARITIES[out] or rarity
end

-- Salvage yield (materials) per rarity.
GemData.SalvageYield = {
    Common = { Scrap = 3 }, Uncommon = { Scrap = 5 }, Rare = { Scrap = 6, Alloy = 2 },
    Epic = { Alloy = 4, Prism = 1 }, Legendary = { Alloy = 6, Prism = 4 }, Mythic = { Prism = 14 },
}
for rank = 7, #ItemData.LEGACY_RARITIES do -- (0.61) above Mythic: Mythic's yield, +40% a step
    local k = 1.4 ^ (rank - 6)
    GemData.SalvageYield[ItemData.LEGACY_RARITIES[rank]] = { Prism = math.round(14 * k) }
end

---------------------------------------------------------------------------------------------------
-- Geometry
---------------------------------------------------------------------------------------------------
local radiusCache: { [string]: { string } } = {}
-- Every node (not Origin/Start/Socket/Keystone) within the gem radius of a socket.
function GemData.NodesInRadius(socketId: string): { string }
    if radiusCache[socketId] then return radiusCache[socketId] end
    local out = {}
    local s = SkillTreeData[socketId]
    if s then
        for id, n in pairs(SkillTreeData) do
            if (n.Type == "Minor" or n.Type == "Notable") and (n.Position - s.Position).Magnitude <= GemData.RADIUS then
                table.insert(out, id)
            end
        end
    end
    table.sort(out)
    radiusCache[socketId] = out
    return out
end

function GemData.IsSocket(nodeId: string): boolean
    local n = SkillTreeData[nodeId]
    return n ~= nil and n.Type == "Socket"
end

-- Can `gem` go into `socketId` given what's already socketed? (limits: 1 Mythic rule, 2 Legendary transforms -- by
-- the gem's SHAPE, so a Celestial Crown of Notables still counts as a Legendary)
function GemData.CanSocket(socketed: { [string]: any }?, socketId: string, gem: any): (boolean, string?)
    if not GemData.IsSocket(socketId) then return false, "That isn't a gem socket." end
    local myth, leg = 0, 0
    for sid, g in pairs(socketed or {}) do
        if sid ~= socketId and type(g) == "table" then
            local sh = GemData.Shape(g)
            if sh == "Mythic" then myth += 1 elseif sh == "Legendary" then leg += 1 end
        end
    end
    local shape = GemData.Shape(gem)
    if shape == "Mythic" and myth >= GemData.MAX_MYTHIC then return false, "Only 1 gem with a build rule can be socketed at a time." end
    if shape == "Legendary" and leg >= GemData.MAX_LEGENDARY then return false, "Only " .. GemData.MAX_LEGENDARY .. " gems with a transform can be socketed at a time." end
    if gem.Unique then
        for sid, g in pairs(socketed or {}) do
            if sid ~= socketId and type(g) == "table" and g.Unique == gem.Unique then return false, "You already have " .. gem.Name .. " socketed." end
        end
    end
    return true
end

-- Nodes reachable for allocation through Thread of Fate gems (socket must be allocated).
function GemData.LeapNodes(socketed: { [string]: any }?, allocatedSet: { [string]: boolean }): { [string]: boolean }
    local out = {}
    for sid, g in pairs(socketed or {}) do
        if type(g) == "table" and g.Unique == "THREAD" and allocatedSet[sid] then
            for _, id in ipairs(GemData.NodesInRadius(sid)) do out[id] = true end
        end
    end
    return out
end

-- Everything the socketed gems do, for StatCalculator:
--   Flat = { stat = total }, NodeMult = { nodeId = multiplier }, IronWill / GlassLens / Calibrated = { nodeId = true },
--   StatBoost = { nodeId = { stat = extra multiplier } }, Mechanics = { MYTHIC_ID = true }
function GemData.Effects(socketed: { [string]: any }?, allocatedSet: { [string]: boolean }): any
    local fx = { Flat = {}, NodeMult = {}, IronWill = {}, GlassLens = {}, Calibrated = {}, StatBoost = {}, Mechanics = {} }
    if not socketed then return fx end
    for sid, g in pairs(socketed) do
        if type(g) == "table" and allocatedSet[sid] then
            for _, line in ipairs(g.Lines or {}) do
                if type(line.Stat) == "string" and type(line.Value) == "number" then
                    fx.Flat[line.Stat] = (fx.Flat[line.Stat] or 0) + line.Value
                end
            end
            local inRadius = GemData.NodesInRadius(sid)
            local r = g.Radius
            if r and r.Kind == "NodeStat" and type(r.Value) == "number" then
                local n = 0
                for _, id in ipairs(inRadius) do if allocatedSet[id] then n += 1 end end
                fx.Flat[r.Stat] = (fx.Flat[r.Stat] or 0) + r.Value * n
            elseif r and r.Kind == "NotableBoost" then
                for _, id in ipairs(inRadius) do
                    if SkillTreeData[id].Type == "Notable" then fx.NodeMult[id] = (fx.NodeMult[id] or 1) + (r.Value or 0.3) end
                end
            end
            local u = g.Unique
            if u == "RESONANCE" then
                for _, id in ipairs(inRadius) do
                    if SkillTreeData[id].Type == "Minor" then fx.NodeMult[id] = (fx.NodeMult[id] or 1) + 1 end
                end
            elseif u == "CROWN" then
                for _, id in ipairs(inRadius) do
                    if SkillTreeData[id].Type == "Notable" then fx.NodeMult[id] = (fx.NodeMult[id] or 1) + 0.6 end
                end
            elseif u == "IRON_WILL" then
                for _, id in ipairs(inRadius) do fx.IronWill[id] = true end
            elseif u == "GLASS_LENS" then
                for _, id in ipairs(inRadius) do fx.GlassLens[id] = true end
            elseif u == "CALIBRATED" then
                for _, id in ipairs(inRadius) do fx.Calibrated[id] = true end
            elseif u == "HAIR_TRIGGER" then
                for _, id in ipairs(inRadius) do fx.StatBoost[id] = { FireRateBonus = 1, ReloadSpeedBonus = 1, MagSizeBonus = 1 } end
            elseif u and GemData.Mythics[u] then
                fx.Mechanics[u] = true
            end
        end
    end
    return fx
end

---------------------------------------------------------------------------------------------------
-- Text (tooltips)
---------------------------------------------------------------------------------------------------
function GemData.Describe(g: any): { Title: string, Subtitle: string, Lines: { string }, Special: string? }
    local lines = {}
    for _, l in ipairs(g.Lines or {}) do table.insert(lines, ItemData.FormatStat(l.Stat, l.Value)) end
    if g.Radius then
        if g.Radius.Kind == "NodeStat" then
            table.insert(lines, ItemData.FormatStat(g.Radius.Stat, g.Radius.Value) .. " per allocated node in radius")
        elseif g.Radius.Kind == "NotableBoost" then
            table.insert(lines, string.format("Notables in radius are %d%% stronger", math.round((g.Radius.Value or 0.3) * 100)))
        end
    end
    local special
    local u = g.Unique and (GemData.Legendaries[g.Unique] or GemData.Mythics[g.Unique])
    if u then special = u.Text end
    -- (0.71) the subtitle says which socket limit it counts toward -- above Mythic the SHAPE decides, not the rarity
    local shape = GemData.Shape(g)
    local kind = (shape == "Mythic" and ("Build rule (" .. GemData.MAX_MYTHIC .. " at a time)")) or (shape == "Legendary" and ("Transform (" .. GemData.MAX_LEGENDARY .. " at a time)")) or "Stat gem"
    return { Title = g.Name or "Gem", Subtitle = (g.Rarity or "Common") .. " Gem  •  " .. kind, Lines = lines, Special = special }
end

-- WHAT IT GIVES YOU (2026-10-14, owner: "those effects dont even say what overall benefit it gives (i.e all minor nodes
-- double x damage, that needs to be shown somewhere)"): the extra stats a gem's radius / effect adds in `socketId` with the
-- nodes you have allocated now -- the same rules StatCalculator applies (node stats x mult, Glass Lens 75% of defence to
-- damage, Iron Will health -> damage, Calibrated damage -> weak spot, Hair Trigger doubles). Its own stat lines aren't
-- repeated. Overlapping radii of two gems are counted for each gem on its own (so: "about").
-- -> { Header = string, Lines = { string } } (Lines empty = nothing extra right now)
function GemData.Contribution(g: any, socketId: string, allocatedSet: { [string]: boolean }): any
    local inRadius = GemData.NodesInRadius(socketId)
    local have, notables, minors = 0, 0, 0
    for _, id in ipairs(inRadius) do
        if allocatedSet[id] then
            have += 1
            if SkillTreeData[id].Type == "Notable" then notables += 1 else minors += 1 end
        end
    end
    local sum: { [string]: number } = {}
    local function Add(stat, v) if v ~= 0 then sum[stat] = (sum[stat] or 0) + v end end
    local function EachStat(filter: (any) -> boolean, fn: (string, number) -> ())
        for _, id in ipairs(inRadius) do
            local n = SkillTreeData[id]
            if allocatedSet[id] and n and filter(n) then
                for stat, v in pairs(n.Stats or {}) do fn(stat, v) end
            end
        end
    end
    local r, u = g.Radius, g.Unique
    if r and r.Kind == "NodeStat" and type(r.Value) == "number" then Add(r.Stat, r.Value * have)
    elseif r and r.Kind == "NotableBoost" then EachStat(function(n) return n.Type == "Notable" end, function(st, v) Add(st, v * (r.Value or 0.3)) end) end
    if u == "RESONANCE" then EachStat(function(n) return n.Type == "Minor" end, function(st, v) Add(st, v) end)
    elseif u == "CROWN" then EachStat(function(n) return n.Type == "Notable" end, function(st, v) Add(st, v * 0.6) end)
    elseif u == "IRON_WILL" then EachStat(function() return true end, function(st, v) if st == "MaxHPPct" then Add("IncreasedDamage", v) end end)
    elseif u == "GLASS_LENS" then EachStat(function() return true end, function(st, v)
            if DEFENSIVE[st] then Add(st, -v); Add("IncreasedDamage", v * 0.75) end
        end)
    elseif u == "CALIBRATED" then EachStat(function() return true end, function(st, v) if st == "IncreasedDamage" then Add("WeakSpotMultiplier", v) end end)
    elseif u == "HAIR_TRIGGER" then EachStat(function() return true end, function(st, v)
            if st == "FireRateBonus" or st == "ReloadSpeedBonus" or st == "MagSizeBonus" then Add(st, v) end
        end)
    end
    local lines = {}
    local keys = {}
    for k in pairs(sum) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
        if math.abs(sum[k]) > 1e-6 then table.insert(lines, ItemData.FormatStat(k, sum[k])) end
    end
    if u == "THREAD" then
        local free = 0
        for _, id in ipairs(inRadius) do if not allocatedSet[id] then free += 1 end end
        table.insert(lines, free .. " node" .. (free == 1 and "" or "s") .. " in reach you can take without a path")
    end
    local header = string.format("RIGHT NOW: %d of %d nodes in its radius allocated (%d minor, %d notable)", have, #inRadius, minors, notables)
    if #lines == 0 and (r or (u and GemData.Legendaries[u])) then
        table.insert(lines, (have == 0) and "Nothing extra yet: allocate the nodes inside its ring"
            or "Nothing extra here: the nodes in its ring have no stats this effect changes")
    end
    return { Header = header, Lines = lines }
end

-- (0.61f) gem glyphs are plain font symbols, not Roblox emoji: they take the gem's text colour and theme
function GemData.Icon(g: any): string
    local u = g and g.Unique and (GemData.Legendaries[g.Unique] or GemData.Mythics[g.Unique])
    return u and u.Icon or "◆"
end

return GemData
