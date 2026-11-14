--!nocheck
-- Live previews for the cosmetics window (client). Every card shows the real thing:
--   Avatar(look)            a blocky mannequin built from a look (AvatarData), pieces placed exactly like AvatarService
--                           does on the real character -- the card shows the piece ON your current outfit
--   Melee(meleeId, skinId)  the melee model in that skin (WorldGear / ViewmodelRig)
--   Viewport(parent, model, focus) a ViewportFrame that frames the model and slowly turns it; returns { Frame, Step, Destroy }
local Shared = script.Parent
local AvatarData = require(Shared:WaitForChild("AvatarData"))
local MeleeData = require(Shared:WaitForChild("MeleeData"))

local CosmeticPreview = {}

local function Part(model, name, size, cf, color, material, ball)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
    if ball then
        local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = p
    end
    p.Parent = model
    return p
end

-- R15-style block layout (feet at y = 0, front = -Z), close to the default blocky rig
local BODY = {
    LeftFoot = { Vector3.new(1, 0.3, 1), Vector3.new(-0.5, 0.15, 0) }, RightFoot = { Vector3.new(1, 0.3, 1), Vector3.new(0.5, 0.15, 0) },
    LeftLowerLeg = { Vector3.new(1, 0.85, 1), Vector3.new(-0.5, 0.725, 0) }, RightLowerLeg = { Vector3.new(1, 0.85, 1), Vector3.new(0.5, 0.725, 0) },
    LeftUpperLeg = { Vector3.new(1, 0.85, 1), Vector3.new(-0.5, 1.575, 0) }, RightUpperLeg = { Vector3.new(1, 0.85, 1), Vector3.new(0.5, 1.575, 0) },
    LowerTorso = { Vector3.new(2, 0.4, 1), Vector3.new(0, 2.2, 0) },
    UpperTorso = { Vector3.new(2, 1.6, 1), Vector3.new(0, 3.2, 0) },
    LeftUpperArm = { Vector3.new(1, 1.0, 1), Vector3.new(-1.5, 3.5, 0) }, RightUpperArm = { Vector3.new(1, 1.0, 1), Vector3.new(1.5, 3.5, 0) },
    LeftLowerArm = { Vector3.new(1, 0.9, 1), Vector3.new(-1.5, 2.55, 0) }, RightLowerArm = { Vector3.new(1, 0.9, 1), Vector3.new(1.5, 2.55, 0) },
    LeftHand = { Vector3.new(1, 0.3, 1), Vector3.new(-1.5, 1.95, 0) }, RightHand = { Vector3.new(1, 0.3, 1), Vector3.new(1.5, 1.95, 0) },
}
local SKIN_PARTS = { "LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm", "LeftUpperArm", "RightUpperArm" }
local PANTS_PARTS = { "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" }

function CosmeticPreview.Avatar(look)
    look = AvatarData.Normalize(look)
    local skin = AvatarData.Find("Skin", look.Skin)
    local headDef = AvatarData.Find("Head", look.Head)
    local face = AvatarData.Find("Face", look.Face)
    local hair = AvatarData.Find("Hair", look.Hair)
    local hairCol = AvatarData.Find("HairColor", look.HairColor).Color
    local shirt = AvatarData.Find("Shirt", look.Shirt).Color
    local pants = AvatarData.Find("Pants", look.Pants).Color
    local skinMat = skin.Material == "Metal" and Enum.Material.Metal or nil

    local model = Instance.new("Model")
    model.Name = "Mannequin"
    local parts = {}
    for name, d in pairs(BODY) do
        parts[name] = Part(model, name, d[1], CFrame.new(d[2]), shirt)
    end
    for _, n in ipairs(SKIN_PARTS) do parts[n].Color = skin.Color; parts[n].Material = skinMat or Enum.Material.SmoothPlastic end
    parts.UpperTorso.Color = shirt
    for _, n in ipairs(PANTS_PARTS) do parts[n].Color = pants end
    if look.Sleeves == "Short" or look.Sleeves == "Long" then parts.LeftUpperArm.Color = shirt; parts.RightUpperArm.Color = shirt end
    if look.Sleeves == "Long" then parts.LeftLowerArm.Color = shirt; parts.RightLowerArm.Color = shirt end

    -- head shell on the neck
    local box = headDef.Size or Vector3.new(1, 1, 1)
    local headCF = CFrame.new(0, 4.0 + box.Y / 2, 0)
    local shell = Part(model, "Head", box, headCF, skin.Color, skinMat, headDef.Sphere)
    if headDef.ClassicMesh then
        local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Head; m.Scale = Vector3.one; m.Parent = shell
    end
    local d = Instance.new("Decal")
    d.Face = Enum.NormalId.Front
    d.Texture = face.Texture
    d.Parent = shell
    parts.Head = shell

    local named = {
        Hair = hairCol, Skin = skin.Color, Shirt = shirt, Pants = pants,
        ShirtDark = shirt:Lerp(Color3.new(0, 0, 0), 0.35), PantsDark = pants:Lerp(Color3.new(0, 0, 0), 0.35),
        Trim = (AvatarData.Find("Trim", look.Trim) or AvatarData.Trim[1]).Color,
    }
    local function AddPieces(tag, pieces, defaultAttach, defaultColor)
        for i, pc in ipairs(pieces or {}) do
            local attach = parts[pc.Attach or defaultAttach]
            if attach then
                local unit = attach.Size
                local col = (typeof(pc.Color) == "Color3" and pc.Color) or named[pc.Color] or defaultColor
                local mat = pc.Material and Enum.Material[pc.Material] or nil
                local r = pc.R or Vector3.zero
                local cf = attach.CFrame * CFrame.new(pc.P * unit) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
                local p = Part(model, tag .. i, pc.S * unit, cf, col, mat, pc.Ball)
                if pc.Cyl then p.Shape = Enum.PartType.Cylinder end
                if pc.Transparency then p.Transparency = pc.Transparency end
            end
        end
    end
    local hidesHair = false
    for _, cat in ipairs(AvatarData.Categories) do
        if cat.Slot then
            local e = AvatarData.Find(cat.Id, look[cat.Id])
            if e and e.HidesHair then hidesHair = true end
        end
    end
    if not hidesHair then AddPieces("Hair", hair.Pieces, "Head", hairCol) end
    for _, cat in ipairs(AvatarData.Categories) do
        if cat.Slot then
            local e = AvatarData.Find(cat.Id, look[cat.Id])
            if e and e.Pieces then AddPieces(cat.Id, e.Pieces, cat.Attach, shirt) end
        end
    end
    model.PrimaryPart = parts.UpperTorso
    return model
end

-- the mannequin wearing armor pieces (ArmorFX defs): built anchored around its body parts and animated like the real
-- thing (halos spin, wings breathe) through CosmeticPreview.Animators. look = the outfit underneath (nil = default).
-- extras (a bundle's full set): { Glove = GloveFX def (on both hands), Guns = { { Gun = baseId, Skin = SkinFX skin } } (displayed
-- beside the figure, barrel down) }
function CosmeticPreview.Armor(defs, look, extras)
    local okA, ArmorFX = pcall(require, Shared:WaitForChild("ArmorFX"))
    local okS, SkinFX = pcall(require, Shared:WaitForChild("SkinFX"))
    if not (okA and okS) then return nil end
    local model = CosmeticPreview.Avatar(look or {})
    local body = {}
    for _, d in ipairs(model:GetChildren()) do if d:IsA("BasePart") then body[d.Name] = d end end
    local anim = {}
    for _, def in ipairs(defs) do
        for _, rec in ipairs(ArmorFX.Build(def, body, model, false)) do
            local a = rec.Body and SkinFX.AnimRecord(rec.Part, rec.Rest, rec.Part.Size)
            if a then table.insert(anim, { Part = rec.Part, Body = rec.Body, Rest = rec.Rest, Anim = a }) end
            for _, d in ipairs(rec.Part:GetChildren()) do -- (no drifting particles inside a card)
                if d:IsA("Attachment") then for _, pe in ipairs(d:GetChildren()) do if pe:IsA("ParticleEmitter") then pe.Rate = pe.Rate * 0.5 end end end
            end
        end
    end
    -- gloves on both hands (dressed like the first-person view, on the mannequin's hand blocks)
    local gloveDressed = {}
    local okG, GloveFX = pcall(require, Shared:WaitForChild("GloveFX"))
    if extras and extras.Glove and okG then
        for _, side in ipairs({ "LeftHand", "RightHand" }) do
            local hand = body[side]
            if hand then
                local okD, d = pcall(function()
                    GloveFX.ApplyBase(extras.Glove, hand, hand.Color, 1.04)
                    local dd = GloveFX.Dress(extras.Glove, hand, model, 0.8)
                    GloveFX.Place(dd, hand.CFrame, hand.Size, os.clock())
                    return dd
                end)
                if okD and d then table.insert(gloveDressed, { D = d, Hand = hand }) end
            end
        end
    end
    -- the set's guns, standing barrel-down at the figure's sides (first one right, second one left)
    local okW, WorldGear = pcall(require, Shared:WaitForChild("WorldGear"))
    for i, g in ipairs(extras and extras.Guns or {}) do
        if okW and i <= 2 then
            local okM, gm = pcall(function() return (WorldGear.Gun(g.Gun, g.Skin)) end)
            if okM and gm then
                for _, p in ipairs(gm:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end end
                local cf, size = gm:GetBoundingBox()
                local side = (i == 1) and 1 or -1
                -- (gun space: +X = barrel) -> barrel down, the grip facing the figure
                local want = CFrame.new(side * 2.9, 2.5, -0.2) * CFrame.Angles(0, (side == 1) and 0 or math.pi, math.rad(-90))
                gm:PivotTo(want * cf:ToObjectSpace(gm:GetPivot()))
                local k = 4.4 / math.max(size.X, size.Y, size.Z) -- about as tall as the figure's torso + legs
                if k < 1 then gm:ScaleTo(gm:GetScale() * k) end
                gm.Parent = model
            end
        end
    end
    if #anim > 0 or #gloveDressed > 0 then
        local st = { Open = 0, Spin = 1, Flash = 1, Halo = 0 }
        CosmeticPreview.Animators[model] = function(now)
            for _, e in ipairs(anim) do
                local off, tr = SkinFX.AnimOffset(e.Anim, now, st)
                e.Part.CFrame = e.Body.CFrame * off * e.Rest
                if tr then e.Part.Transparency = tr end
            end
            for _, g in ipairs(gloveDressed) do pcall(GloveFX.Place, g.D, g.Hand.CFrame, g.Hand.Size, now) end
        end
        model.Destroying:Connect(function() CosmeticPreview.Animators[model] = nil end)
    end
    return model
end

-- YOUR avatar as a preview figure (2026-10-02: players wear their own Roblox avatars): a still clone of your
-- character, turned to face the camera (front = -Z) with its feet at y = 0, about mannequin height. No scripts,
-- no world gear (the preview dresses its own), backbling put back. nil if you have no character yet.
function CosmeticPreview.PlayerFigure()
    local char = game:GetService("Players").LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (root and char:FindFirstChildOfClass("Humanoid")) then return nil end
    local was = char.Archivable
    char.Archivable = true
    local ok, model = pcall(function() return char:Clone() end)
    char.Archivable = was
    if not ok or not model then return nil end
    model.Name = "PlayerFigure"
    for _, n in ipairs({ "WorldGun", "WorldMelee", "WorldGloves", "WorldArmor", "AvatarLook" }) do
        local g = model:FindFirstChild(n)
        if g then g:Destroy() end
    end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("BillboardGui")
            or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
            d:Destroy()
        elseif d:IsA("BasePart") then
            d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false
        end
        if (d:IsA("BasePart") or d:IsA("Decal")) and d:GetAttribute("BBT") ~= nil then
            d.Transparency = d:GetAttribute("BBT") -- (a backbling the world gear hid behind the slung gun)
        end
    end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    end
    local mroot = model:FindFirstChild("HumanoidRootPart")
    if mroot then mroot.Transparency = 1 end
    model.PrimaryPart = mroot
    -- face -Z (yaw only), feet on y = 0, ~5.3 studs tall like the mannequin
    model:PivotTo(CFrame.new()) -- (the root's orientation -> identity: the figure faces -Z)
    local cf, size = model:GetBoundingBox()
    if size.Y > 0.5 and (size.Y > 6.5 or size.Y < 4.2) then
        pcall(function() model:ScaleTo(model:GetScale() * 5.3 / size.Y) end)
        cf, size = model:GetBoundingBox()
    end
    model:PivotTo(CFrame.new(0, -(cf.Position.Y - size.Y / 2), 0))
    return model
end

-- the hand / arm a glove or sleeve shell covers on a real rig (R6: the bottom 30% of each arm block = glove, the
-- rest = sleeve; R15: the hand / the two arm segments) -- the same fit as CombatServer's world gloves
local function FigureShells(model, kind)
    local out = {}
    local function Shell(limb, side, y0, y1, scale)
        local p = Instance.new("Part")
        p.Name = side .. kind .. "Shell"
        p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
        p.Size = Vector3.new(limb.Size.X * scale, limb.Size.Y * (y1 - y0) * (kind == "Glove" and 1.04 or 1), limb.Size.Z * scale)
        p.CFrame = limb.CFrame * CFrame.new(0, limb.Size.Y * (y0 + y1) / 2, 0)
        p.Color = limb.Color
        p.Material = Enum.Material.SmoothPlastic
        p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent = model
        table.insert(out, { Part = p, Side = side })
    end
    for _, side in ipairs({ "Left", "Right" }) do
        local sd = side == "Left" and "L" or "R"
        local arm = model:FindFirstChild(side .. " Arm")
        if arm then
            if kind == "Glove" then Shell(arm, sd, -0.5, -0.2, 1.08) else Shell(arm, sd, -0.2, 0.5, 1.05) end
        elseif kind == "Glove" then
            local hand = model:FindFirstChild(side .. "Hand")
            if hand then Shell(hand, sd, -0.5, 0.5, 1.08) end
        else
            for _, seg in ipairs({ "LowerArm", "UpperArm" }) do
                local limb = model:FindFirstChild(side .. seg)
                if limb then Shell(limb, sd, -0.5, 0.5, 1.05) end
            end
        end
    end
    return out
end

-- a bundle on YOUR avatar: its gloves + sleeves on your arms, its guns standing at your sides.
-- extras = { Glove = def?, Sleeve = def?, Guns = { { Gun, Skin } } }. Falls back to the mannequin without a character.
function CosmeticPreview.Bundle(extras, look)
    local model = CosmeticPreview.PlayerFigure()
    if not model then return CosmeticPreview.Armor({}, look, extras) end
    local okG, GloveFX = pcall(require, Shared:WaitForChild("GloveFX"))
    local dressed = {}
    if okG then
        for _, kind in ipairs({ "Sleeve", "Glove" }) do
            local def = extras and extras[kind]
            if def and def.Base then
                for _, sh in ipairs(FigureShells(model, kind)) do
                    local p = sh.Part
                    local okD, d = pcall(function()
                        local w = math.max(p.Size.X, p.Size.Z)
                        local dd = GloveFX.Dress(def, p, model, w * 1.1)
                        GloveFX.ApplyBase(def, p, nil, w)
                        return dd
                    end)
                    if okD and d then table.insert(dressed, { D = d, Part = p, Rot = GloveFX.WorldRot[sh.Side] }) end
                end
            end
        end
    end
    local okW, WorldGear = pcall(require, Shared:WaitForChild("WorldGear"))
    local _, figSize = model:GetBoundingBox()
    for i, g in ipairs(extras and extras.Guns or {}) do
        if okW and i <= 2 then
            local okM, gm = pcall(function() return (WorldGear.Gun(g.Gun, g.Skin)) end)
            if okM and gm then
                for _, p in ipairs(gm:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end end
                local cf, size = gm:GetBoundingBox()
                local side = (i == 1) and 1 or -1
                local want = CFrame.new(side * math.max(2.9, figSize.X / 2 + 1.3), 2.5, -0.2) * CFrame.Angles(0, (side == 1) and 0 or math.pi, math.rad(-90))
                gm:PivotTo(want * cf:ToObjectSpace(gm:GetPivot()))
                local k = 4.4 / math.max(size.X, size.Y, size.Z)
                if k < 1 then gm:ScaleTo(gm:GetScale() * k) end
                gm.Parent = model
            end
        end
    end
    if #dressed > 0 then
        CosmeticPreview.Animators[model] = function(now)
            for _, r in ipairs(dressed) do
                local s = r.Part.Size
                pcall(GloveFX.Place, r.D, r.Part.CFrame * r.Rot, Vector3.new(s.Z, s.X, s.Y), now)
            end
        end
        model.Destroying:Connect(function() CosmeticPreview.Animators[model] = nil end)
        CosmeticPreview.Animators[model](os.clock())
    end
    return model
end

-- a grapple look: the hook at the end of a sagging line of rope beads (beams don't draw in a ViewportFrame)
function CosmeticPreview.Grapple(def)
    if not def then return nil end
    local model = Instance.new("Model")
    model.Name = "GrapplePreview"
    local h = def.Hook or {}
    local sz = h.Size or 0.38
    local N = 22
    local a, b = Vector3.new(-2.6, 0.9, 0), Vector3.new(2.4, 0.6, 0)
    local function At(t) return a:Lerp(b, t) + Vector3.new(0, -math.sin(t * math.pi) * 0.7, 0) end
    for i = 0, N - 1 do
        local t0, t1 = i / N, (i + 1) / N
        local p0, p1 = At(t0), At(t1)
        local seg = Instance.new("Part")
        seg.Anchored = true; seg.CanCollide = false; seg.CastShadow = false
        seg.Material = Enum.Material.Neon
        seg.Size = Vector3.new((p1 - p0).Magnitude + 0.02, (def.Width or 0.09) * 1.4, (def.Width or 0.09) * 1.4)
        seg.CFrame = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, math.pi / 2, 0)
        seg.Color = def.Rainbow and Color3.fromHSV((t0 * 0.9) % 1, 0.75, 1) or def.Rope[1]:Lerp(def.Rope[2], t0)
        seg.Parent = model
    end
    local hook = Instance.new("Part")
    hook.Name = "Hook"
    hook.Anchored = true; hook.CanCollide = false; hook.CastShadow = false
    hook.Color = h.Color or Color3.new(1, 1, 1)
    hook.Material = h.Material or Enum.Material.Neon
    if h.Shape == "Block" then
        hook.Size = Vector3.new(sz, sz, sz) * 1.6
        hook.CFrame = CFrame.new(b) * CFrame.Angles(0.5, 0.6, 0.3)
    elseif h.Shape == "Ring" then
        hook.Shape = Enum.PartType.Cylinder
        hook.Size = Vector3.new(sz * 0.25, sz * 1.8, sz * 1.8)
        hook.CFrame = CFrame.new(b) * CFrame.Angles(0, 0.5, 0.4)
    else
        hook.Shape = Enum.PartType.Ball
        hook.Size = Vector3.new(sz, sz, sz) * 1.6
        hook.CFrame = CFrame.new(b)
    end
    hook.Parent = model
    -- a hand-end anchor (dark grip block) so the rope reads as coming from somewhere
    local grip = Instance.new("Part")
    grip.Anchored = true; grip.CanCollide = false; grip.CastShadow = false
    grip.Size = Vector3.new(0.6, 0.45, 0.45); grip.Color = Color3.fromRGB(40, 44, 56); grip.Material = Enum.Material.Metal
    grip.CFrame = CFrame.new(a - Vector3.new(0.3, 0, 0))
    grip.Parent = model
    return model
end

-- where to look on the mannequin for each slot: { centre, distance }
CosmeticPreview.Focus = {
    HeadGear = { Vector3.new(0, 4.55, 0), 6.0 },
    Top = { Vector3.new(0, 3.1, 0), 10.5 },
    Bottom = { Vector3.new(0, 1.4, 0), 10.0 },
    Skin = { Vector3.new(0, 2.6, 0), 14.0 },
    Armor_Head = { Vector3.new(0, 4.7, 0), 7.0 },
    Armor_Chest = { Vector3.new(0, 3.2, 0), 9.5 },
    Armor_Back = { Vector3.new(0, 3.6, 0), 12.0 },
    Armor_Legs = { Vector3.new(0, 1.6, 0), 9.5 },
    Armor_All = { Vector3.new(0, 3.0, 0), 15.0 },
    Armor_Set = { Vector3.new(0, 2.9, 0), 17.5 }, -- (armor + gloves + the guns at its sides)
}

function CosmeticPreview.Melee(meleeId, skinId)
    local okWG, WorldGear = pcall(require, Shared:WaitForChild("WorldGear"))
    if not okWG then return nil end
    local skin = MeleeData.Skins[skinId] or MeleeData.Skins.Factory
    local ok, model = pcall(function() return (WorldGear.Melee(meleeId, skin)) end)
    if not ok or not model then return nil end
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end
    end
    return model
end

-- a gun in a premium skin (SkinFX entry), drawn exactly as other players see it
function CosmeticPreview.Gun(gunId, skin)
    local okWG, WorldGear = pcall(require, Shared:WaitForChild("WorldGear"))
    if not okWG then return nil end
    local ok, model = pcall(function() return (WorldGear.Gun(gunId, skin)) end)
    if not ok or not model then return nil end
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end
    end
    return model
end

CosmeticPreview.Animators = {} -- model -> function(now): per-frame animation in a viewport (strong: weak Instance keys get lost)
CosmeticPreview.Dressed = {} -- arms model -> { { GloveFX dressing, owner part, size } } (ShopShowcase.Arms)

-- a glove (or sleeve) on a hand block, dressed like the first-person view
function CosmeticPreview.Glove(def, isSleeve)
    local okG, GloveFX = pcall(require, Shared:WaitForChild("GloveFX"))
    if not okG then return nil end
    local m = Instance.new("Model")
    local size = isSleeve and Vector3.new(1, 1, 2.6) or Vector3.new(1.04, 1.04, 0.54)
    local owner = Instance.new("Part")
    owner.Anchored = true
    owner.Size = size
    owner.CFrame = CFrame.Angles(math.rad(-25), math.rad(35), 0)
    owner.Color = isSleeve and Color3.fromRGB(40, 44, 54) or Color3.fromRGB(234, 184, 146)
    owner.Material = Enum.Material.SmoothPlastic
    owner.Parent = m
    local tex = GloveFX.ApplyBase(def, owner, owner.Color, 1.04)
    local d = GloveFX.Dress(def, owner, m, 1)
    d.BaseTex = tex
    GloveFX.Place(d, owner.CFrame, size, os.clock())
    -- live: wings flap, rings spin, shards orbit (Viewport.Step calls the model's animator)
    CosmeticPreview.Animators[m] = function(now) GloveFX.Place(d, owner.CFrame, size, now) end
    m.Destroying:Connect(function() CosmeticPreview.Animators[m] = nil end)
    if not isSleeve then
        -- a stub of sleeve behind the glove so it reads as a hand
        local arm = Instance.new("Part")
        -- (short + smooth: a long dark Fabric block read as a granite cube in the little previews and stole the focus)
        arm.Anchored = true; arm.Size = Vector3.new(0.86, 0.86, 0.9); arm.Color = Color3.fromRGB(70, 76, 92); arm.Material = Enum.Material.SmoothPlastic
        arm.CFrame = owner.CFrame * CFrame.new(0, 0, 0.75); arm.Parent = m
    end
    m.PrimaryPart = owner
    return m
end

-- ARMS (0.97): a forearm in its sleeve with the gloved hand at the end, both dressed like the first-person view
function CosmeticPreview.Arms(glove, sleeve)
    local okG, GloveFX = pcall(require, Shared:WaitForChild("GloveFX"))
    if not okG then return nil end
    local m = Instance.new("Model")
    local base = CFrame.Angles(math.rad(-20), math.rad(35), math.rad(8))
    local armSize, handSize = Vector3.new(1, 1, 2.4), Vector3.new(1.04, 1.04, 0.54)
    local arm = Instance.new("Part")
    arm.Anchored = true; arm.Size = armSize; arm.CFrame = base * CFrame.new(0, 0, 0.8)
    arm.Color = Color3.fromRGB(40, 44, 54); arm.Material = Enum.Material.SmoothPlastic; arm.Parent = m
    local hand = Instance.new("Part")
    hand.Anchored = true; hand.Size = handSize; hand.CFrame = base * CFrame.new(0, 0, -0.67)
    hand.Color = Color3.fromRGB(234, 184, 146); hand.Material = Enum.Material.SmoothPlastic; hand.Parent = m
    local dressed = {}
    if sleeve then
        local tex = GloveFX.ApplyBase(sleeve, arm, arm.Color, 1.04)
        local d = GloveFX.Dress(sleeve, arm, m, 1); d.BaseTex = tex
        GloveFX.Place(d, arm.CFrame, armSize, os.clock())
        table.insert(dressed, { d, arm, armSize })
    end
    if glove then
        local tex = GloveFX.ApplyBase(glove, hand, hand.Color, 1.04)
        local d = GloveFX.Dress(glove, hand, m, 1); d.BaseTex = tex
        GloveFX.Place(d, hand.CFrame, handSize, os.clock())
        table.insert(dressed, { d, hand, handSize })
    end
    CosmeticPreview.Animators[m] = function(now) for _, x in ipairs(dressed) do GloveFX.Place(x[1], x[2].CFrame, x[3], now) end end
    CosmeticPreview.Dressed[m] = dressed -- (Update 6 SHOP SHOWCASE: fires the glove's own Fire / Kill / Inspect events)
    m.Destroying:Connect(function() CosmeticPreview.Animators[m] = nil; CosmeticPreview.Dressed[m] = nil end)
    m.PrimaryPart = hand
    return m
end

-- a ViewportFrame showing a model, framed on focus = { centre, distance } (nil = fit the model); Step(now) turns it
function CosmeticPreview.Viewport(parent, model, focus, opts)
    opts = opts or {}
    local vf = Instance.new("ViewportFrame")
    vf.BackgroundTransparency = 1
    vf.Size = UDim2.fromScale(1, 1)
    vf.Ambient = opts.Fit and Color3.fromRGB(200, 200, 212) or Color3.fromRGB(170, 170, 185)
    vf.LightColor = Color3.fromRGB(255, 250, 240)
    vf.LightDirection = Vector3.new(-0.6, -1, -0.8)
    vf.ZIndex = opts.ZIndex or 2
    vf.Parent = parent
    local cam = Instance.new("Camera")
    cam.FieldOfView = 30
    cam.Parent = vf
    vf.CurrentCamera = cam
    model.Parent = vf
    local centre, dist
    if focus then
        centre, dist = focus[1], focus[2]
    else
        local cf, size = model:GetBoundingBox()
        centre = cf.Position
        dist = math.max(size.X, size.Y, size.Z) * 2.1 + 0.5
    end
    -- STORE ICONS v2 (0.97, owner: "Icons look horrific right now for all shop items, make them look professional"): a card
    -- (opts.Fit = fill share) frames the VISIBLE parts (invisible skin decorations used to stretch the box and shrink the
    -- item) so they fill the card at a fixed three-quarter angle with a slight sway -- no full spins catching guns end-on
    local bmin, bmax
    if opts.Fit then
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") and d.Transparency < 0.95 then
                local hs = d.Size / 2
                for _, sx in ipairs({ -1, 1 }) do for _, sy in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
                    local w = d.CFrame:PointToWorldSpace(Vector3.new(hs.X * sx, hs.Y * sy, hs.Z * sz))
                    bmin = bmin and bmin:Min(w) or w
                    bmax = bmax and bmax:Max(w) or w
                end end end
            end
        end
        if bmin then centre = (bmin + bmax) / 2 end
    end
    local function FitDist(a: number): number
        if not bmin then return dist end
        local sz = bmax - bmin
        local w = math.abs(sz.X * math.cos(a)) + math.abs(sz.Z * math.sin(a))
        local h = sz.Y + 0.25 * math.abs(sz.Z * math.cos(a) + sz.X * math.sin(a)) * 0.18
        local abs = vf.AbsoluteSize
        local aspect = (abs.Y > 1) and (abs.X / abs.Y) or 1.3
        local tv = math.tan(math.rad(cam.FieldOfView / 2))
        local th = tv * aspect
        local fill = (type(opts.Fit) == "number") and opts.Fit or 0.84
        return math.max(w / 2 / (th * fill), h / 2 / (tv * fill)) + math.max(sz.X, sz.Z) * 0.25
    end
    local spin = opts.Spin -- "full" (melee) or nil (a gentle sway so the front stays in view)
    local seed = math.random() * 10
    local self = { Frame = vf, Yaw = opts.Yaw or 0, Zoom = 1 }
    -- drag to turn it (big previews): the drag adds to the slow automatic turn
    if opts.Drag then
        local UIS = game:GetService("UserInputService")
        local dragging, last = false, nil
        vf.Active = true
        vf.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; last = i.Position end
        end)
        vf.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
        local conn = UIS.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) and last then
                self.Yaw += (i.Position.X - last.X) * 0.012
                last = i.Position
            elseif i.UserInputType == Enum.UserInputType.MouseWheel and vf.Parent and vf.GuiState == Enum.GuiState.Hover then
                self.Zoom = math.clamp(self.Zoom - i.Position.Z * 0.08, 0.55, 1.6)
            end
        end)
        vf.Destroying:Connect(function() conn:Disconnect() end)
    end
    function self.Step(now)
        local a
        if opts.Fit then
            a = (opts.BaseYaw or 0.42) + math.sin(now * 0.6 + seed) * (opts.Sway or 0.16) + self.Yaw
        else
            a = (spin == "full" and (now * 0.8 + seed) or (math.sin(now * 0.7 + seed) * 0.6)) + self.Yaw
        end
        local dist = (opts.Fit and FitDist(a) or dist) * self.Zoom
        local pos = centre + Vector3.new(math.sin(a) * dist, dist * 0.18, -math.cos(a) * dist)
        cam.CFrame = CFrame.lookAt(pos, centre)
        local anim = CosmeticPreview.Animators[model]
        if anim then pcall(anim, now) end
    end
    function self.Destroy() CosmeticPreview.Animators[model] = nil; vf:Destroy() end
    self.Step(os.clock())
    return self
end

return CosmeticPreview
