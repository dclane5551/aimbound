--!nocheck
-- GUIDE CODEX (UPDATE 8 OFFENSE, 2026-10-21): the Index window's HOW IT WORKS tab -- plain-words pages for the systems UPDATE 8
-- rebuilt: attributes, the passive tree, sockets + links, shot mods, damage types, defences. Live numbers come from the
-- player's own state where it helps (your attributes, your mod level cap, the link gate). Client only.
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local ItemData = require(script.Parent:WaitForChild("ItemData"))
local ShotMods = require(script.Parent:WaitForChild("ShotMods"))

local GuideCodex = {}
local C = UIStyle.Colors
local New, Text = UIStyle.New, UIStyle.Text

-- each page: { Title, Color, Lines (strings or function(state) -> string) }
GuideCodex.PAGES = {
    { Id = "Attributes", Title = "ATTRIBUTES", Color = Color3.fromRGB(255, 205, 110), Lines = {
        function(st)
            local a = st and st._Attrs
            return a and string.format("You have  STRENGTH %d   •   DEXTERITY %d   •   INTELLECT %d  (everyone starts with %d of each).", a.Strength, a.Dexterity, a.Intellect, ItemData.ATTR_BASE)
                or ("Everyone starts with " .. ItemData.ATTR_BASE .. " of each attribute.")
        end,
        "Attributes come only from the PASSIVE TREE (the small nodes along the paths give +8, your class start +20, some notables more) and from GEAR lines. There are no points to hand out.",
        "STRENGTH: +0.1% life and +0.2% Plating a point. ARs, LMGs, shotguns, Plating gear and RED mods need it.",
        "DEXTERITY: +0.2% Agility and +0.02% crit chance a point. SMGs, pistols, DMRs, snipers, Agility gear and GREEN mods need it.",
        "INTELLECT: +0.2% Ward and +0.1% elemental damage a point. Beam guns, Ward gear and BLUE mods need it.",
        "REQUIREMENTS: a gun needs 0.6 x its item level of its attribute, a gear piece 0.5 x of its defence's (half-and-half pieces 0.3 x of each), a mod 4 + 3.5 x its level of its colour's. Tooltips show it in red when you're short. You can't equip a gun or gear you don't meet, and a mod you don't meet sits idle.",
    } },
    { Id = "Tree", Title = "THE PASSIVE TREE", Color = Color3.fromRGB(120, 210, 255), Lines = {
        "You get a passive point every level and 2 more the first time you complete each difficulty: about 220 at level 200, for a tree of about 2,500 nodes. You can only ever reach a small part of it, so pick a direction.",
        "SMALL nodes add a little of one stat. NOTABLES (the big nodes) sit in themed clusters (Heat, Cryo, Volt, Void, Plating, Agility, Ward, chains, pistols...) and many of them ask for something back.",
        "CORNERSTONES change a rule of the game and always give something up. You unlock them on the tree, then equip them under PASSIVES: 3 slots, a 4th at level 75 and a 5th at level 200.",
        "SPECIALIZATIONS: from level 35, every tier of THE PROVING you clear (Challenges window, PROVING tab) gives 2 specialization points. Spend them with the tree's SPECIALIZATION button: three per class, each with one SIGNATURE rule.",
        "EXPERTISE (the diamond in a cluster's middle): once you hold a notable of that cluster, spend a point to pick one of its four effects.",
        "GEM SOCKETS on the tree hold gems; a gem boosts the nodes you hold around it.",
        "Refunding costs gold (50 x your level a point) or an Unwind, so choices stick.",
    } },
    { Id = "Sockets", Title = "SOCKETS AND LINKS", Color = Color3.fromRGB(95, 211, 106), Lines = {
        "Guns roll SOCKETS: red, green or blue. Sockets joined by a bar are LINKED. Only the gun's BIGGEST linked group works; mods in other sockets sit idle.",
        "Rarer guns and higher item levels roll more sockets: 3 from item level 10, 4 from 25, 5 from 50, 6 from 100.",
        function() return string.format("Links need item level too: a %d-link from 25, %d-link from 45, %d-link from 75. A longer group on a lower-level gun only works up to that size.",
            ItemData.MaxLinks(25), ItemData.MaxLinks(45), ItemData.MaxLinks(75)) end,
        "From level 8 kills drop socket currencies: BORE BIT rerolls how many sockets, SOLDER which ones are linked, TINT their colours.",
        "Every gun tile shows its sockets as coloured dots under the picture: a bar between two dots = linked, a gap = a new group, a white ring = a mod is in it.",
    } },
    { Id = "Mods", Title = "SHOT MODS", Color = Color3.fromRGB(90, 166, 255), Lines = {
        "Shot mods drop from level " .. ShotMods.DROP.Unlock .. " (bosses drop better ones). Put them in your gun's sockets in the MODS window (MENU > MODS): a mod fits a socket of its own colour.",
        "The MOD SUPPLY stall in the city (or the MODS window's SUPPLY tab) sells plain level-1 mods for Scrap, Alloy and gold, a few more as you level, including an area mod of each colour by level " .. tostring((ShotMods.SUPPLY and ShotMods.SUPPLY[#ShotMods.SUPPLY].Level) or 16) .. ". The strongest mods only drop.",
        "They change what your shot DOES: chains to other enemies, forks, bursts, corpses that explode, marks, extra Heat / Cryo / Volt damage, faster fire, bigger magazines and more.",
        "CLEAR or FOCUS: Chain, Fork, Volley and Impact hit other enemies for most of your hit but cost some damage on the one you aim at -- best against packs. Narrow Bore, Overcharge and the Added mods hit only your target much harder -- best against bosses and elites.",
        function(st)
            local cap = ShotMods.LevelCap(st and st.Level or 1)
            return "Mods level up as you kill with the gun they sit in, up to level " .. ShotMods.MAX_LEVEL .. ". At your level they work up to level " .. cap .. " (+1 every 8 levels)."
        end,
        "The first 3 mods in the group count in full. A 4th, 5th and 6th still help, but their damage and fire-rate bonuses count at the square root (+44% becomes +20%), so the order you socket them in matters.",
        "Each mod needs its colour's attribute (red Strength, green Dexterity, blue Intellect). BURNISH (from level 10) adds quality: each 1% is +0.5% more damage.",
        "Selling, quick-selling or dismantling a gun puts its mods back in your bag.",
    } },
    { Id = "Damage", Title = "DAMAGE TYPES", Color = Color3.fromRGB(255, 120, 60), Lines = {
        "Every hit is KINETIC, HEAT, CRYO, VOLT or VOID (most guns are Kinetic; beam guns, some mods, notables and Cornerstones add or convert to the others).",
        "Each comes with its own ailment: Kinetic BLEEDS (worse while the enemy moves), Heat BURNS, Cryo CHILLS and builds up to a FREEZE, Volt SHOCKS (more damage taken), Void WITHERS (stacks of more damage taken).",
        "Every world's enemies resist their own element and are weak to another one (shown on the floor's title card). Worlds never resist Kinetic (some map mods do).",
        "Damage numbers take the colour of the hit's type; a small arrow shows when a resistance or a weakness moved it.",
        "HEAVY ROUNDS: when a shot kills, the damage left over jumps to the nearest enemy and keeps going while it kills: Bolt Action rifles up to 4 enemies, Lances 4, Marksman Rifles 2, Rifles, LMGs and Hand Cannons 1, shotguns 1 (a shotgun kill also carries the rest of the blast). Slow guns also shoot through enemies lined up behind (Bolt Action 3, Marksman Rifles 2, Rifles, LMGs and Hand Cannons 1). Fast guns rarely have damage left over. A MARKSMAN with a Marksman class gun carries it much further: up to 30 studs a jump instead of 12.",
    } },
    { Id = "Defence", Title = "DEFENCES", Color = Color3.fromRGB(170, 230, 120), Lines = {
        "PLATING cuts Kinetic hits (small hits more than big ones). AGILITY gives a chance to dodge ordinary attacks, and a boss's plain swings, thrusts and shots (never an area attack, a big boss move or a hazard). WARD is a shield in front of your life that recharges 2 seconds after a hit (Void goes straight through it).",
        "RESISTANCES cut Heat, Cryo, Volt and Void hits, up to 75%. Harder difficulties take some of them away.",
        "Gear bases lean to one or two defences (Plating, Agility, Ward) and need that defence's attribute.",
        "IN THE PASSIVE TREE: every class has life and its own defence on small nodes near its start (Vanguard Plating, Marksman and Gunslinger Agility, Arcwright Ward). The Breacher has the most life and Plating. Notables between the Vanguard and the Marksman, and between the Arcwright and the Breacher, add Plating; those between the Vanguard and the Marksman, the Marksman and the Gunslinger, and the Gunslinger and the Arcwright add Agility.",
    } },
    -- (CLASS BUILDS) the 4 builds of each class and what to look for (tools/tree_v8 ARCHETYPES; Cornerstone names = SkillTreeData)
    { Id = "Builds", Title = "CLASS BUILDS", Color = Color3.fromRGB(255, 184, 28), Lines = {
        "Every class leans one way: the MARKSMAN is a glass cannon (the most damage, little life), the GUNSLINGER a fast glass cannon, the VANGUARD the middle, the ARCWRIGHT a sturdy middle (a little less damage, more toughness) and the BREACHER the tank (the most life and Plating, the least damage).",
        "Every class has four builds that only it does well. A build is three pieces that fit together: a GUN FAMILY (its built-in line is on the gun's tooltip), a SPECIALIZATION with its SIGNATURE rule (nothing else in the game has it) and the CORNERSTONES deep in your class's part of the tree.",
        "Any class can walk the tree to another class's build nodes, but they sit far from your start, so it costs a lot of points. A finished build is about 2-4 times as strong as an average one at its job, and weaker at the jobs it gave up.",
        "MARKSMAN.  ONE SHOT: a Bolt Action rifle, Lone Round + Bolt Discipline; slow, huge single shots.  SHATTER: Glacial Shells turns your rounds to Cryo and Longwatch kills frozen, wounded enemies outright.  SPOTTER CHAIN: a Marksman Rifle, Bank Shot + Untouched Aim and chain mods; Spotter's mark makes chains off it hit in full.  EXECUTIONER: a Void Marksman Rifle, Point of Aim + Marked Quarry; Specter culls enemies by their Wither stacks.",
        "GUNSLINGER.  TARGET HOPPER: a Hand Cannon, Quickdraw + Kill Rush; Fastdraw's first hit on every enemy hits hardest, so keep switching.  STATIC STORM: an SMG, Hip Shooter + Hot Streak and Volt; Bulletstorm sends lightning every few Shocks.  GHOST: a Sidearm, Run and Gun + Slide Fire and Agility; Outrider's dodges make the next strikes miss too.  RICOCHET: a Hand Cannon with Carom Shot + Empty the Mag; weak-spot hits bounce to the next enemy's weak spot.",
        "VANGUARD.  DEMOLITIONS: a Rifle, Shrapnel + Walking Fire; Sapper's kills explode through the pack.  LANCER: a Rifle and pierce, Walking Fire + Iron Frame; Spearhead pays you back for every line you shoot through.  SUPPRESSOR: an LMG, Stand Firm + Drum Mag; Siegebreaker's long bursts pin one target down.  FIELD COMMANDER: a Rifle in the middle of the pack with the Field Commander Cornerstone (more damage per enemy near you, less with none).",
        "BREACHER.  SLUG BREACHER: a Pump Shotgun with Slug Rounds + Door Kicker; one heavy slug instead of pellets, real weak-spot hits at range.  JUGGERNAUT: Iron Hide + Face to Face and Plating; Ironside hits hardest and takes least up close.  FORTRESS: Hardened Hide + Battering Ram and resistances; Bastion turns resistance over the cap into life regen.  BLOODSTORM: an Auto Shotgun, Bloodletter + Mercy Shot and Bleed; Gorehound's pellets each open their own Bleed.",
        "ARCWRIGHT.  WILDFIRE: a Heat Ray, Pyromania + Conduction and Burn; Pyrebrand spreads Burns from every burning kill.  CRYOSTASIS: a Ray, Ward Bound + Charged Cell and Cryo; Frostbinder freezes in half the build-up and every Freeze refills Ward.  PLAGUE: a Ray, Overload + Feedback Loop; Plaguecaller's targets take more for every different ailment on them.  STORM LANCE: a Lance with Static Discharge + Ion Charge; Volt rounds that go through the whole line.",
        "WHAT TO LOOK FOR: the gun family first (its line decides how you shoot), then the specialization, then the path to your two Cornerstones. Gear and mods that feed the build's damage type or ailment matter more than raw damage.",
    } },
    -- (2026-11-09 AUTO-SELL FILTER) appended
    { Id = "AutoSell", Title = "AUTO-SELL", Color = Color3.fromRGB(240, 190, 70), Lines = {
        "Bag > SELL > AUTO-SELL opens the auto-sell panel. Pick a rarity: new guns and gear at or under it are sold for gold as they drop.",
        "KEEP RULES protect drops the rarity would sell: guns with at least N sockets or an N-link, anything at or above an item level, whole gun classes or gear slots, and stat lines you pick (at a tier or better, and how many of them it needs).",
        "An item that matches ANY keep rule is kept. Relics and Zeniths are never auto-sold. The panel shows what your bag would do with your rules before you save.",
        "Changed your mind? SELL > BUYBACK has your last 10 sales, auto-sold ones included, for what they sold for.",
    } },
}

do -- (CLASS BUILDS) FAMILY: some mods work differently on some gun families -- one line each (ItemData.GunFamilies ModNote)
    for _, page in ipairs(GuideCodex.PAGES) do
        if page.Id == "Mods" and ItemData.GunFamilies then
            table.insert(page.Lines, "GUN FAMILIES: every gun has a built-in family line (on its tooltip), and a few mods work differently on some families:")
            for _, fid in ipairs(ItemData.GUN_FAMILY_ORDER or {}) do
                local f = ItemData.GunFamilies[fid]
                local keys = {}
                for k in pairs(f and f.ModNote or {}) do table.insert(keys, k) end
                table.sort(keys)
                for _, k in ipairs(keys) do table.insert(page.Lines, f.ModNote[k]) end
            end
        end
    end
end

function GuideCodex.Render(scroll: ScrollingFrame, state: any, attrs: any?)
    scroll.CanvasSize = UDim2.new()
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    local st = setmetatable({ _Attrs = attrs }, { __index = state or {} })
    local holder = New("Frame", { Name = "GuideHolder", BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(6, 6), Parent = scroll }, {
        New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    Text({ Name = "Intro", LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = UIStyle.BodyFont, TextSize = 14, TextWrapped = true,
        TextColor3 = C.Sub, Text = "HOW IT WORKS: the build systems in plain words.", Parent = holder })
    for i, page in ipairs(GuideCodex.PAGES) do
        local card = New("Frame", { Name = "Page_" .. page.Id, LayoutOrder = i, BackgroundColor3 = C.Bg1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, Parent = holder }, {
            New("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
            New("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
        })
        -- (UI CLEAN audit: the raised card + a head in Text; the page colour as one 2 px line under the head)
        card.BackgroundColor3 = C.Text; card.BackgroundTransparency = 0.955
        Text({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 22), Text = page.Title, TextSize = 18, TextColor3 = C.Text, Parent = card })
        New("Frame", { LayoutOrder = 1, Name = "Mark", BackgroundColor3 = page.Color, BorderSizePixel = 0, Size = UDim2.fromOffset(28, 2), Parent = card })
        for j, ln in ipairs(page.Lines) do
            local s = ln
            if type(ln) == "function" then local ok, r = pcall(ln, st); s = ok and r or "" end
            Text({ LayoutOrder = 1 + j, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = UIStyle.BodyFont, TextSize = 14, TextWrapped = true,
                TextColor3 = (j == 1) and C.Text or C.Sub, Text = "•  " .. s, Parent = card })
        end
    end
end

return GuideCodex
