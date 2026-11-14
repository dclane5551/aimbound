--!nocheck
-- Character creator catalog (shared). Players don't wear their Roblox avatar here (StarterPlayer.LoadCharacterAppearance
-- = false): everyone is a blocky Rivals-style character built from these choices (AvatarService applies them).
--
-- A saved look (state.Avatar) is { [category Id] = entry Id } for every category below (missing keys = defaults).
-- Unlock = nil (free) | { Level = n } | { Robux = price, ProductId = id } (ProductId 0 = not on sale yet: shown locked)
--        | { Drop = true } (found in the game: owned once state.AvatarOwned[Id] is set).
--
-- COSMETIC PIECES (hair, headwear, tops, bottoms -- and any future slot): an entry's Pieces is a list of blocks, each
--   { Attach = body part (default: the slot's Attach), S = size, P = centre, R = rotation degrees, -- all in units of
--     the attach part's size (the head shell for "Head"; front = -Z, top = +Y)
--     Ball / Cyl = rounded / cylinder, Color = Color3 or "Shirt" | "ShirtDark" | "Pants" | "PantsDark" | "Hair" | "Skin",
--     Material = Enum.Material name, Transparency }
-- Entries may also set HidesHair = true (hats that cover the hair). New slots: add a category with Slot = true,
-- an Attach, a catalog with a "None" entry, and a Default -- AvatarService and the creator handle the rest.
local AvatarData = {}

local function C3(r, g, b) return Color3.fromRGB(r, g, b) end

-- ===== Categories, in the order the creator shows them =====
AvatarData.Categories = {
    { Id = "Body", Label = "BODY", Icon = "■" },
    { Id = "Skin", Label = "SKIN", Icon = "●" },
    { Id = "Head", Label = "HEAD", Icon = "▣" },
    { Id = "Face", Label = "FACE", Icon = "◉" },
    { Id = "Hair", Label = "HAIR", Icon = "≋" },
    { Id = "HairColor", Label = "HAIR COLOR", Icon = "◐" },
    { Id = "HeadGear", Label = "HEADWEAR", Icon = "♕", Slot = true, Attach = "Head" },
    { Id = "Shirt", Label = "SHIRT", Icon = "▲" },
    { Id = "Sleeves", Label = "SLEEVES", Icon = "◧" },
    { Id = "Top", Label = "TOP", Icon = "◭", Slot = true, Attach = "UpperTorso" },
    { Id = "Pants", Label = "PANTS", Icon = "▼" },
    { Id = "Bottom", Label = "BOTTOM", Icon = "◮", Slot = true, Attach = "LowerTorso" },
    { Id = "Trim", Label = "TRIM GLOW", Icon = "◆" },
}

-- ===== Body types (HumanoidDescription scales) =====
AvatarData.Body = {
    { Id = "Classic", Name = "Classic", W = 1, H = 1, D = 1, Head = 1 },
    { Id = "Chunky", Name = "Chunky", W = 1.18, H = 0.96, D = 1.15, Head = 1.04 },
    { Id = "Slim", Name = "Slim", W = 0.88, H = 1.04, D = 0.9, Head = 0.96 },
    { Id = "Small", Name = "Small", W = 0.9, H = 0.86, D = 0.9, Head = 1.12 },
    { Id = "Titan", Name = "Titan", W = 1.25, H = 1.1, D = 1.2, Head = 1, Unlock = { Level = 25 } },
}

-- ===== Skin =====
AvatarData.Skin = {
    { Id = "Porcelain", Name = "Porcelain", Color = C3(255, 230, 214) },
    { Id = "Fair", Name = "Fair", Color = C3(246, 210, 180) },
    { Id = "Peach", Name = "Peach", Color = C3(234, 184, 146) },
    { Id = "Warm", Name = "Warm", Color = C3(214, 160, 118) },
    { Id = "Tan", Name = "Tan", Color = C3(190, 132, 90) },
    { Id = "Bronze", Name = "Bronze", Color = C3(160, 106, 68) },
    { Id = "Brown", Name = "Brown", Color = C3(124, 80, 52) },
    { Id = "Deep", Name = "Deep", Color = C3(92, 58, 38) },
    { Id = "Ebony", Name = "Ebony", Color = C3(62, 40, 28) },
    { Id = "Classic", Name = "Classic Yellow", Color = C3(245, 205, 48) },
    { Id = "Ghost", Name = "Ghost", Color = C3(196, 226, 255), Unlock = { Level = 5 } },
    { Id = "Alien", Name = "Alien", Color = C3(120, 220, 110), Unlock = { Level = 10 } },
    { Id = "Ember", Name = "Ember", Color = C3(235, 92, 64), Unlock = { Level = 15 } },
    { Id = "Void", Name = "Void", Color = C3(38, 34, 52), Unlock = { Level = 30 } },
    { Id = "Gold", Name = "24K Gold", Color = C3(255, 196, 60), Material = "Metal", Unlock = { Robux = 99, ProductId = 0 } },
    { Id = "Chrome", Name = "Chrome", Color = C3(200, 206, 216), Material = "Metal", Unlock = { Robux = 99, ProductId = 0 } },
}

-- ===== Head shapes (Size in studs at body Head scale 1). Every shape is a shell over the hidden Roblox head (the
-- default head is an animated "dynamic head" whose face is part of its mesh -- a decal on it flickers). =====
AvatarData.Head = {
    -- (about half the torso's width, Rivals-style; the torso is 2 studs wide)
    { Id = "Cube", Name = "Cube", Size = Vector3.new(1, 1, 1) },
    { Id = "Classic", Name = "Classic", Size = Vector3.new(1.05, 1.05, 1.05), ClassicMesh = true }, -- Roblox's original rounded head
    { Id = "Tall", Name = "Tall Block", Size = Vector3.new(0.9, 1.15, 0.92) },
    { Id = "Wide", Name = "Wide Block", Size = Vector3.new(1.2, 0.95, 1) },
    { Id = "Round", Name = "Round", Size = Vector3.new(1.06, 1.06, 1.06), Sphere = true, Unlock = { Level = 8 } },
    { Id = "Mega", Name = "Mega Cube", Size = Vector3.new(1.32, 1.32, 1.32), Unlock = { Level = 20 } },
}

-- ===== Faces (Roblox's classic faces; Texture = the face image) =====
local function Face(id, name, tex, unlock) return { Id = id, Name = name, Texture = "rbxassetid://" .. tex, Unlock = unlock } end
AvatarData.Face = {
    Face("Smile", "Smile", 144080495),
    Face("CheckIt", "Check It", 7074780),
    Face("Chill", "Chill", 7074749),
    Face("SillyFun", "Silly Fun", 7699086),
    Face("Squiggle", "Squiggle Mouth", 25165947),
    Face("Skeptic", "Skeptic", 31117192),
    Face("Stare", "Stare", 8560915),
    Face("NotAmused", "Not Amused", 7131857),
    Face("Cutiemouse", "Cutiemouse", 15885042),
    Face("BigGrin", ":D", 16132434),
    Face("Side", "¬_¬", 13038247),
    Face("Chubs", "Chubs", 7076096, { Level = 3 }),
    Face("Dizzy", "Dizzy", 10749463, { Level = 6 }),
    Face("Stitch", "Stitchface", 8329438, { Level = 10 }),
    Face("Fang", "Fang", 7075130, { Level = 14 }),
    Face("Sigmund", "Sigmund", 21311520, { Level = 18 }),
    Face("Good", "Good Intentioned", 7317606, { Level = 22 }),
    Face("Zombie", "Zombie", 629906620, { Level = 35 }),
}

-- ===== Hair (blocks in head units: the head is a 1x1x1 box at the origin, front = -Z, top = +Y) =====
-- Each piece: S = size, P = centre, R = rotation in degrees (optional), Ball = drawn rounded (optional).
local V = Vector3.new
AvatarData.Hair = {
    { Id = "None", Name = "Bald", Pieces = {} },
    { Id = "Buzz", Name = "Buzz Cut", Pieces = {
        { S = V(1.04, 0.16, 1.04), P = V(0, 0.52, 0) },
        { S = V(1.04, 0.4, 0.1), P = V(0, 0.28, 0.5) },
    } },
    { Id = "Crew", Name = "Crew Cut", Pieces = {
        { S = V(1.08, 0.26, 1.06), P = V(0, 0.6, 0.01) },
        { S = V(1.08, 0.5, 0.14), P = V(0, 0.3, 0.5) },
        { S = V(0.12, 0.34, 0.86), P = V(-0.52, 0.36, 0.08) }, { S = V(0.12, 0.34, 0.86), P = V(0.52, 0.36, 0.08) },
    } },
    { Id = "Swept", Name = "Side Swept", Pieces = {
        { S = V(1.1, 0.3, 1.1), P = V(0, 0.62, 0.02) },
        { S = V(0.78, 0.26, 0.16), P = V(-0.16, 0.42, -0.53), R = V(0, 0, 10) },
        { S = V(1.1, 0.56, 0.16), P = V(0, 0.3, 0.5) },
        { S = V(0.14, 0.46, 0.92), P = V(-0.54, 0.3, 0.06) }, { S = V(0.14, 0.46, 0.92), P = V(0.54, 0.3, 0.06) },
    } },
    { Id = "Spiky", Name = "Spiky", Pieces = {
        { S = V(1.06, 0.22, 1.06), P = V(0, 0.58, 0.02) },
        { S = V(0.26, 0.42, 0.26), P = V(-0.3, 0.8, -0.28), R = V(-18, 0, 16) },
        { S = V(0.26, 0.46, 0.26), P = V(0.05, 0.84, -0.3), R = V(-20, 0, -4) },
        { S = V(0.26, 0.42, 0.26), P = V(0.34, 0.8, -0.2), R = V(-14, 0, -18) },
        { S = V(0.28, 0.44, 0.28), P = V(-0.22, 0.82, 0.18), R = V(14, 0, 14) },
        { S = V(0.28, 0.44, 0.28), P = V(0.24, 0.82, 0.22), R = V(16, 0, -14) },
        { S = V(1.06, 0.46, 0.14), P = V(0, 0.32, 0.5) },
    } },
    { Id = "Bowl", Name = "Bowl Cut", Pieces = {
        { S = V(1.14, 0.44, 1.14), P = V(0, 0.5, 0.01) },
        { S = V(1.12, 0.18, 0.12), P = V(0, 0.28, -0.55) },
        { S = V(0.14, 0.4, 0.9), P = V(-0.56, 0.26, 0.06) }, { S = V(0.14, 0.4, 0.9), P = V(0.56, 0.26, 0.06) },
        { S = V(1.14, 0.62, 0.14), P = V(0, 0.22, 0.55) },
    } },
    { Id = "Mohawk", Name = "Mohawk", Unlock = { Level = 4 }, Pieces = {
        { S = V(0.26, 0.46, 1.08), P = V(0, 0.72, 0.04) },
        { S = V(0.26, 0.3, 0.26), P = V(0, 0.62, -0.58), R = V(-30, 0, 0) },
    } },
    { Id = "Long", Name = "Long", Pieces = {
        { S = V(1.1, 0.28, 1.1), P = V(0, 0.6, 0.02) },
        { S = V(1.12, 1.35, 0.22), P = V(0, -0.06, 0.52) },
        { S = V(0.16, 1.15, 0.86), P = V(-0.56, 0.02, 0.1) }, { S = V(0.16, 1.15, 0.86), P = V(0.56, 0.02, 0.1) },
        { S = V(0.9, 0.2, 0.14), P = V(0.08, 0.42, -0.54), R = V(0, 0, -6) },
    } },
    { Id = "Ponytail", Name = "Ponytail", Pieces = {
        { S = V(1.1, 0.3, 1.1), P = V(0, 0.6, 0.02) },
        { S = V(1.1, 0.5, 0.16), P = V(0, 0.32, 0.5) },
        { S = V(0.32, 0.9, 0.32), P = V(0, 0.08, 0.76), R = V(-22, 0, 0), Ball = true },
        { S = V(0.9, 0.18, 0.14), P = V(0, 0.42, -0.54) },
    } },
    { Id = "Bun", Name = "Top Bun", Unlock = { Level = 2 }, Pieces = {
        { S = V(1.08, 0.26, 1.08), P = V(0, 0.58, 0.02) },
        { S = V(1.08, 0.48, 0.14), P = V(0, 0.3, 0.5) },
        { S = V(0.5, 0.46, 0.5), P = V(0, 0.86, 0.12), Ball = true },
    } },
    { Id = "Pigtails", Name = "Pigtails", Unlock = { Level = 7 }, Pieces = {
        { S = V(1.1, 0.28, 1.1), P = V(0, 0.6, 0.02) },
        { S = V(1.1, 0.5, 0.14), P = V(0, 0.32, 0.5) },
        { S = V(0.36, 0.6, 0.36), P = V(-0.66, 0.1, 0.2), Ball = true },
        { S = V(0.36, 0.6, 0.36), P = V(0.66, 0.1, 0.2), Ball = true },
    } },
    { Id = "Afro", Name = "Afro", Unlock = { Level = 12 }, Pieces = {
        { S = V(1.5, 1.2, 1.5), P = V(0, 0.48, 0.1), Ball = true },
    } },
}

-- ===== Gear v2: NEON OPERATOR (owner 2026-10-02: "the starting outfits and drops still don't really fit the vibe of
-- the game" -- the old line was dark-fantasy leather / chainmail / bone). Aim-trainer, neon-biome, Rivals-style blocky
-- characters: headsets, visors, hoodies, tech vests, exo frames, holo capes; the glow lines take the player's TRIM GLOW
-- colour (Color = "Trim"). Free starters are street / esports kit; everything else drops in dungeons
-- (Unlock = { Drop = true }) with a Rarity (rarer = more tech, more glow; see AvatarData.RollDrop).
-- Legacy = true: the retired dark-fantasy pieces -- never listed or dropped, still wearable by anyone who owns them.
local DROP = { Drop = true }
local BLACK, IRON, STEEL, RUST_IRON = C3(22, 20, 22), C3(92, 94, 100), C3(150, 154, 162), C3(98, 82, 70)
local LEATHER, DARK_LEATHER, BONE, LINEN = C3(112, 74, 46), C3(64, 44, 32), C3(214, 204, 178), C3(196, 186, 160)
local GOLD, BLOOD = C3(214, 168, 72), C3(120, 18, 24)
local GUNMETAL, CARBON, OLIVE_TECH = C3(62, 66, 74), C3(30, 32, 38), C3(70, 76, 60)
-- the retired dark-fantasy pieces (Legacy: see above)
local LEGACY = { ClothHood = true, Headwrap = true, IronCoif = true, BoneCirclet = true, HornedHelm = true, PlagueMask = true, WraithHood = true, ThornCrown = true, EmberCrown = true, Jerkin = true, RopeSash = true, TravelCloak = true, Chainmail = true, Cuirass = true, Tabard = true, Pauldrons = true, BonePauldrons = true, PlateCuirass = true, ShadowCloak = true, VoidMantle = true, Belt = true, LegWraps = true, WornBoots = true, PouchBelt = true, Faulds = true, Greaves = true, IronBoots = true, BoneSkirt = true, HellGreaves = true, AstralLegguards = true }

-- ===== Headwear (Attach = Head) =====
AvatarData.HeadGear = {
    { Id = "None", Name = "None", Pieces = {} },
    -- starter (free): neon-operator kit
    { Id = "Headset", Name = "Pro Headset", Pieces = {
        { S = V(1.1, 0.08, 0.16), P = V(0, 0.56, 0), Color = "ShirtDark", Material = "SmoothPlastic" },
        { S = V(0.14, 0.38, 0.38), P = V(-0.56, 0.02, 0), Color = "ShirtDark", Material = "SmoothPlastic" },
        { S = V(0.14, 0.38, 0.38), P = V(0.56, 0.02, 0), Color = "ShirtDark", Material = "SmoothPlastic" },
        { S = V(0.03, 0.26, 0.26), P = V(-0.64, 0.02, 0), Color = "Trim", Material = "Neon" },
        { S = V(0.03, 0.26, 0.26), P = V(0.64, 0.02, 0), Color = "Trim", Material = "Neon" },
        { S = V(0.05, 0.05, 0.46), P = V(-0.5, -0.2, -0.3), R = V(0, 28, 0), Color = "ShirtDark", Material = "SmoothPlastic" },
    } },
    { Id = "VisorShades", Name = "Visor Shades", Pieces = {
        { S = V(1.06, 0.18, 0.06), P = V(0, 0.1, -0.54), Color = "Trim", Material = "Glass", Transparency = 0.2 },
        { S = V(1.08, 0.04, 0.08), P = V(0, 0.2, -0.54), Color = C3(30, 32, 38), Material = "Metal" },
        { S = V(0.04, 0.06, 0.58), P = V(-0.54, 0.14, -0.24), Color = C3(30, 32, 38), Material = "Metal" },
        { S = V(0.04, 0.06, 0.58), P = V(0.54, 0.14, -0.24), Color = C3(30, 32, 38), Material = "Metal" },
    } },
    { Id = "TechCap", Name = "Tech Cap", HidesHair = true, Pieces = {
        { S = V(1.08, 0.3, 1.08), P = V(0, 0.5, 0.02), Color = "ShirtDark", Material = "SmoothPlastic" },
        { S = V(0.92, 0.05, 0.42), P = V(0, 0.37, -0.7), Color = "ShirtDark", Material = "SmoothPlastic" },
        { S = V(0.26, 0.07, 0.02), P = V(0, 0.52, -0.55), Color = "Trim", Material = "Neon" },
    } },
    -- drops: gear you find on the run (rarer = more tech, more glow)
    { Id = "TacHelmet", Name = "Tactical Helmet", Rarity = "Common", Unlock = DROP, HidesHair = true, Pieces = {
        { S = V(1.16, 0.44, 1.16), P = V(0, 0.48, 0.02), Color = GUNMETAL, Material = "Metal" },
        { S = V(0.08, 0.12, 0.62), P = V(-0.6, 0.36, 0), Color = CARBON, Material = "SmoothPlastic" },
        { S = V(0.08, 0.12, 0.62), P = V(0.6, 0.36, 0), Color = CARBON, Material = "SmoothPlastic" },
        { S = V(0.3, 0.16, 0.08), P = V(0, 0.56, -0.6), Color = CARBON, Material = "SmoothPlastic" },
    } },
    { Id = "CommRig", Name = "Comm Rig", Rarity = "Uncommon", Unlock = DROP, Pieces = {
        { S = V(1.1, 0.08, 0.16), P = V(0, 0.56, 0), Color = CARBON, Material = "SmoothPlastic" },
        { S = V(0.16, 0.4, 0.4), P = V(0.57, 0.02, 0), Color = CARBON, Material = "SmoothPlastic" },
        { S = V(0.03, 0.28, 0.28), P = V(0.66, 0.02, 0), Color = "Trim", Material = "Neon" },
        { S = V(0.04, 0.7, 0.04), P = V(0.6, 0.52, 0.18), Color = GUNMETAL, Material = "Metal" },
        { S = V(0.1, 0.1, 0.1), P = V(0.6, 0.9, 0.18), Color = "Trim", Material = "Neon", Ball = true },
        { S = V(0.05, 0.05, 0.5), P = V(0.5, -0.22, -0.3), R = V(0, -28, 0), Color = CARBON, Material = "SmoothPlastic" },
    } },
    { Id = "HexVisor", Name = "Hex Visor", Rarity = "Uncommon", Unlock = DROP, Pieces = {
        { S = V(1.04, 0.42, 0.08), P = V(0, 0.06, -0.55), Color = "Trim", Material = "Glass", Transparency = 0.3 },
        { S = V(1.08, 0.06, 0.1), P = V(0, 0.29, -0.55), Color = GUNMETAL, Material = "Metal" },
        { S = V(1.08, 0.06, 0.1), P = V(0, -0.17, -0.55), Color = GUNMETAL, Material = "Metal" },
        { S = V(1.1, 0.12, 1.1), P = V(0, 0.36, 0), Color = GUNMETAL, Material = "Metal" },
    } },
    { Id = "Respirator", Name = "Respirator", Rarity = "Rare", Unlock = DROP, Pieces = {
        { S = V(0.62, 0.38, 0.2), P = V(0, -0.2, -0.58), Color = CARBON, Material = "SmoothPlastic" },
        { S = V(0.2, 0.22, 0.22), P = V(-0.34, -0.25, -0.62), R = V(0, 0, 90), Color = GUNMETAL, Material = "Metal", Cyl = true },
        { S = V(0.2, 0.22, 0.22), P = V(0.34, -0.25, -0.62), R = V(0, 0, 90), Color = GUNMETAL, Material = "Metal", Cyl = true },
        { S = V(0.3, 0.04, 0.02), P = V(0, -0.16, -0.69), Color = "Trim", Material = "Neon" },
        { S = V(1.1, 0.06, 1.1), P = V(0, -0.12, 0.02), Color = CARBON, Material = "SmoothPlastic" },
    } },
    { Id = "NeonCrest", Name = "Neon Crest Helm", Rarity = "Rare", Unlock = DROP, HidesHair = true, Pieces = {
        { S = V(1.16, 0.46, 1.16), P = V(0, 0.48, 0.02), Color = C3(26, 28, 34), Material = "Metal" },
        { S = V(0.08, 0.32, 1.02), P = V(0, 0.82, 0.02), Color = "Trim", Material = "Neon" },
        { S = V(1.18, 0.05, 0.1), P = V(0, 0.28, -0.56), Color = "Trim", Material = "Neon" },
    } },
    { Id = "TargetLock", Name = "Target-Lock Visor", Rarity = "Epic", Unlock = DROP, Pieces = {
        { S = V(1.1, 0.1, 1.1), P = V(0, 0.42, 0), Color = GUNMETAL, Material = "Metal" },
        { S = V(0.42, 0.32, 0.04), P = V(-0.24, 0.1, -0.57), Color = C3(255, 70, 70), Material = "Glass", Transparency = 0.25 },
        { S = V(0.04, 0.46, 0.46), P = V(-0.24, 0.1, -0.58), R = V(0, 90, 0), Color = C3(255, 70, 70), Material = "Neon", Cyl = true, Transparency = 0.6 },
        { S = V(0.14, 0.22, 0.4), P = V(-0.6, 0.12, -0.2), Color = CARBON, Material = "Metal" },
        { S = V(0.05, 0.05, 0.05), P = V(-0.6, 0.27, -0.38), Color = C3(255, 70, 70), Material = "Neon", Ball = true },
    } },
    { Id = "PhaseCrown", Name = "Phase Crown", Rarity = "Legendary", Unlock = DROP, Pieces = {
        { S = V(0.16, 0.3, 0.06), P = V(0, 0.82, -0.48), Color = C3(120, 220, 255), Material = "Neon" },
        { S = V(0.16, 0.3, 0.06), P = V(0, 0.82, 0.48), Color = C3(120, 220, 255), Material = "Neon" },
        { S = V(0.06, 0.3, 0.16), P = V(-0.48, 0.82, 0), Color = C3(120, 220, 255), Material = "Neon" },
        { S = V(0.06, 0.3, 0.16), P = V(0.48, 0.82, 0), Color = C3(120, 220, 255), Material = "Neon" },
        { S = V(0.12, 0.22, 0.05), P = V(-0.34, 0.8, -0.34), R = V(0, 45, 0), Color = C3(200, 240, 255), Material = "Neon" },
        { S = V(0.12, 0.22, 0.05), P = V(0.34, 0.8, -0.34), R = V(0, -45, 0), Color = C3(200, 240, 255), Material = "Neon" },
        { S = V(0.12, 0.22, 0.05), P = V(-0.34, 0.8, 0.34), R = V(0, -45, 0), Color = C3(200, 240, 255), Material = "Neon" },
        { S = V(0.12, 0.22, 0.05), P = V(0.34, 0.8, 0.34), R = V(0, 45, 0), Color = C3(200, 240, 255), Material = "Neon" },
    } },
    { Id = "Singularity", Name = "Singularity Helm", Rarity = "Mythic", Unlock = DROP, HidesHair = true, Pieces = {
        { S = V(1.18, 1.18, 1.18), P = V(0, 0.04, 0), Color = C3(18, 14, 30), Material = "Glass", Transparency = 0.12 },
        { S = V(0.92, 0.08, 0.02), P = V(0, 0.12, -0.6), Color = C3(180, 100, 255), Material = "Neon" },
        { S = V(0.04, 0.5, 1.2), P = V(0, 0.4, 0), Color = C3(180, 100, 255), Material = "Neon" },
        { S = V(1.22, 0.04, 1.22), P = V(0, -0.5, 0), Color = C3(120, 60, 220), Material = "Neon" },
    } },
    -- legacy: the retired dark-fantasy line (still wearable if owned; never listed or dropped)
    { Id = "ClothHood", Name = "Cloth Hood", HidesHair = true, Pieces = {
        { S = V(1.14, 0.24, 1.14), P = V(0, 0.6, 0.02), Color = "ShirtDark", Material = "Fabric" },
        { S = V(1.14, 1.02, 0.16), P = V(0, 0.06, 0.56), Color = "ShirtDark", Material = "Fabric" },
        { S = V(0.14, 0.96, 1.0), P = V(-0.57, 0.08, 0.07), Color = "ShirtDark", Material = "Fabric" },
        { S = V(0.14, 0.96, 1.0), P = V(0.57, 0.08, 0.07), Color = "ShirtDark", Material = "Fabric" },
        { S = V(0.74, 0.14, 0.2), P = V(0, 0.55, -0.55), Color = "ShirtDark", Material = "Fabric" },
    } },
    { Id = "Headwrap", Name = "Headwrap", Pieces = {
        { S = V(1.06, 0.22, 1.06), P = V(0, 0.34, 0), Color = LINEN, Material = "Fabric" },
        { S = V(0.12, 0.36, 0.06), P = V(0.16, 0.12, 0.55), R = V(0, 0, 18), Color = LINEN, Material = "Fabric" },
    } },
    { Id = "IronCoif", Name = "Iron Coif", Rarity = "Common", Unlock = DROP, HidesHair = true, Pieces = {
        { S = V(1.14, 0.24, 1.14), P = V(0, 0.6, 0.02), Color = IRON, Material = "DiamondPlate" },
        { S = V(1.14, 1.1, 0.16), P = V(0, 0.02, 0.56), Color = IRON, Material = "DiamondPlate" },
        { S = V(0.14, 1.04, 1.0), P = V(-0.57, 0.04, 0.07), Color = IRON, Material = "DiamondPlate" },
        { S = V(0.14, 1.04, 1.0), P = V(0.57, 0.04, 0.07), Color = IRON, Material = "DiamondPlate" },
        { S = V(1.14, 0.22, 0.14), P = V(0, -0.4, -0.5), Color = IRON, Material = "DiamondPlate" },
    } },
    { Id = "BoneCirclet", Name = "Bone Circlet", Rarity = "Uncommon", Unlock = DROP, Pieces = {
        { S = V(1.06, 0.1, 1.06), P = V(0, 0.42, 0), Color = BONE, Material = "Marble" },
        { S = V(0.08, 0.22, 0.08), P = V(0, 0.56, -0.53), R = V(-10, 0, 0), Color = BONE, Material = "Marble" },
        { S = V(0.07, 0.16, 0.07), P = V(-0.26, 0.52, -0.52), R = V(-10, 0, 12), Color = BONE, Material = "Marble" },
        { S = V(0.07, 0.16, 0.07), P = V(0.26, 0.52, -0.52), R = V(-10, 0, -12), Color = BONE, Material = "Marble" },
        { S = V(0.1, 0.1, 0.04), P = V(0, 0.42, -0.55), Color = BLOOD, Material = "Glass" },
    } },
    { Id = "HornedHelm", Name = "Horned Helm", Rarity = "Rare", Unlock = DROP, HidesHair = true, Pieces = {
        { S = V(1.14, 0.56, 1.16), P = V(0, 0.44, 0.02), Color = RUST_IRON, Material = "CorrodedMetal" },
        { S = V(1.18, 0.1, 1.2), P = V(0, 0.18, 0.02), Color = IRON, Material = "Metal" },
        { S = V(0.1, 0.4, 0.08), P = V(0, 0.08, -0.58), Color = IRON, Material = "Metal" },
        { S = V(0.18, 0.42, 0.18), P = V(-0.56, 0.74, 0), R = V(0, 0, 38), Color = BONE, Material = "Marble" },
        { S = V(0.18, 0.42, 0.18), P = V(0.56, 0.74, 0), R = V(0, 0, -38), Color = BONE, Material = "Marble" },
        { S = V(0.11, 0.32, 0.11), P = V(-0.74, 1.04, 0), R = V(0, 0, 8), Color = BONE, Material = "Marble" },
        { S = V(0.11, 0.32, 0.11), P = V(0.74, 1.04, 0), R = V(0, 0, -8), Color = BONE, Material = "Marble" },
    } },
    { Id = "PlagueMask", Name = "Plague Mask", Rarity = "Rare", Unlock = DROP, Pieces = {
        { S = V(1.03, 0.66, 0.08), P = V(0, 0.04, -0.53), Color = DARK_LEATHER, Material = "Leather" },
        { S = V(0.24, 0.24, 0.62), P = V(0, -0.1, -0.84), R = V(-16, 0, 0), Color = DARK_LEATHER, Material = "Leather" },
        { S = V(0.22, 0.18, 0.05), P = V(-0.22, 0.14, -0.58), Color = C3(200, 40, 40), Material = "Glass", Transparency = 0.1 },
        { S = V(0.22, 0.18, 0.05), P = V(0.22, 0.14, -0.58), Color = C3(200, 40, 40), Material = "Glass", Transparency = 0.1 },
        { S = V(1.07, 0.12, 1.07), P = V(0, 0.16, 0), Color = BLACK, Material = "Leather" },
    } },
    { Id = "WraithHood", Name = "Wraith Hood", Rarity = "Epic", Unlock = DROP, HidesHair = true, Pieces = {
        { S = V(1.16, 0.26, 1.16), P = V(0, 0.61, 0.02), Color = BLACK, Material = "Fabric" },
        { S = V(1.16, 1.12, 0.18), P = V(0, 0.02, 0.57), Color = BLACK, Material = "Fabric" },
        { S = V(0.16, 1.06, 1.04), P = V(-0.58, 0.04, 0.06), Color = BLACK, Material = "Fabric" },
        { S = V(0.16, 1.06, 1.04), P = V(0.58, 0.04, 0.06), Color = BLACK, Material = "Fabric" },
        { S = V(0.92, 0.84, 0.04), P = V(0, 0.0, -0.51), Color = C3(6, 6, 8), Material = "SmoothPlastic" },
        { S = V(0.14, 0.06, 0.02), P = V(-0.18, 0.12, -0.54), Color = C3(90, 230, 255), Material = "Neon" },
        { S = V(0.14, 0.06, 0.02), P = V(0.18, 0.12, -0.54), Color = C3(90, 230, 255), Material = "Neon" },
    } },
    { Id = "ThornCrown", Name = "Crown of Thorns", Rarity = "Legendary", Unlock = DROP, Pieces = {
        { S = V(1.1, 0.12, 1.1), P = V(0, 0.5, 0), Color = C3(54, 36, 26), Material = "Wood" },
        { S = V(0.05, 0.22, 0.05), P = V(0, 0.62, -0.55), R = V(-25, 0, 0), Color = C3(54, 36, 26), Material = "Wood" },
        { S = V(0.05, 0.22, 0.05), P = V(0.4, 0.62, -0.4), R = V(-20, 0, -20), Color = C3(54, 36, 26), Material = "Wood" },
        { S = V(0.05, 0.22, 0.05), P = V(-0.4, 0.62, -0.4), R = V(-20, 0, 20), Color = C3(54, 36, 26), Material = "Wood" },
        { S = V(0.05, 0.22, 0.05), P = V(0.55, 0.62, 0), R = V(0, 0, -25), Color = C3(54, 36, 26), Material = "Wood" },
        { S = V(0.05, 0.22, 0.05), P = V(-0.55, 0.62, 0), R = V(0, 0, 25), Color = C3(54, 36, 26), Material = "Wood" },
        { S = V(0.05, 0.22, 0.05), P = V(0, 0.62, 0.55), R = V(25, 0, 0), Color = C3(54, 36, 26), Material = "Wood" },
        { S = V(0.06, 0.06, 0.06), P = V(0.14, 0.46, -0.56), Color = BLOOD, Material = "Glass" },
        { S = V(0.06, 0.08, 0.06), P = V(-0.3, 0.44, -0.47), Color = BLOOD, Material = "Glass" },
    } },
    { Id = "EmberCrown", Name = "Ember Crown", Rarity = "Mythic", Unlock = DROP, Pieces = {
        { S = V(0.96, 0.22, 0.96), P = V(0, 0.62, 0), Color = GOLD, Material = "Foil" },
        { S = V(0.14, 0.3, 0.14), P = V(0, 0.86, -0.42), Color = C3(255, 120, 30), Material = "Neon" },
        { S = V(0.12, 0.24, 0.12), P = V(0.36, 0.83, -0.24), Color = C3(255, 150, 40), Material = "Neon" },
        { S = V(0.12, 0.24, 0.12), P = V(-0.36, 0.83, -0.24), Color = C3(255, 150, 40), Material = "Neon" },
        { S = V(0.12, 0.24, 0.12), P = V(0.36, 0.83, 0.24), Color = C3(255, 150, 40), Material = "Neon" },
        { S = V(0.12, 0.24, 0.12), P = V(-0.36, 0.83, 0.24), Color = C3(255, 150, 40), Material = "Neon" },
        { S = V(0.12, 0.12, 0.05), P = V(0, 0.62, -0.49), Color = C3(255, 60, 30), Material = "Neon" },
    } },
}

-- ===== Tops (Attach = UpperTorso unless a piece says otherwise) =====
AvatarData.Top = {
    { Id = "None", Name = "Plain Tunic", Pieces = {} },
    -- starter (free)
    { Id = "Hoodie", Name = "Hoodie", Pieces = {
        { S = V(1.06, 1.0, 1.1), P = V(0, 0, 0), Color = "Shirt", Material = "SmoothPlastic" },
        { S = V(0.72, 0.36, 0.3), P = V(0, 0.52, 0.48), Color = "ShirtDark", Material = "SmoothPlastic" },
        { S = V(0.62, 0.24, 0.04), P = V(0, -0.3, -0.56), Color = "ShirtDark", Material = "SmoothPlastic" },
        { S = V(0.03, 0.3, 0.02), P = V(-0.12, 0.24, -0.56), Color = "Trim", Material = "Neon" },
        { S = V(0.03, 0.3, 0.02), P = V(0.12, 0.24, -0.56), Color = "Trim", Material = "Neon" },
    } },
    { Id = "TrackJacket", Name = "Track Jacket", Pieces = {
        { S = V(1.06, 1.0, 1.1), P = V(0, 0, 0), Color = "Shirt", Material = "SmoothPlastic" },
        { S = V(0.04, 0.96, 0.02), P = V(0, 0, -0.56), Color = "ShirtDark", Material = "Metal" },
        { S = V(0.84, 0.16, 0.3), P = V(0, 0.52, 0.36), Color = "ShirtDark", Material = "SmoothPlastic" },
        { Attach = "LeftUpperArm", S = V(0.08, 1.0, 0.3), P = V(-0.5, 0, 0), Color = "Trim", Material = "Neon" },
        { Attach = "RightUpperArm", S = V(0.08, 1.0, 0.3), P = V(0.5, 0, 0), Color = "Trim", Material = "Neon" },
    } },
    { Id = "TechVest", Name = "Tech Vest", Pieces = {
        { S = V(1.08, 0.82, 1.14), P = V(0, 0.02, 0), Color = "ShirtDark", Material = "SmoothPlastic" },
        { S = V(0.2, 0.22, 0.08), P = V(-0.3, -0.18, -0.6), Color = C3(34, 36, 42), Material = "SmoothPlastic" },
        { S = V(0.2, 0.22, 0.08), P = V(0, -0.18, -0.6), Color = C3(34, 36, 42), Material = "SmoothPlastic" },
        { S = V(0.2, 0.22, 0.08), P = V(0.3, -0.18, -0.6), Color = C3(34, 36, 42), Material = "SmoothPlastic" },
        { S = V(0.3, 0.04, 0.02), P = V(0, 0.28, -0.58), Color = "Trim", Material = "Neon" },
    } },
    -- drops
    { Id = "PlateCarrier", Name = "Plate Carrier", Rarity = "Common", Unlock = DROP, Pieces = {
        { S = V(0.74, 0.72, 0.1), P = V(0, 0.06, -0.58), Color = OLIVE_TECH, Material = "SmoothPlastic" },
        { S = V(0.74, 0.72, 0.1), P = V(0, 0.06, 0.58), Color = OLIVE_TECH, Material = "SmoothPlastic" },
        { S = V(1.1, 0.3, 1.14), P = V(0, -0.26, 0), Color = OLIVE_TECH, Material = "SmoothPlastic" },
        { S = V(0.14, 0.24, 1.16), P = V(-0.3, 0.46, 0), Color = OLIVE_TECH, Material = "SmoothPlastic" },
        { S = V(0.14, 0.24, 1.16), P = V(0.3, 0.46, 0), Color = OLIVE_TECH, Material = "SmoothPlastic" },
    } },
    { Id = "CyberHarness", Name = "Cyber Harness", Rarity = "Uncommon", Unlock = DROP, Pieces = {
        { S = V(0.1, 1.22, 0.04), P = V(0, 0, -0.55), R = V(0, 0, 32), Color = CARBON, Material = "SmoothPlastic" },
        { S = V(0.1, 1.22, 0.04), P = V(0, 0, -0.55), R = V(0, 0, -32), Color = CARBON, Material = "SmoothPlastic" },
        { S = V(0.1, 1.22, 0.04), P = V(0, 0, 0.55), R = V(0, 0, 32), Color = CARBON, Material = "SmoothPlastic" },
        { S = V(0.1, 1.22, 0.04), P = V(0, 0, 0.55), R = V(0, 0, -32), Color = CARBON, Material = "SmoothPlastic" },
        { S = V(0.04, 0.32, 0.32), P = V(0, 0.02, -0.58), R = V(0, 90, 0), Color = "Trim", Material = "Neon", Cyl = true },
    } },
    { Id = "ShoulderRig", Name = "Shoulder Rig", Rarity = "Uncommon", Unlock = DROP, Pieces = {
        { Attach = "LeftUpperArm", S = V(1.32, 0.46, 1.3), P = V(-0.06, 0.42, 0), R = V(0, 0, 14), Color = GUNMETAL, Material = "Metal" },
        { Attach = "LeftUpperArm", S = V(1.34, 0.05, 1.32), P = V(-0.06, 0.2, 0), R = V(0, 0, 14), Color = "Trim", Material = "Neon" },
        { S = V(0.14, 1.2, 0.05), P = V(0, 0, -0.54), R = V(0, 0, -34), Color = CARBON, Material = "SmoothPlastic" },
        { S = V(0.14, 1.2, 0.05), P = V(0, 0, 0.54), R = V(0, 0, 34), Color = CARBON, Material = "SmoothPlastic" },
    } },
    { Id = "RunnerJacket", Name = "Runner Jacket", Rarity = "Rare", Unlock = DROP, Pieces = {
        { S = V(1.08, 0.9, 1.12), P = V(0, 0.05, 0), Color = C3(236, 238, 244), Material = "SmoothPlastic" },
        { S = V(1.1, 0.04, 1.14), P = V(0, -0.39, 0), Color = "Trim", Material = "Neon" },
        { S = V(0.9, 0.2, 0.32), P = V(0, 0.52, 0.38), Color = C3(236, 238, 244), Material = "SmoothPlastic" },
        { S = V(0.04, 0.86, 0.02), P = V(0.1, 0.05, -0.57), Color = "Trim", Material = "Neon" },
        { Attach = "LeftUpperArm", S = V(1.08, 1.02, 1.08), P = V(0, 0, 0), Color = C3(236, 238, 244), Material = "SmoothPlastic" },
        { Attach = "RightUpperArm", S = V(1.08, 1.02, 1.08), P = V(0, 0, 0), Color = C3(236, 238, 244), Material = "SmoothPlastic" },
        { Attach = "LeftUpperArm", S = V(0.06, 1.02, 1.1), P = V(-0.52, 0, 0), Color = "Trim", Material = "Neon" },
        { Attach = "RightUpperArm", S = V(0.06, 1.02, 1.1), P = V(0.52, 0, 0), Color = "Trim", Material = "Neon" },
    } },
    { Id = "ExoFrame", Name = "Exo Frame", Rarity = "Rare", Unlock = DROP, Pieces = {
        { S = V(0.16, 1.12, 0.14), P = V(0, 0, 0.58), Color = GUNMETAL, Material = "Metal" },
        { S = V(1.1, 0.07, 0.08), P = V(0, 0.3, 0.57), Color = GUNMETAL, Material = "Metal" },
        { S = V(1.1, 0.07, 0.08), P = V(0, 0, 0.57), Color = GUNMETAL, Material = "Metal" },
        { S = V(1.1, 0.07, 0.08), P = V(0, -0.3, 0.57), Color = GUNMETAL, Material = "Metal" },
        { S = V(0.22, 0.22, 0.05), P = V(0, 0.32, 0.65), Color = "Trim", Material = "Neon" },
        { Attach = "LeftUpperArm", S = V(0.14, 0.8, 0.14), P = V(-0.5, 0.05, 0.4), Color = GUNMETAL, Material = "Metal" },
        { Attach = "RightUpperArm", S = V(0.14, 0.8, 0.14), P = V(0.5, 0.05, 0.4), Color = GUNMETAL, Material = "Metal" },
    } },
    { Id = "HoloCape", Name = "Holo Cape", Rarity = "Epic", Unlock = DROP, Pieces = {
        { S = V(0.98, 1.75, 0.04), P = V(0, -0.38, 0.6), R = V(7, 0, 0), Color = "Trim", Material = "Glass", Transparency = 0.45 },
        { S = V(1.0, 0.05, 0.07), P = V(0, 0.46, 0.58), Color = "Trim", Material = "Neon" },
        { S = V(0.03, 1.72, 0.06), P = V(-0.49, -0.38, 0.61), R = V(7, 0, 0), Color = "Trim", Material = "Neon" },
        { S = V(0.03, 1.72, 0.06), P = V(0.49, -0.38, 0.61), R = V(7, 0, 0), Color = "Trim", Material = "Neon" },
        { S = V(0.2, 0.2, 0.08), P = V(-0.38, 0.42, -0.56), Color = GUNMETAL, Material = "Metal", Ball = true },
        { S = V(0.2, 0.2, 0.08), P = V(0.38, 0.42, -0.56), Color = GUNMETAL, Material = "Metal", Ball = true },
    } },
    { Id = "ReactorVest", Name = "Reactor Vest", Rarity = "Legendary", Unlock = DROP, Pieces = {
        { S = V(1.1, 0.98, 1.16), P = V(0, 0.01, 0), Color = C3(32, 34, 42), Material = "Metal" },
        { S = V(0.12, 0.44, 0.44), P = V(0, 0.12, -0.6), R = V(0, 90, 0), Color = C3(90, 230, 255), Material = "Neon", Cyl = true },
        { S = V(0.14, 0.56, 0.56), P = V(0, 0.12, -0.58), R = V(0, 90, 0), Color = GUNMETAL, Material = "Metal", Cyl = true },
        { S = V(0.04, 0.5, 0.02), P = V(-0.32, -0.12, -0.59), Color = C3(90, 230, 255), Material = "Neon" },
        { S = V(0.04, 0.5, 0.02), P = V(0.32, -0.12, -0.59), Color = C3(90, 230, 255), Material = "Neon" },
        { Attach = "LeftUpperArm", S = V(1.3, 0.44, 1.28), P = V(-0.05, 0.42, 0), R = V(0, 0, 12), Color = C3(32, 34, 42), Material = "Metal" },
        { Attach = "RightUpperArm", S = V(1.3, 0.44, 1.28), P = V(0.05, 0.42, 0), R = V(0, 0, -12), Color = C3(32, 34, 42), Material = "Metal" },
        { S = V(0.5, 0.3, 0.08), P = V(0, 0.2, 0.6), Color = C3(90, 230, 255), Material = "Neon", Transparency = 0.3 },
    } },
    { Id = "Overclock", Name = "Overclock Exosuit", Rarity = "Mythic", Unlock = DROP, Pieces = {
        { S = V(1.1, 1.0, 1.16), P = V(0, 0, 0), Color = C3(18, 18, 24), Material = "Metal" },
        { S = V(0.04, 0.9, 0.02), P = V(-0.18, 0, -0.59), Color = C3(255, 60, 200), Material = "Neon" },
        { S = V(0.04, 0.9, 0.02), P = V(0.18, 0, -0.59), Color = C3(60, 230, 255), Material = "Neon" },
        { S = V(0.42, 0.04, 0.02), P = V(0, 0.18, -0.59), Color = C3(200, 120, 255), Material = "Neon" },
        { S = V(0.04, 0.9, 0.02), P = V(0, 0, 0.59), Color = C3(200, 120, 255), Material = "Neon" },
        { Attach = "LeftUpperArm", S = V(1.36, 0.5, 1.32), P = V(-0.06, 0.42, 0), R = V(0, 0, 16), Color = C3(18, 18, 24), Material = "Metal" },
        { Attach = "RightUpperArm", S = V(1.36, 0.5, 1.32), P = V(0.06, 0.42, 0), R = V(0, 0, -16), Color = C3(18, 18, 24), Material = "Metal" },
        { Attach = "LeftUpperArm", S = V(1.38, 0.05, 1.34), P = V(-0.06, 0.2, 0), R = V(0, 0, 16), Color = C3(255, 60, 200), Material = "Neon" },
        { Attach = "RightUpperArm", S = V(1.38, 0.05, 1.34), P = V(0.06, 0.2, 0), R = V(0, 0, -16), Color = C3(60, 230, 255), Material = "Neon" },
        { S = V(0.26, 0.5, 0.2), P = V(-0.3, 0.1, 0.66), Color = GUNMETAL, Material = "Metal" },
        { S = V(0.26, 0.5, 0.2), P = V(0.3, 0.1, 0.66), Color = GUNMETAL, Material = "Metal" },
        { S = V(0.2, 0.06, 0.16), P = V(-0.3, -0.18, 0.66), Color = C3(255, 60, 200), Material = "Neon" },
        { S = V(0.2, 0.06, 0.16), P = V(0.3, -0.18, 0.66), Color = C3(60, 230, 255), Material = "Neon" },
    } },
    -- legacy: the retired dark-fantasy line (still wearable if owned; never listed or dropped)
    { Id = "Jerkin", Name = "Leather Jerkin", Pieces = {
        { S = V(1.04, 0.86, 1.1), P = V(0, -0.02, 0), Color = LEATHER, Material = "Leather" },
        { S = V(0.04, 0.55, 0.02), P = V(0, 0.04, -0.56), Color = DARK_LEATHER, Material = "Leather" },
    } },
    { Id = "RopeSash", Name = "Rope Sash", Pieces = {
        { S = V(0.12, 1.18, 0.06), P = V(0, 0, -0.53), R = V(0, 0, 34), Color = C3(150, 122, 82), Material = "Fabric" },
        { S = V(0.12, 1.18, 0.06), P = V(0, 0, 0.53), R = V(0, 0, -34), Color = C3(150, 122, 82), Material = "Fabric" },
    } },
    { Id = "TravelCloak", Name = "Traveler's Cloak", Pieces = {
        { S = V(1.08, 0.18, 1.12), P = V(0, 0.48, 0.02), Color = "ShirtDark", Material = "Fabric" },
        { S = V(0.96, 1.5, 0.08), P = V(0, -0.24, 0.6), R = V(7, 0, 0), Color = "ShirtDark", Material = "Fabric" },
    } },
    { Id = "Chainmail", Name = "Chainmail Shirt", Rarity = "Common", Unlock = DROP, Pieces = {
        { S = V(1.04, 1.04, 1.08), P = V(0, 0, 0), Color = IRON, Material = "DiamondPlate" },
        { Attach = "LeftUpperArm", S = V(1.07, 1.02, 1.07), P = V(0, 0, 0), Color = IRON, Material = "DiamondPlate" },
        { Attach = "RightUpperArm", S = V(1.07, 1.02, 1.07), P = V(0, 0, 0), Color = IRON, Material = "DiamondPlate" },
    } },
    { Id = "Cuirass", Name = "Leather Cuirass", Rarity = "Uncommon", Unlock = DROP, Pieces = {
        { S = V(1.06, 0.92, 1.12), P = V(0, 0.02, 0), Color = DARK_LEATHER, Material = "Leather" },
        { S = V(0.14, 0.2, 1.16), P = V(-0.3, 0.52, 0), Color = DARK_LEATHER, Material = "Leather" },
        { S = V(0.14, 0.2, 1.16), P = V(0.3, 0.52, 0), Color = DARK_LEATHER, Material = "Leather" },
        { S = V(1.08, 0.08, 1.14), P = V(0, -0.2, 0), Color = C3(150, 120, 70), Material = "Metal" },
    } },
    { Id = "Tabard", Name = "Templar Tabard", Rarity = "Uncommon", Unlock = DROP, Pieces = {
        { S = V(0.6, 1.08, 0.04), P = V(0, -0.02, -0.53), Color = BLOOD, Material = "Fabric" },
        { S = V(0.6, 1.08, 0.04), P = V(0, -0.02, 0.53), Color = BLOOD, Material = "Fabric" },
        { S = V(0.08, 0.6, 0.02), P = V(0, 0.08, -0.56), Color = GOLD, Material = "Foil" },
        { S = V(0.36, 0.08, 0.02), P = V(0, 0.18, -0.56), Color = GOLD, Material = "Foil" },
    } },
    { Id = "Pauldrons", Name = "Iron Pauldrons", Rarity = "Rare", Unlock = DROP, Pieces = {
        { Attach = "LeftUpperArm", S = V(1.3, 0.46, 1.28), P = V(-0.05, 0.42, 0), R = V(0, 0, 12), Color = RUST_IRON, Material = "CorrodedMetal" },
        { Attach = "RightUpperArm", S = V(1.3, 0.46, 1.28), P = V(0.05, 0.42, 0), R = V(0, 0, -12), Color = RUST_IRON, Material = "CorrodedMetal" },
        { S = V(0.14, 1.18, 0.05), P = V(0, 0, -0.53), R = V(0, 0, 34), Color = DARK_LEATHER, Material = "Leather" },
    } },
    { Id = "BonePauldrons", Name = "Bone Pauldrons", Rarity = "Rare", Unlock = DROP, Pieces = {
        { Attach = "LeftUpperArm", S = V(1.26, 0.38, 1.24), P = V(-0.04, 0.44, 0), R = V(0, 0, 14), Color = BONE, Material = "Marble" },
        { Attach = "RightUpperArm", S = V(1.26, 0.38, 1.24), P = V(0.04, 0.44, 0), R = V(0, 0, -14), Color = BONE, Material = "Marble" },
        { Attach = "LeftUpperArm", S = V(0.14, 0.4, 0.14), P = V(-0.35, 0.72, 0), R = V(0, 0, 30), Color = BONE, Material = "Marble" },
        { Attach = "RightUpperArm", S = V(0.14, 0.4, 0.14), P = V(0.35, 0.72, 0), R = V(0, 0, -30), Color = BONE, Material = "Marble" },
        { S = V(0.5, 0.1, 0.05), P = V(0, 0.38, -0.53), Color = BONE, Material = "Marble" },
    } },
    { Id = "PlateCuirass", Name = "Plate Cuirass", Rarity = "Epic", Unlock = DROP, Pieces = {
        { S = V(1.08, 0.98, 1.14), P = V(0, 0.01, 0), Color = STEEL, Material = "Metal" },
        { S = V(0.7, 0.16, 1.16), P = V(0, 0.5, 0), Color = IRON, Material = "Metal" },
        { S = V(0.06, 0.8, 0.02), P = V(0, -0.02, -0.58), Color = GOLD, Material = "Foil" },
        { Attach = "LeftUpperArm", S = V(1.28, 0.44, 1.26), P = V(-0.04, 0.42, 0), R = V(0, 0, 10), Color = STEEL, Material = "Metal" },
        { Attach = "RightUpperArm", S = V(1.28, 0.44, 1.26), P = V(0.04, 0.42, 0), R = V(0, 0, -10), Color = STEEL, Material = "Metal" },
    } },
    { Id = "ShadowCloak", Name = "Shadow Cloak", Rarity = "Legendary", Unlock = DROP, Pieces = {
        { S = V(1.12, 0.2, 1.16), P = V(0, 0.5, 0.02), Color = BLACK, Material = "Fabric" },
        { S = V(1.04, 1.9, 0.08), P = V(0, -0.42, 0.62), R = V(6, 0, 0), Color = BLACK, Material = "Fabric" },
        { S = V(1.06, 0.05, 0.1), P = V(0, -1.36, 0.69), R = V(6, 0, 0), Color = C3(150, 70, 255), Material = "Neon" },
        { S = V(0.05, 1.9, 0.1), P = V(-0.52, -0.42, 0.63), R = V(6, 0, 0), Color = C3(150, 70, 255), Material = "Neon" },
        { S = V(0.05, 1.9, 0.1), P = V(0.52, -0.42, 0.63), R = V(6, 0, 0), Color = C3(150, 70, 255), Material = "Neon" },
    } },
    { Id = "VoidMantle", Name = "Voidforged Mantle", Rarity = "Mythic", Unlock = DROP, Pieces = {
        { S = V(1.08, 0.98, 1.14), P = V(0, 0.01, 0), Color = C3(26, 22, 36), Material = "Metal" },
        { S = V(0.05, 0.7, 0.02), P = V(0, 0.0, -0.58), Color = C3(170, 80, 255), Material = "Neon" },
        { S = V(0.4, 0.05, 0.02), P = V(0, 0.2, -0.58), Color = C3(170, 80, 255), Material = "Neon" },
        { S = V(0.05, 0.3, 0.02), P = V(-0.2, -0.12, -0.58), R = V(0, 0, 30), Color = C3(170, 80, 255), Material = "Neon" },
        { S = V(0.05, 0.3, 0.02), P = V(0.2, -0.12, -0.58), R = V(0, 0, -30), Color = C3(170, 80, 255), Material = "Neon" },
        { Attach = "LeftUpperArm", S = V(1.34, 0.5, 1.3), P = V(-0.06, 0.42, 0), R = V(0, 0, 16), Color = C3(26, 22, 36), Material = "Metal" },
        { Attach = "RightUpperArm", S = V(1.34, 0.5, 1.3), P = V(0.06, 0.42, 0), R = V(0, 0, -16), Color = C3(26, 22, 36), Material = "Metal" },
        { Attach = "LeftUpperArm", S = V(0.16, 0.5, 0.16), P = V(-0.4, 0.82, 0), R = V(0, 0, 28), Color = C3(170, 80, 255), Material = "Neon" },
        { Attach = "RightUpperArm", S = V(0.16, 0.5, 0.16), P = V(0.4, 0.82, 0), R = V(0, 0, -28), Color = C3(170, 80, 255), Material = "Neon" },
        { S = V(1.0, 1.8, 0.06), P = V(0, -0.4, 0.62), R = V(6, 0, 0), Color = C3(40, 20, 70), Material = "Glass", Transparency = 0.25 },
    } },
}

-- ===== Bottoms (Attach = LowerTorso unless a piece says otherwise) =====
AvatarData.Bottom = {
    { Id = "None", Name = "Plain Trousers", Pieces = {} },
    -- starter (free)
    { Id = "Joggers", Name = "Joggers", Pieces = {
        { Attach = "LeftLowerLeg", S = V(1.08, 0.16, 1.08), P = V(0, -0.4, 0), Color = "PantsDark", Material = "SmoothPlastic" },
        { Attach = "RightLowerLeg", S = V(1.08, 0.16, 1.08), P = V(0, -0.4, 0), Color = "PantsDark", Material = "SmoothPlastic" },
        { Attach = "LeftUpperLeg", S = V(0.04, 1.0, 0.24), P = V(-0.52, 0, 0), Color = "Trim", Material = "Neon" },
        { Attach = "RightUpperLeg", S = V(0.04, 1.0, 0.24), P = V(0.52, 0, 0), Color = "Trim", Material = "Neon" },
    } },
    { Id = "Cargo", Name = "Cargo Pants", Pieces = {
        { S = V(1.04, 0.32, 1.06), P = V(0, 0.2, 0), Color = C3(30, 32, 36), Material = "SmoothPlastic" },
        { S = V(0.14, 0.24, 0.04), P = V(0, 0.2, -0.55), Color = "Trim", Material = "Neon" },
        { Attach = "LeftUpperLeg", S = V(0.1, 0.38, 0.46), P = V(-0.55, -0.1, 0), Color = "PantsDark", Material = "SmoothPlastic" },
        { Attach = "RightUpperLeg", S = V(0.1, 0.38, 0.46), P = V(0.55, -0.1, 0), Color = "PantsDark", Material = "SmoothPlastic" },
    } },
    { Id = "Sneakers", Name = "Glow Sneakers", Pieces = {
        { Attach = "LeftFoot", S = V(1.12, 1.2, 1.2), P = V(0, 0.06, -0.03), Color = C3(236, 238, 244), Material = "SmoothPlastic" },
        { Attach = "RightFoot", S = V(1.12, 1.2, 1.2), P = V(0, 0.06, -0.03), Color = C3(236, 238, 244), Material = "SmoothPlastic" },
        { Attach = "LeftFoot", S = V(1.14, 0.3, 1.24), P = V(0, -0.42, -0.03), Color = "Trim", Material = "Neon" },
        { Attach = "RightFoot", S = V(1.14, 0.3, 1.24), P = V(0, -0.42, -0.03), Color = "Trim", Material = "Neon" },
    } },
    -- drops
    { Id = "KneePads", Name = "Knee Pads", Rarity = "Common", Unlock = DROP, Pieces = {
        { Attach = "LeftLowerLeg", S = V(0.84, 0.34, 0.22), P = V(0, 0.36, -0.52), Color = CARBON, Material = "SmoothPlastic" },
        { Attach = "RightLowerLeg", S = V(0.84, 0.34, 0.22), P = V(0, 0.36, -0.52), Color = CARBON, Material = "SmoothPlastic" },
        { Attach = "LeftLowerLeg", S = V(1.06, 0.12, 1.06), P = V(0, 0.36, 0), Color = CARBON, Material = "SmoothPlastic" },
        { Attach = "RightLowerLeg", S = V(1.06, 0.12, 1.06), P = V(0, 0.36, 0), Color = CARBON, Material = "SmoothPlastic" },
    } },
    { Id = "UtilityBelt", Name = "Utility Belt", Rarity = "Uncommon", Unlock = DROP, Pieces = {
        { S = V(1.06, 0.34, 1.08), P = V(0, 0.18, 0), Color = OLIVE_TECH, Material = "SmoothPlastic" },
        { S = V(0.2, 0.3, 0.14), P = V(-0.34, 0.14, -0.58), Color = OLIVE_TECH, Material = "SmoothPlastic" },
        { S = V(0.2, 0.3, 0.14), P = V(0.34, 0.14, -0.58), Color = OLIVE_TECH, Material = "SmoothPlastic" },
        { Attach = "RightUpperLeg", S = V(0.16, 0.66, 0.56), P = V(0.56, 0.06, 0), Color = CARBON, Material = "SmoothPlastic" },
        { Attach = "RightUpperLeg", S = V(0.04, 0.4, 0.04), P = V(0.65, 0.06, -0.18), Color = "Trim", Material = "Neon" },
    } },
    { Id = "RunnerBoots", Name = "Runner Boots", Rarity = "Rare", Unlock = DROP, Pieces = {
        { Attach = "LeftFoot", S = V(1.14, 1.4, 1.2), P = V(0, 0.12, -0.02), Color = C3(24, 26, 30), Material = "SmoothPlastic" },
        { Attach = "RightFoot", S = V(1.14, 1.4, 1.2), P = V(0, 0.12, -0.02), Color = C3(24, 26, 30), Material = "SmoothPlastic" },
        { Attach = "LeftLowerLeg", S = V(1.1, 0.5, 1.1), P = V(0, -0.26, 0), Color = C3(24, 26, 30), Material = "SmoothPlastic" },
        { Attach = "RightLowerLeg", S = V(1.1, 0.5, 1.1), P = V(0, -0.26, 0), Color = C3(24, 26, 30), Material = "SmoothPlastic" },
        { Attach = "LeftFoot", S = V(1.16, 0.2, 1.26), P = V(0, -0.5, -0.02), Color = "Trim", Material = "Neon" },
        { Attach = "RightFoot", S = V(1.16, 0.2, 1.26), P = V(0, -0.5, -0.02), Color = "Trim", Material = "Neon" },
    } },
    { Id = "ExoLegs", Name = "Exo Legs", Rarity = "Rare", Unlock = DROP, Pieces = {
        { Attach = "LeftUpperLeg", S = V(0.12, 0.92, 0.14), P = V(-0.56, 0, 0), Color = GUNMETAL, Material = "Metal" },
        { Attach = "RightUpperLeg", S = V(0.12, 0.92, 0.14), P = V(0.56, 0, 0), Color = GUNMETAL, Material = "Metal" },
        { Attach = "LeftLowerLeg", S = V(0.12, 0.92, 0.14), P = V(-0.56, 0, 0), Color = GUNMETAL, Material = "Metal" },
        { Attach = "RightLowerLeg", S = V(0.12, 0.92, 0.14), P = V(0.56, 0, 0), Color = GUNMETAL, Material = "Metal" },
        { Attach = "LeftLowerLeg", S = V(0.3, 0.3, 0.3), P = V(-0.56, 0.5, 0), Color = "Trim", Material = "Neon", Ball = true },
        { Attach = "RightLowerLeg", S = V(0.3, 0.3, 0.3), P = V(0.56, 0.5, 0), Color = "Trim", Material = "Neon", Ball = true },
    } },
    { Id = "HoverGreaves", Name = "Hover Greaves", Rarity = "Epic", Unlock = DROP, Pieces = {
        { Attach = "LeftLowerLeg", S = V(1.1, 0.88, 1.1), P = V(0, 0.02, 0), Color = C3(40, 44, 54), Material = "Metal" },
        { Attach = "RightLowerLeg", S = V(1.1, 0.88, 1.1), P = V(0, 0.02, 0), Color = C3(40, 44, 54), Material = "Metal" },
        { Attach = "LeftFoot", S = V(1.12, 1.2, 1.2), P = V(0, 0.06, -0.02), Color = C3(40, 44, 54), Material = "Metal" },
        { Attach = "RightFoot", S = V(1.12, 1.2, 1.2), P = V(0, 0.06, -0.02), Color = C3(40, 44, 54), Material = "Metal" },
        { Attach = "LeftFoot", S = V(0.9, 0.24, 0.9), P = V(0, -0.62, 0), Color = C3(90, 230, 255), Material = "Neon", Transparency = 0.25 },
        { Attach = "RightFoot", S = V(0.9, 0.24, 0.9), P = V(0, -0.62, 0), Color = C3(90, 230, 255), Material = "Neon", Transparency = 0.25 },
        { Attach = "LeftLowerLeg", S = V(0.05, 0.7, 0.02), P = V(0, 0.02, -0.57), Color = C3(90, 230, 255), Material = "Neon" },
        { Attach = "RightLowerLeg", S = V(0.05, 0.7, 0.02), P = V(0, 0.02, -0.57), Color = C3(90, 230, 255), Material = "Neon" },
    } },
    { Id = "KineticStriders", Name = "Kinetic Striders", Rarity = "Legendary", Unlock = DROP, Pieces = {
        { Attach = "LeftUpperLeg", S = V(1.1, 1.02, 1.1), P = V(0, 0, 0), Color = C3(22, 22, 26), Material = "Metal" },
        { Attach = "RightUpperLeg", S = V(1.1, 1.02, 1.1), P = V(0, 0, 0), Color = C3(22, 22, 26), Material = "Metal" },
        { Attach = "LeftLowerLeg", S = V(1.1, 0.9, 1.1), P = V(0, 0, 0), Color = C3(22, 22, 26), Material = "Metal" },
        { Attach = "RightLowerLeg", S = V(1.1, 0.9, 1.1), P = V(0, 0, 0), Color = C3(22, 22, 26), Material = "Metal" },
        { Attach = "LeftUpperLeg", S = V(0.05, 0.9, 0.02), P = V(0.12, 0, -0.57), R = V(0, 0, 12), Color = C3(255, 220, 60), Material = "Neon" },
        { Attach = "RightUpperLeg", S = V(0.05, 0.9, 0.02), P = V(-0.12, 0, -0.57), R = V(0, 0, -12), Color = C3(255, 220, 60), Material = "Neon" },
        { Attach = "LeftLowerLeg", S = V(0.05, 0.8, 0.02), P = V(-0.1, 0, -0.57), R = V(0, 0, -14), Color = C3(255, 220, 60), Material = "Neon" },
        { Attach = "RightLowerLeg", S = V(0.05, 0.8, 0.02), P = V(0.1, 0, -0.57), R = V(0, 0, 14), Color = C3(255, 220, 60), Material = "Neon" },
        { Attach = "LeftFoot", S = V(1.14, 1.3, 1.22), P = V(0, 0.08, -0.02), Color = C3(22, 22, 26), Material = "Metal" },
        { Attach = "RightFoot", S = V(1.14, 1.3, 1.22), P = V(0, 0.08, -0.02), Color = C3(22, 22, 26), Material = "Metal" },
    } },
    { Id = "PhaseTreads", Name = "Phase Treads", Rarity = "Mythic", Unlock = DROP, Pieces = {
        { Attach = "LeftUpperLeg", S = V(1.12, 1.02, 1.12), P = V(0, 0, 0), Color = C3(120, 90, 255), Material = "Glass", Transparency = 0.4 },
        { Attach = "RightUpperLeg", S = V(1.12, 1.02, 1.12), P = V(0, 0, 0), Color = C3(120, 90, 255), Material = "Glass", Transparency = 0.4 },
        { Attach = "LeftLowerLeg", S = V(1.12, 0.92, 1.12), P = V(0, 0, 0), Color = C3(120, 90, 255), Material = "Glass", Transparency = 0.4 },
        { Attach = "RightLowerLeg", S = V(1.12, 0.92, 1.12), P = V(0, 0, 0), Color = C3(120, 90, 255), Material = "Glass", Transparency = 0.4 },
        { Attach = "LeftLowerLeg", S = V(1.16, 0.06, 1.16), P = V(0, 0.46, 0), Color = C3(200, 160, 255), Material = "Neon" },
        { Attach = "RightLowerLeg", S = V(1.16, 0.06, 1.16), P = V(0, 0.46, 0), Color = C3(200, 160, 255), Material = "Neon" },
        { Attach = "LeftLowerLeg", S = V(1.16, 0.06, 1.16), P = V(0, -0.46, 0), Color = C3(200, 160, 255), Material = "Neon" },
        { Attach = "RightLowerLeg", S = V(1.16, 0.06, 1.16), P = V(0, -0.46, 0), Color = C3(200, 160, 255), Material = "Neon" },
        { Attach = "LeftFoot", S = V(1.16, 1.3, 1.22), P = V(0, 0.08, -0.02), Color = C3(30, 20, 60), Material = "Glass", Transparency = 0.2 },
        { Attach = "RightFoot", S = V(1.16, 1.3, 1.22), P = V(0, 0.08, -0.02), Color = C3(30, 20, 60), Material = "Glass", Transparency = 0.2 },
        { Attach = "LeftFoot", S = V(1.18, 0.16, 1.26), P = V(0, -0.52, -0.02), Color = C3(200, 160, 255), Material = "Neon" },
        { Attach = "RightFoot", S = V(1.18, 0.16, 1.26), P = V(0, -0.52, -0.02), Color = C3(200, 160, 255), Material = "Neon" },
    } },
    -- legacy: the retired dark-fantasy line (still wearable if owned; never listed or dropped)
    { Id = "Belt", Name = "Leather Belt", Pieces = {
        { S = V(1.04, 0.4, 1.06), P = V(0, 0.15, 0), Color = DARK_LEATHER, Material = "Leather" },
        { S = V(0.16, 0.3, 0.04), P = V(0, 0.15, -0.54), Color = C3(150, 120, 70), Material = "Metal" },
    } },
    { Id = "LegWraps", Name = "Leg Wraps", Pieces = {
        { Attach = "LeftLowerLeg", S = V(1.06, 0.78, 1.06), P = V(0, 0.02, 0), Color = LINEN, Material = "Fabric" },
        { Attach = "RightLowerLeg", S = V(1.06, 0.78, 1.06), P = V(0, 0.02, 0), Color = LINEN, Material = "Fabric" },
    } },
    { Id = "WornBoots", Name = "Worn Boots", Pieces = {
        { Attach = "LeftFoot", S = V(1.1, 1.3, 1.12), P = V(0, 0.1, 0), Color = LEATHER, Material = "Leather" },
        { Attach = "RightFoot", S = V(1.1, 1.3, 1.12), P = V(0, 0.1, 0), Color = LEATHER, Material = "Leather" },
        { Attach = "LeftLowerLeg", S = V(1.06, 0.32, 1.06), P = V(0, -0.34, 0), Color = LEATHER, Material = "Leather" },
        { Attach = "RightLowerLeg", S = V(1.06, 0.32, 1.06), P = V(0, -0.34, 0), Color = LEATHER, Material = "Leather" },
    } },
    { Id = "PouchBelt", Name = "Pouch Belt", Rarity = "Common", Unlock = DROP, Pieces = {
        { S = V(1.04, 0.4, 1.06), P = V(0, 0.15, 0), Color = DARK_LEATHER, Material = "Leather" },
        { S = V(0.2, 0.55, 0.16), P = V(-0.32, -0.15, -0.56), Color = LEATHER, Material = "Leather" },
        { S = V(0.2, 0.55, 0.16), P = V(0.32, -0.15, -0.56), Color = LEATHER, Material = "Leather" },
        { S = V(0.22, 0.6, 0.18), P = V(0.45, -0.1, 0.3), Color = LEATHER, Material = "Leather" },
    } },
    { Id = "Faulds", Name = "Iron Faulds", Rarity = "Uncommon", Unlock = DROP, Pieces = {
        { S = V(1.05, 0.4, 1.07), P = V(0, 0.15, 0), Color = DARK_LEATHER, Material = "Leather" },
        { S = V(0.46, 1.5, 0.06), P = V(-0.25, -0.8, -0.54), R = V(-6, 0, 0), Color = IRON, Material = "Metal" },
        { S = V(0.46, 1.5, 0.06), P = V(0.25, -0.8, -0.54), R = V(-6, 0, 0), Color = IRON, Material = "Metal" },
        { S = V(0.9, 1.4, 0.06), P = V(0, -0.75, 0.54), R = V(6, 0, 0), Color = IRON, Material = "Metal" },
    } },
    { Id = "Greaves", Name = "Greaves", Rarity = "Rare", Unlock = DROP, Pieces = {
        { Attach = "LeftLowerLeg", S = V(0.86, 0.82, 0.22), P = V(0, 0.04, -0.5), Color = RUST_IRON, Material = "CorrodedMetal" },
        { Attach = "RightLowerLeg", S = V(0.86, 0.82, 0.22), P = V(0, 0.04, -0.5), Color = RUST_IRON, Material = "CorrodedMetal" },
        { Attach = "LeftUpperLeg", S = V(0.8, 0.3, 0.24), P = V(0, -0.38, -0.5), Color = RUST_IRON, Material = "CorrodedMetal" },
        { Attach = "RightUpperLeg", S = V(0.8, 0.3, 0.24), P = V(0, -0.38, -0.5), Color = RUST_IRON, Material = "CorrodedMetal" },
    } },
    { Id = "IronBoots", Name = "Iron Boots", Rarity = "Rare", Unlock = DROP, Pieces = {
        { Attach = "LeftFoot", S = V(1.14, 1.4, 1.16), P = V(0, 0.12, 0), Color = STEEL, Material = "Metal" },
        { Attach = "RightFoot", S = V(1.14, 1.4, 1.16), P = V(0, 0.12, 0), Color = STEEL, Material = "Metal" },
        { Attach = "LeftLowerLeg", S = V(1.1, 0.42, 1.1), P = V(0, -0.3, 0), Color = STEEL, Material = "Metal" },
        { Attach = "RightLowerLeg", S = V(1.1, 0.42, 1.1), P = V(0, -0.3, 0), Color = STEEL, Material = "Metal" },
    } },
    { Id = "BoneSkirt", Name = "Bone Skirt", Rarity = "Epic", Unlock = DROP, Pieces = {
        { S = V(1.05, 0.4, 1.07), P = V(0, 0.15, 0), Color = BLACK, Material = "Leather" },
        { S = V(0.16, 1.6, 0.06), P = V(-0.38, -0.85, -0.55), Color = BONE, Material = "Marble" },
        { S = V(0.16, 1.8, 0.06), P = V(-0.13, -0.95, -0.55), Color = BONE, Material = "Marble" },
        { S = V(0.16, 1.8, 0.06), P = V(0.13, -0.95, -0.55), Color = BONE, Material = "Marble" },
        { S = V(0.16, 1.6, 0.06), P = V(0.38, -0.85, -0.55), Color = BONE, Material = "Marble" },
        { S = V(0.9, 1.6, 0.06), P = V(0, -0.85, 0.55), Color = BONE, Material = "Marble" },
    } },
    { Id = "HellGreaves", Name = "Hellforged Greaves", Rarity = "Legendary", Unlock = DROP, Pieces = {
        { Attach = "LeftLowerLeg", S = V(1.1, 0.86, 1.1), P = V(0, 0.02, 0), Color = C3(34, 26, 24), Material = "CorrodedMetal" },
        { Attach = "RightLowerLeg", S = V(1.1, 0.86, 1.1), P = V(0, 0.02, 0), Color = C3(34, 26, 24), Material = "CorrodedMetal" },
        { Attach = "LeftLowerLeg", S = V(0.06, 0.7, 0.02), P = V(0.12, 0.02, -0.56), R = V(0, 0, 14), Color = C3(255, 110, 30), Material = "Neon" },
        { Attach = "RightLowerLeg", S = V(0.06, 0.7, 0.02), P = V(-0.12, 0.02, -0.56), R = V(0, 0, -14), Color = C3(255, 110, 30), Material = "Neon" },
        { Attach = "LeftFoot", S = V(1.14, 1.4, 1.16), P = V(0, 0.12, 0), Color = C3(34, 26, 24), Material = "CorrodedMetal" },
        { Attach = "RightFoot", S = V(1.14, 1.4, 1.16), P = V(0, 0.12, 0), Color = C3(34, 26, 24), Material = "CorrodedMetal" },
        { Attach = "LeftUpperLeg", S = V(0.84, 0.34, 0.26), P = V(0, -0.36, -0.5), Color = C3(34, 26, 24), Material = "CorrodedMetal" },
        { Attach = "RightUpperLeg", S = V(0.84, 0.34, 0.26), P = V(0, -0.36, -0.5), Color = C3(34, 26, 24), Material = "CorrodedMetal" },
    } },
    { Id = "AstralLegguards", Name = "Astral Legguards", Rarity = "Mythic", Unlock = DROP, Pieces = {
        { S = V(1.06, 0.42, 1.08), P = V(0, 0.15, 0), Color = GOLD, Material = "Foil" },
        { S = V(0.2, 0.2, 0.06), P = V(0, 0.15, -0.56), Color = C3(120, 220, 255), Material = "Neon" },
        { Attach = "LeftUpperLeg", S = V(1.08, 1.04, 1.08), P = V(0, 0, 0), Color = C3(230, 232, 240), Material = "Marble" },
        { Attach = "RightUpperLeg", S = V(1.08, 1.04, 1.08), P = V(0, 0, 0), Color = C3(230, 232, 240), Material = "Marble" },
        { Attach = "LeftLowerLeg", S = V(1.1, 0.9, 1.1), P = V(0, 0, 0), Color = GOLD, Material = "Foil" },
        { Attach = "RightLowerLeg", S = V(1.1, 0.9, 1.1), P = V(0, 0, 0), Color = GOLD, Material = "Foil" },
        { Attach = "LeftLowerLeg", S = V(0.5, 0.06, 0.02), P = V(0, 0.2, -0.57), Color = C3(120, 220, 255), Material = "Neon" },
        { Attach = "RightLowerLeg", S = V(0.5, 0.06, 0.02), P = V(0, 0.2, -0.57), Color = C3(120, 220, 255), Material = "Neon" },
        { Attach = "LeftFoot", S = V(1.14, 1.4, 1.16), P = V(0, 0.12, 0), Color = GOLD, Material = "Foil" },
        { Attach = "RightFoot", S = V(1.14, 1.4, 1.16), P = V(0, 0.12, 0), Color = GOLD, Material = "Foil" },
    } },
}

-- ===== Colors =====
local function Pal(list, unlocks)
    local out = {}
    for i, e in ipairs(list) do out[i] = { Id = e[1], Name = e[2], Color = e[3], Unlock = unlocks and unlocks[e[1]] } end
    return out
end
AvatarData.HairColor = Pal({
    { "Black", "Black", C3(28, 24, 26) }, { "DarkBrown", "Dark Brown", C3(60, 38, 26) }, { "Brown", "Brown", C3(104, 66, 40) },
    { "Auburn", "Auburn", C3(140, 62, 36) }, { "Ginger", "Ginger", C3(204, 98, 44) }, { "Blonde", "Blonde", C3(232, 196, 112) },
    { "Platinum", "Platinum", C3(236, 230, 214) }, { "Grey", "Grey", C3(150, 150, 156) },
    { "Pink", "Pink", C3(255, 120, 190) }, { "Blue", "Electric Blue", C3(60, 140, 255) }, { "Green", "Toxic Green", C3(110, 230, 80) },
    { "Purple", "Purple", C3(150, 80, 230) }, { "Red", "Crimson", C3(210, 40, 50) }, { "Teal", "Teal", C3(40, 200, 190) },
}, { Pink = { Level = 3 }, Blue = { Level = 3 }, Green = { Level = 6 }, Purple = { Level = 6 }, Red = { Level = 9 }, Teal = { Level = 9 } })

-- clothing colours: techwear neutrals first, then the richer dyes (level unlocks); old ids kept for saved looks
local Clothes = {
    { "Linen", "Linen", C3(196, 186, 160) }, { "Bone", "Bone", C3(214, 204, 178) }, { "Ash", "Ash", C3(120, 118, 112) },
    { "Slate", "Slate", C3(72, 80, 94) }, { "Charcoal", "Charcoal", C3(55, 55, 60) }, { "Black", "Black", C3(28, 28, 32) },
    { "Umber", "Umber", C3(90, 62, 42) }, { "Leather", "Leather", C3(120, 80, 50) }, { "Olive", "Olive", C3(82, 86, 56) },
    { "Moss", "Moss", C3(60, 80, 55) }, { "Rust", "Rust", C3(128, 62, 36) }, { "Wine", "Wine", C3(92, 32, 40) },
    { "Crimson", "Crimson", C3(150, 26, 32) }, { "Midnight", "Midnight", C3(32, 36, 70) }, { "Royal", "Royal Purple", C3(72, 40, 104) },
    { "Gilded", "Gilded", C3(176, 140, 64) },
    { "Graphite", "Graphite", C3(40, 42, 48) }, { "White", "Clean White", C3(232, 234, 240) }, { "Navy", "Navy", C3(28, 40, 72) },
    { "Teal", "Deep Teal", C3(20, 84, 90) }, { "Hazard", "Hazard Orange", C3(220, 110, 30) },
}
local DYES = { Crimson = { Level = 5 }, Midnight = { Level = 10 }, Royal = { Level = 15 }, Gilded = { Level = 25 }, Teal = { Level = 6 }, Hazard = { Level = 12 } }
AvatarData.Shirt = Pal(Clothes, DYES)
AvatarData.Pants = Pal(Clothes, DYES)
-- TRIM GLOW: the neon colour of every glow line on your gear (pieces use Color = "Trim")
AvatarData.Trim = Pal({
    { "Cyan", "Cyan", C3(60, 230, 255) }, { "Ice", "Ice White", C3(225, 245, 255) }, { "Lime", "Lime", C3(150, 255, 90) },
    { "Magenta", "Magenta", C3(255, 70, 200) }, { "Violet", "Violet", C3(170, 100, 255) }, { "Amber", "Amber", C3(255, 190, 60) },
    { "Red", "Signal Red", C3(255, 60, 70) }, { "Mint", "Mint", C3(90, 255, 200) }, { "Gold", "Gold", C3(255, 214, 110) },
}, { Mint = { Level = 4 }, Violet = { Level = 8 }, Red = { Level = 12 }, Gold = { Level = 20 } })
AvatarData.Sleeves = {
    { Id = "Short", Name = "Short Sleeves" }, -- upper arms in the shirt color
    { Id = "None", Name = "Sleeveless" },
    { Id = "Long", Name = "Long Sleeves" },
}

AvatarData.Default = { Body = "Classic", Skin = "Warm", Head = "Cube", Face = "Smile", Hair = "Swept", HairColor = "Brown", Shirt = "Graphite", Pants = "Black", Sleeves = "Short",
    HeadGear = "Headset", Top = "Hoodie", Bottom = "Sneakers", Trim = "Cyan" }

-- lookup: AvatarData.Find("Hair", "Afro")
local index = {}
for _, cat in ipairs(AvatarData.Categories) do
    index[cat.Id] = {}
    for _, e in ipairs(AvatarData[cat.Id]) do
        index[cat.Id][e.Id] = e; e.Cat = cat.Id
        if cat.Slot and LEGACY[e.Id] then e.Legacy = true end
    end
end
function AvatarData.Find(cat: string, id: any): any?
    return index[cat] and index[cat][id] or nil
end

-- Is an entry shown in lists (creator / cosmetics)? Legacy pieces only for players who own them.
function AvatarData.Listed(entry: any, state: any): boolean
    if not entry then return false end
    if not entry.Legacy then return true end
    local owned = state and state.AvatarOwned
    return type(owned) == "table" and owned[(entry.Cat or "") .. ":" .. entry.Id] == true
end

-- Is an entry usable by this player state? -> ok, reason ("Reach level 10" / "R$ 99" / "Coming soon")
function AvatarData.IsUnlocked(entry: any, state: any): (boolean, string?)
    local u = entry and entry.Unlock
    if not u then return true end
    if u.Level then
        if (state and state.Level or 1) >= u.Level then return true end
        return false, "Level " .. u.Level
    end
    local owned = state and state.AvatarOwned
    if type(owned) == "table" and owned[(entry.Cat or "") .. ":" .. entry.Id] then return true end
    if u.Robux then
        return false, (u.ProductId and u.ProductId ~= 0) and ("R$ " .. u.Robux) or "Coming soon"
    end
    if u.Drop then return false, "Dungeon drop" end
    return true
end

-- ===== drops =====
-- Odds of a cosmetic per kill, and the rarity mix by source (rarer sources skew to rarer -- cooler -- pieces).
AvatarData.DropChance = { Enemy = 0.004, Elite = 0.03, Goblin = 0.12, Boss = 0.08, SuperBoss = 0.25 }
AvatarData.DropRarityWeights = {
    Enemy = { Common = 55, Uncommon = 30, Rare = 12, Epic = 2.6, Legendary = 0.4, Mythic = 0 },
    Elite = { Common = 30, Uncommon = 34, Rare = 24, Epic = 9, Legendary = 2.6, Mythic = 0.4 },
    Goblin = { Common = 10, Uncommon = 30, Rare = 34, Epic = 18, Legendary = 6.5, Mythic = 1.5 },
    Boss = { Common = 12, Uncommon = 26, Rare = 32, Epic = 20, Legendary = 8, Mythic = 2 },
    SuperBoss = { Common = 0, Uncommon = 8, Rare = 26, Epic = 34, Legendary = 24, Mythic = 8 },
}
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

-- Roll a cosmetic drop for a player state from a source ("Enemy" / "Elite" / "Goblin" / "Boss" / "SuperBoss").
-- Returns the entry (unowned, a Drop item) or nil. Marks nothing -- the caller grants it (AvatarOwned["Cat:Id"] = true).
function AvatarData.RollDrop(state: any, source: string, rng: Random?): any?
    local chance = AvatarData.DropChance[source] or 0
    local r = rng or Random.new()
    if r:NextNumber() >= chance then return nil end
    local owned = type(state.AvatarOwned) == "table" and state.AvatarOwned or {}
    local byRarity = {}
    for _, cat in ipairs(AvatarData.Categories) do
        for _, e in ipairs(AvatarData[cat.Id]) do
            if e.Unlock and e.Unlock.Drop and not e.Legacy and not owned[cat.Id .. ":" .. e.Id] then
                local rar = e.Rarity or "Common"
                byRarity[rar] = byRarity[rar] or {}
                table.insert(byRarity[rar], e)
            end
        end
    end
    local weights = AvatarData.DropRarityWeights[source] or AvatarData.DropRarityWeights.Enemy
    local total = 0
    for _, rar in ipairs(RARITY_ORDER) do if byRarity[rar] then total += weights[rar] or 0 end end
    if total <= 0 then return nil end -- owns every drop it could roll
    local pick = r:NextNumber() * total
    for _, rar in ipairs(RARITY_ORDER) do
        local pool = byRarity[rar]
        if pool then
            pick -= weights[rar] or 0
            if pick <= 0 then return pool[r:NextInteger(1, #pool)] end
        end
    end
    return nil
end

-- A complete, valid look: unknown / missing ids fall back to the defaults.
function AvatarData.Normalize(look: any): any
    local out = {}
    for _, cat in ipairs(AvatarData.Categories) do
        local id = type(look) == "table" and look[cat.Id] or nil
        out[cat.Id] = (type(id) == "string" and index[cat.Id][id]) and id or AvatarData.Default[cat.Id]
    end
    return out
end

-- Like Normalize, but anything the player hasn't unlocked falls back to the default too.
function AvatarData.Sanitize(look: any, state: any): any
    local out = AvatarData.Normalize(look)
    for _, cat in ipairs(AvatarData.Categories) do
        if not AvatarData.IsUnlocked(index[cat.Id][out[cat.Id]], state) then out[cat.Id] = AvatarData.Default[cat.Id] end
    end
    return out
end

return AvatarData
