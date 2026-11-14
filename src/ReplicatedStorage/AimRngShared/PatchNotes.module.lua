--!nocheck
-- Patch notes shown in the hub (the notes button next to the guide button; NEW badge until you've read the latest).
-- Newest FIRST. Bump Id for every update (the badge compares it with the player's saved SeenPatch setting).
-- Keep entries short and in player terms.
-- (CHASE ITEMS 2026-11-06) an entry with Dark = true is left out until ItemData.ZENITH_LIVE is on (ship-dark rule: nothing about the
-- Zenith tier shows while its switch is off; the NEW badge reads the first entry left, so it doesn't light up either).
local NOTES = {
    -- FIXES 2026-11-09 (builders add their lines to this entry's Fixes)
    {
        Id = 130, Version = "0.99z5", Date = "Nov 9, 2026", Title = "SORTED",
        Sections = {
            -- (2026-11-09 builder inv: sockets on tiles + the auto-sell filter)
            { Head = "Sockets at a glance", Lines = {
                "Every gun in your bag, stash, loadout, the Exchange, the Forge and trades now shows its sockets as coloured dots under its picture.",
                "A bar between two dots means they're linked; a gap starts a new group. A white ring means a mod is already in that socket.",
            } },
            { Head = "Auto-sell filter", Lines = {
                "SELL > AUTO-SELL now opens a panel. Pick the rarity to sell at or under, then add KEEP rules that protect drops it would sell.",
                "Keep guns with at least a number of sockets or a big enough link, anything from an item level up, whole gun classes or gear slots, and the stat lines you hunt for (at a tier or better, and how many of them an item needs).",
                "An item that matches any keep rule is kept. The panel shows what your current bag would do with your rules before you save. Relics and Zeniths are never auto-sold.",
                "Guns and gear now go through the same auto-sell check everywhere they drop.",
            } },
            { Head = "Fixes", Lines = {
                "Fixed Kirameki skins leaving their BANG! sign and star stickers floating in the air beside you in the city (and any skin's stickers when your gun is put away).",
            } },
        },
    },
    -- LOOT SCARCITY + WIPE 6 (2026-11-07, builder scarce; docs/LOOT_SCARCITY_2026-11-07.md)
    {
        Id = 129, Version = "0.99z4", Date = "Nov 7, 2026", Title = "EARNED",
        Sections = {
            { Head = "Fresh start: everyone starts over", Lines = {
                "The new loot economy starts everyone fresh: levels, items, gear, mods, maps, gold, currencies and the leaderboards reset, and the Exchange starts empty.",
                "Everything you bought stays: cosmetics, skins and copies, BOUND, colourways, your settings, the bought parts of your hideout (stash tabs come back empty), the season pass and revive credits.",
                "Crews keep their name, tag, members and ranks; the crew bank and research start over.",
            } },
            { Head = "Loot is rarer, on purpose", Lines = {
                "Far fewer items drop: about half of before on Easy, down to a quarter on the harder tiers. Most drops are Common or Uncommon, so the good ones stand out.",
                "Rares are rare early on. On Easy, Normal and Hard a yellow Rare is an event; from Brutal up they come more often, and they're the gear you'll wear.",
                "Mythics are rarer too: expect your first one after many hours on Torment, sooner on harder tiers.",
                "Elites and bosses are still where the better loot is. Loot goblins still pay four Rare-or-better items.",
            } },
            { Head = "Crafting is an investment", Lines = {
                "Scrap, Alloy and Prism Shards drop much less often, and salvaging gives less. Prism Shards from the free daily roll are lower too.",
                "Encounters pay their own currency most of the time, not always, and a fast or clean run has a chance at one more.",
                "Upgrades now follow ITEM LEVEL as well as rarity: up to +2 on a low-level gun, +5 at item level 30, +12 at item level 100, +20 (Mythic) at item level 180. The higher Alloy and Prism steps cost more.",
                "Maxing a weapon is now a long goal, not your first hour. The Forge shows the item level each next step opens at.",
            } },
            { Head = "The Mod Supply", Lines = {
                "A new stall in the city, the MOD SUPPLY (west side, by the Forge), sells plain level-1 mods for Scrap, Alloy and gold. The MODS window has the same SUPPLY tab.",
                "Added Heat, Added Cryo and Added Volt from level 3, Rapid from level 6, the area mods Volley and Pierce from level 12 and Impact from level 16: an area mod for every socket colour, so clearing packs isn't down to luck.",
                "They cost real savings, not pocket change. Chain, Fork, Detonate and the other strong mods still only drop.",
            } },
            { Head = "Nightmare is less crowded", Lines = {
                "Nightmare now has Brutal's enemy numbers: fewer bots in each room and in the big crowd rooms. Torment is the first tier with full crowds.",
                "Each kill on those floors pays a little more XP and gold, so a Nightmare run still pays about the same, in less time.",
            } },
        },
    },
    -- RUN FIXES + EARLY DENSITY (2026-11-07, builder ship). (The dark ZENITH entry below needs an Id above this one when it goes
    -- live, or its NEW badge won't light: the badge compares the first entry's Id.)
    {
        Id = 128, Version = "0.99z3", Date = "Nov 7, 2026", Title = "SOLID GROUND",
        Sections = {
            { Head = "Changes", Lines = {
                "Early tiers are lighter: Normal, Hard, Brutal and Nightmare rooms hold fewer enemies and build up to full packs by Torment, around the time you have area damage. Each kill there pays a little more, so a run's XP and loot stay the same.",
                "Commander elites no longer carry a giant ring in the air: a thin gold band marks the one to shoot first, and a faint ring on the floor shows how far its buff reaches.",
                "Added map bounds to every dungeon floor: if you get outside the map, you're put straight back where you last stood.",
            } },
            { Head = "Fixes", Lines = {
                "Fixed being unable to move after buying a revive.",
                "Fixed the Infrared M4A1's finger marks floating beside the gun in first person.",
            } },
        },
    },
    -- CHASE ITEMS (2026-11-06; contract docs/CHASE_ITEMS_2026-11-06.md). DARK until the owner flips ItemData.ZENITH_LIVE.
    {
        Id = 127, Version = "0.99z2", Date = "Nov 2026", Title = "ZENITH", Dark = true,
        Sections = {
            { Head = "A new tier above Relics", Lines = {
                "ZENITH items: seven named items that change how you play, each with a real catch. They're the rarest things in the game. When one drops, the whole server hears about it.",
                "Every class has its own Zenith gun, and those five only drop from the Summit: a slim chance each kill, three times better on the Summit Unbound.",
                "Saint's Ricochet (P226): weak-spot hits bounce to the next enemy's weak spot, up to 3 times. Half the magazine, slower reloads.",
                "Furnace Heart (M60) never reloads: it builds heat instead and locks for 2.5 seconds if you overheat. Weak-spot hits vent heat.",
                "Long Promise (Hunting Rifle) pierces every enemy in line and hits harder for each one, with a one-round magazine and a slower walk while aiming.",
                "Bloomshot (KS7): kills send their pellets on to nearby enemies, but the spread is wider. Lattice (Tesla Quadbeam): the beam forks to 4 more enemies, but you take more damage while firing.",
                "Two Zeniths are gear any class can wear, and they can drop from any kill (exceedingly rarely, more often on harder difficulties):",
                "Glass Halo (helmet): your weak-spot bonus is tripled and a weak-spot kill gives the round back. Body shots deal half damage.",
                "Unbroken Thread (gloves): every hit in a row adds 4% damage, up to 60%. A miss clears it all, and you take 15% more damage for 2 seconds. The stacks fade after 5 seconds without a hit, and every floor starts at zero.",
            } },
            { Head = "Twin Glass", Lines = {
                "A new currency that makes an exact copy of a weapon or gear piece at the Forge. Both copies become TWINNED: they can't be crafted or twinned again. The copy comes out locked, so it can't be sold by accident.",
                "It is the rarest drop in the game: any kill, almost never. Most players will trade for one.",
            } },
            { Head = "Where it shows", Lines = {
                "Zeniths can be traded, listed on the Exchange (new ZENITH filter), stashed and locked. The Index has a ZENITH section.",
                "Selling or dismantling a Zenith always asks first, and bulk selling never touches one. A Zenith in Lost Loot never falls off the list.",
                "A Zenith drops at your own level, not the area's.",
            } },
        },
    },
    -- LIVE HOTFIX (2026-11-06, owner on the live game: a floor stuck at "6 left" after every enemy was dead)
    {
        Id = 126, Version = "0.99z1", Date = "Nov 6, 2026", Title = "HOTFIX",
        Sections = {
            { Head = "Fixes", Lines = {
                "A floor could get stuck saying enemies were left after you had killed them all, with no way on. Kills now always count, and a floor whose count goes wrong fixes itself within a couple of seconds.",
            } },
        },
    },
    -- MAP PACING (2026-10-31; contract docs/MAPS_PACING_2026-10-31.md). Version is a guess -- main's call.
    {
        Id = 125, Version = "0.99z", Date = "Oct 31, 2026", Title = "RISK, NOT A SLOG",
        Sections = {
            { Head = "Rare maps are dangerous, not slow", Lines = {
                "A Rare map used to take about twice as long as a Plain map of the same tier. Now it takes only a little longer, and its extra loot comes from DANGER: harder hits, extra elements, your defences squeezed.",
                "A map's rarity no longer makes its enemies tougher. Charged and Rare maps still drop higher item levels.",
                "Mods that make enemies slower to kill (tougher, harder to hit, more of them) now share one limit on each map, so a map never piles them up. Its other mods are danger mods.",
                "Weaker on maps, and they pay a little less to match: the enemy resistance mods (Plated, Heatproof, Frostproof, Insulated, Voidproof: +12% to +19%), Swarming and Teeming (+10% to +16%), Aim High (body shots -15% to -24%), Keep Your Distance (-30% to -48%), Empowered Guardian (+30% to +48%).",
                "Enemy health mods have their own slot: about 4 in 10 Rare maps roll one, on top of the shared limit. Fortified gives enemies +20% health on tier 1 up to +32% on tier 12 (never the guardian: Empowered Guardian is its health mod), Warded +15% to +24%. Only one of the two per map.",
                "Steel Skin on maps: your crits still land, but their extra damage is cut (30% on tier 1, 48% on tier 12). It used to switch crits off completely.",
                "Maps you already hold keep their mods, with the new numbers. The map card shows them.",
            } },
            { Head = "Fixes", Lines = {
                "Warded, Mending and Regenerating enemies kept healing while you were shooting them. Now they only heal after a few seconds without being hit, as their text says. Regenerating elites die faster everywhere because of this.",
                "Damage numbers no longer show a decimal on big hits (27520.1 is now 27520).",
                "Loot pickup lines no longer sit on top of an open window, and the UNLOCKED / maps cards wait until an Aim Trial is over.",
                "Text that was cut off: the class cards (Marksman), the hideout's MAP ROOM card, and on phones the map device's bot skill line and the Season pass's tier 50 card.",
                "The card you see when you walk up to loot has the new clean look, and it no longer covers the room line at the top of the screen.",
                "With a window open, messages like \"+4 Prism Shard\" now show along the bottom of the screen instead of over the window's top bar or the RUN AGAIN button.",
                "The hideout's Armory Workshop is now called the Forge Workshop, since it opens the Forge. Its sign says FORGE too. If you already own one, it stays where it is.",
                "Enemies barely moved and packs stood in one big clump. Now gunners and heavies keep moving from spot to spot and only stop for a moment to fire, a pack spreads out across your view and at different distances, and an enemy that walks into cover finds a way round within about a second.",
            } },
        },
    },
    -- BOT MOVEMENT POE (2026-10-30; contract docs/BOT_MOVEMENT_2026-10-30.md). Version is a guess -- main's call.
    {
        Id = 124, Version = "0.99y", Date = "Oct 30, 2026", Title = "HOLD THE LINE",
        Sections = {
            { Head = "Enemies move with a purpose", Lines = {
                "The common enemies and the Molten roster no longer strafe side to side all the time. Each one moves like its role, on its own timing, so a pack never moves as one wall.",
                "RUSHERS close in, stop at arm's length or their charge distance, and strike. After a strike they hop to a new angle. After a dive they stand winded for a moment: a free shot.",
                "GUNNERS keep their distance and keep moving from spot to spot with smooth, long moves. MARKSMEN hang back and move after they fire. HEAVIES plod forward. CASTERS hide behind their allies.",
                "These reworked enemies STOP to fire: a gunner slows to a halt just before its volley, a marksman stands still through its whole charge. That is your window for the big hits and weak-spot shots.",
                "A few enemies are fast and fragile: Skirmishers, Zippers and Comets move quicker but go down in a few hits. Kill them first.",
                "The other biomes' own enemies keep their old movement for now, but they follow the new speed rules below.",
            } },
            { Head = "Higher tiers are tougher, not faster", Lines = {
                "Enemy movement speed now stops growing at Torment. Higher tiers and maps make enemies tougher and deadlier instead.",
                "No enemy can move across your screen faster than a readable limit, whatever the tier, map modifiers or bot skill. Frenzied and Relentless maps still make enemies faster, up to that limit.",
                "Maps no longer roll a random bot skill of 6 to 10. Every map plays at Standard bot skill and pays the same rewards as the old average. Want more? Pick a higher bot skill on the map device: faster enemies, more XP, gold and loot.",
                "Bosses and map guardians fight the same as before (a higher bot skill on the device still speeds a guardian up). Enemies that fight beside a boss keep their own movement but follow the new speed rules.",
            } },
        },
    },
    -- ENEMY ATTACKS PILOT (2026-10-30; contract docs/ENEMY_ATTACKS_2026-10-30.md). Version is a guess -- main's call.
    {
        Id = 123, Version = "0.99x", Date = "Oct 30, 2026", Title = "READ THE ENEMY",
        Sections = {
            { Head = "Every enemy fights its own way", Lines = {
                "Most enemy attacks used to be a red shape on the floor under you. Now the common enemies (every biome) and the Molten roster each have a ROLE, and each role asks something different of you.",
                "GUNNERS (Tracker, Runner, Strafer, Hopper and most flyers) fire a quick volley of glowing tracer rounds in a small fan. It is too fast to sidestep, and on higher tiers it aims where you are heading. About one round of a volley lands whether you move or not: cover, range and killing them first are the answer, and your Plating, resistances and Health decide how much it hurts.",
                "MARKSMEN (Sniper, Blinker, Ashwing) charge one hard shot every other attack (quick volleys in between). A glint grows on the head, then turns steady as it locks. Hit the head while it charges and the shot is cancelled and the enemy staggers. Too late? Move when it locks.",
                "HEAVIES (Drifter, Gunship, Magmaw) lob a slow shell every other attack and mark where it lands. Step off the mark, or SHOOT THE SHELL DOWN in the air. The Juggernaut still slams the floor.",
                "RUSHERS (Brute, Charger, Slagroller) glow on their body as they wind up, then swing or dive through you. Once one is on you it also jabs fast: back off or kill it first.",
                "CASTERS (Warden, Smelter, Medic) protect the others: a Warden or Smelter wards an ally (a bubble and a tether, half damage) until the caster dies. The ground around a caster hurts while it fights. Kill them first.",
                "Round colours show their damage type. Pack fodder fire single rounds, and only a few rounds can fly at you at once, however big the room.",
                "How often enemies attack is unchanged. Bosses, minibosses, trials and map guardians are unchanged. The other biomes' own enemies keep their old attacks for now.",
            } },
            { Head = "Moving cuts damage, it never removes it", Lines = {
                "Enemies now deal two kinds of damage. CHIP is the steady part: tracer volleys, rusher jabs, harmful ground round casters, an elite's burst when it dies. You can't dodge all of it, so it is your PLATING (best against small Kinetic hits), RESISTANCES (Heat / Cryo / Volt / Void hits) and HEALTH that keep you standing.",
                "SPIKES are rare, big and clearly told: the marksman's charged shot, the heavy's shell, the rusher's swing or dive. Dodge those. When one catches you, your Health decides whether you live.",
                "AGILITY makes attacks miss you (rounds, shells, jabs, swings, dives). It does not help against harmful ground or death bursts.",
                "Small chip no longer spoils a no-hit floor or your Focus: only a HEAVY hit counts for Untouchable, no-hit contracts and goals, and breaking your Focus. Any damage still pauses your Ward's recharge.",
                "Elites of the reworked enemies (the common enemies and the Molten roster; not Volatile ones) leave a short burst where they die: a disc on the floor for a moment, then it goes off. Several bursts at once never hit you for more than one. Step out, or have the defences to shrug it off.",
                "Higher tiers are faster: rounds and shells arrive sooner, the marksman's lock is shorter and gunners read your movement more. On the top tiers your defences matter far more than your feet. Enemy wind-ups stay the same length on every tier.",
            } },
            { Head = "New elite modifiers", Lines = {
                "SHELLED (Iron / Ember / Frost / Storm / Void-shelled): a shell soaks 40% of its health first. The matching damage type breaks it 2.5x as fast, others 0.75x. Breaking it staggers the elite. The shell's bar sits under its health bar.",
                "AVENGING: when an enemy near it dies, it and the enemies around it attack 15% more often for 6 seconds (stacks 3 times). Kill it first.",
                "SKITTISH: blinks a few studs aside when you hit it (at most every 5 seconds). Follow the blink.",
            } },
        },
    },
    -- MAPS V2 (2026-10-30; contract docs/MAPS_V2_2026-10-30.md). The LOOP builder owns this entry; MODS / BOSS append their own
    -- sections below. Version is a guess -- main's call.
    {
        Id = 122, Version = "0.99w", Date = "Oct 30, 2026", Title = "MAPS V2",
        Sections = {
            { Head = "Maps drop from maps", Lines = {
                "A finished map no longer hands you the next one. Maps now DROP inside maps: the guardian drops one most of the time, and Charged and Rare elites and the floor caches sometimes do too.",
                "Beat the timer and the guardian's map often climbs a tier or two. Over time, it drops less often and never climbs.",
                "Map drops land around the tier you ran: sometimes one lower, usually the same, sometimes higher. Rare maps with more mods (more item quantity) make elites and caches drop maps more often.",
                "Dying still loses the map, but every map you already found on it is yours.",
                "Bosses outside maps still drop the first tier of their band (level 100+), and the City Quarters stall still sells maps, so you are never stuck.",
                "Map tree: Cartography's nodes now raise the chance for maps to drop inside maps. Surveyor's Gamble makes the guardian always drop a map when you beat the timer (no drop more than one tier up). Race the Clock gives an 80% chance of a second guardian map. Collector's drops never climb.",
            } },
            { Head = "Completion", Lines = {
                "Every map type (each biome and each Storied map) beaten IN TIME on each band (Ruin, Dread, Apocalypse, Annihilation) is a COMPLETION. Every 2 completions give a map point.",
                "Open COMPLETION at the map device to see what's done and what's missing. CHART a map (new biome) to chase a missing one.",
                "Map points now come from your best tier beaten in time, completions and maps finished (a point every 20, up to 10). Like before, you can never take the whole tree: 68 points at full completion, about 60% of the tree, so choose. Nobody loses points they already had.",
            } },
            { Head = "Better map floors", Lines = {
                "The chest by each map floor's exit portal is now a MAP CACHE: 1-2 items, gold, and a chance at a Chart Shard, a Sigil Mark or a map. More item quantity on the map, better caches.",
                "Charged and Rare elites on maps can drop Chart Shards and Sigil Marks. The guardian's cache is still the big payout.",
            } },
            -- (MODS builder: mods scale with tier, the map card, map boosting)
            { Head = "Map mods scale with the tier", Lines = {
                "Map mods get stronger on higher tiers: a tier 12 map's mods hit about 60% harder than tier 1's (Fortified: +40% enemy health on tier 1, +64% on tier 12). They pay more item quantity and rarity to match.",
                "The nastiest mods (Glass Arena, Bleak, Short Fuse, Empowered Guardian, Steel Skin, Exposed, Champions) only roll from tier 4; All In and Hollow from tier 7.",
                "A map never rolls two mods of the same kind: one extra-damage mod, one enemy-resistance mod, one enemy-damage mod, one enemy-health mod, one speed mod, one pack-size mod (Swarming or Teeming, never both).",
                "Rare maps roll more mods: 4 on tiers 1-3, 4-5 on tiers 4-6, 5 on tiers 7-9, 5-6 on tiers 10-12. Charged maps keep 1-2.",
                "Teeming makes every pack 25% bigger (more on higher tiers) instead of adding 2 enemies.",
            } },
            { Head = "Map card", Lines = {
                "Every map at the map device now shows ITEM QUANTITY, ITEM RARITY, PACK SIZE and QUALITY, and each mod line shows its real number for that tier.",
                "Item rarity is real: it raises the loot luck of the map's floors and of the guardian's cache.",
                "The floor banner in a map shows the mods' real numbers too.",
            } },
            { Head = "Map boosting", Lines = {
                "HONE (2 Chart Shards): +5% quality on a map, up to 20%. Every 1% quality is +1% item quantity. Always full price.",
                "RUPTURE (4 Chart Shards): corrupt a Corrupted map a second time. It never destroys the map. 25% each: no change, +1 tier (+1 mod at the top tier), all-new Rare mods plus 1-2 corrupted ones that can be any tier's (the risk), or +30% item quantity and +20% item rarity. After that the map is locked (Sigil Marks still go on). The map device shows the odds and asks before it rolls.",
                "Corrupting a map no longer climbs it past the top tier.",
                "New map tree notable WIDE MARGINS (past Rich Inks): maps take a third Sigil Mark.",
            } },
            -- (BOSS builder: a guardian per band + the new map boss)
            { Head = "A guardian per band + THE LAMPLIGHTER", Lines = {
                "Each band has its own guardians now: Ruin = the Seraph Archon or the Chronarch, Dread = the Echo Warden or Forgeheart, Apocalypse = the Lockwarden or the Broodmother, Annihilation = the Duelist, the Fortune Engine or THE LAMPLIGHTER. The map device shows which one your map has. Storied maps keep theirs.",
                "Higher bands' guardians are tougher: their target rounds ask for a few more hits each band, and Annihilation's guardians now fight a step faster than Apocalypse's (they were the same).",
                "NEW MAP BOSS: THE LAMPLIGHTER, only on Annihilation maps (tier 10-12). Human-sized and never still: he circles you, side-steps your aim and glides to new spots. His shots and lanes come one at a time, after a clear wind-up.",
                "His TARGETS are his lamps: hanging lamps that sway on their chains (switch between them), one lantern swinging on a long chain in front of him (track it), and lamps that flare up one at a time round you (flick to each). Break them all in time: STAGGERED, +75% damage. His head is the weak point.",
                "The maps you already have re-pick their guardian once from their band's guardians.",
            } },
        },
    },
    -- UPDATE 8 (LOOT/RUN builder, finalised 2026-10-22 from every builder's notes; DEFENCE's Phase 6 re-fit in "Packs and elites").
    -- Version is a guess -- main's call.
    {
        Id = 121, Version = "0.99v", Date = "Oct 26, 2026", Title = "UPDATE 8: THE REVAMP",
        Sections = {
            -- (release sweep 2026-10-31: the wipe notice moved to the top of the entry so nobody misses it)
            { Head = "Fresh start: everyone starts over", Lines = {
                "Update 8 starts everyone fresh: levels, items, gear, mods, maps, gold, currencies and the leaderboards reset, and the Exchange starts empty.",
                "Everything you bought stays: cosmetics, skins and copies, BOUND, colourways, your settings, the bought parts of your hideout (stash tabs come back empty), the season pass and revive credits.",
                "Crews keep their name, tag, members and ranks; the crew bank and research start over.",
            } },
            { Head = "Five damage types", Lines = {
                "Every hit is now Kinetic, Heat, Cryo, Volt or Void. Most guns are Kinetic; beams, the railgun and a few others carry an element.",
                "Each biome resists one type and is weak to another (the floor card says which). Kinetic works the same everywhere.",
                "Each type has its own ailment: Bleed, Burn, Chill (enough Cryo freezes), Shock (they take more damage) and Wither (stacks of more damage taken).",
                "Hit numbers are coloured by type, with a small arrow when a resist or weakness matters.",
            } },
            { Head = "Defences", Lines = {
                "PLATING (your old armour) cuts Kinetic hits, more against small hits than big ones.",
                "AGILITY gives a chance to dodge a normal enemy attack completely. Rings, zones, hazards and the big boss moves never miss.",
                "Agility can now dodge a boss's normal hits too (a plain swing, thrust, claw or shot at you, such as the Phantom's lock-on or the Ravager's rake). Area attacks and big boss moves still can't be dodged, and Ghostwalk never makes a boss's hit miss.",
                "WARD is a shield in front of your health. It refills 2 seconds after you stop taking damage. Void damage goes straight past it.",
                "Resist Heat, Cryo, Volt and Void on your gear. Harder difficulties lower your resists, so stack them as you climb.",
                "Enemies can Shock and Wither you too. Look for the chips over your health bar.",
            } },
            { Head = "Guns", Lines = {
                "Each gun base has its own damage type split, shown on its card.",
                "New guns roll new lines: added Heat, Cryo, Volt or Void on that gun, more Kinetic on that gun, ailment chances and the usual speed and crit lines.",
                "Guns have SOCKETS (red, green, blue), some of them linked. Higher item level and rarity mean more sockets and links. A 6-link is very rare.",
                "The AA-12 has a new model: the real boxy AA-12 with its carry-handle sights and an 8-round box magazine, the charging handle rides back on the reload. Same gun and stats. The Fission AA-12 skin is rebuilt on it.", -- (AA-12 replacement 2026-10-29)
            } },
            { Head = "Shot mods", Lines = {
                "MODS go into gun sockets of their colour and change what your shot does: chain to the next enemy, fork, ricochet, explode, pierce, mark, convert to an element, and more.",
                "Only the gun's biggest linked group works. Mods in other sockets sit idle.",
                "Mods level up while they're in your equipped gun (up to your level's cap) and drop from enemies from level 3. Bosses drop better ones.",
                "Open them from MENU > MODS or the inventory. They trade and sell on the Exchange like items.",
                "The 4th, 5th and 6th linked mods count for less (the square root of their bonus), so big links stay strong without running away.",
            } },
            { Head = "Gear", Lines = {
                "GLOVES are a new gear slot.",
                "Every piece has a base with its own defence (Plating, Agility, Ward or a mix of two) and a fixed implicit line.",
                "Gear lines are split into prefixes (life, defences, added damage) and suffixes (resists, speed, crit, luck). A few rare pieces carry a line that changes how a defence works.",
            } },
            { Head = "Five rarities", Lines = {
                "Common, Uncommon, yellow RARE (3-6 lines, your everyday drop), red MYTHIC (an extra line, Torment and up) and RELIC.",
                "Your old items were moved onto the new rarities automatically. Gems and titles use the same five grades now.",
                "Mythic items have a slightly lower damage multiplier (1.4x) on new drops.",
            } },
            { Head = "Relics", Lines = {
                "About 40 named Relics across every gun class and every gear slot. Their lines are fixed and many change how a build plays: conversions, executes, Volt that freezes, Plating that stops elements and more.",
                "Relic guns come with their own fixed sockets.",
                "Some Relics only drop on harder difficulties. They come from bosses, Boss Trials, map guardians and, very rarely, any drop.",
                "You can wear as many Relic pieces as you like now.",
            } },
            { Head = "Crafting", Lines = {
                "Every crafting currency still does one random job, and now works on the new gun lines and gear bases.",
                "Three new currencies for gun sockets: BORE BIT (how many), SOLDER (which are linked) and TINT (their colours). Mods that no longer fit go back to your bag.",
                "BURNISH adds 1-5% quality to a mod (each 1% = a bit more damage). Use it in the MODS window.",
                "Prism rerolls a Relic's numbers inside their ranges.",
            } },
            { Head = "Packs and elites", Lines = {
                "Every floor, solo or party, is now packs of weaker bots around a leader. Fodder dies fast and drops a little less.",
                "Elites roll monster mods: blue elites 1-2, yellow ones 3-4, with only one toughness mod each. Their name tag lists them, and more mods mean more loot.",
                "New mods include Summoning, Vampiric, Warded, Resistant, extra elemental damage and COMMANDING: its pack hits harder and takes less damage while it lives, so shoot it first (the gold ring on the floor shows its reach).",
                "Hasted is gone. Mini-boss floors bring their own pack wave.",
                "Packs grow with the difficulty: 4-5 fodder round each leader on Easy, up to 8-10 on Annihilation (mini-boss waves too). Fodder no longer wear an element aura (the leader shows the pack's element), and a party's opening wave starts with fewer, bigger packs.", -- (PACK SIZE BY DIFFICULTY)
                "Run boons are gone. The wandering merchant sells a Currency Pouch instead.",
                "Enemies were re-balanced for the new builds: enemy health and damage were re-fitted so an average build kills a basic bot at about the old pace, and enemy hits take about the same share of your health as before.",
                "Bosses: the aim rounds no longer come faster on hard difficulties. A boss you're slow on takes at most about 1.5x as long, and breaking the targets fast still staggers it and shortens the fight.",
            } },
            { Head = "Linked rooms", Lines = { -- (LINKED ROOMS are the normal game, 2026-10-22)
                "Floors are big areas now: two or three combat rooms in a line, joined by paths that turn a corner, and a side room. The exit (the chest and portals) opens when the EXIT room is clear. Each room closes the way on with a gate until you clear it: its header counts what's left on a bar, its beams go dark with a clunk as you clear, and it unlocks and sinks into the floor with a thud when the room is done, so you hear the way open from anywhere in the room. The side room is optional.", -- (SEALED ROOMS 2026-10-25; SEAL GATE 2026-10-26; gate sounds 2026-10-26)
                "A linked floor counts as two floors, so runs keep their length: 2 linked floors, a regular floor and the boss. Jobs, contracts, floor records and Season XP count it twice.",
                "Packs wait in their rooms and wake when you walk in or they see you. They fight you in their room and its doorways, but never follow you down a path. A room's packs warp in as you step through its doorway: a shaft of light, a ring at each spot and a rush of air, and they can't move, attack or be hurt until they've formed. The paths between rooms are always clear.", -- (SEALED ROOMS 2026-10-25; ARRIVAL 2026-10-26)
                "The SIDE ROOM holds an elite, the floor's encounter and a HIDDEN CACHE that opens once the room is clear (once per player in a party). One room is a HORDE room: an elite with a crowd of fodder.",
                "Party floors and maps (floors 1-4) are linked too. Boss, mini-boss and guardian floors stay single arenas. Trials, The Proving, the Daily and the Gauntlet Run are unchanged.",
                "The floor number on the banner is right as soon as you arrive on a linked floor (it showed the floor before for a moment).",
                "Boss bars no longer sit on top of the floor modifiers, the map clock or the City Broadcast line: those lines move under the bar.",
                "A gentler start: on Easy the first floors have one group of about 3-5 bots in each room (the horde room a few more) and grow to the full size by Hard; Normal's first floors have fewer, smaller packs too. Each kill there pays a little more XP, so levelling is just as quick.",
                "Fixed bots showing up early in the next area or stuck in walls: packs no longer wake up through the rock between rooms, enemy outlines only show through walls in the room or path you're in, and cliff rock no longer pokes into the rooms (a bot that ends up in rock steps out and stays out, and bots no longer pick spots inside rock to fly to).",
                "Better-looking floors: the rock walls round the rooms lean back and break up instead of standing as flat slabs with ruler-straight tops, the walls over the doorways get a broken crest, ground patches are round, the big hills on the skyline are craggy, and the props round the rooms are no longer the same few models in a row: every piece is sized, leaned and tinted on its own, with seven new rock and cliff models mixed in.", -- (MAPLOOK 2026-10-24)
                "The ground in every room and passage is flat and level with where you walk: it used to sit in a lumpy layer a little above your feet, hiding the lava cracks and ground markings and making low walls look shorter than they are.", -- (MAPVIBE 2026-10-25)
                "Rooms are dressed like someone uses them: every wall of every room has its things standing against it -- a foundry's working wall of barrels, crates and tools, ice and snow drifted up one side, leaning wind-blown debris on the storm cliffs, squared stacks in the tech rooms, colonnades with fallen pieces in the temples, scattered clusters in the wild worlds -- from 49 new models, and no two of the same thing side by side. The floor in the middle stays open for the fight, the stone rings in the middle of the rooms are gone, nothing floats any more (the spore world's giant mushrooms stand on their own sky island), and boss arenas keep their own look.", -- (MAPVIBE PROP SETS 2026-10-25)
                "Every room of a floor has its own life now, not just the first: its own drifting embers, snow, spores, petals, mist or rain, glowing pools of the place's colour at the wall feet, a worn trail between its doors, a landmark set into one wall, and in the molten rooms lava troughs and glowing cracks.", -- (MAPVIBE ROOM ATMOSPHERE 2026-10-25)
                "The molten foundries went dark and lava-lit: the low sun is gone and the stone is darker, so the light comes from lava sluices running along the wall feet behind basalt retaining walls, glowing cracks spreading out of them, a big tipped crucible pouring molten metal down one wall, iron girders with a hanging crucible over a corner, chimneys and buttresses on the rim. Your gun, enemies, portals, chests and loot keep their brightness.", -- (MAPVIBE MOLTEN PILOT 2026-10-25)
                "The frozen rooms and the haunted bayou got the same treatment, each its own way: frozen channels of cold meltwater under ice along the walls with frost cracks running out, ice shelves with icicles over the rim and a giant's sword frozen in a block of ice; black water along the bayou walls with rotten walkways, dead willows leaning over the rim, grave markers in the mud, a sunken shack with its lantern still lit and mist creeping over the floor. The molten rooms' pour is now a real stream of metal, and their floors have cracks, vents and slag all over.", -- (MAPVIBE PASS 2 ROLL-OUT 2026-10-25)
                "Three more worlds got their own look: the Sun Empire's temples have turquoise canals in carved gutters along the walls, cobbled paving, overgrown megaliths on the rim and a colossal sun stone fallen against a wall; the Stormspire is darker and wet, with rain runoff along the walls, puddles, lightning scars burnt into the ground, dead trees all bent the same way by the wind and a wrecked ship heeled over against a wall; the Void went near-black, lit by violet rifts torn into the floor along the walls, veins of light spreading out of them, and a shattered monolith with its core glowing between the floating pieces. Flat floor pieces everywhere are broken, irregular shapes now (no more stray boxes). The haunted bayou went cold and grey-blue instead of green: black water winds across the floor in channels and pools, dead branches, roots and reeds lie everywhere, bigger dead trees reach over the room edge, and a rotten boardwalk leads from one doorway past the sunken shack to the other.", -- (MAPVIBE PASS 2 AZTEC / STORM / VOID 2026-10-25)
                "The Cyber floors became machine halls: a wall of server racks, tanks and a ribbed reactor housing along one side under a steel gantry, consoles opposite, a lit channel at their feet, engraved deck plates with glowing circuit traces, energy coils in the corners and a breached reactor spilling cables and sparks. The Derelict Station took a hit instead: hull plates buckled in off the walls, racks and tanks knocked over across the corners, a girder collapsed against a wall with a cable sparking under it, a broken red emergency strip, and a breach torn up through the deck with frost pouring out of it. Rooftop and station crates, poles and containers no longer hang out over the drop.", -- (MAPVIBE CYBER / STATION 2026-10-25)
                "The Dreamscape became a sleeper's bedroom dissolving into the dream: giant furniture sinks into the floor along the walls, growing bigger from one end of the room to the other -- a bed, an open wardrobe with light spilling out and a clock melting over its top, a grandfather clock, armchairs, glowing floor lamps, towers of books -- a trail of loose pages drifts between the doorways, and the Sandman's hourglass lies toppled on its side with a thin stream of gold sand falling out of the sky onto a glowing dune. The stone gates over the first room's entrance in every world are now carved in the room's own stone with a band of the world's colour, instead of a slab of raw paint.", -- (MAPVIBE DREAM + ENTRY GATES 2026-10-25)
                "The Neon Flats are a dead roadside stop now: a cracked asphalt road with faded lines and skid marks runs through every room from one doorway to the other, a filling station stands at one end of it (pumps under a canopy with a lit pink fascia), a motel sign and a phone booth at the other with cones along the verge, an old sedan is abandoned against a wall, a water tower stands in the far corner, and a giant arrow sign has fallen against a wall, its bulbs still lit, pointing on down the road.", -- (MAPVIBE FLATS 2026-10-25)
                "The Toxic Wastes are a chemical breach: a ruptured tank on its saddles pours glowing sludge at one wall behind a broken cordon of barriers and warning signs, drums lie blown out along the walls (knocked over and leaking near the tank), a glowing seep branches across the floor to a choked drain on the far side, and crushed cars are stacked against the walls. The Brass Skyport hangs its cargo now: davit cranes at the walls with loads slung under them at different heights, crates and a rope winch by them, a big propeller on a wall bracket, rope coils on the deck, and an airship gondola that came down hard, keeled over in broken planks with its portholes still lit.", -- (MAPVIBE WASTE / SKY 2026-10-25)
                "The Spore World grew in: real mushrooms now, with lumpy dark caps, gills underneath, a ring on the stem and spots and gills glowing teal, in clusters at the wall feet and as giants leaning in over the rim. A fallen giant lies along one wall with its glowing gills turned to the room and bracket fungi growing on its stem. The floor is darker under moss, lichen, roots and mycelium mats with threads of light running through them, and the old pink toadstools, puffballs and pods are gone.", -- (HUBFIX ATMO FUNGAL 2026-10-25)
                "The Sunken Temple grew wild: ferns and broad-leaved undergrowth crowd every wall foot and the cover, vines hang in curtains down cliffs gone green with moss, canopy trees and palms lean in over the rims, turquoise spring pools steam among wet boulders, the floor breaks into mud, grass and leaf litter with roots and broken paving across it, and a toppled temple head lies half sunk at one wall, its gold eyes still lit.", -- (HUBFIX ATMO JUNGLE 2026-10-25)
                "The Moonlit Spires turned to graveyard: iron fences with rows of worn headstones behind them line the walls under gas lamps, cold mist lies in the dead grass between the old cobbles, a broken gothic window and a bare dead tree stand against the rim, and an opened sarcophagus breathes cold light under a weeping angel, candles burning round it.", -- (HUBFIX ATMO GOTHIC 2026-10-25)
                "The Sakura Shrine came into bloom: cherry trees ring every room and crown the rims, their blossom hanging over the edges and shedding petals onto the dark moss, raked gravel walks with stone kerbs wind in from the doors under glowing stone lanterns, a vermilion gate stands against the rock, and the great temple bell lies fallen beside its broken frame, lanterns still burning by it.", -- (HUBFIX ATMO SAKURA 2026-10-25)
                "The Sun Dunes grew harsher: soft sand dunes heap up every wall foot and into the corners, drifting round the cover, the ribs of something enormous arch high out of the sand and over the rock at one wall, termite spires tower at the wall feet, a torn sun shade throws a patch of shade, a fire bowl burns at the dune line, and dust devils spin across the open floor.", -- (HUBFIX ATMO DESERT 2026-10-25)
                "The Deep came alive: reef boulders crusted with coral line the walls with glowing tube worms and anemones between them, giant kelp rises far over your head at the wall feet, shells and bubbling vents dot the sand, a shaft of drowned light falls from far above, and a giant clam gapes open at one wall with a glowing pearl on its mantle.", -- (HUBFIX ATMO ABYSS 2026-10-25)
                "The Autumn Highlands turned: broad maples blaze red and amber at the wall feet shedding leaves into drifts, a dry-stone wall runs along one side with hay, toadstools and a lantern on a post, and a harvest cart lies tipped on its broken wheel with pumpkins spilled across the grass and a scarecrow leaning beside it.", -- (HUBFIX ATMO AUTUMN 2026-10-25)
            } },
            { Head = "Shorter runs", Lines = { -- (RUN PACE 2026-10-24)
                "A run on your level now takes about 6 to 10 minutes on every difficulty. Before, it took 12 to 23 minutes from Hard up.",
                "From Hard up, linked floors have two combat rooms instead of three, with two packs each, plus the side room. The side room now opens off the exit room. Easy and Normal keep three rooms.",
                "Enemies get much less tanky as a run goes on. Floor 1 is the same, but the later floors and the boss have less health (Normal and up). They hit just as hard and drop the same loot and gold, so loot comes in faster.",
                "Each kill in a normal run gives a bit less XP from Hard up, so levelling is only a little faster than before (about 1.2x per hour). Maps, trials, the Daily and the Gauntlet Run keep their XP.",
                "Endless plays the same way: its first 6 floors match a run (less health later on, a bit less XP a kill), and the deeper floors keep climbing from there, so they go about twice as fast as before and still pay their full XP. A floor-10 boss takes about 2 to 3 minutes on your level (was 7 to 8).",
                "Run bosses now take about a minute to a minute and a half on your level. Some took 3 to 5 minutes before.",
            } },
            { Head = "Passive tree rebuilt", Lines = {
                "A smaller tree (about 2,500 nodes) where every node matters, and you can only reach a small part of it, so where you go is a real choice.",
                "Small nodes give Kinetic, Heat, Cryo, Volt and Void damage, Plating, Agility, Ward, resistances and attributes. Notables sit in themed clusters, and many carry a price.",
                "CORNERSTONES change a rule and always give something up: no crits but every hit is a weak spot, a one-round magazine that hits far harder, chains that hit the same enemy twice, life turned into Ward, all Kinetic damage turned into Heat, Volt or Cryo, and more.",
                "No more level ceilings on the tree: one number per stat.",
                "Every tree and specialization is refunded once.",
            } },
            { Head = "Attributes", Lines = {
                "Strength, Dexterity and Intellect now come only from the tree and your gear. Hand-placed points are gone.",
                "Each gives a small bonus, and guns, gear and mods need them: a gun needs its type's attribute, gear its defence's, a mod its colour's (red Strength, green Dexterity, blue Intellect).",
                "A mod whose attribute you don't meet sits idle.",
            } },
            { Head = "Specializations", Lines = {
                "All 15 rebuilt around the new damage types, defences and mods.",
                "Class balance: the tree's areas were re-tuned so every class levels at a similar pace. The Arc Projector deals a lot more damage, and Marksman guns deal 35% more at mid levels (fading out by level 250).",
                "Shot mods hit harder: an average 3-link is about +50% damage on one target.",
                "Bigger linked groups need higher item levels: 4-link from 25, 5-link from 45, 6-link from 75. The socket currencies follow the same limit.",
            } },
            { Head = "Class builds", Lines = { -- ((CLASS BUILDS) PART B)
                "Every class now has four builds of its own, 20 in all. A build is a gun family, a specialization and two Cornerstones deep in your class's part of the tree. The Index's HOW IT WORKS > CLASS BUILDS lists them and what to look for.",
                "GUN FAMILIES: the 49 guns are in 11 families, and every gun has its family's built-in line (on the tooltip; it can't be rerolled). Bolt Action: the first hit on each enemy crits. Marksman Rifle: weak-spot hits in a row stack damage. Hand Cannon: a new target takes more and the round comes back. Sidearm: more Agility on the move, and a dodge gives a short damage boost. SMG: every 10th hit applies every ailment you can cause.",
                "Rifle: +1 pierce, and each enemy pierced adds to the rest of the shot. LMG: damage ramps up while you hold the trigger. Pump Shotgun: more damage when every pellet hits one enemy. Auto Shotgun: each pellet rolls ailments on its own. Ray: every 5th tick on an enemy applies your ailments. Lance: shots go through every enemy in a line.",
                "Some shot mods work differently on a family: Chain on a Bolt Action hits at full damage, Chain on an Auto Shotgun jumps from every pellet that kills, Detonate on an LMG only goes off at full ramp, Fork on a Lance forks at the end of the line.",
                "SPECIALIZATIONS: each of the 15 has one SIGNATURE rule nothing else in the game has, such as Shatter, Mark, Execute, First Contact, Static, Ghost, Demolition, Lancer, Suppressor, Arm's Length, Overcap, Bloodstorm, Wildfire, Cryostasis and Plague. The panel tags it.",
                "Three new class Cornerstones on the rim: SLUG ROUNDS (Breacher: your shotgun fires one slug with all its pellets' damage +10%, at range and with real weak-spot hits, but no pellet effects), FIELD COMMANDER (Vanguard: +4% damage per enemy within 20 studs, up to 10; 25% less with none near) and CAROM SHOT (Gunslinger: weak-spot hits bounce half their damage to the nearest enemy's weak spot; body hits deal 20% less).",
                "Cornerstones moved so each build's pieces sit in its own class's area. Any class can still walk there, it just costs a lot of points.",
                "Every tree and specialization is refunded once more, for free.",
                "Heavy rounds: slow guns carry overkill and pierce. A kill's leftover damage jumps to the nearest enemy and keeps going while it kills (Bolt Action rifles and Lances up to 4 enemies, Marksman Rifles 2, Rifles, LMGs, Hand Cannons and shotguns 1; a shotgun kill carries the rest of the blast), and slow guns shoot through the enemies lined up behind (Bolt Action 3, Marksman Rifles 2, Rifles, LMGs and Hand Cannons 1). Fast guns barely change; one enemy on its own (a boss) takes exactly the same damage as before.",
                "MARKSMAN LONG CARRY: with a Marksman class gun, a kill's leftover damage now jumps to an enemy up to 30 studs away (12 for everyone else), so a sniper's big shots clear the spread-out stragglers of a pack too. Bosses and lone elites take the same damage as before.",
                "CLEAR MODS hit harder and reach further: Chain jumps up to 36 studs for 90% of your hit (was 30 studs, 42%), Fork splits within 30 studs for 85% (was 22, 30%), Volley strikes within 18 studs for 80% (was 8, 30%: it almost never found a target), Impact bursts 12 studs for 40% (was 5, 25%), Detonate reaches 16 studs. They now cost a little damage on your target (Chain 8% less, Fork and Volley 5% less, Impact no bonus), so a clear link wins packs and a focus link (Narrow Bore, Overcharge, Added damage) wins bosses and elites.",
                "Defences in the tree: Agility nodes give twice as much and Ward nodes three times as much as before, and every notable between the Vanguard and the Marksman, the Marksman and the Gunslinger, and the Gunslinger and the Arcwright also gives +60% Agility. An Agility or Ward build is now a real choice next to Plating and life.",
                "Life is spread over the whole tree: every class now has life and its own defence on small nodes near its start (Plating for the Vanguard, Agility for the Marksman and Gunslinger, Ward for the Arcwright), so no one has to walk to the Breacher to get tough. The Breacher keeps the most life and Plating; its Leather Hide notable is +20% life (was +67%). Notables between the Vanguard and the Marksman and between the Arcwright and the Breacher add Plating, and those between the Breacher and the Vanguard add Heat damage.",
                "Class leans: the Marksman is a glass cannon (+23% damage), the Gunslinger a fast glass cannon (+18%), the Vanguard the middle (+11%), the Arcwright a sturdy middle (-11%) and the Breacher the tank (-21%), each with its class guns. Toughness leans the other way, from the Breacher (about twice the average) down to the Gunslinger (about half). The average across the classes is unchanged.",
                "The Vanguard hits about 13% harder with its class guns than first planned: it had the toughness of a tank but fell behind on damage. It stays in the middle, below the Gunslinger and above the Arcwright.",
            } },
            { Head = "Maps", Lines = {
                "Maps use the new systems: Searing, Frostbitten and Overcharged add elemental damage to every enemy hit, Hollow adds Void that skips your Ward.",
                "Monster resist mods (Heatproof, Frostproof, Insulated, Voidproof, Plated), Warded monsters that refill, Exposed (lower max resists), Dampened (slower Ward), Sluggish (fewer dodges).",
                "Teeming (bigger packs), Champions (every elite is yellow) and Warbands (every elite Commanding or Volatile).",
                "Map timers are much longer and grow with the tier: about 15 minutes on the first tiers up to about 26 on the deepest (they were 5 minutes on every tier). Short Fuse still cuts 30%.",
                "Beating a map's guardian now takes you home through a gold portal (it used to open a portal into an extra floor), and the run summary says MAP CLEARED.",
                "Maps pay about 2 to 3 times a normal run's XP a minute on every tier. The deeper tiers paid up to 4 times, so they give a little less XP than before; gold and loot are unchanged.", -- (MAP XP 2026-10-25)
            } },
            { Head = "Party floors", Lines = { -- (PARTY TWIN 2026-10-25)
                "Party floors now look exactly like solo floors: the same terrain, cliffs, props and room atmosphere. Everyone in the party sees the same map.",
            } },
            { Head = "Fixes", Lines = { -- (FUTURE-PROOF pass 2026-10-25)
                "Warbands maps no longer turn blue elites into gold ones: the extra modifier it adds keeps the elite's own tier.",
                "The Index's ENEMIES page lists every elite modifier again (it stopped part way down).",
                "The Daily Challenge no longer builds a dead Boon Shrine on some floors.",
                "The map device shows map rarities by their names (Plain, Charged) instead of internal ones.",
            } },
            { Head = "New look", Lines = { -- (UI CLEAN 2026-10-28, docs/UI_CLEAN_2026-10-28.md)
                "A whole new look: flat dark panels, sharp corners, tall caps for titles and numbers, one off-white accent, and no more glow or neon edges. Every heading now stands out from the text under it.",
                "New HUD: a big health number with a thin bar, small pips for your lives, your gun's name and a big ammo count. No boxes and no always-on key hints; on phones it sits at the bottom centre, clear of your thumbs.",
                "The floor banner, safe-zone line, objectives, boss bars, messages and the goal tracker share one clean see-through plate, lined up on the same screen edges. Your currencies run along the top as icons with big numbers.",
                "New full-screen inventory: your name, level and power numbers on the left, ten matching loadout slots in the middle and your bag as a grid of item tiles on the right. Hover or tap a tile for EQUIP, sell or lock; one SELL menu holds selling, auto-sell, stash-up-to and buyback.",
                "Every gun has its own drawn icon, and every gear type has a real picture: a helmet, a plate carrier, leg armour, gloves, boots, a pendant on a chain and a ring with a stone.",
                "Item cards rebuilt: a rarity band with the item's picture, a clear BASE stats grid, MODIFIERS with their tier on the right and a \"vs equipped\" strip.",
                "Every window opens full screen with the windows that belong together along the top: Inventory / Stash / Forge / Mods / Exchange / Passives, Settings / Guide / Patch notes / Credits, Challenges / Season / Index, and Profiles / Party finder / Crew / Trade.",
                "The Forge shows your item's full card between the item list and the actions, with costs as plain numbers (red only when you're short). Every item list in the game uses the same row: picture, name in its rarity colour and a thin rarity edge.",
                "Calmer run screens: a run summary that leads with your time, kills, accuracy and DPS, a quieter out-of-lives screen, flat enemy health bars and simple ring touch buttons on phones.",
            } },
            { Head = "Quality of life", Lines = { -- (QOL pass 2026-10-28, docs/QOL_2026-10-28.md)
                "A live MINIMAP in every dungeon: top-right, it turns with you and shows the rooms (cleared ones go green), enemies, your party, Rare+ loot, the side room's cache and the exit. N (D-pad right, or tap it on a phone) makes it big and see-through, or turns it off; Settings > Interface has Minimap + Minimap Zoom.",
                "RUN AGAIN on the run summary and the DUNGEON CLEARED banner: the same difficulty, game type and bot skill straight away (a map run uses another map of the same tier from your bag; in a party the leader starts it).",
                "Leaving a floor with items still on the ground warns you first (\"3 ITEMS STILL ON THE GROUND\"): press again to leave. Drops your Drop Rules hide don't count.",
                "New key PICK UP ALL NEARBY (Z, D-pad left, or a button on the loot card on phones): grabs every visible drop within reach, nearest first, until your bag is full.",
                "The passive tree has an undo: clicked nodes wait as PENDING (light blue) until you press APPLY. UNDO takes back the last click, CLEAR all of them, and clicking a pending node again drops it for free.",
                "New keys: DUNGEONS (O) opens the Dungeons window anywhere in the city, FORGE (I) opens the Forge in the city or your hideout; both are tiles in the MENU too.",
                "Forge: rerolling a Mythic, a relic or an item with a perfect-roll star asks CLICK AGAIN first; SHIFT-click a reroll to do up to 5 in a row (it stops when a star roll or a top-tier line lands); hold ALT over an item to see every line's min-max range.",
                "Party READY CHECK: when the leader presses START everyone gets a READY? card for 15 seconds; the run starts once everyone is ready, or the leader can START ANYWAY when time runs out.",
                "Messages stack (up to 4, newest on top) instead of replacing each other, and BAG FULL stays longer. Settings > Interface > Global Drop Feed turns the server-wide drop rows off.",
                "A BAG 52/60 chip shows over your health bar once your bag is 85% full, new items get a dot in the inventory until you look at them, and in your hideout STASH UP TO + ctrl-click move items into the stash.",
                "Controllers: every prompt is RB now (X is only reload), and opening a window selects something straight away so the D-pad works at once.",
                "Death recap: when you lose a life you see what killed you and the last hits you took (who, how much, what type) -- on the OUT OF LIVES screen and the run summary too.",
                "The run summary compares your accuracy, weak-spot rate and DPS with your recent average (\"+2.1% vs avg\"), and a LAST RUN tile in the MENU reopens it.",
                "Goal tracker: in runs, up to 3 daily contracts / weekly jobs show top-left with live progress. Pick them with TRACK in Challenges > WEEKLY (Settings > Interface > Goal Tracker).",
                "Lost your connection (or quit) before clearing a map's first floor? The map is given back the next time you join.",
                "Party runs show your teammates above your health bar: name, health and small pips for lives, or DOWN / OUT.",
                "Sold something by mistake? BUYBACK in your bag lists the last 10 items you sold this session and buys any of them back for what they sold for.",
                "Gear shows when it's an upgrade too: the loot card says \"+x% vs equipped\" and better gear gets the ▲ in your bag, scored like EQUIP BEST.",
                "Rarity symbols before every item name in the bag, the stash and on the ground (● Common, ■ Uncommon, ◆ Rare, ◈ Mythic, ★ Relic). Settings > Interface > Rarity Symbols.",
                "Exchange: hover, tap or select any listing for the full item card (click to pin it), rows show \"+N more\" instead of running off, PRICE CHECK shows the 3 cheapest similar listings, and you're told on join when your listings sold (green dot on the MENU / new EXCHANGE tile).",
                "Binding a key another action already uses swaps the two and tells you; old clashing binds are sorted out when you join. The Welcome Guide shows YOUR keys.",
                "Controllers: selecting an item shows its card beside it with your equipped item; SELECT shows the min-max roll ranges.",
                "Every skin set's UI theme is rebuilt on the new look: menus take the colours of the set AND the colourway you wear, with touches made for that set (a silk thread on the tabs, a gold-mended seam, a watch dial, a planet's edge ...). No more stretched header art. The store's own themes got the same treatment.",
                "Damage numbers follow the gun skin in your hands and its colourway: every set has its own digits, motion, crit, weak-spot and kill look (struck at the anvil, a manga sticker, a thermal readout, ticking like a watch ...). Odd lines under some numbers are gone.",
                "MY COSMETICS has a BUNDLES slot: every set you own in one place, EQUIP THE WHOLE SET puts every piece on at once (SHOW ALL lists the rest).",
                "Damage numbers: weak-spot hits and body hits on one enemy now count up as two separate numbers, so a body shot after a headshot no longer shows as a headshot.",
            } },
            { Head = "Runs better", Lines = { -- (OPTIMIZE pass 2026-10-27)
                "Graphics Quality has a new AUTO setting (the default): phones and tablets, and anyone who set their Roblox graphics slider to 4 or lower, get Low automatically. You can still pick High or Low yourself in Settings > Video.",
                "Low now also thins the room atmosphere's particles and the faint lava cracks on molten floors, and turns bloom off straight away (it used to wait until you changed area).",
                "Less work every frame in dungeons: idle packs in nearby rooms think less often, enemies behind you or asleep aren't animated, and health bars that can't show are skipped.",
                "Bosses are drawn exactly where they are instead of a couple of frames behind.",
                "The Bazaar is no longer drawn while you're in a dungeon, and the patch notes and Settings tabs are built when you first open them, so joining is lighter.",
            } },
            { Head = "Skies", Lines = { -- (HUB SKY 2026-10-23; DUNGEON SKY SEAM 2026-10-24)
                "The sky over the city and the Bazaar no longer looks like a box: the seam is gone, and past the walls the city goes on to the horizon, its street lights fading into a warm glow.",
                "The Cyber and Spore World skies no longer have a straight line running down the sky ahead of you, and the clouds seen through the water overhead in The Deep (and the Deep Aquarium hideout) no longer have a cut through them.",
            } },
            { Head = "The city", Lines = { -- (HUB LOOK 2026-10-24)
                "The city's streets are clean night asphalt: no more pink blotches (the old puddles mirrored the sky) or giant cracks, and the Bazaar's street is no longer a black void.",
                "Street lamps, benches, planters and bollards are rebuilt, and nothing is a copy-paste row any more: stalls, Bazaar booths, AC units, balconies, lanterns and the range's sandbags each have their own size, angle and wear.",
                "The Training Grounds' floor is grey concrete instead of orange dirt, and the firing-line rail is worn paint instead of a glowing caution strip.",
                "The leaderboards are lit sign boxes now, set higher on the walls so they no longer crowd the shop signs. The towers have a ledge over the shop level and a cornice on top, and the square round the centre has a paved border.",
                "The quarter leaders are dressed for their quarter (coats, a rain hat and lantern, a hood and visor, a hard hat), the Hall of Aim stands on stone plinths, and the city has a little more depth at night: darker corners, brighter shopfronts.",
                "The city is a little brighter at night and the starry night sky is back. The Training Grounds is a covered firing shed now: a booth for every lane, painted lane numbers and firing line, a dirt range with a sand berm at the back, and no more neon everywhere.", -- (HUBFIX 2026-10-24)
                "The city's towers have real depth now: upper floors step back behind their own roof edge, some floors are open loggias set deep into the wall with a lit room at the back, and bay windows, stacked balconies and slab edges stand out over the street.", -- (HUBFIX DEPTH 2026-10-25)
            } },
            { Head = "Levels and jobs", Lines = {
                "The level cap is 200 (content above it is hidden for now). Early levels are as quick as before; past level 20 each level takes a bit longer, so level 200 is a long road (about 90 hours for an average player).",
                "Pack fodder counts as a fifth of a kill toward weapon mastery and Zeroing, so they fill at about the old pace.",
                "Jobs that count floors (contracts, the Job Board, Season Feats, quarter bounties) need about a third fewer floors, and 'clear a floor fast' jobs allow 60 seconds (was 40).",
            } },
            { Head = "Better game sounds", Lines = { -- (GAME SOUNDS v4, 2026-10-23)
                "Every menu, reward and combat sound that wasn't a gun is new: real recordings (wood, marimba, harp, punches, rock, coins, a chest latch) instead of synth beeps, warm and short.",
                "Each kind of sound sits at its own level under your gunfire: menu clicks soft, level ups and floor clears warm but never louder than a shot, hit markers crisp and clearly over your gunfire but no longer as loud as the shot itself (the Hit Sound Volume slider still goes to 300%).",
                "Level up has its own sound now, and so do Forge crafts, store buys and opening a chest. One fanfare plays at a time.",
                "Getting hurt is a clear body hit you can hear on phone and laptop speakers. Boss slams, strikes, blasts and roars are real impacts instead of deep thumps.",
                "All nine Hit Sound choices and the Kill Sound choices are rebuilt, and dashing has a real swish.",
                "Music: the city, the hideouts and your runs play chill drum and bass from Roblox's licensed music library, kept quiet under your gunfire (a little quieter in runs). Starting or leaving a run blends into another track, the city picks up where it left off, duels, the tutorial and try-ons stay silent, and your hideout jukebox takes over while it plays. Settings > Audio > Music (50% to start, 0 turns it off).", -- (HUB MUSIC 2026-10-23; run music 2026-10-24)
            } },
            { Head = "Names", Lines = {
                "A few names changed to our own: the Headhunter trait is now Crownshot, the Headhunter Rules floor mod is now Aim High, the Uber Summit is the Summit Unbound, and Ascension Essence is now LODESTAR.",
                "Map rarities are now Plain, Charged, Rare and Storied. The Index's enemy tab is ENEMIES.",
                "Some guns are named after the gun they really are now: the F2000 is the FAMAS, G17 -> G19, SCAR-H -> SCAR-L, USAS-12 -> Komrad 12, KSG -> KS7, AWP -> AWM, Scout -> Hunting Rifle, SR9 -> P99, EMR -> M14 and Mk 11 -> M110. Same guns and stats; the guns you own are renamed too.", -- (GUN NAMES 2026-10-24)
            } },
            { Head = "Hideout", Lines = { -- (HIDEOUT LOFT FIX 2026-10-23)
                "The Walled-City Loft has its own night city outside now: streets with traffic far below, lit windows and neon across the road, towers fading into the distance, a train and an airship. The map room's walls no longer poke through the window wall.",
                "The map room costs 500,000 gold (was 25,000): it's the level 100 endgame buy now, above the Penthouse. The BOUND points price is unchanged, and a map room you already own stays.",
                "The jukebox has new music: four stations of professionally made tracks from Roblox's licensed music library (Late Night Lo-fi, Calm Drift, Open Plains and Night Drive), each a short playlist with the same mood as before. They play at the same level as the city music and follow your Music volume slider. With no station on, the city's chill drum and bass plays.",
            } },
            { Head = "Better loot drops", Lines = { -- (LOOT FEEL v2, 2026-10-23)
                "New drop sounds, short and warm, quieter than your gun: each rarity has its own (Rare, a Rare with a top-tier line, Mythic, Relic). Still only the two best kinds of drop for your difficulty make a sound.",
                "A Mythic or Relic swells while it flies and lands with a deep hit; a Relic is unmistakable.",
                "Drops fly out of the enemy (or the chest), land with a little ring, then the beam shoots up and the name pops in. Mythics and Relics burst on the ground.",
                "Picking something up makes a soft sound (a better one for Rare and up) and ONE small line in the item's colour at the right of the screen (a better gun says UPGRADE). The old pop-up cards with stats are gone: stats live in your bag, and the card when you walk up to an item stays.",
                "Every rarity has its own beam: Rare a thin yellow pillar, Mythic a tall thick red pillar that pulses over a pulsing ring, Relic a towering orange pillar with a white-hot core, a turning light shaft, a flare at the top and a glyph on the ground. Beams widen with distance so you can spot them across a room.",
                "Drops look like the item now: guns are the real gun model hovering over the ground, gear is a helmet, chest piece, gloves, leggings, boots, ring or necklace, and gems are a glowing crystal, each trimmed in its rarity colour.",
                "The RUN SUMMARY shows your BEST DROP of the run (hover it for the item).",
            } },
            { Head = "Tutorial", Lines = {
                "The hub tour now has you pick your CLASS (free) right after the Skill Tree, before your first run.",
                "The dash and slide work all the way to the back of the tutorial hall, where the Warden fight is.",
            } },
        },
    },
    {
        Id = 120, Version = "0.99u", Date = "Oct 21, 2026", Title = "NEON NIGHTS",
        Sections = {
            -- (overnight 2026-10-20/21: each builder fills ONLY its own section; keep lines short, player terms)
            { Head = "A new look", Lines = {
                "Every window and the HUD are redone in a calm night-city style: dark panels, more room, and one thin neon line along the top of each window, like the signs in the city.",
                "Windows fade in quickly when they open, buttons light up softly and lift a little under your mouse, and tabs slide a neon underline to the one you pick.",
                "Buttons are easier to read at a glance: the main action is bright, everything else is quiet and outlined in its own colour.",
                "The inventory is laid out again: compact gear tiles with a faint icon for empty slots, a cleaner stat list, and an item's buttons show when you point at it.",
                "Settings, Dungeons, the Store, the Exchange, Trade, Lost Loot and the Ledger are calmer too: fewer boxes, clearer headings, and empty lists say what goes there.",
                "Your gold and your inventory totals roll up to their new amounts, and messages slide in and fade out. With a window open they show at the top, clear of it.",
                "Premium UI themes still restyle everything, and rarity colours are unchanged.",
            } },
            { Head = "Faster boss fights", Lines = {
                "Every boss is a short, sharp fight now: about 10 seconds for a mini-boss, 20 for a floor boss and under 40 for a superboss or a run's final boss, if your level and build fit the tier.",
                "Bosses take full damage outside TARGETS rounds. Superbosses and the big Boss Trial bosses used to shrug off half of every shot.",
                "TARGETS no longer make the boss immune: it only guards (half damage) while the lime targets are up. Break them and it's still STAGGERED for +75% damage, so the targets are a bonus, not a wait.",
                "The first TARGETS round comes sooner (5 seconds in on a mini-boss, 8 on the rest) and the next ones about every 20 seconds, so every fight gets one.",
                "Boss Trials and The Ascendant were the worst sponges: higher tiers stacked up to 5x extra health. A tier now adds only a little health on top of its difficulty, so tier X is a fight, not an hour.",
                "Boss Trial bosses enrage after 4 minutes (was 7). The week's SHORT FUSE twist: 2.5 minutes. The Uber Summit: 3.5 minutes. The week's and The Summit's extra health are unchanged.",
                "Map guardians are about a 30-second fight.",
                "You can see your damage land: the boss bar is split into 10 chunks and each one breaks off as you get through it, and the boss flinches and sheds armour chips every 10%.",
                "No more full-screen flashes when a boss roars, enrages or gets staggered.",
                "The superboss at the end of a run (floor 6 from Hard up) has 55% less health and hits 20% softer: it was tuned for a player at its own monster level, the top of the tier.",
            } },
            { Head = "Passive tree reset", Lines = {
                "Every passive tree was refunded for free. Your class, specialization and gems are kept (socketed gems went back to your bag), and your passive skills need equipping again.",
                "Fewer points: 1 per level (it was 1, plus 5 more on every 5th level), plus 2 the first time you complete each difficulty (the clear that unlocks the next one). That's 428 at level 400 with every difficulty done (it was 800).",
                "Nodes that count: before, a built character went far past what its level allows, so most nodes added almost nothing (+0.02%). Now a build sits around its level's limit, and the tree shows what each node really gives you.",
                "Small nodes give 15-100% more than before (most in the areas whose small nodes were weakest). A notable is worth about three and a half small nodes (it was about twelve), and the attribute nodes on the paths between clusters give 30-60% less. The listed numbers are smaller overall, but now nearly all of them count.",
                "The limits on what the tree can give rise more evenly with your level: much more room before level 300, the same at level 400.",
            } },
            { Head = "Expertise", Lines = {
                "Every cluster with two or three notables now has an Expertise (the ◈ in its middle). Once you hold one of its notables, it costs 1 point and you pick ONE of four effects.",
                "Each cluster type has its own four: Weak-Spot, Critical, Focus, Magazine, Movement, Fire, Cold, Bleed, Life, Armour and more, plus one for each class's guns.",
                "Some effects are plain stats, others do something: marks on weak-spot hits, ammo back on kills, more damage on burning or chilled enemies, less damage taken while you stand still, and more.",
                "Each effect works once in your whole tree, so a second Magazine Expertise has to pick a different effect.",
                "Click the ◈ to open its panel. Right-click a picked one to take it back.",
            } },
            { Head = "Notables that do something", Lines = {
                "Ten notables (two in each class's area) now have an effect instead of their second stat. For example: Quick Holster refunds 2 rounds on every kill, Crown Breaker gives 6% more damage for 5 seconds after an elite or boss kill, Sickening Mix gives your hits a chance to inflict a random ailment, and Reinforced Frame cuts the damage you take while reloading.",
            } },
            { Head = "Refunds are expensive now", Lines = {
                "Every point you take back (one node, an Expertise, or a whole respec) costs one UNWIND, or gold if you have none: 50 gold x your level per point (5,000 a point at level 100, 20,000 at level 400). Refunds are free only up to level 10.",
                "Unwinds are rare: bosses sometimes drop one, and the first time you complete each difficulty gives one. Everyone whose tree was reset gets 5 to start.",
                "A full respec costs the same per point as single refunds, so a whole new build is a big decision. Plan your path before you spend.",
            } },
            { Head = "Gun balance", Lines = {
                "Every gun was measured against the other guns of its class on the same build. The ones that were far off are evened out (damage):",
                "Railgun 28% less, Void Blaster 23% less, Double Barrel 23% less: they killed 1.4 to 1.6 times faster than the rest of their class. They stay a little ahead, because they're the hardest to land.",
                "More damage: AA-12 +17%, SKS +17%, TEC-9 +13%, USAS-12 +12%, Arc Projector +9%, Thermal Beam +8%, F2000 +8%, M4 Super 90 +7%.",
                "Guns you already own change too, wherever they are. LMGs stay a little ahead of the rifles: they pay for it by moving slower.",
            } },
            { Head = "Faster kills", Lines = {
                "Enemies die much faster: a plain bot takes about a second of good shooting on the early difficulties and under 2.5 seconds even on Singularity, instead of whole magazines.",
                "Elites take about 3 to 5 seconds, and bosses about half as long as before.",
                "The harder difficulties still get harder, but through faster, harder-hitting and smaller enemies instead of more health. You still have to aim: weak spots and accuracy decide how fast things drop.",
                "Each kill gives less XP, because you'll get many more kills an hour: a little less on Easy and Normal, more on the higher difficulties, where runs got the most faster. Levelling takes about as long as before on every difficulty.",
            } },
            { Head = "Shorter runs", Lines = {
                "Every run is 6 floors now, on every difficulty (they were 5 to 10), and ends on its boss: a major boss on Easy and Normal, the biome superboss from Hard up.",
                "Difficulties you've already unlocked stay unlocked: a full Easy or Normal clear from when they were 5 floors still counts.",
                "No more fixed bosses in the middle of a run. Instead, 1 run in 10 has a surprise mini-boss on floor 3.",
                "Maps and the Daily Challenge are unchanged (5 floors, boss on the last).",
            } },
            { Head = "Elites", Lines = {
                "An elite gets at most one toughness modifier now (Giant, Armored, Shielded or Regenerating), so they no longer stack into damage sponges.",
                "They're also softer: Giant has 25% more health (was 60%), Armored blocks 25% of body-shot damage (was 40%), and a Shielded elite's shield blocks half the damage for 2 seconds (was three quarters for 2.5).",
            } },
            { Head = "Boss loot", Lines = {
                "Bosses have much better odds of dropping rare items now. Nothing is guaranteed, but they no longer drop what any enemy does.",
                "Each item a boss drops is several times more likely to be Legendary or better than a normal enemy's: about 3 times for a mini-boss, 4 times for a major boss and 7 to 8 times for a superboss. The higher the rarity, the bigger the boost.",
            } },
            { Head = "A better-looking passive tree", Lines = {
                "Each class's part of the tree glows in its colour, so you can see where you are even zoomed all the way out.",
                "Small nodes look like little sockets, notables and passives sit in a frame of their colour, Expertise nodes are diamonds, and the path you've taken glows.",
                "The side panel is easier to read: your class at the top, then each bonus on its own row with the number on the right. Gun-type bonuses have their own heading.",
            } },
            { Head = "Unlocks", Lines = {
                "The Week's Quarry now opens at level 22 instead of 18, so level 18 isn't four new things at once.",
            } },
            { Head = "Loot goblins", Lines = {
                "Loot goblins are rare now: about 1 room in 100, instead of roughly 1 in 7.",
                "Catching one always gives at least a LEGENDARY item, whatever the difficulty. Very rarely it's better: 1 in 50 goes one rarity higher, and each step after that is 50 times rarer again (only up to your difficulty's top rarity). Loot luck doesn't change any of this. The rest of its jackpot (more items, a gem, materials, gold) stays.",
                "Treasure Hunt no longer shows up as a floor modifier or a path choice. The daily and weekly goblin jobs are gone, and the season goal is now to catch one.",
            } },
            { Head = "Shots look instant", Lines = {
                "Every gun hits the moment you fire, and now it looks that way: the tracer appears all at once from your gun to where the shot landed, then fades. No more streak flying out like a bullet. This covers every skin's tracer too.",
            } },
            { Head = "Class balance", Lines = {
                "Re-measured on the new tree with Expertise, so every class kills at about the same pace at every level (within about 10%).",
                "Marksman: class guns deal 15% less damage up to level 100, then up to 49% less at level 400. Without the old limits, stacking crits and headshots made it about twice as fast as the other classes.",
                "Breacher: shotguns deal 4-20% more damage up to level 100, rising to 77% more at level 400.",
                "Arcwright: beam guns deal about the same up to level 100, rising to 38% more at level 400.",
                "Gunslinger: within 5% either way up to level 150, then 15% less at 200 and up to 27% less at 400.",
                "Vanguard: 12-17% less from level 50 to 300, 5% less at 400.",
                "Enemies follow your new strength, so kills take as long as before: 10-20% more health up to level 100, about the same at 150, 10% less at 200, about half at 300 and 60% less at 400.",
                "Enemies hit softer as your health from the tree is lower now: about 20% less at level 50, 35-45% less from level 100 to 300, about half at 400. You can take as many hits as before.",
            } },
            { Head = "Fixes", Lines = {
                "Small fixes.",
                "Joining a party in another server: a slow or busy moment can no longer show an empty Party Finder, and you can't start a second move while the first is on its way.",
                "Profiles of players who are offline now show their gun, and opening many profiles quickly no longer slows the server.",
                "After the wipe, a busy moment on Roblox's save servers can no longer skip carrying over your bought cosmetics and BOUND points: the load waits and tries again.",
            } },
        },
    },
    {
        Id = 119, Version = "0.99t", Date = "Oct 20, 2026", Title = "FIND YOUR SQUAD",
        Sections = {
            { Head = "The side buttons are one MENU now", Lines = {
                "The column of icons on the left is gone. One MENU button opens a window with every one of them, each with its name, its key and a line on what it does. No more hovering to find the right one.",
                "Press L to open it (change the key in Settings > Controls). Esc, X or L again closes it. Every window's own key still works as before.",
                "In a run it only lists what a run allows: inventory, skill tree, cosmetics, store and settings.",
                "A red dot on MENU means LOST LOOT has drops waiting to be bought back.",
            } },
            { Head = "Party Finder", Lines = {
                "MENU > PARTY FINDER lists every open party in every server: what they're playing, the host's level, bot skill, how full it is and how busy their server is.",
                "JOIN puts you straight into a party in your server. A party in another server takes you to that server and into the party.",
                "Make a PUBLIC room in the Dungeons window and players everywhere can find it. The Dungeons window has an ALL SERVERS button next to the room list.",
                "Filters: dungeons, Endless, boss trials, and only the difficulties you've unlocked.",
            } },
            { Head = "Invite friends", Lines = {
                "MENU > INVITE FRIENDS opens Roblox's invite window. When a friend who's new to Aimbound joins from your invite and gets going, you BOTH get 50 BOUND points.",
                "Getting going means level 20 with 2 hours of play on 2 different days. Their Roblox account must be at least 30 days old and on your friends list.",
                "You're paid for up to 10 friends. Titles at 1, 3 and 10 friends: Recruiter, Squad Leader, Commander.",
                "The window shows the friends you invited and, if someone invited you, your progress toward the gift.",
            } },
            { Head = "Profiles", Lines = {
                "MENU > PROFILES shows your AIM PROFILE: accuracy, weak-spot hits and kills, K/D, best headshot streak, Aim Trial bests, numbers for every gun you've run with, and a chart of your last 20 runs.",
                "See where your accuracy stands against everyone in your server.",
                "Click any player in the city to open their profile: their gun, gear and melee (hover for the full item card), build, cosmetics and aim. The Hall of Aim statues open theirs too.",
            } },
            { Head = "Skill tree numbers at your level", Lines = {
                "Every number in the skill tree now shows what it really adds at your level: node tooltips, the path you're hovering and the totals on the right.",
                "Stats stack toward a ceiling that rises with your level. When a number is trimmed by it, the full value is shown next to it as \"uncapped\", and more of it counts as you level up.",
            } },
            { Head = "Ceiling notables", Lines = {
                "10 new notables, two in each class's part of the tree, raise one stat's ceiling by 25%: Damage, Max Health, Crit Chance, Crit Damage, Weak-Spot Damage, Armor and Ailment Power.",
                "They sit off the beaten path, so a build that stacks one stat has to go out of its way for them.",
                "Only one of each ceiling counts: a second Damage Ceiling notable adds nothing.",
                "Hover one to see what it would add to your build right now.",
            } },
            { Head = "Fixes", Lines = {
                "Closing the City Quarters window (the leaders in the plaza), the Crew window or the Exchange with X no longer leaves your camera stuck.",
            } },
        },
    },
    {
        Id = 118, Version = "0.99s", Date = "Oct 20, 2026", Title = "LAUNCH PREP",
        Sections = {
            { Head = "A fresh start", Lines = {
                "Update 7 changed how every item rolls, so everyone starts over: levels, gear, gold, currencies and the leaderboards are fresh.",
                "Everything you bought stays: cosmetics and their copies, BOUND points, colourways, stash tabs (now empty), hideout themes, expansions and the map room, and this season's premium pass.",
            } },
            { Head = "Everything costs BOUND points", Lines = {
                "Stash tabs, hideout expansions, the map room, premium hideout pieces and themes, revives, buying back lost gear, the Rebirth Shard and the premium season pass are all bought with BOUND points now.",
                "Every purchase opens one window first: what it is, its price, how many BOUND points you have and how many more you'd need. GET BOUND opens the point packs right there.",
                "The premium season pass can also be bought straight for R$ 499: BUY WITH ROBUX in the same window.",
                "Hideout expansions (which add stash room) are BOUND points only, with no level needed. The one trade tab for 1,000,000 gold is gone; a tab already bought with gold stays.",
            } },
            { Head = "A tidier plaza", Lines = {
                "The leaderboard walls hold five boards each: HIGHEST LEVEL, both MAPS boards, the DAILY CHALLENGE and THE GAUNTLET RUN on the west wall; all four AIM TRIALS and the RECENT BIG DROPS on the east wall.",
                "The big-drops board and the Exchange board no longer stand in the street: the drops are on the leaderboard wall, the Exchange is the market stall on the east side.",
                "The HALL OF AIM statues and two quarter leaders stand against the wall between the gates, out of your way; Juno Vale waits at the market stall across from the Exchange.",
            } },
        },
    },
    {
        Id = 117, Version = "0.99r", Date = "Oct 20, 2026", Title = "DEPTH: THE ENDGAME",
        Sections = {
            { Head = "Drop rules", Lines = {
                "Settings > Gameplay > Loot Lens: hide drops you don't want, or make the ones you do GLOW (a gold outline, a taller beam, a sound), by kind, rarity and words in the item (\"weak-spot\", \"AK\", \"ring\"...).",
                "The first rule that matches a drop wins. Hidden drops can still be picked up; relics are never hidden. 4 rules to start, more with Marksman Grades 4, 11 and 17.",
            } },
            { Head = "City quarters + a living hub", Lines = {
                "Three quarter leaders now stand in the plaza: ILSA WICK of LANTERN ROW (precision) and OLD BRANN of IRON STAIR (survival) by the wall between the gates, JUNO VALE of the WIRE MARKET (tempo) at the market stall across from the Exchange. From level 65, talk to one.",
                "Each quarter gives you two bounties a day (they count from any run). Finishing one pays STANDING with that quarter, but costs half as much with its rival.",
                "Standing raises your rank (Stranger to Legend) and buys things at the quarter's stall: its crafting currency, maps, Wildfire Cores, and two show-off titles.",
                "Between the gates stands the HALL OF AIM (statues of the three highest-level players, cast from their own avatars), and the leaderboard wall now has a board of this server's latest big drops.",
            } },
            { Head = "Crews (level 20)", Lines = {
                "A new CREW tile: found a crew (250,000 gold, a name and a 2-4 letter tag) or ask to join one by its name. Officers can invite players in your server and let requests in, even while you're offline.",
                "Members share the tag on their name tags and a gold BANK anyone can donate to. The leader and officers spend it on RESEARCH that helps every member: +bag slots, +Exchange listings, +Job Board rerolls, +Season XP and new tag colours.",
            } },
            { Head = "The Exchange (level 30)", Lines = {
                "Buy and sell with every player, even when they're offline. Open it at the EXCHANGE stall in the plaza or with the EXCHANGE button in your stash.",
                "SELL: put guns or gear in a TRADE tab of your stash (or pick a Gunwright), set a price in gold, Prism or any crafting currency, and LIST it. The item leaves your tab while it's listed.",
                "BROWSE: filter by kind, rarity, currency and words, cheapest or newest first. A sale can only ever go to one buyer.",
                "MY LISTINGS: cancel a listing, or COLLECT what you've sold (a 10% tax comes off; Marksman Grades 13 and 19 lower it and add 2 listings each). You can have 10 listings at a time.",
            } },
            { Head = "Zeroing you can see", Lines = {
                "A zeroed gun now shows it: one glowing notch on the receiver per tier you've claimed (an underline at tier V).",
            } },
            { Head = "Special stash tabs", Lines = {
                "GEM tab (+50 gem bag room) and MAP tab (+30 map room), 99 BOUND points each, up to 5 of each. Buy them with + TAB in your stash.",
            } },
            { Head = "Season Feats", Lines = {
                "A new Challenges tab, FEATS: 30 big feats for Season 1 across the whole game (kills, floors, encounters, maps, the Summit, quarters, Gunwrights, zeroing...), counted from every run.",
                "Every 10 you finish pays a season title, BOUND points and gold (300 / 500 / 1000 BOUND, 50K / 150K / 400K gold). They reset with the season.",
            } },
            { Head = "Split the Haul (level 80, parties)", Lines = {
                "HAUL TAGS drop from elites (rare) and bosses. When your PARTY kills a boss, every member carrying a tag spends one.",
                "Each tag adds two items (one step under the floor's top rarity) to one shared chest, and everyone who spent a tag picks one: first come, first served, 40 seconds. Four tags = eight items to choose from.",
            } },
            { Head = "World alerts", Lines = {
                "Every two hours (at a quarter past every even hour, UTC) a 45-minute CITY BROADCAST runs in every server at once, with a banner at the top and a 10-minute heads-up:",
                "RELIC SURGE double boss relic chance  •  ENCOUNTER RUSH an encounter on every floor that can have one  •  WORLD SURGE one world pays +50% loot luck and +25% rewards  •  ELITE HUNT 50% more elites paying double  •  CURRENCY RAIN double encounter currency and Wildfire Cores  •  MANHUNT your Marked Man on every floor it can.",
            } },
            { Head = "The Gauntlet Run (level 100)", Lines = {
                "A new Challenges tab: three harsh floors (two tough modifiers each, floor 3 a boss), the same for everyone today, on the hardest difficulty you've unlocked.",
                "ONE try a day: dying or leaving spends it. A clear pays gold, Prism, crafting currencies, Sigil Marks and two top-rarity items (sometimes a relic), and goes on today's board.",
            } },
            { Head = "Sigil Marks (level 100)", Lines = {
                "Map guardians drop five kinds of Sigil Mark. Draw up to two different ones onto a map at your map device before you open it:",
                "PLENTY +25% item quantity  •  THE PACK more elites (+10% quantity)  •  GREED a loot goblin on more floors  •  ECHOES an encounter on every floor from 2 to 4  •  THE COMPASS the guardian always drops a Bearing.",
            } },
            { Head = "The Summit (level 125)", Lines = {
                "Map guardians now drop BEARINGS: North, East, South and West. With one of each, press CLIMB THE SUMMIT at your map device.",
                "The Summit is a major boss at the hardest tier your level reaches, with 120% more health, 25% harder hits and a faster pace. It pays a big stack: gold, Prism, Blackflux, top-rarity items, a 25% relic chance and the SUMMIT BREAKER title the first time.",
                "From level 158: the UBER SUMMIT (two of each Bearing): 250% more health, 50% harder hits, an enrage at 5 minutes, and double the reward.",
            } },
            { Head = "Redline (level 125)", Lines = {
                "A new currency, BLACKFLUX, from map guardians and the Summit. At the Forge, REDLINE a Legendary-or-better item:",
                "30% nothing, 30% a bonus line past the item's limit at its top tier, 25% a full reroll, 15% one good line turns bad. Either way the item is then LOCKED: no crafting can change it again.",
            } },
        },
    },
    {
        Id = 116, Version = "0.99q", Date = "Oct 20, 2026", Title = "DEPTH: ENCOUNTERS, STASH, GUNWRIGHTS, MARKED MEN + ZEROING",
        Sections = {
            { Head = "Three new floor encounters", Lines = {
                "Like the Tumbler, they can turn up on any normal floor from floor 2, each built around one aim skill and paying its own crafting currency:",
                "THE RUNNER (level 18, tracking): call the mark at the WANTED board and land enough hits as it sprints and jukes round the room before it escapes (20 s). Pays Rivets.",
                "THE BREACH (level 30, flicking): open the breach and targets spill out one after another, vanishing fast. Every kill in 20 seconds raises the payout. Pays Scrapes.",
                "MIRROR MATCH (level 45, dodge and hit): your echo strafes and throws cyan strikes at you. Land enough hits without being hit once (30 s). Pays Hones.",
                "Finish the mark or the echo in under half the time for a bonus item and currency. Slow guns' hits count for more, so every class can do them.",
                "New weekly bounties for each encounter, and the level-up cards explain each one when it unlocks.",
            } },
            { Head = "Gunwrights (level 45)", Lines = {
                "A new drop from bosses and elites (and the Week's Quarry stack): a mod for ONE gun, with 2 or 3 random lines (sometimes a penalty line too).",
                "Fit it on a gun of that model in the inventory's ITEMS tab and its lines count like the gun's own affixes. Fitting another swaps the old one back into your Gunwright bag.",
                "REROLL a Gunwright's lines with Tuning Grit (a new currency; it costs a little more each time), or SALVAGE one for grit. Your class's guns come up more often.",
            } },
            { Head = "Marked Man (level 80)", Lines = {
                "Each week a named elite is marked on you and can show up on your normal floors, with a gold skull and its name. It doesn't count toward clearing the floor.",
                "Once you hit it you have 6 seconds to finish it. If it gets away (or you clear the floor around it) it comes back tougher and its gun gets better.",
                "Bring it down for its gun and a pile of gold. A new Marked Man every Monday.",
                "Gunwrights can be traded now.",
            } },
            { Head = "Zeroing (level 65)", Lines = {
                "Every gun now has 5 zeroing tiers, earned by aim feats with that gun: weak-spot kills, weak-spot hits in a row, elite kills and hits in a row without a miss.",
                "Claim a tier for gold and a crafting currency, then pick one of its two perks (moving or planted, long or close range, ...). You can switch a pick later for a little gold.",
                "Find it on the gun cards in Challenges > MASTERY.",
            } },
            { Head = "Hallmarks (level 125)", Lines = {
                "Now and then (2% of item drops) an item comes with one line HALLMARKED into the metal, marked ◈ in its tooltip.",
                "Nothing changes a hallmark: REROLL VALUES keeps its number, Scrape and Hone skip it, a Wildfire Core rerolls everything else around it, and a hallmarked gun can't be rerolled into another gun.",
            } },
            { Head = "Fixed", Lines = {
                "REROLL VALUES (Prism) on gear ignored a line's tier and the item's level, so high-tier gear lines could reroll far lower. They now reroll inside their own tier.",
            } },
            { Head = "Stash tabs (your hideout stash)", Lines = {
                "Your stash now has tabs along the top: your old STASH (everything in it stays, expansions included), a free TRADE tab and a SKINS tab that lists every tradeable skin you own and how many copies.",
                "+ TAB buys more: a general tab (100 items) or a trade tab for 49 BOUND points. STASH on a bag item stores it in the tab you have open.",
                "Trade tabs are where you'll list items when the Exchange opens; until then they're storage. Gem and map tabs come with the Exchange.",
            } },
        },
    },
    {
        Id = 115, Version = "0.99p", Date = "Oct 19, 2026", Title = "DEPTH: THE WEEK, MARKSMAN GRADE + THE LEDGER",
        Sections = {
            { Head = "The Week's Quarry (from level 18)", Lines = {
                "Every week one Boss Trial boss is THIS WEEK'S BOSS, with a twist: more health, faster attacks, harder hits or an early enrage. You fight it at the tier your level reaches.",
                "Its first clear each week pays a big stack: gold, Prism, 2 of every crafting currency you've unlocked and an item of the tier's top two rarities, on top of the normal trial rewards.",
                "Find it in the Challenges window, new WEEKLY tab. Solo or with your party.",
            } },
            { Head = "The Job Board (from level 12)", Lines = {
                "Five big jobs a week (defeat enemies, clear floors, crack Tumblers, beat Boss Trials...). The same things count as for your daily contracts.",
                "Each one pays gold, Prism and a crafting currency; all five pay a bonus with an item. One reroll a week for a job you don't like.",
            } },
            { Head = "Marksman Grade (exams from level 15)", Lines = {
                "Every mastery level on every gun is a point. Points open the next grade; pass its aim exam (an Aim Trial at a set rank, any difficulty, no timer, retry as often as you like) to take it.",
                "Grades give bag slots (up to +50), extra Job Board rerolls, extra daily contracts, an early look at next week's Quarry, your grade emblem on your name tag and four show-off titles. Never damage.",
                "Challenges window, MASTERY tab.",
            } },
            { Head = "The Ledger (Index window, new LEDGER tab)", Lines = {
                "A collection log: every rarity, every relic, every Boss Trial boss at every tier, every world and every gun you've found or beaten.",
                "Each page pays gold, Prism and crafting currencies at its milestones, automatically. What you already own counts, so most players get a payout right away. Your first item of a new rarity (Epic and up) gets its own announcement.",
            } },
            { Head = "New things explain themselves", Lines = {
                "When your level opens something new (Tumblers, the Job Board, Marksman Grade, new currencies, the Week's Quarry) a short card tells you what it is, the next time you're in the hub.",
            } },
        },
    },
    {
        Id = 114, Version = "0.99o", Date = "Oct 18, 2026", Title = "DEPTH PREVIEW: CRAFTING + TUMBLER",
        Sections = {
            { Head = "New crafting currencies", Lines = {
                "Each one does ONE random job, so a perfect item is still something you hunt for:",
                "TURNCOAT (level 18): REROLL GUN at the Forge. RIVET (18): adds one random line to an item with room for it (it can be a penalty line). SCRAPE (30): removes one random line. HONE (45): raises one random line one tier, up to what the item's level allows. WILDFIRE CORE (45): rerolls everything, how many lines and which ones.",
                "Prism Shards now REROLL VALUES: the same lines and tiers, new numbers inside each tier.",
                "Currencies show in the Forge and your bag from the level they unlock. Wildfire Cores drop from bosses; the free daily roll adds one of your unlocked currencies (2 from level 100).",
            } },
            { Head = "Tumbler (new floor encounter, from level 8)", Lines = {
                "Some floors have a steel vault by the entrance. PICK THE LOCK and hit each moving pin on its door. A missed shot or a pin you let slip resets the lock; you have 30 seconds.",
                "Cracked: items with better odds, gold and Turncoats. Crack it with no resets for a bonus item and more.",
                "This is the first of four encounters. Tell us how it feels!",
            } },
        },
    },
    {
        Id = 113, Version = "0.99n", Date = "Oct 18, 2026", Title = "PLAYTEST FIXES",
        Sections = {
            { Head = "Runs", Lines = {
                "Fewer bosses: a run now has at most ONE boss mid-run plus the final boss (Brutal 3 + 6, Nightmare / Torment 4 + 8, Cataclysm and up 5 + 10, Veteran only the floor 5 boss). Most floors are normal fights again.",
            } },
            { Head = "Rarity rework", Lines = {
                "Every rarity now has ONE set of odds for the whole game. A Legendary is a Legendary on every difficulty: harder difficulties only nudge the rare ones up a little and still unlock a new top rarity.",
                "Your level no longer raises your drop luck. Where you play decides your loot.",
                "Rough odds: Rare 1 in 10, Legendary about 1 in 140, Mythic about 1 in 1,600. Rarity 15 (Infinite) is meant to take hundreds of hours even on Singularity.",
                "Rarity now decides how many affix lines an item gets: Common 0, Uncommon and Rare 1-2, Epic 3-4, Legendary and up 4-6 (the higher the rarity, the more often 5 or 6). Legendary is the everyday workhorse; a great Legendary can beat a weak rarity-12 item.",
                "Item level decides how high affix tiers can go: T1-T5 anywhere, T6 and up only from higher content, T15 only at the very top. Old items keep every line they have.",
                "A line that rolled at the very top of its tier's range shows a star in the tooltip.",
                "Enemies from level 100 up are tuned down to match the gear you will actually have now.",
                "Rewards that promise a rarity (\"an Epic item\") now always give at least that rarity. Drop sounds and the global drop feed follow how rare a drop really is.",
            } },
            { Head = "Forge", Lines = {
                "The free daily roll now also gives a guaranteed stack of Prism Shards that grows with your level (about 10 at level 1, 50 at level 100). One roll in ten is a TRIPLE stack.",
                "NEW: REROLL GUN. A Rare or better weapon that isn't for your class can become a random gun of YOUR class, keeping its rarity, item level and unique power, with new affixes (upgrades reset). Costs a Turncoat and gold (since 0.99o).",
            } },
            { Head = "Combat", Lines = {
                "Enemy and boss attack areas glow less: dimmer colours, a thinner edge and a softer flash when they strike. Same shapes and timing.",
                "The Cryo boss arena is no longer blindingly bright.",
                "Enemies no longer push into walls, ramps, props or shrines: they slide along them instead.",
            } },
            { Head = "Boss targets", Lines = {
                "The green targets in boss fights have a health bar and show your hits as damage numbers.",
                "They break much faster: about 7-10 rifle shots each (1-2 for a sniper), and the tracking target no longer needs a whole magazine. Every gun still needs about the same time on target.",
                "Target rounds come about half as often, and the targets float at eye level around the boss instead of overhead, so you can still see the attacks on the floor.",
            } },
            { Head = "Fairer attacks", Lines = {
                "ROULETTE (the pie-wheel attack): the safe part is now two wedges, marked GREEN, always near you. The other wedges strike in two waves with more warning.",
                "The four-slice floor attack gives 50% more time to step into the safe slices.",
                "The Shogun of Petals: every attack can be walked out of now. Fewer and slower blade lanes, petals give time to step off, smaller floor tiles with more time to switch, and a longer pause between moves.",
            } },
            { Head = "Inspect", Lines = {
                "Inspecting only works in first person. An inspect still playing stops when the camera pulls back to third person.",
            } },
            { Head = "Settings", Lines = {
                "Damage Numbers has a new choice: BOSS FIGHTS ONLY.",
            } },
        },
    },
    {
        Id = 112, Version = "0.99m", Date = "Oct 15, 2026", Title = "STORE TIDY",
        Sections = {
            { Head = "Store", Lines = {
                "The HIDEOUT tab is no longer hidden under the search box: the search box sits next to the category title now.",
                "Every stash and portal skin has a real picture in the store, portals shown open.",
            } },
            { Head = "UI themes", Lines = {
                "UI themes no longer play an effect when a window opens. Their look stays the same; new opening effects will come in a later update.",
            } },
            { Head = "Duels", Lines = {
                "Duel movement is slower: you run about 40% slower (it still starts, stops and turns as sharply as before), so fights come down to tracking. Strafe-jumping builds less speed and the dash is shorter with a 6 second recharge.",
                "Duels are CLASSIC only now (Gun Rotation and Instagib are gone).",
                "Fixed: players could get stuck looking crouched to everyone else after tabbing out (or opening chat) while holding crouch.",
                "NEW: one ability each, picked in the DUEL window and used with [F]: BLINK (12 studs the way you're moving, every 8 s), GUARD (60% less damage for 1.5 s, every 14 s) or PULSE (see your opponent through walls for 3 s, every 14 s). Your opponent is told when you use it.",
            } },
        },
    },
    {
        Id = 111, Version = "0.99l", Date = "Oct 14, 2026", Title = "SWAP SHOP",
        Sections = {
            { Head = "Trade skins", Lines = {
                "Skins can be traded now: gun skins, melee skins, arms, health bars, UI themes and kill effects, including the season pass rewards.",
                "Own more than one: buy a skin or a bundle again for an extra copy. The store shows how many you own.",
                "Open a trade [Y] and switch your side to SKINS. Up to 8 skins a trade, next to your guns, gear, gold and BOUND points. Trade skins for gear, or give them away for nothing.",
                "Bundles trade piece by piece. Giving away your last copy of a skin you're wearing takes it off.",
                "Colourways, hideout looks and free skins stay with you.",
            } },
            { Head = "Fixes and balance", Lines = {
                "The boss on the last floor of a run has 30% less health.",
                "Enemy outlines no longer flicker off while you shoot them.",
                "Equip Best no longer refills your magazine.",
                "Arms you wear now stay on when you leave and come back (they were reset to the default on every join).",
                "A boss killed in the middle of charging an attack no longer leaves its glowing ball floating in the arena.",
            } },
            { Head = "Duels, remade", Lines = {
                "Three modes: CLASSIC (first to 5), GUN ROTATION (a new gun of another class after every frag, first to 4) and INSTAGIB (one hit kills, first to 10).",
                "Duelists are 20% smaller: tracking a strafing player takes real aim now.",
                "Dash (1 charge) and slide work in duels. You can jump once every 0.9 seconds, and shots fired in the air spread.",
                "Both arenas rebuilt on one flat floor: no catwalks, decks or roofs to stand on, and no waist-high cover to peek over. Towers, columns, the furnace and the containers are full height and only break line of sight.",
            } },
            { Head = "Gems", Lines = {
                "Socket up to 6 gems with a Legendary effect (was 2). The strongest effects (Resonant Prism, Hair Trigger, Crown of Notables) are rarer drops.",
                "Every socketed gem now shows what it gives you right now: how many nodes in its ring you have and the exact stats it adds. Picking a gem for a socket previews this for every gem in your bag.",
                "New SALVAGE GEMS UP TO button on the ITEMS tab: salvage every gem at or below a rarity in one go (socketed and locked gems are kept).",
            } },
        },
    },
    {
        Id = 110, Version = "0.99k", Date = "Oct 14, 2026", Title = "FINISHERS",
        Sections = {
            { Head = "Every bundle remade", Lines = {
                "All 17 bundles have a brand new kill effect, each its own idea: a manga freeze frame, a clock that stops time, a body frozen and shattered, a reactor meltdown, a honey pour, a silk cocoon and more.",
                "Kill effects are now bundle exclusive. The new KILL EFFECTS tab in the store shows them all.",
                "Every bundle's damage numbers have their own font and motion.",
                "Every bundle's UI theme has its own corners, details and opening animation. UI themes can be bought on their own.",
                "Health bars were redone: each bundle has its own fill and its own way of losing health (drain, shatter, burn or snap). The free bar got a cleaner look too.",
            } },
            { Head = "A better store", Lines = {
                "Every bundle has a new banner and card showing its guns and melee in the set's colours.",
                "Every gun, melee, arms, health bar, UI theme, kill effect and hideout theme has a new, clearly lit picture in the store.",
                "Bundle prices now show correctly (799, or 699 for two-gun sets).",
            } },
        },
    },
    {
        Id = 109, Version = "0.99j", Date = "Oct 14, 2026", Title = "PRICE DROP",
        Sections = {
            { Head = "Store", Lines = {
                "Every store item costs about half as many BOUND points: gun skins 199, melee skins 249, arms 249, health bars 79, kill effects 99, UI themes 149.",
                "Bundles are 799 (699 for two-gun sets), about 40% less than buying the pieces one by one.",
                "Hideout themes 399, stash and portal skins 199. Colourways stay 100 for the whole set.",
                "Bigger BOUND point packs give much bigger bonuses: up to +35% (13,500 points for R$ 9,999).",
            } },
        },
    },
    {
        Id = 108, Version = "0.99i", Date = "Oct 13, 2026", Title = "FINDING YOUR WAY",
        Sections = {
            { Head = "Tutorial", Lines = {
                "The hub tour now draws a trail of gold arrows on the ground to each stop: the Dungeon Rift, the Skill Tree, the Forge and the rest.",
                "Tutorial boxes are bigger on phones and easier to read.",
            } },
            { Head = "Phones and tablets", Lines = {
                "The column of side buttons is now one MENU button in the top left. Tap it for a big menu with every window; tap outside or X to close it.",
            } },
            { Head = "Characters", Lines = {
                "Other players' arms are back to their normal size.",
            } },
            { Head = "Boss challenges", Lines = {
                "The boss card no longer hides the party room buttons under SOLO and FASTEST CLEARS: the card scrolls when it's long.",
                "Leaderboard tabs show just the tier (I to X) instead of the full boss name squeezed into each tab, and the leaderboard fits on phones.",
                "The daily contracts box steps aside while a window is open.",
            } },
        },
    },
    {
        Id = 107, Version = "0.99h", Date = "Oct 13, 2026", Title = "BOSS MAKEOVER",
        Sections = {
            { Head = "Every boss rebuilt", Lines = {
                "All 34 bosses have a brand new look: minibosses, the Titan, every superboss, every world superboss, the trial and major bosses and the Ascendant.",
                "They are one family now, built like the pill bots: a smooth body, a glowing ring, floating weapons instead of limbs, and one big piece that says who each boss is.",
                "Each boss's head is tinted to match it but stands out from the body, so the weak spot is easy to find. It is still the only weak spot.",
                "Bosses keep a lighter outline, so their colours show at fighting range.",
                "Fights, attacks and mechanics are unchanged, and the new models are much lighter on your device.",
            } },
        },
    },
    {
        Id = 106, Version = "0.99g", Date = "Oct 13, 2026", Title = "PLAY ON YOUR PHONE",
        Sections = {
            { Head = "Menus on phones", Lines = {
                "Every window now fits a phone screen: menus open below the Roblox top bar, use the whole screen and are drawn bigger, so the text is readable and the buttons are easy to tap.",
                "Dungeons has its own phone layout: what to play, how to play and the START button always on screen, with the open rooms beside them.",
                "The inventory, skill tree, store, settings, season pass, challenges, forge, hideout, map device, map tree, duels, trade and the guide were rebuilt for small screens. Long lists scroll inside the window instead of the whole window moving.",
                "When a window has more below, a scroll bar and a MORE button show it, and a close button stays on screen while you scroll.",
                "Roblox's movement stick and jump button step aside while a menu is open, and close buttons are easier to hit.",
                "Settings sliders can be dragged, a tap on an item shows its details with your equipped item beside them, and hints that only showed when you pointed at something now show on a tap.",
                "Hideout build mode works by touch: tap to place or pick up, drag to turn the view, pinch to zoom, plus TURN, CANCEL and TAKE BACK buttons.",
                "The GUIDE, PATCH NOTES and CREDITS buttons and the side buttons moved out from under the Roblox top bar, and the side buttons are bigger.",
                "The victory banner, boon cards, loot card, out of lives screen and spectate bar are bigger on phones.",
            } },
            { Head = "Playing on phones", Lines = {
                "The tutorial works with touch controls: its cards no longer cover the fire buttons or stay up in a fight.",
                "New: Aim Assist (touch) in Settings > Gameplay, with Off, Slight (the default) or Normal. Your aim slows down a little over an enemy and eases toward its body while you drag or fire. Touch screens only, against bots only: never in duels or Aim Trials.",
                "A compact HUD on phones: the level, health and gun card take less room, the left FIRE button sits beside the side buttons, and the drop feed and the DPS panel moved off the touch buttons.",
            } },
        },
    },
    {
        Id = 105, Version = "0.99f", Date = "Oct 13, 2026", Title = "LAUNCH PREP",
        Sections = {
            { Head = "Progression", Lines = {
                "Paragon is gone. Your level is the whole story now: new level caps arrive with updates, along with new bosses, worlds, rarities and relics.",
                "At the level cap your XP bar reads MAX LEVEL. The TOP LEVELS leaderboard moved to the MASTERY tab in Challenges.",
            } },
            { Head = "Clearer words", Lines = {
                "Maps are called maps everywhere now: the map HUD, the map device, the hub leaderboards and item descriptions no longer say \"rift\". You open a map with a SIGIL at your hideout's map device.",
            } },
            { Head = "Fixes", Lines = {
                "The level 100 MAPS intro no longer stays on screen if you walk into a run or a duel without reading it: it comes back the next time you're in the hub.",
            } },
        },
    },
    {
        Id = 104, Version = "0.99e", Date = "Oct 13, 2026", Title = "UPDATE 6: FINISHING TOUCHES",
        Sections = {
            { Head = "Three new bundles in the Store", Lines = {
                "KIRAMEKI: USAS-12, PX4 Storm and Arc Projector in bold anime style, inked outlines, hot magenta and electric yellow with hand-lettered sound effects, plus the Kira Saber.",
                "ORBITER: P90, F2000 and Quadbeam built from real spacecraft hardware (gold foil, solar cells, a spinning reaction wheel), plus the Antenna Glaive.",
                "LEADLIGHT: 21E, SR9 and Helios Beam in see-through stained glass held in dark lead, plus the Lancet Sword.",
            } },
            { Head = "New players", Lines = {
                "A guided TUTORIAL: a short hands-on run (moving, shooting, weak spots, the EXPOSED mark, picking up and comparing guns, a boss with its shield round), then a walk through the hub and your hideout.",
                "Replay it any time from the GUIDE (PLAY TUTORIAL). Players who joined before get a one-time offer.",
                "Reaching level 100 now gives a short intro to MAPS.",
            } },
            { Head = "Season Pass", Lines = {
                "Every tier now has a reward, and the Premium row pays out BOUND points on every tier: 700 over the season, more than the pass costs.",
                "SEASON 1 CHAMPION REWARD: tier 50 of the Premium row is the TORCHBEARER set. Torchbearer Gauntlets (a living flame in a gold laurel crest that flares on every kill), Torchbearer Sleeves, and the Torchbearer Blade: a gold torch-cup dagger whose blade is real fire. You can see them in the Season Pass window from day one.",
                "Torchbearer Blade: the draw lights the torch and the fire climbs up the blade, every strike streams fire, and the inspect is a champion's salute. Three colourways: Champion (orange flame), Bluefire (blue flame) and Inferno (deep red flame). Season rewards are never sold in the store.",
                "The free row now also gives a few BOUND points (at tiers 10, 20, 30, 40 and 50).",
                "Season tiers take more XP as you climb: reaching tier 50 takes about 40 hours of play over the season.",
                "Leveling is a little slower: about 4 hours to level 50, 20 to level 100 and 200 to level 400.",
            } },
            { Head = "Hideouts", Lines = {
                "Starwhale Observatory is now an open deck under a brass dome, riding through deep space with nothing below but stars, nebulas, shooting stars and distant whales.",
                "Crystal Hollow's crystals are real quartz now: six-sided points with see-through bodies, a glowing core and a slow twinkle.",
            } },
            { Head = "Try before you buy", Lines = {
                "TRY IN FIRST PERSON now takes you to your own bright test range: soft, even studio light and three targets, so you see a set's real colours, tracers, kill effect and banner. When you leave, you're right back where you stood.",
            } },
            { Head = "Fixes", Lines = {
                "Long guns no longer stretch your left arm across the screen: your support hand now holds near the front of the receiver (just ahead of the magazine on most guns), and the arm comes up more steeply where a pump or ammo box is in the way. No gun shows more forearm than the AK-47 now.",
                "LMGs (PKM, M60, 21E, M249): your support hand now cradles the ammo box from below, close in, instead of reaching out along the barrel. The MP40 holds the magwell just behind its magazine.",
            } },
            { Head = "Skin reworks", Lines = {
                "BESPOKE: the Barber's Razor is now the Bespoke Stiletto: a slim engraved blade, an oxblood leather grip wound with brass wire, a polished brass guard and pommel, and its own draw, thrusts, heavy strike and inspect. If you owned the razor, you own the stiletto.",
                "FERROFLUX: the glossy rippled finish is gone. The guns, the Flux Scythe and the arms now have a clean satin finish with crisp light and shade.",
                "PERMAFROST: cleaner ice. Crisp frost-blue bands instead of the noisy shine, every part of the gun frozen over (no plain grey scope or grip left), even rows of ice teeth instead of random drips, and tidier frost gloves.",
                "KINTSUGI is in the Store: M60, P226 and Mk 11 truly shattered and mended in gold on both sides, broken shards over a gold heart, one missing shard floating on threads of molten gold, and a splintered gold crack running the whole gun. Inspect it and the gun breaks apart, then snaps back together. A kill knocks the pieces loose with a surge of gold.",
                "The Kintsugi Kunai's tip is broken off and floats on threads of molten gold; inspect it to break the blade apart and snap it back together. Glaze Gloves and Mended Sleeves wear shattered, gold-mended ceramic plates.",
                "Kunai inspects and draws are now one smooth motion (no stutter at the start or the end).",
            } },
        },
    },
    {
        Id = 103, Version = "0.99d", Date = "Oct 12, 2026", Title = "UPDATE 6",
        Sections = {
            { Head = "Hideouts", Lines = {
                "Starwhale Observatory: the whale no longer pokes through the floor. The deck now rides on a timber saddle strapped to its back, under a new deep-space sky with nebulas, a sea of drifting star gas below and a pod of whales swimming past.",
                "Crystal Hollow: every crystal now grows from rock (ledges, shore shelves, islands) instead of floating, and the lake is a dark, still pool that mirrors the crystals, with light rippling on the cave roof.",
                "Ember Forge: the lava lake, river and lavafalls use the same churning, flowing lava as the Molten biome.",
            } },
            { Head = "New hideout interactables", Lines = {
                "Title Wall: your titles by name on plaques, rarest first, with the one you wear on the banner. Now unlocks at 3 titles.",
                "Stats Board: your lifetime kills, weak-spot kills, deaths, runs, deepest floor and more, for visitors to read.",
                "Trophy Shelf: a cup for every boss trial you've cleared (bronze to platinum by tier), a crystal for every relic you own, and your best full clear.",
                "Weapon Rack: hang your three favourite guns in their skins. Inspect them, equip one, or swap what hangs there.",
                "Jukebox: pick your hideout's music. Everyone inside hears it, and anyone can mute it for themselves.",
                "Arcade Cabinet: AIM ARCADE, a 20 second flick game with a personal best. The screen shows the owner's high score.",
            } },
            { Head = "Fixes", Lines = {
                "Chargers no longer circle you at high speed: they stalk at a distance, wind up, dive straight through, then stop winded for a moment.",
                "Left arms are no longer stretched on long guns, and sleeves now cover the whole forearm you can see.",
                "The scythe, razor and butterfly knife no longer clip through your hands when drawn or inspected.",
                "TACTILE has a new Claret colourway, and the MP5 stock no longer flickers.",
                "Your UI theme now follows the colourway you picked for its set.",
                "Leaderboards refresh at a steadier pace, easing load on the server.",
            } },
        },
    },
    {
        Id = 102, Version = "0.99c", Date = "Oct 12, 2026", Title = "UPDATE 5: SKINS",
        Sections = {
            { Head = "Thirteen new bundles", Lines = {
                "Every gun in these bundles is fully remodelled, not repainted. Each bundle is a full set: gun skins, a melee, gloves and sleeves, a health bar, a UI theme, a kill effect, a kill banner and its own sounds, with three or four colourways.",
                "Buy a bundle or single pieces with Bound Points in the Store, and recolour the whole set in the Colourways window.",
            } },
            { Head = "The bundles", Lines = {
                "FERROFLUX: AK-47, G17 and Hyperion in living magnetic fluid that spikes with every shot, plus the Flux Scythe.",
                "INFRARED: M4A1, USP and M4 Super 90 that glow hotter the more you fire, plus the Thermal Knife.",
                "TOURBILLON: AWP and Rhino with a ticking watch movement on the side, plus the Escapement Balisong.",
                "BESPOKE: Desert Eagle, Double Barrel and M40 in quilted oxblood leather, engraved nickel and carved walnut, plus the Barber's Razor.",
                "TACTILE: MP5, TAR-21 and KSG as soft-touch design objects with a lit grille that shows your ammo, plus the Field Hatchet.",
                "CARAPACE: Vector, AUG and Spark Pistol in jewel-beetle shell, plus the Mandibles.",
                "IRONRUNE: 870 Pump, SCAR-H and SVD in forged iron and carved oak with glowing runes, plus the Bearded Axe.",
                "FISSION: AA-12, M249 and Ion Accelerator as portable reactors with a glowing porthole and a pressure gauge, plus the Control Rod.",
                "PERMAFROST: M82, PKM and MP40 carved out of glacier ice with a frost fern frozen inside, plus the Rime Sabre.",
                "SLIPSTREAM: Scout, MP7 and 416 in racing lacquer and carbon with a rev counter that redlines with your streak, plus the Pit Knuckle.",
                "NECTAR: Uzi, Galil and SKS in honey-lacquered wood and brass with a honey jar that is your magazine, plus the Honey Dipper.",
                "MARQUEE: PPSh-41 and 590 Pump as an art-deco picture palace with chasing marquee bulbs, plus the Cane Sword.",
                "SILKFANG: TEC-9, EMR and Void Rifle as spider-made weapons wound in silk, plus the Fang Karambit.",
            } },
            { Head = "More detail up close", Lines = {
                "Every bundle got a detail pass where you actually look in first person: panel lines, plates, louvres, checkering and engraving with real depth, and sharper edges on every surface.",
                "Gloves and sleeves are no longer one flat colour: leathers, fabrics and rubbers with real texture, seams, piping and cuff details.",
            } },
            { Head = "Fixes", Lines = {
                "Textured gloves and sleeves keep their true colour in warm biomes (they used to turn tan or peach in Molten).",
                "The Tourbillon AWP's watch sits flat on the gun again instead of tilting into it.",
            } },
        },
    },
    {
        Id = 101, Version = "0.99b", Date = "Oct 11, 2026", Title = "REMASTERED",
        Sections = {
            { Head = "The whole game, remastered", Lines = {
                "Every biome, all twelve worlds, the city, the hideouts, the skies and every surface got a full art pass: real scanned textures, real skies and real models in place of block-built props.",
                "It runs as lightly as before: models replaced dozens of parts each, and nothing new lights up the floor.",
            } },
            { Head = "Low graphics", Lines = {
                "NEW: Settings > Video > Graphics Quality. Low turns off shadows, bloom, sun rays and grass, thins out particles and hides far scenery, for older computers and phones. High is the full look.",
            } },
            { Head = "Surfaces and skies", Lines = {
                "Every ground, rock, sand, snow, ice, brick, concrete, wood and metal surface is a real scanned texture now, and natural ground no longer repeats in an obvious grid.",
                "All 19 biomes and the city have new skies made from real sky photographs, each painted for its world: an eruption over Molten, a halo round the sun in Cryo, a black hole in the Void, neon smog over Cyber, a rising moon over the Sakura Shrine and more.",
                "The lighting was checked in every biome and mood so your gun stays easy to see, even on the darkest floors.",
            } },
            { Head = "The original biomes", Lines = {
                "The safe room at the start of every floor is dug into the cliff now, with a solid roof: no more sky showing through it and no more flickering walls.",
                "Molten's lava is real molten rock: glowing pools, rivers and lavafalls under a cracked crust.",
                "Props are real models: basalt columns, fort ruins, kilns and fire pits in Molten, crystals, scanned rocks, power poles, rusted cars and sci-fi crates across the rest.",
                "Cover walls, pillars and raised decks are built in each biome's own style (stone walls with capstones, tech panels, timber), and party floors look as good as solo ones.",
                "New chests and portals: gilded chests on a glowing rune circle, and portals that open into a turning tunnel of light.",
            } },
            { Head = "The twelve worlds", Lines = {
                "Every prop in the newer worlds is a real model: temple ruins and idols, angels and tombs, cypress trees and shacks, pagodas and stone lanterns, airships and clock towers, reactors and more.",
                "Each world has real scenery out to the horizon and some life in the sky: bats, macaws, paper sky lanterns, jellyfish, a drifting cogwheel.",
                "Every world's boss stage piece rises clearly over the walls now.",
                "Tall pillars in the arenas belong to their world: a carved glyph pillar with a brazier in the Sun Empire, a stone lantern in the Sakura Shrine, a weeping angel in the Moonlit Spires, basalt columns in Molten and more. They play exactly as before.",
            } },
            { Head = "The city", Lines = {
                "Real building faces with windows on every side, a wet street that catches the neon, new gates, shopfronts full of goods and posters, a hologram over the plaza and a moodier night sky.",
                "The wall into the Training Grounds is a real building with a tunnel through it, and the Bazaar got the same treatment.",
            } },
            { Head = "Hideouts", Lines = {
                "Every hideout theme is rebuilt with real models: a living reef with fish, a manta and a turtle in the Deep Aquarium, a giant tree with butterflies and swallows at the Forest Cabin, a star-whale under the observatory, glowing crystals in the Hollow and a sleeping cat on the loft balcony.",
                "Every stash and portal style is a new model with its own life: a mimic that snaps, a ghost that drifts, gears that turn. The Forest Cabin and the duel arenas have real skies too.",
            } },
            { Head = "Beam guns", Lines = {
                "All seven beam guns are new models in one family look: dark gunmetal, copper wiring and one glowing energy core your skin colours.",
                "The beam now locks to your crosshair every frame instead of trailing behind it, and the PPSh-41's drum faces the right way.",
            } },
            { Head = "Melees and inspects", Lines = {
                "Melee weapons sit at the right edge of your screen now.",
                "Every melee type has its own draw, attacks and inspect (knife, karambit, sword, axe, mace, spear, scythe), plus new kunai, balisong, knuckle and dual-wield types ready for skins.",
                "A new default Combat Knife.",
                "Every gun has a proper inspect [T]: it shows one side, stands up in your hand to show the other, then settles back. Pump shotguns: your hand rides the pump.",
            } },
            { Head = "Credits", Lines = {
                "NEW: a CREDITS window lists the artists whose models, skies, textures and sounds are in the game. Open it from the hub corner, the guide or Settings > Interface.",
            } },
        },
    },
    {
        Id = 100, Version = "0.99", Date = "Oct 11, 2026", Title = "FERROFLUX",
        Sections = {
            { Head = "A new line of skins", Lines = {
                "The old skin sets are retired: they're gone from the store and the locker, and anything you had equipped from them is back to the default look.",
                "In their place comes a new line of bundles where every gun is fully remodelled, not just repainted. Each bundle is a full set: gun skins, a melee, arms (gloves and sleeves), a health bar, a UI theme, a kill effect and a kill banner.",
            } },
            { Head = "FERROFLUX bundle", Lines = {
                "Liquid metal on a leash: black magnetic fluid held in shape by glowing field coils. AK-47, G17 and the Hyperion beam gun, plus the Flux Scythe melee.",
                "The fluid is alive: spikes breathe at rest, surge with every shot and stand taller as your streak climbs. The AK's magazine spine counts your rounds; the G17 grows a spiked crest; the Hyperion's coils run on your charge.",
                "Shots fire a helix of field energy and land in a splash that stands up into spikes. Every kill PULLS the target into a spiked column of fluid that slumps into a puddle, with a spike banner next to your weapon card that counts your streak.",
                "Flux Grips + Flux Sleeves: a wet-look glove with a titanium knuckle plate and a fluid bead that bristles on kills.",
                "Four colourways: Magnet (magenta), Quicksilver (cyan), Magma (orange) and Venom (acid green).",
            } },
        },
    },
    {
        Id = 99, Version = "0.98", Date = "Oct 11, 2026", Title = "CLEAN LINES",
        Sections = {
            { Head = "A cleaner interface", Lines = {
                "Every window, the HUD and the text got a full pass: one set of text sizes, one spacing, one accent colour, and nothing smaller than a readable size anywhere.",
                "Gold now means one thing: the main action or what's selected. Tabs and chips light up gold when picked and stay neutral otherwise.",
                "Windows always sit above the HUD (the health bar used to draw over some of them), with a plain close button that turns red under your cursor.",
                "Numbers (health, ammo, currencies, stats) use a cleaner condensed number font.",
            } },
            { Head = "HUD", Lines = {
                "The bottom-left HUD is one tidy column: your level, health and weapon card line up at the same width.",
                "The weapon card shows the rarity shape and name, one line of stats and your ammo as a big number. Health and ammo say LOW when they run low, not just turn red.",
                "Your focus streak moved further below the crosshair so nothing sits on it.",
            } },
            { Head = "Your stats", Lines = {
                "NEW: a STATS tab in the inventory [TAB] (top right of the CHARACTER column): kills, weak-spot kills, deaths, kills per death, accuracy, runs, floors, your best streaks, duel record and time played.",
                "Weak-spot kills, deaths, accuracy, runs, floors and time played start counting from this update.",
            } },
            { Head = "Accessibility", Lines = {
                "Interface Scale (Settings > Interface) now goes from 90% to 130% and also sizes the boss banner and the trial and duel HUDs.",
                "Locked difficulties show a lock, and low health / low ammo say so in words, so nothing relies on colour alone.",
            } },
        },
    },
    {
        Id = 98, Version = "0.97", Date = "Oct 11, 2026", Title = "HARD CHOICES",
        Sections = {
            { Head = "Beam guns", Lines = {
                "All seven beam guns (Arc Projector, Helios Beam, Ion Accelerator, Quadbeam, Hyperion, Spark Pistol, Void Rifle) have brand new, fully detailed models in place of the old blocky builds.",
                "Each has its own energy cell that comes out on a reload. The Void Rifle keeps its glowing runes, and the rest wear the same painted look as every other gun.",
            } },
            { Head = "Crafting", Lines = {
                "Crafting no longer hands out perfect gear. The Forge does two things now: UPGRADE a weapon (more expensive than before) and REROLL ITS AFFIXES.",
                "Rerolls cost Prism Shards and gold, and every reroll of the same item costs more than the last. Affixes can't be locked.",
                "Rarity upgrades (Ascend), Purge, Augment, Imprint, power rerolls, prefix changes, Tune, the crafting bench and re-leveling are gone, along with their materials. Rewards that used to give them give Prism Shards instead.",
                "NEW: penalty affixes. Any affix roll has a small chance to land a red T-1 to T-5 penalty instead (less damage, slower reload, a smaller magazine...). It takes a normal affix slot, so every gun is a real choice.",
            } },
            { Head = "Drops", Lines = {
                "When anyone in the server finds a top-rarity drop for their difficulty (or a relic), it shows on the right of everyone's screen with the rarity and how rare it is (\"1 in 389 drops\"). Hold Alt and hover it to see the full stats.",
            } },
            { Head = "In a run", Lines = {
                "Inside dungeons, maps, trials and boss fights only the inventory, the cosmetics window (store and locker), the skill tree and settings open now.",
                "Damage numbers pop much less: a number that keeps counting up only nudges instead of bouncing every hit.",
            } },
            { Head = "Aim Trials", Lines = {
                "You're locked in place for the whole trial now: no walking, dashing or sliding to the side of the targets.",
                "Tracking is new: a ball floats through the air in front of you, curving smoothly in every direction and bouncing off the edges, instead of one bot strafing the same line.",
            } },
            { Head = "BOUND points store", Lines = {
                "Everything in the store (and the hideout's premium pieces, themes, expansions and map room) is now bought with BOUND points.",
                "BOUND points come in seven packs, from R$ 99 to R$ 9999. Bigger packs give more points per Robux (up to +15%). Click the BOUND POINTS chip in the store.",
                "Bundles cost about 999 BP and save around half compared to buying their pieces one by one. Colourways still need the whole set.",
                "BOUND points can be traded: there's a BP box next to gold in the trade window.",
                "Store cards are redone: every gun, melee and glove fills its card at a clean angle on a lit stage in its rarity colour, instead of a tiny model spinning in a black box.",
            } },
            { Head = "Arms", Lines = {
                "Gloves and sleeves are one cosmetic now: ARMS. Every set's gloves and sleeves come together as one matched piece, and the store has an ARMS tab instead of two.",
                "If you owned either the gloves or the sleeves of a set, you own its arms. Bundles include the arms.",
            } },
            { Head = "New bot look", Lines = {
                "Regular enemies and elites are now clean aim-trainer pills: a tall capsule with a round head on top (the head is still the weak spot). Small fliers are simple spheres with the weak spot dead centre on the side facing you.",
                "Every biome paints its bots in a colour picked to stand out against that biome's ground, walls and lights, and gives them one small touch of personality: vines in the jungle, frost in the ice, embers in the volcano, a light band in the cyber city and more.",
                "Bosses and minibosses keep their own models.",
            } },
            { Head = "Gun check", Lines = {
                "Every gun was tested: reloads (the magazine leaves and comes back exactly in place, or the hand loads shells / clips / a speed-loader), inspects and textures.",
                "The QuadBeam had no magazine, so its reload was only a moving hand. It now has a power cell that comes out and goes back in.",
            } },
            { Head = "Melees, held like they should be", Lines = {
                "Every knife, sword, karambit and axe is held the way premium shooters do it: low right, leaning across the screen with its flat side facing you, bigger and closer. Before, most blades pointed into the screen and looked like thin slivers.",
                "New draw (the weapon twirls into your hand) and a new inspect: it rises toward the centre, shows one face, flips over to show the other and flips back, without your fist moving.",
                "Blades are broader, with a polished bevel along the edge and a darker spine on both faces, and handles are faceted.",
            } },
            { Head = "Gun skins on the new models", Lines = {
                "Every gun skin now draws on the new detailed gun models (they were still on the old low-poly ones), painted in its set's colours with deep base colours and glowing accent lines along the panel seams. Each skin's effects and decorations come along.",
            } },
            { Head = "Combat Knife", Lines = {
                "The crowbar is retired. Everyone's melee is now a plain tactical Combat Knife (quick slashes, a committed stab) held and inspected like a CS knife. Melee skins work on it as before.",
            } },
        },
    },
    {
        Id = 97, Version = "0.96", Date = "Oct 10, 2026", Title = "PAINTED STEEL",
        Sections = {
            { Head = "One look for every gun", Lines = {
                "All 41 guns are repainted in the game's own style: clean slate gunmetal, steel, walnut wood and a few tan or olive parts, in flat colour bands with dark edges. No more grime, scratches or camo noise.",
                "The new detailed shapes stay, so guns still look sharp, but they now match your arms and the painted world instead of looking like photos.",
            } },
        },
    },
    {
        Id = 96, Version = "0.95", Date = "Oct 10, 2026", Title = "NEW STEEL",
        Sections = {
            { Head = "New gun models", Lines = {
                "Every gun in the game has a brand-new, detailed model: all rifles, SMGs, LMGs, shotguns, pistols, DMRs and snipers, 41 in all.",
                "Skins you own still show on the older models until their set is rebuilt.",
            } },
            { Head = "Brighter hub", Lines = {
                "The hub, the Bazaar and the training grounds are much brighter. It's still night and the neon still glows, but you can see the streets, and your gun no longer turns almost black in the shooting range.",
                "Your gun, melee, gloves and sleeves now read the light where you're standing and keep their real colours everywhere: no more green guns in the hub or in Void's entry rooms, no red guns in The Deep, and about the same brightness in every biome, mood and room. Future biomes get it automatically.",
                "The hub's spawn plaza is darker again (its streets, walls and shopfronts), while the neon, your character and your gear keep their full brightness. Your own gun, gloves and sleeves in third person get the same colour correction as in first person.",
            } },
            { Head = "Reloads", Lines = {
                "Pump and tube shotguns now load real shells by hand, the SKS loads a stripper clip, the double barrel takes two shells, and the revolver uses a speed-loader. Before, only your empty hand moved.",
                "The M249 actually swaps its ammo pouch now, magazines on the new models no longer show holes when you hold them, and short magazines and boxes are held from below instead of your hand sinking into them.",
            } },
        },
    },
    {
        Id = 95, Version = "0.94", Date = "Oct 10, 2026", Title = "DAYLIGHT",
        Sections = {
            { Head = "Lighting", Lines = {
                "Your gun, melee, gloves and sleeves now look like they do in daylight in every area: a molten floor no longer turns them orange, ice no longer turns them blue, and night areas no longer darken them.",
                "The whole game is a little brighter, with no extra neon.",
                "Fixed: after visiting an ice floor, the lighting could stop changing for the rest of the session.",
            } },
            { Head = "Starlight Idol, rebuilt (the first set of the cosmetic overhaul)", Lines = {
                "Midnight violet, polished silver and one star-gold glow. A silver crescent moon stands beside the gun, and a gold star orbits it, faster as your streak climbs and with a kick on every shot.",
                "Its own draw (gold ribbons unwind off the barrel while the moon whirls into place), inspect (the moon turns while a gold magic circle draws itself under the gun) and reload (the star drops into the magazine).",
                "Nothing sits on top of the gun any more, so your view past the sights is clear.",
                "New gloves: midnight satin with a small silver moon; a tiny gold star twinkles in it now and then. New sleeves: a fitted satin sleeve with a silver band and a ribbon bow. The Crescent Karambit matches the new colours.",
            } },
        },
    },
    {
        Id = 94, Version = "0.93", Date = "Oct 28, 2026", Title = "YOUR PACE",
        Sections = {
            { Head = "Melees", Lines = {
                "Ten set melees are real weapons now: Kitsune Tanto, Crescent Karambit (Starlight), Rock Candy Dagger (Sugar Rush), Nekomata Kukri (Neko Cafe), Kingyo Shamshir, Capsule Combat Knife (Gacha Pop), Nightwing Dagger (Yami Kawaii), Riptide Machete (Ramune Summer), Idol Tomahawk (Mecha Idol) and Briarthorn Sword (Fairy Bloom). The Dream Pillow stays.",
                "Every melee is held and swung by its type: knives like a classic shooter knife (flip-spin draw, fast slashes, the turn-it-over inspect), karambits spun round the finger ring, swords drawn up and saluted, axes and hammers held low on the haft and drawn over the shoulder.",
                "Melees sit lower and point forward, below the crosshair, and the handle is IN your fist now (it used to stick out in front of your hand). Karambits and knives are bigger in the hand.",
                "The karambit is held like it should be: reverse grip, the ring on top of your fist and the hooked blade coming out underneath. Axes and hammers stand upright with the head up. Blades show their flat side instead of a twisted edge, and every weapon type swings to match how it's held.",
                "Your fist now grips the handle and turns with it, so swings and inspects never pass through your hand. Axes face their edge forward. The karambit spins round its ring on the draw and inspect.",
            } },
            { Head = "Store + My Cosmetics", Lines = {
                "The store opens on the bundles: a featured bundle you can flip through with the arrows, then every bundle as a card. Open a bundle to see each piece, inspect it and buy it on its own or the whole set.",
                "Single items are one row of tabs (gun skins, melee, gloves, sleeves, health bars, UI themes, hideout) instead of a long side list.",
                "My Cosmetics is your loadout: every slot shows what you're wearing, and only what you own is listed (SHOW ALL lists the rest with where to get it).",
            } },
            { Head = "Colourways + BOUND points", Lines = {
                "Every skin set now comes in three colourways: the original and two new ones (Tempest: Crimson Storm / Toxic Storm, Solaris: Lunar / Crimson Eclipse, Kitsune: Night Fox / Sakura Fox, Abyssal: Blood Tide / Golden Reef, Neon: Toxic / Inferno Override, Ironclad: Arctic / Toxic Ops, Jade: Crimson / Azure Dynasty, Yami: Blood Moon / Toxic Cute, and two for each of the other bundles).",
                "A colourway recolours EVERYTHING in the set: the guns, the melee, gloves, sleeves, health bar, tracers, impacts, the kill effect and its banner.",
                "Open COLORWAYS on any piece of the set in Cosmetics: wear a colourway on just that piece, or on the whole set. On the bundle it recolours the whole set.",
                "A colourway costs 100 BOUND points and unlocks for the whole set. You need to own the full set first (its bundle, or every piece).",
                "BOUND points: 40 on Season Pass premium tiers 5, 15, 25, 35 and 45, or GET POINTS in the colourway window.",
            } },
            { Head = "Maps", Lines = {
                "The map device has a BOT SKILL row: keep each map's own rolled skill, or pick any skill from 1 to 10 for the maps you open.",
                "It works like the Dungeons window: faster bots pay more XP, gold and loot from kills (0.75x at skill 1 up to 2x at skill 10).",
                "Hunter's Pact on the map tree still makes every map skill 10.",
            } },
            { Head = "Bots", Lines = {
                "Tiny fliers (Hummingbirds, Sparks, Zippers, Comets, Crows and the like) no longer get as much faster above Cataclysm, and stop shrinking there. On Singularity they're about 15-35% slower than before (the zig-zagging and ricocheting ones the most).",
                "The erratic movers (zig-zags, ricochets, popcorn) no longer speed up again on the top difficulties.",
                "The Antipode no longer circles you: it sweeps an arc on its own side, much slower, and its flip lands on the other side of that arc instead of behind you.",
                "We measured every flying enemy in every biome. The ones that moved well above the rest are 10% slower: Ashwing, Spark, Cinder, Strafer, Hopper, Vinelash, Idolfly, Pollen Moth, Glow Eel, Koi Spirit, Xeno Larva, Repair Bot and Voodoo Doll.",
            } },
            { Head = "The Forge", Lines = {
                "Your materials sit in a grid at the top: icon, name and how many you have. Hover one to see what it's for.",
                "Every action is grouped (Improve it, Reroll it, Add or remove affixes, Unique power) and says in plain words what it does.",
                "Costs show as chips: how many it takes and how many you have, green when you have enough, red when you don't. If an action can't be used, it says why.",
                "Imprinting opens its own window: pick the weapon (each shows the power it has now), pick a power from your Codex (with what it does and which of your weapons already have it), check what it replaces and the cost, then confirm.",
            } },
            { Head = "Boss Trials", Lines = {
                "The Seraph Archon, Chronarch, Echo Warden and Forgeheart drop relics now, like the major bosses (their old glove drops are retired; anyone who has one keeps it).",
                "The boss card lists each boss's relics. Hover one to see what it is: its slot, its class and what it does.",
            } },
            { Head = "The Proving", Lines = {
                "The four trials now span the whole game: Trial I at level 35 (Nightmare), II at 100 (Ruin), III at 200 (Annihilation), IV at 305 (Singularity). The bosses fight at the pace of those difficulties and the rewards scale up with them.",
                "Points you already earned from trials stay yours.",
            } },
            { Head = "Aim Trials", Lines = {
                "Flick, Tracking and Target Switch use small hovering bots (body and head) that move like the dungeon bots, instead of balls sliding along a wall. Headshots count as weak-spot hits and pay a little more.",
                "Every hit plays your hit sound and shows the hitmarker, like in a dungeon.",
                "The trial guns fire faster (7 to 10 shots a second): fast clicks were being dropped, which felt like shots not registering.",
            } },
            { Head = "Titles", Lines = {
                "Titles for difficulties (clears, bosses, flawless floors, deathless runs) now only count what you do at a minimum bot skill for that difficulty: 4 up to Brutal, 6 for Nightmare to Oblivion, 7 for Ruin to Apocalypse, 8 above. Each title says what it needs.",
                "They also only count while you're not outlevelled for that difficulty: your level can be at most 10 above its highest monster level (Ruin: level 140). Out-gearing an old difficulty no longer earns its title; a harder one still counts.",
                "Titles you already claimed are yours to keep.",
                "TITLES has its own button on the side dock, and clicking the TITLE slot in your inventory opens them too.",
            } },
            { Head = "Getting started", Lines = {
                "No more class pick when you join. Open the skill tree when you're ready and press CHOOSE YOUR CLASS (the first pick is free).",
                "New key: P opens the skill tree from anywhere (rebind it in Settings > Controls).",
                "In a run only the stash and skill tree keys work, so a stray key press can't open a hub menu mid-fight.",
            } },
            { Head = "Bots, duels and gloves", Lines = {
                "Shroomlings, Hoppers, Seahorses, Hedgelings, Voodoo Dolls and Repair Bots hop lower and smoother, with fewer sudden direction changes.",
                "Duels: a big health bar sits over your health number. A hit drops it at once, a white chip shows how much you lost, and the damage pops beside it. No more red: the hit arc pointing at the shooter is white, and low health turns amber.",
                "Gloves in first person are slimmer, and with a sleeve on they now end at the wrist instead of stacking a second cuff over the sleeve.",
            } },
            { Head = "Less neon", Lines = {
                "Most glowing trims, signs and windows in the world (the city, biomes, enemies) are now solid painted colour, and the rest glow softer. Skins, gloves, sleeves, kill effects and hideout cosmetics keep their full design, just 15% softer. The same kind of piece always gets the same look, so there's variety without a patchy mix.",
                "Attack markers, weak points, lime targets and boss mechanic parts still glow so they stay easy to read.",
                "Settings > Video > Neon Glow: Full puts every glow back.",
            } },
            { Head = "Spectating", Lines = {
                "Fixed: watching a player's solo run showed an empty floor. The enemies now show up and move as they do for the player.",
            } },
            { Head = "Boss trophy titles", Lines = {
                "Nine rare titles that DROP: each Boss Trial boss has its own from tier VI up (Wingbreaker, Last Tick, Silencebringer, Quencher, Vaultbreaker, Brood Bane, Duelbreaker, House Breaker), and biome superbosses on Ruin or harder can drop Worldeater.",
                "They're among the strongest titles, and like every difficulty title they can't drop while you're outlevelled for the fight.",
            } },
            { Head = "Removed", Lines = {
                "Boss Blueprints are gone (the BLUEPRINTS tab and the fragment drops).",
            } },
        },
    },
    {
        Id = 93, Version = "0.92", Date = "Oct 28, 2026", Title = "NEW FACES",
        Sections = {
            { Head = "Map guardians", Lines = {
                "Every map now has its own guardian, picked from all eight trial and major bosses: the Archon, Chronarch, Echo Warden, Forgeheart, Lockwarden, Broodmother, Duelist and Fortune Engine. Before, every map in the same difficulty band had the same one.",
                "The map device shows each map's guardian before you open it, and the same map always keeps the same guardian. Its strength still follows the map's tier.",
            } },
        },
    },
    {
        Id = 92, Version = "0.91", Date = "Oct 28, 2026", Title = "FAIR SHOTS",
        Sections = {
            { Head = "Bosses", Lines = {
                "Every visible part of a boss now takes hits: armour, wings, robes, cannons, crowns, all of it. The head is still the only weak spot.",
                "Bosses have one outline round the whole body again (no more outlines on single parts).",
                "The wider bosses move and dodge faster (up to +20% for the widest), so their size doesn't make them free to hit.",
                "TARGET and WEAK POINT labels are white on a dark tag now, so you can read them over the bright orbs.",
            } },
            { Head = "Loot", Lines = {
                "No more guaranteed minimum rarities. Every drop can be any rarity the difficulty allows, from Common up to its top, and the top one is always a real chase.",
                "Bosses, superbosses, chests and rewards that used to promise a rarity now roll with much better odds instead.",
                "Better loot gets more common as you level up inside a difficulty: up to +60% luck by the time you reach the next one.",
            } },
        },
    },
    {
        Id = 91, Version = "0.90", Date = "Oct 28, 2026", Title = "PAINTED WORLD",
        Sections = {
            { Head = "A new look for everything", Lines = {
                "Every surface in the game has been repainted in one hand-painted style: rock, grass, soil, sand, snow, ice, wood, brick, concrete, metal plating and more, with bold shapes and dark ink lines like the icons and skies. No more default grass and mountains.",
                "It covers every biome and map, the city hub and its areas, the training grounds, every hideout and stash chest, and the boss arenas. Each biome keeps its own colours.",
                "Derelict Station, Neon Megacity, the Dreamscape, Brass Skyport and Spore World get their own painted surfaces too: hull plating, tech floors, swirled cloud-stone, airship canvas and spotted mushroom caps.",
                "The big props in the original biomes (pillars, arches, crystals, machines) were repainted to match.",
            } },
            { Head = "Leveling", Lines = {
                "Enemies give about 20% less XP, so levelling lands closer to the intended pace.",
            } },
        },
    },
    {
        Id = 90, Version = "0.89", Date = "Oct 27, 2026", Title = "NATIVES",
        Sections = {
            { Head = "Every new world has its own enemies", Lines = {
                "The twelve worlds from 0.87 no longer borrow: each has six enemies of its own (five types plus a specialist), with their own look, movement and attacks. 72 new enemies in all, every one in the bestiary.",
                "Sunken Temple: vinelashes, idol flies, dart frogs, pollen moths, totem imps, the Temple Guardian. Moonlit Spires: gargoyles, lantern wraiths, ravens, grave hounds, bell spirits, the Bishop. Sun Dunes: scarabs, bandage wisps, sand djinn, ibis sentries, sun disks, the Sun Priest.",
                "The Deep: anglerfish, mantas, pufferfish, seahorses, glow eels, the Siren. Sakura Shrine: oni masks, paper lanterns, koi spirits, ronin, petal sprites, the Temple Monk. Toxic Wastes: mutant flies, barrel bots, scrappers, gas bags, ghouls, the Hazmat Mech.",
                "Spore World: shroomlings, spore puffers, lantern caps, mycelids, spore bats, the Mother Cap. Brass Skyport: clock owls, gyrocopters, automatons, balloon mines, gearlings, the Dirigible. Autumn Highlands: scarecrows, leaf spirits, tawny owls, hedgelings, crows, the Stag Spirit.",
                "Derelict Station: maintenance drones, turret pods, crawlers, xeno larvae, repair bots, the Warden Unit. Sun Empire: quetzals, jaguar warriors, sun masks, jade skulls, hummingbirds, the High Priest. Haunted Bayou: will-o'-wisps, bog lurkers, firefly swarms, voodoo dolls, moss wraiths, the Swamp Witch.",
            } },
            { Head = "Twelve new superbosses", Lines = {
                "The Idol King, Count Noctis, Pharaoh Sunka, the Drowned Kraken, the Shogun of Petals, the Reclaimer, the Mycelium Heart, Admiral Cogsworth, the Harvest King, Warden-Prime, Tonatiuh's Avatar and Mama Bayou.",
                "Each has its own body, three phases of its own moves and the aim rounds every superboss has. They work in party runs too.",
            } },
            { Head = "Phones", Lines = {
                "On a phone, windows now fill the width of the screen with bigger, readable text and scroll with a swipe up or down when they are taller than the screen. They also cover the HUD while open.",
                "The side buttons wrap into two columns on short screens instead of running under the level card. The inventory says TAP instead of hover on touch screens.",
                "Fix: the Dungeons, Challenges, Settings, Forge and Store windows never shrank on small screens (laptops included). They fit now.",
            } },
            { Head = "Hideouts", Lines = {
                "Two new hideout themes. STARWHALE OBSERVATORY: a walnut-and-brass observatory under a glass vault, riding a star-whale through the night, with a turning orrery, a great telescope, a ringed planet and star jellies circling. CRYSTAL HOLLOW: a miners' lodge in a cavern of glowing crystal, with a mine cart rolling in and out of its shaft, a trestle over an underground lake, a waterfall and drifting spores.",
                "Four new stash chests: the Clockwork Strongbox (gears turning behind a porthole), the Geode Chest (split open on glowing crystal), the Astral Orrery (planets circling on its lid) and the Ghostlight Casket (green candles, grave mist and a small ghost).",
            } },
            { Head = "Also", Lines = {
                "Top difficulties: above Cataclysm the bots now run their movement patterns faster too (+5% a tier, Singularity +35%), not only their top speed. Before, most bots on Singularity moved about as fast as on Hard.",
                "The Derelict Station, Moonlit Spires and Haunted Bayou skies were showing as plain black. Their painted space and night skies show now.",
            } },
        },
    },
    {
        Id = 89, Version = "0.88", Date = "Oct 26, 2026", Title = "ALWAYS EXPOSED",
        Sections = {
            { Head = "Exposed bots", Lines = {
                "There is now always one EXPOSED bot (lime glow, +40% damage taken) while any regular bot is alive, in solo and party dungeons, maps and trials.",
                "It moves to a different bot every 4 seconds, and the moment you kill it the glow jumps straight to the next one. No more waiting for the next exposure.",
            } },
        },
    },
    {
        Id = 88, Version = "0.87", Date = "Oct 26, 2026", Title = "NEW WORLDS",
        Sections = {
            { Head = "Twelve new biomes", Lines = {
                "Runs now roll from 19 biomes. New: Sunken Temple, Moonlit Spires, Sun Dunes, The Deep, Sakura Shrine, Toxic Wastes, Spore World, Brass Skyport, Autumn Highlands, Derelict Station, Sun Empire and Haunted Bayou.",
                "Every one is its own place: its own painted sky, lighting and haze, three map layouts, cover pieces, a centrepiece round the plaza, a landmark on the horizon, life overhead (bats, butterflies, jellyfish, airships, falling petals and leaves, fireflies, wisps) and a boss stage.",
                "Each comes with its own moods too (Monsoon, Blood Moon, Sandstorm, Midnight Zone, Lantern Night, Acid Rain, Copper Sunset, First Frost, Red Alert, Witch Moon and more).",
            } },
            { Head = "Enemies", Lines = {
                "For now the new biomes borrow the enemies, element and superboss of a related biome (the jungle and the skyport fight like Stormspire, the deep sea and the shrine like the Dreamscape, and so on). Their own enemies and bosses come in later updates.",
            } },
            { Head = "Also", Lines = {
                "Maps and the Daily roll the new biomes too. The Dungeons window lists every biome (hover a swatch for its name).",
                "Procedural rooms no longer place cover inside the plaza centrepiece.",
            } },
        },
    },
    {
        Id = 87, Version = "0.86", Date = "Oct 25, 2026", Title = "NEVER THE SAME ROOM",
        Sections = {
            { Head = "Procedural rooms", Lines = {
                "Every combat room is now generated: six room shapes (open arena, long hall, corner bastions, raised terrace, canyon ridge, walled courtyard), mirrored or free layouts, and fresh cover every floor.",
                "Cover is built for aiming: walls stay below eye height so you shoot over them, tall blocks only stand out at the sides, and raised decks have ramps and a low parapet.",
                "The path from the entrance to the portals, the chest area and both doorways always stay clear, and every room is checked so nothing is sealed off.",
                "Maps keep their own room shape, but the cover and details change every floor.",
            } },
            { Head = "Biome moods", Lines = {
                "Every floor rolls a mood for its biome: Ashfall, Ember Dusk, Sulfur Haze, Aurora Night, Rose Dawn, Crimson Rift, Synthwave, Golden Break and more, each with its own light, haze, accent colours and ground tones.",
                "On top of the mood, every floor gets a small random shift in colour, haze and light, so no two floors look the same. The mood's name shows on the floor's title card.",
            } },
            { Head = "Exotics", Lines = {
                "Relics now drop from every dungeon boss at a very low chance that rises a little with difficulty (mini-bosses 0.05%, bosses 0.12%, superbosses 0.3% on Easy, about double on the top tier).",
                "The full chance applies on your highest unlocked difficulty and the one below it. Each tier lower quarters it, so farming easy tiers for relics isn't worth it, but helping a friend still can pay.",
                "Boss Trial relics are now 1% at tier I, up to 3.25% at tier X (first clears of I, V and X still guarantee one). Map relics: 0.4% to 1.5% by tier, doubled on Unique maps.",
            } },
        },
    },
    {
        Id = 86, Version = "0.85", Date = "Oct 24, 2026", Title = "TRUE TARGETS",
        Sections = {
            { Head = "Enemy outlines", Lines = {
                "Outlines and body tint now only show on the parts you can actually hit. Bosses no longer light up their armour, limbs, weapons or decorations that shots pass through.",
            } },
            { Head = "Boss mechanics", Lines = {
                "Tracking rounds, orbs, satellites, relay targets, locks and other boss mechanic targets are now fair for every fire rate: every gun needs about the same time on target with perfect aim.",
                "Slow, heavy guns hit much harder on them: a sniper, launcher or a full shotgun blast one-shots satellites and relay targets, and fills a solo tracking target in one hit.",
                "Very fast guns (SMGs, beams, the minigun) no longer clear them faster than everything else.",
            } },
        },
    },
    {
        Id = 85, Version = "0.84", Date = "Oct 24, 2026", Title = "CLEAN WATCH",
        Sections = {
            { Head = "Spectating", Lines = {
                "While you spectate, your own HUD is hidden (it covered the STOP button), and you can't interact with anything: no prompts, no menus, no shift lock. Double tap J or press STOP to leave; Settings still opens.",
            } },
            { Head = "Gem auto-salvage", Lines = {
                "Gems now have their own auto-salvage on the ITEMS tab (where your gems are), completely separate from the guns + gear auto-sell. The ITEMS tab used to show the weapon setting, so picking a rarity there changed your weapons instead of your gems.",
                "The weapon setting is now labelled AUTO-SELL GUNS + GEAR, and the gem confirm explains that salvaged gems become materials.",
            } },
            { Head = "Inventory", Lines = {
                "A roomier inventory: the window can grow bigger on large screens, and the equipped column is wider.",
                "Bigger text everywhere: slot names and details, the stat sheet (now with alternating rows), bag rows and the sell buttons.",
                "Equipped slots show a rarity-coloured strip along the top.",
            } },
        },
    },
    {
        Id = 84, Version = "0.83", Date = "Oct 24, 2026", Title = "THROUGH THEIR EYES",
        Sections = {
            { Head = "Spectating", Lines = {
                "Spectating is now smooth and accurate: you see the player's exact camera (streamed about 30 times a second and smoothly played back), so every flick and tracking shot looks the way they aimed it.",
                "Enemies on a solo floor move exactly where the player saw them, and shots, hits and kills play at the same moment as the view.",
                "You see the game with THEIR settings: field of view (including their aim zoom), crosshair, damage numbers, hitmarker, hit / head / kill sounds, enemy outlines and tint, UI theme, health-bar style and kill effects. Your own settings come back when you stop.",
                "Their hits show as they saw them: the hitmarker, their hit sounds, the damage number and their kill effect.",
                "Duels: you now also see the opponent's shots.",
                "When someone is watching you, an eye shows on the right of your screen with how many are watching.",
            } },
        },
    },
    {
        Id = 83, Version = "0.82", Date = "Oct 23, 2026", Title = "STEADY TARGETS",
        Sections = {
            { Head = "Enemies", Lines = {
                "The HASTED elite modifier is gone: elites no longer roll it.",
                "Uplinks (the satellite bots) are much easier to shoot: their swing is smaller and slower (about 8 studs a second through the bottom instead of 19), it turns more gently, and their body and head are a bit bigger.",
            } },
        },
    },
    {
        Id = 82, Version = "0.81", Date = "Oct 23, 2026", Title = "EASY ON THE EYES",
        Sections = {
            { Head = "Visuals", Lines = {
                "The whole game is a bit less bright: less bloom (and only from the brightest lights), slightly lower exposure, softer reflections on metal and guns, and fainter sun rays.",
                "Every area keeps its own look; it's all just toned down together.",
            } },
        },
    },
    {
        Id = 81, Version = "0.80", Date = "Oct 23, 2026", Title = "WAY HOME",
        Sections = {
            { Head = "Back to the hub", Lines = {
                "Double tap J (rebindable: Settings > Controls > Back to Hub) to go straight back to the hub from anywhere: a run or map, an Aim Trial, a hideout, the Bazaar, the training grounds, while spectating, or a duel.",
                "One tap only shows a reminder, so you can't leave by accident.",
                "In a duel it counts as a forfeit, and you're back in the hub after the result screen.",
            } },
        },
    },
    {
        Id = 80, Version = "0.79", Date = "Oct 23, 2026", Title = "RINGSIDE",
        Sections = {
            { Head = "Spectate duels", Lines = {
                "You can now watch duels. Open SPECTATE in the city (duels are listed with the opponent, score and arena), or press WATCH next to a player who's in a duel in the DUEL window.",
                "You see the duel through that player's eyes, holding the duel gun in their skin, and both players' shots show.",
                "The bar at the bottom shows the score, time left (or SUDDEN DEATH), both players' health, the arena and the gun.",
                "Players who turned off Allow Spectators (Settings > Social) can't be watched, in runs or in duels.",
            } },
        },
    },
    {
        Id = 79, Version = "0.78", Date = "Oct 22, 2026", Title = "CLEAR SIGHT",
        Sections = {
            { Head = "Crosshair", Lines = {
                "Text never covers your crosshair any more: damage numbers, enemy health bars and names move out of a clear zone round it.",
                "A boss's WEAK POINT label hides while you aim at it (the ring stays), and the damage-taken number and MOVE! sit further from the crosshair.",
                "Duels: no name tag over your opponent's head.",
            } },
            { Head = "Less flashing", Lines = {
                "Duels: no more red screen flash when you're hit. A thin arc round the crosshair points at the shooter, plus the hurt sound.",
                "Enemy health bars no longer flash white, shake or strobe at low health. The fill drops and the chip drains, that's all.",
            } },
            { Head = "Enemies", Lines = {
                "Uplinks (the satellite bots) toned down: the three lanes spread much wider (easy to stand between), are thinner, warn longer and hit for less; they fire less often and swing slower.",
            } },
        },
    },
    {
        Id = 78, Version = "0.77", Date = "Oct 22, 2026", Title = "SAME GUN, BETTER AIM",
        Sections = {
            { Head = "Duels", Lines = {
                "Both duelists now use the SAME gun. Challenge with RANDOM (a gun is rolled when the duel starts) or pick one gun.",
                "When you get a challenge you can ACCEPT, DECLINE or COUNTER: COUNTER offers your picked gun instead, and a coin flip decides between the two.",
                "Headshots deal 20% more damage (with a crit sound).",
                "Hits heal you for 80% of the damage you deal (was 50%).",
                "No more armour: you spawn with 200 health, and hits can heal you up to 300 (it ticks back down to 200).",
                "Everyone has the exact same body in a duel: the standard blocky body at normal size, no accessories or body packages. Your look comes back after the duel.",
                "You move 12% faster in duels.",
            } },
            { Head = "Arenas", Lines = {
                "NEON ROOFTOPS rebuilt: a helipad deck, brick stair huts with neon signs, a water tank, planters, string lights, billboards and a city skyline at dusk.",
                "THE FOUNDRY rebuilt: steel walls and roof trusses, a riveted furnace with embers and a smoking chimney, an overhead crane pouring a ladle, pipes, painted containers and hanging lamps.",
                "The cover layout and spawns are the same, so the fights still play the same way.",
            } },
        },
    },
    {
        Id = 77, Version = "0.76", Date = "Oct 21, 2026", Title = "HOME AND HEADSHOTS",
        Sections = {
            { Head = "Hideout", Lines = {
                "New station AREAS: the Constellation Observatory (your own passive tree area, with your class stars circling) and the Armory Workshop (your own upgrade area: workbench, tool wall, anvil).",
                "New stations: Wardrobe (cosmetics), Index Terminal (Index), Challenge Board, Season Banner, Black Market Crate (shop) and Trade Terminal.",
            } },
            { Head = "Weak spots", Lines = {
                "Every enemy and boss has exactly ONE weak spot: its head. Cores, brands and break parts are normal hits now.",
                "A boss's weak point glow is smaller (about head size) and drawn over its armour, so it's always hittable, and precise shots are rewarded.",
            } },
            { Head = "Items", Lines = {
                "Lock items: click the padlock on any bag row. Locked items can't be sold, bulk-sold, dismantled or salvaged.",
            } },
            { Head = "Visuals", Lines = {
                "Every area now has sky light and reflections, so guns, metal and glass look much richer (no extra shadow cost), plus soft sun rays.",
            } },
            { Head = "Fixes", Lines = {
                "The Forge / Upgrade materials bar no longer flickers.",
            } },
        },
    },
    {
        Id = 76, Version = "0.75", Date = "Oct 21, 2026", Title = "CRAFT AND CONSEQUENCE",
        Sections = {
            { Head = "Crafting overhaul", Lines = {
                "Every crafting material now does one specific thing. Reforge Token: reroll every affix. Tuning Kit: reroll the numbers. Infusion Core: add one random affix. Purge Salt: remove one random affix. Affix Seal: keep ONE affix through a Reforge.",
                "No more building exactly what you want: Affix Seals lock one affix at most per Reforge (the cost now triples each time on the same item), Purge can no longer be aimed with seals, and the Bench still builds the base you pick but ROLLS its rarity like a drop.",
                "Crafting materials are much rarer from every source, and dismantling no longer gives Seals, Infusion Cores or Purge Salts.",
            } },
            { Head = "Titles", Lines = {
                "Every title was re-graded: the harder it is to earn, the higher its rarity and the bigger its buffs, every time. Clearing a difficulty matches that difficulty's top loot rarity.",
                "The easiest requirements are a bit harder, and flat Health / Armor title buffs are now percentages so they still matter at high level.",
            } },
            { Head = "Bags", Lines = {
                "New ITEMS tab in the inventory bag: every material (with what it does), your gems and misc items in one place.",
                "Gem bag AUTO-SALVAGE: gems at or under the rarity you pick salvage into materials as they drop.",
                "You can't pick up a gem while the gem bag is full (it used to vanish into materials).",
            } },
            { Head = "Fixes", Lines = {
                "TARGET LOOT (pity) items are never auto-sold. If your auto-sell was set, the target gun was sold the moment it dropped.",
                "Flying enemies can no longer drift outside the room's walls where they couldn't be shot.",
                "Rooms mix their enemies: one type fills at most about a third of a room.",
            } },
        },
    },
    {
        Id = 75, Version = "0.74", Date = "Oct 20, 2026", Title = "NO MORE SPRAY",
        Sections = {
            { Head = "Enemy attacks", Lines = {
                "The shockwave that burst out of enemies in every direction (it looked like a shotgun spray) is gone, from every enemy and boss. Wherever it was used, the enemy now drops a marked circle on YOU, timed for when the wave would have reached you. Step off it.",
                "That covers boss stomps, ripples and quakes, the Juggernaut's third slam, the Arcwalker's thunderclap, the Drowse lullaby and Hammerfall.",
            } },
            { Head = "Elites and bots", Lines = {
                "Hasted elites are still faster, but less extreme: +20% movement and attack speed (was +40% / +30%).",
                "Orbiters no longer circle you. They strafe from side to side in long, smooth sweeps in front of you.",
            } },
        },
    },
    {
        Id = 74, Version = "0.73", Date = "Oct 20, 2026", Title = "TORMENT TEMPO",
        Sections = {
            { Head = "Bot movement", Lines = {
                "Every difficulty above Cataclysm now uses the Torment / Cataclysm movement: the same mix of bots and the same rhythm to their sweeps, curves and strafes.",
                "What still climbs is their actual speed: +6% per difficulty past Nightmare, with no cap (Cataclysm +18%, Oblivion +24% ... Singularity +60%).",
            } },
        },
    },
    {
        Id = 73, Version = "0.72", Date = "Oct 20, 2026", Title = "SOUND OF LOOT",
        Sections = {
            { Head = "Drop sounds", Lines = {
                "Drops are quiet unless they matter: only the two rarest rarities of the difficulty you're on make a sound. The second-rarest gets a light shimmer, the rarest (or anything better, or a relic) gets the big one.",
                "It's relative: a Legendary on Brutal is a jackpot; on Oblivion it's silent. A chest or boss burst plays one sound, its best drop, and picking an item up doesn't play it again.",
                "Auto-sold items are silent.",
            } },
            { Head = "Gear pace", Lines = {
                "The top two rarities of each difficulty drop about half as often, and luck pushes them less.",
                "Boss, superboss, goblin and vault rewards guarantee one rarity step lower than before (a superboss no longer guarantees one of the top two rarities every kill).",
            } },
        },
    },
    {
        Id = 72, Version = "0.71", Date = "Oct 20, 2026", Title = "GEM POLISH",
        Sections = {
            { Head = "Skill gems", Lines = {
                "A socketed gem is easy to see on the tree now: a ring in its rarity colour around the socket, and Celestial and higher gems show their full rarity colours. (Astral gems used to look like an empty socket and the top rarities like the hover highlight.)",
                "Gems above Legendary are much rarer: every rarity step above Legendary has to be won on a coin flip. Gems stay in your tree for good, so a Celestial or better gem is now a real find.",
                "Gem tooltips are fixed: they say whether a gem counts toward the 1 Mythic rule or the 2 Legendary effects you can socket, gems on the ground show the same text as everywhere else (radius bonuses count ALLOCATED nodes only), and Glacial Tomb says bosses are immune.",
                "The gem loot message no longer points at a key that doesn't open the tree.",
            } },
        },
    },
    {
        Id = 71, Version = "0.70", Date = "Oct 20, 2026", Title = "DEEPER TIERS",
        Sections = {
            { Head = "Affix tiers up to T15", Lines = {
                "Weapon and gear affixes now roll from T1 up to T15. Your item's RARITY sets how high it can go: Legendary and below top out at T5, Mythic and Celestial at T10, and only Transcendent and higher can reach T15.",
                "Low tiers are by far the most common and every tier up is rarer. Each rarity's top tier is very rare: 0.5% on a Common, rising to 1.5% on the highest rarity. A T5 on a Legendary is a real find now, not a given.",
                "Mythic and higher weapons no longer get free T5 affixes.",
            } },
            { Head = "Gear grows with level", Lines = {
                "Gear lines now get stronger with item level: a level 1 piece starts low and a level 400 piece rolls about 3.5 times the numbers. Gear lines roll tiers too (shown on the tooltip), each tier a little stronger.",
                "Gear stats still have their own limits that rise with your level, so gear can't push you past the curve early.",
            } },
            { Head = "M60", Lines = {
                "The M60's ammo box hangs where it should: the belt feeds into it instead of poking out the side.",
                "The M60 is no longer pitch black in dark places like the hub at night.",
            } },
        },
    },
    {
        Id = 70, Version = "0.69", Date = "Oct 19, 2026", Title = "WEAK POINTS",
        Sections = {
            { Head = "Boss weak points", Lines = {
                "Every boss has its weak point back: its head and core glow LIME. A hit anywhere on the glow is a weak-spot hit (crit sound, weak-spot damage): what you see is exactly what you can hit, and it moves with the boss without lagging or jumping.",
            } },
            { Head = "Forge", Lines = {
                "The materials bar at the top of the Forge no longer jumps around when you hover it: the material's name and what it does show in a line under the bar.",
                "Chart Shards have their own icon.",
            } },
            { Head = "Rarity colours", Lines = {
                "Transcendent and higher items show their drifting rarity colours in every menu now: the Forge, upgrades, trades, duels and everywhere else an item name appears.",
            } },
        },
    },
    {
        Id = 69, Version = "0.68", Date = "Oct 19, 2026", Title = "TARGETS",
        Sections = {
            { Head = "One boss mechanic: TARGETS", Lines = {
                "Every boss now has the same mechanic, so you learn it once: now and then it shields up (no damage) and lime TARGETS appear around it. Break them all before the timer and it's STAGGERED: +75% damage for 6 seconds. Too slow and the targets fire at you as circles you can dodge.",
                "Three kinds of round, each boss plays them in turn: SWITCH (several targets at once), TRACK (one target gliding around the boss) and FLICK (one target at a time, each popping up somewhere new). Every gun breaks a target in about the same time.",
                "The old mixed mechanics are gone: no tiles to stand on, light wells, lightning rods, guards, metronome beats, armoured fronts or slag shells, and no extra tracking mini-games running at the same time. The Seraph Archon still makes you look away.",
            } },
            { Head = "No more laser fans", Lines = {
                "Bosses no longer shoot lines out all around themselves (spokes, spirals, sweeps, fissure fans): those moves are now circles where you're heading.",
            } },
            { Head = "Rarity colours", Lines = {
                "Transcendent and higher weapons show their rarity colours drifting gently across the name on your HUD weapon card, in tooltips, stash rows, ground loot and loot popups.",
            } },
        },
    },
    {
        Id = 68, Version = "0.67", Date = "Oct 18, 2026", Title = "SMOOTH OPERATORS",
        Sections = {
            { Head = "Bot movement", Lines = {
                "Bots no longer dash across the room every few seconds: when one moves to a new spot it glides there while it keeps weaving, so every bot moves in smooth, readable lines. Their rush-ins are gentler too.",
                "Circling bots (Orbiters, Vultures) circle wider, turn half as fast and ease into each turnaround. Orbiters no longer join the hard-difficulty mix.",
                "Strafing bots stay on the ground: no more jumps mid-strafe.",
                "Comets are 20% slower with narrower sweeps and a slightly bigger body.",
            } },
            { Head = "Bosses", Lines = {
                "Boss movement is smooth now: one flowing motion that swings from side to side, no more little hops or snaps. Dodges are a quick burst that eases out, and bosses keep drifting while they attack instead of freezing.",
                "Every dungeon boss can drop a RELIC: mini-bosses rarely, major bosses more, superbosses most, and more often on harder difficulties.",
            } },
            { Head = "Loot goblins", Lines = {
                "A loot goblin is a jackpot now: four items (often one of the top two rarities), a gem, a pile of crafting materials and 8x its gold.",
            } },
            { Head = "Taking damage", Lines = {
                "A red ring pops around your crosshair every time you're hit, with the damage under it.",
                "The screen-edge flash is bigger, the hurt sound is louder, and from 40% health the edges pulse red faster and stronger the lower you go.",
            } },
        },
    },
    {
        Id = 67, Version = "0.66", Date = "Oct 17, 2026", Title = "CHARTED",
        Sections = {
            { Head = "Map guardians", Lines = {
                "Every map tier band now ends on its own guardian instead of the usual Titan or biome boss: Ruin the Seraph Archon, Dread the Chronarch, Apocalypse the Echo Warden, Annihilation the Forgeheart, Eternity the Broodmother and Singularity the Duelist. Each fights with its full trial mechanics, at map strength.",
                "The map device shows each map's guardian.",
            } },
            { Head = "Map-only loot", Lines = {
                "CHART SHARDS: a new currency found only in maps (a chance on every map floor, more from the guardian's cache).",
                "Spend them at the map device: CHART gives a map a new biome and room layout, CORRUPT is a gamble (+1 tier and a mod, a mod, or nothing, always +20% item quantity, but the map can never be crafted again), ENGRAVE turns a Rare map into a Unique.",
                "Three map-only relics drop from guardians (beat the timer; twice as likely on Unique maps): Wayfinder's Compass, Cartographer's Mantle and Rift Lens. Any class can wear them.",
            } },
            { Head = "New map modifiers", Lines = {
                "Short Fuse (30% less time), Empowered Guardian (+60% guardian health), Steel Skin (no critical hits), Mending (enemies heal when left alone): each adds item quantity.",
                "All In: beat the timer and the guardian drops twice the items; miss it and it drops nothing.",
            } },
            { Head = "Map tree", Lines = {
                "Map points keep coming after your first 200 maps: one every 30 more maps, up to 16 extra points.",
            } },
            { Head = "Fixes", Lines = {
                "Fixed a script error that could stop enemy movement from drawing smoothly on party floors (seen on the Sandman and Highway King).",
            } },
        },
    },
    {
        Id = 66, Version = "0.65", Date = "Oct 16, 2026", Title = "CLEAR SHOTS",
        Sections = {
            { Head = "Arenas", Lines = {
                "Every dungeon room is 10% bigger (boss arenas too).",
                "Jump pads are gone from the biomes.",
                "Fewer props stand in the middle of the room, so they block your shots less often.",
            } },
            { Head = "Bots on Nightmare and up", Lines = {
                "The small, erratic fliers (Strafers, Zippers, Poppers, Pasus, Sparks, Gales, Rasters, Glitches) move a little slower.",
                "The smooth movers (Trackers, Seraphs, Drifters, Flurries, Rimewyrms, Uplinks and more) move faster, more the higher the difficulty, and every other bot a bit faster too. The hardest tiers now feel like it.",
                "The Orbiter and the Vulture no longer run full laps round you: they sweep an arc on their side of you and turn back at each end.",
            } },
            { Head = "Store", Lines = {
                "Bundle-only items no longer say GET THE ... BUNDLE BUNDLE.",
            } },
        },
    },
    {
        Id = 65, Version = "0.64b", Date = "Oct 15, 2026", Title = "SECOND LOOK",
        Sections = {
            { Head = "Map tree", Lines = {
                "The map tree now opens zoomed out so you see all of it, node names stay readable at any zoom, and the nodes you can take right now light up.",
            } },
            { Head = "Beam skins", Lines = {
                "Aurora guns are now frosted white and ice blue, Event Horizon guns polished gold over void black, and the Brass Comet Spark Pistol cream enamel with oxblood panels. Before, they looked too much like the plain guns.",
            } },
            { Head = "Fixes", Lines = {
                "The Spark Pistol sits properly in your hands instead of floating above them.",
            } },
        },
    },
    {
        Id = 64, Version = "0.64", Date = "Oct 14, 2026", Title = "MAPMAKER",
        Sections = {
            { Head = "Map tree", Lines = {
                "A new MAP TREE (the MAP TREE button on your hideout's map device): 113 map passives in eight branches round your map device: Cartography (sigils), Treasure (the guardian cache), The Hunt (elites), Fortune (loot goblins), Tempo (the timer), Artisan (map crafting), The Depths (XP) and Purist (Normal maps).",
                "Each branch ends in a CORNERSTONE with a real trade-off, like Hunter's Pact (every map is bot skill 10, +40% guardian items) or Race the Clock (half the time, but a bonus sigil and a top item).",
                "Points: one for every map tier you've beaten in time, one per 10 maps finished and one per Unique map cleared. There are far fewer points than nodes, so pick a direction. Refunds cost 2 Prism.",
            } },
            { Head = "Maps", Lines = {
                "Maps now run at YOUR level, up to 10 above it (deeper tiers and rarer maps sit higher), so everything they drop is gear you can use. The tier still sets the difficulty and the loot rarities.",
                "Every map rolls its bot skill between 6 and 10, shown on the map with its level.",
            } },
            { Head = "Boss loot", Lines = {
                "Boss rewards now follow the difficulty's own rarity range instead of fixed names: a superboss drops one item from the top two rarities your difficulty can drop and two from the top three, bosses one from the top three and one from the top four. On high difficulties that used to mean 'Epic', which normal enemies drop.",
                "Vault paths, floor objectives, events, the loot goblin and the boss vault chest work the same way.",
            } },
            { Head = "Leveling", Lines = {
                "Leveling is much faster: about 3 hours to level 50, 8 to 75 and 18 to 100 for an average player, and around 200 hours to the level 400 cap. Every kill gives more XP to match.",
            } },
            { Head = "Fixes", Lines = {
                "Revives and lost-loot recovery are no longer free while they aren't on sale yet.",
            } },
        },
    },
    {
        Id = 63, Version = "0.63", Date = "Oct 13, 2026", Title = "CLOSE QUARTERS",
        Sections = {
            { Head = "Passives", Lines = {
                "The ten playstyle cornerstones moved from the middle of the tree to its outer edge, two in each gap between the classes (about 80 points to the nearest one).",
                "You can hold at most three playstyle cornerstones at once.",
                "Everyone gets another free full passive tree reset.",
            } },
            { Head = "Arcwright guns rebuilt", Lines = {
                "All seven beam guns are brand new designs of their own: armoured energy weapons with glowing cores, coils and emitters, not reskinned real guns. Each has its own armour colour, glow and a charge gauge on top.",
                "Hyperion Railgun (an open twin-rail barrel with copper windings and a long holo scope), Helios (a focusing-lens barrel and a slotted shroud glowing orange), Tesla Quadbeam (four copper prongs and tesla coil drums), Ion Accelerator (a containment chamber with the ion core showing through), Void Rifle (a swept bullpup with a broken singularity ring at the muzzle), Spark Pistol (an open coil emitter) and the Arc Projector (forked electrodes).",
            } },
            { Head = "New skin bundles", Lines = {
                "AURORA: Hyperion Railgun + Ion Accelerator. Curtains of aurora light ripple above the barrel and ice grows over the gun with your streak. Glacier Edge melee, Aurora Curtain kill.",
                "EVENT HORIZON: Void Rifle + Tesla Quadbeam. A spinning accretion disk round the emitter and a black singularity at the muzzle. Horizon Blade melee, Collapse kill.",
                "BRASS COMET: Helios + Spark Pistol. Retro raygun brass: tumbling gyro rings, glowing vacuum tubes and a pressure gauge that climbs as you fire. Comet Saber melee, Comet Strike kill.",
                "Each bundle has gloves, sleeves, a health bar, its own sounds, tracers, impacts and kill banner.",
                "The Fairy Bloom Arc Projector and every beam skin were refitted to the new models.",
            } },
            { Head = "Bosses", Lines = {
                "Weak points and targets now glow LIME, a colour no boss or enemy uses, so you can spot them from across the arena.",
                "Their circle and glow only show while you can actually see them (nothing in the way).",
                "Far fewer laser fans: the 'lines shooting out around the boss' attacks were cut from most bosses and can't repeat within 35 seconds.",
                "New boss moves: PYLONS (shoot the pylons before they fire at you), PREDICT (circles land where you're heading), TWIN QUAKE (two shockwaves from either side) and SEEKERS (homing orbs drift after you: shoot them down before they reach you).",
                "The Goliath, Phantom, Ravager, Apex Titan and every biome superboss picked up some of the new moves, so their fights vary more.",
            } },
            { Head = "Bots", Lines = {
                "Every few seconds one bot is EXPOSED: it glows lime and takes 40% more damage for 4 seconds. Switch to it.",
            } },
            { Head = "Crafting", Lines = {
                "The forge BENCH is harder: it now builds up to three rarities below your level's top (was two), and costs about two to three times as much (more Schematics the higher the rarity).",
            } },
            { Head = "Duels", Lines = {
                "Both duel arenas were rebuilt about an eighth of their old size: Neon Rooftops and The Foundry are tight, close-range fights now.",
                "Quake-style movement in duels: a faster run, low quick hops, hold Space to bunny hop and strafe in the air to build speed. No dash, slide or knife dash.",
                "Quake health: you spawn with 125, hits heal you past 100 up to 200, and anything over 100 ticks down 1 a second. Fights last longer and a streak builds a real lead.",
            } },
            { Head = "Balance", Lines = {
                "Enemy health from level 100 up was re-scaled to the new passive tree (the playstyle cornerstones and the stronger passives).",
            } },
            { Head = "Rooms", Lines = {
                "Every room is about 25% smaller again, boss arenas too.",
            } },
        },
    },
    {
        Id = 62, Version = "0.62", Date = "Oct 12, 2026", Title = "THE BENCH",
        Sections = {
            { Head = "Maps", Lines = {
                "Maps now have a rarity: Normal (no modifiers), Magic (1-2), Rare (3-4) and Unique (named maps with fixed modifiers and a much bigger guardian cache).",
                "Seven new map-only modifiers: Brutal, Bleak (no health regen), Armored, Sharpshooters, Relentless, Small Targets and Elemental.",
                "Every modifier adds item quantity: harder maps drop more and better loot from the guardian.",
                "Craft maps at the map device with Prism: IMBUE a Normal map into Magic, EMPOWER a Magic map into Rare, REROLL a map's modifiers.",
                "Every map has its own room layout (Gauntlet Run, Tower Yard, Ring Arena, Pillar Hall, Terraces, Bunker Field) and stays in its biome for all five floors.",
            } },
            { Head = "Arcwright beam guns", Lines = {
                "The Arcwright gets six new guns: Helios Thermal Beam and Tesla Quadbeam (continuous beams), Hyperion Particle Railgun, Ion Plasma Accelerator, Quantum Void Disintegrator and the Spark Pistol.",
            } },
            { Head = "Passives", Lines = {
                "Class passives were rebuilt into real playstyles, and ten new playstyle cornerstones sit in the middle of the tree: Glass Cannon, Flicker, Tracker's Lock, Last Stand, Momentum, One Shot, Executioner's Creed, Blood Rounds, Gambler and Bullseye.",
                "Everyone gets a free full passive tree reset.",
                "Hovering a far-away node lists everything you'd unlock on the way to it.",
            } },
            { Head = "Spectate", Lines = {
                "New SPECTATE button on the side dock (in the city): watch anyone in a run through their eyes, holding their gun in their skin.",
                "Don't want to be watched? Settings > Social > Allow Spectators.",
            } },
            { Head = "Combat feel", Lines = {
                "Rooms are smaller and tighter (boss arenas keep their size).",
                "Bots were revamped: smoother tracking, long and close strafes, and the top bot skills add more targets instead of twitchier movement.",
                "Getting hit is much clearer: bigger direction arcs, a stronger edge glow, a short red pulse and a louder hurt sound.",
                "Bosses stand out more, and every weak point and mechanic target is marked (WEAK POINT / TARGET, with arrows when off screen). The boss bar says what to do.",
                "Shooting no longer lights the screen up white (impact and muzzle lights toned down).",
            } },
            { Head = "Quality of life", Lines = {
                "Holding the mouse after a reload keeps shooting.",
                "Store search understands gun types: try LMG, SMG, Sniper.",
                "The hit sound pickers play the sound when you change it, and body and head hit sounds no longer overlap.",
                "The teleport menu works from your hideout.",
                "Trades no longer break when you take an item out or put one back.",
            } },
            { Head = "Forge crafting", Lines = {
                "Gear can now be Reforged (with Affix Seal locks), Tuned and Re-leveled in the Forge, just like weapons.",
                "AUGMENT adds a new affix to a free slot (Infusion Core).",
                "PURGE removes an affix (Purge Salt). Lock the affixes you want to keep to choose which one goes.",
                "ASCEND raises an item one rarity and keeps its affixes (Ascension Essence + Prism), once per item, up to one below the best rarity your level can drop (the top rarity only comes from drops).",
                "The new BENCH tab builds the gun or gear piece you pick, at your level (Schematics).",
                "The new materials drop from bosses, elites, caches, rifts and dismantling.",
                "Ascension Essence is incredibly rare: any monster can drop one, but don't count on it (bosses are a little more likely).",
            } },
            { Head = "Look", Lines = {
                "Every Roblox emoji icon in the game (materials, settings tabs, the bounty skull, buttons, lists) is replaced with our own icons.",
                "The welcome guide's text follows your UI theme with readable contrast instead of always being yellow.",
                "Rarity symbols on loot popups, gems and lists no longer show up as empty boxes.",
                "The Forge's material bar fits the window: owned materials show their icon and count (hover for the name).",
            } },
            { Head = "Enemies", Lines = {
                "Fast enemies on the top bot skills change direction far less often: longer strafes, fewer twitchy flips, so you get a moment to shoot. Their speed is unchanged.",
                "Zig-zaggers and grid fliers hold each line longer before turning.",
                "Blinking and teleporting enemies teleport half as often.",
            } },
            { Head = "Bosses", Lines = {
                "Every boss is now about human sized: far smaller and much harder to hit (weak spots shrank with them). They move 50% faster and have 40% less health to make up for it.",
                "Bosses never just stand there any more: every boss circles you, strafes across your aim and side-dodges, switching direction every few seconds.",
                "New tracking rounds on every boss (each in its own style): SATELLITES orbiting the boss (break them all in time), a WISP to keep your aim on, or a RELAY of targets popping up around you one at a time. Clear one and the boss is EXPOSED.",
                "Superbosses have more of their own moves: the Void colossus has a new set, and the Storm, Fire and Sentinel fights swapped repeated patterns for new ones.",
            } },
            { Head = "Fixes", Lines = {
                "Going back a floor and returning no longer locks the portals on the floor you came back to.",
                "Props (pines, ice statues, crystals, furnaces, rock outcrops) no longer block the next-floor portals on the Ice and Molten maps.",
                "The 'better weapon found' popup only shows guns for your class (others go straight to the stash).",
                "A boss's health bar no longer hides under the SAFE ZONE banner in the entry room.",
            } },
        },
    },
    {
        Id = 61, Version = "0.61", Date = "Oct 11, 2026", Title = "AIM FIRST",
        Sections = {
            { Head = "Enemies", Lines = {
                "Regular enemies attack about half as often, but every hit lands about twice as hard.",
                "Their warnings are longer and the same on every difficulty: harder tiers make enemies tougher, not faster to attack.",
                "At most two enemies wind up an attack on you at a time (elites can be a third).",
                "Bosses keep their own attack patterns.",
            } },
            { Head = "Fair hits", Lines = {
                "Shockwave rings now have gaps: stand in an opening and the ring passes you. They also follow the ground, so you can always see them (on bumpy floors they used to sink out of sight and still hit you).",
                "Rings and floor lasers only hit where they're drawn. The old 'standing on something' rule that hit you through a buried laser is gone.",
                "'Get to a safe circle' wipes (Supernova and the like) are drawn in a deep red that shows on every floor, each safe circle has a tall green light, and nothing outside the red floor gets hit.",
                "The Bulwark Sentinel's PULSE fires 2 rings, further apart, instead of up to 5.",
            } },
            { Head = "Minibosses", Lines = {
                "Every miniboss now has its own attacks; none of them share patterns any more.",
                "Goliath Enforcer: earth and charges, one charge per round (a double charge when it's berserk), stomps, boulders, fault lines and rubble.",
                "Bulwark Sentinel: lasers only. New: Laser Grid, Closing Beams, Tracking Lasers and Grid Lockdown.",
                "Hexcaller: spells. New: Hex Bloom, Hex Prison and Hex Quadrants.",
                "Props no longer stand behind or between the end-of-floor portals, and the portals are spaced so their names don't overlap.",
                "Enemy attack areas are exact now: if you're outside the coloured area when it goes off, you take nothing.",
                "Fixed: standing right behind an enemy's swing could still hit you, and strips reached a little past their ends.",
            } },
            { Head = "Difficulty curve", Lines = {
                "A run now gets harder smoothly. The first floors are a bit tougher than before, the last floors about the same, and there is no big jump halfway.",
                "Specialists and elites now join gradually through a run instead of all at once after the first boss.",
            } },
            { Head = "Loot and crafting", Lines = {
                "New material: AFFIX SEAL. When you Reforge a weapon at the Forge, click affixes to lock them: they stay, the rest reroll.",
                "Each locked affix costs 1 seal, and the cost doubles with every locked reforge of the same item (1, 2, 4, 8...).",
                "Seals drop from bosses (superbosses always give 2), rift guardians, run finishes, loot goblins, sometimes elites, and dismantling Legendary or better.",
                "Missed loot? Every cleared floor now has a blue BACK portal by the chest. It takes you to the floor behind you with your drops still there, and the way back brings you to this floor still cleared.",
                "EQUIP BEST only picks guns of your class now (it still uses any gun if you don't own one for your class).",
            } },
            { Head = "Movement", Lines = {
                "Sliding has a short cooldown (about 1 second), and tapping crouch mid-slide no longer re-boosts it.",
            } },
            { Head = "Portals, chests and visibility", Lines = {
                "Every dungeon portal is rebuilt: a carved stone archway with glowing runes, floating crystals and a jewelled keystone around a swirling vortex that pulls light into its centre.",
                "Every chest is now a heavy iron-banded strongbox with a glowing seam, a lit lock and a gem on the lid. Bigger chests get handles, crest spikes and floating runes. Opening one swings the lid back with a burst of light and a shaft that fades out.",
                "Enemy outlines now use a colour picked to stand out in each biome (cyan on fire, red on ice, yellow in the void, and so on), and enemies get a light tint of that colour. Both can be changed in Settings > Enemies.",
                "Your first class pick gives you a random starter gun from that class instead of the pistol.",
                "Passive tree: cornerstones and notables on the border between two classes are now coloured as the class whose guns they work with (Drum Mag is Vanguard, Bolt Discipline is Marksman).",
            } },
        },
    },
    {
        Id = 60, Version = "0.60", Date = "Oct 10, 2026", Title = "SLOW AND STEADY",
        Sections = {
            { Head = "Movement", Lines = {
                "You move slower now. Bhops, slides and dashes still work, but they build much less speed, and there's a speed cap a little above a fast run.",
                "This is an aim game: staying on target matters more than outrunning everything.",
            } },
            { Head = "Enemies", Lines = {
                "Every enemy and boss attack winds up a little longer, so you have time to step out at the new pace.",
                "Red areas are slightly smaller and safe circles bigger; rings, rolling walls and sweeping lasers move a bit slower.",
                "Superbosses have about 30% less health, and shooting them between their weak moments counts a little more.",
                "Enemies that teleport, phase out or dash-blink do it about a third as often, so you get time to land your shots.",
                "Late floors no longer bury you: only 2 or 3 enemies can wind up an attack on you at once (4 on the top three difficulties), elites wait their turn too, and a room has at most 2 specialists.",
            } },
            { Head = "Dungeons", Lines = {
                "The portals now stand just behind the victory chest instead of at the far end of the room.",
            } },
            { Head = "Experience", Lines = {
                "All XP is up about 30%.",
                "The first floors of a run no longer pay almost nothing when you out-level them: the cut starts 12 levels below you and never drops under a quarter.",
                "XP no longer drops the moment a new difficulty unlocks at your level; it only expects you there a few levels later.",
            } },
            { Head = "Loot", Lines = {
                "Fixed: skill-tree gems ignored the difficulty and dropped mostly Common and Uncommon even on Torment. Gems now follow the same rarity window as weapons and gear for the difficulty you're on.",
                "Gems now climb the whole rarity ladder like your loot: Celestial up to Infinite on the hardest difficulties, and they keep getting stronger. Above Mythic a gem can be a stat gem, a Legendary effect, or (from bosses) a Mythic rule.",
            } },
            { Head = "Maps", Lines = {
                "Maps (Rift Sigils) are now the level 100+ endgame. The map device opens at level 100, and bosses start dropping sigils then.",
                "Tiers climb the top difficulties three at a time: 1-3 Ruin, 4-6 Dread, 7-9 Apocalypse, 10-12 Annihilation, 13-15 Eternity, 16+ Singularity.",
                "The guardian pays far more: 3 to 8 items near the top rarity of the tier, gems, materials and a big gold cache. Every tier also gives more XP, gold and luck per floor.",
                "Sigils you already own move onto the new ladder.",
            } },
            { Head = "Interface", Lines = {
                "Fixed: the GUIDE and PATCH NOTES buttons in the top left were hidden all the time. They're back.",
                "The side dock is cleaner: just the icons. Hover one to see its name and key.",
                "Buttons, windows, cards and title bars now share the look of the game's icons: a solid face, a shaded side and a heavy dark edge. The striped plate in window title bars is gone.",
                "The class change button now says what it costs: 1 Rebirth Shard (it used to show how many you have).",
                "Fixed: on some servers the DPS TEST pad in the Training Grounds never started its meter.",
            } },
            { Head = "Duels", Lines = {
                "Pick ANY gun in the DUEL window. Every gun deals exactly 120 damage a second at perfect aim: its damage per shot is 120 divided by its fire rate, and shotguns split that across their pellets.",
                "Everyone is the same plain body in a duel, and shots hit exactly the limbs you see.",
                "Your shots now reach across the whole arena.",
                "No knife in duels, no bhop off landings, a jump at most every 0.75 seconds, and a lower speed cap.",
                "You can change your gun between frags. Your opponent sees the gun you picked.",
                "The DUEL window is rebuilt: your record, opponents with their avatars, a weapon grid showing each gun's damage x fire rate, arena cards, the wager switch and the rules.",
            } },
        },
    },
    {
        Id = 59, Version = "0.59", Date = "Oct 9, 2026", Title = "DUELS",
        Sections = {
            { Head = "Duels (new)", Lines = {
                "Challenge anyone in the server to a one on one duel: press [K] or use the DUEL tile. Pick the arena, and choose whether to wager gear.",
                "Everyone fires the same gun: 120 damage a second at perfect aim, no recoil, no reload, the same hitbox for every avatar. Your gear, tree and gun stats don't count; your aim does. Hold any automatic gun (an AR, LMG, SMG or the beam) and it's just its look, sound and skin.",
                "Hits are vampiric: half the damage you deal heals you. Two players at the same accuracy both bleed out slowly, so the better aim wins every exchange.",
                "100 health and 100 armour, armour takes two thirds of each hit. First to 5 frags; after 5 minutes the leader wins, a tie goes to sudden death.",
                "Two duel-only arenas, bigger than the dungeon rooms: NEON ROOFTOPS (a raised court, rooftop huts, long cover walls) and THE FOUNDRY (a furnace, a catwalk ring with bridges, containers).",
                "Gear wagers: if both of you agree, each puts in up to 4 guns or gear. Both press READY, then CONFIRM. The winner takes everything. Leaving mid-duel forfeits.",
                "Your duel record (wins, frags, accuracy) is in the DUEL window. Settings > Social can turn duel challenges off.",
            } },
            { Head = "Hideouts", Lines = {
                "New theme: EMBER FORGE, a smiths' hall cut into a live volcano with a roaring hearth, lava running past iron-barred windows, lavafalls down the crater and embers drifting past the balcony.",
                "The map device is now part of the portal skin: every portal comes with its own device (a rune altar, a stone lantern, a floating monolith, a holo table and more).",
                "Portals open with their own sound, a burst of effects and a looping hum, and keep their particles going while open.",
                "New portals: Inferno Maw, Celestial Halo, Clockwork Gate and Coral Arch. New stashes: Dragon's Hoard, Frost Reliquary and The Mimic.",
                "The default stash, the default portal and every older skin got the same upgrade: more detail, lights, particles and moving parts.",
            } },
            { Head = "Bosses", Lines = {
                "Attacks that covered the whole middle of the arena now always leave several safe circles around the boss instead of one spot beside it.",
                "Over forty boss moves were replaced with new signature moves, so far fewer bosses share attacks.",
            } },
            { Head = "Fixes", Lines = {
                "Dying in a dungeon no longer leaves your character kicking on the ground: you lie still until you're back up.",
                "Auto sell now also sells gear and guns dropped by enemies, not only chest drops.",
                "Relics are their own tier now: they show RELIC instead of the rarity they rolled on.",
            } },
        },
    },
    {
        Id = 58, Version = "0.58", Date = "Oct 8, 2026", Title = "MAPS AND MARQUEES",
        Sections = {
            { Head = "Hideouts", Lines = {
                "Every hideout is about half again as big, with a new door for each theme.",
                "MAP ROOM expansion: a new wing with a map device and a portal. Put a rift sigil in the device and the portal opens; step through to run it. The portal has skins.",
                "Rifts now open from your hideout's map device. The RIFTS tab in Challenges is gone.",
                "Stash and portal skins: Treasure Chest, Cyber Vault, Sakura Box and Void Coffer stashes; Torii, Void Eye and Neon Arch portals.",
                "The training dummy is rebuilt as a padded combat bot with a bullseye core front and back, and it no longer pokes through the roof.",
                "From your hideout's balcony you can see the players down in the city. Players in the city still never see hideouts or the people in them.",
            } },
            { Head = "UI themes", Lines = {
                "Every skin bundle now includes its own UI theme, built from the set's own art: its print on every window, its emblem glowing behind each menu, themed corners, two layers of floating particles (petals, bubbles, hearts, bats, coins, music notes and more) and a burst when a window opens. If you already own a bundle, its theme is waiting in your cosmetics.",
                "The older premium themes gained the emblem watermark and a second particle layer, and the dropped recolours now have soft floating particles too.",
            } },
            { Head = "Hit numbers", Lines = {
                "Damage numbers are rebuilt: hits on the same enemy stack into one number that grows and pops, crits shake, weak spots get a mark, and a killing blow punches the number up.",
                "Your UI theme styles them: its colours, and for premium themes their own font, mark and pop.",
                "Numbers stay under your menus now.",
            } },
            { Head = "Biomes", Lines = {
                "Every boss stage is its own place: a magma seal in Molten, a frozen lake in Glacier, a summoning circle in the Void, a neon grid in Cyber, rain-soaked stone in Stormspire, a giant clock in the Dreamscape and a crossroads in Neon Flats. A sign over the arena names the boss, and boss floors are lit darker and moodier.",
                "New clouds: soft drifting cloud banks instead of the hard discs in the sky.",
                "Ground and rock now match their biome: Neon Flats is a dusk desert of pink salt, asphalt and red-rock mesas, the Void floor is dark violet stone, and the Dreamscape no longer glows white underfoot.",
            } },
            { Head = "City", Lines = {
                "The street has real concrete slabs, cracks and stains, raised sidewalks with curbs along the shops, and a low mist.",
                "Rooftops: parapets, water tanks, antennas with red beacons, neon signs and more lit windows up top.",
                "The teleport menu is redrawn: every place has its own neon-sign card.",
            } },
            { Head = "Selling", Lines = {
                "One SELL button with a dropdown: sell everything up to the rarity you pick.",
                "Auto sell goes up to much higher rarities, and asks you to confirm before it's set for the rarer ones.",
            } },
            { Head = "Melee", Lines = {
                "Swing trails are toned down further.",
                "Melees are held at an angle that shows off the weapon instead of edge-on.",
                "A small meter under the crosshair shows the melee dash cooldown.",
            } },
            { Head = "Fixes", Lines = {
                "The HK21 is called 21E everywhere, and its magazine no longer looks glitched.",
                "Gloves no longer poke through the sides of the newer guns.",
                "Enemy health bars no longer show through your menus.",
            } },
        },
    },
    {
        Id = 57, Version = "0.57", Date = "Oct 7, 2026", Title = "BAGS AND BLADES",
        Sections = {
            { Head = "Melee", Lines = {
                "Every melee animation is smoother: swings, pullouts and inspects now flow through each pose instead of stopping at every one.",
                "Every melee skin has its own pullout and inspect: flicks, twirls, tosses, scoops, cradles, flourishes and stage spins, each fitted to the skin.",
                "Right click with your melee out is now a pure dash. Melee swings no longer go off while you dash.",
                "Swing trails are toned down: they only show around the hit itself and fade fast instead of hanging in your face.",
                "A quick melee cancels a reload (your magazine stays as it was), and firing or reloading cuts a quick melee short.",
            } },
            { Head = "Gloves and sleeves", Lines = {
                "Sleeves now come in seven cuts (plated, wrapped, scaled, flowing, tech, layered frills and bracer) and gloves in seven (gauntlet, fingerless, claw, tech, mitt, lace and paw), so every set looks different on your arms.",
            } },
            { Head = "Bag and stash", Lines = {
                "Your inventory is now a 60-item BAG. When it's full, new drops wait on the ground until you make room.",
                "Every hideout has a STASH chest: 100 items, plus 50 for each hideout expansion. Store and take items from the inventory's STASH tab while you're home.",
                "Search boxes in the inventory and the cosmetics window: type a name, gun, type, rarity or stat.",
                "Hideout expansions can also be bought with Robux (no level needed).",
            } },
            { Head = "Hideouts", Lines = {
                "Hideouts now float above the city's plaza: the balcony looks down on the spawn and the waypoint.",
                "Other players' names no longer show in your hideout.",
                "Hideout themes are rebuilt from scratch as their own places. The Deep Aquarium is a glass tunnel on the sea floor with fish shoals, a manta, a turtle and glowing jellyfish swimming around you. The Forest Cabin is a log cabin up in a giant tree with open windows, vines, fireflies, butterflies and birds.",
                "Hideout themes are in the store under HIDEOUT THEMES, as well as the HIDEOUT window's THEMES tab.",
            } },
            { Head = "Balance", Lines = {
                "Fully automatic guns get less from bonus fire rate, so they no longer spiral out of control at high levels.",
                "Titles re-graded for the 15-rarity ladder and sorted by rarity. Difficulty clears now match that difficulty's top loot rarity.",
            } },
            { Head = "Movement", Lines = {
                "Dashing has its own animation: a low lunge you (and everyone else) can see, with the gun tucking in.",
            } },
            { Head = "Fixes", Lines = {
                "Boss warnings (like TURN AWAY) no longer follow you back to the hub.",
                "The biome name card fits the screen.",
                "Loot goblins move smoothly instead of glitching around.",
                "Adding items to a trade no longer scrolls the list back to the top.",
            } },
        },
    },
    {
        Id = 56, Version = "0.56", Date = "Oct 7, 2026", Title = "PLAYTEST FIXES",
        Sections = {
            { Head = "Bosses", Lines = {
                "Fan attacks no longer look like lasers shooting out of the boss: the whole wedge fills in evenly, then goes off.",
                "Boss attacks now hit exactly where they're drawn. Beams were drawn thinner than they hit, and sweeping lasers and rings reached past their edges.",
                "Every boss shuffles its moves now: each one comes once per round in a new order, and the same attack never plays twice in a row. During mechanics they also pick from six lighter attacks instead of looping three.",
                "New attack: WAVES. Walls roll across the arena from the boss. Jump the low ones; the tall ones have a gap to run through, and it moves each wave. The Titan, Goliath, Sentinel, the Cyber superboss and the Lockwarden use them.",
                "Goliath is much quicker to kill: its armoured front takes half damage (was 30%), it has less health, its posture breaks sooner, it stays down longer and it charges more often (each charge opens its back).",
                "Two new minibosses. RAVAGER: a beast that pounces where you stand; its frenzy builds to a rampage of pounces unless you shoot the glowing spines on its back. HEXCALLER: three crystals orbit it and ward it; break all three while dodging its hexes and it takes double damage.",
            } },
            { Head = "Hideouts", Lines = {
                "EXPANSIONS: four upgrades bought with gold in the HIDEOUT window (each needs a level). They raise how many pieces you can place, up to 60, and BALCONY RIGHTS lets you build out on the balcony.",
                "THEMES: prebuilt hideouts that change the whole place while your furniture stays put. The Walled-City Loft is the default, and the Deep Aquarium and Forest Cabin are new. Pick them in the HIDEOUT window's THEMES tab.",
                "Right-drag turns the camera in build mode again.",
            } },
            { Head = "Try-ons", Lines = {
                "Trying a gun skin now hands you that skin's own gun (its fire rate, magazine and feel), not your equipped gun with a new look.",
                "Try-ons only work in the hub city and end the moment you leave it or open another window. Nobody else sees or hears your try-on shots or swings.",
            } },
            { Head = "Fixes", Lines = {
                "You can shoot the moment you step out of the dungeon's entry room after respawning (there was a second-long lockout).",
                "Respawning in the hub is instant.",
                "Returning to the hub after a run or a death no longer knocks your character over.",
            } },
        },
    },
    {
        Id = 55, Version = "0.55", Date = "Oct 7, 2026", Title = "HOME AND TRADE",
        Sections = {
            { Head = "Trading", Lines = {
                "Trade guns, gear and gold with other players. Press [Y] (or the TRADE tile) and send someone a request; they get a popup to accept.",
                "Both of you put in what you're giving, press READY, then CONFIRM after a short lock so you can check what you get. Changing anything un-readies both sides. The server checks every item again before the swap, so nothing can be duped or lost halfway.",
                "Equipped items and the starter pistol can't be traded. You can turn trade requests off in Settings > Social.",
            } },
            { Head = "The Bazaar", Lines = {
                "A new night-market courtyard just for trading: trade tables, a furniture stall, street food and a gate back to the city. Go there from the Teleport menu [G].",
            } },
            { Head = "Hideouts", Lines = {
                "Your own walled-city loft: press [U] (or the HIDEOUT tile) and pick GO TO MY HIDEOUT.",
                "BUILD MODE: pick a piece, it snaps to the floor grid (R turns it), click to place. Click a placed piece to move it, DELETE or X to put it away. The camera lifts above the room while you build.",
                "45 pieces of furniture: simple pieces for gold (at the Bazaar's stall or in the HIDEOUT window), boss trophies that drop more often on harder difficulties, pieces you earn (a relic case, trial monuments, level banners, a title wall) and premium pieces.",
                "Useful stations you can place: your own Stash Locker, Forge Bench, Upgrade Anvil, Skill Shrine and a Dungeon Portal. Every hideout has a practice alcove with a damage dummy.",
                "Friends and party members can visit any time from the HIDEOUT window. Anyone else can ASK while you're home; you choose to let them in or not, and you can kick visitors. Turn visit requests off in Settings > Social.",
            } },
            { Head = "Kawaii sets restyled", Lines = {
                "All twelve kawaii sets got new gloves and sleeves: tailored stage-combat gear in each set's own colours, with shaped armour plates, metal trim, glowing piping, a strap and buckle, and the set's emblem on the cuff and the back of the hand.",
                "Their guns now use three matching tones each (a deep base, the set's colour and a polished metal) instead of a mix of pastels, so the whole gun reads as one design. A few decorations were recoloured to match.",
                "Gloves renamed: Kitsune Gauntlets, Sprinkle Gauntlets, Kingyo Gauntlets, Cloud Nine Gauntlets and Ramune Gloves. You keep any you own.",
            } },
            { Head = "Every set restyled", Lines = {
                "The Solaris, Abyssal, Tempest, Neon, Ironclad, Verdant, Jade, Seraphim and Infernal gloves and sleeves got the same tailored treatment in their own colours, and keep their signature pieces: sun dishes, fins, charged orbs, holo panels, pistons, leaves, coins, wings and horns.",
                "Melee hits now land: a skin-coloured slash flash, sparks and a ring where the blow connects, the skin's own hit sound, and a short hit-stop that knocks back through your arms.",
                "Each of these sets' melees has its own moves now: hooking khopesh cuts, a lunging fang bite, a thunder slam, a spinning hard-light slash, a breaching axe chop, flowing leaf arcs and a jian's thrusts, each with its own entrance and inspect. The Seraphim Spear and Infernal Scythe got new entrances, and the Breacher's head now faces you.",
            } },
            { Head = "Fixes", Lines = {
                "The GUIDE and PATCH NOTES buttons no longer sit on top of open windows.",
                "You can no longer walk or jump out of your hideout into the sky.",
            } },
        },
    },
    {
        Id = 54, Version = "0.54", Date = "Oct 6, 2026", Title = "KAWAII ARSENAL",
        Sections = {
            { Head = "Twelve new skin sets: every new gun has a skin", Lines = {
                "STARLIGHT IDOL (Vector + HK416): a magical-girl weapon with a beating heart locket, a satin bow, a crescent moon muzzle and a MAGIC CIRCLE on inspect. The melee is the Moon Scepter, with its own baton-twirl inspect. Kill effect: Magical Finish.",
                "KITSUNE MATSURI (M40 + KSG): a fox-spirit festival. Porcelain fox masks, fox ears, nine tails that fan out on inspect, a little torii gate and a foxfire that burns taller as your streak climbs. The melee is the Kitsune War Fan, which snaps open with every swing. Kill effect: Kitsune's Blessing.",
                "SUGAR RUSH (USP + Double Barrel): a dessert parlour. Candy-cane stripes, piped cream, a cherry on top, strawberry slices and sprinkles with every shot. The melee is the Swirl Lollipop. Kill effect: Sugar Rush.",
                "NEKO CAFE (PPSh + SVD): a lucky-cat cafe in sky blue and strawberry pink. A little lucky cat rides the gun and beckons faster as your streak climbs, the PPSh's drum wears a happy cat face, a collar bell jingles with every shot and a gold coin spins on inspect. Paw-print tracers. The melee is the Neko Paw, which beckons at you on inspect. Kill effect: Nyan Punch.",
                "ORIGAMI GARDEN (TAR-21 + P226): folded coral and teal washi paper. A paper crane perches on the gun and flaps faster as your streak climbs, then takes off on inspect, the sides are covered in folded facets that open like pages, and every shot is a paper plane. The melee is the Origami Blade, which unfolds in your hand on inspect. Kill effect: Thousand Cranes.",
                "KINGYO MATSURI (M249 + SKS): a summer-festival goldfish stall in indigo and aqua. A paper goldfish lantern glows on top, clear water bags with goldfish swimming inside hang at the sides, scales shimmer with every shot and a glass wind chime swings under the barrel. Every shot is a little goldfish. The melee is the Kingyo Poi, a giant goldfish scoop whose goldfish leaps out on inspect. Kill effect: Kingyo Scoop.",
                "CLOUD NINE (MP40 + M590): a lavender and pink daydream. A sleepy little cloud rides the gun with Zzz drifting up and rains with every shot, then WAKES UP on a streak, a rainbow on each side grows a band with every streak step and cloud puffs drift along the sides. The melee is the Dream Pillow: pillow-fight whacks and a hug on inspect. Kill effect: Sweet Dreams.",
                "GACHA POP (PX4 + PKM): a capsule-toy machine in glossy red, pink and blue. The PKM carries a little gacha machine whose capsules empty with your ammo and refill on a reload, its crank turning with every shot; the PX4 has a capsule window in the grip. The melee is the Squeaky Hammer, which squeaks and squashes with every hit. Kill effect: Jackpot, with a toy in every capsule and a rarity roll on the banner.",
                "YAMI KAWAII (M60 + SR9): creepy-cute pastel goth in plum-black, pink and lilac with lace. A stitched plush bunny with little bat wings rides the gun, its button eye glowing on a big streak, a stitched heart beats on each side and little bats flutter out with every shot. The melee is the Batwing Parasol, which pops open and twirls on inspect. Kill effect: Night Night.",
                "RAMUNE SUMMER (GALIL + USAS-12): Japanese summer in sky blue and watermelon green. Glass ramune bottles on the sides drain with your ammo and their marbles rattle with every shot, a sunflower blooms wider as your streak climbs and the magazine wears a beach ball. The melee is the Watermelon Ice Pop: take a bite on inspect. Kill effect: Fizz Pop.",
                "MECHA IDOL (21E + EMR): a pastel robot pop star in idol pink, mint and navy. A chibi robo-idol head rides the gun, its LED visor turning to heart eyes on a big streak, heart power cores charge up on the sides and armour panels pulse. The melee is the Idol Mic: twirl it on inspect. Kill effect: Encore.",
                "FAIRY BLOOM (MK11 + Arc Projector): a flower fairy in lilac, pink and mint. Shimmering butterfly wings flutter on the gun, a wreath of daisies and tulips blooms one more flower with every streak step, dewdrops twinkle and the Arc Projector's beam turns petal pink. The melee is the Fairy Bouquet: take a sniff on inspect. Kill effect: Blossom Burst.",
                "Each set is a full bundle: two gun skins, a melee skin, gloves, sleeves, a health bar, a kill effect with its own kill banner, tracers, impacts and sounds.",
            } },
            { Head = "Melee skins come alive", Lines = {
                "Melee skins now show their full effects in your hand: moving parts, glows, swing trails and sparks. Before, none of them animated in first person.",
            } },
            { Head = "Bosses fight differently", Lines = {
                "Bosses no longer spray straight lasers in every direction. Each one keeps at most one line attack and gets new ones: GET IN or GET OUT rings, pie-slice QUADRANTS, rolling boulders, a trail that erupts behind you, shockwaves that close in from the walls and hazards that orbit the boss.",
                "The Goliath rolls boulders and slams the ground, the Phantom stalks your footsteps, the Sentinel lays orbiting mines, the Titan fires missile trails and sector barrages, and every superboss and trial boss got its own versions.",
            } },
            { Head = "More run variety", Lines = {
                "Six new precision boons: Long Shot, Point Blank, Fresh Brass, Quick Hands, Steady Aim and Surgeon, plus four combos: Sniper's Nest, Run and Gun, Speed Loader and Scalpel.",
                "Two new floor objectives: SHARPSHOOTER (clear the floor with 65% accuracy or better) and CHAIN REACTION (kill 3 enemies within 3 seconds of each other).",
                "Two new path modifiers: KEEP YOUR DISTANCE (hits from closer than 25 studs deal less) and EAGLE EYE (weak-spot hits deal more).",
            } },
            { Head = "Relics stand out", Lines = {
                "Relic guns wear a glowing crystal core and light seams on the receiver, so you can tell one apart from a normal gun of the same model at a glance (you and everyone around you).",
                "The crystal takes the colour of whatever skin the gun wears and finds a free spot on the receiver, so it never covers a skin's own decorations.",
                "Relics show their names in relic orange with a diamond (◆) in the stash, the equipped panel, tooltips, the weapon card and on the ground; the rarity still shows underneath.",
            } },
            { Head = "Fixes", Lines = {
                "Rounded skin decorations (petals, wings, ears and more) now keep their real oval shape instead of shrinking to a dot.",
                "The Dreamscape boss arena floor no longer glares white.",
                "Enraged bosses keep their ENRAGED tag on the health bar.",
                "Dreamscape and Neon Flats show their names and colours in the Challenges menu.",
                "The victory screen no longer mentions run loot (that system was removed).",
                "Dreamscape and Neon Flats draw a third fewer parts around their edges, for smoother play on lower-end devices.",
            } },
        },
    },
    {
        Id = 53, Version = "0.53", Date = "Oct 5, 2026", Title = "DREAMS AND HIGHWAYS",
        Sections = {
            { Head = "Two new biomes", Lines = {
                "DREAMSCAPE: a pastel dream night under a giant moon. Floating isles, doors to nowhere, broken stairways and melted clocks. Its enemies: Drowse, Paperbird, Mirage, Sleepwalker, Jellylamp and the Dreamweaver.",
                "NEON FLATS: a synthwave salt flat at dusk under a striped sun. Wrecked cars, billboards, power lines and mesas. Its enemies: Roadrunner, Tumble, Vulture, Billboard, Dust Devil and the Pylon.",
                "Two new superbosses: THE SANDMAN (shoot the dream sheep before three get across, or everyone falls asleep) and the HIGHWAY KING (shoot every nitro canister he drops on his lap and he wrecks himself).",
            } },
            { Head = "Exotics", Lines = {
                "The major bosses now drop RELICS: named items with one signature effect, two per class. Iron Choir, Twin Fang, Last Word, Dragon's Maw and Arc Lance are guns; the Quartermaster's Bandolier, Drifter's Boots, Hawkeye Visor, Bastion Shell and Prism Core are gear.",
                "Each major boss has its own relics (shown on its card). Your first clear of tiers I, V and X always drops one; otherwise the chance climbs with the tier. Their stats roll like any drop from that tier.",
                "You can wear one relic gear piece at a time.",
            } },
            { Head = "Enemies come alive", Lines = {
                "Every enemy is animated now: they bob and bank as they move, wind up before they attack, flinch when you hit them and break apart when they die. Wings flap, shards orbit, tails sway and eyes flare red as an attack builds.",
                "The first drones (Tracker, Strafer, Drifter, Juggernaut, Hopper, Charger, Sniper, Medic, Gunship) have new, more detailed models. Elite halos are a shimmering ring instead of a flat plate.",
            } },
            { Head = "The original bosses, reworked", Lines = {
                "From phase 2 each original trial boss has a new mechanic: the Archon's FALLEN WINGS, the Chronarch's CHIMES, the Echo Warden's MIRROR SEQUENCE and the Forgeheart's OVERHEAT. Do it to open a damage window; fail and the arena is wiped.",
                "Every Boss Trial now enrages after 7 minutes.",
                "The Goliath, Sentinel and Echo Warden have more detailed models.",
                "Hits on boss mechanic targets (locks, eggs, coins, orbs, vents) now count by your gun's fire rate, so slow guns like snipers can do every mechanic.",
            } },
            { Head = "A new look", Lines = {
                "New hand-made icons across the game: the side dock, the store, the welcome guide, the class picker and the biome titles.",
            } },
            { Head = "Fixes", Lines = {
                "Guns no longer go silent when their shot sound can't load: they play a standard shot instead.",
            } },
        },
    },
    {
        Id = 52, Version = "0.52", Date = "Oct 5, 2026", Title = "MAJOR BOSSES",
        Sections = {
            { Head = "Four major bosses", Lines = {
                "New in Challenges > BOSSES: four MAJOR bosses. They hit harder, take less damage outside their openings and ENRAGE after 7 minutes. They're where relics will drop (coming soon).",
                "THE LOCKWARDEN (Storm): four coloured locks on its body, four tiles of the same colours on the floor. A lock only breaks while someone stands on its tile. Break all four to open the vault.",
                "THE BROODMOTHER (Fire): pop every egg in her clutch before it hatches. Each hatchling sends her into a deeper FRENZY; clear a clutch and she's stunned. She burrows, webs the floor and climbs out of reach.",
                "THE DUELIST (Void): when it raises its GUARD, stop shooting: hits on the guard power its riposte, and holding your fire opens it up. After a lunge it's off balance. Later its cuts leave afterimages, then it challenges you to a DEATH DUEL.",
                "THE FORTUNE ENGINE (Cyber): it spins its reels and a HOUSE RULE takes over: shoot the coins, stand on the gold, ride the moving pad, double or nothing, or BUST.",
            } },
            { Head = "Boss Trials go to tier X", Lines = {
                "Every boss now has tiers VI to X (Ruin up to Singularity). Tiers VI+ need the difficulty's level and pay much more.",
            } },
            { Head = "Party up at the bosses", Lines = {
                "Each boss card has OPEN FRIENDS ROOM / OPEN PUBLIC ROOM and lists rooms you can join for that boss. The host starts it with WITH PARTY.",
            } },
            { Head = "Every gun sounds like itself", Lines = {
                "Gun shots are rebuilt from real recordings of each gun where one exists (Glock, Desert Eagle, USP, revolver, Uzi, MP5, P90, PPSh, Kriss, AK-47, M4A1, SCAR-H, F2000, G3, M60, 870, 590, Barrett, M14 and more). The rest use the closest gun of the same family and calibre. Fast-firing guns no longer share one sound.",
                "Skin sounds are built from their gun's new shot.",
            } },
            { Head = "Clearer attacks", Lines = {
                "Attack markers on the floor are more solid and easier to read.",
            } },
        },
    },
    {
        Id = 51, Version = "0.51", Date = "Oct 5, 2026", Title = "THE LADDER OF RARITY",
        Sections = {
            { Head = "A rarity for every difficulty", Lines = {
                "There are now 15 rarities. After Transcendent come ASTRAL, EMPYREAN, PRIMORDIAL, SOVEREIGN, ECLIPSE, GENESIS and INFINITE.",
                "Every difficulty adds one new top rarity: Easy drops up to Uncommon, Normal up to Rare, Hard up to Epic ... Singularity up to Infinite.",
                "Each difficulty's top rarity is very rare (about 1 in 200 drops). The tier below it is about 1 in 20, and most drops sit a few tiers lower. The lowest rarities get rarer as you climb and then stop dropping (no more Commons on the high tiers).",
                "The Dungeons window shows the top rarity each difficulty can drop.",
            } },
            { Head = "Higher rarities, better items", Lines = {
                "Every rarity hits a little harder and rolls stronger stats than the one before.",
                "Guns gain a new stat line every couple of rarities (up to 7), and gear up to 8. The rarest tiers roll their stats at the top grade.",
            } },
            { Head = "Traits have rarities", Lines = {
                "The rarer the gun, the likelier it carries a unique trait (Infinite guns always do).",
                "WHICH trait you get is its own roll with fixed odds, the same on any gun: Common traits are common, Legendary traits (Guillotine, Reaper's Toll, Overcharge) are rare. A trait's rarity shows on the gun.",
                "9 new traits: Steady Hands, Opening Volley, Quick Loader, Momentum, Brittle Rounds, Headhunter, Second Wind, Reaper's Toll and Overcharge.",
            } },
            { Head = "Enemies keep up", Lines = {
                "The high difficulties' enemies were retuned for the stronger loot, so each tier stays as challenging as before.",
            } },
        },
    },
    {
        Id = 50, Version = "0.50", Date = "Oct 5, 2026", Title = "TARGET LOOT",
        Sections = {
            { Head = "Choose what you're hunting", Lines = {
                "In the Dungeons window, set TARGET LOOT: one gun and one gear type (helmet, chest, legs, boots, ring or amulet). Your picks lock while you're in a run.",
                "Every chest you open builds toward a bonus drop of your picks, at your level. The meter is the chance each chest pays out; a full meter is a sure drop.",
                "DAILY RARE: once a day you get a rare drop of your gun and one of your gear, always from the better half of that difficulty's rarities. The very best tier is still only a chance.",
                "After the daily ones, chests keep building toward UNLIMITED target drops at the difficulty's normal odds, a little slower.",
                "Bigger chests count more (the end-of-floor chest double, a boss vault four times). Playing far below your level builds nothing, so pick a difficulty that fits you. Changing a pick restarts its unlimited meter.",
            } },
            { Head = "Every gun shows its class", Lines = {
                "Guns now say what they are and which class they're for, e.g. \"Assault Rifle  •  Vanguard\" or \"DMR  •  Marksman\", on tooltips, loot cards, your stash, the gun card and the target picker.",
            } },
            { Head = "Changes", Lines = {
                "Regenerating elites now heal a steady 1.25% of their health a second (it no longer pauses when you hit them).",
            } },
        },
    },
    {
        Id = 49, Version = "0.49", Date = "Oct 5, 2026", Title = "FULL CHAMBER",
        Sections = {
            { Head = "Real gun sounds", Lines = {
                "Every gun's shot is now built from real recordings of real guns, with a heavier low end and a short echo, so shots land with weight instead of sounding like a hit marker.",
                "Reloads use real handling recordings too: mags out and in, charging handles, slides, bolts, pumps, shells and revolver cylinders.",
                "Skinned guns now have their OWN full shot, built from the gun's real shot in the skin's style (plasma, deep water, thunder, bit-crushed, hydraulic, wooden, gong, hellfire, choir). Take the skin off and you'll hear the difference.",
                "Skins no longer replace your gun's reload sounds; their reload touches sit underneath, lower and softer.",
                "Hit sounds now climb in pitch while you keep hitting, and reset when you miss. Fast guns climb in small steps, slow guns in big ones, so every gun reaches the top after about the same time on target.",
            } },
            { Head = "Run summary", Lines = {
                "When a run ends (finished, extracted, out of lives or you leave), a summary shows your time, floors, kills, accuracy, total hits, weak-spot and crit rates, damage, DPS, biggest hit, damage taken, deaths, loot, gold and levels.",
                "In a party, everyone's run is in one table to compare accuracy, DPS, damage, kills and more. The best in each column is gold, and the table updates as your friends finish.",
            } },
            { Head = "Bosses you can actually play", Lines = {
                "While a boss mechanic needs you (coolant plates, glyphs, firewall nodes, lightning rods, mirror decoys, shield orbs, the Ascendant's trials), the boss stops its attack rotation and only throws one light, slow attack every few seconds.",
                "Between mechanics, bosses get about 10 seconds to attack properly, so a fight goes: dodge, do the mechanic, then burn the damage window.",
                "Every phase brings new attacks instead of faster copies of the old ones. New attacks include cages with one gap, checkerboard floors, walls that close in on your lane, crossing beams, shockwave ripples and slow spinning windmills.",
            } },
            { Head = "Passive skills: unlock, then equip", Lines = {
                "Every ★ passive skill you allocate on the tree is now unlocked for good. Equip up to 3 at a time in the new ★ PASSIVES menu in the tree, and swap them whenever you like.",
                "10 new passive skills sit at the far edge of the tree, past each class's Zenith: Untouched Aim, Marked Quarry, Slide Fire, Hot Streak, Charged Cell, Feedback Loop, Mercy Shot, Battering Ram, Walking Fire and Entrenched Gunner.",
            } },
            { Head = "Fixes", Lines = {
                "Regenerating elites heal slower (see 0.50).",
                "The dungeon window no longer reappears on your screen after you spawn into a floor.",
                "Melee skin kill effects work again.",
            } },
        },
    },
    {
        Id = 48, Version = "0.48", Date = "Oct 5, 2026", Title = "ARSENAL",
        Sections = {
            { Head = "24 new guns", Lines = {
                "LMGs: the M249, PKM, M60 and 21E. Belt-fed, a hundred rounds and a long reload. They count as Assault guns for the Vanguard.",
                "Assault rifles: the TAR-21, Galil and 416.",
                "SMGs: the MP40, PPSh-41 (a 71-round drum) and Vector.",
                "Shotguns: the USAS-12, KSG, 590 Pump and a Double Barrel that breaks open to reload.",
                "Pistols: the USP, P226, SR9 and PX4 Storm.",
                "Marksman and sniper rifles: the SVD, SKS (loaded from the top with clips), M40, EMR and Mk 11.",
                "The ARC PROJECTOR: the Arcwright finally has a class gun. Hold the trigger and one unbroken beam stays locked on whatever you track.",
                "Every new gun drops from enemies, chests and bosses like the others.",
            } },
            { Head = "Every gun sounds different", Lines = {
                "All guns, old and new, have brand-new shots built for that weapon: the AK-47 thumps and rattles, the M4 cracks, the shotguns boom, the snipers roll on for a second.",
                "New reload and handling sounds: mags out and in, bolts slamming home, pumps racking, shells loading, belt boxes opening.",
                "Skins have their own shot layered on top: plasma, sonar, thunder, glitch, hydraulics, wood, firecrackers and hellfire.",
                "New hit sounds for every Hit Sound choice in Settings, new kill sounds, and fresh enemy, boss and menu sounds.",
            } },
            { Head = "Boss arenas", Lines = {
                "Boss floors are real arenas now: you walk in through a gate onto one clean, round fighting floor where every attack marker reads clearly.",
                "MOLTEN: a basalt ring over a lava moat, ringed by forge spires and braziers. GLACIER: a frozen colosseum with tiered stands and crystal obelisks.",
                "VOID: a rune-circled altar with monoliths hanging in the dark. CYBER: a neon server core under a holo ring. STORMSPIRE: a crown of giant lightning rods.",
                "No more vantage towers, jump pads or wall-run panels in boss fights: four low barriers give cover, but there's nowhere to perch above an attack.",
            } },
            { Head = "Skies fixed", Lines = {
                "The biome skies no longer show seams overhead, and the painted sky now lines up with the scenery (the Molten eruption rises out of the volcano).",
            } },
            { Head = "Guns feel heavier", Lines = {
                "Recoil is now a spring: every shot snaps the gun back hard, it overshoots a touch and settles. Big guns kick slow and heavy, SMGs quick and tight.",
                "Seating a mag, slamming a bolt home, racking a pump or snapping a break-action shut jolts the gun in your hands.",
                "Drawing a gun swings it up past the hold and settles it with a little weight.",
            } },
        },
    },
    {
        Id = 47, Version = "0.47", Date = "Oct 5, 2026", Title = "NEW HORIZONS",
        Sections = {
            { Head = "Go back for your loot", Lines = {
                "Every floor's entry room has a blue BACK portal to the floor you just left. The loot you left on the ground is still there, the chest is open, and a blue portal brings you straight back.",
                "The way back closes once you step out into the new floor (or anything dies), so it can't be used to farm.",
                "Loot from a chest now always lands in a neat row in front of the chest, wherever you stood when you opened it.",
            } },
            { Head = "Every biome has its own sky", Lines = {
                "MOLTEN: a volcanic night under ash clouds lit by lava, with an erupting volcano on the horizon.",
                "GLACIER: a clear, freezing polar day with a halo round the sun and ice spires on the horizon (the aurora is gone).",
                "VOID: deep space, a nebula and a black hole, with floating islands around the arena.",
                "CYBER: a neon megacity of lit, stepped towers under a smog-lit sky with searchlights.",
                "STORMSPIRE: under a supercell: a heavy cloud deck, rain sheets and lightning in the clouds.",
            } },
            { Head = "Fairer bosses", Lines = {
                "No more one-shots: a single hit can take at most 70% of your health.",
                "Boss hits were eased on the harder tiers. A normal hit is now about 15% of your health on Easy and about a third on Singularity; heavy attacks still hurt a lot more.",
                "Heavy attacks always get a long, readable wind-up, even on the top tiers, and the hunting marks lock in place long enough to step out.",
            } },
            { Head = "Trials", Lines = {
                "Boss Trials and the Proving have separate SOLO and WITH PARTY buttons. Solo only ever takes you; With Party takes your whole party room (host only).",
            } },
            { Head = "Titles", Lines = {
                "New titles for clearing every difficulty from Torment to Singularity, for the Proving tiers, for 5,000 kills with each weapon class, and for 100,000 kills, 1,000 bosses and 100 superbosses.",
                "Some titles were renamed so they don't clash with the classes, and difficulty titles are rarer the higher up the ladder they are.",
            } },
            { Head = "Items and the hub", Lines = {
                "Items have a level requirement: you can wear gear and guns up to 5 item levels above your level (10 from level 200). Drops are always ones you can wear.",
                "Jump pads always land you on their platform, however you step onto them.",
                "The hub's back streets beside the gates no longer lead out of the city.",
                "Daily contracts are hidden while you're in a dungeon.",
            } },
        },
    },
    {
        Id = 46, Version = "0.46", Date = "Oct 5, 2026", Title = "WEAPON CLASSES",
        Sections = {
            { Head = "Five weapon classes", Lines = {
                "VANGUARD: assault rifles and LMGs. GUNSLINGER: SMGs and pistols. MARKSMAN: DMRs and snipers. BREACHER: shotguns. ARCWRIGHT: beam guns.",
                "You can still use any gun, but your class's passive skills and specialization only work while you hold one of your class's guns.",
                "Everyone picks a class again for free, and every passive point and specialization point was refunded.",
            } },
            { Head = "Passive skills", Lines = {
                "The stars on the passive tree are now class passive skills: 6 per class, each one a trade-off that changes how you play. Example: Marksman's Double Tap makes the second of two headshots in a row deal double damage (1.5x on bosses), every 7 seconds.",
                "You can have 3 passive skills at once, so pick the ones that fit how you shoot.",
                "Every passive skill hits a single target: nothing splashes or spreads.",
            } },
            { Head = "Tree and specializations", Lines = {
                "The tree was rebuilt round a shared centre: 3,703 nodes in five class areas, with weapon-type nodes back in each class's area.",
                "Melee is gone from the tree and the classes. Specializations: 3 per class, rebuilt for its guns.",
                "Enemies were re-tuned for the new tree.",
            } },
        },
    },
    {
        Id = 45, Version = "0.45", Date = "Oct 5, 2026", Title = "GEAR MATTERS",
        Sections = {
            { Head = "Three ceilings", Lines = {
                "Your passive tree, your attribute points and your gear now each have their own ceiling, and they add up. A great roll on gear always counts, even when your tree is at its cap.",
                "Hover a (capped) stat on your character sheet to see how much the tree, attributes and gear each give and where each one caps.",
                "Enemies were re-tuned for a geared character. From Brutal on, good gear is expected.",
            } },
            { Head = "Attributes", Lines = {
                "You get 1 attribute point a level plus 4 more every 10th level, and each point is worth more: Strength +1.5% damage, Dexterity +0.4% crit and +1.5% reload, Vitality +3% health, Luck +2.5% loot luck.",
                "Attributes have their own ceiling too, so spreading points pays off more than pumping one.",
                "Every attribute has been refunded once: spend your points again from the character sheet.",
            } },
            { Head = "Drops", Lines = {
                "Rarity odds were rebuilt. Each harder difficulty is a real step up for the rarest tiers, and loot luck now helps the rarest tiers the most instead of stopping at a cap.",
                "Rough first-drop times: Legendary about 3 hours on Easy, 20 minutes on Oblivion. Mythic about a day on Brutal, 8 hours on Oblivion, 2 hours on Singularity. Celestial and Transcendent are true chases.",
            } },
        },
    },
    {
        Id = 44, Version = "0.44", Date = "Oct 5, 2026", Title = "CLEAR SIGNS",
        Sections = {
            { Head = "Hub", Lines = {
                "The Dungeons and Challenges gates have a solid back wall: no more slipping through into the void.",
                "Station names are simple now: SHOP, FORGE, UPGRADE, STASH, SKILL TREE, INDEX, ARMORY and SEASON PASS.",
                "Signs are easier to read: plain titles, less glare, dark outlines. Two hanging boards that covered the gate signs moved down the street.",
            } },
            { Head = "Hit registration", Lines = {
                "Shots now include the mouse movement of the frame you clicked in. A flick and a click on the same frame used to fire from where you were a moment earlier.",
                "Aim Trial targets are solid instead of glowing, so what you see is exactly what you can hit.",
            } },
        },
    },
    {
        Id = 43, Version = "0.43", Date = "Oct 5, 2026", Title = "EARNED POWER",
        Sections = {
            { Head = "Stat ceilings", Lines = {
                "Every stat now has a ceiling set by your level: damage, fire rate, crit chance and damage, weak-spot damage, health, armor, speed, reload, magazine, luck, gold, leech, regen, proc chance, effects and every conditional bonus.",
                "Small bonuses still count almost fully; stacking one stat far past your level flattens out. The ceilings open up slowly, then fast near level 400, so the huge numbers (100% crit, +1000% damage) are end-game only.",
                "Your character sheet marks a stat as (capped) and shows what your bonuses add up to versus what they count for right now.",
                "Enemies at every monster level were re-tuned to match the new power curve.",
            } },
            { Head = "Fixes", Lines = {
                "Going through a portal to the next floor restores your health.",
                "Chests no longer sink into the ground on the open maps.",
                "The 'get to a safe circle' wipes (Ignis's Cataclysm and Supernova and the other bosses') place their safe circles within reach on open ground and always give at least 2 seconds.",
            } },
        },
    },
    {
        Id = 42, Version = "0.42", Date = "Oct 5, 2026", Title = "THE LADDER",
        Sections = {
            { Head = "Enemies have their own level now", Lines = {
                "Every difficulty has a fixed MONSTER LEVEL (shown in the Dungeons window), rising floor by floor. Enemies and bosses no longer copy your level.",
                "So levelling makes you stronger against everything: outgrow a difficulty, then climb to the next one.",
                "Enemies are built to match a well-built character of their level (passive tree, attributes and gear included), so on-level content stays a real fight.",
                "Loot drops at the monster level, gold follows it, and content far below your level gives much less XP. Punching above your level gives a little more.",
            } },
            { Head = "Six new difficulties", Lines = {
                "RUIN (monster level 100-130), DREAD (128-165), APOCALYPSE (160-205), ANNIHILATION (200-250), ETERNITY (245-310) and SINGULARITY (305-400).",
                "10 floors each, ending on a superboss, with more loot, better rarity odds, more XP and nastier enemies each step. They unlock by level and by clearing the tier below.",
            } },
            { Head = "Other", Lines = {
                "Attributes: type how many points to add in the new box next to RESET; every + spends that many at once.",
                "Party floors: everyone fights the floor's monster level.",
                "Floor bounties, Fortune, the gamble and the wandering merchant no longer cost or pay absurd amounts at high level.",
            } },
        },
    },
    {
        Id = 41, Version = "0.41", Date = "Oct 5, 2026", Title = "LIMITLESS",
        Sections = {
            { Head = "Level 400 and a far bigger tree", Lines = {
                "The level cap is now 400. Gear and enemies keep growing every level; big numbers are shortened (K, M, B, T, Qd...).",
                "Every level gives 1 passive point and every 5th level gives 5 more: 800 points at level 400. Your points were recalculated.",
                "The passive tree has grown from about 1,500 to almost 3,800 nodes: three new outer rings around every class, with new notables, gem sockets and an APEX notable for each class.",
                "New affix tiers T8, T9 and T10 drop on items of level 150, 250 and 350. New titles at levels 200, 300 and 400.",
            } },
            { Head = "Elements", Lines = {
                "Every enemy has a type: its own elemental mod, or else its biome. Burning, Freezing, Decaying and Bleeding guns deal 15% more to the type they beat and 15% less to the type that resists them.",
                "Molten is weak to Freezing, Cryo to Burning, Void to Bleeding, Cyber and Stormspire to Decaying. The floor's title card and your gun's tooltip show it; damage numbers get a small up or down arrow.",
            } },
            { Head = "Harder difficulties", Lines = {
                "From Nightmare up, more of every floor is fast, small, twitchy bots, plus a new one: the COMET, a very fast tracker that sweeps across you in smooth curves.",
                "The slow, tanky bots no longer crawl on high difficulties, and bots get a little smaller with every tier from Nightmare up.",
                "Boss movement and attack rhythm now follow your Bot Skill setting in dungeons.",
            } },
            { Head = "Fairer boss attacks", Lines = {
                "Attack areas only hit inside what's drawn (a little tighter than before), and party floors give you the benefit of the doubt for your connection.",
                "Shockwave rings and floor lasers now reach you while you stand on a platform: jump them instead.",
                "EYE OF THE STORM: the safe circle is bigger and the shockwave after it has a real warning (it used to hit everyone).",
                "Bots stuck behind cliffs or walls with no view of you now relocate after a few seconds.",
            } },
            { Head = "Balance", Lines = {
                "Shotguns now match rifles' damage; snipers deal a little less and their weak-spot bonus is lower (3x instead of 4x+). Your guns were updated.",
                "Burns, bleeds, chills and echoes are now the same share of your damage on every gun: slow guns proc more often but each proc is smaller.",
                "Equip Best always gives the same answer and now weighs your health and armour too.",
                "Rebirth Shards drop from 5% of bosses.",
            } },
            { Head = "Other", Lines = {
                "Weapon tooltips show what the gun does WITH YOUR BUILD (tree, gear, gems), and the comparison uses it.",
                "Class descriptions updated for the gun-agnostic tree. The specialization panel no longer lets the tree underneath light up.",
                "The hub and Training Grounds got some weathering: rust, rubble, loose wires and a broken sign or two.",
            } },
        },
    },
    {
        Id = 40, Version = "0.40", Date = "Oct 5, 2026", Title = "BACK LOT",
        Sections = {
            { Head = "Training Grounds", Lines = {
                "The Training Grounds moved into the walled city too: a back lot boxed in by tower blocks, with steel barriers between the bays, neon bay signs, sodium lamps and red lanterns over the firing line.",
                "Look for the big green range sign straight through the hub's south doorway.",
                "The bay pads and distance lines are visible again (they had sunk into the ground). Every bay works the same as before.",
            } },
            { Head = "Raids", Lines = {
                "Raids are off for now. They'll come back in a later update.",
            } },
        },
    },
    {
        Id = 39, Version = "0.39", Date = "Oct 5, 2026", Title = "THE PROVINGS",
        Sections = {
            { Head = "Five new superbosses", Lines = {
                "Every biome boss is a different creature now, each with its own mechanic. It shrugs off damage until your team does the mechanic, then opens up for a damage phase:",
                "IGNIS, THE FORGE TYRANT (Molten): stand on the lit coolant plates in order to crack its shell before it goes supernova.",
                "THE FROST SOVEREIGN (Cryo): break the frost crystals on its back. Get behind it when it turns away, or dodge it into a wall.",
                "THE UNBLINKING (Void): glyphs flash a sequence. Shoot them in the same order, then fight from inside the light well.",
                "OMNISCIENCE CORE (Cyber): track and break the firewall nodes as they race round the arena.",
                "TEMPEST SOVEREIGN (Stormspire): when you're Stormcharged, run to a lightning rod to ground the storm.",
                "A run no longer repeats bosses: mini-bosses rotate through all three before any comes back, and the big boss is one you haven't fought yet this run.",
            } },
            { Head = "The Proving", Lines = {
                "Specialization points come from the new PROVING (Challenges > PROVING): two hard floors, then THE ASCENDANT.",
                "Four trials, unlocked at levels 15, 35, 55 and 75. Each one's first clear gives 2 specialization points (8 in all). Every clear pays gold, Prism and an item.",
                "Already earned points from Boss Trials? You keep them.",
                "Boss Trials and the Proving can be played with a party: the room's host starts it, and the boss has x2 / x3 / x4 health.",
            } },
            { Head = "Passive tree: no more gun types", Lines = {
                "Nodes that only worked with one gun type (rifles, heavy guns, pistols...) now work with ANY gun, based on how you play:",
                "Close Range (within 25 studs), Long Range (60+ studs), Fresh Load (3 s after a reload), Opening Rounds (70%+ of your magazine left), Moving and Braced (standing still).",
                "The cornerstones and specializations that named a gun type work the same way now. Pistoleer is now Fastdraw.",
            } },
            { Head = "Fixes", Lines = {
                "The safe room's roof no longer flickers.",
                "A giant tower no longer stands inside the Cyber safe room.",
            } },
        },
    },
    {
        Id = 38, Version = "0.38", Date = "Oct 5, 2026", Title = "THE WALLED CITY",
        Sections = {
            { Head = "A new hub", Lines = {
                "The hub has moved into a walled city at night: towering patched-together apartment blocks close in on a wet, neon-lit street.",
                "Every station is a shopfront now (roll-up shutters, awnings, glowing signs, cluttered shelves), in the same spot as before.",
                "The Dungeons and Challenges rifts sit in neon-framed alley mouths at the north end; the Training Grounds doorway is at the south end.",
                "Red lantern strings, tangled cables, hanging street signs, vending machines, an arcade corner, food carts and steam vents fill the streets.",
                "The waypoint is a neon kiosk in a raised planter, with the rings glowing above it as a hologram.",
                "Everything still works the same: stations, the teleport menu, leaderboards and the Training Grounds.",
            } },
        },
    },
    {
        Id = 37, Version = "0.37", Date = "Oct 5, 2026", Title = "THE LONG ROAD",
        Sections = {
            { Head = "Leveling, reworked", Lines = {
                "Leveling follows a steady pace now: roughly 7 to 8 hours of play to reach level 50, about 25 hours for 75 and around 70 hours for 100 (faster if you clear quickly or aim well).",
                "Harder difficulties still pay more XP, but no longer many times more: the climb doesn't crawl and then suddenly rocket once a new difficulty opens.",
                "In a long run, every floor now matches your current level (enemies and their XP keep up as you level).",
            } },
            { Head = "Fixes", Lines = {
                "Respawning in the safe room while a boss was mid-attack could still hurt you: you're now protected for a moment after every respawn.",
                "The hub well is a proper well: a raised stone ring round an open shaft, a bucket on a rope, and a closed roof.",
                "The waypoint stone in the middle of the hub had a huge invisible wall round it: you can walk right up to it now.",
                "The leaderboards are no longer blocked by the wall pillars.",
                "Party: a floor your team already cleared stays cleared. Catch up later and it's empty, with its chest and portals waiting (it used to fill back up with enemies).",
                "Party: other floors' attacks no longer set off your danger warning, and their effects (beams, fire, sparks) no longer show on your floor.",
            } },
        },
    },
    {
        Id = 36, Version = "0.36", Date = "Oct 5, 2026", Title = "HORIZONS",
        Sections = {
            { Head = "The world goes on past the arena", Lines = {
                "Skies aren't black any more: every biome has its own time of day and sky colour (a Molten sunset, a Cryo dawn, Void and Cyber dusk, a grey Storm day).",
                "Far mountains ring every open map, snowy on Cryo, smouldering on Molten, and the land carries on to the horizon. Cyber maps have a city skyline out to the edge.",
            } },
            { Head = "Bosses", Lines = {
                "Easy and Normal runs no longer always end on the Apex Titan: the finale is the Titan or that floor's biome boss (at the Titan's strength).",
                "Head hitboxes: shots on the top of a boss's head (or any edge of it) count now. The server was throwing them out while the boss moved.",
                "The Omniscience Core's firewall nodes hold still now instead of jittering around.",
            } },
            { Head = "Passive tree", Lines = {
                "Small nodes give small buffs now (around +4 to an attribute, +4% damage), notables give big ones, cornerstones stay the big rule-changers. Your total from a full path is about the same, just concentrated in the notables.",
                "Loot luck can now reach +125% (was +75%) as a trial.",
            } },
            { Head = "Fixes", Lines = {
                "Party: another floor's enemy health bars no longer float over yours.",
                "The entry room floor no longer flickers.",
                "Prop hitboxes are smaller, so the invisible edges of rocks and props stop eating your shots.",
            } },
        },
    },
    {
        Id = 35, Version = "0.35", Date = "Oct 5, 2026", Title = "EVERY BOSS IS DIFFERENT",
        Sections = {
            { Head = "Every boss has its own fight", Lines = {
                "GOLIATH: its front is armoured. Bait its charge: it skids to a stop facing away, so shoot the glowing backplate. Enough back hits break its posture and it kneels.",
                "PHANTOM: never stands still. In its mirror dance it splits into copies that fire at you; only the one with the glowing head is real.",
                "SENTINEL: its shield always faces you, so flank it. After its pulse rings it vents and the core comes out.",
                "APEX TITAN: break its two shoulder cannons. Its hull takes half damage while one stands; with both gone it overloads and kneels, then rebuilds them.",
                "IGNIS (Molten): it leaps round the arena and keeps heating up. Shoot its blazing core to cool it, or it goes supernova at 100%.",
                "FROST SOVEREIGN (Cryo): it skates at you along a marked lane. Dodge so it slams into a wall and it's dazed.",
                "VOID OVERLORD: it only takes full damage while you stand in one of the wells of light, and the wells move.",
                "OMNISCIENCE CORE (Cyber): firewall nodes shield it at each phase. Break them to stagger it. (No other boss uses this any more.)",
                "TEMPEST SOVEREIGN (Storm): it rides the lightning in fast zig-zag dashes, then lands grounded and wide open.",
                "Bosses are harder to hit: they strafe across your aim and dodge to the side. The bar under each boss shows its mechanic (posture, heat, cannons...).",
            } },
            { Head = "Attacks are easier to read", Lines = {
                "Every attack area has a solid bright red edge now, and the fill is more solid.",
                "On the open maps, attack areas sat partly under the ground. They're drawn on top of the terrain now.",
                "Standing in an attack: the screen edges glow red, and MOVE! flashes over your crosshair.",
            } },
            { Head = "Fixes", Lines = {
                "Props never spawn in front of the portals (or the path you walk to them).",
                "The class picker no longer pops up in the middle of a dungeon.",
                "A boss's damage state could carry over onto the next floor's boss.",
            } },
        },
    },
    {
        Id = 34, Version = "0.34", Date = "Oct 5, 2026", Title = "RAIDS",
        Sections = {
            { Head = "Raids: 8-12 players", Lines = {
                "New game type in the Dungeons menu: RAID. Open a Public or Friends raid room (up to 12) and start once 8 are in.",
                "Three floors, scaled to the raid's size, ending on a RAID BOSS: the biome superboss with more shield orbs, so the whole team has to split up and shoot.",
                "Everyone there for the kill gets a guaranteed Legendary, on top of the usual run rewards.",
            } },
            { Head = "Bosses: break the shield", Lines = {
                "At each phase change a boss raises a SHIELD and becomes immune. Glowing orbs float round the arena, each tethered to it by a beam.",
                "Shoot every orb to break the shield: the boss is STAGGERED, stops attacking and takes 75% more damage for 6 seconds. That's your damage phase.",
                "Too slow and the orbs OVERLOAD: each one still up blasts where you stand, then they reform.",
            } },
            { Head = "Your own instance", Lines = {
                "You only see and hear players who are in the same place as you. Other players' runs, your own Training Grounds lane and party members who went on through a portal are all hidden, and so are their sounds and shots.",
                "The hub is still shared, so you can meet people there.",
            } },
            { Head = "Inventory", Lines = {
                "The EQUIPPED column is laid out round your character now: your gun and melee up top, helmet, chest, legs and boots down the middle, rings and amulet on the sides, your total DPS and defence in the corners.",
                "Bigger WEAPONS, GEAR and SORT buttons. Click an empty gear slot to jump to the gear stash.",
            } },
            { Head = "Daily contracts pay more", Lines = {
                "Every contract shows its reward. Easy ones pay 300 gold and materials, medium ones 450 gold and a Rare item, hard ones 650 gold, a Prism Shard and an Epic item.",
                "Finish all three for a skill gem, 2 Prism Shards and an Epic-or-better item (15% Legendary).",
            } },
            { Head = "Balance", Lines = {
                "Loot luck from Luck, gear and the tree now has diminishing returns and can never pass +75%. Luck's proc chance is 0.2% a point, at most +12%. Luck-stacking farm builds were far ahead of everything else.",
                "\"At least Rare / Epic / Legendary\" drops are now a real guarantee (they could miss before).",
            } },
            { Head = "Fixes", Lines = {
                "Dungeon entrances are clear: the cliffs and props round the new maps no longer block the way in (Boss Trials no longer trap you in the entry room).",
                "Enemies no longer look like they glide through rock, and the Molten rock piles are all different now.",
                "Enemy health bars: the old name tag no longer shows next to the new bar (no more doubled names).",
                "Skill tree: clicks no longer close it. Standing at the Skill Monolith, its interact prompt floated over the tree window and took the clicks (the station then toggled the tree shut). Prompts now hide while any window is open, and a station only ever opens its window.",
                "Outlines are white by default, and show through walls by default. Camera recoil is gone (always off).",
                "Hub: the two gates' arches sit square round their portals and mirror each other, the well has a proper peaked roof, all four plaza lanterns are lit, the props sit in the dusk light, and the Training Grounds' back wall is plain stone.",
                "A new player can pick their class in their first dungeon.",
            } },
        },
    },
    {
        Id = 33, Version = "0.33", Date = "Oct 5, 2026", Title = "FRONTIER",
        Sections = {
            { Head = "A new hub: the Frontier Keep", Lines = {
                "The hub is now an open-air walled outpost at dusk: curtain walls and watchtowers, a cobbled plaza round the WAYPOINT obelisk, braziers, banners and lanterns.",
                "Every station has its own building round the plaza: the Black Market stall and cart, the Weapon Forge with its chimney and sparks, the Upgrade Anvil's war tent, the Arsenal Vault bunker, the Skill Monolith's standing stones, the Codex scribe tent, the Armory racks and the Season stage.",
                "The two great gates stand at the north end: the Dungeons rift inside a ruined arch, and the Challenges gate with its banners. Leaderboards hang on carved notice boards.",
                "The Training Grounds are an open firing yard behind the keep: timber bays, wooden backstops and braziers. Everything in it works as before.",
            } },
            { Head = "Arenas are real places now", Lines = {
                "The combat room's box walls are gone. Every floor is built from one of 15 MAPS, three per biome: a lava caldera under a smoking volcano, a ruined foundry, a frozen monastery, a pine hollow, floating isles over the void, a storm-lashed lighthouse cliff, a tesla works, a neon rooftop and more.",
                "Cliffs, ruins and chasm edges ring the fight, cover pieces are rock outcrops and props from the biome, and big landmarks rise beyond the edge.",
                "The fight itself is unchanged: same arena size, entrance, portals, chest, jump pads and climbing routes. Enemies path round the new cover.",
                "Built to run on anything: every map stays inside the old floor's budget for parts, lights and particles.",
            } },
        },
    },
    {
        Id = 32, Version = "0.32", Date = "Oct 5, 2026", Title = "ASCENSION TREE",
        Sections = {
            { Head = "A brand new passive tree", Lines = {
                "Over 1,500 nodes. Zoom out (scroll / pinch) to see all of it, drag to move around, and use the search box to light up anything (try \"crit\", \"burn\" or \"pistol\").",
                "Small nodes on the paths, notables in every cluster, 38 cornerstones at the rim and gem sockets along the way. Notables now favour gun types too: pistol, SMG, rifle, shotgun, sniper and heavy-gun clusters.",
                "Heavy guns are any gun that fires 3 times a second or slower: snipers, pump shotguns and hand cannons.",
                "Points: 1 per level plus an extra on every 4th level from 8, 123 at level 100. Everyone's tree has been refunded for free.",
            } },
            { Head = "Classes", Lines = {
                "Pick one of seven classes when you join: Marksman, Gunslinger, Hexslinger, Bulwark, Reaper, Demolisher or the Drifter in the centre. Your class decides where your tree starts. You can still path anywhere.",
                "Change class with the CHANGE CLASS button in the passive tree. It costs a REBIRTH SHARD: a rare drop from bosses (best from Boss Trials), or buy one in the Change Class window. Your tree and specialization are refunded.",
            } },
            { Head = "Ascendancies", Lines = {
                "Each class has 3 specializations with their own mini-tree of game-changing notables: marking targets, every 5th shot a guaranteed crit, cheating death, spreading ailments on kills and much more.",
                "Earn specialization points from BOSS TRIALS: 2 for each tier you clear (your best tier on any trial boss), up to 8 at tier IV. Spend them from the SPECIALIZATION button at the top of the passive tree.",
            } },
        },
    },
    {
        Id = 31, Version = "0.31", Date = "Oct 5, 2026", Title = "LEARN THE FIGHT",
        Sections = {
            { Head = "Every boss rebuilt", Lines = {
                "Bosses now fight in a FIXED ORDER of moves. The same every time, so you can learn it. The boss bar names each move as it starts.",
                "One attack at a time, then a short breather: that's your window to deal damage. New moves join the order at 2/3 and 1/3 health.",
                "No more constant hazards raining on you between moves, and attacks land where you ARE, not where you're heading, moving dodges them.",
                "No more teleporting on top of you: the Phantom shows where it's going and glides there, far from you; the Echo Warden leaps where you stood. Bosses keep their distance and stand still while they attack.",
                "Minibosses (Goliath, Phantom, Sentinel) fight at a gentler tempo than the big bosses: more time to react to every attack and longer breathers between moves.",
            } },
            { Head = "Health", Lines = {
                "Your health bar is now big and front and centre at the bottom of the screen. Hits shake it and show the chunk you just lost before it drains, a damage number pops up, and it pulses red when you're low.",
                "The HEALTH GATE is gone: with every boss attack telegraphed, a killing blow now kills at any health. Watch the red.",
                "Your weapon card moved to the bottom-left corner under your level.",
            } },
            { Head = "Fixes", Lines = {
                "The FIXATION counter no longer sits in the middle of the screen in the hub. It shows only while you have stacks.",
                "Skinned guns no longer float off your back (the Ironclad M4 Super 90 hovered over your shoulder).",
                "The Tempest M82 and Scout are rebuilt: storm-indigo armour with glowing lightning seams and a glass tesla barrel with a bolt crackling inside.",
            } },
        },
    },
    {
        Id = 30, Version = "0.30", Date = "Oct 5, 2026", Title = "ARSENAL",
        Sections = {
            { Head = "New set: SOLARIS ECLIPSE", Lines = {
                "A captured sun in mirror-black chrome and deep gold for the AWP and the Desert Eagle, plus the Solar Khopesh, Corona Gauntlets, Solaris Sleeves and a Solaris Eclipse health bar.",
                "Every shot SPENDS the sun: its core goes dark and recharges, lighting the pips round it (and the rings down the AWP barrel) one by one. A solar flare leaps over it and a crown of rays at the muzzle bursts.",
                "Inspect it and the moon ECLIPSES the core, with a blazing corona and a diamond-ring flash. Planets orbit the core as your kill streak climbs.",
                "Sunbeam tracers that pinch out, molten scorch marks, the SUPERNOVA kill effect and a SUNRISE kill banner that climbs higher with every kill.",
                "The health bar's sun is eclipsed by the moon as the enemy's health drops.",
            } },
            { Head = "New set: ABYSSAL TIDE", Lines = {
                "A bioluminescent deep-sea predator for the AUG and the MP5, plus the Abyssal Fang, Leviathan Grips, Abyssal Sleeves and an Abyssal Tide health bar.",
                "Its glass tank and the gauge on top hold glowing water that drains as you empty the magazine and floods back with a rush of bubbles when you reload.",
                "An angler's lure sways over the muzzle and blazes on every kill, fins ripple along the gun, and inspecting it sends SONAR pings racing down it.",
                "Water-jet tracers, splash-crown impacts, the LEVIATHAN kill effect (a waterspout, then a jaw of glass fangs snaps shut) and a DEPTH GAUGE kill banner.",
            } },
            { Head = "New set: TEMPEST", Lines = {
                "A captured thunderstorm for the M82 and the Scout, plus the Stormcaller war hammer, Tempest Gauntlets, Tempest Sleeves and a Tempest health bar.",
                "Deep storm-indigo armour split by glowing lightning seams, and a glass tesla barrel wound in copper with a bolt of lightning crackling inside it.",
                "Storm cells flicker with lightning, arcs crackle along a rail of tesla coils (faster and violet as your streak climbs) and the forked muzzle DISCHARGES with every shot.",
                "It's struck by lightning when you draw it; inspect it and a THUNDERHEAD gathers overhead and strikes it. Reloading slides its capacitor plates open.",
                "Bolt tracers, crawling arc impacts, the THUNDERSTRIKE kill effect and a VOLTAGE kill banner whose needle climbs with your streak.",
            } },
            { Head = "New set: NEON OVERRIDE", Lines = {
                "A hacked weapon in void black and deep magenta for the P90 and the MP7, plus the Override Edge hard-light blade, the Override Rig gloves, Override Sleeves and a Neon Override health bar.",
                "A holographic screen over the gun shows your LIVE ammo count. It boots up when you draw it, shows SYNC % while you reload and flashes with every shot.",
                "It glitches into magenta / cyan RGB ghosts every few seconds (more often as your streak climbs), code streams down its sides, and inspecting it splits its plates open under an OVERRIDE sigil.",
                "Data-packet tracers, pixel impacts, the DEREZ kill effect (the target breaks into voxels) and a TERMINAL kill banner that types out the hack. The health bar shows a live percentage.",
            } },
            { Head = "New set: IRONCLAD (three shotguns)", Lines = {
                "Heavy industrial mech gear for the 870, the M4 Super 90 and the AA-12, plus the Breacher axe, Ironclad Gauntlets, Ironclad Sleeves and an Ironclad health bar.",
                "A side-saddle of real shells empties as you fire and loads back one by one when you reload. Hydraulic pistons slam forward with every shot and the exhaust puffs smoke.",
                "A warning beacon turns on top, racing and red when you're low. Inspect it to LOCK DOWN: the armour slides back and a targeting laser sweeps.",
                "Slug tracers, spark impacts, the HYDRAULIC PRESS kill effect and a MECH HUD kill banner.",
            } },
            { Head = "New set: VERDANT", Lines = {
                "A living weapon of heartwood and moss-green bronze, veined with glowing amber sap, for the Uzi and the TEC-9, plus the Leafblade, Rootbound Grips, Verdant Sleeves and a Verdant health bar.",
                "Its vines GROW with your kill streak until it's fully overgrown and in bloom. Its leaves sprout when you draw it, fold shut while you reload, and a leaf falls with every shot.",
                "Inspect it and its buds open into flowers. Seed tracers, sprouting impacts, the OVERGROWTH kill effect and a BLOOM kill banner that opens a petal per kill.",
            } },
            { Head = "New set: JADE DYNASTY", Lines = {
                "Carved jade, black lacquer and imperial gold for the G17 and the Rhino, plus the Jade Jian sword, Dragonscale Bracers, Jade Dynasty Sleeves and a Jade Dynasty health bar.",
                "A serpent dragon coils along the gun, rippling, whiskers whipping with every shot, chasing a flaming pearl that burns brighter with your streak. A silk tassel with gold coins swings from the grip.",
                "Inspect it and the dragon AWAKENS. Coin tracers, firecracker impacts, the DRAGON DANCE kill effect and a SEAL kill banner.",
                "Every gun in the game now has a premium skin.",
            } },
            { Head = "Everyone sees it", Lines = {
                "Premium skins now show their own tracers on other players' shots, and their animations play on other players' guns.",
            } },
        },
    },
    {
        Id = 29, Version = "0.29", Date = "Oct 4, 2026", Title = "SHORT RUNS",
        Sections = {
            { Head = "Runs", Lines = {
                "Runs are much shorter: Easy and Normal 5 floors, Hard and Brutal 6, Nightmare and Torment 8, Cataclysm and Oblivion 10. Each still ends on its biggest boss.",
                "Bosses come sooner: mini-bosses on floor 2 or 3, major bosses mid-run.",
                "Difficulties unlock in order now: clear a full run on the one below (and reach its level) to open the next. Anything you've already beaten stays open.",
            } },
            { Head = "Loot", Lines = {
                "Harder difficulties give far better rarity odds (up to 10x on Oblivion).",
                "LOST LOOT: Legendary or better drops you leave on the floor are saved. Buy them back from the hub dock any time.",
                "Titles that needed long runs now ask for the new run lengths.",
            } },
            { Head = "Parties", Lines = {
                "Portals take only the player who walks in. Teammates follow when they're ready, through as many portals as they need, so nobody loses loot on the floor.",
                "When the dungeon is finished your cursor comes up so you can pick KEEP LOOTING or RETURN TO HUB.",
            } },
            { Head = "Cosmetics + names", Lines = {
                "New SERAPHIM ASCENDANT health bar: pearl and gold filigree, beating wings, a halo and drifting feathers. It's part of the Seraphim Ascendant bundle (bundle owners get it automatically).",
                "The Infernal Scythe's blade now reaches forward toward your crosshair instead of curling back at you.",
                "Guns go by their model names now (AUG, MP5, SCAR-H, G17...), without the maker. Guns you already own are renamed too.",
                "Cleaner window titles in the stash and the Codex.",
            } },
        },
    },
    {
        Id = 28, Version = "0.28", Date = "Oct 4, 2026", Title = "FATE",
        Sections = {
            { Head = "Progression", Lines = {
                "Levelling is 20% faster.",
                "You get 1 passive point per level, and 5 on every 5th level. Existing characters got the extra points for the levels they already have.",
                "New RESET button on the character panel: take back every attribute point for free and spend them again.",
            } },
            { Head = "Movement", Lines = {
                "Switching direction mid-hop works: hold A + Space, then switch to D, and your speed swings straight over to the new side instead of dying. The same goes for W and S.",
            } },
            { Head = "Fire rate", Lines = {
                "Dexterity now gives +0.25% crit chance and +1% reload speed per point. It no longer adds fire rate.",
                "Fire rate bonuses past +40% count for a third, and they stop at +80%, so every gun keeps its own feel instead of turning into a minigun.",
                "The passive tree has far fewer fire rate nodes (15 down to 6, all on the Gunslinger side). The ones that left became magazine, reload, crit and ailment nodes.",
            } },
            { Head = "Fate Shards", Lines = {
                "A new, exceptionally rare currency: 0.05% from any enemy, 0.5% from bosses.",
                "Spend one at the Forge to reroll a weapon's unique trait into a different one.",
            } },
            { Head = "Cosmetics", Lines = {
                "The store and locker now carry only the Seraphim Ascendant and Infernal Pact sets while the rest are remade. Anything you own stays in your save.",
                "The Seraphim UI theme no longer unlocks at level 10: it comes only with the Seraphim Ascendant bundle.",
                "UI themes keep the game's own fonts now, so text looks the same whichever theme you wear.",
                "New KILL EFFECTS tab in Cosmetics: Match My Skin, Off, or a set's effect (Ascension, Claimed) on every kill with any weapon. You own a set's effect with any skin from that set.",
                "Fixed avatars' arms poking through gloves and sleeves (the arm under a full glove + sleeve is hidden now).",
                "The Infernal Scythe is held in both hands across your body, with its own swings and its own inspect.",
                "Fixed sleeves flickering where they meet your arms and gloves.",
            } },
            { Head = "Interface", Lines = {
                "Windows no longer shake or bounce when they open, and text has no outline.",
                "EQUIP BEST sits in the Equipped column now, so it no longer covers the window title.",
                "Your title above your head and on the HUD, and the health and level bars, match the Mega-City look.",
            } },
        },
    },
    {
        Id = 27, Version = "0.27", Date = "Oct 4, 2026", Title = "MEGA-CITY",
        Sections = {
            { Head = "A new look", Lines = {
                "The whole interface has been rebuilt in a hard-edged Mega-City style: gunmetal panels, Justice-gold accents, hazard stripes and condensed type. Menus snap open instead of bouncing.",
                "The welcome guide, side dock, stash, store, the in-run HUD and the hub's station signs all share the new look.",
                "Fixed stat text like \"-60% Increased Armor\": penalties now read \"60% Reduced Armor\" and \"10% Less Damage\".",
            } },
            { Head = "Difficulties and Endless", Lines = {
                "Three new difficulties above Nightmare: TORMENT, CATACLYSM and OBLIVION (30 floors each). Each one hits harder and pays more.",
                "The rarest loot now comes from the top difficulties: Mythic from Brutal, Celestial from Torment and Transcendent only on Oblivion.",
                "ENDLESS is now its own game type. Pick ENDLESS in the Dungeons window, then any difficulty: the floors never end, with a boss every 5th floor, at that difficulty's toughness and loot.",
                "Bot skill 10 is now called CELESTIAL.",
            } },
            { Head = "Fewer, tougher rooms", Lines = {
                "Rooms have far fewer enemies: 4 to start, plus 1 more every 5 floors, on every difficulty. Harder difficulties make each enemy tougher instead.",
                "Enemies no longer mirror your movement. Each one holds its own spot and repositions on its own timer.",
            } },
            { Head = "Gameplay", Lines = {
                "Your stash works in a run again: open it with TAB and equip what you find.",
                "Air strafing: switching from one side to the other mid-jump now swings your speed over to the new direction instead of stopping you. Holding both keys now follows the one you pressed last.",
                "Party runs: enemies are now scaled to YOUR level on your screen. A lower-level player is no longer stuck fighting enemies tuned for the highest level in the party, and kills pay out at your own level.",
                "Recoil affixes are gone (recoil is a setting). Weapons that had one now carry Effect Duration instead, and the tree's Steady Breath nodes are now Steady Aim (weak-spot damage).",
            } },
            { Head = "Cosmetics", Lines = {
                "Every sleeve has been rebuilt with layered plates, cuffs and details of its own, and sleeve and glove textures no longer flicker against your arms.",
                "The Infernal Scythe is held at a new angle with its blade sweeping back over the shaft like a bat wing.",
            } },
        },
    },
    {
        Id = 26, Version = "0.26.1", Date = "Oct 4, 2026", Title = "KEEP WHAT YOU FIND",
        Sections = {
            { Head = "Loot is never at risk", Lines = {
                "Everything you pick up in a run is yours straight away, even if you die or leave early.",
                "No more extraction portals, run bag or lost-gear buy-back.",
            } },
            { Head = "Compare items", Lines = {
                "Hover an item and hold SHIFT to see your equipped item's full stats beside it.",
                "Item stat cards no longer run off the right side of the screen.",
            } },
            { Head = "Multiplayer", Lines = {
                "You can now see and hear other players shooting: muzzle flash, tracer and their gun's sound.",
                "Other players hold their gun in the training grounds instead of wearing it on their back.",
            } },
            { Head = "Fixes", Lines = {
                "Fixed arenas with no enemies in them: waiting in the safe room or respawning made every enemy vanish.",
                "Free Cursor (Left Alt) is now hold-to-use. Alt-Tabbing used to leave the cursor on screen and block your dash.",
                "Loot from a chest no longer lands inside the chest, and a chest's open prompt goes away once you've opened it.",
                "Enemies spread out instead of lining up in a wall, and step out of arena props they get stuck in.",
            } },
        },
    },
    {
        Id = 25, Version = "0.26", Date = "Oct 4, 2026", Title = "ASCENSION",
        Sections = {
            { Head = "Two new rarities", Lines = {
                "CELESTIAL (sky cyan) and TRANSCENDENT (prismatic) sit above Mythic. Celestial drops on Nightmare and Endless; Transcendent only on Endless, and it is very rare.",
                "Celestial weapons have two top-tier affixes and often a unique trait. Transcendent weapons have every affix at the top tier, always carry a trait and an elemental prefix, and deal the most damage of any rarity.",
                "Celestial gear rolls 5 stats, Transcendent gear 6. Both can be upgraded to +20.",
            } },
            { Head = "Level cap 100", Lines = {
                "The level cap is now 100 (was 60). Every level still gives a skill point and two attribute points.",
                "Past level 60 the world gets stronger more gently, so a gun a few levels old stays useful for longer.",
                "Items from level 70 can roll a new tier 6 affix, and from level 85 a tier 7 affix, stronger than anything before.",
                "New titles: Veteran (level 80) and Centurion (level 100). Paragon now starts at level 100. If you already unlocked Paragon, you keep your points and board.",
            } },
            { Head = "Choose your path", Lines = {
                "After you clear a floor, two or three portals offer different versions of the next floor. Each one shows its modifiers and reward bonus above it.",
                "CALM: no extra danger, a small gift (gold, a loot goblin or a supply cache). RISKY: one hard modifier and a better gift (an Armory item, a boon shrine or a goblin). DEADLY: two hard modifiers and a War Vault.",
                "New floor rewards: ARMORY (a guaranteed Rare or better item when you clear the floor), WAR VAULT (Epic or better) and SUPPLY CACHE (a pile of upgrade materials).",
                "Boss floors, Rifts, the Daily Challenge and party runs keep a single portal.",
                "WANDERING MERCHANT: a calm or risky path can lead to a floor with a merchant's stall by the entrance. Spend gold on an Armory Crate (a Rare or better item), a Boon Charm (a random boon) or Field Supplies (a full heal and upgrade materials). Prices grow with your level.",
            } },
            { Head = "Floor objectives", Lines = {
                "Some floors now carry an optional objective, shown under the floor modifiers. Pull it off for a reward on top of the floor's loot. Fail it and nothing is lost.",
                "BOUNTY: one enemy wears a gold skull and is tougher. Kill it in time. PRECISION: land a number of weak-spot kills. UNTOUCHABLE: clear the floor without getting hit.",
                "BLITZ: clear the floor in time. FOCUS: reach a 12-stack Focus streak.",
                "Timers start when you walk out of the entry room.",
            } },
            { Head = "Boon combos", Lines = {
                "16 boon combos. Hold both boons of a pair and the combo switches on for the rest of the run, adding its own bonus on top.",
                "For example: Incendiary + Cryo Rounds = THERMAL SHOCK, Headhunter + Keen Eye = DEADSHOT, Kill Rush + Overflow = AVALANCHE, Glass Jaw + Reckless = DEATH WISH.",
                "A boon card tells you when picking it would finish a combo, and boon offers lean toward boons that finish one you're halfway into. Active combos show in your boon tray.",
            } },
            { Head = "The INFERNAL set", Lines = {
                "A new premium set in the Store, the devil to the Seraphim set's angel. INFERNAL SCAR-H and F2000: a caged demon that runs on heat and souls. Keep firing and it heats up (white-hot cracks, vents that open and smoke), its fanged maw snaps with every shot, a demon eye opens when you inspect, and claimed souls burn in vials on the handguard. Hellfire whip tracers claw-mark whatever they hit.",
                "Every kill with an Infernal weapon is CLAIMED: the light is sucked into the body, the ground splits open, chains lash out of it and the soul flies into your gun. Your kill banner sears a tally mark per kill: CLAIMED, DAMNED, CONDEMNED, FORSAKEN, DAMNATION.",
                "INFERNAL SCYTHE melee skin, HELLBOUND TALONS gloves (horn blades that flare, a demon eye in each wrist, hellfire on every kill), HELLBOUND SLEEVES, the INFERNAL PACT health bar and the INFERNAL PACT UI theme.",
                "Or get it all in the INFERNAL PACT BUNDLE.",
            } },
            { Head = "New enemies", Lines = {
                "MOLTEN: SLAGROLLERS roll low across the floor in fast curves, then stop to cool. Their carom lane runs to you, then bounces off your spot at an angle.",
                "CRYO: RIMEWYRMS weave up and down like a serpent while they slide across the room. Their icefall rings you with strikes, then hits where you stand.",
                "VOID: ANTIPODES circle you, then flip to the exact opposite side of their orbit. Their collapse closes rings of strikes in on you.",
                "CYBER: GLITCHES jitter, snapping a few studs at a time as they drift. Their bitstream lane zig-zags and ends on you.",
                "Every biome now has five enemy types of its own. The Index > Bestiary explains each one.",
            } },
            { Head = "New room layouts", Lines = {
                "Three new arena layouts: PILLARS (a grid of tall pillars to peek around), TERRACES (raised ledges down both sides at different heights) and BUNKERS (low L-shaped cover).",
            } },
            { Head = "A bigger passive tree", Lines = {
                "Six new HYBRID branches (309 nodes, was 249). Each one runs outward between two regions, mixes both playstyles, has its own gem socket and ends in a new cornerstone.",
                "DUELIST: weak-spot hits build 2 Focus, but a body shot ends it. HEX ROUNDS: the tree's burn / chill / bleed / decay chances are doubled. GLACIAL WARD: every chill you apply makes you tougher for a moment.",
                "LAST BASTION: much stronger below 40% health. BUTCHER: all overkill damage carries into your next hit. ONE SHOT: slow-firing guns hit far harder, fast ones less.",
                "Hybrid branches also connect sideways into the branches next to them, so there are more ways in and out.",
                "Fixed: the Rampage cornerstone lowered every hit by 10% on top of its first-hit penalty. Now only the first hit on an untouched enemy is lower, as described.",
            } },
        },
    },
    {
        Id = 24, Version = "0.25", Date = "Oct 4, 2026", Title = "MIXED RUNS",
        Sections = {
            { Head = "Every floor is a new biome", Lines = {
                "No more picking a biome: every floor of a run rolls its own, Molten, Cryo, Void, Cyber or Stormspire. All five come up before any repeats, never the same one twice in a row. A title card names each one as you arrive.",
                "Party runs, Rifts and the Daily Challenge mix too (the Daily shows today's order, floor by floor). Boss Trials keep their own arena.",
            } },
            { Head = "Simpler movement, more aiming", Lines = {
                "Grappling and wall running are gone, along with the grapple tree, the grapple keys and the HOOK button. You move by running, sliding, bhopping and dashing, so fights stay about your aim.",
                "Hold Space to bhop: land with Space held and you jump again straight away, keeping your speed. Hold a movement key in the air (W, A, S or D) to build speed that way.",
                "Every slide press is a fresh slide with a quick burst that fades fast. Jump out of a slide for an extra kick. Hold crouch and Space to slide-hop on every landing.",
                "Land without jumping and you slow down fast.",
                "Rooms lost their grapple anchors and the glowing wall-run strips; the walls, platforms and ramps stay as cover.",
                "Grapple ropes are no longer sold. If you own one, it stays on your account.",
            } },
            { Head = "See when you're hit", Lines = {
                "When something hits you, a thin arc around your crosshair points at it and keeps pointing there as you turn.",
                "Hits flash the edges of your screen instead of the whole screen, so your aim is never covered. Bigger hits flash brighter, and elemental hits show in their element's colour.",
                "Standing in an attack's area? The screen edges glow in that area's colour and a small marker pulses under your crosshair, so you know to move without looking down. It covers lingering pools too.",
                "Below 30% health the screen edges pulse a faint red.",
            } },
            { Head = "Every biome has its own enemies", Lines = {
                "MOLTEN: CINDERS corkscrew up and plunge, MAGMAWS dive into the floor and burst out where the crack leads, ASHWINGS flap and glide, and SMELTERS pour pools of molten metal.",
                "CRYO: SHARDLINGS skate on the air and overshoot, FROSTBITES freeze dead still then burst off, FLURRIES drift down like snowflakes, and CRYOMANCERS send a frost lock hunting you.",
                "VOID: PHASEWINGS phase out (shots pass through) while they move, MIRRORSHADES strafe the opposite way to you, RIFTLINGS hop between the same four stars, and the WATCHER's gaze locks on and fires.",
                "CYBER: RASTERS move only in right angles, TRACERS dash and leave a hologram behind, UPLINKS swing on a data tether, and FIREWALLS sweep a laser round the floor.",
                "Every attack has its own pattern to read. The Index > Bestiary explains each one.",
            } },
            { Head = "Better-looking biomes", Lines = {
                "Molten, Cryo and Void are open to the sky now like Stormspire: a deck of lava-lit smoke and falling ash; an aurora, icicles and snow; a starfield with a black hole and drifting rock islands. Magma veins, ice sheets, crystal clusters, rift cracks and geysers on the floors.",
                "Cyber is a neon data hall: a glowing grid on the floor and ceiling, data pillars and a scan bar. Every biome got sharper lighting.",
            } },
            { Head = "A new hub", Lines = {
                "The Gate Hall is rebuilt in stone and brass, lit by daylight through a great open skylight. A brass target is inlaid around the spawn, under a slowly turning gyroscope reticle. Far less neon, far fewer lights. It looks better and runs better.",
            } },
            { Head = "Runs smoother", Lines = {
                "Big performance pass: the hub isn't drawn while you're in a dungeon, no shadows in the dark dungeon rooms, a third of the lights, about half the particles. Floors draw around a third of what they used to.",
            } },
            { Head = "Balance + fixes", Lines = {
                "Boons are about half as strong (curses keep their full downside), and the boss that finishes your run no longer offers one.",
                "Boss Trial gloves are much rarer now: they only drop from tier V clears, at 0.25%.",
                "Echo Wraps no longer leave a trail of ghost hands behind them.",
                "The melee dash-strike goes out the instant you take your melee out. No draw delay.",
                "Sliding is easy to feel: your gun lowers while you slide (the same on every field of view).",
                "Smoother camera and a steady gun at speed: the gun's walk bob no longer speeds up and shakes when you bhop or slide fast, and stops in the air. Bhopping with crouch held no longer makes the view pulse on every landing.",
                "Picking a boon with 1 / 2 / 3 no longer switches your weapon.",
                "The run-complete popup can be closed (KEEP LOOTING) and closes itself after a few seconds.",
                "You no longer slide under a chest when you walk onto its back.",
                "The dungeon window no longer pops up again after you've entered a run.",
                "You no longer see (or bump into, or shoot) players who are in a different run, only your own party shows in a dungeon.",
                "Hits and kills land instantly now: the hit flash, the health bar and a killing blow show the moment you shoot (they used to wait for the server).",
                "Enemies move on their own instead of as one block: each reacts to you at its own speed, circles at its own pace, picks new spots at its own times and spreads out around you.",
                "Removed the supply chests on top of the corner pillars.",
                "Boss attacks use their arena's colours too (trial bosses get their own, gold for the Seraph Archon and the Chronarch).",
            } },
            { Head = "Clearer attacks", Lines = {
                "Attack markers look like they belong to the place: molten lava on Molten, ice on Cryo, a shimmering rift on Void, an acid-green hologram on Cyber, storm light on Stormspire. Each with a dark outline and a bright fill so they're easy to see. Bosses draw theirs in their own colours.",
                "Teleports are readable now: Blinkers and Blinking elites flash where they leave and where they land (Blinking elites used to just vanish and reappear). Tracers no longer dash through walls.",
                "You can hit every visible part of an enemy now (wings, crystals, snowflake arms...), body damage, or a head shot on the pieces of its head. The snowflake's arms got shorter too.",
            } },
        },
    },
    {
        Id = 23, Version = "0.24", Date = "Oct 4, 2026", Title = "FORGEHEART",
        Sections = {
            { Head = "New Boss Trial: FORGEHEART", Lines = {
                "A walking furnace in a shell of cooling slag (Challenges > BOSSES). Its shell shrugs off 85% of your damage, three white-hot BRANDS crawl over its body, and those take full damage. Track them as they come round.",
                "MAGMA TIDE: basalt pillars burst out of the floor, the ground glows... then the whole arena floods with lava. Get up on a pillar until it drains. In its last phase the pillar you're on cracks and sinks. Jump to another.",
                "HAMMERFALL: it raises its forge hammer and leaps onto where you stand; the impact sends shockwave rings out. Jump them. It also breathes fire from its furnace mouth and spits slag puddles where you're going.",
                "Rewards: a new Mythic glove drop, FORGEHEART GRIPS (a furnace burning inside the forearm that flares white with every shot, hammer sparks, brand runes, kills erupt), and two titles, SLAGBREAKER (tier III) and FORGEBORN (tier V), both boosting weak-spot damage.",
            } },
            { Head = "Fixes", Lines = {
                "Boss armor now really counts in solo runs: the Chronarch is armored on the beat and takes TRIPLE damage when its core opens, and bosses take far less damage while they roar between phases. (Solo fights were ignoring both.)",
                "Stormspire: the rooms are open to the storm now, broken roofs, storm clouds, forked lightning across the sky and rain you can actually see.",
            } },
        },
    },
    {
        Id = 22, Version = "0.23", Date = "Oct 4, 2026", Title = "STORMSPIRE",
        Sections = {
            { Head = "New biome: STORMSPIRE", Lines = {
                "A ruined sky citadel in a permanent thunderstorm: white stone, copper lightning rods, tesla coils, rain and lightning flashes. Pick STORM in the dungeon menu (Daily Challenge and Rifts can roll it too).",
                "Its enemies live nowhere else: STORMCALLERS strike-dive straight down and throw chain lightning, GALES glide in long sweeps and cut a crosswind across your line, ARCWALKERS arc-step through lightning and clap shockwaves, SPARKS ping around at high speed, and CONDUCTOR totems lock you down with storm strikes.",
                "Storm-charged enemies make you take more damage (Chaos resistance helps).",
                "Superboss: the TEMPEST SOVEREIGN. It wires a web of lightning between rods it plants, chains lightning after you, sweeps a wall of rain across the arena (find the gap, it moves), and in its last phase lights up the WHOLE arena, the only safe place is right beside it.",
                "New Mythic blueprint from it: STORMBREAKER (M4A1).",
            } },
            { Head = "Fixes", Lines = {
                "A final-floor win now gets the gold RETURN TO HUB portal (there was none).",
                "The out-of-lives screen said your loot was kept. It isn't; it now tells you it's lost and can be bought back from LOST GEAR.",
            } },
        },
    },
    {
        Id = 21, Version = "0.22", Date = "Oct 3, 2026", Title = "DASH-STRIKE",
        Sections = {
            { Head = "Melee", Lines = {
                "Your melee's heavy attack (right click) is now a DASH-STRIKE: you dash wherever you're looking, up, down, sideways with A / D, back with S, and the swing lands at the end. 2 s cooldown, doesn't use dash stamina.",
            } },
            { Head = "Survival", Lines = {
                "HEALTH GATE: above 25% health, no single hit can kill you. It leaves you on 1% and you take 25% less damage for 2.5 s to get out. Re-arms after 6 s.",
            } },
            { Head = "Movement", Lines = {
                "SLIDES REWORKED: a tap of crouch slides (it used to stop the moment you let go). The slide runs until you slow to a walk; jump (slide hop), dash or grapple cancel it keeping your speed.",
                "Tap crouch again to cancel a slide (you keep your speed); tap once more right after and the next slide is faster, spam it to build speed.",
                "FASTER SLIDES: a slide from a run starts at ~38 speed (was 28), holds it longer, and a dash flows straight into a slide at ~55.",
                "AIR MOVEMENT IS NOW CLASSIC BHOP STYLE: nothing yanks your momentum mid-air any more. Keys only nudge you, pulling back slows you smoothly, and speed comes from air strafing (hold A / D and turn the mouse the same way) and clean bhops.",
                "NEW (beta): Settings > Gameplay > Movement Style -> Classic. A port of classic bhop-server movement (autobhop, air strafing, a speed readout). Walking, jumping and strafing only for now, dash, slides and the grapple are Aimbound-style only.",
                "FIXED: portals work again (the prompt was hidden by the portal's glass core).",
                "FIXED: after a respawn the spawn room is safe again, bosses no longer hunt you there.",
                "Boss Trials: the boss now drops ONE gold Return to Hub portal and you stay to loot (no more auto-teleport). Trial bosses have 2.5x health.",
                "FIXED: the LOST GEAR buy-back button no longer hides under the level bar, and the welcome guide's key list no longer covers the cards.",
                "Source movement now has EVERYTHING: dash, slides + slide hops, wall-run, the grapple, the melee dash-strike, jump pads and crouch-walking all work in Source mode, and other players see you run and jump.",
                "Source movement: every bhop or SIDEHOP (hold A or D, keep looking ahead, hold jump) adds a little speed, and air strafing gains faster.",
                "Air strafing is stronger and rewards SMOOTH turns: about +10 speed a second while strafing. Spinning the camera gains nothing, and a quick turn no longer loses your momentum (the game was quietly bleeding speed on every mid-air turn).",
                "Slides go where your keys point: hold a new direction (even straight back) and tap crouch to cut back instantly. No more getting stuck after a 180.",
                "You can steer a slide: it turns quickly toward the way you're pressing (or where you look with no keys), and every spam tap re-aims it.",
                "RESPONSIVE MOVEMENT: full speed in ~0.15 s, a stop in ~0.2 s, nothing ever locks your direction (no landing or after-dash lock), and when you're going fast your keys steer that momentum; pulling back brakes. Camera effects are toned down.",
                "Slides are short and snappy now (about two thirds of a second, spam-tap to keep going) and stand you straight back up; you steer them almost instantly.",
                "Crouch pressed in the air is remembered: land and you go straight into a slide hop. Bumps no longer end a slide.",
                "Sliding has an animation: your body leans back with a leg out (everyone sees it), and in first person the gun tilts, the camera leans and speed streaks run down the screen.",
                "Dash, slide, slide hop, bhop and wall-run work in the hub too (not the grapple). Hub Shift Lock moved to Caps Lock.",
                "Dash into a slide always gets the slide boost, and letting go of a slide / dash eases you out instead of stopping you dead.",
                "The grapple is held now: let go of the key to drop the rope. A quick tap still gives you the latch boost.",
                "Every action can be bound to a mouse button (left / right / middle), and shooting / aiming can be moved off the mouse (Settings > Controls).",
            } },
            { Head = "Phones & tablets", Lines = {
                "Loot can be picked up: the item card has a big TAP TO PICK UP button.",
                "Tap an item in your stash / bag to see its stats.",
                "Passive tree: drag with a finger to move it, pinch to zoom; tap a node to see it, tap again to take it (or refund it).",
                "Spectating: tap to switch who you watch. The AIM button turns into DASH with your melee out; HOOK is held.",
                "Keyboard key hints are hidden on touch screens.",
            } },
            { Head = "Progression", Lines = {
                "Levels take 50% more XP.",
                "Premium UI themes are no longer sold. They unlock as you level (Seraphim 10, Neon Overdrive 20, Hellforge 30, Void Rift 40, Prismatic 50).",
            } },
            { Head = "Aim Trials", Lines = {
                "Everyone shoots the same trial weapon now (no recoil, no spread, a set fire rate per trial) so the leaderboards are fair.",
                "The Tracking target strafes smoothly instead of shivering, and it's hit exactly where you see it.",
            } },
            { Head = "Bosses", Lines = {
                "Seraph Archon: the light is rarer (14 s cooldown), winds up longer, shows a big TURN AWAY countdown and hits softer. Scales of Judgement gives you longer to cross.",
                "Chronarch: no more near-instant attacks. Every beat-timed attack gives you at least ~0.85 s, and the pendulum hits where you actually stand.",
                "Echo Warden: echoes no longer stack into a white wall of light, and fewer attacks overlap.",
                "Big attacks no longer flash the whole screen white when they land.",
            } },
            { Head = "Fixes", Lines = {
                "Juggernauts and other melee enemies weave unpredictably on the way in instead of a fixed wiggle.",
                "Titles no longer stack on top of each other when you change them.",
                "Chargers no longer fly up to the ceiling after a dive.",
                "The Void and Cyber floors are much brighter.",
            } },
        },
    },
    {
        Id = 20, Version = "0.21", Date = "Oct 3, 2026", Title = "PLAYTEST FIXES",
        Sections = {
            { Head = "Movement", Lines = {
                "SLIDE HOP: slide, jump, hold crouch and you land straight into a slide. Every hop adds speed. Chain it to fly.",
                "Speed has a soft cap now instead of a wall: past it every gain shrinks fast, so going faster takes real skill (air strafing).",
                "Jumping out of a slide gives a little extra speed.",
                "Wall-running only starts when you mean it: moving along the wall, fast, holding a direction. It builds a little speed, the jump-off adds more, and crouch drops you off.",
                "Jump pads launch you properly onto their platforms (the speed limit was clipping them).",
            } },
            { Head = "Enemies", Lines = {
                "Only a few enemies can wind up an attack on you at once (2 on Easy / Normal, 3 on Hard / Brutal, 4 above). The rest reposition and wait their turn. Elites ignore the queue.",
                "Ordinary enemy attacks show just a flat warning on the floor; the tall column only appears when you're above the attack, and on bosses.",
                "Enemies swing round corners much faster when you hide, jiggle-peeking a stuck enemy doesn't work any more.",
            } },
            { Head = "Loot", Lines = {
                "Every drop plays a clear chime (higher for rarer items), and name tags stay visible from further away the rarer the item.",
                "Chest loot lands in a row in front of you, and you're told how many items dropped.",
                "Chests and portals got a glow-up: a glowing ring and sparkles on chests (the lid swings open in a burst of light), a light beam over the floor-clear chest, and swirling portals.",
            } },
            { Head = "Fixes", Lines = {
                "Typing in chat no longer opens menus or triggers moves.",
                "Your gun sits lower and further to the side in first person, out of the way of the crosshair.",
            } },
        },
    },
    {
        Id = 19, Version = "0.20", Date = "Oct 3, 2026", Title = "EARN IT",
        Sections = {
            { Head = "Challenge titles", Lines = {
                "15 new titles you have to earn the hard way:",
                "Headshot streaks: Steady Hand (10 in a row), Marksman (25), Surgical (50), Perfect Aim (100). A body shot or a miss ends the streak; the range dummy doesn't count.",
                "Bosses: Executioner (kill a boss on Hard+ within 30 s of your first hit), Flawless (kill a boss without taking damage), Untouchable (10 flawless), Colossus Breaker (10 superbosses), Apex Predator (50 bosses on Brutal+).",
                "Runs: Deathless (finish Hard without losing a life), Immortal (finish Nightmare without losing a life), Ghost (25 no-hit floors on Hard+).",
                "Also Elite Hunter (100 elites), Riftwalker (tier 5 rift in time) and Rift Lord (tier 10).",
                "Retired: Cadence, Collector, Hoarder, Relic Master, Aegis and Mythbearer. If you already own one, you keep it and can still wear it.",
                "Progress counts from now on (old fights weren't tracked).",
            } },
            { Head = "Premium season pass", Lines = {
                "The Season Journey has a PREMIUM row on every tier: more gold and materials, Legendary gems, extra rift sigils, Reforge Tokens and two premium-only titles (S1 Elite and S1 Apex).",
                "Tiers 10, 20, 30, 40 and 50 hold season skins (coming soon).",
                "Premium also gives +25% Season XP. Buy it any time. Every tier you've already reached is claimable straight away.",
                "Premium titles are cosmetic only: the pass never sells power.",
            } },
        },
    },
    {
        Id = 18, Version = "0.19", Date = "Oct 3, 2026", Title = "HOOKED",
        Sections = {
            { Head = "Grapple tree", Lines = {
                "The grapple has its own skill tree, open it with [N] or the GRAPPLE button on the left. You get 1 point, plus 1 every 3 levels; resetting is free.",
                "Four directions, each with small upgrades to pull speed, range, cooldown and launch burst.",
                "MOMENTUM: Slipstream (+15% move speed for 3 s after a hook) and Second Wind (a hook refunds a dash bar).",
                "ASSAULT: Hook Shot (+12% damage for 3 s after a hook) and Predator (+10% crit chance for 3 s).",
                "GUNSLINGER: Quick Draw (+15% fire rate for 3 s after a hook) and Speed Loader (a hook reloads your gun).",
                "RIGGING: Retractor (-15% cooldown, misses are free) and Twin Hook (two grapple charges).",
            } },
            { Head = "Grapple looks", Lines = {
                "New cosmetic category GRAPPLES: Standard Line, Ember Chain (level 10), Toxic Tether (level 20), Void Line (level 35), and the premium Prismatic Cord and Seraphim Halo Line.",
            } },
        },
    },
    {
        Id = 17, Version = "0.18", Date = "Oct 3, 2026", Title = "BE YOURSELF",
        Sections = {
            { Head = "Your avatar", Lines = {
                "You now play as your own Roblox avatar (R6). The character creator and the Style Studio are gone.",
                "Gloves and sleeves fit your arms, and your gun and melee ride on your character for everyone to see.",
            } },
            { Head = "Cosmetics", Lines = {
                "Cosmetics are all about your loadout now: gun skins, melee skins, gloves, sleeves, UI themes and health bars.",
                "Armor and outfit pieces were retired. The Seraphim Ascendant bundle is now the guns, spear, gloves, sleeves and UI theme.",
                "Back accessories hide while a gun or spear is slung on your back, so they never clip through it.",
            } },
            { Head = "Grapple", Lines = {
                "The grapple hooks onto anything again, ceilings included.",
                "It now launches you with a burst of speed the moment it latches.",
                "Cooldown is now 5 seconds (a miss or a cancel still only costs half a second), make each grapple count.",
            } },
            { Head = "Movement", Lines = {
                "Moves chain freely: hold crouch and you slide the moment you touch the ground fast, out of a dash, a grapple, a wall run or a jump.",
                "Dash-jump: jump during a ground dash to hop out with all its speed.",
                "Dash during a grapple to let go and burst off with its speed.",
                "Crouch: hold it standing or walking to crouch-walk, or in the air to tuck and land straight into a slide.",
                "Wall runs catch a Space press a little earlier before you reach the wall.",
                "The Seraphim bundle preview in the store now shows the set on YOUR avatar.",
            } },
        },
    },
    {
        Id = 16, Version = "0.17", Date = "Oct 3, 2026", Title = "EVERY SHOT COUNTS",
        Sections = {
            { Head = "No more room-clearing", Lines = {
                "Explosions, splashes, chains and ricochets are gone from builds. Every enemy needs its own shot. Power now comes from killing each one faster.",
                "CHAIN KILLS: every kill gives a stack for a few seconds; stacks add damage. Keep the kills coming.",
                "OVERKILL: damage beyond what kills an enemy can carry into your next hit.",
                "EXECUTES: Culling affixes and gems kill weakened enemies outright.",
            } },
            { Head = "Fights", Lines = {
                "Enemies and bosses leave you alone in the safe entry room, a boss waits until you walk back out.",
                "Every red area now shows its column: a faint wall of red rises from it (up past you if you're above it), fills in with the wind-up and flashes when it strikes.",
            } },
            { Head = "Pierce", Lines = {
                "High-caliber guns pierce: the AWP (3 enemies), Barrett and Scout (2), Desert Eagle and Rhino (1). Line them up.",
                "Pierce Damage and Extra Pierce can roll on those guns, the tree, gems and boons.",
            } },
            { Head = "Traits", Lines = {
                "Unique traits are now very rare, Legendaries no longer always have one.",
                "12 traits, all single-target: Static Build-Up, Supernova Core, Guillotine, Overflow, Bloodhound, Hunter's Focus, Marrow Tap, Phantom Round, Last Light and more. Traits on your old weapons were updated.",
            } },
            { Head = "Skill tree, gems and boons", Lines = {
                "The Demolitionist sector is now BALLISTICS: Penetrator (pierce) and Rampage (chain kills) replace the explosion branches. Conflagration, Shatter and Ricochet were reworked. Your skill points were refunded.",
                "The Explosive prefix is now Echoing: the same enemy gets hit again. Fixation's max-stack blow lands on its target.",
                "New gems: Calibrated Scope, Hair Trigger (Legendary), Surgeon's Hand, High Caliber, Last Word, Tunnel Vision (Mythic). Chain of Command and Reactor Core reworked.",
                "New boons: Kill Rush, Overflow, Armor-Piercing Rounds, Culling Edge, Rampage. The Demolitionist title is now Penetrator (land piercing hits).",
            } },
        },
    },
    {
        Id = 15, Version = "0.16", Date = "Oct 3, 2026", Title = "NO HIDING",
        Sections = {
            { Head = "Movement that matters", Lines = {
                "Red areas are now COLUMNS: circles, lines, cones, marks and arena wipes hit you at any height. Going up doesn't get you out, moving sideways does. A pale pillar shows the area when you're above it.",
                "Shockwave rings, sweeping floor lasers and lingering pools still sit low. Jump them.",
                "The grapple no longer hooks ceilings. Walls and the arena's grapple anchors still work.",
            } },
            { Head = "Runs", Lines = {
                "Extract portals every 5 floors on every difficulty (was 10).",
                "The Crowbar is everyone's melee now. The other melees are gone (anything you bought was refunded). Melee looks come from skins: the Seraphim Spear for now, more to come.",
            } },
            { Head = "A cleaner interface", Lines = {
                "One type system for every text in the game: each UI theme has its own header, body and accent fonts, and descriptions always stay easy to read.",
                "New icons on the left dock. They take your UI theme's colours. [H] opens My Cosmetics, [B] the Store.",
                "The training range stats panel moved to the right, out from under the dock.",
            } },
            { Head = "New look", Lines = {
                "New outfit line: headsets, visors, hoodies, tech vests, exo frames, holo capes, hover greaves and more, starters in the Style Studio, the rest drop on runs.",
                "New TRIM GLOW colour in the Style Studio: the neon lines on your gear take it.",
                "Seraphim armor now covers you all the way round: back plate, arm guards, leg armor and boots.",
            } },
            { Head = "Store", Lines = {
                "Bundles show everything: the full set wears its gloves and stands its guns beside it, and a chip for every item lets you look at (and try) each one on its own.",
                "Trying a bundle in first person: [N] swaps between its guns.",
            } },
            { Head = "Sound", Lines = {
                "New Kill Sound and Death Sound pickers in Settings > Audio (new defaults). No more Roblox oof on anyone.",
                "Inspecting a weapon is silent now.",
                "Fixed audio getting very loud / breaking after big boss fights.",
            } },
        },
    },
    {
        Id = 14, Version = "0.15", Date = "Oct 3, 2026", Title = "SERAPHIM ASCENDANT",
        Sections = {
            { Head = "Seraphim armor + the big bundle", Lines = {
                "New ARMOR: the Seraphim Crown, Cuirass, Wings and Greaves, pearl and gold, glowing runes, a floating halo and wings that breathe and flare. Buy any piece on its own.",
                "SERAPHIM ASCENDANT BUNDLE: all four armor pieces, both Seraphim guns, the Seraphim Spear, Celestial Fury gloves, Seraphim sleeves and the Seraphim Ascendant UI theme, about half the price of buying them one by one.",
                "Armor is for everyone else to see: in first person nothing gets in your way.",
            } },
            { Head = "A new store", Lines = {
                "Cleaner store: categories on the left, a tidy grid in the middle, and a big DETAIL panel on the right with a live 3D preview you can drag to turn and scroll to zoom.",
                "TRY IN FIRST PERSON: put on any gun skin, melee skin, gloves, sleeves or UI theme and see it in your own hands, with a target dummy to shoot, [T] to inspect and [K] to see the kill effect.",
                "VIEW ON CHARACTER: armor, bundles, gloves and gun skins on your own character with a slow showcase camera.",
                "Bundles list everything inside, what you already own, and how much you save.",
                "MY COSMETICS shows the premium items too, pick one you don't own and GET IT IN THE STORE takes you straight to it.",
            } },
            { Head = "Premium cosmetics, rebuilt", Lines = {
                "Seraphim guns: wings that breathe and unfold on inspect, spinning halos at the muzzle, a gold star flash on every shot, chiming reloads, star-burst impacts and an escalating ASCENSION kill banner.",
                "Every glove has its own look now: armored vambraces, void lightning arcing between your hands, a molten gauntlet that heats up as you fire, a hologram ammo readout, a ticking clock, pistons that punch, ghost echoes.",
                "UI THEMES now restyle the WHOLE interface. Eight recolour themes DROP from bosses, elites and goblins; five premium themes (Seraphim Ascendant, Neon Overdrive, Hellforge, Void Rift, Prismatic) bring their own fonts, textures, ornaments and animations.",
            } },
            { Head = "Smarter enemies", Lines = {
                "Enemies LEARN how you fight: strafe in the same A-D rhythm and they aim past your next turn; always dodge the same way and some attacks land where you're running; keep peeking the same corner and they'll pre-fire it.",
                "A purple eye flashes over an enemy when it reads you. Change it up. Bosses read your strafe rhythm too. Easier difficulties use their reads less often.",
            } },
            { Head = "Bosses, reforged", Lines = {
                "APEX TITAN MECH is now a four-legged siege walker: legs that stride, rotary cannons that spin up before they fire, a turning reactor and missile pods.",
                "GOLIATH rolls in on tank tracks and its ram punches out when it charges. PHANTOM is a cloaked wraith with two scythes. SENTINEL is a fortress of crystal towers linked by energy beams.",
                "The biome superbosses are colossi now, giant floating fists that rise when they attack, a burning heart, a masked head and rune rings around them, with a different body for every biome.",
                "Every boss announces itself, every phase change hits the screen with a banner, and bosses visibly heat up, orange in phase 2, white-hot with embers in the final phase.",
            } },
            { Head = "Every platform", Lines = {
                "Phones and tablets: on-screen FIRE (two of them), AIM, RELOAD, DASH, SLIDE, HOOK, SWAP, MELEE and INSPECT buttons, and drag anywhere on the right to look.",
                "Controllers: R2 shoot, L2 aim, X reload, Y swap, R3 melee, LB dash, B slide, RB grapple, A jump, right stick to look, Start for settings.",
                "Windows and the HUD shrink to fit small screens. New settings: Touch Look Sensitivity, Controller Look Speed, Touch Button Size.",
            } },
        },
    },
    {
        Id = 13, Version = "0.14", Date = "Oct 3, 2026", Title = "ASCENSION",
        Sections = {
            { Head = "Boss Trials (endgame)", Lines = {
                "New BOSSES tab at the Challenge gate: three endgame bosses, each fought alone in its own arena, in 5 tiers. Clear a tier to unlock the next.",
                "SERAPH ARCHON: when it blazes up, TURN AWAY or the light strikes you. When it raises a wing, get to that side: the other half of the arena burns.",
                "CHRONARCH: it fights to a ticking metronome. It's armored on the beat; every 4th beat its core opens and takes triple damage.",
                "ECHO WARDEN: every attack happens again a few seconds later in the same spot. Remember where it struck.",
                "Every clear pays gold and Prism (big bounty the first time), fastest clears go on leaderboards, tier III and V unlock titles, and each boss has a super-rare exclusive glove.",
            } },
            { Head = "Seraphim skins", Lines = {
                "Seraphim M4A1 and AK-47: pearl and gold with feathered wings that spread when you inspect, a halo over the gun, gold tracers and a pillar of light on every kill.",
                "Seraphim Spear: turns your melee into a pearl-and-gold spear with its own stabs and wings that spread on inspect.",
                "Skins show in first person and on your character for everyone.",
            } },
            { Head = "Gloves, sleeves and HUD themes", Lines = {
                "Gloves and sleeves are back, for your first-person hands, and gloves show on your character too. Some burn, crackle with void lightning, flow through every colour, or spin a halo at your wrist.",
                "Super-rare boss gloves: one from each Boss Trial boss and one from the Apex Titan (0.5-1%).",
                "HUD themes re-skin your own HUD: Midnight, Emerald, Gold Rush, Seraphim, Neon Cyber, Inferno, Prismatic.",
            } },
            { Head = "Enemies", Lines = {
                "Every enemy has a new look: armor, glowing eyes, fins, thrusters, arm cannons, and walkers swing their arms.",
                "Six new enemies modelled on aim-trainer drills: Popper, Pasu, Seraph Drone, Zipper, Orbiter and Leaper.",
                "Every boss got a new silhouette (cannons, shrouds, pylons, wings, crowns).",
            } },
            { Head = "Also", Lines = {
                "New look for the whole UI: one clean font everywhere and new high-contrast icons.",
                "The STORE now shows only things you can buy; COSMETICS shows everything with where to get it.",
                "Smoother party runs and a safety limit on attack effects when a lot is happening at once.",
            } },
        },
    },
    {
        Id = 12, Version = "0.13.1", Date = "Oct 2, 2026", Title = "THE COSMETICS SHOP",
        Sections = {
            { Head = "New", Lines = {
                "Two new buttons on the left of the hub: SHOP and COSMETICS.",
                "SHOP lists every cosmetic in the game, health bar styles, headwear, tops, bottoms, special skin tones and melee skins, with its price or exactly how to get it.",
                "COSMETICS is your collection: everything you own, sorted by category, one click to equip. Your collection count is at the top.",
                "Every card is a live preview: health bars animate, outfit pieces are shown on a model wearing your current look, melee skins spin on your melee.",
                "Melee skins now go on every melee you own, and are sold in the shop (they had no way to be earned before).",
            } },
        },
    },
    {
        Id = 11, Version = "0.13", Date = "Oct 2, 2026", Title = "BOSSES REBORN",
        Sections = {
            { Head = "Bosses", Lines = {
                "Every boss is rebuilt with its own move set and three phases: at 2/3 and 1/3 health it roars, blasts a shockwave and gets faster and nastier.",
                "Goliath charges you down along a marked lane, stomps and shields up (flank it). Phantom snipes with lock-on lasers, blinks behind you and sends decoys.",
                "Sentinel spins laser spokes, pulses shockwaves and turtles behind a shield while it shells the room. The Apex Titan fires lasers and artillery and calls up to 2 escorts.",
                "Each biome's superboss has a signature fight: meteors and fire breath, frost novas and icicle storms, rift singularities, laser grids.",
                "Boss fights are relentless: every boss keeps up constant pressure (quake fissures, hunting death marks, spinning floor lasers, artillery, lava pools, icicle storms) while its big moves overlap, and some attacks flood the whole arena except a few safe circles. Easier difficulties give you more breathing room.",
                "New boss effects: charge-ups, dash trails, impact bursts, afterimages, screen shake and a big death explosion.",
            } },
            { Head = "Health bars", Lines = {
                "All-new health bars: they only show on enemies you hit or aim at (no more stacks of bars), drain with a bright chip, flash and kick on every hit, and burst on the kill.",
                "Bosses get a big bar at the top of the screen with phase marks and a shield warning.",
                "Health bar styles (Settings > Enemies > Health Bar Style): Inferno, Glacier, Storm Caller, Bone Collector, Hellspawn, Seraph, Prismatic and more, animated wings, skulls, flames and lightning.",
                "Sovereign's Crown: a Mythic style that only drops from a final-floor superboss (1 in 100).",
            } },
        },
    },
    {
        Id = 10, Version = "0.12", Date = "Oct 2, 2026", Title = "READ THE ATTACK",
        Sections = {
            { Head = "Changed", Lines = {
                "No more projectiles or random hits: every enemy attack is a red area that fills up, then goes off. Be out of it when it does.",
                "Ranged enemies glow while they wind up and mark the area where you are (a little ahead if you're running): circles, lanes, long sniper lanes and barrages.",
                "Chargers mark a strip through you, then dive along it. Juggernauts slam a circle (and send a shockwave you jump over). Brutes swing a cone.",
                "Volatile elites mark their blast circle when they die.",
                "Harder difficulties give you less time to react.",
                "Bosses now fight you in the main arena. The back room is gone. (A full boss rework is next.)",
            } },
        },
    },
    {
        Id = 9, Version = "0.11.2", Date = "Oct 2, 2026", Title = "BHOP, TUNED",
        Sections = {
            { Head = "Changed", Lines = {
                "Bhop in any direction: hold Space and steer with W, S, A or D, forwards, backwards or side-hops all keep your speed.",
                "Every clean hop adds speed, and turning while you hop adds more. Nothing in the air slows you down.",
                "A slightly late jump still counts, landing no longer throws you sideways.",
                "Dash, grapple and wall run all keep the speed you bring into them.",
                "Top speed is capped so nobody can break the game.",
            } },
        },
    },
    {
        Id = 8, Version = "0.11.1", Date = "Oct 2, 2026", Title = "BHOP FIXES",
        Sections = {
            { Head = "Changed", Lines = {
                "Bhopping builds speed: hold Space (or press it just before you land) and you jump again instantly. Every clean hop adds speed.",
                "Slides flow into bhops: jump out of a slide with all its speed, or hold slide as you land to slide-hop.",
                "CS-style strafing: once you have speed, bhop with just A or D and steer with the mouse. You keep your momentum (forwards or backwards) and turning with the key builds speed.",
                "The slide sound is gone.",
                "Fixed: dash didn't work in live servers for players with Roblox's Shift Lock turned on.",
            } },
        },
    },
    {
        Id = 7, Version = "0.11", Date = "Oct 2, 2026", Title = "NEW MOVEMENT",
        Sections = {
            { Head = "Changed", Lines = {
                "Movement rebuilt, Redliner-style: chain moves and you keep accelerating (up to a high top speed). Turning is crisp. Your speed grips the way you face.",
                "3 stamina bars: a dash costs one. They refill faster on the ground or on a wall.",
                "Dash never slows you down: you come out of it at least as fast as you went in.",
                "Bhop: hold Space and land-jump to keep all your speed. Air strafe: hold a direction and turn the camera smoothly to gain speed (turn too fast and you lose it).",
                "Slide hop: hold slide as you land to slide again with a fresh boost. Downhill slides speed up.",
                "Wall run: press Space next to a wall in the air; Space again jumps off where you look. Wall running refills stamina.",
                "Grapple redirect: grapple while holding no movement key and all your speed swings toward the hook. Dash backward, then grapple forward for a burst.",
            } },
        },
    },
    {
        Id = 6, Version = "0.10.2", Date = "Oct 2, 2026", Title = "FIXES",
        Sections = {
            { Head = "New", Lines = {
                "The Season Journey has its own window at the season stand (it used to open Challenges).",
            } },
            { Head = "Fixed", Lines = {
                "Enemies no longer get stuck on towers, walls and platforms, a stalled enemy finds a way around.",
                "Q and 3 no longer pull out your melee in the hub.",
                "Your focus streak no longer follows you out of the training grounds.",
                "The Settings button is easier to read.",
            } },
        },
    },
    {
        Id = 5, Version = "0.10.1", Date = "Oct 2, 2026", Title = "FASTER, DEADLIER RUNS",
        Sections = {
            { Head = "Changed", Lines = {
                "Runs are much shorter: Easy 5 floors, Normal 10, Hard 15, Brutal 20, Nightmare 30. Each ends on its biggest boss. Extract portals every 10 floors.",
                "Grapple is one tap: it pulls you all the way to where it lands. A miss just flicks the rope.",
                "Dash charges recharge slower.",
                "Enemy shots fly about twice as fast and lead your movement.",
                "Juggernauts, Brutes and Chargers are now melee brawlers: they rush you and strike after a red flash, dash out of it.",
                "Wall-run stamina bar under the dash pips; it refills on the ground. Wall columns no longer stop wall runs.",
                "Molten rooms are brighter and alive: lava channels, lavafalls, embers, smoke, hanging cages.",
                "Titles reworked: 4 per rarity, sorted Common to Mythic, and the rarer the title the harder it is. Weak-spot titles count every gun now.",
                "Your title shows above your head for everyone (and for you in the hub).",
            } },
        },
    },
    {
        Id = 4, Version = "0.10", Date = "Oct 2, 2026", Title = "MOVEMENT TECH",
        Sections = {
            { Head = "New", Lines = {
                "Dash [Shift]: a quick burst in any direction, even mid-air, 2 charges.",
                "Slide [C / Ctrl, hold]: a burst of speed low to the ground. Jump out of it to keep the speed.",
                "Wall run: jump at a wall while moving forward. [Space] wall-jumps off, and gives a dash charge back.",
                "Grapple [F, hold]: fire a rope and swing. Glowing anchors in every arena pull your aim onto them.",
                "Momentum carries between moves: chain dash, slide, wall run and grapple to stay fast.",
                "Arenas are bigger and taller, with one of three layouts: Gauntlet, Towers or Ring.",
            } },
            { Head = "Changed", Lines = {
                "Practice range: bot speed is now [Z] slower / [X] faster ([C] is slide).",
            } },
        },
    },
    {
        Id = 3, Version = "0.9.1", Date = "Oct 2, 2026", Title = "DUNGEON GEAR",
        Sections = {
            { Head = "New", Lines = {
                "Character gear now fits the dungeons: a plain adventurer starter kit, hood, headwrap, leather jerkin, rope sash, traveler's cloak, belt, leg wraps and worn boots.",
                "Dungeon drops: helms, masks, crowns, armor, cloaks, greaves and more in all six rarities. The rarer, the more impressive.",
                "Bosses, loot goblins and elites drop rarer gear more often. Found gear is yours forever, wear it at the Style Studio.",
            } },
            { Head = "Changed", Lines = {
                "Clothing colors are now earthy, worn-in tones; richer dyes unlock with level.",
            } },
        },
    },
    {
        Id = 2, Version = "0.9", Date = "Oct 2, 2026", Title = "STYLE STUDIO",
        Sections = {
            { Head = "New", Lines = {
                "Character creator at the new Style Studio booth: body type, skin, head shape, face, hair, outfit colors, headwear, tops and bottoms.",
                "The hub is now third person. Hold right mouse to look around, scroll to zoom.",
                "Other players now see your gun (in its skin), your melee and your gloves on your character.",
                "Spectating a teammate shows the run through their eyes.",
                "This welcome guide and these patch notes.",
            } },
            { Head = "Changed", Lines = {
                "Roblox avatars are replaced by your Aimbound character so gear and cosmetics always fit.",
            } },
        },
    },
    {
        Id = 1, Version = "0.8", Date = "Oct 2, 2026", Title = "ROGUELITE RUNS",
        Sections = {
            { Head = "New", Lines = {
                "3 lives per run, with a revive window when you run out.",
                "Gear found in a run is at risk until you clear the last floor or extract (gold portal every 20 floors).",
                "Lost gear can be bought back until your next run.",
                "Loot goblins: catch them in 30 seconds for great loot.",
                "Equip Best in the stash, with build presets (Max DPS, Tank, Burn, Freeze, Bleed, Decay, Crit).",
            } },
            { Head = "Balance", Lines = {
                "Legendary and Mythic drops are much rarer.",
                "Easier bots on the lower skill levels; Normal and Hard hit a little softer.",
            } },
        },
    },
}
do
    local okI, ItemData = pcall(require, script.Parent:WaitForChild("ItemData"))
    if not (okI and type(ItemData) == "table" and ItemData.ZENITH_LIVE == true) then
        for i = #NOTES, 1, -1 do if NOTES[i].Dark then table.remove(NOTES, i) end end
    end
end
return NOTES
