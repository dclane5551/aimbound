--!strict
-- ROOM ATMOSPHERE PASS 2 -- AZTEC (Sun Empire world; RoomAtmo API: see RoomAtmo "ATMOSPHERE PASS 2"). Its own treatment
-- (reference row: Vaal City, Phaaryl Megaliths, Vaults of Kamasa -- "carved stone plazas, overgrown megaliths, gold glints").
-- A sunlit world, so not "dark": a lower, warmer late sun with real shadow, the jungle green deeper, and the gold catching it.
--   CONTRAST  Light: sun x0.65, ambient x0.88 (gear plate kept near the other biomes), the grade warmer; palette x0.68
--             (grass x0.6), parts x0.8.
--   GROUND    TEMPLE CANALS at the wall foot: a carved limestone gutter with turquoise water in it, a stepped coping on the wall
--             side with a gold-inlaid band, glints on the water, one warm PointLight. The open floor: carved PAVING (terrain
--             cobblestone + limestone + sandstone fields with flush paving shards), moss / grass creeping between them, roots, fallen glyph
--             fragments, a few gold glints in the paving (< 0.6 stud).
--   EDGE      two OVERGROWN MEGALITHS standing in the rim: two stacked offset blocks, a wedge cap, moss on top, vines
--   SET PIECE a COLOSSAL SUN STONE (the world's sun-disc model, ~32 tall) fallen and leaning against a wall, moss on it, gold
--             glinting, a warm light at its foot
--   DRIFT     pollen / dust motes drifting in the sun
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.65, Ambient = 0.88, Outdoor = 0.85, Tint = C3(255, 232, 196), TintAmt = 0.4 }
B.Palette = { Dim = 0.68, Mats = { [M.Grass] = Color3.new(0.52, 0.46, 0.4), [M.LeafyGrass] = 0.6 }, -- (grass: dulled olive, it read as lawn green)
    Base = { [M.Pavement] = C3(150, 136, 110), [M.Mud] = C3(96, 80, 60), [M.Cobblestone] = C3(140, 124, 98) } } -- (the floor field's materials the world palette lacks)
B.PartDim = 0.8

local STONE, STONE_DK, GOLD = C3(150, 128, 96), C3(104, 90, 70), C3(230, 180, 70)
local MEG, MEG_DK = C3(122, 116, 96), C3(96, 92, 76)
local WATER, MOSS, VINE = C3(40, 140, 130), C3(70, 110, 56), C3(56, 96, 46)

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Part, Paint, Emitter, Shard = A.Part, A.Paint, A.Emitter, A.Shard
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    -- FLOOR FIELD (terrain paint, 0 parts): the whole open floor in big irregular blobs / drifts of the biome's ground
    -- materials (A.PaintField; its own Random so the room's other draws -- the layout -- stay where they were). The big
    -- round field blobs below only draw their numbers when the field ran.
    local field = A.PaintField(P, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.Limestone, 30 }, { M.Cobblestone, 22 }, { M.Pavement, 18 }, { M.Mud, 18 }, { M.Grass, 12 } }, { Scale = 20, Stretch = 1.6 }) > 0
    local function FieldPaint(x: number, z: number, r: number, mat: Enum.Material, rr: Random)
        if field then rr:NextNumber(0, math.pi * 2) else Paint(x, z, r, mat, rr) end
    end
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    local lit = false
    -- TEMPLE CANAL: a carved gutter with turquoise water, stepped coping + gold band on the wall side
    local function Canal(b0: Vector3, b1: Vector3, w: number, o: Vector3)
        local d = Vector3.new(b1.X - b0.X, 0, b1.Z - b0.Z)
        local len, u = d.Magnitude, d.Unit
        local mid = Vector3.new((b0.X + b1.X) / 2, F, (b0.Z + b1.Z) / 2)
        local cf = CFrame.lookAt(mid, mid + u)
        local water = Part(fx, "CanalWater", nil, Vector3.new(w, 0.15, len), cf * CFrame.new(0, 0.1, 0), WATER, M.SmoothPlastic)
        water.Transparency = 0.15; water.Reflectance = 0.25; water.CastShadow = false
        -- room-side lip: a low carved kerb; wall side: two coping steps + a gold band on the upper one
        local side = cf:VectorToObjectSpace(o).X > 0 and 1 or -1
        Part(fx, "CanalLip", nil, Vector3.new(1, 0.45, len), cf * CFrame.new(-side * (w / 2 + 0.5), 0.2, 0), STONE, M.Limestone)
        Part(fx, "CanalStep", nil, Vector3.new(2.4, 1.4, len), cf * CFrame.new(side * (w / 2 + 1.2), 0.7, 0), STONE_DK, M.Limestone)
        Part(fx, "CanalStep", nil, Vector3.new(2, 2.8, len - 2), cf * CFrame.new(side * (w / 2 + 3.2), 1.4, 0), STONE, M.Limestone)
        local band = Part(fx, "GoldBand", nil, Vector3.new(0.15, 0.45, len - 3), cf * CFrame.new(side * (w / 2 + 2.15), 2.2, 0), GOLD, M.Metal)
        band.Reflectance = 0.35
        n += 5
        if Lava then
            for g = 1, math.max(1, math.floor(len / 28)) do
                Lava.Glow(fx, b0:Lerp(b1, (g - 0.5) / math.max(1, math.floor(len / 28))) + Vector3.new(0, F + 0.6 - b0.Y, 0), 14, C3(90, 230, 210), 0.55, { Name = "CanalGlow", MaxDistance = 300 })
            end
        end
        Emitter(fx, "CanalGlints", CFrame.lookAt(mid + Vector3.new(0, 0.4, 0), mid + Vector3.new(0, 0.4, 0) + u), Vector3.new(w, 0.2, len), {
            Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C3(255, 250, 220)), LightEmission = 1, LightInfluence = 0,
            Rate = math.clamp(len / 14, 2, 5), Lifetime = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(0, 0.2),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 0) }) })
        if not lit then
            lit = true
            local c = A.Carrier(fx, "CanalLight", Vector3.new(1, 1, 1), CFrame.new(mid + Vector3.new(0, 2, 0)))
            local l = Instance.new("PointLight")
            l.Color = C3(255, 220, 160); l.Range = 26; l.Brightness = 0.8; l.Shadows = false
            l.Parent = c
            n += 1
        end
    end
    local isBand = {}
    for wi, sd in ipairs(P.walls) do
        local b0, b1 = P.Band(sd, 4.5, 18)
        if b0 then
            isBand[sd] = true
            Canal(b0, b1, wi == 1 and 4.4 or 3.6, P.SIDES[sd])
        end
    end
    -- THE OPEN FLOOR: carved paving fields, moss between, roots, glyph fragments, gold glints
    if ctx.Terrain then
        for _ = 1, vr:NextInteger(5, 7) do
            local p = P.Spot(12)
            FieldPaint(p.X, p.Z, vr:NextNumber(8, 14), ({ M.Cobblestone, M.Cobblestone, M.Limestone, M.Sandstone })[vr:NextInteger(1, 4)], vr)
        end
    end
    for _ = 1, vr:NextInteger(3, 4) do
        local p = P.Spot(8)
        if not P.DoorNear(p, 10) then
            Shard(fx, "PavingShard", p, vr:NextNumber(2.5, 4), 0.25, STONE, M.Limestone, vr)
            if ctx.Terrain then Paint(p.X + vr:NextNumber(-3, 3), p.Z + vr:NextNumber(-3, 3), vr:NextNumber(2.5, 4), M.LeafyGrass, vr) end
            n += 3
        end
    end
    for _ = 1, vr:NextInteger(3, 4) do
        local p = P.Spot(8)
        if not P.DoorNear(p, 10) then
            local L = vr:NextNumber(5, 9)
            local root = Part(fx, "Root", Enum.PartType.Cylinder, Vector3.new(L, vr:NextNumber(0.4, 0.6), vr:NextNumber(0.4, 0.6)),
                CFrame.new(p + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0), C3(84, 70, 52), M.Wood)
            root.CastShadow = false
            n += 1
        end
    end
    for _ = 1, vr:NextInteger(2, 3) do
        local p = P.Spot(10)
        if not P.DoorNear(p, 10) then
            local g = Part(fx, "GlyphFragment", Enum.PartType.Wedge, Vector3.new(vr:NextNumber(1.6, 2.6), 0.55, vr:NextNumber(1.6, 2.6)),
                CFrame.new(p + Vector3.new(0, 0.2, 0)) * CFrame.Angles(math.rad(vr:NextNumber(-6, 6)), vr:NextNumber(0, 6.28), 0), STONE_DK, M.Limestone)
            g.CastShadow = false
            local glint = Part(fx, "GoldGlint", Enum.PartType.Ball, Vector3.new(0.35, 0.35, 0.35), CFrame.new(p + Vector3.new(vr:NextNumber(-0.5, 0.5), 0.55, vr:NextNumber(-0.5, 0.5))), GOLD, M.Neon)
            glint.CastShadow = false
            n += 2
        end
    end
    -- EDGE: overgrown megaliths standing in the rim, leaning, vines down their faces
    local stones = 0
    for _, sd in ipairs(P.order) do
        if stones >= 2 then break end
        local o = P.SIDES[sd]
        local al = P.Along(sd)
        local at = C0 + o * (half + 4) + al * vr:NextNumber(-0.6, 0.6) * half
        if not P.DoorNear(at, 22) then
            stones += 1
            local h = vr:NextNumber(22, 30)
            local base = Vector3.new(at.X, F + h / 2 - 2, at.Z)
            local cf = CFrame.lookAt(base, base - o) * CFrame.Angles(math.rad(-vr:NextNumber(4, 10)), 0, math.rad(vr:NextNumber(-6, 6)))
            -- two stacked blocks offset + tilted (a broken, weathered silhouette, never one clean slab), a tapered cap, moss on
            -- top and uneven vine clumps hanging down the face
            local W, D = vr:NextNumber(6, 8), vr:NextNumber(3.5, 5)
            local lo = cf * CFrame.new(0, -h * 0.2, 0)
            Part(fx, "Megalith", nil, Vector3.new(W, h * 0.6, D), lo, MEG, M.Rock)
            local up = lo * CFrame.new(vr:NextNumber(-0.8, 0.8), h * 0.5, vr:NextNumber(-0.3, 0.3)) * CFrame.Angles(math.rad(vr:NextNumber(-4, 4)), math.rad(vr:NextNumber(-8, 8)), math.rad(vr:NextNumber(-5, 5)))
            Part(fx, "Megalith", nil, Vector3.new(W * 0.78, h * 0.42, D * 0.85), up, MEG_DK, M.Rock)
            local top = up * CFrame.new(0, h * 0.21 + 1.1, 0)
            Part(fx, "MegalithCap", Enum.PartType.Wedge, Vector3.new(W * 0.7, 2.2, D * 0.8), top * CFrame.Angles(0, vr:NextInteger(0, 1) * math.pi, 0), MEG, M.Rock)
            local moss = Part(fx, "MegalithMoss", nil, Vector3.new(W * 0.82, 0.5, D * 0.95), up * CFrame.new(0, h * 0.21 + 0.1, 0), MOSS, M.LeafyGrass)
            moss.CastShadow = false
            for _ = 1, 3 do
                local vl = vr:NextNumber(h * 0.25, h * 0.6)
                local x = vr:NextNumber(-W * 0.32, W * 0.32)
                local vine = Part(fx, "Vine", nil, Vector3.new(vr:NextNumber(0.8, 1.7), vl, 0.45), up * CFrame.new(x, h * 0.21 - vl / 2, -D * 0.43 - 0.2)
                    * CFrame.Angles(0, 0, math.rad(vr:NextNumber(-6, 6))), VINE, M.LeafyGrass)
                vine.CastShadow = false
            end
            n += 7
        end
    end
    -- SET PIECE: a colossal sun stone fallen against a wall
    do
        local sd, spot = P.SetSpot(26, 6, isBand)
        if sd and spot then
            local o = P.SIDES[sd]
            local tm = A.WorldProp("Aztec", "SunStone")
            local face = CFrame.lookAt(Vector3.new(spot.X, F, spot.Z) + o * 3, Vector3.new(spot.X, F, spot.Z) - o * 10)
            if tm then
                local m = A.PlaceModel(tm, fx, face * CFrame.Angles(math.rad(-20), 0, math.rad(vr:NextNumber(-8, 8))), 32, "FallenSunStone")
                local _ = m
            else
                local disc = Part(fx, "FallenSunStone", Enum.PartType.Cylinder, Vector3.new(3, 22, 22), face * CFrame.new(0, 11, 0) * CFrame.Angles(math.rad(-14), math.rad(90), 0), STONE, M.Limestone)
                local _ = disc
            end
            -- moss creeping up its foot, gold glints, a warm light
            if ctx.Terrain then Paint(spot.X, spot.Z, 8, M.LeafyGrass, vr) end
            Emitter(fx, "SunStoneGlints", face * CFrame.new(0, 11, -2), Vector3.new(16, 16, 1), {
                Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C3(255, 220, 120)), LightEmission = 1, LightInfluence = 0,
                Rate = 4, Lifetime = NumberRange.new(0.5, 1.2), Speed = NumberRange.new(0, 0.3),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.5), NumberSequenceKeypoint.new(1, 0) }) })
            local c = A.Carrier(fx, "SunStoneLight", Vector3.new(1, 1, 1), face * CFrame.new(0, 3, -6))
            local l = Instance.new("PointLight")
            l.Color = C3(255, 200, 120); l.Range = 24; l.Brightness = 0.9; l.Shadows = false
            l.Parent = c
            n += 3
        end
    end
    -- DRIFT: pollen / dust motes in the sun
    Emitter(fx, "Pollen", CFrame.new(C0 + Vector3.new(0, 4, 0)), Vector3.new(half * 1.6, 4, half * 1.6), {
        Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C3(255, 236, 170), C3(220, 255, 170)), LightEmission = 0.6, LightInfluence = 0.4,
        Rate = 8, Lifetime = NumberRange.new(6, 10), Speed = NumberRange.new(0.3, 0.8), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0.3, 0.05, 0),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.16), NumberSequenceKeypoint.new(1, 0) }) })
    return n
end

return B
