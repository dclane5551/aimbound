--!strict
-- ROOM ATMOSPHERE PASS 2 -- STORM (Stormspire; RoomAtmo API: see RoomAtmo "ATMOSPHERE PASS 2"). Its own treatment (reference
-- row: Ravine, Riverside, Castaway -- "cliff edges, wet dark stone, a wreck or broken structure, everything leaning one way"):
--   CONTRAST  Light: the grey day's sun x0.5, ambient x0.85, colder grade; palette x0.72 (wet = darker), parts x0.7.
--   GROUND    RUNOFF at the wall foot: a dark glossy rain channel along the wall with a broken stone edge, a pale-blue charge
--             glow over it (the storm's colour), one cold PointLight. The open floor: wet dark fields (terrain), standing
--             puddles (irregular glossy shards), scorch marks with blue-white branching scars where lightning struck
--             (< 0.6 stud).
--   EDGE      wind-bent DEAD TRUNKS on the rim, all leaning the same way (the wind), with a broken wall stub
--   SET PIECE a WRECKED HULL heeled over against a wall: bare curved ribs, broken strakes, keel + bow stem, the mast
--             snapped with its top lying on the ground, a torn sail (one light)
--   DRIFT     a few wind-driven rain streaks across the room, the same way the trunks lean (pass 1 already rains: kept light)
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.5, Ambient = 0.85, Outdoor = 0.85, Tint = C3(210, 225, 255), TintAmt = 0.35 }
B.Palette = { Dim = 0.72, Mats = { [M.Mud] = 0.4 }, Base = { [M.Limestone] = C3(108, 112, 120) } } -- (floor field value
-- contrast, coordinator: one clearly darker wet material + one lighter: wet near-black Mud streaks running with the wind and
-- pale weathered Limestone -- not Rock: Rock / Basalt are the Lighthouse Cliffs rim materials and SetMaterialColor is global;
-- the Pebble scan read as green moss)
B.PartDim = 0.7

local WET, STONE, WOOD, WOOD_DK = C3(22, 26, 32), C3(70, 76, 86), C3(78, 66, 54), C3(52, 44, 38)
local CHARGE = C3(150, 200, 255)

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Part, Paint, Emitter, Shard = A.Part, A.Paint, A.Emitter, A.Shard
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    -- the wind: one direction for the whole room (trunks, rain)
    local wa = vr:NextNumber(0, math.pi * 2)
    local wind = Vector3.new(math.cos(wa), 0, math.sin(wa))
    -- FLOOR FIELD (terrain paint, 0 parts): the whole open floor in big irregular blobs / drifts of the biome's ground
    -- materials (A.PaintField; its own Random so the room's other draws -- the layout -- stay where they were). The big
    -- round field blobs below only draw their numbers when the field ran.
    local field = A.PaintField(P, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.Slate, 30 }, { M.Mud, 25 }, { M.Basalt, 20 }, { M.Limestone, 25 } }, { Scale = 20, Stretch = 3.2, Dir = wind }) > 0
    local function FieldPaint(x: number, z: number, r: number, mat: Enum.Material, rr: Random)
        if field then rr:NextNumber(0, math.pi * 2) else Paint(x, z, r, mat, rr) end
    end
    local lit = false
    local function Runoff(b0: Vector3, b1: Vector3, w: number, o: Vector3)
        local d = Vector3.new(b1.X - b0.X, 0, b1.Z - b0.Z)
        local len, u = d.Magnitude, d.Unit
        local mid = Vector3.new((b0.X + b1.X) / 2, F, (b0.Z + b1.Z) / 2)
        local cf = CFrame.lookAt(mid, mid + u)
        local water = Part(fx, "Runoff", nil, Vector3.new(w, 0.15, len), cf * CFrame.new(0, 0.08, 0), WET, M.SmoothPlastic)
        water.Reflectance = 0.45; water.CastShadow = false
        n += 1
        -- a broken stone edge on the room side
        local side = cf:VectorToObjectSpace(o).X > 0 and 1 or -1
        local t = 0
        while t < len - 3 do
            local seg = math.min(vr:NextNumber(8, 14), len - t)
            if vr:NextNumber() < 0.75 then
                local at = cf * CFrame.new(-side * (w / 2 + 0.6), 0.25, -len / 2 + t + seg / 2)
                Part(fx, "RunoffEdge", nil, Vector3.new(1.1, vr:NextNumber(0.35, 0.6), seg - vr:NextNumber(1, 3)), at * CFrame.Angles(0, vr:NextNumber(-0.08, 0.08), 0), STONE, M.Slate)
                n += 1
            end
            t += seg
        end
        if Lava then
            for g = 1, math.max(1, math.floor(len / 26)) do
                Lava.Glow(fx, b0:Lerp(b1, (g - 0.5) / math.max(1, math.floor(len / 26))) + Vector3.new(0, F + 0.8 - b0.Y, 0), 18, CHARGE, 0.55, { Name = "ChargeGlow", MaxDistance = 300 })
            end
        end
        if not lit then
            lit = true
            local c = A.Carrier(fx, "ChargeLight", Vector3.new(1, 1, 1), CFrame.new(mid + Vector3.new(0, 2, 0)))
            local l = Instance.new("PointLight")
            l.Color = C3(170, 200, 255); l.Range = 26; l.Brightness = 0.9; l.Shadows = false
            l.Parent = c
            n += 1
        end
    end
    local isBand = {}
    for wi, sd in ipairs(P.walls) do
        local b0, b1 = P.Band(sd, 4, 18)
        if b0 then
            isBand[sd] = true
            Runoff(b0, b1, wi == 1 and 4.5 or 3.5, P.SIDES[sd])
        end
    end
    -- THE OPEN FLOOR: wet fields, puddles, lightning scars
    if ctx.Terrain then
        for _ = 1, vr:NextInteger(5, 7) do
            local p = P.Spot(12)
            FieldPaint(p.X, p.Z, vr:NextNumber(9, 16), ({ M.Slate, M.Slate, M.Mud, M.Basalt })[vr:NextInteger(1, 4)], vr)
        end
    end
    for _ = 1, vr:NextInteger(4, 6) do
        local p = P.Spot(8)
        if not P.DoorNear(p, 10) then
            for _, s in ipairs(Shard(fx, "Puddle", p, vr:NextNumber(2.5, 4.5), 0.1, WET, M.SmoothPlastic, vr)) do s.Reflectance = 0.5 end
            n += 3
        end
    end
    for _ = 1, vr:NextInteger(2, 3) do
        local p = P.Spot(14)
        if not P.DoorNear(p, 14) then
            if ctx.Terrain then Paint(p.X, p.Z, vr:NextNumber(5, 7), M.Basalt, vr) end
            for _ = 1, vr:NextInteger(3, 4) do
                local a = vr:NextNumber(0, math.pi * 2)
                -- short jagged forks that fade out (long straight segments read as tape lines at eye height)
                n += A.Cracks(fx, P, ctx, vr, p, Vector3.new(math.cos(a), 0, math.sin(a)), vr:NextNumber(0.45, 0.6),
                    { Neon = true, Hot = C3(180, 205, 245), Dark = C3(70, 92, 135), HotT = 0.6, DarkT = 0.82, HotShare = 0.06, Limit = 7, MaxDepth = 4,
                      Seg = { 1.6, 3.4 }, Turn = { 0.35, 0.9 }, Fade = 0.25, Start = 1, Y = 0.1 })
            end
        end
    end
    -- EDGE: wind-bent dead trunks on the rim, all leaning with the wind, and a broken wall stub
    local trees = 0
    for _, sd in ipairs(P.order) do
        if trees >= 3 then break end
        local o = P.SIDES[sd]
        local al = P.Along(sd)
        local at = C0 + o * (half + 5) + al * vr:NextNumber(-0.6, 0.6) * half
        if not P.DoorNear(at, 22) then
            trees += 1
            local h = vr:NextNumber(20, 28)
            local lean = math.rad(vr:NextNumber(20, 30))
            local axis = (Vector3.yAxis * math.cos(lean) + wind * math.sin(lean)).Unit
            local base = Vector3.new(at.X, F - 2, at.Z)
            local kit = ctx.EnvKit
            if kit and kit.Has("Storm", "DeadTrunk") then
                -- the scanned dead trunk, stretched tall and leaning with the wind (its up axis = the lean axis)
                -- (the scan is a log lying along its X, 12 long, pivot at the bottom centre: stood up along the lean axis)
                local sz = kit.Size("Storm", "DeadTrunk")
                local k = sz and math.clamp(h / math.max(sz.X, 0.1), 0.5, 4) or 2
                local look = wind:Cross(Vector3.yAxis).Unit
                local cf = CFrame.fromMatrix(base + axis * h / 2, axis, look) * CFrame.Angles(vr:NextNumber(0, 6.28), 0, 0)
                    * CFrame.new(0, -(sz and sz.Y or 3) * k / 2, 0)
                kit.Place("Storm", "DeadTrunk", cf, { Scale = k, Parent = fx, Hitbox = false, Name = "DeadTrunk" })
                n += 1
            else
                local side0 = axis:Cross(o).Magnitude > 0.1 and axis:Cross(o).Unit or wind
                Part(fx, "DeadTrunk", Enum.PartType.Cylinder, Vector3.new(h, 2.6, 2.6), CFrame.fromMatrix(base + axis * h / 2, axis, side0), C3(64, 60, 56), M.Wood)
                for _ = 1, 2 do
                    local from = base + axis * h * vr:NextNumber(0.6, 0.95)
                    local bd = (axis * 0.3 + wind * 0.8 + Vector3.new(0, vr:NextNumber(-0.2, 0.3), 0)).Unit
                    local bl = vr:NextNumber(5, 9)
                    local up = bd:Cross(Vector3.yAxis).Magnitude > 0.1 and bd:Cross(Vector3.yAxis).Unit or o
                    Part(fx, "DeadBranch", Enum.PartType.Cylinder, Vector3.new(bl, 0.8, 0.8), CFrame.fromMatrix(from + bd * bl / 2, bd, up), C3(64, 60, 56), M.Wood)
                end
                n += 3
            end
        end
    end
    -- SET PIECE: a wrecked hull heeled over on its side against a wall: curved ribs standing bare, a few broken strakes still
    -- on them, a keel, a raised bow stem, the mast snapped (the top half lying on the ground), a torn dark sail (one light)
    do
        local sd, spot = P.SetSpot(28, 8, isBand)
        if sd and spot then
            local o = P.SIDES[sd]
            local al = P.Along(sd)
            local L, Bm, Dp = 32, 6.5, 7 -- (grounding probe: ends + keel were 2.1 over the ground)
            -- hull frame: X across (toward the room = -o), Y up, Z along the wall; deck line 2.5 up, heeled 20 deg toward the wall
            local HF = CFrame.fromMatrix(Vector3.new(spot.X, F + 5, spot.Z) - o * 3, -o, Vector3.yAxis)
                * CFrame.Angles(0, 0, math.rad(-20)) * CFrame.Angles(math.rad(vr:NextNumber(-5, 5)), 0, 0)
            local function Pt(th: number, z: number): Vector3
                local s2 = 1 - math.min(1, math.abs(z) / (L / 2)) ^ 2 * 0.45
                return (HF * CFrame.new(math.cos(th) * Bm * s2, -math.sin(th) * Dp * s2, z)).Position
            end
            local function Stick(name: string, a0: Vector3, a1: Vector3, w: number, t: number, col: Color3, mat: Enum.Material): BasePart
                local mid, d = (a0 + a1) / 2, a1 - a0
                local up = math.abs(d.Unit:Dot(HF.ZVector)) < 0.9 and HF.ZVector or HF.YVector
                local part = Part(fx, name, nil, Vector3.new(w, t, d.Magnitude + 0.3), CFrame.lookAt(mid, a1, up), col, mat)
                n += 1
                return part
            end
            local TH = { math.rad(8), math.rad(55), math.rad(105), math.rad(160) }
            for k = 0, 8 do
                local z = -L / 2 + 2.5 + k * (L - 5) / 8
                if vr:NextNumber() < 0.85 then
                    local top = (k % 3 == 1) and 3 or #TH -- some ribs broken short
                    for i = 1, top - 1 do Stick("HullRib", Pt(TH[i], z), Pt(TH[i + 1], z), 0.7, 0.7, WOOD_DK, M.Wood) end
                end
            end
            -- strakes: the low side keeps a few planks, broken off at random lengths
            -- the stern half keeps its planking (the hull's mass), the bow half is bare ribs; a couple of loose strakes
            for _, th in ipairs({ math.rad(100), math.rad(118), math.rad(136), math.rad(154) }) do
                local z1 = vr:NextNumber(-2, 4)
                Stick("HullPlank", Pt(th, -L / 2 + 1), Pt(th, z1), 0.35, 2.6, WOOD, M.WoodPlanks)
            end
            for _, th in ipairs({ math.rad(70), math.rad(40) }) do
                local z0 = vr:NextNumber(-6, 2)
                Stick("HullPlank", Pt(th, z0), Pt(th, z0 + vr:NextNumber(6, 10)), 0.35, 2, WOOD, M.WoodPlanks)
            end
            Stick("Keel", Pt(math.rad(90), -L / 2), Pt(math.rad(90), 0), 1.1, 1.1, WOOD_DK, M.Wood)
            Stick("Keel", Pt(math.rad(90), 0), Pt(math.rad(90), L / 2), 1.1, 1.1, WOOD_DK, M.Wood)
            local bow = Pt(math.rad(90), L / 2)
            Stick("BowStem", bow, bow + HF.ZVector * 2.5 + HF.YVector * 6, 1, 1, WOOD_DK, M.Wood)
            -- the snapped mast: the stump stands from the deck line, the top half lies on the ground beside the hull
            local mastBase = (HF * CFrame.new(0, -Dp * 0.6, 2)).Position
            Stick("Mast", mastBase, mastBase + HF.YVector * 9, 1.1, 1.1, WOOD_DK, M.Wood)
            local lyFrom = Vector3.new(spot.X, F + 0.6, spot.Z) - o * 7 + al * vr:NextNumber(-6, 6)
            local lyDir = (al * vr:NextNumber(0.6, 1) * (vr:NextNumber() < 0.5 and -1 or 1) - o * 0.4).Unit
            Stick("MastTop", lyFrom, lyFrom + lyDir * 11, 0.9, 0.9, WOOD_DK, M.Wood)
            -- torn sail: two dark cloth triangles hanging off the stump, not a flat sheet
            local sailAt = mastBase + HF.YVector * 6
            for i = 1, 2 do
                local w = Instance.new("WedgePart")
                w.Name = "TornSail"; w.Anchored = true; w.CanCollide = false; w.CanQuery = false; w.CanTouch = false; w.CastShadow = false
                w.Size = Vector3.new(0.12, vr:NextNumber(3.5, 5), vr:NextNumber(3, 4.5))
                w.CFrame = CFrame.fromMatrix(sailAt + wind * (1.2 + i * 0.8) - Vector3.yAxis * i, wind:Cross(Vector3.yAxis).Unit, Vector3.yAxis) * CFrame.Angles(0, 0, math.rad((i - 1.5) * 30))
                w.Color = C3(58, 54, 48); w.Material = M.Fabric; w.Transparency = 0.1
                w.Parent = fx
                n += 1
            end
            local c = A.Carrier(fx, "WreckLight", Vector3.new(1, 1, 1), HF * CFrame.new(-3, 2, 0))
            local l = Instance.new("PointLight")
            l.Color = C3(255, 214, 160); l.Range = 18; l.Brightness = 0.8; l.Shadows = false
            l.Parent = c
            n += 1
        end
    end
    -- DRIFT: wind-driven rain streaks, the way the trunks lean
    Emitter(fx, "WindRain", CFrame.lookAt(C0 + Vector3.new(0, 24, 0) - wind * half * 0.6, C0 + Vector3.new(0, 24, 0) - wind * half * 0.6 + wind), Vector3.new(half * 1.6, 2, half * 0.6), {
        Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C3(200, 215, 235)), LightEmission = 0.3, LightInfluence = 0.7,
        Rate = 12, Lifetime = NumberRange.new(1, 1.4), Speed = NumberRange.new(30, 38), SpreadAngle = Vector2.new(6, 6), EmissionDirection = Enum.NormalId.Front,
        Acceleration = Vector3.new(0, -40, 0), Orientation = Enum.ParticleOrientation.VelocityParallel,
        Size = NumberSequence.new(0.12), Squash = NumberSequence.new(-2.5), Transparency = NumberSequence.new(0.35) })
    return n
end

return B
