--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "AimRngNet"

local EVENT_NAMES = {
    "ReportHit",
    "RunSummary", -- (RunStats: the end-of-run summary)
    "HitConfirmed",
    "SyncPlayerState",
    "TeleportPlayer",
    "LootAnnounce",
    "DropFeed", -- (0.97: a top-rarity drop, shown to everyone in the server)
    "Spoils", -- (UPDATE 7 B4: a Shared Spoils session to its pickers)
    "GuildInvite", -- (UPDATE 7 B9: (guildId, name, from) to an invited player)
    "OpenMenu",
    "DungeonUpdate",
    "LevelUp",
    "PlayerDamaged",
    "ShopRefreshed",
    "ReloadWeapon",
    "MeleeSlash",
    "DungeonVictory",
    "CombatDelta",
    "PortalNextFloor",
    "ResendGroundLoot",
    "CosmeticDrop",
    "SaveSettings",
    -- private dungeons (see DungeonRuns)
    "EnemyHitPlayer",
    "EnemyPositions",
    "EnemyFlag",
    "EnemySummon",
    "OpenChest",
    "HazardHit",
    "CombatFx",
    "MaterialsGained",
    "PartyUpdate",
    "PartyRoomsChanged",
    "UseEvent",
    "LootDropped",
    "LootPicked",
    "LootCleared",
    "DpsTick",
    "AimPitch", -- party runs: where you look up/down (spectators see your view)
    "MoveState", -- client -> server: sliding on / off (Player attribute "Sliding": every client poses the body)
    "LivesAction", -- client -> server: "GiveUp" | "UseCredit" | "Revive" (Studio only, free)
    "RunLootLost", -- server -> client: your run loot was lost (open the recovery window)
    "ExtractRun", -- client -> server: leave through the extraction portal (keeps run loot)
    "BarStyleAction", -- client -> server: "Equip", styleId | "Buy", styleId (health bar cosmetics, BarStyles)
    "RecoverAction", -- client -> server: "Pick", index | "Free", index (only while the product isn't set up)
    "BuyRebirthShard", -- client -> server: buy a Rebirth Shard (Robux product; free in Studio while ProductId is 0)
    "SpectateFeed", -- server -> watcher (0.62 SPECTATE): ("Floor", cfg, look) | ("Roster", list) | ("Stop", why)
    "TradeUpdate", -- server -> client: ("Request" | "Session" | "Closed" | "Done" | "Declined", data) (TradeService)
    "HideoutUpdate", -- server -> client: hideout layout / visit requests / kicks (Hideouts)
    "PvpUpdate", -- server -> client: ("Request" | "Declined" | "Duel" | "Closed" | "Hit" | "Hurt" | "Frag" | "BotShot", data) (PvpService)
    "PvpShot", -- client -> server: (hitPos, didHit) one standardized duel shot (PvpService checks it)
    "ReportError", -- client -> server: (message, trace) a client script error for the live error log (ErrorLog)
}

local FUNCTION_NAMES = {
    "AtlasAction", -- client -> server: ("Allocate" | "Refund", nodeId) the MAP TREE (AtlasService)
    "GetPlayerState",
    "TradeAction", -- ("Request", userId) | ("Respond", fromUserId, accept) | ("SetItem", kind, uid, on) | ("SetGold", n) |
                   -- ("Ready", on) | ("Confirm") | ("Cancel") -> ok, message (TradeService)
    "PvpAction", -- duels: ("Challenge", userId, arenaId, wager) | ("Respond", fromUserId, accept) | ("SetItem", kind, uid, on) |
                 -- ("Ready", on) | ("Confirm") | ("Cancel") | ("Forfeit") -> ok, message (PvpService)
    "SpectateAction", -- (0.62 SPECTATE) ("List") -> live runs | ("Watch", userId) | ("Stop")
    "HideoutAction", -- hideout: Enter / Leave / Visit / RequestVisit / RespondVisit / Place / Move / Remove / Buy (Hideouts)
    "ChooseClass", -- passive tree v4: (classId) -> ok, message (SkillTreeServer; first pick free, then a Rebirth Shard)
    "AscendancyAction", -- ("Choose", ascId) | ("Allocate" | "Refund", nodeId) -> ok, message (SkillTreeServer)
    "AvatarAction", -- character creator: Preview / Save / Revert / Get (AvatarService)
    "SeasonAction", -- season pass: ("BuyPremium") -> ok, message (CombatServer.InitSeasonPass)
    "AdminAction", -- admin gift panel: Check / Players / Owned / Give / Take (AdminService; admins only)
    "CosmeticAction", -- cosmetics shop / locker: ("Equip" | "Buy", category, id) -> ok, message (CombatServer)
    "ColorwayAction", -- (0.93) ("Buy", setKind, v) | ("Use", setKind, v, ref?) | ("Points", packId) -> ok, message (CombatServer)
    "RollWeaponRNG",
    "EquipWeapon",
    "AllocateSkillNode",
    "AllocateSkillNodes", -- (QOL M2: the tree's APPLY -- every pending node at once, validated as a set; SkillTreeServer)
    "PassiveEquip", -- (SkillTreeServer: the ★ PASSIVES menu)
    "SetPityTargets", -- (CombatServer: TARGET LOOT picks)
    "UpgradeWeapon",
    "StartDungeonRaid",
    "RevisitFloor",
    "SellWeapon",
    "QuickSellRarity",
    "SetAutoSellThreshold",
    "SetGemAutoSalvage",
    "ToggleItemLock",
    "AllocateStatPoint",
    "ResetAttributes", -- refund every allocated attribute point (character panel RESET)
    "EquipGear",
    "UnequipGear",
    "SellGear",
    "Buyback", -- (QOL2 I3: ("List") / ("Buy", uid); AimRngServer/Buyback)
    "BuyShopItem",
    "GetShopStock",
    "Reload",
    "PerformMelee",
    "EquipGlove",
    "BuyGlove",
    "EquipKnife",
    "BuyKnife",
    "EquipTitle",
    "ClaimTitle",
    "DismantleItem",
    "ForgeReroll",
    "ForgeLevelUp",
    "ForgeCraft", -- (0.61f FORGE CRAFTING: Augment / Purge / Ascend / Bench)
    "EquipCosmetic",
    "RespecSkillTree",
    "RefundSkillNode",
    "ExpertiseAction", -- (2026-10-22) ("Pick", expertiseNodeId, effectId) / ("Refund", expertiseNodeId) (SkillTreeServer)
    "SocketGem",
    "UnsocketGem",
    "SalvageGem",
    "ChooseBoon",
    "StartDailyChallenge",
    "StartDailyLine", -- (UPDATE 7 B6) THE DAILY LINE (EndgameServer)
    "BeginTrial",
    "SubmitTrial",
    "GetChallengeData",
    "StartRift",
    "RunAgain", -- (QOL F1 2026-10-28) ("Info") -> what the RUN AGAIN button shows / ("Go") -> ok, why|result (RunAgain)
    "StartBossTrial", -- endgame Boss Trials (BossTrials / EndgameServer)
    "StartAscTrial", -- Trial of Ascension (AscensionTrials / EndgameServer)
    "PickupLoot",
    "PickupLootMany", -- (QOL L2 2026-10-28: PICK UP ALL NEARBY -- a list of drop ids -> how many were picked up)
    "EquipMeleeSkin",
    "EquipBest", -- stash button: best weapon by DPS, then the gear that raises it most (ties: survivability)
    "ClaimSeason",
    "PartyRequest",
    "MerchantBuy", -- (index) wandering merchant purchase (DungeonRuns)
    "EncounterAction", -- (UPDATE 7) ("Start") / ("Finish", ok, resets): the floor's run encounter (DungeonRuns + Encounters)
    "WeeklyAction", -- (UPDATE 7) ("Reroll", i): the weekly bounty board (Weekly / EndgameServer)
    "GuildAction", -- (UPDATE 7 B9) guilds (GuildService)
    "MarketAction", -- (UPDATE 7 C7) Browse / Mine / List / Cancel / Buy / Collect: the market (MarketService)
    "ProfileAction", -- (2026-10-20) ("Get", userId?) / ("List"): player profiles + aim stats (ProfileService)
    "ReferralAction", -- (2026-10-20) ("Get") -> the INVITE FRIENDS view (ReferralService)
    "PartyFinderAction", -- (2026-10-20) ("List") / ("Join", jobId, roomId): open parties from every server (PartyFinder)
    "SpoilsAction", -- (UPDATE 7 B4) ("Pick", sid, i): Shared Spoils (SharedSpoils)
    "DistrictAction", -- (UPDATE 7 B5) ("Buy", district, itemId): city district stalls (CombatServer)
    "ApexAction", -- (UPDATE 7 C1) ("Start", uber): the Apex Hunt (EndgameServer)
    "DropRulesAction", -- (UPDATE 7 C9) ("Set", list): DropRules (CombatServer)
    "CalibrationAction", -- (UPDATE 7 B2) ("Claim", gun, pick) / ("Pick", gun, tier, pick): Calibration (CombatServer)
    "RiftmodAction", -- (UPDATE 7) ("Fit", mod, gun) / ("Remove", gun) / ("Reroll", mod) / ("Salvage", mod): Riftmods (CombatServer)
    "BoundBuy", -- (2026-10-20) ("Revive") / ("Recover", lostIndex) / ("RebirthShard") / ("SeasonPremium") -> ok, msg: BOUND-point buys (CombatServer)
}

-- UnreliableRemoteEvents: cosmetic, high-rate, fine to drop one
local UNRELIABLE_NAMES = {
    "ShotFx", -- client -> server -> nearby clients: a shot's muzzle flash, tracer + sound on the shooter's gun
    "SpectatePos", -- server -> watcher (0.62 SPECTATE): enemy positions + health of the watched floor, ~8/s
    "SpecCam", -- (0.83 LIVE VIEW) watched client -> server -> watchers: (stamp, camera CFrame, FOV) ~30/s
    "SpecWorld", -- (0.83 LIVE VIEW) watched client -> server -> watchers: (stamp, enemy ids, positions) ~15/s (solo floors)
}

local Remotes = {}

local function GetOrCreateFolder(): Folder
    local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder?
    if not folder then
        if RunService:IsServer() then
            folder = Instance.new("Folder")
            folder.Name = FOLDER_NAME
            folder.Parent = ReplicatedStorage
        else
            folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 10) :: Folder?
            if not folder then
                folder = Instance.new("Folder")
                folder.Name = FOLDER_NAME
                folder.Parent = ReplicatedStorage
            end
        end
    end

    if RunService:IsServer() and folder then
        for _, name in ipairs(EVENT_NAMES) do
            if not folder:FindFirstChild(name) then
                local ev = Instance.new("RemoteEvent")
                ev.Name = name
                ev.Parent = folder
            end
        end
        for _, name in ipairs(FUNCTION_NAMES) do
            if not folder:FindFirstChild(name) then
                local rf = Instance.new("RemoteFunction")
                rf.Name = name
                rf.Parent = folder
            end
        end
        for _, name in ipairs(UNRELIABLE_NAMES) do
            if not folder:FindFirstChild(name) then
                local ev = Instance.new("UnreliableRemoteEvent")
                ev.Name = name
                ev.Parent = folder
            end
        end
    end

    return folder :: Folder
end

local folder = GetOrCreateFolder()

function Remotes.GetEvent(name: string): RemoteEvent
    local ev = folder:FindFirstChild(name) :: RemoteEvent?
    if not ev then
        ev = folder:WaitForChild(name, 10) :: RemoteEvent?
        if not ev and RunService:IsServer() then
            ev = Instance.new("RemoteEvent")
            ev.Name = name
            ev.Parent = folder
        end
    end
    if not ev then
        error("[AimRngRemotes] RemoteEvent not found: " .. name)
    end
    return ev
end

function Remotes.GetFunction(name: string): RemoteFunction
    local rf = folder:FindFirstChild(name) :: RemoteFunction?
    if not rf then
        rf = folder:WaitForChild(name, 10) :: RemoteFunction?
        if not rf and RunService:IsServer() then
            rf = Instance.new("RemoteFunction")
            rf.Name = name
            rf.Parent = folder
        end
    end
    if not rf then
        error("[AimRngRemotes] RemoteFunction not found: " .. name)
    end
    return rf
end

return Remotes
