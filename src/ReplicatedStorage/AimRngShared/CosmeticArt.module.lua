--!nocheck
-- Uploaded art for premium cosmetics (tools/make_cosmetic_art.py -> art/cosmetics/*.png, uploaded with the MCP
-- upload_image tool). Seamless TEXTURES go on glove / sleeve blocks (Texture instances) and UI theme windows (tiled
-- ImageLabels); CORNERS / EMBLEMS are UI theme ornaments; FX are sprites for particles and billboards.
local A = "rbxassetid://"
return {
    -- seamless textures
    Filigree = A .. "109745808839090", VoidCracks = A .. "110567160223998", Lava = A .. "128061016371596",
    Circuit = A .. "96395517334077", Hex = A .. "73956641365168", Holo = A .. "70706422723502",
    Carbon = A .. "133510780848202", Brass = A .. "98921580394299", Stars = A .. "116394460825347",
    Scales = A .. "112988745813001",
    -- UI theme window corners (top-left; rotated for the others)
    CornerSeraph = A .. "80781607914133", CornerCyber = A .. "120111555419187", CornerHell = A .. "126796837556031",
    CornerVoid = A .. "103732789901666", CornerPrism = A .. "100895967406436",
    -- title emblems (512x256); the Seraph one is also the Seraphim kill banner
    EmblemSeraph = A .. "109839951249611", EmblemCyber = A .. "94210547256888", EmblemHell = A .. "93373746486476",
    EmblemVoid = A .. "130507207585754", EmblemPrism = A .. "75593171351056",
    -- INFERNAL set (2026-10-04, tools/make_infernal_art.py): the horned sigil (kill banner) + obsidian / hellfire cracks
    EmblemInfernal = A .. "85769662532993", Infernal = A .. "86150271711502",
    -- fx sprites
    Glow = A .. "128322159183195", Rays = A .. "106708454166038", Feather = A .. "80460881443909",
    -- UI THEMES v2 (0.58, tools/make_theme_sprites.py): white sprites the theme engine tints -- particles + corners
    SpPetal = A .. "110016414100176", SpHeart = A .. "137598941324790", SpBubble = A .. "136045779268819", SpLeaf = A .. "78651444986805",
    SpSparkle = A .. "71086097573060", SpSnow = A .. "94166364705797", SpBolt = A .. "80452969261517", SpCoin = A .. "99258658365130",
    SpBat = A .. "102789157203805", SpPaw = A .. "77733337208219", SpNote = A .. "133650340103109", SpBokeh = A .. "81448986581876",
    CornerLace = A .. "85959971273876", CornerVine = A .. "87590878942290", CornerRivet = A .. "118783050639475",
    CornerWave = A .. "139601852403702", CornerCloud = A .. "71169129276034", CornerFan = A .. "81096257323634",
}
