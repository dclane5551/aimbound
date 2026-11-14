--!nocheck
-- ============================================================================================
-- MAP COMPLETION (MAPS V2 L2, 2026-10-30; contract docs/MAPS_V2_2026-10-30.md). Every MAP TYPE (each biome in Rifts.BIOMES +
-- each Storied map in Rifts.UNIQUE_ORDER) beaten IN TIME on each open BAND (Rifts.LADDER, Ruin .. Annihilation at the launch cap)
-- is one completion = one map tree point (AtlasData.PointsFor). Save: state.MapComplete = { [band] = { [typeId] = 1 } }
-- (SaveService PLAIN_FIELDS, nil = nothing yet; keyed by id, so a new biome / Storied map / band just adds rows -- nothing is
-- stored by position). EndgameServer.RiftFinished calls MapCompletion.Mark on an in-time clear; the map device's COMPLETION view
-- (MapCompletionMenu) draws MapCompletion.Grid.
-- ============================================================================================
local MC = {}
local Shared = script.Parent

MC.FIELD = "MapComplete"
local function Rifts() return require(Shared:WaitForChild("Rifts")) end

-- the open bands, in ladder order
function MC.Bands(): { string }
    local R = Rifts()
    local out = {}
    local top = R.MaxTier()
    for i, d in ipairs(R.LADDER) do
        if (i - 1) * R.BAND + 1 <= top then table.insert(out, d) end
    end
    return out
end
-- every map type: { Id, Name, Storied } -- biomes first (Rifts.BIOMES order), then the Storied maps
function MC.Types(): { any }
    if MC._types then return MC._types end
    local R = Rifts()
    local names = {}
    local okWB, WB = pcall(function() return require(Shared:WaitForChild("WorldBiomes")) end)
    if okWB and WB.Titles then for id, t in pairs(WB.Titles) do names[id] = t.Name end end
    local CORE = { Fire = "MOLTEN", Ice = "CRYO", Cyber = "CYBER", Void = "VOID", Storm = "STORMSPIRE", Dream = "DREAMSCAPE", Flats = "NEON FLATS" }
    local out = {}
    for _, id in ipairs(R.BIOMES or {}) do table.insert(out, { Id = id, Name = string.upper(names[id] or CORE[id] or id) }) end
    for _, id in ipairs(R.UNIQUE_ORDER or {}) do
        local u = R.UNIQUES[id]
        table.insert(out, { Id = id, Name = string.upper(u and u.Name or id), Storied = true })
    end
    MC._types = out
    return out
end
-- the type a map (sigil / run.Rift) counts as: its Storied id, else its biome
function MC.TypeOf(map: any): string?
    if type(map) ~= "table" then return nil end
    if type(map.Unique) == "string" and Rifts().UNIQUES[map.Unique] then return map.Unique end
    return type(map.Biome) == "string" and map.Biome or nil
end
local function Book(state: any): { [string]: { [string]: any } }
    local b = type(state) == "table" and state[MC.FIELD]
    return type(b) == "table" and b or {}
end
function MC.Has(state: any, band: string, typeId: string): boolean
    local row = Book(state)[band]
    return type(row) == "table" and row[typeId] ~= nil
end
-- a map beaten in time: record it -> (true if it was new, band, type)
function MC.Mark(state: any, map: any): (boolean, string?, string?)
    if type(state) ~= "table" or type(map) ~= "table" then return false end
    local band = Rifts().DifficultyFor(tonumber(map.Tier) or 1)
    local id = MC.TypeOf(map)
    if not band or not id then return false end
    local known = false
    for _, t in ipairs(MC.Types()) do if t.Id == id then known = true; break end end
    if not known then return false end
    state[MC.FIELD] = type(state[MC.FIELD]) == "table" and state[MC.FIELD] or {}
    local row = state[MC.FIELD][band]
    if type(row) ~= "table" then row = {}; state[MC.FIELD][band] = row end
    if row[id] ~= nil then return false, band, id end
    row[id] = 1
    return true, band, id
end
-- completions on the OPEN bands (closed bands' rows are kept but don't count until they open)
function MC.Count(state: any): number
    local n = 0
    local types = MC.Types()
    for _, band in ipairs(MC.Bands()) do
        for _, t in ipairs(types) do if MC.Has(state, band, t.Id) then n += 1 end end
    end
    return n
end
function MC.Total(): number
    return #MC.Bands() * #MC.Types()
end
-- per band: done / total (for the device line + the view's column heads)
function MC.BandCount(state: any, band: string): (number, number)
    local n, types = 0, MC.Types()
    for _, t in ipairs(types) do if MC.Has(state, band, t.Id) then n += 1 end end
    return n, #types
end
function MC.Name(typeId: string): string
    for _, t in ipairs(MC.Types()) do if t.Id == typeId then return t.Name end end
    return string.upper(tostring(typeId))
end

return MC
