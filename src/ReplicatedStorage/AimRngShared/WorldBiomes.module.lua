--!nocheck
-- ============================================================================================
-- WORLD BIOMES (0.87, owner: "I want far more than 6 biomes ... take from other video games that use aesthetics that we
-- dont have yet" -> picked all twelve, "Worlds first"): every world is its own module in AimRngShared.Worlds and brings
-- its whole LOOK -- theme surfaces, cover props, landmarks, map-shell kits + 3 templates, a far hero, the horizon, the
-- scenery over the open roof, a boss stage, light profile, haze, terrain palette, painted sky, moods, telegraph colours.
-- Its ENEMIES, element and superboss are borrowed from a SISTER biome for now (its own roster comes in later batches):
-- the floor's look is the world's, a superboss floor dresses the sister's colossus (DungeonGenerator.CreateBiomeSuperBoss
-- swaps config.Biome for NB.BOSS_OF on its copy).
-- Wiring: NewBiomes calls WB.MergeInto(NB, KITS) at load, so every NB hook in DungeonGenerator (titles, themes, props,
-- landmarks, kits, heroes, vista, scenery, set pieces) serves the worlds too. Client / shared tables read WB directly.
-- A world module must not require game modules (it's required by NewBiomes / ItemData / EnemyAttacks / the client).
-- ============================================================================================
local WB = {}
local KIT = require(script.Parent:WaitForChild("WorldKit"))
WB.ORDER = { "Jungle", "Gothic", "Desert", "Abyss", "Sakura", "Waste", "Fungal", "Sky", "Autumn", "Station", "Aztec", "Bayou" }
WB.W = {}
local folder = script.Parent:WaitForChild("Worlds", 10)
if folder then
    for _, id in ipairs(WB.ORDER) do
        local m = folder:FindFirstChild(id)
        if m then
            local ok, w = pcall(require, m)
            if ok and type(w) == "table" then WB.W[id] = w else warn("[WorldBiomes] " .. id .. " failed: " .. tostring(w)) end
        end
    end
end
-- the worlds that loaded, in order
WB.LIST = {}
for _, id in ipairs(WB.ORDER) do if WB.W[id] then table.insert(WB.LIST, id) end end

-- a sister's element key (ItemData.ELEMENT_OF_BIOME / DungeonGenerator BiomeElement use the same keys)
WB.SISTER_ELEMENT = { Fire = "Fire", Ice = "Cold", Void = "Chaos", Cyber = "Bleed", Storm = "Shock", Dream = "Lucid", Flats = "Scorch" }

-- per-key lookups for the client / shared modules
local function Field(key: string): { [string]: any }
    local t = {}
    for id, w in pairs(WB.W) do if w[key] ~= nil then t[id] = w[key] end end
    return t
end
WB.Light = Field("Light")       -- client LIGHT_PROFILES entries
WB.Atmo = Field("Atmo")         -- client ATMO entries { Density, Color, Decay, Haze, Glare }
WB.Terrain = Field("Terrain")   -- client terrain palette { [Enum.Material] = Color3 }
WB.Contrast = Field("Contrast") -- the enemy outline colour against this world
WB.EA = Field("EA")             -- telegraph colours { Warn, Core, Mat }
WB.Moods = Field("Moods")       -- BiomeMood lists
WB.Sky = Field("Sky")           -- painted skybox face ids (tools/make_skies.py)
WB.Cover = Field("Cover")       -- (UPDATE 4 wrap-up) RoomGen cover dress { Stone, Crown, Clad } (RoomGen.DressFor)
WB.Sister = Field("Sister")
WB.Element = {}
for id, s in pairs(WB.Sister) do WB.Element[id] = WB.SISTER_ELEMENT[s] or "Fire" end
WB.Titles = {}
for id, w in pairs(WB.W) do WB.Titles[id] = { Name = w.Title, Color = w.TitleColor } end

-- NewBiomes hands its tables (and its local kit registry) over at load
function WB.MergeInto(NB: any, KITS: any)
    NB.BOSS_OF = NB.BOSS_OF or {}
    NB.SISTER = NB.SISTER or {}
    NB.WorldVista = NB.WorldVista or {}
    for _, id in ipairs(WB.LIST) do
        local w = WB.W[id]
        if not table.find(NB.BIOMES, id) then table.insert(NB.BIOMES, id) end
        NB.TITLES[id] = { Name = w.Title, Color = w.TitleColor }
        local th = w.Theme
        NB.PALETTE[id] = w.Palette or {
            FloorColor = BrickColor.new(th.Floor.Color), WallColor = BrickColor.new(th.Wall.Color), AccentColor = BrickColor.new(th.Accent),
            LightColor = th.Light, FloorMaterial = th.Floor.Material, HazardColor = BrickColor.new(th.Hazard.Color), HazardName = w.HazardName or "Hazard",
        }
        NB.THEMES[id] = th
        NB.AMBIENCE[id] = w.Ambience
        NB.ELEMENT[id] = WB.Element[id]
        NB.SISTER[id] = w.Sister
        NB.BOSS_OF[id] = w.Sister
        NB.Props[id] = w.Props
        NB.Landmarks[id] = w.Landmarks
        NB.VISTA[id] = w.Vista
        NB.TEMPLATES[id] = w.Templates
        for name, fn in pairs(w.Kits or {}) do KITS[name] = fn end
        for name, fn in pairs(w.Heroes or {}) do NB.Heroes[name] = fn end
        if w.Scenery then NB.Scenery[id] = w.Scenery end
        if w.SetPiece then NB.SetPiece[id] = w.SetPiece end
        if w.VistaFn then
            -- (the generator's horizon part maker doesn't know the Ball gotcha: fix every part it makes for a world)
            NB.WorldVista[id] = function(fx, Pf, centre, gy, zC, r)
                return w.VistaFn(fx, function(props) return KIT.FixBall(Pf(props)) end, centre, gy, zC, r)
            end
        end
    end
    -- (0.89 WORLD FOES: worlds with their own roster / superboss stop borrowing the sister's -- WorldFoes)
    local ok, err = pcall(function() require(script.Parent:WaitForChild("WorldFoes")).MergeInto(NB) end)
    if not ok then warn("[WorldBiomes] world foes failed to merge: " .. tostring(err)) end
end

return WB
