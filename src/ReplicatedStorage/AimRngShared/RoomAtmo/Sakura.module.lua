--!strict
-- ROOM ATMOSPHERE PASS 2 -- SAKURA (the Sakura Shrine; RoomAtmo API: see RoomAtmo "ATMOSPHERE PASS 2"). Its own treatment
-- (reference: a carpet of petals under dark blossom, warm dappled dusk light, a shrine path). Real meshes:
-- ReplicatedStorage.RoomAtmoKit.Sakura (tools/atmo_kit_sakura.py: a gnarled cherry tree with clouds of blossom cards, a
-- petal carpet, stepping stones, a fallen temple bell with its broken frame, a raked gravel strip) + the world's own
-- WorldProps.Sakura Toro (stone lantern) / Torii; without them the plain part pieces stand in.
--   CONTRAST  (v2, coordinator: "a flat washed pink") Light: a lower warmer sun x0.6, ambient x0.9, a warm amber grade,
--             a deeper warm fog + less haze (ambient kept at x0.97 for the gun); the ground dark moss (grass x0.55) and the rims grey-green stone (rock / slate
--             recoloured), parts x0.72 -- so the blossom is the brightest thing on screen, with lantern glow under it.
--   GROUND    a LANTERN WALK at the wall foot: raked gravel strips with a stone kerb, stone lanterns along them whose
--             windows glow, petal carpets at their feet, one warm light a room. Narrow gravel WALKS curve in from every door
--             toward the room's heart. The rest: A.PaintField moss / short grass only (no earth, no paving fields), stepping
--             stones, petal carpets -- all low, no collision.
--   EDGE      THE BLOSSOM DOMINATES: 4-6 big CHERRY TREES at the wall feet round the room (every wall without a door in the
--             way) and 2-3 more standing on the rim, all leaning in so the canopies reach over the room edge above head
--             height, petals falling and a petal carpet under each; a vermilion TORII against another wall facing in
--   SET PIECE a FALLEN TEMPLE BELL: the great bronze bell on its side by its broken timber frame, a straw rope with paper
--             streamers across it, petals drifted round it, a lantern still burning (1 warm light)
--   DRIFT     petals blown across the room on the wind
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.6, Ambient = 0.97, Outdoor = 0.9, Tint = C3(255, 210, 170), TintAmt = 0.34, FogColor = C3(132, 104, 104), FogEnd = 0.75 }
B.Atmo = { Haze = 0.55, Density = 0.85 }
B.Palette = { Dim = 0.7, Mats = { [M.Grass] = 0.55, [M.LeafyGrass] = 0.55, [M.Rock] = C3(168, 196, 158), [M.Slate] = C3(150, 168, 146), [M.Pavement] = 0.75 } }
-- (Mats Color3 = a channel multiplier: rock 118,112,120 -> ~78,86,74 grey-green, slate 120 -> ~70,79,69)
B.PartDim = 0.72
B.SADim = 0.55 -- (the scanned boulders / busts keep their bright textures under PartDim: mapvibe's separate factor)
B.Drift = { PetalWind = true }

local PETAL, PETAL2, STONE, STONE2, WOOD = C3(250, 168, 196), C3(236, 140, 176), C3(150, 148, 140), C3(112, 110, 106), C3(80, 52, 40)
local WARM, VERMILION = C3(255, 196, 120), C3(196, 52, 40)
local ROUGH = { Bark = M.Wood, Core = M.Grass, Stone = M.Slate, Moss = M.Grass, Timber = M.Wood, Rope = M.Fabric, Gravel = M.Pebble, Bronze = M.Metal }

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Part, Paint, Emitter = A.Part, A.Paint, A.Emitter
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    local kitRoot = game:GetService("ReplicatedStorage"):FindFirstChild("RoomAtmoKit")
    local KIT = kitRoot and kitRoot:FindFirstChild("Sakura")
    -- a kit piece (KIT, or the world's props when world = true): size = height (byWidth: width); up = its up axis; face = the
    -- direction its front (-Z) looks
    local function Kit(name: string, at: Vector3, size: number, up: Vector3?, byWidth: boolean?, face: Vector3?, world: boolean?): Model?
        local tmpl = world and A.WorldProp("Sakura", name) or (KIT and KIT:FindFirstChild(name))
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
                if q:GetAttribute("Glow") then q.CastShadow = false
                elseif role and ROUGH[role] then q.Material = ROUGH[role] end
                if role == "Petal" or role == "Gravel" or role == "Moss" then q.CastShadow = false end
            end
        end
        return m
    end
    local function Drift(at: Vector3, s: number)
        if Kit("PetalDrift", at, s, nil, true) then return end
        local p = Part(fx, "PetalDrift", nil, Vector3.new(s, 0.12, s * 0.7), CFrame.new(at + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0), PETAL, M.SmoothPlastic)
        p.CastShadow = false
        n += 1
    end
    -- a stone lantern (the world's Toro), its window glowing
    local function Lantern(at: Vector3, face: Vector3, h: number)
        if not Kit("Toro", at, h, nil, nil, face, true) then
            Part(fx, "ToroPost", nil, Vector3.new(0.9, h * 0.6, 0.9), CFrame.new(at + Vector3.new(0, h * 0.3, 0)), STONE, M.Slate)
            Part(fx, "ToroRoof", nil, Vector3.new(2.2, 0.5, 2.2), CFrame.new(at + Vector3.new(0, h * 0.8, 0)), STONE2, M.Slate)
            n += 2
        end
        local win = Part(fx, "ToroLight", nil, Vector3.new(0.7, h * 0.12, 0.7), CFrame.new(at + Vector3.new(0, h * 0.62, 0)), WARM, M.Neon)
        win.Transparency = 0.25; win.CastShadow = false
        win:SetAttribute("KeepNeon", true)
        n += 1
        if Lava then Lava.Glow(fx, at + Vector3.new(0, h * 0.62, 0), 6, WARM, 0.45, { Name = "ToroGlow", MaxDistance = 400 }) end
    end
    -- LANTERN WALK: raked gravel strips along the band, stone lanterns behind them, petal carpets, one warm light
    local lit = false
    local function Walk(b0: Vector3, b1: Vector3, o: Vector3, lanterns: number)
        local d = Vector3.new(b1.X - b0.X, 0, b1.Z - b0.Z)
        local len, u = d.Magnitude, d.Unit
        local mid = Vector3.new((b0.X + b1.X) / 2, F, (b0.Z + b1.Z) / 2)
        local segs = math.max(1, math.floor(len / 18))
        for k = 1, segs do
            local at = b0:Lerp(b1, (k - 0.5) / segs)
            Kit("Gravel", Vector3.new(at.X, F - 0.15, at.Z), len / segs - 0.4, nil, true, u:Cross(Vector3.yAxis))
            if ctx.Terrain then
                local seg = len / segs
                for t = -0.35, 0.36, 0.35 do local q = at + u * seg * t; Paint(q.X, q.Z, 2.8, M.Slate, vr) end
            end
        end
        for k = 1, lanterns do
            local at = b0:Lerp(b1, (k - 0.5) / lanterns) + o * 2.6
            Lantern(Vector3.new(at.X, F, at.Z), -o, vr:NextNumber(5, 6))
            Drift(Vector3.new(at.X, F, at.Z) - o * 2.2 + u * vr:NextNumber(-2, 2), vr:NextNumber(4.5, 6))
        end
        if not lit then
            lit = true
            local c = A.Carrier(fx, "WalkLight", Vector3.new(1, 1, 1), CFrame.new(mid + Vector3.new(0, 4, 0) - o * 3))
            local l = Instance.new("PointLight")
            l.Color = C3(255, 200, 140); l.Range = 26; l.Brightness = 0.9; l.Shadows = false
            l.Parent = c
        end
    end
    -- THE FLOOR first (A.PaintField on its own stream): moss / grass / earth / old paving -- 0 parts
    if A.PaintField then
        A.PaintField(P, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.LeafyGrass, 50 }, { M.Grass, 50 } },
            { Scale = 20, Stretch = 1.5, Warp = 10, Edge = 0.3 })
    end
    local isBand = {}
    for wi, sd in ipairs(P.walls) do
        local b0, b1 = P.Band(sd, 4, 18)
        if b0 then
            isBand[sd] = true
            Walk(b0, b1, P.SIDES[sd], wi == 1 and 3 or 2)
        end
    end
    -- GRAVEL WALKS: from each door a narrow raked walk curving in toward the room's heart (3 kit strips, yaw drifting)
    for _, dp in ipairs(P.doors) do
        local at = Vector3.new(dp.X, F, dp.Z)
        local dir = Vector3.new(C0.X - at.X, 0, C0.Z - at.Z)
        if dir.Magnitude > 8 then
            dir = dir.Unit
            at += dir * 7
            local turn = math.rad(vr:NextNumber(-14, 14))
            for _ = 1, 3 do
                dir = (CFrame.Angles(0, turn, 0) * dir).Unit
                local mid = at + dir * 6
                Kit("Gravel", Vector3.new(mid.X, F - 0.15, mid.Z), 12, nil, true, dir:Cross(Vector3.yAxis)) -- (sunk: only the kerbs stand proud)
                if ctx.Terrain then -- the walk's bed: grey stone voxels between the kerbs (the gravel slab sits under the ground)
                    for _, t in ipairs({ -3, 3 }) do local q = mid + dir * t; Paint(q.X, q.Z, 2.6, M.Slate, vr) end
                end
                at += dir * 11.6
                if (Vector3.new(at.X - C0.X, 0, at.Z - C0.Z)).Magnitude < 14 then break end
            end
        end
    end
    -- THE OPEN FLOOR: a curve of stepping stones, petal carpets (low, no collision)
    for _ = 1, 1 do
        local p = P.Spot(18)
        if not P.DoorNear(p, 12) then
            local ang = vr:NextNumber(0, math.pi * 2)
            if not Kit("Stepping", p, vr:NextNumber(11, 14), nil, true, Vector3.new(math.cos(ang), 0, math.sin(ang))) then
                Part(fx, "SteppingStone", Enum.PartType.Cylinder, Vector3.new(0.3, 3, 3), CFrame.new(p + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), STONE, M.Slate).CastShadow = false
                n += 1
            end
        end
    end
    for _ = 1, vr:NextInteger(3, 4) do
        local p = P.Spot(9)
        if not P.DoorNear(p, 10) then Drift(p, vr:NextNumber(5, 8)) end
    end
    -- EDGE: THE BLOSSOM. Cherry trees at the wall feet of every wall (two where the wall is long and clear), more on the
    -- rim, all leaning in, canopies over the room edge above head height; a petal carpet under each; then the torii
    local T = workspace.Terrain
    local function RimTop(x: number, z: number): number?
        if not ctx.Terrain then return nil end
        local gx, gz = math.floor(x / 4) * 4, math.floor(z / 4) * 4
        local _, occ = T:ReadVoxels(Region3.new(Vector3.new(gx, 0, gz), Vector3.new(gx + 4, 60, gz + 4)), 4)
        for j = occ.Size.Y, 1, -1 do
            local v = occ[1][j][1]
            if v > 0.3 then return (j - 1) * 4 + v * 4 end
        end
        return nil
    end
    local function Tree(base: Vector3, o: Vector3, h: number, falls: boolean)
        local lean = math.rad(vr:NextNumber(8, 15))
        local axis = (Vector3.yAxis * math.cos(lean) - o * math.sin(lean)).Unit
        if not Kit("CherryTree", base - Vector3.new(0, 0.4, 0), h, axis) then
            Part(fx, "CherryTrunk", Enum.PartType.Cylinder, Vector3.new(10, 1.6, 1.6), CFrame.fromMatrix(base + Vector3.new(0, 5, 0), axis, o), WOOD, M.Wood)
            n += 1
        end
        if falls then
            Emitter(fx, "BlossomFall", CFrame.new(base + Vector3.new(0, h * 0.75, 0) - o * 4), Vector3.new(12, 2, 12), {
                Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(PETAL, PETAL2), LightEmission = 0.2, LightInfluence = 0.8,
                Rate = 3, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0.5, 1.2), Acceleration = Vector3.new(0, -0.9, 0), RotSpeed = NumberRange.new(-120, 120),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32), NumberSequenceKeypoint.new(1, 0.24) }) })
        end
    end
    local trees, falls, torii = 0, 0, nil
    for _, sd in ipairs(P.order) do
        local o, al = P.SIDES[sd], P.Along(sd)
        local spots = isBand[sd] and { vr:NextNumber(-0.75, -0.6), vr:NextNumber(0.6, 0.75) } or { vr:NextNumber(-0.55, -0.3), vr:NextNumber(0.3, 0.55) }
        for _, f in ipairs(spots) do
            if trees >= 6 then break end
            local at = C0 + o * (half - (isBand[sd] and 1.5 or 3)) + al * f * half
            if not P.DoorNear(at, 16) then
                trees += 1
                falls += 1
                Tree(Vector3.new(at.X, F, at.Z), o, vr:NextNumber(20, 25), falls <= 3)
                Drift(Vector3.new(at.X, F, at.Z) - o * 5, vr:NextNumber(8, 11))
            elseif not torii and not isBand[sd] then
                torii = { sd = sd, f = f }
            end
        end
    end
    local rims = 0
    for _, sd in ipairs(P.order) do -- more on the rim: their canopies hang over the edge from above
        if rims >= 3 then break end
        local o, al = P.SIDES[sd], P.Along(sd)
        local at = C0 + o * (half + 7) + al * vr:NextNumber(-0.2, 0.2) * half
        local top = RimTop(at.X, at.Z)
        if top and top > F + 3 and top < F + 34 and not P.DoorNear(C0 + o * half + al * (at - C0):Dot(al), 20) then
            rims += 1
            Tree(Vector3.new(at.X, top, at.Z), o, vr:NextNumber(22, 26), false)
        end
    end
    do -- the torii against a wall facing in (a clear spot no tree took)
        local sd = torii and torii.sd
        if not sd then for _, s2 in ipairs(P.order) do if not isBand[s2] then sd = s2 break end end end
        if sd then
            local o, al = P.SIDES[sd], P.Along(sd)
            local base = Vector3.new(C0.X, F - 0.3, C0.Z) + o * (half - 1.5)
            if not P.DoorNear(base, 14) and not Kit("Torii", base, vr:NextNumber(17, 20), nil, nil, -o, true) then
                local cf = CFrame.lookAt(base, base - o)
                for sx = -1, 1, 2 do Part(fx, "ToriiPillar", nil, Vector3.new(1.4, 17, 1.4), cf * CFrame.new(sx * 6, 8.5, 0), VERMILION, M.SmoothPlastic) end
                Part(fx, "ToriiBeam", nil, Vector3.new(16, 1.2, 1.4), cf * CFrame.new(0, 17.4, 0), C3(30, 26, 26), M.SmoothPlastic)
                n += 3
            end
        end
    end
    -- SET PIECE: the fallen temple bell beside its broken frame, petals drifted round it, a lantern still burning
    do
        local sd, spot = P.SetSpot(26, 9, isBand)
        if sd and spot then
            local o, al = P.SIDES[sd], P.Along(sd)
            local at = Vector3.new(spot.X, F, spot.Z) + o * 1
            local side = (vr:NextNumber() < 0.5) and -1 or 1
            -- (the kit's bell lies along its own X: face its side along -(fwd x up) so the bell lies along the wall)
            local fwd = (al * side + o * vr:NextNumber(-0.3, 0.3)).Unit
            if not Kit("TempleBell", at - Vector3.new(0, 0.5, 0), vr:NextNumber(12.5, 14), nil, nil, fwd:Cross(Vector3.yAxis)) then
                local bcf = CFrame.fromMatrix(at + Vector3.new(0, 3.2, 0), fwd, Vector3.yAxis)
                Part(fx, "BellBody", Enum.PartType.Cylinder, Vector3.new(8, 7.6, 7.6), bcf, C3(112, 84, 52), M.Metal)
                n += 1
            end
            Drift(at - o * 5 + al * side * 3, 9)
            Drift(at + al * side * 9, 7)
            Lantern(at - o * 7 - al * side * 7, -o, 5.5)
            Lantern(at - o * 7 + al * side * 9, -o, 5.5)
            local c = A.Carrier(fx, "BellLight", Vector3.new(1, 1, 1), CFrame.new(at - o * 7 + Vector3.new(0, 4, 0)))
            local l = Instance.new("PointLight")
            l.Color = C3(255, 196, 130); l.Range = 22; l.Brightness = 1; l.Shadows = false
            l.Parent = c
        end
    end
    -- DRIFT: petals blown across the room
    Emitter(fx, "PetalWind", CFrame.new(C0 + Vector3.new(0, 4, 0)), Vector3.new(half * 1.6, 6, half * 1.6), {
        Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(PETAL, PETAL2), LightEmission = 0.1, LightInfluence = 0.9,
        Rate = 9, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(4, 7), SpreadAngle = Vector2.new(20, 10),
        EmissionDirection = Enum.NormalId.Front, Acceleration = Vector3.new(0, -0.7, 0), RotSpeed = NumberRange.new(-200, 200),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.22) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) }) })
    return n
end

return B
