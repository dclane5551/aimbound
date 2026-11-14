--!nocheck
-- WORLD KIT (0.87): the part helpers every world module (AimRngShared.Worlds.*) builds its pieces with. Same rules as
-- NewBiomes: decoration never collides or blocks shots (P), cover is Solid (blocks shots, bots steer round it), lights
-- only where a world asks for one (<= ~5 a floor), animations only on the client (Live).
local RunService = game:GetService("RunService")
local IS_CLIENT = RunService:IsClient()

local K = {}
K.C3 = Color3.fromRGB
K.M = Enum.Material
K.IS_CLIENT = IS_CLIENT

-- BALL GOTCHA (seen in play 0.87, same as the 0.54 skins): a Ball part is a sphere of its SMALLEST size -- a 14 x 14 x
-- 50 airship envelope was a 14-stud ball and its fins floated off it. A non-uniform Ball becomes a Block with a Sphere
-- SpecialMesh = a true ellipsoid of its size.
function K.FixBall(p: BasePart): BasePart
    if p:IsA("Part") and (p :: Part).Shape == Enum.PartType.Ball then
        local z = p.Size
        if math.abs(z.X - z.Y) > 0.01 or math.abs(z.Y - z.Z) > 0.01 then
            (p :: Part).Shape = Enum.PartType.Block
            local m = Instance.new("SpecialMesh")
            m.MeshType = Enum.MeshType.Sphere
            m.Parent = p
        end
    end
    return p
end

function K.P(parent: Instance, props: any): BasePart
    local cls = props.Class or "Part"
    props.Class = nil
    local p = Instance.new(cls)
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
    for k, v in pairs(props) do p[k] = v end
    -- (a WORLD PIECE: MapShell.Terrainify leaves it alone -- it hid every Neon part and turned solid pieces into map
    -- stone / terrain rock, so idol eyes, gills, lantern glass and pearls vanished on solo maps)
    p:SetAttribute("WP", true)
    K.FixBall(p)
    p.Parent = parent
    return p
end
-- cover: blocks shots, bots steer round it
function K.Solid(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, shape: Enum.PartType?): BasePart
    local p = K.P(parent, { Size = size, CFrame = cf, Color = color, Material = mat })
    p.CanCollide = true; p.CanQuery = true
    if shape then p.Shape = shape; K.FixBall(p) end
    return p
end
-- decoration only
function K.Deco(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, shape: Enum.PartType?, transp: number?): BasePart
    local p = K.P(parent, { Size = size, CFrame = cf, Color = color, Material = mat, Transparency = transp or 0 })
    if shape then p.Shape = shape; K.FixBall(p) end
    return p
end
function K.Wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, solid: boolean?): BasePart
    local p = K.P(parent, { Class = "WedgePart", Size = size, CFrame = cf, Color = color, Material = mat })
    if solid then p.CanCollide = true; p.CanQuery = true end
    return p
end
function K.Neon(parent: Instance, size: Vector3, cf: CFrame, color: Color3, transp: number?, shape: Enum.PartType?): BasePart
    local p = K.P(parent, { Size = size, CFrame = cf, Color = color, Material = Enum.Material.Neon, Transparency = transp or 0 })
    if shape then p.Shape = shape; K.FixBall(p) end
    return p
end
-- a cylinder standing up (Roblox cylinders lie along X)
function K.Up(cf: CFrame): CFrame return cf * CFrame.Angles(0, 0, math.rad(90)) end
function K.Pillar(parent: Instance, dia: number, h: number, cf: CFrame, color: Color3, mat: Enum.Material, solid: boolean?): BasePart
    local p = K.P(parent, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, dia, dia), CFrame = K.Up(cf * CFrame.new(0, h / 2, 0)), Color = color, Material = mat })
    if solid then p.CanCollide = true; p.CanQuery = true end
    return p
end
-- a part stretched between two points (cables, branches, struts)
function K.Beam(parent: Instance, a: Vector3, b: Vector3, thick: number, color: Color3, mat: Enum.Material, round: boolean?): BasePart
    local len = (b - a).Magnitude
    if round then
        return K.P(parent, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, thick, thick), CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), Color = color, Material = mat })
    end
    return K.P(parent, { Size = Vector3.new(thick, thick, len), CFrame = CFrame.lookAt((a + b) / 2, b), Color = color, Material = mat })
end
function K.Yaw(rng: Random): CFrame return CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) end
function K.Light(part: BasePart, color: Color3, range: number, brightness: number?)
    local l = Instance.new("PointLight"); l.Color = color; l.Range = range; l.Brightness = brightness or 1.4; l.Shadows = false; l.Parent = part
    return l
end
-- a client-only animation loop that ends with the room
function K.Live(fx: Instance, fn: (number, number) -> ())
    if not IS_CLIENT then return end
    local t0 = os.clock()
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if not fx.Parent then conn:Disconnect() return end
        if not fx:IsDescendantOf(workspace) then return end -- (optimization pass 2026-10-27: a parked room's loop rests; fn gets the elapsed time, so it resumes in step)
        fn(os.clock() - t0, dt)
    end)
end
-- a particle emitter with sane defaults (props override)
function K.Emit(parent: Instance, props: any): ParticleEmitter
    local e = Instance.new("ParticleEmitter")
    e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    e.LightInfluence = 0.4
    for k, v in pairs(props) do e[k] = v end
    e.Parent = parent
    return e
end
-- an invisible box an emitter lives in
function K.Box(parent: Instance, size: Vector3, cf: CFrame): BasePart
    return K.P(parent, { Size = size, CFrame = cf, Transparency = 1 })
end
-- turn every part of a model into pure decoration
function K.NoCollide(m: Instance)
    for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide = false; d.CanQuery = false end end
end
-- a model wrapper (scenery floaters, hero pieces)
function K.Model(parent: Instance, name: string): Model
    local m = Instance.new("Model"); m.Name = name; m.Parent = parent
    return m
end
-- ==================== REAL MESHES (UPDATE 4 WORLDS) ====================
-- ReplicatedStorage.WorldMeshes holds scanned CC0 props (tools/world_mesh_*.py: Poly Haven rocks / cliffs / logs),
-- each a MeshPart template whose LONGEST side is 1 stud (attribute Unit) with a SurfaceAppearance whose colour map is
-- neutral grey -- so a world tints it its own colour (SurfaceAppearance.Color). The templates live in the PLACE (owner
-- Ctrl+S): when one is missing (an unsaved place) K.Mesh returns nil and the caller keeps its old primitive build.
local MESHES = nil
local function MeshFolder()
    if MESHES and MESHES.Parent then return MESHES end
    MESHES = game:GetService("ReplicatedStorage"):FindFirstChild("WorldMeshes")
    return MESHES
end
function K.HasMesh(name: string): boolean
    local f = MeshFolder()
    return f ~= nil and f:FindFirstChild(name) ~= nil
end
-- K.Mesh(parent, name, cf, size, color, opts) -> MeshPart?
--   cf    = the BOTTOM CENTRE on the ground (the mesh's origin), rotation included
--   size  = a number (the longest side in studs, proportions kept) or a Vector3 (stretched to exactly that)
--   color = the tint (Color3; nil = white)
--   opts  = { Solid = true (collides + blocks shots: cover), Sink = studs pushed into the ground (hides the cut base),
--             Shadow = false, Name }
function K.Mesh(parent: Instance, name: string, cf: CFrame, size: any, color: Color3?, opts: any?): BasePart?
    local f = MeshFolder()
    local t = f and f:FindFirstChild(name)
    if not t then return nil end
    opts = opts or {}
    local p = t:Clone()
    local unit = t:GetAttribute("Unit") or t.Size
    local sz = (typeof(size) == "Vector3") and size or unit * (size or 1)
    p.Size = sz
    p.CFrame = cf * CFrame.new(0, sz.Y / 2 - (opts.Sink or 0), 0)
    p.Anchored, p.CanTouch = true, false
    p.CanCollide = opts.Solid == true
    p.CanQuery = opts.Solid == true
    p.CastShadow = opts.Shadow ~= false
    if opts.Name then p.Name = opts.Name end
    local sa = p:FindFirstChildOfClass("SurfaceAppearance")
    if sa and color then sa.Color = color end
    p:SetAttribute("WP", true) -- (a world piece: MapShell.Terrainify leaves it alone)
    p.Parent = parent
    return p
end
-- a cover rock: the mesh when it exists, else the caller's fallback builder
function K.MeshOr(parent: Instance, name: string, cf: CFrame, size: any, color: Color3?, opts: any?, fallback: (() -> ())?): BasePart?
    local p = K.Mesh(parent, name, cf, size, color, opts)
    if not p and fallback then fallback() end
    return p
end
-- ==================== WORLD PROPS (UPDATE 4 WORLDS prop pass) ====================
-- Real textured models for the worlds' props live IN THE PLACE under ReplicatedStorage.WorldProps.<World>.<Name>
-- (Studio MCP generate_mesh -> normalised so scale 1 = the old part-built piece's size at s = 1, pivot at the bottom
-- centre facing -Z; NOT in git: the owner must Ctrl+S after any change). Each prop builder calls K.Prop first and
-- keeps its old primitive build as the fallback, so an unsaved place never breaks a floor.
--   K.Prop(parent, world, name, cf, s, hit) -> true when placed
--     cf  = the bottom centre on the floor (rotation included), s = the builder's scale
--     hit = the gameplay box at s = 1 (Vector3; nil = pure decoration): ONE invisible Solid box (blocks shots, bots
--           steer round it, CanCollide) -- the visual mesh never collides, so cover plays exactly like the old blocks;
--           or a list of { size, centre } boxes (cf space, s = 1) for shapes one box can't stand in for (stairs)
local PROPS = nil
local function PropFolder()
    if PROPS and PROPS.Parent then return PROPS end
    PROPS = game:GetService("ReplicatedStorage"):FindFirstChild("WorldProps")
    return PROPS
end
function K.HasProp(world: string, name: string): boolean
    local f = PropFolder()
    local w = f and f:FindFirstChild(world)
    return w ~= nil and w:FindFirstChild(name) ~= nil
end
-- SOLO open maps: the terrain surface renders ~2 studs over the floor the props are placed on (measured on Bayou:
-- floor 2.0, terrain 3.95), which buried low props (a dock showed only its lantern post). The terrain is filled in
-- AFTER the props are built, so a client-built floor re-checks each prop a moment later and lifts it (and its gameplay
-- boxes) onto terrain found up to 4.5 studs above its spot. Party floors have no terrain.
local TERRAIN_ONLY = RaycastParams.new()
TERRAIN_ONLY.FilterType = Enum.RaycastFilterType.Include
TERRAIN_ONLY.FilterDescendantsInstances = { workspace.Terrain }
local function TerrainLift(p: Vector3): number
    local r = workspace:Raycast(p + Vector3.new(0, 4.5, 0), Vector3.new(0, -4.6, 0), TERRAIN_ONLY)
    if r and r.Position.Y > p.Y + 0.2 then return r.Position.Y - p.Y - 0.15 end
    return 0
end
function K.LiftLater(items: { Instance }, at: Vector3)
    if not IS_CLIENT then return end
    task.spawn(function()
        for _, t in ipairs({ 0.4, 1.2, 3 }) do
            task.wait(t)
            local lead = items[1]
            if not (lead and lead.Parent) then return end
            if lead:GetAttribute("OnSurface") then return end -- (UPDATE 4 wrap-up: MapShell.OnSurface already stood it on the hill)
            local up = TerrainLift(at)
            if up > 0 then
                for _, it in ipairs(items) do
                    if it:IsA("Model") then it:PivotTo(it:GetPivot() + Vector3.new(0, up, 0))
                    elseif it:IsA("BasePart") then it.CFrame += Vector3.new(0, up, 0) end
                end
                return
            end
        end
    end)
end
function K.Prop(parent: Instance, world: string, name: string, cf: CFrame, s: number?, hit: any?): boolean
    local f = PropFolder()
    local w = f and f:FindFirstChild(world)
    local t = w and w:FindFirstChild(name)
    if not t then return false end
    s = s or 1
    local m = t:Clone()
    if math.abs(s - 1) > 0.001 then m:ScaleTo(m:GetScale() * s) end
    m:PivotTo(cf)
    local big = (t:GetAttribute("Height") or 6) * s > 8
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") then
            p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
            p.CastShadow = big
            p:SetAttribute("WP", true) -- (a world piece: MapShell.Terrainify leaves it alone)
        end
    end
    m:SetAttribute("WP", true)
    m.Parent = parent
    local items = { m }
    local boxes = (typeof(hit) == "Vector3") and { { hit, Vector3.new(0, hit.Y / 2, 0) } } or hit
    for _, b in ipairs(boxes or {}) do
        local h = K.P(parent, { Name = name .. "Hit", Size = b[1] * s, CFrame = cf * CFrame.new(b[2] * s), Transparency = 1 })
        h.CanCollide = true; h.CanQuery = true
        table.insert(items, h)
    end
    K.LiftLater(items, cf.Position)
    return true, m
end
-- K.Far(parent, world, name, cf, s, tint) -> Model? : a far horizon copy of a world prop (VistaFn / heroes): no boxes,
-- no shadow, no terrain lift; tint (optional) multiplies its SurfaceAppearance (fade a far copy toward the haze).
-- MapShell.QualityTag hides MapShell pieces past the arena + VISTA_KEEP on Low, these included.
function K.Far(parent: Instance, world: string, name: string, cf: CFrame, s: number?, tint: Color3?): Model?
    local f = PropFolder()
    local w = f and f:FindFirstChild(world)
    local t = w and w:FindFirstChild(name)
    if not t then return nil end
    local m = t:Clone()
    if s and math.abs(s - 1) > 0.001 then m:ScaleTo(m:GetScale() * s) end
    m:PivotTo(cf)
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") then
            p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
            if tint then
                local sa = p:FindFirstChildOfClass("SurfaceAppearance")
                if sa then sa.Color = tint end
            end
        end
    end
    m.Name = "Far" .. name
    m.Parent = parent
    return m
end
-- K.Life(parent, world, name, s) -> Model?, BasePart?, Vector3? : a world prop as a moving LIFE piece (scenery animals,
-- lanterns, gears): no collision / query / shadow, pivot at its middle (it turns about its centre). Also returns its
-- biggest part + that part's size: creatures are one mesh, so a wing flap / jelly pulse = scaling that part per axis.
-- tint (optional) multiplies its SurfaceAppearance like K.Far.
function K.Life(parent: Instance, world: string, name: string, s: number?, tint: Color3?): (Model?, BasePart?, Vector3?)
    local m = K.Far(parent, world, name, CFrame.new(0, -400, 0), s, tint)
    if not m then return nil end
    m.Name = "Life" .. name
    m.WorldPivot = CFrame.new((m:GetBoundingBox()).Position)
    local big, vol = nil, -1
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") and p.Size.X * p.Size.Y * p.Size.Z > vol then big, vol = p, p.Size.X * p.Size.Y * p.Size.Z end
    end
    return m, big, big and big.Size
end
-- gameplay boxes alone (a prop made of several models): boxes = { { size, centre } } in cf space at s = 1
function K.Hit(parent: Instance, cf: CFrame, s: number, boxes: any)
    local items = {}
    for _, b in ipairs(boxes) do
        local h = K.P(parent, { Name = "PropHit", Size = b[1] * s, CFrame = cf * CFrame.new(b[2] * s), Transparency = 1 })
        h.CanCollide = true; h.CanQuery = true
        table.insert(items, h)
    end
    K.LiftLater(items, cf.Position)
end
-- a scanned rock from a list, picked from the spot (same spot = same rock, no rng needed), longest side `size`
function K.ScanRock(parent: Instance, list: { string }, cf: CFrame, size: number, color: Color3?, opts: any?): BasePart?
    local p = cf.Position
    local name = list[(math.floor(math.abs(p.X * 7.3 + p.Z * 13.1)) % #list) + 1]
    return K.Mesh(parent, name, cf, size, color, opts)
end
K.MOSS_ROCKS = { "MossRock1", "MossRock2", "MossRock3", "MossRock4", "MossRock5", "MossRock6" }
-- ==================== WORLD TEXTURES (tools/world_textures.py -> upload -> image ids) ====================
K.TEX = {
    Falls = "rbxassetid://77118024812069", -- streaky white water on transparent, seamless top to bottom (Beam)
    Foam = "rbxassetid://85381141629190", -- a soft churning puff (splash particles)
    Solar = "rbxassetid://121260583022296", -- a solar-panel tile, 4 x 6 square cells (Station arrays: a Texture, V = 1.5 U)
}
-- K.Falls(parent, top, bottom, width, opts) -> a waterfall of camera-facing textured Beams scrolling down (three
-- layers at different speeds = churning water) + a foam splash at the foot. opts = { Color, Layers (default 3),
-- Foam (false = none), Rate }. Cheap: 2 invisible anchor parts, <= 3 beams, 1 emitter (thinned on Low).
function K.Falls(parent: Instance, top: Vector3, bottom: Vector3, width: number, opts: any?): BasePart
    opts = opts or {}
    local col = opts.Color or Color3.fromRGB(214, 236, 244)
    local a = K.Box(parent, Vector3.new(1, 1, 1), CFrame.new(top))
    local b = K.Box(parent, Vector3.new(1, 1, 1), CFrame.new(bottom))
    a.Name, b.Name = "FallsTop", "FallsFoot"
    local a0 = Instance.new("Attachment"); a0.Parent = a
    local a1 = Instance.new("Attachment"); a1.Parent = b
    local layers = { { 1, 0.15, 0.55 }, { 0.72, 0.35, 0.8 }, { 0.48, 0.5, 1.15 } }
    for i = 1, (opts.Layers or 3) do
        local L = layers[i]
        local beam = Instance.new("Beam")
        beam.Attachment0, beam.Attachment1 = a0, a1
        beam.Texture = K.TEX.Falls
        beam.TextureMode = Enum.TextureMode.Wrap
        beam.TextureLength = 70 + i * 18
        beam.TextureSpeed = L[3]
        beam.Width0, beam.Width1 = width * L[1], width * L[1] * 1.25
        beam.FaceCamera = true
        beam.Segments = 1
        beam.LightEmission = 0.25
        beam.LightInfluence = 0.65
        beam.Color = ColorSequence.new(col)
        beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 + L[2] * 0.4), NumberSequenceKeypoint.new(0.08, L[2]),
            NumberSequenceKeypoint.new(0.9, L[2]), NumberSequenceKeypoint.new(1, 0.5 + L[2] * 0.5) })
        beam.Parent = a
    end
    if opts.Foam ~= false then
        local foot = K.Box(parent, Vector3.new(width * 1.4, 2, width * 0.6), CFrame.new(bottom + Vector3.new(0, 2, 0)))
        foot.Name = "FallsFoam"
        K.Emit(foot, { Texture = K.TEX.Foam, Color = ColorSequence.new(Color3.fromRGB(236, 246, 250)), Rate = opts.Rate or 6,
            Lifetime = NumberRange.new(2.2, 3.4), Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(35, 35),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, width * 0.35), NumberSequenceKeypoint.new(1, width * 0.9) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
            Acceleration = Vector3.new(0, -6, 0), EmissionDirection = Enum.NormalId.Top, LightEmission = 0.2, LightInfluence = 0.6,
            Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20) })
    end
    return a
end
-- rock sets for natural worlds (variety from one call)
K.ROCKS = { "RockA", "BoulderA", "StoneA", "MossRock1", "MossRock2", "MossRock3", "MossRock4", "MossRock5", "MossRock6" }
K.CLIFFS = { "CliffA", "CliffB", "CliffC" }
function K.Pick(rng: Random, list: { string }): string return list[rng:NextInteger(1, #list)] end

-- n points round a ring (boss stage builders), skipping the north entrance gap
function K.Ring(n: number, radius: number, c: Vector3, fn: (Vector3, number, number) -> ())
    for i = 0, n - 1 do
        local a = (i + 0.5) / n * 2 * math.pi
        if math.abs(((a - math.pi + math.pi) % (2 * math.pi)) - math.pi) > 0.32 then
            fn(c + Vector3.new(math.sin(a) * radius, 0, math.cos(a) * radius), a, i)
        end
    end
end

return K
