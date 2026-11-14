--!nocheck
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local HubGenerator = {}

-- HUB v4 "FRONTIER KEEP" (2026-10-05): an open-air walled outpost at dusk on a terrain plateau -- curtain walls +
-- watchtowers, a cobbled plaza round the Waypoint obelisk (Centerpiece rings), the two gates north, stations as kit
-- buildings (EnvKit meshes, ReplicatedStorage.EnvKit.Hub) down both sides, the Training Grounds yard south of the
-- gatehouse. Anchor part names / attributes / prompts are a contract with the server + client: keep them.
-- (SCALE / WALL_HEIGHT / CEILING_Y below are left from the enclosed v3 hall; only some helpers still use them.)
local SCALE = 1.6
local WALL_HEIGHT = 48
local FLOOR_HALF = 75 -- 150x150 floor (compact: every station is a short walk)
local WALL_Z = FLOOR_HALF + 1
local CEILING_Y = WALL_HEIGHT + 1

local function MakePart(props: { [string]: any }): Part
    local p = Instance.new("Part")
    p.Anchored = true
    p.Material = Enum.Material.SmoothPlastic
    for k, v in pairs(props) do
        (p :: any)[k] = v
    end
    return p
end

-- Floating name tag above a station. Sized in STUDS (scale), so it shrinks with distance like a real
-- sign instead of staying a fixed-size block on screen (which made far stations' tags pile up over
-- everything); hidden past MaxDistance. Same chunky outlined look as the menus.
local function MakeTitle(adornee: BasePart, mainText: string, subText: string?, accentColor: Color3, yOffset: number): BillboardGui
    local bb = Instance.new("BillboardGui")
    bb.Name = "TitleSign"
    bb.Size = UDim2.fromScale(8, subText and 2 or 1.3)
    bb.StudsOffset = Vector3.new(0, yOffset, 0)
    bb.AlwaysOnTop = false
    bb.LightInfluence = 0
    bb.MaxDistance = 55
    bb.Adornee = adornee
    bb.Parent = adornee

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.fromScale(1, 1)
    panel.BackgroundColor3 = Color3.new(1, 1, 1)
    panel.BackgroundTransparency = 0.1
    panel.BorderSizePixel = 0
    panel.Parent = bb
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.25, 0)
    corner.Parent = panel
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new(Color3.fromRGB(34, 40, 62), Color3.fromRGB(18, 21, 34))
    grad.Rotation = 90
    grad.Parent = panel
    local stroke = Instance.new("UIStroke")
    stroke.Color = accentColor
    stroke.Thickness = 2
    stroke.Parent = panel

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.BackgroundTransparency = 1
    title.Size = subText and UDim2.fromScale(0.92, 0.56) or UDim2.fromScale(0.92, 0.8)
    title.Position = subText and UDim2.fromScale(0.04, 0.06) or UDim2.fromScale(0.04, 0.1)
    title.Font = Enum.Font.FredokaOne
    title.TextScaled = true
    title.TextColor3 = accentColor
    title.Text = mainText
    title.Parent = panel
    local tStroke = Instance.new("UIStroke")
    tStroke.Color = Color3.fromRGB(10, 12, 20)
    tStroke.Thickness = 1.5
    tStroke.Parent = title

    if subText then
        local sub = Instance.new("TextLabel")
        sub.Name = "Subtitle"
        sub.BackgroundTransparency = 1
        sub.Size = UDim2.fromScale(0.92, 0.3)
        sub.Position = UDim2.fromScale(0.04, 0.62)
        sub.Font = Enum.Font.GothamBold
        sub.TextScaled = true
        sub.TextColor3 = Color3.fromRGB(200, 208, 225)
        sub.Text = subText
        sub.Parent = panel
    end

    return bb
end

-- Small ceiling-mounted fixture (a housing block + downward SpotLight) used to fill the now-enclosed
-- interior with light, since the old open-sky plaza relied on outdoor sun/ambient alone.
local function MakeCeilingLight(pos: Vector3, color: Color3, brightness: number?): Part
    local housing = MakePart({
        Name = "CeilingLightFixture",
        Size = Vector3.new(3, 1, 3),
        Position = pos,
        BrickColor = BrickColor.new("Black"),
        Material = Enum.Material.Metal,
        Parent = Workspace,
    })
    local lens = MakePart({
        Name = "Lens",
        Size = Vector3.new(2, 0.2, 2),
        Position = pos - Vector3.new(0, 0.6, 0),
        BrickColor = BrickColor.new("Institutional white"),
        Material = Enum.Material.Neon,
        CanCollide = false,
        CanQuery = false,
        Parent = housing,
    })
    lens.Color = color
    local spot = Instance.new("SpotLight")
    spot.Face = Enum.NormalId.Bottom
    spot.Range = 55
    spot.Angle = 110
    spot.Brightness = brightness or 3.5
    spot.Color = color
    spot.Shadows = false -- 12 of these fill the hub; shadow-casting lights are the priciest thing on the GPU
    spot.Parent = lens
    return housing
end

function HubGenerator.SetupLighting()
    -- (HUBFIX 2026-10-24, owner: "The hub is incredibly dark and hard to see now, there's no night skybox"): the server no
    -- longer sets the clock / brightness / ambient or makes its own warm Haze-1.6 Atmosphere. Every client sets the light
    -- itself (AimRngClient LIGHT_PROFILES), but in a Studio playtest these server writes replicated AFTER the client's hub
    -- profile: clock 0.5 (a painted sky goes black at a night clock), a second hazy Atmosphere (a flat wall over the sky)
    -- and the server's dim ambient -- the owner tested a darker hub than live players get. Lighting is only ever drawn on
    -- clients, so the server leaves it alone and Studio Play == live.
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
    bloom.Intensity = 0.3
    bloom.Size = 22
    bloom.Threshold = 1.4
    bloom.Parent = Lighting
end

function HubGenerator.SpawnSinglePracticeDrone(spawnPos: Vector3): Model
    local hub = Workspace:FindFirstChild("HubWorld")
    local parent = hub or Workspace

    local model = Instance.new("Model")
    model.Name = "PracticeTargetDrone"
    -- Same toughness as a level-1 Easy Scout (the practice range is for warming up your aim).
    model:SetAttribute("Health", 30)
    model:SetAttribute("MaxHealth", 30)
    model:SetAttribute("XpReward", 20)
    model:SetAttribute("IsPracticeDummy", true)
    model:SetAttribute("SpawnPos", spawnPos)

    local root = MakePart({
        Name = "DroneRoot",
        Size = Vector3.new(2, 2, 2),
        Position = spawnPos,
        Transparency = 1,
        CanCollide = false,
        CanTouch = false,
        CanQuery = false,
        Parent = model,
    })
    model.PrimaryPart = root

    local torso = MakePart({
        Name = "Torso",
        Size = Vector3.new(2.8, 3.6, 1.2),
        CFrame = CFrame.new(spawnPos),
        BrickColor = BrickColor.new("Dark stone grey"),
        Material = Enum.Material.Metal,
        CanCollide = true,
        CanQuery = true,
        Parent = model,
    })

    -- Precision Head Hitbox (2x2 stud sphere)
    local head = MakePart({
        Name = "Head",
        Shape = Enum.PartType.Ball,
        Size = Vector3.new(2.0, 2.0, 2.0),
        CFrame = CFrame.new(spawnPos + Vector3.new(0, 2.6, 0)),
        BrickColor = BrickColor.new("Really red"),
        Material = Enum.Material.Neon,
        CanCollide = true,
        CanQuery = true,
        Parent = model,
    })

    -- Precision Core Hitbox (1.6 stud disc)
    local core = MakePart({
        Name = "Core",
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(0.6, 1.6, 1.6),
        CFrame = CFrame.new(spawnPos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        BrickColor = BrickColor.new("Deep orange"),
        Material = Enum.Material.Neon,
        CanCollide = true,
        CanQuery = true,
        Parent = model,
    })

    for _, p in ipairs({ torso, head, core }) do
        p.Anchored = true
        p:SetAttribute("Damageable", true)
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "HealthHUD"
    billboard.Enabled = false -- (never shown: EnemyBars draws every bar; an enabled one doubled the name + bar)
    billboard.Size = UDim2.new(0, 90, 0, 14)
    billboard.StudsOffset = Vector3.new(0, 4.0, 0)
    billboard.AlwaysOnTop = false
    billboard.MaxDistance = 60
    billboard.Adornee = head
    billboard.Parent = model

    local bgBar = Instance.new("Frame")
    bgBar.Name = "Background"
    bgBar.Size = UDim2.new(1, 0, 1, 0)
    bgBar.BackgroundColor3 = Color3.fromRGB(15, 20, 25)
    bgBar.BorderSizePixel = 1
    bgBar.BorderColor3 = Color3.fromRGB(255, 60, 60)
    bgBar.Parent = billboard

    local fillBar = Instance.new("Frame")
    fillBar.Name = "Fill"
    fillBar.Size = UDim2.new(1, 0, 1, 0)
    fillBar.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    fillBar.BorderSizePixel = 0
    fillBar.Parent = bgBar

    local tag = Instance.new("TextLabel")
    tag.Size = UDim2.new(1, 0, 1, 0)
    tag.BackgroundTransparency = 1
    tag.Font = Enum.Font.GothamBold
    tag.TextSize = 9
    tag.TextColor3 = Color3.fromRGB(255, 255, 255)
    tag.Text = "PRACTICE TARGET"
    tag.Parent = bgBar

    -- Matte body, dimmed weak spots (full Neon drones bloomed into blinding blobs).
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
            if d.Name == "Head" then -- (0.76: one weak spot)
                d.Color = d.Color:Lerp(Color3.new(0, 0, 0), 0.35)
            else
                d.Material = Enum.Material.SmoothPlastic
            end
        end
    end
    game:GetService("CollectionService"):AddTag(model, "AimRngEnemy")
    model.Parent = parent
    return model
end

-- ============================================================================================
-- HUB v2 (session 4): the Gate Hall.
--   North wall: two matching giant gates -- DUNGEONS (left) and CHALLENGES (right) -- with stairs,
--   braziers, a glowing vortex you can walk into, and a lit runway from the spawn to each.
--   West + east walls: themed station booths (counter, canopy, neon sign, a prop that says what it is)
--   under the live leaderboard walls (10 boards; the client draws them -- HubBoards).
--   South wall: a big doorway into the TRAINING GROUNDS (Rivals-style range): a firing line with 13 bays --
--   a DPS test in the middle and one bay per bot type; stand on a bay's pad to start it (RangeClient).
-- Names the server script hooks prompts by (RollAltar, TreeAltar, InvLocker, UpgradeAnvil, ShopStand,
-- IndexAltar, PortalVortex) are kept as direct children of HubWorld.
-- ============================================================================================
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("AimRngShared"):WaitForChild("Remotes"))

local HALL_H = 80
local FLOOR_TOP = 1.5

-- Training Grounds geometry (shared with the client through attributes on the zone pads)
HubGenerator.RANGE = {
    Z0 = 75, LineZ = 98, Z1 = 240, HalfX = 156, BayW = 24, FloorTop = 2, Height = 40,
    Bays = { "Tracker", "Strafer", "Drifter", "Blinker", "Hopper", "Charger", "DPS", "Juggernaut", "Sniper", "Runner", "Skirmisher", "Warden", "Gunship" },
}

local function P(parent: Instance, props: { [string]: any }): Part
    local p = MakePart(props)
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

-- A part placed in a local frame (cf * offset * rotation).
local function L(parent: Instance, cf: CFrame, size: Vector3, offset: Vector3, props: { [string]: any }, rot: CFrame?): Part
    props.Size = size
    props.CFrame = cf * CFrame.new(offset) * (rot or CFrame.identity)
    return P(parent, props)
end

local function Neon(parent: Instance, cf: CFrame, size: Vector3, offset: Vector3, color: Color3, transp: number?, rot: CFrame?): Part
    return L(parent, cf, size, offset, { Color = color, Material = Enum.Material.Neon, Transparency = transp or 0, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }, rot)
end

local function Light(parent: Instance, class: string, props: { [string]: any })
    local l = Instance.new(class)
    for k, v in pairs(props) do (l :: any)[k] = v end
    l.Parent = parent
    return l
end

-- Big text sign on one face of a part (server-built SurfaceGui; replicates to everyone).
local function Sign(part: BasePart, face: Enum.NormalId, title: string, sub: string?, color: Color3, ppsOverride: number?, style: string?)
    local sg = Instance.new("SurfaceGui")
    sg.Name = "Sign"
    sg.Face = face
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = ppsOverride or 30
    sg.LightInfluence = 0
    sg.Brightness = 1.6
    sg.Parent = part
    -- (MEGA-CITY, 2026-10-04: a billboard -- a dark plate, the station's colour as a block on the left, condensed caps,
    -- a hazard strip along the bottom -- not bubbly letters outlined in black straight on the wall)
    local plate = Instance.new("Frame")
    plate.Name = "Plate"; plate.BackgroundColor3 = Color3.fromRGB(12, 12, 14); plate.BackgroundTransparency = 0.12
    if style == "Wood" then plate.BackgroundTransparency = 1 end -- (HUB v4: a painted wooden board -- the part shows through)
    plate.BorderSizePixel = 0; plate.Size = UDim2.fromScale(1, 1); plate.Parent = sg
    local block = Instance.new("Frame")
    block.Name = "Block"; block.BackgroundColor3 = color; block.BorderSizePixel = 0; block.Size = UDim2.fromScale(0.012, 1); block.Parent = plate
    local rule = Instance.new("Frame")
    rule.Name = "Rule"; rule.BackgroundColor3 = color; rule.BorderSizePixel = 0; rule.BackgroundTransparency = 0.3
    rule.Size = UDim2.fromScale(1, 0.025); rule.Parent = plate
    local hz = Instance.new("ImageLabel")
    hz.Name = "Hazard"; hz.BackgroundTransparency = 1; hz.Image = "rbxassetid://123887840862473" -- (UIStyle.Art.Hazard)
    hz.ScaleType = Enum.ScaleType.Tile; hz.TileSize = UDim2.fromOffset(24, 24); hz.ImageTransparency = 0.2
    hz.AnchorPoint = Vector2.new(0, 1); hz.Position = UDim2.fromScale(0, 1); hz.Size = UDim2.fromScale(1, 0.06); hz.Parent = plate
    if style == "Wood" then hz.Visible = false; block.Visible = false; rule.Visible = false; sg.LightInfluence = 0.5; sg.Brightness = 1.2 end
    if style == "Neon" then hz.Visible = false; rule.Visible = false; plate.BackgroundTransparency = 0.25 end -- (UPDATE 4: tube lettering, no hazard strip)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Size = sub and UDim2.fromScale(0.92, 0.56) or UDim2.fromScale(0.92, 0.8)
    t.Position = sub and UDim2.fromScale(0.04, 0.06) or UDim2.fromScale(0.04, 0.08)
    t.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
    t:SetAttribute("KeepFont", true)
    t.TextScaled = true
    t.TextColor3 = color
    t.Text = string.upper(title)
    t.Parent = sg
    local st = Instance.new("UIStroke"); st.Thickness = 1; st.Transparency = 0.4; st.Color = Color3.fromRGB(8, 8, 10); st.Parent = t
    if style == "Neon" then st.Color = color; st.Thickness = 2.4; st.Transparency = 0.45 end -- (a soft glow round the letters: a bent neon tube)
    if sub then
        local s = Instance.new("TextLabel")
        s.BackgroundTransparency = 1
        s.Size = UDim2.fromScale(0.88, 0.24)
        s.Position = UDim2.fromScale(0.06, 0.64)
        s.FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium)
        s:SetAttribute("KeepFont", true)
        s.TextScaled = true
        s.TextColor3 = Color3.fromRGB(200, 198, 190)
        s.Text = string.upper(sub)
        s.Parent = sg
    end
    return sg
end

local function Prompt(parent: Instance, name: string, action: string, object: string, dist: number?): ProximityPrompt
    local pr = Instance.new("ProximityPrompt")
    pr.Name = name
    pr.ActionText = action
    pr.ObjectText = object
    pr.HoldDuration = 0
    pr.RequiresLineOfSight = false
    pr.MaxActivationDistance = dist or 14
    pr.Parent = parent
    return pr
end

-- ------------------------------------------------------------------ the fortress
-- HUB v4 "FRONTIER FORTRESS" (2026-10-05). Owner: "I want the hub and arenas massively improved still ... use Path of
-- exile towns ... as reference" -> picked "Frontier fortress": an open-air walled outpost on a cliff at DUSK. The
-- reference's principles, our own build: an inner bailey round a WAYPOINT obelisk, a cobbled plaza with dirt roads,
-- stations as stalls / workshops / tents with clutter round them, two great ruined-arch gates (the rifts), tall curtain
-- walls carrying the leaderboards, watchtowers, warm firelight pools against a cool dusk (few lights, no neon walls).
-- Ground + cliffs are TERRAIN (cheap, organic); props are the EnvKit (AI-made meshes, one draw each, box hitboxes).
-- Footprint unchanged (inner bailey |x|, |z| < 75): HubCamera's region, the booths' anchor spots and the gates stay.
local EnvKit = require(game:GetService("ReplicatedStorage"):WaitForChild("AimRngShared"):WaitForChild("EnvKit"))
-- HUB v5 "WALLED CITY" (2026-10-05, HubCity): the keep below is kept for a rollback -- HUB_STYLE = "Keep" brings it back.
local HubCity = require(script.Parent:WaitForChild("HubCity"))
local HUB_STYLE = "City"
local Terrain = Workspace.Terrain
local WALL_H = 46                                -- curtain walls (the leaderboards hang on them)
local WALL_X = FLOOR_HALF + 3                    -- wall centre lines (inner face at 75)
local STONE = Color3.fromRGB(82, 76, 72)          -- wall stone
local STONE_DARK = Color3.fromRGB(46, 42, 42)     -- base course, buttresses
local WOOD = Color3.fromRGB(70, 50, 36)           -- timber
local IRON = Color3.fromRGB(46, 46, 50)
local BRASS = Color3.fromRGB(198, 160, 92)
local FIRE = Color3.fromRGB(255, 150, 70)
HubGenerator.SPAWN = Vector3.new(0, 5, 24) -- (south of the waypoint; the server / client hub teleports use this)

-- HUB GRADE (owner 2026-10-05: "All of the props in spawn look very generated, the marks dont add up with the
-- environment"): the generated kit's textures are bright, saturated cartoon paint against a dusk keep. Every hub prop
-- is multiplied by one muted warm grade (on top of its own tint), so they sit in the scene's light instead of on it.
local HUB_GRADE = Color3.new(0.74, 0.69, 0.64)
local function Graded(c: Color3): Color3 return Color3.new(c.R * HUB_GRADE.R, c.G * HUB_GRADE.G, c.B * HUB_GRADE.B) end
local function Kit(parent: Instance, name: string, cf: CFrame, scale: number?, opts: any?)
    opts = opts or {}
    opts.Scale = scale or 1
    opts.Parent = parent
    local tpl = EnvKit.Get("Hub", name)
    local base = opts.Tint or (tpl and tpl:GetAttribute("Tint")) or Color3.new(1, 1, 1)
    if typeof(base) == "Color3" then opts.Tint = Graded(base) end
    return EnvKit.Place("Hub", name, cf, opts)
end
-- a kit prop in a booth's local frame (offset from the booth origin, yaw in degrees)
local function KitL(parent: Instance, cf: CFrame, name: string, off: Vector3, yaw: number, scale: number?, opts: any?)
    return Kit(parent, name, cf * CFrame.new(off) * CFrame.Angles(0, math.rad(yaw), 0), scale, opts)
end
local function FireLight(parent: BasePart, range: number?, brightness: number?, color: Color3?)
    return Light(parent, "PointLight", { Range = range or 20, Brightness = brightness or 2.2, Color = color or FIRE, Shadows = false })
end
-- a brazier (kit) with a real Fire and one light
local function Brazier(parent: Instance, pos: Vector3, scale: number?, color: Color3?, withLight: boolean?)
    local s = scale or 1.6
    Kit(parent, "Brazier", CFrame.new(pos), s, { Hitbox = Vector3.new(2.6 * s / 1.6, 4 * s / 1.6, 2.6 * s / 1.6) })
    local flame = P(parent, { Name = "BrazierFlame", Size = Vector3.new(1, 1, 1), Position = pos + Vector3.new(0, 3.2 * s / 1.6 + 0.6, 0), Transparency = 1, CanCollide = false, CanQuery = false })
    local fire = Instance.new("Fire"); fire.Size = 4 * s / 1.6; fire.Heat = 7; fire.Color = color or FIRE; fire.SecondaryColor = Color3.fromRGB(255, 60, 20); fire.Parent = flame
    if withLight ~= false then FireLight(flame, 22, 2.4, color) end
    return flame
end
-- a lantern post (kit) with an optional light at the lantern
local function Lantern(parent: Instance, pos: Vector3, yaw: number?, withLight: boolean?)
    Kit(parent, "LanternPost", CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw or 0), 0), 1.45, { Hitbox = Vector3.new(1.4, 11, 1.4) })
    if withLight then
        local l = P(parent, { Name = "LanternLight", Size = Vector3.new(0.5, 0.5, 0.5), Position = pos + Vector3.new(0, 9.6, 0), Transparency = 1, CanCollide = false, CanQuery = false })
        FireLight(l, 24, 1.8, Color3.fromRGB(255, 190, 110))
    end
end
-- a stack of crates (primitives: the generator couldn't make good ones)
local function Crates(parent: Instance, cf: CFrame, n: number?)
    local cols = { Color3.fromRGB(104, 76, 50), Color3.fromRGB(88, 64, 44), Color3.fromRGB(116, 86, 56) }
    for i = 1, (n or 3) do
        local s = (i == 3) and 2.6 or 3.2
        local off = (i == 1 and Vector3.new(-1.7, s / 2, 0)) or (i == 2 and Vector3.new(1.7, s / 2, 0.3)) or Vector3.new(-0.2, 3.2 + s / 2, 0.1)
        local c = P(parent, { Name = "Crate", Size = Vector3.new(s, s, s), CFrame = cf * CFrame.new(off) * CFrame.Angles(0, math.rad(i * 13), 0), Color = cols[i], Material = Enum.Material.WoodPlanks })
        c.CastShadow = true
        P(parent, { Name = "CrateBand", Size = Vector3.new(s + 0.08, 0.3, s + 0.08), CFrame = c.CFrame * CFrame.new(0, s * 0.3, 0), Color = IRON, Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
    end
end
-- emitters (cheap, low rates)
local function Emit(parent: Instance, props: { [string]: any }): ParticleEmitter
    local pe = Instance.new("ParticleEmitter")
    for k, v in pairs(props) do (pe :: any)[k] = v end
    pe.Parent = parent
    return pe
end

-- the Centerpiece gyroscope (OuterRing / InnerRing, turned by the client while you're in the hub)
local function BuildCenterpiece(hub: Folder): Model
    local top = FLOOR_TOP
    local cp = Instance.new("Model")
    cp.Name = "Centerpiece"
    cp.Parent = hub
    local C0 = Vector3.new(0, 34, 0)
    local function Ring(name: string, radius: number, thick: number, tilt: CFrame, n: number)
        local m = Instance.new("Model")
        m.Name = name
        m.Parent = cp
        for i = 0, n - 1 do
            local a = (i / n) * math.pi * 2
            local seg = 2 * radius * math.sin(math.pi / n) + 0.15
            P(m, { Name = "Seg", Size = Vector3.new(thick, thick, seg), CFrame = CFrame.new(C0) * tilt * CFrame.Angles(0, a, 0) * CFrame.new(radius, 0, 0),
                Color = BRASS, Material = Enum.Material.Metal, Reflectance = 0.25, CanCollide = false, CanQuery = false })
        end
        m.WorldPivot = CFrame.new(C0) * tilt
        return m
    end
    Ring("OuterRing", 7, 0.55, CFrame.identity, 18)
    Ring("InnerRing", 5, 0.45, CFrame.Angles(0, 0, math.rad(90)), 14)
    local core = P(cp, { Name = "ReticleCore", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), CFrame = CFrame.new(C0), Color = Color3.fromRGB(255, 205, 120), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
    core.CastShadow = false
    Light(core, "PointLight", { Range = 30, Brightness = 1.6, Color = Color3.fromRGB(255, 200, 130), Shadows = false })
    Emit(core, { Color = ColorSequence.new(Color3.fromRGB(255, 220, 150)), LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) }),
        Lifetime = NumberRange.new(3, 5), Rate = 5, Speed = NumberRange.new(0.6, 1.6), SpreadAngle = Vector2.new(180, 180), Transparency = NumberSequence.new(0.3) })
    cp:SetAttribute("Spin", true)
    return cp
end
-- the spawn pad (and the place's own SpawnLocation / Baseplate tamed)
local function BuildSpawn(hub: Folder)
    -- spawn: south of the waypoint, facing it
    local spawnPad = Instance.new("SpawnLocation")
    spawnPad.Name = "HubSpawn"
    spawnPad.Size = Vector3.new(10, 0.4, 10)
    local sy = (HUB_STYLE == "City") and HubCity.GROUND + 0.2 or 1.7 -- (the city's street is a part at y 4)
    spawnPad.CFrame = CFrame.lookAt(Vector3.new(HubGenerator.SPAWN.X, sy, HubGenerator.SPAWN.Z), Vector3.new(0, sy, 0))
    spawnPad.Transparency = 1
    spawnPad.CanCollide = false
    spawnPad.Anchored = true
    spawnPad.Neutral = true
    spawnPad.Duration = 0
    spawnPad.Parent = hub
    for _, d in ipairs(spawnPad:GetChildren()) do if d:IsA("Decal") then d:Destroy() end end
    -- (the place's default SpawnLocation sits at the origin -- under the waypoint obelisk: players spawned on top of it)
    for _, sp in ipairs(Workspace:GetChildren()) do
        if sp:IsA("SpawnLocation") then sp.Enabled = false; sp.CFrame = spawnPad.CFrame - Vector3.new(0, 6, 0); sp.Transparency = 1; sp.CanCollide = false end
    end
    -- (the place's default 2048-wide Baseplate showed as a flat plastic plain past the open arena rims: hidden, it
    -- still collides as a safety net under everything)
    local base = Workspace:FindFirstChild("Baseplate")
    if base and base:IsA("BasePart") then base.Transparency = 1; base.CastShadow = false end
end

local function BuildHall(hub: Folder)
    -- ===== TERRAIN: the cliff plateau, dirt bailey, cobbled plaza + roads, grass at the edges =====
    local top = FLOOR_TOP
    Terrain:FillBlock(CFrame.new(0, top - 30, 70), Vector3.new(352, 60, 420), Enum.Material.Rock)
    Terrain:FillBlock(CFrame.new(0, top - 2, 0), Vector3.new(156, 4, 156), Enum.Material.Ground)
    Terrain:FillCylinder(CFrame.new(0, top - 2, 0), 4, 30, Enum.Material.Cobblestone)
    local function Road(a: Vector2, b: Vector2, w: number, mat: Enum.Material)
        local A, B = Vector3.new(a.X, top - 2, a.Y), Vector3.new(b.X, top - 2, b.Y)
        Terrain:FillBlock(CFrame.lookAt((A + B) / 2, B), Vector3.new(w, 4, (B - A).Magnitude), mat)
    end
    Road(Vector2.new(0, 0), Vector2.new(-38, -60), 13, Enum.Material.Cobblestone)
    Road(Vector2.new(0, 0), Vector2.new(38, -60), 13, Enum.Material.Cobblestone)
    Road(Vector2.new(0, 0), Vector2.new(0, 76), 14, Enum.Material.Cobblestone)
    Road(Vector2.new(-48, -50), Vector2.new(-48, 52), 9, Enum.Material.Pavement)
    Road(Vector2.new(48, -50), Vector2.new(48, 52), 9, Enum.Material.Pavement)
    Road(Vector2.new(-48, 0), Vector2.new(48, 0), 8, Enum.Material.Pavement)
    -- grass + mud patches where nobody walks (the corners, along the walls between booths)
    local rng = Random.new(1207)
    for _, c in ipairs({ Vector2.new(-64, -64), Vector2.new(64, -64), Vector2.new(-64, 64), Vector2.new(64, 64), Vector2.new(-30, 52), Vector2.new(30, 52),
        Vector2.new(-30, -30), Vector2.new(30, -30) }) do
        for _ = 1, 3 do
            local p = Vector3.new(c.X + rng:NextNumber(-6, 6), top - 1.6, c.Y + rng:NextNumber(-6, 6))
            Terrain:FillBlock(CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Vector3.new(rng:NextNumber(6, 12), 3.2, rng:NextNumber(6, 12)), Enum.Material.LeafyGrass)
        end
    end
    Terrain:FillBlock(CFrame.new(-60, top - 1.6, -12), Vector3.new(14, 3.2, 12), Enum.Material.Mud) -- (round the forge)
    -- the cliff edge round the plateau: broken rock shelves falling away (seen past the range and the corners)
    for i = 1, 40 do
        local side = (i % 4)
        local t = rng:NextNumber(-1, 1)
        local p = (side == 0 and Vector3.new(t * 170, 0, -145)) or (side == 1 and Vector3.new(176, 0, 70 + t * 210)) or (side == 2 and Vector3.new(-176, 0, 70 + t * 210)) or Vector3.new(t * 170, 0, 282)
        local r = rng:NextNumber(14, 30)
        Terrain:FillBall(p + Vector3.new(0, top - r * 0.9 - rng:NextNumber(0, 30), 0), r, Enum.Material.Rock)
        if rng:NextNumber() < 0.5 then Terrain:FillBall(p + Vector3.new(rng:NextNumber(-12, 12), top - r * 1.6 - 25, rng:NextNumber(-12, 12)), r * 1.2, Enum.Material.Slate) end
    end

    -- ===== CURTAIN WALLS: stone with a dark base course, buttresses, crenellations; an invisible collider above =====
    local function WallRun(name: string, size: Vector3, pos: Vector3, alongX: boolean)
        P(hub, { Name = name, Size = size, Position = pos, Color = STONE, Material = Enum.Material.Cobblestone })
        local base = Vector3.new(alongX and size.X or size.X + 1.6, 7, alongX and size.Z + 1.6 or size.Z)
        P(hub, { Name = name .. "Base", Size = base, Position = Vector3.new(pos.X, top + 3.5, pos.Z), Color = STONE_DARK, Material = Enum.Material.Basalt, CanQuery = false })
        local len = alongX and size.X or size.Z
        -- crenellations: merlons every 6 studs on the outer half of the wall top
        for t = -len / 2 + 3, len / 2 - 3, 6 do
            local mp = alongX and Vector3.new(pos.X + t, WALL_H + 2.5, pos.Z) or Vector3.new(pos.X, WALL_H + 2.5, pos.Z + t)
            local m = P(hub, { Name = "Merlon", Size = alongX and Vector3.new(3.4, 5, size.Z) or Vector3.new(size.X, 5, 3.4), Position = mp, Color = STONE, Material = Enum.Material.Cobblestone, CanQuery = false })
            m.CastShadow = false
        end
        -- buttresses every 26 studs on the inner face (skip where a booth / board sits)
        local inward = alongX and (pos.Z < 0 and 1 or -1) or (pos.X < 0 and 1 or -1)
        -- (side walls: shifted half a step -- they stood right in the middle of the leaderboards, which hang 26 apart;
        -- owner 2026-10-05: "the leaderboards are blocked by props on the wall")
        local shift = alongX and 0 or 17 -- (puts them at z -51, -25, 1, 27, 53: the gaps between the boards)
        for t = -len / 2 + 13 + shift, len / 2 - 4, 26 do
            local bh = alongX and WALL_H or 18 -- (side walls: low pilasters that stop under the boards and their header)
            local bp = alongX and Vector3.new(pos.X + t, top + bh / 2, pos.Z + inward * (size.Z / 2 + 1.6)) or Vector3.new(pos.X + inward * (size.X / 2 + 1.6), top + bh / 2, pos.Z + t)
            P(hub, { Name = "Buttress", Size = alongX and Vector3.new(4, bh, 3.2) or Vector3.new(3.2, bh, 4), Position = bp, Color = STONE_DARK, Material = Enum.Material.Slate })
        end
        -- invisible collider up to 90: nobody jumps the walls
        local cz = P(hub, { Name = name .. "Collider", Size = Vector3.new(size.X, 45, size.Z), Position = Vector3.new(pos.X, WALL_H + 22.5, pos.Z), Transparency = 1, CanQuery = false })
        cz.CastShadow = false
    end
    WallRun("WallNorth", Vector3.new(WALL_X * 2 + 6, WALL_H, 6), Vector3.new(0, WALL_H / 2, -WALL_X), true)
    WallRun("WallWest", Vector3.new(6, WALL_H, WALL_X * 2 + 6), Vector3.new(-WALL_X, WALL_H / 2, 0), false)
    WallRun("WallEast", Vector3.new(6, WALL_H, WALL_X * 2 + 6), Vector3.new(WALL_X, WALL_H / 2, 0), false)
    -- south: two runs either side of the range doorway (40 wide), a timber gatehouse over it
    local side = (WALL_X * 2 + 6 - 40) / 2
    WallRun("WallSouthL", Vector3.new(side, WALL_H, 4), Vector3.new(-(20 + side / 2), WALL_H / 2, FLOOR_HALF + 2), true)
    WallRun("WallSouthR", Vector3.new(side, WALL_H, 4), Vector3.new(20 + side / 2, WALL_H / 2, FLOOR_HALF + 2), true)
    P(hub, { Name = "Gatehouse", Size = Vector3.new(44, WALL_H - 28, 6), Position = Vector3.new(0, 28 + (WALL_H - 28) / 2, FLOOR_HALF + 2), Color = STONE, Material = Enum.Material.Cobblestone })
    P(hub, { Name = "GatehouseBeam", Size = Vector3.new(44, 2.2, 7), Position = Vector3.new(0, 27.4, FLOOR_HALF + 2), Color = WOOD, Material = Enum.Material.WoodPlanks })
    for _, sx in ipairs({ -1, 1 }) do
        P(hub, { Name = "GatePost", Size = Vector3.new(3, 27, 3), Position = Vector3.new(sx * 20.5, top + 13.5, FLOOR_HALF + 0.5), Color = WOOD, Material = Enum.Material.WoodPlanks })
    end
    -- watchtowers in the four corners, rising over the walls
    for _, c in ipairs({ Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) }) do
        Kit(hub, "Watchtower", CFrame.new(c.X * (WALL_X - 2), top, c.Y * (WALL_X - 2)) * CFrame.Angles(0, math.rad(45 + (c.X * c.Y > 0 and 0 or 90)), 0), 3.1, { Shadow = true })
    end
    -- ===== THE WAYPOINT: a carved obelisk on a stepped plinth; the gyroscope reticle turns over it (client) =====
    -- (the collider fits the visible stone: a 13 x 24 x 13 box kept everyone a long way off it -- owner 2026-10-05)
    Kit(hub, "Obelisk", CFrame.new(0, top, 0), 1.35, { Hitbox = Vector3.new(5.5, 20, 5.5), Shadow = true, Name = "Waypoint" })
    BuildCenterpiece(hub)
    -- four lantern posts round the plaza edge (all lit: owner 2026-10-05 "only two of four lights have light"), braziers by the roads, benches of crates / barrels
    for _, a in ipairs({ 45, 135, 225, 315 }) do
        local d = CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0, -27)
        Lantern(hub, Vector3.new(d.Position.X, top, d.Position.Z), a, true)
    end
    for _, s in ipairs({ -1, 1 }) do
        Kit(hub, "BannerPole", CFrame.new(s * 14, top, -24) * CFrame.Angles(0, math.rad(180), 0), 1.7, { Hitbox = Vector3.new(1.2, 15, 1.2) })
        Kit(hub, "Barrels", CFrame.new(s * 62, top, 62) * CFrame.Angles(0, math.rad(s * 40), 0), 1.4, { Hitbox = true })
        Crates(hub, CFrame.new(s * 30, top, 66) * CFrame.Angles(0, math.rad(s * 20), 0))
        Kit(hub, "Sandbags", CFrame.new(s * 22, top, 62) * CFrame.Angles(0, math.rad(s * 25), 0), 1.5, { Hitbox = true })
    end
    -- a stone well (SW quadrant), benches, a bounty board by the spawn road
    do
        local wc = CFrame.new(-34, top, 22)
        -- (owner 2026-10-05: "the middle needs to be higher with a hole in the middle", then "the top two pieces aren't
        -- connected") a raised stone ring round an open, dark water shaft; the roof halves meet at a ridge beam
        local R, H, N = 3.6, 3.4, 14
        for i = 0, N - 1 do
            local ang = (i / N) * math.pi * 2
            local seg = 2 * R * math.sin(math.pi / N) + 0.35
            P(hub, { Name = "WellRing", Size = Vector3.new(1.1, H, seg), CFrame = wc * CFrame.Angles(0, ang, 0) * CFrame.new(R, H / 2, 0),
                Color = STONE:Lerp(Color3.new(0, 0, 0), (i % 3) * 0.06), Material = Enum.Material.Cobblestone })
            P(hub, { Name = "WellCap", Size = Vector3.new(1.5, 0.45, seg + 0.1), CFrame = wc * CFrame.Angles(0, ang + math.pi / N, 0) * CFrame.new(R, H + 0.22, 0),
                Color = Color3.fromRGB(96, 92, 88), Material = Enum.Material.Slate, CanQuery = false })
        end
        -- the shaft: black inside, still water deep down
        P(hub, { Name = "WellShaft", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, R * 2 - 0.6, R * 2 - 0.6), CFrame = wc * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
            Color = Color3.fromRGB(8, 10, 12), Material = Enum.Material.SmoothPlastic, CanQuery = false })
        P(hub, { Name = "WellWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, R * 2 - 0.8, R * 2 - 0.8), CFrame = wc * CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)),
            Color = Color3.fromRGB(24, 44, 56), Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.2, CanCollide = false, CanQuery = false })
        -- posts outside the ring, up to the ridge
        local RIDGE, HALF, TILT = 11.6, 2.6, math.rad(36)
        for _, sx in ipairs({ -1, 1 }) do
            P(hub, { Name = "WellPost", Size = Vector3.new(0.7, RIDGE - 0.4, 0.7), CFrame = wc * CFrame.new(sx * (R + 0.7), (RIDGE - 0.4) / 2, 0), Color = WOOD, Material = Enum.Material.Wood })
        end
        -- the two roof halves meet at the ridge (each panel's top edge sits on the ridge line) + a ridge beam over the seam
        for _, sz in ipairs({ -1, 1 }) do
            P(hub, { Name = "WellRoof", Size = Vector3.new(9.6, 0.5, HALF * 2),
                CFrame = wc * CFrame.new(0, RIDGE - HALF * math.sin(TILT), sz * HALF * math.cos(TILT)) * CFrame.Angles(sz * TILT, 0, 0),
                Color = Color3.fromRGB(60, 42, 30), Material = Enum.Material.WoodPlanks })
        end
        P(hub, { Name = "WellRidge", Size = Vector3.new(10, 0.55, 0.55), CFrame = wc * CFrame.new(0, RIDGE + 0.15, 0), Color = WOOD, Material = Enum.Material.Wood })
        -- the windlass: an axle between the posts, a crank, a rope down into the shaft and a bucket
        P(hub, { Name = "WellAxle", Shape = Enum.PartType.Cylinder, Size = Vector3.new((R + 0.7) * 2, 0.5, 0.5), CFrame = wc * CFrame.new(0, 7.2, 0), Color = WOOD, Material = Enum.Material.Wood, CanCollide = false })
        P(hub, { Name = "WellCrank", Size = Vector3.new(0.3, 1.4, 0.3), CFrame = wc * CFrame.new(R + 1.2, 6.6, 0), Color = IRON, Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
        P(hub, { Name = "WellRope", Size = Vector3.new(0.12, 3.6, 0.12), CFrame = wc * CFrame.new(0, 5.2, 0), Color = Color3.fromRGB(150, 120, 80), Material = Enum.Material.Fabric, CanCollide = false, CanQuery = false })
        P(hub, { Name = "WellBucket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 1, 1), CFrame = wc * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 58, 40), Material = Enum.Material.WoodPlanks, CanCollide = false, CanQuery = false })
    end
    for _, b in ipairs({ { 36, 20, -30 }, { -40, -26, 60 }, { 40, -26, -60 } }) do
        local bc = CFrame.new(b[1], top, b[2]) * CFrame.Angles(0, math.rad(b[3]), 0)
        P(hub, { Name = "Bench", Size = Vector3.new(7, 0.6, 2), CFrame = bc * CFrame.new(0, 2.1, 0), Color = Color3.fromRGB(78, 56, 40), Material = Enum.Material.WoodPlanks })
        for _, sx in ipairs({ -1, 1 }) do P(hub, { Name = "BenchLeg", Size = Vector3.new(0.6, 1.8, 1.6), CFrame = bc * CFrame.new(sx * 2.8, 0.9, 0), Color = Color3.fromRGB(60, 42, 30), Material = Enum.Material.WoodPlanks, CanQuery = false }) end
    end
    Kit(hub, "NoticeBoard", CFrame.new(12, top, 48) * CFrame.Angles(0, math.rad(-160), 0), 1.6, { Hitbox = true })
    -- AIMBOUND crest: an iron plaque on the north wall between the gates
    local crest = P(hub, { Name = "Crest", Size = Vector3.new(17, 20, 1), Position = Vector3.new(0, 30, -FLOOR_HALF + 0.4), Color = Color3.fromRGB(26, 24, 26), Material = Enum.Material.Metal, CanQuery = false })
    do
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Back
        sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        sg.PixelsPerStud = 30
        sg.LightInfluence = 0.4
        sg.Brightness = 1.2
        sg.Parent = crest
        local function line(text, y, h, color)
            local t = Instance.new("TextLabel")
            t.BackgroundTransparency = 1
            t.Size = UDim2.fromScale(0.9, h)
            t.Position = UDim2.fromScale(0.05, y)
            t.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
            t:SetAttribute("KeepFont", true)
            t.TextScaled = true
            t.TextColor3 = color
            t.Text = text
            t.Parent = sg
        end
        line("AIMBOUND", 0.06, 0.26, Color3.fromRGB(235, 200, 130))
        line("AIM  •  LOOT  •  ASCEND", 0.4, 0.12, Color3.fromRGB(200, 190, 175))
        line("FRONTIER  KEEP", 0.62, 0.14, Color3.fromRGB(160, 150, 140))
    end
    for _, y in ipairs({ 19.8, 40.2 }) do P(hub, { Name = "CrestFrame", Size = Vector3.new(18, 0.6, 1.4), Position = Vector3.new(0, y, -FLOOR_HALF + 0.4), Color = BRASS, Material = Enum.Material.Metal, CanCollide = false, CanQuery = false }) end
    -- dust motes drifting over the bailey (one big emitter)
    local motes = P(hub, { Name = "Motes", Size = Vector3.new(140, 1, 140), Position = Vector3.new(0, 14, 0), Transparency = 1, CanCollide = false, CanQuery = false })
    Emit(motes, { Color = ColorSequence.new(Color3.fromRGB(255, 220, 180)), LightEmission = 0.6, Size = NumberSequence.new(0.18), Lifetime = NumberRange.new(6, 10),
        Rate = 7, Speed = NumberRange.new(0.2, 0.8), SpreadAngle = Vector2.new(180, 180), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.5), NumberSequenceKeypoint.new(1, 1) }) })
    BuildSpawn(hub)
end

-- ------------------------------------------------------------------ the gates
-- A great ruined stone arch over each rift (the vortex + prompt + touch logic are unchanged: the server and the client
-- look for PortalVortex / ChallengeVortex straight under HubWorld).
local function BuildGate(hub: Folder, cx: number, t: any): BasePart
    local m = Instance.new("Model")
    m.Name = t.ModelName
    m.Parent = hub
    local cf = CFrame.lookAt(Vector3.new(cx, FLOOR_TOP, -FLOOR_HALF + 10), Vector3.new(cx, FLOOR_TOP, 0)) -- local -Z faces the bailey
    local stone = t.Stone
    -- dais + steps
    if not t.City then
    L(m, cf, Vector3.new(40, 2.4, 16), Vector3.new(0, 1.2, 1), { Color = stone, Material = Enum.Material.Slate })
    L(m, cf, Vector3.new(36, 1.4, 3.4), Vector3.new(0, 0.7, -8.5), { Color = stone, Material = Enum.Material.Slate })
    end
    -- the arch (kit), tinted to the gate's stone; the rift fills its opening
    -- (the kit mesh sits ~40 deg turned inside its model, which left the arch diagonal to the rift: square every part to
    -- the gate. t.Mirror turns it round, so the two gates mirror each other instead of being copies.)
    local arch = (not t.City) and Kit(m, "RuinArch", cf * CFrame.new(0, 2.4, 2), 2.25, { Tint = t.ArchTint, Shadow = true }) or nil
    if arch then
        local rot = cf.Rotation * (t.Mirror and CFrame.Angles(0, math.pi, 0) or CFrame.identity)
        for _, d in ipairs(arch:GetDescendants()) do
            if d:IsA("BasePart") then d.CFrame = CFrame.new(d.Position) * rot end
        end
    end
    -- the RIFT: a black void (self-lit black, so lights can't wash it out) with a thin glowing edge and slow coloured
    -- wisps drifting across it (Beams -- big transparent Neon planes read as a solid block of colour, so none of those)
    L(m, cf, Vector3.new(21, 33, 1), Vector3.new(0, 19, 5.5), { Color = Color3.fromRGB(6, 3, 10), Material = Enum.Material.Neon, CanQuery = false })
    for _, e in ipairs({ { Vector3.new(20.6, 0.35, 0.35), Vector3.new(0, 35.3, 4.6) }, { Vector3.new(20.6, 0.35, 0.35), Vector3.new(0, 2.8, 4.6) },
        { Vector3.new(0.35, 32.5, 0.35), Vector3.new(-10.3, 19, 4.6) }, { Vector3.new(0.35, 32.5, 0.35), Vector3.new(10.3, 19, 4.6) } }) do
        Neon(m, cf, e[1], e[2], t.Main, 0.1)
    end
    local vortex = L(m, cf, Vector3.new(20, 31, 0.6), Vector3.new(0, 18.5, 1.2), { Name = t.VortexName, Color = t.Main, Material = Enum.Material.SmoothPlastic, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = true })
    vortex.CastShadow = false
    for k = 1, 2 do
        local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(-9, (k == 1) and -10 or 8, 2.4 + k * 0.4); a0.Parent = vortex
        local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(9, (k == 1) and 6 or -9, 2.4 + k * 0.4); a1.Parent = vortex
        local b = Instance.new("Beam")
        b.Attachment0, b.Attachment1 = a0, a1
        b.Texture = "rbxasset://textures/particles/smoke_main.dds"
        b.TextureMode = Enum.TextureMode.Stretch
        b.TextureSpeed = (k == 1) and 0.12 or -0.09
        b.Width0, b.Width1 = 26, 20
        b.LightEmission = 1
        b.Color = ColorSequence.new(t.Main, t.Accent)
        b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) })
        b.FaceCamera = false
        b.Parent = vortex
    end
    Emit(vortex, { Color = ColorSequence.new(t.Accent, t.Main), LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
        Transparency = NumberSequence.new(0.2), Lifetime = NumberRange.new(1.5, 3), Rate = 14, Speed = NumberRange.new(3, 7), RotSpeed = NumberRange.new(-180, 180),
        SpreadAngle = Vector2.new(30, 30), EmissionDirection = Enum.NormalId.Front })
    Light(vortex, "SurfaceLight", { Face = Enum.NormalId.Front, Range = 34, Angle = 100, Brightness = 1.3, Color = t.Main, Shadows = false })
    Prompt(vortex, t.PromptName, t.Action, t.Object, 24)
    local lastTouch: { [Player]: number } = {}
    vortex.Touched:Connect(function(hit)
        local plr = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
        if not plr or os.clock() - (lastTouch[plr] or 0) < 3 then return end
        -- (only for someone actually standing in the hub: a late touch must never pop the menu inside a run)
        local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if not root or root.Position.Z > 450 or plr:GetAttribute("RunId") then return end
        lastTouch[plr] = os.clock()
        Remotes.GetEvent("OpenMenu"):FireClient(plr, t.Menu)
    end)
    -- title plaque hung on chains above the arch
    if t.City then
        HubCity.Gate(hub, cx, t, { P = P, Light = Light, FLOOR_TOP = FLOOR_TOP, FLOOR_HALF = FLOOR_HALF, GROUND = HubCity.GROUND })
        m.WorldPivot = cf
        vortex.Parent = hub
        return vortex
    end
    local plaque = L(m, cf, Vector3.new(24, 5.2, 0.8), Vector3.new(0, 39, -8.4), { Color = Color3.fromRGB(22, 20, 22), Material = Enum.Material.Metal, CanQuery = false })
    Sign(plaque, Enum.NormalId.Front, t.Title, t.Sub, t.Main, 22)
    for _, s in ipairs({ -1, 1 }) do
        L(m, cf, Vector3.new(0.4, 5, 0.4), Vector3.new(s * 10, 44, -8.4), { Color = IRON, Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
        -- braziers + banners flank the dais
        local fl = Brazier(m, (cf * CFrame.new(s * 22, 0, -6)).Position, 2.1, t.Fire, true)
        local _ = fl
        Kit(m, "BannerPole", cf * CFrame.new(s * 15.5, 2.4, -6) * CFrame.Angles(0, math.rad(180), 0), 2, { Tint = t.BannerTint, Hitbox = Vector3.new(1.2, 18, 1.2) })
    end
    m.WorldPivot = cf
    vortex.Parent = hub -- the server script looks for it directly under HubWorld
    return vortex
end

-- ------------------------------------------------------------------ station booths
-- cf: booth origin on the floor, local -Z = toward the plaza. A wooden deck, a hanging wooden sign on a timber frame and
-- the station's own scene (t.Prop, EnvKit). The ANCHOR (named t.Anchor, parented straight to HubWorld with its prompt)
-- is the counter; t.HideCounter = the scene has its own counter, so the anchor is an invisible box there.
local function BuildBooth(hub: Folder, cf: CFrame, t: any): BasePart
    local m = Instance.new("Model")
    m.Name = "Booth_" .. t.Anchor
    m.Parent = hub
    local col = t.Color
    L(m, cf, Vector3.new(22, 0.8, 17), Vector3.new(0, 0.4, 0), { Color = Color3.fromRGB(58, 42, 30), Material = Enum.Material.WoodPlanks })
    for _, s in ipairs({ -1, 1 }) do -- deck edge beams
        L(m, cf, Vector3.new(0.8, 1, 17), Vector3.new(s * 11, 0.5, 0), { Color = Color3.fromRGB(44, 32, 24), Material = Enum.Material.WoodPlanks, CanQuery = false })
    end
    -- a hanging shop sign: one post at the deck's front-left corner, an iron-braced arm, a painted board on chains
    L(m, cf, Vector3.new(0.9, 17, 0.9), Vector3.new(-10.6, 8.5, -7.6), { Color = WOOD, Material = Enum.Material.WoodPlanks })
    L(m, cf, Vector3.new(11, 0.7, 0.7), Vector3.new(-5.5, 16.4, -7.6), { Color = WOOD, Material = Enum.Material.WoodPlanks, CanQuery = false })
    L(m, cf, Vector3.new(0.25, 4.4, 0.25), Vector3.new(-8.6, 14.8, -7.6), { Color = IRON, Material = Enum.Material.Metal, CanCollide = false, CanQuery = false }, CFrame.Angles(0, 0, math.rad(-45)))
    local signBoard = L(m, cf, Vector3.new(9.5, 3, 0.4), Vector3.new(-5, 13.7, -7.6), { Color = Color3.fromRGB(46, 32, 22), Material = Enum.Material.WoodPlanks, CanQuery = false })
    Sign(signBoard, Enum.NormalId.Front, t.Title, t.Sub, col, 32, "Wood")
    L(m, cf, Vector3.new(9.8, 0.25, 0.5), Vector3.new(-5, 15.3, -7.6), { Color = BRASS, Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
    for _, s in ipairs({ -1, 1 }) do
        L(m, cf, Vector3.new(0.15, 1.4, 0.15), Vector3.new(-5 + s * 3.8, 15.7, -7.6), { Color = IRON, Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
    end
    -- counter (the anchor)
    local counter = L(m, cf, Vector3.new(14, 3.6, 3), Vector3.new(0, 2.6, -3.5), { Name = t.Anchor, Color = Color3.fromRGB(62, 44, 32), Material = Enum.Material.WoodPlanks })
    if t.HideCounter then counter.Transparency = 1 end
    if not t.HideCounter then
        L(m, cf, Vector3.new(14.3, 0.3, 3.3), Vector3.new(0, 4.5, -3.5), { Color = Color3.fromRGB(44, 32, 24), Material = Enum.Material.WoodPlanks, CanCollide = false, CanQuery = false })
    end
    Prompt(counter, t.PromptName, t.Action, t.Object, 16)
    if t.Prop then t.Prop(m, cf, col) end
    m.WorldPivot = cf
    m:ScaleTo(1.15)
    counter.Parent = hub -- the server script finds the prompt by this name under HubWorld
    return counter
end

-- ----- booth scenes (local frame: -Z = the plaza, +Z = the wall behind; the deck spans x +-11, z +-8.5)
local PROPS = {}
function PROPS.Shop(m, cf, col)
    -- the BLACK MARKET: a crimson-awning stall, a loaded cart, barrels and a lantern
    KitL(m, cf, "MarketStall", Vector3.new(0, 0.8, 2.5), 0, 1.3)
    KitL(m, cf, "Cart", Vector3.new(-8, 0.8, -1), 70, 1.5, { Hitbox = true })
    KitL(m, cf, "Barrels", Vector3.new(8.5, 0.8, -1.5), -20, 1.2, { Hitbox = true })
    Crates(m, cf * CFrame.new(8, 0.8, 5) * CFrame.Angles(0, math.rad(-15), 0), 2)
    L(m, cf, Vector3.new(0.6, 0.6, 0.6), Vector3.new(0, 10.5, 0), { Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
end
function PROPS.Forge(m, cf, col)
    -- the WEAPON FORGE: hearth + chimney (kit), a real fire, smoke and sparks
    KitL(m, cf, "Forge", Vector3.new(0, 0.8, 3), 0, 1.25)
    local hearth = L(m, cf, Vector3.new(3, 2, 2), Vector3.new(-1.5, 4.5, 2.2), { Transparency = 1, CanCollide = false, CanQuery = false })
    local fire = Instance.new("Fire"); fire.Size = 3.5; fire.Heat = 6; fire.Color = Color3.fromRGB(255, 140, 40); fire.Parent = hearth
    FireLight(hearth, 22, 2.8)
    Emit(hearth, { Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 90, 30)), LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) }),
        Lifetime = NumberRange.new(0.6, 1.2), Rate = 6, Speed = NumberRange.new(5, 10), SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(0, -18, 0), EmissionDirection = Enum.NormalId.Top })
    local chimney = L(m, cf, Vector3.new(1, 1, 1), Vector3.new(-1.7, 16, 6.5), { Transparency = 1, CanCollide = false, CanQuery = false })
    local smoke = Instance.new("Smoke"); smoke.Color = Color3.fromRGB(70, 66, 66); smoke.Opacity = 0.12; smoke.RiseVelocity = 3; smoke.Size = 4; smoke.Parent = chimney
    Crates(m, cf * CFrame.new(-8.5, 0.8, -2) * CFrame.Angles(0, math.rad(25), 0), 2)
    KitL(m, cf, "WeaponRack", Vector3.new(8.5, 0.8, 0), -70, 1.2, { Hitbox = true })
end
function PROPS.Upgrade(m, cf, col)
    -- the UPGRADE ANVIL: an armourer's tent, an anvil at the counter with a charged gem over it
    KitL(m, cf, "WarTent", Vector3.new(0, 0.8, 3.5), 0, 1.15)
    L(m, cf, Vector3.new(4, 1.8, 2.2), Vector3.new(0, 5.4, -3.5), { Color = Color3.fromRGB(56, 58, 66), Material = Enum.Material.Metal })
    L(m, cf, Vector3.new(1.4, 0.9, 1.2), Vector3.new(2.4, 5.5, -3.5), { Color = Color3.fromRGB(56, 58, 66), Material = Enum.Material.Metal })
    -- (no floating neon gem + sparkles any more: a hammer resting on the anvil and a hot ingot cooling on it)
    L(m, cf, Vector3.new(0.35, 0.35, 3.2), Vector3.new(-0.6, 6.5, -3.3), { Color = WOOD, Material = Enum.Material.Wood, CanCollide = false }, CFrame.Angles(0, math.rad(25), 0))
    L(m, cf, Vector3.new(1.3, 0.75, 0.75), Vector3.new(-1.2, 6.6, -4.6), { Color = IRON, Material = Enum.Material.Metal, CanCollide = false }, CFrame.Angles(0, math.rad(25), 0))
    local ingot = L(m, cf, Vector3.new(1.2, 0.35, 0.6), Vector3.new(1.1, 6.47, -3.2), { Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
    ingot.CastShadow = false
    KitL(m, cf, "WeaponRack", Vector3.new(-8.5, 0.8, 0), 70, 1.2, { Hitbox = true })
    KitL(m, cf, "Barrels", Vector3.new(8.5, 0.8, 1), 30, 1.1, { Hitbox = true })
end
function PROPS.Vault(m, cf, col)
    -- the ARSENAL VAULT: an armoured bunker behind sandbags
    KitL(m, cf, "VaultBunker", Vector3.new(0, 0.8, 3.5), 0, 1.45, { Tint = Color3.fromRGB(150, 150, 160) })
    KitL(m, cf, "Sandbags", Vector3.new(-8, 0.8, -2.5), 25, 1.3, { Hitbox = true })
    KitL(m, cf, "Sandbags", Vector3.new(8, 0.8, -2.5), -25, 1.3, { Hitbox = true })
    Crates(m, cf * CFrame.new(-8.5, 0.8, 4.5), 3)
end
function PROPS.Tree(m, cf, col)
    -- the SKILL MONOLITH: a ring of rune stones round a great menhir, a green orb over it
    KitL(m, cf, "Menhir", Vector3.new(0, 0.8, 3.5), 0, 1.7, { Hitbox = true })
    for i = -2, 2 do
        if i ~= 0 then
            local a = math.rad(i * 34)
            KitL(m, cf, "Menhir", Vector3.new(math.sin(a) * 8, 0.8, 3.5 - math.cos(a) * 3 + 2), i * 20, 1.05, { Hitbox = true })
        end
    end
    -- (a worn flagstone circle round the stones; the transparent neon disc read as a flat glowing sticker)
    L(m, cf, Vector3.new(0.3, 16, 16), Vector3.new(0, 0.9, 2.5), { Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(70, 66, 62), Material = Enum.Material.Slate, CanCollide = false, CanQuery = false }, CFrame.Angles(0, 0, math.rad(90)))
    local orb = Neon(m, cf, Vector3.new(2.2, 2.2, 2.2), Vector3.new(0, 19, 3.5), col, 0.05)
    orb.Shape = Enum.PartType.Ball
    Light(orb, "PointLight", { Range = 22, Brightness = 2, Color = col })
    Emit(orb, { Color = ColorSequence.new(col), LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }),
        Lifetime = NumberRange.new(2, 3.5), Rate = 4, Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180) })
end
function PROPS.Codex(m, cf, col)
    -- THE CODEX: a scribe's tent with books and a candle; a notice board of bestiary pages
    KitL(m, cf, "ScribeTent", Vector3.new(0, 0.8, 3), 0, 1.45)
    KitL(m, cf, "NoticeBoard", Vector3.new(-8.5, 0.8, -0.5), 30, 1.5, { Hitbox = true })
    for _, s in ipairs({ -1, 1 }) do
        L(m, cf, Vector3.new(2.4, 0.15, 3), Vector3.new(s * 1.15, 4.75, -3.5), { Color = Color3.fromRGB(225, 212, 180), Material = Enum.Material.SmoothPlastic, CanCollide = false }, CFrame.Angles(0, 0, math.rad(s * -12)))
    end
    local candle = L(m, cf, Vector3.new(0.4, 1, 0.4), Vector3.new(4.5, 5.2, -3.5), { Color = Color3.fromRGB(235, 225, 200), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false })
    local fl = Instance.new("Fire"); fl.Size = 1; fl.Heat = 2; fl.Parent = candle
    FireLight(candle, 14, 1.4, Color3.fromRGB(255, 200, 120))
end
function PROPS.Armory(m, cf, col)
    -- the ARMORY: racks of blades and guns round a training post
    for i, x in ipairs({ -7, 0, 7 }) do
        KitL(m, cf, "WeaponRack", Vector3.new(x, 0.8, 5 - math.abs(x) * 0.3), x * -4, 1.35, { Hitbox = true })
        local _ = i
    end
    L(m, cf, Vector3.new(0.9, 7, 0.9), Vector3.new(-8, 4.3, -1), { Color = WOOD, Material = Enum.Material.Wood })
    L(m, cf, Vector3.new(4.5, 0.8, 0.8), Vector3.new(-8, 6.4, -1), { Color = WOOD, Material = Enum.Material.Wood })
    L(m, cf, Vector3.new(2.4, 3, 1.6), Vector3.new(-8, 5.2, -1), { Color = Color3.fromRGB(150, 130, 96), Material = Enum.Material.Fabric })
    KitL(m, cf, "BannerPole", Vector3.new(9, 0.8, -1), 180, 1.3, { Hitbox = Vector3.new(1, 11, 1) })
end
function PROPS.Season(m, cf, col)
    -- SEASON JOURNEY: a herald's stage -- banners, the trophy, a board of the season's tiers
    L(m, cf, Vector3.new(12, 1.4, 6), Vector3.new(0, 1.5, 4.5), { Color = Color3.fromRGB(52, 38, 28), Material = Enum.Material.WoodPlanks })
    for _, x in ipairs({ -7, 0, 7 }) do
        KitL(m, cf, "BannerPole", Vector3.new(x, 2.2, 6.5), 180, 1.6, { Hitbox = Vector3.new(1, 13, 1), Tint = Color3.fromRGB(200, 160, 255) })
    end
    local gold = Color3.fromRGB(255, 200, 70)
    L(m, cf, Vector3.new(2.4, 3, 2.4), Vector3.new(0, 3.7, 3), { Color = Color3.fromRGB(40, 36, 44), Material = Enum.Material.Marble })
    L(m, cf, Vector3.new(0.8, 2.4, 0.8), Vector3.new(0, 6.4, 3), { Color = gold, Material = Enum.Material.Foil })
    L(m, cf, Vector3.new(2.4, 2.8, 2.8), Vector3.new(0, 8.6, 3), { Shape = Enum.PartType.Cylinder, Color = gold, Material = Enum.Material.Foil }, CFrame.Angles(0, 0, math.rad(90)))
    KitL(m, cf, "NoticeBoard", Vector3.new(-8.5, 0.8, -0.5), 30, 1.5, { Hitbox = true })
end

-- ------------------------------------------------------------------ leaderboard walls
-- 5 board panels on each curtain wall, above the booths; the client draws them (HubBoards). Each panel names the board
-- it shows (attr BoardId = EndgameServer Boards() Id, or "Drops" = LivingHub's recent big drops), so a new board in the
-- catalog never shifts the walls (0.99r's Gauntlet Run board pushed HIGHEST LEVEL onto the Aim Trial wall and dropped
-- TARGET SWITCH). Headers span their group of boards.
local BOARD_Y = 39 -- (above the shop signs: from the street the INVENTORY sign hid the bottom of the nearest board)
local BOARD_SIZE = 18
-- (HUB LOOK v2 2026-10-24, owner: "Leaderboards definitely need to look a little nicer and can move"): in the city they are
-- built-in LIGHTBOX signs like the shop boards, a size smaller and 5 studs higher -- a clear band of wall (and the
-- shop-level string course) between them and the shop signs, still read from the plaza. HubCity.Facade keeps its relief
-- out of BOARD_ZONE.
if HUB_STYLE == "City" then BOARD_Y = 44; BOARD_SIZE = 16 end
local BOARD_Z = { -40, -20, 0, 20, 40 } -- gate end -> spawn end
local function BoardGroups()
    local trials = {}
    local okT, AimTrials = pcall(function() return require(game:GetService("ReplicatedStorage").AimRngShared.AimTrials) end)
    for _, s in ipairs(okT and AimTrials.Scenarios or {}) do
        if #trials < 4 then table.insert(trials, "Trial_" .. s.Id) end
    end
    return {
        { Side = -1, Title = "HALL OF LEGENDS", Color = Color3.fromRGB(255, 200, 70), Ids = { "Line", "Daily", "RiftWeekly", "RiftHighest", "PlayerLevel" } },
        { Side = 1, Title = "AIM TRIAL CHAMPIONS", Color = Color3.fromRGB(110, 210, 255), Ids = trials },
        { Side = 1, Title = "THIS SERVER", Color = Color3.fromRGB(255, 120, 200), Ids = { "Drops" }, From = 5 },
    }
end
local function BuildBoards(hub: Folder)
    local folder = Instance.new("Folder")
    folder.Name = "Leaderboards"
    folder.Parent = hub
    local half = BOARD_SIZE / 2
    for _, grp in ipairs(BoardGroups()) do
        local side = grp.Side
        local x = side * (FLOOR_HALF - 0.5)
        local col = grp.Color
        local first = grp.From or 1
        for i, id in ipairs(grp.Ids) do
            local z = BOARD_Z[first + i - 1]
            if not z then break end
            local panel
            if HUB_STYLE == "City" then
                -- a steel lightbox cabinet set into the wall, the live panel 0.2 proud of its face, a neon tube along the top
                -- and bottom lip in the group's colour, steel side caps (5 parts; was 10)
                local wx = side * FLOOR_HALF -- (the facade line)
                P(folder, { Name = "BoardFrame", Size = Vector3.new(1.4, BOARD_SIZE + 1.3, BOARD_SIZE + 1.0), Position = Vector3.new(wx - side * 0.7, BOARD_Y, z), Color = Color3.fromRGB(26, 26, 30), Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
                panel = P(folder, { Name = "BoardPanel", Size = Vector3.new(0.2, BOARD_SIZE, BOARD_SIZE), Position = Vector3.new(wx - side * 1.5, BOARD_Y, z), Color = Color3.fromRGB(14, 13, 16), Material = Enum.Material.SmoothPlastic, CanCollide = false })
                for _, dy in ipairs({ half + 0.36, -(half + 0.36) }) do
                    local e = P(folder, { Name = "BoardEdge", Size = Vector3.new(0.25, 0.25, BOARD_SIZE + 0.4), Position = Vector3.new(wx - side * 1.55, BOARD_Y + dy, z), Color = col, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
                    e.CastShadow = false
                end
                for _, dz in ipairs({ -(half + 0.7), half + 0.7 }) do
                    P(folder, { Name = "BoardPost", Size = Vector3.new(1.8, BOARD_SIZE + 1.7, 0.45), Position = Vector3.new(wx - side * 0.9, BOARD_Y, z + dz), Color = Color3.fromRGB(52, 54, 60), Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
                end
            else
                P(folder, { Name = "BoardFrame", Size = Vector3.new(1, BOARD_SIZE + 1, BOARD_SIZE + 1), Position = Vector3.new(x, BOARD_Y, z), Color = WOOD, Material = Enum.Material.WoodPlanks })
                for _, dy in ipairs({ half + 0.6, -(half + 0.6) }) do
                    P(folder, { Name = "BoardRule", Size = Vector3.new(0.5, 0.8, BOARD_SIZE + 1.6), Position = Vector3.new(x - side * 0.5, BOARD_Y + dy, z), Color = IRON, Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
                end
                panel = P(folder, { Name = "BoardPanel", Size = Vector3.new(0.3, BOARD_SIZE, BOARD_SIZE), Position = Vector3.new(x - side * 0.6, BOARD_Y, z), Color = Color3.fromRGB(16, 13, 12), Material = Enum.Material.SmoothPlastic, CanCollide = false })
            end
            panel:SetAttribute("BoardId", id)
            panel:SetAttribute("Face", (side < 0) and "Right" or "Left") -- the face that looks into the bailey
            panel:SetAttribute("Accent", col)
        end
        -- the header spans exactly this group's boards
        local zA, zB = BOARD_Z[first], BOARD_Z[math.min(#BOARD_Z, first + #grp.Ids - 1)]
        if zA and zB and #grp.Ids > 0 then
            local len = (zB - zA) + BOARD_SIZE + 1 -- (a stud apart from the next group's header)
            if HUB_STYLE == "City" then
                -- (HUB LOOK v2) the group's name plate sits ON the cabinets (one sign band, a neon tube under it), like a shop board
                -- (pass 2 fix: the plate sits 1.2 clear of the cabinets in a steel frame -- from the street its letters ran into the
                -- middle board's title -- and the Sign's coloured end block is hidden: it read as a stray gold bracket)
                local hy = BOARD_Y + half + 0.65 + 1.2 + 2.2
                P(folder, { Name = "BoardsHeaderFrame", Size = Vector3.new(1.0, 4.9, len + 0.6), Position = Vector3.new(side * FLOOR_HALF - side * 0.5, hy, (zA + zB) / 2), Color = Color3.fromRGB(52, 54, 60), Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
                local h = P(folder, { Name = "BoardsHeader", Size = Vector3.new(1.45, 4.4, len), Position = Vector3.new(side * FLOOR_HALF - side * 0.725, hy, (zA + zB) / 2), Color = Color3.fromRGB(20, 18, 22), Material = Enum.Material.Metal, CanQuery = false })
                local hs = Sign(h, (side < 0) and Enum.NormalId.Right or Enum.NormalId.Left, grp.Title, nil, col, 20, "Neon")
                local blk = hs:FindFirstChild("Plate") and hs.Plate:FindFirstChild("Block")
                if blk then blk.Visible = false end
                local t = P(folder, { Name = "BoardsHeaderNeon", Size = Vector3.new(0.25, 0.25, len - 0.6), Position = Vector3.new(side * FLOOR_HALF - side * 1.55, hy - 2.5, (zA + zB) / 2), Color = col, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
                t.CastShadow = false
            else
                local h = P(folder, { Name = "BoardsHeader", Size = Vector3.new(1, 3.4, len), Position = Vector3.new(side * (FLOOR_HALF - 0.9), BOARD_Y + half + 3, (zA + zB) / 2), Color = Color3.fromRGB(22, 18, 16), Material = Enum.Material.Metal, CanQuery = false })
                Sign(h, (side < 0) and Enum.NormalId.Right or Enum.NormalId.Left, grp.Title, nil, col, 20, "Neon")
            end
        end
    end
end

-- ------------------------------------------------------------------ Training Grounds
function HubGenerator.SpawnDpsDummy(pos: Vector3, parent: Instance): Model
    -- (0.58, owner: "DPS dummy needs a complete revamp, it also glitches through hideout roof"): a padded combat
    -- training bot on a spring post -- red canvas torso with steel chest plates, a bullseye CORE front and back (weak
    -- spot), padded arm stubs, a helmet head with a lit visor. 11.3 studs tall (was 12.9: the head poked through the
    -- forest shed's roof). Same part names + attributes as before (Head / Core = weak spots, every part Damageable).
    local model = Instance.new("Model")
    model.Name = "DpsDummy"
    model:SetAttribute("Health", 1e7)
    model:SetAttribute("MaxHealth", 1e7)
    model:SetAttribute("IsPracticeDummy", true)
    model:SetAttribute("DpsDummy", true) -- never dies; CombatServer reports each hit to its shooter (DpsTick)
    local STEEL, DARKS, CANVAS, VISOR, HAZ = Color3.fromRGB(78, 82, 94), Color3.fromRGB(34, 36, 44), Color3.fromRGB(176, 52, 48), Color3.fromRGB(90, 220, 255), Color3.fromRGB(255, 170, 40)
    local base = pos
    local function deco(name, size, cframe, color, mat, shape, transp)
        local p = MakePart({ Name = name, Size = size, CFrame = cframe, Color = color, Material = mat or Enum.Material.Metal, CanCollide = false, CanQuery = false, CanTouch = false, Parent = model })
        if shape then p.Shape = shape end
        if transp then p.Transparency = transp end
        return p
    end
    local function part(name, size, cframe, color, mat, shape)
        local p = MakePart({ Name = name, Size = size, CFrame = cframe, Color = color, Material = mat or Enum.Material.Metal, CanCollide = true, CanQuery = true })
        if shape then p.Shape = shape end
        p:SetAttribute("Damageable", true)
        p.Parent = model
        return p
    end
    local UP = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder standing up)
    local FACE = CFrame.Angles(0, math.rad(90), 0) -- (a cylinder facing along z)
    MakePart({ Name = "Stand", Size = Vector3.new(0.6, 6.6, 6.6), CFrame = CFrame.new(base + Vector3.new(0, 0.3, 0)) * UP, Shape = Enum.PartType.Cylinder,
        Color = DARKS, Material = Enum.Material.DiamondPlate, CanQuery = false, Parent = model })
    deco("StandRing", Vector3.new(0.4, 7.0, 7.0), CFrame.new(base + Vector3.new(0, 0.28, 0)) * UP, HAZ, Enum.Material.Neon, Enum.PartType.Cylinder, 0.35) -- (a band round the base edge)
    MakePart({ Name = "Pole", Size = Vector3.new(3.2, 0.7, 0.7), CFrame = CFrame.new(base + Vector3.new(0, 2.2, 0)) * UP, Shape = Enum.PartType.Cylinder,
        Color = STEEL, Material = Enum.Material.Metal, CanQuery = false, Parent = model })
    for k = 0, 2 do deco("Coil", Vector3.new(0.22, 1.4, 1.4), CFrame.new(base + Vector3.new(0, 1.3 + k * 0.8, 0)) * UP, Color3.fromRGB(150, 154, 166), Enum.Material.Metal, Enum.PartType.Cylinder) end
    deco("Hips", Vector3.new(2.6, 0.9, 1.6), CFrame.new(base + Vector3.new(0, 4.05, 0)), DARKS, Enum.Material.Metal)
    local torso = part("Torso", Vector3.new(3.8, 3.6, 2), CFrame.new(base + Vector3.new(0, 6.3, 0)), CANVAS, Enum.Material.SmoothPlastic)
    for _, z in ipairs({ -1.05, 1.05 }) do
        deco("ChestPlate", Vector3.new(2.6, 2.4, 0.16), CFrame.new(base + Vector3.new(0, 6.5, z)), STEEL, Enum.Material.DiamondPlate)
        local core = part("Core", Vector3.new(0.18, 1.5, 1.5), CFrame.new(base + Vector3.new(0, 6.5, z * 1.14)) * FACE, Color3.fromRGB(245, 240, 230), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
        deco("CoreRing", Vector3.new(0.2, 1.0, 1.0), core.CFrame * CFrame.new(math.sign(-z) * 0.02, 0, 0), Color3.fromRGB(230, 50, 50), Enum.Material.Neon, Enum.PartType.Cylinder)
        deco("CoreDot", Vector3.new(0.22, 0.4, 0.4), core.CFrame * CFrame.new(math.sign(-z) * 0.04, 0, 0), Color3.fromRGB(255, 240, 220), Enum.Material.Neon, Enum.PartType.Cylinder)
    end
    for _, x in ipairs({ -1.6, 1.6 }) do deco("Strap", Vector3.new(0.3, 3.62, 2.04), CFrame.new(base + Vector3.new(x, 6.3, 0)), DARKS, Enum.Material.Fabric) end
    part("ArmL", Vector3.new(1.2, 3, 1.3), CFrame.new(base + Vector3.new(-2.55, 6.4, 0)) * CFrame.Angles(0, 0, math.rad(-8)), CANVAS, Enum.Material.SmoothPlastic)
    part("ArmR", Vector3.new(1.2, 3, 1.3), CFrame.new(base + Vector3.new(2.55, 6.4, 0)) * CFrame.Angles(0, 0, math.rad(8)), CANVAS, Enum.Material.SmoothPlastic)
    for _, x in ipairs({ -2.5, 2.5 }) do deco("Pad", Vector3.new(1.5, 0.6, 1.6), CFrame.new(base + Vector3.new(x, 8.0, 0)), STEEL, Enum.Material.Metal) end
    deco("Neck", Vector3.new(0.8, 0.9, 0.8), CFrame.new(base + Vector3.new(0, 8.45, 0)), DARKS, Enum.Material.Metal)
    part("Head", Vector3.new(2.2, 2.2, 2.2), CFrame.new(base + Vector3.new(0, 9.75, 0)), Color3.fromRGB(44, 46, 56), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
    for _, z in ipairs({ -1, 1 }) do deco("Visor", Vector3.new(1.6, 0.36, 0.3), CFrame.new(base + Vector3.new(0, 9.9, z * 0.92)), VISOR, Enum.Material.Neon) end
    deco("Antenna", Vector3.new(0.12, 0.7, 0.12), CFrame.new(base + Vector3.new(0.5, 11.0, 0)), STEEL, Enum.Material.Metal)
    deco("AntennaTip", Vector3.new(0.26, 0.26, 0.26), CFrame.new(base + Vector3.new(0.5, 11.38, 0)), Color3.fromRGB(255, 70, 60), Enum.Material.Neon, Enum.PartType.Ball)
    model.PrimaryPart = torso
    game:GetService("CollectionService"):AddTag(model, "AimRngEnemy")
    model.Parent = parent
    return model
end

local BAY_COLORS = {
    Tracker = Color3.fromRGB(80, 190, 255), Strafer = Color3.fromRGB(255, 220, 70), Drifter = Color3.fromRGB(120, 235, 150), Blinker = Color3.fromRGB(205, 120, 255),
    Hopper = Color3.fromRGB(255, 150, 80), Charger = Color3.fromRGB(255, 95, 95), DPS = Color3.fromRGB(255, 70, 70), Juggernaut = Color3.fromRGB(255, 140, 40),
    Sniper = Color3.fromRGB(255, 70, 70), Runner = Color3.fromRGB(90, 225, 255), Skirmisher = Color3.fromRGB(255, 205, 80), Warden = Color3.fromRGB(120, 200, 255),
    Gunship = Color3.fromRGB(255, 110, 60),
}
local BAY_TEXT = {
    Tracker = "steady glide", Strafer = "fast side-to-side", Drifter = "slow drifting", Blinker = "teleports", Hopper = "bouncing",
    Charger = "rushes you", Juggernaut = "big + slow", Sniper = "far + peeking", Runner = "ground runner", Skirmisher = "jinking walker",
    Warden = "shielded: aim high", Gunship = "heavy flyer", DPS = "test your damage",
}

local function BuildTrainingGrounds(hub: Folder)
    -- HUB v4: the range is the keep's FIRING YARD -- open to the dusk sky, stone walls, packed dirt, timber bay fences,
    -- sandbags along the firing line, wooden backstops with painted targets. Bays / pads / the DPS dummy are unchanged
    -- (RangeClient reads the zone pads' attributes).
    local R = HubGenerator.RANGE
    local tg = Instance.new("Folder")
    tg.Name = "TrainingGrounds"
    tg.Parent = hub
    local W = R.HalfX
    local depth = R.Z1 - R.Z0
    local midZ = (R.Z0 + R.Z1) / 2
    local trim = Color3.fromRGB(255, 190, 110)
    -- WALLED CITY (2026-10-05, owner: "Fix the training ground"): HubCity.Range dresses the yard as a back lot (tower
    -- blocks for walls, sodium lamps, lanterns, the range sign); the bays below get steel barriers + metal signs.
    -- Terrain voxels are 4 studs: the yard's ground really renders at y 4 (HubCity.GROUND), not FloorTop 2 -- the old
    -- pads / edge strips / markers were buried under it. Visuals sit on GF; RANGE (RangeClient's numbers) is unchanged.
    local city = HUB_STYLE == "City"
    local GF = city and HubCity.GROUND or R.FloorTop
    -- (RANGE REDO 2026-10-24: downrange is packed dirt, a concrete apron runs from the firing strip to HubCity.SHED.Apron
    -- (the lane numbers sit on it), and a sand BACKSTOP BERM rises along the back wall behind the farthest bots (z > 233))
    Terrain:FillBlock(CFrame.new(0, R.FloorTop - 2, midZ), Vector3.new(W * 2 + 8, 4, depth + 6), Enum.Material.Ground)
    local apron = city and HubCity.SHED.Apron or R.LineZ
    Terrain:FillBlock(CFrame.new(0, R.FloorTop - 2, (R.Z0 + apron) / 2), Vector3.new(W * 2, 4, apron - R.Z0), city and Enum.Material.Concrete or Enum.Material.Pavement)
    if city then
        Terrain:FillWedge(CFrame.new(0, HubCity.GROUND + 4, R.Z1 - 2.6), Vector3.new(W * 2 + 8, 8, 6), Enum.Material.Ground)
    end
    -- walls (stone), crenellated tops, invisible colliders above (bots and players stay in)
    -- (City: the walls stay as invisible colliders -- the tower blocks are what you see)
    local function RWall(name, size, pos)
        local w = P(tg, { Name = name, Size = size, Position = pos, Color = STONE, Material = Enum.Material.Cobblestone })
        if city then w.Transparency = 1; w.CastShadow = false; w.CanQuery = false end
        local c = P(tg, { Name = name .. "Collider", Size = Vector3.new(size.X, 40, size.Z), Position = pos + Vector3.new(0, size.Y / 2 + 20, 0), Transparency = 1, CanQuery = false })
        c.CastShadow = false
    end
    RWall("RangeWallS", Vector3.new(W * 2 + 2, R.Height, 3), Vector3.new(0, R.Height / 2, R.Z1 + 1.5))
    RWall("RangeWallE", Vector3.new(3, R.Height, depth + 2), Vector3.new(W + 1.5, R.Height / 2, midZ))
    RWall("RangeWallW", Vector3.new(3, R.Height, depth + 2), Vector3.new(-W - 1.5, R.Height / 2, midZ))
    local nw = W - (FLOOR_HALF + 2)
    for _, s in ipairs({ -1, 1 }) do
        RWall("RangeWallN", Vector3.new(nw + 2, R.Height, 3), Vector3.new(s * (FLOOR_HALF + 2 + nw / 2), R.Height / 2, R.Z0 + 1.5))
    end
    for x = -W + 4, W - 4, 8 do
        if city then break end
        local mm = P(tg, { Name = "Merlon", Size = Vector3.new(4, 4, 3), Position = Vector3.new(x, R.Height + 2, R.Z1 + 1.5), Color = STONE, Material = Enum.Material.Cobblestone, CanQuery = false })
        mm.CastShadow = false
    end
    -- the gatehouse sign over the doorway (bailey side)
    local dsign = P(tg, { Name = "DoorSign", Size = Vector3.new(30, 5, 0.6), Position = Vector3.new(0, 33, city and (HubCity.SOUTH_FRONT - 0.5) or (FLOOR_HALF - 1.4)), Color = Color3.fromRGB(28, 22, 18), Material = Enum.Material.WoodPlanks, CanQuery = false })
    Sign(dsign, Enum.NormalId.Front, "TRAINING GROUNDS", "DPS test  •  a range for every bot", Color3.fromRGB(255, 200, 120), 24)
    -- the firing line: a timber rail with sandbags under it, braziers every few bays
    -- (City: a steel crowd barrier with a hazard-striped top rail; HubCity.Range puts sodium lamps where the braziers were)
    local rvR = Random.new(2412) -- (HUB LOOK 2026-10-24: per-bay variation, its own stream)
    -- (RANGE REDO 2026-10-24: in the city the firing line is the booths' counters + partitions -- HubCity.RangeShed; the
    -- hazard rail, its posts and every neon strip / frame / colour pool / fence below are gone)
    local rail = (not city) and P(tg, { Name = "Railing", Size = Vector3.new(W * 2, 0.8, 0.8), Position = Vector3.new(0, GF + 3, R.LineZ + 0.5), Color = city and Color3.fromRGB(150, 120, 40) or WOOD, Material = city and Enum.Material.Metal or Enum.Material.WoodPlanks })
    if false then -- (RANGE REDO: the city's hazard rail is gone)
        for _, face in ipairs({ Enum.NormalId.Back, Enum.NormalId.Front, Enum.NormalId.Top }) do
            local tx = Instance.new("Texture")
            tx.Texture = "rbxassetid://123887840862473" -- (UIStyle.Art.Hazard)
            tx.Face = face; tx.StudsPerTileU = 1.6; tx.StudsPerTileV = 0.8; tx.Transparency = 0.15
            tx.Color3 = Color3.fromRGB(150, 138, 118) -- (HUB LOOK 2026-10-24: worn paint at night, not a glowing caution strip)
            tx.Parent = rail
        end
        P(tg, { Name = "RailLow", Size = Vector3.new(W * 2, 0.3, 0.3), Position = Vector3.new(0, GF + 1.4, R.LineZ + 0.5), Color = Color3.fromRGB(46, 48, 52), Material = Enum.Material.Metal, CanCollide = false, CanQuery = false })
    end
    for x = -W + 6, W - 6, 12 do
        if city then break end
        P(tg, { Name = "RailPost", Size = Vector3.new(city and 0.4 or 0.8, 3, city and 0.4 or 0.8), Position = Vector3.new(x, GF + 1.5, R.LineZ + 0.5), Color = city and Color3.fromRGB(46, 48, 52) or WOOD,
            Material = city and Enum.Material.Metal or Enum.Material.WoodPlanks, CanQuery = false })
    end
    if city then
        HubCity.Range(tg, { P = P, Light = Light, FLOOR_HALF = FLOOR_HALF }, R)
    else
        for i, x in ipairs({ -W + 24, -W + 72, -W + 120, W - 120, W - 72, W - 24 }) do Brazier(tg, Vector3.new(x, R.FloorTop, R.LineZ - 4), 1.7, nil, i % 2 == 1) end -- (lights: every other)
    end
    -- bays
    for i, kind in ipairs(R.Bays) do
        local cx = -W + R.BayW * (i - 0.5)
        local col = BAY_COLORS[kind] or trim
        if i > 1 then
            local x = -W + R.BayW * (i - 1)
            -- a timber fence between bays (rails + posts)
            local len = R.Z1 - R.LineZ - 1
            local cz = (R.LineZ + R.Z1) / 2 + 0.5
            -- (City: a steel barrier -- dark rails, diamond-plate posts, a thin neon line along the top)
            for _, y in ipairs(city and {} or { 3, 6.5 }) do
                P(tg, { Name = "BayFence", Size = Vector3.new(city and 0.3 or 0.5, city and 0.35 or 0.6, len), Position = Vector3.new(x, GF + y, cz), Color = city and Color3.fromRGB(58, 60, 66) or WOOD,
                    Material = city and Enum.Material.Metal or Enum.Material.WoodPlanks, CanQuery = false })
            end
            if false then -- (RANGE REDO: no neon line along the bay fences)
                local ln = P(tg, { Name = "BayNeon", Size = Vector3.new(0.14, 0.14, len), Position = Vector3.new(x, GF + 6.9, cz), Color = Color3.fromRGB(200, 215, 255), Material = Enum.Material.Neon, Transparency = 0.45, CanCollide = false, CanQuery = false })
                ln.CastShadow = false
            end
            for z = R.LineZ + 4, city and -1 or (R.Z1 - 4), 22 do -- (RANGE REDO: no fence posts in the city: chalk lane lines)
                P(tg, { Name = "BayPost", Size = Vector3.new(city and 0.5 or 0.8, 8, city and 0.5 or 0.8), Position = Vector3.new(x, GF + 4, z), Color = city and Color3.fromRGB(40, 42, 46) or WOOD,
                    Material = city and Enum.Material.DiamondPlate or Enum.Material.WoodPlanks, CanQuery = false })
            end
            local div = P(tg, { Name = "BayDivider", Size = Vector3.new(1, 12, len), Position = Vector3.new(x, R.FloorTop + 6, cz), Transparency = 1, CanQuery = false })
            div.CastShadow = false -- (the old solid divider's collision: bots stay in their bay)
        end
        -- distance markers: small painted stakes (City: faded paint lines across the bay)
        for d = 1, city and 0 or 4 do -- (RANGE REDO: the coloured distance paint is gone: gantries + chalk lines)
            if city then
                local m = P(tg, { Name = "Marker", Size = Vector3.new(R.BayW - 5, 0.05, 0.7), Position = Vector3.new(cx, GF + 0.03, R.LineZ + d * 32), Color = col, Material = Enum.Material.SmoothPlastic, Transparency = 0.55, CanCollide = false, CanQuery = false })
                m.CastShadow = false
            else
                P(tg, { Name = "Marker", Size = Vector3.new(0.5, 1.6, 0.5), Position = Vector3.new(cx + R.BayW / 2 - 2, R.FloorTop + 0.8, R.LineZ + d * 32), Color = col, Material = Enum.Material.SmoothPlastic, CanQuery = false })
            end
        end
        -- (no backstop name boards: owner 2026-10-05 "just have wall in the back" -- the yard's stone wall is the backdrop)
        -- bay plaque over the entrance (facing the firing line)
        -- (City: a dark metal sign box, the billboard style, with a neon edge in the bay's colour)
        local hdr = (not city) and P(tg, { Name = "BayHeader", Size = Vector3.new(R.BayW - 3, 3.4, 0.5), Position = Vector3.new(cx, GF + 11, R.LineZ + 1.5), Color = city and Color3.fromRGB(16, 15, 18) or Color3.fromRGB(30, 22, 18),
            Material = city and Enum.Material.Metal or Enum.Material.WoodPlanks, CanQuery = false })
        if hdr then Sign(hdr, Enum.NormalId.Front, (kind == "DPS") and "DPS TEST" or string.upper(kind), (BAY_TEXT[kind] or "") .. "  •  step on the pad", col, 24, "Wood") end
        if city then
            -- (RANGE REDO 2026-10-24: the bay plate is a stencilled lane plate on the shed's fascia now -- HubCity.RangeShed;
            -- no neon tube frame, no colour pool on the floor. The lane number stays, painted white on the concrete apron)
            -- (UPDATE 4, owner: "ensure the shooting range is included" in the quality pass) a full neon tube frame round the
            -- header, the bay's colour pooled on the firing line (self-lit, no light), its lane number painted on the floor past
            -- the line, a sandbag berm behind the farthest targets (kit meshes; nothing between the line and the bots)
            local num = P(tg, { Name = "LaneNumber", Size = Vector3.new(7, 0.05, 4.5), CFrame = CFrame.new(cx, GF + 0.04, R.LineZ + 7), Transparency = 1, CanCollide = false, CanQuery = false })
            num.CastShadow = false
            local nsg = Instance.new("SurfaceGui"); nsg.Face = Enum.NormalId.Top; nsg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; nsg.PixelsPerStud = 24
            nsg.LightInfluence = 0.6; nsg.Brightness = 1.2; nsg.Parent = num
            local nt = Instance.new("TextLabel"); nt.BackgroundTransparency = 1; nt.Size = UDim2.fromScale(1, 1); nt.TextScaled = true
            nt.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold); nt:SetAttribute("KeepFont", true)
            nt.Text = string.format("%02d", i); nt.TextColor3 = Color3.fromRGB(226, 222, 208); nt.TextTransparency = 0.35; nt.Rotation = 180; nt.Parent = nsg
            -- (HUB LOOK 2026-10-24, owner: "copy and paste items": the same three bags at the same angles in all 13 bays ->
            -- each pile its own spacing, angle and size, now and then pushed together or set back)
            for k = -1, 1 do
                local bx = cx + k * rvR:NextNumber(6.2, 8.4) + rvR:NextNumber(-0.8, 0.8)
                Kit(tg, "Sandbags", CFrame.new(bx, GF, R.Z1 - 7 + rvR:NextNumber(-1.2, 0.6)) * CFrame.Angles(0, math.rad(180 + rvR:NextNumber(-16, 16)), 0), 1.25 * rvR:NextNumber(0.88, 1.12))
            end
        end
        for _, s in ipairs(city and {} or { -1, 1 }) do
            P(tg, { Name = "HeaderPost", Size = Vector3.new(city and 0.4 or 0.7, 12.7, city and 0.4 or 0.7), Position = Vector3.new(cx + s * (R.BayW / 2 - 1.5), GF + 6.35, R.LineZ + 1.5), Color = city and Color3.fromRGB(40, 42, 46) or WOOD,
                Material = city and Enum.Material.Metal or Enum.Material.WoodPlanks, CanQuery = false })
        end
        -- the zone pad on the firing line: standing on it starts the bay (RangeClient reads these attributes)
        local pad = P(tg, { Name = "RangeZone", Size = Vector3.new(R.BayW - 3, 0.12, R.LineZ - R.Z0 - 6), Position = Vector3.new(cx, GF + 0.06, (R.Z0 + R.LineZ) / 2 + 1.5),
            Color = col, Material = Enum.Material.Neon, Transparency = city and 1 or 0.86, CanCollide = false, CanQuery = false, CanTouch = false }) -- (RANGE REDO: invisible in the city -- the booth mat shows where to stand)
        pad.CastShadow = false
        pad:SetAttribute("Kind", kind)
        pad:SetAttribute("BayIndex", i)
        pad:SetAttribute("Color", col)
        pad:SetAttribute("MinX", cx - R.BayW / 2 + 2); pad:SetAttribute("MaxX", cx + R.BayW / 2 - 2)
        pad:SetAttribute("MinZ", R.LineZ + 20); pad:SetAttribute("MaxZ", R.LineZ + ((kind == "Sniper") and 135 or 80)) -- snipers sit far back
        for _, s in ipairs(city and {} or { -1, 1 }) do
            Neon(tg, CFrame.new(cx + s * (R.BayW / 2 - 1.5), GF + 0.08, (R.Z0 + R.LineZ) / 2 + 1.5), Vector3.new(0.3, 0.1, R.LineZ - R.Z0 - 6), Vector3.zero, col, 0.35)
        end
        if kind == "DPS" then
            HubGenerator.SpawnDpsDummy(Vector3.new(cx, GF, R.LineZ + 28), tg)
        end
    end
    if city then HubCity.RangeShed(tg, { P = P, Light = Light, FLOOR_HALF = FLOOR_HALF }, R, BAY_COLORS, BAY_TEXT) end
end

-- ------------------------------------------------------------------ build
function HubGenerator.BuildHub(): Folder
    HubGenerator.SetupLighting()
    local old = Workspace:FindFirstChild("HubWorld")
    if old then old:Destroy() end
    local hub = Instance.new("Folder")
    hub.Name = "HubWorld"
    hub.Parent = Workspace

    local H = { P = P, L = L, Neon = Neon, Light = Light, Prompt = Prompt, Emit = Emit, FLOOR_TOP = FLOOR_TOP, FLOOR_HALF = FLOOR_HALF, GROUND = HubCity.GROUND }
    local city = HUB_STYLE == "City"
    if city then
        HubCity.Build(hub, H)
        HubCity.TintCenterpiece(BuildCenterpiece(hub))
        BuildSpawn(hub)
    else
        BuildHall(hub)
    end
    BuildGate(hub, -38, {
        City = city, ZH = "地下城",
        ModelName = "DungeonGate", VortexName = "PortalVortex", PromptName = "PromptDungeon", Menu = "Dungeons",
        Title = "DUNGEONS", Sub = "a new biome every floor  •  bosses  •  loot", Glyph = "✠",
        Action = "Enter the dungeons", Object = "DUNGEON GATE",
        Main = Color3.fromRGB(190, 70, 255), Accent = Color3.fromRGB(255, 60, 110), Stone = Color3.fromRGB(44, 38, 56), Banner = Color3.fromRGB(70, 20, 60),
        ArchTint = Color3.fromRGB(120, 108, 128), Fire = Color3.fromRGB(200, 110, 255), BannerTint = Color3.fromRGB(170, 120, 200),
    })
    BuildGate(hub, 38, {
        City = city, ZH = "挑戰",
        ModelName = "ChallengeGate", Mirror = true, VortexName = "ChallengeVortex", PromptName = "PromptChallenges", Menu = "Challenges",
        Title = "CHALLENGES", Sub = "boss trials  •  ascension  •  daily  •  aim trials", Glyph = "★",
        Action = "Open challenges", Object = "CHALLENGE GATE",
        Main = Color3.fromRGB(255, 170, 40), Accent = Color3.fromRGB(255, 240, 140), Stone = Color3.fromRGB(56, 48, 40), Banner = Color3.fromRGB(90, 50, 10),
        ArchTint = Color3.fromRGB(150, 132, 112), Fire = nil, BannerTint = nil,
    })
    -- booths: west wall faces +X, east wall faces -X (City: storefronts in the same spots, same anchors)
    local BuildBooth = city and function(h, cf, t) return HubCity.Shop(h, cf, t, H) end or BuildBooth
    local function westCF(z) return CFrame.lookAt(Vector3.new(-FLOOR_HALF + 12, FLOOR_TOP, z), Vector3.new(0, FLOOR_TOP, z)) end
    local function eastCF(z) return CFrame.lookAt(Vector3.new(FLOOR_HALF - 12, FLOOR_TOP, z), Vector3.new(0, FLOOR_TOP, z)) end
    BuildBooth(hub, westCF(-38), { Anchor = "ShopStand", PromptName = "PromptShop", Action = "Browse the market", Object = "SHOP",
        Title = "SHOP", Sub = "guns & gear  •  restocks every hour", Color = Color3.fromRGB(255, 200, 60), Prop = PROPS.Shop, HideCounter = true })
    BuildBooth(hub, westCF(-12), { Anchor = "RollAltar", PromptName = "PromptRoll", Action = "Open the forge", Object = "FORGE",
        Title = "FORGE", Sub = "free daily roll  •  upgrade  •  reroll", Color = Color3.fromRGB(255, 130, 40), Wall = Color3.fromRGB(40, 30, 28), WallMat = Enum.Material.Brick, Prop = PROPS.Forge })
    BuildBooth(hub, westCF(14), { Anchor = "UpgradeAnvil", PromptName = "PromptUpgrade", Action = "Upgrade a weapon", Object = "UPGRADE",
        Title = "UPGRADE", Sub = "push your gun to +20", Color = Color3.fromRGB(80, 170, 255), Prop = PROPS.Upgrade })
    BuildBooth(hub, westCF(40), { Anchor = "InvLocker", PromptName = "PromptInv", Action = "Open your inventory", Object = "INVENTORY",
        Title = "INVENTORY", Sub = "weapons  •  gear  •  currencies", Color = Color3.fromRGB(110, 140, 255), Prop = PROPS.Vault })
    BuildBooth(hub, eastCF(-38), { Anchor = "TreeAltar", PromptName = "PromptTree", Action = "Open the passive tree", Object = "SKILL TREE",
        Title = "SKILL TREE", Sub = "passive tree  •  socket gems", Color = Color3.fromRGB(110, 235, 120), Prop = PROPS.Tree })
    BuildBooth(hub, eastCF(-12), { Anchor = "IndexAltar", PromptName = "PromptIndex", Action = "Open the index", Object = "INDEX",
        Title = "INDEX", Sub = "every gun  •  rarities  •  bestiary", Color = Color3.fromRGB(0, 220, 255), Wall = Color3.fromRGB(34, 28, 24), Prop = PROPS.Codex })
    BuildBooth(hub, eastCF(14), { Anchor = "ArmoryStand", PromptName = "PromptArmory", Action = "Open the armory", Object = "ARMORY",
        Title = "ARMORY", Sub = "melee weapons", Color = Color3.fromRGB(255, 80, 90), Prop = PROPS.Armory })
    BuildBooth(hub, eastCF(40), { Anchor = "SeasonStand", PromptName = "PromptSeason", Action = "View the season pass", Object = "SEASON PASS",
        Title = "SEASON PASS", Sub = "50 tiers  •  free + premium rewards", Color = Color3.fromRGB(200, 120, 255), Prop = PROPS.Season })
    -- (the Style Studio booth is gone, 2026-10-02: players wear their own Roblox avatars)
    BuildBoards(hub)
    if city then HubCity.DimPlaza(hub) end -- (darker plaza surfaces, the light unchanged: gear keeps its look)
    BuildTrainingGrounds(hub)
    if city then hub:SetAttribute("SignPropsCleared", HubCity.ClearSignProps(hub)) end -- (HUBFIX: no facade prop through a sign / board / gate)
    return hub
end

return HubGenerator
