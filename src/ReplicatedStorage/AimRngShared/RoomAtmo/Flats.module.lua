--!strict
-- ROOM ATMOSPHERE PASS 2 -- FLATS (the Neon Flats). mapvibe 2026-10-25. A dead roadside stop on the salt flats at dusk.
-- Real meshes: ReplicatedStorage.RoomAtmoKit.Flats (tools/atmo_kit_flats.py -> tools/atmo_kit_flats_import.py): GasPump,
-- Canopy, MotelSign, PhoneBooth, TireStack, Cone, Sedan, WaterTower, NeonArrow.
-- PLACEMENT (its own pattern): everything is laid out by THE ROAD -- a cracked asphalt road runs through the room from one
-- doorway to the other, and the stops stand at its two ENDS, turned to face it: a filling station at one end, a motel sign at
-- the other. Nothing else in any biome is placed by a road axis.
--   CONTRAST  Light: sun x0.6, ambient x0.88, a warm dusk grade; terrain x0.74, parts x0.74. Neon pink + warm bulbs.
--   GROUND    THE ROAD (terrain asphalt, a broken faded centre line, worn edge lines, skid marks -- Beams, 0 parts a dash);
--             the FILLING STATION: a canopy with a lit fascia over two pumps, a tyre stack (1 pink light); the MOTEL end: the
--             sign on its pole, a phone booth, cones along the verge; an abandoned sedan at a wall foot. The flats round it:
--             salt / sand / sandstone field (terrain paint, 0 parts).
--   EDGE      a water tower in the corner farthest from the road
--   SET PIECE a giant roadside ARROW sign fallen against a wall, still pointing down the road, its bulbs lit (1 light)
--   DRIFT     dust blowing along the road
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.6, Ambient = 0.88, Outdoor = 0.88, Tint = C3(255, 218, 196), TintAmt = 0.26 }
B.Palette = { Dim = 0.74 }
B.PartDim = 0.74
B.Drift = { RoadDust = true }

local PINK, WARM, LINE, LINE2, SKID, DUST = C3(255, 90, 180), C3(255, 206, 140), C3(214, 178, 70), C3(200, 196, 186), C3(16, 14, 14), C3(226, 196, 170)

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Emitter = A.Emitter
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    A.PaintField(P, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.Salt, 45 }, { M.Sand, 30 }, { M.Sandstone, 25 } }, { Scale = 28, Stretch = 2.6 })
    local root = game:GetService("ReplicatedStorage"):FindFirstChild("RoomAtmoKit")
    local KIT = root and root:FindFirstChild("Flats")
    local function Kit(name: string, at: Vector3, face: Vector3, k: number, tilt: CFrame?): Model?
        local t = KIT and KIT:FindFirstChild(name)
        if not (t and t:IsA("Model")) then return nil end
        local _, bb = t:GetBoundingBox()
        local cf = CFrame.lookAt(at, at + Vector3.new(face.X, 0, face.Z)) * (tilt or CFrame.new())
        local ok, m = pcall(A.PlaceModel, t, fx, cf, bb.Y * k, name)
        if not ok or not m then return nil end
        for _, q in ipairs(m:GetDescendants()) do
            if q:IsA("BasePart") then
                n += 1
                local role = q:GetAttribute("Role")
                if role == "Paint2" then q.Color = (name == "Canopy") and Color3.fromRGB(92, 84, 78) or Color3.fromRGB(150, 138, 120) -- (196 cream read
                    -- as a white slab at dusk; the canopy roof is all sky-facing top: darker still)
                elseif role == "Glass" then q.Transparency = 0.45; q.CastShadow = false
                elseif role == "Glow" or role == "Bulb" then q.CastShadow = false end
            end
        end
        return m
    end
    local function Inside(p: Vector3, m: number): boolean
        return math.abs(p.X - C0.X) <= half - m and math.abs(p.Z - C0.Z) <= half - m
    end
    local function Clamp(p: Vector3, m: number): Vector3
        return Vector3.new(math.clamp(p.X, C0.X - half + m, C0.X + half - m), F, math.clamp(p.Z, C0.Z - half + m, C0.Z + half - m))
    end

    -- THE ROAD: from one doorway to the other (one door: to the opposite wall), a slight bow
    local a: Vector3, b: Vector3
    if #P.doors >= 2 then
        a, b = P.doors[1], P.doors[2]
    elseif #P.doors == 1 then
        a = P.doors[1]; b = C0 + (C0 - Vector3.new(a.X, C0.Y, a.Z))
    else
        a, b = C0 + Vector3.new(0, 0, -half), C0 + Vector3.new(0, 0, half)
    end
    a, b = Vector3.new(a.X, F, a.Z), Vector3.new(b.X, F, b.Z)
    local d = (b - a).Magnitude > 1 and (b - a).Unit or Vector3.zAxis
    local side = d:Cross(Vector3.yAxis).Unit
    local bow = vr:NextNumber(-0.12, 0.12) * (b - a).Magnitude
    local function RoadAt(t: number): Vector3 return a:Lerp(b, t) + side * math.sin(t * math.pi) * bow end
    local RW = 7 -- (half width)
    if ctx.Terrain then
        for i = 0, 40 do
            local p = RoadAt(i / 40)
            if Inside(p, 1) then A.Paint(p.X, p.Z, RW + vr:NextNumber(-0.6, 0.6), M.Asphalt, vr) end
        end
    end
    -- markings: flat Beams on one carrier (no part a dash) -- a faded broken centre line, worn edge lines, skid marks
    local holder: BasePart? = nil
    local function Stripe(p0: Vector3, p1: Vector3, w: number, col: Color3, t0: number, t1: number)
        if not holder then holder = A.Carrier(fx, "RoadPaint", Vector3.new(0.2, 0.2, 0.2), CFrame.new(C0)); n += 1 end
        local f = p1 - p0
        if f.Magnitude < 0.2 then return end
        local sd = f.Unit:Cross(Vector3.yAxis).Unit
        local function At(pos: Vector3): Attachment
            local at = Instance.new("Attachment")
            at.CFrame = (holder :: BasePart).CFrame:ToObjectSpace(CFrame.fromMatrix(pos + Vector3.new(0, 0.12, 0), Vector3.yAxis, sd, Vector3.yAxis:Cross(sd)))
            at.Parent = holder
            return at
        end
        local bm = Instance.new("Beam")
        bm.Attachment0, bm.Attachment1 = At(p0), At(p1)
        bm.FaceCamera = false; bm.Segments = 1; bm.Width0 = w; bm.Width1 = w
        bm.Color = ColorSequence.new(col); bm.Transparency = NumberSequence.new(t0, t1)
        bm.LightEmission = 0; bm.LightInfluence = 1
        bm.Parent = holder
    end
    for i = 0, 26 do
        local t0, t1 = i / 27, (i + 0.5) / 27
        local p0, p1 = RoadAt(t0), RoadAt(t1)
        if Inside(p0, 2) and Inside(p1, 2) and vr:NextNumber() < 0.82 then -- (some dashes worn away)
            local fade = vr:NextNumber(0.25, 0.55)
            Stripe(p0, p1, 0.45, LINE, fade, math.min(0.9, fade + vr:NextNumber(0, 0.3)))
        end
        for _, s in ipairs({ -1, 1 }) do -- the edge lines, broken in long stretches
            local e0, e1 = RoadAt(t0) + side * s * (RW - 0.8), RoadAt((i + 1) / 27) + side * s * (RW - 0.8)
            if Inside(e0, 2) and Inside(e1, 2) and math.noise(i * 0.31, s * 3.1) > -0.15 then Stripe(e0, e1, 0.3, LINE2, 0.5, 0.65) end
        end
    end
    for _ = 1, 2 do -- skid marks: two dark curving pairs
        local t = vr:NextNumber(0.3, 0.7)
        local p = RoadAt(t) + side * vr:NextNumber(-3, 3)
        local dir = (CFrame.Angles(0, vr:NextNumber(-0.5, 0.5), 0) * CFrame.new(Vector3.zero, d)).LookVector
        local turn = vr:NextNumber(-0.06, 0.06)
        for _, off in ipairs({ -0.9, 0.9 }) do
            local q, dd = p + dir:Cross(Vector3.yAxis).Unit * off, dir
            for k = 1, 5 do
                local q2 = q + dd * 2.4
                if Inside(q2, 3) then Stripe(q, q2, 0.42, SKID, 0.35 + k * 0.08, 0.43 + k * 0.08) end
                q = q2
                dd = (CFrame.Angles(0, turn, 0) * CFrame.new(Vector3.zero, dd)).LookVector
            end
        end
    end
    local sideSign = (vr:NextNumber() < 0.5) and -1 or 1

    -- SET PIECE: the giant arrow fallen against a wall parallel-ish to the road, still pointing down it (1 light)
    local setAt: Vector3? = nil
    do
        -- (the sign's tip is the kit's Blender +X = Roblox local -X after the import's turn = lookAt's LEFT. Facing into the
        -- room from wall o, right = -o x up; the opposite wall's is the reverse -- so the wall is chosen for the direction)
        local best, bestScore = nil, -1
        for _, sd in ipairs(P.order) do
            local o = P.SIDES[sd]
            local right = (-o):Cross(Vector3.yAxis)
            if math.abs(P.Along(sd):Dot(d)) > 0.6 then
                for _, f in ipairs({ 0, -0.3, 0.3 }) do
                    local spot = C0 + o * (half - 5) + P.Along(sd) * f * half
                    local score = (right:Dot(d) < 0) and 2 or 1 -- (pointing down the road wins; the other wall only if that one is blocked)
                    if score > bestScore and not P.DoorNear(spot, 26) then best, bestScore = { sd, spot }, score; break end
                end
            end
        end
        if best then
            local o = P.SIDES[best[1]]
            local at = Vector3.new(best[2].X, F, best[2].Z)
            setAt = at
            Kit("NeonArrow", at, -o, vr:NextNumber(1.45, 1.7), CFrame.Angles(math.rad(vr:NextNumber(16, 24)), 0, math.rad(vr:NextNumber(-4, 4))))
            if Lava then Lava.Glow(fx, at - o * 2 + Vector3.new(0, 3, 0), 18, WARM, 0.6, { Name = "ArrowGlow", MaxDistance = 700 }) end
            local cc = A.Carrier(fx, "ArrowLight", Vector3.new(1, 1, 1), CFrame.new(at - o * 4 + Vector3.new(0, 4, 0)))
            local l = Instance.new("PointLight")
            l.Color = WARM; l.Range = 24; l.Brightness = 1; l.Shadows = false
            l.Parent = cc
            n += 1
        end
    end
    local function NearSet(p: Vector3, r: number): boolean
        return setAt ~= nil and (Vector3.new(p.X, 0, p.Z) - Vector3.new((setAt :: Vector3).X, 0, (setAt :: Vector3).Z)).Magnitude < r
    end

    -- THE FILLING STATION at the road's start, on one side, facing the road
    do
        -- (against the side wall, level with the road's first stretch: first look stood it 28 studs out in the room)
        local r0 = RoadAt(0.2)
        local c = Clamp(Vector3.new(r0.X, F, r0.Z) + side * sideSign * half * 2, 9)
        if not P.DoorNear(c, 14) and not NearSet(c, 22) then
            local toRoad = -side * sideSign
            Kit("Canopy", c, toRoad, vr:NextNumber(0.95, 1.1), CFrame.Angles(0, 0, math.rad(vr:NextNumber(-2, 2))))
            for _, s in ipairs({ -1, 1 }) do
                local p = c + d * s * vr:NextNumber(3.5, 4.5) + toRoad * 1.5
                Kit("GasPump", p, toRoad, vr:NextNumber(1.0, 1.15), CFrame.Angles(0, math.rad(vr:NextNumber(-6, 6)), 0))
            end
            Kit("TireStack", c - toRoad * 3 + d * vr:NextNumber(7, 9), d, 1, CFrame.Angles(0, vr:NextNumber(0, 6.28), 0))
            if Lava then Lava.Glow(fx, c + toRoad * 4.5 + Vector3.new(0, 12.5, 0), 16, PINK, 0.6, { Name = "FasciaGlow", MaxDistance = 600 }) end
            local cc = A.Carrier(fx, "CanopyLight", Vector3.new(1, 1, 1), CFrame.new(c + Vector3.new(0, 10, 0)))
            local l = Instance.new("PointLight")
            l.Color = PINK; l.Range = 22; l.Brightness = 0.9; l.Shadows = false
            l.Parent = cc
            n += 1
        end
    end
    -- THE MOTEL END: the sign, a phone booth, cones along the verge -- the other side, the other end
    do
        local r1 = RoadAt(0.8)
        local c = Clamp(Vector3.new(r1.X, F, r1.Z) - side * sideSign * half * 2, 6)
        if not P.DoorNear(c, 12) and not NearSet(c, 18) then
            local toRoad = side * sideSign
            Kit("MotelSign", c, toRoad, vr:NextNumber(1.0, 1.2), CFrame.Angles(math.rad(vr:NextNumber(-3, 3)), 0, math.rad(vr:NextNumber(-4, 4))))
            local pb = Clamp(c - d * vr:NextNumber(6, 8) - toRoad * 1.5, 6)
            if not P.DoorNear(pb, 10) then Kit("PhoneBooth", pb, toRoad, 1, CFrame.Angles(0, math.rad(vr:NextNumber(-12, 12)), 0)) end
        end
        for i = 1, vr:NextInteger(3, 5) do
            local t = 0.25 + i * 0.11 + vr:NextNumber(-0.03, 0.03)
            local p = RoadAt(t) + side * sideSign * -(RW - 0.6)
            if Inside(p, 3) and not P.DoorNear(p, 9) then
                local knocked = vr:NextNumber() < 0.3
                Kit("Cone", p, d, vr:NextNumber(0.9, 1.1), knocked and CFrame.Angles(math.rad(90), vr:NextNumber(0, 6.28), 0) or nil)
            end
        end
    end
    -- the abandoned sedan at the foot of the wall that runs most along the road, angled in
    do
        for _ = 1, 4 do
            local sd = P.order[vr:NextInteger(1, #P.order)]
            local o, al = P.SIDES[sd], P.Along(sd)
            if math.abs(al:Dot(d)) > 0.5 then
                local p = C0 + o * (half - 6) + al * vr:NextNumber(-0.6, 0.6) * half
                p = Vector3.new(p.X, F, p.Z)
                if not P.DoorNear(p, 14) and not NearSet(p, 18) then
                    local ang = math.rad(vr:NextNumber(15, 35)) * ((vr:NextNumber() < 0.5) and -1 or 1)
                    Kit("Sedan", p, (CFrame.Angles(0, ang, 0) * CFrame.new(Vector3.zero, -o)).LookVector, 1, CFrame.Angles(math.rad(vr:NextNumber(-3, 3)), 0, math.rad(vr:NextNumber(2, 5))))
                    break
                end
            end
        end
    end
    -- EDGE: the water tower in the corner farthest from the road
    do
        local best, bestD = nil, -1
        for _, ab in ipairs({ { 1, 3 }, { 1, 4 }, { 2, 3 }, { 2, 4 } }) do
            local c = C0 + (P.SIDES[ab[1]] + P.SIDES[ab[2]]) * (half - 8)
            local rel = c - a
            local dist = math.abs(rel:Dot(side))
            if dist > bestD and not P.DoorNear(c, 16) and not NearSet(c, 20) then best, bestD = c, dist end
        end
        if best then Kit("WaterTower", Vector3.new(best.X, F, best.Z), (C0 - best).Unit, vr:NextNumber(1.0, 1.15), CFrame.Angles(math.rad(vr:NextNumber(-3, 3)), 0, math.rad(vr:NextNumber(-3, 3)))) end
    end

    -- DRIFT: dust blowing along the road
    Emitter(fx, "RoadDust", CFrame.lookAt(a:Lerp(b, 0.5) + Vector3.new(0, 1.5, 0), a:Lerp(b, 0.5) + Vector3.new(0, 1.5, 0) + d), Vector3.new(half * 1.4, 2, half * 1.4), {
        Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(DUST), LightEmission = 0, LightInfluence = 1,
        Rate = 2, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(4, 7), SpreadAngle = Vector2.new(8, 8), EmissionDirection = Enum.NormalId.Front,
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.82), NumberSequenceKeypoint.new(1, 1) }),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) }) })
    return n
end

return B
