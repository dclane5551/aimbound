--!strict
-- ROOM ATMOSPHERE PASS 2 -- JUNGLE (the Sunken Temple; RoomAtmo API: see RoomAtmo "ATMOSPHERE PASS 2"). Its own treatment
-- (reference: ferns and palms over the paths, ruins swallowed by plants, turquoise steaming springs). The plants and the
-- carved head are REAL MESHES: ReplicatedStorage.RoomAtmoKit.Jungle (tools/atmo_kit_jungle.py: arching ferns with leaflets,
-- elephant-ear undergrowth, a palm, a buttressed canopy tree with leaf-card crowns + hanging lianas, a carved temple head,
-- roots, broken paving); without the kit (an unsaved place) the plain part pieces stand in.
--   CONTRAST  Light: the sun x0.6 (the canopy shades the floor), ambient x0.94 (the gun plate stays within ~10%), a warm grade;
--             palette x0.7 (limestone x0.75),
--             parts x0.66. Shafts of sunlight through the canopy and the glowing spring water carry the light.
--   GROUND    STEAMING SPRING POOLS at the wall foot (kit Springs: irregular turquoise pools, a lighter shallow edge, dark
--             wet boulders round the rim, the glow lying under the water -- no lit edge line), ferns and broad-leaved
--             undergrowth behind them, steam rising (1 light). FERN CLUMPS along every wall foot and at the feet of the
--             cover pieces (fight lanes + doorways clear). The open floor: A.PaintField mud / grass / leaf litter / mossy
--             pebble fields, broken paving, roots snaking across -- all low, no collision.
--   EDGE      THE RIMS READ AS JUNGLE: the cliff stone darkened (palette), moss + grass painted over the exposed rock faces
--             and crests (voxels, 0 parts), VINE CURTAINS draped down the faces with ferns on the crests; CANOPY TREES
--             rooted below the rim leaning over the room, a PALM on another side; SUNBEAMS slanting down (beams, no parts)
--   SET PIECE a TOPPLED TEMPLE HEAD half sunk at a wall foot, moss on its crown, its gold eyes still lit, roots over it,
--             ferns at its chin (1 warm light)
--   DRIFT     warm humid haze low on the floor + golden pollen in the sunbeams
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.6, Ambient = 0.94, Outdoor = 0.94, Tint = C3(255, 238, 204), TintAmt = 0.28 }
B.Palette = { Dim = 0.7, Mats = { [M.Limestone] = 0.42, [M.Rock] = 0.6, [M.Pebble] = 1 }, Base = { [M.Pebble] = C3(54, 70, 44) } }
-- (coordinator: the pale beige-green cliffs were the brightest thing on screen: limestone x0.75 -> x0.42, rock x0.6)
B.PartDim = 0.66
B.SADim = 0.55 -- (the scanned boulders / busts keep their bright textures under PartDim: mapvibe's separate factor)
B.Drift = { Humid = true } -- (room 1 skips its whole-room drift: RoomAtmo.BuildRoom1)

local WATER, WATER_DEEP, SPRING = C3(52, 150, 140), C3(20, 80, 86), C3(100, 220, 200)
local STONE, LEAF, LEAF2, BARK = C3(146, 146, 120), C3(44, 82, 36), C3(64, 104, 44), C3(70, 54, 40)
local GOLD = C3(255, 200, 90)
local ROUGH = { Leaf = M.Grass, Core = M.Grass, Stem = M.Grass, Vine = M.Grass, Moss = M.Grass, Trunk = M.Wood, Root = M.Wood, Stone = M.Limestone, WetStone = M.Slate }
-- the pool layers (kit Springs): see-through water over a soft glow, a lighter shallow edge, wet stone
local POOL = { Water = { T = 0.18, R = 0.14 }, Shallow = { T = 0.3, R = 0.08 }, PoolGlow = { T = 0.7, R = 0 }, WetStone = { T = 0, R = 0.08 } }

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Part, Paint, Emitter = A.Part, A.Paint, A.Emitter
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    local kitRoot = game:GetService("ReplicatedStorage"):FindFirstChild("RoomAtmoKit")
    local KIT = kitRoot and kitRoot:FindFirstChild("Jungle")
    -- a kit piece: size = its height (byWidth: its width) in studs; up = its up axis (a lean); leaf = a leaf colour
    local function Kit(name: string, at: Vector3, size: number, up: Vector3?, leaf: Color3?, byWidth: boolean?, face: Vector3?): Model?
        local tmpl = KIT and KIT:FindFirstChild(name)
        if not (tmpl and tmpl:IsA("Model")) then return nil end
        local _, bb = tmpl:GetBoundingBox()
        local h = byWidth and size * bb.Y / math.max(bb.X, bb.Z, 0.1) or size
        local u = (up or Vector3.yAxis).Unit
        local x = Vector3.yAxis:Cross(u)
        x = (x.Magnitude > 1e-3) and x.Unit or Vector3.xAxis
        local cf = CFrame.fromMatrix(at, x, u) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0)
        if face then cf = CFrame.lookAt(at, at + face, u) end -- (kit models face -Z: their front toward `face`)
        local ok, m = pcall(A.PlaceModel, tmpl, fx, cf, h, name)
        if not ok or not m then return nil end
        if up then -- (PlaceModel seats the model-frame box: re-seat a tilted piece on its lowest world point)
            local lo = math.huge
            for _, q in ipairs(m:GetDescendants()) do
                if q:IsA("BasePart") then
                    local c, hs = q.CFrame, q.Size / 2
                    lo = math.min(lo, c.Position.Y - (math.abs(c.RightVector.Y) * hs.X + math.abs(c.UpVector.Y) * hs.Y + math.abs(c.LookVector.Y) * hs.Z))
                end
            end
            if lo < math.huge then m:PivotTo(m:GetPivot() + Vector3.new(0, at.Y - lo, 0)) end
        end
        for _, q in ipairs(m:GetDescendants()) do
            if q:IsA("BasePart") then
                n += 1
                local role = q:GetAttribute("Role")
                if q:GetAttribute("Glow") then q.CastShadow = false
                elseif ROUGH[role] then q.Material = ROUGH[role] end
                if role == "Leaf" and leaf then q.Color = leaf end
                local pl = POOL[role]
                if pl then q.Transparency = pl.T; q.Reflectance = pl.R; if pl.T > 0 then q.CastShadow = false end end
            end
        end
        return m
    end
    local function LeafCol(): Color3 return LEAF:Lerp(LEAF2, vr:NextNumber(0, 1)) end
    -- a fern clump (kit), else a few wedge fronds
    local function Fern(at: Vector3, s: number, kind: string?)
        if Kit(kind or ((vr:NextNumber() < 0.5) and "FernA" or "FernB"), at, s * 0.55, nil, LeafCol()) then return end
        for k = 1, 5 do
            local a = k / 5 * math.pi * 2
            local fa = (Vector3.new(math.cos(a), 0, math.sin(a)) * 0.8 + Vector3.yAxis * 0.6).Unit
            local cf = CFrame.fromMatrix(at + fa * s / 2, fa:Cross(Vector3.yAxis).Unit, fa)
            Part(fx, "Frond", Enum.PartType.Wedge, Vector3.new(0.1, s, s * 0.32), cf * CFrame.Angles(0, math.rad(90), 0), LEAF, M.Grass).CastShadow = false
            n += 1
        end
    end
    local function Undergrowth(at: Vector3, s: number)
        Kit("Undergrowth", at, s, nil, LeafCol())
    end
    -- the ground height at x, z (the top of the voxel column; F off terrain maps)
    local T = workspace.Terrain
    local function GroundAt(x: number, z: number): number
        local gx, gz = math.floor(x / 4) * 4, math.floor(z / 4) * 4
        local _, occ = T:ReadVoxels(Region3.new(Vector3.new(gx, -4, gz), Vector3.new(gx + 4, 12, gz + 4)), 4)
        for j = occ.Size.Y, 1, -1 do
            local v = occ[1][j][1]
            if v > 0.05 then return -4 + (j - 1) * 4 + v * 4 end
        end
        return F
    end
    -- a shallow basin under a pool's water: the top voxel of every column under it lowered ~1.2 studs (looks only: the
    -- floor collider is a part)
    local function Basin(wat: BasePart)
        local cf, hs = wat.CFrame, wat.Size / 2
        local ext = math.max(hs.X, hs.Z) + 4
        local c = cf.Position
        local reg = Region3.new(Vector3.new(c.X - ext, -4, c.Z - ext), Vector3.new(c.X + ext, 12, c.Z + ext)):ExpandToGrid(4)
        local mats, occ = T:ReadVoxels(reg, 4)
        local sz = occ.Size
        local org = reg.CFrame.Position - reg.Size / 2
        local changed = false
        for i = 1, sz.X do
            for k = 1, sz.Z do
                local lp = cf:PointToObjectSpace(Vector3.new(org.X + (i - 0.5) * 4, c.Y, org.Z + (k - 0.5) * 4))
                if math.abs(lp.X) < hs.X * 0.85 and math.abs(lp.Z) < hs.Z * 0.75 then
                    for j = sz.Y, 1, -1 do
                        local v = occ[i][j][k]
                        if v > 0.05 and mats[i][j][k] ~= M.Air then
                            if v > 0.3 then occ[i][j][k] = v - 0.3
                            else occ[i][j][k] = 0; if j > 1 then occ[i][j - 1][k] = math.max(0.1, occ[i][j - 1][k] - (0.3 - v)) end end
                            changed = true
                            break
                        end
                    end
                end
            end
        end
        if changed then T:WriteVoxels(reg, 4, mats, occ) end
    end
    -- STEAMING SPRING POOLS along a band: one or two kit pool chains (Springs, 30 long) laid along it, ferns + undergrowth
    -- behind against the wall, steam, 1 light for the room (kit missing: a plain dark pool, never a lit bar)
    local lit = false
    local function Spring(b0: Vector3, b1: Vector3, w: number, o: Vector3, plants: number)
        local d = Vector3.new(b1.X - b0.X, 0, b1.Z - b0.Z)
        local len, u = d.Magnitude, d.Unit
        local mid = Vector3.new((b0.X + b1.X) / 2, F, (b0.Z + b1.Z) / 2)
        local chains = (len >= 44) and 2 or 1
        for c = 1, chains do
            local seg = len / chains
            local at = b0:Lerp(b1, (c - 0.5) / chains) + o * vr:NextNumber(-0.6, 0.6)
            local ang = math.rad(vr:NextNumber(-7, 7))
            local fwd = (u * math.cos(ang) + o * math.sin(ang)).Unit
            -- (the kit's length runs along its own X: face its side (-Z) along -(fwd x up) so X lies along the band)
            local pool = Kit("Springs", Vector3.new(at.X, F - 0.35, at.Z), math.min(seg - 2, w * 4), nil, nil, true, fwd:Cross(Vector3.yAxis))
            local wat = pool and pool:FindFirstChild("Water")
            if pool and wat and wat:IsA("BasePart") then
                -- SUNK, NOT A TRAY: the water surface sits just over the ground there, the ground under it dips a little (the
                -- rocks sink in with it); measured on the voxels (the kit's lowest point is a boulder's foot, not the bed)
                local g = ctx.Terrain and GroundAt(wat.Position.X, wat.Position.Z) or F
                pool:PivotTo(pool:GetPivot() + Vector3.new(0, g + 0.08 - (wat.Position.Y + wat.Size.Y / 2), 0))
                if ctx.Terrain then Basin(wat) end
            end
            if not pool then
                local cf = CFrame.lookAt(Vector3.new(at.X, F, at.Z), Vector3.new(at.X, F, at.Z) + u)
                Part(fx, "SpringBed", nil, Vector3.new(w, 0.14, seg - 2), cf * CFrame.new(0, 0.07, 0), C3(30, 40, 36), M.Slate).CastShadow = false
                local wat = Part(fx, "SpringWater", nil, Vector3.new(w - 1.6, 0.12, seg - 4), cf * CFrame.new(0, 0.2, 0), WATER, M.SmoothPlastic)
                wat.Transparency = 0.3; wat.CastShadow = false
                n += 2
            end
        end
        for k = 1, plants do -- ferns and undergrowth behind the water, against the wall
            local at = b0:Lerp(b1, (k - 0.5) / plants + vr:NextNumber(-0.04, 0.04)) + o * vr:NextNumber(7, 8)
            if k % 3 ~= 2 then Fern(Vector3.new(at.X, F, at.Z), vr:NextNumber(10, 12), "FernA") else Undergrowth(Vector3.new(at.X, F, at.Z), vr:NextNumber(4, 5)) end
        end
        if ctx.Terrain then
            for k = 0, 3 do
                local q = b0:Lerp(b1, k / 3) - o * (w / 2 + 3)
                Paint(q.X, q.Z, vr:NextNumber(4, 6), M.Mud, vr)
            end
        end
        if not lit then
            lit = true
            local c = A.Carrier(fx, "SpringLight", Vector3.new(1, 1, 1), CFrame.new(mid + Vector3.new(0, 2.5, 0) - o * 2))
            local l = Instance.new("PointLight")
            l.Color = C3(120, 235, 215); l.Range = 26; l.Brightness = 0.7; l.Shadows = false
            l.Parent = c
        end
        Emitter(fx, "SpringSteam", CFrame.lookAt(mid + Vector3.new(0, 0.6, 0), mid + Vector3.new(0, 0.6, 0) + u), Vector3.new(w, 0.2, len), {
            Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(232, 240, 226)), LightInfluence = 0.9,
            Rate = math.clamp(len / 14, 1.5, 4), Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(1, 2.2), EmissionDirection = Enum.NormalId.Top,
            Acceleration = Vector3.new(0, 0.3, 0),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 9) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.8), NumberSequenceKeypoint.new(1, 1) }) })
    end
    -- THE RIMS (terrain maps): the rock profile outside a wall, the faces mossed, vine curtains down them
    local function KeptOut(x: number, z: number, pad: number): boolean
        for _, kb in ipairs(P.keep) do
            if x >= kb[1] - pad and x <= kb[2] + pad and z >= kb[3] - pad and z <= kb[4] + pad then return true end
        end
        return false
    end
    -- the rim outside wall sd at along-offset u: foot distance, crest distance (from the wall line) + crest top; nil = no cliff
    local function Profile(sd: number, u: number): (number?, number?, number?)
        local o, al = P.SIDES[sd], P.Along(sd)
        local tops, maxTop = {}, -1
        for k = 0, 7 do
            local q = C0 + o * (half + k * 4 + 2) + al * u
            local gx, gz = math.floor(q.X / 4) * 4, math.floor(q.Z / 4) * 4
            local _, occ = T:ReadVoxels(Region3.new(Vector3.new(gx, 0, gz), Vector3.new(gx + 4, 64, gz + 4)), 4)
            local top = 0
            for j = occ.Size.Y, 1, -1 do
                local v = occ[1][j][1]
                if v > 0.35 then top = (j - 1) * 4 + v * 4; break end
            end
            tops[k] = top
            maxTop = math.max(maxTop, top)
        end
        if maxTop < F + 9 then return nil end
        local kf, kc
        for k = 0, 7 do
            if not kf and tops[k] >= F + 5 then kf = k end
            if not kc and tops[k] >= maxTop - 3 then kc = k end
        end
        if not kf or not kc then return nil end
        return kf * 4, kc * 4 + 2, tops[kc]
    end
    -- moss + grass over the exposed faces and crests of the rim outside wall sd (material only, never height)
    local function MossFaces(sd: number)
        local o = P.SIDES[sd]
        local a = C0 + o * half
        local lo, hi
        if math.abs(o.X) > 0.5 then
            local x0 = (o.X > 0) and a.X or a.X - 28
            lo, hi = Vector3.new(x0, F + 2, C0.Z - half - 4), Vector3.new(x0 + 28, 62, C0.Z + half + 4)
        else
            local z0 = (o.Z > 0) and a.Z or a.Z - 28
            lo, hi = Vector3.new(C0.X - half - 4, F + 2, z0), Vector3.new(C0.X + half + 4, 62, z0 + 28)
        end
        local reg = Region3.new(lo, hi):ExpandToGrid(4)
        local mats, occ = T:ReadVoxels(reg, 4)
        local sz = mats.Size
        local org = reg.CFrame.Position - reg.Size / 2
        local seed = vr:NextNumber(0, 100)
        local di = (o.X > 0.5 and -1) or (o.X < -0.5 and 1) or 0
        local dk = (o.Z > 0.5 and -1) or (o.Z < -0.5 and 1) or 0
        local changed = false
        for i = 1, sz.X do
            for k = 1, sz.Z do
                local x, z = org.X + (i - 0.5) * 4, org.Z + (k - 0.5) * 4
                if not KeptOut(x, z, 4) then
                    for j = 1, sz.Y do
                        local m = mats[i][j][k]
                        if occ[i][j][k] > 0.3 and m ~= M.Air and m ~= M.Water then
                            local up = j == sz.Y or occ[i][j + 1][k] < 0.3
                            local ii, kk = i + di, k + dk
                            local side = ii < 1 or ii > sz.X or kk < 1 or kk > sz.Z or occ[ii][j][kk] < 0.3
                            if up or side then
                                local y = org.Y + (j - 0.5) * 4
                                local nz = math.noise(x / 13 + seed, y / 9, z / 13)
                                if up and nz > -0.35 then
                                    mats[i][j][k] = (nz > 0.15) and M.LeafyGrass or M.Grass; changed = true
                                elseif side and nz > -0.05 and y > F + 3 then
                                    mats[i][j][k] = (nz > 0.3) and M.LeafyGrass or M.Grass; changed = true
                                end
                            end
                        end
                    end
                end
            end
        end
        if changed then T:WriteVoxels(reg, 4, mats, occ) end
    end
    local curtains = 0
    local function Curtains(sd: number)
        local o, al = P.SIDES[sd], P.Along(sd)
        for _, f in ipairs({ -0.42, 0.38 }) do
            if curtains >= 3 then return end
            local u = (f + vr:NextNumber(-0.12, 0.12)) * half
            local wp = C0 + o * half + al * u
            if not P.DoorNear(wp, 20) and not KeptOut(wp.X, wp.Z, 8) then
                local fd, cd, cy = Profile(sd, u)
                if fd and cd and cy then
                    local foot = C0 + o * (half + fd - 1) + al * u + Vector3.new(0, F + 0.6 - C0.Y, 0)
                    local crest = C0 + o * (half + cd) + al * u + Vector3.new(0, cy - C0.Y, 0)
                    local ax = crest - foot
                    if ax.Magnitude >= 9 then
                        curtains += 1
                        Kit("VineCurtain", foot - o * 0.4, math.min(ax.Magnitude + 1, 40), ax.Unit, LeafCol(), false, -o)
                        Fern(Vector3.new(crest.X, cy - 0.4, crest.Z) - o * 1.2 + al * vr:NextNumber(3, 5), vr:NextNumber(8, 10))
                    end
                end
            end
        end
    end
    -- THE FLOOR first (A.PaintField on its own stream): mud, grass, leaf litter, mossy pebble -- 0 parts
    if A.PaintField then
        A.PaintField(P, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.Mud, 30 }, { M.Grass, 22 }, { M.LeafyGrass, 22 }, { M.Ground, 14 }, { M.Pebble, 12 } },
            { Scale = 20, Stretch = 1.7, Warp = 10, Edge = 0.3 })
    end
    local isBand = {}
    for wi, sd in ipairs(P.walls) do
        local b0, b1 = P.Band(sd, 9, 18)
        if b0 then
            isBand[sd] = true
            Spring(b0, b1, wi == 1 and 8.5 or 7.5, P.SIDES[sd], wi == 1 and 4 or 3)
        end
    end
    if ctx.Terrain then -- the rims: moss over every wall's faces, vine curtains down them
        for _, sd in ipairs(P.order) do MossFaces(sd) end
        for _, sd in ipairs(P.order) do Curtains(sd) end
    end
    -- THE OPEN FLOOR: a broken temple path of real paving, roots snaking across, undergrowth clumps (low, no collision)
    do
        local a = P.Spot(20)
        local ang = vr:NextNumber(0, math.pi * 2)
        local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
        for k = 0, 1 do
            local q = a + dir * (k - 0.5) * 7.5
            if not P.DoorNear(q, 10) and math.abs(q.X - C0.X) < half - 7 and math.abs(q.Z - C0.Z) < half - 7 then
                if not Kit("Paving", q, vr:NextNumber(6.5, 8), nil, nil, true) then
                    Part(fx, "PavingSlab", nil, Vector3.new(3, 0.3, 3), CFrame.new(q + Vector3.new(0, 0.14, 0)) * CFrame.Angles(0, ang, 0), STONE, M.Limestone).CastShadow = false
                    n += 1
                end
            end
        end
    end
    for _ = 1, 2 do
        local p = P.Spot(9)
        if not P.DoorNear(p, 10) then
            if not Kit("Roots", p - Vector3.new(0, 0.1, 0), vr:NextNumber(9, 13), nil, nil, true) then
                Part(fx, "Root", Enum.PartType.Cylinder, Vector3.new(8, 0.55, 0.55), CFrame.new(p + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0), BARK, M.Wood).CastShadow = false
                n += 1
            end
        end
    end
    do
        local p = P.Spot(14)
        if not P.DoorNear(p, 12) then Undergrowth(p, vr:NextNumber(2.8, 3.6)) end
    end
    for _, sd in ipairs(P.order) do -- FERN CLUMPS along every other wall's foot, big, every ~16 studs, doorways clear
        if not isBand[sd] then
            local o, al = P.SIDES[sd], P.Along(sd)
            local steps = math.max(2, math.floor(half * 1.6 / 20))
            for k = 0, steps - 1 do -- a clump = a tall fern + elephant ears behind it against the rock
                local f = -0.8 + 1.6 * (k + 0.5) / steps + vr:NextNumber(-0.05, 0.05)
                local q = C0 + o * (half - vr:NextNumber(2.5, 3.5)) + al * f * half
                if not P.DoorNear(q, 13) then
                    Fern(Vector3.new(q.X, F, q.Z), vr:NextNumber(10, 12.5), "FernA")
                    if k % 2 == 0 then
                        local r = q + o * 1.8 + al * vr:NextNumber(-2, 2)
                        Undergrowth(Vector3.new(r.X, F, r.Z), vr:NextNumber(4, 5.2))
                    end
                end
            end
        end
    end
    do -- FERNS AT THE FEET OF THE COVER: up to 2 pieces of the room's own cover (their colliders), 2 corners each
        local dg: Instance? = fx.Parent
        for _ = 1, 4 do
            if not dg or dg:FindFirstChild("StaticGeometry") then break end
            dg = dg.Parent
        end
        local sg = dg and dg:FindFirstChild("StaticGeometry")
        local cover = {}
        if sg then
            for _, q in ipairs(sg:GetDescendants()) do
                if q:IsA("BasePart") and q.CanCollide then
                    local pp, sz = q.Position, q.Size
                    if math.abs(pp.X - C0.X) < half - 8 and math.abs(pp.Z - C0.Z) < half - 8 and sz.Y >= 2.5 and sz.Y <= 18
                        and math.min(sz.X, sz.Z) >= 1.5 and math.max(sz.X, sz.Z) <= 36 and pp.Y - sz.Y / 2 < F + 2 then
                        table.insert(cover, q)
                    end
                end
            end
        end
        for i = #cover, 2, -1 do local j = vr:NextInteger(1, i); cover[i], cover[j] = cover[j], cover[i] end
        for i = 1, math.min(2, #cover) do
            local q = cover[i]
            local hs = q.Size / 2
            local sx = vr:NextNumber() < 0.5 and 1 or -1
            for _, sgn in ipairs({ 1, -1 }) do
                local c = q.CFrame * Vector3.new(sx * sgn * (hs.X + 1.3), 0, sgn * (hs.Z + 1.3))
                local spot = Vector3.new(c.X, F, c.Z)
                if not P.DoorNear(spot, 10) and math.abs(spot.X - C0.X) < half - 3 and math.abs(spot.Z - C0.Z) < half - 3 then
                    Fern(spot, vr:NextNumber(7, 9))
                end
            end
        end
    end
    -- EDGE: canopy trees rooted below the rim, leaning over the room; a palm on another side
    local trees, palm, used = 0, false, {}
    local beams = {}
    for _, sd in ipairs(P.order) do
        if trees >= 2 and palm then break end
        local o, al = P.SIDES[sd], P.Along(sd)
        local at = C0 + o * (half + 4) + al * vr:NextNumber(-0.5, 0.5) * half
        if used[sd] or P.DoorNear(at, 22) then continue end
        used[sd] = true
        if trees < 2 then
            trees += 1
            local lean = math.rad(vr:NextNumber(10, 16))
            local axis = (Vector3.yAxis * math.cos(lean) - o * math.sin(lean)).Unit
            local h = vr:NextNumber(42, 50)
            local m = Kit("Canopy", Vector3.new(at.X, F - 10, at.Z), h, axis, LeafCol())
            if not m then
                local base = Vector3.new(at.X, F - 14, at.Z) + o * 3
                Part(fx, "CanopyTrunk", Enum.PartType.Cylinder, Vector3.new(h, 3.6, 3.6), CFrame.fromMatrix(base + axis * h / 2, axis, o), BARK, M.Wood)
                n += 1
            end
            table.insert(beams, Vector3.new(at.X, F + h * 0.8, at.Z) - o * 8)
        elseif not palm then
            palm = true
            local lean = math.rad(vr:NextNumber(14, 22))
            local axis = (Vector3.yAxis * math.cos(lean) - o * math.sin(lean)).Unit
            Kit("Palm", Vector3.new(at.X, F - 6, at.Z), vr:NextNumber(26, 32), axis, LeafCol())
        end
    end
    -- SUNBEAMS slanting through the canopy (soft beams on one carrier: no parts)
    if #beams > 0 then
        local car = A.Carrier(fx, "Sunbeams", Vector3.new(1, 1, 1), CFrame.new(C0 + Vector3.new(0, 40, 0)))
        for _, src in ipairs(beams) do
            local a0 = Instance.new("Attachment"); a0.WorldPosition = src + Vector3.new(0, 4, 0); a0.Parent = car
            local foot = Vector3.new(src.X, F, src.Z):Lerp(C0, 0.32) + Vector3.new(vr:NextNumber(-4, 4), 0, vr:NextNumber(-4, 4))
            local a1 = Instance.new("Attachment"); a1.WorldPosition = foot; a1.Parent = car
            local b = Instance.new("Beam")
            b.Attachment0 = a0; b.Attachment1 = a1
            b.Width0 = 7; b.Width1 = 12; b.FaceCamera = true; b.Segments = 1
            b.Texture = "rbxasset://textures/particles/smoke_main.dds"; b.TextureMode = Enum.TextureMode.Stretch
            b.Color = ColorSequence.new(C3(255, 236, 180)); b.LightEmission = 0.6; b.LightInfluence = 0
            b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.95), NumberSequenceKeypoint.new(0.3, 0.84), NumberSequenceKeypoint.new(0.85, 0.86), NumberSequenceKeypoint.new(1, 1) })
            b.Parent = car
            Emitter(fx, "BeamPollen", CFrame.new(foot:Lerp(src, 0.35)), Vector3.new(6, 10, 6), {
                Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(GOLD), LightEmission = 0.8, LightInfluence = 0,
                Rate = 3, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0.2, 0.5), SpreadAngle = Vector2.new(180, 180),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.18), NumberSequenceKeypoint.new(1, 0) }) })
        end
    end
    -- SET PIECE: a toppled temple head half sunk at a wall foot, gold eyes lit, moss, roots, ferns at its chin
    do
        local sd, spot = P.SetSpot(26, 9, isBand)
        if sd and spot then
            local o, al = P.SIDES[sd], P.Along(sd)
            local at = Vector3.new(spot.X, F, spot.Z) + o * 1.5
            if ctx.Terrain then Paint(at.X - o.X * 4, at.Z - o.Z * 4, 12, M.Mud, vr) end
            -- face toward the room, rolled a little onto one cheek and tipped back, sunk ~1.5 studs into the mud
            local fwd = (-o + al * vr:NextNumber(-0.35, 0.35)).Unit
            local up = (Vector3.yAxis * math.cos(math.rad(16)) + o * math.sin(math.rad(16)) * 0.7 + al * math.sin(math.rad(12))).Unit
            local head = Kit("IdolHead", at - Vector3.new(0, 1.6, 0), vr:NextNumber(11, 13), up, nil, nil, fwd)
            if head then
                for _, q in ipairs(head:GetChildren()) do
                    if q:IsA("BasePart") and q:GetAttribute("Role") == "Stone" then q.Color = C3(118, 116, 98) end -- (the limestone scan read bright yellow)
                end
            else
                local hcf = CFrame.lookAt(at + Vector3.new(0, 4, 0), at + Vector3.new(0, 4, 0) + fwd)
                Part(fx, "IdolHead", nil, Vector3.new(10, 11, 8), hcf, STONE, M.Limestone)
                for sx = -1, 1, 2 do Part(fx, "IdolEye", nil, Vector3.new(2, 1, 0.4), hcf * CFrame.new(sx * 2.4, 1, -4.1), GOLD, M.Neon) end
                n += 3
            end
            Kit("Roots", at + o * 1, vr:NextNumber(10, 13), nil, nil, true)
            Fern(at + fwd * 6 + al * vr:NextNumber(-3, 3), vr:NextNumber(6, 7.5))
            if Lava then Lava.Glow(fx, at + Vector3.new(0, 4, 0) + fwd * 4, 10, GOLD, 0.62, { Name = "IdolGlow", MaxDistance = 500 }) end
            local c = A.Carrier(fx, "IdolLight", Vector3.new(1, 1, 1), CFrame.new(at + Vector3.new(0, 4, 0) + fwd * 6))
            local l = Instance.new("PointLight")
            l.Color = C3(255, 200, 120); l.Range = 20; l.Brightness = 0.9; l.Shadows = false
            l.Parent = c
        end
    end
    -- DRIFT: warm humid haze low on the floor
    Emitter(fx, "Humid", CFrame.new(C0 + Vector3.new(0, 0.9, 0)), Vector3.new(half * 1.7, 0.3, half * 1.7), {
        Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(200, 214, 176)), LightInfluence = 1,
        Rate = 3, Lifetime = NumberRange.new(9, 13), Speed = NumberRange.new(0.4, 1), SpreadAngle = Vector2.new(80, 5),
        EmissionDirection = Enum.NormalId.Front,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 13) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.88), NumberSequenceKeypoint.new(1, 1) }) })
    return n
end

return B
