--!nocheck
-- GEAR LIGHT (2026-10-09, owner: "Lighting needs to be consistent in terms of skins, guns should always look like they do
-- during daytime" -- "ensure you apply it to gloves, sleeves, melee etc"). Roblox lighting is global, so a gun in Molten
-- came out orange (sunset sun + warm ambient + warm grade), in the night hub dim and blue.
-- COUNTER-TINT, not a light: the place renders with voxel lighting (local lights are baked into a 4-stud grid and update
-- over seconds -- a light riding the camera never reaches a gun and smears over walls; tested 2026-10-10). So the colours
-- of your first-person gear (everything under the camera's GunViewmodel: gun, melee, gloves, sleeves) are multiplied by
-- the inverse of the light's colour cast, so on screen they land near their authored daylight look, at about the same
-- brightness everywhere.
--   * Neon parts are skipped (they glow their authored colour in any light)
--   * part colours + SurfaceAppearance colours (the gun meshes' body tint); the authored colour is remembered per part.
--     A part whose colour something else changes (skin drivers, colourways, a re-skin) is re-read as the new authored
--     colour; a part a driver re-colours every frame simply keeps the driver's colour
-- v2 LIVE LIGHT (2026-10-10, owner: "Some of the guns look a little green in the hub still ... make sure guns universally
-- look about the same in all current and future biomes"). v1 used ONE measured plate per light profile, taken in the
-- entry room and AFTER the colour grade: (1) a saturated / contrasty grade exaggerated the cast it measured, so the hub's
-- pink grade over-corrected guns green; (2) the room lamps aren't the arena's light (Void: teal lamps vs a purple
-- arena -> green guns out in the fight), and arenas came out dark. v2 SENSES the light where you stand every 0.25 s --
-- open sky overhead (5 rays), nearby lights, the sun on the gear's face -- and runs it through a light MODEL fitted to
-- 30 measurements over 18 biomes + the hub (tools/gear_calibrate.luau -> gear_cal_add.py -> gear_fit.py), BEFORE the grade
-- (the grade's tint is divided out; its saturation / contrast then leave a neutral gear neutral). It reads only live
-- Lighting values, so new biomes, moods and boss stages work with no table entry; RESIDUAL holds each measured profile's
-- leftover colour (open air / covered) the model misses (the client publishes Lighting attr GearProfile). Simulated on
-- the data: a grey plate within 2-5% of neutral everywhere (v1: up to 50%), except Molten, whose light has almost no
-- blue -- there the correction is scaled back along its own direction, so gear stays warm brown instead of turning olive.
local GearLight = {}

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

-- tunables (Studio: workspace attribute DevGearLight = "off" turns it off to compare). Keep in step with tools/gear_fit.py
GearLight.HUE = 0.9 -- 0..1: how much of the light's colour cast is cancelled
GearLight.CHANNEL = { 0.45, 2.6 } -- per-channel limit of the hue correction (past it the whole correction scales back)
GearLight.TARGET = 0.18 -- the pre-grade screen value (0..1) a 0.2 grey plate is brought to
GearLight.LIFT = { 0.5, 2.4 } -- brightness correction range
GearLight.STEP = 0.01 -- rewrite colours only when the correction moved this much
GearLight.EASE = 0.35 -- per 0.25 s read: how far the correction moves toward the new light (no pop at a doorway)

-- the light at the gear, per channel: A * Ambient + B * sky * OutdoorAmbient + D * lamps + E * sun on the face
-- + F * EnvironmentDiffuse * sky * Atmosphere colour; screen = K * (2^exposure * light)^P; lamp colours count G times as
-- saturated as their Color (measured: a mildly pink lamp turns a room magenta). (tools/gear_fit.py)
GearLight.MODEL = { A = 0.544, B = 0.000, D = 2.557, E = 0.307, K = 0.223, P = 0.400, F = 2.934, G = 2.566 }
-- [light profile] = { Open = the colour + brightness the model misses in open air (sky / painted-sky light) }. No Room
-- entries: under a roof the lamps light you, and their colour follows the floor's mood, so the model senses them live
-- (a per-biome room fit, tried, matched one mood and broke the next). (tools/gear_fit.py)
GearLight.RESIDUAL = { -- (colour AND brightness, light units)
    Abyss = { Open = { 0.767, 0.620, 0.750 } }, -- (LIGHTING AUDIT: re-measured on the lifted profile, MODEL held)
    Autumn = { Open = { 1.127, 1.062, 1.024 } },
    Aztec = { Open = { 0.941, 0.977, 0.881 } },
    Bayou = { Open = { 0.616, 0.743, 0.662 } }, -- (LIGHTING AUDIT: re-measured on the lifted profile, MODEL held)
    -- (UPDATE 4 SKIES: Cyber / Dream / Void re-measured on their day clock 13 -- fitted with MODEL held, the rest kept)
    Cyber = { Open = { 0.495, 0.925, 0.802 } }, -- (LIGHTING AUDIT: re-measured on the brighter profile; Void kept -- it read 89,89,89)
    Desert = { Open = { 0.833, 0.704, 0.605 } }, -- (UPDATE 4 SKIES: re-measured at its new clock 16.4, MODEL held)
    Dream = { Open = { 0.525, 0.389, 0.805 } },
    Fire = { Open = { 1.362, 1.262, 1.187 } }, -- (UPDATE 4 LIGHTING AUDIT: re-measured on the brighter Fire profile, MODEL held)
    Flats = { Open = { 0.604, 0.530, 0.469 } }, -- (LIGHTING AUDIT: re-measured on the lifted profile, MODEL held)
    Fungal = { Open = { 0.747, 0.724, 0.785 } }, -- (LIGHTING AUDIT: re-measured on the lifted profile, MODEL held)
    Gothic = { Open = { 0.601, 0.635, 0.925 } }, -- (LIGHTING AUDIT: re-measured on the lifted profile, MODEL held)
    Hub = { Open = { 1.210, 1.069, 0.994 } }, -- (UPDATE 4 NIGHT, no veil: dark haze + neutral grade, MODEL held -- Hub/range17nv)
    -- (LIGHTING AUDIT hideouts: the alcove rays reach the sky (sky 1), so Open applies; Crystal read red 87,62,55)
    HideoutAquarium = { Open = { 1.104, 0.983, 1.084 } },
    HideoutCrystal = { Open = { 1.272, 0.633, 0.450 } },
    Ice = { Open = { 0.566, 0.706, 0.881 } }, -- (LIGHTING AUDIT: Ice had no entry -- read cool 46,55,64; MODEL held)
    Jungle = { Open = { 1.095, 1.119, 0.966 } },
    Sakura = { Open = { 0.764, 0.606, 0.728 } }, -- (UPDATE 4 SKIES: re-measured at its new clock 16.0, MODEL held)
    Sky = { Open = { 1.175, 1.177, 1.208 } },
    Station = { Open = { 0.836, 0.793, 0.883 } }, -- (LIGHTING AUDIT: re-measured on the lifted profile, MODEL held)
    Storm = { Open = { 0.586, 0.622, 0.749 } }, -- (LIGHTING AUDIT: re-measured on the lifted profile, MODEL held)
    Void = { Open = { 0.531, 0.418, 0.699 } },
    Waste = { Open = { 0.702, 0.764, 0.513 } }, -- (LIGHTING AUDIT: re-measured on the lifted profile, MODEL held)
}

local NEON = Enum.Material.Neon
local ONE = Vector3.new(1, 1, 1)

local root -- the GunViewmodel model being corrected
local conns = {}
local orig = setmetatable({}, { __mode = "k" }) -- instance -> authored Color3
local wrote = setmetatable({}, { __mode = "k" }) -- instance -> the Color3 this module last wrote
local applied = ONE -- the correction currently on the parts
local want = ONE -- the correction the scene asks for
local dirty = false
local nextRead = 0

local function C3V(c: Color3): Vector3 return Vector3.new(c.R, c.G, c.B) end
local function Lum(v: Vector3): number return 0.3 * v.X + 0.59 * v.Y + 0.11 * v.Z end
local function V3(t: { number }): Vector3 return Vector3.new(t[1], t[2], t[3]) end

local function Grade(): Vector3
    local cc = Lighting:FindFirstChild("AimRngGrade")
    if cc and cc:IsA("ColorCorrectionEffect") and cc.Enabled then return C3V(cc.TintColor) end
    return ONE
end

-- LOCAL LIGHTS: every Light in the workspace, tracked by events (no per-read scan)
local lights = {}
local tracking = false
local function Track()
    if tracking then return end
    tracking = true
    local function Add(d) if d:IsA("Light") then lights[d] = true end end
    for _, d in ipairs(workspace:GetDescendants()) do Add(d) end
    workspace.DescendantAdded:Connect(Add)
    workspace.DescendantRemoving:Connect(function(d) lights[d] = nil end)
end

-- SENSE (same rules as tools/gear_calibrate.luau): rays skip see-through / non-shadow parts (the open maps' invisible walls)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local function Clear(origin: Vector3, dir: Vector3, dist: number): boolean
    local from = origin
    for _ = 1, 6 do
        local hit = workspace:Raycast(from, dir * dist, params)
        if not hit then return true end
        local inst = hit.Instance
        if inst:IsA("Terrain") then return false end
        if inst:IsA("BasePart") and inst.Transparency < 0.9 and inst.CastShadow then return false end
        from = hit.Position + dir * 0.05
    end
    return true
end
local SKY_DIRS = { Vector3.new(0, 1, 0), Vector3.new(0.7, 0.7, 0).Unit, Vector3.new(-0.7, 0.7, 0).Unit,
    Vector3.new(0, 0.7, 0.7).Unit, Vector3.new(0, 0.7, -0.7).Unit }
function GearLight.Sense(cam: Camera): any
    local cf = cam.CFrame
    local origin = cf.Position
    local ignore = { cam }
    local char = Players.LocalPlayer and Players.LocalPlayer.Character
    if char then table.insert(ignore, char) end
    params.FilterDescendantsInstances = ignore
    local sky = 0
    for _, d in ipairs(SKY_DIRS) do if Clear(origin, d, 300) then sky += 1 end end
    sky /= #SKY_DIRS
    local sunDir = Lighting:GetSunDirection()
    if sunDir.Y < -0.05 then sunDir = Lighting:GetMoonDirection() end
    local sunVis = (sunDir.Y > -0.05 and Clear(origin, sunDir, 500)) and 1 or 0
    local facing = sunVis * math.max(0, (-cf.LookVector):Dot(sunDir))
    local acc = Vector3.zero
    for l in pairs(lights) do
        local part = l.Parent
        if l.Enabled and part and part:IsA("BasePart") then
            local dist = (part.Position - origin).Magnitude
            local range = (l :: any).Range
            if range and dist < range then
                acc += C3V(l.Color) * (l.Brightness * (1 - dist / range) ^ 2)
            end
        end
    end
    return { Sky = sky, Facing = facing, Lights = acc }
end

-- the per-channel multiplier that cancels the light's cast (1,1,1 = leave the colours alone)
function GearLight.Correction(sense: any): Vector3
    local M = GearLight.MODEL
    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    local lamps = sense.Lights
    local ll = Lum(lamps)
    if ll > 1e-6 then
        lamps = Vector3.new(math.max(lamps.X / ll, 1e-4) ^ M.G, math.max(lamps.Y / ll, 1e-4) ^ M.G, math.max(lamps.Z / ll, 1e-4) ^ M.G) * ll
    end
    local light = C3V(Lighting.Ambient) * M.A
        + C3V(Lighting.OutdoorAmbient) * (M.B * sense.Sky)
        + lamps * M.D
        + ONE * (M.E * sense.Facing * Lighting.Brightness)
        + (atmo and C3V(atmo.Color) or ONE * 0.5) * (M.F * Lighting.EnvironmentDiffuseScale * sense.Sky)
    local res = GearLight.RESIDUAL[Lighting:GetAttribute("GearProfile") or ""]
    if res then
        local op = res.Open and V3(res.Open) or ONE
        local ro = res.Room and V3(res.Room) or ONE
        light *= ro + (op - ro) * sense.Sky
    end
    light *= 2 ^ math.clamp(Lighting.ExposureCompensation, -3, 3)
    -- the PRE-GRADE screen colour of a 0.2 grey plate here (grade tint included). The screen responds about LINEARLY to a
    -- part's colour (measured: corrected / raw plate = the multiplier), so dividing this colour out neutralises the gear
    local t = Grade()
    local function Plate(x: number): number return M.K * (0.2 * math.max(x, 1e-4)) ^ M.P end
    local eff = Vector3.new(math.max(Plate(light.X) * t.X, 1e-4), math.max(Plate(light.Y) * t.Y, 1e-4), math.max(Plate(light.Z) * t.Z, 1e-4))
    local l = Lum(eff)
    local s = GearLight.HUE
    local hue = Vector3.new((l / eff.X) ^ s, (l / eff.Y) ^ s, (l / eff.Z) ^ s)
    hue /= Lum(hue)
    -- a channel the light hardly has can't be pulled up: the whole correction scales back along the same direction
    local lo, hi = math.log(GearLight.CHANNEL[1]), math.log(GearLight.CHANNEL[2])
    local lx, ly, lz = math.log(hue.X), math.log(hue.Y), math.log(hue.Z)
    local k = 1
    for _, v in ipairs({ lx, ly, lz }) do
        if v > hi then k = math.min(k, hi / v) end
        if v < lo then k = math.min(k, lo / v) end
    end
    hue = Vector3.new(math.exp(lx * k), math.exp(ly * k), math.exp(lz * k))
    hue /= Lum(hue)
    local lift = math.clamp(GearLight.TARGET / l, GearLight.LIFT[1], GearLight.LIFT[2])
    return hue * lift
end

-- a channel that would pass 1 scales the whole colour down instead of clipping, so the hue stays right (white
-- SurfaceAppearances could otherwise only lose red and never gain blue)
-- BRIGHT EASE: a bright surface's lit channel clips in the tonemapper, so it carries less of the cast than the dark probe
-- plate did -- full strength turned a pearl gun lavender in Molten. The correction eases with the colour's brightness
-- (lum 1 -> x(1 - BRIGHT_EASE)). A SurfaceAppearance's Color only tints its texture, so its brightness is the texture's:
-- SURFACE_LUM[name] (the map's mean, generated), else SA_LUM (factory gun textures, the arms).
GearLight.BRIGHT_EASE = 0.55
GearLight.SA_LUM = 0.45
-- SURFACE_LUM BEGIN (tools/surface_lum.py writes this block)
GearLight.SURFACE_LUM = {
    Abyssal_AUG_V2 = 0.29, Abyssal_AUG_V3 = 0.33, Abyssal_AUG = 0.32, Abyssal_MP5_V2 = 0.28, Abyssal_MP5_V3 = 0.32,
    Abyssal_MP5 = 0.30, Aurora_PlasmaCannon_V2 = 0.30, Aurora_PlasmaCannon_V3 = 0.30, Aurora_PlasmaCannon = 0.35,
    Aurora_Railgun_V2 = 0.34, Aurora_Railgun_V3 = 0.32, Aurora_Railgun = 0.37, Cloud_M590_V2 = 0.56,
    Cloud_M590_V3 = 0.44, Cloud_M590 = 0.47, Cloud_MP40_V2 = 0.59, Cloud_MP40_V3 = 0.48, Cloud_MP40 = 0.50,
    Comet_ContinuousLaser_V2 = 0.31, Comet_ContinuousLaser_V3 = 0.33, Comet_ContinuousLaser = 0.28,
    Comet_SparkPistol_V2 = 0.29, Comet_SparkPistol_V3 = 0.30, Comet_SparkPistol = 0.27, Fairy_BEAM_V2 = 0.28,
    Fairy_BEAM_V3 = 0.30, Fairy_BEAM = 0.24, Fairy_MK11_V2 = 0.24, Fairy_MK11_V3 = 0.26, Fairy_MK11 = 0.19,
    Gacha_PKM_V2 = 0.34, Gacha_PKM_V3 = 0.35, Gacha_PKM = 0.29, Gacha_PX4_V2 = 0.19, Gacha_PX4_V3 = 0.20,
    Gacha_PX4 = 0.16, Horizon_QuadBeam_V2 = 0.26, Horizon_QuadBeam_V3 = 0.28, Horizon_QuadBeam = 0.24,
    Horizon_VoidDisintegrator_V2 = 0.23, Horizon_VoidDisintegrator_V3 = 0.26, Horizon_VoidDisintegrator = 0.21,
    Infernal_F2000 = 0.24, Infernal_SCAR = 0.20, Ironclad_AA12_V2 = 0.28, Ironclad_AA12_V3 = 0.30,
    Ironclad_AA12 = 0.32, Ironclad_BM4_V2 = 0.27, Ironclad_BM4_V3 = 0.29, Ironclad_BM4 = 0.31,
    Ironclad_R870_V2 = 0.32, Ironclad_R870_V3 = 0.34, Ironclad_R870 = 0.37, Jade_RHINO_V2 = 0.37,
    Jade_RHINO_V3 = 0.38, Jade_RHINO = 0.35, Kingyo_M249_V2 = 0.44, Kingyo_M249_V3 = 0.25, Kingyo_M249 = 0.36,
    Kingyo_SKS_V2 = 0.34, Kingyo_SKS_V3 = 0.19, Kingyo_SKS = 0.27, Kitsune_KSG_V2 = 0.18, Kitsune_KSG_V3 = 0.18,
    Kitsune_KSG = 0.16, Kitsune_M40_V2 = 0.30, Kitsune_M40_V3 = 0.32, Kitsune_M40 = 0.28, Mecha_EMR_V2 = 0.25,
    Mecha_EMR_V3 = 0.15, Mecha_EMR = 0.23, Mecha_HK21_V2 = 0.25, Mecha_HK21_V3 = 0.15, Mecha_HK21 = 0.23,
    Neko_PPSH_V2 = 0.39, Neko_PPSH_V3 = 0.43, Neko_PPSH = 0.43, Neko_SVD_V2 = 0.29, Neko_SVD_V3 = 0.33,
    Neko_SVD = 0.33, Neon_MP7_V2 = 0.34, Neon_MP7_V3 = 0.37, Neon_MP7 = 0.34, Neon_P90_V2 = 0.28, Neon_P90_V3 = 0.33,
    Neon_P90 = 0.30, Origami_P226_V2 = 0.23, Origami_P226_V3 = 0.25, Origami_P226 = 0.24, Origami_TAR21_V2 = 0.26,
    Origami_TAR21_V3 = 0.27, Origami_TAR21 = 0.27, Seraphim_AK47 = 0.78, Seraphim_M4A1 = 0.79, Solaris_AWP_V2 = 0.41,
    Solaris_AWP_V3 = 0.24, Solaris_AWP = 0.35, Solaris_DEAGLE_V2 = 0.47, Solaris_DEAGLE_V3 = 0.26,
    Solaris_DEAGLE = 0.39, Starlight_HK416_V2 = 0.33, Starlight_HK416_V3 = 0.29, Starlight_HK416 = 0.26,
    Starlight_VECTOR_V2 = 0.25, Starlight_VECTOR_V3 = 0.21, Starlight_VECTOR = 0.18, Sugar_DBARREL_V2 = 0.29,
    Sugar_DBARREL_V3 = 0.50, Sugar_DBARREL = 0.37, Sugar_USP_V2 = 0.25, Sugar_USP_V3 = 0.42, Sugar_USP = 0.30,
    Summer_GALIL_V2 = 0.26, Summer_GALIL_V3 = 0.24, Summer_GALIL = 0.29, Summer_USAS12_V2 = 0.22,
    Summer_USAS12_V3 = 0.20, Summer_USAS12 = 0.24, Tempest_M82_V2 = 0.22, Tempest_M82_V3 = 0.38, Tempest_M82 = 0.27,
    Tempest_SCOUT_V2 = 0.21, Tempest_SCOUT_V3 = 0.37, Tempest_SCOUT = 0.25, Verdant_TEC9_V2 = 0.26,
    Verdant_TEC9_V3 = 0.23, Verdant_TEC9 = 0.26, Verdant_UZI_V2 = 0.25, Verdant_UZI_V3 = 0.21, Verdant_UZI = 0.24,
    Yami_M60_V2 = 0.27, Yami_M60_V3 = 0.37, Yami_M60 = 0.27, Yami_SR9_V2 = 0.15, Yami_SR9_V3 = 0.19, Yami_SR9 = 0.14,
    AA12Base_AA12_Atlas = 0.28, Bespoke_Arms_Atlas_V2 = 0.17, Bespoke_Arms_Atlas_V3 = 0.12, Bespoke_Arms_Atlas = 0.12,
    Bespoke_DBARREL_Atlas_V2 = 0.17, Bespoke_DBARREL_Atlas_V3 = 0.11, Bespoke_DBARREL_Atlas = 0.12,
    Bespoke_DBARREL_OrigButton_V2 = 0.14, Bespoke_DBARREL_OrigButton_V3 = 0.13, Bespoke_DBARREL_OrigButton = 0.12,
    Bespoke_DBARREL_OrigIronSight_V2 = 0.11, Bespoke_DBARREL_OrigIronSight_V3 = 0.08,
    Bespoke_DBARREL_OrigIronSight = 0.11, Bespoke_DBARREL_OrigMainBarrel_V2 = 0.10,
    Bespoke_DBARREL_OrigMainBarrel_V3 = 0.08, Bespoke_DBARREL_OrigMainBarrel = 0.09,
    Bespoke_DBARREL_OrigMetalReceiver_V2 = 0.09, Bespoke_DBARREL_OrigMetalReceiver_V3 = 0.07,
    Bespoke_DBARREL_OrigMetalReceiver = 0.09, Bespoke_DBARREL_OrigNuts_V2 = 0.10, Bespoke_DBARREL_OrigNuts_V3 = 0.08,
    Bespoke_DBARREL_OrigNuts = 0.09, Bespoke_DBARREL_OrigReceiver_V2 = 0.09, Bespoke_DBARREL_OrigReceiver_V3 = 0.07,
    Bespoke_DBARREL_OrigReceiver = 0.09, Bespoke_DBARREL_OrigReloadPart_V2 = 0.10,
    Bespoke_DBARREL_OrigReloadPart_V3 = 0.08, Bespoke_DBARREL_OrigReloadPart = 0.09,
    Bespoke_DBARREL_OrigTriggerFrame_V2 = 0.10, Bespoke_DBARREL_OrigTriggerFrame_V3 = 0.08,
    Bespoke_DBARREL_OrigTriggerFrame = 0.09, Bespoke_DBARREL_OrigTriggerSmall_V2 = 0.15,
    Bespoke_DBARREL_OrigTriggerSmall_V3 = 0.13, Bespoke_DBARREL_OrigTriggerSmall = 0.13,
    Bespoke_DBARREL_OrigTriggerlarge_V2 = 0.17, Bespoke_DBARREL_OrigTriggerlarge_V3 = 0.16,
    Bespoke_DBARREL_OrigTriggerlarge = 0.14, Bespoke_DBARREL_OrigWoodenGripLarge_V2 = 0.10,
    Bespoke_DBARREL_OrigWoodenGripLarge_V3 = 0.07, Bespoke_DBARREL_OrigWoodenGripLarge = 0.09,
    Bespoke_DBARREL_OrigWooodenGripBack_V2 = 0.10, Bespoke_DBARREL_OrigWooodenGripBack_V3 = 0.06,
    Bespoke_DBARREL_OrigWooodenGripBack = 0.09, Bespoke_DEAGLE_Atlas_V2 = 0.23, Bespoke_DEAGLE_Atlas_V3 = 0.19,
    Bespoke_DEAGLE_Atlas = 0.16, Bespoke_DEAGLE_OrigDEFrame_V2 = 0.10, Bespoke_DEAGLE_OrigDEFrame_V3 = 0.08,
    Bespoke_DEAGLE_OrigDEFrame = 0.10, Bespoke_DEAGLE_OrigDEMag_V2 = 0.10, Bespoke_DEAGLE_OrigDEMag_V3 = 0.08,
    Bespoke_DEAGLE_OrigDEMag = 0.10, Bespoke_DEAGLE_OrigDESlide_V2 = 0.10, Bespoke_DEAGLE_OrigDESlide_V3 = 0.08,
    Bespoke_DEAGLE_OrigDESlide = 0.10, Bespoke_FX_Atlas_V2 = 0.30, Bespoke_FX_Atlas_V3 = 0.13,
    Bespoke_FX_Atlas = 0.17, Bespoke_M40_Atlas_V2 = 0.17, Bespoke_M40_Atlas_V3 = 0.11, Bespoke_M40_Atlas = 0.12,
    Bespoke_M40_OrigScope_V2 = 0.10, Bespoke_M40_OrigScope_V3 = 0.08, Bespoke_M40_OrigScope = 0.10,
    Bespoke_M40_Origm401A_V2 = 0.10, Bespoke_M40_Origm401A_V3 = 0.07, Bespoke_M40_Origm401A = 0.09,
    Bespoke_Razor_Atlas_V2 = 0.23, Bespoke_Razor_Atlas_V3 = 0.21, Bespoke_Razor_Atlas = 0.18,
    Bespoke_Stiletto_Atlas_V2 = 0.46, Bespoke_Stiletto_Atlas_V3 = 0.44, Bespoke_Stiletto_Atlas = 0.40,
    Carapace_AUG_Atlas_V2 = 0.11, Carapace_AUG_Atlas_V3 = 0.12, Carapace_AUG_Atlas_V4 = 0.11,
    Carapace_AUG_Atlas = 0.14, Carapace_AUG_Orig01Default_V2 = 0.05, Carapace_AUG_Orig01Default_V3 = 0.05,
    Carapace_AUG_Orig01Default_V4 = 0.04, Carapace_AUG_Orig01Default = 0.06, Carapace_Arms_Atlas_V2 = 0.15,
    Carapace_Arms_Atlas_V3 = 0.13, Carapace_Arms_Atlas_V4 = 0.14, Carapace_Arms_Atlas = 0.14,
    Carapace_Mandible_Atlas_V2 = 0.12, Carapace_Mandible_Atlas_V3 = 0.14, Carapace_Mandible_Atlas_V4 = 0.12,
    Carapace_Mandible_Atlas = 0.15, Carapace_SparkPistol_Atlas_V2 = 0.12, Carapace_SparkPistol_Atlas_V3 = 0.11,
    Carapace_SparkPistol_Atlas_V4 = 0.10, Carapace_SparkPistol_Atlas = 0.12, Carapace_SparkPistol_OrigBody_V2 = 0.05,
    Carapace_SparkPistol_OrigBody_V3 = 0.05, Carapace_SparkPistol_OrigBody_V4 = 0.05,
    Carapace_SparkPistol_OrigBody = 0.06, Carapace_SparkPistol_OrigHandle_V2 = 0.05,
    Carapace_SparkPistol_OrigHandle_V3 = 0.05, Carapace_SparkPistol_OrigHandle_V4 = 0.05,
    Carapace_SparkPistol_OrigHandle = 0.06, Carapace_SparkPistol_OrigLarge_V2 = 0.05,
    Carapace_SparkPistol_OrigLarge_V3 = 0.05, Carapace_SparkPistol_OrigLarge_V4 = 0.05,
    Carapace_SparkPistol_OrigLarge = 0.07, Carapace_SparkPistol_OrigSmall_V2 = 0.05,
    Carapace_SparkPistol_OrigSmall_V3 = 0.05, Carapace_SparkPistol_OrigSmall_V4 = 0.05,
    Carapace_SparkPistol_OrigSmall = 0.07, Carapace_SparkPistol_OrigSparkPistolMag_V2 = 0.05,
    Carapace_SparkPistol_OrigSparkPistolMag_V3 = 0.05, Carapace_SparkPistol_OrigSparkPistolMag_V4 = 0.05,
    Carapace_SparkPistol_OrigSparkPistolMag = 0.06, Carapace_SparkPistol_OrigSparkPistolSteel_V2 = 0.05,
    Carapace_SparkPistol_OrigSparkPistolSteel_V3 = 0.05, Carapace_SparkPistol_OrigSparkPistolSteel_V4 = 0.05,
    Carapace_SparkPistol_OrigSparkPistolSteel = 0.07, Carapace_SparkPistol_OrigSparkPistolTrig_V2 = 0.05,
    Carapace_SparkPistol_OrigSparkPistolTrig_V3 = 0.05, Carapace_SparkPistol_OrigSparkPistolTrig_V4 = 0.05,
    Carapace_SparkPistol_OrigSparkPistolTrig = 0.07, Carapace_VECTOR_Atlas_V2 = 0.13, Carapace_VECTOR_Atlas_V3 = 0.12,
    Carapace_VECTOR_Atlas_V4 = 0.12, Carapace_VECTOR_Atlas = 0.14, Carapace_VECTOR_OrigMaterial001_V2 = 0.05,
    Carapace_VECTOR_OrigMaterial001_V3 = 0.05, Carapace_VECTOR_OrigMaterial001_V4 = 0.05,
    Carapace_VECTOR_OrigMaterial001 = 0.07, Carapace_VECTOR_OrigSCOPE001_V2 = 0.05,
    Carapace_VECTOR_OrigSCOPE001_V3 = 0.05, Carapace_VECTOR_OrigSCOPE001_V4 = 0.05,
    Carapace_VECTOR_OrigSCOPE001 = 0.07, Carapace_VECTOR_OrigZenUVGenericMaterial_V2 = 0.05,
    Carapace_VECTOR_OrigZenUVGenericMaterial_V3 = 0.05, Carapace_VECTOR_OrigZenUVGenericMaterial_V4 = 0.05,
    Carapace_VECTOR_OrigZenUVGenericMaterial = 0.07, Ferroflux_AK47_Atlas_V2 = 0.19, Ferroflux_AK47_Atlas_V3 = 0.12,
    Ferroflux_AK47_Atlas_V4 = 0.14, Ferroflux_AK47_Atlas = 0.12, Ferroflux_AK47_OrigMainTexture_V2 = 0.17,
    Ferroflux_AK47_OrigMainTexture_V3 = 0.15, Ferroflux_AK47_OrigMainTexture_V4 = 0.16,
    Ferroflux_AK47_OrigMainTexture = 0.17, Ferroflux_Arms_Atlas_V2 = 0.31, Ferroflux_Arms_Atlas_V3 = 0.20,
    Ferroflux_Arms_Atlas_V4 = 0.22, Ferroflux_Arms_Atlas = 0.20, Ferroflux_FX_Atlas_V2 = 0.19,
    Ferroflux_FX_Atlas_V3 = 0.12, Ferroflux_FX_Atlas_V4 = 0.14, Ferroflux_FX_Atlas = 0.11,
    Ferroflux_Glock17_Atlas_V2 = 0.19, Ferroflux_Glock17_Atlas_V3 = 0.12, Ferroflux_Glock17_Atlas_V4 = 0.14,
    Ferroflux_Glock17_Atlas = 0.11, Ferroflux_Glock17_Origmaterial004_V2 = 0.20,
    Ferroflux_Glock17_Origmaterial004_V3 = 0.16, Ferroflux_Glock17_Origmaterial004_V4 = 0.17,
    Ferroflux_Glock17_Origmaterial004 = 0.18, Ferroflux_Railgun_Atlas_V2 = 0.17, Ferroflux_Railgun_Atlas_V3 = 0.11,
    Ferroflux_Railgun_Atlas_V4 = 0.13, Ferroflux_Railgun_Atlas = 0.10, Ferroflux_Railgun_OrigMaterial3_V2 = 0.19,
    Ferroflux_Railgun_OrigMaterial3_V3 = 0.15, Ferroflux_Railgun_OrigMaterial3_V4 = 0.16,
    Ferroflux_Railgun_OrigMaterial3 = 0.17, Ferroflux_Railgun_OrigRGCopper_V2 = 0.33,
    Ferroflux_Railgun_OrigRGCopper_V3 = 0.22, Ferroflux_Railgun_OrigRGCopper_V4 = 0.23,
    Ferroflux_Railgun_OrigRGCopper = 0.22, Ferroflux_Railgun_OrigRGMag_V2 = 0.18,
    Ferroflux_Railgun_OrigRGMag_V3 = 0.15, Ferroflux_Railgun_OrigRGMag_V4 = 0.16, Ferroflux_Railgun_OrigRGMag = 0.16,
    Ferroflux_Railgun_OrigRGTrig_V2 = 0.18, Ferroflux_Railgun_OrigRGTrig_V3 = 0.15,
    Ferroflux_Railgun_OrigRGTrig_V4 = 0.16, Ferroflux_Railgun_OrigRGTrig = 0.16, Ferroflux_Scythe_Atlas_V2 = 0.19,
    Ferroflux_Scythe_Atlas_V3 = 0.12, Ferroflux_Scythe_Atlas_V4 = 0.13, Ferroflux_Scythe_Atlas = 0.12,
    Fission_AA12_Atlas_V2 = 0.14, Fission_AA12_Atlas_V3 = 0.16, Fission_AA12_Atlas_V4 = 0.15,
    Fission_AA12_Atlas = 0.16, Fission_AA12_Origatlas_V2 = 0.12, Fission_AA12_Origatlas_V3 = 0.13,
    Fission_AA12_Origatlas_V4 = 0.11, Fission_AA12_Origatlas = 0.15, Fission_Arms_Atlas_V2 = 0.16,
    Fission_Arms_Atlas_V3 = 0.18, Fission_Arms_Atlas_V4 = 0.16, Fission_Arms_Atlas = 0.18,
    Fission_M249_Atlas_V2 = 0.14, Fission_M249_Atlas_V3 = 0.15, Fission_M249_Atlas_V4 = 0.14,
    Fission_M249_Atlas = 0.16, Fission_M249_OrigM249_V2 = 0.13, Fission_M249_OrigM249_V3 = 0.14,
    Fission_M249_OrigM249_V4 = 0.12, Fission_M249_OrigM249 = 0.16, Fission_PlasmaCannon_Atlas_V2 = 0.13,
    Fission_PlasmaCannon_Atlas_V3 = 0.15, Fission_PlasmaCannon_Atlas_V4 = 0.14, Fission_PlasmaCannon_Atlas = 0.15,
    Fission_PlasmaCannon_OrigHandle_V2 = 0.13, Fission_PlasmaCannon_OrigHandle_V3 = 0.13,
    Fission_PlasmaCannon_OrigHandle_V4 = 0.12, Fission_PlasmaCannon_OrigHandle = 0.15,
    Fission_PlasmaCannon_OrigInter_V2 = 0.13, Fission_PlasmaCannon_OrigInter_V3 = 0.13,
    Fission_PlasmaCannon_OrigInter_V4 = 0.12, Fission_PlasmaCannon_OrigInter = 0.15,
    Fission_PlasmaCannon_OrigMainBody_V2 = 0.13, Fission_PlasmaCannon_OrigMainBody_V3 = 0.13,
    Fission_PlasmaCannon_OrigMainBody_V4 = 0.12, Fission_PlasmaCannon_OrigMainBody = 0.15,
    Fission_PlasmaCannon_OrigPlasmaCannonCopper_V2 = 0.18, Fission_PlasmaCannon_OrigPlasmaCannonCopper_V3 = 0.19,
    Fission_PlasmaCannon_OrigPlasmaCannonCopper_V4 = 0.18, Fission_PlasmaCannon_OrigPlasmaCannonCopper = 0.19,
    Fission_Rod_Atlas_V2 = 0.15, Fission_Rod_Atlas_V3 = 0.16, Fission_Rod_Atlas_V4 = 0.15, Fission_Rod_Atlas = 0.17,
    Geode_PX4_Atlas_V2 = 0.17, Geode_PX4_Atlas_V3 = 0.15, Geode_PX4_Atlas_V4 = 0.15, Geode_PX4_Atlas = 0.13,
    Geode_PX4_OrigMat1001_V2 = 0.19, Geode_PX4_OrigMat1001_V3 = 0.19, Geode_PX4_OrigMat1001_V4 = 0.18,
    Geode_PX4_OrigMat1001 = 0.16, Geode_PX4_OrigPX4Mag_V2 = 0.19, Geode_PX4_OrigPX4Mag_V3 = 0.19,
    Geode_PX4_OrigPX4Mag_V4 = 0.18, Geode_PX4_OrigPX4Mag = 0.16, Geode_PX4_OrigPX4Slide_V2 = 0.19,
    Geode_PX4_OrigPX4Slide_V3 = 0.19, Geode_PX4_OrigPX4Slide_V4 = 0.17, Geode_PX4_OrigPX4Slide = 0.16,
    Geode_PX4_OrigPX4Trig_V2 = 0.19, Geode_PX4_OrigPX4Trig_V3 = 0.19, Geode_PX4_OrigPX4Trig_V4 = 0.18,
    Geode_PX4_OrigPX4Trig = 0.16, Geode_USAS12_Atlas_V2 = 0.11, Geode_USAS12_Atlas_V3 = 0.11,
    Geode_USAS12_Atlas_V4 = 0.11, Geode_USAS12_Atlas = 0.10, Geode_USAS12_Origbase_V2 = 0.13,
    Geode_USAS12_Origbase_V3 = 0.13, Geode_USAS12_Origbase_V4 = 0.13, Geode_USAS12_Origbase = 0.12,
    Geode_USAS12_Origbutt_V2 = 0.13, Geode_USAS12_Origbutt_V3 = 0.13, Geode_USAS12_Origbutt_V4 = 0.13,
    Geode_USAS12_Origbutt = 0.12, Geode_USAS12_Orighandle_V2 = 0.13, Geode_USAS12_Orighandle_V3 = 0.13,
    Geode_USAS12_Orighandle_V4 = 0.13, Geode_USAS12_Orighandle = 0.12, Geode_USAS12_Origskore1_V2 = 0.12,
    Geode_USAS12_Origskore1_V3 = 0.12, Geode_USAS12_Origskore1_V4 = 0.12, Geode_USAS12_Origskore1 = 0.12,
    Infrared_Arms_Atlas_V2 = 0.16, Infrared_Arms_Atlas_V3 = 0.16, Infrared_Arms_Atlas = 0.15,
    Infrared_BM4_Atlas_V2 = 0.13, Infrared_BM4_Atlas_V3 = 0.13, Infrared_BM4_Atlas = 0.12,
    Infrared_BM4_OrigMat1_V2 = 0.11, Infrared_BM4_OrigMat1_V3 = 0.11, Infrared_BM4_OrigMat1 = 0.11,
    Infrared_BM4_OrigMat2_V2 = 0.12, Infrared_BM4_OrigMat2_V3 = 0.12, Infrared_BM4_OrigMat2 = 0.12,
    Infrared_BM4_OrigMat3_V2 = 0.12, Infrared_BM4_OrigMat3_V3 = 0.12, Infrared_BM4_OrigMat3 = 0.11,
    Infrared_Knife_Atlas_V2 = 0.13, Infrared_Knife_Atlas_V3 = 0.13, Infrared_Knife_Atlas = 0.12,
    Infrared_M4A1_Atlas_V2 = 0.12, Infrared_M4A1_Atlas_V3 = 0.12, Infrared_M4A1_Atlas = 0.12,
    Infrared_M4A1_OrigBody1_V2 = 0.11, Infrared_M4A1_OrigBody1_V3 = 0.11, Infrared_M4A1_OrigBody1 = 0.11,
    Infrared_M4A1_Origlambert15_V2 = 0.11, Infrared_M4A1_Origlambert15_V3 = 0.11, Infrared_M4A1_Origlambert15 = 0.11,
    Infrared_USP_Atlas_V2 = 0.12, Infrared_USP_Atlas_V3 = 0.12, Infrared_USP_Atlas = 0.11,
    Infrared_USP_OrigBarrelBody_V2 = 0.11, Infrared_USP_OrigBarrelBody_V3 = 0.11, Infrared_USP_OrigBarrelBody = 0.11,
    Infrared_USP_OrigSlideMagazine_V2 = 0.11, Infrared_USP_OrigSlideMagazine_V3 = 0.11,
    Infrared_USP_OrigSlideMagazine = 0.11, Infrared_USP_OrigSmallParts_V2 = 0.11,
    Infrared_USP_OrigSmallParts_V3 = 0.12, Infrared_USP_OrigSmallParts = 0.11, Ironrune_Arms_Atlas_V2 = 0.14,
    Ironrune_Arms_Atlas_V3 = 0.08, Ironrune_Arms_Atlas = 0.11, Ironrune_Melee_Atlas_V2 = 0.20,
    Ironrune_Melee_Atlas_V3 = 0.12, Ironrune_Melee_Atlas = 0.16, Ironrune_R870_Atlas_V2 = 0.15,
    Ironrune_R870_Atlas_V3 = 0.09, Ironrune_R870_Atlas = 0.13, Ironrune_SCAR_Atlas_V2 = 0.12,
    Ironrune_SCAR_Atlas_V3 = 0.06, Ironrune_SCAR_Atlas = 0.10, Ironrune_SVD_Atlas_V2 = 0.13,
    Ironrune_SVD_Atlas_V3 = 0.07, Ironrune_SVD_Atlas = 0.11, Kintsugi_Arms_Atlas_V2 = 0.20,
    Kintsugi_Arms_Atlas_V3 = 0.21, Kintsugi_Arms_Atlas_V4 = 0.15, Kintsugi_Arms_Atlas = 0.22,
    Kintsugi_Kunai_Atlas_V2 = 0.19, Kintsugi_Kunai_Atlas_V3 = 0.22, Kintsugi_Kunai_Atlas_V4 = 0.12,
    Kintsugi_Kunai_Atlas = 0.22, Kintsugi_M60_Atlas_V2 = 0.19, Kintsugi_M60_Atlas_V3 = 0.23,
    Kintsugi_M60_Atlas_V4 = 0.12, Kintsugi_M60_Atlas = 0.23, Kintsugi_M60_OrigNone_V2 = 0.07,
    Kintsugi_M60_OrigNone_V3 = 0.09, Kintsugi_M60_OrigNone_V4 = 0.07, Kintsugi_M60_OrigNone = 0.10,
    Kintsugi_MK11_Atlas_V2 = 0.17, Kintsugi_MK11_Atlas_V3 = 0.21, Kintsugi_MK11_Atlas_V4 = 0.11,
    Kintsugi_MK11_Atlas = 0.21, Kintsugi_MK11_OrigGlass_V2 = 0.07, Kintsugi_MK11_OrigGlass_V3 = 0.09,
    Kintsugi_MK11_OrigGlass_V4 = 0.07, Kintsugi_MK11_OrigGlass = 0.10, Kintsugi_MK11_OrigGreyCoat_V2 = 0.07,
    Kintsugi_MK11_OrigGreyCoat_V3 = 0.09, Kintsugi_MK11_OrigGreyCoat_V4 = 0.07, Kintsugi_MK11_OrigGreyCoat = 0.10,
    Kintsugi_MK11_OrigWhiteCoat2_V2 = 0.07, Kintsugi_MK11_OrigWhiteCoat2_V3 = 0.09,
    Kintsugi_MK11_OrigWhiteCoat2_V4 = 0.07, Kintsugi_MK11_OrigWhiteCoat2 = 0.10,
    Kintsugi_MK11_OrigWhiteCoat_V2 = 0.07, Kintsugi_MK11_OrigWhiteCoat_V3 = 0.09,
    Kintsugi_MK11_OrigWhiteCoat_V4 = 0.07, Kintsugi_MK11_OrigWhiteCoat = 0.10, Kintsugi_P226_Atlas_V2 = 0.18,
    Kintsugi_P226_Atlas_V3 = 0.21, Kintsugi_P226_Atlas_V4 = 0.11, Kintsugi_P226_Atlas = 0.21,
    Kintsugi_P226_Orig03Default_V2 = 0.07, Kintsugi_P226_Orig03Default_V3 = 0.09,
    Kintsugi_P226_Orig03Default_V4 = 0.07, Kintsugi_P226_Orig03Default = 0.10, Kintsugi_P226_Orig07Default_V2 = 0.12,
    Kintsugi_P226_Orig07Default_V3 = 0.11, Kintsugi_P226_Orig07Default = 0.12, Kintsugi_P226_OrigP226Mag_V2 = 0.06,
    Kintsugi_P226_OrigP226Mag_V3 = 0.09, Kintsugi_P226_OrigP226Mag_V4 = 0.07, Kintsugi_P226_OrigP226Mag = 0.10,
    Kintsugi_P226_OrigP226SightR_V2 = 0.06, Kintsugi_P226_OrigP226SightR_V3 = 0.09,
    Kintsugi_P226_OrigP226SightR_V4 = 0.07, Kintsugi_P226_OrigP226SightR = 0.10, Kintsugi_P226_OrigP226Trig_V2 = 0.06,
    Kintsugi_P226_OrigP226Trig_V3 = 0.09, Kintsugi_P226_OrigP226Trig_V4 = 0.07, Kintsugi_P226_OrigP226Trig = 0.10,
    Kintsugi_P226_Origdefault_V2 = 0.06, Kintsugi_P226_Origdefault_V3 = 0.09, Kintsugi_P226_Origdefault_V4 = 0.07,
    Kintsugi_P226_Origdefault = 0.10, Kirameki_BEAM_Atlas_V2 = 0.56, Kirameki_BEAM_Atlas_V3 = 0.56,
    Kirameki_BEAM_Atlas = 0.57, Kirameki_BEAM_OrigAttachment_V2 = 0.76, Kirameki_BEAM_OrigAttachment_V3 = 0.23,
    Kirameki_BEAM_OrigAttachment = 0.37, Kirameki_BEAM_OrigBEAMCopper_V2 = 0.53,
    Kirameki_BEAM_OrigBEAMCopper_V3 = 0.60, Kirameki_BEAM_OrigBEAMCopper = 0.78, Kirameki_BEAM_OrigBEAMMag_V2 = 0.18,
    Kirameki_BEAM_OrigBEAMMag_V3 = 0.11, Kirameki_BEAM_OrigBEAMMag = 0.16, Kirameki_BEAM_OrigBEAMTrig_V2 = 0.18,
    Kirameki_BEAM_OrigBEAMTrig_V3 = 0.11, Kirameki_BEAM_OrigBEAMTrig = 0.15, Kirameki_BEAM_OrigBody_V2 = 0.73,
    Kirameki_BEAM_OrigBody_V3 = 0.22, Kirameki_BEAM_OrigBody = 0.35, Kirameki_BEAM_OrigHandle_V2 = 0.18,
    Kirameki_BEAM_OrigHandle_V3 = 0.11, Kirameki_BEAM_OrigHandle = 0.15, Kirameki_PX4_Atlas_V2 = 0.58,
    Kirameki_PX4_Atlas_V3 = 0.59, Kirameki_PX4_Atlas = 0.59, Kirameki_PX4_OrigMat1001_V2 = 0.18,
    Kirameki_PX4_OrigMat1001_V3 = 0.11, Kirameki_PX4_OrigMat1001 = 0.16, Kirameki_PX4_OrigPX4Mag_V2 = 0.18,
    Kirameki_PX4_OrigPX4Mag_V3 = 0.11, Kirameki_PX4_OrigPX4Mag = 0.16, Kirameki_PX4_OrigPX4Slide_V2 = 0.74,
    Kirameki_PX4_OrigPX4Slide_V3 = 0.22, Kirameki_PX4_OrigPX4Slide = 0.36, Kirameki_PX4_OrigPX4Trig_V2 = 0.18,
    Kirameki_PX4_OrigPX4Trig_V3 = 0.11, Kirameki_PX4_OrigPX4Trig = 0.16, Kirameki_Saber_Atlas_V2 = 0.57,
    Kirameki_Saber_Atlas_V3 = 0.48, Kirameki_Saber_Atlas = 0.48, Kirameki_USAS12_Atlas_V2 = 0.57,
    Kirameki_USAS12_Atlas_V3 = 0.57, Kirameki_USAS12_Atlas = 0.58, Kirameki_USAS12_Origbase_V2 = 0.71,
    Kirameki_USAS12_Origbase_V3 = 0.21, Kirameki_USAS12_Origbase = 0.34, Kirameki_USAS12_Origbutt_V2 = 0.90,
    Kirameki_USAS12_Origbutt_V3 = 0.89, Kirameki_USAS12_Origbutt = 0.90, Kirameki_USAS12_Orighandle_V2 = 0.18,
    Kirameki_USAS12_Orighandle_V3 = 0.11, Kirameki_USAS12_Orighandle = 0.16, Kirameki_USAS12_Origskore1_V2 = 0.18,
    Kirameki_USAS12_Origskore1_V3 = 0.11, Kirameki_USAS12_Origskore1 = 0.15, Leadlight_Arms_Atlas_V2 = 0.21,
    Leadlight_Arms_Atlas_V3 = 0.22, Leadlight_Arms_Atlas = 0.21, Leadlight_ContinuousLaser_Atlas_V2 = 0.13,
    Leadlight_ContinuousLaser_Atlas_V3 = 0.13, Leadlight_ContinuousLaser_Atlas = 0.14,
    Leadlight_ContinuousLaser_OrigContinuousLaserCoppe_V2 = 0.45,
    Leadlight_ContinuousLaser_OrigContinuousLaserCoppe_V3 = 0.46,
    Leadlight_ContinuousLaser_OrigContinuousLaserCoppe = 0.47,
    Leadlight_ContinuousLaser_OrigContinuousLaserGlow_V2 = 0.02,
    Leadlight_ContinuousLaser_OrigContinuousLaserGlow_V3 = 0.02,
    Leadlight_ContinuousLaser_OrigContinuousLaserGlow = 0.02, Leadlight_ContinuousLaser_Origlambert1_V2 = 0.16,
    Leadlight_ContinuousLaser_Origlambert1_V3 = 0.17, Leadlight_ContinuousLaser_Origlambert1 = 0.17,
    Leadlight_HK21_Atlas_V2 = 0.11, Leadlight_HK21_Atlas_V3 = 0.12, Leadlight_HK21_Atlas = 0.12,
    Leadlight_HK21_OrigG3material_V2 = 0.16, Leadlight_HK21_OrigG3material_V3 = 0.17,
    Leadlight_HK21_OrigG3material = 0.17, Leadlight_Lancet_Atlas_V2 = 0.38, Leadlight_Lancet_Atlas_V3 = 0.37,
    Leadlight_Lancet_Atlas = 0.39, Leadlight_SR9_Atlas_V2 = 0.12, Leadlight_SR9_Atlas_V3 = 0.13,
    Leadlight_SR9_Atlas = 0.13, Leadlight_SR9_OrigSR9Mag_V2 = 0.16, Leadlight_SR9_OrigSR9Mag_V3 = 0.18,
    Leadlight_SR9_OrigSR9Mag = 0.17, Leadlight_SR9_OrigSR9Slide_V2 = 0.16, Leadlight_SR9_OrigSR9Slide_V3 = 0.17,
    Leadlight_SR9_OrigSR9Slide = 0.17, Leadlight_SR9_OrigSR9Trig_V2 = 0.16, Leadlight_SR9_OrigSR9Trig_V3 = 0.17,
    Leadlight_SR9_OrigSR9Trig = 0.17, Leadlight_SR9_Origmaterial005_V2 = 0.16,
    Leadlight_SR9_Origmaterial005_V3 = 0.17, Leadlight_SR9_Origmaterial005 = 0.17, Marquee_Arms_Atlas_V2 = 0.46,
    Marquee_Arms_Atlas_V3 = 0.51, Marquee_Arms_Atlas = 0.45, Marquee_Cane_Atlas_V2 = 0.26,
    Marquee_Cane_Atlas_V3 = 0.30, Marquee_Cane_Atlas = 0.26, Marquee_M590_Atlas_V2 = 0.28,
    Marquee_M590_Atlas_V3 = 0.32, Marquee_M590_Atlas = 0.28, Marquee_M590_Origm590furniture_V2 = 0.09,
    Marquee_M590_Origm590furniture_V3 = 0.13, Marquee_M590_Origm590furniture = 0.08,
    Marquee_M590_Origm590receiver_V2 = 0.10, Marquee_M590_Origm590receiver_V3 = 0.13,
    Marquee_M590_Origm590receiver = 0.08, Marquee_PPSH_Atlas_V2 = 0.27, Marquee_PPSH_Atlas_V3 = 0.31,
    Marquee_PPSH_Atlas = 0.27, Marquee_PPSH_OrigMaterial001_V2 = 0.10, Marquee_PPSH_OrigMaterial001_V3 = 0.14,
    Marquee_PPSH_OrigMaterial001 = 0.08, Nectar_Arms_Atlas_V2 = 0.24, Nectar_Arms_Atlas_V3 = 0.34,
    Nectar_Arms_Atlas = 0.28, Nectar_Dipper_Atlas_V2 = 0.13, Nectar_Dipper_Atlas_V3 = 0.19,
    Nectar_Dipper_Atlas = 0.18, Nectar_GALIL_Atlas_V2 = 0.19, Nectar_GALIL_Atlas_V3 = 0.27, Nectar_GALIL_Atlas = 0.23,
    Nectar_GALIL_OrigMaterial006_V2 = 0.08, Nectar_GALIL_OrigMaterial006_V3 = 0.11,
    Nectar_GALIL_OrigMaterial006 = 0.11, Nectar_SKS_Atlas_V2 = 0.19, Nectar_SKS_Atlas_V3 = 0.28,
    Nectar_SKS_Atlas = 0.24, Nectar_SKS_OrigSKSBolt_V2 = 0.31, Nectar_SKS_OrigSKSBolt_V3 = 0.46,
    Nectar_SKS_OrigSKSBolt = 0.34, Nectar_SKS_OrigSKSTrig_V2 = 0.08, Nectar_SKS_OrigSKSTrig_V3 = 0.11,
    Nectar_SKS_OrigSKSTrig = 0.11, Nectar_SKS_Origmaterial008_V2 = 0.10, Nectar_SKS_Origmaterial008_V3 = 0.13,
    Nectar_SKS_Origmaterial008 = 0.15, Nectar_UZI_Atlas_V2 = 0.18, Nectar_UZI_Atlas_V3 = 0.26,
    Nectar_UZI_Atlas = 0.22, Nectar_UZI_OrigUZIMagazineandBullet_V2 = 0.04,
    Nectar_UZI_OrigUZIMagazineandBullet_V3 = 0.05, Nectar_UZI_OrigUZIMagazineandBullet = 0.06,
    Nectar_UZI_Origmaterial002_V2 = 0.09, Nectar_UZI_Origmaterial002_V3 = 0.11, Nectar_UZI_Origmaterial002 = 0.12,
    Orbiter_Arms_Atlas_V2 = 0.25, Orbiter_Arms_Atlas_V3 = 0.22, Orbiter_Arms_Atlas_V4 = 0.12,
    Orbiter_Arms_Atlas = 0.25, Orbiter_F2000_Atlas_V2 = 0.25, Orbiter_F2000_Atlas_V3 = 0.21,
    Orbiter_F2000_Atlas_V4 = 0.12, Orbiter_F2000_Atlas = 0.27, Orbiter_F2000_OrigMaterial003_V2 = 0.47,
    Orbiter_F2000_OrigMaterial003_V3 = 0.44, Orbiter_F2000_OrigMaterial003_V4 = 0.12,
    Orbiter_F2000_OrigMaterial003 = 0.56, Orbiter_F2000_OrigMaterial004_V2 = 0.46,
    Orbiter_F2000_OrigMaterial004_V3 = 0.44, Orbiter_F2000_OrigMaterial004_V4 = 0.11,
    Orbiter_F2000_OrigMaterial004 = 0.56, Orbiter_F2000_OrigMaterial005_V2 = 0.47,
    Orbiter_F2000_OrigMaterial005_V3 = 0.44, Orbiter_F2000_OrigMaterial005_V4 = 0.12,
    Orbiter_F2000_OrigMaterial005 = 0.56, Orbiter_Glaive_Atlas_V2 = 0.31, Orbiter_Glaive_Atlas_V3 = 0.26,
    Orbiter_Glaive_Atlas_V4 = 0.18, Orbiter_Glaive_Atlas = 0.32, Orbiter_P90_Atlas_V2 = 0.28,
    Orbiter_P90_Atlas_V3 = 0.23, Orbiter_P90_Atlas_V4 = 0.13, Orbiter_P90_Atlas = 0.29,
    Orbiter_P90_OrigMaterial26_V2 = 0.45, Orbiter_P90_OrigMaterial26_V3 = 0.42, Orbiter_P90_OrigMaterial26_V4 = 0.12,
    Orbiter_P90_OrigMaterial26 = 0.53, Orbiter_QuadBeam_Atlas_V2 = 0.26, Orbiter_QuadBeam_Atlas_V3 = 0.22,
    Orbiter_QuadBeam_Atlas_V4 = 0.12, Orbiter_QuadBeam_Atlas = 0.27, Orbiter_QuadBeam_OrigATTACH_V2 = 0.43,
    Orbiter_QuadBeam_OrigATTACH_V3 = 0.42, Orbiter_QuadBeam_OrigATTACH_V4 = 0.11, Orbiter_QuadBeam_OrigATTACH = 0.53,
    Orbiter_QuadBeam_OrigBODY_V2 = 0.47, Orbiter_QuadBeam_OrigBODY_V3 = 0.44, Orbiter_QuadBeam_OrigBODY_V4 = 0.12,
    Orbiter_QuadBeam_OrigBODY = 0.56, Orbiter_QuadBeam_OrigQuadBeamGlow_V2 = 0.59,
    Orbiter_QuadBeam_OrigQuadBeamGlow_V3 = 0.49, Orbiter_QuadBeam_OrigQuadBeamGlow_V4 = 0.43,
    Orbiter_QuadBeam_OrigQuadBeamGlow = 0.59, Orbiter_QuadBeam_OrigQuadBeamTrig_V2 = 0.45,
    Orbiter_QuadBeam_OrigQuadBeamTrig_V3 = 0.43, Orbiter_QuadBeam_OrigQuadBeamTrig_V4 = 0.11,
    Orbiter_QuadBeam_OrigQuadBeamTrig = 0.55, Orbiter_QuadBeam_OrigRAIL_V2 = 0.47,
    Orbiter_QuadBeam_OrigRAIL_V3 = 0.45, Orbiter_QuadBeam_OrigRAIL_V4 = 0.11, Orbiter_QuadBeam_OrigRAIL = 0.57,
    Orbiter_QuadBeam_OrigSTOCK_V2 = 0.47, Orbiter_QuadBeam_OrigSTOCK_V3 = 0.45, Orbiter_QuadBeam_OrigSTOCK_V4 = 0.11,
    Orbiter_QuadBeam_OrigSTOCK = 0.57, Permafrost_Arms_Atlas_V2 = 0.29, Permafrost_Arms_Atlas_V3 = 0.36,
    Permafrost_Arms_Atlas_V4 = 0.35, Permafrost_Arms_Atlas = 0.34, Permafrost_M82_Atlas_V2 = 0.18,
    Permafrost_M82_Atlas_V3 = 0.24, Permafrost_M82_Atlas_V4 = 0.22, Permafrost_M82_Atlas = 0.23,
    Permafrost_M82_OrigLens001_V2 = 0.30, Permafrost_M82_OrigLens001_V3 = 0.34, Permafrost_M82_OrigLens001_V4 = 0.34,
    Permafrost_M82_OrigLens001 = 0.35, Permafrost_M82_OrigM82Bolt_V2 = 0.28, Permafrost_M82_OrigM82Bolt_V3 = 0.32,
    Permafrost_M82_OrigM82Bolt_V4 = 0.32, Permafrost_M82_OrigM82Bolt = 0.33, Permafrost_M82_OrigM82Trig_V2 = 0.28,
    Permafrost_M82_OrigM82Trig_V3 = 0.32, Permafrost_M82_OrigM82Trig_V4 = 0.32, Permafrost_M82_OrigM82Trig = 0.33,
    Permafrost_M82_Origmaterial006_V2 = 0.30, Permafrost_M82_Origmaterial006_V3 = 0.33,
    Permafrost_M82_Origmaterial006_V4 = 0.34, Permafrost_M82_Origmaterial006 = 0.34, Permafrost_MP40_Atlas_V2 = 0.18,
    Permafrost_MP40_Atlas_V3 = 0.24, Permafrost_MP40_Atlas_V4 = 0.23, Permafrost_MP40_Atlas = 0.23,
    Permafrost_MP40_OrigMP40_V2 = 0.31, Permafrost_MP40_OrigMP40_V3 = 0.35, Permafrost_MP40_OrigMP40_V4 = 0.35,
    Permafrost_MP40_OrigMP40 = 0.36, Permafrost_PKM_Atlas_V2 = 0.19, Permafrost_PKM_Atlas_V3 = 0.25,
    Permafrost_PKM_Atlas_V4 = 0.24, Permafrost_PKM_Atlas = 0.24, Permafrost_PKM_OrigBODY_V2 = 0.30,
    Permafrost_PKM_OrigBODY_V3 = 0.34, Permafrost_PKM_OrigBODY_V4 = 0.34, Permafrost_PKM_OrigBODY = 0.35,
    Permafrost_Sabre_Atlas_V2 = 0.35, Permafrost_Sabre_Atlas_V3 = 0.41, Permafrost_Sabre_Atlas_V4 = 0.40,
    Permafrost_Sabre_Atlas = 0.40, Silkfang_Arms_Atlas_V2 = 0.18, Silkfang_Arms_Atlas_V3 = 0.24,
    Silkfang_Arms_Atlas_V4 = 0.17, Silkfang_Arms_Atlas = 0.16, Silkfang_EMR_Atlas_V2 = 0.15,
    Silkfang_EMR_Atlas_V3 = 0.22, Silkfang_EMR_Atlas_V4 = 0.13, Silkfang_EMR_Atlas = 0.14,
    Silkfang_EMR_OrigMM141_V2 = 0.14, Silkfang_EMR_OrigMM141_V3 = 0.16, Silkfang_EMR_OrigMM141_V4 = 0.12,
    Silkfang_EMR_OrigMM141 = 0.12, Silkfang_EMR_OrigMM142_V2 = 0.13, Silkfang_EMR_OrigMM142_V3 = 0.16,
    Silkfang_EMR_OrigMM142_V4 = 0.12, Silkfang_EMR_OrigMM142 = 0.11, Silkfang_EMR_OrigMM14_V2 = 0.13,
    Silkfang_EMR_OrigMM14_V3 = 0.16, Silkfang_EMR_OrigMM14_V4 = 0.12, Silkfang_EMR_OrigMM14 = 0.11,
    Silkfang_Fang_Atlas_V2 = 0.16, Silkfang_Fang_Atlas_V3 = 0.23, Silkfang_Fang_Atlas_V4 = 0.15,
    Silkfang_Fang_Atlas = 0.15, Silkfang_TEC9_Atlas_V2 = 0.16, Silkfang_TEC9_Atlas_V3 = 0.22,
    Silkfang_TEC9_Atlas_V4 = 0.14, Silkfang_TEC9_Atlas = 0.15, Silkfang_TEC9_OrigDefaultMaterial_V2 = 0.13,
    Silkfang_TEC9_OrigDefaultMaterial_V3 = 0.16, Silkfang_TEC9_OrigDefaultMaterial_V4 = 0.12,
    Silkfang_TEC9_OrigDefaultMaterial = 0.12, Silkfang_VoidDisintegrator_Atlas_V2 = 0.15,
    Silkfang_VoidDisintegrator_Atlas_V3 = 0.22, Silkfang_VoidDisintegrator_Atlas_V4 = 0.14,
    Silkfang_VoidDisintegrator_Atlas = 0.14, Silkfang_VoidDisintegrator_OrigMainWeapon_V2 = 0.13,
    Silkfang_VoidDisintegrator_OrigMainWeapon_V3 = 0.16, Silkfang_VoidDisintegrator_OrigMainWeapon_V4 = 0.12,
    Silkfang_VoidDisintegrator_OrigMainWeapon = 0.12, Silkfang_VoidDisintegrator_OrigVoidDisintegratorMag_V2 = 0.14,
    Silkfang_VoidDisintegrator_OrigVoidDisintegratorMag_V3 = 0.16,
    Silkfang_VoidDisintegrator_OrigVoidDisintegratorMag_V4 = 0.12,
    Silkfang_VoidDisintegrator_OrigVoidDisintegratorMag = 0.12, Slipstream_Arms_Atlas_V2 = 0.12,
    Slipstream_Arms_Atlas_V3 = 0.12, Slipstream_Arms_Atlas_V4 = 0.11, Slipstream_Arms_Atlas = 0.13,
    Slipstream_HK416_Atlas_V2 = 0.21, Slipstream_HK416_Atlas_V3 = 0.20, Slipstream_HK416_Atlas_V4 = 0.17,
    Slipstream_HK416_Atlas = 0.21, Slipstream_HK416_OrigA1Grip_V2 = 0.13, Slipstream_HK416_OrigA1Grip_V3 = 0.13,
    Slipstream_HK416_OrigA1Grip_V4 = 0.13, Slipstream_HK416_OrigA1Grip = 0.13,
    Slipstream_HK416_OrigMiscParts_V2 = 0.17, Slipstream_HK416_OrigMiscParts_V3 = 0.17,
    Slipstream_HK416_OrigMiscParts_V4 = 0.17, Slipstream_HK416_OrigMiscParts = 0.14,
    Slipstream_HK416_OrigRails_V2 = 0.12, Slipstream_HK416_OrigRails_V3 = 0.12, Slipstream_HK416_OrigRails_V4 = 0.12,
    Slipstream_HK416_OrigRails = 0.12, Slipstream_HK416_OrigSBCH_V2 = 0.11, Slipstream_HK416_OrigSBCH_V3 = 0.11,
    Slipstream_HK416_OrigSBCH_V4 = 0.11, Slipstream_HK416_OrigSBCH = 0.11, Slipstream_HK416_Origmaterial001_V2 = 0.12,
    Slipstream_HK416_Origmaterial001_V3 = 0.12, Slipstream_HK416_Origmaterial001_V4 = 0.12,
    Slipstream_HK416_Origmaterial001 = 0.12, Slipstream_MP7_Atlas_V2 = 0.13, Slipstream_MP7_Atlas_V3 = 0.12,
    Slipstream_MP7_Atlas_V4 = 0.14, Slipstream_MP7_Atlas = 0.15, Slipstream_MP7_OrigMaterial001_V2 = 0.13,
    Slipstream_MP7_OrigMaterial001_V3 = 0.12, Slipstream_MP7_OrigMaterial001_V4 = 0.13,
    Slipstream_MP7_OrigMaterial001 = 0.13, Slipstream_MP7_OrigMaterial002_V2 = 0.11,
    Slipstream_MP7_OrigMaterial002_V3 = 0.11, Slipstream_MP7_OrigMaterial002_V4 = 0.11,
    Slipstream_MP7_OrigMaterial002 = 0.11, Slipstream_MP7_OrigMaterial003_V2 = 0.12,
    Slipstream_MP7_OrigMaterial003_V3 = 0.12, Slipstream_MP7_OrigMaterial003_V4 = 0.12,
    Slipstream_MP7_OrigMaterial003 = 0.12, Slipstream_MP7_OrigMaterial004_V2 = 0.12,
    Slipstream_MP7_OrigMaterial004_V3 = 0.12, Slipstream_MP7_OrigMaterial004_V4 = 0.12,
    Slipstream_MP7_OrigMaterial004 = 0.12, Slipstream_MP7_OrigMaterial005_V2 = 0.11,
    Slipstream_MP7_OrigMaterial005_V3 = 0.11, Slipstream_MP7_OrigMaterial005_V4 = 0.11,
    Slipstream_MP7_OrigMaterial005 = 0.11, Slipstream_MP7_OrigMaterial006_V2 = 0.13,
    Slipstream_MP7_OrigMaterial006_V3 = 0.13, Slipstream_MP7_OrigMaterial006_V4 = 0.13,
    Slipstream_MP7_OrigMaterial006 = 0.13, Slipstream_MP7_OrigMaterial008_V2 = 0.13,
    Slipstream_MP7_OrigMaterial008_V3 = 0.13, Slipstream_MP7_OrigMaterial008_V4 = 0.13,
    Slipstream_MP7_OrigMaterial008 = 0.14, Slipstream_MP7_OrigMaterial009_V2 = 0.14,
    Slipstream_MP7_OrigMaterial009_V3 = 0.13, Slipstream_MP7_OrigMaterial009_V4 = 0.14,
    Slipstream_MP7_OrigMaterial009 = 0.14, Slipstream_MP7_OrigNone001_V2 = 0.12, Slipstream_MP7_OrigNone001_V3 = 0.12,
    Slipstream_MP7_OrigNone001_V4 = 0.12, Slipstream_MP7_OrigNone001 = 0.12, Slipstream_Melee_Atlas_V2 = 0.22,
    Slipstream_Melee_Atlas_V3 = 0.24, Slipstream_Melee_Atlas_V4 = 0.23, Slipstream_Melee_Atlas = 0.24,
    Slipstream_SCOUT_Atlas_V2 = 0.16, Slipstream_SCOUT_Atlas_V3 = 0.15, Slipstream_SCOUT_Atlas_V4 = 0.16,
    Slipstream_SCOUT_Atlas = 0.18, Slipstream_SCOUT_OriginitialShadingGroup_V2 = 0.12,
    Slipstream_SCOUT_OriginitialShadingGroup_V3 = 0.12, Slipstream_SCOUT_OriginitialShadingGroup_V4 = 0.12,
    Slipstream_SCOUT_OriginitialShadingGroup = 0.13, Tactile_Arms_Atlas_V2 = 0.21, Tactile_Arms_Atlas_V3 = 0.21,
    Tactile_Arms_Atlas = 0.17, Tactile_Hatchet_Atlas_V2 = 0.23, Tactile_Hatchet_Atlas_V3 = 0.23,
    Tactile_Hatchet_Atlas = 0.21, Tactile_KSG_Atlas_V2 = 0.15, Tactile_KSG_Atlas_V3 = 0.15, Tactile_KSG_Atlas = 0.13,
    Tactile_KSG_Origmaterial003_V2 = 0.16, Tactile_KSG_Origmaterial003_V3 = 0.17, Tactile_KSG_Origmaterial003 = 0.18,
    Tactile_MP5_Atlas_V2 = 0.16, Tactile_MP5_Atlas_V3 = 0.16, Tactile_MP5_Atlas = 0.15,
    Tactile_MP5_OrigAttachments_V2 = 0.17, Tactile_MP5_OrigAttachments_V3 = 0.17, Tactile_MP5_OrigAttachments = 0.19,
    Tactile_MP5_OrigGrip_V2 = 0.16, Tactile_MP5_OrigGrip_V3 = 0.17, Tactile_MP5_OrigGrip = 0.19,
    Tactile_MP5_OrigMagBarrel_V2 = 0.17, Tactile_MP5_OrigMagBarrel_V3 = 0.17, Tactile_MP5_OrigMagBarrel = 0.19,
    Tactile_TAR21_Atlas_V2 = 0.16, Tactile_TAR21_Atlas_V3 = 0.16, Tactile_TAR21_Atlas = 0.15,
    Tactile_TAR21_OrigTavorWhite_V2 = 0.16, Tactile_TAR21_OrigTavorWhite_V3 = 0.17,
    Tactile_TAR21_OrigTavorWhite = 0.18, Torchbearer_Arms_Atlas_V2 = 0.30, Torchbearer_Arms_Atlas_V3 = 0.33,
    Torchbearer_Arms_Atlas = 0.47, Torchbearer_KnifeA_Atlas_V2 = 0.26, Torchbearer_KnifeA_Atlas_V3 = 0.33,
    Torchbearer_KnifeA_Atlas = 0.39, Torchbearer_KnifeB_Atlas_V2 = 0.38, Torchbearer_KnifeB_Atlas_V3 = 0.38,
    Torchbearer_KnifeB_Atlas = 0.44, Torchbearer_KnifeC_Atlas_V2 = 0.24, Torchbearer_KnifeC_Atlas_V3 = 0.27,
    Torchbearer_KnifeC_Atlas = 0.36, Torchbearer_Knife_Atlas_V2 = 0.33, Torchbearer_Knife_Atlas_V3 = 0.33,
    Torchbearer_Knife_Atlas = 0.44, Tourbillon_AWP_Atlas_V2 = 0.14, Tourbillon_AWP_Atlas_V3 = 0.17,
    Tourbillon_AWP_Atlas_V4 = 0.13, Tourbillon_AWP_Atlas = 0.14, Tourbillon_Arms_Atlas_V2 = 0.15,
    Tourbillon_Arms_Atlas_V3 = 0.17, Tourbillon_Arms_Atlas_V4 = 0.14, Tourbillon_Arms_Atlas = 0.14,
    Tourbillon_Melee_Atlas_V2 = 0.19, Tourbillon_Melee_Atlas_V3 = 0.21, Tourbillon_Melee_Atlas_V4 = 0.18,
    Tourbillon_Melee_Atlas = 0.19, Tourbillon_RHINO_Atlas_V2 = 0.16, Tourbillon_RHINO_Atlas_V3 = 0.18,
    Tourbillon_RHINO_Atlas_V4 = 0.15, Tourbillon_RHINO_Atlas = 0.15,
}
-- SURFACE_LUM END
local function Tint(c: Color3, f: Vector3, sa: Instance?): Color3
    local v = sa and (GearLight.SURFACE_LUM[sa.Name] or GearLight.SA_LUM) or (0.3 * c.R + 0.59 * c.G + 0.11 * c.B)
    local k = 1 - GearLight.BRIGHT_EASE * v * v
    local r, g, b = c.R * f.X ^ k, c.G * f.Y ^ k, c.B * f.Z ^ k
    local m = math.max(r, g, b, 1)
    return Color3.new(r / m, g / m, b / m)
end

-- (2026-10-12) Texture / Decal overlays too: an opaque arm-block Tex kept its authored colour while the part under it
-- was corrected, so it read tan / peach in Molten (found on the TACTILE sleeve). Their colour property is Color3; a
-- texture's brightness is its image's, so it is treated like a SurfaceAppearance (SA_LUM). Not on Neon parts.
local function IsTex(d: Instance): boolean
    return d:IsA("Texture") or d:IsA("Decal")
end

local function Tintable(d: Instance): boolean
    if IsTex(d) then
        local p = d.Parent
        return p ~= nil and p:IsA("BasePart") and p.Material ~= NEON
    end
    return (d:IsA("BasePart") and d.Material ~= NEON) or d:IsA("SurfaceAppearance")
end

local function ApplyOne(d: Instance, f: Vector3)
    local prop = IsTex(d) and "Color3" or "Color"
    local cur = d[prop]
    if wrote[d] ~= cur then orig[d] = cur end -- first sight, or something else re-coloured it: that's the authored colour now
    local o = orig[d]
    local c = (f == ONE) and o or Tint(o, f, (d:IsA("SurfaceAppearance") or IsTex(d)) and d or nil)
    if c ~= cur then d[prop] = c end
    wrote[d] = d[prop] -- read back: colours are stored as 8-bit, so the float we set never compares equal (compounded)
end

-- TARGETS: the first-person GunViewmodel, and (third person, 2026-10-10: the hub plaza is darker now, owner: "without the
-- weapons / sleeves getting darker") YOUR OWN world gear -- the gun on your back, the melee at your hip, glove + sleeve
-- shells and their decorations (the caller passes those roots). Parts that stop being a target get their colour back.
local active = {} -- instance -> true: tinted right now
local rootsNow = {} -- root -> true (last frame)

local function Collect(roots: { Instance }): { Instance }
    local list, seen = {}, {}
    local function Add(d)
        if not seen[d] and Tintable(d) then seen[d] = true; table.insert(list, d) end
    end
    for _, r in ipairs(roots) do
        if r.Parent then
            Add(r)
            for _, d in ipairs(r:GetDescendants()) do Add(d) end
        end
    end
    return list
end

local function ApplyList(list: { Instance }, f: Vector3)
    local keep = {}
    for _, d in ipairs(list) do keep[d] = true; ApplyOne(d, f) end
    for d in pairs(active) do
        if not keep[d] then
            if d.Parent then ApplyOne(d, ONE) end -- (no longer a target: hand its colour back)
            wrote[d] = nil
        end
    end
    active = keep
    applied = f
end

local function Watch(roots: { Instance })
    for _, c in ipairs(conns) do c:Disconnect() end
    table.clear(conns)
    table.clear(rootsNow)
    for _, r in ipairs(roots) do
        rootsNow[r] = true
        table.insert(conns, r.DescendantAdded:Connect(function(d) if Tintable(d) then dirty = true end end))
    end
    dirty = true
end

-- camCF: unused (kept for the caller); visible: the first-person viewmodel is on screen; extra: more roots to correct
-- (your own third-person gear)
function GearLight.Step(_camCF: CFrame?, visible: boolean, extra: { Instance }?)
    local cam = workspace.CurrentCamera
    local roots = {}
    local model = cam and cam:FindFirstChild("GunViewmodel")
    if visible and model then table.insert(roots, model) end
    if extra then for _, r in ipairs(extra) do if r and r.Parent then table.insert(roots, r) end end end
    -- (a new / gone root: re-collect at once, so a fresh gun is never seen uncorrected)
    local changed = false
    local n = 0
    for _, r in ipairs(roots) do n += 1; if not rootsNow[r] then changed = true end end
    for _ in pairs(rootsNow) do n -= 1 end
    if changed or n ~= 0 then Watch(roots) end
    root = roots[1]
    local now = os.clock()
    if now >= nextRead then
        nextRead = now + 0.25
        if #roots == 0 or workspace:GetAttribute("DevGearLight") == "off" then
            want = ONE
        else
            Track()
            local ok, target = pcall(function() return GearLight.Correction(GearLight.Sense(cam)) end)
            if ok then
                -- (the first read jumps straight there; after that it eases, so walking out of a doorway fades the
                -- change instead of popping)
                want = (applied == ONE) and target or want:Lerp(target, GearLight.EASE)
            end
        end
    end
    local d = want - applied
    if dirty or math.max(math.abs(d.X), math.abs(d.Y), math.abs(d.Z)) >= GearLight.STEP then
        dirty = false
        ApplyList((#roots > 0) and Collect(roots) or {}, (#roots > 0) and want or ONE)
    end
end

function GearLight.Off()
    want = ONE
    ApplyList({}, ONE)
end

return GearLight
