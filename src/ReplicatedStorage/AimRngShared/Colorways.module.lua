--!nocheck
-- ============================================================================================
-- COLORWAYS + BOUND POINTS (0.93; owner: "a valorant style color changer for gear ... a premium currency (that would be
-- included in the season pass and purchable with robux), and all gear sets could have 3 different colorways to use. The
-- effects of each gear set and such would also match these color changes" -> "Currency name could be BOUND points ... an
-- alternate recolor for an entire set could be fairly priced at 99 robux. A colourway would unlock for the whole set. You
-- would have to own the base set before purchasing colourways ... a seperate menu selectable from both each individual
-- item AND the bundle if they want to recolor everything").
--
-- HOW A COLOURWAY WORKS: a set's colours all come from ONE `C3` function at the top of its SkinSets module. A colourway is
-- a hue map (Sets[kind][v].Hue): every colour the set makes -- armour plates, glows, tracers, impacts, kill effect, banner,
-- melee, gloves, sleeves, health bar -- goes through it. SkinFX.Sets["Tempest#2"] loads a second copy of the set module
-- with attribute Colorway = 2 (SkinFX "COLORWAYS" at the bottom), so variant 2 is a whole set of its own with every effect
-- recoloured; the gun's palette textures are separate maps (`<Surface>_V2`, tools/make_skin_maps.py COLORWAYS mirrors the
-- hue maps here -- keep both in step). Uploaded images (emblems, prints) keep their colours.
-- Hue map: { from deg, to deg, sat x, val x } anchors: a colour takes the shift (to - from) + multipliers of the anchor
-- nearest its hue; pure greys, whites and blacks (saturation < 0.04) never change.
--
-- STATE: state.BoundPoints (number), state.Colorways[kind] = { Own = { ["2"] = true }, Set = v?, Items = { [ref] = v } }.
-- The colour of an item = Items[ref] or Set or 1 (only owned colourways count). Server: CombatServer "ColorwayAction".
-- This module requires nothing (the set modules require it).
-- ============================================================================================
local Colorways = {}

Colorways.CURRENCY = "BOUND POINTS"
Colorways.SHORT = "BP"
Colorways.PRICE = 100 -- BOUND points for one colourway (unlocks it for the whole set)
-- Robux packs (Developer Products; ProductId 0 = free in Studio, "coming soon" live). 100 BP = R$ 99 = one colourway.
-- (0.97 BOUND SHOP, owner: "Everything in the shop will be purchasable with the bound points ... purchasable in set amounts
-- ... 99 ... 9999 robux worth. Each bundle would give you slightly better value, scaling with the amount purchased" -> picked
-- "1:1 then bonus"): seven packs, 1 BP = 1 R$ at the smallest, +35% at the biggest (2026-10-14 owner pricing pass: was +15%). Old pack ids stay readable (receipts).
Colorways.PACKS = {
    { Id = "BP100", Points = 100, Price = 99, ProductId = 3718278495 },
    { Id = "BP310", Points = 325, Price = 299, ProductId = 3718278503, Note = "+9%" },
    { Id = "BP525", Points = 575, Price = 499, ProductId = 3718278515, Note = "+15%" },
    { Id = "BP1075", Points = 1200, Price = 999, ProductId = 3718278519, Note = "+20%" },
    { Id = "BP2750", Points = 3125, Price = 2499, ProductId = 3718278526, Note = "+25%" },
    { Id = "BP5600", Points = 6500, Price = 4999, ProductId = 3718278531, Note = "+30%" },
    { Id = "BP11500", Points = 13500, Price = 9999, ProductId = 3718278539, Note = "+35%" },
}
Colorways.PackById = {}
for _, p in ipairs(Colorways.PACKS) do Colorways.PackById[p.Id] = p end

-- the colourways of each set: [1] = the original. Swatch = 3 colours for the menu cards.
local C = Color3.fromRGB
Colorways.Sets = {
    -- (SKINS V3 bundle 1) FERROFLUX: the module copies pick their whole palette by colourway (Set.Palettes); the hue maps
    -- only cover any colour made outside it
    Ferroflux = {
        { Name = "Magnet", Swatch = { C(20, 18, 30), C(56, 50, 78), C(235, 60, 200) } },
        { Name = "Quicksilver", Desc = "Liquid mercury: blue-steel fluid, brushed titanium and a cold cyan field.",
          Swatch = { C(44, 52, 72), C(74, 86, 108), C(70, 220, 255) }, Hue = { { 250, 222, 1 }, { 312, 192, 1 } } },
        { Name = "Magma", Desc = "Molten core: oxblood-black fluid, scorched bronze coils and an ember field.",
          Swatch = { C(40, 14, 14), C(74, 48, 42), C(255, 120, 40) }, Hue = { { 250, 0, 1 }, { 312, 22, 1 } } },
        { Name = "Venom", Desc = "Toxic tide: black-green fluid, oxidised coils and an acid field.",
          Swatch = { C(18, 30, 22), C(50, 66, 52), C(170, 255, 70) }, Hue = { { 250, 140, 1 }, { 312, 88, 1 } } },
    },
    Bespoke = {
        { Name = "Oxblood", Swatch = { C(78, 20, 30), C(86, 88, 98), C(255, 130, 160) } },
        { Name = "Bourbon", Desc = "Tan-brown leather, brass engraving and an amber jewel.",
          Swatch = { C(104, 58, 32), C(138, 104, 56), C(255, 180, 80) }, Hue = { { 350, 22, 1 }, { 345, 35, 1 } } },
        { Name = "Midnight", Desc = "Navy leather, platinum engraving and an ice jewel.",
          Swatch = { C(22, 28, 58), C(112, 116, 132), C(170, 210, 255) }, Hue = { { 350, 230, 1 }, { 345, 210, 1 } } },
    },
    Infrared = {
        { Name = "Ironbow", Swatch = { C(26, 26, 34), C(52, 54, 64), C(255, 120, 40) } },
        { Name = "Arctic Scan", Desc = "A cold scan: navy polymer, blue-steel fins and a heat ramp that runs from deep navy to cyan.",
          Swatch = { C(20, 28, 46), C(46, 58, 80), C(90, 220, 255) }, Hue = { { 280, 232, 1 }, { 350, 214, 1 }, { 22, 194, 1 } } },
        { Name = "Night Vision", Desc = "Phosphor green: black-olive polymer, olive fins and a heat ramp from dark moss to bright phosphor.",
          Swatch = { C(26, 30, 22), C(54, 60, 46), C(120, 255, 120) }, Hue = { { 280, 128, 1 }, { 350, 118, 1 }, { 22, 112, 1 } } },
    },
    -- (SKINS V3 bundle 3) TOURBILLON: whole palettes per colourway in the module (Set.Palettes) + painted maps per colourway
    Tourbillon = {
        { Name = "Blued", Swatch = { C(16, 22, 60), C(138, 74, 60), C(130, 255, 200) } },
        { Name = "Onyx", Desc = "Black lacquer and deep yellow gold, the lume a warm old-radium glow.",
          Swatch = { C(16, 16, 19), C(150, 108, 44), C(255, 210, 140) }, Hue = { { 230, 230, 0.12, 0.9 }, { 14, 38, 1.1, 1.08 }, { 155, 35, 0.55, 1 } } },
        { Name = "Sapphire Dial", Desc = "A deep teal dial, platinum for the gold and an ice-blue lume.",
          Swatch = { C(10, 44, 44), C(104, 108, 122), C(160, 220, 255) }, Hue = { { 230, 178, 1, 0.8 }, { 14, 225, 0.22, 0.95 }, { 155, 205, 0.75, 1 } } },
        { Name = "Ruby", Desc = "Oxblood lacquer and rose gold, the lume a soft champagne.",
          Swatch = { C(48, 8, 17), C(138, 78, 64), C(255, 226, 180) }, Hue = { { 230, 346, 1, 0.8 }, { 14, 14, 1, 1 }, { 155, 36, 0.3, 1 } } },
    },
    -- (SKINS V3 bundle 5) TACTILE: whole palettes per colourway in the module (Set.Palettes) + painted maps per colourway
    Tactile = {
        { Name = "Graphite", Swatch = { C(46, 44, 48), C(62, 65, 74), C(255, 110, 90) } },
        { Name = "Claret", Desc = "Deep claret soft-touch, warm gunmetal anodising, champagne-brass controls and a warm white standby light.",
          Swatch = { C(78, 26, 38), C(86, 80, 88), C(255, 212, 158) }, Hue = { { 22, 38, 0.55, 0.96 }, { 8, 32, 0.4, 1 }, { 240, 345, 1.25, 1 }, { 285, 350, 1.25, 1 } } },
        { Name = "Ultramarine", Desc = "Deep ultramarine soft-touch, silver anodising, yellow controls and a warm yellow light.",
          Swatch = { C(26, 40, 96), C(72, 80, 98), C(255, 206, 80) }, Hue = { { 22, 46, 1, 1 }, { 8, 42, 1, 1 }, { 280, 226, 1, 1 } } },
    },
    Slipstream = {
        { Name = "Racing Green", Swatch = { C(18, 58, 40), C(30, 31, 35), C(130, 110, 255) } },
        { Name = "Crimson Livery", Desc = "Deep crimson bodywork over carbon, a silver pinstripe and the violet tach.",
          Swatch = { C(60, 8, 16), C(30, 31, 35), C(130, 110, 255) }, Hue = { { 152, 354, 1.1, 0.9 }, { 42, 42, 0.1, 1 }, { 250, 250, 1, 1 } } },
        { Name = "Midnight Livery", Desc = "Midnight-navy bodywork over carbon, a silver pinstripe and a cyan tach.",
          Swatch = { C(10, 14, 40), C(30, 31, 35), C(90, 220, 255) }, Hue = { { 152, 230, 1.1, 0.75 }, { 42, 42, 0.1, 1 }, { 250, 193, 1, 1 } } },
        { Name = "Papaya", Desc = "Deep papaya-orange bodywork over carbon, a blue pinstripe and a blue tach.",
          Swatch = { C(92, 34, 10), C(30, 31, 35), C(80, 160, 255) }, Hue = { { 152, 22, 1.2, 1.35 }, { 42, 220, 1, 1 }, { 250, 214, 1, 1 } } },
    },
    -- (SKINS V3 bundle 6) CARAPACE: whole palettes per colourway in the module (Set.Palettes) + painted maps per colourway
    Carapace = {
        { Name = "Jewel", Swatch = { C(20, 74, 58), C(96, 62, 30), C(180, 255, 70) } },
        { Name = "Scarab Gold", Desc = "A golden scarab: amber-gold wing cases with a green-gold sheen, black lacquer and a warm lantern.",
          Swatch = { C(106, 72, 16), C(36, 30, 24), C(255, 190, 60) }, Hue = { { 160, 40, 1 }, { 270, 82, 1 }, { 85, 42, 1 } } },
        { Name = "Ruby Shell", Desc = "Wine-red wing cases turning blue-violet at the edges, bronze trim and a pink lantern.",
          Swatch = { C(90, 16, 40), C(96, 62, 30), C(255, 110, 170) }, Hue = { { 160, 340, 1 }, { 270, 255, 1 }, { 85, 330, 1 } } },
        { Name = "Blue Morpho", Desc = "Deep blue wing cases with a teal sheen, gunmetal trim and an aqua lantern.",
          Swatch = { C(18, 40, 110), C(44, 52, 70), C(80, 240, 255) }, Hue = { { 160, 222, 1 }, { 270, 186, 1 }, { 85, 188, 1 } } },
    },
    -- (SKINS V3 bundle 7) IRONRUNE: whole palettes per colourway in the module (Set.Palettes) + painted maps per colourway
    Ironrune = {
        { Name = "Hearthfire", Swatch = { C(36, 31, 30), C(66, 40, 26), C(255, 90, 30) } },
        { Name = "Frostforged", Desc = "Cold blue iron, weathered grey oak, pewter fittings and ice-blue glyphs.",
          Swatch = { C(30, 36, 48), C(52, 52, 56), C(120, 210, 255) }, Hue = { { 20, 200, 1, 1 }, { 25, 220, 0.1, 0.9 }, { 32, 215, 0.25, 0.9 } } },
        { Name = "Bloodforge", Desc = "Black iron, dark red-stained oak, dark copper fittings and crimson glyphs.",
          Swatch = { C(22, 17, 17), C(60, 17, 17), C(255, 50, 70) }, Hue = { { 20, 352, 1, 1 }, { 25, 0, 1.2, 0.95 }, { 32, 16, 1, 0.85 } } },
    },
    -- (SKINS V3 bundle 8) FISSION: whole palettes per colourway in the module (Set.Palettes) + painted maps per colourway
    Fission = {
        { Name = "Cherenkov", Swatch = { C(36, 40, 46), C(62, 74, 86), C(50, 130, 255) } },
        { Name = "Isotope", Desc = "Olive-black graphite, olive reactor steel and a green core.",
          Swatch = { C(30, 36, 24), C(58, 68, 48), C(120, 255, 90) }, Hue = { { 215, 105, 1 }, { 208, 95, 0.6 } } },
        { Name = "Hot Core", Desc = "Dark steel, warm bronze-grey shielding and an amber core.",
          Swatch = { C(36, 33, 33), C(80, 70, 64), C(255, 150, 40) }, Hue = { { 215, 30, 1 }, { 208, 20, 0.4 } } },
        { Name = "Plutonium", Desc = "Deep violet graphite, violet steel and a magenta core.",
          Swatch = { C(34, 24, 46), C(72, 60, 94), C(235, 70, 200) }, Hue = { { 215, 312, 1 }, { 208, 265, 1 } } },
    },
    -- (SKINS V3 bundle 9) PERMAFROST: whole palettes per colourway in the module (Set.Palettes) + painted maps per colourway
    Permafrost = {
        { Name = "Glacier", Swatch = { C(11, 27, 58), C(70, 94, 128), C(120, 225, 255) } },
        { Name = "Black Ice", Desc = "Near-black ice with a violet depth, dark steel, violet-white frost and a violet glow.",
          Swatch = { C(12, 12, 21), C(78, 72, 106), C(200, 170, 255) }, Hue = { { 215, 250, 0.45, 0.8 }, { 195, 265, 1, 1 } } },
        { Name = "Meltwater", Desc = "Deep teal glacier melt, sea-green steel, mint frost and an aqua glow.",
          Swatch = { C(8, 44, 52), C(58, 100, 104), C(90, 255, 220) }, Hue = { { 215, 188, 1, 0.95 }, { 195, 168, 1, 1 } } },
        { Name = "Ember Ice", Desc = "Slate-blue ice, warm iron steel, white frost and a smouldering ember glow frozen inside.",
          Swatch = { C(20, 25, 42), C(100, 84, 78), C(255, 140, 60) }, Hue = { { 215, 225, 0.6, 0.85 }, { 195, 24, 1, 1 } } },
    },
    -- (SKINS V3 bundle 11) ORBITER: whole palettes per colourway in the module (Set.Palettes) + painted maps per colourway
    Orbiter = {
        { Name = "Launch White", Swatch = { C(164, 160, 152), C(214, 84, 18), C(255, 140, 40) } },
        { Name = "Bright Gold", Desc = "Bright gold foil with white ceramic bands, black cells and a warm gold light.",
          Swatch = { C(190, 142, 36), C(166, 162, 154), C(255, 214, 110) }, Hue = { { 22, 42, 0.7, 1 } } },
        { Name = "Silver Foil", Desc = "Silver foil with red bands and stencils, black cells and a red status light.",
          Swatch = { C(142, 144, 150), C(184, 28, 28), C(255, 72, 60) }, Hue = { { 22, 0, 1.1, 0.9 } } },
        { Name = "Black Violet", Desc = "Black foil and cells with violet bands and a violet status light.",
          Swatch = { C(30, 28, 34), C(116, 56, 196), C(180, 120, 255) }, Hue = { { 22, 270, 0.9, 0.8 } } },
    },
    -- (SKINS V3 bundle 12) NECTAR: whole palettes per colourway in the module (Set.Palettes) + painted maps per colourway
    -- (SKINS V3 bundle 15) KINTSUGI: whole palettes per colourway in the module (Set.Palettes) + painted maps per colourway;
    -- the Hue rows tint the plain-part bits (theme / previews) from the celadon default
    Kintsugi = {
        { Name = "Celadon", Swatch = { C(34, 74, 58), C(160, 116, 42), C(255, 196, 80) } },
        { Name = "Indigo Glaze", Desc = "A deep indigo glaze pooling darker underneath, mended in gold.",
          Swatch = { C(14, 16, 42), C(150, 106, 38), C(255, 196, 80) }, Hue = { { 155, 233, 1.1, 0.6 } } },
        { Name = "Kaki", Desc = "A persimmon red-brown glaze, mended in gold.",
          Swatch = { C(90, 32, 14), C(170, 122, 44), C(255, 190, 90) }, Hue = { { 155, 16, 1.4, 1.1 } } },
        { Name = "Tenmoku", Desc = "A near-black brown glaze with copper seams and an ember light.",
          Swatch = { C(18, 12, 9), C(128, 66, 34), C(255, 140, 60) }, Hue = { { 155, 22, 0.6, 0.35 }, { 40, 22, 1 } } },
    },
    Nectar = {
        { Name = "Wildflower", Swatch = { C(74, 40, 16), C(118, 84, 32), C(255, 165, 30) } },
        { Name = "Buckwheat", Desc = "Espresso-dark wood, copper bands and a deep amber honey.",
          Swatch = { C(48, 26, 16), C(120, 66, 40), C(255, 130, 30) }, Hue = { { 35, 24, 1, 0.85 }, { 28, 18, 1, 0.8 } } },
        { Name = "Lavender Honey", Desc = "Deep plum wood, silver bands and a lilac-gold honey.",
          Swatch = { C(56, 28, 56), C(118, 116, 128), C(230, 170, 255) }, Hue = { { 35, 285, 0.7, 1 }, { 28, 300, 0.5, 0.9 } } },
    },
    -- (SKINS V3 bundle 16) LEADLIGHT: whole palettes per colourway in the module (Set.Palettes) + painted maps per colourway
    Leadlight = {
        { Name = "Hearthglow", Swatch = { C(46, 43, 48), C(168, 24, 26), C(255, 170, 50) } },
        { Name = "Evensong", Desc = "Blue-black iron, sapphire and violet glass with amber, a lilac light behind it.",
          Swatch = { C(40, 42, 50), C(62, 40, 142), C(244, 176, 74) }, Hue = { { 355, 250, 1 }, { 25, 265, 0.8 } } },
        { Name = "Verdigris", Desc = "Green-black iron, emerald and sea-green glass with gold, a pale green light behind it.",
          Swatch = { C(40, 48, 44), C(20, 112, 82), C(232, 192, 84) }, Hue = { { 355, 155, 1 }, { 25, 145, 0.8 } } },
    },
    -- (SKINS V3 bundle 14) MARQUEE: whole palettes per colourway in the module (Set.Palettes) + painted maps per colourway
    Marquee = {
        { Name = "Opening Night", Swatch = { C(22, 20, 27), C(150, 118, 70), C(255, 226, 170) } },
        { Name = "Emerald Room", Desc = "Deep emerald lacquer, champagne brass and warm bulbs.",
          Swatch = { C(8, 34, 26), C(150, 118, 70), C(255, 220, 150) }, Hue = { { 260, 160, 1.4, 1.2 } } },
        { Name = "Silver Screen", Desc = "Graphite lacquer, polished silver deco and cool white bulbs.",
          Swatch = { C(34, 34, 40), C(132, 136, 150), C(220, 235, 255) }, Hue = { { 40, 225, 0.15, 1 }, { 350, 230, 0.2, 0.9 } } },
    },
    -- (SKINS V3, anime line pilot) KIRAMEKI: whole palettes per colourway in the module (Set.Palettes) + painted maps per colourway
    Kirameki = {
        { Name = "Kirameki", Swatch = { C(204, 26, 112), C(236, 230, 238), C(250, 206, 28) } },
        { Name = "Lemon Soda", Desc = "Lemon-yellow cel panels, white plates, hot pink accents and a warm plum-brown ink.",
          Swatch = { C(238, 190, 24), C(238, 234, 226), C(255, 72, 150) }, Hue = { { 330, 48, 1, 1.05 }, { 50, 330, 1, 1 } } },
        { Name = "Midnight Idol", Desc = "Deep violet cel panels, white plates, cyan glow and pink stars.",
          Swatch = { C(70, 34, 130), C(232, 226, 246), C(150, 240, 255) }, Hue = { { 330, 268, 1, 0.8 }, { 50, 325, 1, 1 } } },
    },
    -- (skinsB) TORCHBEARER: the Season 1 champion arms + blade; whole palettes in the module + painted maps per colourway
    Torchbearer = {
        { Name = "Champion", Desc = "Ivory enamel armour, scarlet bands, polished gold and a classic orange flame.", Swatch = { C(202, 188, 162), C(164, 26, 32), C(212, 162, 62) } },
        { Name = "Bluefire", Desc = "Black enamel armour, sapphire bands, bright gold and a BLUE flame: a cyan-white core burning out to deep indigo.",
          Swatch = { C(44, 42, 48), C(38, 86, 180), C(70, 140, 255) } },
        { Name = "Inferno", Desc = "Scarlet enamel armour, ivory bands, bronze and a deep red flame.",
          Swatch = { C(146, 26, 26), C(214, 204, 182), C(196, 126, 62) } },
    },
    -- (SKINS V3 bundle 13) SILKFANG: whole palettes per colourway in the module (Set.Palettes) + painted maps per colourway
    Silkfang = {
        { Name = "Widow", Swatch = { C(14, 12, 16), C(112, 114, 128), C(255, 30, 60) } },
        { Name = "Recluse", Desc = "Deep brown lacquer, bronze web lines and an amber hourglass.",
          Swatch = { C(30, 18, 11), C(130, 96, 56), C(255, 160, 60) }, Hue = { { 350, 30, 1 }, { 305, 28, 0.8 } } },
        { Name = "Ghost Silk", Desc = "Charcoal lacquer, pearl-silver web lines and an ice-blue hourglass.",
          Swatch = { C(22, 24, 30), C(150, 154, 166), C(170, 220, 255) }, Hue = { { 350, 205, 0.35 }, { 305, 220, 0.4 } } },
        { Name = "Jewel Spider", Desc = "Deep teal lacquer, gold web lines and a magenta hourglass.",
          Swatch = { C(6, 24, 26), C(150, 118, 48), C(255, 60, 200) }, Hue = { { 350, 318, 1 }, { 305, 318, 1 } } },
    },
    Abyssal = {
        { Name = "Tide", Swatch = { C(12, 26, 70), C(30, 210, 190), C(150, 120, 230) } },
        { Name = "Blood Tide", Desc = "A red deep: blood-crimson glass and coral-orange glows over a black-wine hull.",
          Hue = { { 174, 352, 1 }, { 192, 2, 1 }, { 214, 345, 0.9, 0.85 }, { 252, 22, 1 } } },
        { Name = "Golden Reef", Desc = "A sunken treasure: gold light and amber glass over the abyss-navy hull.",
          Hue = { { 174, 42, 1 }, { 192, 38, 0.9 }, { 214, 214, 1 }, { 252, 285, 1 } } },
    },
    Aurora = {
        { Name = "Aurora", Swatch = { C(20, 40, 80), C(40, 200, 170), C(150, 110, 255) } },
        { Name = "Solar Flare", Desc = "A daytime aurora: gold and ember-orange ribbons over deep crimson.",
          Hue = { { 151, 38, 1 }, { 198, 15, 1 }, { 216, 350, 0.9, 0.8 }, { 265, 322, 1 } } },
        { Name = "Polar Night", Desc = "A violet aurora: purple and deep blue ribbons over the midnight hull.",
          Hue = { { 151, 275, 1 }, { 198, 245, 1 }, { 216, 232, 1 }, { 265, 300, 1 } } },
    },
    Cloud = {
        { Name = "Cloud Nine", Swatch = { C(70, 60, 140), C(150, 160, 255), C(255, 150, 200) } },
        { Name = "Sunset Nap", Desc = "Clouds at sunset: peach-orange and rose over dusky violet.",
          Hue = { { 45, 48, 1 }, { 163, 180, 1 }, { 231, 18, 0.9 }, { 253, 345, 0.9, 0.9 }, { 260, 330, 0.9 }, { 333, 40, 1 } } },
        { Name = "Starry Night", Desc = "Night clouds: deep navy and indigo with silver-violet moonlight.",
          Hue = { { 45, 50, 0.6 }, { 163, 200, 1 }, { 231, 226, 1, 0.65 }, { 253, 240, 1, 0.6 }, { 260, 250, 1, 0.65 }, { 333, 280, 1 } } },
    },
    Comet = {
        { Name = "Brass Comet", Swatch = { C(110, 20, 20), C(220, 160, 70), C(40, 200, 180) } },
        { Name = "Cobalt Comet", Desc = "Cobalt enamel and silver fittings with an amber glow.",
          Hue = { { 1, 220, 1 }, { 16, 215, 0.8 }, { 37, 205, 0.3, 1.05 }, { 172, 32, 1 } } },
        { Name = "Emerald Comet", Desc = "Emerald enamel and brass fittings with a violet glow.",
          Hue = { { 1, 150, 1 }, { 16, 140, 1 }, { 37, 42, 1 }, { 172, 282, 1 } } },
    },
    Fairy = {
        { Name = "Bloom", Swatch = { C(116, 80, 190), C(236, 124, 176), C(80, 200, 160) } },
        { Name = "Autumn Fae", Desc = "Rust, amber and russet leaves with golden glows.",
          Hue = { { 21, 35, 1 }, { 44, 44, 1 }, { 125, 30, 1 }, { 160, 45, 1 }, { 260, 18, 1, 0.85 }, { 264, 28, 1 }, { 332, 8, 1 } } },
        { Name = "Frost Fae", Desc = "Ice blue, frost white and silver over a midnight-blue glaze.",
          Hue = { { 21, 215, 0.6 }, { 44, 200, 0.3 }, { 125, 190, 1 }, { 160, 182, 1 }, { 260, 212, 1 }, { 264, 200, 0.8 }, { 332, 190, 0.7 } } },
    },
    Gacha = {
        { Name = "Gacha Pop", Swatch = { C(40, 32, 50), C(222, 46, 66), C(60, 140, 224) } },
        { Name = "Cyber Capsule", Desc = "Cyan capsules, violet toy plastic and magenta trim.",
          Hue = { { 45, 320, 1 }, { 161, 120, 1 }, { 211, 270, 1 }, { 266, 210, 1 }, { 334, 300, 1 }, { 353, 190, 1 } } },
        { Name = "Gold Capsule", Desc = "The jackpot machine: gold plastic, crimson trim and copper.",
          Hue = { { 45, 50, 1 }, { 161, 20, 1 }, { 211, 350, 1 }, { 266, 38, 1 }, { 334, 30, 1 }, { 353, 42, 0.9 } } },
    },
    Horizon = {
        { Name = "Event Horizon", Swatch = { C(30, 18, 52), C(206, 150, 62), C(180, 110, 255) } },
        { Name = "Crimson Horizon", Desc = "A red singularity: crimson void light and gold flare.",
          Hue = { { 31, 45, 1 }, { 35, 48, 1 }, { 249, 0, 1 }, { 255, 350, 1, 0.85 }, { 262, 355, 1 }, { 267, 0, 1 } } },
        { Name = "Emerald Horizon", Desc = "A green singularity: emerald void light and cyan flare.",
          Hue = { { 31, 190, 1 }, { 35, 185, 1 }, { 249, 160, 1 }, { 255, 160, 1 }, { 262, 165, 1 }, { 267, 150, 1 } } },
    },
    Ironclad = {
        { Name = "Hazard", Swatch = { C(40, 42, 48), C(240, 190, 20), C(230, 90, 20) } },
        { Name = "Arctic Ops", Desc = "Cold-weather plating: ice-cyan markings and steel-blue warning lights.",
          Hue = { { 3, 210, 1, 0.8 }, { 23, 200, 1 }, { 37, 195, 0.3 }, { 45, 190, 1 } } },
        { Name = "Toxic Ops", Desc = "Hazmat plating: lime and acid-green markings.",
          Hue = { { 3, 130, 1, 0.8 }, { 23, 110, 1 }, { 37, 80, 1 }, { 45, 95, 1 } } },
    },
    Jade = {
        { Name = "Dynasty", Swatch = { C(18, 84, 58), C(226, 170, 72), C(200, 30, 40) } },
        { Name = "Crimson Dynasty", Desc = "Cinnabar red lacquer with gold dragons and golden flames.",
          Hue = { { 28, 35, 1 }, { 40, 42, 1 }, { 153, 355, 1 }, { 156, 350, 1 }, { 330, 330, 1 }, { 356, 45, 1 } } },
        { Name = "Azure Dynasty", Desc = "Blue porcelain glaze with gold dragons and pale-blue flames.",
          Hue = { { 28, 192, 1 }, { 40, 45, 1 }, { 153, 212, 1 }, { 156, 216, 1 }, { 330, 230, 1 }, { 356, 200, 0.4 } } },
    },
    Kingyo = {
        { Name = "Matsuri", Swatch = { C(34, 46, 112), C(240, 100, 44), C(60, 190, 206) } },
        { Name = "Koi Gold", Desc = "Golden koi in midnight water: gold fins and amber lanterns.",
          Hue = { { 17, 45, 1 }, { 25, 48, 1 }, { 187, 190, 1 }, { 231, 230, 1 }, { 248, 248, 1 }, { 356, 35, 1 } } },
        { Name = "Ghost Koi", Desc = "Spirit koi: violet fins and pale-green water at night.",
          Hue = { { 17, 285, 1 }, { 25, 290, 1 }, { 187, 160, 1 }, { 231, 240, 1, 0.6 }, { 248, 250, 1 }, { 356, 300, 1 } } },
    },
    Kitsune = {
        { Name = "Matsuri", Swatch = { C(204, 46, 40), C(255, 120, 180), C(226, 168, 70) } },
        { Name = "Night Fox", Desc = "A midnight fox: indigo lacquer, blue foxfire and silver-gold trim.",
          Hue = { { 2, 232, 0.95, 0.8 }, { 21, 218, 0.95, 0.85 }, { 38, 44, 0.7 }, { 193, 178, 1 }, { 333, 196, 1 }, { 355, 240, 0.9, 0.8 } } },
        { Name = "Sakura Fox", Desc = "Spring at the shrine: cherry-blossom pink lacquer, lilac foxfire and mint charms.",
          Hue = { { 2, 338, 0.85, 1.08 }, { 21, 344, 0.8, 1.05 }, { 38, 36, 0.8 }, { 193, 158, 1 }, { 333, 290, 0.9 }, { 355, 322, 0.9 } } },
    },
    Mecha = {
        { Name = "Idol", Swatch = { C(36, 40, 88), C(232, 128, 180), C(70, 200, 170) } },
        { Name = "Strike Mecha", Desc = "Ace-pilot colours: cyan plates, navy armour and red warning lights.",
          Hue = { { 47, 352, 1 }, { 166, 45, 1 }, { 235, 235, 1 }, { 327, 200, 1 }, { 330, 198, 1 } } },
        { Name = "Crimson Mecha", Desc = "Crimson armour plates with ice-blue lights.",
          Hue = { { 47, 45, 1 }, { 166, 205, 1 }, { 235, 240, 1, 0.5 }, { 327, 355, 1 }, { 330, 352, 1 } } },
    },
    Neko = {
        { Name = "Cafe", Swatch = { C(34, 80, 160), C(226, 176, 62), C(206, 36, 50) } },
        { Name = "Black Cat", Desc = "A black cat's cafe: inky violet lacquer, red collar and gold.",
          Hue = { { 22, 0, 0.5, 0.6 }, { 42, 42, 1 }, { 209, 268, 0.6, 0.5 }, { 218, 270, 0.6, 0.4 }, { 330, 285, 1 }, { 344, 290, 1 }, { 355, 355, 1 } } },
        { Name = "Calico", Desc = "A calico cafe: orange and cream lacquer with brown patches.",
          Hue = { { 22, 30, 1 }, { 42, 45, 1 }, { 209, 25, 1 }, { 218, 20, 1, 0.7 }, { 330, 15, 1 }, { 344, 18, 1 }, { 355, 0, 1 } } },
    },
    Neon = {
        { Name = "Override", Swatch = { C(14, 10, 20), C(220, 30, 160), C(30, 220, 240) } },
        { Name = "Toxic Override", Desc = "Acid lime and ultraviolet code over void black.",
          Hue = { { 187, 280, 1 }, { 252, 252, 1 }, { 260, 260, 1 }, { 324, 100, 1 } } },
        { Name = "Inferno Override", Desc = "Molten orange and yellow code over a dark red void.",
          Hue = { { 187, 50, 1 }, { 252, 0, 1 }, { 260, 0, 1 }, { 324, 18, 1 } } },
    },
    Origami = {
        { Name = "Garden", Swatch = { C(26, 30, 64), C(220, 90, 100), C(204, 150, 44) } },
        { Name = "Crane Night", Desc = "Midnight paper: blue cranes and violet folds with gold leaf.",
          Hue = { { 40, 45, 1 }, { 187, 280, 1 }, { 232, 240, 1 }, { 349, 225, 1 }, { 353, 230, 1 } } },
        { Name = "Maple", Desc = "Autumn paper: maple red, orange and bark-brown folds.",
          Hue = { { 40, 40, 1 }, { 187, 0, 1 }, { 232, 15, 1, 0.6 }, { 349, 22, 1 }, { 353, 20, 1 } } },
    },
    Solaris = {
        { Name = "Eclipse", Swatch = { C(22, 20, 24), C(255, 184, 64), C(255, 130, 30) } },
        { Name = "Lunar", Desc = "A cold moon instead of a sun: silver and ice-blue light over black chrome.",
          Hue = { { 18, 214, 0.75, 0.95 }, { 27, 210, 0.6 }, { 37, 205, 0.32, 1.02 }, { 45, 200, 0.25, 1.04 } } },
        { Name = "Crimson Eclipse", Desc = "A blood moon: crimson light and scarlet flares over black chrome.",
          Hue = { { 18, 350, 1.05, 0.85 }, { 27, 352, 1 }, { 37, 356, 1.05 }, { 45, 8, 0.9 } } },
    },
    Starlight = {
        { Name = "Idol", Swatch = { C(58, 26, 104), C(255, 120, 190), C(255, 206, 110) } },
        { Name = "Starfall Blue", Desc = "A blue idol: sapphire and sky-cyan glows with gold stars.",
          Hue = { { 40, 45, 1 }, { 263, 210, 1 }, { 266, 220, 1 }, { 330, 190, 1 }, { 344, 200, 1 } } },
        { Name = "Eclipse Idol", Desc = "A dark idol: wine-black and crimson glows with gold stars.",
          Hue = { { 40, 40, 1 }, { 263, 350, 1 }, { 266, 0, 1, 0.6 }, { 330, 355, 1 }, { 344, 10, 1 } } },
    },
    Sugar = {
        { Name = "Sugar Rush", Swatch = { C(92, 50, 38), C(226, 70, 130), C(110, 214, 186) } },
        { Name = "Blue Raspberry", Desc = "Blue-raspberry candy, grape chocolate and lime.",
          Hue = { { 13, 250, 1, 0.8 }, { 100, 120, 1 }, { 164, 300, 1 }, { 336, 200, 1 }, { 350, 215, 1 } } },
        { Name = "Matcha", Desc = "Matcha green candy, cocoa and toasted cream.",
          Hue = { { 13, 30, 1 }, { 100, 100, 1 }, { 164, 40, 1 }, { 336, 120, 1 }, { 350, 100, 1 } } },
    },
    Summer = {
        { Name = "Ramune", Swatch = { C(14, 34, 72), C(70, 196, 206), C(240, 196, 40) } },
        { Name = "Sunset Beach", Desc = "Sunset soda: orange glass, rose and gold sand.",
          Hue = { { 27, 27, 1 }, { 47, 20, 1 }, { 138, 300, 1 }, { 184, 350, 1 }, { 204, 20, 1 }, { 220, 305, 1 }, { 349, 45, 1 } } },
        { Name = "Midnight Soda", Desc = "Night soda: indigo glass, violet fizz and cyan sparks.",
          Hue = { { 27, 27, 1 }, { 47, 190, 1 }, { 138, 200, 1 }, { 184, 280, 1 }, { 204, 250, 1 }, { 349, 320, 1 } } },
    },
    Tempest = {
        { Name = "Storm", Swatch = { C(26, 30, 70), C(90, 170, 255), C(170, 120, 255) } },
        { Name = "Crimson Storm", Desc = "Blood-red lightning over dark wine armour, ember-orange arcs and gold windings.",
          Hue = { { 22, 44, 1.05 }, { 211, 0, 1.05 }, { 235, 346, 1, 0.68 }, { 262, 26, 1.05 } } },
        { Name = "Toxic Storm", Desc = "Acid-green lightning over deep jungle-teal armour, sulphur-yellow arcs.",
          Hue = { { 22, 30, 1 }, { 211, 128, 1 }, { 235, 168, 1 }, { 262, 62, 1.05 } } },
    },
    Verdant = {
        { Name = "Verdant", Swatch = { C(52, 34, 24), C(60, 160, 70), C(240, 170, 40) } },
        { Name = "Autumn", Desc = "Fallen leaves: amber, rust and gold over dark bark.",
          Hue = { { 22, 15, 1 }, { 39, 50, 1 }, { 47, 40, 1 }, { 100, 35, 1 }, { 115, 25, 1 }, { 125, 10, 1 }, { 334, 10, 1 } } },
        { Name = "Sakura", Desc = "Blossom season: cherry pink leaves and plum bark glows.",
          Hue = { { 22, 20, 1 }, { 39, 320, 1 }, { 47, 45, 1 }, { 100, 340, 1 }, { 115, 330, 1 }, { 125, 300, 1, 0.7 }, { 334, 340, 1 } } },
    },
    Yami = {
        { Name = "Yami", Swatch = { C(42, 28, 54), C(236, 124, 178), C(150, 40, 100) } },
        { Name = "Blood Moon", Desc = "Crimson-black lace and blood-red hearts.",
          Hue = { { 265, 355, 1 }, { 272, 350, 1 }, { 274, 350, 1 }, { 327, 345, 1 }, { 331, 0, 1 } } },
        { Name = "Toxic Cute", Desc = "Slime-green lace and lime hearts over black.",
          Hue = { { 265, 150, 1 }, { 272, 140, 1, 0.8 }, { 274, 140, 1 }, { 327, 90, 1 }, { 331, 100, 1 } } },
    },
}
-- (Update 5 SKINS V3: the old sets' colourways are retired with their sets -- no store / F6 rows; saves keep their
-- Colorways table, inert. Backup: git tag skins-v2-backup, archive/skins_v2/)
for _, kind in ipairs({ "Solaris", "Abyssal", "Tempest", "Neon", "Ironclad", "Verdant", "Jade", "Starlight", "Kitsune", "Sugar", "Neko",
    "Origami", "Kingyo", "Cloud", "Gacha", "Yami", "Summer", "Mecha", "Fairy", "Aurora", "Horizon", "Comet" }) do
    Colorways.Sets[kind] = nil
end
-- (anchors sorted by "from" once, here)
for _, list in pairs(Colorways.Sets) do
    for _, cw in ipairs(list) do
        if cw.Hue then table.sort(cw.Hue, function(a, b) return a[1] < b[1] end) end
    end
end
local SwatchPending = true -- (filled once Map exists, below)

function Colorways.Has(kind: string?): boolean return kind ~= nil and Colorways.Sets[kind] ~= nil end
function Colorways.Count(kind: string?): number return kind and Colorways.Sets[kind] and #Colorways.Sets[kind] or 1 end
function Colorways.Info(kind: string?, v: number?): any return kind and Colorways.Sets[kind] and Colorways.Sets[kind][v or 1] end

-- "Tempest#2" -> "Tempest", 2 ; "Tempest" -> "Tempest", 1
function Colorways.Parse(key: string?): (string?, number)
    if type(key) ~= "string" then return key, 1 end
    local base, v = string.match(key, "^(.-)#(%d+)$")
    if base then return base, tonumber(v) or 1 end
    return key, 1
end
function Colorways.Key(kind: string?, v: number?): string?
    if not kind then return nil end
    if v and v > 1 then return kind .. "#" .. v end
    return kind
end

-- ===== the colour map =====
local function MapHSV(hue: any, h: number, s: number, v: number): (number, number, number)
    if not hue or #hue == 0 or s < 0.04 then return h, s, v end
    local hd = h * 360
    -- the NEAREST anchor round the wheel moves the hue by its own shift (blending between far-apart targets swept
    -- through other colours: a gold between a vermilion -> blue and a gold -> gold anchor turned lime)
    local best, bd = hue[1], 999
    for _, a in ipairs(hue) do
        local d = math.abs(((hd - a[1] + 180) % 360) - 180)
        if d < bd then best, bd = a, d end
    end
    local nh = (hd + best[2] - best[1]) % 360
    return nh / 360, math.clamp(s * (best[3] or 1), 0, 1), math.clamp(v * (best[4] or 1), 0, 1)
end
function Colorways.Map(kind: string?, v: number?, c: Color3): Color3
    local cw = Colorways.Info(kind, v)
    if not cw or not cw.Hue then return c end
    local h, s, val = c:ToHSV()
    return Color3.fromHSV(MapHSV(cw.Hue, h, s, val))
end
-- the C3 a set module builds its colours with: Color3.fromRGB through the colourway's map
function Colorways.C3For(kind: string?, v: number?): any
    local cw = Colorways.Info(kind, v)
    if not cw or not cw.Hue then return Color3.fromRGB end
    local cache = {}
    return function(r, g, b)
        local k = r * 65536 + g * 256 + b
        local hit = cache[k]
        if hit then return hit end
        local h, s, val = Color3.fromRGB(r, g, b):ToHSV()
        hit = Color3.fromHSV(MapHSV(cw.Hue, h, s, val))
        cache[k] = hit
        return hit
    end
end

-- the menu swatch of a colourway without its own: the original's three colours through its map
if SwatchPending then
    for kind, list in pairs(Colorways.Sets) do
        for v, cw in ipairs(list) do
            if not cw.Swatch and list[1].Swatch then
                cw.Swatch = {}
                for i, c in ipairs(list[1].Swatch) do cw.Swatch[i] = Colorways.Map(kind, v, c) end
            end
        end
    end
end

-- ===== ownership + choice (state.Colorways) =====
function Colorways.Rec(state: any, kind: string): any
    local all = type(state) == "table" and type(state.Colorways) == "table" and state.Colorways
    local r = all and all[kind]
    return type(r) == "table" and r or nil
end
function Colorways.Owns(state: any, kind: string, v: number): boolean
    if v == 1 then return true end
    local r = Colorways.Rec(state, kind)
    return r ~= nil and type(r.Own) == "table" and r.Own[tostring(v)] == true
end
-- the colourway an item wears (ref = "Glove:TempestGauntlets"; nil ref = the set's own choice)
function Colorways.VariantFor(state: any, kind: string?, ref: string?): number
    if not kind or not Colorways.Sets[kind] then return 1 end
    local r = Colorways.Rec(state, kind)
    if not r then return 1 end
    local items = type(r.Items) == "table" and r.Items or {}
    -- (0.97 ARMS: a glove or sleeve of the set also follows a pick made on the set's arms piece)
    local armsPick = ref and (ref:find("^Glove:") or ref:find("^Sleeve:")) and tonumber(items["Arms:" .. kind .. "Arms"]) or nil
    -- (owner 2026-10-14: "the kill effects should have the same colourway that you have equipped") a kill effect (and its
    -- banner) has no colourway pick of its own in the menu: it follows a pick made on the set's gun skins, then its melee,
    -- then any other piece, then the whole-set pick
    local killPick
    if ref and ref:find("^KillEffect:") and not items[ref] then
        for _, pre in ipairs({ "^WeaponSkin:", "^MeleeSkin:", "" }) do
            for k, val in pairs(items) do
                if not killPick and type(k) == "string" and k:find(pre) and tonumber(val) and Colorways.Owns(state, kind, tonumber(val)) then killPick = tonumber(val) end
            end
            if killPick then break end
        end
    end
    local v = (ref and tonumber(items[ref])) or armsPick or killPick or tonumber(r.Set) or 1
    if v < 1 or v > #Colorways.Sets[kind] or not Colorways.Owns(state, kind, v) then return 1 end
    return v
end
-- the F6 admin GIFTS rows outside the Cosmetics catalog (AdminPanel + AdminService): every colourway ("Colorway:Tempest:2")
-- and BOUND points amounts ("BoundPoints:100"). Same fields as a Cosmetics entry (Cat .. ":" .. Id = the ref).
Colorways.GIFT_POINTS = { 100, 500, 1000 }
function Colorways.GiftRows(): { any }
    local out = {}
    local kinds = {}
    for kind in pairs(Colorways.Sets) do table.insert(kinds, kind) end
    table.sort(kinds)
    for _, kind in ipairs(kinds) do
        for v, cw in ipairs(Colorways.Sets[kind]) do
            if v > 1 then
                table.insert(out, { Cat = "Colorway", Id = kind .. ":" .. v, Name = kind .. ": " .. cw.Name, Rarity = "Mythic", Unlock = "Robux",
                    Price = 99, Kind = kind, V = v })
            end
        end
    end
    for _, n in ipairs(Colorways.GIFT_POINTS) do
        table.insert(out, { Cat = "BoundPoints", Id = tostring(n), Name = n .. " " .. Colorways.CURRENCY, Rarity = "Legendary", Unlock = "Robux", Price = n * 99 // 100, Points = n })
    end
    -- (UPDATE 7, owner rule: every new currency is giftable) "Currency:<key>:<n>" -- give adds n, take removes n
    local okI, ItemData = pcall(require, script.Parent:WaitForChild("ItemData"))
    if okI and ItemData.CURRENCY_V5 then
        local keys = { "Prism" }
        for _, k in ipairs(ItemData.CURRENCY_V5) do table.insert(keys, k) end
        for _, k in ipairs(ItemData.APEX_MATS or {}) do table.insert(keys, k) end -- (UPDATE 7 APEX HUNT)
        for _, k in ipairs(ItemData.INK_MATS or {}) do table.insert(keys, k) end -- (UPDATE 7 MAP INKS)
        for _, k in ipairs(ItemData.PARTY_MATS or {}) do table.insert(keys, k) end -- (UPDATE 7 SHARED SPOILS)
        for _, k in ipairs(ItemData.TREE_MATS or {}) do table.insert(keys, k) end -- (2026-10-22 Unwind: passive refunds)
        for _, k in ipairs(ItemData.LOOT_MATS or {}) do table.insert(keys, k) end -- (UPDATE 8 RARITY v4: Ascension Essence)
        -- (FUTURE-PROOF 2026-10-25, owner rule "every currency giftable": + every live material in MaterialOrder the lists above missed
        -- -- Chart Shards and Rebirth Shards could not be gifted)
        for _, k in ipairs(ItemData.MaterialOrder or {}) do
            if not table.find(keys, k) and not (ItemData.RETIRED_MATERIALS and ItemData.RETIRED_MATERIALS[k]) then table.insert(keys, k) end
        end
        for _, k in ipairs(keys) do
            local def = ItemData.MaterialDefs[k]
            local n = (k == "Prism") and 50 or 5
            table.insert(out, { Cat = "Currency", Id = k .. ":" .. n, Name = n .. " " .. def.Name, Rarity = "Epic", Unlock = "Drop", Key = k, N = n })
        end
    end
    -- (CHASE ITEMS 2026-11-06, owner rule: every Zenith giftable -- the switch never hides these) "Zenith:<id>": give = one into
    -- the bag at the target's level, take = the first one of that id in the bag
    if okI and ItemData.ZENITH_ORDER then
        for _, id in ipairs(ItemData.ZENITH_ORDER) do
            local d = ItemData.Exotics[id]
            if d then table.insert(out, { Cat = "Zenith", Id = id, Name = "❖ " .. d.Name .. " (" .. (d.Kind == "Weapon" and d.Base or d.Slot) .. ")", Rarity = "Mythic", Unlock = "Drop" }) end
        end
    end
    -- (UPDATE 7 STASH TABS) "StashTab:<kind>": give adds one bought tab, take removes the newest empty one of that kind
    for _, k in ipairs({ "General", "Trade", "Gem", "Map" }) do
        table.insert(out, { Cat = "StashTab", Id = k, Name = string.upper(k) .. " stash tab", Rarity = "Epic", Unlock = "Robux" })
    end
    -- (UPDATE 8 phase 3, owner rule: everything giftable) SHOT MODS "ShotMod:<id>:<level>" -- give = one into the mod bag at that
    -- level, take = the first of that mod in the bag; "ShotMod:ALL:<level>" = one of every mod
    local okS, SMod = pcall(require, script.Parent:WaitForChild("ShotMods"))
    if okS then
        for _, lv in ipairs({ 1, 20 }) do
            table.insert(out, { Cat = "ShotMod", Id = "ALL:" .. lv, Name = "Every mod, level " .. lv, Rarity = "Legendary", Unlock = "Drop" })
        end
        for _, id in ipairs(SMod.ORDER) do
            local d = SMod.DEFS[id]
            table.insert(out, { Cat = "ShotMod", Id = id .. ":1", Name = "Mod: " .. d.Name .. " (" .. SMod.COLOR_NAME[d.Color] .. ")", Rarity = "Rare", Unlock = "Drop" })
        end
    end
    return out
end
Colorways.GIFT_LABELS = { Colorway = "COLORWAYS", BoundPoints = "BOUND POINTS", Currency = "CURRENCIES", StashTab = "STASH TABS", ShotMod = "MODS", Zenith = "ZENITHS" }

function Colorways.Points(state: any): number
    return type(state) == "table" and tonumber(state.BoundPoints) or 0
end

return Colorways
