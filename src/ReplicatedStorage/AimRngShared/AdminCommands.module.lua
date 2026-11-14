--!nocheck
-- ADMIN COMMANDS (0.65, owner: "new admin menu for ALL commands"). The list the admin menu (AdminPanel, F6 -> COMMANDS)
-- draws its buttons from. Each entry runs DevCommands.Run(target, Id, args...) on the server (AdminService checks the
-- caller is an admin first), or an admin-only action AdminService handles itself (Server = true).
-- Pick lists are built from the game's own data every time the menu opens (guns, rarities, biomes, bosses, cosmetics,
-- ...), so anything added to the game shows up here without touching this file.
--   arg = { Name, Kind = "num" | "text" | "pick" | "bool", Default?, Options = function() -> { string } (pick) }
--   Studio = true: only works in Studio (test tooling that would be wrong on a live server)
local Shared = script.Parent

local function Req(name) return require(Shared:WaitForChild(name)) end
local function Keys(t)
    local out = {}
    for k in pairs(t or {}) do table.insert(out, tostring(k)) end
    table.sort(out)
    return out
end

local O = {}
function O.Rarity() return table.clone(Req("ItemData").Rarities) end
function O.GemRarity() return table.clone(Req("ItemData").LEGACY_RARITIES) end -- (UPDATE 8: gems keep the old ladder)
function O.Difficulty() return table.clone(Req("ItemData").DifficultyOrder) end
function O.Biome() return table.clone(Req("DungeonGenerator").BIOMES) end
function O.Gun()
    local out = {}
    for id, w in pairs(Req("ItemData").BaseWeapons) do if type(w) == "table" then table.insert(out, id) end end
    table.sort(out)
    return out
end
function O.Proc() local t = table.clone(Req("ItemData").WeaponProcOrder); table.insert(t, 1, "none"); return t end
function O.Melee() return Keys(Req("ItemData").MeleeWeapons) end
function O.Exotic() local t = Keys(Req("ItemData").Exotics); table.insert(t, 1, "all"); return t end
function O.Boss()
    local out = {}
    for _, b in ipairs(Req("BossTrials").Bosses) do table.insert(out, b.Id) end
    return out
end
function O.Class()
    local out = {}
    for id in pairs(Req("ClassData").ById) do table.insert(out, id) end
    table.sort(out)
    return out
end
function O.Archetype() return Keys(Req("DungeonGenerator").BotArchetypes) end
function O.Cosmetic()
    local out = {}
    for _, e in ipairs(Req("Cosmetics").All()) do table.insert(out, e.Cat .. ":" .. e.Id) end
    return out
end
function O.Menu() return { "Dungeons", "Challenges", "Season", "Skills", "Inventory", "Shop", "Upgrade", "Index", "Armory", "Cosmetics", "CosmeticShop", "Trade", "Settings", "Roll" } end

local AdminCommands = { Options = O }

AdminCommands.Groups = { "Player", "Progress", "Items", "Cosmetics", "Runs", "World", "Debug" }
AdminCommands.GroupColor = {
    Player = Color3.fromRGB(90, 200, 255), Progress = Color3.fromRGB(120, 230, 140), Items = Color3.fromRGB(255, 180, 70),
    Cosmetics = Color3.fromRGB(255, 120, 200), Runs = Color3.fromRGB(255, 110, 90), World = Color3.fromRGB(180, 140, 255),
    Debug = Color3.fromRGB(150, 160, 180),
}

local function N(name, def) return { Name = name, Kind = "num", Default = def } end
local function T(name, def) return { Name = name, Kind = "text", Default = def } end
local function P(name, opts, def) return { Name = name, Kind = "pick", Options = O[opts], Default = def } end
local function B(name, def) return { Name = name, Kind = "bool", Default = def } end

AdminCommands.List = {
    -- PLAYER (AdminService's own actions)
    { Id = "goto", Label = "Go to them", Group = "Player", Server = true, Desc = "Teleport yourself to this player." },
    { Id = "bring", Label = "Bring them", Group = "Player", Server = true, Desc = "Teleport this player to you." },
    { Id = "kick", Label = "Kick", Group = "Player", Server = true, Desc = "Remove this player from the server (they can rejoin).", Args = { T("Reason", "Kicked by an admin") } },
    { Id = "heal", Label = "Heal", Group = "Player", Desc = "Full health." },
    { Id = "nodeath", Label = "No death", Group = "Player", Desc = "Health stops at 1 instead of dying (damage still lands).", Args = { B("On", true) } },
    { Id = "hurt", Label = "Hurt", Group = "Player", Desc = "Real damage through the normal damage path (lives / death).", Args = { N("Damage", 99999) } },
    { Id = "state", Label = "Show state", Group = "Player", Desc = "Level, points, gold, health and the equipped gun." },
    { Id = "stats", Label = "Show stats", Group = "Player", Desc = "The compiled stats the server uses (JSON)." },
    { Id = "menu", Label = "Open a menu", Group = "Player", Desc = "Open a hub menu on their screen, as its station would.", Args = { P("Menu", "Menu", "Dungeons") } },

    -- PROGRESS
    { Id = "level", Label = "Give levels", Group = "Progress", Desc = "Level up (+ the skill and stat points those levels give).", Args = { N("Levels", 10) } },
    { Id = "gold", Label = "Give gold", Group = "Progress", Args = { N("Gold", 10000) } },
    { Id = "bp", Label = "Give BOUND points", Group = "Progress", Args = { N("Points", 100) } },
    { Id = "sp", Label = "Give skill points", Group = "Progress", Args = { N("Points", 10) } },
    { Id = "mats", Label = "Give materials", Group = "Progress", Desc = "This many of every material and crafting currency.", Args = { N("Each", 100) } },
    { Id = "seasonxp", Label = "Season XP", Group = "Progress", Args = { N("XP", 5000) } },
    { Id = "class", Label = "Set class", Group = "Progress", Desc = "Become this class (free; refunds the tree).", Args = { P("Class", "Class") } },
    { Id = "trialbest", Label = "Boss trial best", Group = "Progress", Desc = "Pretend the Archon trial was cleared to this tier (specialization points).", Args = { N("Tier", 1) } },
    { Id = "ascbest", Label = "Proving best", Group = "Progress", Desc = "The Proving progress (specialization points = 2 x this).", Args = { N("Tiers", 4) } },
    { Id = "atlas", Label = "Map tree points", Group = "Progress", Desc = "Set the map-tree point sources (best rift tier, maps done).", Args = { N("Rift best", 10), N("Maps done", 20) } },
    { Id = "wkills", Label = "Weapon mastery kills", Group = "Progress", Args = { P("Gun", "Gun"), N("Kills", 1000) } },
    { Id = "tree", Label = "Allocate tree nodes", Group = "Progress", Desc = "Node ids, comma separated (no point / path checks).", Args = { T("Nodes", "") } },

    -- ITEMS
    { Id = "weapon", Label = "Give a gun", Group = "Items", Desc = "Make and equip a gun at their level.", Args = { P("Prefix", "Proc", "none"), P("Rarity", "Rarity", "Rare"), P("Gun", "Gun") } },
    { Id = "exotic", Label = "Give a relic", Group = "Items", Args = { P("Exotic", "Exotic"), P("Rarity", "Rarity", "Relic"), T("'equip' to wear it", "") } },
    { Id = "melee", Label = "Give a melee", Group = "Items", Args = { P("Melee", "Melee") } },
    { Id = "meleeskins", Label = "Every melee + skin", Group = "Items" },
    { Id = "gem", Label = "Give a gem", Group = "Items", Args = { P("Rarity", "Rarity", "Rare"), T("Unique id (optional)", "") } },
    { Id = "sigil", Label = "Give a map (sigil)", Group = "Items", Args = { N("Tier", 1), T("Rarity (Normal/Magic/Rare/Unique)", "") } },
    { Id = "stuff", Label = "Random stash loot", Group = "Items", Desc = "Random weapons and gear straight into the stash.", Args = { N("Weapons", 10), N("Gear", 20) } },
    { Id = "drop", Label = "Drop loot here", Group = "Items", Desc = "Ground loot in front of them (e.g. Rare,Mythic,Gem:Epic,Gear:Rare).", Args = { T("Drops", "Common,Uncommon,Rare,Mythic,Gear:Rare,Gear:Mythic") } },
    { Id = "chest", Label = "Open chests", Group = "Items", Args = { T("Supply / Vault / Boss", "Vault"), N("Count", 1) } },

    -- COSMETICS
    { Id = "cosmetic", Label = "Give + wear a cosmetic", Group = "Cosmetics", Desc = "Any cosmetic in the catalog (gifts are on the GIFTS tab too).", Args = { P("Cosmetic", "Cosmetic") } },
    { Id = "barstyle", Label = "Health bar style", Group = "Cosmetics", Args = { T("Style id", "Standard") } },

    -- RUNS
    { Id = "floor", Label = "Start a floor", Group = "Runs", Desc = "Jump straight into a dungeon floor.", Args = { N("Floor", 5), P("Biome", "Biome", "Fire"), P("Difficulty", "Difficulty", "Easy") } },
    { Id = "killall", Label = "Kill every enemy", Group = "Runs", Desc = "Everything on their floor, through the real kill path (loot, XP)." },
    { Id = "hub", Label = "Send to hub", Group = "Runs", Desc = "Leave the run as the hub teleport does." },
    { Id = "packsoff", Label = "Packs off", Group = "Runs", Desc = "Packs are the normal game now (UPDATE 8). This turns them OFF on their solo floors for a comparison: no fodder packs, no loot stream. Starts on the next floor; resets when they leave the server.", Args = { B("Off", true) } },
    { Id = "linkedoff", Label = "Linked rooms off", Group = "Runs", Desc = "Linked rooms are the normal game (every regular floor = 3 rooms + a side room joined by paths, counting as 2 floors). This turns them OFF for this player for a comparison: single-room floors again. Starts on the next floor; resets when they leave the server.", Args = { B("Off", true) } },
    { Id = "bosstrial", Label = "Start a boss trial", Group = "Runs", Args = { P("Boss", "Boss"), N("Tier", 1) } },
    { Id = "asctrial", Label = "Start Proving", Group = "Runs", Args = { N("Tier", 1), N("Floor", 1) } },
    { Id = "partyrun", Label = "Party run (solo)", Group = "Runs", Args = { N("Bot skill", 4), P("Biome", "Biome", "Fire"), P("Difficulty", "Difficulty", "Easy") } },
    { Id = "partytrial", Label = "Party trial (solo)", Group = "Runs", Args = { T("Boss id or Asc", "Archon"), N("Tier", 1) } },
    { Id = "roster", Label = "Force bot types", Group = "Runs", Desc = "Only these bots on the next floors (whole server). Empty = normal.", Args = { P("Bot", "Archetype") } },
    { Id = "runstats", Label = "Run summary so far", Group = "Runs" },

    -- WORLD
    { Id = "storm", Label = "Start a Loot Storm", Group = "World", Desc = "A server-wide Loot Storm for 5 minutes." },
    { Id = "hideout", Label = "Hideout action", Group = "World", Desc = "Run a hideout action as them (Enter, Leave, ...).", Args = { T("Action", "Enter"), T("Arg", ""), T("Arg 2", "") } },

    -- DEBUG
    { Id = "pity", Label = "Target-loot meters", Group = "Debug", Args = { T("Set (e.g. DW=1,IG=0.5)", "") } },
    { Id = "loottest", Label = "Loot roll test", Group = "Debug", Desc = "Roll drops and count the rarities (nothing kept).", Args = { P("Difficulty", "Difficulty", "Torment"), T("Floor kind", "Top3"), N("Rolls", 30) } },
    { Id = "powercurve", Label = "Power curve", Group = "Debug", Desc = "DPS / toughness index by level against the tables." },
    { Id = "lostloot", Label = "Fake lost loot", Group = "Debug", Args = { P("Rarity", "Rarity", "Mythic") } },
    { Id = "passives", Label = "Equip passives", Group = "Debug", Args = { T("Ids", "") } },
    { Id = "socket", Label = "Socket a gem", Group = "Debug", Args = { T("Socket id", ""), P("Rarity", "GemRarity", "Legendary"), T("Unique id", "") } },
    { Id = "rejoin", Label = "Save + reload", Group = "Debug", Studio = true, Desc = "Save, forget and load their save back." },
    { Id = "duelbot", Label = "Duel a bot", Group = "Debug", Studio = true, Args = { T("Arena", "") } },
    { Id = "tradebot", Label = "Trade bot", Group = "Debug", Studio = true, Args = { T("start / offer / ready / confirm / state", "start") } },
}

AdminCommands.ById = {}
for _, c in ipairs(AdminCommands.List) do
    c.Args = c.Args or {}
    AdminCommands.ById[c.Id] = c
end

-- the typed values the server passes on (empty = nil, so the command uses its own default)
function AdminCommands.Coerce(cmd, raw)
    local out = {}
    for i, arg in ipairs(cmd.Args) do
        local v = type(raw) == "table" and raw[i] or nil
        if arg.Kind == "num" then
            v = tonumber(v)
        elseif arg.Kind == "bool" then
            v = (v == true or v == "true")
        else
            v = (type(v) == "string" and v ~= "") and string.sub(v, 1, 400) or nil
        end
        out[i] = v
    end
    return out
end

return AdminCommands
