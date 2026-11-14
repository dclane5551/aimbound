--!nocheck
-- UI THEMES (Cosmetics category "HudTheme"; owner, 2026-10-02: "the player UIs are just simple recolors ... make the
-- recolors droppable, and make the crazy Player HUD / UI purchasable with Robux. The UI and Player HUD should apply to
-- ALL UI in the game, not just our HP bar"). A theme restyles EVERY window, title bar, card, chip and HUD panel
-- (UITheme does the drawing):
--   * RECOLOURS (Unlock = "Drop"): colours + one soft particle layer (0.58) -- window glass, cards, title bars, borders, HUD bars. They drop from
--     bosses / elites / loot goblins in dungeon runs (DropFrom = chance per kill source, one roll per kill).
--   * PREMIUM (Unlock = "Robux"): everything a recolour does, plus a tiled art layer in every window (Tex / Tex2,
--     some scrolling), corner ornaments, a title emblem, an animated border (Shimmer / Flow / Pulse / Rainbow), its own
--     header typeface across the whole UI, ambient particles drifting inside windows, and an effect each time a window
--     opens (Flash / Glitch / Flare / Implode / Sweep).
-- Ids of the old themes are kept (saves): Seraphim / NeonCyber / Inferno / Prismatic are now the premium ones.
local HudThemes = {}
local C = Color3.fromRGB
local V2 = Vector2.new
-- (SKIN UI roll-out 2026-10-29, builder B: the clean look + damage numbers of NeonCyber / Inferno / VoidRift / InfernalPact)
local HB = require(script.Parent:WaitForChild("HudThemesB"))

local function P(top, bottom) return { Top = top, Bottom = bottom } end
-- drop chances per kill source (dungeon runs): recolours are uncommon boss / elite / goblin drops
local DROP = { Boss = 0.035, SuperBoss = 0.08, Goblin = 0.05, Elite = 0.006 }

HudThemes.List = {
    { Id = "Default", Name = "Standard", Rarity = "Common", Unlock = "Free", Desc = "The standard Aimbound look." },

    -- ===== recolours: drops =====
    { Id = "Midnight", Name = "Midnight", Rarity = "Uncommon", Unlock = "Drop", DropFrom = DROP, Desc = "Deep navy glass with silver edges.",
      Panel = P(C(22, 28, 52), C(8, 10, 22)), Card = P(C(30, 38, 66), C(16, 20, 38)), Title = P(C(70, 84, 130), C(28, 34, 62)),
      Accent = C(190, 200, 225), HpFill = C(220, 50, 70), HpBg = C(26, 12, 20), XpFill = C(150, 170, 255), Text = C(200, 215, 255), Ambient = "Bokeh", AmbientColor = C(150, 170, 255) },
    { Id = "Emerald", Name = "Emerald", Rarity = "Uncommon", Unlock = "Drop", DropFrom = DROP, Desc = "Jungle-dark glass with emerald trim.",
      Panel = P(C(16, 40, 30), C(6, 16, 12)), Card = P(C(24, 54, 40), C(12, 28, 20)), Title = P(C(40, 150, 96), C(14, 64, 40)),
      Accent = C(60, 220, 140), HpFill = C(60, 220, 120), HpBg = C(10, 30, 18), XpFill = C(140, 255, 190), Text = C(150, 255, 200), Ambient = "Bokeh", AmbientColor = C(60, 220, 140) },
    { Id = "Crimson", Name = "Crimson", Rarity = "Rare", Unlock = "Drop", DropFrom = DROP, Desc = "Blood-red glass with black-steel edges.",
      Panel = P(C(52, 14, 20), C(18, 4, 8)), Card = P(C(70, 22, 30), C(34, 10, 14)), Title = P(C(190, 40, 56), C(80, 12, 22)),
      Accent = C(255, 90, 100), HpFill = C(255, 60, 70), HpBg = C(40, 8, 12), XpFill = C(255, 140, 150), Text = C(255, 190, 195), Ambient = "Embers", AmbientColor = C(255, 80, 90) },
    { Id = "Ocean", Name = "Abyssal Ocean", Rarity = "Rare", Unlock = "Drop", DropFrom = DROP, Desc = "Deep-sea teal with a turquoise glow.",
      Panel = P(C(8, 40, 52), C(2, 14, 22)), Card = P(C(12, 56, 70), C(6, 28, 36)), Title = P(C(20, 150, 170), C(6, 60, 76)),
      Accent = C(70, 230, 230), HpFill = C(50, 210, 220), HpBg = C(4, 26, 30), XpFill = C(130, 245, 255), Text = C(170, 250, 255), Ambient = "Bubbles", AmbientColor = C(130, 245, 255) },
    { Id = "Sunset", Name = "Sunset", Rarity = "Rare", Unlock = "Drop", DropFrom = DROP, Desc = "Dusk orange fading into violet.",
      Panel = P(C(70, 30, 40), C(26, 12, 34)), Card = P(C(84, 40, 52), C(40, 18, 44)), Title = P(C(255, 130, 70), C(140, 50, 110)),
      Accent = C(255, 170, 90), HpFill = C(255, 120, 70), HpBg = C(40, 14, 20), XpFill = C(255, 190, 120), Text = C(255, 215, 180), Ambient = "Bokeh", AmbientColor = C(255, 170, 90) },
    { Id = "Royal", Name = "Royal Amethyst", Rarity = "Epic", Unlock = "Drop", DropFrom = DROP, Desc = "Amethyst glass with a gold edge.",
      Panel = P(C(46, 22, 70), C(16, 6, 30)), Card = P(C(60, 32, 90), C(30, 14, 48)), Title = P(C(150, 80, 220), C(64, 26, 110)),
      Accent = C(255, 205, 100), HpFill = C(200, 110, 255), HpBg = C(30, 10, 40), XpFill = C(255, 215, 130), Text = C(235, 210, 255), Ambient = "Sparkles", AmbientColor = C(255, 215, 130) },
    { Id = "Frost", Name = "Glacier", Rarity = "Epic", Unlock = "Drop", DropFrom = DROP, Desc = "Pale ice-blue glass with frosted white edges.",
      Panel = P(C(40, 62, 86), C(14, 24, 40)), Card = P(C(52, 78, 104), C(24, 38, 58)), Title = P(C(150, 210, 255), C(60, 110, 160)),
      Accent = C(220, 245, 255), HpFill = C(120, 210, 255), HpBg = C(14, 28, 40), XpFill = C(200, 240, 255), Text = C(220, 245, 255), Ambient = "Snowfall", AmbientColor = C(230, 248, 255) },
    { Id = "GoldRush", Name = "Gold Rush", Rarity = "Legendary", Unlock = "Drop", DropFrom = { Boss = 0.012, SuperBoss = 0.04, Goblin = 0.02 }, Desc = "Black glass and gold.",
      Panel = P(C(30, 26, 18), C(10, 9, 6)), Card = P(C(42, 36, 24), C(20, 17, 11)), Title = P(C(230, 180, 70), C(110, 76, 20)),
      Accent = C(255, 205, 90), HpFill = C(255, 190, 60), HpBg = C(40, 28, 8), XpFill = C(255, 230, 140), Text = C(255, 220, 130), Ambient = "Coins", AmbientColor = C(255, 205, 90) },

    -- ===== premium: earned by level (playtester 2026-10-02: "UI themes shouldn't be paid for since it's client side
    -- anyways, maybe event unlocks at most" -- they were R$ 499 each; now one every 10 levels) =====
    -- (owner 2026-10-04: "you get the seraphim UI bundle at level 10 ... It should only come in the bundle")
    { Id = "Seraphim", Name = "Seraphim Ascendant", Rarity = "Mythic", Unlock = "Bundle", How = "Only in the Seraphim Ascendant bundle",
      Desc = "Warm pearl-glass windows wrapped in living gold filigree, angel-wing emblems, gold dust drifting through every menu, and a burst of heavenly light whenever a window opens.",
      Panel = P(C(58, 52, 44), C(22, 19, 15)), Card = P(C(72, 64, 52), C(36, 31, 25)), Title = P(C(214, 170, 82), C(118, 82, 30)),
      Accent = C(255, 214, 120), Accent2 = C(255, 248, 220), HpFill = C(255, 226, 150), HpBg = C(50, 40, 24), XpFill = C(255, 214, 120), Text = C(255, 240, 205),
      Font = "RomanAntique", Tex = "Filigree", TexT = 0.78, TexTile = 230, TexScroll = V2(6, 3),
      Corner = "CornerSeraph", Emblem = "EmblemSeraph", Border = "Shimmer", BorderThick = 4,
      Ambient2 = "Sparkles", Ambient2Color = C(255, 244, 210), Watermark = "EmblemSeraph", CornerColor = C(255, 226, 150), Ambient = "Motes", AmbientColor = C(255, 220, 140), Open = "Flash", OpenColor = C(255, 230, 160),
      Numbers = { Font = "RomanAntique", Glyph = "◆", Pop = "Bounce", Normal = C(255, 244, 220), Crit = C(255, 210, 100), Weak = C(255, 255, 255), Stroke = C(120, 80, 20) } },
    { Id = "NeonCyber", Name = "Neon Overdrive", Rarity = "Mythic", Unlock = "Level", Level = 20,
      Desc = "Black glass and cyan neon: every tab is lit by a neon tube that flickers, circuit traces run in from the corners of the screen with packets of magenta light racing along them, and your damage numbers land RGB-split and snap together.",
      Panel = P(C(10, 14, 24), C(3, 4, 9)), Card = P(C(16, 22, 36), C(7, 9, 17)), Title = P(C(20, 120, 150), C(70, 10, 90)),
      Accent = C(60, 240, 255), Accent2 = C(255, 60, 220), HpFill = C(255, 60, 200), HpBg = C(30, 6, 26), XpFill = C(60, 240, 255), Text = C(150, 245, 255),
      Font = "Michroma", Tex = "Hex", TexT = 0.88, TexTile = 160, TexScroll = V2(0, -10), Tex2 = "Circuit", Tex2T = 0.86, Tex2Tile = 260, Tex2Scroll = V2(14, 0),
      Corner = "CornerCyber", Emblem = "EmblemCyber", Border = "Flow", BorderThick = 3,
      Ambient2 = "Bokeh", Ambient2Color = C(255, 60, 220), Watermark = "EmblemCyber", Ambient = "Data", AmbientColor = C(80, 240, 255), Open = "Glitch", OpenColor = C(255, 60, 220),
      Clean = HB.NeonCyber.Clean, Numbers = HB.NeonCyber.Numbers }, -- (SKIN UI: neon tubes + circuit traces; RGB-split glitch numbers)
    { Id = "Inferno", Name = "Hellforge", Rarity = "Mythic", Unlock = "Level", Level = 30,
      Desc = "Molten basalt and lava: every tab is a seam of flowing lava, jagged obsidian teeth rise from the corners of the screen with lava rims that breathe and embers drifting up, and your damage numbers are slammed down in hellfire.",
      Panel = P(C(40, 16, 10), C(12, 4, 2)), Card = P(C(52, 22, 14), C(24, 9, 5)), Title = P(C(220, 80, 20), C(90, 20, 6)),
      Accent = C(255, 120, 30), Accent2 = C(255, 220, 120), HpFill = C(255, 90, 30), HpBg = C(40, 12, 4), XpFill = C(255, 170, 60), Text = C(255, 200, 140),
      Font = "GrenzeGotisch", Tex = "Lava", TexT = 0.84, TexTile = 240, TexScroll = V2(0, -4), TexPulse = true,
      Corner = "CornerHell", Emblem = "EmblemHell", Border = "Pulse", BorderThick = 4,
      Ambient2 = "Bokeh", Ambient2Color = C(255, 90, 20), Watermark = "EmblemHell", Ambient = "Embers", AmbientColor = C(255, 140, 40), Open = "Flare", OpenColor = C(255, 120, 30),
      Clean = HB.Inferno.Clean, Numbers = HB.Inferno.Numbers }, -- (SKIN UI: lava seams + obsidian teeth; hellfire numbers)
    { Id = "VoidRift", Name = "Void Rift", Rarity = "Mythic", Unlock = "Level", Level = 40,
      Desc = "Deep space violet: every tab is a starlit rift, an event horizon turns in the corner of the screen with stars twinkling round it, and your damage numbers implode into place, crits wobbling, kills swallowed into a point.",
      Panel = P(C(26, 12, 44), C(6, 2, 14)), Card = P(C(36, 18, 58), C(14, 6, 28)), Title = P(C(130, 60, 220), C(40, 10, 80)),
      Accent = C(190, 110, 255), Accent2 = C(255, 120, 220), HpFill = C(190, 90, 255), HpBg = C(26, 8, 40), XpFill = C(255, 140, 230), Text = C(225, 200, 255),
      Font = "Sarpanch", Tex = "Stars", TexT = 0.55, TexTile = 220, TexScroll = V2(-5, 3), Tex2 = "VoidCracks", Tex2T = 0.82, Tex2Tile = 300, Tex2Pulse = true,
      Corner = "CornerVoid", Emblem = "EmblemVoid", Border = "Duo", BorderThick = 4,
      Ambient2 = "Sparkles", Ambient2Color = C(255, 140, 230), Watermark = "EmblemVoid", Ambient = "Stars", AmbientColor = C(220, 190, 255), Open = "Implode", OpenColor = C(170, 80, 255),
      Clean = HB.VoidRift.Clean, Numbers = HB.VoidRift.Numbers }, -- (SKIN UI: starlit rift tabs + an event horizon; numbers pulled in)
    -- INFERNAL set (2026-10-04): obsidian windows split by hellfire, the horned sigil emblem, violet + crimson
    { Id = "InfernalPact", Name = "Infernal Pact", Rarity = "Mythic", Unlock = "Robux", Price = 499, ProductId = 0, Set = "Infernal",
      Desc = "Obsidian, crimson and violet: every tab is sealed with the pact, a pact circle of sealed diamonds turns in the corner of the screen over a breathing crimson glow, and your damage numbers strike in crimson with a violet afterimage, crits stamped with a seal.",
      Panel = P(C(30, 12, 26), C(8, 2, 8)), Card = P(C(42, 18, 36), C(18, 6, 16)), Title = P(C(170, 30, 60), C(70, 20, 120)),
      Accent = C(235, 50, 75), Accent2 = C(170, 90, 255), HpFill = C(235, 45, 70), HpBg = C(34, 6, 18), XpFill = C(170, 90, 255), Text = C(255, 205, 220),
      Font = "GrenzeGotisch", Tex = "Infernal", TexT = 0.8, TexTile = 260, TexScroll = V2(0, -5), TexPulse = true,
      Corner = "CornerHell", Emblem = "EmblemInfernal", Border = "Duo", BorderThick = 4,
      Ambient2 = "Bokeh", Ambient2Color = C(170, 60, 255), Watermark = "EmblemInfernal", Ambient = "Embers", AmbientColor = C(235, 60, 90), Open = "Flare", OpenColor = C(200, 60, 255),
      Clean = HB.InfernalPact.Clean, Numbers = HB.InfernalPact.Numbers }, -- (SKIN UI: pact bars + a pact circle; numbers with a violet afterimage)
    { Id = "Prismatic", Name = "Prismatic", Rarity = "Mythic", Unlock = "Level", Level = 50,
      Desc = "Holographic glass that shifts through every colour, crystal corners, a full-spectrum border that rotates around every window, prism sparkles, and a rainbow sweep across each window as it opens.",
      Panel = P(C(26, 26, 36), C(8, 8, 14)), Card = P(C(36, 36, 50), C(16, 16, 24)), Title = P(C(120, 90, 200), C(40, 110, 170)),
      Accent = C(255, 255, 255), Accent2 = C(255, 120, 200), HpFill = C(255, 80, 120), HpBg = C(30, 14, 24), XpFill = C(140, 200, 255), Text = C(235, 235, 255),
      Font = "TitilliumWeb", Tex = "Holo", TexT = 0.86, TexTile = 300, TexScroll = V2(12, 6),
      Corner = "CornerPrism", Emblem = "EmblemPrism", Border = "Rainbow", BorderThick = 4,
      Ambient2 = "Bokeh", Ambient2Color = C(200, 220, 255), Watermark = "EmblemPrism", Ambient = "Sparkle", AmbientColor = C(255, 255, 255), Open = "Sweep", OpenColor = C(255, 255, 255),
      Numbers = { Font = "TitilliumWeb", Glyph = "◈", Pop = "Bounce", Rainbow = true, Normal = C(240, 240, 255), Stroke = C(20, 20, 40) } },
}
-- (SKIN UI roll-out 2026-10-29, builder A: the clean look of the drop recolours + Seraphim + Prismatic lives in HudThemesA)
do
    local okA, HA = pcall(function() return require(script.Parent:WaitForChild("HudThemesA")) end)
    for _, t in ipairs(HudThemes.List) do
        if okA and type(HA) == "table" and HA[t.Id] then t.Clean = HA[t.Id] end
    end
end
-- ===== SKIN SET THEMES (0.58, owner: "Bundles need to include UI themes for them, and the UI themes in general need to
-- feel higher effort"): one premium theme per SkinSets set, built from that set's own uploaded art (its tiling print
-- as the window glass, its emblem as the title emblem + a big faint WATERMARK in every window), a sprite corner, two
-- particle layers in the set's motif, an open effect, and its own hit-number style. Bundle only: ArmorFX adds
-- "HudTheme:<Id>" to the set's bundle (and to Added, so anyone who already owns the bundle gets it on load).
local SET_THEMES = {
    Solaris = { Name = "Solaris Eclipse", Desc = "Black-chrome windows lit by a captured sun: plasma glass, gilded corners, the eclipse emblem burning behind every menu, embers and sparks rising, and a solar flash as each window opens.",
        Panel = P(C(40, 26, 10), C(10, 7, 4)), Card = P(C(54, 36, 14), C(24, 16, 7)), Title = P(C(214, 140, 30), C(96, 50, 8)),
        Accent = C(255, 184, 64), Accent2 = C(255, 240, 190), HpFill = C(255, 170, 40), HpBg = C(40, 22, 6), XpFill = C(255, 214, 120), Text = C(255, 226, 160),
        Tex = "SolarisPlasma", TexT = 0.86, TexTile = 260, TexScroll = V2(4, -3), TexPulse = true, Corner = "CornerSeraph", CornerColor = C(255, 190, 80),
        Emblem = "EmblemSolaris", Watermark = "EmblemSolaris", WatermarkT = 0.88, Border = "Shimmer", BorderThick = 4,
        Ambient = "Embers", AmbientColor = C(255, 170, 60), Ambient2 = "Sparkles", Ambient2Color = C(255, 236, 170), Open = "Flash", OpenColor = C(255, 200, 90),
        Numbers = { Font = "Bodoni", Glyph = "✚", Pop = "Slam", Normal = C(255, 236, 200), Crit = C(255, 184, 64), Weak = C(255, 120, 40), Stroke = C(60, 30, 0) } },
    Abyssal = { Name = "Abyssal Tide", Desc = "Windows sunk in the deep: rippling abyss water, wave-crest corners, the leviathan emblem glowing below, bubbles rising through soft sea light, and every window opens in a burst of foam.",
        Panel = P(C(8, 40, 56), C(2, 10, 20)), Card = P(C(12, 56, 72), C(5, 24, 34)), Title = P(C(20, 150, 160), C(6, 56, 76)),
        Accent = C(40, 240, 220), Accent2 = C(180, 250, 255), HpFill = C(40, 220, 210), HpBg = C(4, 24, 30), XpFill = C(140, 250, 255), Text = C(180, 250, 255),
        Tex = "AbyssWater", TexT = 0.84, TexTile = 280, TexScroll = V2(8, 3), Tex2 = "AbyssScales", Tex2T = 0.93, Tex2Tile = 200,
        Corner = "CornerWave", CornerColor = C(80, 240, 230), Emblem = "EmblemAbyssal", Watermark = "EmblemAbyssal", WatermarkT = 0.88, Border = "Flow", BorderThick = 4,
        Ambient = "Bubbles", AmbientColor = C(170, 250, 255), Ambient2 = "Bokeh", Ambient2Color = C(40, 200, 220), Open = "Burst", OpenColor = C(120, 250, 240),
        Numbers = { Font = "Michroma", Glyph = "◉", Pop = "Implode", Normal = C(190, 250, 255), Crit = C(40, 240, 220), Weak = C(255, 120, 200), Stroke = C(0, 20, 30) } },
    Tempest = { Name = "Tempest", Desc = "A thunderstorm in glass: storm clouds rolling behind every menu, riveted storm-plate corners, the tempest emblem crackling, bolts flickering through the panels, and lightning flashes as windows open.",
        Panel = P(C(22, 26, 60), C(6, 8, 20)), Card = P(C(30, 36, 78), C(12, 15, 36)), Title = P(C(60, 110, 230), C(20, 30, 90)),
        Accent = C(90, 170, 255), Accent2 = C(220, 240, 255), HpFill = C(100, 180, 255), HpBg = C(10, 14, 36), XpFill = C(200, 230, 255), Text = C(200, 220, 255),
        Tex = "TempestStorm", TexT = 0.84, TexTile = 300, TexScroll = V2(-10, 0), Tex2 = "TempestPlate", Tex2T = 0.94, Tex2Tile = 180,
        Corner = "CornerRivet", CornerColor = C(110, 170, 255), Emblem = "EmblemTempest", Watermark = "EmblemTempest", WatermarkT = 0.88, Border = "Pulse", BorderThick = 4,
        Ambient = "Bolts", AmbientColor = C(170, 210, 255), Ambient2 = "Motes", Ambient2Color = C(90, 150, 255), Open = "Flash", OpenColor = C(150, 200, 255),
        Numbers = { Font = "Bangers", Glyph = "↯", Pop = "Slam", Normal = C(210, 230, 255), Crit = C(120, 190, 255), Weak = C(255, 255, 255), Stroke = C(10, 14, 50) } },
    Neon = { Name = "Neon Override", Desc = "A hacked terminal: live circuit traces under black glass, cyber corners, the override sigil in every window, data rain and magenta bokeh, and windows glitch open.",
        Panel = P(C(30, 6, 32), C(6, 2, 10)), Card = P(C(44, 10, 46), C(16, 4, 20)), Title = P(C(200, 30, 150), C(60, 10, 70)),
        Accent = C(255, 40, 170), Accent2 = C(40, 240, 255), HpFill = C(255, 50, 180), HpBg = C(30, 4, 24), XpFill = C(60, 240, 255), Text = C(255, 180, 235),
        Tex = "NeonCircuit", TexT = 0.85, TexTile = 240, TexScroll = V2(12, 0), Corner = "CornerCyber", CornerColor = C(255, 90, 200),
        Emblem = "EmblemNeon", Watermark = "EmblemNeon", WatermarkT = 0.88, Border = "Duo", BorderThick = 3,
        Ambient = "Data", AmbientColor = C(255, 60, 190), Ambient2 = "Bokeh", Ambient2Color = C(60, 220, 255), Open = "Glitch", OpenColor = C(40, 240, 255),
        Numbers = { Font = "Arcade", Glyph = "◈", Pop = "Glitch", Normal = C(255, 200, 240), Crit = C(40, 240, 255), Weak = C(255, 40, 170), Stroke = C(20, 0, 24) } },
    Ironclad = { Name = "Ironclad", Desc = "Heavy industry: steel deck-plate windows, hazard-striped riveted corners, the ironclad crest stamped behind every menu, sparks spitting from the welds, and a furnace flare as each window opens.",
        Panel = P(C(36, 34, 30), C(12, 12, 12)), Card = P(C(50, 46, 38), C(22, 21, 18)), Title = P(C(200, 150, 20), C(80, 60, 8)),
        Accent = C(235, 180, 20), Accent2 = C(255, 120, 30), HpFill = C(240, 180, 20), HpBg = C(34, 26, 6), XpFill = C(255, 140, 40), Text = C(255, 224, 140),
        Tex = "IronPlate", TexT = 0.85, TexTile = 220, Tex2 = "IronHazard", Tex2T = 0.95, Tex2Tile = 160,
        Corner = "CornerRivet", CornerColor = C(240, 190, 30), Emblem = "EmblemIronclad", Watermark = "EmblemIronclad", WatermarkT = 0.88, Border = "Pulse", BorderThick = 4,
        Ambient = "Embers", AmbientColor = C(255, 150, 40), Ambient2 = "Motes", Ambient2Color = C(255, 220, 120), Open = "Flare", OpenColor = C(255, 150, 30),
        Numbers = { Font = "Oswald", Glyph = "✲", Pop = "Slam", Normal = C(255, 236, 190), Crit = C(255, 190, 30), Weak = C(255, 110, 30), Stroke = C(20, 16, 4) } },
    Verdant = { Name = "Verdant", Desc = "Living wood: bark-grain windows wrapped in leafy vines, the verdant crest growing behind every menu, leaves falling past fireflies, and windows open in a burst of leaves.",
        Panel = P(C(20, 44, 22), C(6, 14, 6)), Card = P(C(30, 60, 30), C(12, 26, 12)), Title = P(C(80, 150, 50), C(26, 60, 18)),
        Accent = C(130, 210, 80), Accent2 = C(255, 200, 90), HpFill = C(120, 210, 80), HpBg = C(12, 30, 10), XpFill = C(255, 210, 110), Text = C(210, 255, 180),
        Tex = "VerdantBark", TexT = 0.86, TexTile = 240, Tex2 = "VerdantLeaf", Tex2T = 0.93, Tex2Tile = 200, Tex2Scroll = V2(3, 4),
        Corner = "CornerVine", CornerColor = C(130, 210, 90), Emblem = "EmblemVerdant", Watermark = "EmblemVerdant", WatermarkT = 0.88, Border = "Flow", BorderThick = 4,
        Ambient = "Leaves", AmbientColor = C(140, 210, 90), Ambient2 = "Motes", Ambient2Color = C(255, 230, 120), Open = "Burst", OpenColor = C(160, 230, 110),
        Numbers = { Font = "Fondamento", Glyph = "✿", Pop = "Bounce", Normal = C(220, 255, 190), Crit = C(255, 210, 90), Weak = C(255, 140, 90), Stroke = C(10, 24, 6) } },
    Jade = { Name = "Jade Dynasty", Desc = "Carved jade and black lacquer: dragon-scale windows, a gold folding-fan in every corner, the dragon seal behind each menu, gold coins and lantern light drifting, and windows burst open like firecrackers.",
        Panel = P(C(14, 50, 36), C(20, 6, 8)), Card = P(C(20, 66, 48), C(28, 10, 12)), Title = P(C(170, 30, 36), C(70, 10, 14)),
        Accent = C(220, 170, 70), Accent2 = C(60, 200, 140), HpFill = C(60, 200, 140), HpBg = C(10, 30, 20), XpFill = C(240, 190, 80), Text = C(255, 224, 150),
        Tex = "JadeScale", TexT = 0.86, TexTile = 220, Tex2 = "JadeSilk", Tex2T = 0.93, Tex2Tile = 260, Tex2Scroll = V2(4, 0),
        Corner = "CornerFan", CornerColor = C(230, 180, 80), Emblem = "EmblemJade", Watermark = "EmblemJade", WatermarkT = 0.88, Border = "Shimmer", BorderThick = 4,
        Ambient = "Coins", AmbientColor = C(240, 190, 80), Ambient2 = "Bokeh", Ambient2Color = C(220, 50, 50), Open = "Burst", OpenColor = C(240, 60, 50),
        Numbers = { Font = "Fondamento", Glyph = "龍", Pop = "Slam", Normal = C(255, 236, 190), Crit = C(240, 190, 80), Weak = C(230, 50, 50), Stroke = C(30, 4, 6) } },
    Starlight = { Name = "Starlight Idol", Desc = "A magical-girl stage: satin and starry-sky windows, lace corners, the heart-locket emblem behind every menu, hearts and sparkles floating up, and each window opens in a burst of stars.",
        Panel = P(C(70, 34, 110), C(28, 10, 52)), Card = P(C(90, 46, 136), C(44, 18, 74)), Title = P(C(236, 110, 190), C(130, 50, 160)),
        Accent = C(255, 120, 190), Accent2 = C(255, 220, 120), HpFill = C(255, 110, 190), HpBg = C(40, 10, 40), XpFill = C(255, 214, 120), Text = C(255, 224, 244),
        Tex = "StarlightSky", TexT = 0.82, TexTile = 260, TexScroll = V2(-4, 2), Tex2 = "StarlightSatin", Tex2T = 0.93, Tex2Tile = 220,
        Corner = "CornerLace", CornerColor = C(255, 170, 220), Emblem = "EmblemStarlight", Watermark = "EmblemStarlight", WatermarkT = 0.86, Border = "Shimmer", BorderThick = 4,
        Ambient = "Hearts", AmbientColor = C(255, 140, 200), Ambient2 = "Sparkles", Ambient2Color = C(255, 236, 160), Open = "Burst", OpenColor = C(255, 170, 220),
        Numbers = { Font = "FredokaOne", Glyph = "♥", Pop = "Bounce", Normal = C(255, 236, 250), Crit = C(255, 214, 110), Weak = C(255, 100, 180), Stroke = C(70, 10, 70) } },
    Kitsune = { Name = "Kitsune Matsuri", Desc = "A festival night: fox-fur and kimono-print windows, folding-fan corners, the fox mask behind every menu, sakura petals falling past blue foxfire, and windows open in a gust of petals.",
        Panel = P(C(90, 20, 26), C(30, 6, 10)), Card = P(C(110, 30, 36), C(50, 10, 16)), Title = P(C(214, 50, 50), C(110, 20, 30)),
        Accent = C(255, 120, 180), Accent2 = C(120, 200, 255), HpFill = C(255, 90, 110), HpBg = C(40, 8, 12), XpFill = C(140, 210, 255), Text = C(255, 230, 214),
        Tex = "KitsuneCloth", TexT = 0.84, TexTile = 240, Tex2 = "KitsuneFur", Tex2T = 0.94, Tex2Tile = 200,
        Corner = "CornerFan", CornerColor = C(255, 200, 210), Emblem = "EmblemKitsune", Watermark = "EmblemKitsune", WatermarkT = 0.86, Border = "Duo", BorderThick = 4,
        Ambient = "Petals", AmbientColor = C(255, 180, 210), Ambient2 = "Motes", Ambient2Color = C(110, 200, 255), Open = "Burst", OpenColor = C(255, 160, 200),
        Numbers = { Font = "LuckiestGuy", Glyph = "✿", Pop = "Bounce", Normal = C(255, 236, 226), Crit = C(130, 210, 255), Weak = C(255, 110, 170), Stroke = C(60, 6, 14) } },
    Sugar = { Name = "Sugar Rush", Desc = "A candy shop: candy-stripe and knit windows, frosting-lace corners, the sweets emblem behind every menu, hearts and sprinkle sparkles floating, and windows pop open in a candy burst.",
        Panel = P(C(130, 50, 96), C(56, 18, 46)), Card = P(C(150, 66, 116), C(76, 28, 64)), Title = P(C(242, 120, 178), C(150, 50, 110)),
        Accent = C(110, 214, 186), Accent2 = C(255, 240, 160), HpFill = C(242, 110, 170), HpBg = C(50, 14, 36), XpFill = C(110, 214, 186), Text = C(255, 240, 248),
        Tex = "SugarStripes", TexT = 0.86, TexTile = 220, TexScroll = V2(6, 6), Tex2 = "SugarKnit", Tex2T = 0.94, Tex2Tile = 180,
        Corner = "CornerLace", CornerColor = C(255, 250, 255), Emblem = "EmblemSugar", Watermark = "EmblemSugar", WatermarkT = 0.86, Border = "Rainbow", BorderThick = 4,
        Ambient = "Hearts", AmbientColor = C(255, 170, 210), Ambient2 = "Sparkles", Ambient2Color = C(140, 240, 210), Open = "Burst", OpenColor = C(255, 200, 230),
        Numbers = { Font = "FredokaOne", Glyph = "♥", Pop = "Bounce", Normal = C(255, 244, 250), Crit = C(130, 230, 200), Weak = C(255, 110, 170), Stroke = C(90, 20, 60) } },
    Neko = { Name = "Neko Cafe", Desc = "A lucky-cat cafe: printed cloth windows, golden lace corners, the beckoning cat behind every menu, paw prints and lucky coins drifting, and each window opens in a burst of paws.",
        Panel = P(C(30, 70, 120), C(10, 26, 56)), Card = P(C(40, 90, 146), C(18, 40, 80)), Title = P(C(80, 160, 230), C(30, 70, 140)),
        Accent = C(226, 176, 62), Accent2 = C(255, 120, 120), HpFill = C(240, 90, 100), HpBg = C(30, 10, 14), XpFill = C(240, 200, 90), Text = C(255, 250, 240),
        Tex = "NekoCloth", TexT = 0.85, TexTile = 230, Corner = "CornerLace", CornerColor = C(240, 196, 90),
        Emblem = "EmblemNeko", Watermark = "EmblemNeko", WatermarkT = 0.86, Border = "Shimmer", BorderThick = 4,
        Ambient = "Paws", AmbientColor = C(255, 240, 220), Ambient2 = "Coins", Ambient2Color = C(240, 196, 80), Open = "Burst", OpenColor = C(255, 220, 140),
        Numbers = { Font = "FredokaOne", Glyph = "❀", Pop = "Bounce", Normal = C(255, 252, 240), Crit = C(240, 196, 80), Weak = C(240, 80, 90), Stroke = C(14, 30, 70) } },
    Origami = { Name = "Origami Garden", Desc = "Folded paper: washi-print windows, folding-fan corners, the paper crane behind every menu, paper petals tumbling past soft lantern light, and windows unfold in a flutter of petals.",
        Panel = P(C(14, 70, 84), C(6, 28, 36)), Card = P(C(20, 90, 104), C(10, 42, 52)), Title = P(C(232, 92, 108), C(120, 40, 60)),
        Accent = C(232, 170, 46), Accent2 = C(255, 250, 240), HpFill = C(232, 92, 108), HpBg = C(30, 10, 14), XpFill = C(240, 200, 90), Text = C(255, 244, 232),
        Tex = "OrigamiPaper", TexT = 0.84, TexTile = 220, Corner = "CornerFan", CornerColor = C(255, 240, 220),
        Emblem = "EmblemOrigami", Watermark = "EmblemOrigami", WatermarkT = 0.86, Border = "Flow", BorderThick = 4,
        Ambient = "Petals", AmbientColor = C(255, 244, 232), Ambient2 = "Bokeh", Ambient2Color = C(240, 180, 80), Open = "Burst", OpenColor = C(255, 240, 220),
        Numbers = { Font = "PatrickHand", Glyph = "◆", Pop = "Bounce", Normal = C(255, 248, 236), Crit = C(240, 190, 60), Weak = C(240, 90, 110), Stroke = C(10, 40, 50) } },
    Kingyo = { Name = "Kingyo Matsuri", Desc = "A goldfish festival: printed yukata windows, wave corners, the goldfish lantern behind every menu, bubbles rising past orange lantern glow, and windows open in a splash.",
        Panel = P(C(26, 50, 110), C(8, 14, 44)), Card = P(C(36, 66, 136), C(14, 24, 66)), Title = P(C(240, 100, 44), C(130, 34, 30)),
        Accent = C(240, 100, 44), Accent2 = C(255, 230, 200), HpFill = C(240, 90, 50), HpBg = C(34, 10, 8), XpFill = C(120, 200, 255), Text = C(255, 244, 232),
        Tex = "KingyoCloth", TexT = 0.84, TexTile = 240, TexScroll = V2(5, 0), Corner = "CornerWave", CornerColor = C(255, 160, 90),
        Emblem = "EmblemKingyo", Watermark = "EmblemKingyo", WatermarkT = 0.86, Border = "Duo", BorderThick = 4,
        Ambient = "Bubbles", AmbientColor = C(200, 230, 255), Ambient2 = "Bokeh", Ambient2Color = C(255, 140, 60), Open = "Burst", OpenColor = C(255, 160, 90),
        Numbers = { Font = "LuckiestGuy", Glyph = "◉", Pop = "Bounce", Normal = C(255, 244, 232), Crit = C(255, 150, 60), Weak = C(255, 70, 60), Stroke = C(10, 20, 60) } },
    Cloud = { Name = "Cloud Nine", Desc = "A daydream: pastel sky windows, puffy cloud corners, the sleepy cloud behind every menu, sparkles and soft dream-light drifting, and each window opens in a puff of stars.",
        Panel = P(C(110, 80, 180), C(40, 30, 100)), Card = P(C(130, 100, 200), C(60, 46, 124)), Title = P(C(236, 120, 172), C(140, 80, 190)),
        Accent = C(255, 230, 120), Accent2 = C(255, 255, 255), HpFill = C(236, 120, 172), HpBg = C(40, 20, 60), XpFill = C(255, 230, 120), Text = C(255, 244, 252),
        Tex = "CloudSky", TexT = 0.8, TexTile = 300, TexScroll = V2(8, 0), Corner = "CornerCloud", CornerColor = C(255, 255, 255), CornerT = 0.1,
        Emblem = "EmblemCloud", Watermark = "EmblemCloud", WatermarkT = 0.84, Border = "Shimmer", BorderThick = 4,
        Ambient = "Sparkles", AmbientColor = C(255, 240, 170), Ambient2 = "Bokeh", Ambient2Color = C(255, 255, 255), Open = "Burst", OpenColor = C(255, 250, 220),
        Numbers = { Font = "FredokaOne", Glyph = "❁", Pop = "Bounce", Normal = C(255, 250, 255), Crit = C(255, 230, 120), Weak = C(236, 110, 170), Stroke = C(60, 40, 120) } },
    Gacha = { Name = "Gacha Pop", Desc = "A capsule-toy arcade: printed toy windows, lace corners, the capsule machine behind every menu, capsules bubbling up past jackpot sparkles, and every window opens like a prize popping.",
        Panel = P(C(130, 40, 90), C(46, 14, 50)), Card = P(C(150, 54, 110), C(70, 22, 70)), Title = P(C(222, 46, 66), C(120, 20, 60)),
        Accent = C(236, 188, 40), Accent2 = C(120, 220, 255), HpFill = C(236, 70, 110), HpBg = C(44, 10, 24), XpFill = C(236, 188, 40), Text = C(255, 248, 240),
        Tex = "GachaPrint", TexT = 0.85, TexTile = 220, TexScroll = V2(0, -5), Corner = "CornerLace", CornerColor = C(255, 214, 80),
        Emblem = "EmblemGacha", Watermark = "EmblemGacha", WatermarkT = 0.86, Border = "Rainbow", BorderThick = 4,
        Ambient = "Bubbles", AmbientColor = C(255, 200, 230), Ambient2 = "Sparkles", Ambient2Color = C(255, 220, 90), Open = "Burst", OpenColor = C(255, 214, 90),
        Numbers = { Font = "LuckiestGuy", Glyph = "★", Pop = "Bounce", Rainbow = true, Normal = C(255, 248, 240), Stroke = C(70, 10, 40) } },
    Yami = { Name = "Yami Kawaii", Desc = "Cute and spooky: printed lace-and-stitches windows, dark lace corners, the bat bunny behind every menu, bats flitting past floating hearts, and windows open in a flutter of bats.",
        Panel = P(C(56, 30, 70), C(14, 8, 20)), Card = P(C(74, 40, 92), C(26, 14, 36)), Title = P(C(160, 80, 160), C(60, 24, 70)),
        Accent = C(236, 124, 178), Accent2 = C(160, 120, 216), HpFill = C(236, 110, 170), HpBg = C(30, 10, 26), XpFill = C(170, 130, 230), Text = C(255, 228, 244),
        Tex = "YamiPrint", TexT = 0.85, TexTile = 220, Corner = "CornerLace", CornerColor = C(200, 120, 190),
        Emblem = "EmblemYami", Watermark = "EmblemYami", WatermarkT = 0.86, Border = "Pulse", BorderThick = 4,
        Ambient = "Bats", AmbientColor = C(150, 110, 200), Ambient2 = "Hearts", Ambient2Color = C(236, 124, 178), Open = "Burst", OpenColor = C(236, 124, 178),
        Numbers = { Font = "Creepster", Glyph = "♥", Pop = "Implode", Normal = C(255, 228, 244), Crit = C(180, 140, 240), Weak = C(236, 90, 160), Stroke = C(20, 6, 26) } },
    Summer = { Name = "Ramune Summer", Desc = "A summer festival: soda-print windows, rolling wave corners, the ramune bottle behind every menu, fizz bubbles rising past sunny sparkles, and windows pop open like a soda.",
        Panel = P(C(26, 90, 150), C(8, 34, 70)), Card = P(C(36, 110, 176), C(14, 50, 96)), Title = P(C(80, 176, 236), C(30, 90, 160)),
        Accent = C(240, 196, 40), Accent2 = C(236, 96, 122), HpFill = C(236, 96, 122), HpBg = C(30, 10, 16), XpFill = C(240, 210, 80), Text = C(255, 252, 236),
        Tex = "SummerPrint", TexT = 0.85, TexTile = 230, TexScroll = V2(4, 0), Corner = "CornerWave", CornerColor = C(200, 240, 255),
        Emblem = "EmblemSummer", Watermark = "EmblemSummer", WatermarkT = 0.86, Border = "Flow", BorderThick = 4,
        Ambient = "Bubbles", AmbientColor = C(200, 245, 255), Ambient2 = "Sparkles", Ambient2Color = C(255, 230, 110), Open = "Burst", OpenColor = C(200, 245, 255),
        Numbers = { Font = "FredokaOne", Glyph = "◈", Pop = "Bounce", Normal = C(255, 252, 236), Crit = C(255, 214, 60), Weak = C(240, 90, 120), Stroke = C(10, 40, 80) } },
    Mecha = { Name = "Mecha Idol", Desc = "An idol robot on stage: armour-panel windows, riveted corners, the idol head behind every menu, music notes floating past stage-light data, and windows open in a stage burst.",
        Panel = P(C(40, 34, 90), C(12, 10, 34)), Card = P(C(54, 46, 116), C(22, 18, 56)), Title = P(C(232, 128, 180), C(110, 50, 140)),
        Accent = C(70, 200, 170), Accent2 = C(255, 140, 200), HpFill = C(232, 120, 180), HpBg = C(30, 10, 34), XpFill = C(70, 220, 190), Text = C(255, 240, 250),
        Tex = "MechaPanels", TexT = 0.85, TexTile = 220, Corner = "CornerRivet", CornerColor = C(110, 230, 200),
        Emblem = "EmblemMecha", Watermark = "EmblemMecha", WatermarkT = 0.86, Border = "Duo", BorderThick = 4,
        Ambient = "Notes", AmbientColor = C(255, 170, 220), Ambient2 = "Data", Ambient2Color = C(80, 230, 200), Open = "Burst", OpenColor = C(255, 160, 210),
        Numbers = { Font = "Arcade", Glyph = "♪", Pop = "Glitch", Normal = C(255, 240, 250), Crit = C(80, 240, 210), Weak = C(255, 120, 190), Stroke = C(20, 10, 50) } },
    Fairy = { Name = "Fairy Bloom", Desc = "A fairy meadow: flower-meadow windows, vine corners, the fairy wing emblem behind every menu, petals drifting past glittering sparkles, and each window opens in a bloom of petals.",
        Panel = P(C(80, 56, 130), C(30, 20, 64)), Card = P(C(100, 72, 156), C(46, 30, 90)), Title = P(C(190, 150, 236), C(90, 60, 160)),
        Accent = C(80, 220, 170), Accent2 = C(255, 170, 210), HpFill = C(236, 124, 176), HpBg = C(34, 14, 40), XpFill = C(90, 230, 180), Text = C(255, 244, 252),
        Tex = "FairyMeadow", TexT = 0.84, TexTile = 240, TexScroll = V2(3, 2), Corner = "CornerVine", CornerColor = C(130, 230, 180),
        Emblem = "EmblemFairy", Watermark = "EmblemFairy", WatermarkT = 0.86, Border = "Shimmer", BorderThick = 4,
        Ambient = "Petals", AmbientColor = C(255, 190, 220), Ambient2 = "Sparkles", Ambient2Color = C(170, 255, 220), Open = "Burst", OpenColor = C(255, 200, 230),
        Numbers = { Font = "FredokaOne", Glyph = "✿", Pop = "Bounce", Normal = C(255, 244, 252), Crit = C(110, 240, 190), Weak = C(255, 120, 180), Stroke = C(50, 20, 80) } },
}
HudThemes.BySet = {}
do
    local Art = require(script.Parent:WaitForChild("CosmeticArt"))
    local okS, SkinSets = pcall(function() return require(script.Parent:WaitForChild("SkinSets")) end)
    for _, set in ipairs(okS and SkinSets.List or {}) do
        -- (SKINS V3: a set may bring its theme itself, Set.Theme -- same fields as a SET_THEMES entry)
        local def = SET_THEMES[set.Kind] or (type(set.Theme) == "table" and set.Theme) or nil
        if def then
            -- the set's own art (tiling prints, emblem) under its keys; the kawaii sets' emblem only lives in Hero
            for k, id in pairs(set.Art or {}) do if Art[k] == nil then Art[k] = id end end
            local emb = "Emblem" .. set.Kind
            if Art[emb] == nil and set.Hero and set.Hero.Emblem then Art[emb] = set.Hero.Emblem end
            def.Id = set.Kind .. "Theme"
            def.Set = set.Kind
            def.Rarity = "Mythic"
            -- (2026-10-14, owner: "UI themes doesnt even have anything in the store"): a set theme is sold on its own too
            -- (BOUND points, Cosmetics.BP_BY_CAT.HudTheme) as well as in its bundle (bundle owners get it via b.Added)
            def.Unlock = "Robux"
            def.Price = def.Price or 299
            def.How = "In the store, or in the " .. ((set.Bundle and set.Bundle.Name) or (def.Name .. " bundle"))
            table.insert(HudThemes.List, def)
            HudThemes.BySet[set.Kind] = def
        end
    end
end
HudThemes.ById = {}
for _, t in ipairs(HudThemes.List) do HudThemes.ById[t.Id] = t end

-- (Update 6, owner: "UI colors need to change too with new bundle colorways") a set theme in a colourway: every colour
-- of the theme (panels, title bars, accents, HP / XP bars, numbers, corners, ambient, open effect) goes through the
-- colourway's hue map (Colorways.Map -- the same map that recolours the rest of the set). One cached table per
-- "<Id>#<v>" (UITheme.Apply skips a theme it already shows by identity). Images keep their own colours.
HudThemes.Variants = {}
-- vt = the same theme as the colourway's own module copy builds it (SkinFX.Sets["<Kind>#<v>"].Theme): a colour the set
-- already takes from its palette there (differs from the original) is used as it is; a fixed one goes through the map
local function MapColors(t: any, fn: (Color3) -> Color3, seen: any, vt: any): any
    if seen[t] then return seen[t] end
    local out = {}
    seen[t] = out
    for k, v in pairs(t) do
        local w = type(vt) == "table" and vt[k] or nil
        if typeof(v) == "Color3" then out[k] = (typeof(w) == "Color3" and w ~= v) and w or fn(v)
        elseif type(v) == "table" then out[k] = MapColors(v, fn, seen, w)
        else out[k] = v end
    end
    return out
end
function HudThemes.Variant(t: any, v: number): any
    if not (t and t.Set) or not v or v <= 1 then return t end
    local key = t.Id .. "#" .. v
    local hit = HudThemes.Variants[key]
    if hit then return hit end
    local ok, Colorways = pcall(require, script.Parent:WaitForChild("Colorways"))
    if not (ok and Colorways.Info(t.Set, v)) then return t end
    local okF, SkinFX = pcall(require, script.Parent:WaitForChild("SkinFX"))
    local vset = okF and SkinFX.Sets[t.Set .. "#" .. v] or nil
    local out = MapColors(t, function(c) return Colorways.Map(t.Set, v, c) end, {}, vset and vset.Theme or nil)
    -- (SKIN UI roll-out 2026-10-29, builder A) the clean palette + the theme's numbers are always built from the colourway copy's
    -- own palette: take them AS THEY ARE. Kept only where they differed from colourway 1, a colour two colourways share (a brass,
    -- a ruby, a gold) went through the hue map (Marquee's brass came out magenta), and the numbers' accent functions stayed
    -- colourway 1's (a Magma theme drew Magnet-magenta spikes on numbers with no skin in hand).
    local vt = vset and type(vset.Theme) == "table" and vset.Theme or nil
    if vt and type(vt.Clean) == "table" then out.Clean = vt.Clean end
    if vt and type(vt.Numbers) == "table" then out.Numbers = vt.Numbers end
    out.Variant, out.BaseId = v, t.Id
    HudThemes.Variants[key] = out
    return out
end
-- the colourway a set theme wears: the pick made on the theme itself, else the set's ("Use on the whole set")
function HudThemes.VariantOf(state: any, t: any): number
    if not (t and t.Set) then return 1 end
    local ok, Colorways = pcall(require, script.Parent:WaitForChild("Colorways"))
    return ok and Colorways.VariantFor(state, t.Set, "HudTheme:" .. t.Id) or 1
end

function HudThemes.For(state: any): any
    local eq = type(state) == "table" and type(state.CosmeticsEquipped) == "table" and state.CosmeticsEquipped.HudTheme
    local t = HudThemes.ById[eq or ""] or HudThemes.ById.Default
    return HudThemes.Variant(t, HudThemes.VariantOf(state, t))
end

-- one drop roll for a kill source ("Boss" / "SuperBoss" / "Goblin" / "Elite"): a random recolour the player doesn't
-- own yet, or nil. owns(id) -> bool.
function HudThemes.RollDrop(src: string, owns: (string) -> boolean): any
    local pool, total = {}, 0
    for _, t in ipairs(HudThemes.List) do
        local ch = t.Unlock == "Drop" and type(t.DropFrom) == "table" and t.DropFrom[src]
        if ch and ch > 0 and not owns(t.Id) then table.insert(pool, t); total += ch end
    end
    if #pool == 0 or math.random() >= total / #pool then return nil end -- (the average chance of what's left)
    local r = math.random() * total
    for _, t in ipairs(pool) do
        r -= t.DropFrom[src]
        if r <= 0 then return t end
    end
    return pool[#pool]
end

return HudThemes
