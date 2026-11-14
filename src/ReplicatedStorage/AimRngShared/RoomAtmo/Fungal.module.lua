--!strict
-- ROOM ATMOSPHERE PASS 2 -- FUNGAL v3 (the Spore World; RoomAtmo API: see RoomAtmo "ATMOSPHERE PASS 2"). Its own treatment
-- (reference: dark undergrowth lit only by bioluminescence, moss / lichen mats and roots on every floor, webs of spore strands
-- in the corners). v3 after the coordinator's review of v2 ("plastic toys", "bare purple dirt", "one purple", "a pink blob"):
-- the mushrooms are REAL MESHES now -- ReplicatedStorage.RoomAtmoKit.Fungal (tools/fungal_atmo_blender.py: lumpy irregular
-- caps with gill fins underneath, raised spots, stems with a hanging ring and a bulbous base, clusters of 5-7 with a broken
-- one, mycelium mats with raised threads, lichen rosettes, puffballs, bracket shelves); muted dark caps, pale stems, the glow
-- ONLY on gills / spots / threads, in ONE contrasting hue (teal) against the violet world. Without the kit (an unsaved
-- place) it falls back to plain part-built mushrooms.
--   CONTRAST  Light: the dim twilight sun x0.5 and ambient x0.88 (the gun plate stays within ~10%); palette x0.45 (ground and rock well below the sky),
--             parts x0.5. The teal gills, spots and mycelium carry the light.
--   GROUND    MYCELIUM BEDS at the wall foot: dark mud, mushroom clusters (5-7, mixed sizes, one broken) with thin glowing
--             mycena beside them on a mycelium mat, one teal PointLight a room, a low spore mist; glowing threads run out
--             across the floor. The open floor (< 0.6 stud, no collision): mycelium mats, lichen rosettes in a second hue
--             (grey-teal), puffballs, little glowing mycena tufts at the other walls' feet.
--   EDGE      GIANT MUSHROOMS (the kit's giants scaled to 40-50 studs) rooted below the rim and leaning over the room, gills
--             glowing teal, spores falling; a web of pale SPORE STRANDS spun across one corner above head height (beams)
--   SET PIECE a FALLEN GIANT: a colossal mushroom toppled along a wall foot, its cap against the wall and its glowing gills
--             turned to the room, bracket fungi growing on the stem, a cluster sprouting at its base, spores pouring out of
--             the gills (1 light) -- a mushroom from any distance
--   DRIFT     a low violet spore haze creeping across the floor + glowing teal spores drifting
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.5, Ambient = 0.88, Outdoor = 0.88, Tint = C3(222, 210, 255), TintAmt = 0.25 }
B.Palette = { Dim = 0.45, Mats = { [M.Slate] = 0.55, [M.Mud] = 0.62, [M.Grass] = 1, [M.LeafyGrass] = 1 },
    Base = { [M.Grass] = C3(30, 52, 46), [M.LeafyGrass] = C3(34, 50, 44), [M.Pebble] = C3(46, 58, 54) } } -- (moss / lichen fields: the world's palette has no grass; floor-only materials, never a Fungal RimMat)
B.PartDim = 0.5

local TEAL, TEAL_DEEP, VIOLET = C3(70, 235, 210), C3(20, 110, 110), C3(150, 110, 230)
local CAPS = { C3(58, 44, 58), C3(44, 46, 62), C3(64, 46, 44), C3(50, 40, 66) }
local STEM, STEM_DARK = C3(138, 128, 136), C3(96, 88, 100)
local LICHEN = { C3(40, 62, 58), C3(56, 64, 46) }
local MOSS = C3(44, 60, 54)
local ROUGH = { Moss = M.Grass, Lichen = M.Slate, Root = M.Wood, Mat = M.Grass, Shelf = M.Wood }

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Part, Paint, Emitter = A.Part, A.Paint, A.Emitter
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    local rs = game:GetService("ReplicatedStorage")
    local kitRoot = rs:FindFirstChild("RoomAtmoKit")
    local KIT = kitRoot and kitRoot:FindFirstChild("Fungal")
    -- a kit piece: `size` = its height (or, with byWidth, its width across) in studs; up = the piece's up axis (lean);
    -- recolours caps / glow per call. Returns the model or nil (no kit).
    local function Kit(name: string, at: Vector3, size: number, up: Vector3?, capCol: Color3?, glowCol: Color3?, byWidth: boolean?): Model?
        local tmpl = KIT and KIT:FindFirstChild(name)
        if not (tmpl and tmpl:IsA("Model")) then return nil end
        local _, bb = tmpl:GetBoundingBox()
        local h = size
        if byWidth then h = size * bb.Y / math.max(bb.X, bb.Z, 0.1) end
        local u = (up or Vector3.yAxis).Unit
        local x = Vector3.yAxis:Cross(u)
        x = (x.Magnitude > 1e-3) and x.Unit or Vector3.xAxis
        local cf = CFrame.fromMatrix(at, x, u) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0)
        local ok, m = pcall(A.PlaceModel, tmpl, fx, cf, h, name)
        if not ok or not m then return nil end
        if up then
            -- (PlaceModel stands the box's bottom on `at` in the MODEL's own frame: a tilted / lying model floated by half
            -- its length. Re-seat it on its lowest WORLD point.)
            local lo = math.huge
            for _, q in ipairs(m:GetDescendants()) do
                if q:IsA("BasePart") then
                    local c, hs = q.CFrame, q.Size / 2
                    local ey = math.abs(c.RightVector.Y) * hs.X + math.abs(c.UpVector.Y) * hs.Y + math.abs(c.LookVector.Y) * hs.Z
                    lo = math.min(lo, c.Position.Y - ey)
                end
            end
            if lo < math.huge then m:PivotTo(m:GetPivot() + Vector3.new(0, at.Y - lo, 0)) end
        end
        for _, q in ipairs(m:GetDescendants()) do
            if q:IsA("BasePart") then
                n += 1
                local role = q:GetAttribute("Role")
                if role == "Cap" and capCol then q.Color = capCol
                elseif (role == "Glow" or role == "Threads" or role == "Rim") and glowCol then q.Color = glowCol end
                if q:GetAttribute("Glow") then q.CastShadow = false
                elseif ROUGH[role] then q.Material = ROUGH[role] end -- (flat floor pieces in Plastic caught the pink sky as a pale sheen)
            end
        end
        return m
    end
    local function RolePos(m: Model?, role: string): Vector3?
        if not m then return nil end
        for _, q in ipairs(m:GetChildren()) do if q:IsA("BasePart") and q:GetAttribute("Role") == role then return q.Position end end
        return nil
    end
    -- the fallback when the kit is missing: a plain part-built mushroom
    local function Shroom(at: Vector3, h: number, w: number, glow: Color3?)
        local base = CFrame.new(at) * CFrame.Angles(math.rad(vr:NextNumber(-10, 10)), vr:NextNumber(0, 6.28), math.rad(vr:NextNumber(-10, 10)))
        Part(fx, "MushStem", Enum.PartType.Cylinder, Vector3.new(h, w * 0.2, w * 0.2), base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), STEM, M.SmoothPlastic).CastShadow = false
        local cap = Part(fx, "MushCap", nil, Vector3.new(w, w * 0.4, w), base * CFrame.new(0, h + w * 0.08, 0), CAPS[vr:NextInteger(1, #CAPS)], M.SmoothPlastic)
        local sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Sphere; sm.Parent = cap
        n += 2
        if glow then
            local g = Part(fx, "MushGill", Enum.PartType.Cylinder, Vector3.new(0.12, w * 0.86, w * 0.86), base * CFrame.new(0, h - w * 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)), glow, M.Neon)
            g.Transparency = 0.25; g.CastShadow = false
            n += 1
        end
    end
    local function Cluster(at: Vector3, h: number, glow: Color3)
        if not Kit("ClusterA", at, h, Vector3.yAxis + Vector3.new(vr:NextNumber(-0.1, 0.1), 0, vr:NextNumber(-0.1, 0.1)), CAPS[vr:NextInteger(1, #CAPS)], glow) then
            Shroom(at, h * 0.8, h * 0.7, glow)
        end
    end
    local function Mycena(at: Vector3, h: number)
        if not Kit("ClusterB", at, h, nil, nil, TEAL) then Shroom(at, h, h * 0.4, TEAL) end
    end
    -- a moss / lichen cushion mat (buttons glowing on some)
    local function Mat(at: Vector3, w: number, glow: boolean)
        local m = Kit("MossA", at - Vector3.new(0, 0.05, 0), w, nil, nil, TEAL, true)
        if m then
            local mt = m:FindFirstChild("Moss")
            if mt then (mt :: BasePart).Color = MOSS:Lerp(LICHEN[vr:NextInteger(1, #LICHEN)], vr:NextNumber(0, 0.5)) end
            if not glow then
                local t = m:FindFirstChild("Glow")
                if t then t:Destroy(); n -= 1 end
            end
        end
    end
    local function Roots(at: Vector3, w: number)
        local m = Kit("Roots", at - Vector3.new(0, 0.12, 0), w, nil, nil, nil, true)
        local r = m and m:FindFirstChild("Root")
        if r then (r :: BasePart).Color = C3(34, 26, 28) end
    end
    -- MYCELIUM BED along the wall: mud, clusters + mycena on mats, one teal light, mist, threads out across the floor
    local lit = false
    local function Bed(b0: Vector3, b1: Vector3, o: Vector3, clusters: number, mycena: boolean)
        local d = Vector3.new(b1.X - b0.X, 0, b1.Z - b0.Z)
        local len, u = d.Magnitude, d.Unit
        local mid = Vector3.new((b0.X + b1.X) / 2, F, (b0.Z + b1.Z) / 2)
        if ctx.Terrain then
            for k = 0, math.max(1, math.floor(len / 10)) do
                local q = b0:Lerp(b1, k / math.max(1, math.floor(len / 10)))
                Paint(q.X, q.Z, vr:NextNumber(4.5, 6.5), M.Mud, vr)
            end
        end
        for c = 1, clusters do
            local at = b0:Lerp(b1, (c - 0.5) / clusters + vr:NextNumber(-0.06, 0.06)) + o * vr:NextNumber(0.8, 2.2)
            local base = Vector3.new(at.X, F, at.Z)
            Mat(base - o * 1.5, vr:NextNumber(10, 13), c % 2 == 1)
            Cluster(base, vr:NextNumber(8.5, 11), (c == 2) and VIOLET or TEAL)
            if mycena then
                local side = vr:NextNumber() < 0.5 and -1 or 1
                Mycena(base + u * side * vr:NextNumber(5, 6.5) - o * vr:NextNumber(1.5, 3), vr:NextNumber(3, 4))
            end
            if Lava then Lava.Glow(fx, base + Vector3.new(0, 5, 0) - o * 1.5, 16, TEAL, 0.55, { Name = "GillGlow", MaxDistance = 500 }) end
        end
        if not lit then
            lit = true
            local c = A.Carrier(fx, "MyceliumLight", Vector3.new(1, 1, 1), CFrame.new(mid + Vector3.new(0, 3, 0) - o * 3))
            local l = Instance.new("PointLight")
            l.Color = C3(110, 240, 220); l.Range = 28; l.Brightness = 1.1; l.Shadows = false
            l.Parent = c
        end
        Emitter(fx, "BedMist", CFrame.lookAt(mid + Vector3.new(0, 0.6, 0), mid + Vector3.new(0, 0.6, 0) + u), Vector3.new(5, 0.2, len), {
            Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(120, 150, 170)), LightInfluence = 0.7,
            Rate = math.clamp(len / 22, 1, 2.5), Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(0.3, 0.8), EmissionDirection = Enum.NormalId.Top,
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.84), NumberSequenceKeypoint.new(1, 1) }) })
        local al = Vector3.new(-o.Z, 0, o.X)
        for _ = 1, vr:NextInteger(3, 4) do
            local s = b0:Lerp(b1, vr:NextNumber(0.05, 0.95)) - o * 3
            A.Cracks(fx, P, ctx, vr, s, -o + al * vr:NextNumber(-0.7, 0.7), vr:NextNumber(0.7, 1.1),
                { Neon = true, Hot = TEAL, Dark = TEAL_DEEP, HotT = 0.3, DarkT = 0.5, HotShare = 0.35, Wall = o, Reach = 42, Limit = 9, Y = 0.1 })
        end
    end
    -- (A.PaintField on its own stream: the floor broken into drifting fields -- mud, earth, dark teal moss (leafy + grass
    -- blades on High) and lichen-grey pebble -- 0 parts; Slate stays the rims' stone)
    if A.PaintField then
        A.PaintField(P, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.Mud, 28 }, { M.Ground, 24 }, { M.LeafyGrass, 26 }, { M.Grass, 12 }, { M.Pebble, 10 } },
            { Scale = 18, Stretch = 1.6, Warp = 10, Edge = 0.3 })
    elseif ctx.Terrain then
        for _ = 1, 7 do
            local p = P.Spot(8)
            Paint(p.X, p.Z, vr:NextNumber(7, 12), (vr:NextNumber() < 0.6) and M.LeafyGrass or M.Mud, vr)
        end
    end
    local isBand = {}
    for wi, sd in ipairs(P.walls) do
        local b0, b1 = P.Band(sd, 4, 18)
        if b0 then
            isBand[sd] = true
            Bed(b0, b1, P.SIDES[sd], wi == 1 and 3 or 2, wi == 1)
        end
    end
    -- THE OPEN FLOOR (< 0.6 stud, no collision): mud / slate fields, mycelium mats, lichen rosettes, puffballs, mycena tufts
    for i = 1, 5 do
        local p = P.Spot(10)
        if not P.DoorNear(p, 12) then
            Mat(p, vr:NextNumber(9, 14), i <= 2)
            if i == 1 and Lava then Lava.Glow(fx, p + Vector3.new(0, 0.8, 0), 7, TEAL, 0.72, { Name = "MatGlow", MaxDistance = 300 }) end
        end
    end
    for _ = 1, 3 do
        local p = P.Spot(12)
        if not P.DoorNear(p, 12) then Roots(p, vr:NextNumber(9, 13)) end
    end
    for _ = 1, 4 do
        local p = P.Spot(10)
        if not P.DoorNear(p, 10) then
            local m = Kit("Lichen", p, vr:NextNumber(5, 8), nil, nil, nil, true)
            if m then for _, q in ipairs(m:GetDescendants()) do if q:IsA("BasePart") then q.Color = LICHEN[vr:NextInteger(1, #LICHEN)] end end end
        end
    end
    for _ = 1, 2 do -- glowing mycena tufts out on the floor
        local p = P.Spot(10)
        if not P.DoorNear(p, 10) then Mycena(p, vr:NextNumber(2.4, 3.2)) end
    end
    for _, sd in ipairs(P.order) do -- mycena tufts at the feet of the walls without a bed
        if not isBand[sd] then
            local o, al = P.SIDES[sd], P.Along(sd)
            for _ = 1, 1 do
                local q = C0 + o * (half - 3) + al * vr:NextNumber(-0.75, 0.75) * half
                if not P.DoorNear(q, 14) then Mycena(Vector3.new(q.X, F, q.Z), vr:NextNumber(2.6, 3.4)) end
            end
        end
    end
    -- EDGE: giant mushrooms rooted below the rim, leaning over the room
    local giants = 0
    local tries = {}
    for _, sd in ipairs(P.order) do for _, f in ipairs({ vr:NextNumber(-0.55, 0.55), vr:NextNumber(-0.6, 0.6) }) do table.insert(tries, { sd, f }) end end
    local usedSide = {}
    for _, tr in ipairs(tries) do
        if giants >= 2 then break end
        local sd = tr[1]
        local o, al = P.SIDES[sd], P.Along(sd)
        local at = C0 + o * (half + 3) + al * tr[2] * half -- (PlaceModel centres the leaning model's box here)
        if not usedSide[sd] and not P.DoorNear(at, 20) then
            usedSide[sd] = true
            giants += 1
            local lean = math.rad(vr:NextNumber(14, 22))
            local axis = (Vector3.yAxis * math.cos(lean) - o * math.sin(lean)).Unit
            local h = vr:NextNumber(40, 50)
            local base = Vector3.new(at.X, F - 12, at.Z)
            local m = Kit((giants == 1) and "GiantA" or "GiantB", base, h, axis, CAPS[vr:NextInteger(1, #CAPS)], TEAL)
            if not m then
                Shroom(Vector3.new(at.X, F - 8, at.Z), h * 0.75, h * 0.5, TEAL)
            end
            local top = RolePos(m, "Cap") or (base + axis * h * 0.82)
            if Lava then Lava.Glow(fx, top, h * 0.55, TEAL, 0.62, { Name = "GiantGlow", MaxDistance = 800 }) end
            Emitter(fx, "SporeFall", CFrame.new(top - axis * 2), Vector3.new(h * 0.35, 0.3, h * 0.35), {
                Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(TEAL), LightEmission = 1, LightInfluence = 0,
                Rate = 3, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0.3, 0.8), EmissionDirection = Enum.NormalId.Bottom,
                Acceleration = Vector3.new(0, -0.6, 0), SpreadAngle = Vector2.new(30, 30),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.3), NumberSequenceKeypoint.new(1, 0) }) })
        end
    end
    -- EDGE: spore strands spun across one corner, above head height (beams between attachments on one carrier)
    do
        local sdA = P.order[1]
        local sdB = (sdA <= 2) and 3 or 1
        local oA, oB = P.SIDES[sdA], P.SIDES[sdB]
        local corner = C0 + oA * half + oB * half
        if not P.DoorNear(corner, 26) then
            local hub = corner - (oA + oB) * 10 + Vector3.new(0, 16, 0)
            local car = A.Carrier(fx, "SporeWeb", Vector3.new(1, 1, 1), CFrame.new(hub))
            local function Att(p: Vector3): Attachment
                local a = Instance.new("Attachment")
                a.WorldPosition = p
                a.Parent = car
                return a
            end
            local function Strand(a0: Attachment, a1: Attachment, w: number)
                local b = Instance.new("Beam")
                b.Attachment0 = a0; b.Attachment1 = a1
                b.Width0 = w; b.Width1 = w; b.FaceCamera = true; b.Segments = 1
                b.Color = ColorSequence.new(C3(220, 205, 255)); b.LightEmission = 0.35; b.LightInfluence = 0.6
                b.Transparency = NumberSequence.new(0.45)
                b.Parent = car
            end
            local center = Att(hub)
            local anchors = {
                corner + Vector3.new(0, 26, 0), corner + Vector3.new(0, 9, 0),
                corner - oA * 26 + Vector3.new(0, 22, 0), corner - oB * 26 + Vector3.new(0, 22, 0),
                corner - oA * 18 + Vector3.new(0, 8, 0), corner - oB * 18 + Vector3.new(0, 8, 0),
            }
            local rings = { {}, {} }
            for _, pnt in ipairs(anchors) do
                local a = Att(pnt)
                Strand(center, a, 0.12)
                for ri, f in ipairs({ 0.38, 0.7 }) do table.insert(rings[ri], Att(hub:Lerp(pnt, f))) end
            end
            local ord = { 1, 3, 5, 6, 4, 2 } -- (round the corner, top to top)
            for ri = 1, 2 do
                for k = 1, #ord - 1 do Strand(rings[ri][ord[k]], rings[ri][ord[k + 1]], 0.08) end
            end
        end
    end
    -- SET PIECE: a FALLEN GIANT along a wall foot, cap against the wall, gills turned to the room
    do
        local sd, spot = P.SetSpot(30, 10, isBand)
        if sd and spot then
            local o, al = P.SIDES[sd], P.Along(sd)
            local _ = vr:NextNumber() -- (kept: the draw the old random side used)
            local at0 = Vector3.new(spot.X, F, spot.Z) + o * 2
            -- the cap end toward the nearer corner, the stem's foot toward the room's middle (a foot toward the corner
            -- stuck out past the room over the drop); the whole piece shifted toward the middle along the wall
            local toward = (al:Dot(C0 - at0) >= 0) and 1 or -1
            local side = -toward
            local at = at0 + al * toward * 5
            if ctx.Terrain then Paint(at.X - o.X * 4, at.Z - o.Z * 4, 16, M.Mud, vr) end
            -- lying along the wall (cap end at +side), turned 28 degrees so the cap leans into the wall foot and the
            -- gills face the room, the stem's foot on the ground
            -- (pitched up 20 degrees toward the cap: the cap is far wider than the stem, so a level one floated its stem in the air)
            local flat = (al * side * math.cos(math.rad(28)) + o * math.sin(math.rad(28))).Unit
            local axis = (flat * math.cos(math.rad(20)) + Vector3.yAxis * math.sin(math.rad(20))).Unit
            local L = vr:NextNumber(20, 23)
            local fallen = Kit("GiantA", at, L, axis, CAPS[1], TEAL)
            local capAt = RolePos(fallen, "Cap") or (at + axis * L * 0.38 + Vector3.new(0, L * 0.18, 0))
            if not fallen then
                Shroom(at, 8, 9, TEAL)
                capAt = at + Vector3.new(0, 8, 0)
            else
                -- bracket fungi up the fallen stem, a cluster sprouting at its base, a mat under it
                Kit("Shelf", at - axis * L * 0.12 - o * 2.6, vr:NextNumber(3.5, 4.5), nil, nil, TEAL)
                Cluster(Vector3.new(at.X, F, at.Z) - axis * L * 0.42 - o * 4, vr:NextNumber(5, 6.5), TEAL)
                Mat(Vector3.new(at.X, F, at.Z) - o * 5, 14, true)
            end
            if Lava then Lava.Glow(fx, capAt - o * 3, 15, TEAL, 0.68, { Name = "FallenGlow", MaxDistance = 800 }) end
            local c = A.Carrier(fx, "FallenLight", Vector3.new(1, 1, 1), CFrame.new(capAt - o * 7))
            local l = Instance.new("PointLight")
            l.Color = C3(110, 240, 220); l.Range = 30; l.Brightness = 1.2; l.Shadows = false
            l.Parent = c
            Emitter(fx, "FallenSpores", CFrame.new(capAt - o * 3), Vector3.new(6, 2, 6), {
                Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(TEAL, C3(180, 255, 240)), LightEmission = 1, LightInfluence = 0,
                Rate = 6, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(1, 2.5), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40),
                Acceleration = Vector3.new(0, -0.15, 0),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.4, 0.5), NumberSequenceKeypoint.new(1, 0) }) })
        end
    end
    -- DRIFT: a low violet spore haze + glowing teal spores
    Emitter(fx, "SporeHaze", CFrame.new(C0 + Vector3.new(0, 0.9, 0)), Vector3.new(half * 1.7, 0.3, half * 1.7), {
        Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(110, 96, 150)), LightInfluence = 0.8,
        Rate = 3, Lifetime = NumberRange.new(9, 13), Speed = NumberRange.new(0.5, 1.2), SpreadAngle = Vector2.new(80, 5),
        EmissionDirection = Enum.NormalId.Front,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 13) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.88), NumberSequenceKeypoint.new(1, 1) }) })
    Emitter(fx, "BigSpores", CFrame.new(C0 + Vector3.new(0, 5, 0)), Vector3.new(half * 1.6, 6, half * 1.6), {
        Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(TEAL, C3(160, 255, 235)), LightEmission = 1, LightInfluence = 0,
        Rate = 4, Lifetime = NumberRange.new(7, 11), Speed = NumberRange.new(0.2, 0.6), SpreadAngle = Vector2.new(180, 180),
        Acceleration = Vector3.new(0, 0.1, 0),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0) }) })
    return n
end

return B
