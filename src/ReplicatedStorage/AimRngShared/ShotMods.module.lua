--!nocheck
-- ShotMods (UPDATE 8 phase 3, owned by OFFENSE; vault "UPDATE 8 - The Revamp" section 6 "Guns = your skill").
-- A SHOT MOD ("Mod" in player text) goes into a gun socket of its colour and changes what the shot DOES. PoE support-gem
-- rules in our words: each mod has a trade-off ("more" / "less"), levels 1-20 from XP while socketed in the equipped gun,
-- quality 0-20 (a currency later; +0.5% more damage per point). No rarity tiers.
-- ACTIVE RULE (one readable rule): only the mods in the gun's LARGEST LINKED GROUP work (a tie = the first one); mods in
-- other groups are IDLE (shown dim in the socket window). Pure data + helpers: safe on server, client and the luau sims.
--
-- item: { Uid = "SM_..", Kind = "ShotMod", Mod = id, Level = 1..20, Xp = 0..1 (progress to the next level), Quality = 0..20 }
-- bag: state.ShotMods (cap BAG); socketed: weapon.SocketMods[socketIndex] = item (rides with the gun: stash / trade / market)

local ShotMods = {}
ShotMods.BAG = 80
ShotMods.MAX_LEVEL = 20
ShotMods.MAX_QUALITY = 20
ShotMods.QUALITY_MORE = 0.005 -- (+0.5% more damage per quality point)
-- XP: a socketed mod gains the kill XP you gain, as a share of YOUR level's XP bar; next level needs NEED_BASE + NEED_STEP x level
-- bars (L1 -> 2 = 0.26 of a player level, L19 -> 20 = 1.34; 1 -> 20 ~15 player levels of XP)
ShotMods.NEED_BASE, ShotMods.NEED_STEP = 0.2, 0.06
function ShotMods.Need(level: number): number return ShotMods.NEED_BASE + ShotMods.NEED_STEP * level end
-- LEVEL CAP by YOUR level (power curve rule: nothing maxes early): a mod works at most at LevelCap(your level) = 1 + level / 8
-- (level 20 from player level 152); it gains no levels past it. A higher-level mod (traded / gifted) works at the cap.
function ShotMods.LevelCap(playerLevel: number?): number return math.clamp(1 + math.floor((playerLevel or 1) / 8), 1, ShotMods.MAX_LEVEL) end
-- REQUIREMENT (UPDATE 8 phase 4): a mod needs its colour's attribute (R Strength, G Dexterity, B Intellect) = REQ_BASE +
-- REQ_PER_LEVEL x its working level (level 1 = 8, 10 = 39, 20 = 74). Unmet = the mod sits IDLE (Active skips it, the window says why).
ShotMods.REQ_BASE, ShotMods.REQ_PER_LEVEL = 4, 3.5
ShotMods.COLOR_ATTR = { R = "Strength", G = "Dexterity", B = "Intellect" }
function ShotMods.Req(item: any, playerLevel: number?): (string?, number)
    local d = ShotMods.Def(item)
    if not d or not ShotMods.COLOR_ATTR[d.Color] then return nil, 0 end
    local L = math.min(item.Level or 1, playerLevel and ShotMods.LevelCap(playerLevel) or ShotMods.MAX_LEVEL)
    return ShotMods.COLOR_ATTR[d.Color], math.round(ShotMods.REQ_BASE + ShotMods.REQ_PER_LEVEL * L)
end
-- nil = met (or no attributes known); else "Needs 50 Dexterity"
function ShotMods.Unmet(item: any, playerLevel: number?, attrs: any?): string?
    if type(attrs) ~= "table" then return nil end
    local a, n = ShotMods.Req(item, playerLevel)
    if a and (tonumber(attrs[a]) or 0) < n then return "Needs " .. n .. " " .. a end
    return nil
end
-- DROPS (CombatServer GiveKillRewards): chance per kill from UNLOCK; bosses drop higher levels (up to BOSS_LEVEL x your cap)
-- and favour the rarer mods (Roll flat 0.4)
ShotMods.DROP = { Unlock = 3, Fodder = 0.004, Bot = 0.01, Magic = 0.04, Rare = 0.08, Boss = 0.3, Super = 0.6, BOSS_LEVEL = 0.6 }

local function Lv(a, b) return function(L) return a + b * ((L or 1) - 1) end end

-- DEFS: Color R / G / B (Strength / Dexterity / Intellect; Heat red, Cryo green, Volt blue), Weight (drop odds;
-- bosses flatten them), Desc (player text, {v} = the value now), and At(L) -> the effect at level L:
--   More (damage x), FireRate (x, applied after the fire-rate caps), Mag (+x magazine), Off (typed offence stats, uncapped:
--   DamageTypes.OFFENCE_STATS keys), Cond (CombatServer cond stats), Fx (CombatServer.Off.ShotModFx mechanics), AilMore[type].
ShotMods.ORDER = {
    "Overcharge", "Impact", "Detonate", "AddedHeat", "ConvertHeat", "Kindle", "Rend", "Execute",
    "Rapid", "Chain", "Fork", "Ricochet", "Volley", "AddedCryo", "ConvertCryo", "Frostbite", "AmmoFeed",
    "AddedVolt", "ConvertVolt", "Static", "Mark", "Overkill", "Pierce", "NarrowBore",
}
ShotMods.DEFS = {
    -- RED
    Overcharge = { Name = "Overcharge", Color = "R", Weight = 10, Tag = "Damage",
        Desc = "{a}% more damage, 10% slower fire.", At = function(L) return { More = Lv(1.35, 0.006)(L), FireRate = 0.90, A = Lv(35, 0.6)(L) } end },
    -- (CLEAR PASS 2026-10-23, cbtree: awake enemies stand 11+ studs apart -- the bots' personal space -- and a Studio probe found
    -- Volley's 8-stud reach hit NOTHING in 362 tries and only 7% of all extra hits killed. Area mods now reach past that spacing
    -- and hit much harder, for a bigger "less": a clear link wins packs, a single-target link (Narrow Bore / Overcharge / Added)
    -- wins bosses and elites.)
    Impact = { Name = "Impact", Color = "R", Weight = 7, Tag = "Area",
        Desc = "Every hit bursts: {a}% of the hit to enemies within {r} studs.",
        At = function(L) return { More = 1.0, Fx = { Impact = { Pct = Lv(0.40, 0.005)(L), R = Lv(12, 0.2)(L) } }, A = Lv(40, 0.5)(L), Rr = Lv(12, 0.2)(L) } end },
    Detonate = { Name = "Detonate", Color = "R", Weight = 6, Tag = "Area",
        Desc = "Enemies you kill explode for {a}% of their max health within 16 studs. 5% more damage.",
        At = function(L) return { More = 1.05, Fx = { Detonate = { Pct = Lv(0.12, 0.004)(L), R = 16 } }, A = Lv(12, 0.4)(L) } end },
    AddedHeat = { Name = "Added Heat", Color = "R", Weight = 10, Tag = "Heat",
        Desc = "Adds Heat damage equal to {a}% of the gun's base hit.", At = function(L) return { Off = { LocalAddedHeat = Lv(0.28, 0.006)(L) }, A = Lv(28, 0.6)(L) } end },
    ConvertHeat = { Name = "Convert to Heat", Color = "R", Weight = 6, Tag = "Heat",
        Desc = "50% of Kinetic becomes Heat. {a}% more damage.", At = function(L) return { Off = { ConvertKineticToHeat = 0.5 }, More = Lv(1.18, 0.006)(L), A = Lv(18, 0.6)(L) } end },
    Kindle = { Name = "Kindle", Color = "R", Weight = 7, Tag = "Ailment",
        Desc = "+{a}% Burn chance, Burns deal {b}% more. 10% more damage.", At = function(L) return { More = 1.10, Off = { BurnChance = Lv(0.10, 0.005)(L) }, AilMore = { Heat = Lv(1.20, 0.01)(L) }, A = Lv(10, 0.5)(L), B = Lv(20, 1)(L) } end },
    Rend = { Name = "Rend", Color = "R", Weight = 7, Tag = "Ailment",
        Desc = "+{a}% Bleed chance, Bleeds deal {b}% more. 10% more damage.", At = function(L) return { More = 1.10, Off = { BleedChance = Lv(0.10, 0.005)(L) }, AilMore = { Kinetic = Lv(1.20, 0.01)(L) }, A = Lv(10, 0.5)(L), B = Lv(20, 1)(L) } end },
    Execute = { Name = "Execute", Color = "R", Weight = 5, Tag = "Damage",
        Desc = "Kills enemies left under {a}% health (not bosses; elites at half). 5% more damage.",
        At = function(L) return { More = 1.05, Cond = { ExecutePct = Lv(0.10, 0.004)(L) }, A = Lv(10, 0.4)(L) } end },
    -- GREEN
    Rapid = { Name = "Rapid", Color = "G", Weight = 10, Tag = "Speed",
        Desc = "{a}% faster fire.", At = function(L) return { FireRate = Lv(1.28, 0.005)(L), A = Lv(28, 0.5)(L) } end },
    Chain = { Name = "Chain", Color = "G", Weight = 6, Tag = "Area",
        Desc = "Hits jump to {n} more enemies within 36 studs for {a}% damage each. 8% less damage.",
        At = function(L) local n = 1 + ((L >= 10) and 1 or 0) + ((L >= 20) and 1 or 0)
            return { More = 0.92, Fx = { Chain = { N = n, Pct = Lv(0.90, 0.005)(L), R = 36 } }, N = n, A = Lv(90, 0.5)(L) } end },
    Fork = { Name = "Fork", Color = "G", Weight = 6, Tag = "Area",
        Desc = "Each hit splits to 2 enemies within 30 studs for {a}% damage each. 5% less damage.",
        At = function(L) return { More = 0.95, Fx = { Fork = { N = 2, Pct = Lv(0.85, 0.005)(L), R = 30 } }, A = Lv(85, 0.5)(L) } end },
    Ricochet = { Name = "Ricochet", Color = "G", Weight = 6, Tag = "Precision",
        Desc = "Headshots and crits bounce to {n} enemy within 35 studs for {a}% damage. 5% more damage.",
        At = function(L) local n = (L >= 15) and 2 or 1
            return { More = 1.05, Fx = { Ricochet = { N = n, Pct = Lv(0.70, 0.015)(L), R = 35 } }, N = n, A = Lv(70, 1.5)(L) } end },
    Volley = { Name = "Volley", Color = "G", Weight = 7, Tag = "Area",
        Desc = "Each hit also strikes 2 enemies within 18 studs for {a}% damage. 5% less damage.",
        At = function(L) return { More = 0.95, Fx = { Volley = { N = 2, Pct = Lv(0.80, 0.005)(L), R = 18 } }, A = Lv(80, 0.5)(L) } end },
    AddedCryo = { Name = "Added Cryo", Color = "G", Weight = 10, Tag = "Cryo",
        Desc = "Adds Cryo damage equal to {a}% of the gun's base hit.", At = function(L) return { Off = { LocalAddedCryo = Lv(0.28, 0.006)(L) }, A = Lv(28, 0.6)(L) } end },
    ConvertCryo = { Name = "Convert to Cryo", Color = "G", Weight = 6, Tag = "Cryo",
        Desc = "50% of Kinetic becomes Cryo. {a}% more damage.", At = function(L) return { Off = { ConvertKineticToCryo = 0.5 }, More = Lv(1.18, 0.006)(L), A = Lv(18, 0.6)(L) } end },
    Frostbite = { Name = "Frostbite", Color = "G", Weight = 7, Tag = "Ailment",
        Desc = "+{a}% Chill chance; Cryo builds Freeze {b}% faster. 10% more damage.",
        At = function(L) return { More = 1.10, Off = { ChillChance = Lv(0.10, 0.005)(L) }, Fx = { FreezeBuild = Lv(1.5, 0.03)(L) }, A = Lv(10, 0.5)(L), B = Lv(50, 3)(L) } end },
    AmmoFeed = { Name = "Ammo Feed", Color = "G", Weight = 8, Tag = "Speed",
        Desc = "+{a}% magazine size.", At = function(L) return { Mag = Lv(0.50, 0.02)(L), A = Lv(50, 2)(L) } end },
    -- BLUE
    AddedVolt = { Name = "Added Volt", Color = "B", Weight = 10, Tag = "Volt",
        Desc = "Adds Volt damage equal to {a}% of the gun's base hit.", At = function(L) return { Off = { LocalAddedVolt = Lv(0.28, 0.006)(L) }, A = Lv(28, 0.6)(L) } end },
    ConvertVolt = { Name = "Convert to Volt", Color = "B", Weight = 6, Tag = "Volt",
        Desc = "50% of Kinetic becomes Volt. {a}% more damage.", At = function(L) return { Off = { ConvertKineticToVolt = 0.5 }, More = Lv(1.18, 0.006)(L), A = Lv(18, 0.6)(L) } end },
    Static = { Name = "Static", Color = "B", Weight = 7, Tag = "Ailment",
        Desc = "+{a}% Shock chance, Shocks {b}% stronger. 10% more damage.", At = function(L) return { More = 1.10, Off = { ShockChance = Lv(0.10, 0.005)(L), ShockEffect = Lv(0.20, 0.01)(L) }, A = Lv(10, 0.5)(L), B = Lv(20, 1)(L) } end },
    Mark = { Name = "Mark", Color = "B", Weight = 6, Tag = "Precision",
        Desc = "Hits mark the target: it takes {a}% more damage for 4 s; the mark jumps to the nearest enemy when it dies.",
        At = function(L) return { Fx = { Mark = { Inc = Lv(0.18, 0.006)(L), T = 4, R = 30 } }, A = Lv(18, 0.6)(L) } end },
    Overkill = { Name = "Overkill", Color = "B", Weight = 6, Tag = "Damage",
        Desc = "{a}% of the damage past a kill carries into your next hit. 8% more damage.", At = function(L) return { More = 1.08, Cond = { OverkillCarry = Lv(0.40, 0.02)(L) }, A = Lv(40, 2)(L) } end },
    Pierce = { Name = "Pierce", Color = "B", Weight = 7, Tag = "Area",
        Desc = "Shots go through {n} enemy behind the target, keeping {a}% damage each.",
        At = function(L) local n = 1 + ((L >= 10) and 1 or 0) + ((L >= 20) and 1 or 0)
            return { Fx = { Pierce = { N = n, Keep = Lv(0.75, 0.01)(L) } }, N = n, A = Lv(75, 1)(L) } end },
    NarrowBore = { Name = "Narrow Bore", Color = "B", Weight = 5, Tag = "Damage",
        Desc = "{a}% more damage to the target you hit; chains, splits, bursts and explosions deal 50% less.",
        At = function(L) return { More = Lv(1.28, 0.006)(L), Fx = { AreaMult = 0.5 }, A = Lv(28, 0.6)(L) } end },
}
ShotMods.COLOR = { R = Color3.fromRGB(226, 87, 76), G = Color3.fromRGB(95, 211, 106), B = Color3.fromRGB(90, 166, 255), W = Color3.fromRGB(230, 230, 230) }
ShotMods.HEX = { R = "#e2574c", G = "#5fd36a", B = "#5aa6ff", W = "#e6e6e6" }
ShotMods.COLOR_NAME = { R = "Red", G = "Green", B = "Blue", W = "White" }

function ShotMods.Def(item: any): any return type(item) == "table" and ShotMods.DEFS[item.Mod] or nil end
function ShotMods.Name(item: any): string
    local d = ShotMods.Def(item)
    return (d and d.Name or "?") .. " " .. tostring(item and item.Level or 1)
end
-- description with the values at its level (+ quality)
function ShotMods.Describe(item: any): string
    local d = ShotMods.Def(item)
    if not d then return "" end
    local v = d.At(item.Level or 1)
    local function F(x) if not x then return "" end local r = math.round(x * 10) / 10 return (r == math.floor(r)) and tostring(math.floor(r)) or tostring(r) end
    local s = d.Desc:gsub("{a}", F(v.A)):gsub("{b}", F(v.B)):gsub("{n}", F(v.N)):gsub("{r}", F(v.Rr))
    local q = tonumber(item.Quality) or 0
    if q > 0 then s ..= string.format("  (Quality %d%%: +%s%% more damage)", q, F(q * ShotMods.QUALITY_MORE * 100)) end
    return s
end

local nextId = 0
function ShotMods.New(modId: string, level: number?, quality: number?): any
    nextId += 1
    return { Uid = "SM_" .. math.random(10000000, 99999999) .. nextId, Kind = "ShotMod", Mod = modId,
        Level = math.clamp(math.floor(level or 1), 1, ShotMods.MAX_LEVEL), Xp = 0, Quality = math.clamp(math.floor(quality or 0), 0, ShotMods.MAX_QUALITY) }
end
-- a random mod id; flat = weights^flat (bosses 0.4: rarer mods more often)
function ShotMods.Roll(flat: number?): string
    local tot, w = 0, {}
    for i, id in ipairs(ShotMods.ORDER) do w[i] = (ShotMods.DEFS[id].Weight or 5) ^ (flat or 1); tot += w[i] end
    local x = math.random() * tot
    for i, id in ipairs(ShotMods.ORDER) do x -= w[i]; if x <= 0 then return id end end
    return ShotMods.ORDER[1]
end

-- ===== sockets: which mods are ACTIVE (the largest linked group; a tie = the first) =====
-- groups from ItemData.SocketGroups are colour lists; here we need socket INDICES per group
function ShotMods.Groups(sockets: string?): { { number } }
    local groups, cur, i = {}, {}, 0
    if type(sockets) ~= "string" then return groups end
    for ch in string.gmatch(sockets, ".") do
        if ch == "R" or ch == "G" or ch == "B" or ch == "W" then i += 1; table.insert(cur, i)
        elseif ch == " " and #cur > 0 then table.insert(groups, cur); cur = {} end
    end
    if #cur > 0 then table.insert(groups, cur) end
    return groups
end
function ShotMods.SocketColor(sockets: string?, index: number): string?
    local i = 0
    if type(sockets) ~= "string" then return nil end
    for ch in string.gmatch(sockets, ".") do
        if ch == "R" or ch == "G" or ch == "B" or ch == "W" then i += 1; if i == index then return ch end end
    end
    return nil
end
function ShotMods.Fits(sockets: string?, index: number, item: any): boolean
    local c, d = ShotMods.SocketColor(sockets, index), ShotMods.Def(item)
    return c ~= nil and d ~= nil and (c == "W" or c == d.Color)
end
-- the active group's socket indices (a set) for a weapon
ShotMods.MAX_LINKS = { { 1, 2 }, { 10, 3 }, { 25, 4 }, { 45, 5 }, { 75, 6 } } -- { item level, biggest working link }
function ShotMods.MaxLinks(itemLevel: number?): number
    local m = 1
    for _, p in ipairs(ShotMods.MAX_LINKS) do if (itemLevel or 1) >= p[1] then m = p[2] end end
    return m
end
function ShotMods.ActiveSet(weapon: any): { [number]: boolean }
    local best
    for _, g in ipairs(ShotMods.Groups(type(weapon) == "table" and weapon.Sockets or nil)) do
        if not best or #g > #best then best = g end
    end
    -- (UPDATE 8 phase 4) links are gated by the gun's item level (ShotMods.MAX_LINKS: a 6-link works from ilvl 75); a
    -- bigger group (crafted / old) works up to that many sockets, the rest idle
    local cap = ShotMods.MaxLinks(type(weapon) == "table" and weapon.ItemLevel or 1)
    local set = {}
    for k, i in ipairs(best or {}) do if k <= cap then set[i] = true end end
    return set
end
-- the active mods on a weapon: { { Item, Def, V = At(level) } } (socket order)
function ShotMods.Active(weapon: any, playerLevel: number?, attrs: any?): { any }
    local out = {}
    local sm = type(weapon) == "table" and type(weapon.SocketMods) == "table" and weapon.SocketMods or nil
    if not sm then return out end
    local set = ShotMods.ActiveSet(weapon)
    local idx = {}
    for k in pairs(sm) do local n = tonumber(k) if n and set[n] then table.insert(idx, n) end end
    table.sort(idx)
    for _, n in ipairs(idx) do
        local it = sm[tostring(n)] or sm[n]
        local d = ShotMods.Def(it)
        if d and ShotMods.Fits(weapon.Sockets, n, it) and not ShotMods.Unmet(it, playerLevel, attrs) then -- (misfit / requirement unmet: idle)
            local L = math.min(it.Level or 1, playerLevel and ShotMods.LevelCap(playerLevel) or ShotMods.MAX_LEVEL)
            table.insert(out, { Item = it, Def = d, V = d.At(L), Index = n, Level = L })
        end
    end
    return out
end

-- ===== the compiled effect of a weapon's active mods (StatCalculator) =====
-- returns { More, FireRate, Mag, Off = { stat = v }, Cond = { stat = v }, Fx = { .. }, AilMore = { type = x }, List = { names } }
-- LINK FALLOFF (Phase 6, DEFENCE's measured proposal; owner: strong builds 2-4x an average one): the 4th, 5th and 6th active mod
-- (socket order) count at a power of LINK_FALLOFF for their More and FireRate -- a 6-link still beats a 3-link, by less.
ShotMods.FULL_LINKS, ShotMods.LINK_FALLOFF = 3, 0.5
function ShotMods.LinkPower(i: number): number return (i > (ShotMods.FULL_LINKS or 3)) and (ShotMods.LINK_FALLOFF or 0.5) or 1 end
function ShotMods.Compile(weapon: any, playerLevel: number?, attrs: any?): any
    local r = { More = 1, FireRate = 1, Mag = 0, Off = {}, Cond = {}, Fx = {}, AilMore = {}, List = {} }
    for ai, a in ipairs(ShotMods.Active(weapon, playerLevel, attrs)) do
        local v = a.V
        local ex = ShotMods.LinkPower(ai)
        r.More *= ((v.More or 1) * (1 + (tonumber(a.Item.Quality) or 0) * ShotMods.QUALITY_MORE)) ^ ex
        r.FireRate *= (v.FireRate or 1) ^ ex
        r.Mag += v.Mag or 0
        for k, x in pairs(v.Off or {}) do r.Off[k] = (r.Off[k] or 0) + x end
        for k, x in pairs(v.Cond or {}) do r.Cond[k] = (r.Cond[k] or 0) + x end
        for t, x in pairs(v.AilMore or {}) do r.AilMore[t] = (r.AilMore[t] or 1) * x end
        for k, x in pairs(v.Fx or {}) do
            if k == "AreaMult" or k == "FreezeBuild" then r.Fx[k] = (r.Fx[k] or 1) * x
            elseif type(x) == "table" then
                local cur = r.Fx[k]
                if not cur then r.Fx[k] = table.clone(x)
                else -- (two of the same: the stronger values, counts add)
                    for kk, xx in pairs(x) do
                        if kk == "N" then cur.N = (cur.N or 0) + xx else cur[kk] = math.max(cur[kk] or 0, xx) end
                    end
                end
            end
        end
        table.insert(r.List, a.Def.Name .. " " .. tostring(a.Level))
    end
    return r
end

-- every socketed mod on a weapon that no longer fits its socket (socket gone / recoloured): taken out, returned as a list
function ShotMods.Misfits(weapon: any): { any }
    local out = {}
    local sm = type(weapon) == "table" and type(weapon.SocketMods) == "table" and weapon.SocketMods or nil
    if not sm then return out end
    for k, it in pairs(sm) do
        local n = tonumber(k)
        if not (n and ShotMods.Fits(weapon.Sockets, n, it)) then table.insert(out, it); sm[k] = nil end
    end
    if next(sm) == nil then weapon.SocketMods = nil end
    return out
end
-- TYPICAL LINK (balance tooling 2026-10-23: DevCmd treesim "APPLYMODS" + tools/sim/classbal A.mods = "typical"): what an
-- average player has socketed at a level -- TYPICAL_N mods (3, 4 from TYPICAL_4_FROM), each at TYPICAL_LEVEL of the level cap,
-- rolled by drop weight from `seed` (no duplicates; with `attrs` a mod the build can't power is re-rolled), in one linked group of
-- their own colours. Replaces the gun's sockets / mods. Returns the mod ids. Own RNG: never touches math.random's seed.
ShotMods.TYPICAL_N, ShotMods.TYPICAL_4_FROM, ShotMods.TYPICAL_LEVEL = 3, 60, 0.75
function ShotMods.Typical(weapon: any, playerLevel: number, attrs: any?, seed: number?, only: { string }?): { string }
    local x = math.floor(((seed or 1) * 2654435761 + (playerLevel or 1) * 40503) % 2147483647)
    if x <= 0 then x = 12345 end
    local function R(): number x = (x * 48271) % 2147483647; return x / 2147483647 end
    local L = math.max(1, math.floor(ShotMods.LevelCap(playerLevel) * ShotMods.TYPICAL_LEVEL))
    local n = (playerLevel or 1) >= ShotMods.TYPICAL_4_FROM and 4 or ShotMods.TYPICAL_N
    local pool = only or ShotMods.ORDER
    local list, used = {}, {}
    for _ = 1, n do
        for _ = 1, 40 do
            local tot = 0
            for _, id in ipairs(pool) do if not used[id] then tot += ShotMods.DEFS[id].Weight or 5 end end
            if tot <= 0 then break end
            local r, pick = R() * tot, nil
            for _, id in ipairs(pool) do
                if not used[id] then r -= ShotMods.DEFS[id].Weight or 5; if r <= 0 then pick = id; break end end
            end
            pick = pick or pool[#pool]
            local it = ShotMods.New(pick, L, 0)
            if not ShotMods.Unmet(it, playerLevel, attrs) then used[pick] = true; table.insert(list, it); break end
            used[pick] = true -- (can't power it: don't roll it again)
        end
    end
    local cs, smap, ids = {}, {}, {}
    for i, it in ipairs(list) do cs[i] = ShotMods.DEFS[it.Mod].Color; smap[tostring(i)] = it; ids[i] = it.Mod end
    weapon.Sockets, weapon.SocketMods = (#cs > 0) and table.concat(cs, "-") or nil, (#cs > 0) and smap or nil
    return ids
end
-- the mods socketed in a weapon (any order)
function ShotMods.InGun(weapon: any): { any }
    local out = {}
    if type(weapon) == "table" and type(weapon.SocketMods) == "table" then
        for _, it in pairs(weapon.SocketMods) do if type(it) == "table" then table.insert(out, it) end end
    end
    return out
end

-- ==================== MOD SUPPLY (2026-11-07, builder scarce; owner: a shot-mod vendor in the city "so AOE isn't pure luck",
-- like PoE's gem vendor; contract docs/LOOT_SCARCITY_2026-11-07.md section 8) ====================
-- A small LEVEL-GATED stock of plain mods for in-game currency (never Robux / BOUND), sold at mod level 1, quality 0. One AREA mod
-- of each colour by level 16 so any socket colour can take area damage; the strong / rare mods (Chain, Fork, Detonate, Overcharge,
-- Narrow Bore, ...) stay DROP-ONLY so drops still matter. Prices are an investment against the scarce income (LOOT_SCARCITY).
-- APPEND ONLY. Row { Mod = id in DEFS, Level = the player level it opens at, Cost = { Scrap / Alloy / Prism = material keys, Gold } }.
-- Bought through remote ShotModAction "SupplyBuy" (CombatServer.Off.ShotModAct: the city / hideout only, never in a run).
-- Studio: DevCmd ["shotmod", "act", "SupplyBuy", modId] = the same buy path.
ShotMods.SUPPLY_NAME = "MOD SUPPLY"
ShotMods.SUPPLY = {
    { Mod = "AddedHeat", Level = 3, Cost = { Scrap = 30, Gold = 1000 } },
    { Mod = "AddedCryo", Level = 3, Cost = { Scrap = 30, Gold = 1000 } },
    { Mod = "AddedVolt", Level = 3, Cost = { Scrap = 30, Gold = 1000 } },
    { Mod = "Rapid", Level = 6, Cost = { Scrap = 50, Alloy = 3, Gold = 2500 } },
    { Mod = "Volley", Level = 12, Cost = { Scrap = 120, Alloy = 10, Gold = 6000 } },
    { Mod = "Pierce", Level = 12, Cost = { Scrap = 120, Alloy = 10, Gold = 6000 } },
    { Mod = "Impact", Level = 16, Cost = { Scrap = 160, Alloy = 14, Prism = 2, Gold = 10000 } },
}
ShotMods.SUPPLY_COST_ORDER = { "Scrap", "Alloy", "Prism", "Gold" }
ShotMods.SUPPLY_COST_NAME = { Scrap = "Scrap", Alloy = "Alloy", Prism = "Prism Shard", Gold = "gold" }
function ShotMods.SupplyRow(modId: any): any
    for _, r in ipairs(ShotMods.SUPPLY) do if r.Mod == modId then return r end end
    return nil
end
-- "120 Scrap  •  10 Alloy  •  6,000 gold"
function ShotMods.CostText(cost: any): string
    local parts = {}
    for _, k in ipairs(ShotMods.SUPPLY_COST_ORDER) do
        local n = cost and cost[k]
        if n and n > 0 then
            local s = string.reverse((string.gsub(string.reverse(tostring(math.floor(n))), "(%d%d%d)", "%1,")))
            if string.sub(s, 1, 1) == "," then s = string.sub(s, 2) end
            table.insert(parts, s .. " " .. ShotMods.SUPPLY_COST_NAME[k])
        end
    end
    return table.concat(parts, "  \u{2022}  ")
end
-- the first cost you're short of (nil = you can pay): materials = state.Materials, gold = state.Gold
function ShotMods.SupplyShort(cost: any, materials: any, gold: number?): string?
    for _, k in ipairs(ShotMods.SUPPLY_COST_ORDER) do
        local n = cost and cost[k] or 0
        local have = (k == "Gold") and (tonumber(gold) or 0) or (tonumber(type(materials) == "table" and materials[k]) or 0)
        if n > 0 and have < n then return ShotMods.SUPPLY_COST_NAME[k] end
    end
    return nil
end
-- data check (a list of errors): every row's mod exists, no mod sold twice, levels never go down, costs are known keys > 0
function ShotMods.SupplyCheck(): { string }
    local errs, seen, last = {}, {}, 0
    for i, r in ipairs(ShotMods.SUPPLY) do
        if not ShotMods.DEFS[r.Mod] then table.insert(errs, "SUPPLY[" .. i .. "] unknown mod " .. tostring(r.Mod)) end
        if seen[r.Mod] then table.insert(errs, "SUPPLY[" .. i .. "] " .. tostring(r.Mod) .. " sold twice") end
        seen[r.Mod] = true
        if type(r.Level) ~= "number" or r.Level < last then table.insert(errs, "SUPPLY[" .. i .. "] Level must not go down") end
        last = tonumber(r.Level) or last
        for k, n in pairs(r.Cost or {}) do
            if not ShotMods.SUPPLY_COST_NAME[k] or type(n) ~= "number" or n <= 0 then table.insert(errs, "SUPPLY[" .. i .. "] bad cost " .. tostring(k)) end
        end
    end
    return errs
end

return ShotMods
