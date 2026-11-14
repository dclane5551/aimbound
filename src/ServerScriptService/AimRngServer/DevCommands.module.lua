--!nocheck
-- Test / admin commands. The Studio tooling hooks are only made in Studio; live servers reach Run only through the
-- ADMIN MENU (AdminService checks the caller is an admin first).
-- Exposed as ServerStorage.AimRngDev (BindableFunction) so play-test tooling can poke the REAL player
-- state: a script run from the command bar gets its own copy of every module, so requiring
-- CombatServer there and editing GetState() changes nothing the game actually uses.
--
--   Invoke("state")                          -> summary string
--   Invoke("sp", n) / ("gold", n)            -> add skill points / gold
--   Invoke("level", n)                        -> grant n levels (+1 skill point, +3 stat points each; no gold/shards)
--   Invoke("floor", n, biome?, difficulty?)  -> jump straight into dungeon floor n (boss floors: ItemData
--                                               DifficultyModes MiniBossWaves / BossWaves / SuperBossWave, e.g. Hard 6 = superboss); the client builds it
--   Invoke("rejoin")                          -> save, wipe the live state, load it back (save/load round trip)
--   Invoke("mats", n)                         -> +n of every material / crafting currency
--   Invoke("heal")                            -> full health
--   Invoke("nodeath", on)                     -> health stops at 1 instead of dying (damage/ailments still apply)
--   Invoke("linkedrooms", on | "spawnall" | "wakeall" | "goto", room | "state") -> LINKED ROOMS pilot switch + test hooks
--   Invoke("packsoff", off)                   -> UPDATE 8: packs OFF on this player's next solo floors (PacksPilot; packs are normal)
--   Invoke("weapon", procId?, rarity?, baseId?) -> add + equip a weapon with that prefix
--                                               (procId: Burn/Freeze/Bleed/Decay/Giantslayer/Fixation/Explosive or "none")
-- In a play-test, F8 (AimRngClient) fires ReplicatedStorage.AimRngDevRemote: equips the test Glock and
-- cycles its prefix each press (no command bar needed).
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ItemData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ItemData"))
local Remotes = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Remotes"))

local DevCommands = {}

function DevCommands.Init(CombatServer: any)
    -- (0.65: the ADMIN MENU runs these too, on any player in the server -- DevCommands.Run(player, cmd, ...). The Studio
    -- tooling hooks below -- AimRngDev, the F8 remote, the DevCmd mailbox -- are still only made in Studio.)
    local IsStudio = game:GetService("RunService"):IsStudio()
    local fn = Instance.new("BindableFunction")
    fn.Name = "AimRngDev"
    if IsStudio then fn.Parent = ServerStorage end

    local function Sync(player: Player, state: any)
        CombatServer.RecalculateMaxHealth(state)
        Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    end

    local Run
    Run = function(player: Player, cmd: string, a: any, b: any, c: any, d: any, e: any, f: any, g: any, h: any, i: any): string
        local state = CombatServer.GetState(player)
        if not state then return "no save loaded for " .. player.Name end

        if cmd == "sp" then
            state.SkillPoints += (a or 10)
        elseif cmd == "gold" then
            state.Gold += (a or 1000)
        elseif cmd == "colorway" then -- (0.93) ["colorway", "Tempest", 2, ref?] = own + wear a colourway (whole set, or one piece)
            local kind, v = tostring(a), tonumber(b) or 2
            state.Colorways = type(state.Colorways) == "table" and state.Colorways or {}
            local rec = state.Colorways[kind] or { Own = {}, Items = {} }
            rec.Own = rec.Own or {}
            rec.Items = rec.Items or {}
            rec.Own[tostring(v)] = true
            if type(c) == "string" then rec.Items[c] = v else rec.Set, rec.Items = v, {} end
            state.Colorways[kind] = rec
            CombatServer.SyncBarStyle(player, state)
        elseif cmd == "bp" then -- (0.93) ["bp", n] = BOUND points (negative takes them)
            state.BoundPoints = math.max(0, (tonumber(state.BoundPoints) or 0) + (tonumber(a) or 100))
            player:SetAttribute("BoundPoints", state.BoundPoints)
        elseif cmd == "class" then
            -- ["class", "Marksman"] = become that class (free, refunds the tree) / ["class"] = no class (shows the picker)
            local ClassData = require(game.ReplicatedStorage.AimRngShared.ClassData)
            local c = type(a) == "string" and ClassData.ById[a]
            local spent = 0
            local SkillTreeData = require(game.ReplicatedStorage.AimRngShared.SkillTreeData)
            for _, id in ipairs(state.AllocatedNodes or {}) do if SkillTreeData[id] and SkillTreeData[id].Type ~= "ClassStart" then spent += 1 end end
            state.SkillPoints += spent
            state.Class = c and c.Id or nil
            state.AllocatedNodes = c and { c.Start } or {}
            state.Ascendancy, state.AscNodes = nil, {}
            Sync(player, state)
            return "class " .. tostring(state.Class) .. ", " .. state.SkillPoints .. " points"
        elseif cmd == "trialbest" then
            -- ["trialbest", tier] = pretend the Archon trial was cleared up to that tier (ascendancy points = 2 x tier)
            local BossTrials = require(game.ReplicatedStorage.AimRngShared.BossTrials)
            local tier = math.clamp(tonumber(a) or 1, 0, BossTrials.MAX_TIER)
            state.BossTrials = type(state.BossTrials) == "table" and state.BossTrials or {}
            local prog = BossTrials.Progress(state, "Archon")
            prog.Best = tier
            state.BossTrials.Archon = prog
            Sync(player, state)
            return "Archon best tier " .. tier .. " -> " .. require(game.ReplicatedStorage.AimRngShared.AscendancyData).PointsFor(state) .. " specialization points"
        elseif cmd == "asc" then
            -- ["asc", ascId, "A1,a2,A2"] = set your ascendancy + its nodes by slot (no checks; for testing Fx) / ["asc"] = none
            local AD = require(game.ReplicatedStorage.AimRngShared.AscendancyData)
            local def = type(a) == "string" and AD.ById[a]
            if not def then
                state.Ascendancy, state.AscNodes = nil, {}
                Sync(player, state)
                return "no specialization"
            end
            state.Class = def.Class
            state.Ascendancy, state.AscNodes, state.AscBuffs = def.Id, { def.Start }, nil
            for slot in string.gmatch(type(b) == "string" and b or "", "[^,]+") do
                local id = "ASC_" .. string.upper(def.Id) .. "_" .. slot
                if AD.Nodes[id] then table.insert(state.AscNodes, id) end
            end
            Sync(player, state)
            return "specialization " .. def.Id .. ": " .. table.concat(state.AscNodes, ",")
        elseif cmd == "sig" then
            -- (CLASS BUILDS) SIGNATURE probe: ["sig"] = your specialization's signature rule + its live state (mark, Ghost,
            -- Shock count, Overcap regen, Ward, magazine); ["sig", "near"] adds the 6 nearest enemies (health, Wither stacks,
            -- ailments, Frozen / Shocked, Suppressor stacks, damage-taken multiplier)
            local StatCalculator = require(game.ReplicatedStorage.AimRngShared.StatCalculator)
            local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
            if a == "cluster" then return CombatServer.CB.Sig.TestCluster(player, state, stats, b) end -- (["sig", "cluster", "Burn,Wither"])
            return CombatServer.CB.Sig.Debug(player, state, stats, a == "near")
        elseif cmd == "family" then
            -- (CLASS BUILDS) FAMILY probe: ["family"] = the equipped gun's family line + its live counters (DMR chain, LMG ramp,
            -- SMG 10th hit, sidearm dodge, pump pellets, magazine, evade on the move, the shot mods as the family uses them);
            -- ["family", "near"] adds the 6 nearest enemies (your hits on each, health, ailments); ["family", "reset"]
            local StatCalculator = require(game.ReplicatedStorage.AimRngShared.StatCalculator)
            local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
            return CombatServer.CB.Family.Debug(player, state, stats, a)
        elseif cmd == "ascprobe" then
            -- ["ascprobe", ctxJson] = your ascendancy effects against a hit context, e.g. {"Weak":true,"Marked":true,"Crit":true}
            -- -> pre-crit MORE multiplier, crit chance added, forced crit, crit-only multiplier, guard multiplier, buffs
            local StatCalculator = require(game.ReplicatedStorage.AimRngShared.StatCalculator)
            local Asc = CombatServer.Asc
            local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
            local ok, c = pcall(function() return game:GetService("HttpService"):JSONDecode(type(a) == "string" and a or "{}") end)
            c = ok and c or {}
            local kinds = {}
            for _, e in ipairs(stats.AscFx or {}) do table.insert(kinds, e.Fx.Kind .. "(" .. tostring(e.Fx.When or e.Fx.Trigger or e.Fx.N or "") .. ")") end
            local st = {}
            local pre, crit, force = Asc.PreHit(st, stats, c, true)
            local cm = Asc.CritMult(stats, c)
            local guard = Asc.GuardMult(player, state, stats, c.Moving == true, nil)
            local buffs = {}
            for k, b in pairs(type(state.AscBuffs) == "table" and state.AscBuffs or {}) do table.insert(buffs, string.format("%s x%d %.1fs", k, b.N or 0, (b.U or 0) - workspace:GetServerTimeNow())) end
            return string.format("fx=[%s] pre=%.3f critAdd=%.2f force=%s critMult=%.3f guard=%.3f crit=%.3f focusMax=%d buffs=[%s]",
                table.concat(kinds, ","), pre, crit, tostring(force), cm, guard, stats.CritChance, stats.MaxFocusStacks or 0, table.concat(buffs, ";"))
        elseif cmd == "treesim" then
            -- TREE BALANCE PROBE (2026-10-05, passive tree v4): ["treesim", startNode, "KEYSTONE,..", level, points, gun, w]
            -- builds a tree from startNode: buys the paths to the listed keystones (SpecialMechanic or node id), then
            -- spends what's left greedily on the nearby node (<= 3 steps) with the best power gain per point.
            -- Power = dps^(1-w) x ehp^w (w default 0.3). Fixed test gun (no affixes / proc / trait) and an even
            -- attribute spread, so trees can be compared. -> "dps / ehp / nodes / keystones"
            local SkillTreeData = require(game.ReplicatedStorage.AimRngShared.SkillTreeData)
            local StatCalculator = require(game.ReplicatedStorage.AimRngShared.StatCalculator)
            local start = (type(a) == "string" and SkillTreeData[a]) and a or "CLASS_VAN"
            -- (weapon classes: the start's class, so its passives + ascendancy count with its guns)
            local simCls = require(game.ReplicatedStorage.AimRngShared.ClassData).ByStart[start]
            local simClass = simCls and simCls.Id or nil
            local lvl = math.clamp(tonumber(c) or 100, 1, ItemData.MAX_LEVEL)
            local budget = tonumber(d) or 123
            local w = tonumber(f) or 0.3
            -- gun "AK47+GEAR": a level-typical weapon WITH its affixes + a full gear set (Rare < 30, Epic < 80, Legendary after;
            -- seeded by level, so reruns match) -- the THREE LAYERS measurement enemies are anchored to (DevCmd powercurve)
            local gunId = type(e) == "string" and (string.match(e, "^([%w_]+)") or "AK47") or "AK47"
            local withGear = type(e) == "string" and string.find(e, "+GEAR", 1, true) ~= nil
            local gearSet = nil
            local gun
            if withGear then
                math.randomseed(lvl * 7919)
                -- (0.51 RARITY LADDER: the commonest rarity of the tier a player of this level farms -- the 40% step of its window;
                -- 0.99n RARITY LADDER v3: the rarity players realistically wear, ItemData.TypicalGearRank. Studio: workspace attr
                -- DevGearModel = "old" measures the 0.51 model, to re-anchor enemies by the ratio)
                local oldModel = workspace:GetAttribute("DevGearModel") == "old"
                local rar = ItemData.Rarities[oldModel and math.max(1, ItemData.MaxRarityForLevel(lvl) - 3) or ItemData.TypicalGearRank(lvl)]
                gun = ItemData.GenerateWeaponOfBase(gunId, rar, lvl)
                gun.Proc, gun.UniqueTrait = nil, nil
                gearSet = {}
                for _, slot in ipairs(ItemData.GEAR_EQUIP_SLOTS) do -- (UPDATE 8: + Gloves)
                    gearSet[slot] = ItemData.GenerateRandomGear(ItemData.GearType(slot), rar, 1, lvl, true)
                end
                math.randomseed(os.clock() * 1000)
            else
                gun = ItemData.GenerateWeaponOfBase(gunId, "Common", lvl)
                gun.Prefixes, gun.Suffixes, gun.Proc, gun.UniqueTrait = {}, {}, nil, nil
            end
            local each = 5 + math.floor(ItemData.AttrPointsAt(lvl) / 4) -- (ATTRIBUTES v2: an even spread of the points you have)
            local attrs = { Strength = each, Dexterity = each, Vitality = each, Luck = each }
            local alloc, set = { start }, { [start] = true }
            -- EFFECTIVE power (tree v4 balance): plain StatCalculator DPS / EHP plus an APPROXIMATE value for the
            -- conditional stats and on-hit ailments the combat code applies (each weighted by a rough uptime), so ailment
            -- and condition builds (Hexslinger, Reaper) aren't scored as zero. Same heuristic for every class.
            local UPTIME = { FirstHitDamage = 0.15, LowHealthEnemyDamage = 0.3, MovingDamage = 0.6, StillDamage = 0.3,
                LastMagDamage = 0.3, EliteDamage = 0.35, SwitchDamage = 0.3, PierceDamage = 0.25, OverkillCarry = 0.25,
                ChainKillDamage = 3, ExecutePct = 2 }
            local function Power(list)
                local fake = { Level = lvl, Attributes = attrs, StatsTracking = {}, Paragon = {}, Class = simClass }
                -- (an average Focus streak of 10, longer with Focus Retain)
                local s0 = StatCalculator.Calculate(gun, list, 0, lvl, attrs, gearSet, nil, nil, nil, fake)
                local streak = math.floor(10 * (1 + ((s0.Cond or {}).FocusRetain or 0)))
                local s = StatCalculator.Calculate(gun, list, streak, lvl, attrs, gearSet, nil, nil, nil, fake)
                local c = s.Cond or {}
                local crit = math.min(1, s.CritChance + (c.WeakSpotCritChance or 0) * 0.35)
                local dps = s.Damage * s.FireRate * math.max(1, s.PelletCount or 1) * math.max(1, s.BurstCount or 1) * (1 + crit * (s.CritMultiplier - 1))
                dps *= 1 + 0.35 * math.max(0, (s.WeakSpotMultiplier or 2) - 1) -- (35% of hits on weak spots)
                -- sustained: the magazine, then the reload
                local magTime = (s.MagazineSize or 10) / math.max(0.2, s.FireRate)
                local reload = (gun.ReloadTime or 1.5) / math.max(0.4, s.ReloadSpeed or 1)
                dps *= magTime / (magTime + reload)
                local condMult = 1 + (c.PierceCount or 0) * 0.1
                for k, up in pairs(UPTIME) do condMult += (c[k] or 0) * up end
                -- (CombatServer TREE_PROCS: on-hit chances x (1 + Proc Chance), x2 with Hex Rounds, capped at 75%)
                local procMult = (1 + (s.AilmentChance or 0)) * ((s.SpecialMechanics or {}).HEX_ROUNDS and 2 or 1)
                for _, k in ipairs({ "BurnOnHit", "ChillOnHit", "BleedOnHit", "DecayOnHit" }) do c[k] = math.min(0.75, (c[k] or 0) * procMult) end
                local ailChance = math.min(1, (c.BurnOnHit or 0) + (c.BleedOnHit or 0) + (c.DecayOnHit or 0) + (c.ChillOnHit or 0))
                condMult += (c.AilmentedDamage or 0) * math.min(1, ailChance * 2)
                local dur = 1 + (s.AilmentDuration or 0)
                local ail = (c.BurnOnHit or 0) * 0.4 * (1 + (s.BurnDamage or 0)) * dur + math.min(1, (c.BleedOnHit or 0)) * 0.4 * (1 + (s.BleedDamage or 0)) * dur * (1 + (c.BleedStacks or 0) * 0.3)
                    + (c.DecayOnHit or 0) * 0.15 * (1 + (s.DecayEffect or 0)) * dur
                local eff = dps * (condMult + ail)
                local ehp = s.MaxHP / math.max(0.05, 1 - (s.DamageReduction or 0))
                ehp *= (1 + (c.StillDR or 0) * 0.3) * (1 + (c.LowLifeDR or 0) * 0.3) * (1 + (c.KillHeal or 0) * 5) * (1 + (c.ChillOnHit or 0) * 0.3 * (1 + (s.FreezeEffect or 0)))
                ehp *= (1 + (s.LifeLeechPct or 0) * 10) * (1 + math.min(0.6, (s.FireResist + s.ColdResist + s.ChaosResist) / 3) * 0.5)
                ehp *= (1 + math.max(0, (s.MovementSpeedMult or 1) - 1) * 1.5) * (1 + (s.HPRegen or 0) / math.max(1, s.MaxHP) * 8)
                return eff ^ (1 - w) * ehp ^ w, eff, ehp
            end
            -- shortest path (unallocated nodes) from the allocated set to target
            local function PathTo(target)
                local prev, queue, head = { [target] = target }, { target }, 1
                while head <= #queue do
                    local cur = queue[head]; head += 1
                    for _, nb in ipairs(SkillTreeData[cur].Connections or {}) do
                        if SkillTreeData[nb] and prev[nb] == nil then
                            prev[nb] = cur
                            if set[nb] then
                                local path, x = {}, cur
                                while true do table.insert(path, x); if x == target then break end; x = prev[x] end
                                return path
                            end
                            if SkillTreeData[nb].Type ~= "ClassStart" or nb == start then table.insert(queue, nb) end -- (never through another class's start)
                        end
                    end
                end
                return nil
            end
            local function Take(path)
                for _, id in ipairs(path) do if not set[id] then set[id] = true; table.insert(alloc, id) end end
            end
            local function Spent() return #alloc - 1 end
            local reached = {}
            for key in string.gmatch(type(b) == "string" and b or "", "[^,]+") do
                local target
                if SkillTreeData[key] then target = key else
                    for id, n in pairs(SkillTreeData) do if n.SpecialMechanic == key then target = id break end end
                end
                local path = target and not set[target] and PathTo(target)
                if path and Spent() + #path <= budget then Take(path); table.insert(reached, SkillTreeData[target].Name) end
            end
            local base = Power(alloc)
            local guard = 0
            local stuck = false
            while Spent() < budget and guard < 2000 do -- (2026-10-21: was 400 rounds -- at L325+ the greedy stopped with 100-200 of its 650-800 points unspent)
                guard += 1
                -- candidates: unallocated nodes within 3 steps of the tree (never another class's start / an ascendancy)
                local dist, frontier = {}, {}
                for id in pairs(set) do dist[id] = 0; table.insert(frontier, id) end
                local cands = {}
                for depth = 1, (stuck and 7 or 3) do
                    local nextF = {}
                    for _, cur in ipairs(frontier) do
                        for _, nb in ipairs(SkillTreeData[cur].Connections or {}) do
                            local n = SkillTreeData[nb]
                            if n and dist[nb] == nil and n.Type ~= "ClassStart" and n.Type ~= "Origin" and not n.Ascendancy then
                                dist[nb] = depth; table.insert(nextF, nb); table.insert(cands, nb)
                            end
                        end
                    end
                    frontier = nextF
                end
                local best, bestRatio, bestPath = nil, 0, nil
                for _, id in ipairs(cands) do
                    local path = PathTo(id)
                    if path and Spent() + #path <= budget then
                        local list = table.clone(alloc)
                        for _, x in ipairs(path) do table.insert(list, x) end
                        local pw = Power(list)
                        local ratio = (pw - base) / #path
                        if ratio > bestRatio then best, bestRatio, bestPath = id, ratio, path end
                    end
                end
                if not best then
                    if stuck then break end
                    stuck = true -- (nothing within 3 steps helps: look further once before giving up)
                    continue
                end
                stuck = false
                Take(bestPath)
                base = Power(alloc)
                if guard % 10 == 0 then task.wait() end
            end
            if g == "APPLY" or g == "APPLYMODS" then
                -- (0.99n balance test) put this built character on YOU: class, tree, attributes, the level-typical gun + gear
                -- (ItemData.TypicalGearRank, or the 0.51 model with workspace DevGearModel "old"). Your old state is not kept.
                state.Class = simClass
                state.Level = lvl -- (the sim's level: DevCmd "level" ADDS levels, so a second APPLY used to keep the old one)
                state.MaxXP = CombatServer.XpToNext(lvl)
                state.XP = 0
                state.AllocatedNodes = alloc
                state.EquippedPassives = nil
                state.Attributes = attrs
                local modTxt = ""
                if withGear and g == "APPLYMODS" then -- (BALANCE PASS 2026-10-23) + the typical 3-4 link of your level (ShotMods.Typical)
                    local SMod = require(game.ReplicatedStorage.AimRngShared.ShotMods)
                    modTxt = ", mods " .. table.concat(SMod.Typical(gun, lvl, nil, tonumber(h) or 1, type(i) == "string" and string.split(i, ",") or nil), "+")
                end
                if withGear then
                    state.EquippedWeapon = gun
                    table.insert(state.Inventory, gun)
                    state.EquippedGear = gearSet
                end
                if CombatServer.RecalculateMaxHealth then CombatServer.RecalculateMaxHealth(state) end
                state.Health = state.MaxHealth
                Sync(player, state)
                return string.format("applied: %s %s, %d nodes, gun %s %s", tostring(simClass), tostring(gun.Rarity), Spent(), gun.BaseId, gun.Name) .. modTxt
            end
            if g == "STATS" then
                -- the built character's final numbers (POWER SCALING checks): increased damage, fire rate, crit, weak spot, HP, luck
                local fake = { Level = lvl, Attributes = attrs, StatsTracking = {}, Paragon = {}, Class = simClass }
                local st = StatCalculator.Calculate(gun, alloc, 0, lvl, attrs, gearSet, nil, nil, nil, fake)
                return string.format("inc dmg +%d%% | fire %.1f/s (base %.1f) | crit %d%% x%.2f | weak %.2fx | HP %s | luck x%.2f | DR %d%%",
                    math.round(st.DamageBonusPct * 100), st.FireRate, gun.BaseFireRate, math.round(st.CritChance * 100), st.CritMultiplier,
                    st.WeakSpotMultiplier, ItemData.FormatNumber(st.MaxHP), st.LuckMultiplier, math.round((st.DamageReduction or 0) * 100))
            end
            if type(g) == "string" and g ~= "" then
                -- UNITPROBE: g = JSON {stat = value of ONE unit}: the power gained by one unit of each stat on top of this
                -- build, as a ratio of IncreasedDamage's gain (tools/gen_tree_v4.py calibrates UNIT from it)
                local Http = game:GetService("HttpService")
                local units = Http:JSONDecode(g)
                local p0 = Power(alloc)
                local gains = {}
                for stat, val in pairs(units) do
                    SkillTreeData._PROBE = { Name = "probe", Type = "Minor", Position = Vector2.zero, Stats = { [stat] = val }, Connections = {} }
                    local list = table.clone(alloc); table.insert(list, "_PROBE")
                    gains[stat] = Power(list) / p0 - 1
                end
                SkillTreeData._PROBE = nil
                local ref = gains.IncreasedDamage or 1e-9
                local outp = {}
                for stat, gn in pairs(gains) do outp[stat] = math.round(gn / ref * 1000) / 1000 end
                return Http:JSONEncode(outp)
            end
            local _, dps, ehp = Power(alloc)
            local ks = {}
            for _, id in ipairs(alloc) do if SkillTreeData[id].Type == "Keystone" then table.insert(ks, SkillTreeData[id].Name) end end
            return string.format("dps %.1f / ehp %.0f / %d nodes / cornerstones: %s", dps, ehp, Spent(), table.concat(ks, ", "))
        elseif cmd == "lostloot" then
            -- a fake piece of lost run loot (tests the LOST GEAR tile / buy-back window): ["lostloot", "Epic"]
            local w = ItemData.GenerateWeaponOfBase and ItemData.GenerateWeaponOfBase("AK47", type(a) == "string" and a or "Epic", state.Level)
            if w then
                state.LostLoot = state.LostLoot or {}
                table.insert(state.LostLoot, { Item = w, Kind = "Weapon" })
            end
        elseif cmd == "unlockto" then -- (2026-10-22 autoplay pace runs) ["unlockto", diff]: every tier below diff counts as fully cleared
            state.StatsTracking = state.StatsTracking or {}
            state.StatsTracking.FloorsByDifficulty = state.StatsTracking.FloorsByDifficulty or {}
            for _, d0 in ipairs(ItemData.DifficultyOrder) do
                if d0 == a then break end
                local m = ItemData.DifficultyModes[d0]
                state.StatsTracking.FloorsByDifficulty[d0] = math.max(state.StatsTracking.FloorsByDifficulty[d0] or 0, m and m.MaxWaves or 6)
            end
            return "cleared every tier below " .. tostring(a)
        elseif cmd == "setlevel" then -- (pace probes: put the level back to n, XP 0; points are not refunded)
            state.Level = math.clamp(math.floor(tonumber(a) or 1), 1, ItemData.MAX_LEVEL)
            state.MaxXP = CombatServer.XpToNext(state.Level)
            state.XP = 0
        elseif cmd == "level" then
            for _ = 1, (a or 1) do
                if state.Level >= ItemData.MAX_LEVEL then break end
                state.Level += 1
                state.SkillPoints += ItemData.TreePointsForLevelUp(state.Level)
                state.StatPoints += ItemData.AttrPointsForLevelUp(state.Level)
                state.MaxXP = CombatServer.XpToNext(state.Level)
            end
            state.XP = 0
        elseif cmd == "floor" then
            local DungeonRuns = require(script.Parent:WaitForChild("DungeonRuns"))
            local forced = nil
            if type(d) == "string" then
                forced = require(game.ReplicatedStorage.AimRngShared.FloorMods).Parse(d) -- Invoke("floor", n, biome, diff, "FRENZIED,TREASURE")
            end
            -- (a party run in progress would keep RunId set -> the lives UI acts as party; leave it first)
            local PR = require(script.Parent:WaitForChild("PartyRuns"))
            if PR.RunOfPlayer(player) then PR.RemoveMember(player) end
            local endless = false
            if type(c) == "string" then c, endless = ItemData.ParseRunKey(c) end -- ("Endless:Hard" = an Endless run on Hard)
            DungeonRuns.StartFloor(player, {
                Biome = b or "Fire", Difficulty = c or "Easy", FloorNumber = a or 5, Endless = endless == true or nil, PlayerLevel = state.Level, ForceMods = forced, ForceEvent = (type(e) == "string" and string.sub(e, 1, 4) ~= "OBJ:" and e ~= "MINI") and e or nil, -- e: DungeonEvents id
                BossArena = (e == "MINI") or nil, -- (UPDATE 8 Phase 5: e = "MINI" forces a mini-boss floor -- with its pack wave)
                BotSkill = f, -- f: bot-skill step 1-10 (nil = default)
                FixedBiome = b ~= nil, -- (a biome named = test that biome; nil = a mixed roll like a real run)
                ForceObjective = (type(e) == "string" and string.sub(e, 1, 4) == "OBJ:") and string.sub(e, 5) or nil, -- e = "OBJ:BOUNTY"
            })
            state.DungeonDifficulty = c or "Easy"
            Remotes.GetEvent("DungeonUpdate"):FireClient(player, {
                Biome = DungeonRuns.Attr(player, "Biome") or "Fire", Difficulty = c or "Easy", Floor = a or 5, Remaining = DungeonRuns.Attr(player, "RemainingEnemies") or 0,
            })
            return "started floor " .. tostring(a or 5)
        elseif cmd == "savecheck" then
            -- (launch sweep 2026-10-13) Invoke("savecheck"): Serialize the live state and list every value the save would
            -- DROP (SaveService Clean keeps string keys or a 1..n array only: a gap / number key / mixed table loses data)
            local data = require(script.Parent:WaitForChild("SaveService")).Serialize(state)
            local lost = {}
            local function Walk(a, b, path)
                if #lost >= 25 or type(a) ~= "table" then return end
                for k, v in pairs(a) do
                    local tv = type(v)
                    if tv == "table" or tv == "string" or tv == "number" or tv == "boolean" then
                        local bv = nil
                        if type(b) == "table" then bv = b[k] end -- (not `and b[k] or nil`: a saved false read as missing)
                        if bv == nil and not (tv == "number" and (v ~= v or math.abs(v) == math.huge)) and not (type(k) == "string" and string.sub(k, 1, 1) == "_") then
                            table.insert(lost, path .. "." .. tostring(k) .. " (" .. type(k) .. " key)")
                        elseif tv == "table" then
                            Walk(v, bv, path .. "." .. tostring(k))
                        end
                    end
                end
            end
            for f, v in pairs(data) do if type(v) == "table" then Walk(state[f], v, f) end end
            return #lost == 0 and "save keeps everything" or ("DROPPED: " .. table.concat(lost, " | "))
        elseif cmd == "oldrarity" then
            -- (UPDATE 8 LOOT) Invoke("oldrarity") -> plant OLD-ladder items / settings in your state (a Legendary gun + a Celestial
            -- helmet in the bag, an Epic gun in the stash, an exotic stamped Transcendent, auto-sell "Epic", a Loot Lens rule
            -- ">= Legendary", Ledger keys of old ranks); then ["rejoin"] = save + load through ItemData.NormalizeRarities
            local function Old(it, r) it.Rarity = r; return it end
            table.insert(state.Inventory, Old(ItemData.GenerateWeaponOfBase("AK47", "Rare", state.Level), "Legendary"))
            table.insert(state.GearInventory, Old(ItemData.GenerateRandomGear("Helmet", "Rare", 1, state.Level), "Celestial"))
            local ex = ItemData.MakeExotic("IronChoir", "Relic", state.Level)
            table.insert(state.Inventory, Old(ex, "Transcendent"))
            state.Hideout = type(state.Hideout) == "table" and state.Hideout or {}
            state.Hideout.Stash = type(state.Hideout.Stash) == "table" and state.Hideout.Stash or { W = {}, G = {} }
            state.Hideout.Stash.W = state.Hideout.Stash.W or {}
            table.insert(state.Hideout.Stash.W, Old(ItemData.GenerateWeaponOfBase("MP5", "Rare", state.Level), "Epic"))
            state.AutoSellThreshold, state.AutoSellV4 = "Epic", nil
            state.DropRules = { { K = "Any", Op = ">=", R = "Legendary", T = "", A = "Glow" } }
            state.Archive = type(state.Archive) == "table" and state.Archive or {}
            state.Archive.Rarity, state.Archive.RarityV = { ["1"] = true, ["5"] = true, ["9"] = true }, nil
            Sync(player, state)
            return "planted: inv " .. #state.Inventory .. " gear " .. #state.GearInventory
        elseif cmd == "oldgunnames" then
            -- (GUN NAMES 2026-10-24) Invoke("oldgunnames") -> every renamed gun planted under its OLD name (bag + stash, a Riftmod
            -- named after the old gun); ("oldgunnames", "list") -> the names you hold now. Then ["rejoin"] = load through MigrateGunNames.
            local function Old(w, id)
                local r = ItemData.GunRenames[id]
                local i, j = string.find(w.Name, r[2], 1, true)
                if i then w.Name = string.sub(w.Name, 1, i - 1) .. r[1] .. string.sub(w.Name, j + 1) end
                return w
            end
            if a == "list" then
                local t = {}
                for _, w in ipairs(state.Inventory) do if ItemData.GunRenames[w.BaseId or ""] then table.insert(t, w.Name) end end
                local st = state.Hideout and state.Hideout.Stash
                for _, w in ipairs(st and st.W or {}) do if ItemData.GunRenames[w.BaseId or ""] then table.insert(t, "S:" .. w.Name) end end
                for _, m in ipairs(type(state.Riftmods) == "table" and state.Riftmods or {}) do table.insert(t, "M:" .. tostring(m.Name)) end
                return table.concat(t, " | ")
            end
            for id in pairs(ItemData.GunRenames) do
                local w = ItemData.GenerateWeaponOfBase(id, "Rare", state.Level)
                if w then table.insert(state.Inventory, Old(w, id)) end
            end
            state.Hideout = type(state.Hideout) == "table" and state.Hideout or {}
            state.Hideout.Stash = type(state.Hideout.Stash) == "table" and state.Hideout.Stash or { W = {}, G = {} }
            state.Hideout.Stash.W = state.Hideout.Stash.W or {}
            local sw = ItemData.GenerateWeaponOfBase("F2000", "Epic", state.Level)
            if sw then table.insert(state.Hideout.Stash.W, Old(sw, "F2000")) end
            CombatServer.GiveRiftmod(player, state, "AA12")
            local m = type(state.Riftmods) == "table" and state.Riftmods[#state.Riftmods]
            if m and type(m.Name) == "string" then Old(m, "AA12") end
            Sync(player, state)
            return "planted: inv " .. #state.Inventory .. " mod " .. tostring(m and m.Name)
        elseif cmd == "rarities" then
            -- (UPDATE 8 LOOT) Invoke("rarities") -> the rarity of every item you hold + the settings that name one
            local t = {}
            local function Add(where, it) if type(it) == "table" then table.insert(t, where .. ":" .. tostring(it.Name):sub(1, 18) .. "=" .. tostring(it.Rarity)) end end
            for i = math.max(1, #state.Inventory - 3), #state.Inventory do Add("W", state.Inventory[i]) end
            for i = math.max(1, #state.GearInventory - 2), #state.GearInventory do Add("G", state.GearInventory[i]) end
            local st = state.Hideout and state.Hideout.Stash
            if st and st.W then Add("S", st.W[#st.W]) end
            local ak = {}
            for k in pairs(state.Archive and state.Archive.Rarity or {}) do table.insert(ak, k) end
            table.sort(ak)
            return table.concat(t, " | ") .. " || autosell " .. tostring(state.AutoSellThreshold) .. " rule " .. tostring(state.DropRules and state.DropRules[1] and state.DropRules[1].R)
                .. " ledger " .. table.concat(ak, ",")
        elseif cmd == "rejoin" then
            -- save -> forget -> load back (the leave/rejoin path, using the mock store in unpublished Studio)
            local before = string.format("Lv%d gold %d inv %d gear %d nodes %d eq %s", state.Level, state.Gold, #state.Inventory, #state.GearInventory, #state.AllocatedNodes, tostring(state.EquippedWeapon.Uid))
            local ok = CombatServer.DevSimulateRejoin(player)
            local s2 = CombatServer.GetState(player)
            local after = string.format("Lv%d gold %d inv %d gear %d nodes %d eq %s", s2.Level, s2.Gold, #s2.Inventory, #s2.GearInventory, #s2.AllocatedNodes, tostring(s2.EquippedWeapon.Uid))
            return "saved=" .. tostring(ok) .. " | before: " .. before .. " | after: " .. after .. " | same equipped table in inventory: " .. tostring(table.find(s2.Inventory, s2.EquippedWeapon) ~= nil)
        elseif cmd == "seasonxp" then
            -- Invoke("seasonxp", n) -> add Season Journey XP
            CombatServer.AddSeasonXP(player, state, a or 5000)
            Sync(player, state)
            return "season xp " .. tostring(state.Season and state.Season.XP)
        elseif cmd == "storm" then
            -- Invoke("storm") -> start a Loot Storm now
            workspace:SetAttribute("LootStormUntil", workspace:GetServerTimeNow() + 300)
            return "storm on"
        elseif cmd == "spectest" then
            -- Invoke("spectest", "start" | "stop") -> feed THIS client a fake watched floor (Studio has one player): the
            -- puppet floor, 3 puppet bots moving in a circle, and the first-person rig of your own gun (SpectateClient)
            local feed = Remotes.GetEvent("SpectateFeed")
            if a == "stop" then feed:FireClient(player, "Stop", "test over"); player:SetAttribute("SpecTest", nil); return "stopped" end
            local look = { Weapon = state.EquippedWeapon, BaseId = state.EquippedWeapon and state.EquippedWeapon.BaseId, Cos = state.CosmeticsEquipped }
            feed:FireClient(player, "Floor", { Biome = b or "Ice", Difficulty = "Easy", FloorNumber = 2, PlayerLevel = 1, Seed = 4242, BotSkill = 4, Mods = "",
                BossArena = false, Layout = "Pillars" }, look, nil)
            task.wait(2)
            local zc = require(game.ReplicatedStorage.AimRngShared.DungeonGenerator).GetChamberLayout(false).CombatZ
            local rows = {}
            for i = 1, 3 do table.insert(rows, { Kind = "Bot", Archetype = (i == 2) and "Orbiter" or "Tracker", EnemyId = 900 + i, SpawnPos = Vector3.new(i * 12 - 24, 8, zc), MaxHealth = 100, Health = 100 - i * 20 }) end
            feed:FireClient(player, "Roster", rows)
            player:SetAttribute("SpecTest", true)
            task.spawn(function()
                local posEv = Remotes.GetEvent("SpectatePos")
                local t0 = os.clock()
                while player:GetAttribute("SpecTest") and os.clock() - t0 < 60 do
                    local tt = os.clock() - t0
                    local pos = {}
                    for i = 1, 3 do pos[tostring(900 + i)] = { Vector3.new(math.cos(tt + i * 2.1) * 30, 8 + i * 2, zc + math.sin(tt + i * 2.1) * 30), 100 - i * 20, 100 } end
                    ;(posEv :: any):FireClient(player, pos)
                    task.wait(1 / 8)
                end
            end)
            return "fed"
        elseif cmd == "hideout" then
            -- Invoke("hideout", action, a, b) -> Hideouts.Act as this player (Enter / CraftMap uid action / OpenMap uid ...);
            -- uid "first" means the uid of the first sigil in the bag
            if b == "first" then b = (state.Sigils and state.Sigils[1] and state.Sigils[1].Uid) end
            -- (UPDATE 6: "equipped" / "bag1" / "bag2" = that gun's uid, for SetRack)
            for _, k in ipairs({ "b", "c" }) do
                local v = (k == "b") and b or c
                local w = (v == "equipped") and state.EquippedWeapon or (type(v) == "string" and v:match("^bag(%d)$") and state.Inventory[tonumber(v:match("^bag(%d)$"))]) or nil
                if w then if k == "b" then b = w.Uid else c = w.Uid end end
            end
            local ok, msg = require(script.Parent:WaitForChild("Hideouts")).Act(player, tostring(a or ""), b, c, d, e) -- (UPDATE 6: Place needs 4)
            return tostring(ok) .. " " .. tostring(msg)
        elseif cmd == "hideoutgive" then
            -- (UPDATE 6) Invoke("hideoutgive", id) -> own one more of a hideout piece (any source: drops, achievements, premium)
            local Hideouts = require(script.Parent:WaitForChild("Hideouts"))
            return tostring(Hideouts.Grant(player, tostring(a), true))
        elseif cmd == "devtitles" then
            -- (UPDATE 6) Invoke("devtitles", n) -> unlock the first n titles of ItemData.Titles (Studio tests of the title wall)
            state.UnlockedTitles = state.UnlockedTitles or {}
            local n = 0
            for id in pairs(ItemData.Titles) do
                if n >= (tonumber(a) or 6) then break end
                if not table.find(state.UnlockedTitles, id) then table.insert(state.UnlockedTitles, id) end
                n += 1
            end
            if b then state.EquippedTitle = state.UnlockedTitles[1] end
            Sync(player, state)
            return "titles " .. #state.UnlockedTitles
        elseif cmd == "mapmods" then
            -- (MAPS V2, MODS builder) Invoke("mapmods", "card", i) -> map i's card (stat line + mod lines at its tier);
            -- ("mapmods", "roll", tier, rarity, n) -> n fresh sigils: mean mods / quantity / rarity / pack size + groups or MinTier broken;
            -- ("mapmods", "rupture", tier, n) -> n fresh corrupted Rare maps ruptured: result counts (+ any map destroyed);
            -- ("mapmods", "set", i, "Field=v,...") -> numbers onto map i (Quality / Tier); ("mapmods", "values", tier) -> every mod's text
            local Rifts = require(game.ReplicatedStorage.AimRngShared.Rifts)
            local FM = require(game.ReplicatedStorage.AimRngShared.FloorMods)
            local MapCard = require(game.ReplicatedStorage.AimRngShared.MapCard)
            local HS = game:GetService("HttpService")
            if a == "card" then
                local sg = state.Sigils and state.Sigils[tonumber(b) or 1]
                if not sg then return "no map" end
                return HS:JSONEncode({ Name = Rifts.DisplayName(sg), Tier = sg.Tier, Stat = MapCard.StatLine(sg), Tag = MapCard.TagLine(sg), Mods = MapCard.ModLines(sg), Q = sg.Quality, Inks = sg.Inks })
            elseif a == "roll" then
                local tier, rar, n = tonumber(b) or 1, c or "Rare", tonumber(d) or 500
                local sm, sq, sr, sp, bad, sl, ml = 0, 0, 0, 0, 0, 0, 0
                for _ = 1, n do
                    local sg = Rifts.NewSigil(tier, nil, rar)
                    sm += #sg.Mods; sq += Rifts.Quantity(sg); sr += Rifts.Rarity(sg); sp += Rifts.PackSize(sg)
                    local ld = Rifts.MapLoad(sg.Mods, tier) -- (MAP PACING: the map's load, never over Rifts.LOAD_CAP)
                    sl += ld; ml = math.max(ml, ld)
                    if Rifts.BudgetLoad(sg.Mods, tier) > Rifts.LOAD_CAP + 1e-6 then bad += 1 end -- (MAP HEALTH: health mods sit outside the cap)
                    local groups = {}
                    for _, m in ipairs(sg.Mods) do
                        local dd = FM.Defs[m]
                        if dd and dd.MinTier and tier < dd.MinTier then bad += 1 end
                        if dd and dd.Group then if groups[dd.Group] then bad += 1 end; groups[dd.Group] = true end
                    end
                end
                return string.format("T%d %s x%d: mods %.2f, quantity +%.1f%%, rarity +%.1f%%, pack +%.1f%%, load %.3f (max %.3f), rule breaks %d", tier, rar, n, sm / n, sq / n * 100, sr / n * 100, sp / n * 100, sl / n, ml, bad)
            elseif a == "rupture" then
                local tier, n = tonumber(b) or 12, tonumber(c) or 1000
                local count, q0, q1 = {}, 0, 0
                for _ = 1, n do
                    local sg = Rifts.NewSigil(tier, nil, "Rare")
                    sg.Corrupted = true
                    q0 += Rifts.Quantity(sg)
                    Rifts.ApplyCraft(sg, "Rupture")
                    count[sg.RuptureResult or "?"] = (count[sg.RuptureResult or "?"] or 0) + 1
                    q1 += Rifts.Quantity(sg)
                    if not sg.Ruptured then count.NotRuptured = (count.NotRuptured or 0) + 1 end
                end
                return string.format("T%d x%d: %s  quantity %.1f%% -> %.1f%%", tier, n, HS:JSONEncode(count), q0 / n * 100, q1 / n * 100)
            elseif a == "set" then
                local sg = state.Sigils and state.Sigils[tonumber(b) or 1]
                if not sg then return "no map" end
                for k, v in string.gmatch(tostring(c or ""), "(%w+)=([^,]+)") do
                    if k == "Mods" then sg.Mods = string.split(v, "|") -- (LOOP final check: "Mods=SWARMING|BIG_PACKS|..." = an exact mod list)
                    else sg[k] = tonumber(v) or (v == "true" and true) or (v == "nil" and nil) or v end
                end
                Sync(player, state)
                return HS:JSONEncode(sg)
            elseif a == "values" then
                local sc, t = Rifts.ModScale(tonumber(b) or 1), {}
                for _, m in ipairs(Rifts.ModPool()) do table.insert(t, m .. ": " .. FM.TextOf(m, sc)) end
                return string.format("scale %.3f\n", sc) .. table.concat(t, "\n")
            elseif a == "node" then -- ("mapmods", "node", id, on?) -> own / drop one map-tree node directly (test only: no point / path check)
                state.Atlas = type(state.Atlas) == "table" and state.Atlas or { Nodes = {} }
                state.Atlas.Nodes = state.Atlas.Nodes or {}
                state.Atlas.Nodes[tostring(b)] = (c ~= false) or nil
                Sync(player, state)
                return HS:JSONEncode(require(game.ReplicatedStorage.AimRngShared.AtlasData).Stats(state))
            end
            return "mapmods: card | roll | rupture | set | values | node"
        elseif cmd == "sigil" then
            -- Invoke("sigil", tier, rarity?) -> a rift sigil (map) into the bag; rarity Normal / Magic / Rare / Unique
            local Rifts = require(game.ReplicatedStorage.AimRngShared.Rifts)
            if a == "list" then return game:GetService("HttpService"):JSONEncode(state.Sigils or {}) end
            if a == "clear" then state.Sigils = {}; Sync(player, state); return "cleared" end
            if a == "start" then -- (UPDATE 7: open the first map in the bag straight away, as the map device's portal would)
                local uid = state.Sigils and state.Sigils[1] and state.Sigils[1].Uid
                local ok, msg = require(script.Parent:WaitForChild("EndgameServer")).StartRift(player, uid, tonumber(b))
                return "start " .. tostring(ok) .. " " .. tostring(msg)
            end
            require(script.Parent:WaitForChild("EndgameServer")).GiveSigil(player, state, Rifts.NewSigil(a or 1, nil, b))
            Sync(player, state)
            return "sigils " .. #state.Sigils
        elseif cmd == "wkills" then
            -- Invoke("wkills", baseId, kills) -> set weapon-mastery kills for a gun
            state.StatsTracking.WeaponKills = state.StatsTracking.WeaponKills or {}
            state.StatsTracking.WeaponKills[a or state.EquippedWeapon.BaseId] = b or 1000
            Sync(player, state)
            return "kills set"
        elseif cmd == "melee" then
            -- Invoke("melee", meleeId, skinId?) -> own + equip that melee (and skin)
            if not ItemData.MeleeWeapons[a] then return "unknown melee " .. tostring(a) end
            if not table.find(state.KnifeInventory, a) then table.insert(state.KnifeInventory, a) end
            state.EquippedKnife = a
            if b then
                state.OwnedMeleeSkins = state.OwnedMeleeSkins or {}
                state.OwnedMeleeSkins[b] = true
                state.MeleeSkinFor = state.MeleeSkinFor or {}
                state.MeleeSkinFor[a] = b
            end
            Sync(player, state)
            return "melee " .. a
        elseif cmd == "meleeskins" then
            -- Invoke("meleeskins") -> own every melee skin and every melee
            local MD = require(game.ReplicatedStorage.AimRngShared.MeleeData)
            state.OwnedMeleeSkins = {}
            for id in pairs(MD.Skins) do state.OwnedMeleeSkins[id] = true end
            for id in pairs(ItemData.MeleeWeapons) do if not table.find(state.KnifeInventory, id) then table.insert(state.KnifeInventory, id) end end
            return "all melee skins + melees"
        elseif cmd == "atlas" then
            -- Invoke("atlas", riftBest, mapsDone) -> sets the map-tree point sources; ("atlas", "reset") clears the tree
            if a == "reset" then state.Atlas = nil; Sync(player, state); return "map tree cleared" end
            state.RiftBest = tonumber(a) or state.RiftBest
            state.MapsDone = tonumber(b) or state.MapsDone
            Sync(player, state)
            local AtlasData = require(game.ReplicatedStorage.AimRngShared.AtlasData)
            return string.format("points %d, free %d", AtlasData.PointsFor(state), AtlasData.Free(state))
        elseif cmd == "mapcomplete" then
            -- (MAPS V2 L2) Invoke("mapcomplete", "state" | "clear" | "fill" [, band] | "mark", band, typeId) -> completions + map points
            local MC = require(game.ReplicatedStorage.AimRngShared.MapCompletion)
            local AtlasData = require(game.ReplicatedStorage.AimRngShared.AtlasData)
            if a == "clear" then state.MapComplete = nil
            elseif a == "fill" then
                for _, band in ipairs(MC.Bands()) do
                    if not b or b == band then
                        state.MapComplete = state.MapComplete or {}
                        state.MapComplete[band] = state.MapComplete[band] or {}
                        for _, t in ipairs(MC.Types()) do state.MapComplete[band][t.Id] = 1 end
                    end
                end
            elseif a == "mark" then
                local R = require(game.ReplicatedStorage.AimRngShared.Rifts)
                local tier = R.FirstTierOf(b) or 1
                local u = R.UNIQUES[c or ""]
                MC.Mark(state, { Tier = tier, Biome = (not u) and c or nil, Unique = u and c or nil })
            end
            Sync(player, state)
            local bd = AtlasData.Breakdown(state)
            return string.format("completions %d / %d, points %d (tier %d + completion %d + maps %d; legacy %d)", MC.Count(state), MC.Total(),
                bd.Total, bd.Tier, bd.Completion, bd.Maps, bd.Legacy)
        elseif cmd == "guild" then
            -- (UPDATE 7 B9) Invoke("guild", action, a) = GuildService.Act as you (Create takes "Name|TAG"); ("guild", "botrequest") = a test
            -- player (UserId 999) asks to join your guild
            local GS = require(script.Parent:WaitForChild("GuildService"))
            if a == "botrequest" then
                local _, view = GS.Act(player, "Get")
                if not (view and view.Guild) then return "no crew" end
                GS._TestRequest(view.Guild.Id, 999, "TestRecruit")
                return "requested"
            end
            local arg = b
            if a == "Create" and type(b) == "string" then local n, t = string.match(b, "^(.-)|(.+)$"); arg = { Name = n, Tag = t } end
            local ok, res = GS.Act(player, a or "Get", tonumber(arg) or arg)
            if type(res) == "table" then res = game:GetService("HttpService"):JSONEncode(res) end
            return tostring(ok) .. " " .. tostring(res)
        elseif cmd == "market" then
            -- (UPDATE 7 C7) Invoke("market", "list", tabId, kind, uidIdx, key, n) = MarketService.List as you (uidIdx = the item's index in the tab)
            -- | ("market", "buy", id|"first") as you | ("market", "botbuy", id|"mine") = a test buyer buys it | ("market", "botlist", rarity, key, n) =
            -- a test seller lists a gun | ("market", "cancel", id|"mine") | ("market", "collect") | ("market", "browse") | ("market", "mine")
            local MS = require(script.Parent:WaitForChild("MarketService"))
            local HSv = game:GetService("HttpService")
            local function FirstOther()
                local r = MS.Browse(player, {})
                for _, s in ipairs(r.Results) do if s.Seller ~= player.UserId then return s.Id end end
            end
            local function FirstMine()
                local m = MS.Mine(player)
                for _, l in ipairs(m.Listings) do if l.Status == "Open" then return l.Summary.Id end end
            end
            if a == "list" then
                local box = require(game.ReplicatedStorage.AimRngShared.StashTabs).Box(state, b)
                local list = box and ((c == "Weapon") and box.W or box.G) or (c == "ShotMod" and state.ShotMods) or state.Riftmods -- (UPDATE 8 phase 3: "ShotMod" = the mod bag)
                local it = list and list[tonumber(d) or 1]
                local ok, msg = MS.List(player, b, c, it and it.Uid, e, f)
                return tostring(ok) .. " " .. tostring(msg)
            elseif a == "buy" then
                local ok, msg = MS.Buy(player, (b == "first" or b == nil) and FirstOther() or b)
                return tostring(ok) .. " " .. tostring(msg) .. " | gold " .. tostring(state.Gold)
            elseif a == "botbuy" then
                local ok, msg = MS.Buy(nil, (b == "mine" or b == nil) and FirstMine() or b, 999)
                return tostring(ok) .. " " .. tostring(msg)
            elseif a == "botlist" then
                -- a fake seller (UserId 999) lists a gun straight into the market (escrow record + index, as MS.List writes them)
                -- (CHASE ITEMS: rarity = a Zenith id -> that Zenith, weapon or gear)
                local zd = ItemData.Exotics[b or ""]
                local w = (zd and zd.Zenith) and ItemData.MakeZenith(b, state.Level or 1) or ItemData.GenerateRandomWeapon(b or "Epic", nil, state.Level or 1, true)
                local id = HSv:GenerateGUID(false)
                MS._TestPut(id, { Id = id, Seller = 999, SellerName = "TestSeller", Kind = (zd and zd.Zenith and zd.Kind == "Gear") and "Gear" or "Weapon", Item = w, Price = { Key = c or "Gold", N = tonumber(d) or 500 }, At = os.time(), Status = "Open" })
                return "listed " .. id .. " " .. tostring(w.Name)
            elseif a == "cancel" then
                local ok, msg = MS.Cancel(player, (b == "mine" or b == nil) and FirstMine() or b)
                return tostring(ok) .. " " .. tostring(msg)
            elseif a == "notice" then -- (QOL2 H3) ("market", "notice", gold?) = proceeds waiting (Studio memory store) + the join check again
                if b then MS._TestProceeds(player.UserId, { Gold = tonumber(b) or 100 }) end
                player:SetAttribute("ExchangeSold", nil)
                MS.SaleNotice(player)
                return "ExchangeSold=" .. tostring(player:GetAttribute("ExchangeSold"))
            elseif a == "collect" then
                local ok, msg = MS.Collect(player)
                return tostring(ok) .. " " .. tostring(msg) .. " | gold " .. tostring(state.Gold)
            elseif a == "browse" then
                local r = MS.Browse(player, { Text = b, MinRarity = c }) -- (c = a rarity floor, or "Zenith": Zeniths only)
                local t = {}
                for _, s in ipairs(r.Results) do table.insert(t, s.Name .. "=" .. s.Price.N .. s.Price.Key .. "(" .. tostring(s.SellerName) .. ")") end
                return r.Total .. " total: " .. table.concat(t, ", ")
            end
            local m = MS.Mine(player)
            local t = {}
            for _, l in ipairs(m.Listings) do table.insert(t, l.Summary.Name .. ":" .. l.Status) end
            return table.concat(t, ", ") .. " | proceeds " .. HSv:JSONEncode(m.Proceeds)
        elseif cmd == "spoils" then -- (UPDATE 7 B4) Invoke("spoils", "pick", i) = pick item i of the last Shared Spoils session
            local SS = require(script.Parent:WaitForChild("SharedSpoils"))
            local ok, msg = SS.Pick(player, SS.Last, tonumber(b) or 1)
            return tostring(ok) .. " " .. tostring(msg) .. " | seals " .. tostring((state.Materials or {}).SpoilsSeal or 0)
        elseif cmd == "livinghub" then -- (UPDATE 7 A6) Invoke("livinghub", "statues") | ("livinghub", "drop", name)
            local LH = require(script.Parent:WaitForChild("LivingHub"))
            if a == "statues" then
                pcall(function() require(script.Parent:WaitForChild("EndgameServer")).SubmitLevel(player); task.wait(6) end)
                LH.RefreshStatues()
            elseif a == "drop" then
                LH.NoteDrop(player.DisplayName, tostring(b or "Test Item"), "Mythic", 1600, ItemData.RarityColors.Mythic)
            end
            return "ok"
        elseif cmd == "district" then -- (UPDATE 7 B5) Invoke("district") = the record | ("district", "event", name, n, ctxJson) | ("district", "buy", id, item) | ("district", "standing", id, n)
            local D = require(game.ReplicatedStorage.AimRngShared.Districts)
            local s = D.Ensure(state, player.UserId)
            local note = ""
            if a == "event" then
                local ok, ctx = pcall(function() return game:GetService("HttpService"):JSONDecode(tostring(d or "{}")) end)
                CombatServer.ContractEvent(player, state, tostring(b), tonumber(c) or 1, ok and ctx or {})
            elseif a == "buy" then
                local ok, msg = CombatServer.DistrictAct(player, "Buy", b, c)
                note = tostring(ok) .. " " .. tostring(msg) .. " | "
            elseif a == "standing" then
                s.Earned[b] = (s.Earned[b] or 0) + (tonumber(c) or 1000); s.Bank[b] = (s.Bank[b] or 0) + (tonumber(c) or 1000)
            end
            Sync(player, state)
            return note .. game:GetService("HttpService"):JSONEncode(state.Districts)
        elseif cmd == "line" then -- (UPDATE 7 B6) Invoke("line") = today's record | ("line", "start") | ("line", "reset")
            local EG = require(script.Parent:WaitForChild("EndgameServer"))
            local note = ""
            if a == "start" then
                local ok, msg = EG.StartDailyLine(player)
                note = tostring(ok) .. " " .. tostring(msg) .. " | "
            elseif a == "reset" then
                state.DailyLine = nil
            end
            return note .. game:GetService("HttpService"):JSONEncode(state.DailyLine or {})
        elseif cmd == "apex" then -- (UPDATE 7 C1) Invoke("apex") = your Coordinates | ("apex", "give", n) = n of each | ("apex", "start", uber?) = ApexAction as you
            local AH = require(game.ReplicatedStorage.AimRngShared.ApexHunt)
            state.Materials = state.Materials or {}
            local note = ""
            if a == "give" then
                for _, k in ipairs(AH.COORDS) do state.Materials[k] = (state.Materials[k] or 0) + (tonumber(b) or 1) end
            elseif a == "start" then
                local ok, msg = require(script.Parent:WaitForChild("EndgameServer")).ApexAction(player, "Start", b == true or b == "uber")
                note = tostring(ok) .. " " .. tostring(msg) .. " | "
            end
            Sync(player, state)
            local t = {}
            for _, k in ipairs(AH.COORDS) do table.insert(t, k .. "=" .. tostring(state.Materials[k] or 0)) end
            return note .. table.concat(t, " ") .. " taint=" .. tostring(state.Materials.RiftTaint or 0)
        elseif cmd == "droprules" then -- (UPDATE 7 C9) Invoke("droprules", json list) = your drop rules (cleaned as the remote does)
            local DR = require(game.ReplicatedStorage.AimRngShared.DropRules)
            local ok, list = pcall(function() return game:GetService("HttpService"):JSONDecode(tostring(a or "[]")) end)
            state.DropRules = ok and DR.Clean(list, state) or {}
            Sync(player, state)
            return game:GetService("HttpService"):JSONEncode(state.DropRules)
        elseif cmd == "calibration" then
            -- (UPDATE 7 B2) Invoke("calibration") = your gun's record | ("calibration", "feat", kind, n) = CombatServer.CalibrationFeat
            -- with the gun in hand | ("calibration", "act", action, gun|"equipped", b, c) = CombatServer.CalibrationAct |
            -- ("calibration", "set", gun|"equipped", T, P) | ("calibration", "reset")
            local Cal = require(game.ReplicatedStorage.AimRngShared.Calibration)
            local function Gun(g) return (g == "equipped" or g == nil) and state.EquippedWeapon and state.EquippedWeapon.BaseId or g end
            local note = ""
            if a == "feat" then
                CombatServer.CalibrationFeat(player, state, tostring(b), tonumber(c) or 1)
            elseif a == "act" then
                local ok, msg = CombatServer.CalibrationAct(player, b, Gun(c), tonumber(d) or d, tonumber(e) or e)
                note = tostring(ok) .. " " .. tostring(msg) .. " | "
            elseif a == "set" then
                local cc = Cal.Ensure(state, Gun(b))
                cc.T = tonumber(c) or cc.T
                cc.P = tonumber(d) or 0
            elseif a == "reset" then
                state.Calibration = {}
            end
            Sync(player, state)
            local g = state.EquippedWeapon and state.EquippedWeapon.BaseId
            local st = require(game.ReplicatedStorage.AimRngShared.StatCalculator).Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
            local perk = {}
            for k2, v in pairs(Cal.StatsFor(state, g)) do table.insert(perk, k2 .. "=" .. v) end
            return note .. tostring(g) .. " " .. game:GetService("HttpService"):JSONEncode(Cal.Of(state, g) or {}) .. " perks {" .. table.concat(perk, ", ") .. "} gold " .. tostring(state.Gold)
                .. " | weakspot " .. string.format("%.3f", st.WeakSpotMultiplier or 0) .. " crit " .. string.format("%.3f", st.CritChance or 0)
        elseif cmd == "etch" then
            -- (UPDATE 7) Invoke("etch", "gear"?) = etch one line of your gun in hand (or your first bag gear piece), whatever the odds
            local isG = a == "gear"
            if isG then -- (a fresh Legendary piece at the front of the gear bag: craftv5 / forge "gear" use the first one)
                table.insert(state.GearInventory, 1, ItemData.GenerateRandomGear("Helmet", "Legendary", nil, state.Level or 1))
            end
            local it = isG and state.GearInventory[1] or state.EquippedWeapon
            local old = ItemData.ETCH_CHANCE
            ItemData.ETCH_CHANCE = 1
            local ok = ItemData.TryEtch(it, isG, math.max(state.Level or 1, ItemData.ETCH_UNLOCK))
            ItemData.ETCH_CHANCE = old
            Sync(player, state)
            local t = {}
            for _, l in ipairs(ItemData.LinesOf(it, isG)) do table.insert(t, l.Stat .. (l.Etched and "*" or "")) end
            return tostring(ok) .. " " .. table.concat(t, ", ")
        elseif cmd == "contract" then
            -- (UPDATE 7) Invoke("contract") = this week's bounty contract; ("contract", "kill") = CombatServer.ContractKill (errors
            -- shown); ("contract", "reset") = a fresh contract (Done off, 0 escapes)
            local BC = require(game.ReplicatedStorage.AimRngShared.BountyContract)
            if a == "reset" then state.BountyContract = nil end
            local c = BC.Ensure(state, player.UserId)
            local note = ""
            if a == "kill" then
                local ok, err = pcall(CombatServer.ContractKill, player, state)
                note = "kill " .. tostring(ok) .. " " .. tostring(err) .. " | "
            elseif a == "shoot" then -- (the real kill pipeline on the contract target alone)
                local DungeonRuns = require(script.Parent:WaitForChild("DungeonRuns"))
                local StatCalculator = require(game.ReplicatedStorage.AimRngShared.StatCalculator)
                local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
                local hit = false
                for _, proxy in ipairs(DungeonRuns.EnemiesOf(player)) do
                    -- (b = "others": everything BUT the target -- the floor clears around it)
                    if (proxy:GetAttribute("Contract") == true) == (b ~= "others") then
                        CombatServer.DealEnemyDamage(player, state, proxy, tonumber(b) or 1e12, stats, { NoTakenMult = true }); hit = true
                    end
                end
                note = "shot " .. tostring(hit) .. " | "
            end
            return note .. game:GetService("HttpService"):JSONEncode(c or {})
        elseif cmd == "riftmod" then
            -- (UPDATE 7) Invoke("riftmod", n, "equipped"?) = n Riftmods (for your gun in hand); ("riftmod", "act", action, a, b) =
            -- RiftmodAction as you ("Fit" "first" "equipped" = the first mod onto your gun); ("riftmod") = the bag + your gun's mod
            local RM = require(game.ReplicatedStorage.AimRngShared.Riftmods)
            state.Riftmods = type(state.Riftmods) == "table" and state.Riftmods or {}
            if a == "act" then
                local x, y = c, d
                if x == "first" then x = state.Riftmods[1] and state.Riftmods[1].Uid end
                if y == "equipped" then y = state.EquippedWeapon and state.EquippedWeapon.Uid end
                if b == "Remove" and x == "equipped" then x = state.EquippedWeapon and state.EquippedWeapon.Uid end
                local ok, msg = CombatServer.RiftmodAct(player, b, x, y)
                return tostring(ok) .. " " .. tostring(msg)
            elseif tonumber(a) then
                for _ = 1, tonumber(a) do CombatServer.GiveRiftmod(player, state, (b == "equipped" and state.EquippedWeapon) and state.EquippedWeapon.BaseId or nil) end
            end
            local t = {}
            for _, m in ipairs(state.Riftmods) do table.insert(t, m.Name .. " [" .. RM.LinesText(m) .. "]") end
            local eq = state.EquippedWeapon
            return #state.Riftmods .. " mods: " .. table.concat(t, " ; ") .. " | gun " .. tostring(eq and eq.Name) .. " mod: " .. tostring(eq and type(eq.Riftmod) == "table" and RM.LinesText(eq.Riftmod) or "none")
                .. " | dust " .. tostring(state.Materials and state.Materials.RiftDust)
        elseif cmd == "mastery" then
            -- (UPDATE 7) Invoke("mastery") = rank / points / exam; ("mastery", "kills", n) = n kills on every lineup gun;
            -- ("mastery", "exam", scenario, trialRank) = an Aim Trial result through CombatServer.MasteryExam; ("mastery", "set", r)
            local MR = require(game.ReplicatedStorage.AimRngShared.MasteryRank)
            state.StatsTracking.WeaponKills = state.StatsTracking.WeaponKills or {}
            local note = ""
            if a == "kills" then
                for _, id in ipairs(ItemData.Lineup) do state.StatsTracking.WeaponKills[id] = (state.StatsTracking.WeaponKills[id] or 0) + (tonumber(b) or 0) end
            elseif a == "exam" then
                note = "passed=" .. tostring(CombatServer.MasteryExam(player, state, tostring(b), tonumber(c) or 0)) .. " "
            elseif a == "set" then
                state.MasteryRank = tonumber(b) or 0
                CombatServer.EnsureContracts(player, state)
                pcall(CombatServer.UpdatePlayerTitleTag, player)
            end
            Sync(player, state)
            local can, why = MR.CanExam(state)
            local r = MR.Rank(state)
            local ex = MR.Exam(r + 1)
            return string.format("%srank %d points %d canExam %s (%s) next exam %s/%s | bagcap %d contracts %d rerolls+%d", note, r, MR.Points(state), tostring(can), tostring(why),
                ex.Scenario, tostring(ex.NeedName), ItemData.BagCap(state), #(state.Contracts and state.Contracts.List or {}), MR.ExtraRerolls(r))
        elseif cmd == "weekly" then
            -- (UPDATE 7) Invoke("weekly") = your week as JSON; ("weekly", "boss") = start this week's boss solo (the real start);
            -- ("weekly", "reroll", i); ("weekly", "event", name, amount, ctxJson) = feed one contract / bounty event;
            -- ("weekly", "reset") = a fresh week (board re-rolled, boss stack unclaimed)
            local Weekly = require(game.ReplicatedStorage.AimRngShared.Weekly)
            local Endgame = require(script.Parent:WaitForChild("EndgameServer"))
            local HS = game:GetService("HttpService")
            if a == "reset" then state.Weekly = nil end
            if a == "boss" then
                local bt = Weekly.BossOf()
                local ok, msg = Endgame.StartBossTrial(player, bt.Id, Weekly.TierFor(state.Level), "Solo", true)
                return "start " .. tostring(ok) .. " " .. tostring(msg) .. " | " .. bt.Id .. " tier " .. Weekly.TierFor(state.Level) .. " mod " .. Weekly.ModOf()
            elseif a == "reroll" then
                local ok, msg = Endgame.WeeklyAction(player, "Reroll", tonumber(b))
                return tostring(ok) .. " " .. tostring(msg)
            elseif a == "event" then
                local ctx = (type(d) == "string" and d ~= "") and HS:JSONDecode(d) or {}
                CombatServer.ContractEvent(player, state, tostring(b), tonumber(c) or 1, ctx)
            end
            local w = CombatServer.EnsureWeekly(player, state)
            Sync(player, state)
            return HS:JSONEncode(w) .. " | gold " .. state.Gold .. " mats " .. HS:JSONEncode(state.Materials)
        elseif cmd == "dailyroll" then
            -- (UPDATE 7) Invoke("dailyroll") = today's free roll again through the real server path (the day's lock cleared)
            state.LastDailyRoll = 0
            local before = game:GetService("HttpService"):JSONEncode(state.Materials)
            local w, _, msg, _, prism, jackpot = CombatServer.DailyRoll(player)
            return string.format("%s %s prism %s jackpot %s | before %s | after %s", tostring(w and w.Rarity), tostring(w and w.Name or msg), tostring(prism),
                tostring(jackpot), before, game:GetService("HttpService"):JSONEncode(state.Materials))
        elseif cmd == "admin" then
            -- (UPDATE 7) Invoke("admin", "Give" | "Take", ref) = the F6 GIFTS row's real server path on yourself, e.g. "Currency:Graft:5"
            local AS = require(script.Parent:WaitForChild("AdminService"))
            local ok, msg = AS.Act(player, a, player.UserId, b)
            return tostring(ok) .. " " .. tostring(msg)
        elseif cmd == "forge" then
            -- (UPDATE 7) Invoke("forge", mode, "gear"?, slot?) = the Forge button's real server path (ForgeReroll: costs, checks) on your
            -- equipped gun (or first bag gear piece): mode Reforge | Retype | Graft | Strip | Temper | Storm
            local isG = b == "gear"
            local it = state.EquippedWeapon
            if isG then -- (the first bag piece, else an equipped one: geartest equips; "isG and bag[1] or weapon" fell through to the gun)
                -- c = an equipped slot ("Boots") picks that piece instead of the bag
                it = (c and (state.EquippedGear or {})[c]) or state.GearInventory[1]
                if not it then for _, g in pairs(state.EquippedGear or {}) do if type(g) == "table" and g.Uid then it = g; break end end end
            end
            if not it or not CombatServer.ForgeReroll then return "no item / no ForgeReroll" end
            local before = string.format("gold %d mats %s", state.Gold, game:GetService("HttpService"):JSONEncode(state.Materials))
            local ok, msg, updated = CombatServer.ForgeReroll(player, it.Uid, isG and "Gear" or "Weapon", a)
            local u = updated or it
            return string.format("%s %s | %s %s | %s | after gold %d mats %s", tostring(ok), tostring(msg), tostring(u.Rarity), tostring(u.Name),
                before, state.Gold, game:GetService("HttpService"):JSONEncode(state.Materials))
        elseif cmd == "craftv5" then
            -- (UPDATE 7) Invoke("craftv5", "Graft" | "Strip" | "Temper" | "Storm" | "Values", "gear"?) -> the craft's item logic on your
            -- equipped gun (or first bag gear piece): lines before -> after (no cost; the Forge's server path adds the cost)
            local isG = b == "gear"
            local it = state.EquippedWeapon
            if isG then -- (same fall-through fix as "forge": the first bag piece, else an equipped one, never the gun)
                it = state.GearInventory[1]
                if not it then for _, g in pairs(state.EquippedGear or {}) do if type(g) == "table" and g.Uid then it = g; break end end end
            end
            if not it then return "no item" end
            local function Show()
                local t = {}
                for _, x in ipairs(ItemData.LinesOf(it, isG)) do table.insert(t, string.format("%s %s T%s%s", x.Stat, tostring(x.Value), tostring(x.Tier), x.Negative and "(neg)" or "")) end
                return #t .. " lines [" .. table.concat(t, "; ") .. "]"
            end
            local before = Show()
            local msg
            if a == "Values" then
                if isG then ItemData.TuneGearLines(it) else ItemData.TuneWeaponAffixes(it) end
                msg = "values rerolled"
            else
                local ok, why = ItemData.CraftV5Check(a, it, isG)
                if not ok then return "refused: " .. tostring(why) .. " | " .. before end
                msg = ItemData.CraftV5Apply(a, it, isG)
            end
            Sync(player, state)
            return string.format("%s %s (iLvl %d): %s | before %s | after %s", it.Rarity, it.Name, it.ItemLevel or 1, tostring(msg), before, Show())
        elseif cmd == "rolltest" then
            -- (0.99n ITEM SCALING v2) Invoke("rolltest", rarity, itemLevel, n) -> n fresh guns + n gear pieces of that rarity at
            -- that item level: how many lines they got, the tiers rolled and how many lines were PERFECT (nothing is kept)
            local rar, ilvl, n = type(a) == "string" and a or "Rare", tonumber(b) or 100, tonumber(c) or 200
            local lines, tiers, perfect, neg = {}, {}, 0, 0
            local function Note(list)
                for _, x in ipairs(list) do
                    if x.Negative then neg += 1 else tiers[x.Tier or 1] = (tiers[x.Tier or 1] or 0) + 1 end
                    if (tonumber(x.Roll) or 0) >= ItemData.PERFECT_ROLL and not x.Negative then perfect += 1 end
                end
            end
            for _ = 1, n do
                local w = ItemData.GenerateRandomWeapon(rar, 1, ilvl, 15)
                local k = #(w.Prefixes or {}) + #(w.Suffixes or {})
                lines["W" .. k] = (lines["W" .. k] or 0) + 1
                Note(w.Prefixes or {}); Note(w.Suffixes or {})
                local g = ItemData.GenerateRandomGear(nil, rar, 1, ilvl, 15)
                lines["G" .. #g.StatLines] = (lines["G" .. #g.StatLines] or 0) + 1
                Note(g.StatLines)
            end
            local out = {}
            for k2, v in pairs(lines) do table.insert(out, k2 .. "=" .. v) end
            table.sort(out)
            local tt = {}
            for t = 1, 15 do if tiers[t] then table.insert(tt, "T" .. t .. "=" .. tiers[t]) end end
            return string.format("%s ilvl %d x%d | lines %s | tiers %s | perfect %d | negative %d", rar, ilvl, n, table.concat(out, " "), table.concat(tt, " "), perfect, neg)
        elseif cmd == "loottest" then
            -- Invoke("loottest", "Torment", "Top3", 30) -> roll 30 drops with that floor on that difficulty, report rarities
            -- (the items are rolled into the bag and removed again; nothing is kept)
            local old, oldSell = state.DungeonDifficulty, state.AutoSellThreshold
            state.DungeonDifficulty, state.AutoSellThreshold = a or "Torment", nil
            local w0, g0 = #state.Inventory, #state.GearInventory
            local StatCalculator = require(game.ReplicatedStorage.AimRngShared.StatCalculator)
            local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
            for _ = 1, tonumber(c) or 20 do CombatServer.DropItemFor(player, state, stats, 2.2, b) end
            local count = {}
            for _, list in ipairs({ { state.Inventory, w0 }, { state.GearInventory, g0 } }) do
                for i = #list[1], list[2] + 1, -1 do
                    local r = list[1][i].Rarity
                    count[r] = (count[r] or 0) + 1
                    table.remove(list[1], i)
                end
            end
            state.DungeonDifficulty, state.AutoSellThreshold = old, oldSell
            local out = {}
            for r, n in pairs(count) do table.insert(out, r .. "=" .. n) end
            return table.concat(out, " ")
        elseif cmd == "drop" then
            -- Invoke("drop", "Common,Rare,Mythic,Relic,Gem:Epic,Gear:Rare") -> ground loot in a row in front of you (UPDATE 8: "Relic" =
            -- a random relic; old names ("Epic") roll their new rarity)
            local ItemData = require(game.ReplicatedStorage.AimRngShared.ItemData)
            local GemData = require(game.ReplicatedStorage.AimRngShared.GemData)
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if not root then return "no character" end
            local look = workspace.CurrentCamera and root.CFrame.LookVector or Vector3.new(0, 0, -1)
            local i = 0
            for spec in string.gmatch(a or "Common,Uncommon,Rare,Mythic,Relic", "[^,]+") do
                i += 1
                local kind, rar = string.match(spec, "^(%a+):(%a+)$")
                if not kind then kind, rar = "Weapon", spec end
                local item
                if kind == "Gem" then item = GemData.Generate(rar)
                elseif rar == "Relic" then
                    local ids = {}
                    for id, def in pairs(ItemData.Exotics) do if (kind == "Gear") == (def.Kind == "Gear") then table.insert(ids, id) end end
                    table.sort(ids)
                    item = ItemData.MakeExotic(ids[math.random(1, #ids)], "Relic", state.Level)
                    kind = (item and item.Slot) and "Gear" or "Weapon"
                elseif kind == "Gear" then item = ItemData.GenerateRandomGear(nil, rar, 1, state.Level, true)
                else item = ItemData.GenerateRandomWeapon(rar, 1, state.Level, true) end
                local side = root.CFrame.RightVector * ((i - 3.5) * 4)
                CombatServer.DropToGround(player, state, item, kind, root.Position + look * 12 + side - Vector3.new(0, 2.5, 0))
            end
            return "dropped " .. i
        elseif cmd == "powercurve" then
            -- POWER CURVE (CONTENT LEVEL, 2026-10-05): ["powercurve", startNode?, "1,20,50,100,..."] -> per level the treesim
            -- DPS / EHP at TreePointsAt(level) as an index over the bare level curve (L1 DPS 41.6, EHP 112 with the plain AK) --
            -- compare with ItemData.POWER_ANCHORS / TOUGH_ANCHORS (enemy health / damage follow them)
            local lines = {}
            -- (weapon classes: each class is measured with a gun of its own type, indexed over that gun's bare level-1 numbers)
            local CLASS_GUN = { CLASS_VAN = "AK47", CLASS_GUN = "MP5", CLASS_MAR = "AWP", CLASS_BRE = "BM4", CLASS_ARC = "BEAM" }
            local startId = type(a) == "string" and a or "CLASS_VAN"
            local gunId = type(d) == "string" and d or CLASS_GUN[startId] or "AK47"
            local r1 = Run(player, "treesim", startId, "", 1, 0, gunId, 0.3)
            local d1, e1 = string.match(r1, "dps ([%d%.e%+]+) / ehp ([%d%.e%+]+)")
            local cv1 = ItemData.LevelCurve(1)
            local baseD, baseE = math.max(1e-6, (tonumber(d1) or 41.6) / cv1), math.max(1e-6, (tonumber(e1) or 112) / cv1)
            for lv in string.gmatch(type(b) == "string" and b or "1,20,50,80,100,150,200,300,400", "[^,]+") do
                local L = tonumber(lv)
                local r = Run(player, "treesim", startId, "", L, ItemData.TreePointsTypical(L), (c == "GEAR") and (gunId .. "+GEAR") or gunId, 0.3)
                local dps, ehp = string.match(r, "dps ([%d%.e%+]+) / ehp ([%d%.e%+]+)")
                local cv = ItemData.LevelCurve(L)
                table.insert(lines, string.format("L%d: power %.3g (table %.3g) tough %.3g (table %.3g)", L, (tonumber(dps) or 0) / cv / baseD, ItemData.PowerIndex(L),
                    (tonumber(ehp) or 0) / cv / baseE, ItemData.ToughIndex(L)))
            end
            return table.concat(lines, " | ")
        elseif cmd == "stuff" then
            -- Invoke("stuff", weapons?, gear?) -> random weapons / gear at mixed rarities + item levels (1 .. level + 5)
            -- straight into the stash (Equip Best tests)
            local ItemData = require(game.ReplicatedStorage.AimRngShared.ItemData)
            local rars = { "Common", "Uncommon", "Rare", "Rare", "Mythic" } -- (UPDATE 8 RARITY v4)
            local top = math.max(5, state.Level + 5)
            for _ = 1, (a or 10) do table.insert(state.Inventory, ItemData.GenerateRandomWeapon(rars[math.random(1, #rars)], 1, math.random(1, top), true)) end
            for _ = 1, (b or 20) do table.insert(state.GearInventory, ItemData.GenerateRandomGear(nil, rars[math.random(1, #rars)], 1, math.random(1, top), true)) end
            Sync(player, state)
            return string.format("stash: %d weapons, %d gear", #state.Inventory, #state.GearInventory)
        elseif cmd == "spectself" then
            -- Invoke("spectself", true|false): watch yourself (SpectateService.DevSelf) -- live-view tests with one player
            return require(script.Parent:WaitForChild("SpectateService")).DevSelf(player, a == true)
        elseif cmd == "duelbot" then
            -- Invoke("duelbot", arena?, accuracy?, wager?, mode?) -> a duel against a moving, shooting bot (PvpService.DevBot);
            -- ("duelbot", "confirm") = the bot confirms the wager; ("duelbot", "state") = the duel's numbers
            local PS = require(script.Parent:WaitForChild("PvpService"))
            if a == "confirm" then return PS.DevBotConfirm(player) end
            if a == "state" then return PS.DevState(player) end
            if a == "act" then local ok, msg = PS.Act(player, b, c, d); return tostring(ok) .. " " .. tostring(msg) end -- (("duelbot", "act", "SetAbility", "Guard") etc.)
            if a == "info" then -- (0.79: what spectators get -- PvpService.Info + the SPECTATE list)
                local SS = require(script.Parent:WaitForChild("SpectateService"))
                return game:GetService("HttpService"):JSONEncode({ Info = PS.Info(player), List = SS.List and SS.List() or "no List" })
            end
            return PS.DevBot(player, a, tonumber(b), c == true, d) -- (d = mode: "Classic" | "Rotation" | "Instagib")
        elseif cmd == "tradebot" then
            -- Invoke("tradebot", "start" | "offer" n | "skin" "Cat:Id" | "ready" | "confirm" | "state"): a fake trade partner (TradeService.DevBot)
            local TS = require(script.Parent:WaitForChild("TradeService"))
            return TS.DevBot(player, tostring(a or "start"), b)
        elseif cmd == "zenith" then
            -- (CHASE ITEMS 2026-11-06) Invoke("zenith", ...): "equip", id = make + wear it (gun: full magazine), answers the numbers it changed
            -- | "drop", id | "global" | "pinnacle" = the real award (ground drop + server-wide call) | "apex", "uber"? = ZenithServer.Apex at
            -- chance 1 | "glass", n = Twin Glass found (+ the call) | "twin", "weapon" | "gear" | uid | "bogus" = TWIN GLASS on it |
            -- "state" = counters + heat | "kill", kind, n = n KillRolls at the real odds (counts what came up; nothing while dark) |
            -- "craftguard", uid = every craft entry point on that item (ForgeReroll's modes, UpgradeWeapon, ShotModAction, RiftmodAction)
            -- -> each answer (owner 2026-11-06: refused while it's offered in a trade / duel wager) | "lostloot", n, id? = n fake
            -- Mythic lost items (id = a Zenith instead) then the real cap trim -> the list's Zenith count + length | "threadclear" =
            -- ZenithServer.ThreadClear as a floor start runs it | "level" = the item level a Zenith would drop at for you
            local ItemData = require(game.ReplicatedStorage.AimRngShared.ItemData)
            local ZS = CombatServer.Zen
            local function Nums(): string
                local st = CombatServer.StatCalculator and CombatServer.StatCalculator.Calculate or require(game.ReplicatedStorage.AimRngShared.StatCalculator).Calculate
                local x = st(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
                local z = {}
                for k in pairs(x.Zenith or {}) do table.insert(z, k) end
                return string.format("zen=%s mag=%s cur=%s reload=%s weak=%s body=%s dmg=%s", table.concat(z, ","), tostring(x.MagazineSize), tostring(state.CurrentMag),
                    tostring(x.ReloadSpeed), tostring(x.WeakSpotMultiplier), tostring(x.BodyShotMult), tostring(x.Damage))
            end
            if a == "equip" then
                local it = ItemData.MakeZenith(tostring(b), ItemData.ZenithLevel(state.Level))
                if not it then return "unknown zenith " .. tostring(b) end
                if ItemData.Exotics[b].Kind == "Weapon" then
                    table.insert(state.Inventory, it); state.EquippedWeapon = it; state.IsReloading = false
                else
                    table.insert(state.GearInventory, it); state.EquippedGear[ItemData.GearType(it.Slot)] = it
                end
                CombatServer.RecalculateMaxHealth(state)
                state.CurrentMag = state.MaxMag
                Sync(player, state)
                return "equipped " .. it.Name .. " | " .. Nums()
            elseif a == "drop" then
                local id = tostring(b or "global")
                if id == "global" then id = ItemData.ZENITH_GLOBAL[math.random(1, #ItemData.ZENITH_GLOBAL)]
                elseif id == "pinnacle" then id = ItemData.ZENITH_PINNACLE[math.random(1, #ItemData.ZENITH_PINNACLE)] end
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if root then -- (onto the ground 8 studs ahead, as a kill there would drop it: beam + sound + drop feed)
                    local s0 = state :: any
                    s0._DropAt, s0._DropAtT, s0._DropFan = root.Position + root.CFrame.LookVector * 8, os.clock(), nil
                end
                local it = ZS.Award(player, state, id, "Dev")
                return it and ("dropped " .. it.Name .. " | call=" .. tostring(workspace:GetAttribute("ZenithCall"))) or ("no zenith " .. id)
            elseif a == "apex" then
                local old = workspace:GetAttribute("DevZenithApex")
                workspace:SetAttribute("DevZenithApex", 1)
                local ok, lines = pcall(ZS.Apex, player, state, b == "uber")
                workspace:SetAttribute("DevZenithApex", old)
                return tostring(ok) .. " " .. (type(lines) == "table" and table.concat(lines, ", ") or tostring(lines))
            elseif a == "glass" then
                ZS.GiveTwinGlass(player, state, tonumber(b) or 1)
                Sync(player, state)
                return "TwinGlass=" .. tostring(state.Materials and state.Materials.TwinGlass)
            elseif a == "twin" then
                local uid, kind = b, "Weapon"
                if b == "weapon" or b == nil then uid = state.EquippedWeapon and state.EquippedWeapon.Uid
                elseif b == "gear" then
                    kind = "Gear"
                    for _, g in pairs(state.EquippedGear or {}) do if type(g) == "table" then uid = g.Uid; if ItemData.ZenithOf(g) then break end end end
                elseif b == "bogus" then uid = "W_NOT_AN_ITEM"
                elseif type(b) == "string" and string.sub(b, 1, 2) == "G_" then kind = "Gear" end
                local ok, msg = ZS.Twin(player, state, uid, kind)
                return tostring(ok) .. " " .. tostring(msg) .. " | bag " .. ItemData.BagCount(state) .. "/" .. ItemData.BagCap(state) .. " | glass " .. tostring(state.Materials and state.Materials.TwinGlass)
            elseif a == "craftguard" then
                local uid = tostring(b)
                local isG = string.sub(uid, 1, 2) == "G_"
                local out = {}
                for _, mode in ipairs({ "Reforge", "Retype", "Graft", "Strip", "Temper", "Storm", "Overcharge", "Ascend", "Sockets", "Links", "Colours", "Twin" }) do
                    local ok, msg = CombatServer.ForgeReroll(player, uid, isG and "Gear" or "Weapon", mode)
                    table.insert(out, mode .. "=" .. tostring(ok) .. ":" .. tostring(msg))
                end
                if not isG then
                    local ok, msg = CombatServer.UpgradeWeapon(player, uid); table.insert(out, "Upgrade=" .. tostring(ok) .. ":" .. tostring(msg))
                    for _, act in ipairs({ "Unsocket", "UnsocketAll" }) do
                        local ok2, msg2 = CombatServer.Off.ShotModAct(player, act, uid, 1); table.insert(out, act .. "=" .. tostring(ok2) .. ":" .. tostring(msg2))
                    end
                    local ok3, msg3 = CombatServer.Off.ShotModAct(player, "Socket", "nomod", uid, 1); table.insert(out, "Socket=" .. tostring(ok3) .. ":" .. tostring(msg3))
                    local ok4, msg4 = CombatServer.RiftmodAct(player, "Fit", "nomod", uid); table.insert(out, "Fit=" .. tostring(ok4) .. ":" .. tostring(msg4))
                    local ok5, msg5 = CombatServer.RiftmodAct(player, "Remove", uid); table.insert(out, "Remove=" .. tostring(ok5) .. ":" .. tostring(msg5))
                end
                return table.concat(out, " | ")
            elseif a == "lostloot" then
                state.LostLoot = type(state.LostLoot) == "table" and state.LostLoot or {}
                for _ = 1, tonumber(b) or 1 do
                    local it = c and ItemData.MakeZenith(tostring(c), ItemData.ZenithLevel(state.Level)) or ItemData.GenerateWeaponOfBase("AK47", "Mythic", state.Level or 1)
                    if it then table.insert(state.LostLoot, { Item = it, Kind = (c and ItemData.Exotics[c].Kind == "Gear") and "Gear" or "Weapon", At = os.time() }) end
                end
                CombatServer.TrimLostLoot(state)
                local z, first = 0, nil
                for i, e in ipairs(state.LostLoot) do if ItemData.ZenithOf(e.Item) then z += 1; first = first or i end end
                Sync(player, state)
                return string.format("lost %d (cap %d), zeniths %d, first zenith at %s", #state.LostLoot, CombatServer.LOST_LOOT_MAX, z, tostring(first))
            elseif a == "threadclear" then
                ZS.ThreadClear(player, state)
                return "thread=" .. tostring((state :: any).ZT_N) .. " attr=" .. tostring(player:GetAttribute("ZenThread"))
            elseif a == "level" then
                return string.format("player %s -> zenith ilvl %d (MAX_LEVEL %d)", tostring(state.Level), ItemData.ZenithLevel(state.Level), ItemData.MAX_LEVEL)
            elseif a == "kill" then
                local n, z0, g0 = tonumber(c) or 1000, #state.Inventory + #state.GearInventory, (state.Materials and state.Materials.TwinGlass) or 0
                for _ = 1, n do ZS.KillRoll(player, state, tostring(b or "Mob"), 1, CombatServer.CurrentDifficulty(player, state)) end
                return string.format("%d rolls: items +%d, TwinGlass +%d (live=%s)", n, #state.Inventory + #state.GearInventory - z0, ((state.Materials and state.Materials.TwinGlass) or 0) - g0, tostring(ZS.Live()))
            end
            local s0 = state :: any
            return string.format("%s | ricochets=%s blooms=%s forks=%s lock=%s vent=%s thread=%s misses=%s fray=%s taken=%s live=%s", Nums(), tostring(s0.ZRicochets), tostring(s0.ZBlooms), tostring(s0.ZForks),
                tostring(s0.ZLockUntil and math.max(0, s0.ZLockUntil - os.clock())), tostring(s0.ZVent), tostring(s0.ZT_N), tostring(s0.ZT_Misses),
                tostring(s0.ZT_FrayUntil and math.max(0, s0.ZT_FrayUntil - os.clock())),
                tostring(ZS.TakenMult(state, require(game.ReplicatedStorage.AimRngShared.StatCalculator).Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state))), tostring(ZS.Live()))
        elseif cmd == "exotic" then
            -- Invoke("exotic", id, rarity?, "equip"?) -> that exotic at your level into the stash ("all" = one of each); "equip" wears it
            local ItemData = require(game.ReplicatedStorage.AimRngShared.ItemData)
            local ids = {}
            if a == "all" then for id in pairs(ItemData.Exotics) do table.insert(ids, id) end else ids = { a } end
            local made = {}
            for _, id in ipairs(ids) do
                local item = ItemData.MakeExotic(tostring(id), b or "Legendary", state.Level)
                if item then
                    if ItemData.Exotics[id].Kind == "Weapon" then
                        table.insert(state.Inventory, item)
                        if c == "equip" then state.EquippedWeapon = item; state.CurrentMag = 999 end
                    else
                        table.insert(state.GearInventory, item)
                        if c == "equip" then state.EquippedGear[ItemData.GearType(item.Slot)] = item end
                    end
                    table.insert(made, item.Name)
                end
            end
            Sync(player, state)
            return "relics: " .. table.concat(made, ", ")
        elseif cmd == "gem" then
            -- Invoke("gem", rarity?, uniqueId?) -> a skill-tree gem into the bag
            local GemData = require(game.ReplicatedStorage.AimRngShared.GemData)
            local g = GemData.Generate(a or "Rare", b)
            require(script.Parent:WaitForChild("SkillTreeServer")).GiveGem(player, state, g)
            Sync(player, state)
            return "gem " .. g.Name .. " (" .. g.Rarity .. ") uid " .. g.Uid
        elseif cmd == "tree" then
            -- Invoke("tree", "ID1,ID2,...") -> allocate these nodes directly (no points / connection checks)
            for id in string.gmatch(a or "", "[^,]+") do
                if not table.find(state.AllocatedNodes, id) then table.insert(state.AllocatedNodes, id) end
            end
            Sync(player, state)
            return "nodes " .. #state.AllocatedNodes
        elseif cmd == "passives" then
            -- Invoke("passives", "ID1,ID2,ID3") -> equip these passive skills (allocates them too; no limit checks)
            state.EquippedPassives = {}
            for id in string.gmatch(a or "", "[^,]+") do
                if not table.find(state.AllocatedNodes, id) then table.insert(state.AllocatedNodes, id) end
                table.insert(state.EquippedPassives, id)
            end
            Sync(player, state)
            return "equipped " .. table.concat(state.EquippedPassives, ",")
        elseif cmd == "pity" then
            -- Invoke("pity", "DW=1,IG=0.5,CW=false") -> set TARGET LOOT meters / claimed flags; returns the pity state
            local p = ItemData.PityState(state)
            for k, v in string.gmatch(a or "", "(%w+)=([%w%.]+)") do
                if v == "true" or v == "false" then p[k] = (v == "true") else p[k] = tonumber(v) or v end
            end
            state.Pity = p
            Sync(player, state)
            return game:GetService("HttpService"):JSONEncode(p)
        elseif cmd == "chest" then
            -- Invoke("chest", "Supply" | "Vault" | "Boss", n?) -> open n chests through the real loot code (TARGET LOOT meters too)
            for _ = 1, math.clamp(tonumber(b) or 1, 1, 500) do
                if a == "Supply" then CombatServer.GiveSupplyChestLoot(player) else CombatServer.GiveFloorLoot(player, a == "Boss") end
            end
            return game:GetService("HttpService"):JSONEncode(ItemData.PityState(state)) .. " inv=" .. #state.Inventory .. " gear=" .. #state.GearInventory
        elseif cmd == "socket" then
            -- Invoke("socket", socketId, rarity, uniqueId?) -> generate a gem straight into an (allocated) socket
            local GemData = require(game.ReplicatedStorage.AimRngShared.GemData)
            if not table.find(state.AllocatedNodes, a) then table.insert(state.AllocatedNodes, a) end
            state.SocketedGems[a] = GemData.Generate(b or "Legendary", c)
            Sync(player, state)
            return "socketed " .. state.SocketedGems[a].Name
        elseif cmd == "stats" then
            -- Invoke("stats") -> the compiled stats the server uses (JSON)
            local StatCalculator = require(game.ReplicatedStorage.AimRngShared.StatCalculator)
            local s = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
            local out = {}
            for k, v in pairs(s) do
                if type(v) == "number" or type(v) == "boolean" then out[k] = v end
            end
            out.Mechanics = s.SpecialMechanics
            local cond = {}
            for k, v in pairs(s.Cond or {}) do if v ~= 0 then cond[k] = v end end
            out.Cond = cond
            return game:GetService("HttpService"):JSONEncode(out)
        elseif cmd == "contentcheck" then -- (FUTURE-PROOF: every content registry, AimRngShared/ContentCheck)
            return require(game.ReplicatedStorage.AimRngShared.ContentCheck).Report()
        elseif cmd == "partyrun" then
            -- a server-run PARTY dungeon with just this player (tests the multiplayer path solo)
            local PartyRuns = require(script.Parent:WaitForChild("PartyRuns"))
            -- ["partyrun", skill, biome, diff, floor]: a floor number jumps straight to it (with that biome fixed: boss floors)
            local ov = tonumber(d) and { FloorNumber = tonumber(d), FixedBiome = b } or nil
            -- (ENEMY ATTACKS PILOT 2026-10-30: leave a party run you're still in first -- a second partyrun used to leave the first
            -- one's floor alive with you as a member, its bots shooting at you on every later floor)
            if PartyRuns.RunOfPlayer(player) then PartyRuns.RemoveMember(player) end
            local run = PartyRuns.Start({ Members = { player }, Biome = b or "Fire", Difficulty = c or "Easy", BotSkill = a or 4 }, ov)
            return run and ("party run " .. run.Id) or "failed"
        elseif cmd == "partytrial" then
            -- a server-run PARTY trial with just this player: ["partytrial","Archon",1] (Boss Trial) or ["partytrial","Asc",1]
            -- (Trial of Ascension); n = the pretend party size for the boss's health (4th arg, default 1)
            local PartyRuns = require(script.Parent:WaitForChild("PartyRuns"))
            local BT = require(game.ReplicatedStorage.AimRngShared.BossTrials)
            local AT = require(game.ReplicatedStorage.AimRngShared.AscensionTrials)
            local tier = math.max(1, tonumber(b) or 1)
            local ov
            if tostring(a) == "Asc" then
                ov = { AscTrial = { Tier = tier }, Difficulty = AT.Tiers[tier].Difficulty, FloorNumber = 1, BotSkill = 5 }
            else
                local def = BT.ById[tostring(a)]
                if not def then return "unknown boss" end
                ov = { BossTrial = { Id = def.Id, Tier = tier }, Difficulty = BT.Tiers[tier].Difficulty, FloorNumber = BT.FLOOR, Biome = def.Biome, FixedBiome = def.Biome, BotSkill = 5 }
            end
            ov.BossHealthScale = tonumber(c) or 1
            if PartyRuns.RunOfPlayer(player) then PartyRuns.RemoveMember(player) end -- (leave the party run you're in first)
            local run = PartyRuns.Start({ Members = { player }, Biome = "Fire", Difficulty = ov.Difficulty, BotSkill = 5 }, ov)
            return run and ("party trial " .. run.Id .. " floor " .. run.Config.FloorNumber) or "failed"
        elseif cmd == "partyportal" then
            -- walk through your party floor's next-floor portal (tooling can't press ProximityPrompts)
            local DG = require(game.ReplicatedStorage.AimRngShared.DungeonGenerator)
            local f = workspace.PartyRuns:FindFirstChild("Run_" .. tostring(player:GetAttribute("RunId")))
            local prompt = f and f:FindFirstChild("PromptPortal", true)
            if not prompt or not DG.ServerPortalHandler then return "no portal" end
            DG.ServerPortalHandler(player, prompt.Parent)
            return "through -> " .. tostring(player:GetAttribute("RunId"))
        elseif cmd == "mats" then
            -- n of every material and crafting currency
            for _, k in ipairs(ItemData.MaterialOrder) do
                state.Materials = state.Materials or ItemData.NewMaterials()
                state.Materials[k] = (state.Materials[k] or 0) + (a or 100)
            end
        elseif cmd == "titleprog" then -- Invoke("titleprog", "RuinClear"): that title's real progress + its requirement text
            local ok, cur, need = ItemData.TitleProgress(tostring(a), state)
            local t = ItemData.Titles[tostring(a)]
            return string.format("%s %s %d/%d  •  %s  •  TitleFloors %s", tostring(a), tostring(ok), cur, need, t and t.Requirement or "?",
                game:GetService("HttpService"):JSONEncode(state.StatsTracking.TitleFloors or {}))
        elseif cmd == "codex" then -- Invoke("codex", "all" | "Id1,Id2"): unlock Codex of Power entries (Forge imprint tests)
            state.Codex = type(state.Codex) == "table" and state.Codex or {}
            for _, t in ipairs(ItemData.UniqueTraitsCatalog) do
                if a == "all" or string.find("," .. tostring(a) .. ",", "," .. t.Id .. ",", 1, true) then state.Codex[t.Id] = true end
            end
        elseif cmd == "boons" then -- Invoke("boons", "IGNITE,CRYO", "SERRATED,VAMPIRIC,KEEN"?): hold these boons (+ an offer of 3)
            state.RunBoons = {}
            for id in string.gmatch(a or "", "[^,]+") do table.insert(state.RunBoons, id) end
            state.BoonOffer = nil
            if type(b) == "string" then
                state.BoonOffer = {}
                for id in string.gmatch(b, "[^,]+") do table.insert(state.BoonOffer, id) end
            end
            CombatServer.RecalculateMaxHealth(state)
            Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
            return "boons " .. #state.RunBoons
        elseif cmd == "aimfake" then -- (2026-10-20 AIM PROFILE) ["aimfake", n] sample runs in your aim log
            return require(script.Parent:WaitForChild("ProfileService")).Dev(player, cmd, a)
        elseif string.sub(cmd, 1, 5) == "refer" then -- (2026-10-20 FRIEND INVITES) refer / referskip / referdays / referplay / referdone / refercheck
            return require(script.Parent:WaitForChild("ReferralService")).Dev(player, cmd, a, b)
        elseif cmd == "pffake" or cmd == "pfarrive" or cmd == "pfroom" or cmd == "pfboard" then -- (2026-10-20 PARTY FINDER) ["pffake", n] fake listings from other servers; ["pfarrive", roomId] = arriving through it
            return require(script.Parent:WaitForChild("PartyFinder")).Dev(player, cmd, a)
        elseif cmd == "maprefund" then -- (QOL2 R5) ("maprefund", "leave" | "join" | "state"): run the leave hook / the join return on
            -- your live state as a quit + rejoin would (Studio can't rejoin with the same save); returns the refund fields + map count
            local MR = require(script.Parent:WaitForChild("MapRefund"))
            if a == "leave" then MR.OnLeave(player, state) elseif a == "join" then MR.OnJoin(player, state) end
            local function U(s) return type(s) == "table" and tostring(s.Uid) .. " T" .. tostring(s.Tier) or "nil" end
            return string.format("live=%s pending=%s maps=%d", U(state._MapRefund), U(state.PendingMapRefund), #(state.Sigils or {}))
        elseif cmd == "aimlog" then -- (QOL2 R3) Invoke("aimlog", n, acc, weak, dps): n fake AIM PROFILE run-log entries (100 shots each)
            -- -> the RUN SUMMARY's "vs avg" lines; ("aimlog", 0) clears the log
            local n = math.clamp(tonumber(a) or 5, 0, 20)
            state.AimLog = {}
            for _ = 1, n do
                table.insert(state.AimLog, { G = "G19", S = 100, H = math.round(100 * (tonumber(b) or 0.5)), P = 100, W = math.round(100 * (tonumber(c) or 0.3)),
                    K = 10, T = 300, O = "VICTORY", At = os.time(), Dm = math.round(60 * (tonumber(d) or 100)), Ct = 60 })
            end
            return string.format("aimlog %d -> avg %s", n, table.concat({ CombatServer.RS.Averages(state) }, " "))
        elseif cmd == "socketguns" then
            -- (2026-11-09 SOCKETS) ["socketguns", "R|R-G|R-G-B B|...", fill?, rarity?] = one gun per socket string into the bag (the bag
            -- tiles' socket dots); fill = "mods" puts a shot mod into socket 1 (+ 3) of each (a filled socket = an off-white ring)
            local SMod = require(game.ReplicatedStorage.AimRngShared.ShotMods)
            local bases = { "AK47", "MP5", "M40", "KSG", "AUG", "P226", "SCAR", "M60" }
            local n = 0
            for spec in string.gmatch(tostring(a or "R|R-G|R-G-B B|R-R-G-G-B-B|G B R-B|B-B-B-B-B"), "[^|]+") do
                n += 1
                local w = ItemData.GenerateWeaponOfBase(bases[((n - 1) % #bases) + 1], tostring(c or "Rare"), math.max(state.Level or 1, 60))
                if w then
                    w.Sockets = spec
                    w.SocketMods = {}
                    if b == "mods" then
                        w.SocketMods["1"] = SMod.New("Overcharge", 1)
                        if #ItemData.ParseSockets(spec) >= 3 then w.SocketMods["3"] = SMod.New("Rapid", 1) end
                    end
                    table.insert(state.Inventory, 1, w)
                end
            end
            Sync(player, state)
            return "added " .. n .. " guns"
        elseif cmd == "autoselltest" then
            -- (2026-11-09 AUTO-SELL FILTER) ["autoselltest", rulesJSON | "" (= the preset), threshold ("Uncommon"), "keep"?] = a fixed set of
            -- items (sockets / links / item level / types / stat tiers / a relic) through the REAL drop path (CombatServer.DropToGround ->
            -- TryAutoSell) with those settings; returns each item's fate (SOLD = gold went up + not on the ground, KEPT = on the ground)
            -- vs what AutoSellRules.Decide says. Your old settings come back unless arg 3 = "keep". The kept items stay on the ground.
            local AR = require(game.ReplicatedStorage.AimRngShared.AutoSellRules)
            local HS = game:GetService("HttpService")
            local rules
            if type(a) == "string" and a ~= "" then
                local okJ, t = pcall(HS.JSONDecode, HS, a)
                rules = okJ and t or nil
            elseif type(a) == "table" then rules = a end
            rules = rules or { MinSockets = 4, MinLinks = 3, MinIlvl = 150, Types = { "Shotgun", "Gear:Ring" }, Stats = { { S = "CritChance", T = 4 } }, StatCount = 1 }
            local oldT, oldR = state.AutoSellThreshold, state.AutoSellRules
            state.AutoSellThreshold = tostring(b or "Uncommon")
            state.AutoSellRules = AR.Clean(rules)
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local lvl = 60
            local function Gun(base, rar, sockets, ilvl, suf)
                local w = ItemData.GenerateWeaponOfBase(base, rar, ilvl or lvl)
                w.Sockets, w.Prefixes, w.Suffixes, w.UniqueTrait = sockets, {}, suf or {}, nil
                return w, "Weapon"
            end
            local function Gear(slot, rar, stat)
                local g = ItemData.GenerateRandomGear(slot, rar, 1, lvl)
                g.StatLines = { { Stat = stat or "MaxHP", Name = stat or "MaxHP", Value = 10, Tier = 2 } }
                return g, "Gear"
            end
            local cases = {
                { "Common AK, 1 socket", function() return Gun("AK47", "Common", "R") end },
                { "Common AK, 4 sockets unlinked", function() return Gun("AK47", "Common", "R G B B") end },
                { "Uncommon MP5, 3-link", function() return Gun("MP5", "Uncommon", "R-G-B") end },
                { "Uncommon MP5, 2-link + 1", function() return Gun("MP5", "Uncommon", "R-G B") end },
                { "Rare AK, 1 socket (above rarity)", function() return Gun("AK47", "Rare", "R") end },
                { "Common KSG shotgun", function() return Gun("KSG", "Common", "G") end },
                { "Common AK, Crit Chance T5", function() return Gun("AK47", "Common", "B", nil, { { Id = "CritChance", Name = "Keen", Stat = "CritChance", Value = 0.02, Tier = 5 } }) end },
                { "Common AK, Crit Chance T1", function() return Gun("AK47", "Common", "B", nil, { { Id = "CritChance", Name = "Keen", Stat = "CritChance", Value = 0.01, Tier = 1 } }) end },
                { "Common AK, item level 160", function() return Gun("AK47", "Common", "R", 160) end },
                { "Common Helmet, life line", function() return Gear("Helmet", "Common") end },
                { "Uncommon Ring", function() return Gear("Ring", "Uncommon") end },
                { "Common Gloves, Crit Chance T2", function() return Gear("Gloves", "Common", "CritChance") end },
            }
            local out, okAll = {}, true
            for i, cs in ipairs(cases) do
                local item, kind = cs[2]()
                local want, why = AR.Decide(state.AutoSellThreshold, state.AutoSellRules, item, kind)
                local g0 = state.Gold
                local got
                if root then
                    local look = root.CFrame.LookVector
                    local side = root.CFrame.RightVector * ((i - 6.5) * 3)
                    CombatServer.DropToGround(player, state, item, kind, root.Position + look * 14 + side - Vector3.new(0, 2.5, 0))
                    local onGround = false
                    for _, d in pairs(state.PendingLoot or {}) do if type(d) == "table" and d.Item == item then onGround = true end end
                    got = (not onGround and state.Gold > g0) and "SOLD" or (onGround and "KEPT" or "?")
                else
                    got = "no character"
                end
                local exp = want and "SOLD" or "KEPT"
                if got ~= exp then okAll = false end
                table.insert(out, string.format("%s => %s (%s)%s", cs[1], got, why, got == exp and "" or (" EXPECTED " .. exp)))
            end
            if c ~= "keep" then state.AutoSellThreshold, state.AutoSellRules = oldT, oldR end
            Sync(player, state)
            return (okAll and "ALL MATCH" or "MISMATCH") .. " | " .. table.concat(out, " | ")
        elseif cmd == "field" then -- Invoke("field", name): one save field of your state as JSON (2026-10-20: the wipe carry check)
            local okJ, js = pcall(function() return game:GetService("HttpService"):JSONEncode(state[tostring(a)]) end)
            return tostring(a) .. " = " .. (okJ and js or tostring(state[tostring(a)]))
        elseif cmd == "expertise" then
            -- (2026-10-22) Invoke("expertise") = picks / points / Unwinds / gold; ("expertise", "Pick", nodeId, effectId) |
            -- ("expertise", "Refund", nodeId) = the real ExpertiseAction path
            local STS = require(script.Parent:WaitForChild("SkillTreeServer"))
            local msg = ""
            if a then local ok, m = STS.ExpertiseAct(player, a, b, c); msg = tostring(ok) .. " " .. tostring(m) .. " | " end
            return msg .. game:GetService("HttpService"):JSONEncode({ Expertise = state.Expertise or {}, SP = state.SkillPoints, Unwind = (state.Materials or {}).Unwind or 0, Gold = state.Gold, Nodes = #state.AllocatedNodes })
        elseif cmd == "refundnode" then -- (2026-10-22) Invoke("refundnode", id) / ("refundnode", "ALL") = the real refund / respec path
            local STS = require(script.Parent:WaitForChild("SkillTreeServer"))
            local ok, m
            if a == "ALL" then ok, m = STS.Respec(player) else ok, m = STS.RefundNode(player, a) end
            return tostring(ok) .. " " .. tostring(m) .. " | SP " .. tostring(state.SkillPoints) .. " gold " .. tostring(state.Gold) .. " unwind " .. tostring((state.Materials or {}).Unwind or 0)
        elseif cmd == "treepath" then
            -- (2026-10-22) Invoke("treepath", nodeId): allocate the shortest path from your tree to it through the real Allocate
            local STS = require(script.Parent:WaitForChild("SkillTreeServer"))
            local SkillTreeData = require(game.ReplicatedStorage.AimRngShared.SkillTreeData)
            local have = {}
            for _, id in ipairs(state.AllocatedNodes) do have[id] = true end
            local prev, queue, head, found = { [a] = a }, { a }, 1, nil
            while head <= #queue and not found do
                local cur = queue[head]; head += 1
                for _, nb in ipairs((SkillTreeData[cur] or {}).Connections or {}) do
                    if have[nb] then found = cur break end
                    if prev[nb] == nil and SkillTreeData[nb] and SkillTreeData[nb].Type ~= "ClassStart" then prev[nb] = cur; table.insert(queue, nb) end
                end
            end
            if not found then return "no path to " .. tostring(a) end
            local n, x, last = 0, found, ""
            while true do
                local ok, m = STS.Allocate(player, x)
                if not ok then return "stopped at " .. x .. ": " .. tostring(m) end
                n += 1; last = m
                if x == a then break end
                x = prev[x]
            end
            return string.format("allocated %d nodes (%s) | SP %d", n, last, state.SkillPoints)
        elseif cmd == "treeversion" then -- Invoke("treeversion", n): pretend the save's tree is version n (then "rejoin" = the refund path)
            state.TreeVersion = tonumber(a) or 1
            return "TreeVersion " .. tostring(state.TreeVersion)
        elseif cmd == "menu" then -- Invoke("menu", "Dungeons" / "Season" / ...): open a hub menu as its station would
            Remotes.GetEvent("OpenMenu"):FireClient(player, a, b, c) -- (["menu", "CosmeticShop", cat, id]: the store on that item)
            return "opened " .. tostring(a)
        elseif cmd == "upgrade" then -- (LOOT SCARCITY 2026-11-07) ["upgrade"] = the Forge's UPGRADE on your gun (the real path: costs, item-level cap)
            local w = state.EquippedWeapon
            if not w then return "no gun" end
            local ok, msg = CombatServer.UpgradeWeapon(player, w.Uid)
            return tostring(ok) .. ": " .. tostring(msg) .. " | +" .. tostring(w.UpgradeLevel or 0) .. " ilvl " .. tostring(w.ItemLevel or 1)
        elseif cmd == "econrun" then
            -- (LOOT SCARCITY 2026-11-07) ["econrun", diff, runs?, level?]: whole runs (floors 1..MaxWaves, linked floors step 2) through the
            -- REAL kill / chest / objective / encounter code: every floor's rooms spawned + killed, its objective done 60% of the time, its
            -- encounter paid (clean 40%), the vault + side cache opened. Returns JSON: items by rarity, kills by kind, gems, every
            -- material gained, gold, shot mods, floors. Not counted: dungeon events, the hub, the daily roll / contracts.
            local DungeonRuns = require(script.Parent:WaitForChild("DungeonRuns"))
            local LinkedRooms = require(game.ReplicatedStorage.AimRngShared.LinkedRooms)
            local diff = type(a) == "string" and a or "Easy"
            local nRuns = math.clamp(tonumber(b) or 1, 1, 10)
            if tonumber(c) then Run(player, "setlevel", tonumber(c)) end
            local maxW = (ItemData.DifficultyModes[diff] and ItemData.DifficultyModes[diff].MaxWaves) or 6
            player:SetAttribute("DevNoDeath", true)
            local E = { Items = {}, Kills = {}, Gems = {}, Enc = {}, Floors = 0, Obj = 0 }
            ;(state :: any)._Econ = E
            local m0 = table.clone(state.Materials or {})
            local g0, sm0, t0 = state.Gold, #((state :: any).ShotMods or {}), os.clock()
            for _ = 1, nRuns do
                local f = 1
                while f <= maxW do
                    Run(player, "floor", f, nil, diff)
                    task.wait(1.2)
                    local run = DungeonRuns.Get(player) :: any
                    if not run then break end
                    pcall(DungeonRuns.LinkedDev, player, "spawnall")
                    for _ = 1, 120 do
                        Run(player, "killall")
                        task.wait(0.3)
                        if run.Folder:GetAttribute("FloorCleared") then break end
                    end
                    if run.Objective and run.Objective.State == "" and math.random() < 0.6 then
                        run.Objective.Deadline = 0; DungeonRuns.CompleteObjective(player); E.Obj += 1
                    end
                    if run.Encounter then
                        E.Enc[run.Encounter.Id] = (E.Enc[run.Encounter.Id] or 0) + 1
                        CombatServer.EncounterReward(player, run.Encounter.Id, { Clean = math.random() < 0.4, Kills = math.random(8, 24) })
                        run.Encounter = nil
                    end
                    CombatServer.GiveFloorLoot(player, ItemData.IsBossConfig(run.Config) or f >= maxW)
                    if run.Linked and run.Linked.L and run.Linked.L.Side then CombatServer.GiveFloorLoot(player, false) end
                    E.Floors += 1
                    f += (run.Config.Linked and LinkedRooms.FLOOR_STEP) or 1
                end
            end
            ;(state :: any)._Econ = nil
            local mats = {}
            for k, v in pairs(state.Materials or {}) do if v ~= (m0[k] or 0) then mats[k] = v - (m0[k] or 0) end end
            E.Mats, E.Gold, E.ShotMods, E.Secs = mats, state.Gold - g0, #((state :: any).ShotMods or {}) - sm0, math.round(os.clock() - t0)
            E.Diff, E.Runs, E.Level = diff, nRuns, state.Level
            return game:GetService("HttpService"):JSONEncode(E)
        elseif cmd == "killall" then -- Invoke("killall"): kill every enemy on your current solo floor (through the real kill pipeline)
            local DungeonRuns = require(script.Parent:WaitForChild("DungeonRuns"))
            local StatCalculator = require(game.ReplicatedStorage.AimRngShared.StatCalculator)
            local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
            local n = 0
            -- (UPDATE 8: ["killall", "adds", n] = only non-bosses, at most n -- pack waves on a mini-boss floor)
            for _, proxy in ipairs(DungeonRuns.EnemiesOf(player)) do
                local skip = a == "adds" and (proxy:GetAttribute("IsBoss") or n >= (tonumber(b) or math.huge))
                if a == "cmd" then skip = not require(game.ReplicatedStorage.AimRngShared.DungeonGenerator).HasEliteMod(proxy:GetAttribute("EliteMods"), "Commander") end -- (["killall", "cmd"] = Commander elites only)
                if a == "room" then skip = proxy:GetAttribute("LinkRoom") ~= tonumber(b) end -- (["killall", "room", n] = one linked room)
                if not skip and CombatServer.DealEnemyDamage then CombatServer.DealEnemyDamage(player, state, proxy, 1e12, stats, { NoTakenMult = true }); n += 1 end
            end
            -- party floors (server-built enemies in the run folder) too
            local prun = require(script.Parent:WaitForChild("PartyRuns")).RunOfPlayer(player)
            if prun and prun.Folder then
                for _, m in ipairs(prun.Folder:GetChildren()) do
                    local only = a ~= "cmd" or require(game.ReplicatedStorage.AimRngShared.DungeonGenerator).HasEliteMod(m:GetAttribute("EliteMods"), "Commander")
                    if a == "room" then only = m:GetAttribute("LinkRoom") == tonumber(b) end
                    if only and m:IsA("Model") and m:GetAttribute("Health") and (m:GetAttribute("Health") or 0) > 0 and CombatServer.DealEnemyDamage then
                        CombatServer.DealEnemyDamage(player, state, m, 1e12, stats, { NoTakenMult = true }); n += 1
                    end
                end
            end
            return "killed " .. n
        elseif cmd == "bossdps" then
            -- (0.99u BOSS PACE probe) ["bossdps", dps, maxSeconds?]: a steady DPS into this run's boss through the real damage
            -- pipeline (its DamageTakenMult counts: aim-round guard, stagger), 10 ticks a second, and time the kill. Returns at
            -- once; when it ends ServerStorage gets attrs BossDpsT (seconds), BossDpsHp (max health), BossDpsName,
            -- BossDpsTaken (average taken multiplier), BossDpsDone = true.
            local DungeonRuns = require(script.Parent:WaitForChild("DungeonRuns"))
            local StatCalculator = require(game.ReplicatedStorage.AimRngShared.StatCalculator)
            local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
            local dps, limit = tonumber(a) or 1000, tonumber(b) or 600
            local boss = nil
            local list = DungeonRuns.EnemiesOf(player)
            local prun = require(script.Parent:WaitForChild("PartyRuns")).RunOfPlayer(player)
            if prun and prun.Folder then for _, m in ipairs(prun.Folder:GetChildren()) do table.insert(list, m) end end
            for _, m in ipairs(list) do if m:GetAttribute("IsBoss") and not m:GetAttribute("Dead") then boss = m break end end
            if not boss then return "no boss" end
            for _, k in ipairs({ "BossDpsT", "BossDpsHp", "BossDpsName", "BossDpsTaken", "BossDpsDone" }) do ServerStorage:SetAttribute(k, nil) end
            local maxHp = boss:GetAttribute("MaxHealth") or 0
            task.spawn(function()
                local t0, sumTaken, n = os.clock(), 0, 0
                while boss.Parent and not boss:GetAttribute("Dead") and (boss:GetAttribute("Health") or 0) > 0 and os.clock() - t0 < limit do
                    sumTaken += (boss:GetAttribute("DamageTakenMult") or 1); n += 1
                    CombatServer.DealEnemyDamage(player, state, boss, dps * 0.1, stats, { Show = false })
                    task.wait(0.1)
                end
                ServerStorage:SetAttribute("BossDpsT", math.round((os.clock() - t0) * 10) / 10)
                ServerStorage:SetAttribute("BossDpsHp", maxHp)
                ServerStorage:SetAttribute("BossDpsName", tostring(boss:GetAttribute("ModelName") or boss.Name))
                ServerStorage:SetAttribute("BossDpsTaken", math.round(sumTaken / math.max(1, n) * 100) / 100)
                ServerStorage:SetAttribute("BossDpsDone", true)
            end)
            return string.format("hitting %s (%d hp) at %d dps", tostring(boss:GetAttribute("ModelName") or boss.Name), maxHp, dps)
        elseif cmd == "runstats" then -- Invoke("runstats"): this run's RUN SUMMARY record so far (RunStats); ("runstats", "Shots=100,Hits=60,...")
            -- sets fields of the live record first (QOL2 R3 "vs avg" tests)
            local r = CombatServer.RS.Get(player)
            if not r then return "no run record" end
            for k, v in string.gmatch(tostring(a or ""), "(%w+)=([%-%d%.]+)") do r[k] = tonumber(v) end
            return string.format("shots=%d hits=%d pellets=%d weak=%d crits=%d dmg=%.0f kills=%d elites=%d bosses=%d taken=%.0f deaths=%d floors=%d items=%d",
                r.Shots, r.Hits, r.PelletHits, r.Weak, r.Crits, r.Damage, r.Kills, r.Elites, r.Bosses, r.Taken, r.Deaths, r.Floors, r.Items)
        elseif cmd == "hub" then -- Invoke("hub"): leave the run the way the hub teleport does (sends the RUN SUMMARY)
            local DungeonRuns = require(script.Parent:WaitForChild("DungeonRuns"))
            local PartyRuns = require(script.Parent:WaitForChild("PartyRuns"))
            DungeonRuns.EndRun(player)
            PartyRuns.RemoveMember(player)
            return "left the run"
        elseif cmd == "bosstrial" then -- Invoke("bosstrial", "Archon" | "Chronarch" | "EchoWarden" | "Forgeheart", tier): start a Boss Trial
            local BossTrials = require(game.ReplicatedStorage.AimRngShared.BossTrials)
            local def = BossTrials.ById[tostring(a)]
            if not def then return "unknown boss" end
            local tier = math.clamp(tonumber(b) or 1, 1, BossTrials.MAX_TIER)
            local t = BossTrials.Tiers[tier]
            local DungeonRuns = require(script.Parent:WaitForChild("DungeonRuns"))
            if DungeonRuns.Get(player) then DungeonRuns.EndRun(player) end
            state.DungeonDifficulty = t.Difficulty
            DungeonRuns.StartFloor(player, { Biome = def.Biome, Difficulty = t.Difficulty, FloorNumber = BossTrials.FLOOR, PlayerLevel = state.Level, BotSkill = 5,
                BossTrial = { Id = def.Id, Tier = tier } })
            Remotes.GetEvent("DungeonUpdate"):FireClient(player, { Biome = def.Biome, Difficulty = t.Difficulty, Floor = BossTrials.FLOOR, Remaining = 1, Trial = def.Name .. "  TIER " .. t.Name })
            return "started " .. def.Id .. " tier " .. tier
        elseif cmd == "asctrial" then -- Invoke("asctrial", tier[, floor]): start the Trial of Ascension (floor 3 = straight to The Ascendant)
            local AT = require(game.ReplicatedStorage.AimRngShared.AscensionTrials)
            local tier = math.clamp(tonumber(a) or 1, 1, AT.MAX_TIER)
            local def = AT.Tiers[tier]
            local DungeonRuns = require(script.Parent:WaitForChild("DungeonRuns"))
            if DungeonRuns.Get(player) then DungeonRuns.EndRun(player) end
            state.DungeonDifficulty = def.Difficulty
            DungeonRuns.StartFloor(player, { Biome = "Fire", Difficulty = def.Difficulty, FloorNumber = 1, PlayerLevel = state.Level, BotSkill = 5, AscTrial = { Tier = tier } })
            local f = math.clamp(tonumber(b) or 1, 1, AT.FLOORS)
            if f > 1 then DungeonRuns.StartFloor(player, { Biome = "Fire", Difficulty = def.Difficulty, FloorNumber = f, PlayerLevel = state.Level, BotSkill = 5 }) end
            Remotes.GetEvent("DungeonUpdate"):FireClient(player, { Biome = "Fire", Difficulty = def.Difficulty, Floor = f, Remaining = DungeonRuns.Attr(player, "RemainingEnemies") or 0, Trial = "THE PROVING " .. def.Name })
            return "started Proving " .. tier .. " floor " .. f
        elseif cmd == "ascbest" then -- Invoke("ascbest", n): set your Trial of Ascension progress (ascendancy points = 2 x n)
            state.AscTrialBest = math.clamp(tonumber(a) or 0, 0, 4)
            Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
            return "AscTrialBest " .. state.AscTrialBest
        elseif cmd == "roster" then -- Invoke("roster", "Pasu,Orbiter"): force these archetypes on the next floors ("" = normal)
            local DG = require(game.ReplicatedStorage.AimRngShared.DungeonGenerator)
            local list = {}
            for _, n in ipairs(string.split(tostring(a or ""), ",")) do if DG.BotArchetypes[n] then table.insert(list, n) end end
            DG.ForceArchetypes = (#list > 0) and list or nil
            return "roster " .. table.concat(list, ",")
        elseif cmd == "cosmetic" then -- Invoke("cosmetic", "HeadGear:EmberCrown"): own + equip any cosmetic (Cosmetics catalog)
            local cat, id = string.match(tostring(a), "^(%w+):(%w+)$")
            if not cat or not CombatServer.GrantCosmetic(player, state, cat, id, true) then return "unknown cosmetic " .. tostring(a) end
            return "granted " .. tostring(a)
        elseif cmd == "skinbench" then
            -- Invoke("skinbench", "FerrofluxAK47,Gun:AK47,/,Melee:Ferroflux", scale?, stJson?, forView?): premium skins laid out
            -- on a backdrop at (0, 800, 0), +Z = toward the camera spot; stJson = a SkinFX state to pose them in
            -- (e.g. {"Eclipse":1,"Charge":1}); returns each model's centre. ("" clears the bench.)
            -- "Gun:<id>" = that gun with no skin (to compare a skin with the plain gun); "/" starts a new column to the right.
            local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
            local SkinFXB = require(Shared:WaitForChild("SkinFX"))
            local VR = require(Shared:WaitForChild("ViewmodelRig"))
            local WR = require(Shared:WaitForChild("WeaponRigs"))
            local MD = require(Shared:WaitForChild("MeleeData"))
            local old = workspace:FindFirstChild("ZZ_SkinBench"); if old then old:Destroy() end
            if tostring(a or "") == "" then return "bench cleared" end
            local bench = Instance.new("Folder"); bench.Name = "ZZ_SkinBench"; bench.Parent = workspace
            local base = CFrame.new(0, 800, 0)
            local bg = Instance.new("Part"); bg.Anchored = true; bg.Size = Vector3.new(80, 50, 1); bg.CFrame = base * CFrame.new(0, 0, -4)
            bg.Color = Color3.fromRGB(58, 62, 70); bg.Material = Enum.Material.SmoothPlastic; bg.Parent = bench
            local floor = bg:Clone(); floor.Size = Vector3.new(80, 1, 30); floor.CFrame = base * CFrame.new(0, -6, 6); floor.Parent = bench
            local st = {}
            if type(c) == "string" and c ~= "" then
                local ok, t = pcall(function() return game:GetService("HttpService"):JSONDecode(c) end)
                if ok and type(t) == "table" then st = t end
            end
            st.Now = st.Now or os.clock(); st.Flash = st.Flash or 1; st.SinceEquip = st.SinceEquip or 99
            local scale = tonumber(b) or 3
            local out, x, y = {}, 0, 4
            for _, id in ipairs(string.split(tostring(a), ",")) do
                local model, skin, def
                local mid = id:match("^Melee:(.+)$")
                local gid = id:match("^Gun:(.+)$")
                if id == "/" then
                    x += 6 * scale; y = 4
                elseif gid then
                    def = WR.Guns[gid]
                elseif mid then
                    skin = MD.Skins[mid]
                    def = skin and MD.Rigs[skin.RigId or ""]
                else
                    skin = SkinFXB.GunSkinById[id]
                    def = skin and WR.Guns[skin.Gun]
                end
                if def then model = VR.ModelFor(def, skin, d == true or d == "true") end
                if model then
                    model.Name = id
                    model.Parent = bench
                    local frame = model:FindFirstChild("Frame")
                    for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true end end
                    if frame then
                        -- pose the skin's animated parts in `st`
                        local fcf = frame.CFrame
                        for _, p in ipairs(model:GetDescendants()) do
                            if p:IsA("BasePart") and p:GetAttribute("SkinDeco") then
                                local rest = fcf:ToObjectSpace(p.CFrame)
                                local an = SkinFXB.AnimRecord(p, rest, p.Size)
                                if an then
                                    local off, tr, col = SkinFXB.AnimOffset(an, st.Now, st)
                                    p.CFrame = fcf * off * rest
                                    if tr then p.Transparency = tr end
                                    if col then p.Color = col end
                                end
                            end
                        end
                        model.PrimaryPart = frame
                        model:PivotTo(base * CFrame.new(x, y, 0))
                        model:ScaleTo(model:GetScale() * scale)
                        local cf, size = model:GetBoundingBox()
                        table.insert(out, string.format("%s @ %.1f,%.1f,%.1f size %.1f,%.1f,%.1f", id, cf.X, cf.Y, cf.Z, size.X, size.Y, size.Z))
                        y -= size.Y + 1
                    end
                elseif id ~= "/" then
                    table.insert(out, id .. " ?")
                end
            end
            return table.concat(out, " | ")
        elseif cmd == "barstyle" then -- Invoke("barstyle", id): own + equip a health bar cosmetic ("Standard" = back to default)
            if not CombatServer.GrantBarStyle(player, state, tostring(a), true) then return "unknown style " .. tostring(a) end
            return "equipped " .. tostring(a)
        elseif cmd == "heal" then
            state.Health = state.MaxHealth
        elseif cmd == "hurt" then -- Invoke("hurt", dmg, src?, type?): real damage through DamagePlayer (lives / death tests; src = the
            -- DEATH RECAP name, QOL2 R1)
            local wasSafe = player:GetAttribute("SafeLocked")
            player:SetAttribute("SafeLocked", true) -- (the entry room would block it)
            CombatServer.DamagePlayer(player, tonumber(a) or 99999, c and tostring(c) or nil, nil, nil, nil, nil, b and tostring(b) or "Test hit")
            player:SetAttribute("SafeLocked", wasSafe)
        elseif cmd == "defgear" then -- (UPDATE 8 DEFENCE) ["defgear", "Ward=500,Agility=1e6,HeatResist=0.3" | "clear"]: a hidden
            -- test piece (EquippedGear.DevDef) carrying these stat lines; returns the defence summary (defstats)
            state.EquippedGear = state.EquippedGear or {}
            if a == "clear" or a == nil then
                state.EquippedGear.DevDef = nil
            else
                local lines = {}
                for k, v in string.gmatch(tostring(a), "(%w+)=([%-%d%.e]+)") do table.insert(lines, { Stat = k, Name = k, Value = tonumber(v) or 0 }) end
                state.EquippedGear.DevDef = { Uid = "G_DEVDEF", Slot = "Ring", Name = "Dev Defence", Rarity = "Common", ItemLevel = 1, Armor = 0, StatLines = lines }
            end
            Sync(player, state)
            return Run(player, "defstats")
        elseif cmd == "geartest" then -- (UPDATE 8 GEAR v3) ["geartest", slot, rarity, baseId?]: a fresh v3 piece EQUIPPED in that slot
            -- (Gloves / Helmet / ChestPiece / Leggings / Boots / Necklace / Ring1 / Ring2); the old piece goes to the stash.
            -- Returns its card (DescribeGear) + the defence summary.
            local IDm = require(game.ReplicatedStorage.AimRngShared.ItemData)
            local slot = tostring(a or "Gloves")
            local g = IDm.GenerateGearV3(IDm.GearType(slot), IDm.NormRarity(b) or "Rare", state.Level or 1, c)
            state.EquippedGear = state.EquippedGear or {}
            if state.EquippedGear[slot] then table.insert(state.GearInventory, state.EquippedGear[slot]) end
            state.EquippedGear[slot] = g
            Sync(player, state)
            local d = IDm.DescribeGear(g)
            local t = { d.Title, d.Subtitle }
            for _, l in ipairs(d.Lines) do table.insert(t, l.Text) end
            return table.concat(t, " / ") .. " || " .. Run(player, "defstats")
        elseif cmd == "defstats" then -- (UPDATE 8 DEFENCE) the defence numbers at the current difficulty
            local SC = require(game.ReplicatedStorage.AimRngShared.StatCalculator)
            local s = SC.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
            local diff = CombatServer.CurrentDifficulty(player, state)
            local r = {}
            for _, t in ipairs({ "Heat", "Cryo", "Volt", "Void" }) do table.insert(r, string.format("%s %.2f->%.2f", t, s[t .. "Resist"] or 0, SC.EffectiveResist(s, t, diff))) end
            return string.format("%s L%d HP %s/%s | Plating %s (-%.1f%% ordinary, -%.1f%% x3 hit) | Agility %s (%.1f%% evade) | Ward %s/%s (delay %.1fs, %.0f%%/s) | %s",
                diff, state.Level or 1, tostring(state.Health), tostring(state.MaxHealth), tostring(s.Plating), SC.PlatingReduction(s, 1) * 100, SC.PlatingReduction(s, 3) * 100,
                tostring(s.Agility), (s.EvadeChance or 0) * 100, tostring(player:GetAttribute("Ward")), tostring(s.Ward), s.WardDelay or 0, (s.WardRate or 0) * 100, table.concat(r, " "))
        elseif cmd == "defhit" then -- (UPDATE 8 DEFENCE) ["defhit", dmg, type, "evade" | "boss" | "bossplain", ailment?]: a typed hit through
            -- DamagePlayer ("evade" = an ordinary bot strike Agility may dodge; "bossplain" = a boss's plain hit: x BOSS_EVADE, no Ghost;
            -- anything else = never dodged); returns what happened
            local wasSafe = player:GetAttribute("SafeLocked")
            player:SetAttribute("SafeLocked", true)
            local h0, w0 = state.Health, player:GetAttribute("Ward")
            CombatServer.DamagePlayer(player, tonumber(a) or 10, b and tostring(b) or nil, d and tostring(d) or nil, 1, nil, { Evadable = c == "evade" or c == "bossplain", Boss = c == "boss" or c == "bossplain" })
            player:SetAttribute("SafeLocked", wasSafe)
            local h1, w1 = state.Health, player:GetAttribute("Ward")
            return string.format("%s hit %s: life %s -> %s, ward %s -> %s%s", tostring(b or "Kinetic"), tostring(a), tostring(h0), tostring(h1), tostring(w0), tostring(w1),
                (h0 == h1 and w0 == w1) and "  (EVADED / no damage)" or "")
        elseif cmd == "nodeath" then
            player:SetAttribute("DevNoDeath", a ~= false)
        elseif cmd == "linkedrooms" then -- (LINKED ROOMS pilot) ["linkedrooms", true|false] = this player's next solo regular floors are
            -- linked rooms (Player attr LinkedRooms); ["linkedrooms", "spawnall" | "wakeall" | "goto", room | "state"] = test hooks on one
            if type(a) == "string" then return require(script.Parent:WaitForChild("DungeonRuns")).LinkedDev(player, a, b) end
            local on = a ~= false
            player:SetAttribute(require(game.ReplicatedStorage.AimRngShared.LinkedRooms).ATTR, on) -- (false, not nil: Studio treats nil as ON)
            return "linked rooms " .. (on and "ON" or "OFF") .. " (from the next floor)"
        elseif cmd == "linkedoff" then -- (LINKED ROOMS are the normal game: ["linkedoff", true|false] = this player's floors are single rooms)
            local off = a ~= false
            local attr = nil
            if off then attr = false end
            player:SetAttribute(require(game.ReplicatedStorage.AimRngShared.LinkedRooms).ATTR, attr)
            return "linked rooms " .. (off and "OFF" or "ON") .. " (from the next floor)"
        elseif cmd == "packsoff" or cmd == "packspilot" then -- (UPDATE 8: packs are normal; "packsoff" true = NO packs on this player's solo floors)
            local off
            if cmd == "packsoff" then off = a ~= false else off = a == false end -- (old "packspilot": false = off)
            player:SetAttribute(require(game.ReplicatedStorage.AimRngShared.PacksPilot).ATTR, off or nil)
            return "packs " .. (off and "OFF" or "ON") .. " (from the next floor)"
        elseif cmd == "typed" then -- (UPDATE 8 OFFENSE) ["typed", "ConvertKineticToHeat=1,HeatDamage=0.5,BurnChance=0.5" | "clear"]:
            -- replaces the equipped gun's affixes with these typed lines (DamageTypes.OFFENCE_STATS); returns the typed hit
            local w = state.EquippedWeapon
            if not w then return "no gun" end
            w.Prefixes, w.Suffixes = {}, {}
            if a and a ~= "clear" then
                for k, v in string.gmatch(tostring(a), "([%w_]+)=([%-%d%.]+)") do table.insert(w.Prefixes, { Stat = k, Value = tonumber(v), Tier = 1, Name = k }) end
            end
            local s = require(game.ReplicatedStorage.AimRngShared.StatCalculator).Calculate(w, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
            Sync(player, state)
            return game:GetService("HttpService"):JSONEncode({ Damage = s.Damage, ByType = s.DamageByType, Main = s.DamageType, Ail = s.AilChanceByType, Proc = w.Proc and w.Proc.Id })
        elseif cmd == "shotmod" then -- (UPDATE 8 OFFENSE phase 3) shot mods on the equipped gun:
            -- ["shotmod", "sockets", "R-G-B B"] = set its sockets | ["shotmod", "give", id, level?] = into the bag | ["shotmod", "put",
            -- "Id,Id,..", level?] = fresh mods straight into sockets 1, 2, .. (colours forced to fit) | ["shotmod", "clear"] |
            -- ["shotmod", "act", action, a, b, c] (the remote's path, "equipped" = your gun's uid, "first" = the bag's first mod) |
            -- ["shotmod", "xp", n] (ShotModXp) | ["shotmod", "drop", n] (n kill drop rolls on a fodder stand-in's terms)
            -- returns the gun's shot: damage / fire rate / magazine, the active mods + ShotFx
            local SMod = require(game.ReplicatedStorage.AimRngShared.ShotMods)
            local w = state.EquippedWeapon
            if not w then return "no gun" end
            if a == "sockets" then
                w.Sockets = tostring(b)
            elseif a == "give" then
                CombatServer.Off.GiveShotMod(player, state, tostring(b), tonumber(c) or 1, 0, true)
            elseif a == "put" then
                w.SocketMods = {}
                local col = {}
                for id in string.gmatch(tostring(b), "[^,]+") do
                    local d = SMod.DEFS[id]
                    if d then table.insert(col, d.Color); w.SocketMods[tostring(#col)] = SMod.New(id, tonumber(c) or 1) end
                end
                if #col > 0 then w.Sockets = table.concat(col, "-") end
            elseif a == "clear" then
                CombatServer.Off.ReturnMods(state, w)
            elseif a == "act" then
                local function U(x) if x == "equipped" then return w.Uid elseif x == "first" then return state.ShotMods and state.ShotMods[1] and state.ShotMods[1].Uid end return x end
                local ok, msg = CombatServer.Off.ShotModAct(player, b, U(c), U(d), U(e))
                return tostring(ok) .. ": " .. tostring(msg)
            elseif a == "xp" then
                local before = {}
                for k, it in pairs(w.SocketMods or {}) do before[k] = (it.Level or 1) .. "/" .. string.format("%.2f", it.Xp or 0) end
                CombatServer.Off.ShotModXp(player, state, tonumber(b) or 1000)
                local after = {}
                for k, it in pairs(w.SocketMods or {}) do after[k] = (it.Level or 1) .. "/" .. string.format("%.2f", it.Xp or 0) end
                return game:GetService("HttpService"):JSONEncode({ Before = before, After = after, Bar = ItemData.XpToNext(state.Level), Cap = SMod.LevelCap(state.Level) })
            end
            local s = require(game.ReplicatedStorage.AimRngShared.StatCalculator).Calculate(w, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
            CombatServer.RecalculateMaxHealth(state)
            Sync(player, state)
            return game:GetService("HttpService"):JSONEncode({ Sockets = w.Sockets, Damage = s.Damage, FireRate = s.FireRate, Mag = s.MagazineSize, More = s.ShotModMore,
                Mods = s.ShotMods, Fx = s.ShotFx, Cond = { ExecutePct = s.Cond.ExecutePct, OverkillCarry = s.Cond.OverkillCarry }, Bag = #(state.ShotMods or {}) })
        elseif cmd == "enemyres" then -- (UPDATE 8 OFFENSE) your run's enemies: resists + ailment flags + health
            local out = {}
            for _, m in ipairs(require(script.Parent:WaitForChild("DungeonRuns")).EnemiesOf(player)) do
                local r = {}
                for _, k in ipairs({ "Res_Kinetic", "Res_Heat", "Res_Cryo", "Res_Volt", "Res_Void" }) do if m:GetAttribute(k) then r[k] = m:GetAttribute(k) end end
                local fl = {}
                for _, k in ipairs({ "Burning", "Bleeding", "Chilled", "Frozen", "Shocked", "Withered", "Decayed" }) do if m:GetAttribute(k) then table.insert(fl, k) end end
                table.insert(out, string.format("%s %s el=%s set=%s %s [%s] hp=%d/%d", m.Name, tostring(m:GetAttribute("ModelName")), tostring(m:GetAttribute("Element")),
                    tostring(m:GetAttribute("ResSet")), game:GetService("HttpService"):JSONEncode(r), table.concat(fl, ","), m:GetAttribute("Health") or 0, m:GetAttribute("MaxHealth") or 0))
            end
            return table.concat(out, "\n")
        elseif cmd == "weapon" then
            local procId = a
            local rarity = b or "Epic"
            local w
            if c then
                w = ItemData.GenerateWeaponOfBase(c, rarity, state.Level) -- works for TestOnly guns too
                if not w then return "unknown baseId " .. tostring(c) end
            else
                w = ItemData.GenerateRandomWeapon(rarity, 1, state.Level)
            end
            if procId and procId ~= "none" then
                if not ItemData.WeaponProcs[procId] then return "unknown proc " .. tostring(procId) end
                w.Proc = { Id = procId, Power = 1 }
            else
                w.Proc = nil
            end
            ItemData.RefreshWeaponName(w)
            table.insert(state.Inventory, w)
            state.EquippedWeapon = w
            state.Streak = 0
            state.IsReloading = false
            CombatServer.RecalculateMaxHealth(state)
            state.CurrentMag = state.MaxMag
        elseif cmd ~= "state" then
            return "unknown command " .. tostring(cmd)
        end

        if cmd ~= "state" then Sync(player, state) end
        local w = state.EquippedWeapon
        return string.format("Lv%d SP=%d Gold=%d HP=%s/%s nodes=%d weapon=%s [%s %s] proc=%s ascBest=%s ascPts=%d",
            state.Level, state.SkillPoints, state.Gold, ItemData.FormatNumber(state.Health or 0), ItemData.FormatNumber(state.MaxHealth or 0),
            #state.AllocatedNodes, w.Name, w.Rarity, w.BaseId, w.Proc and w.Proc.Id or "none", tostring(state.AscTrialBest),
            require(game.ReplicatedStorage.AimRngShared.AscendancyData).PointsFor(state))
    end
    DevCommands.Run = Run
    fn.OnInvoke = function(...)
        local player = Players:GetPlayers()[1]
        if not player then return "no player" end
        return Run(player, ...)
    end
    if not IsStudio then return end

    local remote = Instance.new("RemoteEvent")
    remote.Name = "AimRngDevRemote"
    remote.Parent = game.ReplicatedStorage
    local prefixCycle = { "none", "Burn", "Freeze", "Bleed", "Decay", "Giantslayer", "Fixation", "Echo" }
    local nextPrefix = 1
    -- every gun that has a real-mesh rig (the new lineup), in a fixed order
    local WeaponRigs = require(game.ReplicatedStorage.AimRngShared:WaitForChild("WeaponRigs"))
    local testGuns = {}
    for id in pairs(WeaponRigs.Guns) do
        if ItemData.BaseWeapons[id] and game.ReplicatedStorage.AimRngShared.WeaponAssets:FindFirstChild(WeaponRigs.Guns[id].Asset) then
            table.insert(testGuns, id)
        end
    end
    table.sort(testGuns)
    local gunIndex, currentGun = 0, "Glock17"
    remote.OnServerEvent:Connect(function(player: Player, what: string)
        player:SetAttribute("DevNoDeath", true) -- testing in dungeons shouldn't end in a respawn
        if what == "NextGun" and #testGuns > 0 then
            gunIndex = gunIndex % #testGuns + 1
            currentGun = testGuns[gunIndex]
            Run(player, "weapon", "none", "Epic", currentGun)
        elseif what == "TestGun" then
            local proc = prefixCycle[nextPrefix]
            nextPrefix = nextPrefix % #prefixCycle + 1
            Run(player, "weapon", proc, "Epic", currentGun)
        end
    end)

    -- Mailbox for play-test tooling: Studio's assistant sandbox can't call AimRngDev directly (capabilities),
    -- but it can create a StringValue "DevCmd" in ServerStorage whose Value is a JSON array {cmd, a, b, ...};
    -- the result lands in its "Result" attribute ("Done" = true when finished).
    local HttpService = game:GetService("HttpService")
    local function RunMail(c: Instance)
        if c.Name ~= "DevCmd" or not c:IsA("StringValue") then return end
        task.wait(0.05)
        local ok, args = pcall(HttpService.JSONDecode, HttpService, (c :: StringValue).Value)
        if not ok or type(args) ~= "table" then c:SetAttribute("Result", "bad JSON"); c:SetAttribute("Done", true); return end
        local ok2, res = pcall(function() return fn:Invoke(table.unpack(args)) end)
        c:SetAttribute("Result", tostring(res))
        c:SetAttribute("Done", true)
    end
    game:GetService("ServerStorage").ChildAdded:Connect(function(c) task.spawn(RunMail, c) end)
end

return DevCommands
