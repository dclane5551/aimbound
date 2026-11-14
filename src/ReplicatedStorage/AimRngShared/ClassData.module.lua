--!nocheck
-- CLASSES v2 = WEAPON CLASSES (2026-10-05). Owner: "i want classes to be weapon based ... (AR, LMG) (SMG, PISTOL)
-- (DMR / SR) (MISC (SOMETHING LIKE A FUTURE HITSCAN BEAM WEAPON))", shotguns get a 5th class, "Just remove drifter,
-- because that will jsut be abused", and no melee anywhere in the tree or classes.
-- Five classes on a ring around the tree's shared centre (each owns a 72-degree wedge of SkillTreeData). Group = the
-- weapon group (ItemData.WeaponGroups) the class is built around: any gun can be used, but the class's PASSIVE SKILLS
-- (tree keystones with Group set) and its ascendancy only work while you hold a gun of that group.
-- Pick one on your first join; change it at the Skill Tree for a Rebirth Shard (the tree + ascendancy are refunded).
-- Names are original (tools/gen_tree_v4.py checks them against the reference blocklist).
local ClassData = {}

ClassData.List = {
    { Id = "Vanguard", IconKey = "c_vanguard", Start = "CLASS_VAN", Group = "Assault", Color = Color3.fromRGB(255, 152, 50), -- (UI v4: 255,150,50 is the Eclipse rarity colour -- every Vanguard label drifted magenta)
      Icon = "",
      Role = "AR / LMG", Attribute = "Strength",
      Blurb = "THE MIDDLE: average damage and toughness. Rifles and machine guns (Strength): sustained fire, pierce, chains, bursts.",
      Playstyle = "Stay on target and keep the trigger down. Passives reward long strings of hits and standing firm." },
    { Id = "Gunslinger", IconKey = "c_gunslinger", Start = "CLASS_GUN", Group = "Close", Color = Color3.fromRGB(255, 205, 80), Icon = "",
      Role = "SMG / PISTOL", Attribute = "Dexterity",
      Blurb = "FAST GLASS CANNON: high damage, the least life. SMGs and pistols (Dexterity): speed, Agility, snapping between targets.",
      Playstyle = "Keep moving and keep switching. Passives reward fresh magazines, kills and staying mobile." },
    { Id = "Marksman", IconKey = "c_marksman", Start = "CLASS_MAR", Group = "Precision", Color = Color3.fromRGB(90, 200, 255), Icon = "",
      Role = "DMR / SNIPER", Attribute = "Dexterity",
      Blurb = "GLASS CANNON: the most damage, little life. Marksman rifles and snipers (Dexterity): one perfect shot, and a kill carries on up to 30 studs.",
      Playstyle = "Every shot counts. Passives reward headshot strings, distance and kill shots." },
    { Id = "Breacher", IconKey = "c_breacher", Start = "CLASS_BRE", Group = "Shotgun", Color = Color3.fromRGB(120, 230, 140), Icon = "",
      Role = "SHOTGUN", Attribute = "Vitality",
      Blurb = "THE TANK: the most life and Plating, the least damage. Shotguns (Strength): point-blank power and Kinetic Bleed.",
      Playstyle = "Get close and stay alive. Passives reward full pellet hits, the first shell and fighting up close." },
    { Id = "Arcwright", IconKey = "c_arcwright", Start = "CLASS_ARC", Group = "Beam", Color = Color3.fromRGB(190, 120, 255), Icon = "",
      Role = "BEAM", Attribute = "Luck",
      Blurb = "STURDY MIDDLE: less damage, more toughness. Beam guns (Intellect): Heat, Cryo, Volt and Void, their ailments, Ward.",
      Playstyle = "Hold the beam and stack effects. Passives reward ailments, crits and staying untouched." },
}
ClassData.ById = {}
ClassData.ByStart = {}
ClassData.ByGroup = {}
for i, c in ipairs(ClassData.List) do
    c.Order = i
    ClassData.ById[c.Id] = c
    ClassData.ByStart[c.Start] = c
    ClassData.ByGroup[c.Group] = c
end

-- PASSIVE SKILLS (the tree's keystones): any number unlocked by allocating, at most this many EQUIPPED (0.49 ★ PASSIVES menu), so picking them is a real choice
-- (owner: "I want people to have to think about their choices, right now they do not")
ClassData.PASSIVE_LIMIT = 3
-- (0.62, owner: "Players should have a bunch of nodes to look forward to"): more passive slots as you level -- 3, a 4th
-- at level 75, a 5th at level 200
ClassData.PASSIVE_SLOT_LEVELS = { 75, 200 }
function ClassData.PassiveLimit(level: number?): number
    local n = ClassData.PASSIVE_LIMIT
    for _, l in ipairs(ClassData.PASSIVE_SLOT_LEVELS) do if (level or 1) >= l then n += 1 end end
    return n
end

-- the class's root node (or nil before a class is picked)
function ClassData.StartOf(classId: string?): string?
    local c = classId and ClassData.ById[classId]
    return c and c.Start or nil
end

-- the weapon group of a class (nil = no class)
function ClassData.GroupOf(classId: string?): string?
    local c = classId and ClassData.ById[classId]
    return c and c.Group or nil
end

return ClassData
