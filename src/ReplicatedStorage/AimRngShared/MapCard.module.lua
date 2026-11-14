--!nocheck
-- ============================================================================================
-- MAP CARD (MAPS V2 2026-10-30, MODS builder): what a map (sigil) does, in one place, for every place that shows a map (the map
-- device rows in HideoutClient, the old rift list in ChallengesMenu, anything new). Numbers come from Rifts / FloorMods, the same
-- functions the server pays out with, so the card never says something the map doesn't do.
--   MapCard.Stats(sigil)       -> { Quantity, Rarity, PackSize, Quality, Scale } (fractions; Quality in points 0-20)
--   MapCard.StatLine(sigil)    -> "ITEM QUANTITY +34%  •  ITEM RARITY +41%  •  PACK SIZE +25%  •  QUALITY 10%" (zeros left out
--                                 except quantity), plain text
--   MapCard.ModLines(sigil)    -> { "Fortified: Enemies have 52% more health.", ... } at the map's tier (Rifts.ModScale)
--   MapCard.TagLine(sigil)     -> "CORRUPTED" / "RUPTURED: +1 tier" / nil (the lock state + what a Rupture did)
-- ============================================================================================
local Shared = script.Parent
local Rifts = require(Shared:WaitForChild("Rifts"))
local FloorMods = require(Shared:WaitForChild("FloorMods"))

local MapCard = {}

local function Pct(v: number): string
    return tostring(math.round((tonumber(v) or 0) * 100))
end

function MapCard.Stats(sigil: any): any
    local tier = type(sigil) == "table" and tonumber(sigil.Tier) or 1
    return {
        Quantity = Rifts.Quantity(sigil),
        Rarity = Rifts.Rarity(sigil),
        PackSize = Rifts.PackSize(sigil),
        Quality = Rifts.QualityOf(sigil),
        Scale = Rifts.ModScale(tier),
    }
end

function MapCard.StatLine(sigil: any): string
    local s = MapCard.Stats(sigil)
    local t = { "ITEM QUANTITY +" .. Pct(s.Quantity) .. "%" }
    if s.Rarity > 0.004 then table.insert(t, "ITEM RARITY +" .. Pct(s.Rarity) .. "%") end
    if s.PackSize > 0.004 then table.insert(t, "PACK SIZE +" .. Pct(s.PackSize) .. "%") end
    if s.Quality > 0 then table.insert(t, "QUALITY " .. s.Quality .. "%") end
    return table.concat(t, "  •  ")
end

function MapCard.ModLines(sigil: any): { string }
    local out = {}
    if type(sigil) ~= "table" then return out end
    local sc = Rifts.ModScale(tonumber(sigil.Tier) or 1)
    for _, m in ipairs(sigil.Mods or {}) do
        local d = FloorMods.Defs[m]
        table.insert(out, d and (d.Name .. ": " .. FloorMods.TextOf(m, sc)) or tostring(m))
    end
    return out
end

local RESULT = { Still = "no change", Ascend = "+1 tier or mod", Warp = "new corrupted mods", Bounty = "+quantity and rarity" }
function MapCard.TagLine(sigil: any): string?
    if type(sigil) ~= "table" then return nil end
    if sigil.Ruptured then
        local r = RESULT[sigil.RuptureResult or ""]
        return "RUPTURED" .. (r and (": " .. r) or "") .. "  •  locked (marks still go on)"
    end
    if sigil.Corrupted then return "CORRUPTED  •  only RUPTURE and marks left" end
    return nil
end

return MapCard
