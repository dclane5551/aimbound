--!nocheck
-- GRAPPLE LOOKS (retired 2026-10-03 with the grapple -- owner: "remove grappling and wall running entirely"). Only the
-- cosmetic catalog is left here so the Cosmetics category "Grapple" (Hidden: off sale, not listed) still knows the items
-- players own, and a late Robux receipt for one still grants it. The grapple tree + movement live in archive/movement/.
local GrappleData = {}

-- ===== COSMETICS: the rope + hook look (category "Grapple" in Cosmetics; your own grapple, first person) =====
-- Rope = { colour at the hand, colour at the hook }; Width; Hook = { Color, Material, Shape "Ball"|"Block", Size };
-- Emit = particle colour off the hook (nil = none); Rainbow = the rope cycles hue; Light = light emission (0..1).
GrappleData.Looks = {
    { Id = "Standard", Name = "Standard Line", Rarity = "Common", Unlock = "Free", Desc = "The issue grapple: a bright cyan line.",
      Rope = { Color3.fromRGB(120, 230, 255), Color3.fromRGB(120, 230, 255) }, Width = 0.09, Light = 1,
      Hook = { Color = Color3.fromRGB(150, 235, 255), Material = Enum.Material.Neon, Shape = "Ball", Size = 0.38 } },
    { Id = "Ember", Name = "Ember Chain", Rarity = "Uncommon", Unlock = "Level", Level = 10, Desc = "A glowing hot chain with a forged hook that sheds sparks.",
      Rope = { Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 30) }, Width = 0.11, Light = 1,
      Hook = { Color = Color3.fromRGB(60, 40, 35), Material = Enum.Material.CorrodedMetal, Shape = "Block", Size = 0.4 }, Emit = Color3.fromRGB(255, 140, 40) },
    { Id = "Toxic", Name = "Toxic Tether", Rarity = "Rare", Unlock = "Level", Level = 20, Desc = "A dripping green line. The hook fizzes where it bites.",
      Rope = { Color3.fromRGB(170, 255, 90), Color3.fromRGB(60, 200, 60) }, Width = 0.1, Light = 1,
      Hook = { Color = Color3.fromRGB(120, 255, 90), Material = Enum.Material.Neon, Shape = "Ball", Size = 0.42 }, Emit = Color3.fromRGB(140, 255, 90) },
    { Id = "Void", Name = "Void Line", Rarity = "Epic", Unlock = "Level", Level = 35, Desc = "A thread of nothing that drinks the light around it.",
      Rope = { Color3.fromRGB(190, 110, 255), Color3.fromRGB(40, 10, 70) }, Width = 0.12, Light = 0.6,
      Hook = { Color = Color3.fromRGB(25, 10, 40), Material = Enum.Material.Glass, Shape = "Ball", Size = 0.46 }, Emit = Color3.fromRGB(170, 90, 255) },
    { Id = "Prismatic", Name = "Prismatic Cord", Rarity = "Epic", Unlock = "Robux", Price = 199, ProductId = 3716099995, Desc = "A rope that runs through every colour as you swing.",
      Rope = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(80, 160, 255) }, Width = 0.11, Light = 1, Rainbow = true,
      Hook = { Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon, Shape = "Ball", Size = 0.42 }, Emit = Color3.fromRGB(255, 255, 255) },
    { Id = "Seraphim", Name = "Seraphim Halo Line", Rarity = "Legendary", Unlock = "Robux", Price = 299, ProductId = 3716100004, Desc = "Gold light from a halo-ring hook, trailing feathers of light.",
      Rope = { Color3.fromRGB(255, 250, 220), Color3.fromRGB(255, 205, 90) }, Width = 0.12, Light = 1,
      Hook = { Color = Color3.fromRGB(255, 215, 110), Material = Enum.Material.Neon, Shape = "Ring", Size = 0.5 }, Emit = Color3.fromRGB(255, 235, 170) },
}
GrappleData.LookById = {}
for _, l in ipairs(GrappleData.Looks) do GrappleData.LookById[l.Id] = l end
-- the equipped look (CosmeticsEquipped.Grapple; nothing picked = the standard line)
function GrappleData.LookFor(state)
    local eq = type(state) == "table" and type(state.CosmeticsEquipped) == "table" and state.CosmeticsEquipped.Grapple
    return GrappleData.LookById[eq or ""] or GrappleData.Looks[1]
end

return GrappleData
