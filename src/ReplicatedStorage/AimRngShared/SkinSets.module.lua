--!nocheck
-- SKIN SETS registry (2026-10-04 night, owner's "Skin References for AIMBOUND" note): one ModuleScript per set,
-- children of this module, loaded in release order. A set brings everything of its own -- see "SKIN SETS" at the bottom
-- of SkinFX for the API (GunSkins, Build, Drive / World / OnFire / OnAnim / OnEvent / OnEquip, Muzzle, Tracer, Impact,
-- Kill, Banner, Sounds, Melee, Glove, Sleeve, Bar, BarDecor, Bundle, KillEffect, Hero, Art).
-- Sets must not require other game modules (SkinFX, GloveFX, BarStyles, MeleeData all require THIS) -- they get their
-- toolboxes passed in as arguments.
-- (Update 5 SKINS V3: only the V3 bundles of docs/SKINS_V3_PLAN.md, in release order. The 22 old sets -- Solaris ... Comet --
-- were removed; backup: git tag skins-v2-backup + archive/skins_v2/. Never reuse an old set kind or skin id.)
local ORDER = { "Ferroflux", "Infrared", "Tourbillon", "Bespoke", "Tactile", "Carapace", "Ironrune", "Fission", "Permafrost", "Slipstream", "Orbiter", "Nectar", "Silkfang", "Kintsugi", "Marquee", "Leadlight", "Geode", "Kirameki", "Torchbearer" }
-- HELD = built but not through the gate yet (SKINS_V3_BUILD.md): loaded in Studio only, so a publish never sells a
-- half-finished bundle. Take a kind out of HELD once it passes the gate.
local HELD = { Geode = true }
-- HELD_SKINS = ONE gun skin held back while the rest of its set sells (2026-10-29: the Fission AA-12 rebuilt on the new
-- AA-12 model waits for the owner's OK). Outside Studio the skin is taken out of its set's GunSkins (not listed, not
-- buyable, not equippable -- an owner's save keeps it and it comes back when it's released) and out of the bundle's
-- Contents (buying the bundle doesn't grant it). Studio keeps it so it can be tested. RELEASE: delete its line here.
local HELD_SKINS = {} -- (FissionAA12 released 2026-10-29: owner "fix whatever you need to", the v3 gate passed)
local IN_STUDIO = game:GetService("RunService"):IsStudio()

local SkinSets = { List = {} }
for _, name in ipairs(ORDER) do
    if HELD[name] and not IN_STUDIO then continue end
    local m = script:FindFirstChild(name) or script:WaitForChild(name, 5)
    if m then
        local ok, set = pcall(require, m)
        if ok and type(set) == "table" then
            set.Kind = set.Kind or name
            if not IN_STUDIO and type(set.GunSkins) == "table" then
                for i = #set.GunSkins, 1, -1 do
                    local id = set.GunSkins[i].Id
                    if HELD_SKINS[id] then
                        table.remove(set.GunSkins, i)
                        local b = set.Bundle
                        if b and type(b.Contents) == "table" then
                            local k = table.find(b.Contents, "WeaponSkin:" .. id)
                            if k then table.remove(b.Contents, k) end
                        end
                    end
                end
            end
            table.insert(SkinSets.List, set)
        else
            warn("[SkinSets] " .. name .. ": " .. tostring(set))
        end
    end
end
return SkinSets
