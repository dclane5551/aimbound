--!nocheck
-- ============================================================================================
-- WORLD ALERTS (UPDATE 7 B7; placeholder names): timed events that are the SAME in every server -- the schedule comes from
-- UTC time, not from a server's start, so no messaging is needed. Every SLOT seconds (from OFFSET) an alert runs for LENGTH
-- seconds; which one is picked from the slot number (WorldAlerts.At). The client shows a banner (active, or "in mm:ss" for the
-- last LEAD seconds before one); the server reads WorldAlerts.Current() where each one acts:
--   EXOTIC_SURGE   boss exotic chance x2                                     (CombatServer kill rewards)
--   ENCOUNTER_RUSH an encounter on every eligible floor                      (DungeonRuns)
--   WORLD_SURGE    floors in one world pay +50% loot luck and +25% rewards   (CombatServer ComputeDropLuck / kill rewards)
--   ELITE_HUNT     +50% elites on every floor, elite kills pay double rewards (DungeonRuns AtlasElite / CombatServer rewardMult)
--   CURRENCY_RAIN  encounters pay double currency, bosses double Storm Core  (CombatServer EncounterReward / kill rewards)
--   CONTRACT_HUNT  the Bounty Contract turns up on every eligible floor      (DungeonRuns SpawnContract)
-- Studio: workspace attr DevWorldAlert = an id (WORLD_SURGE:Fire for a world) forces one now.
-- ============================================================================================
local WorldAlerts = {}

WorldAlerts.ON = true
WorldAlerts.SLOT = 2 * 3600
WorldAlerts.LENGTH = 45 * 60
WorldAlerts.OFFSET = 15 * 60 -- (slots start at :15 past even UTC hours)
WorldAlerts.LEAD = 10 * 60
WorldAlerts.COLOR = Color3.fromRGB(120, 220, 255)
WorldAlerts.Defs = {
    EXOTIC_SURGE = { Name = "RELIC SURGE", Text = "double relic chance from bosses" },
    ENCOUNTER_RUSH = { Name = "ENCOUNTER RUSH", Text = "an encounter on every floor that can have one" },
    WORLD_SURGE = { Name = "WORLD SURGE", Text = "floors in %s pay +50% loot luck and +25% rewards" }, -- (%s = the world)
    ELITE_HUNT = { Name = "ELITE HUNT", Text = "50% more elites, and elite kills pay double rewards" },
    CURRENCY_RAIN = { Name = "CURRENCY RAIN", Text = "encounters pay double currency, bosses double Wildfire Cores" },
    CONTRACT_HUNT = { Name = "MANHUNT", Text = "your Marked Man turns up on every floor it can (level 80+)" },
}
WorldAlerts.Order = { "EXOTIC_SURGE", "ENCOUNTER_RUSH", "WORLD_SURGE", "ELITE_HUNT", "CURRENCY_RAIN", "CONTRACT_HUNT" }
local WORLDS = { "Fire", "Ice", "Cyber", "Void", "Storm", "Dream", "Flats" }
do
    local ok, WB = pcall(require, script.Parent:WaitForChild("WorldBiomes"))
    if ok then for _, id in ipairs(WB.LIST) do table.insert(WORLDS, id) end end
end

local function Now(): number return workspace:GetServerTimeNow() end

-- the alert of slot n: { Id, Biome?, Start, End }
function WorldAlerts.At(n: number): any
    local r = Random.new(n * 9973 + 11)
    local id = WorldAlerts.Order[r:NextInteger(1, #WorldAlerts.Order)]
    local start = n * WorldAlerts.SLOT + WorldAlerts.OFFSET
    return { Id = id, Biome = (id == "WORLD_SURGE") and WORLDS[r:NextInteger(1, #WORLDS)] or nil, Start = start, End = start + WorldAlerts.LENGTH }
end

-- the alert running now (or nil)
function WorldAlerts.Current(t: number?): any
    if not WorldAlerts.ON then return nil end
    t = t or Now()
    local dev = game:GetService("RunService"):IsStudio() and workspace:GetAttribute("DevWorldAlert")
    if type(dev) == "string" and dev ~= "" then
        local id, biome = string.match(dev, "^([%u_]+):?(%w*)$")
        if id and WorldAlerts.Defs[id] then return { Id = id, Biome = (biome ~= "" and biome) or "Fire", Start = t - 60, End = t + WorldAlerts.LENGTH } end
    end
    local n = math.floor((t - WorldAlerts.OFFSET) / WorldAlerts.SLOT)
    local a = WorldAlerts.At(n)
    return (t >= a.Start and t < a.End) and a or nil
end

-- the next alert that hasn't started yet
function WorldAlerts.Next(t: number?): any
    t = t or Now()
    local n = math.floor((t - WorldAlerts.OFFSET) / WorldAlerts.SLOT)
    local a = WorldAlerts.At(n)
    if t < a.Start then return a end
    return WorldAlerts.At(n + 1)
end

-- is this alert running now? (id, optional biome for WORLD_SURGE)
function WorldAlerts.Is(id: string, biome: string?): boolean
    local a = WorldAlerts.Current()
    if not a or a.Id ~= id then return false end
    if id == "WORLD_SURGE" then return biome ~= nil and a.Biome == biome end
    return true
end

function WorldAlerts.Text(a: any): string
    local d = a and WorldAlerts.Defs[a.Id]
    if not d then return "" end
    local name = a.Biome
    if name then
        local ok, DG = pcall(require, script.Parent:WaitForChild("DungeonGenerator"))
        local t = ok and DG.BIOME_TITLES and DG.BIOME_TITLES[name]
        if type(t) == "table" then t = t.Title or t.Name or t[1] end -- (the titles table holds { Title, ... })
        name = (type(t) == "string" and t) or string.upper(name)
    end
    return (string.gsub(d.Text, "%%s", name or "")) -- (not string.format: the texts have plain "%" signs)
end

return WorldAlerts
