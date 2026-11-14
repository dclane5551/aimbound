--!strict
-- ROOM ATMOSPHERE PASS 2 -- ABYSS (The Deep; RoomAtmo API: see RoomAtmo "ATMOSPHERE PASS 2"). Its own treatment (reference:
-- turquoise water in dark caves, glowing growth on the rock, things hanging and swaying). Real meshes:
-- ReplicatedStorage.RoomAtmoKit.Abyss (tools/atmo_kit_abyss.py: giant kelp stands, tube worms with glowing plumes, anemones,
-- a giant clam with a pearl, reef boulders crusted with coral and sponges, shells) + the world's own WorldProps.Abyss
-- Coral / BrainCoral / SeaFan; without them the plain part pieces stand in.
--   CONTRAST  Light: the sun x0.55 (deep water), ambient x1 (the gun plate), a cold teal grade; palette x0.7 (sand x0.8), parts x0.7,
--             scanned props x0.55. The glowing plumes, anemones and the pearl carry the light.
--   GROUND    a GLOW REEF at the wall foot: reef boulders banked against the wall, tube worms with lit plumes and anemones
--             between them, the world's coral and sea fans, one soft cyan light a room, silt stirred in the current. The open
--             floor: A.PaintField rippled sand / slate / rock fields, shells, small vents breathing bubbles.
--   EDGE      GIANT KELP stands rising at the wall feet far over head height, a shaft of drowned light falling through the
--             water from above (beams, no parts)
--   SET PIECE a GIANT CLAM gaping open at a wall foot, a glowing pearl on its mantle, anemones round it, bubbles rising
--             (1 light)
--   DRIFT     marine snow sinking slowly
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.55, Ambient = 1.0, Outdoor = 0.95, Tint = C3(190, 230, 240), TintAmt = 0.3 }
B.Palette = { Dim = 0.7, Mats = { [M.Sand] = 0.8 } }
B.PartDim = 0.7
B.SADim = 0.55
B.Drift = { MarineSnow = true }

local CYAN, VIOLET, PEARL, ROCK = C3(60, 240, 230), C3(170, 120, 255), C3(220, 245, 255), C3(40, 56, 70)
local ROUGH = { Stipe = M.Grass, Blade = M.Grass, Float = M.SmoothPlastic, Tube = M.Limestone, Column = M.SmoothPlastic, Shell = M.Slate,
    Mantle = M.SmoothPlastic, Rock = M.Rock, -- (Shell: Slate so the pearl light doesn't wash it violet)
    Coral = M.Limestone, Sponge = M.Slate }

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Part, Paint, Emitter = A.Part, A.Paint, A.Emitter
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    local kitRoot = game:GetService("ReplicatedStorage"):FindFirstChild("RoomAtmoKit")
    local KIT = kitRoot and kitRoot:FindFirstChild("Abyss")
    -- a kit piece (KIT, or the world's props when world = true): size = height (byWidth: width); up = its up axis; face = the
    -- direction its front (-Z) looks; tint = the glowing parts' colour
    local function Kit(name: string, at: Vector3, size: number, up: Vector3?, byWidth: boolean?, face: Vector3?, world: boolean?, tint: Color3?): Model?
        local tmpl = world and A.WorldProp("Abyss", name) or (KIT and KIT:FindFirstChild(name))
        if not (tmpl and tmpl:IsA("Model")) then return nil end
        local _, bb = tmpl:GetBoundingBox()
        local h = byWidth and size * bb.Y / math.max(bb.X, bb.Z, 0.1) or size
        local u = (up or Vector3.yAxis).Unit
        local x = Vector3.yAxis:Cross(u)
        x = (x.Magnitude > 1e-3) and x.Unit or Vector3.xAxis
        local cf = CFrame.fromMatrix(at, x, u) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0)
        if face then cf = CFrame.lookAt(at, at + face, u) end
        local ok, m = pcall(A.PlaceModel, tmpl, fx, cf, h, name)
        if not ok or not m then return nil end
        for _, q in ipairs(m:GetDescendants()) do
            if q:IsA("BasePart") then
                n += 1
                local role = q:GetAttribute("Role")
                if q:GetAttribute("Glow") then
                    q.CastShadow = false
                    if tint then q.Color = tint end
                elseif role and ROUGH[role] then q.Material = ROUGH[role] end
                if role == "Blade" or role == "Shell" and size < 4 then q.CastShadow = false end
            end
        end
        return m
    end
    local function Worms(at: Vector3, s: number, col: Color3)
        if not Kit("TubeWorms", at, s, nil, nil, nil, false, col) then
            for k = 1, 3 do
                local q = at + Vector3.new(vr:NextNumber(-1, 1), 0, vr:NextNumber(-1, 1))
                Part(fx, "Worm", Enum.PartType.Cylinder, Vector3.new(s, 0.4, 0.4), CFrame.new(q + Vector3.new(0, s / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), C3(196, 186, 170), M.SmoothPlastic)
                n += 1
            end
        end
    end
    local function Anemone(at: Vector3, s: number, col: Color3)
        Kit("Anemone", at, s, nil, nil, nil, false, col)
    end
    -- GLOW REEF along the band: reef boulders against the wall, worms + anemones + the world's coral between them, 1 light
    local lit = false
    local function Reef(b0: Vector3, b1: Vector3, o: Vector3)
        local d = Vector3.new(b1.X - b0.X, 0, b1.Z - b0.Z)
        local len = d.Magnitude
        -- (v2, coordinator: "a ROW of near-identical domes at even spacing, each with the same coral tuft") -- CLUSTERS with
        -- gaps between them: each 1-3 pieces of mixed kind (coral-crowned / bare / stacked), sizes 0.6-2.2x, some sunk
        -- half into the sand, crowned differently (tube worms / anemone / sea fan / nothing)
        local u = (b1 - b0).Unit
        local t = vr:NextNumber(0, 4)
        local ci = 0
        while t < len - 3 do
            ci += 1
            local at = b0 + u * t + o * vr:NextNumber(0.5, 2.5)
            local pieces = vr:NextInteger(1, 3)
            for j = 1, pieces do
                local q = at + u * vr:NextNumber(-3, 3) + o * vr:NextNumber(-1, 1.5)
                local roll = vr:NextNumber()
                local kind = (roll < 0.4) and "ReefRock" or ((roll < 0.75) and "ReefBare" or "ReefStack")
                local sz = (kind == "ReefStack") and vr:NextNumber(6, 10) or vr:NextNumber(6, 13) * ((j == 1 and vr:NextNumber() < 0.35) and 2 or 1)
                local sink = (vr:NextNumber() < 0.4) and sz * vr:NextNumber(0.15, 0.3) or 0.6
                local byW = kind ~= "ReefStack"
                if not Kit(kind, Vector3.new(q.X, F - sink, q.Z), sz, nil, byW) and j == 1 then
                    Part(fx, "ReefRock", Enum.PartType.Ball, Vector3.new(5, 5, 5), CFrame.new(Vector3.new(q.X, F + 1, q.Z)), ROCK, M.Rock)
                    n += 1
                end
            end
            local col = (ci % 2 == 0) and VIOLET or CYAN
            local front = at - o * vr:NextNumber(3.5, 5) + u * vr:NextNumber(-2, 2)
            local crown = vr:NextInteger(1, 4)
            if crown == 1 then Worms(Vector3.new(front.X, F, front.Z), vr:NextNumber(2.6, 4), col)
            elseif crown == 2 then Anemone(Vector3.new(front.X, F, front.Z), vr:NextNumber(2.2, 3.2), col)
            elseif crown == 3 then Kit((vr:NextNumber() < 0.5) and "SeaFan" or "Coral", Vector3.new(front.X, F, front.Z), vr:NextNumber(3.5, 5.5), nil, nil, -o, true) end
            if Lava and crown <= 2 then Lava.Glow(fx, Vector3.new(front.X, F + 2.5, front.Z), 8, col, 0.5, { Name = "ReefGlow", MaxDistance = 400 }) end
            t += vr:NextNumber(11, 20)
        end
        local cq = b0:Lerp(b1, vr:NextNumber(0.2, 0.8)) - o * 1
        Kit((vr:NextNumber() < 0.5) and "SeaFan" or "Coral", Vector3.new(cq.X, F, cq.Z), vr:NextNumber(4, 5.5), nil, nil, -o, true)
        if ctx.Terrain then
            for i = 0, 3 do local q = b0:Lerp(b1, i / 3) + o * 1; Paint(q.X, q.Z, 5, M.Rock, vr) end
        end
        local mid = (b0 + b1) / 2
        if not lit then
            lit = true
            local c = A.Carrier(fx, "ReefLight", Vector3.new(1, 1, 1), CFrame.new(Vector3.new(mid.X, F + 3, mid.Z) - o * 3))
            local l = Instance.new("PointLight")
            l.Color = C3(110, 230, 230); l.Range = 26; l.Brightness = 0.9; l.Shadows = false
            l.Parent = c
        end
        Emitter(fx, "ReefSilt", CFrame.lookAt(Vector3.new(mid.X, F + 0.6, mid.Z) - o * 2, Vector3.new(mid.X, F + 0.6, mid.Z) - o * 2 + d.Unit), Vector3.new(4, 0.2, len), {
            Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(120, 170, 180)), LightInfluence = 1,
            Rate = 2, Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(0.3, 0.8), EmissionDirection = Enum.NormalId.Top,
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.85), NumberSequenceKeypoint.new(1, 1) }) })
    end
    -- THE FLOOR first (A.PaintField on its own stream): rippled sand / slate / rock -- 0 parts
    if A.PaintField then
        A.PaintField(P, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.Sand, 72 }, { M.Rock, 28 } },
            { Scale = 50, Stretch = 2.2, Warp = 18, Edge = 0.8 })
    end
    local isBand = {}
    for _, sd in ipairs(P.walls) do
        local b0, b1 = P.Band(sd, 5, 18)
        if b0 then
            isBand[sd] = true
            Reef(b0, b1, P.SIDES[sd])
        end
    end
    -- THE OPEN FLOOR: shells, small vents breathing bubbles (low, no collision)
    for _ = 1, 3 do
        local p = P.Spot(10)
        if not P.DoorNear(p, 10) then Kit("Shells", p, vr:NextNumber(3, 4), nil, true) end
    end
    for _ = 1, 2 do
        local p = P.Spot(14)
        if not P.DoorNear(p, 12) then
            Worms(p, vr:NextNumber(2, 2.8), CYAN)
            Emitter(fx, "VentBubbles", CFrame.new(p + Vector3.new(0, 0.5, 0)), Vector3.new(0.6, 0.2, 0.6), {
                Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C3(210, 245, 255)), LightEmission = 0.4, LightInfluence = 0.5,
                Rate = 2, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(2, 3.5), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(8, 8),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.4) }) })
        end
    end
    -- EDGE: giant kelp stands at the wall feet (every wall, two where it is long and clear), a shaft of drowned light
    local shaftFrom: Vector3? = nil
    local stands = 0
    for _, sd in ipairs(P.order) do
        local o, al = P.SIDES[sd], P.Along(sd)
        for _, f in ipairs({ vr:NextNumber(-0.7, -0.4), vr:NextNumber(0.4, 0.7) }) do
            if stands >= 5 then break end
            -- (v2: the first three stand 8 in from the wall and tall, so they read in the main eye-height view)
            local near = stands < 3
            local at = C0 + o * (half - (near and 8 or 2.5)) + al * f * half
            if not P.DoorNear(at, 14) then
                stands += 1
                local lean = math.rad(vr:NextNumber(3, 8))
                local up = (Vector3.yAxis * math.cos(lean) - o * math.sin(lean)).Unit
                if not Kit("KelpTall", Vector3.new(at.X, F - 0.4, at.Z), near and vr:NextNumber(34, 40) or vr:NextNumber(24, 30), up) then
                    Part(fx, "KelpStalk", nil, Vector3.new(0.6, 24, 0.6), CFrame.new(Vector3.new(at.X, F + 12, at.Z)), C3(48, 92, 64), M.Grass)
                    n += 1
                end
                shaftFrom = shaftFrom or (Vector3.new(at.X, F, at.Z) - o * 10)
            end
        end
    end
    if shaftFrom then
        local sf = shaftFrom :: Vector3
        local car = A.Carrier(fx, "DrownedLight", Vector3.new(1, 1, 1), CFrame.new(C0 + Vector3.new(0, 40, 0)))
        local a0 = Instance.new("Attachment"); a0.WorldPosition = sf + Vector3.new(0, 60, 0); a0.Parent = car
        local a1 = Instance.new("Attachment"); a1.WorldPosition = Vector3.new(sf.X, F, sf.Z):Lerp(C0, 0.3); a1.Parent = car
        local b = Instance.new("Beam")
        b.Attachment0 = a0; b.Attachment1 = a1
        b.Width0 = 10; b.Width1 = 18; b.FaceCamera = true; b.Segments = 1
        b.Texture = "rbxasset://textures/particles/smoke_main.dds"; b.TextureMode = Enum.TextureMode.Stretch
        b.Color = ColorSequence.new(C3(170, 240, 240)); b.LightEmission = 0.6; b.LightInfluence = 0
        b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.97), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(0.85, 0.88), NumberSequenceKeypoint.new(1, 1) })
        b.Parent = car
    end
    -- SET PIECE: a giant clam gaping open at a wall foot, the pearl glowing on its mantle, anemones round it, bubbles
    do
        local sd, spot = P.SetSpot(24, 10, isBand)
        if sd and spot then
            local o, al = P.SIDES[sd], P.Along(sd)
            local at = Vector3.new(spot.X, F, spot.Z) + o * 1
            if ctx.Terrain then Paint(at.X, at.Z, 12, M.Sand, vr) end
            -- (the kit's clam: face -Z into the room puts the hinge at the wall, the gape toward the room -- seen in play)
            -- (tipped ~22 degrees toward the room so the gape, the lit mantle and the pearl face the player)
            local tip = math.rad(22)
            local clam = Kit("GiantClam", at - Vector3.new(0, 0.6, 0) + o * 2, vr:NextNumber(17, 20), (Vector3.yAxis * math.cos(tip) - o * math.sin(tip)).Unit, true, -o)
            local pearlAt = at + Vector3.new(0, 5, 0)
            if clam then
                local pr = clam:FindFirstChild("Pearl")
                if pr and pr:IsA("BasePart") then pearlAt = pr.Position end
            else
                local pearl = Part(fx, "Pearl", Enum.PartType.Ball, Vector3.new(3, 3, 3), CFrame.new(pearlAt), PEARL, M.Neon)
                pearl.CastShadow = false
                n += 1
            end
            if Lava then Lava.Glow(fx, pearlAt, 16, C3(190, 240, 255), 0.45, { Name = "PearlGlow", MaxDistance = 600 }) end
            local c = A.Carrier(fx, "PearlLight", Vector3.new(1, 1, 1), CFrame.new(pearlAt - o * 5))
            local l = Instance.new("PointLight")
            l.Color = C3(190, 240, 255); l.Range = 26; l.Brightness = 1.1; l.Shadows = false
            l.Parent = c
            Emitter(fx, "ClamBubbles", CFrame.new(pearlAt + Vector3.new(0, 1, 0)), Vector3.new(2, 0.4, 2), {
                Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C3(210, 245, 255)), LightEmission = 0.5, LightInfluence = 0.4,
                Rate = 4, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(2.5, 4), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.5) }) })
            for s = -1, 1, 2 do
                local q = at + al * s * 11 - o * 2
                Anemone(Vector3.new(q.X, F, q.Z), vr:NextNumber(2.4, 3.2), (s > 0) and VIOLET or CYAN)
                Worms(Vector3.new(q.X, F, q.Z) + al * s * 3, 3.2, (s > 0) and CYAN or VIOLET)
            end
        end
    end
    -- DRIFT: marine snow sinking slowly
    Emitter(fx, "MarineSnow", CFrame.new(C0 + Vector3.new(0, 18, 0)), Vector3.new(half * 1.7, 2, half * 1.7), {
        Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C3(220, 240, 245)), LightEmission = 0.3, LightInfluence = 0.6,
        Rate = 12, Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(0.5, 1.2), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(20, 20),
        Acceleration = Vector3.new(0.2, -0.3, 0),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.08) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.3), NumberSequenceKeypoint.new(1, 1) }) })
    return n
end

return B
