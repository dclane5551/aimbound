--!nocheck
-- ENEMY MODELS (2026-10-02, owner: "massively improve ALL enemy models"). DungeonGenerator.CreateBot builds the
-- gameplay parts (DroneRoot, Torso + Head = the hitboxes, LegL / LegR, Shield ...); EnemyModels.Decorate adds the
-- look on top: plated armor, glowing eyes / cores, fins, thrusters, weapons, arms for walkers -- a distinct
-- silhouette per archetype so every enemy reads at a glance.
-- Decorations never collide; everything is anchored and moves with model:PivotTo like the rest of the bot. On BOTS
-- every visible decoration is hittable (EnemyModels.MakeHittable -- owner 2026-10-03: "you should be able to hit all
-- visible parts of them"); boss decorations still don't block shots. Glow parts carry the "Glow" attribute so SoftenEnemyVisuals keeps them lit.
--   local extra = EnemyModels.Decorate(model, { Arch, Pos, Body, Head, Ground, LegH, Color, Scale, Melee })
--   extra.Arms = { ArmL, ArmR } for walkers (animated by CreateBot with the legs), extra.ArmLen
local EnemyModels = {}

local ARMOR = Color3.fromRGB(38, 42, 52)
local ARMOR_LIGHT = Color3.fromRGB(78, 84, 98)
local METAL = Enum.Material.Metal
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

local function Part(model, props)
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
    p.Material = SMOOTH
    for k, v in pairs(props) do if k ~= "Glow" then p[k] = v end end
    if props.Glow then p.Material = NEON; p:SetAttribute("Glow", true) end
    p.Parent = model
    return p
end
local function Wedge(model, props)
    local w = Instance.new("WedgePart")
    w.Anchored = true; w.CanCollide = false; w.CanQuery = false; w.CanTouch = false; w.CastShadow = false
    w.Material = props.Material or METAL
    for k, v in pairs(props) do if k ~= "Glow" then w[k] = v end end
    if props.Glow then w.Material = NEON; w:SetAttribute("Glow", true) end
    w.Parent = model
    return w
end
local function Thruster(model, cf, size, color)
    Part(model, { Name = "Thruster", Shape = Enum.PartType.Cylinder, Size = Vector3.new(size * 0.6, size, size), CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Color = ARMOR, Material = METAL })
    local glow = Part(model, { Name = "ThrusterGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, size * 0.72, size * 0.72),
        CFrame = cf * CFrame.new(0, -size * 0.31, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Glow = true })
    local att = Instance.new("Attachment"); att.Parent = glow
    local pe = Instance.new("ParticleEmitter")
    pe.Name = "Exhaust"
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.Color = ColorSequence.new(color)
    pe.LightEmission = 1
    pe.Size = NumberSequence.new(size * 0.35, 0)
    pe.Transparency = NumberSequence.new(0.3, 1)
    pe.Lifetime = NumberRange.new(0.25, 0.4)
    pe.Rate = 9
    pe.Speed = NumberRange.new(4, 6)
    pe.EmissionDirection = Enum.NormalId.Left -- (the cylinder is rotated: Left = world down)
    pe.SpreadAngle = Vector2.new(12, 12)
    pe.Parent = att
end

-- a band around a ball body
local function Ring(model, cf, diameter, thick, color, glow)
    return Part(model, { Name = "ArmorRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(thick, diameter, diameter),
        CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Color = color or ARMOR, Material = glow and NEON or METAL, Glow = glow })
end

-- BOTS: every visible decoration takes hits (made in Decorate with CanQuery off, switched on here). A hit on one counts
-- as the part it sits on -- attribute HitAs = "Head" for pieces on the head (iris, brow, visor, mask...), else "Torso"
-- (AimRngClient / DungeonClient / RangeClient read HitAs; a party bot's client-only decoration reports its real part).
local GAMEPLAY_PARTS = { DroneRoot = true, Torso = true, Head = true, LegL = true, LegR = true, Shield = true, Core = true, DataTether = true }
function EnemyModels.MakeHittable(model: Model, parts: { BasePart }?)
    local head = model:FindFirstChild("Head")
    local list = parts or model:GetDescendants()
    for _, d in ipairs(list) do
        if d:IsA("BasePart") and not GAMEPLAY_PARTS[d.Name] and d.Transparency < 0.6 then
            d.CanQuery = true
            local onHead = head and head:IsA("BasePart") and (d.Position - head.Position).Magnitude <= head.Size.X * 0.75
            d:SetAttribute("HitAs", onHead and "Head" or "Torso")
        end
    end
end

-- a particle emitter on a part (biome roster looks)
local function Puff(part, tex, col, rate, size, speed, life, dir, spread, light)
    local att = Instance.new("Attachment"); att.Parent = part
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/" .. (tex or "sparkles_main.dds")
    pe.Color = typeof(col) == "ColorSequence" and col or ColorSequence.new(col)
    pe.LightEmission = light or 1
    pe.Rate = rate
    pe.Size = NumberSequence.new(size, 0)
    pe.Transparency = NumberSequence.new(0.2, 1)
    pe.Lifetime = NumberRange.new(life * 0.7, life)
    pe.Speed = NumberRange.new(speed * 0.6, speed)
    pe.SpreadAngle = Vector2.new(spread or 20, spread or 20)
    pe.EmissionDirection = dir or Enum.NormalId.Top
    pe.Parent = att
    return pe
end

function EnemyModels.Decorate(model, o)
    local A, pos, body, head, color = o.Arch, o.Pos, o.Body, o.Head, o.Color
    local s = o.Scale or 1
    local base = CFrame.new(pos)
    local R = math.max(body.X, body.Y) * 0.5
    local headY = body.Y / 2 + head.Y / 2 - 0.2
    local headCF = base * CFrame.new(0, headY, 0)
    local style = A.Style or (o.Ground and "Walker" or "Orb")
    local dark = color:Lerp(Color3.new(0, 0, 0), 0.55)
    local extra = {}

    -- ===== the eye: every head gets a glowing iris on its front + a brow plate (the head IS the weak spot) =====
    Part(model, { Name = "Iris", Shape = Enum.PartType.Ball, Size = Vector3.new(head.X * 0.42, head.X * 0.42, head.X * 0.2),
        CFrame = headCF * CFrame.new(0, 0, -head.Z * 0.42), Color = Color3.new(1, 1, 1), Glow = true })
    Part(model, { Name = "Brow", Size = Vector3.new(head.X * 0.9, head.Y * 0.16, head.Z * 0.5),
        CFrame = headCF * CFrame.new(0, head.Y * 0.36, -head.Z * 0.18) * CFrame.Angles(math.rad(-12), 0, 0), Color = ARMOR, Material = METAL })

    if o.Ground then
        -- ===== WALKERS: chest plate + core, shoulder pads, arms (weapon or fists), knee armor =====
        Part(model, { Name = "ChestPlate", Size = Vector3.new(body.X * 0.86, body.Y * 0.5, 0.25), CFrame = base * CFrame.new(0, body.Y * 0.12, -body.Z / 2 - 0.08),
            Color = ARMOR, Material = METAL })
        Part(model, { Name = "ChestCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, body.X * 0.32, body.X * 0.32),
            CFrame = base * CFrame.new(0, body.Y * 0.14, -body.Z / 2 - 0.22) * CFrame.Angles(0, math.rad(90), 0), Color = color, Glow = true })
        Part(model, { Name = "Belt", Size = Vector3.new(body.X * 1.04, body.Y * 0.12, body.Z * 1.08), CFrame = base * CFrame.new(0, -body.Y * 0.42, 0), Color = ARMOR_LIGHT, Material = METAL })
        for _, side in ipairs({ -1, 1 }) do
            Part(model, { Name = "Pauldron", Shape = Enum.PartType.Ball, Size = Vector3.new(body.X * 0.5, body.X * 0.42, body.Z * 0.95),
                CFrame = base * CFrame.new(side * body.X * 0.62, body.Y * 0.4, 0), Color = ARMOR, Material = METAL })
        end
        -- arms: shoulder at the pauldron, hanging down (CreateBot swings them opposite the legs)
        local armLen = body.Y * 0.95
        local arms = {}
        for _, side in ipairs({ -1, 1 }) do
            local arm = Part(model, { Name = side < 0 and "ArmL" or "ArmR", Size = Vector3.new(body.X * 0.24, armLen, body.Z * 0.5),
                CFrame = base * CFrame.new(side * body.X * 0.66, body.Y * 0.32 - armLen / 2, 0), Color = color:Lerp(ARMOR, 0.45), Material = SMOOTH })
            table.insert(arms, arm)
        end
        extra.Arms, extra.ArmLen = arms, armLen
        -- a weapon in the right hand (ranged) or big fists (melee): welded to the arm by offset each frame (see CreateBot)
        if o.Melee then
            for i, arm in ipairs(arms) do
                local fist = Part(model, { Name = "Fist", Shape = Enum.PartType.Ball, Size = Vector3.new(body.X * 0.42, body.X * 0.42, body.X * 0.42), CFrame = arm.CFrame * CFrame.new(0, -armLen / 2, 0),
                    Color = ARMOR_LIGHT, Material = METAL })
                extra.Hand = extra.Hand or {}
                extra.Hand[i] = { Part = fist, Off = CFrame.new(0, -armLen / 2, 0) }
            end
        else
            local gun = Part(model, { Name = "ArmGun", Size = Vector3.new(body.X * 0.2, body.X * 0.22, body.Z * 1.6), CFrame = arms[2].CFrame * CFrame.new(0, -armLen * 0.42, -body.Z * 0.5),
                Color = ARMOR, Material = METAL })
            local muzzle = Part(model, { Name = "Muzzle", Size = Vector3.new(body.X * 0.12, body.X * 0.12, 0.12), CFrame = gun.CFrame * CFrame.new(0, 0, -body.Z * 0.8), Color = color, Glow = true })
            extra.Hand = { [2] = { Part = gun, Off = CFrame.new(0, -armLen * 0.42, -body.Z * 0.5) }, Muzzle = { Part = muzzle, Off = CFrame.new(0, -armLen * 0.42, -body.Z * 1.3) } }
        end
        if style == "Leaper" then
            for _, side in ipairs({ -1, 1 }) do
                Part(model, { Name = "SpringBoot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5 * s, body.X * 0.3, body.X * 0.3),
                    CFrame = base * CFrame.new(side * body.X * 0.26, -body.Y / 2 - (o.LegH or 2) + 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Glow = true })
            end
        end
        if style == "Arc" then
            -- STORMSPIRE Arcwalker: a copper tesla pack on its back, coil rings, a crackling ball on top
            Part(model, { Name = "TeslaPack", Shape = Enum.PartType.Cylinder, Size = Vector3.new(body.Y * 0.8, body.X * 0.42, body.X * 0.42),
                CFrame = base * CFrame.new(0, body.Y * 0.2, body.Z * 0.62) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(176, 106, 58), Material = METAL })
            for k = 0, 2 do
                Part(model, { Name = "Coil", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, body.X * 0.56, body.X * 0.56),
                    CFrame = base * CFrame.new(0, body.Y * (-0.05 + k * 0.22), body.Z * 0.62) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Glow = true })
            end
            local orb = Part(model, { Name = "ArcOrb", Shape = Enum.PartType.Ball, Size = Vector3.new(body.X * 0.36, body.X * 0.36, body.X * 0.36),
                CFrame = base * CFrame.new(0, body.Y * 0.72, body.Z * 0.62), Color = Color3.fromRGB(220, 240, 255), Glow = true })
            local att = Instance.new("Attachment"); att.Parent = orb
            local pe = Instance.new("ParticleEmitter"); pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
            pe.Color = ColorSequence.new(color); pe.LightEmission = 1; pe.Rate = 14; pe.Lifetime = NumberRange.new(0.12, 0.25)
            pe.Speed = NumberRange.new(4, 8); pe.SpreadAngle = Vector2.new(180, 180); pe.Size = NumberSequence.new(0.22, 0); pe.Parent = att
        end
        if style == "Magmaw" then
            -- MOLTEN Magmaw: a hunched basalt digger -- spines of cooling rock down its back, a molten belly, a slag jaw
            local ROCK = Color3.fromRGB(46, 38, 36)
            for k = 0, 3 do
                Wedge(model, { Name = "Spine", Size = Vector3.new(body.X * 0.22, body.Y * (0.42 - k * 0.06), body.Z * 0.5),
                    CFrame = base * CFrame.new(0, body.Y * (0.5 - k * 0.24), body.Z * 0.55) * CFrame.Angles(math.rad(-25), 0, 0), Color = ROCK, Material = Enum.Material.Basalt })
            end
            Part(model, { Name = "Belly", Size = Vector3.new(body.X * 0.6, body.Y * 0.36, 0.2), CFrame = base * CFrame.new(0, -body.Y * 0.16, -body.Z / 2 - 0.12), Color = color, Glow = true })
            for _, c in ipairs({ { -0.3, 0.1, 30 }, { 0.32, -0.05, -40 }, { 0.05, 0.32, 80 } }) do
                Part(model, { Name = "Crack", Size = Vector3.new(0.12, body.Y * 0.32, 0.12), CFrame = base * CFrame.new(body.X * c[1], body.Y * c[2], -body.Z / 2 - 0.2) * CFrame.Angles(0, 0, math.rad(c[3])), Color = Color3.fromRGB(255, 170, 60), Glow = true })
            end
            Wedge(model, { Name = "Jaw", Size = Vector3.new(head.X * 1.05, head.Y * 0.4, head.Z * 0.9), CFrame = headCF * CFrame.new(0, -head.Y * 0.5, -head.Z * 0.15) * CFrame.Angles(math.rad(180), 0, 0), Color = ROCK, Material = Enum.Material.Basalt })
            Part(model, { Name = "Maw", Size = Vector3.new(head.X * 0.8, head.Y * 0.12, 0.1), CFrame = headCF * CFrame.new(0, -head.Y * 0.36, -head.Z * 0.5), Color = color, Glow = true })
            Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "fire_main.dds", Color3.fromRGB(255, 130, 40), 6, 0.6 * s, 2, 0.5, Enum.NormalId.Top, 30)
        elseif style == "Frostbite" then
            -- CRYO Frostbite: armored in ice -- crystal spikes off its shoulders and back, a frosted crest, a frost core
            local ICE = Color3.fromRGB(190, 235, 255)
            for _, side in ipairs({ -1, 1 }) do
                for k = 0, 1 do
                    Wedge(model, { Name = "IceSpike", Size = Vector3.new(body.X * 0.16, body.Y * (0.55 - k * 0.15), body.Z * 0.35),
                        CFrame = base * CFrame.new(side * body.X * (0.62 + k * 0.12), body.Y * (0.62 + k * 0.05), body.Z * (0.05 + k * 0.2)) * CFrame.Angles(math.rad(-15 - k * 10), 0, math.rad(side * (-20 - k * 15))),
                        Color = ICE, Material = Enum.Material.Ice, Transparency = 0.15 })
                end
            end
            for k = 0, 2 do
                Wedge(model, { Name = "BackShard", Size = Vector3.new(body.X * 0.18, body.Y * 0.5, body.Z * 0.4),
                    CFrame = base * CFrame.new(body.X * (k - 1) * 0.28, body.Y * 0.3, body.Z * 0.55) * CFrame.Angles(math.rad(-30), 0, math.rad((k - 1) * 18)), Color = ICE, Material = Enum.Material.Ice, Transparency = 0.15 })
            end
            Wedge(model, { Name = "Crest", Size = Vector3.new(head.X * 0.2, head.Y * 0.6, head.Z * 0.9), CFrame = headCF * CFrame.new(0, head.Y * 0.6, 0), Color = ICE, Material = Enum.Material.Ice, Transparency = 0.1 })
            Part(model, { Name = "Visor", Size = Vector3.new(head.X * 0.85, head.Y * 0.14, 0.1), CFrame = headCF * CFrame.new(0, head.Y * 0.06, -head.Z * 0.52), Color = Color3.fromRGB(150, 230, 255), Glow = true })
            Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "sparkles_main.dds", Color3.fromRGB(210, 240, 255), 5, 0.3 * s, 1, 0.8, Enum.NormalId.Top, 60)
        elseif style == "Mirror" then
            -- VOID Mirrorshade: a figure of mirror glass -- reflective plates, a blank mirror mask, a halo of void
            local GLASS = Color3.fromRGB(200, 190, 230)
            Part(model, { Name = "MirrorPlate", Size = Vector3.new(body.X * 0.9, body.Y * 0.62, 0.12), CFrame = base * CFrame.new(0, body.Y * 0.08, -body.Z / 2 - 0.32), Color = GLASS, Material = Enum.Material.Glass, Reflectance = 0.6, Transparency = 0.1 })
            for _, side in ipairs({ -1, 1 }) do
                Part(model, { Name = "MirrorShard", Size = Vector3.new(0.12, body.Y * 0.5, body.Z * 0.7), CFrame = base * CFrame.new(side * body.X * 0.56, 0, 0) * CFrame.Angles(0, 0, math.rad(side * 8)), Color = GLASS, Material = Enum.Material.Glass, Reflectance = 0.6 })
            end
            Part(model, { Name = "Mask", Size = Vector3.new(head.X * 0.9, head.Y * 0.9, 0.1), CFrame = headCF * CFrame.new(0, 0, -head.Z * 0.52), Color = GLASS, Material = Enum.Material.Glass, Reflectance = 0.75 })
            Ring(model, headCF * CFrame.new(0, head.Y * 0.85, 0), head.X * 1.4, 0.1 * s, color, true)
        elseif style == "Tracer" then
            -- CYBER Tracer: a sprinter -- a neon visor band, swept shoulder fins, light strips down its limbs, back thrusters
            Part(model, { Name = "VisorBand", Size = Vector3.new(head.X * 1.04, head.Y * 0.2, head.Z * 1.04), CFrame = headCF * CFrame.new(0, head.Y * 0.05, 0), Color = color, Glow = true })
            for _, side in ipairs({ -1, 1 }) do
                Wedge(model, { Name = "ShoulderFin", Size = Vector3.new(0.14, body.Y * 0.35, body.Z * 1.1), CFrame = base * CFrame.new(side * body.X * 0.68, body.Y * 0.52, body.Z * 0.2) * CFrame.Angles(0, 0, math.rad(side * -25)), Color = ARMOR_LIGHT, Material = METAL })
                Part(model, { Name = "LightStrip", Size = Vector3.new(0.1, body.Y * 0.8, 0.1), CFrame = base * CFrame.new(side * body.X * 0.3, 0, -body.Z / 2 - 0.1), Color = color, Glow = true })
            end
            Thruster(model, base * CFrame.new(0, body.Y * 0.1, body.Z * 0.6) * CFrame.Angles(math.rad(-90), 0, 0), body.X * 0.32, color)
        end
        if style == "Sleepwalker" then
            -- DREAMSCAPE Sleepwalker: striped pyjamas, a drooping nightcap with a pompom, a sleep mask, a glowing dream bubble
            local STRIPE = Color3.fromRGB(255, 236, 250)
            for k = -1, 1 do
                Part(model, { Name = "Stripe", Size = Vector3.new(body.X * 1.03, body.Y * 0.1, body.Z * 1.03), CFrame = base * CFrame.new(0, k * body.Y * 0.28, 0), Color = STRIPE, Material = SMOOTH })
            end
            Wedge(model, { Name = "Nightcap", Size = Vector3.new(head.X * 0.9, head.Y * 1.1, head.Z * 0.9), CFrame = headCF * CFrame.new(0, head.Y * 0.85, head.Z * 0.1) * CFrame.Angles(math.rad(-20), 0, 0), Color = color, Material = Enum.Material.Fabric })
            Part(model, { Name = "Pompom", Shape = Enum.PartType.Ball, Size = Vector3.one * head.X * 0.35, CFrame = headCF * CFrame.new(0, head.Y * 1.25, head.Z * 0.55), Color = STRIPE, Material = Enum.Material.Fabric })
            Part(model, { Name = "SleepMask", Size = Vector3.new(head.X * 1.04, head.Y * 0.22, head.Z * 1.04), CFrame = headCF * CFrame.new(0, head.Y * 0.12, 0), Color = Color3.fromRGB(70, 50, 110), Material = Enum.Material.Fabric })
            Part(model, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * head.X * 0.55, CFrame = headCF * CFrame.new(head.X * 0.9, head.Y * 0.9, 0), Color = Color3.fromRGB(150, 235, 255), Glow = true, Transparency = 0.3 })
        elseif style == "Roadrunner" then
            -- NEON FLATS Roadrunner: a racing rider -- a helmet with a fin and a neon visor, exhaust pipes on its back, light strips
            Part(model, { Name = "Helmet", Shape = Enum.PartType.Ball, Size = head * 1.12, CFrame = headCF, Color = Color3.fromRGB(30, 26, 36), Material = METAL, Reflectance = 0.2 })
            Part(model, { Name = "VisorBand", Size = Vector3.new(head.X * 1.0, head.Y * 0.24, head.Z * 0.4), CFrame = headCF * CFrame.new(0, head.Y * 0.05, -head.Z * 0.42), Color = color, Glow = true })
            Wedge(model, { Name = "Crest", Size = Vector3.new(0.18 * s, head.Y * 0.6, head.Z * 1.0), CFrame = headCF * CFrame.new(0, head.Y * 0.62, head.Z * 0.1), Color = color, Material = SMOOTH })
            for _, sx in ipairs({ -1, 1 }) do
                Part(model, { Name = "Exhaust", Shape = Enum.PartType.Cylinder, Size = Vector3.new(body.Y * 0.7, body.X * 0.2, body.X * 0.2), CFrame = base * CFrame.new(sx * body.X * 0.25, body.Y * 0.1, body.Z * 0.62) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(150, 150, 160), Material = METAL })
                Part(model, { Name = "LightStrip", Size = Vector3.new(0.1, body.Y * 0.8, 0.1), CFrame = base * CFrame.new(sx * body.X * 0.32, 0, -body.Z / 2 - 0.1), Color = Color3.fromRGB(80, 230, 255), Glow = true })
            end
        end
        if style == "Brute" then
            Part(model, { Name = "Hunch", Size = Vector3.new(body.X * 1.1, body.Y * 0.4, body.Z * 0.6), CFrame = base * CFrame.new(0, body.Y * 0.35, body.Z * 0.35), Color = ARMOR, Material = METAL })
            for _, side in ipairs({ -1, 1 }) do
                Wedge(model, { Name = "Tusk", Size = Vector3.new(0.3, head.Y * 0.5, head.Z * 0.6), CFrame = headCF * CFrame.new(side * head.X * 0.35, -head.Y * 0.3, -head.Z * 0.45) * CFrame.Angles(math.rad(180), 0, 0), Color = Color3.fromRGB(235, 225, 200), Material = SMOOTH })
            end
        end
        return extra
    end

    -- ===== FLYERS =====
    local function Fins(n, len, tilt, col)
        for i = 0, n - 1 do
            local a = (i / n) * math.pi * 2 + math.pi / n
            Wedge(model, { Name = "Fin", Size = Vector3.new(0.18 * s, R * 0.9, len),
                CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, -R * 0.05, R * 0.75 + len * 0.35) * CFrame.Angles(math.rad(tilt), 0, 0), Color = col or ARMOR })
        end
    end

    if style == "Orb" or style == "Tracker" then
        Ring(model, base, R * 2.12, 0.35 * s, ARMOR)
        Ring(model, base * CFrame.new(0, -R * 0.05, 0), R * 2.18, 0.12 * s, color, true)
        Fins(3, R * 0.9, 18)
        Thruster(model, base * CFrame.new(0, -R * 0.95, 0), R * 0.55, color)
    elseif style == "Strafer" then
        Ring(model, base, R * 2.1, 0.3 * s, ARMOR)
        for _, side in ipairs({ -1, 1 }) do
            local pod = base * CFrame.new(side * R * 1.15, 0, 0)
            Part(model, { Name = "SidePod", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 1.1, R * 0.5, R * 0.5), CFrame = pod * CFrame.Angles(0, math.rad(90), 0), Color = ARMOR, Material = METAL })
            Part(model, { Name = "PodGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, R * 0.38, R * 0.38), CFrame = pod * CFrame.new(0, 0, R * 0.56) * CFrame.Angles(0, math.rad(90), 0), Color = color, Glow = true })
        end
        Wedge(model, { Name = "Nose", Size = Vector3.new(R * 0.5, R * 0.4, R * 0.9), CFrame = base * CFrame.new(0, -R * 0.2, -R * 1.05) * CFrame.Angles(0, math.rad(180), 0), Color = ARMOR_LIGHT })
    elseif style == "Heavy" then -- Drifter / Juggernaut
        Ring(model, base, R * 2.16, 0.45 * s, ARMOR)
        Ring(model, base * CFrame.Angles(0, 0, math.rad(90)), R * 2.2, 0.4 * s, ARMOR)
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            Part(model, { Name = "Plate", Size = Vector3.new(R * 0.9, R * 0.9, 0.35 * s), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, R * 0.1, -R * 0.98), Color = ARMOR_LIGHT, Material = METAL })
        end
        Ring(model, base * CFrame.new(0, -R * 0.55, 0), R * 1.7, 0.18 * s, color, true)
        Thruster(model, base * CFrame.new(-R * 0.45, -R * 0.95, 0), R * 0.45, color)
        Thruster(model, base * CFrame.new(R * 0.45, -R * 0.95, 0), R * 0.45, color)
    elseif style == "Crystal" then -- Blinker
        local torso = model:FindFirstChild("Torso")
        if torso then torso.Transparency = 0.55; torso.Material = Enum.Material.Glass end
        Part(model, { Name = "Crystal", Size = Vector3.new(R * 1.15, R * 1.15, R * 1.15), CFrame = base * CFrame.Angles(math.rad(45), math.rad(45), 0), Color = color, Glow = true })
        for i = 0, 3 do
            local a = i * math.pi / 2
            Part(model, { Name = "Shard", Size = Vector3.new(R * 0.3, R * 0.7, R * 0.3), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -R * 1.45) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = color:Lerp(Color3.new(1, 1, 1), 0.4), Glow = true })
        end
    elseif style == "Hopper" then
        Ring(model, base, R * 2.1, 0.35 * s, ARMOR)
        Part(model, { Name = "Spring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 1.1, R * 0.45, R * 0.45), CFrame = base * CFrame.new(0, -R * 1.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = ARMOR_LIGHT, Material = METAL })
        Part(model, { Name = "Pad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3 * s, R * 1.1, R * 1.1), CFrame = base * CFrame.new(0, -R * 1.9, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Glow = true })
    elseif style == "Charger" then
        Ring(model, base, R * 2.12, 0.4 * s, ARMOR)
        Wedge(model, { Name = "Ram", Size = Vector3.new(R * 1.2, R * 0.9, R * 1.1), CFrame = base * CFrame.new(0, -R * 0.15, -R * 1.15) * CFrame.Angles(0, math.rad(180), 0), Color = ARMOR_LIGHT })
        for _, side in ipairs({ -1, 1 }) do
            Wedge(model, { Name = "Horn", Size = Vector3.new(0.3 * s, R * 0.9, R * 0.6), CFrame = headCF * CFrame.new(side * head.X * 0.45, head.Y * 0.35, 0) * CFrame.Angles(0, 0, math.rad(side * -25)), Color = Color3.fromRGB(235, 225, 200), Material = SMOOTH })
        end
        Thruster(model, base * CFrame.new(0, -R * 0.2, R * 1.05) * CFrame.Angles(math.rad(-90), 0, 0), R * 0.5, color)
    elseif style == "Sniper" then
        Ring(model, base, R * 2.1, 0.3 * s, ARMOR)
        Part(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 2.6, R * 0.22, R * 0.22), CFrame = base * CFrame.new(0, -R * 0.15, -R * 1.9) * CFrame.Angles(0, math.rad(90), 0), Color = ARMOR, Material = METAL })
        Part(model, { Name = "Scope", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 1.1, R * 0.32, R * 0.32), CFrame = base * CFrame.new(0, R * 0.4, -R * 0.9) * CFrame.Angles(0, math.rad(90), 0), Color = ARMOR_LIGHT, Material = METAL })
        Part(model, { Name = "Lens", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, R * 0.26, R * 0.26), CFrame = base * CFrame.new(0, R * 0.4, -R * 1.47) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 60, 60), Glow = true })
        Fins(2, R * 0.8, 10)
    elseif style == "Medic" then
        Ring(model, base, R * 2.1, 0.3 * s, Color3.fromRGB(230, 240, 235))
        Ring(model, base * CFrame.new(0, R * 1.35, 0), R * 1.4, 0.15 * s, color, true) -- halo
        Thruster(model, base * CFrame.new(0, -R * 0.95, 0), R * 0.45, color)
    elseif style == "Splitter" then
        Ring(model, base * CFrame.Angles(0, 0, math.rad(90)), R * 2.14, 0.22 * s, color, true) -- the seam it splits along
        Part(model, { Name = "HalfShell", Shape = Enum.PartType.Ball, Size = Vector3.new(body.X * 1.04, body.Y * 1.04, body.Z * 1.04) * 0.98,
            CFrame = base * CFrame.new(R * 0.18, 0, 0), Color = dark, Material = METAL, Transparency = 0.15 })
    elseif style == "Gunship" then
        Ring(model, base, R * 2.12, 0.4 * s, ARMOR)
        for _, side in ipairs({ -1, 1 }) do
            Wedge(model, { Name = "Wing", Size = Vector3.new(0.3 * s, R * 0.6, R * 2.2), CFrame = base * CFrame.new(side * R * 1.5, R * 0.2, R * 0.2) * CFrame.Angles(0, 0, math.rad(side * 80)), Color = ARMOR_LIGHT })
        end
        Thruster(model, base * CFrame.new(0, -R * 0.95, 0), R * 0.6, color)
    elseif style == "Popper" then
        Ring(model, base, R * 2.1, 0.3 * s, ARMOR)
        for i = 0, 5 do
            local a = i * math.pi / 3
            Part(model, { Name = "Kernel", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.5, R * 0.5, R * 0.5), CFrame = base * CFrame.Angles(0, a, math.rad(35)) * CFrame.new(0, R * 0.95, 0),
                Color = Color3.fromRGB(255, 245, 210), Material = SMOOTH })
        end
        Thruster(model, base * CFrame.new(0, -R * 0.95, 0), R * 0.6, color)
    elseif style == "Pasu" then
        local torso = model:FindFirstChild("Torso")
        if torso then torso.Shape = Enum.PartType.Block; torso.Size = Vector3.new(body.X, body.X, body.X) * 0.95 end
        for _, x in ipairs({ -1, 1 }) do for _, y in ipairs({ -1, 1 }) do for _, z in ipairs({ -1, 1 }) do
            Part(model, { Name = "Node", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.36, R * 0.36, R * 0.36), CFrame = base * CFrame.new(x * R * 0.5, y * R * 0.5, z * R * 0.5), Color = color, Glow = true })
        end end end
    elseif style == "Angel" then
        Ring(model, base, R * 2.1, 0.3 * s, Color3.fromRGB(240, 235, 220))
        Ring(model, base * CFrame.new(0, R * 1.5, 0), R * 1.3, 0.14 * s, Color3.fromRGB(255, 220, 120), true)
        for _, side in ipairs({ -1, 1 }) do
            for k = 0, 2 do
                Wedge(model, { Name = "Feather", Size = Vector3.new(0.18 * s, R * (1.1 - k * 0.22), R * (1.6 - k * 0.3)),
                    CFrame = base * CFrame.new(side * R * (1.0 + k * 0.25), R * (0.3 - k * 0.25), R * 0.3) * CFrame.Angles(math.rad(-10 - k * 18), math.rad(side * 20), math.rad(side * (70 - k * 10))),
                    Color = Color3.fromRGB(250, 248, 240), Material = SMOOTH })
            end
        end
    elseif style == "Zipper" then
        Part(model, { Name = "NoseCone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 1.5, R * 0.9, R * 0.9), CFrame = base * CFrame.new(0, 0, -R * 1.05) * CFrame.Angles(0, math.rad(90), 0), Color = ARMOR_LIGHT, Material = METAL })
        Wedge(model, { Name = "Tip", Size = Vector3.new(R * 0.6, R * 0.6, R * 0.8), CFrame = base * CFrame.new(0, 0, -R * 2.1) * CFrame.Angles(0, math.rad(180), 0), Color = color, Glow = true })
        Fins(4, R * 0.7, 0, color:Lerp(ARMOR, 0.4))
        Thruster(model, base * CFrame.new(0, 0, R * 1.0) * CFrame.Angles(math.rad(-90), 0, 0), R * 0.55, color)
    elseif style == "Stormcaller" then
        -- STORMSPIRE: a thundercloud of grey puffs around the core, a copper rod through it, a glowing tip
        for i = 0, 6 do
            local a = i / 7 * math.pi * 2
            Part(model, { Name = "Cloud", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 1.1, R * 0.9, R * 1.1),
                CFrame = base * CFrame.new(math.cos(a) * R * 0.95, R * 0.25 + (i % 2) * R * 0.2, math.sin(a) * R * 0.95), Color = Color3.fromRGB(92, 98, 112), Material = SMOOTH, Transparency = 0.15 })
        end
        Part(model, { Name = "Rod", Size = Vector3.new(0.3 * s, R * 3.4, 0.3 * s), CFrame = base * CFrame.new(0, R * 0.3, 0), Color = Color3.fromRGB(176, 106, 58), Material = METAL })
        Part(model, { Name = "RodTip", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.4, R * 0.4, R * 0.4), CFrame = base * CFrame.new(0, R * 2.0, 0), Color = color, Glow = true })
        Ring(model, base * CFrame.new(0, -R * 0.55, 0), R * 1.6, 0.14 * s, color, true)
    elseif style == "Gale" then
        -- STORMSPIRE: swept-back blade wings with glowing leading edges and trailing streamers
        for _, side in ipairs({ -1, 1 }) do
            Wedge(model, { Name = "Wing", Size = Vector3.new(0.2 * s, R * 0.8, R * 2.6),
                CFrame = base * CFrame.new(side * R * 1.3, 0, R * 0.5) * CFrame.Angles(0, math.rad(side * -25), math.rad(side * 80)), Color = Color3.fromRGB(226, 232, 240), Material = SMOOTH })
            Part(model, { Name = "WingEdge", Size = Vector3.new(0.12 * s, 0.12 * s, R * 2.4),
                CFrame = base * CFrame.new(side * R * 1.25, R * 0.05, R * 0.35) * CFrame.Angles(0, math.rad(side * -25), 0), Color = color, Glow = true })
            Part(model, { Name = "Streamer", Size = Vector3.new(0.08 * s, 0.08 * s, R * 2.2), CFrame = base * CFrame.new(side * R * 0.5, -R * 0.2, R * 1.6), Color = color, Glow = true, Transparency = 0.4 })
        end
        Ring(model, base, R * 2.05, 0.25 * s, Color3.fromRGB(226, 232, 240))
    elseif style == "Spark" then
        -- STORMSPIRE: a bright core inside two crossed glowing rings, crackling
        Ring(model, base * CFrame.Angles(math.rad(45), 0, 0), R * 2.3, 0.14 * s, color, true)
        Ring(model, base * CFrame.Angles(math.rad(-45), math.rad(90), 0), R * 2.3, 0.14 * s, color, true)
        local core = model:FindFirstChild("Torso")
        if core then
            local att = Instance.new("Attachment"); att.Parent = core
            local pe = Instance.new("ParticleEmitter"); pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
            pe.Color = ColorSequence.new(color); pe.LightEmission = 1; pe.Rate = 18; pe.Lifetime = NumberRange.new(0.1, 0.2)
            pe.Speed = NumberRange.new(5, 9); pe.SpreadAngle = Vector2.new(180, 180); pe.Size = NumberSequence.new(0.2, 0); pe.Parent = att
        end
    elseif style == "Conductor" then
        -- STORMSPIRE: a copper lightning totem -- a tall rod through the core, three glowing coil rings, a crown of prongs
        local COPPER = Color3.fromRGB(184, 112, 62)
        Part(model, { Name = "Totem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 4.2, R * 0.5, R * 0.5), CFrame = base * CFrame.Angles(0, 0, math.rad(90)), Color = COPPER, Material = METAL })
        for k = -1, 1 do Ring(model, base * CFrame.new(0, k * R * 0.9, 0), R * 2.3, 0.22 * s, color, true) end
        for i = 0, 3 do
            local a = i * math.pi / 2
            Part(model, { Name = "Prong", Size = Vector3.new(0.25 * s, R * 1.2, 0.25 * s), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, R * 2.2, R * 0.45) * CFrame.Angles(math.rad(-20), 0, 0), Color = COPPER, Material = METAL })
        end
        Part(model, { Name = "CrownOrb", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.6, R * 0.6, R * 0.6), CFrame = base * CFrame.new(0, R * 2.4, 0), Color = Color3.fromRGB(220, 240, 255), Glow = true })
    elseif style == "Cinder" then
        -- MOLTEN: a lump of burning coal -- dark crust plates over the glowing core, a flame plume, embers trailing
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2
            Part(model, { Name = "Crust", Size = Vector3.new(R * 0.95, R * 0.75, 0.3 * s), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad((i % 2) * 34 - 17), 0, 0) * CFrame.new(0, 0, -R * 0.96),
                Color = Color3.fromRGB(42, 34, 32), Material = Enum.Material.Basalt })
        end
        for _, y in ipairs({ 1, -1 }) do
            Part(model, { Name = "Crust", Size = Vector3.new(R * 0.9, 0.3 * s, R * 0.9), CFrame = base * CFrame.new(0, y * R * 0.96, 0) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(42, 34, 32), Material = Enum.Material.Basalt })
        end
        local plume = Part(model, { Name = "Plume", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.6, R * 0.6, R * 0.6), CFrame = base * CFrame.new(0, R * 1.05, 0), Color = Color3.fromRGB(255, 210, 110), Glow = true })
        Puff(plume, "fire_main.dds", ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 70, 20)), 22, R * 0.9, 5, 0.45, Enum.NormalId.Top, 12)
        Puff(plume, "sparkles_main.dds", Color3.fromRGB(255, 160, 60), 10, 0.25 * s, 3, 1.0, Enum.NormalId.Bottom, 60)
    elseif style == "Ashwing" then
        -- MOLTEN: an ash bat -- wide membrane wings with glowing ember veins, pointed ears, a smoldering trail
        local ASH = Color3.fromRGB(58, 52, 50)
        for _, side in ipairs({ -1, 1 }) do
            Wedge(model, { Name = "Wing", Size = Vector3.new(0.14 * s, R * 1.3, R * 3.0), CFrame = base * CFrame.new(side * R * 1.9, R * 0.2, R * 0.2) * CFrame.Angles(0, math.rad(side * 90), math.rad(-80)), Color = ASH, Material = SMOOTH })
            Wedge(model, { Name = "WingTip", Size = Vector3.new(0.14 * s, R * 0.8, R * 1.4), CFrame = base * CFrame.new(side * R * 3.3, R * 0.3, R * 0.3) * CFrame.Angles(0, math.rad(side * 90), math.rad(-80)), Color = ASH, Material = SMOOTH })
            for k = 0, 2 do
                Part(model, { Name = "Vein", Size = Vector3.new(R * (1.3 - k * 0.3), 0.08 * s, 0.08 * s), CFrame = base * CFrame.new(side * R * (1.5 + k * 0.4), R * (0.35 - k * 0.12), R * (0.0 + k * 0.25)) * CFrame.Angles(0, math.rad(side * (10 + k * 15)), 0), Color = color, Glow = true })
            end
            Wedge(model, { Name = "Ear", Size = Vector3.new(0.18 * s, R * 0.7, R * 0.45), CFrame = headCF * CFrame.new(side * head.X * 0.35, head.Y * 0.62, 0), Color = ASH, Material = SMOOTH })
        end
        Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "smoke_main.dds", Color3.fromRGB(70, 60, 56), 4, R * 0.8, 1, 1.2, Enum.NormalId.Back, 20, 0)
    elseif style == "Smelter" then
        -- MOLTEN: a floating crucible -- an iron pot slung under the core, a molten surface on top, a pouring lip, chains
        local IRON = Color3.fromRGB(60, 54, 52)
        Part(model, { Name = "Pot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 1.3, R * 2.3, R * 2.3), CFrame = base * CFrame.new(0, -R * 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = IRON, Material = METAL })
        Part(model, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3 * s, R * 2.5, R * 2.5), CFrame = base * CFrame.new(0, R * 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(90, 80, 74), Material = METAL })
        local melt = Part(model, { Name = "Melt", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15 * s, R * 2.1, R * 2.1), CFrame = base * CFrame.new(0, R * 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Glow = true })
        Wedge(model, { Name = "Lip", Size = Vector3.new(R * 0.6, R * 0.3, R * 0.7), CFrame = base * CFrame.new(0, R * 0.05, -R * 1.35) * CFrame.Angles(0, math.rad(180), 0), Color = IRON, Material = METAL })
        for i = 0, 2 do
            local a = i / 3 * math.pi * 2
            Part(model, { Name = "Chain", Size = Vector3.new(0.12 * s, R * 2.2, 0.12 * s), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, R * 1.2, R * 1.0) * CFrame.Angles(math.rad(-25), 0, 0), Color = Color3.fromRGB(100, 92, 86), Material = METAL })
        end
        Puff(melt, "smoke_main.dds", Color3.fromRGB(80, 66, 60), 5, R * 1.2, 2, 1.4, Enum.NormalId.Right, 15, 0) -- (the disc is rotated: Right = up)
        Puff(melt, "sparkles_main.dds", Color3.fromRGB(255, 190, 90), 8, 0.25 * s, 4, 0.6, Enum.NormalId.Right, 40)
    elseif style == "Shard" then
        -- CRYO: a cluster of ice crystals bursting out of a cold core
        local ICE = Color3.fromRGB(200, 240, 255)
        for i, d in ipairs({ { 0.1, 1, 0.05 }, { -0.05, -1, 0.1 }, { 1, 0.2, 0 }, { -1, 0.2, 0 }, { 0.3, 0.4, 1 }, { -0.4, -0.3, 1 }, { 0.5, -0.5, -0.6 } }) do
            local v = Vector3.new(d[1], d[2], d[3]).Unit
            local len = R * (1.4 + (i % 3) * 0.35)
            Part(model, { Name = "Crystal", Size = Vector3.new(R * 0.42, len, R * 0.42), CFrame = CFrame.lookAt(base.Position, base.Position + v) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, R * 0.5 + len / 2 - R * 0.3, 0),
                Color = ICE, Material = Enum.Material.Ice, Transparency = 0.12 })
        end
        Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "sparkles_main.dds", Color3.fromRGB(220, 245, 255), 8, 0.25 * s, 1.5, 0.7, Enum.NormalId.Top, 180)
    elseif style == "Flurry" then
        -- CRYO: a great snowflake -- six branching arms in a ring around the core, snow drifting off it
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2
            local arm = base * CFrame.Angles(0, 0, a)
            Part(model, { Name = "FlakeArm", Size = Vector3.new(0.22 * s, R * 1.2, 0.22 * s), CFrame = arm * CFrame.new(0, R * 1.2, 0), Color = Color3.fromRGB(235, 248, 255), Glow = true })
            for _, bs in ipairs({ -1, 1 }) do
                Part(model, { Name = "FlakeBranch", Size = Vector3.new(0.18 * s, R * 0.45, 0.18 * s), CFrame = arm * CFrame.new(0, R * 1.4, 0) * CFrame.Angles(0, 0, math.rad(bs * 45)) * CFrame.new(0, R * 0.22, 0), Color = Color3.fromRGB(200, 235, 255), Glow = true })
            end
        end
        Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "sparkles_main.dds", Color3.fromRGB(255, 255, 255), 10, 0.3 * s, 1, 1.4, Enum.NormalId.Bottom, 70, 0.5)
    elseif style == "Cryomancer" then
        -- CRYO: an ice totem -- a crown of icicles above the core, three frozen rings, a glowing heart, cold mist
        local ICE = Color3.fromRGB(190, 230, 255)
        for i = 0, 6 do
            local a = i / 7 * math.pi * 2
            Wedge(model, { Name = "Icicle", Size = Vector3.new(R * 0.25, R * (1.0 + (i % 2) * 0.5), R * 0.3), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, R * 1.5, -R * 0.75), Color = ICE, Material = Enum.Material.Ice, Transparency = 0.1 })
        end
        for k = -1, 1 do Ring(model, base * CFrame.new(0, k * R * 0.6, 0) * CFrame.Angles(math.rad(k * 18), 0, 0), R * (2.5 - math.abs(k) * 0.3), 0.18 * s, ICE, k == 0) end
        local mist = Part(model, { Name = "FrostHeart", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.5, R * 0.5, R * 0.5), CFrame = base * CFrame.new(0, 0, -R * 0.95), Color = Color3.fromRGB(150, 220, 255), Glow = true })
        Puff(mist, "smoke_main.dds", Color3.fromRGB(200, 230, 255), 4, R * 1.4, 0.8, 1.6, Enum.NormalId.Bottom, 60, 0.2)
    elseif style == "Phase" then
        -- VOID: a phase moth -- four shimmering wings, feathered antennae, eye-spots that glow
        for _, side in ipairs({ -1, 1 }) do
            for k, wing in ipairs({ { 1.6, 0.35, 2.2, 1.6 }, { 1.4, -0.45, 1.6, 1.2 } }) do
                local cf = base * CFrame.new(side * R * wing[1], R * wing[2], R * 0.3) * CFrame.Angles(0, 0, math.rad(side * (k == 1 and 20 or -15)))
                Part(model, { Name = "MothWing", Size = Vector3.new(R * wing[3], R * wing[4], 0.1 * s), CFrame = cf, Color = color, Material = Enum.Material.ForceField, Transparency = 0.1 })
                Part(model, { Name = "EyeSpot", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.4, R * 0.4, 0.12 * s), CFrame = cf * CFrame.new(side * R * 0.3, 0, -0.08), Color = Color3.fromRGB(255, 220, 255), Glow = true })
            end
            Part(model, { Name = "Antenna", Size = Vector3.new(0.08 * s, R * 1.3, 0.08 * s), CFrame = headCF * CFrame.new(side * head.X * 0.25, head.Y * 0.9, -head.Z * 0.2) * CFrame.Angles(math.rad(-25), 0, math.rad(side * -25)), Color = color, Glow = true })
        end
        Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "sparkles_main.dds", color, 6, 0.3 * s, 0.8, 1.0, Enum.NormalId.Bottom, 80)
    elseif style == "Riftling" then
        -- VOID: a living star -- four long points around a dark core, a ring of tiny satellites
        for i = 0, 3 do
            local a = i * math.pi / 2
            local pt = base * CFrame.Angles(0, 0, a)
            Wedge(model, { Name = "StarPoint", Size = Vector3.new(0.25 * s, R * 1.8, R * 0.7), CFrame = pt * CFrame.new(0, R * 1.5, 0) * CFrame.Angles(0, math.rad(90), 0), Color = color, Glow = true })
            Part(model, { Name = "StarMote", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.22, R * 0.22, R * 0.22), CFrame = base * CFrame.Angles(0, 0, a + math.pi / 4) * CFrame.new(0, R * 1.6, 0), Color = Color3.fromRGB(240, 220, 255), Glow = true })
        end
        Ring(model, base, R * 2.1, 0.22 * s, Color3.fromRGB(30, 18, 48))
        Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "sparkles_main.dds", color, 10, 0.25 * s, 2, 0.6, Enum.NormalId.Top, 180)
    elseif style == "Watcher" then
        -- VOID: a great eye -- a huge iris and slit pupil, heavy lids, tendrils hanging beneath
        local LID = Color3.fromRGB(60, 30, 70)
        Part(model, { Name = "BigIris", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14 * s, R * 1.3, R * 1.3), CFrame = base * CFrame.new(0, 0, -R * 0.98) * CFrame.Angles(0, math.rad(90), 0), Color = color, Glow = true })
        Part(model, { Name = "Pupil", Size = Vector3.new(R * 0.18, R * 0.95, 0.1 * s), CFrame = base * CFrame.new(0, 0, -R * 1.06), Color = Color3.fromRGB(10, 6, 14), Material = SMOOTH })
        for _, y in ipairs({ 1, -1 }) do
            Part(model, { Name = "Lid", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 2.2, R * 1.0, R * 2.0), CFrame = base * CFrame.new(0, y * R * 0.82, R * 0.05), Color = LID, Material = SMOOTH })
        end
        for i = 0, 4 do
            local a = i / 5 * math.pi * 2
            Part(model, { Name = "Tendril", Size = Vector3.new(0.16 * s, R * (1.4 + (i % 2) * 0.6), 0.16 * s), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, -R * 1.5, R * 0.55) * CFrame.Angles(math.rad(12), 0, 0), Color = color:Lerp(LID, 0.5), Material = SMOOTH })
        end
    elseif style == "Raster" then
        -- CYBER: a pixel cube -- a black frame with glowing edges around the core and a pixel screen for a face
        local e = R * 2.1
        for _, ax in ipairs({ { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }) do
            for _, sa in ipairs({ -1, 1 }) do
                for _, sb in ipairs({ -1, 1 }) do
                    local off, size
                    if ax[1] == 1 then off, size = Vector3.new(0, sa, sb) * e / 2, Vector3.new(e, 0.16 * s, 0.16 * s)
                    elseif ax[2] == 1 then off, size = Vector3.new(sa, 0, sb) * e / 2, Vector3.new(0.16 * s, e, 0.16 * s)
                    else off, size = Vector3.new(sa, sb, 0) * e / 2, Vector3.new(0.16 * s, 0.16 * s, e) end
                    Part(model, { Name = "CubeEdge", Size = size, CFrame = base * CFrame.new(off), Color = color, Glow = true })
                end
            end
        end
        for _, f in ipairs({ { 0, 0, -1 }, { 0, 0, 1 }, { 1, 0, 0 }, { -1, 0, 0 } }) do
            Part(model, { Name = "CubePanel", Size = Vector3.new(f[1] ~= 0 and 0.1 or e * 0.86, e * 0.86, f[3] ~= 0 and 0.1 or e * 0.86), CFrame = base * CFrame.new(f[1] * e / 2, 0, f[3] * e / 2),
                Color = Color3.fromRGB(16, 22, 26), Material = SMOOTH, Transparency = 0.35 })
        end
        for i = 0, 3 do
            Part(model, { Name = "Pixel", Size = Vector3.new(R * 0.3, R * 0.3, 0.12 * s), CFrame = base * CFrame.new(((i % 2) - 0.5) * R * 0.8, (math.floor(i / 2) - 0.5) * R * 0.8 - R * 0.6, -e / 2 - 0.06), Color = color, Glow = true })
        end
    elseif style == "Uplink" then
        -- CYBER: a satellite -- a dish on top, two solar wings, an antenna, blinking status lights
        Part(model, { Name = "Dish", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2 * s, R * 1.9, R * 1.9), CFrame = base * CFrame.new(0, R * 1.1, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(20), 0, 0), Color = ARMOR_LIGHT, Material = METAL })
        Part(model, { Name = "Feed", Size = Vector3.new(0.12 * s, R * 0.9, 0.12 * s), CFrame = base * CFrame.new(0, R * 1.5, 0), Color = color, Glow = true })
        for _, side in ipairs({ -1, 1 }) do
            Part(model, { Name = "SolarWing", Size = Vector3.new(R * 2.0, 0.1 * s, R * 1.0), CFrame = base * CFrame.new(side * R * 2.1, 0, 0), Color = Color3.fromRGB(30, 60, 120), Material = Enum.Material.Glass, Reflectance = 0.3 })
            Part(model, { Name = "WingGrid", Size = Vector3.new(R * 2.0, 0.12 * s, 0.06 * s), CFrame = base * CFrame.new(side * R * 2.1, 0.02, 0), Color = color, Glow = true })
            Part(model, { Name = "Strut", Size = Vector3.new(R * 0.6, 0.12 * s, 0.12 * s), CFrame = base * CFrame.new(side * R * 0.95, 0, 0), Color = ARMOR, Material = METAL })
        end
        Ring(model, base, R * 2.08, 0.25 * s, ARMOR)
    elseif style == "Firewall" then
        -- CYBER: a shield projector -- a hex frame of glowing panels round the core, a projector spike below
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2
            local cf = base * CFrame.Angles(0, 0, a) * CFrame.new(0, R * 1.35, 0)
            Part(model, { Name = "HexPanel", Size = Vector3.new(R * 1.45, 0.16 * s, R * 0.9), CFrame = cf, Color = color, Material = Enum.Material.ForceField, Transparency = 0.05 })
            Part(model, { Name = "HexEdge", Size = Vector3.new(R * 1.5, 0.2 * s, 0.12 * s), CFrame = cf * CFrame.new(0, 0, -R * 0.45), Color = color, Glow = true })
        end
        Wedge(model, { Name = "Projector", Size = Vector3.new(R * 0.5, R * 1.3, R * 0.5), CFrame = base * CFrame.new(0, -R * 1.5, 0) * CFrame.Angles(math.rad(180), 0, 0), Color = ARMOR_LIGHT, Material = METAL })
        Part(model, { Name = "ProjectorTip", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.35, R * 0.35, R * 0.35), CFrame = base * CFrame.new(0, -R * 2.2, 0), Color = color, Glow = true })
    elseif style == "Slagroller" then
        -- MOLTEN: a rolling boulder of slag -- dark basalt slabs over a molten core, glowing seams between them, smoke
        local ROCK = Color3.fromRGB(48, 40, 38)
        for i = 0, 7 do
            local a = i / 8 * math.pi * 2
            local tilt = (i % 2 == 0) and 28 or -28
            Part(model, { Name = "SlagPlate", Size = Vector3.new(R * 1.05, R * 0.95, 0.32 * s), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(tilt), 0, 0) * CFrame.new(0, 0, -R * 0.98),
                Color = ROCK, Material = Enum.Material.Basalt })
        end
        for _, y in ipairs({ 1, -1 }) do
            Part(model, { Name = "SlagCap", Size = Vector3.new(R * 1.1, 0.32 * s, R * 1.1), CFrame = base * CFrame.new(0, y * R * 0.98, 0) * CFrame.Angles(0, math.rad(22), 0), Color = ROCK, Material = Enum.Material.Basalt })
        end
        Ring(model, base * CFrame.Angles(0, 0, math.rad(90)), R * 2.06, 0.16 * s, color, true) -- the glowing seam it rolls on
        Ring(model, base, R * 2.04, 0.12 * s, Color3.fromRGB(255, 190, 90), true)
        Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "smoke_main.dds", Color3.fromRGB(70, 58, 52), 5, R * 0.9, 1.5, 1.0, Enum.NormalId.Top, 25, 0)
        Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "sparkles_main.dds", Color3.fromRGB(255, 150, 60), 8, 0.22 * s, 3, 0.5, Enum.NormalId.Bottom, 70)
    elseif style == "Rimewyrm" then
        -- CRYO: a frost serpent's head -- swept ice horns, a frilled crest, and a tail of shrinking ice segments behind it
        local ICE = Color3.fromRGB(200, 240, 255)
        for _, side in ipairs({ -1, 1 }) do
            Wedge(model, { Name = "Horn", Size = Vector3.new(0.2 * s, R * 1.2, R * 0.8), CFrame = base * CFrame.new(side * R * 0.55, R * 0.9, R * 0.3) * CFrame.Angles(math.rad(-35), 0, math.rad(side * -18)), Color = ICE, Material = Enum.Material.Ice, Transparency = 0.1 })
            Wedge(model, { Name = "Frill", Size = Vector3.new(0.12 * s, R * 0.9, R * 1.1), CFrame = base * CFrame.new(side * R * 1.0, 0, R * 0.2) * CFrame.Angles(0, 0, math.rad(side * 70)), Color = color, Material = Enum.Material.Ice, Transparency = 0.2 })
        end
        -- (from the front: a long ice snout, fangs and glowing frost eyes -- the tail is behind it)
        Wedge(model, { Name = "Snout", Size = Vector3.new(R * 0.9, R * 0.5, R * 1.1), CFrame = base * CFrame.new(0, -R * 0.2, -R * 1.15), Color = ICE, Material = Enum.Material.Ice, Transparency = 0.05 })
        for _, side in ipairs({ -1, 1 }) do
            Wedge(model, { Name = "Fang", Size = Vector3.new(0.12 * s, R * 0.45, R * 0.2), CFrame = base * CFrame.new(side * R * 0.28, -R * 0.62, -R * 1.25) * CFrame.Angles(math.rad(180), 0, 0), Color = Color3.fromRGB(240, 250, 255), Material = SMOOTH })
            Part(model, { Name = "FrostEye", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.28, R * 0.28, R * 0.28), CFrame = base * CFrame.new(side * R * 0.5, R * 0.25, -R * 0.85), Color = color, Glow = true })
        end
        for k = 1, 4 do
            local sz = R * (1.5 - k * 0.24)
            Part(model, { Name = "TailSegment", Shape = Enum.PartType.Ball, Size = Vector3.new(sz, sz, sz), CFrame = base * CFrame.new(0, -R * 0.15 * k, R * (0.75 + k * 0.85)),
                Color = (k % 2 == 0) and ICE or color, Material = Enum.Material.Ice, Transparency = 0.1 })
            Part(model, { Name = "TailFin", Size = Vector3.new(0.1 * s, sz * 0.8, sz * 0.5), CFrame = base * CFrame.new(0, -R * 0.15 * k + sz * 0.55, R * (0.75 + k * 0.85)), Color = color, Glow = true })
        end
        Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "sparkles_main.dds", Color3.fromRGB(220, 245, 255), 7, 0.22 * s, 1, 0.9, Enum.NormalId.Back, 50)
    elseif style == "Antipode" then
        -- VOID: two halves of one thing -- a black hemisphere and a white one, a ring between them, twin moons opposite
        Part(model, { Name = "DarkHalf", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 2.12, R * 2.12, R * 2.12), CFrame = base * CFrame.new(-R * 0.06, 0, 0), Color = Color3.fromRGB(14, 10, 22), Material = SMOOTH })
        Part(model, { Name = "LightHalf", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 2.1, R * 2.1, R * 2.1), CFrame = base * CFrame.new(R * 0.08, 0, 0), Color = Color3.fromRGB(245, 240, 255), Material = SMOOTH })
        Ring(model, base * CFrame.Angles(0, math.rad(90), 0), R * 2.3, 0.18 * s, color, true)
        for _, side in ipairs({ -1, 1 }) do
            Part(model, { Name = "Moon", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.5, R * 0.5, R * 0.5), CFrame = base * CFrame.new(side * R * 2.0, side * R * 0.6, 0),
                Color = (side < 0) and Color3.fromRGB(245, 240, 255) or Color3.fromRGB(30, 18, 48), Glow = side < 0 })
        end
        Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "sparkles_main.dds", color, 6, 0.24 * s, 1.5, 0.8, Enum.NormalId.Top, 180)
    elseif style == "Glitch" then
        -- CYBER: a corrupted cube -- three colour-split copies of its frame knocked out of line, broken pixel shards
        local e = R * 1.9
        for i, c in ipairs({ { Color3.fromRGB(255, 50, 80), Vector3.new(-0.18, 0.08, 0) }, { Color3.fromRGB(50, 255, 160), Vector3.new(0.16, -0.1, 0.05) }, { Color3.fromRGB(70, 140, 255), Vector3.new(0.02, 0.18, -0.06) } }) do
            local o2 = base * CFrame.new(c[2] * R) * CFrame.Angles(0, math.rad((i - 2) * 6), math.rad((i - 2) * 4))
            for _, sa in ipairs({ -1, 1 }) do
                Part(model, { Name = "GlitchEdge", Size = Vector3.new(e, 0.12 * s, 0.12 * s), CFrame = o2 * CFrame.new(0, sa * e / 2, -e / 2), Color = c[1], Glow = true })
                Part(model, { Name = "GlitchEdge", Size = Vector3.new(0.12 * s, e, 0.12 * s), CFrame = o2 * CFrame.new(sa * e / 2, 0, -e / 2), Color = c[1], Glow = true })
            end
        end
        Part(model, { Name = "GlitchCore", Size = Vector3.new(e * 0.9, e * 0.9, e * 0.9), CFrame = base, Color = Color3.fromRGB(20, 14, 28), Material = SMOOTH, Transparency = 0.25 })
        for i = 0, 4 do
            local a = i / 5 * math.pi * 2
            Part(model, { Name = "PixelShard", Size = Vector3.new(R * 0.3, R * 0.3, R * 0.3), CFrame = base * CFrame.Angles(a, a * 0.7, 0) * CFrame.new(0, R * 1.5, 0), Color = color, Glow = true })
        end
    elseif style == "Drowse" then
        -- DREAMSCAPE Drowse: a sleepy cloud -- soft puffs round its core, a nightcap with a pompom, a crescent moon charm
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2
            Part(model, { Name = "Cloud", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 1.1, R * 0.85, R * 1.1), CFrame = base * CFrame.new(math.cos(a) * R * 0.9, -R * 0.2 + (i % 2) * R * 0.25, math.sin(a) * R * 0.9),
                Color = Color3.fromRGB(236, 228, 255), Material = SMOOTH })
        end
        Wedge(model, { Name = "Nightcap", Size = Vector3.new(head.X * 0.9, head.Y * 1.2, head.Z * 0.9), CFrame = headCF * CFrame.new(0, head.Y * 0.9, head.Z * 0.1) * CFrame.Angles(math.rad(-25), 0, 0), Color = color, Material = Enum.Material.Fabric })
        Part(model, { Name = "Pompom", Shape = Enum.PartType.Ball, Size = Vector3.one * head.X * 0.36, CFrame = headCF * CFrame.new(0, head.Y * 1.35, head.Z * 0.6), Color = Color3.fromRGB(255, 240, 250), Glow = true })
        Part(model, { Name = "Moon", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.45, CFrame = base * CFrame.new(R * 1.5, -R * 0.6, 0), Color = Color3.fromRGB(255, 240, 200), Glow = true })
    elseif style == "Paperbird" then
        -- DREAMSCAPE Paperbird: an origami crane -- two flat folded wings with pink edges, a long neck, a tail up
        local PAPER = Color3.fromRGB(250, 246, 255)
        for _, side in ipairs({ -1, 1 }) do
            Wedge(model, { Name = "Wing", Size = Vector3.new(0.1 * s, R * 1.4, R * 2.6), CFrame = base * CFrame.new(side * R * 1.5, R * 0.2, R * 0.1) * CFrame.Angles(0, 0, math.rad(side * 82)), Color = PAPER, Material = SMOOTH })
            Part(model, { Name = "WingEdge", Size = Vector3.new(0.12 * s, 0.12 * s, R * 2.5), CFrame = base * CFrame.new(side * R * 2.2, R * 0.28, R * 0.1), Color = Color3.fromRGB(255, 150, 220), Glow = true })
        end
        Wedge(model, { Name = "Neck", Size = Vector3.new(0.18 * s, R * 0.5, R * 1.8), CFrame = base * CFrame.new(0, R * 0.3, -R * 1.4) * CFrame.Angles(math.rad(-30), math.rad(180), 0), Color = PAPER, Material = SMOOTH })
        Wedge(model, { Name = "TailFin", Size = Vector3.new(0.18 * s, R * 1.2, R * 1.0), CFrame = base * CFrame.new(0, R * 0.6, R * 1.2) * CFrame.Angles(math.rad(-40), 0, 0), Color = PAPER, Material = SMOOTH })
    elseif style == "Mirage" then
        -- DREAMSCAPE Mirage: a porcelain mask on a shimmering body, prisms circling it
        local torso = model:FindFirstChild("Torso")
        if torso then torso.Material = Enum.Material.Glass; torso.Transparency = 0.45 end
        Part(model, { Name = "Mask", Size = Vector3.new(R * 1.3, R * 1.5, 0.2 * s), CFrame = base * CFrame.new(0, R * 0.1, -R * 1.0), Color = Color3.fromRGB(250, 246, 255), Material = SMOOTH })
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "EyeSpot", Size = Vector3.new(R * 0.32, R * 0.14, 0.1 * s), CFrame = base * CFrame.new(sx * R * 0.3, R * 0.3, -R * 1.12) * CFrame.Angles(0, 0, math.rad(sx * -12)), Color = color, Glow = true })
        end
        for i = 0, 4 do
            local a = i / 5 * math.pi * 2
            Part(model, { Name = "Shard", Size = Vector3.new(R * 0.3, R * 0.7, R * 0.3), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, (i % 2) * R * 0.5 - R * 0.2, R * 1.7) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
                Color = (i % 2 == 0) and color or Color3.fromRGB(255, 170, 230), Material = Enum.Material.Glass, Transparency = 0.15 })
        end
    elseif style == "Jellylamp" then
        -- DREAMSCAPE Jellylamp: a glass jellyfish lamp -- a dome over a glowing heart, a frill, trailing tendrils
        Part(model, { Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 2.4, R * 1.8, R * 2.4), CFrame = base * CFrame.new(0, R * 0.3, 0), Color = color, Material = Enum.Material.Glass, Transparency = 0.35 })
        Part(model, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.9, CFrame = base * CFrame.new(0, R * 0.2, 0), Color = Color3.fromRGB(255, 220, 245), Glow = true })
        Ring(model, base * CFrame.new(0, -R * 0.5, 0), R * 2.5, 0.18 * s, color, true)
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2
            Part(model, { Name = "Tendril", Size = Vector3.new(0.14 * s, R * (1.6 + (i % 3) * 0.5), 0.14 * s), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, -R * 1.4, R * 0.75),
                Color = (i % 2 == 0) and color or Color3.fromRGB(150, 235, 255), Glow = true, Transparency = 0.2 })
        end
    elseif style == "Dreamweaver" then
        -- DREAMSCAPE Dreamweaver: a loom of light -- a frame round its core, glowing threads strung across, a spinning bobbin
        local FRAME = Color3.fromRGB(236, 228, 250)
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "Post", Size = Vector3.new(0.35 * s, R * 3.4, 0.35 * s), CFrame = base * CFrame.new(sx * R * 1.4, 0, 0), Color = FRAME, Material = Enum.Material.Marble })
        end
        for _, y in ipairs({ -1, 1 }) do
            Part(model, { Name = "Beam", Size = Vector3.new(R * 3.2, 0.35 * s, 0.35 * s), CFrame = base * CFrame.new(0, y * R * 1.6, 0), Color = FRAME, Material = Enum.Material.Marble })
        end
        for k = -2, 2 do
            Part(model, { Name = "Vein", Size = Vector3.new(0.06 * s, R * 3.0, 0.06 * s), CFrame = base * CFrame.new(k * R * 0.5, 0, -R * 0.4), Color = (k % 2 == 0) and color or Color3.fromRGB(150, 235, 255), Glow = true })
        end
        Part(model, { Name = "Crystal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 1.2, R * 0.6, R * 0.6), CFrame = base * CFrame.new(0, R * 2.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Glow = true })
    elseif style == "Tumble" then
        -- NEON FLATS Tumble: a ball of rebar and live wire -- crossed rods every which way, a sparking neon wire loop
        local REBAR = Color3.fromRGB(120, 70, 60)
        for i = 0, 7 do
            local a, b = i * 0.79, i * 1.31
            Part(model, { Name = "Rebar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 2.6, 0.22 * s, 0.22 * s), CFrame = base * CFrame.Angles(a, b, a * 0.5), Color = REBAR, Material = Enum.Material.CorrodedMetal })
        end
        Ring(model, base * CFrame.Angles(math.rad(30), 0, math.rad(60)), R * 2.3, 0.12 * s, color, true)
        Ring(model, base * CFrame.Angles(math.rad(-50), math.rad(40), 0), R * 2.1, 0.1 * s, Color3.fromRGB(80, 230, 255), true)
        Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "sparkles_main.dds", color, 8, 0.25 * s, 4, 0.4, Enum.NormalId.Top, 180)
    elseif style == "Vulture" then
        -- NEON FLATS Vulture: a scavenger drone -- long swept wings with ragged tips, a hooked beak, a red scanner eye
        local HIDE = Color3.fromRGB(46, 34, 40)
        for _, side in ipairs({ -1, 1 }) do
            Wedge(model, { Name = "Wing", Size = Vector3.new(0.16 * s, R * 1.0, R * 3.2), CFrame = base * CFrame.new(side * R * 1.9, R * 0.3, R * 0.3) * CFrame.Angles(0, math.rad(side * 15), math.rad(side * 84)), Color = HIDE, Material = METAL })
            Wedge(model, { Name = "WingTip", Size = Vector3.new(0.14 * s, R * 0.6, R * 1.4), CFrame = base * CFrame.new(side * R * 3.6, R * 0.45, R * 0.7) * CFrame.Angles(0, math.rad(side * 25), math.rad(side * 84)), Color = HIDE, Material = METAL })
            Part(model, { Name = "WingEdge", Size = Vector3.new(0.1 * s, 0.1 * s, R * 3.0), CFrame = base * CFrame.new(side * R * 1.9, R * 0.32, R * 0.0) * CFrame.Angles(0, math.rad(side * 15), 0), Color = color, Glow = true })
        end
        Wedge(model, { Name = "Beak", Size = Vector3.new(R * 0.4, R * 0.5, R * 0.9), CFrame = headCF * CFrame.new(0, -head.Y * 0.2, -head.Z * 0.8) * CFrame.Angles(math.rad(200), 0, 0), Color = Color3.fromRGB(230, 200, 140), Material = SMOOTH })
        Part(model, { Name = "Lens", Shape = Enum.PartType.Ball, Size = Vector3.one * head.X * 0.32, CFrame = headCF * CFrame.new(0, head.Y * 0.15, -head.Z * 0.45), Color = Color3.fromRGB(255, 60, 60), Glow = true })
    elseif style == "Billboard" then
        -- NEON FLATS Billboard: a flying holo sign -- a dark panel with a neon frame and scrolling text bars, a thruster under it
        local panel = base * CFrame.new(0, R * 0.2, -R * 0.2)
        Part(model, { Name = "Panel", Size = Vector3.new(R * 3.4, R * 2.0, 0.25 * s), CFrame = panel, Color = Color3.fromRGB(20, 16, 26), Material = SMOOTH })
        for _, y in ipairs({ -1, 1 }) do Part(model, { Name = "Frame", Size = Vector3.new(R * 3.5, 0.14 * s, 0.3 * s), CFrame = panel * CFrame.new(0, y * R, 0), Color = color, Glow = true }) end
        for _, x in ipairs({ -1, 1 }) do Part(model, { Name = "Frame", Size = Vector3.new(0.14 * s, R * 2.1, 0.3 * s), CFrame = panel * CFrame.new(x * R * 1.7, 0, 0), Color = color, Glow = true }) end
        Part(model, { Name = "Glow", Size = Vector3.new(R * 2.4, R * 0.45, 0.1 * s), CFrame = panel * CFrame.new(-R * 0.2, R * 0.4, -0.16 * s), Color = Color3.fromRGB(255, 90, 180), Glow = true })
        Part(model, { Name = "Glow", Size = Vector3.new(R * 1.6, R * 0.3, 0.1 * s), CFrame = panel * CFrame.new(-R * 0.6, -R * 0.35, -0.16 * s), Color = Color3.fromRGB(255, 220, 90), Glow = true })
        Thruster(model, base * CFrame.new(0, -R * 1.2, 0), R * 0.55, color)
    elseif style == "DustDevil" then
        -- NEON FLATS Dust Devil: a spinning funnel of sand -- stacked discs narrowing downward, grit whirling round it
        local SAND = Color3.fromRGB(214, 180, 140)
        for k = 0, 4 do
            Part(model, { Name = "Cloud", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 0.4, R * (2.6 - k * 0.42), R * (2.6 - k * 0.42)),
                CFrame = base * CFrame.new(R * 0.15 * math.sin(k), R * (0.6 - k * 0.55), R * 0.15 * math.cos(k)) * CFrame.Angles(0, 0, math.rad(90)), Color = SAND, Material = Enum.Material.Sand, Transparency = 0.25 })
        end
        Ring(model, base * CFrame.new(0, R * 0.9, 0), R * 2.8, 0.1 * s, color, true)
        Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "smoke_main.dds", SAND, 8, R * 0.9, 3, 1.0, Enum.NormalId.Top, 60, 0)
    elseif style == "Pylon" then
        -- NEON FLATS Pylon: a walking power pylon -- a lattice frame round its core, two glass insulators, a sparking crossarm
        local STEEL = Color3.fromRGB(110, 110, 118)
        for _, sx in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                Part(model, { Name = "Strut", Size = Vector3.new(0.22 * s, R * 3.8, 0.22 * s), CFrame = base * CFrame.new(sx * R * 0.9, -R * 0.2, sz * R * 0.9) * CFrame.Angles(math.rad(sz * 8), 0, math.rad(-sx * 8)), Color = STEEL, Material = METAL })
            end
        end
        Part(model, { Name = "Crossarm", Size = Vector3.new(R * 3.8, 0.3 * s, 0.3 * s), CFrame = base * CFrame.new(0, R * 1.6, 0), Color = STEEL, Material = METAL })
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.5, CFrame = base * CFrame.new(sx * R * 1.8, R * 1.3, 0), Color = Color3.fromRGB(80, 230, 255), Glow = true })
        end
        Puff(model:FindFirstChild("Torso") or model.PrimaryPart, "sparkles_main.dds", Color3.fromRGB(150, 230, 255), 10, 0.2 * s, 6, 0.3, Enum.NormalId.Top, 180)
    elseif style == "Orbiter" then
        Ring(model, base * CFrame.Angles(math.rad(25), 0, math.rad(20)), R * 2.9, 0.22 * s, color, true)
        Part(model, { Name = "Moon", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 0.45, R * 0.45, R * 0.45), CFrame = base * CFrame.Angles(math.rad(25), 0, math.rad(20)) * CFrame.new(R * 1.45, 0, 0), Color = ARMOR_LIGHT, Material = METAL })
        Ring(model, base, R * 2.08, 0.3 * s, ARMOR)
    else
        Ring(model, base, R * 2.1, 0.3 * s, ARMOR)
    end
    -- ===== DETAIL PASS (0.53, owner: "continue to improve on model quality of everything"): the first-generation
    -- flyers were a sphere, a ring and fins. Each gets a real silhouette: armour shells with glowing seams, sensors,
    -- engines, weapons. ~8 parts each (performance first). EnemyAnim moves the named ones (Fin flaps, Glow pulses...).
    local function Seam(cf, len)
        Part(model, { Name = "Vein", Size = Vector3.new(0.08 * s, 0.08 * s, len), CFrame = cf, Color = color, Glow = true })
    end
    if style == "Orb" or style == "Tracker" then
        -- a scout drone: four armour petals around the core, a sensor mast with a lens
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            Wedge(model, { Name = "Shell", Size = Vector3.new(R * 1.0, R * 0.55, R * 0.7), Color = ARMOR_LIGHT, Material = METAL,
                CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, R * 0.62, -R * 0.62) * CFrame.Angles(math.rad(35), 0, 0) })
            Seam(base * CFrame.Angles(0, a + math.pi / 4, 0) * CFrame.new(0, R * 0.55, -R * 0.82) * CFrame.Angles(math.rad(40), 0, 0), R * 0.6)
        end
        Part(model, { Name = "Mast", Size = Vector3.new(0.14 * s, R * 0.9, 0.14 * s), CFrame = base * CFrame.new(R * 0.35, R * 1.25, R * 0.2), Color = ARMOR, Material = METAL })
        Part(model, { Name = "Lens", Shape = Enum.PartType.Ball, Size = Vector3.one * R * 0.24, CFrame = base * CFrame.new(R * 0.35, R * 1.72, R * 0.2), Color = color, Glow = true })
    elseif style == "Strafer" then
        -- a racer: swept canards ahead of the pods, a glowing cockpit stripe, tail fins
        for _, side in ipairs({ -1, 1 }) do
            Wedge(model, { Name = "Fin", Size = Vector3.new(0.14 * s, R * 0.4, R * 1.0), Color = ARMOR_LIGHT, Material = METAL,
                CFrame = base * CFrame.new(side * R * 0.95, R * 0.1, -R * 0.75) * CFrame.Angles(0, math.rad(side * 25), math.rad(side * 75)) })
            Wedge(model, { Name = "TailFin", Size = Vector3.new(0.14 * s, R * 0.7, R * 0.6), Color = ARMOR, Material = METAL,
                CFrame = base * CFrame.new(side * R * 0.45, R * 0.7, R * 0.85) * CFrame.Angles(0, 0, math.rad(side * -20)) })
        end
        Part(model, { Name = "VisorBand", Size = Vector3.new(R * 1.3, R * 0.16, R * 0.4), CFrame = base * CFrame.new(0, R * 0.55, -R * 0.75) * CFrame.Angles(math.rad(-30), 0, 0), Color = color, Glow = true })
    elseif style == "Heavy" then
        -- a gun platform: a turret dome on top with twin barrels, glowing vents round the skirt
        Part(model, { Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 1.1, R * 0.7, R * 1.1), CFrame = base * CFrame.new(0, R * 1.0, 0), Color = ARMOR, Material = METAL })
        for _, side in ipairs({ -1, 1 }) do
            Part(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 1.3, R * 0.18, R * 0.18), Color = ARMOR_LIGHT, Material = METAL,
                CFrame = base * CFrame.new(side * R * 0.22, R * 1.05, -R * 0.85) * CFrame.Angles(0, math.rad(90), 0) })
            Part(model, { Name = "Tip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1 * s, R * 0.14, R * 0.14), Color = color, Glow = true,
                CFrame = base * CFrame.new(side * R * 0.22, R * 1.05, -R * 1.5) * CFrame.Angles(0, math.rad(90), 0) })
        end
        for i = 0, 3 do
            Part(model, { Name = "Vein", Size = Vector3.new(R * 0.5, 0.1 * s, 0.1 * s), Color = color, Glow = true,
                CFrame = base * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, -R * 0.35, -R * 1.02) })
        end
    elseif style == "Hopper" then
        -- a spring drone: three shock legs round the spring, a top dome, a glowing band
        for i = 0, 2 do
            local a = i / 3 * math.pi * 2
            Part(model, { Name = "Spring", Size = Vector3.new(0.18 * s, R * 1.3, 0.18 * s), Color = ARMOR_LIGHT, Material = METAL,
                CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, -R * 1.25, -R * 0.55) * CFrame.Angles(math.rad(-20), 0, 0) })
        end
        Part(model, { Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(R * 1.2, R * 0.8, R * 1.2), CFrame = base * CFrame.new(0, R * 0.75, 0), Color = ARMOR, Material = METAL })
        Ring(model, base * CFrame.new(0, R * 0.35, 0), R * 2.0, 0.12 * s, color, true)
    elseif style == "Charger" then
        -- a battering drone: tusk spikes on the ram, an exhaust ring behind, glowing rage seams
        for _, side in ipairs({ -1, 1 }) do
            Wedge(model, { Name = "Spike", Size = Vector3.new(0.3 * s, R * 0.5, R * 0.8), Color = Color3.fromRGB(235, 225, 200), Material = SMOOTH,
                CFrame = base * CFrame.new(side * R * 0.45, -R * 0.1, -R * 1.75) * CFrame.Angles(math.rad(-90), 0, 0) })
            Seam(base * CFrame.new(side * R * 0.7, R * 0.2, -R * 0.5) * CFrame.Angles(0, math.rad(side * 20), 0), R * 1.1)
        end
        Part(model, { Name = "Tip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12 * s, R * 0.55, R * 0.55), Color = color, Glow = true,
            CFrame = base * CFrame.new(0, -R * 0.2, R * 1.12) * CFrame.Angles(0, math.rad(90), 0) })
    elseif style == "Sniper" then
        -- a marksman drone: a muzzle brake, stabiliser legs folded under it, a faint range-finder beam
        Part(model, { Name = "Brake", Size = Vector3.new(R * 0.4, R * 0.32, R * 0.5), CFrame = base * CFrame.new(0, -R * 0.15, -R * 3.2), Color = ARMOR_LIGHT, Material = METAL })
        Part(model, { Name = "Tip", Size = Vector3.new(R * 0.2, R * 0.12, 0.1 * s), CFrame = base * CFrame.new(0, -R * 0.15, -R * 3.46), Color = color, Glow = true })
        for _, side in ipairs({ -1, 1 }) do
            Part(model, { Name = "Strut", Size = Vector3.new(0.14 * s, R * 1.2, 0.14 * s), Color = ARMOR, Material = METAL,
                CFrame = base * CFrame.new(side * R * 0.55, -R * 1.05, -R * 0.4) * CFrame.Angles(math.rad(25), 0, math.rad(side * 20)) })
        end
    elseif style == "Medic" then
        -- a field medic: a glowing cross on four sides, two med pods
        for i = 0, 3 do
            local cf = base * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0, -R * 1.02)
            Part(model, { Name = "Glow", Size = Vector3.new(R * 0.18, R * 0.6, 0.08 * s), CFrame = cf, Color = color, Glow = true })
            Part(model, { Name = "Glow", Size = Vector3.new(R * 0.6, R * 0.18, 0.08 * s), CFrame = cf, Color = color, Glow = true })
        end
        for _, side in ipairs({ -1, 1 }) do
            Part(model, { Name = "Pod", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 0.9, R * 0.45, R * 0.45), CFrame = base * CFrame.new(side * R * 1.2, -R * 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
                Color = Color3.fromRGB(230, 240, 235), Material = SMOOTH })
        end
    elseif style == "Gunship" then
        -- a gunship: two engine nacelles on the wings, a chin cannon, a glowing cockpit band
        for _, side in ipairs({ -1, 1 }) do
            Part(model, { Name = "Nacelle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 1.2, R * 0.5, R * 0.5), Color = ARMOR, Material = METAL,
                CFrame = base * CFrame.new(side * R * 2.2, R * 0.2, R * 0.1) * CFrame.Angles(0, math.rad(90), 0) })
            Part(model, { Name = "PodGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1 * s, R * 0.38, R * 0.38), Color = color, Glow = true,
                CFrame = base * CFrame.new(side * R * 2.2, R * 0.2, R * 0.72) * CFrame.Angles(0, math.rad(90), 0) })
        end
        Part(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(R * 1.2, R * 0.22, R * 0.22), CFrame = base * CFrame.new(0, -R * 0.8, -R * 1.0) * CFrame.Angles(0, math.rad(90), 0), Color = ARMOR_LIGHT, Material = METAL })
        Part(model, { Name = "VisorBand", Size = Vector3.new(R * 1.2, R * 0.16, R * 0.5), CFrame = base * CFrame.new(0, R * 0.5, -R * 0.85) * CFrame.Angles(math.rad(-25), 0, 0), Color = color, Glow = true })
    end
    -- (0.89 WORLD FOES: the world rosters' looks live in their own modules)
    local wd = EnemyModels.WorldDecor and EnemyModels.WorldDecor[style]
    if wd then
        wd(model, { Part = Part, Wedge = Wedge, Puff = Puff, Ring = Ring, base = base, R = R, headCF = headCF, body = body, head = head, s = s,
            color = color, dark = dark, Ground = o.Ground, extra = extra, NEON = NEON, METAL = METAL, SMOOTH = SMOOTH })
    end
    return extra
end

-- ===== BOSSES: a real silhouette on top of each boss's gameplay parts (Torso / Core / Head stay the hitboxes) =====
-- kind = "Goliath" | "Phantom" | "Sentinel" | "Titan" | "SuperBoss" (biome = Fire / Ice / Void / Cyber)
local function Emit(part, color, rate, size, speed, life, tex)
    local att = Instance.new("Attachment"); att.Parent = part
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = tex or "rbxasset://textures/particles/sparkles_main.dds"
    pe.Color = ColorSequence.new(color)
    pe.LightEmission = 0.8
    pe.Size = NumberSequence.new(size, 0)
    pe.Transparency = NumberSequence.new(0.2, 1)
    pe.Lifetime = NumberRange.new(life * 0.7, life)
    pe.Rate = rate
    pe.Speed = NumberRange.new(speed * 0.5, speed)
    pe.SpreadAngle = Vector2.new(180, 180)
    pe.Parent = att
    return pe
end

-- ===== THE ASCENDANT (Trial of Ascension boss, 2026-10-05): an obsidian-and-silver knight floating over the arena,
-- a long robe of hanging plates, a turning halo wheel behind it set with four sigil gems, a three-gem crown and a greatsword
-- held point-down before it. BossAI animates Deco_Wheel (turn), Deco_Robe (drift), Deco_PauldronL/R (bob), Deco_Sword
-- (raised while it attacks). Torso / Core (chest) / Head are the hit zones (DungeonGenerator.CreateAscendant).
function EnemyModels.DecorateAscendant(model, pos)
    if EnemyModels.TryLook(model, "Ascendant", pos) then return end -- (BOSS LOOK v2: AimRngShared/BossLook/Ascendant)
    local base = CFrame.new(pos)
    local function M(x, y, z) return base * CFrame.new(x, y, z) end
    local OBS, SILVER, TEAL, GOLD = Color3.fromRGB(22, 24, 34), Color3.fromRGB(196, 200, 212), Color3.fromRGB(60, 240, 210), Color3.fromRGB(255, 215, 110)
    -- chest armour: a silver breastplate with a teal seam framing the core, a gorget, the belt
    for _, sx in ipairs({ -1, 1 }) do
        Wedge(model, { Name = "Breastplate", Size = Vector3.new(2.6, 4.2, 0.7), CFrame = M(sx * 1.3, 2.4, -1.95) * CFrame.Angles(0, math.rad(180), math.rad(sx * 8)), Color = SILVER, Material = METAL })
        Part(model, { Name = "Seam", Size = Vector3.new(0.18, 6, 0.12), CFrame = M(sx * 2.45, 1, -1.78), Color = TEAL, Glow = true })
    end
    Part(model, { Name = "Gorget", Size = Vector3.new(3.4, 1, 3), CFrame = M(0, 4.8, 0), Color = SILVER, Material = METAL })
    Part(model, { Name = "Belt", Size = Vector3.new(5.4, 0.7, 3.8), CFrame = M(0, -3.6, 0), Color = GOLD, Material = METAL })
    Part(model, { Name = "BeltGem", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = M(0, -3.6, -1.95), Color = TEAL, Glow = true })
    -- the robe: long plates hanging from the belt, flaring out (it floats; the hem trails light)
    for i = 0, 9 do
        local a = i / 10 * math.pi * 2
        local len = 8 + (i % 2) * 1.2
        local cf = M(math.cos(a) * 2.2, -4 - len / 2, math.sin(a) * 1.7) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(-10))
        Part(model, { Name = "Deco_Robe", Size = Vector3.new(0.3, len, 1.8), CFrame = cf, Color = (i % 2 == 0) and OBS or Color3.fromRGB(36, 40, 56), Material = Enum.Material.Fabric })
        Part(model, { Name = "Deco_RobeHem", Size = Vector3.new(0.32, 0.25, 1.8), CFrame = cf * CFrame.new(0, -len / 2 + 0.2, 0), Color = TEAL, Glow = true })
    end
    -- floating pauldrons
    for _, sx in ipairs({ -1, 1 }) do
        local nm = "Deco_Pauldron" .. (sx < 0 and "L" or "R")
        Part(model, { Name = nm, Size = Vector3.new(3, 2.2, 3.6), CFrame = M(sx * 3.9, 4.6, 0) * CFrame.Angles(0, 0, math.rad(sx * -18)), Color = SILVER, Material = METAL })
        Part(model, { Name = nm .. "Trim", Size = Vector3.new(3.05, 0.25, 3.65), CFrame = M(sx * 3.9, 3.6, 0) * CFrame.Angles(0, 0, math.rad(sx * -18)), Color = GOLD, Material = METAL })
        Wedge(model, { Name = nm .. "Fin", Size = Vector3.new(0.4, 2.6, 2.4), CFrame = M(sx * 4.6, 6.2, 0.4) * CFrame.Angles(0, 0, math.rad(sx * -26)), Color = OBS, Material = METAL })
        -- arms: upper + gauntlet, both hands on the sword hilt in front
        local sh, hand = Vector3.new(sx * 3.2, 3.8, 0), Vector3.new(sx * 0.6, 0.6, -3.2)
        local mid = (sh + hand) / 2
        Part(model, { Name = "Deco_SwordArm", Size = Vector3.new(1.2, 1.2, (hand - sh).Magnitude), CFrame = base * CFrame.lookAt(mid, hand), Color = OBS, Material = Enum.Material.Slate })
        Part(model, { Name = "Deco_SwordGauntlet", Size = Vector3.new(1.3, 1.3, 1.3), CFrame = M(hand.X, hand.Y, hand.Z), Color = SILVER, Material = METAL })
    end
    -- the greatsword, point down in front of it
    Part(model, { Name = "Deco_SwordHilt", Size = Vector3.new(0.5, 3, 0.5), CFrame = M(0, 1.4, -3.4), Color = GOLD, Material = METAL })
    Part(model, { Name = "Deco_SwordGuard", Size = Vector3.new(4, 0.5, 0.7), CFrame = M(0, -0.2, -3.4), Color = GOLD, Material = METAL })
    Part(model, { Name = "Deco_SwordBlade", Size = Vector3.new(1.2, 13, 0.3), CFrame = M(0, -7, -3.4), Color = SILVER, Material = METAL })
    Part(model, { Name = "Deco_SwordEdge", Size = Vector3.new(0.2, 12.6, 0.32), CFrame = M(0, -7, -3.4), Color = TEAL, Glow = true })
    Wedge(model, { Name = "Deco_SwordTip", Size = Vector3.new(0.3, 1.4, 1.2), CFrame = M(0, -14.2, -3.4) * CFrame.Angles(0, math.rad(90), math.rad(180)), Color = SILVER, Material = METAL })
    -- the helm: a narrow visor slit, a three-gem crown
    Part(model, { Name = "Visor", Size = Vector3.new(1.8, 0.28, 0.12), CFrame = M(0, 6.3, -1.26), Color = TEAL, Glow = true })
    for i = -1, 1 do
        local h = (i == 0) and 3 or 2
        Wedge(model, { Name = "CrownSpike", Size = Vector3.new(0.4, h, 0.9), CFrame = M(i * 0.8, 7.5 + h / 2, -0.3) * CFrame.Angles(0, math.rad(90), math.rad(i * -12)), Color = GOLD, Material = METAL })
        Part(model, { Name = "CrownGem", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, CFrame = M(i * 0.95, 7.9, -0.75), Color = TEAL, Glow = true })
    end
    -- the halo wheel behind it: an outer ring, eight spokes, four sigil gems
    local wc = M(0, 4.5, 2.6)
    for i = 0, 23 do
        local a = i / 24 * math.pi * 2
        Part(model, { Name = "Deco_Wheel", Size = Vector3.new(1.55, 0.35, 0.35), CFrame = wc * CFrame.Angles(0, 0, a) * CFrame.new(0, 6.2, 0), Color = (i % 6 == 0) and GOLD or SILVER, Material = METAL })
    end
    for i = 0, 7 do
        Part(model, { Name = "Deco_Wheel", Size = Vector3.new(0.2, 6, 0.2), CFrame = wc * CFrame.Angles(0, 0, i / 8 * math.pi * 2) * CFrame.new(0, 3, 0), Color = TEAL, Glow = true, Transparency = 0.25 })
    end
    for i = 0, 3 do
        Part(model, { Name = "Deco_WheelGem", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3, CFrame = wc * CFrame.Angles(0, 0, i / 4 * math.pi * 2 + math.pi / 4) * CFrame.new(0, 6.2, 0), Color = TEAL, Glow = true })
    end
    local hem = Part(model, { Name = "Hem", Size = Vector3.new(1, 1, 1), CFrame = M(0, -12, 0), Transparency = 1 })
    Emit(hem, TEAL, 8, 0.6, 2, 1.8)
    Emit(model:FindFirstChild("Torso") or model.PrimaryPart, Color3.fromRGB(220, 255, 250), 8, 0.3, 3, 1.6)
end

-- ===== BIOME SUPERBOSSES v3 (2026-10-05, owner: "The current superbosses are just simple reskins, they need to be unique
-- with distinct mechanics, like destiny") -- five different creatures, not one colossus recoloured. The hit zones (Torso /
-- Core / Head = the weak spot) are laid out per boss by SUPER_HITBOX (DungeonGenerator builds them; the server's stand-in
-- uses the same sizes); SuperBody restyles them and dresses the rest. BossAI animates the Deco_* names (SUPER.<biome>.Animate).
--   Fire  IGNIS, THE FORGE TYRANT  hunched lava titan on its knuckles: Deco_ArmL/R* (shoulder hinge), Deco_Jaw, chimneys
--   Ice   THE FROST SOVEREIGN      a floating ice warden: Deco_ArmL/R* (ice blades), Deco_Gown, Deco_Halo, Deco_Cape
--   Void  THE UNBLINKING           a giant eye: Deco_LidT / Deco_LidB (blink), Deco_Tendril1..6, Deco_Shard, Deco_Halo
--   Cyber OMNISCIENCE CORE         a server core: Deco_Panel1..4 (orbit, open when staggered), Deco_RingA / B
--   Storm TEMPEST SOVEREIGN        a winged storm angel: Deco_WingL/R* (flap), Deco_Tail, CrownTip / WingTip (arcs)
EnemyModels.SUPER_HITBOX = {
    -- Size, Offset (from the pivot; -Z = toward the player), Shape ("Ball" or nil = block)
    Fire = { Torso = { Vector3.new(15, 10, 10), Vector3.new(0, 1, 1) }, Core = { Vector3.new(4.4, 4.4, 4.4), Vector3.new(0, -0.6, -4.5), "Ball" },
        Head = { Vector3.new(4.2, 4, 4.2), Vector3.new(0, 4.4, -5.8) } },
    Ice = { Torso = { Vector3.new(6, 10, 4), Vector3.new(0, 2, 0) }, Core = { Vector3.new(2.6, 2.6, 2.6), Vector3.new(0, 3.2, -2.3), "Ball" },
        Head = { Vector3.new(3, 3.4, 3), Vector3.new(0, 9, 0) } },
    Void = { Torso = { Vector3.new(13, 13, 13), Vector3.new(0, 3, 0), "Ball" }, Core = { Vector3.new(6.4, 6.4, 6.4), Vector3.new(0, 3, -4.4), "Ball" },
        Head = { Vector3.new(3, 3, 3), Vector3.new(0, 3, -6.9), "Ball" } },
    Cyber = { Torso = { Vector3.new(7, 7, 7), Vector3.new(0, 3, 0) }, Core = { Vector3.new(3.4, 3.4, 3.4), Vector3.new(0, 3, -3.7), "Ball" },
        Head = { Vector3.new(2.6, 2.6, 2.6), Vector3.new(0, 8.4, 0), "Ball" } },
    Storm = { Torso = { Vector3.new(5.5, 8, 3.6), Vector3.new(0, 3, 0) }, Core = { Vector3.new(2.6, 2.6, 2.6), Vector3.new(0, 4.2, -2), "Ball" },
        Head = { Vector3.new(2.8, 2.8, 2.8), Vector3.new(0, 8.8, 0) } },
    -- (0.53 NewBiomes) THE SANDMAN: a tall robed figure, an hourglass heart, a crescent-moon head
    Dream = { Torso = { Vector3.new(6, 11, 4), Vector3.new(0, 1.5, 0) }, Core = { Vector3.new(2.8, 2.8, 2.8), Vector3.new(0, 3, -2.2), "Ball" },
        Head = { Vector3.new(3.4, 3.4, 3.4), Vector3.new(0, 9.4, 0), "Ball" } },
    -- HIGHWAY KING: a chrome hot-rod colossus, its engine heart in the grille, the cab its head
    Flats = { Torso = { Vector3.new(12, 6, 9), Vector3.new(0, 0, 0) }, Core = { Vector3.new(3.2, 3.2, 3.2), Vector3.new(0, 1, -4.9), "Ball" },
        Head = { Vector3.new(5, 3, 3.4), Vector3.new(0, 4.6, -1.6) } },
}
EnemyModels.SUPER_COLOR = { Fire = Color3.fromRGB(255, 100, 30), Ice = Color3.fromRGB(140, 210, 255), Void = Color3.fromRGB(170, 80, 255),
    Cyber = Color3.fromRGB(60, 255, 190), Storm = Color3.fromRGB(150, 210, 255), Dream = Color3.fromRGB(255, 150, 230), Flats = Color3.fromRGB(255, 120, 60) }

local function Style(p, color, mat, transp)
    if not p then return end
    p.Color = color; p.Material = mat or SMOOTH; p.Transparency = transp or 0
    if mat == NEON then p:SetAttribute("Glow", true) end
end
local function Chain(model, name, from, to, n, r0, r1, color, mat)
    for i = 0, n - 1 do
        local k = i / math.max(1, n - 1)
        local r = r0 + (r1 - r0) * k
        Part(model, { Name = name, Shape = Enum.PartType.Ball, Size = Vector3.one * r, CFrame = CFrame.new(from:Lerp(to, k)), Color = color, Material = mat })
    end
end

local SUPER_BODIES = {}

function SUPER_BODIES.Fire(model, M, col)
    local ROCK, ROCK2, LAVA = Color3.fromRGB(40, 24, 20), Color3.fromRGB(62, 36, 26), col
    Style(model:FindFirstChild("Torso"), ROCK, Enum.Material.Basalt)
    Style(model:FindFirstChild("Core"), Color3.fromRGB(255, 150, 40), NEON)
    Style(model:FindFirstChild("Head"), ROCK2, Enum.Material.Basalt)
    -- lava cracks across the chest and flanks
    for i, c in ipairs({ { -4, 2.5, -4.05, 30 }, { 3.5, 3, -4.05, -25 }, { -1.5, -2.5, -4.05, 70 }, { 5.6, -1.4, -4.05, 50 }, { -7.55, 1, 0, 80 }, { 7.55, 2, 1, -70 } }) do
        local side = math.abs(c[1]) > 7.5
        Part(model, { Name = "LavaCrack", Size = side and Vector3.new(0.12, 0.35, 5) or Vector3.new(4.5, 0.35, 0.12), CFrame = M(c[1], c[2], c[3]) * CFrame.Angles(side and math.rad(c[4]) or 0, 0, side and 0 or math.rad(c[4])), Color = LAVA, Glow = true })
        local _ = i
    end
    -- the spine: a ridge of rock plates, three chimneys breathing fire on the back
    for k = 0, 4 do
        Wedge(model, { Name = "SpinePlate", Size = Vector3.new(2.2, 3.4 - k * 0.3, 3.2), CFrame = M(0, 7.4 - k * 0.5, -2 + k * 1.9) * CFrame.Angles(math.rad(-20), 0, 0), Color = ROCK2, Material = Enum.Material.Basalt })
    end
    for i, x in ipairs({ -4.2, 0, 4.2 }) do
        local h = (i == 2) and 6 or 4.5
        local ch = Part(model, { Name = "Chimney", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.2, 2.2), CFrame = M(x, 6 + h / 2, 4.2) * CFrame.Angles(0, 0, math.rad(90)), Color = ROCK, Material = Enum.Material.Basalt })
        Part(model, { Name = "ChimneyGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.7, 1.7), CFrame = M(x, 6 + h + 0.05, 4.2) * CFrame.Angles(0, 0, math.rad(90)), Color = LAVA, Glow = true })
        local f = Emit(ch, LAVA, 7, 1.6, 4, 1.0, "rbxasset://textures/particles/fire_main.dds"); f.EmissionDirection = Enum.NormalId.Right; f.SpreadAngle = Vector2.new(15, 15); f.Acceleration = Vector3.new(0, 8, 0)
    end
    -- boulder shoulders with a molten rim
    for _, sx in ipairs({ -1, 1 }) do
        Part(model, { Name = "Pauldron", Size = Vector3.new(6, 5, 7.5), CFrame = M(sx * 8.6, 4.4, 0) * CFrame.Angles(0, 0, math.rad(sx * -14)), Color = ROCK2, Material = Enum.Material.Basalt })
        Part(model, { Name = "PauldronGlow", Size = Vector3.new(6.1, 0.3, 7.6), CFrame = M(sx * 8.6, 2.1, 0) * CFrame.Angles(0, 0, math.rad(sx * -14)), Color = LAVA, Glow = true })
        Wedge(model, { Name = "ShoulderSpike", Size = Vector3.new(1.4, 4, 2.4), CFrame = M(sx * 9.4, 8.4, 0.5) * CFrame.Angles(0, 0, math.rad(sx * -18)), Color = ROCK, Material = Enum.Material.Basalt })
    end
    -- the arms: it walks on its knuckles (gorilla stance); each arm swings from the shoulder as one piece
    for _, sx in ipairs({ -1, 1 }) do
        local nm = "Deco_Arm" .. (sx < 0 and "L" or "R")
        local sh, el, wr = Vector3.new(sx * 9, 3, -0.5), Vector3.new(sx * 11.4, -2, -4.2), Vector3.new(sx * 10.4, -5.6, -7.6)
        local function Lb(a, b, w, c, mat) local mid = (a + b) / 2; return Part(model, { Name = nm, Size = Vector3.new(w, w * 0.9, (b - a).Magnitude), CFrame = M(0, 0, 0) * CFrame.lookAt(mid, b), Color = c, Material = mat }) end
        Lb(sh, el, 3.8, ROCK2, Enum.Material.Basalt)
        Lb(el, wr, 3.4, ROCK, Enum.Material.Basalt)
        Part(model, { Name = nm .. "Glow", Size = Vector3.new(0.3, 0.3, (wr - el).Magnitude * 0.8), CFrame = M(0, 0, 0) * CFrame.lookAt((el + wr) / 2 + Vector3.new(0, 1.7, 0), wr + Vector3.new(0, 1.7, 0)), Color = LAVA, Glow = true })
        Part(model, { Name = nm .. "Fist", Size = Vector3.new(5, 4.4, 5), CFrame = M(sx * 10.2, -7.2, -8.2), Color = ROCK2, Material = Enum.Material.Basalt })
        for f = 0, 3 do
            Part(model, { Name = nm .. "Knuckle", Size = Vector3.new(1, 0.5, 0.2), CFrame = M(sx * 10.2 - 1.5 + f, -6.2, -10.75), Color = LAVA, Glow = true })
        end
        Emit(model:FindFirstChild(nm .. "Fist") or model.PrimaryPart, LAVA, 4, 0.8, 2, 1.0, "rbxasset://textures/particles/fire_main.dds")
        -- stumpy hind legs
        Part(model, { Name = "Leg", Size = Vector3.new(4.6, 5.4, 4.6), CFrame = M(sx * 5, -5.6, 3.6), Color = ROCK, Material = Enum.Material.Basalt })
        Part(model, { Name = "Foot", Size = Vector3.new(5.4, 1.4, 6), CFrame = M(sx * 5, -8.3, 3), Color = ROCK2, Material = Enum.Material.Basalt })
    end
    -- the skull: horns sweeping back, a molten brow, eye slits, a hinged jaw that drops when it breathes fire
    for _, sx in ipairs({ -1, 1 }) do
        Wedge(model, { Name = "Horn", Size = Vector3.new(1.4, 2.2, 6.5), CFrame = M(sx * 2.6, 6.4, -4.6) * CFrame.Angles(math.rad(25), math.rad(sx * 20), 0), Color = Color3.fromRGB(26, 16, 12), Material = Enum.Material.Basalt })
        Part(model, { Name = "EyeSlit", Size = Vector3.new(1.3, 0.35, 0.15), CFrame = M(sx * 1.1, 4.9, -7.95) * CFrame.Angles(0, 0, math.rad(sx * -14)), Color = Color3.fromRGB(255, 220, 120), Glow = true })
    end
    Part(model, { Name = "Brow", Size = Vector3.new(4.8, 0.9, 1.2), CFrame = M(0, 5.9, -7.6), Color = ROCK, Material = Enum.Material.Basalt })
    Part(model, { Name = "Deco_Jaw", Size = Vector3.new(3.8, 1.2, 3.6), CFrame = M(0, 2, -6.2), Color = ROCK2, Material = Enum.Material.Basalt })
    Part(model, { Name = "Deco_JawGlow", Size = Vector3.new(3.2, 0.2, 3), CFrame = M(0, 2.65, -6.2), Color = LAVA, Glow = true })
    Emit(model:FindFirstChild("Torso") or model.PrimaryPart, LAVA, 10, 0.35, 5, 1.6)
end

function SUPER_BODIES.Ice(model, M, col)
    local ICE, FROST, DEEP = Color3.fromRGB(196, 228, 250), Color3.fromRGB(235, 248, 255), Color3.fromRGB(70, 120, 170)
    Style(model:FindFirstChild("Torso"), Color3.fromRGB(120, 170, 210), Enum.Material.Glacier)
    Style(model:FindFirstChild("Core"), Color3.fromRGB(220, 245, 255), NEON)
    Style(model:FindFirstChild("Head"), FROST, Enum.Material.Marble)
    -- breastplate + waist
    for _, sx in ipairs({ -1, 1 }) do
        Wedge(model, { Name = "Breast", Size = Vector3.new(2.8, 4.4, 0.8), CFrame = M(sx * 1.5, 4.8, -2.3) * CFrame.Angles(0, math.rad(180), math.rad(sx * 10)), Color = DEEP, Material = Enum.Material.Glass })
    end
    Part(model, { Name = "Waist", Size = Vector3.new(6.6, 0.6, 4.6), CFrame = M(0, -2.6, 0), Color = col, Glow = true })
    -- the gown: a cone of hanging ice shards (it floats, the hem trails mist)
    for i = 0, 11 do
        local a = i / 12 * math.pi * 2
        local len = 7 + (i % 3) * 1.2
        local cf = M(math.cos(a) * 2.8, -3 - len / 2, math.sin(a) * 2.2) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(-12))
        -- (dark saturated glass: the pale version blew out to glowing white blocks under the Ice light)
        Wedge(model, { Name = "Deco_Gown", Size = Vector3.new(2.4, len, 0.5), CFrame = cf * CFrame.Angles(0, 0, math.rad(180)), Color = (i % 2 == 0) and Color3.fromRGB(60, 110, 160) or Color3.fromRGB(34, 64, 110), Material = Enum.Material.Glass, Transparency = 0.25 })
    end
    local hem = Part(model, { Name = "Hem", Size = Vector3.new(1, 1, 1), CFrame = M(0, -10, 0), Transparency = 1 })
    Emit(hem, FROST, 10, 2.4, 2, 2.2, "rbxasset://textures/particles/smoke_main.dds").LightEmission = 0.2
    -- crystal pauldrons
    for _, sx in ipairs({ -1, 1 }) do
        for k = 0, 2 do
            Part(model, { Name = "ShoulderCrystal", Size = Vector3.new(0.9, 3 + k * 0.9, 0.9), CFrame = M(sx * (3.4 + k * 0.5), 7 + k * 0.4, -0.6 + k * 0.6) * CFrame.Angles(math.rad(-10 + k * 10), 0, math.rad(sx * (-30 - k * 8))) * CFrame.Angles(0, math.rad(45), 0),
                Color = ICE, Material = Enum.Material.Glass, Transparency = 0.1 })
        end
    end
    -- arms ending in long ice blades
    for _, sx in ipairs({ -1, 1 }) do
        local nm = "Deco_Arm" .. (sx < 0 and "L" or "R")
        local sh, el, wr = Vector3.new(sx * 3.6, 5.8, 0), Vector3.new(sx * 5.2, 1.6, -1.4), Vector3.new(sx * 5.6, -1.6, -3.6)
        for _, seg in ipairs({ { sh, el, 1.3 }, { el, wr, 1.1 } }) do
            local mid = (seg[1] + seg[2]) / 2
            Part(model, { Name = nm, Size = Vector3.new(seg[3], seg[3], (seg[2] - seg[1]).Magnitude), CFrame = M(0, 0, 0) * CFrame.lookAt(mid, seg[2]), Color = DEEP, Material = Enum.Material.Glass })
        end
        local tip = wr + Vector3.new(sx * 0.6, -5, -6)
        local mid = (wr + tip) / 2
        Wedge(model, { Name = nm .. "Blade", Size = Vector3.new(0.4, 1.6, (tip - wr).Magnitude), CFrame = M(0, 0, 0) * CFrame.lookAt(mid, tip), Color = FROST, Material = Enum.Material.Glass, Transparency = 0.05 })
        Part(model, { Name = nm .. "Edge", Size = Vector3.new(0.12, 0.12, (tip - wr).Magnitude), CFrame = M(0, 0, 0) * CFrame.lookAt(mid + Vector3.new(0, -0.7, 0), tip + Vector3.new(0, -0.7, 0)), Color = col, Glow = true })
    end
    -- the head: a hood of ice plates, a faceless mask with two cold eyes, a crown of spikes, a halo of icicles behind
    Part(model, { Name = "Mask", Size = Vector3.new(2.6, 2.8, 0.4), CFrame = M(0, 9, -1.55), Color = FROST, Material = Enum.Material.Marble })
    for _, sx in ipairs({ -1, 1 }) do
        Part(model, { Name = "Eye", Size = Vector3.new(0.7, 0.22, 0.1), CFrame = M(sx * 0.6, 9.3, -1.8) * CFrame.Angles(0, 0, math.rad(sx * -10)), Color = col, Glow = true })
        Wedge(model, { Name = "Hood", Size = Vector3.new(0.6, 4.4, 3.6), CFrame = M(sx * 1.7, 9.4, 0.3) * CFrame.Angles(0, 0, math.rad(sx * 12)), Color = DEEP, Material = Enum.Material.Glass })
    end
    for i = -3, 3 do
        Part(model, { Name = "Crown", Size = Vector3.new(0.5, 2.6 - math.abs(i) * 0.4 + ((i == 0) and 1.4 or 0), 0.5), CFrame = M(i * 0.45, 11.6 + ((i == 0) and 0.7 or 0) - math.abs(i) * 0.2, -0.2) * CFrame.Angles(0, math.rad(45), math.rad(-i * 8)),
            Color = ICE, Material = Enum.Material.Glass })
    end
    for i = 0, 11 do
        local a = i / 12 * math.pi * 2
        Part(model, { Name = "Deco_Halo", Size = Vector3.new(0.35, (i % 2 == 0) and 2.2 or 1.4, 0.35), CFrame = M(math.cos(a) * 4, 9.4 + math.sin(a) * 4, 1.8) * CFrame.Angles(0, 0, a - math.pi / 2),
            Color = (i % 3 == 0) and col or ICE, Glow = (i % 3 == 0) or nil, Material = Enum.Material.Glass })
    end
    -- a frozen cape: three translucent panels behind
    for k = -1, 1 do
        Part(model, { Name = "Deco_Cape", Size = Vector3.new(2.4, 12, 0.2), CFrame = M(k * 2.1, 1, 2.4 + math.abs(k) * 0.3) * CFrame.Angles(math.rad(8), math.rad(k * 14), 0), Color = ICE, Material = Enum.Material.Glass, Transparency = 0.45 })
    end
    Emit(model:FindFirstChild("Torso") or model.PrimaryPart, FROST, 12, 0.5, 3, 2.2)
end

function SUPER_BODIES.Void(model, M, col)
    local OBS, DEEP = Color3.fromRGB(16, 8, 26), Color3.fromRGB(44, 18, 70)
    Style(model:FindFirstChild("Torso"), Color3.fromRGB(30, 18, 44), Enum.Material.Glass)
    Style(model:FindFirstChild("Core"), col, NEON)
    Style(model:FindFirstChild("Head"), Color3.fromRGB(8, 2, 14), SMOOTH)
    local eye = M(0, 3, 0)
    -- a white glint in the pupil, a bright iris rim, veins over the eyeball
    Part(model, { Name = "Glint", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, CFrame = eye * CFrame.new(0.7, 0.7, -8.3), Color = Color3.new(1, 1, 1), Glow = true })
    Part(model, { Name = "IrisRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 7.2, 7.2), CFrame = eye * CFrame.new(0, 0, -5.4) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(230, 170, 255), Glow = true, Transparency = 0.2 })
    for i = 0, 9 do
        local a = i / 10 * math.pi * 2
        local p0 = Vector3.new(math.cos(a) * 3.6, math.sin(a) * 3.6, -5.5)
        local p1 = Vector3.new(math.cos(a + 0.4) * 6.1, math.sin(a + 0.4) * 6.1, -1.6)
        Part(model, { Name = "Vein", Size = Vector3.new(0.18, 0.18, (p1 - p0).Magnitude), CFrame = eye * CFrame.lookAt((p0 + p1) / 2, p1), Color = col, Glow = true, Transparency = 0.25 })
    end
    -- the lids: a brow arc above and a cheek arc below, each a fan of obsidian slabs (BossAI blinks them)
    for _, lid in ipairs({ { "Deco_LidT", 1 }, { "Deco_LidB", -1 } }) do
        for k = -3, 3 do
            local a = k * 0.32
            local cf = eye * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(lid[2] * 38), 0, 0) * CFrame.new(0, 0, -7)
            Part(model, { Name = lid[1], Size = Vector3.new(2.9, 0.7, 2.6), CFrame = cf, Color = OBS, Material = Enum.Material.Slate })
            Part(model, { Name = lid[1] .. "Edge", Size = Vector3.new(2.95, 0.15, 0.15), CFrame = cf * CFrame.new(0, -lid[2] * 0.35, -1.25), Color = col, Glow = true })
        end
    end
    -- tendrils trailing beneath
    for i = 1, 6 do
        local a = i / 6 * math.pi * 2
        local from = Vector3.new(math.cos(a) * 4, -2.4, math.sin(a) * 3 + 1.5)
        local to = from + Vector3.new(math.cos(a) * 3, -9, math.sin(a) * 2 + 2)
        Chain(model, "Deco_Tendril" .. i, from, to, 7, 1.6, 0.5, (i % 2 == 0) and DEEP or OBS, Enum.Material.Slate)
        for _, p in ipairs(model:GetChildren()) do if p.Name == "Deco_Tendril" .. i then p.CFrame = M(0, 0, 0) * p.CFrame end end
        Part(model, { Name = "Deco_Tendril" .. i .. "Tip", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.7, CFrame = M(to.X, to.Y - 0.4, to.Z), Color = col, Glow = true })
    end
    -- obsidian shards orbiting, a ring of runes behind
    for i = 0, 7 do
        local a = i / 8 * math.pi * 2
        Wedge(model, { Name = "Deco_Shard", Size = Vector3.new(1.4, 4.6, 1.8), CFrame = M(math.cos(a) * 11, 3 + math.sin(a * 2) * 2.4, math.sin(a) * 11) * CFrame.Angles(0.5, a, 0.3), Color = (i % 2 == 0) and OBS or DEEP, Material = Enum.Material.Glass })
    end
    for i = 0, 15 do
        local a = i / 16 * math.pi * 2
        Part(model, { Name = "Deco_Halo", Size = Vector3.new(1.4, 0.35, 0.35), CFrame = M(math.cos(a) * 9.5, 3 + math.sin(a) * 9.5, 5) * CFrame.Angles(0, 0, a + math.pi / 2), Color = col, Glow = (i % 2 == 0) or nil, Material = Enum.Material.Glass, Transparency = (i % 2 == 0) and 0.1 or 0.4 })
    end
    Emit(model:FindFirstChild("Torso") or model.PrimaryPart, col, 12, 2, 2, 2.2, "rbxasset://textures/particles/smoke_main.dds")
end

function SUPER_BODIES.Cyber(model, M, col)
    local STEEL, DARK = Color3.fromRGB(56, 62, 74), Color3.fromRGB(22, 26, 32)
    Style(model:FindFirstChild("Torso"), DARK, Enum.Material.DiamondPlate)
    Style(model:FindFirstChild("Core"), col, NEON)
    Style(model:FindFirstChild("Head"), Color3.fromRGB(255, 80, 120), NEON)
    -- the core cube's trim: glowing edges + a lens housing
    for _, e in ipairs({ { 0, 6.55, 0, 7.2, 0.25, 0.25 }, { 0, -0.55, 0, 7.2, 0.25, 0.25 } }) do
        for _, sz in ipairs({ -1, 1 }) do
            Part(model, { Name = "CoreEdge", Size = Vector3.new(e[4], e[5], e[6]), CFrame = M(0, e[2], sz * 3.55), Color = col, Glow = true })
            Part(model, { Name = "CoreEdge", Size = Vector3.new(e[6], e[5], e[4]), CFrame = M(sz * 3.55, e[2], 0), Color = col, Glow = true })
        end
    end
    Part(model, { Name = "LensHousing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 5, 5), CFrame = M(0, 3, -3.6) * CFrame.Angles(0, math.rad(90), 0), Color = STEEL, Material = METAL })
    Part(model, { Name = "Mast", Size = Vector3.new(0.6, 2.6, 0.6), CFrame = M(0, 7.6, 0), Color = STEEL, Material = METAL })
    -- four armoured server panels round it (they orbit; split open when it crashes)
    for i = 1, 4 do
        local a = math.rad(45 + (i - 1) * 90)
        local cf = M(math.cos(a) * 7.2, 3, math.sin(a) * 7.2) * CFrame.Angles(0, -a + math.pi / 2, 0)
        Part(model, { Name = "Deco_Panel" .. i, Size = Vector3.new(7, 12, 1), CFrame = cf, Color = STEEL, Material = Enum.Material.DiamondPlate })
        for r = 0, 4 do
            Part(model, { Name = "Deco_Panel" .. i .. "Led", Size = Vector3.new(5.6, 0.2, 0.15), CFrame = cf * CFrame.new(0, -4.4 + r * 2.2, -0.55), Color = (r % 2 == 0) and col or Color3.fromRGB(255, 80, 120), Glow = true, Transparency = (r % 2 == 0) and 0 or 0.3 })
        end
        Part(model, { Name = "Deco_Panel" .. i .. "Cap", Size = Vector3.new(7.4, 0.6, 1.4), CFrame = cf * CFrame.new(0, 6.3, 0), Color = DARK, Material = METAL })
    end
    -- two holo rings
    for r, spec in ipairs({ { "Deco_RingA", 10.5, 1, 20 }, { "Deco_RingB", 12, 4.5, 24 } }) do
        local name, rad, y, n = spec[1], spec[2], spec[3], spec[4]
        local chord = 2 * math.pi * rad / n * 0.55
        for i = 0, n - 1 do
            local a = i / n * math.pi * 2
            Part(model, { Name = name, Size = Vector3.new(chord, 0.25, 0.4), CFrame = M(0, y, 0) * CFrame.Angles(math.rad(r == 1 and 12 or -8), 0, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, rad),
                Color = (r == 1) and col or Color3.fromRGB(255, 80, 120), Glow = true, Transparency = (i % 4 == 0) and 0 or 0.45 })
        end
    end
    -- the projector it floats on + a beam to the floor, cables hanging off the cube
    Part(model, { Name = "Projector", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 6, 6), CFrame = M(0, -1.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STEEL, Material = METAL })
    Part(model, { Name = "ProjectorBeam", Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 4.6, 4.6), CFrame = M(0, -5.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = col, Glow = true, Transparency = 0.82 })
    for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
        Chain(model, "Cable", Vector3.new(c[1] * 3.2, -0.6, c[2] * 3.2), Vector3.new(c[1] * 4.8, -6.5, c[2] * 4.8), 6, 0.6, 0.45, DARK, SMOOTH)
    end
    for _, p in ipairs(model:GetChildren()) do if p.Name == "Cable" then p.CFrame = M(0, 0, 0) * p.CFrame end end
    Emit(model:FindFirstChild("Core") or model.PrimaryPart, col, 10, 0.4, 5, 1.0)
end

function SUPER_BODIES.Storm(model, M, col)
    local MARBLE, COPPER, CLOUD = Color3.fromRGB(220, 220, 214), Color3.fromRGB(176, 106, 58), Color3.fromRGB(86, 92, 108)
    Style(model:FindFirstChild("Torso"), MARBLE, Enum.Material.Marble)
    Style(model:FindFirstChild("Core"), Color3.fromRGB(215, 235, 255), NEON)
    Style(model:FindFirstChild("Head"), MARBLE, Enum.Material.Marble)
    Part(model, { Name = "Deco_HeartGlow", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.4, CFrame = M(0, 4.2, -2), Color = col, Glow = true, Transparency = 0.6 })
    -- copper breastplate ribs, a storm-cloud mantle round the shoulders
    for k = 0, 3 do
        Part(model, { Name = "Rib", Size = Vector3.new(5.7, 0.3, 0.3), CFrame = M(0, 1.4 + k * 1.1, -1.85), Color = COPPER, Material = METAL })
    end
    for i = 0, 8 do
        local a = i / 9 * math.pi * 2
        Part(model, { Name = "StormCloud", Shape = Enum.PartType.Ball, Size = Vector3.new(3.6, 2.6, 3.6), CFrame = M(math.cos(a) * 3.4, 7.2 + (i % 2) * 0.6, math.sin(a) * 2.6), Color = CLOUD, Material = SMOOTH, Transparency = 0.15 })
    end
    -- helm with a crown of copper lightning rods
    Part(model, { Name = "Visor", Size = Vector3.new(2.4, 0.4, 0.2), CFrame = M(0, 9, -1.45), Color = col, Glow = true })
    for i = -1, 1 do
        local h = 4 + ((i == 0) and 2 or 0)
        Part(model, { Name = "CrownRod", Size = Vector3.new(0.4, h, 0.4), CFrame = M(i * 1.4, 10.2 + h / 2, 0.2) * CFrame.Angles(0, 0, math.rad(i * -16)), Color = COPPER, Material = METAL })
        Part(model, { Name = "CrownTip", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, CFrame = M(i * (1.4 + h * 0.28), 10.2 + h, 0.2), Color = col, Glow = true })
    end
    -- the wings: five feathered blades a side fanning up and out from the shoulder blades, copper spines, glowing edges
    for _, sx in ipairs({ -1, 1 }) do
        local nm = "Deco_Wing" .. (sx < 0 and "L" or "R")
        local root = Vector3.new(sx * 2.4, 6, 1.6)
        for f = 0, 4 do
            local ang = math.rad(18 + f * 22)
            local len = 13 - f * 1.4
            local dir = Vector3.new(sx * math.cos(ang), math.sin(ang), 0.25)
            local tip = root + dir.Unit * len
            local mid = (root + tip) / 2
            local cf = M(0, 0, 0) * CFrame.lookAt(mid, tip)
            Part(model, { Name = nm, Size = Vector3.new(0.3, 2.6 - f * 0.25, len), CFrame = cf * CFrame.new(0, -0.8, 0), Color = MARBLE, Material = Enum.Material.Marble })
            Part(model, { Name = nm .. "Spine", Size = Vector3.new(0.35, 0.35, len), CFrame = cf, Color = COPPER, Material = METAL })
            Part(model, { Name = nm .. "Edge", Size = Vector3.new(0.2, 0.18, len * 0.9), CFrame = cf * CFrame.new(0, -2.1 + f * 0.12, 0), Color = col, Glow = true, Transparency = 0.2 })
            if f == 1 or f == 3 then Part(model, { Name = nm .. "Tip", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.7, CFrame = M(tip.X, tip.Y, tip.Z), Color = col, Glow = true }) end
        end
    end
    -- a spear of lightning in its right hand, the left open
    for _, sx in ipairs({ -1, 1 }) do
        local sh, hand = Vector3.new(sx * 3.3, 5.8, 0), Vector3.new(sx * 4.6, 1.2, -1.8)
        local mid = (sh + hand) / 2
        Part(model, { Name = "Arm", Size = Vector3.new(1.1, 1.1, (hand - sh).Magnitude), CFrame = M(0, 0, 0) * CFrame.lookAt(mid, hand), Color = MARBLE, Material = Enum.Material.Marble })
        Part(model, { Name = "Bracer", Size = Vector3.new(1.3, 1.3, 1.6), CFrame = M(hand.X, hand.Y + 0.6, hand.Z + 0.3), Color = COPPER, Material = METAL })
    end
    Part(model, { Name = "Deco_Spear", Size = Vector3.new(0.3, 0.3, 16), CFrame = M(4.6, 1.4, -1.8) * CFrame.Angles(math.rad(70), 0, 0), Color = Color3.fromRGB(215, 235, 255), Glow = true })
    Wedge(model, { Name = "Deco_SpearHead", Size = Vector3.new(0.3, 1.4, 2.4), CFrame = M(4.6, 9, -4.6) * CFrame.Angles(math.rad(70), 0, 0), Color = col, Glow = true })
    -- below the waist it IS the storm: a zig-zag tail of lightning
    local prev = Vector3.new(0, -1, 0.3)
    for k = 1, 6 do
        local nxt = Vector3.new(((k % 2 == 0) and 1 or -1) * (1.6 - k * 0.15), -1 - k * 1.5, 0.3 + k * 0.4)
        Part(model, { Name = "Deco_Tail", Size = Vector3.new(0.5 - k * 0.05, 0.5 - k * 0.05, (nxt - prev).Magnitude), CFrame = M(0, 0, 0) * CFrame.lookAt((prev + nxt) / 2, nxt), Color = Color3.fromRGB(215, 235, 255), Glow = true })
        prev = nxt
    end
    local sparks = Emit(model:FindFirstChild("Torso") or model.PrimaryPart, col, 14, 0.25, 9, 1.0)
    sparks.SpreadAngle = Vector2.new(180, 180)
end

-- THE SANDMAN (Dreamscape): a towering robed dream-giver floating over the floor -- layered robes that billow (Deco_Robe),
-- sleeves of falling sand, a crescent moon for a face, an hourglass in its chest, stars orbiting it (Deco_Star), a
-- sack of dreams over its shoulder
function SUPER_BODIES.Dream(model, M, col)
    local ROBE, ROBE2, GOLD, PEARL = Color3.fromRGB(60, 46, 110), Color3.fromRGB(96, 70, 150), Color3.fromRGB(255, 210, 120), Color3.fromRGB(250, 240, 255)
    Style(model:FindFirstChild("Torso"), ROBE, Enum.Material.Fabric)
    Style(model:FindFirstChild("Core"), Color3.fromRGB(255, 220, 150), NEON)
    Style(model:FindFirstChild("Head"), PEARL, SMOOTH)
    -- the moon face: a dark disc biting the head into a crescent, a sleepy closed eye, a nightcap
    Part(model, { Name = "MoonShade", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.3, CFrame = M(0.9, 9.8, -0.6), Color = ROBE, Material = SMOOTH })
    Part(model, { Name = "Eye", Size = Vector3.new(0.9, 0.18, 0.2), CFrame = M(-0.7, 9.6, -1.6) * CFrame.Angles(0, 0, math.rad(-10)), Color = col, Glow = true })
    Wedge(model, { Name = "Nightcap", Size = Vector3.new(3, 4, 3), CFrame = M(0, 12.4, 0.6) * CFrame.Angles(math.rad(-30), 0, 0), Color = ROBE2, Material = Enum.Material.Fabric })
    Part(model, { Name = "Pompom", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = M(0, 13.8, 2.6), Color = col, Glow = true })
    -- the hourglass frame round the heart
    for _, y in ipairs({ -1.4, 1.4 }) do Part(model, { Name = "GlassCap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 3.2, 3.2), CFrame = M(0, 3 + y, -2.2) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = METAL }) end
    for k = 0, 3 do
        local a = k / 4 * math.pi * 2 + math.pi / 4
        Part(model, { Name = "GlassPost", Size = Vector3.new(0.25, 3, 0.25), CFrame = M(math.cos(a) * 1.4, 3, -2.2 + math.sin(a) * 1.4), Color = GOLD, Material = METAL })
    end
    -- a flared bell of robes: stacked widening drums, then ragged panels flaring out to a glowing hem that billows
    for k = 0, 2 do
        Part(model, { Name = "RobeBell", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 7 + k * 2.2, 7 + k * 2.2), CFrame = M(0, -3.6 - k * 2.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
            Color = (k % 2 == 0) and ROBE or ROBE2, Material = Enum.Material.Fabric })
    end
    for i = 0, 11 do
        local a = i / 12 * math.pi * 2
        local len = 5 + (i % 3) * 0.9
        Wedge(model, { Name = "Deco_Robe", Size = Vector3.new(0.2, len, 2.9), Material = Enum.Material.Fabric, Color = (i % 2 == 0) and ROBE or ROBE2,
            CFrame = M(0, -9.6 - len / 2 + 1.4, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 5.4) * CFrame.Angles(math.rad(200), 0, 0) })
        Part(model, { Name = "Deco_RobeHem", Size = Vector3.new(2.8, 0.25, 0.25), CFrame = M(0, -9.6 - len + 1.6, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 5.4 + len * 0.34), Color = col, Glow = true })
    end
    Part(model, { Name = "Sash", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 6.6, 6.6), CFrame = M(0, -2.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = METAL })
    -- sleeves that pour sand, the left holding a sack of dreams over the shoulder
    for _, sx in ipairs({ -1, 1 }) do
        local sh, hand = Vector3.new(sx * 3.4, 6.2, 0), Vector3.new(sx * 5.2, 2.2, -1.6)
        local mid = (sh + hand) / 2
        Wedge(model, { Name = "Sleeve", Size = Vector3.new(2.2, 2.0, (hand - sh).Magnitude), CFrame = M(0, 0, 0) * CFrame.lookAt(mid, hand), Color = ROBE2, Material = Enum.Material.Fabric })
        local sand = Part(model, { Name = "SandFall", Size = Vector3.new(0.6, 0.6, 0.6), CFrame = M(hand.X, hand.Y - 0.5, hand.Z), Transparency = 1 })
        local pe = Emit(sand, GOLD, 14, 0.25, 4, 1.2)
        pe.EmissionDirection = Enum.NormalId.Bottom; pe.Acceleration = Vector3.new(0, -12, 0)
    end
    Part(model, { Name = "Sack", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4.6, 3.6), CFrame = M(-3.2, 8.4, 2.4), Color = Color3.fromRGB(150, 110, 190), Material = Enum.Material.Fabric })
    Part(model, { Name = "SackGlow", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = M(-3.2, 10.6, 2.0), Color = col, Glow = true })
    -- stars circling it (Deco_Star) + a wide halo of soft light
    for i = 0, 5 do
        local a = i / 6 * math.pi * 2
        Part(model, { Name = "Deco_Star", Size = Vector3.new(1.2, 1.2, 0.3), CFrame = M(math.cos(a) * 9, 4 + (i % 2) * 3, math.sin(a) * 9) * CFrame.Angles(0, 0, math.rad(45)), Color = (i % 2 == 0) and GOLD or col, Glow = true })
    end
    Emit(model:FindFirstChild("Torso") or model.PrimaryPart, col, 6, 0.4, 1.5, 2.2)
end

-- HIGHWAY KING (Neon Flats): a chrome hot-rod colossus -- a long chrome body on four fat wheels (Deco_Wheel*), a grille
-- face with headlight eyes (the cab is its head), a supercharger on the hood with a spinning blower (Deco_Blower),
-- flaming exhaust stacks, neon underglow, fins and a crown of roof lights
function SUPER_BODIES.Flats(model, M, col)
    local CHROME, PAINT, DARK, MAG = Color3.fromRGB(200, 204, 214), Color3.fromRGB(150, 30, 70), Color3.fromRGB(24, 20, 28), Color3.fromRGB(255, 70, 170)
    Style(model:FindFirstChild("Torso"), PAINT, METAL)
    Style(model:FindFirstChild("Core"), Color3.fromRGB(255, 200, 90), NEON)
    Style(model:FindFirstChild("Head"), DARK, Enum.Material.Glass)
    -- chrome bumpers + grille bars over the engine heart, headlight eyes
    Part(model, { Name = "Bumper", Size = Vector3.new(12.6, 1.2, 1.2), CFrame = M(0, -2.2, -4.9), Color = CHROME, Material = METAL, Reflectance = 0.35 })
    for i = -3, 3 do
        if i ~= 0 then Part(model, { Name = "Grille", Size = Vector3.new(0.3, 3, 0.3), CFrame = M(i * 1.0, 1, -4.75), Color = CHROME, Material = METAL, Reflectance = 0.35 }) end
    end
    for _, sx in ipairs({ -1, 1 }) do
        Part(model, { Name = "Headlight", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.8, 1.8), CFrame = M(sx * 4.6, 1.2, -4.65) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 250, 220), Glow = true })
    end
    -- the cab's visor + roof lights crown
    Part(model, { Name = "Visor", Size = Vector3.new(4.6, 0.5, 0.2), CFrame = M(0, 5, -3.35), Color = col, Glow = true })
    for i = -2, 2 do Part(model, { Name = "RoofLight", Size = Vector3.new(0.6, 0.5, 0.6), CFrame = M(i * 1.0, 6.4, -1.6), Color = (i % 2 == 0) and MAG or Color3.fromRGB(255, 220, 90), Glow = true }) end
    -- the supercharger on the hood with its spinning blower, flaming exhaust stacks along the sides
    Part(model, { Name = "Blower", Size = Vector3.new(3.2, 2, 2.4), CFrame = M(0, 4, -3.4), Color = CHROME, Material = METAL, Reflectance = 0.35 })
    Part(model, { Name = "Deco_Blower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 2.4, 2.4), CFrame = M(0, 5.2, -3.4) * CFrame.Angles(0, 0, math.rad(90)), Color = DARK, Material = METAL })
    for _, sx in ipairs({ -1, 1 }) do
        for k = 0, 2 do
            local st = Part(model, { Name = "Stack", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 0.8, 0.8), CFrame = M(sx * 6.4, 2.2, -1.5 + k * 2) * CFrame.Angles(0, 0, math.rad(90)), Color = CHROME, Material = METAL, Reflectance = 0.3 })
            if k == 1 then
                local fl = Emit(st, Color3.fromRGB(255, 140, 60), 10, 0.8, 6, 0.4, "rbxasset://textures/particles/fire_main.dds")
                fl.EmissionDirection = Enum.NormalId.Right; fl.SpreadAngle = Vector2.new(8, 8)
            end
        end
        -- tail fins + a stripe
        Wedge(model, { Name = "TailFin", Size = Vector3.new(0.4, 3, 4), CFrame = M(sx * 5, 3.6, 4.2), Color = PAINT, Material = METAL })
        Part(model, { Name = "Stripe", Size = Vector3.new(0.1, 0.5, 9), CFrame = M(sx * 6.05, 0.6, 0), Color = Color3.fromRGB(255, 220, 90), Material = SMOOTH })
    end
    -- four fat wheels with glowing hubs, and the underglow
    for _, sx in ipairs({ -1, 1 }) do
        for _, sz in ipairs({ -1, 1 }) do
            local side = (sx < 0 and "L" or "R") .. (sz < 0 and "F" or "B")
            local c = M(sx * 6.4, -2.6, sz * 3.4)
            Part(model, { Name = "Deco_Wheel" .. side, Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 4.4, 4.4), CFrame = c, Color = DARK, Material = Enum.Material.Rubber })
            Part(model, { Name = "Deco_Wheel" .. side .. "Hub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.3, 2.0, 2.0), CFrame = c, Color = CHROME, Material = METAL, Reflectance = 0.35 })
            Part(model, { Name = "Deco_Wheel" .. side .. "Spoke", Size = Vector3.new(2.35, 0.4, 3.8), CFrame = c, Color = MAG, Glow = true })
        end
    end
    Part(model, { Name = "Underglow", Size = Vector3.new(11, 0.2, 8.4), CFrame = M(0, -3.2, 0), Color = MAG, Glow = true, Transparency = 0.3 })
end

function EnemyModels.SuperBody(model, biome, base)
    local f = SUPER_BODIES[biome] or SUPER_BODIES.Fire
    local function M(x, y, z) return base * CFrame.new(x, y, z) end
    f(model, M, EnemyModels.SUPER_COLOR[biome] or EnemyModels.SUPER_COLOR.Fire)
end

-- BOSS LOOK v2 (2026-10-13 pilot: Phantom, Ignis, Duelist -- AimRngShared/BossLook, docs/BOSSES_LOOK.md): a boss whose
-- switch is on and whose kit is in the place wears the pill-family look; otherwise the old dress below
function EnemyModels.TryLook(model, key, pos)
    local ok, BL = pcall(require, script.Parent:WaitForChild("BossLook", 5))
    if not (ok and BL) then return false end
    local done, res = pcall(BL.Build, model, key, pos)
    if not done then warn("[BossLook] " .. tostring(key) .. ": " .. tostring(res)) end
    return done and res == true
end

function EnemyModels.DecorateBoss(model, kind, pos, biome)
    if EnemyModels.TryLook(model, (kind == "SuperBoss") and ("Super" .. tostring(biome)) or kind, pos) then return end
    local base = CFrame.new(pos)
    local torso = model:FindFirstChild("Torso")
    local T = torso and torso.Size or Vector3.new(6, 6, 6)
    local function M(x, y, z) return base * CFrame.new(x, y, z) end
    local function Limb(name, a, b, w, h, color, mat, glow)
        local c = (a + b) / 2
        return Part(model, { Name = name, Size = Vector3.new(w, h, (b - a).Magnitude), CFrame = base * CFrame.lookAt(c, b), Color = color, Material = mat or METAL, Glow = glow })
    end
    local DARK = Color3.fromRGB(26, 28, 34)
    if kind == "Goliath" then
        -- GOLIATH (v2): a tracked siege juggernaut. Road wheels turn as it drives (Deco_WheelL / R), the triple ram
        -- punches forward on a charge (Deco_Ram), exhaust stacks breathe fire. Torso / Core (back) / Head stay the hitboxes.
        local col = Color3.fromRGB(255, 140, 30)
        local HAZ = Color3.fromRGB(255, 190, 40)
        -- tracks
        for _, sx in ipairs({ -1, 1 }) do
            local side = sx < 0 and "L" or "R"
            local tx = sx * (T.X / 2 + 1.0)
            Part(model, { Name = "Track", Size = Vector3.new(1.9, 2.2, T.Z + 2.6), CFrame = M(tx, -T.Y / 2 - 0.15, 0), Color = DARK, Material = Enum.Material.Slate })
            for k = 0, 6 do
                Part(model, { Name = "TrackCleat", Size = Vector3.new(1.95, 0.25, 0.35), CFrame = M(tx, -T.Y / 2 + 0.98, -T.Z / 2 - 1.0 + k * (T.Z + 2) / 6), Color = ARMOR_LIGHT, Material = METAL })
            end
            for k = 0, 3 do
                Part(model, { Name = "Deco_Wheel" .. side, Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.05, 1.7, 1.7), Color = ARMOR_LIGHT, Material = METAL,
                    CFrame = M(tx, -T.Y / 2 - 0.15, -T.Z / 2 + 0.3 + k * (T.Z - 0.6) / 3) })
                Part(model, { Name = "Deco_Wheel" .. side .. "Hub", Size = Vector3.new(2.1, 0.35, 1.2), Color = col, Glow = true,
                    CFrame = M(tx, -T.Y / 2 - 0.15, -T.Z / 2 + 0.3 + k * (T.Z - 0.6) / 3) })
            end
            Part(model, { Name = "Fender", Size = Vector3.new(2.4, 0.4, T.Z + 3.0), CFrame = M(tx, -T.Y / 2 + 1.35, 0), Color = ARMOR, Material = METAL })
            Part(model, { Name = "FenderTrim", Size = Vector3.new(0.12, 0.42, T.Z + 3.0), CFrame = M(tx + sx * 1.22, -T.Y / 2 + 1.35, 0), Color = HAZ, Material = SMOOTH })
        end
        -- glacis + the triple ram under the shield
        Wedge(model, { Name = "Glacis", Size = Vector3.new(T.X * 0.95, T.Y * 0.55, 2.0), CFrame = M(0, -T.Y * 0.2, -T.Z / 2 - 1.0) * CFrame.Angles(0, math.rad(180), 0), Color = ARMOR_LIGHT })
        for i = -1, 1 do
            Wedge(model, { Name = "Deco_Ram", Size = Vector3.new(1.3, 1.5, 2.6), CFrame = M(i * 2.3, -T.Y / 2 + 0.6, -T.Z / 2 - 2.4) * CFrame.Angles(0, math.rad(180), 0), Color = Color3.fromRGB(200, 205, 215), Material = METAL })
            Part(model, { Name = "Deco_RamGlow", Size = Vector3.new(1.32, 0.15, 2.0), CFrame = M(i * 2.3, -T.Y / 2 + 0.05, -T.Z / 2 - 2.2), Color = col, Glow = true })
        end
        -- hydraulic arms holding the shield
        for _, sx in ipairs({ -1, 1 }) do
            Limb("ShieldArm", Vector3.new(sx * T.X * 0.42, T.Y * 0.2, -T.Z * 0.3), Vector3.new(sx * T.X * 0.55, 0.2, -T.Z / 2 - 0.8), 0.7, 0.7, ARMOR_LIGHT)
            Limb("ShieldPiston", Vector3.new(sx * T.X * 0.42, -T.Y * 0.1, -T.Z * 0.3), Vector3.new(sx * T.X * 0.55, -0.6, -T.Z / 2 - 0.8), 0.35, 0.35, Color3.fromRGB(170, 175, 185))
        end
        -- turret dome + visor band + brow over the head bar
        Part(model, { Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(T.X * 0.7, T.Y * 0.55, T.Z * 0.7), CFrame = M(0, T.Y / 2 + 0.2, 0.4), Color = ARMOR, Material = METAL })
        Part(model, { Name = "Deco_GlowBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, T.X * 0.72, T.X * 0.72), CFrame = M(0, T.Y / 2 + 0.3, 0.4) * CFrame.Angles(0, 0, math.rad(90)), Color = col, Glow = true })
        Wedge(model, { Name = "Brow", Size = Vector3.new(4.2, 0.7, 1.6), CFrame = M(0, 3.45, -3.0) * CFrame.Angles(0, math.rad(180), 0), Color = ARMOR, Material = METAL })
        -- spine spikes
        for k = -1, 1 do
            Wedge(model, { Name = "Spike", Size = Vector3.new(0.5, 1.4, 1.2), CFrame = M(0, T.Y / 2 + 1.6, 1.2 + k * 1.2), Color = Color3.fromRGB(200, 205, 215), Material = METAL })
        end
        -- the back core cage (its weak spot -- flank it)
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            Part(model, { Name = "CageBar", Size = Vector3.new(0.35, 0.35, 2.4), Color = ARMOR_LIGHT, Material = METAL,
                CFrame = M(0, 0.5, 3.2) * CFrame.Angles(0, 0, a) * CFrame.new(0, 1.65, 0.3) })
        end
        Ring(model, M(0, 0.5, 4.4) * CFrame.Angles(0, math.rad(90), 0), 3.6, 0.3, col, true)
        -- exhaust stacks that breathe fire
        for _, sx in ipairs({ -1, 1 }) do
            local st = Part(model, { Name = "Stack", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 1.0, 1.0), CFrame = M(sx * T.X * 0.34, T.Y * 0.45, T.Z / 2 + 0.4) * CFrame.Angles(0, 0, math.rad(90)), Color = ARMOR, Material = METAL })
            local fl = Emit(st, col, 12, 0.9, 6, 0.5, "rbxasset://textures/particles/fire_main.dds")
            fl.EmissionDirection = Enum.NormalId.Right; fl.SpreadAngle = Vector2.new(8, 8); fl.Acceleration = Vector3.new(0, 5, 0)
        end
        -- (0.53 detail pass) the main gun: a long barrel off the dome with a muzzle brake and a glowing bore
        Part(model, { Name = "Mantlet", Size = Vector3.new(2.2, 1.4, 1.4), CFrame = M(0, T.Y / 2 + 0.4, -T.Z * 0.3), Color = ARMOR_LIGHT, Material = METAL })
        Part(model, { Name = "MainGun", Shape = Enum.PartType.Cylinder, Size = Vector3.new(T.Z * 0.9, 0.75, 0.75), CFrame = M(0, T.Y / 2 + 0.45, -T.Z * 0.3 - T.Z * 0.45) * CFrame.Angles(0, math.rad(90), 0), Color = ARMOR, Material = METAL })
        Part(model, { Name = "MuzzleBrake", Size = Vector3.new(1.1, 0.9, 1.0), CFrame = M(0, T.Y / 2 + 0.45, -T.Z * 0.3 - T.Z * 0.9), Color = ARMOR_LIGHT, Material = METAL })
        Part(model, { Name = "Bore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.5, 0.5), CFrame = M(0, T.Y / 2 + 0.45, -T.Z * 0.3 - T.Z * 0.9 - 0.52) * CFrame.Angles(0, math.rad(90), 0), Color = col, Glow = true })
        -- hull plating: raised plates with glowing seams between them, rivet rows
        for _, sx in ipairs({ -1, 1 }) do
            for k = -1, 1 do
                Part(model, { Name = "HullPlate", Size = Vector3.new(0.3, T.Y * 0.38, T.Z * 0.3), CFrame = M(sx * (T.X / 2 + 0.16), T.Y * 0.12, k * T.Z * 0.33), Color = ARMOR_LIGHT, Material = METAL })
            end
            Part(model, { Name = "Vein", Size = Vector3.new(0.1, 0.1, T.Z * 0.95), CFrame = M(sx * (T.X / 2 + 0.33), -T.Y * 0.1, 0), Color = col, Glow = true })
        end
        for i = -1, 1, 2 do
            Part(model, { Name = "Chevron", Size = Vector3.new(T.X * 0.18, 0.5, 0.1), CFrame = M(i * T.X * 0.22, -T.Y * 0.16, -T.Z / 2 - 1.62) * CFrame.Angles(math.rad(-28), 0, math.rad(i * 30)), Color = HAZ, Material = SMOOTH })
        end
    elseif kind == "Phantom" then
        -- PHANTOM (v2): a wraith. A tattered cloak that billows (Deco_Cloak), two scythe arms that sway and rise when it
        -- strikes (Deco_ArmL / R), a crown of dark shards turning over its head (Deco_Crown).
        local col = Color3.fromRGB(180, 110, 255)
        local CLOTH = Color3.fromRGB(26, 18, 38)
        Part(model, { Name = "Hood", Shape = Enum.PartType.Ball, Size = Vector3.new(T.X * 1.1, T.Y * 0.72, T.Z * 1.12), CFrame = M(0, T.Y * 0.22, 0.3), Color = CLOTH, Material = Enum.Material.Fabric })
        Wedge(model, { Name = "HoodPeak", Size = Vector3.new(T.X * 0.6, 1.6, 1.8), CFrame = M(0, T.Y * 0.62, 0.9) * CFrame.Angles(math.rad(-25), 0, 0), Color = CLOTH, Material = Enum.Material.Fabric })
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.55, 0.32, 0.3), CFrame = M(sx * 0.62, T.Y * 0.16, -T.Z * 0.48), Color = col, Glow = true })
        end
        -- the cloak: two rings of ragged strips hanging from the shoulders
        for ring = 0, 1 do
            local n = 10
            for i = 0, n - 1 do
                local a = (i + ring * 0.5) / n * math.pi * 2
                local len = T.Y * (1.05 + ((i * 7) % 3) * 0.18) - ring * 0.6
                Wedge(model, { Name = "Deco_Cloak", Size = Vector3.new(0.14, len, T.X * 0.42), Material = Enum.Material.Fabric, Transparency = 0.05 + ring * 0.2,
                    CFrame = M(0, -T.Y * 0.1 - len / 2 + 1.2, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, T.X * (0.46 + ring * 0.08)) * CFrame.Angles(math.rad(188 - ring * 6), 0, 0),
                    Color = CLOTH:Lerp(col, ring * 0.12) })
            end
        end
        -- scythe arms: shoulder -> elbow -> a curved blade of three glowing-edged segments
        for _, sx in ipairs({ -1, 1 }) do
            local side = sx < 0 and "L" or "R"
            local nm = "Deco_Arm" .. side
            local sh = Vector3.new(sx * T.X * 0.48, T.Y * 0.18, 0)
            local el = Vector3.new(sx * (T.X * 0.48 + 2.0), -T.Y * 0.05, -1.0)
            local wr = Vector3.new(sx * (T.X * 0.48 + 2.6), T.Y * 0.2, -2.6)
            Limb(nm .. "Upper", sh, el, 0.6, 0.6, CLOTH, Enum.Material.Fabric)
            Limb(nm .. "Fore", el, wr, 0.5, 0.5, Color3.fromRGB(60, 50, 80))
            -- the scythe: a pole up from the hand, then a hooked blade that curves forward and down from its top
            local top = wr + Vector3.new(0, 3.6, 0.3)
            Limb(nm .. "Pole", wr + Vector3.new(0, -1.2, -0.1), top, 0.28, 0.28, Color3.fromRGB(40, 30, 56))
            local prev = top
            for k = 1, 4 do
                local t = math.rad(k * 28)
                local nxt = top + Vector3.new(sx * 0.15 * k, 2.3 * (math.cos(t) - 1), -2.3 * math.sin(t))
                local c = (prev + nxt) / 2
                local cf = base * CFrame.lookAt(c, nxt, Vector3.new(sx, 0, 0))
                local w = 0.85 - k * 0.15
                Part(model, { Name = nm .. "Blade", Size = Vector3.new(w, 0.14, (nxt - prev).Magnitude + 0.15), CFrame = cf, Color = Color3.fromRGB(70, 60, 96), Material = METAL, Reflectance = 0.2 })
                Part(model, { Name = nm .. "Edge", Size = Vector3.new(0.12, 0.16, (nxt - prev).Magnitude + 0.15), CFrame = cf * CFrame.new(-sx * w / 2, 0, 0), Color = col, Glow = true })
                prev = nxt
            end
        end
        -- crown of shards
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2
            Part(model, { Name = "Deco_Crown", Size = Vector3.new(0.4, 1.4 + (i % 2) * 0.6, 0.4), Color = (i % 2 == 0) and col or Color3.fromRGB(20, 8, 30), Glow = (i % 2 == 0) or nil, Material = Enum.Material.Glass,
                CFrame = M(math.cos(a) * 1.7, T.Y * 0.75 + 0.6, math.sin(a) * 1.7) * CFrame.Angles(0, -a, math.rad(18)) })
        end
        Emit(torso or model.PrimaryPart, col, 6, 1.2, 1.5, 1.6, "rbxasset://textures/particles/smoke_main.dds")
    elseif kind == "Ravager" then
        -- RAVAGER (2026-10-07): a low armoured beast. Four legs that stride (Deco_Leg<side>), a jaw that opens while it
        -- attacks (Deco_Jaw), a ridge of armour plates down the back, horns, glowing eyes. Its back SPINES (the
        -- signature's BreakParts) are added by BossAI.
        local col = Color3.fromRGB(255, 96, 60)
        local HIDE = Color3.fromRGB(46, 30, 28)
        -- shoulders + haunches over the box hitbox, a chest plate, the back ridge
        Part(model, { Name = "Shoulders", Size = Vector3.new(T.X * 1.08, T.Y * 0.8, T.Z * 0.45), CFrame = M(0, 0.6, -T.Z * 0.24), Color = HIDE, Material = Enum.Material.Slate })
        Part(model, { Name = "Haunch", Size = Vector3.new(T.X * 0.95, T.Y * 0.7, T.Z * 0.4), CFrame = M(0, 0.3, T.Z * 0.28), Color = HIDE, Material = Enum.Material.Slate })
        Wedge(model, { Name = "ChestPlate", Size = Vector3.new(T.X * 0.8, T.Y * 0.7, 1.4), CFrame = M(0, -0.2, -T.Z / 2 - 0.3) * CFrame.Angles(0, math.rad(180), 0), Color = ARMOR, Material = METAL })
        for i = 0, 4 do
            Wedge(model, { Name = "Ridge", Size = Vector3.new(T.X * 0.5 - i * 0.25, 0.9, 1.6), CFrame = M(0, T.Y / 2 + 0.6, -T.Z * 0.32 + i * 1.6), Color = ARMOR, Material = METAL })
        end
        -- the head: skull, jaw, horns, eyes
        Part(model, { Name = "Skull", Size = Vector3.new(3, 2.2, 3.4), CFrame = M(0, 1.6, -T.Z / 2 - 1.3), Color = HIDE, Material = Enum.Material.Slate })
        Wedge(model, { Name = "Deco_Jaw", Size = Vector3.new(2.6, 0.9, 3), CFrame = M(0, 0.2, -T.Z / 2 - 1.5) * CFrame.Angles(0, math.rad(180), math.rad(180)), Color = HIDE, Material = Enum.Material.Slate })
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.4, 0.4), CFrame = M(sx * 0.9, 2.1, -T.Z / 2 - 3), Color = col, Glow = true })
            Limb("Horn", Vector3.new(sx * 1.2, 2.6, -T.Z / 2 - 1.6), Vector3.new(sx * 2.4, 4.2, -T.Z / 2 - 0.4), 0.5, 0.5, Color3.fromRGB(220, 200, 170), Enum.Material.SmoothPlastic)
            for k = -1, 1 do
                Wedge(model, { Name = "Fang", Size = Vector3.new(0.2, 0.6, 0.3), CFrame = M(sx * 0.6 + k * 0.25, 0.75, -T.Z / 2 - 2.8) * CFrame.Angles(math.rad(180), 0, 0), Color = Color3.fromRGB(235, 225, 200) })
            end
        end
        -- legs: thigh + shin + a clawed foot, front and back
        for _, sx in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                local nm = "Deco_Leg" .. (sx < 0 and "L" or "R") .. (sz < 0 and "F" or "B")
                local hip = Vector3.new(sx * T.X * 0.5, 0, sz * T.Z * 0.32)
                local knee = hip + Vector3.new(sx * 1.4, -1.6, sz * -0.6)
                local foot = Vector3.new(sx * (T.X * 0.5 + 1.2), -T.Y / 2 - 1.6, sz * T.Z * 0.36)
                Limb(nm .. "Thigh", hip, knee, 1.4, 1.4, HIDE, Enum.Material.Slate)
                Limb(nm .. "Shin", knee, foot, 0.9, 0.9, ARMOR, METAL)
                Part(model, { Name = nm .. "Claw", Size = Vector3.new(1.4, 0.4, 1.6), CFrame = M(foot.X, foot.Y, foot.Z - 0.3), Color = DARK, Material = METAL })
            end
        end
        -- a tail of tapering segments
        local prev = Vector3.new(0, 0.6, T.Z / 2)
        for k = 1, 4 do
            local nxt = prev + Vector3.new(0, 0.2 - k * 0.15, 1.5)
            Limb("Deco_Tail", prev, nxt, 1.1 - k * 0.2, 1.1 - k * 0.2, HIDE, Enum.Material.Slate)
            prev = nxt
        end
        Part(model, { Name = "Underglow", Size = Vector3.new(T.X * 0.7, 0.2, T.Z * 0.8), CFrame = M(0, -T.Y / 2 - 0.1, 0), Color = col, Glow = true, Transparency = 0.4 })
    elseif kind == "Hexcaller" then
        -- HEXCALLER (2026-10-07): a floating robed caster. Layered robe plates drifting (Deco_Robe), a hood with a glowing
        -- mask, a staff with a crystal head (Deco_Staff), a turning sigil ring under it (Deco_Sigil). Its three warding
        -- CRYSTALS (the signature's BreakParts) are added and orbited by BossAI.
        local col = Color3.fromRGB(70, 235, 190)
        local ROBE = Color3.fromRGB(28, 34, 48)
        Part(model, { Name = "Hood", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.8), CFrame = M(0, T.Y * 0.62, 0.2), Color = ROBE, Material = Enum.Material.Fabric })
        Part(model, { Name = "Mask", Size = Vector3.new(1.4, 1.6, 0.25), CFrame = M(0, T.Y * 0.62, -1.3), Color = Color3.fromRGB(220, 230, 235), Material = Enum.Material.SmoothPlastic })
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "Eye", Size = Vector3.new(0.35, 0.18, 0.1), CFrame = M(sx * 0.32, T.Y * 0.66, -1.45), Color = col, Glow = true })
            Wedge(model, { Name = "Mantle", Size = Vector3.new(1.6, 1.2, 3.2), CFrame = M(sx * 2.0, T.Y * 0.38, 0) * CFrame.Angles(0, 0, math.rad(sx * -30)), Color = ARMOR, Material = METAL })
        end
        for i = 0, 9 do
            local a = i / 10 * math.pi * 2
            Wedge(model, { Name = "Deco_Robe", Size = Vector3.new(0.2, T.Y * 0.9, 1.5), Material = Enum.Material.Fabric, Color = (i % 2 == 0) and ROBE or ROBE:Lerp(col, 0.15),
                CFrame = M(0, -T.Y * 0.35, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, T.X * 0.5) * CFrame.Angles(math.rad(186), 0, 0) })
        end
        -- the staff, held on its right
        Limb("Deco_StaffPole", Vector3.new(3, -T.Y * 0.55, -0.6), Vector3.new(3, T.Y * 0.75, -0.6), 0.35, 0.35, Color3.fromRGB(70, 56, 46), Enum.Material.Wood)
        Part(model, { Name = "Deco_StaffHead", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3, CFrame = M(3, T.Y * 0.75 + 0.7, -0.6), Color = col, Glow = true })
        Part(model, { Name = "Deco_StaffRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2.2, 2.2), CFrame = M(3, T.Y * 0.75 + 0.7, -0.6), Color = ARMOR, Material = METAL })
        -- the sigil ring under it: 8 glowing segments
        for i = 0, 7 do
            local a = i / 8 * math.pi * 2
            Part(model, { Name = "Deco_Sigil", Size = Vector3.new(2.2, 0.15, 0.35), CFrame = M(math.cos(a) * 4, -T.Y / 2 - 1.2, math.sin(a) * 4) * CFrame.Angles(0, -a + math.pi / 2, 0), Color = col, Glow = true, Transparency = 0.25 })
        end
        Emit(torso or model.PrimaryPart, col, 5, 0.6, 1.2, 1.4)
    elseif kind == "Sentinel" then
        -- SENTINEL (v2): a fortress. Four crystal pylons bob over their towers and are linked by energy beams, the rune
        -- ring at its base and the emitter crown turn (Deco_BaseRing / Deco_Crown), three drones orbit it (Deco_Orbit).
        local col = Color3.fromRGB(90, 200, 255)
        -- octagonal plinth + a turning rune ring
        Part(model, { Name = "Plinth", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, T.X * 1.55, T.X * 1.55), CFrame = M(0, -T.Y / 2 + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = ARMOR, Material = METAL })
        for i = 0, 11 do
            local a = i / 12 * math.pi * 2
            Part(model, { Name = "Deco_BaseRing", Size = Vector3.new(1.4, 0.18, 0.45), Color = col, Glow = (i % 2 == 0) or nil, Material = METAL,
                CFrame = M(0, -T.Y / 2 + 0.75, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, T.X * 0.72) })
        end
        Part(model, { Name = "Skirt", Size = Vector3.new(T.X * 1.15, 1.2, T.Z * 1.15), CFrame = M(0, -T.Y / 2 + 1.1, 0), Color = ARMOR_LIGHT, Material = METAL })
        -- circuit lines on the side armor
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "SidePlate", Size = Vector3.new(0.5, T.Y * 0.7, T.Z * 0.8), CFrame = M(sx * (T.X / 2 + 0.25), 0, 0), Color = ARMOR, Material = METAL })
            for k = 0, 2 do
                Part(model, { Name = "Circuit", Size = Vector3.new(0.1, 0.16, T.Z * (0.3 + k * 0.15)), CFrame = M(sx * (T.X / 2 + 0.52), -T.Y * 0.2 + k * 1.4, (k - 1) * 0.6), Color = col, Glow = true })
            end
        end
        -- four towers with floating crystals, linked by beams
        local atts = {}
        for i, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
            local tp = Vector3.new(c[1] * (T.X / 2 + 1.4), 0, c[2] * (T.Z / 2 + 1.4))
            Part(model, { Name = "Tower", Size = Vector3.new(1.3, T.Y * 1.0, 1.3), CFrame = base * CFrame.new(tp), Color = ARMOR_LIGHT, Material = METAL })
            Part(model, { Name = "TowerCap", Size = Vector3.new(1.8, 0.5, 1.8), CFrame = base * CFrame.new(tp + Vector3.new(0, T.Y * 0.5, 0)), Color = ARMOR, Material = METAL })
            for k = -1, 1 do
                Part(model, { Name = "TowerBand", Size = Vector3.new(1.4, 0.18, 1.4), CFrame = base * CFrame.new(tp + Vector3.new(0, k * T.Y * 0.25, 0)), Color = col, Glow = true })
            end
            local cr = Part(model, { Name = "Deco_Crystal" .. i, Size = Vector3.new(1.0, 1.9, 1.0), CFrame = base * CFrame.new(tp + Vector3.new(0, T.Y * 0.5 + 1.8, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = col, Glow = true })
            local att = Instance.new("Attachment"); att.Parent = cr
            atts[i] = att
        end
        for i = 1, 4 do
            local b = Instance.new("Beam")
            b.Attachment0 = atts[i]; b.Attachment1 = atts[i % 4 + 1]
            b.Color = ColorSequence.new(col); b.LightEmission = 1; b.Width0 = 0.7; b.Width1 = 0.7; b.FaceCamera = true
            b.Texture = "rbxasset://textures/particles/sparkles_main.dds"; b.TextureSpeed = 2; b.TextureLength = 3
            b.Transparency = NumberSequence.new(0.1); b.Brightness = 3; b.Parent = atts[i].Parent
        end
        -- the emitter crown + its drones
        Part(model, { Name = "Emitter", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 2.6, 2.6), CFrame = M(0, T.Y / 2 + 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = ARMOR, Material = METAL })
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2
            Wedge(model, { Name = "Deco_Crown", Size = Vector3.new(0.4, 1.6, 1.0), Color = (i % 2 == 0) and col or ARMOR_LIGHT, Glow = (i % 2 == 0) or nil, Material = METAL,
                CFrame = M(math.cos(a) * 1.6, T.Y / 2 + 2.0, math.sin(a) * 1.6) * CFrame.Angles(0, -a + math.pi / 2, 0) })
        end
        Part(model, { Name = "CrownCore", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = M(0, T.Y / 2 + 2.0, 0), Color = col, Glow = true })
        for i = 0, 2 do
            local a = i / 3 * math.pi * 2
            local d = M(math.cos(a) * (T.X + 1.5), T.Y * 0.35, math.sin(a) * (T.X + 1.5))
            Part(model, { Name = "Deco_Orbit", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1), CFrame = d, Color = ARMOR_LIGHT, Material = METAL })
            Part(model, { Name = "Deco_OrbitEye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = d * CFrame.new(0, 0, -0.42), Color = col, Glow = true })
        end
        -- (0.53 detail pass) the fortress's crystal spire: a tall faceted crystal over the crown with two smaller ones
        for k, c in ipairs({ { 0, 0, 1.6, 6.0 }, { 0.9, 0.5, 0.9, 3.4 }, { -0.8, -0.6, 0.8, 2.8 } }) do
            Part(model, { Name = "Spire", Size = Vector3.new(c[3], c[4], c[3]), Color = col:Lerp(Color3.new(1, 1, 1), 0.35), Material = Enum.Material.Glass, Transparency = 0.25,
                CFrame = M(c[1], T.Y / 2 + 2.6 + c[4] / 2, c[2]) * CFrame.Angles(0, math.rad(45 + k * 20), math.rad((k - 1) * 8)) })
            Part(model, { Name = "Glow", Size = Vector3.new(c[3] * 0.4, c[4] * 0.85, c[3] * 0.4), Color = col, Glow = true,
                CFrame = M(c[1], T.Y / 2 + 2.6 + c[4] / 2, c[2]) * CFrame.Angles(0, math.rad(45 + k * 20), math.rad((k - 1) * 8)) })
        end
        -- flying buttresses from each tower top in to the crown
        for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
            Limb("Buttress", Vector3.new(c[1] * (T.X / 2 + 1.4), T.Y * 0.5 + 0.3, c[2] * (T.Z / 2 + 1.4)), Vector3.new(c[1] * 1.1, T.Y / 2 + 1.0, c[2] * 1.1), 0.45, 0.45, ARMOR_LIGHT)
        end
    elseif kind == "Titan" then
        -- APEX TITAN MECH (v2): a four-legged siege walker. Splayed legs stride as it moves (Deco_Leg1..4), rotary arm
        -- cannons spin up while it attacks (Deco_BarrelL / R), the reactor ring turns around its core (Deco_Reactor),
        -- missile pods + vents glow with the phase (Deco_Glow*). Torso / Core / Head stay the hitboxes.
        local col = Color3.fromRGB(255, 60, 60)
        local HAZ = Color3.fromRGB(255, 190, 40)
        local DARK = Color3.fromRGB(26, 28, 34)
        local function M(x, y, z) return base * CFrame.new(x, y, z) end
        local function Limb(name, a, b, w, h, color, mat)
            local c = (a + b) / 2
            return Part(model, { Name = name, Size = Vector3.new(w, h, (b - a).Magnitude), CFrame = base * CFrame.lookAt(c, b), Color = color, Material = mat or METAL })
        end
        local head = model:FindFirstChild("Head")
        if head then head.Color = Color3.fromRGB(255, 70, 50) end -- (the visor: a hot red eye-slit, still the weak spot)
        -- ===== chassis plating =====
        Part(model, { Name = "ChestPlate", Size = Vector3.new(T.X * 0.92, T.Y * 0.3, 0.6), CFrame = M(0, -T.Y * 0.26, -T.Z / 2 - 0.3), Color = ARMOR_LIGHT, Material = METAL })
        for _, sx in ipairs({ -1, 1 }) do
            Wedge(model, { Name = "ChestWing", Size = Vector3.new(T.X * 0.34, T.Y * 0.34, 1.4), CFrame = M(sx * T.X * 0.3, T.Y * 0.3, -T.Z / 2 - 0.5) * CFrame.Angles(0, 0, math.rad(sx > 0 and 0 or 0)) * CFrame.Angles(math.rad(180), 0, 0), Color = ARMOR, Material = METAL })
            -- side armor slabs with three glowing vent strips
            Part(model, { Name = "SideSlab", Size = Vector3.new(0.7, T.Y * 0.62, T.Z * 0.9), CFrame = M(sx * (T.X / 2 + 0.35), -T.Y * 0.05, 0), Color = ARMOR, Material = METAL })
            for k = 0, 2 do
                Part(model, { Name = "Deco_GlowVent", Size = Vector3.new(0.12, 0.28, T.Z * 0.6), CFrame = M(sx * (T.X / 2 + 0.72), -T.Y * 0.18 + k * 0.9, 0), Color = col, Glow = true })
            end
        end
        -- hazard chevrons along the lower plate
        for i = -3, 3 do
            Part(model, { Name = "Hazard", Size = Vector3.new(0.45, T.Y * 0.28, 0.08), CFrame = M(i * 1.25, -T.Y * 0.26, -T.Z / 2 - 0.64) * CFrame.Angles(0, 0, math.rad(32)),
                Color = (i % 2 == 0) and HAZ or DARK, Material = SMOOTH })
        end
        -- a stencilled serial on the chest
        do
            local plate = Part(model, { Name = "Serial", Size = Vector3.new(T.X * 0.5, 1.1, 0.1), CFrame = M(0, T.Y * 0.08, -T.Z / 2 - 0.08), Color = DARK, Material = SMOOTH })
            local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.LightInfluence = 0; sg.PixelsPerStud = 40; sg.Parent = plate
            local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.Font = Enum.Font.Michroma; t.TextScaled = true
            t.Text = "APEX-07  //  SIEGE"; t.TextColor3 = HAZ; t.Parent = sg
        end
        -- ===== reactor: a segmented ring that turns around the core + four clamps =====
        local coreC = M(0, 2.0, -3.6)
        for i = 0, 11 do
            local a = i / 12 * math.pi * 2
            Part(model, { Name = "Deco_Reactor", Size = Vector3.new(1.0, 0.55, 0.5), Color = (i % 3 == 0) and col or ARMOR_LIGHT, Glow = (i % 3 == 0) or nil, Material = METAL,
                CFrame = coreC * CFrame.new(0, 0, -0.9) * CFrame.Angles(0, 0, a) * CFrame.new(0, 2.75, 0) })
        end
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            Part(model, { Name = "Clamp", Size = Vector3.new(0.7, 1.6, 1.4), Color = ARMOR, Material = METAL,
                CFrame = coreC * CFrame.new(0, 0, -0.2) * CFrame.Angles(0, 0, a) * CFrame.new(0, 3.3, 0) })
        end
        -- ===== helmet around the visor =====
        local hc = M(0, 8.8, 0)
        Part(model, { Name = "HelmTop", Size = Vector3.new(4.6, 0.9, 4.4), CFrame = hc * CFrame.new(0, 1.9, 0.2), Color = ARMOR, Material = METAL })
        Wedge(model, { Name = "HelmBrow", Size = Vector3.new(4.6, 0.9, 1.4), CFrame = hc * CFrame.new(0, 1.9, -2.6) * CFrame.Angles(0, math.rad(180), 0), Color = ARMOR, Material = METAL })
        Part(model, { Name = "HelmBack", Size = Vector3.new(4.4, 3.4, 1.2), CFrame = hc * CFrame.new(0, 0.2, 1.9), Color = ARMOR, Material = METAL })
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "HelmCheek", Size = Vector3.new(0.8, 3.0, 3.6), CFrame = hc * CFrame.new(sx * 2.2, 0.1, 0.1), Color = ARMOR_LIGHT, Material = METAL })
            Part(model, { Name = "Antenna", Size = Vector3.new(0.2, 3.4, 0.2), CFrame = hc * CFrame.new(sx * 1.7, 3.6, 1.4) * CFrame.Angles(math.rad(-12), 0, math.rad(sx * -8)), Color = ARMOR_LIGHT, Material = METAL })
            Part(model, { Name = "Deco_GlowTip", Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45), CFrame = hc * CFrame.new(sx * 1.95, 5.25, 1.75), Color = col, Glow = true })
        end
        Wedge(model, { Name = "Crest", Size = Vector3.new(0.5, 1.6, 3.6), CFrame = hc * CFrame.new(0, 3.0, 0.4), Color = col:Lerp(ARMOR, 0.4), Material = METAL })
        -- ===== shoulders: big pauldrons + missile pods (2 x 3 tubes each) =====
        for _, sx in ipairs({ -1, 1 }) do
            local sh = M(sx * (T.X / 2 + 1.9), T.Y * 0.36, 0)
            Part(model, { Name = "Pauldron", Size = Vector3.new(4.4, 3.4, T.Z * 1.15), CFrame = sh * CFrame.Angles(0, 0, math.rad(sx * -14)), Color = ARMOR, Material = METAL })
            Part(model, { Name = "PauldronTrim", Size = Vector3.new(4.5, 0.3, T.Z * 1.17), CFrame = sh * CFrame.Angles(0, 0, math.rad(sx * -14)) * CFrame.new(0, -1.55, 0), Color = HAZ, Material = SMOOTH })
            local pod = sh * CFrame.new(sx * 0.2, 2.6, 0.6)
            Part(model, { Name = "MissilePod", Size = Vector3.new(3.2, 2.2, 3.6), CFrame = pod, Color = ARMOR_LIGHT, Material = METAL })
            for x = 0, 1 do for z = 0, 2 do
                Part(model, { Name = "Deco_GlowPod", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 0.8, 0.8), Color = col, Glow = true,
                    CFrame = pod * CFrame.new(-0.7 + x * 1.4, 1.12, -1.1 + z * 1.1) * CFrame.Angles(0, 0, math.rad(90)) })
            end end
        end
        -- ===== arms: upper arm + a six-barrel rotary cannon (barrels spin about the forearm's axis) =====
        for _, sx in ipairs({ -1, 1 }) do
            local side = sx < 0 and "L" or "R"
            local shoulder = Vector3.new(sx * (T.X / 2 + 1.9), T.Y * 0.2, -0.4)
            local elbow = Vector3.new(sx * (T.X / 2 + 2.4), -T.Y * 0.12, -1.6)
            Limb("Deco_Arm" .. side, shoulder, elbow, 2.0, 2.0, ARMOR_LIGHT)
            Part(model, { Name = "Deco_Arm" .. side .. "Joint", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), CFrame = base * CFrame.new(elbow), Color = ARMOR, Material = METAL })
            local gunC = base * CFrame.new(elbow + Vector3.new(0, -0.4, -3.4))
            Part(model, { Name = "Deco_Arm" .. side .. "Housing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.2, 2.8, 2.8), CFrame = gunC * CFrame.new(0, 0, 1.2) * CFrame.Angles(0, math.rad(90), 0), Color = ARMOR, Material = METAL })
            for b = 0, 5 do
                local a = b / 6 * math.pi * 2
                Part(model, { Name = "Deco_Barrel" .. side, Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.6, 0.55, 0.55), Color = DARK, Material = METAL,
                    CFrame = gunC * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.75, -1.2) * CFrame.Angles(0, math.rad(90), 0) })
            end
            Part(model, { Name = "Deco_Barrel" .. side .. "Muzzle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 2.4, 2.4), Color = ARMOR_LIGHT, Material = METAL,
                CFrame = gunC * CFrame.new(0, 0, -3.4) * CFrame.Angles(0, math.rad(90), 0) })
            Part(model, { Name = "Deco_GlowMuzzle" .. side, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 1.9, 1.9), Color = col, Glow = true,
                CFrame = gunC * CFrame.new(0, 0, -3.62) * CFrame.Angles(0, math.rad(90), 0) })
        end
        -- ===== four splayed legs (hip -> knee up and out -> foot on the floor) =====
        local floorY = -T.Y / 2 - 1.1
        for i, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
            local sx, sz = c[1], c[2]
            local hip = Vector3.new(sx * (T.X / 2 - 0.6), -T.Y * 0.32, sz * (T.Z / 2 - 0.8))
            local knee = Vector3.new(sx * (T.X / 2 + 3.4), -T.Y * 0.12, sz * (T.Z / 2 + 2.0))
            local foot = Vector3.new(sx * (T.X / 2 + 4.6), floorY + 0.6, sz * (T.Z / 2 + 3.0))
            local nm = "Deco_Leg" .. i
            Part(model, { Name = nm .. "Hip", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = base * CFrame.new(hip), Color = ARMOR, Material = METAL })
            Limb(nm .. "Thigh", hip, knee, 1.7, 2.1, ARMOR_LIGHT)
            Limb(nm .. "Piston", hip + Vector3.new(0, -0.9, 0), knee + Vector3.new(0, -1.0, 0), 0.5, 0.5, Color3.fromRGB(170, 175, 185))
            Part(model, { Name = nm .. "Knee", Shape = Enum.PartType.Ball, Size = Vector3.new(2.0, 2.0, 2.0), CFrame = base * CFrame.new(knee), Color = ARMOR, Material = METAL })
            Part(model, { Name = nm .. "KneeGlow", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), CFrame = base * CFrame.new(knee + Vector3.new(sx * 0.85, 0, sz * 0.4)), Color = col, Glow = true })
            Limb(nm .. "Shin", knee, foot, 1.5, 1.5, ARMOR)
            Part(model, { Name = nm .. "Foot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 3.0, 3.0), CFrame = base * CFrame.new(foot + Vector3.new(0, -0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = ARMOR_LIGHT, Material = METAL })
            for t = -1, 1 do
                local a = math.atan2(sx, sz) + t * 0.55
                Wedge(model, { Name = nm .. "Toe", Size = Vector3.new(0.5, 0.7, 1.6), Color = DARK, Material = METAL,
                    CFrame = base * CFrame.new(foot + Vector3.new(math.sin(a) * 1.7, -0.5, math.cos(a) * 1.7)) * CFrame.Angles(0, a, 0) })
            end
        end
        -- exhaust stacks on the back (smoke)
        for _, sx in ipairs({ -1, 1 }) do
            local st = Part(model, { Name = "Stack", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.6, 1.3, 1.3), CFrame = M(sx * 2.4, T.Y * 0.42, T.Z / 2 + 0.9) * CFrame.Angles(0, 0, math.rad(90)), Color = ARMOR, Material = METAL })
            local sm = Emit(st, Color3.fromRGB(60, 60, 66), 5, 1.6, 3, 2.2, "rbxasset://textures/particles/smoke_main.dds")
            sm.EmissionDirection = Enum.NormalId.Right; sm.SpreadAngle = Vector2.new(10, 10); sm.LightEmission = 0
            sm.Size = NumberSequence.new(0.8, 2.4); sm.Transparency = NumberSequence.new(0.5, 1); sm.Acceleration = Vector3.new(0, 4, 0)
        end
    elseif kind == "SuperBoss" then
        EnemyModels.SuperBody(model, biome, base) -- (v3: each biome its own creature, see SUPER_BODIES)
    end
end

-- ===== ENDGAME TRIAL BOSSES (BossTrials): the full look; BossAI animates the named parts =====
--   Archon:     Deco_WingL* / Deco_WingR* (three wings a side; raised for SCALES OF JUDGEMENT, gentle flap), halo
--   Chronarch:  Deco_HandA / Deco_HandB (clock hands, turn with the beat), Deco_Pendulum*, Deco_GearL* / Deco_GearR*
--   EchoWarden: Deco_Shard* (orbiting mirror shards), Deco_Ghost* (its echoes standing behind it)
--   Forgeheart: Brand / BrandRim (attribute BrandIndex 1-3: crawl over the shell), Deco_Hammer* (raised for HAMMERFALL)
-- Model space: the pivot is the boss centre, -Z faces the player (BossAI PivotTo lookAt).
local function HaloRing(model, center, radius, thick, n, color, name)
    local chord = 2 * math.pi * radius / n * 1.1
    for i = 0, n - 1 do
        local a = i / n * math.pi * 2
        Part(model, { Name = name or "Halo", Size = Vector3.new(chord, thick, thick), Color = color, Glow = true,
            CFrame = center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, radius) })
    end
end

-- ==================== MAJOR BOSSES (0.52) ====================
-- Model dress for the four major Boss Trial bosses (DungeonGenerator TRIAL_BODIES gives Torso / Core / Head, the hit
-- parts). Parts named Deco_* are posed every frame by BossAI kit.Animate. Only the base parts are hittable; the
-- signatures add their own hit targets (locks, eggs, coins) at fight time.
EnemyModels.MajorDecor = {}
EnemyModels.MajorDecor.Lockwarden = function(model, M)
    -- a vault guardian: a riveted steel cylinder of a body, a vault-door chest plate, a key-blade on its back, shoulder
    -- tesla coils that arc, heavy chains hanging from its arms
    local STEEL, DARK, BRASS, ARC = Color3.fromRGB(96, 108, 124), Color3.fromRGB(38, 42, 52), Color3.fromRGB(200, 160, 80), Color3.fromRGB(150, 210, 255)
    Part(model, { Name = "Hull", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 7.4, 7.4), CFrame = M(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STEEL, Material = METAL, Reflectance = 0.12 })
    for i = -2, 2 do
        Part(model, { Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 7.7, 7.7), CFrame = M(0, i * 2.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = DARK, Material = METAL })
    end
    -- the vault door on its chest: a wheel and spokes
    Part(model, { Name = "Door", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 5.2, 5.2), CFrame = M(0, 0.6, -3.7) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(120, 130, 146), Material = METAL, Reflectance = 0.2 })
    Part(model, { Name = "Deco_Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 2.6, 2.6), CFrame = M(0, 0.6, -4.15) * CFrame.Angles(0, math.rad(90), 0), Color = BRASS, Material = METAL, Reflectance = 0.25 })
    for k = 0, 3 do
        Part(model, { Name = "Deco_WheelSpoke", Size = Vector3.new(0.3, 3.6, 0.3), CFrame = M(0, 0.6, -4.3) * CFrame.Angles(0, 0, k * math.pi / 4), Color = BRASS, Material = METAL })
    end
    for k = 0, 7 do
        local a = k / 8 * math.pi * 2
        Part(model, { Name = "Bolt", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, CFrame = M(math.cos(a) * 2.3, 0.6 + math.sin(a) * 2.3, -4.05), Color = BRASS, Material = METAL })
    end
    -- helm: a visor slit glowing storm blue, a crest
    Part(model, { Name = "Helm", Size = Vector3.new(4.2, 3, 4.2), CFrame = M(0, 6.2, 0), Color = STEEL, Material = METAL, Reflectance = 0.15 })
    Part(model, { Name = "Visor", Size = Vector3.new(3.2, 0.4, 0.15), CFrame = M(0, 6.4, -2.15), Color = ARC, Glow = true })
    Wedge(model, { Name = "Crest", Size = Vector3.new(0.6, 2.2, 3.6), CFrame = M(0, 8.4, 0.2), Color = BRASS, Material = METAL })
    -- arms + chains
    for _, sx in ipairs({ -1, 1 }) do
        local side = sx < 0 and "L" or "R"
        Part(model, { Name = "Pauldron", Size = Vector3.new(3.4, 2.6, 4.2), CFrame = M(sx * 5.2, 4.2, 0), Color = DARK, Material = METAL })
        Part(model, { Name = "Arm", Size = Vector3.new(2.2, 6, 2.2), CFrame = M(sx * 5.2, 0.2, 0), Color = STEEL, Material = METAL })
        Part(model, { Name = "Fist", Size = Vector3.new(2.8, 2.6, 2.8), CFrame = M(sx * 5.2, -3.6, -0.3), Color = DARK, Material = METAL })
        for c = 0, 4 do
            Part(model, { Name = "Deco_Chain" .. side, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 0.9, 0.9), Color = Color3.fromRGB(70, 74, 82), Material = METAL,
                CFrame = M(sx * 5.2, -5 - c * 0.85, -0.3) * CFrame.Angles(0, (c % 2) * math.pi / 2, math.rad(90)) })
        end
        -- tesla coil on the shoulder
        Part(model, { Name = "Coil", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 0.9, 0.9), CFrame = M(sx * 5.2, 6.6, 0.8) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(176, 106, 58), Material = METAL })
        Part(model, { Name = "Deco_CoilTip", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = M(sx * 5.2, 8.3, 0.8), Color = ARC, Glow = true })
    end
    -- the key-blade on its back
    Part(model, { Name = "KeyShaft", Size = Vector3.new(0.6, 11, 0.6), CFrame = M(0, 1, 4.2) * CFrame.Angles(0, 0, math.rad(15)), Color = BRASS, Material = METAL, Reflectance = 0.2 })
    Part(model, { Name = "KeyBow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 2.8, 2.8), CFrame = M(-1.4, 6.6, 4.2) * CFrame.Angles(0, math.rad(90), 0), Color = BRASS, Material = METAL })
    Part(model, { Name = "KeyBit", Size = Vector3.new(1.6, 1.2, 0.6), CFrame = M(1.6, -4.2, 4.2) * CFrame.Angles(0, 0, math.rad(15)), Color = BRASS, Material = METAL })
    -- legs
    for _, sx in ipairs({ -1, 1 }) do
        Part(model, { Name = "Deco_Leg" .. (sx < 0 and "L" or "R"), Size = Vector3.new(2.6, 5, 2.8), CFrame = M(sx * 2.2, -7.2, 0), Color = DARK, Material = METAL })
        Part(model, { Name = "Deco_Foot" .. (sx < 0 and "L" or "R"), Size = Vector3.new(3, 1, 4), CFrame = M(sx * 2.2, -9.8, -0.4), Color = STEEL, Material = METAL })
    end
end

EnemyModels.MajorDecor.Broodmother = function(model, M)
    -- a magma spider-queen: a swollen glowing egg-sac abdomen behind, a plated thorax, a small head with mandibles and
    -- a cluster of eyes, eight jointed legs (posed by BossAI: a walking cycle)
    local SHELL, DARK, MOLTEN, EYE = Color3.fromRGB(58, 30, 26), Color3.fromRGB(28, 16, 14), Color3.fromRGB(255, 110, 40), Color3.fromRGB(255, 220, 120)
    Part(model, { Name = "Abdomen", Shape = Enum.PartType.Ball, Size = Vector3.new(11, 9, 12), CFrame = M(0, 1.5, 7.5), Color = SHELL, Material = Enum.Material.Basalt })
    for k = 0, 5 do
        local a = k / 6 * math.pi * 2
        Part(model, { Name = "SacGlow", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, CFrame = M(math.cos(a) * 4.2, 1.5 + math.sin(a) * 3.4, 7.5 + 4.6), Color = MOLTEN, Glow = true })
    end
    for k = -2, 2 do
        Part(model, { Name = "AbdomenStripe", Size = Vector3.new(10.6, 0.45, 0.6), CFrame = M(0, 1.5 + k * 1.6, 7.5 + 5.2 - math.abs(k) * 0.6), Color = MOLTEN, Glow = true })
    end
    Part(model, { Name = "Spinneret", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = M(0, -1.2, 13.4), Color = MOLTEN, Glow = true })
    -- thorax plates
    for k = 0, 2 do
        Part(model, { Name = "ThoraxPlate", Size = Vector3.new(7 - k * 0.6, 1.2, 2.2), CFrame = M(0, 3 + k * 0.4, -1 + k * 2), Color = DARK, Material = METAL, Reflectance = 0.1 })
    end
    -- head: mandibles + 6 eyes
    for _, sx in ipairs({ -1, 1 }) do
        Part(model, { Name = "Deco_Mandible" .. (sx < 0 and "L" or "R"), Size = Vector3.new(0.6, 0.8, 3.2), CFrame = M(sx * 1.2, -1.2, -7.2) * CFrame.Angles(0, math.rad(-sx * 18), 0), Color = MOLTEN, Glow = true })
    end
    for k = 0, 5 do
        local x = (k % 3 - 1) * 0.9
        local y = (k < 3) and 0.3 or -0.5
        Part(model, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * ((k == 1) and 0.8 or 0.55), CFrame = M(x, y, -5.95), Color = EYE, Glow = true })
    end
    -- eight legs: hip -> knee raised high above the body -> foot planted wide on the floor (BossAI poses each leg about
    -- its hip: Deco_Leg<i><L|R> matches the upper, lower and knee parts)
    local function Seg(name, p0, p1, w, color, mat)
        local mid = (p0 + p1) / 2
        Part(model, { Name = name, Size = Vector3.new(w, w, (p1 - p0).Magnitude), CFrame = M(0, 0, 0) * CFrame.lookAt(mid, p1), Color = color, Material = mat })
    end
    for i = 1, 4 do
        for _, sx in ipairs({ -1, 1 }) do
            local z = -3 + (i - 1) * 2.6
            local name = "Deco_Leg" .. i .. (sx < 0 and "L" or "R")
            local hip = Vector3.new(sx * 3.4, 1.4, z)
            local knee = Vector3.new(sx * 8.5, 6.2 - math.abs(i - 2.5) * 0.4, z + (i - 2.5) * 1.6)
            local foot = Vector3.new(sx * 12.5, -6.6, z + (i - 2.5) * 3.4)
            Seg(name .. "Up", hip, knee, 0.9, SHELL, Enum.Material.Basalt)
            Seg(name .. "Lo", knee, foot, 0.7, DARK, Enum.Material.Basalt)
            Part(model, { Name = name .. "Joint", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3, CFrame = M(knee.X, knee.Y, knee.Z), Color = MOLTEN, Glow = true })
            Part(model, { Name = name .. "Claw", Size = Vector3.new(0.5, 1.2, 0.5), CFrame = M(foot.X, foot.Y - 0.2, foot.Z), Color = MOLTEN, Glow = true })
        end
    end
end

EnemyModels.MajorDecor.Duelist = function(model, M)
    -- a tall void fencer: a long split coat, a narrow masked head, a slim blade held en garde, a crescent of void
    -- shards at its back; Deco_Guard is its parry shell (shown while it guards -- BossAI SIG.Duelist)
    local COAT, DARK, VOID, PALE = Color3.fromRGB(40, 26, 58), Color3.fromRGB(18, 12, 26), Color3.fromRGB(200, 120, 255), Color3.fromRGB(240, 225, 255)
    for _, sx in ipairs({ -1, 1 }) do
        Wedge(model, { Name = "CoatTail", Size = Vector3.new(1.6, 6.5, 2.4), CFrame = M(sx * 0.9, -6.2, 0.6) * CFrame.Angles(math.rad(8), 0, math.rad(sx * 6)), Color = COAT, Material = Enum.Material.Fabric })
        Part(model, { Name = "Deco_Leg" .. (sx < 0 and "L" or "R"), Size = Vector3.new(0.9, 6.5, 0.9), CFrame = M(sx * 0.8, -6.6, 0), Color = DARK, Material = SMOOTH })
        Part(model, { Name = "Shoulder", Size = Vector3.new(1.6, 0.7, 1.8), CFrame = M(sx * 2.1, 3.4, 0), Color = VOID, Glow = true })
    end
    Part(model, { Name = "Collar", Size = Vector3.new(3.6, 1.6, 2.6), CFrame = M(0, 3.8, 0.2), Color = COAT, Material = Enum.Material.Fabric })
    Part(model, { Name = "Mask", Size = Vector3.new(1.6, 2.4, 0.3), CFrame = M(0, 5.3, -1.05), Color = PALE, Material = SMOOTH })
    Part(model, { Name = "MaskSlit", Size = Vector3.new(1.1, 0.16, 0.08), CFrame = M(0, 5.6, -1.22), Color = VOID, Glow = true })
    -- sword arm + blade
    Part(model, { Name = "Deco_SwordArm", Size = Vector3.new(0.8, 4.2, 0.8), CFrame = M(2.4, 1.2, -1.2) * CFrame.Angles(math.rad(-40), 0, 0), Color = DARK })
    Part(model, { Name = "Deco_SwordBlade", Size = Vector3.new(0.22, 9, 0.5), CFrame = M(2.6, 2.8, -5.4) * CFrame.Angles(math.rad(-62), 0, 0), Color = PALE, Material = Enum.Material.Glass, Reflectance = 0.4 })
    Part(model, { Name = "Deco_SwordEdge", Size = Vector3.new(0.08, 9, 0.12), CFrame = M(2.6, 2.8, -5.4) * CFrame.Angles(math.rad(-62), 0, 0) * CFrame.new(0, 0, -0.28), Color = VOID, Glow = true })
    Part(model, { Name = "Deco_SwordHilt", Size = Vector3.new(1.6, 0.3, 0.3), CFrame = M(2.5, -0.4, -3.2), Color = VOID, Glow = true })
    -- a crescent of void shards behind it
    for k = 0, 6 do
        local a = math.rad(-70 + k * 23)
        Part(model, { Name = "Deco_Shard", Size = Vector3.new(0.3, 2.2 - math.abs(k - 3) * 0.25, 0.9), CFrame = M(math.sin(a) * 4, 4.2 + math.cos(a) * 3, 2.2) * CFrame.Angles(0, 0, -a),
            Color = VOID, Glow = true, Transparency = 0.15 })
    end
end

-- (MAPS V2 2026-10-30) THE LAMPLIGHTER's fallback dress (the real look is BossLook/Lamplighter + BossKit.Lamplighter in the place):
-- a short capelet with a brass clasp, a tall lamp-pole floating at his right with a caged amber lantern, a brass halo ring
EnemyModels.MajorDecor.Lamplighter = function(model, M)
    local COAT, DARK, BRASS, AMBER = Color3.fromRGB(40, 42, 58), Color3.fromRGB(18, 18, 24), Color3.fromRGB(176, 140, 82), Color3.fromRGB(255, 178, 76)
    Part(model, { Name = "Capelet", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 3.6, 3.6), CFrame = M(0, 2.4, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = COAT, Material = SMOOTH })
    Part(model, { Name = "Clasp", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = M(0, 3.1, -1.75), Color = BRASS, Material = SMOOTH })
    Part(model, { Name = "Hem", Size = Vector3.new(3.0, 0.25, 2.4), CFrame = M(0, -3.0, 0), Color = AMBER, Glow = true })
    Part(model, { Name = "Deco_Pole", Size = Vector3.new(0.3, 9.5, 0.3), CFrame = M(1.9, 1.2, 0), Color = DARK, Material = SMOOTH })
    Part(model, { Name = "Deco_PoleHook", Size = Vector3.new(1.4, 0.25, 0.25), CFrame = M(1.3, 5.9, 0), Color = BRASS, Material = SMOOTH })
    Part(model, { Name = "Deco_PoleLantern", Size = Vector3.new(0.9, 1.2, 0.9), CFrame = M(0.7, 5.0, 0), Color = DARK, Material = SMOOTH })
    Part(model, { Name = "Deco_PoleGlass", Size = Vector3.new(0.65, 0.8, 0.65), CFrame = M(0.7, 5.0, 0), Color = AMBER, Glow = true, Transparency = 0.1 })
    HaloRing(model, M(0, 6.0, 0.3), 1.2, 0.18, 8, BRASS, "Deco_Halo")
end

EnemyModels.MajorDecor.FortuneEngine = function(model, M)
    -- a casino colossus: a slot-machine cabinet on caterpillar treads, three reels in its face, a marquee of bulbs,
    -- a lever arm, a coin chute that spills when it pays out
    local CAB, TRIM, GOLD, RED, BULB = Color3.fromRGB(120, 20, 40), Color3.fromRGB(30, 26, 34), Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 60, 70), Color3.fromRGB(255, 240, 170)
    Part(model, { Name = "Cabinet", Size = Vector3.new(11, 10, 6), CFrame = M(0, 0, 0.5), Color = CAB, Material = SMOOTH, Reflectance = 0.15 })
    Part(model, { Name = "Bezel", Size = Vector3.new(9.2, 3.8, 0.5), CFrame = M(0, 1.4, -2.7), Color = GOLD, Material = METAL, Reflectance = 0.3 })
    for i = -1, 1 do
        -- a glass window onto a turning reel with three symbols on it (BossAI spins the reels)
        Part(model, { Name = "ReelWindow", Size = Vector3.new(2.6, 3.2, 0.2), CFrame = M(i * 2.9, 1.4, -3.45), Color = Color3.fromRGB(200, 230, 255), Material = SMOOTH, Transparency = 0.75 })
        Part(model, { Name = "Deco_Reel" .. (i + 2), Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 3.2, 3.2), CFrame = M(i * 2.9, 1.4, -1.75), Color = Color3.fromRGB(250, 248, 236), Material = SMOOTH })
        for k, col in ipairs({ RED, GOLD, Color3.fromRGB(80, 220, 255) }) do
            local a = (k - 1) * math.pi * 2 / 3
            Part(model, { Name = "Deco_Reel" .. (i + 2) .. "Mark", Size = Vector3.new(1.4, 0.9, 0.3), Color = col, Glow = true,
                CFrame = M(i * 2.9, 1.4 + math.sin(a) * 1.6, -1.75 - math.cos(a) * 1.6) * CFrame.Angles(-a, 0, 0) })
        end
    end
    -- marquee with bulbs
    -- the marquee (the hittable Head box sits inside it -- DungeonGenerator TRIAL_BODIES)
    Part(model, { Name = "Marquee", Size = Vector3.new(11.6, 2.8, 3.8), CFrame = M(0, 6.4, 0.2), Color = Color3.fromRGB(200, 150, 40), Material = METAL, Reflectance = 0.25 })
    Part(model, { Name = "MarqueeFace", Size = Vector3.new(10.4, 1.6, 0.1), CFrame = M(0, 6.4, -1.72), Color = TRIM, Material = SMOOTH })
    for k = 0, 9 do
        Part(model, { Name = "Deco_Bulb", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, CFrame = M(-5 + k * 1.11, 6.4, -1.9), Color = (k % 2 == 0) and BULB or RED, Glow = true })
    end
    -- the payout tray + chute
    Part(model, { Name = "Tray", Size = Vector3.new(7, 1, 2.4), CFrame = M(0, -3.6, -3.2), Color = GOLD, Material = METAL, Reflectance = 0.3 })
    Part(model, { Name = "Chute", Size = Vector3.new(3, 1.6, 0.4), CFrame = M(0, -2.4, -2.8), Color = TRIM, Material = METAL })
    -- the lever on its right side
    Part(model, { Name = "LeverBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 2, 2), CFrame = M(6, 0.5, 0.5), Color = TRIM, Material = METAL })
    Part(model, { Name = "Deco_Lever", Size = Vector3.new(0.5, 6, 0.5), CFrame = M(6.6, 3.4, 0.5), Color = Color3.fromRGB(200, 200, 210), Material = METAL, Reflectance = 0.3 })
    Part(model, { Name = "Deco_LeverKnob", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = M(6.6, 6.6, 0.5), Color = RED, Glow = true })
    -- treads
    for _, sx in ipairs({ -1, 1 }) do
        Part(model, { Name = "Tread", Size = Vector3.new(2.6, 2.4, 9), CFrame = M(sx * 4.4, -6.2, 0.5), Color = TRIM, Material = METAL })
        for w = -1, 1 do
            Part(model, { Name = "Deco_Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.7, 1.8, 1.8), CFrame = M(sx * 4.4, -6.2, 0.5 + w * 3), Color = GOLD, Material = METAL })
        end
    end
end

function EnemyModels.DecorateTrialBoss(model, id, pos)
    if EnemyModels.TryLook(model, id, pos) then return end
    local base = CFrame.new(pos)
    local function M(x, y, z) return base * CFrame.new(x, y, z) end
    if EnemyModels.MajorDecor[id] then EnemyModels.MajorDecor[id](model, M); return end
    if id == "Archon" then
        local PEARL, GOLD, PALE = Color3.fromRGB(236, 232, 222), Color3.fromRGB(255, 196, 70), Color3.fromRGB(255, 236, 180)
        -- robe: a long skirt with a gold hem, sleeves, a gold sash
        Part(model, { Name = "Robe", Size = Vector3.new(6.2, 5, 3.8), CFrame = M(0, -5.6, 0), Color = PEARL })
        Wedge(model, { Name = "RobeFront", Size = Vector3.new(6.2, 5, 1.2), CFrame = M(0, -5.6, -2.5) * CFrame.Angles(0, math.rad(180), 0), Color = PEARL, Material = SMOOTH })
        Part(model, { Name = "Hem", Size = Vector3.new(6.4, 0.35, 4.0), CFrame = M(0, -8.0, 0), Color = GOLD, Glow = true })
        Part(model, { Name = "Sash", Size = Vector3.new(5.2, 0.6, 3.2), CFrame = M(0, -1.6, 0), Color = GOLD, Material = METAL, Reflectance = 0.2 })
        Part(model, { Name = "Mantle", Size = Vector3.new(6.4, 1.2, 3.4), CFrame = M(0, 3.6, 0), Color = GOLD, Material = METAL, Reflectance = 0.2 })
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "Sleeve", Size = Vector3.new(1.4, 5.2, 1.4), CFrame = M(sx * 3.4, 0.8, -0.3) * CFrame.Angles(math.rad(-20), 0, math.rad(sx * 12)), Color = PEARL })
            Part(model, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.35, 0.3), CFrame = M(sx * 0.45, 5.5, -1.15), Color = PALE, Glow = true })
        end
        -- a sword of light held point-down in front of it
        Part(model, { Name = "LightBlade", Size = Vector3.new(0.5, 9, 0.18), CFrame = M(0, -3.2, -2.6), Color = PALE, Glow = true, Transparency = 0.1 })
        Part(model, { Name = "LightGuard", Size = Vector3.new(3, 0.4, 0.5), CFrame = M(0, 1.4, -2.6), Color = GOLD, Material = METAL })
        -- halo
        HaloRing(model, M(0, 7.6, 0.4), 2.1, 0.32, 14, PALE, "Halo")
        -- SIX WINGS: three a side (upper / middle / lower), 4 feathers each with a gold leading edge
        for _, sx in ipairs({ -1, 1 }) do
            local side = sx < 0 and "L" or "R"
            local root = Vector3.new(sx * 1.6, 2.6, 1.6)
            for w, a0 in ipairs({ 38, 8, -24 }) do
                local scale = ({ 1.0, 0.85, 0.65 })[w]
                for k = 0, 3 do
                    local a = math.rad(a0 + k * 9 - 12)
                    local dir = Vector3.new(sx * math.cos(a), math.sin(a), 0.32).Unit
                    local L = (8.5 - k * 1.3) * scale
                    local h = (1.5 - k * 0.2) * scale
                    local start = root + Vector3.new(0, -(w - 1) * 1.4, 0.2 * w)
                    local center = start + dir * (L / 2)
                    local up = Vector3.new(0, 0, 1):Cross(dir) * sx
                    local cf = base * CFrame.lookAt(center, center + dir, up)
                    Wedge(model, { Name = "Deco_Wing" .. side, Size = Vector3.new(0.22, h, L), CFrame = cf, Color = PEARL, Material = SMOOTH })
                    Part(model, { Name = "Deco_Wing" .. side .. "Edge", Size = Vector3.new(0.26, 0.16, L * 0.95), CFrame = cf * CFrame.new(0, h / 2 - 0.06, 0), Color = GOLD, Glow = true })
                end
            end
        end
    elseif id == "Chronarch" then
        local BRONZE, FACE, CYAN, GOLD = Color3.fromRGB(110, 80, 50), Color3.fromRGB(226, 232, 238), Color3.fromRGB(90, 230, 255), Color3.fromRGB(230, 180, 80)
        local fz = -1.75 -- the face, on the front
        Part(model, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 9.8, 9.8), CFrame = M(0, 0, fz + 0.15) * CFrame.Angles(0, math.rad(90), 0), Color = BRONZE, Material = METAL, Reflectance = 0.15 })
        Part(model, { Name = "Face", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 8.6, 8.6), CFrame = M(0, 0, fz) * CFrame.Angles(0, math.rad(90), 0), Color = FACE, Material = SMOOTH })
        for i = 0, 11 do
            local a = i / 12 * math.pi * 2
            local big = (i % 3 == 0)
            Part(model, { Name = "Tick", Size = Vector3.new(big and 0.5 or 0.25, big and 1.1 or 0.6, 0.12), Color = CYAN, Glow = true,
                CFrame = M(0, 0, fz - 0.18) * CFrame.Angles(0, 0, -a) * CFrame.new(0, 3.6, 0) })
        end
        -- the hands, drawn pointing up from the centre (BossAI turns them about the face centre)
        Part(model, { Name = "Deco_HandA", Size = Vector3.new(0.45, 2.6, 0.14), CFrame = M(0, 1.3, fz - 0.3), Color = BRONZE, Material = METAL })
        Part(model, { Name = "Deco_HandB", Size = Vector3.new(0.28, 3.7, 0.12), CFrame = M(0, 1.85, fz - 0.38), Color = Color3.fromRGB(30, 30, 36), Material = METAL })
        Part(model, { Name = "Hub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.8, 0.8), CFrame = M(0, 0, fz - 0.45) * CFrame.Angles(0, math.rad(90), 0), Color = GOLD, Material = METAL })
        -- the bell tower top + roof
        Wedge(model, { Name = "RoofL", Size = Vector3.new(3.6, 2.4, 5), CFrame = M(-1.8, 5.9, 0) * CFrame.Angles(0, math.rad(-90), 0), Color = BRONZE, Material = METAL })
        Wedge(model, { Name = "RoofR", Size = Vector3.new(3.6, 2.4, 5), CFrame = M(1.8, 5.9, 0) * CFrame.Angles(0, math.rad(90), 0), Color = BRONZE, Material = METAL })
        -- the pendulum below (swings with the beat)
        Part(model, { Name = "Deco_PendulumRod", Size = Vector3.new(0.3, 5.5, 0.3), CFrame = M(0, -7.2, -0.6), Color = GOLD, Material = METAL })
        Part(model, { Name = "Deco_PendulumBob", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 2.6, 2.6), CFrame = M(0, -10.2, -0.6) * CFrame.Angles(0, math.rad(90), 0), Color = GOLD, Material = METAL, Reflectance = 0.25 })
        Part(model, { Name = "Deco_PendulumGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.55, 1.2, 1.2), CFrame = M(0, -10.2, -0.62) * CFrame.Angles(0, math.rad(90), 0), Color = CYAN, Glow = true })
        -- side gears (turn slowly)
        for _, sx in ipairs({ -1, 1 }) do
            local side = sx < 0 and "L" or "R"
            Part(model, { Name = "Deco_Gear" .. side, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 4.2, 4.2), CFrame = M(sx * 5.0, -2.6, 0) * CFrame.Angles(0, 0, 0), Color = BRONZE, Material = METAL })
            for t = 0, 7 do
                local a = t / 8 * math.pi * 2
                Part(model, { Name = "Deco_Gear" .. side .. "Tooth", Size = Vector3.new(0.6, 0.7, 0.7), CFrame = M(sx * 5.0, -2.6, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 2.3, 0), Color = BRONZE, Material = METAL })
            end
            Part(model, { Name = "Deco_Gear" .. side .. "Core", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 1.2, 1.2), CFrame = M(sx * 5.0, -2.6, 0), Color = CYAN, Glow = true })
        end
    elseif id == "EchoWarden" then
        local DARK, PURPLE, PALE = Color3.fromRGB(24, 14, 36), Color3.fromRGB(180, 100, 255), Color3.fromRGB(230, 200, 255)
        -- crystal shell around the body
        for i = 0, 3 do
            local a = i * math.pi / 2 + math.pi / 4
            Wedge(model, { Name = "ShellUp", Size = Vector3.new(3.4, 4.6, 2.2), CFrame = M(0, 6.2, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 1.2), Color = DARK, Material = Enum.Material.Glass, Transparency = 0.15 })
            Wedge(model, { Name = "ShellDown", Size = Vector3.new(3.4, 4.6, 2.2), CFrame = M(0, -6.2, 0) * CFrame.Angles(math.rad(180), a, 0) * CFrame.new(0, 0, 1.2), Color = DARK, Material = Enum.Material.Glass, Transparency = 0.15 })
        end
        Part(model, { Name = "Seam", Size = Vector3.new(4.8, 0.3, 4.8), CFrame = M(0, 0, 0), Color = PURPLE, Glow = true })
        HaloRing(model, M(0, -9.5, 0), 4.5, 0.3, 16, PURPLE, "FloorRing")
        -- orbiting mirror shards
        for i = 0, 5 do
            local a = i / 6 * math.pi * 2
            Part(model, { Name = "Deco_Shard", Size = Vector3.new(0.3, 2.6, 1.4), Color = PALE, Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.4,
                CFrame = M(math.cos(a) * 7, 1 + (i % 2) * 2.4, math.sin(a) * 7) * CFrame.Angles(0, -a, math.rad(15)) })
        end
        -- its echoes: two faint copies standing behind it
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "Deco_Ghost", Size = Vector3.new(4.5, 9, 4.5), CFrame = M(sx * 4.2, 0, 4.5) * CFrame.Angles(0, math.rad(45), 0), Color = PURPLE, Glow = true, Transparency = 0.82 }) -- (ForceField rendered as a mint-green box)
        end
        -- (0.53 detail pass) a crown of mirror blades, a hanging cape of mirror shards, a second slower shard ring, an
        -- inner light seen through the glass shell
        for k = 0, 6 do
            local a = (k - 3) * math.rad(22)
            Wedge(model, { Name = "MirrorCrown", Size = Vector3.new(0.25, 1.6 + (3 - math.abs(k - 3)) * 0.5, 0.9), Color = PALE, Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.4,
                CFrame = M(math.sin(a) * 1.5, 8.2, math.cos(a) * 0.4 - 0.2) * CFrame.Angles(0, -a, math.rad(math.deg(a) * 0.4)) })
        end
        for k = 0, 8 do
            local x = (k - 4) * 0.95
            Part(model, { Name = "Plume", Size = Vector3.new(0.85, 4 + (k % 3) * 1.2, 0.12), Color = (k % 2 == 0) and PALE or PURPLE, Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.35,
                CFrame = M(x, 1.2 - (k % 3) * 0.6, 2.9 + math.abs(k - 4) * -0.15) * CFrame.Angles(math.rad(-8), 0, math.rad((k - 4) * 3)) })
        end
        for i2 = 0, 7 do
            local a = i2 / 8 * math.pi * 2
            Part(model, { Name = "Shard", Size = Vector3.new(0.25, 1.4, 0.8), Color = PURPLE, Glow = true,
                CFrame = M(math.cos(a) * 10, -2 + (i2 % 2) * 1.2, math.sin(a) * 10) * CFrame.Angles(0, -a, 0) })
        end
        Part(model, { Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.2, CFrame = M(0, 0, 0), Color = PURPLE, Glow = true, Transparency = 0.4 })
    elseif id == "Forgeheart" then
        -- a hunched furnace golem: slag plates cracked with lava, a furnace mouth on its chest (the Core), two smoking
        -- chimneys on its back, a forge hammer in its right fist. Its three BRANDS (white-hot plates, the only parts that
        -- take full damage -- CombatServer) are hittable and crawl over its body (BossAI Forgeheart.Animate).
        local SLAG, IRON, MOLTEN, HOT = Color3.fromRGB(46, 38, 36), Color3.fromRGB(62, 56, 54), Color3.fromRGB(255, 120, 30), Color3.fromRGB(255, 236, 190)
        local BASALT = Enum.Material.Basalt
        -- legs + feet, glowing knee seams
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "Leg", Size = Vector3.new(3, 5, 3.4), CFrame = M(sx * 2.6, -6.2, 0.2), Color = SLAG, Material = BASALT })
            Part(model, { Name = "Foot", Size = Vector3.new(3.6, 1.2, 4.8), CFrame = M(sx * 2.6, -8.6, -0.4), Color = IRON, Material = METAL })
            Part(model, { Name = "KneeSeam", Size = Vector3.new(3.06, 0.25, 3.46), CFrame = M(sx * 2.6, -5.4, 0.2), Color = MOLTEN, Glow = true })
        end
        Part(model, { Name = "Belt", Size = Vector3.new(9.4, 1.3, 6.4), CFrame = M(0, -4.2, 0), Color = IRON, Material = METAL, Reflectance = 0.1 })
        for i = -3, 3 do
            Part(model, { Name = "Rivet", Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45), CFrame = M(i * 1.25, -4.2, -3.2), Color = Color3.fromRGB(110, 100, 92), Material = METAL })
        end
        -- lava cracks running over the chest and flanks
        for _, c in ipairs({ { -3.1, 2.2, 25, 3.2 }, { -2.4, -2.6, -35, 2.4 }, { 3.0, 2.0, -20, 3.4 }, { 2.6, -2.4, 40, 2.2 }, { 0.8, 2.9, 80, 2.6 } }) do
            Part(model, { Name = "Crack", Size = Vector3.new(0.22, c[4], 0.1), CFrame = M(c[1], c[2], -3.03) * CFrame.Angles(0, 0, math.rad(c[3])), Color = MOLTEN, Glow = true })
        end
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "Crack", Size = Vector3.new(0.1, 4.2, 0.22), CFrame = M(sx * 4.53, 0.4, 0.6) * CFrame.Angles(math.rad(sx * 22), 0, 0), Color = MOLTEN, Glow = true })
        end
        -- the furnace mouth framing the core: an iron frame, a glowing back plate, grate bars in front (not hittable)
        local fz = -3.15
        Part(model, { Name = "MouthGlow", Size = Vector3.new(3.4, 3.0, 0.1), CFrame = M(0, -0.8, -2.98), Color = MOLTEN, Glow = true })
        Part(model, { Name = "MouthTop", Size = Vector3.new(4.6, 0.8, 0.9), CFrame = M(0, 1.1, fz), Color = IRON, Material = METAL, Reflectance = 0.12 })
        Part(model, { Name = "MouthLip", Size = Vector3.new(4.6, 0.8, 1.2), CFrame = M(0, -2.7, fz - 0.15), Color = IRON, Material = METAL, Reflectance = 0.12 })
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "MouthSide", Size = Vector3.new(0.8, 3.0, 0.9), CFrame = M(sx * 1.9, -0.8, fz), Color = IRON, Material = METAL, Reflectance = 0.12 })
        end
        for i = -1, 1 do
            Part(model, { Name = "Grate", Size = Vector3.new(0.18, 3.0, 0.18), CFrame = M(i * 0.85, -0.8, fz - 0.5), Color = Color3.fromRGB(30, 26, 24), Material = METAL })
        end
        -- head: a slag helm with a white-hot visor slit and a crown of cooling spikes
        Part(model, { Name = "Helm", Size = Vector3.new(3.4, 2.4, 3.2), CFrame = M(0, 4.9, -0.9), Color = SLAG, Material = BASALT })
        Part(model, { Name = "Visor", Size = Vector3.new(2.2, 0.32, 0.12), CFrame = M(0, 4.9, -2.52), Color = HOT, Glow = true })
        for i = -1, 1 do
            Wedge(model, { Name = "Spike", Size = Vector3.new(0.7, 1.6 - math.abs(i) * 0.4, 1.4), CFrame = M(i * 1.1, 6.6 - math.abs(i) * 0.2, -0.9), Color = SLAG, Material = BASALT })
        end
        -- shoulders: massive pauldrons with lava seams
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "Pauldron", Size = Vector3.new(4.2, 3.2, 5.4), CFrame = M(sx * 5.4, 3.0, 0) * CFrame.Angles(0, 0, math.rad(-sx * 14)), Color = SLAG, Material = BASALT })
            Part(model, { Name = "PauldronSeam", Size = Vector3.new(4.25, 0.22, 5.45), CFrame = M(sx * 5.4, 2.4, 0) * CFrame.Angles(0, 0, math.rad(-sx * 14)), Color = MOLTEN, Glow = true })
        end
        -- left arm: a fist like an anvil
        Part(model, { Name = "ArmL", Size = Vector3.new(2.4, 4.6, 2.4), CFrame = M(-6.3, -0.6, 0), Color = SLAG, Material = BASALT })
        Part(model, { Name = "FistL", Size = Vector3.new(3.2, 3.0, 3.4), CFrame = M(-6.5, -4.0, -0.4), Color = IRON, Material = METAL, Reflectance = 0.1 })
        Wedge(model, { Name = "FistHorn", Size = Vector3.new(3.2, 1.0, 1.6), CFrame = M(-6.5, -3.0, -2.9), Color = IRON, Material = METAL })
        -- right arm + THE HAMMER (posed about the shoulder: raised for HAMMERFALL)
        Part(model, { Name = "Deco_HammerArm", Size = Vector3.new(2.4, 4.6, 2.4), CFrame = M(6.3, -0.6, 0), Color = SLAG, Material = BASALT })
        Part(model, { Name = "Deco_HammerFist", Size = Vector3.new(3.0, 2.6, 3.0), CFrame = M(6.5, -3.6, -0.6), Color = IRON, Material = METAL, Reflectance = 0.1 })
        Part(model, { Name = "Deco_HammerHaft", Size = Vector3.new(0.7, 9, 0.7), CFrame = M(6.5, -3.6, -3.4) * CFrame.Angles(math.rad(90), 0, 0), Color = Color3.fromRGB(70, 46, 30), Material = Enum.Material.Wood })
        Part(model, { Name = "Deco_HammerHead", Size = Vector3.new(3.4, 2.6, 2.6), CFrame = M(6.5, -3.6, -8.2), Color = IRON, Material = METAL, Reflectance = 0.15 })
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "Deco_HammerFace", Size = Vector3.new(0.12, 2.2, 2.2), CFrame = M(6.5 + sx * 1.74, -3.6, -8.2), Color = MOLTEN, Glow = true })
        end
        -- chimneys on the back: smoke always, flame from phase 2 (BossAI)
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "Chimney", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 1.5, 1.5), CFrame = M(sx * 2.2, 6.4, 2.6) * CFrame.Angles(0, 0, math.rad(90)), Color = IRON, Material = METAL })
            local top = Part(model, { Name = "ChimneyTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.8, 1.8), CFrame = M(sx * 2.2, 9.0, 2.6) * CFrame.Angles(0, 0, math.rad(90)), Color = MOLTEN, Glow = true })
            local smoke = Instance.new("ParticleEmitter")
            smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"; smoke.Rate = 6; smoke.Lifetime = NumberRange.new(2, 3)
            smoke.Speed = NumberRange.new(5, 8); smoke.SpreadAngle = Vector2.new(12, 12); smoke.Size = NumberSequence.new(1.4, 4)
            smoke.Color = ColorSequence.new(Color3.fromRGB(50, 44, 42)); smoke.Transparency = NumberSequence.new(0.4, 1)
            smoke.EmissionDirection = Enum.NormalId.Right; smoke.Parent = top
            local flame = Instance.new("ParticleEmitter")
            flame.Name = "ForgeFlame"; flame.Texture = "rbxasset://textures/particles/fire_main.dds"; flame.Rate = 0; flame.Lifetime = NumberRange.new(0.3, 0.5)
            flame.Speed = NumberRange.new(6, 9); flame.Size = NumberSequence.new(1.2, 0.2); flame.LightEmission = 0.8
            flame.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 70, 20)); flame.EmissionDirection = Enum.NormalId.Right; flame.Parent = top
        end
        -- THE BRANDS: hittable white-hot plates (named "Brand"; BossAI moves them over the shell every frame)
        for i = 1, 3 do
            local brand = Part(model, { Name = "Brand", Size = Vector3.new(1.7, 1.7, 0.45), CFrame = M(0, 0, -3.3), Color = HOT, Glow = true, CanQuery = true })
            brand:SetAttribute("Damageable", true)
            brand:SetAttribute("BrandIndex", i)
            local rim = Part(model, { Name = "BrandRim", Size = Vector3.new(2.3, 2.3, 0.2), CFrame = M(0, 0, -3.2), Color = MOLTEN, Glow = true, Transparency = 0.25 })
            rim:SetAttribute("BrandIndex", i)
            local spark = Instance.new("ParticleEmitter")
            spark.Texture = "rbxasset://textures/particles/sparkles_main.dds"; spark.Rate = 8; spark.Lifetime = NumberRange.new(0.3, 0.6)
            spark.Speed = NumberRange.new(2, 5); spark.SpreadAngle = Vector2.new(60, 60); spark.Size = NumberSequence.new(0.35, 0)
            spark.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140)); spark.LightEmission = 1; spark.EmissionDirection = Enum.NormalId.Front; spark.Parent = brand
        end
    end
end

-- (0.89 WORLD FOES: the world superbosses' hit zones + bodies, and the world rosters' looks)
do
    local ok, WF = pcall(require, script.Parent:WaitForChild("WorldFoes"))
    if ok then
        EnemyModels.WorldDecor = WF.Decor
        local H = { Part = Part, Wedge = Wedge, Emit = Emit, Style = Style, Chain = Chain, NEON = NEON, METAL = METAL, SMOOTH = SMOOTH }
        for id, sup in pairs(WF.Super) do
            EnemyModels.SUPER_HITBOX[id] = sup.Hitbox
            EnemyModels.SUPER_COLOR[id] = sup.Color
            SUPER_BODIES[id] = function(model, M, col) sup.Body(model, M, col, H) end
        end
    end
end

-- BOSSES: EVERY PART TAKES HITS (0.91, owner: "All parts of the boss should be hittable, the current outline system I wanted
-- doesn't really make sense"). Each boss decorator is wrapped: afterwards every visible decoration (armour, legs, cannons,
-- crowns, capes, the decoration on world superbosses...) is queryable and counts as a BODY hit (HitAs "Torso"). The head
-- (+ its lime WEAK POINT glow) stays the only weak spot; mechanic parts (ShieldOrb / BreakPart / Brand / plates) keep their
-- own names + rules. Moving decoration is fine: hits read the part's current position.
local MECH_PREFIX = { "ShieldOrb", "BreakPart", "Brand", "CoolantPlate", "LightningRod", "LockTile", "WeakGlow" }
function EnemyModels.MakeBossHittable(model: Model)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and not d.CanQuery and not GAMEPLAY_PARTS[d.Name] and d.Transparency < 0.6 then
            local mech = false
            for _, pre in ipairs(MECH_PREFIX) do if string.sub(d.Name, 1, #pre) == pre then mech = true break end end
            if not mech and d.Size.Magnitude > 0.4 then
                d.CanQuery = true
                d:SetAttribute("HitAs", "Torso")
            end
        end
    end
end
for _, k in ipairs({ "DecorateBoss", "DecorateTrialBoss", "DecorateAscendant" }) do
    local fn = EnemyModels[k]
    EnemyModels[k] = function(model, ...)
        local r = table.pack(fn(model, ...))
        EnemyModels.MakeBossHittable(model)
        return table.unpack(r, 1, r.n)
    end
end

-- ==================== PILL BOTS (0.97) ====================
-- Owner: "I want the mobs in the game to look like kovaaks pills ... for the most part, bots should be varients of this.
-- fliers can be a mix between these or just a simple sphere, like the head here. In cases of enemies just being spheres,
-- the weakpoint can be deadcenter of it ... each of them have some simple, non-obstructive decorations that match the
-- biome ... Make the colors of the bots dependent on the area too, JUST MAKE SURE THE COLORS OF THE BOTS CONTRAST WITH ALL OF
-- THE COLORS IN THAT BIOME ... these should be little things that just add a slight bit of personality" (regular mobs +
-- elites; bosses keep their models).
--   EnemyModels.Pill(model, { Arch, Pos, Body, Head, Ground, LegH, Color, HeadColor, Biome, Scale, Tiny })
-- WALKERS: one tall capsule from the floor to the top of the torso with the head sphere on top. FLIERS: a shorter capsule
-- with the head on top; TINY fliers: a plain sphere whose weak spot (the Head) sits dead centre on the face that looks at
-- you. The Torso / Head parts stay the hitboxes (the Torso turns invisible under the capsule; the capsule pieces are hittable
-- as the Torso through MakeHittable). Accents: 2-4 small biome pieces, never in front of the weak spot.
EnemyModels.PILL_BOTS = true
local ACCENT_OF = { -- biome -> accent kind (unlisted: by element-ish family below)
    Jungle = "Vines", Autumn = "Leaf", Sakura = "Petals", Fungal = "Caps", Desert = "Wrap", Abyss = "Lure", Gothic = "Halo",
    Bayou = "Moss", Sky = "Fin", Station = "Band", Aztec = "Crown", Waste = "Drip",
    Fire = "Embers", Ice = "Frost", Void = "Halo", Cyber = "Band", Storm = "Bolt", Dream = "Star", Flats = "Stripe",
}
local function PillAccent(model, kind, cf, r, h, color, headCF, hs)
    local dark = color:Lerp(Color3.new(0, 0, 0), 0.45)
    local lite = color:Lerp(Color3.new(1, 1, 1), 0.55)
    if kind == "Vines" then
        local VINE, LEAF = Color3.fromRGB(46, 120, 52), Color3.fromRGB(80, 170, 70)
        for k = 0, 4 do
            local a = k * 1.25
            Part(model, { Name = "Tendril", Size = Vector3.new(0.09, h * 0.22, 0.09), CFrame = cf * CFrame.new(math.cos(a) * r * 1.01, -h * 0.3 + k * h * 0.13, math.sin(a) * r * 1.01)
                * CFrame.Angles(0, -a, math.rad(35)), Color = VINE })
        end
        Wedge(model, { Name = "Leaf", Size = Vector3.new(0.04, r * 0.5, r * 0.32), CFrame = headCF * CFrame.new(hs * 0.3, hs * 0.5, hs * 0.1) * CFrame.Angles(0, 0, math.rad(-30)), Color = LEAF, Material = SMOOTH })
    elseif kind == "Leaf" then
        Wedge(model, { Name = "Leaf", Size = Vector3.new(0.05, r * 0.6, r * 0.4), CFrame = headCF * CFrame.new(hs * 0.25, hs * 0.55, 0) * CFrame.Angles(0, 0, math.rad(-25)), Color = Color3.fromRGB(214, 110, 40), Material = SMOOTH })
    elseif kind == "Petals" then
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "Ear", Shape = Enum.PartType.Ball, Size = Vector3.new(hs * 0.18, hs * 0.36, hs * 0.1), CFrame = headCF * CFrame.new(sx * hs * 0.32, hs * 0.48, 0) * CFrame.Angles(0, 0, math.rad(-sx * 25)),
                Color = Color3.fromRGB(255, 176, 206) })
        end
    elseif kind == "Caps" then
        for _, sx in ipairs({ -1, 1 }) do
            Part(model, { Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.5, r * 0.26, r * 0.5), CFrame = cf * CFrame.new(sx * r * 0.75, h * 0.32, r * 0.15), Color = Color3.fromRGB(196, 70, 60) })
        end
    elseif kind == "Wrap" then
        Part(model, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h * 0.08, r * 2.06, r * 2.06), CFrame = cf * CFrame.new(0, h * 0.18, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(214, 190, 140) })
        Part(model, { Name = "Streamer", Size = Vector3.new(r * 0.3, h * 0.25, 0.05), CFrame = cf * CFrame.new(r * 0.4, h * 0.05, r * 1.02), Color = Color3.fromRGB(214, 190, 140) })
    elseif kind == "Lure" then
        Part(model, { Name = "Tendril", Size = Vector3.new(0.06, hs * 0.7, 0.06), CFrame = headCF * CFrame.new(0, hs * 0.75, 0), Color = dark })
        Part(model, { Name = "Tip", Shape = Enum.PartType.Ball, Size = Vector3.new(hs * 0.22, hs * 0.22, hs * 0.22), CFrame = headCF * CFrame.new(0, hs * 1.12, 0), Color = Color3.fromRGB(120, 255, 230), Glow = true })
    elseif kind == "Halo" then
        Part(model, { Name = "ArmorRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, hs * 1.35, hs * 1.35), CFrame = headCF * CFrame.new(0, hs * 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = lite })
    elseif kind == "Moss" then
        for k = 0, 2 do
            Part(model, { Name = "Tendril", Size = Vector3.new(0.12, h * 0.16, 0.05), CFrame = cf * CFrame.new((k - 1) * r * 0.5, h * 0.2, r * 0.98), Color = Color3.fromRGB(70, 96, 54) })
        end
    elseif kind == "Fin" then
        Wedge(model, { Name = "Fin", Size = Vector3.new(0.06, h * 0.22, r * 0.9), CFrame = cf * CFrame.new(0, h * 0.18, r * 0.75), Color = lite, Material = SMOOTH })
    elseif kind == "Band" then
        Part(model, { Name = "LightStrip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h * 0.035, r * 2.04, r * 2.04), CFrame = cf * CFrame.new(0, h * 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = lite, Glow = true })
        Part(model, { Name = "Tendril", Size = Vector3.new(0.05, hs * 0.5, 0.05), CFrame = headCF * CFrame.new(hs * 0.25, hs * 0.65, 0), Color = dark })
    elseif kind == "Crown" then
        for k = -1, 1 do
            Wedge(model, { Name = "Spike", Size = Vector3.new(0.06, hs * 0.3, hs * 0.2), CFrame = headCF * CFrame.new(k * hs * 0.24, hs * 0.58, hs * 0.05), Color = Color3.fromRGB(240, 196, 70), Material = METAL })
        end
    elseif kind == "Drip" then
        for k = 0, 2 do
            Part(model, { Name = "Vein", Size = Vector3.new(0.1, h * (0.12 + k * 0.05), 0.06), CFrame = cf * CFrame.new((k - 1) * r * 0.55, h * (0.3 - k * 0.03), -r * 0.95), Color = Color3.fromRGB(150, 230, 70), Glow = true })
        end
    elseif kind == "Embers" then
        for _, c in ipairs({ { -0.45, 0.2, 25 }, { 0.4, -0.05, -35 } }) do
            Part(model, { Name = "Crack", Size = Vector3.new(0.08, h * 0.18, 0.06), CFrame = cf * CFrame.new(r * c[1], h * c[2], r * 0.92) * CFrame.Angles(0, 0, math.rad(c[3])), Color = Color3.fromRGB(255, 150, 50), Glow = true })
        end
    elseif kind == "Frost" then
        Wedge(model, { Name = "Crystal", Size = Vector3.new(0.08, hs * 0.38, hs * 0.26), CFrame = headCF * CFrame.new(0, hs * 0.6, hs * 0.05), Color = Color3.fromRGB(200, 240, 255), Material = Enum.Material.Ice, Transparency = 0.1 })
    elseif kind == "Bolt" then
        Wedge(model, { Name = "Tip", Size = Vector3.new(0.05, hs * 0.4, hs * 0.16), CFrame = headCF * CFrame.new(hs * 0.2, hs * 0.62, 0) * CFrame.Angles(0, 0, math.rad(-20)), Color = Color3.fromRGB(255, 240, 120), Glow = true })
    elseif kind == "Star" then
        Part(model, { Name = "StarPoint", Size = Vector3.new(hs * 0.22, hs * 0.22, 0.05), CFrame = cf * CFrame.new(r * 0.45, h * 0.22, -r * 0.98) * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(255, 236, 140), Glow = true })
    elseif kind == "Stripe" then
        Part(model, { Name = "LightStrip", Size = Vector3.new(r * 0.22, h * 0.7, 0.05), CFrame = cf * CFrame.new(r * 0.38, 0, -r * 0.97), Color = lite, Glow = true })
    end
end

-- capsule pieces (Cylinder lies along X: turned to stand up)
local function Capsule(model, centre: CFrame, r: number, h: number, color: Color3)
    local len = math.max(0.05, h - 2 * r)
    Part(model, { Name = "PillBody", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, r * 2, r * 2), CFrame = centre * CFrame.Angles(0, 0, math.rad(90)), Color = color })
    Part(model, { Name = "PillCap", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 2, r * 2, r * 2), CFrame = centre * CFrame.new(0, len / 2, 0), Color = color })
    Part(model, { Name = "PillCap", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 2, r * 2, r * 2), CFrame = centre * CFrame.new(0, -len / 2, 0), Color = color })
end

function EnemyModels.Pill(model, o)
    local pos, body, hd = o.Pos, o.Body, o.Head
    local torso, head = model:FindFirstChild("Torso"), model:FindFirstChild("Head")
    local visor = model:FindFirstChild("Visor")
    if visor then visor.Transparency = 1 end
    local color, headColor = o.Color, o.HeadColor or o.Color:Lerp(Color3.new(1, 1, 1), 0.35)
    local hs = hd.X
    local r, h, centre
    if o.Tiny and not o.Ground then
        -- a plain sphere; the weak spot is a disc-like ball dead centre on its face (models look at you along -Z)
        r = math.max(body.X, body.Z) * 0.5
        h = r * 2
        centre = CFrame.new(pos)
        if torso then torso.Color = color; torso.Material = SMOOTH; torso.Transparency = 0 end
        if head then
            local d = hs * 0.8
            head.Size = Vector3.new(d, d, d)
            head.CFrame = CFrame.new(pos) * CFrame.new(0, 0, -(r - d * 0.22))
            head.Color = headColor
        end
        PillAccent(model, ACCENT_OF[o.Biome or ""], centre, r * 0.9, h, color, centre * CFrame.new(0, r * 0.55, 0), hs * 0.9)
        return {}
    end
    if o.Ground then
        r = body.X * 0.5
        local bottom = pos.Y - body.Y / 2 - (o.LegH or 0)
        local top = pos.Y + body.Y / 2
        h = top - bottom
        centre = CFrame.new(pos.X, (top + bottom) / 2, pos.Z)
    else
        r = body.X * 0.5
        h = body.Y * 1.25
        centre = CFrame.new(pos)
    end
    Capsule(model, centre, r, h, color)
    if torso then torso.Transparency = 1 end
    local headCF = head and head.CFrame or (centre * CFrame.new(0, h / 2 + hs / 2, 0))
    if head then
        headCF = CFrame.new(centre.Position + Vector3.new(0, h / 2 + hs * 0.42, 0))
        head.CFrame = headCF
        head.Color = headColor
    end
    PillAccent(model, ACCENT_OF[o.Biome or ""], centre, r, h, color, headCF, hs)
    return {}
end

return EnemyModels
