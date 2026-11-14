--!nocheck
-- ============================================================================================
-- THE ARCHIVE (UPDATE 7 "DEPTH" A4, the collection log; vault "UPDATE 7 - Depth" + Loot Economy Plan section 5: "rarity
-- milestones ('first Mythic', 'first rarity 12') make rare drops feel like achievements"). Placeholder name ("Codex" is
-- already the save field of the Forge's Codex of Power).
-- PAGES, each a list of entries you fill in by playing; every page pays at its MILESTONES (found counts), automatically:
--   RARITIES  an item of each of the 5 rarities found, Relic included (owned items count: filled from your save; UPDATE 8)
--   EXOTICS   every exotic found (owned ones count)
--   BOSSES    every Boss Trial boss x tier cleared (from state.BossTrials: already in your save)
--   WORLDS    a floor cleared in every biome (counts from this update)
--   GUNS      every lineup gun found (StatsTracking.DiscoveredWeapons)
-- State: Archive = { Rarity = { [rank] = true }, Exotic = { [id] = true }, World = { [biome] = clears }, Paid = { [page] = n } } (saved).
-- The server fills it (CombatServer.ArchiveScan: on load, every drop, every 20 s) and pays milestones.
-- ============================================================================================
local ArchiveData = {}

ArchiveData.ON = true

local function ID() return require(script.Parent:WaitForChild("ItemData")) end
local function BT() return require(script.Parent:WaitForChild("BossTrials")) end

function ArchiveData.Ensure(state: any): any
    local a = type(state) == "table" and state.Archive
    if type(a) ~= "table" then a = {}; if type(state) == "table" then state.Archive = a end end
    a.Rarity = type(a.Rarity) == "table" and a.Rarity or {}
    a.Exotic = type(a.Exotic) == "table" and a.Exotic or {}
    a.World = type(a.World) == "table" and a.World or {}
    a.Paid = type(a.Paid) == "table" and a.Paid or {}
    return a
end

-- the pages: Id, Title, Color, Text, Milestones (found counts, ascending; the last = the whole page), Entries(state) ->
-- { { Key, Name, Found, Color? } }
ArchiveData.Pages = {
    { Id = "Rarities", Title = "RARITIES", Color = Color3.fromRGB(255, 196, 70), Milestones = { 3, 4, 5 }, -- (UPDATE 8 RARITY v4: 5 rarities; was 4 .. 15)
        Text = "An item of every rarity. Owning one counts.",
        Entries = function(state)
            local I = ID()
            local a = ArchiveData.Ensure(state)
            local out = {}
            for rank, name in ipairs(I.Rarities) do
                table.insert(out, { Key = tostring(rank), Name = name, Found = a.Rarity[tostring(rank)] == true, Color = I.RarityColors[name] })
            end
            return out
        end },
    { Id = "Exotics", Title = "RELICS", Color = Color3.fromRGB(255, 140, 40), Milestones = { 1, 3, 6, 9, 13 },
        Text = "Every relic, from boss fights and maps. Owning one counts.",
        Entries = function(state)
            local I = ID()
            local a = ArchiveData.Ensure(state)
            local ids = {}
            for id, d in pairs(I.Exotics) do if not d.Zenith then table.insert(ids, id) end end -- (CHASE ITEMS: Zeniths are not relics)
            table.sort(ids, function(x, y) return I.Exotics[x].Name < I.Exotics[y].Name end)
            local out = {}
            for _, id in ipairs(ids) do table.insert(out, { Key = id, Name = I.Exotics[id].Name, Found = a.Exotic[id] == true, Color = I.EXOTIC_COLOR }) end
            return out
        end },
    { Id = "Bosses", Title = "BOSS TRIALS", Color = Color3.fromRGB(255, 110, 90), Milestones = { 5, 15, 30, 50, 80 },
        Text = "Every Boss Trial boss at every tier (a clear of tier V counts tiers I-V).",
        Entries = function(state)
            local B = BT()
            local out = {}
            for _, b in ipairs(B.Bosses) do
                local best = B.Progress(state, b.Id).Best
                for t = 1, B.MAX_TIER do
                    table.insert(out, { Key = b.Id .. ":" .. t, Name = b.Name .. " " .. B.Tiers[t].Name, Found = best >= t, Color = b.Color })
                end
            end
            return out
        end },
    { Id = "Worlds", Title = "WORLDS", Color = Color3.fromRGB(110, 210, 255), Milestones = { 3, 7, 12, 19 },
        Text = "Clear a floor in every world (counts from Update 7).",
        Entries = function(state)
            local DG = require(script.Parent:WaitForChild("DungeonGenerator"))
            local a = ArchiveData.Ensure(state)
            local out = {}
            for _, b in ipairs(DG.BIOMES) do
                local t = DG.BIOME_TITLES[b]
                table.insert(out, { Key = b, Name = t and t.Name or string.upper(b), Found = (tonumber(a.World[b]) or 0) > 0, Color = t and t.Color })
            end
            return out
        end },
    { Id = "Guns", Title = "GUNS", Color = Color3.fromRGB(120, 255, 140), Milestones = { 10, 20, 30, 40, 49 },
        Text = "Find every gun in the game (any rarity).",
        Entries = function(state)
            local I = ID()
            local found = type(state) == "table" and state.StatsTracking and state.StatsTracking.DiscoveredWeapons or {}
            local out = {}
            for _, id in ipairs(I.Lineup) do
                local def = I.BaseWeapons[id]
                table.insert(out, { Key = id, Name = def and def.ShortName or id, Found = found[id] == true })
            end
            return out
        end },
}
ArchiveData.ById = {}
for _, p in ipairs(ArchiveData.Pages) do ArchiveData.ById[p.Id] = p end

-- found / total of a page
function ArchiveData.Count(page: any, state: any): (number, number)
    local n, t = 0, 0
    for _, e in ipairs(page.Entries(state)) do
        t += 1
        if e.Found then n += 1 end
    end
    return n, t
end

-- what milestone i of a page pays: gold + Prism + crafting currency, growing with the milestone (the last one doubled)
function ArchiveData.MilestoneReward(page: any, i: number): any
    local last = i == #page.Milestones
    local k = (last and 2 or 1) * i
    return { Gold = 2500 * k, Prism = 4 * k, EachCurrency = last and 2 or (i >= 3 and 1 or nil), Currency = (i < 3 and not last) and 1 or nil }
end

-- "+5,000 gold, 8 Prism, 1 of each currency"
function ArchiveData.RewardText(r: any): string
    local parts = { tostring(r.Gold) .. " gold", tostring(r.Prism) .. " Prism" }
    if r.EachCurrency then table.insert(parts, r.EachCurrency .. " of each currency") end
    if r.Currency then table.insert(parts, "a currency") end
    return table.concat(parts, ", ")
end

return ArchiveData
