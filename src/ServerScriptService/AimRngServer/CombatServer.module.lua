--!nocheck
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Remotes = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Remotes"))
local ItemData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ItemData"))
local StatCalculator = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("StatCalculator"))
local SaveService = require(script.Parent:WaitForChild("SaveService"))
-- Private dungeons: enemies are part-less stand-ins (DungeonRuns) the owner's client renders and moves.
local DungeonRuns = require(script.Parent:WaitForChild("DungeonRuns"))
local AscendancyData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("AscendancyData"))
-- Party dungeons (server-run, 2-4 players) and the lobby rooms that start them.
local PartyRuns = require(script.Parent:WaitForChild("PartyRuns"))
local PartyService = require(script.Parent:WaitForChild("PartyService"))
local DungeonGeneratorShared = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("DungeonGenerator"))

local CombatServer = {}
CombatServer.RS = require(script.Parent:WaitForChild("RunStats")) -- (RUN SUMMARY: per-run stats; no new top-level local)
CombatServer.DL = require(script.Parent:WaitForChild("DeathLog")) -- (QOL2 R1 DEATH RECAP: the last hits per player; no new top-level local)
CombatServer.GT = require(script.Parent:WaitForChild("GoalTrack")) -- (QOL2 R4 GOAL TRACKER: live contract / bounty progress, 1/s when changed)
CombatServer.GT.GetState = function(p) return CombatServer.GetState(p) end
CombatServer.SafeRespawnAt = {} :: { [Player]: number } -- when RespawnInRun last put each player back at the entry room

export type PlayerAttributes = {
    Strength: number,
    Dexterity: number,
    Vitality: number,
    Luck: number,
}

export type StatsTracking = {
    SniperHeadshots: number,
    MeleeKills: number,
    BossKills: number,
    ExplosiveDamageDealt: number,
    TotalKills: number,
    DiscoveredWeapons: { [string]: boolean },
    -- Added for the Title/Achievement revamp: real, checkable progress instead of the old
    -- claim-eligibility logic that didn't match what each title's Requirement text described.
    HighestFloorCleared: number,
    FloorsByDifficulty: { [string]: number },
    FastestFloorClearSeconds: number,
}

export type PlayerState = {
    EquippedWeapon: ItemData.WeaponInstance,
    Inventory: { ItemData.WeaponInstance },
    EquippedGear: { [string]: ItemData.GearInstance },
    GearInventory: { ItemData.GearInstance },
    AllocatedNodes: { string },
    Streak: number,
    SkillPoints: number,
    StatPoints: number,
    Attributes: PlayerAttributes,
    Gold: number,
    UpgradeShards: number,
    ForgeCores: number,
    Materials: { [string]: number }, -- Scrap / Alloy / Prism / ReforgeToken / TuningKit / PrefixCatalyst (ItemData.MaterialOrder)
    LastDailyRoll: number, -- day number (os.time() // 86400) of the last free Forge roll
    RollsCount: number,
    AutoSellThreshold: string,
    Level: number,
    XP: number,
    MaxXP: number,
    Health: number,
    MaxHealth: number,
    -- Cosmetics & Melee
    EquippedGlove: string,
    GloveInventory: { string },
    EquippedKnife: string,
    KnifeInventory: { string },
    EquippedSleeve: string,
    SleeveInventory: { string },
    EquippedWeaponSkin: string,
    WeaponSkinInventory: { string },
    EquippedTitle: string,
    UnlockedTitles: { string },
    DungeonDifficulty: string,
    CurrentMag: number,
    MaxMag: number,
    IsReloading: boolean,
    StatsTracking: StatsTracking,
    Settings: { [string]: any }, -- client settings (FOV, sensitivity, crosshair, keybinds...), saved with the player
}

local playerStates: { [Player]: PlayerState } = {}

export type ShopEntry = {
    Item: any,
    Type: "Weapon" | "Gear",
    Price: number,
}


-- Loot rarity odds (see ItemData.GenerateRandomWeapon/GenerateRandomGear's weighted-luck curve) are
-- driven by a single composite "luck" number. Previously that number only ever reflected the player's
-- own Luck stat and a fixed per-context multiplier -- the chosen DIFFICULTY never factored in, so a
-- kill on Easy rolled identical rarity odds to the same kill on Endless. This table is the missing
-- difficulty axis, so harder modes skew loot noticeably better without ever guaranteeing a rarity.
-- Higher difficulties also drop items more often (per-kill drop chance), not just better ones.
-- ==================== LOOT (progression overhaul) ====================
-- Harder difficulties drop MORE (quantity: item chances and material amounts) and slightly BETTER (luck on
-- the rarity roll). Mythics only drop on Brutal and harder. Targets (Easy, ~15 floors/h, ~3.5 items a
-- floor): a first Legendary in 1-2 hours; a first Mythic in 20-30 hours of Brutal+.
local FloorMods = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("FloorMods"))
local Contracts = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Contracts"))
local Progression = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Progression"))
local AvatarData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("AvatarData"))
local BarStyles = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("BarStyles"))
local Cosmetics = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Cosmetics"))

-- ===== HEALTH BAR COSMETICS (BarStyles): state.BarStyle / state.BarStylesOwned -> Player attributes for the client =====
function CombatServer.SyncBarStyle(player: Player, state: any)
    state.BarStylesOwned = type(state.BarStylesOwned) == "table" and state.BarStylesOwned or {}
    if not BarStyles.Owns(state.BarStylesOwned, state.BarStyle) then state.BarStyle = BarStyles.Default end
    player:SetAttribute("BarStylesOwned", BarStyles.OwnedString(state.BarStylesOwned))
    -- (0.93 COLORWAYS) a set bar in a colourway goes out as "Tempest#2" (BarStyles builds the recoloured bar from it)
    local bs = rawget(BarStyles.ById, state.BarStyle)
    local Colorways = require(game.ReplicatedStorage.AimRngShared.Colorways)
    local v = bs and bs.Set and Colorways.VariantFor(state, bs.Set, "HealthBar:" .. state.BarStyle) or 1
    player:SetAttribute("BarStyle", v > 1 and (state.BarStyle .. "#" .. v) or state.BarStyle)
    player:SetAttribute("BoundPoints", Colorways.Points(state))
end
function CombatServer.GrantBarStyle(player: Player, state: any, id: string, equip: boolean?)
    if not BarStyles.ById[id] then return false end
    state.BarStylesOwned = type(state.BarStylesOwned) == "table" and state.BarStylesOwned or {}
    state.BarStylesOwned[id] = true
    if equip then state.BarStyle = id end
    CombatServer.SyncBarStyle(player, state)
    return true
end

-- ===== ALL COSMETICS (Cosmetics catalog: health bars, outfit pieces, skin tones, melee skins) =====
-- Give a cosmetic (purchase / drop / dev command). Doesn't equip unless asked.
function CombatServer.GrantCosmetic(player: Player, state: any, cat: string, id: string, equip: boolean?): boolean
    local e = Cosmetics.Find(cat, id)
    if not e then return false end
    Cosmetics.Grant(state, e)
    if cat == "HealthBar" then CombatServer.SyncBarStyle(player, state) end
    if equip then CombatServer.EquipCosmetic(player, state, cat, id) end
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    return true
end
-- Wear an owned cosmetic (Cosmetics.Equip changes the state per category). Outfit pieces also re-dress the character;
-- a melee skin goes on every melee (it follows you when you switch). New categories need nothing here unless they
-- show on the character / gear -- add their side effect below.
function CombatServer.EquipCosmetic(player: Player, state: any, cat: string, id: string): (boolean, string?)
    local e = Cosmetics.Find(cat, id)
    if not e then return false, "Unknown item." end
    if not Cosmetics.Owns(state, e) then return false, "You don't own that yet." end
    local meleeIds = {}
    for meleeId in pairs(ItemData.MeleeWeapons) do table.insert(meleeIds, meleeId) end
    Cosmetics.Equip(state, e, meleeIds)
    -- side effects the state change alone doesn't cover
    if cat == "HealthBar" then
        CombatServer.SyncBarStyle(player, state)
    elseif cat == "HideoutTheme" or cat == "HideoutStash" or cat == "HideoutPortal" then
        -- everyone draws your hideout from your published attributes
        local okH, H = pcall(function() return require(script.Parent:WaitForChild("Hideouts")) end)
        if okH and H.Publish then H.Publish(player) end
    elseif Cosmetics.IsAvatarCat[cat] then
        local char = player.Character
        if char then
            local AvatarService = require(script.Parent:WaitForChild("AvatarService"))
            task.spawn(AvatarService.Apply, char, state.Avatar)
        end
    end
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    return true
end
-- (shared with the Dungeons window: DungeonGenerator.DifficultyLoot)
local DifficultyQtyMult: { [string]: number } = DungeonGeneratorShared.DifficultyLoot.Qty
local DifficultyLootMult: { [string]: number } = DungeonGeneratorShared.DifficultyLoot.Luck
-- (FUTURE-PROOF 2026-10-25: Brutal and every tier above it in ItemData.DifficultyOrder -- a new harder tier is in by itself)
local MYTHIC_DIFFICULTIES: { [string]: boolean } = { Endless = true }
for i, d in ipairs(ItemData.DifficultyOrder) do
    if i >= (table.find(ItemData.DifficultyOrder, "Brutal") or 4) then MYTHIC_DIFFICULTIES[d] = true end
end

-- Rarity luck for one roll: character Luck (stats.LuckMultiplier) x difficulty x how special the source
-- is (regular kill 1, elites / bosses more). It only shifts the weighted odds -- nothing is ever forced.
local function ComputeDropLuck(state: PlayerState, stats: any, contextMult: number): number
    local diffMult = 1.0 -- (0.51 RARITY LADDER: the difficulty sets the rarity window itself; its old luck would double-count)
    -- FloorLuckMult: floor modifiers' reward bonus (set by DungeonRuns.StartFloor)
    local storm = (workspace:GetServerTimeNow() < (workspace:GetAttribute("LootStormUntil") or 0)) and 1.5 or 1 -- Loot Storm (EndgameServer)
    -- (UPDATE 7 WORLD ALERTS: a WORLD SURGE in the world you're on)
    local surge = require(game.ReplicatedStorage.AimRngShared.WorldAlerts).Is("WORLD_SURGE", (state :: any).CurBiome) and 1.5 or 1
    return (stats.LuckMultiplier or 1) * diffMult * contextMult * ((state :: any).FloorLuckMult or 1) * storm * surge
end

-- Reward multiplier of the bot-skill step (1-10) the player's current run is set to: 0.75x ... 1.0x (step 4)
-- ... 2.0x (step 10). Applies to kill XP, kill gold and every loot quantity.
local function RewardMultFor(player: Player): number
    local partySkill = PartyRuns.BotSkillOf(player)
    -- (BOT MOVEMENT POE) a map pays its own multiplier (Rifts.MapReward: Standard = the old 6-10 roll's average)
    local mapReward = (not partySkill) and DungeonRuns.Attr(player, "SkillReward")
    if type(mapReward) == "number" then return mapReward end
    local skill = partySkill or DungeonRuns.Attr(player, "BotSkill")
    if not skill then return 1 end
    return DungeonGeneratorShared.BotSkill({ BotSkill = skill }).Reward
end
CombatServer.RewardMultFor = RewardMultFor

-- PER-PLAYER PARTY SCALING (owner 2026-10-04: "multiplayer dungeon scaling ... seems to take the scaling of the highest
-- level player ... enemy health should solely be based off of a specific player's level, ONLY on their end"). A party
-- floor's enemies are built once at the run's reference level (Config.PlayerLevel); each player's hits are converted by
-- LevelCurve(ref) / LevelCurve(own), and the enemies' hits on them by the inverse -- so every member fights the floor
-- as if it were scaled to their own level (bars are fractions, damage numbers come back in their own scale).
-- -> f (>1 = you're below the reference level: your hits count for more, theirs hurt you less), and the run's ref level
local function PartyScale(player: Player): (number, number?)
    local run = PartyRuns.RunOfPlayer(player)
    local ref = run and run.Config and run.Config.PlayerLevel
    if not ref then return 1, nil end
    -- CONTENT LEVEL (2026-10-05): enemies are built at the floor's MONSTER level for everyone -- a lower-level member is
    -- simply weaker against it (and a higher one stronger), like any other floor. No per-player conversion any more:
    -- f is always 1; ref is still returned for the XP conversion below.
    return 1, ref
end
CombatServer.PartyScale = PartyScale
-- (owner 2026-10-05: "health should reset when entering portals"): every new floor starts at full health
function CombatServer.FullHeal(player: Player)
    local st = playerStates[player]
    if not st or (st.Health or 0) <= 0 then return end -- (downed / out of lives: the lives flow owns that)
    CombatServer.RecalculateMaxHealth(st)
    st.Health = st.MaxHealth
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, st)
end
-- the monster level of the content this player is fighting (solo run, party floor), else their own level (hub, trials
-- without a folder) -- loot item level and the XP level gap use it
function CombatServer.ContentLevel(player: Player, state: any): number
    local ml = DungeonRuns.Attr(player, "MonsterLevel")
    if not ml then
        local rid = player:GetAttribute("RunId")
        local pf = rid and workspace:FindFirstChild("PartyRuns")
        local f = pf and pf:FindFirstChild("Run_" .. tostring(rid))
        ml = f and f:GetAttribute("MonsterLevel")
    end
    return (type(ml) == "number" and ml) or ((state and state.Level) or 1)
end

-- Quantity multiplier for loot: difficulty x bot skill.
local function QtyMult(player: Player, state: PlayerState): number
    return (DifficultyQtyMult[state.DungeonDifficulty] or 1) * RewardMultFor(player)
end

-- A fractional amount becomes a whole one with the right average (2.6 -> 2 or 3).
local function StochasticRound(x: number): number
    local whole = math.floor(x)
    return whole + ((math.random() < x - whole) and 1 or 0)
end

-- Adds materials / crafting currencies (amounts x the difficulty's quantity multiplier unless raw) and tells
-- the client. chances = { Key = probability } for single drops (also scaled by quantity, capped at 1).
-- (LOOT SCARCITY 2026-11-07) earned = a raw grant that is still PLAY income (map guardians, run rewards): it takes
-- ItemData.LOOT_SCARCITY.Mats too; a non-raw grant takes Mats and the quantity as qty ^ MatQtyExp. Purchases / gifts / refunds /
-- salvage stay raw (salvage follows LOOT_SCARCITY.Salvage instead).
local function GrantMaterials(player: Player, state: PlayerState, amounts: { [string]: number }?, chances: { [string]: number }?, raw: boolean?, earned: boolean?)
    local qty = raw and 1 or QtyMult(player, state)
    local LS = ItemData.Scarce() and ItemData.LOOT_SCARCITY or nil
    if LS and not raw then qty = (DifficultyQtyMult[state.DungeonDifficulty] or 1) ^ LS.MatQtyExp * RewardMultFor(player) end
    local SM = (LS and (not raw or earned)) and LS.Mats or {}
    state.Materials = state.Materials or ItemData.NewMaterials()
    local gained = {}
    local CM = ItemData.CRAFT_SOURCE_MULT -- (0.75 CRAFTING v3: every crafting currency grant is scaled down here)
    for k, v in pairs(amounts or {}) do
        local n = StochasticRound(v * qty * (CM[k] or 1) * (SM[k] or 1))
        if n > 0 then
            state.Materials[k] = (state.Materials[k] or 0) + n
            gained[k] = (gained[k] or 0) + n
        end
    end
    for k, p in pairs(chances or {}) do
        if math.random() < math.min(1, p * qty * (CM[k] or 1) * (SM[k] or 1)) then
            state.Materials[k] = (state.Materials[k] or 0) + 1
            gained[k] = (gained[k] or 0) + 1
        end
    end
    if next(gained) then Remotes.GetEvent("MaterialsGained"):FireClient(player, gained) end
end
CombatServer.GrantMaterials = GrantMaterials

local RarityRank: { [string]: number } = ItemData.RarityRank

-- A milestone level-up reward should always feel like a genuine reward, so it rerolls (a handful of
-- tries, never more) until it clears a floor rarity -- but that floor is modest and it's still the
-- real weighted table doing the rolling, so it's never a guaranteed high-end item the way a flat
-- rarityOverride was. It can still land above the floor on a good roll; it just won't land below it.
local function RollWeaponAtLeast(luck: number, itemLevel: number, minRarity: string, allowMythic: any): ItemData.WeaponInstance
    local minRank = RarityRank[minRarity] or 1
    local result = ItemData.GenerateRandomWeapon(nil, luck, itemLevel, allowMythic)
    for _ = 1, 8 do
        if (RarityRank[result.Rarity] or 1) >= minRank then break end
        result = ItemData.GenerateRandomWeapon(nil, luck, itemLevel, allowMythic)
    end
    -- (still short after the rerolls: the minimum is a promise -- raid / contract / boss "at least" drops)
    if (RarityRank[result.Rarity] or 1) < minRank then result = ItemData.GenerateRandomWeapon(minRarity, luck, itemLevel, allowMythic) end
    return result
end

-- ==================== GROUND LOOT (Borderlands / PoE) ====================
-- While (state :: any)._DropAt is set (enemy kills, chests), items land on the ground at that spot instead
-- of going straight to the inventory: the client draws a rarity-colored light beam and a card on approach,
-- and [E] picks it up (PickupLoot). Drops are personal (each player sees only their own). Unclaimed drops sit
-- in state.PendingLoot (saved). Leaving the floor MISSES them (MissGroundLoot: Mythic+ -> LOST LOOT, the rest is gone; a solo
-- floor's drops wait one floor for the BACK PORTAL); only a rejoin collects them (CollectGroundLoot). QOL L1 2026-10-28: the
-- exits warn first while pickable drops remain (client GroundLoot.LeaveGate, party portals LeaveLootGate below).
local function GroundPos(state: any): Vector3?
    local at = (state :: any)._DropAt
    if typeof(at) ~= "Vector3" then return nil end
    -- only for drops in the same server step that set it (a stale spot never catches gamble / rift rewards)
    if os.clock() - ((state :: any)._DropAtT or 0) > 0.25 then return nil end
    -- chests: fan the items out in a row in front of the player (owner 2026-10-02: "items drop IN FRONT of the player")
    local fan = (state :: any)._DropFan
    if fan then
        fan.N += 1
        local k = fan.N - 1
        local slot = (k == 0) and 0 or (((k % 2 == 1) and 1 or -1) * math.ceil(k / 2))
        return at + fan.Right * (slot * 2.4) + fan.Fwd * (math.abs(slot) * -0.5)
    end
    -- scatter a little (the client drops it onto the floor below with a raycast)
    return Vector3.new(at.X + math.random(-30, 30) / 10, at.Y, at.Z + math.random(-30, 30) / 10)
end
-- RUN LOOT: anything found inside a dungeon run is tagged until the run is won / extracted (see RUN LOOT below)
-- where chest loot lands: ~5 studs in front of the player (the way they face), fanned out sideways by GroundPos
local function DropInFront(player: Player, state: any)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then (state :: any)._DropAt = nil; return end
    local lv = root.CFrame.LookVector
    local f = Vector3.new(lv.X, 0, lv.Z)
    f = f.Magnitude > 0.05 and f.Unit or Vector3.new(0, 0, 1)
    ;(state :: any)._DropAt = root.Position + f * 5 - Vector3.new(0, 2.6, 0)
    ;(state :: any)._DropAtT = os.clock()
    ;(state :: any)._DropFan = { N = 0, Right = Vector3.yAxis:Cross(f) * -1, Fwd = f }
end
CombatServer.DropInFront = DropInFront

local function InDungeonRun(player: Player): boolean
    return PartyRuns.RunOfPlayer(player) ~= nil or DungeonRuns.Get(player) ~= nil
end
-- (owner 2026-10-04: "remove the extraction / bag system, it's too annoying" -- nothing found in a run is at risk any
-- more: it's yours the moment you pick it up. The tag / resolve plumbing below stays so old saves' tagged items settle.)
local function TagRunLoot(player: Player, item: any) -- (2026-10-23: the run summary's BEST DROP notes every item kept from a run)
    if CombatServer.RS and CombatServer.RS.NoteDrop then CombatServer.RS.NoteDrop(player, item) end
end
-- AUTO-SELL (2026-11-09 AUTO-SELL FILTER, builder inv): THE one auto-sell for every drop path (DropToGround, DropItem's gun + gear
-- with or without a ground spot). AutoSellRules.Decide = rarity at / under state.AutoSellThreshold AND no KEEP rule in
-- state.AutoSellRules (sockets / links / item level / type / stats); relics + Zeniths never. Sold = gold + the buyback list + the
-- "auto-sold" loot line. Returns true when it sold the item (the caller stops there).
local AutoSellRules = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("AutoSellRules"))
CombatServer.AutoSellRules = AutoSellRules
function CombatServer.TryAutoSell(player: Player, state: any, item: any, kind: string): boolean
    if not state or not AutoSellRules.Decide(state.AutoSellThreshold, state.AutoSellRules, item, kind) then return false end
    local sold = (kind == "Gear") and ItemData.GetGearSellValue(item) or ItemData.GetSellValue(item)
    state.Gold += sold
    if CombatServer.Buyback then CombatServer.Buyback.Add(player, item, kind, sold) end -- (QOL2 I3: auto-sold = buyback list)
    Remotes.GetEvent("LootAnnounce"):FireClient(player, item, nil, true)
    return true
end
local function DropToGround(player: Player, state: any, item: any, kind: string, pos: Vector3, keep: boolean?)
    -- (UPDATE 7 ARCHIVE: every drop is noted before auto-sell can take it; a new entry runs the milestone check)
    if (kind == "Weapon" or kind == "Gear") and CombatServer.ArchiveNote then
        local A = require(game.ReplicatedStorage.AimRngShared.ArchiveData)
        local a = A.Ensure(state)
        if next(a.Rarity) == nil then pcall(CombatServer.ArchiveScan, player, state, false) end -- (the save's quiet first fill first)
        local had = item and a.Rarity[tostring(ItemData.RarityRank[item.Rarity] or 0)]
        if CombatServer.ArchiveNote(state, item) then
            if not had and (ItemData.RarityRank[item.Rarity] or 0) >= ItemData.RarityRank.Rare then -- (RARITY v4: Rare / Mythic / Relic)
                Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "LEDGER: your first " .. string.upper(item.Rarity) .. " item!", ItemData.RarityColors[item.Rarity])
            end
            task.defer(function() pcall(CombatServer.ArchiveScan, player, state, false) end)
        end
    end
    -- AUTO SELL (0.59, owner: "Chest drops auto-sell, but bot drops do not"): every drop source lands here, so the
    -- threshold is applied once for weapons AND gear (gear never auto-sold before -- and kills drop far more gear).
    -- Exotics are never auto-sold. (0.75: `keep` = TARGET LOOT -- owner: "you dont actually get the pity weapon when it
    -- drops": the infinite meter rolls normal odds, so most target guns were at or under the auto-sell threshold and were
    -- sold the moment they dropped, while the "TARGET LOOT" text still showed)
    if kind == "Gem" and not keep then -- (0.75 GEM AUTO-SALVAGE: the gem bag's own threshold)
        local gRank = ItemData.RarityRank[state.GemAutoSalvage or ""] or 0 -- (UPDATE 8 GEM GRADES v4: the 5 rarities)
        if gRank > 0 and (ItemData.RarityRank[item.Rarity] or 1) <= gRank then
            local GemData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("GemData"))
            GrantMaterials(player, state, GemData.Yield(item), nil, true)
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "GEM AUTO-SALVAGED: " .. string.upper(item.Rarity), Color3.fromRGB(170, 150, 220))
            return
        end
    end
    -- GLOBAL DROP FEED (0.97, owner: "add global gear drop chats (can hover the weapon / gear they got to view the stats.
    -- Overall rarity of the drop should be displayed)"): a drop at the top rarity of its run (or an exotic) is shown to
    -- everyone in the server, before any auto-sell
    if (kind == "Weapon" or kind == "Gear") and CombatServer.AnnounceDrop and InDungeonRun(player) then
        CombatServer.AnnounceDrop(player, state, item, kind)
    end
    if (kind == "Weapon" or kind == "Gear") and not keep and CombatServer.TryAutoSell(player, state, item, kind) then return end
    TagRunLoot(player, item)
    state.PendingLoot = type(state.PendingLoot) == "table" and state.PendingLoot or {}
    local id = game:GetService("HttpService"):GenerateGUID(false)
    -- (BACK PORTAL: a solo floor's drops remember their floor -- they wait there while you're one floor past it)
    local floor = DungeonRuns.Get(player) and DungeonRuns.Attr(player, "Floor") or nil
    state.PendingLoot[id] = { Item = item, Kind = kind, Pos = { pos.X, pos.Y, pos.Z }, Floor = floor }
    Remotes.GetEvent("LootDropped"):FireClient(player, id, item, kind, pos)
end
-- Puts one picked-up / collected item into the inventory (weapons, gear or gems).
local function GrantLootItem(player: Player, state: any, item: any, kind: string, announce: boolean)
    if kind == "Gem" then
        require(script.Parent:WaitForChild("SkillTreeServer")).GiveGem(player, state, item, true) -- (picked up by hand: no auto-salvage)
        return
    end
    if kind == "Gear" then
        table.insert(state.GearInventory, item)
        if announce then Remotes.GetEvent("LootAnnounce"):FireClient(player, item, nil, false) end
        return
    end
    state.StatsTracking.DiscoveredWeapons[item.BaseId] = true
    table.insert(state.Inventory, item)
    if announce then Remotes.GetEvent("LootAnnounce"):FireClient(player, item, ItemData.CompareWeapons(item, state.EquippedWeapon), false) end
end
-- Everything still on the ground goes to the inventory (floor / run end, rejoin).
function CombatServer.CollectGroundLoot(player: Player, state: any?)
    state = state or playerStates[player]
    if not state or type(state.PendingLoot) ~= "table" or not next(state.PendingLoot) then return end
    local n, stashed = 0, 0
    for _, d in pairs(state.PendingLoot) do
        if type(d) == "table" and d.Item then
            -- (bag full: it goes to the hideout stash if that has room, else into the bag anyway -- never lost)
            local kind = d.Kind or "Weapon"
            if kind ~= "Gem" and ItemData.BagRoom(state) <= 0 then
                local HD = require(game.ReplicatedStorage.AimRngShared.HideoutData)
                state.Hideout = type(state.Hideout) == "table" and state.Hideout or {}
                local h = state.Hideout
                h.Stash = type(h.Stash) == "table" and h.Stash or { W = {}, G = {} }
                h.Stash.W = type(h.Stash.W) == "table" and h.Stash.W or {}
                h.Stash.G = type(h.Stash.G) == "table" and h.Stash.G or {}
                if HD.StashCount(state) < HD.StashCap(HD.ExpLevel(state)) then
                    table.insert(kind == "Gear" and h.Stash.G or h.Stash.W, d.Item)
                    stashed += 1
                    n += 1
                    continue
                end
            end
            GrantLootItem(player, state, d.Item, kind, false)
            n += 1
        end
    end
    state.PendingLoot = {}
    if player.Parent then
        Remotes.GetEvent("LootCleared"):FireClient(player)
        if n > 0 then Remotes.GetEvent("CombatFx"):FireClient(player, "Text", n .. " item" .. (n == 1 and "" or "s") .. " you left behind " .. ((stashed > 0) and ("were collected (" .. stashed .. " to your hideout stash: bag full).") or "went to your bag.")) end
        Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    end
end

-- LOST LOOT (owner 2026-10-04: "a 'lost loot' feature. Notable missed loot (legendary +) will be stored here, and can be
-- purchased back for robux"): drops still on the floor when you leave it (portal, exit, end of run, disconnect) are
-- missed -- Legendary and better go to state.LostLoot (saved, newest LOST_LOOT_MAX kept) to buy back per rarity
-- (ItemData.RunLoot.RecoverPrices / RecoverProductIds); everything below Legendary is gone.
CombatServer.LOST_LOOT_MAX = 30
-- the cap pushes the OLDEST NON-ZENITH out (owner 2026-11-06: a Zenith in Lost Loot never falls off; a list of only Zeniths may
-- run over the cap)
function CombatServer.TrimLostLoot(state: any)
    local list = state.LostLoot
    if type(list) ~= "table" then return end
    while #list > CombatServer.LOST_LOOT_MAX do
        local drop = nil
        for i, e in ipairs(list) do
            if not (type(e) == "table" and ItemData.ZenithOf(e.Item)) then drop = i; break end
        end
        if not drop then break end
        table.remove(list, drop)
    end
end
-- keepFloor (BACK PORTAL, owner 2026-10-05: "portal back to previous floor (loot stays)"): drops on that solo floor
-- stay pending -- you can still walk back for them; the rest are missed as before.
function CombatServer.MissGroundLoot(player: Player, state: any?, keepFloor: number?)
    state = state or playerStates[player]
    if not state or type(state.PendingLoot) ~= "table" or not next(state.PendingLoot) then return end
    local kept = 0
    state.LostLoot = type(state.LostLoot) == "table" and state.LostLoot or {}
    local stay = {}
    for id, d in pairs(state.PendingLoot) do
        if keepFloor and type(d) == "table" and d.Floor == keepFloor then
            stay[id] = d
        elseif type(d) == "table" and type(d.Item) == "table" and d.Kind ~= "Gem" and (RarityRank[d.Item.Rarity or "Common"] or 1) >= RarityRank.Mythic then -- (RARITY v4: Mythic + Relic)
            table.insert(state.LostLoot, { Item = d.Item, Kind = d.Kind or "Weapon", At = os.time() })
            kept += 1
        end
    end
    CombatServer.TrimLostLoot(state) -- (Zeniths pinned)
    state.PendingLoot = stay
    if player.Parent then
        Remotes.GetEvent("LootCleared"):FireClient(player)
        if kept > 0 then Remotes.GetEvent("RunLootLost"):FireClient(player, kept) end
        Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    end
end

-- QOL L1 (2026-10-28): a server-built (party) portal / extract asks first. Pickable drops on this floor (your Drop Rules'
-- hidden ones don't count) -> a warning and no leave; the next try within LEAVE_WARN_S goes through. Never auto-collects.
local LEAVE_WARN_S = 6
local leaveWarnAt = setmetatable({}, { __mode = "k" })
function CombatServer.LeaveLootGate(player: Player): boolean
    local state = playerStates[player]
    if not state or type(state.PendingLoot) ~= "table" or not next(state.PendingLoot) then return true end
    local DR = require(game.ReplicatedStorage.AimRngShared.DropRules)
    local floor = DungeonRuns.Get(player) and DungeonRuns.Attr(player, "Floor") or nil
    local n = 0
    for _, d in pairs(state.PendingLoot) do
        if type(d) == "table" and type(d.Item) == "table" and (d.Floor == nil or d.Floor == floor)
            and DR.Match(state.DropRules, d.Item, d.Kind or "Weapon") ~= "Hide" then n += 1 end
    end
    if n == 0 then return true end
    local t = leaveWarnAt[player]
    if t and os.clock() - t < LEAVE_WARN_S then leaveWarnAt[player] = nil; return true end
    leaveWarnAt[player] = os.clock()
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", n .. (n == 1 and " ITEM" or " ITEMS") .. " STILL ON THE GROUND -- press again to leave", Color3.fromRGB(255, 200, 90))
    return false
end
DungeonGeneratorShared.LeaveGate = function(player: Player) return CombatServer.LeaveLootGate(player) end

-- ==================== RUN LOOT (roguelite) ====================
-- Items found in a run carry RunLoot = true. When the run ends:
--   kept  (state.RunKeep: final floor cleared, or extraction) -> tags cleared, the items are yours;
--   lost  (out of lives, leaving early, disconnecting)       -> removed into state.LostLoot (saved), which the
--         player can buy back one item at a time (ItemData.RunLoot prices) until their next run starts.
local function EachRunLoot(state: any, fn: (list: { any }, i: number, kind: string) -> ())
    for _, spec in ipairs({ { state.Inventory, "Weapon" }, { state.GearInventory, "Gear" }, { state.Gems or {}, "Gem" } }) do
        local list = spec[1]
        for i = #list, 1, -1 do
            if type(list[i]) == "table" and list[i].RunLoot then fn(list, i, spec[2]) end
        end
    end
end
function CombatServer.ResolveRunLoot(player: Player, keep: boolean, state: any?)
    state = state or playerStates[player]
    if not state then return end
    keep = true -- (no run loot is ever lost now; an old save's tagged items are simply kept)
    CombatServer.MissGroundLoot(player, state) -- drops still on the floor were missed (Legendary+ -> LOST LOOT)
    local n = 0
    if keep then
        EachRunLoot(state, function(list, i) list[i].RunLoot = nil; n += 1 end)
        for _, g in pairs(state.EquippedGear or {}) do if type(g) == "table" and g.RunLoot then g.RunLoot = nil; n += 1 end end
        if n > 0 and player.Parent then
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "RUN LOOT SECURED: " .. n .. " item" .. (n == 1 and "" or "s"), Color3.fromRGB(120, 255, 160))
        end
    else
        local lost = {}
        EachRunLoot(state, function(list, i, kind)
            local it = table.remove(list, i)
            it.RunLoot = nil
            table.insert(lost, { Item = it, Kind = kind })
        end)
        for slot, g in pairs(state.EquippedGear or {}) do
            if type(g) == "table" and g.RunLoot then
                g.RunLoot = nil
                state.EquippedGear[slot] = nil
                table.insert(lost, { Item = g, Kind = "Gear" })
            end
        end
        -- the gun in your hands was run loot: back to the one you brought (or your best other gun)
        if state.EquippedWeapon and not table.find(state.Inventory, state.EquippedWeapon) then
            local back
            for _, w in ipairs(state.Inventory) do if w.Uid == state.RunStartWeaponUid then back = w end end
            back = back or state.Inventory[1]
            if not back then
                back = ItemData.GenerateWeaponOfBase and ItemData.GenerateWeaponOfBase("Glock17", "Common", 1) or nil
                if back then table.insert(state.Inventory, back) end
            end
            state.EquippedWeapon = back
            state.IsReloading = false
        end
        if #lost > 0 then
            state.LostLoot = state.LostLoot or {}
            for _, l in ipairs(lost) do table.insert(state.LostLoot, l) end
            CombatServer.TrimLostLoot(state) -- (the cap here too; Zeniths pinned)
            if player.Parent then Remotes.GetEvent("RunLootLost"):FireClient(player, #lost) end
        end
        CombatServer.RecalculateMaxHealth(state)
    end
    state.RunKeep = nil
    if player.Parent then Remotes.GetEvent("SyncPlayerState"):FireClient(player, state) end
end
-- a new run starts: remember the gun you brought, and unclaimed lost loot is gone for good
function CombatServer.BeginRunLoot(player: Player)
    local state = playerStates[player]
    if not state then return end
    state.RunKeep = nil
    state.RunStartWeaponUid = state.EquippedWeapon and state.EquippedWeapon.Uid or nil
    -- (LOST LOOT now stays until you buy it back -- newest CombatServer.LOST_LOOT_MAX kept)
end
-- buy one lost item back (Robux receipt or free while play-testing)
-- (rarities that share a buy-back product -- Mythic / Celestial / Transcendent -- count as the same purchase)
local function SameRecoverTier(a: string?, b: string?): boolean
    if a == b then return true end
    local ids = ItemData.RunLoot.RecoverProductIds
    local ia, ib = a and ids[a] or 0, b and ids[b] or 0
    return ia ~= 0 and ia == ib
end
local function RecoverLost(player: Player, state: any, index: number, rarity: string?): boolean
    local lost = state.LostLoot
    if type(lost) ~= "table" then return false end
    local e = lost[index]
    if not e or (rarity and not SameRecoverTier(e.Item.Rarity, rarity)) then
        e, index = nil, nil
        for i, l in ipairs(lost) do if not rarity or SameRecoverTier(l.Item.Rarity, rarity) then e, index = l, i break end end
    end
    if not e then return false end
    table.remove(lost, index)
    GrantLootItem(player, state, e.Item, e.Kind, true)
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    return true
end
CombatServer.RecoverLost = RecoverLost

-- LAUNCH: boss / chest / objective floors are RELATIVE to the difficulty's rarity window. "TopN" = one of the N highest
-- rarities this tier can drop (Top1 = the tier's top). Fixed names ("Rare", "Epic") sat at or under the window's bottom
-- on Torment+, so a superboss's "3 Epic+" was what a normal mob dropped. Fixed names still work (contracts, trials).
-- (0.72 GEAR PACE: every "TopN" floor sits one step lower -- a superboss's "Top2" guaranteed a top-two item every kill)
CombatServer.TOP_FLOOR_SHIFT = 1
function CombatServer.TierFloor(minRarity: string?, topRank: number): string?
    local n = type(minRarity) == "string" and tonumber(minRarity:match("^Top(%d+)$"))
    if not n then return minRarity end
    return ItemData.Rarities[math.max(1, topRank - n + 1 - CombatServer.TOP_FLOOR_SHIFT)]
end
-- LOOT v3 (0.91, owner: "the minimum rarity system just doesn't feel very fun ... the chance to drop up to x rarity is there
-- rather than just ALWAYS getting mythics"): no drop has a minimum any more. What used to be a floor ("Top3" for a boss,
-- "Epic" for a contract ...) becomes LUCK: the closer the old floor sat to the tier's top, the better the odds -- x1 for a
-- floor 5+ steps under the top, +0.35 per step closer (a superboss's old Top2 = x2.05). Every rarity can still drop.
function CombatServer.FloorLuck(minRarity: string?, topRank: number): number
    if not minRarity then return 1 end
    -- (UPDATE 8 RARITY v4: the ladder is 4 steps now, so "TopN" is a plain luck bonus by N -- Top1 x2.4 .. Top4 x1.35; still
    -- never a guarantee. Named rarities keep the old rule below.)
    local topN = type(minRarity) == "string" and tonumber(minRarity:match("^Top(%d+)$"))
    if topN then return 1 + 0.35 * math.max(0, 5 - topN) end
    local r = ItemData.RarityRank[CombatServer.TierFloor(minRarity, topRank) or ""] or 1
    local gap = math.max(0, topRank - math.min(r, topRank))
    return 1 + 0.35 * math.max(0, 5 - gap)
end

-- a GIVEN item onto the ground in front of you (never auto-sold), else into the bag (UPDATE 7: the bounty contract's gun)
function CombatServer.DropGiven(player: Player, state: PlayerState, item: any, kind: string)
    if kind == "Weapon" then state.StatsTracking.DiscoveredWeapons[item.BaseId] = true end
    local gp = GroundPos(state)
    if gp then DropToGround(player, state, item, kind, gp, true); return end
    table.insert((kind == "Weapon") and state.Inventory or state.GearInventory, item)
    Remotes.GetEvent("LootAnnounce"):FireClient(player, item, nil, false)
end

-- One item drop (55% weapon, 45% gear) at the player's level +/-2, at least minRarity. Auto-sell applies
-- to weapons at or below the player's threshold.
-- boost (BOSS ODDS, 2026-10-22): each rarity step's weight x boost^(rank - 1) on top of luck -- bosses roll better odds, nothing
-- guaranteed (luck alone moves the ladder only luck^0.1 a step, so a boss's luck bonus used to change almost nothing)
-- (LOOT SCARCITY 2026-11-07) the Studio economy probe (DevCmd "econrun"): while state._Econ is set, every item drop / kill is counted
function CombatServer.EconNote(state: any, what: string, key: string?)
    local E = state and state._Econ
    if not E then return end
    E[what] = E[what] or {}
    E[what][key or "?"] = (E[what][key or "?"] or 0) + 1
end
local function DropItem(player: Player, state: PlayerState, stats: any, contextLuck: number, minRarity: string?, boost: number?)
    CombatServer.RS.Add(player, "Items")
    local luck = ComputeDropLuck(state, stats, contextLuck)
    local allowMythic = ItemData.MaxRarityRank(state.DungeonDifficulty) -- (RARITY v4: Rare everywhere, Mythic from Torment)
    local area = state.DungeonDifficulty or "Easy" -- (RARITY v4: the difficulty names the roll's cap AND its area)
    local lvl = math.clamp(CombatServer.ContentLevel(player, state) + math.random(-2, 2), 1, ItemData.MAX_LEVEL) -- (CONTENT LEVEL: the floor's monster level)
    -- (ITEM LEVEL REQUIREMENT: a drop is always something you can wear -- content above you drops at your ceiling)
    lvl = math.min(lvl, (state.Level or 1) + ItemData.IlvlAllowance(state.Level))
    -- (UPDATE 8 LOOT RELICS, THE STREAM) any item drop can be a relic instead (ItemData.StreamRelicChance; MinDiff / hooks apply)
    if math.random() < ItemData.StreamRelicChance(area) then
        local rid = ItemData.RollRelicId("Stream", area)
        local relic = rid and ItemData.MakeExotic(rid, "Relic", lvl)
        if relic then
            CombatServer.EconNote(state, "Items", "Relic")
            local kind = (ItemData.Exotics[rid].Kind == "Weapon") and "Weapon" or "Gear"
            if kind == "Weapon" then state.StatsTracking.DiscoveredWeapons[relic.BaseId] = true end
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "RELIC DROP: " .. relic.Name .. "!", ItemData.EXOTIC_COLOR)
            local gp = GroundPos(state)
            if gp then DropToGround(player, state, relic, kind, gp); return end
            TagRunLoot(player, relic)
            table.insert((kind == "Weapon") and state.Inventory or state.GearInventory, relic)
            Remotes.GetEvent("LootAnnounce"):FireClient(player, relic, nil, false)
            return
        end
    end
    -- (LOOT v3: no floor -- the old minimum is better odds; luck also climbs with your level inside the tier)
    luck *= CombatServer.FloorLuck(minRarity, allowMythic) * ItemData.LevelLuck(state.Level, state.DungeonDifficulty)
    -- (0.99n RARITY LADDER v3: a NAMED minimum -- "an Epic item" from a contract, the golden cache, a raid's Legendary -- is a
    -- promise again: a rarity means the same everywhere now. Relative "TopN" floors stay luck only, see FloorLuck.)
    local fixed = nil
    if type(minRarity) == "string" and not minRarity:match("^Top%d+$") and RarityRank[minRarity] then
        local r = ItemData.RollRarity(luck, area)
        local want = math.min(RarityRank[minRarity], allowMythic)
        fixed = ((RarityRank[r] or 1) >= want) and r or ItemData.Rarities[want]
    end
    if boost and boost ~= 1 and not fixed then -- (> 1 bosses; < 1 PACKS PILOT fodder)
        local w = ItemData.RarityWindow(luck, area)
        local tot = 0
        for r, v in pairs(w) do w[r] = v * boost ^ (r - 1); tot += w[r] end
        local roll, acc = math.random() * tot, 0
        for r = 1, #w do
            acc += w[r]
            if roll <= acc then fixed = ItemData.Rarities[r]; break end
        end
    end
    if math.random() < 0.45 then
        local gear = ItemData.GenerateRandomGear(nil, fixed, luck, lvl, area)
        CombatServer.EconNote(state, "Items", gear.Rarity)
        ItemData.TryEtch(gear, true, state.Level) -- (UPDATE 7 SET LINES)
        local gp = GroundPos(state)
        if gp then DropToGround(player, state, gear, "Gear", gp); return end
        if CombatServer.TryAutoSell(player, state, gear, "Gear") then return end -- (2026-11-09: no ground spot -> the same auto-sell)
        TagRunLoot(player, gear)
        table.insert(state.GearInventory, gear)
        Remotes.GetEvent("LootAnnounce"):FireClient(player, gear, nil, false)
        return
    end
    local w = ItemData.GenerateRandomWeapon(fixed, luck, lvl, area)
    CombatServer.EconNote(state, "Items", w.Rarity)
    ItemData.TryEtch(w, false, state.Level) -- (UPDATE 7 SET LINES)
    state.StatsTracking.DiscoveredWeapons[w.BaseId] = true
    -- (2026-11-09 AUTO-SELL FILTER: the gun's own auto-sell check moved into DropToGround's -- the one TryAutoSell, after the
    -- Ledger note like gear -- or straight here when there's no ground spot)
    local gp = GroundPos(state)
    if gp then DropToGround(player, state, w, "Weapon", gp); return end
    if CombatServer.TryAutoSell(player, state, w, "Weapon") then return end
    TagRunLoot(player, w)
    table.insert(state.Inventory, w)
    Remotes.GetEvent("LootAnnounce"):FireClient(player, w, ItemData.CompareWeapons(w, state.EquippedWeapon), false)
end

-- the loot goblin's promise (2026-10-22): one item of AT LEAST GOBLIN_RARITY at the floor's item level (55% gun / 45% gear, like
-- DropItem), never auto-sold. Legendary even where the difficulty tops out lower. Owner: "Ensure at LEAST a legendary, but
-- anything higher should be exceptionally rare": GOBLIN_STEP_UP (2%) to go one rarity higher, each further step 1/50 of the
-- last (Mythic 1 in 50, Celestial 1 in 2,500, ...), only up to the difficulty's own top rarity. Luck plays no part.
CombatServer.BOSS_ODDS = { Mini = 1.35, Major = 1.5, Super = 1.8 } -- (per rarity step on boss item rolls; see the boss loot branch)
-- UPDATE 8 RARITY v4 (owner, vault answers: "Loot goblins should simply drop rare+, not a guarantee of anything"): every goblin
-- item is AT LEAST Rare; above that the NORMAL odds of the difficulty (a Mythic as often as from any drop with the same luck,
-- only where Mythics drop). Replaces the "at least Legendary" promise (GOBLIN_STEP_UP / FALLOFF are gone).
CombatServer.GOBLIN_RARITY = "Rare"
function CombatServer.GoblinRarity(difficulty: string?, luck: number?): string
    local r = ItemData.RollRarity(luck or 1, difficulty or "Easy")
    if (RarityRank[r] or 1) < RarityRank[CombatServer.GOBLIN_RARITY] then r = CombatServer.GOBLIN_RARITY end
    return r
end
function CombatServer.GoblinLegendary(player: Player, state: PlayerState)
    CombatServer.RS.Add(player, "Items")
    local lvl = math.clamp(CombatServer.ContentLevel(player, state) + math.random(-2, 2), 1, ItemData.MAX_LEVEL)
    lvl = math.min(lvl, (state.Level or 1) + ItemData.IlvlAllowance(state.Level))
    local rar = CombatServer.GoblinRarity(state.DungeonDifficulty)
    if math.random() < 0.45 then
        local gear = ItemData.GenerateRandomGear(nil, rar, 1, lvl)
        ItemData.TryEtch(gear, true, state.Level)
        CombatServer.DropGiven(player, state, gear, "Gear")
    else
        local w = ItemData.GenerateRandomWeapon(rar, 1, lvl)
        ItemData.TryEtch(w, false, state.Level)
        CombatServer.DropGiven(player, state, w, "Weapon")
    end
end

-- One skill-tree gem (GemData) at least minRarity. Mythic gems only from superbosses / Endless bosses on
-- Brutal and harder (mythicSource). A full gem bag salvages the gem into materials instead.
local function DropGem(player: Player, state: PlayerState, stats: any, contextLuck: number, minRarity: string?, mythicSource: boolean?)
    local GemData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("GemData"))
    local luck = ComputeDropLuck(state, stats, contextLuck)
    local allowMythic = mythicSource == true and MYTHIC_DIFFICULTIES[state.DungeonDifficulty] == true
    local tierCap = ItemData.LegacyMaxRarityRank(state.DungeonDifficulty) -- (0.60e: gems follow the difficulty's window; RARITY v4: gems keep the OLD ladder)
    -- (LOOT v3: no floor -- better odds instead, + level luck)
    luck *= CombatServer.FloorLuck(minRarity, tierCap) * ItemData.LevelLuck(state.Level, state.DungeonDifficulty)
    local r = GemData.RollRarity(luck, allowMythic, tierCap)
    r = GemData.ThinRarity(r) -- (0.71: each step above Legendary is a 50% roll -- gems stay in the tree for good; off since 0.99n)
    if type(minRarity) == "string" and not minRarity:match("^Top%d+$") and GemData.Rank[minRarity] then -- (0.99n: a named minimum is a promise)
        local want = math.min(GemData.Rank[minRarity], tierCap)
        if (GemData.Rank[r] or 1) < want then r = GemData.Rarities[want] end
    end
    local gem = GemData.Generate(r, nil, allowMythic) -- (0.61: Mythic rules only where Mythics may drop)
    CombatServer.EconNote(state, "Gems", "n")
    local gp = GroundPos(state)
    if gp then DropToGround(player, state, gem, "Gem", gp); return end
    TagRunLoot(player, gem)
    require(script.Parent:WaitForChild("SkillTreeServer")).GiveGem(player, state, gem)
end
CombatServer.DropGem = DropGem
-- WANDERING MERCHANT wares (DungeonEvents.MERCHANT_STOCK): what a purchase gives. Returns ok, message.
function CombatServer.MerchantGrant(player: Player, kind: string): (boolean, string?)
    local state = CombatServer.GetState(player)
    if not state then return false, "No state." end
    local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
    if kind == "Item" then
        DropItem(player, state, stats, 1.5, "Top4")
        return true, "Armory Crate opened."
    elseif kind == "Currency" then -- (UPDATE 8 Phase 5: replaces the Boon Charm -- one random crafting currency you've unlocked)
        local pool = {}
        for _, k in ipairs(ItemData.CURRENCY_V5) do if ItemData.CurrencyRolls(k, state.Level) then table.insert(pool, k) end end
        local k = pool[math.random(1, math.max(1, #pool))]
        if k then
            GrantMaterials(player, state, { [k] = 1 }, nil, true)
            return true, "Currency Pouch: 1 " .. ItemData.MaterialDefs[k].Name
        end
        GrantMaterials(player, state, { Prism = 3 }, nil, true)
        return true, "Currency Pouch: 3 Prism Shards"
    elseif kind == "Boon" then
        local BoonData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("BoonData"))
        if BoonData.ON == false then return false, "Boons are gone." end
        state.RunBoons = state.RunBoons or {}
        if #state.RunBoons >= BoonData.MAX_BOONS then return false, "You already carry the most boons a run allows." end
        if state.BoonOffer and #state.BoonOffer > 0 then return false, "Choose your current boon first (1 / 2 / 3)." end
        local id = BoonData.RollOffer(state.RunBoons, false)[1]
        if not id then return false, "The merchant has no charms left." end
        table.insert(state.RunBoons, id)
        CombatServer.RecalculateMaxHealth(state)
        local b = BoonData.ById[id]
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "BOON: " .. string.upper(b and b.Name or id), BoonData.RarityColors[b and b.Rarity or "Common"])
        return true, "Boon Charm: " .. (b and b.Name or id)
    elseif kind == "Supplies" then
        state.Health = state.MaxHealth
        GrantMaterials(player, state, { Scrap = 8, Alloy = 4, Prism = 1 })
        return true, "Field Supplies: healed, plus materials."
    end
    return false, "Unknown ware."
end
-- FLOOR OBJECTIVE rewards (FloorObjectives), paid the moment it's done
function CombatServer.ObjectiveReward(player: Player, id: string)
    local state = CombatServer.GetState(player)
    if not state then return end
    local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
    local gold = math.round(320 * (1 + (CombatServer.ContentLevel(player, state) - 1) * 0.05)) -- (linear, like kill gold: the curve ^0.6 paid ~1.3B at level 400)
    -- (LOOT SCARCITY 2026-11-07) an objective's item drops LOOT_SCARCITY.ObjectiveItem of the time
    local objItem = ItemData.Scarce() and ItemData.LOOT_SCARCITY.ObjectiveItem or 1
    local function DropItem(...) if math.random() < objItem then CombatServer.DropItemRaw(...) end end
    if id == "BOUNTY" then
        DropItem(player, state, stats, 1.6, "Top4"); state.Gold += gold
    elseif id == "PRECISION" then
        GrantMaterials(player, state, { Alloy = 4, Prism = 1 }, { ReforgeToken = 0.4 }); DropItem(player, state, stats, 1.3)
    elseif id == "UNTOUCHED" then
        DropItem(player, state, stats, 1.9, "Top3")
    elseif id == "BLITZ" then
        state.Gold += gold * 2; GrantMaterials(player, state, { Prism = 3 })
    elseif id == "FOCUS" then
        DropItem(player, state, stats, 1.5, "Top4")
    elseif id == "SHARPSHOOTER" then
        DropItem(player, state, stats, 1.5, "Top4"); GrantMaterials(player, state, { Alloy = 3, Prism = 1 })
    elseif id == "CHAIN" then
        state.Gold += math.round(gold * 1.5); DropItem(player, state, stats, 1.3)
    end
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "OBJECTIVE COMPLETE", Color3.fromRGB(255, 215, 90))
    CombatServer.SendCombatDelta(player, state)
end
-- PATH REWARDS (FloorMods ARMORY / VAULT / CACHE): paid when the floor that carried them is cleared
function CombatServer.PathClearReward(player: Player, mods: any)
    local state = CombatServer.GetState(player)
    if not state then return end
    local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
    if FloorMods.Has(mods, "ARMORY") then DropItem(player, state, stats, 1.5, "Top4") end
    if FloorMods.Has(mods, "VAULT") then DropItem(player, state, stats, 2.0, "Top3") end
    if FloorMods.Has(mods, "CACHE") then
        GrantMaterials(player, state, { Scrap = 12, Alloy = 6, Prism = 2 }, { ReforgeToken = 0.5, TuningKit = 0.35, AffixSeal = 0.4,
            Schematic = 0.3, InfusionCore = 0.25, PurgeSalt = 0.25 })
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "SUPPLY CACHE  •  upgrade materials", Color3.fromRGB(170, 230, 140))
    end
end
CombatServer.DropToGround = DropToGround
CombatServer.DropItemRaw = function(...) DropItem(...) end -- (LOOT SCARCITY: ObjectiveReward's gated wrapper)
CombatServer.DropItemFor = function(player: Player, state: PlayerState, stats: any, contextLuck: number, minRarity: string?)
    DropItem(player, state, stats, contextLuck, minRarity)
end

-- Both the RNG weapon roll and the shop used to hand out items at a flat baseline item level (the RNG
-- roll used the player's OWN level already, which was fine; the shop used a hardcoded 20 forever,
-- meaning a level-5 player could buy a level-20-scaled weapon on day one and a level-90 player would be
-- stuck seeing permanently-weak level-20 stock). This keeps every roll/purchase within +/-3 of a
-- reference level instead of landing exactly on it every time, so it doesn't feel like a solved formula.
local ITEM_LEVEL_ROLL_SPREAD = 3
local function RollItemLevelNear(referenceLevel: number): number
    return math.max(1, math.floor(referenceLevel) + math.random(-ITEM_LEVEL_ROLL_SPREAD, ITEM_LEVEL_ROLL_SPREAD))
end


-- Shared "an enemy just died" pipeline (XP/Gold, boss/loot-goblin bookkeeping, per-kill loot roll,
-- leveling + milestone cache, practice-dummy respawn, and the RemainingEnemies/room-clear/boss-gate
-- logic) -- used by BOTH the ranged hit-registration handler and the melee handler below, so a melee
-- kill goes through exactly the same server-authoritative bookkeeping a gun kill does. Previously melee
-- kills only did `state.StatsTracking.MeleeKills += 1; child:Destroy()` and skipped ALL of this, which
-- meant a melee kill gave no XP/Gold/loot AND never decremented RemainingEnemies -- silently desyncing
-- the run's kill counter (the room could never reach "cleared" for that kill, or -- if it removed the
-- last enemy -- left the floor stuck one kill short of what the counter expected).
-- Global pacing dial: every kill's XP/Gold gets scaled by these before anything else touches them.
-- Progression (currency, rolling, upgrading -- everything) was happening far too fast for a game meant
-- to reward long-term grinding, and per-kill XP/Gold is the single biggest driver of that since it fires
-- on every kill across every enemy type/floor -- one constant here tunes the whole game's pace instead of
-- needing to individually retune dozens of scattered per-enemy-type reward values across DungeonGenerator.
local KILL_XP_MULT = 1 -- (LEVELING PACE: the enemies' XpReward is already the tuned value -- ItemData.KillXp)
local KILL_GOLD_MULT = 0.55

-- ==================== RARE COSMETIC DROPS ====================
-- Each difficulty has an Enemy set (<1% per regular kill) and a Boss set (a few % per boss kill); see
-- ItemData.CosmeticSets. Unowned pieces are preferred; if the whole set is owned, a duplicate converts
-- into Upgrade Shards instead of being wasted.
local COSMETIC_INVENTORY_FIELD = { Glove = "GloveInventory", Sleeve = "SleeveInventory", WeaponSkin = "WeaponSkinInventory" }
local function RollCosmeticDrop(player: Player, state: PlayerState, difficulty: string, isBoss: boolean, isSuperBoss: boolean)
    local tables = ItemData.CosmeticDropTables[difficulty]
    if not tables then return end
    local chance = isSuperBoss and ItemData.CosmeticDropChance.SuperBoss
        or (isBoss and ItemData.CosmeticDropChance.Boss or ItemData.CosmeticDropChance.Enemy)
    if math.random() >= chance then return end
    local pool = isBoss and tables.Boss or tables.Enemy
    if not pool or #pool == 0 then return end

    local unowned = {}
    for _, ref in ipairs(pool) do
        local inv = (state :: any)[COSMETIC_INVENTORY_FIELD[ref.Kind]]
        if inv and not table.find(inv, ref.Id) then table.insert(unowned, ref) end
    end
    if #unowned == 0 then
        state.UpgradeShards += isBoss and 60 or 25
        Remotes.GetEvent("CosmeticDrop"):FireClient(player, { Kind = "Duplicate", Id = pool[math.random(1, #pool)].Id, Shards = isBoss and 60 or 25 })
        Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
        return
    end
    local ref = unowned[math.random(1, #unowned)]
    table.insert((state :: any)[COSMETIC_INVENTORY_FIELD[ref.Kind]], ref.Id)
    Remotes.GetEvent("CosmeticDrop"):FireClient(player, { Kind = ref.Kind, Id = ref.Id })
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
end

-- ===== challenge-title bookkeeping (ItemData.TitleProgress kinds; 2026-10-02 titles pass) =====
-- A boss fight starts at the first hit anyone lands (model attribute FightStart, set in ReportHit); a kill is
-- FLAWLESS for a player who took no damage since then (state.HurtAt, set when they're hit) and FAST if it died within
-- 30 s of that first hit. Counted per difficulty so titles can ask for "Hard or harder".
local function Bump(tbl: any, key: string) tbl[key] = (tbl[key] or 0) + 1 end
-- LIFETIME STATS (Update 5, owner: "Add some simple stats somewhere (kills, headshot kills, deaths etc)"): plain counters
-- in StatsTracking (saved with it: SaveService merges its keys, old saves start at 0) shown in the inventory's STATS tab.
-- TotalKills / BossKills / EliteKills / MeleeKills / BestStreak / HighestFloorCleared were already counted; added here:
-- OwnKills / WeakSpotKills (your killing blows / those that hit a weak spot), Deaths (lives lost in runs), Runs / RunsCleared, Shots / Hits (trigger
-- pulls in runs, as the run summary counts them), FloorsCleared (ItemData.RecordFloorClear), PlaySeconds (SaveService).
function CombatServer.Life(state: any, key: string, n: number?)
    local stt = state and state.StatsTracking
    if type(stt) ~= "table" then return end
    stt[key] = (tonumber(stt[key]) or 0) + (n or 1)
end
function CombatServer.RecordBossKill(player: Player, state: any, model: Instance)
    if model:GetAttribute("IsPracticeDummy") then return end
    local stt = state.StatsTracking
    local diff = state.DungeonDifficulty or "Easy"
    -- (0.93 TITLE SKILL FLOOR: boss titles only count kills at the difficulty's title bot skill or higher)
    if not ItemData.TitleSkillOk(diff, PartyRuns.BotSkillOf(player) or DungeonRuns.Attr(player, "BotSkill"), state.Level) then
        if (model:GetAttribute("ModelName") or model.Name) == "BiomeSuperBoss" and not model:GetAttribute("Lite") then stt.SuperBossKills = (stt.SuperBossKills or 0) + 1 end
        return
    end
    stt.BossKillsByDiff = type(stt.BossKillsByDiff) == "table" and stt.BossKillsByDiff or {}
    Bump(stt.BossKillsByDiff, diff)
    if (model:GetAttribute("ModelName") or model.Name) == "BiomeSuperBoss" and not model:GetAttribute("Lite") then stt.SuperBossKills = (stt.SuperBossKills or 0) + 1 end
    local fs = model:GetAttribute("FightStart")
    if fs then
        if ((state :: any).HurtAt or -1) < fs then
            stt.FlawlessBosses = (stt.FlawlessBosses or 0) + 1
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "FLAWLESS BOSS KILL  (" .. stt.FlawlessBosses .. ")", Color3.fromRGB(240, 240, 255))
        end
        if os.clock() - fs <= 30 then
            stt.FastBossesByDiff = type(stt.FastBossesByDiff) == "table" and stt.FastBossesByDiff or {}
            Bump(stt.FastBossesByDiff, diff)
        end
    end
end
-- a whole run finished: deathless if no life was lost (and no revive bought)
function CombatServer.RecordRunFinished(player: Player, state: any, diff: string)
    CombatServer.RS.Note(player, "VICTORY")
    CombatServer.Life(state, "RunsCleared")
    local lives = player:GetAttribute("Lives")
    local skillOk = ItemData.TitleSkillOk(diff, PartyRuns.BotSkillOf(player) or DungeonRuns.Attr(player, "BotSkill"), state.Level) -- (0.93: skill floor + level cap)
    if skillOk and lives and lives >= ItemData.Lives.PerRun and (player:GetAttribute("Revives") or 0) == 0 then
        local stt = state.StatsTracking
        stt.DeathlessRuns = type(stt.DeathlessRuns) == "table" and stt.DeathlessRuns or {}
        Bump(stt.DeathlessRuns, diff)
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "DEATHLESS " .. string.upper(diff) .. " RUN", Color3.fromRGB(255, 80, 120))
    end
end

-- XP, gold, loot rolls and level-ups for one player from one kill (each party member gets their own).

-- PASSIVE POINTS v5 (2026-10-21): completing a difficulty the first time (the clear that unlocks the next one) is worth
-- ItemData.TREE_CLEAR_POINTS passive points, like the reference game's quest points. ItemData.RecordFloorClear says when.
function CombatServer.TreeClearBonus(player: Player, state: any, diff: string)
    local n = ItemData.TREE_CLEAR_POINTS
    state.SkillPoints = (state.SkillPoints or 0) + n
    -- (2026-10-22 PAID REFUNDS) + Unwinds, the free refunds (the reference game's quest refund points)
    local u = ItemData.UNWIND_PER_CLEAR
    GrantMaterials(player, state, { Unwind = u }, nil, true)
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", string.format("%s COMPLETE  •  +%d PASSIVE POINTS  •  +%d UNWIND", string.upper(tostring(diff)), n, u), Color3.fromRGB(120, 230, 255))
end

local function GiveKillRewards(player: Player, state: PlayerState, model: Instance, stats: any)
    -- item / gem drops land where the enemy died (ground loot)
    local deathPos = (DungeonRuns.IsProxy(model) and DungeonRuns.PosOf(model)) or ((model :: any).PrimaryPart and (model :: any).PrimaryPart.Position)
    ;(state :: any)._DropAt = deathPos; (state :: any)._DropAtT = os.clock(); (state :: any)._DropFan = nil
    local storming = workspace:GetServerTimeNow() < (workspace:GetAttribute("LootStormUntil") or 0)
    local rewardMult = RewardMultFor(player) * (1 + (DungeonRuns.Attr(player, "ModReward") or 0)) * (storming and 1.5 or 1) -- floor modifiers / Loot Storm pay more
    do -- (UPDATE 7 WORLD ALERTS) a WORLD SURGE in this world: +25% rewards; ELITE HUNT: elites pay double gold
        local WA = require(game.ReplicatedStorage.AimRngShared.WorldAlerts)
        if WA.Is("WORLD_SURGE", DungeonRuns.Attr(player, "Biome")) then rewardMult *= 1.25 end
        if WA.Is("ELITE_HUNT") and model:GetAttribute("EliteTier") then rewardMult *= 2 end
    end
    -- (party floors: gold comes from the floor's monster level for everyone now -- DungeonGenerator.GetRewardMultiplier)
    local bountiful = FloorMods.Has(DungeonRuns.Attr(player, "Mods"), "BOUNTIFUL")
    state.StatsTracking.TotalKills += 1
    do -- (TITLES v3: class titles count kills with each weapon class's guns)
        local g = ItemData.WeaponGroupOf(state.EquippedWeapon)
        if g then
            local st = state.StatsTracking :: any
            st.KillsByGroup = type(st.KillsByGroup) == "table" and st.KillsByGroup or {}
            st.KillsByGroup[g] = (st.KillsByGroup[g] or 0) + 1
        end
    end
    local xpMult = rewardMult
    do -- party floors: XP at your own level (enemies were built at the run's reference level; gold keeps the old term)
        local _, ref = PartyScale(player)
        if ref and model:GetAttribute("RunId") ~= nil then
            xpMult = xpMult / ((1 + (state.Level - 1) * 0.05) / (1 + (ref - 1) * 0.05)) * (ItemData.KillXpUnit(state.Level) / ItemData.KillXpUnit(ref))
        end
    end
    -- CONTENT LEVEL: content far below you pays little XP, punching up pays a bit more (ItemData.LevelGapXp)
    xpMult *= ItemData.LevelGapXp(state.Level, CombatServer.ContentLevel(player, state))
    local xpReward = math.round((model:GetAttribute("XpReward") or 25) * KILL_XP_MULT * xpMult)
    state.XP += xpReward
    pcall(CombatServer.Off.ShotModXp, player, state, xpReward) -- (UPDATE 8 OFFENSE phase 3: socketed mods level up)
    local goldReward = model:GetAttribute("GoldReward")
    if goldReward then
        state.Gold += math.round(goldReward * KILL_GOLD_MULT * rewardMult * (bountiful and 1.6 or 1))
    end

    local isBoss = (model:GetAttribute("IsBoss") == true)
    -- bestiary: kills per enemy kind (bot archetype, or the boss / goblin model name)
    if not model:GetAttribute("IsPracticeDummy") then
        local kind = model:GetAttribute("DroneType") or model:GetAttribute("ModelName") or model.Name
        local ek = state.StatsTracking.EnemyKills or {}
        state.StatsTracking.EnemyKills = ek
        ek[kind] = (ek[kind] or 0) + 1
        if model:GetAttribute("EliteTier") then state.StatsTracking.EliteKills = (state.StatsTracking.EliteKills or 0) + 1 end
    end
    if (state.Level or 1) >= 80 and not model:GetAttribute("IsPracticeDummy") then -- (UPDATE 7 B4: Spoils Seals from elites + bosses)
        local sc = isBoss and 0.12 or (model:GetAttribute("EliteTier") and 0.015 or 0)
        if sc > 0 then GrantMaterials(player, state, nil, { SpoilsSeal = sc }) end
    end
    if isBoss then
        state.StatsTracking.BossKills += 1
        CombatServer.RecordBossKill(player, state, model)
        -- Rift sigils (Rifts): the first boss ever drops one, then a chance per boss
        require(script.Parent:WaitForChild("EndgameServer")).OnBossKilled(player, state, state.DungeonDifficulty, (DungeonRuns.Attr(player, "Rift") or 0) > 0)
        -- (0.93: boss blueprints removed -- owner: "Blueprint system needs to be removed")
    end

    -- Loot by source (Easy numbers; the difficulty multiplies quantities). Regular kills: a small item chance
    -- and a little Scrap. Elites, the goblin and bosses are where Alloy, Prism Shards and crafting currency
    -- come from. Nothing is ever a guaranteed top rarity.
    local isLootGoblin = (model:GetAttribute("IsLootGoblin") == true)
    local eliteTier = model:GetAttribute("EliteTier") -- nil | "Magic" | "Rare"
    if eliteTier and (DungeonRuns.Attr(player, "Rift") or 0) > 0 and not model:GetAttribute("IsPracticeDummy") then -- (MAPS V2 L1 + L3: a map elite
        pcall(require(script.Parent:WaitForChild("EndgameServer")).MapEliteDrop, player, state, eliteTier) -- can drop a map / Chart Shard / Sigil Mark)
    end
    local isSuperBoss = (model:GetAttribute("ModelName") or model.Name) == "BiomeSuperBoss" and not model:GetAttribute("Lite") -- (a Lite one pays like the Titan)
    local qty = QtyMult(player, state)
    -- PACKS PILOT fodder: its own loot stream below; the flat per-kill rolls x PP.RARE so 5x the kills isn't 5x of those
    local PP = require(game.ReplicatedStorage.AimRngShared.PacksPilot)
    local fodder = model:GetAttribute("Fodder") == true
    local rare = fodder and PP.RARE or 1
    CombatServer.EconNote(state, "Kills", (isSuperBoss and "Super") or (isBoss and "Boss") or (isLootGoblin and "Goblin") or eliteTier or (fodder and "Fodder") or "Bot")
    if not model:GetAttribute("IsPracticeDummy") then
        CombatServer.KillJob(player, state, "Kill", fodder, { Elite = eliteTier ~= nil, RareElite = eliteTier == "Rare", Boss = isBoss, Goblin = isLootGoblin }) -- (UPDATE 8: packs)
        local SX = require(game.ReplicatedStorage.AimRngShared.Seasons).XP
        if not fodder or math.random() < rare then
            CombatServer.AddSeasonXP(player, state, (isBoss and SX.BossKill) or (eliteTier and SX.EliteKill) or SX.Kill)
        end
    end
    -- Skill-tree gems: bosses and elites are the source (chances x quantity, capped).
    local gemChance = (isSuperBoss and 1) or (isBoss and 0.35) or (isLootGoblin and 0.30)
        or (eliteTier == "Rare" and 0.10) or (eliteTier == "Magic" and 0.03) or 0.003
    gemChance *= rare
    if storming then gemChance *= 2 end
    if not model:GetAttribute("IsPracticeDummy") and math.random() < math.min(1, gemChance * qty) then
        local endlessBoss = isBoss and (ItemData.DifficultyRank[state.DungeonDifficulty or ""] or 0) >= 7 -- (Mythic gems: Cataclysm and up)
        DropGem(player, state, stats, isSuperBoss and 3.0 or (isBoss and 2.0 or 1.0), isSuperBoss and "Top3" or (isBoss and "Top4" or nil), isSuperBoss or endlessBoss)
    end
    -- (UPDATE 7 CRAFTING v5) Storm Cores come from bosses, once they're unlocked (ItemData.STORM_CORE_CHANCE x quantity)
    if (isBoss or isSuperBoss) and ItemData.MaterialUnlocked("StormCore", state.Level) then
        GrantMaterials(player, state, nil, { StormCore = (isSuperBoss and ItemData.STORM_CORE_CHANCE.SuperBoss or ItemData.STORM_CORE_CHANCE.Boss)
            * (require(game.ReplicatedStorage.AimRngShared.WorldAlerts).Is("CURRENCY_RAIN") and 2 or 1) })
    end
    -- (UPDATE 7 BOUNTY CONTRACT) its gun + gold, done for the week
    if model:GetAttribute("Contract") == true then pcall(CombatServer.ContractKill, player, state) end
    -- (UPDATE 7 RIFTMODS) bosses / elites drop them from their unlock level
    do
        local RM = require(game.ReplicatedStorage.AimRngShared.Riftmods)
        if RM.ON and (state.Level or 1) >= RM.UNLOCK then
            local ch = (isSuperBoss and RM.CHANCE.SuperBoss) or (isBoss and RM.CHANCE.Boss) or ((model:GetAttribute("EliteTier") ~= nil) and RM.CHANCE.Elite) or 0
            if math.random() < ch then CombatServer.GiveRiftmod(player, state) end
        end
    end
    -- (UPDATE 8 OFFENSE phase 3) SHOT MODS: low chance from the stream (fodder / bots / elites), bosses higher levels + rarer mods
    if not model:GetAttribute("IsPracticeDummy") then pcall(CombatServer.Off.ShotModDrop, player, state, model, isBoss, isSuperBoss) end
    -- BOSS ODDS (2026-10-22, owner: "The bosses dont seem to drop better loot at all, its very underwhelming you kill them and get
    -- nothing" -> a guaranteed-minimum version was rejected: "Only make it a higher chance, not anything guarenteed"): since LOOT
    -- v3 a boss's "TopN" floor was only luck, and luck moves the ladder ~luck^0.1 a step, so bosses dropped what mobs do. Each
    -- boss item now rolls with BOSS_ODDS (x that per rarity step, DropItem boost) -- nothing guaranteed, same item counts as
    -- before (superboss 3, major / mini 2). Torment, per item: Legendary+ ~1.4% for a mob (~1.9% the old boss) -> ~4% mini, ~6% major, ~11% superboss.
    local isMiniBoss = model:GetAttribute("IsMiniBoss") == true
    local odds = CombatServer.BOSS_ODDS
    -- (LOOT SCARCITY 2026-11-07) item counts / chances from ItemData.LOOT_SCARCITY; items take the quantity as qty ^ QtyExp
    local LS = ItemData.Scarce() and ItemData.LOOT_SCARCITY or nil
    local iq = LS and ((DifficultyQtyMult[state.DungeonDifficulty] or 1) ^ LS.QtyExp * RewardMultFor(player)) or qty
    if isSuperBoss then
        for _ = 1, (LS and LS.SuperItems or 3) do DropItem(player, state, stats, 2.2, nil, odds.Super) end
        GrantMaterials(player, state, { Scrap = 20, Alloy = 8, Prism = 5, ReforgeToken = 2, TuningKit = 1, AffixSeal = 2,
            Schematic = 2, InfusionCore = 1, PurgeSalt = 1 })
    elseif isBoss then
        for _ = 1, (LS and (isMiniBoss and LS.MiniItems or LS.MajorItems) or 2) do DropItem(player, state, stats, 1.6, nil, isMiniBoss and odds.Mini or odds.Major) end
        GrantMaterials(player, state, { Scrap = 10, Alloy = 3, Prism = 1.5, ReforgeToken = 1 }, { PrefixCatalyst = 0.30, AffixSeal = 0.45,
            Schematic = 0.25, InfusionCore = 0.3, PurgeSalt = 0.3 })
    elseif isLootGoblin then
        -- LOOT GOBLIN JACKPOT (0.67, owner: "loot goblin drops feel incredibly underwhelming"): it used to pay one item
        -- (+35% a second) and a little Scrap. Now: four items (one of the top two rarities 25% of the time), a gem, a pile
        -- of crafting materials and 8x its gold.
        -- (2026-10-22, owner: "Loot goblins are far too common. They should be rare spawns in any room (1/100), and guarantee
        -- a legendary. This would not be affected by loot luck" / "Ensure at LEAST a legendary, but anything higher should be
        -- exceptionally rare"): the first item is ALWAYS Legendary or better -- no luck, never auto-sold
        -- (CombatServer.GoblinLegendary / GoblinRarity); the rest of the jackpot stays.
        -- (UPDATE 8 RARITY v4: all four items Rare or better -- normal odds above, no other promise)
        CombatServer.GoblinLegendary(player, state)
        DropItem(player, state, stats, 2.0, CombatServer.GOBLIN_RARITY)
        DropItem(player, state, stats, 1.8, CombatServer.GOBLIN_RARITY)
        DropItem(player, state, stats, 1.8, CombatServer.GOBLIN_RARITY)
        DropGem(player, state, stats, 2.0, "Top4")
        GrantMaterials(player, state, { Scrap = 25, Alloy = 8, Prism = 3, ReforgeToken = 1 }, { TuningKit = 0.6, PrefixCatalyst = 0.5, AffixSeal = 0.6,
            Schematic = 0.4, InfusionCore = 0.5, PurgeSalt = 0.5 })
        local jackpot = math.round((model:GetAttribute("GoldReward") or 0) * 8 * qty)
        state.Gold += jackpot
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "LOOT GOBLIN JACKPOT!  4 Rare-or-better items, a gem, materials, +" .. ItemData.FormatNumber(jackpot) .. " gold", Color3.fromRGB(255, 215, 80))
    elseif eliteTier == "Rare" then
        -- (UPDATE 8 Phase 5 ELITE MODS: loot scales with the mod count -- a 3-mod Rare 30% a second item, a 4-mod one 60%)
        local nMods = #string.split(model:GetAttribute("EliteMods") or "", ",")
        if math.random() < (LS and LS.RareFirst or 1) then DropItem(player, state, stats, 1.6) end
        if math.random() < (LS and LS.RareExtra or 0.3) * math.max(1, nMods - 2) then DropItem(player, state, stats, 1.6) end
        GrantMaterials(player, state, { Scrap = 4, Alloy = 2 }, { ReforgeToken = 0.08, AffixSeal = 0.03, Schematic = 0.02, InfusionCore = 0.03, PurgeSalt = 0.03 })
    elseif eliteTier == "Magic" then
        local nMods = #string.split(model:GetAttribute("EliteMods") or "", ",") -- (UPDATE 8: 1 mod 0.3 x qty, 2 mods 0.6 x qty)
        if math.random() < math.min(1, (LS and LS.MagicPerMod or 0.3) * nMods * iq) then DropItem(player, state, stats, 1.3) end
        GrantMaterials(player, state, { Scrap = 2, Alloy = 1 }, { ReforgeToken = 0.04, AffixSeal = 0.01, Schematic = 0.005, InfusionCore = 0.01, PurgeSalt = 0.01 })
    elseif fodder then -- (PACKS PILOT: many drops, each at lower odds per rarity step)
        -- (EarlyPay: EARLY DENSITY 2026-11-07 -- LOOT SCARCITY: the item chance no longer takes it; XP / gold still do)
        local ch = LS and math.min(LS.FodderCap, LS.Fodder * iq) or math.min(PP.ITEM_CAP, PP.ITEM_CHANCE * qty * (model:GetAttribute("EarlyPay") or 1))
        if math.random() < ch then DropItem(player, state, stats, 1.0, nil, PP.ODDS) end
        GrantMaterials(player, state, { Scrap = 1 / 3 })
    else
        local ch = LS and math.min(LS.BotCap, LS.Bot * iq) or math.min(0.5, 0.06 * qty * (model:GetAttribute("EarlyPay") or 1))
        if math.random() < ch then DropItem(player, state, stats, 1.0) end
        GrantMaterials(player, state, { Scrap = 1 / 3 })
    end
    -- FATE SHARD (rerolls a unique trait): a flat chance per kill -- loot quantity bonuses don't touch it
    if not model:GetAttribute("IsPracticeDummy") then
        local fc = ItemData.FATE_SHARD_CHANCE
        if math.random() < ((isBoss or isSuperBoss) and fc.Boss or fc.Mob * rare) then
            GrantMaterials(player, state, { FateShard = 1 }, nil, true)
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "FATE SHARD FOUND: reroll a unique trait at the Forge")
        end
        -- ASCENSION ESSENCE (owner: "incredibly rare ... the same rate of POE 1s" Exalted Orb): a flat tiny chance from ANY
        -- kill -- the only source; loot quantity bonuses don't touch it (ItemData.ASCEND_ESSENCE_CHANCE)
        local ec = ItemData.ASCEND_ESSENCE_CHANCE
        local essChance = (isSuperBoss and ec.SuperBoss) or (isBoss and ec.Boss) or ((eliteTier or isLootGoblin) and ec.Elite) or ec.Mob * rare
        if math.random() < essChance then
            GrantMaterials(player, state, { AscensionEssence = 1 }, nil, true)
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "LODESTAR FOUND: raise a Rare to Mythic at the Forge (ASCEND)", Color3.fromRGB(255, 120, 200))
        end
        -- SOCKET CURRENCIES + BURNISH (UPDATE 8 LOOT): flat chances per kill like the Essence (loot quantity doesn't touch them)
        local sc = ItemData.SOCKET_CUR_CHANCE
        if ItemData.MaterialUnlocked("SocketBore", state.Level) and math.random() < ((isSuperBoss and sc.SuperBoss) or (isBoss and sc.Boss) or ((eliteTier or isLootGoblin) and sc.Elite) or sc.Mob * rare) then
            local k = ItemData.PickWeighted(ItemData.SOCKET_CUR_WEIGHT, "SocketTint") -- (FUTURE-PROOF: by the weights' sum)
            GrantMaterials(player, state, { [k] = 1 }, nil, true)
        end
        local bc = ItemData.BURNISH_CHANCE
        if ItemData.MaterialUnlocked("ModBurnish", state.Level) and math.random() < ((isSuperBoss and bc.SuperBoss) or (isBoss and bc.Boss) or ((eliteTier or isLootGoblin) and bc.Elite) or bc.Mob * rare) then
            GrantMaterials(player, state, { ModBurnish = 1 }, nil, true)
        end
        -- ZENITH (CHASE ITEMS 2026-11-06): the two global Zeniths + Twin Glass, a flat tiny chance per kill (ZenithServer.KillRoll;
        -- nothing while ItemData.ZENITH_LIVE is false)
        CombatServer.Zen.KillRoll(player, state, (isSuperBoss and "SuperBoss") or (isBoss and "Boss") or ((eliteTier or isLootGoblin) and "Elite") or "Mob", rare, CombatServer.CurrentDifficulty(player, state))
        -- REBIRTH SHARD (changes your class at the Skill Monolith): bosses only -- a Boss Trial boss pays best
        local rc = ItemData.REBIRTH_SHARD_CHANCE
        local trial = isBoss and (DungeonRuns.Attr(player, "BossTrial") or "") ~= ""
        local chance = trial and rc.Trial or (isSuperBoss and rc.SuperBoss) or (isBoss and rc.Boss) or 0
        if chance > 0 and math.random() < chance then
            GrantMaterials(player, state, { RebirthShard = 1 }, nil, true)
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "REBIRTH SHARD FOUND: change your class at the Skill Tree", Color3.fromRGB(150, 230, 255))
        end
        -- UNWIND (2026-10-22 PAID REFUNDS): refunds a passive point without gold; bosses only
        local uc = ItemData.UNWIND_CHANCE
        local uChance = trial and uc.Trial or (isSuperBoss and uc.SuperBoss) or (isBoss and uc.Boss) or 0
        if uChance > 0 and math.random() < uChance then
            GrantMaterials(player, state, { Unwind = 1 }, nil, true)
        end
        -- BOSS EXOTICS (0.67, owner: "exotics should be farmed from bosses"): every dungeon boss can drop one. (0.86, owner:
        -- "at a super super low drop chance (getting slightly higher at higher difficulties)": mini-boss 0.05%, major 0.12%,
        -- superboss 0.3% x (1 + rank / 14) x the TIER FALLOFF -- ItemData.BossExoticChance; was 0.8 / 2 / 4%.) Any class's
        -- exotic (not the map-only ones), at the top rarity of the difficulty. Boss Trials keep their own exotic rolls.
        if (isBoss or isSuperBoss) and (DungeonRuns.Attr(player, "BossTrial") or "") == "" then
            local kind = (isSuperBoss and "Super") or (model:GetAttribute("IsMajorBoss") and "Major") or "Mini"
            if math.random() < ItemData.BossExoticChance(state, kind, state.DungeonDifficulty) * (require(game.ReplicatedStorage.AimRngShared.WorldAlerts).Is("EXOTIC_SURGE") and 2 or 1) then
                local id = ItemData.RollRelicId("Boss", state.DungeonDifficulty) -- (UPDATE 8 LOOT: RelicPool -- MinDiff + hooks)
                local item = id and ItemData.MakeExotic(id, "Relic", -- (RARITY v4: a Relic)
                    math.max(1, math.min(state.Level or 1, CombatServer.ContentLevel(player, state) + 5)))
                if item then
                    if ItemData.Exotics[id].Kind == "Weapon" then
                        state.StatsTracking.DiscoveredWeapons[item.BaseId] = true
                        table.insert(state.Inventory, item)
                    else
                        table.insert(state.GearInventory, item)
                    end
                    Remotes.GetEvent("LootAnnounce"):FireClient(player, item, nil, false)
                    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "RELIC DROP: " .. item.Name .. "!", ItemData.EXOTIC_COLOR)
                end
            end
        end
        -- WORLDEATER (0.93 boss trophy title): a rare drop from a biome superboss on Ruin or harder, not while outlevelled
        if isSuperBoss and ItemData.SUPER_TROPHY_TITLE then
            local d = state.DungeonDifficulty or "Easy"
            local tt = ItemData.SUPER_TROPHY_TITLE
            state.UnlockedTitles = state.UnlockedTitles or {}
            if (ItemData.DifficultyRank[d] or 0) >= (ItemData.DifficultyRank[ItemData.SUPER_TROPHY_MIN_DIFF] or 99) and not table.find(state.UnlockedTitles, tt)
                and (state.Level or 1) <= ItemData.TitleMaxLevel(d)
                and math.random() < ItemData.SUPER_TROPHY_CHANCE * ItemData.ExoticFalloff(state, d) then
                table.insert(state.UnlockedTitles, tt)
                Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "TITLE DROP: " .. ItemData.Titles[tt].Title .. "!  (equip it in TITLES)", ItemData.Titles[tt].Color)
            end
        end
        -- HIDEOUT TROPHIES (0.55, Hideouts.OnBossKill): each boss has its own piece, rarer the lower the tier
        if (isBoss or isSuperBoss) and CombatServer.OnBossKillLoot then
            local pr = PartyRuns.RunOfPlayer(player)
            local biome = (pr and pr.Config and pr.Config.Biome) or DungeonRuns.Attr(player, "Biome")
            pcall(CombatServer.OnBossKillLoot, player, state, model:GetAttribute("ModelName") or model.Name, biome, state.DungeonDifficulty)
        end
    end

    -- Leveling: cap ItemData.MAX_LEVEL (400). A level gives passive points (ItemData.TreePointsForLevelUp) + attribute points (AttrPointsForLevelUp); no gold
    -- or materials (those come from playing). XP needed per level: see CombatServer.XpToNext.
    state.MaxXP = CombatServer.XpToNext(state.Level) -- (saves keep the old requirement until recomputed here)
    while state.XP >= state.MaxXP and state.Level < ItemData.MAX_LEVEL do
        state.XP -= state.MaxXP
        state.Level += 1
        state.SkillPoints += ItemData.TreePointsForLevelUp(state.Level) -- (1 a level; + difficulty clears: ItemData.TreePointsTotal)
        state.StatPoints += ItemData.AttrPointsForLevelUp(state.Level) -- (ATTRIBUTES v2: 1 a level + 4 every 10th)
        state.MaxXP = CombatServer.XpToNext(state.Level)
        CombatServer.RecalculateMaxHealth(state) -- max health grows with level (see StatCalculator)
        state.Health = state.MaxHealth
        Remotes.GetEvent("LevelUp"):FireClient(player, state.Level)
    end
    -- At the cap XP stops (Paragon removed 2026-10-13: a raised cap is the long-term progression; no banked XP, so a
    -- new cap starts everyone at 0 instead of handing out instant levels).
    if state.Level >= ItemData.MAX_LEVEL then state.XP = 0 end

    -- Weapon mastery: kills with each gun model (Progression.MasteryLevel).
    local w = state.EquippedWeapon
    if w and w.BaseId and not model:GetAttribute("IsPracticeDummy") then
        local wk = state.StatsTracking.WeaponKills or {}
        state.StatsTracking.WeaponKills = wk
        local before = Progression.MasteryLevel(wk[w.BaseId])
        -- (UPDATE 8, owner: packs everywhere -- a fodder kill counts Progression.FODDER_MASTERY (1/5) so mastery keeps today's pace)
        wk[w.BaseId] = math.round(((wk[w.BaseId] or 0) + (model:GetAttribute("Fodder") and Progression.FODDER_MASTERY or 1)) * 100) / 100
        local after = Progression.MasteryLevel(wk[w.BaseId])
        if after > before then
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", string.format("MASTERY UP: %s level %d  (+%d%% damage with it)",
                ItemData.BaseWeapons[w.BaseId] and ItemData.BaseWeapons[w.BaseId].ShortName or w.BaseId, after, math.round(after * Progression.MASTERY_DAMAGE_PER_LEVEL * 100)))
        end
    end

    ;(state :: any)._DropAt = nil
    local diffForDrop = DungeonRuns.Attr(player, "Difficulty") or state.DungeonDifficulty or "Easy"
    -- cosmetic drops are off until gloves / sleeves / finishes are redone for the current hand models
    -- RollCosmeticDrop(player, state, diffForDrop, isBoss, isSuperBoss)

    -- cosmetic drops in dungeon runs (health bars, boss gloves, UI themes) -- kept forever, not run loot.
    -- (OFF while the line-up is bundles only: every drop-only cosmetic is retired -- Cosmetics.KEEP_ONLY_BUNDLES)
    if InDungeonRun(player) and not Cosmetics.KEEP_ONLY_BUNDLES then
        local src = (isSuperBoss and "SuperBoss") or (isBoss and "Boss") or (isLootGoblin and "Goblin") or (eliteTier and "Elite") or "Enemy"
        -- the drop-only health bar cosmetic(s): super rare, from their boss only
        for _, bs in ipairs(BarStyles.List) do
            if bs.Unlock == "Drop" and bs.DropSource == src and not BarStyles.Owns(state.BarStylesOwned, bs.Id) and math.random() < (bs.DropChance or 0) then
                CombatServer.GrantBarStyle(player, state, bs.Id, false)
                Remotes.GetEvent("CosmeticDrop"):FireClient(player, { Kind = "BarStyle", Name = "HEALTH BAR: " .. bs.Name:upper(), Rarity = bs.Rarity })
                Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "SUPER RARE DROP!  " .. bs.Name .. " health bar. Equip it in Settings > Enemies", Color3.fromRGB(255, 80, 90))
            end
        end
        -- super rare boss gloves (GloveFX DropFrom = "Titan": the Apex Titan Mech, not trial bosses)
        if model:GetAttribute("IsMajorBoss") == true and not model:GetAttribute("TrialBoss") and (model:GetAttribute("ModelName") or model.Name) == "ApexTitanMech" then
            for _, g in ipairs(require(game.ReplicatedStorage.AimRngShared.GloveFX).Gloves) do -- (GloveFXWG is declared further down)
                if g.DropFrom == "Titan" and math.random() < (g.DropChance or 0.005) then
                    local ce = Cosmetics.Find("Glove", g.Id)
                    if ce and not Cosmetics.Owns(state, ce) then
                        CombatServer.GrantCosmetic(player, state, "Glove", g.Id, false)
                        Remotes.GetEvent("CosmeticDrop"):FireClient(player, { Kind = "Avatar", Name = "GLOVES: " .. g.Name:upper(), Rarity = g.Rarity, Slot = "Glove" })
                        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "SUPER RARE DROP!  " .. g.Name .. ". Equip them in COSMETICS > GLOVES", Color3.fromRGB(255, 80, 90))
                    end
                end
            end
        end
        -- UI theme recolours (HudThemes Unlock = "Drop"): one roll per boss / superboss / loot goblin / elite kill
        if src ~= "Enemy" then
            local HT = require(game.ReplicatedStorage.AimRngShared.HudThemes)
            local t = HT.RollDrop(src, function(id) local ce = Cosmetics.Find("HudTheme", id); return ce == nil or Cosmetics.Owns(state, ce) end)
            if t then
                CombatServer.GrantCosmetic(player, state, "HudTheme", t.Id, false)
                Remotes.GetEvent("CosmeticDrop"):FireClient(player, { Kind = "Avatar", Name = "UI THEME: " .. t.Name:upper(), Rarity = t.Rarity, Slot = "HudTheme" })
                Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "UI THEME DROP!  " .. t.Name .. ". Equip it in COSMETICS > UI THEMES", t.Accent)
            end
        end
        -- (outfit-piece drops are gone: 2026-10-02 players wear their own Roblox avatars -- R6, like Rivals)
    end
end

-- (LIVE FIX 2026-11-06, owner on the live game: "after killing everything, nothing happened and it still said 6 enemies were
-- remaining") a kill marks the stand-in Dead FIRST, then runs the kill effects + rewards, and only then counts it down. One error in
-- between left a Dead (hidden, unhittable) stand-in that never counted -> the floor could never clear. Those steps now run through
-- SafeCall (the error still reaches the F6 ERRORS log), and DungeonRuns.Reconcile re-counts a floor that drifted anyway.
function CombatServer.SafeCall(tag: string, fn: any, ...): boolean
    local ok, err = xpcall(fn, debug.traceback, ...)
    if not ok then task.spawn(error, "[" .. tag .. "] " .. tostring(err), 0) end
    return ok
end
-- the floor's count after a counted kill (rem = the new RemainingEnemies): the client's number, the clear, the floor-clear credit.
-- Also DungeonRuns.Reconcile's way to clear a floor whose count drifted.
function CombatServer.FloorCount(player: Player, state: PlayerState, dungeon: Instance, isBoss: boolean, rem: number)
    -- Boss-room fix: a boss floor's totalFoes only ever counted the boss itself (=1), so a
    -- boss that summons uncounted adds mid-fight could have the FIRST add's death zero this
    -- flat counter while the boss was still alive -- the room would then incorrectly read as
    -- "cleared". BossDefeated is only set true here, specifically when the killed model IS
    -- the boss, so room-clear on a boss floor requires BOTH rem==0 AND the boss confirmed dead.
    local isBossFloorNow = dungeon:GetAttribute("IsBossFloor") == true
    if isBoss then
        dungeon:SetAttribute("BossDefeated", true)
    end
    local bossDefeatedNow = dungeon:GetAttribute("BossDefeated") == true
    -- Boss floors clear the moment the boss dies (its summoned escorts are dismissed); other floors when
    -- every foe is down.
    local roomCleared = (isBossFloorNow and bossDefeatedNow) or (not isBossFloorNow and rem == 0)

    local curBiome = dungeon:GetAttribute("Biome") or "Fire"
    local curDiff = dungeon:GetAttribute("Difficulty") or "Easy"
    local curFloor = dungeon:GetAttribute("Floor") or 1

    -- Don't tell the client "0 remaining" (which shows the Next Floor prompt) while a boss
    -- floor's boss is still alive -- keep the displayed count at 1 until it's actually dead.
    local displayRemaining = rem
    if isBossFloorNow and not bossDefeatedNow then
        displayRemaining = math.max(rem, 1)
    end
    if roomCleared then displayRemaining = 0 end

    Remotes.GetEvent("DungeonUpdate"):FireClient(player, {
        Biome = curBiome,
        Difficulty = curDiff,
        Floor = curFloor,
        Remaining = displayRemaining,
    })

    -- Clear each floor exactly once: on boss floors a leftover summoned add dying AFTER the boss used
    -- to re-trigger the clear (second chest + portal, and a doubled victory payout on the last floor).
    if roomCleared and not dungeon:GetAttribute("FloorCleared") then
        local modeDef = ItemData.RunMode(curDiff, dungeon:GetAttribute("Endless") == true)
        local maxWaves = modeDef and modeDef.MaxWaves or 10

        -- Title/Achievement tracking: real floor-clear progress (used by the Titles menu's
        -- claim-eligibility checks, see claimTitleFunc below) instead of the old requirement
        -- text describing things that were never actually tracked or checked.
        local st = state.StatsTracking
        if ItemData.RecordFloorClear(st, curDiff, curFloor, dungeon:GetAttribute("BotSkill"), not (state :: any).FloorHitTaken, state.Level) then
            CombatServer.TreeClearBonus(player, state, curDiff)
        end
        CombatServer.RS.Add(player, "Floors"); CombatServer.RS.Max(player, "BestFloor", curFloor)
        local floorStartClock = dungeon:GetAttribute("FloorStartClock")
        local elapsed = floorStartClock and (os.clock() - floorStartClock) or nil
        if elapsed and elapsed < (st.FastestFloorClearSeconds or math.huge) then
            st.FastestFloorClearSeconds = elapsed
        end
        CombatServer.ContractEvent(player, state, "FloorClear", 1, {
            Difficulty = curDiff, Mods = dungeon:GetAttribute("Mods"), Elapsed = elapsed, NoHit = not (state :: any).FloorHitTaken,
            Biome = dungeon:GetAttribute("Biome"), -- (UPDATE 7 ARCHIVE: WORLDS)
        })
        CombatServer.AddSeasonXP(player, state, require(game.ReplicatedStorage.AimRngShared.Seasons).XP.FloorClear)

        -- Check if Dungeon is Completed!
        if curFloor >= maxWaves and not (modeDef and modeDef.Endless) then
            -- Trimmed in line with the general pacing pass (was 2500/120) -- still a big one-time
            -- milestone payout for finishing an entire difficulty, just not quite as game-changing.
            state.Gold += 1800
            GrantMaterials(player, state, { Prism = 4, ReforgeToken = 2, TuningKit = 1, AffixSeal = 1, Schematic = 2, InfusionCore = 1, PurgeSalt = 1 })
            state.RunKeep = true -- finished the run: your run loot is kept
            CombatServer.RecordRunFinished(player, state, curDiff)
            Remotes.GetEvent("DungeonVictory"):FireClient(player, curDiff, curFloor)
        end

        -- The client builds the victory chest + portal when it sees FloorCleared (leftover adds are dismissed).
        DungeonRuns.MarkFloorCleared(player)
    end
end

local function ProcessEnemyKill(player: Player, state: PlayerState, model: Instance, stats: any)
    -- Hub practice dummies are for warming up only: no XP, gold, loot or kill credit -- just respawn.
    if model:GetAttribute("IsPracticeDummy") then
        local spawnPos = model:GetAttribute("SpawnPos") :: Vector3?
        model:Destroy()
        if spawnPos then
            task.delay(2.5, function()
                local HubGen = require(script.Parent:WaitForChild("HubGenerator"))
                HubGen.SpawnSinglePracticeDrone(spawnPos)
            end)
        end
        return
    end

    -- RUN SUMMARY: the kill counts for whoever landed it
    CombatServer.RS.Add(player, "Kills")
    if model:GetAttribute("IsBoss") then CombatServer.RS.Add(player, "Bosses") elseif model:GetAttribute("IsElite") then CombatServer.RS.Add(player, "Elites") end
    -- Party dungeon: every member gets the full kill rewards and their own loot rolls.
    local partyRun = PartyRuns.RunOfModel(model)
    if partyRun then
        for _, member in ipairs(partyRun.Members) do
            if member.Parent then
                local ms = CombatServer.GetState(member)
                local mstats = (member == player) and stats or StatCalculator.Calculate(ms.EquippedWeapon, ms.AllocatedNodes, ms.Streak, ms.Level, ms.Attributes, ms.EquippedGear, ms.EquippedTitle, ms.SocketedGems, ms.RunBoons, ms)
                CombatServer.SafeCall("KillRewards", GiveKillRewards, member, ms, model, mstats) -- (LIVE FIX)
                if member ~= player then Remotes.GetEvent("SyncPlayerState"):FireClient(member, ms) end
            end
        end
        task.delay(0.15, function() if model.Parent then model:Destroy() end end) -- (0.53: Dead replicates first -> the client's death animation)
        PartyRuns.OnEnemyKilled(partyRun, model)
        return
    end

    CombatServer.SafeCall("KillRewards", GiveKillRewards, player, state, model, stats) -- (LIVE FIX: an error here never skips the count below)
    local isBoss = (model:GetAttribute("IsBoss") == true)

    local isPractice = model:GetAttribute("IsPracticeDummy")
    local spawnPos = model:GetAttribute("SpawnPos") :: Vector3?

    local isGoblinKill = model:GetAttribute("IsLootGoblin") == true or model:GetAttribute("Uncounted") == true -- (goblins + the bounty contract don't count toward clearing the floor)
    local wasProxy = DungeonRuns.IsProxy(model)
    if wasProxy then DungeonRuns.OnProxyKilled(model) else model:Destroy() end

    if isPractice and spawnPos then
        task.delay(2.5, function()
            local HubGen = require(script.Parent:WaitForChild("HubGenerator"))
            HubGen.SpawnSinglePracticeDrone(spawnPos)
        end)
    else
        local run = DungeonRuns.Get(player)
        local dungeon = run and run.Folder -- the player's private run (same attribute names as the old shared dungeon)
        if dungeon and wasProxy and not isGoblinKill then
            local rem = math.max(0, (dungeon:GetAttribute("RemainingEnemies") or 1) - 1)
            dungeon:SetAttribute("RemainingEnemies", rem)

            CombatServer.FloorCount(player, state, dungeon, isBoss, rem)
        end
    end
end

-- ==================== ENEMY DAMAGE, STATUS EFFECTS & PROCS ====================
-- Every source of damage to an enemy (gun hits, DoT ticks, explosions, arcs, melee) goes through
-- DealEnemyDamage, so Decay / Freeze bonuses, execute thresholds, health bars, damage numbers and the
-- kill pipeline (XP, loot, room-clear counting) behave identically no matter what dealt the damage.
local CollectionService = game:GetService("CollectionService")
local HitConfirmedEv = Remotes.GetEvent("HitConfirmed")
-- (0.58 hit numbers) a short per-enemy key so the client stacks every hit on one enemy into one number, even while it moves
CombatServer.HitKeys = setmetatable({}, { __mode = "k" })
CombatServer.HitKeyN = 0
function CombatServer.HitKey(model: Instance): number
    local k = CombatServer.HitKeys[model]
    if not k then
        CombatServer.HitKeyN += 1
        k = CombatServer.HitKeyN
        CombatServer.HitKeys[model] = k
    end
    return k
end
local SyncStateEv = Remotes.GetEvent("SyncPlayerState")
local PROC = ItemData.PROC
-- (UPDATE 8 OFFENSE) the five damage types (AimRngShared/DamageTypes) -- a field, not a local (this chunk's locals are tight)
CombatServer.DT = require(game:GetService("ReplicatedStorage"):WaitForChild("AimRngShared"):WaitForChild("DamageTypes"))

type EnemyStatus = {
    Burns: { any }, Bleeds: { any }, Colds: { any },
    ChillUntil: number, ChillSlow: number, FrozenBonus: boolean,
    SlowUntil: number, SlowPct: number,
    DecayUntil: number, DecayInc: number,
    Flags: { [string]: boolean },
}
local enemyStatus: { [Instance]: EnemyStatus } = {}

local function GetStatus(model: Instance): EnemyStatus
    local st = enemyStatus[model]
    if not st then
        st = { Burns = {}, Bleeds = {}, Colds = {}, ChillUntil = 0, ChillSlow = 0, FrozenBonus = false,
            SlowUntil = 0, SlowPct = 0, DecayUntil = 0, DecayInc = 0, Flags = {},
            -- (UPDATE 8 OFFENSE) Shock (Volt), Wither stacks (Void), Freeze build-up (Cryo), bleed movement check
            ShockUntil = 0, ShockInc = 0, Withers = {}, ChillBuild = 0, ChillBuildAt = 0, FreezeReadyAt = 0, FrozenUntil = 0 } :: any
        enemyStatus[model] = st
    end
    return st
end

local function EnemyRootPos(model: Instance): Vector3?
    if DungeonRuns.IsProxy(model) then return DungeonRuns.PosOf(model) end
    local m = model :: Model
    local root = m.PrimaryPart or m:FindFirstChild("Torso")
    if root and root:IsA("BasePart") then return root.Position end
    return nil
end

local function UpdateHealthBar(model: Instance, newHealth: number, maxHealth: number)
    local hud = model:FindFirstChild("HealthHUD")
    local bg = hud and hud:FindFirstChild("Background")
    local fill = bg and bg:FindFirstChild("Fill")
    if fill and fill:IsA("Frame") then fill.Size = UDim2.new(math.clamp(newHealth / maxHealth, 0, 1), 0, 1, 0) end
end

-- Damage-taken multiplier from debuffs currently on the enemy (and its own shields/armor attribute).
local function EnemyTakenMult(model: Instance): number
    local m = (model:GetAttribute("DamageTakenMult") or 1) * (model:GetAttribute("ModTakenMult") or 1) -- Glass Arena
    if model:GetAttribute("Exposed") then m *= 1.4 end -- (0.63 EXPOSED bot: DungeonRuns rotation, +40% taken)
    local st = enemyStatus[model]
    if st then
        local now = os.clock()
        if now < st.DecayUntil then m *= (1 + st.DecayInc) end
        if st.FrozenBonus and now < st.ChillUntil then m *= 1.15 end
        -- (UPDATE 8 OFFENSE) Shock = increased damage taken for a few seconds; Wither = stacks of increased damage taken
        local sx: any = st
        if sx.ShockUntil and now < sx.ShockUntil then m *= (1 + sx.ShockInc) end
        if sx.SMMark and now < sx.SMMark.Until then m *= (1 + sx.SMMark.Inc) end -- (UPDATE 8 OFFENSE phase 3: the Mark mod)
        if sx.SigSup then m *= CombatServer.CB.Sig.TakenMult(sx, now) end -- (CLASS BUILDS) SIGNATURE: Suppressor
        if sx.Withers and #sx.Withers > 0 then
            local w = 0
            for _, e in ipairs(sx.Withers) do if e.Until > now then w += e.Inc end end
            m *= 1 + math.min(CombatServer.DT.WITHER.Cap, w)
        end
    end
    return m
end

local ProcessEnemyKillRef: any = ProcessEnemyKill
local OnKillEffectsRef: any = nil -- set below (passive tree / gem kill effects)

-- opts: Kind ("Hit"|"Burn"|"Bleed"|"Freeze"|"Explosion"|"Arc"|"Melee"), Position, IsWeakSpot, IsCrit,
--       Cull (execute threshold, fraction of max HP), Show (false = no damage number), NoTakenMult.
-- Returns damage dealt and whether it killed.
local function DealEnemyDamage(player: Player, state: any, model: Instance, amount: number, stats: any, opts: any?): (number, boolean)
    local o = opts or {}
    if not model.Parent or model:GetAttribute("Dead") then return 0, false end
    -- (2026-10-26 ARRIVAL FX) a bot still warping in (its first ArrivalFx.IMMUNE_S) isn't there yet: nothing hurts it
    if model:GetAttribute("WarpIn") ~= nil and require(game.ReplicatedStorage.AimRngShared.ArrivalFx).Forming(model) then return 0, false end
    local hp = model:GetAttribute("Health")
    local maxHp = model:GetAttribute("MaxHealth")
    if type(hp) ~= "number" or type(maxHp) ~= "number" or hp <= 0 then return 0, false end

    -- a party enemy takes your hit in YOUR level's terms (PartyScale); what you're shown / leech from is your own scale
    local ps = (model:GetAttribute("RunId") ~= nil) and PartyScale(player) or 1
    local dmg = amount * ps * (o.NoTakenMult and 1 or EnemyTakenMult(model))
    dmg = math.max(0.1, math.round(dmg * 10) / 10)
    -- (ENEMY ATTACKS PILOT elite mod SHELLED) a typed shell soaks the hit first (the matching type breaks it faster; BotRoles)
    local toLife = dmg
    if model:GetAttribute("ShellType") then
        CombatServer.BotRoles = CombatServer.BotRoles or require(game.ReplicatedStorage.AimRngShared.BotRoles)
        toLife = CombatServer.BotRoles.ShellAbsorb(model, dmg, stats, o.Kind)
    end
    local newHp = math.max(0, hp - toLife)

    local culled = false
    local hitDmg = dmg -- damage before any execute, used for procs / leech / splash
    local cull = o.Cull or 0
    if newHp > 0 and cull > 0 and model:GetAttribute("IsBoss") ~= true and not ((model:GetAttribute("ShellHp") or 0) > 0) then
        local threshold = cull * ((model:GetAttribute("IsElite") == true) and 0.5 or 1)
        if newHp / maxHp <= threshold then
            dmg += newHp
            newHp = 0
            culled = true
        end
    end

    if model:GetAttribute("DpsDummy") then
        -- Training Grounds DPS test target: never dies; every hit / tick is reported to its shooter
        newHp = maxHp
        culled = false
        Remotes.GetEvent("DpsTick"):FireClient(player, dmg, o.Kind or "Hit", o.IsCrit == true, o.IsWeakSpot == true)
    end
    model:SetAttribute("Health", newHp)
    -- (MAP PACING 2026-10-31 BUG FIX) when it was last hurt: Warded / Mending / Regenerating heal only after a few seconds WITHOUT a
    -- hit, and they read HurtAt -- nothing ever wrote it, so they healed under fire (a Warded T12 floor took 2x as long)
    do
        local tnow = os.clock()
        if tnow - (model:GetAttribute("HurtAt") or 0) > 0.2 then model:SetAttribute("HurtAt", tnow) end
    end
    UpdateHealthBar(model, newHp, maxHp)

    if o.Show ~= false then
        local hitData = {
            Damage = math.round(dmg / ps * 10) / 10, Kind = o.Kind or "Hit", Culled = culled,
            IsWeakSpot = o.IsWeakSpot == true, IsCrit = o.IsCrit == true, Elem = o.Elem,
            CurrentStreak = state.Streak, Position = o.Position or EnemyRootPos(model) or Vector3.zero,
            Killed = (newHp <= 0), Target = CombatServer.HitKey(model),
            -- (UPDATE 8 OFFENSE) the hit's main damage type (damage-number colour); DoTs = their ailment's type
            DType = o.DType or CombatServer.DT.AILMENT_TYPE[o.Kind or ""] or nil,
        }
        HitConfirmedEv:FireClient(player, hitData)
        if player:GetAttribute("Spectators") then -- (0.83: their watchers see the hit as they did)
            pcall(function() require(script.Parent:WaitForChild("SpectateService")).RelayHit(player, hitData) end)
        end
    end

    if not model:GetAttribute("DpsDummy") then CombatServer.RS.Damage(player, hitDmg / ps, (o.Kind or "Hit") == "Hit") end
    if o.Kind == "Bleed" and stats then CombatServer.CB.Sig.BleedLeech(player, state, stats, hitDmg / ps) end -- (CLASS BUILDS) SIGNATURE: Bloodstorm leech
    if newHp <= 0 then
        model:SetAttribute("Dead", true)
        if not model:GetAttribute("IsPracticeDummy") then -- (lifetime stats: your own killing blows, and those on a weak spot)
            CombatServer.Life(state, "OwnKills")
            if o.IsWeakSpot == true then CombatServer.Life(state, "WeakSpotKills") end
            if (o.Kind or "Hit") == "Hit" then -- (UPDATE 7 CALIBRATION: gun killing blows only)
                if o.IsWeakSpot == true then pcall(CombatServer.CalibrationFeat, player, state, "WeakKills", model:GetAttribute("Fodder") and Progression.FODDER_MASTERY or 1) end -- (UPDATE 8: fodder counts 1/5)
                if model:GetAttribute("EliteTier") then pcall(CombatServer.CalibrationFeat, player, state, "EliteKills", 1) end
            end
        end
        player:SetAttribute("KillPulse", (player:GetAttribute("KillPulse") or 0) + 1) -- (other players' clients: glove kill effects)
        if OnKillEffectsRef then CombatServer.SafeCall("KillEffects", OnKillEffectsRef, player, state, model, stats, maxHp, o.Depth or 0) end -- (LIVE FIX)
        enemyStatus[model] = nil
        CombatServer.SafeCall("EnemyKill", ProcessEnemyKillRef, player, state, model, stats) -- (LIVE FIX: DungeonRuns.Reconcile catches a count it skipped)
        if o.Kind and o.Kind ~= "Hit" then
            SyncStateEv:FireClient(player, state) -- the hit handler syncs its own kills
        end
        return hitDmg / ps, true
    end
    return hitDmg / ps, false
end
CombatServer.DealEnemyDamage = DealEnemyDamage -- (DevCommands "killall")

-- Every live enemy within radius of a point: hub practice targets (real server models) plus the owner's
-- own private-dungeon enemies (never another player's -- every dungeon sits at the same coordinates).
local function EnemiesNear(center: Vector3, radius: number, exclude: Instance?, owner: Player?): { Instance }
    local out = {}
    local myRun = owner and owner:GetAttribute("RunId")
    local function consider(m: Instance)
        if m:GetAttribute("RunId") ~= myRun and not DungeonRuns.IsProxy(m) then return end -- another party's enemy
        if m ~= exclude and m.Parent and not m:GetAttribute("Dead") and (m:GetAttribute("Health") or 0) > 0 then
            local pos = EnemyRootPos(m)
            if pos and (pos - center).Magnitude <= radius then table.insert(out, m) end
        end
    end
    for _, m in ipairs(CollectionService:GetTagged("AimRngEnemy")) do consider(m) end
    if owner then
        for _, m in ipairs(DungeonRuns.EnemiesOf(owner)) do consider(m) end
    end
    return out
end

-- Effects are drawn by the owner's client only (other players may be in their own dungeon at these coordinates).
local CombatFxEv = Remotes.GetEvent("CombatFx")
local function BlastFx(player: Player, center: Vector3, radius: number, color: Color3)
    CombatFxEv:FireClient(player, "Blast", center, radius, color)
end
-- Area damage around a point (explosions, detonations, vortexes). falloff = true scales 100% -> 40% at the edge.
-- depth: how deep in a kill chain this blast is (kill explosions / shatters stop chaining at 3).
-- primary: the enemy whose hit caused the blast -- always caught in it at full damage, even when the blast
-- center (the bullet's impact point) is farther than the radius from a big enemy's middle (bosses).
local function Explode(player: Player, state: any, stats: any, center: Vector3, damage: number, radius: number, color: Color3, kind: string, exclude: Instance?, falloff: boolean?, depth: number?, primary: Instance?)
    BlastFx(player, center, radius, color)
    local total = 0
    local targets = EnemiesNear(center, radius, exclude, player)
    if primary and primary ~= exclude and primary.Parent and not primary:GetAttribute("Dead") and not table.find(targets, primary) then
        table.insert(targets, primary)
    end
    for _, m in ipairs(targets) do
        local mult = 1
        if falloff and m ~= primary then
            local pos = EnemyRootPos(m)
            if pos then mult = 1 - 0.6 * math.clamp((pos - center).Magnitude / radius, 0, 1) end
        end
        total += DealEnemyDamage(player, state, m, damage * mult, stats, { Kind = kind, Depth = depth })
    end
    state.StatsTracking.ExplosiveDamageDealt += total
end

local function ArcFx(player: Player, a: Vector3, b: Vector3, color: Color3)
    CombatFxEv:FireClient(player, "Arc", a, b, color)
end
-- ----- applying effects -----
-- maxStacks: 1 = only the strongest burn burns; Wildfire 3; Ember Heart 20.
local function ApplyBurn(owner: Player, model: Instance, total: number, duration: number, maxStacks: number)
    if total <= 0 or duration <= 0 then return end
    local st = GetStatus(model)
    local now = os.clock()
    local entry = { Owner = owner, Dps = total / duration, Until = now + duration }
    for i = #st.Burns, 1, -1 do if st.Burns[i].Until <= now then table.remove(st.Burns, i) end end
    if maxStacks > 1 then
        table.insert(st.Burns, entry)
        if #st.Burns > maxStacks then
            table.sort(st.Burns, function(a, b) return a.Dps > b.Dps end)
            table.remove(st.Burns)
        end
    elseif #st.Burns == 0 or entry.Dps >= st.Burns[1].Dps then
        st.Burns = { entry } -- only the strongest burn burns
    end
end

local function ApplyBleed(owner: Player, model: Instance, total: number, duration: number, maxStacks: number?)
    if total <= 0 or duration <= 0 then return end
    local st = GetStatus(model)
    local now = os.clock()
    for i = #st.Bleeds, 1, -1 do if st.Bleeds[i].Until <= now then table.remove(st.Bleeds, i) end end
    table.insert(st.Bleeds, { Owner = owner, Dps = total / duration, Until = now + duration })
    if #st.Bleeds > (maxStacks or PROC.BleedMaxStacks) then
        table.sort(st.Bleeds, function(a, b) return a.Dps > b.Dps end)
        table.remove(st.Bleeds)
    end
end

local function ApplyChill(owner: Player, model: Instance, slow: number, total: number, duration: number, frozenBonus: boolean)
    local st = GetStatus(model)
    local now = os.clock()
    if now >= st.ChillUntil then st.ChillSlow = 0 end
    st.ChillSlow = math.max(st.ChillSlow, slow)
    st.ChillUntil = math.max(st.ChillUntil, now + duration)
    st.FrozenBonus = st.FrozenBonus or frozenBonus
    if total > 0 then
        local entry = { Owner = owner, Dps = total / duration, Until = now + duration }
        if #st.Colds == 0 or st.Colds[1].Until <= now or entry.Dps >= st.Colds[1].Dps then st.Colds = { entry } end
    end
end

local function ApplySlow(model: Instance, slow: number, duration: number)
    local st = GetStatus(model)
    local now = os.clock()
    if now >= st.SlowUntil then st.SlowPct = 0 end
    st.SlowPct = math.max(st.SlowPct, slow)
    st.SlowUntil = math.max(st.SlowUntil, now + duration)
end

local function ApplyDecay(model: Instance, inc: number, duration: number)
    local st = GetStatus(model)
    local now = os.clock()
    if now >= st.DecayUntil then st.DecayInc = 0 end
    st.DecayInc = math.max(st.DecayInc, inc)
    st.DecayUntil = math.max(st.DecayUntil, now + duration)
end

-- Status tick: DoT damage every 0.5s, slow + visual-flag attributes kept in sync for enemy AI / clients.
local STATUS_TICK = 0.5
task.spawn(function()
    while true do
        task.wait(STATUS_TICK)
        local now = os.clock()
        local ownerCache: { [Player]: any } = {}
        local function OwnerCtx(p: Player): any
            local c = ownerCache[p]
            if c == nil then
                if p.Parent then
                    local ps = CombatServer.GetState(p)
                    c = { State = ps, Stats = StatCalculator.Calculate(ps.EquippedWeapon, ps.AllocatedNodes, ps.Streak, ps.Level, ps.Attributes, ps.EquippedGear, ps.EquippedTitle, ps.SocketedGems, ps.RunBoons, ps) }
                else
                    c = false
                end
                ownerCache[p] = c
            end
            return c
        end
        for model, st in pairs(enemyStatus) do
            if not model.Parent or model:GetAttribute("Dead") then
                enemyStatus[model] = nil
                continue
            end
            local perOwner: { [Player]: { [string]: number } } = {}
            local function Accumulate(list: { any }, kind: string)
                for i = #list, 1, -1 do
                    local e = list[i]
                    if e.Until <= now then
                        table.remove(list, i)
                    else
                        perOwner[e.Owner] = perOwner[e.Owner] or {}
                        perOwner[e.Owner][kind] = (perOwner[e.Owner][kind] or 0) + e.Dps * STATUS_TICK
                    end
                end
            end
            Accumulate(st.Burns, "Burn")
            Accumulate(st.Bleeds, "Bleed")
            Accumulate(st.Colds, "Freeze")
            local sx: any = st -- (UPDATE 8 OFFENSE: bleed is worse on a moving target; Wither stacks run out one by one)
            if #st.Bleeds > 0 then
                local pos = EnemyRootPos(model)
                local B = CombatServer.DT.BLEED
                local f = (pos and sx.BleedPos and (pos - sx.BleedPos).Magnitude > B.MoveDist) and B.Moving or B.Still
                sx.BleedPos = pos
                for _, kinds in pairs(perOwner) do if kinds.Bleed then kinds.Bleed *= f end end
            end
            if sx.Withers then for i = #sx.Withers, 1, -1 do if sx.Withers[i].Until <= now then table.remove(sx.Withers, i) end end end

            local slow = 0
            if now < st.ChillUntil then slow = st.ChillSlow end
            if now < st.SlowUntil then slow = math.max(slow, st.SlowPct) end
            local mult = math.round((1 - slow) * 100) / 100
            if model:GetAttribute("SlowMult") ~= mult then model:SetAttribute("SlowMult", mult) end
            local flags = {
                Burning = #st.Burns > 0, Bleeding = #st.Bleeds > 0,
                Chilled = now < st.ChillUntil or now < st.SlowUntil, Decayed = now < st.DecayUntil,
                Frozen = now < (sx.FrozenUntil or 0), Shocked = now < (sx.ShockUntil or 0),
                Withered = sx.Withers ~= nil and #sx.Withers > 0,
            }
            for k, v in pairs(flags) do
                if st.Flags[k] ~= v then
                    st.Flags[k] = v
                    model:SetAttribute(k, v)
                end
            end

            for owner, kinds in pairs(perOwner) do
                local ctx = OwnerCtx(owner)
                if ctx then
                    for kind, amount in pairs(kinds) do
                        if amount > 0 and model.Parent and not model:GetAttribute("Dead") then
                            DealEnemyDamage(owner, ctx.State, model, amount, ctx.Stats, { Kind = kind })
                        end
                    end
                end
            end

            if #st.Burns == 0 and #st.Bleeds == 0 and #st.Colds == 0 and now >= st.ChillUntil and now >= st.SlowUntil and now >= st.DecayUntil
                and now >= (sx.ShockUntil or 0) and not (sx.Withers and #sx.Withers > 0) and now - (sx.ChillBuildAt or 0) > CombatServer.DT.FREEZE.Window then
                if model:GetAttribute("SlowMult") ~= 1 then model:SetAttribute("SlowMult", 1) end
                enemyStatus[model] = nil
            end
        end
    end
end)

-- Burn / Bleed stack caps from keystones and gems.
local function BurnStackCap(mech: any): number
    return (mech.EMBER_HEART and 20) or (mech.WILDFIRE and 3) or 1
end
local function BleedStackCap(stats: any, mech: any): number
    local sigCap = CombatServer.CB and CombatServer.CB.Sig and CombatServer.CB.Sig.BleedCap(stats) -- (CLASS BUILDS) SIGNATURE: Bloodstorm
    local base = (mech.HYDRA_COIL and 10) or (mech.CRIMSON_DANCE and 8) or PROC.BleedMaxStacks
    return math.max(sigCap or 0, base + math.floor((stats.Cond and stats.Cond.BleedStacks) or 0)) -- ((CLASS BUILDS) PART B: the sig cap never lowers a bigger one)
end

-- One ailment / explosion from any source (weapon prefix, keystone, passive-tree "on hit" chance).
-- blast = the hit's damage (a whole shotgun blast); pw = strength (the weapon prefix's Power, 1 for the tree).
local function InflictAilment(id: string, player: Player, state: any, stats: any, model: Instance, blast: number, hitPos: Vector3, pw: number)
    local mech = stats.SpecialMechanics or {}
    local dur = 1 + (stats.AilmentDuration or 0)
    if id == "Burn" then
        local mult = mech.EMBER_HEART and 0.6 or 1
        ApplyBurn(player, model, blast * PROC.BurnPct * pw * (1 + stats.BurnDamage) * mult, PROC.BurnDuration * dur, BurnStackCap(mech))
    elseif id == "Freeze" then
        local slow = math.min(PROC.FreezeSlowCap, PROC.FreezeSlow * pw * (1 + stats.FreezeEffect))
        if mech.ABSOLUTE_ZERO then slow = math.min(0.7, slow * 2) end
        ApplyChill(player, model, slow, blast * PROC.FreezePct * pw * (1 + stats.FreezeEffect), PROC.FreezeDuration * dur, mech.ABSOLUTE_ZERO == true)
        if mech.GLACIAL_WARD then -- (hybrid keystone: chills harden you -- read in DamagePlayer)
            local s: any = state
            local now = os.clock()
            if now > (s._WardUntil or 0) then s._WardStacks = 0 end
            s._WardStacks = math.min(8, (s._WardStacks or 0) + 1)
            s._WardUntil = now + 5
        end
        if mech.GLACIAL_TOMB and model:GetAttribute("IsBoss") ~= true then ApplySlow(model, 1.0, 1.0) end
    elseif id == "Bleed" then
        ApplyBleed(player, model, blast * PROC.BleedPct * pw * (1 + stats.BleedDamage), PROC.BleedDuration * dur, BleedStackCap(stats, mech))
    elseif id == "Decay" then
        ApplyDecay(model, math.min(PROC.DecayCap, PROC.DecayInc * pw * (1 + stats.DecayEffect)), PROC.DecayDuration * dur)
    elseif id == "Chill" then -- (UPDATE 8 OFFENSE: the new name of the old Freeze proc's chill)
        InflictAilment("Freeze", player, state, stats, model, blast, hitPos, pw)
    elseif id == "Shock" or id == "Wither" then -- (UPDATE 8 OFFENSE: Volt / Void; blast = the hit's part of that type)
        local DT = CombatServer.DT
        local maxHp = model:GetAttribute("MaxHealth") or 0
        local st: any = GetStatus(model)
        local now = os.clock()
        if id == "Shock" then
            local inc = DT.ShockEffect(blast * pw, maxHp, stats.ShockEffect)
            if now >= (st.ShockUntil or 0) then st.ShockInc = 0 end
            st.ShockInc = math.min(DT.SHOCK.Max * (1 + (stats.ShockEffect or 0)), math.max(st.ShockInc or 0, inc))
            st.ShockUntil = math.max(st.ShockUntil or 0, now + DT.SHOCK.Duration * dur)
        else
            local inc = DT.WitherStack(blast * pw, maxHp, (stats.WitherEffect or 0) + (stats.DecayEffect or 0))
            st.Withers = st.Withers or {}
            table.insert(st.Withers, { Inc = inc, Until = now + DT.WITHER.Duration * dur })
            if #st.Withers > DT.WITHER.MaxStacks then table.remove(st.Withers, 1) end
        end
    elseif id == "Echo" or id == "Explosive" then
        -- (no splash -- 2026-10-02 precision rework: the hit echoes into the same enemy)
        if model.Parent and not model:GetAttribute("Dead") then
            DealEnemyDamage(player, state, model, blast * PROC.EchoPct * pw, stats, { Kind = "Arc" })
        end
    end
end

-- ===== (UPDATE 8 OFFENSE) TYPED HITS: enemy resistances + ailments by damage type (docs/UPDATE8.md) =====
CombatServer.Off = {}
-- an enemy's resistances: the stamped Res_<Type> attrs (DungeonGenerator.StampResists, copied to stand-ins), else (hub
-- targets, anything built outside CreateOfKind) from its Element / the floor's biome like the old matchups; dummies none
function CombatServer.Off.Resists(model: Instance, player: Player): { [string]: number }?
    local DT = CombatServer.DT
    if model:GetAttribute("ResSet") then return DT.ReadResists(model) end
    if model:GetAttribute("IsPracticeDummy") or model:GetAttribute("DpsDummy") then return nil end
    local biome = DungeonRuns.Attr(player, "Biome")
    local rid = model:GetAttribute("RunId")
    if rid then
        local pf = workspace:FindFirstChild("PartyRuns")
        local f = pf and pf:FindFirstChild("Run_" .. tostring(rid))
        biome = (f and f:GetAttribute("Biome")) or biome
    end
    local el = model:GetAttribute("Element")
    local key = ItemData.EnemyAffinity(el, biome)
    if not key then return nil end
    return DT.EnemyResists(key, nil, model:GetAttribute("IsBoss") == true)
end
-- after a hit lands: parts = the hit's type shares after resists (any scale); hitDmg = the damage dealt (one pellet).
-- Per type: Cryo always builds toward a Freeze; then a chance roll per type (DamageTypes.AILMENT_BASE_CHANCE x the type's
-- share + the build's chance stat, x the gun's proc-rate factor x (1 + Proc Chance), / pellets) -> that type's ailment
-- with magnitude from the hit's part (Bleed / Burn / Chill use the DoT-parity share like the old procs).
CombatServer.Off.TYPE_AILMENT = { Kinetic = "Bleed", Heat = "Burn", Cryo = "Freeze", Volt = "Shock", Void = "Wither" }
function CombatServer.Off.TypeAilments(player: Player, state: any, stats: any, weapon: any, model: Instance, hitDmg: number, hitPos: Vector3, pellets: number, parts: { [string]: number }?)
    if not parts or not model.Parent or model:GetAttribute("Dead") or (hitDmg or 0) <= 0 then return end
    local DT = CombatServer.DT
    local sum = 0
    for _, t in ipairs(DT.ORDER) do sum += parts[t] or 0 end
    if sum <= 0 then return end
    local maxHp = model:GetAttribute("MaxHealth") or 0
    local rate = ItemData.ProcRateFactor(weapon)
    local chances = stats.AilChanceByType or {}
    local now = os.clock()
    for _, t in ipairs(DT.ORDER) do
        local share = (parts[t] or 0) / sum
        -- (Cornerstone Overload: every hit rolls Burn / Chill / Shock / Wither as if it were half that type)
        if stats.Overload and t ~= "Kinetic" then share = math.max(share, 0.5) end
        if share > 0 then
            local part = hitDmg * share
            -- (gear line VoltCanFreeze, DEFENCE: stats.VoltCanFreeze > 0 = Volt damage also builds Freeze, x that value)
            local freezePart = (t == "Cryo") and (part + hitDmg * ((parts.Volt or 0) / sum) * math.max(0, stats.VoltCanFreeze or 0)) or 0
            if t == "Volt" and (parts.Cryo or 0) <= 0 and (stats.VoltCanFreeze or 0) > 0 then freezePart = part * stats.VoltCanFreeze end
            freezePart *= (type(stats.ShotFx) == "table" and stats.ShotFx.FreezeBuild) or 1 -- (Frostbite mod / Glacial Shells: faster Freeze)
            if freezePart > 0 and maxHp > 0 then -- FREEZE build-up (no roll): Cryo (+ Volt) damage as a share of max health within the window
                local st: any = GetStatus(model)
                local F = DT.FREEZE
                local age = now - (st.ChillBuildAt or 0)
                st.ChillBuild = (st.ChillBuild or 0) * math.max(0, 1 - age / F.Window) + freezePart / maxHp
                st.ChillBuildAt = now
                if st.ChillBuild >= F.BuildPct and now >= (st.FreezeReadyAt or 0) then
                    local dur = F.Duration * (1 + (stats.AilmentDuration or 0))
                    ApplySlow(model, model:GetAttribute("IsBoss") == true and F.BossSlow or 1.0, dur)
                    st.FrozenUntil = now + dur
                    st.FreezeReadyAt = now + dur + F.Cooldown
                    st.ChillBuild = 0
                end
            end
            local chance = (DT.AILMENT_BASE_CHANCE[t] * share + (chances[t] or 0)) * rate * (1 + (stats.AilmentChance or 0))
            chance = math.clamp(chance, 0, DT.AILMENT_MAX_CHANCE) / pellets
            local sigPel = CombatServer.CB.Sig.PelletBleed(stats, t, pellets); if sigPel then chance *= pellets end -- (CLASS BUILDS) SIGNATURE: Bloodstorm (per pellet)
            if chance > 0 and math.random() < chance then
                local id = CombatServer.Off.TYPE_AILMENT[t]
                local blast = (id == "Shock" or id == "Wither") and part * pellets or part * pellets / rate
                if sigPel then blast /= pellets end -- (CLASS BUILDS) SIGNATURE: Bloodstorm (one pellet's Bleed)
                InflictAilment(id, player, state, stats, model, blast, hitPos, 1)
            end
        end
    end
end

-- Passive-tree "chance to X on hit": works with any gun. Same per-hit scaling as a weapon prefix (slow guns
-- get a bigger chance per shot), boosted by Proc Chance, split across shotgun pellets.
local TREE_PROCS = { { "BurnOnHit", "Burn" }, { "ChillOnHit", "Freeze" }, { "BleedOnHit", "Bleed" }, { "DecayOnHit", "Decay" } }

-- Rolls the equipped weapon's prefix, keystone procs and passive-tree on-hit chances for one hit.
-- hitDmg = damage of this hit (a single pellet for shotguns; the effect uses the whole blast so shotguns
-- aren't penalized).
local function RollOnHitEffects(player: Player, state: any, stats: any, weapon: any, model: Instance, hitDmg: number, hitPos: Vector3, pellets: number)
    local mech = stats.SpecialMechanics or {}
    local blast = hitDmg * pellets
    -- DOT PARITY (owner 2026-10-05: "The way DoTs work is based off of the hit, so that makes them scale far more than
    -- something like an ar"): a slow gun procs ProcRateFactor x more often per hit (up to 3x), and each proc's burn / bleed /
    -- chill / echo is a share of that (big) hit -- so its damage over time was DPS x chance x share: a sniper's Burning
    -- prefix added ~53% DPS, an AR's ~8%. The damage part is divided by the same factor, so every gun's damage over time
    -- is the same share of its DPS (Burn ~18% at Power 1); slow guns still proc more often (Decay / slows unchanged).
    local dotBlast = blast / ItemData.ProcRateFactor(weapon)
    local proc = weapon and weapon.Proc
    local def = proc and ItemData.WeaponProcs[proc.Id]
    if def and def.Chance < 1 then
        local chance = ItemData.ProcChance(weapon, stats.AilmentChance) / pellets
        if math.random() < chance then
            InflictAilment(proc.Id, player, state, stats, model, dotBlast, hitPos, proc.Power or 1)
        end
    end
    local cond = stats.Cond or {}
    local rate = ItemData.ProcRateFactor(weapon)
    for _, tp in ipairs(TREE_PROCS) do
        local base = cond[tp[1]] or 0
        if base > 0 and model.Parent and not model:GetAttribute("Dead") then
            local chance = math.clamp(base * rate * (1 + (stats.AilmentChance or 0)) * (mech.HEX_ROUNDS and 2 or 1), 0, 0.75) / pellets
            if math.random() < chance then InflictAilment(tp[2], player, state, stats, model, dotBlast, hitPos, 1) end
        end
    end
end

-- Nearest live enemies to a point (for ricochets / chains), closest first.
local function NearestEnemies(pos: Vector3, radius: number, exclude: Instance?, player: Player, count: number): { Instance }
    local near = EnemiesNear(pos, radius, exclude, player)
    table.sort(near, function(a, b)
        return ((EnemyRootPos(a) or pos) - pos).Magnitude < ((EnemyRootPos(b) or pos) - pos).Magnitude
    end)
    local out = {}
    for i = 1, math.min(count, #near) do out[i] = near[i] end
    return out
end
-- (CHASE ITEMS 2026-11-06) ZENITH: the server half lives in AimRngServer/ZenithServer (a field: this chunk is near the local limit)
CombatServer.Zen = require(script.Parent:WaitForChild("ZenithServer"))
CombatServer.Zen.Init({
    Deal = DealEnemyDamage, Nearest = NearestEnemies, RootPos = EnemyRootPos, Grant = GrantMaterials,
    ResistMult = function(m: Instance, p: Player, sh: any): number return CombatServer.Off.ResistMult(m, p, sh) end,
    DropGiven = function(p: Player, st: any, it: any, kind: string) CombatServer.DropGiven(p, st, it, kind) end,
    ContentLevel = function(p: Player, st: any): number return CombatServer.ContentLevel(p, st) end,
    Sync = function(p: Player, st: any) Remotes.GetEvent("SyncPlayerState"):FireClient(p, st) end,
})
-- NO CRAFTING DURING A TRADE (owner 2026-11-06): an item offered in an open trade or a duel wager stays in the bag by Uid, so a
-- craft would change it under the other side's READY. Every craft entry point asks this first (ForgeReroll: every Forge mode,
-- UpgradeWeapon, ShotModAction, RiftmodAction): returns the refusal text, or nil. uids = any of the call's item / mod uids.
function CombatServer.TradeHold(player: Player, ...: any): string?
    local svc = script.Parent
    for _, name in ipairs({ "TradeService", "PvpService" }) do
        local m = svc:FindFirstChild(name)
        local okM, mod = pcall(function() return m and require(m) end)
        local offered = okM and type(mod) == "table" and mod.Offered
        if offered then
            for i = 1, select("#", ...) do
                local uid = select(i, ...)
                if type(uid) == "string" and uid ~= "" and offered(player, uid) then return "Finish or cancel your trade first." end
            end
        end
    end
    return nil
end

-- ===== (CLASS BUILDS) CORNERSTONE (TREE builder, docs/CLASS_BUILDS.md section 3; texts in tools/tree_v8.py CB_NEW) =====
-- The three class Cornerstones (each only works with its class's guns: StatCalculator's node Group gate). Fields only.
--   Field Commander (K_FIELD_COMMANDER, Vanguard): 4% more per enemy within 20 studs of you (max 10), 25% less with none.
--   Carom Shot (K_TRICK_SHOT, Gunslinger): StatCalculator fx.Carom -> Off.ShotModFx bounces a weak-spot hit to the nearest
--     enemy's weak spot for 50% of the hit (one hop); body hits x0.8 via BodyShotMult.
--   Slug Rounds (K_SLUG, Breacher): stats.Slug -- one ray, one pellet, the whole shot's damage; distance rules read half the
--     distance (close-range bonuses reach twice as far).
CombatServer.CBCorner = {
    FIELD_R = 20, FIELD_PER = 0.04, FIELD_MAX = 10, FIELD_NONE = 0.75, FIELD_CACHE = 0.25,
    SLUG_REACH = 0.5,
    Near = setmetatable({}, { __mode = "k" }), -- per player: { T = os.clock(), N = count } (one scan per FIELD_CACHE s)
}
CombatServer.CB = CombatServer.CB or {}
CombatServer.CB.Corner = CombatServer.CBCorner
function CombatServer.CBCorner.FieldCount(player: Player): number
    local C = CombatServer.CBCorner
    local c = C.Near[player]
    local now = os.clock()
    if c and now - c.T < C.FIELD_CACHE then return c.N end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local n = 0
    if root and root:IsA("BasePart") then n = math.min(#EnemiesNear(root.Position, C.FIELD_R, nil, player), C.FIELD_MAX) end
    C.Near[player] = { T = now, N = n }
    return n
end
-- a hit's damage before crits (the class-passive spot in the hit handler)
function CombatServer.CBCorner.PreHit(player: Player, state: any, stats: any, mech: any, damage: number): number
    local C = CombatServer.CBCorner
    if mech.K_FIELD_COMMANDER then
        local n = C.FieldCount(player)
        damage *= (n > 0) and (1 + C.FIELD_PER * n) or C.FIELD_NONE
    end
    return damage
end
function CombatServer.CBCorner.Dist(stats: any, d: number?): number?
    if d and stats and stats.Slug then return d * CombatServer.CBCorner.SLUG_REACH end
    return d
end

-- ===== SHOT MODS (UPDATE 8 OFFENSE phase 3; AimRngShared/ShotMods = the data) =====
-- After a gun hit lands, the gun's ACTIVE mods (its largest linked group: StatCalculator -> stats.ShotFx) add what the shot
-- DOES: Chain / Fork / Ricochet / Volley = extra hits on other enemies, Impact = a burst round the hit, Mark, Detonate (on
-- kill, Off.ShotModKill), Pierce (PierceShot). base = the hit before the target's resists and weak spot (the crit stays);
-- every extra hit takes ITS target's resists (Off.ResistMult) x AreaMult (Narrow Bore). Shotguns: one pellet in `pellets`
-- triggers them at x pellets (same average, one set of extra hits a trigger pull). Extra hits never trigger mods again.
-- VISUALS (performance first): each extra hit = one instant tracer line (ArcFx), a burst = one flat quick ring ("Ring");
-- at most one set every SM_FX_GAP s per player (the damage always lands). No flashes, nothing at the crosshair.
CombatServer.Off.SM_FX_GAP = 0.06
CombatServer.Off.SMS = setmetatable({}, { __mode = "k" }) -- per player: { FxAt, Marked }
function CombatServer.Off.SMState(player: Player): any
    local s = CombatServer.Off.SMS[player]
    if not s then s = {}; CombatServer.Off.SMS[player] = s end
    return s
end
-- the share of a hit an enemy keeps after its resists (shares = the hit's type shares)
function CombatServer.Off.ResistMult(model: Instance, player: Player, shares: { [string]: number }): number
    local DT = CombatServer.DT
    local res = CombatServer.Off.Resists(model, player)
    if not res then return 1 end
    local m = 0
    for _, t in ipairs(DT.ORDER) do m += (shares[t] or 0) * (1 - math.clamp(res[t] or 0, DT.ENEMY_RESIST_FLOOR, DT.ENEMY_RESIST_CAP)) end
    return (m > 0) and m or 1
end
-- HEAVY ROUNDS (owner 2026-10-22; ItemData.HEAVY_ROUNDS): a kill's leftover damage jumps to the nearest enemy within
-- HEAVY_HOP_R of the body (nearer the shot line preferred), re-checked against THAT enemy's resists (no weak spot / crit
-- re-applied), and keeps hopping while it kills, up to the gun family's fixed hop count (+1 with OverkillCarry, cap 6).
-- left = the killing hit's damage past the target's health, in the dead target's terms (after its resists). One tracer
-- line a hop (ArcFx), each victim shows its number. Hop kills are Depth 1 (Detonate / Demolition still fire once on them).
-- A shot mod's extra hit (Chain / Fork / Volley / Ricochet / Impact) that kills carries too; one trigger pull has at most
-- HEAVY_MAX_HOPS hops in all (state.HR_Budget, reset per pull). rmPrev = the dead enemy's share kept after its resists.
function CombatServer.Off.HeavyCarry(player: Player, state: any, stats: any, weapon: any, model: Instance, left: number, rmPrev: number, hitPos: Vector3)
    local hops = ItemData.HeavyHops(weapon, stats.Cond and stats.Cond.OverkillCarry)
    local hc = ItemData.HEAVY_CLASS and stats.ClassGun and ItemData.HEAVY_CLASS[stats.ClassGun] -- (Marksman LONG CARRY)
    local reach = hc and hc.R or ItemData.HEAVY_HOP_R
    if hc and hops > 0 then hops = math.min(ItemData.HEAVY_MAX_HOPS, hops + (hc.Hops or 0)) end
    if hops <= 0 or left <= 0 or model:GetAttribute("IsPracticeDummy") then return 0 end
    local hs = state :: any
    if hs.HR_BPull ~= hs.P_ShotAt then hs.HR_BPull, hs.HR_Budget = hs.P_ShotAt, ItemData.HEAVY_MAX_HOPS end
    hops = math.min(hops, hs.HR_Budget or 0)
    if hops <= 0 then return 0 end
    local raw = left / math.max(0.05, rmPrev or 1) -- the leftover before resists
    local shares = stats.DamageShares or { Kinetic = 1 }
    local head = player.Character and player.Character:FindFirstChild("Head")
    local dir = (head and head:IsA("BasePart")) and (hitPos - head.Position) or Vector3.zero
    dir = (dir.Magnitude > 0.1) and dir.Unit or nil
    local from, last, done = EnemyRootPos(model) or hitPos, model, { [model] = true }
    local col = CombatServer.DT.COLOR[stats.DamageType or "Kinetic"] or Color3.new(1, 1, 1)
    local n = 0
    for _ = 1, hops do
        local best, bestScore
        for _, m in ipairs(EnemiesNear(from, reach, last, player)) do
            if not done[m] and not m:GetAttribute("Dead") then
                local p = EnemyRootPos(m)
                if p then
                    local score = (p - from).Magnitude
                    if dir then local rel = p - hitPos; score += (rel - dir * rel:Dot(dir)).Magnitude * 0.5 end
                    if not bestScore or score < bestScore then best, bestScore = m, score end
                end
            end
        end
        if not best then break end
        done[best] = true
        local hp = best:GetAttribute("Health") or 0
        local rm = CombatServer.Off.ResistMult(best, player, shares)
        local amount = raw * rm
        local to = EnemyRootPos(best)
        if to then ArcFx(player, from, to, col) end
        local _, k = DealEnemyDamage(player, state, best, amount, stats, { Kind = "Arc", DType = stats.DamageType, Depth = 1 })
        n += 1
        hs.HR_Budget -= 1
        if not k then break end
        raw = math.max(0, amount - hp) / math.max(0.05, rm)
        if raw <= 0 then break end
        from, last = to or from, best
    end
    return n
end
function CombatServer.Off.Ring(player: Player, center: Vector3, radius: number, color: Color3)
    CombatFxEv:FireClient(player, "Ring", center, radius, color)
end
-- Mark: one marked enemy per player (marking another moves it); it takes Inc more from everyone (EnemyTakenMult)
function CombatServer.Off.MarkEnemy(player: Player, model: Instance, mk: any)
    local s = CombatServer.Off.SMState(player)
    if s.Marked and s.Marked ~= model then
        local o: any = enemyStatus[s.Marked]
        if o and o.SMMark and o.SMMark.Owner == player then o.SMMark = nil end
    end
    local st: any = GetStatus(model)
    st.SMMark = { Owner = player, Inc = mk.Inc, Until = os.clock() + (mk.T or 4), T = mk.T or 4, R = mk.R or 30 }
    s.Marked = model
end
-- (UPDATE 8 OFFENSE phase 4) ATTRIBUTE REQUIREMENTS (ItemData.Requirements): your Strength / Dexterity / Intellect with the
-- loadout you wear now (cached 0.5 s: Equip Best checks many items) against the item's. ok, "Needs 45 Strength"
function CombatServer.Off.Attrs(state: any): { [string]: number }
    local c = (state :: any)._AttrCache
    if c and os.clock() - c.T < 0.5 then return c.A end
    local s = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
    local a = ItemData.AttrTotals(s);
    (state :: any)._AttrCache = { T = os.clock(), A = a }
    return a
end
function CombatServer.Off.ReqOk(state: any, item: any): (boolean, string?)
    return ItemData.MeetsReq(item, CombatServer.Off.Attrs(state), state.Level)
end
function CombatServer.Off.ShotModFx(player: Player, state: any, stats: any, weapon: any, model: Instance, damage: number, tParts: any, hitPos: Vector3, isWeak: boolean, isCrit: boolean, killed: boolean, pellets: number)
    local fx = CombatServer.CB.Family.Fx(stats, weapon, state) -- (CLASS BUILDS) FAMILY: shot mods per gun family (was stats.ShotFx)
    -- (RELIC hook WeakKillBlast, Detonator's Seal) a weak-spot kill bursts the target for a share of its max health round it
    local wkb = stats.Cond and stats.Cond.WeakKillBlast or 0
    if killed and isWeak and wkb > 0 and not model:GetAttribute("IsPracticeDummy") then
        local mh = model:GetAttribute("MaxHealth") or 0
        local DTk = CombatServer.DT
        CombatServer.Off.Ring(player, hitPos, 10, DTk.COLOR[stats.DamageType or "Kinetic"] or Color3.new(1, 1, 1))
        for _, m in ipairs(EnemiesNear(hitPos, 10, model, player)) do
            DealEnemyDamage(player, state, m, mh * wkb * CombatServer.Off.ResistMult(m, player, stats.DamageShares or { Kinetic = 1 }), stats, { Kind = "Explosion", DType = stats.DamageType, Depth = 1 })
        end
    end
    if type(fx) ~= "table" or next(fx) == nil or (damage or 0) <= 0 then return end
    pellets = math.max(1, pellets or 1)
    if pellets > 1 and math.random() >= 1 / pellets then return end
    local DT = CombatServer.DT
    local rm = 0
    for _, t in ipairs(DT.ORDER) do rm += (tParts and tParts[t]) or 0 end
    if rm <= 0 then rm = 1 end
    local base = damage / ((isWeak and stats.WeakSpotMultiplier or 1) * rm) * pellets
    local area = fx.AreaMult or 1
    local shares = stats.DamageShares or { Kinetic = 1 }
    local dtype = stats.DamageType
    local col = DT.COLOR[dtype or "Kinetic"] or Color3.new(1, 1, 1)
    local s = CombatServer.Off.SMState(player)
    local now = os.clock()
    local draw = now - (s.FxAt or 0) >= CombatServer.Off.SM_FX_GAP
    if draw then s.FxAt = now end
    local done = { [model] = 1 }
    local lim = fx.Rehit and 2 or 1 -- (Cornerstone Bank Shot: chains may hit the same enemy twice)
    local origin = EnemyRootPos(model) or hitPos
    local function Strike(m: Instance, pct: number, from: Vector3?)
        if (done[m] or 0) >= lim or not m.Parent or m:GetAttribute("Dead") then return end
        done[m] = (done[m] or 0) + 1
        local to = EnemyRootPos(m)
        if draw and from and to then ArcFx(player, from, to, col) end
        local rmM, hp0 = CombatServer.Off.ResistMult(m, player, shares), m:GetAttribute("Health") or 0
        local amt = base * pct * area * rmM
        local dealt, k = DealEnemyDamage(player, state, m, amt, stats, { Kind = "Arc", DType = dtype, Depth = 1 })
        if not k and dealt > 0 then CombatServer.Off.TypeAilments(player, state, stats, weapon, m, dealt, to or hitPos, 1, shares) end
        if k then CombatServer.Off.HeavyCarry(player, state, stats, weapon, m, math.max(0, amt - hp0), rmM, to or hitPos) end -- (HEAVY ROUNDS)
    end
    local function Near(pos: Vector3, r: number, n: number, skip: Instance?): { Instance }
        local out = {}
        for _, m in ipairs(NearestEnemies(pos, r, nil, player, n + 6)) do
            if (done[m] or 0) < lim and m ~= skip then table.insert(out, m); if #out >= n then break end end
        end
        return out
    end
    if fx.Mark and not killed then CombatServer.Off.MarkEnemy(player, model, fx.Mark) end
    if fx.Ricochet and (isWeak or isCrit) then
        for _, m in ipairs(Near(origin, fx.Ricochet.R, fx.Ricochet.N)) do Strike(m, fx.Ricochet.Pct, origin) end
    end
    if fx.Carom and isWeak then -- ((CLASS BUILDS) CORNERSTONE Carom Shot: the nearest enemy's weak spot takes 50% of the weak hit)
        for _, m in ipairs(Near(origin, fx.Carom.R, 1)) do Strike(m, fx.Carom.Pct * (stats.WeakSpotMultiplier or 1), origin) end
    end
    if fx.Chain then
        local from, last = origin, model
        for _ = 1, fx.Chain.N do
            local m = Near(from, fx.Chain.R, 1, last)[1]
            if not m then break end
            -- (RELIC hook ChainAlwaysCrit, Arcing Verdict: a hop is always a crit -- the hit's crit is in `base` already)
            Strike(m, fx.Chain.Pct * ((((stats.Cond and stats.Cond.ChainAlwaysCrit) or 0) > 0 and not isCrit) and (stats.CritMultiplier or 1) or 1), from)
            from, last = EnemyRootPos(m) or from, m
        end
    end
    if fx.Fork then
        for _, m in ipairs(Near(origin, fx.Fork.R, fx.Fork.N)) do Strike(m, fx.Fork.Pct, origin) end
    end
    if fx.Volley then
        for _, m in ipairs(Near(origin, fx.Volley.R, fx.Volley.N)) do Strike(m, fx.Volley.Pct, origin) end
    end
    if fx.Impact then
        if draw then CombatServer.Off.Ring(player, hitPos, fx.Impact.R, col) end
        for _, m in ipairs(EnemiesNear(hitPos, fx.Impact.R, model, player)) do
            DealEnemyDamage(player, state, m, base * fx.Impact.Pct * area * CombatServer.Off.ResistMult(m, player, shares), stats, { Kind = "Explosion", DType = dtype, Depth = 1 })
        end
    end
end
-- a kill (any source, from OnKillEffects): the Mark jumps to the nearest enemy; Detonate = the corpse bursts for a share of
-- its max health round it (chains up to depth 2)
function CombatServer.Off.ShotModKill(player: Player, state: any, model: Instance, stats: any, maxHp: number, depth: number?)
    local es: any = enemyStatus[model]
    local mk = es and es.SMMark
    local pos = EnemyRootPos(model)
    if mk and mk.Owner == player and os.clock() < mk.Until and pos then
        local nxt = NearestEnemies(pos, mk.R or 30, model, player, 1)[1]
        if nxt then
            CombatServer.Off.MarkEnemy(player, nxt, mk)
            local to = EnemyRootPos(nxt)
            if to then ArcFx(player, pos, to, StatCalculator.ShotMods.COLOR.B) end
        end
    end
    -- (RELIC hooks) BurnSpread (Wildfire Loop): that share of a burning enemy's Burn jumps to up to 3 enemies nearby;
    -- ShatterPct (Frostbite Band): a chilled / frozen enemy you kill shatters for that share of its max health round it
    local cnd = stats and stats.Cond or {}
    if es and pos and (depth or 0) < 2 and not model:GetAttribute("IsPracticeDummy") then
        local now = os.clock()
        if (cnd.BurnSpread or 0) > 0 and #es.Burns > 0 then
            local left, dur = 0, 0
            for _, b in ipairs(es.Burns) do
                local t = math.max(0, b.Until - now)
                left += b.Dps * t; dur = math.max(dur, t)
            end
            if left > 0 then
                for _, m in ipairs(NearestEnemies(pos, 15, model, player, 3)) do
                    ApplyBurn(player, m, left * cnd.BurnSpread, math.max(2, dur), 1)
                    local to = EnemyRootPos(m)
                    if to then ArcFx(player, pos, to, CombatServer.DT.COLOR.Heat) end
                end
            end
        end
        if (cnd.ShatterPct or 0) > 0 and (maxHp or 0) > 0 and (now < (es.ChillUntil or 0) or now < (es.FrozenUntil or 0)) then
            CombatServer.Off.Ring(player, pos, 10, CombatServer.DT.COLOR.Cryo)
            for _, m in ipairs(EnemiesNear(pos, 10, model, player)) do
                DealEnemyDamage(player, state, m, maxHp * cnd.ShatterPct * CombatServer.Off.ResistMult(m, player, { Cryo = 1 }), stats, { Kind = "Explosion", DType = "Cryo", Depth = (depth or 0) + 1 })
            end
        end
    end
    local fx = CombatServer.CB.Family.Fx(stats, state and state.EquippedWeapon, state) -- (CLASS BUILDS) FAMILY: an LMG detonates at full ramp only
    local d = fx and fx.Detonate
    if d and pos and (depth or 0) < 2 and (maxHp or 0) > 0 and not model:GetAttribute("IsPracticeDummy") and not model:GetAttribute("DpsDummy") then
        local DT = CombatServer.DT
        CombatServer.Off.Ring(player, pos, d.R, DT.COLOR[stats.DamageType or "Kinetic"] or Color3.new(1, 1, 1))
        local shares = stats.DamageShares or { Kinetic = 1 }
        local dmg = maxHp * d.Pct * (fx.AreaMult or 1)
        for _, m in ipairs(EnemiesNear(pos, d.R, model, player)) do
            DealEnemyDamage(player, state, m, dmg * CombatServer.Off.ResistMult(m, player, shares), stats, { Kind = "Explosion", DType = stats.DamageType, Depth = (depth or 0) + 1 })
        end
    end
end
-- XP: every mod socketed in the EQUIPPED gun gains the kill's XP as a share of your level's bar / ShotMods.Need(level); no
-- level past ShotMods.LevelCap(your level)
function CombatServer.Off.ShotModXp(player: Player, state: any, xp: number)
    local w = state.EquippedWeapon
    if (xp or 0) <= 0 or type(w) ~= "table" or type(w.SocketMods) ~= "table" then return end
    local SMod = StatCalculator.ShotMods
    local bar = ItemData.XpToNext(state.Level or 1)
    if (bar or 0) <= 0 then return end
    local cap = SMod.LevelCap(state.Level)
    local ups = {}
    for _, it in pairs(w.SocketMods) do
        if type(it) == "table" and (it.Level or 1) < cap then
            it.Level = it.Level or 1
            it.Xp = (it.Xp or 0) + (xp / bar) / SMod.Need(it.Level)
            while it.Xp >= 1 and it.Level < cap do
                it.Xp -= 1
                it.Level += 1
                table.insert(ups, SMod.Name(it))
            end
            if it.Level >= cap then it.Xp = math.min(it.Xp, 0.999) end
        end
    end
    if #ups > 0 then
        CombatFxEv:FireClient(player, "Text", "MOD LEVEL UP: " .. table.concat(ups, ", "), Color3.fromRGB(150, 230, 255))
        CombatServer.RecalculateMaxHealth(state)
    end
end
-- a new mod into the mod bag (state.ShotMods); full = it's lost (a toast says so)
function CombatServer.Off.GiveShotMod(player: Player, state: any, modId: string?, level: number?, quality: number?, quiet: boolean?): any
    local SMod = StatCalculator.ShotMods
    state.ShotMods = type(state.ShotMods) == "table" and state.ShotMods or {}
    local it = SMod.New((modId and SMod.DEFS[modId]) and modId or SMod.Roll(), level, quality)
    if #state.ShotMods >= SMod.BAG then
        if not quiet then CombatFxEv:FireClient(player, "Text", "MOD BAG FULL: " .. SMod.Name(it) .. " was lost", Color3.fromRGB(255, 120, 100)) end
        return nil
    end
    table.insert(state.ShotMods, it)
    if not quiet then
        local c = SMod.DEFS[it.Mod].Color
        CombatFxEv:FireClient(player, "Text", "NEW MOD: " .. SMod.Name(it) .. "  (" .. SMod.COLOR_NAME[c] .. " socket)", SMod.COLOR[c])
        SyncStateEv:FireClient(player, state)
    end
    return it
end
-- a kill's mod drop roll (GiveKillRewards)
function CombatServer.Off.ShotModDrop(player: Player, state: any, model: Instance, isBoss: boolean, isSuperBoss: boolean)
    local SMod = StatCalculator.ShotMods
    local D = SMod.DROP
    if (state.Level or 1) < D.Unlock then return end
    local et = model:GetAttribute("EliteTier")
    local ch = (isSuperBoss and D.Super) or (isBoss and D.Boss) or (et == "Rare" and D.Rare) or (et ~= nil and D.Magic)
        or ((model:GetAttribute("Fodder") == true) and D.Fodder) or D.Bot
    if math.random() >= ch then return end
    local lvl = 1
    if isBoss or isSuperBoss then lvl = math.random(1, math.max(1, math.floor(SMod.LevelCap(state.Level) * D.BOSS_LEVEL))) end
    CombatServer.Off.GiveShotMod(player, state, SMod.Roll((isBoss or isSuperBoss) and 0.4 or 1), lvl)
end
-- a gun leaving you (sold / dismantled): its mods go back to the bag first (past the bag cap if need be: nothing is lost)
function CombatServer.Off.ReturnMods(state: any, weapon: any): number
    local mods = StatCalculator.ShotMods.InGun(weapon)
    if #mods == 0 then return 0 end
    state.ShotMods = type(state.ShotMods) == "table" and state.ShotMods or {}
    for _, it in ipairs(mods) do table.insert(state.ShotMods, it) end
    weapon.SocketMods = nil
    return #mods
end
-- on load: the bag exists, and any mod that no longer fits its gun's socket goes back to the bag
function CombatServer.Off.ShotModLoad(state: any)
    state.ShotMods = type(state.ShotMods) == "table" and state.ShotMods or {}
    local SMod = StatCalculator.ShotMods
    for _, w in ipairs(state.Inventory or {}) do
        for _, it in ipairs(SMod.Misfits(w)) do table.insert(state.ShotMods, it) end
    end
end
-- the socket window's actions (remote ShotModAction): Socket(modUid, gunUid, index) -- a mod already there swaps back to the
-- bag; Unsocket(gunUid, index); UnsocketAll(gunUid); Discard(modUid). Guns: the one in hand or one in your bag.
function CombatServer.Off.ShotModAct(player: Player, action: any, a: any, b: any, c: any): (boolean, string?)
    local state = playerStates[player]
    if not state then return false, "?" end
    do local hold = CombatServer.TradeHold(player, a, b); if hold then return false, hold end end -- (a gun / mod offered in a trade)
    local SMod = StatCalculator.ShotMods
    state.ShotMods = type(state.ShotMods) == "table" and state.ShotMods or {}
    local function FindMod(uid)
        for i, m in ipairs(state.ShotMods) do if m.Uid == uid then return m, i end end
        return nil
    end
    local function FindGun(uid)
        if state.EquippedWeapon and state.EquippedWeapon.Uid == uid then return state.EquippedWeapon end
        for _, w in ipairs(state.Inventory or {}) do if w.Uid == uid then return w end end
        return nil
    end
    local msg
    if action == "Socket" then
        local m, i = FindMod(a)
        local g = FindGun(b)
        local idx = tonumber(c)
        if not m or not g or not idx then return false, "That's gone." end
        if not SMod.SocketColor(g.Sockets, idx) then return false, "That gun has no socket there." end
        if not SMod.Fits(g.Sockets, idx, m) then
            local cn = SMod.COLOR_NAME[SMod.DEFS[m.Mod].Color]
            return false, "A " .. cn .. " mod needs a " .. cn .. " socket."
        end
        g.SocketMods = type(g.SocketMods) == "table" and g.SocketMods or {}
        local old = g.SocketMods[tostring(idx)]
        table.remove(state.ShotMods, i)
        if type(old) == "table" then table.insert(state.ShotMods, old) end
        g.SocketMods[tostring(idx)] = m
        msg = SMod.Name(m) .. (SMod.ActiveSet(g)[idx] and " socketed." or " socketed (idle: not in the gun's biggest linked group).")
    elseif action == "Unsocket" or action == "UnsocketAll" then
        local g = FindGun(a)
        if not g or type(g.SocketMods) ~= "table" then return false, "No mods in that gun." end
        local keys = {}
        if action == "Unsocket" then keys = { tostring(tonumber(b) or "") } else for k in pairs(g.SocketMods) do table.insert(keys, k) end end
        local n = 0
        for _, k in ipairs(keys) do
            local it = g.SocketMods[k]
            if type(it) == "table" then
                if #state.ShotMods >= SMod.BAG then return false, "Your mod bag is full." end
                table.insert(state.ShotMods, it)
                g.SocketMods[k] = nil
                n += 1
            end
        end
        if next(g.SocketMods) == nil then g.SocketMods = nil end
        if n == 0 then return false, "That socket is empty." end
        msg = (n == 1) and "Mod taken out." or (n .. " mods taken out.")
    elseif action == "Discard" then
        local m, i = FindMod(a)
        if not m then return false, "That's gone." end
        table.remove(state.ShotMods, i)
        msg = SMod.Name(m) .. " discarded."
    elseif action == "Burnish" then -- (UPDATE 8 LOOT: BURNISH = +BURNISH_MIN..MAX quality on a mod in the bag, one random roll)
        local m = FindMod(a)
        if not m then return false, "Take the mod out of the gun first." end
        local q = tonumber(m.Quality) or 0
        if q >= SMod.MAX_QUALITY then return false, "Already at " .. SMod.MAX_QUALITY .. "% quality." end
        state.Materials = state.Materials or {}
        if (state.Materials.ModBurnish or 0) < 1 then return false, "Needs a Burnish." end
        state.Materials.ModBurnish -= 1
        local add = math.random(ItemData.BURNISH_MIN, ItemData.BURNISH_MAX)
        m.Quality = math.min(SMod.MAX_QUALITY, q + add)
        msg = SMod.Name(m) .. ": quality " .. q .. "% -> " .. m.Quality .. "%"
    elseif action == "SupplyBuy" then -- (MOD SUPPLY 2026-11-07) a = a mod id of ShotMods.SUPPLY: a level-1 mod for its Cost
        local row = SMod.SupplyRow(a)
        if not row then return false, "The supply doesn't sell that." end
        if (state.Level or 1) < row.Level then return false, "Opens at level " .. row.Level .. "." end
        if PartyRuns.RunOfPlayer(player) ~= nil or DungeonRuns.Get(player) ~= nil then return false, "Buy mods in the city, not during a run." end
        if #state.ShotMods >= SMod.BAG then return false, "Your mod bag is full." end
        state.Materials = state.Materials or {}
        local short = SMod.SupplyShort(row.Cost, state.Materials, state.Gold)
        if short then return false, "Not enough " .. short .. ": costs " .. SMod.CostText(row.Cost) .. "." end
        for k, n in pairs(row.Cost) do
            if k == "Gold" then state.Gold -= n else state.Materials[k] = (state.Materials[k] or 0) - n end
        end
        local it = CombatServer.Off.GiveShotMod(player, state, row.Mod, 1, 0, true)
        msg = "Bought " .. SMod.Name(it) .. " (" .. SMod.COLOR_NAME[SMod.DEFS[row.Mod].Color] .. " socket)."
    else
        return false, "?"
    end
    CombatServer.RecalculateMaxHealth(state)
    SyncStateEv:FireClient(player, state)
    return true, msg
end
Remotes.GetFunction("ShotModAction").OnServerInvoke = function(player: Player, action: any, a: any, b: any, c: any)
    return CombatServer.Off.ShotModAct(player, action, a, b, c)
end

-- ===== (CLASS BUILDS) FAMILY: the gun families' built-in lines in combat (GUNS builder; docs/CLASS_BUILDS.md section 1) =====
-- Data + numbers: ItemData.GunFamilies[fid].P (the tooltip text is built from the same numbers). One call per hook, the hit
-- pipeline is unchanged: PreHit (before the typed resists: More + a forced crit), the crit roll (.Crit), TypeAilments' pellets
-- (AilPellets: auto shotguns), PierceShot (Pierce + the line's last enemy), ShotModFx / ShotModKill (Fx: shot mods per family),
-- PostHit (after ShotModFx: every-Nth ailments, the auto-shotgun chain on a kill, the lance fork), DamagePlayer (Evade /
-- OnEvade: the sidearm). Every proc is capped (one forced set of ailments a hit, 3 kill chains a shot, pierce 8, one fork set a
-- shot) and draws at most one instant line per extra hit (no lights, no flashes). Per player: CB_* fields on the state; per
-- enemy: Seen (enemyStatus is dropped when an enemy's ailments run out, so it can't hold "already hit"). Seen is a STRONG
-- table swept every SEEN_SWEEP new enemies (Instances as weak keys can lose their entry while the enemy still lives).
CombatServer.CB = CombatServer.CB or {}
CombatServer.CB.Family = {
    Seen = {}, -- [enemy] = { [player.UserId] = this player's hits on it (trigger pulls) }
    SeenN = 0, SEEN_SWEEP = 300,
    Out = setmetatable({}, { __mode = "k" }), -- [player] = PreHit's result (reused: no table a hit)
}
-- this player's hits on an enemy so far (add = count one more)
function CombatServer.CB.Family.Hits(player: Player, model: any, add: boolean?): number
    local F = CombatServer.CB.Family
    local seen = F.Seen[model]
    if not seen then
        if not add then return 0 end
        F.SeenN += 1
        if F.SeenN > F.SEEN_SWEEP then -- drop enemies that are gone / dead
            local left = 0
            for m in pairs(F.Seen) do
                if typeof(m) ~= "Instance" or not m.Parent or m:GetAttribute("Dead") then F.Seen[m] = nil else left += 1 end
            end
            F.SeenN = left + 1
        end
        seen = {}
        F.Seen[model] = seen
    end
    local n = seen[player.UserId] or 0
    if add then seen[player.UserId] = n + 1 end
    return n
end
-- the hit before the target's resists and weak spot (crit kept), one pellet: ShotModFx's base
function CombatServer.CB.Family.Base(stats: any, damage: number, tParts: any, isWeak: boolean): number
    local rm = 0
    for _, t in ipairs(CombatServer.DT.ORDER) do rm += (tParts and tParts[t]) or 0 end
    if rm <= 0 then rm = 1 end
    return damage / ((isWeak and stats.WeakSpotMultiplier or 1) * rm)
end
-- before the typed resists. -> { More = damage x, Crit = forced crit }
function CombatServer.CB.Family.PreHit(player: Player, state: any, stats: any, weapon: any, model: Instance, isWeak: boolean, consumesAmmo: boolean, pellets: number): any
    local F = CombatServer.CB.Family
    local o = F.Out[player]
    if not o then o = {}; F.Out[player] = o end
    o.More, o.Crit = 1, false
    local fid, f = ItemData.FamilyOf(weapon)
    if not f then return o end
    local P, sa, now = f.P, state :: any, os.clock()
    local n = F.Hits(player, model, consumesAmmo)
    local first = consumesAmmo and n == 0
    if consumesAmmo then sa.CB_LineEnd = nil end
    if fid == "Bolt" then -- FAM_FIRSTCRIT (Point of Aim's "no crit" still wins)
        if first and not stats.AllWeak then o.Crit = true end
    elseif fid == "DMR" then -- FAM_WEAKCHAIN (a miss resets it in the miss paths)
        if consumesAmmo then
            if isWeak then
                o.More = 1 + P.Per * math.min(P.Max, sa.CB_WC or 0)
                sa.CB_WC = math.min(P.Max, (sa.CB_WC or 0) + 1)
            else
                sa.CB_WC = 0
            end
        end
    elseif fid == "HandCannon" then -- FAM_SWITCHROUND: the first hit on each enemy (an enemy, not "the other one" -- no ping-pong)
        if first then
            o.More = 1 + P.More
            state.CurrentMag = math.min(math.max(state.MaxMag or 0, state.CurrentMag or 0), (state.CurrentMag or 0) + 1)
        end
    elseif fid == "LightPistol" then -- FAM_MOVEDODGE (the Agility half is in Evade)
        if now < (sa.CB_DodgeUntil or 0) then o.More = 1 + P.DodgeMore end
    elseif fid == "LMG" then -- FAM_RAMP: per hit while firing, gone P.Reset s after the last hit (a reload resets it)
        if now - (sa.CB_RampAt or -99) > P.Reset then sa.CB_Ramp = 0 end
        o.More = 1 + math.min(P.Max, P.Per * (sa.CB_Ramp or 0))
        if consumesAmmo then sa.CB_Ramp = math.min(math.ceil(P.Max / P.Per), (sa.CB_Ramp or 0) + 1) end
        sa.CB_RampAt = now
    elseif fid == "Pump" then -- FAM_POINTBLANK: the pull's last pellet carries the bonus when every pellet hit this enemy
        if not stats.Slug and pellets > 1 then
            local pb = sa.CB_PB
            if consumesAmmo or not pb or pb.Pull ~= sa.P_ShotAt then
                pb = pb or {}
                pb.Pull, pb.M, pb.N, pb.Bad = sa.P_ShotAt, model, 0, not consumesAmmo -- (the first pellet missed = no bonus)
                sa.CB_PB = pb
            end
            if pb.M ~= model then pb.Bad = true end
            pb.N += 1
            if not pb.Bad and pb.N == pellets then o.More = 1 + P.More * pellets end
        end
    end
    return o
end
-- TypeAilments' pellet count: an auto shotgun's pellets each roll at P.PelletChance of the chance (the same ailment damage on
-- average: chance / k, magnitude x k)
function CombatServer.CB.Family.AilPellets(stats: any, weapon: any, pellets: number): number
    local fid, f = ItemData.FamilyOf(weapon)
    if fid == "Auto" and pellets > 1 and not stats.Slug then return 1 / f.P.PelletChance end
    return pellets
end
-- PierceShot's pierce: rifles +1 (full damage, +Grow an enemy), lances every enemy in the line (Cap)
function CombatServer.CB.Family.Pierce(weapon: any, pr: any): any
    local fid, f = ItemData.FamilyOf(weapon)
    if fid == "Rifle" then return { Targets = (pr and pr.Targets or 0) + f.P.Pierce, Falloff = 1, Grow = f.P.Grow, Cap = f.P.Cap } end
    if fid == "Lance" then return { Targets = math.max(f.P.Cap, pr and pr.Targets or 0), Falloff = 1, Cap = f.P.Cap } end
    return pr
end
-- the shot mods as this family uses them (ShotModFx / ShotModKill read this instead of stats.ShotFx)
function CombatServer.CB.Family.Fx(stats: any, weapon: any, state: any): any
    local fx = stats and stats.ShotFx
    if type(fx) ~= "table" then return fx end
    local fid, f = ItemData.FamilyOf(weapon)
    if not f then return fx end
    if fid == "Bolt" and fx.Chain then -- one hop at full damage
        local c = table.clone(fx); c.Chain = { N = 1, Pct = 1, R = fx.Chain.R }; return c
    elseif fid == "Auto" and fx.Chain and not stats.Slug then -- chains on kills instead (PostHit)
        local c = table.clone(fx); c.Chain = nil; return c
    elseif fid == "Lance" and fx.Fork then -- forks from the line's end instead (PostHit)
        local c = table.clone(fx); c.Fork = nil; return c
    elseif fid == "LMG" and fx.Detonate then -- only at full ramp, with the ramp's bonus
        local c = table.clone(fx)
        local sa = (state or {}) :: any
        local full = os.clock() - (sa.CB_RampAt or -99) <= f.P.Reset and f.P.Per * (sa.CB_Ramp or 0) >= f.P.Max - 1e-6
        c.Detonate = full and { Pct = fx.Detonate.Pct * (1 + f.P.Max), R = fx.Detonate.R } or nil
        return c
    end
    return fx
end
-- every ailment the hit has a chance for, once (FAM_TENTH / FAM_TICKSTACK): the same shares / magnitudes as TypeAilments
function CombatServer.CB.Family.ForceAilments(player: Player, state: any, stats: any, weapon: any, model: Instance, hitDmg: number, hitPos: Vector3, pellets: number, parts: any)
    if not parts or not model.Parent or model:GetAttribute("Dead") or (hitDmg or 0) <= 0 then return end
    local DT = CombatServer.DT
    local sum = 0
    for _, t in ipairs(DT.ORDER) do sum += parts[t] or 0 end
    if sum <= 0 then return end
    local rate = ItemData.ProcRateFactor(weapon)
    local chances = stats.AilChanceByType or {}
    for _, t in ipairs(DT.ORDER) do
        local share = (parts[t] or 0) / sum
        if stats.Overload and t ~= "Kinetic" then share = math.max(share, 0.5) end
        if share > 0 and (DT.AILMENT_BASE_CHANCE[t] * share + (chances[t] or 0)) > 0 then
            local id = CombatServer.Off.TYPE_AILMENT[t]
            local part = hitDmg * share
            InflictAilment(id, player, state, stats, model, (id == "Shock" or id == "Wither") and part * pellets or part * pellets / rate, hitPos, 1)
        end
    end
end
-- after ShotModFx. damage = the hit before DealEnemyDamage (ShotModFx's), finalDmg = what it dealt
function CombatServer.CB.Family.PostHit(player: Player, state: any, stats: any, weapon: any, model: Instance, finalDmg: number, damage: number, tParts: any, hitPos: Vector3, isWeak: boolean, killed: boolean, pellets: number, consumesAmmo: boolean)
    local F = CombatServer.CB.Family
    local fid, f = ItemData.FamilyOf(weapon)
    if not f then return end
    local P, sa = f.P, state :: any
    if fid == "SMG" then -- FAM_TENTH: every Nth hit (trigger pulls that land) applies them all
        if consumesAmmo then
            sa.CB_Tenth = (sa.CB_Tenth or 0) + 1
            if sa.CB_Tenth >= P.Every then
                sa.CB_Tenth = 0
                if not killed then F.ForceAilments(player, state, stats, weapon, model, finalDmg, hitPos, pellets, tParts) end
            end
        end
    elseif fid == "Ray" then -- FAM_TICKSTACK: every Nth hit on the same enemy
        local n = F.Hits(player, model, false)
        if consumesAmmo and not killed and n > 0 and n % P.Every == 0 then F.ForceAilments(player, state, stats, weapon, model, finalDmg, hitPos, pellets, tParts) end
    elseif fid == "Auto" then -- the Chain mod: each killing pellet chains once (P.ChainCap a shot) for the whole shot's share
        local ch = type(stats.ShotFx) == "table" and stats.ShotFx.Chain
        if ch and killed and not stats.Slug then
            if sa.CB_ChainPull ~= sa.P_ShotAt then sa.CB_ChainPull, sa.CB_ChainN = sa.P_ShotAt, 0 end
            if (sa.CB_ChainN or 0) < (P.ChainCap or 3) then
                local pos = EnemyRootPos(model) or hitPos
                local m = NearestEnemies(pos, ch.R or 30, model, player, 1)[1]
                if m then
                    sa.CB_ChainN = (sa.CB_ChainN or 0) + 1
                    local shares = stats.DamageShares or { Kinetic = 1 }
                    local to = EnemyRootPos(m)
                    if to then ArcFx(player, pos, to, CombatServer.DT.COLOR[stats.DamageType or "Kinetic"] or Color3.new(1, 1, 1)) end
                    local amt = F.Base(stats, damage, tParts, isWeak) * pellets * ch.Pct * (stats.ShotFx.AreaMult or 1) * CombatServer.Off.ResistMult(m, player, shares)
                    local dealt, k = DealEnemyDamage(player, state, m, amt, stats, { Kind = "Arc", DType = stats.DamageType, Depth = 1 })
                    if not k and dealt > 0 then CombatServer.Off.TypeAilments(player, state, stats, weapon, m, dealt, to or hitPos, 1, shares) end
                end
            end
        end
    elseif fid == "Lance" then -- the Fork mod splits from the line's last enemy (PierceShot left it in CB_LineEnd)
        local fk = type(stats.ShotFx) == "table" and stats.ShotFx.Fork
        if fk and consumesAmmo then
            local from = sa.CB_LineEnd
            sa.CB_LineEnd = nil
            if not (from and from.Parent) then from = model end
            local pos = EnemyRootPos(from) or hitPos
            local shares = stats.DamageShares or { Kinetic = 1 }
            local base = F.Base(stats, damage, tParts, isWeak) * pellets
            local col = CombatServer.DT.COLOR[stats.DamageType or "Kinetic"] or Color3.new(1, 1, 1)
            local hit = 0
            for _, m in ipairs(NearestEnemies(pos, fk.R or 22, from, player, (fk.N or 2) + 1)) do
                if m ~= model and hit < (fk.N or 2) then
                    hit += 1
                    local to = EnemyRootPos(m)
                    if to then ArcFx(player, pos, to, col) end
                    local dealt, k = DealEnemyDamage(player, state, m, base * fk.Pct * (stats.ShotFx.AreaMult or 1) * CombatServer.Off.ResistMult(m, player, shares), stats, { Kind = "Arc", DType = stats.DamageType, Depth = 1 })
                    if not k and dealt > 0 then CombatServer.Off.TypeAilments(player, state, stats, weapon, m, dealt, to or hitPos, 1, shares) end
                end
            end
        end
    end
end
-- DamagePlayer: the sidearm's Agility while you move and fire (A x P.Agility on the evade curve: e' = a e / (a e + 1 - e))
function CombatServer.CB.Family.Evade(player: Player, state: any, stats: any): number
    local e = stats.EvadeChance or 0
    local fid, f = ItemData.FamilyOf(state.EquippedWeapon)
    if fid ~= "LightPistol" or e <= 0 or e >= StatCalculator.AGILITY_MAX then return e end
    if os.clock() - ((state :: any).P_ShotAt or -99) > f.P.FiredWithin then return e end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not (root and root:IsA("BasePart")) then return e end
    local v = root.AssemblyLinearVelocity
    if Vector3.new(v.X, 0, v.Z).Magnitude < 1.5 then return e end
    local a = f.P.Agility
    return math.min(StatCalculator.AGILITY_MAX, a * e / (a * e + (1 - e)))
end
function CombatServer.CB.Family.OnEvade(player: Player, state: any)
    local fid, f = ItemData.FamilyOf(state.EquippedWeapon)
    if fid == "LightPistol" then (state :: any).CB_DodgeUntil = os.clock() + f.P.DodgeFor end
end
-- DevCmd ["family", "unit"]: the hooks on fake states / enemies (nothing touches your save) -> "ALL OK" + one line per check
function CombatServer.CB.Family.SelfTest(player: Player): string
    local F = CombatServer.CB.Family
    local out, fails = {}, 0
    local function chk(name, cond, info)
        if not cond then fails += 1 end
        table.insert(out, name .. (cond and " ok" or " FAIL") .. (info and (" " .. tostring(info)) or ""))
    end
    local function gun(id) return ItemData.GenerateWeaponOfBase(id, "Rare", 50) end
    local function st(id) return { EquippedWeapon = gun(id), CurrentMag = 5, MaxMag = 7, P_ShotAt = os.clock() } end
    local stats = { AllWeak = false }
    local A, B = {}, {}
    local s = st("AWP")
    local c1 = F.PreHit(player, s, stats, s.EquippedWeapon, A, false, true, 1).Crit
    local c2 = F.PreHit(player, s, stats, s.EquippedWeapon, A, false, true, 1).Crit
    local c3 = F.PreHit(player, s, stats, s.EquippedWeapon, B, false, true, 1).Crit
    chk("Bolt first-hit crit", c1 and not c2 and c3, tostring(c1) .. "/" .. tostring(c2) .. "/" .. tostring(c3))
    chk("Bolt + Point of Aim (no crit)", not F.PreHit(player, s, { AllWeak = true }, s.EquippedWeapon, {}, true, true, 1).Crit)
    s = st("SVD")
    local m = {}
    for _, w in ipairs({ true, true, true, false, true }) do table.insert(m, string.format("%.2f", F.PreHit(player, s, stats, s.EquippedWeapon, A, w, true, 1).More)) end
    chk("DMR weak chain", table.concat(m, ",") == "1.00,1.08,1.16,1.00,1.00", table.concat(m, ","))
    s = st("DEAGLE")
    local h1 = F.PreHit(player, s, stats, s.EquippedWeapon, {}, false, true, 1).More
    local mag1 = s.CurrentMag
    local Cx = {}
    F.PreHit(player, s, stats, s.EquippedWeapon, Cx, false, true, 1)
    local h3 = F.PreHit(player, s, stats, s.EquippedWeapon, Cx, false, true, 1).More
    chk("Hand Cannon first hit + refund", math.abs(h1 - 1.4) < 1e-6 and mag1 == 6 and math.abs(h3 - 1) < 1e-6, string.format("first %.2f mag 5->%d / same enemy again %.2f", h1, mag1, h3))
    s = st("Glock17")
    local d0 = F.PreHit(player, s, stats, s.EquippedWeapon, {}, false, true, 1).More
    F.OnEvade(player, s)
    local d1 = F.PreHit(player, s, stats, s.EquippedWeapon, {}, false, true, 1).More
    chk("Sidearm dodge bonus", d0 == 1 and math.abs(d1 - 1.2) < 1e-6, string.format("%.2f -> %.2f", d0, d1))
    s = st("M249")
    local r = 1
    for _ = 1, 31 do r = F.PreHit(player, s, stats, s.EquippedWeapon, A, false, true, 1).More end
    local det = { Detonate = { Pct = 0.1, R = 10 }, Chain = { N = 2, Pct = 0.5, R = 30 } }
    local fxFull = F.Fx({ ShotFx = det }, s.EquippedWeapon, s)
    s.CB_RampAt = os.clock() - 1
    local fxCold = F.Fx({ ShotFx = det }, s.EquippedWeapon, s)
    chk("LMG ramp cap + Detonate at full ramp only", math.abs(r - 1.6) < 1e-6 and fxFull.Detonate ~= nil and math.abs(fxFull.Detonate.Pct - 0.16) < 1e-6 and fxCold.Detonate == nil and fxCold.Chain ~= nil,
        string.format("%.2f full=%s cold=%s", r, tostring(fxFull.Detonate and fxFull.Detonate.Pct), tostring(fxCold.Detonate)))
    s = st("R870")
    local last, split = 1, 1
    for i = 1, 9 do s.P_ShotAt = 100; last = F.PreHit(player, s, stats, s.EquippedWeapon, A, false, i == 1, 9).More end
    for i = 1, 9 do s.P_ShotAt = 101; split = F.PreHit(player, s, stats, s.EquippedWeapon, (i == 5) and B or A, false, i == 1, 9).More end
    local slug = F.PreHit(player, s, { Slug = true }, s.EquippedWeapon, A, false, true, 1).More
    chk("Pump point-blank", math.abs(last - (1 + 0.35 * 9)) < 1e-6 and split == 1 and slug == 1, string.format("all on one %.2f (last pellet) / split %.2f / slug %.2f", last, split, slug))
    chk("Auto pellet ailments", F.AilPellets({}, gun("BM4"), 9) == 2 and F.AilPellets({ Slug = true }, gun("BM4"), 9) == 9 and F.AilPellets({}, gun("R870"), 9) == 9)
    local pr = F.Pierce(gun("AK47"), nil)
    local pl = F.Pierce(gun("Railgun"), { Targets = 2, Falloff = 0.75 })
    chk("Rifle / Lance pierce", pr.Targets == 1 and pr.Grow == 0.1 and pl.Targets == 8 and pl.Falloff == 1 and F.Pierce(gun("AWP"), nil) == nil,
        string.format("rifle %d +%.2f / lance %d", pr.Targets, pr.Grow, pl.Targets))
    local fb = F.Fx({ ShotFx = { Chain = { N = 3, Pct = 0.5, R = 30 } } }, gun("AWP"), {})
    local fa = F.Fx({ ShotFx = { Chain = { N = 3, Pct = 0.5, R = 30 }, Impact = {} } }, gun("AA12"), {})
    local fl = F.Fx({ ShotFx = { Fork = { N = 2, Pct = 0.3, R = 22 } } }, gun("Railgun"), {})
    chk("Mods per family (Bolt chain / Auto chain / Lance fork)", fb.Chain.N == 1 and fb.Chain.Pct == 1 and fa.Chain == nil and fa.Impact ~= nil and fl.Fork == nil)
    local cnt = 0
    for _ in pairs(ItemData.GunFamilyOf) do cnt += 1 end
    chk("every lineup gun in a family", cnt == #ItemData.Lineup, cnt .. "/" .. #ItemData.Lineup)
    for k in pairs(F.Seen) do if type(k) == "table" then F.Seen[k] = nil end end -- (the fake enemies)
    return (fails == 0 and "ALL OK" or (fails .. " FAILED")) .. "\n" .. table.concat(out, "\n")
end
-- DevCmd ["family"] (DevCommands): the equipped gun's family + every CB_* counter; ["family", "near"] adds the 6 nearest
-- enemies (hits on each by you, health, ailments); ["family", "reset"] clears the counters
function CombatServer.CB.Family.Debug(player: Player, state: any, stats: any, arg: any): string
    local sa, now = state :: any, os.clock()
    if arg == "unit" then return CombatServer.CB.Family.SelfTest(player) end
    if arg == "reset" then
        sa.CB_WC, sa.CB_Ramp, sa.CB_RampAt, sa.CB_Tenth, sa.CB_DodgeUntil, sa.CB_PB, sa.CB_ChainN = 0, 0, -99, 0, 0, nil, 0
        return "family counters reset"
    end
    local fid, f = ItemData.FamilyOf(state.EquippedWeapon)
    local pb = sa.CB_PB
    local out = string.format("gun=%s family=%s line=%s tune=%.2f gunTune=%.3f | WC=%s Ramp=%s (%.2fs ago, +%d%%) Tenth=%s Dodge=%.2fs PB=%s ChainN=%s | mag %s/%s | evade %.3f -> %.3f | fx=%s",
        tostring(state.EquippedWeapon and state.EquippedWeapon.BaseId), tostring(fid), tostring(f and f.Line), ItemData.FamilyTune(state.EquippedWeapon), ItemData.GunTune(state.EquippedWeapon),
        tostring(sa.CB_WC), tostring(sa.CB_Ramp), now - (sa.CB_RampAt or -99), math.round(100 * math.min(f and f.P.Max or 0, (f and f.P.Per or 0) * (sa.CB_Ramp or 0))),
        tostring(sa.CB_Tenth), math.max(0, (sa.CB_DodgeUntil or 0) - now), pb and string.format("%d%s", pb.N or 0, pb.Bad and " bad" or "") or "-", tostring(sa.CB_ChainN),
        tostring(state.CurrentMag), tostring(state.MaxMag), stats.EvadeChance or 0, CombatServer.CB.Family.Evade(player, state, stats),
        (function() local k = {} for n in pairs(CombatServer.CB.Family.Fx(stats, state.EquippedWeapon, state) or {}) do table.insert(k, n) end table.sort(k) return table.concat(k, ",") end)())
    if arg == "near" then
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then
            for _, m in ipairs(NearestEnemies(root.Position, 300, nil, player, 6)) do
                local es: any = enemyStatus[m]
                out ..= string.format("\n  %s hits=%d hp=%.4g/%.4g burns=%d bleeds=%d chill=%s shock=%.2f withers=%d", tostring(m:GetAttribute("ModelName") or m.Name),
                    CombatServer.CB.Family.Hits(player, m, false), m:GetAttribute("Health") or 0, m:GetAttribute("MaxHealth") or 0, es and #es.Burns or 0, es and #es.Bleeds or 0,
                    tostring(es ~= nil and now < (es.ChillUntil or 0)), (es and es.ShockUntil and now < es.ShockUntil) and es.ShockInc or 0, es and es.Withers and #es.Withers or 0)
            end
        end
    end
    return out
end

-- ===== ASCENDANCY EFFECTS (passive tree v4, 2026-10-05) =====
-- StatCalculator hands over stats.AscFx = { { Fx = <AscendancyData Fx>, Key = "nodeId:i" } } for the player's chosen
-- ascendancy. One table (Asc) so the module keeps its local count down. Conditions ("When") are evaluated against a
-- context built per hit (Asc.HitCtx) / per kill (Asc.KillCtx) / per hit taken (DamagePlayer).
local Asc = {}
Asc.WHEN = {
    Always = function() return true end,
    WeakSpot = function(c) return c.Weak == true end,
    Body = function(c) return c.Weak == false end,
    Crit = function(c) return c.Crit == true end,
    FullHPEnemy = function(c) return c.FullHP == true end,
    LowHPEnemy = function(c) return c.LowHP == true end,
    Elite = function(c) return c.Elite == true end,
    Boss = function(c) return c.Boss == true end,
    Moving = function(c) return c.Moving == true end,
    Still = function(c) return c.Moving == false end,
    Ailmented = function(c) return (c.Ail or 0) >= 1 end,
    Ailments2 = function(c) return (c.Ail or 0) >= 2 end,
    Ailments3 = function(c) return (c.Ail or 0) >= 3 end,
    Burning = function(c) return c.Burning == true end,
    Chilled = function(c) return c.Chilled == true end,
    Decaying = function(c) return c.Decaying == true end,
    Bleeding = function(c) return c.Bleeding == true end,
    LowLife = function(c) return c.LowLife == true end,
    HighLife = function(c) return c.HighLife == true end,
    FullLife = function(c) return c.FullLife == true end,
    NewTarget = function(c) return c.NewTarget == true end,
    SameTarget = function(c) return (c.SameHits or 0) >= 3 end,
    LastRounds = function(c) return c.LastRounds == true end,
    Focus10 = function(c) return (c.Streak or 0) >= 10 end,
    Close = function(c) return c.Dist ~= nil and c.Dist <= 20 end,
    Far = function(c) return c.Dist ~= nil and c.Dist >= 60 end,
    Marked = function(c) return c.Marked == true end,
    SlowGun = function(c) return c.SlowGun == true end,
    Reloading = function(c) return c.Reloading == true end,
    HeavyGun = function(c) return c.HeavyGun == true end,
}
function Asc.When(when: string?, c: any): boolean
    for part in string.gmatch(when or "Always", "[^+]+") do
        if string.sub(part, 1, 6) == "Group:" then -- (the held gun's weapon group: ItemData.WeaponGroups, new gun types included)
            if c.Group ~= string.sub(part, 7) then return false end
        else
            local f = Asc.WHEN[part]
            if not f or not f(c) then return false end
        end
    end
    return true
end
function Asc.HasCrit(when: string?): boolean
    return when ~= nil and string.find(when, "Crit", 1, true) ~= nil
end
function Asc.Now(): number return workspace:GetServerTimeNow() end
function Asc.MarkAttr(player: Player): string return "AscMark_" .. player.UserId end
function Asc.Marked(model: Instance, player: Player): boolean
    return (model:GetAttribute(Asc.MarkAttr(player)) or 0) > os.clock()
end
function Asc.Heal(state: any, amount: number)
    if state.Health <= 0 or amount <= 0 then return end
    state.Health = math.min(state.MaxHealth, math.round((state.Health + amount) * 10) / 10)
end
function Asc.Dist(player: Player, pos: Vector3?): number?
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not (root and root:IsA("BasePart") and pos) then return nil end
    return (root.Position - pos).Magnitude
end
-- a timed effect: Buff (on its trigger) or a CheatDeath's follow-up; StatCalculator adds fx.Stats x stacks while U > now
function Asc.AddBuff(state: any, key: string, fx: any, stacks: number?)
    local now = Asc.Now()
    state.AscBuffs = type(state.AscBuffs) == "table" and state.AscBuffs or {}
    local b = state.AscBuffs[key]
    if not b or (b.U or 0) <= now then b = { U = 0, N = 0 } end
    b.N = math.min(fx.Max or 1, (b.N or 0) + (stacks or 1))
    b.U = now + (fx.Dur or 3)
    b.T = now -- (when it last (re)started: a hit only consumes a buff that was up before it)
    state.AscBuffs[key] = b
end
function Asc.Trigger(state: any, stats: any, trigger: string)
    for _, e in ipairs(stats.AscFx or {}) do
        if e.Fx.Kind == "Buff" and e.Fx.Trigger == trigger then Asc.AddBuff(state, e.Key, e.Fx) end
    end
end
function Asc.Has(stats: any, kind: string, what: string?): boolean
    for _, e in ipairs(stats.AscFx or {}) do
        if e.Fx.Kind == kind and (what == nil or e.Fx.What == what) then return true end
    end
    return false
end
-- one effect on an enemy / you (Proc and OnKill share these)
function Asc.Effect(effect: string, v: number, player: Player, state: any, stats: any, model: Instance?, blast: number, hitPos: Vector3?)
    local alive = model ~= nil and model.Parent ~= nil and not model:GetAttribute("Dead")
    if effect == "Random" then
        local pick = ({ "Burn", "Freeze", "Bleed", "Decay" })[math.random(1, 4)]
        effect = pick
    end
    if effect == "Burn" or effect == "Freeze" or effect == "Bleed" or effect == "Decay" then
        if alive then InflictAilment(effect, player, state, stats, model :: Instance, blast, hitPos or Vector3.zero, v) end
    elseif effect == "Echo" then
        if alive then DealEnemyDamage(player, state, model :: Instance, blast * v, stats, { Kind = "Arc" }) end
    elseif effect == "Heal" then
        Asc.Heal(state, state.MaxHealth * v)
    elseif effect == "LeechHit" then
        Asc.Heal(state, blast * v)
    elseif effect == "Ammo" then
        if (state.MaxMag or 0) > 0 then state.CurrentMag = math.min(state.MaxMag, (state.CurrentMag or 0) + v) end
    elseif effect == "Reload" then
        if (state.MaxMag or 0) > 0 then state.IsReloading = false; state.CurrentMag = state.MaxMag end
    elseif effect == "Focus" then
        state.Streak = math.min((stats.MaxFocusStacks or 25) + 5, (state.Streak or 0) + v)
    end
end
-- BEFORE the crit roll: MORE multipliers (not crit-dependent), Ramp, every-Nth-pull; returns (mult, critAdd, forceCrit)
function Asc.PreHit(st: any, stats: any, c: any, consumesAmmo: boolean): (number, number, boolean)
    local mult, critAdd, force = 1, 0, false
    st.AscNth = type(st.AscNth) == "table" and st.AscNth or {}
    st.AscNthPull = type(st.AscNthPull) == "table" and st.AscNthPull or {}
    for _, e in ipairs(stats.AscFx or {}) do
        local fx = e.Fx
        if fx.Kind == "More" and not Asc.HasCrit(fx.When) and Asc.When(fx.When, c) then
            if not fx.Chance or math.random() < fx.Chance then mult *= 1 + fx.Value end
        elseif fx.Kind == "Crit" and Asc.When(fx.When, c) then
            critAdd += fx.Value
        elseif fx.Kind == "Ramp" and Asc.When(fx.When, c) then -- (When: tree Fx limit a ramp to a gun type; nil = always)
            mult *= 1 + math.min(fx.Cap or 0.4, (fx.Per or 0.02) * (c.SameHits or 0))
        elseif fx.Kind == "Nth" then
            if consumesAmmo then -- (a shotgun's pellets / a burst's rounds share their trigger pull's verdict)
                st.AscNth[e.Key] = (st.AscNth[e.Key] or 0) + 1
                st.AscNthPull[e.Key] = st.AscNth[e.Key] >= (fx.N or 5)
                if st.AscNthPull[e.Key] then st.AscNth[e.Key] = 0 end
            end
            if st.AscNthPull[e.Key] then
                mult *= 1 + (fx.Value or 0)
                if fx.Crit == 1 then force = true end
            end
        end
    end
    return mult, critAdd, force
end
-- AFTER the crit roll: crit-dependent MORE multipliers
function Asc.CritMult(stats: any, c: any): number
    local mult = 1
    for _, e in ipairs(stats.AscFx or {}) do
        local fx = e.Fx
        if fx.Kind == "More" and Asc.HasCrit(fx.When) and Asc.When(fx.When, c) then
            if not fx.Chance or math.random() < fx.Chance then mult *= 1 + fx.Value end
        end
    end
    return mult
end
-- AFTER the hit lands: procs, marks, hit-triggered buffs, consumed buffs
function Asc.PostHit(player: Player, state: any, stats: any, model: Instance, c: any, blast: number, hitPos: Vector3, pellets: number, consumesAmmo: boolean)
    local now = Asc.Now()
    local t0 = c.T0 or now
    for _, e in ipairs(stats.AscFx or {}) do
        local fx = e.Fx
        if fx.Kind == "Proc" and Asc.When(fx.When, c) then
            if math.random() < (fx.Chance or 1) / math.max(1, pellets) then
                Asc.Effect(fx.Effect, fx.Value or 1, player, state, stats, model, blast, hitPos)
            end
        elseif fx.Kind == "Mark" and ((fx.Trigger == "WeakSpot" and c.Weak) or (fx.Trigger == "Crit" and c.Crit)) then
            model:SetAttribute(Asc.MarkAttr(player), os.clock() + (fx.Dur or 4))
        elseif fx.Kind == "Buff" then
            if consumesAmmo and ((fx.Trigger == "WeakSpot" and c.Weak) or (fx.Trigger == "Crit" and c.Crit)) then
                Asc.AddBuff(state, e.Key, fx)
            end
            -- "your next hit": a consumed buff fades 0.15 s after the hit (the pull's other pellets still get it)
            local b = fx.Consume == 1 and type(state.AscBuffs) == "table" and state.AscBuffs[e.Key]
            if b and (b.U or 0) > now and (b.T or 0) < t0 and fx.Trigger ~= "WeakSpot" and fx.Trigger ~= "Crit" then
                b.U = math.min(b.U, now + 0.15)
            end
        end
    end
end
-- ON KILL (any of your kills: hits, DoTs, echoes): OnKill effects + Kill / EliteKill buffs
function Asc.OnKill(player: Player, state: any, stats: any, model: Instance)
    if not stats.AscFx or #stats.AscFx == 0 then return end
    local now = os.clock()
    local es = enemyStatus[model]
    local pos = EnemyRootPos(model)
    local c = {
        Elite = model:GetAttribute("IsElite") == true or model:GetAttribute("IsBoss") == true,
        Boss = model:GetAttribute("IsBoss") == true,
        Marked = Asc.Marked(model, player),
        Burning = es ~= nil and #es.Burns > 0, Bleeding = es ~= nil and #es.Bleeds > 0,
        Chilled = es ~= nil and now < es.ChillUntil, Decaying = es ~= nil and now < es.DecayUntil,
        Dist = Asc.Dist(player, pos),
        Group = ItemData.WeaponGroupOf(state.EquippedWeapon), -- (tree / expertise kill effects tied to a gun type)
    }
    c.Ail = (c.Burning and 1 or 0) + (c.Bleeding and 1 or 0) + (c.Chilled and 1 or 0) + (c.Decaying and 1 or 0)
    for _, e in ipairs(stats.AscFx) do
        local fx = e.Fx
        if fx.Kind == "OnKill" and Asc.When(fx.When, c) and (not fx.Chance or math.random() < fx.Chance) then
            if fx.Effect == "Spread" then
                -- the dead enemy's ailment(s) jump to the nearest enemy (within 30 studs)
                local near = pos and NearestEnemies(pos, 30, model, player, 1)[1]
                if near then
                    local blast = (stats.Damage or 10) * 2
                    local list = (fx.Value == "All") and { "Burn", "Freeze", "Bleed", "Decay" } or { fx.Value == "Chill" and "Freeze" or fx.Value }
                    for _, id in ipairs(list) do
                        local has = (id == "Burn" and c.Burning) or (id == "Bleed" and c.Bleeding) or (id == "Freeze" and c.Chilled) or (id == "Decay" and c.Decaying)
                        if has then InflictAilment(id, player, state, stats, near, blast, EnemyRootPos(near) or pos, 1) end
                    end
                end
            else
                Asc.Effect(fx.Effect, fx.Value or 1, player, state, stats, nil, 0, nil)
            end
        end
    end
    Asc.Trigger(state, stats, "Kill")
    if c.Elite then Asc.Trigger(state, stats, "EliteKill") end
end
-- damage you take: Guard (less damage by condition) + active TakenLess buffs; returns the multiplier (>= 0.5)
function Asc.GuardMult(player: Player, state: any, stats: any, moving: boolean, from: Vector3?): number
    local fxl = stats.AscFx
    local mult = 1 - (stats.AscTakenLess or 0)
    if fxl and #fxl > 0 then
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local c = {
            Moving = moving, Reloading = state.IsReloading == true, Streak = state.Streak,
            LowLife = state.Health < state.MaxHealth * 0.4, HighLife = state.Health >= state.MaxHealth * 0.5,
            FullLife = state.Health >= state.MaxHealth * 0.95,
            Dist = (from and root and root:IsA("BasePart")) and (root.Position - from).Magnitude or nil,
        }
        for _, e in ipairs(fxl) do
            if e.Fx.Kind == "Guard" and Asc.When(e.Fx.When, c) then mult *= 1 - e.Fx.Value end
        end
    end
    return math.max(0.5, mult)
end
-- a killing blow: the first ready CheatDeath saves you (cooldown per node); true = saved
function Asc.CheatDeath(player: Player, state: any, stats: any): boolean
    for _, e in ipairs(stats.AscFx or {}) do
        local fx = e.Fx
        if fx.Kind == "CheatDeath" then
            state.AscCD = type(state.AscCD) == "table" and state.AscCD or {}
            if os.clock() >= (state.AscCD[e.Key] or 0) then
                state.AscCD[e.Key] = os.clock() + (fx.Cooldown or 60)
                state.Health = math.round(state.MaxHealth * (fx.HP or 0.3))
                if fx.Stats then Asc.AddBuff(state, e.Key, { Dur = fx.Dur or 4, Max = 1 }) end
                local node = AscendancyData.Nodes[string.match(e.Key, "^(.-):")]
                Remotes.GetEvent("CombatFx"):FireClient(player, "Text", string.upper(node and node.Name or "SAVED"), Color3.fromRGB(255, 235, 140))
                return true
            end
        end
    end
    return false
end

CombatServer.Asc = Asc -- (DevCommands "ascprobe")

-- ===== (CLASS BUILDS) SIGNATURE: the 15 specializations' signature rules (docs/CLASS_BUILDS.md section 2) =====
-- Each specialization has ONE signature notable (AscendancyData: Fx { Kind = "Sig", Id = "SIG_<SPEC>", P = its numbers }) that
-- nothing else grants. It reaches combat through stats.AscFx like every Asc Fx (so only with your class's gun); the rules live
-- here as fields (no new top-level locals) and are called from single tagged lines beside the existing hooks (hit handler,
-- PierceShot, OnKillEffectsRef, EnemyTakenMult, DealEnemyDamage, DamagePlayer, TypeAilments). Every proc is capped (targets,
-- stacks, one burst a kill, kill-chains stop at depth 2). Bosses are never killed outright and their mechanics never miss.
CombatServer.CB = CombatServer.CB or {}
do
    local Sig: any = {}
    CombatServer.CB.Sig = Sig
    Sig.FX_GAP = 0.06 -- (one ring / set of lines per player every 0.06 s at most; the damage always lands)
    -- per player (by UserId) scratch: mark, seen enemies, shock / freeze tokens, Ghost. STRONG tables (an Instance used as a
    -- weak key can be dropped while the enemy still lives); enemies that left the world are swept every 200 new entries.
    Sig.S = {}
    function Sig.St(player: Player): any
        local s = Sig.S[player.UserId]
        if not s then
            s = { Seen = {}, Recent = {}, Frz = {}, Shk = {}, ShockN = 0, Adds = 0 }
            Sig.S[player.UserId] = s
        end
        return s
    end
    function Sig.Note(s: any)
        s.Adds += 1
        if s.Adds < 200 then return end
        s.Adds = 0
        for _, t in ipairs({ s.Seen, s.Recent, s.Frz, s.Shk }) do
            for m in pairs(t) do if not m.Parent or m:GetAttribute("Dead") then t[m] = nil end end
        end
    end
    game:GetService("Players").PlayerRemoving:Connect(function(p) Sig.S[p.UserId] = nil end)
    -- the build's signature: id, its numbers, its AscFx key (nil = none)
    function Sig.Of(stats: any): (string?, any, string?)
        for _, e in ipairs(stats and stats.AscFx or {}) do
            if e.Fx.Kind == "Sig" then return e.Fx.Id, e.Fx.P or {}, e.Key end
        end
        return nil, nil, nil
    end
    function Sig.Has(stats: any, id: string): any
        local sid, P = Sig.Of(stats)
        return (sid == id) and P or nil
    end
    function Sig.Draw(player: Player): boolean
        local s = Sig.St(player)
        local now = os.clock()
        if now - (s.FxAt or 0) < Sig.FX_GAP then return false end
        s.FxAt = now
        return true
    end
    function Sig.Boss(model: Instance): boolean return model:GetAttribute("IsBoss") == true end
    function Sig.Withers(es: any, now: number): number
        local n = 0
        for _, w in ipairs(es and es.Withers or {}) do if w.Until > now then n += 1 end end
        if n == 0 and es and now < (es.DecayUntil or 0) then n = 1 end -- (old Decay = one Wither for players)
        return n
    end
    -- different ailments on an enemy: Bleed, Burn, Chill (or Frozen), Shock, Wither
    function Sig.Ailments(es: any, now: number): number
        if not es then return 0 end
        local n = 0
        if #es.Burns > 0 then n += 1 end
        if #es.Bleeds > 0 then n += 1 end
        if now < es.ChillUntil or now < (es.FrozenUntil or 0) then n += 1 end
        if now < (es.ShockUntil or 0) then n += 1 end
        if Sig.Withers(es, now) > 0 then n += 1 end
        return n
    end
    -- condition Shocked (Thunderhead): the hit context's Shocked flag (set in the hit handler)
    Asc.WHEN.Shocked = function(c) return c.Shocked == true end

    -- BEFORE the crit roll (hit handler, after Asc.PreHit): more damage from MARK / FIRST CONTACT / ARM'S LENGTH / PLAGUE and
    -- Specter's boss rule; also places Spotter's mark and counts Fastdraw's targets. -> multiplier
    function Sig.PreHit(player: Player, state: any, stats: any, model: Instance, consumesAmmo: boolean, shotDist: number?): number
        local id, P, key = Sig.Of(stats)
        if not id then return 1 end
        local now = os.clock()
        local es: any = enemyStatus[model]
        if id == "SIG_SPOTTER" then
            local s = Sig.St(player)
            local mk = s.Mark
            if mk and (mk.Parent == nil or mk:GetAttribute("Dead") or now - (s.MarkAt or 0) > (P.Idle or 6)) then
                if mk.Parent then mk:SetAttribute(Asc.MarkAttr(player), nil) end
                s.Mark, mk = nil, nil
            end
            if not mk and consumesAmmo then
                s.Mark, mk = model, model
                local pos = EnemyRootPos(model)
                if pos and Sig.Draw(player) then CombatServer.Off.Ring(player, pos, 5, Color3.fromRGB(90, 230, 230)) end
            end
            if mk == model then
                s.MarkAt = now
                model:SetAttribute(Asc.MarkAttr(player), now + (P.Idle or 6)) -- (= "Marked" for the spec's other notables)
                return 1 + (P.More or 0.25)
            end
        elseif id == "SIG_SPECTER" then
            if Sig.Boss(model) then return 1 + (P.BossPer or 0.02) * Sig.Withers(es, now) end
        elseif id == "SIG_FASTDRAW" then
            local s = Sig.St(player)
            if consumesAmmo then
                s.FirstPull = nil
                if not s.Seen[model] then s.Seen[model] = true; s.FirstPull = model; Sig.Note(s) end
                -- 5 different enemies within 3 s -> the fire-rate buff (its stats ride on this Fx entry: StatCalculator adds them)
                s.Recent[model] = now
                local n = 0
                for m, t in pairs(s.Recent) do
                    if now - t <= (P.Window or 3) then n += 1 else s.Recent[m] = nil end
                end
                if n >= (P.Targets or 5) and key then
                    table.clear(s.Recent)
                    Asc.AddBuff(state, key, { Dur = P.Dur or 4, Max = 1 })
                    SyncStateEv:FireClient(player, state) -- (the client fires at the faster rate too)
                end
            end
            if s.FirstPull == model then return 1 + (P.More or 0.6) end
        elseif id == "SIG_IRONSIDE" then
            if shotDist and shotDist <= (P.R or 8) then return 1 + (P.More or 0.25) end
        elseif id == "SIG_PLAGUECALLER" then
            return 1 + (P.Per or 0.12) * Sig.Ailments(es, now)
        end
        return 1
    end
    -- EXECUTE (Specter): the cull threshold from the target's Wither stacks (never bosses; DealEnemyDamage halves an elite's
    -- threshold, so it is doubled here: elites die at the same health share)
    function Sig.Cull(player: Player, stats: any, model: Instance): number
        local P = Sig.Has(stats, "SIG_SPECTER")
        if not P or Sig.Boss(model) then return 0 end
        local n = Sig.Withers(enemyStatus[model], os.clock())
        if n <= 0 then return 0 end
        local c = math.min(P.Cap or 0.2, (P.Per or 0.04) * n)
        return (model:GetAttribute("IsElite") == true) and c * 2 or c
    end
    -- AFTER a non-lethal hit (after TypeAilments): SHATTER + CRYOSTASIS (a new Freeze), STATIC (a new Shock), PLAGUE spread,
    -- SUPPRESSOR stacks. hit = the hit's damage (the whole shotgun blast)
    function Sig.AfterHit(player: Player, state: any, stats: any, model: Instance, hit: number, hitPos: Vector3, pellets: number, consumesAmmo: boolean)
        local id, P = Sig.Of(stats)
        if not id or not model.Parent or model:GetAttribute("Dead") then return end
        local now = os.clock()
        local s = Sig.St(player)
        if id == "SIG_SIEGEBREAKER" then
            if not consumesAmmo then return end
            local es: any = GetStatus(model)
            local sp = es.SigSup
            if sp and sp.Owner == player and Sig.SupN(sp, now) > 0 then
                sp.N = math.min(P.Max or 15, Sig.SupN(sp, now) + 1)
            else
                sp = { Owner = player, N = 1, Per = P.Per or 0.04, Grace = P.Grace or 0.6, Decay = P.Decay or 0.25 }
                es.SigSup = sp
            end
            sp.At = now
            return
        end
        local es: any = enemyStatus[model]
        if not es then return end
        if id == "SIG_LONGWATCH" or id == "SIG_FROSTBINDER" then
            local fu = es.FrozenUntil or 0
            if fu > now and s.Frz[model] ~= fu then
                s.Frz[model] = fu
                Sig.Note(s)
                if id == "SIG_FROSTBINDER" then
                    local wmax = stats.Ward or 0
                    if wmax > 0 then
                        local sa = state :: any
                        sa._WardMax = sa._WardMax or wmax
                        sa.WardPool = math.min(sa._WardMax, (sa.WardPool or sa._WardMax) + wmax * (P.Ward or 0.1))
                        CombatServer.WardSync(player, sa)
                    end
                else
                    local hp, mh = model:GetAttribute("Health") or 0, model:GetAttribute("MaxHealth") or 1
                    if hp / mh < (P.Below or 0.3) then
                        local pos = EnemyRootPos(model) or hitPos
                        local col = CombatServer.DT.COLOR.Cryo
                        if Sig.Draw(player) then CombatServer.Off.Ring(player, pos, P.R or 10, col) end
                        for _, m in ipairs(NearestEnemies(pos, P.R or 10, model, player, P.N or 6)) do
                            DealEnemyDamage(player, state, m, hit * (P.Pct or 0.4) * CombatServer.Off.ResistMult(m, player, { Cryo = 1 }), stats, { Kind = "Explosion", DType = "Cryo", Depth = 1 })
                        end
                        if not Sig.Boss(model) and model.Parent and not model:GetAttribute("Dead") then -- (bosses are never shattered)
                            DealEnemyDamage(player, state, model, 0.1, stats, { Kind = "Explosion", DType = "Cryo", Cull = 1, Position = pos, Depth = 1 })
                        end
                    end
                end
            end
        elseif id == "SIG_BULLETSTORM" then
            local su = es.ShockUntil or 0
            if su > now and s.Shk[model] ~= su then
                s.Shk[model] = su
                Sig.Note(s)
                s.ShockN += 1
                if s.ShockN >= (P.Every or 8) then
                    s.ShockN = 0
                    local from = EnemyRootPos(model) or hitPos
                    local draw = Sig.Draw(player)
                    local col = CombatServer.DT.COLOR.Volt
                    for _, m in ipairs(NearestEnemies(from, P.R or 20, model, player, P.N or 3)) do
                        local to = EnemyRootPos(m)
                        if draw and to then ArcFx(player, from, to, col) end
                        DealEnemyDamage(player, state, m, hit * (P.Pct or 0.5) * CombatServer.Off.ResistMult(m, player, { Volt = 1 }), stats, { Kind = "Arc", DType = "Volt", Depth = 1 })
                    end
                end
            end
        elseif id == "SIG_PLAGUECALLER" then
            local void = (stats.DamageShares and stats.DamageShares.Void) or 0
            if void > 0 and now - (s.PlagueAt or 0) >= 0.25 and Sig.Ailments(es, now) >= (P.Spread or 4) then
                s.PlagueAt = now
                local from = EnemyRootPos(model) or hitPos
                local draw = Sig.Draw(player)
                for _, m in ipairs(NearestEnemies(from, P.R or 12, model, player, P.N or 3)) do
                    local to = EnemyRootPos(m)
                    if draw and to then ArcFx(player, from, to, CombatServer.DT.COLOR.Void) end
                    InflictAilment("Wither", player, state, stats, m, hit * void, to or from, 1)
                end
            end
        end
    end
    -- SUPPRESSOR: live stacks (full while you keep hitting; after Grace s without a hit one falls off every Decay s)
    function Sig.SupN(sp: any, now: number): number
        local idle = now - (sp.At or 0) - (sp.Grace or 0.6)
        if idle <= 0 then return sp.N or 0 end
        return math.max(0, (sp.N or 0) - math.floor(idle / math.max(0.05, sp.Decay or 0.25)) - 1)
    end
    -- EnemyTakenMult: the Suppressor stacks on this enemy (damage taken from everything)
    function Sig.TakenMult(sx: any, now: number): number
        local sp = sx.SigSup
        if not sp then return 1 end
        local n = Sig.SupN(sp, now)
        if n <= 0 then sx.SigSup = nil; return 1 end
        return 1 + (sp.Per or 0.04) * n
    end
    -- before ShotModFx: MARK -- Chain / Fork hits off your marked enemy deal full damage (stats.ShotFx's tables are fresh per hit)
    function Sig.PreShotFx(player: Player, stats: any, model: Instance)
        local fx = type(stats.ShotFx) == "table" and stats.ShotFx
        if not fx or not Sig.Has(stats, "SIG_SPOTTER") or Sig.St(player).Mark ~= model then return end
        if type(fx.Chain) == "table" then fx.Chain.Pct = math.max(fx.Chain.Pct or 0, 1) end
        if type(fx.Fork) == "table" then fx.Fork.Pct = math.max(fx.Fork.Pct or 0, 1) end
    end
    -- PierceShot, per enemy pierced (i = 1, 2, ...): LANCER -- the Need-th refunds the round, from the next one on +More
    -- (multiplies the shot's running damage once, so it carries to everything after)
    function Sig.Lancer(stats: any, state: any, i: number): number
        local P = Sig.Has(stats, "SIG_SPEARHEAD")
        if not P then return 1 end
        local need = P.Need or 3
        if i == need and (state.MaxMag or 0) > 0 then state.CurrentMag = math.min(state.MaxMag, (state.CurrentMag or 0) + 1) end
        if i == need + 1 then return 1 + (P.More or 0.2) end
        return 1
    end
    -- ON KILL (OnKillEffectsRef, any of your kills): MARK released, DEMOLITION, WILDFIRE
    function Sig.OnKill(player: Player, state: any, model: Instance, stats: any, maxHp: number, depth: number?)
        local id, P = Sig.Of(stats)
        if not id then return end
        if model:GetAttribute("IsPracticeDummy") or model:GetAttribute("DpsDummy") then return end
        local pos = EnemyRootPos(model)
        if not pos then return end
        if id == "SIG_SPOTTER" then
            local s = Sig.St(player)
            if s.Mark == model then s.Mark = nil end
        elseif id == "SIG_SAPPER" then
            if (depth or 0) >= 2 or (maxHp or 0) <= 0 then return end -- (a blast's kill explodes once more, then it stops)
            local fx = type(stats.ShotFx) == "table" and stats.ShotFx or {}
            local r = (P.R or 8) * (1 + math.max(-0.5, (stats.Cond and stats.Cond.AreaRadius) or 0))
            local dmg = maxHp * (P.Pct or 0.15) * (fx.AreaMult or math.max(0.1, 1 + ((stats.Cond and stats.Cond.AreaDamage) or 0)))
            local shares = stats.DamageShares or { Kinetic = 1 }
            if Sig.Draw(player) then CombatServer.Off.Ring(player, pos, r, CombatServer.DT.COLOR[stats.DamageType or "Kinetic"] or Color3.fromRGB(255, 150, 50)) end
            for _, m in ipairs(NearestEnemies(pos, r, model, player, P.N or 6)) do
                DealEnemyDamage(player, state, m, dmg * CombatServer.Off.ResistMult(m, player, shares), stats, { Kind = "Explosion", DType = stats.DamageType, Depth = (depth or 0) + 1 })
            end
        elseif id == "SIG_PYREBRAND" then
            local es: any = enemyStatus[model]
            if not es or #es.Burns == 0 then return end
            local now = os.clock()
            local best
            for _, b in ipairs(es.Burns) do
                if b.Owner == player and b.Until > now and (not best or b.Dps > best.Dps) then best = b end
            end
            if not best then return end
            local dur = math.max(2, best.Until - now)
            local draw = Sig.Draw(player)
            for _, m in ipairs(NearestEnemies(pos, P.R or 12, model, player, P.N or 3)) do
                ApplyBurn(player, m, best.Dps * dur, dur, BurnStackCap(stats.SpecialMechanics or {}))
                local to = EnemyRootPos(m)
                if draw and to then ArcFx(player, pos, to, CombatServer.DT.COLOR.Heat) end
            end
        end
    end
    -- DealEnemyDamage, a Bleed tick: BLOODSTORM leech
    function Sig.BleedLeech(player: Player, state: any, stats: any, dealt: number)
        local P = Sig.Has(stats, "SIG_GOREHOUND")
        if P and state.Health > 0 and dealt > 0 then Asc.Heal(state, dealt * (P.Leech or 0.01)) end
    end
    -- BleedStackCap: BLOODSTORM's stack cap (nil = the usual)
    function Sig.BleedCap(stats: any): number?
        local P = Sig.Has(stats, "SIG_GOREHOUND")
        return P and (P.Cap or 30) or nil
    end
    -- TypeAilments: BLOODSTORM -- the Kinetic Bleed rolls per pellet at full chance, each the size of one pellet (true)
    function Sig.PelletBleed(stats: any, t: string, pellets: number): boolean
        return t == "Kinetic" and pellets > 1 and Sig.Has(stats, "SIG_GOREHOUND") ~= nil
    end
    -- DamagePlayer, before the Agility roll: GHOST -- an ordinary strike inside the window misses (true = it missed; the miss
    -- is announced like a dodge). Mechanics / hazards are never Evadable, so they never miss; (AGILITY vs BOSSES 2026-10-24) a
    -- boss's plain hit is Evadable but Ghost can't FORCE it to miss (opts.Boss: it rolls your evade chance as usual) -- a
    -- dodged boss hit still arms Ghost for the adds.
    function Sig.GhostMiss(player: Player, state: any, stats: any, opts: any): boolean
        if type(opts) ~= "table" or not opts.Evadable or opts.Boss or not Sig.Has(stats, "SIG_OUTRIDER") then return false end
        local s = Sig.St(player)
        if (s.GhostN or 0) > 0 and os.clock() <= (s.GhostUntil or 0) then
            s.GhostN -= 1
            Remotes.GetEvent("PlayerDamaged"):FireClient(player, 0, state.Health, state.MaxHealth, "Evade", nil)
            return true
        end
        return false
    end
    -- DamagePlayer, a real dodge: GHOST arms (once every Cooldown s)
    function Sig.OnEvade(player: Player, stats: any)
        local P = Sig.Has(stats, "SIG_OUTRIDER")
        if not P then return end
        local s = Sig.St(player)
        local now = os.clock()
        if now < (s.GhostReady or 0) then return end
        s.GhostN, s.GhostUntil, s.GhostReady = P.N or 2, now + (P.Window or 2), now + (P.Cooldown or 6)
    end
    -- DamagePlayer, after Guard: ARM'S LENGTH -- less damage taken while an enemy is within R studs of you
    function Sig.TakenLess(player: Player, stats: any, from: Vector3?): number
        local P = Sig.Has(stats, "SIG_IRONSIDE")
        if not P then return 1 end
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not (root and root:IsA("BasePart")) then return 1 end
        local r = P.R or 8
        local near = (from ~= nil and (root.Position - from).Magnitude <= r) or #EnemiesNear(root.Position, r, nil, player) > 0
        return near and (1 - (P.Less or 0.2)) or 1
    end
    -- DevCmd ["sig", "cluster", "Burn,Wither"]: the kill side of the signatures through the real pipeline -- picks your enemy
    -- with the most others within 8 studs, gives it those ailments (InflictAilment, 20% of its max health as the hit), kills it
    -- with a gun-hit DealEnemyDamage (OnKillEffects -> Demolition / Wildfire / Mark), and reports its neighbours before / after
    function Sig.TestCluster(player: Player, state: any, stats: any, ails: string?): string
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not (root and root:IsA("BasePart")) then return "no character" end
        local all = EnemiesNear(root.Position, 500, nil, player)
        local best, bn, nb = nil, -1, {}
        for _, m in ipairs(all) do
            local pos = EnemyRootPos(m)
            local list = pos and EnemiesNear(pos, 8, m, player) or {}
            if #list > bn then best, bn, nb = m, #list, list end
        end
        if not best then return "no enemies" end
        local now = os.clock()
        local function Snap(): string
            local o = {}
            for _, m in ipairs(nb) do
                local es: any = enemyStatus[m]
                table.insert(o, string.format("%s %.1f/%.1f burns=%d ail=%d", m.Name, m:GetAttribute("Health") or 0, m:GetAttribute("MaxHealth") or 0,
                    es and #es.Burns or 0, Sig.Ailments(es, os.clock())))
            end
            return table.concat(o, "; ")
        end
        local before = Snap()
        local mh = best:GetAttribute("MaxHealth") or 1
        local pos = EnemyRootPos(best) or root.Position
        for a in string.gmatch(ails or "", "[^,]+") do InflictAilment(a, player, state, stats, best, mh * 0.2, pos, 1) end
        local hadAil = Sig.Ailments(enemyStatus[best], now)
        local _, killed = DealEnemyDamage(player, state, best, (best:GetAttribute("Health") or 0) * 10 + 1, stats, { Kind = "Hit", Position = pos })
        return string.format("target %s (ailments %d) killed=%s | BEFORE %s | AFTER %s", best.Name, hadAil, tostring(killed), before, Snap())
    end
    -- DevCmd ["sig"] / ["sig", "near"]: the signature + its live state (and the nearest enemies' ailments / stacks)
    function Sig.Debug(player: Player, state: any, stats: any, near: boolean?): string
        local id, P = Sig.Of(stats)
        local s = Sig.St(player)
        local now = os.clock()
        local ps = {}
        for k, v in pairs(P or {}) do table.insert(ps, k .. "=" .. tostring(v)) end
        table.sort(ps)
        local out = string.format("sig=%s {%s} mark=%s ghost=%d (%.1fs, ready in %.1fs) shockN=%d regen=%.1f/s over=%.3f ward=%s/%s mag=%s/%s fr=%.2f",
            tostring(id), table.concat(ps, ","), s.Mark and s.Mark.Name or "-", s.GhostN or 0, math.max(0, (s.GhostUntil or 0) - now),
            math.max(0, (s.GhostReady or 0) - now), s.ShockN or 0, stats.HPRegen or 0, StatCalculator.SigOvercap and StatCalculator.SigOvercap(stats) or 0,
            tostring((state :: any).WardPool), tostring(stats.Ward), tostring(state.CurrentMag), tostring(state.MaxMag), stats.FireRate or 0)
        if near then
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root and root:IsA("BasePart") then
                for _, m in ipairs(NearestEnemies(root.Position, 300, nil, player, 6)) do
                    local es: any = enemyStatus[m]
                    local sp = es and es.SigSup
                    out ..= string.format(" | %s hp=%.0f/%.0f wither=%d ail=%d frozen=%s shock=%s sup=%d taken=%.2f", m.Name, m:GetAttribute("Health") or 0,
                        m:GetAttribute("MaxHealth") or 0, Sig.Withers(es, now), Sig.Ailments(es, now), tostring(es ~= nil and now < (es.FrozenUntil or 0)),
                        tostring(es ~= nil and now < (es.ShockUntil or 0)), sp and Sig.SupN(sp, now) or 0, EnemyTakenMult(m))
                end
            end
        end
        return out
    end
end

-- After a hit lands: passive-tree / gem effects that follow up on it (single target -- 2026-10-02 precision rework).
local function TreeHitEffects(player: Player, state: any, stats: any, model: Instance, hitDmg: number, hitPos: Vector3, isWeakSpot: boolean, isCrit: boolean, pellets: number, consumesAmmo: boolean)
    local mech = stats.SpecialMechanics or {}
    -- Reactor Core (Mythic): every 8th trigger pull that hits overloads its target.
    if mech.REACTOR_CORE and consumesAmmo then
        state.ReactorCount = (state.ReactorCount or 0) + 1
        if state.ReactorCount >= 8 then
            state.ReactorCount = 0
            if model.Parent and not model:GetAttribute("Dead") then
                BlastFx(player, hitPos, 3, Color3.fromRGB(120, 255, 140))
                DealEnemyDamage(player, state, model, hitDmg * pellets * 1.5, stats, { Kind = "Arc" })
            end
        end
    end
end

-- When one of your hits / DoTs / blasts kills an enemy: heal on kill, burn spread, shatter, kill
-- explosions, Midas Touch. depth stops endless kill chains (3 links).
OnKillEffectsRef = function(player: Player, state: any, model: Instance, stats: any, maxHp: number, depth: number)
    local cond = stats.Cond or {}
    local mech = stats.SpecialMechanics or {}
    pcall(CombatServer.Off.ShotModKill, player, state, model, stats, maxHp, depth) -- (UPDATE 8 OFFENSE phase 3: Mark jump, Detonate)
    Asc.OnKill(player, state, stats, model)
    pcall(CombatServer.CB.Sig.OnKill, player, state, model, stats, maxHp, depth) -- (CLASS BUILDS) SIGNATURE: Demolition / Wildfire / Mark
    if (cond.KillHeal or 0) > 0 and state.Health > 0 then
        state.Health = math.min(state.MaxHealth, math.round((state.Health + state.MaxHealth * cond.KillHeal) * 10) / 10)
    end
    if mech.MIDAS_TOUCH and math.random() < 0.12 then
        local g = model:GetAttribute("GoldReward")
        if g and not model:GetAttribute("IsPracticeDummy") then
            state.Gold += math.round(g * KILL_GOLD_MULT * 5 * (stats.GoldBonusMult or 1))
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "MIDAS x6 GOLD", Color3.fromRGB(255, 215, 80))
        end
    end
    -- (the old burn-spread / shatter / kill-explosion splashes were removed in the 2026-10-02 precision rework: no AOE;
    -- depth is still passed by the legacy launcher splash)
    local _ = depth
end

-- Unique weapon traits (single-target catalog, 2026-10-02). TraitPreHit = damage changes before the hit lands,
-- RollUniqueTrait = what follows a hit.
local function TraitPreHit(state: any, weapon: any, model: Instance, consumesAmmo: boolean, sameTarget: boolean, isNewTarget: boolean, ctx: any?): (number, number)
    local trait = weapon and weapon.UniqueTrait
    if not trait then return 1, 0 end
    local id = trait.Id
    local now = os.clock()
    local c = ctx or {}
    -- 0.51 traits
    if id == "SteadyHands" then return c.Moving and 1 or 1.15, 0 end
    if id == "OpeningVolley" then
        state.TraitSeen = state.TraitSeen or setmetatable({}, { __mode = "k" })
        if consumesAmmo then state.TraitPull = (state.TraitPull or 0) + 1 end
        local seen = state.TraitSeen[model]
        if seen and seen ~= state.TraitPull then return 1, 0 end -- (a later pull; this pull's other pellets still count)
        state.TraitSeen[model] = state.TraitPull
        return 1.6, 0
    end
    if id == "Momentum" then
        if now > (state.MomentumUntil or 0) then state.MomentumN = 0 end
        return 1 + 0.1 * math.min(5, state.MomentumN or 0), 0
    end
    if id == "Brittle" then return ((c.Ail or 0) > 0) and 1.3 or 1, 0 end
    if id == "Headhunter" then return c.Weak and 1.35 or 0.9, 0 end
    if id == "Overcharge" then return ((c.HpFrac or 0) > 0.9) and 1.75 or 1, 0 end
    if id == "HyperBeam" and (state.CurrentMag or 99) <= 2 then return 2, 0 end -- Last Light: the last 3 rounds
    if id == "Guillotine" then return 1, 0.15 end
    if id == "Bloodhound" and (state.HoundUntil or 0) > now and isNewTarget then
        if consumesAmmo then state.HoundUntil = 0 end
        return 1.8, 0
    end
    if id == "HuntersFocus" then return 1 + math.min(0.5, 0.05 * (state.SameTargetHits or 0)), 0 end
    if id == "PhantomRound" and consumesAmmo then
        state.PhantomCount = (state.PhantomCount or 0) + 1
        if state.PhantomCount >= 6 then state.PhantomCount = 0; return 3, 0 end
    end
    return 1, 0
end

local function RollUniqueTrait(player: Player, state: any, stats: any, weapon: any, model: Instance, hitDmg: number, hitPos: Vector3, isWeakSpot: boolean, isCrit: boolean)
    local trait = weapon and weapon.UniqueTrait
    if not trait then return end
    local id = trait.Id
    local alive = model.Parent ~= nil and not model:GetAttribute("Dead")
    if id == "VampiricSoul" then
        state.Health = math.min(state.MaxHealth, math.round((state.Health + hitDmg * 0.15) * 10) / 10)
    elseif id == "MarrowTap" and isWeakSpot then
        state.Health = math.min(state.MaxHealth, math.round((state.Health + state.MaxHealth * 0.02) * 10) / 10)
    elseif id == "Singularity" and isWeakSpot and alive and math.random() < 0.30 then
        BlastFx(player, hitPos, 2.5, Color3.fromRGB(170, 90, 255))
        DealEnemyDamage(player, state, model, hitDmg * 0.8, stats, { Kind = "Arc" })
    elseif id == "Supernova" and isCrit and alive and math.random() < 0.35 then
        ApplyBurn(player, model, hitDmg * 1.5, 3.0, 1)
    elseif id == "ChainLightning" and alive then
        if state.StaticModel ~= model then state.StaticModel, state.StaticCount = model, 0 end
        state.StaticCount = (state.StaticCount or 0) + 1
        if state.StaticCount >= 5 then
            state.StaticCount = 0
            local top = hitPos + Vector3.new(0, 18, 0)
            ArcFx(player, top, hitPos, Color3.fromRGB(120, 200, 255))
            DealEnemyDamage(player, state, model, hitDmg * 2.5, stats, { Kind = "Arc" })
        end
    elseif id == "TemporalStasis" and alive and math.random() < 0.35 then
        ApplySlow(model, 0.5, 2.5)
    end
end

-- PIERCE (high-caliber guns, 2026-10-02): the shot carries on through its target into the enemies lined up behind
-- it (along the line from your head through the hit, within 90 studs, ~3 studs either side). bodyDmg = the hit's
-- damage without its weak-spot bonus. Returns how many enemies it pierced.
local function PierceShot(player: Player, state: any, stats: any, weapon: any, model: Instance, bodyDmg: number, hitPos: Vector3): number
    local pr = ItemData.PierceOf(weapon)
    local smp = type(stats.ShotFx) == "table" and stats.ShotFx.Pierce -- (UPDATE 8 OFFENSE phase 3: the Pierce mod adds targets)
    if smp then pr = { Targets = (pr and pr.Targets or 0) + smp.N, Falloff = math.max(pr and pr.Falloff or 0, smp.Keep) } end
    pr = CombatServer.CB.Family.Pierce(weapon, pr) -- (CLASS BUILDS) FAMILY: rifles +1 growing, lances the whole line
    pr = CombatServer.Zen.Pierce(stats, pr) -- (CHASE ITEMS: Long Promise -- every enemy in the line, +20% per enemy passed)
    if not pr then return 0 end
    local cond = stats.Cond or {}
    local mech = stats.SpecialMechanics or {}
    local count = pr.Targets + math.floor(cond.PierceCount or 0) + (mech.HIGH_CALIBER and 1 or 0)
    local keep = (mech.HIGH_CALIBER or mech.PENETRATOR) and 1 or pr.Falloff
    if pr.Cap then count = math.min(count, pr.Cap) end -- (CLASS BUILDS) FAMILY: at most 8 a shot
    local head = player.Character and player.Character:FindFirstChild("Head")
    if count <= 0 or not (head and head:IsA("BasePart")) then return 0 end
    local dir = hitPos - head.Position
    if dir.Magnitude < 0.1 then return 0 end
    dir = dir.Unit
    local line = {}
    for _, m in ipairs(EnemiesNear(hitPos, 92, model, player)) do
        local pos = EnemyRootPos(m)
        if pos then
            local t = (pos - hitPos):Dot(dir)
            local off = ((pos - hitPos) - dir * t).Magnitude
            if t > 0.5 and t < 90 and off < 3.2 then table.insert(line, { M = m, T = t }) end
        end
    end
    table.sort(line, function(a, b) return a.T < b.T end)
    local dmg = bodyDmg * (1 + (cond.PierceDamage or 0))
    local n = 0
    for i = 1, math.min(count, #line) do
        dmg *= keep
        if mech.PENETRATOR then dmg *= 1.15 end
        dmg *= CombatServer.CB.Sig.Lancer(stats, state, i) -- (CLASS BUILDS) SIGNATURE: Lancer
        DealEnemyDamage(player, state, line[i].M, dmg * (1 + (pr.Grow or 0) * i), stats, { Kind = "Arc" }) -- (CLASS BUILDS) FAMILY: x (1 + Grow per enemy passed)
        n += 1
        state.CB_LineEnd = line[i].M -- (CLASS BUILDS) FAMILY: the lance fork's start
    end
    if n > 0 then
        ArcFx(player, hitPos, hitPos + dir * line[math.min(count, #line)].T, Color3.fromRGB(255, 235, 170))
        state.StatsTracking.PierceHits = (state.StatsTracking.PierceHits or 0) + n
    end
    return n
end

-- ==================== PLAYER STATUS (enemy elemental attacks) ====================
-- Fire -> Burn (damage over time), Cold -> Chill (slower movement), Chaos -> Decay (take more damage),
-- Physical "Bleed" attacks -> Bleed (damage over time). Resistances reduce both the hit and the effect.
type PlayerStatus = { DotList: { any }, ChillUntil: number, ChillSlow: number, DecayUntil: number, DecayInc: number }
local playerStatus: { [Player]: PlayerStatus } = {}
local function GetPlayerStatus(p: Player): PlayerStatus
    local ps = playerStatus[p]
    if not ps then
        ps = { DotList = {}, ChillUntil = 0, ChillSlow = 0, DecayUntil = 0, DecayInc = 0 }
        playerStatus[p] = ps
    end
    return ps
end
local function ClearPlayerStatus(p: Player)
    playerStatus[p] = nil
    for _, k in ipairs({ "Burning", "Bleeding", "Chilled", "Withered", "Shocked" }) do p:SetAttribute(k, false) end
    p:SetAttribute("WitherStacks", nil)
    p:SetAttribute("ChillMult", 1)
end
Players.PlayerRemoving:Connect(function(p) playerStatus[p] = nil end)

local function CurrentDifficulty(player: Player, state: any): string
    local run = PartyRuns.RunOfPlayer(player)
    if run then return run.Config.Difficulty end
    return (DungeonRuns.Attr(player, "RaidActive") and DungeonRuns.Attr(player, "Difficulty")) or state.DungeonDifficulty or "Easy"
end
CombatServer.CurrentDifficulty = CurrentDifficulty
-- GLOBAL DROP FEED (0.97): DropFeed(name, displayName, userId, item, kind, rarityLabel, oneIn) to every player.
-- oneIn = the base odds of that rarity on that difficulty (RarityWindow without luck); exotics send 0 ("ultra rare").
CombatServer._lastFeed = {} -- (a field, not a local: this chunk is near Luau's 200-local limit)
function CombatServer.AnnounceDrop(player: Player, state: any, item: any, kind: string)
    local diff = CurrentDifficulty(player, state)
    if ItemData.DropExcitement(item, diff) < 2 then return end
    local now = os.clock()
    local lf = CombatServer._lastFeed
    if lf[player] and now - lf[player] < 2 then return end -- (a superboss burst: one line)
    lf[player] = now
    local oneIn = 0
    if not item.Exotic then
        local x = ItemData.RarityOneIn(RarityRank[item.Rarity] or 1, diff) -- (RARITY v4: the difficulty names cap + area)
        if x < math.huge then oneIn = math.max(1, math.round(x)) end
    end
    local label = (ItemData.RarityLabel and ItemData.RarityLabel(item)) or item.Rarity
    if not item.Exotic and ItemData.HasTopTierLine(item) then label ..= " • top tier" end -- (RARITY v4: the item-level chase)
    Remotes.GetEvent("DropFeed"):FireAllClients(player.Name, player.DisplayName, player.UserId, item, kind, label, oneIn, ItemData.ParseRunKey(diff))
    if CombatServer.OnDropFeed then -- (UPDATE 7 LIVING HUB: the plaza's drop board)
        pcall(CombatServer.OnDropFeed, player.DisplayName, (item.Exotic and ItemData.DisplayName and ItemData.DisplayName(item)) or item.Name or "?", label, oneIn,
            (ItemData.ItemColor and ItemData.ItemColor(item)) or ItemData.RarityColors[item.Rarity])
    end
end
Players.PlayerRemoving:Connect(function(p) CombatServer._lastFeed[p] = nil end)

-- ==================== BLACK MARKET (per player, restocks every hour on the hour) ====================
-- Every player has their own stock, rolled at their own level and saved (state.ShopStock = { Hour, Items }), so
-- another player's purchase never takes an item away from you and rejoining doesn't reroll it. Odds are the
-- shop's own (not the loot table): Legendary is the best it can roll, at 0.5% per item; never Mythic.
-- Prices scale with rarity and item level.
CombatServer.SHOP_ODDS = { { "Common", 52 }, { "Uncommon", 40 }, { "Rare", 8 } } -- (RARITY v4: Rare is the best it rolls; never Mythic)
CombatServer.SHOP_PRICE = { Common = 120, Uncommon = 320, Rare = 4000 }
local SHOP_WEAPONS, SHOP_GEAR = 4, 2

local function ShopHour(): number return os.time() // 3600 end
local function ShopSecondsLeft(): number return 3600 - (os.time() % 3600) end

local function RollShopRarity(): string
    local total = 0
    for _, o in ipairs(CombatServer.SHOP_ODDS) do total += o[2] end
    local r = math.random() * total
    for _, o in ipairs(CombatServer.SHOP_ODDS) do
        r -= o[2]
        if r <= 0 then return o[1] end
    end
    return "Common"
end

local function ShopPrice(item: any, isGear: boolean): number
    local base = CombatServer.SHOP_PRICE[item.Rarity] or 120
    local lvl = math.max(1, item.ItemLevel or 1)
    local price = base * (1 + (lvl - 1) * 0.06) * (isGear and 0.75 or 1)
    return math.max(10, math.round(price / 10) * 10)
end

local function EnsureShop(state: any): any
    local hour = ShopHour()
    local shop = state.ShopStock
    if type(shop) == "table" and shop.Hour == hour and type(shop.Items) == "table" then return shop end
    local items = {}
    local lvl = state.Level or 1
    for _ = 1, SHOP_WEAPONS do
        local w = ItemData.GenerateRandomWeapon(RollShopRarity(), 1.0, RollItemLevelNear(lvl), false)
        table.insert(items, { Item = w, Type = "Weapon", Price = ShopPrice(w, false) })
    end
    for _ = 1, SHOP_GEAR do
        local g = ItemData.GenerateRandomGear(ItemData.RandomGearSlot(), RollShopRarity(), 1.0, RollItemLevelNear(lvl), false)
        table.insert(items, { Item = g, Type = "Gear", Price = ShopPrice(g, true) })
    end
    shop = { Hour = hour, Items = items }
    state.ShopStock = shop
    return shop
end
CombatServer.EnsureShop = EnsureShop

-- XP to go from `level` to level+1. Kill XP grows with level (enemy rewards), so this curve is what sets
-- the pace: ~1h to 10, ~10h to 30, ~35h to 50, ~80h to 60 (tuned by simulation, see the design doc).
function CombatServer.XpToNext(level: number): number
    return ItemData.XpToNext(level) -- (the curve lives in ItemData now: enemy XP is built from it)
end
function CombatServer.XpToNextRaw(level: number): number
    -- (x1.5, playtester 2026-10-02: "make it harder to level")
    -- LEVEL 100 (2026-10-04): from 60 on a level costs 75% of the old level-60 step, +2% per level (the old curve
    -- would have made level 99 ~35x a level-60 level). 60 -> 100 is ~4.7x the XP of 1 -> 60 (kill XP also grows).
    local late = ItemData.LATE_LEVEL or 60
    if level >= late then
        return math.round(213 * late ^ 1.1 * 1.078 ^ late * 0.75 * 1.02 ^ (level - late))
    end
    return math.round(213 * level ^ 1.1 * 1.078 ^ level)
end

function CombatServer.RecalculateMaxHealth(state: PlayerState)
    local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
    state.MaxHealth = stats.MaxHP
    ;(state :: any)._WardMax, (state :: any)._WardRate, (state :: any)._WardDelay = stats.Ward or 0, stats.WardRate, stats.WardDelay -- (UPDATE 8 DEFENCE)
    if not state.Health or state.Health > state.MaxHealth then
        state.Health = state.MaxHealth
    end
    state.MaxMag = stats.MagazineSize
    if not state.CurrentMag or state.CurrentMag > state.MaxMag then
        state.CurrentMag = state.MaxMag
    end
end

function CombatServer.GetState(player: Player): PlayerState
    if not playerStates[player] then
        -- Block until this player's save has loaded (SaveService.BeginLoad runs on join), so nothing
        -- ever sees or edits a blank starter state that would then overwrite the real save.
        local saved, canSave = SaveService.WaitForLoad(player)
        if playerStates[player] then return playerStates[player] end -- another caller built it while we waited
        local starter = ItemData.CreateStarterPistol()

        local st: PlayerState = {
            EquippedWeapon = starter,
            Inventory = { starter },
            EquippedGear = {}, -- new characters start with just the Common Glock (100 HP, no armor)
            GearInventory = {},
            AllocatedNodes = {}, -- (tree v4: grows from your class start once you pick a class)
            Gems = {}, -- skill-tree gem bag (GemData); socketed ones live in SocketedGems[socketId]
            SocketedGems = {},
            TreeVersion = 3,
            Contracts = {}, -- daily contracts (Contracts module), filled by EnsureContracts
            DailyBest = {}, -- { Day, Time, Rewarded } (EndgameServer)
            TrialBest = {}, -- aim trial personal bests { [scenarioId] = score }
            TrialRanks = {}, -- best rank reached per scenario (rewards paid once)
            Sigils = {}, -- rift keys (Rifts module)
            Blueprints = {}, -- boss blueprint fragments (Blueprints module)
            Codex = {}, -- Codex of Power: unlocked unique powers { [traitId] = true }
            PendingLoot = {}, -- ground loot not picked up yet { [id] = { Item, Kind, Pos } }
            OwnedMeleeSkins = {}, -- melee skins owned { [skinId] = true } (Factory is implicit)
            BossTrials = {}, -- endgame Boss Trials progress (BossTrials)
            MeleeSkinFor = {}, -- skin shown on each melee { [meleeId] = skinId }
            RiftBest = 0, -- highest rift tier beaten in time
            Season = {}, -- season journey progress (Seasons module)
            Streak = 0,
            SkillPoints = 1, -- (tree income: ItemData.TreePointsAt -- level 1 already has 1)
            StatPoints = 3,
            Attributes = {
                Strength = 5,
                Dexterity = 5,
                Vitality = 5,
                Luck = 5,
            },
            Gold = 350,
            UpgradeShards = 40,
            ForgeCores = 0,
            Materials = ItemData.NewMaterials(),
            LastDailyRoll = 0,
            RollsCount = 0,
            AutoSellThreshold = "OFF",
            GemAutoSalvage = "OFF", -- (0.75: gems at or under this rarity salvage when they drop)
            Level = 1,
            XP = 0,
            MaxXP = CombatServer.XpToNext(1),
            Health = 140,
            MaxHealth = 140,
            EquippedGlove = "Tactical",
            GloveInventory = { "Tactical" },
            EquippedKnife = "Knife",
            KnifeInventory = { "Knife" },
            EquippedSleeve = "Standard",
            SleeveInventory = { "Standard" },
            EquippedWeaponSkin = "Factory",
            WeaponSkinInventory = { "Factory" },
            EquippedTitle = "Rookie",
            UnlockedTitles = { "Rookie" },
            DungeonDifficulty = "Easy",
            CurrentMag = starter.MagazineSize or 18,
            MaxMag = starter.MagazineSize or 18,
            IsReloading = false,
            StatsTracking = {
                SniperHeadshots = 0,
                MeleeKills = 0,
                BossKills = 0,
                ExplosiveDamageDealt = 0,
                TotalKills = 0,
                DiscoveredWeapons = { [starter.BaseId] = true },
                HighestFloorCleared = 0,
                FloorsByDifficulty = {},
                FastestFloorClearSeconds = math.huge,
            },
            Settings = {},
            BarStyle = "Standard",
            BarStylesOwned = {},
            CosmeticsOwned = {}, -- generic cosmetic storage (future categories: armor sets, weapon skins, charms...)
            CosmeticsEquipped = {},
        }
        if saved then
            SaveService.Apply(st, saved)
            st.Health, st.CurrentMag = nil, nil -- RecalculateMaxHealth refills both from the loaded gear
            Cosmetics.StripRetired(st) -- (bundles-only line-up: retired cosmetics come off, still owned)
            Cosmetics.ClearUnknownEquipped(st) -- (Update 5 SKINS V3: old skin ids in old saves fall back to the defaults)
            ItemData.MigrateGunNames(st) -- (makers dropped from gun names, 2026-10-04)
            ItemData.MigrateGunBalance(st) -- (shotgun / sniper balance, 2026-10-05)
            -- (TRIAL OF ASCENSION, 2026-10-05: ascendancy points moved off the Boss Trials -- anyone who already earned
            -- some keeps them: their best trial tier becomes their Ascension tier, once)
            if st.AscTrialBest == nil then
                st.AscTrialBest = require(game.ReplicatedStorage.AimRngShared.AscendancyData).LegacyAscBest(st)
            end
        end
        ItemData.NormalizeRarities(st) -- (UPDATE 8 RARITY v4: old rarity names -> the 5; a fresh save just gets its flags)
        do -- (2026-11-09 AUTO-SELL FILTER) a saved KEEP-rules table is re-cleaned on every load (unknown stats / types dropped, clamped)
            local okR, r = pcall(AutoSellRules.Clean, st.AutoSellRules)
            st.AutoSellRules = okR and r or nil
        end
        pcall(CombatServer.Off.ShotModLoad, st) -- (UPDATE 8 OFFENSE phase 3: the mod bag; misfit mods back to it)
        if not canSave then (st :: any).NotSaved = true end
        ;(st :: any)._PlayTick = os.clock() -- (lifetime stats: SaveService adds play time from here at every save)
        playerStates[player] = st
        CombatServer.RecalculateMaxHealth(st)
    end
    local ps = playerStates[player]
    -- Passive tree check on first access: older tree versions are refunded, unknown or disconnected nodes
    -- become skill points again, gems in unallocated sockets go back to the bag.
    if not (ps :: any).TreeValidated then
        (ps :: any).TreeValidated = true
        require(script.Parent:WaitForChild("SkillTreeServer")).Validate(ps)
        CombatServer.EnsureContracts(player, ps)
        CombatServer.SyncBarStyle(player, ps)
        task.defer(CombatServer.CollectGroundLoot, player, ps) -- loot left on the ground last session
        -- run loot from a run that never finished (left / disconnected mid-run) counts as lost
        task.defer(function()
            local any = false
            for _, l in ipairs({ ps.Inventory or {}, ps.GearInventory or {}, ps.Gems or {} }) do
                for _, it in ipairs(l) do if type(it) == "table" and it.RunLoot then any = true end end
            end
            if any then CombatServer.ResolveRunLoot(player, false, ps) end
        end)
    end
    return playerStates[player]
end

-- ==================== SEASON JOURNEY (Seasons module) ====================
function CombatServer.AddSeasonXP(player: Player, state: any, amount: number)
    local Seasons = require(game.ReplicatedStorage.AimRngShared.Seasons)
    if not Seasons.Active() or not amount or amount <= 0 then return end
    local s = Seasons.Ensure(state)
    local before = Seasons.TierOf(s.XP)
    if s.Premium then amount = math.floor(amount * (1 + Seasons.Premium.XPBonus) + 0.5) end -- premium pass: +25% Season XP
    local gx = type(state.GuildPerks) == "table" and tonumber(state.GuildPerks.SeasonXP) or 0 -- (UPDATE 7 B9: guild research)
    if gx > 0 then amount = math.floor(amount * (1 + math.min(gx, 0.15)) + 0.5) end
    s.XP += amount
    local after = Seasons.TierOf(s.XP)
    if after > before then
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "SEASON TIER " .. after .. " reached. Claim it at the Season Pass (hub)")
    end
end

-- the premium season pass (Seasons.Premium): bought via SeasonAction "BuyPremium" (receipt above, or free in Studio)
function CombatServer.GrantSeasonPremium(player: Player, state: any)
    local Seasons = require(game.ReplicatedStorage.AimRngShared.Seasons)
    local s = Seasons.Ensure(state)
    if s.Premium then return end
    s.Premium = true
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "PREMIUM SEASON PASS UNLOCKED: claim your premium rewards at the Season Pass", Color3.fromRGB(255, 120, 200))
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
end
function CombatServer.InitSeasonPass()
    local Seasons = require(game.ReplicatedStorage.AimRngShared.Seasons)
    Remotes.GetFunction("SeasonAction").OnServerInvoke = function(player: Player, action: any)
        local state = CombatServer.GetState(player)
        if not state then return false, "Not loaded yet." end
        if action == "BuyPremium" then
            local s = Seasons.Ensure(state)
            if s.Premium then return false, "You already have the premium pass." end
            if not Seasons.Active() then return false, "This season is over." end
            if (Seasons.Premium.ProductId or 0) ~= 0 then
                game:GetService("MarketplaceService"):PromptProductPurchase(player, Seasons.Premium.ProductId)
                return true, "Prompted"
            elseif game:GetService("RunService"):IsStudio() then
                CombatServer.GrantSeasonPremium(player, state)
                return true, "Premium pass unlocked (Studio: free)."
            end
            return false, "The premium pass is coming soon."
        end
        return false
    end
end

-- (UPDATE 7 ARCHIVE: every 20 s, every player -- fills the archive from saves and catches items that skip DropToGround)
task.spawn(function()
    while true do
        task.wait(20)
        for _, p in ipairs(Players:GetPlayers()) do
            local st = playerStates[p]
            if st then pcall(CombatServer.ArchiveScan, p, st, true) end
        end
    end
end)

-- ==================== RIFTMODS (UPDATE 7 B1) ====================
-- Fit(modUid, gunUid): onto a gun of its model in your bag / hand (a mod already on it goes back to the Riftmod bag);
-- Remove(gunUid); Reroll(modUid): Riftmod Dust (Riftmods.RerollCost) for new lines; Salvage(modUid): dust.
CombatServer.RiftmodAct = function(player: Player, action: any, a: any, b: any): (boolean, string?)
    local state = playerStates[player]
    if not state then return false, "?" end
    do local hold = CombatServer.TradeHold(player, a, b); if hold then return false, hold end end -- (a gun / Gunwright offered in a trade)
    local RM = require(game.ReplicatedStorage.AimRngShared.Riftmods)
    state.Riftmods = type(state.Riftmods) == "table" and state.Riftmods or {}
    local function FindMod(uid)
        for i, m in ipairs(state.Riftmods) do if m.Uid == uid then return m, i end end
        return nil
    end
    local function FindGun(uid)
        if state.EquippedWeapon and state.EquippedWeapon.Uid == uid then return state.EquippedWeapon end
        for _, w in ipairs(state.Inventory or {}) do if w.Uid == uid then return w end end
        return nil
    end
    local msg
    if action == "Fit" then
        local m, i = FindMod(a)
        local g = FindGun(b)
        if not m or not g then return false, "That's gone." end
        if g.BaseId ~= m.Gun then return false, "This Gunwright only fits a " .. tostring(m.Gun) .. "." end
        if type(g.Riftmod) == "table" then table.insert(state.Riftmods, g.Riftmod) end
        table.remove(state.Riftmods, i)
        g.Riftmod = m
        msg = m.Name .. " fitted."
    elseif action == "Remove" then
        local g = FindGun(a)
        if not g or type(g.Riftmod) ~= "table" then return false, "No Gunwright on that gun." end
        if #state.Riftmods >= RM.BAG then return false, "Your Gunwright bag is full." end
        table.insert(state.Riftmods, g.Riftmod)
        g.Riftmod = nil
        msg = "Gunwright removed."
    elseif action == "Reroll" then
        local m = FindMod(a)
        if not m then return false, "That's gone." end
        local cost = RM.RerollCost(m)
        state.Materials = state.Materials or ItemData.NewMaterials()
        if (state.Materials.RiftDust or 0) < cost then return false, "Needs " .. cost .. " Tuning Grit." end
        state.Materials.RiftDust -= cost
        m.Lines = RM.RollLines(m.Gun, math.max(m.ItemLevel or 1, state.Level or 1))
        m.ItemLevel = math.max(m.ItemLevel or 1, state.Level or 1)
        m.Rolls = (m.Rolls or 0) + 1
        msg = "Rerolled: " .. RM.LinesText(m)
    elseif action == "Salvage" then
        local m, i = FindMod(a)
        if not m then return false, "That's gone." end
        table.remove(state.Riftmods, i)
        local n = math.random(RM.SALVAGE[1], RM.SALVAGE[2])
        GrantMaterials(player, state, { RiftDust = n }, nil, true)
        msg = "Salvaged for " .. n .. " Tuning Grit."
    else
        return false, "?"
    end
    CombatServer.RecalculateMaxHealth(state)
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    return true, msg
end
Remotes.GetFunction("RiftmodAction").OnServerInvoke = function(player: Player, action: any, a: any, b: any)
    return CombatServer.RiftmodAct(player, action, a, b)
end

-- ==================== CALIBRATION (UPDATE 7 B2) ====================
-- CalibrationFeat(player, state, kind, n): a feat done with the gun in hand (WeakKills / EliteKills add n, HsRun / HitRun
-- = the current run length, kept as the best). Only the next tier's feat counts; a toast when it's done.
function CombatServer.CalibrationFeat(player: Player, state: any, kind: string, n: number)
    local Cal = require(game.ReplicatedStorage.AimRngShared.Calibration)
    local w = state.EquippedWeapon
    if not Cal.Unlocked(state) or not w or not w.BaseId or not ItemData.BaseWeapons[w.BaseId] then return end
    local c = Cal.Of(state, w.BaseId)
    local t = (c and c.T or 0) + 1
    local d = Cal.TIERS[t]
    if not d or d.Feat ~= kind then return end
    c = c or Cal.Ensure(state, w.BaseId)
    if c.P >= d.Need then return end
    if Cal.RUN_FEAT[kind] then c.P = math.max(c.P, n) else c.P = math.round((c.P + n) * 100) / 100 end
    c.P = math.min(c.P, d.Need)
    if c.P >= d.Need then
        local def = ItemData.BaseWeapons[w.BaseId]
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "ZEROING " .. Cal.NUMERALS[t] .. " READY: " .. string.upper(def.ShortName or def.Name or w.BaseId), Cal.COLOR)
    end
end

-- CalibrationAct: Claim(gun, pick 1|2) pays the next tier (gold + currency) once its feat is done; Pick(gun, tier, pick)
-- switches a claimed tier's perk for SwitchCost gold.
CombatServer.CalibrationAct = function(player: Player, action: any, a: any, b: any, c2: any): (boolean, string?)
    local state = playerStates[player]
    if not state then return false, "?" end
    local Cal = require(game.ReplicatedStorage.AimRngShared.Calibration)
    if not Cal.Unlocked(state) then return false, "Zeroing opens at level " .. Cal.UNLOCK .. "." end
    if type(a) ~= "string" or not ItemData.BaseWeapons[a] then return false, "Pick a gun." end
    local c = Cal.Ensure(state, a)
    local msg
    if action == "Claim" then
        local t = c.T + 1
        local d = Cal.TIERS[t]
        if not d then return false, "Fully zeroed." end
        if not Cal.Ready(c) then return false, "Finish the feat first: " .. Cal.FeatText(t) .. "." end
        local pick = (b == 2) and 2 or 1
        local gold, key, n = Cal.Cost(t, state.Level)
        state.Materials = state.Materials or ItemData.NewMaterials()
        if (state.Gold or 0) < gold then return false, "Needs " .. ItemData.FormatNumber(gold) .. " gold." end
        if (state.Materials[key] or 0) < n then return false, "Needs " .. n .. " " .. ItemData.MaterialDefs[key].Name .. "." end
        state.Gold -= gold
        state.Materials[key] -= n
        c.T = t
        c.P = 0
        c.C[t] = pick
        pcall(CombatServer.SeasonGoalEvent, player, state, "Calibration", 1, { Tier = t })
        msg = "Zeroing " .. Cal.NUMERALS[t] .. ": " .. d.Choices[pick].Name .. " (" .. d.Choices[pick].Desc .. ")."
    elseif action == "Pick" then
        local t = math.floor(tonumber(b) or 0)
        local pick = (c2 == 2) and 2 or 1
        if t < 1 or t > c.T then return false, "Claim that tier first." end
        if Cal.PickOf(c, t) == pick then return false, "Already picked." end
        local gold = Cal.SwitchCost(t, state.Level)
        if (state.Gold or 0) < gold then return false, "Needs " .. ItemData.FormatNumber(gold) .. " gold." end
        state.Gold -= gold
        c.C[t] = pick
        msg = "Switched to " .. Cal.TIERS[t].Choices[pick].Name .. "."
    else
        return false, "?"
    end
    CombatServer.RecalculateMaxHealth(state)
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    return true, msg
end
Remotes.GetFunction("CalibrationAction").OnServerInvoke = function(player: Player, action: any, a: any, b: any, c2: any)
    return CombatServer.CalibrationAct(player, action, a, b, c2)
end

-- (UPDATE 7 C9) DROP RULES: the client's list, cleaned + capped (DropRules.Max), saved on the state
Remotes.GetFunction("DropRulesAction").OnServerInvoke = function(player: Player, action: any, list: any)
    local state = playerStates[player]
    if not state or action ~= "Set" then return false, "?" end
    local DR = require(game.ReplicatedStorage.AimRngShared.DropRules)
    local clean = DR.Clean(list, state)
    if not clean then return false, "Those rules didn't make sense." end
    state.DropRules = clean
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    return true, "Drop rules saved (" .. #clean .. ")."
end

-- ==================== DAILY CONTRACTS (Contracts module) ====================
function CombatServer.EnsureContracts(player: Player, state: any)
    local day = Contracts.Today()
    local want = Contracts.COUNT + require(game.ReplicatedStorage.AimRngShared.MasteryRank).ExtraContracts(state.MasteryRank) -- (UPDATE 7 perk)
    if type(state.Contracts) ~= "table" or state.Contracts.Day ~= day or type(state.Contracts.List) ~= "table" then
        state.Contracts = { Day = day, List = Contracts.Roll(player.UserId, day, want), BonusPaid = false }
    elseif #state.Contracts.List < want then
        -- a rank reached today adds its contract now (the day's roll is fixed: the first picks are the ones you have)
        local full = Contracts.Roll(player.UserId, day, want)
        for i = #state.Contracts.List + 1, want do
            if full[i] then table.insert(state.Contracts.List, full[i]) end
        end
    end
end
-- ==================== THE WEEK (UPDATE 7 A5, Weekly module): the bounty board + the weekly boss stack ====================
function CombatServer.EnsureWeekly(player: Player, state: any)
    local Weekly = require(game.ReplicatedStorage.AimRngShared.Weekly)
    local week = Weekly.Week()
    local w = state.Weekly
    if type(w) ~= "table" or w.Week ~= week or type(w.Bounties) ~= "table" then
        state.Weekly = { Week = week, Bounties = {}, BonusPaid = false, BossDone = false, Rerolls = 0 }
        w = state.Weekly
    end
    -- the board rolls the first time you're at its level this week (a later unlock gets a fresh board, not an empty one)
    if #w.Bounties == 0 and (state.Level or 1) >= Weekly.UNLOCK_BOUNTIES then
        w.Bounties = Weekly.Roll(player.UserId, week, state.Level)
    end
    return w
end
-- THE ARCHIVE (UPDATE 7 A4, ArchiveData): note what you own / found, then pay any page milestone reached
function CombatServer.ArchiveNote(state: any, item: any): boolean
    if type(item) ~= "table" or ItemData.ZenithOf(item) then return false end -- (CHASE ITEMS: a Zenith is no Ledger rarity / relic: it read "your first RELIC item")
    local A = require(game.ReplicatedStorage.AimRngShared.ArchiveData)
    local a = A.Ensure(state)
    local new = false
    local rank = ItemData.RarityRank[item.Rarity]
    if rank and not a.Rarity[tostring(rank)] then a.Rarity[tostring(rank)] = true; new = true end
    if item.Exotic and ItemData.Exotics[item.Exotic] and not a.Exotic[item.Exotic] then a.Exotic[item.Exotic] = true; new = true end
    return new
end
function CombatServer.ArchiveScan(player: Player, state: any, announce: boolean?)
    local A = require(game.ReplicatedStorage.AimRngShared.ArchiveData)
    if not A.ON or type(state) ~= "table" then return end
    local a = A.Ensure(state)
    -- (the first scan of a save fills the archive from what you already own: no "first X" lines, one summary line)
    local fresh = next(a.Rarity) == nil and next(a.Exotic) == nil and next(a.Paid) == nil
    if fresh then announce = false end
    local beforeR = {}
    for k in pairs(a.Rarity) do beforeR[k] = true end
    local function Each(list) for _, it in ipairs(type(list) == "table" and list or {}) do CombatServer.ArchiveNote(state, it) end end
    Each(state.Inventory)
    Each(state.GearInventory)
    CombatServer.ArchiveNote(state, state.EquippedWeapon)
    for _, g in pairs(type(state.EquippedGear) == "table" and state.EquippedGear or {}) do CombatServer.ArchiveNote(state, g) end
    for _, box in ipairs(require(game.ReplicatedStorage.AimRngShared.StashTabs).AllBoxes(state)) do -- (every stash tab)
        Each(box.W)
        Each(box.G)
    end
    -- (a first-of-its-rarity drop is an event: Epic and up get their own line)
    if announce then
        for rank, name in ipairs(ItemData.Rarities) do
            if rank >= ItemData.RarityRank.Rare and a.Rarity[tostring(rank)] and not beforeR[tostring(rank)] then -- (RARITY v4)
                Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "LEDGER: your first " .. string.upper(name) .. " item!", ItemData.RarityColors[name])
            end
        end
    end
    -- milestones
    local paid = 0
    for _, page in ipairs(A.Pages) do
        local n, total = A.Count(page, state)
        local done = tonumber(a.Paid[page.Id]) or 0
        while done < #page.Milestones and n >= page.Milestones[done + 1] do
            done += 1
            a.Paid[page.Id] = done
            local parts = CombatServer.PayWeekly(player, state, A.MilestoneReward(page, done))
            paid += 1
            if not fresh then
                Remotes.GetEvent("CombatFx"):FireClient(player, "Text", string.format("LEDGER %s %d / %d: %s", page.Title, page.Milestones[done], total,
                    table.concat(parts, ", ")), page.Color)
            end
        end
    end
    if fresh and paid > 0 then
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "THE LEDGER is open (Index window): your collection filled " .. paid .. " milestone" .. (paid == 1 and "" or "s") .. " and paid them out.", Color3.fromRGB(255, 196, 70))
    end
    if paid > 0 then Remotes.GetEvent("SyncPlayerState"):FireClient(player, state) end
end
function CombatServer.ArchiveEvent(player: Player, state: any, event: string, ctx: any?)
    if event == "FloorClear" and type(ctx) == "table" and type(ctx.Biome) == "string" and ctx.Biome ~= "" then
        local a = require(game.ReplicatedStorage.AimRngShared.ArchiveData).Ensure(state)
        local first = (tonumber(a.World[ctx.Biome]) or 0) == 0
        a.World[ctx.Biome] = (tonumber(a.World[ctx.Biome]) or 0) + 1
        if first then CombatServer.ArchiveScan(player, state, true) end
    end
end

-- BOUNTY CONTRACT (UPDATE 7, BountyContract): the marked elite is down -> its gun (rarity by escapes) + gold, done this week
function CombatServer.ContractKill(player: Player, state: any)
    local BC = require(game.ReplicatedStorage.AimRngShared.BountyContract)
    local c = BC.Ensure(state, player.UserId)
    if not c or c.Done then return end
    c.Done = true
    local rarity = BC.GunRarity(c, state.DungeonDifficulty)
    local lvl = math.min(CombatServer.ContentLevel(player, state), (state.Level or 1) + ItemData.IlvlAllowance(state.Level))
    local gun = ItemData.GenerateWeaponOfBase(c.Gun, rarity, lvl)
    if gun then CombatServer.DropGiven(player, state, gun, "Weapon") end
    local gold = BC.Gold(c, state.Level)
    state.Gold += gold
    pcall(CombatServer.SeasonGoalEvent, player, state, "ContractKill", 1)
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "CONTRACT FULFILLED: " .. string.upper(c.Name) .. "  (" .. tostring(gun and gun.Name or c.Gun) .. ", " .. ItemData.FormatNumber(gold) .. " gold)", Color3.fromRGB(255, 205, 80))
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
end

-- RIFTMODS (UPDATE 7 B1, Riftmods module): a new mod into the Riftmod bag (full: it's salvaged into dust on the spot)
function CombatServer.GiveRiftmod(player: Player, state: any, gun: string?): any
    local RM = require(game.ReplicatedStorage.AimRngShared.Riftmods)
    state.Riftmods = type(state.Riftmods) == "table" and state.Riftmods or {}
    local mod = RM.New(gun or RM.PickGun(state), state.Level or 1)
    if #state.Riftmods >= RM.BAG then
        local n = math.random(RM.SALVAGE[1], RM.SALVAGE[2])
        GrantMaterials(player, state, { RiftDust = n }, nil, true)
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "GUNWRIGHT BAG FULL: " .. mod.Name .. " became " .. n .. " Tuning Grit", Color3.fromRGB(120, 200, 255))
        return nil
    end
    table.insert(state.Riftmods, mod)
    pcall(CombatServer.SeasonGoalEvent, player, state, "Riftmod", 1)
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "GUNWRIGHT: " .. mod.Name .. "  (" .. RM.LinesText(mod) .. ")", Color3.fromRGB(120, 200, 255))
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    return mod
end

-- MASTERY RANK (UPDATE 7 A3): an Aim Trial result that passes the next rank's exam takes the rank (EndgameServer SubmitTrial)
function CombatServer.MasteryExam(player: Player, state: any, scenarioId: string, trialRank: number): boolean
    local MR = require(game.ReplicatedStorage.AimRngShared.MasteryRank)
    if not MR.CanExam(state) then return false end
    local r = MR.Rank(state) + 1
    local exam = MR.Exam(r)
    if exam.Scenario ~= scenarioId or (trialRank or 0) < exam.Need then return false end
    state.MasteryRank = r
    pcall(CombatServer.SeasonGoalEvent, player, state, "MasteryRank", r)
    CombatServer.EnsureContracts(player, state) -- (a contract-slot perk lands today)
    local perks = MR.Perks[r] and table.concat(MR.Perks[r], ", ") or "rank emblem"
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "MARKSMAN GRADE " .. r .. "!  " .. perks, MR.Color)
    pcall(CombatServer.UpdatePlayerTitleTag, player)
    return true
end
-- one of your unlocked crafting currencies at random (nil before any unlock)
function CombatServer.RandomUnlockedCurrency(state: any): string?
    local list = {}
    for _, k in ipairs(ItemData.CURRENCY_V5 or {}) do if ItemData.CurrencyRolls(k, state.Level) then table.insert(list, k) end end
    return (#list > 0) and list[math.random(1, #list)] or nil
end
-- (UPDATE 7 C1) the Apex's kill reward: ApexHunt.Reward + its exotic chance + the first-kill title; returns the parts
function CombatServer.PayApex(player: Player, state: any, uber: boolean, bossId: string?, stats: any): { string }
    local AH = require(game.ReplicatedStorage.AimRngShared.ApexHunt)
    local r = AH.Reward(state.Level, uber)
    local parts = {}
    state.Gold += r.Gold
    table.insert(parts, ItemData.FormatNumber(r.Gold) .. " gold")
    GrantMaterials(player, state, { Prism = r.Prism, RiftTaint = r.Taint }, nil, true)
    table.insert(parts, r.Prism .. " Prism")
    table.insert(parts, r.Taint .. " Blackflux")
    stats = stats or StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
    for _ = 1, r.Items do DropItem(player, state, stats, 2.5, "Top2") end
    table.insert(parts, r.Items .. " top items")
    if math.random() < r.Exotic then
        local BossTrials = require(game.ReplicatedStorage.AimRngShared.BossTrials)
        local pool = table.clone(BossTrials.EXOTIC_POOL and bossId and BossTrials.EXOTIC_POOL[bossId] or {})
        for _, id in ipairs(require(game.ReplicatedStorage.AimRngShared.Rifts).EXOTICS) do table.insert(pool, id) end
        local id = pool[math.random(1, #pool)]
        local item = id and ItemData.MakeExotic(id, "Relic", state.Level or 1) -- (RARITY v4)
        if item then
            if ItemData.Exotics[id].Kind == "Weapon" then table.insert(state.Inventory, item) else table.insert(state.GearInventory, item) end
            Remotes.GetEvent("LootAnnounce"):FireClient(player, item, nil, false)
            table.insert(parts, "RELIC: " .. item.Name)
        end
    end
    local title = AH.TITLE[uber and "Uber" or "Apex"]
    state.UnlockedTitles = state.UnlockedTitles or {}
    if title and not table.find(state.UnlockedTitles, title) then
        table.insert(state.UnlockedTitles, title)
        table.insert(parts, "TITLE: " .. ((ItemData.Titles[title] or {}).Title or title))
    end
    state.StatsTracking.ApexKills = (state.StatsTracking.ApexKills or 0) + 1
    for _, l in ipairs(CombatServer.Zen.Apex(player, state, uber)) do table.insert(parts, l) end -- (CHASE ITEMS: the four pinnacle Zeniths + Twin Glass)
    return parts
end

-- pays a Weekly reward table ({ Gold, Prism, Currency = n random, EachCurrency = n of each, Item = "TopN" }); returns the parts
function CombatServer.PayWeekly(player: Player, state: any, r: any, stats: any): { string }
    local parts = {}
    local mats = {}
    if r.Gold then state.Gold += r.Gold; table.insert(parts, ItemData.FormatNumber(r.Gold) .. " gold") end
    if r.Prism then mats.Prism = r.Prism; table.insert(parts, r.Prism .. " Prism") end
    if r.Currency then
        local k = CombatServer.RandomUnlockedCurrency(state)
        if k then mats[k] = (mats[k] or 0) + r.Currency; table.insert(parts, r.Currency .. " " .. ItemData.MaterialDefs[k].Name) end
    end
    if r.EachCurrency then
        local n = 0
        for _, k in ipairs(ItemData.CURRENCY_V5 or {}) do
            if ItemData.CurrencyRolls(k, state.Level) then mats[k] = (mats[k] or 0) + r.EachCurrency; n += 1 end
        end
        if n > 0 then table.insert(parts, r.EachCurrency .. " of each currency") end
    end
    GrantMaterials(player, state, mats, nil, true)
    if r.Item then
        DropItem(player, state, stats or StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state), 2.0, r.Item)
        table.insert(parts, "an item")
    end
    if r.Riftmod and (state.Level or 1) >= require(game.ReplicatedStorage.AimRngShared.Riftmods).UNLOCK then
        if CombatServer.GiveRiftmod(player, state) then table.insert(parts, "a Gunwright") end
    end
    return parts
end
-- (UPDATE 7 C8 SEASON GOALS) one event onto this season's goals; a finished goal is announced, a milestone (10 / 20 / 30 done)
-- pays its title + BOUND points + gold (+ the season's exclusive pieces at 30, once they exist). Returns true when one finished.
function CombatServer.SeasonGoalEvent(player: Player, state: any, event: string, amount: number?, ctx: any?): boolean
    local SG = require(game.ReplicatedStorage.AimRngShared.SeasonGoals)
    if not SG.ON then return false end
    local s = SG.Ensure(state)
    local done = SG.Apply(s, event, amount, ctx)
    if #done == 0 then return false end
    for _, id in ipairs(done) do
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "SEASON FEAT: " .. SG.Text(SG.ById[id]) .. "  (" .. SG.DoneCount(s) .. " / " .. #SG.List .. ")", SG.COLOR)
    end
    local n = SG.DoneCount(s)
    for _, m in ipairs(SG.MILESTONES) do
        if n >= m.Need and not s.Paid[tostring(m.Need)] then
            s.Paid[tostring(m.Need)] = true
            state.Gold += m.Gold
            if CombatServer.GrantBoundPoints then pcall(CombatServer.GrantBoundPoints, player, state, m.BP) end
            state.UnlockedTitles = state.UnlockedTitles or {}
            if m.Title and not table.find(state.UnlockedTitles, m.Title) then table.insert(state.UnlockedTitles, m.Title) end
            for _, ref in ipairs(SG.MILESTONE_COSMETICS[m.Need] or {}) do pcall(CombatServer.GrantCosmetic, player, state, ref) end
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", m.Need .. " SEASON FEATS: " .. ((ItemData.Titles[m.Title] or {}).Title or "a title") .. ", " .. m.BP .. " BOUND points, "
                .. ItemData.FormatNumber(m.Gold) .. " gold!", SG.COLOR)
        end
    end
    return true
end

-- (UPDATE 7 B5 CITY DISTRICTS) one event onto the districts' bounties: standing for each finished one (Districts.Gain: daily cap,
-- the rival's share taken). Returns true when something finished.
function CombatServer.DistrictEvent(player: Player, state: any, event: string, amount: number?, ctx: any?): boolean
    local D = require(game.ReplicatedStorage.AimRngShared.Districts)
    if not D.Unlocked(state) then return false end
    local s = D.Ensure(state, player.UserId)
    local done = D.Apply(s, event, amount, ctx)
    for _, f in ipairs(done) do
        local d = D.Defs[f.District]
        local add = D.Gain(s, f.District, D.StandingFor(state.Level))
        local gold = math.round(1000 * (1 + (state.Level or 1) / 40))
        state.Gold += gold
        pcall(CombatServer.SeasonGoalEvent, player, state, "District", 1, { District = f.District })
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", string.upper(d.Name) .. " BOUNTY: " .. D.Text(f.District, f.Bounty) .. "  (+" .. add .. " standing"
            .. (add > 0 and (", -" .. math.floor(add * D.RIVAL_SHARE) .. " with " .. D.Defs[d.Rival].Name) or ", today's cap reached") .. ", +" .. ItemData.FormatNumber(gold) .. " gold)", d.Color)
    end
    return #done > 0
end
-- DistrictAct: Buy(district, itemId) from its shop (Districts.Shop) with that district's banked standing
CombatServer.DistrictAct = function(player: Player, action: any, id: any, itemId: any): (boolean, string?)
    local state = playerStates[player]
    if not state or action ~= "Buy" then return false, "?" end
    local D = require(game.ReplicatedStorage.AimRngShared.Districts)
    if not D.Unlocked(state) then return false, "The quarters open at level " .. D.UNLOCK .. "." end
    if type(id) ~= "string" or not D.Defs[id] then return false, "Which quarter?" end
    local s = D.Ensure(state, player.UserId)
    local it
    for _, x in ipairs(D.Shop(id)) do if x.Id == itemId then it = x end end
    if not it then return false, "That isn't sold here." end
    if D.Rank(s.Earned[id]) < it.Rank then return false, "Needs rank " .. it.Rank .. " (" .. D.RANK_NAMES[it.Rank] .. ") with " .. D.Defs[id].Name .. "." end
    if it.MinLevel and (state.Level or 1) < it.MinLevel then return false, "Needs level " .. it.MinLevel .. "." end
    if (s.Bank[id] or 0) < it.Cost then return false, "Needs " .. ItemData.FormatNumber(it.Cost) .. " standing to spend." end
    state.UnlockedTitles = state.UnlockedTitles or {}
    if it.Title and table.find(state.UnlockedTitles, it.Title) then return false, "You own that title." end
    s.Bank[id] -= it.Cost
    if it.Mats then GrantMaterials(player, state, it.Mats, nil, true) end
    if it.Sigil then
        local Rifts = require(game.ReplicatedStorage.AimRngShared.Rifts)
        require(script.Parent:WaitForChild("EndgameServer")).GiveSigil(player, state, Rifts.NewSigil(math.max(1, state.RiftBest or 1)), true)
    end
    if it.Title then table.insert(state.UnlockedTitles, it.Title) end
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    return true, "Bought: " .. it.Name .. "."
end
Remotes.GetFunction("DistrictAction").OnServerInvoke = function(player: Player, action: any, id: any, itemId: any)
    return CombatServer.DistrictAct(player, action, id, itemId)
end

function CombatServer.WeeklyEvent(player: Player, state: any, event: string, amount: number?, ctx: any?): boolean
    local Weekly = require(game.ReplicatedStorage.AimRngShared.Weekly)
    if not Weekly.ON or (state.Level or 1) < Weekly.UNLOCK_BOUNTIES then return false end
    local w = CombatServer.EnsureWeekly(player, state)
    local done = Weekly.Apply(w.Bounties, event, amount, ctx)
    if #done == 0 then return false end
    for _, c in ipairs(done) do
        local parts = CombatServer.PayWeekly(player, state, Weekly.BountyReward(state.Level))
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "BOUNTY COMPLETE: " .. Weekly.Text(c) .. "  (" .. table.concat(parts, ", ") .. ")", Color3.fromRGB(255, 196, 70))
    end
    local all = true
    for _, c in ipairs(w.Bounties) do if not c.Done then all = false end end
    if all and not w.BonusPaid then
        w.BonusPaid = true
        local parts = CombatServer.PayWeekly(player, state, Weekly.BonusReward(state.Level))
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "ALL WEEKLY BOUNTIES DONE: " .. table.concat(parts, ", ") .. "!", Color3.fromRGB(255, 196, 70))
    end
    return true
end

-- Progress for one game event; pays finished contracts at once (and the all-three bonus). The weekly bounty board takes the
-- same events (WeeklyEvent).
function CombatServer.ContractEvent(player: Player, state: any, event: string, amount: number?, ctx: any?)
    CombatServer.EnsureContracts(player, state)
    CombatServer.GT.Mark(player) -- (QOL2 R4: the goal tracker's progress goes out within a second, only if it changed)
    if event == "FloorClear" then (state :: any)._MapRefund = nil end -- (QOL2 R5: a map past its first floor is never refunded)
    local weeklyDone = CombatServer.WeeklyEvent(player, state, event, amount, ctx)
    if CombatServer.DistrictEvent(player, state, event, amount, ctx) then weeklyDone = true end -- (UPDATE 7 B5: district bounties)
    if CombatServer.SeasonGoalEvent(player, state, event, amount, ctx) then weeklyDone = true end -- (UPDATE 7 C8: season goals)
    pcall(CombatServer.ArchiveEvent, player, state, event, ctx) -- (UPDATE 7 ARCHIVE: worlds)
    local list = state.Contracts.List
    local done = Contracts.Apply(list, event, amount, ctx)
    if #done == 0 then
        if weeklyDone then Remotes.GetEvent("SyncPlayerState"):FireClient(player, state) end
        return
    end
    local SX = require(game.ReplicatedStorage.AimRngShared.Seasons).XP
    local stats = nil
    local function Stats()
        stats = stats or StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
        return stats
    end
    for _, c in ipairs(done) do
        local r = Contracts.RewardOf(c)
        CombatServer.AddSeasonXP(player, state, SX.Contract)
        state.Gold += r.Gold
        GrantMaterials(player, state, r.Mats, r.Chances, true)
        if r.Item then DropItem(player, state, Stats(), 1.5, r.Item) end
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "CONTRACT COMPLETE: " .. Contracts.Text(c) .. "  (" .. Contracts.RewardText(c) .. ")")
    end
    local all = true
    for _, c in ipairs(list) do if not c.Done then all = false end end
    if all and not state.Contracts.BonusPaid then
        state.Contracts.BonusPaid = true
        CombatServer.AddSeasonXP(player, state, SX.ContractsAll)
        GrantMaterials(player, state, Contracts.BonusMats, nil, true)
        DropGem(player, state, Stats(), 2.0, "Rare")
        DropItem(player, state, Stats(), 2.0, (math.random() < Contracts.BonusLegendaryChance) and "Mythic" or Contracts.BonusItem) -- (RARITY v4)
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "ALL DAILY CONTRACTS DONE: bonus skill gem + a Rare-or-better item!")
    end
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
end

-- ==================== RUN BOONS (BoonData) ====================
-- A run's boons live on the live state only (never saved): RunBoons = { id }, BoonOffer = { id x3 } while a
-- choice is pending. DungeonRuns / PartyRuns call these at run start, floor clear and run end.
function CombatServer.ResetRunBoons(player: Player)
    local st = playerStates[player]
    if not st then return end
    local had = (st.RunBoons and #st.RunBoons > 0) or st.BoonOffer ~= nil
    st.RunBoons = {}
    st.BoonOffer = nil
    if had then
        CombatServer.RecalculateMaxHealth(st)
        if player.Parent then Remotes.GetEvent("SyncPlayerState"):FireClient(player, st) end
    end
end
function CombatServer.OfferBoons(player: Player, isBossFloor: boolean?): boolean
    local BoonData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("BoonData"))
    if BoonData.ON == false then return false end -- (UPDATE 8 Phase 5: boons are cut -- nothing offers them any more)
    local st = CombatServer.GetState(player)
    st.RunBoons = st.RunBoons or {}
    if #st.RunBoons >= BoonData.MAX_BOONS then
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "You already carry the most boons a run allows (" .. BoonData.MAX_BOONS .. ").")
        return false
    end
    if st.BoonOffer and #st.BoonOffer > 0 then
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "Choose your current boon first (1 / 2 / 3).")
        return false
    end
    st.BoonOffer = BoonData.RollOffer(st.RunBoons, isBossFloor)
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, st)
    return true
end

-- (UPDATE 8 Phase 5, LOOT/RUN builder) KILL-COUNT JOBS with PACKS: contracts, Job Board, Season Feats and quarter bounties all count
-- "Kill" / "WeakKill" events. A pack floor has ~4x the kills of an old floor and takes ~1.5x as long, so a FODDER kill counts
-- FODDER_JOB_WEIGHT (1 in 5) -- the jobs take about the time they did. Leaders, elites, bosses count 1 as before.
CombatServer.FODDER_JOB_WEIGHT = 0.2
function CombatServer.KillJob(player: Player, state: any, event: string, fodder: boolean?, ctx: any?)
    if not fodder then CombatServer.ContractEvent(player, state, event, 1, ctx); return end
    local key = "_FodderJob" .. event
    local acc = ((state :: any)[key] or 0) + CombatServer.FODDER_JOB_WEIGHT
    if acc >= 0.999 then
        acc -= 1
        CombatServer.ContractEvent(player, state, event, 1, ctx)
    end
    ;(state :: any)[key] = acc
end

-- ==================== DUNGEON EVENT PAYOUTS (DungeonEvents; DungeonRuns calls these) ====================
local function EventStats(state: any): any
    return StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
end
function CombatServer.EventGamble(player: Player, uses: number): boolean
    local DungeonEvents = require(game.ReplicatedStorage.AimRngShared.DungeonEvents)
    local state = CombatServer.GetState(player)
    local price = DungeonEvents.GamblePrice(state.Level, uses)
    if state.Gold < price then
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "The altar wants " .. price .. " gold.")
        return false
    end
    state.Gold -= price
    DropItem(player, state, EventStats(state), 3.0, "Uncommon")
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    return true
end
function CombatServer.EventFortune(player: Player)
    local state = CombatServer.GetState(player)
    state.Health = state.MaxHealth
    ;(state :: any).FloorLuckMult = ((state :: any).FloorLuckMult or 1) * 1.5
    local gold = math.round(80 * (1 + (CombatServer.ContentLevel(player, state) - 1) * 0.05)) -- (linear, like kill gold)
    state.Gold += gold
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "FORTUNE: healed, +50% loot luck this floor, +" .. gold .. " gold")
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
end
function CombatServer.EventAmbushReward(player: Player)
    local state = CombatServer.GetState(player)
    local stats = EventStats(state)
    DropItem(player, state, stats, 2.5, "Top3")
    DropItem(player, state, stats, 2.5, "Top4")
    GrantMaterials(player, state, { Scrap = 6, Alloy = 3 }, { ReforgeToken = 0.3 })
    if math.random() < 0.25 then DropGem(player, state, stats, 2.0) end
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "CURSED CHEST CLAIMED: the guardians' treasure is yours!")
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
end
function CombatServer.EventTrialReward(player: Player, kills: number)
    local DungeonEvents = require(game.ReplicatedStorage.AimRngShared.DungeonEvents)
    local state = CombatServer.GetState(player)
    local stats = EventStats(state)
    local n = DungeonEvents.TRIAL_TARGETS
    local msg
    if kills >= n then
        GrantMaterials(player, state, { Scrap = 8, Alloy = 4 })
        DropItem(player, state, stats, 2.5, "Top3")
        DropGem(player, state, stats, 2.0)
        msg = string.format("PERFECT TRIAL %d/%d: item, gem and materials!", kills, n)
    elseif kills >= 5 then
        GrantMaterials(player, state, { Scrap = 6, Alloy = 2 })
        DropItem(player, state, stats, 2.0, "Top4")
        msg = string.format("GREAT TRIAL %d/%d: item and materials", kills, n)
    elseif kills >= 3 then
        GrantMaterials(player, state, { Scrap = 6, Alloy = 2 })
        msg = string.format("TRIAL %d/%d: materials", kills, n)
    else
        msg = string.format("TRIAL FAILED %d/%d: 3 weak-spot kills needed", kills, n)
    end
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", msg)
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
end

-- Studio test helper (DevCommands "rejoin"): save, drop the live state, load it back from the save
-- store exactly like a fresh join would.
function CombatServer.DevSimulateRejoin(player: Player): boolean
    local ok = SaveService.Save(player, playerStates[player], true)
    SaveService.Forget(player)
    playerStates[player] = nil
    SaveService.BeginLoad(player)
    local st = CombatServer.GetState(player)
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, st)
    return ok
end

-- Lightweight per-shot / per-tick update. The full state table (whole inventory, gear, skill nodes...)
-- is only sent when something big changes; this carries just the fields that change every shot.
function CombatServer.SendCombatDelta(player: Player, state: PlayerState)
    Remotes.GetEvent("CombatDelta"):FireClient(player, {
        CurrentMag = state.CurrentMag,
        IsReloading = state.IsReloading,
        Streak = state.Streak,
        Gold = state.Gold,
        UpgradeShards = state.UpgradeShards,
        Health = state.Health,
        FixStacks = (state :: any).FixStacks or 0,
    })
end

-- ===== LIVES: 3 per run, Robux revives (price climbs each time), party spectating =====
-- Player attributes (the client reads them): Lives, Revives (bought this run), Downed + DownedUntil (out of lives,
-- the revive window is open), Spectating (party: gave up, watching the others), ReviveCredits (revives paid
-- for while not in a run -- used before paying again). Config: ItemData.Lives.
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local LIVES = ItemData.Lives
local downedToken: { [Player]: any } = {}

local function SendToHub(player: Player, state: any)
    DungeonRuns.EndRun(player)
    state.Health = state.MaxHealth
    state.CurrentMag = state.MaxMag
    state.IsReloading = false
    state.Streak = 0
    ClearPlayerStatus(player)
    local char = player.Character
    if char then
        char:PivotTo(CFrame.lookAt(Vector3.new(0, 7.2, 24), Vector3.new(0, 7.2, 0)))
        local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if root then
            root.AssemblyAngularVelocity = Vector3.zero
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end
    Remotes.GetEvent("TeleportPlayer"):FireClient(player, "Hub")
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
end
CombatServer.SendToHub = SendToHub

local function InRun(player: Player): boolean
    return PartyRuns.RunOfPlayer(player) ~= nil or DungeonRuns.Get(player) ~= nil
end

-- out of play (downed / spectating): pinned in place; spectators also vanish
local function SetOutOfPlay(player: Player, anchored: boolean, hidden: boolean)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if root then
        local was = root.Anchored
        root.Anchored = anchored
        -- (RUNFIX 2026-11-07, owner: "after paying to revive you just permanently cant move") anchoring took the body off
        -- its client (an anchored part is the server's); unanchored again it stayed the SERVER's for a while -- and a solo
        -- floor only exists on the client, so the server dropped the body through the floor it can't see (the player came
        -- back stuck in / under the floor). Hand it straight back to its player, before any server physics step runs on it.
        if was and not anchored then
            pcall(function() root:SetNetworkOwner(player) end)
            task.defer(function()
                if root.Parent and not root.Anchored and player.Parent then pcall(function() root:SetNetworkOwner(player) end) end
            end)
        end
    end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") then
            if hidden then
                if d:GetAttribute("LivesOrigT") == nil then d:SetAttribute("LivesOrigT", d.Transparency) end
                d.Transparency = 1
            elseif d:GetAttribute("LivesOrigT") ~= nil then
                d.Transparency = d:GetAttribute("LivesOrigT")
                d:SetAttribute("LivesOrigT", nil)
            end
        end
    end
end

function CombatServer.StartRunLives(player: Player, partyKey: string?)
    CombatServer.RS.Begin(player, partyKey, CombatServer.GetState(player)) -- (RUN SUMMARY: a run starts here, solo or party)
    pcall(function() require(script.Parent.RunAgain).Clear(player) end) -- (QOL F1: the starter notes its run right after; trials etc. never run again)
    CombatServer.Life(CombatServer.GetState(player), "Runs") -- (lifetime stats)
    ;(CombatServer.GetState(player) :: any)._MapRefund = nil -- (QOL2 R5: a new run = the last map is over; StartRift sets it after this)
    downedToken[player] = nil
    player:SetAttribute("Lives", LIVES.PerRun)
    player:SetAttribute("Revives", 0)
    player:SetAttribute("Downed", nil)
    player:SetAttribute("DownedUntil", nil)
    player:SetAttribute("Spectating", nil)
end

function CombatServer.ClearRunLives(player: Player)
    do local stM = CombatServer.GetState(player); if stM then (stM :: any)._MapRefund = nil end end -- (QOL2 R5: a run that ENDED is never refunded)
    -- (RUN SUMMARY: every way a run ends passes here: victory, extraction, out of lives, back to the hub)
    if CombatServer.RS.Get(player) then
        local st = CombatServer.GetState(player)
        local out = (player:GetAttribute("Downed") or player:GetAttribute("Spectating")) and "DEFEATED" or nil
        local rec = CombatServer.RS.Finish(player, out, st)
        if rec and st then -- (2026-10-20 AIM PROFILE: the run's accuracy into the player's log)
            pcall(function() require(script.Parent:WaitForChild("ProfileService")).LogRun(st, rec) end)
        end
    end
    downedToken[player] = nil
    for _, a in ipairs({ "Lives", "Revives", "Downed", "DownedUntil", "Spectating" }) do player:SetAttribute(a, nil) end
    SetOutOfPlay(player, false, false)
end

-- back on your feet at the floor entrance, full health
local function RespawnInRun(player: Player, state: any)
    state.Health = state.MaxHealth
    state.CurrentMag = state.MaxMag
    state.IsReloading = false
    state.Streak = 0
    ClearPlayerStatus(player)
    SetOutOfPlay(player, false, false)
    player:SetAttribute("SafeLocked", false) -- back in the entry room: the doorway reopens (a short respawn hop didn't count)
    CombatServer.SafeRespawnAt[player] = os.clock() -- (UpdateSafeZone: don't re-lock from the pre-teleport position)
    if PartyRuns.RunOfPlayer(player) then
        PartyRuns.RespawnMember(player)
    else
        local isBoss = DungeonRuns.Attr(player, "IsBossFloor") == true
        local z = DungeonGeneratorShared.GetChamberLayout(isBoss).EntryZ
        local cf = CFrame.lookAt(Vector3.new(0, 7, z), Vector3.new(0, 7, z + 10))
        local char = player.Character
        if char then
            char:PivotTo(cf)
            local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
            if root then root.AssemblyLinearVelocity = Vector3.zero end
        end
        Remotes.GetEvent("TeleportPlayer"):FireClient(player, "PartyDungeon", cf)
    end
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
end

-- party: the run fails once every member is out (spectating); nobody still deciding on a revive
local function CheckPartyWipe(run: any)
    if not run then return end
    local all = PartyRuns.PartyMembers(run) -- (the whole party: members can be on different floors now)
    for _, p in ipairs(all) do
        if not p:GetAttribute("Spectating") then return end
    end
    for _, p in ipairs(table.clone(all)) do
        PartyRuns.RemoveMember(p)
        CombatServer.ClearRunLives(p)
        SendToHub(p, CombatServer.GetState(p))
        Remotes.GetEvent("CombatFx"):FireClient(p, "Text", "PARTY WIPED", Color3.fromRGB(255, 90, 90))
    end
end

local function GiveUp(player: Player)
    if not player:GetAttribute("Downed") then return end
    downedToken[player] = nil
    player:SetAttribute("Downed", nil)
    player:SetAttribute("DownedUntil", nil)
    local run = PartyRuns.RunOfPlayer(player)
    if run then
        player:SetAttribute("Spectating", true)
        SetOutOfPlay(player, true, true)
        CombatServer.ResolveRunLoot(player, false) -- out of lives: your run loot is lost
        CheckPartyWipe(run)
    else
        CombatServer.ClearRunLives(player)
        SendToHub(player, CombatServer.GetState(player))
    end
end

-- a revive (bought, a stored credit, or free in Studio): one life, back at the floor entrance
local function Revive(player: Player): boolean
    if not InRun(player) or not (player:GetAttribute("Downed") or player:GetAttribute("Spectating")) then return false end
    downedToken[player] = nil
    player:SetAttribute("Downed", nil)
    player:SetAttribute("DownedUntil", nil)
    player:SetAttribute("Spectating", nil)
    player:SetAttribute("Lives", 1)
    player:SetAttribute("Revives", (player:GetAttribute("Revives") or 0) + 1)
    CombatServer.RS.Note(player, nil)
    RespawnInRun(player, CombatServer.GetState(player))
    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "REVIVED", Color3.fromRGB(120, 255, 160))
    return true
end

-- a death inside a run: lose a life; at 0 the revive window opens
local function OnRunDeath(player: Player, state: any)
    local lives = math.max(0, (player:GetAttribute("Lives") or LIVES.PerRun) - 1)
    player:SetAttribute("Lives", lives)
    CombatServer.RS.Add(player, "Deaths")
    CombatServer.Life(state, "Deaths") -- (lifetime stats)
    do -- (QOL2 R1 DEATH RECAP: attr DeathRecap for the client + the run summary's DEATH line)
        local rc = CombatServer.DL.Publish(player, lives)
        local rr = CombatServer.RS.Get(player)
        if rr then rr.Killer, rr.KillHits = rc.K, rc.H end
    end
    if lives <= 0 then CombatServer.RS.Note(player, "DEFEATED") end
    if lives > 0 then
        RespawnInRun(player, state)
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", lives .. (lives == 1 and " LIFE LEFT" or " LIVES LEFT"), Color3.fromRGB(255, 120, 120))
        return
    end
    state.Health = 0 -- (DamagePlayer ignores you while at 0)
    state.Streak = 0
    ClearPlayerStatus(player)
    player:SetAttribute("Downed", true)
    player:SetAttribute("DownedUntil", workspace:GetServerTimeNow() + LIVES.DownedSeconds)
    SetOutOfPlay(player, true, false)
    -- fall over where you stood
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if root then
        local _, yaw = root.CFrame:ToOrientation()
        root.CFrame = CFrame.new(root.Position - Vector3.new(0, 2, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
    end
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    local token = {}
    downedToken[player] = token
    task.delay(LIVES.DownedSeconds + 0.5, function()
        if downedToken[player] == token and player.Parent then GiveUp(player) end
    end)
end

-- EXTRACTION portal (extract floors, boss beaten): leave the run keeping your run loot
local function Extract(player: Player)
    local state = CombatServer.GetState(player)
    local prun = PartyRuns.RunOfPlayer(player)
    local floor, diff, cleared, endless
    if prun then
        floor, diff, cleared, endless = prun.Config.FloorNumber, prun.Config.Difficulty, prun.Cleared, prun.Config.Endless
    elseif DungeonRuns.Get(player) then
        floor, diff, cleared = DungeonRuns.Attr(player, "Floor"), DungeonRuns.Attr(player, "Difficulty"), DungeonRuns.Attr(player, "FloorCleared")
        endless = DungeonRuns.Attr(player, "Endless") == true
    else
        return
    end
    local trialDone = (not prun) and DungeonRuns.Attr(player, "TrialDone") == true -- (the Boss Trial's hub portal)
    if prun and prun.Config.TrialDone and prun.Cleared then trialDone = true end -- (a party trial's hub portal: PartyRuns)
    do -- the final floor's hub portal (solo or party): a cleared last floor may always go home
        local mode = ItemData.DifficultyModes[diff or ""] and ItemData.RunMode(diff, endless)
        if cleared and type(floor) == "number" and mode and mode.MaxWaves and not mode.Endless and floor >= mode.MaxWaves then trialDone = true end
    end
    if not cleared or type(floor) ~= "number" or not (trialDone or ItemData.IsExtractFloor(diff, floor)) then return end
    if player:GetAttribute("Downed") or player:GetAttribute("Spectating") then return end
    state.RunKeep = true
    do local r = CombatServer.RS.Get(player); if r and r.Pending ~= "VICTORY" and r.Pending ~= "MAPCLEARED" then r.Pending = "EXTRACTED" end end
    if prun then PartyRuns.RemoveMember(player) end -- (resolves the loot as kept)
    CombatServer.ClearRunLives(player)
    SendToHub(player, state)
    if not trialDone then Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "EXTRACTED", Color3.fromRGB(255, 210, 90)) end
end
DungeonGeneratorShared.ServerExtractHandler = Extract

function CombatServer.InitLives()
    Remotes.GetEvent("ExtractRun").OnServerEvent:Connect(Extract)
    Remotes.GetEvent("LivesAction").OnServerEvent:Connect(function(player: Player, action: any)
        if action == "GiveUp" then
            GiveUp(player)
        elseif action == "UseCredit" then
            local state = CombatServer.GetState(player)
            if (state.ReviveCredits or 0) > 0 and Revive(player) then
                state.ReviveCredits -= 1
                player:SetAttribute("ReviveCredits", state.ReviveCredits)
            end
        elseif action == "Revive" then
            -- (LAUNCH) a free revive only in Studio. A live server with the product id still 0 refuses: before this
            -- anyone could fire "Revive" and come back free (the client already showed REVIVES COMING SOON).
            if RunService:IsStudio() then Revive(player) end
        end
    end)
    -- Robux revives: any of the revive products revives you now if you're down in a run; otherwise (it arrived
    -- late, after the window closed) it becomes a stored credit, so a purchase is never lost
    local productStep = {}
    for i, id in ipairs(LIVES.ProductIds) do if id ~= 0 then productStep[id] = i end end
    local recoverRarity = {}
    for rarity, id in pairs(ItemData.RunLoot.RecoverProductIds) do if id ~= 0 then recoverRarity[id] = rarity end end
    -- cosmetics (shop + locker): equip one you own; buy a Robux one (ProductId 0 = not on sale yet; free in Studio tests)
    local cosmeticProduct = Cosmetics.ByProduct()
    Remotes.GetFunction("CosmeticAction").OnServerInvoke = function(player: Player, action: any, cat: any, id: any)
        local state = CombatServer.GetState(player)
        if not state or type(cat) ~= "string" or type(id) ~= "string" then return false end
        local e = Cosmetics.Find(cat, id)
        if not e then return false, "Unknown item." end
        if action == "Equip" then
            return CombatServer.EquipCosmetic(player, state, cat, id)
        elseif action == "Buy" then
            -- (2026-10-14 COPIES: a tradeable piece -- or a bundle of them -- can be bought again: one more copy to trade / gift)
            local had = Cosmetics.Owns(state, e)
            if had and not (Cosmetics.Tradeable(e) or e.Cat == "Bundle") then return false, "You already own that." end
            if not Cosmetics.Buyable(e) then return false, "That one can't be bought. " .. tostring(e.How or "") end
            -- BOUND SHOP (0.97): every store item is bought with BOUND points (Cosmetics.BPPrice); points come from the
            -- Robux packs (Colorways.PACKS), Season Pass premium tiers and trades
            local price = Cosmetics.BPPrice(e)
            if not price then return false, "That one can't be bought." end
            local have = math.floor(tonumber(state.BoundPoints) or 0)
            if have < price then return false, string.format("Not enough BOUND points (%d / %d).", have, price) end
            state.BoundPoints = have - price
            player:SetAttribute("BoundPoints", state.BoundPoints)
            if e.Cat == "Bundle" then -- (pieces you already have become extra copies; the rest are granted below)
                for _, ref in ipairs(e.Contents or {}) do
                    local pc, pid = string.match(ref, "^(.-):(.*)$")
                    local ce = pc and Cosmetics.Find(pc, pid)
                    if ce and Cosmetics.Owns(state, ce) then Cosmetics.AddCopy(state, ce) end
                end
            elseif had then
                Cosmetics.AddCopy(state, e)
            end
            if not had then CombatServer.GrantCosmetic(player, state, cat, id, true) end
            Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
            return true, had and "Copy" or "Granted"
        end
        return false
    end
    -- ===== COLORWAYS + BOUND POINTS (0.93, AimRngShared.Colorways) =====
    -- ("Buy", kind, v): Colorways.PRICE BOUND points, only with the whole base set owned (its bundle, or every piece);
    -- worn on the whole set at once. ("Use", kind, v, ref?): ref = one piece of the set ("Glove:TempestGauntlets"), nil =
    -- the whole set (clears the per-piece picks). ("Points", packId): a BOUND points pack (free in Studio while ProductId 0).
    do
        local Colorways = require(game.ReplicatedStorage.AimRngShared.Colorways)
        local function SetBundle(kind: string): any
            for _, b in ipairs(Cosmetics.List("Bundle", true)) do if (b.Src and b.Src.Set or b.Set) == kind then return b end end
            return nil
        end
        function CombatServer.OwnsSetBase(state: any, kind: string): boolean
            local b = SetBundle(kind)
            if not b then return false end
            if Cosmetics.Owns(state, b) then return true end
            for _, ref in ipairs(b.Contents or {}) do
                if not table.find((b.Src and b.Src.Added) or b.Added or {}, ref) then -- (pieces added to the bundle later, e.g. its UI theme, don't count)
                    local cat, id = string.match(ref, "^(.-):(.*)$")
                    local e = cat and Cosmetics.Find(cat, id)
                    if not (e and Cosmetics.Owns(state, e)) then return false end
                end
            end
            return true
        end
        function CombatServer.GrantBoundPoints(player: Player, state: any, n: number)
            state.BoundPoints = math.max(0, math.floor(Colorways.Points(state) + (tonumber(n) or 0)))
            player:SetAttribute("BoundPoints", state.BoundPoints)
        end
        Remotes.GetFunction("ColorwayAction").OnServerInvoke = function(player: Player, action: any, kind: any, v: any, ref: any)
            local state = CombatServer.GetState(player)
            if not state then return false end
            if action == "Points" then
                local pack = type(kind) == "string" and Colorways.PackById[kind]
                if not pack then return false, "Unknown pack." end
                if (pack.ProductId or 0) ~= 0 then
                    MarketplaceService:PromptProductPurchase(player, pack.ProductId)
                    return true, "Prompted"
                elseif RunService:IsStudio() then
                    CombatServer.GrantBoundPoints(player, state, pack.Points)
                    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
                    return true, "Granted"
                end
                return false, "Coming soon."
            end
            if type(kind) ~= "string" or not Colorways.Has(kind) then return false, "That set has no colourways yet." end
            v = math.floor(tonumber(v) or 0)
            if v < 1 or v > Colorways.Count(kind) then return false end
            state.Colorways = type(state.Colorways) == "table" and state.Colorways or {}
            local rec = type(state.Colorways[kind]) == "table" and state.Colorways[kind] or {}
            rec.Own = type(rec.Own) == "table" and rec.Own or {}
            rec.Items = type(rec.Items) == "table" and rec.Items or {}
            if action == "Buy" then
                if Colorways.Owns(state, kind, v) then return false, "You already own that colourway." end
                if not CombatServer.OwnsSetBase(state, kind) then return false, "Own the whole set first (its bundle, or every piece of it)." end
                if Colorways.Points(state) < Colorways.PRICE then return false, "Not enough BOUND points." end
                state.BoundPoints = Colorways.Points(state) - Colorways.PRICE
                rec.Own[tostring(v)] = true
                rec.Set, rec.Items = v, {} -- (worn on the whole set right away)
            elseif action == "Use" then
                if not Colorways.Owns(state, kind, v) then return false, "You don't own that colourway." end
                if ref ~= nil then
                    local b = SetBundle(kind)
                    if type(ref) ~= "string" or not (b and table.find(b.Contents or {}, ref)) then return false end
                    if v == (tonumber(rec.Set) or 1) then rec.Items[ref] = nil else rec.Items[ref] = v end
                else
                    rec.Set = v > 1 and v or nil
                    rec.Items = {}
                end
            else
                return false
            end
            state.Colorways[kind] = rec
            CombatServer.SyncBarStyle(player, state)
            Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
            return true
        end
    end
    Remotes.GetEvent("BarStyleAction").OnServerEvent:Connect(function(player: Player, action: any, id: any)
        local state = CombatServer.GetState(player)
        local st = type(id) == "string" and BarStyles.ById[id]
        if not state or not st then return end
        if action == "Equip" then
            if BarStyles.Owns(state.BarStylesOwned, id) then
                state.BarStyle = id
                CombatServer.SyncBarStyle(player, state)
            end
        elseif action == "Buy" and st.Unlock == "Robux" and not BarStyles.Owns(state.BarStylesOwned, id) then
            local e = Cosmetics.Find("HealthBar", id)
            if (st.ProductId or 0) ~= 0 then
                MarketplaceService:PromptProductPurchase(player, st.ProductId)
            elseif RunService:IsStudio() and e then
                CombatServer.GrantCosmetic(player, state, "HealthBar", id, true)
            end
        end
    end)
    -- recovering lost gear: the client picks the item, then buys that rarity's product (or free while not set up)
    Remotes.GetEvent("RecoverAction").OnServerEvent:Connect(function(player: Player, action: any, index: any)
        local state = CombatServer.GetState(player)
        if type(index) ~= "number" or type(state.LostLoot) ~= "table" or not state.LostLoot[index] then return end
        if action == "Pick" then
            state.RecoverPick = index
        elseif action == "Free" then
            -- (LAUNCH) free recovery only in Studio; a live server without the rarity's product id refuses
            if RunService:IsStudio() then RecoverLost(player, state, index) end
        end
    end)
    local SeasonsP = require(game.ReplicatedStorage.AimRngShared.Seasons)
    local seasonProduct = SeasonsP.Premium.ProductId or 0
    -- REBIRTH SHARD (class change currency): a Robux product; free in Studio while its ProductId is 0
    local rebirthProduct = ItemData.RebirthShardProduct.ProductId or 0
    local function GiveRebirthShard(player: Player)
        local state = CombatServer.GetState(player)
        GrantMaterials(player, state, { RebirthShard = 1 }, nil, true) -- (its MaterialsGained toast says so)
        Remotes.GetEvent("SyncPlayerState"):FireClient(player, state) -- (the class window shows the new count)
    end
    Remotes.GetEvent("BuyRebirthShard").OnServerEvent:Connect(function(player: Player)
        if rebirthProduct ~= 0 then
            MarketplaceService:PromptProductPurchase(player, rebirthProduct)
        elseif RunService:IsStudio() then
            GiveRebirthShard(player)
        end
    end)
    -- BOUND BUYS (2026-10-20 owner: "Stashes and such should cost boundpoints, and when clicking to buy anything, it should
    -- give a popup of however many boundpoints you would need"): revives, lost-gear recovery, the Rebirth Shard and the
    -- premium season pass cost BOUND points now (the same numbers as their old Robux prices; 1 BP ~ R$1), bought behind the
    -- client's BoundShop popup. BOUND packs are the only Robux products the game prompts. The old developer products stay in
    -- the receipt handler below, so a late receipt is still granted.
    local BoundColorways = require(game.ReplicatedStorage.AimRngShared.Colorways)
    local function SpendBound(player: Player, state: any, price: number): (boolean, string?)
        price = math.max(0, math.floor(tonumber(price) or 0))
        local have = BoundColorways.Points(state)
        if have < price then return false, string.format("Not enough BOUND points (%d / %d).", have, price) end
        state.BoundPoints = have - price
        player:SetAttribute("BoundPoints", state.BoundPoints)
        return true
    end
    CombatServer.SpendBound = SpendBound
    Remotes.GetFunction("BoundBuy").OnServerInvoke = function(player: Player, what: any, arg: any)
        local state = CombatServer.GetState(player)
        if not state or not SaveService.IsReady(player) then return false, "Not loaded yet." end
        if what == "Revive" then
            if not InRun(player) or not (player:GetAttribute("Downed") or player:GetAttribute("Spectating")) then return false, "You're not down." end
            local price = LIVES.Prices[ItemData.RevivePriceStep(player:GetAttribute("Revives") or 0)] or LIVES.Prices[#LIVES.Prices]
            local ok, why = SpendBound(player, state, price)
            if not ok then return false, why end
            if not Revive(player) then CombatServer.GrantBoundPoints(player, state, price) return false, "Too late to revive." end
            Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
            return true
        elseif what == "Recover" then
            local i = math.floor(tonumber(arg) or 0)
            local e = type(state.LostLoot) == "table" and state.LostLoot[i]
            if not (e and e.Item) then return false, "That item is gone." end
            local price = ItemData.RunLoot.RecoverPrices[e.Item.Rarity or ""] or 250
            local ok, why = SpendBound(player, state, price)
            if not ok then return false, why end
            if not RecoverLost(player, state, i) then CombatServer.GrantBoundPoints(player, state, price) return false, "Couldn't recover it." end
            return true
        elseif what == "RebirthShard" then
            local ok, why = SpendBound(player, state, ItemData.RebirthShardProduct.Price or 99)
            if not ok then return false, why end
            GiveRebirthShard(player)
            return true
        elseif what == "SeasonPremium" then
            local Seasons = require(game.ReplicatedStorage.AimRngShared.Seasons)
            local s = Seasons.Ensure(state)
            if s.Premium then return false, "You already have the premium pass." end
            if not Seasons.Active() then return false, "This season is over." end
            local ok, why = SpendBound(player, state, Seasons.Premium.Price or 499)
            if not ok then return false, why end
            CombatServer.GrantSeasonPremium(player, state)
            return true
        end
        return false, "Unknown purchase."
    end
    local hideoutProduct = (function() -- (0.55: Robux hideout furniture also needs the receipt handler)
        local okH, HD = pcall(require, game.ReplicatedStorage.AimRngShared.HideoutData)
        if okH then for _, d in pairs(HD.Items) do if (d.ProductId or 0) ~= 0 then return true end end end
        return false
    end)()
    local bpProduct = false
    for _, pack in ipairs(require(game.ReplicatedStorage.AimRngShared.Colorways).PACKS) do if (pack.ProductId or 0) ~= 0 then bpProduct = true end end
    if next(productStep) or next(recoverRarity) or next(cosmeticProduct) or seasonProduct ~= 0 or rebirthProduct ~= 0 or hideoutProduct or bpProduct or next(Cosmetics.RETIRED_PRODUCTS or {}) then
        local function HandleReceipt(receipt, player)
            if rebirthProduct ~= 0 and receipt.ProductId == rebirthProduct then
                if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
                GiveRebirthShard(player)
                return Enum.ProductPurchaseDecision.PurchaseGranted
            end
            for _, pack in ipairs(require(game.ReplicatedStorage.AimRngShared.Colorways).PACKS) do -- (0.93 BOUND points)
                if (pack.ProductId or 0) ~= 0 and receipt.ProductId == pack.ProductId then
                    if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
                    local st = CombatServer.GetState(player)
                    CombatServer.GrantBoundPoints(player, st, pack.Points)
                    Remotes.GetEvent("SyncPlayerState"):FireClient(player, st)
                    return Enum.ProductPurchaseDecision.PurchaseGranted
                end
            end
            if seasonProduct ~= 0 and receipt.ProductId == seasonProduct then
                if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
                CombatServer.GrantSeasonPremium(player, CombatServer.GetState(player))
                return Enum.ProductPurchaseDecision.PurchaseGranted
            end
            local refund = Cosmetics.RETIRED_PRODUCTS and Cosmetics.RETIRED_PRODUCTS[receipt.ProductId]
            if refund then -- (Update 5 SKINS V3: an old skin product bought late -> its price back in BOUND points)
                if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
                local st = CombatServer.GetState(player)
                if not st then return Enum.ProductPurchaseDecision.NotProcessedYet end
                CombatServer.GrantBoundPoints(player, st, refund)
                Remotes.GetEvent("SyncPlayerState"):FireClient(player, st)
                return Enum.ProductPurchaseDecision.PurchaseGranted
            end
            local ce = cosmeticProduct[receipt.ProductId]
            if ce then
                if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
                CombatServer.GrantCosmetic(player, CombatServer.GetState(player), ce.Cat, ce.Id, true)
                return Enum.ProductPurchaseDecision.PurchaseGranted
            end
            if recoverRarity[receipt.ProductId] then
                if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
                local state = CombatServer.GetState(player)
                if not RecoverLost(player, state, state.RecoverPick or 1, recoverRarity[receipt.ProductId]) then
                    return Enum.ProductPurchaseDecision.NotProcessedYet -- nothing of that rarity to recover (retried later)
                end
                return Enum.ProductPurchaseDecision.PurchaseGranted
            end
            if CombatServer.ExtraReceipt then -- (0.55: hideout furniture for Robux, Hideouts.Receipt)
                local dec = CombatServer.ExtraReceipt(receipt, player)
                if dec then return dec end
            end
            if not productStep[receipt.ProductId] then return Enum.ProductPurchaseDecision.NotProcessedYet end
            if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
            if not Revive(player) then
                local state = CombatServer.GetState(player)
                state.ReviveCredits = (state.ReviveCredits or 0) + 1
                player:SetAttribute("ReviveCredits", state.ReviveCredits)
            end
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
        -- (live-save check 2026-10-13) Robux purchases must never be lost or granted twice:
        --   * only a player whose save LOADED can be granted (a failed load = a never-saved starter state: the purchase
        --     would vanish) -> NotProcessedYet, Roblox re-sends the receipt on their next join;
        --   * every granted PurchaseId is recorded in the save; a receipt Roblox re-sends (it may, e.g. after a server
        --     crash) is acknowledged without granting again;
        --   * the save is written BEFORE Roblox is told "granted"; if that save fails, NotProcessedYet -- the retry finds
        --     the PurchaseId (kept in memory, saved by the next autosave) and is acknowledged without a second grant.
        local RECEIPTS_KEEP = 200
        MarketplaceService.ProcessReceipt = function(receipt)
            local player = Players:GetPlayerByUserId(receipt.PlayerId)
            if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
            local st = CombatServer.GetState(player)
            if not SaveService.IsReady(player) or not st then return Enum.ProductPurchaseDecision.NotProcessedYet end
            st.Receipts = type(st.Receipts) == "table" and st.Receipts or {}
            local rid = tostring(receipt.PurchaseId)
            if st.Receipts[rid] then return Enum.ProductPurchaseDecision.PurchaseGranted end
            local ok, dec = pcall(HandleReceipt, receipt, player)
            if not ok then
                warn("[Receipts] " .. tostring(dec))
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end
            if dec ~= Enum.ProductPurchaseDecision.PurchaseGranted then return dec end
            st.Receipts[rid] = os.time()
            local n = 0
            for _ in pairs(st.Receipts) do n += 1 end
            if n > RECEIPTS_KEEP then
                local list = {}
                for k, t in pairs(st.Receipts) do table.insert(list, { k, tonumber(t) or 0 }) end
                table.sort(list, function(a, b) return a[2] < b[2] end)
                for i = 1, n - RECEIPTS_KEEP do st.Receipts[list[i][1]] = nil end
            end
            if not SaveService.Save(player, st, false) then return Enum.ProductPurchaseDecision.NotProcessedYet end
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
    end
    Players.PlayerRemoving:Connect(function(p) downedToken[p] = nil end)
end

local function KillPlayer(player: Player, state: any)
    if player:GetAttribute("DevNoDeath") then state.Health = 1; return end -- Studio play-test switch (DevCommands "nodeath")
    -- Undying (Mythic gem): once every 90s a killing blow leaves you at 40% health instead.
    local kstats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
    if Asc.CheatDeath(player, state, kstats) then -- ascendancy (Vanish / Last Bulwark / Undying Will)
        CombatServer.SendCombatDelta(player, state)
        return
    end
    if kstats.SpecialMechanics["UNDYING"] and os.clock() - (state.UndyingAt or -1e9) >= 90 then
        state.UndyingAt = os.clock()
        player:SetAttribute("UndyingReadyAt", workspace:GetServerTimeNow() + 90)
        state.Health = math.round(state.MaxHealth * 0.4)
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "UNDYING", Color3.fromRGB(255, 235, 140))
        CombatServer.SendCombatDelta(player, state)
        return
    end
    if player:GetAttribute("Downed") or player:GetAttribute("Spectating") then return end
    -- in a dungeon (solo or party): lives (see the LIVES block above)
    if InRun(player) then
        OnRunDeath(player, state)
        return
    end
    SendToHub(player, state)
end

-- element: "Physical" (default; armor), "Fire" / "Cold" / "Chaos" (resistances, lowered on harder
-- difficulties). ailment: "Burn" | "Chill" | "Decay" | "Bleed" | nil, applied with ailmentChance (default 1).
-- ===== dungeon SAFE ZONE: the entry room (Z 450..CorridorAStart) =====
-- You can't be hurt there until you walk out; once out, the doorway locks behind you (Player attribute
-- SafeLocked -> the client puts up a barrier) until you're next placed in an entry room (new floor, coming from
-- the hub, respawning: any jump of 40+ studs that lands there). Attribute SafeZone = protected right now.
local SAFE_Z = DungeonGeneratorShared.GetChamberLayout(false).CorridorAStart
local safeLast: { [Player]: Vector3 } = {}
function CombatServer.InSafeZone(player: Player): boolean
    -- RESPAWN PROTECTION (owner 2026-10-05: "If you respawn in the saferoom while the boss is attacking, you still take
    -- damage in there"): the server can still see your pre-respawn arena position for a moment (the client moves its own
    -- character), so anything landing in that window counted. 2.5 s after a respawn you're safe wherever you stand.
    if os.clock() - (CombatServer.SafeRespawnAt[player] or -99) < 2.5 then return true end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local z = root.Position.Z
    return z > 450 and z < SAFE_Z and not player:GetAttribute("SafeLocked")
end
-- the entry room by POSITION only (no respawn grace): attacking is locked only while you're actually in the room
-- (owner 2026-10-07: "after respawning, when you walk out of spawn, you cant shoot for a second" -- the 2.5 s damage
-- grace above also blocked shooting)
function CombatServer.InSafeRoom(player: Player): boolean
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local z = root.Position.Z
    return z > 450 and z < SAFE_Z and not player:GetAttribute("SafeLocked")
end
local function UpdateSafeZone(player: Player)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local pos = root.Position
    local last = safeLast[player]
    safeLast[player] = pos
    local inEntry = pos.Z > 450 and pos.Z < SAFE_Z
    -- (owner 2026-10-03: "bosses still target you in spawn ... only after you respawn") dying near the doorway: the
    -- respawn hop is under 40 studs, and a check that still saw the pre-teleport arena position re-locked the room, so
    -- the boss kept hunting you at spawn. For 2 s after a respawn, stale arena positions never lock and the room unlocks.
    local justRespawned = os.clock() - (CombatServer.SafeRespawnAt[player] or -99) < 2
    if inEntry and (not last or (last - pos).Magnitude > 40 or justRespawned) then
        player:SetAttribute("SafeLocked", false) -- just placed in an entry room
    elseif pos.Z >= SAFE_Z + 4 and pos.Z < 3000 and not justRespawned then
        player:SetAttribute("SafeLocked", true) -- walked out (or in the arena)
    elseif pos.Z < 450 then
        player:SetAttribute("SafeLocked", false) -- back in the hub
    end
    player:SetAttribute("SafeZone", CombatServer.InSafeRoom(player))
end
Players.PlayerRemoving:Connect(function(p) safeLast[p] = nil; CombatServer.SafeRespawnAt[p] = nil end)

-- from = where the hit came from (the client's hit arc; nil = no direction)
CombatServer.ONE_HIT_CAP = 0.7
-- ===== (UPDATE 8 DEFENCE) typed hits on you: Agility -> Plating / resist -> Ward -> life (StatCalculator DEFENCE block) =====
-- (fields, not locals: this chunk is at Luau's 200-local limit)
-- player ailments from typed hits, kept light: Shock (Volt) = you take PLAYER_SHOCK more for 2.5 s; Wither (Void) = stacks of
-- PLAYER_WITHER more (at most PLAYER_WITHER_MAX, 4 s from the last); Burn / Bleed = damage over time; Chill = slower.
-- Your resistance weakens each. No Freeze on you (losing control is unfair in an aim game), Bleed is not worse while moving
-- (moving is how you dodge).
CombatServer.PLAYER_SHOCK = 0.15
CombatServer.PLAYER_WITHER, CombatServer.PLAYER_WITHER_MAX = 0.05, 3
CombatServer.DEF_AIL = { Decay = "Wither", Freeze = "Chill" } -- (old ailment ids from ElementDefs)
-- (UPDATE 8 MAPS) extra typed damage map mods: type -> { mod id, share of the hit }
CombatServer.MAP_EXTRA = { Heat = { "EXTRA_HEAT", 0.25 }, Cryo = { "EXTRA_CRYO", 0.25 }, Volt = { "EXTRA_VOLT", 0.25 }, Void = { "EXTRA_VOID", 0.2 } }
-- the hit's size vs an ORDINARY hit on this floor (a plain bot's swing; DungeonGenerator.OrdinaryHit) -> Plating's per-hit
-- cut. Outside a run (no floor) every hit counts as ordinary.
function CombatServer.DefHitSize(player: Player, raw: number): number
    local prun = PartyRuns.RunOfPlayer(player)
    local cfg = (prun and prun.Config) or (DungeonRuns.ConfigOf and DungeonRuns.ConfigOf(player)) or nil
    if not cfg then return 1 end
    local ok, ord = pcall(DungeonGeneratorShared.OrdinaryHit, cfg)
    if not ok or type(ord) ~= "number" or ord <= 0 then return 1 end
    return raw / ord
end
-- Ward pool -> Player attributes Ward / WardMax (the HUD bar); nil attrs = no Ward
function CombatServer.WardSync(player: Player, state: any)
    local max = state._WardMax or 0
    local w = (max > 0) and math.round(math.clamp(state.WardPool or max, 0, max)) or nil
    local m = (max > 0) and math.round(max) or nil
    if player:GetAttribute("Ward") ~= w then player:SetAttribute("Ward", w) end
    if player:GetAttribute("WardMax") ~= m then player:SetAttribute("WardMax", m) end
end
-- (UPDATE 8 MAPS) the map / floor mods a player is fighting under (solo run folder, else a party run's config)
function CombatServer.MapMods(player: Player): any
    local m = DungeonRuns.Attr(player, "Mods")
    if m and m ~= "" then return m end
    local prun = PartyRuns.RunOfPlayer(player)
    return prun and prun.Config and prun.Config.Mods or nil
end
-- (MAPS V2 2026-10-30) a floor mod's value for this player's floor: x the map's ModScale (run folder attr), today's number elsewhere
function CombatServer.ModV(player: Player, id: string): number
    local sc = DungeonRuns.Attr(player, "ModScale")
    return FloorMods.V(id, type(sc) == "number" and sc or nil)
end
-- (relic Wardstep, stat MovingWard) while you move, damage doesn't restart the Ward's recharge delay
function CombatServer.WardHitNow(player: Player, state: any)
    if (state._MovingWard or 0) > 0 then
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then
            local v = root.AssemblyLinearVelocity
            if Vector3.new(v.X, 0, v.Z).Magnitude >= 1.5 then return end
        end
    end
    state._WardHitAt = os.clock()
end
-- damage over time hits Ward first too (returns what reaches life); any damage restarts the recharge delay
function CombatServer.WardAbsorb(player: Player, state: any, d: number): number
    CombatServer.WardHitNow(player, state)
    local max = state._WardMax or 0
    if max <= 0 or d <= 0 then return d end
    local pool = math.min(max, state.WardPool or max)
    local take = math.min(pool, d)
    state.WardPool = pool - take
    CombatServer.WardSync(player, state)
    return d - take
end
-- Ward recharge: WardDelay s (2 s base) after the last damage, WardRate of max a second (25% base)
task.spawn(function()
    while true do
        task.wait(0.25)
        local now = os.clock()
        for player, state in pairs(playerStates) do
            local sa = state :: any
            local max = sa._WardMax or 0
            if max > 0 and player.Parent then
                local pool = math.min(max, sa.WardPool or max)
                if pool < max and now - (sa._WardHitAt or 0) >= (sa._WardDelay or 2) and (state.Health or 0) > 0 then
                    local slow = FloorMods.Has(CombatServer.MapMods(player), "SLOW_WARD") and (1 - CombatServer.ModV(player, "SLOW_WARD")) or 1 -- (UPDATE 8 map mod Dampened; MAPS V2 scaled)
                    pool = math.min(max, pool + max * (sa._WardRate or 0.25) * 0.25 * slow)
                end
                sa.WardPool = pool
            end
            if player.Parent then CombatServer.WardSync(player, sa) end
        end
    end
end)
-- opts (UPDATE 8 DEFENCE): { Evadable = true } = an ordinary hit Agility can dodge (a plain bot's strike, or a boss's PLAIN hit
-- -- BossAI's allow-list; never a mechanic, an area / big boss move, a hazard or damage over time); Boss = true: it came from a
-- boss (the chance x BOSS_EVADE, no Ghost forced miss). element = a damage type (Kinetic / Heat / Cryo / Volt / Void) or an old name
-- (Physical / Fire / Cold / Chaos / Shock ...); ailment = Burn / Chill / Bleed / Shock / Wither (old Decay = Wither).
-- src (QOL2 R1 DEATH RECAP): who / what landed it -- a STRING (an enemy's DungeonGenerator.SourceName, "Hazard" ...), kept in DeathLog.
-- (ENEMY ATTACKS POE DAMAGE MODEL, review 2) a hit this big vs the floor's ordinary hit (CombatServer.DefHitSize) counts as HEAVY:
-- it spoils a no-hit floor and breaks Focus; chip below it doesn't (the Ward delay restarts on any damage)
CombatServer.HEAVY_HIT_REL = 0.5
function CombatServer.DamagePlayer(player: Player, rawDamage: number, element: string?, ailment: string?, ailmentChance: number?, from: Vector3?, opts: any?, src: string?)
    local state = CombatServer.GetState(player)
    if state.Health <= 0 then return end
    if CombatServer.InSafeZone(player) then return end -- dungeon entry room: no damage until you walk out
    if player:GetAttribute("Downed") or player:GetAttribute("Spectating") then return end -- out of lives
    local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
    local el = element or "Physical"
    local diff = CurrentDifficulty(player, state)
    rawDamage /= PartyScale(player) -- (party floors: the enemy hits as hard as it would at YOUR level)
    if stats.Zenith then rawDamage *= CombatServer.Zen.TakenMult(state, stats) end -- (CHASE ITEMS: Lattice +15% while firing)

    -- (UPDATE 8 MAPS) map mods on your defences: Exposed (-10% max resists), Sluggish (Agility dodges half as often)
    local mapMods = CombatServer.MapMods(player)
    if mapMods then
        if FloorMods.Has(mapMods, "MAX_RES_DOWN") then
            for _, t in ipairs({ "Heat", "Cryo", "Volt", "Void" }) do
                stats["Max" .. t .. "Resist"] = (stats["Max" .. t .. "Resist"] or stats.MaxResist or 0.75) - CombatServer.ModV(player, "MAX_RES_DOWN") -- (MAPS V2: 0.1 at x1)
            end
        end
        if FloorMods.Has(mapMods, "LOW_AGILITY") then stats.EvadeChance = (stats.EvadeChance or 0) * (1 - CombatServer.ModV(player, "LOW_AGILITY")) end -- (MAPS V2: x0.5 at x1)
    end
    stats.EvadeChance = CombatServer.CB.Family.Evade(player, state, stats) -- (CLASS BUILDS) FAMILY: the sidearm's Agility on the move
    -- (UPDATE 8 DEFENCE) AGILITY: an ordinary hit can miss you entirely (boss hits / mechanics / hazards never do)
    if CombatServer.CB.Sig.GhostMiss(player, state, stats, opts) then return end -- (CLASS BUILDS) SIGNATURE: Ghost
    local evadeChance = (stats.EvadeChance or 0) * ((type(opts) == "table" and opts.Boss) and (StatCalculator.BOSS_EVADE or 1) or 1) -- (AGILITY vs BOSSES: a boss's plain hit)
    if type(opts) == "table" and opts.Evadable and evadeChance > 0 and math.random() < evadeChance then
        CombatServer.CB.Sig.OnEvade(player, stats) -- (CLASS BUILDS) SIGNATURE: Ghost arms
        Remotes.GetEvent("PlayerDamaged"):FireClient(player, 0, state.Health, state.MaxHealth, "Evade", from)
        CombatServer.CB.Family.OnEvade(player, state) -- (CLASS BUILDS) FAMILY: the sidearm's dodge bonus
        return
    end
    -- PLATING (Kinetic: vs this hit's size on this floor -- big hits are cut less) / RESISTANCE (Heat / Cryo / Volt / Void,
    -- minus the difficulty's penalty), see StatCalculator.MitigateHit
    -- (ENEMY ATTACKS PILOT, review B) a burst's round is judged as the whole burst (opts.HitScale = total / this round)
    local hitRel = CombatServer.DefHitSize(player, rawDamage * ((type(opts) == "table" and type(opts.HitScale) == "number") and opts.HitScale or 1))
    local mitigated, res, dtype = StatCalculator.MitigateHit(stats, rawDamage, el, diff, hitRel)
    el = dtype
    -- (UPDATE 8 MAPS) Searing / Frostbitten / Overcharged / Hollow: extra typed damage on every enemy hit, mitigated as its
    -- own type; the Void part (Hollow) goes past Ward (added after the Ward step)
    local voidExtra = 0
    if mapMods then
        for t, e in pairs(CombatServer.MAP_EXTRA) do
            if FloorMods.Has(mapMods, e[1]) then
                local share = CombatServer.ModV(player, e[1]) -- (MAPS V2: e[2] at x1)
                local part = StatCalculator.MitigateHit(stats, rawDamage * ((share > 0) and share or e[2]), t, diff, hitRel)
                if t == "Void" and (stats.WardVsVoid or 0) <= 0 then voidExtra += part else mitigated += part end
            end
        end
    end
    local ps = playerStatus[player]
    if ps then -- Wither (Void) + Shock (Volt) on you: increased damage taken
        local tnow, inc = os.clock(), 0
        if tnow < ps.DecayUntil then inc += ps.DecayInc end
        if tnow < (ps.ShockUntil or 0) then inc += ps.ShockInc or 0 end
        if inc > 0 then mitigated *= (1 + inc); voidExtra *= (1 + inc) end
    end
    -- Passive tree: standing still (Dug In / Entrenched) and low health (Last Stand) reduce damage taken.
    local cond = stats.Cond or {}
    local extraDR = 0
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        local v = root.AssemblyLinearVelocity
        if Vector3.new(v.X, 0, v.Z).Magnitude < 1.5 then
            extraDR += (cond.StillDR or 0) + (stats.SpecialMechanics["ENTRENCHED"] and 0.10 or 0)
        end
    end
    if state.Health < state.MaxHealth * 0.5 then extraDR += (cond.LowLifeDR or 0) end
    if stats.SpecialMechanics["GLACIAL_WARD"] and os.clock() < ((state :: any)._WardUntil or 0) then
        extraDR += 0.03 * ((state :: any)._WardStacks or 0) -- Glacial Ward: 3% per recent chill
    end
    do -- EXOTIC Bastion Shell (0.53): each hit taken hardens it (-10% per stack, 3 stacks, 4 s) for the NEXT hits
        local chest = state.EquippedGear and state.EquippedGear.ChestPiece
        if chest and chest.Exotic == "BastionShell" then
            local sa, tnow = state :: any, os.clock()
            if tnow < (sa.ExoShellUntil or 0) then extraDR += 0.1 * (sa.ExoShell or 0) end
            sa.ExoShell = (tnow < (sa.ExoShellUntil or 0)) and math.min(3, (sa.ExoShell or 0) + 1) or 1
            sa.ExoShellUntil = tnow + 4
        end
    end
    if extraDR > 0 then mitigated *= (1 - math.min(0.5, extraDR)) end
    if stats.SpecialMechanics["P_STABLE_CORE"] then (state :: any).P_CoreOff = os.clock() + 3 end -- (class passive Stable Core)
    do -- far passives: Untouched Aim (a HEAVY hit switches it off), Battering Ram (stacks cut damage, a hit costs one),
        -- Entrenched Gunner (standing still 1.5 s)
        local sa, tnow = state :: any, os.clock()
        -- (ENEMY ATTACKS POE DAMAGE MODEL, review 2) the same server-side size test as Focus / Untouchable (HEAVY_HIT_REL): chip lands
        -- ~30 times a minute and would keep Untouched Aim off for good
        if hitRel >= CombatServer.HEAVY_HIT_REL then sa.P_HurtAt = tnow end
        local sm = stats.SpecialMechanics
        if sm["P_BATTERING_RAM"] and tnow < (sa.P_RamUntil or 0) and (sa.P_Ram or 0) > 0 then
            mitigated *= 1 - 0.1 * sa.P_Ram
            sa.P_Ram -= 1
        end
        if sm["P_HOLD_LINE"] then
            local still = true
            if root and root:IsA("BasePart") then
                local v = root.AssemblyLinearVelocity
                still = Vector3.new(v.X, 0, v.Z).Magnitude < 1.5
            end
            if not still then sa.P_StillSince = nil
            else
                sa.P_StillSince = sa.P_StillSince or tnow
                if tnow - sa.P_StillSince >= 1.5 then mitigated *= 0.7 end
            end
        end
    end
    do -- ascendancy Guard / TakenLess (tree v4)
        local mv = false
        if root and root:IsA("BasePart") then
            local v = root.AssemblyLinearVelocity
            mv = Vector3.new(v.X, 0, v.Z).Magnitude >= 1.5
        end
        mitigated *= Asc.GuardMult(player, state, stats, mv, from)
        mitigated *= CombatServer.CB.Sig.TakenLess(player, stats, from) -- (CLASS BUILDS) SIGNATURE: Arm's Length
    end
    if FloorMods.Has(DungeonRuns.Attr(player, "Mods"), "GLASS_ARENA") then mitigated *= 1 + CombatServer.ModV(player, "GLASS_ARENA") end -- (MAPS V2 scaled)
    if FloorMods.Has(DungeonRuns.Attr(player, "Mods"), "BRUTAL") then mitigated *= 1 + CombatServer.ModV(player, "BRUTAL") end -- (0.62 map mod; MAPS V2 scaled)
    -- (the HEALTH GATE -- a killing blow above 25% health left you on 1% -- was removed 2026-10-05: owner, "with the
    -- bosses being more telegraphed, we can remove the healthgate")
    -- NO ONE-SHOTS (owner 2026-10-05: "a lot of them just insta kill you"): one hit takes at most 70% of your max health --
    -- every big attack is telegraphed, so getting caught by one hurts badly but never ends you from full; two do.
    -- (UPDATE 8 DEFENCE) WARD: a pool in front of life (Void skips it); any damage restarts its recharge delay. The 70% cap
    -- holds for the whole hit (of life + Ward) and again for the part that reaches life.
    local wardHit = 0
    do
        local sa = state :: any
        local wmax = stats.Ward or 0
        sa._WardMax, sa._WardRate, sa._WardDelay = wmax, stats.WardRate, stats.WardDelay
        sa._MovingWard = stats.MovingWard or 0
        CombatServer.WardHitNow(player, sa) -- (relic Wardstep: no restart while moving)
        mitigated = math.min(mitigated, (state.MaxHealth + wmax) * CombatServer.ONE_HIT_CAP)
        if wmax > 0 and (el ~= "Void" or (stats.WardVsVoid or 0) > 0) then -- (GEAR v3 build line WardVsVoid: Void hits Ward too)
            local pool = math.min(wmax, sa.WardPool or wmax)
            wardHit = math.min(pool, mitigated)
            sa.WardPool = pool - wardHit
            mitigated -= wardHit
        end
        CombatServer.WardSync(player, sa)
    end
    mitigated += voidExtra -- (UPDATE 8 map mod Hollow: its Void part skips Ward)
    mitigated = math.min(mitigated, state.MaxHealth * CombatServer.ONE_HIT_CAP)
    local finalDmg = (mitigated >= 0.5 or wardHit <= 0) and math.max(1, math.round(mitigated)) or 0

    state.Health = math.max(0, state.Health - finalDmg)
    CombatServer.DL.Add(player, src, finalDmg + wardHit, el) -- (QOL2 R1 DEATH RECAP)
    CombatServer.RS.Add(player, "Taken", finalDmg)
    -- (ENEMY ATTACKS POE DAMAGE MODEL, review 2) only a HEAVY hit -- judged HERE by its size vs the floor's ordinary hit
    -- (hitRel; the client's own chip / spike word is never used) -- spoils a no-hit floor (FloorHitTaken: records, Untouchable,
    -- NoHit contracts / goals) and breaks your Focus. Chip (a volley round, a jab, ground / pool ticks) is ~0.1-0.45 x an ordinary
    -- hit and arrives ~30 times a minute: counting it made every no-hit goal impossible. Ward still restarts on ANY damage (above).
    local heavy = hitRel >= CombatServer.HEAVY_HIT_REL
    if heavy then
        (state :: any).FloorHitTaken = true
        DungeonRuns.OnPlayerHit(player) -- (floor objective: Untouchable)
    end
    ;(state :: any).HurtAt = os.clock() -- (Flawless boss kills: no damage since the fight started)
    -- Getting hit breaks your Focus (Unbroken keeps part of it, Eternal Focus all of it).
    if heavy and not stats.SpecialMechanics["ETERNAL_FOCUS"] then
        state.Streak = math.floor((state.Streak or 0) * math.clamp(cond.FocusRetain or 0, 0, 1))
    end

    if state.Health > 0 then Asc.Trigger(state, stats, "Hurt") end
    ailment = ailment and (CombatServer.DEF_AIL[ailment] or ailment) -- (UPDATE 8 DEFENCE: Decay -> Wither)
    if ailment == "Chill" and Asc.Has(stats, "Immune", "Chill") then ailment = nil end
    -- Elemental ailment on you (resistance also weakens the effect; DoTs scale with the whole hit, Ward part included).
    if ailment and math.random() < (ailmentChance or 1) then
        local st = GetPlayerStatus(player)
        local now = os.clock()
        local eff = 1 - math.max(0, res)
        local hitDmg = finalDmg + wardHit
        if ailment == "Burn" then
            table.insert(st.DotList, { Kind = "Burn", Dps = hitDmg * 0.4 / 3, Until = now + 3 })
        elseif ailment == "Bleed" then
            table.insert(st.DotList, { Kind = "Bleed", Dps = hitDmg * 0.4 / 4, Until = now + 4 })
        elseif ailment == "Chill" then
            if now >= st.ChillUntil then st.ChillSlow = 0 end
            st.ChillSlow = math.max(st.ChillSlow, 0.30 * eff)
            st.ChillUntil = now + 2.2
        elseif ailment == "Shock" then -- (UPDATE 8 DEFENCE: Volt) take more damage for a moment
            if now >= (st.ShockUntil or 0) then st.ShockInc = 0 end
            st.ShockInc = math.max(st.ShockInc or 0, CombatServer.PLAYER_SHOCK * eff)
            st.ShockUntil = now + 2.5
        elseif ailment == "Wither" then -- (UPDATE 8 DEFENCE: Void, was Decay) stacks of more damage taken
            if now >= st.DecayUntil then st.WitherN = 0 end
            st.WitherN = math.min(CombatServer.PLAYER_WITHER_MAX, (st.WitherN or 0) + 1)
            st.DecayInc = math.max(now < st.DecayUntil and st.DecayInc or 0, CombatServer.PLAYER_WITHER * st.WitherN * eff)
            st.DecayUntil = now + 4
        end
        while #st.DotList > 6 do table.remove(st.DotList, 1) end
    end

    Remotes.GetEvent("PlayerDamaged"):FireClient(player, finalDmg, state.Health, state.MaxHealth, el, from, wardHit > 0 and math.round(wardHit) or nil)
    CombatServer.SendCombatDelta(player, state)

    if state.Health <= 0 then
        KillPlayer(player, state)
    end
end

-- Player ailment tick: DoT damage (doesn't break your Focus streak), chill slow and status flags.
task.spawn(function()
    while true do
        task.wait(0.5)
        local now = os.clock()
        for player, st in pairs(playerStatus) do
            if not player.Parent then playerStatus[player] = nil; continue end
            local state = CombatServer.GetState(player)
            local dot = 0
            local burning, bleeding = false, false
            for i = #st.DotList, 1, -1 do
                local e = st.DotList[i]
                if e.Until <= now then
                    table.remove(st.DotList, i)
                else
                    dot += e.Dps * 0.5
                    if e.Kind == "Burn" then burning = true else bleeding = true end
                end
            end
            local chillMult = (now < st.ChillUntil) and math.round((1 - st.ChillSlow) * 100) / 100 or 1
            if player:GetAttribute("ChillMult") ~= chillMult then player:SetAttribute("ChillMult", chillMult) end
            local flags = { Burning = burning, Bleeding = bleeding, Chilled = chillMult < 1, Withered = now < st.DecayUntil, Shocked = now < (st.ShockUntil or 0) } -- (UPDATE 8: Decayed -> Withered, + Shocked)
            local wn = (now < st.DecayUntil) and (st.WitherN or 1) or nil
            if player:GetAttribute("WitherStacks") ~= wn then player:SetAttribute("WitherStacks", wn) end
            for k, v in pairs(flags) do
                if player:GetAttribute(k) ~= v then player:SetAttribute(k, v) end
            end
            if dot > 0 and state.Health > 0 then
                local d = math.max(0.1, math.round(dot * 10) / 10)
                CombatServer.DL.Add(player, burning and "Burn" or "Bleed", d, burning and "Burn" or "Bleed") -- (QOL2 R1 DEATH RECAP: ticks merge into one line)
                d = CombatServer.WardAbsorb(player, state, d) -- (UPDATE 8 DEFENCE: damage over time hits Ward first too)
                state.Health = math.max(0, math.round((state.Health - d) * 10) / 10)
                Remotes.GetEvent("PlayerDamaged"):FireClient(player, d, state.Health, state.MaxHealth, burning and "Burn" or "Bleed")
                CombatServer.SendCombatDelta(player, state)
                if state.Health <= 0 then KillPlayer(player, state) end
            end
            if #st.DotList == 0 and now >= st.ChillUntil and now >= st.DecayUntil and now >= (st.ShockUntil or 0) then
                ClearPlayerStatus(player)
            end
        end
    end
end)

-- TARGET LOOT (pity, ItemData.Pity): every chest fills the player's meters for their two picks; the meter's value is
-- the chance this chest also drops that pick (1 = sure). Daily rare first, then infinite. Call while _DropAt is set.
function CombatServer.PityChest(player: Player, state: any, units: number)
    local p = ItemData.PityState(state)
    state.Pity = p
    if not p.W and not p.G then return end
    local tier = ItemData.ParseRunKey(state.DungeonDifficulty)
    if not tier then return end
    local gain = ItemData.PityGain(state.Level, state.DungeonDifficulty) * units
    if gain <= 0 then return end
    local P = ItemData.Pity
    local luck = 1 -- (no character luck, no boss bonus; 0.99n RARITY LADDER v3: the difficulty's nudge is in the ladder itself --
    -- DifficultyLootMult here would count it twice)
    local maxRank = tier -- (RARITY v4: the difficulty key = its cap + its area)
    for _, k in ipairs({ "W", "G" }) do
        if p[k] then
            local daily = not p["C" .. k]
            local mk = (daily and "D" or "I") .. k
            p[mk] = math.min(1, p[mk] + gain * (daily and P.DAILY_RATE or P.INF_RATE))
            if math.random() < p[mk] then
                p[mk] = 0
                if daily then p["C" .. k] = true end
                local rarity = daily and ItemData.RollUpperHalfRarity(luck, maxRank) or ItemData.RollRarity(luck, maxRank)
                local lvl = math.clamp(state.Level or 1, 1, ItemData.MAX_LEVEL)
                local item, kind
                if k == "W" then
                    item, kind = ItemData.GenerateWeaponOfBase(p.W, rarity, lvl), "Weapon"
                    if item then state.StatsTracking.DiscoveredWeapons[item.BaseId] = true end
                else
                    item, kind = ItemData.GenerateRandomGear(p.G, rarity, luck, lvl, maxRank), "Gear"
                end
                if item then
                    CombatServer.RS.Add(player, "Items")
                    local gp = GroundPos(state)
                    if gp then DropToGround(player, state, item, kind, gp, true) else GrantLootItem(player, state, item, kind, true) end -- (0.75: never auto-sold)
                    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", (daily and "DAILY TARGET: " or "TARGET LOOT: ") .. string.upper(item.Rarity .. " " .. (item.Name or "")),
                        ItemData.RarityColors[item.Rarity] or Color3.fromRGB(255, 215, 90))
                end
            end
        end
    end
end

-- RUN ENCOUNTER rewards (UPDATE 7, Encounters): the Vault Lock = 2 items with better odds (+1 on a clean crack), gold,
-- and from the Shift Shard's unlock level 1 Shift Shard (+1 clean). Returns the line the client shows.
function CombatServer.EncounterReward(player: Player, id: string, result: any): string
    local state = CombatServer.GetState(player)
    local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
    local clean = type(result) == "table" and result.Clean == true
    -- (LOOT SCARCITY 2026-11-07) items EncounterItems (+1 clean), the encounter's currency EncounterCurChance of the time and one more
    -- EncounterCurClean of the time on a clean run (was 2 / 3 items, 1 / 2 currency always)
    local LS = ItemData.Scarce() and ItemData.LOOT_SCARCITY or nil
    local function Cur(extra: boolean): number
        if not LS then return extra and 2 or 1 end
        local n = (math.random() < LS.EncounterCurChance) and 1 or 0
        if extra and math.random() < LS.EncounterCurClean then n += 1 end
        return n
    end
    if id == "VAULT_LOCK" then
        DropInFront(player, state)
        local nItems = LS and (LS.EncounterItems + (clean and 1 or 0)) or (clean and 3 or 2)
        for i = 1, nItems do DropItem(player, state, stats, (clean and i == nItems) and 2.0 or 1.6, (clean and i == nItems) and "Top3" or "Top4") end
        local gold = math.round(math.random(150, 300) * (stats.GoldBonusMult or 1) * (clean and 1.5 or 1))
        state.Gold += gold
        local parts = { nItems .. " item" .. (nItems == 1 and "" or "s"), ItemData.FormatNumber(gold) .. " gold" }
        if ItemData.MaterialUnlocked("ShiftShard", state.Level) then
            local n = Cur(clean) * (require(game.ReplicatedStorage.AimRngShared.WorldAlerts).Is("CURRENCY_RAIN") and 2 or 1)
            if n > 0 then
                GrantMaterials(player, state, { ShiftShard = n }, nil, true)
                table.insert(parts, n .. " Turncoat" .. (n == 1 and "" or "s"))
            end
        end
        ;(state :: any)._DropAt = nil; (state :: any)._DropFan = nil
        CombatServer.ContractEvent(player, state, "Encounter", 1, { Id = id, Clean = clean }) -- (weekly bounties)
        Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
        return (clean and "VAULT CRACKED CLEAN: " or "VAULT CRACKED: ") .. table.concat(parts, ", ")
    end
    -- the other three (UPDATE 7, the full set): each pays ITS currency; Clean = done in under half the time (the mark / the
    -- echo) -- the tear pays by kills instead
    local KIND = { BOUNTY_MARK = { Cur = "Graft", Head = "RUNNER CAUGHT" }, RIFT_TEAR = { Cur = "StripShard", Head = "BREACH CLOSED" },
        ECHO_DUEL = { Cur = "Temper", Head = "ECHO SHATTERED" } }
    local k = KIND[id]
    if not k then return "Done" end
    local kills = type(result) == "table" and tonumber(result.Kills) or 0
    local items, cur, goldK = 2, 1, 1
    if id == "RIFT_TEAR" then
        items = math.clamp(1 + kills // 8, 1, 4)
        cur = math.clamp(1 + kills // 12, 1, 3)
        goldK = 0.5 + 0.05 * math.min(kills, 30)
        if LS then items = math.clamp(LS.EncounterItems + kills // 16, 1, 3); cur = Cur(kills >= 16) end
    elseif clean then
        items, cur, goldK = 3, 2, 1.5
        if LS then items, cur = LS.EncounterItems + 1, Cur(true) end
    elseif LS then
        items, cur = LS.EncounterItems, Cur(false)
    end
    DropInFront(player, state)
    for n = 1, items do DropItem(player, state, stats, 1.6, (n == items and n >= 2 and clean) and "Top3" or "Top4") end
    local gold = math.round(math.random(150, 300) * (stats.GoldBonusMult or 1) * goldK)
    state.Gold += gold
    local parts = { items .. " item" .. (items == 1 and "" or "s"), ItemData.FormatNumber(gold) .. " gold" }
    if ItemData.MaterialUnlocked(k.Cur, state.Level) and cur > 0 then
        if require(game.ReplicatedStorage.AimRngShared.WorldAlerts).Is("CURRENCY_RAIN") then cur *= 2 end -- (UPDATE 7 WORLD ALERTS)
        GrantMaterials(player, state, { [k.Cur] = cur }, nil, true)
        table.insert(parts, cur .. " " .. ItemData.MaterialDefs[k.Cur].Name .. ((cur == 1) and "" or "s"))
    end
    ;(state :: any)._DropAt = nil; (state :: any)._DropFan = nil
    CombatServer.ContractEvent(player, state, "Encounter", 1, { Id = id, Clean = clean, Kills = kills })
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    return (id == "RIFT_TEAR" and (k.Head .. " (" .. kills .. " kills): ") or (k.Head .. (clean and " FAST: " or ": "))) .. table.concat(parts, ", ")
end

-- Supply cache (4 per floor): a little gold and Scrap, sometimes an item.
function CombatServer.GiveSupplyChestLoot(player: Player)
    local state = CombatServer.GetState(player)
    local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
    state.Gold += math.round(math.random(25, 55) * stats.GoldBonusMult)
    GrantMaterials(player, state, { Scrap = 3 })
    DropInFront(player, state)
    if math.random() < 0.25 then DropItem(player, state, stats, 1.0) end
    if math.random() < 0.02 then DropGem(player, state, stats, 1.0) end
    CombatServer.PityChest(player, state, ItemData.Pity.CHEST_UNITS.Supply)
    ;(state :: any)._DropAt = nil; (state :: any)._DropFan = nil
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
end

-- Victory chest after a floor clear: gold, 1-2 items, Scrap + Alloy, a small Tuning Kit chance.
-- (Boss floors' big loot comes from the boss kill itself.)
function CombatServer.GiveFloorLoot(player: Player, isBoss: boolean?)
    local state = CombatServer.GetState(player)
    local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
    local gMin = isBoss and 400 or 50
    local gMax = isBoss and 900 or 150
    state.Gold += math.round(math.random(gMin, gMax) * stats.GoldBonusMult)
    DropInFront(player, state)
    DropItem(player, state, stats, isBoss and 1.5 or 1.2, isBoss and "Top4" or nil)
    if math.random() < (ItemData.Scarce() and ItemData.LOOT_SCARCITY.ChestSecond or 0.4) then DropItem(player, state, stats, 1.2) end -- (LOOT SCARCITY)
    GrantMaterials(player, state, { Scrap = 5, Alloy = 1 }, { TuningKit = 0.05 })
    if math.random() < (isBoss and 0.25 or 0.08) then DropGem(player, state, stats, isBoss and 1.5 or 1.2) end
    CombatServer.PityChest(player, state, isBoss and ItemData.Pity.CHEST_UNITS.BossVault or ItemData.Pity.CHEST_UNITS.Vault)
    ;(state :: any)._DropAt = nil; (state :: any)._DropFan = nil
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
end


function CombatServer.UpdatePlayerTitleTag(player: Player)
    local state = CombatServer.GetState(player)
    local tKey = state.EquippedTitle or "Rookie"
    local tData = ItemData.Titles[tKey] or ItemData.Titles.Rookie
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head") :: BasePart?
    if not head then return end

    local tag = head:FindFirstChild("PlayerTitleTag") :: BillboardGui?
    -- (Mega-City restyle 2026-10-04, owner: "make sure the titles ... match the current UI"): a dark gunmetal plate,
    -- a block in the title's rarity colour on the left, condensed uppercase type (no stars, no outline)
    if tag and not tag:FindFirstChild("Plate") then tag:Destroy(); tag = nil end
    if not tag then
        tag = Instance.new("BillboardGui")
        tag.Name = "PlayerTitleTag"
        tag.Size = UDim2.new(0, 260, 0, 24)
        tag.StudsOffset = Vector3.new(0, 2, 0) -- (clears hats / horns)
        tag.AlwaysOnTop = false -- (AlwaysOnTop tags never drew in the hub; this way they also don't show through walls)
        tag.MaxDistance = 150
        tag.Adornee = head
        -- everyone sees it; the wearer's own client shows it only in third person (AimRngClient)
        tag.Parent = head

        local plate = Instance.new("Frame")
        plate.Name = "Plate"
        plate.AnchorPoint = Vector2.new(0.5, 0.5)
        plate.Position = UDim2.fromScale(0.5, 0.5)
        plate.Size = UDim2.new(0, 0, 0, 20)
        plate.AutomaticSize = Enum.AutomaticSize.X
        plate.BackgroundColor3 = Color3.fromRGB(14, 15, 18)
        plate.BackgroundTransparency = 0.12
        plate.BorderSizePixel = 0
        plate.Parent = tag
        local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 11); pad.PaddingRight = UDim.new(0, 8); pad.Parent = plate
        local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(56, 58, 64); st.Thickness = 1; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = plate
        local block = Instance.new("Frame")
        block.Name = "Block"
        block.BorderSizePixel = 0
        block.Size = UDim2.new(0, 4, 1, 0)
        block.Position = UDim2.fromOffset(-11, 0)
        block.Parent = plate

        local tLbl = Instance.new("TextLabel")
        tLbl.Name = "TitleText"
        tLbl.Size = UDim2.new(0, 0, 1, 0)
        tLbl.AutomaticSize = Enum.AutomaticSize.X
        tLbl.BackgroundTransparency = 1
        tLbl.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
        tLbl.TextSize = 14
        tLbl.TextStrokeTransparency = 1
        tLbl:SetAttribute("KeepFont", true)
        tLbl.Parent = plate
    end

    tag.StudsOffset = Vector3.new(0, 2, 0)
    tag.AlwaysOnTop = false
    tag.PlayerToHideFrom = nil
    local plate = tag:FindFirstChild("Plate")
    local tLbl = plate and plate:FindFirstChild("TitleText") :: TextLabel?
    if tLbl then
        -- (UPDATE 7 MASTERY RANK: the rank emblem in front of the title, from rank 1)
        local MR = require(game.ReplicatedStorage.AimRngShared.MasteryRank)
        local emblem = MR.Emblem(MR.Rank(state))
        tLbl.RichText = true
        local gtag = player:GetAttribute("GuildTag") -- (UPDATE 7 B9: the guild tag in its colour)
        tLbl.Text = ((type(gtag) == "string" and gtag ~= "") and string.format('<font color="#%s">[%s]</font>  ', tostring(player:GetAttribute("GuildColor") or "c8d2e1"), gtag) or "")
            .. (emblem and string.format('<font color="#%s">%s</font>   ', MR.Color:ToHex(), emblem) or "") .. tData.Title:upper()
        tLbl.TextColor3 = tData.Color
        local block = plate:FindFirstChild("Block") :: Frame?
        if block then block.BackgroundColor3 = tData.Color end
    end
end

-- ==================== WORLD GEAR (other players see your gun, melee and gloves) ====================
-- Built by WorldGear (same models + skins as the first-person view) and welded to the character: the gun slung on the
-- back in the hub (pistols on the right thigh), in the right hand with the arm raised during a run; the melee at the
-- left hip; gloves over the hands. Nothing while downed / spectating. Built on the server so it replicates to everyone;
-- your own copy is hidden by the first-person camera like the rest of your body (and shown in the third-person hub).
local WorldGear = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("WorldGear"))
local MeleeDataWG = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("MeleeData"))
local SkinFXWG = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("SkinFX"))
local GloveFXWG = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("GloveFX"))
local ArmorFXWG = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ArmorFX"))
local WORLD_GUN_TOOLNONE = { R15 = "rbxassetid://507768375", R6 = "rbxassetid://182393478" } -- Roblox's own "holding a tool" arm pose
local WORLD_GUN_PISTOLS = { Pistol = true }
local worldGunKey: { [Player]: string } = {}
local worldGunChar: { [Player]: Model } = {}
local worldGunTrack: { [Player]: AnimationTrack } = {}

-- the hub's TRAINING GROUNDS (HubGenerator.RANGE): you shoot there, so the gun is in your hands, not on your back
-- (owner: "other players' guns don't show up in the hub shooting range")
local function InTrainingGrounds(player: Player): boolean
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return false end
    local ok, HubGen = pcall(require, script.Parent:WaitForChild("HubGenerator"))
    local R = ok and HubGen.RANGE
    if not R then return false end
    local p = root.Position
    return p.Z > R.Z0 - 2 and p.Z < R.Z1 and math.abs(p.X) < R.HalfX and p.Y < R.Height + 20
end
local function WorldGunMode(player: Player): string
    if player:GetAttribute("Downed") or player:GetAttribute("Spectating") then return "None" end
    return (InDungeonRun(player) or InTrainingGrounds(player) or player:GetAttribute("PvpDuel") ~= nil) and "Hand" or "Back"
end

local WORLD_GEAR = { "WorldGun", "WorldMelee", "WorldGloves", "WorldArmor" }
local function ClearWorldGun(player: Player, char: Model?)
    for _, n in ipairs(WORLD_GEAR) do
        local old = char and char:FindFirstChild(n)
        if old then old:Destroy() end
    end
    local tr = worldGunTrack[player]
    if tr then tr:Stop(0.2); worldGunTrack[player] = nil end
end

-- the cosmetics the world gear wears (whatever the player has equipped -- WorldGear draws them like the first-person view)
local function WorldGearSkins(st: any): (any?, any?)
    -- a premium per-gun skin (SkinFX, e.g. Seraphim M4A1) wins over the old all-guns finish
    local gunSkin = SkinFXWG.GunSkinFor(st, st.EquippedWeapon and st.EquippedWeapon.BaseId) or ItemData.WeaponSkins[st.EquippedWeaponSkin or "Factory"]
    local meleeSkin = MeleeDataWG.SkinFor(st, st.EquippedKnife)
    return gunSkin, meleeSkin
end

-- Back accessories (the avatar's backbling: wings, capes, back swords ...) clip through a gun / spear slung on the
-- back, so they hide while something is slung there and come back when it's drawn (runs), holstered on the thigh
-- (pistols) or gone (downed). Matched by AccessoryType Back or a back attachment; original transparency is kept in
-- the "BBT" attribute so it restores exactly.
local BACK_ATTACH = { BodyBackAttachment = true, WaistBackAttachment = true }
local function IsBackAccessory(acc: Accessory): boolean
    local okT, t = pcall(function() return acc.AccessoryType end)
    if okT and t == Enum.AccessoryType.Back then return true end
    local handle = acc:FindFirstChild("Handle")
    if handle then
        for _, a in ipairs(handle:GetChildren()) do
            if a:IsA("Attachment") and BACK_ATTACH[a.Name] then return true end
        end
    end
    return false
end
local function SetBackbling(char: Model, hidden: boolean)
    for _, acc in ipairs(char:GetChildren()) do
        if acc:IsA("Accessory") and IsBackAccessory(acc) then
            for _, d in ipairs(acc:GetDescendants()) do
                if d:IsA("BasePart") or d:IsA("Decal") then
                    local orig = d:GetAttribute("BBT")
                    if hidden then
                        if orig == nil then d:SetAttribute("BBT", d.Transparency) end
                        d.Transparency = 1
                    elseif orig ~= nil then
                        d.Transparency = orig
                        d:SetAttribute("BBT", nil)
                    end
                end
            end
        end
    end
end

-- (owner 2026-10-04: "the top of some models meshes with the equipped sleeve, so their arm clips through and constantly
-- flickers"): a limb fully covered by glove + sleeve shells is hidden under them (original Transparency kept in "ShellT")
local function CoverLimb(limb: BasePart?, covered: boolean)
    if not limb then return end
    local orig = limb:GetAttribute("ShellT")
    if covered then
        if orig == nil then limb:SetAttribute("ShellT", limb.Transparency) end
        limb.Transparency = 1
    elseif orig ~= nil then
        limb.Transparency = orig
        limb:SetAttribute("ShellT", nil)
    end
end

local function BuildWorldGun(player: Player, char: Model, st: any, mode: string)
    ClearWorldGun(player, char)
    for _, n in ipairs({ "Left Arm", "Right Arm", "LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm", "LeftUpperArm", "RightUpperArm" }) do
        CoverLimb(char:FindFirstChild(n) :: BasePart?, false) -- (re-covered below by whatever shells go on)
    end
    SetBackbling(char, false) -- (hidden again below if a gun / spear goes on the back)
    local hum = char:FindFirstChildOfClass("Humanoid")
    local r15 = hum and hum.RigType == Enum.HumanoidRigType.R15
    -- (armor cosmetics were retired 2026-10-02 -- players wear their own Roblox avatars)
    if mode == "None" then return end
    local gunSkin, meleeSkin = WorldGearSkins(st)

    -- gloves + sleeves: a shell over each hand (and, with a sleeve, each arm segment) in the cosmetic's base look +
    -- texture. A GloveFX look is tagged (LookKind / LookId / Side): every CLIENT builds its decorations, wings, beams
    -- and particles locally and animates them (GloveFX.StartWorld). Old-style gloves are just the coloured shell.
    local gColor, gMat = WorldGear.GloveLook(st.EquippedGlove)
    local gdef, sdef = GloveFXWG.GloveFor(st), GloveFXWG.SleeveFor(st)
    local gloves = Instance.new("Model")
    gloves.Name = "WorldGloves"
    -- yFrom..yTo = the slice of the limb's height it covers (-0.5 bottom .. 0.5 top): R6 arms are one block, so the
    -- glove is the bottom of the arm and the sleeve the rest
    local function Shell(limb: BasePart, name: string, scale: Vector3, def: any?, kind: string, side: string, yFrom: number?, yTo: number?)
        local g = Instance.new("Part")
        g.Name = name
        local y0, y1 = yFrom or -0.5, yTo or 0.5
        g.Size = Vector3.new(limb.Size.X * scale.X, limb.Size.Y * (y1 - y0) * scale.Y, limb.Size.Z * scale.Z)
        g.Color = gColor; g.Material = gMat
        g.TopSurface = Enum.SurfaceType.Smooth; g.BottomSurface = Enum.SurfaceType.Smooth
        g.CanCollide = false; g.CanQuery = false; g.CanTouch = false; g.Massless = true
        local off = CFrame.new(0, limb.Size.Y * (y0 + y1) / 2, 0)
        g.CFrame = limb.CFrame * off
        local w = Instance.new("Weld"); w.Part0 = limb; w.Part1 = g; w.C0 = off; w.Parent = g
        if def then
            GloveFXWG.ApplyBase(def, g, nil, math.max(g.Size.X, g.Size.Z), true) -- (no textures: clients add them)
            g:SetAttribute("LookKind", kind)
            g:SetAttribute("LookId", def.Id)
            g:SetAttribute("Side", side)
        end
        g.Parent = gloves
    end
    for _, side in ipairs({ "Left", "Right" }) do
        local sd = side == "Left" and "L" or "R"
        if r15 then
            local hand = char:FindFirstChild(side .. "Hand") :: BasePart?
            if hand then Shell(hand, side .. "HandGlove", Vector3.new(1.08, 1.08, 1.08), gdef, "Glove", sd); CoverLimb(hand, true) end
            if sdef then
                for _, seg in ipairs({ "LowerArm", "UpperArm" }) do
                    local limb = char:FindFirstChild(side .. seg) :: BasePart?
                    if limb then Shell(limb, side .. seg .. "Sleeve", Vector3.new(1.05, 1.02, 1.05), sdef, "Sleeve", sd); CoverLimb(limb, true) end
                end
            end
        else
            -- R6 (the game's rig, like Rivals): one block per arm -- the glove covers the hand end (bottom 30%),
            -- a sleeve the rest of the arm
            local arm = char:FindFirstChild(side .. " Arm") :: BasePart?
            if arm then
                -- (2026-10-13, owner: third-person gloves "look a little silly" -- big dark blocks over the hands covering the
                -- gun): slim shells, the glove just the bottom 20 % of the arm at 1.05x, the sleeve 1.03x; the client keeps
                -- only a small accent of the look's decorations at world scale (GloveFX.WorldDef)
                Shell(arm, side .. "HandGlove", Vector3.new(1.05, 1.02, 1.05), gdef, "Glove", sd, -0.5, -0.3)
                if sdef then
                    -- (to 0.51: the sleeve's top face sat exactly on the shoulder's and z-fought; the arm under it is hidden)
                    Shell(arm, side .. "ArmSleeve", Vector3.new(1.03, 1.0, 1.03), sdef, "Sleeve", sd, -0.3, 0.51)
                    CoverLimb(arm, true)
                end
            end
        end
    end
    gloves.Parent = char

    -- melee: on the left hip, a little behind the hanging arm, handle up and leaning back (MeleeData rig: the handle
    -- runs along the grip's Y axis, so the grip is turned upside down to hang the head / blade downwards)
    local melee, mFrame, mDef = WorldGear.Melee(st.EquippedKnife, meleeSkin)
    if melee and mDef then melee:SetAttribute("MeleeClass", mDef.Class or (meleeSkin and meleeSkin.Class) or "Knife") end -- (CharacterPoser hold)
    local hip = char:FindFirstChild(r15 and "LowerTorso" or "Torso") :: BasePart?
    local back = char:FindFirstChild(r15 and "UpperTorso" or "Torso") :: BasePart?
    if melee and mFrame and back and meleeSkin and meleeSkin.RigId then
        -- long model skins (the Seraphim Spear): slung diagonally across the back, head up over the right shoulder
        local w = Instance.new("Weld")
        w.Name = "WorldMeleeWeld"
        w.Part0 = back; w.Part1 = mFrame
        w.C0 = CFrame.new(0, 0, back.Size.Z / 2 + 0.18) * CFrame.Angles(0, 0, math.rad(-38))
        w.C1 = CFrame.new(0, 1.1, 0) -- (the spear's middle, up the shaft from the grip)
        w.Parent = mFrame
        melee.Parent = char
        SetBackbling(char, true)
    elseif melee and mFrame and hip then
        local grip = (mDef.Points and mDef.Points.GripR) or CFrame.new()
        local w = Instance.new("Weld")
        w.Name = "WorldMeleeWeld"
        w.Part0 = hip; w.Part1 = mFrame
        w.C0 = CFrame.new(-(hip.Size.X / 2 + 0.06), r15 and -0.05 or -0.6, hip.Size.Z * 0.32) * CFrame.Angles(math.rad(-14), 0, math.rad(180)) * CFrame.Angles(0, math.rad(90), 0)
        w.C1 = grip
        w.Parent = mFrame
        melee.Parent = char
    elseif melee then
        melee:Destroy()
    end

    -- gun
    local gun, frame, def = WorldGear.Gun(st.EquippedWeapon and st.EquippedWeapon.BaseId or "", gunSkin, st.EquippedWeapon and st.EquippedWeapon.Exotic)
    if not (gun and frame and def) then return end -- old asset-pack guns have no model: show nothing
    local baseId = st.EquippedWeapon.BaseId
    local weld = Instance.new("Weld")
    weld.Name = "WorldGunWeld"
    weld.Part1 = frame
    -- gun space: +X = barrel, +Y = top, Z = width. Measured on the gun's own parts only: a premium skin's decorations
    -- (SkinDeco) left out -- the Ironclad M4 Super 90's hidden 4.6-stud inspect laser stretched the box forward and slid
    -- the slung gun 1.8 studs up past the shoulder, and side decorations pushed it off the back (Solaris AWP 0.56)
    local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
    for _, d in ipairs(gun:GetDescendants()) do
        if d:IsA("BasePart") and not d:GetAttribute("SkinDeco") then
            local rel, h = frame.CFrame:ToObjectSpace(d.CFrame), d.Size / 2
            for _, c in ipairs({ Vector3.new(h.X, h.Y, h.Z), Vector3.new(-h.X, h.Y, h.Z), Vector3.new(h.X, -h.Y, h.Z), Vector3.new(h.X, h.Y, -h.Z),
                Vector3.new(-h.X, -h.Y, h.Z), Vector3.new(-h.X, h.Y, -h.Z), Vector3.new(h.X, -h.Y, -h.Z), Vector3.new(-h.X, -h.Y, -h.Z) }) do
                local q = rel * c
                lo, hi = lo:Min(q), hi:Max(q)
            end
        end
    end
    local centre, bbSize = (lo + hi) / 2, hi - lo
    local baseDef = ItemData.BaseWeapons[baseId]
    local isPistol = baseDef and WORLD_GUN_PISTOLS[baseDef.Class] or false
    if mode == "Hand" then
        local hand = char:FindFirstChild(r15 and "RightHand" or "Right Arm") :: BasePart
        local grip = hand and hand:FindFirstChild("RightGripAttachment") :: Attachment
        if not hand then gun:Destroy(); return end
        -- (2026-10-13) the fist on the GRIP: only the G17 has a GripR point; every other gun takes the spot under and
        -- behind its trigger (it used to sit on the frame origin = mid-receiver)
        local gp = (def.Points.GripR and def.Points.GripR.Position)
            or (def.Points.TriggerPivot and def.Points.TriggerPivot.Position + Vector3.new(-0.18, -0.16, 0)) or Vector3.zero
        local g = gp * WorldGear.GUN_SCALE
        weld.Part0 = hand
        weld.C0 = grip and grip.CFrame or CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
        -- tool convention: -Z forward, +Y up -> the gun's +X barrel turns to -Z
        weld.C1 = CFrame.new(g) * CFrame.Angles(0, -math.pi / 2, 0)
        -- (2026-10-13) the arms are posed by every client's CharacterPoser (R6): the gun's hold class + where the
        -- support hand goes (the gun's own GripPose.L, studs up the barrel from the grip); no Roblox tool animation
        do
            local rc = def.RivalsClass
            local grp = baseDef and ItemData.WeaponGroupOf({ BaseId = baseId, Class = baseDef.Class })
            local hold = (rc == "PISTOL" and "Pistol") or (rc == "SNIPER" and "Sniper") or ((rc == "LMG" or rc == "HEAVY") and "LMG")
                or (rc == "SHOTGUN" and "Shotgun") or (rc == "SMG" and "SMG") or (grp == "Beam" and "Beam") or "Rifle"
            gun:SetAttribute("Hold", hold)
            local lw = def.GripPose and def.GripPose.L and def.GripPose.L.Wrist
            if typeof(lw) == "Vector3" then gun:SetAttribute("SupFwd", (lw.X * WorldGear.GUN_SCALE) - g.X) end
        end
        local animator = (not r15) and nil or (hum and hum:FindFirstChildOfClass("Animator"))
        if animator then
            local anim = Instance.new("Animation")
            anim.AnimationId = WORLD_GUN_TOOLNONE[r15 and "R15" or "R6"]
            local ok, tr = pcall(function() return animator:LoadAnimation(anim) end)
            if ok and tr then
                tr.Priority = Enum.AnimationPriority.Action
                tr.Looped = true
                tr:Play(0.2)
                worldGunTrack[player] = tr
            end
        end
    elseif isPistol then
        -- thigh holster on the outside of the right leg (clear of the hanging arm), barrel down
        local leg = char:FindFirstChild(r15 and "RightUpperLeg" or "Right Leg") :: BasePart
        if not leg then gun:Destroy(); return end
        weld.Part0 = leg
        weld.C0 = CFrame.new(leg.Size.X / 2 + bbSize.Z / 2 + 0.03, r15 and 0.05 or 0.35, 0) * CFrame.Angles(0, math.pi / 2, -math.pi / 2)
        weld.C1 = CFrame.new(centre)
    else
        -- slung diagonally across the back, barrel up over the left shoulder
        local torso = char:FindFirstChild(r15 and "UpperTorso" or "Torso") :: BasePart
        if not torso then gun:Destroy(); return end
        weld.Part0 = torso
        local depth = torso.Size.Z / 2 + bbSize.Z / 2 + 0.05
        weld.C0 = CFrame.new(0, r15 and -0.1 or 0, depth) * CFrame.Angles(0, 0, math.rad(-140)) * CFrame.Angles(math.pi, 0, 0)
        weld.C1 = CFrame.new(centre)
        SetBackbling(char, true)
    end
    weld.Parent = frame
    gun.Parent = char
end

function CombatServer.InitWorldGuns()
    Players.PlayerRemoving:Connect(function(p) worldGunKey[p] = nil; worldGunChar[p] = nil; worldGunTrack[p] = nil end)
    -- SHOTS for everyone else (owner: "other players' guns can't be seen shooting or heard"): the shooter's client sends
    -- where each trigger pull landed; nearby players draw the flash + tracer from that player's world gun and hear it
    do
        local shotFx = Remotes.GetEvent("ShotFx")
        local lastShot: { [Player]: number } = {}
        Players.PlayerRemoving:Connect(function(p) lastShot[p] = nil end)
        shotFx.OnServerEvent:Connect(function(player: Player, hitPos: any, stamp: any)
            if type(stamp) ~= "number" or stamp ~= stamp then stamp = nil end -- (0.83: the shooter's clock, for spectators)
            if typeof(hitPos) ~= "Vector3" or hitPos ~= hitPos then return end
            local now = os.clock()
            if now - (lastShot[player] or 0) < 0.035 then return end -- (~28 a second at most)
            lastShot[player] = now
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
            local st = playerStates[player]
            if not root or not st or not st.EquippedWeapon or (hitPos - root.Position).Magnitude > 1500 then return end
            local baseId = player:GetAttribute("PvpGun") or st.EquippedWeapon.BaseId -- (0.60: a duel gun is what others see + hear)
            local skinKind = (SkinFXWG.GunSkinFor(st, baseId) or {}).FX -- (a premium skin's own tracer for everyone else)
            local InstanceKey = require(game.ReplicatedStorage.AimRngShared.InstanceKey)
            local key = InstanceKey.Of(player, root.Position)
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player then
                    local oroot = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    -- (single instances: only players in the SAME instance see / hear the shot -- InstanceKey)
                    -- (0.62 SPECTATE: a watcher in the hub hears / sees the shots of the player they watch)
                    -- (0.79: and a watcher of anyone in this instance -- a duel's spectators see both duelists shoot)
                    if oroot and (((oroot.Position - root.Position).Magnitude < 320 and InstanceKey.Of(other, oroot.Position) == key) or other:GetAttribute("WatchUid") == player.UserId
                        or (other:GetAttribute("WatchUid") and InstanceKey.Of(other) == "watch:" .. key)) then
                        (shotFx :: any):FireClient(other, player, hitPos, baseId, skinKind, stamp)
                    end
                end
            end
        end)
    end
    -- Focus streaks don't leave the training grounds / dungeons: back in the hub hall it resets
    -- (it used to stay on screen after the range, and would have carried into the next run).
    task.spawn(function()
        while true do
            task.wait(0.5)
            for _, p in ipairs(Players:GetPlayers()) do
                local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                local st = playerStates[p]
                if root and st and (st.Streak or 0) > 0 then
                    local pos = root.Position
                    if math.abs(pos.X) < 80 and pos.Z > -80 and pos.Z < 74 and pos.Y < 70 then
                        st.Streak = 0
                        CombatServer.SendCombatDelta(p, st)
                    end
                end
            end
        end
    end)
    -- spectators look through your eyes: your look pitch is shared as the player attribute AimPitch (yaw = your body's facing)
    -- sliding pose for everyone else (MovementController sends it on change; clients pose the body)
    local slideAt: { [Player]: number } = {}
    local dashAt: { [Player]: number } = {}
    Remotes.GetEvent("MoveState").OnServerEvent:Connect(function(player: Player, sliding: any)
        -- (0.56) a dash: "Dashing" = server time it started, every client poses the lunge for ~0.3 s
        if sliding == "dash" then
            if os.clock() - (dashAt[player] or 0) < 0.2 then return end
            dashAt[player] = os.clock()
            player:SetAttribute("Dashing", workspace:GetServerTimeNow())
            return
        end
        -- (2026-10-13, CharacterPoser) crouch + which slot is out, for everyone else's view of your body
        if sliding == "crouch" or sliding == "stand" then player:SetAttribute("Crouching", sliding == "crouch" or nil) return end
        if sliding == "slot:Melee" or sliding == "slot:Gun" then player:SetAttribute("HoldMelee", sliding == "slot:Melee" or nil) return end
        if type(sliding) ~= "boolean" or os.clock() - (slideAt[player] or 0) < 0.08 then return end
        slideAt[player] = os.clock()
        player:SetAttribute("Sliding", sliding or nil)
    end)
    Remotes.GetEvent("AimPitch").OnServerEvent:Connect(function(player: Player, pitch: any)
        if type(pitch) ~= "number" or pitch ~= pitch then return end
        player:SetAttribute("AimPitch", math.floor(math.clamp(pitch, -1.5, 1.5) * 100 + 0.5) / 100)
    end)
    -- polled (cheap): the gun changes in many places (equip, equip best, swaps, run start/end, downed, spectate)
    task.spawn(function()
        while true do
            task.wait(0.5)
            for _, p in ipairs(Players:GetPlayers()) do
                local st = playerStates[p]
                local char = p.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local pvpGun = p:GetAttribute("PvpGun") -- (0.60 duels: the gun picked for the duel, not the equipped one)
                if st and pvpGun then st = setmetatable({ EquippedWeapon = { BaseId = pvpGun, Name = pvpGun } }, { __index = st }) end
                if st and char and hum and hum.Health > 0 then
                    local baseId = st.EquippedWeapon and st.EquippedWeapon.BaseId or ""
                    local mode = WorldGunMode(p)
                    local meleeSkin = MeleeDataWG.SkinFor(st, st.EquippedKnife)
                    -- rebuilt whenever the gear, its cosmetics, the mode or the body (AvatarRev) change
                    local key = table.concat({ baseId, tostring(st.EquippedWeapon and st.EquippedWeapon.Exotic), mode, tostring(char:GetAttribute("AvatarRev")), tostring(st.EquippedWeaponSkin),
                        tostring(st.EquippedKnife), tostring(meleeSkin and meleeSkin.Name), tostring(st.EquippedGlove),
                        tostring((SkinFXWG.GunSkinFor(st, baseId) or {}).Id), tostring((GloveFXWG.GloveFor(st) or {}).Id), tostring((GloveFXWG.SleeveFor(st) or {}).Id),
                        tostring((SkinFXWG.GunSkinFor(st, baseId) or {}).FX), tostring(meleeSkin and meleeSkin.RigId), -- (0.93 colourways)
                        (function() local w, o = ArmorFXWG.Worn(st), {}; for _, sl in ipairs(ArmorFXWG.Slots) do table.insert(o, w[sl] and w[sl].Id or "-") end; return table.concat(o, ",") end)() }, "|")
                    -- rebuild on change, or for a new character after a respawn
                    if worldGunKey[p] ~= key or worldGunChar[p] ~= char then
                        worldGunKey[p] = key
                        worldGunChar[p] = char
                        local okB, err = pcall(BuildWorldGun, p, char, st, mode)
                        if not okB then warn("[WorldGuns] " .. tostring(err)) end
                    end
                end
            end
        end
    end)
end

function CombatServer.Init()
    -- TARGET LOOT picks (Dungeons window; not during a run). weaponId / gearType: a lineup gun / ItemData.Pity.GEAR (nil
    -- clears). A changed pick starts its infinite meter over (no banking a full meter for a swap).
    Remotes.GetFunction("SetPityTargets").OnServerInvoke = function(player: Player, weaponId: any, gearType: any): (boolean, string)
        local state = CombatServer.GetState(player)
        if not state then return false, "Not loaded yet." end
        if InDungeonRun(player) then return false, "Targets are locked during a run." end
        if weaponId ~= nil and not (type(weaponId) == "string" and table.find(ItemData.Lineup, weaponId)) then return false, "Pick a gun from the list." end
        if gearType ~= nil and not (type(gearType) == "string" and table.find(ItemData.Pity.GEAR, gearType)) then return false, "Pick a gear type from the list." end
        local p = ItemData.PityState(state)
        if p.W ~= weaponId then p.IW = 0 end
        if p.G ~= gearType then p.IG = 0 end
        p.W, p.G = weaponId, gearType
        state.Pity = p
        Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
        return true, "Target loot set."
    end
    CombatServer.InitLives()
    CombatServer.InitWorldGuns()
    CombatServer.InitSeasonPass()
    -- Black Market restock: on the hour, everyone online gets a fresh stock (the window refreshes if it's open)
    task.spawn(function()
        local lastHour = ShopHour()
        while true do
            task.wait(5)
            if ShopHour() ~= lastHour then
                lastHour = ShopHour()
                for p, st in pairs(playerStates) do
                    if p.Parent then
                        EnsureShop(st)
                        Remotes.GetEvent("ShopRefreshed"):FireClient(p)
                    end
                end
            end
        end
    end)

    -- dungeon safe zones (see UpdateSafeZone)
    task.spawn(function()
        while true do
            task.wait(0.25)
            for _, p in ipairs(Players:GetPlayers()) do pcall(UpdateSafeZone, p) end
        end
    end)

    -- HP Regeneration
    task.spawn(function()
        while true do
            task.wait(1)
            for player, state in pairs(playerStates) do
                if state.Health < state.MaxHealth and not FloorMods.Has(DungeonRuns.Attr(player, "Mods"), "NO_REGEN") then -- (0.62 map mod Bleak)
                    local rStats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
                    local regen = rStats.HPRegen
                    state.Health = math.min(state.MaxHealth, math.round((state.Health + regen) * 10) / 10)
                    CombatServer.SendCombatDelta(player, state)
                end
            end
        end
    end)

    -- Private dungeon runs (stand-ins, client reports, leaving the arena ends the run).
    DungeonRuns.Init(CombatServer)
    PartyRuns.Init(CombatServer)
    PartyService.Init(CombatServer, PartyRuns)
    require(script.Parent:WaitForChild("RunAgain")).Init() -- (QOL F1: RUN AGAIN on the run summary / victory banner)
    CombatServer.Buyback = require(script.Parent:WaitForChild("Buyback")) -- (QOL2 I3: the last 10 sold items, memory only)
    CombatServer.Buyback.Init(CombatServer)
    Remotes.GetEvent("TeleportPlayer").OnServerEvent:Connect(function(player: Player, dest: any)
        if dest == "Hub" then
            DungeonRuns.EndRun(player)
            PartyRuns.RemoveMember(player)
        end
    end)

    local hitRemote = Remotes.GetEvent("ReportHit")
    local stateSync = Remotes.GetEvent("SyncPlayerState")
    local hitConfirmed = Remotes.GetEvent("HitConfirmed")
    local rollFunc = Remotes.GetFunction("RollWeaponRNG")
    local equipFunc = Remotes.GetFunction("EquipWeapon")
    local upgradeFunc = Remotes.GetFunction("UpgradeWeapon")
    local getStateFunc = Remotes.GetFunction("GetPlayerState")
    local startDungeonFunc = Remotes.GetFunction("StartDungeonRaid")
    local sellFunc = Remotes.GetFunction("SellWeapon")
    local quickSellFunc = Remotes.GetFunction("QuickSellRarity")
    local autoSellFunc = Remotes.GetFunction("SetAutoSellThreshold")
    local allocStatFunc = Remotes.GetFunction("AllocateStatPoint")
    local equipGearFunc = Remotes.GetFunction("EquipGear")
    local unequipGearFunc = Remotes.GetFunction("UnequipGear")
    local sellGearFunc = Remotes.GetFunction("SellGear")
    local buyShopFunc = Remotes.GetFunction("BuyShopItem")
    local getShopFunc = Remotes.GetFunction("GetShopStock")

    -- New Remotes
    local reloadFunc = Remotes.GetFunction("Reload")
    local meleeFunc = Remotes.GetFunction("PerformMelee")
    local equipGloveFunc = Remotes.GetFunction("EquipGlove")
    local buyGloveFunc = Remotes.GetFunction("BuyGlove")
    local equipKnifeFunc = Remotes.GetFunction("EquipKnife")
    local buyKnifeFunc = Remotes.GetFunction("BuyKnife")
    local equipTitleFunc = Remotes.GetFunction("EquipTitle")
    local claimTitleFunc = Remotes.GetFunction("ClaimTitle")
    local dismantleFunc = Remotes.GetFunction("DismantleItem")
    local forgeRerollFunc = Remotes.GetFunction("ForgeReroll")
    local forgeLevelUpFunc = Remotes.GetFunction("ForgeLevelUp")

    -- ==================== ANTI-CHEAT: shot & melee validation ====================
    -- The client decides what it hit (that's what keeps aiming instant), so the server double-checks
    -- every report is physically possible before any damage happens: fire rate, pellets/burst rounds per
    -- trigger pull, the enemy really being where the shot landed, range, and no wall in the way.
    -- Rejected reports are dropped quietly (the client's ammo/HUD is re-synced); the Player attributes
    -- RejectedHits / LastRejectReason make false positives easy to spot while play-testing.
    local HIT_POS_SLACK = 15    -- studs between the reported hit and the part's server position (enemies move; clients render slightly in the past)
    local MAX_SHOT_RANGE = 1010 -- client rays are 1000 studs
    local RATE_SLACK = 1.25     -- up to 25% over the weapon's fire rate (network jitter bunches shots together)
    local RATE_BURST = 3        -- ...and up to 3 shots arriving at once
    local FOLLOWUP_WINDOW = 0.6 -- shotgun pellets / burst rounds must arrive this soon after their trigger pull
    local MELEE_COOLDOWN = 0.3  -- the client swings at most every 0.35s
    local shotGuard: { [Player]: any } = setmetatable({}, { __mode = "k" }) :: any

    local function Guard(player: Player): any
        local g = shotGuard[player]
        if not g then
            g = { Tokens = RATE_BURST, LastRefill = os.clock(), PullAt = 0, FollowUps = 0, LastMelee = 0 }
            shotGuard[player] = g
        end
        return g
    end

    local function Reject(player: Player, reason: string)
        player:SetAttribute("RejectedHits", (player:GetAttribute("RejectedHits") or 0) + 1)
        player:SetAttribute("LastRejectReason", reason)
    end

    -- A new trigger pull: token bucket refilled at the weapon's fire rate (plus slack).
    local function AllowPull(player: Player, fireRate: number): boolean
        local g = Guard(player)
        local now = os.clock()
        g.Tokens = math.min(RATE_BURST, g.Tokens + (now - g.LastRefill) * math.max(0.5, fireRate) * RATE_SLACK)
        g.LastRefill = now
        if g.Tokens < 1 then return false end
        g.Tokens -= 1
        g.PullAt = now
        g.FollowUps = 0
        return true
    end

    -- Extra raycasts of the same pull (mirrors FireWeapon on the client: shotgun pellets, burst rounds).
    local function AllowFollowUp(player: Player, weapon: any): boolean
        local g = Guard(player)
        local extra = 0
        if weapon.Class == "Shotgun" then extra = (weapon.PelletCount or 8) - 1
        elseif weapon.Class == "Burst" then extra = (weapon.BurstCount or 3) - 1 end
        if os.clock() - g.PullAt > FOLLOWUP_WINDOW or g.FollowUps >= extra then return false end
        g.FollowUps += 1
        return true
    end

    -- Nothing solid between the player's head and the hit. Also tried from a little left/right/above the
    -- head, so a player stepping out from cover isn't rejected just because the server sees them a few
    -- frames behind.
    local function HasLineOfSight(player: Player, targetModel: Instance, hitPos: Vector3): boolean
        local char = player.Character
        local head = char and char:FindFirstChild("Head")
        if not head or not head:IsA("BasePart") then return false end
        local ignore: { Instance } = { targetModel }
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then table.insert(ignore, p.Character) end
        end
        for _, m in ipairs(CollectionService:GetTagged("AimRngEnemy")) do table.insert(ignore, m) end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = ignore
        local right = head.CFrame.RightVector
        for _, offset in ipairs({ Vector3.zero, right * 2.5, -right * 2.5, Vector3.new(0, 1.5, 0) }) do
            local origin = head.Position + offset
            local result = Workspace:Raycast(origin, hitPos - origin, params)
            if not result or (result.Position - hitPos).Magnitude < 2 then return true end
        end
        return false
    end


    getStateFunc.OnServerInvoke = function(player: Player)
        return CombatServer.GetState(player)
    end

    -- BACK PORTAL: after the client rebuilds a floor it asks for that floor's drops again
    Remotes.GetEvent("ResendGroundLoot").OnServerEvent:Connect(function(player: Player)
        local state = CombatServer.GetState(player)
        if type(state.PendingLoot) ~= "table" or not DungeonRuns.Get(player) then return end
        local floor = DungeonRuns.Attr(player, "Floor")
        for id, d in pairs(state.PendingLoot) do
            if type(d) == "table" and d.Floor == floor and type(d.Pos) == "table" then
                Remotes.GetEvent("LootDropped"):FireClient(player, id, d.Item, d.Kind or "Weapon", Vector3.new(d.Pos[1], d.Pos[2], d.Pos[3]))
            end
        end
    end)

    -- Ground loot pickup (proximity checked). (QOL L2 2026-10-28: one path for [E] and PICK UP ALL NEARBY: maxDist + a
    -- "full" result so the many-pickup stops at a full bag and says it once)
    local function TryPickup(player: Player, state: any, id: any, maxDist: number, quiet: boolean?): (boolean, string?)
        local d = type(id) == "string" and type(state.PendingLoot) == "table" and state.PendingLoot[id]
        if not d then return false end
        -- (every floor is built in the same spot: a drop waiting on another floor can't be picked up from this one)
        if d.Floor ~= nil and DungeonRuns.Get(player) and DungeonRuns.Attr(player, "Floor") ~= d.Floor then return false end
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local pos = Vector3.new(d.Pos[1], d.Pos[2], d.Pos[3])
        if not root or (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude > maxDist then return false end
        if (d.Kind or "Weapon") == "Gem" then -- (0.75, owner: "should not let you pick up gems if the bag is full")
            local gemCap = require(game.ReplicatedStorage.AimRngShared.StashTabs).GemCap(state) -- (UPDATE 7: + GEM tabs)
            if #(state.Gems or {}) >= gemCap then
                if not quiet then Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "GEM BAG FULL (" .. gemCap .. "): salvage gems at the Skill Tree to pick this up", Color3.fromRGB(255, 120, 90)) end
                return false, "gemfull"
            end
        elseif ItemData.BagRoom(state) <= 0 then
            if not quiet then Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "BAG FULL (" .. ItemData.BagCap(state) .. "): sell, dismantle or stash items to pick this up", Color3.fromRGB(255, 120, 90)) end
            return false, "full"
        end
        state.PendingLoot[id] = nil
        GrantLootItem(player, state, d.Item, d.Kind or "Weapon", true)
        Remotes.GetEvent("LootPicked"):FireClient(player, id)
        return true
    end
    Remotes.GetFunction("PickupLoot").OnServerInvoke = function(player: Player, id: any): boolean
        local state = CombatServer.GetState(player)
        local ok = TryPickup(player, state, id, 14)
        if ok then stateSync:FireClient(player, state) end
        return ok
    end
    -- QOL L2: PICK UP ALL NEARBY (Key_PickupAll). The client sends the ids it can see (Drop Rules' hidden ones are left out
    -- there); each goes through TryPickup with the radius checked here. Stops at a full bag. -> number picked up
    local PICKUP_ALL_DIST = 26 -- (the client's 24-stud radius + slack for movement while the call travels)
    Remotes.GetFunction("PickupLootMany").OnServerInvoke = function(player: Player, ids: any): number
        if type(ids) ~= "table" then return 0 end
        local state = CombatServer.GetState(player)
        local n, full, gemFull = 0, false, false
        for i = 1, math.min(#ids, 40) do
            local ok, why = TryPickup(player, state, ids[i], PICKUP_ALL_DIST, true)
            if ok then n += 1
            elseif why == "full" then full = true
            elseif why == "gemfull" then gemFull = true end
        end
        if n > 0 then stateSync:FireClient(player, state) end
        if full then
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "BAG FULL (" .. ItemData.BagCap(state) .. "): sell, dismantle or stash items to pick up the rest", Color3.fromRGB(255, 120, 90))
        elseif gemFull then
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "GEM BAG FULL: salvage gems at the Skill Tree to pick up the rest", Color3.fromRGB(255, 120, 90))
        end
        return n
    end

    -- Pick one of the offered run boons (1..3).
    Remotes.GetFunction("ChooseBoon").OnServerInvoke = function(player: Player, index: any): (boolean, string?)
        local BoonData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("BoonData"))
        local state = CombatServer.GetState(player)
        local offer = state.BoonOffer
        if type(index) ~= "number" or not offer or not offer[index] then return false, "No boon to pick." end
        local id = offer[index]
        state.RunBoons = state.RunBoons or {}
        table.insert(state.RunBoons, id)
        state.BoonOffer = nil
        CombatServer.ContractEvent(player, state, "BoonPick", 1)
        CombatServer.RecalculateMaxHealth(state)
        stateSync:FireClient(player, state)
        local b = BoonData.ById[id]
        return true, b and b.Name or id
    end

    -- Client settings: the client sends its whole settings table (debounced); it's saved with the player.
    Remotes.GetEvent("SaveSettings").OnServerEvent:Connect(function(player: Player, settings: any)
        local clean = SaveService.SanitizeSettings(settings)
        if clean and playerStates[player] then playerStates[player].Settings = clean end
    end)

    SaveService.Start(function(p) return playerStates[p] end, function(p) playerStates[p] = nil end)

    getShopFunc.OnServerInvoke = function(player: Player)
        local shop = EnsureShop(CombatServer.GetState(player))
        return shop.Items, ShopSecondsLeft(), CombatServer.SHOP_ODDS
    end

    buyShopFunc.OnServerInvoke = function(player: Player, itemUid: string): (boolean, string?)
        local state = CombatServer.GetState(player)
        local stock = EnsureShop(state).Items
        local targetIdx = nil
        local entry: ShopEntry? = nil
        for idx, e in ipairs(stock) do
            if e.Item.Uid == itemUid then
                targetIdx = idx
                entry = e
                break
            end
        end

        if not targetIdx or not entry then
            return false, "Item is no longer in stock!"
        end

        if state.Gold < entry.Price then
            return false, "Not enough Gold! Need " .. entry.Price .. " Gold."
        end
        if ItemData.BagRoom(state) <= 0 then return false, "Your bag is full (" .. ItemData.BagCap(state) .. "). Make room first." end

        state.Gold -= entry.Price
        if entry.Type == "Weapon" then
            local w = entry.Item :: ItemData.WeaponInstance
            state.StatsTracking.DiscoveredWeapons[w.BaseId] = true
            table.insert(state.Inventory, w)
            local comp = ItemData.CompareWeapons(w, state.EquippedWeapon)
            Remotes.GetEvent("LootAnnounce"):FireClient(player, w, comp, false)
        else
            table.insert(state.GearInventory, entry.Item :: ItemData.GearInstance)
            Remotes.GetEvent("LootAnnounce"):FireClient(player, entry.Item, nil, false)
        end

        table.remove(stock, targetIdx)
        stateSync:FireClient(player, state)
        return true, nil
    end

    -- Reload Handler
    reloadFunc.OnServerInvoke = function(player: Player, cmd: any): boolean
        local state = CombatServer.GetState(player)
        -- (2026-10-07: a reload can be cancelled by the melee: the magazine stays as it was)
        if cmd == "Cancel" then
            player:SetAttribute("ReloadAt", nil) -- (CharacterPoser: the reload gesture stops)
            if state.IsReloading then
                state.IsReloading = false
                ;(state :: any).ReloadToken = ((state :: any).ReloadToken or 0) + 1
                stateSync:FireClient(player, state)
            end
            return true
        end
        if state.IsReloading then return false end
        if state.CurrentMag >= state.MaxMag then return false end
        if not CombatServer.Zen.CanReload(state) then return false end -- (CHASE ITEMS: Furnace Heart never reloads)

        local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
        local baseReloadTime = state.EquippedWeapon.ReloadTime or 2.2
        local duration = math.max(0.6, baseReloadTime / stats.ReloadSpeed)

        state.IsReloading = true
        ;(state :: any).ReloadToken = ((state :: any).ReloadToken or 0) + 1
        local token = (state :: any).ReloadToken
        player:SetAttribute("ReloadFor", duration) -- (CharacterPoser: everyone sees the reload gesture)
        player:SetAttribute("ReloadAt", workspace:GetServerTimeNow())
        stateSync:FireClient(player, state)

        task.delay(duration, function()
            if player.Parent and state.IsReloading and (state :: any).ReloadToken == token then
                state.IsReloading = false
                state.CurrentMag = state.MaxMag
                ;(state :: any).ReloadedAt = os.clock() -- (FRESH LOAD: ReloadedDamage for a few seconds; not saved)
                for _, e in ipairs(stats.AscFx or {}) do -- ascendancy: finishing a reload (Regroup)
                    if e.Fx.Kind == "OnReload" and e.Fx.Effect == "Heal" then Asc.Heal(state, state.MaxHealth * (e.Fx.Value or 0)) end
                end
                Asc.Trigger(state, stats, "Reload")
                stateSync:FireClient(player, state)
            end
        end)

        return true
    end

    -- Melee Attack Handler
    local MeleeData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("MeleeData"))
    -- kind: "Light" / "Heavy" (melee slot out) or "Quick" ([V] from the gun; nil = Quick for old clients)
    meleeFunc.OnServerInvoke = function(player: Player, kind: any): boolean
        local g = Guard(player)
        local now = os.clock()
        kind = (kind == "Light" or kind == "Heavy") and kind or "Quick"
        if now - (g.SwingSent or 0) > 0.15 then -- (CharacterPoser: the swing for everyone else)
            g.SwingSent = now
            player:SetAttribute("SwingKind", kind)
            player:SetAttribute("SwingAt", workspace:GetServerTimeNow())
        end
        if CombatServer.InSafeRoom(player) then return false end -- no attacking out of the safe zone
        local atk = MeleeData.Attacks[kind]
        local stateEarly = CombatServer.GetState(player)
        local kdEarly = ItemData.MeleeWeapons[stateEarly.EquippedKnife] or ItemData.MeleeWeapons.Knife
        -- each attack has its own pace (by the melee's AttackRate); 15% slack for network jitter
        local minGap = math.max(MELEE_COOLDOWN * 0.5, atk.Interval / math.max(0.3, kdEarly.AttackRate or 1) * 0.85)
        if now - g.LastMelee < minGap then
            Reject(player, "melee spam")
            return false
        end
        g.LastMelee = now
        local state = CombatServer.GetState(player)
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return false end
        local hrp = char.HumanoidRootPart :: BasePart

        local knifeData = ItemData.MeleeWeapons[state.EquippedKnife] or ItemData.MeleeWeapons.Knife
        local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)

        local isCrit = (math.random() < knifeData.CritChance)
        -- Melee scales with your level (StatCalculator.MeleeDamage); each blade is a multiplier on it.
        local rawDmg = (stats.MeleeDamage or 12) * ((knifeData.BaseDamage or 90) / 90) * atk.Mult * (isCrit and knifeData.CritMultiplier or 1.0)
        local dmg = math.max(1, math.round(rawDmg * 10) / 10)

        Remotes.GetEvent("MeleeSlash"):FireClient(player)

        -- Hit check against the player's own dungeon foes in a frontal cone
        local meleeTargets = DungeonRuns.EnemiesOf(player)
        local prun = PartyRuns.RunOfPlayer(player)
        if prun and prun.Folder then
            for _, m in ipairs(prun.Folder:GetChildren()) do
                if m:IsA("Model") and (m:GetAttribute("Health") or 0) > 0 and not m:GetAttribute("Dead") then table.insert(meleeTargets, m) end
            end
        end
        -- hub practice targets (training dummies, the DPS test) take melee hits too
        local hubWorld = workspace:FindFirstChild("HubWorld")
        if hubWorld and hrp.Position.Z < 450 then
            for _, m in ipairs(game:GetService("CollectionService"):GetTagged("AimRngEnemy")) do
                if m:IsDescendantOf(hubWorld) and (m:GetAttribute("Health") or 0) > 0 then table.insert(meleeTargets, m) end
            end
        end
        -- facing check: the body's flat look direction (the camera turns the body every frame)
        for _, child in ipairs(meleeTargets) do
            local pos = EnemyRootPos(child)
            if pos then
                local toTarget = pos - hrp.Position
                local reach = (knifeData.Range or 9) + atk.RangeBonus + (child:GetAttribute("HitRadius") or 2)
                local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
                local facing = flat.Magnitude > 0.01 and hrp.CFrame.LookVector:Dot(flat.Unit) or 1
                if toTarget.Magnitude <= reach and toTarget.Magnitude > 0.01 and facing > atk.Arc then
                    -- Same pipeline as every other damage source (debuffs, health bar, kill/loot/room-clear).
                    local _, killed = DealEnemyDamage(player, state, child, dmg, stats, { Kind = "Melee", IsCrit = isCrit, Position = pos })
                    if killed then state.StatsTracking.MeleeKills += 1 end
                end
            end
        end

        stateSync:FireClient(player, state)
        return true
    end

    -- Melee skins: equip an owned skin on a melee (MeleeData.Skins; "Factory" is always owned)
    Remotes.GetFunction("EquipMeleeSkin").OnServerInvoke = function(player: Player, meleeId: any, skinId: any): boolean
        local state = CombatServer.GetState(player)
        if type(meleeId) ~= "string" or type(skinId) ~= "string" then return false end
        if not ItemData.MeleeWeapons[meleeId] or not MeleeData.Skins[skinId] then return false end
        if not MeleeData.Owns(state, skinId) then return false end
        state.MeleeSkinFor = type(state.MeleeSkinFor) == "table" and state.MeleeSkinFor or {}
        state.MeleeSkinFor[meleeId] = skinId
        stateSync:FireClient(player, state)
        return true
    end

    -- Cosmetics Handlers
    equipGloveFunc.OnServerInvoke = function(player: Player, gloveId: string): boolean
        local state = CombatServer.GetState(player)
        for _, g in ipairs(state.GloveInventory) do
            if g == gloveId then
                state.EquippedGlove = gloveId
                stateSync:FireClient(player, state)
                return true
            end
        end
        return false
    end

    buyGloveFunc.OnServerInvoke = function(player: Player, gloveId: string): (boolean, string?)
        local state = CombatServer.GetState(player)
        local gData = ItemData.Gloves[gloveId]
        if not gData then return false, "Glove not found!" end
        if gData.DropOnly then return false, "This glove only drops from " .. (gData.DropSource or "enemies") .. "!" end
        for _, g in ipairs(state.GloveInventory) do
            if g == gloveId then return false, "Already owned!" end
        end
        if state.Gold < gData.CostGold or state.UpgradeShards < gData.CostShards then
            return false, "Not enough Gold or Shards!"
        end

        state.Gold -= gData.CostGold
        state.UpgradeShards -= gData.CostShards
        table.insert(state.GloveInventory, gloveId)
        state.EquippedGlove = gloveId
        stateSync:FireClient(player, state)
        return true, nil
    end

    -- Generic equip for drop-able cosmetics (gloves, sleeves, weapon finishes) -- must already be owned.
    Remotes.GetFunction("EquipCosmetic").OnServerInvoke = function(player: Player, kind: string, id: string): boolean
        local state = CombatServer.GetState(player)
        local field = COSMETIC_INVENTORY_FIELD[kind]
        if not field or type(id) ~= "string" then return false end
        local inv = (state :: any)[field]
        if not inv or not table.find(inv, id) then return false end
        if kind == "Glove" then state.EquippedGlove = id
        elseif kind == "Sleeve" then state.EquippedSleeve = id
        else state.EquippedWeaponSkin = id end
        stateSync:FireClient(player, state)
        return true
    end

    equipKnifeFunc.OnServerInvoke = function(player: Player, knifeId: string): boolean
        local state = CombatServer.GetState(player)
        if not ItemData.IsActiveMelee(knifeId) then return false end
        for _, k in ipairs(state.KnifeInventory) do
            if k == knifeId then
                state.EquippedKnife = knifeId
                stateSync:FireClient(player, state)
                return true
            end
        end
        return false
    end

    buyKnifeFunc.OnServerInvoke = function(player: Player, knifeId: string): (boolean, string?)
        local state = CombatServer.GetState(player)
        local kData = ItemData.MeleeWeapons[knifeId]
        if not kData or not ItemData.IsActiveMelee(knifeId) then return false, "Knife not found!" end
        for _, k in ipairs(state.KnifeInventory) do
            if k == knifeId then return false, "Already owned!" end
        end
        if state.Gold < kData.CostGold or state.UpgradeShards < kData.CostShards then
            return false, "Not enough Gold or Shards!"
        end

        state.Gold -= kData.CostGold
        state.UpgradeShards -= kData.CostShards
        table.insert(state.KnifeInventory, knifeId)
        state.EquippedKnife = knifeId
        stateSync:FireClient(player, state)
        return true, nil
    end

    -- Title Handlers
    equipTitleFunc.OnServerInvoke = function(player: Player, titleId: string): boolean
        local state = CombatServer.GetState(player)
        for _, t in ipairs(state.UnlockedTitles) do
            if t == titleId then
                state.EquippedTitle = titleId
                CombatServer.RecalculateMaxHealth(state)
                CombatServer.UpdatePlayerTitleTag(player)
                stateSync:FireClient(player, state)
                return true
            end
        end
        return false
    end

    claimTitleFunc.OnServerInvoke = function(player: Player, titleId: string): (boolean, string?)
        local state = CombatServer.GetState(player)
        local tData = ItemData.Titles[titleId]
        if not tData then return false, "Title not found!" end
        for _, t in ipairs(state.UnlockedTitles) do
            if t == titleId then return false, "Already claimed!" end
        end

        -- Revamped verification: each check now matches EXACTLY what its Title.Requirement text says
        -- (the old checks were disconnected proxies -- e.g. "Clear Floor 3" used to just check Level,
        -- "Land 20 Headshots" checked a completely different number -- which is why claiming titles
        -- felt arbitrary). RarityRank/GearRarityAtLeast mirror the client's CheckTitleRequirement so
        -- the Titles menu's claim button can predict this exactly (grey vs. lit-up yellow).
        if tData.Retired then return false, "That title has been retired." end
        local canClaim = ItemData.TitleProgress(titleId, state)
        if not canClaim then
            return false, "Requirement not yet completed: " .. tData.Requirement
        end

        table.insert(state.UnlockedTitles, titleId)
        state.Gold += tData.RewardGold or 0
        state.Materials = state.Materials or ItemData.NewMaterials()
        for mat, n in pairs(tData.RewardMats or {}) do
            if not ItemData.RETIRED_MATERIALS[mat] then state.Materials[mat] = (state.Materials[mat] or 0) + n end
        end
        state.EquippedTitle = titleId
        CombatServer.RecalculateMaxHealth(state)
        CombatServer.UpdatePlayerTitleTag(player)
        stateSync:FireClient(player, state)
        return true, nil
    end

    -- (owner 2026-10-05: "the game lags when spam adding into attributes. Add a little box to input how many"): amount =
    -- how many points at once (the panel's box), capped at what you have -- one state sync however many
    allocStatFunc.OnServerInvoke = function(player: Player, statName: string, amount: any): boolean
        local state = CombatServer.GetState(player)
        if true then return false end -- (UPDATE 8 OFFENSE phase 4: no hand-placed attributes; tree + gear only)
        if state.StatPoints <= 0 then return false end
        local n = math.clamp(math.floor(tonumber(amount) or 1), 1, state.StatPoints)

        if statName == "Strength" or statName == "Dexterity" or statName == "Vitality" or statName == "Luck" then
            state.StatPoints -= n
            state.Attributes[statName] = (state.Attributes[statName] or 0) + n
            CombatServer.RecalculateMaxHealth(state)
            stateSync:FireClient(player, state)
            return true
        end
        return false
    end

    -- (owner 2026-10-04: "we also need a way to reset attributes"): free; every point above the base 5 comes back
    Remotes.GetFunction("ResetAttributes").OnServerInvoke = function(player: Player): (boolean, number)
        local state = CombatServer.GetState(player)
        if true then return false, 0 end -- (UPDATE 8 OFFENSE phase 4: nothing to reset)
        if not state or type(state.Attributes) ~= "table" then return false, 0 end
        local back = 0
        for _, n in ipairs({ "Strength", "Dexterity", "Vitality", "Luck" }) do
            local v = tonumber(state.Attributes[n]) or 5
            if v > 5 then back += v - 5; state.Attributes[n] = 5 end
        end
        if back <= 0 then return false, 0 end
        state.StatPoints = (state.StatPoints or 0) + back
        CombatServer.RecalculateMaxHealth(state)
        stateSync:FireClient(player, state)
        return true, back
    end

    equipGearFunc.OnServerInvoke = function(player: Player, gearUid: string, targetSlot: string?): boolean
        local state = CombatServer.GetState(player)
        local targetIdx = nil
        local targetGear = nil
        for idx, g in ipairs(state.GearInventory) do
            if g.Uid == gearUid then
                targetIdx = idx; targetGear = g; break
            end
        end

        if not targetIdx or not targetGear then return false end
        if not ItemData.CanEquipLevel(targetGear, state.Level) then
            Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "Requires level " .. ItemData.RequiredLevel(targetGear) .. " to equip", Color3.fromRGB(255, 120, 110))
            return false
        end
        do -- (UPDATE 8 phase 4: attribute requirements)
            local ok, why = CombatServer.Off.ReqOk(state, targetGear)
            if not ok then Remotes.GetEvent("CombatFx"):FireClient(player, "Text", (why or "Needs more attributes") .. " to equip", Color3.fromRGB(255, 120, 110)); return false end
        end

        -- Rings are one item type that fits either ring slot: use the requested ring slot if given,
        -- otherwise the first empty one, otherwise replace Ring 1.
        local gearType = ItemData.GearType(targetGear.Slot)
        targetGear.Slot = gearType
        local slot = gearType
        if gearType == "Ring" then
            if targetSlot == "Ring1" or targetSlot == "Ring2" then
                slot = targetSlot
            elseif not state.EquippedGear.Ring1 then
                slot = "Ring1"
            elseif not state.EquippedGear.Ring2 then
                slot = "Ring2"
            else
                slot = "Ring1"
            end
        end
        local oldGear = state.EquippedGear[slot]
        -- EXOTICS (0.53): one exotic gear piece at a time (swapping onto the same slot is fine)
        if targetGear.Exotic then -- (UPDATE 8 LOOT: up to ItemData.RELIC_GEAR_MAX relic pieces -- 8 = no limit)
            local worn = 0
            for s2, g2 in pairs(state.EquippedGear) do if g2 and g2.Exotic and s2 ~= slot then worn += 1 end end
            for s2, g2 in pairs(state.EquippedGear) do
                if g2 and g2.Exotic and s2 ~= slot and worn >= (ItemData.RELIC_GEAR_MAX or 1) then
                    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "Only one relic gear piece at a time (" .. tostring(g2.Name) .. " is worn)", Color3.fromRGB(255, 150, 40))
                    return false
                end
            end
        end

        table.remove(state.GearInventory, targetIdx)
        if oldGear then
            table.insert(state.GearInventory, oldGear)
        end
        state.EquippedGear[slot] = targetGear

        CombatServer.RecalculateMaxHealth(state)
        stateSync:FireClient(player, state)
        return true
    end

    unequipGearFunc.OnServerInvoke = function(player: Player, slotName: string): boolean
        local state = CombatServer.GetState(player)
        local curr = state.EquippedGear[slotName]
        if curr then
            state.EquippedGear[slotName] = nil :: any
            table.insert(state.GearInventory, curr)
            CombatServer.RecalculateMaxHealth(state)
            stateSync:FireClient(player, state)
            return true
        end
        return false
    end

    -- (owner 2026-11-06) a ZENITH sells / dismantles only with the client's confirm flag (zenOk = true after the "Sell ZENITH <name>?"
    -- popup, ZenithClient.SellAsk): a client can't skip the question. Bulk sell never touches Zeniths.
    sellGearFunc.OnServerInvoke = function(player: Player, gearUid: string, zenOk: any): (boolean, number)
        local state = CombatServer.GetState(player)
        for idx, g in ipairs(state.GearInventory) do
            if g.Uid == gearUid then
                if g.Locked then return false, 0 end -- (0.76 item lock)
                if ItemData.ZenithOf(g) and zenOk ~= true then return false, 0 end -- (Zenith: confirm first)
                local val = ItemData.GetGearSellValue(g)
                table.remove(state.GearInventory, idx)
                state.Gold += val
                CombatServer.Buyback.Add(player, g, "Gear", val) -- (QOL2 I3)
                stateSync:FireClient(player, state)
                return true, val
            end
        end
        return false, 0
    end

    sellFunc.OnServerInvoke = function(player: Player, weaponUid: string, zenOk: any): (boolean, number)
        local state = CombatServer.GetState(player)
        if state.EquippedWeapon.Uid == weaponUid then return false, 0 end

        for idx, w in ipairs(state.Inventory) do
            if w.Uid == weaponUid then
                if w.Locked then return false, 0 end -- (0.76 item lock)
                if ItemData.ZenithOf(w) and zenOk ~= true then return false, 0 end -- (Zenith: confirm first)
                CombatServer.Off.ReturnMods(state, w) -- (UPDATE 8 OFFENSE phase 3: its shot mods back to the bag)
                local gVal = ItemData.GetSellValue(w)
                table.remove(state.Inventory, idx)
                state.Gold += gVal
                CombatServer.Buyback.Add(player, w, "Weapon", gVal) -- (QOL2 I3)
                stateSync:FireClient(player, state)
                return true, gVal
            end
        end
        return false, 0
    end

    quickSellFunc.OnServerInvoke = function(player: Player, rarityTarget: string, scope: string?): (number, number)
        local state = CombatServer.GetState(player)
        local count = 0
        local totalGold = 0
        if type(rarityTarget) ~= "string" or not RarityRank[rarityTarget] then return 0, 0 end
        -- (0.58) scope "AllUpTo": weapons + gear AT OR BELOW the rarity (the SELL UP TO picker); "All": exactly that rarity
        local upTo = scope == "AllUpTo"
        local cap = RarityRank[rarityTarget]
        local function Match(r: string?): boolean
            if upTo then return (RarityRank[r or ""] or 99) <= cap end
            return r == rarityTarget
        end

        -- "All" also sells unequipped gear of that rarity (equipped gear lives in EquippedGear, not here).
        if (scope == "All" or upTo) and state.GearInventory then
            local keepGear = {}
            for _, g in ipairs(state.GearInventory) do
                if Match(g.Rarity) and not (upTo and g.Exotic) and not g.Locked and not ItemData.ZenithOf(g) then -- (exotics / locked items are never bulk-sold; Zeniths in no scope)
                    local gv = ItemData.GetGearSellValue(g)
                    totalGold += gv
                    count += 1
                    CombatServer.Buyback.Add(player, g, "Gear", gv) -- (QOL2 I3: the last 10 of a bulk sell)
                else
                    table.insert(keepGear, g)
                end
            end
            state.GearInventory = keepGear
        end

        local keepInventory = {}
        for _, w in ipairs(state.Inventory) do
            if w.Uid ~= state.EquippedWeapon.Uid and Match(w.Rarity) and not (upTo and w.Exotic) and not w.Locked and not ItemData.ZenithOf(w) then
                CombatServer.Off.ReturnMods(state, w) -- (UPDATE 8 OFFENSE phase 3)
                local g = ItemData.GetSellValue(w)
                totalGold += g
                count += 1
                CombatServer.Buyback.Add(player, w, "Weapon", g) -- (QOL2 I3)
            else
                table.insert(keepInventory, w)
            end
        end

        state.Inventory = keepInventory
        state.Gold += totalGold

        stateSync:FireClient(player, state)
        return count, totalGold
    end

    -- ITEM LOCK (0.76, owner: "Add a lock item feature"): a locked weapon / gear piece / gem can't be sold (one by one or
    -- in bulk), dismantled or salvaged until it's unlocked. (Upgrades, crafting and trading still work.)
    Remotes.GetFunction("ToggleItemLock").OnServerInvoke = function(player: Player, uid: any): (boolean, boolean?)
        local state = CombatServer.GetState(player)
        if type(uid) ~= "string" or not state then return false end
        local lists = { state.Inventory or {}, state.GearInventory or {}, state.Gems or {} }
        local found = nil
        for _, list in ipairs(lists) do for _, it in ipairs(list) do if it.Uid == uid then found = it end end end
        if not found and state.EquippedWeapon and state.EquippedWeapon.Uid == uid then found = state.EquippedWeapon end
        if not found then for _, g in pairs(state.EquippedGear or {}) do if type(g) == "table" and g.Uid == uid then found = g end end end
        if not found then for _, g in pairs(state.SocketedGems or {}) do if type(g) == "table" and g.Uid == uid then found = g end end end
        if not found then return false end
        found.Locked = (not found.Locked) or nil
        stateSync:FireClient(player, state)
        return true, found.Locked == true
    end
    Remotes.GetFunction("SetGemAutoSalvage").OnServerInvoke = function(player: Player, threshold: any): boolean
        local state = CombatServer.GetState(player)
        if threshold ~= "OFF" and not (threshold == "Common" or threshold == "Uncommon" or threshold == "Rare" or threshold == "Mythic") then return false end
        state.GemAutoSalvage = threshold -- (UPDATE 8 GEM GRADES v4: up to Mythic; Relic gems are never auto-salvaged)
        state.GemSalvageV4 = true
        stateSync:FireClient(player, state)
        return true
    end
    autoSellFunc.OnServerInvoke = function(player: Player, threshold: string, rules: any): boolean
        local state = CombatServer.GetState(player)
        if not state then return false end
        -- (0.58: any rarity up to Genesis, rank 14 -- the client confirms from Legendary up; never Infinite)
        -- (RARITY v4: up to Mythic; Relics are never auto-sold; old names refused)
        if threshold ~= "OFF" and not (type(threshold) == "string" and rawget(RarityRank, threshold) and RarityRank[threshold] <= RarityRank.Mythic) then return false end
        state.AutoSellThreshold = threshold
        -- (2026-11-09 AUTO-SELL FILTER) the panel's KEEP rules: any table is cleaned (known ids only, clamped, capped); nil = unchanged
        if rules ~= nil then
            local okR, r = pcall(AutoSellRules.Clean, rules)
            state.AutoSellRules = okR and r or nil
        end
        stateSync:FireClient(player, state)
        return true
    end

    -- The Forge roll: ONE free roll per day (UTC day), a gun at your level with normal drop odds (no Mythics).
    -- (fixes 2026-10-16 #9, playtester: "free daily roll should guarantee something very rare/valuable"; owner: a guaranteed
    -- rare currency stack): every daily roll also pays a PRISM SHARD stack (the rare currency: +13..+20 upgrades + affix
    -- rerolls) that grows with level like the reroll price does -- 10 x (1 + level / 25): ~10 at Lv1, 50 at 100, 170 at
    -- 400 -- and 1 roll in 10 is a TRIPLE stack. Raw: no quantity / CRAFT_SOURCE_MULT scaling.
    ItemData.DAILY_ROLL_PRISM = { Base = (ItemData.LOOT_SCARCITY and ItemData.LOOT_SCARCITY.ON and ItemData.LOOT_SCARCITY.DailyPrism) or 10, Jackpot = 0.1, JackpotMult = 3 } -- (LOOT SCARCITY: was Base 10)
    CombatServer.DailyRoll = function(player: Player): (ItemData.WeaponInstance?, ItemData.WeaponComparison?, string?, boolean?, number?, boolean?) -- (+ DevCmd "dailyroll")
        local state = CombatServer.GetState(player)
        local day = os.time() // 86400
        if (state.LastDailyRoll or 0) >= day then
            local secs = (day + 1) * 86400 - os.time()
            return nil, nil, string.format("Today's free roll is used. Next one in %dh %02dm.", secs // 3600, (secs % 3600) // 60), false
        end
        state.LastDailyRoll = day
        state.RollsCount += 1

        local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
        local newWeapon = ItemData.GenerateRandomWeapon(nil, stats.LuckMultiplier, state.Level, ItemData.TierForLevel(state.Level)) -- (RARITY v4: that tier's cap + area)
        state.StatsTracking.DiscoveredWeapons[newWeapon.BaseId] = true
        table.insert(state.Inventory, newWeapon)
        local comp = ItemData.CompareWeapons(newWeapon, state.EquippedWeapon)
        local dp = ItemData.DAILY_ROLL_PRISM
        local jackpot = math.random() < dp.Jackpot
        local prism = math.round(dp.Base * (1 + (state.Level or 1) / ItemData.REROLL_LEVEL_DIV) * (jackpot and dp.JackpotMult or 1))
        local gift = { Prism = prism }
        -- (UPDATE 7 CRAFTING v5, Loot Economy Plan: "the free daily roll gives a guaranteed stack of the rarer currencies you've
        -- unlocked") + one of the unlocked v5 currencies at random: 1 (2 from level 100, x3 on a jackpot)
        local unlocked = {}
        for _, k in ipairs(ItemData.CURRENCY_V5) do if ItemData.CurrencyRolls(k, state.Level) then table.insert(unlocked, k) end end
        if #unlocked > 0 then
            local k = unlocked[math.random(1, #unlocked)]
            gift[k] = ((state.Level or 1) >= 100 and 2 or 1) * (jackpot and dp.JackpotMult or 1)
        end
        GrantMaterials(player, state, gift, nil, true)
        stateSync:FireClient(player, state)
        return newWeapon, comp, nil, false, prism, jackpot
    end
    rollFunc.OnServerInvoke = CombatServer.DailyRoll

    -- EQUIP BEST (stash button): scores whole loadouts with the real StatCalculator, so every affix, the passive
    -- tree, gems and gear sets count -- not just item level. Primary = DPS (damage x fire rate x pellets x burst,
    -- crit-averaged); a loadout must beat the current best by 0.5% DPS to win, otherwise the tougher one wins
    -- (effective HP = max HP / (1 - damage reduction)), then rarity, then item level.
    local RANK = RarityRank
    -- BUILD PRESETS (the dropdown): each one only changes what "best" means --
    --   DPS   = DPS first, toughness breaks ties
    --   Tank  = effective HP first, DPS breaks ties
    --   Burn / Freeze / Bleed / Decay = DPS weighted by how reliably and how hard you apply that ailment
    --           (matching weapon prefix's proc chance, the tree's on-hit chance, the ailment's damage / effect and
    --           duration) -- with no source at all it falls back to plain DPS
    --   Crit  = DPS weighted by crit chance x crit multiplier
    -- (QOL2 I4 2026-10-28: the score lives in AimRngShared/LoadoutScore -- the client's gear upgrade signal uses the same one)
    CombatServer.LS = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("LoadoutScore"))
    local ELEMENT = CombatServer.LS.ELEMENT
    local function AilmentChanceOf(mode: string, weapon: any, s: any): number
        return CombatServer.LS.AilmentChance(mode, weapon, s)
    end
    local buildMode = "DPS"
    -- EQUIP BEST v2 (owner 2026-10-05: "If I spam equip best for any slot, it changes every time. There should only be 1
    -- solution. Make sure equip best somewhat accounts for HP / armor, as it shouldn't equip best and put on level one
    -- gear that simply has 1% better proc chance"):
    --   * ONE SCORE per loadout: offence^0.75 x toughness^0.25 (Tank: the other way round). Toughness = effective HP
    --     (max HP / (1 - damage reduction)), so a big HP / armour drop now costs more than a sliver of proc chance gains.
    --     (v1 compared DPS first and only looked at HP inside a 0.5% DPS tie.)
    --   * DETERMINISTIC: it starts from the same baseline every time (best gun with no gear), never from what you wear,
    --     and repeats passes until nothing changes; ties go to rarity, item level, then the item id. Live buffs (ascendancy
    --     stacks, grapple) are left out while scoring, so the clock can't change the answer.
    local function Score(state: any, weapon: any, gear: any): number
        -- (UPDATE 8 GEAR v3: toughness counts Plating, resists at your difficulty, Agility and Ward -- StatCalculator.Toughness)
        return CombatServer.LS.Score(state, weapon, gear, buildMode, CombatServer._EqDiff)
    end
    local function PlainDps(state: any, weapon: any, gear: any): (number, any)
        local s = StatCalculator.Calculate(weapon, state.AllocatedNodes, 0, state.Level, state.Attributes, gear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
        return s.Damage * s.FireRate * math.max(1, s.PelletCount or 1) * math.max(1, s.BurstCount or 1) * (1 + s.CritChance * (s.CritMultiplier - 1)), s
    end
    local function Better(scA: number, itemA: any, scB: number, itemB: any): boolean -- is A better than B? (a strict order)
        if math.abs(scA - scB) > 1e-9 * math.max(1, math.abs(scB)) then return scA > scB end
        local ra, rb = RANK[itemA and itemA.Rarity or ""] or 0, RANK[itemB and itemB.Rarity or ""] or 0
        if ra ~= rb then return ra > rb end
        local la, lb = (itemA and itemA.ItemLevel or 0), (itemB and itemB.ItemLevel or 0)
        if la ~= lb then return la > lb end
        return tostring(itemA and itemA.Uid or "") > tostring(itemB and itemB.Uid or "")
    end
    local MODE_NAME = { DPS = "MAX DPS", Tank = "TANK", Burn = "BURN", Freeze = "FREEZE", Bleed = "BLEED", Decay = "DECAY", Crit = "CRIT" }
    Remotes.GetFunction("EquipBest").OnServerInvoke = function(player: Player, mode: any): (boolean, string)
        buildMode = MODE_NAME[mode] and mode or "DPS"
        local state = CombatServer.GetState(player)
        CombatServer._EqDiff = CurrentDifficulty(player, state) -- (UPDATE 8 GEAR v3: Score's toughness reads resists at this difficulty)
        -- scoring copy: no live (timed) buffs
        local sstate = table.clone(state)
        ;(sstate :: any).AscBuffs = nil
        ;(sstate :: any).GrappleBuff = nil
        -- every owned gear piece (equipped + stash), in a fixed order (by id)
        local pool = {}
        for _, g in pairs(state.EquippedGear) do if type(g) == "table" then table.insert(pool, g) end end
        -- (ITEM LEVEL REQUIREMENT: only what you can equip at your level -- or already wear)
        for _, g in ipairs(state.GearInventory) do if ItemData.CanEquipLevel(g, state.Level) and CombatServer.Off.ReqOk(state, g) then table.insert(pool, g) end end
        table.sort(pool, function(a, b) return tostring(a.Uid or "") < tostring(b.Uid or "") end)
        -- (0.61, owner: "Equip best should only account for guns that match your class"): with a class, only guns of its
        -- weapon group are candidates (ClassData.Group); the gun in your hand stays a candidate only if it matches too.
        -- No class yet / no matching gun owned: every gun, as before.
        local ClassData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ClassData"))
        local group = ClassData.GroupOf(state.Class)
        local function Fits(w) return group == nil or ItemData.WeaponGroupOf(w) == group end
        local guns = {}
        if state.EquippedWeapon and Fits(state.EquippedWeapon) then table.insert(guns, state.EquippedWeapon) end
        for _, w in ipairs(state.Inventory) do if w ~= state.EquippedWeapon and ItemData.CanEquipLevel(w, state.Level) and CombatServer.Off.ReqOk(state, w) and Fits(w) then table.insert(guns, w) end end
        if #guns == 0 then
            if state.EquippedWeapon then table.insert(guns, state.EquippedWeapon) end
            for _, w in ipairs(state.Inventory) do if w ~= state.EquippedWeapon and ItemData.CanEquipLevel(w, state.Level) and CombatServer.Off.ReqOk(state, w) then table.insert(guns, w) end end
        end
        table.sort(guns, function(a, b) return tostring(a.Uid or "") < tostring(b.Uid or "") end)
        local changes = 0
        local gear: { [string]: any } = {} -- (baseline: nothing worn)
        local weapon = nil
        local function PickWeapon()
            local best, bs = nil, -math.huge
            for _, w in ipairs(guns) do
                local sc = Score(sstate, w, gear)
                if best == nil or Better(sc, w, bs, best) then best, bs = w, sc end
            end
            return best
        end
        weapon = PickWeapon() or state.EquippedWeapon
        for _pass = 1, 5 do -- (until it settles: a new gun can change which gear is best, and back)
            local moved = false
            for _, slot in ipairs(ItemData.GEAR_EQUIP_SLOTS) do -- (UPDATE 8: + Gloves)
                local want = ItemData.GearType(slot)
                local other = (slot == "Ring1" and gear.Ring2) or (slot == "Ring2" and gear.Ring1)
                local trial = table.clone(gear)
                trial[slot] = nil
                local bestItem, bestSc = nil, Score(sstate, weapon, trial) -- (an empty slot only wins if every piece is worse)
                local exoElsewhere = false -- (EXOTICS: one exotic gear piece at a time)
                local worn = 0
                for s2, g2 in pairs(trial) do if s2 ~= slot and g2 and g2.Exotic then worn += 1 end end
                exoElsewhere = worn >= (ItemData.RELIC_GEAR_MAX or 1) -- (UPDATE 8 LOOT: RELIC_GEAR_MAX)
                for _, g in ipairs(pool) do
                    if ItemData.GearType(g.Slot) == want and g ~= other and not (g.Exotic and exoElsewhere) then
                        trial[slot] = g
                        local sc = Score(sstate, weapon, trial)
                        if Better(sc, g, bestSc, bestItem) then bestItem, bestSc = g, sc end
                    end
                end
                if gear[slot] ~= bestItem then gear[slot] = bestItem; moved = true end
            end
            local w2 = PickWeapon()
            if w2 and w2 ~= weapon then weapon = w2; moved = true end
            if not moved then break end
        end
        -- the two rings are one choice: keep them where they already sit (no swap counted as a change)
        if gear.Ring1 and gear.Ring2 and gear.Ring1 == state.EquippedGear.Ring2 and gear.Ring2 == state.EquippedGear.Ring1 then
            gear.Ring1, gear.Ring2 = gear.Ring2, gear.Ring1
        end
        -- apply: weapon, then rebuild the gear stash from the pool
        local weaponChanged = weapon ~= nil and weapon ~= state.EquippedWeapon
        if weaponChanged then
            local mags = (state :: any).MagByUid or {}
            ;(state :: any).MagByUid = mags
            if state.EquippedWeapon then mags[state.EquippedWeapon.Uid] = state.IsReloading and 0 or state.CurrentMag end
            state.EquippedWeapon = weapon
            state.IsReloading = false
            state.Streak = 0
            changes += 1
        end
        local equippedSet = {}
        for slot, g in pairs(gear) do
            equippedSet[g] = true
            if state.EquippedGear[slot] ~= g then changes += 1 end
        end
        for slot, g in pairs(state.EquippedGear) do if gear[slot] == nil and g then changes += 1 end end
        local newInv = {}
        for _, g in ipairs(pool) do if not equippedSet[g] then table.insert(newInv, g) end end
        state.EquippedGear = gear
        state.GearInventory = newInv
        CombatServer.RecalculateMaxHealth(state)
        -- (2026-10-14, owner: "equipping best reloads the gun and can be abused"): the SAME gun keeps its rounds (and its
        -- reload); a new one takes what it had when last held (the normal swap rule) -- it used to refill every press
        if weaponChanged then
            local mags = (state :: any).MagByUid or {}
            state.CurrentMag = math.min(state.MaxMag, mags[weapon.Uid] or state.MaxMag)
        else
            state.CurrentMag = math.min(state.MaxMag, state.CurrentMag or state.MaxMag)
        end
        stateSync:FireClient(player, state)
        local d, s = PlainDps(state, state.EquippedWeapon, state.EquippedGear)
        local label = MODE_NAME[buildMode]
        local extra = ""
        if ELEMENT[buildMode] then
            local c = AilmentChanceOf(buildMode, state.EquippedWeapon, s)
            extra = c > 0 and string.format(" | %d%% %s chance", math.round(c * 100), string.lower(buildMode))
                or (" | no " .. string.lower(buildMode) .. " items yet, equipped max DPS")
        elseif buildMode == "Tank" then
            extra = " | " .. ItemData.FormatNumber(s.MaxHP) .. " HP, " .. math.round((s.DamageReduction or 0) * 100) .. "% DR"
        elseif buildMode == "Crit" then
            extra = string.format(" | %d%% crit, x%.1f", math.round(s.CritChance * 100), s.CritMultiplier)
        end
        if changes == 0 then return true, label .. ": you're already using your best gear for this build" .. extra end
        return true, string.format("%s: %d change%s, %s DPS%s", label, changes, changes == 1 and "" or "s", ItemData.FormatNumber(d), extra)
    end

    equipFunc.OnServerInvoke = function(player: Player, weaponUid: string): boolean
        local state = CombatServer.GetState(player)
        if state.EquippedWeapon and state.EquippedWeapon.Uid == weaponUid then return true end -- already in hand
        for _, w in ipairs(state.Inventory) do
            if w.Uid == weaponUid then
                if not ItemData.CanEquipLevel(w, state.Level) then -- (ITEM LEVEL REQUIREMENT)
                    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "Requires level " .. ItemData.RequiredLevel(w) .. " to equip", Color3.fromRGB(255, 120, 110))
                    return false
                end
                do -- (UPDATE 8 phase 4: attribute requirements)
                    local ok, why = CombatServer.Off.ReqOk(state, w)
                    if not ok then Remotes.GetEvent("CombatFx"):FireClient(player, "Text", (why or "Needs more attributes") .. " to equip", Color3.fromRGB(255, 120, 110)); return false end
                end
                -- Each gun keeps the rounds it had: swapping back and forth used to refill the magazine
                -- (an instant reload). A gun you haven't held this session starts full.
                local mags = (state :: any).MagByUid or {}
                ;(state :: any).MagByUid = mags
                if state.EquippedWeapon then mags[state.EquippedWeapon.Uid] = state.IsReloading and 0 or state.CurrentMag end
                state.EquippedWeapon = w
                state.Streak = 0
                state.IsReloading = false
                CombatServer.RecalculateMaxHealth(state)
                state.CurrentMag = math.min(state.MaxMag, mags[w.Uid] or state.MaxMag)
                stateSync:FireClient(player, state)
                return true
            end
        end
        return false
    end

    -- Upgrades (equipped weapon unless a Uid is given): +5% damage per level, cap by rarity (+5 ... +20),
    -- every 5th level raises one affix a tier. Costs Scrap / Alloy / Prism Shards + gold
    -- (ItemData.UpgradeStepCost); higher steps can fail: a failure uses up half the materials and the gold,
    -- but the weapon never loses levels or breaks.
    -- Returns (ok, message, outcome) with outcome "success" | "failed" | nil (couldn't attempt).
    CombatServer.UpgradeWeapon = function(player: Player, itemUid: string?): (boolean, string?, string?) -- (a field: DevCmd zenith craftguard)
        local state = CombatServer.GetState(player)
        local w = state.EquippedWeapon
        if type(itemUid) == "string" then
            w = nil
            for _, inv in ipairs(state.Inventory) do
                if inv.Uid == itemUid then w = inv; break end
            end
            if not w then return false, "Item not found." end
        end
        do local hold = CombatServer.TradeHold(player, w and w.Uid); if hold then return false, hold end end -- (no craft on an offered item)
        if w.Twinned then return false, "Twinned items can't be crafted." end -- (CHASE ITEMS: Twin Glass)
        local current = w.UpgradeLevel or 0
        local cap, nextIlvl = ItemData.UpgradeCapFor(w) -- (LOOT SCARCITY 2026-11-07: the cap follows item level too)
        if current >= cap then
            if nextIlvl then return false, "Item level " .. tostring(w.ItemLevel or 1) .. " stops at +" .. cap .. ". The next step opens at item level " .. nextIlvl .. "." end
            return false, w.Rarity .. " weapons max out at +" .. cap .. "."
        end
        local cost = ItemData.UpgradeStepCost(w.Rarity, current + 1)
        state.Materials = state.Materials or ItemData.NewMaterials()
        local have = state.Materials[cost.Material] or 0
        local matName = ItemData.MaterialDefs[cost.Material].Name
        if have < cost.Amount then
            return false, string.format("Need %d %s (you have %d).", cost.Amount, matName, have)
        end
        if state.Gold < cost.Gold then
            return false, "Need " .. cost.Gold .. " gold."
        end
        state.Gold -= cost.Gold
        if math.random() < cost.Chance then
            state.Materials[cost.Material] = have - cost.Amount
            w.UpgradeLevel = current + 1
            if w.UpgradeLevel % 5 == 0 and ItemData.BumpAffixTier(w) then
                (w :: any).TierBumps = ((w :: any).TierBumps or 0) + 1
                ItemData.RefreshWeaponName(w)
            end
            stateSync:FireClient(player, state)
            return true, "Upgraded to +" .. w.UpgradeLevel .. "!", "success"
        end
        local lost = math.floor(cost.Amount / 2)
        state.Materials[cost.Material] = have - lost
        stateSync:FireClient(player, state)
        return true, string.format("Upgrade failed: lost %d %s and the gold. The weapon is unharmed.", lost, matName), "failed"
    end
    upgradeFunc.OnServerInvoke = CombatServer.UpgradeWeapon

    -- ==================== [THE FORGE: dismantle, reroll, item-level up] ====================
    -- Finds a gear piece by Uid whether it's sitting in GearInventory or currently equipped --
    -- equipping a gear piece moves it OUT of GearInventory (see EquipGear above), unlike weapons,
    -- which stay in Inventory while equipped.
    local function FindGearByUid(state: PlayerState, gearUid: string): ItemData.GearInstance?
        for _, g in ipairs(state.GearInventory) do
            if g.Uid == gearUid then return g end
        end
        for _, g in pairs(state.EquippedGear) do
            if g.Uid == gearUid then return g end
        end
        return nil
    end

    -- Breaks an owned weapon or gear piece down into Forge Cores instead of Gold. Won't dismantle the
    -- currently-equipped weapon (mirrors SellWeapon's own guard); equipped gear CAN be dismantled here
    -- since gear has no "can't remove your only piece" restriction elsewhere either.
    -- Dismantle: materials by rarity (ItemData.DismantleYield). Returns (ok, gained materials).
    dismantleFunc.OnServerInvoke = function(player: Player, itemUid: string, itemType: string, zenOk: any): (boolean, any)
        local state = CombatServer.GetState(player)
        local function Salvage(rarity: string): any
            local gained = ItemData.RollDismantle(rarity)
            GrantMaterials(player, state, gained, nil, true)
            return gained
        end
        if itemType == "Gear" then
            for idx, g in ipairs(state.GearInventory) do
                if g.Uid == itemUid then
                    if g.Locked then return false, nil end -- (0.76 item lock)
                    if ItemData.ZenithOf(g) and zenOk ~= true then return false, nil end -- (Zenith: confirm first)
                    table.remove(state.GearInventory, idx)
                    local gained = Salvage(g.Rarity)
                    stateSync:FireClient(player, state)
                    return true, gained
                end
            end
            for slotName, g in pairs(state.EquippedGear) do
                if g.Uid == itemUid then
                    if g.Locked then return false, nil end -- (0.76 item lock)
                    if ItemData.ZenithOf(g) and zenOk ~= true then return false, nil end -- (Zenith: confirm first)
                    state.EquippedGear[slotName] = nil :: any
                    CombatServer.RecalculateMaxHealth(state)
                    local gained = Salvage(g.Rarity)
                    stateSync:FireClient(player, state)
                    return true, gained
                end
            end
            return false, nil
        else
            if state.EquippedWeapon.Uid == itemUid then return false, nil end
            for idx, w in ipairs(state.Inventory) do
                if w.Uid == itemUid then
                    if w.Locked then return false, nil end -- (0.76 item lock)
                    if ItemData.ZenithOf(w) and zenOk ~= true then return false, nil end -- (Zenith: confirm first)
                    CombatServer.Off.ReturnMods(state, w) -- (UPDATE 8 OFFENSE phase 3)
                    table.remove(state.Inventory, idx)
                    -- Codex of Power: a unique power you salvage is yours to imprint forever
                    if w.UniqueTrait and w.UniqueTrait.Id then
                        state.Codex = type(state.Codex) == "table" and state.Codex or {}
                        if not state.Codex[w.UniqueTrait.Id] then
                            state.Codex[w.UniqueTrait.Id] = true
                            -- (0.97: imprinting was removed; the Codex is still recorded, silently)
                        end
                    end
                    local gained = Salvage(w.Rarity)
                    stateSync:FireClient(player, state)
                    return true, gained
                end
            end
            return false, nil
        end
    end

    -- Crafting (PoE-style currencies). mode:
    --   "Reforge" (default) -- Reforge Tokens (Rare 1, Epic 2, Legendary 3, Mythic 5): reroll every affix (weapons and gear)
    --   "Tune"              -- 1 Tuning Kit: reroll the numbers inside a weapon's current affixes
    --   "Prefix"            -- 1 Prefix Catalyst: reroll a Rare+ weapon's elemental / special prefix
    -- Every craft also costs the item's sell value in gold. Common / Uncommon items can't be reforged.
    -- Returns (ok, message, item) so the client can update its copy at once.
    -- (CombatServer.ForgeReroll: the same function, for DevCmd "forge" -- a remote's callback can't be read back)
    CombatServer.ForgeReroll = function(player: Player, itemUid: string, itemType: string, mode: string?, _traitId: string?, locks: any?): (boolean, string?, any?)
        -- CRAFTING v4 (0.97, owner: "Within upgrades, remove purge, augment, imprint system, power rerolling, prefix changing,
        -- and tuning. We should only be able to reroll affixes for a very expensive price, and upgrade weapons"): the one
        -- craft left is the affix REROLL -- no locks, Prism Shards + gold that climb with every reroll of that item
        -- (ItemData.RerollCost, item.Rerolls). Imprint / Trait / Tune / Prefix are refused.
        local state = CombatServer.GetState(player)
        state.Materials = state.Materials or ItemData.NewMaterials()
        do local hold = CombatServer.TradeHold(player, itemUid); if hold then return false, hold end end -- (no craft on an offered item)
        if mode == "Twin" then return CombatServer.Zen.Twin(player, state, itemUid, itemType) end -- (CHASE ITEMS: TWIN GLASS)
        do -- (CHASE ITEMS) a TWINNED item takes no craft of any kind
            local tw = nil
            if itemType == "Gear" then tw = FindGearByUid(state, itemUid) else
                for _, inv in ipairs(state.Inventory) do if inv.Uid == itemUid then tw = inv; break end end
                if not tw and state.EquippedWeapon and state.EquippedWeapon.Uid == itemUid then tw = state.EquippedWeapon end -- (REVIEW: the Reforge path also reads the worn gun)
            end
            if tw and tw.Twinned then return false, "Twinned items can't be crafted." end
        end
        if mode == "Retype" then -- (fixes 2026-10-16 #2: REROLL GUN -- a random other gun of your class, ItemData.RetypeWeapon)
            if itemType == "Gear" then return false, "Only weapons can change gun." end
            local item: any = nil
            for _, inv in ipairs(state.Inventory) do if inv.Uid == itemUid then item = inv; break end end
            if not item and state.EquippedWeapon and state.EquippedWeapon.Uid == itemUid then item = state.EquippedWeapon end
            local ClassData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ClassData"))
            local group = ClassData.GroupOf(state.Class)
            local can, why = ItemData.CanRetype(item, group)
            if not can then return false, why end
            if not ItemData.MaterialUnlocked("ShiftShard", state.Level) then return false, "REROLL GUN unlocks at level " .. ItemData.MaterialDefs.ShiftShard.Unlock .. "." end
            local cost = ItemData.RetypeCost(item, state.Level)
            if (state.Materials.ShiftShard or 0) < cost.ShiftShard then return false, "Needs a Turncoat (from the Tumbler)." end
            if state.Gold < cost.Gold then return false, "Need " .. ItemData.FormatNumber(cost.Gold) .. " gold." end
            state.Materials.ShiftShard -= cost.ShiftShard
            state.Gold -= cost.Gold
            if not ItemData.RetypeWeapon(item, group) then return false, "No other gun in your class." end
            state.StatsTracking.DiscoveredWeapons[item.BaseId] = true
            stateSync:FireClient(player, state)
            return true, nil, item
        end
        -- CRAFTING v5 (UPDATE 7): Graft / Strip / Temper / Storm -- one currency + the craft gold, one random job each
        -- (FUTURE-PROOF 2026-10-25: every action in ItemData.CRAFT_V5_KEY -- a new craft was refused here as "removed" until it was
        -- also typed into this list; Retype has its own branch above)
        if ItemData.CRAFT_V5_KEY[mode] and mode ~= "Retype" then -- (UPDATE 8: + Ascend; LOOT: + the socket currencies)
            local key = ItemData.CRAFT_V5_KEY[mode]
            local def = ItemData.MaterialDefs[key]
            if not ItemData.MaterialUnlocked(key, state.Level) then return false, def.Name .. " unlocks at level " .. def.Unlock .. "." end
            local isGearV5 = itemType == "Gear"
            local it: any = nil
            if isGearV5 then
                it = FindGearByUid(state, itemUid)
            else
                for _, inv in ipairs(state.Inventory) do if inv.Uid == itemUid then it = inv; break end end
                if not it and state.EquippedWeapon and state.EquippedWeapon.Uid == itemUid then it = state.EquippedWeapon end
            end
            local can, why = ItemData.CraftV5Check(mode, it, isGearV5)
            if not can then return false, why end
            if (state.Materials[key] or 0) < 1 then return false, "Needs a " .. def.Name .. "." end
            local gold = ItemData.CraftGold(it, isGearV5)
            if state.Gold < gold then return false, "Need " .. ItemData.FormatNumber(gold) .. " gold." end
            -- (UPDATE 8 LOOT) a socket craft rolls on a copy first: shot mods that no longer fit go back to the mod bag, and if the
            -- bag can't take them nothing is spent and nothing changes (mods are never destroyed)
            local sockRes = nil
            if mode == "Sockets" or mode == "Links" or mode == "Colours" then
                local SMod = StatCalculator.ShotMods
                local trial = table.clone(it)
                trial.SocketMods = type(it.SocketMods) == "table" and table.clone(it.SocketMods) or nil
                local m = ItemData.CraftV5Apply(mode, trial, false)
                local out = SMod and SMod.Misfits(trial) or {}
                state.ShotMods = type(state.ShotMods) == "table" and state.ShotMods or {}
                if SMod and #out > 0 and #state.ShotMods + #out > SMod.BAG then
                    return false, "Your mod bag is full: that roll would knock " .. #out .. " mod" .. (#out == 1 and "" or "s") .. " out. Make room first (nothing was spent)."
                end
                sockRes = { m, trial, out }
            end
            state.Materials[key] -= 1
            state.Gold -= gold
            local msg
            if sockRes then
                it.Sockets, it.SocketMods = sockRes[2].Sockets, sockRes[2].SocketMods
                for _, m in ipairs(sockRes[3]) do table.insert(state.ShotMods, m) end
                msg = sockRes[1] .. ((#sockRes[3] > 0) and ("  (" .. #sockRes[3] .. " mod" .. (#sockRes[3] == 1 and "" or "s") .. " back in your bag)") or "")
            else
                msg = ItemData.CraftV5Apply(mode, it, isGearV5)
            end
            if mode == "Overcharge" then pcall(CombatServer.SeasonGoalEvent, player, state, "Overcharge", 1) end
            if isGearV5 then CombatServer.RecalculateMaxHealth(state) end
            stateSync:FireClient(player, state)
            return true, msg, it
        end
        if mode ~= nil and mode ~= "Reforge" then return false, "That craft was removed." end
        if locks ~= nil and type(locks) == "table" and #locks > 0 then return false, "Affixes can't be locked any more." end
        local item: any, isGear = nil, itemType == "Gear"
        if isGear then
            item = FindGearByUid(state, itemUid)
        else
            for _, inv in ipairs(state.Inventory) do
                if inv.Uid == itemUid then item = inv; break end
            end
            if not item and state.EquippedWeapon and state.EquippedWeapon.Uid == itemUid then item = state.EquippedWeapon end
        end
        if not item then return false, "Item not found." end
        if item.Exotic and not ItemData.RelicTunable(item) then return false, "This relic's lines are fixed." end -- (UPDATE 8 LOOT: relic lines reroll in their own ranges)
        if item.Overcharged then return false, "Redlined items can't be changed." end
        if (RarityRank[item.Rarity] or 1) < 2 then return false, "Common items have no affixes to reroll." end
        if ItemData.AffixTotal(item, isGear) == 0 then return false, "This item has no affixes to reroll." end
        local cost = ItemData.RerollCost(item, isGear, state.Level)
        if (state.Materials.Prism or 0) < cost.Prism then
            return false, string.format("Need %d Prism Shards (you have %d).", cost.Prism, state.Materials.Prism or 0)
        end
        if state.Gold < cost.Gold then return false, "Need " .. ItemData.FormatNumber(cost.Gold) .. " gold." end
        state.Materials.Prism -= cost.Prism
        state.Gold -= cost.Gold
        -- (CRAFTING v5, Loot Economy Plan section 4: Prism = REROLL VALUES -- the same lines and tiers, new numbers. A full
        -- reroll of the lines is the Storm Core's job now.)
        if isGear then
            ItemData.TuneGearLines(item)
            CombatServer.RecalculateMaxHealth(state)
        else
            ItemData.TuneWeaponAffixes(item)
        end
        item.Rerolls = (tonumber(item.Rerolls) or 0) + 1
        stateSync:FireClient(player, state)
        return true, nil, item
    end
    forgeRerollFunc.OnServerInvoke = CombatServer.ForgeReroll

    -- Re-level (Rare+): brings an item up to your character level, keeping its upgrades and affixes.
    -- Costs Prism Shards + gold per level gained (ItemData.RelevelCost) -- deliberately expensive.
    forgeLevelUpFunc.OnServerInvoke = function(player: Player, itemUid: string, itemType: string): (boolean, string?, any?)
        if true then return false, "Re-leveling was removed." end -- (0.97 CRAFTING v4: only rerolls + upgrades remain)
        local state = CombatServer.GetState(player)
        state.Materials = state.Materials or ItemData.NewMaterials()
        local item: any, isGear = nil, itemType == "Gear"
        if isGear then
            item = FindGearByUid(state, itemUid)
        else
            for _, inv in ipairs(state.Inventory) do
                if inv.Uid == itemUid then item = inv; break end
            end
        end
        if not item then return false, "Item not found." end
        if (RarityRank[item.Rarity] or 1) < 3 then return false, "Only Rare and better items can be re-leveled." end
        local from = item.ItemLevel or 1
        if from >= state.Level then return false, "Already at your level." end
        local prism, gold = ItemData.RelevelCost(item.Rarity, from, state.Level)
        local have = state.Materials.Prism or 0
        if have < prism then return false, string.format("Need %d Prism Shards (you have %d).", prism, have) end
        if state.Gold < gold then return false, "Need " .. gold .. " gold." end
        state.Materials.Prism = have - prism
        state.Gold -= gold
        if isGear then
            ItemData.RescaleGearToItemLevel(item, state.Level)
            CombatServer.RecalculateMaxHealth(state)
        else
            ItemData.RescaleWeaponToItemLevel(item, state.Level)
        end
        stateSync:FireClient(player, state)
        return true, nil, item
    end

    -- FORGE CRAFTING (0.61f, owner: "add more features to the armory (we are going to add crafting mechanics now)"):
    -- ("Augment" | "Purge" | "Ascend", uid, "Weapon" | "Gear", locks?) on an owned item, or ("Bench", "Gun" | "Gear",
    -- baseId | slot, rarity) for a new one. Costs + rules: ItemData FORGE CRAFTING. Returns ok, message, item.
    Remotes.GetFunction("ForgeCraft").OnServerInvoke = function(player: Player, action: any, a: any, b: any, c: any): (boolean, string?, any?)
        if true then return false, "That craft was removed." end -- (0.97 CRAFTING v4: Augment / Purge / Ascend / Bench are gone)
        local state = CombatServer.GetState(player)
        if not state or type(action) ~= "string" then return false, "Bad request." end
        state.Materials = state.Materials or ItemData.NewMaterials()
        local function CanPay(cost: { [string]: number }): (boolean, string?)
            for k, n in pairs(cost) do
                if n > 0 then
                    local have = (k == "Gold") and (state.Gold or 0) or (state.Materials[k] or 0)
                    if have < n then
                        local name = (k == "Gold") and "gold" or (ItemData.MaterialDefs[k] and ItemData.MaterialDefs[k].Name or k)
                        return false, string.format("Need %s %s (you have %s).", ItemData.FormatNumber(n), name, ItemData.FormatNumber(have))
                    end
                end
            end
            return true
        end
        local function Pay(cost: { [string]: number })
            for k, n in pairs(cost) do
                if n > 0 then
                    if k == "Gold" then state.Gold -= n else state.Materials[k] = (state.Materials[k] or 0) - n end
                end
            end
        end
        if action == "Bench" then
            local kind, base = a, b
            if (kind ~= "Gun" and kind ~= "Gear") or type(base) ~= "string" then return false, "Bad request." end
            if ItemData.BagRoom(state) < 1 then return false, "Your bag is full." end
            -- (0.75 CRAFTING v3: the base is yours to pick, the rarity is ROLLED -- priced as the top it can roll)
            local rarity = ItemData.BenchRollRarity(state.Level)
            local cost = ItemData.BenchRollCost(state.Level)
            local ok, why = CanPay(cost)
            if not ok then return false, why end
            local item = ItemData.BenchCraft(kind, base, rarity, state.Level)
            if not item then return false, "That can't be built." end
            Pay(cost)
            if kind == "Gun" then
                table.insert(state.Inventory, item)
                if state.StatsTracking and state.StatsTracking.DiscoveredWeapons then state.StatsTracking.DiscoveredWeapons[item.BaseId] = true end
            else
                table.insert(state.GearInventory, item)
            end
            stateSync:FireClient(player, state)
            return true, "Crafted " .. string.upper(rarity) .. " " .. tostring(item.Name), item
        end
        if action ~= "Augment" and action ~= "Purge" and action ~= "Ascend" then return false, "Unknown action." end
        local uid, itemType, locks = a, b, c
        if type(uid) ~= "string" then return false, "Bad request." end
        local isGear = itemType == "Gear"
        local item: any = nil
        if isGear then
            item = FindGearByUid(state, uid)
        else
            for _, inv in ipairs(state.Inventory) do if inv.Uid == uid then item = inv; break end end
            if not item and state.EquippedWeapon and state.EquippedWeapon.Uid == uid then item = state.EquippedWeapon end
        end
        if not item then return false, "Item not found." end
        local okC, whyC = ItemData.CanCraft(action, item, isGear, state.Level)
        if not okC then return false, whyC end
        local cost = ItemData.CraftCost(action, item, isGear)
        -- (0.75 CRAFTING v3: Purge is an Orb of Annulment -- always a random affix; Seals no longer choose it)
        local lockList: { number }? = nil
        local _ = locks
        local ok, why = CanPay(cost)
        if not ok then return false, why end
        Pay(cost)
        local msg
        if action == "Augment" then
            local label = ItemData.AugmentItem(item, isGear)
            msg = label and ("Added " .. label) or "Nothing could be added."
        elseif action == "Purge" then
            local label = ItemData.PurgeItem(item, isGear, lockList)
            msg = label and ("Removed " .. label) or "Nothing was removed."
            if lockList then item.SealRolls = (tonumber(item.SealRolls) or 0) + 1 end
        else
            local new = ItemData.AscendItem(item, isGear)
            msg = new and ("Ascended to " .. new) or "It can't ascend."
        end
        if isGear then CombatServer.RecalculateMaxHealth(state) end
        stateSync:FireClient(player, state)
        return true, msg, item
    end

    -- Starts / advances the player's private run and returns what their client needs to build the floor
    -- ({ Biome, Difficulty, FloorNumber, PlayerLevel, Seed, RunToken }), or false.
    -- biome: ignored since MIXED RUNS (the server rolls every floor's biome -- DungeonRuns.StartFloor); kept in the
    -- signature so older clients still line up.
    startDungeonFunc.OnServerInvoke = function(player: Player, biome: string, diff: string, floorNum: number?, botSkill: number?, pathIndex: number?): any
        -- Anti-cheat: the client names the difficulty/floor, so only accept a real difficulty, and only let a run go
        -- past floor 1 by clearing the floor before it (the portal).
        -- (owner 2026-10-04: ENDLESS is a game type -- the key is "Torment" or "Endless:Torment"; ItemData.ParseRunKey)
        local endless
        diff, endless = ItemData.ParseRunKey(diff)
        if not diff then return false end
        if (floorNum == nil or floorNum == 1) and not ItemData.DifficultyUnlock(CombatServer.GetState(player), diff) then return false end -- (locked)
        local floor = 1
        if floorNum ~= nil and floorNum ~= 1 then
            if type(floorNum) ~= "number" or floorNum % 1 ~= 0 then return false end
            local clearedPrevious = DungeonRuns.Attr(player, "FloorCleared") == true
                and DungeonRuns.Attr(player, "Floor") == floorNum - 1
                and DungeonRuns.Attr(player, "Difficulty") == diff
                and (DungeonRuns.Attr(player, "Endless") == true) == endless
            local modeDef = ItemData.RunMode(diff, endless)
            local pastLastWave = not modeDef.Endless and modeDef.MaxWaves ~= nil and floorNum > modeDef.MaxWaves
            if not clearedPrevious or pastLastWave then return false end
            floor = floorNum
        end
        local state = CombatServer.GetState(player)
        state.DungeonDifficulty = diff or "Easy"

        local config = {
            Biome = "Fire" :: any, -- (rolled by DungeonRuns.StartFloor)
            Difficulty = (diff or "Easy") :: any,
            Endless = endless or nil,
            FloorNumber = floor,
            -- Enemy HP/damage scales off this too (see DungeonGenerator.GetScalingMultiplier), so a
            -- leveled-up character can't just walk back through low floors and one-shot everything.
            PlayerLevel = state.Level,
            -- bot skill step (1-10): chosen on floor 1, kept for the rest of the run
            BotSkill = (floor > 1 and DungeonRuns.Attr(player, "BotSkill"))
                or ((type(botSkill) == "number" and botSkill == botSkill) and math.clamp(math.floor(botSkill), 1, 10) or 4),
        }
        -- PATH CHOICE: the portal you took decides this floor's modifiers (DungeonRuns.TakePath; nil = roll as usual)
        if floor > 1 then
            local pathMods = DungeonRuns.TakePath(player, pathIndex)
            if pathMods then (config :: any).ForceMods = pathMods end
        end
        PartyService.Leave(player) -- a solo run takes you out of any lobby room
        local info = DungeonRuns.StartFloor(player, config)
        if not info then return false end
        if floor == 1 then pcall(function() require(script.Parent.RunAgain).Note(player, { Kind = "Solo", Key = ItemData.RunKey(diff, endless), BotSkill = config.BotSkill }) end) end -- (QOL F1: RUN AGAIN remembers it)

        Remotes.GetEvent("DungeonUpdate"):FireClient(player, {
            Biome = info.Biome,
            Difficulty = diff,
            Endless = endless == true,
            Floor = info.FloorNumber or floor, -- (2026-10-22 autoplay test: a linked floor's portal asks for n + 1 and StartFloor
            -- bumps it to n + 2 -- the banner said FLOOR 2 on floor 3 until the exit room's first kill)
            Remaining = DungeonRuns.Attr(player, "RemainingEnemies") or 0,
        })
        return info
    end

    -- BACK PORTAL (DungeonRuns.Revisit): "Back" to the floor behind you / "Return" to the one you came from
    Remotes.GetFunction("RevisitFloor").OnServerInvoke = function(player: Player, dir: any): any
        if dir ~= "Back" and dir ~= "Return" then return false end
        local ok, why = true, nil
        if dir == "Back" then ok, why = DungeonRuns.CanGoBack(player) end
        local info = ok and DungeonRuns.Revisit(player, dir) or nil
        if not info then
            if why then Remotes.GetEvent("CombatFx"):FireClient(player, "Text", why, Color3.fromRGB(255, 190, 120)) end
            return false
        end
        Remotes.GetEvent("LootCleared"):FireClient(player) -- (the floor you leave: its drops wait there; ResendGroundLoot shows the new one's)
        Remotes.GetEvent("DungeonUpdate"):FireClient(player, {
            Biome = info.Biome, Difficulty = info.Difficulty, Endless = info.Endless, Floor = info.FloorNumber,
            Remaining = DungeonRuns.Attr(player, "RemainingEnemies") or 0, Revisit = info.Revisit,
        })
        return info
    end

    -- Hit Handling & Authoritative Combat
    -- consumesAmmo: the client sends this once per raycast, but a shotgun blast is 6-8 raycasts and
    -- a burst weapon is 2-4 -- all from a single trigger pull that only spent one round. Only the
    -- first raycast of a trigger pull sets consumesAmmo=true (nil from older clients also counts as
    -- true, for a normal single-shot weapon); every pellet/burst-round after that passes false so it
    -- still deals damage but the mag only ever drains once per pull, matching the client's own single
    -- decrement in FireWeapon. Previously this decremented on every single raycast, so shotguns and
    -- burst weapons emptied their magazine 6-8x / 2-4x faster than intended.
    -- hitPart: a hub target's part, or a private-dungeon enemy's stand-in (proxyPartName = the part that was hit).
    hitRemote.OnServerEvent:Connect(function(player, hitPart: Instance?, hitPosition: Vector3, consumesAmmo: boolean?, proxyPartName: string?)
        local state = CombatServer.GetState(player)
        if CombatServer.InSafeRoom(player) then return end -- no shooting out of the dungeon's safe zone

        if typeof(hitPosition) ~= "Vector3" then return end
        if hitPart ~= nil and (typeof(hitPart) ~= "Instance" or not (hitPart:IsA("BasePart") or DungeonRuns.IsProxy(hitPart))) then return end
        if consumesAmmo == nil then consumesAmmo = true end
        if type(consumesAmmo) ~= "boolean" then return end

        local shotStats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
        if consumesAmmo then
            if not AllowPull(player, shotStats.FireRate) then
                Reject(player, "fire rate")
                CombatServer.SendCombatDelta(player, state)
                return
            end
        elseif not AllowFollowUp(player, state.EquippedWeapon) then
            Reject(player, "extra pellets")
            return
        end

        if consumesAmmo then
            if not CombatServer.Zen.OnPull(state) then -- (CHASE ITEMS: Furnace Heart's lockout; heat drain since the last pull)
                CombatServer.SendCombatDelta(player, state)
                return
            end
            if state.CurrentMag <= 0 or state.IsReloading then
                CombatServer.SendCombatDelta(player, state)
                return
            end
            state.CurrentMag = math.max(0, state.CurrentMag - 1)
            CombatServer.Zen.AfterPull(player, state) -- (CHASE ITEMS: full heat -> the lockout)
            CombatServer.RS.Add(player, "Shots"); (state :: any).PullCounted = false -- (RUN SUMMARY accuracy: per trigger pull)
            if CombatServer.RS.Get(player) then CombatServer.Life(state, "Shots") end -- (lifetime accuracy: run shots only)
            task.defer(DungeonRuns.OnShot, player) -- (floor objective: Sharpshooter's live accuracy, after this pull's hit counts)
            do -- (FAR PASSIVES: Walking Fire counts quick follow-ups, Charged Cell charges after a 2 s pause)
                local sa, tnow = state :: any, os.clock()
                local gap = tnow - (sa.P_ShotAt or -99)
                sa.P_Walk = (gap <= 0.35) and ((sa.P_Walk or 0) + 1) or 0
                if gap >= 2 then sa.P_Cell = 12 end
                sa.P_ShotAt = tnow
            end
            CombatServer.Zen.ThreadPull(player, state) -- (CHASE ITEMS: Unbroken Thread -- a pull that lands nothing is a miss)
        end

        -- (ENEMY ATTACKS PILOT, review A) shooting a heavy's shell down is NEUTRAL for Focus / headshot runs (it neither adds nor
        -- breaks them -- it's the mechanic we teach), but only when the server can believe it:
        --   party: a real server shell, hit near it, in range -> popped + neutral
        --   solo (the shell only exists on the client): DungeonRuns.ShellClaim -- a Heavy stand-in alive on the floor, budgeted per
        --   Heavy a claim per its attack gap; anything past that is an ordinary miss
        if hitPart and hitPart.Name == "AtkShell" and hitPart:GetAttribute("ShellShot") then
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local popped = false
            if root and root:IsA("BasePart") and (root.Position - hitPosition).Magnitude <= MAX_SHOT_RANGE
                and ((hitPart :: BasePart).Position - hitPosition).Magnitude <= (hitPart :: BasePart).Size.X + 6 then
                CombatServer.EA = CombatServer.EA or require(game.ReplicatedStorage.AimRngShared.EnemyAttacks)
                popped = CombatServer.EA.PopShell(hitPart)
            end
            if popped then CombatServer.Zen.ThreadKeep(state, player); CombatServer.SendCombatDelta(player, state) return end
            hitPart = nil -- (not a live shell: an ordinary miss below)
        elseif not hitPart and proxyPartName == "AtkShell" and DungeonRuns.ShellClaim(player) then
            CombatServer.Zen.ThreadKeep(state, player)
            CombatServer.SendCombatDelta(player, state)
            return
        end
        if not hitPart or not hitPart.Parent then
            -- A follow-up pellet / burst round whose target just died arrives as nil; that isn't a miss.
            if consumesAmmo and not shotStats.SpecialMechanics["ETERNAL_FOCUS"] then state.Streak = 0 end
            if consumesAmmo then (state :: any).HsRun = 0; (state :: any).P_Hot = 0; (state :: any).CalHit = 0; (state :: any).CB_WC = 0 end -- (a miss ends a headshot run / Hot Streak / calibration hit run; (CLASS BUILDS) FAMILY: the DMR chain)
            CombatServer.SendCombatDelta(player, state)
            return
        end

        local model: Instance, partName: string, partPos: Vector3?, partRadius: number
        if DungeonRuns.IsProxy(hitPart) then
            if hitPart:GetAttribute("OwnerUserId") ~= player.UserId then return end
            model = hitPart
            partName = (type(proxyPartName) == "string" and #proxyPartName < 40) and proxyPartName or "Torso"
            partPos = DungeonRuns.PosOf(hitPart)
            partRadius = hitPart:GetAttribute("HitRadius") or 6
        else
            model = hitPart.Parent :: Instance
            local link = hitPart:FindFirstChild("HitModel") -- (boss shield orbs live outside the boss model, linked to it)
            if link and link:IsA("ObjectValue") and link.Value then model = link.Value end
            -- (0.91: every boss part takes hits -- a piece nested under another part / a spinning hub walks up to the enemy)
            while model and model ~= workspace and not CollectionService:HasTag(model, "AimRngEnemy") and model.Parent and model.Parent:IsA("BasePart") do
                model = model.Parent
            end
            if model and model.Parent and not CollectionService:HasTag(model, "AimRngEnemy") and CollectionService:HasTag(model.Parent, "AimRngEnemy") then model = model.Parent end
            if not CollectionService:HasTag(model, "AimRngEnemy") then -- hit a wall/floor: an ordinary miss
                if consumesAmmo then (state :: any).HsRun = 0; (state :: any).P_Hot = 0; (state :: any).CalHit = 0; (state :: any).CB_WC = 0 end -- ((CLASS BUILDS) FAMILY: the DMR chain)
                return
            end
            if model:GetAttribute("RunId") ~= player:GetAttribute("RunId") then return end -- another party's enemy
            partName = hitPart:GetAttribute("HitAs") or hitPart.Name -- (decorations count as the part they sit on)
            partPos = (hitPart :: BasePart).Position
            partRadius = (hitPart :: BasePart).Size.Magnitude * 0.5
        end
        local char = player.Character
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")
        -- (0.53) a hit on a boss mechanic target counts by the gun's pace: slow guns' hits count more and a shotgun's pellets
        -- share one shot's worth. (0.85, owner: "boss mechanics (such as tracking or flicking to the orbs) needs to be balanced
        -- for varying fire rates (a sniper should deal more damage or one shot certain types)"): the weight was
        -- clamp(5 / rate, 1, 5) -- a sniper's shot capped at 5 (it needs ~14 to match), anything over 5 shots a second all
        -- counted 1. Now weight = 10 / shots a second (0.5 .. 20): a 10/s rifle is unchanged (the mechanics' hit counts are in
        -- rifle hits), every gun needs the same TIME on target, and slow guns one-shot small targets (a sniper ~14 per shot:
        -- every satellite / relay node / a solo wisp in one hit; a full shotgun volley ~8).
        local function OrbWeight(): number
            local w = state.EquippedWeapon
            local rate = (w and w.BaseFireRate) or 10
            return math.clamp(10 / math.max(0.2, rate), 0.5, 20) / ((shotStats.Slug and 1) or math.max(1, (w and w.PelletCount) or 1)) -- ((CLASS BUILDS) a slug = one whole shot)
        end
        -- BOSS SHIELD ORBS (BossAI): a hit on "ShieldOrb<i>" deals no damage; it counts into the boss's "Orb<i>" attribute
        -- (a solo boss's client copy mirrors it). The orbs float far from the boss, so the near-the-enemy check is skipped.
        do
            local orbN = model:GetAttribute("IsBoss") and string.match(partName or "", "^ShieldOrb(%d)$")
            if orbN then
                if rootPart and rootPart:IsA("BasePart") and (rootPart.Position - hitPosition).Magnitude <= MAX_SHOT_RANGE then
                    local k = "Orb" .. orbN
                    model:SetAttribute(k, (model:GetAttribute(k) or 0) + OrbWeight())
                    model:SetAttribute("LastOrbHit", workspace:GetServerTimeNow())
                end
                CombatServer.Zen.ThreadKeep(state, player) -- (CHASE ITEMS: an orb hit isn't a miss)
                CombatServer.SendCombatDelta(player, state)
                return
            end
        end
        local badReason = nil
        if not rootPart or not rootPart:IsA("BasePart") then
            badReason = "no character"
        elseif partPos and (partPos - hitPosition).Magnitude > partRadius + HIT_POS_SLACK + (model:GetAttribute("IsBoss") and 22 or 0) then
            -- (bosses: big, and since 0.35 they strafe + dodge fast -- a solo boss's stand-in position is ~1/6 s old and
            -- party clients see it a ping behind, so hits on the edge of the boss (the TOP OF THE HEAD) were thrown out --
            -- owner 2026-10-05: "the top of their heads dont count as a hit even when exactly on it")
            badReason = "hit too far from enemy"
        elseif (rootPart.Position - hitPosition).Magnitude > MAX_SHOT_RANGE then
            badReason = "out of range"
        elseif not DungeonRuns.IsProxy(model) and not model:GetAttribute("RunId") and not HasLineOfSight(player, model, hitPosition) then
            -- (line of sight is only checked in the hub: dungeons overlap on the server, solo maps aren't there)
            badReason = "through wall"
        end
        if badReason then
            Reject(player, badReason)
            CombatServer.SendCombatDelta(player, state)
            return
        end

        local currentHealth = model:GetAttribute("Health") :: number?
        local maxHealth = model:GetAttribute("MaxHealth") :: number?

        if not currentHealth or not maxHealth or currentHealth <= 0 or model:GetAttribute("Dead") then return end

        local stats = StatCalculator.Calculate(state.EquippedWeapon, state.AllocatedNodes, state.Streak, state.Level, state.Attributes, state.EquippedGear, state.EquippedTitle, state.SocketedGems, state.RunBoons, state)
        local weapon = state.EquippedWeapon
        local mech = stats.SpecialMechanics or {}
        local pellets = (stats.Slug and 1) or math.max(1, weapon and weapon.PelletCount or 1) -- ((CLASS BUILDS) Slug Rounds: one pellet)
        if not model:GetAttribute("IsPracticeDummy") then -- (RUN SUMMARY: a pull that lands any pellet is a hit)
            CombatServer.RS.Add(player, "PelletHits")
            if not (state :: any).PullCounted then
                (state :: any).PullCounted = true; CombatServer.RS.Add(player, "Hits")
                if CombatServer.RS.Get(player) then CombatServer.Life(state, "Hits") end
            end
        end
        local proc = weapon and weapon.Proc
        local procId = proc and proc.Id

        -- FORGEHEART (Boss Trial): a slag shell -- 15% damage anywhere but its three crawling BRANDS, which count as weak
        -- spots and take ~full damage (the rule lives here so a client can't skip it)
        local isForge = model:GetAttribute("ModelName") == "TrialForgeheart" or model:GetAttribute("TrialBoss") == "Forgeheart"
        local isBrand = isForge and partName == "Brand"
        -- BOSS SIGNATURES (BossAI SIG): "BreakPart<i>" = a breakable weak point (Goliath's backplate, the Titan's cannons,
        -- Ignis's core): a weak-spot hit that also counts into the boss's "Orb<i>" attribute (BossAI reads it). The
        -- Goliath's armoured front: 30% damage anywhere but its backplate (its head isn't a weak spot).
        local breakN = model:GetAttribute("IsBoss") and string.match(partName or "", "^BreakPart(%d)$")
        if breakN then
            local k = "Orb" .. breakN
            model:SetAttribute(k, (model:GetAttribute(k) or 0) + OrbWeight())
            model:SetAttribute("LastOrbHit", workspace:GetServerTimeNow())
        end
        -- (0.76, owner: "make it so bosses and enemies only ever have one weakspot that should always be hittable but
        -- relatively small to reward precision"): the HEAD is the one weak spot on every enemy and boss. Cores, brands and
        -- break parts are body hits now (break parts still count into their Orb attribute for boss mechanics).
        local isWeakSpot = partName == "Head"
        local _ = isBrand
        local damage = stats.Damage
        -- (2026-10-07, owner: "the tank boss is incredibly annoying and unfun to fight, it just takes long": its front took
        -- 30% -- effectively more health than the Titan. Now 55%, with less health and quicker posture breaks)
        -- (0.68 AIM ROUNDS: the Goliath's armoured front and the Forgeheart's slag shell are gone -- every boss takes the
        -- same damage everywhere; its mechanic is the aim round in BossAI. Brands / backplates still count as weak spots.)
        if partName == "Shield" and not model:GetAttribute("IsBoss") then damage *= 0.1 end -- Warden's energy shield (0.68: the Sentinel boss's no longer blocks)

        if FloorMods.Has(DungeonRuns.Attr(player, "Mods"), "HEADHUNTER") then damage *= isWeakSpot and 1.3 or (1 - CombatServer.ModV(player, "HEADHUNTER")) end -- (MAPS V2: body x0.5 at x1)
        if stats.Zenith and stats.Zenith.UnbrokenThread then damage *= CombatServer.Zen.ThreadHit(player, state, weapon) end -- (CHASE ITEMS: +4% a hit in a row)
        -- headshot runs (titles: weak-spot hits in a row; a body shot or a miss ends it; the range dummy doesn't count)
        if consumesAmmo and not model:GetAttribute("IsPracticeDummy") then
            local sa = state :: any
            -- (UPDATE 7 CALIBRATION: hits in a row with this gun model; a miss / another gun starts over)
            local gunNow = weapon and weapon.BaseId
            if sa.CalGun ~= gunNow then sa.CalGun = gunNow; sa.CalHit = 0; sa.HsRun = 0 end
            sa.CalHit = (sa.CalHit or 0) + 1
            pcall(CombatServer.CalibrationFeat, player, state, "HitRun", sa.CalHit)
            sa.HsRun = isWeakSpot and ((sa.HsRun or 0) + 1) or 0
            if sa.HsRun > 0 then pcall(CombatServer.CalibrationFeat, player, state, "HsRun", sa.HsRun) end
            if sa.HsRun > (state.StatsTracking.BestHeadshotRun or 0) then
                state.StatsTracking.BestHeadshotRun = sa.HsRun
                if sa.HsRun == 10 or sa.HsRun == 25 or sa.HsRun == 50 or sa.HsRun == 100 then
                    Remotes.GetEvent("CombatFx"):FireClient(player, "Text", sa.HsRun .. " HEADSHOTS IN A ROW", Color3.fromRGB(255, 225, 90))
                end
            end
        end
        -- a boss fight starts at the first hit (Flawless / Executioner titles)
        if model:GetAttribute("IsBoss") and not model:GetAttribute("FightStart") then model:SetAttribute("FightStart", os.clock()) end
        local realWeak = isWeakSpot -- (UPDATE 8 OFFENSE phase 4, Cornerstone Point of Aim: every hit counts as a weak spot;
        -- (ENEMY ATTACKS PILOT) a real head hit on a party (server-run) marksman while it charges cancels the shot (BotRoles reads it;
        -- a solo bot's own client stamps it)
        if isWeakSpot and model:GetAttribute("AimCharge") and not DungeonRuns.IsProxy(model) then model:SetAttribute("WeakHitAt", workspace:GetServerTimeNow()) end
        if stats.AllWeak then isWeakSpot = true end -- titles / run stats still count only real head hits)
        if isWeakSpot then
            damage *= stats.WeakSpotMultiplier
            if realWeak then
                state.StatsTracking.WeakSpotHits = (state.StatsTracking.WeakSpotHits or 0) + 1 -- (titles: any gun)
                CombatServer.RS.Add(player, "Weak")
                if weapon.Class == "Sniper" then
                    state.StatsTracking.SniperHeadshots += 1
                end
            end
            state.Streak = math.min((stats.MaxFocusStacks or 25) + 5, state.Streak + (mech.DUELIST and 2 or 1))
            if DungeonRuns.IsProxy(model) then DungeonRuns.OnStreak(player, state.Streak) end -- (floor objective: Focus)
            if state.Streak >= 5 then CombatServer.ContractEvent(player, state, "Streak", state.Streak) end
            state.StatsTracking.BestStreak = math.max(state.StatsTracking.BestStreak or 0, state.Streak)
            CombatServer.RS.Max(player, "BestStreak", state.Streak)
        else
            -- Deadeye keystone penalty, and Armored elites shrug off body shots.
            damage *= (stats.BodyShotMult or 1) * (model:GetAttribute("BodyArmor") or 1)
            if mech.DUELIST and consumesAmmo then state.Streak = 0 end -- Duelist: a body shot ends your Focus
        end

        -- Fixation: stacks from recent hits raise damage; decay after a pause.
        local st: any = state
        local now = os.clock()

        -- ===== Passive tree conditions (all "increased" bonuses share the damage pool) =====
        local cond = stats.Cond or {}
        -- per trigger pull: shotgun pellets / burst rounds share the pull's "new target" / "full health" verdicts
        local fullHP = currentHealth >= maxHealth - 0.01
        local isNewTarget
        if consumesAmmo then
            isNewTarget = (st.LastHitModel ~= model)
            -- hits in a row on the same enemy (Hunter's Focus trait, Tunnel Vision gem)
            st.SameTargetHits = isNewTarget and 0 or ((st.SameTargetHits or 0) + 1)
            st.PullNewTarget, st.PullFullHP, st.LastHitModel = isNewTarget, fullHP, model
        else
            isNewTarget = (st.PullNewTarget == true) and st.LastHitModel == model
            if st.LastHitModel == model then fullHP = st.PullFullHP == true end
        end
        local moving = false
        local shotDist = nil
        do
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root and root:IsA("BasePart") then
                local v = root.AssemblyLinearVelocity
                moving = Vector3.new(v.X, 0, v.Z).Magnitude >= 1.5
                shotDist = (root.Position - hitPosition).Magnitude
                shotDist = CombatServer.CBCorner.Dist(stats, shotDist) -- ((CLASS BUILDS) Slug Rounds: close-range bonuses reach twice as far)
            end
        end
        local ailCount = 0
        local es = enemyStatus[model]
        if es then
            if #es.Burns > 0 then ailCount += 1 end
            if #es.Bleeds > 0 then ailCount += 1 end
            if now < es.ChillUntil then ailCount += 1 end
            if now < es.DecayUntil then ailCount += 1 end
        end
        local incCond = 0
        if fullHP then incCond += cond.FirstHitDamage or 0 end
        if currentHealth / maxHealth < 0.35 then incCond += cond.LowHealthEnemyDamage or 0 end
        if isNewTarget then incCond += cond.SwitchDamage or 0 end
        if model:GetAttribute("IsElite") == true or model:GetAttribute("IsBoss") == true then incCond += cond.EliteDamage or 0 end
        if (state.MaxMag or 0) > 0 and state.CurrentMag <= math.floor(state.MaxMag * 0.3) then incCond += cond.LastMagDamage or 0 end
        if moving then incCond += cond.MovingDamage or 0 else incCond += cond.StillDamage or 0 end
        -- (2026-10-05 GUN-AGNOSTIC TREE: the old weapon-type nodes became these playstyle stats -- ItemData.StatDefs)
        if shotDist and shotDist <= 25 then incCond += cond.CloseRangeDamage or 0 end
        if shotDist and shotDist >= 60 then incCond += cond.LongRangeDamage or 0 end
        do -- PATH MODIFIERS (2026-10-06): Keep Your Distance (risk) / Eagle Eye (gift)
            local fm = DungeonRuns.Attr(player, "Mods")
            if type(fm) == "string" and fm ~= "" then
                if shotDist and shotDist < 25 and FloorMods.Has(fm, "KEEP_DISTANCE") then damage *= 1 - CombatServer.ModV(player, "KEEP_DISTANCE") end -- (MAPS V2: x0.6 at x1)
                if isWeakSpot and FloorMods.Has(fm, "EAGLE_EYE") then damage *= 1.25 end
            end
        end
        if now - ((state :: any).ReloadedAt or -99) <= 3 then incCond += cond.ReloadedDamage or 0 end
        if (state.MaxMag or 0) > 0 and state.CurrentMag >= math.ceil(state.MaxMag * 0.7) then incCond += cond.FreshMagDamage or 0 end
        do -- the gun-agnostic keystones (were weapon-type: StatCalculator keeps their unconditional parts)
            local fresh = now - ((state :: any).ReloadedAt or -99) <= 3
            if mech.SIDEARM then damage *= fresh and 1.3 or 0.9 end
            if mech.SCATTERSHOT and shotDist and shotDist <= 25 then damage *= 1.3 end
            if mech.COLD_BORE and isWeakSpot and shotDist and shotDist >= 60 then damage *= 1.5 end
            if mech.HEAVY_ORDNANCE and not moving then damage *= 1.3 end
            if mech.ASSAULT_DOCTRINE and (state.MaxMag or 0) > 0 and state.CurrentMag >= math.ceil(state.MaxMag * 0.7) then damage *= 1.2 end
        end
        if ailCount > 0 then incCond += cond.AilmentedDamage or 0 end
        -- Chain kills: every kill adds a stack for a few seconds (precision rework, 2026-10-02)
        if (st.ChainUntil or 0) < now then st.ChainStacks = 0 end
        incCond += (st.ChainStacks or 0) * (cond.ChainKillDamage or 0)
        if incCond ~= 0 then
            local base = 1 + (stats.DamageBonusPct or 0)
            damage *= math.max(0.1, base + incCond) / math.max(0.1, base)
        end
        -- keystones (MORE / LESS multipliers)
        if mech.OVERLOAD and ailCount >= 2 then damage *= 1.5 end
        if mech.QUICKDRAW then damage *= isNewTarget and 1.35 or 0.9 end
        if mech.RUN_AND_GUN then damage *= moving and 1.2 or 0.75 end
        if (mech.ENTRENCHED or mech.STEADY_HANDS) and not moving then damage *= 1.25 end
        -- hybrid keystones (tree v3, 2026-10-04)
        local lowLife = (state.Health or 0) < (state.MaxHealth or 1) * 0.4
        if mech.LAST_BASTION then damage *= lowLife and 1.4 or 0.9 end
        if mech.ONE_SHOT and weapon then damage *= (ItemData.HitsPerSecond(weapon) <= 2) and 1.4 or 0.8 end
        if mech.BUTCHER and fullHP then damage *= 0.75 end
        if procId == "Fixation" then
            if now - (st.FixLast or 0) > PROC.FixDecay then st.FixStacks = 0 end
            damage *= 1 + (st.FixStacks or 0) * PROC.FixDmgPerStack * (proc.Power or 1)
        end
        if mech.RAMPAGE and fullHP then damage *= 0.9 end
        if mech.TUNNEL_VISION then damage *= 1 + math.min(0.45, 0.03 * (st.SameTargetHits or 0)) end
        local lastRound = consumesAmmo and (state.CurrentMag or 1) <= 0
        if mech.LAST_WORD and lastRound then damage *= 1.5 end
        if mech.CHAIN_OF_COMMAND and (st.CommandHits or 0) > 0 then
            damage *= 1.5
            if consumesAmmo then st.CommandHits -= 1 end
        end
        -- CLASS PASSIVES (weapon classes 2026-10-05; tree keystones P_*, only present while you hold your class's guns --
        -- StatCalculator). (0.62: PLAYSTYLES -- a big reward for playing their way, a real cost for not; the texts in
        -- tools/gen_tree_v4.py must match these numbers.) Per-pull counters only step on the pull's first
        -- hit (consumesAmmo); a shotgun's other pellets / a burst share that verdict.
        local pForceCrit = false
        do
            local isBossT = model:GetAttribute("IsBoss") == true
            local hpFrac = currentHealth / maxHealth
            if consumesAmmo then
                st.P_WS = isWeakSpot and ((st.P_WS or 0) + 1) or 0
                st.P_Pull = (st.P_Pull or 0) + 1
                st.P_BoltOK = (now - (st.P_LastPull or -99)) >= 1.2
                st.P_LastPull = now
                st.P_DoorPull = ((state :: any).ReloadedAt or 0) ~= st.P_DoorSeen
                st.P_DoorSeen = (state :: any).ReloadedAt or 0
                st.P_Pel, st.P_PelModel = 0, model
            elseif st.P_PelModel == model then
                st.P_Pel = (st.P_Pel or 0) + 1
            end
            -- Marksman
            if mech.P_DOUBLE_TAP and consumesAmmo and (st.P_WS or 0) >= 2 and now >= (st.P_DTReady or 0) then
                damage *= isBossT and 2 or 3
                st.P_DTReady, st.P_WS = now + 4, 0
                Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "DOUBLE TAP", Color3.fromRGB(120, 210, 255))
            end
            if mech.P_FAR_SIGHT and shotDist then damage *= (shotDist >= 45 and 1.4) or (shotDist <= 20 and 0.6) or 1 end
            if mech.P_CONFIRMED_KILL then
                if now < (st.P_ConfirmUntil or 0) then
                    damage *= 2
                    if consumesAmmo then st.P_ConfirmUntil = 0 end
                else
                    damage *= 0.9
                end
            end
            if mech.P_TRUE_AIM then damage *= isWeakSpot and 1.35 or 0.7 end
            if mech.P_BOLT_DISCIPLINE then damage *= st.P_BoltOK and 1.3 or 0.8 end -- ((CLASS BUILDS) balance: 1.45 -> 1.3)
            -- Gunslinger
            if mech.P_RUN_AND_GUN then damage *= moving and 1.4 or 0.75 end -- ((CLASS BUILDS) PART B: 1.3 -> 1.4)
            if mech.P_QUICKDRAW then damage *= ((st.SameTargetHits or 0) < 3) and 1.4 or 0.85 end -- ((CLASS BUILDS) balance: 1.75 -> 1.4)
            if mech.P_FRESH_MAG and now - ((state :: any).ReloadedAt or -99) <= 1.5 then damage *= 1.4 end
            if mech.P_ADRENALINE then damage *= (now < (st.P_RushUntil or 0)) and 1.4 or 0.9 end
            if mech.P_EMPTY_THE_MAG and (state.MaxMag or 0) > 0 then
                if state.CurrentMag <= math.floor(state.MaxMag * 0.25) then damage *= 1.5
                elseif state.CurrentMag >= math.ceil(state.MaxMag * 0.75) then damage *= 0.9 end
            end
            -- Arcwright
            if mech.P_HEAVY_CURRENT then damage *= (model:GetAttribute("IsElite") == true or isBossT) and 1.3 or 0.85 end
            if mech.P_CONDUCTION then damage *= (ailCount > 0) and 1.35 or 0.8 end
            if mech.P_ION_CHARGE then damage *= (now < (st.P_IonUntil or 0)) and (1 + 0.12 * (st.P_Ion or 0)) or 0.92 end
            if mech.P_STABLE_CORE then
                if now < ((state :: any).P_CoreOff or 0) then damage *= 0.9
                elseif state.Health >= state.MaxHealth * 0.9 then damage *= 1.3 end
            end
            if mech.P_PULSE_SYNC then damage *= (st.P_Pull % 3 == 0) and 1.7 or 0.9 end
            -- Breacher
            if mech.P_FACE_TO_FACE and shotDist then damage *= (shotDist <= 10 and 1.4) or (shotDist >= 25 and 0.6) or 1 end
            if mech.P_DOOR_KICKER and st.P_DoorPull then damage *= 2.5 end
            if mech.P_PELLET_STORM then damage *= ((st.P_Pel or 0) == 0 and pellets > 1) and 0.85 or (1 + math.min(0.4, 0.05 * (st.P_Pel or 0))) end
            if mech.P_BLOODLETTER and es ~= nil and #es.Bleeds > 0 then damage *= 1.15 end -- ((CLASS BUILDS) balance: 1.25 -> 1.15)
            if mech.P_SHELL_SHOCK then damage *= (fullHP and 1.7) or (hpFrac < 0.5 and 0.9) or 1 end
            -- Vanguard
            if mech.P_SUPPRESSIVE_FIRE then damage *= 1 + math.min(0.4, 0.025 * (st.SameTargetHits or 0)) end
            if mech.P_STAND_FIRM then damage *= moving and 0.75 or 1.35 end
            if mech.P_OVERHEAT then
                if now < (st.P_HotUntil or 0) then damage *= 1.6
                elseif now < (st.P_CoolUntil or 0) then damage *= 0.7
                elseif consumesAmmo then
                    st.P_Heat = (st.P_Heat or 0) + 1
                    if st.P_Heat >= 20 then
                        st.P_Heat, st.P_HotUntil, st.P_CoolUntil = 0, now + 3, now + 4.5
                        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "OVERHEAT", Color3.fromRGB(255, 150, 50))
                    end
                end
            end
            if mech.P_TRACER_ROUNDS and consumesAmmo and (st.P_Pull % 5 == 0) then pForceCrit = true end
            damage = CombatServer.CBCorner.PreHit(player, state, stats, mech, damage) -- ((CLASS BUILDS) CORNERSTONE: Field Commander)
            -- FAR PASSIVES (0.49: the far edge of each class's area -- gen_tree_v4 FAR_PASSIVES)
            if mech.P_QUARRY then
                st.P_Marks = st.P_Marks or setmetatable({}, { __mode = "k" })
                if st.P_Marks[model] then damage *= 1.4
                elseif isWeakSpot then st.P_Marks[model] = true
                else damage *= 0.75 end
            end
            if mech.P_SLIDE_FIRE then
                local fast, air = false, false
                local rt = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                if rt then local v = rt.AssemblyLinearVelocity; fast = Vector3.new(v.X, 0, v.Z).Magnitude >= 21 end
                if hum then air = hum.FloorMaterial == Enum.Material.Air end
                damage *= (fast or air) and 1.45 or (moving and 1 or 0.75)
            end
            if mech.P_HOT_STREAK then
                if consumesAmmo then st.P_Hot = (st.P_Hot or 0) + 1 end
                damage *= 1 + math.min(0.45, 0.03 * math.max(0, (st.P_Hot or 1) - 1))
            end
            if mech.P_CAPACITOR then
                if (st.P_Cell or 0) > 0 then
                    damage *= 1.6
                    if consumesAmmo then st.P_Cell -= 1 end
                else
                    damage *= 0.9
                end
            end
            if mech.P_MERCY_SHOT then damage *= (hpFrac < 0.3 and 1.6) or (hpFrac > 0.7 and 0.85) or 1 end
            if mech.P_BATTERING_RAM and now < (st.P_RamUntil or 0) then damage *= 1 + 0.1 * (st.P_Ram or 0) end
            if mech.P_WALKING_FIRE then
                local n = st.P_Walk or 0
                damage *= (n < 5) and 0.85 or (1 + math.min(0.4, 0.02 * (n - 4)))
            end
            if mech.P_HOLD_LINE then
                if moving then st.P_StillSince = nil
                else
                    st.P_StillSince = st.P_StillSince or now
                    if now - st.P_StillSince >= 1.5 then damage *= 1.25 end
                end
            end
        end
        -- PLAYSTYLE KEYSTONES (0.62, tools/tree_additions.py X_PSK_*: any gun, any class -- equipped like class passives)
        do
            local hpFracU = currentHealth / maxHealth
            if mech.U_GLASS then damage *= 1.4 end
            if mech.U_FLICKER then damage *= isNewTarget and 1.5 or 0.85 end
            if mech.U_LOCK then
                if consumesAmmo then
                    if not isNewTarget and now - (st.U_LockAt or -9) <= 0.3 then st.U_Lock = (st.U_Lock or 0) + 1 else st.U_Lock = 0 end
                    st.U_LockAt = now
                end
                damage *= ((st.U_Lock or 0) > 0) and (1 + math.min(0.6, 0.05 * st.U_Lock)) or 0.9
            end
            if mech.U_LAST_STAND then
                local f = state.Health / math.max(1, state.MaxHealth)
                damage *= (f < 0.4 and 1.6) or (f > 0.8 and 0.85) or 1
            end
            if mech.U_MOMENTUM and now < (st.U_MomUntil or 0) then damage *= 1 + 0.1 * (st.U_Mom or 0) end
            if mech.U_ONE_SHOT and st.P_DoorPull then damage *= 4 end
            if mech.U_CREED and hpFracU > 0.5 then damage *= 0.85 end
            if mech.U_GAMBLER then damage *= 0.5 + math.random() * 1.5 end
        end
        -- ascendancy (tree v4): conditional MORE damage, crit chance, every-Nth-pull, ramps
        local actx
        local ascCrit, ascForce = 0, false
        if stats.AscFx and #stats.AscFx > 0 then
            actx = {
                T0 = Asc.Now(), Weak = isWeakSpot, FullHP = fullHP, LowHP = currentHealth / maxHealth < 0.35,
                Elite = model:GetAttribute("IsElite") == true or model:GetAttribute("IsBoss") == true, Boss = model:GetAttribute("IsBoss") == true,
                Moving = moving, Ail = ailCount, Burning = es ~= nil and #es.Burns > 0, Bleeding = es ~= nil and #es.Bleeds > 0,
                Chilled = es ~= nil and now < es.ChillUntil, Decaying = es ~= nil and now < es.DecayUntil,
                LowLife = lowLife, HighLife = state.Health >= state.MaxHealth * 0.5, FullLife = state.Health >= state.MaxHealth * 0.95,
                NewTarget = isNewTarget, SameHits = st.SameTargetHits or 0, Streak = state.Streak or 0,
                LastRounds = (state.MaxMag or 0) > 0 and state.CurrentMag <= math.floor(state.MaxMag * 0.3),
                Dist = Asc.Dist(player, hitPosition), Marked = Asc.Marked(model, player),
                SlowGun = weapon ~= nil and ItemData.HitsPerSecond(weapon) <= 2,
                Group = ItemData.WeaponGroupOf(weapon), HeavyGun = ItemData.IsHeavyGun(weapon),
            }
            actx.Shocked = es ~= nil and now < ((es :: any).ShockUntil or 0) -- (CLASS BUILDS) SIGNATURE: condition Shocked (Thunderhead)
            local am
            am, ascCrit, ascForce = Asc.PreHit(st, stats, actx, consumesAmmo)
            damage *= am
        end
        damage *= CombatServer.CB.Sig.PreHit(player, state, stats, model, consumesAmmo, shotDist) -- (CLASS BUILDS) SIGNATURE: Mark / First Contact / Arm's Length / Plague
        local traitMult, traitCull = TraitPreHit(st, weapon, model, consumesAmmo, not isNewTarget, isNewTarget,
            { Moving = moving, Ail = ailCount, Weak = isWeakSpot, HpFrac = currentHealth / maxHealth })
        damage *= traitMult
        -- EXOTIC WEAPONS (0.53, ItemData.Exotics): their signature effects before the hit lands
        local exo = weapon and weapon.Exotic
        if exo == "IronChoir" then
            -- sustained fire: hits less than 0.6 s apart keep the climb going (to +30% at 3 s)
            if now - (st.ExoChoirLast or -9) > 0.6 then st.ExoChoirStart = now end
            st.ExoChoirLast = now
            damage *= 1 + 0.3 * math.clamp((now - (st.ExoChoirStart or now)) / 3, 0, 1)
        elseif exo == "TwinFang" and now < (st.ExoFangUntil or 0) then
            damage *= 3
            if consumesAmmo then st.ExoFangUntil = 0 end
        elseif exo == "LastWord" and now < (st.ExoWordUntil or 0) then
            damage *= 1 + 0.25 * (st.ExoWord or 0)
        elseif exo == "DragonsMaw" and shotDist and shotDist <= 10 then
            damage *= 1.5
            st.ExoMawBurn = true
        elseif exo == "ArcLance" then
            if st.ExoLanceTarget ~= model or now - (st.ExoLanceLast or -9) > 0.5 then st.ExoLanceTarget, st.ExoLanceStart = model, now end
            st.ExoLanceLast = now
            damage *= 1 + math.min(0.8, 0.1 * (now - st.ExoLanceStart))
        end
        local cbf = CombatServer.CB.Family.PreHit(player, state, stats, weapon, model, isWeakSpot, consumesAmmo, pellets) -- (CLASS BUILDS) FAMILY: the gun family's line
        damage *= cbf.More -- (CLASS BUILDS) FAMILY
        -- (UPDATE 8 OFFENSE) TYPED RESISTS, replacing the old +-15% ElementMatch: each type's share of the hit x (1 - the
        -- enemy's resist to it) (CombatServer.Off.Resists). tParts = the shares after resists (ailments + the number's colour);
        -- "Strong" / "Weak" arrows when the resists move the hit by more than 2%.
        local elemTag
        local tParts = {}
        do
            local DT = CombatServer.DT
            local res = CombatServer.Off.Resists(model, player)
            local shares = stats.DamageShares or { Kinetic = 1 }
            local rm = 0
            for _, t in ipairs(DT.ORDER) do
                local r = res and math.clamp(res[t] or 0, DT.ENEMY_RESIST_FLOOR, DT.ENEMY_RESIST_CAP) or 0
                tParts[t] = (shares[t] or 0) * (1 - r)
                rm += tParts[t]
            end
            if rm <= 0 then rm = 1; tParts.Kinetic = 1 end
            damage *= rm
            if rm > 1.02 then elemTag = "Strong" elseif rm < 0.98 then elemTag = "Weak" end
        end
        -- Overkill carried from your last kill lands on this hit
        if (st.CarryDmg or 0) > 0 then
            if (st.CarryUntil or 0) >= now then damage += st.CarryDmg end
            st.CarryDmg = 0
        end

        local critChance = stats.CritChance + (isWeakSpot and (cond.WeakSpotCritChance or 0) or 0)
        if mech.OPENING_SHOT and fullHP then critChance = 1 end -- Opening Shot: untouched enemies always crit
        if mech.LAST_WORD and lastRound then critChance = 1 end
        critChance += ascCrit
        if ascForce then critChance = 1 end
        if mech.P_CALM_BREATH then critChance += ((state.Streak or 0) >= 10) and 0.15 or -0.08 end
        if pForceCrit then critChance = 1 end -- (Tracer Rounds)
        if cbf.Crit then critChance = 1 end -- (CLASS BUILDS) FAMILY: Bolt Action's first hit on each enemy
        if mech.SURGEON and not isWeakSpot then critChance = 0 end -- Surgeon's Hand: body shots never crit
        if mech.U_DEADEYE then critChance = isWeakSpot and 1 or 0 end -- (0.62 playstyle keystone Bullseye)
        -- (0.66 map mod Steel Skin; MAP PACING 2026-10-31: "can't be crit" was a ~1.5x kill time on a crit kit -> PoE's version, crits
        -- still land but their EXTRA damage is cut by the mod's value: 30% at T1 .. 48% at T12; other modes keep "no crits")
        local steel = 0
        if FloorMods.Has(DungeonRuns.Attr(player, "Mods"), "STEEL_SKIN") then
            if type(DungeonRuns.Attr(player, "ModScale")) == "number" then steel = math.clamp(CombatServer.ModV(player, "STEEL_SKIN"), 0, 1) else critChance = 0 end
        end
        local isCrit = (math.random() < critChance)
        if isCrit then damage *= 1 + (stats.CritMultiplier - 1) * (1 - steel); CombatServer.RS.Add(player, "Crits") end
        if mech.P_UNTOUCHED and isCrit and now - (st.P_HurtAt or -99) >= 4 then damage *= 1.8 end -- (far passive Untouched Aim)
        if mech.P_FEEDBACK and not isCrit then damage *= 0.9 end -- (far passive Feedback Loop)
        if actx then
            actx.Crit = isCrit
            damage *= Asc.CritMult(stats, actx)
        end

        -- Execute thresholds: Giantslayer prefix, the Executioner keystone, Culling affixes, the Guillotine trait.
        local cull = 0
        if procId == "Giantslayer" then cull = ItemData.CullThreshold(weapon) end
        if mech.EXECUTIONER then cull = math.max(cull, 0.10) end
        local creed = mech.U_CREED and model:GetAttribute("IsBoss") ~= true -- (Executioner's Creed: past the usual 25% cap)
        cull = math.min(0.25, math.max(cull, cond.ExecutePct or 0, traitCull))
        if creed then cull = math.max(cull, 0.25) end
        cull = math.max(cull, CombatServer.CB.Sig.Cull(player, stats, model)) -- (CLASS BUILDS) SIGNATURE: Execute

        local finalDmg, killed = DealEnemyDamage(player, state, model, damage, stats, {
            Kind = "Hit", IsWeakSpot = isWeakSpot, IsCrit = isCrit, Position = hitPosition, Cull = cull, Elem = elemTag,
            DType = CombatServer.DT.MainType(tParts), -- (UPDATE 8 OFFENSE)
        })
        local newHealth = killed and 0 or (model:GetAttribute("Health") or 0)
        if pellets > 1 then -- (HEAVY ROUNDS) pellets of this pull landed so far
            local hs = state :: any
            if hs.HR_Pull ~= hs.P_ShotAt then hs.HR_Pull, hs.HR_N = hs.P_ShotAt, 0 end
            hs.HR_N += 1
        end
        if killed then -- (HEAVY ROUNDS) the leftover (a shotgun kill also carries a share of the pellets still to come: they'd hit a corpse)
            local rest = (pellets > 1) and math.max(0, pellets - ((state :: any).HR_N or pellets)) * damage * ItemData.HEAVY_BLAST_KEEP or 0
            local rmK = 0
            for _, t in ipairs(CombatServer.DT.ORDER) do rmK += tParts[t] or 0 end
            CombatServer.Off.HeavyCarry(player, state, stats, weapon, model, math.max(0, damage - currentHealth) + rest, (rmK > 0) and rmK or 1, hitPosition)
        end
        if st.ExoMawBurn then -- (Dragon's Maw: a point-blank hit sets it burning)
            st.ExoMawBurn = nil
            if not killed then ApplyBurn(player, model, finalDmg * 0.6, 3, 1) end
        end
        if killed and exo == "TwinFang" then st.ExoFangUntil = now + 2 end
        if killed and exo == "LastWord" and isWeakSpot then
            st.ExoWord = (now < (st.ExoWordUntil or 0)) and math.min(3, (st.ExoWord or 0) + 1) or 1
            st.ExoWordUntil = now + 6
        end
        if mech.U_VAMPIRE and state.Health > 0 and finalDmg and finalDmg > 0 then -- (Blood Rounds)
            state.Health = math.min(state.MaxHealth, state.Health + math.min(finalDmg * 0.02, state.MaxHealth * 0.01))
        end
        if killed and mech.U_MOMENTUM then
            st.U_Mom = (now < (st.U_MomUntil or 0)) and math.min(6, (st.U_Mom or 0) + 1) or 1
            st.U_MomUntil = now + 5
        end
        do -- class passives after the hit (see CLASS PASSIVES above)
            if isCrit and mech.P_ION_CHARGE then
                st.P_Ion = (now < (st.P_IonUntil or 0)) and math.min(3, (st.P_Ion or 0) + 1) or 1
                st.P_IonUntil = now + 4
            end
            if isCrit and mech.P_BLOODLETTER and not killed then
                InflictAilment("Bleed", player, state, stats, model, finalDmg * pellets, hitPosition, 1)
            end
            if killed then
                if mech.P_CONFIRMED_KILL then st.P_ConfirmUntil = now + 3 end
                if mech.P_ADRENALINE then st.P_RushUntil = now + 3 end
                if mech.P_BATTERING_RAM then
                    st.P_Ram = (now < (st.P_RamUntil or 0)) and math.min(3, (st.P_Ram or 0) + 1) or 1
                    st.P_RamUntil = now + 6
                end
            end
            if isCrit and mech.P_FEEDBACK and now - (st.P_FeedAt or 0) >= 0.1 and state.Health > 0 then
                st.P_FeedAt = now
                state.Health = math.min(state.MaxHealth, state.Health + state.MaxHealth * 0.012)
            end
        end
        if killed and isWeakSpot and not model:GetAttribute("IsPracticeDummy") then
            CombatServer.KillJob(player, state, "WeakKill", model:GetAttribute("Fodder") == true) -- (UPDATE 8: packs)
            if DungeonRuns.IsProxy(model) then DungeonRuns.OnWeakKill(player, model) end
        end
        if killed then
            -- chain-kill stacks, Bloodhound, Chain of Command, overkill carried into the next hit
            local cap, dur = mech.RAMPAGE and 10 or 5, (mech.RAMPAGE and 6 or 4) + (mech.BUTCHER and 3 or 0)
            st.ChainStacks = math.min(cap, ((st.ChainUntil or 0) >= now and (st.ChainStacks or 0) or 0) + 1)
            st.ChainUntil = now + dur
            if weapon and weapon.UniqueTrait and weapon.UniqueTrait.Id == "Bloodhound" then st.HoundUntil = now + 4 end
            do -- 0.51 kill traits
                local tid = weapon and weapon.UniqueTrait and weapon.UniqueTrait.Id
                if tid == "Momentum" then
                    st.MomentumN = (now <= (st.MomentumUntil or 0)) and math.min(5, (st.MomentumN or 0) + 1) or 1
                    st.MomentumUntil = now + 4
                elseif tid == "QuickLoader" then
                    state.CurrentMag = math.min(state.MaxMag or 0, (state.CurrentMag or 0) + 2)
                elseif tid == "ReapersToll" then
                    state.CurrentMag = state.MaxMag or state.CurrentMag
                    state.IsReloading = false
                elseif tid == "SecondWind" and state.Health > 0 then
                    state.Health = math.min(state.MaxHealth, math.round((state.Health + state.MaxHealth * 0.06) * 10) / 10)
                end
            end
            if mech.CHAIN_OF_COMMAND and isWeakSpot then st.CommandHits = 3 end
            local carryShare = (cond.OverkillCarry or 0) + ((weapon and weapon.UniqueTrait and weapon.UniqueTrait.Id == "Overflow") and 1 or 0) + (mech.BUTCHER and 1 or 0)
            if carryShare > 0 then
                local excess = math.max(0, damage - currentHealth)
                st.CarryDmg = math.min(damage, excess * carryShare)
                st.CarryUntil = now + 3
            end
        end

        -- (2026-10-14) no server hit-flash Highlight any more: Roblox draws one Highlight per model, so it hid the enemy's
        -- outline for every player who saw it; the shooter's client flashes the outline itself (DungeonClient.PredictHit)

        -- Launcher / plasma splash (weapons with a built-in blast radius).
        if stats.ExplosionRadius and stats.ExplosionRadius > 0 then
            Explode(player, state, stats, hitPosition, finalDmg * 0.75 * (1 + stats.ExplosionDamage), stats.ExplosionRadius, Color3.fromRGB(255, 140, 40), "Explosion", model, true)
        end

        -- Fixation: build stacks (once per trigger pull for shotguns), detonate at max.
        if procId == "Fixation" and consumesAmmo then
            local maxStacks = PROC.FixMaxStacks
            if (st.FixStacks or 0) >= maxStacks then
                if model.Parent and not model:GetAttribute("Dead") then
                    BlastFx(player, hitPosition, 3, ItemData.WeaponProcs.Fixation.Color)
                    DealEnemyDamage(player, state, model, finalDmg * pellets * PROC.FixBlastPct * (proc.Power or 1), stats, { Kind = "Arc" })
                end
                st.FixStacks = 0
            else
                st.FixStacks = math.min(maxStacks, (st.FixStacks or 0) + ItemData.FixationGain(weapon))
            end
            st.FixLast = now
        end

        -- Prefix procs (Burn / Freeze / Bleed / Decay / Echo) and keystone procs.
        if not killed then
            RollOnHitEffects(player, state, stats, weapon, model, finalDmg, hitPosition, pellets)
            CombatServer.Off.TypeAilments(player, state, stats, weapon, model, finalDmg, hitPosition, CombatServer.CB.Family.AilPellets(stats, weapon, pellets), tParts) -- (UPDATE 8 OFFENSE; (CLASS BUILDS) FAMILY: auto-shotgun pellets)
            CombatServer.CB.Sig.AfterHit(player, state, stats, model, finalDmg * pellets, hitPosition, pellets, consumesAmmo) -- (CLASS BUILDS) SIGNATURE
        end
        RollUniqueTrait(player, state, stats, weapon, model, finalDmg, hitPosition, isWeakSpot, isCrit)
        TreeHitEffects(player, state, stats, model, finalDmg, hitPosition, isWeakSpot, isCrit, pellets, consumesAmmo)
        if actx then Asc.PostHit(player, state, stats, model, actx, finalDmg * pellets, hitPosition, pellets, consumesAmmo) end
        -- high-caliber guns pierce into the enemies behind (once per trigger pull, body-shot damage)
        if consumesAmmo then
            PierceShot(player, state, stats, weapon, model, damage / ((isWeakSpot and stats.WeakSpotMultiplier or 1) * (isCrit and stats.CritMultiplier or 1)), hitPosition)
        end
        CombatServer.CB.Sig.PreShotFx(player, stats, model) -- (CLASS BUILDS) SIGNATURE: Mark (full-damage chains / forks)
        if stats.ShotFx then -- (UPDATE 8 OFFENSE phase 3: the gun's shot mods -- chain / fork / ricochet / volley / impact / mark)
            CombatServer.Off.ShotModFx(player, state, stats, weapon, model, damage, tParts, hitPosition, isWeakSpot, isCrit, killed, pellets)
        end
        if stats.Zenith then -- (CHASE ITEMS 2026-11-06: Glass Halo refund, Saint's Ricochet, Furnace vent, Bloomshot, Lattice)
            local rmZ = 0
            for _, t in ipairs(CombatServer.DT.ORDER) do rmZ += tParts[t] or 0 end
            CombatServer.Zen.PostHit(player, state, stats, weapon, model, damage, rmZ, hitPosition, isWeakSpot, realWeak, isCrit, killed, pellets, consumesAmmo)
        end
        CombatServer.CB.Family.PostHit(player, state, stats, weapon, model, finalDmg, damage, tParts, hitPosition, isWeakSpot, killed, pellets, consumesAmmo) -- (CLASS BUILDS) FAMILY

        -- Life leech (skill tree / gear)
        if stats.LifeLeechPct and stats.LifeLeechPct > 0 then
            local leech = stats.LifeLeechPct * ((mech.LAST_BASTION and lowLife) and 3 or 1) -- (Last Bastion: x3 when low)
            state.Health = math.min(state.MaxHealth, math.round((state.Health + finalDmg * leech) * 10) / 10)
        end

        if newHealth <= 0 then
            -- Kill: XP / level / stats tracking changed, so send the full state (same as before)
            stateSync:FireClient(player, state)
        else
            CombatServer.SendCombatDelta(player, state)
        end
    end)
end

return CombatServer
