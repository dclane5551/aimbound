--!strict
-- ROOM ATMOSPHERE PASS 2 -- BAYOU v2 (the Haunted Bayou world; RoomAtmo API: see RoomAtmo "ATMOSPHERE PASS 2"). Its own
-- treatment. v1 read as "a flat, empty, dark-green plain with an acid green glow" (coordinator review vs the reference bog:
-- "desaturated blue-grey with black water and a tangle of dead branches and roots across the ground"), so v2:
--   CONTRAST  Light: the dim day sun x0.75, the green pulled OUT of ambient / outdoor (cold grey-blue), grade + fog toward a
--             cold grey-blue mist; palette: mud / grass / ground desaturated toward grey-blue; parts x0.75. Green is only the
--             accent: the wisps.
--   GROUND    BLACK WATER at the wall foot (still glossy strip, a faint cold scum edge, lily pads, a cold glow, wisps over
--             it, one cold PointLight) AND across the open floor: a winding black-water channel or two and puddle clusters
--             (overlapping glossy ellipses: shallow, walkable, no collision). Ground cover all over: fallen dead branches
--             (with a fork), roots, reed tufts (terrain grass patches at the water's edges -- the terrain's own grass blades,
--             0 parts), a grave cluster in the mud.
--   WALKWAY   a rotten plank boardwalk that LEADS somewhere: from one doorway, past the set piece, to the other doorway (or
--             the room's middle), on short posts, a few planks missing.
--   EDGE      BIG DEAD TREES standing in the rim, leaning in, their long forked branches reaching over the room edge, grey
--             moss hanging off them
--   SET PIECE a SUNKEN SHACK (planks, built here) listing into black water at a wall, its stilts broken, a lantern still lit
--   DRIFT     low cold mist creeping across the whole floor
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.75, Ambient = Color3.new(0.92, 0.8, 1.06), Outdoor = Color3.new(0.9, 0.79, 1.04),
    Tint = C3(192, 206, 228), TintAmt = 0.45, FogColor = C3(66, 76, 90), FogEnd = 0.8 }
-- (the floor read as a near-black plain where black water can't show: the mud is LIFTED to a cold grey -- the reference
-- bog is mid grey-blue ground with black water in it -- and the green pulled out of everything)
B.Palette = { Dim = 0.8, Mats = {
    [M.Mud] = Color3.new(1.5, 1.45, 1.9), [M.Grass] = Color3.new(1.02, 0.9, 1.12), [M.LeafyGrass] = Color3.new(1.02, 0.9, 1.12),
    [M.Ground] = Color3.new(1.4, 1.45, 1.85), [M.Rock] = Color3.new(1, 1, 1.12) },
    Base = { [M.Slate] = C3(72, 76, 82), [M.LeafyGrass] = C3(62, 72, 56) } } -- (the floor field's puddle-rim slate + leafy patches)
B.Atmo = { Color = C3(122, 132, 146), Decay = C3(44, 50, 60) } -- (the world's haze is green: a cold grey-blue one)
B.Look = { Sig = C3(150, 174, 192), Mote2 = C3(184, 200, 214) } -- (pass 1's light pools + air were acid green: cold grey-blue)
B.Trail = M.Mud -- (pass 1's worn trail between the doors is terrain wood planks with jagged edges: the boardwalk replaces it)
B.PartDim = 0.75

local WATER, WOOD, WOOD_DARK = C3(9, 11, 14), C3(84, 74, 62), C3(56, 50, 44)
local DEAD, MOSS = C3(56, 53, 50), C3(96, 102, 96)
local COLD = C3(150, 172, 190)
local WISP = C3(140, 220, 130)

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Part, Paint, Emitter = A.Part, A.Paint, A.Emitter
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    -- FLOOR FIELD (terrain paint, 0 parts): the whole open floor in big irregular blobs / drifts of the biome's ground
    -- materials (A.PaintField; its own Random so the room's other draws -- the layout -- stay where they were). The big
    -- round field blobs below only draw their numbers when the field ran.
    local field = A.PaintField(P, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.Mud, 35 }, { M.Ground, 25 }, { M.Grass, 20 }, { M.LeafyGrass, 12 }, { M.Slate, 8 } }, { Scale = 20, Stretch = 1.8 }) > 0
    local rimR = Random.new((ctx.Seed or 1) + 7718)
    local function FieldPaint(x: number, z: number, r: number, mat: Enum.Material, rr: Random)
        if field then rr:NextNumber(0, math.pi * 2) else Paint(x, z, r, mat, rr) end
    end
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    local lit = false
    local function Flat(v: Vector3): Vector3 return Vector3.new(v.X, F, v.Z) end
    -- a glossy black ellipse lying on the floor (water never a rectangle on the open floor)
    local function Pool(name: string, at: Vector3, rx: number, rz: number, yaw: number, deep: number?): BasePart
        -- (a Cylinder part's disc is a CIRCLE of the smaller size: a block + a Cylinder SpecialMesh stretches to a true ellipse)
        local t = deep or 0.12
        local p = Part(fx, name, nil, Vector3.new(t, rx * 2, rz * 2), CFrame.new(Flat(at) + Vector3.new(0, 0.13 - t / 2, 0)) * CFrame.Angles(0, yaw, math.rad(90)), WATER, M.SmoothPlastic)
        if field and rx < 8 then Paint(at.X, at.Z, math.max(rx, rz) + 2.5, M.Slate, rimR) end -- (a slate rim round the water)
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.Cylinder
        mesh.Parent = p
        p.Reflectance = 0.36; p.CastShadow = false
        n += 1
        return p
    end
    -- BLACK WATER at the wall foot: a still glossy strip, a faint cold scum edge, lily pads, a cold glow, wisps, mist
    local function Water(b0: Vector3, b1: Vector3, w: number, o: Vector3)
        local d = Vector3.new(b1.X - b0.X, 0, b1.Z - b0.Z)
        local len, u = d.Magnitude, d.Unit
        local mid = Vector3.new((b0.X + b1.X) / 2, F, (b0.Z + b1.Z) / 2)
        local cf = CFrame.lookAt(mid, mid + u)
        local wat = Part(fx, "BlackWater", nil, Vector3.new(w, 0.2, len), cf * CFrame.new(0, 0.08, 0), WATER, M.SmoothPlastic)
        wat.Reflectance = 0.4; wat.CastShadow = false
        local scum = Part(fx, "ScumLine", nil, Vector3.new(0.4, 0.06, len - 1), cf * CFrame.new(cf:VectorToObjectSpace(-o).X * (w / 2 - 0.3), 0.2, 0), C3(96, 112, 110), M.Neon)
        scum.Transparency = 0.7; scum.CastShadow = false
        n += 2
        -- wisps: the green accent, a few motes drifting over the water
        Emitter(fx, "Wisps", CFrame.lookAt(mid + Vector3.new(0, 2, 0), mid + Vector3.new(0, 2, 0) + u), Vector3.new(w, 2, len), {
            Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(WISP, C3(210, 255, 160)), LightEmission = 1, LightInfluence = 0,
            Rate = 3, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0.3, 0.9), SpreadAngle = Vector2.new(180, 180),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) }) })
        if ctx.Terrain then
            -- reed tufts along the room-side bank (terrain grass: its own blades, no parts) on mud
            for k = 0, 3 do
                local q = b0:Lerp(b1, (k + vr:NextNumber(0.1, 0.9)) / 4) - o * (w / 2 + vr:NextNumber(1.5, 3))
                Paint(q.X, q.Z, vr:NextNumber(4, 6), M.Mud, vr)
                Paint(q.X + vr:NextNumber(-1.5, 1.5), q.Z + vr:NextNumber(-1.5, 1.5), vr:NextNumber(1.8, 2.8), M.Grass, vr)
            end
        end
        for _ = 1, 2 do
            local q = b0:Lerp(b1, vr:NextNumber(0.05, 0.95)) + o * vr:NextNumber(-w / 2 + 1, w / 2 - 1)
            local r = vr:NextNumber(0.8, 1.3)
            local pad = Part(fx, "LilyPad", Enum.PartType.Cylinder, Vector3.new(0.08, r * 2, r * 2), CFrame.new(q + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), math.rad(90)), C3(52, 66, 50), M.SmoothPlastic)
            pad.CastShadow = false
            n += 1
        end
        if Lava then
            for g = 1, math.max(1, math.floor(len / 30)) do
                Lava.Glow(fx, b0:Lerp(b1, (g - 0.5) / math.max(1, math.floor(len / 30))) + Vector3.new(0, F + 1.2 - b0.Y, 0), 22, COLD, 0.6, { Name = "SwampGlow", MaxDistance = 400 })
            end
        end
        if not lit then
            lit = true
            local c = A.Carrier(fx, "WispLight", Vector3.new(1, 1, 1), CFrame.new(mid + Vector3.new(0, 2.5, 0)))
            local l = Instance.new("PointLight")
            l.Color = C3(170, 196, 214); l.Range = 26; l.Brightness = 0.75; l.Shadows = false
            l.Parent = c
            n += 1
        end
        Emitter(fx, "WaterMist", CFrame.lookAt(mid + Vector3.new(0, 0.5, 0), mid + Vector3.new(0, 0.5, 0) + u), Vector3.new(w, 0.2, len), {
            Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(160, 172, 186)), LightInfluence = 1,
            Rate = math.clamp(len / 16, 1.5, 4), Lifetime = NumberRange.new(7, 11), Speed = NumberRange.new(0.3, 0.8), EmissionDirection = Enum.NormalId.Top,
            Acceleration = Vector3.new(0, -0.05, 0),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 10) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 1) }) })
    end
    local isBand = {}
    local bands = {}
    for wi, sd in ipairs(P.walls) do
        local b0, b1 = P.Band(sd, 4.5, 18)
        if b0 then
            isBand[sd] = true
            Water(b0, b1, wi == 1 and 7 or 5.5, P.SIDES[sd])
            table.insert(bands, { b0, b1, P.SIDES[sd] })
        end
    end
    -- THE OPEN FLOOR: mud fields (no big grass: the plain read dark green), black-water channels + puddle clusters
    if ctx.Terrain then
        for _ = 1, vr:NextInteger(4, 6) do
            local p = P.Spot(12)
            FieldPaint(p.X, p.Z, vr:NextNumber(9, 15), ({ M.Mud, M.Mud, M.Ground })[vr:NextInteger(1, 3)], vr)
        end
    end
    -- a winding channel: from a wall-foot water band out into the room (else from an open spot), overlapping ellipses
    local reedAt = {}
    for c = 1, 2 do
        local at: Vector3, dir: Vector3
        local bd = bands[c]
        if bd then
            at = bd[1]:Lerp(bd[2], vr:NextNumber(0.25, 0.75)) - bd[3] * 4
            dir = -bd[3]
        else
            at = P.Spot(16)
            local a = vr:NextNumber(0, math.pi * 2)
            dir = Vector3.new(math.cos(a), 0, math.sin(a))
        end
        for _ = 1, vr:NextInteger(6, 8) do
            local rel = at - C0
            if math.abs(rel.X) > half - 4 or math.abs(rel.Z) > half - 4 or P.DoorNear(at, 10) then break end
            Pool("BlackChannel", at, vr:NextNumber(2.4, 3.4), vr:NextNumber(4, 5.5), math.atan2(dir.X, dir.Z) + vr:NextNumber(-0.3, 0.3))
            if vr:NextNumber() < 0.35 then table.insert(reedAt, at + Vector3.new(-dir.Z, 0, dir.X) * (vr:NextNumber() < 0.5 and -3.5 or 3.5)) end
            if ctx.Terrain and vr:NextNumber() < 0.5 then
                local side = Vector3.new(-dir.Z, 0, dir.X) * (vr:NextNumber() < 0.5 and -1 or 1)
                local q = at + side * vr:NextNumber(3.5, 5)
                Paint(q.X, q.Z, vr:NextNumber(1.6, 2.4), M.Grass, vr)
            end
            dir = (CFrame.Angles(0, vr:NextNumber(-0.55, 0.55), 0) * CFrame.new(Vector3.zero, dir)).LookVector
            at += dir * vr:NextNumber(4.5, 6)
        end
    end
    for _ = 1, vr:NextInteger(3, 4) do
        local p = P.Spot(10)
        if not P.DoorNear(p, 10) then
            Pool("BlackPuddle", p, vr:NextNumber(2.6, 4.5), vr:NextNumber(1.8, 3), vr:NextNumber(0, 6.28))
            Pool("BlackPuddle", p + Vector3.new(vr:NextNumber(-3.5, 3.5), 0, vr:NextNumber(-3.5, 3.5)), vr:NextNumber(1.4, 2.4), vr:NextNumber(1, 1.8), vr:NextNumber(0, 6.28))
            if vr:NextNumber() < 0.5 then table.insert(reedAt, p + Vector3.new(vr:NextNumber(-4, 4), 0, vr:NextNumber(-4, 4))) end
        end
    end
    -- reed clumps at the water's edges: a few thin dry stalks leaning every way
    for i, q in ipairs(reedAt) do
        if i > 4 then break end
        if not P.DoorNear(q, 8) then
            for _ = 1, 2 do
                local h = vr:NextNumber(2, 3.6)
                local a = vr:NextNumber(0, math.pi * 2)
                local ax = (Vector3.yAxis + Vector3.new(math.cos(a), 0, math.sin(a)) * vr:NextNumber(0.1, 0.4)).Unit
                local b0 = Flat(q) + Vector3.new(vr:NextNumber(-0.6, 0.6), 0, vr:NextNumber(-0.6, 0.6))
                Part(fx, "Reed", Enum.PartType.Cylinder, Vector3.new(h, 0.16, 0.16), CFrame.fromMatrix(b0 + ax * h / 2, ax, ax:Cross(Vector3.xAxis).Unit), C3(104, 102, 86), M.Grass).CastShadow = false
                n += 1
            end
        end
    end
    -- ground cover: fallen dead branches (a fork each) and roots lying in the mud
    for _ = 1, vr:NextInteger(5, 6) do
        local p = P.Spot(8)
        if not P.DoorNear(p, 10) then
            local a = vr:NextNumber(0, math.pi * 2)
            local d = Vector3.new(math.cos(a), vr:NextNumber(-0.04, 0.06), math.sin(a)).Unit
            local L = vr:NextNumber(5, 9)
            local th = vr:NextNumber(0.35, 0.55)
            local s0 = Flat(p) + Vector3.new(0, th / 2, 0)
            local up = d:Cross(Vector3.yAxis).Unit
            Part(fx, "DeadBranch", Enum.PartType.Cylinder, Vector3.new(L, th, th), CFrame.fromMatrix(s0 + d * L / 2, d, up), DEAD, M.Wood).CastShadow = false
            local fk = (CFrame.Angles(0, vr:NextNumber(0.5, 0.9) * (vr:NextNumber() < 0.5 and -1 or 1), 0) * CFrame.new(Vector3.zero, d)).LookVector
            local fl = vr:NextNumber(2.5, 4)
            local f0 = s0 + d * L * vr:NextNumber(0.45, 0.75)
            Part(fx, "DeadBranch", Enum.PartType.Cylinder, Vector3.new(fl, th * 0.65, th * 0.65), CFrame.fromMatrix(f0 + fk * fl / 2, fk, fk:Cross(Vector3.yAxis).Unit), DEAD, M.Wood).CastShadow = false
            n += 2
        end
    end
    for _ = 1, vr:NextInteger(2, 3) do
        local p = P.Spot(8)
        if not P.DoorNear(p, 10) then
            local L = vr:NextNumber(6, 10)
            local root = Part(fx, "Root", Enum.PartType.Cylinder, Vector3.new(L, vr:NextNumber(0.5, 0.75), vr:NextNumber(0.5, 0.75)),
                CFrame.new(Flat(p) - Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), math.rad(vr:NextNumber(-3, 3))), WOOD_DARK, M.Wood)
            root.CastShadow = false
            n += 1
        end
    end
    -- grave markers: a small cluster in the mud near one wall (crosses and leaning slabs)
    do
        local sd = P.order[vr:NextInteger(1, 4)]
        local o = P.SIDES[sd]
        local al = P.Along(sd)
        local c = C0 + o * (half - 9) + al * vr:NextNumber(-0.5, 0.5) * half
        if not P.DoorNear(c, 18) then
            if ctx.Terrain then Paint(c.X, c.Z, 8, M.Mud, vr) end
            for k = 1, vr:NextInteger(3, 4) do
                local q = c + al * ((k - 2.5) * 2.6 + vr:NextNumber(-0.6, 0.6)) + o * vr:NextNumber(-2, 2)
                local tilt = CFrame.Angles(math.rad(vr:NextNumber(-12, 12)), vr:NextNumber(-0.4, 0.4), math.rad(vr:NextNumber(-12, 12)))
                local face = CFrame.lookAt(Vector3.new(q.X, F, q.Z), Vector3.new(q.X, F, q.Z) - o)
                if vr:NextNumber() < 0.5 then
                    local h = vr:NextNumber(2.4, 3.4)
                    local post = face * tilt * CFrame.new(0, h / 2 - 0.4, 0)
                    Part(fx, "GraveCross", nil, Vector3.new(0.45, h, 0.45), post, WOOD_DARK, M.Wood)
                    Part(fx, "GraveCrossBar", nil, Vector3.new(1.8, 0.4, 0.4), post * CFrame.new(0, h * 0.22, 0), WOOD_DARK, M.Wood)
                    n += 2
                else
                    local h = vr:NextNumber(1.8, 2.8)
                    Part(fx, "GraveSlab", nil, Vector3.new(1.7, h, 0.45), face * tilt * CFrame.new(0, h / 2 - 0.5, 0), C3(84, 88, 92), M.Slate)
                    n += 1
                end
            end
        end
    end
    -- EDGE: big dead trees standing in the rim, leaning in, long forked branches reaching over the room edge, grey moss
    local trees = 0
    for _, sd in ipairs(P.order) do
        if trees >= 2 then break end
        local o = P.SIDES[sd]
        local al = P.Along(sd)
        local at = C0 + o * (half + 5) + al * vr:NextNumber(-0.55, 0.55) * half
        if not P.DoorNear(at, 22) then
            trees += 1
            local h = vr:NextNumber(32, 40)
            local lean = math.rad(vr:NextNumber(12, 20))
            local axis = (Vector3.yAxis * math.cos(lean) - o * math.sin(lean)).Unit
            local base = Vector3.new(at.X, F - 2, at.Z)
            Part(fx, "DeadTreeTrunk", Enum.PartType.Cylinder, Vector3.new(h, 3.8, 3.8), CFrame.fromMatrix(base + axis * h / 2, axis, al), DEAD, M.Wood)
            n += 1
            for b = 1, 4 do
                local from = base + axis * h * vr:NextNumber(0.5, 0.92)
                -- most branches reach IN over the room edge, a couple out / along the rim
                local inward = b <= 3
                local hor = inward and (-o + al * vr:NextNumber(-0.7, 0.7)) or (al * (vr:NextNumber() < 0.5 and -1 or 1) + o * 0.3)
                local bd = (hor.Unit * 0.85 + Vector3.yAxis * vr:NextNumber(0.25, 0.65)).Unit
                local bl = inward and vr:NextNumber(13, 19) or vr:NextNumber(8, 12)
                local th = inward and 1.2 or 0.9
                local bup = bd:Cross(Vector3.yAxis).Magnitude > 0.1 and bd:Cross(Vector3.yAxis).Unit or o
                Part(fx, "DeadTreeBranch", Enum.PartType.Cylinder, Vector3.new(bl, th, th), CFrame.fromMatrix(from + bd * bl / 2, bd, bup), DEAD, M.Wood)
                n += 1
                if inward then
                    -- a fork near the tip, drooping
                    local f0 = from + bd * bl * vr:NextNumber(0.55, 0.75)
                    local fk = (CFrame.Angles(0, vr:NextNumber(0.4, 0.8) * (vr:NextNumber() < 0.5 and -1 or 1), 0) * CFrame.new(Vector3.zero, Vector3.new(bd.X, 0, bd.Z))).LookVector
                    fk = (fk - Vector3.yAxis * vr:NextNumber(0.1, 0.4)).Unit
                    local fl = vr:NextNumber(5, 8)
                    Part(fx, "DeadTreeBranch", Enum.PartType.Cylinder, Vector3.new(fl, 0.6, 0.6), CFrame.fromMatrix(f0 + fk * fl / 2, fk, fk:Cross(Vector3.yAxis).Unit), DEAD, M.Wood)
                    local mp = from + bd * bl * vr:NextNumber(0.6, 0.95)
                    local ml = vr:NextNumber(5, 9)
                    local moss = Part(fx, "HangingMoss", nil, Vector3.new(0.7, ml, 0.3), CFrame.new(mp - Vector3.new(0, ml / 2, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0), MOSS, M.Grass)
                    moss.CastShadow = false
                    n += 2
                end
            end
        end
    end
    -- SET PIECE: a sunken shack listing into black water at a wall, its lantern still lit
    local front: Vector3? = nil
    do
        local sd, spot = P.SetSpot(26, 7, isBand)
        if sd and spot then
            local o = P.SIDES[sd]
            spot = Flat(spot)
            front = spot - o * 14
            Pool("ShackWater", spot - o * 2, 14, 10, math.atan2(o.X, o.Z) + math.rad(90), 2.6)
            -- (built from parts, not the world's shack mesh: that one is a single textured mesh in bright village paint,
            -- and a texture can't be darkened from a script)
            local at = spot + o * 3
            local cf = CFrame.lookAt(Vector3.new(at.X, F + 2.2, at.Z), Vector3.new(at.X, F + 2.2, at.Z) - o)
                * CFrame.Angles(math.rad(vr:NextNumber(-5, 5)), vr:NextNumber(-0.3, 0.3), math.rad(vr:NextNumber(9, 14)) * (vr:NextNumber() < 0.5 and -1 or 1))
            local W, D, H = 16, 13, 10
            local plank, roofC = C3(66, 58, 50), C3(46, 42, 40)
            Part(fx, "ShackFront", nil, Vector3.new(W, H, 0.8), cf * CFrame.new(0, 0, -D / 2), plank, M.WoodPlanks)
            Part(fx, "ShackBack", nil, Vector3.new(W, H, 0.8), cf * CFrame.new(0, 0, D / 2), plank, M.WoodPlanks)
            Part(fx, "ShackSide", nil, Vector3.new(0.8, H, D), cf * CFrame.new(-W / 2, 0, 0), plank, M.WoodPlanks)
            Part(fx, "ShackSide", nil, Vector3.new(0.8, H * 0.7, D), cf * CFrame.new(W / 2, -H * 0.15, 0) * CFrame.Angles(0, 0, math.rad(-8)), plank, M.WoodPlanks)
            for side = -1, 1, 2 do
                Part(fx, "ShackRoof", nil, Vector3.new(W + 2, 0.8, D * 0.62), cf * CFrame.new(0, H / 2 + 1.9, side * D * 0.25) * CFrame.Angles(math.rad(32) * side, 0, 0), roofC, M.WoodPlanks)
            end
            local win = Part(fx, "ShackWindow", nil, Vector3.new(2.6, 2.2, 0.2), cf * CFrame.new(-2.5, 1, -D / 2 - 0.45), C3(255, 196, 120), M.Neon)
            win.Transparency = 0.25; win.CastShadow = false
            Part(fx, "ShackDoor", nil, Vector3.new(3.4, 6, 0.3), cf * CFrame.new(3.5, -1.8, -D / 2 - 0.55) * CFrame.Angles(0, math.rad(25), 0), C3(40, 36, 32), M.Wood)
            for k = 1, 3 do
                local h = vr:NextNumber(2.5, 6)
                local q = Vector3.new(at.X, F, at.Z) - o * vr:NextNumber(8, 12) + P.Along(sd) * ((k - 2) * 5 + vr:NextNumber(-1, 1))
                Part(fx, "ShackStilt", Enum.PartType.Cylinder, Vector3.new(h, 0.9, 0.9), CFrame.new(q + Vector3.new(0, h / 2 - 2, 0)) * CFrame.Angles(math.rad(vr:NextNumber(-12, 12)), 0, math.rad(90 + vr:NextNumber(-12, 12))), WOOD_DARK, M.Wood)
            end
            n += 11
            if Lava then Lava.Glow(fx, (cf * CFrame.new(-2.5, 1, -D / 2 - 1)).Position, 7, C3(255, 210, 130), 0.35, { Name = "ShackLantern", MaxDistance = 400 }) end
            local c = A.Carrier(fx, "ShackLight", Vector3.new(1, 1, 1), cf * CFrame.new(-2.5, 1, -D / 2 - 3))
            local l = Instance.new("PointLight")
            l.Color = C3(255, 200, 130); l.Range = 18; l.Brightness = 0.9; l.Shadows = false
            l.Parent = c
            n += 1
        end
    end
    -- WALKWAY: a rotten boardwalk from one doorway, past the shack, to the other doorway (or the room's middle)
    do
        local doors = P.doors or {}
        local route = {}
        local function Inside(dp: Vector3): Vector3
            local v = Flat(C0) - Flat(dp)
            return Flat(dp) + (v.Magnitude > 0.1 and v.Unit or Vector3.zero) * 9
        end
        if doors[1] then table.insert(route, Inside(doors[1])) else table.insert(route, Flat(P.Spot(14))) end
        if front then table.insert(route, front) end
        if doors[2] then table.insert(route, Inside(doors[2]))
        else table.insert(route, Flat(C0) + Vector3.new(vr:NextNumber(-8, 8), 0, vr:NextNumber(-8, 8))) end
        local seg = 0
        for i = 1, #route - 1 do
            local a, b = route[i], route[i + 1]
            local d = b - a
            local steps = math.max(1, math.floor(d.Magnitude / 9))
            local side = Vector3.new(-d.Unit.Z, 0, d.Unit.X)
            local prev = a
            for k = 1, steps do
                local q = (k == steps) and b or (a + d * (k / steps) + side * vr:NextNumber(-1.6, 1.6))
                seg += 1
                -- a few planks missing (never the first ones out of a doorway)
                if seg <= 2 or vr:NextNumber() > 0.12 then
                    local mid = (prev + q) / 2 + Vector3.new(0, 0.4 + vr:NextNumber(-0.08, 0.08), 0)
                    local cf = CFrame.lookAt(mid, mid + (q - prev).Unit) * CFrame.Angles(0, 0, math.rad(vr:NextNumber(-3, 3)))
                    Part(fx, "Boardwalk", nil, Vector3.new(3.2, 0.3, (q - prev).Magnitude + 0.6), cf, WOOD, M.WoodPlanks).CastShadow = false
                    n += 1
                    if seg % 2 == 0 then
                        for sgn = -1, 1, 2 do
                            if vr:NextNumber() < 0.4 then
                                local h = vr:NextNumber(0.9, 1.6)
                                Part(fx, "BoardwalkPost", Enum.PartType.Cylinder, Vector3.new(h, 0.45, 0.45), cf * CFrame.new(sgn * 1.75, h / 2 - 0.3, (q - prev).Magnitude / 2 - 0.4) * CFrame.Angles(0, 0, math.rad(90 + vr:NextNumber(-10, 10))), WOOD_DARK, M.Wood)
                                n += 1
                            end
                        end
                    end
                end
                prev = q
            end
        end
    end
    -- DRIFT: low cold mist creeping across the floor
    Emitter(fx, "FloorMist", CFrame.new(C0 + Vector3.new(0, 0.8, 0)), Vector3.new(half * 1.7, 0.3, half * 1.7), {
        Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(158, 170, 186)), LightInfluence = 1,
        Rate = 5, Lifetime = NumberRange.new(9, 14), Speed = NumberRange.new(0.6, 1.4), SpreadAngle = Vector2.new(80, 5),
        EmissionDirection = Enum.NormalId.Front, Acceleration = Vector3.new(0, 0, 0),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 14) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.84), NumberSequenceKeypoint.new(1, 1) }) })
    return n
end

return B
