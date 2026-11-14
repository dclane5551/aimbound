--!strict
-- ROOM ATMOSPHERE PASS 2 -- AUTUMN (the Autumn Highlands; RoomAtmo API: see RoomAtmo "ATMOSPHERE PASS 2"). Its own treatment
-- (reference: a golden afternoon in old woodland, leaf litter in reds and ambers, a dry-stone wall, mossy stones). Real meshes:
-- ReplicatedStorage.RoomAtmoKit.Autumn (tools/atmo_kit_autumn.py: broad maples with red / amber leaf crowns, leaf drifts, a
-- dry-stone wall run, a tipped harvest cart spilling pumpkins, a scarecrow, toadstool rings) + the world's own
-- WorldProps.Autumn Hay / FenceRow; without them the plain part pieces stand in.
--   CONTRAST  Light: the low sun x0.8, ambient x0.95, a warm amber grade; palette x0.76 (grass darker x0.66), parts x0.76,
--             scanned props x0.6. Long warm light, the leaves the brightest colour, dark mossy ground under them.
--   GROUND    a chest-high DRY-STONE WALL along the wall foot (kit runs, a gap here and there), leaf drifts banked against it,
--             the world's hay bales, toadstools, one lantern on a post (1 warm light). The open floor: A.PaintField grass /
--             leaf litter / earth / mud recoloured to autumn (palette), a toadstool ring -- all low, no collision. Leaves only lie
--             banked against things (walls, trunks, the cart), never as loose discs on the open floor.
--   EDGE      MAPLES at the wall feet round the room leaning in, crowns blazing red and amber over the edge, leaves falling,
--             a leaf carpet under each; the world's broken fence against another wall
--   SET PIECE a HARVEST CART tipped at a wall foot on its broken wheel, pumpkins spilled across the floor, a scarecrow
--             leaning beside it, a lantern still lit (1 warm light)
--   DRIFT     leaves falling + blowing across the room
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.8, Ambient = 0.95, Outdoor = 0.9, Tint = C3(255, 220, 176), TintAmt = 0.32 }
B.Palette = { Dim = 0.76, Mats = { [M.Grass] = C3(150, 140, 110), [M.LeafyGrass] = C3(214, 140, 104), [M.Ground] = C3(196, 160, 132) },
    Base = { [M.Mud] = C3(92, 70, 52) } }
-- (v2, coordinator: "the floor is still plain green-olive": Mats Color3 = a channel multiplier on the world's terrain colours --
-- grass 150,140,72 -> ~88,77,31 dry grass, leafy grass 140,120,60 -> ~118,66,24 leaf-litter brown-orange, ground 120,96,66 ->
-- ~92,60,34 earth; mud a floor-only material)
B.PartDim = 0.76
B.SADim = 0.6
B.Drift = { LeafWind = true }

local LEAF, LEAF2, STONE, WOOD, WARM = C3(196, 62, 30), C3(222, 128, 36), C3(132, 126, 112), C3(92, 62, 40), C3(255, 196, 120)
local ROUGH = { Bark = M.Wood, Core = M.Grass, Stone = M.Slate, Moss = M.Grass, Wood = M.Wood, Iron = M.Metal, Stalk = M.Wood, Cloth = M.Fabric, Hay = M.Grass }

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Part, Paint, Emitter = A.Part, A.Paint, A.Emitter
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    local kitRoot = game:GetService("ReplicatedStorage"):FindFirstChild("RoomAtmoKit")
    local KIT = kitRoot and kitRoot:FindFirstChild("Autumn")
    local function Kit(name: string, at: Vector3, size: number, up: Vector3?, byWidth: boolean?, face: Vector3?, world: boolean?): Model?
        local tmpl = world and A.WorldProp("Autumn", name) or (KIT and KIT:FindFirstChild(name))
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
                if name == "LeafDrift" or name == "Toadstools" then q.CastShadow = false end
            end
        end
        return m
    end
    -- a leaf drift BANKED against something: `face` points away from what it is banked against (the kit piles high along
    -- its own +Z = the side opposite `face`); it is long (s) and low, never a loose disc
    local function Drift(at: Vector3, s: number, face: Vector3?)
        if Kit("LeafDrift", at - Vector3.new(0, 0.1, 0), s, nil, true, face or Vector3.new(vr:NextNumber(-1, 1), 0, vr:NextNumber(-1, 1)).Unit) then return end
        local p = Part(fx, "LeafDrift", nil, Vector3.new(s, 0.15, s * 0.7), CFrame.new(at + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0), LEAF, M.Grass)
        p.CastShadow = false
        n += 1
    end
    local function Lantern(at: Vector3, h: number)
        Part(fx, "LanternPost", nil, Vector3.new(0.35, h, 0.35), CFrame.new(at + Vector3.new(0, h / 2, 0)), WOOD, M.Wood)
        local lamp = Part(fx, "Lantern", nil, Vector3.new(0.7, 0.9, 0.7), CFrame.new(at + Vector3.new(0, h + 0.3, 0)), WARM, M.Neon)
        lamp.CastShadow = false
        lamp:SetAttribute("KeepNeon", true)
        n += 2
        if Lava then Lava.Glow(fx, at + Vector3.new(0, h + 0.3, 0), 6, WARM, 0.45, { Name = "LanternGlow", MaxDistance = 400 }) end
        return at + Vector3.new(0, h + 0.3, 0)
    end
    -- DRY-STONE WALL along the band: kit runs end to end with a gap now and then, leaf drifts against them, hay, a lantern
    local lit = false
    local function StoneRow(b0: Vector3, b1: Vector3, o: Vector3)
        local d = Vector3.new(b1.X - b0.X, 0, b1.Z - b0.Z)
        local len, u = d.Magnitude, d.Unit
        local segs = math.max(1, math.floor(len / 15))
        for k = 1, segs do
            if segs < 3 or vr:NextNumber() < 0.82 then
                local at = b0:Lerp(b1, (k - 0.5) / segs) + o * 1.5
                local yaw = math.rad(vr:NextNumber(-4, 4))
                local along = (CFrame.Angles(0, yaw, 0) * u)
                -- (v2: chest height, 3.2-3.6 tall; the kit is 12 x 3.3)
                if not Kit("StoneWall", Vector3.new(at.X, F - 0.2, at.Z), vr:NextNumber(3.2, 3.6), nil, false, along:Cross(Vector3.yAxis)) then
                    Part(fx, "DryWall", nil, Vector3.new(len / segs - 1, 1.6, 1), CFrame.lookAt(Vector3.new(at.X, F + 0.8, at.Z), Vector3.new(at.X, F + 0.8, at.Z) + u), STONE, M.Slate)
                    n += 1
                end
            end
            local q = b0:Lerp(b1, (k - 0.5) / segs + vr:NextNumber(-0.2, 0.2)) - o * vr:NextNumber(0.4, 1)
            Drift(Vector3.new(q.X, F, q.Z), vr:NextNumber(9, 13), -o) -- (banked against the run, toward the room)
        end
        local hq = b0:Lerp(b1, vr:NextNumber(0.25, 0.75)) - o * 2
        Kit("Hay", Vector3.new(hq.X, F, hq.Z), vr:NextNumber(3, 3.8), nil, nil, -o, true)
        local tq = b0:Lerp(b1, vr:NextNumber(0.1, 0.9)) - o * 2.5
        Kit("Toadstools", Vector3.new(tq.X, F, tq.Z), vr:NextNumber(2.4, 3.2), nil, true)
        if not lit then
            lit = true
            local q = b0 - o * 1 + u * 2.5
            local top = Lantern(Vector3.new(q.X, F, q.Z), vr:NextNumber(5, 6))
            local c = A.Carrier(fx, "LanternLight", Vector3.new(1, 1, 1), CFrame.new(top - o * 1.5))
            local l = Instance.new("PointLight")
            l.Color = C3(255, 190, 120); l.Range = 24; l.Brightness = 0.9; l.Shadows = false
            l.Parent = c
        end
    end
    -- THE FLOOR first (A.PaintField on its own stream): grass / leaf litter / earth -- 0 parts
    if A.PaintField then
        A.PaintField(P, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.LeafyGrass, 38 }, { M.Grass, 30 }, { M.Ground, 18 }, { M.Mud, 14 } },
            { Scale = 48, Stretch = 2.0, Warp = 16, Edge = 0.7 })
    end
    local isBand = {}
    for _, sd in ipairs(P.walls) do
        local b0, b1 = P.Band(sd, 4, 18)
        if b0 then
            isBand[sd] = true
            StoneRow(b0, b1, P.SIDES[sd])
        end
    end
    -- THE OPEN FLOOR: a toadstool ring (the leaves lie banked against things, not loose on the open floor)
    do
        local p = P.Spot(16)
        if not P.DoorNear(p, 12) then Kit("Toadstools", p, vr:NextNumber(3, 4), nil, true) end
    end
    -- EDGE: maples at the wall feet round the room (2 a wall where clear, max 5), leaning in, falling leaves on the first 3;
    -- the world's fence against a clear stretch of another wall
    local trees, fence = 0, false
    local away = (P.doors[1] and Vector3.new(C0.X - P.doors[1].X, 0, C0.Z - P.doors[1].Z)) or Vector3.new(0, 0, 1)
    away = (math.abs(away.X) > math.abs(away.Z)) and Vector3.new(math.sign(away.X), 0, 0) or Vector3.new(0, 0, math.sign(away.Z))
    local sides = {}
    for _, sd in ipairs(P.order) do if P.SIDES[sd]:Dot(away) > 0.7 then table.insert(sides, 1, sd) else table.insert(sides, sd) end end
    for _, sd in ipairs(sides) do -- (v2: the wall facing the main door first, so its maples are in the view from the entry)
        local o, al = P.SIDES[sd], P.Along(sd)
        for _, f in ipairs({ vr:NextNumber(-0.65, -0.35), vr:NextNumber(0.35, 0.65) }) do
            if trees >= 5 then break end
            local at = C0 + o * (half - (isBand[sd] and 1.5 or 3)) + al * f * half
            if not P.DoorNear(at, 16) then
                trees += 1
                local lean = math.rad(vr:NextNumber(12, 18))
                local up = (Vector3.yAxis * math.cos(lean) - o * math.sin(lean)).Unit
                local h = vr:NextNumber(25, 30)
                if not Kit("MapleTree", Vector3.new(at.X, F - 0.4, at.Z), h, up) then
                    Part(fx, "MapleTrunk", Enum.PartType.Cylinder, Vector3.new(10, 1.8, 1.8), CFrame.fromMatrix(Vector3.new(at.X, F + 5, at.Z), up, o), WOOD, M.Wood)
                    n += 1
                end
                Drift(Vector3.new(at.X, F, at.Z) - o * 2.5 + al * vr:NextNumber(-2, 2), vr:NextNumber(11, 15), -o) -- (banked at the trunk + wall)
                if trees <= 3 then
                    Emitter(fx, "LeafFall", CFrame.new(Vector3.new(at.X, F + h * 0.75, at.Z) - o * 4), Vector3.new(12, 2, 12), {
                        Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(LEAF, LEAF2), LightEmission = 0.1, LightInfluence = 0.9,
                        Rate = 3, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0.5, 1.2), Acceleration = Vector3.new(0, -1, 0), RotSpeed = NumberRange.new(-150, 150),
                        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.28) }) })
                end
            elseif not fence and not isBand[sd] then
                fence = true
                Kit("FenceRow", Vector3.new(at.X, F, at.Z) + o * 1, vr:NextNumber(3.5, 4.5), nil, nil, -o, true)
            end
        end
    end
    -- SET PIECE: the harvest cart tipped at a wall foot, pumpkins spilled, the scarecrow beside it, a lantern still lit
    do
        local sd, spot = P.SetSpot(26, 10, isBand)
        if sd and spot then
            local o, al = P.SIDES[sd], P.Along(sd)
            local at = Vector3.new(spot.X, F, spot.Z) + o * 1.5
            -- (the kit cart's shafts run along its -X and the pumpkins spill toward its -Y: -Z toward the wall puts them
            -- into the room)
            if not Kit("HarvestCart", at - Vector3.new(0, 0.2, 0), vr:NextNumber(13, 15), nil, true, o) then
                Part(fx, "CartBed", nil, Vector3.new(8, 0.5, 5), CFrame.new(at + Vector3.new(0, 2, 0)) * CFrame.Angles(0.3, 0, 0), WOOD, M.Wood)
                n += 1
            end
            local sq = at + al * vr:NextNumber(7, 9) * ((vr:NextNumber() < 0.5) and -1 or 1) + o * 0.5
            Kit("Scarecrow", Vector3.new(sq.X, F - 0.3, sq.Z), vr:NextNumber(8.5, 10), (Vector3.yAxis * 0.97 + o * 0.24).Unit, nil, -o)
            Drift(at - o * 4 + al * 3, 11, -o) -- (banked against the cart)
            local top = Lantern(at - o * 6 - al * 6, 4.5)
            local c = A.Carrier(fx, "CartLight", Vector3.new(1, 1, 1), CFrame.new(top - o * 1))
            local l = Instance.new("PointLight")
            l.Color = C3(255, 190, 120); l.Range = 22; l.Brightness = 1; l.Shadows = false
            l.Parent = c
        end
    end
    -- DRIFT: leaves blowing across the room
    Emitter(fx, "LeafWind", CFrame.new(C0 + Vector3.new(0, 4, 0)), Vector3.new(half * 1.6, 6, half * 1.6), {
        Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(LEAF, LEAF2), LightEmission = 0.1, LightInfluence = 0.9,
        Rate = 7, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(4, 7), SpreadAngle = Vector2.new(20, 10),
        EmissionDirection = Enum.NormalId.Front, Acceleration = Vector3.new(0, -0.8, 0), RotSpeed = NumberRange.new(-200, 200),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32), NumberSequenceKeypoint.new(1, 0.26) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) }) })
    return n
end

return B
