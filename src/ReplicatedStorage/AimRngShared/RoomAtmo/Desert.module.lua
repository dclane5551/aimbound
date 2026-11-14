--!strict
-- ROOM ATMOSPHERE PASS 2 -- DESERT (the Sun Dunes; RoomAtmo API: see RoomAtmo "ATMOSPHERE PASS 2"). Its own treatment
-- (reference: wind-shaped sand banked against old stone, sun-bleached bones of something huge, dry scrub, termite spires,
-- hard golden sun and deep shade). Real meshes: ReplicatedStorage.RoomAtmoKit.Desert (tools/atmo_kit_desert.py: a giant
-- beast's skeleton, sand drifts, dry scrub, termite spires, a broken pot) + the world's own WorldProps.Desert Jars;
-- without them the plain part pieces stand in.
--   CONTRAST  Light: the golden-hour sun x0.85, ambient x0.96 (the gun plate), a warmer grade; palette x0.84 (sand x0.92:
--             it stays the brightest ground), parts x0.78, scanned props x0.6. Hard sun, dark shade under the cloth.
--   GROUND    DUNE DRIFTS at the wall foot: soft sand banked up against the wall (kit SandBank), dry scrub and a cluster of
--             the world's jars in them, a fire bowl burning at one end (1 warm light). The open floor: A.PaintField sand /
--             sandstone / packed earth, scrub tufts, pot shards -- all low, no collision.
--   EDGE      TERMITE SPIRES standing at two wall feet (tall slumped mud towers) and a torn SUN SHADE against another wall
--             (poles + a faded sail, built: the world's Shade model reads as a market stall), its cloth throwing shade
--   SET PIECE a GIANT SKELETON (the hero) on a side wall toward the far end (else the wall facing the main door): the spine in the sand ~8 in from the wall, the
--             ribs rising 15-20 and arching out over the wall line into the rock, the long skull with its jaw dropped, sand drifted round it
--   DUNES     soft sand banks ramping up every wall foot, heaped in the corners, drifts round the cover (terrain, 0 parts)
--   DRIFT     sand blowing low across the floor + dust in the air + one or two dust devils
local B = {}
local M = Enum.Material
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.85, Ambient = 0.96, Outdoor = 0.9, Tint = C3(255, 224, 186), TintAmt = 0.3 }
B.Palette = { Dim = 0.84, Mats = { [M.Sand] = 0.92, [M.Sandstone] = 1.0 } } -- (v2: sandstone close to the sand tone, the field reads soft)
B.PartDim = 0.78
B.SADim = 0.6
B.Drift = { BlowingSand = true, Dust = true }

local SAND, BONE, MUD, WOOD, FIRE = C3(214, 178, 126), C3(226, 214, 188), C3(150, 98, 60), C3(96, 70, 46), C3(255, 170, 70)
local ROUGH = { Bone = M.Limestone, Sand = M.Sand, Twig = M.Wood, Dry = M.Grass, Mud = M.Sandstone, Clay = M.Slate }

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Dune: (Vector3, number, number) -> () = function() end
    local Part, Paint, Emitter = A.Part, A.Paint, A.Emitter
    local Lava = ctx.Lava
    local P = A.Plan(ctx, vr)
    local F, C0, half = P.F, P.C0, P.half
    local n = 0
    local kitRoot = game:GetService("ReplicatedStorage"):FindFirstChild("RoomAtmoKit")
    local KIT = kitRoot and kitRoot:FindFirstChild("Desert")
    -- a kit piece (KIT, or the world's props when world = true): size = height (byWidth: width); up = its up axis; face = the
    -- direction its front (-Z) looks
    local function Kit(name: string, at: Vector3, size: number, up: Vector3?, byWidth: boolean?, face: Vector3?, world: boolean?): Model?
        local tmpl = world and A.WorldProp("Desert", name) or (KIT and KIT:FindFirstChild(name))
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
                if role == "Sand" or role == "Clay" then q.CastShadow = false end
            end
        end
        return m
    end
    local function Scrub(at: Vector3, s: number)
        if not Kit("Scrub", at, s) then
            Part(fx, "Scrub", Enum.PartType.Ball, Vector3.new(s, s * 0.6, s), CFrame.new(at + Vector3.new(0, s * 0.25, 0)), C3(110, 92, 56), M.Grass).CastShadow = false
            n += 1
        end
    end
    -- DUNE DRIFTS: sand banked against the wall, scrub + the world's jars in it, a fire bowl at one end (1 light)
    local lit = false
    local function Drifts(b0: Vector3, b1: Vector3, o: Vector3)
        local d = Vector3.new(b1.X - b0.X, 0, b1.Z - b0.Z)
        local len, u = d.Magnitude, d.Unit
        local k = math.max(1, math.floor(len / 15))
        for i = 1, k do
            local at = b0:Lerp(b1, (i - 0.5) / k) + o * 1.5
            if not Kit("SandBank", Vector3.new(at.X, F - 0.25, at.Z), len / k + 2, nil, true, u:Cross(Vector3.yAxis) * -1) and ctx.Terrain then
                Paint(at.X, at.Z, 6, M.Sand, vr)
            end
            local sq = at - o * vr:NextNumber(1.5, 3) + u * vr:NextNumber(-4, 4)
            Scrub(Vector3.new(sq.X, F, sq.Z), vr:NextNumber(2.4, 3.4))
        end
        local jq = b0:Lerp(b1, vr:NextNumber(0.3, 0.7)) + o * 0.5
        Kit("Jars", Vector3.new(jq.X, F, jq.Z), vr:NextNumber(3.5, 4.5), nil, nil, -o, true)
        if not lit then
            lit = true
            local q = b0 - o * 1 + u * 2
            local bowl = Part(fx, "FireBowl", Enum.PartType.Cylinder, Vector3.new(1.2, 3.2, 3.2), CFrame.new(Vector3.new(q.X, F + 2.6, q.Z)) * CFrame.Angles(0, 0, math.rad(90)), C3(96, 70, 40), M.Metal)
            Part(fx, "FireBowlStand", nil, Vector3.new(0.6, 2.2, 0.6), CFrame.new(Vector3.new(q.X, F + 1.1, q.Z)), WOOD, M.Wood)
            n += 2
            local fireC = A.Carrier(fx, "BowlFire", Vector3.new(1, 1, 1), CFrame.new(bowl.Position + Vector3.new(0, 1, 0)))
            local f = Instance.new("Fire"); f.Size = 3; f.Heat = 6; f.Color = C3(255, 150, 60); f.SecondaryColor = C3(255, 220, 120); f.Parent = fireC
            local l = Instance.new("PointLight")
            l.Color = C3(255, 180, 110); l.Range = 22; l.Brightness = 0.9; l.Shadows = false
            l.Parent = fireC
            if Lava then Lava.Glow(fx, bowl.Position + Vector3.new(0, 1, 0), 7, FIRE, 0.5, { Name = "BowlGlow", MaxDistance = 400 }) end
        end
    end
    -- THE FLOOR first (A.PaintField on its own stream): sand / sandstone / packed earth -- 0 parts
    if A.PaintField then
        -- (v2: two close tones only, big soft fields, a strong edge dither -- the dark earth showed the 4-stud voxel steps)
        A.PaintField(P, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.Sand, 68 }, { M.Sandstone, 32 } },
            { Scale = 60, Stretch = 2.4, Warp = 20, Edge = 0.8 })
    end
    -- DUNES (v2, terrain = 0 parts): soft sand banks ramping up every wall foot and heaped into the corners, a drift
    -- spilling round the foot of the room's cover pieces. Sand balls whose tops stay below the cover line (<= 4.5 at the
    -- wall, 0 by ~8 studs in); doorways / keep boxes / Edge drops skipped. Looks + walk-up only: the floor collider is a part.
    local T = workspace.Terrain
    local function Grounded(x: number, z: number): boolean
        local gx, gz = math.floor(x / 4) * 4, math.floor(z / 4) * 4
        local _, occ = T:ReadVoxels(Region3.new(Vector3.new(gx, -4, gz), Vector3.new(gx + 4, 4, gz + 4)), 4)
        return occ[1][1][1] > 0.3 or occ[1][2][1] > 0.3
    end
    Dune = function(at: Vector3, r: number, h: number)
        if not ctx.Terrain or not Grounded(at.X, at.Z) then return end
        T:FillBall(Vector3.new(at.X, F - r + h, at.Z), r, M.Sand)
    end
    if ctx.Terrain then
        for sd = 1, 4 do
            local o, al = P.SIDES[sd], P.Along(sd)
            local steps = math.floor(half * 2 / 9)
            for k = 0, steps do
                local u = -half + k * 9 + vr:NextNumber(-2, 2)
                local wp = C0 + o * (half + 1) + al * u
                if not P.DoorNear(wp, 17) then
                    Dune(wp, vr:NextNumber(8.5, 10.5), vr:NextNumber(3.2, 4.5))
                end
            end
        end
        for _, cx in ipairs({ -1, 1 }) do -- the corners heap highest
            for _, cz in ipairs({ -1, 1 }) do
                local cp = C0 + Vector3.new(cx * (half - 1), 0, cz * (half - 1))
                if not P.DoorNear(cp, 16) then Dune(cp, 13, 5.5) end
            end
        end
        -- drifts round the room's cover pieces (their colliders), on the side the wind piles them
        local dg: Instance? = fx.Parent
        for _ = 1, 4 do
            if not dg or dg:FindFirstChild("StaticGeometry") then break end
            dg = dg.Parent
        end
        local sg = dg and dg:FindFirstChild("StaticGeometry")
        if sg then
            local wa = vr:NextNumber(0, 6.28)
            local wind = Vector3.new(math.cos(wa), 0, math.sin(wa))
            local cnt = 0
            for _, q in ipairs(sg:GetDescendants()) do
                if cnt >= 8 then break end
                if q:IsA("BasePart") and q.CanCollide then
                    local pp, sz = q.Position, q.Size
                    if math.abs(pp.X - C0.X) < half - 8 and math.abs(pp.Z - C0.Z) < half - 8 and sz.Y >= 2.5 and sz.Y <= 18
                        and math.min(sz.X, sz.Z) >= 1.5 and math.max(sz.X, sz.Z) <= 36 and pp.Y - sz.Y / 2 < F + 2 then
                        cnt += 1
                        local ext = math.max(sz.X, sz.Z) / 2
                        local at = Vector3.new(pp.X, F, pp.Z) - wind * (ext * 0.6)
                        if not P.DoorNear(at, 10) then Dune(at, vr:NextNumber(4, 5.5), vr:NextNumber(1.2, 1.8)) end
                    end
                end
            end
        end
    end
    local isBand = {}
    for _, sd in ipairs(P.walls) do
        local b0, b1 = P.Band(sd, 4, 18)
        if b0 then
            isBand[sd] = true
            Drifts(b0, b1, P.SIDES[sd])
        end
    end
    -- THE OPEN FLOOR: scrub tufts, pot shards (low, no collision)
    for _ = 1, vr:NextInteger(3, 4) do
        local p = P.Spot(10)
        if not P.DoorNear(p, 10) then Scrub(p, vr:NextNumber(2, 3)) end
    end
    for _ = 1, 2 do
        local p = P.Spot(12)
        if not P.DoorNear(p, 10) then Kit("Shards", p, vr:NextNumber(3, 4), nil, true) end
    end
    -- EDGE: termite spires at two wall feet; the world's sun shade against another wall (non-band walls first)
    local sides = {}
    for _, sd in ipairs(P.order) do if not isBand[sd] then table.insert(sides, sd) end end
    for _, sd in ipairs(P.order) do if isBand[sd] then table.insert(sides, sd) end end
    local spires, shade = 0, false
    for _, sd in ipairs(sides) do
        local o, al = P.SIDES[sd], P.Along(sd)
        for _, f in ipairs({ vr:NextNumber(-0.65, -0.35), vr:NextNumber(0.35, 0.65) }) do
            local at = C0 + o * (half - 3) + al * f * half
            if P.DoorNear(at, 16) then continue end
            if spires < 2 then
                spires += 1
                local lean = math.rad(vr:NextNumber(2, 6))
                if not Kit("Spire", Vector3.new(at.X, F - 0.6, at.Z), vr:NextNumber(22, 28), (Vector3.yAxis * math.cos(lean) - o * math.sin(lean)).Unit) then
                    Part(fx, "Spire", nil, Vector3.new(3, 16, 3), CFrame.new(Vector3.new(at.X, F + 8, at.Z)), MUD, M.Sandstone)
                    n += 1
                end
                Scrub(Vector3.new(at.X, F, at.Z) - o * 3 + al * 2, vr:NextNumber(2.4, 3.2))
            elseif not shade then
                -- a torn SUN SHADE: four leaning poles against the wall, a sun-faded sail between them, ripped at one corner
                -- (built: the world's Shade model reads as a striped market stall)
                shade = true
                local base = Vector3.new(at.X, F, at.Z)
                local cf = CFrame.lookAt(base, base - o)
                local H, W, D = vr:NextNumber(9, 11), vr:NextNumber(11, 14), 8
                local tops = {}
                for _, c in ipairs({ { -1, 0 }, { 1, 0 }, { -1, 1 }, { 1, 1 } }) do
                    local foot = cf * Vector3.new(c[1] * W / 2, 0, -c[2] * D)
                    local top = foot + Vector3.new(0, H * (c[2] == 1 and 0.8 or 1), 0) + o * 0.8
                    table.insert(tops, top)
                    Part(fx, "ShadePole", Enum.PartType.Cylinder, Vector3.new((top - foot).Magnitude, 0.35, 0.35), CFrame.fromMatrix((foot + top) / 2, (top - foot).Unit, o:Cross(Vector3.yAxis)), WOOD, M.Wood)
                    n += 1
                end
                -- the sail: one thin slab across the four pole tops, a second smaller torn flap hanging from the front edge
                local mid = (tops[1] + tops[2] + tops[3] + tops[4]) / 4
                local across, deep = (tops[2] - tops[1]), (tops[3] - tops[1])
                local sail = Part(fx, "ShadeSail", nil, Vector3.new(across.Magnitude - 0.4, 0.12, deep.Magnitude - 0.4), CFrame.fromMatrix(mid - Vector3.new(0, 0.3, 0), across.Unit, deep.Unit:Cross(across.Unit)), C3(176, 92, 64), M.Fabric)
                sail.CastShadow = true
                local flap = Part(fx, "ShadeFlap", nil, Vector3.new(across.Magnitude * 0.45, 2.4, 0.1), CFrame.lookAt((tops[3] + tops[4]) / 2 - Vector3.new(0, 1.4, 0) + across * 0.15, (tops[3] + tops[4]) / 2 - Vector3.new(0, 1.4, 0) + across * 0.15 - o) * CFrame.Angles(math.rad(12), 0, math.rad(4)), C3(206, 168, 120), M.Fabric)
                flap.CastShadow = false
                n += 2
            end

        end
        if spires >= 2 and shade then break end
    end
    -- SET PIECE (v2, the hero): the giant skeleton. Its spine lies ~8 in from the wall FACING THE MAIN DOOR (else a side
    -- wall toward the far end), the ribs rising 15-20 and arching out over the wall line into the rock, the skull at one end
    -- -- in frame from the room's entry. Sand dunes heaped round it.
    do
        local d1 = P.doors[1]
        local away = d1 and Vector3.new(C0.X - d1.X, 0, C0.Z - d1.Z) or Vector3.new(0, 0, 1)
        away = (away.Magnitude > 1) and away.Unit or Vector3.new(0, 0, 1)
        -- (snap to the room's axis: a dogleg door sits off the wall's middle)
        away = (math.abs(away.X) > math.abs(away.Z)) and Vector3.new(math.sign(away.X), 0, 0) or Vector3.new(0, 0, math.sign(away.Z))
        local cands = {}
        for sd = 1, 4 do
            local o = P.SIDES[sd]
            local dot = o:Dot(away)
            -- (a SIDE wall toward the far end first: from the entry its arches are seen side-on; on the wall facing the
            -- door they are seen end-on and read as a picket row)
            if dot > 0.7 then table.insert(cands, { sd, { 0, -0.3, 0.3, -0.5, 0.5 } })
            elseif math.abs(dot) < 0.3 then
                local al = P.Along(sd)
                local s = (al:Dot(away) >= 0) and 1 or -1
                table.insert(cands, 1, { sd, { s * 0.3, s * 0.15, s * 0.45, 0 } })
            end
        end
        for sd = 1, 4 do -- (last resort: the wall the main door is on, toward its far end)
            if P.SIDES[sd]:Dot(away) < -0.7 then table.insert(cands, { sd, { -0.5, 0.5 } }) end
        end
        if game:GetService("RunService"):IsStudio() then
            local t = {}
            for _, dp in ipairs(P.doors) do table.insert(t, string.format("%.0f,%.0f", dp.X - C0.X, dp.Z - C0.Z)) end
            fx:SetAttribute("DevDoors", table.concat(t, " "))
        end
        local done = false
        for _, c in ipairs(cands) do
            if done then break end
            local sd = c[1]
            local o, al = P.SIDES[sd], P.Along(sd)
            for _, f in ipairs(c[2]) do
                local at = C0 + o * (half - 8) + al * f * half
                if not P.DoorNear(at, 20) and not P.DoorNear(at + al * 18, 10) and not P.DoorNear(at - al * 18, 10) then
                    done = true
                    local sk = Kit("Skeleton", Vector3.new(at.X, F - 1.2, at.Z), vr:NextNumber(17, 20), nil, false, -o)
                    if not sk then
                        local cf = CFrame.lookAt(Vector3.new(at.X, F, at.Z), Vector3.new(at.X, F, at.Z) + al)
                        for k = -3, 3 do
                            Part(fx, "Rib", Enum.PartType.Cylinder, Vector3.new(14, 0.9, 0.9), cf * CFrame.new(-6, 6, k * 4) * CFrame.Angles(0, 0, math.rad(60)), BONE, M.Limestone)
                            n += 1
                        end
                    end
                    if ctx.Terrain then
                        for k = -3, 3 do local q = at + al * k * 7 + o * 2; Paint(q.X, q.Z, 6, M.Sand, vr) end
                        Dune(at + al * 16 - o * 2, 8, 3.2)
                        Dune(at - al * 18, 7, 2.6)
                    end
                    Scrub(Vector3.new(at.X, F, at.Z) - o * 6 + al * 10, 3)
                    Scrub(Vector3.new(at.X, F, at.Z) - o * 5 - al * 14, 2.6)
                    break
                end
            end
        end
    end
    -- DRIFT: sand blowing low across the floor + dust in the air
    Emitter(fx, "BlowingSand", CFrame.new(C0 + Vector3.new(0, 0.8, 0)), Vector3.new(half * 1.7, 0.3, half * 1.7), {
        Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(222, 196, 150)), LightInfluence = 1,
        Rate = 6, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(6, 10), SpreadAngle = Vector2.new(10, 3),
        EmissionDirection = Enum.NormalId.Front,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.86), NumberSequenceKeypoint.new(1, 1) }) })
    Emitter(fx, "Dust", CFrame.new(C0 + Vector3.new(0, 6, 0)), Vector3.new(half * 1.6, 8, half * 1.6), {
        Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C3(255, 230, 180)), LightEmission = 0.4, LightInfluence = 0.6,
        Rate = 6, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.12), NumberSequenceKeypoint.new(1, 0) }) })
    -- DUST DEVILS: one or two tall thin twisting columns of sand on the open floor (one emitter each, cheap)
    for k = 1, vr:NextInteger(1, 2) do
        local p = P.Spot(16)
        Emitter(fx, "DustDevil" .. k, CFrame.new(p + Vector3.new(0, 0.5, 0)), Vector3.new(1.5, 0.2, 1.5), {
            Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C3(226, 196, 150)), LightInfluence = 1,
            Rate = 5, Lifetime = NumberRange.new(2.5, 3.5), Speed = NumberRange.new(4, 6), EmissionDirection = Enum.NormalId.Top,
            SpreadAngle = Vector2.new(6, 6), RotSpeed = NumberRange.new(-260, 260), Rotation = NumberRange.new(0, 360),
            Acceleration = Vector3.new(vr:NextNumber(-1, 1), 1, vr:NextNumber(-1, 1)),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(0.6, 3.5), NumberSequenceKeypoint.new(1, 6) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.7), NumberSequenceKeypoint.new(0.8, 0.85), NumberSequenceKeypoint.new(1, 1) }) })
    end
    return n
end

return B
