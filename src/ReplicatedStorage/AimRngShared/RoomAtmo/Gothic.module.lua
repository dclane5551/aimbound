--!strict
-- ROOM ATMOSPHERE PASS 2 -- GOTHIC (the Moonlit Spires; RoomAtmo API: see RoomAtmo "ATMOSPHERE PASS 2"). Its own treatment
-- (reference: cold stone and iron in blue-white moonlight, graves and gates along the walls, small warm flames). Real meshes:
-- ReplicatedStorage.RoomAtmoKit.Gothic (tools/atmo_kit_gothic.py: a gnarled dead tree, rows of worn headstones, a broken
-- gothic window, a carved sarcophagus with its lid slid off, melted candle clusters, ivy, bones) + the world's own
-- WorldProps.Gothic Fence / Lantern / Angel; without them the plain part pieces stand in.
--   CONTRAST  Light: the moon x0.75, ambient x1, the grade pulled colder; palette x0.85, parts x0.8. Cold moonlit stone,
--             with a few warm gas-lamp and candle flames as the only warm colour.
--   GROUND    a GRAVE ROW at the wall foot: the wrought-iron fence run along it, worn headstones behind, ivy creeping at the
--             foot, a gas lamp at one end (1 warm light), cold mist lying in it. The open floor: A.PaintField mud / earth /
--             dead grass / old cobbles + pavement fields (the square keeps its stone), sunken ledger stones, bones, candle clusters at the other walls' feet.
--   EDGE      a BROKEN GOTHIC WINDOW and a DEAD TREE standing at wall feet against the rim, bare branches against the moon;
--             short grave rows + ivy + candles at the other wall feet
--   SET PIECE an OPENED SARCOPHAGUS at a wall foot, its lid slid half off, a cold glow rising out of it, a weeping angel
--             behind it and candles round it (1 cold light)
--   DRIFT     cold ground mist + dead leaves tumbling across the floor
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.75, Ambient = 1.0, Outdoor = 1.0, Tint = C3(200, 214, 255), TintAmt = 0.25 }
B.Palette = { Dim = 0.85, Mats = { [M.Grass] = 1, [M.LeafyGrass] = 1 },
    Base = { [M.Grass] = C3(56, 60, 50), [M.LeafyGrass] = C3(62, 58, 48) } } -- (dead grass: floor-only, never a Gothic RimMat)
B.PartDim = 0.8
B.SADim = 0.55 -- (the scanned boulders / busts keep their bright textures under PartDim: mapvibe's separate factor)
B.Drift = { ColdMist = true, DeadLeaves = true }

local IRON, STONE, STONE2, DARK = C3(34, 34, 40), C3(112, 114, 126), C3(88, 90, 102), C3(40, 40, 48)
local FLAME, COLD = C3(255, 180, 90), C3(150, 190, 255)
local ROUGH = { Bark = M.Wood, Stone = M.Slate, Moss = M.Grass, Leaf = M.Grass }

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Part, Paint, Emitter = A.Part, A.Paint, A.Emitter
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    local kitRoot = game:GetService("ReplicatedStorage"):FindFirstChild("RoomAtmoKit")
    local KIT = kitRoot and kitRoot:FindFirstChild("Gothic")
    -- a kit piece (KIT, or the world's props when world = true): size = height (byWidth: width); up = its up axis; face = the
    -- direction its front (-Z) looks
    local function Kit(name: string, at: Vector3, size: number, up: Vector3?, byWidth: boolean?, face: Vector3?, world: boolean?): Model?
        local tmpl = world and A.WorldProp("Gothic", name) or (KIT and KIT:FindFirstChild(name))
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
                elseif role and ROUGH[role] then q.Material = ROUGH[role] end
            end
        end
        return m
    end
    local function Candles(at: Vector3, s: number)
        if not Kit("Candles", at, s * 0.9, nil, true) then
            for k = 1, 3 do
                local q = at + Vector3.new(vr:NextNumber(-0.8, 0.8), 0, vr:NextNumber(-0.8, 0.8))
                local h = vr:NextNumber(0.5, 1.1)
                Part(fx, "Candle", Enum.PartType.Cylinder, Vector3.new(h, 0.28, 0.28), CFrame.new(q + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), C3(220, 210, 186), M.SmoothPlastic).CastShadow = false
                n += 1
            end
        end
        if Lava then Lava.Glow(fx, at + Vector3.new(0, 1, 0), 6, FLAME, 0.55, { Name = "CandleGlow", MaxDistance = 300 }) end
    end
    -- GRAVE ROW: the world's iron fence along the band, worn headstones behind it, ivy, a gas lamp, cold mist
    local lamped = false
    local function Graves(b0: Vector3, b1: Vector3, o: Vector3, rows: number)
        local d = Vector3.new(b1.X - b0.X, 0, b1.Z - b0.Z)
        local len, u = d.Magnitude, d.Unit
        local mid = Vector3.new((b0.X + b1.X) / 2, F, (b0.Z + b1.Z) / 2)
        -- the fence: world Fence models (9.6 wide, run along their X) end to end, one panel missing
        local fl = (b0 - o * 1.4)
        local panels = math.max(1, math.floor(len / 9.4))
        local gap = vr:NextInteger(1, panels)
        local fenced = 0
        for k = 1, panels do
            if k ~= gap or panels < 3 then
                local q = fl:Lerp(b1 - o * 1.4, (k - 0.5) / panels)
                if Kit("Fence", Vector3.new(q.X, F, q.Z), 9.6, nil, true, -o, true) then fenced += 1 end
            end
        end
        if fenced == 0 then -- (no world fence: posts + two rails)
            local fcf = CFrame.lookAt(Vector3.new(mid.X, F, mid.Z) - o * 1.5, Vector3.new(mid.X, F, mid.Z) - o * 1.5 + u)
            for _, y in ipairs({ 1.1, 3.1 }) do Part(fx, "FenceRail", nil, Vector3.new(0.18, 0.22, len), fcf * CFrame.new(0, y, 0), IRON, M.Metal); n += 1 end
        end
        for k = 1, rows do -- the kit's grave rows behind the fence
            local at = b0:Lerp(b1, (k - 0.5) / rows + vr:NextNumber(-0.04, 0.04)) + o * vr:NextNumber(1.6, 2.6)
            if not Kit("Graves", Vector3.new(at.X, F - 0.25, at.Z), vr:NextNumber(3.4, 4.2), nil, nil, -o) then
                local s = CFrame.lookAt(Vector3.new(at.X, F + 1.5, at.Z), Vector3.new(at.X, F + 1.5, at.Z) - o)
                Part(fx, "Headstone", nil, Vector3.new(2.2, 3, 0.5), s, STONE, M.Slate)
                n += 1
            end
        end
        for _ = 1, 2 do -- ivy creeping at the fence foot
            local q = b0:Lerp(b1, vr:NextNumber(0.1, 0.9)) - o * vr:NextNumber(0.6, 2)
            Kit("Ivy", Vector3.new(q.X, F, q.Z), vr:NextNumber(5, 7), nil, true)
        end
        if ctx.Terrain then
            for k = 0, 3 do
                local q = b0:Lerp(b1, k / 3) + o * 1
                Paint(q.X, q.Z, vr:NextNumber(4, 6), M.Mud, vr)
            end
        end
        if not lamped then -- the world's gas lamp at one end of the fence (warm)
            lamped = true
            local q = b0 - o * 1.4 + u * 1
            local lamp = Kit("Lantern", Vector3.new(q.X, F, q.Z), 10, nil, nil, -o, true)
            local top = Vector3.new(q.X, F + 9.2, q.Z)
            if not lamp then
                Part(fx, "LampPost", nil, Vector3.new(0.35, 9, 0.35), CFrame.new(Vector3.new(q.X, F + 4.5, q.Z)), IRON, M.Metal)
                local fl2 = Part(fx, "LampFlame", Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7), CFrame.new(top), FLAME, M.Neon)
                fl2.CastShadow = false
                n += 2
            end
            if Lava then Lava.Glow(fx, top, 9, FLAME, 0.45, { Name = "LampGlow", MaxDistance = 500 }) end
            local c = A.Carrier(fx, "LampLight", Vector3.new(1, 1, 1), CFrame.new(top - Vector3.new(0, 1, 0) - o * 1.5))
            local l = Instance.new("PointLight")
            l.Color = C3(255, 190, 120); l.Range = 24; l.Brightness = 1; l.Shadows = false
            l.Parent = c
        end
        Emitter(fx, "GraveMist", CFrame.lookAt(mid + Vector3.new(0, 0.5, 0) + o, mid + Vector3.new(0, 0.5, 0) + o + u), Vector3.new(4, 0.2, len), {
            Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(196, 206, 230)), LightInfluence = 0.9,
            Rate = math.clamp(len / 18, 1, 3), Lifetime = NumberRange.new(7, 10), Speed = NumberRange.new(0.3, 0.7), EmissionDirection = Enum.NormalId.Top,
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.82), NumberSequenceKeypoint.new(1, 1) }) })
    end
    -- THE FLOOR first (A.PaintField on its own stream): mud / earth / dead grass / pavement -- 0 parts
    if A.PaintField then
        A.PaintField(P, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.Cobblestone, 32 }, { M.Pavement, 14 }, { M.Mud, 18 }, { M.Ground, 16 }, { M.Grass, 11 }, { M.LeafyGrass, 9 } },
            { Scale = 20, Stretch = 1.6, Warp = 10, Edge = 0.3 })
    end
    local isBand = {}
    for wi, sd in ipairs(P.walls) do
        local b0, b1 = P.Band(sd, 4.5, 18)
        if b0 then
            isBand[sd] = true
            Graves(b0, b1, P.SIDES[sd], wi == 1 and 3 or 2)
        end
    end
    -- THE OPEN FLOOR: sunken ledger stones, bones, ivy patches (low, no collision); candles at the other walls' feet
    for _ = 1, vr:NextInteger(4, 5) do
        local p = P.Spot(12)
        if not P.DoorNear(p, 12) then
            local ls = Part(fx, "LedgerStone", nil, Vector3.new(vr:NextNumber(3, 3.8), 0.35, vr:NextNumber(5.5, 6.8)),
                CFrame.new(p + Vector3.new(0, 0.12, 0)) * CFrame.Angles(math.rad(vr:NextNumber(-3, 3)), vr:NextNumber(0, 6.28), math.rad(vr:NextNumber(-3, 3))), STONE2, M.Slate)
            ls.CastShadow = false
            n += 1
        end
    end
    for _ = 1, 2 do
        local p = P.Spot(10)
        if not P.DoorNear(p, 10) then Kit("Bones", p, vr:NextNumber(2.2, 2.8), nil, true) end
    end
    for _ = 1, 2 do
        local p = P.Spot(10)
        if not P.DoorNear(p, 10) then Kit("Ivy", p, vr:NextNumber(5, 7), nil, true) end
    end
    -- THE OTHER WALL FEET: a short row of worn graves with ivy and a candle cluster at each (no fence), doors clear
    local cand = 0
    for _, sd in ipairs(P.order) do
        if not isBand[sd] then
            local o, al = P.SIDES[sd], P.Along(sd)
            for _, f in ipairs({ -0.45, 0.45 }) do
                local q = C0 + o * (half - 3.2) + al * (f + vr:NextNumber(-0.1, 0.1)) * half
                if not P.DoorNear(q, 15) then
                    if vr:NextNumber() < 0.6 then Kit("Graves", Vector3.new(q.X, F - 0.25, q.Z), vr:NextNumber(3.2, 3.9), nil, nil, -o) end
                    local iv = q - o * 1.5 + al * vr:NextNumber(-3, 3)
                    Kit("Ivy", Vector3.new(iv.X, F, iv.Z), vr:NextNumber(5, 7), nil, true)
                    if cand < 2 then cand += 1; Candles(Vector3.new(q.X, F, q.Z) - o * 2.5 + al * 5, vr:NextNumber(2, 2.6)) end
                end
            end
        end
    end
    -- EDGE: a broken gothic window, a dead tree leaning over the room
    -- (both stand AT THE WALL FOOT inside the room: on a cliff rim the rock hid them, on an Edge map there is no ground)
    local placedWin, placedTree, used = false, false, {}
    local sides = {}
    for _, sd in ipairs(P.order) do if not isBand[sd] then table.insert(sides, sd) end end
    for _, sd in ipairs(P.order) do if isBand[sd] then table.insert(sides, sd) end end
    for _, sd in ipairs(sides) do
        local o, al = P.SIDES[sd], P.Along(sd)
        local at = C0 + o * (half - 3) + al * vr:NextNumber(-0.45, 0.45) * half
        if used[sd] or P.DoorNear(at, 18) then continue end
        used[sd] = true
        if not placedWin then
            placedWin = true
            if not Kit("Ruin", Vector3.new(at.X, F - 0.6, at.Z), vr:NextNumber(20, 24), nil, nil, -o) then
                local base = Vector3.new(at.X, F, at.Z)
                local cf = CFrame.lookAt(base, base - o)
                for sx = -1, 1, 2 do Part(fx, "WindowPier", nil, Vector3.new(2.2, 20, 2.2), cf * CFrame.new(sx * 6, 10, 0), STONE2, M.Slate); n += 1 end
            end
        elseif not placedTree then
            placedTree = true
            local lean = math.rad(vr:NextNumber(8, 14))
            local axis = (Vector3.yAxis * math.cos(lean) - o * math.sin(lean)).Unit
            local foot = at + o * 1
            if not Kit("DeadTree", Vector3.new(foot.X, F - 1.2, foot.Z), vr:NextNumber(24, 28), axis) then
                local h = 24
                local base = Vector3.new(foot.X, F - 1, foot.Z)
                Part(fx, "DeadTrunk", Enum.PartType.Cylinder, Vector3.new(h, 2, 2), CFrame.fromMatrix(base + axis * h / 2, axis, o), C3(54, 46, 42), M.Wood)
                n += 1
            end
            break
        end
    end
    -- SET PIECE: an opened sarcophagus at a wall foot, a cold glow out of it, a weeping angel behind, candles round it
    do
        local sd, spot = P.SetSpot(24, 8, isBand)
        if sd and spot then
            local o, al = P.SIDES[sd], P.Along(sd)
            local at = Vector3.new(spot.X, F, spot.Z) + o * 1
            -- (the kit's tomb runs along its own Y in Blender = -Z here: look along the wall so it lies parallel to it)
            local tomb = Kit("Sarcophagus", at, vr:NextNumber(4.6, 5.4), nil, nil, al)
            local glowAt = at + Vector3.new(0, 3, 0)
            if not tomb then
                local cf = CFrame.lookAt(at, at + al)
                Part(fx, "TombPlinth", nil, Vector3.new(8, 1.4, 13), cf * CFrame.new(0, 0.7, 0), STONE2, M.Slate)
                Part(fx, "TombBox", nil, Vector3.new(5, 3.2, 10), cf * CFrame.new(0, 3, 0), STONE, M.Slate)
                local inner = Part(fx, "TombGlow", nil, Vector3.new(3.4, 0.3, 8.4), cf * CFrame.new(0, 4.65, 0), COLD, M.Neon)
                inner.Transparency = 0.35
                n += 3
            end
            Kit("Angel", at + o * 6, 12, nil, nil, -o, true)
            for k = -1, 1, 2 do Candles(at + al * k * 7.5 - o * 2.5, vr:NextNumber(2, 2.6)) end
            Emitter(fx, "TombVapour", CFrame.new(glowAt), Vector3.new(3, 0.3, 6), {
                Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(170, 200, 255)), LightEmission = 0.4, LightInfluence = 0.3,
                Rate = 3, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(1, 2), EmissionDirection = Enum.NormalId.Top,
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) }),
                Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) }) })
            if Lava then Lava.Glow(fx, glowAt + Vector3.new(0, 1, 0), 12, COLD, 0.55, { Name = "TombGlowBB", MaxDistance = 500 }) end
            local c = A.Carrier(fx, "TombLight", Vector3.new(1, 1, 1), CFrame.new(glowAt + Vector3.new(0, 1, 0) - o * 3))
            local l = Instance.new("PointLight")
            l.Color = C3(160, 200, 255); l.Range = 22; l.Brightness = 1; l.Shadows = false
            l.Parent = c
        end
    end
    -- DRIFT: cold ground mist + dead leaves tumbling across the floor
    Emitter(fx, "ColdMist", CFrame.new(C0 + Vector3.new(0, 0.8, 0)), Vector3.new(half * 1.7, 0.3, half * 1.7), {
        Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(180, 192, 222)), LightInfluence = 1,
        Rate = 4, Lifetime = NumberRange.new(9, 14), Speed = NumberRange.new(0.5, 1.2), SpreadAngle = Vector2.new(80, 5),
        EmissionDirection = Enum.NormalId.Front,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 14) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(1, 1) }) })
    Emitter(fx, "DeadLeaves", CFrame.new(C0 + Vector3.new(0, 1.2, 0)), Vector3.new(half * 1.6, 0.4, half * 1.6), {
        Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C3(110, 84, 60)), LightEmission = 0, LightInfluence = 1,
        Rate = 5, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(4, 7), SpreadAngle = Vector2.new(15, 8),
        EmissionDirection = Enum.NormalId.Front, Acceleration = Vector3.new(0, -0.6, 0), RotSpeed = NumberRange.new(-180, 180),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.25) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.2), NumberSequenceKeypoint.new(1, 1) }) })
    return n
end

return B
