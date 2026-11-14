--!nocheck
-- ============================================================================================
-- CREDITS (UPDATE 4 wrap-up, required before publishing): every outside model, sky, texture and sound in Aimbound, with
-- its author, licence and source. Shown in the CREDITS window (WelcomeGuide: hub corner button + guide button, and
-- Settings > Interface > Credits). Data only (a leaf module).
-- LICENCE RULES this follows:
--   CC BY 4.0 (creativecommons.org/licenses/by/4.0): name the creator, the title, a link to the source, the licence + its
--   link, and SAY THAT IT WAS CHANGED; no hint that the creator endorses the game. Every CC BY group carries `Changed`
--   (what we did to all of them) and items a `Note` for anything extra.
--   CC0 / public domain (Poly Haven, ambientCG, Freesound CC0, NASA): no credit required -- credited with thanks.
-- ADDING AN ASSET: a CC BY model / sound / image goes into its group here (or a new group) in the same push that brings it
-- into the game. Source lists: docs/CREDITS_*.md. Links are text (Roblox can't open web links).
-- ============================================================================================
local Credits = {}

Credits.Intro = "Aimbound is built on our own designs plus work shared by these artists. Thank you!"

Credits.Licences = {
    CCBY = { Short = "CC BY 4.0", Name = "Creative Commons Attribution 4.0", Link = "creativecommons.org/licenses/by/4.0" },
    CC0 = { Short = "CC0", Name = "Creative Commons Zero (public domain)", Link = "creativecommons.org/publicdomain/zero/1.0" },
    PD = { Short = "PUBLIC DOMAIN", Name = "Public domain (NASA imagery)", Link = "nasa.gov/nasa-brand-center/images-and-media" },
    APM = { Short = "LICENSED", Name = "Roblox licensed music library, courtesy of APM Music", Link = "create.roblox.com/store/audio" },
    DISTROKID = { Short = "LICENSED", Name = "Roblox licensed music library (artist release via DistroKid)", Link = "create.roblox.com/store/audio" },
}
Credits.NoEndorse = "Used under the licence above. The artists do not endorse Aimbound."

Credits.Groups = {
    {
        Id = "Guns", Title = "GUNS", Licence = "CCBY",
        Head = "Gun models (Sketchfab)",
        Changed = "Changed for Aimbound: split into moving parts, cleaned up, resized and repainted in the game's art style.",
        Items = {
            { Use = "AK-47", Title = "LEAVE A LIKE | AK47 (GAME READY) FREE", Author = "ikagogava", Link = "sketchfab.com/3d-models/570cf6479fe840bab064d87267b05363" },
            { Use = "M249", Title = "M249", Author = "ArtDmitriyK", Link = "sketchfab.com/3d-models/b1e60faa37de4461822103fe38e5c9ce", Note = "Scope, carry handle and bipod removed." },
            { Use = "PKM", Title = "PKM Machine Gun", Author = "futureoverhope", Link = "sketchfab.com/3d-models/79bc67a78b434e65950f0257fe5f09a5", Note = "Bipod removed." },
            { Use = "M60", Title = "M60 Light Machine Gun", Author = "Badboy17Aiden", Link = "sketchfab.com/3d-models/cbf408387dc94a30abe11afb3698ac13", Note = "Bipod removed." },
            { Use = "21E", Title = "HK21E", Author = "notcplkerry", Link = "sketchfab.com/3d-models/ec3211a736344f748616cbd1b8d054fc", Note = "Bipod and loose belt rounds removed." },
            { Use = "M4A1", Title = "M4A1 Carbine", Author = "MrM0lten", Link = "sketchfab.com/3d-models/9bb8f18ad94d4b468e447a2d43bd08b9", Note = "Loose round removed." },
            { Use = "416", Title = "AR-15 M4 M16 HK416 Rifle Project", Author = "Socksthecat", Link = "sketchfab.com/3d-models/db5e293a11114626be2d4f45f1d94664", Note = "Loose rounds removed." },
            { Use = "SCAR-L", Title = "SCAR L", Author = "DelthorGames", Link = "sketchfab.com/3d-models/48141819356643559761da09dd9e7841" },
            { Use = "AUG", Title = "Steyr AUG A3", Author = "mobzver3d", Link = "sketchfab.com/3d-models/62ca412c88a64c0287774496b7f351fc", Note = "Scope and foregrip removed." },
            { Use = "FAMAS", Title = "FAMAS", Author = "Frostoise", Link = "sketchfab.com/3d-models/7d35e14ad8874d148ce9cc46e5765a6b" },
            { Use = "Galil", Title = "Freeform IMI Galil", Author = "dariiiii", Link = "sketchfab.com/3d-models/42f1f3efa63a42efa2838eed495d8c43" },
            { Use = "TAR-21", Title = "TAR - 21 (Tavor). Black and White.", Author = "nik_vega", Link = "sketchfab.com/3d-models/40dc15941e0b456692c83a97bfcd2474", Note = "Spare parts, optic, suppressor and grip removed." },
            { Use = "MP5", Title = "HK MP5 SMG", Author = "dani-zzz", Link = "sketchfab.com/3d-models/fad0226e1dcf4af180f707a5509d3a4e" },
            { Use = "Uzi", Title = "UZI", Author = "Gintoki1234", Link = "sketchfab.com/3d-models/6d997976cf5845b48c6e8b7495b3551b", Note = "Loose rounds removed." },
            { Use = "P90", Title = "FN P90 - LowPoly model", Author = "selfishly_gray", Link = "sketchfab.com/3d-models/af2274dbed31422eb7142d354424bcba", Note = "Spare magazines removed." },
            { Use = "MP7", Title = "MP7 Submachine Gun", Author = "NotNathanModel", Link = "sketchfab.com/3d-models/8db3d7ead18349049255e6c1dba90396" },
            { Use = "Vector", Title = "KRISS VECTOR", Author = "carolineblueeyes", Link = "sketchfab.com/3d-models/3916980e5d564fc9bb1971c9d496bdd5" },
            { Use = "TEC-9", Title = "Tec-9", Author = "neyr", Link = "sketchfab.com/3d-models/4150563248d94261acc3217c5158193b" },
            { Use = "MP40", Title = "MP 40 - WW2 Submachine Gun", Author = "Moony_State", Link = "sketchfab.com/3d-models/7ec7e1f9656e4319b8edae0d785699ad" },
            { Use = "PPSh-41", Title = "PPSh-41", Author = "Artem.Goyko", Link = "sketchfab.com/3d-models/089bdfb09ada407da3e75cfcbe2180fe", Note = "Drum turned to face the barrel." },
            { Use = "870", Title = "Remington 870 Shotgun", Author = "milinam2002", Link = "sketchfab.com/3d-models/6db0ad4764d14eee8f063eea3600071b" },
            { Use = "590 Pump", Title = "Mossberg 590 Mariner", Author = "haoliu95", Link = "sketchfab.com/3d-models/dc5b2d69587344229b60b1a7dbe07a81" },
            { Use = "KS7", Title = "Kel-Tec KS7", Author = "3D-Models-Geek", Link = "sketchfab.com/3d-models/3c5981de236446f09c40e717236d9b87", Note = "Loose shell removed." },
            { Use = "M4 Super 90", Title = "Benelli M4", Author = "bensloane", Link = "sketchfab.com/3d-models/4bf675e04af949238666d8d2688f49c9", Note = "Levelled." },
            { Use = "AA-12", Title = "low-poly AA-12", Author = "DU1701", Link = "sketchfab.com/3d-models/6b26f9d65d8c4838a12918d8e232510a", Note = "House-style repaint, drum and shells removed." },
            { Use = "Komrad 12", Title = "KOMRAD 12 SAIGA 12", Author = "dsamuta", Link = "sketchfab.com/3d-models/2bd3f94f5ba34188a7dfb02fe45445c1", Note = "Flashlight, foregrip and red dot removed." },
            { Use = "Double Barrel", Title = "12 Gauge Double Barrel Shotgun [Custom]", Author = "SchrisArt", Link = "sketchfab.com/3d-models/1e03c51ebc454aeba36ba1c575cff067" },
            { Use = "G19", Title = "Glock Gun 3d Model Free Download", Author = "thronetools", Link = "sketchfab.com/3d-models/d1f6b5d6902d4a7fb735881d3ece250a", Note = "Slide cut out, a magazine added inside the grip." },
            { Use = "Desert Eagle", Title = "Desert Eagle", Author = "Minte_Elseviers", Link = "sketchfab.com/3d-models/334462df58b942759122567fa0b81113", Note = "Loose round removed." },
            { Use = "Rhino", Title = "Chiappa Rhino 60DS", Author = "Sasima", Link = "sketchfab.com/3d-models/c652d5885a7042b28cb6dc8d763d7db8" },
            { Use = "USP", Title = "Heckler & Koch USP Pistol", Author = "Urpo", Link = "sketchfab.com/3d-models/972e3643000246e8959a6df509557bcc" },
            { Use = "P226", Title = "Sig Sauer P226", Author = "Alexcanot", Link = "sketchfab.com/3d-models/e3d4f1ab22f342f4a0891743353c114c" },
            { Use = "P99", Title = "Walther P99", Author = "Hideo_Godzila", Link = "sketchfab.com/3d-models/d9f25cbe04f54e94aa9d2e8c14ec4b62" },
            { Use = "PX4 Storm", Title = "Beretta Px4 Storm Sub-Compact", Author = "dan741vlasov", Link = "sketchfab.com/3d-models/55958f5ee3674f5fbb1a5cb93ca84e44" },
            { Use = "AWM", Title = "AWM Sniper Rifle", Author = "ParaBellis69", Link = "sketchfab.com/3d-models/b7d187569cfd4a8fbb9fe10e76737dd8", Note = "Loose rounds removed." },
            { Use = "M82", Title = "Barrett M82 Baked/Textured", Author = "ShariffButler726", Link = "sketchfab.com/3d-models/416849efe5cb454a8e538188d5a300d1", Note = "Bipod removed." },
            { Use = "Hunting Rifle", Title = "Hunting Rifle", Author = "Tnkii", Link = "sketchfab.com/3d-models/5df7cc598b134b1cb19d41669df05c4b" },
            { Use = "SVD", Title = "SVD Dragunov", Author = "Sergei3D", Link = "sketchfab.com/3d-models/7e5c38ec11b54b08b14e49843ad04ed5" },
            { Use = "SKS", Title = "SKS", Author = "jeandiz", Link = "sketchfab.com/3d-models/ea48b79acd354e4d8aa5ac901218ae5e" },
            { Use = "M40", Title = "M40A1 Sniper Rifle", Author = "JebusModels", Link = "sketchfab.com/3d-models/11444b92b7184acf8dfce16b8dc9af66", Note = "Loose cartridge removed." },
            { Use = "M14", Title = "M14 | High Poly | PBR | FBX", Author = "steingames", Link = "sketchfab.com/3d-models/d5d0198fef4843c392d280837f74ad66" },
            { Use = "M110", Title = "M150 Sniper Rifle (Game Ready)", Author = "Bl4ckGh0st", Link = "sketchfab.com/3d-models/0f71498f1f694b30be77c9779361c6cc", Note = "An M110-style design. Vertical grip and lens caps removed." },
        },
    },
    {
        Id = "Beams", Title = "BEAM GUNS", Licence = "CCBY",
        Head = "Beam gun models (Sketchfab)",
        Changed = "Changed for Aimbound: rebuilt as energy weapons (split into parts, copper wiring, a glowing energy core and cell), resized and repainted in the game's art style.",
        Items = {
            { Use = "Hyperion", Title = "Sniper Railgun", Author = "Theo_Nelson", Link = "sketchfab.com/3d-models/a8b237fe17cc456880b2b47a7eb6cff5", Note = "Scope removed." },
            { Use = "Spark Pistol", Title = "Plasma Pistol 01", Author = "Jeremie.Kull", Link = "sketchfab.com/3d-models/17ad313abbac4d54a643ed820be7fcf3" },
            { Use = "Ion Accelerator", Title = "HMG-379", Author = "Frostoise", Link = "sketchfab.com/3d-models/533204d3a9f240f78b65973b323cba7c" },
            { Use = "Quadbeam", Title = "RL0N-25", Author = "Frostoise", Link = "sketchfab.com/3d-models/c54ce41b7b854834a13ef1ed42aed6ba" },
            { Use = "Arc Projector", Title = "SMG-1311", Author = "Frostoise", Link = "sketchfab.com/3d-models/a3500d22c2a842dfbc275df88835afec" },
            { Use = "Helios Beam", Title = "Sci-fi Gauss Rifle", Author = "Igor.Jop", Link = "sketchfab.com/3d-models/2796208530b24e34b9c631ce8c770e9d", Note = "Top armour opened to show the coil, a capacitor coil added." },
            { Use = "Void Rifle", Title = "AR-H470", Author = "Frostoise", Link = "sketchfab.com/3d-models/4b38c160243743d681d6fdaf3bd77ddb" },
        },
    },
    {
        Id = "World", Title = "WORLD", Licence = "CCBY",
        Head = "Props in the biomes (Sketchfab)",
        Changed = "Changed for Aimbound: simplified, re-centred, resized and retinted to each biome's colours.",
        Items = {
            { Use = "Neon Flats: the rusted cars", Title = "Abandoned Generic Sedan 2 - Game Ready", Author = "rashad-brahimli", Link = "sketchfab.com/3d-models/db2df46c49f9441286c84c66208ef7ac" },
            { Use = "Cyber: the cases and crates", Title = "Modular Sci- Fi Crate", Author = "ForkyForklift", Link = "sketchfab.com/3d-models/d796d8e4e5f54c52a99cccced0dfe68c" },
            { Use = "Cyber: the power canisters", Title = "Sci-Fi Barrel", Author = "a_l_e_x_a_n_d_e_r", Link = "sketchfab.com/3d-models/b6208062ec76461d8ffd24e5944175db" },
        },
        -- (CC0, with thanks)
        Thanks = {
            { Head = "Scanned props (Poly Haven, polyhaven.com, CC0)", Text = "Electricity poles, utility boxes, the security light, the void monolith rock face, the scanned rocks, cliffs and logs in the twelve worlds, and the props of the original biomes (fort walls, fire pit, scoria, basalt and more)." },
            { Head = "Our own", Text = "The other world props, hideout pieces, enemies, bosses, skins, the walled city and its signs are made for Aimbound." },
        },
    },
    {
        Id = "Skies", Title = "SKIES", Licence = "CC0",
        Head = "Sky photographs (Poly Haven HDRIs, polyhaven.com)",
        Changed = "Painted over for each biome with its own light, clouds, moons and effects.",
        Items = {
            { Use = "Molten", Title = "Industrial Sunset (Pure Sky)", Author = "Jarod Guest, Sergej Majboroda", Link = "polyhaven.com/a/industrial_sunset_puresky" },
            { Use = "Cryo", Title = "Kloofendal 38d Partly Cloudy (Pure Sky)", Author = "Greg Zaal, Jarod Guest", Link = "polyhaven.com/a/kloofendal_38d_partly_cloudy_puresky" },
            { Use = "The night skies", Title = "Rogland Clear Night", Author = "Greg Zaal", Link = "polyhaven.com/a/rogland_clear_night", Note = "Void, Derelict Station, Dreamscape, Moonlit Spires, Haunted Bayou." },
            { Use = "Cyber, the walled city (the hub)", Title = "Kloppenheim 07 (Pure Sky)", Author = "Greg Zaal, Jarod Guest", Link = "polyhaven.com/a/kloppenheim_07_puresky" },
            { Use = "Stormspire", Title = "Farm Field (Pure Sky)", Author = "Dimitrios Savva, Jarod Guest", Link = "polyhaven.com/a/farm_field_puresky" },
            { Use = "Neon Flats", Title = "Evening Road 01 (Pure Sky)", Author = "Jarod Guest, Sergej Majboroda", Link = "polyhaven.com/a/evening_road_01_puresky" },
            { Use = "Sunken Temple", Title = "Table Mountain 1 (Pure Sky)", Author = "Greg Zaal, Jarod Guest", Link = "polyhaven.com/a/table_mountain_1_puresky" },
            { Use = "Sun Empire", Title = "Sunflowers (Pure Sky)", Author = "Jarod Guest, Sergej Majboroda", Link = "polyhaven.com/a/sunflowers_puresky" },
            { Use = "Brass Skyport + The Deep", Title = "Kloofendal 48d Partly Cloudy (Pure Sky)", Author = "Greg Zaal, Jarod Guest", Link = "polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky", Note = "Also the Deep Aquarium and Forest Cabin hideouts." },
            { Use = "Toxic Wastes", Title = "Wasteland Clouds (Pure Sky)", Author = "Jarod Guest, Sergej Majboroda", Link = "polyhaven.com/a/wasteland_clouds_puresky" },
            { Use = "Autumn Highlands", Title = "Citrus Orchard (Pure Sky)", Author = "Dimitrios Savva, Jarod Guest", Link = "polyhaven.com/a/citrus_orchard_puresky" },
            { Use = "Sakura Shrine", Title = "Belfast Sunset (Pure Sky)", Author = "Greg Zaal, Dimitrios Savva, Jarod Guest", Link = "polyhaven.com/a/belfast_sunset_puresky" },
            { Use = "Sun Dunes", Title = "Syferfontein 6d Clear (Pure Sky)", Author = "Greg Zaal, Jarod Guest", Link = "polyhaven.com/a/syferfontein_6d_clear_puresky" },
            { Use = "Spore World", Title = "Scythian Tombs (Pure Sky)", Author = "Jarod Guest, Sergej Majboroda", Link = "polyhaven.com/a/scythian_tombs_puresky" },
            { Use = "Duel arenas", Title = "Qwantani Dusk 2 (Pure Sky)", Author = "Greg Zaal, Jarod Guest", Link = "polyhaven.com/a/qwantani_dusk_2_puresky" },
        },
        Thanks = {
            { Head = "The Moon and the Earth (NASA, public domain)", Text = "Moon: LRO / LROC CGI Moon Kit, NASA's Scientific Visualization Studio (svs.gsfc.nasa.gov/4720). Earth: Blue Marble, NASA Visible Earth / Goddard Space Flight Center." },
        },
    },
    {
        Id = "More", Title = "TEXTURES + SOUNDS", Licence = "CC0",
        Head = "Surfaces and sounds",
        Changed = "Neutralised so each biome can colour them, tiled, cut and mixed for Aimbound.",
        Items = {},
        Thanks = {
            { Head = "Textures (Poly Haven, polyhaven.com + ambientCG, ambientcg.com, CC0)", Text = "Every ground, rock, sand, snow, ice, brick, concrete, wood, metal, fabric and lava surface in the game is a real scan from these two libraries." },
            { Head = "Sounds (Freesound, freesound.org, CC0)", Text = "The gunshots, reloads and skin sounds start from real CC0 recordings shared on Freesound." },
        },
    },
    {
        Id = "Music", Title = "MUSIC", Licence = "APM",
        Head = "City, run and hideout music",
        Changed = "Played as recorded, each set to one quiet level under the game sounds.",
        Items = { -- (HUB MUSIC v3 2026-10-24: keep in step with AimRngShared/HubMusic.TRACKS; runs play the same tracks since 2026-10-25)
            { Use = "City + run music", Title = "You and I", Author = "Juice Music", Link = "Juice Music • Drum n Bass" },
            { Use = "City + run music", Title = "Easy Roller", Author = "Juice Music", Link = "Juice Music • Drum n Bass" },
            { Use = "City + run music", Title = "Walking in the Sun", Author = "Juice Music", Link = "Juice Music • Drum n Bass" },
            { Use = "City + run music", Title = "All Right", Author = "KPM Main Series", Link = "KPM Main Series" },
            { Use = "City + run music", Title = "Star Stream", Author = "Kamil Dominik Mazurek", Link = "DNB N Chill" },
            { Use = "City + run music", Title = "With You (Underscore)", Author = "Kamil Dominik Mazurek", Link = "DNB N Chill" },
            { Use = "City + run music", Title = "Right By Your Side (Underscore)", Author = "Kamil Dominik Mazurek", Link = "DNB N Chill" },
            { Use = "City + run music", Title = "Ghostrace", Author = "Justement Music", Link = "Justement Music" },
            -- (JUKEBOX v2 2026-10-24: keep in step with AimRngShared/HideoutData.MUSIC)
            { Use = "Hideout jukebox: Late Night Lo-fi", Title = "Moving Round The Block", Author = "Afro Dizzy", Link = "Afro Dizzy • Lofi Hip Hop" },
            { Use = "Hideout jukebox: Late Night Lo-fi", Title = "Light Dreamer", Author = "Afro Dizzy", Link = "Afro Dizzy • Lofi Hip Hop" },
            { Use = "Hideout jukebox: Late Night Lo-fi", Title = "Sunday In Bed", Author = "Afro Dizzy", Link = "Afro Dizzy • Lofi Hip Hop" },
            { Use = "Hideout jukebox: Late Night Lo-fi", Title = "Calming Lo-Fi (Underscore)", Author = "Invasion From Mars", Link = "Invasion From Mars • ChillHop Lo-Fi" },
            { Use = "Hideout jukebox: Calm Drift", Title = "Watercolours (b)", Author = "Juice Music", Link = "Juice Music • Neutral Atmospheres" },
            { Use = "Hideout jukebox: Calm Drift", Title = "Calm Space (b)", Author = "Juice Music", Link = "Juice Music • Neutral Atmospheres" },
            { Use = "Hideout jukebox: Calm Drift", Title = "Oceanic (b)", Author = "Juice Music", Link = "Juice Music • Neutral Atmospheres" },
            { Use = "Hideout jukebox: Calm Drift", Title = "Essential (b)", Author = "Juice Music", Link = "Juice Music • Neutral Atmospheres" },
            { Use = "Hideout jukebox: Open Plains", Title = "Epic Landscape (Underscore)", Author = "Bruton", Link = "Bruton TV Series • Panoramic Orchestral 3" },
            { Use = "Hideout jukebox: Open Plains", Title = "Summer Day (Underscore)", Author = "Bruton", Link = "Bruton TV Series • Panoramic Orchestral 3" },
            { Use = "Hideout jukebox: Open Plains", Title = "Autumn Mornings (Underscore)", Author = "Bruton", Link = "Bruton TV Series • Panoramic Orchestral 3" },
            { Use = "Hideout jukebox: Open Plains", Title = "Snow Field (Underscore)", Author = "Bruton", Link = "Bruton TV Series • Panoramic Orchestral 3" },
            { Use = "Hideout jukebox: Night Drive", Title = "Into The Night (Underscore)", Author = "B Kully", Link = "APM Music" },
            { Use = "Hideout jukebox: Night Drive", Title = "Cybernetic (Underscore)", Author = "B Kully", Link = "APM Music" },
            { Use = "Hideout jukebox: Night Drive", Title = "Cyberpunk (b)", Author = "Score Production Music", Link = "Score Production Music • Neon Wave 2" },
            { Use = "Hideout jukebox: Night Drive", Title = "Midnight Runner", Author = "Lemoncake", Link = "Lemoncake • Nocturnal Afterglow" },
        },
    },
    {
        Id = "Earlier", Title = "EARLIER MODELS", Licence = "CCBY",
        Head = "Older models still in the game files",
        Changed = "Kept as backups, not used in play. Changed for Aimbound: split into parts, resized and repainted.",
        Items = {
            { Use = "Combat Knife (the first default melee)", Title = "Combat Knife", Author = "skaf13", Link = "sketchfab.com/3d-models/5b5a9e2e783442f9bfe3bd68eb2f0c66" },
            { Use = "Arc Projector (v4)", Title = "sci-fi assault rifles", Author = "EmanuelRestrepoVelez", Link = "sketchfab.com/3d-models/9b0db12353fc432499ef707bf5fa8208" },
            { Use = "Helios Beam (v4)", Title = "Low poly sci fi Reaper impulse assault rifle", Author = "vympel", Link = "sketchfab.com/3d-models/35faa51cc8e74b489f875e858ab64cc0" },
            { Use = "Ion Accelerator (v4)", Title = "Heavy Assault Rifle", Author = "valerij1987", Link = "sketchfab.com/3d-models/1b91aca44b65417f957d9ec30ce8ee19" },
            { Use = "Quadbeam (v4)", Title = "Assault rifle for Games", Author = "vineet", Link = "sketchfab.com/3d-models/65726f79c83c442489e6603cdf77861c" },
            { Use = "Hyperion (v4)", Title = "Sci-fi rifle M13-Gaus", Author = "irons", Link = "sketchfab.com/3d-models/648847589fec4ecc9b91d7cdcc9c4d84" },
            { Use = "Spark Pistol (v4)", Title = "sci-fi space blaster pistol plasmagun da1", Author = "flawlessnormals", Link = "sketchfab.com/3d-models/01825e8f92e44c8a8a7d720a5755b4c2" },
            { Use = "Void Rifle (v4)", Title = "Cyberpunk-X-Laser-Rifle [1.15]", Author = "XX-XX", Link = "sketchfab.com/3d-models/c8deef19e5cb48bbbdc7f59ab582bf98" },
            { Use = "The first gun models", Title = "Low-poly gun series", Author = "TastyTony", Link = "sketchfab.com/TastyTony" },
            { Use = "The first first-person arms", Title = "First Person arms", Author = "bumstrum", Link = "sketchfab.com/bumstrum" },
        },
    },
}

return Credits
