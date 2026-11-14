--!nocheck
-- ===================================================================================================================
-- INFRARED (Skins V3, bundle 2 of docs/SKINS_V3_PLAN.md; SKINS BUILDER 2): M4A1 + USP + M4 Super 90 | Thermal Knife |
-- 1,199 BP. A special-operations prototype seen through a thermal camera: matte night-polymer shells cut in hard
-- chamfered planes, graphite heat-sink fins whose edges carry the thermal ramp (cold violet -> red -> orange -> a
-- white-hot core) and actually heat up as you fire. The guns are RESCULPTED models (WeaponAssets.SkinModels.Infrared_
-- <GUN>, built by tools/skins_v3/infrared_sculpt.py in art/weapons/SkinsV3_Infrared.blend, painted by
-- tools/skin_v3_paint.py with tools/skins_v3/infrared.json); this module brings their motion, effects, sounds and the
-- rest of the bundle.
--   HEAT         every shot adds heat; the fin edges warm front -> back (the muzzle end first), the stock's grille and
--                vents only with sustained fire; it bleeds off over ~1.5 s once you stop, never fully cold (residual
--                heat, a higher floor as your streak climbs); a heat haze rises off a hot gun (first person)
--   SENSOR       a black-glass sensor bar on the receiver: its reticle dot blinks every 3 s; equip runs a scan line
--                along it; on the inspect's Tilt beat two brackets close on the dot (LOCK)
--   CHAMBER      the receiver's chamber window glows with the heat; a reload cools it to the cold end of the ramp and
--                it re-heats as the new round is chambered
--   EQUIP        thermal boot: a heat wave runs grip -> muzzle through every strip, then the scan line
--   INSPECT      on the Present beat the fins re-heat in a wave front -> back; Tilt = the sensor locks
-- Muzzle: an orange-white core flash + a thermal ring. Tracer: a heat signature (white-hot head, a tail cooling
-- orange -> red -> violet). Impact: a hot spot that blooms and cools. Kill "Cooldown": the body's thermal silhouette
-- cools through the ramp and rises away as heat shimmer. Banner: a thermal lock-on plate with a 5-notch heat gauge.
-- Original design (plan "Originality"): no serial stencils, no status lines, no screens, no text on the guns.
-- ===================================================================================================================
local Set = { Kind = "Infrared" }

-- (COLOURWAYS: each colourway is a whole palette -- the module copy SkinFX loads for colourway v has attribute
-- Colorway = v. The painted model maps are separate SurfaceAppearances, SkinFX.V3Swap.)
local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local V = Vector3.new
local PALETTES = {
    { Name = "Ironbow", Body = C(26, 26, 34), Mid = C(52, 54, 64), Dark = C(10, 10, 14), Cold = C(70, 20, 110), Warm = C(200, 30, 60), Hot = C(255, 120, 30),
      White = C(255, 230, 190), Glow = C(255, 120, 40), Text = C(255, 225, 200), Ink = C(30, 6, 20) },
    { Name = "Arctic Scan", Body = C(20, 28, 46), Mid = C(46, 58, 80), Dark = C(8, 11, 18), Cold = C(24, 30, 96), Warm = C(40, 110, 220), Hot = C(90, 220, 255),
      White = C(225, 250, 255), Glow = C(90, 220, 255), Text = C(214, 240, 255), Ink = C(4, 10, 30) },
    { Name = "Night Vision", Body = C(26, 30, 22), Mid = C(54, 60, 46), Dark = C(8, 11, 8), Cold = C(18, 46, 22), Warm = C(60, 150, 60), Hot = C(120, 255, 120),
      White = C(230, 255, 220), Glow = C(120, 255, 120), Text = C(220, 255, 210), Ink = C(4, 16, 6) },
}
local P = PALETTES[VAR] or PALETTES[1]
local COLD, WARM, HOT, WHITE, GLOW = P.Cold, P.Warm, P.Hot, P.White, P.Glow
Set.Palettes = PALETTES
Set.Colors = { Hot = HOT, White = WHITE, Warm = WARM }
-- image ids of tools/make_infrared_art.py (decals uploaded, resolved to images in Studio)
local A = "rbxassetid://"
Set.Art = {
    EmblemInfrared = A .. "70609915763225", EmblemInfraredMask = A .. "138219989647411", InfraredRing = A .. "134989777987520",
    InfraredCorner = A .. "125755233434560", InfraredBracket = A .. "112643780762111", InfraredPrint1 = A .. "138008844210056",
    InfraredPrint2 = A .. "128300198809831", InfraredPrint3 = A .. "80479066616954", InfraredThermal = A .. "92356244582272",
    InfraredScan = A .. "96656127861012", tex_infrared = A .. "120283684042088", InfraredWeave = A .. "83446796937004",
}
local ART = Set.Art
-- the ramp a heat value 0..1 maps to (cold -> warm -> hot; past 1 toward white-hot)
local function Ramp(k: number): Color3
    k = math.clamp(k, 0, 1.3)
    if k < 0.5 then return COLD:Lerp(WARM, k * 2) elseif k < 1 then return WARM:Lerp(HOT, k * 2 - 1) end
    return HOT:Lerp(WHITE, (k - 1) / 0.3)
end

local function GunDesc(gun: string): string
    return "A special-operations prototype seen through a thermal camera. The gun is resculpted in matte night polymer with graphite heat-sink fins, and every fin edge, vent and the chamber window carries the thermal ramp: they warm from violet to red to orange as you fire, the muzzle end first, the stock only under sustained fire, and bleed off slowly once you stop. A black-glass sensor runs a scan line when you draw it and locks on when you inspect it. Heat-signature tracers, impacts that bloom and cool, and every kill COOLS DOWN: the body's thermal silhouette fades through the ramp and rises away as heat shimmer."
end

-- BEGIN HEAT DATA (generated by tools/skins_v3/infrared_heat_lua.py from the sculpt -- do not edit by hand)
local HEAT = {
    M4A1 = {
        { N = "Fin0L", C = V(0.115, 0.158, -0.1635), S = V(0.009, 0.1487, 0.008), Rz = -19.65, D = "Heat8" },
        { N = "Fin1L", C = V(0.181, 0.158, -0.1635), S = V(0.009, 0.1487, 0.008), Rz = -19.65, D = "Heat7" },
        { N = "Fin2L", C = V(0.247, 0.158, -0.1635), S = V(0.009, 0.1487, 0.008), Rz = -19.65, D = "Heat6" },
        { N = "Fin3L", C = V(0.313, 0.158, -0.1635), S = V(0.009, 0.1487, 0.008), Rz = -19.65, D = "Heat5" },
        { N = "Fin4L", C = V(0.379, 0.158, -0.1635), S = V(0.009, 0.1487, 0.008), Rz = -19.65, D = "Heat4" },
        { N = "Fin5L", C = V(0.445, 0.158, -0.1635), S = V(0.009, 0.1487, 0.008), Rz = -19.65, D = "Heat3" },
        { N = "Fin6L", C = V(0.511, 0.158, -0.1635), S = V(0.009, 0.1487, 0.008), Rz = -19.65, D = "Heat2" },
        { N = "Fin7L", C = V(0.577, 0.158, -0.1635), S = V(0.009, 0.1487, 0.008), Rz = -19.65, D = "Heat1" },
        { N = "Fin0R", C = V(0.115, 0.158, 0.1035), S = V(0.009, 0.1487, 0.008), Rz = -19.65, D = "Heat8" },
        { N = "Fin1R", C = V(0.181, 0.158, 0.1035), S = V(0.009, 0.1487, 0.008), Rz = -19.65, D = "Heat7" },
        { N = "Fin2R", C = V(0.247, 0.158, 0.1035), S = V(0.009, 0.1487, 0.008), Rz = -19.65, D = "Heat6" },
        { N = "Fin3R", C = V(0.313, 0.158, 0.1035), S = V(0.009, 0.1487, 0.008), Rz = -19.65, D = "Heat5" },
        { N = "Fin4R", C = V(0.379, 0.158, 0.1035), S = V(0.009, 0.1487, 0.008), Rz = -19.65, D = "Heat4" },
        { N = "Fin5R", C = V(0.445, 0.158, 0.1035), S = V(0.009, 0.1487, 0.008), Rz = -19.65, D = "Heat3" },
        { N = "Fin6R", C = V(0.511, 0.158, 0.1035), S = V(0.009, 0.1487, 0.008), Rz = -19.65, D = "Heat2" },
        { N = "Fin7R", C = V(0.577, 0.158, 0.1035), S = V(0.009, 0.1487, 0.008), Rz = -19.65, D = "Heat1" },
        { N = "Core", C = V(-0.265, 0.143, -0.129), S = V(0.016, 0.25, 0.006), Rz = -90, D = "Core" },
        { N = "Louvre0", C = V(-0.38, 0.104, -0.1465), S = V(0.007, 0.044, 0.004), Rz = -90, D = "Core" },
        { N = "Louvre1", C = V(-0.305, 0.104, -0.1465), S = V(0.007, 0.044, 0.004), Rz = -90, D = "Core" },
        { N = "Louvre2", C = V(-0.23, 0.104, -0.1465), S = V(0.007, 0.044, 0.004), Rz = -90, D = "Core" },
        { N = "Lens", C = V(-0.18, 0.221, -0.1525), S = V(0.016, 0.016, 0.004), Rz = 0, D = "Lens", Kind = "lens" },
        { N = "Scan", C = V(-0.43, 0.221, -0.1522), S = V(0.006, 0.022, 0.003), Rz = 0, D = "Scan", Kind = "scan", To = V(-0.18, 0.221, -0.1522) },
        { N = "SVent0", C = V(-1.0697, 0.1175, -0.0465), S = V(0.008, 0.0283, 0.005), Rz = -17.47, D = "Stock4" },
        { N = "SVent1", C = V(-1.0078, 0.1175, -0.0465), S = V(0.008, 0.0283, 0.005), Rz = -17.47, D = "Stock4" },
        { N = "SVent2", C = V(-0.9458, 0.1175, -0.0465), S = V(0.008, 0.0283, 0.005), Rz = -17.47, D = "Stock3" },
        { N = "SVent3", C = V(-0.8838, 0.1175, -0.0465), S = V(0.008, 0.0283, 0.005), Rz = -17.47, D = "Stock2" },
        { N = "SVent4", C = V(-0.8218, 0.1175, -0.0465), S = V(0.008, 0.0283, 0.005), Rz = -17.47, D = "Stock1" },
        { N = "Grille0", C = V(-1.434, 0.0035, -0.0532), S = V(0.0066, 0.1746, 0.003), Rz = -7.8, D = "Stock4" },
        { N = "Grille1", C = V(-1.392, 0.0175, -0.0532), S = V(0.0066, 0.1468, 0.003), Rz = -8.93, D = "Stock4" },
        { N = "Grille2", C = V(-1.35, 0.0315, -0.0532), S = V(0.0066, 0.1189, 0.003), Rz = -10.43, D = "Stock3" },
        { N = "Grille3", C = V(-1.308, 0.0455, -0.0532), S = V(0.0066, 0.0911, 0.003), Rz = -12.53, D = "Stock2" },
        { N = "Grille4", C = V(-1.266, 0.0595, -0.0532), S = V(0.0066, 0.0633, 0.003), Rz = -15.67, D = "Stock1" },
    },
    USP = {
        { N = "SVent0L", C = V(0.05, 0.2, -0.026), S = V(0.01, 0.0588, 0.008), Rz = -17.82, D = "Heat4", Follow = "Slide" },
        { N = "SVent0R", C = V(0.05, 0.2, 0.046), S = V(0.01, 0.0588, 0.008), Rz = -17.82, D = "Heat4", Follow = "Slide" },
        { N = "SVent1L", C = V(0.1, 0.2, -0.026), S = V(0.01, 0.0588, 0.008), Rz = -17.82, D = "Heat3", Follow = "Slide" },
        { N = "SVent1R", C = V(0.1, 0.2, 0.046), S = V(0.01, 0.0588, 0.008), Rz = -17.82, D = "Heat3", Follow = "Slide" },
        { N = "SVent2L", C = V(0.15, 0.2, -0.026), S = V(0.01, 0.0588, 0.008), Rz = -17.82, D = "Heat2", Follow = "Slide" },
        { N = "SVent2R", C = V(0.15, 0.2, 0.046), S = V(0.01, 0.0588, 0.008), Rz = -17.82, D = "Heat2", Follow = "Slide" },
        { N = "SVent3L", C = V(0.2, 0.2, -0.026), S = V(0.01, 0.0588, 0.008), Rz = -17.82, D = "Heat1", Follow = "Slide" },
        { N = "SVent3R", C = V(0.2, 0.2, 0.046), S = V(0.01, 0.0588, 0.008), Rz = -17.82, D = "Heat1", Follow = "Slide" },
        { N = "RSlot0", C = V(-0.372, 0.174, 0.01), S = V(0.004, 0.006, 0.056), Rz = 0, D = "Heat2", Follow = "Slide" },
        { N = "RSlot1", C = V(-0.372, 0.194, 0.01), S = V(0.004, 0.006, 0.056), Rz = 0, D = "Heat3", Follow = "Slide" },
        { N = "RSlot2", C = V(-0.372, 0.214, 0.01), S = V(0.004, 0.006, 0.056), Rz = 0, D = "Heat4", Follow = "Slide" },
        { N = "TSlot0", C = V(-0.16, 0.2455, 0.01), S = V(0.11, 0.004, 0.018), Rz = 0, D = "Heat3", Follow = "Slide" },
        { N = "TSlot1", C = V(0.02, 0.2455, 0.01), S = V(0.11, 0.004, 0.018), Rz = 0, D = "Heat2", Follow = "Slide" },
        { N = "MVent0", C = V(0.08, 0.127, -0.039), S = V(0.008, 0.0279, 0.006), Rz = -21.04, D = "Core" },
        { N = "MVent1", C = V(0.13, 0.127, -0.039), S = V(0.008, 0.0279, 0.006), Rz = -21.04, D = "Core" },
        { N = "Lens", C = V(0.26, 0.127, -0.0505), S = V(0.012, 0.012, 0.003), Rz = 0, D = "Lens", Kind = "lens" },
        { N = "Scan", C = V(0.196, 0.127, -0.0502), S = V(0.004, 0.016, 0.002), Rz = 0, D = "Scan", Kind = "scan", To = V(0.262, 0.127, -0.0502) },
    },
    BM4 = {
        { N = "Fin0L", C = V(0.24, 0.149, -0.1075), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat12" },
        { N = "Fin1L", C = V(0.325, 0.149, -0.1075), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat11" },
        { N = "Fin2L", C = V(0.41, 0.149, -0.1075), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat10" },
        { N = "Fin3L", C = V(0.495, 0.149, -0.1075), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat9" },
        { N = "Fin4L", C = V(0.58, 0.149, -0.1075), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat8" },
        { N = "Fin5L", C = V(0.665, 0.149, -0.1075), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat7" },
        { N = "Fin6L", C = V(0.75, 0.149, -0.1075), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat6" },
        { N = "Fin7L", C = V(0.835, 0.149, -0.1075), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat5" },
        { N = "Fin8L", C = V(0.92, 0.149, -0.1075), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat4" },
        { N = "Fin9L", C = V(1.005, 0.149, -0.1075), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat3" },
        { N = "Fin10L", C = V(1.09, 0.149, -0.1075), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat2" },
        { N = "Fin11L", C = V(1.175, 0.149, -0.1075), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat1" },
        { N = "Fin0R", C = V(0.24, 0.149, 0.0995), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat12" },
        { N = "Fin1R", C = V(0.325, 0.149, 0.0995), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat11" },
        { N = "Fin2R", C = V(0.41, 0.149, 0.0995), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat10" },
        { N = "Fin3R", C = V(0.495, 0.149, 0.0995), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat9" },
        { N = "Fin4R", C = V(0.58, 0.149, 0.0995), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat8" },
        { N = "Fin5R", C = V(0.665, 0.149, 0.0995), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat7" },
        { N = "Fin6R", C = V(0.75, 0.149, 0.0995), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat6" },
        { N = "Fin7R", C = V(0.835, 0.149, 0.0995), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat5" },
        { N = "Fin8R", C = V(0.92, 0.149, 0.0995), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat4" },
        { N = "Fin9R", C = V(1.005, 0.149, 0.0995), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat3" },
        { N = "Fin10R", C = V(1.09, 0.149, 0.0995), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat2" },
        { N = "Fin11R", C = V(1.175, 0.149, 0.0995), S = V(0.009, 0.1598, 0.008), Rz = -20.14, D = "Heat1" },
        { N = "RFin0", C = V(-0.45, 0.165, -0.1335), S = V(0.007, 0.1102, 0.004), Rz = -15.8, D = "Core" },
        { N = "RFin1", C = V(-0.38, 0.165, -0.1335), S = V(0.007, 0.1102, 0.004), Rz = -15.8, D = "Core" },
        { N = "RFin2", C = V(-0.31, 0.165, -0.1335), S = V(0.007, 0.1102, 0.004), Rz = -15.8, D = "Core" },
        { N = "RFin3", C = V(-0.24, 0.165, -0.1335), S = V(0.007, 0.1102, 0.004), Rz = -15.8, D = "Core" },
        { N = "RFin4", C = V(-0.17, 0.165, -0.1335), S = V(0.007, 0.1102, 0.004), Rz = -15.8, D = "Core" },
        { N = "Lens", C = V(-0.22, 0.2475, -0.1375), S = V(0.016, 0.016, 0.004), Rz = 0, D = "Lens", Kind = "lens" },
        { N = "Scan", C = V(-0.46, 0.2475, -0.1372), S = V(0.006, 0.02, 0.003), Rz = 0, D = "Scan", Kind = "scan", To = V(-0.22, 0.2475, -0.1372) },
        { N = "Comb0", C = V(-1.063, 0.1927, -0.004), S = V(0.011, 0.004, 0.062), Rz = 0, D = "Stock1" },
        { N = "Comb1", C = V(-1.138, 0.1837, -0.004), S = V(0.011, 0.004, 0.062), Rz = 0, D = "Stock2" },
        { N = "Comb2", C = V(-1.213, 0.1746, -0.004), S = V(0.011, 0.004, 0.062), Rz = 0, D = "Stock3" },
        { N = "Comb3", C = V(-1.288, 0.1655, -0.004), S = V(0.011, 0.004, 0.062), Rz = 0, D = "Stock4" },
        { N = "Comb4", C = V(-1.363, 0.1565, -0.004), S = V(0.011, 0.004, 0.062), Rz = 0, D = "Stock4" },
        { N = "Grille0", C = V(-1.5019, -0.0165, -0.0312), S = V(0.0066, 0.2388, 0.003), Rz = -6.04, D = "Stock4" },
        { N = "Grille1", C = V(-1.4456, -0.001, -0.0312), S = V(0.0066, 0.2181, 0.003), Rz = -6.52, D = "Stock4" },
        { N = "Grille2", C = V(-1.3894, 0.0144, -0.0312), S = V(0.0066, 0.1974, 0.003), Rz = -7.07, D = "Stock4" },
        { N = "Grille3", C = V(-1.3331, 0.0299, -0.0312), S = V(0.0066, 0.1767, 0.003), Rz = -7.73, D = "Stock4" },
        { N = "Grille4", C = V(-1.2769, 0.0454, -0.0312), S = V(0.0066, 0.156, 0.003), Rz = -8.52, D = "Stock4" },
        { N = "Grille5", C = V(-1.2206, 0.0608, -0.0312), S = V(0.0066, 0.1353, 0.003), Rz = -9.49, D = "Stock3" },
        { N = "Grille6", C = V(-1.1644, 0.0763, -0.0312), S = V(0.0066, 0.1146, 0.003), Rz = -10.71, D = "Stock2" },
        { N = "Grille7", C = V(-1.1081, 0.0918, -0.0312), S = V(0.0066, 0.094, 0.003), Rz = -12.28, D = "Stock1" },
    },
    Knife = {
        { N = "KEdge1", C = V(0.0704, 0.34, 0), S = V(0.007, 0.1002, 0.006), Rz = -3.26, D = "KEdge1" },
        { N = "KEdge2", C = V(0.0745, 0.44, 0), S = V(0.007, 0.1, 0.006), Rz = -1.42, D = "KEdge2" },
        { N = "KEdge3", C = V(0.0763, 0.54, 0), S = V(0.007, 0.1, 0.006), Rz = -0.64, D = "KEdge3" },
        { N = "KEdge4", C = V(0.075, 0.64, 0), S = V(0.007, 0.1001, 0.006), Rz = 2.2, D = "KEdge4" },
        { N = "KEdge5", C = V(0.0666, 0.735, 0), S = V(0.007, 0.0909, 0.006), Rz = 8.2, D = "KEdge5" },
        { N = "KEdge6", C = V(0.0439, 0.82, 0), S = V(0.007, 0.0863, 0.006), Rz = 22.02, D = "KEdge6" },
        { N = "KLens-1", C = V(0.003, -0.165, -0.0365), S = V(0.014, 0.014, 0.003), Rz = 0, D = "Lens", Kind = "lens" },
        { N = "KLens1", C = V(0.003, -0.165, 0.0365), S = V(0.014, 0.014, 0.003), Rz = 0, D = "Lens", Kind = "lens" },
    },
}
-- END HEAT DATA

-- ===== the guns (V3 models) =====
Set.GunSkins = {
    { Id = "InfraredM4A1", Name = "Infrared M4A1", Gun = "M4A1", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("M4A1"),
      Model = "Infrared_M4A1", V3 = true, Color = GLOW, Deco = "InfraredGun", PerShot = 0.065, Fins = 8, Fit = { Heat = HEAT.M4A1, Print = true } },
    { Id = "InfraredUSP", Name = "Infrared USP", Gun = "USP", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("USP"),
      Model = "Infrared_USP", V3 = true, Color = GLOW, Deco = "InfraredGun", PerShot = 0.15, Fins = 4, Fit = { Heat = HEAT.USP } },
    { Id = "InfraredBM4", Name = "Infrared M4 Super 90", Gun = "BM4", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("BM4"),
      Model = "Infrared_BM4", V3 = true, Color = GLOW, Deco = "InfraredGun", PerShot = 0.2, Fins = 12, Fit = { Heat = HEAT.BM4 } },
}

-- ===== the small live bits built in Roblox parts on the sculpt: heat strips, the sensor dot + lock brackets, the scan
-- line, the magazine's thermal finger marks =====
local function HeatAttrs(p: BasePart, drive: string, cold: number?)
    p:SetAttribute("TintDrive", drive); p:SetAttribute("TintA", COLD); p:SetAttribute("TintMid", WARM); p:SetAttribute("TintB", HOT)
    p:SetAttribute("GlowDrive", drive); p:SetAttribute("GlowCold", cold or 0.8); p:SetAttribute("GlowHot", 0)
end
Set.Build = {}
Set.Build.InfraredGun = function(model: Model, frame: BasePart, f: any, forView: boolean, H: any)
    local CF, ANG, R = H.CF, H.ANG, H.R
    local base = frame.CFrame
    -- the sculpt's own glow meshes (muzzle crown, collar seam) take the colourway's ramp
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") and p:GetAttribute("HeatTint") then
            p:SetAttribute("TintA", COLD); p:SetAttribute("TintMid", WARM); p:SetAttribute("TintB", HOT)
            p.Color = COLD
        end
    end
    for _, h in ipairs(f.Heat or {}) do
        local cf = base * CF(h.C) * ANG(0, 0, R(h.Rz or 0))
        if h.Kind == "lens" then
            local dot = H.Deco(model, { Name = "Lens", Shape = Enum.PartType.Ball, Size = h.S, CFrame = cf, Color = HOT, Glow = true, Zone = "Sensor" })
            dot:SetAttribute("GlowDrive", "Lens"); dot:SetAttribute("GlowCold", 0.75); dot:SetAttribute("GlowHot", 0)
            if h.Follow then dot:SetAttribute("Follow", h.Follow) end
            if forView then
                -- two L brackets that close on the dot when the sensor locks (inspect)
                local s = math.max(h.S.X, h.S.Y)
                for _, sx in ipairs({ -1, 1 }) do
                    local arm = s * 0.9
                    local th = s * 0.22
                    local bx = H.Deco(model, { Name = "Lock", Size = V(arm, th, 0.002), CFrame = cf * CF(sx * s * 1.6, sx * s * 1.1, -0.001), Color = WHITE, Glow = true })
                    local by = H.Deco(model, { Name = "Lock", Size = V(th, arm, 0.002), CFrame = cf * CF(sx * (s * 1.6 + arm / 2 - th / 2), sx * (s * 1.1 - arm / 2 + th / 2), -0.001), Color = WHITE, Glow = true })
                    for _, b in ipairs({ bx, by }) do
                        b:SetAttribute("ShowDrive", "Lock")
                        b:SetAttribute("ShiftDrive", "Lock")
                        b:SetAttribute("ShiftTo", V(-sx * s * 0.8 / b.Size.X, -sx * s * 0.5 / b.Size.Y, 0))
                    end
                end
            end
        elseif h.Kind == "scan" then
            if forView then
                local p = H.Deco(model, { Name = "Scan", Size = h.S, CFrame = cf, Color = WHITE, Glow = true, Zone = "Sensor" })
                p:SetAttribute("ShowDrive", "ScanOn")
                p:SetAttribute("ShiftDrive", "Scan")
                local d = (h.To or h.C) - h.C
                p:SetAttribute("ShiftTo", V(d.X / h.S.X, d.Y / h.S.Y, 0))
            end
        else
            local p = H.Deco(model, { Name = "Heat", Size = h.S, CFrame = cf, Color = COLD, Glow = true, Zone = "Heat" })
            HeatAttrs(p, h.D)
            if h.Follow then p:SetAttribute("Follow", h.Follow) end
        end
    end
    -- thermal finger marks on the magazine's camera face (a decal on an invisible plate that rides the magazine)
    if f.Print and model:FindFirstChild("Magazine") then
        local pl = H.Deco(model, { Name = "Print", Size = V(0.15, 0.17, 0.002), CFrame = base * CF(-0.075, -0.24, -0.0735) * ANG(0, 0, R(6.3)), Color = HOT, Transparency = 1 })
        pl:SetAttribute("SkinDeco", nil)
        pl:SetAttribute("Follow", "Magazine")
        local d = Instance.new("Decal")
        d.Texture = ART["InfraredPrint" .. VAR] or ART.InfraredPrint1
        d.Face = Enum.NormalId.Front
        d.Transparency = 0.2
        d.Parent = pl
    end
end

-- ===== motion: the heat model and every key the parts read =====
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function pulse(t, w) return math.exp(-(t / w) ^ 2) end
local function PlaySound(H: any, d: any)
    if not d or (d.Id or 0) == 0 then return end
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. tostring(d.Id)
    s.Volume = d.Volume or 0.4
    local grp = H.SoundService:FindFirstChild("AimRngMix_Weapons")
    if grp then s.SoundGroup = grp end
    s.Parent = H.SoundService
    s:Play()
    H.Debris:AddItem(s, 3)
end
-- st: the generic moments (SinceShot / SinceEquip / Reload / Streak / Inspect / Anim + AnimT); v = per-gun vars
local function FillKeys(st: any, v: any, dt: number, now: number, nFin: number, perShot: number, H: any?)
    local ss = st.SinceShot or 99
    local se = st.SinceEquip or 99
    local streak = math.min(st.Streak or 0, 5)
    -- heat: +perShot a shot, bleeds off after 0.25 s, never under the residual floor
    if ss < 0.08 and ss < (v.LastSS or 99) - 1e-4 then
        v.Heat = math.min(1.15, (v.Heat or 0) + perShot)
        v.Burst = (v.Burst or 0) + 1
    end
    v.LastSS = ss
    local floor = 0.1 + 0.04 * streak
    local heat = v.Heat or floor
    if ss > 0.25 then heat = floor + (heat - floor) * math.exp(-dt / 0.75) end
    heat = math.max(heat, floor)
    v.Heat = heat
    -- cooling ticks of hot metal once a long burst ends
    if ss > 0.4 and (v.Burst or 0) > 0 then
        if (v.Burst or 0) >= 8 and heat > 0.45 and H and Set.Sounds then PlaySound(H, Set.Sounds.Cool) end
        v.Burst = 0
    end
    -- the inspect wave (OnEvent "IRWave" on the class inspect's Present beat) + the lock (Tilt)
    local wave = v.WaveT and (now - v.WaveT) or 99
    local lock = v.LockT and (now - v.LockT) or 99
    local inInspect = st.Anim == "Inspect"
    if not inInspect then v.LockT = nil; lock = 99 end
    -- every fin strip: its own temperature, the front (index 1) quickest to heat and to cool
    v.T = v.T or {}
    for i = 1, nFin do
        local back = (i - 1) / math.max(1, nFin - 1) -- (0 front .. 1 back)
        local tgt = heat * (1 - 0.22 * back)
        local k = 7 - 4.5 * back
        local t = v.T[i] or floor
        t += (tgt - t) * (1 - math.exp(-dt * k))
        v.T[i] = t
        local val = t
        -- equip: a thermal boot wave from the grip end to the muzzle (back fins first)
        if se < 0.9 then val += 0.9 * pulse(se - (0.1 + (1 - back) * 0.32), 0.09) end
        -- inspect: the fins re-heat in a wave front -> back
        if wave < 1.6 then val = math.max(val, 0.95 * pulse(wave - (0.12 + back * 0.6), 0.14)) end
        st["Heat" .. i] = val
    end
    -- the stock: only sustained fire reaches it (slow), the boot + inspect waves pass through it last
    local sh = math.max(0, (heat - 0.32) / 0.68)
    v.S = (v.S or 0) + (sh - (v.S or 0)) * (1 - math.exp(-dt * 1.6))
    for i = 1, 4 do
        local val = v.S * (1 - 0.12 * (i - 1)) + floor * 0.6
        if se < 0.9 then val += 0.85 * pulse(se - (0.02 + (i - 1) * 0.03), 0.08) end
        if wave < 1.6 then val = math.max(val, 0.85 * pulse(wave - (0.75 + (i - 1) * 0.07), 0.14)) end
        st["Stock" .. i] = val
    end
    -- the chamber core: the heat; a reload cools it to the cold end, re-heats it as the round is chambered
    local core = heat
    local rl = st.Reload or 0
    if rl > 0 then
        if rl < 0.75 then core = heat * (1 - smooth(rl / 0.4)) * 0.6 else core = 0.9 * smooth((rl - 0.75) / 0.12) end
        v.Rechamber = now
    elseif v.Rechamber and now - v.Rechamber < 0.6 then
        core = math.max(heat, 0.9 * (1 - (now - v.Rechamber) / 0.6))
    end
    if se < 0.9 then core += 0.8 * pulse(se - 0.2, 0.09) end
    st.Core = core
    st.Muzzle = math.max((v.T[1] or heat) * 0.75, math.exp(-ss / 0.12))
    st.Collar = 0.15 + 0.85 * (v.S or 0)
    -- sensor: the dot blinks every 3 s; equip / the inspect's Present run the scan line; Tilt locks it
    local blink = ((now % 3) < 0.14) and 1 or 0.18
    st.Lens = math.max(blink, (lock < 99) and 1 or 0)
    local scanT = math.min(se - 0.42, wave >= 0 and wave - 0.05 or 99)
    if scanT >= 0 and scanT < 0.4 then st.Scan, st.ScanOn = smooth(scanT / 0.4), 1 else st.Scan, st.ScanOn = 0, 0 end
    st.Lock = (lock < 99) and smooth(lock / 0.22) or 0
    return heat
end
-- the knife: the edge heats from the guard outward on the draw and after every swing, cools in ~1.2 s
local function FillKnife(st: any, v: any, dt: number, now: number)
    local se = st.SinceEquip or 99
    local sw = v.SwingT and (now - v.SwingT) or 99
    local wave = v.WaveT and (now - v.WaveT) or 99
    v.KH = (v.KH or 0.12) + (0.12 - (v.KH or 0.12)) * (1 - math.exp(-dt * 0.9))
    for i = 1, 6 do
        local d = (i - 1) * 0.045
        local val = v.KH
        if se < 1.2 then val = math.max(val, 1.05 * pulse(se - (0.12 + d), 0.12) + 0.6 * smooth((se - d) / 0.4) * math.exp(-math.max(0, se - 0.5) * 2.5)) end
        if sw < 1.4 then val = math.max(val, math.exp(-math.max(0, sw - d) * 2.2) * (sw >= d and 1 or 0)) end
        if wave < 1.6 then val = math.max(val, 0.95 * pulse(wave - (0.1 + d * 2), 0.12)) end
        st["KEdge" .. i] = val
    end
    st.Lens = ((now % 3) < 0.14) and 1 or 0.2
end
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    local v = rig.SkinVars
    -- (skins4: ViewmodelRig writes st.Anim / st.AnimT only AFTER the set's Drive -- read them from the rig, or the inspect's
    -- sensor LOCK was cleared every frame and never showed)
    st.Anim, st.AnimT = rig.AnimName, rig.AnimTime
    if rig.Def and rig.Def.IsMelee then FillKnife(st, v, dt, now) return end
    local sk = rig.Skin or {}
    local heat = FillKeys(st, v, dt, now, sk.Fins or 8, sk.PerShot or 0.08, H)
    -- heat haze off a hot gun once you stop firing (first person only: the muzzle's emitter)
    local haze = rig.Fx and rig.Fx.Haze
    if haze then
        local rate = ((st.SinceShot or 99) > 0.2 and heat > 0.45) and (3 + 9 * (heat - 0.45)) or 0
        if v.HazeRate ~= rate then v.HazeRate = rate; haze.Rate = rate end
    end
end
Set.OnAnim = function(rig: any, name: string)
    if rig.Def and rig.Def.IsMelee and (name:find("Light") or name:find("Heavy") or name:find("Quick")) then rig.SkinVars.SwingT = os.clock() end
end
Set.OnEvent = function(rig: any, name: string, H: any, data: any)
    local v = rig.SkinVars
    if not v then return end
    if name == "IRWave" or name == "Present" or (rig.Def and rig.Def.IsMelee and name == "Flip") then v.WaveT = os.clock() end
    if name == "IRLock" or name == "Tilt" or name == "Flip" then v.LockT = os.clock() end
end
-- other players' guns: residual heat, a boot now and then (an inspect wave)
Set.World = function(rec: any, now: number, st: any)
    local v = rec.Vars
    v.NextWave = v.NextWave or (now + 3 + math.random() * 5)
    if now >= v.NextWave then v.WaveT = now; v.NextWave = now + 8 + math.random() * 6 end
    st.SinceShot = 99; st.SinceEquip = 99; st.Reload = 0; st.Streak = 1; st.Anim = nil
    local dt = v.LastNow and math.clamp(now - v.LastNow, 0, 0.2) or 0
    v.LastNow = now
    FillKeys(st, v, dt, now, 12, 0)
    FillKnife(st, v, dt, now)
end

-- ===== muzzle: an orange-white core flash + a thermal ring; the heat haze emitter =====
Set.Muzzle = function(rig: any, flash: ParticleEmitter, light: PointLight, muzzle: Attachment, H: any)
    flash.Color = ColorSequence.new(WHITE, HOT)
    light.Color = HOT
    rig.Fx.Ring = H.Emitter(muzzle, { Name = "SkinThermalRing", Texture = ART.InfraredRing, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.4, HOT), ColorSequenceKeypoint.new(1, COLD) }),
        Size = { 0.06, 0.42 }, Life = { 0.09, 0.11 }, Speed = { 0, 0 }, Trans = { 0.25, 1 }, Light = 1 })
    rig.Fx.Haze = H.Emitter(muzzle, { Name = "SkinHeatHaze", Texture = H.SMOKE, Color = { WARM:Lerp(Color3.new(1, 1, 1), 0.5), COLD }, Size = { 0.1, 0.4 },
        Life = { 0.6, 1.0 }, Speed = { 0.2, 0.6 }, Accel = V(0, 1.4, 0), Trans = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.88), NumberSequenceKeypoint.new(1, 1) }),
        Light = 0.15, Spread = 25, Dir = Enum.NormalId.Top })
end
Set.OnFire = function(rig: any, H: any, isLast: boolean)
    if rig.Fx and rig.Fx.Ring then rig.Fx.Ring:Emit(1) end
end

-- ===== HEAT SIGNATURE tracer: a white-hot head racing out, its tail cooling orange -> red -> violet =====
Set.Tracer = function(H: any, from: Vector3, to: Vector3, peer: boolean?)
    local dist = (to - from).Magnitude
    if dist < 1.5 then return end
    local host = H.FxPart({ Size = V(0.05, 0.05, 0.05), Transparency = 1, CFrame = CFrame.new(from) })
    local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
    a0.Parent, a1.Parent = host, host
    local bm = Instance.new("Beam")
    bm.Attachment0, bm.Attachment1 = a0, a1
    bm.FaceCamera = true
    bm.LightEmission, bm.LightInfluence = 1, 0
    bm.Segments = 8   -- (a 3-key Transparency fade: a 1-segment Beam only samples its two ends)
    bm.Width0, bm.Width1 = 0.02, peer and 0.07 or 0.09
    bm.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, COLD), ColorSequenceKeypoint.new(0.45, WARM), ColorSequenceKeypoint.new(0.8, HOT), ColorSequenceKeypoint.new(1, WHITE) })
    bm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0.05) })
    bm.Parent = host
    local dir = (to - from).Unit
    local travel = H.TRAVEL -- (hitscan: the shot is there at once, nothing flies)
    local tailLen = math.min(dist, 16)
    local dur = travel + 0.12
    H.Animate(dur, function(t)
        local hk = math.clamp(t / travel, 0, 1)
        local head = from + dir * dist * hk
        local tail = from -- (hitscan look: the whole line, muzzle -> hit)
        a0.WorldPosition, a1.WorldPosition = tail, head
        local fade = math.clamp((t - travel) / 0.12, 0, 1)
        bm.Width1 = (peer and 0.07 or 0.09) * (1 - fade * 0.6)
        bm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.45 + 0.55 * fade), NumberSequenceKeypoint.new(1, 0.05 + 0.95 * fade) })
    end, function() host:Destroy() end)
end

-- ===== HOT SPOT impact: a bloom on the surface (white -> orange -> red -> violet) that cools in 0.6 s + a few sparks =====
Set.Impact = function(H: any, pos: Vector3, normal: Vector3?, peer: boolean?)
    if not H.Budget("InfraredImpact", peer and 3 or 8, 0.6) then return end
    local nrm = (normal and normal.Magnitude > 0.1) and normal.Unit or V(0, 1, 0)
    local face = CFrame.lookAt(pos + nrm * 0.02, pos + nrm * 2) * H.ANG(0, H.R(90), 0)
    local rings = {}
    for i, spec in ipairs({ { 0.5, 0.0 }, { 0.32, 0.004 }, { 0.16, 0.008 } }) do
        rings[i] = H.FxPart({ Shape = Enum.PartType.Cylinder, Size = V(0.012, spec[1], spec[1]), CFrame = face * CFrame.new(spec[2], 0, 0), Color = (i == 3) and WHITE or ((i == 2) and HOT or WARM), Transparency = (i == 1) and 0.45 or 0.1 })
    end
    if not peer then
        local att = H.Att(rings[3], pos + nrm * 0.05)
        local em = H.Emitter(att, { Name = "IrSparks", Color = { WHITE, HOT }, Size = { 0.05, 0 }, Life = { 0.15, 0.3 }, Speed = { 3, 7 }, Spread = 55, Accel = V(0, -18, 0), Dir = Enum.NormalId.Left })
        em:Emit(5)
    end
    H.Animate(0.6, function(t)
        local k = t / 0.6
        rings[3].Color = WHITE:Lerp(HOT, math.min(1, k * 2.5)):Lerp(COLD, math.max(0, k * 1.6 - 0.6))
        rings[2].Color = HOT:Lerp(WARM, math.min(1, k * 2)):Lerp(COLD, math.max(0, k * 1.5 - 0.5))
        rings[1].Color = WARM:Lerp(COLD, math.min(1, k * 1.5))
        rings[1].Transparency = 0.45 + 0.55 * k
        rings[2].Transparency = 0.1 + 0.9 * k ^ 0.8
        rings[3].Transparency = 0.1 + 0.9 * k ^ 0.7
        local g = 1 + 0.35 * k
        rings[1].Size = V(0.012, 0.5 * g, 0.5 * g)
    end, function() for _, r in ipairs(rings) do r:Destroy() end end)
end

-- ===== HEAT GHOST kill (FX roll-out 2026-10-14; v1 "Cooldown" tinted the body white -> violet and lifted it -- one of the
-- eight body-shell recolours, scored 2). ONE idea: the kill is seen through a THERMAL SIGHT. A dark viewfinder plate snaps
-- up behind the body with four heat-orange reticle brackets (the lock), the body itself is redrawn as a blocky thermal
-- image -- big glowing heat pixels in the set's ramp, white-hot at the core, cold at the edges -- and on the beat (0.18 s)
-- the image BREAKS: the pixels scatter up and outward, cooling through the ramp to dark as they go, while the plate shutters
-- shut and the brackets spring wide. 1.25 s. The pixels leave the body's centre by ~0.3 s (out + up, never toward you).
-- Budget: full plate + bracket host + <= 14 pixels = 16 parts, no sprites; low: plate + brackets + 4 pixels. =====
local function BodyOf(pos: Vector3, H: any): (Model?, CFrame, Vector3)
    local op = OverlapParams.new()
    op.FilterType = Enum.RaycastFilterType.Exclude
    local ex = { H.FxFolder() }
    for _, pl in ipairs(H.Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
    if workspace.CurrentCamera then table.insert(ex, workspace.CurrentCamera) end
    op.FilterDescendantsInstances = ex
    local best, count = nil, {}
    for _, p in ipairs(workspace:GetPartBoundsInRadius(pos, 3.5, op)) do
        local m = p:FindFirstAncestorOfClass("Model")
        while m and not (m:FindFirstChild("Head") or m:FindFirstChild("Torso")) do m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model") end
        if m then count[m] = (count[m] or 0) + 1; if not best or count[m] > count[best] then best = m end end
    end
    if best then
        local ok, cf, size = pcall(function() return best:GetBoundingBox() end)
        if ok and size.Magnitude < 20 then return best, cf, size end
    end
    return nil, CFrame.new(pos - V(0, 1.4, 0)), V(1.8, 3.8, 1.2)
end
Set.Kill = function(H: any, pos: Vector3, low: boolean)
    local body, bcf, bsz = BodyOf(pos, H)
    local ground = H.Ground(pos)
    local cam = workspace.CurrentCamera
    local rt = cam and cam.CFrame.RightVector or V(1, 0, 0)
    rt = V(rt.X, 0, rt.Z)
    rt = (rt.Magnitude > 0.05) and rt.Unit or V(1, 0, 0)
    local W = math.clamp(math.max(bsz.X, bsz.Z) * 1.05, 2.2, 5)
    local Hh = math.clamp(bsz.Y, 3.6, 7.5)
    -- (the plate stands on the floor: a short body / one on a stand still gets a full-height sight)
    local center = V(bcf.Position.X, math.max(bcf.Position.Y, ground.Y + (Hh + 0.8) / 2 + 0.05), bcf.Position.Z)
    local frame = CFrame.fromMatrix(center, rt, V(0, 1, 0)) -- (+Z = toward you)
    local model = Instance.new("Model"); model.Name = "InfraredKill"; model.Parent = H.FxFolder()
    -- the viewfinder plate: the cold, dark background of a thermal image, a little bigger than the body, behind it
    local pw, ph = W + 1.0, Hh + 0.8
    local plate = H.FxPart({ Material = Enum.Material.SmoothPlastic, Color = P.Dark, Transparency = 1, Size = V(pw, ph, 0.04),
        CFrame = frame * CFrame.new(0, 0, -math.max(bsz.X, bsz.Z) * 0.5 - 0.25) }, model)
    -- the reticle brackets: four heat-orange L corners on an ink edge, on a self-lit SurfaceGui just in front of the plate
    local bh = H.FxPart({ Transparency = 1, Size = V(pw, ph, 0.02), CFrame = plate.CFrame * CFrame.new(0, 0, 0.05) }, model)
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Back; sg.LightInfluence = 0; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 40
    sg.Parent = bh
    local corners = {}
    for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
        local holder = H.New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]),
            Size = UDim2.fromOffset(44, 44) }, sg)
        for i = 1, 2 do
            local b = H.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = HOT, BackgroundTransparency = 1, AnchorPoint = Vector2.new(c[1], c[2]),
                Position = UDim2.fromScale(c[1], c[2]), Size = (i == 1) and UDim2.fromOffset(44, 9) or UDim2.fromOffset(9, 44) }, holder)
            H.New("UIStroke", { Color = P.Ink, Thickness = 3, Transparency = 1 }, b)
        end
        table.insert(corners, holder)
    end
    -- the heat pixels: a grid over the body in the camera's plane, kept only where a ray finds the body (so the image is
    -- the body's own blocky silhouette), coloured by heat -- white-hot core, cold edges
    local cap = low and 4 or 14
    local cell = math.max(0.62, math.sqrt(W * Hh / (cap * 1.5)))
    local cols, rows = math.max(1, math.floor(W / cell + 0.5)), math.max(1, math.floor(Hh / cell + 0.5))
    local rp = RaycastParams.new()
    if body then rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { body } end
    local zf = math.min(bsz.X, bsz.Z) * 0.5 + 0.1 -- (the image sits on the body's front face)
    local cells = {}
    for r = 1, rows do
        for c = 1, cols do
            local x, y = (c - (cols + 1) / 2) * cell, (r - (rows + 1) / 2) * cell
            local p = (frame * CFrame.new(x, y, 0)).Position
            local hit = not body or workspace:Raycast(p + frame.ZVector * 4, -frame.ZVector * 8, rp) ~= nil
            if hit then
                local heat = 1.25 - 0.75 * math.abs(x) / (W / 2) - 0.25 * math.abs(y) / (Hh / 2) + (math.random() - 0.5) * 0.2
                table.insert(cells, { X = x, Y = y, Heat = heat })
            end
        end
    end
    if #cells < 3 then -- (no ray found the body -- it was already gone or not queryable: the whole grid is the image)
        cells = {}
        for r = 1, rows do
            for c = 1, cols do
                local x, y = (c - (cols + 1) / 2) * cell, (r - (rows + 1) / 2) * cell
                if math.abs(x) < W * 0.4 or math.abs(y) < Hh * 0.2 then
                    table.insert(cells, { X = x, Y = y, Heat = 1.25 - 0.75 * math.abs(x) / (W / 2) - 0.25 * math.abs(y) / (Hh / 2) + (math.random() - 0.5) * 0.2 })
                end
            end
        end
    end
    table.sort(cells, function(a, b) return a.Heat > b.Heat end)
    while #cells > cap do table.remove(cells, math.random(math.ceil(#cells / 2), #cells)) end
    local px = {}
    for _, c in ipairs(cells) do
        local part = H.FxPart({ Color = Ramp(c.Heat), Size = V(cell * 0.92, cell * 0.92, cell * 0.5), Transparency = 1,
            CFrame = frame * CFrame.new(c.X, c.Y, zf) }, model)
        local side = (c.X >= 0) and 1 or -1
        if math.abs(c.X) < cell * 0.5 then side = (math.random() < 0.5) and -1 or 1 end
        table.insert(px, { P = part, X = c.X, Y = c.Y, Heat = c.Heat,
            V = V(side * (2.2 + math.random() * 2.6), 2.6 + math.random() * 2.4 + c.Heat * 2.2, (math.random() - 0.5) * 1.2),
            Spin = (math.random() - 0.5) * 6 })
    end
    local dur = low and 0.9 or 1.25
    local BEAT = 0.18
    H.Animate(dur, function(t)
        -- 1) LOCK: plate + brackets snap on (the brackets close from 1.3x to 1x)
        local on = smooth(t / 0.06)
        local lock = 1 + 0.3 * (1 - smooth(t / 0.12))
        -- 3) after the beat the plate shutters shut (to a line) and the brackets spring wide and go
        local shut = smooth((t - BEAT - 0.02) / 0.2)
        plate.Size = V(pw, math.max(0.04, ph * (1 - shut)), 0.04)
        plate.Transparency = (t < 0.01) and 1 or math.clamp(0.08 + shut * 0.92, 0, 1)
        local wide = 1 + 0.6 * smooth((t - BEAT) / 0.3)
        local s = (t < BEAT) and lock or wide
        bh.Size = V(pw * s, ph * s, 0.02)
        local ca = math.clamp(1 - on + smooth((t - BEAT - 0.1) / 0.25), 0, 1)
        local blink = (t > BEAT - 0.04 and t < BEAT) and 0.6 or 0
        for _, h in ipairs(corners) do
            for _, b in ipairs(h:GetChildren()) do
                b.BackgroundTransparency = math.min(1, ca + blink)
                local ink = b:FindFirstChildOfClass("UIStroke"); if ink then ink.Transparency = math.min(1, ca + blink) end
            end
        end
        -- 2) the thermal image; on the BEAT it breaks: the pixels scatter up and out, cooling to dark as they go
        local k = math.max(0, t - BEAT)
        for _, q in ipairs(px) do
            local cool = math.clamp(k / (dur - BEAT - 0.1), 0, 1)
            local heat = q.Heat + 0.15 * math.sin(t * 40 + q.X * 7) * (1 - math.min(1, k * 5)) - cool * 1.5
            q.P.Color = (heat > -0.15) and Ramp(math.max(0, heat)) or COLD:Lerp(P.Dark, math.clamp((-heat - 0.15) / 0.3, 0, 1))
            local off = q.V * k + V(0, -2 * k * k, 0) -- (a little drag, they slow as they rise)
            local shrink = 1 - 0.55 * cool
            q.P.Size = V(cell * 0.92 * shrink, cell * 0.92 * shrink, cell * 0.5 * shrink)
            q.P.CFrame = frame * CFrame.new(q.X + off.X, q.Y + off.Y, zf + off.Z) * CFrame.Angles(0, 0, q.Spin * k)
            q.P.Transparency = (t < 0.03) and 1 or math.clamp(smooth((cool - 0.55) / 0.45), 0, 1)
        end
    end, function() model:Destroy() end)
end

-- ===== THERMAL LOCK banner (lower right, beside the weapon card): a dark plate, two brackets close on a heat bloom, a
-- 5-notch heat gauge climbs with the streak; at 5 the bloom flashes white-hot =====
local WORDS = { "WARM", "HOT", "SEARING", "BLAZING", "WHITE-HOT" }
local banner
Set.Banner = function(H: any, streak: number)
    local gui, root = H.BannerRoot("Infrared", Vector2.new(180, 90), "Side")
    if not root then return end
    if not banner or banner.Root ~= root then
        local New = H.New
        local plate = New("Frame", { BackgroundColor3 = P.Dark:Lerp(P.Cold, 0.15), BackgroundTransparency = 0.12, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, root,
            { New("UIStroke", { Color = P.Mid:Lerp(P.Cold, 0.4), Thickness = 1.5 }) })
        local emb = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.EmblemInfrared, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(42, 40), Size = UDim2.fromOffset(56, 56) }, plate)
        local br = {}
        for i, c in ipairs({ { 0, 0, 0 }, { 1, 0, 90 }, { 1, 1, 180 }, { 0, 1, 270 } }) do
            br[i] = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.InfraredBracket, ImageColor3 = HOT, AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromOffset(16, 16), Rotation = c[3], Position = UDim2.fromOffset(42, 40) }, plate)
            br[i]:SetAttribute("Corner", Vector2.new(c[1] * 2 - 1, c[2] * 2 - 1))
        end
        local word = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(80, 16), Size = UDim2.fromOffset(94, 26),
            Font = Enum.Font.Oswald, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = P.Text, Text = "" }, plate)
        local notches = {}
        for i = 1, 5 do
            notches[i] = New("Frame", { BorderSizePixel = 0, BackgroundColor3 = P.Body:Lerp(P.Cold, 0.3), Position = UDim2.fromOffset(80 + (i - 1) * 18, 54), Size = UDim2.fromOffset(15, 14) }, plate)
        end
        banner = { Root = root, Plate = plate, Emblem = emb, Brackets = br, Word = word, Notches = notches, Token = 0, T0 = 0 }
        H.RunService.RenderStepped:Connect(function()
            local b = banner
            if not (b and b.Root.Visible) then return end
            local t = os.clock() - b.T0
            local close = smooth(t / 0.22)
            for _, bi in ipairs(b.Brackets) do
                local c = bi:GetAttribute("Corner")
                local d = 34 - 14 * close
                bi.Position = UDim2.fromOffset(42 + c.X * d, 40 + c.Y * d)
            end
        end)
    end
    local b = banner
    b.Token += 1
    local token = b.Token
    root.Visible = true
    b.T0 = os.clock()
    b.Word.Text = WORDS[streak] or WORDS[1]
    b.Word.TextColor3 = (streak >= 5) and WHITE or P.Text
    b.Word.TextTransparency = 0
    for i, n in ipairs(b.Notches) do
        n.BackgroundColor3 = (i <= streak) and Ramp((i - 0.5) / 5 * 1.25) or P.Body:Lerp(P.Cold, 0.3)
        n.BackgroundTransparency = 0
    end
    b.Emblem.ImageColor3 = (streak >= 5) and WHITE or Color3.new(1, 1, 1)
    b.Emblem.ImageTransparency = 0
    b.Plate.BackgroundTransparency = 0.12
    for _, bi in ipairs(b.Brackets) do bi.ImageColor3 = (streak >= 5) and WHITE or HOT; bi.ImageTransparency = 0 end
    task.delay(1.4, function()
        if b.Token ~= token then return end
        local ti = TweenInfo.new(0.3)
        H.TweenService:Create(b.Plate, ti, { BackgroundTransparency = 1 }):Play()
        H.TweenService:Create(b.Word, ti, { TextTransparency = 1 }):Play()
        H.TweenService:Create(b.Emblem, ti, { ImageTransparency = 1 }):Play()
        for _, n in ipairs(b.Notches) do H.TweenService:Create(n, ti, { BackgroundTransparency = 1 }):Play() end
        for _, bi in ipairs(b.Brackets) do H.TweenService:Create(bi, ti, { ImageTransparency = 1 }):Play() end
        task.delay(0.32, function() if b.Token == token then root.Visible = false end end)
    end)
end

-- ===== sounds (tools/make_skin_sfx_v3.py infrared: every moment from CC0 recordings; tools/audio_ids.json) =====
Set.Sounds = {
    Fire = { Id = 0, Volume = 0 }, Equip = { Id = 101720729993753, Volume = 0.4 }, MagOut = { Id = 132711227221169, Volume = 0.3 },
    MagIn = { Id = 136539119446786, Volume = 0.32 }, Kill = { Id = 83019208206782, Volume = 0.5 }, Impact = { Id = 101104817527352, Volume = 0.18 },
    Swing = { Id = 124091707148154, Volume = 0.4 }, MeleeHit = { Id = 83778204944384, Volume = 0.42 }, Cool = { Id = 135847665225524, Volume = 0.22 },
    -- (each gun's own full shot; volumes matched to the base guns' level: tools/make_skin_sfx_v3.py RMS check)
    FireGun = { M4A1 = { Id = 90328496791722, Volume = 0.8 }, USP = { Id = 112679159647837, Volume = 0.56 }, BM4 = { Id = 73616545214794, Volume = 0.74 } },
}

-- ===== the THERMAL KNIFE (melee, Knife class): a matte black drop point (WeaponAssets.MeleeModels.Infrared); its edge
-- heats from the guard outward on the draw and after every swing; a sensor dot blinks in the handle =====
Set.Melee = {
    Skin = { Name = "Thermal Knife", Price = 449, ProductId = 0,
        Desc = "A matte black drop-point combat knife with a graphite edge bevel, jimped spine, an angular guard and a polymer grip with a sensor window. Its edge carries the thermal ramp: drawn, the heat runs from the guard to the tip; every swing heats it again and it cools from violet back to black. Every kill COOLS DOWN." },
    Rig = { Class = "Knife", BladeLen = 0.8 },
    FlatBlade = true,
    InspectEvents = { { "Flip", "IRWave" } },
    Build = function(m: Model, o: any, H: any, Part: any, CYL_Y: CFrame)
        local CF, ANG, R = H.CF, H.ANG, H.R
        local parts = H.CloneModel(m, "MeleeModels", "Infrared", VAR, nil)
        for _, h in ipairs(HEAT.Knife or {}) do
            local cf = CF(h.C) * ANG(0, 0, R(h.Rz or 0))
            if h.Kind == "lens" then
                local dot = H.Deco(m, { Name = "GripLens", Shape = Enum.PartType.Ball, Size = h.S, CFrame = cf, Color = HOT, Glow = true, Zone = "Grip" })
                dot:SetAttribute("GlowDrive", "Lens"); dot:SetAttribute("GlowCold", 0.75); dot:SetAttribute("GlowHot", 0)
            else
                -- the edge strip sits on the edge itself, as thick as the bevel there
                local p = H.Deco(m, { Name = "Edge", Size = V(h.S.X, h.S.Y, 0.006), CFrame = cf, Color = COLD, Glow = true, Zone = "Edge" })
                HeatAttrs(p, h.D, 0.6)
            end
        end
        -- swing trail off the blade (white-hot -> violet)
        local blade = parts.Blade
        if blade then
            local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
            a0.Name, a1.Name = "TrailBase", "TrailTip"
            a0.Position = blade.CFrame:PointToObjectSpace(V(0.03, 0.32, 0))
            a1.Position = blade.CFrame:PointToObjectSpace(V(0.0, 0.9, 0))
            a0.Parent, a1.Parent = blade, blade
            local tr = Instance.new("Trail")
            tr.Attachment0, tr.Attachment1 = a0, a1
            tr.Color = ColorSequence.new(HOT, COLD)
            tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
            tr.LightEmission, tr.LightInfluence = 0.8, 0
            tr.Lifetime, tr.MinLength, tr.FaceCamera = 0.14, 0.02, true
            tr.Enabled = false
            tr:SetAttribute("SwingTrail", true)
            tr.Parent = blade
        end
    end,
}

-- ===== arms: THERMAL SHELLS (glove) + SOFTSHELL SLEEVES (sculpted mesh pieces, WeaponAssets.ArmsModels.Infrared) =====
-- Glove: matte black tactical glove, a graphite knuckle shell; ONE effect: after sustained fire the shell's ridge tops
-- bloom with heat and fade over ~2 s (a short bloom on a kill / inspect). Sleeve: black softshell (a faint weave), a
-- sculpted ventilated forearm panel, a strap cuff, one tiny steady LED.
Set.Glove = function(K: any)
    local C3, V3 = K.C, K.V
    return {
        Id = "ThermalShells", Name = "Thermal Shells", Price = 449,
        Desc = "Matte black tactical gloves with a faceted graphite knuckle shell and a strapped cuff. Sustained fire heats the shell: its ridges bloom through the thermal ramp and bleed off over a couple of seconds, flaring once more on a kill.",
        Base = { Color = C3(22, 22, 28), Material = Enum.Material.SmoothPlastic },
        Parts = {
            { Mesh = "Infrared/Knuckle", MeshV = VAR, Size = V3(1.04, 0.16, 0.3), Off = V3(0, 0.53, -0.25) },
            { Mesh = "Infrared/KHeat", Size = V3(0.893, 0.018, 0.18), Off = V3(0, 0.615, -0.25), Glow = true, Color = COLD, Transparency = 1,
              HeatBloom = { A = COLD, Mid = WARM, B = HOT, Min = 0.32, Peak = 0.85 } },
            { Mesh = "Infrared/Cuff", MeshV = VAR, Size = V3(1.12, 1.12, 0.16), Off = V3(0, 0, 0.42) },
            { Size = V3(0.56, 0.05, 0.26), Off = V3(0, 0.525, 0.1), Color = C3(40, 42, 50), Material = Enum.Material.SmoothPlastic },
        },
    }
end
Set.Sleeve = function(K: any)
    local C3, V3 = K.C, K.V
    return {
        Id = "SoftshellSleeves", Name = "Softshell Sleeves", Price = 299,
        Desc = "A black softshell sleeve with a faint weave, a sculpted graphite vent panel along the forearm (three slanted vents), a strapped cuff at the wrist and one small steady status light. Part of the Infrared set.",
        Base = { Color = C3(24, 24, 30), Material = Enum.Material.SmoothPlastic, Tex = "InfraredWeave", TexTile = 0.8, TexT = 0.9 },
        Parts = {
            { Mesh = "Infrared/Vent", MeshV = VAR, Size = V3(0.62, 0.11, 0.56), Off = V3(0, 0.55, 0.02) },
            { Mesh = "Infrared/Cuff", MeshV = VAR, Size = V3(1.1, 1.1, 0.12), Off = V3(0, 0, -0.44) },
            { Mesh = "Infrared/Cuff", MeshV = VAR, Size = V3(1.1, 1.1, 0.08), Off = V3(0, 0, 0.36) },
            { Shape = "Ball", Uniform = true, Size = V3(0.07, 0.07, 0.07), Off = V3(0.22, 0.6, 0.27), Color = GLOW, Glow = true, Transparency = 0.3 },
        },
    }
end

-- ===== health bar: a thermal fill (cold at the empty end -> hot at full) over a faint thermal noise; the hit point
-- flares white-hot and cools; a scan line passes every 2 s =====
Set.Bar = { Id = "Infrared", Name = "Infrared", Price = 149,
    Desc = "The enemy's health read through a thermal camera: the fill runs from cold violet at the empty end to hot orange at full, the point where it was hit flares white-hot, the lost piece burns out white and cools to dark, and a scan line sweeps it every two seconds. Part of the Infrared set.",
    Look = "Ink", FillColor = HOT, ChipMotion = "Burn", Chip = WHITE, Back = C(8, 6, 12), Segments = 0,
    Decor = { "ThermalFill", "HeatScan" } }
Set.BarDecor = {
    ThermalFill = function(ctx: any, K: any)
        local f = K.Fader()
        local fill = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 4 }, ctx.Inner)
        K.New("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, COLD), ColorSequenceKeypoint.new(0.5, WARM), ColorSequenceKeypoint.new(1, HOT) }) }, fill)
        f.Add(fill, 0.22, "BackgroundTransparency")
        local spot = f.Add(K.Img("glow", { AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = WHITE, ZIndex = 9 }, ctx.Holder), 1)
        local heat = 0
        return function(now, dt, alpha, info)
            heat = math.max(heat * math.exp(-dt * 2.2), info.Hit)
            f.Apply(alpha)
            local U = ctx.U
            spot.Position = UDim2.fromOffset(ctx.W * info.Shown, ctx.H / 2)
            local sk = (ctx.Tier == "Small") and 0.6 or 1
            spot.Size = UDim2.fromOffset(U * sk * (1.4 + heat * 1.6), U * sk * (1.4 + heat * 1.6))
            spot.ImageColor3 = WHITE:Lerp(HOT, 1 - heat):Lerp(WARM, math.max(0, 0.6 - heat))
            spot.ImageTransparency = 1 - alpha * (0.15 + 0.75 * heat)
        end
    end,
    HeatScan = function(ctx: any, K: any)
        local line = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = WHITE, Size = UDim2.new(0, 2, 1, 0), ZIndex = 6 }, ctx.Inner)
        return function(now, dt, alpha, info)
            local t = (now % 2) / 0.6
            line.Visible = t < 1 and alpha > 0.05
            line.Position = UDim2.fromOffset(ctx.W * t, 0)
            line.BackgroundTransparency = 1 - alpha * 0.45 * math.sin(math.min(t, 1) * math.pi)
        end
    end,
}

-- ===== UI theme v2 (FX roll-out 2026-10-14; v1 = the shared template: heat-map tile + scan tile + corner sprites +
-- watermark + embers + a sweep). Its own pieces, in the icon look: every window is a THERMAL SIGHT -- four heat-orange
-- reticle brackets (flat face, one hard facet, ink edge) LOCK onto the window's corners, a heat-scale ramp (cold -> white-
-- hot) runs down the right edge with a small reading marker that drifts as if the scene's temperature changes, and a faint
-- scan line passes down the window now and then. OPEN = acquire: the brackets slide in from outside and lock with a tiny
-- overshoot, a bright scan line sweeps down once and the ramp fills from cold to hot (0.45 s). Title bars get a short
-- ramp chip and a reticle dot. Colours from the theme table (Cold / Warm / Hot / White / Ink).
local function IrFacet(ctx, o, lit, shade, inkW)
    local g = Instance.new("UIGradient")
    g.Color = ctx.UIStyle.Facet(lit, shade)
    g.Rotation = ctx.UIStyle.FACET_ROT or 35
    g.Parent = o
    local ink = ctx.UIStyle.InkEdge(inkW or 2)
    ink.Parent = o
end
local function IrRamp(t)
    return ColorSequence.new({ ColorSequenceKeypoint.new(0, t.White), ColorSequenceKeypoint.new(0.3, t.Hot), ColorSequenceKeypoint.new(0.65, t.Warm),
        ColorSequenceKeypoint.new(1, t.Cold) })
end
local function IrDeco(ctx)
    if ctx.Kind ~= "Window" then return nil end
    local t = ctx.Theme
    local host = ctx.Root or ctx.Surface
    local f = Instance.new("Frame")
    f.Name = "IrOverlay"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 20; f.Active = false
    f:SetAttribute("NoSkin", true); f:SetAttribute("Skinned", true)
    f.Parent = host
    local small = math.min(host.AbsoluteSize.X, host.AbsoluteSize.Y) < 260
    local len, th = small and 18 or 34, small and 5 or 8
    local brackets = {}
    for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
        local h = Instance.new("Frame")
        h.Name = "IrBracket"; h.BackgroundTransparency = 1; h.Size = UDim2.fromOffset(len, len); h.AnchorPoint = Vector2.new(c[1], c[2])
        h.ZIndex = f.ZIndex + 1; h.Parent = f
        for i = 1, 2 do
            local b = Instance.new("Frame")
            b.Name = "IrBar"; b.BorderSizePixel = 0; b.BackgroundColor3 = Color3.new(1, 1, 1); b.ZIndex = h.ZIndex
            b.Size = (i == 1) and UDim2.fromOffset(len, th) or UDim2.fromOffset(th, len)
            b.AnchorPoint = Vector2.new(c[1], c[2]); b.Position = UDim2.fromScale(c[1], c[2]); b.Parent = h
            IrFacet(ctx, b, t.Hot, t.Warm, 2)
        end
        table.insert(brackets, { F = h, AX = c[1], AY = c[2] })
    end
    -- the heat-scale ramp down the right edge + its reading marker
    local ramp = Instance.new("Frame")
    ramp.Name = "IrRamp"; ramp.BorderSizePixel = 0; ramp.BackgroundColor3 = Color3.new(1, 1, 1); ramp.AnchorPoint = Vector2.new(1, 0.5)
    ramp.Position = UDim2.new(1, -7, 0.55, 0); ramp.Size = UDim2.new(0, small and 4 or 6, 0.4, 0); ramp.ZIndex = f.ZIndex + 1; ramp.Parent = f
    local rg = Instance.new("UIGradient"); rg.Rotation = 90; rg.Color = IrRamp(t); rg.Parent = ramp
    local rk = ctx.UIStyle.InkEdge(2); rk.Parent = ramp
    local mark = Instance.new("Frame")
    mark.Name = "IrMark"; mark.BorderSizePixel = 0; mark.BackgroundColor3 = t.White; mark.AnchorPoint = Vector2.new(1, 0.5)
    mark.Size = UDim2.fromOffset(small and 7 or 11, 3); mark.ZIndex = ramp.ZIndex + 1; mark.Parent = ramp
    local mk = ctx.UIStyle.InkEdge(1); mk.Parent = mark
    -- a faint scan line now and then
    local scan = Instance.new("Frame")
    scan.Name = "IrScan"; scan.BorderSizePixel = 0; scan.BackgroundColor3 = t.Hot; scan.Size = UDim2.new(1, -16, 0, 2); scan.Position = UDim2.fromOffset(8, 0)
    scan.BackgroundTransparency = 1; scan.ZIndex = f.ZIndex; scan.Parent = f
    local sgr = Instance.new("UIGradient")
    sgr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.55), NumberSequenceKeypoint.new(0.8, 0.55),
        NumberSequenceKeypoint.new(1, 1) }); sgr.Parent = scan
    f:SetAttribute("IrLock", 1)
    local nextScan = os.clock() + 3 + math.random() * 3
    local scanAt = -10
    local ph = math.random() * 6.28
    return function(now, dt)
        local lock = f:GetAttribute("IrLock") or 1
        -- (lock 0 -> 1: the brackets slide in from 26 px outside, overshoot 3 px, settle)
        local o = (1 - lock) * 26 - 3 * math.sin(math.clamp(lock, 0, 1) * math.pi) * (lock < 1 and 1 or 0)
        for _, b in ipairs(brackets) do
            b.F.Position = UDim2.new(b.AX, (b.AX == 0) and (4 - o) or (o - 4), b.AY, (b.AY == 0) and (4 - o) or (o - 4))
        end
        rg.Offset = Vector2.new(0, (1 - math.min(1, lock)) * 1.0)
        mark.Position = UDim2.new(0, -2, 0.5 + 0.32 * math.sin(now * 0.4 + ph) * math.sin(now * 0.13 + ph * 2), 0)
        if now >= nextScan then nextScan = now + 6 + math.random() * 4; scanAt = now end
        local k = (now - scanAt) / 1.6
        if k < 1 then
            scan.Position = UDim2.new(0, 8, k, 0)
            scan.BackgroundTransparency = 0.45 + 0.55 * math.abs(k * 2 - 1) ^ 3
        elseif scan.BackgroundTransparency < 1 then scan.BackgroundTransparency = 1 end
    end, { f }
end
local function IrOpen(ctx)
    -- ACQUIRE: brackets slide in and lock, a bright scan line sweeps down once, the ramp fills cold -> hot
    local t = ctx.Theme
    local f = ctx.Root and ctx.Root:FindFirstChild("IrOverlay")
    if not f then return end
    local line = Instance.new("Frame")
    line.Name = "IrAcquire"; line.BorderSizePixel = 0; line.BackgroundColor3 = t.White; line.Size = UDim2.new(1, 0, 0, 3); line.ZIndex = f.ZIndex + 3
    line.Parent = f
    local g = Instance.new("UIGradient"); g.Color = ColorSequence.new(t.Warm, t.White); g.Parent = line
    local trail = Instance.new("Frame")
    trail.Name = "IrAcquireTrail"; trail.BorderSizePixel = 0; trail.BackgroundColor3 = t.Hot; trail.AnchorPoint = Vector2.new(0, 1)
    trail.Position = UDim2.fromScale(0, 0); trail.Size = UDim2.new(1, 0, 0, 40); trail.ZIndex = f.ZIndex + 2; trail.Parent = line
    local tg = Instance.new("UIGradient"); tg.Rotation = 90
    tg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.82) }); tg.Parent = trail
    local t0 = os.clock()
    f:SetAttribute("IrLock", 0)
    local conn
    conn = game:GetService("RunService").RenderStepped:Connect(function()
        local k = os.clock() - t0
        if not f.Parent then conn:Disconnect(); line:Destroy() return end
        f:SetAttribute("IrLock", 1 - (1 - math.clamp(k / 0.25, 0, 1)) ^ 3)
        local s = math.clamp((k - 0.08) / 0.34, 0, 1)
        line.Position = UDim2.new(0, 0, s, 0)
        line.BackgroundTransparency = (k < 0.08) and 1 or 0.1 + 0.9 * s ^ 4
        trail.BackgroundTransparency = (k < 0.08) and 1 or s ^ 2
        if k >= 0.45 then conn:Disconnect(); line:Destroy(); f:SetAttribute("IrLock", 1) end
    end)
end
local function IrTitle(ctx)
    -- a short heat-ramp chip with an ink edge, then a reticle dot
    local bar, t = ctx.Title, ctx.Theme
    local chip = Instance.new("Frame")
    chip.Name = "IrChip"; chip.BorderSizePixel = 0; chip.BackgroundColor3 = Color3.new(1, 1, 1); chip.AnchorPoint = Vector2.new(0, 1)
    chip.Position = UDim2.new(0, 10, 1, -3); chip.Size = UDim2.new(0.22, 0, 0, 4); chip.ZIndex = bar.ZIndex + 1; chip.Parent = bar
    local g = Instance.new("UIGradient"); g.Color = IrRamp(t); g.Rotation = 180; g.Parent = chip
    local ink = ctx.UIStyle.InkEdge(1); ink.Parent = chip
    local dot = Instance.new("Frame")
    dot.Name = "IrDot"; dot.BorderSizePixel = 0; dot.BackgroundColor3 = t.Hot; dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.new(0.22, 20, 1, -5); dot.Size = UDim2.fromOffset(6, 6); dot.ZIndex = bar.ZIndex + 1; dot.Parent = bar
    local ring = Instance.new("UIStroke"); ring.Color = t.Hot; ring.Thickness = 1.5; ring.Parent = dot
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = dot
    return { chip, dot }
end
-- numbers v3 (SKIN UI roll-out 2026-10-29, owner: numbers "unique to the skin and the colorways you have equipped"): a THERMAL
-- LOCK. A squared sensor-readout face (Zekton) that rises straight like a readout (no pop) and flickers on as the sensor
-- acquires; four reticle corner brackets SNAP IN round the digits (from wide to tight, again on every merged hit) and the digits
-- carry the thermal sweep (white-hot core, warm edges). CRIT = the brackets lock twice and go white-hot, the digits flare hot;
-- WEAK SPOT = the brackets close into a full target box (centre ticks) and the digits read white-hot; a KILL = COOLDOWN (the
-- set's kill effect): the brackets close in on the number and its digits cool down the ramp to the cold end as it fades.
-- Every colour is this copy's palette (P = the colourway: Ironbow orange / violet, Arctic Scan cyan / navy, Night Vision
-- phosphor / moss).
local function IrMotion(e, age, pa, life)
    local rise = 1 - (1 - math.min(1, age / 0.8)) ^ 3
    -- (acquire: two hard flickers in the first 0.1 s, a faint one on each merged hit)
    local flick = 0
    if age < 0.1 then flick = (age < 0.03 or (age > 0.055 and age < 0.07)) and 0.7 or 0
    elseif pa < 0.04 then flick = 0.3 end
    local flare = (e.Crit and not e.Dot) and 0.13 * math.exp(-pa * 10) or 0
    return 0.45 + rise * 1.35, 0, 1 + flare, 0, flick, 0
end
local function IrAccent(e)
    local box = Instance.new("Frame")
    box.Name = "IrLock"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 0
    for i = 1, 4 do
        for j = 1, 2 do
            local b = Instance.new("Frame")
            b.Name = "C" .. i .. j; b.BorderSizePixel = 0; b.AnchorPoint = Vector2.new(0.5, 0.5); b.ZIndex = 2; b.Parent = box
        end
        local t = Instance.new("Frame")
        t.Name = "T" .. i; t.BorderSizePixel = 0; t.AnchorPoint = Vector2.new(0.5, 0.5); t.ZIndex = 2; t.Parent = box
    end
    return box
end
local IR_CORNERS = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
local function IrAccentStep(e, box, age, pa, alpha)
    local tb = e.Label.TextBounds
    local hot = (e.Crit or e.Weak) and not e.Dot
    -- snap: the brackets close from 1.7x to the digits in 0.12 s (a crit locks a second time 0.1 s later)
    local k = smooth(pa / 0.12)
    local spread = 1 + 0.7 * (1 - k)
    if e.Crit and not e.Dot then spread += 0.3 * math.max(0, math.sin(math.clamp((age - 0.12) / 0.14, 0, 1) * math.pi)) end
    local kill = (e.Killed and e.KillAt) and smooth((os.clock() - e.KillAt - 0.25) / 0.9) or 0 -- (it reads hot first, then cools)
    spread *= 1 - 0.3 * kill
    local hw, hh = tb.X / 2 + 7, tb.Y / 2 + 3
    local L = math.clamp(math.floor(tb.Y * 0.42), 6, 12)
    local th = hot and 2 or 1.5
    local col = hot and P.White or P.Hot
    if kill > 0 then col = P.Hot:Lerp(P.Cold, kill) end
    -- (bright while it locks, then it settles back so the digits lead)
    local tr = math.clamp(alpha + 0.08 + 0.4 * smooth((age - 0.25) / 0.3) * (hot and 0.6 or 1), 0, 1)
    for i, c in ipairs(IR_CORNERS) do
        local cx, cy = c[1] * hw * spread, c[2] * hh * spread
        local h, v = box:FindFirstChild("C" .. i .. "1"), box:FindFirstChild("C" .. i .. "2")
        if h and v then
            h.Size = UDim2.fromOffset(L, th); h.Position = UDim2.new(0.5, math.floor(cx - c[1] * L / 2), 0.5, math.floor(cy))
            v.Size = UDim2.fromOffset(th, L); v.Position = UDim2.new(0.5, math.floor(cx), 0.5, math.floor(cy - c[2] * L / 2))
            h.BackgroundColor3, v.BackgroundColor3 = col, col
            h.BackgroundTransparency, v.BackgroundTransparency = tr, tr
        end
        -- (weak spot: four centre ticks close the brackets into a target box)
        local t = box:FindFirstChild("T" .. i)
        if t then
            local on = e.Weak and not e.Dot
            t.Visible = on
            if on then
                local tl = math.floor(L * 0.6)
                if i <= 2 then -- left / right edge ticks
                    local sx = (i == 1) and -1 or 1
                    t.Size = UDim2.fromOffset(tl, th); t.Position = UDim2.new(0.5, math.floor(sx * (hw * spread + tl / 2 - 1)), 0.5, 0)
                else -- top / bottom edge ticks
                    local sy = (i == 3) and -1 or 1
                    t.Size = UDim2.fromOffset(th, tl); t.Position = UDim2.new(0.5, 0, 0.5, math.floor(sy * (hh * spread + tl / 2 - 1)))
                end
                t.BackgroundColor3 = col; t.BackgroundTransparency = tr
            end
        end
    end
    -- COOLDOWN: a killing number's digits cool through the ramp (hot -> warm -> cold) as it fades
    if kill > 0 and e.Grad then
        local c = (kill < 0.5) and P.Hot:Lerp(P.Warm, kill * 2) or P.Warm:Lerp(P.Cold:Lerp(P.Warm, 0.35), (kill - 0.5) * 2)
        e.Grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c:Lerp(P.Cold, 0.4)), ColorSequenceKeypoint.new(0.5, c),
            ColorSequenceKeypoint.new(1, c:Lerp(P.Cold, 0.4)) })
    end
end
-- ===== UI THEME v4 (SKIN UI THEMES roll-out 2026-10-29): the clean language in this colourway's colours (UITheme Clean) + the
-- thermal sight. Hooks read only the palette they are given (a colourway copy shares these functions):
--   TAB MARK  the underline is a HEAT SCALE (cold -> warm -> hot -> white-hot, left to right) with a white-hot reading needle
--             that drifts along its hot half on the top bar
--   FIELD     four RETICLE BRACKETS frame the screen under the top bar and LOCK ON when a menu opens (they slide in from outside
--             and settle, one faint SCAN LINE sweeps down with them); a heat-scale legend with ticks + a drifting reading sits
--             in the right margin
local IR_CLEAN = {
    Field = P.Dark:Lerp(P.Cold, 0.14), Surface = P.Dark:Lerp(P.Body, 0.55):Lerp(P.Cold, 0.1), Raised = P.Body:Lerp(P.Cold, 0.14):Lerp(P.Mid, 0.15),
    Hover = P.Mid:Lerp(P.Cold, 0.24), Well = P.Dark, Line = P.Mid:Lerp(P.Warm, 0.22), Tip = P.Dark:Lerp(P.Cold, 0.1),
    Accent = P.Hot, Mark = P.Hot, Hair = P.Warm:Lerp(P.Hot, 0.55),
    Text = P.Text, Sub = P.Text:Lerp(P.Mid, 0.38), Muted = P.Mid:Lerp(P.Text, 0.4), Ink = P.Ink,
    Cold = P.Cold, Warm = P.Warm, Heat = P.Hot, WhiteHot = P.White, InkLine = P.Ink,
}
local function IrK(t, c) return ColorSequenceKeypoint.new(t, c) end
-- (HudThemes.Variant keeps a colourway copy's Clean colour only when it DIFFERS from colourway 1's; one that is the same in
-- both palettes (the gold, a shared brass ...) went through the hue map instead -- Indigo's gold seam came out green. A
-- hair's difference keeps this copy's own colour.)
if VAR ~= 1 then for k, v in pairs(IR_CLEAN) do if typeof(v) == "Color3" then IR_CLEAN[k] = v:Lerp(Color3.new(0, 0, 0), 0.003) end end end
IR_CLEAN.TabMark = function(mark, Q)
    -- (children of a tab mark: offset-sized, inside the mark's width -- tab buttons are AutomaticSize X)
    local g = Instance.new("UIGradient")
    g.Name = "IrScale"
    g.Color = ColorSequence.new({ IrK(0, Q.Cold:Lerp(Q.Warm, 0.3)), IrK(0.42, Q.Warm), IrK(0.8, Q.Heat), IrK(1, Q.WhiteHot) })
    g.Parent = mark
    local n = Instance.new("Frame")
    n.Name = "IrNeedle"; n.BorderSizePixel = 0; n.BackgroundColor3 = Q.WhiteHot; n.Position = UDim2.new(1, -2, 0, -3)
    n.Size = UDim2.fromOffset(2, 8); n.ZIndex = mark.ZIndex + 1; n.Parent = mark
    local st = Instance.new("UIStroke"); st.Color = Q.InkLine; st.Thickness = 1; st.Parent = n
    return { g, n }
end
IR_CLEAN.Sig = function(ctx)
    local Q, f = ctx.P, ctx.Frame
    local topY = 64
    if ctx.Top and ctx.Top.AbsoluteSize.Y > 0 then topY = ctx.Top.AbsolutePosition.Y - f.AbsolutePosition.Y + ctx.Top.AbsoluteSize.Y end
    local made = {}
    -- the reticle brackets (L shapes: two thin bars each), one per screen corner, under the top bar
    local ARM, TH, IN = ctx.Phone and 18 or 28, 2, ctx.Phone and 6 or 12
    local brackets = {}
    for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
        local h = Instance.new("Frame")
        h.Name = "IrBracket"; h.BackgroundTransparency = 1; h.Size = UDim2.fromOffset(ARM, ARM); h.AnchorPoint = Vector2.new(c[1], c[2]); h.ZIndex = 0
        for i = 1, 2 do
            local b = Instance.new("Frame")
            b.Name = "Bar"; b.BorderSizePixel = 0; b.BackgroundColor3 = Q.Heat; b.BackgroundTransparency = 0.3; b.ZIndex = 0
            b.Size = (i == 1) and UDim2.fromOffset(ARM, TH) or UDim2.fromOffset(TH, ARM)
            b.AnchorPoint = Vector2.new(c[1], c[2]); b.Position = UDim2.fromScale(c[1], c[2]); b.Parent = h
        end
        h.Parent = f
        table.insert(brackets, { F = h, X = c[1], Y = c[2] })
    end
    -- (the top two hang off the top bar itself, so they sit under it wherever the menu puts it)
    if ctx.Top then
        for _, b in ipairs(brackets) do if b.Y == 0 then b.F.Parent = ctx.Top; b.InTop = true; table.insert(made, b.F) end end
    end
    local function Place(o)
        for _, b in ipairs(brackets) do
            local x = (b.X == 0) and (IN - o) or (o - IN)
            if b.InTop then b.F.AnchorPoint = Vector2.new(b.X, 0); b.F.Position = UDim2.new(b.X, x, 1, IN - o)
            else
                local y = (b.Y == 0) and (topY + IN - o) or (o - IN)
                b.F.Position = UDim2.new(b.X, x, b.Y, y)
            end
        end
    end
    Place(0)
    -- the heat-scale legend in the right margin: a white-hot -> cold strip, five ticks, a drifting reading
    local reading
    if not ctx.Phone then
        local strip = Instance.new("Frame")
        strip.Name = "IrLegend"; strip.BorderSizePixel = 0; strip.BackgroundColor3 = Color3.new(1, 1, 1); strip.AnchorPoint = Vector2.new(1, 0.5)
        strip.Position = UDim2.new(1, -7, 0.6, 0); strip.Size = UDim2.new(0, 4, 0.3, 0); strip.BackgroundTransparency = 0.25; strip.ZIndex = 0
        local g = Instance.new("UIGradient")
        g.Rotation = 90
        g.Color = ColorSequence.new({ IrK(0, Q.WhiteHot), IrK(0.3, Q.Heat), IrK(0.65, Q.Warm), IrK(1, Q.Cold) })
        g.Parent = strip
        for i = 0, 4 do
            local t = Instance.new("Frame")
            t.Name = "Tick"; t.BorderSizePixel = 0; t.BackgroundColor3 = Q.Sub; t.BackgroundTransparency = 0.45; t.AnchorPoint = Vector2.new(1, 0.5)
            t.Position = UDim2.new(0, -3, i / 4, 0); t.Size = UDim2.fromOffset((i % 2 == 0) and 6 or 3, 1); t.ZIndex = 0; t.Parent = strip
        end
        reading = Instance.new("Frame")
        reading.Name = "IrReading"; reading.BorderSizePixel = 0; reading.BackgroundColor3 = Q.WhiteHot; reading.AnchorPoint = Vector2.new(1, 0.5)
        reading.Size = UDim2.fromOffset(10, 2); reading.ZIndex = 0; reading.Parent = strip
        strip.Parent = f
    end
    -- the acquire scan: one thin line sweeps down the screen as the menu opens
    local scan = Instance.new("Frame")
    scan.Name = "IrScan"; scan.BorderSizePixel = 0; scan.BackgroundColor3 = Q.Heat; scan.BackgroundTransparency = 1; scan.Size = UDim2.new(1, 0, 0, 1)
    scan.ZIndex = 0; scan.Parent = f
    local sg = Instance.new("UIGradient")
    sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.2), NumberSequenceKeypoint.new(0.75, 0.2),
        NumberSequenceKeypoint.new(1, 1) })
    sg.Parent = scan
    local ph = math.random() * 6.28
    local last, openAt, scanAt = -99, -99, -99
    return function(now, _dt)
        -- (a gap in the ticks = the menu was closed: the next frame is an OPEN -> the brackets acquire again)
        if now - last > 0.4 then openAt = now; scanAt = now + 0.05 end
        last = now
        local k = (now - openAt) / 0.32
        if k < 1.4 then
            local o = 26 * (1 - smooth(k)) - 3 * math.sin(math.clamp(k, 0, 1) * math.pi)
            Place(o)
        elseif k < 1.6 then Place(0) end
        if reading then reading.Position = UDim2.new(0, -1, 0.5 + 0.38 * math.sin(now * 0.37 + ph) * math.sin(now * 0.11 + ph * 2), 0) end
        -- (one acquire scan per open, with the brackets: a line left on screen read as a stray line over the menu)
        local s = (now - scanAt) / 0.7
        if s >= 0 and s < 1 then
            scan.Position = UDim2.new(0, 0, s, math.floor(topY * (1 - s)))
            scan.BackgroundTransparency = 0.6 + 0.4 * math.max(s, math.abs(s * 2 - 1) ^ 3)
        elseif scan.BackgroundTransparency < 1 then scan.BackgroundTransparency = 1 end
        -- the reading needle on the selected tab's heat scale drifts along its hot half
        for _, m in ipairs(ctx.Marks()) do
            local n = m.Visible and m:FindFirstChild("IrNeedle")
            if n then n.Position = UDim2.new(0.78 + 0.22 * (0.5 + 0.5 * math.sin(now * 0.8 + ph)), -2, 0, -3) end
        end
    end, made
end
local P1 = PALETTES[1]
local function PG(top, bottom) return { Top = top, Bottom = bottom } end
Set.Theme = { Name = "Infrared", Desc = "Every menu is a thermal sight: reticle brackets lock onto the corners of the screen as it opens with a scan line sweeping down, a heat-scale reading drifts in the margin, and every tab is underlined with the heat scale. In your colourway's thermal palette.",
    Panel = PG(C(24, 18, 32), C(9, 7, 14)), Card = PG(C(34, 24, 44), C(15, 11, 21)), Title = PG(C(150, 44, 72), C(56, 14, 50)),
    Accent = C(255, 120, 40), Accent2 = C(180, 60, 255), HpFill = C(255, 120, 40), HpBg = C(30, 10, 22), XpFill = C(255, 200, 120), Text = C(255, 225, 200),
    Cold = P1.Cold, Warm = P1.Warm, Hot = P1.Hot, White = P1.White, Ink = P1.Ink,
    Tex = "InfraredThermal", TexT = 0.9, TexTile = 260, TexScroll = Vector2.new(3, -2), Emblem = "EmblemInfrared", BorderThick = 2,
    Deco = IrDeco, OpenFn = IrOpen, TitleDeco = IrTitle,
    Clean = IR_CLEAN, -- (SKIN UI THEMES: the clean palette + heat-scale tab marks + reticle lock / legend / scan; the old art is not drawn)
    -- (SKIN UI 2026-10-29: a thermal lock -- brackets snap round the digits, crit double lock, weak = target box, kill = cooldown)
    Numbers = { Font = "Zekton", Glyph = "", NoBang = true, Motion = IrMotion, Accent = IrAccent, AccentStep = IrAccentStep, Shine = { P.White, P.Warm },
        Normal = P.Text, Crit = P.Hot, Weak = P.White, Stroke = P.Ink, StrokeThick = 1.5, Size = 1.05 } }

-- ===== bundle / kill effect / store hero =====
Set.KillEffect = { Id = "Cooldown", Name = "Cooldown", Image = ART.EmblemInfrared,
    How = "Own any Infrared skin (or the Infrared bundle)",
    Desc = "The kill seen through a thermal sight: reticle brackets lock on, the body is redrawn as a blocky thermal image of glowing heat pixels, and on the beat it breaks apart, the pixels scattering up and out and cooling to dark. With the Thermal Lock kill banner." }
Set.Bundle = { Id = "InfraredBundle", Name = "Infrared Bundle", Price = 2199, BP = 799, ProductId = 0,
    Desc = "The whole Infrared set: the Infrared M4A1, USP and M4 Super 90, the Thermal Knife, Thermal Shells + Softshell Sleeves, the Infrared health bar, the Infrared UI theme and the Cooldown kill effect.",
    Contents = { "WeaponSkin:InfraredM4A1", "WeaponSkin:InfraredUSP", "WeaponSkin:InfraredBM4", "MeleeSkin:Infrared", "Glove:ThermalShells", "Sleeve:SoftshellSleeves",
        "HealthBar:Infrared", "KillEffect:Cooldown" } }
Set.Hero = { Grad = { C(46, 18, 44), C(8, 6, 14) }, Stroke = HOT, Emblem = ART.EmblemInfrared, Name = C(255, 225, 200), Chip = C(130, 40, 60) }

return Set
