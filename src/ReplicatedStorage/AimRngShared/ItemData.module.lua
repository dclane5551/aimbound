--!nocheck
export type WeaponRarity = string -- (15 rarities: ItemData.Rarities)
export type WeaponClass = "Pistol" | "SMG" | "Sniper" | "Rifle" | "Burst" | "Shotgun" | "Heavy" | "Laser" | "Revolver" | "Launcher"
export type GearSlot = "Helmet" | "ChestPiece" | "Leggings" | "Boots" | "Ring" | "Ring1" | "Ring2" | "Necklace" | "Gloves" -- items are "Ring"; Ring1/Ring2 are the two equip slots (UPDATE 8: + Gloves)

export type UniqueTraitType = "Singularity" | "Supernova" | "ChainLightning" | "TemporalStasis" | "VampiricSoul" | "HyperBeam"
    | "Guillotine" | "Overflow" | "Bloodhound" | "HuntersFocus" | "MarrowTap" | "PhantomRound"

export type UniqueTrait = {
    Id: UniqueTraitType,
    Name: string,
    Description: string,
    TriggerChance: number,
}

export type Affix = {
    Id: string,
    Name: string,
    Stat: string,
    Value: number,
    Tier: number,
}

export type WeaponInstance = {
    Uid: string,
    BaseId: string,
    Name: string,
    Class: WeaponClass,
    Rarity: WeaponRarity,
    UpgradeLevel: number,
    -- The character level this specific weapon was rolled at -- baked into BaseDamage/affix values at
    -- generation time (see GenerateRandomWeapon), so a weapon found at level 80 stays meaningfully
    -- stronger than one found at level 5, even on the same character, at the same rarity.
    ItemLevel: number,
    BaseDamage: number,
    BaseFireRate: number,
    BaseWeakSpotMultiplier: number,
    MagazineSize: number,
    ReloadTime: number,
    EffectiveRange: number,
    ExplosionRadius: number?,
    BurstCount: number?,
    PelletCount: number?,
    IsContinuousBeam: boolean?,
    RecoilPitch: number?,
    RecoilYaw: number?,
    RecoilKickZ: number?,
    ADSZoom: number?,
    Mobility: number?,
    UniqueTrait: UniqueTrait?,
    Prefixes: { Affix },
    Suffixes: { Affix },
    Proc: WeaponProc?, -- Burn / Freeze / Bleed / Decay / Giantslayer / Fixation / Explosive prefix
}

export type GearStatLine = {
    Stat: string,
    Name: string,
    Value: number,
}

export type GearInstance = {
    Uid: string,
    Slot: GearSlot,
    Name: string,
    Rarity: WeaponRarity,
    -- The character level this piece was rolled at -- baked into each StatLine's Value at generation
    -- time (see GenerateRandomGear), same idea as WeaponInstance.ItemLevel.
    ItemLevel: number,
    Armor: number?, -- intrinsic armor on Helmet/Chest/Legs/Boots (grows with item level)
    StatLines: { GearStatLine },
}

export type WeaponComparison = {
    IsBetter: boolean,
    Reasons: { string },
    DiffDPS: number,
    NewDPS: number,
    CurrentDPS: number,
}

export type MeleeWeapon = {
    Id: string,
    Name: string,
    Rarity: WeaponRarity,
    BaseDamage: number,
    AttackRate: number,
    Range: number,
    CritChance: number,
    CritMultiplier: number,
    MovementSpeedBonus: number,
    ArmorPenetration: number,
    Description: string,
    BladeColor: Color3,
    HandleColor: Color3,
    CostGold: number,
    CostShards: number,
}

export type GloveCosmetic = {
    Id: string,
    Name: string,
    Rarity: WeaponRarity,
    Description: string,
    PrimaryColor: Color3,
    AccentColor: Color3,
    Material: Enum.Material,
    KnuckleMaterial: Enum.Material,
    CostGold: number,
    CostShards: number,
    DropOnly: boolean?, -- true = can't be bought; only drops (see CosmeticDropTables)
    DropSource: string?, -- shown in the Armory, e.g. "Easy bosses"
}

-- Arm sleeve skin: the forearm/sleeve half of the viewmodel arms (gloves are the hand half).
export type ArmSkin = {
    Id: string,
    Name: string,
    Rarity: WeaponRarity,
    Description: string,
    SleeveColor: Color3,
    CuffColor: Color3, -- band where sleeve meets glove
    StripeColor: Color3?, -- optional band partway up the sleeve
    Material: Enum.Material, -- smooth materials only (see the glove note below)
    DropOnly: boolean?,
    DropSource: string?,
}

-- Weapon finish: applies to whatever gun is equipped. Finishes are solid: the gun's texture is replaced by
-- Tint as a solid color in Material (default Metal) with Reflectance. ForceField gives an animated shimmer.
-- Animated = "Rainbow" cycles hue client-side.
export type WeaponSkin = {
    Id: string,
    Name: string,
    Rarity: WeaponRarity,
    Description: string,
    KeepTexture: boolean,
    Tint: Color3, -- multiplies the texture (KeepTexture) or is the solid color
    Reflectance: number?,
    Material: Enum.Material?,
    Animated: string?,
    DropOnly: boolean?,
    DropSource: string?,
}

export type CosmeticRef = { Kind: "Glove" | "Sleeve" | "WeaponSkin", Id: string }

export type TitleDefinition = {
    Id: string,
    Title: string,
    Rarity: WeaponRarity,
    Description: string,
    RewardGold: number,
    RewardShards: number,
    Color: Color3,
    Requirement: string,
    StatBuffs: { [string]: number }?,
}

export type DifficultyMode = {
    Id: "Easy" | "Normal" | "Hard" | "Endless",
    Name: string,
    MaxWaves: number,
    Description: string,
    Color: Color3,
    MiniBossWaves: { number },
    BossWaves: { number },
    SuperBossWave: number?,
    RewardMultiplier: number,
}

local BaseWeapons: { [string]: any } = {
    -- 1. PISTOLS
    ["Revolver"] = {
        Name = "Sheriff Heavy Revolver",
        Class = "Pistol",
        BaseDamage = 10.4,
        BaseFireRate = 2.2,
        BaseWeakSpotMultiplier = 2.8,
        MagazineSize = 6,
        ReloadTime = 1.8,
        EffectiveRange = 500,
        RecoilPitch = 1.8,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.42,
        ADSZoom = 62,
        Mobility = 1.02,
        Description = "High-caliber 6-round revolver with a rotating cylinder. Heavy slide kick and devastating weak-spot criticals.",
    },
    ["Pistol"] = {
        Name = "Viper Tactical Auto-Pistol",
        Class = "Pistol",
        BaseDamage = 4.1,
        BaseFireRate = 6.2,
        BaseWeakSpotMultiplier = 2.0,
        MagazineSize = 18,
        ReloadTime = 1.4,
        EffectiveRange = 450,
        RecoilPitch = 0.8,
        RecoilYaw = 0.2,
        RecoilKickZ = 0.24,
        ADSZoom = 64,
        Mobility = 1.05,
        Description = "Snappy polymer sidearm with fast cyclic blowback. Highly reliable and rapid follow-up shots.",
    },
    -- Weapon-overhaul prototype (real multi-part mesh + rigged arms, see WeaponRigs). TestOnly keeps it out
    -- of loot, shops and the Index until the new gun lineup is decided; hand it out with the dev command.
    ["Glock17"] = {
        Name = "G19",
        Class = "Pistol",
        BaseDamage = 4.3,
        BaseFireRate = 6.0,
        BaseWeakSpotMultiplier = 2.0,
        MagazineSize = 17,
        ReloadTime = 1.45,
        EffectiveRange = 450,
        RecoilPitch = 0.8,
        RecoilYaw = 0.2,
        RecoilKickZ = 0.24,
        ADSZoom = 64,
        Mobility = 1.05,
        Description = "Austrian polymer 9mm. Seventeen rounds, a light trigger and dead-simple reliability.",
    },
    -- Weapon overhaul SMGs (TastyTony low-poly models). TestOnly until verified in-game.
    ["UZI"] = {
        Name = "Uzi",
        Class = "SMG",
        BaseDamage = 3.1,
        BaseFireRate = 10.0,
        BaseWeakSpotMultiplier = 1.9,
        MagazineSize = 32,
        ReloadTime = 1.7,
        EffectiveRange = 320,
        RecoilPitch = 0.53,
        RecoilYaw = 0.35,
        RecoilKickZ = 0.2,
        ADSZoom = 62,
        Mobility = 1.08,
        Description = "Israeli open-bolt classic. Spits 9mm fast and close.",
    },
    ["MP5"] = {
        Name = "MP5",
        Class = "SMG",
        BaseDamage = 2.35,
        BaseFireRate = 13.3,
        BaseWeakSpotMultiplier = 2.1,
        MagazineSize = 30,
        ReloadTime = 1.9,
        EffectiveRange = 380,
        RecoilPitch = 0.33,
        RecoilYaw = 0.2,
        RecoilKickZ = 0.18,
        ADSZoom = 60,
        Mobility = 1.06,
        Description = "The benchmark SMG. Smooth, accurate and easy to control.",
    },
    ["P90"] = {
        Name = "P90",
        Class = "SMG",
        BaseDamage = 2.1,
        BaseFireRate = 15.0,
        BaseWeakSpotMultiplier = 1.9,
        MagazineSize = 50,
        ReloadTime = 2.3,
        EffectiveRange = 360,
        RecoilPitch = 0.31,
        RecoilYaw = 0.2,
        RecoilKickZ = 0.16,
        ADSZoom = 60,
        Mobility = 1.06,
        Description = "Bullpup PDW with a 50-round top-mounted magazine.",
    },
    ["MP7"] = {
        Name = "MP7",
        Class = "SMG",
        BaseDamage = 2.0,
        BaseFireRate = 15.8,
        BaseWeakSpotMultiplier = 2.0,
        MagazineSize = 40,
        ReloadTime = 1.8,
        EffectiveRange = 350,
        RecoilPitch = 0.33,
        RecoilYaw = 0.25,
        RecoilKickZ = 0.17,
        ADSZoom = 62,
        Mobility = 1.08,
        Description = "Compact 4.6mm PDW. Tiny, light and very fast.",
    },
    -- Weapon overhaul pistols (TastyTony low-poly models, rigs in WeaponRigs). TestOnly until verified in-game.
    ["DEAGLE"] = {
        Name = "Desert Eagle",
        Class = "Pistol",
        BaseDamage = 10.5,
        BaseFireRate = 2.6,
        BaseWeakSpotMultiplier = 2.4,
        MagazineSize = 7,
        ReloadTime = 1.9,
        EffectiveRange = 520,
        RecoilPitch = 2.4,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.5,
        ADSZoom = 60,
        Mobility = 1.0,
        Description = ".50 AE hand cannon. Seven rounds that each hit like a rifle.",
    },
    ["TEC9"] = {
        Name = "TEC-9",
        Class = "Pistol",
        BaseDamage = 2.9,
        BaseFireRate = 9.0,
        BaseWeakSpotMultiplier = 1.8,
        MagazineSize = 32,
        ReloadTime = 1.8,
        EffectiveRange = 300,
        RecoilPitch = 0.6,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.2,
        ADSZoom = 64,
        Mobility = 1.07,
        Description = "Cheap, loud and fast. Thirty-two rounds of 9mm in a hurry.",
    },
    ["RHINO"] = {
        Name = "Rhino",
        Class = "Pistol",
        BaseDamage = 11.0,
        BaseFireRate = 2.3,
        BaseWeakSpotMultiplier = 2.5,
        MagazineSize = 6,
        ReloadTime = 2.4,
        EffectiveRange = 480,
        RecoilPitch = 2.0,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.42,
        ADSZoom = 60,
        Mobility = 1.02,
        Description = "Low-bore .357 Magnum revolver. Fires from the bottom chamber, so it stays flat.",
    },
    -- Weapon overhaul shotguns + snipers (TastyTony low-poly models, rigs in WeaponRigs). TestOnly until verified in-game.
    ["R870"] = {
        Name = "870 Pump",
        Class = "Shotgun",
        BaseDamage = 3.3, -- (2026-10-05 balance: was 4.1)
        BaseFireRate = 1.2,
        BaseWeakSpotMultiplier = 1.9,
        MagazineSize = 6,
        PelletCount = 9,
        ReloadTime = 2.5,
        EffectiveRange = 300,
        RecoilPitch = 3.16,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.7,
        ADSZoom = 62,
        Mobility = 1.0,
        Description = "Pistol-grip pump twelve-gauge. Rack it, point it, end the conversation.",
    },
    ["BM4"] = {
        Name = "M4 Super 90",
        Class = "Shotgun",
        BaseDamage = 1.3, -- (2026-10-05 balance: was 1.6)
        BaseFireRate = 3.0,
        BaseWeakSpotMultiplier = 1.9,
        MagazineSize = 7,
        PelletCount = 9,
        ReloadTime = 2.3,
        EffectiveRange = 320,
        RecoilPitch = 1.88,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.58,
        ADSZoom = 62,
        Mobility = 1.0,
        Description = "Gas-operated combat shotgun. As fast as you can pull the trigger.",
    },
    ["AA12"] = {
        Name = "AA-12",
        Class = "Shotgun",
        BaseDamage = 0.9, -- (2026-10-05 balance: was 1.1)
        BaseFireRate = 5.0,
        BaseWeakSpotMultiplier = 1.7,
        MagazineSize = 8,
        PelletCount = 8,
        ReloadTime = 2.4,
        EffectiveRange = 260,
        RecoilPitch = 1.49,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.45,
        ADSZoom = 63,
        Mobility = 0.97,
        Description = "Fully automatic twelve-gauge. Hold the trigger and the room empties.",
    },
    ["AWP"] = {
        Name = "AWM",
        Class = "Sniper",
        BaseDamage = 52.0, -- (2026-10-05 balance: was 60)
        BaseFireRate = 0.7,
        BaseWeakSpotMultiplier = 3.2, -- (was 4.5)
        MagazineSize = 5,
        ReloadTime = 2.6,
        EffectiveRange = 1400,
        RecoilPitch = 4.5,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.95,
        ADSZoom = 25,
        Mobility = 0.86,
        Description = "Arctic Warfare bolt-action. One shot, one kill, one bolt cycle.",
    },
    ["M82"] = {
        Name = "M82A1",
        Class = "Sniper",
        BaseDamage = 24.0, -- (2026-10-05 balance: was 28)
        BaseFireRate = 1.4,
        BaseWeakSpotMultiplier = 3.0, -- (was 4.0)
        MagazineSize = 10,
        ReloadTime = 3.0,
        EffectiveRange = 1600,
        RecoilPitch = 5.5,
        RecoilYaw = 0.6,
        RecoilKickZ = 1.1,
        ADSZoom = 24,
        Mobility = 0.82,
        Description = "Semi-automatic .50 BMG. Heavy, loud and absolutely final.",
    },
    ["SCOUT"] = {
        Name = "Hunting Rifle",
        Class = "Sniper",
        BaseDamage = 38.0, -- (2026-10-05 balance: was 44)
        BaseFireRate = 0.85,
        BaseWeakSpotMultiplier = 3.0, -- (was 4.0)
        MagazineSize = 5,
        ReloadTime = 2.3,
        EffectiveRange = 1100,
        RecoilPitch = 3.2,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.7,
        ADSZoom = 32,
        Mobility = 0.95,
        Description = "Light, quick-handling bolt gun. Snap to the head and keep moving.",
    },
    -- Weapon overhaul rifles (TastyTony low-poly models, rigs in WeaponRigs). TestOnly until verified in-game.
    ["AK47"] = {
        Name = "AK-47",
        Class = "Rifle",
        BaseDamage = 3.5,
        BaseFireRate = 10.0,
        BaseWeakSpotMultiplier = 2.2,
        MagazineSize = 30,
        ReloadTime = 2.3,
        EffectiveRange = 480,
        RecoilPitch = 0.86,
        RecoilYaw = 0.45,
        RecoilKickZ = 0.36,
        ADSZoom = 56,
        Mobility = 0.98,
        Description = "The classic. 7.62mm, thirty rounds, hits hard and kicks harder.",
    },
    ["SCAR"] = {
        Name = "SCAR-L",
        Class = "Rifle",
        BaseDamage = 3.6,
        BaseFireRate = 10.0,
        BaseWeakSpotMultiplier = 2.3,
        MagazineSize = 20,
        ReloadTime = 2.4,
        EffectiveRange = 520,
        RecoilPitch = 0.83,
        RecoilYaw = 0.35,
        RecoilKickZ = 0.38,
        ADSZoom = 55,
        Mobility = 0.97,
        Description = "Belgian 7.62 battle rifle. Twenty heavy rounds with a stiff but steady climb.",
    },
    ["M4A1"] = {
        Name = "M4A1 Carbine",
        Class = "Rifle",
        BaseDamage = 2.6,
        BaseFireRate = 13.3,
        BaseWeakSpotMultiplier = 2.1,
        MagazineSize = 30,
        ReloadTime = 2.0,
        EffectiveRange = 450,
        RecoilPitch = 0.47,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.28,
        ADSZoom = 56,
        Mobility = 1.0,
        Description = "5.56 carbine. Light, fast and easy to keep on target.",
    },
    ["AUG"] = {
        Name = "AUG",
        Class = "Rifle",
        BaseDamage = 3.0,
        BaseFireRate = 11.7,
        BaseWeakSpotMultiplier = 2.2,
        MagazineSize = 30,
        ReloadTime = 2.2,
        EffectiveRange = 480,
        RecoilPitch = 0.46,
        RecoilYaw = 0.25,
        RecoilKickZ = 0.27,
        ADSZoom = 50,
        Mobility = 1.0,
        Description = "Austrian bullpup with a built-in scope. Long barrel in a short package, very controllable.",
    },
    ["F2000"] = {
        Name = "FAMAS",
        Class = "Rifle",
        BaseDamage = 2.45,
        BaseFireRate = 14.2,
        BaseWeakSpotMultiplier = 2.0,
        MagazineSize = 30,
        ReloadTime = 2.1,
        EffectiveRange = 440,
        RecoilPitch = 0.42,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.25,
        ADSZoom = 55,
        Mobility = 1.02,
        Description = "Futuristic Belgian bullpup. The fastest-firing rifle here, with forward ejection.",
    },
    -- ===== 0.48 WEAPON DROP (TastyTony low-poly models + tools/new_guns.py rigs) =====
    -- LMGs (Class Heavy = the Assault group with the ARs): big belts, long reloads, slower to move with.
    ["M249"] = {
        Name = "M249",
        Class = "Heavy",
        BaseDamage = 2.7,
        BaseFireRate = 13.0,
        BaseWeakSpotMultiplier = 2.0,
        MagazineSize = 100,
        ReloadTime = 4.2,
        EffectiveRange = 460,
        RecoilPitch = 0.55,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.3,
        ADSZoom = 56,
        Mobility = 0.88,
        Description = "Belt-fed 5.56 squad gun. A hundred rounds before you even think about reloading.",
    },
    ["PKM"] = {
        Name = "PKM",
        Class = "Heavy",
        BaseDamage = 3.6,
        BaseFireRate = 10.8,
        BaseWeakSpotMultiplier = 2.0,
        MagazineSize = 100,
        ReloadTime = 4.6,
        EffectiveRange = 520,
        RecoilPitch = 0.75,
        RecoilYaw = 0.45,
        RecoilKickZ = 0.36,
        ADSZoom = 55,
        Mobility = 0.86,
        Description = "Belt-fed 7.62 workhorse. Heavy, loud and it simply does not stop.",
    },
    ["M60"] = {
        Name = "M60",
        Class = "Heavy",
        BaseDamage = 3.9,
        BaseFireRate = 9.5,
        BaseWeakSpotMultiplier = 2.0,
        MagazineSize = 100,
        ReloadTime = 4.8,
        EffectiveRange = 520,
        RecoilPitch = 0.8,
        RecoilYaw = 0.45,
        RecoilKickZ = 0.38,
        ADSZoom = 55,
        Mobility = 0.85,
        Description = "The Pig. A slow, booming 7.62 belt that chews through cover and anything behind it.",
    },
    ["HK21"] = {
        Name = "21E",
        Class = "Heavy",
        BaseDamage = 3.4,
        BaseFireRate = 11.5,
        BaseWeakSpotMultiplier = 2.0,
        MagazineSize = 80,
        ReloadTime = 4.0,
        EffectiveRange = 500,
        RecoilPitch = 0.65,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.33,
        ADSZoom = 56,
        Mobility = 0.88,
        Description = "Battle-rifle action on a belt. Steadier than the big machine guns, quicker to reload.",
    },
    ["TAR21"] = {
        Name = "TAR-21",
        Class = "Rifle",
        BaseDamage = 2.7,
        BaseFireRate = 12.5,
        BaseWeakSpotMultiplier = 2.1,
        MagazineSize = 30,
        ReloadTime = 2.0,
        EffectiveRange = 450,
        RecoilPitch = 0.45,
        RecoilYaw = 0.28,
        RecoilKickZ = 0.26,
        ADSZoom = 55,
        Mobility = 1.02,
        Description = "Compact bullpup. A full-length barrel in a short, quick-handling package.",
    },
    ["GALIL"] = {
        Name = "Galil",
        Class = "Rifle",
        BaseDamage = 3.3,
        BaseFireRate = 10.8,
        BaseWeakSpotMultiplier = 2.2,
        MagazineSize = 35,
        ReloadTime = 2.4,
        EffectiveRange = 480,
        RecoilPitch = 0.75,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.34,
        ADSZoom = 56,
        Mobility = 0.98,
        Description = "Rugged 7.62 rifle with a bigger magazine and a steady, heavy rhythm.",
    },
    ["HK416"] = {
        Name = "416",
        Class = "Rifle",
        BaseDamage = 2.8,
        BaseFireRate = 12.5,
        BaseWeakSpotMultiplier = 2.1,
        MagazineSize = 30,
        ReloadTime = 2.1,
        EffectiveRange = 460,
        RecoilPitch = 0.48,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.28,
        ADSZoom = 56,
        Mobility = 1.0,
        Description = "Piston-driven carbine. Clean, reliable and very easy to keep on target.",
    },
    ["MP40"] = {
        Name = "MP40",
        Class = "SMG",
        BaseDamage = 3.1,
        BaseFireRate = 9.5,
        BaseWeakSpotMultiplier = 2.0,
        MagazineSize = 32,
        ReloadTime = 2.0,
        EffectiveRange = 330,
        RecoilPitch = 0.45,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.2,
        ADSZoom = 62,
        Mobility = 1.06,
        Description = "Wartime 9mm classic. Slow, controllable cyclic and a satisfying heavy thump.",
    },
    ["PPSH"] = {
        Name = "PPSh-41",
        Class = "SMG",
        BaseDamage = 1.7,
        BaseFireRate = 16.5,
        BaseWeakSpotMultiplier = 1.9,
        MagazineSize = 71,
        ReloadTime = 3.0,
        EffectiveRange = 300,
        RecoilPitch = 0.38,
        RecoilYaw = 0.32,
        RecoilKickZ = 0.18,
        ADSZoom = 62,
        Mobility = 1.03,
        Description = "Seventy-one rounds in a drum and a rate of fire like tearing cloth.",
    },
    ["VECTOR"] = {
        Name = "Vector",
        Class = "SMG",
        BaseDamage = 1.75,
        BaseFireRate = 18.0,
        BaseWeakSpotMultiplier = 2.0,
        MagazineSize = 25,
        ReloadTime = 1.7,
        EffectiveRange = 320,
        RecoilPitch = 0.25,
        RecoilYaw = 0.18,
        RecoilKickZ = 0.14,
        ADSZoom = 62,
        Mobility = 1.08,
        Description = "Recoil-mitigating .45 that fires impossibly fast and stays flat while it does.",
    },
    ["USAS12"] = {
        Name = "Komrad 12",
        Class = "Shotgun",
        BaseDamage = 0.95,
        BaseFireRate = 4.6,
        BaseWeakSpotMultiplier = 1.7,
        MagazineSize = 10,
        PelletCount = 8,
        ReloadTime = 2.6,
        EffectiveRange = 260,
        RecoilPitch = 1.5,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.46,
        ADSZoom = 63,
        Mobility = 0.96,
        Description = "Automatic twelve-gauge on a rifle frame. Ten shells of nonstop buckshot.",
    },
    ["DBARREL"] = {
        Name = "Double Barrel",
        Class = "Shotgun",
        BaseDamage = 4.4,
        BaseFireRate = 2.0,
        BaseWeakSpotMultiplier = 1.9,
        MagazineSize = 2,
        PelletCount = 10,
        ReloadTime = 2.2,
        EffectiveRange = 220,
        RecoilPitch = 4.2,
        RecoilYaw = 0.5,
        RecoilKickZ = 0.85,
        ADSZoom = 63,
        Mobility = 1.0,
        Description = "Two barrels, two triggers, two problems solved. Break it, load it, do it again.",
    },
    ["KSG"] = {
        Name = "KS7",
        Class = "Shotgun",
        BaseDamage = 3.0,
        BaseFireRate = 1.3,
        BaseWeakSpotMultiplier = 1.9,
        MagazineSize = 14,
        PelletCount = 9,
        ReloadTime = 3.0,
        EffectiveRange = 300,
        RecoilPitch = 3.0,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.66,
        ADSZoom = 62,
        Mobility = 1.0,
        Description = "Twin-tube bullpup pump. Fourteen shells and a very short gun.",
    },
    ["M590"] = {
        Name = "590 Pump",
        Class = "Shotgun",
        BaseDamage = 3.4,
        BaseFireRate = 1.15,
        BaseWeakSpotMultiplier = 1.9,
        MagazineSize = 8,
        PelletCount = 9,
        ReloadTime = 2.6,
        EffectiveRange = 300,
        RecoilPitch = 3.3,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.7,
        ADSZoom = 62,
        Mobility = 0.99,
        Description = "Heavy-barrel tactical pump. The steadiest, hardest-hitting pump in the rack.",
    },
    ["USP"] = {
        Name = "USP",
        Class = "Pistol",
        BaseDamage = 5.0,
        BaseFireRate = 5.0,
        BaseWeakSpotMultiplier = 2.1,
        MagazineSize = 12,
        ReloadTime = 1.5,
        EffectiveRange = 470,
        RecoilPitch = 1.0,
        RecoilYaw = 0.25,
        RecoilKickZ = 0.28,
        ADSZoom = 64,
        Mobility = 1.04,
        Description = ".45 service pistol. Twelve heavy rounds and a crisp, accurate trigger.",
    },
    ["P226"] = {
        Name = "P226",
        Class = "Pistol",
        BaseDamage = 4.5,
        BaseFireRate = 5.6,
        BaseWeakSpotMultiplier = 2.0,
        MagazineSize = 15,
        ReloadTime = 1.45,
        EffectiveRange = 460,
        RecoilPitch = 0.9,
        RecoilYaw = 0.22,
        RecoilKickZ = 0.26,
        ADSZoom = 64,
        Mobility = 1.05,
        Description = "All-metal 9mm sidearm. Smooth, heavy and dependable.",
    },
    ["SR9"] = {
        Name = "P99",
        Class = "Pistol",
        BaseDamage = 4.2,
        BaseFireRate = 6.2,
        BaseWeakSpotMultiplier = 2.0,
        MagazineSize = 17,
        ReloadTime = 1.4,
        EffectiveRange = 450,
        RecoilPitch = 0.8,
        RecoilYaw = 0.2,
        RecoilKickZ = 0.24,
        ADSZoom = 64,
        Mobility = 1.06,
        Description = "Slim striker-fired 9mm. Light in the hand and quick on follow-ups.",
    },
    ["PX4"] = {
        Name = "PX4 Storm",
        Class = "Pistol",
        BaseDamage = 4.4,
        BaseFireRate = 6.0,
        BaseWeakSpotMultiplier = 2.0,
        MagazineSize = 17,
        ReloadTime = 1.45,
        EffectiveRange = 450,
        RecoilPitch = 0.75,
        RecoilYaw = 0.2,
        RecoilKickZ = 0.24,
        ADSZoom = 64,
        Mobility = 1.05,
        Description = "Rotating-barrel 9mm. Unusually soft recoil for how hard it hits.",
    },
    ["SVD"] = {
        Name = "SVD",
        Class = "Sniper",
        BaseDamage = 17.0,
        BaseFireRate = 2.0,
        BaseWeakSpotMultiplier = 2.8,
        MagazineSize = 10,
        ReloadTime = 2.6,
        EffectiveRange = 1100,
        RecoilPitch = 2.6,
        RecoilYaw = 0.35,
        RecoilKickZ = 0.6,
        ADSZoom = 30,
        Mobility = 0.92,
        Description = "Semi-automatic marksman rifle with a 4x scope. Ten fast, heavy 7.62 shots.",
    },
    ["SKS"] = {
        Name = "SKS",
        Class = "Sniper",
        BaseDamage = 13.0,
        BaseFireRate = 2.4,
        BaseWeakSpotMultiplier = 2.6,
        MagazineSize = 10,
        ReloadTime = 2.8,
        EffectiveRange = 900,
        RecoilPitch = 2.0,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.5,
        ADSZoom = 45,
        Mobility = 0.96,
        Description = "Semi-auto carbine fed from stripper clips. Iron sights, quick hands, steady hits.",
    },
    ["M40"] = {
        Name = "M40",
        Class = "Sniper",
        BaseDamage = 44.0,
        BaseFireRate = 0.78,
        BaseWeakSpotMultiplier = 3.0,
        MagazineSize = 5,
        ReloadTime = 2.5,
        EffectiveRange = 1300,
        RecoilPitch = 4.2,
        RecoilYaw = 0.35,
        RecoilKickZ = 0.9,
        ADSZoom = 28,
        Mobility = 0.88,
        Description = "Precision bolt-action. One clean shot, one deliberate cycle of the bolt.",
    },
    ["EMR"] = {
        Name = "M14",
        Class = "Sniper",
        BaseDamage = 14.0,
        BaseFireRate = 2.4,
        BaseWeakSpotMultiplier = 2.6,
        MagazineSize = 20,
        ReloadTime = 2.4,
        EffectiveRange = 1000,
        RecoilPitch = 2.2,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.5,
        ADSZoom = 40,
        Mobility = 0.94,
        Description = "Enhanced battle rifle in a modern chassis. Twenty rounds of fast precision.",
    },
    ["MK11"] = {
        Name = "M110",
        Class = "Sniper",
        BaseDamage = 16.0,
        BaseFireRate = 2.2,
        BaseWeakSpotMultiplier = 2.7,
        MagazineSize = 20,
        ReloadTime = 2.6,
        EffectiveRange = 1100,
        RecoilPitch = 2.4,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.55,
        ADSZoom = 32,
        Mobility = 0.92,
        Description = "Suppressor-ready 7.62 marksman rifle. Long-range accuracy without the bolt.",
    },
    -- the Arcwright's class gun (Class Laser = the Beam group): one unbroken beam while you hold the trigger
    ["BEAM"] = {
        Name = "Arc Projector",
        Class = "Laser",
        BaseDamage = 2.5,
        BaseFireRate = 14.0,
        BaseWeakSpotMultiplier = 1.9,
        MagazineSize = 70,
        ReloadTime = 2.3,
        EffectiveRange = 480,
        IsContinuousBeam = true,
        RecoilPitch = 0.12,
        RecoilYaw = 0.08,
        RecoilKickZ = 0.05,
        ADSZoom = 56,
        Mobility = 1.0,
        Description = "Compact particle emitter. Hold the trigger and a single searing beam stays locked on whatever you track.",
    },
    ["DualDeagle"] = {
        Name = "Akimbo Desert Eagles",
        Class = "Pistol",
        BaseDamage = 10.8,
        BaseFireRate = 3.4,
        BaseWeakSpotMultiplier = 2.4,
        MagazineSize = 14,
        ReloadTime = 2.2,
        EffectiveRange = 480,
        RecoilPitch = 2.2,
        RecoilYaw = 0.5,
        RecoilKickZ = 0.45,
        ADSZoom = 64,
        Mobility = 1.02,
        Description = "Twin high-power .50 cal magnums. Alternating muzzle blasts deliver immense staggered stopping power.",
    },

    -- 2. SMGS
    ["SMG"] = {
        Name = "Spectre Tactical SMG",
        Class = "SMG",
        BaseDamage = 2.5,
        BaseFireRate = 15.0,
        BaseWeakSpotMultiplier = 1.7,
        MagazineSize = 36,
        ReloadTime = 1.9,
        EffectiveRange = 350,
        RecoilPitch = 0.5,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.2,
        ADSZoom = 60,
        Mobility = 1.06,
        Description = "Blistering 15.0 rounds/sec submachine gun with horizontal feed magazine. Excels at melting targets in close quarters.",
    },
    ["VectorSMG"] = {
        Name = "Vector Hyper-Burst SMG",
        Class = "SMG",
        BaseDamage = 2.1,
        BaseFireRate = 20.0,
        BaseWeakSpotMultiplier = 1.8,
        MagazineSize = 40,
        ReloadTime = 1.7,
        EffectiveRange = 320,
        RecoilPitch = 0.4,
        RecoilYaw = 0.5,
        RecoilKickZ = 0.18,
        ADSZoom = 60,
        Mobility = 1.08,
        Description = "Ultra-high cyclic rate (20/s) with patented Super V downward recoil mitigation. Tears through armor instantly.",
    },
    ["StenSMG"] = { -- old pack gun (Sten mesh); "P90" is the new rigged lineup gun
        Name = "P90 Bullpup PDW",
        Class = "SMG",
        BaseDamage = 2.3,
        BaseFireRate = 16.5,
        BaseWeakSpotMultiplier = 1.6,
        MagazineSize = 50,
        ReloadTime = 2.4,
        EffectiveRange = 380,
        RecoilPitch = 0.45,
        RecoilYaw = 0.35,
        RecoilKickZ = 0.2,
        ADSZoom = 60,
        Mobility = 1.04,
        Description = "High-capacity 50-round translucent top-mounted magazine. High sustain and minimal reloads.",
    },

    -- 3. RIFLES
    ["RapidCarbine"] = {
        Name = "Valkyrie Precision Carbine",
        Class = "Rifle",
        BaseDamage = 4.7,
        BaseFireRate = 7.2,
        BaseWeakSpotMultiplier = 2.2,
        MagazineSize = 30,
        ReloadTime = 2.1,
        EffectiveRange = 450,
        RecoilPitch = 0.75,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.3,
        ADSZoom = 54,
        Mobility = 1.0,
        Description = "Ergonomic bullpup assault rifle with an integrated holo-optic. Exceptional mid-range tracking accuracy.",
    },
    ["AK47Classic"] = { -- old pack gun; "AK47" is the new rigged lineup gun
        Name = "Warlord AK-47 Battle Rifle",
        Class = "Rifle",
        BaseDamage = 6.1,
        BaseFireRate = 5.8,
        BaseWeakSpotMultiplier = 2.2,
        MagazineSize = 30,
        ReloadTime = 2.4,
        EffectiveRange = 480,
        RecoilPitch = 1.3,
        RecoilYaw = 0.45,
        RecoilKickZ = 0.38,
        ADSZoom = 56,
        Mobility = 0.98,
        Description = "Rugged 7.62mm stamped-steel battle rifle. Heavy per-bullet punch with aggressive vertical recoil.",
    },

    -- 4. BURST RIFLES
    ["BurstRifle"] = {
        Name = "Pulse-3 Tri-Burst Rifle",
        Class = "Burst",
        BaseDamage = 5.2,
        BaseFireRate = 3.6,
        BaseWeakSpotMultiplier = 2.3,
        MagazineSize = 27,
        ReloadTime = 2.1,
        EffectiveRange = 550,
        BurstCount = 3,
        RecoilPitch = 0.85,
        RecoilYaw = 0.25,
        RecoilKickZ = 0.35,
        ADSZoom = 52,
        Mobility = 1.0,
        Description = "Fires high-precision 3-round bursts per trigger pull. Combines pinpoint recoil grouping with high burst lethality.",
    },
    ["HeavyBurst"] = {
        Name = "Apex Pulse-5 Heavy Burst",
        Class = "Burst",
        BaseDamage = 4.7,
        BaseFireRate = 2.8,
        BaseWeakSpotMultiplier = 2.4,
        MagazineSize = 30,
        ReloadTime = 2.4,
        EffectiveRange = 600,
        BurstCount = 5,
        RecoilPitch = 1.1,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.42,
        ADSZoom = 50,
        Mobility = 0.98,
        Description = "Fires aggressive 5-round barrages. Overwhelms shielded targets with clustered kinetic impact waves.",
    },

    -- 5. SNIPERS (MASSIVELY BUFFED: High Base Damage, 3.5x-4.5x Headshot Multiplier!)
    ["MarksmanRifle"] = {
        Name = "Longbow Needle Sniper",
        Class = "Sniper",
        BaseDamage = 37.8,
        BaseFireRate = 0.95,
        BaseWeakSpotMultiplier = 4.0,
        MagazineSize = 5,
        ReloadTime = 2.4,
        EffectiveRange = 1200,
        RecoilPitch = 3.4,
        RecoilYaw = 0.35,
        RecoilKickZ = 0.75,
        ADSZoom = 35,
        Mobility = 0.90,
        Description = "Extreme-range needle precision rifle with a dual-ring optic. Massive 4.0x headshot multiplier erases targets on weakspot hits.",
    },
    ["AntiMaterial"] = {
        Name = "Titan .50-Cal Anti-Material Sniper",
        Class = "Sniper",
        BaseDamage = 76.5,
        BaseFireRate = 0.45,
        BaseWeakSpotMultiplier = 4.5,
        MagazineSize = 3,
        ReloadTime = 3.2,
        EffectiveRange = 1500,
        RecoilPitch = 5.2,
        RecoilYaw = 0.5,
        RecoilKickZ = 1.05,
        ADSZoom = 28,
        Mobility = 0.84,
        Description = "Catastrophic high-caliber anti-tank rifle. Slams targets with 4.5x weakspot devastation, piercing heavy shields and armor.",
    },
    ["LeverAction"] = {
        Name = "Outlaw Lever-Action Repeater",
        Class = "Sniper",
        BaseDamage = 23.4,
        BaseFireRate = 1.8,
        BaseWeakSpotMultiplier = 3.5,
        MagazineSize = 6,
        ReloadTime = 2.0,
        EffectiveRange = 750,
        RecoilPitch = 2.2,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.52,
        ADSZoom = 45,
        Mobility = 0.95,
        Description = "Classic heavy-lever action rifle. Snappy hammer cycling allows fluid rhythmic marksman fire with 3.5x headshot criticals.",
    },

    -- 6. SHOTGUNS
    ["SawedOff"] = {
        Name = "Double-Barrel Sawed-Off Shotgun",
        Class = "Shotgun",
        BaseDamage = 3.4,
        BaseFireRate = 2.4,
        BaseWeakSpotMultiplier = 1.8,
        MagazineSize = 2,
        ReloadTime = 1.8,
        EffectiveRange = 250,
        PelletCount = 8,
        RecoilPitch = 3.4,
        RecoilYaw = 0.5,
        RecoilKickZ = 0.85,
        ADSZoom = 65,
        Mobility = 1.04,
        Description = "Break-action twin-barrel blast. Fires 8 buckshot pellets simultaneously for massive 304 damage point-blank decimation.",
    },
    ["CombatShotgun"] = {
        Name = "Trench Pump Combat Shotgun",
        Class = "Shotgun",
        BaseDamage = 2.9,
        BaseFireRate = 1.4,
        BaseWeakSpotMultiplier = 1.9,
        MagazineSize = 6,
        ReloadTime = 2.6,
        EffectiveRange = 320,
        PelletCount = 10,
        RecoilPitch = 2.8,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.72,
        ADSZoom = 62,
        Mobility = 0.98,
        Description = "Full-length tube-fed pump shotgun with perforated heat shield. 10 high-velocity pellets per shell with tight choke.",
    },

    -- 7. HEAVY & EXPLOSIVE
    ["RocketLauncher"] = {
        Name = "Nova Rocket Cannon",
        Class = "Heavy",
        BaseDamage = 43.2,
        BaseFireRate = 0.8,
        BaseWeakSpotMultiplier = 1.5,
        MagazineSize = 3,
        ReloadTime = 3.4,
        EffectiveRange = 800,
        ExplosionRadius = 18,
        RecoilPitch = 3.8,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.95,
        ADSZoom = 55,
        Mobility = 0.88,
        Description = "Shoulder-fired rocket cannon. Fires high-explosive ordnance triggering catastrophic 18-stud kinetic shockwaves.",
    },
    ["GrenadeLauncher"] = {
        Name = "Thumper Cluster Grenade Launcher",
        Class = "Heavy",
        BaseDamage = 21.6,
        BaseFireRate = 1.6,
        BaseWeakSpotMultiplier = 1.5,
        MagazineSize = 6,
        ReloadTime = 3.0,
        EffectiveRange = 650,
        ExplosionRadius = 13,
        RecoilPitch = 2.5,
        RecoilYaw = 0.35,
        RecoilKickZ = 0.65,
        ADSZoom = 58,
        Mobility = 0.90,
        Description = "Revolving 6-shot grenade cylinder. Saturates combat zones with consecutive concussive blast craters.",
    },
    ["Minigun"] = {
        Name = "Vulcan Rotary Gatling Minigun",
        Class = "Heavy",
        BaseDamage = 3.2,
        BaseFireRate = 18.0,
        BaseWeakSpotMultiplier = 1.6,
        MagazineSize = 100,
        ReloadTime = 4.2,
        EffectiveRange = 420,
        RecoilPitch = 0.6,
        RecoilYaw = 0.5,
        RecoilKickZ = 0.25,
        ADSZoom = 60,
        Mobility = 0.82,
        Description = "Hexagonal 6-barrel rotary minigun with rapid spool-up. Unloads an unceasing storm of 100 rounds of sustained fire.",
    },

    -- 8. ENERGY & EXOTIC
    ["ContinuousLaser"] = {
        Name = "Helios Continuous Thermal Beam",
        Class = "Laser",
        BaseDamage = 2.7,
        BaseFireRate = 14.0,
        BaseWeakSpotMultiplier = 1.7,
        MagazineSize = 60,
        ReloadTime = 2.2,
        EffectiveRange = 500,
        IsContinuousBeam = true,
        RecoilPitch = 0.15,
        RecoilYaw = 0.1,
        RecoilKickZ = 0.05,
        ADSZoom = 56,
        Mobility = 1.0,
        Description = "Uninterrupted high-energy thermal laser. Melts through organic and robotic hulls with rapid ticking damage.",
    },
    ["PlasmaCannon"] = {
        Name = "Ion Arc Plasma Accelerator",
        Class = "Laser",
        BaseDamage = 13,
        BaseFireRate = 2.6,
        BaseWeakSpotMultiplier = 2.2,
        MagazineSize = 15,
        ReloadTime = 2.4,
        EffectiveRange = 600,
        RecoilPitch = 1.4,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.42,
        ADSZoom = 58,
        Mobility = 0.98,
        Description = "A heavy plasma accelerator fed by a canister cell, its barrel vents glowing as it fires. Every bolt hits like a slug: slow, steady, and hard.",
    },
    -- (0.62 BEAM LINEUP, owner: "arcwright class doesn't really make sense because there is so many less guns")
    ["QuadBeam"] = {
        Name = "Tesla Quadbeam",
        Class = "Laser",
        BaseDamage = 4.2,
        BaseFireRate = 10.0,
        BaseWeakSpotMultiplier = 1.6,
        MagazineSize = 50,
        ReloadTime = 2.5,
        EffectiveRange = 160,
        IsContinuousBeam = true,
        RecoilPitch = 0.2,
        RecoilYaw = 0.12,
        RecoilKickZ = 0.08,
        ADSZoom = 62,
        Mobility = 0.96,
        Description = "Four coils fire one fat, short beam. Brutal up close, it falls off fast at range.",
    },
    ["SparkPistol"] = {
        Name = "Spark Pistol",
        Class = "Laser",
        BaseDamage = 9.0,
        BaseFireRate = 4.0,
        BaseWeakSpotMultiplier = 2.2,
        MagazineSize = 16,
        ReloadTime = 1.6,
        EffectiveRange = 420,
        RecoilPitch = 1.1,
        RecoilYaw = 0.25,
        RecoilKickZ = 0.3,
        ADSZoom = 64,
        Mobility = 1.05,
        Description = "A cell-fed sidearm that spits single plasma darts. Quick to draw, quick to reload.",
    },
    ["Railgun"] = {
        Name = "Hyperion Particle Railgun",
        Class = "Laser",
        BaseDamage = 49.5,
        BaseFireRate = 0.85,
        BaseWeakSpotMultiplier = 3.6,
        MagazineSize = 4,
        ReloadTime = 2.8,
        EffectiveRange = 1200,
        RecoilPitch = 3.6,
        RecoilYaw = 0.25,
        RecoilKickZ = 0.88,
        ADSZoom = 40,
        Mobility = 0.90,
        Description = "Electromagnetic railgun firing superheated particle slugs. Devastating weakspot penetration and pinpoint accuracy.",
    },
    ["VoidDisintegrator"] = {
        Name = "Quantum Void Disintegrator",
        Class = "Laser",
        BaseDamage = 19.8,
        BaseFireRate = 2.1,
        BaseWeakSpotMultiplier = 2.8,
        MagazineSize = 12,
        ReloadTime = 2.5,
        EffectiveRange = 700,
        RecoilPitch = 1.8,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.5,
        ADSZoom = 50,
        Mobility = 0.98,
        Description = "Otherworldly weapon fueled by a void core glowing in its stock. Fires quantum disruption bolts that collapse target matter.",
    },

    -- 9. PISTOLS (PACK EXPANSION)
    ["FlintlockPistol"] = {
        Name = "Rusty Flintlock",
        Class = "Pistol",
        BaseDamage = 16.2,
        BaseFireRate = 0.9,
        BaseWeakSpotMultiplier = 2.6,
        MagazineSize = 1,
        ReloadTime = 3.0,
        EffectiveRange = 200,
        RecoilPitch = 2.0,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.5,
        ADSZoom = 64,
        Mobility = 1.0,
        Description = "Single-shot black-powder flintlock. Devastating per-ball damage, but you're reloading by hand after every trigger pull.",
    },
    ["CaptainsFlintlock"] = {
        Name = "Captain's Flintlock",
        Class = "Pistol",
        BaseDamage = 18.9,
        BaseFireRate = 0.95,
        BaseWeakSpotMultiplier = 2.8,
        MagazineSize = 1,
        ReloadTime = 2.8,
        EffectiveRange = 220,
        RecoilPitch = 2.1,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.52,
        ADSZoom = 64,
        Mobility = 1.0,
        Description = "An ornate officer's flintlock with a gilded barrel. Same brutal one-shot power as the rusty version, tuned a touch tighter.",
    },
    ["ColtM1911"] = {
        Name = "M1911 Sidearm",
        Class = "Pistol",
        BaseDamage = 5.2,
        BaseFireRate = 4.8,
        BaseWeakSpotMultiplier = 2.1,
        MagazineSize = 7,
        ReloadTime = 1.6,
        EffectiveRange = 420,
        RecoilPitch = 1.1,
        RecoilYaw = 0.25,
        RecoilKickZ = 0.3,
        ADSZoom = 63,
        Mobility = 1.03,
        Description = "Legendary .45 GI sidearm. Slower and punchier than the Viper, with a stout single-stack magazine.",
    },
    ["Luger"] = {
        Name = "Luger P08",
        Class = "Pistol",
        BaseDamage = 3.8,
        BaseFireRate = 6.8,
        BaseWeakSpotMultiplier = 2.1,
        MagazineSize = 8,
        ReloadTime = 1.3,
        EffectiveRange = 430,
        RecoilPitch = 0.7,
        RecoilYaw = 0.18,
        RecoilKickZ = 0.22,
        ADSZoom = 65,
        Mobility = 1.06,
        Description = "Elegant toggle-lock sidearm with a razor-light trigger. Snappy follow-up shots and pinpoint muzzle control.",
    },
    ["GoldenLuger"] = {
        Name = "Golden Luger",
        Class = "Pistol",
        BaseDamage = 4.5,
        BaseFireRate = 6.8,
        BaseWeakSpotMultiplier = 2.3,
        MagazineSize = 8,
        ReloadTime = 1.3,
        EffectiveRange = 450,
        RecoilPitch = 0.7,
        RecoilYaw = 0.18,
        RecoilKickZ = 0.22,
        ADSZoom = 65,
        Mobility = 1.06,
        Description = "A gilded collector's Luger. Same silky-fast cycling as the standard model with a harder-hitting load.",
    },

    -- 10. REVOLVERS (NEW CLASS)
    ["Revolver45"] = {
        Name = ".45 Long Colt Revolver",
        Class = "Revolver",
        BaseDamage = 8.5,
        BaseFireRate = 2.6,
        BaseWeakSpotMultiplier = 2.6,
        MagazineSize = 6,
        ReloadTime = 2.0,
        EffectiveRange = 480,
        RecoilPitch = 1.6,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.4,
        ADSZoom = 62,
        Mobility = 1.0,
        Description = "Classic six-shot wheelgun in .45 Long Colt. Balanced hand-cannon damage with a manageable kick.",
    },
    ["Revolver22"] = {
        Name = ".22 Pocket Revolver",
        Class = "Revolver",
        BaseDamage = 4.3,
        BaseFireRate = 4.2,
        BaseWeakSpotMultiplier = 2.0,
        MagazineSize = 8,
        ReloadTime = 1.6,
        EffectiveRange = 350,
        RecoilPitch = 0.9,
        RecoilYaw = 0.2,
        RecoilKickZ = 0.22,
        ADSZoom = 63,
        Mobility = 1.05,
        Description = "Tiny-caliber snub revolver. Weak per-shot but fast to cycle and nearly recoilless.",
    },
    ["Revolver357"] = {
        Name = ".357 Magnum Revolver",
        Class = "Revolver",
        BaseDamage = 11.7,
        BaseFireRate = 2.0,
        BaseWeakSpotMultiplier = 3.0,
        MagazineSize = 6,
        ReloadTime = 2.2,
        EffectiveRange = 500,
        RecoilPitch = 2.0,
        RecoilYaw = 0.35,
        RecoilKickZ = 0.48,
        ADSZoom = 60,
        Mobility = 0.98,
        Description = "Full-power .357 Magnum loads in a six-shot cylinder. Hits like a truck and snaps the wrist just as hard.",
    },

    -- 11. BURST / RIFLE / SNIPER (PACK EXPANSION)
    ["Quadshooter"] = {
        Name = "Quadshooter",
        Class = "Burst",
        BaseDamage = 4,
        BaseFireRate = 1.6,
        BaseWeakSpotMultiplier = 2.0,
        MagazineSize = 16,
        ReloadTime = 2.6,
        EffectiveRange = 380,
        BurstCount = 4,
        RecoilPitch = 1.6,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.4,
        ADSZoom = 58,
        Mobility = 0.96,
        Description = "Four rotating barrels dump a full volley on every pull. Slow to cycle back around, brutal when it lands.",
    },
    ["M16A2Rifle"] = {
        Name = "M16A2 Service Rifle",
        Class = "Rifle",
        BaseDamage = 5,
        BaseFireRate = 6.4,
        BaseWeakSpotMultiplier = 2.2,
        MagazineSize = 30,
        ReloadTime = 2.2,
        EffectiveRange = 460,
        RecoilPitch = 0.95,
        RecoilYaw = 0.32,
        RecoilKickZ = 0.32,
        ADSZoom = 55,
        Mobility = 0.99,
        Description = "Standard-issue service rifle. Middle-of-the-road in every stat, reliable, unremarkable, never lets you down.",
    },
    ["BBGunSniper"] = {
        Name = "\"Sniper\" BB Gun",
        Class = "Sniper",
        BaseDamage = 1.3,
        BaseFireRate = 8.0,
        BaseWeakSpotMultiplier = 1.5,
        MagazineSize = 50,
        ReloadTime = 1.2,
        EffectiveRange = 200,
        RecoilPitch = 0.1,
        RecoilYaw = 0.05,
        RecoilKickZ = 0.05,
        ADSZoom = 50,
        Mobility = 1.1,
        Description = "It barely qualifies. Almost no damage per pellet, but the 50-round hopper and total lack of recoil make it absurdly spammable.",
    },
    ["HuntersBow"] = {
        Name = "Hunter's Recurve Bow",
        Class = "Sniper",
        BaseDamage = 30.6,
        BaseFireRate = 1.1,
        BaseWeakSpotMultiplier = 4.0,
        MagazineSize = 1,
        ReloadTime = 1.0,
        EffectiveRange = 600,
        RecoilPitch = 0.5,
        RecoilYaw = 0.1,
        RecoilKickZ = 0.15,
        ADSZoom = 48,
        Mobility = 1.05,
        Description = "Silent draw-and-loose recurve bow. One arrow nocked at a time, but each one hits like a dedicated marksman round.",
    },

    -- 12. SHOTGUNS (PACK EXPANSION)
    ["IthacaM37"] = {
        Name = "M37 Pump",
        Class = "Shotgun",
        BaseDamage = 3.1,
        BaseFireRate = 1.6,
        BaseWeakSpotMultiplier = 1.8,
        MagazineSize = 5,
        ReloadTime = 2.4,
        EffectiveRange = 300,
        PelletCount = 9,
        RecoilPitch = 2.6,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.68,
        ADSZoom = 62,
        Mobility = 0.99,
        Description = "Bottom-ejecting pump classic. Well-rounded spread and a dependable 5-shell tube.",
    },
    ["StrikerShotgun"] = {
        Name = "Striker-12",
        Class = "Shotgun",
        BaseDamage = 2.5,
        BaseFireRate = 2.8,
        BaseWeakSpotMultiplier = 1.7,
        MagazineSize = 12,
        ReloadTime = 2.8,
        EffectiveRange = 280,
        PelletCount = 7,
        RecoilPitch = 2.0,
        RecoilYaw = 0.35,
        RecoilKickZ = 0.55,
        ADSZoom = 63,
        Mobility = 1.0,
        Description = "12-round rotary-mag combat shotgun. Trades per-shell punch for the fastest cyclic rate in the class.",
    },
    ["BenelliM4"] = {
        Name = "M4 Combat Shotgun",
        Class = "Shotgun",
        BaseDamage = 3.2,
        BaseFireRate = 2.2,
        BaseWeakSpotMultiplier = 1.9,
        MagazineSize = 7,
        ReloadTime = 2.2,
        EffectiveRange = 320,
        PelletCount = 9,
        RecoilPitch = 2.2,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.58,
        ADSZoom = 62,
        Mobility = 1.0,
        Description = "Premium gas-operated combat shotgun. The best all-around numbers of any shell-fed weapon in the roster.",
    },
    ["Blunderbuss"] = {
        Name = "Blunderbuss",
        Class = "Shotgun",
        BaseDamage = 2.3,
        BaseFireRate = 0.9,
        BaseWeakSpotMultiplier = 1.5,
        MagazineSize = 1,
        ReloadTime = 3.2,
        EffectiveRange = 180,
        PelletCount = 14,
        RecoilPitch = 3.4,
        RecoilYaw = 0.6,
        RecoilKickZ = 0.9,
        ADSZoom = 68,
        Mobility = 0.92,
        Description = "Flared-muzzle antique. Dumps a huge, wildly inaccurate spread at point-blank range, then takes forever to reload.",
    },
    ["Remington870"] = {
        Name = "870 Classic",
        Class = "Shotgun",
        BaseDamage = 3.2,
        BaseFireRate = 1.5,
        BaseWeakSpotMultiplier = 1.9,
        MagazineSize = 6,
        ReloadTime = 2.5,
        EffectiveRange = 300,
        PelletCount = 9,
        RecoilPitch = 2.7,
        RecoilYaw = 0.4,
        RecoilKickZ = 0.7,
        ADSZoom = 62,
        Mobility = 0.98,
        Description = "The industry-standard pump shotgun. No surprises, no weaknesses, just a reliable 6-shell workhorse.",
    },
    ["AgedBlunderbuss"] = {
        Name = "Aged Blunderbuss",
        Class = "Shotgun",
        BaseDamage = 2.7,
        BaseFireRate = 0.85,
        BaseWeakSpotMultiplier = 1.6,
        MagazineSize = 1,
        ReloadTime = 3.4,
        EffectiveRange = 170,
        PelletCount = 16,
        RecoilPitch = 3.6,
        RecoilYaw = 0.65,
        RecoilKickZ = 0.95,
        ADSZoom = 68,
        Mobility = 0.90,
        Description = "A weathered relic blunderbuss. Even wider spread than its polished cousin, at the cost of an even slower reload.",
    },
    ["HuntingShotgun"] = {
        Name = "Long-Choke Hunting Shotgun",
        Class = "Shotgun",
        BaseDamage = 3.6,
        BaseFireRate = 1.3,
        BaseWeakSpotMultiplier = 2.0,
        MagazineSize = 4,
        ReloadTime = 2.0,
        EffectiveRange = 380,
        PelletCount = 6,
        RecoilPitch = 2.4,
        RecoilYaw = 0.3,
        RecoilKickZ = 0.6,
        ADSZoom = 60,
        Mobility = 1.0,
        Description = "Tightly-choked hunting gun. Fewer, tighter pellets than a combat shotgun, with real reach for a scattergun.",
    },

    -- 13. LAUNCHERS (NEW CLASS)
    ["AT4Launcher"] = {
        Name = "AT-4 Anti-Armor Launcher",
        Class = "Launcher",
        BaseDamage = 55.8,
        BaseFireRate = 0.5,
        BaseWeakSpotMultiplier = 1.4,
        MagazineSize = 1,
        ReloadTime = 3.6,
        EffectiveRange = 700,
        ExplosionRadius = 16,
        RecoilPitch = 4.2,
        RecoilYaw = 0.4,
        RecoilKickZ = 1.0,
        ADSZoom = 55,
        Mobility = 0.85,
        Description = "Single-shot disposable anti-armor rocket. The hardest one-shot hit in the game, then it's an empty tube.",
    },
    ["BazookaLauncher"] = {
        Name = "Bazooka [Kinda]",
        Class = "Launcher",
        BaseDamage = 34.2,
        BaseFireRate = 0.7,
        BaseWeakSpotMultiplier = 1.3,
        MagazineSize = 2,
        ReloadTime = 3.2,
        EffectiveRange = 600,
        ExplosionRadius = 14,
        RecoilPitch = 3.6,
        RecoilYaw = 0.5,
        RecoilKickZ = 0.85,
        ADSZoom = 56,
        Mobility = 0.88,
        Description = "A janky, vaguely-bazooka-shaped tube. It's not pretty, but it still turns things into a fireball two shots at a time.",
    },
}

-- ==================== [7 UNIQUE MELEE WEAPONS] ====================
local MeleeWeapons: { [string]: MeleeWeapon } = {
    -- (0.97: the default melee -- owner: "make it a simple knife, similar to counter strikes"; same DPS as the crowbar, faster)
    ["Knife"] = {
        Id = "Knife",
        Name = "Combat Knife",
        Rarity = "Common",
        BaseDamage = 72,
        AttackRate = 2.0,
        Range = 7,
        CritChance = 0.14,
        CritMultiplier = 1.8,
        MovementSpeedBonus = 0.08,
        ArmorPenetration = 0.10,
        Description = "A plain tactical knife, everyone's melee. Quick slashes combo; the heavy is a committed stab.",
        BladeColor = Color3.fromRGB(78, 82, 92),
        HandleColor = Color3.fromRGB(30, 31, 36),
        CostGold = 0,
        CostShards = 0,
    },
    ["Crowbar"] = {
        Id = "Crowbar",
        Name = "Crowbar",
        Rarity = "Common",
        BaseDamage = 90,
        AttackRate = 1.6,
        Range = 8,
        CritChance = 0.12,
        CritMultiplier = 1.8,
        MovementSpeedBonus = 0.06,
        ArmorPenetration = 0.10,
        Description = "A heavy steel crowbar, everyone's melee. Light swings combo, the heavy swing crushes.",
        BladeColor = Color3.fromRGB(120, 125, 135),
        HandleColor = Color3.fromRGB(40, 42, 48),
        CostGold = 0,
        CostShards = 0,
    },
    ["Kukri"] = {
        Id = "Kukri",
        Name = "Combat Kukri",
        Rarity = "Rare",
        BaseDamage = 115,
        AttackRate = 2.2,
        Range = 9,
        CritChance = 0.20,
        CritMultiplier = 2.0,
        MovementSpeedBonus = 0.12,
        ArmorPenetration = 0.15,
        Description = "Curved forward-heavy blade built for chopping. Swift strikes grant +12% movement speed while held.",
        BladeColor = Color3.fromRGB(200, 210, 225),
        HandleColor = Color3.fromRGB(20, 25, 35),
        CostGold = 350,
        CostShards = 25,
    },
    ["BowieKnife"] = {
        Id = "BowieKnife",
        Name = "Huntsman Bowie Knife",
        Rarity = "Epic",
        BaseDamage = 175,
        AttackRate = 1.3,
        Range = 10,
        CritChance = 0.15,
        CritMultiplier = 2.2,
        MovementSpeedBonus = 0.05,
        ArmorPenetration = 0.25,
        Description = "Heavy fixed blade with a clipped point. Brutal chopping strikes stagger foes and pierce 25% armor.",
        BladeColor = Color3.fromRGB(180, 185, 195),
        HandleColor = Color3.fromRGB(55, 40, 30),
        CostGold = 700,
        CostShards = 50,
    },
    ["BaseballBat"] = {
        Id = "BaseballBat",
        Name = "Aluminum Baseball Bat",
        Rarity = "Uncommon",
        BaseDamage = 130,
        AttackRate = 1.1,
        Range = 10,
        CritChance = 0.10,
        CritMultiplier = 2.4,
        MovementSpeedBonus = 0.0,
        ArmorPenetration = 0.05,
        Description = "Blunt aluminum bat. Slow swings, but a solid hit knocks foes staggering with a huge crit multiplier.",
        BladeColor = Color3.fromRGB(210, 215, 220),
        HandleColor = Color3.fromRGB(25, 25, 30),
        CostGold = 500,
        CostShards = 35,
    },
    ["FireExtinguisher"] = {
        Id = "FireExtinguisher",
        Name = "Fire Extinguisher",
        Rarity = "Uncommon",
        BaseDamage = 150,
        AttackRate = 0.9,
        Range = 9,
        CritChance = 0.08,
        CritMultiplier = 2.0,
        MovementSpeedBonus = -0.02,
        ArmorPenetration = 0.08,
        Description = "It's heavy, it's awkward, and it hits like a sledgehammer. Not what it was designed for.",
        BladeColor = Color3.fromRGB(200, 30, 30),
        HandleColor = Color3.fromRGB(40, 40, 40),
        CostGold = 600,
        CostShards = 40,
    },
    ["MilitaryAxe"] = {
        Id = "MilitaryAxe",
        Name = "Military Tomahawk",
        Rarity = "Legendary",
        BaseDamage = 245,
        AttackRate = 1.0,
        Range = 10,
        CritChance = 0.22,
        CritMultiplier = 2.6,
        MovementSpeedBonus = 0.02,
        ArmorPenetration = 0.40,
        Description = "Wide single-bit combat tomahawk. Wide, heavy chops that pierce 40% of enemy armor.",
        BladeColor = Color3.fromRGB(140, 145, 150),
        HandleColor = Color3.fromRGB(60, 45, 30),
        CostGold = 1200,
        CostShards = 90,
    },
    ["RiotShield"] = {
        Id = "RiotShield",
        Name = "Riot Shield Bash",
        Rarity = "Mythic",
        BaseDamage = 260,
        AttackRate = 1.0,
        Range = 11,
        CritChance = 0.10,
        CritMultiplier = 1.8,
        MovementSpeedBonus = 0.0,
        ArmorPenetration = 0.20,
        Description = "A riot shield swung like a battering ram. Slow, huge base damage, and wide reach, built to shatter groups of foes.",
        BladeColor = Color3.fromRGB(90, 95, 105),
        HandleColor = Color3.fromRGB(20, 20, 25),
        CostGold = 2200,
        CostShards = 180,
    },
}

-- ==================== [5 GLOVE COSMETICS] ====================
-- IMPORTANT: viewmodel hand parts sit a fraction of a stud from the camera. A heavily bump-mapped PBR
-- material (Fabric, CorrodedMetal, DiamondPlate, Rock, Concrete, ...) that looks fine at normal distance
-- reads as a crumpled/faceted mess at that range -- its normal map is being viewed at a wildly exaggerated
-- scale. Stick to smooth materials (SmoothPlastic, Metal, Neon, Plastic) for every glove here.
local Gloves: { [string]: GloveCosmetic } = {
    ["Tactical"] = {
        Id = "Tactical",
        Name = "Operator Tactical Gloves",
        Rarity = "Common",
        Description = "Standard issue ballistic fiber gloves with carbon-reinforced knuckle protectors.",
        PrimaryColor = Color3.fromRGB(35, 38, 45),
        AccentColor = Color3.fromRGB(65, 70, 80),
        Material = Enum.Material.SmoothPlastic, -- was Fabric; its bump-map looked crumpled at viewmodel range
        KnuckleMaterial = Enum.Material.Metal,
        CostGold = 0,
        CostShards = 0,
    },
    ["CyberNeon"] = {
        Id = "CyberNeon",
        Name = "Cyber Neon Strikers",
        Rarity = "Rare",
        Description = "High-tech combat gloves with pulsing cyan and magenta luminescent circuitry.",
        PrimaryColor = Color3.fromRGB(15, 20, 35),
        AccentColor = Color3.fromRGB(0, 240, 255),
        Material = Enum.Material.SmoothPlastic,
        KnuckleMaterial = Enum.Material.Neon,
        CostGold = 450,
        CostShards = 30,
    },
    ["Molten"] = {
        Id = "Molten",
        Name = "Molten Dragonhide Gauntlets",
        Rarity = "Epic",
        Description = "Charcoal dragon scale weave with glowing molten lava veins pulsing across the knuckles.",
        PrimaryColor = Color3.fromRGB(25, 20, 20),
        AccentColor = Color3.fromRGB(255, 90, 20),
        Material = Enum.Material.Metal, -- was CorrodedMetal; same close-range bump-map problem
        KnuckleMaterial = Enum.Material.Neon,
        CostGold = 850,
        CostShards = 60,
    },
    ["TitanPlated"] = {
        Id = "TitanPlated",
        Name = "Titan Plated Gauntlets",
        Rarity = "Legendary",
        Description = "Reinforced heavy tungsten alloy armor plating designed for frontline titan skirmishers.",
        PrimaryColor = Color3.fromRGB(50, 55, 65),
        AccentColor = Color3.fromRGB(240, 190, 40),
        Material = Enum.Material.Metal, -- was DiamondPlate; same close-range bump-map problem
        KnuckleMaterial = Enum.Material.Metal,
        CostGold = 1400,
        CostShards = 110,
    },
    ["VoidWraps"] = {
        Id = "VoidWraps",
        Name = "Void Weaver Wraps",
        Rarity = "Mythic",
        Description = "Ethereal bandages infused with dark matter, releasing floating violet embers into the air.",
        PrimaryColor = Color3.fromRGB(18, 12, 28),
        AccentColor = Color3.fromRGB(190, 60, 255),
        Material = Enum.Material.SmoothPlastic, -- was Fabric; same close-range bump-map problem
        KnuckleMaterial = Enum.Material.Neon,
        CostGold = 2500,
        CostShards = 200,
    },
}

-- ==================== [TITLES: a ladder that follows real progression] ====================
-- Rarity says how hard a title is; requirements track the actual game (kills, floors per difficulty,
-- bosses, bot-skill clears, level, gear) so the best titles take the longest. Buffs are small and grow
-- with rarity (base HP is 100, so HP buffs stay modest). Progress is checked by ItemData.TitleProgress,
-- shared by the server (claiming) and the client (progress bars / claim button).
-- Rarity = difficulty (4 per tier, Common -> Mythic, sorted by Order); re-check these whenever run lengths, the
-- gun lineup or levels change (2026-10-02 rework: runs 5/10/15/20/30 floors, 19 lineup guns).
-- Check kinds: Default, Kills, Bosses, Headshots (sniper only), WeakSpots (any gun), MeleeKills, Explosive, Discovered, BestStreak, Level,
-- FloorOn (Diff + Floor), SkillClears (MinSkill [+ MinDiff]), EquipWeapon (Rarity [+ MinUpgrade]),
-- GearAtLeast (Rarity + Count), TreeNodes, and (2026-10-02 "challenging atmosphere" pass) HeadshotRun (weak-spot hits in a
-- row, no body shot / miss between), SuperBosses, BossesOn (MinDiff), FlawlessBosses (no damage taken during the fight),
-- FastBossOn (MinDiff; dead within 30 s of your first hit), DeathlessRun (Diff: a full run without losing a life),
-- NoHitFloors (MinDiff), RiftTier, EliteKills.
-- Retired = true: no longer offered (progression-only titles from before the pass) -- owners keep and can wear them.
local Titles: { [string]: TitleDefinition } = {
    -- COMMON: first sessions
    ["Rookie"] = {
        Id = "Rookie", Title = "Rookie", Rarity = "Common", Order = 1,
        Description = "Everyone starts somewhere. +2% Move Speed.",
        Requirement = "Unlocked by default", Check = { Kind = "Default" },
        RewardGold = 0, RewardMats = {},
        Color = Color3.fromRGB(180, 190, 200),
        StatBuffs = { ["MovementSpeed"] = 0.02 },
    },
    ["SidearmSpecialist"] = {
        Id = "SidearmSpecialist", Title = "Trigger Finger", Rarity = "Common", Order = 2,
        Description = "+3% Reload Speed.",
        Requirement = "Eliminate 500 enemies", Check = { Kind = "Kills", Need = 500 }, -- (UPDATE 8: kill titles x5 for packs, owner)
        RewardGold = 150, RewardMats = { Scrap = 10 },
        Color = Color3.fromRGB(190, 205, 220),
        StatBuffs = { ["ReloadSpeedBonus"] = 0.03 },
    },
    ["TargetPlinker"] = {
        Id = "TargetPlinker", Title = "Plinker", Rarity = "Common", Order = 3,
        Description = "+3% Weak-Spot Damage.",
        Requirement = "Land 50 weak-spot hits (any gun)", Check = { Kind = "WeakSpots", Need = 50 },
        RewardGold = 150, RewardMats = { Scrap = 10 },
        Color = Color3.fromRGB(175, 215, 195),
        StatBuffs = { ["WeakSpotMultiplier"] = 0.03 },
    },

    -- UNCOMMON: a few hours in
    ["IncursionScout"] = {
        Id = "IncursionScout", Title = "Scout", Rarity = "Common", Order = 4,
        Description = "+5 Max HP, +2% Damage Reduction.",
        Requirement = "Clear an Easy run (floor 6)", Check = { Kind = "FloorOn", Diff = "Easy", Floor = 6 },
        RewardGold = 400, RewardMats = { Scrap = 25 },
        Color = Color3.fromRGB(60, 210, 150),
        StatBuffs = { ["MaxHP"] = 5, ["DamageReduction"] = 0.02 },
    },
    ["CadenceGunner"] = {
        Id = "CadenceGunner", Title = "Cadence", Rarity = "Uncommon", Order = 5, Retired = true,
        Description = "+3% Fire Rate.",
        Requirement = "Reach level 10", Check = { Kind = "Level", Need = 10 },
        RewardGold = 400, RewardMats = { Scrap = 25 },
        Color = Color3.fromRGB(80, 220, 120),
        StatBuffs = { ["FireRateBonus"] = 0.03 },
    },
    ["Gunslinger"] = {
        Id = "Gunslinger", Title = "Gunhand", Rarity = "Uncommon", Order = 6,
        Description = "+3% Move Speed, +4% Reload Speed.",
        Requirement = "Eliminate 5,000 enemies", Check = { Kind = "Kills", Need = 5000 },
        RewardGold = 500, RewardMats = { Scrap = 30 },
        Color = Color3.fromRGB(0, 220, 100),
        StatBuffs = { ["MovementSpeed"] = 0.03, ["ReloadSpeedBonus"] = 0.04 },
    },
    ["Bladesmith"] = {
        Id = "Bladesmith", Title = "Brawler", Rarity = "Uncommon", Order = 7,
        Description = "+6 Melee Damage, +2% Move Speed.",
        Requirement = "Eliminate 50 enemies with melee", Check = { Kind = "MeleeKills", Need = 50 },
        RewardGold = 500, RewardMats = { Scrap = 30 },
        Color = Color3.fromRGB(160, 70, 240),
        StatBuffs = { ["MeleeDamage"] = 6, ["MovementSpeed"] = 0.02 },
    },

    -- RARE: committed players
    ["ApexDeadeye"] = {
        Id = "ApexDeadeye", Title = "Deadeye", Rarity = "Rare", Order = 9,
        Description = "+6% Weak-Spot Damage, +1% Crit Chance.",
        Requirement = "Land 750 weak-spot hits (any gun)", Check = { Kind = "WeakSpots", Need = 750 },
        RewardGold = 1000, RewardMats = { Scrap = 40, Alloy = 5 },
        Color = Color3.fromRGB(0, 170, 255),
        StatBuffs = { ["WeakSpotMultiplier"] = 0.06, ["CritChance"] = 0.01 },
    },
    ["TitanSlayer"] = {
        Id = "TitanSlayer", Title = "Titan Slayer", Rarity = "Rare", Order = 10,
        Description = "+4% Damage, +8 Max HP.",
        Requirement = "Defeat 25 bosses", Check = { Kind = "Bosses", Need = 25 },
        RewardGold = 1000, RewardMats = { Scrap = 40, Alloy = 5 },
        Color = Color3.fromRGB(240, 50, 50),
        StatBuffs = { ["IncreasedDamage"] = 0.04, ["MaxHP"] = 8 },
    },
    ["BiomeConqueror"] = {
        Id = "BiomeConqueror", Title = "Delver", Rarity = "Uncommon", Order = 8,
        Description = "+4% Damage, +3% Damage Reduction.",
        Requirement = "Clear a Normal run (floor 6)", Check = { Kind = "FloorOn", Diff = "Normal", Floor = 6 },
        RewardGold = 1200, RewardMats = { Scrap = 50, Alloy = 8 },
        Color = Color3.fromRGB(255, 180, 40),
        StatBuffs = { ["IncreasedDamage"] = 0.04, ["DamageReduction"] = 0.03 },
    },
    ["Demolitionist"] = {
        Id = "Demolitionist", Title = "Through and Through", Rarity = "Rare", Order = 11,
        Description = "+5% Damage, +4 Armor.",
        Requirement = "Land 1,500 piercing hits (high-caliber guns)", Check = { Kind = "Pierced", Need = 1500 },
        RewardGold = 1200, RewardMats = { Scrap = 50, Alloy = 8 },
        Color = Color3.fromRGB(255, 140, 30),
        StatBuffs = { ["IncreasedDamage"] = 0.05, ["Armor"] = 4 },
    },

    -- EPIC: dozens of hours
    ["PointBlankBruiser"] = {
        Id = "PointBlankBruiser", Title = "Exterminator", Rarity = "Epic", Order = 14,
        Description = "+6% Damage, +10 Max HP.",
        Requirement = "Eliminate 50,000 enemies", Check = { Kind = "Kills", Need = 50000 },
        RewardGold = 2500, RewardMats = { Alloy = 20, Prism = 2 },
        Color = Color3.fromRGB(80, 160, 240),
        StatBuffs = { ["IncreasedDamage"] = 0.06, ["MaxHP"] = 10 },
    },
    ["ArsenalMaster"] = {
        Id = "ArsenalMaster", Title = "Collector", Rarity = "Epic", Order = 16, Retired = true,
        Description = "+5% Damage, +6% Magazine Size.",
        Requirement = "Discover all 19 guns", Check = { Kind = "Discovered", Need = 19 },
        RewardGold = 2500, RewardMats = { Alloy = 20, Prism = 2 },
        Color = Color3.fromRGB(255, 200, 40),
        StatBuffs = { ["IncreasedDamage"] = 0.05, ["MagSizeBonus"] = 0.06 },
    },
    ["FocusVirtuoso"] = {
        Id = "FocusVirtuoso", Title = "Locked In", Rarity = "Epic", Order = 15,
        Description = "+5% Damage, +2% Crit Chance.",
        Requirement = "Reach a 25x Focus Streak", Check = { Kind = "BestStreak", Need = 25 },
        RewardGold = 2500, RewardMats = { Alloy = 20, Prism = 2 },
        Color = Color3.fromRGB(220, 80, 220),
        StatBuffs = { ["IncreasedDamage"] = 0.05, ["CritChance"] = 0.02 },
    },
    ["RelicHoarder"] = {
        Id = "RelicHoarder", Title = "Hoarder", Rarity = "Rare", Order = 12, Retired = true,
        Description = "+8% Gold Find, +4% Luck.",
        Requirement = "Wear 5 Rare-or-better gear pieces at once", Check = { Kind = "GearAtLeast", Rarity = "Rare", Count = 5 },
        RewardGold = 3000, RewardMats = { Alloy = 25, Prism = 3 },
        Color = Color3.fromRGB(120, 220, 255),
        StatBuffs = { ["GoldBonus"] = 0.08, ["Luck"] = 0.04 },
    },
    ["HyperVelocityStalker"] = {
        Id = "HyperVelocityStalker", Title = "Warlord", Rarity = "Epic", Order = 17,
        Description = "+4% Move Speed, +2% Crit Chance.",
        Requirement = "Clear a Brutal run (floor 6)", Check = { Kind = "FloorOn", Diff = "Brutal", Floor = 6 },
        RewardGold = 3000, RewardMats = { Alloy = 25, Prism = 3 },
        Color = Color3.fromRGB(50, 240, 180),
        StatBuffs = { ["MovementSpeed"] = 0.04, ["CritChance"] = 0.02 },
    },

    -- LEGENDARY: long-term goals
    ["CelestialSentinel"] = {
        Id = "CelestialSentinel", Title = "Sentinel", Rarity = "Rare", Order = 13,
        Description = "+5% Damage, +10 Max HP, +3% Damage Reduction.",
        Requirement = "Clear a Hard run (floor 6, Biome Superboss)", Check = { Kind = "FloorOn", Diff = "Hard", Floor = 6 },
        RewardGold = 6000, RewardMats = { Alloy = 40, Prism = 6 },
        Color = Color3.fromRGB(230, 245, 255),
        StatBuffs = { ["IncreasedDamage"] = 0.05, ["MaxHP"] = 10, ["DamageReduction"] = 0.03 },
    },
    ["VoidSovereign"] = {
        Id = "VoidSovereign", Title = "Kingslayer", Rarity = "Legendary", Order = 18,
        Description = "+8% Damage, +8% Weak-Spot Damage.",
        Requirement = "Defeat 150 bosses", Check = { Kind = "Bosses", Need = 150 },
        RewardGold = 6000, RewardMats = { Alloy = 40, Prism = 6 },
        Color = Color3.fromRGB(190, 50, 255),
        StatBuffs = { ["IncreasedDamage"] = 0.08, ["WeakSpotMultiplier"] = 0.08 },
    },
    ["RelicMaster"] = {
        Id = "RelicMaster", Title = "Relic Master", Rarity = "Legendary", Order = 19, Retired = true,
        Description = "+7% Damage, +8% Crit Damage.",
        Requirement = "Equip a Rare gun upgraded to +10", Check = { Kind = "EquipWeapon", Rarity = "Rare", MinUpgrade = 10 }, -- (RARITY v4: was Legendary)
        RewardGold = 6000, RewardMats = { Alloy = 40, Prism = 6 },
        Color = Color3.fromRGB(255, 150, 40),
        StatBuffs = { ["IncreasedDamage"] = 0.07, ["CritMultiplier"] = 0.08 },
    },
    ["UnbrokenAegis"] = {
        Id = "UnbrokenAegis", Title = "Aegis", Rarity = "Legendary", Order = 20, Retired = true,
        Description = "+20 Max HP, +8 Armor, +1 HP Regen.",
        Requirement = "Reach level 45", Check = { Kind = "Level", Need = 45 },
        RewardGold = 6000, RewardMats = { Alloy = 40, Prism = 6 },
        Color = Color3.fromRGB(80, 190, 255),
        StatBuffs = { ["MaxHP"] = 20, ["Armor"] = 8, ["HPRegen"] = 1 },
    },

    -- MYTHIC: the hardest things in the game
    ["SingularityWeaver"] = {
        Id = "SingularityWeaver", Title = "Mythbearer", Rarity = "Mythic", Order = 21, Retired = true,
        Description = "+10% Damage, +3% Crit Chance.",
        Requirement = "Equip a Mythic gun", Check = { Kind = "EquipWeapon", Rarity = "Mythic" },
        RewardGold = 12000, RewardMats = { Prism = 15 },
        Color = Color3.fromRGB(255, 60, 60),
        StatBuffs = { ["IncreasedDamage"] = 0.10, ["CritChance"] = 0.03 },
    },
    ["OmniConstellation"] = {
        Id = "OmniConstellation", Title = "Seasoned", Rarity = "Mythic", Order = 22,
        Description = "+10% Damage, +20 Max HP, +5% Luck.",
        Requirement = "Reach level 60", Check = { Kind = "Level", Need = 60 },
        RewardGold = 12000, RewardMats = { Prism = 15 },
        Color = Color3.fromRGB(255, 100, 200),
        StatBuffs = { ["IncreasedDamage"] = 0.10, ["MaxHP"] = 20, ["Luck"] = 0.05 },
    },
    ["VoltaicAscendant"] = {
        Id = "VoltaicAscendant", Title = "Aim God", Rarity = "Mythic", Order = 23, -- (owner 2026-10-04: bot step 10 is "Celestial")
        Description = "+12% Damage, +5% Fire Rate, +3% Move Speed.",
        Requirement = "Clear 50 floors at bot skill 10 on Brutal or harder", Check = { Kind = "SkillClears", MinSkill = 10, MinDiff = "Brutal", Need = 50 },
        RewardGold = 15000, RewardMats = { Prism = 20 },
        Color = Color3.fromRGB(255, 230, 60),
        StatBuffs = { ["IncreasedDamage"] = 0.12, ["FireRateBonus"] = 0.05, ["MovementSpeed"] = 0.03 },
    },
    ["GodOfIncursion"] = {
        Id = "GodOfIncursion", Title = "Nightwalker", Rarity = "Epic", Order = 24,
        Description = "+8% Damage, +15 Max HP, +4% Damage Reduction.",
        Requirement = "Clear a Nightmare run (floor 6)", Check = { Kind = "FloorOn", Diff = "Nightmare", Floor = 6 },
        RewardGold = 20000, RewardMats = { Prism = 25 },
        Color = Color3.fromRGB(150, 60, 255),
        StatBuffs = { ["IncreasedDamage"] = 0.08, ["MaxHP"] = 15, ["DamageReduction"] = 0.04 },
    },

    -- BOSS TRIALS (endgame boss fights, BossTrials): tier III = Legendary, tier V = Mythic
    ["ArchonBane"] = {
        Id = "ArchonBane", Title = "Archon's Bane", Rarity = "Legendary", Order = 25,
        Description = "+8% Damage, +15 Max HP.",
        Requirement = "Clear the Seraph Archon trial on tier III", Check = { Kind = "BossTrial", Boss = "Archon", Tier = 3 },
        RewardGold = 8000, RewardMats = { Prism = 10 },
        Color = Color3.fromRGB(255, 214, 120),
        StatBuffs = { ["IncreasedDamage"] = 0.08, ["MaxHP"] = 15 },
    },
    ["Timekeeper"] = {
        Id = "Timekeeper", Title = "Timekeeper", Rarity = "Legendary", Order = 26,
        Description = "+8% Damage, +4% Fire Rate.",
        Requirement = "Clear the Chronarch trial on tier III", Check = { Kind = "BossTrial", Boss = "Chronarch", Tier = 3 },
        RewardGold = 8000, RewardMats = { Prism = 10 },
        Color = Color3.fromRGB(90, 230, 255),
        StatBuffs = { ["IncreasedDamage"] = 0.08, ["FireRateBonus"] = 0.04 },
    },
    ["EchoBreaker"] = {
        Id = "EchoBreaker", Title = "Echobreaker", Rarity = "Legendary", Order = 27,
        Description = "+8% Damage, +3% Move Speed.",
        Requirement = "Clear the Echo Warden trial on tier III", Check = { Kind = "BossTrial", Boss = "EchoWarden", Tier = 3 },
        RewardGold = 8000, RewardMats = { Prism = 10 },
        Color = Color3.fromRGB(190, 110, 255),
        StatBuffs = { ["IncreasedDamage"] = 0.08, ["MovementSpeed"] = 0.03 },
    },
    ["Slagbreaker"] = {
        Id = "Slagbreaker", Title = "Slagbreaker", Rarity = "Legendary", Order = 27.5,
        Description = "+8% Damage, +6% Weak Spot Damage.",
        Requirement = "Clear the Forgeheart trial on tier III", Check = { Kind = "BossTrial", Boss = "Forgeheart", Tier = 3 },
        RewardGold = 8000, RewardMats = { Prism = 10 },
        Color = Color3.fromRGB(255, 130, 40),
        StatBuffs = { ["IncreasedDamage"] = 0.08, ["WeakSpotMultiplier"] = 0.06 },
    },
    ["Godslayer"] = {
        Id = "Godslayer", Title = "Godslayer", Rarity = "Mythic", Order = 28,
        Description = "+14% Damage, +25 Max HP, +4% Crit Chance.",
        Requirement = "Clear the Seraph Archon trial on tier V", Check = { Kind = "BossTrial", Boss = "Archon", Tier = 5 },
        RewardGold = 25000, RewardMats = { Prism = 30 },
        Color = Color3.fromRGB(255, 236, 170),
        StatBuffs = { ["IncreasedDamage"] = 0.14, ["MaxHP"] = 25, ["CritChance"] = 0.04 },
    },
    ["Chronobreaker"] = {
        Id = "Chronobreaker", Title = "Chronobreaker", Rarity = "Mythic", Order = 29,
        Description = "+14% Damage, +6% Fire Rate, +3% Move Speed.",
        Requirement = "Clear the Chronarch trial on tier V", Check = { Kind = "BossTrial", Boss = "Chronarch", Tier = 5 },
        RewardGold = 25000, RewardMats = { Prism = 30 },
        Color = Color3.fromRGB(140, 240, 255),
        StatBuffs = { ["IncreasedDamage"] = 0.14, ["FireRateBonus"] = 0.06, ["MovementSpeed"] = 0.03 },
    },
    ["Forgeborn"] = {
        Id = "Forgeborn", Title = "Forgeborn", Rarity = "Mythic", Order = 30.5,
        Description = "+14% Damage, +10% Weak Spot Damage, +20 Max HP.",
        Requirement = "Clear the Forgeheart trial on tier V", Check = { Kind = "BossTrial", Boss = "Forgeheart", Tier = 5 },
        RewardGold = 25000, RewardMats = { Prism = 30 },
        Color = Color3.fromRGB(255, 200, 120),
        StatBuffs = { ["IncreasedDamage"] = 0.14, ["WeakSpotMultiplier"] = 0.10, ["MaxHP"] = 20 },
    },
    ["VoidWarden"] = {
        Id = "VoidWarden", Title = "Void Warden", Rarity = "Mythic", Order = 30,
        Description = "+14% Damage, +25 Max HP, +5% Damage Reduction.",
        Requirement = "Clear the Echo Warden trial on tier V", Check = { Kind = "BossTrial", Boss = "EchoWarden", Tier = 5 },
        RewardGold = 25000, RewardMats = { Prism = 30 },
        Color = Color3.fromRGB(210, 150, 255),
        StatBuffs = { ["IncreasedDamage"] = 0.14, ["MaxHP"] = 25, ["DamageReduction"] = 0.05 },
    },
}

-- ==================== [DUNGEON DIFFICULTY MODES] ====================
-- RUN LENGTHS v4 (2026-10-22, owner: "each dungeon should only be 6 floors, with simply a boss at the end, with a 10% chance to get
-- a miniboss on the 3rd room"): every difficulty is 6 floors, its boss on 6 (Easy / Normal: a major boss x BOSS_PACE.FinaleMajor;
-- Hard+: the biome superboss), no fixed mid-run bosses; ItemData.RollMidBoss makes floor 3 a mini-boss floor 10% of runs.
-- (v3 was Easy / Normal 5, Hard / Brutal 6, Nightmare / Torment 8, Cataclysm+ 10, with a boss on 3 / 4 / 5.) Maps (Rifts.FLOORS)
-- and the Daily Challenge keep 5 floors: DungeonRuns pins their last-floor boss with config.BossArena.
-- Each difficulty unlocks by clearing the one below it (+ a character level): ItemData.DifficultyUnlock.
local DifficultyModes: { [string]: DifficultyMode } = {
    ["Easy"] = {
        Id = "Easy",
        Name = "Standard Descent (6 Floors)",
        MaxWaves = 6,
        Description = "6 floors ending in a boss. A quick run, great for new marksmen.",
        Color = Color3.fromRGB(0, 220, 100),
        MiniBossWaves = {  },
        BossWaves = { 6 },
        SuperBossWave = nil,
        RewardMultiplier = 1.0,
    },
    ["Normal"] = {
        Id = "Normal",
        Name = "Veteran Descent (6 Floors)",
        MaxWaves = 6,
        Description = "6 floors ending in a Major Boss with an intense moveset.",
        Color = Color3.fromRGB(0, 160, 240),
        MiniBossWaves = {  },
        BossWaves = { 6 },
        SuperBossWave = nil,
        RewardMultiplier = 1.45,
    },
    ["Hard"] = {
        Id = "Hard",
        Name = "Hard Descent (6 Floors)",
        MaxWaves = 6,
        Description = "6 floors of relentless warfare, ending on the Biome Superboss.",
        Color = Color3.fromRGB(255, 50, 60),
        MiniBossWaves = {  },
        BossWaves = {  },
        SuperBossWave = 6,
        RewardMultiplier = 2.2,
    },
    ["Brutal"] = {
        Id = "Brutal",
        Name = "Brutal Descent (6 Floors)",
        MaxWaves = 6,
        Description = "6 floors. Enemies hit much harder than on Hard. Bring a real build. Superboss on 6.",
        Color = Color3.fromRGB(255, 110, 0),
        MiniBossWaves = {  },
        BossWaves = {  },
        SuperBossWave = 6,
        RewardMultiplier = 2.9,
    },
    ["Nightmare"] = {
        Id = "Nightmare",
        Name = "Nightmare Descent (6 Floors)",
        MaxWaves = 6,
        Description = "6 floors, every enemy tougher and faster than Brutal. Superboss on 6.",
        Color = Color3.fromRGB(150, 0, 60),
        MiniBossWaves = {  },
        BossWaves = {  },
        SuperBossWave = 6,
        RewardMultiplier = 3.6,
    },
    -- (owner 2026-10-04: "add 3 more tiers of difficulty" -- and the rarest drops come from these, not from Endless)
    ["Torment"] = {
        Id = "Torment",
        Name = "Torment Descent (6 Floors)",
        MaxWaves = 6,
        Description = "6 floors past Nightmare: every enemy hits harder and moves faster. Mythic drops begin here. Superboss on 6.",
        Color = Color3.fromRGB(200, 30, 40),
        MiniBossWaves = {  },
        BossWaves = {  },
        SuperBossWave = 6,
        RewardMultiplier = 4.4,
    },
    ["Cataclysm"] = {
        Id = "Cataclysm",
        Name = "Cataclysm Descent (6 Floors)",
        MaxWaves = 6,
        Description = "6 floors where one mistake ends you, with far more loot than Torment. Superboss on 6.",
        Color = Color3.fromRGB(255, 120, 20),
        MiniBossWaves = {  },
        BossWaves = {  },
        SuperBossWave = 6,
        RewardMultiplier = 5.3,
    },
    ["Oblivion"] = {
        Id = "Oblivion",
        Name = "Oblivion Descent (6 Floors)",
        MaxWaves = 6,
        Description = "6 floors past Cataclysm: more Mythics and Relics than ever. Superboss on 6.",
        Color = Color3.fromRGB(235, 235, 245),
        MiniBossWaves = {  },
        BossWaves = {  },
        SuperBossWave = 6,
        RewardMultiplier = 6.4,
    },
    -- TIERS 9-14 (2026-10-05, owner: "Add 6 more tiers that make sense for now"): the ladder to level 400 (ItemData.MONSTER_LEVEL)
    ["Ruin"] = {
        Id = "Ruin",
        Name = "Ruin Descent (6 Floors)",
        MaxWaves = 6,
        Description = "Monster level 100-130. Past Oblivion: the long climb starts here. Superboss on 6.",
        Color = Color3.fromRGB(200, 90, 50),
        MiniBossWaves = {  },
        BossWaves = {  },
        SuperBossWave = 6,
        RewardMultiplier = 7.6,
    },
    ["Dread"] = {
        Id = "Dread",
        Name = "Dread Descent (6 Floors)",
        MaxWaves = 6,
        Description = "Monster level 128-165. Every enemy is a threat. Superboss on 6.",
        Color = Color3.fromRGB(150, 60, 200),
        MiniBossWaves = {  },
        BossWaves = {  },
        SuperBossWave = 6,
        RewardMultiplier = 9.0,
    },
    ["Apocalypse"] = {
        Id = "Apocalypse",
        Name = "Apocalypse Descent (6 Floors)",
        MaxWaves = 6,
        Description = "Monster level 160-205. The world ends a little more every floor. Superboss on 6.",
        Color = Color3.fromRGB(255, 70, 30),
        MiniBossWaves = {  },
        BossWaves = {  },
        SuperBossWave = 6,
        RewardMultiplier = 10.6,
    },
    ["Annihilation"] = {
        Id = "Annihilation",
        Name = "Annihilation Descent (6 Floors)",
        MaxWaves = 6,
        Description = "Monster level 200-250. Built for maxed trees and best-in-slot gear. Superboss on 6.",
        Color = Color3.fromRGB(220, 30, 70),
        MiniBossWaves = {  },
        BossWaves = {  },
        SuperBossWave = 6,
        RewardMultiplier = 12.4,
    },
    ["Eternity"] = {
        Id = "Eternity",
        Name = "Eternity Descent (6 Floors)",
        MaxWaves = 6,
        Description = "Monster level 245-310. Very few will see the end of it. Superboss on 6.",
        Color = Color3.fromRGB(120, 210, 255),
        MiniBossWaves = {  },
        BossWaves = {  },
        SuperBossWave = 6,
        RewardMultiplier = 14.5,
    },
    ["Singularity"] = {
        Id = "Singularity",
        Name = "Singularity Descent (6 Floors)",
        MaxWaves = 6,
        Description = "Monster level 305-400. The deepest tier so far. Superboss on 6.",
        Color = Color3.fromRGB(255, 215, 110),
        MiniBossWaves = {  },
        BossWaves = {  },
        SuperBossWave = 6,
        RewardMultiplier = 17.0,
    },
    -- (legacy key: old saves / stats. ENDLESS is now a game type -- any difficulty, no last floor; ItemData.RunMode)
    ["Endless"] = {
        Id = "Endless",
        Name = "Endless Abyss (Infinite)",
        MaxWaves = 9999,
        Description = "Survive infinite waves with non-stop scaling enemy health, speed, and continuous boss encounters every 5 floors. Starts tougher than Nightmare and never stops climbing.",
        Color = Color3.fromRGB(180, 50, 240),
        MiniBossWaves = { 5, 15, 25, 35, 45, 55, 65, 75, 85, 95 },
        BossWaves = { 10, 20, 30, 40, 50, 60, 70, 80, 90, 100 },
        SuperBossWave = nil,
        RewardMultiplier = 4.4,
    },
}

-- Eight item rarities. CELESTIAL + TRANSCENDENT (owner 2026-10-04: "some more rarities") sit above Mythic as the
-- level 60-100 chase: Celestial drops on Nightmare and Endless, Transcendent only on Endless (ItemData.MaxRarityRank).
-- Celestial = two affixes forced to T5+, a 60% unique trait; Transcendent = every affix T5+, a trait and a prefix.
-- ==================== RARITY v4 (UPDATE 8 "The Revamp", LOOT builder; vault "UPDATE 8 - The Revamp.md" 11b) ====================
-- Owner: "5 rarities" -- the 15-step ladder (Epic, Legendary, Celestial .. Infinite) is gone. The "new best for each
-- difficulty" job moved to ITEM LEVEL (AffixTierCap / TIER_ILVL: the top affix tiers only roll on harder content) and to
-- the difficulty-tied Relics. RARITY = HOW MANY LINES (LineBand):
--   Common   grey    0 lines       a base to craft on
--   Uncommon green   1-2 lines     early upgrades
--   Rare     YELLOW  3-6 lines     the workhorse (owner's pick: yellow)
--   Mythic   red     4-7 lines     a Rare + one more line: only a Mythic reaches 7 (the "Mythic line"; Ascension Essence turns
--                                  a Rare into a Mythic by adding it). Drops from MYTHIC_FROM (Torment) up, odds rising by tier.
--   Relic    orange  the unique items (the old exotics, ItemData.Exotics; item.Exotic + Rarity "Relic"), never rolled
-- OLD SAVES: ItemData.NormalizeRarities(state) on load (Epic / Legendary -> Rare, Mythic .. Infinite -> Mythic, exotics ->
-- Relic); RarityRank answers old names too (RARITY_ALIAS) so anything not yet normalised still sorts / compares sanely.
-- The old 15 names stay as display GRADES (ItemData.LEGACY_RARITIES + their colours): titles, cosmetics and the skill-tree
-- gems (GemData) keep that ladder until Phase 3 replaces gems.
local Rarities: { WeaponRarity } = { "Common", "Uncommon", "Rare", "Mythic", "Relic" }
-- (the LEGACY_RARITIES / LegacyRank / RARITY_ALIAS tables: right after `local ItemData = {}` below)

local RarityColors: { [WeaponRarity]: Color3 } = {
    Common = Color3.fromRGB(180, 180, 180),
    Uncommon = Color3.fromRGB(50, 205, 50),
    Rare = Color3.fromRGB(250, 222, 64), -- (UPDATE 8 RARITY v4: yellow, was blue 30,144,255)
    Relic = Color3.fromRGB(255, 150, 40), -- (= EXOTIC_COLOR: the uniques keep their own colour)
    Zenith = Color3.fromRGB(170, 255, 236), -- (= ZENITH_COLOR, CHASE ITEMS 2026-11-06: a display key only -- no item has Rarity "Zenith")
    -- (below: the OLD ladder's colours, kept as display grades for titles / cosmetics / gems -- not item rarities any more)
    Epic = Color3.fromRGB(148, 0, 211),
    Legendary = Color3.fromRGB(255, 140, 0),
    Mythic = Color3.fromRGB(255, 20, 60),
    Celestial = Color3.fromRGB(40, 225, 255),     -- (bright sky cyan: clear of Rare's deeper blue)
    Transcendent = Color3.fromRGB(255, 236, 150), -- (white gold; labels shimmer through a prismatic gradient)
    Astral = Color3.fromRGB(120, 110, 255), Empyrean = Color3.fromRGB(255, 248, 225), Primordial = Color3.fromRGB(150, 235, 90),
    Sovereign = Color3.fromRGB(255, 95, 80), Eclipse = Color3.fromRGB(255, 150, 50), Genesis = Color3.fromRGB(255, 140, 215),
    Infinite = Color3.fromRGB(235, 245, 255),
}

-- (RARITY v4 per-rarity numbers: Rare = about the old Epic / Legendary, Mythic = the old Legendary / Mythic, Relic = Mythic's.
-- The old names keep their values for anything not normalised yet. Phase 6 re-anchors the power curve.)
local RarityPowerMult: { [WeaponRarity]: number } = {
    Common = 1.0,
    Uncommon = 1.25,
    Rare = 2.1, Relic = 2.8, -- (RARITY v4; Mythic below = 2.8)
    Epic = 2.1,
    Legendary = 2.8,
    Mythic = 2.8, -- (RARITY v4: was 3.8)
    Celestial = 5.0,
    Transcendent = 6.8,
    Astral = 9, Empyrean = 12, Primordial = 16, Sovereign = 21, Eclipse = 28, Genesis = 37, Infinite = 50,
}

local BaseSellPrices: { [WeaponRarity]: number } = {
    Common = 10,
    Uncommon = 25,
    Rare = 100, Relic = 800, -- (RARITY v4: Rare was 60 -- the workhorse drops often, so it sells for less than the old Legendary)
    Epic = 150,
    Legendary = 400,
    Mythic = 600, -- (RARITY v4: was 1500)
    Celestial = 2000,
    Transcendent = 5000,
    Astral = 9000, Empyrean = 15000, Primordial = 25000, Sovereign = 40000, Eclipse = 65000, Genesis = 100000, Infinite = 160000,
}

local PrefixPool = {
    { Id = "P_Sharp", Name = "Sharpened", Stat = "FlatDamage", Min = 8, Max = 16, Tier = 1 },
    { Id = "P_Honed", Name = "Honed", Stat = "FlatDamage", Min = 18, Max = 32, Tier = 2 },
    { Id = "P_Devastating", Name = "Devastating", Stat = "FlatDamage", Min = 35, Max = 60, Tier = 3 },
    { Id = "P_Savage", Name = "Savage", Stat = "IncreasedDamage", Min = 0.08, Max = 0.16, Tier = 1 },
    { Id = "P_Ferocious", Name = "Ferocious", Stat = "IncreasedDamage", Min = 0.18, Max = 0.30, Tier = 2 },
    { Id = "P_Apex", Name = "Apex", Stat = "IncreasedDamage", Min = 0.32, Max = 0.50, Tier = 3 },
    { Id = "P_Rapid", Name = "Rapid", Stat = "FireRateBonus", Min = 0.08, Max = 0.15, Tier = 1 },
    { Id = "P_Hyper", Name = "Hyper", Stat = "FireRateBonus", Min = 0.16, Max = 0.28, Tier = 2 },
    { Id = "P_Overclocked", Name = "Overclocked", Stat = "FireRateBonus", Min = 0.30, Max = 0.45, Tier = 3 },
    { Id = "P_Extended", Name = "Extended", Stat = "MagSizeBonus", Min = 0.12, Max = 0.25, Tier = 1 },
    { Id = "P_DrumFed", Name = "Drum-Fed", Stat = "MagSizeBonus", Min = 0.28, Max = 0.50, Tier = 2 },
    { Id = "P_QuickLoad", Name = "Quick-Load", Stat = "ReloadSpeedBonus", Min = 0.10, Max = 0.22, Tier = 1 },
    { Id = "P_Sleight", Name = "Sleight-Cycle", Stat = "ReloadSpeedBonus", Min = 0.25, Max = 0.40, Tier = 2 },
}

local SuffixPool = {
    { Id = "S_Focus", Name = "of Focus", Stat = "StreakDamageBonus", Min = 0.015, Max = 0.03, Tier = 1 },
    { Id = "S_Zen", Name = "of Zen", Stat = "StreakDamageBonus", Min = 0.035, Max = 0.06, Tier = 2 },
    { Id = "S_Precision", Name = "of Precision", Stat = "WeakSpotMultiplier", Min = 0.15, Max = 0.35, Tier = 1 },
    { Id = "S_Deadeye", Name = "of the Sure Shot", Stat = "WeakSpotMultiplier", Min = 0.40, Max = 0.75, Tier = 2 },
    { Id = "S_Chance", Name = "of Opportunity", Stat = "CritChance", Min = 0.04, Max = 0.08, Tier = 1 },
    { Id = "S_Lethality", Name = "of Lethality", Stat = "CritMultiplier", Min = 0.25, Max = 0.55, Tier = 1 },
    { Id = "S_Execution", Name = "of Execution", Stat = "CritMultiplier", Min = 0.60, Max = 1.10, Tier = 2 },
    { Id = "S_FastSwap", Name = "of Quickdraw", Stat = "ReloadSpeedBonus", Min = 0.12, Max = 0.25, Tier = 1 },
}

-- UNIQUE TRAITS (2026-10-02 rework, owner: "no AOE -- the game should require you to kill each enemy"; "traits should be
-- very rare"). Every trait works on the enemy you hit (or on you): no splash, no chains, no explosions. A weapon rolls
-- one with ItemData.TRAIT_CHANCE (Rare 0.4% ... Mythic 25%) -- Legendary no longer guarantees one. Ids are saved
-- with weapons; SaveService refreshes Name / Description from this catalog on load.
local UniqueTraitsCatalog: { UniqueTrait } = {
    { Id = "Singularity", Tier = "Epic", Name = "Singularity Collapse", TriggerChance = 0.30,
      Description = "Weak-spot hits have a 30% chance to collapse on the target, striking it again for 80% of the hit's damage." },
    { Id = "Supernova", Tier = "Rare", Name = "Supernova Core", TriggerChance = 0.35,
      Description = "Critical hits have a 35% chance to set the target ablaze for 150% of the hit's damage over 3 seconds." },
    { Id = "ChainLightning", Tier = "Epic", Name = "Static Build-Up", TriggerChance = 1.0,
      Description = "Every 5th hit on the same enemy calls lightning down on it for 250% of the hit's damage." },
    { Id = "TemporalStasis", Tier = "Common", Name = "Temporal Dilator", TriggerChance = 0.35,
      Description = "Hits have a 35% chance to slow the target by 50% for 2.5 seconds." },
    { Id = "VampiricSoul", Tier = "Rare", Name = "Soul Leech", TriggerChance = 1.0,
      Description = "15% of the damage this weapon's hits deal is returned to you as health." },
    { Id = "HyperBeam", Tier = "Rare", Name = "Last Light", TriggerChance = 1.0,
      Description = "The last 3 rounds of every magazine deal 100% more damage." },
    { Id = "Guillotine", Tier = "Legendary", Name = "Guillotine", TriggerChance = 1.0,
      Description = "Hits execute non-boss enemies below 15% health (elites below 7%)." },
    { Id = "Overflow", Tier = "Epic", Name = "Overflow", TriggerChance = 1.0,
      Description = "All damage beyond what kills an enemy carries into your next hit (within 3 seconds)." },
    { Id = "Bloodhound", Tier = "Rare", Name = "Bloodhound", TriggerChance = 1.0,
      Description = "After a kill, your next hit on a different enemy deals 80% more damage." },
    { Id = "HuntersFocus", Tier = "Common", Name = "Hunter's Focus", TriggerChance = 1.0,
      Description = "Each hit in a row on the same enemy deals 5% more damage (up to 50%). Switching targets resets it." },
    { Id = "MarrowTap", Tier = "Common", Name = "Marrow Tap", TriggerChance = 1.0,
      Description = "Weak-spot hits heal you for 2% of your max health." },
    { Id = "PhantomRound", Tier = "Epic", Name = "Phantom Round", TriggerChance = 1.0,
      Description = "Every 6th trigger pull that hits deals 200% more damage." },
    -- 0.51 new traits (all single-target, no splash)
    { Id = "SteadyHands", Tier = "Common", Name = "Steady Hands", TriggerChance = 1.0,
      Description = "While you're standing still your hits deal 15% more damage." },
    { Id = "OpeningVolley", Tier = "Common", Name = "Opening Volley", TriggerChance = 1.0,
      Description = "Your first hit on each enemy deals 60% more damage." },
    { Id = "QuickLoader", Tier = "Common", Name = "Quick Loader", TriggerChance = 1.0,
      Description = "Kills put 2 rounds back in your magazine." },
    { Id = "Momentum", Tier = "Rare", Name = "Momentum", TriggerChance = 1.0,
      Description = "Each kill within 4 seconds of the last adds 10% damage (up to 50%). 4 seconds without a kill resets it." },
    { Id = "Brittle", Tier = "Rare", Name = "Brittle Rounds", TriggerChance = 1.0,
      Description = "Hits on enemies suffering any ailment (burn, bleed, chill, decay) deal 30% more damage." },
    { Id = "Headhunter", Tier = "Epic", Name = "Crownshot", TriggerChance = 1.0, -- (UPDATE 8 originality: was "Headhunter"; the id stays)
      Description = "Weak-spot hits deal 35% more damage. Body shots deal 10% less." },
    { Id = "SecondWind", Tier = "Epic", Name = "Second Wind", TriggerChance = 1.0,
      Description = "Kills heal you for 6% of your max health." },
    { Id = "ReapersToll", Tier = "Legendary", Name = "Reaper's Toll", TriggerChance = 1.0,
      Description = "Kills refill your whole magazine instantly." },
    { Id = "Overcharge", Tier = "Legendary", Name = "Overcharge", TriggerChance = 1.0,
      Description = "Hits on enemies above 90% health deal 75% more damage." },
}
local GearAffixPools: { [string]: { { Stat: string, Name: string, Min: number, Max: number } } } = {
    Helmet = {
        { Stat = "WeakSpotMultiplier", Name = "Precision Visor", Min = 0.10, Max = 0.25 },
        { Stat = "CritChance", Name = "Target Acquisition", Min = 0.03, Max = 0.07 },
        { Stat = "Dexterity", Name = "Agile Optic", Min = 2, Max = 6 },
        { Stat = "MaxHP", Name = "Reinforced Crown", Min = 15, Max = 40 },
    },
    ChestPiece = {
        { Stat = "MaxHP", Name = "Kevlar Plating", Min = 25, Max = 65 },
        { Stat = "Armor", Name = "Composite Shielding", Min = 10, Max = 30 },
        { Stat = "DamageReduction", Name = "Kinetic Weave", Min = 0.04, Max = 0.10 },
        { Stat = "Vitality", Name = "Endurance Core", Min = 3, Max = 8 },
    },
    Leggings = {
        { Stat = "MovementSpeed", Name = "Hydraulic Actuators", Min = 0.05, Max = 0.14 },
        { Stat = "MaxHP", Name = "Exo-Frame Support", Min = 15, Max = 45 },
        { Stat = "Armor", Name = "Shin Guards", Min = 6, Max = 20 },
        { Stat = "Dexterity", Name = "Flex Joint", Min = 2, Max = 6 },
    },
    Boots = {
        { Stat = "MovementSpeed", Name = "Jet Thrusters", Min = 0.08, Max = 0.18 },
        { Stat = "Dexterity", Name = "Lightweight Soles", Min = 2, Max = 7 },
        { Stat = "DamageReduction", Name = "Shock Absorbers", Min = 0.03, Max = 0.08 },
    },
    Ring = {
        { Stat = "CritChance", Name = "Glinting Band", Min = 0.03, Max = 0.08 },
        { Stat = "CritMultiplier", Name = "Carnage Loop", Min = 0.15, Max = 0.35 },
        { Stat = "IncreasedDamage", Name = "Force Channel", Min = 0.06, Max = 0.15 },
        { Stat = "Strength", Name = "Titan Seal", Min = 2, Max = 6 },
        { Stat = "Luck", Name = "Gambler Signet", Min = 3, Max = 8 },
        { Stat = "GoldBonus", Name = "Midas Touch", Min = 0.10, Max = 0.25 },
        { Stat = "ReloadSpeedBonus", Name = "Swift Grip Band", Min = 0.08, Max = 0.20 },
        { Stat = "MagSizeBonus", Name = "Deep Chamber Ring", Min = 0.10, Max = 0.22 },
    },
    Necklace = {
        { Stat = "AllAttributes", Name = "Pendant of Harmony", Min = 2, Max = 5 },
        { Stat = "IncreasedDamage", Name = "Pendant of Power", Min = 0.08, Max = 0.18 },
        { Stat = "HPRegen", Name = "Amulet of Vitality", Min = 2, Max = 6 },
        { Stat = "Luck", Name = "Four-Leaf Talisman", Min = 3, Max = 10 },
        { Stat = "GoldBonus", Name = "Treasure Hunter Choker", Min = 0.12, Max = 0.30 },
    },
}

local function RollBetween(min: number, max: number): number
    local raw = min + math.random() * (max - min)
    if max >= 10 then
        return math.round(raw)
    else
        return math.round(raw * 1000) / 1000
    end
end

local ItemData = {}
-- (UPDATE 8 RARITY v4, see the RARITY v4 block further down)
ItemData.LEGACY_RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Transcendent",
    "Astral", "Empyrean", "Primordial", "Sovereign", "Eclipse", "Genesis", "Infinite" }
ItemData.LegacyRank = {}
for i, r in ipairs(ItemData.LEGACY_RARITIES) do ItemData.LegacyRank[r] = i end
-- old name -> new name (save normalisation + RarityRank lookups of old names)
ItemData.RARITY_ALIAS = { Epic = "Rare", Legendary = "Rare", Celestial = "Mythic", Transcendent = "Mythic", Astral = "Mythic",
    Empyrean = "Mythic", Primordial = "Mythic", Sovereign = "Mythic", Eclipse = "Mythic", Genesis = "Mythic", Infinite = "Mythic",
    Exotic = "Relic" }
ItemData.RARE_COLOR = Color3.fromRGB(250, 222, 64) -- (UPDATE 8: Rare is yellow)
-- The difficulty ladder (easiest -> hardest). Endless isn't on it: it's a game type you play at any of these.
ItemData.DifficultyOrder = { "Easy", "Normal", "Hard", "Brutal", "Nightmare", "Torment", "Cataclysm", "Oblivion", "Ruin", "Dread", "Apocalypse", "Annihilation", "Eternity", "Singularity" }
ItemData.DifficultyRank = {}
for k, d in ipairs(ItemData.DifficultyOrder) do ItemData.DifficultyRank[d] = k end
ItemData.DifficultyRank.Endless = 5 -- (legacy runs: about Nightmare)
-- A run's key on the wire / in rooms: "Torment" or "Endless:Torment" (the legacy bare "Endless" = Endless on Nightmare).
-- -> difficulty, endless
function ItemData.ParseRunKey(key: any): (string?, boolean)
    if type(key) ~= "string" then return nil, false end
    if key == "Endless" then return "Nightmare", true end
    local tier = string.match(key, "^Endless:(%a+)$")
    if tier then
        if ItemData.DifficultyRank[tier] and tier ~= "Endless" then return tier, true end
        return nil, false
    end
    if ItemData.DifficultyRank[key] and key ~= "Endless" then return key, false end
    return nil, false
end
function ItemData.RunKey(difficulty: string, endless: boolean?): string
    return endless and ("Endless:" .. difficulty) or difficulty
end
-- The floor schedule of a run: the difficulty's own (a last floor, its boss floors), or ENDLESS -- no last floor, a
-- mini-boss every 5th and a major boss every 10th, at that difficulty's toughness and rewards.
local endlessModes = {}
-- (fixes 2026-10-16 #1, playtester: "bosses appear too often shouldn't be every other room"): every run has at most
-- ONE mid-run boss + the finale (Brutal 3 / 6, Nightmare + Torment 4 / 8, Cataclysm+ 5 / 10); the mini-bosses that
-- filled the gaps (2 / 3 / 6 / 7) are gone from the main ladder -- they stay on Hard 3 and in Endless.
-- Is this floor a boss floor (mini, major or super) on that difficulty's schedule? (It used to be "every 5th floor"
-- everywhere; RUN LENGTHS v3 put bosses on 2 / 3 / 4 / 6 ... -- every boss-floor check goes through here.)
function ItemData.IsBossFloor(difficulty: string?, endless: any, floor: number?): boolean
    floor = floor or 1
    local m = ItemData.RunMode(difficulty, endless == true)
    if m.Endless or floor > (m.MaxWaves or 0) then return floor % 5 == 0 end
    if m.SuperBossWave == floor then return true end
    return table.find(m.BossWaves or {}, floor) ~= nil or table.find(m.MiniBossWaves or {}, floor) ~= nil
end
-- the 10% floor-3 mini-boss (RUN LENGTHS v4): rolled once per run on the holder (the solo run / the party), sets cfg.BossArena
ItemData.MIDBOSS = { Floor = 3, Chance = 0.10 }
function ItemData.RollMidBoss(holder: any, cfg: any)
    if cfg.BossArena ~= nil or cfg.Endless or cfg.BossTrial or cfg.AscTrial or cfg.Raid then return end
    if (cfg.FloorNumber or 1) ~= ItemData.MIDBOSS.Floor then return end
    if holder.MidBoss == nil then holder.MidBoss = math.random() < ItemData.MIDBOSS.Chance end
    if holder.MidBoss then cfg.BossArena = true end
end
local function BossOf(cfg: any): boolean if cfg.BossArena ~= nil then return cfg.BossArena == true end return cfg.BossTrial ~= nil or ItemData.IsBossFloor(cfg.Difficulty, cfg.Endless, cfg.FloorNumber) end -- (Boss Trials: boss arena)
ItemData.IsBossConfig = function(cfg: any): boolean return BossOf(cfg) end

function ItemData.RunMode(difficulty: string?, endless: boolean?): any
    local base = DifficultyModes[difficulty or "Easy"] or DifficultyModes.Easy
    if not endless then return base end
    local m = endlessModes[base.Id]
    if not m then
        local e = DifficultyModes.Endless
        m = table.clone(base)
        m.Name = "Endless " .. base.Id
        m.MaxWaves = e.MaxWaves
        m.MiniBossWaves, m.BossWaves, m.SuperBossWave = e.MiniBossWaves, e.BossWaves, nil
        m.Endless = true
        endlessModes[base.Id] = m
    end
    return m
end


-- The rigged lineup (real meshes + rigged arms, see WeaponRigs) is the whole loot pool. Every other entry is
-- an old asset-pack gun: Legacy = never rolled, sold or listed (kept only so its data still resolves).
ItemData.Lineup = {
    "Glock17", "DEAGLE", "TEC9", "RHINO",
    "UZI", "MP5", "P90", "MP7",
    "AK47", "SCAR", "M4A1", "AUG", "F2000",
    "R870", "BM4", "AA12",
    "AWP", "M82", "SCOUT",
    -- 0.48 weapon drop
    "M249", "PKM", "M60", "HK21",
    "TAR21", "GALIL", "HK416",
    "MP40", "PPSH", "VECTOR",
    "USAS12", "DBARREL", "KSG", "M590",
    "USP", "P226", "SR9", "PX4",
    "SVD", "SKS", "M40", "EMR", "MK11",
    "BEAM",
    -- 0.62 beam lineup (art/weapons/Guns_Beam.blend, tools/beam_guns.py)
    "ContinuousLaser", "QuadBeam", "Railgun", "PlasmaCannon", "VoidDisintegrator", "SparkPistol",
}
do
    local inLineup = {}
    for _, id in ipairs(ItemData.Lineup) do inLineup[id] = true end
    for id, def in pairs(BaseWeapons) do
        if not inLineup[id] then def.Legacy = true end
    end
end
-- PIERCE (2026-10-02, owner: "high-caliber guns can pierce"): a shot carries on through its target into the enemies
-- lined up behind it. Targets = how many more enemies it can hit; Falloff = damage kept per enemy passed (body-shot
-- damage, no weak-spot bonus). A gun def may set Pierce itself; these are the lineup's high-caliber guns.
ItemData.PIERCE = {
    AWP = { Targets = 3, Falloff = 0.8 }, SCOUT = { Targets = 2, Falloff = 0.75 }, M82 = { Targets = 2, Falloff = 0.7 },
    DEAGLE = { Targets = 1, Falloff = 0.6 }, RHINO = { Targets = 1, Falloff = 0.65 },
    M40 = { Targets = 3, Falloff = 0.8 }, SVD = { Targets = 2, Falloff = 0.75 }, MK11 = { Targets = 1, Falloff = 0.7 }, EMR = { Targets = 1, Falloff = 0.7 }, SKS = { Targets = 1, Falloff = 0.65 }, PKM = { Targets = 1, Falloff = 0.6 }, M60 = { Targets = 1, Falloff = 0.6 },
}
for id, pr in pairs(ItemData.PIERCE) do
    if BaseWeapons[id] and not BaseWeapons[id].Pierce then BaseWeapons[id].Pierce = pr end
end
function ItemData.PierceOf(w: any): any?
    local base = w and BaseWeapons[w.BaseId]
    return base and base.Pierce or nil
end
ItemData.BaseWeapons = BaseWeapons
ItemData.MeleeWeapons = MeleeWeapons
-- the melees in the game right now (owner 2026-10-02: the Crowbar is THE melee; looks come from skins). The others stay
-- defined for old saves only -- SaveService refunds them and puts the Crowbar back in hand.
ItemData.MeleeLineup = { "Knife" } -- (0.97: the crowbar is retired)
function ItemData.IsActiveMelee(id: string?): boolean
    return id ~= nil and table.find(ItemData.MeleeLineup, id) ~= nil
end
ItemData.Gloves = Gloves

-- ==================== [DROP-ONLY COSMETIC SETS: GLOVES, SLEEVES, WEAPON FINISHES] ====================
-- Each set = one glove + one sleeve + one weapon finish sharing a palette. Every difficulty has TWO sets:
-- an "Enemy" set (any regular enemy, <1% per kill) and a "Boss" set (mini/major/super bosses only, a few
-- % per boss kill). To add a set later, add one row here -- the gloves/sleeves/finishes, drop tables,
-- Armory listing and viewmodel all pick it up automatically.
local ArmSkins: { [string]: ArmSkin } = {
    ["Standard"] = {
        Id = "Standard", Name = "Standard Issue Sleeves", Rarity = "Common",
        Description = "Plain field-grey combat sleeves.",
        SleeveColor = Color3.fromRGB(48, 52, 60), CuffColor = Color3.fromRGB(34, 36, 42),
        Material = Enum.Material.SmoothPlastic,
    },
}
local WeaponSkins: { [string]: WeaponSkin } = {
    ["Factory"] = {
        Id = "Factory", Name = "Factory Finish", Rarity = "Common",
        Description = "The gun as it left the factory (tinted by its rarity).",
        KeepTexture = true, Tint = Color3.new(1, 1, 1),
    },
}

type CosmeticSetDef = {
    Id: string, Name: string, Difficulty: string, Source: "Enemy" | "Boss", Rarity: WeaponRarity,
    Glove: Color3, GloveAccent: Color3, GloveMetal: boolean?,
    Sleeve: Color3, Cuff: Color3, Stripe: Color3?,
    Skin: Color3, SkinKeepTexture: boolean, SkinReflect: number?, SkinMaterial: Enum.Material?, SkinAnimated: string?,
    Flavor: string,
}
local C = Color3.fromRGB
local CosmeticSets: { CosmeticSetDef } = {
    -- EASY
    { Id = "Scrapper", Name = "Scrapper", Difficulty = "Easy", Source = "Enemy", Rarity = "Rare",
      Glove = C(92, 70, 52), GloveAccent = C(150, 120, 80), Sleeve = C(96, 88, 70), Cuff = C(70, 60, 48), Stripe = C(170, 140, 60),
      Skin = C(196, 172, 128), SkinKeepTexture = false, SkinMaterial = Enum.Material.SmoothPlastic, Flavor = "Patched together from arena salvage." },
    { Id = "Warden", Name = "Warden", Difficulty = "Easy", Source = "Boss", Rarity = "Epic",
      Glove = C(34, 44, 66), GloveAccent = C(120, 150, 200), GloveMetal = true, Sleeve = C(40, 52, 78), Cuff = C(160, 170, 185),
      Skin = C(72, 88, 116), SkinKeepTexture = false, SkinReflect = 0.1, Flavor = "Issued to the ones who hold the line." },
    -- NORMAL
    { Id = "Ember", Name = "Ember", Difficulty = "Normal", Source = "Enemy", Rarity = "Epic",
      Glove = C(48, 30, 26), GloveAccent = C(210, 100, 50), Sleeve = C(70, 36, 30), Cuff = C(40, 26, 22), Stripe = C(220, 120, 60),
      Skin = C(156, 74, 42), SkinKeepTexture = false, SkinReflect = 0.08, Flavor = "Still warm from the forge." },
    { Id = "Tidebreaker", Name = "Tidebreaker", Difficulty = "Normal", Source = "Boss", Rarity = "Legendary",
      Glove = C(22, 60, 58), GloveAccent = C(80, 190, 170), Sleeve = C(26, 70, 72), Cuff = C(200, 180, 120),
      Skin = C(40, 130, 110), SkinKeepTexture = false, SkinReflect = 0.18, Flavor = "Jade lacquer, salt-hardened." },
    -- HARD
    { Id = "Nightshade", Name = "Nightshade", Difficulty = "Hard", Source = "Enemy", Rarity = "Legendary",
      Glove = C(24, 22, 30), GloveAccent = C(110, 80, 150), Sleeve = C(30, 28, 38), Cuff = C(18, 16, 22), Stripe = C(120, 90, 170),
      Skin = C(32, 32, 40), SkinKeepTexture = false, SkinReflect = 0.22, Flavor = "Midnight matte. Made to vanish." },
    { Id = "Sovereign", Name = "Sovereign", Difficulty = "Hard", Source = "Boss", Rarity = "Mythic",
      Glove = C(245, 240, 228), GloveAccent = C(212, 175, 55), GloveMetal = true, Sleeve = C(120, 22, 34), Cuff = C(212, 175, 55), Stripe = C(212, 175, 55),
      Skin = C(212, 175, 55), SkinKeepTexture = false, SkinReflect = 0.4, Flavor = "Royal gilding for those who topple titans." },
    -- BRUTAL
    { Id = "Permafrost", Name = "Permafrost", Difficulty = "Brutal", Source = "Enemy", Rarity = "Mythic",
      Glove = C(200, 214, 226), GloveAccent = C(110, 170, 210), Sleeve = C(70, 92, 112), Cuff = C(200, 214, 226), Stripe = C(140, 190, 225),
      Skin = C(172, 208, 232), SkinKeepTexture = false, SkinReflect = 0.25, SkinMaterial = Enum.Material.SmoothPlastic, Flavor = "Rimed in ice that never thaws." },
    { Id = "InfernoTitan", Name = "Inferno Titan", Difficulty = "Brutal", Source = "Boss", Rarity = "Celestial",
      Glove = C(30, 24, 24), GloveAccent = C(255, 110, 30), GloveMetal = true, Sleeve = C(44, 30, 28), Cuff = C(255, 110, 30), Stripe = C(160, 40, 20),
      Skin = C(120, 30, 20), SkinKeepTexture = false, SkinReflect = 0.25, Flavor = "Forged in a dying titan's core." },
    -- NIGHTMARE
    { Id = "Ossuary", Name = "Ossuary", Difficulty = "Nightmare", Source = "Enemy", Rarity = "Celestial",
      Glove = C(226, 218, 196), GloveAccent = C(120, 110, 96), Sleeve = C(58, 52, 48), Cuff = C(226, 218, 196), Stripe = C(160, 30, 36),
      Skin = C(232, 224, 204), SkinKeepTexture = false, SkinReflect = 0.08, Flavor = "Carved from what the nightmare left behind." },
    { Id = "Riftborn", Name = "Riftborn", Difficulty = "Nightmare", Source = "Boss", Rarity = "Transcendent",
      Glove = C(26, 16, 40), GloveAccent = C(170, 90, 255), Sleeve = C(34, 22, 52), Cuff = C(170, 90, 255), Stripe = C(90, 220, 255),
      Skin = C(150, 80, 255), SkinKeepTexture = false, SkinMaterial = Enum.Material.ForceField, Flavor = "A weapon only half in this dimension." },
    -- OBLIVION (were the Endless sets)
    { Id = "Chromatic", Name = "Chromatic", Difficulty = "Oblivion", Source = "Enemy", Rarity = "Transcendent",
      Glove = C(190, 196, 206), GloveAccent = C(240, 244, 250), GloveMetal = true, Sleeve = C(60, 64, 72), Cuff = C(200, 206, 216),
      Skin = C(215, 220, 230), SkinKeepTexture = false, SkinReflect = 0.6, Flavor = "Mirror-polished chrome." },
    { Id = "Ascendant", Name = "Ascendant", Difficulty = "Oblivion", Source = "Boss", Rarity = "Transcendent",
      Glove = C(250, 250, 255), GloveAccent = C(255, 215, 120), Sleeve = C(236, 236, 244), Cuff = C(255, 215, 120), Stripe = C(140, 200, 255),
      Skin = C(255, 255, 255), SkinKeepTexture = false, SkinReflect = 0.2, SkinAnimated = "Rainbow", Flavor = "Endless, and it shows." },
}

-- Drop rolls per kill. Enemy sets: any non-boss kill (<1%). Boss sets: boss kills only.
local CosmeticDropChance = { Enemy = 0.006, Boss = 0.05, SuperBoss = 0.10 }
local CosmeticDropTables: { [string]: { Enemy: { CosmeticRef }, Boss: { CosmeticRef } } } = {}

for _, set in ipairs(CosmeticSets) do
    local sourceText = set.Difficulty .. (set.Source == "Boss" and " bosses" or " enemies")
    local gloveId, sleeveId, skinId = set.Id .. "Gloves", set.Id .. "Sleeves", set.Id .. "Finish"
    Gloves[gloveId] = {
        Id = gloveId, Name = set.Name .. " Gloves", Rarity = set.Rarity,
        Description = set.Flavor .. " (Drops from " .. sourceText .. ".)",
        PrimaryColor = set.Glove, AccentColor = set.GloveAccent,
        Material = set.GloveMetal and Enum.Material.Metal or Enum.Material.SmoothPlastic,
        KnuckleMaterial = Enum.Material.Metal,
        CostGold = 0, CostShards = 0, DropOnly = true, DropSource = sourceText,
    }
    ArmSkins[sleeveId] = {
        Id = sleeveId, Name = set.Name .. " Sleeves", Rarity = set.Rarity,
        Description = set.Flavor .. " (Drops from " .. sourceText .. ".)",
        SleeveColor = set.Sleeve, CuffColor = set.Cuff, StripeColor = set.Stripe,
        Material = Enum.Material.SmoothPlastic, DropOnly = true, DropSource = sourceText,
    }
    WeaponSkins[skinId] = {
        Id = skinId, Name = set.Name .. " Finish", Rarity = set.Rarity,
        Description = set.Flavor .. " (Drops from " .. sourceText .. ".)",
        KeepTexture = set.SkinKeepTexture, Tint = set.Skin, Reflectance = set.SkinReflect,
        Material = set.SkinMaterial, Animated = set.SkinAnimated, DropOnly = true, DropSource = sourceText,
        Accent = set.Stripe or set.GloveAccent, -- (the exotic mark's colour on this finish)
    }
    local tbl = CosmeticDropTables[set.Difficulty] or { Enemy = {}, Boss = {} }
    CosmeticDropTables[set.Difficulty] = tbl
    local list = tbl[set.Source]
    table.insert(list, { Kind = "Glove", Id = gloveId })
    table.insert(list, { Kind = "Sleeve", Id = sleeveId })
    table.insert(list, { Kind = "WeaponSkin", Id = skinId })
end

ItemData.ArmSkins = ArmSkins
ItemData.WeaponSkins = WeaponSkins
ItemData.CosmeticSets = CosmeticSets
ItemData.CosmeticDropChance = CosmeticDropChance
ItemData.CosmeticDropTables = CosmeticDropTables

-- Sorted id list for a cosmetic catalog (by rarity rank, then name) -- used by the Armory tabs.
function ItemData.SortedCosmeticIds(catalog: { [string]: any }): { string }
    local rank = {}
    for i, r in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Transcendent" }) do rank[r] = i end
    local ids = {}
    for id in pairs(catalog) do table.insert(ids, id) end
    table.sort(ids, function(a, b)
        local ra, rb = rank[catalog[a].Rarity] or 0, rank[catalog[b].Rarity] or 0
        if ra ~= rb then return ra < rb end
        return catalog[a].Name < catalog[b].Name
    end)
    return ids
end
-- Season titles (granted by the Season Journey, see Seasons)
Titles["S1Contender"] = {
    Id = "S1Contender", Title = "S1 Contender", Rarity = "Epic", Order = 90,
    Description = "Reached tier 25 of Season 1. +4% Weapon Damage.",
    Requirement = "Season 1 Journey: tier 25", Check = { Kind = "Granted" },
    RewardGold = 0, RewardMats = {}, Color = Color3.fromRGB(190, 110, 255),
    StatBuffs = { ["IncreasedDamage"] = 0.04 },
}
Titles["S1Champion"] = {
    Id = "S1Champion", Title = "S1 Champion", Rarity = "Legendary", Order = 91,
    Description = "Completed the Season 1 Journey. +6% Weapon Damage, +4% Move Speed.",
    Requirement = "Season 1 Journey: tier 50", Check = { Kind = "Granted" },
    RewardGold = 0, RewardMats = {}, Color = Color3.fromRGB(255, 190, 40),
    StatBuffs = { ["IncreasedDamage"] = 0.06, ["MovementSpeed"] = 0.04 },
}
-- BOSS TROPHY TITLES (0.93, owner: "We should also add titles that drop from high tier boss fights and such"): rare titles
-- that DROP (granted on the spot, like loot) -- one per Boss Trial boss from tier VI (Ruin) up, 1% at VI .. 3% at X, and
-- WORLDEATER from dungeon superbosses on Ruin or harder (0.5%). The same rules as every difficulty title: not while
-- outlevelled (ItemData.TitleMaxLevel) and x the tier falloff (ItemData.ExoticFalloff), so an easy tier can't be farmed.
-- Power = TITLE_TIER 12 (the TITLES v4 pass at the end of ItemData turns the StatBuffs keys into numbers).
ItemData.TROPHY_TITLES = {}
ItemData.TROPHY_MIN_TIER = 6
function ItemData.TrophyTitleChance(tier: number): number
    return 0.01 + 0.005 * math.max(0, tier - ItemData.TROPHY_MIN_TIER)
end
ItemData.SUPER_TROPHY_TITLE, ItemData.SUPER_TROPHY_CHANCE, ItemData.SUPER_TROPHY_MIN_DIFF = "Worldeater", 0.005, "Ruin"
Titles["Wingbreaker"] = {
    Id = "Wingbreaker", Title = "Wingbreaker", Rarity = "Sovereign", Order = 29.10,
    Description = "", Requirement = "A rare drop from the Seraph Archon's Boss Trial, tier VI or higher", Check = { Kind = "Granted" },
    RewardGold = 0, RewardMats = {}, Color = Color3.fromRGB(255, 214, 120), Trophy = true,
    StatBuffs = { ["IncreasedDamage"] = 0, ["WeakSpotMultiplier"] = 0 },
}
ItemData.TROPHY_TITLES["Archon"] = "Wingbreaker"
Titles["LastTick"] = {
    Id = "LastTick", Title = "Last Tick", Rarity = "Sovereign", Order = 29.11,
    Description = "", Requirement = "A rare drop from the Chronarch's Boss Trial, tier VI or higher", Check = { Kind = "Granted" },
    RewardGold = 0, RewardMats = {}, Color = Color3.fromRGB(90, 230, 255), Trophy = true,
    StatBuffs = { ["FireRateBonus"] = 0, ["IncreasedDamage"] = 0 },
}
ItemData.TROPHY_TITLES["Chronarch"] = "LastTick"
Titles["Silencebringer"] = {
    Id = "Silencebringer", Title = "Silencebringer", Rarity = "Sovereign", Order = 29.12,
    Description = "", Requirement = "A rare drop from the Echo Warden's Boss Trial, tier VI or higher", Check = { Kind = "Granted" },
    RewardGold = 0, RewardMats = {}, Color = Color3.fromRGB(190, 110, 255), Trophy = true,
    StatBuffs = { ["CritChance"] = 0, ["CritMultiplier"] = 0 },
}
ItemData.TROPHY_TITLES["EchoWarden"] = "Silencebringer"
Titles["Quencher"] = {
    Id = "Quencher", Title = "Quencher", Rarity = "Sovereign", Order = 29.13,
    Description = "", Requirement = "A rare drop from the Forgeheart's Boss Trial, tier VI or higher", Check = { Kind = "Granted" },
    RewardGold = 0, RewardMats = {}, Color = Color3.fromRGB(255, 130, 40), Trophy = true,
    StatBuffs = { ["IncreasedDamage"] = 0, ["DamageReduction"] = 0 },
}
ItemData.TROPHY_TITLES["Forgeheart"] = "Quencher"
Titles["Vaultbreaker"] = {
    Id = "Vaultbreaker", Title = "Vaultbreaker", Rarity = "Sovereign", Order = 29.14,
    Description = "", Requirement = "A rare drop from the Lockwarden's Boss Trial, tier VI or higher", Check = { Kind = "Granted" },
    RewardGold = 0, RewardMats = {}, Color = Color3.fromRGB(120, 200, 255), Trophy = true,
    StatBuffs = { ["WeakSpotMultiplier"] = 0, ["ReloadSpeedBonus"] = 0 },
}
ItemData.TROPHY_TITLES["Lockwarden"] = "Vaultbreaker"
Titles["BroodBane"] = {
    Id = "BroodBane", Title = "Brood Bane", Rarity = "Sovereign", Order = 29.15,
    Description = "", Requirement = "A rare drop from the Broodmother's Boss Trial, tier VI or higher", Check = { Kind = "Granted" },
    RewardGold = 0, RewardMats = {}, Color = Color3.fromRGB(255, 120, 60), Trophy = true,
    StatBuffs = { ["IncreasedDamage"] = 0, ["MaxHPPct"] = 0 },
}
ItemData.TROPHY_TITLES["Broodmother"] = "BroodBane"
Titles["Duelbreaker"] = {
    Id = "Duelbreaker", Title = "Duelbreaker", Rarity = "Sovereign", Order = 29.16,
    Description = "", Requirement = "A rare drop from the Duelist's Boss Trial, tier VI or higher", Check = { Kind = "Granted" },
    RewardGold = 0, RewardMats = {}, Color = Color3.fromRGB(200, 120, 255), Trophy = true,
    StatBuffs = { ["CritMultiplier"] = 0, ["MovementSpeed"] = 0 },
}
ItemData.TROPHY_TITLES["Duelist"] = "Duelbreaker"
Titles["HouseBreaker"] = {
    Id = "HouseBreaker", Title = "House Breaker", Rarity = "Sovereign", Order = 29.17,
    Description = "", Requirement = "A rare drop from the Fortune Engine's Boss Trial, tier VI or higher", Check = { Kind = "Granted" },
    RewardGold = 0, RewardMats = {}, Color = Color3.fromRGB(255, 210, 60), Trophy = true,
    StatBuffs = { ["IncreasedDamage"] = 0, ["LootLuck"] = 0 },
}
ItemData.TROPHY_TITLES["FortuneEngine"] = "HouseBreaker"
Titles["Worldeater"] = {
    Id = "Worldeater", Title = "Worldeater", Rarity = "Sovereign", Order = 29.2,
    Description = "", Requirement = "A rare drop from a biome superboss on Ruin or harder", Check = { Kind = "Granted" },
    RewardGold = 0, RewardMats = {}, Color = Color3.fromRGB(255, 90, 90), Trophy = true,
    StatBuffs = { ["IncreasedDamage"] = 0, ["DamageReduction"] = 0 },
}
-- ===== CHALLENGE TITLES (2026-10-02, owner: "make the titles fit the game's challenging atmosphere -- boss kills, high
-- difficulty clears, headshot streaks"). Tracked in StatsTracking by CombatServer (see TitleProgress kinds). =====
local function T(def) Titles[def.Id] = def end
T({ Id = "SteadyHand", Title = "Steady Hand", Rarity = "Uncommon", Order = 6.5,
    Description = "+4% Weak-Spot Damage, +2% Reload Speed.", Requirement = "Land 10 weak-spot hits in a row (no body shots or misses)",
    Check = { Kind = "HeadshotRun", Need = 10 }, RewardGold = 500, RewardMats = { Scrap = 20 }, Color = Color3.fromRGB(150, 220, 255),
    StatBuffs = { ["WeakSpotMultiplier"] = 0.04, ["ReloadSpeedBonus"] = 0.02 } })
T({ Id = "EliteHunter", Title = "Elite Hunter", Rarity = "Uncommon", Order = 7.5,
    Description = "+3% Damage, +2% Move Speed.", Requirement = "Eliminate 100 elite enemies",
    Check = { Kind = "EliteKills", Need = 100 }, RewardGold = 600, RewardMats = { Alloy = 5 }, Color = Color3.fromRGB(120, 200, 255),
    StatBuffs = { ["IncreasedDamage"] = 0.03, ["MovementSpeed"] = 0.02 } })
T({ Id = "Marksman", Title = "Dead Center", Rarity = "Rare", Order = 9.5,
    Description = "+6% Weak-Spot Damage, +2% Crit Chance.", Requirement = "Land 25 weak-spot hits in a row",
    Check = { Kind = "HeadshotRun", Need = 25 }, RewardGold = 1200, RewardMats = { Alloy = 8 }, Color = Color3.fromRGB(80, 170, 255),
    StatBuffs = { ["WeakSpotMultiplier"] = 0.06, ["CritChance"] = 0.02 } })
T({ Id = "Executioner", Title = "Executioner", Rarity = "Rare", Order = 10.5,
    Description = "+5% Damage, +5% Crit Damage.", Requirement = "Kill a boss on Hard or harder within 30 seconds of your first hit",
    Check = { Kind = "FastBossOn", MinDiff = "Hard", Need = 1 }, RewardGold = 1200, RewardMats = { Alloy = 8 }, Color = Color3.fromRGB(255, 110, 90),
    StatBuffs = { ["IncreasedDamage"] = 0.05, ["CritMultiplier"] = 0.05 } })
T({ Id = "Riftwalker", Title = "Riftwalker", Rarity = "Rare", Order = 11.5,
    Description = "+5% Damage, +3% Move Speed.", Requirement = "Beat a tier 5 rift inside its time limit",
    Check = { Kind = "RiftTier", Need = 5 }, RewardGold = 1500, RewardMats = { Prism = 3 }, Color = Color3.fromRGB(170, 120, 255),
    StatBuffs = { ["IncreasedDamage"] = 0.05, ["MovementSpeed"] = 0.03 } })
T({ Id = "Surgical", Title = "Surgical", Rarity = "Epic", Order = 14.5,
    Description = "+6% Damage, +8% Weak-Spot Damage.", Requirement = "Land 50 weak-spot hits in a row",
    Check = { Kind = "HeadshotRun", Need = 50 }, RewardGold = 2500, RewardMats = { Prism = 4 }, Color = Color3.fromRGB(80, 230, 230),
    StatBuffs = { ["IncreasedDamage"] = 0.06, ["WeakSpotMultiplier"] = 0.08 } })
T({ Id = "Flawless", Title = "Flawless", Rarity = "Epic", Order = 15.5,
    Description = "+6% Damage, +4% Damage Reduction.", Requirement = "Kill a boss without taking any damage during the fight",
    Check = { Kind = "FlawlessBosses", Need = 1 }, RewardGold = 2500, RewardMats = { Prism = 4 }, Color = Color3.fromRGB(240, 240, 255),
    StatBuffs = { ["IncreasedDamage"] = 0.06, ["DamageReduction"] = 0.04 } })
T({ Id = "Deathless", Title = "Deathless", Rarity = "Epic", Order = 16.5,
    Description = "+7% Damage, +12 Max HP.", Requirement = "Finish a Hard run (6 floors) without losing a life",
    Check = { Kind = "DeathlessRun", Diff = "Hard", Need = 1 }, RewardGold = 3000, RewardMats = { Prism = 5 }, Color = Color3.fromRGB(255, 80, 120),
    StatBuffs = { ["IncreasedDamage"] = 0.07, ["MaxHP"] = 12 } })
T({ Id = "ColossusBreaker", Title = "Colossus Breaker", Rarity = "Epic", Order = 16.7,
    Description = "+7% Damage, +10 Max HP.", Requirement = "Defeat 10 biome superbosses",
    Check = { Kind = "SuperBosses", Need = 10 }, RewardGold = 3000, RewardMats = { Prism = 5 }, Color = Color3.fromRGB(255, 150, 60),
    StatBuffs = { ["IncreasedDamage"] = 0.07, ["MaxHP"] = 10 } })
T({ Id = "PerfectAim", Title = "Perfect Aim", Rarity = "Legendary", Order = 18.5,
    Description = "+8% Damage, +10% Weak-Spot Damage.", Requirement = "Land 100 weak-spot hits in a row",
    Check = { Kind = "HeadshotRun", Need = 100 }, RewardGold = 5000, RewardMats = { Prism = 10 }, Color = Color3.fromRGB(255, 225, 90),
    StatBuffs = { ["IncreasedDamage"] = 0.08, ["WeakSpotMultiplier"] = 0.10 } })
T({ Id = "Untouchable", Title = "Untouchable", Rarity = "Legendary", Order = 19.5,
    Description = "+8% Damage, +6% Damage Reduction.", Requirement = "Kill 10 bosses without taking damage during the fight",
    Check = { Kind = "FlawlessBosses", Need = 10 }, RewardGold = 5000, RewardMats = { Prism = 10 }, Color = Color3.fromRGB(200, 240, 255),
    StatBuffs = { ["IncreasedDamage"] = 0.08, ["DamageReduction"] = 0.06 } })
T({ Id = "Ghost", Title = "Ghost", Rarity = "Legendary", Order = 20.5,
    Description = "+8% Damage, +4% Move Speed.", Requirement = "Clear 25 floors on Hard or harder without taking a heavy hit",
    Check = { Kind = "NoHitFloors", MinDiff = "Hard", Need = 25 }, RewardGold = 5000, RewardMats = { Prism = 10 }, Color = Color3.fromRGB(180, 190, 210),
    StatBuffs = { ["IncreasedDamage"] = 0.08, ["MovementSpeed"] = 0.04 } })
T({ Id = "ApexPredator", Title = "Apex Predator", Rarity = "Legendary", Order = 20.7,
    Description = "+9% Damage, +3% Crit Chance.", Requirement = "Defeat 50 bosses on Brutal or harder",
    Check = { Kind = "BossesOn", MinDiff = "Brutal", Need = 50 }, RewardGold = 6000, RewardMats = { Prism = 14 }, Color = Color3.fromRGB(255, 70, 70),
    StatBuffs = { ["IncreasedDamage"] = 0.09, ["CritChance"] = 0.03 } })
T({ Id = "RiftLord", Title = "Rift Lord", Rarity = "Mythic", Order = 23.5,
    Description = "+13% Damage, +5% Fire Rate.", Requirement = "Beat a tier 10 rift inside its time limit",
    Check = { Kind = "RiftTier", Need = 10 }, RewardGold = 10000, RewardMats = { Prism = 21 }, Color = Color3.fromRGB(150, 80, 255),
    StatBuffs = { ["IncreasedDamage"] = 0.13, ["FireRateBonus"] = 0.05 } })
T({ Id = "Immortal", Title = "Immortal", Rarity = "Mythic", Order = 24.5,
    Description = "+15% Damage, +25 Max HP, +5% Damage Reduction.", Requirement = "Finish a Nightmare run (8 floors) without losing a life",
    Check = { Kind = "DeathlessRun", Diff = "Nightmare", Need = 1 }, RewardGold = 15000, RewardMats = { Prism = 28 }, Color = Color3.fromRGB(255, 255, 255),
    StatBuffs = { ["IncreasedDamage"] = 0.15, ["MaxHP"] = 25, ["DamageReduction"] = 0.05 } })
-- level 100 cap (2026-10-04): two more level titles
T({ Id = "Veteran80", Title = "Veteran", Rarity = "Mythic", Order = 24.7,
    Description = "+11% Damage, +4% Damage Reduction.", Requirement = "Reach level 80",
    Check = { Kind = "Level", Need = 80 }, RewardGold = 20000, RewardMats = { Prism = 26 }, Color = Color3.fromRGB(40, 225, 255),
    StatBuffs = { ["IncreasedDamage"] = 0.11, ["DamageReduction"] = 0.04 } })
T({ Id = "Centurion", Title = "Centurion", Rarity = "Transcendent", Order = 24.9,
    Description = "+16% Damage, +4% Crit Chance, +30 Max HP.", Requirement = "Reach level 100",
    Check = { Kind = "Level", Need = 100 }, RewardGold = 50000, RewardMats = { Prism = 52 }, Color = Color3.fromRGB(255, 236, 150),
    StatBuffs = { ["IncreasedDamage"] = 0.16, ["CritChance"] = 0.04, ["MaxHP"] = 30 } })
-- level 400 cap (2026-10-05): a title every 100 levels past 100 (Transcendent: the rarest colour there is)
T({ Id = "Bicentennial", Title = "Twice Forged", Rarity = "Transcendent", Order = 24.92,
    Description = "+18% Damage, +5% Crit Chance, +5% Damage Reduction.", Requirement = "Reach level 200",
    Check = { Kind = "Level", Need = 200 }, RewardGold = 200000, RewardMats = { Prism = 76 }, Color = Color3.fromRGB(255, 210, 120),
    StatBuffs = { ["IncreasedDamage"] = 0.18, ["CritChance"] = 0.05, ["DamageReduction"] = 0.05 } })
T({ Id = "Tricentennial", Title = "Thrice Forged", Rarity = "Transcendent", Order = 24.94,
    Description = "+20% Damage, +6% Crit Chance, +6% Damage Reduction.", Requirement = "Reach level 300",
    Check = { Kind = "Level", Need = 300 }, RewardGold = 1000000, RewardMats = { Prism = 100 }, Color = Color3.fromRGB(255, 180, 90),
    StatBuffs = { ["IncreasedDamage"] = 0.20, ["CritChance"] = 0.06, ["DamageReduction"] = 0.06 } })
T({ Id = "Limitless", Title = "Limitless", Rarity = "Transcendent", Order = 24.96,
    Description = "+22% Damage, +7% Crit Chance, +7% Damage Reduction.", Requirement = "Reach level 400",
    Check = { Kind = "Level", Need = 400 }, RewardGold = 5000000, RewardMats = { Prism = 124 }, Color = Color3.fromRGB(255, 255, 255),
    StatBuffs = { ["IncreasedDamage"] = 0.22, ["CritChance"] = 0.07, ["DamageReduction"] = 0.07 } })
-- premium season track titles: bragging rights only (no stats -- the premium pass never sells power)
T({ Id = "S1Elite", Title = "S1 Elite", Rarity = "Epic", Order = 92,
    Description = "Season 1 premium pass holder. Cosmetic only.", Requirement = "Season 1 Journey premium: tier 1", Check = { Kind = "Granted" },
    RewardGold = 0, RewardMats = {}, Color = Color3.fromRGB(255, 120, 200), StatBuffs = {} })
T({ Id = "S1Apex", Title = "S1 Apex", Rarity = "Mythic", Order = 93,
    Description = "Finished the Season 1 premium track. Cosmetic only.", Requirement = "Season 1 Journey premium: tier 50", Check = { Kind = "Granted" },
    RewardGold = 0, RewardMats = {}, Color = Color3.fromRGB(255, 70, 160), StatBuffs = {} })
-- ===== TITLES v3 (owner 2026-10-05: "titles need to be updated to fit game") =====
-- The whole difficulty ladder (one clear title per tier past Nightmare), the Trial of Ascension, the five weapon classes,
-- and longer kill / boss / superboss goals for a level-400 game. Rarity follows how far up the ladder it is.
do
    local function LastFloor(diff: string): number
        local m = DifficultyModes[diff]
        return (m and m.MaxWaves) or 8
    end
    local LADDER = {
        { "Torment", "TormentClear", "Unbowed", "Legendary", 25.01, 0.10, Color3.fromRGB(255, 120, 60) },
        { "Cataclysm", "CataclysmClear", "Cataclysmic", "Legendary", 25.02, 0.11, Color3.fromRGB(255, 80, 40) },
        { "Oblivion", "OblivionClear", "Oblivion Walker", "Mythic", 25.03, 0.13, Color3.fromRGB(150, 90, 255) },
        { "Ruin", "RuinClear", "Ruinbringer", "Mythic", 25.04, 0.15, Color3.fromRGB(200, 70, 70) },
        { "Dread", "DreadClear", "Dreadnought", "Celestial", 25.05, 0.17, Color3.fromRGB(120, 200, 255) },
        { "Apocalypse", "ApocalypseClear", "Horseman", "Celestial", 25.06, 0.19, Color3.fromRGB(255, 160, 60) },
        { "Annihilation", "AnnihilationClear", "Annihilator", "Celestial", 25.07, 0.21, Color3.fromRGB(255, 70, 140) },
        { "Eternity", "EternityClear", "Eternal", "Transcendent", 25.08, 0.23, Color3.fromRGB(255, 240, 200) },
        { "Singularity", "SingularityClear", "Singularity", "Transcendent", 25.09, 0.25, Color3.fromRGB(255, 255, 255) },
    }
    for i, t in ipairs(LADDER) do
        local diff, id, name, rarity, order, dmg, col = t[1], t[2], t[3], t[4], t[5], t[6], t[7]
        local dr = 0.04 + math.floor(i / 2) * 0.01
        T({ Id = id, Title = name, Rarity = rarity, Order = order,
            Description = string.format("+%d%% Damage, +%d%% Damage Reduction.", math.round(dmg * 100), math.round(dr * 100)),
            Requirement = string.format("Clear %s %s run (floor %d)", string.find(diff, "^[AEIOU]") and "an" or "a", diff, LastFloor(diff)),
            Check = { Kind = "FloorOn", Diff = diff, Floor = LastFloor(diff) },
            RewardGold = 20000 * i * i, RewardMats = { Prism = 10 + 8 * i, ReforgeToken = 2 + i }, Color = col,
            StatBuffs = { ["IncreasedDamage"] = dmg, ["DamageReduction"] = dr } })
    end
end
-- Trial of Ascension tiers (AscTrialBest)
T({ Id = "AscInitiate", Title = "Initiate", Rarity = "Rare", Order = 12.2,
    Description = "+4% Damage, +2% Crit Chance.", Requirement = "Clear the Proving I",
    Check = { Kind = "AscTrial", Need = 1 }, RewardGold = 2000, RewardMats = { Prism = 3 }, Color = Color3.fromRGB(150, 220, 255),
    StatBuffs = { ["IncreasedDamage"] = 0.04, ["CritChance"] = 0.02 } })
T({ Id = "AscAdept", Title = "Adept", Rarity = "Epic", Order = 16.8,
    Description = "+6% Damage, +3% Crit Chance.", Requirement = "Clear the Proving II",
    Check = { Kind = "AscTrial", Need = 2 }, RewardGold = 6000, RewardMats = { Prism = 6 }, Color = Color3.fromRGB(120, 190, 255),
    StatBuffs = { ["IncreasedDamage"] = 0.06, ["CritChance"] = 0.03 } })
T({ Id = "AscExalted", Title = "Exalted", Rarity = "Legendary", Order = 21.2,
    Description = "+9% Damage, +4% Crit Chance.", Requirement = "Clear the Proving III",
    Check = { Kind = "AscTrial", Need = 3 }, RewardGold = 20000, RewardMats = { Prism = 16 }, Color = Color3.fromRGB(255, 220, 120),
    StatBuffs = { ["IncreasedDamage"] = 0.09, ["CritChance"] = 0.04 } })
T({ Id = "AscAscendant", Title = "Ascendant", Rarity = "Mythic", Order = 23.8,
    Description = "+12% Damage, +5% Crit Chance, +4% Damage Reduction.", Requirement = "Clear the Proving IV",
    Check = { Kind = "AscTrial", Need = 4 }, RewardGold = 60000, RewardMats = { Prism = 28 }, Color = Color3.fromRGB(255, 245, 210),
    StatBuffs = { ["IncreasedDamage"] = 0.12, ["CritChance"] = 0.05, ["DamageReduction"] = 0.04 } })
-- MASTERY RANK titles (UPDATE 7 A3): show-off only, NO stats (mastery perks are sideways -- owner-approved list)
T({ Id = "MasteryCadet", Title = "Cadet", Rarity = "Rare", Order = 12.3,
    Description = "A show-off title: no stats.", Requirement = "Reach Marksman Grade 5",
    Check = { Kind = "MasteryRank", Need = 5 }, RewardGold = 2000, Color = Color3.fromRGB(110, 230, 170), StatBuffs = {} })
T({ Id = "MasterySharpshooter", Title = "Sharpshooter", Rarity = "Epic", Order = 16.9,
    Description = "A show-off title: no stats.", Requirement = "Reach Marksman Grade 10",
    Check = { Kind = "MasteryRank", Need = 10 }, RewardGold = 6000, Color = Color3.fromRGB(90, 220, 200), StatBuffs = {} })
T({ Id = "MasteryDeadeye", Title = "Deadeye", Rarity = "Legendary", Order = 21.3,
    Description = "A show-off title: no stats.", Requirement = "Reach Marksman Grade 15",
    Check = { Kind = "MasteryRank", Need = 15 }, RewardGold = 20000, Color = Color3.fromRGB(120, 255, 190), StatBuffs = {} })
T({ Id = "MasteryParagon", Title = "Paragon of Aim", Rarity = "Mythic", Order = 23.9,
    Description = "A show-off title: no stats.", Requirement = "Reach Marksman Grade 20",
    Check = { Kind = "MasteryRank", Need = 20 }, RewardGold = 60000, Color = Color3.fromRGB(200, 255, 230), StatBuffs = {} })
-- SEASON GOALS titles (UPDATE 7 C8): 10 / 20 / 30 of Season 1's goals (Check Granted; show-off, no stats)
T({ Id = "S1Goal10", Title = "S1 Feat Hunter", Rarity = "Rare", Order = 90.1, Description = "A show-off title: no stats.", Requirement = "Finish 10 Season 1 feats",
    Check = { Kind = "Granted" }, RewardGold = 0, Color = Color3.fromRGB(255, 160, 210), StatBuffs = {} })
T({ Id = "S1Goal20", Title = "S1 Trailblazer", Rarity = "Legendary", Order = 90.2, Description = "A show-off title: no stats.", Requirement = "Finish 20 Season 1 feats",
    Check = { Kind = "Granted" }, RewardGold = 0, Color = Color3.fromRGB(255, 140, 200), StatBuffs = {} })
-- FRIEND INVITE titles (2026-10-20, AimRngShared/Referrals): 1 / 3 / 10 invited friends who got going (Check Granted; no stats)
T({ Id = "Recruiter", Title = "Recruiter", Rarity = "Rare", Order = 90.4, Description = "A show-off title: no stats.", Requirement = "Invite a friend who reaches level 20",
    Check = { Kind = "Granted" }, RewardGold = 0, Color = Color3.fromRGB(110, 220, 150), StatBuffs = {} })
T({ Id = "SquadLeader", Title = "Squad Leader", Rarity = "Legendary", Order = 90.5, Description = "A show-off title: no stats.", Requirement = "Invite 3 friends who reach level 20",
    Check = { Kind = "Granted" }, RewardGold = 0, Color = Color3.fromRGB(90, 230, 170), StatBuffs = {} })
T({ Id = "Commander", Title = "Commander", Rarity = "Mythic", Order = 90.6, Description = "A show-off title: no stats.", Requirement = "Invite 10 friends who reach level 20",
    Check = { Kind = "Granted" }, RewardGold = 0, Color = Color3.fromRGB(70, 240, 190), StatBuffs = {} })
T({ Id = "S1Goal30", Title = "S1 Completionist", Rarity = "Mythic", Order = 90.3, Description = "A show-off title: no stats.", Requirement = "Finish all 30 Season 1 feats",
    Check = { Kind = "Granted" }, RewardGold = 0, Color = Color3.fromRGB(255, 110, 190), StatBuffs = {} })
-- CITY DISTRICT titles (UPDATE 7 B5): bought with standing at ranks 3 / 5 (Check Granted; show-off, no stats)
for _, t in ipairs({ { "Lantern", "Lantern Row", Color3.fromRGB(255, 196, 90) }, { "Wire", "Wire Market", Color3.fromRGB(90, 220, 255) }, { "Iron", "Iron Stair", Color3.fromRGB(235, 110, 80) } }) do
    T({ Id = t[1] .. "Friend", Title = "Friend of " .. t[2], Rarity = "Epic", Order = 17.2,
        Description = "A show-off title: no stats.", Requirement = "Rank 3 with " .. t[2] .. ", bought at its stall",
        Check = { Kind = "Granted" }, RewardGold = 0, Color = t[3], StatBuffs = {} })
    T({ Id = t[1] .. "Legend", Title = t[2] .. " Legend", Rarity = "Mythic", Order = 23.92,
        Description = "A show-off title: no stats.", Requirement = "Rank 5 with " .. t[2] .. ", bought at its stall",
        Check = { Kind = "Granted" }, RewardGold = 0, Color = t[3], StatBuffs = {} })
end
-- APEX HUNT titles (UPDATE 7 C1): the first Apex / Uber Apex kill grants them (Check Granted; show-off, no stats)
T({ Id = "ApexHunter", Title = "Summit Breaker", Rarity = "Legendary", Order = 21.4,
    Description = "A show-off title: no stats.", Requirement = "Conquer the Summit",
    Check = { Kind = "Granted" }, RewardGold = 0, Color = Color3.fromRGB(255, 120, 160), StatBuffs = {} })
T({ Id = "UberApexHunter", Title = "Summit Unbound Breaker", Rarity = "Mythic", Order = 23.95,
    Description = "A show-off title: no stats.", Requirement = "Conquer the Summit Unbound",
    Check = { Kind = "Granted" }, RewardGold = 0, Color = Color3.fromRGB(255, 80, 140), StatBuffs = {} })
-- the five weapon classes: kills with that class's guns (StatsTracking.KillsByGroup, any class you play)
do
    local CLASS = {
        { "Assault", "ClassVanguard", "Frontliner", Color3.fromRGB(255, 170, 80), "an assault rifle or LMG" },
        { "Close", "ClassGunslinger", "Quickdraw", Color3.fromRGB(255, 110, 150), "an SMG or pistol" },
        { "Precision", "ClassMarksman", "Sharpshooter", Color3.fromRGB(120, 210, 255), "a DMR or sniper" },
        { "Shotgun", "ClassBreacher", "Doorkicker", Color3.fromRGB(255, 120, 70), "a shotgun" },
        { "Beam", "ClassArcwright", "Arc Master", Color3.fromRGB(190, 120, 255), "a beam gun" },
    }
    for i, c in ipairs(CLASS) do
        T({ Id = c[2], Title = c[3], Rarity = "Epic", Order = 14.6 + i * 0.01,
            Description = "+6% Damage, +3% Reload Speed.", Requirement = "Eliminate 25,000 enemies with " .. c[5],
            Check = { Kind = "GroupKills", Group = c[1], Need = 25000 }, RewardGold = 5000, RewardMats = { Prism = 5 }, Color = c[4],
            StatBuffs = { ["IncreasedDamage"] = 0.06, ["ReloadSpeedBonus"] = 0.03 } })
    end
end
-- longer goals for a level-400 game
T({ Id = "ExtinctionEvent", Title = "Extinction Event", Rarity = "Mythic", Order = 23.9,
    Description = "+12% Damage, +20 Max HP.", Requirement = "Eliminate 500,000 enemies",
    Check = { Kind = "Kills", Need = 500000 }, RewardGold = 100000, RewardMats = { Prism = 35 }, Color = Color3.fromRGB(255, 90, 60),
    StatBuffs = { ["IncreasedDamage"] = 0.12, ["MaxHP"] = 20 } })
T({ Id = "GiantsBane", Title = "Bane of Giants", Rarity = "Mythic", Order = 23.95,
    Description = "+12% Damage, +6% Weak-Spot Damage.", Requirement = "Defeat 1,000 bosses",
    Check = { Kind = "Bosses", Need = 1000 }, RewardGold = 100000, RewardMats = { Prism = 35 }, Color = Color3.fromRGB(255, 200, 90),
    StatBuffs = { ["IncreasedDamage"] = 0.12, ["WeakSpotMultiplier"] = 0.06 } })
T({ Id = "Worldbreaker", Title = "Worldbreaker", Rarity = "Celestial", Order = 24.8,
    Description = "+15% Damage, +5% Damage Reduction.", Requirement = "Defeat 100 biome superbosses",
    Check = { Kind = "SuperBosses", Need = 100 }, RewardGold = 250000, RewardMats = { Prism = 52 }, Color = Color3.fromRGB(150, 230, 255),
    StatBuffs = { ["IncreasedDamage"] = 0.15, ["DamageReduction"] = 0.05 } })
ItemData.Titles = Titles

-- Title progress from a player state (server PlayerState or the client's synced copy).
-- Returns done, current, needed (current/needed are for progress bars; 1/1 or 0/1 for yes/no checks).
-- (FUTURE-PROOF 2026-10-25: built from DifficultyOrder -- a hand copy missing a new tier counted its clears as Easy ones)
local TITLE_DIFF_ORDER = table.clone(ItemData.DifficultyOrder)
table.insert(TITLE_DIFF_ORDER, "Endless") -- (Endless: legacy records)
function ItemData.TitleProgress(titleId: string, state: any): (boolean, number, number)
    local t = Titles[titleId]
    if not t or not state then return false, 0, 1 end
    local c = t.Check or { Kind = "Default" }
    local st = state.StatsTracking or {}
    local function Count(cur: number, need: number): (boolean, number, number)
        return cur >= need, math.min(cur, need), need
    end
    local k = c.Kind
    if k == "Default" then return true, 1, 1
    elseif k == "Granted" then
        -- season / event titles: only granted by the server (Seasons), never claimed from progress
        local has = table.find(state.UnlockedTitles or {}, titleId) ~= nil
        return has, has and 1 or 0, 1
    elseif k == "BossTrial" then
        local bt = type(state.BossTrials) == "table" and state.BossTrials[c.Boss]
        return Count(type(bt) == "table" and tonumber(bt.Best) or 0, c.Tier)
    elseif k == "Kills" then return Count(st.TotalKills or 0, c.Need)
    elseif k == "Bosses" then return Count(st.BossKills or 0, c.Need)
    elseif k == "Headshots" then return Count(st.SniperHeadshots or 0, c.Need)
    elseif k == "WeakSpots" then return Count(math.max(st.WeakSpotHits or 0, st.SniperHeadshots or 0), c.Need)
    elseif k == "MeleeKills" then return Count(st.MeleeKills or 0, c.Need)
    elseif k == "Explosive" then return Count(math.floor(st.ExplosiveDamageDealt or 0), c.Need)
    elseif k == "Pierced" then return Count(st.PierceHits or 0, c.Need)
    elseif k == "HeadshotRun" then return Count(st.BestHeadshotRun or 0, c.Need)
    elseif k == "SuperBosses" then return Count(st.SuperBossKills or 0, c.Need)
    elseif k == "FlawlessBosses" then return Count(st.FlawlessBosses or 0, c.Need)
    elseif k == "EliteKills" then return Count(st.EliteKills or 0, c.Need)
    elseif k == "RiftTier" then return Count(state.RiftBest or 0, c.Need)
    elseif k == "AscTrial" then return Count(tonumber(state.AscTrialBest) or 0, c.Need)
    elseif k == "MasteryRank" then return Count(tonumber(state.MasteryRank) or 0, c.Need) -- (UPDATE 7)
    elseif k == "GroupKills" then return Count((type(st.KillsByGroup) == "table" and st.KillsByGroup[c.Group]) or 0, c.Need)
    elseif k == "BossesOn" or k == "FastBossOn" or k == "NoHitFloors" or k == "DeathlessRun" then
        -- per-difficulty counters: that difficulty or any harder one counts
        local field = (k == "BossesOn" and "BossKillsByDiff") or (k == "FastBossOn" and "FastBossesByDiff")
            or (k == "NoHitFloors" and "NoHitFloorsByDiff") or "DeathlessRuns"
        local tbl = type(st[field]) == "table" and st[field] or {}
        local from = table.find(TITLE_DIFF_ORDER, c.MinDiff or c.Diff) or 1
        local n = 0
        for i = from, #TITLE_DIFF_ORDER do n += tbl[TITLE_DIFF_ORDER[i]] or 0 end
        return Count(n, c.Need)
    elseif k == "BestStreak" then return Count(math.max(st.BestStreak or 0, state.Streak or 0), c.Need)
    elseif k == "Level" then return Count(state.Level or 1, c.Need)
    elseif k == "TreeNodes" then return Count(#(state.AllocatedNodes or {}), c.Need)
    elseif k == "Discovered" then
        local n = 0
        for _ in pairs(st.DiscoveredWeapons or {}) do n += 1 end
        return Count(n, c.Need)
    elseif k == "FloorOn" then
        -- the same floor (or deeper) on a harder difficulty counts too
        local best = 0
        local from = table.find(TITLE_DIFF_ORDER, c.Diff) or 1
        for i = from, #TITLE_DIFF_ORDER do
            best = math.max(best, (st.TitleFloors or {})[TITLE_DIFF_ORDER[i]] or 0) -- (0.93: only clears at the title skill floor)
        end
        return Count(best, c.Floor)
    elseif k == "SkillClears" then
        local n = 0
        local minDiff = c.MinDiff and table.find(TITLE_DIFF_ORDER, c.MinDiff) or 1
        for key, cnt in pairs(st.SkillClears or {}) do
            local skill, diff = string.match(key, "^(%d+)|(%a+)$")
            local di = diff and table.find(TITLE_DIFF_ORDER, diff) or 0
            if skill and tonumber(skill) >= c.MinSkill and di >= minDiff then n += cnt end
        end
        return Count(n, c.Need)
    elseif k == "EquipWeapon" then
        local w = state.EquippedWeapon
        local ok = w ~= nil and (ItemData.RarityRank[w.Rarity] or 0) >= (ItemData.RarityRank[c.Rarity] or 99)
            and (w.UpgradeLevel or 0) >= (c.MinUpgrade or 0)
        return ok, ok and 1 or 0, 1
    elseif k == "GearAtLeast" then
        local n = 0
        for _, g in pairs(state.EquippedGear or {}) do
            if (ItemData.RarityRank[g.Rarity] or 0) >= (ItemData.RarityRank[c.Rarity] or 99) then n += 1 end
        end
        return Count(n, c.Count)
    end
    return false, 0, 1
end

-- Floor-clear bookkeeping for titles (solo and party runs both call this).
-- TITLE SKILL FLOOR (0.93, owner: "titles need to ... be harder, as of now its like too easy to get higher titles, simply
-- beating a hard difficulty on easy would allow you to get one of the best titles"): every difficulty-based title counts
-- only what you did at this BOT SKILL or higher on that difficulty (clears, boss kills, fast / flawless-floor / deathless
-- runs). Standard (4) up to Brutal, Veteran (6) Nightmare..Oblivion, Elite (7) Ruin..Apocalypse, Pro (8) above.
-- Progress made before 0.93 doesn't count (no skill was recorded with it); titles already claimed are kept.
ItemData.TITLE_SKILL_BANDS = { { "Brutal", 4 }, { "Oblivion", 6 }, { "Apocalypse", 7 }, { "Singularity", 8 } }
function ItemData.TitleMinSkill(difficulty: string?): number
    local rank = ItemData.DifficultyRank and ItemData.DifficultyRank[difficulty or ""] or 1
    for _, b in ipairs(ItemData.TITLE_SKILL_BANDS) do
        if rank <= (ItemData.DifficultyRank[b[1]] or 99) then return b[2] end
    end
    return 8
end
-- TITLE LEVEL CAP (0.93, owner: "anyone will eventually be able to do ruin on bot difficulty 10 and just one shot the
-- enemies to get a really good title, I dont want that"): an outlevelled difficulty doesn't count for its titles either --
-- your level must be at most the difficulty's top monster level + TITLE_LEVEL_MARGIN (Ruin 100-130 -> level 140). A harder
-- difficulty still counts for the easier titles ("that difficulty or harder").
ItemData.TITLE_LEVEL_MARGIN = 10
function ItemData.TitleMaxLevel(difficulty: string?): number
    local ml = ItemData.MONSTER_LEVEL and ItemData.MONSTER_LEVEL[difficulty or ""]
    return (ml and ml[2] or 400) + ItemData.TITLE_LEVEL_MARGIN
end
function ItemData.TitleSkillOk(difficulty: string?, botSkill: number?, level: number?): boolean
    if level and level > ItemData.TitleMaxLevel(difficulty) then return false end
    return math.floor(tonumber(botSkill) or 4) >= ItemData.TitleMinSkill(difficulty)
end
-- returns true when this clear COMPLETED the difficulty for the first time (passive points v5: TREE_CLEAR_POINTS)
function ItemData.RecordFloorClear(st: any, difficulty: string, floor: number, botSkill: number?, noHit: boolean?, level: number?): boolean
    local wasCleared = ItemData.DifficultyCleared(st, difficulty)
    st.HighestFloorCleared = math.max(st.HighestFloorCleared or 0, floor)
    st.FloorsCleared = (tonumber(st.FloorsCleared) or 0) + 1 -- (Update 5 lifetime stats)
    local titleOk = ItemData.TitleSkillOk(difficulty, botSkill, level)
    if titleOk then -- (0.93: the floors that count for clear titles -- only at the title skill floor or higher)
        st.TitleFloors = type(st.TitleFloors) == "table" and st.TitleFloors or {}
        st.TitleFloors[difficulty] = math.max(st.TitleFloors[difficulty] or 0, floor)
    end
    if noHit and titleOk then -- (Ghost title: floors cleared without taking damage)
        st.NoHitFloorsByDiff = type(st.NoHitFloorsByDiff) == "table" and st.NoHitFloorsByDiff or {}
        st.NoHitFloorsByDiff[difficulty] = (st.NoHitFloorsByDiff[difficulty] or 0) + 1
    end
    st.FloorsByDifficulty = st.FloorsByDifficulty or {}
    st.FloorsByDifficulty[difficulty] = math.max(st.FloorsByDifficulty[difficulty] or 0, floor)
    st.SkillClears = st.SkillClears or {}
    local key = tostring(math.clamp(math.floor(botSkill or 4), 1, 10)) .. "|" .. difficulty
    st.SkillClears[key] = (st.SkillClears[key] or 0) + 1
    return (not wasCleared) and ItemData.DifficultyCleared(st, difficulty)
end
ItemData.DifficultyModes = DifficultyModes
-- DIFFICULTY UNLOCKS (owner 2026-10-04: "it should be harder to progress to those levels"): a difficulty opens once
-- you've CLEARED the whole run on the one below it (StatsTracking.FloorsByDifficulty >= its last floor) and reached its
-- level. Older characters keep what they beat (the runs only got shorter). Returns ok, reason.
ItemData.DifficultyMinLevel = { Easy = 1, Normal = 1, Hard = 8, Brutal = 18, Nightmare = 30, Torment = 45, Cataclysm = 65, Oblivion = 80,
    Ruin = 98, Dread = 125, Apocalypse = 158, Annihilation = 198, Eternity = 243, Singularity = 303 }
-- CONTENT CAP (LAUNCH CAP, owner: "Dont have them show that, just remove the levels for now"): a difficulty whose min level is
-- above CONTENT_CAP is CLOSED -- not listed anywhere (Dungeons window, map bands, trial tiers, titles), refused by the server
-- (DifficultyUnlock), its data kept here so raising this one number brings it back. 200: Easy .. Annihilation open.
ItemData.CONTENT_CAP = 200
function ItemData.DifficultyOpen(diff: string?): boolean
    local d = ItemData.ParseRunKey and ItemData.ParseRunKey(diff or "") or diff
    return (ItemData.DifficultyMinLevel[d or ""] or 1) <= ItemData.CONTENT_CAP
end
-- the open difficulties in ladder order
function ItemData.OpenDifficulties(): { string }
    local out = {}
    for _, d in ipairs(ItemData.DifficultyOrder) do if ItemData.DifficultyOpen(d) then table.insert(out, d) end end
    return out
end
-- ==================== CONTENT LEVEL (owner 2026-10-05: "if level 100 and 400 feel the same, what would even be the incentive
-- to grind?" -> enemies scale with the CONTENT, not with you) ====================
-- Every difficulty has a fixed MONSTER LEVEL range: floor 1 = lo, the last floor = hi (Endless: +2 a floor past it). Enemies,
-- bosses, loot item level and gold come from it; your own level only decides how strong you are against it. So levelling
-- makes you outgrow a tier, and the next tier is what you grind next.
ItemData.MONSTER_LEVEL = {
    Easy = { 1, 5 }, Normal = { 5, 12 }, Hard = { 10, 20 }, Brutal = { 20, 32 }, Nightmare = { 32, 48 }, Torment = { 47, 66 },
    Cataclysm = { 66, 84 }, Oblivion = { 82, 102 }, Ruin = { 100, 130 }, Dread = { 128, 165 }, Apocalypse = { 160, 205 },
    Annihilation = { 200, 250 }, Eternity = { 245, 310 }, Singularity = { 305, 400 }, Endless = { 32, 48 },
}
function ItemData.MonsterLevel(diff: string?, endless: boolean?, floor: number?): number
    local r = ItemData.MONSTER_LEVEL[diff or "Easy"] or ItemData.MONSTER_LEVEL.Easy
    local mode = DifficultyModes[diff or "Easy"]
    local n = math.max(1, (mode and mode.MaxWaves) or 5)
    local f = math.max(1, math.floor(floor or 1))
    if endless and f > n then return math.floor(r[2] + (f - n) * 2) end
    local t = (n <= 1) and 1 or math.clamp((f - 1) / (n - 1), 0, 1)
    return math.floor(r[1] + (r[2] - r[1]) * t + 0.5)
end
-- EXPECTED PLAYER POWER (how much stronger a level-L character is than the bare level curve), MEASURED with DevCmd treesim
-- 2026-10-05 (best greedy tree at TreePointsAt(L), an even attribute spread, a plain gun; DevCmd `["powercurve"]` reruns
-- it): DPS index 1 / 5.4 / 41 / 186 / 257 / 690 / 2017 / 5943 at L1 / 20 / 50 / 80 / 100 / 150 / 200 / 300 (L400 extrapolated:
-- the probe ran out of steps at 645 of 800 points); toughness (effective HP) index ~1 / 1.4 / 2 / 2.7 / 3 / 5 / 7 / 14 / 24.
-- Gear (rarity + affixes) adds ~1.2-1.5x on top (measured: flat with level). Real players aren't optimal (paths, misses,
-- unfinished gear), so enemies follow a SHARE of it: health x PowerIndex(ML) ^ POWER_SHARE, damage x ToughIndex(ML) ^
-- TOUGH_SHARE. On-level content then stays a fight at every tier, and outlevelling a tier still crushes it.
-- RE-MEASURED after the STAT CEILINGS (StatCalculator.CEILINGS, 2026-10-05; powercurve, Demolisher + Gunslinger averaged):
-- power 1 / 2.1 / 5.7 / 10.6 / 16.5 / 48 / 158 / 970 / ~3500 at L1 / 20 / 50 / 80 / 100 / 150 / 200 / 300 / 400 (was 257 at
-- L100 -- crit / damage / fire rate maxed early), toughness of a damage build 1 / 1.85 / 2.45 / 3.2 / 3.7 / 6 / 7 / 10 / 14
-- (a Bulwark tank sits far higher on purpose). Re-run DevCmd powercurve after any tree / ceiling / stat change.
-- THREE LAYERS re-anchor (0.45, 2026-10-05): gear now adds on top of the character's ceilings, so the anchors are the
-- GEARED curve (DevCmd powercurve <class> <levels> GEAR: level-typical weapon + full Rare/Epic/Legendary set), relative to a
-- geared level 1 and rounded a little under (a typical kit is below a full set of one rarity). Power 1.45 / 3.5 / 9.4 / 24 /
-- 35 / 117 / 371 / 1.76K / 6.6K measured (geometric mean of Demolitionist + Gunslinger), toughness 2 / 4 / 5.9 / 9.4 / 12 /
-- 14.5 / 18 / 33 / 40. Ungeared you fall behind from about Brutal on: gear is the chase again.
-- WEAPON CLASSES re-anchor (0.46): power = the geometric mean of the five classes, each with its own gun + gear (powercurve
-- <class> .. GEAR: 3.5 / 8.1 / 27 / 72 / 189 / 1.15K / 2.9K at L20 / 50 / 100 / 150 / 200 / 300 / 400), rounded ~10% under.
-- Toughness: the new tree buys far more real effective health (HP / (1 - DR): x1.85 at L100, x4.3 at L400, DR reaches its
-- 75% cap) -- enemies follow HALF of that rise (the square root of the ratio), since treesim's greedy builds take more
-- defence than a typical player.
-- (0.51 RARITY LADDER: re-anchored by the measured change of a geared build when its gear follows the new windows -- the
-- commonest rarity of the tier it farms -- DevCmd powercurve VAN+GEAR before / after: power x0.82 @20, x1.03 @50, x1.35
-- @100, x1.69 @200, x2.59 @400; tough x0.67, x0.96, x1.72, x2.10, x2.37; 80 / 150 / 300 log-interpolated)
-- (0.63 re-measure after the PLAYSTYLE KEYSTONES moved out + the 0.62 passives: powercurve <class> 20,100,200,400 GEAR,
-- geometric mean of the five: power 2.56 / 33.9 / 356 / 7.1K (L200 +24% over the table, the rest within 7%); toughness
-- 3.2 / 41 / 262 / 1.19K -- the table stays above the square root of that (the half-the-rise rule). treesim can't value the
-- playstyle keystones (combat mechanics, ~+30% DPS with three, reachable from ~level 60), so the power anchors from L100 up
-- take them in: 100 x1.1, 150 x1.15, 200 -> the measured 356 x0.9 x1.12, 300 / 400 x1.25. Enemy health follows x^0.75.)
-- (0.99n RARITY LADDER v3: the gear model is now the rarity players realistically wear (ItemData.TypicalGearRank: 1 1 2 3 4 4
-- 5 5 5 6 6 6 7 7 by tier) instead of the tier's top - 3 (up to 12 at the top). powercurve <class> .. GEAR new vs old
-- (workspace DevGearModel "old"), Vanguard + Gunslinger geometric mean: power x1.13 / 1 / 1 / 0.61 / 0.54 / 0.52 / 0.65 / 0.39
-- at L20 / 50 / 80 / 100 / 150 / 200 / 300 / 400, toughness x1.03 / 1 / 1 / 0.80 / 0.93 / 0.41 / 0.63 / 0.48. Smoothed and
-- applied from L100 up (power x0.65 / 0.55 / 0.52 / 0.55 / 0.40, tough x0.82 / 0.75 / 0.60 / 0.55 / 0.48); L1-80 left as they
-- were (the small rise there would only make the early game harder). Was: power 35.6 / 113 / 360 / 2700 / 8350, tough 13.6 /
-- 19.6 / 29.4 / 60.2 / 92.4.)
-- (0.99n L100+ PLAY CHECK, 2026-10-18: DevCmd treesim .. APPLY = a Vanguard with its greedy tree + the level-typical AK + gear
-- on real floors, enemy MaxHealth read live. Basic-bot kill time (35% weak spots, every shot hits), corrected to monsters AT
-- your level (LevelCurve 1.06 per level of gap): L110 2.7 s, L140 2.8, L220 4.2, L320 7.3, L400 5.1 -- the top climbed past
-- the ~3 s of the low tiers (it did before the ladder too; the old gear model hid it). Enemy health follows PowerIndex^0.75,
-- so the anchors from 150 up were cut by (kill time / 3)^(1/0.75): 150 x0.85, 200 x0.68, 300 x0.33, 400 x0.49. Was
-- 62.2 / 187 / 1485 / 3340.)
-- (2026-10-20 SCALING CHECK, owner: "Check the scaling" -> "just do what you recommended"; ALL FIVE classes, not Vanguard
-- alone): treesim APPLY at L on the tier holding L + DevCmd stats DPS (35% weak spots), kill time of a 100-HP basic bot AT L =
-- 100 x HealthMult(tier) x EnemyHpIndex(L) x LevelCurve(L) / DPS (live bots are useless here: base Hp runs 40..1000 by type).
-- Five-class geometric mean / the tier's HealthMult (the intended rise per tier): 2.25 / 2.37 / 2.10 / 2.13 / 2.26 / 1.74 / 3.02 at
-- L50 / 80 / 100 / 150 / 200 / 300 / 400 (Arcwright counted at its new boost). Target = the L50-200 mean 2.2: 300 x1.49
-- (enemies too weak there), 400 x0.78 (too tough); the rest left (within noise). Was 300 = 490, 400 = 1640. The 0.99n cut
-- above corrected below-level monsters by 1.06 a level, but health also climbs the index (~1.07 a level up there).
-- (2026-10-21 CLASS BALANCE re-anchor: measured offline with tools/sim/classbal -- every point spent and the best of 9 routes
-- per class; the single greedy above got trapped and from L325 left 100-200 points unspent, so it UNDER-rated L300+ builds.
-- After the class tables (StatCalculator.CLASS_BOOST_BY_LEVEL) the five-class geomean t / HealthMult was 2.07 / 2.36 / 2.07 /
-- 1.83 / 1.94 at L50 / 80 / 100 / 150 / 200 (mean 2.05 = the target, left as they were) but 1.48 / 1.54 / 1.46 at 250 / 300 /
-- 400 (enemies too weak there; 250 was low with the old method too: 1.81) -> a new 250 point 470, 300 730 -> 1070, 400
-- 1275 -> 2020 (enemy health x1.38 / x1.33 / x1.41 there). 175 also read low (1.52; 1.82 old method) -- left, one level.)
-- (PASSIVE TREE v5, 2026-10-21: re-anchored after the tree reset -- fewer points (800 -> 428 at 400) and nodes no longer stacked
-- 3-6x past their ceilings, so a built character's power grows less steeply; the five-class kill time of a 100-HP basic bot
-- (tools/sim/classbal, class boosts re-fitted) was 1.81 / 1.90 / 2.02 / 2.01 / 2.27 / 2.78 / 4.14 / 5.66 / 6.33 / 6.29 at
-- 20 / 50 / 80 / 100 / 150 / 200 / 250 / 300 / 350 / 400 -> every anchor moved to 2.05: x (2.05 / t)^(4/3). Was { 20 2.62, 50 7.52,
-- 80 18.3, 100 23.1, 150 53, 200 127, 250 470, 300 1070, 400 2020 }.)
-- (2026-10-22 EXPERTISE + mechanic notables: a full build kills faster -- t 1.96 / 2.00 / 1.77 / 1.73 / 1.67 / 1.67 / 1.56 / 1.48 /
-- 1.58 at 20 / 50 / 100 / 150 / 200 / 250 / 300 / 350 / 400 (80 interpolated 1.86), classes re-fitted -> x (2.05 / t)^(4/3) again.
-- Was { 20 3.09, 50 8.32, 80 18.66, 100 23.71, 150 46.26, 200 84.61, 250 184, 300 276, 350 327, 400 453 }. TOUGH unchanged: the
-- builds' HP / (1 - DR) moved -12..+10% with no trend, and the expertise "less damage taken" effects aren't in that number.)
-- (UPDATE 8 PHASE 6 RE-FIT, DEFENCE builder, fixed-seed harness on 5aa109e: the AVERAGE build = level-typical gear v3 in 8 slots +
-- the level-typical gun with its own mods + a random 3-link of shot mods at 75% of the level cap + the greedy tree with
-- attributes; "today" = the same harness on the pre-Update-8 code (418b7a3). Kill time of a 100-HP basic bot (t, burst): today
-- 1.83 / 1.71 / 2.18 / 2.39 / 3.03 / 2.68 / 2.90, the new average 0.90 / 0.99 / 0.79 / 0.73 / 1.07 / 1.26 / 1.13 at 5 / 10 / 20 / 50 /
-- 100 / 150 / 200 -> each anchor x (t_today / t_avg)^(4/3) (20-200 smoothed over neighbours; 250+ x the L200 ratio; L1 stays the
-- base) so an average build kills at today's pace. Boss health is built from this index (BossHp), so BOSS_PACE fight times hold.
-- Was { 20 3.28, 50 8.6, 80 21.26, 100 28.84, 150 58.01, 200 111.2, 250 241.8, 300 397.3, 350 504.9, 400 641.1 }.)
-- (PHASE 6 RE-CHECK on ae1632e, same harness: OFFENSE's class pass (link falloff, region scales, BEAM tune, Marksman class edge)
-- sped the average build to x0.91 / 0.89 / 0.95 / 0.83 / 0.84 / 0.97 / 0.81 of today's kill time at 5 / 10 / 20 / 50 / 100 / 150 /
-- 200 -> each anchor x (t_today / t_avg)^(4/3), unsmoothed this time (it also takes out the last fit's L50 / L150 residuals; 80
-- from its neighbours, 250+ x the L200 ratio); re-run: the average is x1.00 of today at every level. Was { 5 3.32, 10 3.62,
-- 20 13.41, 50 37.7, 80 85.9, 100 110.4, 150 186, 200 368, 250 800.1, 300 1314.7, 350 1670.8, 400 2121.5 }.)
ItemData.POWER_ANCHORS = { { 1, 1 }, { 5, 3.78 }, { 10, 4.24 }, { 20, 14.28 }, { 50, 48.17 }, { 80, 108.5 }, { 100, 138.5 }, { 150, 193.5 }, { 200, 490.5 }, { 250, 1066 }, { 300, 1752 }, { 350, 2227 }, { 400, 2827 } }
-- (PASSIVE TREE v5: a built character's EHP (HP / (1 - DR), five-class geomean, tools/sim/classbal) fell to x1.00 / 0.78 / 0.64 /
-- 0.64 / 0.61 / 0.54 / 0.58 / 0.63 / 0.54 / 0.43 of the old tree's at 20 / 50 / 80 / 100 / 150 / 200 / 250 / 300 / 350 / 400 -> each
-- anchor x (smoothed ratio)^(1 / TOUGH_SHARE) so enemy hits take the same share of your health. Was { 20 1.41, 50 3.36, 80 8.26,
-- 100 11.2, 150 14.7, 200 17.6, 300 33.1, 400 44.4 }.)
-- (UPDATE 8 PHASE 6 RE-FIT: the average build's toughness -- life + 0.9 x Ward over a Kinetic 0.5 / elemental 0.4 / Void 0.1 mix
-- at the tier's resist penalty, 60% of hits dodgeable by Agility -- vs today's on the same formula: x1.47 / 1.25 / 1.50 / 1.16 /
-- 1.09 / 1.63 / 1.23 at 5 / 10 / 20 / 50 / 100 / 150 / 200 -> anchor x ratio^(1 / TOUGH_SHARE) (smoothed) so enemy hits take today's
-- share of your health. Was { 20 1.41, 50 2.5, 80 5.03, 100 6.31, 150 7.73, 200 8.64, 300 17.14, 400 17.79 }.)
ItemData.TOUGH_ANCHORS = { { 1, 1 }, { 5, 1.55 }, { 10, 1.62 }, { 20, 2.17 }, { 50, 3.21 }, { 80, 6.48 }, { 100, 8.15 }, { 150, 11.51 }, { 200, 12.23 }, { 300, 24.26 }, { 400, 25.18 } }
-- (0.75 chosen 2026-10-05 from kill times of a 100-HP basic bot at each tier's middle monster level: a DECENT build (80% of
-- the optimal's log-power) 0.6 s on Easy -> 1.3 s Oblivion -> 1.9 s Singularity, an OPTIMAL one 0.6 s -> 0.3 s; at 0.6 the
-- optimal build fell to 0.08 s on Singularity -- outscaling the top content it was meant to struggle with)
ItemData.POWER_SHARE, ItemData.TOUGH_SHARE = 0.75, 0.8
local function LogInterp(anchors: { { number } }, level: number): number
    local l = math.max(1, level)
    if l >= anchors[#anchors][1] then
        local a, b = anchors[#anchors - 1], anchors[#anchors]
        return b[2] * (b[2] / a[2]) ^ ((l - b[1]) / (b[1] - a[1])) -- (keeps the last slope past the table)
    end
    for i = 1, #anchors - 1 do
        local a, b = anchors[i], anchors[i + 1]
        if l <= b[1] then
            local t = (l - a[1]) / (b[1] - a[1])
            return math.exp(math.log(a[2]) + (math.log(b[2]) - math.log(a[2])) * t)
        end
    end
    return anchors[#anchors][2]
end
function ItemData.PowerIndex(level: number): number return LogInterp(ItemData.POWER_ANCHORS, level) end
function ItemData.ToughIndex(level: number): number return LogInterp(ItemData.TOUGH_ANCHORS, level) end
function ItemData.EnemyHpIndex(ml: number): number return ItemData.PowerIndex(ml) ^ ItemData.POWER_SHARE end
function ItemData.EnemyDmgIndex(ml: number): number return ItemData.ToughIndex(ml) ^ ItemData.TOUGH_SHARE end
-- XP vs the gap between you and the content: farming far below your level pays little, punching up pays a bit more
function ItemData.LevelGapXp(playerLevel: number, ml: number): number
    local d = (playerLevel or 1) - (ml or 1)
    -- (0.60b, owner: "the xp gain doesnt really make any sense"): the first floors of a run sit 10-17 levels under you
    -- and paid 28-46%; now the cut starts 12 levels down, 4% a level, never under 25% (was 5 / 6% / 10%)
    if d > 12 then return math.max(0.25, 1 - 0.04 * (d - 12)) end
    if d < 0 then return 1 + math.min(0.5, -d * 0.02) end
    return 1
end
-- ==================== LEVELING PACE (owner 2026-10-05: "Leveling feels a little backwards ... hard to get to the level to
-- unlock the higher xp difficulty, and then those will give a ton more ... a similar scheme to path of exile: about 5-10
-- hours of playtime to hit level 50, 20-30 hours for 75, level 100 about 70 hours" for an average player) ====================
-- Enemy XP used to be (difficulty XP 50 .. 920) x (1 + 5% per player level): an 18x difficulty spread on top of a 6x
-- level ramp. Now it is worked BACKWARDS from a time budget: LEVEL_MINUTES = minutes an average player spends on each
-- level (anchors, linear between; sums: L50 7.5 h, L75 24.5 h, L100 67 h), XP_UNITS_PER_MIN = the XP units an average
-- player earns a minute (a plain bot = 1 unit, elites 3 / 5, bosses more), and the difficulty pays DIFF_XP on top --
-- assuming you play the highest difficulty your level opens, so a lower one is slower and a faster player levels faster.
-- (level 400: the time per level keeps rising past 100 -- 150 min at L100 .. 210 at L400; sums L200 ~330 h, L300 ~630 h,
-- L400 ~970 h for an average player on the best difficulty they've opened. A long-term goal: tune here.)
-- (0.64, owner: "Level 100 should definitely not be 70 hours anymore, closer to 15-20 and then max level can be about
-- 200 hours"): sums now L50 3.2 h, L75 8.4 h, L100 17.8 h, L200 69.5 h, L300 129 h, L400 197 h.
-- (2026-10-13, owner: "Its also too easy to currently level, make it a bit slower" / "the main leveling was a bit quick
-- now too"; retune same day: "L50 about 4 h, L100 about 20 h, L400 about 200 h"): anchors x1.20 to L50, then eased off
-- -> sums L50 4.0 h, L75 9.8 h, L100 20.0 h, L200 73 h, L300 132 h, L400 199 h (was 3.2 / 8.4 / 17.8 / 69.5 / 129 / 197;
-- the first pass 4.0 / 11.1 / 24.0 / 91 / 165 / 249). XP needed per level is unchanged; every
-- enemy pays proportionally less (KillXpUnit divides by these minutes). Power at a level is unchanged.
-- (UPDATE 8 LEVEL PACE, owner: "80-100 hours for max level", cap 200): levels 1-20 unchanged (the first hour unlocks as before),
-- then stretched -> sums L20 0.7 h, L30 1.4 h, L50 4.2 h, L75 10.9 h, L100 22.1 h, L150 52.7 h, L200 88.9 h for an average player on the
-- best difficulty they've opened, packs included (PACK_XP_PACE). tools/sim/xp_pace.py prints the table. (was L50 4.2 / L100 20.5 /
-- L200 73 h before packs, ~66 h with them)
ItemData.LEVEL_MINUTES = { { 1, 0.96 }, { 10, 2.04 }, { 20, 3.36 }, { 35, 6.6 }, { 50, 12.8 }, { 62, 15.2 }, { 75, 20.8 }, { 88, 27.6 }, { 100, 33.5 }, { 150, 40 }, { 200, 47 }, { 300, 54 }, { 400, 60 } }
-- PACKS (UPDATE 8): a pack floor pays its bots + ~4.5 fodder at PacksPilot.XP 0.15 each (x1.675 units) and takes ~1.5x as long
-- (raritysim's 16 floors an hour vs 24) -> ~1.1x the XP a minute of the RUN_PACE model. KillXp divides by this (an ESTIMATE:
-- re-measure from real run summaries).
ItemData.PACK_XP_PACE = 1.1
-- (PACK SIZE BY DIFFICULTY, linked builder 2026-10-22) packs grow with the tier (PacksPilot.PackRange: 4-5 fodder a leader on Easy ..
-- 8-10 on Annihilation): more fodder in the same packs = more XP a minute (no extra waves / walks, only kills in the clump).
-- KillXp divides by this too, so the XP a minute stays on the RUN_PACE model: tools/sim/pack_size.py (an ESTIMATE: 1.5 s per
-- extra fodder; 1.0 s -> up to 1.21, 2.5 s -> up to 1.08 at Annihilation).
ItemData.PACK_XP_TIER = { Easy = 1.0, Normal = 1.02, Hard = 1.03, Brutal = 1.05, Nightmare = 1.07, Torment = 1.08, Cataclysm = 1.1,
    Oblivion = 1.11, Ruin = 1.12, Dread = 1.14, Apocalypse = 1.15, Annihilation = 1.17, Eternity = 1.18, Singularity = 1.19, Endless = 1.07 }
-- (LINKED ROOMS are the normal game, linked builder 2026-10-22) a run of linked floors (2 linked floors + floor 5 + the boss) pays
-- more XP a minute than 5 single-room floors + the boss (fewer chests / portals / loads for the same fights): KillXp divides by
-- this too, so the XP a minute stays on the RUN_PACE model. tools/sim/linked_pace.py (a Studio probe of real rosters + the
-- xp_pace time model; half rush / half full clear) -- an ESTIMATE: re-measure from real run summaries.
ItemData.LINKED_XP_TIER = { Easy = 1.16, Normal = 1.17, Hard = 1.19, Brutal = 1.20, Nightmare = 1.16, Torment = 1.12, Cataclysm = 1.14,
    Oblivion = 1.16, Ruin = 1.19, Dread = 1.16, Apocalypse = 1.14, Annihilation = 1.12, Eternity = 1.12, Singularity = 1.12, Endless = 1.16 }
-- (RUN PACE XP, 2026-10-24; owner: "You can trim the xp to probably like 1.2x instead of 1.5") the run-pace cut (2 rooms from Hard,
-- the flatter in-run health climb, docs/RUN_TIMING_2026-10-24.md) made NORMAL runs 1.3-2.4x faster for about the same XP a run, so
-- XP a minute rose ~1.4-2.6x. DungeonGenerator.EnemyXp divides every enemy / boss XP by this on normal runs only
-- (ItemData.RunLengthXp: not maps, trials, The Proving, the Daily, the Gauntlet Run, Endless -- they didn't get faster), so XP a
-- minute lands ~1.2x the pre-change pace. Factor = (XP a minute after / before) / 1.2. MEASURED: Ruin (3 real runs; at 1.5 they gave
-- 1.06-1.23x, avg 1.16 -> 1.45), Dread (floors 1 / 5 / 6, two samples 1.36 / 2.2 -> 1.5), Torment (2 real runs = ~160K XP a minute
-- before the cut vs ~67K estimated before the run-pace change, design 54K at L53 -> 2.0 = ~80K, 1.2x old / 1.5x design),
-- Apocalypse (floor 5 2.07x -> 1.8). Never below design pace (MinutesForLevel): Cataclysm 1.95 = ~74K vs 68K design at L71. ESTIMATES from run times (no before XP): Normal 1.0 (health ramp
-- only), Hard 1.1, Brutal 1.15, Nightmare 1.3, Cataclysm 1.95 / Oblivion 1.7 (between Torment and Ruin), Annihilation 1.5 (level
-- cap: only L198-200). Gold and loot are not touched.
ItemData.RUN_LENGTH_XP = { Hard = 1.1, Brutal = 1.15, Nightmare = 1.3, Torment = 2.0, Cataclysm = 1.95, Oblivion = 1.7, Ruin = 1.45,
    Dread = 1.5, Apocalypse = 1.8, Annihilation = 1.5, Eternity = 1.5, Singularity = 1.5 }
-- MAP XP (2026-10-24, owner: "Map xp should give 2-3x that's fine"): the mode check measured map XP a minute at ~2x a normal
-- run's at T1 (Ruin) and ~4x at T7 (Apocalypse): maps skip RUN_LENGTH_XP and add Rifts.RewardBonus (+60% T1 .. +150% T10), so the
-- gap grows with the tier's run trim. Every kill on a map floor (guardian too; DungeonRuns sets config.MapTier) divides by this.
-- Measured 2026-10-25 in Play: XP a kill (DungeonGenerator.EnemyXp x the map's RewardBonus, map vs normal floor) was T1 2.3x, T7 4.0x,
-- T10 3.8x -> now T1 2.3x (T3 2.6x), T4 2.6x (T6 2.9x), T7 2.6x (T9 2.9x), T10 2.3x (T12 2.5x). XP a minute (DevCmd killall XP a floor /
-- the timed floor length, 1-3 samples, noisy): T1 2.5x, T4 2.4x, T7 ~2.6x, T10 ~3.2x (its map floors run faster). Gold / loot untouched.
ItemData.MAP_XP_TIER = { Ruin = 1.0, Dread = 1.1, Apocalypse = 1.5, Annihilation = 1.6, Eternity = 1.6, Singularity = 1.6 }
function ItemData.RunLengthXp(cfg: any): number
    if type(cfg) ~= "table" then return 1 end
    if cfg.MapTier then return ItemData.MAP_XP_TIER[cfg.Difficulty or ""] or 1 end
    if cfg.SpecialRun or cfg.Rift or cfg.MonsterLevel or cfg.BossTrial or cfg.AscTrial or cfg.MapGuardian then return 1 end
    -- (Endless: its floors 1 .. the tier's run length got the run's health flattening too (DungeonGenerator.RampHp) -> same XP trim
    -- there; deeper floors climb as before and keep their XP)
    if cfg.Endless then
        local m = DifficultyModes[cfg.Difficulty or ""]
        if (cfg.FloorNumber or 1) > ((m and m.MaxWaves) or 6) then return 1 end
    end
    return ItemData.RUN_LENGTH_XP[cfg.Difficulty or ""] or 1
end
ItemData.XP_UNITS_PER_MIN = 4.4 -- (0.60b: 4.5 -> 3.5 = +29% XP; 0.89, owner: leveling at 1-1.3x the target pace -- measured ~1.2-1.7x at 3.5, so 4.4 = -20% XP per kill. The 2026-10-22 kill pace + 6-floor runs are in RUN_PACE, not here)
-- RUN PACE (2026-10-23, owner: "fix the xp rate if need be"): kills a minute on each tier vs the 4.4 era. The kill pace (bots
-- ~1/3 the health, bosses ~half) and 6-floor runs (were 5 / 6 / 8 / 10, with 90 s superbosses on the long ones) sped the top
-- tiers up far more than Easy (the flat 5.5 left L100+ ~1.3x too fast and the first levels ~10% slow). KillXp divides by
-- it, so XP a minute on every tier stays where 4.4 measured. MODEL (tools/sim/xp_pace.py: per-floor bots / elites / bosses,
-- the documented kill seconds, a 12 min 5-floor Normal run with ~30% of it shooting) -- re-measure from real run summaries.
ItemData.RUN_PACE = { Easy = 1.11, Normal = 1.13, Hard = 1.22, Brutal = 1.19, Nightmare = 1.32, Torment = 1.35, Cataclysm = 1.45,
    Oblivion = 1.48, Ruin = 1.52, Dread = 1.55, Apocalypse = 1.59, Annihilation = 1.63, Eternity = 1.69, Singularity = 1.75, Endless = 1.35 }
ItemData.DIFF_XP = { Easy = 1.0, Normal = 1.15, Hard = 1.3, Brutal = 1.45, Nightmare = 1.6, Torment = 1.8, Cataclysm = 2.0, Oblivion = 2.2,
    Ruin = 2.4, Dread = 2.6, Apocalypse = 2.8, Annihilation = 3.0, Eternity = 3.25, Singularity = 3.5, Endless = 1.6 }
-- XP from level -> level + 1 (moved here from CombatServer so the enemy XP can be built from it)
function ItemData.XpToNext(level: number): number
    local late = ItemData.LATE_LEVEL or 60
    local raw
    if level >= late then
        raw = math.round(213 * late ^ 1.1 * 1.078 ^ late * 0.75 * 1.02 ^ (level - late))
    else
        raw = math.round(213 * level ^ 1.1 * 1.078 ^ level)
    end
    return math.round(raw * 0.8)
end
function ItemData.MinutesForLevel(level: number): number
    local a = ItemData.LEVEL_MINUTES
    level = math.clamp(level, a[1][1], a[#a][1])
    for i = 1, #a - 1 do
        local p, q = a[i], a[i + 1]
        if level <= q[1] then return p[2] + (q[2] - p[2]) * (level - p[1]) / (q[1] - p[1]) end
    end
    return a[#a][2]
end
-- the XP multiplier of the best difficulty a player of this level can be on (by DifficultyMinLevel)
function ItemData.ExpectedDiffXp(level: number): number
    local best = 1
    for d, lv in pairs(ItemData.DifficultyMinLevel) do
        -- (0.60b: a tier counts as "expected" 8 levels after it opens -- at 65 every Torment kill paid 12% less the
        -- moment Cataclysm unlocked, even though it also needs a Torment clear)
        if level >= lv + 8 then best = math.max(best, ItemData.DIFF_XP[d] or 1) end
    end
    return best
end
-- XP of ONE unit for a player of this level (on the expected difficulty)
function ItemData.KillXpUnit(level: number): number
    level = math.max(1, math.floor(level))
    return ItemData.XpToNext(level) / (ItemData.MinutesForLevel(level) * ItemData.XP_UNITS_PER_MIN * ItemData.ExpectedDiffXp(level))
end
-- an enemy's XP reward: units (bot 1, x3 / x5 elites, bosses more) x the difficulty's DIFF_XP / RUN_PACE x a little per floor
function ItemData.KillXp(level: number, difficulty: string?, floor: number?, units: number): number
    local d = difficulty or "Easy"
    return math.max(1, math.round(ItemData.KillXpUnit(level) * (ItemData.DIFF_XP[d] or 1) / ((ItemData.RUN_PACE[d] or 1) * (ItemData.PACK_XP_PACE or 1) * ((ItemData.PACK_XP_TIER and ItemData.PACK_XP_TIER[d]) or 1) * ((ItemData.LINKED_XP_TIER and ItemData.LINKED_XP_TIER[d]) or 1)) * (1 + (floor or 1) * 0.02) * units))
end
function ItemData.DifficultyUnlock(state: any, diff: string): (boolean, string?)
    local order = ItemData.DifficultyOrder
    local idx = table.find(order, diff)
    if not idx then return false, "Unknown difficulty." end
    if not ItemData.DifficultyOpen(diff) then return false, "Unknown difficulty." end -- (LAUNCH CAP: closed = not there)
    local lvl = type(state) == "table" and state.Level or 1
    local need = ItemData.DifficultyMinLevel[diff] or 1
    if lvl < need then return false, string.format("%s needs level %d.", diff, need) end
    if idx == 1 then return true end
    local prev = order[idx - 1]
    local st = type(state) == "table" and state.StatsTracking or nil
    local best = st and type(st.FloorsByDifficulty) == "table" and st.FloorsByDifficulty[prev] or 0
    local m = DifficultyModes[prev]
    if best < (m and m.MaxWaves or 5) then return false, string.format("Clear a full %s run to unlock %s.", prev, diff) end
    return true
end

-- ==================== EXOTIC DROPS (0.86) ====================
-- (owner: "Exotics should be farmable from bosses, at a super super low drop chance (getting slightly higher at higher
-- difficulties). Would it be a good idea to only make the drops farmable on the tier you are currently on?" -> the soft
-- falloff): the chance is full on your HIGHEST UNLOCKED difficulty and the one below it, then x EXOTIC_FALLOFF per tier
-- further down -- speed-farming an easy tier for exotics is never worth it, helping a lower friend still isn't zero.
ItemData.EXOTIC_FALLOFF = 0.25
-- per dungeon boss kill, before the difficulty factor (1 + rank / 14: Easy x1.07 .. Singularity x2)
ItemData.EXOTIC_BOSS_CHANCE = { Mini = 0.0005, Major = 0.0012, Super = 0.003 }
function ItemData.TopUnlockedRank(state: any): number
    local top = 1
    for i, d in ipairs(ItemData.DifficultyOrder) do
        if ItemData.DifficultyUnlock(state, d) then top = i else break end
    end
    return top
end
-- the falloff for exotics rolled on difficulty `diff` (1 on your top tier and the one below)
function ItemData.ExoticFalloff(state: any, diff: string?): number
    local rank = ItemData.DifficultyRank[diff or ""] or 1
    local gap = ItemData.TopUnlockedRank(state) - rank
    if gap <= 1 then return 1 end
    return ItemData.EXOTIC_FALLOFF ^ (gap - 1)
end
-- a dungeon boss's exotic chance: kind "Mini" | "Major" | "Super"
function ItemData.BossExoticChance(state: any, kind: string, diff: string?): number
    local rank = ItemData.DifficultyRank[diff or ""] or 1
    return (ItemData.EXOTIC_BOSS_CHANCE[kind] or 0) * (1 + rank / 14) * ItemData.ExoticFalloff(state, diff)
end
ItemData.Rarities = Rarities
-- RARITY SYMBOLS (QOL2 I2 2026-10-28: rarity was colour only): one shape per rarity, shown before an item's name on bag / stash
-- rows, ground loot tags, the bag toast and the HUD gun name (Settings > Interface > Rarity Symbols turns the row / tag ones off).
-- (0.62: only shapes the UI fonts actually have; the old names stay for gem grades)
ItemData.RARITY_GLYPHS = { Zenith = "❖", Relic = "★", Common = "●", Uncommon = "■", Rare = "◆", Epic = "▲", Legendary = "★", Mythic = "◈", Celestial = "❖", Transcendent = "✚",
    Astral = "◆◆", Empyrean = "▲▲", Primordial = "◈◈", Sovereign = "★★", Eclipse = "◐", Genesis = "❖❖", Infinite = "∞" }
function ItemData.RarityGlyph(rarity: string?): string
    return ItemData.RARITY_GLYPHS[rarity or ""] or "●"
end
-- an item's symbol (a relic = ★ whatever its stored rarity)
function ItemData.ItemGlyph(item: any): string
    if type(item) ~= "table" then return "●" end
    if item.Exotic then return (ItemData.ZenithOf(item) and ItemData.RARITY_GLYPHS.Zenith) or ItemData.RARITY_GLYPHS.Relic end
    return ItemData.RarityGlyph(item.Rarity)
end
-- the name with its symbol first (a relic's own "◆ " marker gives way to its ★)
function ItemData.SymbolName(item: any): string
    if type(item) ~= "table" then return "" end
    return ItemData.ItemGlyph(item) .. " " .. tostring(item.Name or "")
end
-- TOP-RARITY TEXT (2026-10-04): Celestial names fade cyan -> white, Transcendent names run a prismatic gradient.
-- StyleRarityText(label, rarity) adds / removes that UIGradient (the label's TextColor3 goes white under it).
ItemData.PRISM = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 170)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 225, 120)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 255, 190)), ColorSequenceKeypoint.new(0.75, Color3.fromRGB(120, 200, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(215, 140, 255)),
})
ItemData.CELESTIAL_SHEEN = ColorSequence.new(Color3.fromRGB(40, 225, 255), Color3.fromRGB(235, 252, 255))
local function Seq2(a: Color3, b: Color3) return ColorSequence.new(a, b) end
ItemData.RARITY_GRADIENT = {
    Celestial = ItemData.CELESTIAL_SHEEN, Transcendent = ItemData.PRISM,
    Astral = Seq2(Color3.fromRGB(80, 90, 255), Color3.fromRGB(200, 130, 255)),
    Empyrean = Seq2(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 220, 140)),
    Primordial = Seq2(Color3.fromRGB(90, 230, 120), Color3.fromRGB(255, 200, 60)),
    Sovereign = Seq2(Color3.fromRGB(255, 50, 80), Color3.fromRGB(255, 215, 90)),
    Eclipse = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 40)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 30, 170)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 40)) }),
    Genesis = Seq2(Color3.fromRGB(255, 120, 200), Color3.fromRGB(110, 235, 255)),
    Infinite = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 220, 60)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(80, 255, 140)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 200, 255)),
        ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 90, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)) }),
}
function ItemData.StyleRarityText(label: Instance, rarity: string?)
    local g = label:FindFirstChild("RarityGradient")
    local seq = rarity and ItemData.RARITY_GRADIENT[rarity] or nil
    if not seq then
        if g then g:Destroy() end
        return
    end
    if not g then
        g = Instance.new("UIGradient")
        g.Name = "RarityGradient"
        g.Parent = label
    end
    g.Color = seq;
    (label :: any).TextColor3 = Color3.new(1, 1, 1)
    -- (0.68, owner: "Weapons should have the animated colors ... only apply to transcendent +, dont make the effects overly
    -- flashy"): Transcendent and up drift their colours slowly side to side (one shared loop, client only)
    local CS = game:GetService("CollectionService")
    if (ItemData.LegacyRank[rarity or ""] or 0) >= 8 then -- (RARITY v4: the old Transcendent+ GRADES -- titles / cosmetics / gems)
        CS:AddTag(g, "AimRarityDrift")
        ItemData.StartRarityDrift()
    else
        CS:RemoveTag(g, "AimRarityDrift")
        g.Offset = Vector2.zero
    end
end
function ItemData.StartRarityDrift()
    if ItemData._driftOn or not game:GetService("RunService"):IsClient() then return end
    ItemData._driftOn = true
    local CS = game:GetService("CollectionService")
    local last = 0
    game:GetService("RunService").RenderStepped:Connect(function()
        local now = os.clock()
        if now - last < 1 / 30 then return end -- (30 Hz is plenty for a slow drift)
        last = now
        for _, g in ipairs(CS:GetTagged("AimRarityDrift")) do
            local lbl = g.Parent
            if lbl and lbl:IsA("GuiObject") and lbl.Visible then
                g.Offset = Vector2.new(0.3 * math.sin(now * 0.9 + (lbl.AbsolutePosition.Y * 0.01)), 0)
            end
        end
    end)
    -- (0.69, owner: "the color animation didnt apply in all menus (i.e upgrades)"): EVERY menu, without touching each one --
    -- twice a second, any text drawn in a Transcendent-or-higher rarity colour gets that rarity's gradient (marked
    -- RarityAuto); if the code later recolours it (a different item), it's re-checked and the gradient goes if needed
    local byColor = {}
    for r, rank in pairs(ItemData.LegacyRank) do -- (RARITY v4: the old grades only; no item rarity has a gradient)
        local c = ItemData.RarityColors[r]
        if c and rank >= 8 and ItemData.RARITY_GRADIENT[r] then
            byColor[math.floor(c.R * 255 + 0.5) * 65536 + math.floor(c.G * 255 + 0.5) * 256 + math.floor(c.B * 255 + 0.5)] = r
        end
    end
    local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    task.spawn(function()
        while true do
            task.wait(0.5)
            for _, d in ipairs(pg:GetDescendants()) do
                -- (attr NoRarityDrift: text that only SHARES a rarity's colour -- the Vanguard class orange = Eclipse -- keeps it)
                if (d:IsA("TextLabel") or d:IsA("TextButton")) and not d:GetAttribute("NoRarityDrift") then
                    local c = d.TextColor3
                    local auto = d:GetAttribute("RarityAuto")
                    local white = c.R > 0.999 and c.G > 0.999 and c.B > 0.999
                    if not white then
                        local r = byColor[math.floor(c.R * 255 + 0.5) * 65536 + math.floor(c.G * 255 + 0.5) * 256 + math.floor(c.B * 255 + 0.5)]
                        if r then
                            ItemData.StyleRarityText(d, r)
                            d:SetAttribute("RarityAuto", r)
                        elseif auto then
                            d:SetAttribute("RarityAuto", nil)
                            local g = d:FindFirstChild("RarityGradient")
                            if g then g:Destroy() end
                        end
                    end
                end
            end
        end
    end)
end
ItemData.RarityColors = RarityColors
ItemData.RarityPowerMult = RarityPowerMult
ItemData.BaseSellPrices = BaseSellPrices
ItemData.GearAffixPools = GearAffixPools
ItemData.UniqueTraitsCatalog = UniqueTraitsCatalog
ItemData.TraitById = {}
for _, t in ipairs(UniqueTraitsCatalog) do ItemData.TraitById[t.Id] = t end
-- TRAIT RARITY (0.51, owner: "The traits should also have rarities, but this will be seperately rolled within the weapon
-- and NOT scale"): whether a weapon HAS a trait climbs with its rarity (TRAIT_CHANCE); WHICH trait is a separate roll with
-- fixed odds per trait tier (the same on a Rare as on an Infinite). Stronger traits sit in the rarer tiers.
ItemData.TRAIT_TIERS = { { Id = "Common", Weight = 55 }, { Id = "Rare", Weight = 28 }, { Id = "Epic", Weight = 13 }, { Id = "Legendary", Weight = 4 } }
ItemData.TRAIT_TIER_COLORS = { Common = Color3.fromRGB(200, 200, 200), Rare = Color3.fromRGB(60, 150, 255), Epic = Color3.fromRGB(170, 60, 230),
    Legendary = Color3.fromRGB(255, 150, 30) }
function ItemData.RollTrait(excludeId: string?): any
    local total = 0
    for _, t in ipairs(ItemData.TRAIT_TIERS) do total += t.Weight end
    for _ = 1, 20 do
        local roll, acc, tier = math.random() * total, 0, "Common"
        for _, t in ipairs(ItemData.TRAIT_TIERS) do
            acc += t.Weight
            if roll <= acc then tier = t.Id break end
        end
        local pool = {}
        for _, tr in ipairs(UniqueTraitsCatalog) do if tr.Tier == tier and tr.Id ~= excludeId then table.insert(pool, tr) end end
        if #pool > 0 then return table.clone(pool[math.random(1, #pool)]) end
    end
    return table.clone(UniqueTraitsCatalog[1])
end
-- chance that a dropped weapon carries a unique trait, by rarity (very rare by design)
-- (0.51: climbs steadily through all 15 rarities; the TRAIT's own rarity is rolled separately: ItemData.TRAIT_TIERS)
ItemData.TRAIT_CHANCE = { Common = 0, Uncommon = 0.002, Rare = 0.01, Epic = 0.015, Legendary = 0.04, Mythic = 0.10, Celestial = 0.18,
    Transcendent = 0.28, Astral = 0.38, Empyrean = 0.48, Primordial = 0.58, Sovereign = 0.68, Eclipse = 0.78, Genesis = 0.88, Infinite = 1,
    Relic = 0.10 } -- (RARITY v4: Rare 0.006 -> 0.01, Relic = Mythic)

-- Highest rarity rank a difficulty can drop: Mythic (6) from Brutal, Celestial (7) from Torment, Transcendent (8)
-- only on Oblivion. Everything else stops at Legendary (5). (owner 2026-10-04: Endless isn't the endgame any more --
-- an Endless run drops what its difficulty drops)
-- RARITY LADDER v2 (0.51): difficulty number d (Easy 1 ... Singularity 14) drops up to rarity rank d + 1 -- every tier
-- adds one new top rarity. A run key ("Endless:Hard") counts as its tier.
-- RARITY v4 (UPDATE 8): Common / Uncommon / Rare drop everywhere; Mythic from MYTHIC_FROM (Torment) up -- its odds then rise
-- with the tier (RARITY_AREA). Relics never come from this roll (ItemData.Exotics: bosses, trials, maps, as before).
ItemData.MYTHIC_FROM = "Torment"
function ItemData.MaxRarityRank(difficulty: string?): number
    local tier = ItemData.ParseRunKey(difficulty)
    local d = tier and table.find(ItemData.DifficultyOrder, tier)
    if not d then return 3 end
    return (d >= (table.find(ItemData.DifficultyOrder, ItemData.MYTHIC_FROM) or 6)) and ItemData.RarityRank.Mythic or ItemData.RarityRank.Rare
end
-- the OLD ladder's cap (rank d + 1 of LEGACY_RARITIES): only the skill-tree gems still use it (GemData)
function ItemData.LegacyMaxRarityRank(difficulty: string?): number
    local tier = ItemData.ParseRunKey(difficulty)
    local d = tier and table.find(ItemData.DifficultyOrder, tier)
    return d and math.min(#ItemData.LEGACY_RARITIES, d + 1) or 2
end
-- does the item carry a line at the TOP tier its item level allows (AffixTierCap)? -- the "best for this difficulty" signal
-- now that the top tiers are gated by item level (drop sounds, the drop feed, Loot Lens words "toptier")
function ItemData.HasTopTierLine(item: any): boolean
    if type(item) ~= "table" or item.Exotic then return false end
    local cap = ItemData.AffixTierCap(item.Rarity, item.ItemLevel or 1)
    for _, l in ipairs(ItemData.LinesOf(item, item.Slot ~= nil)) do
        if not l.Negative and not l.Exotic and (tonumber(l.Tier) or 0) >= cap then return true end
    end
    return false
end
-- DROP SOUNDS (0.72, owner: "should be relative ... if you get a legendary on a low difficulty, play the most dopamine
-- inducing noise. Noises should only play for the 2 rarest respective drops of that difficulty, one being less exciting
-- and the rarest being the most"): 2 = the difficulty's top rarity or above (or an exotic), 1 = one below it, 0 = silent.
-- Commons never sound (Easy's top is Uncommon, so "one below" would be every Common).
-- (0.99n RARITY LADDER v3: the tier's top rarities are now very rare everywhere, so the sounds follow the ODDS of the drop on
-- that difficulty: 1 in EXCITE_ONE_IN[1]+ = the nice sound, 1 in EXCITE_ONE_IN[2]+ = the jackpot + the global drop feed)
-- (UPDATE 8 RARITY v4, vault 11b: "the two best-for-this-difficulty levels are judged by item level + tiers, not colour"):
--   where Mythics drop (Torment+): 2 = a Mythic (or a Relic), 1 = a Rare with a top-tier line (HasTopTierLine);
--   below that:                     2 = a Rare with a top-tier line, 1 = any other Rare.
-- Anything above the difficulty's own top (a Mythic on Easy) and every Relic = 2. Common / Uncommon never sound.
ItemData.EXCITE_ONE_IN = { 60, 600 } -- (unused since RARITY v4; kept for old readers)
function ItemData.DropExcitement(item: any, difficulty: string?): number
    if type(item) ~= "table" then return 0 end
    if item.Kind == "Gem" then return ((ItemData.LegacyRank[item.Rarity or ""] or 1) >= 5) and 1 or 0 end -- (gems: the old ladder, Legendary+ = nice)
    if item.Exotic or item.Rarity == "Relic" then return 2 end
    local r = ItemData.RarityRank[item.Rarity or ""] or 1
    if r < ItemData.RarityRank.Rare then return 0 end
    local top = ItemData.MaxRarityRank(difficulty)
    if r > top then return 2 end
    local tt = ItemData.HasTopTierLine(item)
    if top >= ItemData.RarityRank.Mythic then
        if r >= ItemData.RarityRank.Mythic then return 2 end
        return tt and 1 or 0
    end
    return tt and 2 or 1
end
-- the top rarity a player of this level is "on" (for rolls outside a dungeon: the daily forge roll): the hardest tier
-- whose monster levels start at or below the level
function ItemData.MaxRarityForLevel(level: number?): number
    return ItemData.MaxRarityRank(ItemData.TierForLevel(level)) -- (RARITY v4: that tier's cap)
end
-- the hardest difficulty whose monster levels start at or below the level (RARITY v4: the area for rolls outside a run)
function ItemData.TierForLevel(level: number?): string
    local best = 1
    for i, id in ipairs(ItemData.DifficultyOrder) do
        local band = ItemData.MONSTER_LEVEL[id]
        if band and (level or 1) >= band[1] then best = i end
    end
    return ItemData.DifficultyOrder[best]
end


-- ==================== [RPG SCALING: ONE LEVEL CURVE FOR EVERYTHING] ====================
-- Weapon damage, gear flat stats, player health, enemy health and enemy damage all grow along the
-- SAME exponential curve (Borderlands-style: a steady % per level, never linear), so an on-level
-- weapon always kills an on-level enemy in about the same time -- what changes your power relative
-- to the world is rarity, affixes, upgrades, attributes and skills, not raw level.
--   level:   1     5     10    20    30    40    50     60     80     100 (cap)
--   curve:   1.0   1.46  2.36  6.12  15.9  41.1  106.7  276.5  887    2843
-- A gun 5 levels behind you does ~38% less damage (1.1^5 = 1.61x) -- the Borderlands pull to keep
-- finding new guns. Level cap: ItemData.MAX_LEVEL.
-- LEVEL 100 (owner 2026-10-04: "level increase"): past 60 the curve grows 6% a level (LEVEL_GROWTH_LATE), not 10%,
-- so numbers stay readable and a 5-level-old gun is ~25% behind instead of ~38%.
ItemData.LEVEL_GROWTH = 1.10
ItemData.LEVEL_GROWTH_LATE = 1.06
ItemData.LATE_LEVEL = 60
-- LEVEL 400 (owner 2026-10-05: "continue to expand the level cap and skill tree ... If the level cap is something like 300
-- or 400, and the xp scaling increasing, player retention will likely heavily increase. This can also be infinite scaled"
-- + "we dont need to cap out the scaling"): the curve keeps its 6% a level all the way up; big numbers are shortened by
-- FormatNumber (K / M / B / T / Qd / Qn ...). Owner: "I meant 400, keep that and make it 800 skill points" (TreePointsAt).
-- Raising the cap again = this number + LEVEL_MINUTES + titles (points follow TreePointsAt).
-- LAUNCH CAP (owner 2026-10-22: "launch level cap 200", docs/LAUNCH_CAP_PLAN.md): every curve stays built to 400 (power, enemy
-- health, ceilings, XP); only the cap + CONTENT_CAP (below) are lowered. A later update raises both numbers and the content
-- above opens by itself (difficulties, map bands, trial tiers, titles). MAX_LEVEL_BUILT = what the curves were tuned to.
ItemData.MAX_LEVEL_BUILT = 400
-- (FUTURE-PROOF 2026-10-25) ONE number: the level cap IS the content cap (raising only one of them opened tiers with no levels to
-- reach them, or levels with nothing new open). Raise ItemData.CONTENT_CAP (above); past MAX_LEVEL_BUILT re-run the curves first.
ItemData.MAX_LEVEL = ItemData.CONTENT_CAP
function ItemData.LevelCurve(level: number?): number
    local l = math.max(1, math.floor(level or 1))
    if l <= ItemData.LATE_LEVEL then return ItemData.LEVEL_GROWTH ^ (l - 1) end
    return ItemData.LEVEL_GROWTH ^ (ItemData.LATE_LEVEL - 1) * ItemData.LEVEL_GROWTH_LATE ^ (l - ItemData.LATE_LEVEL)
end

-- (RARITY v4: the 5 rarities; an OLD name answers its new rarity's rank through RARITY_ALIAS -- pairs() sees only the 5)
local RarityRank: { [string]: number } = setmetatable({ Common = 1, Uncommon = 2, Rare = 3, Mythic = 4, Relic = 5 }, {
    __index = function(t, k) local a = ItemData.RARITY_ALIAS[k]; return a and rawget(t, a) or nil end,
})
ItemData.RarityRank = RarityRank

-- ===== THE BAG (owner 2026-10-07: "Inventory should no longer have unlimited space to encourage putting items in stash")
-- What you carry: weapons + gear, not counting what you have equipped. Full = new drops stay on the ground (pick them up
-- after making room) and shop buys / trades that would overfill it are refused. Your HIDEOUT STASH holds the rest
-- (HideoutData.StashCap). Saves that already carry more keep everything; they just can't take more until under the cap.
ItemData.BAG_CAP = 60
function ItemData.BagCount(state: any): number
    if type(state) ~= "table" then return 0 end
    local n = #(type(state.Inventory) == "table" and state.Inventory or {}) + #(type(state.GearInventory) == "table" and state.GearInventory or {})
    local eq = state.EquippedWeapon
    if eq then
        for _, w in ipairs(type(state.Inventory) == "table" and state.Inventory or {}) do
            if w.Uid == eq.Uid then n -= 1 break end
        end
    end
    return n
end
-- (UPDATE 7 MASTERY RANK: +5 slots every 2 ranks, up to +50 at rank 20 -- the same rule as MasteryRank.BagBonus)
function ItemData.BagCap(state: any): number
    local r = math.clamp(math.floor(tonumber(type(state) == "table" and state.MasteryRank) or 0), 0, 20)
    local guild = (type(state) == "table" and type(state.GuildPerks) == "table" and tonumber(state.GuildPerks.Bag)) or 0 -- (UPDATE 7 B9)
    return ItemData.BAG_CAP + 5 * (r // 2) + math.clamp(guild, 0, 30)
end
function ItemData.BagRoom(state: any): number return math.max(0, ItemData.BagCap(state) - ItemData.BagCount(state)) end

-- ===== TITLES v4 (owner 2026-10-07: "Title still need work, as of now they don't even properly follow rarity sorting, and
-- some of them no longer make sense as we've updated"): rarities re-graded against the 15-tier ladder (a difficulty
-- clear = that difficulty's top loot rarity, Easy Uncommon .. Singularity Infinite; levels / kill counts graded for a
-- level-400 game), then every title's Order is rewritten so the list sorts by RARITY first, then difficulty inside it.
do
    local REGRADE = {
        -- difficulty clears (the ladder)
        IncursionScout = "Uncommon", BiomeConqueror = "Rare", CelestialSentinel = "Epic", HyperVelocityStalker = "Legendary",
        GodOfIncursion = "Mythic", TormentClear = "Celestial", CataclysmClear = "Transcendent", OblivionClear = "Astral",
        RuinClear = "Empyrean", DreadClear = "Primordial", ApocalypseClear = "Sovereign", AnnihilationClear = "Eclipse",
        EternityClear = "Genesis", SingularityClear = "Infinite",
        -- levels
        OmniConstellation = "Epic", Veteran80 = "Legendary", Centurion = "Mythic", Bicentennial = "Transcendent",
        Tricentennial = "Primordial", Limitless = "Infinite",
        -- kills / bosses over a long game
        PointBlankBruiser = "Rare", ExtinctionEvent = "Legendary", VoidSovereign = "Epic", GiantsBane = "Mythic",
        -- deathless runs on the ladder they name
        Deathless = "Epic", Immortal = "Mythic",
    }
    for id, r in pairs(REGRADE) do if Titles[id] then Titles[id].Rarity = r end end
    -- requirement text that no longer matched the game
    if Titles.CelestialSentinel then Titles.CelestialSentinel.Requirement = "Clear a Hard run (floor 6)" end
    if Titles.HyperVelocityStalker then Titles.HyperVelocityStalker.Requirement = "Clear a Brutal run (floor 6)" end
    if Titles.GodOfIncursion then Titles.GodOfIncursion.Requirement = "Clear a Nightmare run (floor 8)" end
    -- the sort: rarity, then the old order inside a rarity (seasonal / granted titles last in their rarity)
    local list = {}
    for id, t in pairs(Titles) do table.insert(list, { Id = id, T = t }) end
    table.sort(list, function(a, b)
        local ra, rb = ItemData.LegacyRank[a.T.Rarity] or 1, ItemData.LegacyRank[b.T.Rarity] or 1 -- (RARITY v4: titles keep the old grades)
        if ra ~= rb then return ra < rb end
        local oa, ob = tonumber(a.T.Order) or 99, tonumber(b.T.Order) or 99
        if oa ~= ob then return oa < ob end
        return a.Id < b.Id
    end)
    for i, e in ipairs(list) do e.T.Order = i end
end

-- Rarity's multiplier on a weapon's base damage / a gear piece's armor. Rarity also adds affixes.
-- Rarity mostly adds affixes and effects, not raw damage (a Legendary is ~40% over a same-level Common).
local RarityDamageMult: { [string]: number } = {
    -- (UPDATE 8 PHASE 6, DEFENCE: Mythic 1.50 -> 1.40 -- the full-chase kit (all Mythic + best 6-link + best route) ran ~6x an average
    -- build; with this and the proposed link falloff ~4.1-4.5x, the owner's 2-4x band. Baked into new items at drop.)
    Common = 1.0, Uncommon = 1.08, Rare = 1.35, Epic = 1.27, Legendary = 1.40, Mythic = 1.40, Celestial = 1.70, Transcendent = 1.85,
    Astral = 1.97, Empyrean = 2.09, Primordial = 2.21, Sovereign = 2.33, Eclipse = 2.45, Genesis = 2.57, Infinite = 2.70,
    Relic = 1.50, -- (RARITY v4: Rare 1.17 -> 1.35 (the workhorse ~ the old Epic / Legendary typical gear), Mythic 1.55 -> 1.50)
}
ItemData.RarityDamageMult = RarityDamageMult

-- How strong a rarity's affix rolls are (x the Common range).
-- (RARITY v4: a table -- the old 1 + 0.14 x (rank - 1) for the 5 rarities would have cut the workhorse's lines; Rare = the old
-- Epic, Mythic / Relic = the old Legendary. Old names keep their old rank's value.)
ItemData.AFFIX_POWER = { Common = 1.0, Uncommon = 1.14, Rare = 1.42, Mythic = 1.56, Relic = 1.56 }
local function AffixTier(rarity: string): number
    local p = ItemData.AFFIX_POWER[rarity]
    if p then return p end
    return 1 + 0.14 * ((ItemData.LegacyRank[rarity] or 1) - 1)
end

-- ==================== [STAT DEFINITIONS] ====================
-- Every stat that can appear on an item, with how it's displayed and what it does (used for item
-- tooltips, the character sheet and for building simple affix-based item names).
--   Kind "pct"    -> stored as a fraction, shown as a whole percent ("+12% Crit Damage")
--   Kind "flat"   -> a plain number that grows with item level ("+34 Max Health")
--   Kind "points" -> attribute points ("+2 Strength")
export type StatDef = { Label: string, Kind: string, Prefix: string, Noun: string, Desc: string, Suffix: string? }
local StatDefs: { [string]: StatDef } = {
    IncreasedDamage = { Label = "Weapon Damage", Kind = "pct", Prefix = "Mighty", Noun = "Power", Desc = "Increases the damage of every shot." },
    -- (2026-10-20 CEILING NOTABLES: raise a stat's level ceiling for the tree / gems / specialization -- StatCalculator.CEIL_STATS)
    CeilDamage = { Label = "Damage Ceiling", Kind = "pct", Desc = "Raises how much Weapon Damage from the tree counts at your level." },
    CeilMaxHP = { Label = "Max Health Ceiling", Kind = "pct", Desc = "Raises how much Max Health from the tree counts at your level." },
    CeilCritChance = { Label = "Crit Chance Ceiling", Kind = "pct", Desc = "Raises how much Crit Chance from the tree counts at your level." },
    CeilCritMulti = { Label = "Crit Damage Ceiling", Kind = "pct", Desc = "Raises how much Crit Damage from the tree counts at your level." },
    CeilWeakSpot = { Label = "Weak-Spot Damage Ceiling", Kind = "pct", Desc = "Raises how much Weak-Spot Damage from the tree counts at your level." },
    CeilArmor = { Label = "Armor Ceiling", Kind = "pct", Desc = "Raises how much Armor from the tree counts at your level." },
    CeilAilPower = { Label = "Ailment Power Ceiling", Kind = "pct", Desc = "Raises how much Burn / Bleed / Freeze / Decay power from the tree counts at your level." },
    FireRateBonus = { Label = "Fire Rate", Kind = "pct", Prefix = "Swift", Noun = "Haste", Desc = "More shots per second." },
    CritChance = { Label = "Crit Chance", Kind = "pct", Prefix = "Keen", Noun = "Insight", Desc = "Chance for any shot to critically hit." },
    CritMultiplier = { Label = "Crit Damage", Kind = "pct", Prefix = "Brutal", Noun = "Carnage", Desc = "Extra damage a critical hit deals on top of a normal hit." },
    WeakSpotMultiplier = { Label = "Weak-Spot Damage", Kind = "pct", Prefix = "Precise", Noun = "Precision", Desc = "Extra damage when you hit an enemy's head or core." },
    MagSizeBonus = { Label = "Magazine Size", Kind = "pct", Prefix = "Deep", Noun = "Plenty", Desc = "More rounds before you need to reload." },
    ReloadSpeedBonus = { Label = "Reload Speed", Kind = "pct", Prefix = "Nimble", Noun = "Readiness", Desc = "Reload faster." },
    RecoilControl = { Label = "Recoil Control", Kind = "pct", Prefix = "Stable", Noun = "Stability", Desc = "Reduces how much the weapon kicks per shot." },
    StreakDamageBonus = { Label = "Damage per Focus Stack", Kind = "pct", Prefix = "Focused", Noun = "Focus", Desc = "Each Focus Streak stack (consecutive weak-spot hits) adds this much damage, up to 25 stacks." },
    MaxHP = { Label = "Max Health", Kind = "flat", Prefix = "Sturdy", Noun = "Vigor", Desc = "More health. Grows with item level." },
    HPRegen = { Label = "Health Regen", Kind = "flat", Suffix = "/s", Prefix = "Renewing", Noun = "Renewal", Desc = "Health restored every second. Grows with item level." },
    Armor = { Label = "Plating", Kind = "flat", Prefix = "Reinforced", Noun = "Warding", Desc = "Cuts Kinetic hits (small hits more than big ones). Grows with item level." }, -- (UPDATE 8 DEFENCE: Armor = Plating)
    MovementSpeed = { Label = "Move Speed", Kind = "pct", Prefix = "Fleet", Noun = "the Wind", Desc = "Walk faster." },
    LootLuck = { Label = "Loot Luck", Kind = "pct", Prefix = "Lucky", Noun = "Fortune", Desc = "Better odds of higher-rarity drops." },
    GoldBonus = { Label = "Gold Find", Kind = "pct", Prefix = "Gilded", Noun = "Greed", Desc = "More gold from kills, chests and sales." },
    Strength = { Label = "Strength", Kind = "points", Prefix = "Strong", Noun = "Might", Desc = "Each point: +1.5% weapon damage and stronger melee (diminishing toward your level's attribute ceiling)." },
    Dexterity = { Label = "Dexterity", Kind = "points", Prefix = "Deft", Noun = "Finesse", Desc = "Each point: +0.4% crit chance, +1.5% reload speed (diminishing toward your level's ceiling)." },
    Vitality = { Label = "Vitality", Kind = "points", Prefix = "Hale", Noun = "Life", Desc = "Each point: +3% max health and more health regen (diminishing toward your level's ceiling)." },
    Luck = { Label = "Luck", Kind = "points", Prefix = "Charmed", Noun = "Chance", Desc = "Each point: +2.5% loot luck (diminishing toward your level's ceiling) and +0.2% Proc Chance (at most +12%)." },
    AllAttributes = { Label = "All Attributes", Kind = "points", Prefix = "Balanced", Noun = "Balance", Desc = "Adds to Strength, Dexterity, Vitality and Luck." },
    -- Defense (percent of a total, so they stay meaningful at every level)
    MaxHPPct = { Label = "Increased Max Health", Kind = "pct", Prefix = "Hearty", Noun = "the Titan", Desc = "Increases your maximum health by this percentage." },
    ArmorPct = { Label = "Increased Plating", Kind = "pct", Prefix = "Plated", Noun = "the Bulwark", Desc = "Increases your total Plating by this percentage." },
    HPRegenPct = { Label = "Regen (% Max Health/s)", Kind = "pct", Prefix = "Mending", Noun = "Mending", Desc = "Regenerate this percentage of your maximum health every second." },
    -- (UPDATE 8 DEFENCE) the old resist lines read as the new types (FireResist = Heat, ColdResist = Cryo, ChaosResist = Void +
    -- Volt until WIPE 5, AllResist = all four); the new keys below are what Phase 2 gear rolls
    FireResist = { Label = "Heat Resistance", Kind = "pct", Prefix = "Fireproof", Noun = "the Hearth", Desc = "Reduces Heat damage taken and weakens Burns on you. Max 75%; harder difficulties lower it." },
    ColdResist = { Label = "Cryo Resistance", Kind = "pct", Prefix = "Insulated", Noun = "the Tundra", Desc = "Reduces Cryo damage taken and weakens Chill slows on you. Max 75%; harder difficulties lower it." },
    ChaosResist = { Label = "Void + Volt Resistance", Kind = "pct", Prefix = "Warded", Noun = "the Void", Desc = "Reduces Void and Volt damage taken and weakens Wither and Shock on you. Max 75%; harder difficulties lower it." },
    AllResist = { Label = "All Resistances", Kind = "pct", Prefix = "Prismatic", Noun = "the Prism", Desc = "Adds to Heat, Cryo, Volt and Void resistance." },
    Plating = { Label = "Plating", Kind = "flat", Prefix = "Reinforced", Noun = "Warding", Desc = "Cuts Kinetic hits (small hits more than big ones)." },
    PlatingPct = { Label = "Increased Plating", Kind = "pct", Prefix = "Plated", Noun = "the Bulwark", Desc = "Increases your total Plating by this percentage." },
    MorePlating = { Label = "More Plating", Kind = "pct", Prefix = "", Noun = "", Desc = "Multiplies your total Plating." },
    Agility = { Label = "Agility", Kind = "flat", Prefix = "Nimble", Noun = "the Slip", Desc = "A chance for an ordinary enemy hit to miss you. Boss hits and floor mechanics always land." },
    AgilityPct = { Label = "Increased Agility", Kind = "pct", Prefix = "Fleet", Noun = "Evasion", Desc = "Increases your total Agility by this percentage." },
    MoreAgility = { Label = "More Agility", Kind = "pct", Prefix = "", Noun = "", Desc = "Multiplies your total Agility." },
    Ward = { Label = "Ward", Kind = "flat", Prefix = "Shielded", Noun = "the Aegis", Desc = "A recharging shield in front of your health. Void damage skips it." },
    WardPct = { Label = "Increased Ward", Kind = "pct", Prefix = "Charged", Noun = "the Barrier", Desc = "Increases your total Ward by this percentage." },
    MoreWard = { Label = "More Ward", Kind = "pct", Prefix = "", Noun = "", Desc = "Multiplies your total Ward." },
    WardRecharge = { Label = "Faster Ward Recharge", Kind = "pct", Prefix = "Humming", Noun = "Renewal", Desc = "Your Ward refills faster." },
    WardStart = { Label = "Faster Ward Restart", Kind = "pct", Prefix = "Restless", Noun = "Haste", Desc = "Your Ward starts recharging sooner after a hit." },
    HeatResist = { Label = "Heat Resistance", Kind = "pct", Prefix = "Fireproof", Noun = "the Hearth", Desc = "Reduces Heat damage taken and weakens Burns on you. Max 75%; harder difficulties lower it." },
    CryoResist = { Label = "Cryo Resistance", Kind = "pct", Prefix = "Insulated", Noun = "the Tundra", Desc = "Reduces Cryo damage taken and weakens Chill slows on you. Max 75%; harder difficulties lower it." },
    VoltResist = { Label = "Volt Resistance", Kind = "pct", Prefix = "Grounded", Noun = "the Storm", Desc = "Reduces Volt damage taken and weakens Shock on you. Max 75%; harder difficulties lower it." },
    VoidResist = { Label = "Void Resistance", Kind = "pct", Prefix = "Warded", Noun = "the Void", Desc = "Reduces Void damage taken and weakens Wither on you. Max 75%; harder difficulties lower it." },
    AllElemResist = { Label = "Elemental Resistances", Kind = "pct", Prefix = "Prismatic", Noun = "the Prism", Desc = "Adds to Heat, Cryo and Volt resistance." },
    MaxHeatResist = { Label = "Maximum Heat Resistance", Kind = "pct", Prefix = "", Noun = "", Desc = "Raises the 75% Heat resistance cap." },
    MaxCryoResist = { Label = "Maximum Cryo Resistance", Kind = "pct", Prefix = "", Noun = "", Desc = "Raises the 75% Cryo resistance cap." },
    MaxVoltResist = { Label = "Maximum Volt Resistance", Kind = "pct", Prefix = "", Noun = "", Desc = "Raises the 75% Volt resistance cap." },
    MaxVoidResist = { Label = "Maximum Void Resistance", Kind = "pct", Prefix = "", Noun = "", Desc = "Raises the 75% Void resistance cap." },
    MaxAllElemResist = { Label = "Maximum Elemental Resistances", Kind = "pct", Prefix = "", Noun = "", Desc = "Raises the Heat, Cryo and Volt resistance caps." },
    LifeLeech = { Label = "Life Leech", Kind = "pct", Prefix = "Leeching", Noun = "Thirst", Desc = "This percentage of the damage your hits deal is returned to you as health." },
    -- Weapon-prefix effects (Burn, Freeze, Bleed, Decay, Explosive, Fixation, Giantslayer)
    AilmentChance = { Label = "Proc Chance", Kind = "pct", Prefix = "Volatile", Noun = "Catalysis", Desc = "Increases the trigger chance of Burning, Freezing, Bleeding, Decaying and Echoing weapons (e.g. 20% x 1.3 = 26%)." },
    AilmentDuration = { Label = "Effect Duration", Kind = "pct", Prefix = "Lingering", Noun = "Persistence", Desc = "Your Burns, Freezes, Bleeds and Decays last longer (they deal their damage over the longer time)." },
    BurnDamage = { Label = "Burn Damage", Kind = "pct", Prefix = "Searing", Noun = "Embers", Desc = "Increases the damage your Burns deal." },
    FreezeEffect = { Label = "Freeze Effect", Kind = "pct", Prefix = "Glacial", Noun = "Frost", Desc = "Increases how much your Freezes slow enemies and the damage they deal." },
    BleedDamage = { Label = "Bleed Damage", Kind = "pct", Prefix = "Serrated", Noun = "Laceration", Desc = "Increases the damage your Bleeds deal." },
    DecayEffect = { Label = "Decay Effect", Kind = "pct", Prefix = "Withering", Noun = "Rot", Desc = "Enemies you Decay take even more damage from every source." },
    ExplosionDamage = { Label = "Explosion Damage", Kind = "pct", Prefix = "Blasting", Noun = "Ruin", Desc = "Increases the damage of your explosions (Explosive and Fixation weapons, launcher splash)." },
    -- Keystone-only multipliers ("more"/"less" multiply the total, separate from additive bonuses)
    MoreDamage = { Label = "More Damage", Kind = "pct", Prefix = "", Noun = "", Desc = "Multiplies your total hit damage." },
    MoreFireRate = { Label = "More Fire Rate", Kind = "pct", Prefix = "", Noun = "", Desc = "Multiplies your total fire rate." },
    MoreMaxHP = { Label = "More Max Health", Kind = "pct", Prefix = "", Noun = "", Desc = "Multiplies your total max health." },
    MoreArmor = { Label = "More Plating", Kind = "pct", Prefix = "", Noun = "", Desc = "Multiplies your total Plating." },
    MoreWeakSpotDamage = { Label = "More Weak-Spot Damage", Kind = "pct", Prefix = "", Noun = "", Desc = "Multiplies weak-spot damage." },
    MoreCritChance = { Label = "More Crit Chance", Kind = "pct", Prefix = "", Noun = "", Desc = "Multiplies your crit chance." },
    BodyShotMore = { Label = "More Body-Shot Damage", Kind = "pct", Prefix = "", Noun = "", Desc = "Multiplies damage of non-weak-spot hits." },
    BurnMore = { Label = "More Burn Damage", Kind = "pct", Prefix = "", Noun = "", Desc = "Multiplies your Burn damage." },
    LeechMore = { Label = "More Life Leech", Kind = "pct", Prefix = "", Noun = "", Desc = "Multiplies your life leech." },
    MaxResist = { Label = "Maximum Resistances", Kind = "pct", Prefix = "", Noun = "", Desc = "Raises or lowers the 75% resistance cap." },
    MoreExplosion = { Label = "More Explosion Damage", Kind = "pct", Prefix = "", Noun = "", Desc = "Multiplies your explosion damage." },
    BleedMore = { Label = "More Bleed Damage", Kind = "pct", Prefix = "", Noun = "", Desc = "Multiplies your Bleed damage." },
    -- Passive tree / gem mechanics (conditional bonuses; CombatServer applies them per hit / kill)
    BaseArmor = { Label = "Plating (grows with level)", Kind = "flat", Prefix = "Armored", Noun = "Iron", Desc = "Plating of your own, scaled by your level, works without plated gear." },
    BurnOnHit = { Label = "Chance to Burn on Hit", Kind = "pct", Prefix = "Igniting", Noun = "Cinders", Desc = "Any gun can ignite: base chance per hit (slow guns get more per shot, like a weapon prefix). Uses your Burn stats." },
    ChillOnHit = { Label = "Chance to Chill on Hit", Kind = "pct", Prefix = "Chilling", Noun = "Rime", Desc = "Any gun can chill: base chance per hit. Uses your Freeze stats." },
    BleedOnHit = { Label = "Chance to Bleed on Hit", Kind = "pct", Prefix = "Rending", Noun = "Wounds", Desc = "Any gun can cause Bleeding: base chance per hit. Uses your Bleed stats." },
    DecayOnHit = { Label = "Chance to Decay on Hit", Kind = "pct", Prefix = "Rotting", Noun = "Rot", Desc = "Any gun can Decay enemies (they take more damage from everything): base chance per hit." },
    ExplodeOnHit = { Label = "Chance to Explode on Hit", Kind = "pct", Prefix = "Detonating", Noun = "Blasts", Desc = "Any gun's hits can explode: base chance per hit. Uses your Explosion stats." },
    FirstHitDamage = { Label = "Damage vs Full-Health Enemies", Kind = "pct", Prefix = "Opening", Noun = "Ambush", Desc = "Increased damage against enemies that haven't been hurt yet." },
    LowHealthEnemyDamage = { Label = "Damage vs Low-Health Enemies", Kind = "pct", Prefix = "Merciless", Noun = "the Hunt", Desc = "Increased damage against enemies below 35% health." },
    MovingDamage = { Label = "Damage while Moving", Kind = "pct", Prefix = "Running", Noun = "Momentum", Desc = "Increased damage while you are moving." },
    StillDamage = { Label = "Damage while Standing Still", Kind = "pct", Prefix = "Braced", Noun = "Stillness", Desc = "Increased damage while you are standing still." },
    StillDR = { Label = "Damage Reduction while Still", Kind = "pct", Prefix = "Rooted", Noun = "the Root", Desc = "Take less damage while you are standing still." },
    CloseRangeDamage = { Label = "Damage at Close Range", Kind = "pct", Prefix = "Point-Blank", Noun = "Close Quarters", Desc = "Increased damage to enemies within 25 studs of you." },
    LongRangeDamage = { Label = "Damage at Long Range", Kind = "pct", Prefix = "Far-Reaching", Noun = "Long Reach", Desc = "Increased damage to enemies 60 or more studs away." },
    ReloadedDamage = { Label = "Damage after Reloading", Kind = "pct", Prefix = "Fresh", Noun = "Fresh Load", Desc = "Increased damage for 3 seconds after you finish a reload." },
    FreshMagDamage = { Label = "Damage with First 30% of Magazine", Kind = "pct", Prefix = "Opening", Noun = "Opening Rounds", Desc = "Increased damage while 70% or more of your magazine is left." },
    LastMagDamage = { Label = "Damage with Last 30% of Magazine", Kind = "pct", Prefix = "Desperate", Noun = "Last Rounds", Desc = "Increased damage while 30% or less of your magazine is left." },
    AilmentedDamage = { Label = "Damage vs Ailing Enemies", Kind = "pct", Prefix = "Exploiting", Noun = "Weakness", Desc = "Increased damage against enemies that are Burning, Chilled, Bleeding or Decayed." },
    EliteDamage = { Label = "Damage vs Elites & Bosses", Kind = "pct", Prefix = "Slaying", Noun = "Giants", Desc = "Increased damage against elite enemies and bosses." },
    SwitchDamage = { Label = "Damage vs a New Target", Kind = "pct", Prefix = "Flicking", Noun = "the Flick", Desc = "Increased damage when you shoot a different enemy than your last shot." },
    KillHeal = { Label = "Heal on Kill (% Max Health)", Kind = "pct", Prefix = "Reaping", Noun = "Renewal", Desc = "Every kill restores this share of your max health." },
    LowLifeDR = { Label = "Damage Reduction below 50% Health", Kind = "pct", Prefix = "Stubborn", Noun = "Last Stands", Desc = "Take less damage while you are below half health." },
    HPToDamage = { Label = "of Increased Max Health as Damage", Kind = "pct", Prefix = "", Noun = "", Desc = "This share of your Increased Max Health also counts as Increased Damage." },
    WeakSpotCritChance = { Label = "Crit Chance on Weak-Spot Hits", Kind = "pct", Prefix = "Splitting", Noun = "Skulls", Desc = "Extra crit chance for hits on a head or core." },
    FocusRetain = { Label = "Focus Kept When Hit", Kind = "pct", Prefix = "Unbroken", Noun = "Resolve", Desc = "Getting hit only removes part of your Focus stacks instead of all of them." },
    BurnSpread = { Label = "Burn Spread on Kill", Kind = "pct", Prefix = "Spreading", Noun = "Wildfire", Desc = "When a burning enemy dies, this share of its Burn jumps to every enemy nearby." },
    ShatterPct = { Label = "Shatter (% of Max Health)", Kind = "pct", Prefix = "Shattering", Noun = "Shards", Desc = "Chilled enemies you kill shatter, dealing this share of their max health to enemies nearby." },
    CorpseExplode = { Label = "Kill Explosion (% of Max Health)", Kind = "pct", Prefix = "Volatile", Noun = "Remains", Desc = "Enemies you kill explode, dealing this share of their max health to enemies nearby." },
    BleedStacks = { Label = "Max Bleed Stacks", Kind = "flat", Prefix = "Deep", Noun = "Wounds", Desc = "Your Bleeds can stack more times." },
    ExplosionRadiusPct = { Label = "Explosion Radius", Kind = "pct", Prefix = "Wide", Noun = "Shockwaves", Desc = "Your explosions cover a bigger area." },
    RicochetPct = { Label = "Crit Ricochet Damage", Kind = "pct", Prefix = "Ricocheting", Noun = "Ricochets", Desc = "(retired)" },
    -- PRECISION stats (2026-10-02: the power fantasy is killing each enemy faster, not hitting many at once)
    ChainKillDamage = { Label = "Damage per Chain Kill", Kind = "pct", Prefix = "Relentless", Noun = "Momentum", Desc = "Each kill gives a Chain stack for 4s (max 5): every stack adds this much increased damage. Keep killing to keep them." },
    OverkillCarry = { Label = "Overkill Carried", Kind = "pct", Prefix = "Overflowing", Noun = "Overkill", Desc = "This share of the damage beyond what kills an enemy is added to your next hit (within 3s)." },
    PierceDamage = { Label = "Pierce Damage", Kind = "pct", Prefix = "Piercing", Noun = "Penetration", Desc = "Increases the damage your shots deal to the enemies they pierce into (high-caliber guns)." },
    PierceCount = { Label = "Extra Enemies Pierced", Kind = "flat", Prefix = "Penetrating", Noun = "Overpenetration", Desc = "Your piercing shots carry through this many more enemies (high-caliber guns)." },
    ExecutePct = { Label = "Execute Threshold", Kind = "pct", Prefix = "Culling", Noun = "Culling", Desc = "Your hits kill non-boss enemies below this share of their health (elites below half of it)." },
}
-- WEAPON GROUPS = THE FIVE CLASSES (2026-10-05, owner: "i want classes to be weapon based ... (AR, LMG) (SMG, PISTOL)
-- (DMR / SR) (MISC (SOMETHING LIKE A FUTURE HITSCAN BEAM WEAPON))", shotguns their own class). THE ONE PLACE gun types
-- are grouped. Each group gets the tree stats <Group>Damage / FireRate / CritChance / CritMultiplier / ReloadSpeed /
-- MagSize / WeakSpot (StatCalculator, labels below), the ascendancy condition "Group:<Group>", and its class
-- (ClassData.Group): class passives + the ascendancy only work while you hold a gun of your class's group.
-- ADDING A GUN TYPE: give its Class a group in ByClass. Launchers have NO group on purpose (owner: "launchers or
-- explosives will never exist so dont do anything based around that"): no class bonuses for them.
ItemData.WeaponGroups = {
    Order = { "Assault", "Close", "Precision", "Shotgun", "Beam" },
    Label = { Assault = "AR / LMG", Close = "SMG / Pistol", Precision = "DMR / Sniper", Shotgun = "Shotgun", Beam = "Beam" },
    Long = { Assault = "an assault rifle or LMG", Close = "an SMG or pistol", Precision = "a DMR or sniper", Shotgun = "a shotgun", Beam = "a beam gun" },
    Hint = {},
    ByClass = { Rifle = "Assault", Burst = "Assault", Heavy = "Assault", SMG = "Close", Pistol = "Close", Revolver = "Close",
        Sniper = "Precision", Shotgun = "Shotgun", Laser = "Beam" },
    -- per gun overrides (BaseId -> group, false = none): the two Heavy-class launchers are not LMGs
    ById = { RocketLauncher = false, GrenadeLauncher = false },
}
-- WEAPON TYPE + CLASS LABELS (0.50, owner: "make sure the weapons have something that indicates the weapon type and what
-- class they are for"): "Assault Rifle  •  Vanguard" on every tooltip / loot card / stash row / target picker
ItemData.WeaponGroups.ClassName = { Assault = "Vanguard", Close = "Gunslinger", Precision = "Marksman", Shotgun = "Breacher", Beam = "Arcwright" }
ItemData.WeaponTypeNames = { Rifle = "Assault Rifle", Burst = "Burst Rifle", Heavy = "LMG", SMG = "SMG", Pistol = "Pistol", Revolver = "Revolver",
    Sniper = "Sniper Rifle", Shotgun = "Shotgun", Laser = "Beam Gun", Launcher = "Launcher" }
ItemData.WeaponTypeById = { SVD = "DMR", SKS = "DMR", EMR = "DMR", MK11 = "DMR", M82 = "Anti-Materiel Rifle" }
-- w = a weapon instance or a BaseWeapons entry (needs BaseId or pass baseId)
function ItemData.WeaponTypeName(w: any, baseId: string?): string
    local id = baseId or (w and w.BaseId)
    return (id and ItemData.WeaponTypeById[id]) or ItemData.WeaponTypeNames[(w and w.Class) or ""] or ((w and w.Class) or "Gun")
end
-- "Assault Rifle  •  Vanguard" (no class: "Launcher  •  no class")
function ItemData.WeaponTypeLine(w: any, baseId: string?): string
    local probe = w
    if baseId and w and not w.BaseId then probe = { BaseId = baseId, Class = w.Class } end
    local grp = ItemData.WeaponGroupOf(probe)
    local cls = grp and ItemData.WeaponGroups.ClassName[grp]
    return ItemData.WeaponTypeName(w, baseId) .. "  •  " .. (cls and (cls .. " class") or "no class")
end

function ItemData.WeaponGroupOf(w: any): string?
    if not w then return nil end
    local o = w.BaseId and ItemData.WeaponGroups.ById[w.BaseId]
    if o ~= nil then return o or nil end
    return ItemData.WeaponGroups.ByClass[w.Class or ""]
end
do
    -- (passive tree v4) every loot gun must belong to a weapon group, or the tree's gun-type nodes never apply to it
    for _, id in ipairs(ItemData.Lineup) do
        local b = BaseWeapons[id]
        if b and not ItemData.WeaponGroups.ByClass[b.Class or ""] and ItemData.WeaponGroups.ById[id] == nil and b.Class ~= "Launcher" then
            warn("[ItemData] gun " .. id .. " has Class " .. tostring(b.Class) .. " with no weapon group: add it to ItemData.WeaponGroups.ByClass")
        end
    end
end
-- ===== (CLASS BUILDS) GUN FAMILIES (GUNS builder, docs/CLASS_BUILDS.md section 1) =====
-- Owner 2026-10-21: "The guns all equate to the same dps for the most part now: they should synergize differently with
-- different things." Every lineup gun sits in exactly one FAMILY; the family gives the gun a BUILT-IN LINE that changes what
-- it scales with (shown "(family)" on tooltips / loot cards / the Index / the MODS window; never rolled, crafted or removed).
-- Read AT USE like GUN_TUNE (ItemData.FamilyOf(w) from the BaseId): nothing is baked into saved items, every old gun has it.
-- P = the line's numbers (CombatServer.CB.Family reads them; tools/sim cbguns harness too). Tune = a hidden damage factor
-- folded into ItemData.GunTune so a family's AVERAGE build keeps its class pace (the line changes what scales, not the
-- average). ModNote = how a shot mod behaves on this family (MODS window + the SHOT MODS codex page).
ItemData.GunFamilies = {
    Bolt = { Name = "Bolt Action", Class = "Precision", Guns = { "AWP", "M40", "SCOUT", "M82" }, Line = "FAM_FIRSTCRIT", P = {}, Tune = 0.90,
        ModNote = { Chain = "Chain on a bolt action: one hop at full damage." } },
    DMR = { Name = "Marksman Rifle", Class = "Precision", Guns = { "SVD", "SKS", "EMR", "MK11" }, Line = "FAM_WEAKCHAIN", P = { Per = 0.08, Max = 6 } },
    HandCannon = { Name = "Hand Cannon", Class = "Close", Guns = { "DEAGLE", "RHINO" }, Line = "FAM_SWITCHROUND", P = { More = 0.30 }, Tune = 0.97 }, -- ((CLASS BUILDS) balance: line 0.40 -> 0.30, Tune 0.95 -> 0.97)
    LightPistol = { Name = "Sidearm", Class = "Close", Guns = { "Glock17", "USP", "P226", "SR9", "PX4", "TEC9" }, Line = "FAM_MOVEDODGE",
        P = { Agility = 1.5, FiredWithin = 0.6, DodgeMore = 0.20, DodgeFor = 1.5 } },
    SMG = { Name = "SMG", Class = "Close", Guns = { "UZI", "MP5", "P90", "MP7", "MP40", "PPSH", "VECTOR" }, Line = "FAM_TENTH", P = { Every = 10 } },
    Rifle = { Name = "Rifle", Class = "Assault", Guns = { "AK47", "SCAR", "M4A1", "AUG", "F2000", "TAR21", "GALIL", "HK416" }, Line = "FAM_PIERCE",
        P = { Pierce = 1, Grow = 0.10, Cap = 8 },
        ModNote = { Pierce = "Pierce on a rifle: its targets add to the built-in one, the shot keeps full damage and still grows 10% an enemy." } },
    LMG = { Name = "LMG", Class = "Assault", Guns = { "M249", "PKM", "M60", "HK21" }, Line = "FAM_RAMP", P = { Per = 0.02, Max = 0.60, Reset = 0.6 }, Tune = 0.70,
        ModNote = { Detonate = "Detonate on an LMG: only at full ramp, and the blast carries the ramp's bonus." } },
    Pump = { Name = "Pump Shotgun", Class = "Shotgun", Guns = { "R870", "M590", "KSG", "DBARREL" }, Line = "FAM_POINTBLANK", P = { More = 0.25 } }, -- ((CLASS BUILDS) balance: 0.35 -> 0.25)
    Auto = { Name = "Auto Shotgun", Class = "Shotgun", Guns = { "BM4", "AA12", "USAS12" }, Line = "FAM_PELLETAIL", P = { PelletChance = 0.5, ChainCap = 3 },
        ModNote = { Chain = "Chain on an auto shotgun: each pellet that kills chains once (up to 3 a shot) for the chain's share of the whole shot." } },
    Ray = { Name = "Ray", Class = "Beam", Guns = { "BEAM", "ContinuousLaser", "QuadBeam", "SparkPistol" }, Line = "FAM_TICKSTACK", P = { Every = 5 } },
    Lance = { Name = "Lance", Class = "Beam", Guns = { "Railgun", "PlasmaCannon", "VoidDisintegrator" }, Line = "FAM_LANCE", P = { Cap = 8 },
        ModNote = { Fork = "Fork on a lance: the split starts from the last enemy in the line." } },
}
ItemData.GUN_FAMILY_ORDER = { "Bolt", "DMR", "HandCannon", "LightPistol", "SMG", "Rifle", "LMG", "Pump", "Auto", "Ray", "Lance" }
ItemData.GUN_FAMILY_COLOR = Color3.fromRGB(255, 214, 140)
-- the line in player words (numbers from P, so text and combat never drift)
function ItemData.FamilyDesc(fid: string?): string?
    local f = fid and ItemData.GunFamilies[fid]
    if not f then return nil end
    local P = f.P
    local function pc(x) return tostring(math.round(x * 100)) end
    local L = f.Line
    if L == "FAM_FIRSTCRIT" then return "The first hit on each enemy is always a crit."
    elseif L == "FAM_WEAKCHAIN" then return "Weak-spot hits in a row stack +" .. pc(P.Per) .. "% damage (up to " .. P.Max .. " stacks); a body hit or a miss resets them."
    elseif L == "FAM_SWITCHROUND" then return "The first hit on each enemy refunds the round and deals " .. pc(P.More) .. "% more."
    elseif L == "FAM_MOVEDODGE" then return "+" .. pc(P.Agility - 1) .. "% Agility while you move and fire; dodging a hit gives +" .. pc(P.DodgeMore) .. "% damage for " .. P.DodgeFor .. " s."
    elseif L == "FAM_TENTH" then return "Every " .. P.Every .. "th hit applies every ailment you have a chance for."
    elseif L == "FAM_PIERCE" then return "+" .. P.Pierce .. " Pierce; each enemy the shot passes through adds " .. pc(P.Grow) .. "% damage to the rest of it."
    elseif L == "FAM_RAMP" then return "Damage ramps +" .. pc(P.Per) .. "% a hit while you keep firing (up to +" .. pc(P.Max) .. "%); it resets " .. P.Reset .. " s after you stop hitting."
    elseif L == "FAM_POINTBLANK" then return "If every pellet hits the same enemy, the shot deals " .. pc(P.More) .. "% more."
    elseif L == "FAM_PELLETAIL" then return "Each pellet rolls ailments on its own, at " .. pc(P.PelletChance) .. "% of the chance each."
    elseif L == "FAM_TICKSTACK" then return "Hits build up on an enemy: every " .. P.Every .. "th hit on the same enemy applies every ailment you have a chance for."
    elseif L == "FAM_LANCE" then return "Shots pierce every enemy in a line (up to " .. P.Cap .. ") and lose no damage."
    end
    return nil
end
ItemData.GunFamilyOf = {}
do
    for fid, f in pairs(ItemData.GunFamilies) do
        f.Id = fid
        for _, id in ipairs(f.Guns) do
            if ItemData.GunFamilyOf[id] then warn("[ItemData] gun " .. id .. " is in two gun families: " .. ItemData.GunFamilyOf[id] .. " and " .. fid) end
            ItemData.GunFamilyOf[id] = fid
        end
        f.Desc = ItemData.FamilyDesc(fid)
    end
    for _, id in ipairs(ItemData.Lineup) do
        if not ItemData.GunFamilyOf[id] then warn("[ItemData] lineup gun " .. id .. " has no gun family: add it to ItemData.GunFamilies") end
    end
end
-- ===== HEAVY ROUNDS (owner 2026-10-22: slow guns felt terrible against early hordes -> "slow heavy shots hit many") =====
-- Every gun family gets a FIXED pierce count and a FIXED number of OVERKILL HOPS (more damage never adds either): a kill's
-- leftover damage jumps to the nearest enemy (CombatServer.Off.HeavyCarry), checked against that enemy's resists, no weak-spot /
-- crit re-applied, hop by hop while damage is left. Fast guns rarely overkill fodder, so they barely change. Build investment
-- adds hops (OverkillCarry: the Overkill mod / tree lines +1), capped at HEAVY_MAX_HOPS. PIERCE here REPLACES the old per-gun
-- ItemData.PIERCE table (one source; the Rifle / Lance family lines and the Pierce mod still add on top in PierceShot).
ItemData.HEAVY_ROUNDS = {
    Bolt = { Pierce = 3, Hops = 4 }, DMR = { Pierce = 2, Hops = 2 }, HandCannon = { Pierce = 1, Hops = 1 },
    LightPistol = { Pierce = 0, Hops = 0 }, SMG = { Pierce = 0, Hops = 0 }, Rifle = { Pierce = 1, Hops = 1 },
    LMG = { Pierce = 1, Hops = 1 }, Pump = { Pierce = 0, Hops = 1 }, Auto = { Pierce = 0, Hops = 1 },
    Ray = { Pierce = 0, Hops = 0 }, Lance = { Pierce = 0, Hops = 4 }, -- (Lance: the family line already goes through the whole line)
}
ItemData.HEAVY_FALLOFF = 0.9    -- damage kept per enemy a shot pierces
ItemData.HEAVY_BLAST_KEEP = 0.6 -- a shotgun kill also carries this share of the pull's pellets still to land (they'd hit a corpse)
ItemData.HEAVY_MAX_HOPS = 6     -- every source together
ItemData.HEAVY_HOP_R = 12       -- studs from the last body to the next
-- MARKSMAN LONG CARRY (cbtree balance pass 2026-10-23; owner: Marksman = a glass CANNON, it lacked the cannon in packs): a
-- Studio probe (Torment L55, AWP) found the first shot into a pack kills + hops fine, but the stragglers left stand 12-60 studs
-- apart (19 of 34 hits had no other enemy within 30) and 28 of 33 kills had nothing in hop reach -- the sniper then spends a
-- whole slow shot on each. A Marksman holding a Marksman class gun carries its overkill further (R studs a jump; Hops = extra
-- jumps); a boss or an elite alone is unchanged (nothing to carry into), so single-target damage doesn't move. Sized in Studio
-- (autoplay, same floor seed, plain treesim kits): R 40 + 1 hop made the Marksman ~2.3x the Vanguard / Breacher at Brutal L20 and
-- ~2.5x the Vanguard at Ruin L100; R 30 + 0: ~1.2-1.4x at L20, cleared Torment L55 where the Vanguard didn't, ~1.9x at L100.
ItemData.HEAVY_CLASS = { Precision = { R = 30, Hops = 0 } }
function ItemData.HeavyHops(w: any, overkillCarry: number?): number
    local fid = ItemData.GunFamilyOf and ItemData.GunFamilyOf[type(w) == "table" and w.BaseId or w]
    local h = fid and ItemData.HEAVY_ROUNDS[fid] and ItemData.HEAVY_ROUNDS[fid].Hops or 0
    if (overkillCarry or 0) > 0 then h += 1 end
    return math.min(ItemData.HEAVY_MAX_HOPS, h)
end
do -- the family pierce counts onto the base guns (ItemData.PierceOf / affix pools / tooltips read BaseWeapons[id].Pierce)
    for id, fid in pairs(ItemData.GunFamilyOf or {}) do
        local hr = ItemData.HEAVY_ROUNDS[fid]
        if hr and BaseWeapons[id] then
            BaseWeapons[id].Pierce = (hr.Pierce > 0) and { Targets = hr.Pierce, Falloff = ItemData.HEAVY_FALLOFF } or nil
        end
    end
end
-- w = a weapon instance, a BaseWeapons entry with BaseId, or a base id -> familyId, its def
function ItemData.FamilyOf(w: any): (string?, any?)
    local id = type(w) == "table" and w.BaseId or w
    local fid = type(id) == "string" and ItemData.GunFamilyOf[id] or nil
    return fid, fid and ItemData.GunFamilies[fid] or nil
end
-- "Bolt Action: The first hit on each enemy is always a crit.  (family)"
function ItemData.FamilyLine(w: any): string?
    local _, f = ItemData.FamilyOf(w)
    return f and (f.Name .. ": " .. f.Desc .. "  (family)") or nil
end
-- the hidden balance factor (folded into ItemData.GunTune)
function ItemData.FamilyTune(w: any): number
    local _, f = ItemData.FamilyOf(w)
    return (f and f.Tune) or 1
end
-- (CLASS BUILDS) the shot-mod twist for this gun's family, or nil
function ItemData.FamilyModNote(w: any, modId: string?): string?
    local _, f = ItemData.FamilyOf(w)
    return f and f.ModNote and modId and f.ModNote[modId] or nil
end
-- (passive tree v4, 2026-10-05) weapon-type stats: only count while the equipped gun is of that type; tree-only, never
-- rolled on gear
do
    local GROUP_LABEL = ItemData.WeaponGroups.Label
    local SUFFIX_LABEL = { Damage = "Damage", FireRate = "Fire Rate", CritChance = "Crit Chance", CritMultiplier = "Crit Damage",
        ReloadSpeed = "Reload Speed", MagSize = "Magazine Size", WeakSpot = "Weak-Spot Damage" }
    for grp, gl in pairs(GROUP_LABEL) do
        for suf, sl in pairs(SUFFIX_LABEL) do
            StatDefs[grp .. suf] = { Label = gl .. " " .. sl, Kind = "pct", TreeOnly = true,
                Desc = sl .. " while you hold " .. (ItemData.WeaponGroups.Long[grp] or gl) .. "." }
        end
    end
    StatDefs.MeleeDamagePct = { Label = "Increased Melee Damage", Kind = "pct", TreeOnly = true, Desc = "Increases the damage of your melee attacks." }
end
ItemData.StatDefs = StatDefs

-- BIG NUMBERS (owner 2026-10-05, level cap 400: "we can always use 8,0000T, 8QN etc for numbers, we dont need to cap
-- out the scaling"): the level curve keeps growing 6% a level to the cap, so from 100,000 up numbers are shortened with
-- a suffix (123.4K, 8.25M, 3.1B, 7.0T, then Qd, Qn, Sx, Sp, Oc, No, Dc, and scientific past that). Below 100,000 nothing changes.
local BIG_SUFFIX = { "K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No", "Dc" }
local function FormatNumber(v: number): string
    if v ~= v then return "0" end
    local a = math.abs(v)
    if a >= 1e5 then
        local e = math.floor(math.log10(a) / 3)
        if e > #BIG_SUFFIX then return string.format("%.2e", v) end
        local m = v / 10 ^ (3 * e)
        return string.format((math.abs(m) >= 100) and "%.0f%s" or ((math.abs(m) >= 10) and "%.1f%s" or "%.2f%s"), m, BIG_SUFFIX[e])
    end
    if math.abs(v - math.round(v)) < 0.05 then return tostring(math.round(v)) end
    return string.format("%.1f", v)
end
ItemData.FormatNumber = FormatNumber

-- "+12% Crit Damage", "+34 Max Health", "+2 Health Regen/s", "+3 Strength"
function ItemData.FormatStat(stat: string, value: number): string
    local def = StatDefs[stat]
    if not def then return "+" .. FormatNumber(value) .. " " .. stat end
    if def.Format then return def.Format(value) end -- (UPDATE 8 GEAR v3: hybrid / build lines word themselves)
    local sign = value < 0 and "-" or "+"
    local v = math.abs(value)
    local label = def.Label
    -- (owner 2026-10-04: "-40% Increased Armor" read as a contradiction) a negative "Increased X" is "Reduced X",
    -- a negative "More X" is "Less X" -- shown without the minus, like "40% Reduced Armor"
    if value < 0 then
        local rest = string.match(label, "^Increased (.+)$")
        local less = string.match(label, "^More (.+)$")
        if rest then label, sign = "Reduced " .. rest, ""
        elseif less then label, sign = "Less " .. less, "" end
    end
    if def.Kind == "pct" then
        return sign .. FormatNumber(v * 100) .. "% " .. label
    end
    return sign .. FormatNumber(v) .. " " .. label .. (def.Suffix or "")
end

-- ==================== [WEAPONS] ====================
-- Short, readable model names (item names are "<affix> <model>", e.g. "Keen G36 Burst Rifle").
local WeaponShortNames: { [string]: string } = {
    Revolver = ".44 Magnum", Pistol = "M1911A1", DualDeagle = "Akimbo Mausers", SMG = "MP5", VectorSMG = "Uzi",
    StenSMG = "Sten SMG", RapidCarbine = "M4 Carbine", AK47Classic = "Classic AK-47", BurstRifle = "G36 Burst Rifle",
    HeavyBurst = "M16 Burst Rifle", MarksmanRifle = "SR-25 Marksman", AntiMaterial = "M1 Garand",
    LeverAction = ".22 Lever Rifle", SawedOff = "Sawed-Off", CombatShotgun = "Trench Gun", RocketLauncher = "RPG-7",
    GrenadeLauncher = "Sticky Launcher", Minigun = "Minigun", ContinuousLaser = "Thermal Beam",
    PlasmaCannon = "Plasma Pistol", Railgun = "Railgun", VoidDisintegrator = "Void Blaster", FlintlockPistol = "Flintlock",
    CaptainsFlintlock = "Captain's Flintlock", ColtM1911 = "1911", Luger = "Luger", GoldenLuger = "Golden Luger",
    Revolver45 = ".45 Revolver", Revolver22 = ".22 Revolver", Revolver357 = ".357 Magnum", Quadshooter = "Quadshooter",
    M16A2Rifle = "M16A2", BBGunSniper = "BB Gun", HuntersBow = "Hunting Bow", IthacaM37 = "M37",
    StrikerShotgun = "Striker-12", BenelliM4 = "M4 Combat", Blunderbuss = "Blunderbuss", Remington870 = "870 Classic",
    AgedBlunderbuss = "Aged Blunderbuss", HuntingShotgun = "Hunting Shotgun", AT4Launcher = "AT-4", BazookaLauncher = "Bazooka",
}
-- The rigged lineup (what actually drops): short model names so item names stay at 3 words or fewer.
local LineupShortNames: { [string]: string } = {
    Glock17 = "G19", DEAGLE = "Desert Eagle", TEC9 = "TEC-9", RHINO = "Rhino",
    UZI = "Uzi", MP5 = "MP5", P90 = "P90", MP7 = "MP7",
    AK47 = "AK-47", SCAR = "SCAR-L", M4A1 = "M4A1", AUG = "AUG", F2000 = "FAMAS",
    R870 = "870", BM4 = "M4 Super 90", AA12 = "AA-12",
    AWP = "AWM", M82 = "M82", SCOUT = "Hunting Rifle",
    M249 = "M249", PKM = "PKM", M60 = "M60", HK21 = "21E", TAR21 = "TAR-21", GALIL = "Galil", HK416 = "416", MP40 = "MP40", PPSH = "PPSh-41", VECTOR = "Vector", USAS12 = "Komrad 12", DBARREL = "Double Barrel", KSG = "KS7", M590 = "590 Pump", USP = "USP", P226 = "P226", SR9 = "P99", PX4 = "PX4 Storm", SVD = "SVD", SKS = "SKS", M40 = "M40", EMR = "M14", MK11 = "M110", BEAM = "Arc Projector",
    ContinuousLaser = "Helios Beam", QuadBeam = "Quadbeam", Railgun = "Hyperion", PlasmaCannon = "Ion Accelerator", VoidDisintegrator = "Void Rifle", SparkPistol = "Spark Pistol",
}
for id, def in pairs(BaseWeapons) do
    def.ShortName = LineupShortNames[id] or WeaponShortNames[id] or def.Name
end

-- Deterministic: the same gun at the same rarity and item level always has the same damage.
function ItemData.WeaponDamageAt(baseId: string, rarity: string, itemLevel: number): number
    local base = BaseWeapons[baseId]
    local raw = (base and base.BaseDamage or 4) * ItemData.LevelCurve(itemLevel) * (RarityDamageMult[rarity] or 1)
    return math.round(raw * 100) / 100
end

-- ==================== [WEAPON AFFIXES: PoE-style prefixes / suffixes with item-level tiers] ====================
-- Up to 2 prefixes (offense) + 2 suffixes (handling / utility) per weapon. Each affix rolls a tier (0.70: the rarity
-- decides the cap -- T5 / T10 / T15 -- and the odds, see AFFIX TIERS v2 below; higher tiers are rarer).
-- An affix's range at tier t = its T1 range with Min x AFFIX_TIER_LO[t] and Max x AFFIX_TIER_HI[t]
-- (increased damage: T1 4-8% ... T5 33-45%). Words = the one word a gun's name takes from its best affix,
-- by tier band (T1-2, T3-4, T5).
-- Tiers above T5 only DROP (upgrades still stop at T5). A new tier = one more entry in each list + AffixTierCap.
-- AFFIX TIERS v2 (0.70, owner: "increase the tier an item can roll to ... up to T15 ... T15 should be incredibly low
-- universally (.5% on a common, scaling up to 1.5% on the highest rarity) ... lower tiers incredibly likely, each tier up
-- decreasing in chance ... Only Transcendent+ guns can roll T15. Legendary and under caps at T5 (rare relative to that
-- rarity), and Celestial and Mythic T10"): the RARITY decides the cap and the odds (no item-level gate any more, no
-- forced T5s). Odds fall off geometrically from T1, the ratio solved per rarity so its TOP tier lands at TopTierChance.
-- (AFFIX_TIER_ILVL / AFFIX_TIER_WEIGHT are kept only for old code / tooltips that read them.)
ItemData.AFFIX_TIER_ILVL = { 1, 10, 25, 40, 55, 70, 85, 150, 250, 350, 360, 370, 380, 390, 400 }
ItemData.AFFIX_TIER_WEIGHT = { 100, 60, 30, 12, 4, 1.6, 0.6, 0.25, 0.1, 0.04, 0.02, 0.01, 0.005, 0.0025, 0.001 }
local AFFIX_TIER_LO = { 1, 2.25, 3.75, 5.75, 8.25, 9.5, 11, 12.5, 14, 15.5, 17, 18.5, 20, 21.5, 23 }
local AFFIX_TIER_HI = { 1, 1.75, 2.75, 4.0, 5.625, 6.5, 7.5, 8.5, 9.5, 10.5, 11.5, 12.5, 13.5, 14.5, 15.5 }
ItemData.AFFIX_TIER_MAX = 15
-- ITEM SCALING v2 (0.99n, vault "Loot Economy Plan" section 10, owner: "I want to mimic POE as close as possible ... youre
-- minimum using 'rare' (gold) items" -> approved: "legendary works for that"): ITEM LEVEL gates the tiers, not rarity.
-- T1-T5 roll at any item level; T6+ need the item level in TIER_ILVL (T8 = Ruin's monster levels, T15 = the very top
-- of Singularity / top maps). The rarity only nudges the odds (TopTierChance). Old items keep what they rolled.
ItemData.TIER_ILVL = { 1, 1, 1, 1, 1, 65, 82, 100, 128, 160, 200, 245, 305, 350, 385 }
function ItemData.AffixTierCap(rarity: string?, itemLevel: number?): number
    if itemLevel == nil then -- (legacy callers without an item level: the old rarity rule)
        local r = RarityRank[rarity or ""] or 1
        if r >= RarityRank.Mythic then return 10 end -- (RARITY v4: Mythic / Relic 10, else 5; the old Transcendent+ 15 is gone)
        return 5
    end
    local cap = 1
    for t, need in ipairs(ItemData.TIER_ILVL) do if itemLevel >= need then cap = t end end
    return cap
end
-- the chance of the rarity's TOP tier: 0.5% on Common .. 1.5% on Relic (linear by rank; RARITY v4: Rare 1.0%, Mythic 1.25%)
function ItemData.TopTierChance(rarity: string?): number
    local r = RarityRank[rarity or ""] or 1
    return 0.005 + 0.01 * (r - 1) / math.max(1, #Rarities - 1)
end
local tierRatio = {}
-- P(tier t) = (1 - q) q^(t-1) / (1 - q^cap): q solved so P(cap) = TopTierChance
function ItemData.AffixTierOdds(rarity: string?, itemLevel: number?): { number }
    local cap, p = ItemData.AffixTierCap(rarity, itemLevel), ItemData.TopTierChance(rarity)
    local key = tostring(rarity) .. "#" .. cap
    local q = tierRatio[key]
    if not q then
        local lo, hi = 0.01, 0.99
        for _ = 1, 50 do
            local mid = (lo + hi) / 2
            local top = (1 - mid) * mid ^ (cap - 1) / (1 - mid ^ cap)
            if top < p then lo = mid else hi = mid end
        end
        q = (lo + hi) / 2
        tierRatio[key] = q
    end
    local odds, norm = {}, (1 - q) / (1 - q ^ cap)
    for t = 1, cap do odds[t] = norm * q ^ (t - 1) end
    return odds
end
local WeaponPrefixPool = {
    { Stat = "IncreasedDamage", Min = 0.04, Max = 0.08, Words = { "Sharp", "Brutal", "Savage" } },
    { Stat = "FireRateBonus", Min = 0.03, Max = 0.06, Words = { "Quick", "Rapid", "Frenzied" } },
    { Stat = "CritChance", Min = 0.01, Max = 0.02, Words = { "Keen", "Lethal", "Assassin's" } },
    { Stat = "CritMultiplier", Min = 0.08, Max = 0.15, Words = { "Cruel", "Vicious", "Ruthless" } },
    { Stat = "WeakSpotMultiplier", Min = 0.08, Max = 0.15, Words = { "Steady", "Precise", "Deadeye" } },
    { Stat = "AilmentChance", Min = 0.06, Max = 0.12, Words = { "Charged", "Volatile", "Catalytic" } },
    { Stat = "ChainKillDamage", Min = 0.01, Max = 0.02, Words = { "Relentless", "Rampaging", "Unstoppable" } },
    { Stat = "ExecutePct", Min = 0.008, Max = 0.016, Words = { "Merciless", "Culling", "Reaping" } },
    { Stat = "PierceDamage", Min = 0.06, Max = 0.12, Words = { "Piercing", "Penetrating", "Armor-Piercing" }, Requires = "Pierce" },
}
local WeaponSuffixPool = {
    { Stat = "MagSizeBonus", Min = 0.06, Max = 0.12, Words = { "Loaded", "Drum-Fed", "Bottomless" } },
    { Stat = "ReloadSpeedBonus", Min = 0.05, Max = 0.10, Words = { "Nimble", "Swift", "Blurred" } },
    -- (owner 2026-10-04: recoil affixes made no sense -- recoil is a setting. Old RecoilControl rolls become this.)
    { Stat = "AilmentDuration", Min = 0.06, Max = 0.12, Words = { "Lingering", "Enduring", "Everlasting" } },
    { Stat = "LifeLeech", Min = 0.004, Max = 0.008, Words = { "Thirsty", "Leeching", "Vampiric" } },
    { Stat = "StreakDamageBonus", Min = 0.005, Max = 0.01, Words = { "Focused", "Zealous", "Fanatic" } },
    { Stat = "LootLuck", Min = 0.03, Max = 0.06, Words = { "Lucky", "Fortunate", "Blessed" } },
    { Stat = "OverkillCarry", Min = 0.05, Max = 0.10, Words = { "Carrying", "Overflowing", "Torrential" } },
}
local AffixDefByStat: { [string]: any } = {}
for _, a in ipairs(WeaponPrefixPool) do a.Kind = "Prefix"; AffixDefByStat[a.Stat] = a end
for _, a in ipairs(WeaponSuffixPool) do a.Kind = "Suffix"; AffixDefByStat[a.Stat] = a end
ItemData.WeaponPrefixPool = WeaponPrefixPool
ItemData.WeaponSuffixPool = WeaponSuffixPool
ItemData.AffixDefByStat = AffixDefByStat
-- ==================== (UPDATE 8 OFFENSE, phase 2) GUN BASES + LOCAL GUN MODS + SOCKETS ====================
-- (owner design section 6 "Guns = your skill"; docs/UPDATE8.md. OFFENSE owns this block; rarity / line counts stay LOOT's.)
do
    local okDT, DT = pcall(require, script.Parent:WaitForChild("DamageTypes"))
    ItemData.DT = okDT and DT or nil
    -- GUN BASES: each base's damage-type split (read AT USE, like GUN_TUNE: every saved gun follows it, no migration; a
    -- gun item may carry its own weapon.DamageTypes, which wins). Unlisted = all Kinetic.
    ItemData.GUN_TYPES = {
        BEAM = { Kinetic = 0.3, Volt = 0.7 },              -- Arc Projector
        ContinuousLaser = { Kinetic = 0.3, Heat = 0.7 },   -- Helios Thermal Beam
        QuadBeam = { Kinetic = 0.4, Volt = 0.6 },          -- Tesla Quadbeam
        Railgun = { Kinetic = 0.6, Volt = 0.4 },           -- Hyperion Particle Railgun
        PlasmaCannon = { Kinetic = 0.2, Heat = 0.5, Volt = 0.3 }, -- Ion Arc Plasma Accelerator
        VoidDisintegrator = { Kinetic = 0.4, Void = 0.6 },  -- Quantum Void Disintegrator
        SparkPistol = { Kinetic = 0.5, Volt = 0.5 },
        DBARREL = { Kinetic = 0.75, Heat = 0.25 },         -- incendiary shells
        M82 = { Kinetic = 0.85, Heat = 0.15 },             -- incendiary rounds
        PPSH = { Kinetic = 0.85, Cryo = 0.15 },            -- frost-rimed drum
        SKS = { Kinetic = 0.85, Void = 0.15 },             -- corroded rounds
    }
    function ItemData.GunTypes(w: any): { [string]: number }?
        if type(w) == "table" and type(w.DamageTypes) == "table" then return w.DamageTypes end
        local id = type(w) == "table" and w.BaseId or w
        return id and ItemData.GUN_TYPES[id] or nil
    end

    -- LOCAL GUN MODS (new drops; old items keep their lines until WIPE 5 -- the old pools stay registered for names,
    -- tuning and tooltips). Prefixes: added Heat / Cryo / Volt / Void ON THIS GUN (a share of its own base hit, so it
    -- grows with item level and upgrades), increased Kinetic on this gun (local: multiplies the gun's Kinetic base),
    -- increased Elemental, a hybrid (Kinetic + crit). Suffixes: fire rate, crit, crit damage, reload, magazine,
    -- weak-spot damage, ailment chance per type. Values x AFFIX_TIER_LO / HI by tier (AffixTierCap / TIER_ILVL).
    -- Sized against the old pools with tools/sim/classbal (docs: CLAUDE.md UPDATE 8).
    ItemData.LegacyWeaponPrefixPool = table.clone(WeaponPrefixPool)
    ItemData.LegacyWeaponSuffixPool = table.clone(WeaponSuffixPool)
    ItemData.GUN_MOD_SCALE = 0.3 -- (one knob on every new local gun mod's value)
    local K = ItemData.GUN_MOD_SCALE
    local NEW_PREFIX = {
        { Stat = "LocalAddedHeat", Min = 0.03 * K, Max = 0.06 * K, Words = { "Smouldering", "Searing", "Blazing" } },
        { Stat = "LocalAddedCryo", Min = 0.03 * K, Max = 0.06 * K, Words = { "Chilled", "Frigid", "Glacial" } },
        { Stat = "LocalAddedVolt", Min = 0.03 * K, Max = 0.06 * K, Words = { "Humming", "Crackling", "Thunderous" } },
        { Stat = "LocalAddedVoid", Min = 0.03 * K, Max = 0.06 * K, Words = { "Hollow", "Tainted", "Abyssal" } },
        { Stat = "LocalKinetic", Min = 0.04 * K, Max = 0.08 * K, Words = { "Heavy", "Brutal", "Savage" } },
        { Stat = "ElementalDamage", Min = 0.05 * K, Max = 0.10 * K, Words = { "Charged", "Volatile", "Catalytic" } },
        { Stat = "HybridKineticCrit", Min = 0.03 * K, Max = 0.06 * K, Words = { "Honed", "Whetted", "Razor" } },
    }
    local NEW_SUFFIX = {
        { Stat = "FireRateBonus", Min = 0.03, Max = 0.06, Words = { "Quick", "Rapid", "Frenzied" } },
        { Stat = "CritChance", Min = 0.01, Max = 0.02, Words = { "Keen", "Lethal", "Assassin's" } },
        { Stat = "CritMultiplier", Min = 0.08, Max = 0.15, Words = { "Cruel", "Vicious", "Ruthless" } },
        { Stat = "ReloadSpeedBonus", Min = 0.05, Max = 0.10, Words = { "Nimble", "Swift", "Blurred" } },
        { Stat = "MagSizeBonus", Min = 0.06, Max = 0.12, Words = { "Loaded", "Drum-Fed", "Bottomless" } },
        { Stat = "WeakSpotMultiplier", Min = 0.08, Max = 0.15, Words = { "Steady", "Precise", "Deadeye" } },
        { Stat = "BleedChance", Min = 0.015, Max = 0.03, Words = { "Jagged", "Serrated", "Flaying" } },
        { Stat = "BurnChance", Min = 0.015, Max = 0.03, Words = { "Kindled", "Scorching", "Infernal" } },
        { Stat = "ChillChance", Min = 0.015, Max = 0.03, Words = { "Rimed", "Freezing", "Arctic" } },
        { Stat = "ShockChance", Min = 0.015, Max = 0.03, Words = { "Static", "Arcing", "Tempest" } },
        { Stat = "WitherChance", Min = 0.015, Max = 0.03, Words = { "Rotting", "Withering", "Ruinous" } },
    }
    table.clear(WeaponPrefixPool); table.clear(WeaponSuffixPool)
    for _, a in ipairs(NEW_PREFIX) do a.Kind = "Prefix"; table.insert(WeaponPrefixPool, a); AffixDefByStat[a.Stat] = a end
    for _, a in ipairs(NEW_SUFFIX) do a.Kind = "Suffix"; table.insert(WeaponSuffixPool, a); AffixDefByStat[a.Stat] = a end
    ItemData.NEW_GUN_PREFIX, ItemData.NEW_GUN_SUFFIX = NEW_PREFIX, NEW_SUFFIX
    ItemData.HYBRID_CRIT = 0.25 -- (HybridKineticCrit: x of its value also counts as crit chance)
    -- labels (player text; placeholder type names)
    local SD = {
        LocalAddedHeat = { Label = "Added Heat (of the gun's base hit)", Kind = "pct", Prefix = "Searing", Noun = "Embers", Desc = "Adds Heat damage to this gun's hits, a share of its base hit." },
        LocalAddedCryo = { Label = "Added Cryo (of the gun's base hit)", Kind = "pct", Prefix = "Frigid", Noun = "Frost", Desc = "Adds Cryo damage to this gun's hits, a share of its base hit." },
        LocalAddedVolt = { Label = "Added Volt (of the gun's base hit)", Kind = "pct", Prefix = "Crackling", Noun = "Sparks", Desc = "Adds Volt damage to this gun's hits, a share of its base hit." },
        LocalAddedVoid = { Label = "Added Void (of the gun's base hit)", Kind = "pct", Prefix = "Tainted", Noun = "Taint", Desc = "Adds Void damage to this gun's hits, a share of its base hit." },
        LocalKinetic = { Label = "Increased Kinetic Damage (this gun)", Kind = "pct", Prefix = "Brutal", Noun = "Force", Desc = "Raises this gun's own Kinetic damage." },
        HybridKineticCrit = { Label = "Increased Kinetic Damage (this gun), a quarter as Crit Chance", Kind = "pct", Prefix = "Keen", Noun = "Edge", Desc = "Raises this gun's Kinetic damage, and a quarter of it as crit chance." },
        ElementalDamage = { Label = "Increased Elemental Damage", Kind = "pct", Prefix = "Charged", Noun = "Charge", Desc = "Raises Heat, Cryo and Volt damage." },
        KineticDamage = { Label = "Increased Kinetic Damage", Kind = "pct" }, HeatDamage = { Label = "Increased Heat Damage", Kind = "pct" },
        CryoDamage = { Label = "Increased Cryo Damage", Kind = "pct" }, VoltDamage = { Label = "Increased Volt Damage", Kind = "pct" },
        VoidDamage = { Label = "Increased Void Damage", Kind = "pct" },
        BleedChance = { Label = "Bleed Chance", Kind = "pct", Prefix = "Lacerating", Noun = "Cuts", Desc = "Chance a hit makes the target Bleed (worse while it moves)." },
        BurnChance = { Label = "Burn Chance", Kind = "pct", Prefix = "Kindling", Noun = "Embers", Desc = "Chance a hit sets the target Burning (needs Heat damage to matter)." },
        ChillChance = { Label = "Chill Chance", Kind = "pct", Prefix = "Rimed", Noun = "Rime", Desc = "Chance a hit Chills the target (needs Cryo damage)." },
        ShockChance = { Label = "Shock Chance", Kind = "pct", Prefix = "Static", Noun = "Static", Desc = "Chance a hit Shocks the target: it takes more damage (needs Volt damage)." },
        WitherChance = { Label = "Wither Chance", Kind = "pct", Prefix = "Rotting", Noun = "Rot", Desc = "Chance a hit Withers the target: stacks of more damage taken (needs Void damage)." },
        ShockEffect = { Label = "Shock Effect", Kind = "pct" }, WitherEffect = { Label = "Wither Effect", Kind = "pct" },
    }
    for k, v in pairs(SD) do if not StatDefs[k] then StatDefs[k] = v end end

    -- SOCKETS + LINKS: item.Sockets = "R-G-B B" ('-' = linked, ' ' = a new group). Colours R / G / B tie to Strength /
    -- Dexterity / Intellect (Phase 4); for now each gun leans by type. Count + links rise with rarity and item level; a
    -- 6-link is very rare. Empty sockets for now (Phase 3 adds the shot mods).
    ItemData.SOCKETS = {
        MaxByIlvl = { { 1, 2 }, { 10, 3 }, { 25, 4 }, { 50, 5 }, { 100, 6 } }, -- { item level, max sockets }
        Min = { Common = 1, Uncommon = 1, Rare = 2, Mythic = 3, Relic = 2 }, -- sockets a fresh roll starts from (item level permitting)
        Extra = { Common = 0.30, Uncommon = 0.35, Rare = 0.40, Mythic = 0.45, Relic = 0.45 }, -- chance of each further socket
        Link = { Common = 0.35, Uncommon = 0.45, Rare = 0.55, Mythic = 0.65, Relic = 0.60 },  -- chance two neighbours are linked
        Colors = { -- { R, G, B } weights by weapon group (LMGs: heavy = Red)
            Assault = { 0.45, 0.35, 0.20 }, LMG = { 0.60, 0.20, 0.20 }, Close = { 0.20, 0.60, 0.20 }, Precision = { 0.20, 0.55, 0.25 }, -- (phase 4: colours follow the gun's attribute: R Str, G Dex, B Int)
            Shotgun = { 0.60, 0.25, 0.15 }, Beam = { 0.20, 0.20, 0.60 }, Default = { 0.34, 0.33, 0.33 },
        },
        Hex = { R = "#e2574c", G = "#5fd36a", B = "#5aa6ff" },
    }
    -- the biggest link a gun of this item level can have (crafting currencies respect it too); keep = ShotMods.MAX_LINKS
    ItemData.MAX_LINKS = { { 1, 2 }, { 10, 3 }, { 25, 4 }, { 45, 5 }, { 75, 6 } }
    function ItemData.MaxLinks(itemLevel: number?): number
        local m = 1
        for _, p in ipairs(ItemData.MAX_LINKS) do if (itemLevel or 1) >= p[1] then m = p[2] end end
        return m
    end
    function ItemData.MaxSockets(itemLevel: number?): number
        local m = 1
        for _, p in ipairs(ItemData.SOCKETS.MaxByIlvl) do if (itemLevel or 1) >= p[1] then m = p[2] end end
        return m
    end
    function ItemData.RollSockets(baseId: string?, rarity: string?, itemLevel: number?, rng: any?): string
        local S = ItemData.SOCKETS
        local r = (ItemData.NormRarity and ItemData.NormRarity(rarity)) or rarity or "Common"
        local rand = rng and function() return rng:NextNumber() end or math.random
        local max = ItemData.MaxSockets(itemLevel)
        local n = math.min(max, S.Min[r] or 1)
        while n < max and rand() < (S.Extra[r] or S.Extra.Common) do n += 1 end
        local base = baseId and BaseWeapons[baseId]
        local grp = base and (base.Class == "Heavy" and "LMG" or ItemData.WeaponGroupOf({ BaseId = baseId, Class = base.Class })) or nil
        local w = S.Colors[grp or ""] or S.Colors.Default
        local out = {}
        for i = 1, n do
            local x = rand() * (w[1] + w[2] + w[3])
            local c = (x < w[1] and "R") or (x < w[1] + w[2] and "G") or "B"
            if i > 1 then table.insert(out, (rand() < (S.Link[r] or S.Link.Common)) and "-" or " ") end
            table.insert(out, c)
        end
        -- (UPDATE 8 phase 4) links gated by item level PoE-style: ItemData.MaxLinks (= ShotMods.MAX_LINKS, 6-link from 75)
        local cap, run = ItemData.MaxLinks(itemLevel), 1
        for i = 2, #out, 2 do
            if out[i] == "-" then run += 1; if run > cap then out[i] = " "; run = 1 end else run = 1 end
        end
        return table.concat(out)
    end
    -- { { "R", "G" }, { "B" } } = the linked groups; plus socket count and the biggest link
    function ItemData.SocketGroups(s: string?): ({ { string } }, number, number)
        local groups, cur, n, big = {}, {}, 0, 0
        if type(s) ~= "string" or s == "" then return groups, 0, 0 end
        for ch in string.gmatch(s, ".") do
            if ch == "R" or ch == "G" or ch == "B" or ch == "W" then table.insert(cur, ch); n += 1
            elseif ch == " " and #cur > 0 then table.insert(groups, cur); cur = {} end
        end
        if #cur > 0 then table.insert(groups, cur) end
        for _, g in ipairs(groups) do big = math.max(big, #g) end
        return groups, n, big
    end
    -- tooltip line: plain text + a RichText version with coloured sockets
    function ItemData.SocketLine(s: string?): (string?, string?)
        local groups, n, big = ItemData.SocketGroups(s)
        if n == 0 then return nil end
        local plain, rich = {}, {}
        for _, g in ipairs(groups) do
            table.insert(plain, table.concat(g, "-"))
            local parts = {}
            for _, c in ipairs(g) do table.insert(parts, string.format('<font color="%s">●</font>', ItemData.SOCKETS.Hex[c] or "#ffffff")) end
            table.insert(rich, table.concat(parts, "-"))
        end
        local tail = string.format("  •  %d socket%s, %d-link", n, n == 1 and "" or "s", big)
        return "Sockets  " .. table.concat(plain, "  ") .. tail, "Sockets  " .. table.concat(rich, "  ") .. tail
    end
    -- the gun's base type split as player text ("70% Volt • 30% Kinetic"), nil for an all-Kinetic gun
    function ItemData.GunTypeLine(w: any): string?
        local split = ItemData.GunTypes(w)
        if not split or not ItemData.DT then return nil end
        local tot, parts = 0, {}
        for _, t in ipairs(ItemData.DT.ORDER) do tot += math.max(0, split[t] or 0) end
        if tot <= 0 then return nil end
        for _, t in ipairs(ItemData.DT.ORDER) do
            local v = math.max(0, split[t] or 0)
            if v > 0 then table.insert(parts, string.format("%d%% %s", math.round(v / tot * 100), ItemData.DT.LABEL[t])) end
        end
        return "Damage type: " .. table.concat(parts, "  •  ")
    end
end
-- ===== (UPDATE 8 OFFENSE, phase 4) ATTRIBUTES: Strength / Dexterity / Intellect (owner: the PoE way, "Intellect" -- "Focus" is the
-- hit streak). They come ONLY from the passive tree (travel nodes, class starts, notables) and gear lines; hand-placed points are
-- gone (state.Attributes / StatPoints are ignored). Each point gives a small built-in bonus (StatCalculator.ATTR_BONUS) and they
-- set REQUIREMENTS: a gun needs its weapon group's attribute and a gear base its defence's attribute by item level, a shot mod its
-- colour's attribute by mod level (R = Strength, G = Dexterity, B = Intellect). Unmet: a gun / piece can't be equipped (the
-- server says why), a socketed mod sits idle (the MODS window says why). Items already worn keep working.
do
    ItemData.ATTRS = { "Strength", "Dexterity", "Intellect" }
    ItemData.ATTR_SHORT = { Strength = "Str", Dexterity = "Dex", Intellect = "Int" }
    ItemData.ATTR_BASE = 10 -- every character starts with 10 of each
    ItemData.GROUP_ATTR = { Assault = "Strength", Shotgun = "Strength", Close = "Dexterity", Precision = "Dexterity", Beam = "Intellect" }
    ItemData.DEF_ATTR = { P = "Strength", A = "Dexterity", W = "Intellect" } -- (gear base Def letters, DEFENCE's GEAR_BASES)
    ItemData.COLOR_ATTR = { R = "Strength", G = "Dexterity", B = "Intellect" }
    -- requirement per item level: a gun 0.6, a single-defence gear base 0.5, a hybrid 0.3 of each; nothing below item level 5
    -- (sized with tools/sim/classbal: an average route of the class meets its own gun's + armour's at every level).
    -- A shot mod: ShotMods.Req (4 + 3.5 x its working level: level 1 = 8, 10 = 39, 20 = 74). DEFENCE may put
    -- Req = { Strength = k, ... } (per item level) on a GEAR_BASES entry to override its pieces.
    ItemData.REQ = { Gun = 0.6, Gear = 0.5, Hybrid = 0.3, MinIlvl = 5 }
    function ItemData.Requirements(item: any, playerLevel: number?): { [string]: number }
        local out = {}
        if type(item) ~= "table" then return out end
        local R = ItemData.REQ
        if item.Kind == "ShotMod" then
            local ok, SMod = pcall(require, script.Parent:WaitForChild("ShotMods"))
            local a, n = nil, 0
            if ok then a, n = SMod.Req(item, playerLevel) end
            if a then out[a] = n end
            return out
        end
        local il = math.floor(tonumber(item.ItemLevel) or 1)
        if il < R.MinIlvl then return out end
        if item.BaseId and ItemData.BaseWeapons[item.BaseId] then
            local a = ItemData.GROUP_ATTR[ItemData.WeaponGroupOf(item) or ""]
            if a then out[a] = math.floor(il * R.Gun) end
            return out
        end
        local base = ItemData.GearBaseOf and ItemData.GearBaseOf(item)
        if base then
            if type(base.Req) == "table" then
                for a, k in pairs(base.Req) do out[a] = math.floor(il * k) end
            elseif type(base.Def) == "string" and base.Def ~= "" then
                local k = (#base.Def >= 2) and R.Hybrid or R.Gear
                for ch in string.gmatch(base.Def, ".") do
                    local a = ItemData.DEF_ATTR[ch]
                    if a then out[a] = math.floor(il * k) end
                end
            end
        end
        return out
    end
    -- attrs = { Strength = n, ... } (CompiledStats TotalStrength ... via ItemData.AttrTotals) -> ok, "Needs 45 Strength"
    function ItemData.MeetsReq(item: any, attrs: any, playerLevel: number?): (boolean, string?)
        local miss = {}
        for _, a in ipairs(ItemData.ATTRS) do
            local need = ItemData.Requirements(item, playerLevel)[a]
            if need and need > 0 and (tonumber(attrs and attrs[a]) or 0) < need then table.insert(miss, need .. " " .. a) end
        end
        if #miss > 0 then return false, "Needs " .. table.concat(miss, " and ") end
        return true
    end
    function ItemData.AttrTotals(stats: any): { [string]: number }
        return { Strength = stats and stats.TotalStrength or 0, Dexterity = stats and stats.TotalDexterity or 0, Intellect = stats and stats.TotalIntellect or 0 }
    end
    -- tooltip line ("Requires 45 Str  •  20 Dex"), nil when there's nothing to meet
    function ItemData.ReqLine(item: any, playerLevel: number?): string?
        local req, parts = ItemData.Requirements(item, playerLevel), {}
        for _, a in ipairs(ItemData.ATTRS) do
            if (req[a] or 0) > 0 then table.insert(parts, req[a] .. " " .. ItemData.ATTR_SHORT[a]) end
        end
        return (#parts > 0) and ("Requires " .. table.concat(parts, "  •  ")) or nil
    end
    -- the attribute texts (StatDefs is shared; the old Vitality / Luck lines count as Strength / Intellect until WIPE 5)
    local SD = ItemData.StatDefs
    SD.Strength = { Label = "Strength", Kind = "points", Prefix = "Strong", Noun = "Might", Desc = "Each point: +0.1% max health and +0.2% Plating. Guns (ARs, LMGs, shotguns) and Plating gear need it." }
    SD.Dexterity = { Label = "Dexterity", Kind = "points", Prefix = "Deft", Noun = "Finesse", Desc = "Each point: +0.2% Agility and +0.02% crit chance. Guns (SMGs, pistols, DMRs, snipers) and Agility gear need it." }
    SD.Intellect = { Label = "Intellect", Kind = "points", Prefix = "Clever", Noun = "Insight", Desc = "Each point: +0.2% Ward and +0.1% elemental damage. Beam guns and Ward gear need it." }
    SD.Vitality = { Label = "Strength (old Vitality)", Kind = "points", Prefix = "Hale", Noun = "Life", Desc = "An old line: counts as Strength." }
    SD.Luck = { Label = "Intellect (old Luck)", Kind = "points", Prefix = "Charmed", Noun = "Chance", Desc = "An old line: counts as Intellect." }
    SD.AllAttributes = { Label = "All Attributes", Kind = "points", Prefix = "Balanced", Noun = "Balance", Desc = "Adds to Strength, Dexterity and Intellect." }
    -- (phase 4) the tree's area stats (they act on shot mods' extra hits: chains, forks, volleys, bursts, Detonate)
    local function Def(k, v) if not SD[k] then SD[k] = v end end
    Def("AreaDamage", { Label = "Area Damage (extra hits)", Kind = "pct", Desc = "More damage on your shot mods' extra hits: chains, forks, volleys, bursts and Detonate." })
    Def("AreaRadius", { Label = "Area Reach", Kind = "pct", Desc = "Your bursts reach wider and your chains / forks jump further." })
    Def("ExtraChains", { Label = "Extra Chain Hops", Kind = "points", Desc = "Your Chain mod hits this many more enemies." })
    Def("FreezeChance", { Label = "Freeze Build-up", Kind = "pct", Desc = "Your Cryo damage builds Freeze faster." })
    Def("MaxFocus", { Label = "Maximum Focus", Kind = "points", Desc = "More Focus stacks (hits in a row on weak spots)." })
end
-- ITEM SCALING v2 (0.99n): RARITY = HOW MANY LINES. Common 0 | Uncommon, Rare 1-2 (max 1 prefix + 1 suffix) | Epic 3-4 (2 + 2)
-- | Legendary and up 4-6 (3 + 3: the workhorse band). Above Legendary each rarity leans further toward 5-6 lines
-- (RollLineCount). Guns and gear use the same band. The tables below hold the band's MAX (UI, AffixCap); old items keep
-- every line they rolled (a Reforge keeps an old item's count).
-- RARITY v4 (UPDATE 8): Common 0 | Uncommon 1-2 (1 + 1) | Rare 3-6 (3 + 3: the workhorse) | Mythic 4-7 (4 + 4: a Rare roll + the
-- Mythic line) | Relic = a Rare's band (its signature is the relic effect). An old name not normalised yet keeps its old band.
ItemData.LINE_BAND = { Common = { 0, 0, 0 }, Uncommon = { 1, 2, 1 }, Rare = { 3, 6, 3 }, Mythic = { 4, 7, 4 }, Relic = { 3, 6, 3 },
    Epic = { 3, 4, 2 } } -- { min, max, per side }
ItemData.FULL_BAND = { 4, 6, 3 }
ItemData.RARE_LINE_WEIGHTS = { 25, 35, 28, 12 } -- (a fresh Rare: 3 / 4 / 5 / 6 lines, %)
function ItemData.LineBand(rarity: string?): (number, number, number)
    local b = ItemData.LINE_BAND[rarity or ""] or ItemData.FULL_BAND
    return b[1], b[2], b[3]
end
-- the line count a fresh roll of this rarity gets
function ItemData.RollLineCount(rarity: string?): number
    local lo, hi = ItemData.LineBand(rarity)
    if lo == hi then return lo end
    if rarity == "Rare" or rarity == "Mythic" or rarity == "Relic" then
        local w, tot = ItemData.RARE_LINE_WEIGHTS, 0
        for _, v in ipairs(w) do tot += v end
        local x, n = math.random() * tot, #w
        for i, v in ipairs(w) do
            if x < v then n = i; break end
            x -= v
        end
        return 2 + n + ((rarity == "Mythic") and 1 or 0) -- (Mythic = a Rare roll + its Mythic line)
    end
    if hi == 6 then -- (an old Legendary+ name: 4-6)
        local x = math.random() * 100
        return (x < 50) and 4 or ((x < 85) and 5 or 6)
    end
    return (math.random() < 0.6) and lo or hi -- (low / mid bands: the lower count 60%)
end
local WeaponAffixCount: { [string]: number } = {}
for _, r in ipairs(Rarities) do local _, hi = ItemData.LineBand(r); WeaponAffixCount[r] = hi end
ItemData.WeaponAffixCount = WeaponAffixCount
-- NEGATIVE AFFIXES (0.97, owner: "Add potential negative affixes, which could be rolled at anytime. This would have a way
-- lower chance than the normal affixes, and would go from T-1 to T-5 ... a bigger choice for players to pick guns or change
-- based off of the affixes" + "take a normal slot"): any affix roll (a drop or a reroll) has NEG_AFFIX_CHANCE to land a
-- penalty instead -- the same stat names with a negative value, Tier -1 (mild) .. -5 (harsh), Negative = true, no name word,
-- never raised by upgrades. Ranges = magnitude at T-1 .. T-5 (linear).
ItemData.NEG_AFFIX_CHANCE = 0.05
ItemData.NEG_AFFIX_COLOR = Color3.fromRGB(255, 92, 92)
ItemData.NEG_TIER_WEIGHT = { 45, 27, 15, 9, 4 } -- (T-1 .. T-5)
ItemData.NegativeAffixPool = {
    { Stat = "IncreasedDamage", Lo = 0.04, Hi = 0.20 },
    { Stat = "FireRateBonus", Lo = 0.03, Hi = 0.15 },
    { Stat = "CritChance", Lo = 0.01, Hi = 0.04 },
    { Stat = "WeakSpotMultiplier", Lo = 0.06, Hi = 0.25 },
    { Stat = "MagSizeBonus", Lo = 0.06, Hi = 0.25 },
    { Stat = "ReloadSpeedBonus", Lo = 0.06, Hi = 0.25 },
}
-- how many of a weapon's affixes are forced up to T5 (the best ones first) -- none since 0.70 (tiers roll by rarity)
ItemData.FORCED_T5 = {} -- (0.70 AFFIX TIERS v2: no forced T5s -- "it feels like you just start to get T5 easily")

-- ==================== [WEAPON PROC PREFIXES] ====================
-- A weapon can carry ONE proc prefix (its name leads with it: "Burning AK-47"). How often it triggers
-- depends on the gun: the fewer hits per second a weapon lands, the higher its per-hit chance, so a sniper
-- procs on a big share of its shots and a minigun on a few percent of its bullets -- every weapon type
-- ends up with a similar, moderate payoff instead of rapid-fire guns (or one-shot guns) dominating.
-- Power scales with rarity (Common 1.0 ... Transcendent ~2.0) and multiplies each effect's strength.
export type WeaponProc = { Id: string, Power: number }
local WeaponProcs: { [string]: any } = {
    Burn = { Prefix = "Burning", Element = "Fire", Chance = 0.22, Color = Color3.fromRGB(255, 130, 50),
        Summary = "Ignites enemies: damage over time." },
    Freeze = { Prefix = "Freezing", Element = "Cold", Chance = 0.22, Color = Color3.fromRGB(120, 210, 255),
        Summary = "Chills enemies: slows their movement and deals a little damage over time." },
    Bleed = { Prefix = "Bleeding", Element = "Physical", Chance = 0.22, Color = Color3.fromRGB(215, 40, 55),
        Summary = "Opens wounds: damage over time that stacks up to 3 times." },
    Decay = { Prefix = "Decaying", Element = "Chaos", Chance = 0.20, Color = Color3.fromRGB(150, 220, 70),
        Summary = "Withers enemies: they take increased damage from every source." },
    Giantslayer = { Prefix = "Giantslayer", Element = "Physical", Chance = 1.0, Color = Color3.fromRGB(255, 215, 90),
        Summary = "Executes enemies left below a health threshold (bosses are immune, elites resist)." },
    Fixation = { Prefix = "Fixated", Element = "Physical", Chance = 1.0, Color = Color3.fromRGB(255, 95, 200),
        Summary = "Hits build Fixation stacks that raise your damage; at max stacks your next hit lands a crushing blow." },
    -- (replaces the old Explosive prefix: no splash -- the same enemy takes an echo of the hit)
    Echo = { Prefix = "Echoing", Element = "Physical", Chance = 0.14, Color = Color3.fromRGB(255, 175, 60),
        Summary = "Hits can echo: the same enemy is struck again." },
}
ItemData.WeaponProcs = WeaponProcs
ItemData.WeaponProcOrder = { "Burn", "Freeze", "Bleed", "Decay", "Giantslayer", "Fixation", "Echo" }

-- ==================== [ELEMENTAL MATCHUPS] (owner 2026-10-05: "fire beats ice etc, 15% damage buff, neutral, or
-- 15% damage decrease depending on matchup") ====================
-- An enemy's TYPE = its own elemental mod (model attribute Element) or else its floor's biome. A gun's element = its
-- elemental prefix (Burning = Fire, Freezing = Cold, Decaying = Chaos, Bleeding = Bleed); every other gun is neutral.
-- Each enemy type is weak to one element (+15%) and resists one (-15%); the server applies it in the hit handler
-- (before crits), so the prefix's damage over time (a share of the hit) follows it too.
ItemData.ELEMENT_EDGE = 0.15
ItemData.ELEMENT_OF_PROC = { Burn = "Fire", Freeze = "Cold", Decay = "Chaos", Bleed = "Bleed" }
ItemData.ELEMENT_OF_BIOME = { Fire = "Fire", Ice = "Cold", Void = "Chaos", Cyber = "Bleed", Storm = "Shock", Dream = "Lucid", Flats = "Scorch" }
do -- (0.87 WORLDS: a world's enemies carry its sister biome's element)
    local ok, WB = pcall(require, script.Parent:WaitForChild("WorldBiomes"))
    if ok then for k, v in pairs(WB.Element) do ItemData.ELEMENT_OF_BIOME[k] = v end end
end
ItemData.ENEMY_AFFINITY = {
    Fire = { Weak = "Cold", Resist = "Fire", Name = "Molten" },     -- frost puts out the fire
    Cold = { Weak = "Fire", Resist = "Cold", Name = "Cryo" },       -- fire melts the ice
    Chaos = { Weak = "Bleed", Resist = "Chaos", Name = "Void" },    -- void flesh tears; decay feeds it
    Bleed = { Weak = "Chaos", Resist = "Bleed", Name = "Cyber" },   -- decay corrupts the machines; steel doesn't bleed
    Shock = { Weak = "Chaos", Resist = "Fire", Name = "Storm" },    -- decay grounds the charge; storms shrug off heat
    Lucid = { Weak = "Bleed", Resist = "Cold", Name = "Dream" },    -- (0.53) a cut wakes you up; dreams are cold
    Scorch = { Weak = "Cold", Resist = "Bleed", Name = "Flats" },   -- (0.53) cold snaps the heat; sun-baked hides don't bleed
}
ItemData.ELEMENT_WORD = { Fire = "Burning", Cold = "Freezing", Chaos = "Decaying", Bleed = "Bleeding" }
-- enemy type key from an enemy's attributes + the floor's biome
function ItemData.EnemyAffinity(elementAttr: string?, biome: string?): string?
    if elementAttr and ItemData.ENEMY_AFFINITY[elementAttr] then return elementAttr end
    return biome and ItemData.ELEMENT_OF_BIOME[biome] or nil
end
-- (multiplier, "Strong" | "Weak" | nil) for a gun's proc id against an enemy type key
function ItemData.ElementMatch(procId: string?, enemyKey: string?): (number, string?)
    local el = procId and ItemData.ELEMENT_OF_PROC[procId]
    local aff = enemyKey and ItemData.ENEMY_AFFINITY[enemyKey]
    if not (el and aff) then return 1, nil end
    if aff.Weak == el then return 1 + ItemData.ELEMENT_EDGE, "Strong" end
    if aff.Resist == el then return 1 - ItemData.ELEMENT_EDGE, "Weak" end
    return 1, nil
end
-- tooltip line: which enemies this gun's element is strong / weak against
function ItemData.DescribeElement(w: any): string?
    -- (UPDATE 8 OFFENSE: the old +-15% matchup is gone -- an elemental prefix converts part of the gun's Kinetic damage to
    -- its type, and enemies resist (or are weak to) types: DamageTypes.ENEMY_RES)
    local ok, DT = pcall(require, script.Parent:WaitForChild("DamageTypes"))
    local t = ok and w and w.Proc and DT.PROC_TYPE[w.Proc.Id]
    if not t or t == "Kinetic" then return nil end
    local strong, weak = {}, {}
    for _, k in ipairs({ "Fire", "Cold", "Chaos", "Bleed", "Shock" }) do
        local row, aff = DT.ENEMY_RES[k], ItemData.ENEMY_AFFINITY[k]
        local v = row and row[t]
        if v and v < 0 then table.insert(strong, aff.Name) end
        if v and v > 0 then table.insert(weak, aff.Name) end
    end
    local line = string.format("%d%% of Kinetic damage becomes %s", math.round(DT.PROC_CONVERT * 100), DT.LABEL[t])
    if #strong > 0 then line ..= " • " .. table.concat(strong, " / ") .. " enemies are weak to it" end
    if #weak > 0 then line ..= " • " .. table.concat(weak, " / ") .. " enemies resist it" end
    return line
end

-- Tunables (all x Power). Shared by the server's proc engine and every tooltip, so what you read is
-- exactly what happens.
ItemData.PROC = {
    BurnPct = 0.80, BurnDuration = 3.0,             -- 80% of the hit's damage, dealt over 3s
    FreezePct = 0.30, FreezeSlow = 0.30, FreezeSlowCap = 0.60, FreezeDuration = 2.5,
    BleedPct = 0.90, BleedDuration = 4.0, BleedMaxStacks = 3,
    DecayInc = 0.12, DecayCap = 0.30, DecayDuration = 4.0,
    CullBase = 0.07, CullCap = 0.20,               -- execute threshold (fraction of max health)
    FixMaxStacks = 20, FixDmgPerStack = 0.008, FixBlastPct = 1.5, FixBlastRadius = 11, FixDecay = 4.0,
    ExplodePct = 0.60, ExplodeRadius = 9, EchoPct = 0.60,
}
-- Elemental / special prefix: Rare 25%, Epic 50%, Legendary and Mythic always.
local PROC_CHANCE_BY_RARITY: { [string]: number } = {
    Relic = 1.0, -- (RARITY v4: Rare 0.25 -> 0.5)
    Common = 0, Uncommon = 0, Rare = 0.50, Epic = 0.50, Legendary = 1.0, Mythic = 1.0, Celestial = 1.0, Transcendent = 1.0,
    Astral = 1.0, Empyrean = 1.0, Primordial = 1.0, Sovereign = 1.0, Eclipse = 1.0, Genesis = 1.0, Infinite = 1.0,
}
ItemData.PROC_CHANCE_BY_RARITY = PROC_CHANCE_BY_RARITY

-- Hits per second (a shotgun blast counts as ONE hit for procs; burst rounds count individually).
function ItemData.HitsPerSecond(w: any): number
    local rate = (w and w.BaseFireRate or 1)
    local burst = math.max(1, w and w.BurstCount or 1)
    return math.max(0.2, rate * burst)
end
-- HEAVY GUNS (passive tree v4 "Heavy" stats, the Heavy Ordnance keystone, Demolisher): the heavy weapon classes AND any
-- gun that fires 3 times a second or slower -- the loot pool has no miniguns / launchers, so this is what "heavy" means
-- (AWP, M82, Scout, 870, M4 Super 90, Desert Eagle, Rhino).
ItemData.HEAVY_HPS = 3
function ItemData.IsHeavyGun(w: any): boolean
    if not w then return false end
    local c = w.Class
    return c == "Heavy" or c == "Laser" or c == "Launcher" or ItemData.HitsPerSecond(w) <= ItemData.HEAVY_HPS
end

-- >1 for slow, heavy-hitting guns; <1 for rapid-fire ones.
function ItemData.ProcRateFactor(w: any): number
    return math.clamp((2.5 / ItemData.HitsPerSecond(w)) ^ 0.6, 0.3, 3.0)
end

-- Per-hit (per-blast for shotguns) trigger chance of the weapon's proc, 0..0.75.
function ItemData.ProcChance(w: any, ailmentChanceBonus: number?): number
    local proc = w and w.Proc
    local def = proc and WeaponProcs[proc.Id]
    if not def then return 0 end
    if def.Chance >= 1 then return 1 end
    return math.clamp(def.Chance * ItemData.ProcRateFactor(w) * (1 + (ailmentChanceBonus or 0)), 0.02, 0.75)
end

-- Giantslayer execute threshold (fraction of max health).
function ItemData.CullThreshold(w: any): number
    local power = (w and w.Proc and w.Proc.Power) or 1
    local rf = math.clamp(ItemData.ProcRateFactor(w) ^ 0.5, 0.75, 1.5)
    return math.min(ItemData.PROC.CullCap, ItemData.PROC.CullBase * power * rf)
end

-- Fixation stacks gained per hit (slow guns build faster).
function ItemData.FixationGain(w: any): number
    return math.clamp(math.round(ItemData.ProcRateFactor(w)), 1, 4)
end

-- One readable line describing exactly what this weapon's prefix does (uses the same numbers the server uses).
function ItemData.DescribeProc(w: any, stats: any?): string?
    local proc = w and w.Proc
    local def = proc and WeaponProcs[proc.Id]
    if not def then return nil end
    local P = ItemData.PROC
    local pw = proc.Power or 1
    local chance = math.round(ItemData.ProcChance(w, stats and stats.AilmentChance or 0) * 100)
    local dur = 1 + (stats and stats.AilmentDuration or 0)
    local id = proc.Id
    local function pct(v: number): string return tostring(math.round(v * 100)) .. "%" end
    local rf = ItemData.ProcRateFactor(w) -- (DOT PARITY: the damage part is the hit's x pct / rf -- CombatServer RollOnHitEffects)
    if id == "Burn" then
        return string.format("%s: %d%% chance on hit to ignite for %s of the hit's damage over %.1fs", def.Prefix, chance, pct(P.BurnPct * pw / rf), P.BurnDuration * dur)
    elseif id == "Freeze" then
        return string.format("%s: %d%% chance on hit to slow by %s for %.1fs, dealing %s of the hit's damage", def.Prefix, chance, pct(math.min(P.FreezeSlowCap, P.FreezeSlow * pw)), P.FreezeDuration * dur, pct(P.FreezePct * pw / rf))
    elseif id == "Bleed" then
        return string.format("%s: %d%% chance on hit to bleed for %s of the hit's damage over %.1fs (stacks %dx)", def.Prefix, chance, pct(P.BleedPct * pw / rf), P.BleedDuration * dur, P.BleedMaxStacks)
    elseif id == "Decay" then
        return string.format("%s: %d%% chance on hit: enemy takes +%s damage from everything for %.1fs", def.Prefix, chance, pct(math.min(P.DecayCap, P.DecayInc * pw)), P.DecayDuration * dur)
    elseif id == "Giantslayer" then
        return string.format("%s: hits execute enemies below %s health (elites below half that, bosses immune)", def.Prefix, pct(ItemData.CullThreshold(w)))
    elseif id == "Fixation" then
        return string.format("%s: each hit adds %d stack(s), +%s damage per stack (max %d). At max, the next hit deals %s extra damage to its target", def.Prefix, ItemData.FixationGain(w), string.format("%.1f%%", P.FixDmgPerStack * pw * 100), P.FixMaxStacks, pct(P.FixBlastPct * pw))
    elseif id == "Echo" then
        return string.format("%s: %d%% chance on hit to strike the same enemy again for %s of the hit's damage", def.Prefix, chance, pct(P.EchoPct * pw / rf))
    end
    return nil
end

-- Rough average damage multiplier a proc adds on a single target (for DPS comparisons only).
function ItemData.ProcDpsFactor(w: any): number
    local proc = w and w.Proc
    if not proc or not WeaponProcs[proc.Id] then return 1 end
    local P = ItemData.PROC
    local pw = proc.Power or 1
    local c = ItemData.ProcChance(w, 0)
    local hps = ItemData.HitsPerSecond(w)
    local id = proc.Id
    local rf = ItemData.ProcRateFactor(w) -- (DOT PARITY: the damage part of a proc is divided by it -- CombatServer RollOnHitEffects)
    if id == "Burn" then return 1 + c * P.BurnPct * pw * 0.75 / rf
    elseif id == "Bleed" then return 1 + c * P.BleedPct * pw * 0.85 / rf
    elseif id == "Freeze" then return 1 + c * P.FreezePct * pw * 0.8 / rf
    elseif id == "Echo" then return 1 + c * P.EchoPct * pw / rf
    elseif id == "Decay" then
        local uptime = 1 - (1 - c) ^ (hps * P.DecayDuration)
        return 1 + uptime * math.min(P.DecayCap, P.DecayInc * pw)
    elseif id == "Fixation" then
        local hitsToMax = math.ceil(P.FixMaxStacks / ItemData.FixationGain(w))
        return 1 + P.FixMaxStacks * P.FixDmgPerStack * pw * 0.5 + (P.FixBlastPct * pw) / (hitsToMax + 1)
    elseif id == "Giantslayer" then return 1 + ItemData.CullThreshold(w)
    end
    return 1
end

local function RollProc(rarity: string): WeaponProc?
    if math.random() >= (PROC_CHANCE_BY_RARITY[rarity] or 0) then return nil end
    local order = ItemData.WeaponProcOrder
    local id = order[math.random(1, #order)]
    local power = AffixTier(rarity) * (0.9 + math.random() * 0.2)
    return { Id = id, Power = math.round(power * 100) / 100 }
end
ItemData.RollProc = RollProc

ItemData._StatWarned = {}
local function RoundStat(stat: string, value: number): number
    -- (FUTURE-PROOF 2026-10-25) a negative value keeps its sign (math.max(step, ...) turned a -5% line into +1%), and a stat with no
    -- StatDefs row is reported in Studio: it rounds like a flat stat (a NEW 5% line without its row would become +100%)
    if value < 0 then return -RoundStat(stat, -value) end
    local def = StatDefs[stat]
    if not def and not ItemData._StatWarned[stat] and game:GetService("RunService"):IsStudio() then
        ItemData._StatWarned[stat] = true
        warn("[ItemData] stat '" .. tostring(stat) .. "' has no StatDefs row: rounded as a flat stat (add its row with Kind)")
    end
    if def and def.Kind == "pct" then
        local step = (stat == "StreakDamageBonus") and 0.005 or ((stat == "HPRegenPct" or stat == "LifeLeech") and 0.001 or 0.01)
        return math.max(step, math.round(value / step) * step)
    elseif def and def.Kind == "points" then
        return math.max(1, math.round(value))
    end
    return math.max(1, math.round(value))
end

-- (ITEM SCALING v2) a line rolled in the top 3% of its tier's range is PERFECT: a star after its tier in tooltips
ItemData.PERFECT_ROLL = 0.97
function ItemData.PerfectMark(a: any): string
    return (type(a) == "table" and not a.Negative and (tonumber(a.Roll) or 0) >= ItemData.PERFECT_ROLL) and "  ★" or ""
end
local function RollAffixes(pool: { any }, count: number, rarity: string, itemLevel: number): { Affix }
    local tier = AffixTier(rarity)
    local copy = table.clone(pool)
    local out: { Affix } = {}
    for _ = 1, count do
        if #copy == 0 then break end
        local raw = table.remove(copy, math.random(1, #copy))
        local t = ItemData.RollAffixTier(itemLevel, rarity) -- (0.70 gear tiers)
        local pos = math.random()
        local v = (raw.Min + pos * (raw.Max - raw.Min)) * tier * ItemData.GearTierMult(t)
        local def = StatDefs[raw.Stat]
        if def and def.Kind == "flat" then v *= ItemData.LevelCurve(itemLevel) else v *= ItemData.GearLevelScale(itemLevel) end
        table.insert(out, { Id = raw.Stat, Name = def and def.Prefix or raw.Stat, Stat = raw.Stat, Value = RoundStat(raw.Stat, v), Tier = t, Roll = math.round(pos * 100) / 100 })
    end
    return out
end

-- Highest affix tier this item level can roll.
function ItemData.MaxAffixTier(itemLevel: number?): number
    local t = 1
    for i, need in ipairs(ItemData.AFFIX_TIER_ILVL) do
        if (itemLevel or 1) >= need then t = i end
    end
    return t
end

local function RollTier(itemLevel: number, rarity: string?): number
    local odds = ItemData.AffixTierOdds(rarity, itemLevel or 1)
    local r = math.random()
    for t = 1, #odds do
        r -= odds[t]
        if r <= 0 then return t end
    end
    return 1
end
ItemData.RollAffixTier = RollTier
-- GEAR lines (0.70, owner: "despite your levels, the values stay pretty similar ... it should scale upwards, start low
-- and go up, just dont make them too overpowered as gear is true values"): every line rolls a tier like a weapon affix
-- (a gentler step: +8% a tier, T15 x2.12) and percent / attribute lines grow with item level (x0.6 at 1 .. x2.2 at 400;
-- flat lines keep the level curve). The gear stat ceilings (StatCalculator GEAR_CEILINGS) still bound the totals.
function ItemData.GearTierMult(t: number?): number return 1 + 0.08 * ((t or 1) - 1) end
function ItemData.GearLevelScale(itemLevel: number?): number -- (FUTURE-PROOF: clamps at MAX_LEVEL_BUILT, the curve's 400 reference kept)
    return 0.6 + 1.6 * (math.clamp(tonumber(itemLevel) or 1, 1, ItemData.MAX_LEVEL_BUILT) / 400) ^ 0.75
end

-- Value of an affix at a tier; pos (0..1) = where in that tier's range it landed (kept when the tier
-- is raised by upgrades, rerolled by a Tuning Kit).
-- (FUTURE-PROOF 2026-10-25) a tier past the tables (a NEW T16+ in TIER_ILVL) carries on their last step instead of nil arithmetic
function ItemData.AffixTierLo(t: number): number
    local n = #AFFIX_TIER_LO
    if t <= n then return AFFIX_TIER_LO[math.max(1, t)] end
    return AFFIX_TIER_LO[n] + (AFFIX_TIER_LO[n] - AFFIX_TIER_LO[n - 1]) * (t - n)
end
function ItemData.AffixTierHi(t: number): number
    local n = #AFFIX_TIER_HI
    if t <= n then return AFFIX_TIER_HI[math.max(1, t)] end
    return AFFIX_TIER_HI[n] + (AFFIX_TIER_HI[n] - AFFIX_TIER_HI[n - 1]) * (t - n)
end
local function AffixValue(def: any, tier: number, pos: number): number
    local lo, hi = def.Min * ItemData.AffixTierLo(tier), def.Max * ItemData.AffixTierHi(tier)
    return RoundStat(def.Stat, lo + (hi - lo) * pos)
end

local function MakeAffix(def: any, tier: number, pos: number?): Affix
    local roll = pos or math.random()
    return {
        Id = def.Stat, Stat = def.Stat, Name = StatDefs[def.Stat] and StatDefs[def.Stat].Label or def.Stat,
        Value = AffixValue(def, tier, roll), Tier = tier, Roll = math.round(roll * 100) / 100,
    } :: any
end
ItemData.MakeAffix = MakeAffix -- (UPDATE 7 Riftmods)
-- a penalty affix (NEGATIVE AFFIXES): avoid = stats already on the gun (a penalty never sits on a stat it also boosts)
local function MakeNegativeAffix(avoid: { [string]: boolean }?): Affix?
    local bag = {}
    for _, d in ipairs(ItemData.NegativeAffixPool) do if not (avoid and avoid[d.Stat]) then table.insert(bag, d) end end
    if #bag == 0 then return nil end
    local def = bag[math.random(1, #bag)]
    local w, total = ItemData.NEG_TIER_WEIGHT, 0
    for _, v in ipairs(w) do total += v end
    local r, t = math.random() * total, 1
    for i, v in ipairs(w) do r -= v; if r <= 0 then t = i; break end end
    local roll = math.random()
    local lo = def.Lo + (def.Hi - def.Lo) * (t - 1) / 5
    local hi = def.Lo + (def.Hi - def.Lo) * t / 5
    return {
        Id = def.Stat, Stat = def.Stat, Name = StatDefs[def.Stat] and StatDefs[def.Stat].Label or def.Stat,
        Value = -RoundStat(def.Stat, lo + (hi - lo) * roll), Tier = -t, Roll = math.round(roll * 100) / 100, Negative = true,
    } :: any
end
ItemData.MakeNegativeAffix = MakeNegativeAffix -- (UPDATE 7 Riftmods)
ItemData.MakeNegativeAffix = MakeNegativeAffix

-- A weapon's prefixes and suffixes: `count` affixes (default: by rarity), at most 2 of each kind, no stat
-- twice. Each affix's tier rolls from its rarity's odds (AffixTierOdds).
local function RollWeaponAffixSet(rarity: string, itemLevel: number, count: number?, baseId: string?): ({ Affix }, { Affix })
    local n = count or ItemData.RollLineCount(rarity)
    local _, _, sideMax = ItemData.LineBand(rarity)
    local half = math.max(sideMax, math.ceil(n / 2)) -- (ITEM SCALING v2: the band's per-side max; a legacy count keeps its room)
    local prefixes, suffixes = {}, {}
    -- (Requires = "Pierce": only on guns that pierce)
    local pierces = baseId ~= nil and BaseWeapons[baseId] ~= nil and BaseWeapons[baseId].Pierce ~= nil
    local function Bag(pool)
        local out = {}
        for _, d in ipairs(pool) do if not d.Requires or (d.Requires == "Pierce" and pierces) then table.insert(out, d) end end
        return out
    end
    local pBag, sBag = Bag(WeaponPrefixPool), Bag(WeaponSuffixPool)
    for _ = 1, n do
        local takePrefix: boolean
        if #prefixes >= half or #pBag == 0 then takePrefix = false
        elseif #suffixes >= half or #sBag == 0 then takePrefix = true
        else takePrefix = math.random() < 0.5 end
        local bag = takePrefix and pBag or sBag
        if #bag == 0 then break end
        local neg = math.random() < ItemData.NEG_AFFIX_CHANCE and MakeNegativeAffix((function()
            local used = {}
            for _, list in ipairs({ prefixes, suffixes }) do for _, a in ipairs(list) do used[a.Stat] = true end end
            return used
        end)()) or nil
        if neg then
            table.insert(takePrefix and prefixes or suffixes, neg) -- (takes the slot)
        else
            local def = table.remove(bag, math.random(1, #bag))
            table.insert(takePrefix and prefixes or suffixes, MakeAffix(def, RollTier(itemLevel, rarity)))
        end
    end
    -- a positive affix rolled after a penalty may share its stat: the penalty moves to a stat the gun doesn't boost
    do
        local pos = {}
        for _, list in ipairs({ prefixes, suffixes }) do for _, a in ipairs(list) do if not a.Negative then pos[a.Stat] = true end end end
        for _, list in ipairs({ prefixes, suffixes }) do
            for i, a in ipairs(list) do
                if a.Negative and pos[a.Stat] then
                    local fresh = MakeNegativeAffix(pos)
                    if fresh then list[i] = fresh else table.remove(list, i) end
                end
            end
        end
    end
    local forced = ItemData.FORCED_T5[rarity] or 0
    if forced > 0 then
        local all: { any } = {}
        for _, list in ipairs({ prefixes, suffixes }) do
            for _, a in ipairs(list) do table.insert(all, a) end
        end
        table.sort(all, function(x, y) return (x.Tier or 1) > (y.Tier or 1) end)
        for i = 1, math.min(forced, #all) do
            local a = all[i]
            if not a.Negative and (a.Tier or 1) < 5 then
                local fresh = MakeAffix(AffixDefByStat[a.Stat], 5)
                for k, v in pairs(fresh :: any) do a[k] = v end
            end
        end
    end
    return prefixes, suffixes
end
ItemData.RollWeaponAffixSet = RollWeaponAffixSet
ItemData.WeaponAffixPools = function() return WeaponPrefixPool, WeaponSuffixPool end -- (UPDATE 7 Riftmods)

-- The one word a gun's name takes from an affix (by tier band).
function ItemData.AffixWord(a: any): string?
    if a and a.Negative then return nil end -- (penalties don't name the gun)
    local def = a and AffixDefByStat[a.Stat]
    if not def then return nil end
    local t = a.Tier or 1
    return def.Words[(t >= 5) and 3 or ((t >= 3) and 2 or 1)]
end

-- Mythic and higher weapons with a unique trait carry hand-made names, keyed by the trait.
ItemData.MythicNames = {
    Singularity = "Event Horizon", Supernova = "Sunfall", ChainLightning = "Stormcaller",
    TemporalStasis = "Eventide", VampiricSoul = "Bloodmoon", HyperBeam = "Final Hour",
    Guillotine = "Headsman", Overflow = "Floodgate", Bloodhound = "Pack Leader", HuntersFocus = "Quarry",
    MarrowTap = "Marrowmaw", PhantomRound = "Wraithshot",
}

-- Names stay short: model, plus one word from the elemental prefix or the best affix. Mythics use their own name.
local function WeaponName(baseId: string, prefixes: { Affix }?, proc: WeaponProc?, suffixes: { Affix }?, mythicName: string?): string
    if mythicName then return mythicName end
    local base = BaseWeapons[baseId]
    local short = base and base.ShortName or baseId
    if proc and WeaponProcs[proc.Id] then
        return WeaponProcs[proc.Id].Prefix .. " " .. short
    end
    local best: any = nil
    for _, list in ipairs({ prefixes or {}, suffixes or {} }) do
        for _, a in ipairs(list) do
            if AffixDefByStat[a.Stat] and (not best or (a.Tier or 1) > (best.Tier or 1)) then best = a end
        end
    end
    local word = ItemData.AffixWord(best)
    return word and (word .. " " .. short) or short
end
ItemData.WeaponName = WeaponName

-- Drop odds. Base shares (luck 1) per rarity. Luck (character Luck, difficulty, elite / boss kills) shifts weight
-- toward the top. maxRank caps the roll (ItemData.MaxRarityRank by difficulty): true = up to Mythic (old callers),
-- a number = that rank, nil / false = Legendary. Celestial is ~5x rarer than Mythic, Transcendent ~5x rarer again.
-- (2026-10-02: Legendaries / Mythics came far too fast -- shares cut and high tiers made less luck-sensitive)
-- DROPS v3 (owner 2026-10-05: "we need to rethink about drop percentages both factoring base luck and future luck"):
-- simulated per tier (scratchpad dropsim: runs of each tier at its monster level, real drop rules) for an average
-- character -- first Legendary ~3 h on Easy -> ~20 min on Oblivion -> ~10 min on Singularity; Mythic ~25 h on Brutal ->
-- ~8 h Oblivion -> ~2 h Singularity; Celestial ~55 h Torment -> ~30 h Oblivion -> ~7 h Singularity; Transcendent ~200 h
-- Oblivion -> ~40 h Singularity. Luck = your LuckMultiplier x the difficulty's luck (DifficultyLoot.Luck, gentler now: 1 ..
-- 10) x the kill's bonus (bosses); the rarest tiers have the steepest exponents, so luck matters most where it should,
-- and the old clamp of 40 (every top tier hit it, so character luck stopped mattering there) is gone.
ItemData.RarityBaseShare = { 57.5, 30.5, 9.4, 2.0, 0.3, 0.0095, 0.0016, 0.00016 }
local RarityLuckExp = { -0.6, 0, 0.6, 0.8, 0.95, 1.25, 1.45, 1.65 }
-- RARITY LADDER v2 (0.51, owner: "if you farm easy, a common is most likely to drop, with a small chance of a rarer tier
-- ... the highest level of loot for your current stage should NEVER be guaranteed ... The lower tier loot should get
-- progressively rarer and rarer, until they are out of the pool ... the highest rarity items for each difficulty should
-- always be incredibly rare"): the roll is a WINDOW under the difficulty's top rarity (cap = MaxRarityRank). Share by
-- distance below the top (WINDOW_SHARE[1] = the top itself); shares below rank 1 fold into rank 1, so easy tiers are
-- mostly Common. Luck (character x the drop's context, e.g. bosses) leans the top three steps up a little (LUCK_EXP).
-- GEAR PACE (0.72, owner: "the gear progression might be a little bit too fast right now, im already almost past
-- transcendent in a matter of days"): the top step 0.5% -> 0.25% and the next 5% -> 2.5%, and luck leans on them less
-- (1.0 / 0.6 -> 0.8 / 0.5). With CombatServer.TOP_FLOOR_SHIFT a top-2 item comes ~2-4x slower from normal drops and
-- bosses, ~8x slower from superbosses.
ItemData.WINDOW_SHARE = { 0.0025, 0.025, 0.25, 0.40, 0.22, 0.075 } -- (pre-0.99n window, unused: see RARITY LADDER v3)
ItemData.WINDOW_TAIL = 0.5
-- ==================== RARITY LADDER v3 (fixes 2026-10-16 #12, 0.99n) ====================
-- Owner: "I dont think it should scale with levels as it does now ... as you level, the rarities just start to feel
-- meaningless. Getting a rare drop doesnt feel good or like an accomplishment, but rather just a guarantee ... even at the
-- highest difficulty or in maps, getting rarity 15 item would be insanely rare". The old window slid up one rarity per
-- difficulty (the tier's 4th-best rarity was its commonest drop) and level luck added up to x1.6 inside a tier.
-- NOW ONE FIXED LADDER: every rarity has one base weight (RARITY_STEP = how many times rarer each step is than the one
-- below); the AREA only nudges it -- the difficulty's RARITY_AREA (Easy 1 .. Singularity 10) ^ (AREA_EXP x (rank - 1)),
-- so a step up leans hardest on the top rarities; luck (character x the drop's source: bosses, chests, FloorLuck) the
-- same way with LUCK_EXP_V3; your level adds nothing (LevelLuck = 1). The difficulty's cap stays (MaxRarityRank). Base odds
-- (Easy, luck 1): Common 1 in 2, Rare 1 in 10, Legendary 1 in 136, Mythic 1 in 1.6K, Transcendent 1 in 59K, Infinite 1 in
-- 35M. Simulated (scratchpad raritysim: items / hour per tier from the drop code, 24 floors an hour, average sources):
-- first Legendary ~1.3 h on Brutal, Mythic ~11 h on Nightmare, Transcendent ~150 h on Cataclysm; on Singularity a Mythic
-- every ~2 h, Transcendent ~21 h, Infinite ~980 h. Drops there: Common 40% / Uncommon 32% / Rare 17% / Epic 8% / Legendary 3%.
-- ==================== RARITY v4 ODDS (UPDATE 8; tools/sim/raritysim.py -- keep its STEP / AREA_EXP / LUCK_EXP / MYTHIC_FROM
-- equal to these) ====================
-- Four rollable rarities (Relic never rolls): Common -> Uncommon -> Rare -> Mythic, each step RARITY_STEP times rarer than the
-- one below at Easy / luck 1 (Rare 1 in 27 of a plain drop); the AREA (RARITY_AREA by difficulty) ^ (AREA_EXP x (rank - 1))
-- leans the upper steps (Rare x1.7 on Torment .. x5 on Singularity; Mythic x2.8 .. x11); luck the same way with LUCK_EXP_V3.
-- The cap is MaxRarityRank (Mythic from Torment). Simulated (the LOOT STREAM: packs, ~16 floors an hour, avg sources):
-- first Rare ~25 min on Easy, ~9 min Nightmare, ~3 min Singularity (~2.4 .. 20 Rares an hour, 3-10% of drops); first Mythic
-- ~11 h on Torment, ~7 h Oblivion, ~3 h Singularity (1 in ~1.9K .. 620 drops). Without packs: the same Mythic hours (fodder
-- rolls x0.65 a step), fewer Commons.
ItemData.RARITY_STEP = { 2.2, 8.0, 130 } -- (rank r -> r + 1; RARITY v4, was 14 steps)
ItemData.RARITY_AREA = { Easy = 1.0, Normal = 1.2, Hard = 1.4, Brutal = 1.7, Nightmare = 2.1, Torment = 2.7, Cataclysm = 3.4,
    Oblivion = 4.2, Ruin = 4.9, Dread = 5.7, Apocalypse = 6.6, Annihilation = 7.6, Eternity = 8.7, Singularity = 10.0, Endless = 2.1 }
ItemData.AREA_EXP = 0.35 -- (RARITY v4: was 0.16 over 14 steps)
ItemData.LUCK_EXP_V3 = 0.10
local RARITY_BASE = { 1 }
for i, st in ipairs(ItemData.RARITY_STEP) do RARITY_BASE[i + 1] = RARITY_BASE[i] / st end
ItemData.RARITY_BASE = RARITY_BASE
-- the OLD 15-step ladder's weights: only GemData's legacy roll (ItemData.LegacyRollRarity) still reads them
ItemData.LEGACY_STEP = { 1.9, 3.0, 3.2, 4.2, 12, 6, 6, 4.5, 3.2, 2.6, 2.3, 2.0, 1.9, 1.8 }
ItemData.LEGACY_BASE = { 1 }
for i, st in ipairs(ItemData.LEGACY_STEP) do ItemData.LEGACY_BASE[i + 1] = ItemData.LEGACY_BASE[i] / st end
-- a roll's AREA key: a difficulty / run key string (its cap is that difficulty's MaxRarityRank), or a cap number (old callers:
-- the area is Easy, or MYTHIC_FROM when the cap reaches Mythic). Returns cap, area tier.
function ItemData.RollCap(maxRank: any, areaKey: string?): (number, string)
    if type(maxRank) == "string" then
        return ItemData.MaxRarityRank(maxRank), ItemData.ParseRunKey(maxRank) or "Easy"
    end
    local cap = (maxRank == true and 4) or (type(maxRank) == "number" and maxRank) or 3
    cap = math.clamp(cap, 1, 4) -- (Relic never rolls)
    local tier = areaKey and ItemData.ParseRunKey(areaKey) or ((cap >= 4) and ItemData.MYTHIC_FROM or "Easy")
    return cap, tier
end
-- weights (not normalised) for ranks 1..cap. maxRank / areaKey: see RollCap.
function ItemData.RarityWindow(luckMultiplier: number?, maxRank: any, areaKey: string?): { [number]: number }
    local luck = math.clamp(luckMultiplier or 1.0, 0.5, 8)
    local cap, tier = ItemData.RollCap(maxRank, areaKey)
    local area = ItemData.RARITY_AREA[tier or "Easy"] or 1
    local shares = {}
    local scarce = ItemData.Scarce()
    local B = scarce and RARITY_BASE or (ItemData.RARITY_BASE_BEFORE or RARITY_BASE) -- (LOOT SCARCITY A/B: the old Mythic step)
    for r = 1, cap do
        shares[r] = B[r] * area ^ (ItemData.AREA_EXP * (r - 1)) * luck ^ (ItemData.LUCK_EXP_V3 * (r - 1))
    end
    -- (LOOT SCARCITY 2026-11-07) Rare+ weights x RareGate on the early tiers -- a Rare is an event there
    local gate = scarce and ItemData.LOOT_SCARCITY.RareGate[tier or "Easy"] or 1
    if gate ~= 1 then for r = 3, cap do shares[r] *= gate end end
    return shares
end
-- 1 in N for one rarity on a difficulty (luck 1): the drop feed, tooltips. maxRank / areaKey: see RollCap.
function ItemData.RarityOneIn(rank: number, maxRank: any, areaKey: string?): number
    local w = ItemData.RarityWindow(1, maxRank, areaKey)
    local total = 0
    for _, v in pairs(w) do total += v end
    local x = w[rank]
    return (x and x > 0) and (total / x) or math.huge
end
-- the OLD ladder's roll, for the skill-tree gems only (GemData): cap = LegacyMaxRarityRank, area = that tier
function ItemData.LegacyRollRarity(luckMultiplier: number?, cap: number?): string
    local L = ItemData.LEGACY_RARITIES
    local c = math.clamp(cap or 5, 1, #L)
    local tier = ItemData.DifficultyOrder[math.clamp(c - 1, 1, #ItemData.DifficultyOrder)]
    local area = ItemData.RARITY_AREA[tier or "Easy"] or 1
    local luck = math.clamp(luckMultiplier or 1.0, 0.5, 8)
    local w, tot = {}, 0
    for r = 1, c do
        w[r] = ItemData.LEGACY_BASE[r] * area ^ (0.16 * (r - 1)) * luck ^ (0.10 * (r - 1))
        tot += w[r]
    end
    local x = math.random() * tot
    for r = 1, c do
        x -= w[r]
        if x <= 0 then return L[r] end
    end
    return L[1]
end
-- the rarity a player realistically WEARS by the end of a tier: the best rarity they'd have ~8 of (one per slot), counting
-- the drops of every tier so far over the hours it takes to level through each one (LEVEL_MINUTES; scratchpad typical.py)
-- -- the gear model enemies are anchored to (DevCmd treesim "+GEAR" / powercurve). Index = difficulty.
-- (the old model was the tier's commonest drop = its top - 3: 1 1 1 2 3 4 5 6 7 8 9 10 11 12)
-- (RARITY v4: the 5-rarity model -- Uncommon on Normal / Hard, a full set of Rares from Brutal (the stream gives several an
-- hour), Mythics never typical (a chase drop). Was 1 1 2 3 4 4 5 5 5 6 6 6 7 7 on the old ladder: Phase 6 re-runs powercurve.)
ItemData.TYPICAL_GEAR_RANK = { 1, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3 }
function ItemData.TypicalGearRank(level: number?): number
    local d = math.clamp(table.find(ItemData.DifficultyOrder, ItemData.TierForLevel(level)) or 1, 1, #ItemData.TYPICAL_GEAR_RANK)
    return ItemData.TYPICAL_GEAR_RANK[d]
end
-- LEVEL LUCK (0.91) is gone with the ladder (owner: rarity should not scale with your level): always 1, kept for callers.
function ItemData.LevelLuck(_level: number?, _difficulty: string?): number
    return 1
end
-- maxRank: a difficulty / run key (RARITY v4: its cap AND its area -- pass this), or a cap number (see ItemData.RollCap)
local function RollRarity(luckMultiplier: number?, maxRank: any, areaKey: string?): string
    local shares = ItemData.RarityWindow(luckMultiplier, maxRank, areaKey)
    local weights, total = {}, 0
    for i = 1, #Rarities do
        weights[i] = shares[i] or 0
        total += weights[i]
    end
    local roll = math.random() * total
    local accum = 0
    for i, w in ipairs(weights) do
        accum += w
        if roll <= accum then return Rarities[i] end
    end
    return "Common"
end
ItemData.RollRarity = RollRarity

local function BuildWeapon(baseId: string, rarity: string, itemLevel: number, prefixes: { Affix }, uid: string?, proc: WeaponProc?, suffixes: { Affix }?): WeaponInstance
    local base = BaseWeapons[baseId]
    -- a unique trait is RARE (ItemData.TRAIT_CHANCE); a Mythic with one takes the trait's own name
    local uniqueTrait: UniqueTrait? = nil
    if math.random() < (ItemData.TRAIT_CHANCE[rarity] or 0) then
        uniqueTrait = ItemData.RollTrait()
    end
    local mythicName = ((RarityRank[rarity] or 1) >= RarityRank.Mythic and uniqueTrait) and ItemData.MythicNames[uniqueTrait.Id] or nil -- (RARITY v4: Mythic / Relic)
    return {
        Uid = uid or ("W_" .. math.random(10000000, 99999999)),
        BaseId = baseId,
        Name = WeaponName(baseId, prefixes, proc, suffixes, mythicName),
        MythicName = mythicName,
        Class = base.Class,
        Rarity = rarity,
        UpgradeLevel = 0,
        TierBumps = 0,
        ItemLevel = itemLevel,
        BaseDamage = ItemData.WeaponDamageAt(baseId, rarity, itemLevel),
        Sockets = ItemData.RollSockets and ItemData.RollSockets(baseId, rarity, itemLevel) or nil, -- (UPDATE 8 OFFENSE: sockets + links)
        BaseFireRate = math.round(base.BaseFireRate * 10) / 10,
        BaseWeakSpotMultiplier = base.BaseWeakSpotMultiplier,
        BalV = ItemData.GUN_BALANCE_V, -- (already on the current numbers: MigrateGunBalance skips it)
        MagazineSize = base.MagazineSize,
        ReloadTime = base.ReloadTime or 2.2,
        EffectiveRange = base.EffectiveRange,
        ExplosionRadius = base.ExplosionRadius,
        BurstCount = base.BurstCount,
        PelletCount = base.PelletCount,
        IsContinuousBeam = base.IsContinuousBeam,
        RecoilPitch = base.RecoilPitch or 1.0,
        RecoilYaw = base.RecoilYaw or 0.3,
        RecoilKickZ = base.RecoilKickZ or 0.35,
        ADSZoom = base.ADSZoom or 60,
        Mobility = base.Mobility or 1.0,
        UniqueTrait = uniqueTrait,
        Prefixes = prefixes,
        Suffixes = suffixes or {},
        Proc = proc,
    }
end

-- itemLevel = the level the weapon is rolled at (usually the player's level); it sets the damage.
-- allowMythic: the highest rarity rank this roll may reach (ItemData.MaxRarityRank; true = Mythic, see RollRarity).
function ItemData.GenerateRandomWeapon(rarityOverride: WeaponRarity?, luckMultiplier: number?, itemLevel: number?, allowMythic: any): WeaponInstance
    local lvl = math.max(1, math.floor(itemLevel or 1))
    local baseKeys = {}
    for k, def in pairs(BaseWeapons) do
        if not def.TestOnly and not def.Legacy then table.insert(baseKeys, k) end
    end
    table.sort(baseKeys)
    local baseId = baseKeys[math.random(1, #baseKeys)]
    local rarity = ItemData.NormRarity(rarityOverride) or RollRarity(luckMultiplier, allowMythic)
    local prefixes, suffixes = RollWeaponAffixSet(rarity, lvl, nil, baseId)
    return BuildWeapon(baseId, rarity, lvl, prefixes, nil, RollProc(rarity), suffixes)
end

-- A normally-rolled weapon (affixes, prefix) of one specific base -- including TestOnly ones.
function ItemData.GenerateWeaponOfBase(baseId: string, rarity: WeaponRarity, itemLevel: number?): WeaponInstance?
    if not BaseWeapons[baseId] then return nil end
    rarity = ItemData.NormRarity(rarity) or "Common" -- (RARITY v4: an old name ("Epic") means its new rarity)
    local lvl = math.max(1, math.floor(itemLevel or 1))
    local prefixes, suffixes = RollWeaponAffixSet(rarity, lvl, nil, baseId)
    return BuildWeapon(baseId, rarity, lvl, prefixes, nil, RollProc(rarity), suffixes)
end

function ItemData.CreateStarterPistol(): WeaponInstance
    local w = BuildWeapon("Glock17", "Common", 1, {}, "W_STARTER_PISTOL")
    w.UniqueTrait = nil
    return w
end
-- (0.61c, owner: "Starting weapon should be a random weapon from your chosen classes pool"): a plain Common level-1 gun of
-- a random base from the class's weapon group (ItemData.WeaponGroups), given on the FIRST class pick (SkillTreeServer)
function ItemData.CreateStarterWeapon(group: string?): WeaponInstance
    local pool = {}
    for _, id in ipairs(ItemData.Lineup) do
        local b = BaseWeapons[id]
        if b and not b.TestOnly and ItemData.WeaponGroupOf({ BaseId = id, Class = b.Class }) == group then table.insert(pool, id) end
    end
    if #pool == 0 then return ItemData.CreateStarterPistol() end
    local w = BuildWeapon(pool[math.random(1, #pool)], "Common", 1, {})
    w.UniqueTrait = nil
    return w
end

-- Sum of a weapon's affix values for one stat.
function ItemData.WeaponAffixTotal(weapon: WeaponInstance, stat: string): number
    local total = 0
    for _, list in ipairs({ weapon.Prefixes or {}, weapon.Suffixes or {} }) do
        for _, a in ipairs(list) do
            if a.Stat == stat then total += a.Value end
        end
    end
    return total
end

-- Average damage per second of the weapon itself (its own damage, fire rate, pellets/burst and its own
-- affixes; your character stats come on top of this). Used for comparing guns.
function ItemData.CalculateTrueDPS(weapon: WeaponInstance): number
    if not weapon then return 0 end
    local dmg = (weapon.BaseDamage or 1) * ItemData.GunTune(weapon) * (1 + ItemData.UPGRADE_DAMAGE_PER_LEVEL * (weapon.UpgradeLevel or 0))
    dmg *= 1 + ItemData.WeaponAffixTotal(weapon, "IncreasedDamage")
    local rate = (weapon.BaseFireRate or 1) * (1 + ItemData.WeaponAffixTotal(weapon, "FireRateBonus"))
    local pellets = math.max(1, weapon.PelletCount or 1)
    local burst = math.max(1, weapon.BurstCount or 1)
    local critChance = 0.05 + ItemData.WeaponAffixTotal(weapon, "CritChance")
    local critExtra = 0.5 + ItemData.WeaponAffixTotal(weapon, "CritMultiplier")
    return math.round(dmg * rate * pellets * burst * (1 + critChance * critExtra) * ItemData.ProcDpsFactor(weapon) * 10) / 10
end

function ItemData.CompareWeapons(newW: WeaponInstance, currW: WeaponInstance?): WeaponComparison
    local newDPS = ItemData.CalculateTrueDPS(newW)
    if not currW then
        return { IsBetter = true, Reasons = { "First weapon!" }, DiffDPS = newDPS, NewDPS = newDPS, CurrentDPS = 0 }
    end
    local currDPS = ItemData.CalculateTrueDPS(currW)
    local reasons = {}
    if newDPS > currDPS * 1.02 then
        table.insert(reasons, string.format("+%s DPS (%s vs %s)", FormatNumber(newDPS - currDPS), FormatNumber(newDPS), FormatNumber(currDPS)))
    end
    if (RarityRank[newW.Rarity] or 1) > (RarityRank[currW.Rarity] or 1) then
        table.insert(reasons, "Higher rarity (" .. newW.Rarity .. ")")
    end
    if newW.Proc and not currW.Proc and WeaponProcs[newW.Proc.Id] then
        table.insert(reasons, "Prefix: " .. WeaponProcs[newW.Proc.Id].Prefix)
    end
    if newW.UniqueTrait and not currW.UniqueTrait then
        table.insert(reasons, "Unique trait: " .. newW.UniqueTrait.Name)
    end
    return {
        IsBetter = newDPS > currDPS * 1.02 or (newW.UniqueTrait ~= nil and currW.UniqueTrait == nil and newDPS >= currDPS * 0.9),
        Reasons = reasons,
        DiffDPS = math.round((newDPS - currDPS) * 10) / 10,
        NewDPS = newDPS,
        CurrentDPS = currDPS,
    }
end

-- ==================== [GEAR] ====================
-- Six gear types; rings are one type that fits either ring slot.
local GearBaseNames: { [string]: string } = {
    Helmet = "Helmet", ChestPiece = "Chestplate", Leggings = "Leg Guards", Boots = "Boots", Ring = "Ring", Necklace = "Amulet",
}
ItemData.GearBaseNames = GearBaseNames
ItemData.GearSlotLabels = {
    Helmet = "Helmet", ChestPiece = "Chest", Leggings = "Legs", Boots = "Boots", Ring1 = "Ring", Ring2 = "Ring", Necklace = "Amulet",
}
-- Intrinsic armor of armor pieces at item level 1, Common (x level curve x rarity).
local SlotArmor: { [string]: number } = { Helmet = 6, ChestPiece = 10, Leggings = 8, Boots = 5 }

-- Each gear type has its own identity. Flat stats (MaxHP / HPRegen / Armor) grow with item level.
local GearAffixPoolsV2: { [string]: { any } } = {
    Helmet = {
        { Stat = "CritChance", Min = 0.02, Max = 0.04 }, { Stat = "WeakSpotMultiplier", Min = 0.08, Max = 0.18 },
        { Stat = "MaxHP", Min = 8, Max = 16 }, { Stat = "Dexterity", Min = 1, Max = 3 }, { Stat = "LootLuck", Min = 0.04, Max = 0.08 },
        { Stat = "ColdResist", Min = 0.08, Max = 0.15 }, { Stat = "ChaosResist", Min = 0.06, Max = 0.12 },
        { Stat = "HPRegen", Min = 1, Max = 2 }, -- (0.51: 8 lines for the top rarities)
    },
    ChestPiece = {
        { Stat = "MaxHP", Min = 12, Max = 24 }, { Stat = "HPRegen", Min = 1, Max = 2 }, { Stat = "Vitality", Min = 1, Max = 3 },
        { Stat = "IncreasedDamage", Min = 0.03, Max = 0.06 }, { Stat = "Armor", Min = 3, Max = 6 },
        { Stat = "MaxHPPct", Min = 0.04, Max = 0.08 }, { Stat = "FireResist", Min = 0.08, Max = 0.15 }, { Stat = "ChaosResist", Min = 0.06, Max = 0.12 },
    },
    Leggings = {
        { Stat = "MaxHP", Min = 10, Max = 20 }, { Stat = "MovementSpeed", Min = 0.03, Max = 0.06 },
        { Stat = "ReloadSpeedBonus", Min = 0.05, Max = 0.12 }, { Stat = "Strength", Min = 1, Max = 3 }, { Stat = "Armor", Min = 2, Max = 5 },
        { Stat = "FireResist", Min = 0.08, Max = 0.15 }, { Stat = "ArmorPct", Min = 0.06, Max = 0.12 },
        { Stat = "Vitality", Min = 1, Max = 3 },
    },
    Boots = {
        { Stat = "MovementSpeed", Min = 0.04, Max = 0.08 }, { Stat = "FireRateBonus", Min = 0.03, Max = 0.06 },
        { Stat = "Dexterity", Min = 1, Max = 3 }, { Stat = "GoldBonus", Min = 0.05, Max = 0.12 },
        { Stat = "ColdResist", Min = 0.08, Max = 0.15 }, { Stat = "AilmentDuration", Min = 0.06, Max = 0.12 },
        { Stat = "MaxHP", Min = 8, Max = 16 }, { Stat = "ReloadSpeedBonus", Min = 0.04, Max = 0.10 },
    },
    Ring = {
        { Stat = "CritChance", Min = 0.02, Max = 0.04 }, { Stat = "CritMultiplier", Min = 0.08, Max = 0.18 },
        { Stat = "IncreasedDamage", Min = 0.03, Max = 0.07 }, { Stat = "FireRateBonus", Min = 0.03, Max = 0.06 },
        { Stat = "MagSizeBonus", Min = 0.06, Max = 0.15 }, { Stat = "LootLuck", Min = 0.04, Max = 0.08 }, { Stat = "Strength", Min = 1, Max = 3 },
        { Stat = "AllResist", Min = 0.04, Max = 0.08 }, { Stat = "AilmentChance", Min = 0.08, Max = 0.16 },
        { Stat = "BurnDamage", Min = 0.10, Max = 0.20 }, { Stat = "BleedDamage", Min = 0.10, Max = 0.20 },
    },
    Necklace = {
        { Stat = "IncreasedDamage", Min = 0.04, Max = 0.08 }, { Stat = "CritMultiplier", Min = 0.10, Max = 0.20 },
        { Stat = "HPRegen", Min = 1, Max = 2 }, { Stat = "AllAttributes", Min = 1, Max = 2 },
        { Stat = "GoldBonus", Min = 0.06, Max = 0.14 }, { Stat = "LootLuck", Min = 0.05, Max = 0.10 },
        { Stat = "AllResist", Min = 0.05, Max = 0.09 }, { Stat = "AilmentChance", Min = 0.10, Max = 0.18 },
        { Stat = "FreezeEffect", Min = 0.08, Max = 0.16 }, { Stat = "DecayEffect", Min = 0.08, Max = 0.16 }, { Stat = "ChainKillDamage", Min = 0.01, Max = 0.02 },
        { Stat = "OverkillCarry", Min = 0.06, Max = 0.12 },
    },
}
ItemData.GearAffixPoolsV2 = GearAffixPoolsV2
-- (ITEM SCALING v2: gear uses the same line bands as guns -- the max is kept here for the UI / AffixCap)
local GearAffixCount: { [string]: number } = {}
for _, r in ipairs(Rarities) do local _, hi = ItemData.LineBand(r); GearAffixCount[r] = hi end
ItemData.GearAffixCount = GearAffixCount

-- Old saves / old code used "Ring1"/"Ring2" as an item's type; both are just "Ring" now.
function ItemData.GearType(slot: string?): string
    if slot == "Ring1" or slot == "Ring2" then return "Ring" end
    return slot or "Helmet"
end

function ItemData.RandomGearSlot(): string
    local bag = { "Helmet", "ChestPiece", "Gloves", "Leggings", "Boots", "Ring", "Ring", "Necklace" } -- (UPDATE 8: + Gloves)
    return bag[math.random(1, #bag)]
end

-- item = the piece being named (UPDATE 8 GEAR v3: a based piece is named after its base, e.g. "Sturdy Steel Visor of Fortune")
local function GearName(slotType: string, lines: { GearStatLine }, item: any?): string
    local base = (item and item.Base and ItemData.GearBaseOf and ItemData.GearBaseOf(item) and ItemData.GearBaseOf(item).Name) or GearBaseNames[slotType] or slotType
    local first, second = lines[1], lines[2]
    local name = base
    if first and StatDefs[first.Stat] then name = StatDefs[first.Stat].Prefix .. " " .. base end
    if second and StatDefs[second.Stat] then name = name .. " of " .. StatDefs[second.Stat].Noun end
    return name
end

local function RollGearLines(slotType: string, rarity: string, lvl: number, item: any?): { GearStatLine }
    if item and item.Base and ItemData.RollGearLinesV3 then return ItemData.RollGearLinesV3(slotType, rarity, lvl, ItemData.GearBaseOf(item)) end -- (UPDATE 8 GEAR v3)
    local pool = GearAffixPoolsV2[slotType] or GearAffixPoolsV2.Helmet
    local rolled = RollAffixes(pool, ItemData.RollLineCount(rarity), rarity, lvl)
    local lines: { GearStatLine } = {}
    for _, a in ipairs(rolled) do
        table.insert(lines, { Stat = a.Stat, Name = StatDefs[a.Stat] and StatDefs[a.Stat].Label or a.Stat, Value = a.Value, Tier = a.Tier, Roll = a.Roll })
    end
    return lines
end

-- ==================== [GEAR v3: BASES + IMPLICITS + NEW AFFIX POOLS + GLOVES] (UPDATE 8, DEFENCE builder) ====================
-- (owner design "Gear": GLOVES are an 8th equip slot -- a gear piece, nothing to do with the glove cosmetics; every slot has
-- BASE TYPES with a defence type (Plating / Agility / Ward or a hybrid) and an IMPLICIT line; affixes rebuilt as prefixes
-- (life, defences, flat added damage) and suffixes (resists, speeds, crit, luck, a few rare build lines).) NEW DROPS ONLY:
-- an item with .Base is v3 (.Def = its base defences, .Implicit = { Stat, Name, Value }, lines carry Side "P" / "S"); old
-- items (no .Base) keep their .Armor + lines and craft from the legacy pools (GearAffixPoolsV2) until WIPE 5.
GearBaseNames.Gloves = "Gloves"
ItemData.GearSlotLabels.Gloves = "Gloves"
ItemData.GEAR_EQUIP_SLOTS = { "Helmet", "ChestPiece", "Gloves", "Leggings", "Boots", "Necklace", "Ring1", "Ring2" }
ItemData.GEAR_TYPES = { "Helmet", "ChestPiece", "Gloves", "Leggings", "Boots", "Ring", "Necklace" }
ItemData.GEAR_V3 = true -- (false = new drops roll the old way)
-- DEFENCE BUDGET of an armour slot: units x LevelCurve(item level) x RarityDamageMult (the old Helmet 6 / Chest 10 / Legs 8 /
-- Boots 5 = 29 Armor, now spread over five slots). Agility uses the same numbers as Plating (same formula on your sheet);
-- Ward x WARD_PER_UNIT. A hybrid base gets HYBRID_SHARE of the budget in EACH of its two defences.
ItemData.GEAR_DEF_UNITS = { Helmet = 5, ChestPiece = 9, Gloves = 4, Leggings = 7, Boots = 4 }
ItemData.WARD_PER_UNIT = 1.2
ItemData.HYBRID_SHARE = 0.55
ItemData.GEAR_DEF_MIX = { P = { Plating = 1 }, A = { Agility = 1 }, W = { Ward = 1 }, PA = { Plating = 0.55, Agility = 0.55 },
    PW = { Plating = 0.55, Ward = 0.55 }, AW = { Agility = 0.55, Ward = 0.55 } }
-- every v3 line's value x this (8 slots now carry what 7 did: an average kit keeps today's power -- classbal sims)
ItemData.GEAR_V3_LINE_SCALE = 0.85
ItemData.GEAR_DEF_WORD = { P = "Plating", A = "Agility", W = "Ward", PA = "Plating + Agility", PW = "Plating + Ward", AW = "Agility + Ward" }
-- the implicit: a fixed line of the base, size by item level only (pct x GearLevelScale, flat x LevelCurve), not by rarity
local function Imp(stat: string, lo: number, hi: number) return { Stat = stat, Min = lo, Max = hi } end
ItemData.GEAR_BASES = {
    Helmet = { -- implicit: weak-spot damage
        { Id = "SteelVisor", Name = "Steel Visor", Def = "P", Implicit = Imp("WeakSpotMultiplier", 0.04, 0.07) },
        { Id = "RunnerHood", Name = "Runner's Hood", Def = "A", Implicit = Imp("WeakSpotMultiplier", 0.04, 0.07) },
        { Id = "HaloCirclet", Name = "Halo Circlet", Def = "W", Implicit = Imp("WeakSpotMultiplier", 0.04, 0.07) },
        { Id = "ScoutHelm", Name = "Scout Helm", Def = "PA", Implicit = Imp("WeakSpotMultiplier", 0.04, 0.07) },
        { Id = "WardenHelm", Name = "Warden Helm", Def = "PW", Implicit = Imp("WeakSpotMultiplier", 0.04, 0.07) },
        { Id = "GlimmerMask", Name = "Glimmer Mask", Def = "AW", Implicit = Imp("WeakSpotMultiplier", 0.04, 0.07) },
    },
    ChestPiece = { -- implicit: life
        { Id = "BulwarkRig", Name = "Bulwark Rig", Def = "P", Implicit = Imp("MaxHPPct", 0.02, 0.04) },
        { Id = "StriderJacket", Name = "Strider Jacket", Def = "A", Implicit = Imp("MaxHPPct", 0.02, 0.04) },
        { Id = "HaloCoat", Name = "Halo Coat", Def = "W", Implicit = Imp("MaxHPPct", 0.02, 0.04) },
        { Id = "TrooperVest", Name = "Trooper Vest", Def = "PA", Implicit = Imp("MaxHPPct", 0.02, 0.04) },
        { Id = "SentinelCoat", Name = "Sentinel Coat", Def = "PW", Implicit = Imp("MaxHPPct", 0.02, 0.04) },
        { Id = "PhantomWeave", Name = "Phantom Weave", Def = "AW", Implicit = Imp("MaxHPPct", 0.02, 0.04) },
    },
    Gloves = { -- implicit: fire rate or crit chance
        { Id = "KnucklePlates", Name = "Knuckle Plates", Def = "P", Implicit = Imp("CritChance", 0.01, 0.02) },
        { Id = "GripGloves", Name = "Grip Gloves", Def = "A", Implicit = Imp("FireRateBonus", 0.02, 0.04) },
        { Id = "PulseGloves", Name = "Pulse Gloves", Def = "W", Implicit = Imp("CritChance", 0.01, 0.02) },
        { Id = "CombatGloves", Name = "Combat Gloves", Def = "PA", Implicit = Imp("FireRateBonus", 0.02, 0.04) },
        { Id = "AnchorGauntlets", Name = "Anchor Gauntlets", Def = "PW", Implicit = Imp("CritChance", 0.01, 0.02) },
        { Id = "FlickerWraps", Name = "Flicker Wraps", Def = "AW", Implicit = Imp("FireRateBonus", 0.02, 0.04) },
    },
    Leggings = { -- implicit: health regen
        { Id = "SiegeGreaves", Name = "Siege Greaves", Def = "P", Implicit = Imp("HPRegen", 1, 2) },
        { Id = "SprinterPants", Name = "Sprinter Pants", Def = "A", Implicit = Imp("HPRegen", 1, 2) },
        { Id = "GlowLeggings", Name = "Glow Leggings", Def = "W", Implicit = Imp("HPRegen", 1, 2) },
        { Id = "RangerPants", Name = "Ranger Pants", Def = "PA", Implicit = Imp("HPRegen", 1, 2) },
        { Id = "BastionLegs", Name = "Bastion Legs", Def = "PW", Implicit = Imp("HPRegen", 1, 2) },
        { Id = "DriftLeggings", Name = "Drift Leggings", Def = "AW", Implicit = Imp("HPRegen", 1, 2) },
    },
    Boots = { -- implicit: move speed
        { Id = "IronTreads", Name = "Iron Treads", Def = "P", Implicit = Imp("MovementSpeed", 0.02, 0.04) },
        { Id = "GlideSneakers", Name = "Glide Sneakers", Def = "A", Implicit = Imp("MovementSpeed", 0.02, 0.04) },
        { Id = "SparkBoots", Name = "Spark Boots", Def = "W", Implicit = Imp("MovementSpeed", 0.02, 0.04) },
        { Id = "TrailBoots", Name = "Trail Boots", Def = "PA", Implicit = Imp("MovementSpeed", 0.02, 0.04) },
        { Id = "WardBoots", Name = "Keeper Boots", Def = "PW", Implicit = Imp("MovementSpeed", 0.02, 0.04) },
        { Id = "DriftBoots", Name = "Drift Boots", Def = "AW", Implicit = Imp("MovementSpeed", 0.02, 0.04) },
    },
    Ring = { -- implicit: a resistance or a little added damage (no defence)
        { Id = "EmberBand", Name = "Ember Band", Implicit = Imp("HeatResist", 0.08, 0.12) },
        { Id = "FrostBand", Name = "Frost Band", Implicit = Imp("CryoResist", 0.08, 0.12) },
        { Id = "StormBand", Name = "Storm Band", Implicit = Imp("VoltResist", 0.08, 0.12) },
        { Id = "ShadeBand", Name = "Shade Band", Implicit = Imp("VoidResist", 0.06, 0.09) },
        { Id = "PrismLoop", Name = "Prism Loop", Implicit = Imp("AllElemResist", 0.03, 0.05) },
        { Id = "SpikeRing", Name = "Spike Ring", Implicit = Imp("AddedKinetic", 0.15, 0.3) },
        { Id = "CinderRing", Name = "Cinder Ring", Implicit = Imp("AddedHeat", 0.15, 0.3) },
    },
    Necklace = { -- implicit: a broad stat (no defence)
        { Id = "HeartPendant", Name = "Heart Pendant", Implicit = Imp("MaxHPPct", 0.03, 0.05) },
        { Id = "EdgePendant", Name = "Edge Pendant", Implicit = Imp("IncreasedDamage", 0.04, 0.06) },
        { Id = "LuckyCharm", Name = "Lucky Charm", Implicit = Imp("LootLuck", 0.04, 0.06) },
        { Id = "PrismPendant", Name = "Prism Pendant", Implicit = Imp("AllElemResist", 0.04, 0.06) },
        { Id = "HunterLocket", Name = "Hunter's Locket", Implicit = Imp("CritMultiplier", 0.06, 0.10) },
    },
}
local GEAR_BASE_BY_ID = {}
for slot, list in pairs(ItemData.GEAR_BASES) do for _, b in ipairs(list) do b.Slot = slot; GEAR_BASE_BY_ID[b.Id] = b end end
function ItemData.GearBaseOf(item: any): any return item and item.Base and GEAR_BASE_BY_ID[item.Base] or nil end
-- HYBRID LINES: the line's value is its life part; the other part = value x the ratio (StatCalculator expands them)
ItemData.GEAR_HYBRID = { LifePlating = { MaxHP = 1, Plating = 0.4 }, LifeAgility = { MaxHP = 1, Agility = 0.4 }, LifeWard = { MaxHP = 1, Ward = 0.6 } }
-- BUILD LINES (rare; drop-only, never from crafting): a fixed value, no tier. VoltCanFreeze (OFFENSE hook), PlatingVsElements /
-- WardVsVoid (DEFENCE: StatCalculator.MitigateHit / CombatServer.DamagePlayer). GEAR_BUILD_CHANCE = the chance a build line is
-- in the pool for a given drop (then it competes like any line).
ItemData.GEAR_BUILD_CHANCE = 0.12
-- THE POOLS (T1 ranges per item type; x the rarity's AFFIX_POWER x GearTierMult(tier) x item level, like every gear line).
-- Side P = prefix, S = suffix; Needs = only on a base with that defence; Range = { [type] = { min, max } }.
local A = function(t: { [string]: { number } }) return t end
local ARMOUR = { "Helmet", "ChestPiece", "Gloves", "Leggings", "Boots" }
local function Every(lo: number, hi: number, types: { string }?): { [string]: { number } }
    local t = {}
    for _, k in ipairs(types or ItemData.GEAR_TYPES) do t[k] = { lo, hi } end
    return t
end
ItemData.GEAR_POOL_V3 = {
    -- PREFIXES: life, defences, flat added damage
    { Stat = "MaxHP", Side = "P", Range = A({ Helmet = { 5, 11 }, ChestPiece = { 8, 16 }, Gloves = { 4, 8 }, Leggings = { 7, 14 }, Boots = { 5, 11 }, Necklace = { 5, 11 } }) },
    { Stat = "MaxHPPct", Side = "P", Range = A({ ChestPiece = { 0.03, 0.06 }, Leggings = { 0.02, 0.05 }, Necklace = { 0.02, 0.05 } }) },
    { Stat = "Plating", Side = "P", Needs = "Plating", Range = A({ Helmet = { 2, 4 }, ChestPiece = { 3, 6 }, Gloves = { 2, 4 }, Leggings = { 2, 5 }, Boots = { 2, 4 } }) },
    { Stat = "Agility", Side = "P", Needs = "Agility", Range = A({ Helmet = { 2, 4 }, ChestPiece = { 3, 6 }, Gloves = { 2, 4 }, Leggings = { 2, 5 }, Boots = { 2, 4 } }) },
    { Stat = "Ward", Side = "P", Needs = "Ward", Range = A({ Helmet = { 3, 6 }, ChestPiece = { 5, 9 }, Gloves = { 3, 6 }, Leggings = { 3, 7 }, Boots = { 3, 6 } }) },
    { Stat = "LocalDefence", Side = "P", Range = Every(0.06, 0.12, ARMOUR) },
    { Stat = "LifePlating", Side = "P", Needs = "Plating", Range = Every(3, 7, ARMOUR) },
    { Stat = "LifeAgility", Side = "P", Needs = "Agility", Range = Every(3, 7, ARMOUR) },
    { Stat = "LifeWard", Side = "P", Needs = "Ward", Range = Every(3, 7, ARMOUR) },
    { Stat = "AddedKinetic", Side = "P", Range = Every(0.2, 0.4, { "Gloves", "Ring", "Necklace" }) },
    { Stat = "AddedHeat", Side = "P", Range = Every(0.2, 0.4, { "Gloves", "Ring", "Necklace" }) },
    { Stat = "AddedCryo", Side = "P", Range = Every(0.2, 0.4, { "Gloves", "Ring", "Necklace" }) },
    { Stat = "AddedVolt", Side = "P", Range = Every(0.2, 0.4, { "Gloves", "Ring", "Necklace" }) },
    { Stat = "IncreasedDamage", Side = "P", Range = A({ Ring = { 0.03, 0.07 }, Necklace = { 0.04, 0.08 } }) },
    { Stat = "PlatingPct", Side = "P", Range = A({ Necklace = { 0.05, 0.10 } }) },
    { Stat = "AgilityPct", Side = "P", Range = A({ Necklace = { 0.05, 0.10 } }) },
    { Stat = "WardPct", Side = "P", Range = A({ Necklace = { 0.05, 0.10 } }) },
    -- SUFFIXES: resistances, speeds, crit, luck
    { Stat = "HeatResist", Side = "S", Range = Every(0.06, 0.12) },
    { Stat = "CryoResist", Side = "S", Range = Every(0.06, 0.12) },
    { Stat = "VoltResist", Side = "S", Range = Every(0.06, 0.12) },
    { Stat = "VoidResist", Side = "S", Range = Every(0.05, 0.09) },
    { Stat = "AllElemResist", Side = "S", Range = A({ Ring = { 0.04, 0.08 }, Necklace = { 0.05, 0.09 } }) },
    { Stat = "FireRateBonus", Side = "S", Range = A({ Gloves = { 0.02, 0.05 }, Ring = { 0.03, 0.06 } }) },
    { Stat = "CritChance", Side = "S", Range = A({ Helmet = { 0.02, 0.04 }, Gloves = { 0.015, 0.03 }, Ring = { 0.02, 0.04 } }) },
    { Stat = "CritMultiplier", Side = "S", Range = A({ Gloves = { 0.08, 0.18 }, Ring = { 0.08, 0.18 }, Necklace = { 0.10, 0.20 } }) },
    { Stat = "ReloadSpeedBonus", Side = "S", Range = A({ Gloves = { 0.05, 0.12 }, Leggings = { 0.05, 0.12 } }) },
    { Stat = "MagSizeBonus", Side = "S", Range = A({ Gloves = { 0.06, 0.15 }, Ring = { 0.06, 0.15 } }) },
    { Stat = "MovementSpeed", Side = "S", Range = A({ Boots = { 0.04, 0.08 }, Leggings = { 0.03, 0.06 } }) },
    { Stat = "AilmentChance", Side = "S", Range = A({ Gloves = { 0.08, 0.16 }, Ring = { 0.08, 0.16 }, Necklace = { 0.10, 0.18 } }) },
    { Stat = "LootLuck", Side = "S", Range = A({ Helmet = { 0.04, 0.08 }, Boots = { 0.04, 0.08 }, Ring = { 0.04, 0.08 }, Necklace = { 0.05, 0.10 } }) },
    { Stat = "WeakSpotMultiplier", Side = "S", Range = A({ Helmet = { 0.08, 0.18 } }) },
    { Stat = "HPRegen", Side = "S", Range = A({ ChestPiece = { 1, 2 }, Leggings = { 1, 2 }, Necklace = { 1, 2 } }) },
    { Stat = "WardRecharge", Side = "S", Needs = "Ward", Range = Every(0.10, 0.20, ARMOUR) },
    -- ATTRIBUTES (UPDATE 8 phase 4, keys read by OFFENSE's attribute bonuses + Requirements(): gear needs ~0.8 x item level of
    -- its base's attribute). Suffixes, leaning on helmet / gloves / rings / amulet like the reference game; All on jewellery.
    { Stat = "Strength", Side = "S", Range = A({ Helmet = { 6, 12 }, Gloves = { 6, 12 }, Ring = { 6, 12 }, Necklace = { 7, 14 }, ChestPiece = { 5, 10 }, Leggings = { 5, 10 }, Boots = { 5, 10 } }) },
    { Stat = "Dexterity", Side = "S", Range = A({ Helmet = { 6, 12 }, Gloves = { 6, 12 }, Ring = { 6, 12 }, Necklace = { 7, 14 }, ChestPiece = { 5, 10 }, Leggings = { 5, 10 }, Boots = { 5, 10 } }) },
    { Stat = "Intellect", Side = "S", Range = A({ Helmet = { 6, 12 }, Gloves = { 6, 12 }, Ring = { 6, 12 }, Necklace = { 7, 14 }, ChestPiece = { 5, 10 }, Leggings = { 5, 10 }, Boots = { 5, 10 } }) },
    { Stat = "AllAttributes", Side = "S", Range = A({ Ring = { 2, 5 }, Necklace = { 3, 6 } }) },
    -- BUILD LINES (rare, fixed)
    { Stat = "VoltCanFreeze", Side = "S", Build = true, Fixed = 1, Range = Every(1, 1, { "Gloves", "Ring", "Necklace" }) },
    { Stat = "PlatingVsElements", Side = "S", Build = true, Fixed = 0.5, Needs = "Plating", Range = Every(1, 1, { "ChestPiece", "Leggings" }) },
    { Stat = "WardVsVoid", Side = "S", Build = true, Fixed = 1, Needs = "Ward", Range = Every(1, 1, { "Helmet", "ChestPiece" }) },
}
-- the v3 pool for an item type + base (build = include the rare build lines; crafting never does)
function ItemData.GearPoolV3(slotType: string, base: any?, build: boolean?): { any }
    local mix = base and base.Def and ItemData.GEAR_DEF_MIX[base.Def] or {}
    local out = {}
    for _, e in ipairs(ItemData.GEAR_POOL_V3) do
        local r = e.Range[slotType]
        if r and (not e.Needs or mix[e.Needs]) and (build or not e.Build) then
            table.insert(out, { Stat = e.Stat, Min = r[1], Max = r[2], Side = e.Side, Build = e.Build, Fixed = e.Fixed })
        end
    end
    return out
end
-- the pool an item crafts from: v3 for a based piece, the legacy pool for an old one (every crafting path uses this)
function ItemData.GearPoolOf(item: any, slotType: string?): { any }
    local st = slotType or ItemData.GearType(item and item.Slot)
    if item and item.Base then return ItemData.GearPoolV3(st, ItemData.GearBaseOf(item), false) end
    return GearAffixPoolsV2[st] or GearAffixPoolsV2.Helmet
end
-- lines for a v3 piece: up to the band's per-side max of prefixes and of suffixes; build lines keep their fixed value
function ItemData.RollGearLinesV3(slotType: string, rarity: string, lvl: number, base: any?): { GearStatLine }
    local n = ItemData.RollLineCount(rarity)
    local _, _, per = ItemData.LineBand(rarity)
    per = math.max(1, per or 3)
    local pool = ItemData.GearPoolV3(slotType, base, true)
    local pre, suf = {}, {}
    for _, d in ipairs(pool) do
        if not d.Build or math.random() < ItemData.GEAR_BUILD_CHANCE then table.insert((d.Side == "P") and pre or suf, d) end
    end
    local hiP = math.min(n, per, #pre)
    local np = math.random(math.min(hiP, math.max(0, n - math.min(per, #suf))), hiP)
    local ns = math.min(n - np, per, #suf)
    local lines: { GearStatLine } = {}
    for _, part in ipairs({ { pre, np, "P" }, { suf, ns, "S" } }) do
        local byStat = {}
        for _, d in ipairs(part[1]) do byStat[d.Stat] = d end
        for _, a in ipairs(RollAffixes(part[1], part[2], rarity, lvl)) do
            local d = byStat[a.Stat]
            local line: any = { Stat = a.Stat, Name = StatDefs[a.Stat] and StatDefs[a.Stat].Label or a.Stat, Value = a.Value, Tier = a.Tier, Roll = a.Roll, Side = part[3] }
            if d and d.Build then line.Value, line.Tier, line.Roll = d.Fixed, nil, nil else line.Value = RoundStat(a.Stat, a.Value * ItemData.GEAR_V3_LINE_SCALE) end
            table.insert(lines, line)
        end
    end
    return lines
end
-- the piece's own defences with its LocalDefence lines applied: { Plating, Agility, Ward } (old pieces: Armor = Plating)
function ItemData.GearDefOf(g: any): { [string]: number }
    local out = { Plating = 0, Agility = 0, Ward = 0 }
    if type(g) ~= "table" then return out end
    if not g.Base then out.Plating = tonumber(g.Armor) or 0 return out end
    local loc = 0
    for _, l in ipairs(g.StatLines or {}) do if l.Stat == "LocalDefence" and type(l.Value) == "number" then loc += l.Value end end
    for k, v in pairs(type(g.Def) == "table" and g.Def or {}) do if out[k] then out[k] = math.round(v * (1 + loc)) end end
    return out
end
-- re-scales a piece's base defences (Ascend / rarity changes: ratio of RarityDamageMult; item level: flat implicit too)
function ItemData.ScaleGearDefence(g: any, k: number, implicitToo: boolean?)
    if type(g.Armor) == "number" and g.Armor > 0 then g.Armor = math.round(g.Armor * k) end
    if type(g.Def) == "table" then for key, v in pairs(g.Def) do g.Def[key] = math.round(v * k) end end
    if implicitToo and type(g.Implicit) == "table" and StatDefs[g.Implicit.Stat] and StatDefs[g.Implicit.Stat].Kind == "flat" then
        g.Implicit.Value = RoundStat(g.Implicit.Stat, g.Implicit.Value * k)
    end
end
-- a fresh v3 piece
function ItemData.GenerateGearV3(slotType: string, rarity: string, lvl: number, baseId: string?): GearInstance
    local list = ItemData.GEAR_BASES[slotType] or ItemData.GEAR_BASES.Helmet
    local base = (baseId and GEAR_BASE_BY_ID[baseId]) or list[math.random(1, #list)]
    local curve = ItemData.LevelCurve(lvl)
    local def = nil
    local units = ItemData.GEAR_DEF_UNITS[slotType]
    if units and base.Def then
        def = {}
        for k, share in pairs(ItemData.GEAR_DEF_MIX[base.Def]) do
            def[k] = math.max(1, math.round(units * share * curve * (RarityDamageMult[rarity] or 1) * ((k == "Ward") and ItemData.WARD_PER_UNIT or 1)))
        end
    end
    local im = base.Implicit
    local pos = math.random()
    local iv = im.Min + pos * (im.Max - im.Min)
    local idef = StatDefs[im.Stat]
    iv *= (idef and idef.Kind == "flat") and curve or ItemData.GearLevelScale(lvl)
    local g: any = {
        Uid = "G_" .. math.random(10000000, 99999999),
        Slot = slotType, Rarity = rarity, ItemLevel = lvl, Base = base.Id, Def = def,
        Implicit = { Stat = im.Stat, Name = idef and idef.Label or im.Stat, Value = RoundStat(im.Stat, iv) },
    }
    g.StatLines = ItemData.RollGearLinesV3(slotType, rarity, lvl, base)
    g.Name = GearName(slotType, g.StatLines, g)
    return g
end
-- labels for the new line keys (hybrids / build lines word themselves through Format)
do
    local function F(v: number) return FormatNumber(v) end
    local SD = {
        LocalDefence = { Label = "Increased Plating / Agility / Ward (this item)", Kind = "pct", Prefix = "Tempered", Noun = "Temper", Desc = "Raises this piece's own Plating, Agility and Ward." },
        LifePlating = { Label = "Life + Plating", Kind = "flat", Prefix = "Stalwart", Noun = "the Wall", Desc = "Max health and Plating together.",
            Format = function(v) return "+" .. F(v) .. " Max Health, +" .. F(math.round(v * 0.4)) .. " Plating" end },
        LifeAgility = { Label = "Life + Agility", Kind = "flat", Prefix = "Lithe", Noun = "the Dancer", Desc = "Max health and Agility together.",
            Format = function(v) return "+" .. F(v) .. " Max Health, +" .. F(math.round(v * 0.4)) .. " Agility" end },
        LifeWard = { Label = "Life + Ward", Kind = "flat", Prefix = "Haloed", Noun = "the Halo", Desc = "Max health and Ward together.",
            Format = function(v) return "+" .. F(v) .. " Max Health, +" .. F(math.round(v * 0.6)) .. " Ward" end },
        AddedKinetic = { Label = "Added Kinetic Damage (per hit)", Kind = "flat", Prefix = "Barbed", Noun = "Barbs", Desc = "Kinetic damage added to every gun hit (worth more on slower guns' hits, less per pellet)." },
        AddedHeat = { Label = "Added Heat Damage (per hit)", Kind = "flat", Prefix = "Smouldering", Noun = "Cinders", Desc = "Heat damage added to every gun hit." },
        AddedCryo = { Label = "Added Cryo Damage (per hit)", Kind = "flat", Prefix = "Frosted", Noun = "Frost", Desc = "Cryo damage added to every gun hit." },
        AddedVolt = { Label = "Added Volt Damage (per hit)", Kind = "flat", Prefix = "Sparking", Noun = "Sparks", Desc = "Volt damage added to every gun hit." },
        VoltCanFreeze = { Label = "Volt damage can Freeze", Kind = "pct", Prefix = "Cryostatic", Noun = "the Cold Spark", Desc = "Your Volt damage also builds Freeze.",
            Format = function() return "Your Volt damage can Freeze" end },
        PlatingVsElements = { Label = "Plating also cuts elemental hits", Kind = "pct", Prefix = "Insulated", Noun = "the Faraday", Desc = "Your Plating also cuts Heat, Cryo, Volt and Void hits, at half strength.",
            Format = function() return "Your Plating also cuts elemental hits (half strength)" end },
        WardVsVoid = { Label = "Void damage hits your Ward", Kind = "pct", Prefix = "Sealed", Noun = "the Seal", Desc = "Void damage no longer skips your Ward.",
            Format = function() return "Void damage no longer skips your Ward" end },
    }
    for k, v in pairs(SD) do StatDefs[k] = StatDefs[k] or v end
end

function ItemData.GenerateRandomGear(slot: string?, rarityOverride: WeaponRarity?, luckMultiplier: number?, itemLevel: number?, allowMythic: any): GearInstance
    local lvl = math.max(1, math.floor(itemLevel or 1))
    local slotType = ItemData.GearType(slot or ItemData.RandomGearSlot())
    local rarity = ItemData.NormRarity(rarityOverride) or RollRarity(luckMultiplier, allowMythic)
    if ItemData.GEAR_V3 then return ItemData.GenerateGearV3(slotType, rarity, lvl) end -- (UPDATE 8 GEAR v3: bases + implicits)
    local lines = RollGearLines(slotType, rarity, lvl)
    local armor = SlotArmor[slotType] and math.round(SlotArmor[slotType] * ItemData.LevelCurve(lvl) * (RarityDamageMult[rarity] or 1)) or 0
    return {
        Uid = "G_" .. math.random(10000000, 99999999),
        Slot = slotType,
        Name = GearName(slotType, lines),
        Rarity = rarity,
        ItemLevel = lvl,
        Armor = armor,
        StatLines = lines,
    }
end

-- ==================== [MATERIALS, UPGRADES, CRAFTING CURRENCIES] ====================
-- Materials (upgrades): Scrap (+1..+5), Alloy (+6..+12), Prism Shards (+13..+20, re-leveling).
-- Crafting currencies (PoE-style): Reforge Token = reroll every affix, Tuning Kit = reroll the numbers
-- inside the current affixes, Prefix Catalyst = reroll the elemental / special prefix.
-- All of them live in PlayerState.Materials[key]; they come only from dungeons and dismantling.
ItemData.MaterialOrderAll = { "Scrap", "Alloy", "Prism", "ReforgeToken", "TuningKit", "PrefixCatalyst", "AffixSeal", "InfusionCore", "PurgeSalt",
    "AscensionEssence", "Schematic", "FateShard", "RebirthShard", "ChartShard" }
-- CRAFTING v4 (0.97, owner: "Crafting is incredibly overpowered and removes the rarity aspect of good gear ... We should only
-- be able to reroll affixes for a very expensive price, and upgrade weapons"): these currencies are RETIRED -- nothing
-- drops them (CRAFT_SOURCE_MULT 0), no window lists them, saved amounts stay untouched in the save. Everything else
-- reads MaterialOrder (the live list).
ItemData.RETIRED_MATERIALS = { ReforgeToken = true, TuningKit = true, PrefixCatalyst = true, AffixSeal = true, InfusionCore = true,
    PurgeSalt = true, Schematic = true, FateShard = true } -- (UPDATE 8 RARITY v4: AscensionEssence is LIVE again -- Rare -> Mythic)
ItemData.MaterialOrder = {}
for _, k in ipairs(ItemData.MaterialOrderAll) do
    if not ItemData.RETIRED_MATERIALS[k] then table.insert(ItemData.MaterialOrder, k) end
end
ItemData.MaterialDefs = {
    Scrap = { Name = "Scrap", Short = "Scrap", Icon = "", IconKey = "cur_scrap", Color = Color3.fromRGB(170, 175, 185), Desc = "Upgrades +1 to +5. From kills, chests and dismantling." },
    Alloy = { Name = "Alloy", Short = "Alloy", Icon = "", IconKey = "cur_alloy", Color = Color3.fromRGB(90, 170, 255), Desc = "Upgrades +6 to +12. From elites, bosses and dismantling Rare+." },
    Prism = { Name = "Prism Shard", Short = "Prism", Icon = "", IconKey = "cur_prism", Color = Color3.fromRGB(230, 120, 255), Desc = "Upgrades +13 to +20 and affix rerolls. From bosses, maps and dismantling Mythics and Relics." },
    ReforgeToken = { Name = "Reforge Token", Short = "Tokens", Icon = "", IconKey = "mat_reforge", Color = Color3.fromRGB(255, 170, 60), Desc = "Rerolls every affix on a Rare or better weapon." },
    TuningKit = { Name = "Tuning Kit", Short = "Kits", Icon = "", IconKey = "mat_tuning", Color = Color3.fromRGB(120, 230, 160), Desc = "Rerolls the numbers inside a weapon's current affixes." },
    PrefixCatalyst = { Name = "Prefix Catalyst", Short = "Catalysts", Icon = "", IconKey = "mat_catalyst", Color = Color3.fromRGB(255, 90, 120), Desc = "Rerolls the elemental / special prefix of a Rare or better weapon." },
    -- (0.61, owner: "We need new material to lock affixes when rerolling them, the cost would double with each reroll")
    AffixSeal = { Name = "Affix Seal", Short = "Seals", Icon = "", IconKey = "mat_seal", Color = Color3.fromRGB(90, 215, 225), Desc = "Seals ONE affix when you Reforge: it stays, the rest reroll. One seal per reforge, and the cost triples with every sealed reforge of the same item. Very rare: bosses and maps only." },
    -- FORGE CRAFTING (0.61f, owner: "add more features to the armory (we are going to add crafting mechanics now)")
    InfusionCore = { Name = "Infusion Core", Short = "Cores", Icon = "", IconKey = "mat_infusion", Color = Color3.fromRGB(120, 200, 255), Desc = "Augment: adds one RANDOM affix to an item with a free affix slot. Rare: bosses, elites and caches." },
    PurgeSalt = { Name = "Purge Salt", Short = "Salts", Icon = "", IconKey = "mat_purge", Color = Color3.fromRGB(235, 235, 210), Desc = "Purge: removes one affix at random. From bosses, elites and caches." },
    AscensionEssence = { Name = "Lodestar", Short = "Lodestar", Icon = "", IconKey = "mat_ascend", Color = Color3.fromRGB(255, 120, 200), Desc = "ASCEND at the Forge: a Rare item becomes a Mythic and gains its Mythic line (one more random line). Incredibly rare: any monster can drop one (bosses a little more often)." },
    Schematic = { Name = "Schematic", Short = "Schematics", Icon = "", IconKey = "mat_schematic", Color = Color3.fromRGB(110, 230, 170), Desc = "Crafting bench: build the gun or gear piece you pick at your level, at a RANDOM rarity (up to three under your level's top). From bosses, caches, rifts and rarely dismantling." },
    -- (owner 2026-10-04: "a new currency that allows you to reroll unique traits ... exceptionally rare, .05% from mobs and .5% from bosses")
    FateShard = { Name = "Fate Shard", Short = "Fate", Icon = "", IconKey = "mat_fate", Color = Color3.fromRGB(255, 184, 28), Desc = "Exceptionally rare (0.05% from enemies, 0.5% from bosses). Rerolls a weapon's unique trait into a different one." },
    RebirthShard = { Name = "Rebirth Shard", Short = "Rebirth", Icon = "", IconKey = "mat_rebirth", Color = Color3.fromRGB(150, 230, 255), Desc = "A 5% drop from every boss (or buy one in the Change Class window). Change your class at the Skill Tree. Your passive tree and specialization are refunded." },
}
-- (0.66 MAPS: the map-only currency -- Rifts.SHARD_FLOOR_CHANCE / ShardsFor; spent at the map device, Rifts.CRAFT)
ItemData.MaterialDefs.ChartShard = { Name = "Chart Shard", Short = "Charts", Icon = "", IconKey = "teleport", Color = Color3.fromRGB(110, 200, 255),
    Desc = "Only found in maps (map floors and the guardian). At the map device: CHART a map's biome and layout, CORRUPT it for a gamble, or ENGRAVE a Rare map into a Storied one." }
ItemData.FATE_SHARD_CHANCE = { Mob = 0.0005, Boss = 0.005 }
-- ==================== CRAFTING CURRENCIES v5 (UPDATE 7 "DEPTH", vault "Loot Economy Plan" section 4) ====================
-- Each currency does ONE random job (you never pick the result) and comes from its own source. Names are placeholders
-- (owner: renames later). Each one stays hidden until its unlock level (Unlock): forge rows, the material grid, the bag.
--   Shift Shard  REROLL GUN: a Rare+ gun -> a random other gun of your class (ItemData.RetypeWeapon)   L18  Vault Lock, daily roll
--   Graft        adds one random line where the rarity's band has room                                  L18  (Bounty Mark), daily roll
--   Strip Shard  removes one random line                                                                 L30  (Rift Tear), daily roll
--   Temper       raises one random line one tier, never past what the item level allows                L45  (Echo Duel), daily roll
--   Storm Core   rerolls everything: line count (inside the band), which lines, their tiers            L45  bosses, daily roll
-- Prism keeps the everyday job: REROLL VALUES (same lines, same tiers, new numbers). The encounter sources in brackets
-- arrive with those encounters; until then the daily roll is how you get them.
ItemData.CURRENCY_V5 = { "ShiftShard", "Graft", "StripShard", "Temper", "StormCore", "RiftDust", "RiftTaint" } -- (+ RiftDust: Riftmods, UPDATE 7 B1; + RiftTaint: Overcharge, C5)
ItemData.MaterialDefs.ShiftShard = { Name = "Turncoat", Short = "Turncoat", IconKey = "mat_schematic", Color = Color3.fromRGB(110, 230, 170), Unlock = 18,
    Desc = "REROLL GUN at the Forge: a Rare or better gun becomes a random gun of your class. From the Tumbler and the free daily roll." }
ItemData.MaterialDefs.Graft = { Name = "Rivet", Short = "Rivet", IconKey = "mat_infusion", Color = Color3.fromRGB(120, 200, 255), Unlock = 18,
    Desc = "Adds one random line to an item with room for it (Uncommon: 2 lines, Rare: 6, Mythic: 7)." }
ItemData.MaterialDefs.StripShard = { Name = "Scrape", Short = "Scrape", IconKey = "mat_purge", Color = Color3.fromRGB(235, 235, 210), Unlock = 30,
    Desc = "Removes one random line from an item." }
ItemData.MaterialDefs.Temper = { Name = "Hone", Short = "Hone", IconKey = "mat_ascend", Color = Color3.fromRGB(255, 150, 70), Unlock = 45,
    Desc = "Raises one random line one tier, up to the highest tier the item's level allows." }
ItemData.MaterialDefs.StormCore = { Name = "Wildfire Core", Short = "Wildfire", IconKey = "mat_reforge", Color = Color3.fromRGB(170, 130, 255), Unlock = 45,
    Desc = "Rerolls everything on an item: how many lines (inside its rarity's band), which lines and their tiers. From bosses." }
ItemData.MaterialDefs.RiftDust = { Name = "Tuning Grit", Short = "Grit", IconKey = "mat_purge", Color = Color3.fromRGB(120, 200, 255), Unlock = 45,
    Desc = "Rerolls a Gunwright's lines (inventory, ITEMS tab). From salvaging Gunwrights, the Week's Quarry and the free daily roll." }
ItemData.MaterialDefs.RiftTaint = { Name = "Blackflux", Short = "Flux", IconKey = "mat_purge", Color = Color3.fromRGB(230, 70, 150), Unlock = 125, NoRoll = true,
    Desc = "REDLINE at the Forge: a gamble that pushes an item past its limit (nothing, a bonus line, a full reroll, or a line turns bad), then locks it for good. From map guardians and the Summit." }
-- (UPDATE 7 C1 APEX HUNT + C3 MAP INKS) not crafting currencies: kept out of CURRENCY_V5 (no forge chip / daily roll)
ItemData.APEX_MATS = { "CoordNorth", "CoordEast", "CoordSouth", "CoordWest" }
for _, k in ipairs(ItemData.APEX_MATS) do
    local dir = string.gsub(k, "Coord", "")
    ItemData.MaterialDefs[k] = { Name = "Bearing: " .. dir, Short = string.sub(dir, 1, 1), IconKey = "teleport", Color = Color3.fromRGB(255, 120, 160), Unlock = 125, NoRoll = true,
        Desc = "One of the four Bearings of the Summit. Map guardians drop them; one of each lets you CLIMB THE SUMMIT at your map device." }
end
do
    local okInks, MapInks = pcall(require, script.Parent:WaitForChild("MapInks"))
    ItemData.INK_MATS = {}
    if okInks then
        for _, k in ipairs(MapInks.Order) do
            local d = MapInks.Defs[k]
            ItemData.MaterialDefs[k] = { Name = d.Name, Short = d.Short, IconKey = "mat_catalyst", Color = d.Color, Unlock = MapInks.UNLOCK, NoRoll = true,
                Desc = "A SIGIL MARK: draw it onto a map at your map device (" .. d.Text .. "). Up to " .. MapInks.MAX_PER_MAP .. " a map, " .. (MapInks.MAX_PER_MAP + 1) .. " with the map tree's Wide Margins. From map guardians." }
            table.insert(ItemData.INK_MATS, k)
        end
    end
end
-- (UPDATE 7 B4 SHARED SPOILS) the party seal
ItemData.PARTY_MATS = { "SpoilsSeal" }
ItemData.MaterialDefs.SpoilsSeal = { Name = "Haul Tag", Short = "Tag", IconKey = "mat_reforge", Color = Color3.fromRGB(255, 205, 110), Unlock = 80, NoRoll = true,
    Desc = "Carry it into a PARTY run: when your party kills a boss, every member with a tag spends one, each tag adds two items to a shared chest and everyone who spent one picks an item. From elites and bosses." }
-- (2026-10-22 PAID REFUNDS) the passive-tree refund currency: one Unwind = one point back (or an Expertise pick changed)
-- without the gold cost (ItemData.RefundGold). Not a crafting currency: no forge chip, no daily roll.
ItemData.TREE_MATS = { "Unwind" }
ItemData.MaterialDefs.Unwind = { Name = "Unwind", Short = "Unwind", IconKey = "mat_rebirth", Color = Color3.fromRGB(150, 255, 210), NoRoll = true,
    Desc = "Refunds one passive tree point, or changes an Expertise pick, without paying gold. Rare: bosses sometimes drop one, and the first time you complete each difficulty gives one." }
for _, list in ipairs({ ItemData.CURRENCY_V5, ItemData.APEX_MATS, ItemData.INK_MATS, ItemData.PARTY_MATS, ItemData.TREE_MATS }) do
    for _, k in ipairs(list) do
        table.insert(ItemData.MaterialOrderAll, k)
        table.insert(ItemData.MaterialOrder, k)
    end
end
-- (UPDATE 7) can the daily roll / weekly stack hand this currency out? (unlocked, and not a top-end-only currency)
function ItemData.CurrencyRolls(key: string, level: number?): boolean
    local def = ItemData.MaterialDefs[key]
    return ItemData.MaterialUnlocked(key, level) and not (def and def.NoRoll)
end
-- is this material visible / usable at this level? (everything without an Unlock always is)
function ItemData.MaterialUnlocked(key: string, level: number?): boolean
    local def = ItemData.MaterialDefs[key]
    return not def or (level or 1) >= (def.Unlock or 1)
end
-- Storm Core from bosses (CombatServer kill rewards; x the loot quantity like every currency chance)
ItemData.STORM_CORE_CHANCE = { Boss = 0.06, SuperBoss = 0.15 }
-- CRAFTING v3 (0.75, owner: "crafting in general needs a massive nerf still, materials are too easy to get and allow for
-- too much. Having this much crafting removes the incentive to grind for something rare, because you can just fully get
-- every single attribute you want. I want it to copy path of exiles material system, where certain ones allow you to do
-- certain things"). Each currency does ONE thing, and the deterministic paths are gone:
--   Reforge Token  = Chaos Orb: reroll every affix          Tuning Kit = Divine Orb: reroll the numbers
--   Infusion Core  = Exalted Orb: add one RANDOM affix      Purge Salt = Annulment: remove one RANDOM affix (no choosing)
--   Affix Seal     = "cannot be changed": keeps ONE affix through a Reforge, cost x3 per sealed reforge of the item
--   Schematic      = Chance on a chosen base: the bench builds the base you pick at a RANDOM rarity (up to BenchMaxRank)
--   Prefix Catalyst / Fate Shard / Ascension Essence keep their single jobs.
-- And they're far rarer: every grant of these (kills, bosses, caches, runs, rifts, contracts, salvage) goes through
-- CombatServer.GrantMaterials, which scales it by CRAFT_SOURCE_MULT; dismantling no longer gives Seals, Cores or Salts.
ItemData.CRAFT_SOURCE_MULT = { ReforgeToken = 0.4, TuningKit = 0.4, PrefixCatalyst = 0.5, AffixSeal = 0.15, InfusionCore = 0.3,
    PurgeSalt = 0.4, Schematic = 0.35 }
for k in pairs(ItemData.RETIRED_MATERIALS) do ItemData.CRAFT_SOURCE_MULT[k] = 0 end -- (0.97: retired, never granted)
-- ASCENSION ESSENCE (owner: "incredibly rare ... the same rate of POE 1s" Exalted Orb): any monster can drop one, at a
-- flat tiny chance per kill (no quantity scaling); the ONLY source -- no boss / raid / rift / cache / dismantle guarantees
ItemData.ASCEND_ESSENCE_CHANCE = { Mob = 0.0001, Elite = 0.0005, Boss = 0.002, SuperBoss = 0.005 }
-- REBIRTH SHARD (passive tree v4, owner: "to change classes, lets add a rare currency that either drops or can be bought
-- with robux"): spent at the Skill Monolith to change class. Drops from bosses only (CombatServer kill rewards).
-- (owner 2026-10-05: "change class rebirth tokens to be a 5% chance from boss, still purchaseable with robux")
ItemData.REBIRTH_SHARD_CHANCE = { Boss = 0.05, SuperBoss = 0.05, Trial = 0.05 }
ItemData.RebirthShardProduct = { ProductId = 3718278545, Price = 99 } -- (Developer Product "Rebirth Shard", created 2026-10-13; store_icons/49)

-- PASSIVE POINTS v5 (2026-10-21, owner: "reset the skill tree, and made the nodes more notable while not giving away as
-- many" -> "Just follow path of exiles logic and scale it to our game"; was v4: 1 a level + 5 every 5th = 800 at 400). The
-- reference game: 1 point a level + quest points for finishing the story, ~9% of its tree by the level cap. Ours: 1 a level
-- (level 1 included) + TREE_CLEAR_POINTS for each difficulty COMPLETED the first time (the clear that unlocks the next one,
-- ItemData.DifficultyCleared) = 400 + 28 = 428 at 400 with every tier done (~11% of the 4,000-node tree; our tree spreads five
-- classes, so a build reaches about the same share of its own region). Node values follow (gen_tree_v4 NODE VALUES v5).
-- TreePointsAt(level) = the level part; TreePointsTotal(state) = everything the character has earned.
ItemData.TREE_CLEAR_POINTS = 2
function ItemData.TreePointsForLevelUp(newLevel: number): number
    return 1
end
function ItemData.TreePointsAt(level: number): number
    return math.max(1, math.floor(level or 1))
end
function ItemData.DifficultyCleared(st: any, diff: string): boolean
    local best = type(st) == "table" and type(st.FloorsByDifficulty) == "table" and tonumber(st.FloorsByDifficulty[diff]) or 0
    local m = DifficultyModes[diff]
    return best >= ((m and m.MaxWaves) or 5)
end
function ItemData.TreeClearPoints(state: any): number
    local st = type(state) == "table" and state.StatsTracking or nil
    local n = 0
    for _, d in ipairs(ItemData.DifficultyOrder) do
        if ItemData.DifficultyCleared(st, d) then n += 1 end
    end
    return n * ItemData.TREE_CLEAR_POINTS
end
-- for sims (DevCmd treesim / powercurve, tools/sim/classbal): the points a TYPICAL character of this level has -- every
-- difficulty whose next tier it has reached the level for counts as completed (the last one from the level cap)
function ItemData.TreePointsTypical(level: number): number
    local lv = math.max(1, math.floor(level or 1))
    local order, n = ItemData.DifficultyOrder, 0
    for i, d in ipairs(order) do
        local nxt = order[i + 1]
        if (nxt and lv >= (ItemData.DifficultyMinLevel[nxt] or 1)) or (not nxt and lv >= ItemData.MAX_LEVEL) then n += 1 end
    end
    return ItemData.TreePointsAt(lv) + n * ItemData.TREE_CLEAR_POINTS
end
function ItemData.TreePointsTotal(state: any): number
    return ItemData.TreePointsAt(type(state) == "table" and state.Level or 1) + ItemData.TreeClearPoints(state)
end
-- PAID REFUNDS (2026-10-22, owner: "Lets work on the not done parts now"; the reference game's per-point refunds, scaled):
-- every refunded passive point (single refund, full respec, an Expertise pick changed or taken back) costs ONE Unwind if
-- you have one, else RefundGold(level). Free through REFUND_FREE_LEVEL while you learn the tree. A full respec costs the
-- same per point as single refunds (no bulk discount: like the reference game, a whole new build is a real cost).
-- Unwinds: UNWIND_PER_CLEAR for each difficulty completed the first time (beside its +2 points), UNWIND_CHANCE from
-- bosses, UNWIND_RESET_GIFT to everyone whose tree the v5 reset refunded.
-- (owner 2026-10-22: "Refunding should not be cheap at all" -> 6 x level gold a point became 50 x level (L100: 5,000 a point, a
-- 110-point respec 550K; L400: 20,000, a full respec ~8.6M -- the guild / Calibration gold sinks' scale), free only to level 10,
-- Unwinds rare: bosses 12 / 25% -> 3 / 8%, 1 per first difficulty completion (was 2), reset gift 5 (was 10).)
ItemData.REFUND_FREE_LEVEL = 10
ItemData.REFUND_GOLD_PER_LEVEL = 50
ItemData.UNWIND_PER_CLEAR = 1
ItemData.UNWIND_RESET_GIFT = 5
ItemData.UNWIND_CHANCE = { Boss = 0.03, SuperBoss = 0.08, Trial = 0.08 }
function ItemData.RefundGold(level: number?): number
    local lv = math.floor(level or 1)
    if lv <= ItemData.REFUND_FREE_LEVEL then return 0 end
    return ItemData.REFUND_GOLD_PER_LEVEL * lv
end
-- what refunding n points costs this state: Unwinds first, gold for the rest -> (unwinds used, gold)
function ItemData.RefundCost(state: any, n: number): (number, number)
    local per = ItemData.RefundGold(state and state.Level)
    if per <= 0 then return 0, 0 end
    local have = math.max(0, math.floor(((state and state.Materials) or {}).Unwind or 0))
    local u = math.min(have, n)
    return u, (n - u) * per
end
-- ATTRIBUTE POINTS v2 (2026-10-05): 1 a level + 4 more on every 10th level; a new character has 3 to spend
-- (StatCalculator ATTRIBUTES v2 / ATTR_CEILINGS). AttrPointsAt(level) = the total a character of that level has had.
-- (UPDATE 8 OFFENSE phase 4: hand-placed attribute points are GONE -- attributes come from the tree + gear; both return 0)
function ItemData.AttrPointsForLevelUp(newLevel: number): number
    local _ = newLevel
    return 0
end
function ItemData.AttrPointsAt(level: number): number
    local _ = level
    return 0
end
function ItemData.NewMaterials(): { [string]: number }
    local m = {}
    for _, k in ipairs(ItemData.MaterialOrder) do m[k] = 0 end
    return m
end

-- Upgrades: +5% weapon damage per level; every 5th level also raises one affix a tier.
ItemData.UPGRADE_DAMAGE_PER_LEVEL = 0.05
ItemData.UpgradeCap = { Relic = 20, Common = 5, Uncommon = 5, Rare = 12, Epic = 12, Legendary = 16, Mythic = 20, Celestial = 20, Transcendent = 20,
    Astral = 20, Empyrean = 20, Primordial = 20, Sovereign = 20, Eclipse = 20, Genesis = 20, Infinite = 20 }
ItemData.UpgradeCostMult = { Relic = 6, Common = 1, Uncommon = 1.5, Rare = 3, Epic = 3, Legendary = 4, Mythic = 6, Celestial = 8, Transcendent = 10,
    Astral = 12, Empyrean = 14, Primordial = 16, Sovereign = 18, Eclipse = 20, Genesis = 22, Infinite = 25 }
-- Cost and success chance of the step to `target` (1..20). A failed attempt uses up half the materials
-- (rounded down) and the gold; the weapon never loses levels or breaks.
function ItemData.UpgradeStepCost(rarity: string, target: number): { Material: string, Amount: number, Gold: number, Chance: number }
    local mult = ItemData.UpgradeCostMult[rarity] or 1
    local mat, base, chance
    if target <= 5 then
        mat, base, chance = "Scrap", 10 * 1.4 ^ (target - 1), 1.0
    elseif target <= 12 then
        mat, base, chance = "Alloy", 3 * 1.3 ^ (target - 6), (target <= 8) and 0.85 or 0.70
    else
        mat, base, chance = "Prism", 2 * 1.35 ^ (target - 13), (target <= 16) and 0.55 or 0.40
    end
    -- (0.97 CRAFTING v4, owner: "Make the upgrading more expensive too"): materials x UPGRADE_COST_K, gold x UPGRADE_GOLD_K
    -- (LOOT SCARCITY 2026-11-07: x LOOT_SCARCITY.UpgradeK per material -- the Alloy / Prism steps are the long investment)
    local k = ItemData.Scarce() and (ItemData.LOOT_SCARCITY.UpgradeK[mat] or 1) or 1
    return { Material = mat, Amount = math.max(1, math.round(base * mult * ItemData.UPGRADE_COST_K * k)),
        Gold = math.round(100 * target * mult * ItemData.UPGRADE_GOLD_K), Chance = chance }
end
ItemData.UPGRADE_COST_K = 1.75
ItemData.UPGRADE_GOLD_K = 2
-- AFFIX REROLL (0.97 CRAFTING v4, owner: "Affix rolling should no longer be lockable, and each roll should be incredibly
-- expensive, make it use prisms and each reroll scales in price like terraria"): Prism Shards = REROLL_PRISM[rarity] x
-- REROLL_GROWTH ^ (rerolls this item has had), + the sell value x (1 + 0.5 per earlier reroll) in gold. item.Rerolls is
-- saved on the item (trading a gun hands its price on with it). Weapons and gear; exotic gear can't be rerolled.
ItemData.REROLL_PRISM = { Relic = 34, Uncommon = 4, Rare = 14, Epic = 14, Legendary = 22, Mythic = 34, Celestial = 48, Transcendent = 64, Astral = 80,
    Empyrean = 96, Primordial = 112, Sovereign = 128, Eclipse = 144, Genesis = 160, Infinite = 180 }
ItemData.REROLL_GROWTH = 1.5
-- (0.97 UPDATE 3, owner: "The affix rolling is still FAR too easy. It should be considerably expensive (and also scale with
-- player level / rarity of gun) ... for anyone whos midgame + it will be easy to spam reroll"): the Prism price also
-- grows with level -- the higher of the item's level and yours (x1 at level 1, x5 at 100, x17 at 400) -- because Prism
-- income grows with the tiers you farm. Example: a level-80 Legendary costs 92 Prisms, then 138, 207, 311 ...
ItemData.REROLL_LEVEL_DIV = 25
function ItemData.RerollCost(item: any, isGear: boolean?, playerLevel: number?): { [string]: number }
    local n = math.max(0, math.floor(tonumber(item and item.Rerolls) or 0))
    local base = ItemData.REROLL_PRISM[item and item.Rarity or ""] or 4
    local lvl = math.max(tonumber(item and item.ItemLevel) or 1, tonumber(playerLevel) or 1)
    local sell = isGear and ItemData.GetGearSellValue(item) or ItemData.GetSellValue(item)
    return { Prism = math.ceil(base * (1 + lvl / ItemData.REROLL_LEVEL_DIV) * ItemData.REROLL_GROWTH ^ n), Gold = math.round(sell * 2 * (1 + n)) }
end

-- Raises one affix a tier (the lowest one below T5), keeping where in the range it rolled.
function ItemData.BumpAffixTier(weapon: WeaponInstance): boolean
    local lowest: any = nil
    for _, list in ipairs({ weapon.Prefixes or {}, weapon.Suffixes or {} }) do
        for _, a in ipairs(list) do
            if not a.Negative and AffixDefByStat[a.Stat] and (a.Tier or 1) < 5 and (not lowest or (a.Tier or 1) < (lowest.Tier or 1)) then lowest = a end
        end
    end
    if not lowest then return false end
    local fresh = MakeAffix(AffixDefByStat[lowest.Stat], (lowest.Tier or 1) + 1, lowest.Roll or 0.5)
    for k, v in pairs(fresh :: any) do lowest[k] = v end
    return true
end

local function RenameWeapon(weapon: any)
    if weapon.Uid ~= "W_STARTER_PISTOL" then
        weapon.Name = WeaponName(weapon.BaseId, weapon.Prefixes, weapon.Proc, weapon.Suffixes, weapon.MythicName)
    end
end

ItemData.RefreshWeaponName = RenameWeapon

-- REROLL GUN (fixes 2026-10-16 #2, playtester: "getting a rare drop and immediately scrapping it because its not my class
-- doesn't feel good"; owner: a random gun of YOUR class): a Rare+ gun becomes a RANDOM other gun of your class's weapon
-- group -- same rarity, item level and unique power (+ its Mythic name), fresh affixes + prefix. Upgrades reset (they
-- were tied to the old affixes); lock and reroll count stay. You never pick the gun (crafting stays random).
-- Prism = 1.5 x the item's first affix reroll price (same level scaling), gold = 3 x the sell value.
ItemData.RETYPE_PRISM_MULT = 1.5
function ItemData.RetypePool(group: string?, exceptBase: string?): { string }
    local pool = {}
    for _, id in ipairs(ItemData.Lineup) do
        local b = BaseWeapons[id]
        if b and not b.TestOnly and not b.Legacy and id ~= exceptBase and ItemData.WeaponGroupOf({ BaseId = id, Class = b.Class }) == group then
            table.insert(pool, id)
        end
    end
    return pool
end
function ItemData.CanRetype(item: any, group: string?): (boolean, string?)
    if not item or not item.BaseId then return false, "Pick a weapon." end
    if item.Twinned then return false, "Twinned items can't be crafted." end -- (CHASE ITEMS: Twin Glass)
    if item.Exotic then return false, "Relic weapons keep their gun." end
    if item.Uid == "W_STARTER_PISTOL" then return false, "The starter pistol can't be rerolled." end
    if item.Overcharged then return false, "Redlined guns can't be changed." end
    for _, a in ipairs(ItemData.LinesOf(item, false)) do if a.Etched then return false, "Hallmarked guns keep their gun (the hallmark is part of it)." end end
    if (RarityRank[item.Rarity] or 1) < 3 then return false, "Rare and better only." end
    if not group then return false, "Pick a class at the Skill Tree first." end
    if #ItemData.RetypePool(group, item.BaseId) == 0 then return false, "No other gun in your class." end
    return true, nil
end
-- (CRAFTING v5: one Shift Shard + 3x the sell value in gold; it cost Prism for its first day)
function ItemData.RetypeCost(item: any, _playerLevel: number?): { [string]: number }
    return { ShiftShard = 1, Gold = math.round(ItemData.GetSellValue(item) * 3) }
end
-- turns `item` (in place: same Uid) into a random other gun of `group`; returns false if it can't
function ItemData.RetypeWeapon(item: any, group: string): boolean
    local pool = ItemData.RetypePool(group, item.BaseId)
    if #pool == 0 then return false end
    local fresh = ItemData.GenerateWeaponOfBase(pool[math.random(1, #pool)], item.Rarity, item.ItemLevel)
    if not fresh then return false end
    local keep = { Uid = item.Uid, Locked = item.Locked, Rerolls = item.Rerolls, UniqueTrait = item.UniqueTrait, MythicName = item.MythicName }
    for k in pairs(item) do item[k] = nil end
    for k, v in pairs(fresh) do item[k] = v end
    for k, v in pairs(keep) do item[k] = v end
    RenameWeapon(item)
    return true
end
-- GUN NAMES WITHOUT MAKERS (owner 2026-10-04: "AUG instead of Steyr AUG"): item names are saved, so items named before
-- the change get the maker dropped on load (CombatServer state load). Old short name -> new.
ItemData.OldGunNames = { { "Glock 17", "G17" }, { "Benelli M4", "M4 Super 90" }, { "Barrett", "M82" }, { "Colt 1911", "1911" },
    { "Ithaca M37", "M37" }, { "Remington 870", "870 Classic" } }
-- GUN BALANCE 2026-10-05 (owner: "Snipers and shotguns are kind of overpowered"): measured base DPS -- shotguns ~44 vs rifles
-- ~35 / SMGs ~31; snipers' sustained weak-spot DPS 107-139 vs rifles ~40 (a 4-4.5x weak-spot multiplier on huge hits, plus
-- pierce). Shotguns -> rifle DPS; sniper damage -14% and weak-spot 3.0-3.2x (still the best precision payoff). Saved guns
-- carry their own BaseDamage / BaseWeakSpotMultiplier, so ItemData.MigrateGunBalance rescales them once (w.BalV).
ItemData.GUN_BALANCE = {
    R870 = { Dmg = 3.3 / 4.1 }, BM4 = { Dmg = 1.3 / 1.6 }, AA12 = { Dmg = 0.9 / 1.1 },
    AWP = { Dmg = 52 / 60, WS = 3.2 }, M82 = { Dmg = 24 / 28, WS = 3.0 }, SCOUT = { Dmg = 38 / 44, WS = 3.0 },
}
ItemData.GUN_BALANCE_V = 1
-- GUN TUNE (2026-10-22, gun-by-gun pass with tools/sim/classbal/gunsweep.py): every lineup gun on its class's tree, same
-- gear, sustained kill time vs its class's median at L20 / 100 / 250 / 400. Outliers were the Railgun ~0.63 (1.6x faster than
-- the other beams), Void Disintegrator ~0.73, Double Barrel ~0.69, and AA-12 / USAS-12 / BM4 / TEC-9 / SKS / F2000 / the two
-- full-auto beams 1.1-1.3 slower. A damage multiplier read AT USE (StatCalculator, CalculateTrueDPS, tooltips via
-- ItemData.GunDamage), so every saved gun -- bag, stash tabs, Exchange listings -- changes at once with no save migration.
-- Hard-to-use guns keep a small edge (Railgun / Double Barrel land ~0.9 of the median). LMGs (~0.85) were left: they pay
-- with mobility 0.85-0.88. The class table's Shotgun + Beam rows were divided by the BM4 / BEAM factors (their reference guns).
ItemData.GUN_TUNE = { Railgun = 0.72, VoidDisintegrator = 0.77, DBARREL = 0.77, BEAM = 1.6, --[[ BEAM 1.09 -> 1.6 (Phase 6: the Arc Projector was ~45% of the AK at L50) ]] ContinuousLaser = 1.08,
    AA12 = 1.17, USAS12 = 1.12, BM4 = 1.07, TEC9 = 1.13, SKS = 1.17, F2000 = 1.08 }
function ItemData.GunTune(w: any): number
    local id = type(w) == "table" and w.BaseId or w
    return ((id and ItemData.GUN_TUNE[id]) or 1) * (ItemData.FamilyTune and ItemData.FamilyTune(id) or 1) -- (CLASS BUILDS) FAMILY: x the family's Tune
end
-- a gun's base damage as it fires (saved BaseDamage x GUN_TUNE; no upgrade level)
function ItemData.GunDamage(w: any): number
    return ((type(w) == "table" and w.BaseDamage) or 0) * ItemData.GunTune(w)
end
function ItemData.MigrateGunBalance(state: any)
    if type(state) ~= "table" then return end
    local function fix(w)
        if type(w) ~= "table" or (w.BalV or 0) >= ItemData.GUN_BALANCE_V then return end
        w.BalV = ItemData.GUN_BALANCE_V
        local b = w.BaseId and ItemData.GUN_BALANCE[w.BaseId]
        if not b then return end
        if b.Dmg and type(w.BaseDamage) == "number" then w.BaseDamage = math.round(w.BaseDamage * b.Dmg * 100) / 100 end
        if b.WS then w.BaseWeakSpotMultiplier = b.WS end
    end
    fix(state.EquippedWeapon)
    for _, w in ipairs(type(state.Inventory) == "table" and state.Inventory or {}) do fix(w) end
    for _, l in ipairs(type(state.LostLoot) == "table" and state.LostLoot or {}) do if type(l) == "table" then fix(l.Item) end end
    for _, d in pairs(type(state.PendingLoot) == "table" and state.PendingLoot or {}) do if type(d) == "table" then fix(d.Item) end end
end

-- GUN NAMES = THE MODEL (2026-10-24, owner: "some guns are not named correctly (i.e. f2000 is a famas)"): the display name
-- follows the real gun each v2 model actually is (docs/CREDITS_GUNS_V2.md). BaseIds / saves / remotes are unchanged; saved
-- item names (and Riftmods' "<gun> Gunwright") are fixed per BaseId on load. [BaseId] = { old short name, new }
ItemData.GunRenames = {
    Glock17 = { "G17", "G19" }, SCAR = { "SCAR-H", "SCAR-L" }, F2000 = { "F2000", "FAMAS" }, AA12 = { "Saiga-12", "AA-12" }, -- (2026-10-29: back to AA-12 with the new DU1701 model)
    USAS12 = { "USAS-12", "Komrad 12" }, KSG = { "KSG", "KS7" }, AWP = { "AWP", "AWM" }, SCOUT = { "Scout", "Hunting Rifle" },
    SR9 = { "SR9", "P99" }, EMR = { "EMR", "M14" }, MK11 = { "Mk 11", "M110" },
}
function ItemData.FixGunName(w: any)
    if type(w) ~= "table" or type(w.Name) ~= "string" then return end
    if w.BaseId ~= nil then
        for _, p in ipairs(ItemData.OldGunNames) do
            local i, j = string.find(w.Name, p[1], 1, true)
            if i then w.Name = string.sub(w.Name, 1, i - 1) .. p[2] .. string.sub(w.Name, j + 1) end
        end
    end
    local r = (not w.MythicName) and ItemData.GunRenames[w.BaseId or w.Gun or ""]
    if r and not string.find(w.Name, r[2], 1, true) then
        local i, j = string.find(w.Name, r[1], 1, true)
        if i then w.Name = string.sub(w.Name, 1, i - 1) .. r[2] .. string.sub(w.Name, j + 1) end
    end
end
function ItemData.MigrateGunNames(state: any)
    if type(state) ~= "table" then return end
    local fix = ItemData.FixGunName
    local function list(l) if type(l) == "table" then for _, it in pairs(l) do fix(it) end end end
    fix(state.EquippedWeapon)
    list(state.Inventory)
    list(state.Riftmods)
    for _, l in ipairs(type(state.LostLoot) == "table" and state.LostLoot or {}) do if type(l) == "table" then fix(l.Item) end end
    for _, d in pairs(type(state.PendingLoot) == "table" and state.PendingLoot or {}) do if type(d) == "table" then fix(d.Item) end end
    if type(state.PvpEscrow) == "table" then for _, e in ipairs(type(state.PvpEscrow.Items) == "table" and state.PvpEscrow.Items or {}) do if type(e) == "table" then fix(e.Item) end end end
    local h = type(state.Hideout) == "table" and state.Hideout or nil
    if h then
        if type(h.Stash) == "table" then list(h.Stash.W) end
        for _, t in ipairs(type(h.Tabs) == "table" and h.Tabs or {}) do if type(t) == "table" then list(t.W) end end
    end
end

-- ===== RARITY v4 SAVE NORMALISATION (UPDATE 8 LOOT; the ONE place old rarity names are fixed, called on load next to
-- MigrateGunNames). Never bumps SAVE_VERSION. Epic / Legendary -> Rare, Mythic .. Infinite -> Mythic, any exotic -> Relic.
-- Skill-tree GEMS keep the old ladder (GemData, until Phase 3). Settings that name a rarity: the weapon auto-sell threshold
-- never lands on Rare (an old "Rare" / "Epic" ... threshold becomes Uncommon: it would sell the new workhorse), Loot Lens rules
-- take the new name, the Ledger's rarity page is re-keyed once (Archive.RarityV = 4).
function ItemData.NormRarity(r: any): string?
    if type(r) ~= "string" then return nil end
    if rawget(ItemData.RarityRank, r) then return r end
    return ItemData.RARITY_ALIAS[r] or r
end
function ItemData.NormalizeItemRarity(item: any): boolean
    if type(item) ~= "table" or item.Kind == "Gem" or item.Kind == "Riftmod" then return false end
    local want = item.Exotic and "Relic" or ItemData.NormRarity(item.Rarity)
    if want and want ~= item.Rarity then item.Rarity = want; return true end
    return false
end
function ItemData.NormalizeRarities(state: any): number
    if type(state) ~= "table" then return 0 end
    local n = 0
    local function fix(it)
        if ItemData.NormalizeItemRarity(it) then n += 1 end
        -- (UPDATE 8 originality: a weapon's saved trait copy takes the catalog's current name / text -- "Headhunter" -> "Crownshot")
        local ut = type(it) == "table" and type(it.UniqueTrait) == "table" and it.UniqueTrait or nil
        local cur = ut and ItemData.TraitById[ut.Id]
        if cur and (ut.Name ~= cur.Name or ut.Description ~= cur.Description) then ut.Name, ut.Description = cur.Name, cur.Description end
    end
    local function list(l) if type(l) == "table" then for _, it in pairs(l) do fix(it) end end end
    fix(state.EquippedWeapon)
    list(state.Inventory)
    list(state.GearInventory)
    list(state.EquippedGear)
    for _, l in ipairs(type(state.LostLoot) == "table" and state.LostLoot or {}) do if type(l) == "table" then fix(l.Item) end end
    for _, d in pairs(type(state.PendingLoot) == "table" and state.PendingLoot or {}) do if type(d) == "table" and d.Kind ~= "Gem" then fix(d.Item) end end
    if type(state.PvpEscrow) == "table" then for _, e in ipairs(type(state.PvpEscrow.Items) == "table" and state.PvpEscrow.Items or {}) do if type(e) == "table" then fix(e.Item) end end end
    local h = type(state.Hideout) == "table" and state.Hideout or nil
    if h then
        if type(h.Stash) == "table" then list(h.Stash.W); list(h.Stash.G) end
        for _, t in ipairs(type(h.Tabs) == "table" and h.Tabs or {}) do if type(t) == "table" then list(t.W); list(t.G) end end
    end
    -- settings that name a rarity
    -- (UPDATE 8 GEM GRADES v4) gems + the gem auto-salvage threshold onto the 5 rarities (GemData.NormalizeState)
    local okG, GemData = pcall(require, script.Parent:FindFirstChild("GemData"))
    if okG and type(GemData) == "table" and GemData.NormalizeState then n += GemData.NormalizeState(state) end
    if not state.AutoSellV4 then -- (once per save: SaveService PLAIN_FIELDS keeps the flag, so a new "Rare" choice stays)
        local th = state.AutoSellThreshold
        if type(th) == "string" and (ItemData.LegacyRank[th] or 0) >= 3 then state.AutoSellThreshold = "Uncommon" end
        state.AutoSellV4 = true
    end
    for _, r in ipairs(type(state.DropRules) == "table" and state.DropRules or {}) do
        if type(r) == "table" and type(r.R) == "string" then r.R = ItemData.NormRarity(r.R) or r.R end
    end
    local a = type(state.Archive) == "table" and state.Archive or nil
    if a and type(a.Rarity) == "table" and a.RarityV ~= 4 then
        local new = {}
        for k, v in pairs(a.Rarity) do
            local old = ItemData.LEGACY_RARITIES[tonumber(k) or 0]
            local nr = old and ItemData.RarityRank[ItemData.NormRarity(old) or ""] or nil
            if v and nr then new[tostring(nr)] = true end
        end
        a.Rarity = new
        a.RarityV = 4
    end
    return n
end

-- Crafting currency costs per use.
ItemData.ReforgeCost = { Rare = 1, Epic = 2, Legendary = 3, Mythic = 5, Celestial = 7, Transcendent = 10, Astral = 12, Empyrean = 14, Primordial = 16,
    Sovereign = 18, Eclipse = 20, Genesis = 22, Infinite = 25 } -- Reforge Tokens (Common/Uncommon can't be rerolled)
ItemData.CRAFT_GOLD_MULT = 1.0 -- + sell price x this in gold per craft
-- Codex of Power imprint cost in Prism Shards (+ the craft gold), by the target weapon's rarity.
ItemData.ImprintCost = { Relic = 8, Rare = 3, Epic = 4, Legendary = 6, Mythic = 8, Celestial = 10, Transcendent = 12, Astral = 13, Empyrean = 14, Primordial = 15,
    Sovereign = 16, Eclipse = 17, Genesis = 18, Infinite = 20 }

-- Reforge Token: rerolls every affix (same count, rarity, level, upgrades); upgrade tier bumps are re-applied.
function ItemData.RerollWeaponAffixes(weapon: WeaponInstance, _luck: number?): WeaponInstance
    local count = #(weapon.Prefixes or {}) + #(weapon.Suffixes or {})
    local lo = ItemData.LineBand(weapon.Rarity) -- (ITEM SCALING v2: same count, at least the band's minimum; legacy counts kept)
    weapon.Prefixes, weapon.Suffixes = RollWeaponAffixSet(weapon.Rarity, weapon.ItemLevel or 1, math.max(count, lo), weapon.BaseId)
    for _ = 1, (weapon :: any).TierBumps or 0 do ItemData.BumpAffixTier(weapon) end
    RenameWeapon(weapon)
    return weapon
end

-- Tuning Kit: new numbers within each affix's current tier.
function ItemData.TuneWeaponAffixes(weapon: WeaponInstance): WeaponInstance
    for _, list in ipairs({ weapon.Prefixes or {}, weapon.Suffixes or {} }) do
        for _, a in ipairs(list) do
            local def = not a.Negative and not a.Etched and not a.Exotic and AffixDefByStat[a.Stat] -- (UPDATE 7 SET LINES: etched lines never change; UPDATE 8: relic lines reroll in their own range)
            if a.Exotic and ItemData.TuneRelicLine then ItemData.TuneRelicLine(a) end
            if def then
                local fresh = MakeAffix(def, a.Tier or 1)
                for k, v in pairs(fresh :: any) do a[k] = v end
            end
        end
    end
    return weapon
end

-- (CRAFTING v5) Prism REROLL VALUES on gear: the same lines and tiers, new numbers inside each tier
function ItemData.TuneGearLines(gear: any): any
    local slotType = ItemData.GearType(gear.Slot)
    local pool = ItemData.GearPoolOf(gear, slotType)
    for _, line in ipairs(gear.StatLines or {}) do
        local raw = nil
        for _, d in ipairs(pool) do if d.Stat == line.Stat then raw = d break end end
        if line.Exotic and ItemData.TuneRelicLine then ItemData.TuneRelicLine(line) end -- (UPDATE 8 LOOT: a relic line in its own range)
        if raw and not line.Exotic and not line.Etched then
            local pos = math.random()
            local v = (raw.Min + pos * (raw.Max - raw.Min)) * AffixTier(gear.Rarity) * ItemData.GearTierMult(line.Tier or 1)
            local def = StatDefs[raw.Stat]
            if def and def.Kind == "flat" then v *= ItemData.LevelCurve(gear.ItemLevel or 1) else v *= ItemData.GearLevelScale(gear.ItemLevel or 1) end
            if gear.Base then v *= ItemData.GEAR_V3_LINE_SCALE end -- (UPDATE 8 LOOT: v3 lines carry the line scale, like a drop)
            line.Value = RoundStat(raw.Stat, v)
            line.Roll = math.round(pos * 100) / 100
        end
    end
    return gear
end
-- (QOL F3 2026-10-28) AFFIX RANGES: hold ALT over an item tooltip -> every line shows the min-max it can roll at its tier (the same
-- formulas REROLL VALUES / Tune use). ItemData.LineRange(item, line, isGear) -> lo, hi (nil = no range: implicit, build line, fixed relic
-- line); ItemData.ShowRanges (client only, set while ALT is held) makes DescribeWeapon / DescribeGear add "  [lo-hi]" via RangeSuffix.
ItemData.ShowRanges = false
function ItemData.LineRange(item: any, line: any, isGear: boolean?): (number?, number?)
    if type(item) ~= "table" or type(line) ~= "table" or not line.Stat then return nil, nil end
    if line.Exotic then
        if tonumber(line.RLo) and tonumber(line.RHi) and line.RHi > line.RLo then return line.RLo, line.RHi end
        return nil, nil
    end
    local t = math.abs(tonumber(line.Tier) or 1)
    if line.Negative then
        for _, d in ipairs(ItemData.NegativeAffixPool or {}) do
            if d.Stat == line.Stat and d.Lo and d.Hi then
                local lo = d.Lo + (d.Hi - d.Lo) * (t - 1) / 5
                local hi = d.Lo + (d.Hi - d.Lo) * t / 5
                return -RoundStat(line.Stat, hi), -RoundStat(line.Stat, lo)
            end
        end
        return nil, nil
    end
    if not isGear then
        local def = AffixDefByStat[line.Stat]
        if not def then return nil, nil end
        return AffixValue(def, t, 0), AffixValue(def, t, 1)
    end
    local pool = ItemData.GearPoolOf(item, ItemData.GearType(item.Slot))
    local raw = nil
    for _, d in ipairs(pool or {}) do if d.Stat == line.Stat then raw = d break end end
    if not raw or not raw.Min or not raw.Max then return nil, nil end
    local function At(pos: number): number
        local v = (raw.Min + pos * (raw.Max - raw.Min)) * AffixTier(item.Rarity) * ItemData.GearTierMult(t)
        local sd = StatDefs[raw.Stat]
        if sd and sd.Kind == "flat" then v *= ItemData.LevelCurve(item.ItemLevel or 1) else v *= ItemData.GearLevelScale(item.ItemLevel or 1) end
        if item.Base then v *= ItemData.GEAR_V3_LINE_SCALE end
        return RoundStat(raw.Stat, v)
    end
    return At(0), At(1)
end
function ItemData.RangeSuffix(item: any, line: any, isGear: boolean?): string
    if not ItemData.ShowRanges then return "" end
    local ok, lo, hi = pcall(ItemData.LineRange, item, line, isGear)
    if not ok or lo == nil or hi == nil then return "" end
    if lo > hi then lo, hi = hi, lo end
    local def = StatDefs[line.Stat]
    if def and def.Format then return "  [" .. ItemData.FormatStat(line.Stat, lo) .. " to " .. ItemData.FormatStat(line.Stat, hi) .. "]" end
    if def and def.Kind == "pct" then return "  [" .. FormatNumber(lo * 100) .. " to " .. FormatNumber(hi * 100) .. "%]" end
    return "  [" .. FormatNumber(lo) .. " to " .. FormatNumber(hi) .. "]"
end
-- SET LINES (UPDATE 7 C4, vault rename of "fractured items"; placeholder): from level ETCH_UNLOCK a drop with lines has ETCH_CHANCE
-- to come with one line ETCHED into the metal (line.Etched): no currency changes it -- REROLL VALUES keeps its number, Strip /
-- Temper skip it, a Storm Core rerolls everything else, REROLL GUN refuses the gun. A locked good line = a valuable crafting base.
ItemData.ETCH_UNLOCK = 125
ItemData.ETCH_CHANCE = 0.02
ItemData.ETCH_COLOR = Color3.fromRGB(230, 200, 140)
function ItemData.TryEtch(item: any, isGear: boolean?, level: number?): boolean
    if (level or 1) < ItemData.ETCH_UNLOCK or math.random() >= ItemData.ETCH_CHANCE or type(item) ~= "table" or item.Exotic then return false end
    local cands = {}
    for _, l in ipairs(ItemData.LinesOf(item, isGear)) do if not l.Negative and not l.Exotic then table.insert(cands, l) end end
    if #cands == 0 then return false end
    cands[math.random(1, #cands)].Etched = true
    return true
end
-- CRAFTING v5 jobs. CraftV5Check(action, item, isGear) -> ok, why (the button + the server both ask it);
-- CraftV5Apply(action, item, isGear) -> message (call only after a passing check). action = Graft / Strip / Temper / Storm.
ItemData.CRAFT_V5_KEY = { Graft = "Graft", Strip = "StripShard", Temper = "Temper", Storm = "StormCore", Retype = "ShiftShard", Overcharge = "RiftTaint",
    Ascend = "AscensionEssence", -- (UPDATE 8 RARITY v4: ASCEND = Rare -> Mythic + the Mythic line)
    Sockets = "SocketBore", Links = "SocketSolder", Colours = "SocketTint" } -- (UPDATE 8 LOOT: the three socket currencies)
-- (UPDATE 8 RARITY v4) loot currencies outside CURRENCY_V5 (no daily roll): forge chips + F6 GIFTS rows read this
ItemData.LOOT_MATS = { "AscensionEssence", "SocketBore", "SocketSolder", "SocketTint", "ModBurnish" }
-- BURNISH (UPDATE 8 LOOT): + BURNISH_MIN..MAX quality on one shot mod (in the bag), one random roll, up to ShotMods.MAX_QUALITY
-- (each point = +0.5% more damage). Rare: BURNISH_CHANCE per kill. Used from the MODS window (ShotModAction "Burnish").
ItemData.BURNISH_MIN, ItemData.BURNISH_MAX = 1, 5
ItemData.BURNISH_CHANCE = { Mob = 0.0008, Elite = 0.006, Boss = 0.04, SuperBoss = 0.1 }
ItemData.MaterialDefs.ModBurnish = { Name = "Burnish", Short = "Burnish", IconKey = "mat_ascend", Color = Color3.fromRGB(255, 225, 140), Unlock = 10, NoRoll = true,
    Desc = "Adds 1-5% quality to a shot mod in your bag (MODS window), up to 20%. Each 1% = +0.5% more damage. Rare: any kill can drop one." }
for _, k in ipairs(ItemData.LOOT_MATS) do -- (the bag / toasts / save defaults read MaterialOrder)
    if not table.find(ItemData.MaterialOrder, k) then table.insert(ItemData.MaterialOrderAll, k); table.insert(ItemData.MaterialOrder, k) end
end
-- SOCKET CURRENCIES (UPDATE 8 LOOT, PoE's socket orbs in our words; one random job each, guns only): BORE BIT rerolls how many
-- sockets (rarity + item level, like a drop), SOLDER rerolls which neighbours are linked, TINT rerolls the colours (leaning to
-- the gun's colour weights: ItemData.SocketColourWeights). Each always CHANGES something when it can. A shot mod that no
-- longer fits goes back to your mod bag (CombatServer). Relics keep their fixed sockets. Drops: SOCKET_CUR_CHANCE per kill
-- (loot quantity doesn't touch it), one of the three by SOCKET_CUR_WEIGHT; kills are the only source.
ItemData.SOCKET_CUR_CHANCE = { Mob = 0.002, Elite = 0.012, Boss = 0.06, SuperBoss = 0.15 }
ItemData.SOCKET_CUR_WEIGHT = { { "SocketTint", 0.45 }, { "SocketBore", 0.35 }, { "SocketSolder", 0.20 } }
-- (FUTURE-PROOF 2026-10-25) one pick from a { { id, weight }, ... } list by its weights' SUM (a new entry no longer skews the
-- others: the old loops assumed the weights add up to 1). fallback = the id when the list is empty.
function ItemData.PickWeighted(list: { any }, fallback: any?): any
    local total = 0
    for _, e in ipairs(list) do total += math.max(0, tonumber(e[2]) or 0) end
    if total <= 0 then return fallback end
    local x = math.random() * total
    for _, e in ipairs(list) do
        x -= math.max(0, tonumber(e[2]) or 0)
        if x <= 0 then return e[1] end
    end
    return list[#list][1]
end
ItemData.MaterialDefs.SocketBore = { Name = "Bore Bit", Short = "Bore", IconKey = "mat_schematic", Color = Color3.fromRGB(200, 200, 215), Unlock = 8, NoRoll = true,
    Desc = "Rerolls how many sockets a gun has (its rarity and item level set the odds; 6 needs item level 100). From any kill, now and then." }
ItemData.MaterialDefs.SocketSolder = { Name = "Solder", Short = "Solder", IconKey = "mat_infusion", Color = Color3.fromRGB(255, 205, 110), Unlock = 8, NoRoll = true,
    Desc = "Rerolls which of a gun's sockets are linked (only the biggest linked group's shot mods work). From any kill, now and then." }
ItemData.MaterialDefs.SocketTint = { Name = "Tint", Short = "Tint", IconKey = "mat_catalyst", Color = Color3.fromRGB(150, 220, 255), Unlock = 8, NoRoll = true,
    Desc = "Rerolls the colours of a gun's sockets (red / green / blue), leaning to what that gun usually rolls. From any kill, now and then." }
-- colour weights { R, G, B } for an item's sockets: its gun group's (ItemData.SOCKETS.Colors). PHASE 4 HOOK: SOCKET_COLOUR_HOOK
-- (item, w) -> w can lean them on the gun's attribute requirements later.
function ItemData.SocketColourWeights(item: any): { number }
    local S = ItemData.SOCKETS
    local base = item and item.BaseId and ItemData.BaseWeapons[item.BaseId]
    local grp = base and (base.Class == "Heavy" and "LMG" or ItemData.WeaponGroupOf({ BaseId = item.BaseId, Class = base.Class })) or nil
    local w = (S and S.Colors[grp or ""]) or (S and S.Colors.Default) or { 0.34, 0.33, 0.33 }
    if ItemData.SOCKET_COLOUR_HOOK then w = ItemData.SOCKET_COLOUR_HOOK(item, w) or w end
    return w
end
-- socket string <-> list { { c, linked-to-previous } }
function ItemData.ParseSockets(s: string?): { any }
    local out, link = {}, false
    for ch in string.gmatch(type(s) == "string" and s or "", ".") do
        if ch == "R" or ch == "G" or ch == "B" or ch == "W" then table.insert(out, { ch, #out > 0 and link }); link = false
        elseif ch == "-" then link = true elseif ch == " " then link = false end
    end
    return out
end
-- (UPDATE 8: OFFENSE's link gate) cut any linked run longer than ItemData.MaxLinks(item level)
function ItemData.CapLinks(list: { any }, itemLevel: number?)
    local cap, run = ItemData.MaxLinks and ItemData.MaxLinks(itemLevel) or 6, 1
    for i = 2, #list do
        if list[i][2] then run += 1; if run > cap then list[i][2] = false; run = 1 end else run = 1 end
    end
    return list
end
function ItemData.JoinSockets(list: { any }): string
    local t = {}
    for i, s in ipairs(list) do
        if i > 1 then table.insert(t, s[2] and "-" or " ") end
        table.insert(t, s[1])
    end
    return table.concat(t)
end
-- one socket craft on a gun: mode "Sockets" | "Links" | "Colours"; returns the new string (it differs from the old one
-- whenever a different result is possible; up to 24 tries)
function ItemData.RerollSockets(item: any, mode: string): string
    local S = ItemData.SOCKETS
    local r = ItemData.NormRarity(item.Rarity) or "Common"
    local w = ItemData.SocketColourWeights(item)
    local function Col()
        local x = math.random() * (w[1] + w[2] + w[3])
        return (x < w[1] and "R") or (x < w[1] + w[2] and "G") or "B"
    end
    local linkP = S.Link[r] or S.Link.Common
    local old = item.Sockets or ""
    local cur = ItemData.ParseSockets(old)
    local out = old
    for _ = 1, 24 do
        local list = {}
        if mode == "Sockets" then
            local max = ItemData.MaxSockets(item.ItemLevel)
            local n = math.min(max, S.Min[r] or 1)
            while n < max and math.random() < (S.Extra[r] or S.Extra.Common) do n += 1 end
            for i = 1, n do
                local c = cur[i]
                list[i] = c and { c[1], i > 1 and c[2] } or { Col(), i > 1 and math.random() < linkP }
            end
        elseif mode == "Links" then
            for i, c in ipairs(cur) do list[i] = { c[1], i > 1 and math.random() < linkP } end
        else
            for i, c in ipairs(cur) do list[i] = { (c[1] == "W") and "W" or Col(), c[2] } end
        end
        out = ItemData.JoinSockets(ItemData.CapLinks(list, item.ItemLevel))
        if out ~= old then break end
    end
    return out
end
-- (UPDATE 8 LOOT, CRAFTING on GEAR v3) a crafted gear line: a v3 piece (item.Base) takes a side with room (the band's per-side
-- max), never a build line (GearPoolOf leaves them out) and GEAR_V3_LINE_SCALE like a dropped line; an old piece as before.
-- tierTo = force that tier (Redline's bonus line, which may also go past the per-side max: overBand). nil = nothing fits.
function ItemData.CraftGearLine(item: any, ilvl: number, tierTo: number?, overBand: boolean?): any
    local slotType = ItemData.GearType(item.Slot)
    local have, nP, nS = {}, 0, 0
    for _, l in ipairs(item.StatLines or {}) do
        have[l.Stat] = true
        if l.Side == "P" then nP += 1 elseif l.Side == "S" then nS += 1 end
    end
    local v3 = item.Base ~= nil
    local _, _, per = ItemData.LineBand(item.Rarity)
    per = math.max(1, per or 3)
    local byStat, pool = {}, {}
    for _, d in ipairs(ItemData.GearPoolOf(item, slotType)) do
        if not have[d.Stat] and (not v3 or overBand or (d.Side == "P" and nP < per) or (d.Side == "S" and nS < per)) then
            table.insert(pool, d); byStat[d.Stat] = d
        end
    end
    local rolled = RollAffixes(pool, 1, item.Rarity, ilvl)[1]
    if not rolled then return nil end
    local t0, v = rolled.Tier or 1, rolled.Value
    if tierTo then v = v * ItemData.GearTierMult(tierTo) / ItemData.GearTierMult(t0); t0 = tierTo end
    if v3 then v *= ItemData.GEAR_V3_LINE_SCALE end
    local d = byStat[rolled.Stat]
    return { Stat = rolled.Stat, Name = StatDefs[rolled.Stat] and StatDefs[rolled.Stat].Label or rolled.Stat, Value = RoundStat(rolled.Stat, v),
        Tier = t0, Roll = rolled.Roll, Side = v3 and d and d.Side or nil }
end
-- a GEAR v3 build line (fixed value, no tier): Hone never raises it
function ItemData.IsBuildLine(l: any): boolean
    if type(l) ~= "table" or l.Tier ~= nil then return false end
    for _, e in ipairs(ItemData.GEAR_POOL_V3 or {}) do if e.Build and e.Stat == l.Stat then return true end end
    return false
end
-- OVERCHARGE (UPDATE 7 C5, the vault's "corruption" renamed; placeholder): Rift Taint pushes an item past its limit, then
-- locks it (item.Overcharged: no currency, Prism reroll or REROLL GUN touches it again). OVERCHARGE_ODDS = nothing / a bonus
-- line past the rarity's band at the item level's top tier (line.Overcharge) / a full reroll / one good line turns into a penalty.
ItemData.OVERCHARGE_ODDS = { { "Nothing", 0.3 }, { "Bonus", 0.3 }, { "Reroll", 0.25 }, { "Brick", 0.15 } }
ItemData.OVERCHARGE_COLOR = Color3.fromRGB(230, 70, 150)
function ItemData.LinesOf(item: any, isGear: boolean?): { any } -- (a field, not a local: this chunk is near the 200-local limit)
    if isGear then return item.StatLines or {} end
    local all = {}
    for _, a in ipairs(item.Prefixes or {}) do table.insert(all, a) end
    for _, a in ipairs(item.Suffixes or {}) do table.insert(all, a) end
    return all
end
function ItemData.CraftV5Check(action: string, item: any, isGear: boolean?): (boolean, string?)
    if not item then return false, "Pick an item." end
    if item.Twinned then return false, "Twinned items can't be crafted." end -- (CHASE ITEMS: Twin Glass)
    if isGear and item.Exotic then return false, "Relic gear can't be crafted." end
    if item.Exotic then return false, "Relics keep their fixed lines and sockets." end -- (UPDATE 8 LOOT: relic guns too)
    if action == "Sockets" or action == "Links" or action == "Colours" then -- (UPDATE 8 LOOT: socket currencies, guns only)
        if isGear or not item.BaseId then return false, "Guns only: gear has no sockets." end
        local n = #ItemData.ParseSockets(item.Sockets)
        if action == "Sockets" then
            if ItemData.MaxSockets(item.ItemLevel) <= 1 and n == 1 then return false, "Item level " .. (item.ItemLevel or 1) .. " holds one socket (2 from item level 10)." end
            return true
        end
        if n == 0 then return false, "No sockets yet: a Bore Bit adds them." end
        if action == "Links" and n < 2 then return false, "One socket: nothing to link." end
        if action == "Colours" then
            local any = false
            for _, s in ipairs(ItemData.ParseSockets(item.Sockets)) do if s[1] ~= "W" then any = true end end
            if not any then return false, "White sockets take any colour already." end
        end
        return true
    end
    if item.Overcharged then return false, "Redlined items can't be changed." end
    if action == "Ascend" then -- (UPDATE 8 RARITY v4: Ascension Essence)
        if item.Exotic or item.Rarity == "Relic" then return false, "Relics can't ascend." end
        if item.Rarity == "Mythic" then return false, "Already a Mythic." end
        if item.Rarity ~= "Rare" then return false, "Rare items only: a Rare becomes a Mythic." end
        local _, hi = ItemData.LineBand("Mythic")
        if #ItemData.LinesOf(item, isGear) >= hi then return false, "No room for a Mythic line." end
        return true
    end
    if action == "Overcharge" then
        if (ItemData.RarityRank[item.Rarity] or 1) < ItemData.RarityRank.Rare then return false, "Rare and better only." end -- (RARITY v4: was Legendary+)
        if item.Exotic then return false, "Relics can't be redlined." end
        return true
    end
    local lines = ItemData.LinesOf(item, isGear)
    local _, hi = ItemData.LineBand(item.Rarity)
    if action == "Graft" then
        if hi == 0 then return false, "Commons have no lines." end
        if #lines >= hi then return false, "No room: " .. item.Rarity .. " items hold " .. hi .. " lines." end
        return true
    elseif action == "Strip" then
        local free = 0
        for _, a in ipairs(lines) do if not a.Etched then free += 1 end end
        if free == 0 then return false, (#lines == 0) and "No lines to remove." or "Only hallmarks left: they can't be removed." end
        return true
    elseif action == "Temper" then
        local cap = ItemData.AffixTierCap(item.Rarity, item.ItemLevel or 1)
        for _, a in ipairs(lines) do
            if not a.Negative and not a.Exotic and not a.Etched and not ItemData.IsBuildLine(a) and (a.Tier or 1) >= 1 and (a.Tier or 1) < cap then return true end
        end
        return false, "Every line is at the highest tier item level " .. (item.ItemLevel or 1) .. " allows (T" .. cap .. ") or hallmarked."
    elseif action == "Storm" then
        if hi == 0 then return false, "Commons have no lines." end
        return true
    end
    return false, "Unknown craft."
end
function ItemData.CraftV5Apply(action: string, item: any, isGear: boolean?): string
    local ilvl = item.ItemLevel or 1
    if action == "Sockets" or action == "Links" or action == "Colours" then -- (UPDATE 8 LOOT: socket currencies)
        local before = item.Sockets or ""
        item.Sockets = ItemData.RerollSockets(item, action)
        local _, n, big = ItemData.SocketGroups(item.Sockets)
        local word = (action == "Sockets" and "BORED") or (action == "Links" and "SOLDERED") or "TINTED"
        if item.Sockets == before then return word .. ": the same again (" .. n .. " sockets, " .. big .. "-link)" end
        return word .. ": " .. n .. " socket" .. (n == 1 and "" or "s") .. ", " .. big .. "-link  (" .. item.Sockets .. ")"
    end
    if action == "Ascend" then -- (UPDATE 8 RARITY v4: Rare -> Mythic, the numbers moved to Mythic's like a dropped one, + the Mythic line)
        local old = item.Rarity
        item.Rarity = "Mythic"
        item.Ascended = true
        if isGear then
            local k = AffixTier("Mythic") / AffixTier(old)
            for _, l in ipairs(item.StatLines or {}) do
                if not l.Exotic and not l.Negative and type(l.Value) == "number" then l.Value = RoundStat(l.Stat, l.Value * k) end
            end
            ItemData.ScaleGearDefence(item, (RarityDamageMult.Mythic or 1) / (RarityDamageMult[old] or 1)) -- (UPDATE 8 GEAR v3: Armor + base defences)
        else
            if type(item.BaseDamage) == "number" then
                item.BaseDamage = math.round(item.BaseDamage * (RarityDamageMult.Mythic or 1) / (RarityDamageMult[old] or 1) * 100) / 100
            end
            if not item.Proc then item.Proc = RollProc("Mythic") end
        end
        ItemData._GRAFT_NO_NEG = true -- (the Mythic line is never a penalty)
        local ok, added = pcall(ItemData.CraftV5Apply, "Graft", item, isGear)
        ItemData._GRAFT_NO_NEG = nil
        added = ok and tostring(added) or "no line"
        return "ASCENDED to Mythic. Mythic line: " .. (string.gsub(added, "^Riveted: ", ""))
    end
    if action == "Overcharge" then
        local pick = ItemData.PickWeighted(ItemData.OVERCHARGE_ODDS, "Nothing")
        local msg = "The charge fades: nothing changed."
        if pick == "Bonus" then
            local cap = ItemData.AffixTierCap(item.Rarity, ilvl)
            local have = {}
            for _, a in ipairs(ItemData.LinesOf(item, isGear)) do have[a.Stat] = true end
            if isGear then
                local line = ItemData.CraftGearLine(item, ilvl, cap, true) -- (UPDATE 8 LOOT: GEAR v3 sides + line scale)
                if line then
                    line.Overcharge = true
                    table.insert(item.StatLines, line)
                    msg = "REDLINED: a bonus line, " .. ItemData.FormatStat(line.Stat, line.Value) .. " (T" .. cap .. ")"
                end
            else
                local pierces = item.BaseId and ItemData.BaseWeapons[item.BaseId] and ItemData.BaseWeapons[item.BaseId].Pierce ~= nil
                local bag = {}
                for _, d in ipairs(ItemData.WeaponPrefixPool) do if not have[d.Stat] and (not d.Requires or (d.Requires == "Pierce" and pierces)) then table.insert(bag, { d, true }) end end
                for _, d in ipairs(ItemData.WeaponSuffixPool) do if not have[d.Stat] and (not d.Requires or (d.Requires == "Pierce" and pierces)) then table.insert(bag, { d, false }) end end
                if #bag > 0 then
                    local e = bag[math.random(1, #bag)]
                    local new = MakeAffix(e[1], cap)
                    new.Overcharge = true
                    item.Prefixes, item.Suffixes = item.Prefixes or {}, item.Suffixes or {}
                    table.insert(e[2] and item.Prefixes or item.Suffixes, new)
                    msg = "REDLINED: a bonus line, " .. ItemData.FormatStat(new.Stat, new.Value) .. " (T" .. cap .. ")"
                end
            end
        elseif pick == "Reroll" then
            msg = "REDLINED: " .. ItemData.CraftV5Apply("Storm", item, isGear)
        elseif pick == "Brick" then
            local cands = {}
            if isGear then
                for i, l in ipairs(item.StatLines or {}) do if not l.Etched and not l.Exotic and (l.Value or 0) > 0 then table.insert(cands, { item.StatLines, i }) end end
            else
                for i, a in ipairs(item.Prefixes or {}) do if not a.Etched and not a.Negative then table.insert(cands, { item.Prefixes, i }) end end
                for i, a in ipairs(item.Suffixes or {}) do if not a.Etched and not a.Negative then table.insert(cands, { item.Suffixes, i }) end end
            end
            if #cands > 0 then
                local c = cands[math.random(1, #cands)]
                local old = c[1][c[2]]
                if isGear then
                    old.Value = -math.abs(old.Value) * 0.5
                    old.Negative = true
                    msg = "REDLINE BACKFIRED: " .. ItemData.FormatStat(old.Stat, old.Value)
                else
                    local have = {}
                    for _, a in ipairs(ItemData.LinesOf(item, false)) do have[a.Stat] = true end
                    local neg = ItemData.MakeNegativeAffix(have)
                    if neg then
                        c[1][c[2]] = neg
                        msg = "REDLINE BACKFIRED: " .. ItemData.FormatStat(old.Stat, old.Value) .. " became " .. ItemData.FormatStat(neg.Stat, neg.Value)
                    end
                end
            end
        end
        item.Overcharged = true
        if not isGear then RenameWeapon(item) else item.Name = GearName(ItemData.GearType(item.Slot), item.StatLines, item) end
        return msg .. "  (locked: it can't be changed again)"
    end
    if action == "Graft" then
        if isGear then
            local slotType = ItemData.GearType(item.Slot)
            local line = ItemData.CraftGearLine(item, ilvl) -- (UPDATE 8 LOOT: GEAR v3 sides + line scale, no build lines)
            if not line then return "Nothing left to add." end
            item.StatLines = item.StatLines or {}
            table.insert(item.StatLines, line)
            item.Name = GearName(slotType, item.StatLines, item)
            return "Riveted: " .. ItemData.FormatStat(line.Stat, line.Value) .. "  (T" .. line.Tier .. ")"
        end
        local _, _, side = ItemData.LineBand(item.Rarity)
        item.Prefixes, item.Suffixes = item.Prefixes or {}, item.Suffixes or {}
        local have = {}
        for _, a in ipairs(ItemData.LinesOf(item, false)) do if not a.Negative then have[a.Stat] = true end end
        local pierces = item.BaseId and ItemData.BaseWeapons[item.BaseId] and ItemData.BaseWeapons[item.BaseId].Pierce ~= nil
        local function Bag(pool)
            local out = {}
            for _, d in ipairs(pool) do if not have[d.Stat] and (not d.Requires or (d.Requires == "Pierce" and pierces)) then table.insert(out, d) end end
            return out
        end
        local canP = #item.Prefixes < side and #Bag(ItemData.WeaponPrefixPool) > 0
        local canS = #item.Suffixes < side and #Bag(ItemData.WeaponSuffixPool) > 0
        if not canP and not canS then return "Nothing left to add." end
        local prefix = canP and (not canS or math.random() < 0.5)
        local neg = not ItemData._GRAFT_NO_NEG and math.random() < ItemData.NEG_AFFIX_CHANCE and ItemData.MakeNegativeAffix(have) or nil
        local new = neg
        if not new then
            local bag = Bag(prefix and ItemData.WeaponPrefixPool or ItemData.WeaponSuffixPool)
            new = MakeAffix(bag[math.random(1, #bag)], ItemData.RollAffixTier(ilvl, item.Rarity))
        end
        table.insert(prefix and item.Prefixes or item.Suffixes, new)
        RenameWeapon(item)
        return (new.Negative and "Riveted a PENALTY: " or "Riveted: ") .. ItemData.FormatStat(new.Stat, new.Value) .. "  (T" .. tostring(new.Tier) .. ")"
    elseif action == "Strip" then
        -- (UPDATE 7 SET LINES: an etched line is never the one removed)
        if isGear then
            local cands = {}
            for i, l in ipairs(item.StatLines) do if not l.Etched then table.insert(cands, i) end end
            local gone = table.remove(item.StatLines, cands[math.random(1, #cands)])
            item.Name = GearName(ItemData.GearType(item.Slot), item.StatLines, item)
            return "Stripped: " .. ItemData.FormatStat(gone.Stat, gone.Value)
        end
        local cands = {}
        for i, a in ipairs(item.Prefixes or {}) do if not a.Etched then table.insert(cands, { item.Prefixes, i }) end end
        for i, a in ipairs(item.Suffixes or {}) do if not a.Etched then table.insert(cands, { item.Suffixes, i }) end end
        local pick = cands[math.random(1, #cands)]
        local gone = table.remove(pick[1], pick[2])
        RenameWeapon(item)
        return "Stripped: " .. ItemData.FormatStat(gone.Stat, gone.Value)
    elseif action == "Temper" then
        local cap = ItemData.AffixTierCap(item.Rarity, ilvl)
        local cands = {}
        for _, a in ipairs(ItemData.LinesOf(item, isGear)) do
            if not a.Negative and not a.Exotic and not a.Etched and not ItemData.IsBuildLine(a) and (a.Tier or 1) >= 1 and (a.Tier or 1) < cap then table.insert(cands, a) end
        end
        local a = cands[math.random(1, #cands)]
        local t = (a.Tier or 1) + 1
        if isGear then
            a.Value = RoundStat(a.Stat, a.Value * ItemData.GearTierMult(t) / ItemData.GearTierMult(t - 1))
            a.Tier = t
        else
            local def = AffixDefByStat[a.Stat]
            local fresh = MakeAffix(def, t, tonumber(a.Roll) or 0.5)
            for k, v in pairs(fresh :: any) do a[k] = v end
            RenameWeapon(item)
        end
        return "Honed: " .. ItemData.FormatStat(a.Stat, a.Value) .. "  (T" .. t .. ")"
    elseif action == "Storm" then
        -- (UPDATE 7 SET LINES: the etched line stays; everything else rerolls, the count still inside the band)
        if isGear then
            local slotType = ItemData.GearType(item.Slot)
            local keep = {}
            for _, l in ipairs(item.StatLines or {}) do if l.Etched then table.insert(keep, l) end end
            local bc = ItemData.GEAR_BUILD_CHANCE
            ItemData.GEAR_BUILD_CHANCE = 0 -- (UPDATE 8 LOOT: build lines are drop-only, never from crafting)
            local okF, fresh = pcall(RollGearLines, slotType, item.Rarity, ilvl, item)
            ItemData.GEAR_BUILD_CHANCE = bc
            if not okF then error(fresh) end
            local _, _, perSide = ItemData.LineBand(item.Rarity)
            perSide = math.max(1, perSide or 3)
            for _, k in ipairs(keep) do
                for i = #fresh, 1, -1 do if fresh[i].Stat == k.Stat then table.remove(fresh, i) end end
                if item.Base and k.Side then -- (UPDATE 8 LOOT: a v3 piece keeps the per-side cap -- the hallmark takes a slot on its own side)
                    local same = {}
                    for i, l in ipairs(fresh) do if l.Side == k.Side and not l.Etched then table.insert(same, i) end end
                    local onSide = 0
                    for _, l in ipairs(fresh) do if l.Side == k.Side then onSide += 1 end end
                    if onSide + 1 > perSide and #same > 0 then table.remove(fresh, same[math.random(1, #same)]) end
                end
                if #fresh >= 1 and #fresh + 1 > select(2, ItemData.LineBand(item.Rarity)) then table.remove(fresh, math.random(1, #fresh)) end
                table.insert(fresh, 1, k)
            end
            item.StatLines = fresh
            item.Name = GearName(slotType, item.StatLines, item)
            return "Storm rerolled: " .. #item.StatLines .. " lines" .. ((#keep > 0) and " (the hallmark stayed)" or "")
        end
        local keepP, keepS = {}, {}
        for _, a in ipairs(item.Prefixes or {}) do if a.Etched then table.insert(keepP, a) end end
        for _, a in ipairs(item.Suffixes or {}) do if a.Etched then table.insert(keepS, a) end end
        item.Prefixes, item.Suffixes = RollWeaponAffixSet(item.Rarity, ilvl, nil, item.BaseId)
        for _ = 1, (item :: any).TierBumps or 0 do ItemData.BumpAffixTier(item) end
        local _, hi, side = ItemData.LineBand(item.Rarity)
        for _, pair in ipairs({ { keepP, item.Prefixes }, { keepS, item.Suffixes } }) do
            for _, k in ipairs(pair[1]) do
                local list = pair[2]
                for i = #list, 1, -1 do if list[i].Stat == k.Stat then table.remove(list, i) end end
                if #list >= side or #item.Prefixes + #item.Suffixes >= hi then if #list > 0 then table.remove(list, math.random(1, #list)) end end
                table.insert(list, 1, k)
            end
        end
        RenameWeapon(item)
        return "Storm rerolled: " .. (#item.Prefixes + #item.Suffixes) .. " lines" .. ((#keepP + #keepS > 0) and " (the hallmark stayed)" or "")
    end
    return "Nothing happened."
end

-- Prefix Catalyst: a different elemental / special prefix at the rarity's power.
function ItemData.RerollWeaponProc(weapon: WeaponInstance): WeaponInstance
    local order = ItemData.WeaponProcOrder
    local current = weapon.Proc and weapon.Proc.Id
    local pick = current
    for _ = 1, 10 do
        pick = order[math.random(1, #order)]
        if pick ~= current then break end
    end
    weapon.Proc = { Id = pick, Power = math.round(AffixTier(weapon.Rarity) * (0.9 + math.random() * 0.2) * 100) / 100 }
    RenameWeapon(weapon)
    return weapon
end

-- Re-level (Rare+): brings an item to a higher level, keeping upgrades and affixes.
-- Cost per level gained: 1 Prism Shard + 500 gold, x the rarity's upgrade cost multiplier.
function ItemData.RelevelCost(rarity: string, fromLevel: number, toLevel: number): (number, number)
    local gained = math.max(0, math.floor(toLevel) - math.floor(fromLevel))
    local mult = ItemData.UpgradeCostMult[rarity] or 1
    return math.ceil(gained * mult), math.round(500 * gained * mult)
end

-- Dismantling: materials by rarity (+ a chance at a Reforge Token from Epic up).
ItemData.DismantleYield = {
    Common = { Scrap = 2 },
    Uncommon = { Scrap = 4 },
    Rare = { Scrap = 8, Alloy = 3, TokenChance = 0.25 }, -- (RARITY v4: the old Epic's; was Scrap 6, Alloy 1)
    Relic = { Scrap = 15, Alloy = 8, Prism = 10, TokenChance = 0.25, SealChance = 0.15 },
    Epic = { Scrap = 8, Alloy = 3, TokenChance = 0.25 },
    Legendary = { Scrap = 10, Alloy = 5, Prism = 3, TokenChance = 0.25, SealChance = 0.08 },
    Mythic = { Scrap = 15, Alloy = 8, Prism = 10, TokenChance = 0.25, SealChance = 0.15 },
    Celestial = { Scrap = 20, Alloy = 12, Prism = 18, TokenChance = 0.6, SealChance = 0.25 },
    Transcendent = { Scrap = 30, Alloy = 18, Prism = 30, TokenChance = 1, SealChance = 0.35 },
    Astral = { Scrap = 34, Alloy = 21, Prism = 36, TokenChance = 1 }, Empyrean = { Scrap = 38, Alloy = 24, Prism = 42, TokenChance = 1 },
    Primordial = { Scrap = 42, Alloy = 27, Prism = 48, TokenChance = 1 }, Sovereign = { Scrap = 46, Alloy = 30, Prism = 55, TokenChance = 1 },
    Eclipse = { Scrap = 50, Alloy = 33, Prism = 62, TokenChance = 1 }, Genesis = { Scrap = 55, Alloy = 36, Prism = 70, TokenChance = 1 },
    Infinite = { Scrap = 60, Alloy = 40, Prism = 80, TokenChance = 1 },
}
function ItemData.RollDismantle(rarity: string): { [string]: number }
    local y = ItemData.DismantleYield[rarity] or ItemData.DismantleYield.Common
    if ItemData.DISMANTLE_BEFORE and ItemData.DISMANTLE_BEFORE[rarity] and not ItemData.Scarce() then y = ItemData.DISMANTLE_BEFORE[rarity] end -- (LOOT SCARCITY A/B)
    local out = { Scrap = y.Scrap or 0, Alloy = y.Alloy or 0, Prism = y.Prism or 0 }
    -- (0.75 CRAFTING v3: dismantling gives upgrade materials, a small Reforge Token chance and rarely a Schematic -- no
    -- Seals, Infusion Cores or Purge Salts any more; GrantMaterials then applies CRAFT_SOURCE_MULT on top)
    local rk = ItemData.RarityRank[rarity] or 1
    if y.TokenChance and math.random() < math.min(0.25, y.TokenChance * 0.25) then out.ReforgeToken = 1 end
    if rk >= 4 and math.random() < math.min(0.1, 0.02 + 0.01 * (rk - 4)) then out.Schematic = 1 end
    return out
end
-- Short text of what an item dismantles into ("6 Scrap, 1 Alloy").
function ItemData.DismantleText(rarity: string): string
    local y = ItemData.DismantleYield[rarity] or ItemData.DismantleYield.Common
    local parts = {}
    for _, k in ipairs({ "Scrap", "Alloy", "Prism" }) do
        if (y :: any)[k] then table.insert(parts, tostring((y :: any)[k]) .. " " .. ItemData.MaterialDefs[k].Name) end
    end
    -- (0.97: Reforge Tokens are retired -- no token line)
    return table.concat(parts, ", ")
end
-- Old Forge Core value (kept for any older UI that still asks).
function ItemData.GetDismantleCores(rarity: WeaponRarity): number
    local y = ItemData.DismantleYield[rarity] or ItemData.DismantleYield.Common
    return y.Scrap or 1
end

function ItemData.RerollGearStatLines(gear: GearInstance, _luck: number?): GearInstance
    local slotType = ItemData.GearType(gear.Slot)
    gear.Slot = slotType
    local count = math.max(ItemData.LineBand(gear.Rarity), #(gear.StatLines or {})) -- (ITEM SCALING v2: same count, at least the band's min)
    local pool = ItemData.GearPoolOf(gear, slotType)
    local rolled = RollAffixes(pool, count, gear.Rarity, gear.ItemLevel or 1)
    local lines: { GearStatLine } = {}
    for _, a in ipairs(rolled) do
        table.insert(lines, { Stat = a.Stat, Name = StatDefs[a.Stat] and StatDefs[a.Stat].Label or a.Stat, Value = a.Value, Tier = a.Tier, Roll = a.Roll })
    end
    gear.StatLines = lines
    gear.Name = GearName(slotType, lines, gear)
    return gear
end

-- ===== AFFIX SEALS (0.61, owner: "We need new material to lock affixes when rerolling them, the cost would double with
-- each reroll") =====
-- A Reforge may LOCK some of an item's affixes: locked ones stay exactly (stat, tier, value), the rest reroll into stats
-- the item doesn't already carry. Indices count the affixes in tooltip order (weapons: prefixes then suffixes; gear: its
-- stat lines). Never all of them. Seal cost = locked affixes x 2 ^ item.SealRolls (how many LOCKED reforges this item
-- has had; the server bumps it after each one, so 1 lock costs 1, 2, 4, 8 ... and 2 locks 2, 4, 8, 16 ...).
function ItemData.SealCost(item: any, lockedCount: number): number
    local n = math.max(0, math.floor(tonumber(lockedCount) or 0))
    if n == 0 then return 0 end
    return n * 3 ^ math.max(0, math.floor(tonumber(item and item.SealRolls) or 0)) -- (0.75: x3 per sealed reforge, was x2)
end
function ItemData.AffixTotal(item: any, isGear: boolean?): number
    if not item then return 0 end
    if isGear then return #(item.StatLines or {}) end
    return #(item.Prefixes or {}) + #(item.Suffixes or {})
end
-- weapon: Reforge Token reroll keeping the locked affixes (locks = list of indices)
function ItemData.RerollWeaponAffixesLocked(weapon: WeaponInstance, locks: { number }?): WeaponInstance
    if not locks or #locks == 0 then return ItemData.RerollWeaponAffixes(weapon) end
    local lockSet = {}
    for _, i in ipairs(locks) do lockSet[i] = true end
    local pre, suf = weapon.Prefixes or {}, weapon.Suffixes or {}
    weapon.Prefixes, weapon.Suffixes = pre, suf
    local used, slots, total = {}, {}, 0
    for li, list in ipairs({ pre, suf }) do
        for pos, a in ipairs(list) do
            total += 1
            if lockSet[total] then used[a.Stat] = true
            else table.insert(slots, { List = list, Pos = pos, Kind = (li == 1) and "Prefix" or "Suffix", Old = a }) end
        end
    end
    local base = BaseWeapons[weapon.BaseId]
    local pierces = base ~= nil and base.Pierce ~= nil
    local function Bag(pool)
        local out = {}
        for _, d in ipairs(pool) do
            if not used[d.Stat] and (not d.Requires or (d.Requires == "Pierce" and pierces)) then table.insert(out, d) end
        end
        return out
    end
    -- the unlocked stats are free to come back (a reroll may land on the same stat again, like a plain Reforge)
    local fresh = {}
    for _, s in ipairs(slots) do
        local bag = Bag(s.Kind == "Prefix" and WeaponPrefixPool or WeaponSuffixPool)
        if #bag == 0 then bag = Bag(s.Kind == "Prefix" and WeaponSuffixPool or WeaponPrefixPool) end
        if #bag > 0 then
            local def = bag[math.random(1, #bag)]
            used[def.Stat] = true
            local a = MakeAffix(def, RollTier(weapon.ItemLevel or 1, weapon.Rarity))
            s.List[s.Pos] = a
            table.insert(fresh, a)
        else
            used[s.Old.Stat] = true -- (nothing left to roll: it keeps what it had)
        end
    end
    -- (FORCED_T5 is empty since 0.70, so this does nothing now; kept for a rarity that might force tiers again)
    local forced = ItemData.FORCED_T5[weapon.Rarity] or 0
    local have = 0
    for _, list in ipairs({ pre, suf }) do for _, a in ipairs(list) do if (a.Tier or 1) >= 5 then have += 1 end end end
    if have < forced then
        local order = table.clone(fresh)
        table.sort(order, function(x, y) return (x.Tier or 1) > (y.Tier or 1) end)
        for _, a in ipairs(order) do
            if have >= forced then break end
            if (a.Tier or 1) < 5 and AffixDefByStat[a.Stat] then
                local t5 = MakeAffix(AffixDefByStat[a.Stat], 5)
                for k, v in pairs(t5 :: any) do a[k] = v end
                have += 1
            end
        end
    end
    -- upgrade tier bumps: the new affixes get their share (the locked ones keep the bumps they already carry)
    local bumps = math.round(((weapon :: any).TierBumps or 0) * #fresh / math.max(1, total))
    for _ = 1, bumps do
        local lowest: any = nil
        for _, a in ipairs(fresh) do
            if AffixDefByStat[a.Stat] and (a.Tier or 1) < 5 and (not lowest or (a.Tier or 1) < (lowest.Tier or 1)) then lowest = a end
        end
        if not lowest then break end
        local up = MakeAffix(AffixDefByStat[lowest.Stat], (lowest.Tier or 1) + 1, lowest.Roll or 0.5)
        for k, v in pairs(up :: any) do lowest[k] = v end
    end
    RenameWeapon(weapon)
    return weapon
end
-- gear: stat-line reroll keeping the locked lines
function ItemData.RerollGearStatLinesLocked(gear: GearInstance, locks: { number }?): GearInstance
    if not locks or #locks == 0 then return ItemData.RerollGearStatLines(gear) end
    local slotType = ItemData.GearType(gear.Slot)
    gear.Slot = slotType
    local lines = gear.StatLines or {}
    local lockSet, used, open = {}, {}, {}
    for _, i in ipairs(locks) do lockSet[i] = true end
    for i, l in ipairs(lines) do
        if lockSet[i] then used[l.Stat] = true else table.insert(open, i) end
    end
    local pool = {}
    for _, d in ipairs(ItemData.GearPoolOf(gear, slotType)) do
        if not used[d.Stat] then table.insert(pool, d) end
    end
    local rolled = RollAffixes(pool, #open, gear.Rarity, gear.ItemLevel or 1)
    for k, pos in ipairs(open) do
        local a = rolled[k]
        if a then lines[pos] = { Stat = a.Stat, Name = StatDefs[a.Stat] and StatDefs[a.Stat].Label or a.Stat, Value = a.Value, Tier = a.Tier } end
    end
    gear.StatLines = lines
    gear.Name = GearName(slotType, lines, gear)
    return gear
end

-- ===== FORGE CRAFTING (0.61f, owner: "you should be able to reroll all types of gear (not just weapons), add more
-- features to the armory (we are going to add crafting mechanics now)") =====
-- Server-validated in CombatServer "ForgeCraft"; the ForgeMenu CRAFT / BENCH tabs read the same costs from here.
--   TUNE (gear)  Tuning Kit: new values inside each line's range (TuneGearLines; weapons keep TuneWeaponAffixes)
--   AUGMENT      Infusion Core: one new affix into a free slot (fewer affixes than the rarity's count)
--   PURGE        Purge Salt: one affix removed at random (0.75: Seals can't choose it any more)
--   ASCEND       Ascension Essence + Prism: one rarity up (keeps every affix, fills the new slots, re-scales base damage /
--                armour / gear line strength), ONCE per item (item.Ascended), capped at AscendMaxRank = one under
--                ItemData.MaxRarityForLevel (the top your level's difficulty drops stays drop-only)
--   BENCH        Schematics + Alloy + Prism + gold: a chosen gun base / gear slot at a RANDOM rarity (0.75) at your level, up to
--                BENCH_BELOW_TOP steps under that cap (drops stay the way to the top rarities)
-- Exotic gear (fixed lines) can't be crafted; exotic weapons can't ascend.
-- (0.63, owner: "Crafting right now is a bit too easy (using the bench type of crafting)"): 2 -> 3 steps under your
-- level's top rarity, and BenchCost about 2-3x (schematics grow faster than linearly with rarity)
ItemData.BENCH_BELOW_TOP = 3
ItemData.BENCH_SLOTS = { "Helmet", "ChestPiece", "Leggings", "Boots", "Gloves", "Ring", "Necklace" }
function ItemData.AffixCap(item: any, isGear: boolean?): number
    if not item then return 0 end
    if isGear then return GearAffixCount[item.Rarity] or 1 end
    return WeaponAffixCount[item.Rarity] or 0
end
function ItemData.CraftGold(item: any, isGear: boolean?): number
    return math.round((isGear and ItemData.GetGearSellValue(item) or ItemData.GetSellValue(item)) * ItemData.CRAFT_GOLD_MULT)
end
-- cost table { [materialKey] = n, Gold = n } for "Augment" / "Purge" / "Ascend"
function ItemData.CraftCost(action: string, item: any, isGear: boolean?): { [string]: number }
    local gold = ItemData.CraftGold(item, isGear)
    local rank = RarityRank[item and item.Rarity or "Common"] or 1
    if action == "Augment" then return { InfusionCore = 1, Gold = gold } end
    if action == "Purge" then return { PurgeSalt = 1, Gold = gold } end
    if action == "Ascend" then return { AscensionEssence = 1, Prism = 2 * rank, Gold = gold * 2 } end -- (1 Essence: it's Exalted-Orb rare)
    return { Gold = gold }
end
-- (0.75 CRAFTING v3) the bench no longer lets you pick the rarity: it rolls the normal drop window under BenchMaxRank
function ItemData.BenchRollRarity(level: number?): string
    return RollRarity(1, ItemData.BenchMaxRank(level))
end
-- its price: as if building the highest rarity it can roll
function ItemData.BenchRollCost(level: number?): { [string]: number }
    return ItemData.BenchCost(Rarities[ItemData.BenchMaxRank(level)] or "Rare", level)
end
function ItemData.BenchMaxRank(level: number?): number
    return math.max(2, ItemData.MaxRarityForLevel(level) - ItemData.BENCH_BELOW_TOP)
end
-- the highest rarity Ascend can reach: one under your level's top (ASCEND_BELOW_TOP)
ItemData.ASCEND_BELOW_TOP = 1
function ItemData.AscendMaxRank(level: number?): number
    return math.max(2, ItemData.MaxRarityForLevel(level) - ItemData.ASCEND_BELOW_TOP)
end
function ItemData.BenchCost(rarity: string, level: number?): { [string]: number }
    local rank = RarityRank[rarity] or 1
    local lv = math.max(1, math.floor(level or 1))
    return { Schematic = math.ceil(rank ^ 1.6), Alloy = 6 * rank, Prism = math.max(0, rank - 2) * 4, Gold = math.round(375 * rank ^ 1.5 * (1 + (lv - 1) * 0.04)) }
end
-- the guns the bench can build: every lineup gun with a weapon group (no test models, no launchers), group by group
function ItemData.BenchGuns(): { string }
    local out = {}
    for _, grp in ipairs(ItemData.WeaponGroups.Order) do
        for _, id in ipairs(ItemData.Lineup) do
            local b = BaseWeapons[id]
            if b and not b.TestOnly and ItemData.WeaponGroupOf({ BaseId = id, Class = b.Class }) == grp then table.insert(out, id) end
        end
    end
    return out
end
-- can this item take the action at all (before costs)? returns ok, reason
function ItemData.CanCraft(action: string, item: any, isGear: boolean?, playerLevel: number?): (boolean, string?)
    if not item then return false, "Pick an item." end
    if item.Twinned then return false, "Twinned items can't be crafted." end -- (CHASE ITEMS: Twin Glass)
    if isGear and item.Exotic then return false, "Relic gear can't be crafted." end
    local total = ItemData.AffixTotal(item, isGear)
    if action == "Augment" then
        if total >= ItemData.AffixCap(item, isGear) then return false, "No free affix slot (Purge one first, or Ascend it)." end
        return true
    elseif action == "Purge" then
        if total < 1 then return false, "No affixes to purge." end
        return true
    elseif action == "Ascend" then
        if not isGear and item.Exotic then return false, "Relic weapons can't ascend." end
        -- (owner: "WAYYYYY too overpowered ... you can literally just get the highest tier of weapon" -- Bench at top - 2
        -- then Ascend twice): once per item, and never into your level's top rarity (that stays a drop)
        if item.Ascended then return false, "This item has already been ascended." end
        local rank = RarityRank[item.Rarity] or 1
        if rank >= #Rarities then return false, "Already the highest rarity." end
        local cap = ItemData.AscendMaxRank(playerLevel)
        if rank + 1 > cap then return false, "Ascend goes up to " .. Rarities[cap] .. " at your level (the top rarity only drops)." end
        return true
    end
    return false, "Unknown action."
end
-- Tuning Kit on gear: every (non-exotic) line rerolls its value inside its range at the item's rarity / level
-- (UPDATE 7: renamed -- defined after CRAFTING v5's TuneGearLines it REPLACED it, so Prism REROLL VALUES on gear ignored line
-- tiers and the item-level scale. Kept for reference, unused.)
function ItemData.TuneGearLinesLegacy(gear: GearInstance): GearInstance
    local pool = ItemData.GearPoolOf(gear)
    local byStat = {}
    for _, d in ipairs(pool) do byStat[d.Stat] = d end
    for _, l in ipairs(gear.StatLines or {}) do
        local d = byStat[l.Stat]
        if d and not (l :: any).Exotic then
            local v = (d.Min + math.random() * (d.Max - d.Min)) * AffixTier(gear.Rarity)
            local def = StatDefs[d.Stat]
            if def and def.Kind == "flat" then v *= ItemData.LevelCurve(gear.ItemLevel or 1) end
            l.Value = RoundStat(d.Stat, v)
        end
    end
    return gear
end
-- AUGMENT: one new affix (a stat the item doesn't carry). Returns the new affix's label or nil.
function ItemData.AugmentItem(item: any, isGear: boolean?): string?
    if isGear then
        local slotType = ItemData.GearType(item.Slot)
        local used, pool = {}, {}
        for _, l in ipairs(item.StatLines or {}) do used[l.Stat] = true end
        for _, d in ipairs(ItemData.GearPoolOf(item, slotType)) do if not used[d.Stat] then table.insert(pool, d) end end
        local a = RollAffixes(pool, 1, item.Rarity, item.ItemLevel or 1)[1]
        if not a then return nil end
        item.StatLines = item.StatLines or {}
        table.insert(item.StatLines, { Stat = a.Stat, Name = StatDefs[a.Stat] and StatDefs[a.Stat].Label or a.Stat, Value = a.Value, Tier = a.Tier })
        item.Name = GearName(slotType, item.StatLines, item)
        return ItemData.FormatStat(a.Stat, a.Value)
    end
    item.Prefixes, item.Suffixes = item.Prefixes or {}, item.Suffixes or {}
    local used = {}
    for _, list in ipairs({ item.Prefixes, item.Suffixes }) do for _, a in ipairs(list) do used[a.Stat] = true end end
    local base = BaseWeapons[item.BaseId]
    local pierces = base ~= nil and base.Pierce ~= nil
    local function Bag(pool)
        local out = {}
        for _, d in ipairs(pool) do
            if not used[d.Stat] and (not d.Requires or (d.Requires == "Pierce" and pierces)) then table.insert(out, d) end
        end
        return out
    end
    local half = math.max(2, math.ceil(ItemData.AffixCap(item, false) / 2))
    local pBag, sBag = Bag(WeaponPrefixPool), Bag(WeaponSuffixPool)
    local canP, canS = #item.Prefixes < half and #pBag > 0, #item.Suffixes < half and #sBag > 0
    if not canP and not canS then canP, canS = #pBag > 0, #sBag > 0 end -- (room is checked by the caller: any kind will do)
    local takeP = canP and (not canS or math.random() < 0.5)
    local bag = takeP and pBag or sBag
    if #bag == 0 then return nil end
    local a = MakeAffix(bag[math.random(1, #bag)], RollTier(item.ItemLevel or 1, item.Rarity))
    table.insert(takeP and item.Prefixes or item.Suffixes, a)
    RenameWeapon(item)
    return ItemData.FormatStat(a.Stat, a.Value)
end
-- PURGE: one affix removed at random from the unlocked ones (locks = indices in tooltip order). Returns its label or nil.
function ItemData.PurgeItem(item: any, isGear: boolean?, locks: { number }?): string?
    local lockSet = {}
    for _, i in ipairs(locks or {}) do lockSet[i] = true end
    local slots = {}
    if isGear then
        for i, l in ipairs(item.StatLines or {}) do if not lockSet[i] then table.insert(slots, { List = item.StatLines, Pos = i }) end end
    else
        local n = 0
        for _, list in ipairs({ item.Prefixes or {}, item.Suffixes or {} }) do
            for pos in ipairs(list) do
                n += 1
                if not lockSet[n] then table.insert(slots, { List = list, Pos = pos }) end
            end
        end
    end
    if #slots == 0 then return nil end
    local pick = slots[math.random(1, #slots)]
    local gone = table.remove(pick.List, pick.Pos)
    if isGear then item.Name = GearName(ItemData.GearType(item.Slot), item.StatLines or {}, item) else RenameWeapon(item) end
    return gone and ItemData.FormatStat(gone.Stat, gone.Value) or "an affix"
end
-- ASCEND: one rarity up. Weapons: base damage x the rarity damage step, free slots filled, a proc
-- may roll if it had none. Gear: line strength x the affix-tier step, armour x the damage step, free slots filled.
function ItemData.AscendItem(item: any, isGear: boolean?): string?
    local old = item.Rarity
    local rank = RarityRank[old] or 1
    local new = Rarities[rank + 1]
    if not new then return nil end
    item.Rarity = new
    item.Ascended = true -- (one ascend per item, CanCraft)
    if isGear then
        local k = AffixTier(new) / AffixTier(old)
        for _, l in ipairs(item.StatLines or {}) do
            if not l.Exotic and type(l.Value) == "number" then l.Value = RoundStat(l.Stat, l.Value * k) end
        end
        ItemData.ScaleGearDefence(item, (RarityDamageMult[new] or 1) / (RarityDamageMult[old] or 1)) -- (UPDATE 8 GEAR v3: Armor + base defences)
    else
        if type(item.BaseDamage) == "number" then
            item.BaseDamage = math.round(item.BaseDamage * (RarityDamageMult[new] or 1) / (RarityDamageMult[old] or 1) * 100) / 100
        end
        if not item.Proc then item.Proc = RollProc(new) end
    end
    for _ = 1, 8 do
        if ItemData.AffixTotal(item, isGear) >= ItemData.AffixCap(item, isGear) then break end
        if not ItemData.AugmentItem(item, isGear) then break end
    end
    if not isGear then
        local forced = ItemData.FORCED_T5[new] or 0
        local all, have = {}, 0
        for _, list in ipairs({ item.Prefixes or {}, item.Suffixes or {} }) do
            for _, a in ipairs(list) do
                table.insert(all, a)
                if (a.Tier or 1) >= 5 then have += 1 end
            end
        end
        table.sort(all, function(x, y) return (x.Tier or 1) > (y.Tier or 1) end)
        for _, a in ipairs(all) do
            if have >= forced then break end
            if (a.Tier or 1) < 5 and AffixDefByStat[a.Stat] then
                local t5 = MakeAffix(AffixDefByStat[a.Stat], 5, a.Roll)
                for kk, v in pairs(t5 :: any) do a[kk] = v end
                have += 1
            end
        end
        RenameWeapon(item)
    else
        item.Name = GearName(ItemData.GearType(item.Slot), item.StatLines or {}, item)
    end
    return new
end
-- BENCH: a new item ("Gun" + base id, or "Gear" + slot) at a rarity, at the given level
function ItemData.BenchCraft(kind: string, base: string, rarity: string, level: number): any?
    local lvl = math.max(1, math.floor(level or 1))
    if kind == "Gun" then
        local b = BaseWeapons[base]
        if not b or not table.find(ItemData.BenchGuns(), base) then return nil end
        return ItemData.GenerateWeaponOfBase(base, rarity, lvl)
    elseif kind == "Gear" then
        if not table.find(ItemData.BENCH_SLOTS, base) then return nil end
        return ItemData.GenerateRandomGear(base, rarity :: any, 1, lvl, true)
    end
    return nil
end

-- Raises an item's level (never lowers it). Damage/armor/flat stats are recomputed for the new level;
-- percentage affixes stay as rolled.
function ItemData.RescaleWeaponToItemLevel(weapon: WeaponInstance, newItemLevel: number): WeaponInstance
    local oldLvl = math.max(1, math.floor(weapon.ItemLevel or 1))
    local newLvl = math.max(oldLvl, math.floor(newItemLevel))
    if newLvl <= oldLvl then return weapon end
    weapon.ItemLevel = newLvl
    weapon.BaseDamage = ItemData.WeaponDamageAt(weapon.BaseId, weapon.Rarity, newLvl)
    return weapon
end

function ItemData.RescaleGearToItemLevel(gear: GearInstance, newItemLevel: number): GearInstance
    local oldLvl = math.max(1, math.floor(gear.ItemLevel or 1))
    local newLvl = math.max(oldLvl, math.floor(newItemLevel))
    if newLvl <= oldLvl then return gear end
    local ratio = ItemData.LevelCurve(newLvl) / ItemData.LevelCurve(oldLvl)
    for _, line in ipairs(gear.StatLines or {}) do
        local def = StatDefs[line.Stat]
        if def and def.Kind == "flat" then line.Value = math.max(1, math.round(line.Value * ratio)) end
    end
    ItemData.ScaleGearDefence(gear, ratio, true) -- (UPDATE 8 GEAR v3: Armor + base defences + a flat implicit)
    gear.ItemLevel = newLvl
    return gear
end

-- Sell values: by rarity, with a gentle bump for item level (gold rewards grow gently, not exponentially).
function ItemData.GetSellValue(item: WeaponInstance): number
    local base = BaseSellPrices[item.Rarity] or 15
    local affixes = #(item.Prefixes or {}) + #(item.Suffixes or {})
    local lvlMult = 1 + (math.max(1, item.ItemLevel or 1) - 1) * 0.03
    return math.round((base + affixes * 10 + (item.Proc and 30 or 0) + (item.UpgradeLevel or 0) * 25 + (item.UniqueTrait and 250 or 0)) * lvlMult)
end

function ItemData.GetGearSellValue(gear: GearInstance): number
    local base = BaseSellPrices[gear.Rarity] or 15
    local lvlMult = 1 + (math.max(1, gear.ItemLevel or 1) - 1) * 0.03
    return math.round((base * 0.8 + #(gear.StatLines or {}) * 8) * lvlMult)
end

-- ==================== [ITEM DESCRIPTIONS (tooltips, loot cards, shop)] ====================
-- Returns { Title, Subtitle, Lines = { {Text, Kind} } } where Kind is "stat" | "affix" | "trait" | "note".
function ItemData.DescribeWeapon(w: WeaponInstance, stats: any?): any
    local lines = {}
    local upg = w.UpgradeLevel or 0
    local dmg = (w.BaseDamage or 0) * ItemData.GunTune(w) * (1 + ItemData.UPGRADE_DAMAGE_PER_LEVEL * upg)
    local pellets = w.PelletCount and w.PelletCount > 1 and (" x" .. w.PelletCount .. " pellets") or ""
    local burst = w.BurstCount and w.BurstCount > 1 and (" (" .. w.BurstCount .. "-round burst)") or ""
    table.insert(lines, { Text = "Damage: " .. FormatNumber(dmg) .. pellets, Kind = "stat" })
    table.insert(lines, { Text = "Fire Rate: " .. FormatNumber(w.BaseFireRate or 1) .. "/s" .. burst, Kind = "stat" })
    table.insert(lines, { Text = "Weak-Spot Damage: " .. FormatNumber((w.BaseWeakSpotMultiplier or 2) * 100) .. "%", Kind = "stat" })
    table.insert(lines, { Text = "Magazine: " .. tostring(w.MagazineSize or 0) .. "   Reload: " .. FormatNumber(w.ReloadTime or 2) .. "s", Kind = "stat" })
    table.insert(lines, { Text = "Weapon DPS: " .. FormatNumber(ItemData.CalculateTrueDPS(w)), Kind = "stat" })
    do -- (UPDATE 8 OFFENSE: the gun base's damage types + its sockets / links)
        local tl = ItemData.GunTypeLine and ItemData.GunTypeLine(w)
        if tl then table.insert(lines, { Text = tl, Kind = "stat" }) end
        local sl, rich = nil, nil
        if ItemData.SocketLine then sl, rich = ItemData.SocketLine(w.Sockets) end
        if sl then table.insert(lines, { Text = sl, RichText = rich, Kind = "stat" }) end
        if sl then -- (phase 4: the item-level link gate, when it cuts this gun's biggest group short)
            local SMg = require(script.Parent:WaitForChild("ShotMods"))
            local best = 0
            for _, grp in ipairs(SMg.Groups(w.Sockets)) do best = math.max(best, #grp) end
            local capL = SMg.MaxLinks(w.ItemLevel or 1)
            if best > capL then
                table.insert(lines, { Text = "  Item level " .. tostring(w.ItemLevel or 1) .. ": only a " .. capL .. "-link works", Kind = "stat",
                    Color = Color3.fromRGB(240, 170, 90) })
            end
        end
        if type(w.SocketMods) == "table" then -- (phase 3: the shot mods in its sockets; idle ones = not in the biggest linked group)
            local SMod = require(script.Parent:WaitForChild("ShotMods"))
            local act = SMod.ActiveSet(w)
            local keys = {}
            for k in pairs(w.SocketMods) do if tonumber(k) then table.insert(keys, tonumber(k)) end end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local it = w.SocketMods[tostring(k)]
                local d = SMod.Def(it)
                if d then
                    local tag = act[k] and "" or "  (idle)"
                    table.insert(lines, { Text = "  Mod: " .. SMod.Name(it) .. tag, Kind = "stat",
                        RichText = string.format('  <font color="%s">\●</font> Mod: %s%s', SMod.HEX[d.Color], SMod.Name(it), act[k] and "" or '<font transparency="0.4">  (idle)</font>') })
                end
            end
        end
    end
    do -- (CLASS BUILDS) FAMILY: the gun family's built-in line (can't be crafted away)
        local fl = ItemData.FamilyLine(w)
        if fl then table.insert(lines, { Text = fl, Kind = "family", Color = ItemData.GUN_FAMILY_COLOR }) end
    end
    local pr = ItemData.PierceOf(w)
    if pr then
        table.insert(lines, { Text = string.format("Pierces %d enem%s (%d%% damage kept per enemy)", pr.Targets, pr.Targets == 1 and "y" or "ies", math.round(pr.Falloff * 100)), Kind = "stat" })
    end
    local hops = ItemData.HeavyHops(w)
    if hops > 0 then -- (HEAVY ROUNDS)
        table.insert(lines, { Text = string.format("Heavy rounds: a kill carries its leftover damage to %d more enem%s nearby", hops, hops == 1 and "y" or "ies"), Kind = "stat" })
    end
    local procLine = ItemData.DescribeProc(w, stats)
    if procLine then
        table.insert(lines, { Text = procLine, Kind = "proc", Color = WeaponProcs[w.Proc.Id].Color })
    end
    local elLine = ItemData.DescribeElement(w)
    if elLine then table.insert(lines, { Text = elLine, Kind = "proc", Color = WeaponProcs[w.Proc.Id].Color }) end
    for _, list in ipairs({ w.Prefixes or {}, w.Suffixes or {} }) do
        for _, a in ipairs(list) do
            local tier = (a.Tier and ("  (T" .. a.Tier .. ")" .. ItemData.PerfectMark(a)) or "") .. ItemData.RangeSuffix(w, a, false) -- (QOL F3: ALT = ranges)
            if a.Negative then -- (0.97 NEGATIVE AFFIXES: red, "T-3")
                table.insert(lines, { Text = ItemData.FormatStat(a.Stat, a.Value) .. tier, Kind = "affix", Color = ItemData.NEG_AFFIX_COLOR, Negative = true })
            elseif a.Etched then -- (UPDATE 7 SET LINES)
                table.insert(lines, { Text = "◈ " .. ItemData.FormatStat(a.Stat, a.Value) .. tier .. "  HALLMARK", Kind = "affix", Color = ItemData.ETCH_COLOR })
            elseif a.Overcharge then -- (UPDATE 7 OVERCHARGE: the bonus line)
                table.insert(lines, { Text = "✚ " .. ItemData.FormatStat(a.Stat, a.Value) .. tier .. "  REDLINED", Kind = "affix", Color = ItemData.OVERCHARGE_COLOR })
            else
                table.insert(lines, { Text = ItemData.FormatStat(a.Stat, a.Value) .. tier, Kind = "affix" })
            end
        end
    end
    if type(w.Riftmod) == "table" then -- (UPDATE 7 RIFTMODS: the fitted mod's lines, in its colour)
        for _, a in ipairs(w.Riftmod.Lines or {}) do
            table.insert(lines, { Text = "◇ " .. ItemData.FormatStat(a.Stat, a.Value) .. "  (Gunwright)", Kind = "affix",
                Color = a.Negative and ItemData.NEG_AFFIX_COLOR or Color3.fromRGB(120, 200, 255), Negative = a.Negative })
        end
    end
    if w.Exotic and ItemData.Exotics[w.Exotic] then
        local zd = ItemData.ZenithOf(w) -- (CHASE ITEMS 2026-11-06: a Zenith's mechanic + its catch)
        if zd then
            table.insert(lines, 1, { Text = "CATCH  " .. zd.Catch, Kind = "trait", Color = ItemData.NEG_AFFIX_COLOR })
            local more = ItemData.ZenithMoreText(w.Exotic)
            if more then table.insert(lines, 1, { Text = more, Kind = "trait", Color = ItemData.ZENITH_COLOR }) end
            table.insert(lines, 1, { Text = "❖ ZENITH  " .. zd.Desc, Kind = "trait", Color = ItemData.ZENITH_COLOR })
        else
            table.insert(lines, 1, { Text = "◆ RELIC  " .. ItemData.Exotics[w.Exotic].Desc, Kind = "trait", Color = ItemData.EXOTIC_COLOR })
        end
    end
    if w.Twinned then table.insert(lines, { Text = "⧉ TWINNED: can't be crafted or twinned again", Kind = "trait", Color = ItemData.ZENITH_COLOR }) end
    if w.Overcharged then table.insert(lines, { Text = "✚ REDLINED: can't be changed again", Kind = "trait", Color = ItemData.OVERCHARGE_COLOR }) end
    if w.UniqueTrait then
        table.insert(lines, { Text = "★ " .. (w.UniqueTrait.Tier and (string.upper(w.UniqueTrait.Tier) .. " TRAIT  ") or "") .. w.UniqueTrait.Name .. ": " .. w.UniqueTrait.Description, Kind = "trait" })
    end
    local cap = ItemData.UpgradeCapFor(w) -- (LOOT SCARCITY: the item-level gate)
    local model = (w.MythicName and BaseWeapons[w.BaseId]) and (BaseWeapons[w.BaseId].ShortName .. "  •  ") or ""
    local sub = model .. ItemData.RarityLabel(w) .. " " .. ItemData.WeaponTypeLine(w) .. "  •  Item Level " .. tostring(w.ItemLevel or 1) .. "  •  +" .. upg .. "/" .. cap
    local req = ItemData.RequiredLevel(w)
    if req > 1 then table.insert(lines, 1, { Text = "Requires level " .. req .. " to equip", Kind = "note" }) end
    return { Title = ItemData.DisplayName(w), Subtitle = sub, Lines = lines }
end

-- ITEM LEVEL REQUIREMENT (owner 2026-10-05: "make gear have an ilvl range requirement (within 5-10 levels of your level)
-- so trading isn't abused"): you can equip guns and gear up to IlvlAllowance(level) item levels above you -- 5 at level
-- 1, one more every 40 levels, 10 from level 200. RequiredLevel = the lowest level that can equip the item.
function ItemData.IlvlAllowance(level: number?): number
    return math.clamp(5 + math.floor((level or 1) / 40), 5, 10)
end
function ItemData.CanEquipLevel(item: any, level: number?): boolean
    local lv = math.max(1, math.floor(level or 1))
    return math.floor(item and item.ItemLevel or 1) <= lv + ItemData.IlvlAllowance(lv)
end
function ItemData.RequiredLevel(item: any): number
    local il = math.max(1, math.floor(item and item.ItemLevel or 1))
    for lv = math.max(1, il - 10), il do
        if lv + ItemData.IlvlAllowance(lv) >= il then return lv end
    end
    return il
end
local function ReqText(item: any): string
    local r = ItemData.RequiredLevel(item)
    return (r > 1) and ("  •  Requires Lv " .. r) or ""
end

function ItemData.DescribeGear(g: GearInstance): any
    local lines = {}
    local slotType = ItemData.GearType(g.Slot)
    -- (UPDATE 8 GEAR v3) the piece's own defence (its LocalDefence lines applied) + its IMPLICIT, above the affix lines
    do
        local d = ItemData.GearDefOf(g)
        local parts = {}
        for _, k in ipairs({ "Plating", "Agility", "Ward" }) do if (d[k] or 0) > 0 then table.insert(parts, k .. " " .. FormatNumber(d[k])) end end
        if #parts > 0 then table.insert(lines, { Text = table.concat(parts, "   "), Kind = "stat" }) end
        if type(g.Implicit) == "table" and g.Implicit.Stat then
            table.insert(lines, { Text = ItemData.FormatStat(g.Implicit.Stat, g.Implicit.Value or 0) .. "  (implicit)", Kind = "stat", Color = Color3.fromRGB(150, 205, 255) })
        end
    end
    local zdG = ItemData.ZenithOf(g) -- (CHASE ITEMS: a Zenith's mechanic + its catch)
    if zdG then
        table.insert(lines, { Text = "❖ ZENITH  " .. zdG.Desc, Kind = "trait", Color = ItemData.ZENITH_COLOR })
        local moreG = ItemData.ZenithMoreText(g.Exotic)
        if moreG then table.insert(lines, { Text = moreG, Kind = "trait", Color = ItemData.ZENITH_COLOR }) end
        table.insert(lines, { Text = "CATCH  " .. zdG.Catch, Kind = "trait", Color = ItemData.NEG_AFFIX_COLOR })
    elseif g.Exotic and ItemData.Exotics[g.Exotic] then
        table.insert(lines, { Text = "◆ RELIC  " .. ItemData.Exotics[g.Exotic].Desc, Kind = "trait", Color = ItemData.EXOTIC_COLOR })
    end
    if g.Twinned then table.insert(lines, { Text = "⧉ TWINNED: can't be crafted or twinned again", Kind = "trait", Color = ItemData.ZENITH_COLOR }) end
    for _, s in ipairs(g.StatLines or {}) do
        table.insert(lines, { Text = (s.Etched and "◈ " or (s.Overcharge and "✚ " or "")) .. ItemData.FormatStat(s.Stat, s.Value) .. ((s.Tier and not s.Exotic) and ("  (T" .. s.Tier .. ")" .. ItemData.PerfectMark(s)) or "") .. ItemData.RangeSuffix(g, s, true) --[[QOL F3: ALT = ranges]] .. (s.Etched and "  HALLMARK" or (s.Overcharge and "  REDLINED" or "")),
            Kind = "affix", Color = (s.Exotic and (zdG and ItemData.ZENITH_COLOR or ItemData.EXOTIC_COLOR)) or (s.Etched and ItemData.ETCH_COLOR) or (s.Overcharge and ItemData.OVERCHARGE_COLOR) or (s.Negative and ItemData.NEG_AFFIX_COLOR) or nil })
    end
    if g.Overcharged then
        table.insert(lines, { Text = "✚ REDLINED: can't be changed again", Kind = "trait", Color = ItemData.OVERCHARGE_COLOR })
    end
    if slotType == "Ring" then
        table.insert(lines, { Text = "Fits either ring slot.", Kind = "note" })
    end
    local gb = ItemData.GearBaseOf(g) -- (UPDATE 8 GEAR v3: "Rare Steel Visor (Plating)")
    local sub = ItemData.RarityLabel(g) .. " " .. (gb and (gb.Name .. (gb.Def and (" (" .. ItemData.GEAR_DEF_WORD[gb.Def] .. ")") or "")) or (GearBaseNames[slotType] or slotType)) .. "  •  Item Level " .. tostring(g.ItemLevel or 1) .. ReqText(g)
    return { Title = ItemData.DisplayName(g), Subtitle = sub, Lines = lines }
end

-- ===== LIVES (CombatServer "LIVES" block) =====
-- Every dungeon run gives PerRun lives. Out of lives you have DownedSeconds to revive with Robux (price climbs
-- with each revive bought this run: Prices[1], [2], ... the last price repeats) or give up (solo: back to the
-- hub; party: spectate the others -- the run ends when nobody is left standing).
-- ProductIds: the Developer Product for each price step (Creator Hub > Monetization > Developer Products).
-- 0 = not set up yet: the revive button then only works in Studio (free, for testing).
ItemData.Lives = {
    PerRun = 3,
    DownedSeconds = 15,
    Prices = { 25, 50, 100, 200 },
    ProductIds = { 3716100073, 3716100084, 3716100096, 3716100106 },
}
-- RUN LOOT (roguelite): items found in a run are "at risk" (item.RunLoot = true) until you finish the run or
-- extract; lose all your lives, leave early or disconnect and they're lost. Lost items can be bought back
-- (one at a time, priced by rarity) until your next run starts. RecoverProductIds: one Developer Product per
-- rarity (0 = not set up yet -> free while play-testing).
ItemData.RunLoot = {
    -- (UPDATE 8 RARITY v4: only Mythics + Relics are kept as lost loot -- Mythic 100 (the old Legendary price + product), Relic 250)
    RecoverPrices = { Relic = 250, Common = 10, Uncommon = 15, Rare = 25, Epic = 50, Legendary = 100, Mythic = 100, Celestial = 250, Transcendent = 250,
        Astral = 250, Empyrean = 250, Primordial = 250, Sovereign = 250, Eclipse = 250, Genesis = 250, Infinite = 250 },
    RecoverProductIds = { Relic = 3716100160, Common = 3716100114, Uncommon = 3716100124, Rare = 3716100135, Epic = 3716100147, Legendary = 3716100156, Mythic = 3716100156,
        Celestial = 3716100160, Transcendent = 3716100160, Astral = 3716100160, Empyrean = 3716100160, Primordial = 3716100160,
        Sovereign = 3716100160, Eclipse = 3716100160, Genesis = 3716100160, Infinite = 3716100160 }, -- (the top two reuse the Mythic product until they get their own)
}
-- EXTRACTION: on long runs, every ExtractEvery floors (a boss floor) an extraction portal opens beside the
-- next-floor portal once the boss is beaten -- leave there and you keep your run loot.
ItemData.RunLoot.ExtractEvery = 5 -- (owner 2026-10-02: every 5 floors on every difficulty; runs are 5-10 floors)
ItemData.RunLoot.ExtractionOn = false -- (owner 2026-10-04: no extraction / run bag / buy-back; loot is never at risk)
function ItemData.IsExtractFloor(difficulty: string, floor: number): boolean
    if not ItemData.RunLoot.ExtractionOn then return false end -- (owner 2026-10-04: extraction removed)
    local mode = ItemData.DifficultyModes[difficulty]
    local maxW = mode and mode.MaxWaves or 10
    local final = floor >= maxW and difficulty ~= "Endless"
    return floor % ItemData.RunLoot.ExtractEvery == 0 and not final
end
function ItemData.RevivePriceStep(revivesBought: number): number
    return math.clamp((revivesBought or 0) + 1, 1, #ItemData.Lives.Prices)
end

-- ==================== TARGET LOOT (pity, 0.50) ====================
-- Owner: "when you pick a class, you dont really want to get other weapons ... beam, where we currently have one weapon".
-- You pick ONE weapon and ONE gear type (Dungeons window, before a run; locked during it). Every chest you open fills a
-- meter for each pick; on every chest the meter's value is the chance of a bonus drop of that pick (a soft pity), and a
-- full meter is a sure drop. Two systems that never feed each other at once:
--   DAILY RARE   1 weapon + 1 gear a day (Pity.DAILY_RATE per chest, ~2.5x the infinite rate); its rarity comes from the
--                UPPER HALF of the difficulty's rarities (never its common end; the top tier is still only a chance).
--                Chests feed it first; once today's is claimed they feed the infinite meter.
--   INFINITE     unlimited, slower (Pity.INF_RATE); the difficulty's normal rarity odds, no extra luck.
-- Drops are at your level. A chest's gain shrinks once you out-level the difficulty's monster levels (Pity.Gain): full
-- up to Pity.OVER_FULL levels above the tier's top level, nothing from Pity.OVER_ZERO -- farming an easy tier does nothing.
-- Changing a pick resets that pick's infinite meter (the daily one stays). state.Pity (saved).
ItemData.Pity = {
    DAILY_RATE = 0.005, -- meter per chest unit (soft pity: usually ~18 units, sure at 200)
    INF_RATE = 0.002,   -- (usually ~28 units, sure at 500)
    CHEST_UNITS = { Supply = 1, Vault = 2, BossVault = 4 },
    OVER_FULL = 5, OVER_ZERO = 15,
    GEAR = { "Helmet", "ChestPiece", "Leggings", "Boots", "Gloves", "Ring", "Necklace" },
}
function ItemData.PityDay(): number
    return os.time() // 86400
end
-- the multiplier on a chest's gain for this player on this difficulty (run key or plain tier)
function ItemData.PityGain(level: number?, runKey: string?): number
    local tier = ItemData.ParseRunKey(runKey)
    local band = tier and ItemData.MONSTER_LEVEL[tier]
    if not band then return 0 end
    local over = (level or 1) - band[2]
    local P = ItemData.Pity
    if over <= P.OVER_FULL then return 1 end
    return math.clamp(1 - (over - P.OVER_FULL) / (P.OVER_ZERO - P.OVER_FULL), 0, 1)
end
-- a normalised copy of state.Pity (fresh day -> today's daily drops are open again)
function ItemData.PityState(state: any): any
    local p = type(state) == "table" and type(state.Pity) == "table" and state.Pity or {}
    local out = {
        W = (type(p.W) == "string" and BaseWeapons[p.W]) and p.W or nil,
        G = (type(p.G) == "string" and table.find(ItemData.Pity.GEAR, p.G)) and p.G or nil,
        Day = tonumber(p.Day) or 0, DW = tonumber(p.DW) or 0, DG = tonumber(p.DG) or 0,
        IW = tonumber(p.IW) or 0, IG = tonumber(p.IG) or 0, CW = p.CW == true, CG = p.CG == true,
    }
    if out.Day ~= ItemData.PityDay() then
        out.Day, out.CW, out.CG = ItemData.PityDay(), false, false
    end
    return out
end
-- DAILY RARE rarity: the difficulty's normal odds, kept to the top three steps of its window
-- (0.99n RARITY LADDER v3: the old "top three steps of the window" would hand out the tier's near-impossible top rarities
-- every day -- the daily target loot is now RARE OR BETTER on the same fixed ladder, with x3 luck)
function ItemData.RollUpperHalfRarity(luck: number, maxRank: any, areaKey: string?): string
    local cap, area = ItemData.RollCap(maxRank, areaKey) -- (RARITY v4: maxRank may be the difficulty key -- its cap + area)
    local minRank = math.min(3, cap)
    maxRank = cap
    local w = ItemData.RarityWindow((luck or 1) * 3, cap, area)
    local total = 0
    for r = minRank, maxRank do total += w[r] or 0 end
    local roll, acc = math.random() * total, 0
    for r = minRank, maxRank do
        acc += w[r] or 0
        if roll <= acc then return Rarities[r] end
    end
    return Rarities[minRank]
end


-- ===== EXOTICS (0.53, owner: "move onto exotics, make whatever non AOE ideas that you think are balanced and best fit the
-- game") =====
-- One named item with one signature effect, class-themed, dropped ONLY by the major bosses (BossTrials Major = true,
-- each boss its own pool -- BossTrials.EXOTIC_POOL). Its stats roll like any drop at the trial's rarity window, so an
-- exotic farmed on a higher tier is stronger. Rules: one exotic GEAR piece worn at a time (CombatServer EquipGear);
-- a gun is one at a time anyway. No AOE, each effect ~+10-30% of a class build's damage at its best.
-- Weapon effects live in CombatServer (ExoticPreHit / the kill block), gear effects are fixed stat lines (Lines) or a
-- DamagePlayer hook (BastionShell). item.Exotic = the id; the name, colour and lines below are shown everywhere.
ItemData.EXOTIC_COLOR = Color3.fromRGB(255, 150, 40)
ItemData.Exotics = {
    -- VANGUARD
    IronChoir = { Name = "Iron Choir", Kind = "Weapon", Base = "M249", Class = "Vanguard",
        Desc = "Hold the trigger: damage climbs to +30% over 3 seconds of sustained fire, and resets the moment you stop." },
    Bandolier = { Name = "Quartermaster's Bandolier", Kind = "Gear", Slot = "Necklace", Class = "Vanguard",
        Desc = "Belts of spare rounds: +50% magazine size.", Lines = { { Stat = "MagSizeBonus", Value = 0.5 } } },
    -- GUNSLINGER
    TwinFang = { Name = "Twin Fang", Kind = "Weapon", Base = "USP", Class = "Gunslinger",
        Desc = "A kill loads a fang: your next shot within 2 seconds deals triple damage." },
    DrifterBoots = { Name = "Drifter's Boots", Kind = "Gear", Slot = "Boots", Class = "Gunslinger",
        Desc = "Never stop moving: +20% damage while moving, +10% movement speed.",
        Lines = { { Stat = "MovingDamage", Value = 0.2 }, { Stat = "MovementSpeed", Value = 0.1 } } },
    -- MARKSMAN
    LastWord = { Name = "Last Word", Kind = "Weapon", Base = "AWP", Class = "Marksman",
        Desc = "Weak-spot kills grant +25% damage for 6 seconds, stacking up to 3 times." },
    HawkeyeVisor = { Name = "Hawkeye Visor", Kind = "Gear", Slot = "Helmet", Class = "Marksman",
        Desc = "Finds the seam in any armour: +25% weak-spot damage.", Lines = { { Stat = "WeakSpotMultiplier", Value = 0.25 } } },
    -- BREACHER
    DragonsMaw = { Name = "Dragon's Maw", Kind = "Weapon", Base = "R870", Class = "Breacher",
        Desc = "Point blank: pellets that hit within 10 studs deal +50% damage and set the target burning." },
    BastionShell = { Name = "Bastion Shell", Kind = "Gear", Slot = "ChestPiece", Class = "Breacher",
        Desc = "Every hit you take hardens it: -10% damage taken per stack, up to 3 stacks, for 4 seconds." },
    -- ARCWRIGHT
    ArcLance = { Name = "Arc Lance", Kind = "Weapon", Base = "BEAM", Class = "Arcwright",
        Desc = "Locks on: damage ramps +10% per second on the same target, up to +80%. Switching targets resets it." },
    PrismCore = { Name = "Prism Core", Kind = "Gear", Slot = "Necklace", Class = "Arcwright",
        Desc = "A lens for every element: ailments you inflict last 50% longer.", Lines = { { Stat = "AilmentDuration", Value = 0.5 } } },
    -- MAP-ONLY (0.66, NEXT_LIST C8): only map guardians drop these (Rifts.EXOTICS / Rifts.ExoticChance), any class
    WayfinderCompass = { Name = "Wayfinder's Compass", Kind = "Gear", Slot = "Necklace", Class = "Any", MapOnly = true,
        Desc = "Charted ground: +20% damage against elites and bosses, +10% movement speed.",
        Lines = { { Stat = "EliteDamage", Value = 0.2 }, { Stat = "MovementSpeed", Value = 0.1 } } },
    AtlasMantle = { Name = "Cartographer's Mantle", Kind = "Gear", Slot = "ChestPiece", Class = "Any", MapOnly = true,
        Desc = "The map remembers you: +15% max health, and 15% less damage taken while standing still.",
        Lines = { { Stat = "MaxHPPct", Value = 0.15 }, { Stat = "StillDR", Value = 0.15 } } },
    RiftLens = { Name = "Rift Lens", Kind = "Gear", Slot = "Helmet", Class = "Any", MapOnly = true,
        Desc = "Sees the opening: +30% damage against unhurt enemies, +15% crit chance on weak-spot hits.",
        Lines = { { Stat = "FirstHitDamage", Value = 0.3 }, { Stat = "WeakSpotCritChance", Value = 0.15 } } },
}
-- an exotic item of `id` at a rarity + item level (a normal roll of its base, then made exotic)
-- (UPDATE 8 RARITY v4: every exotic IS a Relic -- the rarity argument is ignored, old callers pass the tier's top rarity)
function ItemData.MakeExotic(id: string, _rarity: string?, itemLevel: number): any
    local def = ItemData.Exotics[id]
    if not def then return nil end
    local rarity = "Relic"
    local item
    if def.Kind == "Weapon" then
        item = ItemData.GenerateWeaponOfBase(def.Base, rarity, itemLevel)
    else
        item = ItemData.GenerateRandomGear(def.Slot, rarity, nil, itemLevel)
        if item and def.Lines then
            item.StatLines = item.StatLines or {}
            for _, l in ipairs(def.Lines) do table.insert(item.StatLines, 1, { Stat = l.Stat, Value = l.Value, Exotic = true }) end
        end
    end
    if not item then return nil end
    item.Exotic = id
    item.Name = def.Name
    return item
end
function ItemData.ExoticOf(item: any): any
    return item and item.Exotic and ItemData.Exotics[item.Exotic] or nil
end
-- the colour an item's NAME is shown in everywhere (stash, paper doll, tooltips, HUD, ground loot): exotic orange for
-- an exotic (its rarity still shows in the subtitle), else its rarity colour
function ItemData.ItemColor(item: any): Color3
    if ItemData.ZenithOf(item) then return ItemData.ZENITH_COLOR end -- (CHASE ITEMS: the tier above Relics)
    if ItemData.ExoticOf(item) then return ItemData.EXOTIC_COLOR end
    return item and ItemData.RarityColors[item.Rarity] or Color3.fromRGB(220, 220, 220)
end
-- EXOTICS ARE THEIR OWN CATEGORY (0.59, owner: "Exotics should be their own category, not be stacked on top of another
-- rarity"): an exotic shows as EXOTIC everywhere (label, colour, its own group above every rarity when sorting). Its
-- power is fixed at the TOP rarity of the tier it dropped on (EndgameServer), kept in item.Rarity only for the stat maths.
function ItemData.RarityLabel(item: any): string
    if ItemData.ZenithOf(item) then return "ZENITH" end
    if ItemData.ExoticOf(item) then return "Relic" end
    return item and tostring(item.Rarity or "Common") or "Common"
end
-- the sort rank: exotics above every rarity
function ItemData.SortRank(item: any): number
    if ItemData.ZenithOf(item) then return 200 end -- (CHASE ITEMS: Zeniths above Relics)
    if ItemData.ExoticOf(item) then return 100 end
    return item and ItemData.RarityRank[item.Rarity] or 1
end
-- the name with the exotic diamond in front ("◆ Iron Choir")
function ItemData.DisplayName(item: any): string
    if not item then return "" end
    return ((ItemData.ZenithOf(item) and "❖ ") or (ItemData.ExoticOf(item) and "◆ ") or "") .. tostring(item.Name or "")
end

-- ==================== RELICS v2 (UPDATE 8 LOOT, owner: "build-enabling, PoE's backbone") ====================
-- ~40 named items across every gun class and every gear slot (GLOVES too). A Relic's lines are FIXED (no random lines): each
-- line rolls inside its own range (Fixed = { stat, lo, hi } at item level 100, x RelicScale(item level) like any line, so a
-- relic found later is stronger -- power curve rule), or is a flat mechanic (F = true: conversions, flags, counts). Relic guns
-- also carry a fixed SOCKET pattern (trimmed to what the item level holds) and often a unique trait (Trait). Prism REROLL
-- VALUES rerolls a relic's lines inside their ranges (TuneRelicLine); no other craft touches a relic.
-- DIFFICULTY-TIED: MinDiff = only drops on that difficulty or harder (the new best per difficulty). Needs = a mechanic another
-- builder wires (RELIC_HOOKS): until its flag is true that relic exists (gifts, dev) but never drops.
-- SOURCES (RelicPool / RollRelicId): dungeon bosses (BossExoticChance), Boss Trials (their signature BossTrials.EXOTIC_POOL,
-- filtered by MinDiff), map guardians (map-only relics x3 weight + every other) and THE STREAM: any item drop can be a relic
-- instead at StreamRelicChance (tools/sim/raritysim.py has the hours).
-- Items made before this keep their old rolled lines (no migration). Old exotics keep their ids and signature effects.
do
    local REL = {
        -- ===== GUNS =====
        IronChoir = { Fixed = { { "FireRateBonus", 0.25, 0.35 }, { "MagSizeBonus", 0.5, 0.7 }, { "LocalKinetic", 0.12, 0.18 } }, Sockets = "R-R-R-G" },
        TwinFang = { Fixed = { { "CritChance", 0.10, 0.14 }, { "CritMultiplier", 0.6, 0.9 }, { "ReloadSpeedBonus", 0.3, 0.45 } }, Sockets = "G-G-B" },
        LastWord = { Fixed = { { "WeakSpotMultiplier", 0.8, 1.1 }, { "CritMultiplier", 0.6, 0.9 } }, Sockets = "B-B-G" },
        DragonsMaw = { Fixed = { { "LocalAddedHeat", 0.12, 0.16 }, { "BurnChance", 0.2, 0.3 }, { "CloseRangeDamage", 0.25, 0.35 } }, Sockets = "R-R-R" },
        ArcLance = { Fixed = { { "LocalAddedVolt", 0.12, 0.16 }, { "ShockChance", 0.2, 0.3 }, { "ShockEffect", 0.25, 0.4 } }, Sockets = "B-B-B" },
        Headsman = { Name = "The Headsman", Kind = "Weapon", Base = "DEAGLE", Trait = "Guillotine", MinDiff = "Brutal", Sockets = "G-G R",
            Desc = "Executes non-boss enemies below 15% health (elites below 7%). Finish them and move on.",
            Fixed = { { "WeakSpotMultiplier", 0.7, 1.0 }, { "LowHealthEnemyDamage", 0.25, 0.35 }, { "CritChance", 0.06, 0.1 } } },
        ArcingVerdict = { Name = "Arcing Verdict", Kind = "Weapon", Base = "Glock17", Needs = "ChainAlwaysCrit", Sockets = "G-G-B-B",
            Desc = "Every shot that chains on to another enemy is a critical hit. Built for the Chain shot mod.",
            Fixed = { { "ChainAlwaysCrit", 1, F = true }, { "CritMultiplier", 0.5, 0.8 }, { "LocalAddedVolt", 0.10, 0.14 }, { "CritChance", 0.05, 0.08 } } },
        Leechmaw = { Name = "Leechmaw", Kind = "Weapon", Base = "MP5", Trait = "VampiricSoul", Sockets = "G-G-R",
            Desc = "15% of the damage it deals comes back to you as health.",
            Fixed = { { "FireRateBonus", 0.2, 0.3 }, { "LifeLeech", 0.02, 0.03 } } },
        Thunderhead = { Name = "Thunderhead", Kind = "Weapon", Base = "AUG", Trait = "ChainLightning", MinDiff = "Hard", Sockets = "R-B-B",
            Desc = "Every 5th hit on the same enemy calls lightning down on it for 250% of the hit.",
            Fixed = { { "LocalAddedVolt", 0.12, 0.16 }, { "ShockChance", 0.15, 0.25 }, { "MagSizeBonus", 0.3, 0.5 } } },
        Spillway = { Name = "Spillway", Kind = "Weapon", Base = "SCAR", Trait = "Overflow", MinDiff = "Nightmare", Sockets = "R-R-G",
            Desc = "Damage past a kill pours into your next hit. Packs fall in a chain.",
            Fixed = { { "OverkillCarry", 0.3, 0.5 }, { "LocalKinetic", 0.12, 0.18 }, { "FireRateBonus", 0.1, 0.2 } } },
        ReapersBell = { Name = "Reaper's Bell", Kind = "Weapon", Base = "AA12", Trait = "ReapersToll", MinDiff = "Torment", Sockets = "R-R-G",
            Desc = "Kills refill the drum, and every kill in a chain hits harder. Wounds stack deeper.",
            Fixed = { { "ChainKillDamage", 0.04, 0.06 }, { "BleedChance", 0.2, 0.3 }, { "BleedStacks", 2, F = true } } },
        PhantomVow = { Name = "Phantom Vow", Kind = "Weapon", Base = "M40", Trait = "PhantomRound", Sockets = "B-G-G",
            Desc = "Every 6th trigger pull that hits deals 200% more damage.",
            Fixed = { { "WeakSpotMultiplier", 0.7, 1.0 }, { "ReloadSpeedBonus", 0.3, 0.45 } } },
        GlacierHeart = { Name = "Glacier Heart", Kind = "Weapon", Base = "PPSH", Trait = "Brittle", MinDiff = "Nightmare", Sockets = "G-G-B-B",
            Desc = "Half its Kinetic damage turns to Cryo, and anything suffering an ailment breaks easier.",
            Fixed = { { "ConvertKineticToCryo", 0.5, F = true }, { "ChillChance", 0.2, 0.3 }, { "LocalAddedCryo", 0.10, 0.14 } } },
        Cinderfall = { Name = "Cinderfall", Kind = "Weapon", Base = "AK47", MinDiff = "Torment", Sockets = "R-R-R-B",
            Desc = "Most of its Kinetic damage burns as Heat. A Burn build's rifle.",
            Fixed = { { "ConvertKineticToHeat", 0.6, F = true }, { "BurnChance", 0.25, 0.35 }, { "HeatDamage", 0.25, 0.4 } } },
        HollowSaint = { Name = "Hollow Saint", Kind = "Weapon", Base = "VoidDisintegrator", MinDiff = "Cataclysm", Sockets = "B-B-B-R",
            Desc = "Rots what it touches: Wither stacks deeper and hits harder.",
            Fixed = { { "WitherChance", 0.25, 0.35 }, { "WitherEffect", 0.3, 0.5 }, { "VoidDamage", 0.25, 0.4 } } },
        LongshotCovenant = { Name = "Longshot Covenant", Kind = "Weapon", Base = "M82", MinDiff = "Oblivion", Sockets = "B-B-G-G",
            Desc = "Rounds pass through two more enemies and hit harder the further they fly.",
            Fixed = { { "LongRangeDamage", 0.3, 0.45 }, { "PierceCount", 2, F = true }, { "PierceDamage", 0.15, 0.25 } } },
        EventHorizon = { Name = "Event Horizon", Kind = "Weapon", Base = "Railgun", Trait = "Singularity", MinDiff = "Singularity", Sockets = "B-B-B-W-G",
            Desc = "Weak-spot hits can collapse on the target and strike it again. Its white socket takes any colour.",
            Fixed = { { "WeakSpotMultiplier", 0.8, 1.1 }, { "ShockEffect", 0.3, 0.5 }, { "CritChance", 0.08, 0.12 } } },
        -- ===== GEAR =====
        Bandolier = { GearBase = "HunterLocket", Desc = "Belts of spare rounds: a much bigger magazine, and the first rounds of each one hit harder.",
            Fixed = { { "MagSizeBonus", 0.4, 0.6 }, { "ReloadSpeedBonus", 0.15, 0.25 }, { "FreshMagDamage", 0.15, 0.25 } } },
        DrifterBoots = { GearBase = "DriftBoots", Desc = "Never stop moving: more damage and speed while you're on the move.",
            Fixed = { { "MovingDamage", 0.15, 0.25 }, { "MovementSpeed", 0.08, 0.12 }, { "AgilityPct", 0.15, 0.25 } } },
        HawkeyeVisor = { GearBase = "ScoutHelm", Desc = "Finds the seam in any armour: weak spots hit harder and crit more.",
            Fixed = { { "WeakSpotMultiplier", 0.2, 0.3 }, { "WeakSpotCritChance", 0.08, 0.12 }, { "CritChance", 0.03, 0.05 } } },
        BastionShell = { GearBase = "BulwarkRig", Fixed = { { "PlatingPct", 0.25, 0.4 }, { "MaxHPPct", 0.06, 0.1 } } },
        PrismCore = { GearBase = "PrismPendant", Desc = "A lens for every element: your ailments land more often and last longer.",
            Fixed = { { "AilmentDuration", 0.4, 0.6 }, { "AilmentChance", 0.15, 0.25 }, { "AllElemResist", 0.08, 0.12 } } },
        WayfinderCompass = { GearBase = "LuckyCharm", Desc = "Charted ground: more damage against elites and bosses, faster feet, better finds.",
            Fixed = { { "EliteDamage", 0.15, 0.25 }, { "MovementSpeed", 0.08, 0.12 }, { "LootLuck", 0.08, 0.12 } } },
        AtlasMantle = { GearBase = "SentinelCoat", Desc = "The map remembers you: more health and Ward, and less damage taken while you stand still.",
            Fixed = { { "MaxHPPct", 0.12, 0.18 }, { "StillDR", 0.12, 0.18 }, { "WardPct", 0.15, 0.25 } } },
        RiftLens = { GearBase = "GlimmerMask", Desc = "Sees the opening: big damage into unhurt enemies, and weak-spot hits crit more.",
            Fixed = { { "FirstHitDamage", 0.25, 0.35 }, { "WeakSpotCritChance", 0.12, 0.18 } } },
        Stormgrip = { Name = "Stormgrip", Kind = "Gear", Slot = "Gloves", GearBase = "PulseGloves", MinDiff = "Hard",
            Desc = "Cold sparks: your Volt damage also builds Freeze.",
            Fixed = { { "VoltCanFreeze", 1, F = true }, { "VoltDamage", 0.2, 0.3 }, { "ShockChance", 0.10, 0.15 } } },
        ButchersMitts = { Name = "Butcher's Mitts", Kind = "Gear", Slot = "Gloves", GearBase = "KnucklePlates",
            Desc = "Wounds pile up: two more Bleed stacks, and bleeding comes easier.",
            Fixed = { { "BleedStacks", 2, F = true }, { "BleedChance", 0.15, 0.25 }, { "CritMultiplier", 0.2, 0.3 } } },
        QuickdrawWraps = { Name = "Quickdraw Wraps", Kind = "Gear", Slot = "Gloves", GearBase = "FlickerWraps",
            Desc = "Fast hands: quicker reloads, and a fresh magazine hits harder.",
            Fixed = { { "ReloadSpeedBonus", 0.25, 0.35 }, { "FreshMagDamage", 0.2, 0.3 }, { "FireRateBonus", 0.06, 0.1 } } },
        KindlingTouch = { Name = "Kindling Touch", Kind = "Gear", Slot = "Gloves", GearBase = "CombatGloves", MinDiff = "Torment",
            Desc = "Whatever you hold runs hot: a share of every gun's Kinetic damage turns to Heat.",
            Fixed = { { "ConvertKineticToHeat", 0.3, F = true }, { "BurnChance", 0.12, 0.18 }, { "HeatDamage", 0.2, 0.3 } } },
        Wardstep = { Name = "Wardstep", Kind = "Gear", Slot = "Boots", GearBase = "SparkBoots", Needs = "MovingWard",
            Desc = "Movement turns into Ward: while you move, your Ward keeps recharging, even under fire.",
            Fixed = { { "MovingWard", 1, F = true }, { "WardPct", 0.15, 0.25 }, { "MovementSpeed", 0.06, 0.1 } } },
        AnchorTreads = { Name = "Anchor Treads", Kind = "Gear", Slot = "Boots", GearBase = "IronTreads",
            Desc = "Plant your feet: standing still you hit harder and take less. You move slower.",
            Fixed = { { "StillDR", 0.10, 0.15 }, { "StillDamage", 0.15, 0.25 }, { "PlatingPct", 0.15, 0.25 }, { "MovementSpeed", -0.08, F = true } } },
        IronbarkGreaves = { Name = "Ironbark Greaves", Kind = "Gear", Slot = "Leggings", GearBase = "SiegeGreaves", MinDiff = "Nightmare",
            Desc = "Bark over steel: your Plating also cuts Heat, Cryo, Volt and Void hits (half strength).",
            Fixed = { { "PlatingVsElements", 0.5, F = true }, { "PlatingPct", 0.25, 0.35 }, { "MaxHPPct", 0.06, 0.1 } } },
        RacersStride = { Name = "Racer's Stride", Kind = "Gear", Slot = "Leggings", GearBase = "SprinterPants",
            Desc = "Light on your feet: more Agility and speed, and more damage on the move.",
            Fixed = { { "AgilityPct", 0.25, 0.35 }, { "MovementSpeed", 0.06, 0.1 }, { "MovingDamage", 0.10, 0.15 } } },
        LastStand = { Name = "Last Stand Greaves", Kind = "Gear", Slot = "Leggings", GearBase = "BastionLegs", MinDiff = "Ruin",
            Desc = "Below half health you take much less damage, and every kill patches you up.",
            Fixed = { { "LowLifeDR", 0.15, 0.25 }, { "KillHeal", 0.02, 0.03 }, { "MaxHPPct", 0.08, 0.12 } } },
        VoidwovenCoat = { Name = "Voidwoven Coat", Kind = "Gear", Slot = "ChestPiece", GearBase = "HaloCoat", MinDiff = "Cataclysm",
            Desc = "Void damage no longer slips past your Ward.",
            Fixed = { { "WardVsVoid", 1, F = true }, { "WardPct", 0.2, 0.3 }, { "VoidResist", 0.15, 0.2 } } },
        BloodforgedVest = { Name = "Bloodforged Vest", Kind = "Gear", Slot = "ChestPiece", GearBase = "TrooperVest",
            Desc = "Feeds on the fight: a share of your damage heals you, and kills heal more.",
            Fixed = { { "LifeLeech", 0.015, 0.025 }, { "KillHeal", 0.03, 0.04 }, { "MaxHPPct", 0.06, 0.1 } } },
        HuntersHood = { Name = "Hunter's Hood", Kind = "Gear", Slot = "Helmet", GearBase = "RunnerHood",
            Desc = "Marks the big game: more damage against elites and bosses, and better finds.",
            Fixed = { { "EliteDamage", 0.2, 0.3 }, { "AgilityPct", 0.15, 0.25 }, { "LootLuck", 0.06, 0.1 } } },
        ExecutionersMask = { Name = "Executioner's Mask", Kind = "Gear", Slot = "Helmet", GearBase = "GlimmerMask", MinDiff = "Apocalypse",
            Desc = "Non-boss enemies below 8% health die on your next hit, and hurt ones take more.",
            Fixed = { { "ExecutePct", 0.08, F = true }, { "LowHealthEnemyDamage", 0.25, 0.35 }, { "CritChance", 0.03, 0.05 } } },
        WildfireLoop = { Name = "Wildfire Loop", Kind = "Gear", Slot = "Ring", GearBase = "CinderRing", Needs = "BurnSpread",
            Desc = "Burn spreads: when a burning enemy dies, its fire jumps to the enemies around it.",
            Fixed = { { "BurnSpread", 0.5, F = true }, { "BurnChance", 0.10, 0.15 }, { "HeatDamage", 0.15, 0.25 } } },
        FrostbiteBand = { Name = "Frostbite Band", Kind = "Gear", Slot = "Ring", GearBase = "FrostBand", Needs = "ShatterPct",
            Desc = "Chilled enemies you kill shatter, cutting the enemies next to them.",
            Fixed = { { "ShatterPct", 0.1, F = true }, { "ChillChance", 0.10, 0.15 }, { "CryoDamage", 0.15, 0.25 } } },
        GamblersCoil = { Name = "Gambler's Coil", Kind = "Gear", Slot = "Ring", GearBase = "PrismLoop",
            Desc = "Big crits and better finds, paid for with your health.",
            Fixed = { { "CritChance", 0.05, 0.07 }, { "CritMultiplier", 0.3, 0.45 }, { "LootLuck", 0.08, 0.12 }, { "MaxHPPct", -0.1, F = true } } },
        DetonatorsSeal = { Name = "Detonator's Seal", Kind = "Gear", Slot = "Ring", GearBase = "SpikeRing", Needs = "WeakKillBlast", MinDiff = "Dread",
            Desc = "A weak-spot kill sets the target off: it bursts, hurting the enemies around it. Aim pays twice.",
            Fixed = { { "WeakKillBlast", 0.1, F = true }, { "WeakSpotMultiplier", 0.12, 0.2 }, { "IncreasedDamage", 0.06, 0.1 } } },
        EclipsePendant = { Name = "Eclipse Pendant", Kind = "Gear", Slot = "Necklace", GearBase = "EdgePendant", MinDiff = "Eternity",
            Desc = "A share of every gun's Kinetic damage turns to Void, and your Wither bites deeper.",
            Fixed = { { "ConvertKineticToVoid", 0.3, F = true }, { "WitherEffect", 0.25, 0.35 }, { "VoidDamage", 0.2, 0.3 } } },
    }
    for id, d in pairs(REL) do
        local e = ItemData.Exotics[id] or {}
        for k, v in pairs(d) do e[k] = v end
        e.Lines = nil -- (old fixed-value lines: Fixed replaces them)
        if e.Kind == "Weapon" and not e.Class then
            local b = ItemData.BaseWeapons[e.Base]
            local grp = b and ItemData.WeaponGroupOf({ BaseId = e.Base, Class = b.Class })
            e.Class = grp and ItemData.WeaponGroups.ClassName[grp] or "Any"
        end
        e.Class = e.Class or "Any"
        ItemData.Exotics[id] = e
    end
    -- mechanics another builder wires (until then those relics don't drop): OFFENSE ChainAlwaysCrit / BurnSpread / ShatterPct /
    -- WeakKillBlast, DEFENCE MovingWard. (Every relic is our own: own names, own effects and combinations -- never a copy of
    -- another game's item.)
    ItemData.RELIC_HOOKS = { ChainAlwaysCrit = true, MovingWard = true, BurnSpread = true, ShatterPct = true, WeakKillBlast = true } -- (OFFENSE hooks live: CombatServer.Off) -- (MovingWard: DEFENCE hook live)
    -- labels for the new keys (StatDefs; conversions belong to OFFENSE -- only filled when missing)
    local SD = ItemData.StatDefs
    local function Pc(v: number) return tostring(math.round(v * 100)) .. "%" end
    for _, t in ipairs({ "Heat", "Cryo", "Volt", "Void" }) do
        local k = "ConvertKineticTo" .. t
        if not SD[k] then SD[k] = { Label = "Kinetic converted to " .. t, Kind = "pct", Desc = "This share of your Kinetic damage is dealt as " .. t .. " instead.",
            Format = function(v) return Pc(v) .. " of Kinetic damage converted to " .. t end } end
    end
    SD.ChainAlwaysCrit = SD.ChainAlwaysCrit or { Label = "Chained hits always crit", Kind = "pct", Desc = "A shot that chains on to another enemy is always a critical hit.",
        Format = function() return "Shots that chain to another enemy always crit" end }
    SD.WeakKillBlast = SD.WeakKillBlast or { Label = "Weak-spot kills burst", Kind = "pct", Desc = "An enemy you kill with a weak-spot hit bursts, hitting the enemies around it for this share of its max health.",
        Format = function(v) return "Weak-spot kills burst for " .. Pc(v) .. " of the enemy's max health around it" end }
    SD.MovingWard = SD.MovingWard or { Label = "Ward recharges while moving", Kind = "pct", Desc = "While you move your Ward keeps recharging, even while you take damage.",
        Format = function() return "While moving, your Ward recharges even under fire" end }
    -- one relic line at an item level: { Stat, Value, Exotic, RLo, RHi } (RLo / RHi = its range there, for Prism rerolls)
    function ItemData.RelicScale(itemLevel: number?): number
        return ItemData.GearLevelScale(itemLevel) / ItemData.GearLevelScale(100)
    end
    local function R3(v: number): number return math.round(v * 1000) / 1000 end
    function ItemData.RelicLine(spec: any, itemLevel: number?): any
        local stat, lo = spec[1], spec[2]
        local hi = spec[3] or lo
        local k = spec.F and 1 or ItemData.RelicScale(itemLevel)
        local v = (lo + (hi - lo) * math.random()) * k
        local def = SD[stat]
        local line: any = { Id = stat, Name = def and def.Label or stat, Stat = stat, Value = R3(v), Exotic = true }
        if hi > lo then line.RLo, line.RHi = R3(lo * k), R3(hi * k) end
        return line
    end
    function ItemData.TuneRelicLine(l: any)
        if type(l) == "table" and tonumber(l.RLo) and tonumber(l.RHi) and l.RHi > l.RLo then l.Value = R3(l.RLo + (l.RHi - l.RLo) * math.random()) end
    end
    function ItemData.RelicTunable(item: any): boolean
        for _, l in ipairs(ItemData.LinesOf(item, item and item.Slot ~= nil and item.BaseId == nil)) do if (l.RLo and l.RHi) or not l.Exotic then return true end end -- (old exotics' rolled lines too)
        return false
    end
    -- the gun-line side for a relic stat (prefix = damage lines, suffix = the rest)
    local PREFIX = {}
    for _, a in ipairs(ItemData.NEW_GUN_PREFIX or {}) do PREFIX[a.Stat] = true end
    -- an exotic item of `id` at an item level (the rarity argument is ignored: every relic is a Relic)
    function ItemData.MakeExotic(id: string, _rarity: string?, itemLevel: number): any
        local def = ItemData.Exotics[id]
        if not def then return nil end
        local lvl = math.max(1, math.floor(tonumber(itemLevel) or 1))
        local item
        if def.Kind == "Weapon" then
            item = ItemData.GenerateWeaponOfBase(def.Base, "Relic", lvl)
            if not item then return nil end
            item.Prefixes, item.Suffixes = {}, {}
            local DT = ItemData.DT
            for _, spec in ipairs(def.Fixed or {}) do
                local line = ItemData.RelicLine(spec, lvl)
                local pre = PREFIX[spec[1]] or (DT and DT.OFFENCE_STATS and DT.OFFENCE_STATS[spec[1]] and not string.find(spec[1], "Chance$")) or false
                table.insert(pre and item.Prefixes or item.Suffixes, line)
            end
            item.UniqueTrait = def.Trait and ItemData.TraitById[def.Trait] and table.clone(ItemData.TraitById[def.Trait]) or nil
            item.Proc = nil
            if def.Sockets then -- (the fixed pattern, cut to the sockets this item level holds)
                local list = ItemData.ParseSockets(def.Sockets)
                local max = ItemData.MaxSockets(lvl)
                while #list > max do table.remove(list) end
                item.Sockets = ItemData.JoinSockets(ItemData.CapLinks(list, lvl)) -- (the link gate too)
            end
        else
            local slotType = ItemData.GearType(def.Slot)
            if ItemData.GEAR_V3 and ItemData.GenerateGearV3 then
                item = ItemData.GenerateGearV3(slotType, "Relic", lvl, def.GearBase)
            else
                item = ItemData.GenerateRandomGear(def.Slot, "Relic", nil, lvl)
            end
            if not item then return nil end
            item.StatLines = {}
            for _, spec in ipairs(def.Fixed or {}) do table.insert(item.StatLines, ItemData.RelicLine(spec, lvl)) end
        end
        item.Exotic = id
        item.Name = def.Name
        return item
    end
    -- drop rules
    function ItemData.RelicLive(id: string): boolean
        local d = ItemData.Exotics[id]
        return d ~= nil and (not d.Needs or ItemData.RELIC_HOOKS[d.Needs] == true)
    end
    function ItemData.RelicAllowed(id: string, diff: string?): boolean
        local d = ItemData.Exotics[id]
        if not d or d.Zenith or not ItemData.RelicLive(id) then return false end -- (CHASE ITEMS: Zeniths never join a relic pool)
        if d.MinDiff and (ItemData.DifficultyRank[diff or ""] or 1) < (ItemData.DifficultyRank[d.MinDiff] or 1) then return false end
        return true
    end
    -- source "Stream" | "Boss" | "Map" (map-only relics x MAP_ONLY_WEIGHT there, never elsewhere)
    ItemData.RELIC_MAP_ONLY_WEIGHT = 3
    function ItemData.RelicPool(source: string, diff: string?): { string }
        local ids = {}
        for id in pairs(ItemData.Exotics) do table.insert(ids, id) end
        table.sort(ids)
        local out = {}
        for _, id in ipairs(ids) do
            local d = ItemData.Exotics[id]
            if ItemData.RelicAllowed(id, diff) then
                if d.MapOnly then
                    if source == "Map" then for _ = 1, ItemData.RELIC_MAP_ONLY_WEIGHT do table.insert(out, id) end end
                else
                    table.insert(out, id)
                end
            end
        end
        return out
    end
    function ItemData.RollRelicId(source: string, diff: string?): string?
        local pool = ItemData.RelicPool(source, diff)
        return pool[math.random(1, math.max(1, #pool))]
    end
    -- a trial / list pool narrowed by difficulty (the whole Stream pool when nothing in it is allowed)
    function ItemData.FilterRelics(list: { string }?, diff: string?): { string }
        local out = {}
        for _, id in ipairs(list or {}) do if ItemData.RelicAllowed(id, diff) then table.insert(out, id) end end
        if #out == 0 then out = ItemData.RelicPool("Boss", diff) end
        return out
    end
    -- THE STREAM: the chance that one item drop is a relic instead (difficulty area ^ 0.5: Easy x1 .. Singularity x3.2)
    ItemData.RELIC_STREAM = { Base = 0.00015, AreaExp = 0.5 }
    function ItemData.StreamRelicChance(diff: string?): number
        local a = (ItemData.RARITY_AREA and ItemData.RARITY_AREA[diff or "Easy"]) or 1
        return ItemData.RELIC_STREAM.Base * a ^ ItemData.RELIC_STREAM.AreaExp
    end
    -- RELIC GEAR WORN AT ONCE (was 1 since 0.53): relics are the backbone now -- any number (8 = every slot)
    ItemData.RELIC_GEAR_MAX = 8
end

-- ==================== ZENITH (CHASE ITEMS 2026-11-06, contract docs/CHASE_ITEMS_2026-11-06.md) ====================
-- Owner: "We also need to add chase items like POE" -> a tier ABOVE Relics: six build-warping items, each with a real CATCH,
-- so rare the whole server hears about it. Two class-neutral gear pieces drop from ANY kill (ZENITH_GLOBAL, odds of the rarest
-- world drops, better on harder difficulties); five guns, ONE PER CLASS, only from the pinnacle (ZENITH_PINNACLE: the Summit,
-- owner 2026-11-06 "Even it out"). Every drop rate is in ZENITH_TUNE.Drops (one table). Never in RelicPool / the stream /
-- boss / map / trial pools: their own roll (AimRngServer/ZenithServer). A Zenith is stored like a relic (item.Exotic = its id,
-- Rarity "Relic" for the stat maths, fixed lines + sockets) and SHOWN as ZENITH everywhere (ZenithOf: label, colour, sort,
-- ❖ marker). Mechanics: StatCalculator (magazine / reload / weak spot / body), ZenithServer (hits, kills, heat, damage taken),
-- ZenithClient (heat HUD, aim slow, spread). Numbers live in ZENITH_TUNE (text + combat read the same table).
-- TWIN GLASS: the chase currency -- an exact copy of a weapon / gear piece (new Uid); both copies are TWINNED (no craft of any kind,
-- can't be twinned again). Server-atomic in ZenithServer.Twin (Forge row TWIN GLASS).
-- SHIP DARK: ZENITH_LIVE = false -> no Zenith / Twin Glass drops in normal play, the patch-notes entry and the Index section hide;
-- F6 gifts and the Studio dev hooks still work. The OWNER flips it (never a builder).
ItemData.ZENITH_LIVE = false
ItemData.ZENITH_COLOR = Color3.fromRGB(170, 255, 236) -- (pale prismatic white-teal: clear of Relic orange, Mythic red, Rare yellow)
ItemData.ZENITH_ORDER = { "GlassHalo", "SaintsRicochet", "FurnaceHeart", "LongPromise", "Bloomshot", "Lattice", "UnbrokenThread" } -- (APPEND only)
ItemData.ZENITH_GLOBAL = { "GlassHalo", "UnbrokenThread" } -- (class-neutral gear: any kill)
ItemData.ZENITH_PINNACLE = { "SaintsRicochet", "FurnaceHeart", "LongPromise", "Bloomshot", "Lattice" } -- (one gun per class: the Summit only)
ItemData.ZENITH_TUNE = {
    -- More = a Zenith's own "more damage" (StatCalculator; a card line), set from the balance sim (docs/CHASE_ITEMS_2026-11-06.md
    -- "Balance"): each one's best case lands ~1.5-2x the best relic of its class / slot
    GlassHalo = { WeakBonus = 3.0, Body = 0.5 },                         -- weak-spot BONUS x3 (2.3x -> 4.9x), body x0.5, weak kill = +1 round
    SaintsRicochet = { R = 20, Jumps = 3, Mag = 0.5, Reload = 1.4 },     -- jumps strike the next enemy's weak spot for the full hit
    FurnaceHeart = { Lock = 2.5, Idle = 0.35, Drain = 0.45, Vent = 0.5, More = 1.9 }, -- heat in rounds: Idle s without firing -> Drain x capacity a s; a weak hit vents Vent rounds
    LongPromise = { Grow = 0.2, Cap = 30, AdsMove = 0.7, More = 1.3 },              -- +20% per enemy already passed; ADS move x0.7
    Bloomshot = { R = 15, Spread = 1.4, Depth = 2 },                    -- fragments = the killing pellet + the pull's pellets still to land
    Lattice = { N = 4, R = 12, Pct = 0.6, Taken = 1.15, Firing = 0.3 }, -- damage taken x1.15 within Firing s of a shot
    -- +Per damage a stack, a stack per pull that lands anything (a pellet gun: any pellet; a beam: per BeamEvery s on target), up
    -- to Max; a pull that lands nothing within Grace s = a miss: every stack gone + damage taken x Taken for Fray s. Decay (owner
    -- 2026-11-06): Decay s with no hit at all -> every stack goes (no Fray: that's not a miss); a floor / run start clears them too
    UnbrokenThread = { Per = 0.04, Max = 15, Taken = 1.15, Fray = 2, BeamEvery = 0.3, Grace = 0.35, More = 1.35, Decay = 5 },
    -- EVERY ZENITH DROP RATE (CHASE ITEMS overnight 2026-11-06, owner: "match PoE's rarest drops"; tools/sim/raritysim.py prints
    -- the hours, keep it equal). Kill / Glass = per kill x RARITY_AREA ^ AreaExp (Mob x PacksPilot.RARE for pack fodder): Kill = one
    -- of ZENITH_GLOBAL (~1 in 2,000 h at the top open tier), Glass = Twin Glass (~1 in 10,000 h). Apex / Uber = per Summit kill, one
    -- of ZENITH_PINNACLE. GlassUber = Twin Glass per Unbound kill (0: Twin Glass is a world drop only, like the rarest currency).
    -- LOOSEN = scale these numbers (one edit).
    Drops = {
        Kill = { Mob = 6.1e-7, Elite = 3.65e-6, Boss = 1.82e-5, SuperBoss = 3.65e-5, AreaExp = 0.5 },
        Glass = { Mob = 1.22e-7, Elite = 7.3e-7, Boss = 3.66e-6, SuperBoss = 7.3e-6, AreaExp = 0.5 },
        Apex = 0.01, Uber = 0.03, GlassUber = 0,
    },
}
do
    local Z = {
        GlassHalo = { Name = "Glass Halo", Kind = "Gear", Slot = "Helmet", GearBase = "HaloCirclet", Class = "Any",
            Desc = "Your weak-spot damage bonus is tripled, and a weak-spot kill puts the round back in your magazine.",
            Catch = "Body shots deal 50% less damage.",
            Fixed = { { "WeakSpotMultiplier", 0.2, 0.3 }, { "WeakSpotCritChance", 0.08, 0.12 }, { "WardPct", 0.15, 0.25 } } },
        SaintsRicochet = { Name = "Saint's Ricochet", Kind = "Weapon", Base = "P226", Sockets = "G-G-B-B",
            Desc = "A weak-spot hit ricochets to the nearest enemy within 20 studs and strikes its weak spot for full damage, up to 3 jumps.",
            Catch = "Half the magazine, and reloads take 40% longer.",
            Fixed = { { "WeakSpotMultiplier", 0.5, 0.8 }, { "CritChance", 0.06, 0.1 }, { "LocalKinetic", 0.12, 0.18 } } },
        FurnaceHeart = { Name = "Furnace Heart", Kind = "Weapon", Base = "M60", Sockets = "R-R-R-B",
            Desc = "Never reloads: firing builds HEAT instead. Heat drains fast while you hold fire and weak-spot hits vent it. Magazine size is heat capacity.",
            Catch = "Past full heat the gun locks for 2.5 seconds.",
            Fixed = { { "FireRateBonus", 0.15, 0.25 }, { "MagSizeBonus", 0.3, 0.5 }, { "LocalAddedHeat", 0.10, 0.14 } } },
        LongPromise = { Name = "Long Promise", Kind = "Weapon", Base = "SCOUT", Sockets = "B-B-G-G",
            Desc = "Every shot pierces every enemy in its line, and hits 20% harder for each enemy it has already passed through.",
            Catch = "A one-round magazine, and you move 30% slower while aiming down sights.",
            Fixed = { { "LongRangeDamage", 0.3, 0.45 }, { "WeakSpotMultiplier", 0.6, 0.9 }, { "ReloadSpeedBonus", 0.3, 0.45 } } },
        Bloomshot = { Name = "Bloomshot", Kind = "Weapon", Base = "KSG", Sockets = "R-R-G-G",
            Desc = "A kill bursts the body: the pellets that killed it fly on at enemies within 15 studs.",
            Catch = "Pellet spread is 40% wider.",
            Fixed = { { "CloseRangeDamage", 0.25, 0.35 }, { "FireRateBonus", 0.10, 0.15 }, { "LocalKinetic", 0.10, 0.16 } } },
        Lattice = { Name = "Lattice", Kind = "Weapon", Base = "QuadBeam", Sockets = "B-B-B-G",
            Desc = "The beam forks from its target to up to 4 more enemies within 12 studs at 60% damage.",
            Catch = "You take 15% more damage while firing.",
            Fixed = { { "LocalAddedVolt", 0.12, 0.16 }, { "ShockChance", 0.15, 0.25 }, { "ShockEffect", 0.2, 0.3 } } },
        UnbrokenThread = { Name = "Unbroken Thread", Kind = "Gear", Slot = "Gloves", GearBase = "GripGloves", Class = "Any",
            Desc = "Every hit in a row without a miss adds 4% damage, up to 60% at 15 hits. Beams build a stack every 0.3 s on target; a shotgun blast counts as one hit if any pellet lands. The stacks fade after 5 s without a hit, and every floor starts at 0.",
            Catch = "A miss clears every stack, and you take 15% more damage for 2 seconds.",
            Fixed = { { "FireRateBonus", 0.06, 0.1 }, { "CritChance", 0.05, 0.08 }, { "MaxHPPct", 0.06, 0.1 } } },
    }
    for _, id in ipairs(ItemData.ZENITH_GLOBAL) do Z[id].Global = true end
    for _, id in ipairs(ItemData.ZENITH_PINNACLE) do Z[id].Pinnacle = true end
    for id, e in pairs(Z) do
        e.Zenith = true
        if e.Kind == "Weapon" and not e.Class then
            local b = ItemData.BaseWeapons[e.Base]
            local grp = b and ItemData.WeaponGroupOf({ BaseId = e.Base, Class = b.Class })
            e.Class = grp and ItemData.WeaponGroups.ClassName[grp] or "Any"
        end
        ItemData.Exotics[id] = e
    end
    function ItemData.ZenithOf(item: any): any
        local d = type(item) == "table" and item.Exotic and ItemData.Exotics[item.Exotic]
        return (d and d.Zenith) and d or nil
    end
    -- the Zeniths you carry into a fight: { [id] = true } or nil (the gun + every worn gear piece)
    function ItemData.ZenithActive(weapon: any, gear: any): any
        local out = nil
        local function Add(it: any) if ItemData.ZenithOf(it) then out = out or {}; out[it.Exotic] = true end end
        Add(weapon)
        if type(gear) == "table" then for _, g in pairs(gear) do Add(g) end end
        return out
    end
    -- a Zenith's own "more damage" line for the card ("❖ 30% MORE damage"), or nil
    function ItemData.ZenithMoreText(id: string?): string?
        local t = id and ItemData.ZENITH_TUNE[id]
        local m = t and tonumber(t.More)
        if not m or m == 1 then return nil end
        return "❖ " .. tostring(math.floor((m - 1) * 100 + 0.5)) .. "% MORE damage"
    end
    -- (owner 2026-11-06) a Zenith's item level = the PLAYER's level (not the floor's monster level), clamped like every other
    -- item level (1 .. MAX_LEVEL): the global roll, the Summit roll, dev drops and F6 GIVE all read this
    function ItemData.ZenithLevel(playerLevel: number?): number
        return math.clamp(math.floor(tonumber(playerLevel) or 1), 1, ItemData.MAX_LEVEL)
    end
    function ItemData.MakeZenith(id: string, itemLevel: number): any
        if not (ItemData.Exotics[id] and ItemData.Exotics[id].Zenith) then return nil end
        return ItemData.MakeExotic(id, "Relic", itemLevel)
    end
    -- DROPS (tools/sim/raritysim.py prints the hours -- keep these equal): per kill, like the Lodestar (loot quantity doesn't touch
    -- it), x RARITY_AREA ^ AreaExp (Easy x1 .. Annihilation x2.8 .. Singularity x3.2). Mob x PacksPilot.RARE for pack fodder.
    -- (the numbers: ZENITH_TUNE.Drops -- these names read the same tables)
    ItemData.ZENITH_KILL = ItemData.ZENITH_TUNE.Drops.Kill
    ItemData.TWIN_GLASS_KILL = ItemData.ZENITH_TUNE.Drops.Glass
    function ItemData.ZenithApexChance(uber: boolean?): number return ItemData.ZENITH_TUNE.Drops[uber and "Uber" or "Apex"] or 0 end
    function ItemData.TwinGlassUberChance(): number return ItemData.ZENITH_TUNE.Drops.GlassUber or 0 end
    -- the tier is live (ZENITH_LIVE), or a Studio test turned it on (workspace DevZenithLive) -- for UI that hides while dark
    function ItemData.ZenithShown(): boolean
        if ItemData.ZENITH_LIVE == true then return true end
        return game:GetService("RunService"):IsStudio() and workspace:GetAttribute("DevZenithLive") == true
    end
    function ItemData.ZenithKillChance(t: any, kind: string, diff: string?): number
        local a = (ItemData.RARITY_AREA and ItemData.RARITY_AREA[diff or "Easy"]) or 1
        return (t[kind] or t.Mob) * a ^ (t.AreaExp or 0.5)
    end
    -- TWIN GLASS (a currency: MaterialOrder -> bag, toasts, save defaults; gifts; the Exchange's price list)
    ItemData.ZENITH_MATS = { "TwinGlass" }
    -- (Unlock: while the tier is dark the MATERIALS list only shows it once you own one -- an "x0" row for everyone was a leak)
    ItemData.MaterialDefs.TwinGlass = { Name = "Twin Glass", Short = "Twin", IconKey = "mat_catalyst", Color = ItemData.ZENITH_COLOR, NoRoll = true,
        Unlock = (ItemData.ZENITH_LIVE == true) and 1 or 1e9,
        Desc = "TWIN GLASS at the Forge: makes an exact copy of a weapon or gear piece. Both copies become TWINNED: no crafting of any kind, and they can't be twinned again. The copy comes out locked. Beyond rare: any kill, and the Summit Unbound." }
    for _, k in ipairs(ItemData.ZENITH_MATS) do
        if not table.find(ItemData.MaterialOrder, k) then table.insert(ItemData.MaterialOrderAll, k); table.insert(ItemData.MaterialOrder, k) end
    end
    -- can this item be twinned? (the server's word; the Forge row asks it too)
    function ItemData.CanTwin(item: any): (boolean, string?)
        if type(item) ~= "table" or type(item.Uid) ~= "string" then return false, "That's not an item." end
        if item.Twinned then return false, "This item is already twinned." end
        if item.Kind == "Gem" or item.Kind == "ShotMod" then return false, "Only weapons and gear can be twinned." end
        return true, nil
    end
    -- the copy (call only after CanTwin): a deep copy with a new Uid; BOTH become Twinned. Shot mods in its sockets and a fitted
    -- Gunwright stay with the original (they are items of their own: copying them would duplicate them). The copy comes out
    -- LOCKED (owner 2026-11-06), whatever the original's lock state; it unlocks like any item.
    function ItemData.TwinCopy(item: any): any
        local function Deep(t: any): any
            if type(t) ~= "table" then return t end
            local o = {}
            for k, v in pairs(t) do o[k] = Deep(v) end
            return o
        end
        local c = Deep(item)
        c.Uid = (item.Slot ~= nil and item.BaseId == nil and "G_" or "W_") .. math.random(10000000, 99999999)
        c.SocketMods, c.Riftmod, c.RunLoot = nil, nil, nil
        c.Locked = true
        item.Twinned, c.Twinned = true, true
        return c
    end
end
-- (UPDATE 8 LOOT: dungeon boss relic chance x2 with the stream added -- raritysim.py)
ItemData.EXOTIC_BOSS_CHANCE = { Mini = 0.001, Major = 0.0025, Super = 0.006 }

-- (UPDATE 8 TITLE GRADES) a title's effort tier 1-15 -> its rarity label (colour / sort): 1-2 Common, 3-5 Uncommon, 6-9 Rare,
-- 10-13 Mythic, 14-15 Relic
function ItemData.TitleRarity(tier: number?): string
    local t = tonumber(tier) or 1
    return (t <= 2 and "Common") or (t <= 5 and "Uncommon") or (t <= 9 and "Rare") or (t <= 13 and "Mythic") or "Relic"
end
-- ===== TITLES v4 (0.75, owner: "The titles dont make sense buff wise, they dont remotely make logical sense in terms of
-- harder to get = bigger buffs, a lot of the titles are outdated or far too easy") =====
-- Every live title gets an EFFORT TIER 1..15, measured against the difficulty ladder and its level bands (DifficultyMinLevel:
-- clearing Brutal ~ L18-30 = tier 5, Torment ~ L45 = 7 ... Singularity ~ L303 = 14, level 400 = 15). The tier sets its
-- RARITY (Rarities[tier]) and its buff SIZE: each stat it already had = TITLE_UNIT[stat] x tier, x a share for how many
-- stats it carries (one stat x1.4, two x1, three x0.8) -- so a harder title is always the bigger one. Flat HP / armor /
-- regen became % (flat numbers meant nothing at level 400). The easiest requirements were raised (TITLE_NEED).
-- Retired, season (Granted) and cosmetic titles are left as they were. Description = the buffs, generated.
ItemData.TITLE_TIER = {
    -- (difficulty clears = that difficulty's top loot rarity: Easy 2 .. Singularity 15; levels a step lower -- they come
    -- with playing anyway)
    Rookie = 1, SidearmSpecialist = 1, TargetPlinker = 1,
    IncursionScout = 2, SteadyHand = 2, Bladesmith = 2,
    BiomeConqueror = 3, Gunslinger = 3, EliteHunter = 3,
    CelestialSentinel = 4, ApexDeadeye = 4, TitanSlayer = 4, Demolitionist = 4, Marksman = 4, Executioner = 4, AscInitiate = 4,
    HyperVelocityStalker = 5, Riftwalker = 5, Deathless = 5, Flawless = 5, OmniConstellation = 5,
    ClassVanguard = 5, ClassGunslinger = 5, ClassMarksman = 5, ClassBreacher = 5, ClassArcwright = 5,
    GodOfIncursion = 6, PointBlankBruiser = 6, FocusVirtuoso = 6, Surgical = 6, ColossusBreaker = 6, AscAdept = 6, Veteran80 = 6,
    ArchonBane = 6, Timekeeper = 6, EchoBreaker = 6, Slagbreaker = 6,
    TormentClear = 7, VoidSovereign = 7, PerfectAim = 7, Untouchable = 7, Ghost = 7, ApexPredator = 7, AscExalted = 7,
    Immortal = 7, Centurion = 7,
    CataclysmClear = 8, RiftLord = 8, AscAscendant = 8, VoltaicAscendant = 8,
    Godslayer = 8, Chronobreaker = 8, Forgeborn = 8, VoidWarden = 8,
    OblivionClear = 9, ExtinctionEvent = 9, GiantsBane = 9,
    RuinClear = 10, Worldbreaker = 10, Bicentennial = 10,
    DreadClear = 11,
    ApocalypseClear = 12, Tricentennial = 12,
    AnnihilationClear = 13,
    EternityClear = 14,
    SingularityClear = 15, Limitless = 15,
    -- (0.93 boss trophy titles: rare drops)
    Wingbreaker = 12, LastTick = 12, Silencebringer = 12, Quencher = 12, Vaultbreaker = 12, BroodBane = 12, Duelbreaker = 12,
    HouseBreaker = 12, Worldeater = 12,
}
-- per tier, per stat (x the stat-count share): tier 15 one-stat Damage = +31%, a two-stat title +22% and its partner
ItemData.TITLE_UNIT = {
    IncreasedDamage = 0.015, CritChance = 0.004, CritMultiplier = 0.012, WeakSpotMultiplier = 0.01, FireRateBonus = 0.004,
    ReloadSpeedBonus = 0.006, MagSizeBonus = 0.008, MovementSpeed = 0.003, DamageReduction = 0.004, MaxHPPct = 0.006,
    ArmorPct = 0.01, HPRegenPct = 0.0004, LootLuck = 0.006, GoldBonus = 0.015, MeleeDamage = 2,
}
local TITLE_FLAT_TO_PCT = { MaxHP = "MaxHPPct", Armor = "ArmorPct", HPRegen = "HPRegenPct", Luck = "LootLuck" } -- (Luck is attribute POINTS: 0.05 of one did nothing)
-- requirements that were far too easy for what they now give
local TITLE_NEED = {
    SidearmSpecialist = { 250, "Eliminate 250 enemies" }, TargetPlinker = { 150, "Land 150 weak-spot hits (any gun)" },
    Bladesmith = { 100, "Eliminate 100 enemies with melee" }, Gunslinger = { 2500, "Eliminate 2,500 enemies" },
    EliteHunter = { 250, "Eliminate 250 elite enemies" }, ApexDeadeye = { 2500, "Land 2,500 weak-spot hits (any gun)" },
    TitanSlayer = { 50, "Defeat 50 bosses" }, Demolitionist = { 3000, "Land 3,000 piercing hits (high-caliber guns)" },
    VoidSovereign = { 250, "Defeat 250 bosses" }, ColossusBreaker = { 15, "Defeat 15 biome superbosses" },
}
do
    local order = { "IncreasedDamage", "CritChance", "CritMultiplier", "WeakSpotMultiplier", "FireRateBonus", "ReloadSpeedBonus",
        "MagSizeBonus", "MovementSpeed", "DamageReduction", "MaxHPPct", "ArmorPct", "HPRegenPct", "LootLuck", "GoldBonus", "MeleeDamage" }
    local SHARE = { 1.4, 1.0, 0.8, 0.7 }
    for id, tier in pairs(ItemData.TITLE_TIER) do
        local t = ItemData.Titles[id]
        if t and not t.Retired then
            local keys = {}
            for k in pairs(t.StatBuffs or {}) do
                local nk = TITLE_FLAT_TO_PCT[k] or k
                if ItemData.TITLE_UNIT[nk] and not table.find(keys, nk) then table.insert(keys, nk) end
            end
            if #keys == 0 then keys = { "IncreasedDamage" } end
            local share = SHARE[math.min(#keys, #SHARE)]
            local buffs, parts = {}, {}
            for _, k in ipairs(order) do
                if table.find(keys, k) then
                    local v = ItemData.TITLE_UNIT[k] * tier * share
                    v = (k == "MeleeDamage") and math.round(v) or (math.round(v * 10000) / 10000)
                    buffs[k] = v
                    local txt = ItemData.StatDefs[k] and ItemData.FormatStat(k, v)
                        or ((k == "MeleeDamage") and ("+" .. v .. " Melee Damage"))
                        or string.format("+%s%% %s", tostring(math.round(v * 1000) / 10), (k == "DamageReduction") and "Damage Reduction" or k)
                    table.insert(parts, txt)
                end
            end
            t.StatBuffs = buffs
            t.Tier = tier
            t.Rarity = ItemData.TitleRarity(tier) -- (UPDATE 8 GEM + TITLE GRADES: the 5 rarities; the TIER 1-15 still sets the buff size)
            t.Description = table.concat(parts, ", ") .. "."
            local need = TITLE_NEED[id]
            if need and t.Check then t.Check.Need = need[1]; t.Requirement = need[2] end
        end
    end
    -- (UPDATE 8) every other title (season, trophy, show-off) shows its grade on the 5 rarities too
    for _, t in pairs(ItemData.Titles) do t.Rarity = ItemData.NormRarity(t.Rarity) or t.Rarity end
    -- re-sort: rarity, then the old order inside it (the earlier v4 pass sorted on the old rarities)
    local list = {}
    for id, t in pairs(ItemData.Titles) do table.insert(list, { Id = id, T = t }) end
    table.sort(list, function(x, y)
        local rx, ry = rawget(ItemData.RarityRank, x.T.Rarity) or 1, rawget(ItemData.RarityRank, y.T.Rarity) or 1 -- (UPDATE 8: the 5 rarities)
        if rx ~= ry then return rx < ry end
        local ox, oy = tonumber(x.T.Order) or 99, tonumber(y.T.Order) or 99
        if ox ~= oy then return ox < oy end
        return x.Id < y.Id
    end)
    for k, e in ipairs(list) do e.T.Order = k end
end


-- (0.69: the rarity-gradient scanner + drift start on the client once the whole module is loaded)
if game:GetService("RunService"):IsClient() then task.defer(function() pcall(ItemData.StartRarityDrift) end) end

-- (0.93 TITLE SKILL FLOOR) every difficulty-based title says the bot skill it needs
do
    local KINDS = { FloorOn = true, BossesOn = true, FastBossOn = true, NoHitFloors = true, DeathlessRun = true }
    for _, t in pairs(ItemData.Titles or {}) do
        local c = t.Check
        local d = c and KINDS[c.Kind] and (c.Diff or c.MinDiff)
        if d and type(t.Requirement) == "string" and not string.find(t.Requirement, "bot skill", 1, true) then
            local cap = ItemData.TitleMaxLevel(d)
            t.Requirement ..= string.format(" at bot skill %d+", ItemData.TitleMinSkill(d))
                .. ((cap < (ItemData.MAX_LEVEL or 400)) and string.format(", level %d or lower", cap) or "")
        end
    end
end

-- ===== LAUNCH CAP (ItemData.CONTENT_CAP / MAX_LEVEL): trial tiers past the cap are cut from their lists (data kept), and titles
-- nobody can earn under the cap are hidden like Retired ones (owners keep them). Runs once at load; a cap raise undoes it. =====
do
    local okA, AT = pcall(function() return require(script.Parent:WaitForChild("AscensionTrials")) end)
    if okA and type(AT) == "table" and AT.Tiers then
        local n = 0
        for i, t in ipairs(AT.Tiers) do
            if ItemData.DifficultyOpen(t.Difficulty) and (t.Level or 1) <= ItemData.MAX_LEVEL then n = i else break end
        end
        AT.MAX_TIER = n
    end
    local okB, BT = pcall(function() return require(script.Parent:WaitForChild("BossTrials")) end)
    if okB and type(BT) == "table" and BT.Tiers then
        local n = 0
        for i, t in ipairs(BT.Tiers) do if ItemData.DifficultyOpen(t.Difficulty) then n = i else break end end
        BT.MAX_TIER = n
    end
    -- MONSTER LEVELS past the cap: an open difficulty's monsters stop at MAX_LEVEL + CAP_MONSTER_OVER (Annihilation 200-250 ->
    -- 200-210). Health climbs ~7% a level up there, so the old top (250 for a level-200 player) made its last-floor boss a ~19 minute
    -- fight (Phase 6 harness); ~1 minute now. MONSTER_LEVEL_BUILT keeps the 400-ladder ranges for a cap raise.
    ItemData.CAP_MONSTER_OVER = 10
    ItemData.MONSTER_LEVEL_BUILT = ItemData.MONSTER_LEVEL_BUILT or {}
    do
        local top = ItemData.MAX_LEVEL + ItemData.CAP_MONSTER_OVER
        for d, r in pairs(ItemData.MONSTER_LEVEL or {}) do
            ItemData.MONSTER_LEVEL_BUILT[d] = ItemData.MONSTER_LEVEL_BUILT[d] or { r[1], r[2] }
            if ItemData.DifficultyOpen(d) then r[1] = math.min(r[1], top); r[2] = math.min(r[2], top) end
        end
        -- (FUTURE-PROOF 2026-10-25) each difficulty's "Monster level a-b." text follows the real (capped) range -- Annihilation's said
        -- 200-250 at a 200 cap, where its monsters stop at 210
        for d, mode in pairs(ItemData.DifficultyModes or {}) do
            local r = ItemData.MONSTER_LEVEL and ItemData.MONSTER_LEVEL[d]
            if type(mode) == "table" and type(mode.Description) == "string" and r then
                mode.Description = string.gsub(mode.Description, "^Monster level %d+%-%d+", string.format("Monster level %d-%d", r[1], r[2]))
            end
        end
    end
    local ascMax = (okA and type(AT) == "table" and AT.MAX_TIER) or 99
    for _, t in pairs(ItemData.Titles or {}) do
        local c = t.Check
        if type(c) == "table" and not t.Retired then
            local closed = (c.Kind == "Level" and (tonumber(c.Need) or 0) > ItemData.MAX_LEVEL)
                or (c.Kind == "AscTrial" and (tonumber(c.Need) or 0) > ascMax)
                or (type(c.Diff) == "string" and not ItemData.DifficultyOpen(c.Diff))
                or (type(c.MinDiff) == "string" and not ItemData.DifficultyOpen(c.MinDiff))
            if closed then t.Retired = true; t.CapHidden = true end
        end
    end
end


-- ==================== LOOT SCARCITY (2026-11-07; owner: "Crafting material and currency is far too easy to come by, alongside drops in
-- general ... Its far too easy to max a weapon out early on ... like POE where its an investment ... Match its drop rates ... we get
-- rares and such too early". Contract + PoE anchors + before / after: docs/LOOT_SCARCITY_2026-11-07.md; tools/sim/econ.py mirrors
-- this table, keep them EQUAL) ====================
-- ONE tune table for how much loot the game pays. Readers: CombatServer GiveKillRewards / GrantMaterials / GiveFloorLoot /
-- ObjectiveReward / EncounterReward, ItemData RarityWindow / UpgradeCapFor / UpgradeStepCost / DismantleYield, Contracts, the daily roll.
-- ON = false -> every reader falls back to the numbers before this pass (A/B in Studio: workspace attr DevScarcityOff = true).
ItemData.LOOT_SCARCITY = {
    ON = true,
    -- ITEMS from kills (PoE's ladder: a magic monster ~7x a normal one, a rare ~15x, a boss ~30x -- at about half PoE's trash rate,
    -- our fodder are quarter-health filler). The difficulty's loot quantity counts as qty ^ QtyExp for items (was qty: 6x at the top).
    QtyExp = 0.5,
    Fodder = 0.035, FodderCap = 0.08, -- (was PacksPilot.ITEM_CHANCE 0.2 x qty, cap 0.6)
    Bot = 0.035, BotCap = 0.12,       -- (a plain pack leader; was 0.06 x qty, cap 0.5)
    MagicPerMod = 0.15,               -- (Magic elite: a mod's item chance x qty; was 0.3)
    RareFirst = 0.65, RareExtra = 0.15, -- (Rare elite: was 1 sure item + 0.3 a mod past 2)
    SuperItems = 2, MajorItems = 2, MiniItems = 1, -- (boss items; was 3 / 2 / 2)
    ChestSecond = 0,                  -- (a floor chest's second item; was 40%)
    ObjectiveItem = 0.5,              -- (a floor objective's item drops this often; was always)
    EncounterItems = 1,               -- (an encounter's items, + 1 on a clean run; was 2 / 3; the Breach keeps paying by kills)
    -- RARITY: Rare and Mythic weights x RareGate on the early tiers (PoE: a Rare in the campaign is an event); no row = 1
    RareGate = { Easy = 0.2, Normal = 0.3, Hard = 0.5 }, -- (Brutal + no gate: the gear model wants a set of Rares by the end of Brutal)
    MythicStep = 170,                 -- (ItemData.RARITY_STEP[3], Rare -> Mythic; was 130 -- fewer drops, so a Mythic stays ~10 h on Torment)
    -- MATERIALS earned in play (CombatServer.GrantMaterials: kills, chests, bosses, objectives, events, caches, map guardians):
    -- x Mats[key], and the difficulty's quantity counts as qty ^ MatQtyExp (was qty). Keys not listed: x1.
    MatQtyExp = 0.5,
    Mats = { Scrap = 0.4, Alloy = 0.18, Prism = 0.3 },
    -- what an item dismantles into (replaces ItemData.DismantleYield for these rarities)
    Salvage = { Common = { Scrap = 1 }, Uncommon = { Scrap = 2 }, Rare = { Scrap = 3, Alloy = 1 }, Mythic = { Scrap = 6, Alloy = 2, Prism = 3 },
        Relic = { Scrap = 6, Alloy = 2, Prism = 3 } },
    DailyPrism = 4,                   -- (the free daily roll's Prism base, x (1 + level / 25); was 10)
    -- ENCOUNTER currencies (Turncoat / Rivet / Scrape / Hone: PoE's Exalt / Annul-tier jobs): paid EncounterCurChance of the time,
    -- a clean run (or a Breach with 16+ kills) adds one more EncounterCurClean of the time (was always 1, clean 2, Breach 1-3)
    EncounterCurChance = 0.6, EncounterCurClean = 0.35,
    -- UPGRADES: the cap follows ITEM LEVEL (power-curve rule: ceilings by level) -- min(rarity cap, Base + floor(ilvl / Per)):
    -- +2 at ilvl 1-9, +5 at 30, +7 at 50, +12 at 100, +20 at 180. UpgradeK = x on a step's material (Scrap / Alloy / Prism)
    UpgradeIlvl = { Base = 2, Per = 10 },
    UpgradeK = { Scrap = 1, Alloy = 1.6, Prism = 2.0 },
    ContractItem2 = "Uncommon",       -- (the tier-2 daily contract's item; was "Rare". Tier 3 keeps its Rare)
}
-- is the table live? (Studio A/B: workspace attr DevScarcityOff)
function ItemData.Scarce(): boolean
    local LS = ItemData.LOOT_SCARCITY
    if not LS or LS.ON == false then return false end
    local ok, off = pcall(function() return workspace:GetAttribute("DevScarcityOff") end)
    return not (ok and off == true)
end
-- the upgrade cap of this weapon (rarity cap, then the item-level gate) -> cap, the next item level that raises it (or nil)
function ItemData.UpgradeCapFor(w: any): (number, number?)
    local rc = ItemData.UpgradeCap[w and w.Rarity or ""] or 5
    if not ItemData.Scarce() then return rc, nil end
    local g = ItemData.LOOT_SCARCITY.UpgradeIlvl
    local ilvl = math.max(1, math.floor(w and w.ItemLevel or 1))
    local c = math.min(rc, g.Base + ilvl // g.Per)
    local nextIlvl = (c < rc) and ((c + 1 - g.Base) * g.Per) or nil
    return c, nextIlvl
end
-- the rarity ladder's Mythic step + the dismantle table follow the table (RARITY_BASE is read at roll time)
do
    local LS = ItemData.LOOT_SCARCITY
    ItemData.RARITY_STEP_BEFORE = table.clone(ItemData.RARITY_STEP)
    ItemData.DISMANTLE_BEFORE = {}
    ItemData.RARITY_BASE_BEFORE = table.clone(ItemData.RARITY_BASE)
    if LS.ON then
        ItemData.RARITY_STEP[3] = LS.MythicStep
        ItemData.RARITY_BASE[1] = 1
        for i, st in ipairs(ItemData.RARITY_STEP) do ItemData.RARITY_BASE[i + 1] = ItemData.RARITY_BASE[i] / st end
        for r, y in pairs(LS.Salvage) do
            ItemData.DISMANTLE_BEFORE[r] = ItemData.DismantleYield[r]
            ItemData.DismantleYield[r] = y
        end
    end
end

return ItemData
