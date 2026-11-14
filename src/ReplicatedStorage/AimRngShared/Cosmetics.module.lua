--!nocheck
-- COSMETICS: one catalog over every cosmetic system (2026-10-02, owner: "revamp the whole cosmetic system -- a dedicated
-- cosmetic shop on the left in the hub and a dedicated inventory, right now they're far too hard to find" + "make sure
-- there is room to add armor / weapon / charm cosmetics etc").
-- The SHOP / MY COSMETICS window (CosmeticsMenu) and the server (CombatServer "CosmeticAction") only talk to this module.
--
-- ===== ADDING A CATEGORY (armor sets, weapon skins, charms, ...) =====
-- Add one entry to Cosmetics.Categories below. Required: Id, Label, Icon, Color, Desc, Items = function() -> raw list.
-- Each raw item: { Id, Name, Rarity, Desc?, Unlock = "Free" | "Robux" | "Drop" | "Level" | "Achievement", Price?,
--   ProductId? (0 = not on sale yet), Level?, How? (shop text), Image? (rbxassetid for the card), Color? (swatch) }.
-- That's all: ownership + the equipped choice are stored for you in state.CosmeticsOwned / state.CosmeticsEquipped
-- (saved), the shop sells it (Robux receipts included), the locker equips it, cards preview Image / Color.
-- Optional hooks when a category has its own storage or its own look on the character:
--   Owns(state, e), Equipped(state, e), Grant(state, e), Equip(state, e) -- pure state changes (shared)
--   Preview = "Bar" | "Avatar" | "Melee" | "Icon" (how the card previews it; default "Icon")
--   Soon = true (listed as "coming soon" until it has items)
-- Server-side extras after an equip (re-dress the character, sync attributes) live in CombatServer.EquipCosmetic.
--   entry (normalized) = { Cat, Id, Name, Rarity, Desc, Unlock, Price, ProductId, Level, How, Image, Color, Src }
local Shared = script.Parent
local BarStyles = require(Shared:WaitForChild("BarStyles"))
local AvatarData = require(Shared:WaitForChild("AvatarData"))
local MeleeData = require(Shared:WaitForChild("MeleeData"))
local SkinFX = require(Shared:WaitForChild("SkinFX"))
local GloveFX = require(Shared:WaitForChild("GloveFX"))
local HudThemes = require(Shared:WaitForChild("HudThemes"))
local ArmorFX = require(Shared:WaitForChild("ArmorFX"))
local GrappleData = require(Shared:WaitForChild("GrappleData"))
local CosmeticArt = require(Shared:WaitForChild("CosmeticArt"))

local Cosmetics = {}

Cosmetics.RarityOrder = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }
Cosmetics.RarityColor = BarStyles.RarityColor

local function DropHow(rarity)
    if rarity == "Mythic" or rarity == "Legendary" then return "Dungeon drop: best odds from bosses and superbosses" end
    return "Dungeon drop: any enemy can drop it (bosses and goblins more often)"
end

-- ---------- generic storage (any category without its own) ----------
local function Key(e) return e.Cat .. ":" .. e.Id end
local function GenericOwns(state, e)
    if e.Unlock == "Free" then return true end
    if e.Unlock == "Level" then return (type(state) == "table" and state.Level or 1) >= (e.Level or 1) end
    return type(state) == "table" and type(state.CosmeticsOwned) == "table" and state.CosmeticsOwned[Key(e)] == true
end
local function GenericEquipped(state, e)
    local eq = type(state) == "table" and type(state.CosmeticsEquipped) == "table" and state.CosmeticsEquipped[e.Cat]
    if eq == nil then
        -- nothing picked yet: the category's first free item counts as worn
        for _, x in ipairs(Cosmetics.List(e.Cat)) do if x.Unlock == "Free" then return x.Id == e.Id end end
        return false
    end
    return eq == e.Id
end
local function GenericGrant(state, e)
    state.CosmeticsOwned = type(state.CosmeticsOwned) == "table" and state.CosmeticsOwned or {}
    state.CosmeticsOwned[Key(e)] = true
end
local function GenericEquip(state, e)
    state.CosmeticsEquipped = type(state.CosmeticsEquipped) == "table" and state.CosmeticsEquipped or {}
    state.CosmeticsEquipped[e.Cat] = e.Id
end
Cosmetics.EquippedId = function(state, catId) -- the generic equipped choice (for future categories' gameplay code)
    return type(state) == "table" and type(state.CosmeticsEquipped) == "table" and state.CosmeticsEquipped[catId] or nil
end

-- ---------- outfit pieces (AvatarData) ----------
local function AvatarItems(catId)
    local out = {}
    for _, e in ipairs(AvatarData[catId]) do
        local u = e.Unlock
        local unlock, rarity, how, price, pid, lvl = "Free", e.Rarity or "Common", "Free", nil, 0, nil
        if u and u.Level then unlock, lvl, how = "Level", u.Level, "Reach level " .. u.Level; rarity = e.Rarity or "Rare"
        elseif u and u.Robux then unlock, price, pid, how = "Robux", u.Robux, u.ProductId or 0, nil; rarity = e.Rarity or "Legendary"
        elseif u and u.Drop then unlock, how = "Drop", DropHow(rarity) end
        -- skin tones: only the special ones are worth a slot in the shop / locker (the basics live in the Style Studio)
        if (catId ~= "Skin" or u) and not e.Legacy then -- (retired legacy pieces stay out of the store / collection)
            table.insert(out, { Id = e.Id, Name = e.Name, Rarity = rarity, Desc = e.Desc, Unlock = unlock, Price = price,
                ProductId = pid, Level = lvl, How = how, Color = e.Color, Src = e })
        end
    end
    return out
end
local function AvatarCategory(def)
    def.Preview = "Avatar"
    def.Items = function() return AvatarItems(def.Id) end
    def.Owns = function(state, e) return (AvatarData.IsUnlocked(e.Src, state)) end
    def.Equipped = function(state, e) return Cosmetics.Look(state)[e.Cat] == e.Id end
    def.Grant = function(state, e)
        state.AvatarOwned = type(state.AvatarOwned) == "table" and state.AvatarOwned or {}
        state.AvatarOwned[e.Cat .. ":" .. e.Id] = true
    end
    def.Equip = function(state, e)
        local look = Cosmetics.Look(state)
        look[e.Cat] = e.Id
        state.Avatar = AvatarData.Sanitize(look, state)
    end
    def.Avatar = true
    return def
end

-- ===== the categories, in sidebar order =====
Cosmetics.Categories = {
    { Id = "HealthBar", Label = "HEALTH BARS", Icon = "", IconKey = "cat_heart", Color = Color3.fromRGB(255, 80, 110), Desc = "How enemy and boss health bars look for you.",
      Preview = "Bar",
      Items = function()
          local out = {}
          for _, s in ipairs(BarStyles.List) do
              table.insert(out, { Id = s.Id, Name = s.Name, Rarity = s.Rarity, Desc = s.Desc, Unlock = s.Unlock, Price = s.Price, ProductId = s.ProductId or 0,
                  How = (s.Unlock == "Drop") and string.format("Superboss drop: 1 in %d (final floor of Hard and up)", math.round(1 / (s.DropChance or 0.01)))
                      or (s.Unlock == "Free" and "Free") or nil, Src = s })
          end
          return out
      end,
      Owns = function(state, e) return BarStyles.Owns(type(state) == "table" and state.BarStylesOwned or nil, e.Id) end,
      Equipped = function(state, e) return (type(state) == "table" and state.BarStyle or BarStyles.Default) == e.Id end,
      Grant = function(state, e)
          state.BarStylesOwned = type(state.BarStylesOwned) == "table" and state.BarStylesOwned or {}
          state.BarStylesOwned[e.Id] = true
      end,
      Equip = function(state, e) state.BarStyle = e.Id end },
    { Id = "MeleeSkin", Label = "MELEE SKINS", Icon = "", IconKey = "cat_knife", Color = Color3.fromRGB(220, 110, 255), Desc = "Finishes for every melee weapon you own.",
      Preview = "Melee",
      Items = function()
          local out = {}
          for _, id in ipairs(MeleeData.SkinOrder) do
              local s = MeleeData.Skins[id]
              local unlock = (s.Source == "Default" and "Free") or (s.Source == "Season" and "Season") or (s.Price and "Robux") or (s.Source == "Achievement" and "Achievement") or "Drop"
              table.insert(out, { Id = id, Name = s.Name, Rarity = s.Rarity, Desc = s.Desc, Unlock = unlock, Price = s.Price, ProductId = s.ProductId or 0,
                  How = s.How or (unlock == "Free" and "Free") or (unlock == "Achievement" and "Earned from an achievement") or (unlock == "Drop" and DropHow(s.Rarity)) or nil, Src = s })
          end
          return out
      end,
      Owns = function(state, e) return MeleeData.Owns(state, e.Id) end,
      Equipped = function(state, e)
          local _, id = MeleeData.SkinFor(state, type(state) == "table" and state.EquippedKnife or nil)
          return id == e.Id
      end,
      Grant = function(state, e)
          state.OwnedMeleeSkins = type(state.OwnedMeleeSkins) == "table" and state.OwnedMeleeSkins or {}
          state.OwnedMeleeSkins[e.Id] = true
      end,
      Equip = function(state, e, meleeIds)
          state.MeleeSkinFor = type(state.MeleeSkinFor) == "table" and state.MeleeSkinFor or {}
          for _, m in ipairs(meleeIds or {}) do state.MeleeSkinFor[m] = e.Id end -- the skin goes on every melee
      end },
    -- room for the next cosmetic lines (owner): give them Items and drop Soon to switch them on
    -- premium per-gun skins (SkinFX): each skin fits one gun; wearing it again takes it off (back to the factory look)
    { Id = "WeaponSkin", Label = "GUN SKINS", Icon = "", IconKey = "cat_palette", Color = Color3.fromRGB(255, 140, 60), Desc = "Premium skins for your guns. Each one fits a single gun.",
      Preview = "Gun", Toggle = true,
      Items = function()
          local out = {}
          for _, s in ipairs(SkinFX.GunSkins) do
              table.insert(out, { Id = s.Id, Name = s.Name, Rarity = s.Rarity, Desc = s.Desc, Unlock = "Robux", Price = s.Price, ProductId = s.ProductId or 0, Color = s.Color, Gun = s.Gun, Src = s })
          end
          return out
      end,
      Equipped = function(state, e) local s = SkinFX.GunSkinFor(state, e.Gun); return s ~= nil and s.Id == e.Id end,
      Equip = function(state, e)
          state.CosmeticsEquipped = type(state.CosmeticsEquipped) == "table" and state.CosmeticsEquipped or {}
          local key = SkinFX.EquipKey(e.Gun)
          state.CosmeticsEquipped[key] = (state.CosmeticsEquipped[key] ~= e.Id) and e.Id or nil
      end },
    -- gloves + sleeves (GloveFX): first-person hands / arms; gloves also show on your character
    { Id = "Glove", Label = "GLOVES", Hidden = true, Icon = "", IconKey = "cat_glove", Color = Color3.fromRGB(255, 120, 200), Desc = "Gloves for your hands, in first person and on your character.",
      Preview = "Glove", Items = function()
          local out = {}
          for _, g in ipairs(GloveFX.Gloves) do
              table.insert(out, { Id = g.Id, Name = g.Name, Rarity = g.Rarity, Desc = g.Desc, Unlock = g.Unlock, Price = g.Price, ProductId = g.ProductId or 0, Level = g.Level,
                  How = g.How, Color = g.Base and g.Base.Color or nil, Src = g })
          end
          return out
      end },
    { Id = "Sleeve", Label = "SLEEVES", Hidden = true, Icon = "", IconKey = "cat_sleeve", Color = Color3.fromRGB(140, 200, 255), Desc = "Sleeves for your first-person arms.",
      Preview = "Glove", Items = function()
          local out = {}
          for _, s in ipairs(GloveFX.Sleeves) do
              table.insert(out, { Id = s.Id, Name = s.Name, Rarity = s.Rarity, Desc = s.Desc, Unlock = s.Unlock, Price = s.Price, ProductId = s.ProductId or 0, Level = s.Level,
                  How = s.How, Color = s.Base and s.Base.Color or nil, Src = s, IsSleeve = true })
          end
          return out
      end },
    -- ARMS (0.97, owner: "Combine ALL arms and gloves into one cosmetics. This should honestly allow for better looking arms"
    -- -> "One arms item per set"): one piece = a glove + its sleeve. Owning either old half counts as owning the arms;
    -- granting / equipping the arms grants / equips both halves, so every glove + sleeve renderer works unchanged.
    { Id = "Arms", Label = "ARMS", Icon = "", IconKey = "cat_glove", Color = Color3.fromRGB(255, 120, 200),
      Desc = "Gloves and sleeves as one matched set, in first person and on your character.",
      Preview = "Arms", Items = function() return Cosmetics.ArmsItems() end,
      Owns = function(state, e)
          local g, sl = Cosmetics.Find("Glove", e.Glove), Cosmetics.Find("Sleeve", e.Sleeve)
          if e.Unlock == "Free" then return true end
          if e.Unlock == "Level" then return (type(state) == "table" and state.Level or 1) >= (e.Level or 1) end
          return GenericOwns(state, e) or (g ~= nil and Cosmetics.Owns(state, g)) or (sl ~= nil and Cosmetics.Owns(state, sl))
      end,
      Equipped = function(state, e)
          local g, sl = Cosmetics.Find("Glove", e.Glove), Cosmetics.Find("Sleeve", e.Sleeve)
          return (g == nil or Cosmetics.Equipped(state, g)) and (sl == nil or Cosmetics.Equipped(state, sl))
      end,
      Grant = function(state, e)
          GenericGrant(state, e)
          for _, ref in ipairs({ { "Glove", e.Glove }, { "Sleeve", e.Sleeve } }) do
              local ce = Cosmetics.Find(ref[1], ref[2])
              if ce and not Cosmetics.Owns(state, ce) then Cosmetics.Grant(state, ce) end
          end
      end,
      Equip = function(state, e)
          state.CosmeticsEquipped = type(state.CosmeticsEquipped) == "table" and state.CosmeticsEquipped or {}
          state.CosmeticsEquipped.Glove = e.Glove
          state.CosmeticsEquipped.Sleeve = e.Sleeve
          state.CosmeticsEquipped.Arms = e.Id
      end },
    -- grapple looks (GrappleData.Looks). RETIRED 2026-10-03 with the grapple (owner: "pull them from sale"): Hidden =
    -- not in the store / locker / admin lists; owners keep them in their save and a late Robux receipt still grants.
    { Id = "Grapple", Label = "GRAPPLES", Hidden = true, Icon = "", Color = Color3.fromRGB(90, 220, 255),
      Desc = "Your grapple's rope and hook. The line you see every time you swing.",
      Preview = "Grapple", Items = function()
          local out = {}
          for _, l in ipairs(GrappleData.Looks) do
              table.insert(out, { Id = l.Id, Name = l.Name, Rarity = l.Rarity, Desc = l.Desc, Unlock = l.Unlock, Price = l.Price, ProductId = l.ProductId or 0,
                  Level = l.Level, Color = l.Rope[2], Src = l })
          end
          return out
      end },
    -- UI themes (HudThemes / UITheme): restyle EVERY window, card and HUD panel; recolours drop, premium ones unlock by level
    { Id = "HudTheme", Label = "UI THEMES", Icon = "", IconKey = "cat_hud", Color = Color3.fromRGB(120, 230, 210), Desc = "Restyle the whole interface. Every menu, card and your HUD. Premium themes (art, animated borders and effects) come in their bundles.",
      Preview = "Hud", Items = function()
          local out = {}
          for _, t in ipairs(HudThemes.List) do
              local how = (t.Unlock == "Drop") and "Dungeon drop: bosses, superbosses, loot goblins and elites" or nil
              table.insert(out, { Id = t.Id, Name = t.Name, Rarity = t.Rarity, Desc = t.Desc, Unlock = t.Unlock, Price = t.Price, ProductId = t.ProductId or 0, Level = t.Level,
                  Color = t.Accent, How = how or t.How, Src = t })
          end
          return out
      end },
    -- KILL EFFECTS (owner 2026-10-04: "kill effects dont exist in the cosmetic tab. add those"): what plays when you kill
    -- something. MATCH MY SKIN = the old rule (the held skin's own effect); a set's effect, once picked, plays on every
    -- kill with any weapon. A set's effect is yours with any skin from that set (or its bundle). AimRngClient UI.SkinKill.
    { Id = "KillEffect", Label = "KILL EFFECTS", Icon = "", IconKey = "cat_star", Color = Color3.fromRGB(255, 184, 28),
      Desc = "What happens when you take an enemy down. Pick one to play on every kill, whatever you're holding.",
      Items = function()
          local base = {
              { Id = "Auto", Name = "Match My Skin", Rarity = "Common", Unlock = "Free", How = "Free",
                Desc = "Each premium skin plays its own kill effect; other weapons play none." },
              { Id = "Off", Name = "Off", Rarity = "Common", Unlock = "Free", How = "Free", Desc = "No kill effect, even with a premium skin." },
              { Id = "Ascension", Name = "Ascension", Rarity = "Mythic", Unlock = "Bundle", FX = "Seraphim", Image = CosmeticArt.EmblemSeraph,
                How = "Own any Seraphim skin (or the Seraphim Ascendant bundle)",
                Desc = "Wings of light unfold, a pillar of gold descends and a rune circle turns while feathers fall, with the Seraphim kill banner." },
              { Id = "Claimed", Name = "Claimed", Rarity = "Mythic", Unlock = "Bundle", FX = "Infernal", Image = CosmeticArt.EmblemInfernal,
                How = "Own any Infernal skin (or the Infernal Pact bundle)",
                Desc = "The ground splits, chains with red-hot tips drag the soul down and it flies to your weapon, with the seared tally banner." },
          }
          -- every SkinSets set brings its own (set.KillEffect = { Id, Name, Desc, How, Image? })
          local list = {}
          for _, e in ipairs(base) do table.insert(list, e) end
          for _, set in ipairs(SkinFX.SetOrder) do
              local k = set.KillEffect
              if k then
                  -- (2026-10-14, owner: "kill effects should be exclusive"): a set's kill effect is BUNDLE ONLY -- shown in the
                  -- store's KILL EFFECTS tab with GET THE ... BUNDLE; owned through the bundle (its Contents grant it)
                  table.insert(list, { Id = k.Id, Name = k.Name, Rarity = k.Rarity or "Mythic", Unlock = "Bundle", FX = set.Kind, Image = k.Image,
                      How = "Only in the " .. ((set.Bundle and set.Bundle.Name) or (set.Kind .. " bundle")), Desc = k.Desc })
              end
          end
          return list
      end,
      Owns = function(state, e)
          if e.Unlock == "Free" then return true end
          if type(state) == "table" and type(state.CosmeticsOwned) == "table" and state.CosmeticsOwned["KillEffect:" .. e.Id] then return true end
          -- (2026-10-14: bundle exclusive -- a set's skin alone no longer brings its kill effect; the old skin rule below
          -- stays only for the retired Seraphim / Infernal effects, which have no bundle any more)
          if e.Id ~= "Ascension" and e.Id ~= "Claimed" then return false end
          for _, s in ipairs(SkinFX.GunSkins) do
              if s.FX == e.FX then
                  local ce = Cosmetics.Find("WeaponSkin", s.Id)
                  if ce and Cosmetics.Owns(state, ce) then return true end
              end
          end
          for id, s in pairs(MeleeData.Skins) do
              if s.FX == e.FX or (e.FX and id == e.FX) then
                  local ce = Cosmetics.Find("MeleeSkin", id)
                  if ce and Cosmetics.Owns(state, ce) then return true end
              end
          end
          return false
      end,
      Equipped = function(state, e)
          local id = type(state) == "table" and type(state.CosmeticsEquipped) == "table" and state.CosmeticsEquipped.KillEffect or "Auto"
          return id == e.Id
      end },
    -- (outfit pieces + armor sets were retired 2026-10-02: players wear their own Roblox avatars, cosmetics are weapons,
    -- melees, gloves, sleeves, UI themes and health bars)
    -- bundles: a whole set in one purchase (cheaper than its pieces); owning = owning every piece
    { Id = "Bundle", Label = "BUNDLES", Icon = "", IconKey = "cat_bundle", Color = Color3.fromRGB(255, 180, 60),
      Desc = "Whole sets in one purchase. Every piece, cheaper than buying them one by one. Equip puts the whole set on.",
      Preview = "Bundle",
      Items = function()
          local out = {}
          for _, b in ipairs(ArmorFX.Bundles) do
              table.insert(out, { Id = b.Id, Name = b.Name, Rarity = b.Rarity, Desc = b.Desc, Unlock = b.Unlock, Price = b.Price, ProductId = b.ProductId or 0,
                  Contents = b.Contents, Color = Color3.fromRGB(255, 200, 90), Src = b, BP = b.BP }) -- (BP: the set's own price -- it was dropped here, so every bundle fell back to the Robux formula's 1199)
          end
          return out
      end,
      Owns = function(state, e)
          for _, ref in ipairs(e.Contents or {}) do
              local cat, id = ref:match("^(.-):(.*)$")
              local ce = Cosmetics.Find(cat, id)
              if ce and not Cosmetics.Owns(state, ce) then return false end
          end
          return true
      end,
      Equipped = function(state, e)
          for _, ref in ipairs(e.Contents or {}) do
              local cat, id = ref:match("^(.-):(.*)$")
              local ce = Cosmetics.Find(cat, id)
              if ce and not Cosmetics.Equipped(state, ce) then return false end
          end
          return true
      end,
      Grant = function(state, e)
          for _, ref in ipairs(e.Contents or {}) do
              local cat, id = ref:match("^(.-):(.*)$")
              local ce = Cosmetics.Find(cat, id)
              if ce then Cosmetics.Grant(state, ce) end
          end
      end,
      Equip = function(state, e, extra)
          for _, ref in ipairs(e.Contents or {}) do
              local cat, id = ref:match("^(.-):(.*)$")
              local ce = Cosmetics.Find(cat, id)
              -- (toggle categories take an item OFF when it's worn: only put on what isn't on yet)
              if ce and Cosmetics.Owns(state, ce) and not Cosmetics.Equipped(state, ce) then Cosmetics.Equip(state, ce, extra) end
          end
      end },
    -- HIDEOUT THEMES (0.56; owner 2026-10-07: "where are the hideout skins?" -- they were only in the HIDEOUT window's
    -- THEMES tab): the prebuilt hideouts are sold + worn here too. Storage stays state.Hideout.Themes / .Theme (HideoutData)
    { Id = "HideoutTheme", Label = "HIDEOUT THEMES", KeepAll = true, Icon = "", IconKey = "cat_bundle", Color = Color3.fromRGB(255, 150, 90),
      Desc = "Prebuilt hideouts: they change your whole hideout's look, and your furniture stays where you put it. Also in the HIDEOUT window [U].",
      Items = function()
          local HD = require(script.Parent:WaitForChild("HideoutData"))
          local swatch = { Apartment = Color3.fromRGB(150, 110, 80), Aquarium = Color3.fromRGB(40, 140, 200), Forest = Color3.fromRGB(70, 130, 60), Forge = Color3.fromRGB(230, 100, 40),
              Starwhale = Color3.fromRGB(70, 90, 190), Crystal = Color3.fromRGB(70, 170, 240) }
          local out = {}
          for _, id in ipairs(HD.THEME_ORDER) do
              local t = HD.THEMES[id]
              table.insert(out, { Id = id, Name = t.Name, Rarity = t.Rarity or "Common", Desc = t.Desc, Unlock = t.Free and "Free" or "Robux", Price = t.Price,
                  ProductId = t.ProductId or 0, Color = swatch[id] })
          end
          return out
      end,
      Owns = function(state, e)
          local HD = require(script.Parent:WaitForChild("HideoutData"))
          local t = HD.THEMES[e.Id]
          local h = type(state) == "table" and type(state.Hideout) == "table" and state.Hideout or {}
          return t ~= nil and (t.Free == true or (type(h.Themes) == "table" and h.Themes[e.Id] == true))
      end,
      Equipped = function(state, e)
          local HD = require(script.Parent:WaitForChild("HideoutData"))
          return HD.ThemeOf(state) == e.Id
      end,
      Grant = function(state, e)
          state.Hideout = type(state.Hideout) == "table" and state.Hideout or {}
          state.Hideout.Themes = type(state.Hideout.Themes) == "table" and state.Hideout.Themes or {}
          state.Hideout.Themes[e.Id] = true
      end,
      Equip = function(state, e)
          state.Hideout = type(state.Hideout) == "table" and state.Hideout or {}
          state.Hideout.Theme = e.Id
      end },
    -- STASH + PORTAL SKINS (0.58, owner: "Stashes and portals will have skins for the hideout"): looks for your hideout's
    -- stash chest and the map room's portal (HideoutData.STASH_SKINS / PORTAL_SKINS + builders); generic storage, published
    -- on the owner (Hideouts.Publish) so visitors see them too
    { Id = "HideoutStash", Label = "STASH SKINS", KeepAll = true, Icon = "", IconKey = "cat_bundle", Color = Color3.fromRGB(255, 190, 90),
      Desc = "Looks for the stash chest in your hideout.",
      Items = function()
          local HD = require(script.Parent:WaitForChild("HideoutData"))
          local out = {}
          for _, s in ipairs(HD.STASH_SKINS) do
              table.insert(out, { Id = s.Id, Name = s.Name, Rarity = s.Rarity or "Common", Desc = s.Desc, Unlock = s.Free and "Free" or "Robux", Price = s.Price,
                  ProductId = s.ProductId or 0, Color = s.Color })
          end
          return out
      end },
    { Id = "HideoutPortal", Label = "PORTAL SKINS", KeepAll = true, Icon = "", IconKey = "cat_bundle", Color = Color3.fromRGB(170, 110, 255),
      Desc = "Looks for the map room's portal: the gate that opens when you use a Rift Sigil at the map device.",
      Items = function()
          local HD = require(script.Parent:WaitForChild("HideoutData"))
          local out = {}
          for _, s in ipairs(HD.PORTAL_SKINS) do
              table.insert(out, { Id = s.Id, Name = s.Name, Rarity = s.Rarity or "Common", Desc = s.Desc, Unlock = s.Free and "Free" or "Robux", Price = s.Price,
                  ProductId = s.ProductId or 0, Color = s.Color })
          end
          return out
      end },
    { Id = "Charm", Label = "CHARMS", Icon = "", IconKey = "cat_charm", Color = Color3.fromRGB(120, 230, 210), Desc = "Trinkets that hang off your weapon.", Soon = true, Items = function() return {} end },
}
Cosmetics.CategoryById = {}
for i, c in ipairs(Cosmetics.Categories) do
    c.Order = i
    c.Preview = c.Preview or "Icon"
    Cosmetics.CategoryById[c.Id] = c
end
-- (kept for callers: which categories dress the character)
Cosmetics.IsAvatarCat = {}
for _, c in ipairs(Cosmetics.Categories) do if c.Avatar then Cosmetics.IsAvatarCat[c.Id] = true end end

-- ===== the line-up (owner 2026-10-04: "lets take out everything but the bundle cosmetics") =====
-- Only the bundles' pieces (ArmorFX.Bundles Contents) and each category's free default stay in the store, the locker,
-- drops and on players. Everything else is RETIRED: owners keep it in their save (and a late Robux receipt still
-- grants), but it isn't listed and gets taken off (Cosmetics.StripRetired on load). Clear the set to bring them back.
-- ARMS pairs (0.97): every set's glove + sleeve (GloveFX Set field) and hand-picked pairs for the rest
Cosmetics.ARMS_PAIRS = {
    { Id = "StandardIssue", Name = "Standard Issue", Glove = "Tactical", Sleeve = "Standard" },
    { Id = "BareArms", Name = "Bare Hands", Glove = "BareHands", Sleeve = "Standard" },
    { Id = "FieldLeather", Name = "Field Leather", Glove = "Leather", Sleeve = "Urban" },
    { Id = "CarbonGuard", Name = "Carbon Guard", Glove = "Carbon", Sleeve = "Crimson" },
    { Id = "RangerArms", Name = "Ranger", Glove = "Ranger", Sleeve = "Standard" },
    { Id = "CelestialArms", Name = "Celestial Fury", Glove = "CelestialFury", Sleeve = "Seraphim" },
    { Id = "VoidrendArms", Name = "Voidrend", Glove = "Voidrend", Sleeve = "VoidSilk" },
    { Id = "InfernoArms", Name = "Inferno", Glove = "InfernoGauntlets", Sleeve = "Emberweave" },
    { Id = "PrismArms", Name = "Prism Shift", Glove = "PrismShift", Sleeve = "RoyalPearl" },
    { Id = "ArcPulseArms", Name = "Arc Pulse", Glove = "ArcPulse", Sleeve = "Standard" },
    { Id = "SeraphArms", Name = "Seraph Grips", Glove = "SeraphGrips", Sleeve = "Standard" },
    { Id = "ChronoArms", Name = "Chrono Gauntlets", Glove = "ChronoGauntlets", Sleeve = "Standard" },
    { Id = "EchoArms", Name = "Echo Wraps", Glove = "EchoWraps", Sleeve = "Standard" },
    { Id = "ForgeheartArms", Name = "Forgeheart Grips", Glove = "ForgeheartGrips", Sleeve = "Standard" },
    { Id = "TitanArms", Name = "Titanbreakers", Glove = "Titanbreakers", Sleeve = "Standard" },
}
local armsCache = nil
function Cosmetics.ArmsItems()
    if armsCache then return armsCache end
    local out, used = {}, {}
    local function Add(id, name, g, sl, set)
        if not g then return end
        used[g.Id] = true
        local desc = tostring(g.Desc or "") .. ((sl and sl.Desc) and (" Sleeves: " .. sl.Desc) or "")
        table.insert(out, { Id = id, Name = name, Rarity = g.Rarity, Desc = desc, Unlock = g.Unlock, Price = (g.Unlock == "Robux") and ((g.Price or 0) + (sl and sl.Price or 0)) or g.Price,
            ProductId = 0, Level = g.Level, How = g.How, Color = g.Base and g.Base.Color or nil, Glove = g.Id, Sleeve = sl and sl.Id or "Standard",
            Src = { Set = set or g.Set, Glove = g, Sleeve = sl } })
    end
    for _, pr in ipairs(Cosmetics.ARMS_PAIRS) do Add(pr.Id, pr.Name, GloveFX.GloveById[pr.Glove], GloveFX.SleeveById[pr.Sleeve]) end
    -- every set: its glove + its sleeve, named after the set's glove ("Tempest Gauntlets" -> arms "Tempest Gauntlets")
    for _, g in ipairs(GloveFX.Gloves) do
        if g.Set and not used[g.Id] then
            local sl
            for _, x in ipairs(GloveFX.Sleeves) do if x.Set == g.Set then sl = x; break end end
            Add(g.Set .. "Arms", g.Name, g, sl, g.Set)
        end
    end
    -- any glove left unpaired still becomes arms (with the standard sleeve) so nothing anyone owns disappears
    for _, g in ipairs(GloveFX.Gloves) do if not used[g.Id] then Add(g.Id .. "Arms", g.Name, g, GloveFX.SleeveById.Standard) end end
    armsCache = out
    return out
end
-- bundles sell the arms, not the two halves: "Glove:X" -> "Arms:<its arms>", "Sleeve:Y" dropped (rewritten in place, so the
-- server's set checks and the store read the same contents)
do
    local byGlove, bySleeve = {}, {}
    for _, a in ipairs(Cosmetics.ArmsItems()) do byGlove[a.Glove] = a.Id; if a.Sleeve ~= "Standard" then bySleeve[a.Sleeve] = bySleeve[a.Sleeve] or a.Id end end
    local function Fix(list)
        if type(list) ~= "table" then return end
        local out = {}
        for _, ref in ipairs(list) do
            local cat, id = ref:match("^(.-):(.*)$")
            if cat == "Glove" and byGlove[id] then
                if not table.find(out, "Arms:" .. byGlove[id]) then table.insert(out, "Arms:" .. byGlove[id]) end
            elseif cat == "Sleeve" and bySleeve[id] then
                if not table.find(out, "Arms:" .. bySleeve[id]) then table.insert(out, "Arms:" .. bySleeve[id]) end
            else
                table.insert(out, ref)
            end
        end
        table.clear(list)
        for _, r in ipairs(out) do table.insert(list, r) end
    end
    for _, b in ipairs(ArmorFX.Bundles) do Fix(b.Contents); Fix(b.Added) end
end
Cosmetics.KEEP_ONLY_BUNDLES = true
local KEEP = {}
for _, b in ipairs(ArmorFX.Bundles) do for _, ref in ipairs(b.Contents or {}) do KEEP[ref] = true end end
-- (2026-10-15, owner: "Why arent my arms saving when I leave?"): the bundles list ARMS ("Arms:<Set>Arms"), not their glove +
-- sleeve halves, so every set glove / sleeve came out "retired" -- and StripRetired took the worn halves off on every load
-- (the arms read as worn only while both halves are). The halves of a live pair of arms are live too.
for _, a in ipairs(Cosmetics.ArmsItems()) do
    if KEEP["Arms:" .. a.Id] or a.Unlock == "Season" then
        KEEP["Glove:" .. tostring(a.Glove)] = true
        if a.Sleeve and a.Sleeve ~= "Standard" then KEEP["Sleeve:" .. a.Sleeve] = true end
    end
end
local function IsRetired(catId, e)
    if not Cosmetics.KEEP_ONLY_BUNDLES or catId == "Bundle" or e.Unlock == "Free" then return false end
    if e.Unlock == "Season" then return false end -- (skinsB: season pass rewards are earned, never sold: listed, never stripped)
    local c = Cosmetics.CategoryById[catId]
    if c and c.KeepAll then return false end -- (a category sold on its own, outside bundles: hideout themes)
    return not KEEP[catId .. ":" .. e.Id]
end

-- ===== reading the catalog =====
local cache, fullCache = {}, {}
-- (includeRetired: the pieces taken out of the line-up too -- Find, receipts and StripRetired want those)
function Cosmetics.List(catId, includeRetired: boolean?)
    if includeRetired then
        if not fullCache[catId] then Cosmetics.List(catId) end
        return fullCache[catId] or {}
    end
    if cache[catId] then return cache[catId] end
    local cat = Cosmetics.CategoryById[catId]
    local out, full = {}, {}
    if cat then
        for _, raw in ipairs(cat.Items()) do
            local e = table.clone(raw)
            e.Cat = catId
            e.Rarity = e.Rarity or "Common"
            e.Unlock = e.Unlock or "Free"
            e.ProductId = e.ProductId or 0
            if e.Name == "None" then e.Name = "No " .. string.lower(cat.Label) end
            if not e.How and e.Unlock == "Drop" then e.How = DropHow(e.Rarity) end
            if not e.How and e.Unlock == "Level" then e.How = "Reach level " .. tostring(e.Level) end
            e.Retired = IsRetired(catId, e) or nil
            table.insert(full, e)
            if not e.Retired then table.insert(out, e) end
        end
    end
    cache[catId], fullCache[catId] = out, full
    return out
end

-- take off anything retired or not owned (the server calls this when a save loads); returns true if something changed
function Cosmetics.StripRetired(state): boolean
    if type(state) ~= "table" then return false end
    local changed = false
    -- bundle pieces added after launch (ArmorFX bundle `Added`): whoever owns the rest of the bundle gets them
    for _, b in ipairs(ArmorFX.Bundles) do
        if b.Added then
            local hasRest, missing = true, {}
            for _, ref in ipairs(b.Contents or {}) do
                local cat, id = ref:match("^(.-):(.*)$")
                local ce = Cosmetics.Find(cat, id)
                if ce and not Cosmetics.Owns(state, ce) then
                    -- (a piece traded away: CosmeticsOwned[ref] == false, never handed back)
                    local gone = type(state.CosmeticsOwned) == "table" and state.CosmeticsOwned[ref] == false
                    local added = table.find(b.Added, ref) ~= nil
                    if added and not gone then table.insert(missing, ce) elseif not added then hasRest = false end
                end
            end
            if hasRest then for _, ce in ipairs(missing) do Cosmetics.Grant(state, ce); changed = true end end
        end
    end
    for _, c in ipairs(Cosmetics.Categories) do
        if c.Id ~= "Bundle" and not c.Soon then
            for _, e in ipairs(Cosmetics.List(c.Id, true)) do
                -- (also anything worn but no longer owned, e.g. the Seraphim theme that used to unlock at level 10)
                local off = (e.Retired and c.Id == "MeleeSkin") or ((e.Retired or not Cosmetics.Owns(state, e)) and Cosmetics.Equipped(state, e))
                if off then
                    changed = true
                    if c.Id == "WeaponSkin" then
                        Cosmetics.Equip(state, e) -- (toggle: wearing it again takes it off)
                    elseif c.Id == "MeleeSkin" then
                        for m, id in pairs(type(state.MeleeSkinFor) == "table" and state.MeleeSkinFor or {}) do
                            if id == e.Id then state.MeleeSkinFor[m] = nil end
                        end
                    elseif c.Id == "HealthBar" then
                        state.BarStyle = BarStyles.Default
                    else
                        local def
                        for _, x in ipairs(Cosmetics.List(c.Id)) do if x.Unlock == "Free" then def = x.Id; break end end
                        state.CosmeticsEquipped = type(state.CosmeticsEquipped) == "table" and state.CosmeticsEquipped or {}
                        state.CosmeticsEquipped[c.Id] = def
                    end
                end
            end
        end
    end
    return changed
end

-- (includeHidden: retired categories too -- only purchase receipts want those)
function Cosmetics.All(includeHidden: boolean?)
    local out = {}
    for _, c in ipairs(Cosmetics.Categories) do
        if includeHidden or not c.Hidden then
            for _, e in ipairs(Cosmetics.List(c.Id, includeHidden)) do table.insert(out, e) end
        end
    end
    return out
end

function Cosmetics.Find(catId, id)
    for _, e in ipairs(Cosmetics.List(catId, true)) do if e.Id == id then return e end end
    return nil
end

-- the saved look with every key filled in (what the character is wearing)
function Cosmetics.Look(state)
    return AvatarData.Sanitize(type(state) == "table" and state.Avatar or nil, state)
end

function Cosmetics.Owns(state, e)
    local cat = e and Cosmetics.CategoryById[e.Cat]
    if not cat then return false end
    return (cat.Owns or GenericOwns)(state, e)
end

function Cosmetics.Equipped(state, e)
    local cat = e and Cosmetics.CategoryById[e.Cat]
    if not cat or type(state) ~= "table" then return false end
    return (cat.Equipped or GenericEquipped)(state, e)
end

-- state changes only (the server calls these, then does the side effects)
function Cosmetics.Grant(state, e) local cat = Cosmetics.CategoryById[e.Cat]; (cat.Grant or GenericGrant)(state, e) end
function Cosmetics.Equip(state, e, extra) local cat = Cosmetics.CategoryById[e.Cat]; (cat.Equip or GenericEquip)(state, e, extra) end

-- SKIN TRADING (2026-10-14, owner: "Can we add the ability to trade skins?" -> store pieces + the season pass rewards, no
-- trade hold): what TradeService lets players swap. Bundles trade as their pieces; free / level / drop unlocks, colourways,
-- hideout looks and retired pieces stay with the account.
Cosmetics.TRADE_CATS = { "WeaponSkin", "MeleeSkin", "Arms", "HealthBar", "HudTheme", "KillEffect" }
local TRADE_CAT, TRADE_UNLOCK = {}, { Robux = true, Bundle = true, Season = true }
for _, c in ipairs(Cosmetics.TRADE_CATS) do TRADE_CAT[c] = true end
function Cosmetics.Tradeable(e): boolean
    return e ~= nil and TRADE_CAT[e.Cat] == true and TRADE_UNLOCK[e.Unlock] == true and not e.Retired
end
-- take one piece away (pure state; the server syncs). Wearing it puts the category's default back on. The piece's key in
-- CosmeticsOwned is left as false: StripRetired must not hand a traded-away bundle piece (`Added`) back on the next load.
function Cosmetics.Revoke(state, e)
    if type(state) ~= "table" or not e then return end
    state.CosmeticsOwned = type(state.CosmeticsOwned) == "table" and state.CosmeticsOwned or {}
    state.CosmeticsEquipped = type(state.CosmeticsEquipped) == "table" and state.CosmeticsEquipped or {}
    local owned, eq = state.CosmeticsOwned, state.CosmeticsEquipped
    owned[Key(e)] = false
    if type(state.SkinCopies) == "table" then state.SkinCopies[Key(e)] = nil end -- (every copy goes: TakeCopy spends extras first)
    if e.Cat == "WeaponSkin" then
        local k = SkinFX.EquipKey(e.Gun)
        if eq[k] == e.Id then eq[k] = nil end
    elseif e.Cat == "MeleeSkin" then
        if type(state.OwnedMeleeSkins) == "table" then state.OwnedMeleeSkins[e.Id] = nil end
        for m, id in pairs(type(state.MeleeSkinFor) == "table" and state.MeleeSkinFor or {}) do
            if id == e.Id then state.MeleeSkinFor[m] = nil end
        end
    elseif e.Cat == "HealthBar" then
        if type(state.BarStylesOwned) == "string" then -- (old saves keep a comma list)
            local t = {}
            for _, id in ipairs(string.split(state.BarStylesOwned, ",")) do if id ~= "" then t[id] = true end end
            state.BarStylesOwned = t
        end
        if type(state.BarStylesOwned) == "table" then state.BarStylesOwned[e.Id] = nil end
        if state.BarStyle == e.Id then state.BarStyle = BarStyles.Default end
    elseif e.Cat == "Arms" then
        local worn = Cosmetics.Equipped(state, e) or eq.Arms == e.Id
        for _, ref in ipairs({ { "Glove", e.Glove }, { "Sleeve", e.Sleeve } }) do
            local ce = Cosmetics.Find(ref[1], ref[2])
            if ce and ce.Unlock ~= "Free" then owned[Key(ce)] = false end
        end
        if worn then
            for _, x in ipairs(Cosmetics.List("Arms")) do
                if x.Unlock == "Free" then Cosmetics.Equip(state, x); break end
            end
        end
    else -- (HudTheme, KillEffect and other generic categories: the equip key is the category)
        if eq[e.Cat] == e.Id then eq[e.Cat] = nil end
    end
end
-- COPIES (2026-10-14, owner: "players should be able to own multiple and have a way to see that ... maximize incentive to
-- spend"): a tradeable piece can be owned more than once -- buy it again, get it in a trade, buy its bundle again. The first
-- copy lives in the category's own storage; extra copies are counted in state.SkinCopies[ref] (saved, carried on wipes).
function Cosmetics.Copies(state, e): number
    if not e or not Cosmetics.Owns(state, e) then return 0 end
    local t = type(state) == "table" and type(state.SkinCopies) == "table" and state.SkinCopies or nil
    return 1 + math.max(0, math.floor(tonumber(t and t[Key(e)]) or 0))
end
-- one more copy: a first one is granted (and stops being "traded away"), the rest are counted
function Cosmetics.AddCopy(state, e)
    if not e then return end
    local ref = Key(e)
    if Cosmetics.Tradeable(e) and Cosmetics.Owns(state, e) then
        state.SkinCopies = type(state.SkinCopies) == "table" and state.SkinCopies or {}
        state.SkinCopies[ref] = math.max(0, math.floor(tonumber(state.SkinCopies[ref]) or 0)) + 1
        return
    end
    Cosmetics.Grant(state, e)
    if type(state.CosmeticsOwned) == "table" and state.CosmeticsOwned[ref] == false then state.CosmeticsOwned[ref] = nil end
end
-- one copy less: an extra one if there is one (the worn skin stays on), else the piece itself (Revoke)
function Cosmetics.TakeCopy(state, e)
    if not e then return end
    local ref = Key(e)
    local t = type(state.SkinCopies) == "table" and state.SkinCopies or nil
    local n = t and math.floor(tonumber(t[ref]) or 0) or 0
    if n > 0 then
        t[ref] = (n > 1) and (n - 1) or nil
        return
    end
    Cosmetics.Revoke(state, e)
end

-- (skinsB) the store's bundle shelf (home grid + hero): every bundle but the season pass sets (Unlock "Season": earned, never sold)
function Cosmetics.ShelfBundles()
    local out = {}
    for _, b in ipairs(Cosmetics.List("Bundle")) do if b.Unlock ~= "Season" then table.insert(out, b) end end
    return out
end

-- can it be bought with Robux? (ProductId 0 = not on sale yet; Studio tests give it free)
function Cosmetics.Buyable(e)
    return e ~= nil and e.Unlock == "Robux" and e.Price ~= nil
end

-- BOUND SHOP (0.97, owner: "Everything in the shop will be purchasable with the bound points ... On average, the bundles
-- should cost 999 bound points. Individual items can also be purchased, but ... buying the items single would be a far worse
-- deal"): every store item's price in BOUND points. Bundles ~999 (scaled by their old Robux price: the 3-gun Ironclad 1199);
-- single pieces by category (a whole set bought piece by piece costs about twice its bundle). e.BP overrides.
-- (2026-10-14 owner pricing pass: Roblox players buy at R$ 100-400 -- every single piece roughly halved, bundles ~40% under
-- their pieces; was 349 / 449 / 449 / 299 / 649 / 149 / 299 / 199 / 699 / 349 / 349)
Cosmetics.BP_BY_CAT = { WeaponSkin = 199, MeleeSkin = 249, Glove = 249, Sleeve = 149, Arms = 249, HealthBar = 79, HudTheme = 149,
    KillEffect = 99, HideoutTheme = 399, HideoutStash = 199, HideoutPortal = 199 }
function Cosmetics.BPPrice(e): number?
    if not Cosmetics.Buyable(e) then return nil end
    if e.BP then return e.BP end
    if e.Cat == "Bundle" then return math.max(799, math.round((e.Price or 1799) * 999 / 1799 / 50) * 50 - 1) end
    return Cosmetics.BP_BY_CAT[e.Cat] or math.max(99, math.round((e.Price or 100) * 0.9 / 10) * 10 - 1)
end

-- (Update 5 SKINS V3) the OLD skins' live developer products: a late receipt for one refunds BOUND points (its Robux price
-- 1:1) instead of granting a removed item (CombatServer ProcessReceipt). Owner: take these products off sale.
Cosmetics.RETIRED_PRODUCTS = {
    [3716100063] = 1799, -- Seraphim Ascendant bundle
    [3716099889] = 399, [3716099897] = 399, [3716099878] = 499, -- Seraphim M4A1 / AK-47 / Spear
    [3716099911] = 799, [3716099918] = 799, [3716099928] = 799, [3716099936] = 699, [3716099945] = 499, -- gloves
    [3716099960] = 299, [3716099967] = 399, [3716099977] = 399, [3716099987] = 399, -- sleeves
    [3716099790] = 49, [3716099805] = 79, [3716099812] = 79, [3716099821] = 79, [3716099825] = 79, [3716099834] = 99,
    [3716099841] = 99, [3716099853] = 149, [3716099860] = 149, [3716099871] = 149, -- health bars
    [3716100004] = 299, -- the Seraphim Halo grapple line
    [3716099995] = 199, -- the Prismatic Cord grapple line (grapple removed from the game)
    [3716100013] = 499, [3716100024] = 499, [3716100031] = 499, [3716100045] = 499, [3716100055] = 499, -- old UI themes
}
-- (Update 5 SKINS V3) clear equipped cosmetics that no catalog entry has any more (old skin ids in old saves): one key at a
-- time, ownership untouched. -> true if something changed
function Cosmetics.ClearUnknownEquipped(state): boolean
    local eq = type(state) == "table" and type(state.CosmeticsEquipped) == "table" and state.CosmeticsEquipped
    if not eq then return false end
    local changed = false
    for k, v in pairs(eq) do
        local cat = type(k) == "string" and string.match(k, "^([%w]+)")
        if cat and Cosmetics.CategoryById[cat] and type(v) == "string" and v ~= "" and not Cosmetics.Find(cat, v) then
            eq[k] = nil
            changed = true
        end
    end
    return changed
end

-- product id -> entry, for the server's purchase receipts
function Cosmetics.ByProduct()
    local map = {}
    for _, e in ipairs(Cosmetics.All(true)) do
        if e.Unlock == "Robux" and (e.ProductId or 0) ~= 0 then map[e.ProductId] = e end
    end
    return map
end

return Cosmetics
