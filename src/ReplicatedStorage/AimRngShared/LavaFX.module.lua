--!nocheck
-- ============================================================================================
-- LAVA FX (UPDATE 4, owner: "The lava and such doesnt look as good as the other aspects"). Molten rock that reads as
-- real lava next to the scanned textures: self-lit image layers (SurfaceGuis / Beams with LightInfluence 0, so they
-- glow the same under every biome light) over the CrackedLava crust, instead of flat Neon slabs. Images:
-- tools/make_lava_art.py (art/lava, uploaded; ids below). Works on solo (client-built) AND party (server-built) floors:
--   * Beams scroll by themselves (TextureSpeed) on every client;
--   * pool layers turn on the client runner below, which follows the "LavaSpin" tag (tags replicate).
--   LavaFX.Pool(parent, cf, radius, opts)        a round molten pool: crust plates over a churning molten core + a halo
--   LavaFX.Flow(parent, p0, p1, width, opts)     a lava river ribbon lying on a surface (Beam, flows p0 -> p1)
--   LavaFX.Fall(parent, top, bottom, width, out, opts)  a lavafall (Beam facing `out`) + a splash pool at its foot
--   LavaFX.Glow(parent, pos, studs, color, t, opts)    a soft self-lit glow (BillboardGui) -- craters, vents
--   LavaFX.Panel(part, face, opts)               a self-lit molten face on a part (forge mouths, grates)
-- opts (all optional): Tint (Color3 multiplier, e.g. a mood's accent), Bright (SurfaceGui / Beam brightness),
--   Light (false = no PointLight; a number = its Range), Smoke / Sparks (false = none), Speed (flow scroll), Name.
-- Decoration only: nothing here collides, takes shots or touches. On Graphics Quality Low (QualityMode) the turning
-- layers stop and the emitters / second layers are tagged "QDetail" (QualityMode hides them).
-- ============================================================================================
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LavaFX = {}

LavaFX.IMG = {
    Molten = "rbxassetid://114091133140731", -- (image ids; decals pool_molten / pool_crust / flow / fall in tools/asset_ids.json)
    Crust = "rbxassetid://75057053784413",
    Flow = "rbxassetid://93565489806340",
    Fall = "rbxassetid://86020521987191",
    Glow = "rbxassetid://136808539004321", -- (the portals' soft_glow, tools/make_fx_art.py)
}
LavaFX.HOT = Color3.fromRGB(255, 118, 40) -- lava light / halo colour
LavaFX.SPIN_RANGE = 230 -- pools further than this from the camera don't turn

local function Tag(inst: Instance, tag: string) CollectionService:AddTag(inst, tag) end
local function Low(inst: Instance) Tag(inst, "QDetail") end -- (QualityMode: off on Graphics Quality Low)

local function Carrier(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
    local p = Instance.new("Part")
    p.Name = name; p.Size = size; p.CFrame = cf; p.Anchored = true; p.Transparency = 1
    p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
    p.Parent = parent
    return p
end

local function TintOf(opts: any): Color3
    return (opts and opts.Tint) or Color3.new(1, 1, 1)
end

local function PoolLight(p: BasePart, r: number, opts: any)
    if opts and opts.Light == false then return end
    local l = Instance.new("PointLight")
    l.Color = LavaFX.HOT:Lerp(TintOf(opts), 0.3)
    l.Range = (opts and type(opts.Light) == "number") and opts.Light or math.clamp(r * 2.6, 12, 32)
    l.Brightness = 1.4
    l.Shadows = false
    l.Parent = p
    return l
end

-- heat rising off the lava: a thin dark smoke + a few sparks popping out of the surface
local function Heat(p: BasePart, r: number, opts: any)
    if not (opts and opts.Smoke == false) then
        local e = Instance.new("ParticleEmitter")
        e.Name = "LavaHeat"
        e.Texture = "rbxasset://textures/particles/smoke_main.dds"
        e.Color = ColorSequence.new(Color3.fromRGB(150, 70, 40), Color3.fromRGB(40, 30, 28))
        e.LightEmission = 0.25; e.LightInfluence = 0.4
        e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, r * 0.35), NumberSequenceKeypoint.new(1, r * 1.1) })
        e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.82), NumberSequenceKeypoint.new(1, 1) })
        e.Lifetime = NumberRange.new(3, 5); e.Rate = math.clamp(r * 0.18, 0.6, 1.6)
        e.Speed = NumberRange.new(2, 4); e.SpreadAngle = Vector2.new(12, 12)
        e.Acceleration = Vector3.new(0.6, 1.2, 0); e.RotSpeed = NumberRange.new(-20, 20)
        e.EmissionDirection = Enum.NormalId.Top
        e.Shape = Enum.ParticleEmitterShape.Box
        e.Parent = p
        Low(e)
    end
    if not (opts and opts.Sparks == false) then
        local s = Instance.new("ParticleEmitter")
        s.Name = "LavaPops"
        s.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        s.Color = ColorSequence.new(Color3.fromRGB(255, 210, 120), Color3.fromRGB(255, 80, 20))
        s.LightEmission = 1; s.LightInfluence = 0
        s.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0) })
        s.Transparency = NumberSequence.new(0, 1)
        s.Lifetime = NumberRange.new(0.5, 1.2); s.Rate = math.clamp(r * 0.5, 1.5, 4)
        s.Speed = NumberRange.new(5, 11); s.SpreadAngle = Vector2.new(35, 35)
        s.Acceleration = Vector3.new(0, -26, 0)
        s.EmissionDirection = Enum.NormalId.Top
        s.Shape = Enum.ParticleEmitterShape.Box
        s.Parent = p
        Low(s)
    end
end

-- LavaFX.Pool: cf = the pool's centre ON the surface (its up = the surface normal); radius in studs
function LavaFX.Pool(parent: Instance, cf: CFrame, radius: number, opts: any?): Model
    opts = opts or {}
    local IMG = LavaFX.IMG
    local m = Instance.new("Model")
    m.Name = opts.Name or "LavaPool"
    local canvas = radius * 2 * 1.35 -- (the halo reaches past the crust edge)
    local p = Carrier(m, "LavaFace", Vector3.new(canvas, 0.05, canvas), cf * CFrame.new(0, 0.04, 0))
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Top
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = math.clamp(900 / canvas, 4, 40)
    sg.LightInfluence = 0
    sg.Brightness = opts.Bright or 1.7
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = p
    local tint = TintOf(opts)
    local function Layer(img: string, scale: number, col: Color3, t: number, z: number): ImageLabel
        local l = Instance.new("ImageLabel")
        l.Name = "Layer" .. z
        l.BackgroundTransparency = 1; l.AnchorPoint = Vector2.new(0.5, 0.5); l.Position = UDim2.fromScale(0.5, 0.5)
        l.Size = UDim2.fromScale(scale, scale); l.Image = img; l.ImageColor3 = col; l.ImageTransparency = t; l.ZIndex = z
        l.Rotation = math.random() * 360
        l.Parent = sg
        return l
    end
    local halo = Layer(IMG.Glow, 1, LavaFX.HOT:Lerp(Color3.fromRGB(255, 60, 20), 0.4), 0.55, 1)
    local molten = Layer(IMG.Molten, 0.97 / 1.35, Color3.new(1, 1, 1):Lerp(tint, 0.35), 0, 2)
    local crust = Layer(IMG.Crust, 1 / 1.35, Color3.new(1, 1, 1):Lerp(tint, 0.2), 0, 3)
    local _ = halo
    -- the core churns one way, the crust plates drift the other (client runner; slower on bigger pools)
    local rate = (opts.Spin or 7) * math.clamp(6 / radius, 0.35, 1.4)
    molten:SetAttribute("SpinRate", rate); Tag(molten, "LavaSpin")
    crust:SetAttribute("SpinRate", -rate * 0.28); Tag(crust, "LavaSpin")
    molten:SetAttribute("Pulse", 0.06) -- (the core breathes a little: brightness wobble)
    PoolLight(p, radius, opts)
    Heat(Carrier(m, "LavaHeatBox", Vector3.new(radius * 1.2, 0.2, radius * 1.2), cf * CFrame.new(0, 0.3, 0)), radius, opts)
    m.Parent = parent
    return m
end

-- a Beam lying on a surface from p0 to p1 (up = the surface normal; the ribbon's width runs across the flow)
local function Ribbon(parent: Instance, name: string, p0: Vector3, p1: Vector3, width: number, up: Vector3, img: string,
    tileLen: number, speed: number, bright: number, tint: Color3): (Part, Beam)
    local dir = (p1 - p0)
    local len = dir.Magnitude
    local fwd = dir.Unit
    local side = fwd:Cross(up).Unit
    local mid = (p0 + p1) / 2
    local holder = Carrier(parent, name, Vector3.new(0.2, 0.2, 0.2), CFrame.new(mid))
    -- (a FaceCamera-off Beam spreads its width along the attachments' secondary axis turned 90 deg about the beam:
    -- the attachments' Axis = the surface normal puts the ribbon flat on the surface)
    local function At(pos: Vector3): Attachment
        local a = Instance.new("Attachment")
        a.CFrame = holder.CFrame:ToObjectSpace(CFrame.fromMatrix(pos, up, side, fwd:Cross(up) * 0 + up:Cross(side)))
        a.Parent = holder
        return a
    end
    local a0, a1 = At(p0), At(p1)
    local b = Instance.new("Beam")
    b.Name = name .. "Beam"
    b.Attachment0, b.Attachment1 = a0, a1
    b.FaceCamera = false
    b.Width0, b.Width1 = width, width
    b.Segments = math.clamp(math.floor(len / 20), 1, 10)
    b.Texture = img
    b.TextureMode = Enum.TextureMode.Wrap
    b.TextureLength = tileLen
    b.TextureSpeed = speed
    b.LightInfluence = 0
    b.LightEmission = 0
    b.Brightness = bright
    b.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(tint, 0.3))
    b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(math.min(0.4, 3 / len), 0),
        NumberSequenceKeypoint.new(math.max(0.6, 1 - 3 / len), 0), NumberSequenceKeypoint.new(1, 0.6) })
    b.ZOffset = 0
    b.Parent = holder
    return holder, b
end

-- LavaFX.Flow: a river of lava on a surface; up defaults to world up
function LavaFX.Flow(parent: Instance, p0: Vector3, p1: Vector3, width: number, opts: any?): Model
    opts = opts or {}
    local m = Instance.new("Model")
    m.Name = opts.Name or "LavaFlow"
    local up = opts.Up or Vector3.yAxis
    local holder = Ribbon(m, "LavaRiver", p0 + up * 0.06, p1 + up * 0.06, width, up, LavaFX.IMG.Flow, width * 4,
        opts.Speed or 0.06, opts.Bright or 1.7, TintOf(opts))
    if opts.Light ~= false then PoolLight(holder, width * 1.2, opts) end
    if opts.Smoke ~= false or opts.Sparks ~= false then
        local len = (p1 - p0).Magnitude
        local box = Carrier(m, "LavaHeatBox", Vector3.new(width * 0.7, 0.2, len * 0.8), CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.new(0, 0.3, 0))
        Heat(box, math.min(width, 8), opts)
    end
    m.Parent = parent
    return m
end

-- LavaFX.Fall: a lavafall from `top` down to `bottom`, its face toward `out`; a splash pool at the foot on the ground
function LavaFX.Fall(parent: Instance, top: Vector3, bottom: Vector3, width: number, out: Vector3, opts: any?): Model
    opts = opts or {}
    local m = Instance.new("Model")
    m.Name = opts.Name or "LavaFall"
    local holder = Ribbon(m, "LavaCurtain", top + out * 0.08, bottom + out * 0.08, width, out, LavaFX.IMG.Fall, width * 2,
        opts.Speed or 0.9, opts.Bright or 1.9, TintOf(opts))
    local _ = holder
    local foot = bottom + out * (width * 0.55)
    local pool = LavaFX.Pool(m, CFrame.new(foot), width * 0.75, { Tint = opts.Tint, Light = opts.Light, Smoke = false, Sparks = opts.Sparks })
    local _2 = pool
    -- splash: sparks kicked up where it lands + steam
    local splash = Carrier(m, "LavaSplash", Vector3.new(width, 0.4, 1), CFrame.lookAt(bottom + out * 0.6 + Vector3.new(0, 0.4, 0), bottom + out * 2 + Vector3.new(0, 0.4, 0)))
    if opts.Sparks ~= false then
        local s = Instance.new("ParticleEmitter")
        s.Name = "FallSplash"
        s.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        s.Color = ColorSequence.new(Color3.fromRGB(255, 210, 110), Color3.fromRGB(255, 70, 20))
        s.LightEmission = 1; s.LightInfluence = 0
        s.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32), NumberSequenceKeypoint.new(1, 0) })
        s.Transparency = NumberSequence.new(0, 1)
        s.Lifetime = NumberRange.new(0.5, 1.1); s.Rate = 9
        s.Speed = NumberRange.new(7, 14); s.SpreadAngle = Vector2.new(50, 30)
        s.Acceleration = Vector3.new(0, -30, 0)
        s.EmissionDirection = Enum.NormalId.Front
        s.Parent = splash
        Low(s)
    end
    m.Parent = parent
    return m
end

-- LavaFX.Panel: a self-lit molten face on `face` of a part (a forge mouth, a furnace grate): the molten field cropped to
-- the face with crust flecks over it; the core breathes (runner Pulse)
function LavaFX.Panel(part: BasePart, face: Enum.NormalId, opts: any?): SurfaceGui
    opts = opts or {}
    local sg = Instance.new("SurfaceGui")
    sg.Name = "LavaPanel"
    sg.Face = face
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = opts.PPS or 60
    sg.LightInfluence = 0
    sg.Brightness = opts.Bright or 1.8
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = part
    local function Layer(img: string, z: number, t: number): ImageLabel
        local l = Instance.new("ImageLabel")
        l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1, 1); l.Image = img; l.ScaleType = Enum.ScaleType.Crop
        l.ImageColor3 = Color3.new(1, 1, 1):Lerp(TintOf(opts), 0.3); l.ImageTransparency = t; l.ZIndex = z
        l.Parent = sg
        return l
    end
    local core = Layer(LavaFX.IMG.Molten, 1, 0)
    Layer(LavaFX.IMG.Crust, 2, 0.15)
    core:SetAttribute("Pulse", 0.08); core:SetAttribute("SpinRate", 0); Tag(core, "LavaSpin")
    return sg
end

-- LavaFX.Glow: a soft self-lit glow of `studs` across at pos (always faces the camera)
function LavaFX.Glow(parent: Instance, pos: Vector3, studs: number, color: Color3, t: number?, opts: any?): BillboardGui
    opts = opts or {}
    local p = Carrier(parent, opts.Name or "LavaGlow", Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos))
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromScale(studs, studs)
    bb.LightInfluence = 0
    bb.Brightness = opts.Bright or 1.5
    bb.MaxDistance = opts.MaxDistance or 4000
    bb.ResetOnSpawn = false
    bb.Adornee = p
    bb.Parent = p
    local l = Instance.new("ImageLabel")
    l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1, 1)
    l.Image = LavaFX.IMG.Glow; l.ImageColor3 = color; l.ImageTransparency = t or 0.3
    l.Parent = bb
    if opts.Pulse then l:SetAttribute("Pulse", opts.Pulse); l:SetAttribute("SpinRate", 0); Tag(l, "LavaSpin") end
    return bb
end

-- ===== client runner: turns + breathes every "LavaSpin" label near the camera (one Heartbeat, ~30 Hz) =====
if RunService:IsClient() then
    task.defer(function()
        local QM
        pcall(function() QM = require(script.Parent:WaitForChild("QualityMode", 5)) end)
        local live: { [Instance]: { L: GuiObject, Rate: number, Pulse: number, T0: number, Base: number } } = {}
        local function Add(l: Instance)
            if not l:IsA("ImageLabel") then return end
            live[l] = { L = l, Rate = l:GetAttribute("SpinRate") or 0, Pulse = l:GetAttribute("Pulse") or 0, T0 = l.Rotation,
                Base = l.ImageTransparency }
        end
        for _, l in ipairs(CollectionService:GetTagged("LavaSpin")) do Add(l) end
        CollectionService:GetInstanceAddedSignal("LavaSpin"):Connect(Add)
        CollectionService:GetInstanceRemovedSignal("LavaSpin"):Connect(function(l) live[l] = nil end)
        local acc = 0
        RunService.Heartbeat:Connect(function(dt)
            acc += dt
            if acc < 1 / 30 then return end
            acc = 0
            if QM and QM.IsLow() then return end
            local cam = Workspace.CurrentCamera
            if not cam then return end
            local eye = cam.CFrame.Position
            local t = os.clock()
            for l, r in pairs(live) do
                local gui = l.Parent
                local part = gui and (gui:IsA("SurfaceGui") and gui.Parent or gui:IsA("BillboardGui") and gui.Adornee)
                if not part or not part:IsA("BasePart") then
                    if not l.Parent then live[l] = nil end
                elseif (part.Position - eye).Magnitude < LavaFX.SPIN_RANGE then
                    if r.Rate ~= 0 then l.Rotation = (r.T0 + t * r.Rate) % 360 end
                    if r.Pulse ~= 0 then
                        l.ImageTransparency = math.clamp(r.Base + r.Pulse * (math.sin(t * 1.3 + r.T0) + math.sin(t * 2.9 + r.T0 * 2) * 0.5), 0, 1)
                    end
                end
            end
        end)
    end)
end

return LavaFX
