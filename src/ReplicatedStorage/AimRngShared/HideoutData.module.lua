--!nocheck
-- ============================================================================================
-- HIDEOUTS (0.55). Owner 2026-10-06: "customizeable hideouts for the player" -> answers: friends + party can visit,
-- plus "request to visit" (a setting turns requests off; a request only goes through while the owner is IN the
-- hideout); furniture from a GOLD shop ("Gold decorations should be simpler"), BOSS / RUN DROPS, ROBUX and ACHIEVEMENTS
-- ("the others depending on rarity / difficulty / price"); USEFUL STATIONS (stash, forge, training dummy, dungeon
-- portal); GRID SNAP in ONE APARTMENT (a walled-city loft), expandable later.
-- Shared by the server (Hideouts: owning, placing, validating) and the client (HideoutClient: building, build mode).
--   HideoutData.Items[id] = { Name, Desc, Source = "Gold" | "Drop" | "Robux" | "Achievement", Price (gold) / Robux,
--       ProductId, Rarity, W, D (grid cells), Layer = "Floor" | "Rug", Station = menu name?, Max (how many you can own),
--       Drop = { Model, Biome?, Chance } / Unlock = function(state) -> bool, How (text), Build = function(model, cf) }
--   HideoutData.BuildShell(parent) -> the apartment (walls, windows, balcony, door, practice alcove)
--   HideoutData.Footprint(id, rot) -> w, d;  HideoutData.CanPlace(layout, id, gx, gz, rot, skipIndex) -> ok, why
--   HideoutData.Origin = the floor's centre (Zones.HIDEOUT_ORIGIN). Grid: ROOM cells of GRID studs.
-- ============================================================================================
local HideoutData = {}
local Zones = require(script.Parent:WaitForChild("Zones"))
-- (UPDATE 4) the hideout kit: real textured models living in the place (ReplicatedStorage.HideoutKit); nil = old pieces
local Kit = nil
pcall(function() Kit = require(script.Parent:WaitForChild("HideoutKit", 5)) end)
-- (UPDATE 6) the shared lava (self-lit pools / rivers / falls, the Molten biome's look) for the Ember Forge's outside
local LavaFX = nil
pcall(function() LavaFX = require(script.Parent:WaitForChild("LavaFX", 5)) end)
-- (UPDATE 6) WorldKit: its waterfall beams (Crystal Hollow)
local WK = nil
pcall(function() WK = require(script.Parent:WaitForChild("WorldKit", 5)) end)

local M = Enum.Material
local V, CF, ANG, R = Vector3.new, CFrame.new, CFrame.Angles, math.rad
local function C(r, g, b) return Color3.fromRGB(r, g, b) end

HideoutData.Origin = Zones.HIDEOUT_ORIGIN
HideoutData.GRID = 4
-- the room (0.58, owner: "I want to make the hideouts bigger" -> about 1.5x): x -30..54, z -14..34 (local, studs) = 21 x 12
-- cells, + the balcony z 34..42 = rows 13-14 (an EXPANSION). X0 / Z0 never move, so every saved layout stays where it was
-- (the old balcony rows 10-11 are now inside the room). BX / BZ = the room's far edges, used by every theme's walls.
HideoutData.ROOM = { X0 = -30, Z0 = -14, W = 21, D = 14 }
HideoutData.BALCONY_ROW = 13 -- (rows >= 13 are the balcony: the south wall runs between rows 12 and 13)
HideoutData.BX, HideoutData.BZ, HideoutData.BALZ = 54, 34, 42 -- (room east wall x, south wall z, balcony edge z)
HideoutData.MAX_PIECES = 60 -- (the most any hideout can hold: the last expansion's cap)

-- ===== EXPANSIONS (2026-10-07, owner: "theres also no way to get upgrades to build the hideout expansions"): bought in
-- order with gold, each needs a level. They raise how many pieces you can place, and BALCONY RIGHTS opens the balcony
-- for building. state.Hideout.Exp = how many you own (0 = the plain loft). Pieces already placed are never taken away.
HideoutData.BASE_CAP = 20
-- (owner 2026-10-07: "Upgrades can be bought both in game and with robux"): each one is gold + its level, OR Robux
-- (Robux skips the level; ProductId 0 = free in Studio, "coming soon" live). Each also adds 50 STASH slots.
HideoutData.EXPANSIONS = {
    { Id = "Storage", Name = "Storage Lockers", Desc = "Room for 30 pieces and 150 stashed items.", Cap = 30, Price = 6000, Level = 5, Robux = 99, ProductId = 0 },
    { Id = "Balcony", Name = "Balcony Rights", Desc = "Build out on the balcony too (two more rows), room for 35 pieces and 200 stashed items.", Cap = 35, Price = 18000, Level = 15, Balcony = true, Robux = 149, ProductId = 0 },
    { Id = "Renovation", Name = "Full Renovation", Desc = "Room for 45 pieces and 250 stashed items.", Cap = 45, Price = 45000, Level = 30, Robux = 249, ProductId = 0 },
    { Id = "Penthouse", Name = "Penthouse Permit", Desc = "Room for 60 pieces and 300 stashed items: the most a hideout can hold.", Cap = 60, Price = 120000, Level = 50, Robux = 399, ProductId = 0 },
}
-- the HIDEOUT STASH (owner 2026-10-07: "Hideouts should have a stash with an item limit"): state.Hideout.Stash =
-- { W = { weapons }, G = { gear } }; use it at the stash chest in your hideout
HideoutData.STASH_BASE = 100
HideoutData.STASH_PER_EXP = 50
function HideoutData.StashCap(exp: number): number return HideoutData.STASH_BASE + HideoutData.STASH_PER_EXP * (exp or 0) end
function HideoutData.StashCount(st: any): number
    local h = type(st) == "table" and type(st.Hideout) == "table" and st.Hideout or {}
    local s = type(h.Stash) == "table" and h.Stash or {}
    return #(type(s.W) == "table" and s.W or {}) + #(type(s.G) == "table" and s.G or {})
end
function HideoutData.ExpLevel(st: any): number
    local h = type(st) == "table" and type(st.Hideout) == "table" and st.Hideout or {}
    return math.clamp(math.floor(tonumber(h.Exp) or 0), 0, #HideoutData.EXPANSIONS)
end
function HideoutData.Cap(exp: number): number
    local e = HideoutData.EXPANSIONS[exp or 0]
    return e and e.Cap or HideoutData.BASE_CAP
end
function HideoutData.BalconyOpen(exp: number): boolean
    for i = 1, exp or 0 do if HideoutData.EXPANSIONS[i] and HideoutData.EXPANSIONS[i].Balcony then return true end end
    return false
end

-- ===== THEMES (2026-10-07, owner: "We are going to offer hideout prebuilt areas too that change your hideout default
-- area (you can still build), so default would be appartment, but then we can have other hideouts that would replace
-- that (aquarium, forest etc)"): the same floor plan (grid, door, balcony, practice alcove: your furniture stays where it
-- is) dressed as a different place. state.Hideout.Theme = the one shown, state.Hideout.Themes = { [id] = true } owned.
HideoutData.THEME_ORDER = { "Apartment", "Aquarium", "Forest", "Forge", "Starwhale", "Crystal" }
HideoutData.THEMES = {
    Apartment = { Name = "Walled-City Loft", Desc = "Your starting loft above the neon city: plaster walls, wooden floors, towers outside the windows.", Free = true },
    Aquarium = { Name = "Deep Aquarium", Desc = "A glass tunnel on the sea floor: fish shoals, a manta and a turtle swimming over the glass, kelp, reefs and glowing jellyfish all round.",
        Price = 399, ProductId = 0, Rarity = "Legendary" },
    Forest = { Name = "Forest Cabin", Desc = "A log cabin up in a giant tree: open windows on the canopy, vines, fireflies, butterflies on the deck, mist far below.",
        Price = 399, ProductId = 0, Rarity = "Legendary" },
    Forge = { Name = "Ember Forge", Desc = "A smiths' hall cut into a live volcano: a roaring hearth in the wall, a lava river past iron-barred windows, lavafalls down the crater and embers rising past the balcony.",
        Price = 399, ProductId = 0, Rarity = "Legendary" },
    -- (0.89, owner: "more hideout ... skins", references: a big ARPG's premium hideouts -- original designs)
    Starwhale = { Name = "Starwhale Observatory", Desc = "A walnut-and-brass observatory under a glass vault, riding the back of a star-whale through the night: a turning orrery, a great telescope, a ringed planet, star jellies circling and the whale's slow flukes below.",
        Price = 399, ProductId = 0, Rarity = "Mythic" },
    Crystal = { Name = "Crystal Hollow", Desc = "A miners' lodge on a rock pillar in a cavern of azure crystal: a mine shaft with a cart rolling in and out, a trestle over the underground lake, a waterfall, glowing spores and giant crystals in the walls.",
        Price = 399, ProductId = 0, Rarity = "Legendary" },
}
function HideoutData.ThemeOf(st: any): string
    local h = type(st) == "table" and type(st.Hideout) == "table" and st.Hideout or {}
    local t = h.Theme
    if type(t) == "string" and HideoutData.THEMES[t] and (HideoutData.THEMES[t].Free or (type(h.Themes) == "table" and h.Themes[t])) then return t end
    return "Apartment"
end
-- cells kept free: the practice alcove's mouth (north-west), the MAP ROOM doorway (north, x 22..34), the path in from the
-- door (east wall x 54, z 0..8) and the stash chest (west wall)
HideoutData.RESERVED = { ["1,1"] = true, ["2,1"] = true, ["3,1"] = true, ["4,1"] = true, ["14,1"] = true, ["15,1"] = true, ["16,1"] = true }
for z = 4, 6 do HideoutData.RESERVED["20," .. z] = true; HideoutData.RESERVED["21," .. z] = true end
for z = 7, 9 do HideoutData.RESERVED["1," .. z] = true end -- (0.56: the stash chest by the west wall)
HideoutData.SPAWN = CFrame.lookAt(Zones.HIDEOUT_ORIGIN + V(44, 3, 4), Zones.HIDEOUT_ORIGIN + V(10, 3, 4)) -- (inside the door, facing in)

-- ===== THE MAP ROOM (0.58, owner: "add an expansion for the endgame mapping system we are going to add (like path of
-- exile) ... When you open a rift or map ... a portal will open (and the skin of that portal can be changed)"): a wing
-- north of the room (x 10..46, z -40..-14, doorway x 22..34) with the MAP DEVICE: put a Rift Sigil in and the portal at
-- the far end opens; walk in to start that rift. Its own purchase (not one of the EXPANSIONS steps): state.Hideout.MapRoom,
-- published as the owner attribute HideoutMapRoom. Gold + level, or Robux (ProductId 0 = free in Studio).
-- (0.61 MAPS v2: Level 20 -> 100 = Rifts.MIN_LEVEL; a Robux room still needs level 100 to use the device)
HideoutData.MAP_ROOM = { Name = "Map Room", Desc = "A new wing with the MAP DEVICE for level 100+: maps run the hardest difficulties (Ruin and up) and pay the best loot in the game.",
    Price = 500000, Level = 100, Robux = 199, ProductId = 0 }
-- (2026-10-23, owner: "a bit too cheap gold wise" at 25,000 -- under the L30 Renovation's 45,000): 500,000 = ~5 Ruin runs at
-- level 100 (measured in Studio: a 6-floor Ruin Descent, every enemy killed through the real kill pipeline + each floor's
-- chest, every drop sold = ~107,000 gold; floors 12-30K each), well over the Penthouse (120,000, L50). BOUND price unchanged.
-- BOUND SHOP (0.97, owner: "Everything in the shop will be purchasable with the bound points"): what used to be a Robux
-- purchase in the hideout (pieces, expansions, the map room, themes) costs BOUND points; themes match the store (699)
function HideoutData.BPPrice(robux: number?): number
    return math.max(49, math.round((tonumber(robux) or 100) * 0.9 / 10) * 10 - 1)
end
HideoutData.THEME_BP = 399 -- (2026-10-14 pricing pass: was 699)
HideoutData.MAP = { X0 = 10, X1 = 46, Z0 = -40, DoorX0 = 22, DoorX1 = 34, Device = V(28, 0, -26), Portal = V(28, 0, -36) }
-- (2026-10-23) the map room's side walls run z Z0..-15 (WZ / WL: centre / length) and its ceiling z Z0-1..-15 (CZ / CL):
-- they stop BEHIND the room's north wall (z -15..-14) instead of poking through it (z-fighting its face, the owner's
-- "grey clips through the tan wall"), and the ceiling never overlaps the room's own
do
    local MP = HideoutData.MAP
    MP.WZ, MP.WL = (MP.Z0 - 15) / 2, -15 - MP.Z0
    MP.CZ, MP.CL = (MP.Z0 - 16) / 2, -14 - MP.Z0
end
-- the north wall's window runs: without the map room both sides of its doorway; with it, the bays the wing backs onto
-- (x 9..22 / 34..47) are solid wall -- windows only see out, never into the map room
function HideoutData.NorthRuns(mapRoom: boolean): any
    local MP = HideoutData.MAP
    if not mapRoom then return { Win = { { -14, MP.DoorX0 }, { MP.DoorX1, HideoutData.BX } }, Solid = {} } end
    return { Win = { { -14, MP.X0 - 1 }, { MP.X1 + 1, HideoutData.BX } }, Solid = { { MP.X0 - 1, MP.DoorX0 }, { MP.DoorX1, MP.X1 + 1 } } }
end
HideoutData.PORTAL_OPEN_SECONDS = 90
function HideoutData.HasMapRoom(st: any): boolean
    local h = type(st) == "table" and type(st.Hideout) == "table" and st.Hideout or {}
    return h.MapRoom == true
end
HideoutData.DUMMY_POS = Zones.HIDEOUT_ORIGIN + V(-24, 0, -35)
-- (UPDATE 6) the Starwhale's floor of deep space under the whale: the painted sky's downward face (BiomeSkies.HideoutStarwhale Dn)
-- (UNUSED since the Starwhale clears the hub terrain on the client instead -- kept for a fallback)
HideoutData.SPACE_FLOOR = "rbxassetid://75085012485433"
-- THE JUKEBOX v2 (2026-10-24; owner on the CC0 Freesound music: "cheesy and AI generated"): every station is a short playlist
-- of tracks from Roblox's licensed music library (creator APMOfficial = APM Music: free in any experience, no access
-- grant), the station's old mood kept. Ids stay (saved picks: state.Hideout.Music). HideoutShowcase plays a station's
-- Tracks in order from a random one, round again, on the Music sound group (the Music slider applies). Volume = measured
-- trim to the city music's level (HubMusic.TRACKS): 10^((-21.5 - RMS) / 20), RMS = AudioAnalyzer over the whole track in
-- Edit (the AUDITION.md method). With no station on, HubMusic plays the city's DnB in the hideout. Credits MUSIC tab.
HideoutData.MUSIC = {
    { Id = "lofi", Name = "Late Night Lo-fi", Mood = "late-night lo-fi hip hop", Tracks = {
        { Id = 9047105108, Name = "Moving Round The Block", By = "Afro Dizzy", Volume = 0.29 }, -- RMS -10.8
        { Id = 9047105702, Name = "Light Dreamer", By = "Afro Dizzy", Volume = 0.33 }, -- RMS -11.9
        { Id = 9047104336, Name = "Sunday In Bed", By = "Afro Dizzy", Volume = 0.29 }, -- RMS -10.8
        { Id = 9042722978, Name = "Calming Lo-Fi (Underscore)", By = "Invasion From Mars", Volume = 0.57 }, -- RMS -16.6
    } },
    { Id = "calm", Name = "Calm Drift", Mood = "slow drifting pads and drones", Tracks = {
        { Id = 9042042278, Name = "Watercolours (b)", By = "Juice Music", Volume = 3.0 }, -- RMS -31.1 (a quiet drone master)
        { Id = 9042043110, Name = "Calm Space (b)", By = "Juice Music", Volume = 1.29 }, -- RMS -23.7
        { Id = 9042042428, Name = "Oceanic (b)", By = "Juice Music", Volume = 1.30 }, -- RMS -23.8
        { Id = 9042042011, Name = "Essential (b)", By = "Juice Music", Volume = 1.24 }, -- RMS -23.4
    } },
    { Id = "plains", Name = "Open Plains", Mood = "wide orchestral landscapes", Tracks = {
        { Id = 9043252812, Name = "Epic Landscape (Underscore)", By = "Bruton", Volume = 0.66 }, -- RMS -17.9
        { Id = 9043250032, Name = "Summer Day (Underscore)", By = "Bruton", Volume = 0.92 }, -- RMS -20.8
        { Id = 9043256659, Name = "Autumn Mornings (Underscore)", By = "Bruton", Volume = 0.83 }, -- RMS -19.9
        { Id = 9043252474, Name = "Snow Field (Underscore)", By = "Bruton", Volume = 1.05 }, -- RMS -21.9
    } },
    { Id = "synth", Name = "Night Drive", Mood = "night-drive synthwave", Tracks = {
        { Id = 1842946777, Name = "Into The Night (Underscore)", By = "B Kully", Volume = 0.30 }, -- RMS -11.0 (the owner's audition keep)
        { Id = 1842947080, Name = "Cybernetic (Underscore)", By = "B Kully", Volume = 0.34 }, -- RMS -12.2
        { Id = 9040339867, Name = "Cyberpunk (b)", By = "Score Production Music", Volume = 0.38 }, -- RMS -13.1
        { Id = 1842842595, Name = "Midnight Runner", By = "Lemoncake", Volume = 0.41 }, -- RMS -13.8
    } },
}
HideoutData.MusicById = {}
for _, t in ipairs(HideoutData.MUSIC) do HideoutData.MusicById[t.Id] = t end
-- (UPDATE 6) THE AIM ARCADE: a round's length, the most one hit can score, the fastest believable hit rate (server check)
HideoutData.ARCADE = { Time = 20, MaxPerHit = 200, MaxRate = 6 }

-- ===== part helpers (anchored; decoration never collides / is queryable: each piece gets ONE invisible hitbox) =====
local function P(m: Instance, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?, o: any?): BasePart
    local p = Instance.new((o and o.Wedge) and "WedgePart" or "Part")
    p.Anchored = true
    p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = mat or M.SmoothPlastic
    if o then
        if o.Shape then
            p.Shape = o.Shape
            -- (a Ball is a sphere of its SMALLEST side: a non-uniform one becomes a block + sphere mesh = an ellipsoid)
            if o.Shape == Enum.PartType.Ball and math.max(size.X, size.Y, size.Z) > math.min(size.X, size.Y, size.Z) * 1.15 then
                p.Shape = Enum.PartType.Block
                p.Size = size
                local sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Sphere; sm.Parent = p
            end
        end
        if o.T then p.Transparency = o.T end
        if o.Refl then p.Reflectance = o.Refl end
        if o.Name then p.Name = o.Name end
        if o.Collide then p.CanCollide = true; p.CanQuery = true end
    end
    p.Parent = m
    return p
end
local function Cyl(m, cf, len, dia, color, mat, o) -- along cf's Y axis
    o = o or {}; o.Shape = Enum.PartType.Cylinder
    return P(m, cf * ANG(0, 0, R(90)), V(len, dia, dia), color, mat, o)
end
local function Ball(m, cf, d, color, mat, o)
    o = o or {}; o.Shape = Enum.PartType.Ball
    return P(m, cf, V(d, d, d), color, mat, o)
end
local function Glow(m, cf, size, color, t) return P(m, cf, size, color, M.Neon, { T = t or 0 }) end
local function Label(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?)
    local sg = Instance.new("SurfaceGui")
    sg.Face = face; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 30; sg.LightInfluence = 0; sg.Brightness = 1.5
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(0.92, 0.84); t.Position = UDim2.fromScale(0.04, 0.08)
    t.TextScaled = true; t.Font = font or Enum.Font.GothamBlack; t.TextColor3 = color; t.Text = text
    t:SetAttribute("KeepFont", true)
    t.Parent = sg
    sg.Parent = part
end
HideoutData.P, HideoutData.Glow, HideoutData.Label = P, Glow, Label

-- palette
local WOOD, DARKWOOD, LIGHTWOOD = C(120, 80, 52), C(70, 46, 34), C(176, 132, 90)
local STEEL, DARK, CREAM = C(110, 112, 118), C(34, 34, 40), C(226, 218, 200)
local RED, TEAL, PINK, AMBER, CYAN, GOLD = C(186, 48, 52), C(48, 140, 136), C(236, 112, 170), C(250, 176, 60), C(60, 220, 240), C(240, 196, 80)

-- every builder: (m, cf) with cf at the footprint's centre on the floor, the piece's front facing -Z
local B = {}

-- ===================== GOLD: simple pieces =====================
function B.Sofa(m, cf) -- 2 x 1
    local col = C(150, 62, 70)
    P(m, cf * CF(0, 0.9, 0.3), V(7.2, 1.2, 3.2), col, M.Fabric)
    P(m, cf * CF(0, 2.2, 1.6), V(7.2, 2.6, 0.8), col, M.Fabric)
    for sx = -1, 1, 2 do P(m, cf * CF(sx * 3.35, 1.6, 0.4), V(0.7, 1.6, 3.4), col:Lerp(C(0, 0, 0), 0.15), M.Fabric) end
    for sx = -1, 1, 2 do P(m, cf * CF(sx * 1.75, 1.65, 0.1), V(3.3, 0.5, 2.6), col:Lerp(C(255, 255, 255), 0.1), M.Fabric) end
    P(m, cf * CF(-2.4, 2.4, 1.0), V(1.4, 1.4, 0.5), AMBER, M.Fabric)
    for sx = -1, 1, 2 do for sz = -1, 1, 2 do P(m, cf * CF(sx * 3.3, 0.15, 0.3 + sz * 1.3), V(0.4, 0.3, 0.4), DARKWOOD, M.Wood) end end
end
function B.Armchair(m, cf) -- 1 x 1
    local col = C(70, 100, 140)
    P(m, cf * CF(0, 0.9, 0.2), V(3.2, 1.2, 3), col, M.Fabric)
    P(m, cf * CF(0, 2.2, 1.4), V(3.2, 2.6, 0.7), col, M.Fabric)
    for sx = -1, 1, 2 do P(m, cf * CF(sx * 1.45, 1.6, 0.3), V(0.5, 1.4, 3), col:Lerp(C(0, 0, 0), 0.2), M.Fabric) end
end
function B.CoffeeTable(m, cf)
    P(m, cf * CF(0, 1.4, 0), V(3.2, 0.25, 2.2), DARKWOOD, M.Wood)
    P(m, cf * CF(0, 0.7, 0), V(2.6, 0.15, 1.6), WOOD, M.Wood)
    for sx = -1, 1, 2 do for sz = -1, 1, 2 do P(m, cf * CF(sx * 1.4, 0.65, sz * 0.9), V(0.25, 1.3, 0.25), DARKWOOD, M.Wood) end end
    Cyl(m, cf * CF(0.6, 1.75, 0), 0.5, 0.5, CREAM, M.SmoothPlastic) -- a mug
    P(m, cf * CF(-0.6, 1.58, 0.1) * ANG(0, R(15), 0), V(1.2, 0.1, 0.9), RED, M.SmoothPlastic) -- a magazine
end
function B.FloorLamp(m, cf)
    P(m, cf * CF(0, 0.1, 0), V(1.4, 0.2, 1.4), DARK, M.Metal)
    Cyl(m, cf * CF(0, 2.6, 0), 5, 0.18, DARK, M.Metal)
    Cyl(m, cf * CF(0, 5.4, 0), 1.2, 1.6, C(255, 214, 160), M.Neon, { T = 0.25 })
end
function B.PottedPlant(m, cf)
    Cyl(m, cf * CF(0, 0.7, 0), 1.4, 1.6, C(180, 90, 60), M.Slate)
    for k = 0, 5 do
        local a = k / 6 * math.pi * 2
        P(m, cf * CF(math.cos(a) * 0.4, 2.2, math.sin(a) * 0.4) * ANG(math.cos(a) * 0.5, a, math.sin(a) * 0.5), V(0.5, 2.4, 0.15), C(60, 150, 70), M.SmoothPlastic)
    end
end
function B.Bonsai(m, cf)
    P(m, cf * CF(0, 0.45, 0), V(2.4, 0.9, 1.6), C(60, 70, 90), M.Slate)
    P(m, cf * CF(0, 0.95, 0), V(2.2, 0.1, 1.4), C(80, 60, 40), M.Ground)
    Cyl(m, cf * CF(0, 1.6, 0) * ANG(0, 0, R(12)), 1.4, 0.35, C(90, 60, 40), M.Wood)
    Cyl(m, cf * CF(0.25, 2.4, 0) * ANG(0, 0, R(-35)), 1.0, 0.25, C(90, 60, 40), M.Wood)
    for _, o in ipairs({ { -0.3, 2.5, 0, 1.4 }, { 0.6, 2.9, 0.1, 1.1 }, { 0.1, 3.2, -0.2, 0.9 } }) do
        Ball(m, cf * CF(o[1], o[2], o[3]), o[4], C(70, 140, 70), M.Grass)
    end
end
function B.Bookshelf(m, cf) -- 2 x 1
    P(m, cf * CF(0, 3.5, 1.2), V(7, 7, 0.3), DARKWOOD, M.Wood)
    for sx = -1, 1, 2 do P(m, cf * CF(sx * 3.4, 3.5, 0.3), V(0.3, 7, 2), DARKWOOD, M.Wood) end
    local cols = { RED, TEAL, AMBER, C(90, 70, 140), C(60, 90, 60), CREAM, C(140, 60, 40) }
    for row = 0, 3 do
        local y = 0.2 + row * 1.75
        P(m, cf * CF(0, y, 0.3), V(6.6, 0.2, 2), WOOD, M.Wood)
        if row < 3 then
            local x = -3.1
            local k = row
            while x < 2.9 do
                k += 1
                local w = 0.3 + (k * 37 % 5) * 0.08
                local h = 1.0 + (k * 13 % 4) * 0.12
                P(m, cf * CF(x + w / 2, y + 0.1 + h / 2, 0.4), V(w, h, 1.4), cols[k % #cols + 1], M.SmoothPlastic)
                x += w + 0.04
                if k % 9 == 0 then x += 0.6 end
            end
        end
    end
end
function B.Bed(m, cf) -- 2 x 2
    P(m, cf * CF(0, 0.6, 0), V(6.4, 1.2, 7.4), DARKWOOD, M.Wood)
    P(m, cf * CF(0, 1.5, 0.2), V(6, 0.8, 7), CREAM, M.Fabric)
    P(m, cf * CF(0, 1.75, -1.0), V(6.1, 0.5, 4.8), C(70, 80, 140), M.Fabric) -- the duvet
    for sx = -1, 1, 2 do P(m, cf * CF(sx * 1.5, 2.1, 2.7), V(2.4, 0.6, 1.3), C(240, 236, 228), M.Fabric) end
    P(m, cf * CF(0, 2.6, 3.6), V(6.4, 3.4, 0.4), DARKWOOD, M.Wood)
    Glow(m, cf * CF(0, 4.2, 3.4), V(5.6, 0.12, 0.12), PINK, 0.1)
end
function B.DiningSet(m, cf) -- 2 x 2
    P(m, cf * CF(0, 2.6, 0), V(5.2, 0.3, 3.4), WOOD, M.Wood)
    for sx = -1, 1, 2 do for sz = -1, 1, 2 do P(m, cf * CF(sx * 2.3, 1.25, sz * 1.4), V(0.35, 2.5, 0.35), DARKWOOD, M.Wood) end end
    for _, s in ipairs({ { -1.4, -2.6 }, { 1.4, -2.6 }, { -1.4, 2.6 }, { 1.4, 2.6 } }) do
        Cyl(m, cf * CF(s[1], 1.7, s[2]), 0.3, 1.4, RED, M.SmoothPlastic)
        Cyl(m, cf * CF(s[1], 0.8, s[2]), 1.6, 0.2, DARK, M.Metal)
    end
    Cyl(m, cf * CF(0, 3.0, 0), 0.4, 1.2, CREAM, M.SmoothPlastic) -- a rice bowl / pot
    Ball(m, cf * CF(1.2, 3.0, 0.5), 0.6, C(230, 120, 40), M.SmoothPlastic)
end
function B.TVStand(m, cf) -- 2 x 1
    P(m, cf * CF(0, 1, 0.3), V(7, 2, 2.4), DARKWOOD, M.Wood)
    P(m, cf * CF(0, 1, -0.95), V(6.4, 1.4, 0.1), C(50, 36, 30), M.Wood)
    P(m, cf * CF(0, 3.5, 0.5), V(4.4, 3, 2.8), C(60, 58, 56), M.SmoothPlastic) -- a CRT set
    local screen = Glow(m, cf * CF(0, 3.5, -0.95), V(3.6, 2.4, 0.1), C(80, 160, 220), 0.1)
    screen.Name = "TVScreen"
    for sx = -1, 1, 2 do Cyl(m, cf * CF(sx * 0.6, 5.6, 0.8) * ANG(0, 0, R(sx * 25)), 1.6, 0.1, DARK, M.Metal) end
    P(m, cf * CF(2.6, 2.2, -0.2), V(1, 0.4, 0.7), C(30, 30, 34), M.SmoothPlastic) -- a game console
end
function B.ArcadeCabinet(m, cf) -- (UPDATE 6: plays the AIM ARCADE -- a 20 s flick game with a personal best; the screen shows the owner's)
    local BODY, SIDE, INK = C(36, 26, 76), C(24, 18, 54), C(10, 8, 22)
    P(m, cf * CF(0, 0.25, 0.25), V(3.2, 0.5, 2.8), DARK, M.Metal)
    P(m, cf * CF(0, 1.75, 0.3), V(2.8, 2.5, 2.4), BODY, M.SmoothPlastic)
    P(m, cf * CF(0, 1.45, -0.93), V(1.9, 1.5, 0.06), INK, M.SmoothPlastic) -- (the coin door)
    Glow(m, cf * CF(0.45, 1.75, -0.97), V(0.12, 0.42, 0.04), AMBER, 0.1)
    Glow(m, cf * CF(-0.45, 1.75, -0.97), V(0.12, 0.42, 0.04), AMBER, 0.1)
    for sx = -1, 1, 2 do
        P(m, cf * CF(sx * 1.5, 3.55, 0.3), V(0.22, 6.5, 2.7), SIDE, M.SmoothPlastic)
        Glow(m, cf * CF(sx * 1.5, 3.55, -1.07), V(0.26, 6.3, 0.07), CYAN, 0.12)
    end
    P(m, cf * CF(0, 3.12, -0.75) * ANG(R(-16), 0, 0), V(2.8, 0.28, 1.3), C(28, 26, 34), M.SmoothPlastic) -- (the control deck)
    Cyl(m, cf * CF(-0.75, 3.48, -0.85), 0.5, 0.12, DARK, M.Metal)
    Ball(m, cf * CF(-0.75, 3.75, -0.85), 0.36, RED, M.SmoothPlastic)
    for k = 0, 2 do Cyl(m, cf * CF(0.15 + k * 0.42, 3.33 - k * 0.02, -0.92 + k * 0.03) * ANG(R(-16), 0, 0), 0.12, 0.3, ({ CYAN, AMBER, PINK })[k + 1], M.Neon) end
    P(m, cf * CF(0, 5.0, 0.55), V(2.8, 3.2, 1.6), BODY, M.SmoothPlastic)
    P(m, cf * CF(0, 4.95, -0.3) * ANG(R(-8), 0, 0), V(2.7, 2.35, 0.08), INK, M.SmoothPlastic) -- (the bezel)
    P(m, cf * CF(0, 4.95, -0.36) * ANG(R(-8), 0, 0), V(2.45, 2.05, 0.04), C(6, 8, 16), M.SmoothPlastic, { Name = "ArcadeScreen" })
    local mq = P(m, cf * CF(0, 6.6, -0.05), V(2.9, 0.8, 0.6), INK, M.SmoothPlastic)
    Label(mq, Enum.NormalId.Front, "AIM ARCADE", PINK)
    Glow(m, cf * CF(0, 7.05, -0.05), V(2.9, 0.1, 0.6), PINK, 0.15)
end
function B.VendingMachine(m, cf)
    P(m, cf * CF(0, 3.3, 0.4), V(3.2, 6.6, 2.6), C(190, 40, 52), M.SmoothPlastic)
    Glow(m, cf * CF(-0.4, 4, -0.92), V(2, 4, 0.1), C(225, 240, 255), 0.25)
    for r = 0, 2 do for c = 0, 2 do
        Cyl(m, cf * CF(-1.0 + c * 0.6, 5.2 - r * 1.2, -0.8), 0.7, 0.35, ({ RED, CYAN, AMBER })[(r + c) % 3 + 1], M.SmoothPlastic)
    end end
    P(m, cf * CF(1.1, 3.6, -0.95), V(0.6, 1.2, 0.1), DARK, M.Metal)
    P(m, cf * CF(-0.3, 0.8, -0.95), V(2.2, 0.6, 0.1), DARK, M.Metal)
end
function B.CrateStack(m, cf)
    P(m, cf * CF(-0.3, 1.1, 0.2), V(2.2, 2.2, 2.2), LIGHTWOOD, M.WoodPlanks)
    P(m, cf * CF(0.5, 0.8, -0.9) * ANG(0, R(20), 0), V(1.6, 1.6, 1.6), WOOD, M.WoodPlanks)
    P(m, cf * CF(-0.2, 2.9, 0.1) * ANG(0, R(-12), 0), V(1.5, 1.4, 1.5), LIGHTWOOD:Lerp(DARK, 0.2), M.WoodPlanks)
end
function B.RugRed(m, cf) -- 3 x 2 rug
    P(m, cf * CF(0, 0.05, 0), V(11.4, 0.1, 7.4), C(150, 40, 46), M.Fabric)
    P(m, cf * CF(0, 0.07, 0), V(10.2, 0.1, 6.2), C(200, 160, 90), M.Fabric)
    P(m, cf * CF(0, 0.09, 0), V(9.6, 0.1, 5.6), C(150, 40, 46), M.Fabric)
    P(m, cf * CF(0, 0.11, 0) * ANG(0, R(45), 0), V(2.4, 0.1, 2.4), C(200, 160, 90), M.Fabric)
end
function B.RugNeon(m, cf) -- 2 x 2 rug
    P(m, cf * CF(0, 0.05, 0), V(7.4, 0.1, 7.4), C(30, 26, 44), M.Fabric)
    for k = 0, 3 do
        Glow(m, cf * ANG(0, k * math.pi / 2, 0) * CF(0, 0.08, 3.3), V(6.6, 0.06, 0.12), (k % 2 == 0) and PINK or CYAN, 0.1)
    end
    Glow(m, cf * CF(0, 0.08, 0) * ANG(0, R(45), 0), V(2.2, 0.06, 0.12), PINK, 0.1)
    Glow(m, cf * CF(0, 0.08, 0) * ANG(0, R(-45), 0), V(2.2, 0.06, 0.12), CYAN, 0.1)
end
function B.LanternStand(m, cf)
    Cyl(m, cf * CF(0, 2.8, 0.5), 5.6, 0.2, DARK, M.Wood)
    P(m, cf * CF(0, 5.5, 0), V(0.15, 0.15, 1.3), DARK, M.Wood)
    Ball(m, cf * CF(0, 4.6, -0.5), 1.6, C(230, 60, 50), M.Neon, { T = 0.2 })
    for _, y in ipairs({ 5.35, 3.85 }) do Cyl(m, cf * CF(0, y, -0.5), 0.2, 0.9, GOLD, M.Metal) end
    P(m, cf * CF(0, 0.1, 0.3), V(1.4, 0.2, 1.4), DARK, M.Wood)
end
function B.Kotatsu(m, cf) -- 2 x 2
    P(m, cf * CF(0, 1.2, 0), V(4.4, 0.3, 4.4), LIGHTWOOD, M.Wood)
    P(m, cf * CF(0, 0.65, 0), V(5.6, 0.9, 5.6), C(200, 90, 100), M.Fabric) -- the quilt
    for sx = -1, 1, 2 do P(m, cf * CF(sx * 3.5, 0.2, 0), V(1.4, 0.4, 2), C(70, 90, 150), M.Fabric) end -- floor cushions
    for sz = -1, 1, 2 do P(m, cf * CF(0, 0.2, sz * 3.5), V(2, 0.4, 1.4), C(70, 90, 150), M.Fabric) end
    for k = 0, 2 do Ball(m, cf * CF(-0.4 + k * 0.4, 1.55, 0.2), 0.45, C(240, 140, 40), M.SmoothPlastic) end -- mandarins
end
function B.WeaponRack(m, cf) -- 2 x 1 (UPDATE 6: shows the owner's three favourite guns in their skins; prompt = inspect / equip / set)
    P(m, cf * CF(0, 0.35, 1.0), V(7.6, 0.7, 1.1), DARK, M.Metal)
    P(m, cf * CF(0, 3.4, 1.35), V(7.4, 5.6, 0.3), C(132, 98, 66), M.WoodPlanks)
    P(m, cf * CF(0, 3.4, 1.18), V(6.9, 5.1, 0.06), C(40, 58, 46), M.Fabric) -- (a green baize panel: the guns read against it)
    for sx = -1, 1, 2 do P(m, cf * CF(sx * 3.75, 3.4, 1.2), V(0.25, 5.9, 0.5), STEEL, M.Metal) end
    P(m, cf * CF(0, 6.3, 1.15), V(7.8, 0.45, 0.65), DARK, M.Metal)
    Glow(m, cf * CF(0, 6.04, 0.9), V(7.0, 0.08, 0.1), AMBER, 0.25)
    for i, y in ipairs({ 1.5, 3.0, 4.5 }) do
        for sx = -1, 1, 2 do Cyl(m, cf * CF(sx * 2.3, y - 0.35, 0.85) * ANG(R(90), 0, 0), 0.8, 0.16, GOLD, M.Metal) end
        P(m, cf * CF(0, y, 0.7), V(0.2, 0.2, 0.2), DARK, M.SmoothPlastic, { T = 1, Name = "RackSlot" .. i })
        P(m, cf * CF(0, y - 0.62, 1.17), V(2.4, 0.3, 0.06), C(28, 22, 18), M.SmoothPlastic, { Name = "RackTag" .. i })
    end
end
function B.NeonSign(m, cf)
    P(m, cf * CF(0, 1.5, 0.3), V(0.3, 3, 0.3), DARK, M.Metal)
    P(m, cf * CF(0, 0.1, 0.3), V(1.6, 0.2, 1.2), DARK, M.Metal)
    local s = P(m, cf * CF(0, 4.2, 0.3), V(3.6, 2.4, 0.3), C(20, 16, 22), M.SmoothPlastic)
    Glow(m, cf * CF(0, 5.45, 0.3), V(3.7, 0.1, 0.36), PINK, 0)
    Glow(m, cf * CF(0, 2.95, 0.3), V(3.7, 0.1, 0.36), PINK, 0)
    Label(s, Enum.NormalId.Front, "營業中", PINK)
    Label(s, Enum.NormalId.Back, "OPEN", CYAN)
end
-- ===================== STATIONS (gold; one of each) =====================
function B.StashLocker(m, cf)
    P(m, cf * CF(0, 3.2, 0.3), V(3.2, 6.4, 2.6), C(60, 80, 100), M.Metal)
    for k = -1, 1, 2 do
        P(m, cf * CF(k * 0.78, 3.2, -1.0), V(1.45, 6.0, 0.1), C(80, 104, 128), M.Metal)
        for v = 0, 3 do P(m, cf * CF(k * 0.78, 5.6 - v * 0.25, -1.08), V(1.0, 0.08, 0.05), DARK, M.Metal) end
        P(m, cf * CF(k * 0.2, 3.2, -1.1), V(0.1, 0.7, 0.1), C(220, 200, 120), M.Metal)
    end
    local plate = Glow(m, cf * CF(0, 6.7, -0.9), V(2.6, 0.6, 0.1), C(70, 145, 255), 0.05)
    Label(plate, Enum.NormalId.Front, "STASH", C(255, 255, 255))
end
function B.ForgeBench(m, cf) -- 2 x 1
    P(m, cf * CF(0, 1.5, 0.3), V(7, 3, 2.6), C(70, 60, 56), M.Brick)
    P(m, cf * CF(0, 3.1, 0.3), V(7.2, 0.3, 2.8), C(40, 40, 44), M.Metal)
    -- the furnace mouth glowing + an anvil + tongs
    P(m, cf * CF(-1.8, 1.6, -1.0), V(2.2, 1.6, 0.1), C(30, 20, 18), M.Metal)
    Glow(m, cf * CF(-1.8, 1.5, -1.02), V(1.8, 1.0, 0.08), C(255, 120, 40), 0)
    P(m, cf * CF(1.6, 3.7, 0.3), V(2.2, 0.9, 1), STEEL, M.Metal)
    P(m, cf * CF(2.5, 3.9, 0.3), V(0.8, 0.5, 0.6), STEEL, M.Metal, { Wedge = true })
    P(m, cf * CF(0.2, 3.35, -0.4) * ANG(0, R(30), 0), V(2.2, 0.12, 0.2), DARK, M.Metal)
    Cyl(m, cf * CF(-2.4, 4.8, 0.9), 3.2, 0.9, C(60, 56, 54), M.Metal) -- the chimney
    local s = P(m, cf * CF(0, 5.4, 1.4), V(3.4, 1, 0.2), C(30, 22, 20), M.SmoothPlastic)
    Label(s, Enum.NormalId.Front, "FORGE", C(255, 160, 60))
end
function B.UpgradeAnvil(m, cf)
    P(m, cf * CF(0, 0.6, 0), V(2.4, 1.2, 2.2), C(70, 66, 64), M.Concrete)
    P(m, cf * CF(0, 1.6, 0), V(1.2, 0.8, 1.2), STEEL, M.Metal)
    P(m, cf * CF(0, 2.35, 0), V(3, 0.7, 1.3), C(150, 150, 158), M.Metal)
    P(m, cf * CF(1.8, 2.45, 0), V(0.8, 0.5, 0.9), C(150, 150, 158), M.Metal, { Wedge = true })
    Glow(m, cf * CF(0, 2.72, 0), V(2.4, 0.05, 0.3), C(240, 80, 90), 0.1)
    Cyl(m, cf * CF(-0.6, 2.95, 0.2) * ANG(0, 0, R(70)), 1.4, 0.18, LIGHTWOOD, M.Wood) -- the hammer
    P(m, cf * CF(0.05, 3.18, 0.2), V(0.5, 0.4, 0.4), DARK, M.Metal)
end
function B.SkillShrine(m, cf)
    P(m, cf * CF(0, 0.4, 0), V(3, 0.8, 3), C(60, 70, 64), M.Slate)
    P(m, cf * CF(0, 2.4, 0), V(1.4, 3.2, 1.4), C(50, 60, 56), M.Slate)
    local orb = Ball(m, cf * CF(0, 4.6, 0), 1.4, C(70, 225, 120), M.Neon, { T = 0.15 })
    orb.Name = "ShrineOrb"
    for k = 0, 2 do
        local a = k / 3 * math.pi * 2
        Glow(m, cf * CF(math.cos(a) * 0.72, 2.6, math.sin(a) * 0.72), V(0.1, 2.8, 0.1), C(70, 225, 120), 0.2)
    end
end
function B.DungeonPortal(m, cf) -- 2 x 1
    for sx = -1, 1, 2 do P(m, cf * CF(sx * 3, 3.6, 0.3), V(1, 7.2, 1.4), C(60, 30, 70), M.Slate) end
    P(m, cf * CF(0, 7.6, 0.3), V(7.2, 1, 1.6), C(60, 30, 70), M.Slate)
    local mem = P(m, cf * CF(0, 3.6, 0.3), V(5, 7, 0.3), C(230, 60, 230), M.Neon, { T = 0.4 })
    mem.Name = "PortalMembrane"
    P(m, cf * CF(0, 3.6, 0.45), V(4.6, 6.6, 0.1), C(20, 6, 30), M.SmoothPlastic, { T = 0.1 })
    for sx = -1, 1, 2 do Glow(m, cf * CF(sx * 2.45, 3.6, 0.1), V(0.12, 7, 0.12), C(255, 140, 255), 0) end
    P(m, cf * CF(0, 0.15, 0.3), V(7.4, 0.3, 2), C(40, 30, 44), M.Slate)
end
-- ===================== STATION AREAS (0.76, owner: "Add more hideout options: your own passive tree area, upgrade area
-- etc, anything that would befit") =====================
-- Bigger, living versions of the city's stations (each opens the same window). Moving parts are named for HideoutClient's
-- furniture animation: OrbitNode (circles the piece's centre), SpinRing (turns on its own axis), ShrineOrb (bobs), Holo.
function B.Observatory(m, cf) -- 3 x 3: the passive tree
    local SLATE, DEEP = C(46, 52, 60), C(20, 26, 34)
    Cyl(m, cf * CF(0, 0.3, 0), 0.6, 10.6, SLATE, M.Slate) -- the round dais
    Cyl(m, cf * CF(0, 0.62, 0), 0.06, 10.8, GOLD, M.Metal)
    Cyl(m, cf * CF(0, 0.64, 0), 0.05, 8.2, DEEP, M.Marble)
    for k = 0, 11 do -- a ring of floor runes
        local a = k / 12 * math.pi * 2
        Glow(m, cf * CF(math.cos(a) * 4.6, 0.66, math.sin(a) * 4.6) * ANG(0, -a, 0), V(0.5, 0.04, 0.16), C(70, 225, 120), 0.25)
    end
    for _, sx in ipairs({ -1, 1 }) do -- steps up
        P(m, cf * CF(sx * 0, 0.15, -5.3), V(3.2, 0.3, 0.8), SLATE, M.Slate)
    end
    -- the central pillar + its star
    Cyl(m, cf * CF(0, 2.0, 0), 2.8, 1.1, C(36, 40, 48), M.Marble)
    Cyl(m, cf * CF(0, 3.45, 0), 0.15, 1.6, GOLD, M.Metal)
    local star = Ball(m, cf * CF(0, 5.4, 0), 1.6, C(150, 255, 170), M.Neon, { T = 0.05 })
    star.Name = "ShrineOrb"
    local halo = Cyl(m, cf * CF(0, 5.4, 0) * ANG(0, 0, R(90)), 0.08, 3.2, C(90, 235, 140), M.Neon, { T = 0.35 })
    halo.Name = "SpinRing"
    local halo2 = Cyl(m, cf * CF(0, 5.4, 0) * ANG(R(70), 0, R(90)), 0.08, 3.8, C(255, 220, 110), M.Neon, { T = 0.45 })
    halo2.Name = "SpinRing"
    -- class nodes orbiting the star (the five class colours)
    local cols = { C(255, 170, 80), C(255, 110, 150), C(120, 210, 255), C(255, 120, 70), C(190, 120, 255) }
    for k, col in ipairs(cols) do
        local a = k / #cols * math.pi * 2
        local n = Ball(m, cf * CF(math.cos(a) * 3.3, 5.4 + math.sin(a * 2) * 0.6, math.sin(a) * 3.3), 0.55, col, M.Neon, { T = 0.05 })
        n.Name = "OrbitNode"
    end
    -- two lecterns with the tree on a slate
    for _, sx in ipairs({ -1, 1 }) do
        local lc = cf * CF(sx * 3.4, 0, -2.6) * ANG(0, R(sx * -20), 0)
        P(m, lc * CF(0, 1.5, 0), V(0.5, 1.8, 0.5), DARKWOOD, M.Wood)
        P(m, lc * CF(0, 2.5, -0.1) * ANG(R(-30), 0, 0), V(1.6, 0.12, 1.1), WOOD, M.Wood)
        Glow(m, lc * CF(0, 2.58, -0.12) * ANG(R(-30), 0, 0), V(1.3, 0.03, 0.8), C(70, 225, 120), 0.45)
    end
    local s = P(m, cf * CF(0, 1.35, -5.0), V(4, 0.7, 0.12), C(24, 28, 34), M.SmoothPlastic)
    Label(s, Enum.NormalId.Front, "PASSIVE TREE", C(120, 255, 160))
end
function B.ArmoryWorkshop(m, cf) -- 3 x 2: upgrades
    local IRON = C(58, 60, 66)
    P(m, cf * CF(0, 0.05, 0), V(11.6, 0.1, 7.6), C(44, 44, 48), M.DiamondPlate) -- the shop floor plate
    -- the long workbench with a gun in the vise
    P(m, cf * CF(-1.5, 2.0, 1.6), V(7, 0.3, 2.4), LIGHTWOOD, M.WoodPlanks)
    for _, x in ipairs({ -4.6, 1.6 }) do for _, z in ipairs({ 0.6, 2.6 }) do P(m, cf * CF(x, 1.0, z), V(0.3, 2.0, 0.3), IRON, M.Metal) end end
    P(m, cf * CF(-1.5, 0.6, 1.6), V(6.6, 0.15, 2.0), DARKWOOD, M.Wood) -- lower shelf
    P(m, cf * CF(-3.6, 2.5, 1.4), V(0.9, 0.7, 0.9), STEEL, M.Metal) -- the vise
    P(m, cf * CF(-2.5, 2.55, 1.4), V(2.6, 0.35, 0.35), DARK, M.Metal) -- the gun body
    P(m, cf * CF(-0.6, 2.6, 1.4), V(1.8, 0.14, 0.14), STEEL, M.Metal) -- its barrel
    P(m, cf * CF(-2.9, 2.2, 1.4), V(0.3, 0.6, 0.25), DARK, M.Metal) -- the grip
    Glow(m, cf * CF(-2.0, 2.76, 1.4), V(1.4, 0.04, 0.08), C(60, 210, 255), 0.2) -- an upgrade line on it
    for k = 0, 3 do P(m, cf * CF(0.4 + k * 0.4, 2.2, 2.3), V(0.25, 0.1, 0.5), ({ GOLD, STEEL, C(90, 170, 255), C(230, 120, 255) })[k + 1], M.Metal) end
    -- a tool wall behind
    P(m, cf * CF(-1.5, 3.6, 3.5), V(7.2, 4.8, 0.2), C(70, 74, 82), M.Metal)
    for k = 0, 6 do
        local x = -4.5 + k
        P(m, cf * CF(x, 4.0 + (k % 2) * 0.7, 3.35), V(0.15, 1.3, 0.12), STEEL, M.Metal)
        P(m, cf * CF(x, 4.75 + (k % 2) * 0.7, 3.33), V(0.45, 0.25, 0.12), DARK, M.Metal)
    end
    local s = P(m, cf * CF(-1.5, 5.6, 3.36), V(4, 0.8, 0.1), C(24, 26, 30), M.SmoothPlastic)
    Label(s, Enum.NormalId.Front, "FORGE", C(60, 210, 255)) -- (2026-11-01 owner: the piece opens the FORGE, so it says so)
    -- the anvil + a glowing quench basin on the right
    P(m, cf * CF(4.0, 0.7, -0.6), V(2.4, 1.4, 1.8), C(70, 66, 64), M.Concrete)
    P(m, cf * CF(4.0, 1.75, -0.6), V(2.8, 0.7, 1.2), C(150, 150, 158), M.Metal)
    P(m, cf * CF(5.6, 1.85, -0.6), V(0.7, 0.45, 0.8), C(150, 150, 158), M.Metal, { Wedge = true })
    local hot = Glow(m, cf * CF(4.0, 2.13, -0.6), V(1.2, 0.08, 0.4), C(255, 120, 40), 0)
    hot.Name = "ShrineOrb"
    Cyl(m, cf * CF(4.2, 0.5, -3.0), 1.0, 2.0, IRON, M.Metal)
    Glow(m, cf * CF(4.2, 1.02, -3.0), V(1.6, 0.04, 1.6), C(80, 200, 255), 0.3)
    -- a hanging forge lamp with a spinning fan
    Cyl(m, cf * CF(4.0, 6.0, -0.6), 0.2, 2.2, DARK, M.Metal)
    local fan = P(m, cf * CF(4.0, 5.85, -0.6), V(2.2, 0.06, 0.3), STEEL, M.Metal)
    fan.Name = "SpinRing"
    Glow(m, cf * CF(4.0, 5.6, -0.6), V(0.6, 0.3, 0.6), C(255, 210, 140), 0)
end
function B.Wardrobe(m, cf) -- 2 x 1: cosmetics
    P(m, cf * CF(0, 3.4, 0.6), V(7, 6.8, 2), DARKWOOD, M.Wood)
    P(m, cf * CF(0, 3.4, -0.36), V(6.6, 6.4, 0.08), C(30, 24, 22), M.Wood)
    Cyl(m, cf * CF(0, 5.8, -0.2) * ANG(0, 0, R(90)), 6.2, 0.15, GOLD, M.Metal) -- the rail
    local cols = { C(220, 60, 70), C(60, 140, 230), C(250, 190, 60), C(70, 200, 120), C(200, 90, 220), C(240, 240, 240) }
    for k, col in ipairs(cols) do
        local x = -2.7 + (k - 1) * 1.08
        P(m, cf * CF(x, 4.3, -0.2), V(0.9, 2.8, 0.5), col, M.Fabric)
        P(m, cf * CF(x, 5.75, -0.2), V(0.1, 0.25, 0.1), STEEL, M.Metal)
    end
    local mirror = P(m, cf * CF(-4.4, 3.0, 0.2) * ANG(0, R(25), 0), V(1.6, 5.2, 0.12), C(190, 220, 235), M.Glass, { T = 0.2 })
    mirror.Reflectance = 0.4
    Glow(m, cf * CF(0, 6.9, -0.4), V(6.4, 0.12, 0.12), C(255, 140, 210), 0.2)
    local s = P(m, cf * CF(0, 7.3, 0.6), V(3, 0.7, 0.1), C(30, 20, 30), M.SmoothPlastic)
    Label(s, Enum.NormalId.Front, "WARDROBE", C(255, 160, 220))
end
function B.ArchiveTerminal(m, cf) -- the Index (guns, rarities, bestiary)
    P(m, cf * CF(0, 0.4, 0), V(3, 0.8, 3), C(40, 44, 54), M.Metal)
    P(m, cf * CF(0, 1.8, 0.4), V(2.2, 2.0, 1.2), C(30, 34, 42), M.Metal)
    Glow(m, cf * CF(0, 2.3, -0.22), V(1.8, 1.0, 0.04), C(70, 160, 255), 0.15)
    Glow(m, cf * CF(0, 2.82, 0.2), V(1.4, 0.05, 1.4), CYAN, 0.3)
    local holo = P(m, cf * CF(0, 4.4, 0.2), V(1.8, 2.6, 0.06), CYAN, M.ForceField, { T = 0.25, Name = "Holo" })
    Ball(m, cf * CF(0, 4.4, 0.2), 1.1, C(120, 200, 255), M.ForceField, { T = 0.3, Name = "HoloOrb" })
    local s = P(m, cf * CF(0, 0.9, -1.52), V(2.6, 0.5, 0.06), C(20, 24, 30), M.SmoothPlastic)
    Label(s, Enum.NormalId.Front, "INDEX", C(120, 200, 255))
end
function B.ChallengeBoard(m, cf) -- 2 x 1: challenges
    for _, sx in ipairs({ -1, 1 }) do P(m, cf * CF(sx * 3.2, 3.2, 0.3), V(0.6, 6.4, 0.6), C(60, 50, 40), M.Metal) end
    P(m, cf * CF(0, 6.3, 0.3), V(7.2, 0.6, 0.7), C(60, 50, 40), M.Metal)
    P(m, cf * CF(0, 3.6, 0.35), V(5.6, 4.6, 0.15), C(26, 22, 20), M.Slate)
    for k = 0, 2 do
        local row = Glow(m, cf * CF(-0.4, 5.0 - k * 1.3, 0.24), V(4.0, 0.7, 0.04), ({ C(255, 210, 90), C(150, 220, 255), C(255, 120, 100) })[k + 1], 0.35)
        P(m, cf * CF(2.3, 5.0 - k * 1.3, 0.24), V(0.5, 0.5, 0.05), GOLD, M.Metal)
        local _ = row
    end
    local s = P(m, cf * CF(0, 6.3, -0.07), V(4.4, 0.5, 0.05), C(20, 18, 16), M.SmoothPlastic)
    Label(s, Enum.NormalId.Front, "CHALLENGES", C(255, 210, 90))
end
function B.SeasonBanner(m, cf) -- the season pass
    P(m, cf * CF(0, 0.3, 0), V(2.4, 0.6, 2.4), C(50, 44, 40), M.Slate)
    Cyl(m, cf * CF(0, 3.6, 0), 6.4, 0.25, GOLD, M.Metal)
    Cyl(m, cf * CF(0, 6.5, -0.2) * ANG(0, 0, R(90)), 2.6, 0.15, GOLD, M.Metal)
    local flag = P(m, cf * CF(0, 4.6, -0.25), V(2.4, 3.8, 0.08), C(130, 60, 220), M.Fabric)
    Glow(m, cf * CF(0, 5.6, -0.3), V(1.2, 1.2, 0.03), C(255, 220, 110), 0.1)
    P(m, cf * CF(0, 2.65, -0.25), V(2.4, 0.3, 0.1), GOLD, M.Metal)
    local _ = flag
end
function B.BlackMarketCrate(m, cf) -- the shop
    P(m, cf * CF(0, 1.1, 0), V(3, 2.2, 2.4), C(46, 40, 34), M.WoodPlanks)
    for _, y in ipairs({ 0.3, 1.9 }) do P(m, cf * CF(0, y, 0), V(3.1, 0.18, 2.5), DARK, M.Metal) end
    P(m, cf * CF(0, 2.5, 0.9) * ANG(R(-55), 0, 0), V(3, 0.15, 1.6), C(52, 46, 40), M.WoodPlanks) -- the lid, propped open
    Glow(m, cf * CF(0, 2.25, 0), V(2.6, 0.06, 2.0), C(160, 255, 140), 0.25) -- the loot glow
    for k = 0, 2 do P(m, cf * CF(-0.8 + k * 0.8, 2.3, -0.1) * ANG(0, k, R(10)), V(0.5, 0.3, 0.9), ({ GOLD, CYAN, PINK })[k + 1], M.Metal) end
    local s = P(m, cf * CF(0, 1.1, -1.23), V(2.2, 0.6, 0.05), C(18, 16, 14), M.SmoothPlastic)
    Label(s, Enum.NormalId.Front, "黑市 SHOP", C(160, 255, 140))
end
function B.TradeTerminal(m, cf) -- trading
    P(m, cf * CF(0, 0.5, 0), V(2.6, 1, 2.2), C(40, 44, 50), M.Metal)
    P(m, cf * CF(0, 2.0, 0.3), V(1.8, 2.2, 1.0), C(54, 58, 66), M.Metal)
    Glow(m, cf * CF(0, 2.4, -0.22), V(1.4, 0.8, 0.04), C(255, 190, 80), 0.15)
    local ring = Cyl(m, cf * CF(0, 3.9, 0.3) * ANG(0, 0, R(90)), 0.1, 1.6, C(255, 190, 80), M.Neon, { T = 0.2 })
    ring.Name = "SpinRing"
    Ball(m, cf * CF(0, 3.9, 0.3), 0.6, C(255, 220, 140), M.Neon, { T = 0.1, Name = "ShrineOrb" })
    local s = P(m, cf * CF(0, 0.6, -1.12), V(2.0, 0.5, 0.05), C(20, 20, 22), M.SmoothPlastic)
    Label(s, Enum.NormalId.Front, "TRADE", C(255, 200, 100))
end
-- ===================== DROPS: trophies (a plinth + the relic) =====================
local function Plinth(m, cf, accent)
    P(m, cf * CF(0, 0.9, 0), V(2.8, 1.8, 2.8), C(40, 38, 44), M.Marble)
    P(m, cf * CF(0, 1.85, 0), V(3.0, 0.15, 3.0), GOLD, M.Metal)
    Glow(m, cf * CF(0, 0.05, -1.45), V(2.8, 0.08, 0.08), accent, 0.1)
    return cf * CF(0, 1.95, 0)
end
local function Plaque(m, cf, text, accent)
    local s = P(m, cf * CF(0, 1.1, -1.45), V(2.2, 0.6, 0.08), C(30, 26, 30), M.SmoothPlastic)
    Label(s, Enum.NormalId.Front, text, accent, Enum.Font.GothamBold)
end
function B.TrophyTitan(m, cf)
    local top = Plinth(m, cf, AMBER)
    P(m, top * CF(0, 0.9, 0), V(2.2, 1.6, 1.8), C(80, 84, 92), M.DiamondPlate) -- the walker's head
    Glow(m, top * CF(0, 1.1, -0.92), V(1.4, 0.3, 0.05), RED, 0)
    for sx = -1, 1, 2 do Cyl(m, top * CF(sx * 1.2, 1.2, -0.2) * ANG(R(90), 0, 0), 1.6, 0.4, DARK, M.Metal) end
    Plaque(m, cf, "APEX TITAN", AMBER)
end
function B.TrophyGoliath(m, cf)
    local top = Plinth(m, cf, C(200, 120, 60))
    for k = 0, 4 do P(m, top * CF(-0.9 + k * 0.45, 0.35, 0), V(0.35, 0.5, 1.8), C(60, 60, 64), M.Metal) end -- a track
    Cyl(m, top * CF(0, 0.75, 0) * ANG(R(90), 0, 0), 2, 0.8, STEEL, M.Metal)
    Plaque(m, cf, "GOLIATH", C(200, 120, 60))
end
function B.TrophyPhantom(m, cf)
    local top = Plinth(m, cf, C(160, 90, 255))
    Cyl(m, top * CF(0, 1.6, 0) * ANG(0, 0, R(15)), 3.2, 0.15, DARK, M.Metal)
    P(m, top * CF(0.9, 3.0, 0) * ANG(0, 0, R(-30)), V(1.8, 0.5, 0.08), C(200, 200, 220), M.Metal)
    Glow(m, top * CF(0.9, 2.82, 0) * ANG(0, 0, R(-30)), V(1.7, 0.06, 0.1), C(160, 90, 255), 0)
    Plaque(m, cf, "PHANTOM", C(160, 90, 255))
end
function B.TrophySentinel(m, cf)
    local top = Plinth(m, cf, CYAN)
    P(m, top * CF(0, 1.2, 0) * ANG(R(45), R(30), R(45)), V(1.2, 1.2, 1.2), C(120, 220, 255), M.Glass, { T = 0.2 })
    Glow(m, top * CF(0, 1.2, 0), V(0.5, 0.5, 0.5), CYAN, 0)
    Plaque(m, cf, "SENTINEL", CYAN)
end
local RELIC = {
    Fire = { "MAGMA HEART", C(255, 110, 40) }, Ice = { "FROST CROWN", C(150, 220, 255) }, Void = { "VOID EYE", C(170, 90, 255) },
    Cyber = { "CYBER CORE", C(60, 255, 200) }, Storm = { "STORM ROD", C(120, 170, 255) }, Dream = { "DREAM MOON", C(255, 190, 240) },
    Flats = { "ROAD SUN", C(255, 200, 70) },
}
local function RelicBuilder(biome)
    return function(m, cf)
        local r = RELIC[biome]
        local top = Plinth(m, cf, r[2])
        if biome == "Storm" then
            Cyl(m, top * CF(0, 1.4, 0), 2.6, 0.25, STEEL, M.Metal)
            for k = 0, 2 do Glow(m, top * CF(0, 2.6 - k * 0.5, 0) * ANG(0, k, 0), V(0.9, 0.05, 0.05), r[2], 0) end
        elseif biome == "Ice" then
            for k = 0, 4 do
                local a = k / 5 * math.pi * 2
                P(m, top * CF(math.cos(a) * 0.55, 0.7, math.sin(a) * 0.55) * ANG(math.sin(a) * 0.3, a, math.cos(a) * 0.3), V(0.3, 1.2, 0.3), r[2], M.Glass, { T = 0.15 })
            end
        else
            Ball(m, top * CF(0, 1.0, 0), 1.5, r[2]:Lerp(C(0, 0, 0), 0.4), M.Glass, { T = 0.3 })
            Ball(m, top * CF(0, 1.0, 0), 0.8, r[2], M.Neon)
            Cyl(m, top * CF(0, 0.15, 0), 0.3, 1.4, GOLD, M.Metal)
        end
        Plaque(m, cf, r[1], r[2])
    end
end
function B.RelicLockwarden(m, cf)
    local top = Plinth(m, cf, C(255, 210, 90))
    Cyl(m, top * CF(0, 0.9, 0) * ANG(R(90), 0, 0), 0.4, 1.6, GOLD, M.Metal) -- the vault lock dial
    for k = 0, 3 do Glow(m, top * CF(0, 0.9, 0) * ANG(0, 0, k * math.pi / 2) * CF(0, 0.55, -0.22), V(0.12, 0.3, 0.05), ({ RED, CYAN, C(80, 255, 120), AMBER })[k + 1], 0) end
    Plaque(m, cf, "TUMBLER", C(255, 210, 90))
end
function B.RelicBroodmother(m, cf)
    local top = Plinth(m, cf, C(255, 90, 40))
    P(m, top * CF(0, 0.9, 0), V(1.3, 1.8, 1.3), C(120, 30, 30), M.SmoothPlastic, { Shape = Enum.PartType.Ball })
    Glow(m, top * CF(0, 0.95, -0.6), V(0.5, 0.9, 0.1), C(255, 120, 40), 0.2)
    Plaque(m, cf, "BROOD EGG", C(255, 90, 40))
end
function B.RelicDuelist(m, cf)
    local top = Plinth(m, cf, C(190, 110, 255))
    for sx = -1, 1, 2 do
        P(m, top * CF(sx * 0.3, 1.4, 0) * ANG(0, 0, R(sx * 20)), V(0.15, 2.6, 0.4), C(220, 220, 236), M.Metal)
        P(m, top * CF(sx * 0.05, 0.25, 0) * ANG(0, 0, R(sx * 20)), V(0.6, 0.15, 0.3), GOLD, M.Metal)
    end
    Plaque(m, cf, "DUELIST BLADES", C(190, 110, 255))
end
function B.RelicFortune(m, cf)
    local top = Plinth(m, cf, GOLD)
    P(m, top * CF(0, 0.9, 0), V(1.8, 1.6, 1.2), C(150, 30, 40), M.SmoothPlastic)
    for k = -1, 1 do Glow(m, top * CF(k * 0.5, 1.0, -0.62), V(0.38, 0.6, 0.05), CREAM, 0) end
    Cyl(m, top * CF(1.1, 1.2, 0), 1.2, 0.12, STEEL, M.Metal)
    Ball(m, top * CF(1.1, 1.85, 0), 0.35, RED, M.SmoothPlastic)
    Plaque(m, cf, "JACKPOT", GOLD)
end
function B.ApexPedestal(m, cf) -- the rarest drop: any boss on Ruin or higher
    local top = Plinth(m, cf, C(255, 255, 255))
    for k = 0, 5 do
        local hue = Color3.fromHSV(k / 6, 0.6, 1)
        Glow(m, top * CF(0, 0.2 + k * 0.32, 0) * ANG(0, k * 0.5, 0), V(1.4 - k * 0.15, 0.12, 1.4 - k * 0.15), hue, 0.1)
    end
    P(m, top * CF(0, 2.5, 0) * ANG(R(45), 0, R(45)), V(0.7, 0.7, 0.7), C(255, 255, 255), M.Neon)
    Plaque(m, cf, "APEX", C(255, 240, 200))
end
-- ===================== ACHIEVEMENTS =====================
function B.ExoticCase(m, cf)
    P(m, cf * CF(0, 1.2, 0), V(3.2, 2.4, 2.6), C(40, 34, 30), M.Wood)
    P(m, cf * CF(0, 3.6, 0), V(3.0, 2.4, 2.4), C(200, 220, 230), M.SmoothPlastic, { T = 0.75 })
    P(m, cf * CF(0, 2.6, -0.2), V(2.4, 0.3, 0.5), C(30, 30, 34), M.Metal) -- a gun silhouette
    P(m, cf * CF(0.7, 2.35, -0.2), V(0.4, 0.5, 0.4), C(30, 30, 34), M.Metal)
    P(m, cf * CF(0, 2.6, -0.48) * ANG(0, 0, R(45)), V(0.3, 0.3, 0.1), C(255, 150, 40), M.Neon)
    Glow(m, cf * CF(0, 4.85, 0), V(3, 0.1, 2.4), C(255, 150, 40), 0.4)
    local s = P(m, cf * CF(0, 1.6, -1.32), V(2.4, 0.5, 0.05), C(20, 16, 14), M.SmoothPlastic)
    Label(s, Enum.NormalId.Front, "◆ RELIC", C(255, 150, 40))
end
function B.TrialPlaque(m, cf)
    P(m, cf * CF(0, 2.6, 0.6), V(3.2, 5.2, 0.6), DARKWOOD, M.Wood)
    local s = P(m, cf * CF(0, 3.2, 0.25), V(2.6, 2.6, 0.1), GOLD, M.Metal)
    Label(s, Enum.NormalId.Front, "BOSS\nTRIALS\nIII", C(40, 30, 20))
    P(m, cf * CF(0, 0.15, 0.5), V(3.4, 0.3, 1.6), DARK, M.Metal)
end
function B.TrialMonument(m, cf)
    P(m, cf * CF(0, 0.5, 0), V(3.4, 1, 3.4), C(30, 30, 34), M.Granite)
    P(m, cf * CF(0, 3.5, 0), V(1.4, 5, 1.4), C(30, 30, 34), M.Granite)
    P(m, cf * CF(0, 6.4, 0) * ANG(0, R(45), 0), V(1.2, 1.2, 1.2), GOLD, M.Metal)
    Glow(m, cf * CF(0, 3.5, -0.72), V(0.15, 4.6, 0.05), GOLD, 0)
    local s = P(m, cf * CF(0, 1.4, -1.72), V(2.6, 0.7, 0.05), C(20, 20, 24), M.SmoothPlastic)
    Label(s, Enum.NormalId.Front, "TRIAL V", GOLD)
end
function B.LevelBanner(m, cf)
    Cyl(m, cf * CF(0, 3.5, 0.6), 7, 0.25, DARK, M.Metal)
    P(m, cf * CF(0, 6.8, 0.3), V(3.4, 0.2, 0.2), GOLD, M.Metal)
    local s = P(m, cf * CF(0, 4.9, 0.3), V(3.0, 3.6, 0.08), C(120, 20, 30), M.Fabric)
    Label(s, Enum.NormalId.Front, "LV\n100", GOLD)
    P(m, cf * CF(0, 0.15, 0.6), V(1.6, 0.3, 1.6), DARK, M.Metal)
end
function B.MaxLevelBanner(m, cf)
    Cyl(m, cf * CF(0, 3.5, 0.6), 7, 0.25, GOLD, M.Metal)
    local s = P(m, cf * CF(0, 4.9, 0.3), V(3.0, 3.6, 0.08), C(20, 20, 30), M.Fabric)
    Label(s, Enum.NormalId.Front, "LV\n400", C(255, 240, 200))
    Glow(m, cf * CF(0, 6.8, 0.3), V(3.4, 0.15, 0.15), C(255, 240, 200), 0)
    P(m, cf * CF(0, 0.15, 0.6), V(1.6, 0.3, 1.6), GOLD, M.Metal)
end
function B.AscensionPedestal(m, cf)
    P(m, cf * CF(0, 0.6, 0), V(3, 1.2, 3), C(230, 226, 214), M.Marble)
    Cyl(m, cf * CF(0, 2.4, 0), 2.4, 1.2, C(230, 226, 214), M.Marble)
    local orb = Ball(m, cf * CF(0, 4.3, 0), 1.2, C(255, 230, 150), M.Neon, { T = 0.1 })
    orb.Name = "AscOrb"
    for k = 0, 1 do Glow(m, cf * CF(0, 4.3, 0) * ANG(R(90), k * 1.2, 0), V(2.2, 0.08, 2.2), GOLD, 0.6) end
end
function B.TitleWall(m, cf) -- 2 x 1 (UPDATE 6, owner: "display your titles instead of just showing colors": the owner's titles by name)
    P(m, cf * CF(0, 3.55, 1.25), V(7.4, 6.5, 0.3), C(50, 36, 30), M.WoodPlanks)
    for sx = -1, 1, 2 do P(m, cf * CF(sx * 3.72, 3.55, 1.1), V(0.18, 6.7, 0.35), GOLD, M.Metal) end
    for _, y in ipairs({ 0.25, 6.85 }) do P(m, cf * CF(0, y, 1.1), V(7.6, 0.2, 0.35), GOLD, M.Metal) end
    P(m, cf * CF(0, 6.05, 1.02), V(6.4, 0.85, 0.1), C(110, 22, 32), M.Fabric, { Name = "TitleBanner" })
    for r = 0, 1 do
        for c = 0, 3 do
            local i = r * 4 + c + 1
            P(m, cf * CF(-2.55 + c * 1.7, 4.55 - r * 1.75, 1.03), V(1.55, 1.45, 0.08), C(22, 20, 26), M.SmoothPlastic, { Name = "TitlePlaque" .. i })
            P(m, cf * CF(-2.55 + c * 1.7, 3.82 - r * 1.75, 1.02), V(1.55, 0.1, 0.08), C(90, 90, 96), M.Neon, { Name = "TitleEdge" .. i, T = 0.2 })
        end
    end
    local s = P(m, cf * CF(0, 0.95, 1.02), V(4, 0.7, 0.1), C(20, 16, 14), M.SmoothPlastic)
    Label(s, Enum.NormalId.Front, "TITLES", GOLD)
end
function B.StatsBoard(m, cf) -- 2 x 1 (UPDATE 6): the owner's lifetime numbers on a slate board
    for sx = -1, 1, 2 do
        Cyl(m, cf * CF(sx * 3.15, 2.9, 0.65), 5.8, 0.32, DARKWOOD, M.Wood)
        P(m, cf * CF(sx * 3.15, 0.12, 0.65), V(0.9, 0.24, 1.6), DARK, M.Metal)
    end
    P(m, cf * CF(0, 3.85, 0.65), V(6.6, 4.3, 0.28), DARKWOOD, M.Wood)
    P(m, cf * CF(0, 3.85, 0.48), V(6.1, 3.8, 0.06), C(18, 26, 24), M.Slate, { Name = "StatsScreen" })
    P(m, cf * CF(0, 1.6, 0.42), V(6.2, 0.14, 0.5), DARKWOOD, M.Wood)
    local h = P(m, cf * CF(0, 6.35, 0.6), V(3.6, 0.62, 0.18), GOLD, M.Metal)
    Label(h, Enum.NormalId.Front, "LIFETIME", C(40, 26, 12))
end
function B.TrophyShelf(m, cf) -- 2 x 1 (UPDATE 6): the owner's boss-trial trophies, exotics and best clear
    P(m, cf * CF(0, 3.2, 1.35), V(7.4, 6.4, 0.25), C(40, 30, 26), M.WoodPlanks)
    for sx = -1, 1, 2 do P(m, cf * CF(sx * 3.6, 3.2, 0.75), V(0.3, 6.4, 1.45), DARKWOOD, M.Wood) end
    local n = 0
    for s, y in ipairs({ 0.2, 2.2, 4.2 }) do
        P(m, cf * CF(0, y, 0.75), V(7.2, (s == 1) and 0.4 or 0.22, 1.4), DARKWOOD, M.Wood)
        P(m, cf * CF(0, y + ((s == 1) and 0.21 or 0.12), 0.06), V(7.0, 0.06, 0.06), GOLD, M.Metal)
        for k = -1, 1 do
            n += 1
            P(m, cf * CF(k * 2.3, y + ((s == 1) and 0.2 or 0.11), 0.75), V(0.2, 0.2, 0.2), DARK, M.SmoothPlastic, { T = 1, Name = "TrophySlot" .. n })
        end
    end
    P(m, cf * CF(0, 6.42, 0.75), V(7.5, 0.25, 1.5), DARKWOOD, M.Wood)
    Glow(m, cf * CF(0, 6.26, 0.4), V(6.8, 0.06, 0.1), C(255, 214, 140), 0.25)
    P(m, cf * CF(0, 6.95, 1.0), V(5.2, 0.7, 0.14), C(20, 16, 14), M.SmoothPlastic, { Name = "TrophyBanner" })
end
function B.Jukebox(m, cf) -- (UPDATE 6): picks the hideout's music (owner), plays it for everyone inside
    local BODY, WOODJ = C(120, 36, 48), C(112, 70, 40)
    P(m, cf * CF(0, 0.3, 0.2), V(3.2, 0.6, 2.4), DARK, M.Metal)
    P(m, cf * CF(0, 2.4, 0.3), V(3.0, 3.6, 2.2), WOODJ, M.Wood)
    Cyl(m, cf * CF(0, 4.2, 0.3) * ANG(R(90), 0, 0), 2.2, 3.0, WOODJ, M.Wood)
    for sx = -1, 1, 2 do
        P(m, cf * CF(sx * 1.42, 2.5, -0.62), V(0.36, 3.9, 0.5), BODY, M.SmoothPlastic)
        Glow(m, cf * CF(sx * 1.42, 2.5, -0.9), V(0.14, 3.7, 0.08), PINK, 0.1).Name = "JukeGlow"
    end
    for k = 0, 6 do
        local a = k / 6 * math.pi
        Glow(m, cf * CF(math.cos(a) * 1.42, 4.3 + math.sin(a) * 1.25, -0.84) * ANG(0, 0, a), V(0.12, 0.72, 0.08), AMBER, 0.1).Name = "JukeGlow"
    end
    -- the record on its turntable ledge in front of the cabinet, under a glass hood
    P(m, cf * CF(0, 3.05, -1.2), V(2.2, 0.2, 0.9), C(40, 30, 26), M.Wood)
    Cyl(m, cf * CF(0, 3.2, -1.2), 0.06, 0.82, C(18, 18, 20), M.SmoothPlastic, { Name = "SpinRing" })
    Cyl(m, cf * CF(0, 3.24, -1.2), 0.04, 0.3, C(220, 60, 60), M.SmoothPlastic)
    P(m, cf * CF(0, 3.65, -1.2), V(2.2, 1.0, 0.9), C(170, 210, 235), M.SmoothPlastic, { T = 0.82 })
    for k = 0, 4 do P(m, cf * CF(0, 0.95 + k * 0.3, -0.83), V(2.4, 0.1, 0.06), GOLD, M.Metal) end
    P(m, cf * CF(0, 2.65, -0.84), V(2.3, 0.45, 0.06), C(14, 10, 12), M.SmoothPlastic, { Name = "JukeLabel" })
end
-- ===================== ROBUX =====================
function B.KoiPond(m, cf) -- 2 x 2
    for k = 0, 7 do
        local a = k / 8 * math.pi * 2
        P(m, cf * CF(math.cos(a) * 3.2, 0.5, math.sin(a) * 3.2) * ANG(0, -a, 0), V(1.6, 1, 2.6), C(120, 116, 110), M.Slate)
    end
    Cyl(m, cf * CF(0, 0.45, 0), 0.1, 6.2, C(40, 110, 140), M.Glass, { T = 0.25 })
    Cyl(m, cf * CF(0, 0.2, 0), 0.1, 6.2, C(20, 50, 60), M.SmoothPlastic)
    for _, f in ipairs({ { 1, 0.6, C(250, 120, 40), 30 }, { -1.2, -0.4, C(240, 240, 240), 160 }, { 0.2, -1.4, C(250, 80, 40), 260 } }) do
        local fc = cf * CF(f[1], 0.38, f[2]) * ANG(0, R(f[4]), 0)
        local fish = P(m, fc, V(0.5, 0.2, 1.2), f[3], M.SmoothPlastic, { Shape = Enum.PartType.Ball, Name = "Koi" })
        P(m, fc * CF(0, 0, 0.7), V(0.5, 0.1, 0.4), f[3], M.SmoothPlastic)
    end
    for _, l in ipairs({ { 1.6, 1.6 }, { -1.8, 1.0 } }) do Cyl(m, cf * CF(l[1], 0.5, l[2]), 0.05, 1.0, C(70, 150, 70), M.SmoothPlastic) end
    Ball(m, cf * CF(1.6, 0.6, 1.6), 0.35, PINK, M.SmoothPlastic)
end
function B.Aquarium(m, cf) -- 2 x 1
    P(m, cf * CF(0, 1.2, 0.2), V(7, 2.4, 2.6), C(30, 30, 40), M.SmoothPlastic)
    P(m, cf * CF(0, 4.0, 0.2), V(6.8, 3.2, 2.4), C(80, 180, 230), M.Glass, { T = 0.6 })
    Glow(m, cf * CF(0, 5.62, 0.2), V(6.8, 0.1, 2.4), CYAN, 0.3)
    P(m, cf * CF(0, 2.5, 0.2), V(6.6, 0.2, 2.2), C(220, 200, 150), M.Sand)
    for _, f in ipairs({ { -2, 3.8, C(250, 120, 60) }, { 0.6, 4.4, C(255, 220, 60) }, { 2.2, 3.4, PINK } }) do
        P(m, cf * CF(f[1], f[2], 0.2), V(0.6, 0.35, 0.2), f[3], M.Neon, { Shape = Enum.PartType.Ball, Name = "Fish" })
    end
    for k = 0, 2 do P(m, cf * CF(-2.6 + k * 2.4, 3.2, 0.6), V(0.15, 1.4 + k * 0.3, 0.15), C(60, 170, 90), M.SmoothPlastic) end
end
function B.SakuraTree(m, cf) -- 2 x 2
    P(m, cf * CF(0, 0.3, 0), V(3.6, 0.6, 3.6), C(110, 100, 90), M.Slate)
    Cyl(m, cf * CF(0, 3, 0) * ANG(0, 0, R(6)), 5.4, 0.9, C(80, 50, 40), M.Wood)
    Cyl(m, cf * CF(0.9, 5.6, 0.3) * ANG(R(10), 0, R(-40)), 2.6, 0.5, C(80, 50, 40), M.Wood)
    Cyl(m, cf * CF(-0.9, 5.8, -0.2) * ANG(R(-10), 0, R(38)), 2.6, 0.5, C(80, 50, 40), M.Wood)
    for _, b in ipairs({ { 0, 7.2, 0, 3.6 }, { 1.8, 6.6, 0.5, 2.6 }, { -1.8, 6.8, -0.4, 2.8 }, { 0.4, 6.4, 1.6, 2.4 }, { -0.5, 6.5, -1.6, 2.4 } }) do
        Ball(m, cf * CF(b[1], b[2], b[3]), b[4], C(255, 176, 210), M.SmoothPlastic)
    end
    for k = 0, 5 do P(m, cf * CF(math.sin(k * 2.1) * 2.4, 0.05, math.cos(k * 1.7) * 2.4) * ANG(0, k, 0), V(0.4, 0.05, 0.3), C(255, 190, 220), M.SmoothPlastic) end
end
function B.HoloProjector(m, cf)
    Cyl(m, cf * CF(0, 0.4, 0), 0.8, 2.4, C(40, 44, 54), M.Metal)
    Glow(m, cf * CF(0, 0.82, 0), V(2, 0.05, 2), CYAN, 0.3)
    local holo = P(m, cf * CF(0, 3, 0), V(1.6, 3.4, 0.08), CYAN, M.ForceField, { T = 0.2, Name = "Holo" })
    Ball(m, cf * CF(0, 3.2, 0), 1.2, CYAN, M.ForceField, { T = 0.3, Name = "HoloOrb" })
end

-- ===== the catalog =====
local Items = {}
HideoutData.Items = Items
local Order = {}
HideoutData.Order = Order
local function Add(id, def)
    def.Id = id
    def.Build = def.Build or B[id]
    def.W, def.D = def.W or 1, def.D or 1
    def.Layer = def.Layer or "Floor"
    def.Max = def.Max or ((def.Source == "Gold" and not def.Station) and 10 or 1)
    Items[id] = def
    table.insert(Order, id)
end
-- GOLD
Add("Sofa", { Name = "Corner Sofa", Desc = "A worn red sofa with mismatched cushions.", Source = "Gold", Price = 300, Rarity = "Common", W = 2 })
Add("Armchair", { Name = "Armchair", Desc = "A blue reading chair.", Source = "Gold", Price = 150, Rarity = "Common" })
Add("CoffeeTable", { Name = "Coffee Table", Desc = "Low table, a mug and a magazine.", Source = "Gold", Price = 120, Rarity = "Common" })
Add("FloorLamp", { Name = "Floor Lamp", Desc = "A tall lamp with a warm shade.", Source = "Gold", Price = 100, Rarity = "Common" })
Add("PottedPlant", { Name = "Potted Plant", Desc = "Something green in a clay pot.", Source = "Gold", Price = 80, Rarity = "Common" })
Add("Bonsai", { Name = "Bonsai", Desc = "A tiny tree on a slate tray.", Source = "Gold", Price = 260, Rarity = "Uncommon" })
Add("Bookshelf", { Name = "Bookshelf", Desc = "Shelves of well-thumbed books.", Source = "Gold", Price = 220, Rarity = "Common", W = 2 })
Add("Bed", { Name = "Bed", Desc = "A low bed with a neon headboard strip.", Source = "Gold", Price = 400, Rarity = "Uncommon", W = 2, D = 2 })
Add("DiningSet", { Name = "Dining Set", Desc = "A table and four stools.", Source = "Gold", Price = 380, Rarity = "Uncommon", W = 2, D = 2 })
Add("TVStand", { Name = "TV Stand", Desc = "An old CRT set on a cabinet, console included.", Source = "Gold", Price = 350, Rarity = "Uncommon", W = 2 })
Add("ArcadeCabinet", { Name = "Arcade Cabinet", Desc = "AIM ARCADE: a 20-second flick game with a personal best. The screen shows the owner's high score; anyone can play.", Source = "Gold", Price = 500, Rarity = "Rare", Max = 2, Show = "Arcade", Prompt = "Play" })
Add("VendingMachine", { Name = "Vending Machine", Desc = "Cold drinks, any hour.", Source = "Gold", Price = 450, Rarity = "Uncommon" })
Add("CrateStack", { Name = "Crate Stack", Desc = "Stacked wooden crates.", Source = "Gold", Price = 60, Rarity = "Common" })
Add("RugRed", { Name = "Patterned Rug", Desc = "A big red and gold rug. Furniture can stand on it.", Source = "Gold", Price = 120, Rarity = "Common", W = 3, D = 2, Layer = "Rug" })
Add("RugNeon", { Name = "Neon Rug", Desc = "A dark rug with glowing edges. Furniture can stand on it.", Source = "Gold", Price = 160, Rarity = "Uncommon", W = 2, D = 2, Layer = "Rug" })
Add("LanternStand", { Name = "Lantern Stand", Desc = "A red paper lantern on a post.", Source = "Gold", Price = 140, Rarity = "Common" })
Add("Kotatsu", { Name = "Kotatsu", Desc = "A heated table with a quilt, cushions and mandarins.", Source = "Gold", Price = 320, Rarity = "Uncommon", W = 2, D = 2 })
Add("WeaponRack", { Name = "Weapon Rack", Desc = "A wall rack for your three favourite guns, in their skins. Inspect them, equip one, or pick what hangs there.", Source = "Gold", Price = 300, Rarity = "Uncommon", W = 2, Max = 3, Show = "Rack", Prompt = "Weapon rack" })
Add("StatsBoard", { Name = "Stats Board", Desc = "A slate board with your lifetime numbers: kills, weak-spot kills, deaths, runs, the deepest floor. Visitors read yours.", Source = "Gold", Price = 600, Rarity = "Uncommon", W = 2, Max = 1, Show = "Stats", Prompt = "Read stats" })
Add("TrophyShelf", { Name = "Trophy Shelf", Desc = "Your boss-trial trophies (bronze to platinum by tier), your relics and your best clear, on a lit shelf.", Source = "Gold", Price = 900, Rarity = "Rare", W = 2, Max = 1, Show = "Trophies", Prompt = "Inspect trophies" })
Add("Jukebox", { Name = "Jukebox", Desc = "Pick your hideout's music. Everyone inside hears it.", Source = "Gold", Price = 700, Rarity = "Uncommon", Max = 1, Show = "Jukebox", Prompt = "Pick music" })
Add("NeonSign", { Name = "Neon Sign", Desc = "營業中: open for business.", Source = "Gold", Price = 200, Rarity = "Uncommon" })
-- STATIONS (useful: open the same windows as the city's stations)
Add("StashLocker", { Name = "Stash Locker", Desc = "Your stash, at home.", Source = "Gold", Price = 800, Rarity = "Rare", Station = "Inventory", Max = 1, Prompt = "Open stash" })
Add("ForgeBench", { Name = "Forge Bench", Desc = "Daily roll, upgrades and affix rerolls, at home.", Source = "Gold", Price = 1500, Rarity = "Rare", W = 2, Station = "Roll", Max = 1, Prompt = "Use forge" })
Add("UpgradeAnvil", { Name = "Upgrade Anvil", Desc = "Upgrade your guns, at home.", Source = "Gold", Price = 1200, Rarity = "Rare", Station = "Upgrade", Max = 1, Prompt = "Upgrade" })
Add("SkillShrine", { Name = "Skill Shrine", Desc = "The passive tree, at home.", Source = "Gold", Price = 1200, Rarity = "Rare", Station = "Skills", Max = 1, Prompt = "Skill tree" })
Add("DungeonPortal", { Name = "Dungeon Portal", Desc = "Start a run straight from your hideout.", Source = "Gold", Price = 2500, Rarity = "Epic", W = 2, Station = "Dungeons", Max = 1, Prompt = "Dungeons" })
-- (0.76) station AREAS: big living set pieces + the rest of the city's windows
Add("Observatory", { Name = "Constellation Observatory", Desc = "Your own passive tree area: a starlit dais with your class stars circling.", Source = "Gold", Price = 9000, Rarity = "Epic", W = 3, D = 3, Station = "Skills", Max = 1, Prompt = "Passive tree" })
-- (2026-11-01 owner: "Armory" read wrong -- it opens the FORGE (rerolls / crafts) -> "Forge Workshop". The id stays ArmoryWorkshop:
-- saves store ids, and owned pieces must keep resolving.)
Add("ArmoryWorkshop", { Name = "Forge Workshop", Desc = "Your own Forge area for rerolls and crafts: a workbench, tool wall, anvil and quench basin.", Source = "Gold", Price = 8000, Rarity = "Epic", W = 3, D = 2, Station = "Upgrade", Max = 1, Prompt = "Forge" })
Add("Wardrobe", { Name = "Wardrobe", Desc = "Your cosmetics, at home: a rack of outfits and a mirror.", Source = "Gold", Price = 1500, Rarity = "Rare", W = 2, Station = "Cosmetics", Max = 1, Prompt = "Cosmetics" })
Add("ArchiveTerminal", { Name = "Index Terminal", Desc = "The Index (guns, rarities, bestiary), at home.", Source = "Gold", Price = 1200, Rarity = "Rare", Station = "Index", Max = 1, Prompt = "Index" })
Add("ChallengeBoard", { Name = "Challenge Board", Desc = "The daily challenge and aim trials, at home.", Source = "Gold", Price = 2000, Rarity = "Rare", W = 2, Station = "Challenges", Max = 1, Prompt = "Challenges" })
Add("SeasonBanner", { Name = "Season Banner", Desc = "Your season journey, at home.", Source = "Gold", Price = 800, Rarity = "Uncommon", Station = "Season", Max = 1, Prompt = "Season" })
Add("BlackMarketCrate", { Name = "Black Market Crate", Desc = "The black market's stock, at home.", Source = "Gold", Price = 1500, Rarity = "Rare", Station = "Shop", Max = 1, Prompt = "Shop" })
Add("TradeTerminal", { Name = "Trade Terminal", Desc = "Trade with other players, from home.", Source = "Gold", Price = 1000, Rarity = "Uncommon", Station = "Trade", Max = 1, Prompt = "Trade" })
-- DROPS (Drop = { Model = the boss's ModelName, Biome?, Chance per kill }; the chance grows with the difficulty)
Add("TrophyGoliath", { Name = "Goliath Trophy", Desc = "A track link from a Goliath.", Source = "Drop", Rarity = "Rare", Drop = { Model = "GoliathMiniBoss", Chance = 0.03 }, How = "Rare drop from Goliath" })
Add("TrophyPhantom", { Name = "Phantom Trophy", Desc = "A Phantom's scythe on a stand.", Source = "Drop", Rarity = "Rare", Drop = { Model = "PhantomMiniBoss", Chance = 0.03 }, How = "Rare drop from the Phantom" })
Add("TrophySentinel", { Name = "Sentinel Trophy", Desc = "A Sentinel's glowing crystal.", Source = "Drop", Rarity = "Rare", Drop = { Model = "SentinelMiniBoss", Chance = 0.03 }, How = "Rare drop from the Sentinel" })
Add("TrophyTitan", { Name = "Titan Trophy", Desc = "An Apex Titan's head.", Source = "Drop", Rarity = "Epic", Drop = { Model = "ApexTitanMech", Chance = 0.04 }, How = "Rare drop from the Apex Titan" })
for _, b in ipairs({ "Fire", "Ice", "Void", "Cyber", "Storm", "Dream", "Flats" }) do
    local r = RELIC[b]
    local name = r[1]:sub(1, 1) .. r[1]:sub(2):lower():gsub(" (%a)", function(c) return " " .. c:upper() end)
    Add("Relic" .. b, { Name = name, Desc = "A trophy of the " .. b .. " superboss.", Source = "Drop", Rarity = "Legendary",
        Drop = { Model = "BiomeSuperBoss", Biome = b, Chance = 0.06 }, How = "Drop from that biome's superboss", Build = RelicBuilder(b) })
end
Add("RelicLockwarden", { Name = "Tumbler", Desc = "The Lockwarden's dial.", Source = "Drop", Rarity = "Mythic", Drop = { Model = "TrialLockwarden", Chance = 0.08 }, How = "Drop from the Lockwarden (Boss Trial)" })
Add("RelicBroodmother", { Name = "Brood Egg", Desc = "An egg that never hatched. Probably.", Source = "Drop", Rarity = "Mythic", Drop = { Model = "TrialBroodmother", Chance = 0.08 }, How = "Drop from the Broodmother (Boss Trial)" })
Add("RelicDuelist", { Name = "Duelist Blades", Desc = "The Duelist's crossed blades.", Source = "Drop", Rarity = "Mythic", Drop = { Model = "TrialDuelist", Chance = 0.08 }, How = "Drop from the Duelist (Boss Trial)" })
Add("RelicFortune", { Name = "Jackpot Machine", Desc = "A piece of the Fortune Engine.", Source = "Drop", Rarity = "Mythic", Drop = { Model = "TrialFortuneEngine", Chance = 0.08 }, How = "Drop from the Fortune Engine (Boss Trial)" })
Add("ApexPedestal", { Name = "Apex Pedestal", Desc = "Only the highest tiers drop this.", Source = "Drop", Rarity = "Celestial", Drop = { Any = true, MinRank = 9, Chance = 0.01 }, How = "Very rare drop from any boss on Ruin or higher" })
-- ACHIEVEMENTS (Unlock(state) -> true once earned; you own one)
local function TrialBest(st)
    local best = 0
    for _, v in pairs(type(st.BossTrials) == "table" and st.BossTrials or {}) do if type(v) == "table" then best = math.max(best, tonumber(v.Best) or 0) end end
    return best
end
local function HasExotic(st)
    for _, w in ipairs(st.Inventory or {}) do if type(w) == "table" and w.Exotic then return true end end
    for _, g in ipairs(st.GearInventory or {}) do if type(g) == "table" and g.Exotic then return true end end
    if st.EquippedWeapon and st.EquippedWeapon.Exotic then return true end
    for _, g in pairs(st.EquippedGear or {}) do if type(g) == "table" and g.Exotic then return true end end
    return false
end
Add("ExoticCase", { Name = "Relic Display Case", Desc = "A lit case for a relic.", Source = "Achievement", Rarity = "Legendary", Unlock = HasExotic, How = "Own a relic" })
Add("TrialPlaque", { Name = "Trial Plaque", Desc = "Boss Trials, tier III.", Source = "Achievement", Rarity = "Epic", Unlock = function(st) return TrialBest(st) >= 3 end, How = "Clear any Boss Trial on tier III" })
Add("TrialMonument", { Name = "Trial Monument", Desc = "Boss Trials, tier V.", Source = "Achievement", Rarity = "Legendary", Unlock = function(st) return TrialBest(st) >= 5 end, How = "Clear any Boss Trial on tier V" })
Add("LevelBanner", { Name = "Level 100 Banner", Desc = "A banner for level 100.", Source = "Achievement", Rarity = "Epic", Unlock = function(st) return (st.Level or 1) >= 100 end, How = "Reach level 100" })
Add("MaxLevelBanner", { Name = "Level 400 Banner", Desc = "A banner for reaching level 400.", Source = "Achievement", Rarity = "Mythic", Unlock = function(st) return (st.Level or 1) >= 400 end, How = "Reach level 400" })
Add("AscensionPedestal", { Name = "Ascension Pedestal", Desc = "A golden orb for the Proving.", Source = "Achievement", Rarity = "Legendary", Unlock = function(st) return (tonumber(st.AscTrialBest) or 0) >= 2 end, How = "Clear the Proving II" })
Add("TitleWall", { Name = "Title Wall", Desc = "Your titles by name on brass-edged plaques (rarest first), your worn title on the banner. Inspect it for the full list.", Source = "Achievement", Rarity = "Epic", W = 2, Show = "Titles", Prompt = "Inspect titles",
    Unlock = function(st) local n = 0 for _ in pairs(type(st.UnlockedTitles) == "table" and st.UnlockedTitles or {}) do n += 1 end return n >= 3 end, How = "Unlock 3 titles" })
-- ROBUX (ProductId 0 = not on sale yet; free in Studio)
Add("KoiPond", { Name = "Koi Pond", Desc = "A stone pond with three koi.", Source = "Robux", Price = 199, ProductId = 0, Rarity = "Legendary", W = 2, D = 2 })
Add("Aquarium", { Name = "Neon Aquarium", Desc = "A long tank of glowing fish.", Source = "Robux", Price = 149, ProductId = 0, Rarity = "Epic", W = 2 })
Add("SakuraTree", { Name = "Sakura Tree", Desc = "A cherry blossom tree, petals and all.", Source = "Robux", Price = 249, ProductId = 0, Rarity = "Legendary", W = 2, D = 2 })
Add("HoloProjector", { Name = "Holo Projector", Desc = "A spinning hologram.", Source = "Robux", Price = 99, ProductId = 0, Rarity = "Epic" })

-- how many of `id` this state has (achievements: 1 once earned)
function HideoutData.OwnedCount(st: any, id: string): number
    local def = Items[id]
    if not def then return 0 end
    if def.Source == "Achievement" then
        local ok, yes = pcall(def.Unlock, st)
        return (ok and yes) and 1 or 0
    end
    local h = type(st.Hideout) == "table" and st.Hideout or {}
    return tonumber(type(h.Owned) == "table" and h.Owned[id]) or 0
end
function HideoutData.PlacedCount(layout: any, id: string, skip: number?): number
    local n = 0
    for i, e in ipairs(layout or {}) do if e.I == id and i ~= skip then n += 1 end end
    return n
end

-- ===== the grid =====
function HideoutData.Footprint(id: string, rot: number): (number, number)
    local d = Items[id]
    if not d then return 1, 1 end
    if (rot or 0) % 2 == 1 then return d.D, d.W end
    return d.W, d.D
end
-- local position (relative to the origin) of a piece's footprint centre; gx, gz = its lowest cell (1-based)
function HideoutData.CellCenter(id: string, gx: number, gz: number, rot: number): Vector3
    local w, d = HideoutData.Footprint(id, rot)
    local G, Rm = HideoutData.GRID, HideoutData.ROOM
    return V(Rm.X0 + (gx - 1) * G + w * G / 2, 0, Rm.Z0 + (gz - 1) * G + d * G / 2)
end
function HideoutData.PieceCFrame(e: any): CFrame
    local lp = HideoutData.CellCenter(e.I, e.X, e.Z, e.R or 0)
    return CF(HideoutData.Origin + lp) * ANG(0, math.pi - (e.R or 0) * math.pi / 2, 0) -- (turn 0: the front faces into the room, away from the north wall)
end
-- is (gx, gz, rot) free for `id`? skip = the layout index being moved
function HideoutData.CanPlace(layout: any, id: string, gx: number, gz: number, rot: number, skip: number?, exp: number?): (boolean, string?)
    local def = Items[id]
    if not def then return false, "Unknown piece." end
    if type(gx) ~= "number" or type(gz) ~= "number" or gx ~= math.floor(gx) or gz ~= math.floor(gz) then return false, "Bad spot." end
    rot = (rot or 0) % 4
    local w, d = HideoutData.Footprint(id, rot)
    local Rm = HideoutData.ROOM
    if gx < 1 or gz < 1 or gx + w - 1 > Rm.W or gz + d - 1 > Rm.D then return false, "That doesn't fit there." end
    -- the balcony (rows 10-11): its own area behind the south wall, and only with the BALCONY RIGHTS expansion
    local B = HideoutData.BALCONY_ROW
    if gz + d - 1 >= B then
        if gz < B then return false, "The balcony wall is in the way." end
        if not HideoutData.BalconyOpen(exp or #HideoutData.EXPANSIONS) then return false, "Buy BALCONY RIGHTS (Hideout > Home) to build out here." end
    end
    for x = gx, gx + w - 1 do
        for z = gz, gz + d - 1 do
            if HideoutData.RESERVED[x .. "," .. z] then return false, "Keep the doorways clear." end
        end
    end
    for i, e in ipairs(layout or {}) do
        if i ~= skip then
            local od = Items[e.I]
            if od and od.Layer == def.Layer then
                local ow, odd = HideoutData.Footprint(e.I, e.R or 0)
                if gx < e.X + ow and e.X < gx + w and gz < e.Z + odd and e.Z < gz + d then return false, "Something's already there." end
            end
        end
    end
    return true
end

-- build one piece into `parent`: a Model with the decoration + ONE invisible hitbox (walk collision + build-mode clicks)
function HideoutData.BuildPiece(parent: Instance, e: any, index: number?): Model?
    local def = Items[e.I]
    if not def or not def.Build then return nil end
    local m = Instance.new("Model")
    m.Name = e.I
    local cf = HideoutData.PieceCFrame(e)
    local ok, err = pcall(def.Build, m, cf)
    if not ok then warn("[Hideout] " .. e.I .. ": " .. tostring(err)) end
    local w, d = HideoutData.Footprint(e.I, e.R or 0)
    local G = HideoutData.GRID
    local h = (def.Layer == "Rug") and 0.2 or 6
    local hb = Instance.new("Part")
    hb.Name = "Hitbox"
    hb.Anchored = true
    hb.Transparency = 1
    hb.CanCollide = def.Layer ~= "Rug"
    hb.CanQuery = true
    hb.CanTouch = false
    hb.Size = V(w * G - 0.6, h, d * G - 0.6)
    hb.CFrame = CF(HideoutData.Origin + HideoutData.CellCenter(e.I, e.X, e.Z, e.R or 0) + V(0, h / 2, 0))
    hb.Parent = m
    m.PrimaryPart = hb
    if index then m:SetAttribute("Index", index) end
    m:SetAttribute("Piece", e.I)
    m.Parent = parent
    return m
end

local ACCENT_STASH = C(255, 170, 70)
-- (2026-10-07, owner: "The hideouts are terrible. It shouldn't be the same inside with a recolor, and there shouldn't be
-- a giant patch of land outside ... They should NOT be reskins"): each theme is its OWN BUILD. Only the floor plan is
-- shared (the floors, the door, the stash, the balcony barriers, the practice lines, the map room's device + portal: your
-- furniture stays put). THEME_LOOK is just those shared pieces' colours; everything else is in the theme's block.
local THEME_LOOK = {
    Apartment = { Wall = C(150, 128, 112), WallMat = M.Plaster, Trim = C(70, 52, 44), TrimMat = M.Wood, Floor = C(120, 84, 60), FloorMat = M.WoodPlanks,
        Ceil = C(60, 56, 54), CeilMat = M.Concrete, Slab = C(80, 80, 84), SlabMat = M.Concrete, Bay = C(70, 72, 78), BayMat = M.Concrete,
        Lines = C(200, 150, 40), LinesMat = M.Neon, Glass = C(150, 190, 210), GlassT = 0.82, Lamp = C(255, 214, 160), Light = C(255, 200, 150),
        Accent = C(255, 170, 70), MapFloor = C(60, 62, 70), MapFloorMat = M.Concrete },
    Aquarium = { Floor = C(58, 70, 86), FloorMat = M.Marble, Slab = C(58, 70, 86), SlabMat = M.Marble, Bay = C(52, 62, 78), BayMat = M.Marble,
        Lines = C(90, 220, 255), LinesMat = M.Neon, Accent = C(90, 220, 255), MapFloor = C(50, 60, 74), MapFloorMat = M.DiamondPlate },
    Forest = { Floor = C(128, 92, 60), FloorMat = M.WoodPlanks, Slab = C(116, 82, 54), SlabMat = M.WoodPlanks, Bay = C(110, 80, 54), BayMat = M.WoodPlanks,
        Lines = C(236, 230, 210), LinesMat = M.SmoothPlastic, Accent = C(255, 200, 110), MapFloor = C(118, 84, 56), MapFloorMat = M.WoodPlanks },
    Forge = { Floor = C(70, 62, 58), FloorMat = M.Slate, Slab = C(60, 52, 50), SlabMat = M.Basalt, Bay = C(64, 56, 52), BayMat = M.Slate,
        Lines = C(255, 140, 50), LinesMat = M.Neon, Accent = C(255, 150, 60), MapFloor = C(58, 50, 48), MapFloorMat = M.Slate },
    Starwhale = { Floor = C(92, 62, 44), FloorMat = M.WoodPlanks, Slab = C(80, 54, 40), SlabMat = M.WoodPlanks, Bay = C(70, 48, 36), BayMat = M.WoodPlanks,
        Lines = C(200, 154, 74), LinesMat = M.Metal, Accent = C(170, 205, 255), MapFloor = C(80, 54, 40), MapFloorMat = M.WoodPlanks },
    Crystal = { Floor = C(104, 72, 46), FloorMat = M.WoodPlanks, Slab = C(92, 64, 42), SlabMat = M.WoodPlanks, Bay = C(70, 74, 86), BayMat = M.Slate,
        Lines = C(90, 180, 255), LinesMat = M.Neon, Accent = C(255, 190, 110), MapFloor = C(64, 68, 80), MapFloorMat = M.Slate },
}

-- ===== STASH + PORTAL SKINS v2 (0.58 skins; 0.59, owner: "map device needs to be a part of the portal cosmetics and change
-- with it (not just color wise). Current portal skins are incredibly underwhelming and need far more effects and VFX + custom
-- sounds ... More hideout cosmetics (portals, chests ...) while also making them higher quality (retroactively ... default
-- as well)"). Sold in the Cosmetics store (HideoutStash / HideoutPortal), published as owner attrs HideoutStashSkin /
-- HideoutPortalSkin. A PORTAL skin is a set: the gate (PORTAL_BUILD), its own MAP DEVICE (DEVICE_BUILD: a different
-- object per skin), particles (Fx: Idle = always, Open = while the portal is open, Burst = once as it opens) and two
-- sounds (tools/make_portal_sfx.py: an opening sound + a loop while open). HideoutClient switches Fx / Snd on open.
-- Builders draw with B(cfLocal, size, color, mat, o) in their anchor's frame: the stash's front faces +X, the portal
-- and the device face +Z (the room). o.Open = shown only while open (the membrane is named "MapPortal").
HideoutData.STASH_SKINS = {
    { Id = "Standard", Name = "Theme Stash", Free = true, Desc = "Each hideout theme's own stash: a lit steel locker, a station locker or an iron-banded trunk with a lantern." },
    { Id = "Treasure", Name = "Pirate's Hoard", Rarity = "Epic", Price = 149, ProductId = 0, Color = C(220, 170, 60),
        Desc = "A barrel-lidded treasure chest bound in gold, its lock glowing, coins spilling at its feet and glinting." },
    { Id = "CyberVault", Name = "Cyber Vault", Rarity = "Legendary", Price = 199, ProductId = 0, Color = C(80, 220, 255),
        Desc = "A matte black bank vault: a lit combination dial that turns, neon seams, blinking status lights and a scanner beam." },
    { Id = "SakuraBox", Name = "Sakura Lacquer Box", Rarity = "Legendary", Price = 199, ProductId = 0, Color = C(255, 140, 180),
        Desc = "A black and red lacquer box with gold corners, sakura blossoms on the lid, a silk tassel and petals drifting down." },
    { Id = "VoidCoffer", Name = "Void Coffer", Rarity = "Mythic", Price = 249, ProductId = 0, Color = C(170, 90, 255),
        Desc = "An obsidian coffer cracked with violet light, crystals growing from its lid, an orb of the void bobbing above and wisps rising." },
    { Id = "DragonHoard", Name = "Dragon's Hoard", Rarity = "Mythic", Price = 249, ProductId = 0, Color = C(90, 220, 150),
        Desc = "A carved jade chest with a gold dragon coiled round it, a glowing pearl in its claws and gold dust in the air." },
    { Id = "FrostReliquary", Name = "Frost Reliquary", Rarity = "Legendary", Price = 199, ProductId = 0, Color = C(150, 220, 255),
        Desc = "A reliquary of blue ice, crystal spires on its lid and a cold mist pouring off it." },
    { Id = "Mimic", Name = "The Mimic", Rarity = "Mythic", Price = 249, ProductId = 0, Color = C(230, 70, 70),
        Desc = "It looks like a chest. It has teeth. It breathes, its eye glows, and it keeps your things very, very safe." },
    { Id = "Clockwork", Name = "Clockwork Strongbox", Rarity = "Legendary", Price = 199, ProductId = 0, Color = C(204, 156, 72),
        Desc = "A riveted steel safe trimmed in brass: two gears turning behind a porthole, a pressure gauge that wavers, a steam pipe venting." },
    { Id = "Geode", Name = "Geode Chest", Rarity = "Legendary", Price = 199, ProductId = 0, Color = C(170, 100, 255),
        Desc = "A rough stone chest split open, packed with glowing amethyst and azure crystal, its lid hovering above it as sparkles rise." },
    { Id = "Orrery", Name = "Astral Orrery", Rarity = "Mythic", Price = 249, ProductId = 0, Color = C(120, 160, 255),
        Desc = "A midnight-blue chest set with gold stars, a brass orrery on its lid: a sun and three planets circling at their own speeds." },
    { Id = "Ghostlight", Name = "Ghostlight Casket", Rarity = "Mythic", Price = 249, ProductId = 0, Color = C(150, 255, 200),
        Desc = "A black coffin bound in iron, pale-green candles at its head and foot, grave mist round its base and a small ghost circling it." },
}
HideoutData.PORTAL_SKINS = {
    { Id = "Riftgate", Name = "Riftgate", Free = true, Desc = "The map room's own gate: slate pillars carved with pulsing runes, a rune altar for its device, and a violet vortex that swirls open." },
    { Id = "Torii", Name = "Spirit Torii", Rarity = "Legendary", Price = 299, ProductId = 0, Color = C(230, 60, 50),
        Desc = "A vermilion torii and a stone lantern for its device. Opening it rings temple bells and fills the frame with warm spirit light and falling sakura." },
    { Id = "VoidEye", Name = "Eye of the Void", Rarity = "Mythic", Price = 399, ProductId = 0, Color = C(170, 80, 255),
        Desc = "A ring of floating obsidian shards round a violet eye, a hovering monolith for its device. It opens with a reversed roar, the void pouring inward." },
    { Id = "NeonArch", Name = "Neon Hexgate", Rarity = "Legendary", Price = 299, ProductId = 0, Color = C(60, 230, 255),
        Desc = "A hexagonal steel gate wired in cyan and magenta neon, a holo table for its device. It boots up with a synth sweep and a storm of data." },
    { Id = "InfernoMaw", Name = "Inferno Maw", Rarity = "Mythic", Price = 399, ProductId = 0, Color = C(255, 90, 30),
        Desc = "A horned demon mouth with iron teeth, a hellfire brazier for its device. It roars open in a burst of fire and keeps spitting embers." },
    { Id = "CelestialHalo", Name = "Celestial Halo", Rarity = "Mythic", Price = 399, ProductId = 0, Color = C(255, 220, 130),
        Desc = "Marble pillars inside three turning gold halos, an angel's font for its device. A harp glissando opens it and golden feathers drift through." },
    { Id = "Clockwork", Name = "Clockwork Gate", Rarity = "Legendary", Price = 299, ProductId = 0, Color = C(220, 160, 70),
        Desc = "A great brass gear that turns, smaller gears and a swinging pendulum, a spinning astrolabe for its device. It ticks open in a gust of steam." },
    { Id = "CoralArch", Name = "Coral Arch", Rarity = "Legendary", Price = 299, ProductId = 0, Color = C(255, 120, 140),
        Desc = "An arch of living coral and swaying kelp, a giant clam with a glowing pearl for its device. It opens in a swirl of sea water and bubbles." },
}
HideoutData.StashSkinById, HideoutData.PortalSkinById = {}, {}
for _, s in ipairs(HideoutData.STASH_SKINS) do HideoutData.StashSkinById[s.Id] = s end
for _, s in ipairs(HideoutData.PORTAL_SKINS) do HideoutData.PortalSkinById[s.Id] = s end

-- the portal sounds (rbxassetid; tools/audio_ids.json: portal_<Id>_open / _hum)
local PORTAL_SND = {
    Riftgate = { 105912558636449, 72034839624325 }, Torii = { 98496432384843, 132258184611385 }, VoidEye = { 85915341455169, 116968884815745 },
    NeonArch = { 136460855352043, 72815909647015 }, InfernoMaw = { 89026750607195, 100518530694378 }, CelestialHalo = { 72606620512358, 107749401071388 },
    Clockwork = { 139574823989429, 95466372951872 }, CoralArch = { 139250684973681, 138251036065818 },
}
HideoutData.PORTAL_SND = PORTAL_SND
local TEX = {
    Spark = "rbxasset://textures/particles/sparkles_main.dds", Fire = "rbxasset://textures/particles/fire_main.dds",
    Smoke = "rbxasset://textures/particles/smoke_main.dds", Petal = "rbxassetid://110016414100176", Bubble = "rbxassetid://136045779268819",
    Feather = "rbxassetid://80460881443909", Glow = "rbxassetid://128322159183195", Bolt = "rbxassetid://80452969261517",
}
local function NS(a, b) return NumberSequence.new(a, b or a) end
local function NSK(pts) local k = {} for _, p in ipairs(pts) do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2])) end return NumberSequence.new(k) end
-- a particle emitter on a part: mode "Idle" (always on), "Open" (while the portal is open), "Burst" (n at once when it opens)
local function Fx(part: BasePart, mode: string, o: any): ParticleEmitter?
    if mode == "Idle" and Kit and Kit.Low() then return nil end
    local e = Instance.new("ParticleEmitter")
    e.Name = "SkinFx"
    e.Texture = TEX[o.Tex or "Spark"] or o.Tex
    e.Color = ColorSequence.new(o.Color, o.Color2 or o.Color)
    e.Size = o.Size or NS(0.3)
    e.Transparency = o.T or NSK({ { 0, 1 }, { 0.15, 0.2 }, { 0.8, 0.3 }, { 1, 1 } })
    e.Lifetime = o.Life or NumberRange.new(1.5, 2.5)
    e.Rate = (mode == "Burst") and 0 or (o.Rate or 6)
    e.Speed = o.Speed or NumberRange.new(1, 2)
    e.SpreadAngle = o.Spread or Vector2.new(30, 30)
    e.Acceleration = o.Accel or Vector3.zero
    e.Rotation = NumberRange.new(0, 360)
    e.RotSpeed = o.RotSpeed or NumberRange.new(-60, 60)
    e.LightEmission = o.Light or 0.6
    e.LightInfluence = 0.2
    e.EmissionDirection = o.Dir or Enum.NormalId.Top
    if o.Shape then e.Shape = o.Shape; e.ShapeStyle = o.ShapeStyle or Enum.ParticleEmitterShapeStyle.Volume end
    if o.InOut then e.ShapeInOut = o.InOut end
    if o.Drag then e.Drag = o.Drag end
    if o.Lock then e.LockedToPart = true end
    e.Enabled = mode == "Idle"
    e:SetAttribute("FxMode", mode)
    if mode == "Burst" then e:SetAttribute("BurstN", o.N or 40) end
    e.Parent = part
    return e
end
-- a sound on a part: mode "Open" (once as it opens), "Hum" (loops while open), "Idle" (loops always, quiet)
local function Snd(part: BasePart, id: number, mode: string, vol: number)
    local s = Instance.new("Sound")
    s.Name = "SkinSnd"
    s.SoundId = "rbxassetid://" .. id
    s.Volume = vol
    s.Looped = mode ~= "Open"
    s.RollOffMode = Enum.RollOffMode.InverseTapered
    s.RollOffMinDistance = 8; s.RollOffMaxDistance = 70
    s:SetAttribute("SndMode", mode)
    s.Parent = part
    return s
end
-- a real flame (Roblox Fire: cheap and reads as fire, unlike a particle on a bright room); mode as Fx (Idle / Open)
local function Flame(part: BasePart, size: number, heat: number, color: Color3, color2: Color3, mode: string)
    local f = Instance.new("Fire")
    f.Name = "SkinFlame"
    f.Size = size; f.Heat = heat; f.Color = color; f.SecondaryColor = color2
    f.Enabled = mode == "Idle"
    f:SetAttribute("FxMode", mode)
    f.Parent = part
    return f
end
local function Light(part: BasePart, color: Color3, range: number, bright: number, openOnly: boolean?)
    local l = Instance.new("PointLight")
    l.Color = color; l.Range = range; l.Brightness = bright; l.Shadows = false
    if openOnly then l.Enabled = false; l:SetAttribute("FxMode", "Open") end
    l.Parent = part
    return l
end

local Cyl, Ball = Enum.PartType.Cylinder, Enum.PartType.Ball
local DISC = Enum.ParticleEmitterShape.Disc
local BOX = Enum.ParticleEmitterShape.Box
-- a HOOP: a real ring (n segments in the hub's local XY plane) riding an invisible hub that spins (Anim Spin on its
-- local axis). A cylinder part is a solid disc, never a ring.
local function Hoop(B, cf: CFrame, radius: number, n: number, thick: number, color: Color3, mat: Enum.Material, rate: number, axis: string)
    local hub = B(cf, V(0.2, 0.2, 0.2), color, mat, { T = 1, Anim = { "Spin", { Rate = rate, Axis = axis } } })
    local seg = 2 * math.pi * radius / n + 0.05
    for k = 0, n - 1 do
        local a = k / n * math.pi * 2
        local p = B(cf * CF(math.cos(a) * radius, math.sin(a) * radius, 0) * ANG(0, 0, a + math.pi / 2), V(seg, thick, thick), color, mat)
        p.Parent = hub
    end
    return hub
end
-- a ring of n blocks round (0, cy, 0) in the XY plane (the portal's face): radius r, each w long
local function RingXY(B, n, r, cy, w, h, d, color, mat, o)
    local parts = {}
    for k = 0, n - 1 do
        local a = k / n * math.pi * 2
        table.insert(parts, B(CF(math.cos(a) * r, cy + math.sin(a) * r, 0) * ANG(0, 0, a + math.pi / 2), V(w, h, d), color, mat, o))
    end
    return parts
end

local STASH_OLD = {
    -- (the two defaults, upgraded: a lit locker with a status light + a gentle glow; a trunk with a hanging lantern)
    Locker = function(B)
        B(CF(0, 2.2, 0), V(2.2, 4.4, 5), C(46, 50, 58), M.DiamondPlate)
        B(CF(1.15, 2.2, 0), V(0.12, 3.6, 4.4), C(30, 32, 38), M.Metal)
        B(CF(1.25, 3.9, 0), V(0.1, 0.25, 4.4), ACCENT_STASH, M.Neon, { Anim = { "Pulse", { Amp = 0.3, Rate = 0.8 } } })
        B(CF(1.22, 2.4, -1.6), V(0.12, 0.8, 0.25), C(200, 200, 210), M.Metal) -- (the handle)
        for k = 0, 3 do B(CF(1.22, 1.1 + k * 0.5, 1.6), V(0.06, 0.08, 0.9), C(20, 22, 26), M.Metal) end -- (vents)
        local led = B(CF(1.24, 3.4, 1.7), V(0.08, 0.2, 0.2), C(90, 255, 140), M.Neon, { Shape = Ball, Anim = { "Pulse", { Amp = 0.6, Rate = 2 } } })
        Light(led, C(255, 190, 110), 8, 0.6)
    end,
    Trunk = function(B)
        B(CF(0, 1.3, 0), V(2.8, 2.6, 5), C(120, 80, 46), M.Wood)
        B(CF(0, 2.6, 0) * ANG(0, R(90), 0), V(5, 2.8, 2.8), C(108, 72, 42), M.Wood, { Shape = Cyl })
        for _, z in ipairs({ -1.6, 1.6 }) do B(CF(0, 2.1, z), V(2.95, 4.1, 0.3), DARK, M.Metal) end
        B(CF(1.45, 2.3, 0), V(0.15, 0.7, 0.6), ACCENT_STASH, M.Neon)
        local lamp = B(CF(1.3, 0.55, 2.2), V(0.7, 1.1, 0.7), C(255, 200, 110), M.Neon, { T = 0.2, Anim = { "Pulse", { Amp = 0.25, Rate = 1.3 } } })
        B(CF(1.3, 1.2, 2.2), V(0.8, 0.15, 0.8), DARK, M.Metal)
        Light(lamp, C(255, 190, 110), 10, 0.8)
        Fx(lamp, "Idle", { Color = C(255, 210, 120), Size = NS(0.08), Rate = 2, Speed = NumberRange.new(0.4, 0.8), Life = NumberRange.new(2, 3) })
    end,
    Treasure = function(B)
        local WOOD, GOLD = C(110, 66, 36), C(232, 180, 60)
        B(CF(0, 1.15, 0), V(2.8, 2.3, 4.8), WOOD, M.Wood)
        B(CF(0, 2.3, 0) * ANG(0, R(90), 0), V(4.8, 2.8, 2.8), C(96, 58, 32), M.Wood, { Shape = Cyl })
        for _, z in ipairs({ -1.9, 0, 1.9 }) do
            B(CF(0, 1.15, z), V(2.9, 2.4, 0.28), GOLD, M.Metal)
            B(CF(0, 2.3, z) * ANG(0, R(90), 0), V(0.3, 2.95, 2.95), GOLD, M.Metal, { Shape = Cyl })
        end
        B(CF(1.45, 2.0, 0), V(0.16, 0.9, 0.8), GOLD, M.Metal)
        local lock = B(CF(1.55, 1.95, 0), V(0.08, 0.35, 0.3), C(255, 220, 110), M.Neon, { Anim = { "Pulse", { Amp = 0.4, Rate = 1.5 } } })
        local pile = B(CF(2.2, 0.15, 0), V(1.2, 0.3, 2.4), GOLD, M.Metal)
        for k = 0, 7 do B(CF(1.9 + (k % 3) * 0.35, 0.32 + (k > 3 and 0.12 or 0), -1 + k * 0.3) * ANG(R(k * 20), 0, R(70)), V(0.08, 0.5, 0.5), GOLD, M.Metal, { Shape = Cyl }) end
        Fx(pile, "Idle", { Color = C(255, 240, 160), Size = NSK({ { 0, 0 }, { 0.5, 0.25 }, { 1, 0 } }), Rate = 3, Speed = NumberRange.new(0, 0.2), Life = NumberRange.new(0.6, 1),
            Shape = BOX, Light = 1 })
        Light(lock, C(255, 200, 90), 7, 0.6)
    end,
    CyberVault = function(B)
        local BODY, NEON = C(22, 24, 30), C(80, 220, 255)
        B(CF(0, 2.2, 0), V(2.6, 4.4, 4.8), BODY, M.DiamondPlate)
        B(CF(1.32, 2.2, 0), V(0.08, 3.8, 4.2), C(34, 36, 44), M.Metal)
        B(CF(1.4, 2.5, 0.3), V(0.2, 1.7, 1.7), C(170, 176, 190), M.Metal, { Shape = Cyl })
        B(CF(1.36, 2.5, 0.3), V(0.1, 2.1, 2.1), NEON, M.Neon, { Shape = Cyl, T = 0.25, Anim = { "Spin", { Rate = 0.5, Axis = "X" } } })
        B(CF(1.52, 2.5, 0.3), V(0.1, 0.5, 0.5), C(40, 42, 50), M.Metal, { Shape = Cyl })
        for _, z in ipairs({ -2.05, 2.05 }) do B(CF(1.34, 2.2, z), V(0.06, 3.8, 0.12), NEON, M.Neon, { Anim = { "Pulse", { Amp = 0.4, Rate = 1.1 } } }) end
        for k = 0, 2 do B(CF(1.37, 3.7 - k * 0.45, -1.55), V(0.06, 0.2, 0.2), (k == 0) and C(80, 255, 140) or NEON, M.Neon, { Shape = Ball, Anim = { "Pulse", { Amp = 0.8, Rate = 1.5 + k } } }) end
        B(CF(0, 4.45, 0), V(2.7, 0.1, 4.9), NEON, M.Neon, { T = 0.5 })
        local scan = B(CF(1.6, 2.2, 0), V(0.05, 0.08, 4.2), NEON, M.Neon, { T = 0.3, Anim = { "Bob", { Amp = 1.6, Rate = 1.0, NoTurn = true } } }) -- (the scanner beam)
        Light(scan, NEON, 8, 0.7)
    end,
    SakuraBox = function(B)
        local LAC, RED, GOLD, PINK = C(26, 12, 16), C(176, 30, 44), C(232, 184, 70), C(255, 160, 196)
        B(CF(0, 1.2, 0), V(2.6, 2.4, 4.6), LAC, M.SmoothPlastic, { Refl = 0.08 })
        B(CF(0, 2.65, 0), V(2.8, 0.5, 4.8), RED, M.SmoothPlastic, { Refl = 0.08 })
        for _, x in ipairs({ -1.3, 1.3 }) do for _, z in ipairs({ -2.3, 2.3 }) do B(CF(x, 1.4, z), V(0.12, 2.8, 0.12), GOLD, M.Metal) end end
        B(CF(1.42, 1.5, 0), V(0.1, 0.5, 0.9), GOLD, M.Metal)
        for k = 0, 6 do
            local a, rr = k * 0.9, (k % 2 == 0) and 1.2 or 0.6
            B(CF(math.cos(a) * 0.6, 2.95, math.sin(a) * rr), V(0.32, 0.12, 0.32), PINK, M.SmoothPlastic, { Shape = Ball })
            B(CF(math.cos(a) * 0.6, 2.98, math.sin(a) * rr), V(0.1, 0.1, 0.1), C(255, 230, 120), M.Neon, { Shape = Ball })
        end
        B(CF(1.42, 0.9, 0), V(0.06, 1.2, 0.06), RED, M.Fabric, { Anim = { "Sway", { Amp = 0.12, Rate = 1.4 } } })
        B(CF(1.42, 0.25, 0), V(0.18, 0.4, 0.18), RED, M.Fabric, { Shape = Ball })
        local src = B(CF(0, 5.5, 0), V(3, 0.2, 5), PINK, M.SmoothPlastic, { T = 1 })
        Fx(src, "Idle", { Tex = "Petal", Color = C(255, 180, 210), Color2 = C(255, 220, 235), Size = NS(0.35), Rate = 2.5, Speed = NumberRange.new(0.3, 0.8),
            Life = NumberRange.new(3, 4), Accel = V(0, -0.6, 0), Dir = Enum.NormalId.Bottom, Shape = BOX, Light = 0.1, RotSpeed = NumberRange.new(-120, 120) })
    end,
    VoidCoffer = function(B)
        local OBS, VIO = C(20, 14, 30), C(170, 90, 255)
        B(CF(0, 1.3, 0), V(2.6, 2.6, 4.6), OBS, M.Slate)
        B(CF(0, 2.75, 0), V(2.8, 0.3, 4.8), C(30, 22, 44), M.Slate)
        for _, z in ipairs({ -1.4, 0.2, 1.6 }) do B(CF(1.31, 1.3, z) * ANG(R(25 * z), 0, 0), V(0.05, 2.2, 0.1), VIO, M.Neon, { Anim = { "Pulse", { Amp = 0.5, Rate = 0.9 } } }) end
        for k, c in ipairs({ { -0.4, -1.2, 1.3 }, { 0.3, 0.4, 1.8 }, { -0.2, 1.4, 1.1 } }) do
            B(CF(c[1], 2.9 + c[3] / 2, c[2]) * ANG(0, R(k * 40), R(8 * k)), V(0.5, c[3], 0.5), VIO, M.Neon, { T = 0.15 })
        end
        local orb = B(CF(0, 4.6, 0), V(0.7, 0.7, 0.7), VIO, M.Neon, { Shape = Ball, Anim = { "Bob", { Amp = 0.25, Rate = 1.4 } } })
        Light(orb, VIO, 9, 0.8)
        Fx(orb, "Idle", { Tex = "Smoke", Color = C(120, 60, 200), Color2 = C(30, 10, 60), Size = NSK({ { 0, 0.3 }, { 1, 1.4 } }), Rate = 4, Speed = NumberRange.new(0.4, 1),
            Life = NumberRange.new(1.5, 2.5), Light = 0.3, T = NSK({ { 0, 1 }, { 0.3, 0.6 }, { 1, 1 } }) })
    end,
    DragonHoard = function(B)
        local JADE, GOLD, RED = C(30, 120, 80), C(214, 160, 50), C(170, 30, 40)
        B(CF(0, 1.2, 0), V(2.7, 2.4, 4.8), JADE, M.Marble)
        B(CF(0, 2.55, 0), V(2.9, 0.4, 5), C(22, 90, 60), M.Marble)
        for _, z in ipairs({ -2.2, 2.2 }) do B(CF(0, 1.3, z), V(2.8, 2.6, 0.3), GOLD, M.Metal) end
        for _, z in ipairs({ -2.35, 2.35 }) do for _, x in ipairs({ -1.4, 1.4 }) do B(CF(x, 2.6, z), V(0.35, 0.5, 0.35), GOLD, M.Metal) end end -- (corner caps)
        -- the lock: a gold medallion with a ruby heart
        B(CF(1.38, 1.5, 0), V(0.12, 1.2, 1.2), GOLD, M.Metal, { Shape = Cyl })
        B(CF(1.44, 1.5, 0), V(0.06, 0.5, 0.5), RED, M.Neon, { Shape = Cyl, Anim = { "Pulse", { Amp = 0.3, Rate = 1.2 } } })
        -- the dragon: an S of even gold segments lying ON the lid (top at y 2.75), a dorsal spike on every other one,
        -- its head reaching over the front edge with horns, glowing eyes and the pearl in its jaws
        local N = 14
        for k = 0, N - 1 do
            local u = k / (N - 1)
            local r = 0.34 - u * 0.12
            local x, z = -0.9 + math.sin(u * math.pi * 1.6) * 0.7 + u * 1.6, -2.1 + u * 3.9
            B(CF(x, 2.75 + r, z), V(r * 2, r * 2, r * 2), GOLD, M.Metal, { Shape = Ball })
            if k % 2 == 0 and k < N - 1 then B(CF(x, 2.75 + r * 2 + 0.12, z) * ANG(R(-20), 0, 0), V(0.08, 0.3, 0.22), RED, M.SmoothPlastic, { Wedge = true }) end
        end
        local hx, hy, hz = 1.35, 3.1, 1.95
        B(CF(hx, hy, hz), V(0.8, 0.6, 0.7), GOLD, M.Metal) -- (head)
        B(CF(hx + 0.55, hy - 0.08, hz), V(0.5, 0.36, 0.5), GOLD, M.Metal) -- (snout)
        B(CF(hx + 0.5, hy - 0.42, hz), V(0.55, 0.14, 0.45), GOLD, M.Metal) -- (jaw)
        for _, s2 in ipairs({ -1, 1 }) do
            B(CF(hx - 0.35, hy + 0.45, hz + s2 * 0.22) * ANG(0, 0, R(35)), V(0.1, 0.7, 0.1), C(240, 230, 200), M.SmoothPlastic) -- (horns)
            B(CF(hx + 0.2, hy + 0.12, hz + s2 * 0.36), V(0.14, 0.12, 0.06), C(255, 60, 40), M.Neon) -- (eyes)
            B(CF(hx + 0.85, hy - 0.1, hz + s2 * 0.2) * ANG(R(s2 * 25), 0, R(-15)), V(0.7, 0.04, 0.04), GOLD, M.Metal, { Anim = { "Sway", { Amp = 0.12, Rate = 1.4 } } }) -- (whiskers)
        end
        local pearl = B(CF(hx + 0.9, hy - 0.3, hz), V(0.42, 0.42, 0.42), C(240, 250, 255), M.Neon, { Shape = Ball, Anim = { "Pulse", { Amp = 0.3, Rate = 1 } } })
        Light(pearl, C(180, 255, 220), 8, 0.7)
        Fx(pearl, "Idle", { Color = C(255, 220, 120), Size = NS(0.12), Rate = 5, Speed = NumberRange.new(0.3, 0.9), Life = NumberRange.new(1.5, 2.5), Spread = Vector2.new(180, 180) })
    end,
    FrostReliquary = function(B)
        local ICE, DEEP, STEEL, GLOW = C(120, 170, 210), C(40, 70, 120), C(150, 160, 175), C(140, 220, 255)
        B(CF(0, 1.25, 0), V(2.6, 2.5, 4.6), ICE, M.Glacier)
        B(CF(0, 2.62, 0), V(2.8, 0.25, 4.8), DEEP, M.Ice)
        B(CF(0, 0.12, 0), V(2.8, 0.25, 4.8), DEEP, M.Ice)
        for _, x in ipairs({ -1.32, 1.32 }) do for _, z in ipairs({ -2.32, 2.32 }) do B(CF(x, 1.35, z), V(0.16, 2.6, 0.16), STEEL, M.Metal) end end -- (frame posts)
        for _, z in ipairs({ -2.32, 2.32 }) do B(CF(1.32, 2.5, z * 0.5), V(0.16, 0.16, 2.3), STEEL, M.Metal) end
        -- a snowflake on the front: six thin glowing arms with a fork on each
        local core = B(CF(1.33, 1.3, 0), V(0.06, 0.36, 0.36), GLOW, M.Neon, { Shape = Cyl, Anim = { "Pulse", { Amp = 0.35, Rate = 0.7 } } })
        for k = 0, 5 do
            local ang = k * math.pi / 3
            local arm = CF(1.34, 1.3, 0) * ANG(ang, 0, 0)
            B(arm * CF(0, 0.5, 0), V(0.04, 0.9, 0.07), GLOW, M.Neon)
            for _, sgn in ipairs({ -1, 1 }) do B(arm * CF(0, 0.65, 0) * ANG(R(sgn * 40), 0, 0) * CF(0, 0.12, 0), V(0.04, 0.26, 0.05), GLOW, M.Neon) end
        end
        -- icicles along the lid's front edge
        for k = 0, 6 do B(CF(1.38, 2.25, -1.9 + k * 0.63) * ANG(0, 0, R(180)), V(0.12, 0.3 + (k % 3) * 0.14, 0.16), C(210, 240, 255), M.Ice, { Wedge = true, T = 0.15 }) end
        -- crystal clusters growing from the lid: each a shaft + a pointed tip, leaning out
        for k, c in ipairs({ { 0.1, -1.3, 1.3, 15 }, { -0.3, -0.2, 2.0, -8 }, { 0.3, 0.6, 1.5, 12 }, { -0.1, 1.5, 1.1, -18 }, { 0.5, -0.7, 0.8, 30 } }) do
            local base = CF(c[1], 2.75, c[2]) * ANG(R(c[4]), R(k * 37), R(c[4] * 0.5))
            B(base * CF(0, c[3] / 2, 0), V(0.42, c[3], 0.42), C(190, 230, 255), M.Ice, { T = 0.1 })
            B(base * CF(0, c[3] + 0.22, 0), V(0.42, 0.45, 0.42), C(230, 248, 255), M.Ice, { Wedge = true, T = 0.1 })
        end
        Light(core, GLOW, 9, 0.6)
        local mist = B(CF(0.9, 0.3, 0), V(1, 0.2, 4.4), ICE, M.SmoothPlastic, { T = 1 })
        Fx(mist, "Idle", { Tex = "Smoke", Color = C(200, 230, 255), Size = NSK({ { 0, 0.4 }, { 1, 1.6 } }), Rate = 4, Speed = NumberRange.new(0.3, 0.7),
            Life = NumberRange.new(2, 3), Accel = V(0, -0.2, 0), Dir = Enum.NormalId.Right, Light = 0, Shape = BOX, T = NSK({ { 0, 1 }, { 0.3, 0.75 }, { 1, 1 } }) })
        Fx(core, "Idle", { Color = C(220, 245, 255), Size = NS(0.08), Rate = 3, Speed = NumberRange.new(0.2, 0.5), Life = NumberRange.new(1.5, 2.5), Spread = Vector2.new(180, 180) })
    end,
    Mimic = function(B)
        local WOOD, IRON, RED = C(100, 62, 34), C(60, 56, 54), C(180, 40, 50)
        local body = B(CF(0, 1.2, 0), V(2.7, 2.4, 4.8), WOOD, M.Wood)
        B(CF(0, 2.7, 0) * ANG(0, 0, R(-12)), V(2.8, 0.7, 4.9), C(90, 56, 30), M.Wood, { Anim = { "Bob", { Amp = 0.12, Rate = 1.6, NoTurn = true } } })
        for _, z in ipairs({ -2.1, 2.1 }) do B(CF(0, 1.4, z), V(2.85, 2.8, 0.25), IRON, M.Metal) end
        for k = 0, 7 do -- teeth along the lid's lip
            B(CF(1.38, 2.25, -1.9 + k * 0.54) * ANG(0, 0, R(180)), V(0.25, 0.35, 0.3), C(240, 236, 220), M.SmoothPlastic, { Wedge = true })
        end
        B(CF(1.3, 2.05, 0), V(0.3, 0.12, 3.6), RED, M.SmoothPlastic)
        local tongue = B(CF(1.7, 1.75, 0.6) * ANG(0, 0, R(-35)), V(1.2, 0.18, 0.6), C(200, 70, 90), M.SmoothPlastic, { Anim = { "Sway", { Amp = 0.15, Rate = 2.2 } } })
        local eye = B(CF(1.4, 3.15, -1.2), V(0.4, 0.4, 0.4), C(255, 220, 60), M.Neon, { Shape = Ball, Anim = { "Pulse", { Amp = 0.7, Rate = 0.6 } } })
        Light(eye, C(255, 200, 80), 6, 0.6)
        Fx(body, "Idle", { Tex = "Smoke", Color = C(70, 40, 40), Size = NS(0.4), Rate = 0.8, Speed = NumberRange.new(0.2, 0.5), Life = NumberRange.new(1, 1.6), Dir = Enum.NormalId.Right, Light = 0 })
        local _ = tongue
    end,
    -- (0.89, owner: "more hideout, chest and stash skins", references: an ARPG shop's hideout + stash looks -- original)
    -- CLOCKWORK STRONGBOX: a riveted steel safe in brass, a porthole showing two gears turning against each other, a
    -- pressure gauge whose needle wavers, a steam pipe venting now and then
    Clockwork = function(B)
        local STEEL, BRASS, COPPER = C(58, 62, 70), C(204, 156, 72), C(184, 110, 70)
        B(CF(0, 1.5, 0), V(2.6, 3, 4.8), STEEL, M.DiamondPlate)
        B(CF(0, 3.1, 0), V(2.8, 0.25, 5), BRASS, M.Metal)
        B(CF(0, 0.12, 0), V(2.8, 0.25, 5), BRASS, M.Metal)
        for _, z in ipairs({ -2.35, 2.35 }) do B(CF(0, 1.6, z), V(2.75, 3.1, 0.2), BRASS, M.Metal) end
        for _, y in ipairs({ 0.6, 2.6 }) do for _, z in ipairs({ -2, -1, 1, 2 }) do B(CF(1.32, y, z), V(0.1, 0.18, 0.18), BRASS, M.Metal, { Shape = Ball }) end end -- (rivets)
        -- the porthole: a brass ring, dark glass, two gears inside (each a disc + teeth riding a spinning hub)
        B(CF(1.33, 1.6, -0.4), V(0.12, 2.3, 2.3), BRASS, M.Metal, { Shape = Cyl })
        B(CF(1.36, 1.6, -0.4), V(0.08, 1.9, 1.9), C(20, 22, 28), M.SmoothPlastic, { Shape = Cyl })
        local function Gear(cf: CFrame, r: number, teeth: number, rate: number, col: Color3)
            local hub = B(cf, V(0.1, r * 1.3, r * 1.3), col, M.Metal, { Shape = Cyl, Anim = { "Spin", { Rate = rate, Axis = "X" } } })
            for k = 0, teeth - 1 do
                local a = k / teeth * math.pi * 2
                local t = B(cf * ANG(a, 0, 0) * CF(0, r * 0.72, 0), V(0.1, r * 0.3, r * 0.26), col, M.Metal); t.Parent = hub
            end
            local cap = B(cf * CF(0.05, 0, 0), V(0.08, r * 0.35, r * 0.35), C(40, 40, 46), M.Metal, { Shape = Cyl }); cap.Parent = hub
            return hub
        end
        Gear(CF(1.42, 1.85, -0.75), 0.6, 8, 1.2, BRASS)
        Gear(CF(1.44, 1.25, -0.05), 0.45, 7, -1.55, COPPER)
        -- the gauge + its needle, a handle wheel
        B(CF(1.34, 2.3, 1.4), V(0.1, 0.9, 0.9), C(230, 224, 200), M.SmoothPlastic, { Shape = Cyl })
        B(CF(1.38, 2.3, 1.4), V(0.04, 0.16, 0.16), C(40, 40, 46), M.Metal, { Shape = Cyl })
        B(CF(1.4, 2.45, 1.4), V(0.04, 0.32, 0.05), C(200, 40, 40), M.SmoothPlastic, { Anim = { "Sway", { Amp = 0.5 } } })
        local wheel = B(CF(1.45, 1.1, 1.4), V(0.14, 1, 1), BRASS, M.Metal, { Shape = Cyl, Anim = { "Spin", { Rate = 0.3, Axis = "X" } } })
        for k = 0, 3 do local s = B(CF(1.45, 1.1, 1.4) * ANG(k * math.pi / 4, 0, 0), V(0.08, 1.3, 0.1), BRASS, M.Metal); s.Parent = wheel end
        -- a steam pipe up the back corner, venting
        B(CF(-0.9, 3.9, 2.0), V(1.6, 0.3, 0.3), COPPER, M.Metal, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
        local vent = B(CF(-0.9, 4.75, 2.0), V(0.4, 0.15, 0.4), COPPER, M.Metal)
        Fx(vent, "Idle", { Tex = "Smoke", Color = C(240, 236, 230), Size = NSK({ { 0, 0.3 }, { 1, 1.4 } }), Rate = 1.2, Speed = NumberRange.new(1.5, 2.5),
            Life = NumberRange.new(1, 1.6), Light = 0, T = NSK({ { 0, 1 }, { 0.2, 0.6 }, { 1, 1 } }), Spread = Vector2.new(10, 10) })
        Light(B(CF(1.4, 1.6, -0.4), V(0.05, 0.6, 0.6), C(255, 190, 110), M.Neon, { Shape = Cyl, T = 0.5, Anim = { "Pulse", { Amp = 0.3, Rate = 0.9 } } }), C(255, 190, 120), 7, 0.5)
    end,
    -- GEODE CHEST: a rough stone chest split open along the lid, amethyst + azure crystals packed inside glowing through
    -- the gap, the lid hovering a hand's width above, sparkles rising
    Geode = function(B)
        local ROCK, ROCK2, AGATE, AME, AZU = C(78, 70, 78), C(58, 52, 60), C(220, 200, 235), C(176, 96, 255), C(90, 190, 255)
        B(CF(0, 1.1, 0), V(2.6, 2.2, 4.6), ROCK, M.Slate)
        for k, c in ipairs({ { 0.9, 0.5, -1.8, 0.9 }, { -0.8, 0.9, 1.9, 1.0 }, { 1.0, 1.6, 1.2, 0.7 }, { -1.0, 0.4, -0.6, 0.8 } }) do -- (lumps on the sides)
            B(CF(c[1] * 1.2, c[2], c[3]) * ANG(k, k * 2, 0), V(c[4], c[4], c[4]), ROCK2, M.Slate)
        end
        -- the agate rim round the opening (a pale band), the hollow, and a bed of crystal points standing up out of it
        B(CF(0, 2.22, 0), V(2.7, 0.14, 4.7), AGATE, M.Marble)
        B(CF(0, 2.24, 0), V(2.2, 0.14, 4.2), C(50, 24, 74), M.SmoothPlastic)
        for k = 0, 11 do
            local x, z = ((k % 3) - 1) * 0.65, -1.85 + k * 0.34
            local h = 0.8 + ((k * 7) % 5) * 0.2
            local col = (k % 4 == 1) and AZU or AME
            B(CF(x, 2.25 + h / 2, z) * ANG(R((k % 2 == 0) and 14 or -14), 0, R(((k % 3) - 1) * 18)), V(0.42, h, 0.42), col, M.Neon, { T = 0.1 })
        end
        -- the lid: lifted and tipped back on its rear edge, its underside crusted with crystal (it breathes up and down)
        local lid = B(CF(-0.4, 3.9, 0) * ANG(0, 0, R(28)), V(2.8, 0.7, 4.8), ROCK, M.Slate, { Anim = { "Bob", { Amp = 0.15, Rate = 0.8, NoTurn = true } } })
        local under = B(CF(-0.4, 3.9, 0) * ANG(0, 0, R(28)) * CF(0, -0.4, 0), V(2.4, 0.1, 4.4), AGATE, M.Marble); under.Parent = lid
        for k = 0, 5 do
            local cr = B(CF(-0.4, 3.9, 0) * ANG(0, 0, R(28)) * CF(((k % 2) - 0.5) * 0.9, -0.65, -1.8 + k * 0.72) * ANG(R(180), 0, 0), V(0.32, 0.55, 0.32), AME, M.Neon, { Wedge = true, T = 0.1 })
            cr.Parent = lid
        end
        -- cracks of crystal light down the front
        for k, ck in ipairs({ { 1.6, -1.2, 25 }, { 1.2, 0.3, -30 }, { 1.7, 1.5, 15 } }) do
            B(CF(1.31, ck[1], ck[2]) * ANG(R(ck[3]), 0, 0), V(0.05, 0.9, 0.1), (k == 2) and AZU or AME, M.Neon, { Anim = { "Pulse", { Amp = 0.4, Rate = 0.8 + k * 0.2 } } })
        end
        local glow = B(CF(0, 2.9, 0), V(2, 0.1, 4), AME, M.Neon, { T = 1 })
        Light(glow, C(180, 120, 255), 11, 0.9)
        Fx(glow, "Idle", { Color = C(220, 190, 255), Color2 = C(150, 210, 255), Size = NS(0.1), Rate = 6, Speed = NumberRange.new(0.6, 1.2),
            Life = NumberRange.new(1.2, 2), Shape = BOX, Light = 1 })
    end,
    -- ASTRAL ORRERY: a midnight-blue chest picked out in gold stars, a brass orrery on the lid (a sun, two planets and a
    -- ringed one circling at their own speeds), star dust drifting up
    Orrery = function(B)
        local NAVY, GOLD, STAR = C(26, 32, 70), C(216, 172, 80), C(200, 220, 255)
        B(CF(0, 1.2, 0), V(2.6, 2.4, 4.6), NAVY, M.SmoothPlastic, { Refl = 0.05 })
        B(CF(0, 2.5, 0), V(2.8, 0.2, 4.8), GOLD, M.Metal)
        B(CF(0, 0.1, 0), V(2.8, 0.2, 4.8), GOLD, M.Metal)
        for _, z in ipairs({ -2.3, 2.3 }) do for _, x in ipairs({ -1.3, 1.3 }) do B(CF(x, 1.3, z), V(0.18, 2.6, 0.18), GOLD, M.Metal) end end
        for k, st in ipairs({ { 1.9, -1.4 }, { 1.4, -0.4 }, { 2.0, 0.6 }, { 0.8, 1.2 }, { 1.6, 1.8 }, { 0.6, -1.7 } }) do -- (stars inlaid on the front)
            B(CF(1.32, st[1], st[2]), V(0.06, 0.14, 0.14), STAR, M.Neon, { Shape = Ball, Anim = { "Pulse", { Amp = 0.6, Rate = 0.7 + k * 0.15 } } })
        end
        B(CF(1.34, 1.3, 0), V(0.1, 0.8, 0.8), GOLD, M.Metal, { Shape = Cyl }) -- (the lock: a gold sunburst)
        B(CF(1.38, 1.3, 0), V(0.06, 0.4, 0.4), C(255, 210, 120), M.Neon, { Shape = Cyl })
        -- the orrery
        B(CF(0, 2.75, 0), V(1.2, 0.3, 1.2), GOLD, M.Metal, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
        B(CF(0, 3.4, 0), V(0.12, 1.2, 0.12), GOLD, M.Metal)
        local sun = B(CF(0, 4.2, 0), V(0.7, 0.7, 0.7), C(255, 200, 100), M.Neon, { Shape = Ball, Anim = { "Pulse", { Amp = 0.2, Rate = 1 } } })
        Light(sun, C(255, 210, 150), 9, 0.6)
        for k, pl in ipairs({ { 0.9, 0.34, C(120, 190, 255), 0.9 }, { 1.4, 0.44, C(230, 120, 90), -0.6 }, { 2.0, 0.56, C(200, 170, 255), 0.4 } }) do
            local hub = B(CF(0, 4.2, 0), V(0.1, 0.1, 0.1), GOLD, M.Metal, { T = 1, Anim = { "Spin", { Rate = pl[4] } } })
            local arm = B(CF(pl[1] / 2, 4.1, 0), V(pl[1], 0.05, 0.05), GOLD, M.Metal); arm.Parent = hub
            local p = B(CF(pl[1], 4.1, 0), V(pl[2], pl[2], pl[2]), pl[3], M.SmoothPlastic, { Shape = Ball }); p.Parent = hub
            if k == 3 then local rg = B(CF(pl[1], 4.1, 0) * ANG(R(25), 0, R(90)), V(0.04, 0.75, 0.75), C(230, 210, 170), M.SmoothPlastic, { Shape = Cyl, T = 0.35 }); rg.Parent = hub end
        end
        Hoop(B, CF(0, 4.2, 0) * ANG(R(90), 0, 0), 2.3, 14, 0.06, GOLD, M.Metal, 0.15, "Z")
        Fx(sun, "Idle", { Color = STAR, Color2 = C(255, 230, 170), Size = NS(0.06), Rate = 4, Speed = NumberRange.new(0.2, 0.5), Life = NumberRange.new(2, 3),
            Spread = Vector2.new(180, 180), Light = 1 })
    end,
    -- GHOSTLIGHT CASKET: a coffin of black wood bound in iron, pale-green candles burning at its head and foot, a little
    -- ghost circling it, grave mist pooling round its base
    Ghostlight = function(B)
        local WOOD, IRON, GHOST = C(40, 30, 32), C(70, 70, 76), C(170, 255, 210)
        -- the coffin: a wide shoulder tapering to the feet (two wedges each end), a raised lid
        B(CF(0, 1.1, 0.4), V(2.4, 2.2, 3.2), WOOD, M.Wood)
        B(CF(0, 1.1, -1.75), V(2.4, 2.2, 1.1), WOOD, M.Wood, { Wedge = true, Rot = ANG(0, math.pi, 0) * ANG(0, 0, 0) })
        B(CF(0, 2.35, 0.2), V(2.6, 0.3, 4.2), C(54, 40, 42), M.Wood)
        for _, turn in ipairs({ 0, math.pi }) do -- (a peaked lid: two wedges back to back along the coffin, a ridge cap)
            B(CF(0, 2.85, 0.2) * ANG(0, R(90) + turn, 0), V(4.1, 0.7, 1.25), C(48, 36, 38), M.Wood, { Wedge = true, Rot = CF(0, 0, -0.62) }) -- (a wedge is tall at its +Z back: the two backs meet at the ridge)
        end
        B(CF(0, 3.22, 0.2), V(0.2, 0.08, 4.1), C(150, 150, 160), M.Metal)
        for _, z in ipairs({ -1.0, 1.4 }) do B(CF(0, 1.2, z), V(2.5, 2.4, 0.2), IRON, M.Metal) end
        B(CF(1.24, 1.3, 0.4), V(0.08, 1.4, 0.18), C(150, 150, 160), M.Metal) -- (an iron cross on the side)
        B(CF(1.24, 1.55, 0.4), V(0.08, 0.18, 0.8), C(150, 150, 160), M.Metal)
        for _, z in ipairs({ -2.3, 2.3 }) do -- (candles on iron stands)
            B(CF(0.9, 0.8, z), V(0.15, 1.6, 0.15), IRON, M.Metal)
            local cdl = B(CF(0.9, 1.9, z), V(0.3, 0.6, 0.3), C(220, 230, 210), M.SmoothPlastic, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
            local fl = B(CF(0.9, 2.35, z), V(0.16, 0.3, 0.16), C(80, 255, 140), M.Neon, { T = 0.2, Anim = { "Pulse", { Amp = 0.35, Rate = 7 } } })
            Light(fl, C(150, 255, 200), 7, 0.5)
            local _ = cdl
        end
        -- the ghost: a pale sheet with two dark eyes and a wavy hem, circling on a hub above the lid
        local hub = B(CF(0, 3.6, 0), V(0.1, 0.1, 0.1), GHOST, M.Neon, { T = 1, Anim = { "Spin", { Rate = 0.7 } } })
        local body = B(CF(1.8, 3.8, 0), V(0.8, 1.0, 0.8), C(220, 255, 235), M.Neon, { Shape = Ball, T = 0.35 }); body.Parent = hub
        local hem = B(CF(1.8, 3.25, 0), V(0.75, 0.5, 0.75), C(200, 245, 225), M.Neon, { Wedge = true, T = 0.5 }); hem.Parent = hub
        for _, s2 in ipairs({ -1, 1 }) do local e = B(CF(1.8, 3.95, s2 * 0.15) * CF(-0.36, 0, 0), V(0.05, 0.16, 0.1), C(20, 30, 30), M.SmoothPlastic); e.Parent = hub end
        local mist = B(CF(0, 0.3, 0), V(3, 0.2, 5), GHOST, M.SmoothPlastic, { T = 1 })
        Fx(mist, "Idle", { Tex = "Smoke", Color = C(170, 230, 200), Color2 = C(80, 140, 120), Size = NSK({ { 0, 0.8 }, { 1, 2.4 } }), Rate = 6, Speed = NumberRange.new(0.2, 0.5),
            Life = NumberRange.new(2.5, 3.5), Light = 0.3, T = NSK({ { 0, 1 }, { 0.3, 0.55 }, { 1, 1 } }), Shape = BOX, Accel = V(0, -0.1, 0) })
    end,
}

-- ===== STASHES v2 (UPDATE 4, owner: hideout stashes + portals "absolutely stunning"): every style is a real textured
-- model (HideoutKit.Stash.<Id>: faces -Z, pivot = its BACK-bottom centre, attributes Size / Top / Front + its own points)
-- turned to face the room (+X) with its back on the west wall, plus its own life: lights, particles, and moving parts
-- (lids, dials, a tassel, a ghost). A style whose model is missing draws its old build (STASH_OLD): an unsaved place
-- never breaks a hideout. Builders get (B, K) from Anchored: B draws parts, K places kit models in the same frame.
local SROT = ANG(0, R(-90), 0) -- (model -Z -> the stash's +X front)
local SBACK = CF(-1.45, 0, 0) * SROT -- (the model's frame: its back 1.45 behind the anchor = against the wall)
local STILL = { Amp = 0, Rate = 0, NoTurn = true } -- (a carrier that stays put while its hinged parts move)
local function SSize(K, id: string): Vector3
    local m = K.Get("Stash", id)
    local v = m and m:GetAttribute("Size")
    return typeof(v) == "Vector3" and v or V(4.6, 3, 3)
end
-- a point in the model's own space (x across, y up, z = -depth at its front) -> the builder's frame
local function SP(v: Vector3): Vector3 return SBACK * v end
local function SAttr(K, id: string, attr: string, def: Vector3): Vector3
    local m = K.Get("Stash", id)
    local v = m and m:GetAttribute(attr)
    return SP(typeof(v) == "Vector3" and v or def)
end
local function Hold(B, at: Vector3): BasePart -- (an invisible holder for a light / emitter)
    return B(CF(at), V(0.2, 0.2, 0.2), DARK, M.SmoothPlastic, { T = 1 })
end
local STASH_BUILD = {}
for id, fn in pairs(STASH_OLD) do STASH_BUILD[id] = fn end
-- the theme defaults: a steel locker with a status light / a strapped explorer's trunk with its lantern lit
STASH_BUILD.Locker = function(B, K)
    if not (K and K.Place("Stash", "Locker", SBACK)) then return STASH_OLD.Locker(B) end
    local s = SSize(K, "Locker")
    local led = B(CF(SP(V(s.X * 0.42, s.Y * 0.93, -s.Z - 0.03))), V(0.08, 0.13, 0.13), C(90, 255, 140), M.Neon, { Shape = Ball, Anim = { "Pulse", { Amp = 0.6, Rate = 2 } } })
    Light(led, C(255, 190, 110), 8, 0.6)
end
STASH_BUILD.Trunk = function(B, K)
    if not (K and K.Place("Stash", "Trunk", SBACK)) then return STASH_OLD.Trunk(B) end
    local lamp = Hold(B, SAttr(K, "Trunk", "Lantern", V(-1.7, 0.7, -2.2)) + V(0, 0.15, 0))
    Light(lamp, C(255, 190, 110), 10, 0.8)
    Fx(lamp, "Idle", { Color = C(255, 210, 120), Size = NS(0.08), Rate = 2, Speed = NumberRange.new(0.4, 0.8), Life = NumberRange.new(2, 3) })
end
-- PIRATE'S HOARD: the lid thrown open on coins and jewels, a warm glow from inside, glints dancing on the gold
STASH_BUILD.Treasure = function(B, K)
    if not (K and K.Place("Stash", "Treasure", SBACK)) then return STASH_OLD.Treasure(B) end
    local s = SSize(K, "Treasure")
    local glow = B(CF(SAttr(K, "Treasure", "Glow", V(0, 2.2, -1.6))), V(1.2, 0.3, s.X * 0.5), C(255, 220, 110), M.SmoothPlastic, { T = 1 })
    Light(glow, C(255, 200, 90), 9, 0.9)
    Fx(glow, "Idle", { Color = C(255, 240, 160), Size = NSK({ { 0, 0 }, { 0.5, 0.22 }, { 1, 0 } }), Rate = 5, Speed = NumberRange.new(0, 0.3), Life = NumberRange.new(0.6, 1),
        Shape = BOX, Light = 1 })
    Fx(glow, "Idle", { Color = C(255, 210, 120), Size = NS(0.06), Rate = 2, Speed = NumberRange.new(0.4, 0.9), Life = NumberRange.new(1.5, 2.5), Shape = BOX, Light = 1 })
end
-- CYBER VAULT: the combination dial turning, a scanner beam sweeping the door, cyan light spilling out
STASH_BUILD.CyberVault = function(B, K)
    if not (K and K.Place("Stash", "CyberVault", SBACK)) then return STASH_OLD.CyberVault(B) end
    local s, NEON = SSize(K, "CyberVault"), C(80, 220, 255)
    K.Creature("Stash", "CyberVaultDial", CF(SAttr(K, "CyberVault", "CyberVaultDial", V(0, 2.2, -2.6))) * SROT, nil, "Spin", { Rate = 0.5, Axis = "Z" })
    local scan = B(CF(SP(V(0, s.Y * 0.5, -s.Z - 0.1))), V(0.05, 0.06, s.X * 0.8), NEON, M.Neon, { T = 0.3, Anim = { "Bob", { Amp = s.Y * 0.38, Rate = 0.9, NoTurn = true } } })
    Light(scan, NEON, 8, 0.7)
    Light(Hold(B, SP(V(0, s.Y * 0.5, -s.Z - 1))), NEON, 10, 0.5)
end
-- SAKURA LACQUER BOX: the silk tassel swaying, petals drifting down onto the lid
STASH_BUILD.SakuraBox = function(B, K)
    if not (K and K.Creature("Stash", "SakuraBox", SBACK, nil, "Bob", STILL, { tassel = { "Z", 0.14, 1.3, V(0, 0.5, 0) } })) then return STASH_OLD.SakuraBox(B) end
    local s = SSize(K, "SakuraBox")
    local src = B(CF(SP(V(0, s.Y + 2.6, -s.Z / 2))), V(s.Z + 0.6, 0.2, s.X + 0.4), C(255, 160, 196), M.SmoothPlastic, { T = 1 })
    Fx(src, "Idle", { Tex = "Petal", Color = C(255, 180, 210), Color2 = C(255, 220, 235), Size = NS(0.35), Rate = 2.5, Speed = NumberRange.new(0.3, 0.8),
        Life = NumberRange.new(3, 4), Accel = V(0, -0.6, 0), Dir = Enum.NormalId.Bottom, Shape = BOX, Light = 0.1, RotSpeed = NumberRange.new(-120, 120) })
    Light(Hold(B, SP(V(0, s.Y + 0.6, -s.Z - 0.6))), C(255, 170, 200), 7, 0.4)
end
-- VOID COFFER: an orb of the void bobbing over the crystals, violet smoke curling off it and pooling at the base
STASH_BUILD.VoidCoffer = function(B, K)
    if not (K and K.Place("Stash", "VoidCoffer", SBACK)) then return STASH_OLD.VoidCoffer(B) end
    local s, VIO = SSize(K, "VoidCoffer"), C(170, 90, 255)
    local orb = B(CF(SP(V(0, s.Y + 1.0, -s.Z / 2))), V(0.6, 0.6, 0.6), VIO, M.Neon, { Shape = Ball, Anim = { "Bob", { Amp = 0.25, Rate = 1.4 } } })
    Light(orb, VIO, 10, 0.8)
    Fx(orb, "Idle", { Tex = "Smoke", Color = C(120, 60, 200), Color2 = C(30, 10, 60), Size = NSK({ { 0, 0.3 }, { 1, 1.4 } }), Rate = 4, Speed = NumberRange.new(0.4, 1),
        Life = NumberRange.new(1.5, 2.5), Light = 0.3, T = NSK({ { 0, 1 }, { 0.3, 0.6 }, { 1, 1 } }) })
    local seep = B(CF(SP(V(0, 0.2, -s.Z / 2))), V(s.Z + 0.4, 0.2, s.X + 0.4), VIO, M.SmoothPlastic, { T = 1 })
    Fx(seep, "Idle", { Tex = "Smoke", Color = C(110, 50, 190), Color2 = C(40, 14, 70), Size = NSK({ { 0, 0.6 }, { 1, 1.8 } }), Rate = 3, Speed = NumberRange.new(0.1, 0.3),
        Life = NumberRange.new(2.5, 3.5), Light = 0.4, Shape = BOX, T = NSK({ { 0, 1 }, { 0.3, 0.7 }, { 1, 1 } }) })
end
-- DRAGON'S HOARD: the pearl in the dragon's claws glowing, gold dust in the air
STASH_BUILD.DragonHoard = function(B, K)
    if not (K and K.Place("Stash", "DragonHoard", SBACK)) then return STASH_OLD.DragonHoard(B) end
    local pearl = Hold(B, SAttr(K, "DragonHoard", "Pearl", V(0, 3.3, -2.8)))
    Light(pearl, C(180, 255, 220), 9, 0.8)
    Fx(pearl, "Idle", { Color = C(255, 220, 120), Size = NS(0.1), Rate = 5, Speed = NumberRange.new(0.3, 0.9), Life = NumberRange.new(1.5, 2.5), Spread = Vector2.new(180, 180) })
end
-- FROST RELIQUARY: cold light through the ice, mist pouring off the front, frost glittering round the spires
STASH_BUILD.FrostReliquary = function(B, K)
    if not (K and K.Place("Stash", "FrostReliquary", SBACK)) then return STASH_OLD.FrostReliquary(B) end
    local s, GLOW = SSize(K, "FrostReliquary"), C(140, 220, 255)
    Light(Hold(B, SP(V(0, s.Y * 0.4, -s.Z - 0.4))), GLOW, 9, 0.6)
    local mist = B(CF(SP(V(0, 0.3, -s.Z * 0.75))), V(1, 0.2, s.X), GLOW, M.SmoothPlastic, { T = 1 })
    Fx(mist, "Idle", { Tex = "Smoke", Color = C(200, 230, 255), Size = NSK({ { 0, 0.4 }, { 1, 1.6 } }), Rate = 4, Speed = NumberRange.new(0.3, 0.7),
        Life = NumberRange.new(2, 3), Accel = V(0, -0.2, 0), Dir = Enum.NormalId.Right, Light = 0, Shape = BOX, T = NSK({ { 0, 1 }, { 0.3, 0.75 }, { 1, 1 } }) })
    Fx(Hold(B, SP(V(0, s.Y - 0.6, -s.Z / 2))), "Idle", { Color = C(220, 245, 255), Size = NS(0.08), Rate = 4, Speed = NumberRange.new(0.2, 0.5), Life = NumberRange.new(1.5, 2.5),
        Spread = Vector2.new(180, 180), Light = 1 })
end
-- THE MIMIC: its jaw breathing open and shut, the tongue lolling, its eye glowing, foul breath
STASH_BUILD.Mimic = function(B, K)
    if not (K and K.Creature("Stash", "Mimic", SBACK, nil, "Bob", { Amp = 0.04, Rate = 1.6, NoTurn = true },
        { lid = { "X", 0.12, 1.7, V(0, -0.5, 0.5) }, tongue = { "Y", 0.3, 2.2, V(0, 0, 0.5) } })) then return STASH_OLD.Mimic(B) end
    Light(Hold(B, SAttr(K, "Mimic", "Eye", V(0, 4, -2))), C(255, 200, 80), 7, 0.7)
    Fx(Hold(B, SAttr(K, "Mimic", "Mouth", V(0, 1.8, -2.5))), "Idle", { Tex = "Smoke", Color = C(70, 40, 40), Size = NS(0.4), Rate = 0.8, Speed = NumberRange.new(0.2, 0.5),
        Life = NumberRange.new(1, 1.6), Dir = Enum.NormalId.Right, Light = 0 })
end
-- CLOCKWORK STRONGBOX: the porthole gears turning, steam venting from the pipe, a warm glow behind the glass
STASH_BUILD.Clockwork = function(B, K)
    if not (K and K.Place("Stash", "Clockwork", SBACK)) then return STASH_OLD.Clockwork(B) end
    local wheel = SAttr(K, "Clockwork", "ClockworkWheel", V(0, 1.5, -2.4))
    K.Creature("Stash", "ClockworkWheel", CF(wheel) * SROT, nil, "Spin", { Rate = 0.6, Axis = "Z" })
    Light(Hold(B, wheel + V(0.5, 0, 0)), C(255, 190, 120), 7, 0.5)
    Fx(Hold(B, SAttr(K, "Clockwork", "Vent", V(1, 4, -0.5)) + V(0, 0.1, 0)), "Idle", { Tex = "Smoke", Color = C(240, 236, 230), Size = NSK({ { 0, 0.3 }, { 1, 1.4 } }), Rate = 1.2,
        Speed = NumberRange.new(1.5, 2.5), Life = NumberRange.new(1, 1.6), Light = 0, T = NSK({ { 0, 1 }, { 0.2, 0.6 }, { 1, 1 } }), Spread = Vector2.new(10, 10) })
end
-- GEODE CHEST: its crystal-crusted lid hovering and breathing over the glowing amethyst, sparkles rising
STASH_BUILD.Geode = function(B, K)
    if not (K and K.Place("Stash", "Geode", SBACK)) then return STASH_OLD.Geode(B) end
    local s = SSize(K, "Geode")
    K.Creature("Stash", "GeodeLid", CF(SAttr(K, "Geode", "GeodeLid", V(0, 3, -1)) + V(0, 0.25, 0)) * SROT, nil, "Bob", { Amp = 0.15, Rate = 0.8, NoTurn = true })
    local glow = B(CF(SP(V(0, s.Y * 0.62, -s.Z / 2))), V(s.Z * 0.6, 0.1, s.X * 0.6), C(176, 96, 255), M.SmoothPlastic, { T = 1 })
    Light(glow, C(180, 120, 255), 11, 0.9)
    Fx(glow, "Idle", { Color = C(220, 190, 255), Color2 = C(150, 210, 255), Size = NS(0.1), Rate = 6, Speed = NumberRange.new(0.6, 1.2), Life = NumberRange.new(1.2, 2), Shape = BOX, Light = 1 })
end
-- ASTRAL ORRERY: a brass orrery on the lid, a sun and three planets circling at their own speeds, star dust
local function OrreryOn(B, p: Vector3)
    local GOLD, STAR = C(216, 172, 80), C(200, 220, 255)
    B(CF(p + V(0, 0.15, 0)), V(1.1, 0.3, 1.1), GOLD, M.Metal, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
    B(CF(p + V(0, 0.8, 0)), V(0.12, 1.2, 0.12), GOLD, M.Metal)
    local c = p + V(0, 1.6, 0)
    local sun = B(CF(c), V(0.7, 0.7, 0.7), C(255, 200, 100), M.Neon, { Shape = Ball, Anim = { "Pulse", { Amp = 0.2, Rate = 1 } } })
    Light(sun, C(255, 210, 150), 9, 0.6)
    for k, pl in ipairs({ { 0.9, 0.34, C(120, 190, 255), 0.9 }, { 1.4, 0.44, C(230, 120, 90), -0.6 }, { 2.0, 0.56, C(200, 170, 255), 0.4 } }) do
        local hub = B(CF(c), V(0.1, 0.1, 0.1), GOLD, M.Metal, { T = 1, Anim = { "Spin", { Rate = pl[4] } } })
        local arm = B(CF(c + V(pl[1] / 2, -0.1, 0)), V(pl[1], 0.05, 0.05), GOLD, M.Metal); arm.Parent = hub
        local planet = B(CF(c + V(pl[1], -0.1, 0)), V(pl[2], pl[2], pl[2]), pl[3], M.SmoothPlastic, { Shape = Ball }); planet.Parent = hub
        if k == 3 then local rg = B(CF(c + V(pl[1], -0.1, 0)) * ANG(R(25), 0, R(90)), V(0.04, 0.75, 0.75), C(230, 210, 170), M.SmoothPlastic, { Shape = Cyl, T = 0.35 }); rg.Parent = hub end
    end
    Hoop(B, CF(c) * ANG(R(90), 0, 0), 2.3, 26, 0.045, GOLD, M.Metal, 0.15, "Z")
    Fx(sun, "Idle", { Color = STAR, Color2 = C(255, 230, 170), Size = NS(0.06), Rate = 4, Speed = NumberRange.new(0.2, 0.5), Life = NumberRange.new(2, 3),
        Spread = Vector2.new(180, 180), Light = 1 })
end
STASH_BUILD.Orrery = function(B, K)
    if not (K and K.Place("Stash", "Orrery", SBACK)) then return STASH_OLD.Orrery(B) end
    OrreryOn(B, SAttr(K, "Orrery", "Top", V(0, 3.6, -1.6)))
end
-- GHOSTLIGHT CASKET: pale-green candles flickering at its corners, a little ghost circling it, grave mist
STASH_BUILD.Ghostlight = function(B, K)
    if not (K and K.Place("Stash", "Ghostlight", SBACK)) then return STASH_OLD.Ghostlight(B) end
    local s = SSize(K, "Ghostlight")
    for k = 1, 4 do
        local cp = SAttr(K, "Ghostlight", "Candle" .. k, V((k <= 2) and -2 or 2, 3.2, (k % 2 == 1) and -2 or -0.4))
        local fl = B(CF(cp + V(0, 0.16, 0)), V(0.12, 0.26, 0.12), C(80, 255, 140), M.Neon, { T = 0.2, Anim = { "Pulse", { Amp = 0.35, Rate = 6 + k } } })
        if k == 1 or k == 4 then Light(fl, C(150, 255, 200), 7, 0.5) end
    end
    local over = SP(V(0, s.Y + 1.2, -s.Z / 2))
    K.Creature("Stash", "Ghost", CF(over), nil, "Orbit", { Center = K.World(CF(over)).Position, RX = s.Z / 2 + 1.6, RZ = s.X / 2 + 1.2, Speed = 2.2, Bob = 0.35 },
        { ["left arm"] = { "Z", 0.5, 4 }, ["right arm"] = { "Z", -0.5, 4 } })
    local mist = B(CF(SP(V(0, 0.3, -s.Z / 2))), V(s.Z + 0.6, 0.2, s.X + 0.4), C(170, 255, 210), M.SmoothPlastic, { T = 1 })
    Fx(mist, "Idle", { Tex = "Smoke", Color = C(170, 230, 200), Color2 = C(80, 140, 120), Size = NSK({ { 0, 0.8 }, { 1, 2.4 } }), Rate = 6, Speed = NumberRange.new(0.2, 0.5),
        Life = NumberRange.new(2.5, 3.5), Light = 0.3, T = NSK({ { 0, 1 }, { 0.3, 0.55 }, { 1, 1 } }), Shape = BOX, Accel = V(0, -0.1, 0) })
end

-- each PORTAL skin's own MAP DEVICE (anchored at HideoutData.MAP.Device, facing +Z); returns the crystal / heart part
-- (the map room's one light sits on it)
local DEVICE_OLD = {
    -- RIFTGATE (default): a rune altar -- a slate plinth, glowing runes, three rune stones floating round a turning crystal
    Riftgate = function(B)
        local STONE, RUNE = C(58, 56, 66), C(160, 90, 255)
        B(CF(0, 0.5, 0), V(6, 1, 6), C(44, 42, 50), M.Slate)
        B(CF(0, 1.6, 0), V(4, 1.2, 4), STONE, M.Slate)
        for k = 0, 3 do B(CF(0, 1.6, 0) * ANG(0, R(k * 90), 0) * CF(0, 0, 2.02), V(2.6, 0.18, 0.06), RUNE, M.Neon, { Anim = { "Pulse", { Amp = 0.5, Rate = 0.8 + k * 0.1 } } }) end
        for k = 0, 2 do
            local a = k / 3 * math.pi * 2
            B(CF(math.cos(a) * 2.6, 3.4, math.sin(a) * 2.6) * ANG(0, a, R(12)), V(0.7, 1.2, 0.4), STONE, M.Slate, { Anim = { "Bob", { Amp = 0.4, Rate = 0.9 + k * 0.2 } } })
        end
        local c = B(CF(0, 3.6, 0), V(1.1, 1.8, 1.1), RUNE, M.Neon, { T = 0.1, Anim = { "Spin", { Rate = 0.8, Axis = "Y" } } })
        Fx(c, "Idle", { Color = RUNE, Size = NS(0.15), Rate = 5, Speed = NumberRange.new(0.5, 1.2), Life = NumberRange.new(1.5, 2), Spread = Vector2.new(180, 180) })
        return c
    end,
    -- TORII: a stone lantern (toro) -- base, post, lit fire box with paper windows, a curved cap
    Torii = function(B)
        local STONE, PAPER = C(130, 126, 120), C(255, 214, 150)
        B(CF(0, 0.4, 0), V(3.6, 0.8, 3.6), STONE, M.Slate)
        B(CF(0, 1.8, 0), V(1.2, 2.2, 1.2), STONE, M.Slate, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
        B(CF(0, 3.1, 0), V(2.6, 0.4, 2.6), STONE, M.Slate)
        local box = B(CF(0, 4.0, 0), V(1.9, 1.5, 1.9), PAPER, M.Neon, { T = 0.15, Anim = { "Pulse", { Amp = 0.25, Rate = 1.2 } } })
        for k = 0, 3 do B(CF(0, 4.0, 0) * ANG(0, R(k * 90), 0) * CF(0, 0, 0.97), V(1.5, 1.2, 0.06), C(60, 50, 40), M.Wood, { T = 0.6 }) end
        B(CF(0, 5.0, 0), V(3.2, 0.5, 3.2), STONE, M.Slate)
        B(CF(0, 5.5, 0), V(0.8, 0.8, 0.8), STONE, M.Slate, { Shape = Ball })
        Fx(box, "Idle", { Color = C(255, 200, 120), Size = NS(0.1), Rate = 3, Speed = NumberRange.new(0.6, 1), Life = NumberRange.new(1.5, 2.5) })
        return box
    end,
    -- VOID EYE: a black monolith floating over a cracked slab, an eye orb on its face, shards circling
    VoidEye = function(B)
        local OBS, VIO = C(20, 14, 30), C(170, 80, 255)
        B(CF(0, 0.3, 0), V(6, 0.6, 6), C(30, 24, 40), M.Slate, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
        for k = 0, 3 do B(CF(0, 0.62, 0) * ANG(0, R(k * 45), 0), V(5, 0.04, 0.12), VIO, M.Neon) end
        local mono = B(CF(0, 3.6, 0), V(1.6, 4.4, 0.8), OBS, M.Slate, { Anim = { "Bob", { Amp = 0.3, Rate = 0.6, NoTurn = true } } })
        local eye = B(CF(0, 4.2, 0.42), V(0.8, 0.8, 0.3), VIO, M.Neon, { Shape = Ball })
        eye.Parent = mono -- (rides the monolith)
        for k = 0, 4 do
            local a = k / 5 * math.pi * 2
            B(CF(math.cos(a) * 2, 3 + (k % 2) * 1.2, math.sin(a) * 2) * ANG(R(30), a, R(20)), V(0.3, 0.8, 0.3), OBS, M.Slate, { Anim = { "Bob", { Amp = 0.5, Rate = 0.7 + k * 0.15 } } })
        end
        Fx(mono, "Idle", { Tex = "Smoke", Color = C(110, 50, 180), Color2 = C(20, 6, 40), Size = NSK({ { 0, 0.4 }, { 1, 1.6 } }), Rate = 4, Speed = NumberRange.new(0.2, 0.6),
            Life = NumberRange.new(2, 3), Dir = Enum.NormalId.Bottom, Light = 0.3, T = NSK({ { 0, 1 }, { 0.3, 0.6 }, { 1, 1 } }) })
        return eye
    end,
    -- NEON HEXGATE: a holo table -- a steel table, a projector ring, a slowly turning holo cube over it
    NeonArch = function(B)
        local STEEL, CYAN, MAG = C(36, 40, 50), C(60, 230, 255), C(255, 60, 200)
        B(CF(0, 1.4, 0), V(4.4, 0.4, 4.4), STEEL, M.DiamondPlate)
        for _, x in ipairs({ -1.8, 1.8 }) do for _, z in ipairs({ -1.8, 1.8 }) do B(CF(x, 0.6, z), V(0.4, 1.2, 0.4), C(26, 28, 34), M.Metal) end end
        B(CF(0, 1.62, 0), V(0.06, 3.4, 3.4), CYAN, M.Neon, { Shape = Cyl, Rot = ANG(0, 0, R(90)), T = 0.3 })
        local ring = B(CF(0, 2.0, 0), V(0.08, 3, 3), MAG, M.Neon, { Shape = Cyl, Rot = ANG(0, 0, R(90)), T = 0.45, Anim = { "Spin", { Rate = 1.2, Axis = "X" } } })
        local cube = B(CF(0, 3.4, 0) * ANG(R(35), R(45), 0), V(1.3, 1.3, 1.3), CYAN, M.Neon, { T = 0.55, Anim = { "Spin", { Rate = 0.9, Axis = "Y" } } })
        Fx(cube, "Idle", { Color = CYAN, Color2 = MAG, Size = NS(0.1), Rate = 8, Speed = NumberRange.new(1, 2), Life = NumberRange.new(0.6, 1), Spread = Vector2.new(10, 10) })
        local _ = ring
        return cube
    end,
    -- INFERNO MAW: a hellfire brazier -- an iron bowl on three clawed legs, burning
    InfernoMaw = function(B)
        local IRON, LAVA = C(40, 34, 32), C(255, 110, 30)
        for k = 0, 2 do
            local a = k / 3 * math.pi * 2
            B(CF(math.cos(a) * 1.2, 1.2, math.sin(a) * 1.2) * ANG(0, -a, R(-20)), V(0.4, 2.6, 0.4), IRON, M.Metal)
        end
        B(CF(0, 2.6, 0), V(1, 3.4, 3.4), IRON, M.Metal, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
        local coals = B(CF(0, 3.05, 0), V(0.2, 3, 3), LAVA, M.Neon, { Shape = Cyl, Rot = ANG(0, 0, R(90)), Anim = { "Pulse", { Amp = 0.3, Rate = 1.6 } } })
        local flameAt = B(CF(0, 3.4, 0), V(2.4, 0.4, 2.4), LAVA, M.SmoothPlastic, { T = 1 })
        Flame(flameAt, 6, 9, C(255, 150, 40), C(255, 40, 10), "Idle")
        Fx(coals, "Idle", { Color = C(255, 160, 60), Size = NS(0.1), Rate = 5, Speed = NumberRange.new(3, 6), Life = NumberRange.new(1, 2), Spread = Vector2.new(25, 25), Dir = Enum.NormalId.Right })
        return coals
    end,
    -- CELESTIAL HALO: an angel's font -- a marble pedestal and basin, a gold halo turning over a light orb
    CelestialHalo = function(B)
        local MARBLE, GOLD = C(196, 190, 178), C(214, 168, 70)
        B(CF(0, 0.4, 0), V(3.6, 0.8, 3.6), MARBLE, M.Marble)
        B(CF(0, 1.7, 0), V(2.4, 1.0, 1.0), MARBLE, M.Marble, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
        B(CF(0, 2.6, 0), V(0.8, 3.4, 3.4), MARBLE, M.Marble, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
        B(CF(0, 2.98, 0), V(0.06, 3, 3), C(200, 240, 255), M.Neon, { Shape = Cyl, Rot = ANG(0, 0, R(90)), T = 0.4 })
        Hoop(B, CF(0, 4.4, 0) * ANG(R(90), 0, 0), 1.4, 14, 0.16, GOLD, M.Metal, 0.7, "Z")
        local orb = B(CF(0, 4.4, 0), V(0.9, 0.9, 0.9), C(255, 245, 210), M.Neon, { Shape = Ball, Anim = { "Bob", { Amp = 0.2, Rate = 1 } } })
        Fx(orb, "Idle", { Tex = "Feather", Color = C(255, 240, 200), Size = NS(0.3), Rate = 1.5, Speed = NumberRange.new(0.2, 0.5), Life = NumberRange.new(3, 4),
            Accel = V(0, -0.3, 0), Spread = Vector2.new(180, 180), Light = 0.2, RotSpeed = NumberRange.new(-40, 40) })
        return orb
    end,
    -- CLOCKWORK: a brass astrolabe -- a stand and three rings turning on different axes round a glowing sun
    Clockwork = function(B)
        local BRASS, DARKB = C(200, 150, 70), C(110, 80, 40)
        B(CF(0, 0.4, 0), V(3.2, 0.8, 3.2), DARKB, M.Metal)
        B(CF(0, 1.6, 0), V(2.4, 0.5, 0.5), BRASS, M.Metal, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
        Hoop(B, CF(0, 3.6, 0), 1.7, 16, 0.14, BRASS, M.Metal, 0.5, "Y")
        Hoop(B, CF(0, 3.6, 0) * ANG(0, R(90), 0), 1.4, 14, 0.14, BRASS, M.Metal, -0.7, "Y")
        Hoop(B, CF(0, 3.6, 0) * ANG(R(90), 0, 0), 1.1, 12, 0.12, DARKB, M.Metal, 0.9, "Z")
        local sun = B(CF(0, 3.6, 0), V(0.8, 0.8, 0.8), C(255, 200, 100), M.Neon, { Shape = Ball, Anim = { "Pulse", { Amp = 0.3, Rate = 1 } } })
        Fx(sun, "Idle", { Tex = "Smoke", Color = C(230, 220, 210), Size = NSK({ { 0, 0.3 }, { 1, 1.2 } }), Rate = 1.5, Speed = NumberRange.new(1, 2), Life = NumberRange.new(1.5, 2),
            Light = 0, T = NSK({ { 0, 1 }, { 0.2, 0.7 }, { 1, 1 } }) })
        return sun
    end,
    -- CORAL ARCH: a giant clam on a rock, open, a pearl glowing inside, bubbles streaming up
    CoralArch = function(B)
        local ROCK, SHELL = C(90, 80, 86), C(176, 112, 140)
        B(CF(0, 0.6, 0), V(5, 1.2, 4), ROCK, M.Rock)
        B(CF(0, 1.5, 0), V(4.4, 0.8, 3.4), SHELL, M.SmoothPlastic, { Shape = Ball })
        B(CF(0, 2.9, -1.0) * ANG(R(-55), 0, 0), V(4.4, 0.7, 3.4), SHELL, M.SmoothPlastic, { Shape = Ball, Anim = { "Bob", { Amp = 0.08, Rate = 0.5, NoTurn = true } } })
        local pearl = B(CF(0, 2.15, 0.2), V(1, 1, 1), C(240, 250, 255), M.Neon, { Shape = Ball, Anim = { "Pulse", { Amp = 0.3, Rate = 0.8 } } })
        for k = 0, 3 do
            local a = k * 1.6
            B(CF(math.cos(a) * 2.4, 1.6, math.sin(a) * 1.8) * ANG(0, 0, R(10)), V(0.3, 2.2, 0.3), C(200, 60, 70), M.SmoothPlastic, { Anim = { "Sway", { Amp = 0.15, Rate = 1 + k * 0.2 } } })
        end
        Fx(pearl, "Idle", { Tex = "Bubble", Color = C(200, 240, 255), Size = NSK({ { 0, 0.15 }, { 1, 0.35 } }), Rate = 4, Speed = NumberRange.new(1.5, 2.5), Life = NumberRange.new(1.5, 2.5),
            Spread = Vector2.new(10, 10), Light = 0.2 })
        return pearl
    end,
}

local PORTAL_OLD = {
    -- RIFTGATE (default, upgraded): carved slate pillars with pulsing runes, floating keystones, a violet vortex
    Riftgate = function(B)
        local STONE, RUNE = C(58, 56, 66), C(160, 90, 255)
        B(CF(0, 0.3, 0), V(17, 0.6, 4), C(44, 42, 50), M.Slate)
        for _, x in ipairs({ -7, 7 }) do
            B(CF(x, 6.8, 0), V(2.2, 13, 2.4), STONE, M.Slate)
            B(CF(x, 0.9, 0), V(3, 1.2, 3), C(44, 42, 50), M.Slate)
            for k = 0, 3 do B(CF(x, 2.5 + k * 3, 1.22), V(0.9, 0.18, 0.06), RUNE, M.Neon, { T = 0.2, Anim = { "Pulse", { Amp = 0.6, Rate = 0.7 + k * 0.15 } } }) end
        end
        B(CF(0, 14, 0), V(18, 2.2, 3), STONE, M.Slate)
        B(CF(0, 14, 1.52), V(5, 0.6, 0.06), RUNE, M.Neon, { T = 0.2, Anim = { "Pulse", { Amp = 0.5, Rate = 0.6 } } })
        for _, x in ipairs({ -3.5, 3.5 }) do B(CF(x, 16.2, 0) * ANG(0, 0, R(x * 4)), V(1.4, 1.8, 1.4), STONE, M.Slate, { Anim = { "Bob", { Amp = 0.35, Rate = 0.8, NoTurn = true } } }) end
        local mem = B(CF(0, 6.8, 0) * ANG(0, R(90), 0), V(0.3, 11.4, 11.4), RUNE, M.Neon, { Name = "MapPortal", T = 0.3, Shape = Cyl, Open = true })
        B(CF(0, 6.8, 0.25) * ANG(0, R(90), 0), V(0.2, 7, 7), C(150, 80, 230), M.Neon, { Shape = Cyl, T = 0.5, Open = true, Anim = { "Spin", { Rate = 1.2, Axis = "X" } } })
        B(CF(0, 6.8, 0.4) * ANG(0, R(90), 0), V(0.15, 3, 3), C(200, 120, 255), M.Neon, { Shape = Cyl, T = 0.45, Open = true, Anim = { "Spin", { Rate = -2, Axis = "X" } } })
        local base = B(CF(0, 0.7, 1.2), V(14, 0.2, 1), RUNE, M.Neon, { T = 1 })
        Fx(base, "Idle", { Color = RUNE, Size = NS(0.12), Rate = 6, Speed = NumberRange.new(0.6, 1.4), Life = NumberRange.new(2, 3), Shape = BOX })
        Fx(mem, "Open", { Tex = "Smoke", Color = C(170, 100, 255), Color2 = C(60, 20, 120), Size = NSK({ { 0, 2.5 }, { 1, 0.3 } }), Rate = 14, Speed = NumberRange.new(2, 3),
            Life = NumberRange.new(1, 1.4), Shape = DISC, InOut = Enum.ParticleEmitterShapeInOut.Inward, Light = 0.5, Dir = Enum.NormalId.Left })
        Fx(mem, "Burst", { Color = C(230, 200, 255), Size = NS(0.3), Speed = NumberRange.new(8, 14), Life = NumberRange.new(0.8, 1.2), Spread = Vector2.new(180, 180), N = 60 })
        Light(mem, RUNE, 26, 1.4, true)
        return mem
    end,
    Torii = function(B)
        local RED, BLACK, GOLD = C(150, 26, 26), C(24, 20, 22), C(200, 150, 50)
        for _, x in ipairs({ -6.2, 6.2 }) do
            B(CF(x, 6.6, 0), V(13.2, 1.3, 1.3), RED, M.SmoothPlastic, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
            B(CF(x, 0.4, 0), V(2, 0.8, 2), BLACK, M.Slate)
            B(CF(x, 1.4, 0), V(1.6, 1.6, 1.6), BLACK, M.SmoothPlastic, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
        end
        B(CF(0, 13.9, 0), V(18, 0.9, 1.8), BLACK, M.SmoothPlastic)
        for _, x in ipairs({ -8.6, 8.6 }) do B(CF(x, 14.2, 0) * ANG(0, 0, R(x > 0 and 12 or -12)), V(1.6, 0.7, 1.8), BLACK, M.SmoothPlastic) end -- (upturned ends)
        B(CF(0, 13.1, 0), V(16.6, 0.8, 1.4), RED, M.SmoothPlastic)
        B(CF(0, 10.4, 0), V(14, 0.7, 0.9), RED, M.SmoothPlastic)
        B(CF(0, 11.8, 0.1), V(2, 2, 0.4), GOLD, M.Metal)
        for _, x in ipairs({ -3, 3 }) do -- (shimenawa paper streamers)
            for k = 0, 2 do B(CF(x + k * 0.5 - 0.5, 9.4, 0.5), V(0.3, 1.4, 0.05), C(250, 248, 240), M.SmoothPlastic, { Anim = { "Sway", { Amp = 0.15, Rate = 1.3 + k * 0.2 } } }) end
        end
        local mem = B(CF(0, 5.2, 0), V(11.4, 10.2, 0.3), C(255, 180, 110), M.Neon, { Name = "MapPortal", T = 0.5, Open = true })
        B(CF(0, 5.2, 0.3), V(8, 7, 0.2), C(255, 140, 90), M.Neon, { T = 0.65, Open = true, Anim = { "Pulse", { Amp = 0.25, Rate = 1.1 } } })
        local top = B(CF(0, 12.5, 2), V(14, 0.2, 4), RED, M.SmoothPlastic, { T = 1 })
        Fx(top, "Open", { Tex = "Petal", Color = C(255, 170, 200), Color2 = C(255, 225, 235), Size = NS(0.4), Rate = 12, Speed = NumberRange.new(0.5, 1.2), Life = NumberRange.new(4, 5),
            Accel = V(0.3, -0.8, 0), Dir = Enum.NormalId.Bottom, Shape = BOX, Light = 0.1, RotSpeed = NumberRange.new(-150, 150) })
        Fx(top, "Idle", { Tex = "Petal", Color = C(255, 170, 200), Size = NS(0.35), Rate = 1.5, Speed = NumberRange.new(0.3, 0.8), Life = NumberRange.new(4, 5),
            Accel = V(0.3, -0.6, 0), Dir = Enum.NormalId.Bottom, Shape = BOX, Light = 0.1, RotSpeed = NumberRange.new(-150, 150) })
        Fx(mem, "Burst", { Color = C(255, 240, 200), Size = NS(0.25), Speed = NumberRange.new(4, 8), Life = NumberRange.new(1.2, 1.8), Spread = Vector2.new(60, 60), N = 70, Dir = Enum.NormalId.Back })
        Light(mem, C(255, 200, 150), 22, 0.9, true)
        return mem
    end,
    VoidEye = function(B)
        local OBS, VIO = C(26, 18, 36), C(170, 80, 255)
        B(CF(0, 0.3, 0), V(15, 0.6, 15), C(30, 24, 40), M.Slate, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
        for k = 0, 11 do
            local a = k / 12 * math.pi * 2
            B(CF(math.cos(a) * 6.6, 7.4 + math.sin(a) * 6.6, 0) * ANG(0, 0, a) * ANG(0, 0, R(90)), V(1.6, 3.2 - (k % 2) * 0.8, 1.2), OBS, M.Slate,
                { Wedge = true, Anim = { "Bob", { Amp = 0.25, Rate = 0.5 + (k % 4) * 0.12, NoTurn = true } } })
        end
        for k = 0, 11 do
            local a = (k + 0.5) / 12 * math.pi * 2
            B(CF(math.cos(a) * 7.6, 7.4 + math.sin(a) * 7.6, 0), V(0.25, 0.25, 0.25), VIO, M.Neon, { Shape = Ball, Anim = { "Pulse", { Amp = 0.8, Rate = 0.9 + (k % 3) * 0.3 } } })
        end
        local mem = B(CF(0, 7.4, 0) * ANG(0, R(90), 0), V(0.3, 11, 11), VIO, M.Neon, { Name = "MapPortal", T = 0.3, Shape = Cyl, Open = true })
        B(CF(0, 7.4, 0.35) * ANG(0, R(90), 0), V(0.2, 4.2, 4.2), C(255, 120, 220), M.Neon, { Shape = Cyl, T = 0.2, Open = true, Anim = { "Spin", { Rate = 0.8, Axis = "X" } } })
        B(CF(0, 7.4, 0.5), V(1.8, 1.8, 0.6), C(8, 4, 12), M.SmoothPlastic, { Shape = Ball, Open = true })
        Fx(mem, "Open", { Tex = "Smoke", Color = C(40, 10, 80), Color2 = C(170, 80, 255), Size = NSK({ { 0, 3 }, { 1, 0.2 } }), Rate = 16, Speed = NumberRange.new(2, 4),
            Life = NumberRange.new(0.9, 1.3), Shape = DISC, InOut = Enum.ParticleEmitterShapeInOut.Inward, Light = 0.2, Dir = Enum.NormalId.Left })
        Fx(mem, "Burst", { Color = C(200, 140, 255), Size = NS(0.3), Speed = NumberRange.new(10, 16), Life = NumberRange.new(0.6, 1), Spread = Vector2.new(180, 180), N = 80 })
        Light(mem, VIO, 26, 1.4, true)
        return mem
    end,
    NeonArch = function(B)
        local STEEL, CYAN, MAG = C(36, 40, 50), C(60, 230, 255), C(255, 60, 200)
        B(CF(0, 0.3, 0), V(16, 0.6, 4), C(28, 30, 38), M.DiamondPlate)
        for k = 0, 5 do
            local a = k / 6 * math.pi * 2 + math.pi / 6
            local cf = CF(math.cos(a) * 6.2, 7.2 + math.sin(a) * 6.2, 0) * ANG(0, 0, a + math.pi / 2)
            B(cf, V(6.8, 0.7, 0.8), STEEL, M.DiamondPlate)
            B(cf * CF(0, 0, 0.42), V(6.8, 0.16, 0.06), (k % 2 == 0) and CYAN or MAG, M.Neon, { Anim = { "Pulse", { Amp = 0.5, Rate = 1.5 + k * 0.2 } } })
        end
        for _, x in ipairs({ -7.5, 7.5 }) do -- (cable spools + junction boxes)
            B(CF(x, 1.4, 0), V(1.6, 2.2, 1.6), C(30, 32, 40), M.Metal)
            B(CF(x, 2.0, 0.82), V(0.8, 0.3, 0.06), CYAN, M.Neon, { Anim = { "Pulse", { Amp = 0.9, Rate = 3 } } })
        end
        local mem = B(CF(0, 7.2, 0) * ANG(0, R(90), 0), V(0.3, 11, 11), CYAN, M.Neon, { Name = "MapPortal", T = 0.35, Shape = Cyl, Open = true })
        for k = -2, 2 do B(CF(0, 7.2 + k * 1.6, 0.3), V(9 - math.abs(k) * 1.6, 0.08, 0.1), C(200, 250, 255), M.Neon, { T = 0.4, Open = true, Anim = { "Pulse", { Amp = 0.5, Rate = 3 } } }) end
        Fx(mem, "Open", { Color = CYAN, Color2 = MAG, Size = NS(0.14), Rate = 30, Speed = NumberRange.new(2, 5), Life = NumberRange.new(0.5, 0.9), Shape = DISC, Dir = Enum.NormalId.Left,
            Spread = Vector2.new(5, 5), Light = 1 })
        Fx(mem, "Burst", { Tex = "Bolt", Color = CYAN, Color2 = MAG, Size = NS(0.6), Speed = NumberRange.new(8, 12), Life = NumberRange.new(0.3, 0.6), Spread = Vector2.new(180, 180), N = 30 })
        Light(mem, CYAN, 26, 1.4, true)
        return mem
    end,
    -- INFERNO MAW: a horned demon mouth -- black stone jaws, iron teeth round the opening, horns, lava dripping
    InfernoMaw = function(B)
        local ROCK, IRON, LAVA = C(34, 22, 22), C(70, 60, 56), C(255, 100, 30)
        B(CF(0, 0.4, 0), V(17, 0.8, 5), ROCK, M.Basalt)
        local ring = RingXY(B, 14, 6.6, 7.2, 3.2, 2.4, 3, ROCK, M.Basalt)
        for k = 0, 13 do -- teeth pointing in
            local a = k / 14 * math.pi * 2
            B(CF(math.cos(a) * 5.1, 7.2 + math.sin(a) * 5.1, 0.6) * ANG(0, 0, a - math.pi / 2), V(0.8, 1.6, 0.6), IRON, M.Metal, { Wedge = true })
        end
        for _, s in ipairs({ -1, 1 }) do -- horns
            local base = CF(s * 6, 13.5, 0)
            for k = 0, 4 do B(base * CF(s * k * 0.6, k * 0.9, 0) * ANG(0, 0, R(-s * (20 + k * 12))), V(1.4 - k * 0.22, 1.2, 1.4 - k * 0.22), C(50, 40, 36), M.Slate) end
        end
        for _, x in ipairs({ -4, 0, 4 }) do B(CF(x, 12.6, 1.3), V(0.3, 1.6, 0.3), LAVA, M.Neon, { Anim = { "Pulse", { Amp = 0.5, Rate = 1.2 } } }) end -- (lava drips)
        local mem = B(CF(0, 7.2, 0) * ANG(0, R(90), 0), V(0.3, 10, 10), LAVA, M.Neon, { Name = "MapPortal", T = 0.3, Shape = Cyl, Open = true })
        B(CF(0, 7.2, 0.3) * ANG(0, R(90), 0), V(0.2, 6, 6), C(255, 220, 120), M.Neon, { Shape = Cyl, T = 0.35, Open = true, Anim = { "Pulse", { Amp = 0.4, Rate = 2 } } })
        local floor = B(CF(0, 1.0, 1.5), V(10, 0.2, 2), LAVA, M.Neon, { T = 1 })
        for _, x in ipairs({ -3.5, 0, 3.5 }) do
            local at = B(CF(x, 1.2, 1.5), V(2, 0.3, 1.5), LAVA, M.SmoothPlastic, { T = 1 })
            Flame(at, 7, 12, C(255, 150, 40), C(255, 40, 10), "Open")
        end
        Fx(floor, "Idle", { Color = C(255, 140, 50), Size = NS(0.12), Rate = 6, Speed = NumberRange.new(2, 4), Life = NumberRange.new(1.5, 2.5), Shape = BOX })
        Fx(mem, "Burst", { Tex = "Fire", Color = C(255, 180, 60), Color2 = C(255, 40, 10), Size = NS(2.5), Speed = NumberRange.new(10, 18), Life = NumberRange.new(0.5, 0.8),
            Spread = Vector2.new(50, 50), N = 40, Dir = Enum.NormalId.Left })
        Light(mem, C(255, 120, 40), 28, 1.6, true)
        local _ = ring
        return mem
    end,
    -- CELESTIAL HALO: two marble pillars inside three gold halos turning on different axes, wings carved at the top
    CelestialHalo = function(B)
        local MARBLE, GOLD = C(196, 190, 178), C(214, 168, 70)
        B(CF(0, 0.4, 0), V(16, 0.8, 5), MARBLE, M.Marble)
        for _, x in ipairs({ -6.4, 6.4 }) do
            B(CF(x, 6.5, 0), V(12, 1.6, 1.6), MARBLE, M.Marble, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
            B(CF(x, 12.8, 0), V(2.4, 0.8, 2.4), GOLD, M.Metal)
            for k = 0, 3 do -- a carved wing on each capital
                B(CF(x + (x > 0 and 1 or -1) * (1 + k * 0.6), 13.4 + k * 0.35, 0) * ANG(0, 0, R((x > 0 and -1 or 1) * (20 + k * 10))), V(2.2 - k * 0.3, 0.3, 0.6), C(214, 210, 200), M.Marble)
            end
        end
        Hoop(B, CF(0, 7.2, 0), 6.6, 24, 0.35, GOLD, M.Metal, 0.3, "Z")
        Hoop(B, CF(0, 7.2, 0) * ANG(R(70), 0, 0), 6.1, 22, 0.28, GOLD, M.Metal, 0.4, "Y")
        Hoop(B, CF(0, 7.2, 0) * ANG(0, R(60), 0), 5.7, 20, 0.28, GOLD, M.Metal, -0.5, "X")
        local mem = B(CF(0, 7.2, 0) * ANG(0, R(90), 0), V(0.3, 10, 10), C(255, 170, 60), M.Neon, { Name = "MapPortal", T = 0.55, Shape = Cyl, Open = true })
        Fx(mem, "Open", { Tex = "Feather", Color = C(255, 245, 220), Color2 = C(255, 220, 140), Size = NS(0.5), Rate = 8, Speed = NumberRange.new(1, 2), Life = NumberRange.new(3, 4),
            Shape = DISC, Dir = Enum.NormalId.Left, Accel = V(0, -0.5, 0), Light = 0.3, RotSpeed = NumberRange.new(-60, 60) })
        Fx(mem, "Open", { Tex = "Glow", Color = C(255, 230, 160), Size = NS(0.3), Rate = 12, Speed = NumberRange.new(0.5, 1), Life = NumberRange.new(2, 3), Shape = DISC, Light = 1 })
        Fx(mem, "Burst", { Color = C(255, 240, 180), Size = NS(0.35), Speed = NumberRange.new(6, 12), Life = NumberRange.new(1, 1.5), Spread = Vector2.new(180, 180), N = 90 })
        Light(mem, C(255, 230, 170), 24, 1.0, true)
        return mem
    end,
    -- CLOCKWORK GATE: a great brass gear (rim + teeth) turning round the opening, two smaller gears and a pendulum
    Clockwork = function(B)
        local BRASS, DARKB, STEEL = C(200, 150, 70), C(110, 80, 40), C(90, 88, 84)
        B(CF(0, 0.4, 0), V(16, 0.8, 4), DARKB, M.Metal)
        for _, x in ipairs({ -6.8, 6.8 }) do B(CF(x, 4, 0), V(1.4, 8, 1.4), STEEL, M.Metal) end
        local hub = B(CF(0, 7.4, -0.6), V(0.6, 1.4, 1.4), BRASS, M.Metal, { Shape = Cyl, Rot = ANG(0, R(90), 0), Anim = { "Spin", { Rate = 0.25, Axis = "X" } } })
        for k = 0, 19 do -- the big gear's rim + teeth ride on the hub
            local a = k / 20 * math.pi * 2
            local rim = B(CF(math.cos(a) * 6.4, 7.4 + math.sin(a) * 6.4, -0.6) * ANG(0, 0, a + math.pi / 2), V(2.2, 0.9, 0.8), BRASS, M.Metal)
            rim.Parent = hub
            if k % 2 == 0 then
                local tooth = B(CF(math.cos(a) * 7.2, 7.4 + math.sin(a) * 7.2, -0.6) * ANG(0, 0, a + math.pi / 2), V(0.8, 0.8, 0.8), BRASS, M.Metal)
                tooth.Parent = hub
            end
        end
        for _, g in ipairs({ { -8.5, 12.5, 2.4, 0.6 }, { 8.6, 2.6, 2.0, -0.7 } }) do
            local sg = B(CF(g[1], g[2], -0.4), V(0.5, g[3] * 2, g[3] * 2), DARKB, M.Metal, { Shape = Cyl, Rot = ANG(0, R(90), 0), Anim = { "Spin", { Rate = g[4], Axis = "X" } } })
            for k = 0, 7 do
                local a = k / 8 * math.pi * 2
                local t = B(CF(g[1] + math.cos(a) * g[3], g[2] + math.sin(a) * g[3], -0.4), V(0.5, 0.5, 0.5), BRASS, M.Metal)
                t.Parent = sg
            end
        end
        local pend = B(CF(0, 13.5, 0.8), V(0.3, 0.3, 0.3), DARKB, M.Metal, { Anim = { "Sway", { Amp = 0.35, Rate = 1.4 } } })
        local rod = B(CF(0, 11.5, 0.8), V(0.15, 4, 0.15), BRASS, M.Metal); rod.Parent = pend
        local bob = B(CF(0, 9.4, 0.8), V(1.2, 1.2, 0.3), BRASS, M.Metal, { Shape = Cyl, Rot = ANG(0, R(90), 0) }); bob.Parent = pend
        local mem = B(CF(0, 7.4, 0) * ANG(0, R(90), 0), V(0.3, 10.6, 10.6), C(255, 150, 60), M.Neon, { Name = "MapPortal", T = 0.55, Shape = Cyl, Open = true })
        Fx(mem, "Open", { Tex = "Smoke", Color = C(230, 220, 210), Size = NSK({ { 0, 1 }, { 1, 3 } }), Rate = 6, Speed = NumberRange.new(2, 4), Life = NumberRange.new(1.2, 1.8),
            Light = 0, T = NSK({ { 0, 1 }, { 0.2, 0.6 }, { 1, 1 } }), Dir = Enum.NormalId.Left, Spread = Vector2.new(40, 40) })
        Fx(mem, "Burst", { Color = C(255, 200, 100), Size = NS(0.2), Speed = NumberRange.new(8, 14), Life = NumberRange.new(0.4, 0.8), Spread = Vector2.new(180, 180), N = 50,
            Accel = V(0, -30, 0) })
        Light(mem, C(255, 200, 120), 24, 1.0, true)
        return mem
    end,
    -- CORAL ARCH: branching coral up both sides and over, shells, kelp swaying, a sea-water membrane
    CoralArch = function(B)
        local CORAL, CORAL2, KELP = C(200, 56, 84), C(214, 104, 40), C(40, 120, 76)
        B(CF(0, 0.5, 0), V(16, 1, 5), C(90, 80, 86), M.Rock)
        for k = 0, 16 do -- the arch: stacked coral lumps on a semicircle
            local a = k / 16 * math.pi
            local p = V(math.cos(a) * 6.4, 1 + math.sin(a) * 12, 0)
            B(CF(p) * ANG(0, R(k * 37), R(k * 23)), V(2.2, 1.8, 2), (k % 2 == 0) and CORAL or CORAL2, M.SmoothPlastic, { Shape = Ball })
            if k % 3 == 0 then
                B(CF(p + V(0, 0.4, 1.2)) * ANG(R(30), 0, R(20 - k * 4)), V(0.3, 1.8, 0.3), CORAL2, M.SmoothPlastic, { Anim = { "Sway", { Amp = 0.12, Rate = 1 + k * 0.05 } } })
            end
        end
        for _, x in ipairs({ -8, -7, 7, 8 }) do
            B(CF(x, 3.5, 0.6), V(0.4, 6, 0.2), KELP, M.SmoothPlastic, { Anim = { "Sway", { Amp = 0.2, Rate = 0.8 + x * 0.02 } } })
        end
        local mem = B(CF(0, 6.4, 0) * ANG(0, R(90), 0), V(0.3, 10.6, 10.6), C(30, 120, 190), M.Neon, { Name = "MapPortal", T = 0.45, Shape = Cyl, Open = true })
        B(CF(0, 6.4, 0.3) * ANG(0, R(90), 0), V(0.2, 6, 6), C(40, 150, 210), M.Neon, { Shape = Cyl, T = 0.55, Open = true, Anim = { "Spin", { Rate = 0.9, Axis = "X" } } })
        Fx(mem, "Open", { Tex = "Bubble", Color = C(210, 245, 255), Size = NSK({ { 0, 0.2 }, { 1, 0.5 } }), Rate = 16, Speed = NumberRange.new(1.5, 3), Life = NumberRange.new(1.5, 2.5),
            Shape = DISC, Light = 0.3, Accel = V(0, 3, 0) })
        Fx(mem, "Open", { Tex = "Smoke", Color = C(60, 160, 220), Size = NSK({ { 0, 2.5 }, { 1, 0.3 } }), Rate = 10, Speed = NumberRange.new(2, 3), Life = NumberRange.new(1, 1.4),
            Shape = DISC, InOut = Enum.ParticleEmitterShapeInOut.Inward, Light = 0.3, Dir = Enum.NormalId.Left })
        Fx(mem, "Burst", { Tex = "Bubble", Color = C(220, 250, 255), Size = NS(0.4), Speed = NumberRange.new(6, 10), Life = NumberRange.new(1, 1.6), Spread = Vector2.new(180, 180), N = 60 })
        Light(mem, C(100, 200, 240), 24, 1.0, true)
        return mem
    end,
}

-- ===== PORTALS + MAP DEVICES v2 (UPDATE 4, owner: hideout portals "absolutely stunning"): each skin's gate and device are
-- real textured models (HideoutKit.Portal.<Id> / HideoutKit.Device.<Id>, generated facing -Z, turned by PROT to face
-- the room). A gate model carries its measured OPENING (attributes OpenC / OpenW / OpenH, found by rays through it);
-- the membrane ("MapPortal", open only) is sized into that opening, so open / burst effects, light and sounds work as
-- before. Moving pieces: the clockwork gear turns, the void monolith floats, halos / hoops / holo cubes / crystals.
-- A skin whose model is missing draws its old build (PORTAL_OLD / DEVICE_OLD).
local PROT = ANG(0, R(180), 0)
local GATE_MAX_H = 14.6 -- (the map room's ceiling is at 16: a taller gate is drawn smaller)
local function GateScale(K, id: string): number
    local src = K.Get("Portal", id)
    local sz = src and src:GetAttribute("Size")
    return (typeof(sz) == "Vector3") and math.min(1, GATE_MAX_H / sz.Y) or 1
end
local function KitOpening(K, id: string): (Vector3, number, number)
    local src = K.Get("Portal", id)
    local c, w, h = src and src:GetAttribute("OpenC"), src and src:GetAttribute("OpenW"), src and src:GetAttribute("OpenH")
    local sc = GateScale(K, id)
    return (typeof(c) == "Vector3") and (PROT * c * sc) or V(0, 7, 0), (w or 8) * sc, (h or 10) * sc
end
local function PlaceGate(K, id: string): Model?
    if not K then return nil end
    return K.Place("Portal", id, PROT, GateScale(K, id))
end
local function DSize(K, id: string): Vector3
    local m = K.Get("Device", id)
    local v = m and m:GetAttribute("Size")
    return typeof(v) == "Vector3" and v or V(4, 3, 4)
end
local function DAttr(K, id: string, attr: string, def: Vector3): Vector3
    local m = K.Get("Device", id)
    local v = m and m:GetAttribute(attr)
    return PROT * (typeof(v) == "Vector3" and v or def)
end
-- the membrane: "Disc" (diameter d = w), "Oval" (w x h, a sphere-meshed slab) or "Door" (a w x h panel); returns the part
-- + the face its particles leave from (toward the room)
local function Membrane(B, shape: string, c: Vector3, w: number, h: number, col: Color3, t: number): (BasePart, Enum.NormalId)
    if shape == "Disc" then
        return B(CF(c) * ANG(0, R(90), 0), V(0.3, w, w), col, M.Neon, { Name = "MapPortal", T = t, Shape = Cyl, Open = true }), Enum.NormalId.Left
    end
    local p = B(CF(c), V(w, h, 0.3), col, M.Neon, { Name = "MapPortal", T = t, Open = true })
    if shape == "Oval" then local sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Sphere; sm.Parent = p end
    return p, Enum.NormalId.Back
end
-- a turning swirl disc inside the opening (open only)
local function Swirl(B, c: Vector3, d: number, col: Color3, t: number, rate: number)
    return B(CF(c) * ANG(0, R(90), 0), V(0.2, d, d), col, M.Neon, { Shape = Cyl, T = t, Open = true, Anim = { "Spin", { Rate = rate, Axis = "X" } } })
end

local PORTAL_BUILD = {}
local DEVICE_BUILD = {}
for id, fn in pairs(PORTAL_OLD) do PORTAL_BUILD[id] = fn end
for id, fn in pairs(DEVICE_OLD) do DEVICE_BUILD[id] = fn end

-- RIFTGATE: carved rune pillars under a stone lintel, a violet vortex filling the doorway
PORTAL_BUILD.Riftgate = function(B, K)
    if not PlaceGate(K, "Riftgate") then return PORTAL_OLD.Riftgate(B) end
    local RUNE = C(160, 90, 255)
    local c, w, h = KitOpening(K, "Riftgate")
    local mem, dir = Membrane(B, "Oval", c, w + 0.4, h + 0.2, RUNE, 0.3)
    Swirl(B, c + V(0, 0, 0.25), w * 0.85, C(150, 80, 230), 0.5, 1.2)
    Swirl(B, c + V(0, 0, 0.4), w * 0.4, C(200, 120, 255), 0.45, -2)
    local base = B(CF(0, 0.7, 2.2), V(w + 4, 0.2, 1), RUNE, M.Neon, { T = 1 })
    Fx(base, "Idle", { Color = RUNE, Size = NS(0.12), Rate = 6, Speed = NumberRange.new(0.6, 1.4), Life = NumberRange.new(2, 3), Shape = BOX })
    Fx(mem, "Open", { Tex = "Smoke", Color = C(170, 100, 255), Color2 = C(60, 20, 120), Size = NSK({ { 0, 2.5 }, { 1, 0.3 } }), Rate = 14, Speed = NumberRange.new(2, 3),
        Life = NumberRange.new(1, 1.4), Shape = DISC, InOut = Enum.ParticleEmitterShapeInOut.Inward, Light = 0.5, Dir = dir })
    Fx(mem, "Burst", { Color = C(230, 200, 255), Size = NS(0.3), Speed = NumberRange.new(8, 14), Life = NumberRange.new(0.8, 1.2), Spread = Vector2.new(180, 180), N = 60 })
    Light(mem, RUNE, 26, 1.4, true)
    return mem
end
DEVICE_BUILD.Riftgate = function(B, K)
    if not (K and K.Place("Device", "Riftgate", PROT)) then return DEVICE_OLD.Riftgate(B) end
    local STONE, RUNE = C(58, 56, 66), C(160, 90, 255)
    local top = DSize(K, "Riftgate").Y
    for k = 0, 2 do
        local a = k / 3 * math.pi * 2
        B(CF(math.cos(a) * 2.9, top + 0.6, math.sin(a) * 2.9) * ANG(0, a, R(12)), V(0.6, 1.0, 0.35), STONE, M.Slate, { Anim = { "Bob", { Amp = 0.35, Rate = 0.9 + k * 0.2 } } })
    end
    local cr = B(CF(0, top + 1.3, 0), V(0.9, 1.5, 0.9), RUNE, M.Neon, { T = 0.1, Anim = { "Spin", { Rate = 0.8, Axis = "Y" } } })
    Fx(cr, "Idle", { Color = RUNE, Size = NS(0.15), Rate = 5, Speed = NumberRange.new(0.5, 1.2), Life = NumberRange.new(1.5, 2), Spread = Vector2.new(180, 180) })
    return cr
end
-- SPIRIT TORII: the vermilion gate, warm spirit light filling it, sakura falling; a mossy stone lantern for its device
PORTAL_BUILD.Torii = function(B, K)
    if not PlaceGate(K, "Torii") then return PORTAL_OLD.Torii(B) end
    local c, w, h = KitOpening(K, "Torii")
    local mem, dir = Membrane(B, "Door", c, w + 0.2, h, C(255, 170, 100), 0.62)
    B(CF(c + V(0, 0, 0.3)), V(w * 0.7, h * 0.7, 0.2), C(255, 140, 90), M.Neon, { T = 0.65, Open = true, Anim = { "Pulse", { Amp = 0.25, Rate = 1.1 } } })
    local gs = K.Get("Portal", "Torii"):GetAttribute("Size")
    local top = B(CF(0, (typeof(gs) == "Vector3" and gs.Y or 16) * GateScale(K, "Torii") - 2.5, 2), V(14, 0.2, 4), C(150, 26, 26), M.SmoothPlastic, { T = 1 })
    Fx(top, "Open", { Tex = "Petal", Color = C(255, 170, 200), Color2 = C(255, 225, 235), Size = NS(0.4), Rate = 12, Speed = NumberRange.new(0.5, 1.2), Life = NumberRange.new(4, 5),
        Accel = V(0.3, -0.8, 0), Dir = Enum.NormalId.Bottom, Shape = BOX, Light = 0.1, RotSpeed = NumberRange.new(-150, 150) })
    Fx(top, "Idle", { Tex = "Petal", Color = C(255, 170, 200), Size = NS(0.35), Rate = 1.5, Speed = NumberRange.new(0.3, 0.8), Life = NumberRange.new(4, 5),
        Accel = V(0.3, -0.6, 0), Dir = Enum.NormalId.Bottom, Shape = BOX, Light = 0.1, RotSpeed = NumberRange.new(-150, 150) })
    Fx(mem, "Burst", { Color = C(255, 240, 200), Size = NS(0.25), Speed = NumberRange.new(4, 8), Life = NumberRange.new(1.2, 1.8), Spread = Vector2.new(60, 60), N = 70, Dir = dir })
    Light(mem, C(255, 200, 150), 22, 0.9, true)
    return mem
end
DEVICE_BUILD.Torii = function(B, K)
    if not (K and K.Place("Device", "Torii", PROT)) then return DEVICE_OLD.Torii(B) end
    local box = B(CF(DAttr(K, "Torii", "Glow", V(0, 3.6, 0))), V(0.6, 0.6, 0.6), C(255, 214, 150), M.SmoothPlastic, { T = 1 })
    Fx(box, "Idle", { Color = C(255, 200, 120), Size = NS(0.1), Rate = 3, Speed = NumberRange.new(0.6, 1), Life = NumberRange.new(1.5, 2.5) })
    return box
end
-- EYE OF THE VOID: a rune-carved obsidian ring, the void pouring inward round a black pupil; a floating eye monolith
PORTAL_BUILD.VoidEye = function(B, K)
    if not PlaceGate(K, "VoidEye") then return PORTAL_OLD.VoidEye(B) end
    local VIO = C(170, 80, 255)
    local c, w, h = KitOpening(K, "VoidEye")
    local d = math.max(w, h)
    local mem, dir = Membrane(B, "Disc", c, d, d, VIO, 0.3)
    Swirl(B, c + V(0, 0, 0.35), d * 0.5, C(255, 120, 220), 0.2, 0.8)
    B(CF(c + V(0, 0, 0.5)), V(1.8, 1.8, 0.6), C(8, 4, 12), M.SmoothPlastic, { Shape = Ball, Open = true })
    Fx(mem, "Open", { Tex = "Smoke", Color = C(40, 10, 80), Color2 = C(170, 80, 255), Size = NSK({ { 0, 3 }, { 1, 0.2 } }), Rate = 16, Speed = NumberRange.new(2, 4),
        Life = NumberRange.new(0.9, 1.3), Shape = DISC, InOut = Enum.ParticleEmitterShapeInOut.Inward, Light = 0.2, Dir = dir })
    Fx(mem, "Burst", { Color = C(200, 140, 255), Size = NS(0.3), Speed = NumberRange.new(10, 16), Life = NumberRange.new(0.6, 1), Spread = Vector2.new(180, 180), N = 80 })
    Light(mem, VIO, 26, 1.4, true)
    return mem
end
DEVICE_BUILD.VoidEye = function(B, K)
    if not (K and K.Place("Device", "VoidEye", PROT)) then return DEVICE_OLD.VoidEye(B) end
    local VIO = C(170, 80, 255)
    K.Creature("Device", "VoidEyeMono", CF(DAttr(K, "VoidEye", "VoidEyeMono", V(0, 3.6, 0))) * PROT, nil, "Bob", { Amp = 0.3, Rate = 0.6, NoTurn = true })
    local eye = B(CF(DAttr(K, "VoidEye", "Eye", V(0, 3.8, -0.6))), V(0.4, 0.4, 0.4), VIO, M.SmoothPlastic, { T = 1 })
    Fx(eye, "Idle", { Tex = "Smoke", Color = C(110, 50, 180), Color2 = C(20, 6, 40), Size = NSK({ { 0, 0.4 }, { 1, 1.6 } }), Rate = 4, Speed = NumberRange.new(0.2, 0.6),
        Life = NumberRange.new(2, 3), Dir = Enum.NormalId.Bottom, Light = 0.3, T = NSK({ { 0, 1 }, { 0.3, 0.6 }, { 1, 1 } }) })
    return eye
end
-- NEON HEXGATE: the neon-wired frame booting up, scan lines across the opening, a storm of data; a holo table
PORTAL_BUILD.NeonArch = function(B, K)
    if not PlaceGate(K, "NeonArch") then return PORTAL_OLD.NeonArch(B) end
    local CYAN, MAG = C(60, 230, 255), C(255, 60, 200)
    local c, w, h = KitOpening(K, "NeonArch")
    local mem, dir = Membrane(B, "Disc", c, w, w, CYAN, 0.35)
    for k = -2, 2 do B(CF(c + V(0, k * w * 0.15, 0.3)), V(w * 0.85 - math.abs(k) * w * 0.15, 0.08, 0.1), C(200, 250, 255), M.Neon, { T = 0.4, Open = true, Anim = { "Pulse", { Amp = 0.5, Rate = 3 } } }) end
    Fx(mem, "Open", { Color = CYAN, Color2 = MAG, Size = NS(0.14), Rate = 30, Speed = NumberRange.new(2, 5), Life = NumberRange.new(0.5, 0.9), Shape = DISC, Dir = dir,
        Spread = Vector2.new(5, 5), Light = 1 })
    Fx(mem, "Burst", { Tex = "Bolt", Color = CYAN, Color2 = MAG, Size = NS(0.6), Speed = NumberRange.new(8, 12), Life = NumberRange.new(0.3, 0.6), Spread = Vector2.new(180, 180), N = 30 })
    Light(mem, CYAN, 26, 1.4, true)
    return mem
end
DEVICE_BUILD.NeonArch = function(B, K)
    if not (K and K.Place("Device", "NeonArch", PROT)) then return DEVICE_OLD.NeonArch(B) end
    local CYAN, MAG = C(60, 230, 255), C(255, 60, 200)
    local top = DSize(K, "NeonArch").Y
    B(CF(0, top + 0.35, 0), V(0.08, 3, 3), MAG, M.Neon, { Shape = Cyl, Rot = ANG(0, 0, R(90)), T = 0.45, Anim = { "Spin", { Rate = 1.2, Axis = "X" } } })
    local cube = B(CF(0, top + 1.6, 0) * ANG(R(35), R(45), 0), V(1.2, 1.2, 1.2), CYAN, M.Neon, { T = 0.55, Anim = { "Spin", { Rate = 0.9, Axis = "Y" } } })
    Fx(cube, "Idle", { Color = CYAN, Color2 = MAG, Size = NS(0.1), Rate = 8, Speed = NumberRange.new(1, 2), Life = NumberRange.new(0.6, 1), Spread = Vector2.new(10, 10) })
    return cube
end
-- INFERNO MAW: the horned demon skull, a wall of fire in its jaws, hellfire bursting out; a clawed brazier, burning
PORTAL_BUILD.InfernoMaw = function(B, K)
    if not PlaceGate(K, "InfernoMaw") then return PORTAL_OLD.InfernoMaw(B) end
    local LAVA = C(255, 100, 30)
    local c = select(1, KitOpening(K, "InfernoMaw"))
    local ms = GateScale(K, "InfernoMaw")
    local mc = V(c.X, c.Y + 0.3 * ms, 1.6 * ms) -- (the mouth: in front of the throat, filling the jaws)
    local mem, dir = Membrane(B, "Oval", mc, 6.2 * ms, 8.2 * ms, LAVA, 0.3)
    B(CF(mc + V(0, 0, 0.3)), V(4.2, 5.6, 0.2), C(255, 220, 120), M.Neon, { T = 0.35, Open = true, Anim = { "Pulse", { Amp = 0.4, Rate = 2 } } })
    local gs = K.Get("Portal", "InfernoMaw"):GetAttribute("Size")
    local front = (typeof(gs) == "Vector3" and gs.Z / 2 or 4.7) * GateScale(K, "InfernoMaw") + 0.6
    local floor = B(CF(0, 1.0, front), V(10, 0.2, 2), LAVA, M.Neon, { T = 1 })
    for _, x in ipairs({ -3.5, 0, 3.5 }) do
        local at = B(CF(x, 1.2, front), V(2, 0.3, 1.5), LAVA, M.SmoothPlastic, { T = 1 })
        Flame(at, 7, 12, C(255, 150, 40), C(255, 40, 10), "Open")
    end
    Fx(floor, "Idle", { Color = C(255, 140, 50), Size = NS(0.12), Rate = 6, Speed = NumberRange.new(2, 4), Life = NumberRange.new(1.5, 2.5), Shape = BOX })
    Fx(mem, "Burst", { Tex = "Fire", Color = C(255, 180, 60), Color2 = C(255, 40, 10), Size = NS(2.5), Speed = NumberRange.new(10, 18), Life = NumberRange.new(0.5, 0.8),
        Spread = Vector2.new(50, 50), N = 40, Dir = dir })
    Light(mem, C(255, 120, 40), 28, 1.6, true)
    return mem
end
DEVICE_BUILD.InfernoMaw = function(B, K)
    if not (K and K.Place("Device", "InfernoMaw", PROT)) then return DEVICE_OLD.InfernoMaw(B) end
    local LAVA = C(255, 110, 30)
    local coals = B(CF(DAttr(K, "InfernoMaw", "Fire", V(0, 2.7, 0))), V(1.8, 0.3, 1.8), LAVA, M.SmoothPlastic, { T = 1 })
    Flame(coals, 5, 9, C(255, 150, 40), C(255, 40, 10), "Idle")
    Fx(coals, "Idle", { Color = C(255, 160, 60), Size = NS(0.1), Rate = 5, Speed = NumberRange.new(3, 6), Life = NumberRange.new(1, 2), Spread = Vector2.new(25, 25) })
    return coals
end
-- CELESTIAL HALO: winged marble pillars under a gold arch, two gold halos turning round the light, feathers drifting
PORTAL_BUILD.CelestialHalo = function(B, K)
    if not PlaceGate(K, "CelestialHalo") then return PORTAL_OLD.CelestialHalo(B) end
    local GOLD = C(214, 168, 70)
    local c, w, h = KitOpening(K, "CelestialHalo")
    local mem, dir = Membrane(B, "Oval", c, w + 0.3, h, C(255, 196, 120), 0.66)
    Hoop(B, CF(c) * ANG(R(70), 0, 0), h * 0.42, 24, 0.22, GOLD, M.Metal, 0.4, "Y")
    Hoop(B, CF(c) * ANG(0, R(60), 0), h * 0.4, 22, 0.2, GOLD, M.Metal, -0.5, "X")
    Fx(mem, "Open", { Tex = "Feather", Color = C(255, 245, 220), Color2 = C(255, 220, 140), Size = NS(0.5), Rate = 8, Speed = NumberRange.new(1, 2), Life = NumberRange.new(3, 4),
        Shape = DISC, Dir = dir, Accel = V(0, -0.5, 0), Light = 0.3, RotSpeed = NumberRange.new(-60, 60) })
    Fx(mem, "Open", { Tex = "Glow", Color = C(255, 230, 160), Size = NS(0.3), Rate = 12, Speed = NumberRange.new(0.5, 1), Life = NumberRange.new(2, 3), Shape = DISC, Light = 1 })
    Fx(mem, "Burst", { Color = C(255, 240, 180), Size = NS(0.35), Speed = NumberRange.new(6, 12), Life = NumberRange.new(1, 1.5), Spread = Vector2.new(180, 180), N = 90 })
    Light(mem, C(255, 230, 170), 24, 0.7, true)
    return mem
end
DEVICE_BUILD.CelestialHalo = function(B, K)
    if not (K and K.Place("Device", "CelestialHalo", PROT)) then return DEVICE_OLD.CelestialHalo(B) end
    local top = DSize(K, "CelestialHalo").Y
    Hoop(B, CF(0, top + 1.8, 0) * ANG(R(90), 0, 0), 1.3, 16, 0.14, C(214, 168, 70), M.Metal, 0.7, "Z")
    local orb = B(CF(0, top + 1.8, 0), V(0.8, 0.8, 0.8), C(255, 245, 210), M.Neon, { Shape = Ball, Anim = { "Bob", { Amp = 0.2, Rate = 1 } } })
    Fx(orb, "Idle", { Tex = "Feather", Color = C(255, 240, 200), Size = NS(0.3), Rate = 1.5, Speed = NumberRange.new(0.2, 0.5), Life = NumberRange.new(3, 4),
        Accel = V(0, -0.3, 0), Spread = Vector2.new(180, 180), Light = 0.2, RotSpeed = NumberRange.new(-40, 40) })
    return orb
end
-- CLOCKWORK GATE: a great brass gear turning round the opening, a pendulum swinging, steam on opening; a brass stand
-- carrying a spinning astrolabe
PORTAL_BUILD.Clockwork = function(B, K)
    if not (K and K.Has("Portal", "Clockwork")) then return PORTAL_OLD.Clockwork(B) end
    local BRASS, DARKB = C(200, 150, 70), C(110, 80, 40)
    local gs = K.Get("Portal", "Clockwork"):GetAttribute("Size")
    local sc = GateScale(K, "Clockwork")
    local r = (typeof(gs) == "Vector3" and gs.Y or 16) * sc / 2
    local c = V(0, r + 0.9, 0)
    B(CF(0, 0.4, 0), V(r * 2, 0.8, 3), DARKB, M.Metal)
    K.Creature("Portal", "Clockwork", CF(c) * PROT, sc, "Spin", { Rate = 0.25, Axis = "Z" })
    local _, w, h = KitOpening(K, "Clockwork")
    local d = math.max(w, h) * 0.95
    local mem, dir = Membrane(B, "Disc", c, d, d, C(255, 150, 60), 0.55)
    local pend = B(CF(0, c.Y + r + 0.4, 1.0), V(0.3, 0.3, 0.3), DARKB, M.Metal, { Anim = { "Sway", { Amp = 0.35, Rate = 1.4 } } })
    local rod = B(CF(0, c.Y + r - 1.6, 1.0), V(0.15, 4, 0.15), BRASS, M.Metal); rod.Parent = pend
    local bob = B(CF(0, c.Y + r - 3.7, 1.0), V(1.2, 1.2, 0.3), BRASS, M.Metal, { Shape = Cyl, Rot = ANG(0, R(90), 0) }); bob.Parent = pend
    Fx(mem, "Open", { Tex = "Smoke", Color = C(230, 220, 210), Size = NSK({ { 0, 1 }, { 1, 3 } }), Rate = 6, Speed = NumberRange.new(2, 4), Life = NumberRange.new(1.2, 1.8),
        Light = 0, T = NSK({ { 0, 1 }, { 0.2, 0.6 }, { 1, 1 } }), Dir = dir, Spread = Vector2.new(40, 40) })
    Fx(mem, "Burst", { Color = C(255, 200, 100), Size = NS(0.2), Speed = NumberRange.new(8, 14), Life = NumberRange.new(0.4, 0.8), Spread = Vector2.new(180, 180), N = 50,
        Accel = V(0, -30, 0) })
    Light(mem, C(255, 200, 120), 24, 0.7, true)
    return mem
end
DEVICE_BUILD.Clockwork = function(B, K)
    if not (K and K.Place("Device", "Clockwork", PROT)) then return DEVICE_OLD.Clockwork(B) end
    local BRASS, DARKB = C(200, 150, 70), C(110, 80, 40)
    local y = DSize(K, "Clockwork").Y + 1.2
    Hoop(B, CF(0, y, 0), 1.5, 16, 0.12, BRASS, M.Metal, 0.5, "Y")
    Hoop(B, CF(0, y, 0) * ANG(0, R(90), 0), 1.25, 14, 0.12, BRASS, M.Metal, -0.7, "Y")
    Hoop(B, CF(0, y, 0) * ANG(R(90), 0, 0), 1.0, 12, 0.1, DARKB, M.Metal, 0.9, "Z")
    local sun = B(CF(0, y, 0), V(0.7, 0.7, 0.7), C(255, 200, 100), M.Neon, { Shape = Ball, Anim = { "Pulse", { Amp = 0.3, Rate = 1 } } })
    Fx(sun, "Idle", { Tex = "Smoke", Color = C(230, 220, 210), Size = NSK({ { 0, 0.3 }, { 1, 1.2 } }), Rate = 1.5, Speed = NumberRange.new(1, 2), Life = NumberRange.new(1.5, 2),
        Light = 0, T = NSK({ { 0, 1 }, { 0.2, 0.7 }, { 1, 1 } }) })
    return sun
end
-- CORAL ARCH: an arch of living coral and kelp, sea water swirling open, bubbles streaming; a giant clam with its pearl
PORTAL_BUILD.CoralArch = function(B, K)
    if not PlaceGate(K, "CoralArch") then return PORTAL_OLD.CoralArch(B) end
    local c, w, h = KitOpening(K, "CoralArch")
    local mem, dir = Membrane(B, "Oval", c, w + 0.4, h + 0.2, C(30, 120, 190), 0.45)
    Swirl(B, c + V(0, 0, 0.3), w * 0.9, C(40, 150, 210), 0.55, 0.9)
    Fx(mem, "Open", { Tex = "Bubble", Color = C(210, 245, 255), Size = NSK({ { 0, 0.2 }, { 1, 0.5 } }), Rate = 16, Speed = NumberRange.new(1.5, 3), Life = NumberRange.new(1.5, 2.5),
        Shape = DISC, Light = 0.3, Accel = V(0, 3, 0), Dir = dir })
    Fx(mem, "Open", { Tex = "Smoke", Color = C(60, 160, 220), Size = NSK({ { 0, 2.5 }, { 1, 0.3 } }), Rate = 10, Speed = NumberRange.new(2, 3), Life = NumberRange.new(1, 1.4),
        Shape = DISC, InOut = Enum.ParticleEmitterShapeInOut.Inward, Light = 0.3, Dir = dir })
    Fx(mem, "Burst", { Tex = "Bubble", Color = C(220, 250, 255), Size = NS(0.4), Speed = NumberRange.new(6, 10), Life = NumberRange.new(1, 1.6), Spread = Vector2.new(180, 180), N = 60 })
    Light(mem, C(100, 200, 240), 24, 1.0, true)
    return mem
end
DEVICE_BUILD.CoralArch = function(B, K)
    if not (K and K.Place("Device", "CoralArch", PROT)) then return DEVICE_OLD.CoralArch(B) end
    local pearl = B(CF(DAttr(K, "CoralArch", "Pearl", V(0, 1.8, 0.3)) + V(0, 1.6, 0)), V(0.5, 0.5, 0.5), C(240, 250, 255), M.SmoothPlastic, { T = 1 })
    Fx(pearl, "Idle", { Tex = "Bubble", Color = C(200, 240, 255), Size = NSK({ { 0, 0.15 }, { 1, 0.35 } }), Rate = 4, Speed = NumberRange.new(1.5, 2.5), Life = NumberRange.new(1.5, 2.5),
        Spread = Vector2.new(10, 10), Light = 0.2 })
    return pearl
end

-- ===== THE SHELL (client-side, per viewer). Room x -30..54, z -14..34 (local), balcony z 34..42, door east (x 54.5, z 0..8),
-- PRACTICE alcove x -34..-14, z -38..-14 (the dummy is the server's), MAP ROOM x 10..46, z -40..-14 (doorway x 22..34; drawn
-- only when owned: opts.MapRoom), stash by the west wall (z 14). opts = { MapRoom, StashSkin, PortalSkin }.
-- Moving decoration is tagged for HideoutClient's animator: attribute Anim = Sway / Line / Orbit / Bob / Spin / Rise / Fall /
-- Firefly / Pulse (+ its numbers); a part's child parts ride along, a child with Hinge (+ HingeAxis / HingeAmp / HingeRate)
-- flaps on that joint. Roof = hidden in build mode (the camera looks down in).
function HideoutData.BuildShell(parent: Instance, theme: string?, opts: any?): Folder
    opts = opts or {}
    local f = Instance.new("Folder")
    f.Name = "HideoutShell"
    theme = (theme and THEME_LOOK[theme]) and theme or "Apartment"
    f:SetAttribute("Theme", theme)
    local mapRoom = opts.MapRoom == true
    f:SetAttribute("MapRoom", mapRoom)
    local TL = THEME_LOOK[theme]
    local O = HideoutData.Origin
    local BX, BZ, BALZ = HideoutData.BX, HideoutData.BZ, HideoutData.BALZ
    local XM, ZM = (-30 + BX) / 2, (-14 + BZ) / 2 -- (12, 10: the room's middle)
    local MR = HideoutData.MAP
    local MXC, MZC = (MR.X0 + MR.X1) / 2, (MR.Z0 - 14) / 2
    local function S(lp: Vector3, size: Vector3, color: Color3, mat: Enum.Material?, o: any?): BasePart
        o = o or {}
        local p = P(o.Parent or f, CF(O + lp) * (o.Rot or CF()), size, color, mat, o)
        if o.Roof then p:SetAttribute("Roof", true) end
        return p
    end
    local function SC(cfl: CFrame, size: Vector3, color: Color3, mat: Enum.Material?, o: any?): BasePart -- (a local CFrame)
        o = o or {}
        local p = P(o.Parent or f, CF(O) * cfl, size, color, mat, o)
        if o.Roof then p:SetAttribute("Roof", true) end
        return p
    end
    local function Anim(p: BasePart, kind: string, attrs: any?): BasePart
        p:SetAttribute("Anim", kind)
        for k, v in pairs(attrs or {}) do p:SetAttribute(k, v) end
        return p
    end
    local function Hinge(p: BasePart, at: Vector3, axis: string, amp: number, rate: number)
        p:SetAttribute("Hinge", at); p:SetAttribute("HingeAxis", axis); p:SetAttribute("HingeAmp", amp); p:SetAttribute("HingeRate", rate)
    end
    local function Barrier(lp: Vector3, size: Vector3)
        local b = S(lp, size, DARK, M.SmoothPlastic, { Collide = true, T = 1 })
        b.Name = "HideoutBarrier"
        return b
    end
    -- a builder in an anchor's frame (stash / portal skins); o.Anim = { kind, attrs }, o.Open = portal-open only
    local function Anchored(anchor: CFrame)
        local B = function(cfl: CFrame, size: Vector3, color: Color3, mat: Enum.Material?, o: any?): BasePart
            o = o or {}
            local p = P(f, CF(O) * anchor * cfl * (o.Rot or CF()), size, color, mat, o)
            if o.Anim then Anim(p, o.Anim[1], o.Anim[2]) end
            if o.Open then p:SetAttribute("PortalOpenOnly", true); p:SetAttribute("OpenT", p.Transparency) end
            return p
        end
        -- (UPDATE 4) K = the kit placer in the same frame: K.Place(set, name, cfl, scale) -> a HideoutKit model or nil (then
        -- the builder draws its old primitive piece); K.Creature(set, name, cfl, scale, anim, attrs, flap) -> an animated
        -- carrier whose mesh parts ride along (named parts in flap hinge: lids, jaws, wings)
        local K = {
            Place = function(set: string, name: string, cfl: CFrame, scale: number?): Model?
                if not Kit then return nil end
                return Kit.Place(f, set, name, CF(O) * anchor * cfl, scale)
            end,
            Creature = function(set: string, name: string, cfl: CFrame, scale: number?, anim: string, attrs: any?, flap: any?): BasePart?
                if not Kit then return nil end
                local c = Kit.Creature(f, set, name, CF(O) * anchor * cfl, scale, { Flap = flap })
                if c then Anim(c, anim, attrs) end
                return c
            end,
            Has = function(set: string, name: string): boolean return Kit ~= nil and Kit.Get(set, name) ~= nil end,
            Get = function(set: string, name: string): Model? return Kit and Kit.Get(set, name) or nil end,
            World = function(cfl: CFrame): CFrame return CF(O) * anchor * cfl end,
        }
        return B, K
    end
    -- a panel running x0..x1 between two points of a cross-section (za, ya) -> (zb, yb) (arched glass, roof slopes);
    -- its local Y is the section's inward normal, so `inset` > 0 moves it into the room
    local function SegX(x0: number, x1: number, za: number, ya: number, zb: number, yb: number, thick: number, color: Color3, mat: Enum.Material, o: any?, inset: number?): BasePart
        local Zv = V(0, yb - ya, zb - za)
        local len = Zv.Magnitude
        Zv = Zv.Unit
        local Xv = V(1, 0, 0)
        local Yv = Zv:Cross(Xv)
        local pos = V((x0 + x1) / 2, (ya + yb) / 2, (za + zb) / 2) + Yv * (inset or 0)
        return SC(CFrame.fromMatrix(pos, Xv, Yv, Zv), V(x1 - x0, thick, len + 0.08), color, mat, o)
    end
    -- the same along z (tubes that run north)
    local function SegZ(z0: number, z1: number, xa: number, ya: number, xb: number, yb: number, thick: number, color: Color3, mat: Enum.Material, o: any?, inset: number?): BasePart
        local Xv = V(xb - xa, yb - ya, 0)
        local len = Xv.Magnitude
        Xv = Xv.Unit
        local Zv = V(0, 0, 1)
        local Yv = Zv:Cross(Xv)
        local pos = V((xa + xb) / 2, (ya + yb) / 2, (z0 + z1) / 2) + Yv * (inset or 0)
        return SC(CFrame.fromMatrix(pos, Xv, Yv, Zv), V(len + 0.08, thick, z1 - z0), color, mat, o)
    end
    -- pieces of a wall along x at depth z for x0..x1, skipping the gaps ({ { a, b }, ... } sorted)
    local function Runs(x0: number, x1: number, gaps: { any }): { any }
        local out, at = {}, x0
        for _, g in ipairs(gaps) do
            if g[1] > at then table.insert(out, { at, math.min(g[1], x1) }) end
            at = math.max(at, g[2])
        end
        if at < x1 then table.insert(out, { at, x1 }) end
        return out
    end

    -- ===== shared by every theme: floors, the door + stash prompts, the balcony's invisible walls, the practice lines =====
    local floorPart = S(V(XM, -0.5, ZM), V(BX + 30, 1, BZ + 14), TL.Floor, TL.FloorMat, { Collide = true })
    S(V(-24, -0.5, -26), V(20, 1, 24), TL.Bay, TL.BayMat, { Collide = true }) -- (the alcove floor)
    S(V(XM, -0.5, (BZ + BALZ) / 2), V(BX + 30, 1, BALZ - BZ), TL.Slab, TL.SlabMat, { Collide = true }) -- (the balcony)
    S(V(BX + 0.6, 5.5, 4), V(0.4, 11, 7.6), DARK, M.SmoothPlastic, { Name = "HideoutDoor", Collide = true, T = 1 })
        :SetAttribute("CamSolid", true) -- (the third-person camera stops here: it used to slip out the doorway into the dark)
    S(V(-28.4, 1.6, 14), V(3, 3.2, 5), DARK, M.SmoothPlastic, { Name = "HideoutStash", Collide = true, T = 1 })
    Barrier(V(XM, 15, BALZ + 0.6), V(BX + 32, 30, 1))
    Barrier(V(-30.5, 15, (BZ + BALZ) / 2), V(1, 30, BALZ - BZ + 1))
    Barrier(V(BX + 0.5, 15, (BZ + BALZ) / 2), V(1, 30, BALZ - BZ + 1))
    Barrier(V(XM, 30.5, (BZ + BALZ) / 2), V(BX + 32, 1, BALZ - BZ + 1))
    for z = -34, -18, 4 do S(V(-24, 0.02, z), V(18, 0.04, 0.2), TL.Lines, TL.LinesMat, { T = 0.7 }) end -- range lines (dim: bright ones glared in first person)
    -- the stash's look (a skin, or the theme's own)
    do
        local sid = opts.StashSkin
        local fn = (sid and sid ~= "Standard" and STASH_BUILD[sid]) or ((theme == "Forest") and STASH_BUILD.Trunk or STASH_BUILD.Locker)
        fn(Anchored(CF(-28.4, 0, 14)))
    end
    -- the MAP ROOM (owned): its floor, the MAP DEVICE (prompt part "MapDevice") and the portal (a skin; prompt on "MapPortal")
    if mapRoom then
        S(V(MXC, -0.5, MZC), V(MR.X1 - MR.X0, 1, -14 - MR.Z0), TL.MapFloor, TL.MapFloorMat, { Collide = true })
        local d = MR.Device
        local acc = TL.Accent
        S(d + V(0, 2, 0), V(6, 4, 6), DARK, M.SmoothPlastic, { Name = "MapDevice", Collide = true, T = 1 })
        -- (0.59) the device is part of the portal skin: each skin builds its own (an altar, a lantern, a monolith, a holo table...)
        local pid = opts.PortalSkin
        if not (pid and PORTAL_BUILD[pid]) then pid = "Riftgate" end
        local heart = DEVICE_BUILD[pid](Anchored(CF(d)))
        local ml = Instance.new("PointLight"); ml.Color = heart.Color; ml.Range = 26; ml.Brightness = 0.7; ml.Shadows = false; ml.Parent = heart -- (the map room's one light)
        local sign = S(d + V(0, 0.9, 3.75), V(3.4, 0.8, 0.1), C(14, 16, 22), M.SmoothPlastic)
        Label(sign, Enum.NormalId.Back, "MAP DEVICE", acc)
        local mem = PORTAL_BUILD[pid](Anchored(CF(MR.Portal)))
        local snd = PORTAL_SND[pid]
        if mem and snd then
            Snd(mem, snd[1], "Open", 0.9)
            Snd(mem, snd[2], "Hum", 0.45)
        end
    end
    -- the locked MAP ROOM doorway (not owned yet): a sign on whatever closes it (each theme builds the closing door)
    local function LockedSign(z: number, faceCol: Color3)
        local sign = S(V(28, 8.2, z), V(9, 1.4, 0.2), C(14, 16, 22), M.SmoothPlastic)
        Label(sign, Enum.NormalId.Back, "MAP ROOM  地図室", faceCol)
        S(V(31.6, 4.6, z + 0.1), V(0.6, 0.6, 0.1), C(255, 70, 60), M.Neon)
    end

    if theme == "Aquarium" then
        -- ===== DEEP AQUARIUM: a glass observation tunnel on the sea floor. The room is one long arched glass hall on steel
        -- ribs (the balcony is its observation deck, inside the glass), docked into a steel station bulkhead at the door
        -- end; the practice bay and the map room are smaller glass tubes off the north side. Outside: dunes, reefs, kelp,
        -- bubble vents, fish shoals past and over the roof, a manta, a turtle, glowing jellyfish, light shafts. A glowing
        -- water box far out hides everything else (the city is parked on this client in here: AimRngClient).
        local GLASS, GT = C(160, 220, 245), 0.72
        local STEEL2, RIB, HAZ = C(70, 82, 98), C(44, 52, 64), C(240, 190, 40)
        local ZC, HW, Y0, RISE, N = (-14 + BALZ) / 2, (BALZ + 14) / 2, 7, 13, 10 -- the hall's section: z -14..42, glass to y 7, arch to y 20
        local function AP(th: number): (number, number) return ZC + HW * math.cos(th), Y0 + RISE * math.sin(th) end
        local function HH(z: number): number local u = (z - ZC) / HW; return Y0 + RISE * math.sqrt(math.max(0, 1 - u * u)) end
        S(V(XM, Y0 / 2, BALZ + 0.15), V(BX + 31, Y0, 0.3), GLASS, M.Glass, { T = GT, Collide = true })
        for _, run in ipairs(Runs(-14, BX, { { MR.DoorX0, MR.DoorX1 } })) do
            S(V((run[1] + run[2]) / 2, Y0 / 2, -14.15), V(run[2] - run[1], Y0, 0.3), GLASS, M.Glass, { T = GT, Collide = true })
        end
        for i = 0, N - 1 do
            local za, ya = AP(math.pi * i / N)
            local zb, yb = AP(math.pi * (i + 1) / N)
            SegX(-30.6, BX + 0.6, za, ya, zb, yb, 0.3, GLASS, M.Glass, { T = GT, Collide = true, Roof = true })
        end
        for _, x in ipairs({ -30, -9, 12, 33, BX }) do
            S(V(x, Y0 / 2, BALZ - 0.45), V(0.9, Y0, 0.9), RIB, M.DiamondPlate)
            if x > -14 and not (x > MR.DoorX0 - 1 and x < MR.DoorX1 + 1) then S(V(x, Y0 / 2, -13.55), V(0.9, Y0, 0.9), RIB, M.DiamondPlate) end
            for i = 0, N - 1 do
                local za, ya = AP(math.pi * i / N)
                local zb, yb = AP(math.pi * (i + 1) / N)
                SegX(x - 0.45, x + 0.45, za, ya, zb, yb, 0.9, RIB, M.Metal, { Roof = true, Refl = 0.08 }, 0.45)
                -- (UPDATE 4) a cyan light line inset along every rib: the tunnel reads as a lit modern aquarium
                SegX(x - 0.1, x + 0.1, za, ya, zb, yb, 0.06, C(120, 230, 255), M.Neon, { Roof = true, T = 0.25 }, 0.93)
            end
        end
        S(V(XM, Y0 + RISE - 0.7, ZC), V(BX + 30, 0.6, 1.4), RIB, M.DiamondPlate, { Roof = true })
        S(V(XM, Y0 + RISE - 1.05, ZC), V(BX + 28, 0.12, 0.4), C(120, 230, 255), M.Neon, { T = 0.5, Roof = true })
        for _, x in ipairs({ -6, 18, 42 }) do
            S(V(x, Y0 + RISE - 1.7, ZC), V(0.15, 1.4, 0.15), DARK, M.Metal, { Roof = true })
            local pod = S(V(x, Y0 + RISE - 2.6, ZC), V(2, 0.7, 2), C(140, 220, 250), M.Neon, { T = 0.4, Shape = Ball, Roof = true })
            local l = Instance.new("PointLight"); l.Color = C(140, 220, 255); l.Range = 36; l.Brightness = 0.8; l.Shadows = false; l.Parent = pod
        end
        S(V(XM, 0.03, BALZ - 0.6), V(BX + 30, 0.06, 0.3), C(90, 220, 255), M.Neon, { T = 0.35 })
        S(V(-29.6, 0.03, ZC), V(0.3, 0.06, BALZ + 14), C(90, 220, 255), M.Neon, { T = 0.35 })
        -- the west end: glass all the way up (strips under the arch)
        local wE = { -14, -9, -4, 1, 6, 11, 14, 17, 22, 27, 32, 37, BALZ }
        for k = 1, #wE - 1 do
            local za, zb = wE[k], wE[k + 1]
            local top = math.max(HH(za), HH(zb), (za <= ZC and zb >= ZC) and (Y0 + RISE) or 0) + 0.2
            S(V(-30.65, top / 2, (za + zb) / 2), V(0.3, top, zb - za), GLASS, M.Glass, { T = GT, Collide = true })
        end
        -- the east end: the station's steel bulkhead with the AIRLOCK door
        local TOP = Y0 + RISE + 1
        S(V(BX + 0.75, TOP / 2, -7.5), V(0.6, TOP, 15), STEEL2, M.DiamondPlate, { Collide = true })
        S(V(BX + 0.75, TOP / 2, (8 + BALZ + 1) / 2), V(0.6, TOP, BALZ + 1 - 8), STEEL2, M.DiamondPlate, { Collide = true })
        S(V(BX + 0.75, (11 + TOP) / 2, 4), V(0.6, TOP - 11, 8), STEEL2, M.DiamondPlate, { Collide = true })
        for _, z in ipairs({ -0.3, 8.3 }) do S(V(BX + 0.2, 5.6, z), V(0.5, 11.2, 0.6), HAZ, M.Metal) end
        S(V(BX + 0.2, 11.35, 4), V(0.5, 0.6, 9.2), HAZ, M.Metal)
        S(V(BX + 0.42, 5.5, 4), V(0.3, 10.8, 7.6), C(84, 92, 104), M.DiamondPlate)
        S(V(BX + 0.25, 5.5, 4), V(0.08, 10.8, 0.12), C(30, 34, 40), M.Metal) -- (the two leaves' seam)
        S(V(BX + 0.24, 7.6, 4), V(0.2, 2.4, 2.4), GLASS, M.Glass, { Shape = Cyl, T = 0.4 })
        S(V(BX + 0.2, 4.4, 4), V(0.16, 2.6, 2.6), C(200, 60, 50), M.Metal, { Shape = Cyl })
        S(V(BX + 0.12, 4.4, 4), V(0.12, 2.2, 2.2), C(84, 92, 104), M.Metal, { Shape = Cyl })
        for k = 0, 1 do S(V(BX + 0.08, 4.4, 4), V(0.1, 2.6, 0.2), C(200, 60, 50), M.Metal, { Rot = ANG(R(45 + 90 * k), 0, 0) }) end
        S(V(BX + 0.1, 12.3, 7), V(0.5, 0.5, 0.5), C(255, 70, 60), M.Neon, { Shape = Ball })
        local exit = S(V(BX + 0.1, 12.4, 3.4), V(0.2, 1.2, 4), C(14, 22, 30), M.SmoothPlastic)
        Label(exit, Enum.NormalId.Left, "出口  EXIT", C(255, 90, 80))
        -- the observation deck (the balcony)
        local dh = HH(BZ) - 0.6
        S(V(XM, dh, BZ), V(BX + 30, 0.7, 0.7), RIB, M.DiamondPlate, { Roof = true })
        for _, x in ipairs({ -29.4, BX - 0.6 }) do S(V(x, dh / 2, BZ), V(0.7, dh, 0.7), RIB, M.DiamondPlate) end
        S(V(XM, 0.03, BZ), V(BX + 30, 0.06, 0.3), HAZ, M.Neon, { T = 0.45 })
        local deck = S(V(XM, dh - 1.2, BZ), V(13, 1.5, 0.2), C(14, 22, 30), M.SmoothPlastic, { Roof = true })
        Label(deck, Enum.NormalId.Front, "OBSERVATION DECK  展望", C(120, 230, 255))
        -- the hatch to the practice bay (x -30..-14, 7 high)
        local function Hatch(x0: number, x1: number, label: string?, col: Color3?)
            S(V(x0 - 0.2, 3.5, -14.2), V(0.6, 7, 0.8), HAZ, M.Metal)
            S(V(x1 + 0.2, 3.5, -14.2), V(0.6, 7, 0.8), HAZ, M.Metal)
            S(V((x0 + x1) / 2, 7.2, -14.2), V(x1 - x0 + 0.8, 0.6, 0.8), HAZ, M.Metal)
            for k = 0, math.floor((x1 - x0) / 2.4) - 1 do S(V(x0 + 1 + k * 2.4, 7.2, -13.77), V(0.5, 0.62, 0.06), DARK, M.SmoothPlastic, { Rot = ANG(0, 0, R(35)) }) end
            if label then
                local sign = S(V((x0 + x1) / 2, 8.4, -13.2), V(9, 1.3, 0.2), C(14, 22, 30), M.SmoothPlastic)
                Label(sign, Enum.NormalId.Back, label, col or C(255, 200, 40))
            end
        end
        Hatch(-30, -14, "PRACTICE  練習")
        -- a glass tube running north from the hall (the practice bay; the map room): x0..x1, z0..-14, walls to y0, arch rise
        local function Tube(x0: number, x1: number, z0: number, y0: number, rise: number, n: number, ribs: { number })
            local xc, hw = (x0 + x1) / 2, (x1 - x0) / 2
            local function BP(th: number): (number, number) return xc + hw * math.cos(th), y0 + rise * math.sin(th) end
            local function HB(x: number): number local u = (x - xc) / hw; return y0 + rise * math.sqrt(math.max(0, 1 - u * u)) end
            S(V(x0 - 0.15, y0 / 2, (z0 - 14) / 2), V(0.3, y0, -14 - z0 + 0.4), GLASS, M.Glass, { T = GT, Collide = true })
            S(V(x1 + 0.15, y0 / 2, (z0 - 14) / 2), V(0.3, y0, -14 - z0 + 0.4), GLASS, M.Glass, { T = GT, Collide = true })
            for i = 0, n - 1 do
                local xa, ya = BP(math.pi * i / n)
                local xb, yb = BP(math.pi * (i + 1) / n)
                SegZ(z0 - 0.7, -14.3, xa, ya, xb, yb, 0.3, GLASS, M.Glass, { T = GT, Collide = true, Roof = true })
                for _, z in ipairs(ribs) do SegZ(z - 0.45, z + 0.45, xa, ya, xb, yb, 0.9, RIB, M.DiamondPlate, { Roof = true }, 0.45) end
            end
            for _, z in ipairs(ribs) do
                S(V(x0 + 0.45, y0 / 2, z), V(0.9, y0, 0.9), RIB, M.DiamondPlate)
                S(V(x1 - 0.45, y0 / 2, z), V(0.9, y0, 0.9), RIB, M.DiamondPlate)
            end
            S(V(xc, y0 + rise - 0.5, (z0 - 14) / 2), V(0.4, 0.12, -14 - z0 - 2), C(120, 230, 255), M.Neon, { T = 0.2, Roof = true })
            local steps = math.max(4, math.floor((x1 - x0) / 4.5))
            for k = 0, steps - 1 do
                local xa, xb = x0 + (x1 - x0) * k / steps, x0 + (x1 - x0) * (k + 1) / steps
                local top = math.max(HB(xa), HB(xb), (xa <= xc and xb >= xc) and (y0 + rise) or 0) + 0.2
                S(V((xa + xb) / 2, top / 2, z0 - 0.85), V(xb - xa, top, 0.3), GLASS, M.Glass, { T = GT, Collide = true })
            end
            -- the bulkhead it shares with the hall, above the hatch: steel strips up to the tube's own arch (a flat
            -- rectangle here read as a billboard from the hall)
            for k = 0, steps - 1 do
                local xa, xb = x0 + (x1 - x0) * k / steps, x0 + (x1 - x0) * (k + 1) / steps
                local top = math.max(HB(xa), HB(xb), (xa <= xc and xb >= xc) and (y0 + rise) or 0) + 0.4
                if top > 7 then S(V((xa + xb) / 2, (7 + top) / 2, -14.6), V(xb - xa, top - 7, 0.6), STEEL2, M.DiamondPlate, { Collide = true }) end
            end
        end
        Tube(-34.5, -13.5, -38, 6, 8, 6, { -37.6, -26 })
        S(V(-32.5, 3.5, -14.6), V(4, 7, 0.6), STEEL2, M.DiamondPlate, { Collide = true })
        if mapRoom then
            Tube(MR.X0, MR.X1, MR.Z0, 6, 10, 8, { MR.Z0 + 0.4, -27 })
            Hatch(MR.DoorX0, MR.DoorX1, "MAP ROOM  地図室", C(120, 230, 255))
        else
            Hatch(MR.DoorX0, MR.DoorX1)
            S(V(28, 3.5, -14.35), V(MR.DoorX1 - MR.DoorX0, 7, 0.5), STEEL2, M.DiamondPlate, { Collide = true })
            for k = 0, 3 do S(V(23.5 + k * 3, 3.5, -14.05), V(0.4, 6.4, 0.08), HAZ, M.Metal, { Rot = ANG(0, 0, R(30)) }) end
            LockedSign(-13.95, C(120, 230, 255))
        end
        -- ===== outside: THE DEEP =====
        local deepV2 = Kit ~= nil and Kit.Get("Aquarium", "Clownfish") ~= nil
        if deepV2 then
            -- ===== THE DEEP v2 (UPDATE 4, owner: the aquarium "simply looks like little low effort shapes floating around"):
            -- real textured sea life (HideoutKit models), caustic light rippling over the sand AND the tunnel floor, god
            -- rays from the surface, marine snow, bubble vents, a kelp forest, coral reefs hugging the glass, a wreck in the
            -- haze; a school circles over the arch, a manta, a turtle and a shark pass round the tunnel. Low quality: no
            -- particles / rays, half the school.
            local low = Kit.Low()
            local function KP(name: string, lp: Vector3, scale: number?, yaw: number?, tilt: number?)
                return Kit.Place(f, "Aquarium", name, CF(O + lp) * ANG(0, R(yaw or 0), 0) * ANG(R(tilt or 0), 0, 0), scale)
            end
            local function KC(name: string, lp: Vector3, scale: number?, anim: string, attrs: any?, flap: any?)
                local c = Kit.Creature(f, "Aquarium", name, CF(O + lp), scale, { Flap = flap })
                if c then Anim(c, anim, attrs) end
                return c
            end
            local TAIL = { ["tail fin"] = { "Y", 0.45, 9 }, tail = { "Y", 0.35, 3 } }
            -- the sea floor: rippled sand + two layers of caustic light; the same light ripples over the tunnel floor
            local sand = S(V(XM, -3.5, ZM), V(340, 2, 340), C(150, 140, 112), M.SmoothPlastic)
            local stx = Instance.new("Texture"); stx.Texture = Kit.TEX.Sand; stx.Face = Enum.NormalId.Top; stx.StudsPerTileU = 26; stx.StudsPerTileV = 26; stx.Color3 = C(150, 136, 104); stx.Parent = sand -- (the texture covers the part colour: tint it, or it reads white)
            Kit.Caustics(sand, Enum.NormalId.Top, 30, 0.58, 1.4)
            Kit.Caustics(floorPart, Enum.NormalId.Top, 22, 0.74, 1.1)
            for i = 0, 11 do -- (dunes rolling off into the haze)
                local a = i / 12 * math.pi * 2 + 0.3
                local r = 96 + (i % 3) * 22
                S(V(XM + math.cos(a) * r, -4.5, ZM + math.sin(a) * r), V(70, 14, 50), (i % 2 == 0) and C(128, 120, 96) or C(140, 130, 104), M.Sand, { Shape = Ball, Rot = ANG(0, a, 0) })
            end
            -- the water all round (the client's deep-water haze does the fade) and the surface far above, light dancing on it
            local DEEP = C(12, 62, 104)
            for _, w in ipairs({ { V(XM, 40, ZM - 165), V(340, 96, 2) }, { V(XM, 40, ZM + 165), V(340, 96, 2) }, { V(XM - 165, 40, ZM), V(2, 96, 340) }, { V(XM + 165, 40, ZM), V(2, 96, 340) } }) do
                S(w[1], w[2], DEEP, M.Neon)
            end
            local surf = S(V(XM, 86, ZM), V(340, 1, 340), C(40, 116, 164), M.Neon)
            Kit.Caustics(surf, Enum.NormalId.Bottom, 72, 0.45, 2.4)
            -- god rays slanting down through the water, all outside the glass
            if not low then
                for i, rp in ipairs({ V(-48, 0, 60), V(-20, 0, 70), V(30, 0, 66), V(70, 0, 58), V(-58, 0, -10), V(-44, 0, -52), V(0, 0, -44), V(60, 0, -46), V(84, 0, 14) }) do
                    Kit.GodRay(f, O + rp + V(-12, 85, -7), O + rp + V(3, -2.5, 2), 6 + (i % 3) * 3, 15 + (i % 2) * 7, C(176, 232, 255), 0.8)
                end
                local snow = S(V(XM, 30, ZM), V(240, 60, 240), DEEP, M.SmoothPlastic, { T = 1 })
                Kit.Snow(snow, { Rate = 40 })
            end
            -- REEFS hugging the glass: a rock, corals round it, an anemone with its clownfish pair
            local REEFS = {
                { V(-6, -2.5, 52), 0 }, { V(22, -2.5, 54), 40 }, { V(46, -2.5, 52), 80 }, { V(-26, -2.5, 54), 120 },
                { V(-40, -2.5, 30), 160 }, { V(-42, -2.5, 6), 200 }, { V(-6, -2.5, -22), 240 }, { V(54, -2.5, -24), 280 },
                { V(-44, -2.5, -44), 320 }, { V(28, -2.5, -50), 20 },
            }
            local CORALS = { "BrainCoral", "StaghornCoral", "SeaFan", "TableCoral", "TubeSponge" }
            for k, rf in ipairs(REEFS) do
                local at, yaw = rf[1], rf[2]
                if k % 4 == 1 then KP("ReefArch", at + V(0, -0.8, 0), 0.9 + (k % 2) * 0.2, yaw) else KP("ReefRock", at + V(0, -0.6, 0), 0.8 + (k % 3) * 0.25, yaw) end
                for j = 0, 3 do
                    local a = R(yaw + j * 95)
                    local d = 3.2 + (j % 2) * 1.6
                    KP(CORALS[(k + j) % #CORALS + 1], at + V(math.cos(a) * d, 0, math.sin(a) * d), 0.8 + ((k + j) % 3) * 0.3, yaw + j * 60)
                end
                if k % 3 == 1 then
                    local an = at + V(math.cos(R(yaw + 300)) * 3.4, 0, math.sin(R(yaw + 300)) * 3.4)
                    KP("Anemone", an, 1.1, yaw)
                    for c = 0, 1 do
                        KC("Clownfish", an + V(2, 1.2, 0), 0.8, "Orbit", { Center = O + an + V(0, 1.4 + c * 0.5, 0), RX = 2.2, RZ = 1.8, Speed = 1.6, Phase = c * 3.1, Bob = 0.3 }, TAIL)
                    end
                end
                if k % 2 == 0 then KP("Starfish", at + V(-3, 0.05, 2.5), 0.9, yaw + 30) end
            end
            -- KELP forests to the west and south-west, swaying on their holdfasts
            for k, kp in ipairs({ V(-52, -2.5, 40), V(-56, -2.5, 28), V(-50, -2.5, 50), V(-60, -2.5, 16), V(-38, -2.5, 62), V(-28, -2.5, 66),
                V(64, -2.5, 34), V(70, -2.5, 46), V(-54, -2.5, -26), V(-62, -2.5, -38), V(8, -2.5, -60), V(40, -2.5, 70) }) do
                local c = KC("Kelp", kp, 1.4 + (k % 4) * 0.3, "Sway", { Amp = 0.07, Phase = k * 0.7 })
                if c then c.CFrame = c.CFrame * ANG(0, R(k * 47), 0) end
            end
            -- THE WRECK half buried out in the haze, a chest of gold spilling light beside it
            KP("Shipwreck", V(62, -6, 96), 1, 210, 16)
            local chest = KP("TreasureChest", V(40, -2.4, 74), 1, 160)
            if chest then
                local glow = S(V(40, -0.8, 74), V(1.6, 0.8, 1.2), C(255, 206, 90), M.Neon, { Shape = Ball, T = 0.3 })
                Anim(glow, "Pulse", { Amp = 0.25, Rate = 1.1 })
                local cl = Instance.new("PointLight"); cl.Color = C(255, 200, 110); cl.Range = 18; cl.Brightness = 0.9; cl.Shadows = false; cl.Parent = glow
            end
            -- bubble vents (streams of real bubbles rising to the surface)
            for _, vp in ipairs({ V(-46, -2.4, 40), V(62, -2.4, 32), V(-4, -2.4, -28) }) do
                KP("ReefRock", vp + V(0, -0.8, 0), 0.4, 0)
                local vent = S(vp + V(0, 0.2, 0), V(0.6, 0.2, 0.6), DEEP, M.SmoothPlastic, { T = 1 })
                Kit.Bubbles(vent, { Rate = 5, Life = 9 })
            end
            -- THE LIFE. A school circles over the arch (seen through the glass roof), tangs patrol the glass, a manta + a
            -- turtle + a shark sweep round the whole tunnel, jellyfish drift and glow
            local nSchool = low and 6 or 14
            for i = 0, nSchool - 1 do
                KC((i % 3 == 0) and "BlueTang" or "YellowTang", V(XM, 24, ZC), 1.1 + (i % 3) * 0.15, "Orbit",
                    { Center = O + V(XM, 23.5 + (i % 4) * 1.3, ZC), RX = 40 + (i % 3) * 1.6, RZ = 31 + (i % 2) * 1.2, Speed = 6, Phase = i * 0.085, Bob = 0.7 }, TAIL)
            end
            for i = 0, (low and 2 or 5) do
                local south = i % 2 == 0
                KC((i % 3 == 0) and "BlueTang" or "Angelfish", V(XM, 2 + (i % 3) * 2.6, south and (50 + (i % 2) * 2) or -20), 1 + (i % 2) * 0.15, "Line",
                    { Axis = "X", Amp = 40, Speed = 4.5 + (i % 3), Phase = i * 1.3 }, TAIL)
            end
            KC("Manta", V(XM, 36, ZC), 1.4, "Orbit", { Center = O + V(XM, 36, ZC), RX = 66, RZ = 54, Speed = 4.5, Phase = 0, Bob = 2.2 },
                { ["left wing"] = { "Z", 0.32, 1.5 }, ["right wing"] = { "Z", -0.32, 1.5 }, tail = { "Y", 0.15, 1.5 } })
            KC("Turtle", V(XM, 26, ZC), 1, "Orbit", { Center = O + V(XM + 4, 27, ZC - 2), RX = 52, RZ = 42, Speed = 2.6, Phase = 2.4, Bob = 1.2, Dir = -1 },
                { ["left front flipper"] = { "Z", 0.4, 1.3 }, ["right front flipper"] = { "Z", -0.4, 1.3 } })
            KC("Shark", V(XM, 15, ZC), 1, "Orbit", { Center = O + V(XM, 15, ZC), RX = 78, RZ = 64, Speed = 5, Phase = 4.2, Bob = 1.5 }, TAIL)
            for i, jp in ipairs({ V(-44, 10, 32), V(66, 12, -4), V(20, 9, 54), V(-20, 8, 52), V(-2, 12, -32), V(58, 12, -32), V(-48, 14, -8) }) do
                local j = KC("Jellyfish", jp, 0.9 + (i % 3) * 0.25, "Bob", { Amp = 1.4, Rate = 0.5, Phase = i * 1.3, NoTurn = true })
                if j then for _, m in ipairs(j:GetChildren()) do if m:IsA("BasePart") then m.Transparency = 0.3 end end end
            end
        end
        if not deepV2 then -- (the kit isn't in this place: the old primitive sea)
        local CX, CZ = XM, 2
        S(V(CX, -3.5, CZ), V(320, 2, 320), C(176, 160, 118), M.Sand)
        for i = 0, 9 do
            local a = i / 10 * math.pi * 2 + 0.3
            local r = 84 + (i % 3) * 18
            S(V(CX + math.cos(a) * r, -3, CZ + math.sin(a) * r), V(56, 9, 42), (i % 2 == 0) and C(166, 150, 110) or C(186, 170, 128), M.Sand, { Shape = Ball, Rot = ANG(0, a, 0) })
        end
        local DEEP = C(16, 74, 118)
        S(V(CX, 30, CZ - 150), V(304, 70, 2), DEEP, M.Neon)
        S(V(CX, 30, CZ + 150), V(304, 70, 2), DEEP, M.Neon)
        S(V(CX - 150, 30, CZ), V(2, 70, 304), DEEP, M.Neon)
        S(V(CX + 150, 30, CZ), V(2, 70, 304), DEEP, M.Neon)
        S(V(CX, 64, CZ), V(304, 1, 304), C(34, 112, 160), M.Neon) -- (the surface, far above)
        for i, sp in ipairs({ V(-62, 30, 52), V(72, 30, -44), V(78, 30, 30), V(-66, 30, -52), V(22, 30, 72), V(-4, 30, -72) }) do
            Anim(S(sp, V(5, 70, 5), C(150, 220, 255), M.Neon, { T = 0.9, Rot = ANG(R(10), R(i * 50), R(8)) }), "Pulse", { Amp = 0.06, Rate = 0.4, Phase = i })
        end
        local CORAL = { C(255, 110, 140), C(255, 160, 70), C(180, 110, 255), C(80, 230, 200), C(255, 220, 90) }
        local reef = { V(-6, 0, 50), V(18, 0, 52), V(-26, 0, 50), V(44, 0, 50), V(64, 0, 8), V(62, 0, -8), V(-46, 0, 12), V(-46, 0, -4),
            V(-2, 0, -22), V(56, 0, -26), V(-46, 0, -32), V(28, 0, -50) }
        for k, p in ipairs(reef) do
            S(p + V(0, -1.8, 0), V(5 + k % 3, 3, 4 + k % 2), C(84, 90, 96), M.Slate, { Shape = Ball })
            S(p + V(1.6, -0.3, 0.6), V(2, 1.6, 2), CORAL[k % 5 + 1], M.SmoothPlastic, { Shape = Ball })
            for b = 0, 2 do
                local ang = b * 2.1 + k
                local h = 3 + b * 0.7
                S(p + V(math.cos(ang) * 1.2 - 1, -1 + h / 2, math.sin(ang) * 1.2), V(0.45, h, 0.45), CORAL[(k + 2) % 5 + 1], M.SmoothPlastic,
                    { Rot = ANG(math.cos(ang) * 0.4, 0, math.sin(ang) * 0.4) })
            end
            if k % 2 == 0 then
                Anim(S(p + V(-1.8, 0.1, -1), V(1.2, 1.2, 1.2), CORAL[(k + 4) % 5 + 1], M.Neon, { Shape = Ball, T = 0.2 }), "Pulse", { Amp = 0.35, Rate = 1.2, Phase = k })
            end
        end
        local kelpAt = { V(-50, 0, 36), V(-54, 0, 24), V(-48, 0, 46), V(66, 0, 20), V(70, 0, 30), V(64, 0, -20), V(-20, 0, 56), V(-12, 0, 58),
            V(36, 0, 56), V(-50, 0, -24), V(-4, 0, -34), V(2, 0, -26) }
        for k, p in ipairs(kelpAt) do
            local L = 14 + (k * 5) % 9
            local stalk = S(p + V(0, -2.5 + L / 2, 0), V(0.4, L, 0.4), C(74, 128, 52), M.SmoothPlastic)
            Anim(stalk, "Sway", { Amp = 0.1, Phase = k * 0.7 })
            for j = 1, 3 do
                local side = (j % 2 == 0) and 1 or -1
                S(p + V(0.55 * side, -2.5 + L * (0.3 + j * 0.2), 0), V(0.12, 2.6, 1.3), C(96, 156, 64), M.SmoothPlastic, { Parent = stalk, Rot = ANG(0, 0, R(-25 * side)) })
            end
        end
        for v, vp in ipairs({ V(-46, 0, 40), V(62, 0, 32), V(-4, 0, -28) }) do
            S(vp + V(0, -2.3, 0), V(0.6, 1.6, 1.6), C(60, 64, 70), M.Slate, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
            for b = 1, 5 do
                local d = 0.3 + (b % 3) * 0.15
                Anim(S(vp + V(0, -2, 0), V(d, d, d), C(210, 245, 255), M.Glass, { Shape = Ball, T = 0.35 }), "Rise", { Height = 36, Speed = 3 + (b % 3), Phase = b * 1.25 + v })
            end
        end
        S(V(26, -1.6, 53), V(3, 1.8, 2), C(110, 74, 44), M.Wood, { Rot = ANG(0, R(20), 0) })
        S(V(26.2, -0.2, 53.9), V(3.1, 0.3, 2.1), C(96, 64, 38), M.Wood, { Rot = ANG(0, R(20), 0) * ANG(R(-55), 0, 0) })
        S(V(26, -0.5, 53), V(2.6, 0.7, 1.6), C(255, 210, 70), M.Neon, { Shape = Ball, T = 0.1 })
        local KINDS = {
            { C(255, 130, 40), C(255, 130, 40), C(250, 250, 250) }, -- (clownfish)
            { C(40, 90, 230), C(255, 220, 40) }, -- (blue tang)
            { C(255, 225, 50), C(255, 225, 50) }, -- (yellow tang)
            { C(255, 120, 190), C(180, 90, 255) },
            { C(150, 230, 255), C(60, 150, 220) },
        }
        local function Fish(lp: Vector3, len: number, kind: number, anim: string, attrs: any)
            local kd = KINDS[kind]
            local b = S(lp, V(len * 0.34, len * 0.55, len), kd[1], M.SmoothPlastic, { Shape = Ball })
            local tl = S(lp + V(0, 0, len * 0.66), V(0.08, len * 0.42, len * 0.42), kd[2], M.SmoothPlastic, { Parent = b, Rot = ANG(R(45), 0, 0) })
            Hinge(tl, V(0, 0, len * 0.45), "Y", 0.45, 9)
            S(lp + V(0, len * 0.3, len * 0.05), V(0.06, len * 0.22, len * 0.42), kd[2], M.SmoothPlastic, { Parent = b })
            if kd[3] then S(lp + V(0, 0, -len * 0.1), V(len * 0.36, len * 0.5, len * 0.14), kd[3], M.SmoothPlastic, { Parent = b, Shape = Ball }) end
            Anim(b, anim, attrs)
        end
        for i = 0, 6 do Fish(V(XM, 2 + (i % 4) * 2.4, 50 + (i % 3) * 2), 1.6 + (i % 2) * 0.6, i % 5 + 1, "Line", { Axis = "X", Amp = 46, Speed = 5 + (i % 3), Phase = i * 1.1 }) end
        for i = 0, 3 do Fish(V(MXC, 2 + i * 2.6, -48 - (i % 2) * 2), 1.4 + (i % 2) * 0.5, (i + 2) % 5 + 1, "Line", { Axis = "X", Amp = 26, Speed = 4 + i % 2, Phase = i * 1.7 }) end
        for i = 0, 3 do Fish(V(-44 - (i % 2) * 2, 2 + i * 2.5, 10), 1.5, (i + 1) % 5 + 1, "Line", { Axis = "Z", Amp = 26, Speed = 4.5, Phase = i * 1.4 }) end
        for i = 0, 3 do Fish(V(64 + (i % 2) * 2, 3 + i * 2.2, 8), 1.5 + (i % 2) * 0.4, (i + 3) % 5 + 1, "Line", { Axis = "Z", Amp = 30, Speed = 5, Phase = i * 1.9 }) end
        for i = 0, 7 do Fish(V(0, 26, 0), 1.2, 2, "Orbit", { Center = O + V(XM, 25 + (i % 3) * 1.2, 4), RX = 38, RZ = 30, Speed = 6, Phase = i * 0.12, Bob = 0.8 }) end
        do
            local m = S(V(0, 34, 0), V(3.2, 0.7, 4.4), C(40, 56, 80), M.SmoothPlastic, { Shape = Ball })
            for s = -1, 1, 2 do
                Hinge(S(V(s * 3.6, 34, 0.4), V(5, 0.3, 3.2), C(46, 64, 90), M.SmoothPlastic, { Parent = m, Shape = Ball }), V(s * 1.4, 0, 0), "Z", 0.35 * s, 1.8)
            end
            S(V(0, 34, 5), V(0.15, 0.15, 5), C(30, 40, 56), M.SmoothPlastic, { Parent = m })
            Anim(m, "Orbit", { Center = O + V(XM, 35, 2), RX = 60, RZ = 50, Speed = 4, Phase = 0, Bob = 2 })
        end
        do
            local t = S(V(0, 25, 0), V(3, 1.3, 3.8), C(96, 120, 70), M.SmoothPlastic, { Shape = Ball })
            S(V(0, 25.45, 0), V(2.4, 0.7, 3), C(120, 96, 60), M.SmoothPlastic, { Parent = t, Shape = Ball })
            S(V(0, 25.2, -2.3), V(0.9, 0.8, 1.1), C(140, 160, 100), M.SmoothPlastic, { Parent = t, Shape = Ball })
            for s = -1, 1, 2 do
                Hinge(S(V(s * 2, 24.9, -0.9), V(2.6, 0.2, 1), C(130, 150, 92), M.SmoothPlastic, { Parent = t, Shape = Ball }), V(s * 1.2, 0, -0.9), "Z", 0.4 * s, 1.4)
                S(V(s * 1.3, 24.9, 1.6), V(1.2, 0.18, 0.7), C(130, 150, 92), M.SmoothPlastic, { Parent = t, Shape = Ball })
            end
            Anim(t, "Orbit", { Center = O + V(XM + 4, 25, 0), RX = 50, RZ = 40, Speed = 2.5, Phase = 2.4, Bob = 1.2, Dir = -1 })
        end
        for i, jp in ipairs({ V(-44, 10, 30), V(66, 12, -4), V(20, 9, 52), V(-20, 8, 50), V(-2, 12, -30), V(58, 12, -30) }) do
            local col = ({ C(255, 140, 220), C(180, 140, 255), C(120, 220, 255) })[i % 3 + 1]
            local bell = S(jp, V(2.4, 1.6, 2.4), col, M.Neon, { Shape = Ball, T = 0.45 })
            for k = 0, 3 do
                local a = k * math.pi / 2 + 0.4
                local len = 3 - (k % 2) * 0.8
                S(jp + V(math.cos(a) * 0.6, -0.6 - len / 2, math.sin(a) * 0.6), V(0.08, len, 0.08), col, M.Neon, { Parent = bell, T = 0.5 })
            end
            Anim(bell, "Bob", { Amp = 1.4, Rate = 0.5, Phase = i * 1.3 })
        end
        end
    elseif theme == "Forest" then
        -- ===== FOREST CABIN: a log cabin built into a giant tree, up in the canopy. Stacked-log walls with open windows,
        -- a vaulted A-frame roof on rafters, three lanterns, a plank practice shed with archery targets, a plank map-room
        -- annex, a deck with a rope rail and fairy lights. Outside: the great trunk + branches over the roof, a ring of
        -- giant trees, a sea of treetops below (no ground), vines, fireflies, butterflies, birds, falling leaves, sun rays.
        local LOG1, LOG2, BARK, PLANK = C(128, 90, 58), C(112, 78, 50), C(88, 62, 42), C(96, 66, 44)
        local LEAF = { C(72, 122, 52), C(86, 138, 60), C(60, 106, 46), C(98, 146, 64) }
        local ROPE = C(196, 170, 120)
        -- (UPDATE 4) FOREST v2: real trees, canopy, lanterns, birds + butterflies, leaf fall, mist and sun rays (HideoutKit)
        local forestV2 = Kit ~= nil and Kit.Get("Forest", "GiantTree") ~= nil
        local lowQ = Kit ~= nil and Kit.Low() or false
        local function FP(name: string, lp: Vector3, scale: number?, yaw: number?, tilt: number?)
            if not forestV2 then return nil end
            return Kit.Place(f, "Forest", name, CF(O + lp) * ANG(0, R(yaw or 0), 0) * ANG(R(tilt or 0), 0, 0), scale)
        end
        local function FC(name: string, lp: Vector3, scale: number?, anim: string, attrs: any?, flap: any?)
            if not forestV2 then return nil end
            local c = Kit.Creature(f, "Forest", name, CF(O + lp), scale, { Flap = flap })
            if c then Anim(c, anim, attrs) end
            return c
        end
        local nLog = 0
        local function LogX(x0: number, x1: number, y: number, z: number)
            nLog += 1
            S(V((x0 + x1) / 2, y, z), V(x1 - x0, 1.5, 1.5), (nLog % 2 == 0) and LOG1 or LOG2, M.Wood, { Shape = Cyl, Collide = true })
        end
        local function LogZ(z0: number, z1: number, y: number, x: number)
            nLog += 1
            S(V(x, y, (z0 + z1) / 2), V(z1 - z0, 1.5, 1.5), (nLog % 2 == 0) and LOG1 or LOG2, M.Wood, { Shape = Cyl, Collide = true, Rot = ANG(0, R(90), 0) })
        end
        -- the walls: 8 courses; windows (y 4.5..9) west + 2 north; the map-room doorway north; the door east; the deck opening south
        for L = 0, 7 do
            local y = 0.75 + L * 1.5
            local win = L >= 3 and L <= 5
            if win then LogZ(-15, -6, y, -30.5); LogZ(2, BZ + 1, y, -30.5) else LogZ(-15, BZ + 1, y, -30.5) end
            local gaps = {}
            if win then table.insert(gaps, { -8, 4 }) end
            if L <= 5 then table.insert(gaps, { MR.DoorX0, MR.DoorX1 }) end
            if win then table.insert(gaps, mapRoom and { 47, 53 } or { 40, 52 }) end -- (2026-10-23: not into the map room)
            for _, run in ipairs(Runs(-14.5, BX + 1, gaps)) do LogX(run[1], run[2], y, -14.5) end
            if L >= 6 then LogX(-31, -14.5, y, -14.5) end -- (over the practice shed's doorway)
            if L <= 6 then LogZ(-15, 0, y, BX + 0.5); LogZ(8, BZ + 1, y, BX + 0.5) else LogZ(-15, BZ + 1, y, BX + 0.5) end
            if L <= 5 then LogX(-31, -6, y, BZ + 0.5); LogX(30, BX + 1, y, BZ + 0.5) else LogX(-31, BX + 1, y, BZ + 0.5) end
        end
        for _, c in ipairs({ V(-30.5, 0, -14.5), V(BX + 0.5, 0, -14.5), V(-30.5, 0, BZ + 0.5), V(BX + 0.5, 0, BZ + 0.5), V(-14.5, 0, -14.5),
            V(-6, 0, BZ + 0.5), V(30, 0, BZ + 0.5), V(MR.DoorX0, 0, -14.5), V(MR.DoorX1, 0, -14.5) }) do
            S(c + V(0, 6, 0), V(12, 2.2, 2.2), BARK, M.Wood, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
        end
        local function Window(c: Vector3, alongX: boolean, w: number)
            local sz = alongX and V(w + 1, 0.4, 2.2) or V(2.2, 0.4, w + 1)
            S(c + V(0, -2.35, 0), sz, PLANK, M.WoodPlanks)
            S(c + V(0, 2.35, 0), sz, PLANK, M.WoodPlanks)
            S(c, V(0.3, 4.5, 0.3), PLANK, M.Wood)
            Barrier(c, alongX and V(w, 4.5, 0.4) or V(0.4, 4.5, w))
        end
        Window(V(-30.5, 6.75, -2), false, 8)
        Window(V(-2, 6.75, -14.5), true, 12)
        if mapRoom then Window(V(50, 6.75, -14.5), true, 6) else Window(V(46, 6.75, -14.5), true, 12) end
        -- the roof: two plank slopes (eaves y 11, ridge y 24 along z 10), rafters, a ridge beam, tie beams, plank gables
        local RIDGE, EAVE, RZ = 24, 11, ZM
        SegX(-32, BX + 2, -16.5, EAVE, RZ, RIDGE, 0.8, C(84, 58, 40), M.WoodPlanks, { Roof = true, Collide = true })
        SegX(-32, BX + 2, BZ + 2.5, EAVE, RZ, RIDGE, 0.8, C(84, 58, 40), M.WoodPlanks, { Roof = true, Collide = true })
        for x = -24, BX - 6, 12 do
            SegX(x - 0.45, x + 0.45, -16.5, EAVE, RZ, RIDGE, 0.9, BARK, M.Wood, { Roof = true }, -0.85)
            SegX(x - 0.45, x + 0.45, BZ + 2.5, EAVE, RZ, RIDGE, 0.9, BARK, M.Wood, { Roof = true }, 0.85)
        end
        S(V(XM, RIDGE - 1.2, RZ), V(BX + 34, 1.4, 1.4), BARK, M.Wood, { Shape = Cyl, Roof = true })
        for _, x in ipairs({ 0, 24 }) do S(V(x, 12.2, RZ), V(BZ + 15, 1.2, 1.2), BARK, M.Wood, { Shape = Cyl, Rot = ANG(0, R(90), 0), Roof = true }) end
        for _, x in ipairs({ -30.5, BX + 0.5 }) do
            S(V(x, 18, (-14.5 + RZ) / 2), V(1.2, 12, RZ + 14.5), LOG2, M.WoodPlanks, { Wedge = true, Collide = true })
            S(V(x, 18, (RZ + BZ + 0.5) / 2), V(1.2, 12, BZ + 0.5 - RZ), LOG2, M.WoodPlanks, { Wedge = true, Collide = true, Rot = ANG(0, math.pi, 0) })
        end
        -- three lanterns on chains from the ridge (the cabin's only lights), flames flickering
        for _, x in ipairs({ -12, 12, 36 }) do
            S(V(x, (RIDGE - 1.9 + 9.7) / 2, RZ), V(0.12, RIDGE - 1.9 - 9.7, 0.12), DARK, M.Metal, { Roof = true })
            if not FP("Lantern", V(x, 7.5, RZ), 1, x * 7) then
                S(V(x, 9.55, RZ), V(1.6, 0.3, 1.6), C(40, 34, 30), M.Metal)
                S(V(x, 8.6, RZ), V(1.3, 1.8, 1.3), C(40, 34, 30), M.Metal, { T = 0.6 })
                S(V(x, 7.65, RZ), V(1.5, 0.25, 1.5), C(40, 34, 30), M.Metal)
            end
            local flame = S(V(x, 8.5, RZ), V(0.6, 1, 0.6), C(255, 190, 100), M.Neon, { T = 0.1, Shape = Ball })
            Anim(flame, "Pulse", { Amp = 0.25, Rate = 7, Phase = x })
            local l = Instance.new("PointLight"); l.Color = C(255, 180, 110); l.Range = 34; l.Brightness = 0.9; l.Shadows = false; l.Parent = flame
        end
        -- the door: vertical planks, iron straps, a ring handle, a carved EXIT board over it
        for k = 0, 4 do S(V(BX + 0.42, 5.4, 4 - 3 + k * 1.5), V(0.3, 10.8, 1.46), (k % 2 == 0) and C(112, 74, 44) or C(98, 64, 38), M.Wood) end
        for _, y in ipairs({ 2.2, 5.4, 8.6 }) do S(V(BX + 0.24, y, 4), V(0.12, 0.45, 7.4), DARK, M.Metal) end
        S(V(BX + 0.15, 5, 1.6), V(0.12, 0.9, 0.9), C(70, 66, 60), M.Metal, { Shape = Cyl })
        S(V(BX + 0.2, 11.3, 4), V(9, 1.2, 1.2), BARK, M.Wood, { Shape = Cyl, Rot = ANG(0, R(90), 0) })
        local exit = S(V(BX - 0.4, 12.4, 4), V(0.25, 1.1, 4), PLANK, M.WoodPlanks)
        Label(exit, Enum.NormalId.Left, "出口  EXIT", C(255, 222, 160))
        -- THE PRACTICE SHED: plank walls on log posts, a sloped plank roof, straw bales, two archery targets
        S(V(-34.5, 6, -26.5), V(1, 12, 24), PLANK, M.WoodPlanks, { Collide = true })
        S(V(-13.5, 6, -26.5), V(1, 12, 24), PLANK, M.WoodPlanks, { Collide = true })
        S(V(-24, 6, -38.5), V(22, 12, 1), PLANK, M.WoodPlanks, { Collide = true })
        S(V(-32.5, 6, -14.5), V(4, 12, 1), PLANK, M.WoodPlanks, { Collide = true })
        for _, c in ipairs({ V(-34.5, 0, -38.5), V(-13.5, 0, -38.5), V(-34.5, 0, -26.5), V(-13.5, 0, -26.5) }) do
            S(c + V(0, 6.5, 0), V(13, 1.6, 1.6), BARK, M.Wood, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
        end
        S(V(-24, 12.9, -26.6), V(23, 0.6, 25.6), C(84, 58, 40), M.WoodPlanks, { Collide = true, Roof = true, Rot = ANG(R(-3), 0, 0) })
        for _, x in ipairs(forestV2 and {} or { -29, -19 }) do
            S(V(x, 6, -37.85), V(0.3, 4, 4), C(240, 236, 220), M.SmoothPlastic, { Shape = Cyl, Rot = ANG(0, R(90), 0) })
            S(V(x, 6, -37.7), V(0.3, 2.7, 2.7), C(220, 60, 50), M.SmoothPlastic, { Shape = Cyl, Rot = ANG(0, R(90), 0) })
            S(V(x, 6, -37.55), V(0.3, 1.2, 1.2), C(255, 210, 60), M.SmoothPlastic, { Shape = Cyl, Rot = ANG(0, R(90), 0) })
        end
        for _, x in ipairs({ -31.6, -16.4 }) do S(V(x, 1.2, -36.4), V(3.6, 2.4, 2.6), C(214, 186, 110), M.Fabric) end
        for _, x in ipairs({ -28, -20 }) do FP("ArcheryTarget", V(x, 0, -36.8), 1, 0) end
        local sign = S(V(-22.5, 10.5, -13.6), V(9, 1.4, 0.25), PLANK, M.WoodPlanks)
        Label(sign, Enum.NormalId.Back, "PRACTICE  練習", C(255, 222, 160))
        -- THE MAP ROOM annex (plank walls, a lantern-lit plank roof) or its locked plank door
        if mapRoom then
            S(V(MR.X0 - 0.5, 6, MZC), V(1, 12, -14 - MR.Z0), PLANK, M.WoodPlanks, { Collide = true })
            S(V(MR.X1 + 0.5, 6, MZC), V(1, 12, -14 - MR.Z0), PLANK, M.WoodPlanks, { Collide = true })
            S(V(MXC, 6, MR.Z0 - 0.5), V(MR.X1 - MR.X0 + 2, 12, 1), PLANK, M.WoodPlanks, { Collide = true })
            for _, c in ipairs({ V(MR.X0 - 0.5, 0, MR.Z0 - 0.5), V(MR.X1 + 0.5, 0, MR.Z0 - 0.5), V(MR.X0 - 0.5, 0, -15), V(MR.X1 + 0.5, 0, -15) }) do
                S(c + V(0, 6.5, 0), V(13, 1.8, 1.8), BARK, M.Wood, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
            end
            S(V(MXC, 12.9, MZC), V(MR.X1 - MR.X0 + 3, 0.6, -14 - MR.Z0 + 2), C(84, 58, 40), M.WoodPlanks, { Collide = true, Roof = true, Rot = ANG(R(3), 0, 0) })
            local mapSign = S(V(28, 10.5, -13.6), V(9, 1.4, 0.25), PLANK, M.WoodPlanks)
            Label(mapSign, Enum.NormalId.Back, "MAP ROOM  地図室", C(255, 222, 160))
        else
            for k = 0, 7 do S(V(MR.DoorX0 + 0.75 + k * 1.5, 4.5, -14.5), V(1.46, 9, 0.4), (k % 2 == 0) and C(112, 74, 44) or C(98, 64, 38), M.Wood, { Collide = true }) end
            for _, y in ipairs({ 2, 7 }) do S(V(28, y, -14.2), V(12, 0.4, 0.15), DARK, M.Metal) end
            LockedSign(-14.1, C(255, 222, 160))
        end
        -- THE DECK (the balcony): a rope rail on log posts, fairy lights, two planters
        for x = -30, BX, 6 do S(V(x, 1.9, BALZ), V(3.8, 0.7, 0.7), BARK, M.Wood, { Shape = Cyl, Rot = ANG(0, 0, R(90)) }) end
        for _, y in ipairs({ 2, 3.5 }) do
            S(V(XM, y, BALZ), V(BX + 30, 0.25, 0.25), ROPE, M.Fabric, { Shape = Cyl })
            for _, x in ipairs({ -30, BX }) do S(V(x, y, (BZ + BALZ) / 2), V(BALZ - BZ, 0.25, 0.25), ROPE, M.Fabric, { Shape = Cyl, Rot = ANG(0, R(90), 0) }) end
        end
        for _, x in ipairs({ -30, BX }) do S(V(x, 1.9, (BZ + BALZ) / 2), V(3.8, 0.7, 0.7), BARK, M.Wood, { Shape = Cyl, Rot = ANG(0, 0, R(90)) }) end
        for i = 0, 12 do
            Anim(S(V(-24 + i * 6, 3.05, BALZ + 0.1), V(0.45, 0.45, 0.45), (i % 2 == 0) and C(255, 214, 120) or C(255, 170, 120), M.Neon, { Shape = Ball }), "Pulse", { Amp = 0.4, Rate = 1.5, Phase = i * 0.8 })
        end
        for _, x in ipairs({ -26, BX - 4 }) do
            S(V(x, 0.6, BALZ - 1.6), V(4, 1.2, 1.6), PLANK, M.WoodPlanks)
            if not FP("Flowers", V(x, 1.2, BALZ - 1.6), 1, 0) then
                for j = 0, 2 do S(V(x - 1.2 + j * 1.2, 1.5, BALZ - 1.6), V(0.9, 0.9, 0.9), ({ C(255, 120, 170), C(255, 220, 90), C(190, 140, 255) })[j + 1], M.SmoothPlastic, { Shape = Ball }) end
            end
        end
        -- under the cabin: floor beams + braces down into the treetops
        for _, z in ipairs({ -12, ZM, BZ - 2 }) do S(V(XM, -1.9, z), V(BX + 34, 2, 2), BARK, M.Wood, { Shape = Cyl }) end
        for _, b in ipairs({ { V(-24, -2, -12), V(-30, -30, -26) }, { V(BX - 6, -2, -12), V(BX + 4, -30, -24) }, { V(-24, -2, BZ - 2), V(-32, -30, BZ + 12) }, { V(BX - 6, -2, BZ - 2), V(BX + 4, -30, BZ + 14) } }) do
            local a, c = b[1], b[2]
            SC(CFrame.lookAt((a + c) / 2, c) * ANG(0, R(90), 0), V((c - a).Magnitude, 1.6, 1.6), BARK, M.Wood, { Shape = Cyl })
        end
        -- THE GREAT TREE (north-east): the trunk, fungus shelves, branches over the roof, its crown
        local TX, TZ = BX + 18, -30
        if forestV2 then
            -- ===== FOREST v2 (UPDATE 4): the cabin sits against a colossal tree; a ring of giants rises out of a sea of
            -- canopy below; branches + leaf crowns arch over the roof; mist drifts over the treetops; warm sun shafts
            FP("GiantTree", V(TX + 6, -22, TZ - 6), 1.25, 200)
            -- (shelf fungus on the bark facing the cabin: the trunk's surface measured at r ~6 round (TX + 6, TZ - 6))
            for j, fs in ipairs({ { V(TX - 0.24, 3, TZ - 2.4), -60 }, { V(TX - 0.6, 7, TZ - 6), -90 }, { V(TX + 1.64, 1, TZ + 0.23), -35 } }) do FP("Fungus", fs[1], 0.9 - j * 0.1, fs[2]) end
            -- (the colossal tree's own crown overhangs the roof: no separate branch + crown pieces, they read as floating discs)
            for i = 0, 13 do -- (the ring of giants)
                local a = i / 14 * math.pi * 2 + 0.2
                local r = 96 + (i % 3) * 14
                FP("GiantTree", V(XM + math.cos(a) * r, -60 - (i % 3) * 6, 4 + math.sin(a) * r), 1 + (i % 3) * 0.18, i * 53)
            end
            local step = lowQ and 52 or 40
            for gx = -5, 5 do -- (the sea of canopy, no ground)
                for gz = -5, 5 do
                    local x, z = XM + gx * step + ((gz % 2) * step / 2), 4 + gz * step
                    local d = math.sqrt((x - XM) ^ 2 + (z - 4) ^ 2)
                    if d < 190 then -- (under the cabin they sit lower: the cabin rests on the treetops)
                        local lp, sc, yw = V(x, ((d < 34) and -32 or -24) - ((gx * 7 + gz * 3) % 4) * 3, z), 1.3 + ((gx + gz) % 3) * 0.2, gx * 40 + gz * 17
                        local _ = FP("CanopySea", lp, sc, yw) or FP("Canopy", lp, sc, yw)
                    end
                end
            end
            S(V(XM, -44, 4), V(440, 2, 440), C(26, 44, 24), M.LeafyGrass) -- (the shaded under-storey: gaps read as deep forest)
            -- mist banks over the treetops, leaves drifting past the windows + deck, sun shafts
            local mist = S(V(XM, -12, 4), V(260, 8, 260), C(230, 236, 220), M.SmoothPlastic, { T = 1 })
            Kit.Mist(mist, { Rate = 6, Size = 46, T = 0.72 })
            for _, lb in ipairs({ { V(XM, 24, BALZ + 6), V(BX + 40, 8, 10) }, { V(XM, 24, -22), V(BX + 40, 8, 10) }, { V(-40, 24, ZM), V(10, 8, 50) } }) do
                local e = S(lb[1], lb[2], LEAF[1], M.SmoothPlastic, { T = 1 })
                Kit.Leaves(e, { Rate = 3 })
            end
            if not lowQ then
                for i, rp in ipairs({ V(-56, 0, 52), V(-20, 0, 66), V(30, 0, 64), V(74, 0, 44), V(-62, 0, -36), V(4, 0, -62), V(70, 0, -40), V(-70, 0, 8) }) do
                    Kit.GodRay(f, O + rp + V(-16, 90, -10), O + rp + V(2, -16, 2), 8 + (i % 3) * 3, 20 + (i % 2) * 8, C(255, 224, 160), 0.82)
                end
            end
        end
        if not forestV2 then
        S(V(TX, -10, TZ), V(160, 18, 18), BARK, M.Wood, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
        for j, fp in ipairs({ V(TX - 8.6, 4, TZ + 4), V(TX - 8.4, 7, TZ - 1), V(TX - 8, 2, TZ - 5) }) do
            S(fp, V(3 - j * 0.4, 0.6, 3.6 - j * 0.4), C(230, 150, 70), M.SmoothPlastic, { Shape = Ball })
        end
        local function Branch(a: Vector3, c: Vector3, d: number, roof: boolean?)
            SC(CFrame.lookAt((a + c) / 2, c) * ANG(0, R(90), 0), V((c - a).Magnitude, d, d), BARK, M.Wood, { Shape = Cyl, Roof = roof })
        end
        Branch(V(TX - 4, 26, TZ + 4), V(18, 34, 6), 3, true)
        Branch(V(TX + 2, 18, TZ + 8), V(TX + 14, 24, BZ + 4), 2.6)
        Branch(V(TX - 4, 34, TZ - 6), V(36, 40, -66), 2.6)
        for j, lc in ipairs({ { V(34, 35, -2), V(20, 8, 18), true }, { V(16, 35, 8), V(18, 7, 16), true }, { V(52, 32, -12), V(16, 8, 14), true },
            { V(TX, 46, TZ), V(36, 16, 32) }, { V(TX + 12, 38, TZ + 18), V(24, 12, 22) }, { V(TX - 14, 44, TZ - 14), V(26, 12, 24) },
            { V(TX + 14, 26, BZ + 4), V(20, 10, 18) }, { V(36, 42, -66), V(22, 10, 20) } }) do
            S(lc[1], lc[2], LEAF[j % 4 + 1], M.LeafyGrass, { Shape = Ball, Roof = lc[3] })
        end
        -- a ring of giant trees all round, a sea of treetops below (no ground)
        for i = 0, 13 do
            local a = i / 14 * math.pi * 2 + 0.2
            local r = 92 + (i % 3) * 12
            local x, z = XM + math.cos(a) * r, 4 + math.sin(a) * r
            local d = 8 + (i % 3) * 2
            S(V(x, -15, z), V(150, d, d), (i % 2 == 0) and BARK or C(80, 58, 40), M.Wood, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
            for j = 0, 3 do
                local s = 32 - j * 5
                local ca = a + j * 1.7
                S(V(x + math.cos(ca) * 6, 22 + j * 9 + (i % 2) * 4, z + math.sin(ca) * 6), V(s, s * 0.45, s * 0.9), LEAF[(i + j) % 4 + 1], M.LeafyGrass, { Shape = Ball })
            end
            S(V(x + math.cos(a + 3) * 5, 2 + (i % 3) * 4, z), V(18, 8, 16), LEAF[i % 4 + 1], M.LeafyGrass, { Shape = Ball })
        end
        for gx = -4, 4 do
            for gz = -4, 4 do
                local x, z = XM + gx * 36 + ((gz % 2) * 18), 4 + gz * 36
                if math.sqrt((x - XM) ^ 2 + (z - 4) ^ 2) < 160 then
                    local j = (gx * 7 + gz * 3) % 4
                    S(V(x, -14 - j * 3, z), V(44 + j * 4, 15, 42 + j * 3), LEAF[j + 1], M.LeafyGrass, { Shape = Ball, Rot = ANG(0, gx + gz, 0) })
                end
            end
        end
        end
        local function Vine(top: Vector3, L: number, amp: number, ph: number)
            local v = S(top - V(0, L / 2, 0), V(0.25, L, 0.25), C(58, 100, 44), M.SmoothPlastic)
            for j = 1, math.max(1, math.floor(L / 3)) do
                local side = (j % 2 == 0) and 1 or -1
                S(top - V(-0.3 * side, j * 2.6, 0), V(0.6, 0.1, 0.5), LEAF[j % 4 + 1], M.SmoothPlastic, { Parent = v, Rot = ANG(0, j, R(20 * side)) })
            end
            Anim(v, "Sway", { Amp = amp, Hang = true, Phase = ph })
        end
        for i, x in ipairs({ -6, 2, 42, 50 }) do Vine(V(x, 10.8, -16.3), 3 + (i % 2) * 2, 0.1, i) end
        for i, x in ipairs({ -20, -4, 20, 36 }) do Vine(V(x, 10.8, BZ + 2.3), 2.5 + (i % 2) * 1.5, 0.1, i * 2) end
        Vine(V(48, 30, -18), 20, 0.05, 1)
        Vine(V(TX - 8, 24, TZ + 10), 18, 0.05, 3)
        Vine(V(TX + 10, 21, 18), 16, 0.05, 5)
        local ffAt = { V(-24, 4, BALZ + 3), V(-8, 6, BALZ + 4), V(8, 3, BALZ + 3), V(24, 5, BALZ + 5), V(40, 4, BALZ + 3), V(-4, 6, -18), V(2, 4, -19),
            V(44, 7, -18), V(50, 5, -20), V(-33, 6, -4), V(-34, 4, 2), V(-10, 9, BZ - 6), V(20, 8, BZ - 7), V(40, 10, BZ - 4) }
        for i, p in ipairs(ffAt) do
            Anim(S(p, V(0.3, 0.3, 0.3), C(255, 236, 120), M.Neon, { Shape = Ball }), "Firefly", { Speed = 0.5 + (i % 4) * 0.2 })
        end
        for i, bp in ipairs({ V(0, 3, BZ + 5), V(28, 4, BZ + 6), V(-2, 5, -18), V(46, 6, -19), V(12, 5, BZ + 7), V(-20, 4, BZ + 6) }) do
            if forestV2 then
                FC((i % 2 == 0) and "Butterfly" or "Butterfly2", bp, 1, "Firefly", { Speed = 0.6 + (i % 3) * 0.15, Steady = true },
                    { ["left wing"] = { "Z", 0.9, 14 }, ["right wing"] = { "Z", -0.9, 14 } })
                continue
            end
            if i > 4 then continue end
            local col = ({ C(255, 150, 60), C(120, 200, 255), C(255, 120, 200), C(255, 230, 80) })[i]
            local b = S(bp, V(0.12, 0.12, 0.5), C(40, 30, 26), M.SmoothPlastic)
            for s = -1, 1, 2 do Hinge(S(bp + V(s * 0.32, 0, 0), V(0.6, 0.05, 0.55), col, M.SmoothPlastic, { Parent = b }), V(s * 0.05, 0, 0), "Z", 1.0 * s, 16) end
            Anim(b, "Firefly", { Speed = 0.7, Steady = true })
        end
        for i = 0, 2 do
            if forestV2 then
                FC("Bird", V(XM, 36 + i * 4, 4), 1, "Orbit", { Center = O + V(XM, 36 + i * 4, 4), RX = 62 - i * 8, RZ = 52 - i * 7, Speed = 10, Phase = i * 2.1, Bob = 2, Dir = (i % 2 == 0) and 1 or -1 },
                    { ["left wing"] = { "Z", 0.7, 8 }, ["right wing"] = { "Z", -0.7, 8 } })
                continue
            end
            local b = S(V(0, 40, 0), V(0.7, 0.6, 1.6), C(60, 50, 44), M.SmoothPlastic, { Shape = Ball })
            for s = -1, 1, 2 do Hinge(S(V(s * 1.2, 40, 0.1), V(2, 0.1, 0.8), C(70, 58, 50), M.SmoothPlastic, { Parent = b }), V(s * 0.3, 0, 0), "Z", 0.7 * s, 8) end
            S(V(0, 40, 1.1), V(0.5, 0.08, 0.7), C(60, 50, 44), M.SmoothPlastic, { Parent = b })
            Anim(b, "Orbit", { Center = O + V(XM, 36 + i * 4, 4), RX = 62 - i * 8, RZ = 52 - i * 7, Speed = 10, Phase = i * 2.1, Bob = 2, Dir = (i % 2 == 0) and 1 or -1 })
        end
        local lfAt = { V(-20, 20, BALZ + 4), V(-6, 22, BALZ + 6), V(10, 21, BALZ + 4), V(30, 20, BALZ + 5), V(-4, 20, -18), V(0, 22, -19), V(46, 21, -18),
            V(-34, 20, -2), V(BX + 4, 22, 14), V(BX + 4, 20, -6) }
        for i, p in ipairs(forestV2 and {} or lfAt) do
            Anim(S(p, V(0.7, 0.06, 0.5), ({ C(220, 140, 50), C(200, 90, 40), C(140, 170, 60) })[i % 3 + 1], M.SmoothPlastic), "Fall", { Height = 24, Speed = 1.6 + (i % 3) * 0.4, Phase = i * 0.9 })
        end
        for i, p in ipairs(forestV2 and {} or { V(-60, 20, 50), V(74, 20, 30), V(-64, 20, -40), V(4, 20, -60) }) do
            Anim(S(p, V(6, 60, 6), C(255, 220, 150), M.Neon, { T = 0.92, Rot = ANG(R(-12), R(i * 40), R(18)) }), "Pulse", { Amp = 0.05, Rate = 0.3, Phase = i })
        end
    elseif theme == "Forge" then
        -- ===== EMBER FORGE (0.59, owner: "More hideout cosmetics (... overall hideouts)"): a smiths' hall cut into a live
        -- volcano. Basalt walls on buttresses with glowing veins, the great HEARTH recessed into the west wall (fire, embers,
        -- an anvil), iron-barred windows north over a lava river, iron beams + chains under the vault, an arched opening
        -- to the balcony over the crater. Outside: the hall stands on a rock spire in a crater ring with lavafalls, a lava
        -- lake far below (no land), floating rocks, embers rising past the windows.
        local BAS, BAS2, IRON, LAVA, EMBER = C(84, 72, 68), C(104, 90, 84), C(52, 50, 52), C(255, 100, 30), C(255, 170, 60)
        -- (UPDATE 4) FORGE v2: real iron lanterns, anvil, quench barrel, braziers and weapon racks (HideoutKit.Forge)
        local forgeV2 = Kit ~= nil and Kit.Get("Forge", "Anvil") ~= nil
        local function FG(name: string, lp: Vector3, yaw: number?, scale: number?): Model?
            if not forgeV2 then return nil end
            return Kit.Place(f, "Forge", name, CF(O + lp) * ANG(0, R(yaw or 0), 0), scale)
        end
        local H = 18
        -- WEST wall with the HEARTH recess (z -9..1), EAST wall with the door, SOUTH wall with the balcony arch
        S(V(-30.5, H / 2, -11.5), V(1.5, H, 5), BAS, M.Basalt, { Collide = true })
        S(V(-30.5, H / 2, (1 + BZ) / 2), V(1.5, H, BZ - 1), BAS, M.Basalt, { Collide = true })
        S(V(-30.5, H - 3, -4), V(1.5, 6, 10), BAS, M.Basalt, { Collide = true })
        S(V(BX + 0.5, H / 2, -7), V(1.5, H, 14), BAS, M.Basalt, { Collide = true })
        S(V(BX + 0.5, H / 2, (8 + BZ) / 2), V(1.5, H, BZ - 8), BAS, M.Basalt, { Collide = true })
        S(V(BX + 0.5, (11.2 + H) / 2, 4), V(1.5, H - 11.2, 8), BAS, M.Basalt, { Collide = true })
        for _, run in ipairs({ { -31, -6 }, { 30, BX + 1 } }) do
            S(V((run[1] + run[2]) / 2, H / 2, BZ + 0.5), V(run[2] - run[1], H, 1.5), BAS, M.Basalt, { Collide = true })
        end
        S(V(12, (12 + H) / 2, BZ + 0.5), V(36, H - 12, 1.5), BAS, M.Basalt, { Collide = true })
        for k = 0, 8 do -- (the arch's voussoirs)
            local a = k / 8 * math.pi
            S(V(12 + math.cos(a) * 18, 9 + math.sin(a) * 3, BZ + 0.1), V(4.6, 1.4, 2), BAS2, M.Basalt, { Rot = ANG(0, 0, a + math.pi / 2) })
        end
        -- NORTH wall: basalt sill + head, iron bars between (looking down on the lava river)
        local function Grille(x0: number, x1: number)
            local w, xc = x1 - x0, (x0 + x1) / 2
            S(V(xc, 1.5, -14.5), V(w, 3, 1.5), BAS, M.Basalt, { Collide = true })
            S(V(xc, (12 + H) / 2, -14.5), V(w, H - 12, 1.5), BAS, M.Basalt, { Collide = true })
            for x = x0 + 1, x1 - 0.5, 1.6 do S(V(x, 7.5, -14.5), V(9, 0.3, 0.3), IRON, M.Metal, { Shape = Cyl, Rot = ANG(0, 0, R(90)) }) end
            for _, y in ipairs({ 5, 10 }) do S(V(xc, y, -14.5), V(w, 0.35, 0.35), IRON, M.Metal) end
            Barrier(V(xc, 7.5, -14.5), V(w, 9, 0.6))
        end
        -- (2026-10-23) with the map room built the bays it backs onto are solid basalt (HideoutData.NorthRuns: the grilles
        -- used to look into the map room's side walls)
        local nRuns = HideoutData.NorthRuns(mapRoom)
        for _, r in ipairs(nRuns.Win) do Grille(r[1], r[2]) end
        for _, r in ipairs(nRuns.Solid) do S(V((r[1] + r[2]) / 2, H / 2, -14.5), V(r[2] - r[1], H, 1.5), BAS, M.Basalt, { Collide = true }) end
        -- buttresses + glowing veins
        for z = -8, BZ - 4, 10 do
            if z + 6 > 4 then S(V(-29.4, H / 2, z + 6), V(1.2, H, 2.6), BAS2, M.Basalt) end -- (none in front of the hearth)
            S(V(BX - 0.6, H / 2, z + 6), V(1.2, H, 2.6), BAS2, M.Basalt)
        end
        for i, v in ipairs({ { -29.6, 6, 12, 25 }, { -29.6, 9, 24, -30 }, { BX - 0.4, 7, 16, -20 }, { BX - 0.4, 10, 28, 35 } }) do
            Anim(S(V(v[1], v[2], v[3]), V(0.1, 5, 0.25), LAVA, M.Neon, { Rot = ANG(R(v[4]), 0, 0) }), "Pulse", { Amp = 0.5, Rate = 0.6, Phase = i })
        end
        -- the vault: a basalt ceiling, iron beams, chains with hooks swaying
        S(V(XM, H + 0.5, ZM), V(BX + 32, 1, BZ + 16), BAS, M.Basalt, { Collide = true, Roof = true })
        for x = -24, BX - 6, 12 do S(V(x, H - 0.7, ZM), V(1.2, 1.2, BZ + 14), IRON, M.Metal, { Roof = true }) end
        for i, x in ipairs({ -18, 6, 30 }) do
            local ch = S(V(x, H - 4.4, ZM - 4 + i * 3), V(0.25, 6, 0.25), IRON, M.Metal, { Roof = true })
            S(V(x, H - 7.6, ZM - 4 + i * 3), V(0.8, 0.8, 0.2), IRON, M.Metal, { Parent = ch })
            Anim(ch, "Sway", { Amp = 0.06, Hang = true, Phase = i })
        end
        -- three forge lanterns on chains from the beams (the hall's lights): iron cages round a living flame
        for i, x in ipairs({ -12, 12, 36 }) do
            S(V(x, H - 3.2, ZM), V(0.15, 6.4, 0.15), IRON, M.Metal, { Roof = true })
            local caged = FG("Lantern", V(x, H - 6.3, ZM), i * 40, 1.5)
            if not caged then
                S(V(x, H - 6.5, ZM), V(1.8, 0.3, 1.8), IRON, M.Metal)
                for _, o in ipairs({ V(0.8, 0, 0.8), V(-0.8, 0, 0.8), V(0.8, 0, -0.8), V(-0.8, 0, -0.8) }) do S(V(x, H - 7.6, ZM) + o, V(0.15, 2, 0.15), IRON, M.Metal) end
                S(V(x, H - 8.7, ZM), V(1.8, 0.3, 1.8), IRON, M.Metal)
            end
            local flame = S(V(x, caged and (H - 8.4) or (H - 7.6), ZM), caged and V(0.7, 1.15, 0.7) or V(0.9, 1.3, 0.9), EMBER, M.Neon, { T = 0.1, Shape = Ball })
            Anim(flame, "Pulse", { Amp = 0.25, Rate = 6, Phase = i * 2 })
            Light(flame, C(255, 170, 100), 42, 1.1)
        end
        -- THE HEARTH (recessed behind the west wall): a stone forge, its mouth full of fire, a hood + chimney, an anvil
        S(V(-34.5, H / 2, -9.5), V(8, H, 1), BAS, M.Basalt, { Collide = true })
        S(V(-34.5, H / 2, 1.5), V(8, H, 1), BAS, M.Basalt, { Collide = true })
        S(V(-38.5, H / 2, -4), V(1, H, 12), BAS, M.Basalt, { Collide = true })
        S(V(-34.5, H + 0.5, -4), V(9, 1, 12), BAS, M.Basalt, { Collide = true, Roof = true })
        S(V(-34.5, -0.5, -4), V(8, 1, 10), C(60, 52, 50), M.Slate, { Collide = true })
        S(V(-36.4, 2.2, -4), V(3.6, 4.4, 8), BAS2, M.Basalt, { Collide = true })
        -- the hearth's frame in the hall: two stone jambs, a lintel with a glowing seam, a lava sill
        for _, z in ipairs({ -9.6, 1.6 }) do S(V(-29.4, 6, z), V(1.6, 12, 1.8), BAS2, M.Basalt) end
        S(V(-29.4, 12.4, -4), V(1.8, 1.4, 13), BAS2, M.Basalt)
        Anim(S(V(-28.45, 12.4, -4), V(0.1, 0.25, 11), LAVA, M.Neon), "Pulse", { Amp = 0.3, Rate = 0.9 })
        S(V(-30, 0.06, -4), V(2.4, 0.12, 9), LAVA, M.Neon, { T = 0.35 })
        local coals = S(V(-34.55, 2.6, -4), V(0.2, 3.2, 7), LAVA, M.Neon)
        Anim(coals, "Pulse", { Amp = 0.25, Rate = 2.4 })
        if LavaFX then pcall(LavaFX.Panel, coals, Enum.NormalId.Right, { PPS = 40, Bright = 1.6 }) end -- (UPDATE 6: the molten bed of the fire)
        local fireAt = S(V(-35.6, 4.6, -4), V(1.6, 0.4, 4.4), LAVA, M.SmoothPlastic, { T = 1 })
        Flame(fireAt, 6, 9, EMBER, LAVA, "Idle")
        Light(coals, C(255, 140, 60), 36, 1.3)
        Fx(fireAt, "Idle", { Color = EMBER, Color2 = LAVA, Size = NS(0.1), Rate = 7, Speed = NumberRange.new(2, 4), Life = NumberRange.new(1.5, 2.5),
            Accel = V(0, 1.5, 0), Spread = Vector2.new(25, 25), Light = 1 })
        S(V(-36.6, 8.4, -4), V(3.6, 3, 8), IRON, M.Metal)
        S(V(-36.6, 13.5, -4), V(3, 8, 3.4), BAS2, M.Basalt)
        -- the anvil + a hammer, a quench barrel with steam
        local barrel
        if FG("Anvil", V(-32.4, 0, -1), 90) and FG("Barrel", V(-32.6, 0, -7.4), 200) then
            barrel = S(V(-32.6, 2.75, -7.4), V(1.4, 0.2, 1.4), C(96, 66, 42), M.SmoothPlastic, { T = 1 })
            FG("WeaponRack", V(-29.4, 0, 9), -90) -- (racks of fresh blades: by the hearth + on the east wall)
            FG("WeaponRack", V(BX - 0.4, 0, 20), 90)
        else
            S(V(-32.4, 0.9, -1), V(1.6, 1.8, 1.2), IRON, M.Metal)
            S(V(-32.4, 2.1, -1), V(1.4, 0.6, 3), C(70, 70, 76), M.Metal)
            S(V(-32.4, 2.1, 1.0), V(0.6, 0.6, 1.2), C(70, 70, 76), M.Metal, { Wedge = true, Rot = ANG(0, math.pi, 0) })
            S(V(-32.2, 2.6, -1.6), V(0.25, 0.25, 1.6), C(110, 80, 50), M.Wood, { Rot = ANG(R(30), 0, 0) })
            barrel = S(V(-32.6, 1.3, -7.4), V(2.4, 2.6, 2.6), C(96, 66, 42), M.WoodPlanks, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
        end
        Fx(barrel, "Idle", { Tex = "Smoke", Color = C(230, 220, 210), Size = NSK({ { 0, 0.5 }, { 1, 2 } }), Rate = 1.2, Speed = NumberRange.new(1, 2),
            Life = NumberRange.new(1.5, 2.5), Light = 0, T = NSK({ { 0, 1 }, { 0.3, 0.7 }, { 1, 1 } }), Dir = forgeV2 and Enum.NormalId.Top or Enum.NormalId.Right })
        -- the door: iron-banded slabs, rivets, a ring, EXIT in ember letters
        for k = 0, 3 do S(V(BX + 0.42, 5.6, 1 + k * 2), V(0.3, 11.2, 1.96), (k % 2 == 0) and C(70, 50, 36) or C(60, 44, 32), M.Wood) end
        for _, y in ipairs({ 1.5, 5.6, 9.7 }) do S(V(BX + 0.24, y, 4), V(0.12, 0.6, 7.6), IRON, M.Metal) end
        S(V(BX + 0.15, 5.4, 1.6), V(0.12, 1, 1), C(90, 86, 80), M.Metal, { Shape = Cyl })
        local exit = S(V(BX - 0.3, 12.6, 4), V(0.2, 1.2, 3.4), C(20, 12, 10), M.SmoothPlastic)
        Label(exit, Enum.NormalId.Left, "出口  EXIT", EMBER)
        -- THE PRACTICE ALCOVE: basalt walls, round iron shields as targets
        S(V(-34.5, H / 2, -26.5), V(1, H, 24), BAS, M.Basalt, { Collide = true })
        S(V(-13.5, H / 2, -26.5), V(1, H, 24), BAS, M.Basalt, { Collide = true })
        S(V(-24, H / 2, -38.5), V(22, H, 1), BAS, M.Basalt, { Collide = true })
        S(V(-24, H + 0.5, -27), V(22, 1, 24), BAS, M.Basalt, { Collide = true, Roof = true }) -- (z -39..-15: not over the hall's own)
        for _, x in ipairs({ -29, -19 }) do
            S(V(x, 6, -37.85), V(0.3, 4.4, 4.4), IRON, M.Metal, { Shape = Cyl, Rot = ANG(0, R(90), 0) })
            S(V(x, 6, -37.7), V(0.3, 2.6, 2.6), C(150, 40, 30), M.Metal, { Shape = Cyl, Rot = ANG(0, R(90), 0) })
            S(V(x, 6, -37.55), V(0.3, 1, 1), EMBER, M.Neon, { Shape = Cyl, Rot = ANG(0, R(90), 0) })
        end
        local psign = S(V(-22.5, 12, -13.7), V(9, 1.4, 0.25), C(20, 12, 10), M.SmoothPlastic)
        Label(psign, Enum.NormalId.Back, "PRACTICE  練習", EMBER)
        -- THE MAP ROOM: a basalt annex with rune-lit walls, or an iron portcullis
        if mapRoom then
            S(V(MR.X0 - 0.5, H / 2, MR.WZ), V(1, H, MR.WL), BAS, M.Basalt, { Collide = true })
            S(V(MR.X1 + 0.5, H / 2, MR.WZ), V(1, H, MR.WL), BAS, M.Basalt, { Collide = true })
            S(V(MXC, H / 2, MR.Z0 - 0.5), V(MR.X1 - MR.X0 + 2, H, 1), BAS, M.Basalt, { Collide = true })
            S(V(MXC, H + 0.5, MR.CZ), V(MR.X1 - MR.X0 + 3, 1, MR.CL), BAS, M.Basalt, { Collide = true, Roof = true })
            S(V(28, (12 + H) / 2, -14.5), V(MR.DoorX1 - MR.DoorX0, H - 12, 1.5), BAS, M.Basalt, { Collide = true })
            for i, z in ipairs({ -20, -28, -36 }) do
                for _, x in ipairs({ MR.X0, MR.X1 }) do
                    Anim(S(V(x + ((x == MR.X0) and 0.05 or -0.05), 7, z), V(0.1, 3, 0.3), EMBER, M.Neon), "Pulse", { Amp = 0.5, Rate = 0.8, Phase = i })
                end
            end
            local mapSign = S(V(28, 13, -13.7), V(9, 1.4, 0.25), C(20, 12, 10), M.SmoothPlastic)
            Label(mapSign, Enum.NormalId.Back, "MAP ROOM  地図室", EMBER)
        else
            S(V(28, (12 + H) / 2, -14.5), V(MR.DoorX1 - MR.DoorX0, H - 12, 1.5), BAS, M.Basalt, { Collide = true })
            for x = MR.DoorX0 + 0.75, MR.DoorX1 - 0.5, 1.5 do S(V(x, 6, -14.5), V(0.3, 12, 0.3), IRON, M.Metal, { Collide = true }) end
            for _, y in ipairs({ 3, 7, 11 }) do S(V(28, y, -14.5), V(12, 0.4, 0.4), IRON, M.Metal, { Collide = true }) end
            LockedSign(-14.1, EMBER)
        end
        -- THE BALCONY: iron posts with rails over the crater, two braziers
        for x = -30, BX, 6 do S(V(x, 1.8, BALZ), V(0.5, 3.6, 0.5), IRON, M.Metal) end
        for _, y in ipairs({ 1.6, 3.2 }) do S(V(XM, y, BALZ), V(BX + 30, 0.2, 0.2), IRON, M.Metal) end
        for _, x in ipairs({ -26, BX - 4 }) do
            local bowl
            if FG("Brazier", V(x, 0, BALZ - 2), x) then
                bowl = S(V(x, 2.6, BALZ - 2), V(1.6, 0.3, 1.6), IRON, M.SmoothPlastic, { T = 1 })
            else
                S(V(x, 0.9, BALZ - 2), V(1.8, 1.8, 1.8), IRON, M.Metal)
                bowl = S(V(x, 2.1, BALZ - 2), V(0.6, 2.6, 2.6), IRON, M.Metal, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
            end
            Flame(bowl, 4, 7, EMBER, LAVA, "Idle")
            Light(bowl, C(255, 140, 60), 26, 0.8)
        end
        -- OUTSIDE: the rock spire the hall stands on, the lava river past the north windows, the crater ring, lavafalls,
        -- the lava lake far below with crust plates, floating rocks, embers rising
        S(V(XM, -21, ZM), V(BX + 46, 40, BZ + 34), BAS, M.Basalt) -- (the city's street terrain is ~80 below: everything outside stays above y -42)
        -- (UPDATE 6, owner: "Lavaforge isnt using the updated lava"): the river, the lake and the falls are the Molten
        -- biome's LavaFX now (self-lit churning pools under drifting crust, flowing ribbons, streaming curtains with
        -- splash pools) on a CrackedLava crust; the old flat Neon slabs only stay as the fallback without LavaFX
        local lavaFX = LavaFX ~= nil
        if lavaFX then
            -- the river past the north windows: a basalt channel, molten rock flowing east in it
            S(V(XM, -12.4, -60), V(260, 1, 18), C(232, 220, 210), M.CrackedLava)
            LavaFX.Flow(f, O + V(XM - 130, -11.85, -60), O + V(XM + 130, -11.85, -60), 17, { Light = false, Smoke = false, Speed = 0.05, Name = "ForgeRiver" })
        else
            S(V(XM, -12, -60), V(260, 1, 20), LAVA, M.Neon, { T = 0.1 })
        end
        for _, z in ipairs({ -71, -49 }) do S(V(XM, -10, z), V(260, 6, 6), BAS2, M.Basalt) end
        if lavaFX then
            -- the lake: a crust of cracked lava with molten pools churning in it round the spire, rivers feeding it
            S(V(XM, -41, ZM), V(700, 2, 700), C(232, 220, 210), M.CrackedLava)
            for i, pl in ipairs({ { 0.4, 92, 44 }, { 1.35, 120, 52 }, { 2.3, 98, 40 }, { 3.2, 132, 56 }, { 4.15, 104, 46 }, { 5.2, 126, 50 } }) do
                local a = pl[1]
                LavaFX.Pool(f, CF(O + V(XM + math.cos(a) * pl[2], -39.9, ZM + math.sin(a) * pl[2])), pl[3],
                    { Light = false, Smoke = (i % 2 == 0), Sparks = (i % 3 == 0), Spin = 4, Name = "ForgeLake" })
                if i % 2 == 1 then -- (heat shimmer: a soft self-lit glow hanging over every other pool)
                    LavaFX.Glow(f, O + V(XM + math.cos(a) * pl[2], -30, ZM + math.sin(a) * pl[2]), pl[3] * 3.2, C(255, 96, 34), 0.62, { Name = "ForgeLakeGlow", Pulse = 0.05 })
                end
            end
        else
            S(V(XM, -41, ZM), V(700, 2, 700), C(170, 46, 14), M.Neon, { T = 0.1 })
        end
        local CRATER = { C(46, 38, 36), C(58, 48, 44), C(38, 32, 32) }
        for i = 0, 19 do
            local a = i / 20 * math.pi * 2
            local r = 230 + (i % 3) * 18
            local cx, cz = XM + math.cos(a) * r, ZM + math.sin(a) * r
            local h = 240 + ((i * 37) % 4) * 30
            S(V(cx, -50 + h / 2, cz), V(90, h, 50), CRATER[i % 3 + 1], M.Basalt, { Rot = ANG(0, -a + math.pi / 2, 0) * ANG(R(-10 - (i % 3) * 4), 0, 0) })
            S(V(XM + math.cos(a + 0.16) * (r - 30), -30 + (i % 4) * 10, ZM + math.sin(a + 0.16) * (r - 30)), V(40, 60, 40), CRATER[(i + 1) % 3 + 1], M.Basalt,
                { Rot = ANG(R(i * 9), i, R(i * 5)) })
            if i % 4 == 1 then -- (a lavafall: a thin bright core inside a soft glow, rim to lake, with a glowing pool at its foot)
                local fr, fa = r - 34, -a + math.pi / 2
                local fx, fz = XM + math.cos(a) * fr, ZM + math.sin(a) * fr
                if lavaFX then -- (UPDATE 6: a streaming LavaFX curtain off the rim, its splash pool on the crust, a river to the lake)
                    local inward = V(-math.cos(a), 0, -math.sin(a))
                    LavaFX.Fall(f, O + V(fx, 104, fz), O + V(fx, -40, fz), 12, inward, { Light = false, Speed = 0.7, Name = "ForgeFall" })
                    local foot = V(fx, -39.95, fz) + inward * 10
                    LavaFX.Flow(f, O + foot, O + foot + inward * 70, 9, { Light = false, Smoke = false, Sparks = false, Speed = 0.04, Name = "ForgeRun" })
                    continue
                end
                Anim(S(V(fx, 30, fz), V(3, 150, 0.8), C(255, 200, 80), M.Neon, { Rot = ANG(0, fa, 0) * ANG(R(-6), 0, 0) }), "Pulse", { Amp = 0.2, Rate = 1.6, Phase = i })
                S(V(fx, 30, fz), V(8, 150, 0.6), LAVA, M.Neon, { T = 0.55, Rot = ANG(0, fa, 0) * ANG(R(-6), 0, 0) })
                S(V(fx - math.cos(a) * 8, -39.5, fz - math.sin(a) * 8), V(30, 1, 22), C(255, 170, 60), M.Neon, { T = 0.3, Rot = ANG(0, fa, 0) })
            end
        end
        for i = 0, lavaFX and -1 or 55 do -- (crust plates: mostly dark crust, the lava glowing in the cracks between; LavaFX: the crust part does it)
            local a = i * 2.39996
            local r = 30 + math.sqrt(i) * 34
            S(V(XM + math.cos(a) * r, -39.8 + (i % 3) * 0.1, ZM + math.sin(a) * r), V(34 + (i % 4) * 10, 1, 28 + (i % 3) * 12), (i % 2 == 0) and C(34, 28, 28) or C(44, 34, 32), M.Basalt,
                { Rot = ANG(0, a * 1.7, 0) })
        end
        for i, p in ipairs({ V(-70, 10, -40), V(90, 18, 50), V(-60, 4, 70) }) do
            Anim(S(p, V(14 + i * 2, 8, 12), BAS2, M.Basalt, { Rot = ANG(R(i * 10), i, R(i * 7)) }), "Bob", { Amp = 2, Rate = 0.3 + i * 0.05 })
        end
        local emAt = { V(-24, -6, BALZ + 4), V(-6, -8, BALZ + 6), V(10, -6, BALZ + 3), V(30, -7, BALZ + 5), V(-4, -8, -20), V(6, -6, -22), V(44, -8, -20),
            V(-36, -8, 10), V(BX + 6, -6, 20), V(BX + 6, -8, -4), V(16, -6, BALZ + 8), V(48, -7, BALZ + 4) }
        for i, p in ipairs(emAt) do
            Anim(S(p, V(0.3, 0.3, 0.3), (i % 2 == 0) and EMBER or LAVA, M.Neon, { Shape = Ball }), "Rise", { Height = 40, Speed = 2.5 + (i % 3) * 0.8 })
        end
    elseif theme == "Starwhale" then
        -- ===== STARWHALE OBSERVATORY (0.89, owner: "more hideout ... skins", references: the premium hideouts of a big ARPG's
        -- shop -- original design): a walnut-and-brass observatory with a glass vault, riding the back of a star-whale that
        -- drifts through the night. Glass walls above a wood wainscot, a brass orrery turning under the vault, the TELESCOPE
        -- bay in the west recess (a star chart on its wall). Outside: the whale (glowing constellation spots, eyes, slow fins
        -- and flukes), a ringed planet and its moon, star jellies circling, a comet, motes drifting past.
        local WOOD, WOOD2, BRASS, NAVY, STAR = C(74, 48, 36), C(58, 38, 28), C(200, 154, 74), C(22, 28, 54), C(170, 205, 255)
        local GLASS, GT = C(170, 200, 235), 0.86
        local WHALE, BELLY, SPOT = C(34, 42, 94), C(84, 104, 168), C(110, 200, 255)
        local H, WH = 15, 4 -- (wall top, wainscot top)
        -- (UPDATE 6 pass 2, owner: "just looks like a box, can you just make it look infinite almost") OPEN DECK: the outer
        -- walls are a brass deck railing now (a low walnut kick, two brass rails on posts) with an invisible barrier above --
        -- no wainscot, glass panes, mullions or cap closing the view; axis "X" (at z) or "Z" (at x)
        local function Wall(axis: string, a0: number, a1: number, at: number)
            local len, mid = a1 - a0, (a0 + a1) / 2
            local function At(u: number, y: number, sx: number, sy: number, sz: number, col: Color3, mat: Enum.Material, o: any?): BasePart
                if axis == "X" then return S(V(u, y, at), V(sx, sy, sz), col, mat, o) end
                return S(V(at, y, u), V(sz, sy, sx), col, mat, o)
            end
            At(mid, 0.35, len, 0.7, 0.9, WOOD, M.WoodPlanks)
            At(mid, 3.5, len, 0.24, 0.36, BRASS, M.Metal)
            At(mid, 1.9, len, 0.12, 0.16, BRASS, M.Metal)
            At(mid, H / 2, len, H, 0.3, GLASS, M.SmoothPlastic, { T = 1, Collide = true })
            local n = math.max(1, math.floor(len / 4.5))
            for k = 0, n do At(a0 + len * k / n, 1.75, 0.3, 3.5, 0.3, BRASS, M.Metal) end
        end
        Wall("Z", -14, -9, -30.5); Wall("Z", 1, BZ, -30.5) -- west (the telescope bay between)
        Wall("Z", -14, 0, BX + 0.5); Wall("Z", 8, BZ, BX + 0.5) -- east (the door between)
        S(V(BX + 0.5, 12.2, 4), V(1.2, 2, 9.6), WOOD, M.WoodPlanks, { Collide = true }) -- (the door's lintel on two posts)
        for _, z in ipairs({ -0.4, 8.4 }) do S(V(BX + 0.5, 6.6, z), V(1.2, 13.2, 0.8), WOOD, M.WoodPlanks, { Collide = true }) end
        Wall("X", -14, MR.DoorX0, -14.5); Wall("X", MR.DoorX1, BX, -14.5) -- north (the alcove mouth + the map-room door)
        Wall("X", -30, -6, BZ + 0.5); Wall("X", 30, BX, BZ + 0.5) -- south (the balcony arch between)
        S(V(-30.5, (12 + H) / 2, -4), V(1.2, H - 12, 10), WOOD, M.WoodPlanks, { Collide = true }) -- (over the bay)
        -- THE VAULT (UPDATE 6 pass 2): an OPEN armillary dome -- seven brass ribs arching over the deck from rail to rail
        -- (curved posts carry them from the deck), the sky straight through; the old glass panes are an invisible roof
        local ZC, HW, RISE, N = (BZ - 14) / 2, (BZ + 14) / 2, 10, 8
        local function AP(th: number): (number, number) return ZC + HW * math.cos(th), H + 0.6 + RISE * math.sin(th) end
        local RIBS = { -30, -16, -2, 12, 26, 40, BX }
        for i = 0, N - 1 do
            local za, ya = AP(math.pi * i / N)
            local zb, yb = AP(math.pi * (i + 1) / N)
            SegX(-30.6, BX + 0.6, za, ya, zb, yb, 0.3, GLASS, M.SmoothPlastic, { T = 1, Collide = true, Roof = true })
            for _, x in ipairs(RIBS) do SegX(x - 0.3, x + 0.3, za, ya, zb, yb, 0.5, BRASS, M.Metal, { Roof = true }, 0.3) end
        end
        for _, x in ipairs(RIBS) do -- (each rib stands on two slim posts at the rail)
            for _, z in ipairs({ -14.3, BZ + 0.3 }) do S(V(x, (3.5 + H + 0.6) / 2, z), V(0.35, H + 0.6 - 3.5, 0.35), BRASS, M.Metal) end
        end
        for _, x in ipairs({ -30.6, BX + 0.6 }) do -- (the vault's end walls: invisible)
            for i = 0, N - 1 do
                local za, ya = AP(math.pi * (i + 0.5) / N)
                S(V(x, (H + ya) / 2 + 0.3, za), V(0.3, ya - H, HW * 2 / N + 0.6), GLASS, M.SmoothPlastic, { T = 1, Collide = true, Roof = true })
            end
        end
        -- THE ORRERY under the ridge: a gold sun, three planets on turning arms, a brass ring (the hall's centre light)
        do
            local B = Anchored(CF(12, 19.5, ZC))
            B(CF(0, 3, 0), V(0.15, 5, 0.15), BRASS, M.Metal)
            local sun = B(CF(), V(2.2, 2.2, 2.2), C(255, 200, 90), M.Neon, { Shape = Ball, Anim = { "Pulse", { Amp = 0.15, Rate = 0.7 } } })
            Light(sun, C(255, 214, 160), 44, 0.9)
            Hoop(B, CF() * ANG(R(90), 0, 0), 5.5, 16, 0.18, BRASS, M.Metal, 0.12, "Z")
            for k, pl in ipairs({ { 3.6, 0.7, C(120, 190, 255), 0.5 }, { 5.5, 1.0, C(230, 120, 80), -0.32 }, { 7.6, 1.3, C(200, 170, 255), 0.2 } }) do
                local hub = B(CF(), V(0.2, 0.2, 0.2), BRASS, M.Metal, { T = 1, Anim = { "Spin", { Rate = pl[4] } } })
                local arm = B(CF(pl[1] / 2, -0.2, 0), V(pl[1], 0.12, 0.12), BRASS, M.Metal); arm.Parent = hub
                local p = B(CF(pl[1], -0.2, 0), V(pl[2], pl[2], pl[2]), pl[3], M.SmoothPlastic, { Shape = Ball }); p.Parent = hub
                if k == 3 then local rg = B(CF(pl[1], -0.2, 0) * ANG(R(20), 0, R(90)), V(0.1, 2.4, 2.4), C(230, 210, 170), M.SmoothPlastic, { Shape = Cyl, T = 0.4 }); rg.Parent = hub end
            end
        end
        -- two star lanterns (brass cages round a pale-blue star)
        for i, x in ipairs({ -16, 40 }) do -- (hung from the ribs' crowns)
            S(V(x, (H - 4 + H + 0.6 + RISE) / 2, ZC), V(0.12, RISE + 4.6, 0.12), BRASS, M.Metal, { Roof = true })
            S(V(x, H - 4, ZC), V(1.6, 0.2, 1.6), BRASS, M.Metal)
            S(V(x, H - 6.2, ZC), V(1.6, 0.2, 1.6), BRASS, M.Metal)
            for _, o in ipairs({ V(0.7, 0, 0.7), V(-0.7, 0, 0.7), V(0.7, 0, -0.7), V(-0.7, 0, -0.7) }) do S(V(x, H - 5.1, ZC) + o, V(0.12, 2.2, 0.12), BRASS, M.Metal) end
            local st = S(V(x, H - 5.1, ZC), V(0.9, 0.9, 0.9), STAR, M.Neon, { Shape = Ball })
            Anim(st, "Pulse", { Amp = 0.2, Rate = 1.2, Phase = i * 2 })
            Light(st, C(190, 210, 255), 34, 0.7)
        end
        -- THE TELESCOPE BAY (west recess, z -9..1): walnut walls, a glass roof, a great brass telescope on a turning mount
        -- aimed up through it, a glowing star chart on the back wall
        S(V(-34.5, WH / 2, -9.5), V(8, WH, 1), WOOD, M.WoodPlanks, { Collide = true })
        S(V(-34.5, WH / 2, 1.5), V(8, WH, 1), WOOD, M.WoodPlanks, { Collide = true })
        S(V(-34.5, (WH + H) / 2, -9.5), V(8, H - WH, 0.3), GLASS, M.SmoothPlastic, { T = GT, Collide = true })
        S(V(-34.5, (WH + H) / 2, 1.5), V(8, H - WH, 0.3), GLASS, M.SmoothPlastic, { T = GT, Collide = true })
        S(V(-38.5, H / 2, -4), V(1, H, 12), NAVY, M.SmoothPlastic, { Collide = true })
        S(V(-34.5, H + 0.4, -4), V(9, 0.3, 12), GLASS, M.SmoothPlastic, { T = GT, Collide = true, Roof = true })
        S(V(-34.5, -0.5, -4), V(8, 1, 10), WOOD2, M.WoodPlanks, { Collide = true })
        for i, st in ipairs({ { -7, 11 }, { -5.2, 12.6 }, { -3, 11.8 }, { -1.6, 9.6 }, { 0, 10.6 }, { -4, 8.2 }, { -6, 7.4 } }) do -- (the chart: a constellation)
            Anim(S(V(-37.9, st[2], st[1]), V(0.1, 0.35, 0.35), STAR, M.Neon, { Shape = Ball }), "Pulse", { Amp = 0.5, Rate = 0.6 + i * 0.1, Phase = i })
        end
        local chart = { { -7, 11 }, { -5.2, 12.6 }, { -3, 11.8 }, { -1.6, 9.6 }, { 0, 10.6 }, { -4, 8.2 }, { -6, 7.4 } }
        for _, ln in ipairs({ { 1, 2 }, { 2, 3 }, { 3, 5 }, { 5, 4 }, { 3, 6 }, { 6, 7 } }) do
            local a, b = chart[ln[1]], chart[ln[2]]
            local pa, pb = V(-37.95, a[2], a[1]), V(-37.95, b[2], b[1])
            SC(CF((pa + pb) / 2, pb) , V(0.05, 0.08, (pb - pa).Magnitude), C(140, 170, 230), M.Neon, { T = 0.45 })
        end
        if Kit and Kit.Place(f, "Starwhale", "Telescope", CF(O + V(-34.5, 0, -4)) * ANG(0, R(90), 0)) then
            -- (the real telescope stands in the bay)
        else
            local mount = S(V(-34.5, 1.6, -4), V(1.2, 3.2, 1.2), BRASS, M.Metal)
            for k = 0, 2 do S(V(-34.5, 1.2, -4) + V(math.cos(k * 2.09) * 1.3, 0, math.sin(k * 2.09) * 1.3), V(0.25, 2.6, 0.25), WOOD2, M.Wood, { Rot = ANG(R(math.sin(k * 2.09) * -20), 0, R(math.cos(k * 2.09) * 20)) }) end
            local hub = S(V(-34.5, 3.4, -4), V(0.6, 0.6, 0.6), BRASS, M.Metal, { Shape = Ball })
            Anim(hub, "Sway", { Amp = 0.12 })
            local tube = SC(CF(V(-34.5, 3.4, -4)) * ANG(0, R(-30), 0) * ANG(R(-55), 0, 0) * CF(0, 0, -2.5) * ANG(R(90), 0, 0), V(1.1, 9, 1.1), BRASS, M.Metal, { Shape = Cyl })
            tube.Parent = hub
            local cap = SC(CF(V(-34.5, 3.4, -4)) * ANG(0, R(-30), 0) * ANG(R(-55), 0, 0) * CF(0, 0, -7) * ANG(R(90), 0, 0), V(0.2, 1.5, 1.5), WOOD2, M.Wood, { Shape = Cyl })
            cap.Parent = hub
            local lens = SC(CF(V(-34.5, 3.4, -4)) * ANG(0, R(-30), 0) * ANG(R(-55), 0, 0) * CF(0, 0, 2.05) * ANG(R(90), 0, 0), V(0.1, 0.8, 0.8), STAR, M.Neon, { Shape = Cyl })
            lens.Parent = hub
            local _ = mount
        end
        -- the door: walnut planks, brass bands + a ring, EXIT over it
        for k = 0, 3 do S(V(BX + 0.42, 5.6, 1 + k * 2), V(0.3, 11.2, 1.96), (k % 2 == 0) and WOOD or WOOD2, M.WoodPlanks) end
        for _, y in ipairs({ 1.5, 5.6, 9.7 }) do S(V(BX + 0.24, y, 4), V(0.12, 0.4, 7.6), BRASS, M.Metal) end
        S(V(BX + 0.15, 5.4, 1.6), V(0.12, 1, 1), BRASS, M.Metal, { Shape = Cyl })
        local exit = S(V(BX - 0.3, 12.6, 4), V(0.2, 1.2, 3.4), NAVY, M.SmoothPlastic)
        Label(exit, Enum.NormalId.Left, "出口  EXIT", STAR)
        -- THE PRACTICE ALCOVE: walnut walls under glass, brass star targets
        S(V(-34.5, H / 2, -26.5), V(1, H, 24), WOOD, M.WoodPlanks, { Collide = true })
        S(V(-13.5, H / 2, -26.5), V(1, H, 24), WOOD, M.WoodPlanks, { Collide = true })
        S(V(-24, H / 2, -38.5), V(22, H, 1), WOOD, M.WoodPlanks, { Collide = true })
        S(V(-24, H + 0.4, -26), V(22, 0.3, 26), GLASS, M.SmoothPlastic, { T = GT, Collide = true, Roof = true })
        for _, x in ipairs({ -29, -19 }) do
            S(V(x, 6, -37.85), V(0.3, 4.4, 4.4), BRASS, M.Metal, { Shape = Cyl, Rot = ANG(0, R(90), 0) })
            S(V(x, 6, -37.7), V(0.3, 2.8, 2.8), NAVY, M.SmoothPlastic, { Shape = Cyl, Rot = ANG(0, R(90), 0) })
            for k = 0, 4 do S(V(x, 6, -37.55) + V(math.cos(k * 1.2566 + R(90)) * 0.7, math.sin(k * 1.2566 + R(90)) * 0.7, 0), V(0.35, 1.2, 0.1), STAR, M.Neon,
                { Rot = ANG(0, 0, k * 1.2566) }) end
        end
        local psign = S(V(-22.5, 12, -13.7), V(9, 1.4, 0.25), NAVY, M.SmoothPlastic)
        Label(psign, Enum.NormalId.Back, "PRACTICE  練習", STAR)
        -- THE MAP ROOM: a walnut annex under glass, or a brass lattice gate
        if mapRoom then
            S(V(MR.X0 - 0.5, H / 2, MZC), V(1, H, -14 - MR.Z0), WOOD, M.WoodPlanks, { Collide = true })
            S(V(MR.X1 + 0.5, H / 2, MZC), V(1, H, -14 - MR.Z0), WOOD, M.WoodPlanks, { Collide = true })
            S(V(MXC, H / 2, MR.Z0 - 0.5), V(MR.X1 - MR.X0 + 2, H, 1), WOOD, M.WoodPlanks, { Collide = true })
            S(V(MXC, H + 0.4, MZC), V(MR.X1 - MR.X0 + 3, 0.3, -14 - MR.Z0 + 2), GLASS, M.SmoothPlastic, { T = GT, Collide = true, Roof = true })
            S(V(28, 13.2, -14.5), V(MR.DoorX1 - MR.DoorX0 + 1.6, 2.4, 1.2), WOOD, M.WoodPlanks, { Collide = true }) -- (a doorframe: lintel on posts)
            for _, x in ipairs({ MR.DoorX0 - 0.4, MR.DoorX1 + 0.4 }) do S(V(x, 6.6, -14.5), V(0.8, 13.2, 1.2), WOOD, M.WoodPlanks, { Collide = true }) end
            local mapSign = S(V(28, 13, -13.7), V(9, 1.4, 0.25), NAVY, M.SmoothPlastic)
            Label(mapSign, Enum.NormalId.Back, "MAP ROOM  地図室", STAR)
        else
            S(V(28, (12 + H) / 2, -14.5), V(MR.DoorX1 - MR.DoorX0, H - 12, 1.2), WOOD, M.WoodPlanks, { Collide = true })
            for x = MR.DoorX0 + 1, MR.DoorX1 - 0.5, 2 do S(V(x, 6, -14.5), V(0.25, 12, 0.25), BRASS, M.Metal, { Collide = true }) end
            for _, y in ipairs({ 2, 6, 10 }) do S(V(28, y, -14.5), V(12, 0.3, 0.3), BRASS, M.Metal, { Collide = true }) end
            LockedSign(-14.1, STAR)
        end
        -- THE BALCONY: brass rails, two star-globe lamps
        for x = -30, BX, 6 do S(V(x, 1.8, BALZ), V(0.35, 3.6, 0.35), BRASS, M.Metal) end
        for _, y in ipairs({ 1.6, 3.3 }) do S(V(XM, y, BALZ), V(BX + 30, 0.18, 0.18), BRASS, M.Metal) end
        for i, x in ipairs({ -26, BX - 4 }) do
            S(V(x, 2.2, BALZ - 2), V(0.3, 4.4, 0.3), BRASS, M.Metal)
            local g = S(V(x, 4.8, BALZ - 2), V(1.2, 1.2, 1.2), STAR, M.Neon, { Shape = Ball, T = 0.15 })
            Anim(g, "Pulse", { Amp = 0.2, Rate = 0.9, Phase = i })
            Light(g, C(170, 200, 255), 22, 0.6)
        end
        -- OUTSIDE: the deck the observatory stands on, strapped to the STARWHALE's back
        S(V(12, -1.6, 0), V(104, 2, 92), WOOD2, M.WoodPlanks)
        for _, z in ipairs({ -46, 46 }) do S(V(12, -1.6, z), V(104, 2.2, 0.6), BRASS, M.Metal) end
        for _, x in ipairs({ -40, 64 }) do S(V(x, -1.6, 0), V(0.6, 2.2, 92), BRASS, M.Metal) end
        -- (UPDATE 4) STARWHALE v2: a real star whale under the deck (HideoutKit.Starwhale.Whale, pivot = the point of its
        -- back the deck rests on; fins + flukes hinged), else the primitive whale
        -- (UPDATE 6, owner: "Starwhale observatory is broken, whale clips in"): the whale's back is a curve (the head end and
        -- the raised flukes rise ~6 / ~28 studs over the point the deck used to rest on), so the hump came up through the
        -- floor and the flukes through the telescope bay. It is drawn at 0.78 and 10.4 studs lower now: measured, no part of
        -- it reaches the deck's underside (-2.6) anywhere under the deck, the flukes rise only past the west end (x < -43),
        -- and the deck stands on a SADDLE (timber legs + brass bands on leather pads, the length of its back, cut to the
        -- back by rays) with harness straps from the deck edge down round its flanks
        local WS = 0.78
        local whale = Kit and Kit.Creature(f, "Starwhale", "Whale", CF(O + V(16, -11.8, 2)) * ANG(0, R(-90), 0), WS,
            { Flap = { ["left fin"] = { "Z", 0.14, 0.55 }, ["right fin"] = { "Z", -0.14, 0.55 }, ["tail flukes"] = { "X", 0.12, 0.45 } } })
        if whale then
            Anim(whale, "Bob", STILL)
            -- where its back is under a point (rays at the real mesh: the carrier goes into the workspace for a moment)
            local meshes = {}
            for _, c in ipairs(whale:GetChildren()) do if c:IsA("BasePart") then c.CanQuery = true; table.insert(meshes, c) end end
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Include
            rp.FilterDescendantsInstances = meshes
            local held = whale.Parent
            whale.Parent = workspace
            local function BackY(x: number, z: number, def: number): number
                local r = workspace:Raycast(O + V(x, 20, z), V(0, -70, 0), rp)
                return r and math.clamp(r.Position.Y - O.Y, -26, -3.4) or def
            end
            local SADDLE, PAD, STRAP = C(58, 40, 30), C(40, 26, 22), C(46, 30, 24)
            for _, z in ipairs({ -9, 9 }) do S(V(12, -3.3, z), V(104, 1.3, 1.6), SADDLE, M.Wood) end -- (the two sills under the deck)
            for i, x in ipairs({ -26, 4, 34, 56 }) do
                S(V(x, -3.3, 0), V(1.4, 1.2, 19.6), SADDLE, M.Wood) -- (a cross-tie between the sills)
                local foot = {}
                for _, z in ipairs({ -9, 9 }) do
                    local by = BackY(x, z, -12) - 0.7 -- (sunk a little into the hide)
                    local len = -3.9 - by
                    S(V(x, by + len / 2, z), V(1.3, len, 1.3), SADDLE, M.Wood)
                    S(V(x, -4.3, z), V(1.6, 0.4, 1.6), BRASS, M.Metal)
                    S(V(x, by + 1.1, z), V(1.6, 0.4, 1.6), BRASS, M.Metal)
                    S(V(x, by + 0.55, z), V(3.6, 0.5, 3.2), PAD, M.Fabric) -- (the leather pad on its back)
                    foot[z] = by
                end
                if i == 2 or i == 3 then -- (cross bracing on the middle legs)
                    local a, b = V(x, -4.2, -9), V(x, foot[9] + 1.6, 9)
                    SC(CF((a + b) / 2, b) , V(0.25, 0.25, (b - a).Magnitude), BRASS, M.Metal)
                    a, b = V(x, -4.2, 9), V(x, foot[-9] + 1.6, -9)
                    SC(CF((a + b) / 2, b), V(0.25, 0.25, (b - a).Magnitude), BRASS, M.Metal)
                end
            end
            -- the harness: straps from brass cleats on the deck edge, taut down round its flanks
            for _, x in ipairs({ -18, 44 }) do
                for _, s in ipairs({ -1, 1 }) do
                    local top = V(x, -2.4, s * 46.4)
                    local low = V(x, BackY(x, s * 18, -16) - 7, s * 20)
                    SC(CF((top + low) / 2, low), V(1.4, 0.25, (low - top).Magnitude), STRAP, M.Fabric)
                    S(top + V(0, 0.4, -s * 0.2), V(2, 0.8, 0.8), BRASS, M.Metal)
                end
            end
            whale.Parent = held
            for _, c in ipairs(meshes) do c.CanQuery = false end
        else
            local WC = V(16, -19, 2) -- (the whale's middle; it runs along X, its head east)
            S(WC, V(330, 36, 124), WHALE, M.SmoothPlastic, { Shape = Ball })
            S(WC + V(10, -9, 0), V(300, 22, 112), BELLY, M.SmoothPlastic, { Shape = Ball })
            for _, x in ipairs({ -18, 42 }) do -- (harness straps over its back)
                for _, sz in ipairs({ -1, 1 }) do S(V(x, -10, sz * 55), V(3, 18, 0.6), C(60, 40, 30), M.Fabric, { Rot = ANG(R(sz * 28), 0, 0) }) end
            end
            -- the head: two glowing eyes, a long mouth line, throat grooves
            for _, sz in ipairs({ -1, 1 }) do
                local e = S(V(150, -15, sz * 33), V(4.5, 4.5, 4.5), C(170, 230, 255), M.Neon, { Shape = Ball })
                Anim(e, "Pulse", { Amp = 0.25, Rate = 0.35 })
                S(V(151.5, -15, sz * 35), V(1.6, 2.2, 1.6), C(14, 18, 40), M.SmoothPlastic, { Shape = Ball })
                S(V(150, -25, sz * 30), V(46, 0.8, 1), C(18, 22, 50), M.SmoothPlastic, { Rot = ANG(0, R(sz * -12), R(-6)) })
                for g = 0, 3 do S(V(130 - g * 6, -33 + g * 0.6, sz * (14 + g * 3)), V(18, 0.6, 0.6), C(64, 80, 140), M.SmoothPlastic, { Rot = ANG(0, R(sz * 70), 0) }) end
            end
            -- constellation spots along its flanks and back (a slow twinkle)
            for i = 0, 25 do
                local u = -0.82 + (i % 13) * 0.13
                local side = (i < 13) and 1 or -1
                local th = R(40 + (i * 37) % 50)
                local rx = u * 165
                local f2 = math.sqrt(math.max(0, 1 - u * u))
                local p = WC + V(rx, math.sin(th) * 18 * f2, side * math.cos(th) * 62 * f2)
                if math.abs(p.Z) > 48 or p.Y < -6 then
                    Anim(S(p, V(1.6, 1.6, 1.6) * (0.6 + (i % 3) * 0.3), SPOT, M.Neon, { Shape = Ball }), "Pulse", { Amp = 0.6, Rate = 0.5 + (i % 4) * 0.2, Phase = i * 1.7 })
                end
            end
            -- pectoral fins (flap slowly) + the tail with its flukes (beat up and down)
            for _, sz in ipairs({ -1, 1 }) do
                local hub = S(V(70, -28, sz * 52), V(0.4, 0.4, 0.4), WHALE, M.SmoothPlastic, { T = 1 })
                Anim(hub, "Bob", { Amp = 0.01, Rate = 0.1, NoTurn = true })
                local fin = S(V(70, -30, sz * 70), V(26, 1.4, 34), WHALE, M.SmoothPlastic, { Shape = Ball, Rot = ANG(0, R(sz * 20), R(sz * -8)) })
                fin.Parent = hub
                Hinge(fin, V(0, 0, 0), "X", 0.22, 0.7) -- (the fin turns about its root at the hub)
            end
            S(V(-170, -14, 2), V(90, 22, 34), WHALE, M.SmoothPlastic, { Shape = Ball })
            do
                local hub = S(V(-210, -12, 2), V(0.4, 0.4, 0.4), WHALE, M.SmoothPlastic, { T = 1 })
                Anim(hub, "Bob", { Amp = 3, Rate = 0.5, NoTurn = true })
                for _, sz in ipairs({ -1, 1 }) do
                    local fl = S(V(-222, -12, 2 + sz * 20), V(30, 1.6, 34), WHALE, M.SmoothPlastic, { Shape = Ball, Rot = ANG(0, R(sz * -25), 0) })
                    fl.Parent = hub
                    Hinge(fl, V(0, 0, 0), "Z", 0.2, 0.5)
                    Anim(S(V(-226, -11, 2 + sz * 24), V(1.4, 1.4, 1.4), SPOT, M.Neon, { Shape = Ball }), "Pulse", { Amp = 0.5, Rate = 0.6 })
                end
            end
        end
        -- the sky: a ringed planet + its moon far off, star jellies circling the whale, a comet, motes drifting by
        do
            local pc = V(-420, 150, -520)
            S(pc, V(170, 170, 170), C(214, 150, 120), M.SmoothPlastic, { Shape = Ball })
            S(pc + V(-30, 40, 30), V(120, 30, 120), C(230, 180, 150), M.SmoothPlastic, { Shape = Ball, T = 0.3 })
            local B = Anchored(CF(pc) * ANG(R(70), R(20), 0))
            Hoop(B, CF(), 150, 36, 10, C(230, 200, 160), M.SmoothPlastic, 0.02, "Z")
            S(V(380, 240, -360), V(50, 50, 50), C(200, 210, 230), M.SmoothPlastic, { Shape = Ball })
        end
        for i = 0, 3 do
            local j = Kit and Kit.Creature(f, "Aquarium", "Jellyfish", CF(O + V(XM, 10, 0)), 2.4, {})
            if not j then
                j = S(V(XM, 10, 0), V(3, 2.4, 3), C(170, 140, 255), M.Neon, { Shape = Ball, T = 0.3 })
                for k = 0, 3 do
                    local tn = S(V(XM + math.cos(k * 1.57) * 0.8, 7.6, math.sin(k * 1.57) * 0.8), V(0.15, 4, 0.15), C(200, 180, 255), M.Neon, { T = 0.5 })
                    tn.Parent = j
                end
            end
            Anim(j, "Orbit", { Center = O + V(XM + 10, 8 + i * 5, 2), RX = 120 + i * 12, RZ = 90 + i * 8, Speed = 5 + i, Phase = i * 1.6, Bob = 2, Dir = (i % 2 == 0) and 1 or -1 })
        end
        Anim(S(V(XM, 120, 0), V(1.4, 1.4, 22), C(220, 240, 255), M.Neon, { T = 0.1 }), "Orbit", { Center = O + V(XM, 160, 0), RX = 700, RZ = 600, Speed = 70, Phase = 0.5, Bob = 30 })
        for i, p in ipairs({ V(-40, 6, 60), V(30, 12, 64), V(80, 4, 58), V(-60, 14, -54), V(20, 10, -60), V(90, 16, -50), V(-80, 8, 20), V(120, 10, 30) }) do
            Anim(S(p, V(0.35, 0.35, 0.35), (i % 2 == 0) and STAR or C(255, 220, 160), M.Neon, { Shape = Ball }), "Firefly", { Speed = 0.3 + (i % 3) * 0.15 })
        end
        if not whale then
            S(V(XM, -41, ZM), V(900, 2, 900), C(6, 8, 20), M.SmoothPlastic) -- (the old flat deep-space floor: only for the primitive whale)
        else
            -- (UPDATE 6, owner: "outside looks unfinished"): no flat floor any more -- the painted deep-space sky
            -- (BiomeSkies.HideoutStarwhale: stars, milky way, a cobalt / teal nebula, below the horizon too) is all round,
            -- with life far out in it: a pod of star whales swimming past, nebula gas drifting under the whale, soft
            -- glows round the planet and the moon. (The city below is parked while you're in here; only its invisible
            -- baseplate stays.)
            local low = Kit.Low()
            for i, pod in ipairs({ { 520, 60, 0.0, 0.34, 7 }, { 600, 95, 2.3, 0.26, 6 }, { 470, -30, 4.1, 0.22, 8 } }) do
                if low and i > 1 then break end
                local pw = Kit.Creature(f, "Starwhale", "Whale", CF(O + V(XM, pod[2], 0)), pod[4],
                    { Flap = { ["left fin"] = { "Z", 0.2, 0.5 }, ["right fin"] = { "Z", -0.2, 0.5 }, ["tail flukes"] = { "X", 0.25, 0.5 } } })
                if pw then
                    Anim(pw, "Orbit", { Center = O + V(XM, pod[2], ZM), RX = pod[1], RZ = pod[1] * 0.8, Speed = pod[5], Phase = pod[3], Bob = 6, Dir = (i % 2 == 0) and -1 or 1 })
                end
            end
            if LavaFX then -- (LavaFX.Glow = a self-lit soft glow sprite: an atmosphere on the planet, a halo on the moon)
                LavaFX.Glow(f, O + V(-420, 150, -520), 330, C(120, 170, 255), 0.55, { Name = "PlanetGlow" })
                LavaFX.Glow(f, O + V(380, 240, -360), 110, C(200, 215, 255), 0.6, { Name = "MoonGlow" })
                for i, gp in ipairs({ V(-160, -55, 120), V(170, -62, -60), V(40, -66, 220), V(-220, -48, -180), V(260, -58, 150) }) do
                    LavaFX.Glow(f, O + gp, 260 + (i % 3) * 60, (i % 2 == 0) and C(60, 150, 200) or C(90, 80, 210), 0.78, { Name = "NebulaGas", Pulse = 0.03 })
                end
            end
            -- (UPDATE 6 pass 2, owner: "make it look infinite almost") DEEP SPACE IN LAYERS round the open deck: two shells of
            -- stars streaming slowly west past the whale (it swims east; the nearer shell faster = parallax), close motes
            -- now and then, two more far whales and two far worlds fading into the haze (FogStart 500 / FogEnd 1500), and
            -- shooting stars crossing every few seconds. All sprites / a handful of parts, no lights; Low keeps the far worlds.
            if not low then
                for _, sh in ipairs({ { 320, 4, 1.8, 7, 50 }, { 700, 2, 4.2, 4, 80 } }) do -- { half-size, rate, size, speed, life }
                    local shell = S(V(XM, 0, ZM), V(sh[1] * 2, sh[1] * 1.2, sh[1] * 2), C(0, 0, 0), M.SmoothPlastic, { T = 1, Name = "StarShell" })
                    Fx(shell, "Idle", { Tex = "Spark", Color = C(205, 222, 255), Color2 = C(255, 236, 214), Size = NS(sh[3]), Rate = sh[2],
                        Life = NumberRange.new(sh[5], sh[5] * 1.3), Speed = NumberRange.new(sh[4], sh[4] * 1.4), Spread = Vector2.new(3, 3),
                        Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Dir = Enum.NormalId.Left,
                        Light = 1, RotSpeed = NumberRange.new(-8, 8), T = NSK({ { 0, 1 }, { 0.12, 0.15 }, { 0.88, 0.15 }, { 1, 1 } }) })
                end
                local motes = S(V(XM, 6, ZM), V(220, 60, 200), C(0, 0, 0), M.SmoothPlastic, { T = 1, Name = "StarMotes" })
                Fx(motes, "Idle", { Tex = "Glow", Color = C(170, 200, 255), Size = NS(0.35), Rate = 2, Life = NumberRange.new(14, 18),
                    Speed = NumberRange.new(12, 16), Spread = Vector2.new(2, 2), Shape = Enum.ParticleEmitterShape.Box, Dir = Enum.NormalId.Left, Light = 1,
                    T = NSK({ { 0, 1 }, { 0.1, 0.35 }, { 0.9, 0.35 }, { 1, 1 } }) })
                for i, pod in ipairs({ { 1100, 150, 1.2, 0.2, 4 }, { 1250, -140, 3.6, 0.16, 3 } }) do
                    local pw = Kit.Creature(f, "Starwhale", "Whale", CF(O + V(XM, pod[2], 0)), pod[4],
                        { Flap = { ["left fin"] = { "Z", 0.2, 0.4 }, ["right fin"] = { "Z", -0.2, 0.4 }, ["tail flukes"] = { "X", 0.25, 0.4 } } })
                    if pw then
                        Anim(pw, "Orbit", { Center = O + V(XM, pod[2], ZM), RX = pod[1], RZ = pod[1] * 0.85, Speed = pod[5], Phase = pod[3], Bob = 10, Dir = (i % 2 == 0) and 1 or -1 })
                    end
                end
                for i, st in ipairs({ { 520, 820, 150, 0.0 }, { 760, 480, -40, 2.1 }, { 640, 640, 260, 4.0 } }) do -- (shooting stars)
                    local m = S(V(XM, st[3], 0), V(0.8, 0.8, 18), C(225, 238, 255), M.Neon, { T = 0.05, Name = "Meteor" })
                    Anim(m, "Orbit", { Center = O + V(XM, st[3], ZM), RX = st[1], RZ = st[2], Speed = 150 + i * 30, Phase = st[4], Bob = 40, Dir = (i % 2 == 0) and -1 or 1 })
                end
            end
            S(V(980, -90, 760), V(70, 70, 70), C(64, 96, 128), M.SmoothPlastic, { Shape = Ball, Name = "FarWorld" }) -- (an ice giant, dim: far off)
            S(V(-760, 320, 960), V(34, 34, 34), C(200, 120, 96), M.SmoothPlastic, { Shape = Ball, Name = "FarWorld" }) -- (a small red moon)
            if LavaFX then
                LavaFX.Glow(f, O + V(980, -90, 760), 150, C(120, 180, 230), 0.7, { Name = "FarGlow" })
                LavaFX.Glow(f, O + V(-760, 320, 960), 80, C(240, 150, 120), 0.66, { Name = "FarGlow" })
            end
            -- (UPDATE 6 pass 2) NO FLOOR: the hub's terrain ~80 below is cleared on this client while you're in here
            -- (AimRngClient's hub parking, pasted back when you leave), so the painted sky runs all the way down. (Before:
            -- a 2400-stud plane with the sky's Dn face on it -- it read as a starry carpet with a horizon line.)
            if not low then -- (the ABYSS: stars far out below the deck, drifting with the rest, so the void's horizon is starry --
                -- none right under the deck, where the nebula banks glow)
                for _, o in ipairs({ V(0, 0, 600), V(0, 0, -600), V(600, 0, 0), V(-600, 0, 0) }) do
                    local strip = S(V(XM, -70, ZM) + o, (o.X ~= 0) and V(500, 4, 1700) or V(1700, 4, 500), C(0, 0, 0), M.SmoothPlastic, { T = 1, Name = "AbyssStars" })
                    Fx(strip, "Idle", { Tex = "Spark", Color = C(190, 210, 255), Color2 = C(255, 230, 210), Size = NS(3.2), Rate = 1.5, Life = NumberRange.new(45, 60),
                        Speed = NumberRange.new(4, 6), Spread = Vector2.new(3, 3), Shape = Enum.ParticleEmitterShape.Box, Dir = Enum.NormalId.Left, Light = 1,
                        T = NSK({ { 0, 1 }, { 0.12, 0.2 }, { 0.88, 0.2 }, { 1, 1 } }) })
                end
            end
            if not low then -- (a NEBULA SEA: banks of glowing gas drifting over the deep-space floor, so it reads as depth, not a plane)
                for i, g in ipairs({ { V(XM, -64, ZM), C(70, 120, 200) }, { V(XM - 380, -60, ZM + 300), C(60, 170, 190) }, { V(XM + 420, -62, ZM - 260), C(120, 90, 210) },
                    { V(XM + 300, -58, ZM + 420), C(70, 140, 220) }, { V(XM - 360, -66, ZM - 380), C(90, 100, 200) },
                    { V(XM + 60, -34, ZM - 140), C(80, 110, 210) }, { V(XM - 120, -40, ZM + 160), C(60, 150, 200) } }) do -- (+ two higher, thinner banks: layered depth)
                    local gas = S(g[1], V(i == 1 and 360 or 520, 10, i == 1 and 360 or 520), g[2], M.SmoothPlastic, { T = 1 })
                    Kit.Mist(gas, { Rate = i == 1 and 2 or 1.2, Size = i == 1 and 80 or 140, T = 0.82, Color = g[2] })
                end
            end
        end
    elseif theme == "Crystal" then
        -- ===== CRYSTAL HOLLOW (0.89, references: the cavern hideouts of a big ARPG's shop -- original design): an old miners'
        -- lodge built on a rock pillar inside a cavern of azure crystal. Timber post-and-beam walls, open north windows on
        -- the cavern, crystal sconces, oil lanterns, the west recess is a MINE SHAFT with rails and a cart rolling in and out.
        -- Outside: the cavern walls and stalactites, giant crystal clusters, an underground lake, a waterfall, a mine
        -- trestle across the lake with a second cart, glowing spores and drips.
        local TIM, TIM2, ROCK, ROCK2, IRON = C(116, 80, 50), C(88, 60, 40), C(74, 78, 92), C(54, 56, 70), C(52, 52, 56)
        local CRY, CRY2, CORE, LAMP, WATER = C(70, 160, 240), C(140, 110, 245), C(150, 225, 255), C(255, 190, 110), C(30, 96, 124)
        local H = 16
        -- a crystal: a shaft + a pointed tip, the shaft clear-ish round a glowing core (Glass would black out the core)
        local function Crystal(base: CFrame, len: number, w: number, col: Color3, core: boolean?)
            SC(base * CF(0, len / 2, 0), V(w, len, w), col, M.SmoothPlastic, { T = 0.22 })
            SC(base * CF(0, len + w * 0.45, 0), V(w, w * 0.9, w), col, M.SmoothPlastic, { Wedge = true, T = 0.22 })
            SC(base * CF(0, len + w * 0.45, 0) * ANG(0, math.pi, 0), V(w, w * 0.9, w), col, M.SmoothPlastic, { Wedge = true, T = 0.22 })
            if core then return SC(base * CF(0, len / 2, 0), V(w * 0.35, len * 0.9, w * 0.35), CORE, M.Neon, { T = 0.25 }) end
            return nil
        end
        -- (UPDATE 4) CRYSTAL v2: real crystal clusters (azure + violet), a real mine cart, iron cage lanterns (HideoutKit.Crystal
        -- + the Forge lantern); without the kit the primitive crystals are drawn
        local cryV2 = Kit ~= nil and Kit.Get("Crystal", "ClusterBlue") ~= nil
        -- (UPDATE 6 QUARTZ, owner: "make the crystals in crystal hollow actually look like crystals / maybe shine like them"):
        -- the two kit clusters are real quartz now (tools/crystal_quartz.py: six-sided prisms with faceted tips fanned out of
        -- a rock matrix; parts Matrix / Shell (translucent) / Core (Neon, the glow from within) / Tips (lighter) -- model
        -- attr Quartz). Each one GLINTS: a few star sparkles flash on its tips now and then (one tiny emitter, not on Low,
        -- not on the pool reflections); o.Light = a soft coloured PointLight on a handful of big clusters (their rock lights up)
        local function Cluster(cfl: CFrame, scale: number, violet: boolean?, o: any?): Model?
            if not cryV2 then return nil end
            local m = Kit.Place(f, "Crystal", violet and "ClusterViolet" or "ClusterBlue", CF(O) * cfl, scale)
            if m and m:GetAttribute("Quartz") then
                local tips = m:FindFirstChild("Tips")
                if tips and not (o and o.NoFx) and not Kit.Low() then
                    local e = Instance.new("ParticleEmitter")
                    e.Name = "Glint"
                    e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
                    e.Color = ColorSequence.new(violet and C(240, 225, 255) or C(225, 245, 255))
                    e.LightEmission, e.LightInfluence = 1, 0
                    e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.32 * scale), NumberSequenceKeypoint.new(1, 0) })
                    e.Transparency = NumberSequence.new(0.05)
                    e.Lifetime = NumberRange.new(0.35, 0.6)
                    e.Rate = 0.5 + 0.25 * scale
                    e.Speed = NumberRange.new(0, 0)
                    e.Rotation = NumberRange.new(0, 90)
                    e.ZOffset = 1
                    e.Parent = tips
                end
                if o and o.Light and not Kit.Low() then -- (no extra cluster lights on Graphics Quality Low)
                    local core = m:FindFirstChild("Core")
                    if core then Light(core, violet and C(175, 135, 255) or C(110, 185, 255), o.Light, 0.75) end
                end
            end
            return m
        end
        -- timber wall run: plank infill, posts every ~8, a sill beam + a head beam; axis "X" (at z) or "Z" (at x)
        local function Wall(axis: string, a0: number, a1: number, at: number, y0: number?, y1: number?)
            local len, mid = a1 - a0, (a0 + a1) / 2
            local lo, hi = y0 or 0, y1 or H
            local function At(u: number, y: number, sx: number, sy: number, sz: number, col: Color3, mat: Enum.Material, o: any?): BasePart
                if axis == "X" then return S(V(u, y, at), V(sx, sy, sz), col, mat, o) end
                return S(V(at, y, u), V(sz, sy, sx), col, mat, o)
            end
            -- (a timber wainscot to y 6, rough cavern rock above: the lodge is built into the rock)
            local mid6 = math.min(hi, 6)
            if mid6 > lo then At(mid, (lo + mid6) / 2, len, mid6 - lo, 1.2, TIM, M.WoodPlanks, { Collide = true }) end
            if hi > 6 then At(mid, (math.max(lo, 6) + hi) / 2, len, hi - math.max(lo, 6), 1.2, ROCK, M.Slate, { Collide = true }) end
            local n = math.max(1, math.floor(len / 8))
            for k = 0, n do At(a0 + len * k / n, (lo + hi) / 2, 1, hi - lo, 1.6, TIM2, M.Wood) end
            At(mid, hi - 0.4, len, 0.8, 1.6, TIM2, M.Wood)
        end
        Wall("Z", -14, -9, -30.5); Wall("Z", 1, BZ, -30.5)
        S(V(-30.5, (12 + H) / 2, -4), V(1.2, H - 12, 10), TIM, M.WoodPlanks, { Collide = true })
        Wall("Z", -14, 0, BX + 0.5); Wall("Z", 8, BZ, BX + 0.5)
        S(V(BX + 0.5, (11.2 + H) / 2, 4), V(1.2, H - 11.2, 8), TIM, M.WoodPlanks, { Collide = true })
        Wall("X", -30, -6, BZ + 0.5); Wall("X", 30, BX, BZ + 0.5)
        S(V(12, (12 + H) / 2, BZ + 0.5), V(36, H - 12, 1.2), TIM, M.WoodPlanks, { Collide = true })
        S(V(12, 12.4, BZ + 0.5), V(37, 1, 1.8), TIM2, M.Wood) -- (the balcony opening's lintel)
        -- NORTH: open windows on the cavern (a sill wall + a head wall, posts, a rope rail; an invisible barrier)
        local function Window(x0: number, x1: number)
            local xc, w = (x0 + x1) / 2, x1 - x0
            Wall("X", x0, x1, -14.5, 0, 3)
            Wall("X", x0, x1, -14.5, 11, H)
            for x = x0, x1 + 0.1, w / math.max(1, math.floor(w / 8)) do S(V(x, 7, -14.5), V(1, 8, 1.4), TIM2, M.Wood) end
            S(V(xc, 4.2, -14.2), V(w, 0.18, 0.18), C(170, 140, 100), M.Fabric)
            Barrier(V(xc, 7, -14.5), V(w, 8, 0.6))
        end
        -- (2026-10-23) with the map room built the bays it backs onto are solid timber (HideoutData.NorthRuns: the open
        -- windows used to look into the map room's rock walls)
        local nRuns = HideoutData.NorthRuns(mapRoom)
        for _, r in ipairs(nRuns.Win) do Window(r[1], r[2]) end
        for _, r in ipairs(nRuns.Solid) do Wall("X", r[1], r[2], -14.5) end
        -- the ceiling: planks on heavy beams
        S(V(XM, H + 0.5, ZM), V(BX + 32, 1, BZ + 16), ROCK2, M.Slate, { Collide = true, Roof = true })
        for x = -24, BX - 6, 10 do S(V(x, H - 0.6, ZM), V(1.4, 1.2, BZ + 14), TIM2, M.Wood, { Roof = true }) end
        -- three oil lanterns on chains (the lodge's lights)
        for i, x in ipairs({ -14, 12, 38 }) do
            local ch = S(V(x, H - 2.6, ZM - 2), V(0.12, 4, 0.12), IRON, M.Metal, { Roof = true })
            local caged = cryV2 and Kit.Place(f, "Forge", "Lantern", CF(O + V(x, H - 4.6, ZM - 2)) * ANG(0, R(i * 50), 0), 1.1)
            local lb = S(V(x, caged and (H - 6.2) or (H - 5.3), ZM - 2), caged and V(0.45, 0.7, 0.45) or V(0.7, 1.0, 0.7), C(255, 150, 70), M.Neon, { T = 0.3 })
            if not caged then
                S(V(x, H - 4.5, ZM - 2), V(1.3, 0.25, 1.3), IRON, M.Metal, { Parent = lb })
                S(V(x, H - 6.1, ZM - 2), V(1.3, 0.25, 1.3), IRON, M.Metal, { Parent = lb })
                for _, o in ipairs({ V(0.55, 0, 0.55), V(-0.55, 0, 0.55), V(0.55, 0, -0.55), V(-0.55, 0, -0.55) }) do S(V(x, H - 5.3, ZM - 2) + o, V(0.12, 1.6, 0.12), IRON, M.Metal, { Parent = lb }) end
            end
            Anim(lb, "Pulse", { Amp = 0.12, Rate = 5, Phase = i * 2 })
            Light(lb, C(255, 190, 120), 36, 0.85)
            local _ = ch
        end
        -- crystal sconces high on the walls (iron brackets holding a glowing cluster)
        for i, sc in ipairs({ { -29.6, 9, 6, 1 }, { -29.6, 9, 26, 1 }, { BX - 0.4, 9, -8, -1 }, { BX - 0.4, 9, 22, -1 } }) do
            local p = V(sc[1], sc[2], sc[3])
            S(p, V(2, 0.4, 2.4), IRON, M.Metal)
            local core
            if Cluster(CF(p + V(sc[4] * 0.3, 0.2, 0)) * ANG(0, R(i * 70), R(sc[4] * -12)), 0.45, i % 2 == 0) then
                core = S(p + V(sc[4] * 0.8, 1.6, 0), V(0.3, 0.3, 0.3), CORE, M.SmoothPlastic, { T = 1 })
            else
                for k = 0, 2 do
                    local c = Crystal(CF(p + V(sc[4] * 0.4, 0.1, (k - 1) * 0.7)) * ANG(R((k - 1) * 20), 0, R(sc[4] * -14)), 2.2 + (k % 2) * 1.2, 0.8, (i % 2 == 0) and CRY2 or CRY, k == 1)
                    core = core or c
                end
            end
            if core then
                Anim(core, "Pulse", { Amp = 0.35, Rate = 0.7, Phase = i })
                if i % 2 == 1 then Light(core, (i % 2 == 0) and C(170, 130, 255) or C(110, 180, 255), 22, 0.6) end
            end
        end
        -- THE MINE SHAFT (west recess, z -9..1): a timber-framed tunnel mouth, rails into the dark, a cart full of crystals
        -- rolling in and out
        S(V(-34.5, H / 2, -9.5), V(8, H, 1), ROCK2, M.Slate, { Collide = true })
        S(V(-34.5, H / 2, 1.5), V(8, H, 1), ROCK2, M.Slate, { Collide = true })
        S(V(-38.5, H / 2, -4), V(1, H, 12), C(10, 12, 18), M.SmoothPlastic, { Collide = true })
        S(V(-34.5, H + 0.5, -4), V(9, 1, 12), ROCK2, M.Slate, { Collide = true, Roof = true })
        S(V(-34.5, -0.5, -4), V(8, 1, 10), ROCK, M.Slate, { Collide = true })
        for _, x in ipairs({ -31, -35, -38 }) do -- (tunnel frames: two posts + a cap)
            for _, z in ipairs({ -8.6, 0.6 }) do S(V(x, 5, z), V(0.9, 10, 0.9), TIM2, M.Wood) end
            S(V(x, 10.3, -4), V(1, 1, 10.4), TIM2, M.Wood)
        end
        for _, z in ipairs({ -5.1, -2.9 }) do S(V(-34, 0.15, z), V(10, 0.3, 0.25), IRON, M.Metal) end
        for x = -38, -30, 1.6 do S(V(x, 0.05, -4), V(0.5, 0.15, 3.4), TIM2, M.Wood) end
        do
            -- (a moving part turns to face where it goes: the cart is built long along its own Z, axles along X)
            local cart = cryV2 and Kit.Creature(f, "Crystal", "MineCart", CF(O + V(-34.5, 0.3, -4)), 1, {})
            if not cart then
                cart = S(V(-34.5, 1.4, -4), V(2.6, 1.8, 3.2), IRON, M.Metal)
                for _, x in ipairs({ -1.1, 1.1 }) do for _, z in ipairs({ -1.1, 1.1 }) do
                    S(V(-34.5 + x, 0.55, -4 + z), V(0.4, 0.9, 0.9), C(30, 30, 34), M.Metal, { Shape = Cyl, Parent = cart })
                end end
            end
            Anim(cart, "Line", { Axis = "X", Amp = 2.6, Speed = 1.2 })
            for k = 0, 3 do
                local c = SC(CF(-34.5 + (k - 1.5) * 0.7, 2.6, -4 + ((k % 2) - 0.5) * 0.8) * ANG(R((k - 1.5) * 15), 0, R((k % 2 - 0.5) * 30)), V(0.5, 1.4 + (k % 2) * 0.6, 0.5),
                    (k % 2 == 0) and CRY or CRY2, M.Neon, { T = 0.2 })
                c.Parent = cart
            end
            Light(cart, C(120, 190, 255), 14, 0.5)
        end
        Anim(S(V(-38, 6, -4), V(0.2, 3, 3), CRY, M.Neon, { T = 0.6 }), "Pulse", { Amp = 0.3, Rate = 0.5 }) -- (a glow deep in the shaft)
        -- the door: planks + iron bands + a ring, a lantern EXIT
        for k = 0, 3 do S(V(BX + 0.42, 5.6, 1 + k * 2), V(0.3, 11.2, 1.96), (k % 2 == 0) and TIM or TIM2, M.WoodPlanks) end
        for _, y in ipairs({ 1.5, 5.6, 9.7 }) do S(V(BX + 0.24, y, 4), V(0.12, 0.5, 7.6), IRON, M.Metal) end
        S(V(BX + 0.15, 5.4, 1.6), V(0.12, 1, 1), IRON, M.Metal, { Shape = Cyl })
        local exit = S(V(BX - 0.3, 12.6, 4), V(0.2, 1.2, 3.4), C(30, 22, 16), M.SmoothPlastic)
        Label(exit, Enum.NormalId.Left, "出口  EXIT", LAMP)
        -- THE PRACTICE ALCOVE: a rock gallery, barrels with crystal bullseyes
        S(V(-34.5, H / 2, -26.5), V(1, H, 24), ROCK2, M.Slate, { Collide = true })
        S(V(-13.5, H / 2, -26.5), V(1, H, 24), ROCK2, M.Slate, { Collide = true })
        S(V(-24, H / 2, -38.5), V(22, H, 1), ROCK2, M.Slate, { Collide = true })
        S(V(-24, H + 0.5, -27), V(22, 1, 24), ROCK2, M.Slate, { Collide = true, Roof = true }) -- (z -39..-15: not over the lodge's own)
        for _, x in ipairs({ -29, -19 }) do
            S(V(x, 2, -36.6), V(3.4, 4, 3.4), TIM, M.WoodPlanks, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
            S(V(x, 6, -37.85), V(0.3, 3.6, 3.6), TIM2, M.Wood, { Shape = Cyl, Rot = ANG(0, R(90), 0) })
            S(V(x, 6, -37.7), V(0.3, 1.2, 1.2), CRY, M.Neon, { Shape = Cyl, Rot = ANG(0, R(90), 0) })
        end
        local psign = S(V(-22.5, 12, -13.7), V(9, 1.4, 0.25), C(30, 22, 16), M.SmoothPlastic)
        Label(psign, Enum.NormalId.Back, "PRACTICE  練習", LAMP)
        -- THE MAP ROOM: a rock chamber veined with crystal, or a boarded-up doorway
        if mapRoom then
            S(V(MR.X0 - 0.5, H / 2, MR.WZ), V(1, H, MR.WL), ROCK, M.Slate, { Collide = true })
            S(V(MR.X1 + 0.5, H / 2, MR.WZ), V(1, H, MR.WL), ROCK, M.Slate, { Collide = true })
            S(V(MXC, H / 2, MR.Z0 - 0.5), V(MR.X1 - MR.X0 + 2, H, 1), ROCK, M.Slate, { Collide = true })
            S(V(MXC, H + 0.5, MR.CZ), V(MR.X1 - MR.X0 + 3, 1, MR.CL), ROCK2, M.Slate, { Collide = true, Roof = true })
            S(V(28, (12 + H) / 2, -14.5), V(MR.DoorX1 - MR.DoorX0, H - 12, 1.2), TIM, M.WoodPlanks, { Collide = true })
            for i, z in ipairs({ -20, -28, -36 }) do
                for _, x in ipairs({ MR.X0, MR.X1 }) do
                    Anim(S(V(x + ((x == MR.X0) and 0.05 or -0.05), 7, z), V(0.1, 4, 0.3), CRY, M.Neon, { Rot = ANG(R(20 * i), 0, 0) }), "Pulse", { Amp = 0.5, Rate = 0.7, Phase = i })
                end
            end
            local mapSign = S(V(28, 13, -13.7), V(9, 1.4, 0.25), C(30, 22, 16), M.SmoothPlastic)
            Label(mapSign, Enum.NormalId.Back, "MAP ROOM  地図室", LAMP)
        else
            S(V(28, (12 + H) / 2, -14.5), V(MR.DoorX1 - MR.DoorX0, H - 12, 1.2), TIM, M.WoodPlanks, { Collide = true })
            S(V(28, 6, -14.6), V(MR.DoorX1 - MR.DoorX0, 12, 0.6), C(20, 20, 26), M.SmoothPlastic, { Collide = true })
            for k = 0, 3 do S(V(28, 2 + k * 3, -14.1), V(13, 1, 0.4), (k % 2 == 0) and TIM or TIM2, M.WoodPlanks, { Rot = ANG(0, 0, R((k % 2 == 0) and 8 or -8)) }) end
            LockedSign(-13.8, LAMP)
        end
        -- THE BALCONY: a timber railing, two crystal lamp posts
        for x = -30, BX, 6 do S(V(x, 1.8, BALZ), V(0.6, 3.6, 0.6), TIM2, M.Wood) end
        for _, y in ipairs({ 1.6, 3.3 }) do S(V(XM, y, BALZ), V(BX + 30, 0.4, 0.3), TIM, M.Wood) end
        for i, x in ipairs({ -26, BX - 4 }) do
            S(V(x, 2.2, BALZ - 2), V(0.4, 4.4, 0.4), IRON, M.Metal)
            local cr = Crystal(CF(x, 4.4, BALZ - 2), 1.8, 0.7, CRY, true)
            if cr then Anim(cr, "Pulse", { Amp = 0.3, Rate = 0.8, Phase = i }); Light(cr, C(120, 190, 255), 22, 0.6) end
        end
        if cryV2 then
        -- ===== CRYSTAL HOLLOW v3 (UPDATE 6, owner: "looks a bit unfinished, some of the crystals come across as randomly
        -- placed and just float, and the water in there just doesn't look good"): every cluster is SEATED -- on the pillar
        -- top, on rock ledges off the pillar, on the shore shelves that ring the lake at the foot of the cavern walls, on
        -- rock islands, or sunk into a wall face and growing out of it -- and composed for the two views (the north windows,
        -- the balcony). The lake is a dark, still, deep pool: a translucent surface over a black bed far below, every
        -- low cluster mirrored under it (its reflection), slow ripple glints on the surface, the light off the water
        -- moving on the cavern roof, a breath of mist. Soft self-lit glows (no Light objects) round the island crystals.
        local WY = -30 -- (the water line)
        local low = Kit.Low()
        local refl = {} -- { cfl, scale, violet } of clusters whose reflection shows in the pool
        local function Seat(cfl: CFrame, scale: number, violet: boolean?, mirror: boolean?, light: number?): Model?
            local m = Cluster(cfl, scale, violet, light and { Light = light } or nil)
            if m and mirror then table.insert(refl, { cfl, scale, violet }) end
            return m
        end
        local function Rock(cfl: CFrame, size: Vector3, col: Color3?): BasePart return SC(cfl, size, col or ROCK2, M.Slate) end
        local function Halo(lp: Vector3, studs: number, col: Color3, t: number)
            if LavaFX then LavaFX.Glow(f, O + lp, studs, col, t, { Name = "CrystalGlow", Pulse = 0.04 }) end
        end
        S(V(XM, -37.5, ZM), V(BX + 46, 73, BZ + 34), ROCK, M.Slate) -- (the rock pillar the lodge stands on, down into the dark water)
        -- the PILLAR: its long faces broken up by leaning buttresses of rock (it read as one grey box)
        for i, b in ipairs({ { -30, -26, 0 }, { -2, -26.5, 0 }, { 30, -25.8, 0 }, { 54, -26.2, 0 }, { -24, 46, 1 }, { 6, 46.5, 1 }, { 40, 45.8, 1 },
            { -40, -6, 2 }, { -40, 24, 2 }, { 64, 0, 3 }, { 64, 30, 3 } }) do
            local side = b[3]
            local rot = (side <= 1) and ANG(R((side == 0 and -1 or 1) * (6 + i % 3 * 3)), R(i * 17 % 30 - 15), R(i * 11 % 14 - 7))
                or ANG(R(i * 13 % 16 - 8), R(i * 9 % 20 - 10), R((side == 2 and 1 or -1) * (6 + i % 3 * 3)))
            local size = (side <= 1) and V(14 + i % 3 * 5, 50, 7 + i % 2 * 2) or V(7 + i % 2 * 2, 50, 14 + i % 3 * 5)
            Rock(CF(b[1], -27.6, b[2]) * rot, size, (i % 2 == 0) and ROCK or ROCK2)
        end
        -- clusters growing from the pillar's top just outside the north windows (their roots in the rock), low and at the
        -- window edges so they frame the view of the lake instead of filling it
        for i, cl in ipairs({ { -11, -21.4, 0, 1.0 }, { 19, -21.8, 1, 1.2 }, { 51, -21.4, 0, 1.05 } }) do
            Seat(CF(cl[1], -1.6, cl[2]) * ANG(0, R(i * 47), 0) * ANG(R(-9), 0, R((i - 2) * 6)), cl[4], cl[3] == 1, nil, (i == 2) and 22 or nil)
        end
        -- past the balcony rail: rock ledges jut from the pillar's south face, a cluster on each
        for i, cl in ipairs({ { -22, 1, 1.6 }, { 30, 0, 1.4 }, { 50, 1, 1.7 } }) do
            Rock(CF(cl[1], -5.4, 49.5) * ANG(R(4), R(i * 23), 0), V(13, 9, 12), ROCK)
            Rock(CF(cl[1] + 1, -12, 47.5) * ANG(R(-28), R(i * 23), R(6)), V(10, 9, 9), ROCK2)
            Seat(CF(cl[1], -1.3, 50.5) * ANG(0, R(i * 61), 0) * ANG(R(9), 0, R((i - 2) * 5)), cl[3], cl[2] == 1, nil, (i == 2) and 22 or nil)
        end
        -- THE POOL: a black bed far down (reads as deep), the translucent surface, ripple glints, mist
        S(V(XM, -76, ZM), V(580, 2, 580), C(3, 7, 11), M.Slate)
        local water = S(V(XM, WY, ZM), V(580, 0.3, 580), C(6, 26, 38), M.SmoothPlastic, { T = 0.46 })
        Kit.Caustics(water, Enum.NormalId.Top, 90, 0.955, 0.12) -- (slow, very faint: a still pool's glints -- stronger read as a net)
        if not low then
            local mist = S(V(XM, WY + 4, ZM), V(420, 6, 420), C(120, 190, 220), M.SmoothPlastic, { T = 1 })
            Kit.Mist(mist, { Rate = 1.6, Size = 46, T = 0.9, Color = C(140, 200, 230) })
        end
        -- the pillar's foot: rock ledges at the water line, crystals growing on them (glow + reflections close to the lodge)
        for k, lg in ipairs({ { -20, -27.5, 1.8 }, { 30, -28, 2.2 }, { -41.5, 12, 1.6 }, { 65.5, 20, 2.0 }, { 0, 47.5, 1.9 }, { 44, 48, 1.5 } }) do
            Rock(CF(lg[1], WY, lg[2]) * ANG(0, R(k * 29), 0), V(13, 4.4, 10), (k % 2 == 0) and ROCK or ROCK2) -- (as deep as it is tall: its reflection is itself)
            Seat(CF(lg[1], WY + 1.4, lg[2]) * ANG(0, R(k * 67), 0) * ANG(R(-6), 0, R(5)), lg[3], k % 3 == 0, true)
        end
        -- islands: rock stacks rising out of the dark water, crystal on each (north view + balcony view)
        for i, isl in ipairs({ { -24, -70, 1, 2.6 }, { 44, -96, 0, 3.2 }, { 104, -36, 1, 2.2 }, { -46, 92, 0, 2.8 }, { 58, 108, 1, 3.0 }, { -96, 30, 0, 2.4 } }) do
            local x, z, yaw = isl[1], isl[2], R(i * 53)
            Rock(CF(x, WY + 0.5, z) * ANG(0, yaw, 0), V(20 + i % 3 * 4, 9, 16 + i % 2 * 4), (i % 2 == 0) and ROCK or ROCK2)
            Rock(CF(x + 9, WY, z + 5) * ANG(0, yaw + 0.5, 0), V(10, 4.8, 9), ROCK2)
            Seat(CF(x, WY + 4.3, z) * ANG(0, yaw, 0) * ANG(R(5), 0, R(-4)), isl[4], isl[3] == 1, true, (i == 2) and 34 or nil)
            Seat(CF(x + 8, WY + 1.4, z + 5) * ANG(0, yaw + 1.2, 0) * ANG(R(-12), 0, R(10)), isl[4] * 0.5, isl[3] ~= 1, true)
            Halo(V(x, WY + isl[4] * 3.4, z), isl[4] * 18, (isl[3] == 1) and C(170, 130, 255) or C(110, 190, 255), 0.5)
            Halo(V(x, WY - isl[4] * 3.4, z), isl[4] * 16, (isl[3] == 1) and C(170, 130, 255) or C(110, 190, 255), 0.72) -- (its glow in the water)
        end
        -- THE CAVERN: wall slabs round the lake; at each one's foot a SHORE SHELF (a ring of rock at the water line, going
        -- down into the dark), giant clusters seated on every other shelf, and some growing out of the wall face higher up
        local SHELL = { C(48, 50, 62), C(60, 62, 76), C(40, 42, 54) }
        for i = 0, 19 do
            local a = i / 20 * math.pi * 2
            local r = 190 + (i % 3) * 16
            local cx, cz = XM + math.cos(a) * r, ZM + math.sin(a) * r
            local yaw = -a + math.pi / 2
            local wall = S(V(cx, 30, cz), V(80, 190, 46), SHELL[i % 3 + 1], M.Slate, { Rot = ANG(0, yaw, 0) * ANG(R(8 + (i % 3) * 3), 0, 0) })
            local shelfTop = WY + 2 + (i % 3) * 0.7
            local sh = 2 * (shelfTop - WY) + 1 -- (as deep below the water line as it stands above: the pool mirrors it)
            Rock(CF(XM + math.cos(a) * (r - 40), shelfTop - sh / 2, ZM + math.sin(a) * (r - 40)) * ANG(0, yaw, 0),
                V(72, sh, 36), SHELL[(i + 1) % 3 + 1])
            if i % 2 == 0 then
                local sr = r - 42
                local sc = 3.4 + (i % 3) * 0.8
                Seat(CF(XM + math.cos(a) * sr, shelfTop - 0.9, ZM + math.sin(a) * sr) * ANG(0, R(i * 37), 0) * ANG(R(-6), 0, R(5)), sc, i % 4 == 0, true)
                Seat(CF(XM + math.cos(a + 0.09) * (sr + 6), shelfTop - 0.7, ZM + math.sin(a + 0.09) * (sr + 6)) * ANG(0, R(i * 71), 0) * ANG(R(10), 0, R(-8)), sc * 0.45, i % 4 ~= 0, true)
            end
            local _ = wall
        end
        -- the reflections: each low cluster mirrored in the water line, a touch darker
        -- (bug sweep 2026-10-13: not on Graphics Quality Low -- they are ~a third of the cavern's parts)
        for _, e in ipairs(low and {} or refl) do
            local cfl = e[1]
            local p, xv, yv = cfl.Position, cfl.XVector, cfl.YVector
            local mp = V(p.X, 2 * WY - p.Y, p.Z)
            local m = Cluster(CFrame.fromMatrix(mp, V(xv.X, -xv.Y, xv.Z), V(yv.X, -yv.Y, yv.Z)), e[2], e[3], { NoFx = true })
            -- (a touch fainter than the real thing: each part keeps 70% of its own opacity -- the quartz shells stay clear)
            if m then for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Transparency = 1 - (1 - d.Transparency) * 0.7 end end end
        end
        local roof = S(V(XM, 118, ZM), V(520, 6, 520), C(36, 38, 50), M.Slate) -- (the cavern roof; the light off the water ripples on it)
        Kit.Caustics(roof, Enum.NormalId.Bottom, 80, 0.95, 0.2)
        for i = 0, 15 do -- (stalactites + a few crystal ones)
            local a, r = i * 2.39996, 50 + math.sqrt(i) * 34
            local x, z = XM + math.cos(a) * r, ZM + math.sin(a) * r
            local len = 20 + (i % 4) * 9
            for _, turn in ipairs({ 0, math.pi }) do -- (two wedges back to back = a point)
                SC(CF(x, 115 - len / 2, z) * ANG(R(180), R(i * 40) + turn, 0), V(8, len, 4), (i % 5 == 0) and CRY or SHELL[i % 3 + 1], (i % 5 == 0) and M.SmoothPlastic or M.Slate,
                    { Wedge = true, T = (i % 5 == 0) and 0.2 or 0 })
            end
        end
        -- the waterfall off the north-east wall: a lip of rock, streaming white water (WorldKit falls: scrolling layered
        -- beams + foam), mist where it lands
        do
            local wx, wz = XM + 120, ZM - 130
            Rock(CF(wx, 108, wz) * ANG(0, R(-40), 0), V(26, 8, 16), ROCK)
            if WK then
                WK.Falls(f, O + V(wx, 106, wz), O + V(wx, WY + 0.4, wz), 18, { Color = C(170, 220, 240), Rate = 4 })
            else
                Anim(S(V(wx, 40, wz), V(10, 140, 1), C(200, 240, 255), M.Neon, { T = 0.35, Rot = ANG(0, R(-40), 0) }), "Pulse", { Amp = 0.15, Rate = 2 })
            end
            local foot = S(V(wx, WY + 0.5, wz + 6), V(30, 1, 20), C(170, 220, 240), M.SmoothPlastic, { T = 1, Rot = ANG(0, R(-40), 0) })
            Fx(foot, "Idle", { Tex = "Smoke", Color = C(220, 240, 255), Size = NSK({ { 0, 3 }, { 1, 9 } }), Rate = 4, Speed = NumberRange.new(2, 4), Life = NumberRange.new(2, 3),
                Light = 0.1, T = NSK({ { 0, 1 }, { 0.3, 0.7 }, { 1, 1 } }), Shape = BOX })
            Halo(V(wx, WY + 6, wz + 4), 70, C(150, 210, 240), 0.82)
        end
        else
        -- crystal clusters growing up just outside the north windows and past the balcony rail (seen from inside)
        for i, cl in ipairs({ { -8, -18, 0 }, { 14, -19, 1 }, { 42, -18, 0 }, { -22, 46, 1 }, { 30, 47, 0 }, { 50, 46, 1 } }) do
            if Cluster(CF(cl[1], -4, cl[2] + ((cl[2] < 0) and -3 or 3)) * ANG(0, R(i * 47), 0) * ANG(R((cl[2] < 0 and 1 or -1) * -10), 0, 0), 1.5 + (i % 2) * 0.3, cl[3] == 1) then continue end
            for k = 0, 2 do
                local c = Crystal(CF(cl[1] + (k - 1) * 2.2, -2, cl[2]) * ANG(R((cl[2] < 0 and 1 or -1) * (-14 - k * 6)), R(i * 30), R((k - 1) * 22)), 7 + (k % 2) * 5 + (i % 2) * 2, 1.6,
                    (cl[3] == 1) and CRY2 or CRY, k == 1)
                if c then Anim(c, "Pulse", { Amp = 0.3, Rate = 0.5 + i * 0.05, Phase = i * 2 }) end
            end
        end
        -- OUTSIDE: the rock pillar the lodge stands on, the cavern ring + roof, stalactites, giant crystals, the lake, a
        -- waterfall, the mine trestle with a cart, spores + drips
        S(V(XM, -20, ZM), V(BX + 46, 38, BZ + 34), ROCK, M.Slate)
        S(V(XM, -30, ZM), V(700, 1, 700), WATER, M.SmoothPlastic, { T = 0.05, Refl = 0.15 }) -- (the lake)
        S(V(XM, -38, ZM), V(700, 2, 700), C(14, 30, 44), M.Slate) -- (its bed; the city's street terrain is ~80 below)
        local SHELL = { C(48, 50, 62), C(60, 62, 76), C(40, 42, 54) }
        for i = 0, 19 do
            local a = i / 20 * math.pi * 2
            local r = 190 + (i % 3) * 16
            local cx, cz = XM + math.cos(a) * r, ZM + math.sin(a) * r
            S(V(cx, 40, cz), V(80, 170, 46), SHELL[i % 3 + 1], M.Slate, { Rot = ANG(0, -a + math.pi / 2, 0) * ANG(R(8 + (i % 3) * 3), 0, 0) })
            if i % 2 == 0 then -- (a crystal cluster growing off the wall, leaning into the cavern)
                local base = CF(XM + math.cos(a) * (r - 30), -28 + (i % 4) * 14, ZM + math.sin(a) * (r - 30)) * ANG(0, -a + math.pi / 2, 0)
                if Cluster(base * ANG(R(-22), 0, 0), 5 + (i % 3) * 0.8, i % 4 == 0) then continue end
                for k = 0, 2 do
                    local c = Crystal(base * CF((k - 1) * 7, 0, 0) * ANG(R(-25 - k * 8), 0, R((k - 1) * 18)), 24 + (k % 2) * 16 + (i % 3) * 6, 5 + (k % 2) * 2,
                        (i % 4 == 0) and CRY2 or CRY, k == 1)
                    if c then Anim(c, "Pulse", { Amp = 0.3, Rate = 0.4 + (i % 3) * 0.1, Phase = i }) end
                end
            end
        end
        S(V(XM, 118, ZM), V(520, 6, 520), C(36, 38, 50), M.Slate) -- (the cavern roof)
        for i = 0, 15 do -- (stalactites + a few crystal ones)
            local a, r = i * 2.39996, 50 + math.sqrt(i) * 34
            local x, z = XM + math.cos(a) * r, ZM + math.sin(a) * r
            local len = 20 + (i % 4) * 9
            for _, turn in ipairs({ 0, math.pi }) do -- (two wedges back to back = a point)
                SC(CF(x, 115 - len / 2, z) * ANG(R(180), R(i * 40) + turn, 0), V(8, len, 4), (i % 5 == 0) and CRY or SHELL[i % 3 + 1], (i % 5 == 0) and M.SmoothPlastic or M.Slate,
                    { Wedge = true, T = (i % 5 == 0) and 0.2 or 0 })
            end
        end
        -- the waterfall off the north-east wall into the lake (a bright core in a soft sheet, mist where it lands)
        do
            local wx, wz = XM + 120, ZM - 130
            Anim(S(V(wx, 40, wz), V(10, 140, 1), C(200, 240, 255), M.Neon, { T = 0.35, Rot = ANG(0, R(-40), 0) }), "Pulse", { Amp = 0.15, Rate = 2 })
            S(V(wx, 40, wz), V(22, 140, 0.8), C(120, 190, 230), M.SmoothPlastic, { T = 0.55, Rot = ANG(0, R(-40), 0) })
            local foot = S(V(wx, -29.5, wz + 6), V(30, 1, 20), C(170, 220, 240), M.Neon, { T = 0.6, Rot = ANG(0, R(-40), 0) })
            Fx(foot, "Idle", { Tex = "Smoke", Color = C(220, 240, 255), Size = NSK({ { 0, 3 }, { 1, 9 } }), Rate = 4, Speed = NumberRange.new(2, 4), Life = NumberRange.new(2, 3),
                Light = 0.1, T = NSK({ { 0, 1 }, { 0.3, 0.7 }, { 1, 1 } }), Shape = BOX })
        end
        end
        -- the mine trestle: from the pillar out east across the lake, timber bents, rails, a second cart
        do
            local y0 = -1.2
            S(V(BX + 60, y0, 20), V(120, 0.8, 6), TIM2, M.WoodPlanks)
            for _, z in ipairs({ 18.9, 21.1 }) do S(V(BX + 60, y0 + 0.55, z), V(120, 0.3, 0.25), IRON, M.Metal) end
            for x = BX + 8, BX + 118, 14 do
                for _, z in ipairs({ 17.5, 22.5 }) do S(V(x, (y0 - 30) / 2, z), V(0.9, 28.5, 0.9), TIM2, M.Wood, { Rot = ANG(R((z - 20) * 1.5), 0, 0) }) end
                S(V(x, -14, 20), V(0.6, 0.6, 7), TIM2, M.Wood)
                S(V(x, -14, 20), V(0.5, 20, 0.5), TIM2, M.Wood, { Rot = ANG(R(70), 0, 0) })
            end
            local cart = S(V(BX + 60, y0 + 1.6, 20), V(2.6, 1.8, 3.4), IRON, M.Metal)
            Anim(cart, "Line", { Axis = "X", Amp = 50, Speed = 4 })
            for k = 0, 2 do local c = SC(CF(BX + 59.3 + k * 0.7, y0 + 2.9, 20) * ANG(0, 0, R((k - 1) * 20)), V(0.6, 1.6, 0.6), CRY, M.Neon, { T = 0.2 }); c.Parent = cart end
        end
        for i, p in ipairs({ V(-40, 4, 50), V(10, 10, 56), V(60, 6, 52), V(-50, 12, -30), V(30, 8, -40), V(70, 14, -24), V(-60, 6, 10), V(80, 10, 40), V(0, 20, 60), V(40, 22, -60) }) do
            Anim(S(p, V(0.3, 0.3, 0.3), (i % 3 == 0) and CRY2 or CORE, M.Neon, { Shape = Ball }), "Firefly", { Speed = 0.25 + (i % 3) * 0.12 })
        end
        for i, p in ipairs({ V(-50, 100, 40), V(70, 104, -30), V(30, 98, 70), V(-20, 102, -60), V(90, 96, 20), V(-70, 100, -10) }) do
            Anim(S(p, V(0.25, 0.5, 0.25), C(170, 220, 255), M.Neon, { T = 0.3 }), "Fall", { Height = 128, Speed = 22 + i * 2 })
        end
    else
        -- ===== WALLED-CITY LOFT (the default): plaster walls, a window band north, sliding glass to the balcony, exposed
        -- pipes and three hanging lamps; it floats over the real city (the plaza, the waypoint and the spawn are below)
        local WALL, TRIM = TL.Wall, TL.Trim
        local H = 16
        -- (UPDATE 4) LOFT v2: real pendant lamps, a turning ceiling fan, balcony plants + AC units, a cat asleep in the sun,
        -- fairy lights on the rail (HideoutKit.Apartment; without the kit the old pieces are drawn)
        local aptV2 = Kit ~= nil and Kit.Get("Apartment", "Lamp") ~= nil
        local lowQ = Kit ~= nil and Kit.Low() or false
        local function AP(name: string, lp: Vector3, yaw: number?, scale: number?): Model?
            if not aptV2 then return nil end
            return Kit.Place(f, "Apartment", name, CF(O + lp) * ANG(0, R(yaw or 0), 0), scale)
        end
        S(V(XM, H + 0.5, ZM), V(BX + 32, 1, BZ + 16), TL.Ceil, TL.CeilMat, { Collide = true })
        S(V(-24, H + 0.5, -27), V(22, 1, 24), TL.Ceil, TL.CeilMat, { Collide = true }) -- (the alcove's: z -39..-15, never over the room's own)
        S(V(-30.5, H / 2, ZM), V(1, H, BZ + 14), WALL, TL.WallMat, { Collide = true })
        S(V(BX + 0.5, H / 2, -7), V(1, H, 14), WALL, TL.WallMat, { Collide = true })
        S(V(BX + 0.5, H / 2, (8 + BZ) / 2), V(1, H, BZ - 8), WALL, TL.WallMat, { Collide = true })
        S(V(BX + 0.5, H - 2.5, 4), V(1, 5, 8), WALL, TL.WallMat, { Collide = true })
        -- the door: a steel door in a dark frame (two inset panels, a push bar, a kick plate, a narrow window), EXIT over it
        for _, z in ipairs({ -0.3, 8.3 }) do S(V(BX + 0.1, 5.6, z), V(0.6, 11.2, 0.6), TRIM, TL.TrimMat) end
        S(V(BX + 0.1, 11.3, 4), V(0.6, 0.6, 9.2), TRIM, TL.TrimMat)
        S(V(BX + 0.35, 5.4, 4), V(0.25, 10.8, 7.6), C(54, 52, 58), M.Metal)
        for _, y in ipairs({ 8, 3 }) do S(V(BX + 0.2, y, 4), V(0.08, 4, 6.4), C(44, 42, 48), M.Metal) end
        S(V(BX + 0.05, 5.4, 4), V(6, 0.3, 0.3), C(190, 192, 198), M.Metal, { Shape = Cyl, Rot = ANG(0, R(90), 0) })
        S(V(BX + 0.18, 0.6, 4), V(0.08, 1, 7.2), C(130, 130, 136), M.DiamondPlate)
        S(V(BX + 0.16, 8.4, 6.2), V(0.12, 2.4, 0.7), TL.Glass, M.Glass, { T = 0.5 })
        S(V(BX - 0.15, 11.9, 4), V(0.3, 0.3, 8), C(255, 80, 80), M.Neon)
        local exit = S(V(BX - 0.2, 12.9, 4), V(0.2, 1.2, 3), C(20, 10, 10), M.SmoothPlastic)
        Label(exit, Enum.NormalId.Left, "出口  EXIT", C(255, 80, 80))
        -- north wall: window bands either side of the map-room doorway (x -14..22 and 34..54). (2026-10-23, owner: "the
        -- grey kind of clips through the tan wall") with the map room built, its concrete side walls (x 9..10 / 46..47)
        -- used to run up to z -14 -- through this wall, their ends z-fighting the plaster sill / head, and the windows at
        -- x 10..22 / 34..46 looked into the map room. Now its walls stop behind this wall (z -15), the bays it backs onto
        -- are plain plaster (HideoutData.NorthRuns); the window bands' end posts stand where the wing walls meet this wall.
        local function WindowWall(x0: number, x1: number)
            local w, xc = x1 - x0, (x0 + x1) / 2
            S(V(xc, 1.5, -14.5), V(w, 3, 1), WALL, TL.WallMat, { Collide = true })
            S(V(xc, H - 2, -14.5), V(w, 4, 1), WALL, TL.WallMat, { Collide = true })
            for x = x0, x1 + 0.1, w / math.max(1, math.floor(w / 8.8 + 0.5)) do S(V(x, H / 2, -14.5), V(1, H, 1.2), TRIM, TL.TrimMat, { Collide = true }) end
            -- (2026-10-23: SmoothPlastic, not Glass -- the Glass material hides every see-through part behind it, and the
            -- city's lit rooms / neon / signs are see-through Neon)
            S(V(xc, 7.5, -14.6), V(w, 9, 0.2), TL.Glass, M.SmoothPlastic, { T = 0.88, Refl = 0.06, Collide = true })
            S(V(xc, 0.4, -14), V(w, 0.8, 0.3), TRIM, TL.TrimMat)
        end
        -- the wings' OUTER faces (the alcove + the map room frame the north windows like a light well): the city's night
        -- facade tile, so the windows look out between two building walls, not bare concrete
        local function Outer(p: BasePart, face: Enum.NormalId)
            local t = Instance.new("Texture"); t.Texture = "rbxassetid://118912348108489"; t.Face = face
            t.StudsPerTileU, t.StudsPerTileV, t.OffsetStudsV = 20, 20, 2
            t.Parent = p
        end
        local runs = HideoutData.NorthRuns(mapRoom)
        for _, r in ipairs(runs.Win) do WindowWall(r[1], r[2]) end
        for _, r in ipairs(runs.Solid) do
            S(V((r[1] + r[2]) / 2, H / 2, -14.5), V(r[2] - r[1], H, 1), WALL, TL.WallMat, { Collide = true })
            S(V((r[1] + r[2]) / 2, 0.4, -13.85), V(r[2] - r[1], 0.8, 0.3), TRIM, TL.TrimMat)
        end
        if mapRoom then
            S(V(28, H - 2.5, -14.5), V(MR.DoorX1 - MR.DoorX0, 5, 1), WALL, TL.WallMat, { Collide = true })
            for _, x in ipairs({ MR.DoorX0, MR.DoorX1 }) do S(V(x, 5.5, -14.5), V(0.8, 11, 1.4), TRIM, TL.TrimMat) end
            local sign = S(V(28, 12.4, -13.9), V(9, 1.6, 0.25), C(20, 18, 24), M.SmoothPlastic)
            Label(sign, Enum.NormalId.Back, "MAP ROOM  地図室", TL.Accent)
            -- the map room: concrete walls, a strip of warm light, its ceiling (walls z MR.Z0..-15, ceiling z MR.Z0-1..-15:
            -- both stop behind the window wall)
            Outer(S(V(MR.X0 - 0.5, H / 2, MR.WZ), V(1, H, MR.WL), C(90, 92, 98), M.Concrete, { Collide = true }), Enum.NormalId.Left)
            Outer(S(V(MR.X1 + 0.5, H / 2, MR.WZ), V(1, H, MR.WL), C(90, 92, 98), M.Concrete, { Collide = true }), Enum.NormalId.Right)
            S(V(MXC, H / 2, MR.Z0 - 0.5), V(MR.X1 - MR.X0 + 2, H, 1), C(60, 62, 70), M.Concrete, { Collide = true })
            S(V(MXC, H + 0.5, MR.CZ), V(MR.X1 - MR.X0 + 2, 1, MR.CL), TL.Ceil, TL.CeilMat, { Collide = true })
            for _, x in ipairs({ MR.X0 + 0.1, MR.X1 - 0.1 }) do S(V(x, 10, MZC), V(0.2, 0.15, -14 - MR.Z0 - 2), TL.Accent, M.Neon, { T = 0.3 }) end
        else
            S(V(28, H / 2, -14.5), V(MR.DoorX1 - MR.DoorX0, H, 1), WALL, TL.WallMat, { Collide = true })
            S(V(28, 4.5, -13.95), V(6, 9, 0.2), C(54, 52, 58), M.Metal)
            S(V(28, 4.5, -13.85), V(0.1, 8.6, 0.1), C(30, 30, 34), M.Metal)
            LockedSign(-13.85, TL.Accent)
        end
        -- alcove walls (x -34..-14, z -38..-15: they stop behind the window wall's end post, not through it) + the
        -- corner west of the room (x -35..-30) closed
        S(V(-34.5, H / 2, -26.5), V(1, H, 23), C(90, 92, 98), M.Concrete, { Collide = true })
        Outer(S(V(-13.5, H / 2, -26.5), V(1, H, 23), C(90, 92, 98), M.Concrete, { Collide = true }), Enum.NormalId.Right)
        S(V(-32.5, H / 2, -14.5), V(5, H, 1), C(90, 92, 98), M.Concrete, { Collide = true })
        S(V(-24, H / 2, -38.5), V(22, H, 1), C(60, 62, 70), M.Concrete, { Collide = true })
        local psign = S(V(-24, 12.5, -14.2), V(10, 2.2, 0.3), C(20, 18, 24), M.SmoothPlastic)
        Label(psign, Enum.NormalId.Back, "PRACTICE  練習", C(255, 200, 40))
        S(V(-24, 11.3, -14.2), V(10, 0.15, 0.4), C(255, 200, 40), M.Neon)
        -- south wall: posts + sliding glass to the balcony, a railing
        local SW = BX + 30 - 12
        S(V(-27, H / 2, BZ + 0.5), V(6, H, 1), WALL, TL.WallMat, { Collide = true })
        S(V(BX - 3, H / 2, BZ + 0.5), V(6, H, 1), WALL, TL.WallMat, { Collide = true })
        S(V(XM, H - 1.5, BZ + 0.5), V(SW, 3, 1), WALL, TL.WallMat, { Collide = true })
        for x = -24, BX - 6, 12 do S(V(x, (H - 3) / 2, BZ + 0.5), V(0.4, H - 3, 0.6), DARK, M.Metal) end
        S(V(XM, (H - 3) / 2, BZ + 0.5), V(SW, H - 3, 0.2), TL.Glass, M.SmoothPlastic, { T = 0.9, Refl = 0.06 }) -- (not Glass: see the windows)
        S(V(XM, 3.5, BALZ), V(BX + 30, 0.3, 0.3), DARK, M.Metal, {})
        S(V(XM, 1.75, BALZ), V(BX + 30, 3.5, 0.2), DARK, M.Metal, { T = 0.6, Collide = true })
        for x = -28, BX - 2, 4 do S(V(x, 1.75, BALZ), V(0.2, 3.5, 0.2), DARK, M.Metal) end
        if aptV2 then
            -- the balcony: two monsteras + a planter box, AC units on the wall stubs, the cat asleep, fairy lights on the rail
            AP("Monstera", V(-27.5, 0, BALZ - 2.4), 30)
            AP("Planter", V(-22.5, 0, BALZ - 1.6), 180)
            AP("Monstera", V(BX - 4, 0, BALZ - 2.4), -40, 0.9)
            AP("ACUnit", V(-27, 0, BZ + 1.75), 180)
            AP("ACUnit", V(BX - 3, 0, BZ + 1.75), 180)
            local cat = Kit.Creature(f, "Apartment", "Cat", CF(O + V(BX - 12, 0, BALZ - 3)) * ANG(0, R(-110), 0), 1, { Flap = { tail = { "Y", 0.35, 1.1 } } })
            if cat then Anim(cat, "Bob", { Amp = 0.03, Rate = 0.5, NoTurn = true }) end
            if not lowQ then
                local warm = { C(255, 190, 110), C(255, 150, 90), C(255, 220, 150) }
                local k = 0
                for x = -28.5, BX - 1.5, 2.4 do
                    k += 1
                    S(V(x, 3.78, BALZ), V(0.24, 0.24, 0.24), warm[k % 3 + 1], M.Neon, { Shape = Ball, T = 0.15, Anim = { "Pulse", { Amp = 0.35, Rate = 0.6 + (k % 4) * 0.15 } } })
                end
            end
        else
            for k = 0, 3 do S(V(-26 + k * 1.6, 1, BALZ - 2.5), V(1.2, 2, 1.2), C(120, 70, 50), M.Slate) end -- balcony pots
            for k = 0, 3 do S(V(-26 + k * 1.6, 2.6, BALZ - 2.5), V(1.4, 1.4, 1.4), C(80, 150, 80), M.Grass, { Shape = Ball }) end
        end
        -- the ceiling: exposed pipes + three hanging lamps (the room's only lights)
        for k = 0, 2 do S(V(XM, H - 0.8 - k * 0.6, -6 + k * 0.7), V(BX + 30, 0.5, 0.5), C(90, 86, 80), M.Metal, { Shape = Cyl }) end
        for _, x in ipairs({ -6, 18, 42 }) do
            local shade
            if AP("Lamp", V(x, H, ZM), x * 3) then
                local b = Kit.Get("Apartment", "Lamp"):GetAttribute("Bulb")
                shade = S(V(x, H, ZM) + ((typeof(b) == "Vector3") and b or V(0, -3.3, 0)) + V(0, -0.3, 0), V(0.3, 0.3, 0.3), TL.Lamp, M.SmoothPlastic, { T = 1 })
            else
                S(V(x, H - 2, ZM), V(0.1, 4, 0.1), DARK, M.Metal)
                S(V(x, H - 4.2, ZM), V(0.9, 2.8, 2.8), C(60, 46, 40), M.Metal, { Shape = Cyl, Rot = ANG(0, 0, R(90)) }) -- (a dark shade, a small warm bulb under it)
                shade = S(V(x, H - 4.75, ZM), V(0.9, 0.9, 0.9), TL.Lamp, M.Neon, { T = 0.1, Shape = Ball })
            end
            local l = Instance.new("PointLight"); l.Color = TL.Light; l.Range = 32; l.Brightness = 0.55; l.Shadows = false; l.Parent = shade
        end
        if aptV2 then -- (the ceiling fan, turning slowly over the middle of the room)
            local fan = Kit.Creature(f, "Apartment", "Fan", CF(O + V(XM, H - 1.6, ZM)), 1, {})
            if fan then Anim(fan, "Spin", { Rate = 1.1 }) end
        end
        S(V(-30, 0.4, ZM), V(0.3, 0.8, BZ + 14), TRIM, TL.TrimMat)
        -- ===== THE CITY VIEW (2026-10-23, owner: the outside buildings "look like glued on"): the loft used to float over
        -- the hub, and its north windows looked at the hub's real north row 24 studs past the glass -- one flat facade in
        -- every pane, no sky, no street. The city is parked on this client here now (AimRngClient, like every theme) and
        -- the loft stands in its own block of a night city: a street canyon each side with traffic, a NEAR row across it
        -- (the hub's night facade tiles + relief, lit rooms, shop neon, roof tanks, signs), a MID row and a FAR skyline
        -- (dark towers whose lit rooms are a Neon plate seen through tools/make_skyline_lit.py's tile: glowing windows
        -- without SurfaceGuis or lights), an elevated train north, an ad blimp circling. Street level is local y -41 (the
        -- hub terrain ~76 below never shows). Seeded: every visit builds the same city. No lights.
        do
            local GY = -41
            local FAC = { "rbxassetid://118912348108489", "rbxassetid://128353189650653", "rbxassetid://120306559202636", "rbxassetid://140001422292538" }
            local SKY = "rbxassetid://139511270244651"
            local MS = game:GetService("MaterialService")
            local EK = nil
            pcall(function() EK = require(script.Parent:WaitForChild("EnvKit", 2)) end)
            local GRIME = { C(92, 84, 78), C(78, 74, 76), C(104, 92, 80), C(70, 72, 80), C(96, 78, 70), C(84, 70, 64) }
            local NEONS = { C(255, 60, 120), C(50, 210, 255), C(255, 160, 50), C(170, 80, 255), C(70, 255, 170) }
            local LIT = { C(205, 135, 70), C(205, 135, 70), C(220, 150, 85), C(190, 120, 70), C(70, 95, 140) }
            local rng = Random.new(2310)
            local function Tex(part: BasePart, id: string, face: Enum.NormalId, su: number, ou: number?)
                local t = Instance.new("Texture"); t.Texture = id; t.Face = face; t.StudsPerTileU = su; t.StudsPerTileV = su
                t.OffsetStudsU = ou or 0; t.Parent = part
                return t
            end
            -- a tower's frame: (fx, fz) = the middle of its FRONT face at street level; yaw 0 = the front faces -Z (north),
            -- pi = +Z (south), pi/2 = -X (west), -pi/2 = +X (east). Local -Z is the front, the block runs back d studs.
            local function Frame(fx: number, fz: number, d: number, yaw: number): CFrame
                return CF(fx, 0, fz) * ANG(0, yaw, 0) * CF(0, 0, d / 2)
            end
            local roofs = {}
            -- NEAR: a facade-tiled block (top on a 20-stud line so the tile + its relief variant line up); lit rooms in the
            -- tile's window bays; a shop band at street level; o.Back = the back face is a street face too
            local function Near(fx: number, fz: number, w: number, d: number, n: number, yaw: number, o: any?)
                o = o or {}
                local top = GY + 20 * n
                local cf = Frame(fx, fz, d, yaw)
                local k = rng:NextInteger(1, #FAC)
                local blk = SC(cf * CF(0, (GY + top) / 2, 0), V(w, top - GY, d), GRIME[rng:NextInteger(1, #GRIME)], M.Concrete)
                if MS:FindFirstChild("HubFacade" .. k) then blk.MaterialVariant = "HubFacade" .. k end
                local faces = { Enum.NormalId.Front, Enum.NormalId.Left, Enum.NormalId.Right }
                if o.Back then table.insert(faces, Enum.NormalId.Back) end
                for _, face in ipairs(faces) do Tex(blk, FAC[k], face, 20) end
                for _, side in ipairs(o.Back and { 1, -1 } or { 1 }) do
                    local zf = -side * (d / 2 + 0.06)
                    local rot = (side > 0) and CF() or ANG(0, math.pi, 0)
                    local nLit = math.min(4, math.floor(w * (top - GY) / 600) + rng:NextInteger(0, 1))
                    for _ = 1, nLit do
                        local fl = rng:NextInteger(0, math.max(0, math.floor((top - GY - 16) / 10) - 1))
                        local nb = math.floor((w - 1) / 5)
                        if nb >= 1 then
                            local uc = 2.5 + 5 * rng:NextInteger(0, nb - 1)
                            local lx = side * (w / 2 - uc)
                            SC(cf * CF(lx, top - 4.8 - 10 * fl, zf) * rot, V(3, 3.6, 0.12), LIT[rng:NextInteger(1, #LIT)], M.Neon, { T = 0.5 })
                        end
                    end
                    -- the shops: a lit glass front + a neon sign band over it
                    SC(cf * CF(0, GY + 2.8, zf - side * 0.02) * rot, V(w - 3, 3.6, 0.1), C(255, 165, 95), M.Neon, { T = 0.72 })
                    SC(cf * CF(rng:NextNumber(-w / 6, w / 6), GY + 7.6, zf - side * 0.25) * rot, V(w * rng:NextNumber(0.45, 0.75), 1.4, 0.35), NEONS[rng:NextInteger(1, #NEONS)], M.Neon, { T = 0.2 })
                end
                -- the roof: a parapet on the street side; a water tank, an antenna with a red beacon, or a stair shack
                -- (o.NoRoof: the loft's own block, under the floor)
                if o.NoRoof then return end
                SC(cf * CF(0, top + 0.6, -d / 2 + 0.35), V(w + 0.2, 1.2, 0.7), C(60, 56, 56), M.Concrete)
                local r = rng:NextNumber()
                if r < 0.4 and EK and EK.Has("City", "WaterTank") then
                    EK.Place("City", "WaterTank", CF(O) * cf * CF(rng:NextNumber(-w / 2 + 4, w / 2 - 4), top, rng:NextNumber(-2, 4)) * ANG(0, R(rng:NextNumber(0, 360)), 0), { Parent = f, Scale = 0.9, Shadow = false })
                elseif r < 0.75 then
                    local tx, mh = rng:NextNumber(-w / 2 + 2, w / 2 - 2), rng:NextNumber(8, 15)
                    SC(cf * CF(tx, top + mh / 2, 2), V(0.3, mh, 0.3), C(60, 60, 64), M.Metal)
                    Anim(SC(cf * CF(tx, top + mh, 2), V(0.7, 0.7, 0.7), C(255, 50, 40), M.Neon, { Shape = Ball }), "Pulse", { Amp = 0.85, Rate = 1.4 + rng:NextNumber(0, 0.6) })
                elseif EK and EK.Has("City", "RoofShack") and w > 14 then
                    EK.Place("City", "RoofShack", CF(O) * cf * CF(rng:NextNumber(-w / 2 + 5, w / 2 - 5), top, d * 0.2), { Parent = f, Scale = 1, Shadow = false })
                end
                table.insert(roofs, { cf, top, w, d })
            end
            -- SKY: a dark block, its front a Neon plate under the lit-window tile (dim = the plate's transparency: farther
            -- = dimmer rooms); o.Edge = neon strips up its front corners
            local function Sky(fx: number, fz: number, w: number, d: number, top: number, yaw: number, dim: number, col: Color3, o: any?)
                local cf = Frame(fx, fz, d, yaw)
                SC(cf * CF(0, (GY + top) / 2, 0), V(w, top - GY, d), col, M.SmoothPlastic)
                local plate = SC(cf * CF(0, (GY + 6 + top - 0.4) / 2, -d / 2 + 0.05), V(w - 0.4, top - 0.4 - GY - 6, 0.2), C(255, 140, 60), M.Neon, { T = dim })
                Tex(plate, SKY, Enum.NormalId.Front, 80, 5 * rng:NextInteger(0, 15))
                if o and o.Edge then
                    local ec = NEONS[rng:NextInteger(1, #NEONS)]
                    for _, sx in ipairs({ -1, 1 }) do SC(cf * CF(sx * (w / 2 - 0.2), (GY + top) / 2, -d / 2 - 0.15), V(0.4, top - GY, 0.3), ec, M.Neon, { T = 0.3 }) end
                end
                if top > GY + 70 and rng:NextNumber() < 0.5 then
                    Anim(SC(cf * CF(0, top + 1, 0), V(1.6, 1.6, 1.6), C(255, 50, 40), M.Neon, { Shape = Ball }), "Pulse", { Amp = 0.85, Rate = 1.2 + rng:NextNumber(0, 0.8) })
                end
            end
            -- a row of towers along x from x0 to x1, fronts on the line z = fz (+ jitter away from the loft), facing it
            local function Row(x0: number, x1: number, fz: number, yaw: number, kind: string)
                local away = (yaw == 0) and 1 or -1
                local x = x0
                while x < x1 do
                    if kind == "near" then
                        local w = rng:NextNumber(16, 30)
                        local n = ({ 1, 2, 2, 3, 3, 4, 5 })[rng:NextInteger(1, 7)]
                        Near(x + w / 2, fz, w, rng:NextNumber(18, 28), n, yaw)
                        x += w + ((rng:NextNumber() < 0.3) and rng:NextNumber(3, 7) or 0)
                    elseif kind == "mid" then
                        local w = rng:NextNumber(26, 46)
                        Sky(x + w / 2, fz + away * rng:NextNumber(0, 30), w, 30, GY + rng:NextNumber(45, 125), yaw, 0.12, C(26, 25, 32), { Edge = rng:NextNumber() < 0.12 })
                        x += w + rng:NextNumber(6, 24)
                    else
                        local w = rng:NextNumber(60, 110)
                        Sky(x + w / 2, fz + away * rng:NextNumber(0, 90), w, 50, GY + rng:NextNumber(80, 230), yaw, 0.38, C(18, 17, 24), { Edge = rng:NextNumber() < 0.25 })
                        x += w + rng:NextNumber(4, 30)
                    end
                end
            end
            -- the street (one asphalt slab under everything, centre lines), the loft's own block + its neighbours
            local street = S(V(12, GY - 1, 10), V(2000, 2, 2000), C(40, 38, 46), M.Asphalt)
            if MS:FindFirstChild("HubAsphalt") then street.MaterialVariant = "HubAsphalt" end
            for _, z in ipairs({ 66, -58 }) do S(V(12, GY + 0.03, z), V(1600, 0.05, 0.35), C(220, 180, 70), M.Neon, { T = 0.55 }) end
            Near(10.25, -41, 91.5, 75, 2, 0, { Back = true, NoRoof = true }) -- (the loft's building: x -35.5..56, z -41..34, roof under the floor)
            -- the light well between the wings (seen down through the north windows): a roof deck, a vent box + its duct
            S(V(10.25, -0.95, -27.5), V(91.5, 0.1, 27), C(70, 68, 72), M.Concrete)
            S(V(-6, 0.1, -32), V(3.2, 2, 2.6), C(120, 122, 128), M.DiamondPlate)
            S(V(-6, 1.3, -32), V(1.8, 0.4, 1.8), C(60, 60, 66), M.Metal, { Shape = Cyl, Rot = ANG(0, 0, R(90)) })
            S(V(-1, 0.6, -36), V(9, 0.9, 0.9), C(110, 108, 112), M.Metal, { Shape = Cyl })
            -- sidewalks along both streets, the shops' light spilling over them, sodium lamps on the far curbs
            for _, sw in ipairs({ { 34, 41, 36.5 }, { 89, 96, 93.5 }, { -48, -41, -43.5 }, { -75, -68, -72.5 } }) do
                S(V(12, GY + 0.25, (sw[1] + sw[2]) / 2), V(1600, 0.5, sw[2] - sw[1]), C(86, 82, 88), M.Concrete)
                S(V(12, GY + 0.52, sw[3]), V(1600, 0.04, 4), C(255, 150, 80), M.Neon, { T = 0.9 })
            end
            for _, ln in ipairs({ { 88.6, -1 }, { -67.6, 1 } }) do
                for lx = -110, 170, 56 do
                    S(V(lx, GY + 6, ln[1]), V(0.4, 12, 0.4), C(40, 40, 44), M.Metal)
                    S(V(lx, GY + 12, ln[1] + ln[2] * 1.4), V(0.8, 0.4, 3), C(255, 170, 80), M.Neon, { T = 0.1 })
                    S(V(lx, GY + 0.07, ln[1] + ln[2] * 4), V(0.05, 15, 15), C(220, 120, 50), M.Neon, { T = 0.92, Shape = Cyl, Rot = ANG(0, 0, R(90)) })
                end
            end
            local x = -35.5
            for _, n in ipairs({ 3, 1, 2, 4 }) do local w = rng:NextNumber(22, 30); Near(x - w / 2, -41, w, 75, n, 0, { Back = true }); x -= w end
            x = 56
            for _, n in ipairs({ 2, 4, 1, 3 }) do local w = rng:NextNumber(22, 30); Near(x + w / 2, -41, w, 75, n, 0, { Back = true }); x += w end
            -- SOUTH (the balcony): the street z 34..96, the near row, mid, far
            Row(-150, 190, 96, 0, "near")
            Row(-420, 450, 180, 0, "mid")
            Row(-900, 920, 340, 0, "far")
            -- NORTH (the windows): the street z -75..-41, the near row, the elevated line, mid, far
            Row(-130, 170, -75, math.pi, "near")
            Row(-420, 450, -165, math.pi, "mid")
            Row(-900, 920, -330, math.pi, "far")
            -- the street ends (east / west), far off
            for _, e in ipairs({ { 560, math.pi / 2 }, { -520, -math.pi / 2 } }) do
                local z = -150
                while z < 200 do
                    local w = rng:NextNumber(40, 80)
                    Sky(e[1], z + w / 2, w, 50, GY + rng:NextNumber(70, 190), e[2], 0.38, C(18, 17, 24))
                    z += w + rng:NextNumber(0, 12)
                end
            end
            -- rooftop signs on up to four low near roofs facing the loft (one SurfaceGui each)
            local words = { "ラーメン  拉麺", "HOTEL  旅館", "薬局  24H", "カラオケ" }
            local nSign = 0
            for _, rf in ipairs(roofs) do
                local cf, top, w, d = rf[1], rf[2], rf[3], rf[4]
                if nSign < #words and top <= GY + 60 and top >= GY + 20 and w >= 18 and d < 40 and rng:NextNumber() < 0.5 then
                    nSign += 1
                    local col = NEONS[(nSign % #NEONS) + 1]
                    local sw, sh = math.min(w - 3, 15), 4.5
                    local board = SC(cf * CF(0, top + 2 + sh / 2, -d / 2 + 1.4), V(sw, sh, 0.4), C(14, 12, 18), M.Metal)
                    Label(board, Enum.NormalId.Front, words[nSign], col)
                    for _, dy in ipairs({ 1.6, sh + 2.4 }) do
                        local bar = SC(cf * CF(0, top + dy, -d / 2 + 1.15), V(sw + 0.4, 0.3, 0.3), col, M.Neon)
                        if nSign == 2 then Anim(bar, "Pulse", { Amp = 0.6, Rate = 3.1 }) end
                    end
                    for _, lx in ipairs({ -sw / 2 + 1, sw / 2 - 1 }) do SC(cf * CF(lx, top + 1, -d / 2 + 1.4), V(0.4, 2, 0.4), C(30, 30, 32), M.Metal) end
                end
            end
            -- the elevated line north (track + piers; the train runs on it)
            local TZ = -128
            S(V(12, -12, TZ), V(1500, 2, 7), C(52, 50, 56), M.Concrete)
            for px = -400, 420, 110 do S(V(px, (GY - 12) / 2 - 0.5, TZ), V(3, -12 - GY - 1, 3), C(52, 50, 56), M.Concrete) end
            if not lowQ then
                -- THE LIFE: cars both streets (a body, head / tail lights), the train, the blimp
                for i, c in ipairs({ { 54, 34 }, { 60, 28 }, { 72, 40 }, { 78, 31 }, { -52, 36 }, { -64, 30 }, { 48, 44 } }) do
                    local body = S(V(rng:NextNumber(-200, 200), GY + 1.2, c[1]), V(2.6, 1.6, 6), ({ C(30, 30, 36), C(120, 30, 34), C(200, 200, 205), C(40, 60, 90) })[i % 4 + 1], M.SmoothPlastic)
                    for _, sx in ipairs({ -0.8, 0.8 }) do
                        P(body, body.CFrame * CF(sx, 0.1, -3.02), V(0.6, 0.35, 0.1), C(255, 250, 225), M.Neon)
                        P(body, body.CFrame * CF(sx, 0.2, 3.02), V(0.6, 0.3, 0.1), C(255, 40, 40), M.Neon)
                    end
                    Anim(body, "Line", { Axis = "X", Amp = 360 + i * 25, Speed = c[2], Phase = i * 0.9 })
                end
                local train = S(V(0, -8.2, TZ), V(4.6, 4.6, 64), C(150, 155, 165), M.Metal)
                for _, sx in ipairs({ -2.32, 2.32 }) do P(train, train.CFrame * CF(sx, 0.5, 0), V(0.1, 1.4, 60), C(255, 214, 150), M.Neon) end
                for _, sz in ipairs({ -32.05, 32.05 }) do P(train, train.CFrame * CF(0, -0.6, sz), V(2.4, 0.5, 0.1), C(255, 250, 225), M.Neon) end
                Anim(train, "Line", { Axis = "X", Amp = 420, Speed = 38, Phase = 1.7 })
                local blimp = S(V(12, 78, 10), V(11, 11, 38), C(70, 72, 82), M.SmoothPlastic, { Shape = Ball })
                for _, sx in ipairs({ -5.2, 5.2 }) do P(blimp, blimp.CFrame * CF(sx, 0, 0), V(0.2, 4.5, 16), C(255, 60, 150), M.Neon, { T = 0.15 }) end
                P(blimp, blimp.CFrame * CF(0, -6, 2), V(2.4, 2, 6), C(40, 40, 46), M.Metal)
                P(blimp, blimp.CFrame * CF(0, 3, 17), V(0.4, 6, 5), C(60, 62, 72), M.SmoothPlastic)
                Anim(blimp, "Orbit", { Center = O + V(12, 78, 10), RX = 300, RZ = 250, Speed = 9, Bob = 2 })
            end
        end
    end
    -- the roof pieces (ceiling, pipes, lamps, the walls' top bands) hide in build mode so the overhead camera sees in
    -- (moving decoration never: it's not in the way)
    for _, p in ipairs(f:GetDescendants()) do
        if p:IsA("BasePart") and not p:GetAttribute("Anim") and not (p.Parent and p.Parent:IsA("BasePart")) then
            local lp = p.Position - O
            if lp.Y > 11.5 and p.Size.Y < 6 and lp.X > -40 and lp.X < BX + 6 and lp.Z > -46 and lp.Z < BALZ + 4 then p:SetAttribute("Roof", true) end
        end
    end
    f.Parent = parent
    return f
end

-- (UPDATE 8 RARITY v4) furniture rarity LABELS on the 5 rarities (Common / Uncommon / Rare / Mythic / Relic), the same map as
-- items (ItemData.RARITY_ALIAS); ids, prices and sources unchanged
do
    local MAP = { Epic = "Rare", Legendary = "Rare", Celestial = "Mythic", Transcendent = "Mythic", Astral = "Mythic", Empyrean = "Mythic",
        Primordial = "Mythic", Sovereign = "Mythic", Eclipse = "Mythic", Genesis = "Mythic", Infinite = "Mythic", Exotic = "Relic" }
    for _, def in pairs(Items) do
        if type(def) == "table" and MAP[def.Rarity] then def.Rarity = MAP[def.Rarity] end
    end
end

return HideoutData
