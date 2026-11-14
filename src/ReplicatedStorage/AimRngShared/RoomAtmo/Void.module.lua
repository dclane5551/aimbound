--!strict
-- ROOM ATMOSPHERE PASS 2 -- VOID (the Void biome; RoomAtmo API: see RoomAtmo "ATMOSPHERE PASS 2"). Its own treatment (reference
-- row: Twisted Domain, Simulacrum, Crux of Nothingness -- "near-black ground, violet shard clusters, mist, broken floating
-- debris"):
--   CONTRAST  Light: ambient x0.6 (the biome is lit by its ambient, its sun is already low), sun x0.6, violet grade; palette
--             x0.55, parts x0.6. Near-black ground, the violet carries the light.
--   GROUND    RIFTS at the wall foot: a black tear in the floor with a violet Neon rim on both edges, violet light pooling out
--             of it, motes rising, one violet PointLight. Violet VEINS branch out over the floor (Neon beams), dark glass
--             fields (terrain glacier), black obsidian shards, small crystal clusters (< 0.6 stud, a few up to the knee at the
--             walls only).
--   EDGE      the biome's floating ruins already hang over the rim (pass 1), so only a crystal spire on a corner
--   SET PIECE a SHATTERED MONOLITH at a wall: the lower half standing, the upper pieces hanging apart in the air above it with
--             a violet core glowing in the gap (one light)
--   DRIFT     violet mist low over the floor + motes rising
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.6, Ambient = 0.6, Outdoor = 0.6, Tint = C3(225, 205, 255), TintAmt = 0.35 }
B.Palette = { Dim = 0.55, Mats = { [M.Glacier] = 0.5 }, Base = { [M.Rock] = C3(88, 80, 112) } } -- Rock (the rim boulders) is not in the
-- biome palette: without a Base entry it kept the default pale grey and lit up lavender against the dark floor
B.PartDim = 0.6

local BLACK, STONE = C3(12, 10, 18), C3(46, 40, 60)
local VIOLET, VIOLET_DK = C3(190, 110, 255), C3(110, 60, 190)

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Part, Paint, Emitter, Shard = A.Part, A.Paint, A.Emitter, A.Shard
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    -- FLOOR FIELD (terrain paint, 0 parts): the whole open floor in big irregular blobs / drifts of the biome's ground
    -- materials (A.PaintField; its own Random so the room's other draws -- the layout -- stay where they were). The big
    -- round field blobs below only draw their numbers when the field ran.
    local field = A.PaintField(P, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.Basalt, 40 }, { M.Slate, 35 }, { M.Asphalt, 25 } }, { Scale = 22, Stretch = 2 }) > 0
    local function FieldPaint(x: number, z: number, r: number, mat: Enum.Material, rr: Random)
        if field then rr:NextNumber(0, math.pi * 2) else Paint(x, z, r, mat, rr) end
    end
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    local lit = false
    local function Rift(b0: Vector3, b1: Vector3, w: number, o: Vector3)
        local d = Vector3.new(b1.X - b0.X, 0, b1.Z - b0.Z)
        local len, u = d.Magnitude, d.Unit
        local mid = Vector3.new((b0.X + b1.X) / 2, F, (b0.Z + b1.Z) / 2)
        local cf = CFrame.lookAt(mid, mid + u)
        local tear = Part(fx, "Rift", nil, Vector3.new(w, 0.12, len), cf * CFrame.new(0, 0.06, 0), C3(34, 16, 58), M.SmoothPlastic)
        tear.CastShadow = false
        for side = -1, 1, 2 do
            local rim = Part(fx, "RiftRim", nil, Vector3.new(0.6, 0.1, len - 1), cf * CFrame.new(side * (w / 2), 0.14, 0) * CFrame.Angles(0, math.rad(side * vr:NextNumber(0.5, 1.5)), 0), VIOLET, M.Neon)
            rim.Transparency = 0.05; rim.CastShadow = false
        end
        n += 3
        if Lava then
            for g = 1, math.max(1, math.floor(len / 24)) do
                Lava.Glow(fx, b0:Lerp(b1, (g - 0.5) / math.max(1, math.floor(len / 24))) + Vector3.new(0, F + 1 - b0.Y, 0), 30, VIOLET, 0.4, { Name = "RiftGlow", MaxDistance = 400 })
            end
        end
        Emitter(fx, "RiftMotes", CFrame.lookAt(mid + Vector3.new(0, 0.3, 0), mid + Vector3.new(0, 0.3, 0) + u), Vector3.new(w, 0.2, len), {
            Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(VIOLET, C3(240, 200, 255)), LightEmission = 1, LightInfluence = 0,
            Rate = math.clamp(len / 10, 3, 7), Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(1.5, 3), EmissionDirection = Enum.NormalId.Top,
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }) })
        if not lit then
            lit = true
            local c = A.Carrier(fx, "RiftLight", Vector3.new(1, 1, 1), CFrame.new(mid + Vector3.new(0, 2, 0)))
            local l = Instance.new("PointLight")
            l.Color = C3(180, 110, 255); l.Range = 28; l.Brightness = 1; l.Shadows = false
            l.Parent = c
            n += 1
        end
        -- veins out of it
        local al = Vector3.new(-o.Z, 0, o.X)
        for _ = 1, vr:NextInteger(2, 3) do
            local s = b0:Lerp(b1, vr:NextNumber(0.1, 0.9)) - o * (w / 2 + 0.4)
            n += A.Cracks(fx, P, ctx, vr, s, -o + al * vr:NextNumber(-0.6, 0.6), vr:NextNumber(0.8, 1.1),
                { Neon = true, Hot = C3(215, 160, 255), Dark = VIOLET_DK, HotT = 0.2, DarkT = 0.55, HotShare = 0.12, Wall = o, Reach = 44, Limit = 8, Y = 0.1 })
        end
    end
    local isBand = {}
    for wi, sd in ipairs(P.walls) do
        local b0, b1 = P.Band(sd, 4, 18)
        if b0 then
            isBand[sd] = true
            Rift(b0, b1, wi == 1 and 3.2 or 2.6, P.SIDES[sd])
        end
    end
    -- THE OPEN FLOOR: dark glass fields, black obsidian shards, small crystal clusters at the walls
    if ctx.Terrain then
        for _ = 1, vr:NextInteger(5, 7) do
            local p = P.Spot(12)
            FieldPaint(p.X, p.Z, vr:NextNumber(9, 16), ({ M.Glacier, M.Basalt, M.Slate, M.Asphalt })[vr:NextInteger(1, 4)], vr)
        end
    end
    for _ = 1, vr:NextInteger(4, 5) do
        local p = P.Spot(8)
        if not P.DoorNear(p, 10) then
            for _, s in ipairs(Shard(fx, "ObsidianShard", p, vr:NextNumber(2.5, 4), 0.15, BLACK, M.SmoothPlastic, vr)) do s.Reflectance = 0.15 end
            n += 3
        end
    end
    if ctx.EnvKit and ctx.EnvKit.Has("Void", "VoidCrystalsA") then
        for _ = 1, 2 do
            local sd = P.order[vr:NextInteger(1, 4)]
            local at = C0 + P.SIDES[sd] * (half - 3) + P.Along(sd) * vr:NextNumber(-0.6, 0.6) * half
            if not P.DoorNear(at, 16) then
                local sz = ctx.EnvKit.Size("Void", "VoidCrystalsA")
                local k = sz and math.clamp(3 / math.max(sz.Y, 0.1), 0.2, 4) or 1
                ctx.EnvKit.Place("Void", "VoidCrystalsA", CFrame.new(at) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0), { Scale = k, Parent = fx, Hitbox = false, Name = "CrystalCluster" })
                n += 1
            end
        end
    end
    -- EDGE: the biome's own floating ruins already hang over the rim (pass 1): a crystal spire on a corner
    if ctx.EnvKit and ctx.EnvKit.Has("Void", "VoidSpire") then
        local o, o2 = P.SIDES[P.order[2]], P.SIDES[(P.order[2] <= 2) and 4 or 2]
        local corner = C0 + o * (half + 6) + o2 * (half + 6)
        local sz = ctx.EnvKit.Size("Void", "VoidSpire")
        local k = sz and math.clamp(30 / math.max(sz.Y, 0.1), 0.3, 8) or 3
        ctx.EnvKit.Place("Void", "VoidSpire", CFrame.new(corner - Vector3.new(0, 3, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0), { Scale = k, Parent = fx, Hitbox = false, Name = "VoidSpire" })
        n += 1
    end
    -- SET PIECE: a shattered monolith, the upper pieces hanging apart over the lower half, a violet core in the gap
    do
        local sd, spot = P.SetSpot(24, 5, isBand)
        if sd and spot then
            local o = P.SIDES[sd]
            local base = Vector3.new(spot.X, F, spot.Z) + o * 2
            local face = CFrame.lookAt(base, base - o)
            local W, D = 12, 6
            Part(fx, "MonolithBase", nil, Vector3.new(W, 18, D), face * CFrame.new(0, 9, 0) * CFrame.Angles(0, 0, math.rad(vr:NextNumber(-3, 3))), STONE, M.Slate)
            local core = Part(fx, "MonolithCore", Enum.PartType.Ball, Vector3.new(5, 5, 5), face * CFrame.new(0, 22, 0), VIOLET, M.Neon)
            core.CastShadow = false
            for k = 1, 3 do
                local piece = Part(fx, "FloatingMonolith", nil, Vector3.new(W * vr:NextNumber(0.6, 0.95), vr:NextNumber(4, 6), D),
                    face * CFrame.new(vr:NextNumber(-1.5, 1.5), 23 + k * 6.5, vr:NextNumber(-1, 1)) * CFrame.Angles(vr:NextNumber(-0.25, 0.25), vr:NextNumber(-0.4, 0.4), vr:NextNumber(-0.3, 0.3)), STONE, M.Slate)
                local _ = piece
            end
            if Lava then Lava.Glow(fx, (face * CFrame.new(0, 22, 0)).Position, 20, VIOLET, 0.35, { Name = "CoreGlow", MaxDistance = 600 }) end
            local c = A.Carrier(fx, "CoreLight", Vector3.new(1, 1, 1), face * CFrame.new(0, 22, -3))
            local l = Instance.new("PointLight")
            l.Color = C3(190, 120, 255); l.Range = 26; l.Brightness = 1.1; l.Shadows = false
            l.Parent = c
            n += 5
        end
    end
    -- DRIFT: violet mist low over the floor
    Emitter(fx, "VoidMist", CFrame.new(C0 + Vector3.new(0, 0.8, 0)), Vector3.new(half * 1.7, 0.3, half * 1.7), {
        Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(120, 80, 170)), LightInfluence = 0.6, LightEmission = 0.2,
        Rate = 4, Lifetime = NumberRange.new(9, 14), Speed = NumberRange.new(0.5, 1.2), SpreadAngle = Vector2.new(80, 5), EmissionDirection = Enum.NormalId.Front,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 14) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.85), NumberSequenceKeypoint.new(1, 1) }) })
    return n
end

return B
