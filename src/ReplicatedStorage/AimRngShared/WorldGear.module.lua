--!nocheck
-- Third-person gear -- what OTHER players see on you: the equipped gun, melee and gloves, built from exactly the same
-- model lookup (ViewmodelRig.ModelFor) and skin code (ViewmodelRig.SkinParts) as the first-person view, so a new
-- finish, a per-zone skin or a full model-replacing skin shows up here with no extra work.
-- Each piece is its own model on the character ("WorldGun" / "WorldMelee" / "WorldGloves"), kept apart from the
-- character creator's look ("AvatarLook"), so the two never overwrite each other. CombatServer places them.
local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local ViewmodelRig = require(Shared:WaitForChild("ViewmodelRig"))
local WeaponRigs = require(Shared:WaitForChild("WeaponRigs"))
local MeleeData = require(Shared:WaitForChild("MeleeData"))
local ItemData = require(Shared:WaitForChild("ItemData"))

local WorldGear = {}
-- Guns on bodies are drawn bigger than real-world size so they read on the chunky Rivals-style characters (a real
-- Glock is ~13% of a character's height and vanished against the leg). Grip / mount offsets scale with it.
WorldGear.GUN_SCALE = 1.45

-- Skin a freshly cloned weapon model and turn it into a loose prop welded to its Frame. -> model, frame (nil if unusable)
local function Prepare(model: Model, def: any, skin: any?): (Model?, BasePart?)
    local frame = model:FindFirstChild("Frame")
    if not (frame and frame:IsA("BasePart")) then model:Destroy() return nil, nil end
    local parts = {}
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            local pd = def.Parts and def.Parts[p.Name]
            table.insert(parts, {
                Part = p, Zone = (pd and pd.Zone) or p:GetAttribute("Zone") or "Frame", Original = p:FindFirstChildOfClass("SurfaceAppearance"),
                Factory = { Color = p.Color, Material = p.Material, Reflectance = p.Reflectance, Transparency = p.Transparency },
            })
        end
    end
    ViewmodelRig.SkinParts(parts, def, skin)
    for _, gp in ipairs(parts) do
        local p = gp.Part
        p.Anchored = false; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true; p.CastShadow = true
        if p ~= frame then
            -- explicit offsets (a WeldConstraint would lock in wherever the parts happen to be when it activates)
            local w = Instance.new("Weld")
            w.Part0 = frame; w.Part1 = p; w.C0 = frame.CFrame:ToObjectSpace(p.CFrame); w.Parent = p
        end
    end
    return model, frame
end

-- The gun model for a lineup gun in a weapon skin (ItemData.WeaponSkins entry). -> model, frame, def
function WorldGear.Gun(baseId: string, skin: any?, exotic: any?): (Model?, BasePart?, any?)
    local def = WeaponRigs.Guns[baseId]
    if not def then return nil end -- old asset-pack guns have no model
    local src = ViewmodelRig.ModelFor(def, skin, nil, exotic)
    if not src then return nil end
    if WorldGear.GUN_SCALE ~= 1 then src:ScaleTo(src:GetScale() * WorldGear.GUN_SCALE) end
    local model, frame = Prepare(src, def, skin)
    if model then model.Name = "WorldGun" end
    return model, frame, def
end

-- The melee model in a melee skin (MeleeData.Skins entry). -> model, frame, def
function WorldGear.Melee(meleeId: string?, skin: any?): (Model?, BasePart?, any?)
    local def = MeleeData.Rigs[(skin and skin.RigId and MeleeData.Rigs[skin.RigId]) and skin.RigId or MeleeData.RigIdFor(meleeId)] -- (model skins bring their own rig)
    local src = ViewmodelRig.ModelFor(def, skin)
    if not src then return nil end
    local model, frame = Prepare(src, def, skin)
    if model then model.Name = "WorldMelee" end
    return model, frame, def
end

-- Color + material of a glove cosmetic (ItemData.Gloves id) for the character's hands.
function WorldGear.GloveLook(gloveId: string?): (Color3, Enum.Material)
    local g = ItemData.Gloves[gloveId or "Tactical"] or ItemData.Gloves.Tactical
    local mat = g.Material
    if typeof(mat) ~= "EnumItem" then mat = Enum.Material.SmoothPlastic end
    return g.PrimaryColor or Color3.fromRGB(35, 38, 45), mat
end

return WorldGear
