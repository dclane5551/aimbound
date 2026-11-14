--!nocheck
-- ============================================================================================
-- HIDEOUT KIT (UPDATE 4, owner: hideouts must look "INSANE" -- "the aquarium hideout ... simply looks like little low
-- effort shapes floating around"). Real textured models for the hideout themes live IN THE PLACE under
-- ReplicatedStorage.HideoutKit.<Theme>.<Name> (Studio MCP generate_mesh -> stored there; NOT in git: the owner must
-- Ctrl+S after any kit change). HideoutData.BuildShell places them through this module; a missing item returns nil and
-- the theme falls back to its old primitive piece, so the game never breaks on an unsaved place.
--   HideoutKit.Place(parent, theme, name, cf, scale) -> a clone (anchored, no collision / query / shadow) or nil
--   HideoutKit.Creature(parent, theme, name, cf, scale, o) -> an invisible CARRIER part (the thing HideoutClient animates:
--       give it Anim attributes) with the model's mesh parts as its children (they ride along); o.Flap = { [partName] =
--       { axis, amp, rate, hinge? } } turns those parts into Hinge kids (tail fins, wings, flippers, lids), hinged where they
--       meet the body or at `hinge` (fractions of the part's own box: a lid's back edge = Vector3.new(0, -0.5, -0.5))
--   HideoutKit.Caustics(part, face, tile, t, speed) -> two scrolling caustic Textures (HideoutClient scrolls ScrollU / V)
--   HideoutKit.GodRay(parent, top, bottom, w0, w1, color, t) -> a soft light shaft (Beam, FaceCamera)
--   HideoutKit.Snow(part, o) / HideoutKit.Bubbles(part, o) -> particle presets (skipped on the low-quality setting)
--   HideoutKit.Leaves(part, o) / HideoutKit.Mist(part, o) -> drifting leaves / soft mist banks (skipped on low)
--   HideoutKit.Low() -> the low-quality setting (QualityMode, if it exists yet)
-- ============================================================================================
local HideoutKit = {}
local RS = game:GetService("ReplicatedStorage")

-- image ids (tools/hideout_textures.py -> tools/upload_asset.py decal -> InsertService:LoadAsset in Edit = the image id)
HideoutKit.TEX = {
    Caustics = "rbxassetid://109668347321930",
    GodRay = "rbxassetid://115976547304504",
    Snow = "rbxassetid://128556010872106",
    Bubble = "rbxassetid://109184633713512",
    Sand = "rbxassetid://89662274625162",
    Leaf = "rbxassetid://123096176986004",
    Mist = "rbxassetid://102614058157647",
}

local qm
function HideoutKit.Low(): boolean
    if qm == nil then
        local ok, m = pcall(function()
            local f = script.Parent:FindFirstChild("QualityMode")
            return f and require(f) or false
        end)
        qm = ok and m or false
    end
    if not qm then return false end
    local ok, low = pcall(qm.IsLow)
    return ok and low == true
end

function HideoutKit.Get(theme: string, name: string): Model?
    local kit = RS:FindFirstChild("HideoutKit")
    local set = kit and kit:FindFirstChild(theme)
    local m = set and set:FindFirstChild(name)
    return (m and m:IsA("Model")) and m or nil
end

local function Calm(m: Instance)
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") then
            p.Anchored = true
            p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
        end
    end
end

function HideoutKit.Place(parent: Instance, theme: string, name: string, cf: CFrame, scale: number?): Model?
    local src = HideoutKit.Get(theme, name)
    if not src then return nil end
    local m = src:Clone()
    Calm(m)
    if scale and scale ~= 1 then m:ScaleTo(m:GetScale() * scale) end
    m:PivotTo(cf * CFrame.Angles(0, math.rad(src:GetAttribute("Fwd") or 0), 0))
    m.Parent = parent
    return m
end

-- an animated creature: the carrier is invisible and faces the way it swims (-Z); the meshes hang off it
function HideoutKit.Creature(parent: Instance, theme: string, name: string, cf: CFrame, scale: number?, o: any?): BasePart?
    o = o or {}
    local m = HideoutKit.Place(parent, theme, name, cf, scale)
    if not m then return nil end
    local carrier = Instance.new("Part")
    carrier.Name = name
    carrier.Anchored = true
    carrier.CanCollide, carrier.CanQuery, carrier.CanTouch, carrier.CastShadow = false, false, false, false
    carrier.Transparency = 1
    carrier.Size = Vector3.new(0.2, 0.2, 0.2)
    carrier.CFrame = cf
    local body
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") and string.find(string.lower(p.Name), "body") then body = p end
    end
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") then
            local key = string.gsub(p.Name, "_geom$", "")
            local fl = o.Flap and o.Flap[key]
            if fl and (body or fl[4]) then
                -- the hinge: the point of this part's box nearest the body's centre, in the carrier's space -- or fl[4], a
                -- point given as fractions of the part's own box (a chest lid's back edge = Vector3.new(0, -0.5, -0.5))
                local near
                if fl[4] then
                    near = p.CFrame:PointToWorldSpace(p.Size * fl[4])
                else
                    local lp = p.CFrame:PointToObjectSpace(body.Position)
                    local h = p.Size / 2
                    near = p.CFrame:PointToWorldSpace(Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z)))
                end
                p:SetAttribute("Hinge", carrier.CFrame:PointToObjectSpace(near))
                p:SetAttribute("HingeAxis", fl[1]); p:SetAttribute("HingeAmp", fl[2]); p:SetAttribute("HingeRate", fl[3])
            end
            p.Parent = carrier
        end
    end
    m:Destroy()
    carrier.Parent = parent
    return carrier
end

function HideoutKit.Caustics(part: BasePart, face: Enum.NormalId, tile: number, t: number, speed: number?)
    local sp = speed or 1.2
    for k = 1, 2 do
        local tx = Instance.new("Texture")
        tx.Name = "Caustics"
        tx.Texture = HideoutKit.TEX.Caustics
        tx.Face = face
        tx.StudsPerTileU = tile * (k == 1 and 1 or 1.37)
        tx.StudsPerTileV = tile * (k == 1 and 1 or 1.37)
        tx.Transparency = t + (k == 1 and 0 or 0.12)
        tx.Color3 = Color3.fromRGB(210, 245, 255)
        tx:SetAttribute("ScrollU", (k == 1 and 1 or -0.6) * sp)
        tx:SetAttribute("ScrollV", (k == 1 and 0.45 or 0.8) * sp)
        tx.Parent = part
    end
end

function HideoutKit.GodRay(parent: Instance, top: Vector3, bottom: Vector3, w0: number, w1: number, color: Color3, t: number): Beam
    local holder = Instance.new("Part")
    holder.Name = "GodRay"
    holder.Anchored = true
    holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.CastShadow = false, false, false, false
    holder.Transparency = 1
    holder.Size = Vector3.new(0.2, 0.2, 0.2)
    holder.CFrame = CFrame.new(top)
    local a0 = Instance.new("Attachment"); a0.Parent = holder
    local a1 = Instance.new("Attachment"); a1.WorldPosition = bottom; a1.Parent = holder
    local b = Instance.new("Beam")
    b.Attachment0, b.Attachment1 = a0, a1
    b.Texture = HideoutKit.TEX.GodRay
    b.TextureMode = Enum.TextureMode.Stretch
    b.FaceCamera = true
    b.LightEmission = 1
    b.LightInfluence = 0
    b.Width0, b.Width1 = w0, w1
    b.Color = ColorSequence.new(color)
    b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, t), NumberSequenceKeypoint.new(0.7, t + (1 - t) * 0.4), NumberSequenceKeypoint.new(1, 1) })
    b.Segments = 1
    b.Parent = holder
    holder.Parent = parent
    return b
end

local function NS(a, b) return NumberSequence.new(a, b or a) end

function HideoutKit.Snow(part: BasePart, o: any?): ParticleEmitter?
    if HideoutKit.Low() then return nil end
    o = o or {}
    local e = Instance.new("ParticleEmitter")
    e.Name = "MarineSnow"
    e.Texture = HideoutKit.TEX.Snow
    e.Shape = Enum.ParticleEmitterShape.Box
    e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
    e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
    e.Rate = o.Rate or 30
    e.Lifetime = NumberRange.new(9, 14)
    e.Speed = NumberRange.new(0.1, 0.4)
    e.SpreadAngle = Vector2.new(180, 180)
    e.Acceleration = Vector3.new(0, -0.08, 0)
    e.Drag = 0.4
    e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.1, o.Size or 0.16), NumberSequenceKeypoint.new(0.9, o.Size or 0.16), NumberSequenceKeypoint.new(1, 0) })
    e.Transparency = NS(o.T or 0.35)
    e.Color = ColorSequence.new(o.Color or Color3.fromRGB(220, 240, 255))
    e.LightEmission = 0.5
    e.LightInfluence = 0.4
    e.Parent = part
    return e
end

function HideoutKit.Bubbles(part: BasePart, o: any?): ParticleEmitter?
    if HideoutKit.Low() then return nil end
    o = o or {}
    local e = Instance.new("ParticleEmitter")
    e.Name = "Bubbles"
    e.Texture = HideoutKit.TEX.Bubble
    e.Rate = o.Rate or 5
    e.Lifetime = NumberRange.new(o.Life or 6, (o.Life or 6) * 1.4)
    e.Speed = NumberRange.new(4, 7)
    e.SpreadAngle = Vector2.new(8, 8)
    e.EmissionDirection = Enum.NormalId.Top
    e.Acceleration = Vector3.new(0, 1.2, 0)
    e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(0.6, o.Size or 0.4), NumberSequenceKeypoint.new(1, (o.Size or 0.4) * 1.3) })
    e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.85, 0.35), NumberSequenceKeypoint.new(1, 1) })
    e.LightEmission = 0.3
    e.RotSpeed = NumberRange.new(-40, 40)
    e.Parent = part
    return e
end

function HideoutKit.Leaves(part: BasePart, o: any?): ParticleEmitter?
    if HideoutKit.Low() then return nil end
    o = o or {}
    local e = Instance.new("ParticleEmitter")
    e.Name = "Leaves"
    e.Texture = HideoutKit.TEX.Leaf
    e.Shape = Enum.ParticleEmitterShape.Box
    e.Rate = o.Rate or 4
    e.Lifetime = NumberRange.new(10, 16)
    e.Speed = NumberRange.new(0.2, 1)
    e.SpreadAngle = Vector2.new(180, 180)
    e.Acceleration = Vector3.new(0.4, -0.9, 0.2)
    e.Drag = 0.7
    e.Rotation = NumberRange.new(0, 360)
    e.RotSpeed = NumberRange.new(-120, 120)
    e.Size = NumberSequence.new(o.Size or 0.5)
    e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, 0), NumberSequenceKeypoint.new(0.9, 0), NumberSequenceKeypoint.new(1, 1) })
    e.Color = o.Color or ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(226, 146, 52)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(196, 86, 40)), ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 172, 62)) })
    e.LightInfluence = 1
    e.Parent = part
    return e
end

function HideoutKit.Mist(part: BasePart, o: any?): ParticleEmitter?
    if HideoutKit.Low() then return nil end
    o = o or {}
    local e = Instance.new("ParticleEmitter")
    e.Name = "Mist"
    e.Texture = HideoutKit.TEX.Mist
    e.Shape = Enum.ParticleEmitterShape.Box
    e.Rate = o.Rate or 3
    e.Lifetime = NumberRange.new(14, 20)
    e.Speed = NumberRange.new(0.5, 1.5)
    e.SpreadAngle = Vector2.new(180, 10)
    e.Rotation = NumberRange.new(0, 360)
    e.RotSpeed = NumberRange.new(-4, 4)
    e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, (o.Size or 30) * 0.6), NumberSequenceKeypoint.new(1, o.Size or 30) })
    e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, o.T or 0.7), NumberSequenceKeypoint.new(0.7, o.T or 0.7), NumberSequenceKeypoint.new(1, 1) })
    e.Color = ColorSequence.new(o.Color or Color3.fromRGB(236, 240, 228))
    e.LightInfluence = 0.6
    e.Parent = part
    return e
end

return HideoutKit
