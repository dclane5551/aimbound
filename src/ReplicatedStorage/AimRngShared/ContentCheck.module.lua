--!nocheck
-- CONTENT CHECK (2026-10-25, owner: "make sure all of our systems are future proof. We will be adding future harder content, new
-- future modifiers and such ... in the same fashion as poe"). The game's content lives in many tables that must agree: a new
-- difficulty tier has ~30 per-tier rows, a map mod a def + its pool, a stat a StatDefs row ... and most lookups fall back
-- SILENTLY (a missing tier row gave Easy monster levels and Easy loot odds). This walks every one of those registries and lists
-- what a half-added entry is missing. ERROR = it will misbehave in play; WARN = probably wrong / worth a look.
-- Runs on the server at start in Studio (AimRngServer prints the summary; every finding is a warn); DevCmd ["contentcheck"]
-- returns the full list. The recipes for adding each kind of content: docs/EXTENDING.md.
-- Rule of thumb it enforces: a new entry is APPENDED (tier lists, boss trial tiers, unlock cards are stored by position).
local Shared = script.Parent

local ContentCheck = {}

local function Req(name: string): any
    local ok, m = pcall(function() return require(Shared:WaitForChild(name, 5)) end)
    return ok and m or nil
end

function ContentCheck.Run(): { { Level: string, Area: string, Msg: string } }
    local out = {}
    local function Add(level: string, area: string, msg: string) table.insert(out, { Level = level, Area = area, Msg = msg }) end
    local function Err(area, msg) Add("ERROR", area, msg) end
    local function Warn(area, msg) Add("WARN", area, msg) end

    local ID = Req("ItemData")
    local DG = Req("DungeonGenerator")
    local DT = Req("DamageTypes")
    local FM = Req("FloorMods")
    local RF = Req("Rifts")
    local SM = Req("ShotMods")
    local EA = Req("EnemyAttacks")
    local BAI = Req("BossAI")
    local BT = Req("BossTrials")
    local AT = Req("AscensionTrials")
    local AD = Req("AscendancyData")
    local ENC = Req("Encounters")
    local WB = Req("WorldBiomes")
    if not ID then Err("Core", "ItemData did not load") return out end

    -- ==================== DIFFICULTY TIERS ====================
    local order = ID.DifficultyOrder or {}
    local function Need(area: string, name: string, t: any, optional: boolean?)
        if type(t) ~= "table" then Err(area, name .. " is missing") return end
        for _, d in ipairs(order) do
            if rawget(t, d) == nil then
                if optional then Warn(area, string.format("%s has no row for %s (it falls back to a default)", name, d))
                else Err(area, string.format("%s has no row for %s (a silent fallback -- usually Easy's numbers)", name, d)) end
            end
        end
    end
    Need("Tiers", "ItemData.DifficultyModes", ID.DifficultyModes)
    Need("Tiers", "ItemData.DifficultyMinLevel", ID.DifficultyMinLevel)
    Need("Tiers", "ItemData.MONSTER_LEVEL", ID.MONSTER_LEVEL)
    Need("Tiers", "ItemData.DIFF_XP", ID.DIFF_XP)
    Need("Tiers", "ItemData.RUN_PACE", ID.RUN_PACE)
    Need("Tiers", "ItemData.RARITY_AREA", ID.RARITY_AREA)
    Need("Tiers", "ItemData.PACK_XP_TIER", ID.PACK_XP_TIER)
    Need("Tiers", "ItemData.LINKED_XP_TIER", ID.LINKED_XP_TIER)
    Need("Tiers", "ItemData.DifficultyRank", ID.DifficultyRank)
    if DG then
        Need("Tiers", "DungeonGenerator.DifficultyScaling", DG.DifficultyScaling)
        Need("Tiers", "DungeonGenerator.DifficultyLoot.Qty", DG.DifficultyLoot and DG.DifficultyLoot.Qty)
        Need("Tiers", "DungeonGenerator.DifficultyLoot.Luck", DG.DifficultyLoot and DG.DifficultyLoot.Luck)
        Need("Tiers", "DungeonGenerator.RareEliteChance", DG.RareEliteChance)
        Need("Tiers", "DungeonGenerator.ELITE_CHANCE", DG.ELITE_CHANCE)
        Need("Tiers", "DungeonGenerator.BOSS_HIT_EASE", DG.BOSS_HIT_EASE)
        Need("Tiers", "DungeonGenerator.RAMP_HP", DG.RAMP_HP, true)
        Need("Tiers", "DungeonGenerator.RAMP_HP_BOSS", DG.RAMP_HP_BOSS, true)
    end
    if BAI then Need("Tiers", "BossAI.DIFF_PACE", BAI.DIFF_PACE) end
    if EA then
        Need("Tiers", "EnemyAttacks.DifficultyWindup", EA.DifficultyWindup)
        Need("Tiers", "EnemyAttacks.SLOTS", EA.SLOTS)
    end
    if DT then Need("Tiers", "DamageTypes.RESIST_PENALTY", DT.RESIST_PENALTY, true) end
    -- the ladder climbs: min levels and monster levels never go down from one tier to the next (only append harder tiers)
    for i = 2, #order do
        local a, b = order[i - 1], order[i]
        local la, lb = ID.DifficultyMinLevel and ID.DifficultyMinLevel[a], ID.DifficultyMinLevel and ID.DifficultyMinLevel[b]
        if la and lb and lb < la then Err("Tiers", string.format("%s opens at level %d, below %s (%d): tiers must be appended in order", b, lb, a, la)) end
        local ma = ID.MONSTER_LEVEL_BUILT and ID.MONSTER_LEVEL_BUILT[a] or (ID.MONSTER_LEVEL and ID.MONSTER_LEVEL[a])
        local mb = ID.MONSTER_LEVEL_BUILT and ID.MONSTER_LEVEL_BUILT[b] or (ID.MONSTER_LEVEL and ID.MONSTER_LEVEL[b])
        if ma and mb and mb[1] < ma[1] then Err("Tiers", string.format("%s monster levels start below %s's", b, a)) end
    end
    if ID.MAX_LEVEL ~= ID.CONTENT_CAP then Err("Cap", "MAX_LEVEL and CONTENT_CAP differ -- the level cap and the content cap are one number") end
    if (ID.MAX_LEVEL or 0) > (ID.MAX_LEVEL_BUILT or 0) then
        Warn("Cap", string.format("the level cap %d is past MAX_LEVEL_BUILT %d: re-run powercurve / the anchors, raise MAX_LEVEL_BUILT", ID.MAX_LEVEL, ID.MAX_LEVEL_BUILT))
    end
    if RF then
        for _, d in ipairs(RF.LADDER or {}) do
            if not table.find(order, d) then Err("Maps", "Rifts.LADDER names " .. d .. ", not a difficulty") end
            if not (RF.GUARDIANS and RF.GUARDIANS[d]) then Warn("Maps", "Rifts.GUARDIANS has no row for the map band " .. d .. " (it plays at the top band's pace)") end
        end
    end

    -- ==================== AFFIX TIERS ====================
    local nT = #(ID.TIER_ILVL or {})
    if #(ID.AFFIX_TIER_ILVL or {}) ~= (ID.AFFIX_TIER_MAX or 0) or #(ID.AFFIX_TIER_WEIGHT or {}) ~= (ID.AFFIX_TIER_MAX or 0) then
        Err("Affixes", "AFFIX_TIER_ILVL / AFFIX_TIER_WEIGHT / AFFIX_TIER_MAX lengths differ")
    end
    if nT > (ID.AFFIX_TIER_MAX or 0) then
        Warn("Affixes", string.format("TIER_ILVL has %d tiers, the range tables %d: tiers past them use the last step (ItemData.AffixTierLo / Hi)", nT, ID.AFFIX_TIER_MAX or 0))
    end
    for i = 2, nT do
        if ID.TIER_ILVL[i] < ID.TIER_ILVL[i - 1] then Err("Affixes", "TIER_ILVL goes down at tier " .. i) end
    end

    -- ==================== STATS (every rolled line has a StatDefs row) ====================
    local SD = ID.StatDefs or {}
    local seen = {}
    local function Stat(area: string, stat: any, where: string)
        if type(stat) ~= "string" or seen[stat] then return end
        seen[stat] = true
        if not SD[stat] then Err(area, string.format("stat '%s' (%s) has no StatDefs row: it rounds as a flat stat and shows its raw key", stat, where)) end
    end
    for _, d in ipairs(ID.WeaponPrefixPool or {}) do Stat("Stats", d.Stat, "gun prefix") end
    for _, d in ipairs(ID.WeaponSuffixPool or {}) do Stat("Stats", d.Stat, "gun suffix") end
    for _, d in ipairs(ID.GEAR_POOL_V3 or {}) do Stat("Stats", d.Stat, "gear line") end
    for id, b in pairs(ID.GEAR_BASES or {}) do
        local im = type(b) == "table" and b.Implicit
        if type(im) == "table" then Stat("Stats", im.Stat, "gear base " .. tostring(id) .. " implicit") end
    end

    -- ==================== DAMAGE TYPES ====================
    if DT then
        for _, t in ipairs(DT.ORDER or {}) do
            for _, k in ipairs({ "COLOR", "LABEL", "AILMENT", "ADDED_STAT", "INC_STAT", "AIL_CHANCE_STAT" }) do
                if not (DT[k] and DT[k][t]) then Err("DamageTypes", string.format("DamageTypes.%s has no entry for %s", k, t)) end
            end
            if rawget(DT.AILMENT_BASE_CHANCE or {}, t) == nil then Warn("DamageTypes", "AILMENT_BASE_CHANCE has no entry for " .. t .. " (default 10%)") end
        end
    end

    -- ==================== FLOOR / MAP MODS ====================
    if FM then
        local defs = FM.Defs or {}
        local function Pool(name: string, list: any)
            for _, id in ipairs(type(list) == "table" and list or {}) do
                if not defs[id] then Err("FloorMods", string.format("%s names '%s', which has no FloorMods def", name, tostring(id))) end
            end
        end
        Pool("FloorMods.Order", FM.Order)
        Pool("FloorMods.RISKS", FM.RISKS)
        for k, p in pairs(FM.PATHS or {}) do Pool("FloorMods.PATHS." .. k, p.Gifts) end
        if RF then
            Pool("Rifts.MOD_POOL", RF.MOD_POOL)
            for id, u in pairs(RF.UNIQUES or {}) do Pool("Rifts.UNIQUES." .. id, u.Mods) end
        end
        for id, d in pairs(defs) do
            if type(d.Name) ~= "string" or type(d.Text) ~= "string" then Err("FloorMods", id .. " needs Name and Text") end
            if typeof(d.Color) ~= "Color3" then Err("FloorMods", id .. " needs a Color (the banner calls ToHex on it)") end
            if d.MinTier ~= nil and type(d.MinTier) ~= "number" then Err("FloorMods", id .. ".MinTier must be a map tier number") end
            if d.Weight ~= nil and (type(d.Weight) ~= "number" or d.Weight < 0) then Err("FloorMods", id .. ".Weight must be a number >= 0") end
            if d.Load ~= nil and (type(d.Load) ~= "number" or d.Load < 0) then Err("FloorMods", id .. ".Load must be a number >= 0") end
        end
        -- (MAP PACING 2026-10-31) every map-pool mod says how much longer it makes a clear (Load, 0 = pure danger), so the Rare
        -- map's load budget (Rifts.LOAD_CAP) can't be dodged by a new mod; a single mod over the cap could never roll
        if RF and RF.ModPool then
            local ok, pool = pcall(RF.ModPool)
            for _, id in ipairs(ok and pool or {}) do
                local d = defs[id]
                if d and d.Load == nil then Err("Maps", id .. " is in the map pool with no Load (MAP PACING: measure it with tools/map_pace.luau; 0 = pure danger)") end
                local free = d and d.Group and RF.LOAD_FREE_GROUPS and RF.LOAD_FREE_GROUPS[d.Group] -- (MAP HEALTH: own slot, outside the cap)
                if d and not free and type(d.Load) == "number" and RF.LOAD_CAP and d.Load > RF.LOAD_CAP then Err("Maps", id .. ".Load is over Rifts.LOAD_CAP: it can never roll") end
            end
        end
    end

    -- ==================== ELITE MODS ====================
    if DG then
        local defs = DG.EliteMods or {}
        for _, k in ipairs(DG.EliteModKeys or {}) do
            local group = DG.ELITE_GROUPS and DG.ELITE_GROUPS[k]
            if group then
                for _, v in ipairs(group) do if not defs[v] then Err("EliteMods", string.format("group %s's variant %s has no EliteMods def", k, v)) end end
            elseif not defs[k] then
                Err("EliteMods", k .. " rolls but has no EliteMods def (Word / Desc)")
            end
        end
        for _, v in ipairs(DG.ELITE_EXTRA or {}) do
            if not (DG.ELITE_EXTRA_KEY and DG.ELITE_EXTRA_KEY[v]) then Err("EliteMods", v .. " is an Extra variant with no ELITE_EXTRA_KEY element") end
        end
        for id, d in pairs(defs) do
            if type(d.Word) ~= "string" or type(d.Desc) ~= "string" then Err("EliteMods", id .. " needs Word and Desc") end
        end
    end

    -- ==================== BOT ROLES (ENEMY ATTACKS PILOT 2026-10-30; AimRngShared/BotRoles) ====================
    local BR = Req("BotRoles")
    if BR and DG then
        local arches = DG.BotArchetypes or {}
        for id, row in pairs(BR.ROWS or {}) do
            local A = arches[id]
            local function E(msg) Err("BotRoles", id .. ": " .. msg) end
            if not A then E("has a role row but no BotArchetypes entry") end
            if not (BR.ROLES or {})[row.Role or ""] then E("unknown Role " .. tostring(row.Role)) end
            local ar = (BR.ATTACK_ROLE or {})[row.Attack or ""]
            if not ar then E("unknown Attack " .. tostring(row.Attack))
            elseif ar ~= row.Role then E(string.format("Attack %s is a %s attack, not %s", row.Attack, ar, tostring(row.Role))) end
            if row.Attack == "Burst" and not (type(row.Shots) == "number" and row.Shots >= 1 and row.Shots <= 3) then E("a Burst needs Shots 1-3") end
            if row.Attack == "Shell" and not (type(row.Count) == "number" and row.Count >= 1 and row.Count <= 2) then E("a Shell needs Count 1-2") end
            if A and A.Melee and not (row.Attack == "Swing" or row.Attack == "Dash" or row.Attack == "Slam") then
                E("a melee bot only runs Swing / Dash / Slam (its ranged branch never runs)")
            end
            if A and not A.Melee and (row.Attack == "Swing" or row.Attack == "Slam") then E(row.Attack .. " needs a melee bot (A.Melee)") end
            if row.Attack == "Slam" and not row.Keep then E("Slam = the old floor slam: set Keep = true") end
            if row.Fallback and not (BR.ATTACK_ROLE or {})[row.Fallback.Attack or ""] then E("Fallback has an unknown Attack") end
            -- (POE DAMAGE MODEL) every attack is tagged Chip / Spike; Contact = rushers, Aura = casters
            if row.Tag ~= "Chip" and row.Tag ~= "Spike" then E("needs Tag = \"Chip\" or \"Spike\" (POE DAMAGE MODEL)") end
            if row.Fallback and row.Fallback.Tag ~= "Chip" and row.Fallback.Tag ~= "Spike" then E("Fallback needs Tag = \"Chip\" or \"Spike\"") end
            if row.Contact and row.Role ~= "Rusher" then E("Contact (a jab) is a Rusher piece") end
            if row.Contact and not (type(row.Contact.Mult) == "number" and row.Contact.Mult > 0 and row.Contact.Mult <= 1) then E("Contact.Mult must be 0-1 (chip)") end
            if row.Aura and row.Role ~= "Caster" then E("Aura is a Caster piece") end
            if row.ChipShots and not (type(row.ChipShots) == "number" and row.ChipShots >= 1 and row.ChipShots <= 3) then E("ChipShots must be 1-3 (the volley fan, BotRoles FAN_OFF)") end
            if row.Every and not (row.Tag == "Spike" and (row.Attack == "Shell" or row.Attack == "Aimed") and type(row.Every) == "number" and row.Every >= 2) then
                E("Every (spike every n-th attack) needs a Spike Shell / Aimed row and a number >= 2") end
            if row.Aura and not (type(row.Aura.Mult) == "number" and row.Aura.Mult > 0 and row.Aura.Mult <= 0.5) then E("Aura.Mult (a tick) must be 0-0.5 (chip)") end
            if EA and BR.Rounds and BR.Rounds(row) > (EA.SHOT_CAP or 6) then E("puts more rounds in the air than EnemyAttacks.SHOT_CAP") end
            if DG.BotLore and not DG.BotLore[id] then Warn("BotRoles", id .. " has no BotLore (Index bestiary) text") end
        end
        for id, A in pairs(arches) do -- (the common roster has a role; biome rosters are converted by appending rows)
            if not A.Biome and not (BR.ROWS or {})[id] then Warn("BotRoles", id .. " (common roster) has no BotRoles row: it keeps the old floor attack") end
        end
        -- ==================== ENEMY VARIETY (2026-11-07; AimRngShared/BotVerbs: one verb per common bot, pack families) ====================
        local BV = BR.Verbs
        if BV then
            local verbs = {}
            local function V(msg) Err("BotVerbs", msg) end
            for id, row in pairs(BV.ROWS or {}) do
                local A = arches[id]
                if not A then V(id .. ": no BotArchetypes entry") end
                if A and A.Biome then Warn("BotVerbs", id .. " is a biome bot: biome families get their own rows (docs/ENEMY_VARIETY_2026-11-07.md)") end
                if not (BR.ROLES or {})[row.Role or ""] then V(id .. ": unknown Role " .. tostring(row.Role)) end
                local ar = (BR.ATTACK_ROLE or {})[row.Attack or ""]
                if not ar then V(id .. ": unknown Attack " .. tostring(row.Attack)) elseif ar ~= row.Role then V(id .. ": Attack " .. row.Attack .. " is a " .. ar .. " attack") end
                if row.Tag ~= "Chip" and row.Tag ~= "Spike" then V(id .. ": needs Tag Chip / Spike") end
                if type(row.Verb) ~= "string" or row.Verb == "" then V(id .. ": needs a Verb name")
                elseif verbs[row.Verb] then V(id .. ": Verb '" .. row.Verb .. "' is " .. verbs[row.Verb] .. "'s too (owner rule: no two bots do the same thing)")
                else verbs[row.Verb] = id end
                if row.Attack == "Burst" and not (type(row.Shots) == "number" and row.Shots >= 1 and row.Shots <= 3) then V(id .. ": a Burst needs Shots 1-3") end
                if A and A.Melee and not (row.Attack == "Swing" or row.Attack == "Dash" or row.Attack == "Slam") then V(id .. ": a melee bot only runs Swing / Dash / Slam") end
                if row.Fallback and not ((BR.ATTACK_ROLE or {})[row.Fallback.Attack or ""] and (row.Fallback.Tag == "Chip" or row.Fallback.Tag == "Spike")) then V(id .. ": Fallback needs a known Attack + Tag") end
                if (row.Attack == "Beacon" or row.Attack == "Counter" or row.Attack == "Raise") and not row.Fallback then V(id .. ": " .. row.Attack .. " needs a Fallback attack") end
                if row.Boost and not (type(row.Boost) == "number" and row.Boost > 0 and row.Boost <= 0.5) then V(id .. ": Boost must be 0-0.5") end
                if row.Rate and not (type(row.Rate) == "number" and row.Rate >= 0.4 and row.Rate <= 2) then V(id .. ": Rate must be 0.4-2") end
                if EA and BR.Rounds and BR.Rounds(row) > (EA.SHOT_CAP or 6) then V(id .. ": more rounds in the air than EnemyAttacks.SHOT_CAP") end
                if not (BV.LORE or {})[id] then Warn("BotVerbs", id .. " has no LORE (bestiary) row") end
            end
            for id, v in pairs(BV.KEEP or {}) do
                if not (BR.ROWS or {})[id] then V("KEEP." .. id .. " has no BotRoles row") end
                if (BV.ROWS or {})[id] then V("KEEP." .. id .. " also has a BotVerbs row") end
                if verbs[v] then V("KEEP." .. id .. ": Verb '" .. v .. "' is " .. verbs[v] .. "'s too") else verbs[v] = id end
            end
            for id, A in pairs(arches) do
                if not A.Biome and not (BV.ROWS or {})[id] and not (BV.KEEP or {})[id] then Warn("BotVerbs", id .. " (common roster) has no verb of its own (BotVerbs.ROWS / KEEP)") end
            end
            for k, row in pairs(BV.LITE or {}) do
                if row and not ((BR.ATTACK_ROLE or {})[row.Attack or ""] and (row.Tag == "Chip" or row.Tag == "Spike")) then V("LITE." .. k .. ": needs a known Attack + Tag") end
                if row and EA and BR.Rounds and BR.Rounds(row) > (EA.SHOT_CAP or 6) then V("LITE." .. k .. ": more rounds in the air than EnemyAttacks.SHOT_CAP") end
            end
            -- (2026-11-07 owner call: a perfect dodger still takes ~half) Every = its chip fan / tracer between the verb's attacks
            local EVERY_OK = { Burst = true, Aimed = true, Seeker = true }
            local function EveryCheck(name, row)
                if not row then return end
                if row.Every and not (row.Tag == "Spike" and EVERY_OK[row.Attack or ""] and type(row.Every) == "number" and row.Every >= 2) then
                    V(name .. ": Every needs a Spike Burst / Aimed / Seeker row and a number >= 2") end
                if row.ChipShots and not (type(row.ChipShots) == "number" and row.ChipShots >= 1 and row.ChipShots <= 3) then V(name .. ": ChipShots must be 1-3") end
                if row.ChipMult and not (type(row.ChipMult) == "number" and row.ChipMult > 0 and row.ChipMult <= 2.5) then V(name .. ": ChipMult must be 0-2.5") end
            end
            for id, row in pairs(BV.ROWS or {}) do EveryCheck(id, row) end
            for k, row in pairs(BV.LITE or {}) do EveryCheck("LITE." .. k, row) end
            -- two packs in a room are consecutive pack numbers: neighbours (and the wrap) must differ
            local pk = BV.PACK_KINDS or {}
            for i = 1, #pk do if pk[i] == pk[(i % #pk) + 1] then V("PACK_KINDS[" .. i .. "] and its neighbour are both " .. tostring(pk[i]) .. " (two packs of a room would share a family)") end end
            for id, k in pairs(BV.LITE_OF or {}) do
                if (BV.LITE or {})[k] == nil then V("LITE_OF." .. id .. " -> " .. tostring(k) .. " is not a LITE row") end
                if not arches[id] then V("LITE_OF." .. id .. " is not a BotArchetypes id") end
            end
            for i, k in ipairs(BV.PACK_KINDS or {}) do if (BV.LITE or {})[k] == nil then V("PACK_KINDS[" .. i .. "] " .. tostring(k) .. " is not a LITE row") end end
            for _, pool in ipairs({ BV.PRIORITY_POOL or {}, BV.PRESSURE_POOL or {} }) do
                for _, e in ipairs(pool) do if not arches[e[1]] then V("pairing pool: " .. tostring(e[1]) .. " is not a BotArchetypes id") end end
            end
        end
        -- ==================== BOT MOVEMENT POE (2026-10-30; AimRngShared/BotMove) ====================
        local BM = Req("BotMove")
        if BM then
            for _, role in ipairs(BR.ORDER or {}) do
                local P = (BM.ROLE or {})[role]
                if not P then Err("BotMove", "role " .. role .. " has no BotMove.ROLE movement row (its bots would keep their old pattern)")
                elseif not (type(P.Speed) == "number" and P.Speed > 0 and type(P.Accel) == "number" and P.Accel > 0) then Err("BotMove", role .. ": Speed + Accel must be numbers > 0") end
            end
            for _, tbl in ipairs({ "FAST", "STYLE" }) do
                for id in pairs(BM[tbl] or {}) do
                    if not arches[id] then Err("BotMove", tbl .. "." .. id .. " is not a BotArchetypes id") end
                    if not (BR.ROWS or {})[id] then Warn("BotMove", tbl .. "." .. id .. " has no BotRoles row: it moves by its old pattern, the row does nothing") end
                end
            end
            for id, f in pairs(BM.FAST or {}) do
                if not (type(f.Speed) == "number" and f.Speed >= 1 and f.Speed <= 2.5) then Err("BotMove", "FAST." .. id .. ".Speed must be 1-2.5") end
                if f.Hp and not (type(f.Hp) == "number" and f.Hp > 0 and f.Hp <= 1) then Err("BotMove", "FAST." .. id .. ".Hp must be 0-1 (fragile)") end
            end
            if not (type(BM.CAP_DEG) == "number" and BM.CAP_DEG > 0) then Err("BotMove", "CAP_DEG (the readability cap) must be a number > 0") end
            -- (review) the map device's reward per bot-skill step: one row a step, never less for a harder step, never above 2.0 (the old top)
            local RF = Req("Rifts")
            local MR = RF and RF.MAP_REWARD
            if RF and not (type(MR) == "table" and #MR == 10) then Err("BotMove", "Rifts.MAP_REWARD needs 10 rows (bot-skill steps 1-10)")
            elseif MR then
                for i = 1, 10 do
                    if type(MR[i]) ~= "number" or MR[i] > 2.0 or (i > 1 and MR[i] < MR[i - 1]) then Err("BotMove", "Rifts.MAP_REWARD[" .. i .. "] must be a number <= 2.0 and not below the step before") end
                end
            end
            -- a role bot's own top speed must be readable at a typical fight distance (30 studs) on the Standard step
            for id, row in pairs(BR.ROWS or {}) do
                local A = arches[id]
                local P = A and (BM.ROLE or {})[row.Role]
                if P and BM.Wants(id, A, row) then
                    local top = P.Speed * ((BM.FAST or {})[id] and BM.FAST[id].Speed or 1)
                    if math.deg(top / 30) > BM.CAP_DEG then Warn("BotMove", string.format("%s moves %.0f deg/s at 30 studs on Standard: over the cap, it will always be held back", id, math.deg(top / 30))) end
                end
            end
        end
        for _, v in ipairs(DG.ELITE_SHELL or {}) do
            local t = BR.SHELL_TYPE and BR.SHELL_TYPE[v]
            if not t then Err("EliteMods", v .. " is a Shelled variant with no BotRoles.SHELL_TYPE") elseif DT and DT.COLOR and not DT.COLOR[t] then Err("EliteMods", v .. ": type " .. t .. " has no DamageTypes.COLOR") end
        end
        if DT and DT.ORDER then
            for _, t in ipairs(DT.ORDER) do
                local found = false
                for _, tt in pairs(BR.SHELL_TYPE or {}) do if tt == t then found = true end end
                if not found then Warn("EliteMods", "damage type " .. t .. " has no Shelled variant (append ELITE_SHELL + SHELL_TYPE)") end
            end
        end
    end

    -- ==================== CURRENCIES ====================
    local MD = ID.MaterialDefs or {}
    for mode, key in pairs(ID.CRAFT_V5_KEY or {}) do
        if not MD[key] then Err("Currency", string.format("craft %s uses %s, which has no MaterialDefs row", mode, tostring(key))) end
    end
    for _, list in ipairs({ { "CURRENCY_V5", ID.CURRENCY_V5 }, { "LOOT_MATS", ID.LOOT_MATS }, { "MaterialOrder", ID.MaterialOrder } }) do
        for _, k in ipairs(list[2] or {}) do
            if not MD[k] then Err("Currency", string.format("%s names %s, which has no MaterialDefs row", list[1], tostring(k))) end
        end
    end
    for k, d in pairs(MD) do
        if type(d) == "table" and type(d.Name) ~= "string" then Err("Currency", k .. " needs a Name") end
    end

    -- ==================== SHOT MODS ====================
    if SM then
        for _, id in ipairs(SM.ORDER or {}) do if not (SM.DEFS and SM.DEFS[id]) then Err("ShotMods", id .. " is in ORDER with no DEFS row") end end
        for id in pairs(SM.DEFS or {}) do if not table.find(SM.ORDER or {}, id) then Warn("ShotMods", id .. " has a DEFS row but is not in ORDER (it never drops)") end end
        -- (LOOT SCARCITY 2026-11-07) the MOD SUPPLY vendor's stock: known mods, sold once, levels never go down, costs in known currencies
        if SM.SupplyCheck then for _, e in ipairs(SM.SupplyCheck()) do Err("ShotMods", e) end end
    end

    -- ==================== RELICS ====================
    for id, e in pairs(ID.Exotics or {}) do
        if type(e) == "table" then
            if e.MinDiff ~= nil and not table.find(order, e.MinDiff) then Err("Relics", string.format("%s MinDiff '%s' is not a difficulty (it would drop everywhere)", id, tostring(e.MinDiff))) end
            if e.Needs ~= nil and (ID.RELIC_HOOKS or {})[e.Needs] == nil then Err("Relics", string.format("%s Needs '%s', which is not a RELIC_HOOKS flag", id, tostring(e.Needs))) end
            for _, l in ipairs(type(e.Lines) == "table" and e.Lines or {}) do Stat("Relics", l.Stat, "relic " .. id) end
            for _, l in ipairs(type(e.Fixed) == "table" and e.Fixed or {}) do Stat("Relics", l.Stat or l[1], "relic " .. id) end
        end
    end

    -- ==================== ZENITH (CHASE ITEMS 2026-11-06) ====================
    do
        local seen = {}
        for _, id in ipairs(ID.ZENITH_ORDER or {}) do
            local e = ID.Exotics and ID.Exotics[id]
            seen[id] = true
            if not (type(e) == "table" and e.Zenith) then Err("Zenith", id .. " is in ZENITH_ORDER with no Zenith def in ItemData.Exotics")
            else
                for _, k in ipairs({ "Name", "Desc", "Catch", "Kind" }) do if type(e[k]) ~= "string" then Err("Zenith", id .. " needs " .. k) end end
                if e.Kind == "Weapon" and not (ID.BaseWeapons and ID.BaseWeapons[e.Base or ""]) then Err("Zenith", id .. " Base '" .. tostring(e.Base) .. "' is not a gun") end
                if e.Kind == "Gear" and not e.Slot then Err("Zenith", id .. " needs a Slot") end
                if not (ID.ZENITH_TUNE and ID.ZENITH_TUNE[id]) then Err("Zenith", id .. " has no ZENITH_TUNE row (its mechanic reads it)") end
                if not e.Global and not e.Pinnacle then Warn("Zenith", id .. " is in neither ZENITH_GLOBAL nor ZENITH_PINNACLE (it never drops)") end
            end
        end
        for id, e in pairs(ID.Exotics or {}) do
            if type(e) == "table" and e.Zenith and not seen[id] then Err("Zenith", id .. " is a Zenith def missing from ZENITH_ORDER") end
        end
        for _, list in ipairs({ { "ZENITH_GLOBAL", ID.ZENITH_GLOBAL }, { "ZENITH_PINNACLE", ID.ZENITH_PINNACLE } }) do
            for _, id in ipairs(list[2] or {}) do if not seen[id] then Err("Zenith", list[1] .. " names " .. tostring(id) .. ", not in ZENITH_ORDER") end end
        end
        for _, k in ipairs(ID.ZENITH_MATS or {}) do if not (ID.MaterialDefs or {})[k] then Err("Zenith", "ZENITH_MATS names " .. k .. " with no MaterialDefs row") end end
        if ID.ZENITH_LIVE ~= true and ID.ZENITH_LIVE ~= false then Err("Zenith", "ZENITH_LIVE must be true or false") end
    end

    -- ==================== BOSSES + TRIALS ====================
    if BT then
        local prev = 0
        for i, t in ipairs(BT.Tiers or {}) do
            local r = ID.DifficultyRank and ID.DifficultyRank[t.Difficulty]
            if not r then Err("BossTrials", string.format("tier %d names '%s', not a difficulty", i, tostring(t.Difficulty))) end
            if r and r < prev then Err("BossTrials", string.format("tier %d is easier than the tier before it (tiers are saved by position: append only)", i)) end
            prev = r or prev
        end
        local kits = BAI and (BAI.Kits or BAI.KITS) -- (MAPS V2: BossAI exports Kits; the check read KITS and never ran)
        local allBosses = table.clone(BT.Bosses or {})
        for _, b in ipairs(BT.MapBosses or {}) do table.insert(allBosses, b) end
        for _, b in ipairs(allBosses) do
            if DG and DG.TRIAL_BODIES and not DG.TRIAL_BODIES[b.Id] then Warn("Bosses", b.Id .. " has no DungeonGenerator.TRIAL_BODIES entry (it borrows another body)") end
            if kits and not kits[b.Id] then Warn("Bosses", b.Id .. " has no BossAI kit") end
        end
        if RF then
            for _, g in ipairs(RF.GUARDIAN_POOL or {}) do
                if not (BT.ById and BT.ById[g]) then Err("Maps", "Rifts.GUARDIAN_POOL names " .. g .. ", which is not a BossTrials boss") end
            end
            -- (MAPS V2) every map band has a guardian pool, and every name in it is a boss
            for _, band in ipairs(RF.LADDER or {}) do
                local pool = RF.BAND_GUARDIANS and RF.BAND_GUARDIANS[band]
                if RF.BAND_GUARDIANS and not pool then Warn("Maps", "Rifts.BAND_GUARDIANS has no row for " .. band .. " (it takes the top band's pool)") end
                for _, g in ipairs(pool or {}) do
                    if not (BT.ById and BT.ById[g]) then Err("Maps", "Rifts.BAND_GUARDIANS." .. band .. " names " .. g .. ", which is not a BossTrials boss") end
                end
            end
        end
    end
    if AT and AD and AD.MAX_POINTS and AD.POINTS_PER_TIER and #(AT.Tiers or {}) * AD.POINTS_PER_TIER ~= AD.MAX_POINTS then
        Warn("Specs", string.format("AscendancyData.MAX_POINTS %d ~= %d Proving tiers x %d: a new tier gives no points", AD.MAX_POINTS, #(AT.Tiers or {}), AD.POINTS_PER_TIER))
    end

    -- ==================== ENCOUNTERS ====================
    if ENC then
        for _, id in ipairs(ENC.Order or {}) do if not (ENC.Defs and ENC.Defs[id]) then Err("Encounters", id .. " is in Order with no Defs row") end end
        for id in pairs(ENC.Defs or {}) do if not table.find(ENC.Order or {}, id) then Warn("Encounters", id .. " has a Defs row but is not in Order (it never rolls)") end end
    end

    -- ==================== BIOMES / MAP TYPES ====================
    local biomes = table.clone(DG and DG.BIOMES or {})
    for _, id in ipairs(WB and WB.LIST or {}) do if not table.find(biomes, id) then table.insert(biomes, id) end end
    local RA = Shared:FindFirstChild("RoomAtmo")
    local MS = DG and DG.MapShell
    for _, b in ipairs(biomes) do
        if MS and MS.TEMPLATES and not MS.TEMPLATES[b] then Err("Biomes", b .. " has no MapShell.TEMPLATES (it builds as Molten)") end
        if RA and not RA:FindFirstChild(b) then Warn("Biomes", b .. " has no RoomAtmo/" .. b .. " child (its rooms get only pass 1 atmosphere)") end
        if MS and MS.PROPS and not MS.PROPS[b] and not (MS.PROP_FAMILY and MS.PROP_FAMILY[b]) then Warn("Biomes", b .. " has no MapShell.PROPS row or PROP_FAMILY") end
        if MS and MS.LAYOUT and not MS.LAYOUT[b] and not (MS.PROP_FAMILY and MS.LAYOUT[MS.PROP_FAMILY[b] or ""]) then Warn("Biomes", b .. " has no prop LAYOUT style (Organic)") end
    end

    -- ==================== UNLOCK CARDS (a 32-bit seen mask) ====================
    local okT, TU = pcall(function() return require(Shared:WaitForChild("Tutorial", 5)) end)
    if okT and type(TU) == "table" and TU.UNLOCKS and #TU.UNLOCKS > 31 then
        Err("Tutorial", string.format("%d unlock cards: the seen mask holds 31 -- card 32+ would show every session", #TU.UNLOCKS))
    end
    return out
end

-- a printable summary (errors first)
function ContentCheck.Report(list: { any }?): string
    list = list or ContentCheck.Run()
    local e, w = 0, 0
    local lines = {}
    for _, lv in ipairs({ "ERROR", "WARN" }) do
        for _, f in ipairs(list) do
            if f.Level == lv then
                if lv == "ERROR" then e += 1 else w += 1 end
                table.insert(lines, string.format("  %s [%s] %s", f.Level, f.Area, f.Msg))
            end
        end
    end
    return string.format("[ContentCheck] %d error(s), %d warning(s)", e, w) .. ((#lines > 0) and ("\n" .. table.concat(lines, "\n")) or "")
end

return ContentCheck
