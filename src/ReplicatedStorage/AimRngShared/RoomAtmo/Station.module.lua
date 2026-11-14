--!strict
-- ROOM ATMOSPHERE PASS 2 -- STATION (the Derelict Station). mapvibe 2026-10-25. Its OWN layout (coordinator: "no two biomes with
-- the same placement pattern" -- Cyber keeps its tidy machine row): a hull that took a hit and went dark. NOTHING IN ROWS.
-- Pieces from the Cyber mesh kit (ReplicatedStorage.RoomAtmoKit.Cyber) knocked over, plus hull plates as parts.
--   CONTRAST  Light: sun x0.5, ambient x0.9, a cold grade; red emergency light at the wall feet, cold white at the breach.
--   GROUND    BUCKLED BULKHEADS: on every wall, irregular groups of hull plates leaning INWARD off the wall at different angles,
--             bent ribs kinked into the room, a plate fallen flat at the foot; a broken red emergency strip in pieces, one
--             end dropped. The deck: displaced, tilted deck plates, scorch marks, frost spreading from the breach.
--   EDGE      TOPPLED RACKS lying across one or two corners, a tank rolled on its side, a fallen girder propped on a wall
--   SET PIECE the HULL BREACH: torn up out of the DECK by a wall (works on the edge maps' low parapets too) -- deck plates peeled
--             up round a dark hole with a cold rim, icicles, frost venting up and drifting in, the wreckage piled against the
--             wall behind (1 light). A second debris pile under a collapsed girder elsewhere, sparking.
--   DRIFT     slow frost crystals from the breach side
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.5, Ambient = 0.9, Outdoor = 0.9, Tint = C3(210, 222, 242), TintAmt = 0.24 }
B.Palette = { Dim = 0.64 }
B.PartDim = 0.64
B.Drift = { FrostDrift = true }

-- (first look: pale plates vanished against the station's own pale wall panels -> darker, scorched hull tones)
local HULL, HULL2, HULLDK, RIB, RED, AMBER, FROST, COLD, SCORCH, CABLE =
    C3(92, 96, 104), C3(70, 74, 82), C3(44, 46, 52), C3(46, 48, 54), C3(255, 58, 44), C3(255, 150, 60),
    C3(200, 226, 242), C3(170, 214, 255), C3(32, 26, 24), C3(22, 22, 26)
local ROLE = { Glow = RED, Trim = C3(196, 150, 40), Hull = C3(62, 65, 72), Panel = C3(128, 132, 140), Pipe = C3(92, 108, 124) }

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Part, Emitter = A.Part, A.Emitter
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    local root = game:GetService("ReplicatedStorage"):FindFirstChild("RoomAtmoKit")
    local KIT = root and root:FindFirstChild("Cyber")
    local function Kit(name: string, at: Vector3, face: Vector3, k: number, tilt: CFrame?, glow: Color3?): Model?
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
                local c = (role == "Glow" and glow) or ROLE[role]
                if c then q.Color = c end
                if role == "Glow" then q.CastShadow = false end
            end
        end
        return m
    end
    local function Inside(p: Vector3, m: number): boolean
        return math.abs(p.X - C0.X) <= half - m and math.abs(p.Z - C0.Z) <= half - m
    end
    -- a soft flat blotch: 3 overlapping thin discs (Shard's triangles read as black / white cut-out triangles here)
    local function Flat(name: string, at: Vector3, r: number, col: Color3, mat: Enum.Material, t: number?)
        for i = 1, 3 do
            local rr = r * vr:NextNumber(0.5, 0.9)
            local off = Vector3.new(vr:NextNumber(-0.4, 0.4) * r, 0, vr:NextNumber(-0.4, 0.4) * r)
            local d = Part(fx, name, Enum.PartType.Cylinder, Vector3.new(0.05, rr * 2, rr * 2 * vr:NextNumber(0.6, 1)),
                CFrame.new(at + off + Vector3.new(0, 0.06 + 0.01 * i, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), math.rad(90)), col, mat)
            d.CastShadow = false
            d.Transparency = math.min(0.9, (t or 0) + 0.15 * (i - 1))
            n += 1
        end
    end
    -- a pile of torn plates / chunks round `at` (radius r), piled higher in the middle
    local function Debris(at: Vector3, r: number, k: number)
        for i = 1, k do
            local a, d = vr:NextNumber(0, math.pi * 2), r * math.sqrt(vr:NextNumber())
            local p = at + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
            local h = 1 + (1 - d / r) * vr:NextNumber(1, 3)
            local sz = Vector3.new(vr:NextNumber(1.5, 4.5), vr:NextNumber(0.3, 1.2), vr:NextNumber(1.2, 3.5))
            local shape = (i % 3 == 0) and Enum.PartType.Wedge or nil
            Part(fx, "Debris", shape, sz, CFrame.new(p + Vector3.new(0, h * 0.45, 0)) * CFrame.Angles(vr:NextNumber(-0.7, 0.7), vr:NextNumber(0, 6.28), vr:NextNumber(-0.7, 0.7)),
                (i % 2 == 0) and HULL2 or HULLDK, (i % 4 == 0) and M.DiamondPlate or M.Metal)
            n += 1
        end
    end

    -- SET PIECE first (everything else keeps clear of it): the HULL BREACH, torn up out of the DECK by a wall (review: a breach
    -- hung on the wall floated in the air over the edge maps' low parapets -- a deck breach works on every station template)
    local breach: Vector3? = nil
    local breachO: Vector3? = nil
    do
        local sd, spot = P.SetSpot(24, 11, nil)
        if sd and spot then
            local o, al = P.SIDES[sd], P.Along(sd)
            local into = -o
            local c = Vector3.new(spot.X, F, spot.Z)
            breach, breachO = c, o
            local R = vr:NextNumber(4.2, 5.2)
            local function Disc(name: string, r1: number, r2: number, y: number, col: Color3, mat: Enum.Material, t: number): BasePart
                local d = Part(fx, name, Enum.PartType.Cylinder, Vector3.new(0.06, r1 * 2, r2 * 2), CFrame.new(c + Vector3.new(0, y, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), math.rad(90)), col, mat)
                d.Transparency = t; d.CastShadow = false
                n += 1
                return d
            end
            Disc("BreachScorch", R * 2.1, R * 1.8, 0.04, SCORCH, M.Slate, 0.45) -- (blast marks round it)
            Disc("BreachGlow", R * 1.12, R * 0.98, 0.08, COLD, M.Neon, 0.2) -- (the cold rim)
            Disc("BreachVoid", R, R * 0.86, 0.11, C3(6, 8, 14), M.SmoothPlastic, 0) -- (the hole: dark, space under the deck)
            -- deck plates torn UP round the hole, uneven, some bent right back
            local petals = vr:NextInteger(7, 9)
            for i = 1, petals do
                local a = (i / petals) * math.pi * 2 + vr:NextNumber(-0.3, 0.3)
                local radial = Vector3.new(math.cos(a), 0, math.sin(a))
                local len = vr:NextNumber(2.5, 5)
                local w = vr:NextNumber(2.2, 3.8)
                local up = math.rad(vr:NextNumber(35, 80)) -- (how far it is peeled up)
                local base = c + radial * R * vr:NextNumber(0.9, 1.05) + Vector3.new(0, 0.1, 0)
                local dir = (radial * math.cos(up) + Vector3.yAxis * math.sin(up)).Unit
                local tip = base + dir * len
                local pcf = CFrame.lookAt((base + tip) / 2, tip) * CFrame.Angles(0, 0, vr:NextNumber(-0.3, 0.3))
                Part(fx, "BreachPetal", (i % 3 == 0) and Enum.PartType.Wedge or nil, Vector3.new(w, 0.35, len), pcf, (i % 2 == 0) and HULL or HULL2, M.DiamondPlate)
                n += 1
                if vr:NextNumber() < 0.4 then -- an icicle off the lip
                    local ih = vr:NextNumber(0.7, 1.6)
                    local ic = Part(fx, "Icicle", Enum.PartType.Wedge, Vector3.new(0.3, ih, 0.4), CFrame.new(tip - Vector3.new(0, ih / 2, 0)) * CFrame.Angles(math.rad(180), vr:NextNumber(0, 6.28), 0), FROST, M.Ice)
                    ic.Transparency = 0.2; ic.CastShadow = false
                    n += 1
                end
            end
            -- frost venting up out of it and drifting into the room
            Emitter(fx, "BreachFrost", CFrame.new(c + Vector3.new(0, 0.5, 0)) * CFrame.Angles(math.rad(-90), 0, 0), Vector3.new(R * 1.6, R * 1.6, 0.4), {
                Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(FROST), LightEmission = 0.3, LightInfluence = 0.6,
                Rate = 6, Lifetime = NumberRange.new(2.5, 4.5), Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(14, 14),
                Acceleration = into * 1.5 + Vector3.new(0, -0.6, 0), EmissionDirection = Enum.NormalId.Front,
                Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 6) }) })
            for k = 1, 4 do
                local p = c + into * (R + 1 + k * 3) + al * vr:NextNumber(-3, 3) * k * 0.6
                if Inside(p, 4) and not P.DoorNear(p, 9) then Flat("Frost", p, vr:NextNumber(3.2, 4.4) - k * 0.35, FROST, M.Ice, 0.2 + k * 0.1) end
            end
            -- the wreckage thrown out of it, piled against the wall behind
            Debris(c + o * (R + 3.5) + al * vr:NextNumber(-3, 3), 5, vr:NextInteger(8, 11))
            if Lava then Lava.Glow(fx, c + Vector3.new(0, 1.2, 0), R * 2.6, COLD, 0.55, { Name = "BreachHalo", MaxDistance = 700 }) end
            local cc = A.Carrier(fx, "BreachLight", Vector3.new(1, 1, 1), CFrame.new(c + Vector3.new(0, 2.5, 0)))
            local l = Instance.new("PointLight")
            l.Color = COLD; l.Range = 22; l.Brightness = 1.3; l.Shadows = false
            l.Parent = cc
            n += 1
        end
    end
    local function NearBreach(p: Vector3, r: number): boolean
        return breach ~= nil and (Vector3.new(p.X, 0, p.Z) - Vector3.new((breach :: Vector3).X, 0, (breach :: Vector3).Z)).Magnitude < r
    end

    -- BUCKLED BULKHEADS on every wall: irregular groups, leaning inward, never a row
    local redLit = false
    for _, sd in ipairs(P.order) do
        local o, al = P.SIDES[sd], P.Along(sd)
        local into = -o
        local groups = vr:NextInteger(3, 5)
        local used = {}
        for g = 1, groups do
            local f = vr:NextNumber(-0.85, 0.85)
            local clash = false
            for _, u in ipairs(used) do if math.abs(u - f) < 0.22 then clash = true end end
            local base = C0 + o * (half - 0.8) + al * f * half
            base = Vector3.new(base.X, F, base.Z)
            if not clash and not P.DoorNear(base, 12) and not NearBreach(base, 14) then
                table.insert(used, f)
                local plates = vr:NextInteger(2, 3)
                for i = 1, plates do
                    local w, h = vr:NextNumber(6, 11), vr:NextNumber(11, 19) -- (walls sheet: 9-16 read small on a 123-stud room)
                    local lean = math.rad(vr:NextNumber(10, 32)) -- (top pushed in)
                    local at = base + al * (i - (plates + 1) / 2) * w * vr:NextNumber(0.6, 0.9)
                    -- (turned about its FOOT: the bottom edge stays on the deck by the wall, the top comes in)
                    local cf = CFrame.lookAt(at, at + into) * CFrame.Angles(-lean, 0, math.rad(vr:NextNumber(-9, 9))) * CFrame.new(0, h / 2, 0.25)
                    local torn = vr:NextNumber() < 0.4 -- (a torn diagonal top edge)
                    local pl = Part(fx, "BuckledPlate", torn and Enum.PartType.Wedge or nil, Vector3.new(0.5, h, w), cf * CFrame.Angles(0, math.rad(90), 0),
                        (vr:NextNumber() < 0.5) and HULL or HULL2, (i == 2) and M.DiamondPlate or M.Metal)
                    -- a dark scorched band across the plate
                    if not torn then
                        Part(fx, "PlateBurn", nil, Vector3.new(w * 0.9, h * vr:NextNumber(0.2, 0.35), 0.1), cf * CFrame.new(0, vr:NextNumber(-0.2, 0.25) * h, -0.33), HULLDK, M.Slate).CastShadow = false
                        n += 1
                    end
                    local _ = pl
                    n += 1
                end
                -- a rib kinked into the room: a straight foot then the bent top
                local rb = base + al * vr:NextNumber(-3, 3) + into * 0.6
                local h1, h2 = vr:NextNumber(7, 10), vr:NextNumber(8, 12)
                local k1 = rb + Vector3.new(0, h1, 0) + into * vr:NextNumber(0.5, 1.5)
                local k2 = k1 + Vector3.new(0, h2 * 0.75, 0) + into * h2 * vr:NextNumber(0.45, 0.8)
                for _, seg in ipairs({ { rb, k1 }, { k1, k2 } }) do
                    local a, b = seg[1], seg[2]
                    Part(fx, "BentRib", nil, Vector3.new(1.1, 1.4, (b - a).Magnitude + 0.6), CFrame.lookAt((a + b) / 2, b), RIB, M.Metal)
                    n += 1
                end
                if vr:NextNumber() < 0.55 then -- a plate fallen flat at the foot
                    local at = base + into * vr:NextNumber(4, 6.5) + al * vr:NextNumber(-3, 3)
                    if not P.DoorNear(at, 10) then
                        Part(fx, "FallenPlate", nil, Vector3.new(vr:NextNumber(5, 8), 0.45, vr:NextNumber(5, 8)), CFrame.new(at + Vector3.new(0, 0.5, 0)) * CFrame.Angles(math.rad(vr:NextNumber(-8, 8)), vr:NextNumber(0, 6.28), math.rad(vr:NextNumber(4, 12))), HULL2, M.Metal)
                        n += 1
                    end
                end
            end
        end
        -- the broken red emergency strip on this wall: pieces with gaps, one end dropped
        local pieces = vr:NextInteger(2, 4)
        for i = 1, pieces do
            local f0 = -0.8 + (i - 1) * 1.6 / pieces + vr:NextNumber(0, 0.12)
            local f1 = f0 + 1.6 / pieces * vr:NextNumber(0.35, 0.7)
            local a = C0 + o * (half - 1.4) + al * f0 * half
            local b = C0 + o * (half - 1.4) + al * f1 * half
            a, b = Vector3.new(a.X, F + 1.7, a.Z), Vector3.new(b.X, F + 1.7, b.Z)
            if vr:NextNumber() < 0.35 then b = b - Vector3.new(0, vr:NextNumber(0.8, 1.5), 0) + into * 0.6 end -- (sagging off its clips)
            if not P.DoorNear((a + b) / 2, 10) and not NearBreach((a + b) / 2, 10) then
                local s = Part(fx, "EmergencyStrip", nil, Vector3.new(0.3, 0.22, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), RED, M.Neon)
                s.Transparency = 0.15; s.CastShadow = false
                n += 1
                if Lava and i == 1 then Lava.Glow(fx, (a + b) / 2 + into * 1.5, 12, RED, 0.62, { Name = "EmergencyGlow", MaxDistance = 400 }) end
                if not redLit then
                    redLit = true
                    local cc = A.Carrier(fx, "EmergencyLight", Vector3.new(1, 1, 1), CFrame.new((a + b) / 2 + into * 2 + Vector3.new(0, 1, 0)))
                    local l = Instance.new("PointLight")
                    l.Color = C3(255, 70, 56); l.Range = 24; l.Brightness = 1.1; l.Shadows = false
                    l.Parent = cc
                    n += 1
                end
            end
        end
    end

    -- TOPPLED RACKS across one or two corners, a tank rolled on its side by one of them
    do
        local corners = {}
        for _, a in ipairs({ { 1, 3 }, { 1, 4 }, { 2, 3 }, { 2, 4 } }) do
            local c = C0 + (P.SIDES[a[1]] + P.SIDES[a[2]]) * (half - 7.5)
            if not P.DoorNear(c, 15) and not NearBreach(c, 18) then table.insert(corners, { c, P.SIDES[a[1]], P.SIDES[a[2]] }) end
        end
        for i = #corners, 2, -1 do local j = vr:NextInteger(1, i); corners[i], corners[j] = corners[j], corners[i] end
        for i = 1, math.min(vr:NextInteger(1, 2), #corners) do
            local c, ox, oz = corners[i][1], corners[i][2], corners[i][3]
            local diag = (ox - oz).Unit -- (lying ACROSS the corner, along the diagonal that cuts it)
            local at = Vector3.new(c.X, F, c.Z)
            -- (rolled onto its side, the rack's length lies along its right vector: face = up x diag puts it along the cut)
            Kit("ServerRack", at, Vector3.new(diag.Z, 0, -diag.X), vr:NextNumber(1.4, 1.7), CFrame.Angles(0, 0, math.rad((vr:NextNumber() < 0.5) and 90 or -90)) * CFrame.Angles(math.rad(vr:NextNumber(-8, 8)), 0, 0), RED)
            if i == 1 then
                local tAt = at - (ox + oz).Unit * vr:NextNumber(8, 11) + diag * vr:NextNumber(-4, 4)
                if not P.DoorNear(tAt, 12) then Kit("Tank", Vector3.new(tAt.X, F, tAt.Z), diag, 1.3, CFrame.Angles(math.rad(90), 0, 0), AMBER) end
            end
            if vr:NextNumber() < 0.6 then Debris(at - (ox + oz).Unit * 4, 3.5, vr:NextInteger(3, 5)) end
        end
    end

    -- a COLLAPSED GIRDER propped against a wall, a debris pile and a sparking cable under it
    do
        for _ = 1, 6 do
            local sd = P.order[vr:NextInteger(1, #P.order)]
            local o, al = P.SIDES[sd], P.Along(sd)
            local f = vr:NextNumber(-0.6, 0.6)
            local foot = C0 + o * (half - 14) + al * f * half
            foot = Vector3.new(foot.X, F, foot.Z)
            if not P.DoorNear(foot, 16) and not NearBreach(foot, 22) then
                -- the truss lies from the deck up onto the wall at ~28 deg, turned off-square
                local yaw = vr:NextNumber(-0.5, 0.5)
                local dir = (CFrame.Angles(0, yaw, 0) * CFrame.new(Vector3.zero, o)).LookVector
                Kit("Truss", foot, Vector3.new(dir.Z, 0, -dir.X), 0.75, CFrame.Angles(0, 0, math.rad(vr:NextNumber(22, 30))))
                Debris(foot - o * 1.5, 4, vr:NextInteger(4, 6))
                local top = foot + o * 6 + Vector3.new(0, 14, 0)
                local end1 = foot - o * 3 + al * vr:NextNumber(-2, 2) + Vector3.new(0, 0.5, 0)
                local cb = Part(fx, "HangingCable", Enum.PartType.Cylinder, Vector3.new((top - end1).Magnitude, 0.4, 0.4), CFrame.lookAt((top + end1) / 2, end1) * CFrame.Angles(0, math.rad(90), 0), CABLE, M.SmoothPlastic)
                cb.CastShadow = false
                n += 1
                Emitter(fx, "CableSparks", CFrame.new(end1 + Vector3.new(0, 0.3, 0)) * CFrame.Angles(math.rad(-90), 0, 0), Vector3.new(0.4, 0.4, 0.4), {
                    Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.new(1, 0.9, 0.6), AMBER), LightEmission = 1, LightInfluence = 0,
                    Rate = 4, Lifetime = NumberRange.new(0.25, 0.6), Speed = NumberRange.new(6, 11), SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, -35, 0),
                    Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0) }) })
                break
            end
        end
    end

    -- THE DECK: displaced, tilted deck plates (never on a grid), scorch marks
    local plates = {}
    for _ = 1, vr:NextInteger(3, 5) do
        local p = P.Spot(12)
        local near = false
        for _, q in ipairs(plates) do if (q - p).Magnitude < 12 then near = true end end
        if not near and not P.DoorNear(p, 12) and not NearBreach(p, 12) then
            table.insert(plates, p)
            Kit("FloorPlate", p + Vector3.new(0, 0.05, 0), Vector3.new(math.cos(vr:NextNumber(0, 6.28)), 0, 1), vr:NextNumber(0.9, 1.2),
                CFrame.Angles(math.rad(vr:NextNumber(-6, 6)), 0, math.rad(vr:NextNumber(-6, 6))), (vr:NextNumber() < 0.5) and RED or C3(70, 70, 74))
        end
    end
    for _ = 1, vr:NextInteger(2, 3) do
        local p = P.Spot(10)
        if not P.DoorNear(p, 10) then Flat("Scorch", p, vr:NextNumber(3, 5), SCORCH, M.Slate, 0.66) end -- (0.5 read as round pits)
    end

    -- DRIFT: slow frost crystals (room-wide; the breach streams its own)
    Emitter(fx, "FrostDrift", CFrame.new(C0 + Vector3.new(0, 6, 0) + (breachO or Vector3.zero) * half * 0.35), Vector3.new(half * 1.4, 8, half * 1.4), {
        Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(FROST), LightEmission = 0.4, LightInfluence = 0.5,
        Rate = 4, Lifetime = NumberRange.new(6, 10), Speed = NumberRange.new(0.1, 0.4), SpreadAngle = Vector2.new(180, 180),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.14), NumberSequenceKeypoint.new(1, 0) }) })
    return n
end

return B
