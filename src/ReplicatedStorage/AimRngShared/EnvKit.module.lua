--!nocheck
-- ENVKIT (2026-10-05, hub + arenas overhaul; owner: "the hub and arenas ... come across as a bit low effort. They should
-- have OPTIMIZED effects"). Environment props and surfaces made in Studio EDIT (AI generate_mesh / generate_material)
-- and saved WITH THE PLACE -- they are not in git (tools/envkit.json lists them so the kit can be rebuilt):
--   ReplicatedStorage.EnvKit.<Set>.<Name>   a Model (MeshParts), pivot at its bottom centre, facing -Z
--   MaterialService.<Name>                  MaterialVariants (EnvKit.Mat)
-- Placing a prop: visuals never collide / take shots (CanCollide / CanQuery / CanTouch off, one draw each); its
-- gameplay shape is ONE invisible box hitbox (opts.Hitbox) -- cheap physics, shots stop on it, bots steer round it when
-- it's parented into a floor's StaticGeometry. A missing kit item falls back to a plain block, so nothing breaks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MaterialService = game:GetService("MaterialService")

local EnvKit = {}
local root = ReplicatedStorage:WaitForChild("EnvKit", 10)

function EnvKit.Get(set: string, name: string): Model?
    local f = root and root:FindFirstChild(set)
    local m = f and f:FindFirstChild(name)
    return (m and m:IsA("Model")) and m or nil
end
function EnvKit.Has(set: string, name: string): boolean
    return EnvKit.Get(set, name) ~= nil
end

-- size of a kit item at scale 1 (studs), or nil
function EnvKit.Size(set: string, name: string): Vector3?
    local m = EnvKit.Get(set, name)
    if not m then return nil end
    local _, s = m:GetBoundingBox()
    return s
end

-- opts: Scale (number), Parent, Name, Shadow (bool; default: only props taller than 8 studs cast shadows),
--   Hitbox = true (the bounding box) | Vector3 (size, centred on the prop) | false (none, default),
--   HitScale (shrink the auto box, default 0.9), HitParent (default Parent), Tint (Color3 multiplies textures),
--   Fallback = { Size = Vector3, Color = Color3, Material = Enum.Material } when the kit item is missing
-- cf = where its bottom centre goes. Returns (model or fallback part, hitbox?)
function EnvKit.Place(set: string, name: string, cf: CFrame, opts: any?): (Instance?, BasePart?)
    opts = opts or {}
    local template = EnvKit.Get(set, name)
    local inst: Instance
    local bbCF, bbSize
    if template then
        local m = template:Clone()
        if opts.Scale and opts.Scale ~= 1 then m:ScaleTo(opts.Scale) end
        -- (each kit model's FrontYaw attribute turns its front to face -Z of cf, whichever way the generator built it)
        m:PivotTo(cf * CFrame.Angles(0, math.rad(template:GetAttribute("FrontYaw") or 0), 0))
        bbCF, bbSize = m:GetBoundingBox()
        local shadow = opts.Shadow
        if shadow == nil then shadow = bbSize.Y > 8 end
        -- tint: the placement's Tint, else the kit model's own "Tint" attribute (its texture lives in a SurfaceAppearance,
        -- whose Color multiplies it -- a MeshPart's Color can't tint a plain TextureID)
        local tint = opts.Tint or template:GetAttribute("Tint")
        for _, p in ipairs(m:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Anchored = true
                p.CanCollide = false
                p.CanQuery = false
                p.CanTouch = false
                p.CastShadow = shadow
                if tint and p:IsA("MeshPart") then
                    local sa = p:FindFirstChildOfClass("SurfaceAppearance")
                    if sa then sa.Color = tint else p.Color = tint end
                end
            end
        end
        m.Name = opts.Name or name
        inst = m
    else
        local fb = opts.Fallback or {}
        local size = (fb.Size or Vector3.new(4, 4, 4)) * (opts.Scale or 1)
        local p = Instance.new("Part")
        p.Anchored = true
        p.Size = size
        p.CFrame = cf * CFrame.new(0, size.Y / 2, 0)
        p.Color = fb.Color or Color3.fromRGB(70, 66, 62)
        p.Material = fb.Material or Enum.Material.Slate
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.Name = opts.Name or name
        bbCF, bbSize = p.CFrame, p.Size
        inst = p
    end
    local hit: BasePart? = nil
    if opts.Hitbox then
        local size = typeof(opts.Hitbox) == "Vector3" and opts.Hitbox or bbSize * (opts.HitScale or 0.9)
        local h = Instance.new("Part")
        h.Name = "Hitbox"
        h.Anchored = true
        h.Transparency = 1
        h.CastShadow = false
        h.CanTouch = false
        h.Size = size
        h.CFrame = typeof(opts.Hitbox) == "Vector3" and (cf * CFrame.new(0, size.Y / 2, 0)) or bbCF
        h.Parent = opts.HitParent or opts.Parent
        hit = h
    end
    inst.Parent = opts.Parent
    return inst, hit
end

-- MaterialVariant by name (MaterialService); sets Material + MaterialVariant, or the fallback material if it's missing
function EnvKit.Mat(part: BasePart, variant: string, fallback: Enum.Material?)
    local v = MaterialService:FindFirstChild(variant)
    if v and v:IsA("MaterialVariant") then
        part.Material = v.BaseMaterial
        part.MaterialVariant = variant
    elseif fallback then
        part.Material = fallback
    end
end

return EnvKit
