--!nocheck
-- WeaponRigs: data for the real-mesh first-person viewmodel (played by ViewmodelRig).
--
-- Every gun follows one standard so skins, accessories, VFX and animations work the same on all of them:
--   * Asset: a Model in AimRngShared.WeaponAssets whose MeshParts are named by role (Frame is the root;
--     Slide, Barrel, Magazine, Trigger, Bolt, ... as the gun has them).
--   * Parts: each part's skin Zone. A weapon skin is a table of per-zone looks (see ViewmodelRig.ApplyLook).
--   * Points: named CFrames in gun space (studs, relative to the Frame part; +X = muzzle direction,
--     +Y = up, +Z = the gun's right side). Hands, muzzle flash, shell ejection, the magazine well and
--     every accessory mount are looked up by these names, so a new scope / suppressor / charm / VFX only
--     needs to know a point name.
--   * Anims: keyframe tracks (see ViewmodelRig for the channel list), Sounds and Fx.
-- The arms (Arms below) are shared by every gun and knife; gloves and sleeves re-skin their layers.
local WeaponRigs = {}

-- The viewmodel always looks as if seen at this (vertical) FOV: at any other camera FOV -- the Settings
-- slider or an ADS zoom -- ViewmodelRig squashes / stretches the arms and gun along the camera's depth,
-- which is exactly what rendering them with a fixed FOV would do. Only the world's FOV changes.
-- All camera-space numbers below (Hold, RootOffset, Poles) are as seen at this FOV.
WeaponRigs.ViewmodelFOV = 90

-- Build a point frame: X = forward, Y = up (re-orthogonalized so they're exactly perpendicular).
local function Point(pos: Vector3, forward: Vector3?, up: Vector3?): CFrame
    local y = (up or Vector3.yAxis).Unit
    local x = (forward or Vector3.xAxis)
    x = (x - y * x:Dot(y)).Unit
    return CFrame.fromMatrix(pos, x, y, x:Cross(y))
end
WeaponRigs.Point = Point

-- ==================== ARMS (shared by every weapon) ====================
local function FingerChain(prefix: string, ids: { string }): { string }
    local out = {}
    for i, id in ipairs(ids) do out[i] = prefix .. id end
    return out
end

WeaponRigs.Arms = {
    -- "Block" = blocky Roblox arms (Rivals / Sniper Arena style: a block arm + block hand on each grip point, no
    -- wrists or fingers). "Rigged" = the realistic bone-rigged arms (VAULTED 2026-10-02 -- everything below still
    -- runs, the meshes are just hidden; set Style back to "Rigged" to restore them).
    Style = "Block",
    Block = {
        Rivals = true, GripDrop = 0.1, HandLen = 0.16, -- Rivals arms: thick sleeve + glove cuff, the gun rests on the arm's end
        ArmWidth = 0.3, HandSize = 0.22, HandBox = Vector3.new(0.2, 0.26, 0.22), -- every hand is this same box (one look on every gun; sleeve = ArmWidth) -- (different sizes: equal ones made the touching faces flicker)
        HandBack = 0.04, -- the hand sits this far back along the arm from the grip point (so it wraps the grip, not inside it)
        -- shoulder points in camera space (as seen at ViewmodelFOV): just off the bottom corners of the screen
        ShoulderR = Vector3.new(0.75, -1.5, 0.1), ShoulderL = Vector3.new(-0.75, -1.5, 0.1),
        ArmColor = Color3.fromRGB(40, 44, 54), -- "shirt"
        HandColor = Color3.fromRGB(234, 184, 146), -- default skin; the player's avatar colour is used when available
    },
    Asset = "ViewArms",
    -- Where the arm rig's root (chest) sits relative to the camera.
    RootOffset = CFrame.new(0.25, -1.45, -0.452),
    -- Cosmetic layers (MeshParts): gloves re-skin Glove, sleeves re-skin Sleeve, Skin is bare fingers.
    Layers = { Glove = "Arms_Glove", Sleeve = "Arms_Sleeve", Skin = "Arms_Skin" },
    Sides = {
        R = {
            Shoulder = "R_arm_025", Elbow = "R_elbow_026", Wrist = "R_wrist_027",
            -- Elbows bend toward this camera-space point (out to the side and down).
            Pole = Vector3.new(2.2, -2.2, 0.602),
            Fingers = {
                Thumb = FingerChain("R_", { "thumb1_028", "thumb2_029", "thumb3_030" }),
                Index = FingerChain("R_", { "point1_032", "point2_033", "point3_034" }),
                Middle = FingerChain("R_", { "middle1_036", "middle2_037", "middle3_038" }),
                Ring = FingerChain("R_", { "ring1_041", "ring2_042", "ring3_043" }),
                Pinky = FingerChain("R_", { "pink1_045", "pink2_046", "pink3_047" }),
            },
        },
        L = {
            Shoulder = "L_arm_02", Elbow = "L_elbow_03", Wrist = "L_wrist_04",
            Pole = Vector3.new(-2.2, -2.2, 0.602),
            Fingers = {
                Thumb = FingerChain("L_", { "thumb1_05", "thumb2_06", "thumb3_07" }),
                Index = FingerChain("L_", { "point1_09", "point2_00", "point3_010" }),
                Middle = FingerChain("L_", { "middle1_012", "middle2_013", "middle3_014" }),
                Ring = FingerChain("L_", { "ring1_017", "ring2_018", "ring3_019" }),
                Pinky = FingerChain("L_", { "pink1_021", "pink2_022", "pink3_023" }),
            },
        },
    },
    -- How far the grip's centre line sits from the palm (studs), i.e. half the grip + palm thickness.
    PalmToGrip = 0.13,
    -- Share of a hand's roll about the forearm that the forearm takes (the rest stays at the wrist). The rig
    -- has no twist bones, so either end pinches if it takes the whole turn.
    ForearmRoll = 0.5,
    -- Hand shapes: degrees of curl per joint {base, middle, tip}; ThumbSpread swings the thumb sideways
    -- (negative = away from the palm) and ThumbTwist rolls it, so a thumb can lie flat along a frame.
    Hands = {
        Open = { Thumb = { 5, 5, 0 }, Index = { 5, 5, 5 }, Middle = { 5, 5, 5 }, Ring = { 5, 5, 5 }, Pinky = { 5, 5, 5 } },
        -- right thumb lies flat along the frame's left face, just under the slide
        PistolGrip = { Thumb = { 10, 7, 4 }, ThumbSpread = -30, ThumbTwist = -45, Index = { 30, 35, 20 }, Middle = { 45, 51, 27 }, Ring = { 47, 51, 27 }, Pinky = { 48, 51, 27 } },
        TriggerPull = { Index = { 42, 50, 28 } },
        -- support thumb points forward along the frame's left side, below and ahead of the right thumb
        Support = { Thumb = { 0, 0, 0 }, ThumbSpread = 15, ThumbTwist = -30, Index = { 60, 70, 40 }, Middle = { 65, 75, 45 }, Ring = { 68, 75, 45 }, Pinky = { 70, 75, 45 } },
        HoldMag = { Thumb = { 35, 25, 15 }, Index = { 45, 55, 35 }, Middle = { 55, 65, 40 }, Ring = { 60, 65, 40 }, Pinky = { 60, 65, 40 } },
        Fist = { Thumb = { 40, 40, 30 }, Index = { 85, 95, 60 }, Middle = { 85, 95, 60 }, Ring = { 85, 95, 60 }, Pinky = { 85, 95, 60 } },
        -- hammer grip on a melee handle: fingers wrap the handle, thumb laid over the index finger (not sticking out)
        MeleeGrip = { Thumb = { 55, 45, 30 }, ThumbSpread = -10, ThumbTwist = -55, Index = { 62, 70, 40 }, Middle = { 66, 72, 42 }, Ring = { 68, 72, 42 }, Pinky = { 70, 72, 42 } },
    },
}

-- ==================== SOUND SETS ====================
-- Swap any id here to change a sound everywhere it's used.
WeaponRigs.Sounds = {
    DEAGLE = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 1.0, Pitch = 0.62 }, -- placeholder until per-gun recordings
        MagOut = { Id = "rbxassetid://6239156710", Volume = 0.65, Pitch = 0.85 },
        MagIn = { Id = "rbxassetid://2914833164", Volume = 0.75, Pitch = 0.85 },
        SlideRelease = { Id = "rbxassetid://18919548562", Volume = 0.75, Pitch = 0.8 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 0.9 },
    },
    TEC9 = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 0.65, Pitch = 1.22 },
        MagOut = { Id = "rbxassetid://6239156710", Volume = 0.6, Pitch = 1.0 },
        MagIn = { Id = "rbxassetid://2914833164", Volume = 0.7, Pitch = 1.0 },
        SlideRelease = { Id = "rbxassetid://18919548562", Volume = 0.7, Pitch = 1.0 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 1.0 },
    },
    RHINO = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 1.0, Pitch = 0.7 },
        CylOpen = { Id = "rbxassetid://6239156710", Volume = 0.6, Pitch = 1.3 },
        ShellsOut = { Id = "rbxassetid://2914833164", Volume = 0.6, Pitch = 1.5 },
        ShellsIn = { Id = "rbxassetid://2914833164", Volume = 0.7, Pitch = 1.2 },
        CylClose = { Id = "rbxassetid://18919548562", Volume = 0.75, Pitch = 1.1 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 0.8 },
    },
    R870 = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 1.0, Pitch = 0.7 }, -- placeholder until per-gun recordings
        PumpBack = { Id = "rbxassetid://6239156710", Volume = 0.75, Pitch = 1.2 },
        PumpForward = { Id = "rbxassetid://18919548562", Volume = 0.75, Pitch = 1.1 },
        ShellIn = { Id = "rbxassetid://2914833164", Volume = 0.6, Pitch = 1.3 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 0.9 },
    },
    BM4 = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 1.0, Pitch = 0.74 },
        BoltBack = { Id = "rbxassetid://6239156710", Volume = 0.7, Pitch = 1.1 },
        BoltForward = { Id = "rbxassetid://18919548562", Volume = 0.7, Pitch = 1.0 },
        ShellIn = { Id = "rbxassetid://2914833164", Volume = 0.6, Pitch = 1.3 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 0.9 },
    },
    AA12 = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 0.95, Pitch = 0.78 },
        MagOut = { Id = "rbxassetid://6239156710", Volume = 0.65, Pitch = 0.8 },
        MagIn = { Id = "rbxassetid://2914833164", Volume = 0.75, Pitch = 0.8 },
        SlideRelease = { Id = "rbxassetid://18919548562", Volume = 0.75, Pitch = 0.85 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 0.9 },
    },
    AWP = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 1.1, Pitch = 0.6 },
        BoltUp = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 0.7 },
        BoltBack = { Id = "rbxassetid://6239156710", Volume = 0.75, Pitch = 0.9 },
        BoltForward = { Id = "rbxassetid://18919548562", Volume = 0.75, Pitch = 0.9 },
        MagOut = { Id = "rbxassetid://6239156710", Volume = 0.65, Pitch = 0.8 },
        MagIn = { Id = "rbxassetid://2914833164", Volume = 0.75, Pitch = 0.8 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 0.85 },
    },
    M82 = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 1.2, Pitch = 0.5 },
        MagOut = { Id = "rbxassetid://6239156710", Volume = 0.7, Pitch = 0.7 },
        MagIn = { Id = "rbxassetid://2914833164", Volume = 0.8, Pitch = 0.7 },
        SlideRelease = { Id = "rbxassetid://18919548562", Volume = 0.8, Pitch = 0.75 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 0.8 },
    },
    SCOUT = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 1.0, Pitch = 0.68 },
        BoltUp = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 0.75 },
        BoltBack = { Id = "rbxassetid://6239156710", Volume = 0.7, Pitch = 1.0 },
        BoltForward = { Id = "rbxassetid://18919548562", Volume = 0.7, Pitch = 1.0 },
        MagOut = { Id = "rbxassetid://6239156710", Volume = 0.6, Pitch = 0.9 },
        MagIn = { Id = "rbxassetid://2914833164", Volume = 0.7, Pitch = 0.9 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 0.9 },
    },
    UZI = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 0.65, Pitch = 1.15 }, -- placeholder until per-gun recordings
        MagOut = { Id = "rbxassetid://6239156710", Volume = 0.6, Pitch = 0.95 },
        MagIn = { Id = "rbxassetid://2914833164", Volume = 0.7, Pitch = 0.95 },
        SlideRelease = { Id = "rbxassetid://18919548562", Volume = 0.7, Pitch = 0.9 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 1.0 },
    },
    MP5 = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 0.65, Pitch = 1.1 }, -- placeholder until per-gun recordings
        MagOut = { Id = "rbxassetid://6239156710", Volume = 0.6, Pitch = 0.95 },
        MagIn = { Id = "rbxassetid://2914833164", Volume = 0.7, Pitch = 0.95 },
        SlideRelease = { Id = "rbxassetid://18919548562", Volume = 0.7, Pitch = 0.9 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 1.0 },
    },
    P90 = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 0.65, Pitch = 1.2 }, -- placeholder until per-gun recordings
        MagOut = { Id = "rbxassetid://6239156710", Volume = 0.6, Pitch = 0.95 },
        MagIn = { Id = "rbxassetid://2914833164", Volume = 0.7, Pitch = 0.95 },
        SlideRelease = { Id = "rbxassetid://18919548562", Volume = 0.7, Pitch = 0.9 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 1.0 },
    },
    MP7 = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 0.65, Pitch = 1.18 }, -- placeholder until per-gun recordings
        MagOut = { Id = "rbxassetid://6239156710", Volume = 0.6, Pitch = 0.95 },
        MagIn = { Id = "rbxassetid://2914833164", Volume = 0.7, Pitch = 0.95 },
        SlideRelease = { Id = "rbxassetid://18919548562", Volume = 0.7, Pitch = 0.9 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 1.0 },
    },
    AK47 = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 0.85, Pitch = 0.82 }, -- placeholder until per-gun recordings
        MagOut = { Id = "rbxassetid://6239156710", Volume = 0.65, Pitch = 0.85 },
        MagIn = { Id = "rbxassetid://2914833164", Volume = 0.75, Pitch = 0.85 },
        SlideRelease = { Id = "rbxassetid://18919548562", Volume = 0.75, Pitch = 0.8 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 0.9 },
    },
    SCAR = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 0.9, Pitch = 0.78 }, -- placeholder until per-gun recordings
        MagOut = { Id = "rbxassetid://6239156710", Volume = 0.65, Pitch = 0.85 },
        MagIn = { Id = "rbxassetid://2914833164", Volume = 0.75, Pitch = 0.85 },
        SlideRelease = { Id = "rbxassetid://18919548562", Volume = 0.75, Pitch = 0.8 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 0.9 },
    },
    M4A1 = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 0.8, Pitch = 0.98 }, -- placeholder until per-gun recordings
        MagOut = { Id = "rbxassetid://6239156710", Volume = 0.65, Pitch = 0.85 },
        MagIn = { Id = "rbxassetid://2914833164", Volume = 0.75, Pitch = 0.85 },
        SlideRelease = { Id = "rbxassetid://18919548562", Volume = 0.75, Pitch = 0.8 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 0.9 },
    },
    AUG = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 0.8, Pitch = 0.94 }, -- placeholder until per-gun recordings
        MagOut = { Id = "rbxassetid://6239156710", Volume = 0.65, Pitch = 0.85 },
        MagIn = { Id = "rbxassetid://2914833164", Volume = 0.75, Pitch = 0.85 },
        SlideRelease = { Id = "rbxassetid://18919548562", Volume = 0.75, Pitch = 0.8 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 0.9 },
    },
    F2000 = {
        Fire = { Id = "rbxassetid://3603368006", Volume = 0.75, Pitch = 1.05 }, -- placeholder until per-gun recordings
        MagOut = { Id = "rbxassetid://6239156710", Volume = 0.65, Pitch = 0.85 },
        MagIn = { Id = "rbxassetid://2914833164", Volume = 0.75, Pitch = 0.85 },
        SlideRelease = { Id = "rbxassetid://18919548562", Volume = 0.75, Pitch = 0.8 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 0.9 },
    },
    Glock17 = {
        Fire = { Id = "rbxassetid://77245791056472", Volume = 0.8, Pitch = 1.0 },
        MagOut = { Id = "rbxassetid://6239156710", Volume = 0.6, Pitch = 1.0 },
        MagIn = { Id = "rbxassetid://2914833164", Volume = 0.7, Pitch = 1.0 },
        SlideBack = { Id = "rbxassetid://123026044968461", Volume = 0.6, Pitch = 1.0 },
        SlideRelease = { Id = "rbxassetid://18919548562", Volume = 0.7, Pitch = 1.0 },
        DryFire = { Id = "rbxassetid://484110242", Volume = 0.6, Pitch = 1.0 },
    },
}

-- ===== SOUND PACK v2 (tools/gun_sounds.py; do not edit by hand) =====
for name, set in pairs({
    Glock17 = { Fire = { Id = "rbxassetid://81318482854417", Volume = 0.75, Pitch = 1 }, MagOut = { Id = "rbxassetid://131996445628150", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://92324766250648", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://136561695709194", Volume = 0.80, Pitch = 1 }, SlideBack = { Id = "rbxassetid://74420709469614", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://129974781548958", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    USP = { Fire = { Id = "rbxassetid://100226990931472", Volume = 0.75, Pitch = 1 }, MagOut = { Id = "rbxassetid://131996445628150", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://92324766250648", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://136561695709194", Volume = 0.80, Pitch = 1 }, SlideBack = { Id = "rbxassetid://74420709469614", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://129974781548958", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    P226 = { Fire = { Id = "rbxassetid://123730025986983", Volume = 0.75, Pitch = 1 }, MagOut = { Id = "rbxassetid://131996445628150", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://92324766250648", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://136561695709194", Volume = 0.80, Pitch = 1 }, SlideBack = { Id = "rbxassetid://74420709469614", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://129974781548958", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    SR9 = { Fire = { Id = "rbxassetid://122669415954740", Volume = 0.75, Pitch = 1 }, MagOut = { Id = "rbxassetid://131996445628150", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://92324766250648", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://136561695709194", Volume = 0.80, Pitch = 1 }, SlideBack = { Id = "rbxassetid://74420709469614", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://129974781548958", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    PX4 = { Fire = { Id = "rbxassetid://138607398446198", Volume = 0.75, Pitch = 1 }, MagOut = { Id = "rbxassetid://131996445628150", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://92324766250648", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://136561695709194", Volume = 0.80, Pitch = 1 }, SlideBack = { Id = "rbxassetid://74420709469614", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://129974781548958", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    DEAGLE = { Fire = { Id = "rbxassetid://95487065413620", Volume = 0.90, Pitch = 1 }, MagOut = { Id = "rbxassetid://131996445628150", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://92324766250648", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://136561695709194", Volume = 0.80, Pitch = 1 }, SlideBack = { Id = "rbxassetid://74420709469614", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://129974781548958", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    TEC9 = { Fire = { Id = "rbxassetid://130995509024267", Volume = 0.70, Pitch = 1 }, MagOut = { Id = "rbxassetid://129921030134475", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://74336155372402", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    RHINO = { Fire = { Id = "rbxassetid://113542857683639", Volume = 0.90, Pitch = 1 }, CylOpen = { Id = "rbxassetid://105669774095887", Volume = 0.80, Pitch = 1 }, ShellsOut = { Id = "rbxassetid://97275178027128", Volume = 0.80, Pitch = 1 }, ShellsIn = { Id = "rbxassetid://90037227263265", Volume = 0.80, Pitch = 1 }, CylClose = { Id = "rbxassetid://108654649220551", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://129974781548958", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    UZI = { Fire = { Id = "rbxassetid://135686752182062", Volume = 0.72, Pitch = 1 }, MagOut = { Id = "rbxassetid://129921030134475", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://74336155372402", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    MP5 = { Fire = { Id = "rbxassetid://109133024068853", Volume = 0.70, Pitch = 1 }, MagOut = { Id = "rbxassetid://129921030134475", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://74336155372402", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    P90 = { Fire = { Id = "rbxassetid://121891082625623", Volume = 0.70, Pitch = 1 }, MagOut = { Id = "rbxassetid://129921030134475", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://74336155372402", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    MP7 = { Fire = { Id = "rbxassetid://124235426866392", Volume = 0.70, Pitch = 1 }, MagOut = { Id = "rbxassetid://129921030134475", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://74336155372402", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    MP40 = { Fire = { Id = "rbxassetid://96873726498024", Volume = 0.72, Pitch = 1 }, MagOut = { Id = "rbxassetid://129921030134475", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://74336155372402", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    PPSH = { Fire = { Id = "rbxassetid://107675645008709", Volume = 0.72, Pitch = 1 }, MagOut = { Id = "rbxassetid://129921030134475", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://74336155372402", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    VECTOR = { Fire = { Id = "rbxassetid://73833375959073", Volume = 0.70, Pitch = 1 }, MagOut = { Id = "rbxassetid://129921030134475", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://74336155372402", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    AK47 = { Fire = { Id = "rbxassetid://93481422536384", Volume = 0.85, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    SCAR = { Fire = { Id = "rbxassetid://108306576421412", Volume = 0.85, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    M4A1 = { Fire = { Id = "rbxassetid://92251261711594", Volume = 0.85, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    AUG = { Fire = { Id = "rbxassetid://114148494707035", Volume = 0.85, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    F2000 = { Fire = { Id = "rbxassetid://78169468655047", Volume = 0.85, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    TAR21 = { Fire = { Id = "rbxassetid://128501425890929", Volume = 0.85, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    GALIL = { Fire = { Id = "rbxassetid://136156955268414", Volume = 0.85, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    HK416 = { Fire = { Id = "rbxassetid://134855345482273", Volume = 0.85, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    M249 = { Fire = { Id = "rbxassetid://119738452020761", Volume = 0.90, Pitch = 1 }, MagOut = { Id = "rbxassetid://92508022218031", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://133147956790263", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    PKM = { Fire = { Id = "rbxassetid://73282251243848", Volume = 0.90, Pitch = 1 }, MagOut = { Id = "rbxassetid://92508022218031", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://133147956790263", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    M60 = { Fire = { Id = "rbxassetid://96224921188017", Volume = 0.90, Pitch = 1 }, MagOut = { Id = "rbxassetid://92508022218031", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://133147956790263", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    HK21 = { Fire = { Id = "rbxassetid://76504445250332", Volume = 0.90, Pitch = 1 }, MagOut = { Id = "rbxassetid://92508022218031", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://133147956790263", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    R870 = { Fire = { Id = "rbxassetid://79018643926501", Volume = 0.95, Pitch = 1 }, PumpBack = { Id = "rbxassetid://82509349096597", Volume = 0.80, Pitch = 1 }, PumpForward = { Id = "rbxassetid://80625504964349", Volume = 0.80, Pitch = 1 }, ShellIn = { Id = "rbxassetid://136469630594005", Volume = 0.80, Pitch = 1 }, BoltBack = { Id = "rbxassetid://119498880862302", Volume = 0.80, Pitch = 1 }, BoltForward = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    BM4 = { Fire = { Id = "rbxassetid://103709385223168", Volume = 0.90, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    AA12 = { Fire = { Id = "rbxassetid://121847022444578", Volume = 0.90, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    USAS12 = { Fire = { Id = "rbxassetid://70978250163474", Volume = 0.90, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    DBARREL = { Fire = { Id = "rbxassetid://123628466643429", Volume = 1.00, Pitch = 1 }, BreakOpen = { Id = "rbxassetid://101262800660047", Volume = 0.80, Pitch = 1 }, ShellsOut = { Id = "rbxassetid://97275178027128", Volume = 0.80, Pitch = 1 }, ShellIn = { Id = "rbxassetid://136469630594005", Volume = 0.80, Pitch = 1 }, BreakClose = { Id = "rbxassetid://76078673981464", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    KSG = { Fire = { Id = "rbxassetid://71054777362427", Volume = 0.95, Pitch = 1 }, PumpBack = { Id = "rbxassetid://82509349096597", Volume = 0.80, Pitch = 1 }, PumpForward = { Id = "rbxassetid://80625504964349", Volume = 0.80, Pitch = 1 }, ShellIn = { Id = "rbxassetid://136469630594005", Volume = 0.80, Pitch = 1 }, BoltBack = { Id = "rbxassetid://119498880862302", Volume = 0.80, Pitch = 1 }, BoltForward = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    M590 = { Fire = { Id = "rbxassetid://132647058515623", Volume = 0.95, Pitch = 1 }, PumpBack = { Id = "rbxassetid://82509349096597", Volume = 0.80, Pitch = 1 }, PumpForward = { Id = "rbxassetid://80625504964349", Volume = 0.80, Pitch = 1 }, ShellIn = { Id = "rbxassetid://136469630594005", Volume = 0.80, Pitch = 1 }, BoltBack = { Id = "rbxassetid://119498880862302", Volume = 0.80, Pitch = 1 }, BoltForward = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    AWP = { Fire = { Id = "rbxassetid://92976055381816", Volume = 1.00, Pitch = 1 }, BoltUp = { Id = "rbxassetid://76542765159210", Volume = 0.80, Pitch = 1 }, BoltBack = { Id = "rbxassetid://108217475943870", Volume = 0.80, Pitch = 1 }, BoltForward = { Id = "rbxassetid://109435883760557", Volume = 0.80, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    M82 = { Fire = { Id = "rbxassetid://99990191384610", Volume = 0.95, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    SCOUT = { Fire = { Id = "rbxassetid://90765411482641", Volume = 1.00, Pitch = 1 }, BoltUp = { Id = "rbxassetid://76542765159210", Volume = 0.80, Pitch = 1 }, BoltBack = { Id = "rbxassetid://108217475943870", Volume = 0.80, Pitch = 1 }, BoltForward = { Id = "rbxassetid://109435883760557", Volume = 0.80, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    M40 = { Fire = { Id = "rbxassetid://129231543615670", Volume = 1.00, Pitch = 1 }, BoltUp = { Id = "rbxassetid://76542765159210", Volume = 0.80, Pitch = 1 }, BoltBack = { Id = "rbxassetid://108217475943870", Volume = 0.80, Pitch = 1 }, BoltForward = { Id = "rbxassetid://109435883760557", Volume = 0.80, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    SVD = { Fire = { Id = "rbxassetid://128971306578526", Volume = 0.95, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    SKS = { Fire = { Id = "rbxassetid://76869357843463", Volume = 0.95, Pitch = 1 }, ShellIn = { Id = "rbxassetid://136469630594005", Volume = 0.80, Pitch = 1 }, BoltBack = { Id = "rbxassetid://119498880862302", Volume = 0.80, Pitch = 1 }, BoltForward = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    EMR = { Fire = { Id = "rbxassetid://109852928597882", Volume = 0.95, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    MK11 = { Fire = { Id = "rbxassetid://118154785619482", Volume = 0.95, Pitch = 1 }, MagOut = { Id = "rbxassetid://112273909870786", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://84107136971029", Volume = 0.80, Pitch = 1 }, SlideRelease = { Id = "rbxassetid://91700370623479", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
    BEAM = { Fire = { Id = "rbxassetid://139376522146568", Volume = 0.65, Pitch = 1 }, MagOut = { Id = "rbxassetid://92176316964380", Volume = 0.80, Pitch = 1 }, MagIn = { Id = "rbxassetid://114716356706231", Volume = 0.80, Pitch = 1 }, Equip = { Id = "rbxassetid://120174537670123", Volume = 0.55, Pitch = 1 }, DryFire = { Id = "rbxassetid://95349047497726", Volume = 0.6, Pitch = 1 } },
}) do WeaponRigs.Sounds[name] = set end
-- ===== END SOUND PACK v2 =====

-- ==================== GUNS ====================
-- Gun-space points for the Glock 17 were measured from the mesh in Blender (see art/weapons).
local GLOCK_GRIP_UP = Vector3.new(0.332, 0.943, 0)
local GLOCK_MAG_UP = Vector3.new(0.262, 0.965, 0)

local V = Vector3.new -- (short form for the GripPose tables)

WeaponRigs.Guns = {
    Glock17 = {
        Asset = "Glock17",
        Class = "Pistol",
        Scale = 1.12,          -- drawn 12% bigger than the imported mesh (the hand pose was made at this size)
        Parts = {
            Frame = { Zone = "Frame" },
            Slide = { Zone = "Slide" },
            Barrel = { Zone = "Metal" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
            -- dark inserts inside the grip, so the empty magazine well isn't see-through (skins skip "Interior")
            MagWellFill = { Zone = "Interior" },
            MagWellFill2 = { Zone = "Interior" },
        },
        Points = {
            Muzzle = Point(Vector3.new(0.332, 0.205, 0.001)),
            Eject = Point(Vector3.new(-0.011, 0.251, 0.022), Vector3.zAxis),
            -- Hand points: X = the direction the palm faces, Y = up the grip (see ViewmodelRig.MeasureHands).
            -- Right palm wraps the back strap facing forward-left; the support palm cups from the left.
            GripR = Point(Vector3.new(-0.176, -0.051, 0.001), Vector3.new(0.57, 0, -0.82), GLOCK_GRIP_UP),
            -- (support hand: further left and forward, knuckle line leaning ~35 deg forward, so it wraps
            -- around the outside of the right hand's fingers instead of through them)
            GripL = Point(Vector3.new(-0.10, -0.08, -0.15), Vector3.new(0.2, 0, 0.95), CFrame.fromAxisAngle(Vector3.zAxis, math.rad(-35)) * GLOCK_GRIP_UP),
            MagWell = Point(Vector3.new(-0.115, 0.172, 0.002), Vector3.xAxis, GLOCK_MAG_UP),
            TriggerPivot = Point(Vector3.new(-0.022, 0.130, 0.001)),
            -- Accessory mounts
            Optic = Point(Vector3.new(-0.214, 0.258, 0.001)),
            MuzzleDevice = Point(Vector3.new(0.332, 0.205, 0.001)),
            Underbarrel = Point(Vector3.new(0.232, 0.118, 0.001)),
            Charm = Point(Vector3.new(-0.235, -0.160, 0.0)),
        },
        -- Where GripR sits in camera space (as seen at WeaponRigs.ViewmodelFOV), and the gun's resting
        -- angle in degrees (pitch, yaw, roll).
        Hold = { Position = Vector3.new(0.72, -0.82, -0.791), Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0.075,   -- studs the slide moves back when cycling
        TriggerAngle = -16,    -- degrees the trigger rotates when pulled
        MagAxis = GLOCK_MAG_UP,
        MagHoldOffset = 0.13,  -- the support hand holds a loose magazine this far below its centre
        RecoilKick = { Back = 0.10, Up = 0.035, Pitch = 7, Roll = 2 },
        -- Hand-posed grip (posed by eye in art/weapons/Glock17_and_Arms.blend, thumbs-forward two-hand
        -- grip; exported as gun-space joint positions: wrist, then each finger base -> tip). Used whenever
        -- an animation isn't driving that hand; GripR/GripL + Hands shapes remain the fallback.
        GripPose = {
            R = {
                Wrist = V(-0.3708, 0.0329, 0.0898),
                Thumb = { V(-0.2637, 0.0903, 0.0042), V(-0.1648, 0.0894, -0.0779), V(-0.0674, 0.0893, -0.0867), V(0.0297, 0.0893, -0.0759) },
                Index = { V(-0.0397, 0.0143, 0.0509), V(0.0782, 0.0562, 0.0371), V(0.1280, 0.0597, -0.0310), V(0.0467, 0.0556, -0.0087) },
                Middle = { V(-0.0701, -0.0573, 0.0898), V(-0.0513, -0.0770, -0.0440), V(-0.1588, -0.0479, -0.0737), V(-0.2528, -0.0136, -0.0163) },
                Ring = { V(-0.1122, -0.1217, 0.0906), V(-0.0960, -0.1387, -0.0246), V(-0.1842, -0.1147, -0.0489), V(-0.2614, -0.0867, -0.0018) },
                Pinky = { V(-0.1742, -0.1777, 0.0733), V(-0.1625, -0.1899, -0.0098), V(-0.2262, -0.1727, -0.0273), V(-0.2818, -0.1524, 0.0066) },
            },
            L = {
                Wrist = V(-0.3165, -0.1578, -0.1784),
                Thumb = { V(-0.2796, -0.0355, -0.1024), V(-0.1726, 0.0359, -0.1016), V(-0.0761, 0.0511, -0.1015), V(0.0209, 0.0510, -0.0893) },
                Index = { V(-0.0500, 0.0354, -0.1221), V(-0.0154, 0.0603, -0.0036), V(-0.0785, 0.0418, 0.0493), V(-0.1569, 0.0134, 0.0626) },
                Middle = { V(-0.0254, -0.0446, -0.1461), V(0.0012, -0.0213, -0.0142), V(-0.0903, -0.0495, 0.0501), V(-0.1981, -0.0894, 0.0583) },
                Ring = { V(-0.0207, -0.1206, -0.1349), V(0.0023, -0.1005, -0.0214), V(-0.0728, -0.1236, 0.0313), V(-0.1613, -0.1564, 0.0380) },
                Pinky = { V(-0.0396, -0.1996, -0.1088), V(-0.0230, -0.1851, -0.0269), V(-0.0771, -0.2018, 0.0111), V(-0.1410, -0.2254, 0.0159) },
            },
        },
        Sounds = "Glock17",
        Fx = { Flash = "Pistol", Shell = "9mm" },
        Anims = nil, -- filled in below (shared pistol set)
    },
    -- ===== Rifles (TastyTony low-poly series, CC-BY). Points / GripPose / ArmsRoot / Eye are generated by
    -- art/weapons/gunprep.py (posed in art/weapons/Guns_Rifles.blend) -- regenerate rather than hand-edit.
    AK47 = {
        Asset = "AK47",
        Class = "Rifle",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
            Bolt = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.5714, 0.1689, -0.0115)),
            TriggerPivot = Point(Vector3.new(-0.4000, 0.0307, -0.0115)),
            MagWell = Point(Vector3.new(-0.0781, 0.1147, -0.0115)),
            Eject = Point(Vector3.new(0.1435, 0.2092, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.3478, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.5714, 0.1689, -0.0115)),
            Charm = Point(Vector3.new(-0.7857, -0.1043, 0.1071)),
            Underbarrel = Point(Vector3.new(0.5000, 0.0179, 0.0000)),
        },
        MagAxis = Vector3.new(-0.376, 0.927, -0.000),
        GripPose = {
            R = {
                Wrist = V(-0.7933, -0.0632, 0.0786),
                Thumb = { V(-0.6875, -0.0034, -0.0070), V(-0.5886, -0.0021, -0.0891), V(-0.4912, -0.0001, -0.0979), V(-0.3941, 0.0021, -0.0871) },
                Index = { V(-0.4618, -0.0744, 0.0396), V(-0.3449, -0.0299, 0.0259), V(-0.2952, -0.0253, -0.0422), V(-0.3764, -0.0312, -0.0199) },
                Middle = { V(-0.4906, -0.1467, 0.0786), V(-0.4714, -0.1660, -0.0553), V(-0.5795, -0.1392, -0.0849), V(-0.6743, -0.1070, -0.0275) },
                Ring = { V(-0.5313, -0.2120, 0.0794), V(-0.5147, -0.2286, -0.0359), V(-0.6035, -0.2066, -0.0602), V(-0.6813, -0.1803, -0.0130) },
                Pinky = { V(-0.5921, -0.2694, 0.0621), V(-0.5801, -0.2813, -0.0210), V(-0.6442, -0.2655, -0.0386), V(-0.7002, -0.2464, -0.0046) },
            },
            L = {
                Wrist = V(0.2893, -0.1199, -0.2377),
                Thumb = { V(0.3792, -0.0130, -0.1868), V(0.4153, 0.0740, -0.0991), V(0.4993, 0.1238, -0.0999), V(0.5832, 0.1741, -0.1000) },
                Index = { V(0.3555, 0.0421, 0.0468), V(0.3946, 0.1576, 0.0779), V(0.4498, 0.2215, 0.0768), V(0.5334, 0.2099, 0.0770) },
                Middle = { V(0.2750, 0.0088, 0.0484), V(0.3100, 0.1382, 0.0747), V(0.3762, 0.2326, 0.0774), V(0.4793, 0.1808, 0.0759) },
                Ring = { V(0.2026, 0.0045, 0.0227), V(0.2306, 0.1114, 0.0628), V(0.2783, 0.1924, 0.0737), V(0.3660, 0.2276, 0.0785) },
                Pinky = { V(0.1353, 0.0077, -0.0296), V(0.1530, 0.0739, 0.0203), V(0.1820, 0.1313, 0.0432), V(0.2293, 0.1770, 0.0614) },
            },
        },
        ArmsRoot = Vector3.new(0.0714, -0.9300, -0.2151),
        Eye = Vector3.new(-1.4358, 0.4573, -0.4651), -- camera position in gun space (posed view + framing nudge)
        ArmsShift = Vector3.new(0, -0.05, 0.3), -- shoulders back/down, out of view
        Hold = { Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0.26,   -- studs the bolt / charging handle moves when cycling
        NoBoltLock = false,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        RecoilKick = { Back = 0.09, Up = 0.02, Pitch = 1.6, Roll = 0.6 },
        Sounds = "AK47",
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        FactoryTint = Color3.new(0.45, 0.45, 0.45), -- the palette textures read too bright in game lighting
        Anims = nil, -- RifleAnims(...) below
    },
    SCAR = {
        Asset = "SCAR",
        Class = "Rifle",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
            Bolt = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.7679, 0.1130, 0.0284)),
            TriggerPivot = Point(Vector3.new(-0.4327, -0.0835, 0.0284)),
            MagWell = Point(Vector3.new(-0.1695, 0.0825, 0.0284)),
            Eject = Point(Vector3.new(0.0755, 0.0341, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.2984, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.7679, 0.1130, 0.0284)),
            Charm = Point(Vector3.new(-0.8839, -0.1410, 0.1071)),
            Underbarrel = Point(Vector3.new(0.5714, 0.0000, 0.0286)),
        },
        MagAxis = Vector3.new(-0.082, 0.997, 0.000),
        GripPose = {
            R = {
                Wrist = V(-0.8420, -0.1783, 0.1178),
                Thumb = { V(-0.7314, -0.1279, 0.0322), V(-0.6328, -0.1351, -0.0499), V(-0.5356, -0.1414, -0.0587), V(-0.4387, -0.1476, -0.0479) },
                Index = { V(-0.5128, -0.2180, 0.0789), V(-0.3924, -0.1838, 0.0651), V(-0.3425, -0.1835, -0.0030), V(-0.4239, -0.1824, 0.0193) },
                Middle = { V(-0.5477, -0.2876, 0.1178), V(-0.5302, -0.3084, -0.0160), V(-0.6356, -0.2725, -0.0457), V(-0.7272, -0.2322, 0.0117) },
                Ring = { V(-0.5938, -0.3491, 0.1186), V(-0.5788, -0.3671, 0.0034), V(-0.6652, -0.3375, -0.0209), V(-0.7405, -0.3046, 0.0262) },
                Pinky = { V(-0.6593, -0.4010, 0.1013), V(-0.6484, -0.4140, 0.0182), V(-0.7109, -0.3927, 0.0007), V(-0.7651, -0.3689, 0.0346) },
            },
            L = {
                Wrist = V(0.1929, -0.1515, -0.1664),
                Thumb = { V(0.2827, -0.0446, -0.1155), V(0.3305, 0.0704, -0.0833), V(0.4229, 0.1008, -0.0926), V(0.5048, 0.1541, -0.0911) },
                Index = { V(0.2590, 0.0105, 0.1181), V(0.2982, 0.1260, 0.1492), V(0.3533, 0.1899, 0.1481), V(0.4369, 0.1783, 0.1483) },
                Middle = { V(0.1786, -0.0228, 0.1197), V(0.2135, 0.1066, 0.1460), V(0.2798, 0.2010, 0.1487), V(0.3828, 0.1492, 0.1472) },
                Ring = { V(0.1062, -0.0271, 0.0940), V(0.1342, 0.0798, 0.1341), V(0.1818, 0.1608, 0.1450), V(0.2696, 0.1961, 0.1498) },
                Pinky = { V(0.0389, -0.0239, 0.0417), V(0.0566, 0.0423, 0.0916), V(0.0856, 0.0997, 0.1145), V(0.1328, 0.1454, 0.1327) },
            },
        },
        ArmsRoot = Vector3.new(0.0387, -1.0443, -0.1751),
        Eye = Vector3.new(-1.7185, 0.5800, -0.4252), -- camera position in gun space (raised 2026-10-02: was Y 0.373, BELOW the gun's top 0.47 -> sat too high on screen)
        ArmsShift = Vector3.new(0, -0.05, 0.4), -- shoulders back/down, out of view
        Hold = { Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0.22,   -- studs the bolt / charging handle moves when cycling
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        RecoilKick = { Back = 0.10, Up = 0.02, Pitch = 1.8, Roll = 0.6 },
        Sounds = "SCAR",
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        FactoryTint = Color3.new(0.45, 0.45, 0.45), -- the palette textures read too bright in game lighting
        Anims = nil, -- RifleAnims(...) below
    },
    M4A1 = {
        Asset = "M4A1",
        Class = "Rifle",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
            Bolt = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.5000, 0.1212, -0.0302)),
            TriggerPivot = Point(Vector3.new(-0.4036, -0.0294, -0.0302)),
            MagWell = Point(Vector3.new(-0.1774, 0.0811, -0.0302)),
            Eject = Point(Vector3.new(-0.0118, 0.0564, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.2222, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.5000, 0.1212, -0.0302)),
            Charm = Point(Vector3.new(-0.7500, -0.1045, 0.1071)),
            Underbarrel = Point(Vector3.new(0.4643, 0.0000, -0.0286)),
        },
        MagAxis = Vector3.new(-0.109, 0.994, -0.000),
        GripPose = {
            R = {
                Wrist = V(-0.7838, -0.0699, 0.0607),
                Thumb = { V(-0.6674, -0.0349, -0.0249), V(-0.5707, -0.0554, -0.1070), V(-0.4752, -0.0748, -0.1158), V(-0.3801, -0.0941, -0.1050) },
                Index = { V(-0.4630, -0.1539, 0.0218), V(-0.3391, -0.1362, 0.0080), V(-0.2896, -0.1426, -0.0601), V(-0.3701, -0.1305, -0.0378) },
                Middle = { V(-0.5070, -0.2180, 0.0607), V(-0.4925, -0.2410, -0.0731), V(-0.5921, -0.1912, -0.1028), V(-0.6774, -0.1389, -0.0454) },
                Ring = { V(-0.5610, -0.2728, 0.0615), V(-0.5485, -0.2926, -0.0537), V(-0.6302, -0.2516, -0.0780), V(-0.7003, -0.2088, -0.0309) },
                Pinky = { V(-0.6329, -0.3153, 0.0442), V(-0.6239, -0.3296, -0.0389), V(-0.6829, -0.3001, -0.0564), V(-0.7334, -0.2692, -0.0225) },
            },
            L = {
                Wrist = V(0.2108, -0.1315, -0.1949),
                Thumb = { V(0.3006, -0.0246, -0.1440), V(0.3466, 0.0862, -0.1903), V(0.4376, 0.1201, -0.1788), V(0.5203, 0.1722, -0.1802) },
                Index = { V(0.2769, 0.0304, 0.0895), V(0.3161, 0.1460, 0.1206), V(0.3712, 0.2099, 0.1195), V(0.4548, 0.1982, 0.1197) },
                Middle = { V(0.1965, -0.0028, 0.0911), V(0.2314, 0.1266, 0.1174), V(0.2977, 0.2209, 0.1201), V(0.4007, 0.1691, 0.1186) },
                Ring = { V(0.1241, -0.0071, 0.0654), V(0.1521, 0.0998, 0.1055), V(0.1997, 0.1808, 0.1164), V(0.2875, 0.2160, 0.1212) },
                Pinky = { V(0.0567, -0.0040, 0.0131), V(0.0745, 0.0623, 0.0630), V(0.1035, 0.1197, 0.0859), V(0.1507, 0.1654, 0.1041) },
            },
        },
        ArmsRoot = Vector3.new(0.0678, -0.9901, -0.2337),
        Eye = Vector3.new(-1.6394, 0.4172, -0.4838), -- camera position in gun space (posed view + framing nudge)
        ArmsShift = Vector3.new(0, -0.05, 0.35), -- shoulders back/down, out of view
        Hold = { Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0.0,   -- studs the bolt / charging handle moves when cycling
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        RecoilKick = { Back = 0.07, Up = 0.015, Pitch = 1.2, Roll = 0.4 },
        Sounds = "M4A1",
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        FactoryTint = Color3.new(0.45, 0.45, 0.45), -- the palette textures read too bright in game lighting
        Anims = nil, -- RifleAnims(...) below
    },
    AUG = {
        Asset = "AUG",
        Class = "Rifle",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
            Bolt = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.4107, 0.0976, 0.0260)),
            TriggerPivot = Point(Vector3.new(-0.0163, -0.0263, 0.0285)),
            MagWell = Point(Vector3.new(-0.6760, 0.0255, 0.0260)),
            Eject = Point(Vector3.new(-0.1209, -0.0030, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.4286, 0.0250)),
            MuzzleDevice = Point(Vector3.new(1.4107, 0.0976, 0.0260)),
            Charm = Point(Vector3.new(-0.7054, -0.1278, 0.1071)),
            Underbarrel = Point(Vector3.new(0.7143, -0.0714, 0.0250)),
        },
        MagAxis = Vector3.new(-0.162, 0.987, -0.000),
        GripPose = {
            R = {
                Wrist = V(-0.3741, -0.0997, 0.1178),
                Thumb = { V(-0.2636, -0.0493, 0.0322), V(-0.1650, -0.0565, -0.0499), V(-0.0678, -0.0629, -0.0587), V(0.0291, -0.0691, -0.0479) },
                Index = { V(-0.0449, -0.1395, 0.0789), V(0.0754, -0.1052, 0.0651), V(0.1253, -0.1049, -0.0030), V(0.0439, -0.1038, 0.0193) },
                Middle = { V(-0.0798, -0.2090, 0.1178), V(-0.0623, -0.2298, -0.0160), V(-0.1678, -0.1939, -0.0457), V(-0.2594, -0.1537, 0.0117) },
                Ring = { V(-0.1260, -0.2706, 0.1186), V(-0.1109, -0.2886, 0.0034), V(-0.1974, -0.2590, -0.0209), V(-0.2726, -0.2261, 0.0262) },
                Pinky = { V(-0.1914, -0.3225, 0.1013), V(-0.1805, -0.3354, 0.0182), V(-0.2430, -0.3141, 0.0007), V(-0.2972, -0.2903, 0.0346) },
            },
            L = {
                Wrist = V(0.1860, -0.1855, -0.0749),
                Thumb = { V(0.2847, -0.1077, 0.0044), V(0.3954, -0.1386, 0.0621), V(0.4863, -0.1519, 0.0957), V(0.5832, -0.1636, 0.1015) },
                Index = { V(0.5168, -0.1543, -0.0416), V(0.5271, -0.1596, 0.0837), V(0.4439, -0.1473, 0.0911), V(0.3851, -0.1367, 0.0314) },
                Middle = { V(0.4965, -0.2321, -0.0749), V(0.5077, -0.2378, 0.0610), V(0.3940, -0.2211, 0.0711), V(0.3137, -0.2066, -0.0104) },
                Ring = { V(0.4640, -0.3017, -0.0705), V(0.4736, -0.3066, 0.0465), V(0.3803, -0.2929, 0.0547), V(0.3144, -0.2810, -0.0122) },
                Pinky = { V(0.4107, -0.3645, -0.0482), V(0.4177, -0.3681, 0.0362), V(0.3504, -0.3582, 0.0421), V(0.3029, -0.3496, -0.0061) },
            },
        },
        ArmsRoot = Vector3.new(0.4551, -0.9870, -0.1751),
        Eye = Vector3.new(-1.2020, 0.7088, -0.7287), -- camera position in gun space (posed view + framing nudge)
        ArmsShift = Vector3.new(0, 0, 0.5), -- shoulders back/down, out of view
        Hold = { Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0.2,   -- studs the bolt / charging handle moves when cycling
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        RecoilKick = { Back = 0.07, Up = 0.015, Pitch = 1.2, Roll = 0.4 },
        Sounds = "AUG",
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        FactoryTint = Color3.new(0.45, 0.45, 0.45), -- the palette textures read too bright in game lighting
        Anims = nil, -- RifleAnims(...) below
    },
    F2000 = {
        Asset = "F2000",
        Class = "Rifle",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.2321, 0.1575, 0.0150)),
            TriggerPivot = Point(Vector3.new(0.1986, -0.0066, 0.0150)),
            MagWell = Point(Vector3.new(-0.4259, 0.0728, 0.0154)),
            Optic = Point(Vector3.new(-0.0000, 0.3955, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.2321, 0.1575, 0.0150)),
            Charm = Point(Vector3.new(-0.6161, -0.1395, 0.1071)),
            Underbarrel = Point(Vector3.new(0.5357, -0.1429, 0.0250)),
            Eject = Point(Vector3.new(0.3571, 0.1250, 0.1071), Vector3.new(0.300, 0.000, 1.000)),
        },
        MagAxis = Vector3.new(-0.035, 0.999, -0.000),
        GripPose = {
            R = {
                Wrist = V(-0.1039, -0.0653, 0.1036),
                Thumb = { V(0.0160, -0.0455, 0.0180), V(0.1093, -0.0782, -0.0641), V(0.2015, -0.1097, -0.0730), V(0.2934, -0.1410, -0.0621) },
                Index = { V(0.2036, -0.1896, 0.0646), V(0.3287, -0.1879, 0.0508), V(0.3769, -0.2007, -0.0173), V(0.2987, -0.1784, 0.0051) },
                Middle = { V(0.1517, -0.2476, 0.1036), V(0.1632, -0.2723, -0.0302), V(0.0708, -0.2101, -0.0600), V(-0.0072, -0.1474, -0.0025) },
                Ring = { V(0.0911, -0.2950, 0.1043), V(0.1010, -0.3163, -0.0109), V(0.0252, -0.2652, -0.0352), V(-0.0389, -0.2138, 0.0119) },
                Pinky = { V(0.0144, -0.3280, 0.0871), V(0.0215, -0.3434, 0.0040), V(-0.0332, -0.3066, -0.0136), V(-0.0793, -0.2694, 0.0204) },
            },
            L = {
                Wrist = V(0.4965, -0.2399, -0.1735),
                Thumb = { V(0.5863, -0.1330, -0.1226), V(0.6353, -0.0152, -0.1067), V(0.7289, 0.0126, -0.1118), V(0.8101, 0.0670, -0.1108) },
                Index = { V(0.5626, -0.0780, 0.1110), V(0.6018, 0.0375, 0.1421), V(0.6569, 0.1015, 0.1410), V(0.7405, 0.0898, 0.1412) },
                Middle = { V(0.4822, -0.1112, 0.1125), V(0.5171, 0.0181, 0.1389), V(0.5834, 0.1125, 0.1415), V(0.6864, 0.0607, 0.1401) },
                Ring = { V(0.4098, -0.1155, 0.0869), V(0.4378, -0.0087, 0.1269), V(0.4854, 0.0724, 0.1379), V(0.5732, 0.1076, 0.1426) },
                Pinky = { V(0.3424, -0.1124, 0.0346), V(0.3602, -0.0462, 0.0844), V(0.3892, 0.0112, 0.1073), V(0.4364, 0.0569, 0.1255) },
            },
        },
        ArmsRoot = Vector3.new(0.4143, -1.0214, -0.1885),
        Eye = Vector3.new(-1.3714, 0.6000, -0.5457), -- camera position in gun space (posed view + framing nudge)
        ArmsShift = Vector3.new(0, 0, 0.5), -- shoulders back/down, out of view
        Hold = { Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0.0,   -- studs the bolt / charging handle moves when cycling
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        RecoilKick = { Back = 0.06, Up = 0.012, Pitch = 1.0, Roll = 0.3 },
        Sounds = "F2000",
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        FactoryTint = Color3.new(0.45, 0.45, 0.45), -- the palette textures read too bright in game lighting
        Anims = nil, -- RifleAnims(...) below
    },
    -- ===== SMGs (TastyTony, CC-BY): generated by art/weapons/gunprep.py
    UZI = {
        Asset = "UZI",
        Class = "SMG",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(0.8183, 0.1251, 0.0000)),
            TriggerPivot = Point(Vector3.new(-0.0754, 0.0239, -0.0000)),
            MagWell = Point(Vector3.new(0.0591, 0.1846, -0.0000)),
            Optic = Point(Vector3.new(-0.0000, 0.2461, 0.0000)),
            MuzzleDevice = Point(Vector3.new(0.8183, 0.1251, 0.0000)),
            Charm = Point(Vector3.new(-0.3804, -0.0971, 0.1071)),
        },
        MagAxis = Vector3.new(-0.006, 1.000, -0.000),
        GripPose = {
            R = {
                Wrist = V(-0.4299, -0.1837, 0.1000),
                Thumb = { V(-0.3498, -0.0924, 0.0144), V(-0.2568, -0.0585, -0.0678), V(-0.1656, -0.0244, -0.0765), V(-0.0746, 0.0097, -0.0657) },
                Index = { V(-0.1133, -0.0848, 0.0611), V(-0.0176, -0.0042, 0.0473), V(0.0277, 0.0165, -0.0209), V(-0.0470, -0.0159, 0.0015) },
                Middle = { V(-0.1166, -0.1626, 0.1000), V(-0.0922, -0.1745, -0.0339), V(-0.2031, -0.1850, -0.0635), V(-0.3031, -0.1859, -0.0061) },
                Ring = { V(-0.1335, -0.2377, 0.1008), V(-0.1124, -0.2480, -0.0144), V(-0.2034, -0.2565, -0.0387), V(-0.2855, -0.2574, 0.0084) },
                Pinky = { V(-0.1719, -0.3119, 0.0835), V(-0.1567, -0.3193, 0.0004), V(-0.2223, -0.3255, -0.0171), V(-0.2815, -0.3260, 0.0168) },
            },
            L = {
                Wrist = V(-0.3121, -0.3433, -0.1682),
                Thumb = { V(-0.3205, -0.2158, -0.0923), V(-0.2454, -0.1114, -0.0914), V(-0.1603, -0.0632, -0.0913), V(-0.0695, -0.0293, -0.0791) },
                Index = { V(-0.1304, -0.0688, -0.1120), V(-0.1068, -0.0334, 0.0065), V(-0.1594, -0.0728, 0.0595), V(-0.2228, -0.1269, 0.0728) },
                Middle = { V(-0.0793, -0.1351, -0.1359), V(-0.0626, -0.1039, -0.0040), V(-0.1384, -0.1624, 0.0603), V(-0.2254, -0.2377, 0.0685) },
                Ring = { V(-0.0482, -0.2045, -0.1248), V(-0.0338, -0.1777, -0.0113), V(-0.0960, -0.2257, 0.0415), V(-0.1673, -0.2875, 0.0482) },
                Pinky = { V(-0.0381, -0.2852, -0.0987), V(-0.0277, -0.2658, -0.0168), V(-0.0725, -0.3004, 0.0213), V(-0.1241, -0.3449, 0.0261) },
            },
        },
        Eye = Vector3.new(-1.3300, 0.5400, -0.5200), -- camera position in gun space (2026-10-02: Y 0.44 -> 0.54, still sat too high; was -1.5299, 0.2663)
        Hold = { Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.15,
        RecoilKick = { Back = 0.06, Up = 0.015, Pitch = 1.4, Roll = 0.5 },
        Sounds = "UZI",
        Fx = { Flash = "Rifle", Shell = "9mm" },
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        Anims = nil, -- RifleAnims(...) below
    },
    MP5 = {
        Asset = "MP5",
        Class = "SMG",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.2143, 0.1647, 0.0067)),
            TriggerPivot = Point(Vector3.new(0.0044, -0.0442, 0.0067)),
            MagWell = Point(Vector3.new(0.2882, 0.1378, 0.0067)),
            Optic = Point(Vector3.new(-0.0000, 0.3847, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.2143, 0.1647, 0.0067)),
            Charm = Point(Vector3.new(-0.6071, -0.1180, 0.1071)),
            Underbarrel = Point(Vector3.new(0.7143, 0.0000, 0.0000)),
        },
        MagAxis = Vector3.new(-0.264, 0.964, 0.000),
        GripPose = {
            R = {
                Wrist = V(-0.4035, -0.1591, 0.1067),
                Thumb = { V(-0.2948, -0.1050, 0.0211), V(-0.1958, -0.1089, -0.0610), V(-0.0985, -0.1120, -0.0698), V(-0.0014, -0.1149, -0.0590) },
                Index = { V(-0.0731, -0.1876, 0.0678), V(0.0461, -0.1494, 0.0540), V(0.0959, -0.1474, -0.0141), V(0.0145, -0.1491, 0.0082) },
                Middle = { V(-0.1057, -0.2583, 0.1067), V(-0.0874, -0.2787, -0.0271), V(-0.1941, -0.2463, -0.0568), V(-0.2870, -0.2092, 0.0006) },
                Ring = { V(-0.1497, -0.3214, 0.1075), V(-0.1340, -0.3390, -0.0077), V(-0.2215, -0.3123, -0.0320), V(-0.2977, -0.2821, 0.0151) },
                Pinky = { V(-0.2133, -0.3755, 0.0902), V(-0.2020, -0.3882, 0.0071), V(-0.2651, -0.3691, -0.0104), V(-0.3201, -0.3471, 0.0235) },
            },
            L = {
                Wrist = V(0.6215, -0.0570, -0.2035),
                Thumb = { V(0.7113, 0.0499, -0.1526), V(0.7538, 0.1522, -0.0873), V(0.8421, 0.1926, -0.0980), V(0.9257, 0.2432, -0.0976) },
                Index = { V(0.6876, 0.1049, 0.0810), V(0.7267, 0.2204, 0.1121), V(0.7819, 0.2844, 0.1110), V(0.8655, 0.2727, 0.1112) },
                Middle = { V(0.6072, 0.0717, 0.0825), V(0.6421, 0.2010, 0.1089), V(0.7083, 0.2954, 0.1116), V(0.8114, 0.2437, 0.1101) },
                Ring = { V(0.5347, 0.0674, 0.0569), V(0.5627, 0.1742, 0.0970), V(0.6104, 0.2553, 0.1079), V(0.6981, 0.2905, 0.1127) },
                Pinky = { V(0.4674, 0.0705, 0.0046), V(0.4851, 0.1367, 0.0545), V(0.5141, 0.1941, 0.0773), V(0.5614, 0.2398, 0.0956) },
            },
        },
        ArmsRoot = Vector3.new(0.4758, -1.0049, -0.2143),
        Eye = Vector3.new(-1.1835, 0.5000, -0.4533), -- camera position in gun space (lowered 2026-10-01; was Y 0.3409)
        ArmsShift = Vector3.new(0, -0.05, 0.3), -- shoulders back/down, out of view
        Hold = { Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.15,
        RecoilKick = { Back = 0.06, Up = 0.012, Pitch = 1.0, Roll = 0.4 },
        Sounds = "MP5",
        Fx = { Flash = "Rifle", Shell = "9mm" },
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        Anims = nil, -- RifleAnims(...) below
    },
    P90 = {
        Asset = "P90",
        Class = "SMG",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(0.8929, 0.1441, -0.0000)),
            TriggerPivot = Point(Vector3.new(0.2774, 0.0092, 0.0000)),
            MagWell = Point(Vector3.new(-0.0423, 0.3716, -0.0000)),
            Optic = Point(Vector3.new(0.2857, 0.5457, 0.0000)),
            MuzzleDevice = Point(Vector3.new(0.8929, 0.1441, -0.0000)),
            Charm = Point(Vector3.new(-0.4464, -0.1637, 0.1071)),
        },
        MagAxis = Vector3.new(0.764, 0.645, -0.000),
        GripPose = {
            R = {
                Wrist = V(-0.2033, -0.0032, 0.1000),
                Thumb = { V(-0.0908, 0.0427, 0.0144), V(0.0075, 0.0314, -0.0678), V(0.1043, 0.0211, -0.0765), V(0.2010, 0.0109, -0.0657) },
                Index = { V(0.1241, -0.0563, 0.0611), V(0.2457, -0.0271, 0.0473), V(0.2956, -0.0288, -0.0208), V(0.2143, -0.0244, 0.0015) },
                Middle = { V(0.0863, -0.1244, 0.1000), V(0.1030, -0.1460, -0.0338), V(-0.0010, -0.1058, -0.0635), V(-0.0908, -0.0618, -0.0061) },
                Ring = { V(0.0377, -0.1840, 0.1008), V(0.0520, -0.2027, -0.0144), V(-0.0332, -0.1696, -0.0387), V(-0.1070, -0.1336, 0.0084) },
                Pinky = { V(-0.0298, -0.2332, 0.0835), V(-0.0195, -0.2466, 0.0004), V(-0.0810, -0.2229, -0.0171), V(-0.1342, -0.1969, 0.0168) },
            },
            L = {
                Wrist = V(0.3181, -0.0361, -0.1000),
                Thumb = { V(0.4168, 0.0417, -0.0206), V(0.5275, 0.0109, 0.0371), V(0.6184, -0.0024, 0.0706), V(0.7153, -0.0142, 0.0765) },
                Index = { V(0.6489, -0.0049, -0.0667), V(0.6592, -0.0102, 0.0587), V(0.5760, 0.0021, 0.0660), V(0.5172, 0.0127, 0.0064) },
                Middle = { V(0.6286, -0.0826, -0.1000), V(0.6397, -0.0884, 0.0360), V(0.5261, -0.0717, 0.0460), V(0.4458, -0.0572, -0.0355) },
                Ring = { V(0.5961, -0.1522, -0.0956), V(0.6057, -0.1572, 0.0214), V(0.5124, -0.1435, 0.0297), V(0.4465, -0.1316, -0.0372) },
                Pinky = { V(0.5428, -0.2151, -0.0733), V(0.5498, -0.2187, 0.0111), V(0.4825, -0.2088, 0.0171), V(0.4350, -0.2002, -0.0312) },
            },
        },
        ArmsRoot = Vector3.new(0.7488, -0.9515, -0.2143),
        Eye = Vector3.new(-1.0533, 0.5768, -0.5200), -- camera position in gun space (framed like the rifles)
        ArmsShift = Vector3.new(0, -0.05, 0.3), -- shoulders back/down, out of view
        Hold = { Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.15,
        RecoilKick = { Back = 0.05, Up = 0.01, Pitch = 0.9, Roll = 0.3 },
        Sounds = "P90",
        Fx = { Flash = "Rifle", Shell = "9mm" },
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        Anims = nil, -- RifleAnims(...) below
    },
    MP7 = {
        Asset = "MP7",
        Class = "SMG",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(0.6561, 0.0609, -0.0028)),
            TriggerPivot = Point(Vector3.new(-0.0636, 0.0109, -0.0028)),
            MagWell = Point(Vector3.new(-0.2208, 0.0373, -0.0028)),
            Optic = Point(Vector3.new(-0.0000, 0.2295, 0.0000)),
            MuzzleDevice = Point(Vector3.new(0.6561, 0.0609, -0.0028)),
            Charm = Point(Vector3.new(-0.3280, -0.1020, 0.1071)),
        },
        MagAxis = Vector3.new(-0.108, 0.994, -0.000),
        GripPose = {
            R = {
                Wrist = V(-0.4010, -0.0675, 0.0972),
                Thumb = { V(-0.3063, 0.0086, 0.0116), V(-0.2088, 0.0260, -0.0705), V(-0.1131, 0.0438, -0.0793), V(-0.0177, 0.0618, -0.0685) },
                Index = { V(-0.0721, -0.0247, 0.0583), V(0.0361, 0.0382, 0.0445), V(0.0844, 0.0508, -0.0236), V(0.0052, 0.0318, -0.0013) },
                Middle = { V(-0.0888, -0.1007, 0.0972), V(-0.0667, -0.1167, -0.0366), V(-0.1778, -0.1079, -0.0663), V(-0.2764, -0.0915, -0.0089) },
                Ring = { V(-0.1182, -0.1718, 0.0980), V(-0.0992, -0.1855, -0.0172), V(-0.1904, -0.1782, -0.0415), V(-0.2714, -0.1649, 0.0056) },
                Pinky = { V(-0.1689, -0.2383, 0.0807), V(-0.1551, -0.2481, -0.0024), V(-0.2209, -0.2430, -0.0199), V(-0.2793, -0.2333, 0.0140) },
            },
            L = {
                Wrist = V(-0.0155, -0.0784, -0.1000),
                Thumb = { V(0.0832, -0.0006, -0.0206), V(0.1940, -0.0314, 0.0371), V(0.2848, -0.0447, 0.0706), V(0.3817, -0.0565, 0.0765) },
                Index = { V(0.3153, -0.0472, -0.0667), V(0.3256, -0.0525, 0.0587), V(0.2424, -0.0402, 0.0660), V(0.1836, -0.0296, 0.0064) },
                Middle = { V(0.2950, -0.1250, -0.1000), V(0.3062, -0.1307, 0.0360), V(0.1925, -0.1140, 0.0460), V(0.1122, -0.0995, -0.0355) },
                Ring = { V(0.2625, -0.1946, -0.0956), V(0.2721, -0.1995, 0.0214), V(0.1788, -0.1858, 0.0297), V(0.1130, -0.1739, -0.0372) },
                Pinky = { V(0.2093, -0.2574, -0.0733), V(0.2162, -0.2610, 0.0111), V(0.1490, -0.2511, 0.0171), V(0.1014, -0.2425, -0.0312) },
            },
        },
        ArmsRoot = Vector3.new(0.4078, -0.9498, -0.2143),
        Eye = Vector3.new(-1.2510, 0.4525, -0.4828), -- camera position in gun space (framed like the rifles)
        ArmsShift = Vector3.new(0, -0.15, 0.45), -- shoulders back/down, out of view (2026-10-02: was 0, -0.05, 0.25 -- the folded support arm filled the bottom of the screen)
        Hold = { Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.15,
        RecoilKick = { Back = 0.05, Up = 0.012, Pitch = 1.0, Roll = 0.4 },
        Sounds = "MP7",
        Fx = { Flash = "Rifle", Shell = "9mm" },
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        Anims = nil, -- RifleAnims(...) below
    },
    -- Weapon overhaul shotguns + snipers (TastyTony low-poly models, CC-BY; posed in art/weapons/Guns_Long.blend)
    R870 = {
        Asset = "R870",
        Class = "Shotgun",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Pump = { Zone = "Furniture" },
            Bolt = { Zone = "Metal" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.3393, 0.2215, -0.0034)),
            TriggerPivot = Point(Vector3.new(-0.9878, 0.0969, -0.0034)),
            Eject = Point(Vector3.new(-0.5454, 0.2277, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.2900, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.3393, 0.2215, -0.0034)),
            Charm = Point(Vector3.new(-0.6696, -0.0926, 0.1071)),
            LoadPort = Point(Vector3.new(-0.62, -0.06, 0.0)),
        },
        GripPose = {
            R = { -- AK-47's right hand, moved onto this gun's trigger
                Wrist = V(-1.3811, 0.0030, 0.0867),
                Thumb = { V(-1.2753, 0.0628, 0.0011), V(-1.1764, 0.0641, -0.0810), V(-1.0790, 0.0661, -0.0898), V(-0.9819, 0.0683, -0.0790) },
                Index = { V(-1.0496, -0.0082, 0.0477), V(-0.9327, 0.0363, 0.0340), V(-0.8830, 0.0409, -0.0341), V(-0.9642, 0.0350, -0.0118) },
                Middle = { V(-1.0784, -0.0805, 0.0867), V(-1.0592, -0.0998, -0.0472), V(-1.1673, -0.0730, -0.0768), V(-1.2621, -0.0408, -0.0194) },
                Ring = { V(-1.1191, -0.1458, 0.0875), V(-1.1025, -0.1624, -0.0278), V(-1.1913, -0.1404, -0.0521), V(-1.2691, -0.1141, -0.0049) },
                Pinky = { V(-1.1799, -0.2032, 0.0702), V(-1.1679, -0.2151, -0.0129), V(-1.2320, -0.1993, -0.0305), V(-1.2880, -0.1802, 0.0035) },
            },
            L = { -- support hand on the pump (AK pose moved +0.13 up / +0.03 in, 2026-10-02: it sat under/beside the pump)
                Wrist = V(0.1049, 0.0129, -0.1844),
                Thumb = { V(0.1947, 0.1198, -0.1336), V(0.2348, 0.2299, -0.0805), V(0.3223, 0.2731, -0.0862), V(0.4193, 0.2851, -0.0862) },
                Index = { V(0.1710, 0.1749, 0.1000), V(0.2104, 0.2872, 0.1410), V(0.2945, 0.2801, 0.1384), V(0.3757, 0.3017, 0.1463) },
                Middle = { V(0.0906, 0.1416, 0.1016), V(0.1248, 0.2693, 0.1358), V(0.2366, 0.2968, 0.1432), V(0.1638, 0.2105, 0.1200) },
                Ring = { V(0.0182, 0.1373, 0.0759), V(0.0454, 0.2421, 0.1216), V(0.1224, 0.2926, 0.1437), V(0.2117, 0.2639, 0.1312) },
                Pinky = { V(-0.0492, 0.1404, 0.0236), V(-0.0320, 0.2049, 0.0760), V(0.0078, 0.2478, 0.1109), V(0.0667, 0.2746, 0.1327) },
            },
        },
        ArmsRoot = Vector3.new(-0.1130, -0.8638, -0.2070), -- AK's shoulder placement relative to the grip (+0.40 forward: the pump is far out)
        Eye = Vector3.new(-1.9500, 0.6314, -0.4977), -- camera in gun space (2026-10-02: X -2.297 -> -1.95, the rig sat too far away: thin arms, hand off the pump)
        ArmsShift = Vector3.new(0, -0.45, 0.3), -- shoulders back and well down (2026-10-02: Y -0.35 -> -0.45; -0.6 put the pump out of reach)
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Pump",
        PumpTravel = 0.29,
        SlideTravel = 0.29,
        NoBoltLock = true,
        TriggerAngle = -16,
        RecoilKick = { Back = 0.16, Up = 0.03, Pitch = 5.0, Roll = 1.2 },
        Sounds = "R870",
        Fx = { Flash = "Shotgun", Shell = "12ga" },
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        Anims = nil, -- built below from AnimKind
    },
    BM4 = {
        Asset = "BM4",
        Class = "Shotgun",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Bolt = { Zone = "Metal" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.6964, 0.2264, -0.0040)),
            TriggerPivot = Point(Vector3.new(-0.5145, 0.0978, -0.0040)),
            Eject = Point(Vector3.new(-0.0536, 0.2747, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.4001, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.6964, 0.2264, -0.0040)),
            Charm = Point(Vector3.new(-0.8482, -0.1371, 0.1071)),
            LoadPort = Point(Vector3.new(-0.18, -0.08, 0.0)),
        },
        GripPose = {
            R = { -- AK-47's right hand, moved onto this gun's trigger
                Wrist = V(-0.9078, 0.0039, 0.0861),
                Thumb = { V(-0.8020, 0.0637, 0.0005), V(-0.7031, 0.0650, -0.0816), V(-0.6057, 0.0670, -0.0904), V(-0.5086, 0.0692, -0.0796) },
                Index = { V(-0.5763, -0.0073, 0.0471), V(-0.4594, 0.0372, 0.0334), V(-0.4097, 0.0418, -0.0347), V(-0.4909, 0.0359, -0.0124) },
                Middle = { V(-0.6051, -0.0796, 0.0861), V(-0.5859, -0.0989, -0.0478), V(-0.6940, -0.0721, -0.0774), V(-0.7888, -0.0399, -0.0200) },
                Ring = { V(-0.6458, -0.1449, 0.0869), V(-0.6292, -0.1615, -0.0284), V(-0.7180, -0.1395, -0.0527), V(-0.7958, -0.1132, -0.0055) },
                Pinky = { V(-0.7066, -0.2023, 0.0696), V(-0.6946, -0.2142, -0.0135), V(-0.7587, -0.1984, -0.0311), V(-0.8147, -0.1793, 0.0029) },
            },
            L = { -- support hand flat under the handguard at the AK's spacing from the grip
                Wrist = V(0.1026, -0.1027, -0.2465),
                Thumb = { V(0.1924, 0.0042, -0.1956), V(0.2227, 0.0772, -0.0941), V(0.3019, 0.1327, -0.0794), V(0.3850, 0.1841, -0.0765) },
                Index = { V(0.1687, 0.0592, 0.0380), V(0.2079, 0.1748, 0.0691), V(0.2805, 0.2177, 0.0676), V(0.3533, 0.1749, 0.0691) },
                Middle = { V(0.0883, 0.0260, 0.0395), V(0.1232, 0.1554, 0.0658), V(0.2089, 0.2325, 0.0693), V(0.2594, 0.1289, 0.0646) },
                Ring = { V(0.0159, 0.0217, 0.0139), V(0.0439, 0.1286, 0.0539), V(0.1028, 0.2014, 0.0675), V(0.1972, 0.2077, 0.0686) },
                Pinky = { V(-0.0515, 0.0249, -0.0384), V(-0.0337, 0.0911, 0.0114), V(-0.0001, 0.1442, 0.0380), V(0.0528, 0.1827, 0.0572) },
            },
        },
        ArmsRoot = Vector3.new(-0.0431, -0.8629, -0.2076), -- AK's shoulder placement relative to the grip
        Eye = Vector3.new(-1.7537, 0.6324, -0.4983), -- camera in gun space (wrist + framing; ~0.1 above the gun/scope top)
        ArmsShift = Vector3.new(0, -0.05, 0.3), -- shoulders back/down, out of view (same as the rifles)
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "TubeSemi",
        SlideTravel = 0.21,
        NoBoltLock = true,
        TriggerAngle = -16,
        RecoilKick = { Back = 0.13, Up = 0.025, Pitch = 4.0, Roll = 1.0 },
        Sounds = "BM4",
        Fx = { Flash = "Shotgun", Shell = "12ga" },
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        Anims = nil, -- built below from AnimKind
    },
    AA12 = {
        Asset = "AA12",
        Class = "Shotgun",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Bolt = { Zone = "Metal" },
            Trigger = { Zone = "Metal" },
        },
        -- (2026-10-29: the AA-12 by DU1701 replaced the ripped Saiga-12 model; points measured off its meshes in
        -- art/weapons/AA12_DU1701.blend -- bore y 0.066, the box magazine's top centre, the right-side ejection port;
        -- Bolt = the top charging handle, it rides back on the reload)
        Points = {
            Muzzle = Point(Vector3.new(1.9660, 0.0660, 0.0000)),
            TriggerPivot = Point(Vector3.new(-0.2850, -0.0700, 0.0000)),
            MagWell = Point(Vector3.new(0.0610, 0.0220, 0.0000)),
            Eject = Point(Vector3.new(0.0400, 0.1000, 0.0750), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.3600, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.9660, 0.0660, 0.0000)),
            Charm = Point(Vector3.new(-0.8700, -0.0800, 0.0750)),
        },
        MagAxis = Vector3.new(-0.058, 0.998, -0.002),
        GripPose = {
            R = { -- AK-47's right hand, moved onto this gun's trigger
                Wrist = V(-0.6783, -0.1764, 0.0897),
                Thumb = { V(-0.5725, -0.1166, 0.0041), V(-0.4736, -0.1153, -0.0780), V(-0.3762, -0.1133, -0.0868), V(-0.2791, -0.1111, -0.0760) },
                Index = { V(-0.3468, -0.1876, 0.0507), V(-0.2299, -0.1431, 0.0370), V(-0.1802, -0.1385, -0.0311), V(-0.2614, -0.1444, -0.0088) },
                Middle = { V(-0.3756, -0.2599, 0.0897), V(-0.3564, -0.2792, -0.0442), V(-0.4645, -0.2524, -0.0738), V(-0.5593, -0.2202, -0.0164) },
                Ring = { V(-0.4163, -0.3252, 0.0905), V(-0.3997, -0.3418, -0.0248), V(-0.4885, -0.3198, -0.0491), V(-0.5663, -0.2935, -0.0019) },
                Pinky = { V(-0.4771, -0.3826, 0.0732), V(-0.4651, -0.3945, -0.0099), V(-0.5292, -0.3787, -0.0275), V(-0.5852, -0.3596, 0.0065) },
            },
            L = { -- support hand flat under the handguard at the AK's spacing from the grip
                Wrist = V(0.3320, -0.1560, -0.2066),
                Thumb = { V(0.4219, -0.0492, -0.1557), V(0.4659, 0.0570, -0.0980), V(0.5554, 0.0945, -0.1097), V(0.6387, 0.1457, -0.1088) },
                Index = { V(0.3982, 0.0059, 0.0779), V(0.4373, 0.1214, 0.1090), V(0.5100, 0.1644, 0.1075), V(0.5827, 0.1216, 0.1090) },
                Middle = { V(0.3177, -0.0273, 0.0795), V(0.3527, 0.1020, 0.1058), V(0.4383, 0.1792, 0.1093), V(0.4889, 0.0756, 0.1046) },
                Ring = { V(0.2453, -0.0316, 0.0538), V(0.2733, 0.0752, 0.0939), V(0.3323, 0.1480, 0.1074), V(0.4267, 0.1543, 0.1086) },
                Pinky = { V(0.1780, -0.0285, 0.0015), V(0.1957, 0.0377, 0.0514), V(0.2293, 0.0909, 0.0779), V(0.2823, 0.1294, 0.0971) },
            },
        },
        ArmsRoot = Vector3.new(0.1864, -1.0432, -0.2040), -- AK's shoulder placement relative to the grip
        Eye = Vector3.new(-1.5242, 0.7450, -0.4948), -- camera in gun space (wrist + framing; ~0.1 above the gun/scope top)
        ArmsShift = Vector3.new(0, -0.05, 0.3), -- shoulders back/down, out of view (same as the rifles)
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0.18,
        NoBoltLock = true,
        TriggerAngle = -16,
        MagHoldOffset = 0.2,
        MagPull = 1.0,
        RecoilKick = { Back = 0.09, Up = 0.02, Pitch = 2.4, Roll = 0.8 },
        Sounds = "AA12",
        Fx = { Flash = "Shotgun", Shell = "12ga" },
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        Anims = nil, -- built below from AnimKind
    },
    AWP = {
        Asset = "AWP",
        Class = "Sniper",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Bolt = { Zone = "Metal" },
            Trigger = { Zone = "Metal" },
            Scope = { Zone = "Optic" },
        },
        Points = {
            Muzzle = Point(Vector3.new(2.1071, 0.2119, -0.0000)),
            TriggerPivot = Point(Vector3.new(-0.8147, 0.0290, -0.0000)),
            MagWell = Point(Vector3.new(-0.5246, 0.1778, -0.0000)),
            Eject = Point(Vector3.new(-0.6355, 0.1530, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.2937, 0.0000)),
            MuzzleDevice = Point(Vector3.new(2.1071, 0.2119, -0.0000)),
            Charm = Point(Vector3.new(-1.0536, -0.0881, 0.1071)),
            BoltKnob = Point(Vector3.new(-0.7883, 0.0974, 0.1242)),
            BoltAxis = Point(Vector3.new(0, 0.2218, 0)),
        },
        MagAxis = Vector3.new(-0.068, 0.998, -0.000),
        GripPose = {
            R = { -- AK-47's right hand, moved onto this gun's trigger
                Wrist = V(-1.2080, -0.0649, 0.0901),
                Thumb = { V(-1.1022, -0.0051, 0.0045), V(-1.0033, -0.0038, -0.0776), V(-0.9059, -0.0018, -0.0864), V(-0.8088, 0.0004, -0.0756) },
                Index = { V(-0.8765, -0.0761, 0.0511), V(-0.7596, -0.0316, 0.0374), V(-0.7099, -0.0270, -0.0307), V(-0.7911, -0.0329, -0.0084) },
                Middle = { V(-0.9053, -0.1484, 0.0901), V(-0.8861, -0.1677, -0.0438), V(-0.9942, -0.1409, -0.0734), V(-1.0890, -0.1087, -0.0160) },
                Ring = { V(-0.9460, -0.2137, 0.0909), V(-0.9294, -0.2303, -0.0244), V(-1.0182, -0.2083, -0.0487), V(-1.0960, -0.1820, -0.0015) },
                Pinky = { V(-1.0068, -0.2711, 0.0736), V(-0.9948, -0.2830, -0.0095), V(-1.0589, -0.2672, -0.0271), V(-1.1149, -0.2481, 0.0069) },
            },
            L = { -- support hand flat under the handguard at the AK's spacing from the grip
                Wrist = V(-0.1976, -0.1597, -0.2263),
                Thumb = { V(-0.1078, -0.0528, -0.1754), V(-0.0718, 0.0340, -0.0875), V(0.0123, 0.0839, -0.0882), V(0.0961, 0.1342, -0.0883) },
                Index = { V(-0.1315, 0.0023, 0.0582), V(-0.0924, 0.1178, 0.0893), V(-0.0197, 0.1608, 0.0878), V(0.0531, 0.1179, 0.0893) },
                Middle = { V(-0.2119, -0.0310, 0.0598), V(-0.1770, 0.0984, 0.0861), V(-0.0914, 0.1756, 0.0895), V(-0.0408, 0.0720, 0.0849) },
                Ring = { V(-0.2844, -0.0353, 0.0341), V(-0.2564, 0.0716, 0.0742), V(-0.1974, 0.1444, 0.0877), V(-0.1030, 0.1507, 0.0889) },
                Pinky = { V(-0.3517, -0.0321, -0.0182), V(-0.3339, 0.0341, 0.0317), V(-0.3003, 0.0872, 0.0582), V(-0.2474, 0.1258, 0.0774) },
            },
        },
        ArmsRoot = Vector3.new(-0.3433, -0.9317, -0.2036), -- AK's shoulder placement relative to the grip
        Eye = Vector3.new(-2.0540, 0.6530, -0.4943), -- camera in gun space (wrist + framing; ~0.1 above the gun/scope top)
        ArmsShift = Vector3.new(0, -0.05, 0.3), -- shoulders back/down, out of view (same as the rifles)
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "BoltAction",
        SlideTravel = 0.36,
        BoltLift = -62,
        NoBoltLock = true,
        TriggerAngle = -14,
        MagHoldOffset = 0.12,
        RecoilKick = { Back = 0.2, Up = 0.04, Pitch = 6.5, Roll = 1.0 },
        Sounds = "AWP",
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        Anims = nil, -- built below from AnimKind
    },
    M82 = {
        Asset = "M82",
        Class = "Sniper",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Bolt = { Zone = "Metal" },
            Trigger = { Zone = "Metal" },
            Scope = { Zone = "Optic" },
        },
        Points = {
            Muzzle = Point(Vector3.new(2.5893, 0.2073, 0.0000)),
            TriggerPivot = Point(Vector3.new(-1.2004, -0.0214, -0.0000)),
            MagWell = Point(Vector3.new(-0.8659, 0.1471, -0.0000)),
            Eject = Point(Vector3.new(-0.5506, 0.2142, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.3425, 0.0000)),
            MuzzleDevice = Point(Vector3.new(2.5893, 0.2073, 0.0000)),
            Charm = Point(Vector3.new(-1.2946, -0.1159, 0.1071)),
        },
        MagAxis = Vector3.new(-0.165, 0.986, -0.000),
        GripPose = {
            R = { -- AK-47's right hand, moved onto this gun's trigger
                Wrist = V(-1.5937, -0.1153, 0.0901),
                Thumb = { V(-1.4879, -0.0555, 0.0045), V(-1.3890, -0.0542, -0.0776), V(-1.2916, -0.0522, -0.0864), V(-1.1945, -0.0500, -0.0756) },
                Index = { V(-1.2622, -0.1265, 0.0511), V(-1.1453, -0.0820, 0.0374), V(-1.0956, -0.0774, -0.0307), V(-1.1768, -0.0833, -0.0084) },
                Middle = { V(-1.2910, -0.1988, 0.0901), V(-1.2718, -0.2181, -0.0438), V(-1.3799, -0.1913, -0.0734), V(-1.4747, -0.1591, -0.0160) },
                Ring = { V(-1.3317, -0.2641, 0.0909), V(-1.3151, -0.2807, -0.0244), V(-1.4039, -0.2587, -0.0487), V(-1.4817, -0.2324, -0.0015) },
                Pinky = { V(-1.3925, -0.3215, 0.0736), V(-1.3805, -0.3334, -0.0095), V(-1.4446, -0.3176, -0.0271), V(-1.5006, -0.2985, 0.0069) },
            },
            L = { -- support hand flat under the handguard at the AK's spacing from the grip
                Wrist = V(-0.5834, -0.1786, -0.2115),
                Thumb = { V(-0.4935, -0.0717, -0.1606), V(-0.4516, 0.0294, -0.0931), V(-0.3635, 0.0706, -0.1034), V(-0.2798, 0.1211, -0.1031) },
                Index = { V(-0.5172, -0.0167, 0.0730), V(-0.4781, 0.0988, 0.1041), V(-0.4054, 0.1418, 0.1026), V(-0.3327, 0.0990, 0.1041) },
                Middle = { V(-0.5977, -0.0499, 0.0746), V(-0.5627, 0.0795, 0.1009), V(-0.4771, 0.1566, 0.1044), V(-0.4265, 0.0531, 0.0997) },
                Ring = { V(-0.6701, -0.0542, 0.0489), V(-0.6421, 0.0527, 0.0890), V(-0.5831, 0.1255, 0.1025), V(-0.4887, 0.1318, 0.1037) },
                Pinky = { V(-0.7374, -0.0511, -0.0034), V(-0.7197, 0.0152, 0.0465), V(-0.6861, 0.0683, 0.0730), V(-0.6331, 0.1068, 0.0922) },
            },
        },
        ArmsRoot = Vector3.new(-0.7290, -0.9821, -0.2036), -- AK's shoulder placement relative to the grip
        Eye = Vector3.new(-2.4397, 0.8850, -0.4943), -- camera in gun space (wrist + framing; ~0.1 above the gun/scope top)
        ArmsShift = Vector3.new(0, -0.05, 0.3), -- shoulders back/down, out of view (same as the rifles)
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0.21,
        NoBoltLock = true,
        TriggerAngle = -14,
        MagHoldOffset = 0.18,
        RecoilKick = { Back = 0.22, Up = 0.05, Pitch = 7.0, Roll = 1.2 },
        Sounds = "M82",
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        Anims = nil, -- built below from AnimKind
    },
    SCOUT = {
        Asset = "SCOUT",
        Class = "Sniper",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Bolt = { Zone = "Metal" },
            Trigger = { Zone = "Metal" },
            Scope = { Zone = "Optic" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.7857, 0.2156, -0.0000)),
            TriggerPivot = Point(Vector3.new(-0.5895, 0.0302, 0.0000)),
            MagWell = Point(Vector3.new(-0.2595, 0.1698, -0.0012)),
            Eject = Point(Vector3.new(-0.3768, 0.1357, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.2834, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.7857, 0.2156, -0.0000)),
            Charm = Point(Vector3.new(-0.8929, -0.0850, 0.1071)),
            BoltKnob = Point(Vector3.new(-0.6145, 0.0545, 0.1166)),
            BoltAxis = Point(Vector3.new(0, 0.2243, 0)),
        },
        MagAxis = Vector3.new(0.165, 0.986, -0.024),
        GripPose = {
            R = { -- AK-47's right hand, moved onto this gun's trigger
                Wrist = V(-0.9828, -0.0637, 0.0901),
                Thumb = { V(-0.8770, -0.0039, 0.0045), V(-0.7781, -0.0026, -0.0776), V(-0.6807, -0.0006, -0.0864), V(-0.5836, 0.0016, -0.0756) },
                Index = { V(-0.6513, -0.0749, 0.0511), V(-0.5344, -0.0304, 0.0374), V(-0.4847, -0.0258, -0.0307), V(-0.5659, -0.0317, -0.0084) },
                Middle = { V(-0.6801, -0.1472, 0.0901), V(-0.6609, -0.1665, -0.0438), V(-0.7690, -0.1397, -0.0734), V(-0.8638, -0.1075, -0.0160) },
                Ring = { V(-0.7208, -0.2125, 0.0909), V(-0.7042, -0.2291, -0.0244), V(-0.7930, -0.2071, -0.0487), V(-0.8708, -0.1808, -0.0015) },
                Pinky = { V(-0.7816, -0.2699, 0.0736), V(-0.7696, -0.2818, -0.0095), V(-0.8337, -0.2660, -0.0271), V(-0.8897, -0.2469, 0.0069) },
            },
            L = { -- support hand flat under the handguard at the AK's spacing from the grip
                Wrist = V(0.0275, -0.1264, -0.2132),
                Thumb = { V(0.1174, -0.0196, -0.1623), V(0.1586, 0.0798, -0.0919), V(0.2462, 0.1222, -0.1015), V(0.3300, 0.1726, -0.1013) },
                Index = { V(0.0937, 0.0355, 0.0713), V(0.1328, 0.1510, 0.1024), V(0.2055, 0.1940, 0.1009), V(0.2782, 0.1512, 0.1024) },
                Middle = { V(0.0132, 0.0023, 0.0728), V(0.0482, 0.1316, 0.0991), V(0.1338, 0.2088, 0.1026), V(0.1844, 0.1052, 0.0979) },
                Ring = { V(-0.0592, -0.0020, 0.0472), V(-0.0312, 0.1048, 0.0872), V(0.0278, 0.1776, 0.1007), V(0.1222, 0.1839, 0.1019) },
                Pinky = { V(-0.1265, 0.0011, -0.0052), V(-0.1088, 0.0673, 0.0447), V(-0.0752, 0.1205, 0.0712), V(-0.0222, 0.1590, 0.0905) },
            },
        },
        ArmsRoot = Vector3.new(-0.1181, -0.9305, -0.2036), -- AK's shoulder placement relative to the grip
        Eye = Vector3.new(-1.8288, 0.6010, -0.4943), -- camera in gun space (wrist + framing; ~0.1 above the gun/scope top)
        ArmsShift = Vector3.new(0, -0.05, 0.3), -- shoulders back/down, out of view (same as the rifles)
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "BoltAction",
        SlideTravel = 0.29,
        BoltLift = -62,
        NoBoltLock = true,
        TriggerAngle = -14,
        MagHoldOffset = 0.1,
        RecoilKick = { Back = 0.16, Up = 0.035, Pitch = 5.0, Roll = 0.9 },
        Sounds = "SCOUT",
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        Anims = nil, -- built below from AnimKind
    },
    -- Weapon overhaul pistols (TastyTony low-poly models, CC-BY; Glock two-hand grip fitted in art/weapons/Guns_Long.blend)
    DEAGLE = {
        Asset = "DEAGLE",
        Class = "Pistol",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Slide = { Zone = "Slide" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(0.4821, 0.2166, 0.0000)),
            TriggerPivot = Point(Vector3.new(-0.1092, 0.0861, 0.0000)),
            MagWell = Point(Vector3.new(-0.2571, -0.0225, 0.0000)),
            Eject = Point(Vector3.new(-0.0078, 0.1498, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.2488, 0.0000)),
            MuzzleDevice = Point(Vector3.new(0.4821, 0.2166, 0.0000)),
            Charm = Point(Vector3.new(-0.2411, -0.0794, 0.1071)),
        },
        MagAxis = Vector3.new(0.017, 1.000, -0.000),
        GripPose = {
            R = {
                Wrist = V(-0.4427, -0.0746, 0.0999),
                Thumb = { V(-0.3500, 0.0040, 0.0143), V(-0.2530, 0.0237, -0.0678), V(-0.1577, 0.0440, -0.0765), V(-0.0627, 0.0644, -0.0657) },
                Index = { V(-0.1150, -0.0233, 0.0610), V(-0.0084, 0.0422, 0.0473), V(0.0395, 0.0560, -0.0209), V(-0.0391, 0.0350, 0.0015) },
                Middle = { V(-0.1297, -0.0998, 0.0999), V(-0.1072, -0.1152, -0.0339), V(-0.2185, -0.1093, -0.0635), V(-0.3175, -0.0955, -0.0061) },
                Ring = { V(-0.1574, -0.1715, 0.1007), V(-0.1380, -0.1849, -0.0144), V(-0.2293, -0.1799, -0.0387), V(-0.3106, -0.1687, 0.0084) },
                Pinky = { V(-0.2063, -0.2393, 0.0834), V(-0.1923, -0.2489, 0.0004), V(-0.2581, -0.2455, -0.0171), V(-0.3168, -0.2373, 0.0168) },
            },
            L = {
                Wrist = V(-0.3496, -0.2498, -0.1682),
                Thumb = { V(-0.3391, -0.1225, -0.0923), V(-0.2495, -0.0303, -0.0914), V(-0.1582, 0.0049, -0.0913), V(-0.0634, 0.0251, -0.0791) },
                Index = { V(-0.1294, -0.0050, -0.1120), V(-0.1009, 0.0265, 0.0065), V(-0.1587, -0.0048, 0.0595), V(-0.2294, -0.0490, 0.0728) },
                Middle = { V(-0.0887, -0.0781, -0.1359), V(-0.0675, -0.0498, -0.0040), V(-0.1511, -0.0965, 0.0603), V(-0.2482, -0.1582, 0.0685) },
                Ring = { V(-0.0681, -0.1514, -0.1248), V(-0.0499, -0.1270, -0.0113), V(-0.1185, -0.1653, 0.0415), V(-0.1981, -0.2159, 0.0482) },
                Pinky = { V(-0.0700, -0.2326, -0.0987), V(-0.0569, -0.2150, -0.0168), V(-0.1063, -0.2427, 0.0213), V(-0.1638, -0.2791, 0.0261) },
            },
        },
        Eye = Vector3.new(-0.9952, 0.3576, -0.4809),
        Hold = { Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0.1,
        TriggerAngle = -16,
        MagPull = 0.34,
        MagHoldOffset = 0.06,
        RecoilKick = { Back = 0.16, Up = 0.05, Pitch = 11, Roll = 2.5 },
        Sounds = "DEAGLE",
        Fx = { Flash = "Pistol", Shell = "Rifle" },
        Anims = nil, -- PistolAnimsFor(...) below
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
    },
    TEC9 = {
        Asset = "TEC9",
        Class = "Pistol",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Bolt = { Zone = "Metal" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(0.5714, 0.1938, 0.0000)),
            TriggerPivot = Point(Vector3.new(-0.1942, 0.0764, 0.0000)),
            MagWell = Point(Vector3.new(0.0229, 0.1838, 0.0000)),
            Eject = Point(Vector3.new(0.0284, 0.2319, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.2759, 0.0000)),
            MuzzleDevice = Point(Vector3.new(0.5714, 0.1938, 0.0000)),
            Charm = Point(Vector3.new(-0.2857, -0.0883, 0.1071)),
        },
        MagAxis = Vector3.new(-0.021, 1.000, -0.000),
        GripPose = {
            R = {
                Wrist = V(-0.5875, -0.0278, 0.1000),
                Thumb = { V(-0.4799, 0.0286, 0.0144), V(-0.3810, 0.0268, -0.0678), V(-0.2836, 0.0258, -0.0765), V(-0.1865, 0.0250, -0.0657) },
                Index = { V(-0.2565, -0.0493, 0.0611), V(-0.1383, -0.0085, 0.0473), V(-0.0885, -0.0055, -0.0209), V(-0.1698, -0.0089, 0.0015) },
                Middle = { V(-0.2876, -0.1207, 0.1000), V(-0.2690, -0.1406, -0.0338), V(-0.3763, -0.1105, -0.0635), V(-0.4699, -0.0754, -0.0061) },
                Ring = { V(-0.3303, -0.1847, 0.1008), V(-0.3143, -0.2019, -0.0144), V(-0.4023, -0.1771, -0.0387), V(-0.4792, -0.1484, 0.0084) },
                Pinky = { V(-0.3928, -0.2402, 0.0835), V(-0.3812, -0.2525, 0.0004), V(-0.4447, -0.2347, -0.0171), V(-0.5002, -0.2139, 0.0168) },
            },
            L = {
                Wrist = V(-0.5349, -0.2189, -0.1682),
                Thumb = { V(-0.4970, -0.0970, -0.0922), V(-0.3893, -0.0266, -0.0914), V(-0.2926, -0.0123, -0.0913), V(-0.1956, -0.0132, -0.0791) },
                Index = { V(-0.2667, -0.0281, -0.1119), V(-0.2319, -0.0036, 0.0066), V(-0.2952, -0.0216, 0.0595), V(-0.3738, -0.0493, 0.0728) },
                Middle = { V(-0.2429, -0.1083, -0.1359), V(-0.2160, -0.0853, -0.0040), V(-0.3078, -0.1127, 0.0603), V(-0.4160, -0.1517, 0.0685) },
                Ring = { V(-0.2388, -0.1844, -0.1247), V(-0.2156, -0.1646, -0.0112), V(-0.2909, -0.1870, 0.0415), V(-0.3797, -0.2190, 0.0482) },
                Pinky = { V(-0.2584, -0.2632, -0.0986), V(-0.2417, -0.2489, -0.0167), V(-0.2960, -0.2652, 0.0213), V(-0.3600, -0.2882, 0.0261) },
            },
        },
        Eye = Vector3.new(-1.0324, 0.5147, -0.4809),
        Hold = { Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0.2,
        NoBoltLock = true,
        TriggerAngle = -16,
        MagPull = 0.75,
        MagHoldOffset = 0.2,
        RecoilKick = { Back = 0.06, Up = 0.02, Pitch = 3, Roll = 1.2 },
        Sounds = "TEC9",
        Fx = { Flash = "Pistol", Shell = "9mm" },
        Anims = nil, -- PistolAnimsFor(...) below
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
    },
    RHINO = {
        Asset = "RHINO",
        Class = "Pistol",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Cylinder = { Zone = "Slide" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(0.4399, 0.0807, 0.0011)),
            TriggerPivot = Point(Vector3.new(-0.1194, 0.0263, 0.0011)),
            Optic = Point(Vector3.new(-0.0000, 0.2139, 0.0000)),
            MuzzleDevice = Point(Vector3.new(0.4399, 0.0807, 0.0011)),
            Charm = Point(Vector3.new(-0.2199, -0.0691, 0.1071)),
            CylAxis = Point(Vector3.new(-0.1240, 0.1080, 0.0010)), -- (GUN MODELS v2: the new cylinder's centre)
            Crane = Point(Vector3.new(-0.1240, 0.0491, -0.0519)),
        },
        GripPose = {
            R = {
                Wrist = V(-0.5575, -0.0642, 0.1011),
                Thumb = { V(-0.4516, -0.0046, 0.0155), V(-0.3527, -0.0035, -0.0667), V(-0.2553, -0.0015, -0.0754), V(-0.1582, 0.0005, -0.0646) },
                Index = { V(-0.2260, -0.0758, 0.0622), V(-0.1090, -0.0315, 0.0484), V(-0.0593, -0.0270, -0.0198), V(-0.1406, -0.0328, 0.0026) },
                Middle = { V(-0.2550, -0.1481, 0.1011), V(-0.2358, -0.1674, -0.0328), V(-0.3439, -0.1406, -0.0624), V(-0.4386, -0.1083, -0.0050) },
                Ring = { V(-0.2957, -0.2134, 0.1019), V(-0.2792, -0.2301, -0.0133), V(-0.3679, -0.2079, -0.0376), V(-0.4456, -0.1815, 0.0095) },
                Pinky = { V(-0.3566, -0.2707, 0.0846), V(-0.3446, -0.2826, 0.0015), V(-0.4086, -0.2668, -0.0160), V(-0.4647, -0.2476, 0.0179) },
            },
            L = {
                Wrist = V(-0.4993, -0.2537, -0.1671),
                Thumb = { V(-0.4649, -0.1306, -0.0911), V(-0.3594, -0.0571, -0.0903), V(-0.2632, -0.0399, -0.0902), V(-0.1662, -0.0380, -0.0780) },
                Index = { V(-0.2368, -0.0550, -0.1108), V(-0.2028, -0.0294, 0.0076), V(-0.2655, -0.0492, 0.0606), V(-0.3433, -0.0793, 0.0739) },
                Middle = { V(-0.2106, -0.1344, -0.1348), V(-0.1844, -0.1106, -0.0029), V(-0.2754, -0.1408, 0.0614), V(-0.3824, -0.1829, 0.0696) },
                Ring = { V(-0.2043, -0.2103, -0.1236), V(-0.1817, -0.1898, -0.0101), V(-0.2563, -0.2145, 0.0426), V(-0.3441, -0.2491, 0.0493) },
                Pinky = { V(-0.2215, -0.2897, -0.0975), V(-0.2052, -0.2749, -0.0156), V(-0.2590, -0.2928, 0.0224), V(-0.3224, -0.3177, 0.0272) },
            },
        },
        Eye = Vector3.new(-1.0184, 0.4648, -0.4798),
        Hold = { Angles = Vector3.new(0, -5, 0) },
        Revolver = true, -- cylinder turns 60 deg per shot; reload swings it out (CylSwing deg about Points.Crane)
        CylSwing = -90,
        NoBoltLock = true,
        TriggerAngle = -20,
        RecoilKick = { Back = 0.14, Up = 0.05, Pitch = 10, Roll = 2 },
        Sounds = "RHINO",
        Fx = { Flash = "Pistol" },
        Anims = nil, -- RevolverAnims(...) below
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
    },
}

-- ===== NEW GUNS (tools/new_guns.py; do not edit by hand) =====
for id, def in pairs({
    M249 = {
        Asset = "M249",
        Class = "Rifle",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.8571, 0.1283, -0.0220)),
            TriggerPivot = Point(Vector3.new(-0.4522, -0.0974, -0.0220)),
            MagWell = Point(Vector3.new(-0.1437, -0.0013, -0.0096)),
            Optic = Point(Vector3.new(-0.0000, 0.4807, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.8571, 0.1283, -0.0220)),
            Charm = Point(Vector3.new(-0.9286, -0.1442, 0.1071)),
        },
        MagAxis = Vector3.new(0.000, 1.000, 0.000),
        GripPose = {
            R = {
                Wrist = V(-0.8455, -0.1913, 0.0681),
                Thumb = { V(-0.7397, -0.1315, -0.0175), V(-0.6408, -0.1302, -0.0996), V(-0.5434, -0.1282, -0.1084), V(-0.4463, -0.1260, -0.0976) },
                Index = { V(-0.5140, -0.2025, 0.0291), V(-0.3971, -0.1580, 0.0154), V(-0.3474, -0.1534, -0.0527), V(-0.4286, -0.1593, -0.0304) },
                Middle = { V(-0.5428, -0.2748, 0.0681), V(-0.5236, -0.2941, -0.0658), V(-0.6317, -0.2673, -0.0954), V(-0.7265, -0.2351, -0.0380) },
                Ring = { V(-0.5835, -0.3401, 0.0689), V(-0.5669, -0.3567, -0.0464), V(-0.6557, -0.3347, -0.0707), V(-0.7335, -0.3084, -0.0235) },
                Pinky = { V(-0.6443, -0.3975, 0.0516), V(-0.6323, -0.4094, -0.0315), V(-0.6964, -0.3936, -0.0491), V(-0.7524, -0.3745, -0.0151) },
            },
            L = {
                Wrist = V(0.4343, -0.2977, -0.2482),
                Thumb = { V(0.5242, -0.1908, -0.1973), V(0.5603, -0.1038, -0.1096), V(0.6443, -0.0540, -0.1104), V(0.7282, -0.0037, -0.1105) },
                Index = { V(0.5005, -0.1357, 0.0363), V(0.5396, -0.0202, 0.0674), V(0.5948, 0.0437, 0.0663), V(0.6784, 0.0321, 0.0665) },
                Middle = { V(0.4200, -0.1690, 0.0379), V(0.4550, -0.0396, 0.0642), V(0.5212, 0.0548, 0.0669), V(0.6243, 0.0030, 0.0654) },
                Ring = { V(0.3476, -0.1733, 0.0122), V(0.3756, -0.0664, 0.0523), V(0.4233, 0.0146, 0.0632), V(0.5110, 0.0498, 0.0680) },
                Pinky = { V(0.2803, -0.1701, -0.0401), V(0.2980, -0.1039, 0.0098), V(0.3270, -0.0465, 0.0327), V(0.3743, -0.0008, 0.0509) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0.2,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        MagPull = 0.9,
        RecoilKick = { Back = 0.1, Up = 0.02, Pitch = 1.3, Roll = 0.6 },
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        Sounds = "M249",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    PKM = {
        Asset = "PKM",
        Class = "Rifle",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(2.1250, 0.1685, 0.0657)),
            TriggerPivot = Point(Vector3.new(-0.6885, -0.0251, 0.0657)),
            MagWell = Point(Vector3.new(-0.1410, 0.0521, 0.0289)),
            Optic = Point(Vector3.new(-0.0000, 0.3966, 0.0000)),
            MuzzleDevice = Point(Vector3.new(2.1250, 0.1685, 0.0657)),
            Charm = Point(Vector3.new(-1.0625, -0.1334, 0.1071)),
        },
        MagAxis = Vector3.new(0.000, 1.000, 0.000),
        GripPose = {
            R = {
                Wrist = V(-1.0818, -0.1190, 0.1558),
                Thumb = { V(-0.9760, -0.0592, 0.0702), V(-0.8771, -0.0579, -0.0119), V(-0.7797, -0.0559, -0.0207), V(-0.6826, -0.0537, -0.0099) },
                Index = { V(-0.7503, -0.1302, 0.1168), V(-0.6334, -0.0857, 0.1031), V(-0.5837, -0.0811, 0.0350), V(-0.6649, -0.0870, 0.0573) },
                Middle = { V(-0.7791, -0.2025, 0.1558), V(-0.7599, -0.2218, 0.0219), V(-0.8680, -0.1950, -0.0077), V(-0.9628, -0.1628, 0.0497) },
                Ring = { V(-0.8198, -0.2678, 0.1566), V(-0.8032, -0.2844, 0.0413), V(-0.8920, -0.2624, 0.0170), V(-0.9698, -0.2361, 0.0642) },
                Pinky = { V(-0.8806, -0.3252, 0.1393), V(-0.8686, -0.3371, 0.0562), V(-0.9327, -0.3213, 0.0386), V(-0.9887, -0.3022, 0.0726) },
            },
            L = {
                Wrist = V(0.6143, -0.1337, -0.1605),
                Thumb = { V(0.7042, -0.0268, -0.1096), V(0.7403, 0.0602, -0.0219), V(0.8243, 0.1100, -0.0227), V(0.9082, 0.1603, -0.0228) },
                Index = { V(0.6805, 0.0283, 0.1240), V(0.7196, 0.1438, 0.1551), V(0.7748, 0.2077, 0.1540), V(0.8584, 0.1961, 0.1542) },
                Middle = { V(0.6000, -0.0050, 0.1256), V(0.6350, 0.1244, 0.1519), V(0.7012, 0.2188, 0.1546), V(0.8043, 0.1670, 0.1531) },
                Ring = { V(0.5276, -0.0093, 0.0999), V(0.5556, 0.0976, 0.1400), V(0.6033, 0.1786, 0.1509), V(0.6910, 0.2138, 0.1557) },
                Pinky = { V(0.4603, -0.0061, 0.0476), V(0.4780, 0.0601, 0.0975), V(0.5070, 0.1175, 0.1204), V(0.5543, 0.1632, 0.1386) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0.2,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        MagPull = 0.9,
        RecoilKick = { Back = 0.11, Up = 0.02, Pitch = 1.5, Roll = 0.6 },
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        Sounds = "PKM",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    M60 = {
        Asset = "M60",
        Class = "Rifle",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.9643, 0.0522, 0.2996)),
            TriggerPivot = Point(Vector3.new(-0.6922, -0.1115, 0.2996)),
            MagWell = Point(Vector3.new(-0.6319, -0.0753, -0.5271)), -- (0.70: the ammo box moved to the belt's end, see below)
            Optic = Point(Vector3.new(-0.0000, 0.1662, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.9643, 0.0522, 0.2996)),
            Charm = Point(Vector3.new(-0.9821, -0.1064, 0.1071)),
        },
        MagAxis = Vector3.new(0.000, 0.000, 1.000),
        GripPose = {
            R = {
                Wrist = V(-1.0855, -0.2054, 0.3897),
                Thumb = { V(-0.9797, -0.1456, 0.3041), V(-0.8808, -0.1443, 0.2220), V(-0.7834, -0.1423, 0.2132), V(-0.6863, -0.1401, 0.2240) },
                Index = { V(-0.7540, -0.2166, 0.3507), V(-0.6371, -0.1721, 0.3370), V(-0.5874, -0.1675, 0.2689), V(-0.6686, -0.1734, 0.2912) },
                Middle = { V(-0.7828, -0.2889, 0.3897), V(-0.7636, -0.3082, 0.2558), V(-0.8717, -0.2814, 0.2262), V(-0.9665, -0.2492, 0.2836) },
                Ring = { V(-0.8235, -0.3542, 0.3905), V(-0.8069, -0.3708, 0.2752), V(-0.8957, -0.3488, 0.2509), V(-0.9735, -0.3225, 0.2981) },
                Pinky = { V(-0.8843, -0.4116, 0.3732), V(-0.8723, -0.4235, 0.2901), V(-0.9364, -0.4077, 0.2725), V(-0.9924, -0.3886, 0.3065) },
            },
            L = {
                Wrist = V(0.8643, -0.2227, 0.0734),
                Thumb = { V(0.9542, -0.1158, 0.1243), V(0.9903, -0.0288, 0.2120), V(1.0743, 0.0210, 0.2112), V(1.1582, 0.0713, 0.2111) },
                Index = { V(0.9305, -0.0607, 0.3579), V(0.9696, 0.0548, 0.3890), V(1.0248, 0.1187, 0.3879), V(1.1084, 0.1071, 0.3881) },
                Middle = { V(0.8500, -0.0940, 0.3595), V(0.8850, 0.0354, 0.3858), V(0.9512, 0.1298, 0.3885), V(1.0543, 0.0780, 0.3870) },
                Ring = { V(0.7776, -0.0983, 0.3338), V(0.8056, 0.0086, 0.3739), V(0.8533, 0.0896, 0.3848), V(0.9410, 0.1248, 0.3896) },
                Pinky = { V(0.7103, -0.0951, 0.2815), V(0.7280, -0.0289, 0.3314), V(0.7570, 0.0285, 0.3543), V(0.8043, 0.0742, 0.3725) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0.2,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        MagPull = 0.9,
        RecoilKick = { Back = 0.11, Up = 0.02, Pitch = 1.5, Roll = 0.6 },
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        Sounds = "M60",
        -- (0.70, owner: "m60 mag is bugged on the side, and its way too dark under certain lighting"): its texture is far
        -- darker than the other guns' (0.45 read pure black in the night hub; 1.0 washes out in bright rooms). The ammo box
        -- (WeaponAssets.M60.Magazine) was moved 0.42 left / 0.03 down so the frame's belt feeds into its top instead of
        -- sticking out past it into the air.
        FactoryTint = Color3.new(0.75, 0.75, 0.75),
        NewGun = true,
    },
    HK21 = {
        Asset = "HK21",
        Class = "Rifle",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.8214, 0.1662, 0.0011)),
            TriggerPivot = Point(Vector3.new(-0.4633, -0.0432, 0.0011)),
            MagWell = Point(Vector3.new(-0.0815, -0.0526, 0.0000)),
            Optic = Point(Vector3.new(-0.0000, 0.2791, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.8214, 0.1662, 0.0011)),
            Charm = Point(Vector3.new(-0.9107, -0.1152, 0.1071)),
        },
        MagAxis = Vector3.new(0.000, 1.000, 0.000),
        GripPose = {
            R = {
                Wrist = V(-0.8566, -0.1371, 0.0912),
                Thumb = { V(-0.7508, -0.0773, 0.0056), V(-0.6519, -0.0760, -0.0765), V(-0.5545, -0.0740, -0.0853), V(-0.4574, -0.0718, -0.0745) },
                Index = { V(-0.5251, -0.1483, 0.0522), V(-0.4082, -0.1038, 0.0385), V(-0.3585, -0.0992, -0.0296), V(-0.4397, -0.1051, -0.0073) },
                Middle = { V(-0.5539, -0.2206, 0.0912), V(-0.5347, -0.2399, -0.0427), V(-0.6428, -0.2131, -0.0723), V(-0.7376, -0.1809, -0.0149) },
                Ring = { V(-0.5946, -0.2859, 0.0920), V(-0.5780, -0.3025, -0.0233), V(-0.6668, -0.2805, -0.0476), V(-0.7446, -0.2542, -0.0004) },
                Pinky = { V(-0.6554, -0.3433, 0.0747), V(-0.6434, -0.3552, -0.0084), V(-0.7075, -0.3394, -0.0260), V(-0.7635, -0.3203, 0.0080) },
            },
            L = {
                Wrist = V(0.5643, -0.0577, -0.2251),
                Thumb = { V(0.6542, 0.0492, -0.1742), V(0.6903, 0.1362, -0.0865), V(0.7743, 0.1860, -0.0873), V(0.8582, 0.2363, -0.0874) },
                Index = { V(0.6305, 0.1043, 0.0594), V(0.6696, 0.2198, 0.0905), V(0.7248, 0.2837, 0.0894), V(0.8084, 0.2721, 0.0896) },
                Middle = { V(0.5500, 0.0710, 0.0610), V(0.5850, 0.2004, 0.0873), V(0.6512, 0.2948, 0.0900), V(0.7543, 0.2430, 0.0885) },
                Ring = { V(0.4776, 0.0667, 0.0353), V(0.5056, 0.1736, 0.0754), V(0.5533, 0.2546, 0.0863), V(0.6410, 0.2898, 0.0911) },
                Pinky = { V(0.4103, 0.0699, -0.0170), V(0.4280, 0.1361, 0.0329), V(0.4570, 0.1935, 0.0558), V(0.5043, 0.2392, 0.0740) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0.2,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        MagPull = 0.9,
        RecoilKick = { Back = 0.1, Up = 0.02, Pitch = 1.4, Roll = 0.6 },
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        Sounds = "HK21",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    TAR21 = {
        Asset = "TAR21",
        Class = "Rifle",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.2857, 0.1093, 0.0395)),
            TriggerPivot = Point(Vector3.new(0.2178, 0.0027, 0.0395)),
            MagWell = Point(Vector3.new(-0.5714, 0.0820, 0.0367)),
            Optic = Point(Vector3.new(-0.0000, 0.3283, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.2857, 0.1093, 0.0395)),
            Charm = Point(Vector3.new(-0.6429, -0.1442, 0.1071)),
        },
        MagAxis = Vector3.new(-0.080, 0.997, -0.000),
        GripPose = {
            R = {
                Wrist = V(-0.1400, -0.0707, 0.1288),
                Thumb = { V(-0.0295, -0.0203, 0.0432), V(0.0691, -0.0275, -0.0389), V(0.1663, -0.0339, -0.0477), V(0.2632, -0.0401, -0.0369) },
                Index = { V(0.1892, -0.1105, 0.0899), V(0.3095, -0.0762, 0.0761), V(0.3594, -0.0759, 0.0080), V(0.2780, -0.0748, 0.0303) },
                Middle = { V(0.1543, -0.1800, 0.1288), V(0.1718, -0.2008, -0.0050), V(0.0663, -0.1649, -0.0347), V(-0.0253, -0.1247, 0.0227) },
                Ring = { V(0.1081, -0.2416, 0.1296), V(0.1232, -0.2596, 0.0144), V(0.0367, -0.2300, -0.0099), V(-0.0385, -0.1971, 0.0372) },
                Pinky = { V(0.0427, -0.2935, 0.1123), V(0.0536, -0.3064, 0.0292), V(-0.0089, -0.2851, 0.0117), V(-0.0631, -0.2613, 0.0456) },
            },
            L = {
                Wrist = V(0.3095, -0.0334, -0.0639),
                Thumb = { V(0.4082, 0.0444, 0.0154), V(0.5189, 0.0135, 0.0731), V(0.6098, 0.0002, 0.1067), V(0.7067, -0.0115, 0.1125) },
                Index = { V(0.6403, -0.0022, -0.0306), V(0.6506, -0.0075, 0.0947), V(0.5674, 0.0048, 0.1021), V(0.5086, 0.0154, 0.0424) },
                Middle = { V(0.6200, -0.0800, -0.0639), V(0.6312, -0.0857, 0.0720), V(0.5175, -0.0690, 0.0821), V(0.4372, -0.0545, 0.0006) },
                Ring = { V(0.5875, -0.1496, -0.0595), V(0.5971, -0.1545, 0.0575), V(0.5038, -0.1408, 0.0657), V(0.4379, -0.1289, -0.0012) },
                Pinky = { V(0.5342, -0.2124, -0.0372), V(0.5412, -0.2160, 0.0472), V(0.4739, -0.2061, 0.0531), V(0.4264, -0.1975, 0.0049) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0.2,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        MagPull = 0.8,
        RecoilKick = { Back = 0.09, Up = 0.02, Pitch = 1.6, Roll = 0.6 },
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        Sounds = "TAR21",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    GALIL = {
        Asset = "GALIL",
        Class = "Rifle",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.7321, 0.0891, -0.0161)),
            TriggerPivot = Point(Vector3.new(-0.4845, 0.0213, -0.0161)),
            MagWell = Point(Vector3.new(-0.1992, 0.0839, -0.0157)),
            Optic = Point(Vector3.new(-0.0000, 0.2092, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.7321, 0.0891, -0.0161)),
            Charm = Point(Vector3.new(-0.8661, -0.0709, 0.1071)),
        },
        MagAxis = Vector3.new(-0.352, 0.936, 0.002),
        GripPose = {
            R = {
                Wrist = V(-0.8778, -0.0726, 0.0740),
                Thumb = { V(-0.7720, -0.0128, -0.0116), V(-0.6731, -0.0115, -0.0937), V(-0.5757, -0.0095, -0.1025), V(-0.4786, -0.0073, -0.0917) },
                Index = { V(-0.5463, -0.0838, 0.0350), V(-0.4294, -0.0393, 0.0213), V(-0.3797, -0.0347, -0.0468), V(-0.4609, -0.0406, -0.0245) },
                Middle = { V(-0.5751, -0.1561, 0.0740), V(-0.5559, -0.1754, -0.0599), V(-0.6640, -0.1486, -0.0895), V(-0.7588, -0.1164, -0.0321) },
                Ring = { V(-0.6158, -0.2214, 0.0748), V(-0.5992, -0.2380, -0.0405), V(-0.6880, -0.2160, -0.0648), V(-0.7658, -0.1897, -0.0176) },
                Pinky = { V(-0.6766, -0.2788, 0.0575), V(-0.6646, -0.2907, -0.0256), V(-0.7287, -0.2749, -0.0432), V(-0.7847, -0.2558, -0.0092) },
            },
            L = {
                Wrist = V(0.4143, -0.1387, -0.2423),
                Thumb = { V(0.5042, -0.0318, -0.1914), V(0.5403, 0.0552, -0.1037), V(0.6243, 0.1050, -0.1045), V(0.7082, 0.1553, -0.1046) },
                Index = { V(0.4805, 0.0233, 0.0422), V(0.5196, 0.1388, 0.0733), V(0.5748, 0.2027, 0.0722), V(0.6584, 0.1911, 0.0724) },
                Middle = { V(0.4000, -0.0100, 0.0438), V(0.4350, 0.1194, 0.0701), V(0.5012, 0.2138, 0.0728), V(0.6043, 0.1620, 0.0713) },
                Ring = { V(0.3276, -0.0143, 0.0181), V(0.3556, 0.0926, 0.0582), V(0.4033, 0.1736, 0.0691), V(0.4910, 0.2088, 0.0739) },
                Pinky = { V(0.2603, -0.0111, -0.0342), V(0.2780, 0.0551, 0.0157), V(0.3070, 0.1125, 0.0386), V(0.3543, 0.1582, 0.0568) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0.2,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        MagPull = 0.8,
        RecoilKick = { Back = 0.09, Up = 0.02, Pitch = 1.6, Roll = 0.6 },
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        Sounds = "GALIL",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    HK416 = {
        Asset = "HK416",
        Class = "Rifle",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.6071, 0.1625, -0.0229)),
            TriggerPivot = Point(Vector3.new(-0.3738, -0.0277, -0.0229)),
            MagWell = Point(Vector3.new(-0.1324, 0.1115, -0.0229)),
            Optic = Point(Vector3.new(-0.0000, 0.3077, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.6071, 0.1625, -0.0229)),
            Charm = Point(Vector3.new(-0.8036, -0.1315, 0.1071)),
        },
        MagAxis = Vector3.new(-0.125, 0.992, -0.000),
        GripPose = {
            R = {
                Wrist = V(-0.7540, -0.0682, 0.0680),
                Thumb = { V(-0.6376, -0.0332, -0.0176), V(-0.5409, -0.0537, -0.0997), V(-0.4454, -0.0731, -0.1085), V(-0.3503, -0.0924, -0.0977) },
                Index = { V(-0.4332, -0.1522, 0.0291), V(-0.3093, -0.1345, 0.0153), V(-0.2598, -0.1409, -0.0528), V(-0.3403, -0.1288, -0.0305) },
                Middle = { V(-0.4772, -0.2163, 0.0680), V(-0.4627, -0.2393, -0.0658), V(-0.5623, -0.1895, -0.0955), V(-0.6476, -0.1372, -0.0381) },
                Ring = { V(-0.5312, -0.2711, 0.0688), V(-0.5187, -0.2909, -0.0464), V(-0.6004, -0.2499, -0.0707), V(-0.6705, -0.2071, -0.0236) },
                Pinky = { V(-0.6031, -0.3136, 0.0515), V(-0.5941, -0.3279, -0.0316), V(-0.6531, -0.2984, -0.0491), V(-0.7036, -0.2675, -0.0152) },
            },
            L = {
                Wrist = V(0.4643, -0.1017, -0.1876),
                Thumb = { V(0.5541, 0.0052, -0.1367), V(0.6001, 0.1160, -0.1830), V(0.6911, 0.1499, -0.1715), V(0.7738, 0.2020, -0.1729) },
                Index = { V(0.5304, 0.0602, 0.0968), V(0.5696, 0.1758, 0.1279), V(0.6247, 0.2397, 0.1268), V(0.7083, 0.2280, 0.1270) },
                Middle = { V(0.4500, 0.0270, 0.0984), V(0.4849, 0.1564, 0.1247), V(0.5512, 0.2507, 0.1274), V(0.6542, 0.1989, 0.1259) },
                Ring = { V(0.3776, 0.0227, 0.0727), V(0.4056, 0.1296, 0.1128), V(0.4532, 0.2106, 0.1237), V(0.5410, 0.2458, 0.1285) },
                Pinky = { V(0.3102, 0.0258, 0.0204), V(0.3280, 0.0921, 0.0703), V(0.3570, 0.1495, 0.0932), V(0.4042, 0.1952, 0.1114) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0.2,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        MagPull = 0.8,
        RecoilKick = { Back = 0.09, Up = 0.02, Pitch = 1.6, Roll = 0.6 },
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        Sounds = "HK416",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    MP40 = {
        Asset = "MP40",
        Class = "SMG",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.4821, 0.2205, 0.0429)),
            TriggerPivot = Point(Vector3.new(-0.3225, 0.0253, 0.0429)),
            MagWell = Point(Vector3.new(0.5408, 0.1828, 0.0448)),
            Optic = Point(Vector3.new(-0.0000, 0.3275, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.4821, 0.2205, 0.0429)),
            Charm = Point(Vector3.new(-0.7411, -0.1029, 0.1071)),
        },
        MagAxis = Vector3.new(-0.001, 1.000, 0.000),
        GripPose = {
            R = {
                Wrist = V(-0.7304, -0.0896, 0.1429),
                Thumb = { V(-0.6217, -0.0355, 0.0573), V(-0.5227, -0.0394, -0.0248), V(-0.4254, -0.0425, -0.0336), V(-0.3283, -0.0454, -0.0228) },
                Index = { V(-0.4000, -0.1181, 0.1040), V(-0.2808, -0.0799, 0.0902), V(-0.2310, -0.0779, 0.0221), V(-0.3124, -0.0796, 0.0444) },
                Middle = { V(-0.4326, -0.1888, 0.1429), V(-0.4143, -0.2092, 0.0091), V(-0.5210, -0.1768, -0.0206), V(-0.6139, -0.1397, 0.0368) },
                Ring = { V(-0.4766, -0.2519, 0.1437), V(-0.4609, -0.2695, 0.0285), V(-0.5484, -0.2428, 0.0042), V(-0.6246, -0.2126, 0.0513) },
                Pinky = { V(-0.5402, -0.3060, 0.1264), V(-0.5289, -0.3187, 0.0433), V(-0.5920, -0.2996, 0.0258), V(-0.6470, -0.2776, 0.0597) },
            },
            L = {
                Wrist = V(0.5743, -0.1487, -0.1673),
                Thumb = { V(0.6641, -0.0418, -0.1164), V(0.7066, 0.0605, -0.0511), V(0.7949, 0.1009, -0.0618), V(0.8785, 0.1515, -0.0614) },
                Index = { V(0.6404, 0.0132, 0.1172), V(0.6795, 0.1287, 0.1483), V(0.7347, 0.1927, 0.1472), V(0.8183, 0.1810, 0.1474) },
                Middle = { V(0.5600, -0.0200, 0.1187), V(0.5949, 0.1093, 0.1451), V(0.6611, 0.2037, 0.1478), V(0.7642, 0.1520, 0.1463) },
                Ring = { V(0.4875, -0.0243, 0.0931), V(0.5155, 0.0825, 0.1332), V(0.5632, 0.1636, 0.1441), V(0.6509, 0.1988, 0.1489) },
                Pinky = { V(0.4202, -0.0212, 0.0408), V(0.4379, 0.0450, 0.0907), V(0.4669, 0.1024, 0.1135), V(0.5142, 0.1481, 0.1318) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0.2,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        MagPull = 0.8,
        RecoilKick = { Back = 0.05, Up = 0.02, Pitch = 1.0, Roll = 0.6 },
        Fx = { Flash = "Rifle", Shell = "9mm" },
        Sounds = "MP40",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    PPSH = {
        Asset = "PPSH",
        Class = "SMG",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.5000, 0.2353, -0.0257)),
            TriggerPivot = Point(Vector3.new(-0.2894, 0.0301, -0.0257)),
            MagWell = Point(Vector3.new(0.3088, 0.1456, 0.0016)),
            Optic = Point(Vector3.new(-0.0000, 0.3034, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.5000, 0.2353, -0.0257)),
            Charm = Point(Vector3.new(-0.7500, -0.1024, 0.1071)),
        },
        MagAxis = Vector3.new(0, 1, 0), -- (Update 4: the drum turned 90 deg -- round faces front / back like the real gun -- plugs straight up)
        GripPose = {
            R = {
                Wrist = V(-0.6827, -0.0638, 0.0644),
                Thumb = { V(-0.5769, -0.0040, -0.0212), V(-0.4780, -0.0027, -0.1033), V(-0.3806, -0.0007, -0.1121), V(-0.2835, 0.0015, -0.1013) },
                Index = { V(-0.3512, -0.0750, 0.0254), V(-0.2343, -0.0305, 0.0117), V(-0.1846, -0.0259, -0.0564), V(-0.2658, -0.0318, -0.0341) },
                Middle = { V(-0.3800, -0.1473, 0.0644), V(-0.3608, -0.1666, -0.0695), V(-0.4689, -0.1398, -0.0991), V(-0.5637, -0.1076, -0.0417) },
                Ring = { V(-0.4207, -0.2126, 0.0652), V(-0.4041, -0.2292, -0.0501), V(-0.4929, -0.2072, -0.0744), V(-0.5707, -0.1809, -0.0272) },
                Pinky = { V(-0.4815, -0.2700, 0.0479), V(-0.4695, -0.2819, -0.0352), V(-0.5336, -0.2661, -0.0528), V(-0.5896, -0.2470, -0.0188) },
            },
            L = {
                Wrist = V(0.7643, -0.0327, -0.2519),
                Thumb = { V(0.8542, 0.0742, -0.2010), V(0.8903, 0.1612, -0.1133), V(0.9743, 0.2110, -0.1141), V(1.0582, 0.2613, -0.1142) },
                Index = { V(0.8305, 0.1293, 0.0326), V(0.8696, 0.2448, 0.0637), V(0.9248, 0.3087, 0.0626), V(1.0084, 0.2971, 0.0628) },
                Middle = { V(0.7500, 0.0960, 0.0342), V(0.7850, 0.2254, 0.0605), V(0.8512, 0.3198, 0.0632), V(0.9543, 0.2680, 0.0617) },
                Ring = { V(0.6776, 0.0917, 0.0085), V(0.7056, 0.1986, 0.0486), V(0.7533, 0.2796, 0.0595), V(0.8410, 0.3148, 0.0643) },
                Pinky = { V(0.6103, 0.0949, -0.0438), V(0.6280, 0.1611, 0.0061), V(0.6570, 0.2185, 0.0290), V(0.7043, 0.2642, 0.0472) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0.2,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        MagPull = 0.6,
        RecoilKick = { Back = 0.05, Up = 0.02, Pitch = 1.0, Roll = 0.6 },
        Fx = { Flash = "Rifle", Shell = "9mm" },
        Sounds = "PPSH",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    VECTOR = {
        Asset = "VECTOR",
        Class = "SMG",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            -- (0.97: measured on the v2 model -- the v1 points left the trigger at the bottom of the grip and the muzzle
            -- 0.3 under the barrel; owner: "vector kind of floats")
            Muzzle = Point(Vector3.new(1.2890, 0.3160, 0.0114)),
            TriggerPivot = Point(Vector3.new(0.2250, 0.3840, 0.0114)),
            MagWell = Point(Vector3.new(0.4675, -0.0004, 0.0081)),
            Optic = Point(Vector3.new(-0.0000, 0.2281, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.2890, 0.3160, 0.0114)),
            Charm = Point(Vector3.new(-0.5536, -0.1257, 0.1071)),
        },
        MagAxis = Vector3.new(0.308, 0.951, -0.002),
        GripPose = {
            R = {
                Wrist = V(-0.3583, 0.0064, 0.1114),
                Thumb = { V(-0.2636, 0.0825, 0.0258), V(-0.1661, 0.0999, -0.0563), V(-0.0704, 0.1177, -0.0651), V(0.0250, 0.1357, -0.0543) },
                Index = { V(-0.0294, 0.0492, 0.0725), V(0.0788, 0.1121, 0.0587), V(0.1271, 0.1247, -0.0094), V(0.0479, 0.1057, 0.0129) },
                Middle = { V(-0.0461, -0.0268, 0.1114), V(-0.0240, -0.0428, -0.0224), V(-0.1351, -0.0340, -0.0521), V(-0.2337, -0.0176, 0.0053) },
                Ring = { V(-0.0755, -0.0979, 0.1122), V(-0.0565, -0.1116, -0.0030), V(-0.1477, -0.1043, -0.0273), V(-0.2287, -0.0910, 0.0198) },
                Pinky = { V(-0.1262, -0.1644, 0.0949), V(-0.1124, -0.1742, 0.0118), V(-0.1782, -0.1691, -0.0057), V(-0.2366, -0.1594, 0.0282) },
            },
            L = {
                Wrist = V(0.4295, -0.1534, -0.0858),
                Thumb = { V(0.5282, -0.0756, -0.0064), V(0.6390, -0.1064, 0.0513), V(0.7298, -0.1197, 0.0848), V(0.8267, -0.1315, 0.0907) },
                Index = { V(0.7603, -0.1222, -0.0525), V(0.7706, -0.1275, 0.0729), V(0.6874, -0.1152, 0.0802), V(0.6286, -0.1046, 0.0206) },
                Middle = { V(0.7400, -0.2000, -0.0858), V(0.7512, -0.2057, 0.0502), V(0.6375, -0.1890, 0.0602), V(0.5572, -0.1745, -0.0213) },
                Ring = { V(0.7075, -0.2696, -0.0814), V(0.7171, -0.2745, 0.0356), V(0.6238, -0.2608, 0.0439), V(0.5580, -0.2489, -0.0230) },
                Pinky = { V(0.6543, -0.3324, -0.0591), V(0.6612, -0.3360, 0.0253), V(0.5940, -0.3261, 0.0313), V(0.5464, -0.3175, -0.0170) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0.2,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        MagPull = 0.8,
        RecoilKick = { Back = 0.04, Up = 0.02, Pitch = 0.8, Roll = 0.6 },
        Fx = { Flash = "Rifle", Shell = "9mm" },
        Sounds = "VECTOR",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    USAS12 = {
        Asset = "USAS12",
        Class = "Shotgun",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.7103, 0.2363, 0.0531)),
            TriggerPivot = Point(Vector3.new(-0.4237, 0.0522, 0.0531)),
            MagWell = Point(Vector3.new(-0.0733, 0.1435, 0.0529)),
            Optic = Point(Vector3.new(-0.0000, 0.5644, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.7103, 0.2363, 0.0531)),
            Charm = Point(Vector3.new(-0.8552, -0.1798, 0.1071)),
        },
        MagAxis = Vector3.new(-0.156, 0.988, -0.002),
        GripPose = {
            R = {
                Wrist = V(-0.8170, -0.0417, 0.1432),
                Thumb = { V(-0.7112, 0.0181, 0.0576), V(-0.6123, 0.0194, -0.0245), V(-0.5149, 0.0214, -0.0333), V(-0.4178, 0.0236, -0.0225) },
                Index = { V(-0.4855, -0.0529, 0.1042), V(-0.3686, -0.0084, 0.0905), V(-0.3189, -0.0038, 0.0224), V(-0.4001, -0.0097, 0.0447) },
                Middle = { V(-0.5143, -0.1252, 0.1432), V(-0.4951, -0.1445, 0.0093), V(-0.6032, -0.1177, -0.0203), V(-0.6980, -0.0855, 0.0371) },
                Ring = { V(-0.5550, -0.1905, 0.1440), V(-0.5384, -0.2071, 0.0287), V(-0.6272, -0.1851, 0.0044), V(-0.7050, -0.1588, 0.0516) },
                Pinky = { V(-0.6158, -0.2479, 0.1267), V(-0.6038, -0.2598, 0.0436), V(-0.6679, -0.2440, 0.0260), V(-0.7239, -0.2249, 0.0600) },
            },
            L = {
                Wrist = V(0.5643, 0.0013, -0.1531),
                Thumb = { V(0.6542, 0.1081, -0.1022), V(0.6982, 0.2143, -0.0445), V(0.7877, 0.2518, -0.0562), V(0.8710, 0.3030, -0.0553) },
                Index = { V(0.6305, 0.1632, 0.1314), V(0.6696, 0.2787, 0.1625), V(0.7423, 0.3217, 0.1610), V(0.8150, 0.2789, 0.1625) },
                Middle = { V(0.5500, 0.1300, 0.1330), V(0.5850, 0.2593, 0.1593), V(0.6706, 0.3365, 0.1628), V(0.7212, 0.2329, 0.1581) },
                Ring = { V(0.4776, 0.1257, 0.1073), V(0.5056, 0.2325, 0.1474), V(0.5646, 0.3053, 0.1609), V(0.6590, 0.3116, 0.1621) },
                Pinky = { V(0.4103, 0.1288, 0.0550), V(0.4280, 0.1950, 0.1049), V(0.4616, 0.2482, 0.1314), V(0.5146, 0.2867, 0.1506) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0.2,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        MagPull = 1.0,
        RecoilKick = { Back = 0.09, Up = 0.02, Pitch = 2.4, Roll = 0.6 },
        Fx = { Flash = "Shotgun", Shell = "12ga" },
        Sounds = "USAS12",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    DBARREL = {
        Asset = "DBARREL",
        Class = "Shotgun",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Furniture" },
            Break = { Zone = "Frame" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(3.0991, 0.4938, -0.0000)),
            TriggerPivot = Point(Vector3.new(0.4133, 0.2628, 0.0014)),
            Optic = Point(Vector3.new(-0.0000, 0.3222, 0.0000)),
            MuzzleDevice = Point(Vector3.new(3.0991, 0.4938, -0.0000)),
            Charm = Point(Vector3.new(-0.4147, -0.1686, 0.1071)),
            Hinge = Point(Vector3.new(0.7906, 0.3062, 0.0000)),
            LoadPort = Point(Vector3.new(0.5408, 0.4866, 0.0000)),
        },
        GripPose = {
            R = {
                Wrist = V(0.0200, 0.1689, 0.0915),
                Thumb = { V(0.1258, 0.2287, 0.0059), V(0.2247, 0.2300, -0.0762), V(0.3221, 0.2320, -0.0850), V(0.4192, 0.2342, -0.0742) },
                Index = { V(0.3515, 0.1577, 0.0525), V(0.4684, 0.2022, 0.0388), V(0.5181, 0.2068, -0.0293), V(0.4369, 0.2009, -0.0070) },
                Middle = { V(0.3227, 0.0854, 0.0915), V(0.3419, 0.0661, -0.0424), V(0.2338, 0.0929, -0.0720), V(0.1390, 0.1251, -0.0146) },
                Ring = { V(0.2820, 0.0201, 0.0923), V(0.2986, 0.0035, -0.0230), V(0.2098, 0.0255, -0.0473), V(0.1320, 0.0518, -0.0001) },
                Pinky = { V(0.2212, -0.0373, 0.0750), V(0.2332, -0.0492, -0.0081), V(0.1691, -0.0334, -0.0257), V(0.1131, -0.0143, 0.0083) },
            },
            L = {
                Wrist = V(1.1643, 0.1513, -0.1796),
                Thumb = { V(1.2541, 0.2582, -0.1288), V(1.2942, 0.3683, -0.0757), V(1.3817, 0.4115, -0.0814), V(1.4787, 0.4235, -0.0814) },
                Index = { V(1.2304, 0.3133, 0.1048), V(1.2698, 0.4256, 0.1458), V(1.3539, 0.4185, 0.1432), V(1.4351, 0.4401, 0.1511) },
                Middle = { V(1.1500, 0.2800, 0.1064), V(1.1842, 0.4077, 0.1406), V(1.2960, 0.4352, 0.1480), V(1.2232, 0.3489, 0.1248) },
                Ring = { V(1.0776, 0.2757, 0.0807), V(1.1048, 0.3805, 0.1264), V(1.1818, 0.4310, 0.1485), V(1.2711, 0.4023, 0.1360) },
                Pinky = { V(1.0102, 0.2788, 0.0284), V(1.0274, 0.3433, 0.0808), V(1.0672, 0.3862, 0.1157), V(1.1261, 0.4130, 0.1375) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Break",
        BreakAngle = -38,
        SlideTravel = 0,
        NoBoltLock = true,
        TriggerAngle = -16,
        RecoilKick = { Back = 0.2, Up = 0.04, Pitch = 6.5, Roll = 1.4 },
        Fx = { Flash = "Shotgun", Shell = "12ga" },
        Sounds = "DBARREL",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    KSG = {
        Asset = "KSG",
        Class = "Shotgun",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Pump = { Zone = "Furniture" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.2143, 0.1936, -0.0000)),
            TriggerPivot = Point(Vector3.new(-0.0019, -0.0334, 0.0000)),
            Optic = Point(Vector3.new(-0.0000, 0.4263, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.2143, 0.1936, -0.0000)),
            Charm = Point(Vector3.new(-0.6071, -0.1279, 0.1071)),
            LoadPort = Point(Vector3.new(-0.6428, -0.0714, 0.0000)),
        },
        GripPose = {
            R = {
                Wrist = V(-0.3952, -0.1273, 0.0901),
                Thumb = { V(-0.2894, -0.0675, 0.0045), V(-0.1905, -0.0662, -0.0776), V(-0.0931, -0.0642, -0.0864), V(0.0040, -0.0620, -0.0756) },
                Index = { V(-0.0637, -0.1385, 0.0511), V(0.0532, -0.0940, 0.0374), V(0.1029, -0.0894, -0.0307), V(0.0217, -0.0953, -0.0084) },
                Middle = { V(-0.0925, -0.2108, 0.0901), V(-0.0733, -0.2301, -0.0438), V(-0.1814, -0.2033, -0.0734), V(-0.2762, -0.1711, -0.0160) },
                Ring = { V(-0.1332, -0.2761, 0.0909), V(-0.1166, -0.2927, -0.0244), V(-0.2054, -0.2707, -0.0487), V(-0.2832, -0.2444, -0.0015) },
                Pinky = { V(-0.1940, -0.3335, 0.0736), V(-0.1820, -0.3454, -0.0095), V(-0.2461, -0.3296, -0.0271), V(-0.3021, -0.3105, 0.0069) },
            },
            L = {
                Wrist = V(0.6243, -0.1687, -0.1810),
                Thumb = { V(0.7141, -0.0618, -0.1302), V(0.7542, 0.0483, -0.0771), V(0.8417, 0.0915, -0.0828), V(0.9387, 0.1035, -0.0828) },
                Index = { V(0.6904, -0.0067, 0.1034), V(0.7298, 0.1056, 0.1444), V(0.8139, 0.0985, 0.1418), V(0.8951, 0.1201, 0.1497) },
                Middle = { V(0.6100, -0.0400, 0.1050), V(0.6442, 0.0877, 0.1392), V(0.7560, 0.1152, 0.1466), V(0.6832, 0.0289, 0.1234) },
                Ring = { V(0.5376, -0.0443, 0.0793), V(0.5648, 0.0605, 0.1250), V(0.6418, 0.1110, 0.1471), V(0.7311, 0.0823, 0.1346) },
                Pinky = { V(0.4702, -0.0412, 0.0270), V(0.4874, 0.0233, 0.0794), V(0.5272, 0.0662, 0.1143), V(0.5861, 0.0930, 0.1361) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Pump",
        PumpTravel = 0.24,
        SlideTravel = 0.24,
        NoBoltLock = true,
        TriggerAngle = -16,
        RecoilKick = { Back = 0.16, Up = 0.03, Pitch = 5.0, Roll = 1.2 },
        Fx = { Flash = "Shotgun", Shell = "12ga" },
        Sounds = "KSG",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    M590 = {
        Asset = "M590",
        Class = "Shotgun",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Pump = { Zone = "Furniture" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.7857, 0.2227, 0.0017)),
            TriggerPivot = Point(Vector3.new(-0.4388, 0.1577, 0.0017)),
            Optic = Point(Vector3.new(-0.0000, 0.3529, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.7857, 0.2227, 0.0017)),
            Charm = Point(Vector3.new(-0.8929, -0.1059, 0.1071)),
            LoadPort = Point(Vector3.new(-0.0581, 0.1399, 0.0000)),
        },
        GripPose = {
            R = {
                Wrist = V(-0.8321, 0.0638, 0.0918),
                Thumb = { V(-0.7263, 0.1236, 0.0062), V(-0.6274, 0.1249, -0.0759), V(-0.5300, 0.1269, -0.0847), V(-0.4329, 0.1291, -0.0739) },
                Index = { V(-0.5006, 0.0526, 0.0528), V(-0.3837, 0.0971, 0.0391), V(-0.3340, 0.1017, -0.0290), V(-0.4152, 0.0958, -0.0067) },
                Middle = { V(-0.5294, -0.0197, 0.0918), V(-0.5102, -0.0390, -0.0421), V(-0.6183, -0.0122, -0.0717), V(-0.7131, 0.0200, -0.0143) },
                Ring = { V(-0.5701, -0.0850, 0.0926), V(-0.5535, -0.1016, -0.0227), V(-0.6423, -0.0796, -0.0470), V(-0.7201, -0.0533, 0.0002) },
                Pinky = { V(-0.6309, -0.1424, 0.0753), V(-0.6189, -0.1543, -0.0078), V(-0.6830, -0.1385, -0.0254), V(-0.7390, -0.1194, 0.0086) },
            },
            L = {
                Wrist = V(0.8943, -0.0487, -0.1793),
                Thumb = { V(0.9841, 0.0582, -0.1285), V(1.0242, 0.1683, -0.0754), V(1.1117, 0.2115, -0.0811), V(1.2087, 0.2235, -0.0811) },
                Index = { V(0.9604, 0.1133, 0.1051), V(0.9998, 0.2256, 0.1461), V(1.0839, 0.2185, 0.1435), V(1.1651, 0.2401, 0.1514) },
                Middle = { V(0.8800, 0.0800, 0.1067), V(0.9142, 0.2077, 0.1409), V(1.0260, 0.2352, 0.1483), V(0.9532, 0.1489, 0.1251) },
                Ring = { V(0.8076, 0.0757, 0.0810), V(0.8348, 0.1805, 0.1267), V(0.9118, 0.2310, 0.1488), V(1.0011, 0.2023, 0.1363) },
                Pinky = { V(0.7402, 0.0788, 0.0287), V(0.7574, 0.1433, 0.0811), V(0.7972, 0.1862, 0.1160), V(0.8561, 0.2130, 0.1378) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Pump",
        PumpTravel = 0.29,
        SlideTravel = 0.29,
        NoBoltLock = true,
        TriggerAngle = -16,
        RecoilKick = { Back = 0.16, Up = 0.03, Pitch = 5.0, Roll = 1.2 },
        Fx = { Flash = "Shotgun", Shell = "12ga" },
        Sounds = "M590",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    USP = {
        Asset = "USP",
        Class = "Pistol",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Slide = { Zone = "Slide" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(0.3576, 0.1657, 0.0099)),
            TriggerPivot = Point(Vector3.new(-0.0145, 0.0930, 0.0092)),
            MagWell = Point(Vector3.new(-0.1454, 0.1333, 0.0092)),
            Eject = Point(Vector3.new(0.0218, 0.1636, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.2020, 0.0000)),
            MuzzleDevice = Point(Vector3.new(0.3576, 0.1657, 0.0099)),
            Charm = Point(Vector3.new(-0.1676, -0.0691, 0.1071)),
        },
        MagAxis = Vector3.new(0.223, 0.975, 0.000),
        GripPose = {
            R = {
                Wrist = V(-0.3633, -0.0041, 0.0980),
                Thumb = { V(-0.2562, 0.0533, 0.0124), V(-0.1573, 0.0524, -0.0697), V(-0.0599, 0.0523, -0.0785), V(0.0372, 0.0523, -0.0677) },
                Index = { V(-0.0322, -0.0227, 0.0591), V(0.0857, 0.0192, 0.0453), V(0.1355, 0.0227, -0.0228), V(0.0542, 0.0186, -0.0005) },
                Middle = { V(-0.0626, -0.0943, 0.0980), V(-0.0438, -0.1140, -0.0358), V(-0.1513, -0.0849, -0.0655), V(-0.2453, -0.0506, -0.0081) },
                Ring = { V(-0.1047, -0.1587, 0.0988), V(-0.0885, -0.1757, -0.0164), V(-0.1767, -0.1517, -0.0407), V(-0.2539, -0.1237, 0.0064) },
                Pinky = { V(-0.1667, -0.2147, 0.0815), V(-0.1550, -0.2269, -0.0016), V(-0.2187, -0.2097, -0.0191), V(-0.2743, -0.1894, 0.0148) },
            },
            L = {
                Wrist = V(-0.3090, -0.1948, -0.1702),
                Thumb = { V(-0.2721, -0.0725, -0.0942), V(-0.1651, -0.0011, -0.0934), V(-0.0686, 0.0141, -0.0933), V(0.0284, 0.0140, -0.0811) },
                Index = { V(-0.0425, -0.0016, -0.1139), V(-0.0079, 0.0233, 0.0046), V(-0.0710, 0.0048, 0.0575), V(-0.1494, -0.0236, 0.0708) },
                Middle = { V(-0.0179, -0.0816, -0.1379), V(0.0087, -0.0583, -0.0060), V(-0.0828, -0.0865, 0.0583), V(-0.1906, -0.1264, 0.0665) },
                Ring = { V(-0.0132, -0.1576, -0.1267), V(0.0098, -0.1375, -0.0132), V(-0.0653, -0.1606, 0.0395), V(-0.1538, -0.1934, 0.0462) },
                Pinky = { V(-0.0321, -0.2366, -0.1006), V(-0.0155, -0.2221, -0.0187), V(-0.0696, -0.2388, 0.0193), V(-0.1335, -0.2624, 0.0241) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0.1,
        TriggerAngle = -16,
        MagPull = 0.34,
        MagHoldOffset = 0.06,
        RecoilKick = { Back = 0.12, Up = 0.04, Pitch = 9, Roll = 2 },
        Fx = { Flash = "Pistol", Shell = "9mm" },
        Sounds = "USP",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    P226 = {
        Asset = "P226",
        Class = "Pistol",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Slide = { Zone = "Slide" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(0.3500, 0.1919, 0.0021)),
            TriggerPivot = Point(Vector3.new(-0.0449, 0.0821, 0.0021)),
            MagWell = Point(Vector3.new(-0.1709, 0.0866, 0.0021)),
            Eject = Point(Vector3.new(0.0003, 0.1734, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.2255, 0.0000)),
            MuzzleDevice = Point(Vector3.new(0.3500, 0.1919, 0.0021)),
            Charm = Point(Vector3.new(-0.1750, -0.0677, 0.1071)),
        },
        MagAxis = Vector3.new(0.137, 0.991, 0.000),
        GripPose = {
            R = {
                Wrist = V(-0.3937, -0.0150, 0.0909),
                Thumb = { V(-0.2866, 0.0424, 0.0053), V(-0.1877, 0.0415, -0.0768), V(-0.0903, 0.0414, -0.0856), V(0.0068, 0.0414, -0.0748) },
                Index = { V(-0.0626, -0.0336, 0.0520), V(0.0553, 0.0083, 0.0382), V(0.1051, 0.0118, -0.0299), V(0.0238, 0.0077, -0.0076) },
                Middle = { V(-0.0930, -0.1052, 0.0909), V(-0.0742, -0.1249, -0.0429), V(-0.1817, -0.0958, -0.0726), V(-0.2757, -0.0615, -0.0152) },
                Ring = { V(-0.1351, -0.1696, 0.0917), V(-0.1189, -0.1866, -0.0235), V(-0.2071, -0.1626, -0.0478), V(-0.2843, -0.1346, -0.0007) },
                Pinky = { V(-0.1971, -0.2256, 0.0744), V(-0.1854, -0.2378, -0.0087), V(-0.2491, -0.2206, -0.0262), V(-0.3047, -0.2003, 0.0077) },
            },
            L = {
                Wrist = V(-0.3394, -0.2057, -0.1773),
                Thumb = { V(-0.3025, -0.0834, -0.1013), V(-0.1955, -0.0120, -0.1005), V(-0.0990, 0.0032, -0.1004), V(-0.0020, 0.0031, -0.0882) },
                Index = { V(-0.0729, -0.0125, -0.1210), V(-0.0383, 0.0124, -0.0025), V(-0.1014, -0.0061, 0.0504), V(-0.1798, -0.0345, 0.0637) },
                Middle = { V(-0.0483, -0.0925, -0.1450), V(-0.0217, -0.0692, -0.0131), V(-0.1132, -0.0974, 0.0512), V(-0.2210, -0.1373, 0.0594) },
                Ring = { V(-0.0436, -0.1685, -0.1338), V(-0.0206, -0.1484, -0.0203), V(-0.0957, -0.1715, 0.0324), V(-0.1842, -0.2043, 0.0391) },
                Pinky = { V(-0.0625, -0.2475, -0.1077), V(-0.0459, -0.2330, -0.0258), V(-0.1000, -0.2497, 0.0122), V(-0.1639, -0.2733, 0.0170) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0.1,
        TriggerAngle = -16,
        MagPull = 0.34,
        MagHoldOffset = 0.06,
        RecoilKick = { Back = 0.12, Up = 0.04, Pitch = 9, Roll = 2 },
        Fx = { Flash = "Pistol", Shell = "9mm" },
        Sounds = "P226",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    SR9 = {
        Asset = "SR9",
        Class = "Pistol",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Slide = { Zone = "Slide" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(0.3393, 0.1664, -0.0006)),
            TriggerPivot = Point(Vector3.new(-0.0238, 0.1135, -0.0000)),
            MagWell = Point(Vector3.new(-0.1398, 0.1766, -0.0000)),
            Eject = Point(Vector3.new(0.0040, 0.1906, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.2261, 0.0000)),
            MuzzleDevice = Point(Vector3.new(0.3393, 0.1664, -0.0006)),
            Charm = Point(Vector3.new(-0.1696, -0.0678, 0.1071)),
        },
        MagAxis = Vector3.new(0.135, 0.991, -0.000),
        GripPose = {
            R = {
                Wrist = V(-0.3726, 0.0164, 0.0888),
                Thumb = { V(-0.2655, 0.0738, 0.0032), V(-0.1666, 0.0729, -0.0789), V(-0.0692, 0.0728, -0.0877), V(0.0279, 0.0728, -0.0769) },
                Index = { V(-0.0415, -0.0022, 0.0499), V(0.0764, 0.0397, 0.0361), V(0.1262, 0.0432, -0.0320), V(0.0449, 0.0391, -0.0097) },
                Middle = { V(-0.0719, -0.0738, 0.0888), V(-0.0531, -0.0935, -0.0450), V(-0.1606, -0.0644, -0.0747), V(-0.2546, -0.0301, -0.0173) },
                Ring = { V(-0.1140, -0.1382, 0.0896), V(-0.0978, -0.1552, -0.0256), V(-0.1860, -0.1312, -0.0499), V(-0.2632, -0.1032, -0.0028) },
                Pinky = { V(-0.1760, -0.1942, 0.0723), V(-0.1643, -0.2064, -0.0108), V(-0.2280, -0.1892, -0.0283), V(-0.2836, -0.1689, 0.0056) },
            },
            L = {
                Wrist = V(-0.3183, -0.1743, -0.1794),
                Thumb = { V(-0.2814, -0.0520, -0.1034), V(-0.1744, 0.0194, -0.1026), V(-0.0779, 0.0346, -0.1025), V(0.0191, 0.0345, -0.0903) },
                Index = { V(-0.0518, 0.0189, -0.1231), V(-0.0172, 0.0438, -0.0046), V(-0.0803, 0.0253, 0.0483), V(-0.1587, -0.0031, 0.0616) },
                Middle = { V(-0.0272, -0.0611, -0.1471), V(-0.0006, -0.0378, -0.0152), V(-0.0921, -0.0660, 0.0491), V(-0.1999, -0.1059, 0.0573) },
                Ring = { V(-0.0225, -0.1371, -0.1359), V(0.0005, -0.1170, -0.0224), V(-0.0746, -0.1401, 0.0303), V(-0.1631, -0.1729, 0.0370) },
                Pinky = { V(-0.0414, -0.2161, -0.1098), V(-0.0248, -0.2016, -0.0279), V(-0.0789, -0.2183, 0.0101), V(-0.1428, -0.2419, 0.0149) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0.1,
        TriggerAngle = -16,
        MagPull = 0.34,
        MagHoldOffset = 0.06,
        RecoilKick = { Back = 0.12, Up = 0.04, Pitch = 8, Roll = 2 },
        Fx = { Flash = "Pistol", Shell = "9mm" },
        Sounds = "SR9",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    PX4 = {
        Asset = "PX4",
        Class = "Pistol",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Slide = { Zone = "Slide" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(0.3504, 0.1912, 0.0000)),
            TriggerPivot = Point(Vector3.new(0.0801, 0.0968, 0.0000)),
            MagWell = Point(Vector3.new(-0.0843, 0.1672, 0.0000)),
            Eject = Point(Vector3.new(0.0178, 0.2081, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.2507, 0.0000)),
            MuzzleDevice = Point(Vector3.new(0.3504, 0.1912, 0.0000)),
            Charm = Point(Vector3.new(-0.1694, -0.0752, 0.1071)),
        },
        MagAxis = Vector3.new(0.377, 0.926, 0.000),
        GripPose = {
            R = {
                Wrist = V(-0.2687, -0.0003, 0.0888),
                Thumb = { V(-0.1616, 0.0571, 0.0032), V(-0.0627, 0.0562, -0.0789), V(0.0347, 0.0561, -0.0877), V(0.1318, 0.0561, -0.0769) },
                Index = { V(0.0624, -0.0189, 0.0499), V(0.1803, 0.0230, 0.0361), V(0.2301, 0.0265, -0.0320), V(0.1488, 0.0224, -0.0097) },
                Middle = { V(0.0320, -0.0905, 0.0888), V(0.0508, -0.1102, -0.0450), V(-0.0567, -0.0811, -0.0747), V(-0.1507, -0.0468, -0.0173) },
                Ring = { V(-0.0101, -0.1549, 0.0896), V(0.0061, -0.1719, -0.0256), V(-0.0821, -0.1479, -0.0499), V(-0.1593, -0.1199, -0.0028) },
                Pinky = { V(-0.0721, -0.2109, 0.0723), V(-0.0604, -0.2231, -0.0108), V(-0.1241, -0.2059, -0.0283), V(-0.1797, -0.1856, 0.0056) },
            },
            L = {
                Wrist = V(-0.2144, -0.1910, -0.1794),
                Thumb = { V(-0.1775, -0.0687, -0.1034), V(-0.0705, 0.0027, -0.1026), V(0.0260, 0.0179, -0.1025), V(0.1230, 0.0178, -0.0903) },
                Index = { V(0.0521, 0.0022, -0.1231), V(0.0867, 0.0271, -0.0046), V(0.0236, 0.0086, 0.0483), V(-0.0548, -0.0198, 0.0616) },
                Middle = { V(0.0767, -0.0778, -0.1471), V(0.1033, -0.0545, -0.0152), V(0.0118, -0.0827, 0.0491), V(-0.0960, -0.1226, 0.0573) },
                Ring = { V(0.0814, -0.1538, -0.1359), V(0.1044, -0.1337, -0.0224), V(0.0293, -0.1568, 0.0303), V(-0.0592, -0.1896, 0.0370) },
                Pinky = { V(0.0625, -0.2328, -0.1098), V(0.0791, -0.2183, -0.0279), V(0.0250, -0.2350, 0.0101), V(-0.0389, -0.2586, 0.0149) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0.1,
        TriggerAngle = -16,
        MagPull = 0.34,
        MagHoldOffset = 0.06,
        RecoilKick = { Back = 0.12, Up = 0.04, Pitch = 8, Roll = 2 },
        Fx = { Flash = "Pistol", Shell = "9mm" },
        Sounds = "PX4",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    SVD = {
        Asset = "SVD",
        Class = "Sniper",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(2.1786, -0.0284, -0.0435)),
            TriggerPivot = Point(Vector3.new(-0.9760, -0.1182, -0.0435)),
            MagWell = Point(Vector3.new(-0.5028, -0.0624, -0.0435)),
            Optic = Point(Vector3.new(-0.0000, 0.0637, 0.0000)),
            MuzzleDevice = Point(Vector3.new(2.1786, -0.0284, -0.0435)),
            Charm = Point(Vector3.new(-1.0893, -0.0963, 0.1071)),
        },
        MagAxis = Vector3.new(0.064, 0.998, 0.000),
        GripPose = {
            R = {
                Wrist = V(-1.3693, -0.2121, 0.0466),
                Thumb = { V(-1.2635, -0.1523, -0.0390), V(-1.1646, -0.1510, -0.1211), V(-1.0672, -0.1490, -0.1299), V(-0.9701, -0.1468, -0.1191) },
                Index = { V(-1.0378, -0.2233, 0.0076), V(-0.9209, -0.1788, -0.0061), V(-0.8712, -0.1742, -0.0742), V(-0.9524, -0.1801, -0.0519) },
                Middle = { V(-1.0666, -0.2956, 0.0466), V(-1.0474, -0.3149, -0.0873), V(-1.1555, -0.2881, -0.1169), V(-1.2503, -0.2559, -0.0595) },
                Ring = { V(-1.1073, -0.3609, 0.0474), V(-1.0907, -0.3775, -0.0679), V(-1.1795, -0.3555, -0.0922), V(-1.2573, -0.3292, -0.0450) },
                Pinky = { V(-1.1681, -0.4183, 0.0301), V(-1.1561, -0.4302, -0.0530), V(-1.2202, -0.4144, -0.0706), V(-1.2762, -0.3953, -0.0366) },
            },
            L = {
                Wrist = V(0.5143, -0.2387, -0.2697),
                Thumb = { V(0.6042, -0.1318, -0.2188), V(0.6403, -0.0448, -0.1311), V(0.7243, 0.0050, -0.1319), V(0.8082, 0.0553, -0.1320) },
                Index = { V(0.5805, -0.0767, 0.0148), V(0.6196, 0.0388, 0.0459), V(0.6748, 0.1027, 0.0448), V(0.7584, 0.0911, 0.0450) },
                Middle = { V(0.5000, -0.1100, 0.0164), V(0.5350, 0.0194, 0.0427), V(0.6012, 0.1138, 0.0454), V(0.7043, 0.0620, 0.0439) },
                Ring = { V(0.4276, -0.1143, -0.0093), V(0.4556, -0.0074, 0.0308), V(0.5033, 0.0736, 0.0417), V(0.5910, 0.1088, 0.0465) },
                Pinky = { V(0.3603, -0.1111, -0.0616), V(0.3780, -0.0449, -0.0117), V(0.4070, 0.0125, 0.0112), V(0.4543, 0.0582, 0.0294) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0.2,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        MagPull = 0.7,
        RecoilKick = { Back = 0.16, Up = 0.02, Pitch = 4.5, Roll = 0.6 },
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        Sounds = "SVD",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    SKS = {
        Asset = "SKS",
        Class = "Sniper",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Bolt = { Zone = "Metal" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.8214, 0.1866, -0.0350)),
            TriggerPivot = Point(Vector3.new(-0.6483, -0.0046, -0.0350)),
            Eject = Point(Vector3.new(-0.1252, 0.1506, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.3010, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.8214, 0.1866, -0.0350)),
            Charm = Point(Vector3.new(-0.9107, -0.0990, 0.1071)),
            LoadPort = Point(Vector3.new(-0.0180, 0.2496, 0.0000)),
        },
        GripPose = {
            R = {
                Wrist = V(-1.0416, -0.0985, 0.0551),
                Thumb = { V(-0.9358, -0.0387, -0.0305), V(-0.8369, -0.0374, -0.1126), V(-0.7395, -0.0354, -0.1214), V(-0.6424, -0.0332, -0.1106) },
                Index = { V(-0.7101, -0.1097, 0.0161), V(-0.5932, -0.0652, 0.0024), V(-0.5435, -0.0606, -0.0657), V(-0.6247, -0.0665, -0.0434) },
                Middle = { V(-0.7389, -0.1820, 0.0551), V(-0.7197, -0.2013, -0.0788), V(-0.8278, -0.1745, -0.1084), V(-0.9226, -0.1423, -0.0510) },
                Ring = { V(-0.7796, -0.2473, 0.0559), V(-0.7630, -0.2639, -0.0594), V(-0.8518, -0.2419, -0.0837), V(-0.9296, -0.2156, -0.0365) },
                Pinky = { V(-0.8404, -0.3047, 0.0386), V(-0.8284, -0.3166, -0.0445), V(-0.8925, -0.3008, -0.0621), V(-0.9485, -0.2817, -0.0281) },
            },
            L = {
                Wrist = V(0.5143, -0.0987, -0.2612),
                Thumb = { V(0.6042, 0.0082, -0.2103), V(0.6403, 0.0952, -0.1226), V(0.7243, 0.1450, -0.1234), V(0.8082, 0.1953, -0.1235) },
                Index = { V(0.5805, 0.0633, 0.0233), V(0.6196, 0.1788, 0.0544), V(0.6748, 0.2427, 0.0533), V(0.7584, 0.2311, 0.0535) },
                Middle = { V(0.5000, 0.0300, 0.0249), V(0.5350, 0.1594, 0.0512), V(0.6012, 0.2538, 0.0539), V(0.7043, 0.2020, 0.0524) },
                Ring = { V(0.4276, 0.0257, -0.0008), V(0.4556, 0.1326, 0.0393), V(0.5033, 0.2136, 0.0502), V(0.5910, 0.2488, 0.0550) },
                Pinky = { V(0.3603, 0.0289, -0.0531), V(0.3780, 0.0951, -0.0032), V(0.4070, 0.1525, 0.0197), V(0.4543, 0.1982, 0.0379) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "TubeSemi",
        TopLoad = true,
        SlideTravel = 0.22,
        NoBoltLock = true,
        TriggerAngle = -16,
        RecoilKick = { Back = 0.12, Up = 0.03, Pitch = 3.2, Roll = 0.8 },
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        Sounds = "SKS",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    M40 = {
        Asset = "M40",
        Class = "Sniper",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Bolt = { Zone = "Metal" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.9464, 0.0363, -0.0156)),
            TriggerPivot = Point(Vector3.new(-0.7523, -0.1080, -0.0156)),
            MagWell = Point(Vector3.new(-0.4396, 0.0034, -0.0156)),
            Eject = Point(Vector3.new(-0.5184, -0.0068, 0.0714), Vector3.new(-0.000, 0.000, 1.000)),
            Optic = Point(Vector3.new(-0.0000, 0.3185, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.9464, 0.0363, -0.0156)),
            Charm = Point(Vector3.new(-0.9732, -0.1181, 0.1071)),
            BoltKnob = Point(Vector3.new(-0.7369, -0.0600, 0.1325)),
            BoltAxis = Point(Vector3.new(-0.0000, -0.0136, -0.0249)),
        },
        MagAxis = Vector3.new(-0.066, 0.998, 0.000),
        GripPose = {
            R = {
                Wrist = V(-1.1456, -0.2019, 0.0745),
                Thumb = { V(-1.0398, -0.1421, -0.0111), V(-0.9409, -0.1408, -0.0932), V(-0.8435, -0.1388, -0.1020), V(-0.7464, -0.1366, -0.0912) },
                Index = { V(-0.8141, -0.2131, 0.0355), V(-0.6972, -0.1686, 0.0218), V(-0.6475, -0.1640, -0.0463), V(-0.7287, -0.1699, -0.0240) },
                Middle = { V(-0.8429, -0.2854, 0.0745), V(-0.8237, -0.3047, -0.0594), V(-0.9318, -0.2779, -0.0890), V(-1.0266, -0.2457, -0.0316) },
                Ring = { V(-0.8836, -0.3507, 0.0753), V(-0.8670, -0.3673, -0.0400), V(-0.9558, -0.3453, -0.0643), V(-1.0336, -0.3190, -0.0171) },
                Pinky = { V(-0.9444, -0.4081, 0.0580), V(-0.9324, -0.4200, -0.0251), V(-0.9965, -0.4042, -0.0427), V(-1.0525, -0.3851, -0.0087) },
            },
            L = {
                Wrist = V(0.4643, -0.2487, -0.2419),
                Thumb = { V(0.5541, -0.1418, -0.1910), V(0.5901, -0.0550, -0.1031), V(0.6742, -0.0051, -0.1038), V(0.7580, 0.0452, -0.1039) },
                Index = { V(0.5304, -0.0867, 0.0426), V(0.5695, 0.0288, 0.0737), V(0.6422, 0.0718, 0.0722), V(0.7150, 0.0289, 0.0737) },
                Middle = { V(0.4500, -0.1200, 0.0442), V(0.4849, 0.0094, 0.0705), V(0.5705, 0.0866, 0.0739), V(0.6211, -0.0170, 0.0693) },
                Ring = { V(0.3775, -0.1243, 0.0185), V(0.4055, -0.0174, 0.0586), V(0.4645, 0.0554, 0.0721), V(0.5589, 0.0617, 0.0733) },
                Pinky = { V(0.3102, -0.1211, -0.0338), V(0.3280, -0.0549, 0.0161), V(0.3616, -0.0018, 0.0426), V(0.4145, 0.0368, 0.0618) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "BoltAction",
        SlideTravel = 0.36,
        BoltLift = -62,
        NoBoltLock = true,
        TriggerAngle = -14,
        MagHoldOffset = 0.12,
        RecoilKick = { Back = 0.2, Up = 0.04, Pitch = 6.5, Roll = 1.0 },
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        Sounds = "M40",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    EMR = {
        Asset = "EMR",
        Class = "Sniper",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.6964, 0.2272, -0.0296)),
            TriggerPivot = Point(Vector3.new(-0.6702, 0.0394, -0.0296)),
            MagWell = Point(Vector3.new(-0.3833, 0.1677, -0.0296)),
            Optic = Point(Vector3.new(-0.0000, 0.3046, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.6964, 0.2272, -0.0296)),
            Charm = Point(Vector3.new(-0.8482, -0.0993, 0.1071)),
        },
        MagAxis = Vector3.new(-0.231, 0.973, 0.000),
        GripPose = {
            R = {
                Wrist = V(-1.0504, -0.0011, 0.0613),
                Thumb = { V(-0.9340, 0.0339, -0.0243), V(-0.8373, 0.0134, -0.1064), V(-0.7418, -0.0060, -0.1152), V(-0.6467, -0.0253, -0.1044) },
                Index = { V(-0.7296, -0.0851, 0.0224), V(-0.6057, -0.0674, 0.0086), V(-0.5562, -0.0738, -0.0595), V(-0.6367, -0.0617, -0.0372) },
                Middle = { V(-0.7736, -0.1492, 0.0613), V(-0.7591, -0.1722, -0.0725), V(-0.8587, -0.1224, -0.1022), V(-0.9440, -0.0701, -0.0448) },
                Ring = { V(-0.8276, -0.2040, 0.0621), V(-0.8151, -0.2238, -0.0531), V(-0.8968, -0.1828, -0.0774), V(-0.9669, -0.1400, -0.0303) },
                Pinky = { V(-0.8995, -0.2465, 0.0448), V(-0.8905, -0.2608, -0.0383), V(-0.9495, -0.2313, -0.0558), V(-1.0000, -0.2004, -0.0219) },
            },
            L = {
                Wrist = V(0.4143, -0.1287, -0.1943),
                Thumb = { V(0.5041, -0.0218, -0.1434), V(0.5501, 0.0890, -0.1897), V(0.6411, 0.1229, -0.1782), V(0.7238, 0.1750, -0.1796) },
                Index = { V(0.4804, 0.0332, 0.0901), V(0.5196, 0.1488, 0.1212), V(0.5747, 0.2127, 0.1201), V(0.6583, 0.2010, 0.1203) },
                Middle = { V(0.4000, 0.0000, 0.0917), V(0.4349, 0.1294, 0.1180), V(0.5012, 0.2237, 0.1207), V(0.6042, 0.1719, 0.1192) },
                Ring = { V(0.3276, -0.0043, 0.0660), V(0.3556, 0.1026, 0.1061), V(0.4032, 0.1836, 0.1170), V(0.4910, 0.2188, 0.1218) },
                Pinky = { V(0.2602, -0.0012, 0.0137), V(0.2780, 0.0651, 0.0636), V(0.3070, 0.1225, 0.0865), V(0.3542, 0.1682, 0.1047) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0.2,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        MagPull = 0.7,
        RecoilKick = { Back = 0.14, Up = 0.02, Pitch = 3.8, Roll = 0.6 },
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        Sounds = "EMR",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    MK11 = {
        Asset = "MK11",
        Class = "Sniper",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
        },
        Points = {
            Muzzle = Point(Vector3.new(1.9643, 0.1566, -0.0022)),
            TriggerPivot = Point(Vector3.new(-0.5839, -0.0189, -0.0022)),
            MagWell = Point(Vector3.new(-0.3335, 0.0983, -0.0022)),
            Optic = Point(Vector3.new(-0.0000, 0.2712, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.9643, 0.1566, -0.0022)),
            Charm = Point(Vector3.new(-0.9821, -0.1254, 0.1071)),
        },
        MagAxis = Vector3.new(-0.079, 0.997, -0.000),
        GripPose = {
            R = {
                Wrist = V(-0.9641, -0.0594, 0.0887),
                Thumb = { V(-0.8477, -0.0244, 0.0031), V(-0.7510, -0.0449, -0.0790), V(-0.6555, -0.0643, -0.0878), V(-0.5604, -0.0836, -0.0770) },
                Index = { V(-0.6433, -0.1434, 0.0498), V(-0.5194, -0.1257, 0.0360), V(-0.4699, -0.1321, -0.0321), V(-0.5504, -0.1200, -0.0098) },
                Middle = { V(-0.6873, -0.2075, 0.0887), V(-0.6728, -0.2305, -0.0451), V(-0.7724, -0.1807, -0.0748), V(-0.8577, -0.1284, -0.0174) },
                Ring = { V(-0.7413, -0.2623, 0.0895), V(-0.7288, -0.2821, -0.0257), V(-0.8105, -0.2411, -0.0500), V(-0.8806, -0.1983, -0.0029) },
                Pinky = { V(-0.8132, -0.3048, 0.0722), V(-0.8042, -0.3191, -0.0109), V(-0.8632, -0.2896, -0.0284), V(-0.9137, -0.2587, 0.0055) },
            },
            L = {
                Wrist = V(0.5143, -0.0887, -0.1669),
                Thumb = { V(0.6041, 0.0182, -0.1160), V(0.6501, 0.1290, -0.1623), V(0.7411, 0.1629, -0.1508), V(0.8238, 0.2150, -0.1522) },
                Index = { V(0.5804, 0.0732, 0.1175), V(0.6196, 0.1888, 0.1486), V(0.6747, 0.2527, 0.1475), V(0.7583, 0.2410, 0.1477) },
                Middle = { V(0.5000, 0.0400, 0.1191), V(0.5349, 0.1694, 0.1454), V(0.6012, 0.2637, 0.1481), V(0.7042, 0.2119, 0.1466) },
                Ring = { V(0.4276, 0.0357, 0.0934), V(0.4556, 0.1426, 0.1335), V(0.5032, 0.2236, 0.1444), V(0.5910, 0.2588, 0.1492) },
                Pinky = { V(0.3602, 0.0388, 0.0411), V(0.3780, 0.1051, 0.0910), V(0.4070, 0.1625, 0.1139), V(0.4542, 0.2082, 0.1321) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0.2,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.2,
        MagPull = 0.7,
        RecoilKick = { Back = 0.14, Up = 0.02, Pitch = 3.6, Roll = 0.6 },
        Fx = { Flash = "Rifle", Shell = "Rifle" },
        Sounds = "MK11",
        FactoryTint = Color3.new(0.45, 0.45, 0.45),
        NewGun = true,
    },
    BEAM = {
        Asset = "BEAM",
        Class = "Laser",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
            Glow = { Zone = "Glow" },
            MagGlow = { Zone = "Glow" },
        },
        Points = {
            -- (v2 model 2026-10-07, art/weapons/BEAM_v2.blend: the particle cannon; Frame centred where v1's was, so the
            -- grip / trigger / hand points carried over. The lens sits a little behind the emitter's claws.)
            Muzzle = Point(Vector3.new(1.2400, 0.0930, 0.0000)),
            TriggerPivot = Point(Vector3.new(-0.5071, -0.0683, 0.0000)),
            MagWell = Point(Vector3.new(-0.1020, -0.1400, 0.0000)),
            Optic = Point(Vector3.new(-0.0000, 0.6000, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.2400, 0.0930, 0.0000)),
            Charm = Point(Vector3.new(-0.6482, -0.1407, 0.2700)),
        },
        MagAxis = Vector3.new(0.000, 1.000, 0.000),
        GripPose = {
            R = {
                Wrist = V(-0.8873, -0.1088, 0.0909),
                Thumb = { V(-0.7709, -0.0738, 0.0053), V(-0.6742, -0.0943, -0.0768), V(-0.5787, -0.1137, -0.0856), V(-0.4836, -0.1330, -0.0748) },
                Index = { V(-0.5665, -0.1928, 0.0520), V(-0.4426, -0.1751, 0.0382), V(-0.3931, -0.1815, -0.0299), V(-0.4736, -0.1694, -0.0076) },
                Middle = { V(-0.6105, -0.2569, 0.0909), V(-0.5960, -0.2799, -0.0429), V(-0.6956, -0.2301, -0.0726), V(-0.7809, -0.1778, -0.0152) },
                Ring = { V(-0.6645, -0.3117, 0.0917), V(-0.6520, -0.3315, -0.0235), V(-0.7337, -0.2905, -0.0478), V(-0.8038, -0.2477, -0.0007) },
                Pinky = { V(-0.7364, -0.3542, 0.0744), V(-0.7274, -0.3685, -0.0087), V(-0.7864, -0.3390, -0.0262), V(-0.8369, -0.3081, 0.0077) },
            },
            L = {
                Wrist = V(0.5143, -0.1887, -0.1647),
                Thumb = { V(0.6041, -0.0818, -0.1138), V(0.6501, 0.0290, -0.1601), V(0.7411, 0.0629, -0.1486), V(0.8238, 0.1150, -0.1500) },
                Index = { V(0.5804, -0.0268, 0.1197), V(0.6196, 0.0888, 0.1508), V(0.6747, 0.1527, 0.1497), V(0.7583, 0.1410, 0.1499) },
                Middle = { V(0.5000, -0.0600, 0.1213), V(0.5349, 0.0694, 0.1476), V(0.6012, 0.1637, 0.1503), V(0.7042, 0.1119, 0.1488) },
                Ring = { V(0.4276, -0.0643, 0.0956), V(0.4556, 0.0426, 0.1357), V(0.5032, 0.1236, 0.1466), V(0.5910, 0.1588, 0.1514) },
                Pinky = { V(0.3602, -0.0612, 0.0433), V(0.3780, 0.0051, 0.0932), V(0.4070, 0.0625, 0.1161), V(0.4542, 0.1082, 0.1343) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        Beam = true,
        SlideTravel = 0,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.15,
        MagPull = 0.7,
        RecoilKick = { Back = 0.025, Up = 0.006, Pitch = 0.35, Roll = 0.2 },
        Fx = { Flash = "Rifle" },
        Sounds = "BEAM",
        FactoryTint = Color3.new(0.8, 0.8, 0.8), -- (v2: its palette is already dark; v1 needed 0.45)
        NewGun = true,
    },
}) do WeaponRigs.Guns[id] = def end
for id, src in pairs({ M249 = "AK47", PKM = "AK47", M60 = "AK47", HK21 = "AK47", TAR21 = "M4A1", GALIL = "M4A1", HK416 = "M4A1", MP40 = "MP5", PPSH = "MP5", VECTOR = "MP5", USAS12 = "R870", DBARREL = "R870", KSG = "R870", M590 = "R870", USP = "Glock17", P226 = "Glock17", SR9 = "Glock17", PX4 = "Glock17", SVD = "SCOUT", SKS = "SCOUT", M40 = "SCOUT", EMR = "SCOUT", MK11 = "SCOUT", BEAM = "M4A1" }) do
    local name = WeaponRigs.Guns[id].Sounds
    WeaponRigs.Sounds[name] = WeaponRigs.Sounds[name] or WeaponRigs.Sounds[src]
end
-- ===== END NEW GUNS =====

-- ===== BEAM GUNS (tools/beam_guns.py; BEAM GUNS v4 (2026-10-10): Muzzle / MagWell hand-measured on the new Sketchfab models -- keep them if this block is regenerated) =====
for id, def in pairs({
    ContinuousLaser = {
        Asset = "ContinuousLaser",
        Class = "Laser",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
            Glow = { Zone = "Glow" },
        },
        Points = { -- (BEAM GUNS v5: measured on the Arcwright family model, tools/beam5_prep.measure)
            Muzzle = Point(Vector3.new(1.8073, 0.4494, -0.0074)),
            TriggerPivot = Point(Vector3.new(-0.3524, -0.0264, -0.0015)),
            MagWell = Point(Vector3.new(-0.0785, -0.0034, -0.0068)),
            Optic = Point(Vector3.new(0.0000, 0.5852, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.8073, 0.4494, -0.0074)),
            Charm = Point(Vector3.new(-1.2855, 0.3083, 0.0588)),
        },
        MagAxis = Vector3.new(0.000, 1.000, 0.000),
        GripPose = {
            R = {
                Wrist = V(-0.7326, -0.0669, 0.0894),
                Thumb = { V(-0.6162, -0.0319, 0.0038), V(-0.5195, -0.0524, -0.0783), V(-0.4240, -0.0718, -0.0871), V(-0.3289, -0.0911, -0.0763) },
                Index = { V(-0.4118, -0.1509, 0.0505), V(-0.2879, -0.1332, 0.0367), V(-0.2384, -0.1396, -0.0314), V(-0.3189, -0.1275, -0.0091) },
                Middle = { V(-0.4558, -0.2150, 0.0894), V(-0.4413, -0.2380, -0.0444), V(-0.5409, -0.1882, -0.0741), V(-0.6262, -0.1359, -0.0167) },
                Ring = { V(-0.5098, -0.2698, 0.0902), V(-0.4973, -0.2896, -0.0250), V(-0.5790, -0.2486, -0.0493), V(-0.6491, -0.2058, -0.0022) },
                Pinky = { V(-0.5817, -0.3123, 0.0729), V(-0.5727, -0.3266, -0.0102), V(-0.6317, -0.2971, -0.0277), V(-0.6822, -0.2662, 0.0062) },
            },
            L = {
                Wrist = V(0.4857, -0.1004, -0.1662),
                Thumb = { V(0.5755, 0.0065, -0.1153), V(0.6215, 0.1173, -0.1616), V(0.7125, 0.1512, -0.1501), V(0.7952, 0.2033, -0.1515) },
                Index = { V(0.5518, 0.0615, 0.1182), V(0.5910, 0.1771, 0.1493), V(0.6461, 0.2410, 0.1482), V(0.7297, 0.2293, 0.1484) },
                Middle = { V(0.4714, 0.0283, 0.1198), V(0.5063, 0.1577, 0.1461), V(0.5726, 0.2520, 0.1488), V(0.6756, 0.2002, 0.1473) },
                Ring = { V(0.3990, 0.0240, 0.0941), V(0.4270, 0.1309, 0.1342), V(0.4746, 0.2119, 0.1451), V(0.5624, 0.2471, 0.1499) },
                Pinky = { V(0.3316, 0.0271, 0.0418), V(0.3494, 0.0934, 0.0917), V(0.3784, 0.1508, 0.1146), V(0.4256, 0.1965, 0.1328) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        Beam = true,
        SlideTravel = 0,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.15,
        MagPull = 0.7,
        RecoilKick = { Back = 0.025, Up = 0.006, Pitch = 0.35, Roll = 0.2 },
        Fx = { Flash = "Rifle" },
        Sounds = "BEAM",
        FactoryTint = Color3.new(0.9, 0.9, 0.9),
        NewGun = true,
    },
    QuadBeam = {
        Asset = "QuadBeam",
        Class = "Laser",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" }, -- (0.97 gun check: a power cell cloned from the ContinuousLaser -- its reload was an empty hand)
            Trigger = { Zone = "Metal" },
            Glow = { Zone = "Glow" },
        },
        Points = { -- (BEAM GUNS v5: measured on the Arcwright family model, tools/beam5_prep.measure)
            MagWell = Point(Vector3.new(0.2769, 0.0366, 0.0000)),
            Muzzle = Point(Vector3.new(1.9598, 0.1300, 0.0000)),
            TriggerPivot = Point(Vector3.new(-0.1448, -0.0702, 0.0000)),
            Optic = Point(Vector3.new(0.2200, 0.3541, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.9598, 0.1300, 0.0000)),
            Charm = Point(Vector3.new(-0.7760, -0.0188, 0.0797)),
        },
        GripPose = {
            R = {
                Wrist = V(-0.5381, -0.1641, 0.0901),
                Thumb = { V(-0.4323, -0.1043, 0.0045), V(-0.3334, -0.1030, -0.0776), V(-0.2360, -0.1010, -0.0864), V(-0.1389, -0.0988, -0.0756) },
                Index = { V(-0.2066, -0.1753, 0.0511), V(-0.0897, -0.1308, 0.0374), V(-0.0400, -0.1262, -0.0307), V(-0.1212, -0.1321, -0.0084) },
                Middle = { V(-0.2354, -0.2476, 0.0901), V(-0.2162, -0.2669, -0.0438), V(-0.3243, -0.2401, -0.0734), V(-0.4191, -0.2079, -0.0160) },
                Ring = { V(-0.2761, -0.3129, 0.0909), V(-0.2595, -0.3295, -0.0244), V(-0.3483, -0.3075, -0.0487), V(-0.4261, -0.2812, -0.0015) },
                Pinky = { V(-0.3369, -0.3703, 0.0736), V(-0.3249, -0.3822, -0.0095), V(-0.3890, -0.3664, -0.0271), V(-0.4450, -0.3473, 0.0069) },
            },
            L = {
                Wrist = V(0.4814, -0.2055, -0.1810),
                Thumb = { V(0.5712, -0.0986, -0.1302), V(0.6113, 0.0115, -0.0771), V(0.6988, 0.0547, -0.0828), V(0.7958, 0.0667, -0.0828) },
                Index = { V(0.5475, -0.0435, 0.1034), V(0.5869, 0.0688, 0.1444), V(0.6710, 0.0617, 0.1418), V(0.7522, 0.0833, 0.1497) },
                Middle = { V(0.4671, -0.0768, 0.1050), V(0.5013, 0.0509, 0.1392), V(0.6131, 0.0784, 0.1466), V(0.5403, -0.0079, 0.1234) },
                Ring = { V(0.3947, -0.0811, 0.0793), V(0.4219, 0.0237, 0.1250), V(0.4989, 0.0742, 0.1471), V(0.5882, 0.0455, 0.1346) },
                Pinky = { V(0.3273, -0.0780, 0.0270), V(0.3445, -0.0135, 0.0794), V(0.3843, 0.0294, 0.1143), V(0.4432, 0.0562, 0.1361) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        Beam = true,
        SlideTravel = 0,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.15,
        MagPull = 0.7,
        RecoilKick = { Back = 0.025, Up = 0.006, Pitch = 0.35, Roll = 0.2 },
        Fx = { Flash = "Rifle" },
        Sounds = "BEAM",
        FactoryTint = Color3.new(0.9, 0.9, 0.9),
        NewGun = true,
    },
    Railgun = {
        Asset = "Railgun",
        Class = "Laser",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
            Glow = { Zone = "Glow" },
        },
        Points = { -- (BEAM GUNS v5 pilot: measured on the coil-chamber model -- muzzle = the charge rod's tip between the
            -- rails, mag well = the top of the twin cells under the core)
            Muzzle = Point(Vector3.new(2.1900, 0.2690, 0.0000)),
            TriggerPivot = Point(Vector3.new(-1.0500, 0.0000, 0.0000)),
            MagWell = Point(Vector3.new(-0.1075, 0.0510, -0.0020)),
            Optic = Point(Vector3.new(-0.4000, 0.5900, 0.0000)),
            MuzzleDevice = Point(Vector3.new(2.1900, 0.2690, 0.0000)),
            Charm = Point(Vector3.new(-1.3000, -0.1000, 0.1800)),
        },
        MagAxis = Vector3.new(0.002, 1.000, -0.000),
        GripPose = {
            R = {
                Wrist = V(-1.4438, -0.1650, 0.0888),
                Thumb = { V(-1.3380, -0.1052, 0.0032), V(-1.2391, -0.1039, -0.0789), V(-1.1417, -0.1019, -0.0877), V(-1.0446, -0.0997, -0.0769) },
                Index = { V(-1.1123, -0.1762, 0.0498), V(-0.9954, -0.1317, 0.0361), V(-0.9457, -0.1271, -0.0320), V(-1.0269, -0.1330, -0.0097) },
                Middle = { V(-1.1411, -0.2485, 0.0888), V(-1.1219, -0.2678, -0.0451), V(-1.2300, -0.2410, -0.0747), V(-1.3248, -0.2088, -0.0173) },
                Ring = { V(-1.1818, -0.3138, 0.0896), V(-1.1652, -0.3304, -0.0257), V(-1.2540, -0.3084, -0.0500), V(-1.3318, -0.2821, -0.0028) },
                Pinky = { V(-1.2426, -0.3712, 0.0723), V(-1.2306, -0.3831, -0.0108), V(-1.2947, -0.3673, -0.0284), V(-1.3507, -0.3482, 0.0056) },
            },
            L = {
                Wrist = V(0.1661, -0.2118, -0.2276),
                Thumb = { V(0.2559, -0.1049, -0.1767), V(0.2919, -0.0181, -0.0888), V(0.3760, 0.0318, -0.0895), V(0.4598, 0.0821, -0.0896) },
                Index = { V(0.2322, -0.0498, 0.0569), V(0.2713, 0.0657, 0.0880), V(0.3440, 0.1087, 0.0865), V(0.4168, 0.0658, 0.0880) },
                Middle = { V(0.1518, -0.0831, 0.0585), V(0.1867, 0.0463, 0.0848), V(0.2723, 0.1235, 0.0882), V(0.3229, 0.0199, 0.0836) },
                Ring = { V(0.0793, -0.0874, 0.0328), V(0.1073, 0.0195, 0.0729), V(0.1663, 0.0923, 0.0864), V(0.2607, 0.0986, 0.0876) },
                Pinky = { V(0.0120, -0.0842, -0.0195), V(0.0298, -0.0180, 0.0304), V(0.0634, 0.0351, 0.0569), V(0.1163, 0.0737, 0.0761) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.15,
        MagPull = 0.7,
        RecoilKick = { Back = 0.2, Up = 0.02, Pitch = 6.0, Roll = 0.6 },
        Fx = { Flash = "Rifle" },
        Sounds = "BEAM",
        FactoryTint = Color3.new(0.9, 0.9, 0.9),
        NewGun = true,
    },
    PlasmaCannon = {
        Asset = "PlasmaCannon",
        Class = "Laser",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
            Glow = { Zone = "Glow" },
        },
        Points = { -- (BEAM GUNS v5: measured on the Arcwright family model, tools/beam5_prep.measure)
            Muzzle = Point(Vector3.new(2.0398, 0.0797, 0.0000)),
            TriggerPivot = Point(Vector3.new(-0.8438, -0.1102, -0.0004)),
            MagWell = Point(Vector3.new(-1.1467, -0.0272, 0.0000)),
            Optic = Point(Vector3.new(-0.4900, 0.6016, 0.0000)),
            MuzzleDevice = Point(Vector3.new(2.0398, 0.0797, 0.0000)),
            Charm = Point(Vector3.new(-1.9135, -0.0669, 0.2720)),
        },
        MagAxis = Vector3.new(0.000, 1.000, 0.000),
        GripPose = {
            R = {
                Wrist = V(-1.2371, -0.2041, 0.0897),
                Thumb = { V(-1.1313, -0.1443, 0.0041), V(-1.0324, -0.1430, -0.0780), V(-0.9350, -0.1410, -0.0868), V(-0.8379, -0.1388, -0.0760) },
                Index = { V(-0.9056, -0.2153, 0.0507), V(-0.7887, -0.1708, 0.0370), V(-0.7390, -0.1662, -0.0311), V(-0.8202, -0.1721, -0.0088) },
                Middle = { V(-0.9344, -0.2876, 0.0897), V(-0.9152, -0.3069, -0.0442), V(-1.0233, -0.2801, -0.0738), V(-1.1181, -0.2479, -0.0164) },
                Ring = { V(-0.9751, -0.3529, 0.0905), V(-0.9585, -0.3695, -0.0248), V(-1.0473, -0.3475, -0.0491), V(-1.1251, -0.3212, -0.0019) },
                Pinky = { V(-1.0359, -0.4103, 0.0732), V(-1.0239, -0.4222, -0.0099), V(-1.0880, -0.4064, -0.0275), V(-1.1440, -0.3873, 0.0065) },
            },
            L = {
                Wrist = V(0.4590, -0.2188, -0.2266),
                Thumb = { V(0.5489, -0.1119, -0.1757), V(0.5850, -0.0249, -0.0880), V(0.6690, 0.0249, -0.0888), V(0.7529, 0.0752, -0.0889) },
                Index = { V(0.5252, -0.0568, 0.0579), V(0.5643, 0.0587, 0.0890), V(0.6195, 0.1226, 0.0879), V(0.7031, 0.1110, 0.0881) },
                Middle = { V(0.4447, -0.0901, 0.0595), V(0.4797, 0.0393, 0.0858), V(0.5459, 0.1337, 0.0885), V(0.6490, 0.0819, 0.0870) },
                Ring = { V(0.3723, -0.0944, 0.0338), V(0.4003, 0.0125, 0.0739), V(0.4480, 0.0935, 0.0848), V(0.5357, 0.1287, 0.0896) },
                Pinky = { V(0.3050, -0.0912, -0.0185), V(0.3227, -0.0250, 0.0314), V(0.3517, 0.0324, 0.0543), V(0.3990, 0.0781, 0.0725) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.15,
        MagPull = 0.7,
        RecoilKick = { Back = 0.12, Up = 0.02, Pitch = 2.6, Roll = 0.6 },
        Fx = { Flash = "Rifle" },
        Sounds = "BEAM",
        FactoryTint = Color3.new(0.9, 0.9, 0.9),
        NewGun = true,
    },
    VoidDisintegrator = {
        Asset = "VoidDisintegrator",
        Class = "Laser",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
            Glow = { Zone = "Glow" },
        },
        Points = { -- (BEAM GUNS v5: measured on the Arcwright family model, tools/beam5_prep.measure)
            Muzzle = Point(Vector3.new(2.0228, 0.0798, 0.0000)),
            TriggerPivot = Point(Vector3.new(0.1999, -0.0105, -0.0012)),
            MagWell = Point(Vector3.new(0.5306, -0.0876, 0.0000)),
            Optic = Point(Vector3.new(0.5700, 0.3927, 0.0000)),
            MuzzleDevice = Point(Vector3.new(2.0228, 0.0798, 0.0000)),
            Charm = Point(Vector3.new(-0.4387, 0.1021, 0.0734)),
        },
        MagAxis = Vector3.new(0.000, 1.000, 0.000),
        GripPose = {
            R = {
                Wrist = V(-0.1579, -0.0839, 0.0881),
                Thumb = { V(-0.0474, -0.0335, 0.0025), V(0.0512, -0.0407, -0.0796), V(0.1484, -0.0471, -0.0884), V(0.2453, -0.0533, -0.0776) },
                Index = { V(0.1713, -0.1237, 0.0492), V(0.2916, -0.0894, 0.0354), V(0.3415, -0.0891, -0.0327), V(0.2601, -0.0880, -0.0104) },
                Middle = { V(0.1364, -0.1932, 0.0881), V(0.1539, -0.2140, -0.0457), V(0.0484, -0.1781, -0.0754), V(-0.0432, -0.1379, -0.0180) },
                Ring = { V(0.0902, -0.2548, 0.0889), V(0.1053, -0.2728, -0.0263), V(0.0188, -0.2432, -0.0506), V(-0.0564, -0.2103, -0.0035) },
                Pinky = { V(0.0248, -0.3067, 0.0716), V(0.0357, -0.3196, -0.0115), V(-0.0268, -0.2983, -0.0290), V(-0.0810, -0.2745, 0.0049) },
            },
            L = {
                Wrist = V(0.2916, -0.0466, -0.1046),
                Thumb = { V(0.3903, 0.0312, -0.0253), V(0.5010, 0.0003, 0.0324), V(0.5919, -0.0130, 0.0660), V(0.6888, -0.0247, 0.0718) },
                Index = { V(0.6224, -0.0154, -0.0713), V(0.6327, -0.0207, 0.0540), V(0.5495, -0.0084, 0.0614), V(0.4907, 0.0022, 0.0017) },
                Middle = { V(0.6021, -0.0932, -0.1046), V(0.6133, -0.0989, 0.0313), V(0.4996, -0.0822, 0.0414), V(0.4193, -0.0677, -0.0401) },
                Ring = { V(0.5696, -0.1628, -0.1002), V(0.5792, -0.1677, 0.0168), V(0.4859, -0.1540, 0.0250), V(0.4200, -0.1421, -0.0419) },
                Pinky = { V(0.5163, -0.2256, -0.0779), V(0.5233, -0.2292, 0.0065), V(0.4560, -0.2193, 0.0124), V(0.4085, -0.2107, -0.0358) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        SlideTravel = 0,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.15,
        MagPull = 0.7,
        RecoilKick = { Back = 0.1, Up = 0.02, Pitch = 2.2, Roll = 0.6 },
        Fx = { Flash = "Rifle" },
        Sounds = "BEAM",
        FactoryTint = Color3.new(0.9, 0.9, 0.9),
        NewGun = true,
    },
    SparkPistol = {
        Asset = "SparkPistol",
        Class = "Pistol",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
            Glow = { Zone = "Glow" },
        },
        Points = { -- (BEAM GUNS v5: measured on the Arcwright family model, tools/beam5_prep.measure)
            Muzzle = Point(Vector3.new(0.5495, 0.0895, -0.0003)),
            TriggerPivot = Point(Vector3.new(-0.1011, 0.0613, 0.0003)),
            MagWell = Point(Vector3.new(0.0650, -0.0165, -0.0001)),
            Optic = Point(Vector3.new(0.2500, 0.2554, 0.0000)),
            MuzzleDevice = Point(Vector3.new(0.5495, 0.0895, -0.0003)),
            Charm = Point(Vector3.new(-0.0433, 0.0085, 0.1221)),
        },
        MagAxis = Vector3.new(0.000, 1.000, 0.000),
        GripPose = {
            R = {
                Wrist = V(-0.4499, -0.0358, 0.0891),
                Thumb = { V(-0.3428, 0.0216, 0.0035), V(-0.2439, 0.0207, -0.0786), V(-0.1465, 0.0206, -0.0874), V(-0.0494, 0.0206, -0.0766) },
                Index = { V(-0.1188, -0.0544, 0.0502), V(-0.0009, -0.0125, 0.0364), V(0.0489, -0.0090, -0.0317), V(-0.0324, -0.0131, -0.0094) },
                Middle = { V(-0.1492, -0.1260, 0.0891), V(-0.1304, -0.1457, -0.0447), V(-0.2379, -0.1166, -0.0744), V(-0.3319, -0.0823, -0.0170) },
                Ring = { V(-0.1913, -0.1904, 0.0899), V(-0.1751, -0.2074, -0.0253), V(-0.2633, -0.1834, -0.0496), V(-0.3405, -0.1554, -0.0025) },
                Pinky = { V(-0.2533, -0.2464, 0.0726), V(-0.2416, -0.2586, -0.0105), V(-0.3053, -0.2414, -0.0280), V(-0.3609, -0.2211, 0.0059) },
            },
            L = {
                Wrist = V(-0.3956, -0.2265, -0.1791),
                Thumb = { V(-0.3587, -0.1042, -0.1031), V(-0.2517, -0.0328, -0.1023), V(-0.1552, -0.0176, -0.1022), V(-0.0582, -0.0177, -0.0900) },
                Index = { V(-0.1291, -0.0333, -0.1228), V(-0.0945, -0.0084, -0.0043), V(-0.1576, -0.0269, 0.0486), V(-0.2360, -0.0553, 0.0619) },
                Middle = { V(-0.1045, -0.1133, -0.1468), V(-0.0779, -0.0900, -0.0149), V(-0.1694, -0.1182, 0.0494), V(-0.2772, -0.1581, 0.0576) },
                Ring = { V(-0.0998, -0.1893, -0.1356), V(-0.0768, -0.1692, -0.0221), V(-0.1519, -0.1923, 0.0306), V(-0.2404, -0.2251, 0.0373) },
                Pinky = { V(-0.1187, -0.2683, -0.1095), V(-0.1021, -0.2538, -0.0276), V(-0.1562, -0.2705, 0.0104), V(-0.2201, -0.2941, 0.0152) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        SlideTravel = 0,
        NoBoltLock = true,
        TriggerAngle = -16,
        MagPull = 0.34,
        MagHoldOffset = 0.06,
        RecoilKick = { Back = 0.1, Up = 0.03, Pitch = 6, Roll = 1.5 },
        Fx = { Flash = "Pistol" },
        Sounds = "BEAM",
        FactoryTint = Color3.new(0.9, 0.9, 0.9),
        NewGun = true,
    },
    BEAM = {
        Asset = "BEAM",
        Class = "Laser",
        Scale = 1.12,
        Parts = {
            Frame = { Zone = "Frame" },
            Magazine = { Zone = "Magazine" },
            Trigger = { Zone = "Metal" },
            Glow = { Zone = "Glow" },
        },
        Points = { -- (BEAM GUNS v5: measured on the Arcwright family model, tools/beam5_prep.measure)
            Muzzle = Point(Vector3.new(1.7188, 0.3348, 0.0000)),
            TriggerPivot = Point(Vector3.new(-0.1066, 0.0720, 0.0007)),
            MagWell = Point(Vector3.new(0.5501, 0.1411, 0.0000)),
            Optic = Point(Vector3.new(0.2600, 0.7914, 0.0000)),
            MuzzleDevice = Point(Vector3.new(1.7188, 0.3348, 0.0000)),
            Charm = Point(Vector3.new(-1.2018, 0.2140, 0.1000)),
        },
        MagAxis = Vector3.new(0.000, 1.000, 0.000),
        GripPose = {
            R = {
                Wrist = V(-0.4440, -0.0064, 0.1007),
                Thumb = { V(-0.3493, 0.0697, 0.0151), V(-0.2518, 0.0871, -0.0670), V(-0.1561, 0.1049, -0.0758), V(-0.0607, 0.1229, -0.0650) },
                Index = { V(-0.1151, 0.0364, 0.0618), V(-0.0069, 0.0993, 0.0480), V(0.0414, 0.1119, -0.0201), V(-0.0378, 0.0929, 0.0022) },
                Middle = { V(-0.1318, -0.0396, 0.1007), V(-0.1097, -0.0556, -0.0331), V(-0.2208, -0.0468, -0.0628), V(-0.3194, -0.0304, -0.0054) },
                Ring = { V(-0.1612, -0.1107, 0.1015), V(-0.1422, -0.1244, -0.0137), V(-0.2334, -0.1171, -0.0380), V(-0.3144, -0.1038, 0.0091) },
                Pinky = { V(-0.2119, -0.1772, 0.0842), V(-0.1981, -0.1870, 0.0011), V(-0.2639, -0.1819, -0.0164), V(-0.3223, -0.1722, 0.0175) },
            },
            L = {
                Wrist = V(0.3438, -0.1662, -0.0965),
                Thumb = { V(0.4425, -0.0884, -0.0171), V(0.5533, -0.1192, 0.0406), V(0.6441, -0.1325, 0.0741), V(0.7410, -0.1443, 0.0800) },
                Index = { V(0.6746, -0.1350, -0.0632), V(0.6849, -0.1403, 0.0622), V(0.6017, -0.1280, 0.0695), V(0.5429, -0.1174, 0.0099) },
                Middle = { V(0.6543, -0.2128, -0.0965), V(0.6655, -0.2185, 0.0395), V(0.5518, -0.2018, 0.0495), V(0.4715, -0.1873, -0.0320) },
                Ring = { V(0.6218, -0.2824, -0.0921), V(0.6314, -0.2873, 0.0249), V(0.5381, -0.2736, 0.0332), V(0.4723, -0.2617, -0.0337) },
                Pinky = { V(0.5686, -0.3452, -0.0698), V(0.5755, -0.3488, 0.0146), V(0.5083, -0.3389, 0.0206), V(0.4607, -0.3303, -0.0277) },
            },
        },
        Hold = { Angles = Vector3.new(0, -5, 0) },
        AnimKind = "Rifle",
        Beam = true,
        SlideTravel = 0,
        NoBoltLock = true,
        TriggerAngle = -18,
        MagHoldOffset = 0.15,
        MagPull = 0.7,
        RecoilKick = { Back = 0.025, Up = 0.006, Pitch = 0.35, Roll = 0.2 },
        Fx = { Flash = "Rifle" },
        Sounds = "BEAM",
        FactoryTint = Color3.new(0.9, 0.9, 0.9),
        NewGun = true,
    },
}) do WeaponRigs.Guns[id] = def end
-- (BEAM GUNS v5, owner: "replace the orange rifle muzzle flash on beam guns with an energy flash that matches the
-- family"): every Arcwright gun fires an ENERGY flash -- short, in the beam colour, no smoke, matching light + tracer
-- (ViewmodelRig BuildEffects / SetProcFx / MuzzleFlash read def.Energy)
for _, id in ipairs({ "Railgun", "ContinuousLaser", "PlasmaCannon", "QuadBeam", "SparkPistol", "VoidDisintegrator", "BEAM" }) do
    if WeaponRigs.Guns[id] then WeaponRigs.Guns[id].Energy = true end
end
-- ===== END BEAM GUNS =====

-- ==================== ANIMATIONS ====================
-- Channels (all optional; missing = rest):
--   Gun       CFrame   offset applied to the held gun, in camera space around the grip
--   Slide     number   0 = forward, 1 = fully back
--   Trigger   number   0 = rest, 1 = pulled
--   Mag       CFrame   magazine offset in gun space (from its seated position)
--   MagHand   number   1 = the magazine rides in the left hand (at the hand's palm) instead of the gun
--   MagShow   number   0 hides the magazine (dropped / out of view)
--   LHand     number   0 = left hand on GripL, 1 = left hand at LFree
--   LFree     CFrame   free left-hand target in gun space (a hand point: X = palm facing, Y = knuckle line)
--   LFollowMag number  1 = the left hand rides on the magazine wherever it is (grabbing / seating it)
--   RHandPose / LHandPose  string  hand shape name (Arms.Hands)
-- Keys: { t, value, ease? } (ease: "Linear" | "In" | "Out" | "InOut" | "Step"; default InOut).
-- Events: { t, name } -- sounds (Sounds[name]) and "Eject" (shell), "SlideLockRelease".
local CF = CFrame.new
local ANG = CFrame.Angles
local R = math.rad

local MAG_OUT = CF(-GLOCK_MAG_UP.Unit * 0.42)            -- slid out along the magazine's own (raked) axis
local MAG_PARTWAY = CF(-GLOCK_MAG_UP.Unit * 0.18)
local MAG_DROP = CF(-0.35, -2.2, 0.1) * ANG(0, 0, R(25))  -- empty mag falls away

-- The left hand's free targets (gun-space hand points: X = where the palm faces, Y = knuckle line).
local LH_BELOW_WELL = Point(Vector3.new(-0.31, -0.57, 0), Vector3.zAxis, GLOCK_MAG_UP)   -- new mag lined up under the grip
local LH_AT_BELT = Point(Vector3.new(-0.60, -1.40, -0.50), Vector3.zAxis, GLOCK_MAG_UP)  -- off-screen, at the mag pouch

-- Reload pose: the gun comes up and in, canted, so the magazine well is on screen.
local RELOAD_POSE = CF(-0.45, 0.74, 0.15) * ANG(R(30), R(24), R(-46))
local RELOAD_SLIDE_POSE = CF(-0.22, 0.24, 0.02) * ANG(R(8), R(12), R(-18))

local PistolAnims = {
    Equip = {
        Length = 0.55,
        Tracks = {
            Gun = { { 0, CF(0.25, -0.9, 0.35) * ANG(R(-55), R(20), R(35)) }, { 0.32, CF(0, 0.03, -0.015) * ANG(R(6), 0, R(-5)), "Out" },
                    { 0.44, CF(0, -0.008, 0) * ANG(R(-1.5), 0, R(1)) }, { 0.55, CF() } },
            LHand = { { 0, 1 }, { 0.30, 1 }, { 0.50, 0 } },
            LFree = { { 0, LH_AT_BELT } },
            RHandPose = { { 0, "PistolGrip" } },
            LHandPose = { { 0, "Open" }, { 0.45, "Support" } },
        },
        Events = { { 0.05, "Equip" } },
    },
    Fire = {
        Length = 0.16,
        Tracks = {
            Slide = { { 0, 0 }, { 0.035, 1, "Out" }, { 0.10, 0, "In" } },
            Trigger = { { 0, 1 }, { 0.08, 0 } },
        },
        Events = { { 0.03, "Eject" } },
    },
    Reload = {
        Length = 1.45,
        Tracks = {
            Gun = { { 0, CF() }, { 0.20, RELOAD_POSE }, { 1.02, RELOAD_POSE }, { 1.08, RELOAD_POSE * CF(0, 0.03, 0) }, { 1.20, RELOAD_POSE }, { 1.45, CF() } },
            LHand = { { 0, 0 }, { 0.14, 1 }, { 1.25, 1 }, { 1.42, 0 } },
            LFree = { { 0, LH_BELOW_WELL }, { 0.46, LH_BELOW_WELL }, { 0.56, LH_AT_BELT }, { 0.60, LH_AT_BELT }, { 0.74, LH_BELOW_WELL } },
            LFollowMag = { { 0, 0 }, { 0.10, 0 }, { 0.18, 1 }, { 0.36, 1 }, { 0.46, 0 }, { 0.80, 0 }, { 0.90, 1 }, { 1.06, 1 }, { 1.18, 0 } },
            Mag = { { 0, CF() }, { 0.20, CF() }, { 0.34, MAG_OUT, "Out" }, { 0.86, MAG_OUT }, { 0.94, MAG_PARTWAY }, { 1.02, CF(), "In" } },
            MagHand = { { 0, 0 }, { 0.36, 1, "Step" }, { 0.88, 0, "Step" } },
            LHandPose = { { 0, "Support" }, { 0.12, "Open" }, { 0.20, "HoldMag" }, { 1.04, "HoldMag" }, { 1.12, "Open" }, { 1.38, "Support" } },
        },
        Events = { { 0.26, "MagOut" }, { 1.00, "MagIn" } },
    },
    ReloadEmpty = {
        Length = 1.65,
        Tracks = {
            -- after seating the mag the support hand returns and its thumb drops the slide release
            Gun = { { 0, CF() }, { 0.20, RELOAD_POSE }, { 1.02, RELOAD_POSE }, { 1.08, RELOAD_POSE * CF(0, 0.03, 0) }, { 1.24, RELOAD_SLIDE_POSE }, { 1.30, RELOAD_SLIDE_POSE * CF(0, -0.03, 0.03) }, { 1.65, CF() } },
            Slide = { { 0, 1 }, { 1.27, 1 }, { 1.31, 0, "In" } },
            LHand = { { 0, 0 }, { 0.16, 1 }, { 1.12, 1 }, { 1.24, 0 } },
            LFree = { { 0, LH_BELOW_WELL }, { 0.16, LH_BELOW_WELL }, { 0.40, LH_AT_BELT }, { 0.52, LH_AT_BELT }, { 0.72, LH_BELOW_WELL } },
            LFollowMag = { { 0, 0 }, { 0.80, 0 }, { 0.90, 1 }, { 1.06, 1 }, { 1.16, 0 } },
            Mag = { { 0, CF() }, { 0.18, CF() }, { 0.34, MAG_DROP, "In" }, { 0.40, MAG_OUT, "Step" }, { 0.86, MAG_OUT }, { 0.94, MAG_PARTWAY }, { 1.02, CF(), "In" } },
            MagHand = { { 0, 0 }, { 0.52, 1, "Step" }, { 0.88, 0, "Step" } },
            MagShow = { { 0, 1 }, { 0.36, 0, "Step" }, { 0.52, 1, "Step" } },
            LHandPose = { { 0, "Support" }, { 0.12, "Open" }, { 0.52, "HoldMag" }, { 1.04, "HoldMag" }, { 1.12, "Open" }, { 1.22, "Support" } },
        },
        Events = { { 0.22, "MagOut" }, { 1.00, "MagIn" }, { 1.28, "SlideRelease" } },
    },
    Inspect = {
        Length = 2.6,
        Tracks = {
            Gun = {
                { 0, CF() },
                { 0.45, CF(-0.25, 0.12, 0.25) * ANG(R(8), R(35), R(-65)) },
                { 1.20, CF(-0.25, 0.12, 0.25) * ANG(R(8), R(30), R(-60)) },
                { 1.65, CF(-0.10, 0.05, 0.15) * ANG(R(-10), R(-40), R(30)) },
                { 2.20, CF(-0.10, 0.05, 0.15) * ANG(R(-10), R(-35), R(25)) },
                { 2.60, CF() },
            },
            LHand = { { 0, 0 }, { 0.25, 1 }, { 2.35, 1 }, { 2.6, 0 } },
            LFree = { { 0, LH_AT_BELT } },
            LHandPose = { { 0, "Support" }, { 0.25, "Open" }, { 2.4, "Support" } },
        },
        Events = {},
    },
}
WeaponRigs.Guns.Glock17.Anims = PistolAnims
WeaponRigs.PistolAnims = PistolAnims

-- Long-gun set, built per gun from its magazine (MagWell point + MagAxis), so every rifle reloads its own
-- magazine along its own angle. Hands: the left hand rides the magazine (LFollowMag) while it moves, goes
-- to the belt for a fresh one, and returns to the posed grip; the right hand never leaves the grip.
local function RifleAnims(def)
    local axis = (def.MagAxis or Vector3.yAxis).Unit
    -- (0.62: a gun with no magazine -- the beam guns' cells -- reloads round a point just ahead of the trigger; the hand
    -- still goes to the belt and back, a cell swap. A missing MagWell used to stop this whole module loading.)
    local wellP = def.Points.MagWell
    local trig = def.Points.TriggerPivot
    local well = wellP and wellP.Position or ((trig and trig.Position or Vector3.zero) + Vector3.new(0.35, -0.15, 0))
    local magOut = CF(-axis * (def.MagPull or 0.75))          -- pulled straight out along the magazine
    local magPart = CF(-axis * 0.25)
    local magDrop = CF(-0.3, -2.4, -0.2) * ANG(0, 0, R(30))  -- empty one falls away
    local belt = Point(well + Vector3.new(-0.5, -1.6, -0.7), Vector3.zAxis, axis)
    local pose = def.ReloadPose or (CF(-0.12, 0.22, 0.05) * ANG(R(14), R(12), R(-28)))
    local function reload(len, empty)
        local s = len / 2.0 -- authored at 2.0 s
        local function T(t) return t * s end
        local tr = {
            Gun = { { 0, CF() }, { T(0.25), pose }, { T(1.48), pose }, { T(1.55), pose * CF(0, 0.05, 0) }, { T(1.66), pose }, { T(1.96), CF() } },
            LHand = { { 0, 0 }, { T(0.62), 0 }, { T(0.76), 1 }, { T(1.24), 1 }, { T(1.25), 0, "Step" } },
            LFree = { { 0, belt } },
            LFollowMag = { { 0, 0 }, { T(0.06), 0 }, { T(0.28), 1 }, { T(0.62), 1 }, { T(0.74), 0 }, { T(1.04), 0 }, { T(1.24), 1 }, { T(1.60), 1 }, { T(1.84), 0 } },
            Mag = { { 0, CF() }, { T(0.32), CF() }, { T(0.56), magOut, "Out" }, { T(1.24), magOut }, { T(1.36), magPart }, { T(1.50), CF(), "In" } },
            MagHand = { { 0, 0 }, { T(0.60), 1, "Step" }, { T(1.24), 0, "Step" } },
            MagShow = { { 0, 1 }, { T(0.84), 0, "Step" }, { T(0.96), 1, "Step" } },
            LHandPose = { { 0, "Support" }, { T(0.22), "HoldMag" }, { T(1.62), "HoldMag" }, { T(1.84), "Support" } },
        }
        local ev = { { T(0.40), "MagOut" }, { T(1.49), "MagIn" } }
        if empty then
            -- empty: the spent magazine just drops, a fresh one comes from the belt, then the bolt is released
            tr.LFollowMag = { { 0, 0 }, { T(1.04), 0 }, { T(1.24), 1 }, { T(1.60), 1 }, { T(1.84), 0 } }
            tr.LHand = { { 0, 0 }, { T(0.12), 1 }, { T(1.24), 1 }, { T(1.25), 0, "Step" } }
            tr.Mag = { { 0, CF() }, { T(0.20), CF() }, { T(0.42), magDrop, "In" }, { T(0.50), magOut, "Step" }, { T(1.24), magOut }, { T(1.36), magPart }, { T(1.50), CF(), "In" } }
            tr.MagHand = { { 0, 0 }, { T(0.50), 1, "Step" }, { T(1.24), 0, "Step" } }
            tr.MagShow = { { 0, 1 }, { T(0.44), 0, "Step" }, { T(0.80), 1, "Step" } }
            tr.Slide = { { 0, 1 }, { T(1.72), 1 }, { T(1.78), 0, "In" } }
            tr.Gun = { { 0, CF() }, { T(0.25), pose }, { T(1.48), pose }, { T(1.55), pose * CF(0, 0.05, 0) }, { T(1.66), pose }, { T(1.76), pose * ANG(R(-4), 0, R(-6)) }, { T(1.84), pose }, { T(2.0), CF() } }
            ev = { { T(0.24), "MagOut" }, { T(1.49), "MagIn" }, { T(1.76), "SlideRelease" } }
        end
        return { Length = len, Tracks = tr, Events = ev }
    end
    return {
        Equip = {
            Length = 0.6,
            Tracks = {
                -- swung up, overshoots a touch past the hold, settles (0.48: weight on the draw)
                Gun = { { 0, CF(0.3, -1.1, 0.4) * ANG(R(-40), R(25), R(30)) }, { 0.36, CF(0, 0.035, -0.02) * ANG(R(5), R(-2), R(-4)), "Out" },
                        { 0.5, CF(0, -0.01, 0.005) * ANG(R(-1.5), 0, R(1)) }, { 0.6, CF() } },
                LHand = { { 0, 1 }, { 0.3, 1 }, { 0.55, 0 } },
                LFree = { { 0, belt } },
                LHandPose = { { 0, "Open" }, { 0.5, "Support" } },
            },
            Events = { { 0.05, "Equip" } },
        },
        Fire = {
            Length = 0.1,
            Tracks = {
                Slide = { { 0, 0 }, { 0.025, 1, "Out" }, { 0.075, 0, "In" } },
                Trigger = { { 0, 1 }, { 0.06, 0 } },
            },
            Events = { { 0.02, "Eject" } },
        },
        Reload = reload(2.0, false),
        ReloadEmpty = reload(2.3, true),
        Inspect = {
            Length = 2.4,
            Tracks = {
                -- both hands stay on (the posed grip rides along): roll it to show the right side, then the left
                Gun = {
                    { 0, CF() },
                    { 0.45, CF(-0.1, 0.1, -0.35) * ANG(R(4), R(10), R(-30)) },
                    { 1.10, CF(-0.1, 0.1, -0.35) * ANG(R(4), R(8), R(-27)) },
                    { 1.55, CF(0.0, 0.05, -0.3) * ANG(R(-6), R(-8), R(22)) },
                    { 2.05, CF(0.0, 0.05, -0.3) * ANG(R(-6), R(-6), R(20)) },
                    { 2.40, CF() },
                },
            },
            Events = {},
        },
    }
end
WeaponRigs.RifleAnims = RifleAnims
for _, g in pairs(WeaponRigs.Guns) do
    if (g.Class == "Rifle" or g.Class == "SMG") and not g.Anims then g.Anims = RifleAnims(g) end
end


-- ==================== SHOTGUNS + SNIPERS ====================
-- Tube-fed shotguns load shell by shell through the loading port (Points.LoadPort) with the support hand;
-- the game refills the whole tube at once, so the animation just shows a few loads and is time-scaled to the
-- weapon's ReloadTime like every reload.
local function ShellLoads(tr, ev, port, t0, count, step, top)
    local belt = Point(port.Position + Vector3.new(-0.2, -1.3, -0.6), Vector3.yAxis, Vector3.xAxis)
    local s = top and -1 or 1 -- top = loaded from above (stripper clips): the hand comes down onto the port
    local below = Point(port.Position + Vector3.new(0.05, -0.32 * s, 0), s * Vector3.yAxis, Vector3.xAxis)
    local push = Point(port.Position + Vector3.new(0.12, -0.12 * s, 0), s * Vector3.yAxis, Vector3.xAxis)
    tr.LFree = { { 0, belt } }
    -- ShellHold (2026-10-10, owner: "Some guns dont have actual reload animations either, just your hand moves"): the
    -- round / clip the hand carries (ViewmodelRig HELD ROUNDS) shows from the belt until it's pushed home
    tr.ShellHold = { { 0, 0 } }
    for i = 0, count - 1 do
        local t = t0 + i * step
        table.insert(tr.ShellHold, { t + step * 0.02, 1, "Step" })
        table.insert(tr.ShellHold, { t + step * 0.64, 0, "Step" })
        table.insert(tr.LFree, { t, belt })
        table.insert(tr.LFree, { t + step * 0.45, below, "Out" })
        table.insert(tr.LFree, { t + step * 0.62, push, "In" })
        table.insert(tr.LFree, { t + step * 0.95, belt })
        table.insert(ev, { t + step * 0.62, "ShellIn" })
    end
end

local function TubeReload(def, len, withPump, withBolt)
    local port = def.Points.LoadPort or Point(Vector3.new(-0.5, -0.1, 0))
    local pose = CF(-0.05, 0.12, 0.05) * ANG(R(8), R(10), R(32)) -- rolled so the loading port faces the camera
    local tr = {
        Gun = { { 0, CF() }, { 0.3, pose }, { len - 0.45, pose }, { len - 0.15, CF() } },
        LHand = { { 0, 0 }, { 0.22, 1 }, { len - 0.4, 1 }, { len - 0.2, 0 } },
        LHandPose = { { 0, "Support" }, { 0.2, "HoldMag" }, { len - 0.3, "Support" } },
    }
    local ev = {}
    ShellLoads(tr, ev, port, 0.3, 4, (len - 0.85) / 4, def.TopLoad)
    if withPump then -- rack it once the hand is back on the pump
        tr.Pump = { { 0, 0 }, { len - 0.2, 0 }, { len - 0.12, 1, "Out" }, { len - 0.02, 0, "In" } }
        tr.Slide = tr.Pump
        table.insert(ev, { len - 0.13, "PumpBack" }); table.insert(ev, { len - 0.04, "PumpForward" })
    elseif withBolt then -- support hand snaps the bolt handle back
        tr.Slide = { { 0, 0 }, { len - 0.25, 0 }, { len - 0.18, 1, "Out" }, { len - 0.1, 0, "In" } }
        table.insert(ev, { len - 0.18, "BoltBack" }); table.insert(ev, { len - 0.1, "BoltForward" })
    end
    table.sort(ev, function(a, b) return a[1] < b[1] end)
    return { Length = len, Tracks = tr, Events = ev }
end

-- RifleAnims needs a magazine well; tube-fed guns borrow their loading port for it (equip / inspect only).
local function RifleBase(def)
    if def.Points.MagWell then return RifleAnims(def) end
    local d = table.clone(def)
    d.Points = table.clone(def.Points)
    d.Points.MagWell = def.Points.LoadPort or Point(Vector3.zero)
    return RifleAnims(d)
end


local function PumpAnims(def)
    local rifle = RifleBase(def)
    return {
        Equip = rifle.Equip,
        -- fire, then rack the pump (the left hand rides it; the bolt follows through the action bars)
        Fire = {
            Length = 0.6,
            Tracks = {
                Trigger = { { 0, 1 }, { 0.08, 0 } },
                Pump = { { 0, 0 }, { 0.14, 0 }, { 0.27, 1, "Out" }, { 0.31, 1 }, { 0.44, 0, "In" } },
                Slide = { { 0, 0 }, { 0.14, 0 }, { 0.27, 1, "Out" }, { 0.31, 1 }, { 0.44, 0, "In" } },
                Gun = { { 0, CF() }, { 0.05, CF(0, 0.03, 0.1) * ANG(R(7), 0, R(2)) }, { 0.25, CF(0, -0.03, 0.04) * ANG(R(-2), R(-3), R(6)) }, { 0.6, CF(), "InOut" } },
            },
            Events = { { 0.15, "PumpBack" }, { 0.28, "Eject" }, { 0.4, "PumpForward" } },
        },
        Reload = TubeReload(def, 2.5, false),
        ReloadEmpty = TubeReload(def, 2.8, true),
        Inspect = rifle.Inspect,
    }
end

local function TubeSemiAnims(def)
    local rifle = RifleBase(def)
    return {
        Equip = rifle.Equip,
        Fire = {
            Length = 0.22,
            Tracks = {
                Slide = { { 0, 0 }, { 0.03, 1, "Out" }, { 0.1, 0, "In" } },
                Trigger = { { 0, 1 }, { 0.07, 0 } },
                Gun = { { 0, CF() }, { 0.04, CF(0, 0.02, 0.07) * ANG(R(5), 0, R(1.5)) }, { 0.22, CF(), "Out" } },
            },
            Events = { { 0.03, "Eject" } },
        },
        Reload = TubeReload(def, 2.3, false),
        ReloadEmpty = TubeReload(def, 2.6, false, true),
        Inspect = rifle.Inspect,
    }
end

-- Bolt-actions: after each shot the right hand leaves the grip, lifts the bolt, pulls it back (the case flies
-- out), pushes it home and turns it down, then returns to the grip.
local function BoltCycle(tr, ev, t)
    tr.RFollowBolt = { { 0, 0 }, { t, 0 }, { t + 0.14, 1, "Out" }, { t + 0.62, 1 }, { t + 0.78, 0, "In" } }
    tr.BoltLift = { { 0, 0 }, { t + 0.15, 0 }, { t + 0.23, 1, "Out" }, { t + 0.53, 1 }, { t + 0.61, 0, "In" } }
    tr.Slide = { { 0, 0 }, { t + 0.25, 0 }, { t + 0.36, 1, "Out" }, { t + 0.4, 1 }, { t + 0.51, 0, "In" } }
    table.insert(ev, { t + 0.2, "BoltUp" })
    table.insert(ev, { t + 0.33, "BoltBack" })
    table.insert(ev, { t + 0.37, "Eject" })
    table.insert(ev, { t + 0.5, "BoltForward" })
end

local function BoltActionAnims(def)
    local rifle = RifleAnims(def)
    local fireTr = {
        Trigger = { { 0, 1 }, { 0.07, 0 } },
        -- recoil, then the gun cants toward the bolt while it's worked
        Gun = { { 0, CF() }, { 0.06, CF(0, 0.04, 0.14) * ANG(R(9), 0, R(2)) }, { 0.3, CF(0, -0.02, 0.02) * ANG(R(-2), R(-4), R(10)) },
                { 0.95, CF(0, -0.02, 0.02) * ANG(R(-2), R(-4), R(10)) }, { 1.2, CF(), "InOut" } },
    }
    local fireEv = {}
    BoltCycle(fireTr, fireEv, 0.22)
    -- empty reload: the rifle reload, then cycle the bolt to chamber a round
    local base = rifle.Reload
    local emptyTr, emptyEv = table.clone(base.Tracks), table.clone(base.Events)
    BoltCycle(emptyTr, emptyEv, base.Length - 0.1)
    table.sort(emptyEv, function(a, b) return a[1] < b[1] end)
    return {
        Equip = rifle.Equip,
        Fire = { Length = 1.2, Tracks = fireTr, Events = fireEv },
        Reload = base,
        ReloadEmpty = { Length = base.Length + 0.75, Tracks = emptyTr, Events = emptyEv },
        Inspect = rifle.Inspect,
    }
end
-- Break-actions (0.48 double barrel): the barrels hinge down about Points.Hinge (part "Break", channel Break 0..1 x
-- def.BreakAngle), both empties kick out, the support hand brings two shells from the belt into the open breech
-- (Points.LoadPort, moved with the open barrels), then flicks it shut.
local function BreakAnims(def)
    local rifle = RifleBase(def)
    local hinge = def.Points.Hinge.Position
    local open = CFrame.new(hinge) * CFrame.Angles(0, 0, R(def.BreakAngle or -38)) * CFrame.new(-hinge)
    local breech = open * def.Points.LoadPort.Position -- the open chambers
    local BELT = Point(breech + Vector3.new(-0.3, -1.3, -0.6), Vector3.yAxis, Vector3.xAxis)
    -- (the hand comes up from BELOW the open breech: a block arm reaching over the top filled the screen)
    local AT = Point(breech + Vector3.new(-0.05, -0.42, -0.04), Vector3.yAxis, Vector3.xAxis) -- shell held under the open chambers
    local IN = Point(breech + Vector3.new(0.0, -0.26, -0.02), Vector3.yAxis, Vector3.xAxis)   -- thumbed home
    local POSE = CF(-0.05, 0.08, 0.05) * ANG(R(12), R(10), R(-16)) -- muzzle down a touch, breech toward the camera
    local function reload(len, two)
        local s = len / 2.4
        local function T(t) return t * s end
        local tr = {
            Gun = { { 0, CF() }, { T(0.3), POSE }, { T(0.55), POSE * CF(0, 0.06, 0) * ANG(R(10), 0, 0) }, { T(0.7), POSE },
                    { T(1.95), POSE }, { T(2.05), POSE * ANG(R(-12), 0, 0) }, { T(2.4), CF() } },
            Break = { { 0, 0 }, { T(0.28), 0 }, { T(0.4), 1, "Out" }, { T(1.96), 1 }, { T(2.06), 0, "In" } },
            LHand = { { 0, 0 }, { T(0.45), 1 }, { T(1.9), 1 }, { T(2.2), 0 } },
            LFree = { { 0, BELT }, { T(0.8), BELT }, { T(1.05), AT, "Out" }, { T(1.18), IN, "In" } },
            LHandPose = { { 0, "Support" }, { T(0.45), "HoldMag" }, { T(2.15), "Support" } },
            ShellHold = { { 0, 0 }, { T(0.8), 1, "Step" }, { T(1.19), 0, "Step" } }, -- (the shell in the hand)
        }
        local ev = { { T(0.36), "BreakOpen" }, { T(0.56), "Eject" }, { T(0.6), "ShellsOut" }, { T(1.18), "ShellIn" } }
        if two then
            table.insert(tr.LFree, { T(1.32), AT, "Out" }); table.insert(tr.LFree, { T(1.46), IN, "In" })
            table.insert(tr.ShellHold, { T(1.21), 1, "Step" }); table.insert(tr.ShellHold, { T(1.47), 0, "Step" })
            table.insert(ev, { T(0.62), "Eject" }); table.insert(ev, { T(1.46), "ShellIn" })
        end
        table.insert(tr.LFree, { T(1.75), AT })
        table.insert(ev, { T(2.04), "BreakClose" })
        table.sort(ev, function(a, b) return a[1] < b[1] end)
        return { Length = len, Tracks = tr, Events = ev }
    end
    return {
        Equip = rifle.Equip,
        Fire = {
            Length = 0.32,
            Tracks = {
                Trigger = { { 0, 1 }, { 0.08, 0 } },
                Gun = { { 0, CF() }, { 0.05, CF(0, 0.05, 0.16) * ANG(R(11), 0, R(2.5)) }, { 0.32, CF(), "Out" } },
            },
            Events = {},
        },
        Reload = reload(2.2, false),
        ReloadEmpty = reload(2.4, true),
        Inspect = rifle.Inspect,
    }
end
WeaponRigs.PumpAnims, WeaponRigs.TubeSemiAnims, WeaponRigs.BoltActionAnims = PumpAnims, TubeSemiAnims, BoltActionAnims
WeaponRigs.BreakAnims = BreakAnims

for _, g in pairs(WeaponRigs.Guns) do
    if not g.Anims then
        if g.AnimKind == "Pump" then g.Anims = PumpAnims(g)
        elseif g.AnimKind == "TubeSemi" then g.Anims = TubeSemiAnims(g)
        elseif g.AnimKind == "BoltAction" then g.Anims = BoltActionAnims(g)
        elseif g.AnimKind == "Rifle" then g.Anims = RifleAnims(g)
        elseif g.AnimKind == "Break" then g.Anims = BreakAnims(g)
        end
    end
end

-- ==================== OTHER PISTOLS ====================
-- The Glock's animations, refitted to another pistol: the magazine slides out along that gun's MagAxis by its
-- MagPull, and every support-hand target moves with its magazine well.
local GLOCK_WELL = Vector3.new(-0.115, 0.172, 0.002)
local function PistolAnimsFor(def)
    local axis = (def.MagAxis or GLOCK_MAG_UP).Unit
    local pull = def.MagPull or 0.42
    local shift = (def.Points.MagWell and def.Points.MagWell.Position or GLOCK_WELL) - GLOCK_WELL
    local function NearlySame(a, b) return (a.Position - b.Position).Magnitude < 1e-5 end
    local function MapMag(cf)
        if NearlySame(cf, MAG_OUT) then return CF(-axis * pull) end
        if NearlySame(cf, MAG_PARTWAY) then return CF(-axis * pull * 0.43) end
        return cf
    end
    local function MapHand(cf) return Point(cf.Position + shift, Vector3.zAxis, axis) end
    -- reloads: the Glock's lift-and-cant is too high for bigger pistols -- bring it lower and less rolled
    local lift, turn = def.ReloadLift or 0.35, def.ReloadTurn or 0.55
    local function TameGun(cf)
        return CF(cf.Position.X * 0.6, cf.Position.Y * lift, cf.Position.Z * 0.6) * CFrame.identity:Lerp(cf.Rotation, turn)
    end
    local out = {}
    for name, anim in pairs(PistolAnims) do
        local tracks = {}
        local isReload = name == "Reload" or name == "ReloadEmpty"
        for ch, keys in pairs(anim.Tracks) do
            local nk = {}
            for i, k in ipairs(keys) do
                local v = k[2]
                if ch == "Mag" then v = MapMag(v) elseif ch == "LFree" then v = MapHand(v)
                elseif ch == "Gun" and isReload then v = TameGun(v) end
                nk[i] = { k[1], v, k[3] }
            end
            tracks[ch] = nk
        end
        out[name] = { Length = anim.Length, Tracks = tracks, Events = anim.Events }
    end
    return out
end

-- Revolver: the cylinder turns a chamber per shot (ViewmodelRig, def.Revolver); the reload swings it out
-- (CylSwing channel), dumps the empties, the support hand brings a speed-loader from the belt, then it
-- swings shut.
local function RevolverAnims(def)
    local base = PistolAnimsFor(def)
    local axis = def.Points.CylAxis.Position
    local beside = Vector3.new(axis.X - 0.08, axis.Y - 0.12, -0.42)               -- left of the swung-out cylinder
    local LOADER = Point(beside, Vector3.zAxis, Vector3.xAxis)                    -- palm toward the gun, fingers forward
    local BELT = Point(Vector3.new(-0.6, -1.4, -0.5), Vector3.zAxis, Vector3.yAxis)
    local POSE = CF(-0.18, 0.1, 0.05) * ANG(R(10), R(-10), R(-20))             -- brought in and canted left so the open cylinder shows
    local DUMP = POSE * CF(0, 0.08, 0) * ANG(R(-35), 0, 0)                        -- muzzle flicked up: empties fall out
    local function reload(len)
        local s = len / 2.4
        local function T(t) return t * s end
        return {
            Length = len,
            Tracks = {
                Gun = { { 0, CF() }, { T(0.3), POSE }, { T(0.62), POSE }, { T(0.72), DUMP, "Out" }, { T(0.9), POSE }, { T(1.9), POSE }, { T(2.05), POSE * ANG(R(-6), 0, R(-8)) }, { T(2.4), CF() } },
                CylSwing = { { 0, 0 }, { T(0.3), 0 }, { T(0.45), 1, "Out" }, { T(1.86), 1 }, { T(1.98), 0, "In" } },
                LHand = { { 0, 0 }, { T(0.2), 1 }, { T(2.15), 1 }, { T(2.35), 0 } },
                LFree = { { 0, BELT }, { T(1.0), BELT }, { T(1.4), LOADER, "Out" }, { T(1.62), LOADER }, { T(1.72), BELT, "In" } },
                LHandPose = { { 0, "Support" }, { T(0.18), "Open" }, { T(1.05), "HoldMag" }, { T(1.65), "Open" }, { T(2.3), "Support" } },
                ShellHold = { { 0, 0 }, { T(1.0), 1, "Step" }, { T(1.6), 0, "Step" } }, -- (the speed-loader in the hand)
            },
            Events = { { T(0.42), "CylOpen" }, { T(0.72), "ShellsOut" }, { T(1.5), "ShellsIn" }, { T(1.97), "CylClose" } },
        }
    end
    return {
        Equip = base.Equip,
        Fire = {
            Length = 0.18,
            Tracks = {
                Trigger = { { 0, 1 }, { 0.09, 0 } },
                Gun = { { 0, CF() }, { 0.04, CF(0, 0.04, 0.08) * ANG(R(9), 0, R(2)) }, { 0.18, CF(), "Out" } },
            },
            Events = {},
        },
        Reload = reload(2.4),
        ReloadEmpty = reload(2.4),
        Inspect = base.Inspect,
    }
end
WeaponRigs.PistolAnimsFor, WeaponRigs.RevolverAnims = PistolAnimsFor, RevolverAnims
for _, g in pairs(WeaponRigs.Guns) do
    if g.Class == "Pistol" and not g.Anims then
        g.Anims = g.Revolver and RevolverAnims(g) or PistolAnimsFor(g)
    end
end
-- the Glock gets the same lower, less rolled reload (PistolAnimsFor with its own numbers changes nothing else)
WeaponRigs.Guns.Glock17.Anims = PistolAnimsFor(WeaponRigs.Guns.Glock17)
-- ===== RIVALS HOLDS (WeaponRigs.Arms.Style = "Block", Arms.Block.Rivals) =====
-- Per weapon class, copied from Rivals: Hold = camera-space spot of the right grip point (+X right, +Y up, -Z out),
-- Turn = degrees (pitch, yaw: + = muzzle toward the centre, roll), ShR / ShL = where each arm comes from (camera
-- space, below the screen), LeftOnRight = two-handed pistol (support fist beside the shooting fist, camera space),
-- OneHand = support arm out of view (comes in for reloads). Per-gun overrides go in RIVALS_GUN.
local RIVALS = { -- (0.97 UPDATE 3, owner: "holding weapons should feel consistent ... all the guns vary a lot with the different arm lengths, heights etc and its jarring": every rifle-type class shares ONE hold + shoulders, pistols one; the support shoulder sits out at the lower left)
    AR = { Hold = Vector3.new(0.52, -0.74, -1.4), Turn = Vector3.new(0, 0, 0), ShR = Vector3.new(0.75, -1.5, 0.1), ShL = Vector3.new(-0.75, -1.45, -0.1) },
    SMG = { Hold = Vector3.new(0.52, -0.74, -1.4), Turn = Vector3.new(0, 0, 0), ShR = Vector3.new(0.75, -1.5, 0.1), ShL = Vector3.new(-0.75, -1.45, -0.1) },
    PISTOL = { Hold = Vector3.new(0.66, -1.4, -1.95), Turn = Vector3.new(0, 0, 0), GripDrop = -0.04, ShR = Vector3.new(1.25, -1.75, 0.2), ShL = Vector3.new(-0.55, -1.8, 0.2), -- (shoulders out to the sides: the forearms come in diagonally and show -- owner "we cant even see the arms")
        LeftOnRight = Vector3.new(-0.2, -0.08, 0.06) },
    HEAVY = { Hold = Vector3.new(0.66, -1.4, -1.95), Turn = Vector3.new(0, 0, 0), GripDrop = -0.02, ShR = Vector3.new(0.6, -1.5, 0.1), ShL = Vector3.new(-0.6, -1.8, 0.1), OneHand = true },
    SHOTGUN = { Hold = Vector3.new(0.52, -0.74, -1.4), Turn = Vector3.new(0, 0, 0), ShR = Vector3.new(0.75, -1.5, 0.1), ShL = Vector3.new(-0.75, -1.45, -0.1) },
    SNIPER = { Hold = Vector3.new(0.52, -0.74, -1.4), Turn = Vector3.new(0, 0, 0), ShR = Vector3.new(0.75, -1.5, 0.1), ShL = Vector3.new(-0.75, -1.45, -0.1) },
    -- LMGs (0.48): held like a rifle but lower and a touch further out -- a long, heavy gun across the bottom-right
    LMG = { Hold = Vector3.new(0.52, -0.74, -1.4), Turn = Vector3.new(0, 0, 0), ShR = Vector3.new(0.75, -1.5, 0.1), ShL = Vector3.new(-0.75, -1.45, -0.1) },
}
local RIVALS_CLASS = {
    AK47 = "AR", M4A1 = "AR", SCAR = "AR", F2000 = "AR", AUG = "AR",
    UZI = "SMG", MP5 = "SMG", MP7 = "SMG", P90 = "SMG", TEC9 = "SMG",
    Glock17 = "PISTOL", DEAGLE = "PISTOL", RHINO = "PISTOL", -- (owner: "why are some of the pistols only one hand ... shouldnt it be consistent")
    R870 = "SHOTGUN", BM4 = "SHOTGUN", AA12 = "SHOTGUN",
    AWP = "SNIPER", M82 = "SNIPER", SCOUT = "SNIPER",
}
local RIVALS_GUN = { -- pistols read bigger in Rivals: the gun is about as long as the arm is thick x2
    Glock17 = { Scale = 1.5 }, DEAGLE = { Scale = 1.3 }, RHINO = { Scale = 1.5, Hold = Vector3.new(0.34, -0.79, -1.3) },
    AK47 = { Scale = 1.5 }, M4A1 = { Scale = 1.5 }, R870 = { Scale = 1.75, NudgeL = Vector3.new(0, -0.06, 0) }, SCOUT = { Scale = 1.4 }, -- read small at the class size
    TEC9 = { Scale = 1.25, Hold = Vector3.new(0.38, -0.65, -1.15) }, -- down + back into the fists
    UZI = { Hold = Vector3.new(0.38, -0.675, -1.15) },
    P90 = { Hold = Vector3.new(0.41, -0.9, -1.3), Turn = Vector3.new(6, 0, 0), Scale = 1.1, Widen = 1.7 }, -- owner's reference: straight ahead from the bottom-right, nose up / stock down, no cant
    F2000 = { Hold = Vector3.new(0.58, -0.8, -1.6) }, -- further out: the stock clipped the camera on inspect -- (glove stays on screen at FOV 70)
    MP5 = { Scale = 1.35, Hold = Vector3.new(0.56, -0.95, -1.7) }, -- bigger, and further out (stock in your face)
} -- per-gun overrides: { Hold = ..., Turn = ..., Scale = (gun size multiplier), NudgeR / NudgeL = gun space }
-- ===== NEW GUN HOLDS (tools/new_guns.py) =====
RIVALS_CLASS.M249 = "LMG"
RIVALS_CLASS.PKM = "LMG"
RIVALS_CLASS.M60 = "LMG"
RIVALS_CLASS.HK21 = "LMG"
RIVALS_CLASS.TAR21 = "AR"
RIVALS_CLASS.GALIL = "AR"
RIVALS_CLASS.HK416 = "AR"
RIVALS_CLASS.MP40 = "SMG"
RIVALS_CLASS.PPSH = "SMG"
RIVALS_CLASS.VECTOR = "SMG"
RIVALS_CLASS.USAS12 = "SHOTGUN"
RIVALS_CLASS.DBARREL = "SHOTGUN"
RIVALS_CLASS.KSG = "SHOTGUN"
RIVALS_CLASS.M590 = "SHOTGUN"
RIVALS_CLASS.USP = "PISTOL"
RIVALS_CLASS.P226 = "PISTOL"
RIVALS_CLASS.SR9 = "PISTOL"
RIVALS_CLASS.PX4 = "PISTOL"
RIVALS_CLASS.SVD = "SNIPER"
RIVALS_CLASS.SKS = "SNIPER"
RIVALS_CLASS.M40 = "SNIPER"
RIVALS_CLASS.EMR = "SNIPER"
RIVALS_CLASS.MK11 = "SNIPER"
RIVALS_CLASS.BEAM = "AR"
RIVALS_GUN.USP = { Scale = 1.5 }
RIVALS_GUN.P226 = { Scale = 1.5 }
RIVALS_GUN.SR9 = { Scale = 1.5 }
RIVALS_GUN.PX4 = { Scale = 1.45 }
RIVALS_GUN.DBARREL = { Scale = 1.5, NudgeL = Vector3.new(0, -0.06, 0) }
RIVALS_GUN.M590 = { Scale = 1.55, NudgeL = Vector3.new(0, -0.06, 0) }
RIVALS_GUN.KSG = { Hold = Vector3.new(0.44, -0.9, -1.65) }
RIVALS_GUN.BEAM = { Scale = 1.05, Hold = Vector3.new(0.56, -0.86, -1.8) }
RIVALS_GUN.USAS12 = { Hold = Vector3.new(0.42, -0.95, -1.75), Scale = 1.1 }
-- ===== END NEW GUN HOLDS =====
-- ===== BEAM GUN HOLDS (tools/beam_guns.py) =====
RIVALS_CLASS.ContinuousLaser = "AR"
RIVALS_CLASS.QuadBeam = "SHOTGUN"
RIVALS_CLASS.Railgun = "SNIPER"
RIVALS_CLASS.PlasmaCannon = "LMG"
RIVALS_CLASS.VoidDisintegrator = "AR"
RIVALS_CLASS.SparkPistol = "PISTOL"
RIVALS_CLASS.BEAM = "SMG"
RIVALS_GUN.SparkPistol = { Scale = 1.5, Hold = Vector3.new(0.3, -0.92, -1.3), NudgeR = Vector3.new(0, 0.1, 0), NudgeL = Vector3.new(0, 0.1, 0) }
RIVALS_GUN.ContinuousLaser = {}
RIVALS_GUN.Railgun = {}
RIVALS_GUN.PlasmaCannon = {}
RIVALS_GUN.VoidDisintegrator = { Scale = 0.66 } -- (BEAM GUNS v4: the new model is tall -- it filled half the screen)
RIVALS_GUN.QuadBeam = { Hold = Vector3.new(0.44, -0.9, -1.65) }
RIVALS_GUN.BEAM = { Scale = 0.88 } -- (BEAM GUNS v4: long stock up close)
-- ===== END BEAM GUN HOLDS =====
WeaponRigs.Rivals, WeaponRigs.RivalsClass = RIVALS, RIVALS_CLASS
for id, cls in pairs(RIVALS_CLASS) do
    local g, c, o = WeaponRigs.Guns[id], RIVALS[cls], RIVALS_GUN[id] or {}
    if g and c then
        g.BlockHold, g.BlockTurn = o.Hold or c.Hold, o.Turn or c.Turn
        g.RivalsClass = cls -- (0.97: ViewmodelRig.VALORANT_HOLD per class)
        g.BlockShoulderR, g.BlockShoulderL = o.ShR or c.ShR, o.ShL or c.ShL
        g.BlockLeftOnRight = c.LeftOnRight
        g.BlockOneHand = c.OneHand
        g.BlockGripDrop = o.GripDrop or c.GripDrop
        g.BlockNudgeR, g.BlockNudgeL = o.NudgeR, o.NudgeL
        local sc = o.Scale or c.Scale
        if sc then g.Scale = (g.Scale or 1) * sc end
        if o.Widen then g.Widen = o.Widen end
    end
end
-- (0.97 UPDATE 3, owner: "Some of the weapons are WAYYYY bigger than others. Take the m249 and uzi for example ... find
-- the ideal size that matches something along the lines of valorant or CS"; then at one true scale "some of the guns are
-- still tiny looking" and "the size of the m82 for example looks nice, its a good size without being annoyingly large or
-- awkwardly small"). Every gun's drawn size comes from ONE rule: its on-screen length (model length x scale / hold
-- distance) follows the M82's, compressed -- A = A_REF x (L / L_REF) ^ VIEW_Q -- so a big gun is drawn smaller than true and
-- a small one bigger, but an Uzi still reads smaller than an AK. Pistols have their own reference (the Glock, unchanged).
-- GUN_LENGTH = each v2 model's length (studs, measured from the meshes; a new gun without one uses 0.9 x its Frame).
WeaponRigs.GUN_LENGTH = {
    AA12 = 3.45, AK47 = 3.14, AUG = 2.82, AWP = 4.21, BEAM = 3.22, BM4 = 3.39, ContinuousLaser = 3.39, DBARREL = 3.93, DEAGLE = 0.94,
    EMR = 3.57, F2000 = 2.68, GALIL = 3.80, Glock17 = 0.71, HK21 = 3.88, HK416 = 3.21, KSG = 2.57, M249 = 3.71, M40 = 3.89, M4A1 = 3.07,
    M590 = 3.57, M60 = 3.90, M82 = 5.16, MK11 = 3.93, MP40 = 2.96, MP5 = 2.43, MP7 = 1.96, P226 = 0.72, P90 = 1.78, PKM = 4.25,
    PPSH = 2.99, PX4 = 0.68, PlasmaCannon = 4.25, QuadBeam = 3.04, R870 = 2.86, RHINO = 0.81, Railgun = 4.64, SCAR = 3.54, SCOUT = 3.57,
    SKS = 3.64, SR9 = 0.68, SVD = 4.35, SparkPistol = 0.89, TAR21 = 2.57, TEC9 = 1.14, USAS12 = 3.43, USP = 0.71, UZI = 1.68,
    VECTOR = 2.20, VoidDisintegrator = 2.76,
}
-- (owner, after measured-coverage sizes: "the guns should match the size of the hands ... they shouldnt look neither
-- massive or tiny"). The HANDS are the reference: every gun -- pistols too -- is drawn at ONE scale, so each keeps its
-- real proportion to the fists (a pistol grip ~ one fist tall, a rifle ~ seven fists long); the fists are sized to a
-- real hand at that scale (ViewmodelRig.ARM_FIT); every rifle-type class holds at the same depth (RIVALS Hold Z) so the
-- hands read the same size on every gun, pistols a little closer. GUN_VIEW_SCALE is the one knob for "bigger / smaller".
-- VIEW_FIT[id][2] = a measured muzzle-height lift (tools/view_fit.py) so every muzzle ends at the same screen height
-- ([1] is unused now).
WeaponRigs.SHORT_K = 0.3
WeaponRigs.GUN_SHORTEN = { UZI = 0.82, RHINO = 0.84 } -- (drawn shorter along the length only: owner "the uzi ... looks streched length wise")
WeaponRigs.GUN_VIEW_SCALE = 1.4 -- (owner at 1.12: "the ak you are holding right now feels minature")
-- per-gun roll fix (degrees, + = counter-clockwise on screen) for models rolled inside their own mesh (owner: "the deagle
-- is tilted to the right"; its slide is ~4 deg rolled in the model)
WeaponRigs.VIEW_ROLL = { DEAGLE = 4 }
-- per-gun hand tweaks on top of the measured fit (owner's pass after it): S = size x, Len = drawn length x,
-- Pitch = degrees (- = nose down: a long gun whose far muzzle sits near the crosshair reads "too high" -- tilting it
-- keeps the hands where they are), Lift = studs after every anchor (pistols too)
WeaponRigs.VIEW_TWEAK = {
    EMR = { Pitch = -4 }, M40 = { Pitch = -3 }, SKS = { Pitch = -3 },
    SCOUT = { Pitch = -3, Len = 0.86 },
    SVD = { S = 1.16, Len = 0.84, Pitch = -2 }, -- ("the scope looks stretched and in your face but the entire gun still feels small")
    MK11 = { S = 1.06 }, MP40 = { S = 1.07 }, MP5 = { S = 1.07 },
    KSG = { S = 1.2 },
    RHINO = { Lift = -0.035 },
    Railgun = { Len = 0.82 }, -- (BEAM GUNS v5 pilot: the bullpup's tall rear body sat at the camera and the coil
    -- chamber was far off; drawn shorter, the chamber comes closer and the slab moves away -- same class hold)
}
WeaponRigs.PISTOL_BOOST = 1.15 -- (0.97: pistols held further out so the forearms show -- owner "we cant even see the arms" -- and drawn a little bigger)
WeaponRigs.VIEW_FIT = {
    AA12 = { 1.074, 0.000, 0.238 },
    AK47 = { 1.400, 0.000, 0.000 },
    AUG = { 1.139, 0.000, 0.000 },
    AWP = { 1.442, 0.000, 0.179 },
    BEAM = { 0.769, 0.000, 0.174 },
    BM4 = { 2.000, 0.000, 0.223 },
    ContinuousLaser = { 0.702, 0.000, 0.000 },
    DBARREL = { 1.755, 0.000, 0.228 },
    DEAGLE = { 1.650, 0.000, 0.000 },
    EMR = { 2.000, 0.000, 0.257 },
    F2000 = { 1.193, 0.000, 0.003 },
    GALIL = { 1.250, 0.000, 0.035 },
    Glock17 = { 2.070, 0.000, 0.000 },
    HK21 = { 1.525, 0.000, 0.049 },
    HK416 = { 1.303, 0.000, 0.000 },
    KSG = { 0.850, 0.000, 0.000 },
    M249 = { 1.034, 0.000, 0.000 },
    M40 = { 1.847, 0.000, 0.249 },
    M4A1 = { 1.366, 0.000, 0.000 },
    M590 = { 1.846, 0.000, 0.198 },
    M60 = { 1.119, 0.000, 0.000 },
    M82 = { 0.850, 0.000, 0.000 },
    MK11 = { 1.026, 0.000, 0.043 },
    MP40 = { 1.509, 0.000, 0.220 },
    MP5 = { 1.054, 0.000, 0.062 },
    MP7 = { 1.256, 0.000, 0.107 },
    P226 = { 1.920, 0.000, 0.000 },
    P90 = { 1.059, 0.000, 0.143 },
    PKM = { 1.400, 0.000, 0.000 },
    PPSH = { 1.791, 0.000, 0.300 },
    PX4 = { 1.435, 0.000, 0.000 },
    PlasmaCannon = { 0.620, 0.000, 0.000 },
    QuadBeam = { 0.830, 0.000, 0.300 },
    R870 = { 2.000, 0.000, 0.223 },
    RHINO = { 2.400, 0.000, 0.079 },
    Railgun = { 0.696, 0.000, 0.111 },
    SCAR = { 0.937, 0.000, 0.000 },
    SCOUT = { 1.897, 0.000, 0.194 },
    SKS = { 1.818, 0.000, 0.084 },
    SR9 = { 1.762, 0.000, 0.000 },
    SVD = { 1.404, 0.000, 0.201 },
    SparkPistol = { 1.785, 0.000, 0.050 },
    TAR21 = { 1.058, 0.000, 0.000 },
    TEC9 = { 1.699, 0.000, 0.300 },
    USAS12 = { 1.043, 0.000, 0.187 },
    USP = { 1.592, 0.000, 0.000 },
    UZI = { 1.169, 0.000, 0.144 },
    VECTOR = { 1.161, 0.000, 0.042 },
    VoidDisintegrator = { 0.881, 0.000, 0.174 },
}
for id, g in pairs(WeaponRigs.Guns) do
    if g.RivalsClass and not g.IsMelee then
        local c = RIVALS[g.RivalsClass]
        if c and c.Hold then g.BlockHold = c.Hold end -- (per-gun holds only made up for the old size mismatch)
        -- (owner: "ak is a perfect example gun now. THe uzi is WAY too long"): at one scale a short gun, held at the same
        -- spot as the AK, reaches just as far across the screen (perspective), so anything shorter than the AK is drawn
        -- a little smaller: x (L / AK) ^ SHORT_K. Pistols keep their own size.
        local L = WeaponRigs.GUN_LENGTH[id] or 3.14
        local side = g.RivalsClass == "PISTOL" or g.RivalsClass == "HEAVY"
        g.Scale = WeaponRigs.GUN_VIEW_SCALE * ((side or L >= 3.14) and 1 or (L / 3.14) ^ WeaponRigs.SHORT_K)
        g.ViewLiftY = nil
        g.Length = WeaponRigs.GUN_SHORTEN[id]
        -- (owner: "Each class of gun should feel super similar to each other in size and holding"): VIEW_FIT[id] =
        -- { scale, muzzle lift } MEASURED by tools/view_fit.py so every gun covers about as much of the screen as its
        -- class reference (AR = AK, LMG = PKM, the rest = the class median) and its muzzle ends at the same height
        local fit = WeaponRigs.VIEW_FIT[id]
        if fit then g.Scale, g.ViewLiftY, g.ViewShiftX = fit[1], fit[2], fit[3] end
        if g.RivalsClass == "PISTOL" then g.Scale *= WeaponRigs.PISTOL_BOOST end -- (owner: "The pistols still feel so small")
        local tw = WeaponRigs.VIEW_TWEAK[id]
        if tw then
            g.Scale *= (tw.S or 1)
            if tw.Len then g.Length = tw.Len end
            if tw.Lift then g.ViewLiftAfter = tw.Lift end
            if tw.Fist then g.FistOff = tw.Fist end
        end
        if WeaponRigs.VIEW_ROLL[id] or (tw and tw.Pitch) then
            g.BlockTurn = Vector3.new(tw and tw.Pitch or 0, 0, WeaponRigs.VIEW_ROLL[id] or 0)
        end
    end
end

-- (Update 5 INSPECTS, owner: "Ensure the inspects on the weapons ... function properly without clipping ... allow for future
-- custom inspects with skins"): every gun's inspect is its CLASS choreography from AimRngShared.Inspects (per-gun tuning:
-- Inspects.GUN; a skin's own: skin.InspectAnim / its set's GunInspect -- docs/INSPECTS.md). Checked clip-free per gun by
-- tools/gun_clipcheck.luau.
local Inspects = require(script.Parent:WaitForChild("Inspects"))
for id, g in pairs(WeaponRigs.Guns) do
    if g.RivalsClass and g.Anims and not g.IsMelee then
        g.Anims = table.clone(g.Anims)
        g.Anims.Inspect = Inspects.GunInspect(g, id)
    end
end

return WeaponRigs
