--!nocheck
-- ============================================================================================
-- MAP INKS (UPDATE 7 C3, the vault's "Inscriptions"; placeholder names): consumables drawn onto a map at the map device
-- before you open it (sigil.Inks, up to MAX_PER_MAP, no two the same). Each one changes that map: more item quantity, more
-- elites, a loot goblin on more floors, an encounter on every middle floor, or a sure Coordinate from the guardian.
-- Inks are materials (state.Materials[key]); they drop from map guardians (RiftFinished: DROP_CHANCE, + one more in time).
-- Server: Hideouts "InkMap"(uid, key); EndgameServer.StartRift copies Inks onto run.Rift; effects in Rifts.Quantity,
-- DungeonRuns (elites / goblins / encounters) and RiftFinished (Coordinates).
-- ============================================================================================
local MapInks = {}

MapInks.ON = true
MapInks.UNLOCK = 100
MapInks.MAX_PER_MAP = 2
MapInks.DROP_CHANCE = 0.5
MapInks.COLOR = Color3.fromRGB(120, 180, 255)
MapInks.Defs = {
    InkPlenty = { Name = "Mark of Plenty", Short = "Plenty", Text = "+25% item quantity on this map", Quantity = 0.25, Color = Color3.fromRGB(255, 215, 90) },
    InkPack = { Name = "Mark of the Pack", Short = "Pack", Text = "more elites on every floor (+50%)", Elites = 0.5, Quantity = 0.1, Color = Color3.fromRGB(255, 120, 90) },
    InkGreed = { Name = "Mark of Greed", Short = "Greed", Text = "a loot goblin turns up on more floors", Goblin = 0.35, Color = Color3.fromRGB(120, 230, 140) },
    InkEchoes = { Name = "Mark of Echoes", Short = "Echoes", Text = "an encounter on every floor from 2 to 4", Encounter = true, Color = Color3.fromRGB(150, 140, 255) },
    InkCompass = { Name = "Mark of the Compass", Short = "Compass", Text = "the guardian always drops a Bearing (level 125+)", Coord = true, Color = Color3.fromRGB(110, 220, 230) },
}
MapInks.Order = { "InkPlenty", "InkPack", "InkGreed", "InkEchoes", "InkCompass" }

-- the ink ids on a map (a sigil or a run's Rift table)
function MapInks.Of(map: any): { string }
    local out = {}
    for _, k in ipairs(type(map) == "table" and type(map.Inks) == "table" and map.Inks or {}) do
        if MapInks.Defs[k] then table.insert(out, k) end
    end
    return out
end
function MapInks.Has(map: any, key: string): boolean
    return table.find(MapInks.Of(map), key) ~= nil
end
-- the summed number field of a map's inks (Quantity / Elites / Goblin)
function MapInks.Sum(map: any, field: string): number
    local n = 0
    for _, k in ipairs(MapInks.Of(map)) do n += tonumber(MapInks.Defs[k][field]) or 0 end
    return n
end
-- (MAPS V2 2026-10-30) how many marks a map takes: MAX_PER_MAP + the map tree's InkSlots (the "Wide Margins" notable: a third)
function MapInks.MaxFor(atlasStats: any?): number
    return MapInks.MAX_PER_MAP + math.max(0, math.floor(type(atlasStats) == "table" and tonumber(atlasStats.InkSlots) or 0))
end
-- atlasStats = AtlasData.Stats(state) (nil = no tree: 2 slots)
function MapInks.CanInk(sigil: any, key: string, atlasStats: any?): (boolean, string?)
    if not MapInks.ON then return false, "Sigil Marks are off." end
    if not MapInks.Defs[key] then return false, "Unknown mark." end
    local have = MapInks.Of(sigil)
    local max = MapInks.MaxFor(atlasStats)
    if #have >= max then return false, "A map holds " .. max .. " Sigil Marks." end
    if table.find(have, key) then return false, "That mark is already on this map." end
    return true
end
function MapInks.Text(sigil: any): string?
    local t = {}
    for _, k in ipairs(MapInks.Of(sigil)) do table.insert(t, MapInks.Defs[k].Name .. ": " .. MapInks.Defs[k].Text) end
    return (#t > 0) and table.concat(t, "\n") or nil
end

return MapInks
