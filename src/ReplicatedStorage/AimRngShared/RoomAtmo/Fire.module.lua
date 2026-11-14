--!strict
-- ROOM ATMOSPHERE PASS 2 -- FIRE (Molten). The MOLTEN PILOT (2026-10-25), the reference for the other biomes' passes.
-- (coordinator: "after is almost the same image as before ... the reference is dark, with lava troughs cut into the
-- architecture as the light source"; review: "the mood is a real step", then fixes: a real pour, floor detail, scale)
--   CONTRAST  Light: the low sun x0.25 (it lit every floor face evenly); ambient + exposure stay, so GearLight's plate test
--             reads the same (fix grey 60 -> 57) and enemies keep their outlines. Palette x0.55 (crust x0.4: its orange
--             cracks stay), parts x0.55 (RoomAtmo.Dim). The lava carries the light.
--   GROUND    lava SLUICES at the wall foot (flush: a channel sunk under the floor is invisible from 6 up past ~40 studs):
--             ribbon, low room-side lip, tall broken basalt retaining wall, wide heat glows, embers, crusted pools whose
--             PointLights light the room (main band 2). Up to two doorless walls + a gutter beside each doorway, only where
--             the wall foot is open floor. CRACK networks out of them up to ~40 studs in (mostly dark, a few hot), vents with
--             their own cracks in the open floor, slag fields (terrain), obsidian plates, cinder clumps -- all < 0.6 stud.
--   EDGE      a tall tapered CHIMNEY (smoke + mouth glow), twin I-beam GIRDERS over the opposite corner with a chain + a
--             glowing hanging crucible, two big stone BUTTRESSES against the trough wall
--   SET PIECE a big crucible on a trunnion cradle, tipped SIDEWAYS along the wall, pouring a real stream (hot core inside a
--             glowing sheath) into a splash pool with sparks (1 light)
local B = {}
local M = Enum.Material
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local function C3(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

B.Light = { Sun = 0.25 }
B.Palette = { Dim = 0.55, Mats = { [M.CrackedLava] = 0.4 },
    Base = { [M.Basalt] = C3(52, 42, 40), [M.Slate] = C3(70, 58, 54), [M.Rock] = C3(88, 70, 62), [M.Ground] = C3(80, 64, 56),
        [M.Mud] = C3(66, 52, 46), [M.Pavement] = C3(84, 72, 66), [M.Cobblestone] = C3(84, 70, 62), [M.Sandstone] = C3(110, 80, 64) } }
B.PartDim = 0.55

function B.Build(fx: Instance, ctx: any, vr: Random, A: any): number
    local Part, Carrier, Paint, SIDES = A.Part, A.Carrier, A.Paint, A.SIDES
    local Lava = ctx.Lava
    if not Lava then return 0 end
    local cx, cz, half = ctx.X, ctx.Z, ctx.Half
    local F = 2
    local C0 = Vector3.new(cx, F, cz)
    local doors = ctx.Doors or {}
    -- FLOOR FIELD (terrain paint, 0 parts): the whole open floor in big irregular blobs / drifts of the biome's ground
    -- materials (A.PaintField; its own Random so the room's other draws -- the layout -- stay where they were). The big
    -- round field blobs below only draw their numbers when the field ran.
    local field = A.PaintField({ C0 = C0, half = half }, ctx, Random.new((ctx.Seed or 1) + 7717), { { M.Basalt, 45 }, { M.Slate, 30 }, { M.CrackedLava, 25 } }, { Scale = 22, Stretch = 2 }) > 0
    local function FieldPaint(x: number, z: number, r: number, mat: Enum.Material, rr: Random)
        if field then rr:NextNumber(0, math.pi * 2) else Paint(x, z, r, mat, rr) end
    end
    local function DoorNear(p: Vector3, r: number): boolean
        for _, dp in ipairs(doors) do if (Vector3.new(dp.X - p.X, 0, dp.Z - p.Z)).Magnitude < r then return true end end
        for _, b in ipairs(ctx.Keep or {}) do if p.X >= b[1] and p.X <= b[2] and p.Z >= b[3] and p.Z <= b[4] then return true end end -- (room 1's keep boxes)
        return false
    end
    local n = 0
    -- the troughs: up to two walls without a door (the opposite one first), each trimmed short of any doorway
    local order = { 1, 2, 3, 4 }
    for i = 4, 2, -1 do local j = vr:NextInteger(1, i); order[i], order[j] = order[j], order[i] end
    local function Clear(sd: number): boolean return not DoorNear(C0 + SIDES[sd] * (half - 6), half * 0.75) end
    local walls = {}
    for _, sd in ipairs(order) do
        if Clear(sd) then
            table.insert(walls, sd)
            local opp = (sd % 2 == 1) and sd + 1 or sd - 1
            if Clear(opp) then table.insert(walls, opp) end
            break
        end
    end
    if #walls == 0 then walls = { order[1] } end
    local troughSide = walls[1]
    local tOut = SIDES[troughSide]
    -- (eye-level check 2026-10-25: a channel sunk 2 under the floor is invisible from 6 up at 40+ studs -- the lip hides it.
    -- So the trough is a flush lava sluice: the lava ribbon on the floor, a broken basalt kerb on its room side (a low
    -- silhouette that says "channel" from across the room), heat haze glows over it and embers rising off it)
    local function Sluice(p0: Vector3, p1: Vector3, w: number, inward: Vector3, lights: number?)
        local y = F + 0.25
        -- crusted pools swelling out of the sluice: the room's only lights besides the set piece (they wash the kerb, the
        -- wall foot and the floor orange -- what makes the lava read as the light source from eye height)
        for li = 1, lights or 0 do
            local at = p0:Lerp(p1, li / ((lights or 0) + 1) + vr:NextNumber(-0.08, 0.08))
            Lava.Pool(fx, CFrame.new(Vector3.new(at.X, F + 0.3, at.Z)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0), w * 0.75, { Light = 30, Smoke = false, Sparks = false })
            n += 1
        end
        Lava.Flow(fx, Vector3.new(p0.X, y, p0.Z), Vector3.new(p1.X, y, p1.Z), w, { Light = false, Smoke = false, Sparks = false, Speed = 0.05, Bright = 2.2 })
        local d = Vector3.new(p1.X - p0.X, 0, p1.Z - p0.Z)
        local len, u = d.Magnitude, d.Unit
        -- kerbs: a LOW lip on the room side (0.3-0.5: from eye height a taller one hid the lava behind it) and a tall
        -- retaining wall of basalt blocks on the wall side, which the pool lights wash orange
        for side = -1, w >= 4 and 1 or -1, 2 do -- (a doorway gutter: the wall-side row only)
            local t = 0
            while t < len - 3 do
                local seg = math.min(vr:NextNumber(14, 22), len - t)
                local mid = p0:Lerp(p1, (t + seg / 2) / len) + inward * side * (w / 2 + 0.7)
                local hgt = side > 0 and vr:NextNumber(0.3, 0.5) or vr:NextNumber(1.6, 2.6)
                local base = Vector3.new(mid.X, F + hgt / 2 - 0.25, mid.Z)
                local cf = CFrame.lookAt(base, base + u) * CFrame.Angles(0, vr:NextNumber(-0.06, 0.06), 0)
                Part(fx, "SluiceKerb", nil, Vector3.new(side > 0 and 1.3 or 1.8, hgt, seg - vr:NextNumber(0.6, 1.6)), cf, C3(36, 30, 28), M.Basalt)
                n += 1
                t += seg
            end
        end
        local glows = math.max(1, math.floor(len / 22))
        for g = 1, glows do
            Lava.Glow(fx, p0:Lerp(p1, (g - 0.5) / glows) + Vector3.new(0, F + 1.6 - p0.Y, 0), 26, C3(255, 110, 40), 0.3, { Name = "TroughGlow", MaxDistance = 400 })
            n += 1
        end
        local src = Carrier(fx, "SluiceEmbers", Vector3.new(w, 0.2, len), CFrame.lookAt((p0 + p1) / 2 + Vector3.new(0, F + 0.4 - p0.Y, 0), (p0 + p1) / 2 + Vector3.new(0, F + 0.4 - p0.Y, 0) + u))
        local e = Instance.new("ParticleEmitter")
        e.Texture = "rbxasset://textures/particles/sparkles_main.dds"; e.Color = ColorSequence.new(C3(255, 190, 90), C3(255, 70, 20))
        e.LightEmission = 1; e.LightInfluence = 0; e.Rate = math.clamp(len / 12, 2, 7)
        e.Lifetime = NumberRange.new(1.5, 3); e.Speed = NumberRange.new(2, 5); e.SpreadAngle = Vector2.new(20, 20)
        e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
        e.Acceleration = Vector3.new(0, 1.5, 0); e.EmissionDirection = Enum.NormalId.Top
        e.Parent = src
        CollectionService:AddTag(e, "QThin")
    end
    local function Trough(sd: number, w: number, lights: number): (Vector3, Vector3)
        local o = SIDES[sd]
        local al = Vector3.new(-o.Z, 0, o.X)
        local mid = C0 + o * (half - 4.5)
        local b0, b1 = mid - al * half * 0.62, mid + al * half * 0.62
        for _, dp in ipairs(doors) do
            local rel = Vector3.new(dp.X, 0, dp.Z) - Vector3.new(mid.X, 0, mid.Z)
            if math.abs(rel:Dot(o)) < 12 then
                local du = rel:Dot(al)
                if du > 0 then b1 = mid + al * math.min(half * 0.62, du - 14) else b0 = mid + al * math.max(-half * 0.62, du + 14) end
            end
        end
        if (b1 - b0).Magnitude < 18 then return nil, nil end
        -- (only where the wall foot is open floor: a massif / terrace / cover filled in front of the wall would bury it --
        -- the exit room's Hall massifs did. Terrain maps: one voxel read of the cell above the floor along the band)
        if ctx.Terrain then
            local T = Workspace.Terrain
            local d = b1 - b0
            local len = Vector3.new(d.X, 0, d.Z).Magnitude
            local steps = math.max(1, math.floor(len / 4))
            local open = {}
            for k = 0, steps do
                local q = b0:Lerp(b1, k / steps) - o * 2.5 -- (the band's room half: the cliff toe fills the cells at the wall)
                local gx, gz = math.floor(q.X / 4) * 4, math.floor(q.Z / 4) * 4
                local _, occ = T:ReadVoxels(Region3.new(Vector3.new(gx, 4, gz), Vector3.new(gx + 4, 8, gz + 4)), 4)
                open[k] = occ[1][1][1] < 0.3
            end
            -- the longest open run
            local bestA, bestB, a = nil, nil, nil
            for k = 0, steps + 1 do
                if open[k] then a = a or k
                elseif a then
                    if not bestA or (k - 1 - a) > (bestB - bestA) then bestA, bestB = a, k - 1 end
                    a = nil
                end
            end
            if not bestA or (bestB - bestA) * len / steps < 16 then return nil, nil end
            b0, b1 = b0:Lerp(b1, bestA / steps), b0:Lerp(b1, bestB / steps)
        end
        Sluice(b0, b1, w, -o, lights)
        return b0, b1
    end
    -- CRACKS: branching networks, thinning out; mostly dark (a dull red seam), a few hot (pilot review: "reaching far further
    -- in ... mostly dark with a few hot spots"). Flat self-lit strips: no height, no collision, no query.
    local DARK = C3(150, 48, 22)
    local cracks = 0
    local function Crack(p: Vector3, dir: Vector3, w: number, depth: number, o: Vector3?, maxDepth: number?)
        if cracks > 70 then return end
        local len = vr:NextNumber(4, 9)
        local q = p + dir * len
        local rel = q - C0
        if math.abs(rel.X) > half - 3 or math.abs(rel.Z) > half - 3 then return end
        if o and rel:Dot(o) < half - 46 then return end -- (from a trough: up to ~40 studs into the room)
        if DoorNear(q, 9) then return end
        local hot = depth == 0 or vr:NextNumber() < 0.12
        local seam = Lava.Flow(fx, p + Vector3.new(0, 0.3, 0), q + Vector3.new(0, 0.3, 0), w, { Light = false, Smoke = false, Sparks = false, Speed = 0.03,
            Tint = (not hot) and DARK or nil, Bright = hot and 1.9 or 1.1 })
        -- (optimization pass 2026-10-27: up to 70 beams a room; Graphics Quality Low keeps only the hot ones)
        if not hot then game:GetService("CollectionService"):AddTag(seam, "QDetail") end
        n += 1; cracks += 1
        if depth < (maxDepth or 4) then
            local turn = vr:NextNumber(0.25, 0.7)
            Crack(q, (CFrame.Angles(0, turn, 0) * CFrame.new(Vector3.zero, dir)).LookVector, math.max(0.35, w * 0.72), depth + 1, o, maxDepth)
            if vr:NextNumber() < 0.5 then Crack(q, (CFrame.Angles(0, -turn, 0) * CFrame.new(Vector3.zero, dir)).LookVector, math.max(0.35, w * 0.62), depth + 1, o, maxDepth) end
        end
    end
    local a0, a1
    for wi, sd in ipairs(walls) do
        local o = SIDES[sd]
        local al = Vector3.new(-o.Z, 0, o.X)
        local b0, b1 = Trough(sd, wi == 1 and 6.4 or 5, wi == 1 and 2 or 0)
        if wi == 1 then a0, a1 = b0, b1 end
        for _ = 1, b0 and vr:NextInteger(3, 4) or 0 do
            local start = b0:Lerp(b1, vr:NextNumber(0.1, 0.9)) - o * 3.6
            Crack(Vector3.new(start.X, F, start.Z), (-o + al * vr:NextNumber(-0.5, 0.5)).Unit, vr:NextNumber(1.2, 1.7), 0, o, 5)
        end
    end
    -- the doorway walls: a lava gutter on the clear stretch beside the door (no light: the main troughs carry the room)
    do
        local isT = {}
        for _, sd in ipairs(walls) do isT[sd] = true end
        for _, sd in ipairs(order) do
            if not isT[sd] then Trough(sd, 3.4, 0) end
        end
    end
    if not a0 then a0, a1 = C0 + tOut * (half - 4.5), C0 + tOut * (half - 4.5) end
    -- one wall only: a short trough across one corner of it
    if #walls == 1 then
        local s2 = (troughSide <= 2) and vr:NextInteger(3, 4) or vr:NextInteger(1, 2)
        local o2 = SIDES[s2]
        local corner = C0 + tOut * (half - 3) + o2 * (half - 3)
        if not DoorNear(corner, 22) then Sluice(corner - tOut * 15, corner - o2 * 15, 3.6, -(tOut + o2).Unit) end
    end
    -- CINDER / SLAG / ASH patches round the troughs (material only)
    -- (Paint is above in this module)
    if ctx.Terrain then
        for _ = 1, 4 do
            local p = a0:Lerp(a1, vr:NextNumber(0, 1)) - tOut * vr:NextNumber(4, 12)
            Paint(p.X, p.Z, vr:NextNumber(4, 8), ({ M.CrackedLava, M.Basalt, M.Slate })[vr:NextInteger(1, 3)], vr)
        end
    end
    -- THE OPEN FLOOR (pilot review: "the flat floor is 60-70% of every eye-height frame and reads as plain rock"): low detail
    -- that never blocks aim or movement -- all under 0.6 stud, no collision, no query
    do
        local function Spot(margin: number): Vector3
            return C0 + Vector3.new(vr:NextNumber(-1, 1) * (half - margin), 0, vr:NextNumber(-1, 1) * (half - margin))
        end
        -- big ground-colour blobs: crusted slag fields and dark basalt over the plain rock (terrain material only)
        if ctx.Terrain then
            for _ = 1, vr:NextInteger(5, 7) do
                local p = Spot(12)
                FieldPaint(p.X, p.Z, vr:NextNumber(9, 16), ({ M.CrackedLava, M.CrackedLava, M.Basalt, M.Slate })[vr:NextInteger(1, 4)], vr)
            end
        end
        -- vents: a small crusted pool in the open floor with its own crack network running off it
        for _ = 1, vr:NextInteger(2, 3) do
            local p = Spot(14)
            if not DoorNear(p, 14) then
                Lava.Pool(fx, CFrame.new(p + Vector3.new(0, 0.22, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0), vr:NextNumber(1, 1.6), { Light = false, Smoke = false, Sparks = false })
                n += 1
                for _ = 1, vr:NextInteger(3, 4) do
                    local a = vr:NextNumber(0, math.pi * 2)
                    Crack(p, Vector3.new(math.cos(a), 0, math.sin(a)), vr:NextNumber(0.7, 1.0), 1, nil, 4)
                end
            end
        end
        -- cooled obsidian / slag plates: thin glossy black slabs set into the floor
        for _ = 1, vr:NextInteger(4, 5) do
            local p = Spot(8)
            if not DoorNear(p, 10) then
                local cf = CFrame.new(p + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0)
                -- (an irregular shard, never one rectangle: review saw a "stray box"; terrain basalt round it)
                for _, sl in ipairs(A.Shard(fx, "SlagPlate", p, vr:NextNumber(2.5, 4.5), vr:NextNumber(0.12, 0.2), C3(16, 13, 15), M.SmoothPlastic, vr)) do
                    sl.Reflectance = 0.06 -- (more and the pool lights turned them into orange planks)
                end
                if ctx.Terrain then Paint(p.X, p.Z, vr:NextNumber(3, 5), M.Basalt, vr) end
                n += 3
            end
        end
        -- cinder scatter: small clumps, a few still glowing
        for _ = 1, 2 do
            local c = Spot(10)
            for _ = 1, vr:NextInteger(3, 4) do
                local glow = vr:NextNumber() < 0.35
                local sz = vr:NextNumber(0.35, 0.6)
                local cp = Part(fx, "Cinder", nil, Vector3.new(sz, sz * 0.7, sz * vr:NextNumber(0.8, 1.3)),
                    CFrame.new(c + Vector3.new(vr:NextNumber(-3, 3), sz * 0.2, vr:NextNumber(-3, 3))) * CFrame.Angles(vr:NextNumber(0, 6), vr:NextNumber(0, 6), vr:NextNumber(0, 6)),
                    glow and C3(190, 60, 20) or C3(34, 26, 24), glow and M.Neon or M.Basalt)
                cp.CastShadow = false
                n += 1
            end
        end
    end
    -- EDGE: a chimney at a corner on the trough side (outside the box), smoke + a glow at its mouth
    do
        local o2 = SIDES[(troughSide <= 2) and vr:NextInteger(3, 4) or vr:NextInteger(1, 2)]
        local base = C0 + tOut * (half + 10) + o2 * (half * 0.55)
        local h = vr:NextNumber(58, 72)
        local stone, iron = C3(44, 36, 34), C3(34, 29, 28)
        local up = CFrame.Angles(0, 0, math.rad(90))
        Part(fx, "Chimney", Enum.PartType.Cylinder, Vector3.new(h * 0.62, 12, 12), CFrame.new(base + Vector3.new(0, h * 0.31 - 2, 0)) * up, stone, M.Slate)
        Part(fx, "ChimneyUpper", Enum.PartType.Cylinder, Vector3.new(h * 0.4, 9, 9), CFrame.new(base + Vector3.new(0, h * 0.8 - 2, 0)) * up, stone, M.Slate)
        Part(fx, "ChimneyLip", Enum.PartType.Cylinder, Vector3.new(1.8, 10.4, 10.4), CFrame.new(base + Vector3.new(0, h - 2.4, 0)) * up, iron, M.CorrodedMetal)
        Part(fx, "ChimneyBand", Enum.PartType.Cylinder, Vector3.new(1.8, 13, 13), CFrame.new(base + Vector3.new(0, h * 0.6 - 2, 0)) * up, iron, M.CorrodedMetal)
        Lava.Glow(fx, base + Vector3.new(0, h - 1, 0), 26, C3(255, 120, 50), 0.35, { Name = "ChimneyGlow", MaxDistance = 1200 })
        local src = Carrier(fx, "ChimneySmoke", Vector3.new(6, 1, 6), CFrame.new(base + Vector3.new(0, h, 0)))
        local e = Instance.new("ParticleEmitter")
        e.Texture = "rbxasset://textures/particles/smoke_main.dds"; e.Color = ColorSequence.new(C3(70, 50, 44), C3(30, 26, 26))
        e.LightInfluence = 1; e.Rate = 3; e.Lifetime = NumberRange.new(7, 10); e.Speed = NumberRange.new(3, 5)
        e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 16) })
        e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
        e.Acceleration = Vector3.new(1.5, 0.8, 0); e.EmissionDirection = Enum.NormalId.Top
        e.Parent = src
        CollectionService:AddTag(e, "QThin")
        n += 4
    end
    -- EDGE: an iron girder over the opposite corner, above head height, with a chain + a glowing crucible on it
    do
        local fOut = -tOut
        local o2 = SIDES[(troughSide <= 2) and vr:NextInteger(3, 4) or vr:NextInteger(1, 2)]
        local corner = C0 + fOut * half + o2 * half
        local y = F + vr:NextNumber(24, 28)
        local pA = corner - fOut * 26 + fOut * 8 -- (on the wall line side o2, 18 studs from the corner, 8 past it)
        pA = Vector3.new(cx, 0, cz) + o2 * (half + 6) + fOut * (half - 22)
        local pB = Vector3.new(cx, 0, cz) + fOut * (half + 6) + o2 * (half - 22)
        pA = Vector3.new(pA.X, y, pA.Z); pB = Vector3.new(pB.X, y, pB.Z)
        local len = (pB - pA).Magnitude
        local cf = CFrame.lookAt((pA + pB) / 2, pB)
        local iron = C3(40, 35, 33)
        -- (two I-beams side by side, deep enough to read as steel from across the room)
        for gi, off in ipairs({ -2.6, 2.6 }) do
            local gcf = cf * CFrame.new(off, gi == 2 and 1.2 or 0, 0)
            Part(fx, "Girder", nil, Vector3.new(1.1, 5.2, len), gcf, iron, M.CorrodedMetal)
            Part(fx, "GirderFlange", nil, Vector3.new(3.4, 0.8, len), gcf * CFrame.new(0, 2.6, 0), iron, M.CorrodedMetal)
            Part(fx, "GirderFlangeB", nil, Vector3.new(3.4, 0.8, len), gcf * CFrame.new(0, -2.6, 0), iron, M.CorrodedMetal)
        end
        local hang = (pA + pB) / 2 + Vector3.new(0, -3, 0)
        local drop = vr:NextNumber(4, 6)
        Part(fx, "Chain", Enum.PartType.Cylinder, Vector3.new(drop, 0.8, 0.8), CFrame.new(hang - Vector3.new(0, drop / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), C3(30, 28, 28), M.Metal)
        local bucket = hang - Vector3.new(0, drop + 3.8, 0)
        Part(fx, "Crucible", Enum.PartType.Cylinder, Vector3.new(7.6, 9.4, 9.4), CFrame.new(bucket) * CFrame.Angles(0, 0, math.rad(90)), C3(48, 38, 34), M.CorrodedMetal)
        Part(fx, "CrucibleRim", Enum.PartType.Cylinder, Vector3.new(1, 10.4, 10.4), CFrame.new(bucket + Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), C3(34, 29, 28), M.Metal)
        local lid = Part(fx, "CrucibleMelt", Enum.PartType.Cylinder, Vector3.new(0.3, 8.2, 8.2), CFrame.new(bucket + Vector3.new(0, 3.95, 0)) * CFrame.Angles(0, 0, math.rad(90)), C3(255, 120, 40), M.Neon)
        lid.CastShadow = false
        Lava.Glow(fx, bucket + Vector3.new(0, 5, 0), 18, C3(255, 120, 50), 0.35, { Name = "CrucibleGlow", MaxDistance = 400 })
        n += 9
    end
    -- EDGE: foundry buttresses against the trough wall, standing in the rim (outside the box) -- the pool lights wash them
    do
        local o = tOut
        local al = Vector3.new(-o.Z, 0, o.X)
        for _, f in ipairs({ -0.34, 0.34 }) do
            local h = vr:NextNumber(30, 40)
            local base = C0 + o * (half + 3.5) + al * (f * half + vr:NextNumber(-3, 3))
            local cf = CFrame.lookAt(Vector3.new(base.X, F + h / 2 - 2.5, base.Z), Vector3.new(base.X, F + h / 2 - 2.5, base.Z) - o) -- (sunk: probe 0.8 over the rim) * CFrame.Angles(math.rad(vr:NextNumber(3, 7)), 0, 0)
            Part(fx, "Buttress", nil, Vector3.new(8.5, h, 6.5), cf, C3(46, 37, 34), M.Slate)
            Part(fx, "ButtressCap", nil, Vector3.new(9.8, 1.8, 7.8), cf * CFrame.new(0, h / 2 + 0.3, 0) * CFrame.Angles(0, 0, math.rad(vr:NextNumber(-9, 9))), C3(34, 29, 28), M.Basalt)
            n += 2
        end
        n += 7
    end
    -- SET PIECE: a tipped crucible against a wall (no door near), spilling a lava fall + pool
    do
        -- (a wall without a trough first; else the second trough's wall -- the pot then stands back over it and pours in)
        local isT = {}
        for _, sd in ipairs(walls) do isT[sd] = true end
        local cands = {}
        for _, sd in ipairs(order) do if not isT[sd] then table.insert(cands, sd) end end
        if walls[2] then table.insert(cands, walls[2]) end
        table.insert(cands, walls[1])
        -- (each wall tried at a few spots, the corners first: a door wall's middle is never clear)
        local tries = {}
        for _, s in ipairs(cands) do
            for _, f in ipairs({ 0.7, 0.55, 0.35 }) do
                local sg = vr:NextNumber() < 0.5 and -1 or 1
                table.insert(tries, { s, f * sg }); table.insert(tries, { s, -f * sg })
            end
        end
        for _, tr in ipairs(tries) do
            local s = tr[1]
            local placed = false
            do
                local out = SIDES[s]
                local along = Vector3.new(-out.Z, 0, out.X)
                local spot = C0 + out * (half - (isT[s] and 1.5 or 4)) + along * tr[2] * half
                if not DoorNear(spot, 28) then
                    placed = true
                    -- (pilot review: a pot tipped TOWARD the room showed its melt as a flat orange half-disc. Now it tips
                    -- SIDEWAYS along the wall -- you see the pot's flank from the room -- and pours a real stream: a narrow
                    -- hot core inside a wider glowing sheath, falling ~2 pot-heights, into a splash pool with sparks)
                    local S = 2.4 -- (pot ~19 long, ~20 across: reads from the far side of a 120-stud room)
                    local sgn = tr[2] > 0 and -1 or 1 -- (it pours toward the middle of the wall, away from the corner)
                    local th = math.rad(58)
                    local ax = (Vector3.yAxis * math.cos(th) + along * sgn * math.sin(th)).Unit
                    local body = Vector3.new(spot.X, F + 4.6 * S, spot.Z) + out * 1.2 * S
                    local cf = CFrame.fromMatrix(body, ax, out)
                    Part(fx, "BigCrucible", Enum.PartType.Cylinder, Vector3.new(8, 8.5, 8.5) * S, cf, C3(50, 40, 36), M.CorrodedMetal)
                    Part(fx, "BigCrucibleBand", Enum.PartType.Cylinder, Vector3.new(1.1, 9.1, 9.1) * S, cf * CFrame.new(-1.6 * S, 0, 0), C3(38, 32, 30), M.Metal)
                    Part(fx, "BigCrucibleLip", Enum.PartType.Cylinder, Vector3.new(0.8, 9.2, 9.2) * S, cf * CFrame.new(3.7 * S, 0, 0), C3(34, 29, 28), M.Metal)
                    -- (no melt disc: the mouth's lit face read as a flat sprite; a soft glow sits inside the mouth instead)
                    Lava.Glow(fx, body + ax * 3.2 * S, 3.4 * S, C3(255, 120, 40), 0.45, { Name = "MouthGlow", MaxDistance = 500 })
                    -- trunnion cradle: two posts at the pot's pivot, either side across the wall line
                    for side = -1, 1, 2 do
                        local post = Vector3.new(body.X, 0, body.Z) + out * side * 5.6 * S
                        local ph = 4.6 * S + 1.5
                        Part(fx, "CradlePost", nil, Vector3.new(1.4 * S, ph, 1.4 * S), CFrame.new(post + Vector3.new(0, ph / 2 + F - 2.2, 0)), C3(38, 32, 30), M.CorrodedMetal)
                    end
                    Part(fx, "CradleAxle", Enum.PartType.Cylinder, Vector3.new(11.8 * S, 0.9 * S, 0.9 * S), CFrame.fromMatrix(body, out, Vector3.yAxis), C3(30, 28, 28), M.Metal)
                    -- the stream: from the low edge of the mouth straight down
                    local mouth = body + ax * 4.1 * S
                    local lip = mouth + along * sgn * 2.2 * S - Vector3.new(0, 2.8 * S, 0)
                    local foot = Vector3.new(lip.X, F + 0.15, lip.Z)
                    local hgt = lip.Y - foot.Y
                    local mid = (lip + foot) / 2
                    local core = Part(fx, "PourCore", Enum.PartType.Cylinder, Vector3.new(hgt, 1.1 * S, 1.1 * S), CFrame.new(mid) * CFrame.Angles(0, 0, math.rad(90)), C3(255, 170, 70), M.Neon)
                    local sheath = Part(fx, "PourSheath", Enum.PartType.Cylinder, Vector3.new(hgt, 1.9 * S, 1.9 * S), CFrame.new(mid) * CFrame.Angles(0, 0, math.rad(90)), C3(255, 90, 20), M.Neon)
                    sheath.Transparency = 0.55
                    core.CastShadow = false; sheath.CastShadow = false
                    for g = 1, 3 do
                        Lava.Glow(fx, foot:Lerp(lip, (g - 0.5) / 3), 5 * S, C3(255, 120, 40), 0.35, { Name = "PourGlow", MaxDistance = 600 })
                    end
                    Lava.Pool(fx, CFrame.new(foot + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, vr:NextNumber(0, 6.28), 0), 2.6 * S, { Light = 26, Smoke = false, Sparks = true })
                    local sp = Carrier(fx, "PourSplash", Vector3.new(1, 1, 1), CFrame.new(foot + Vector3.new(0, 0.6, 0)))
                    local e = Instance.new("ParticleEmitter")
                    e.Texture = "rbxasset://textures/particles/sparkles_main.dds"; e.Color = ColorSequence.new(C3(255, 210, 110), C3(255, 70, 20))
                    e.LightEmission = 1; e.LightInfluence = 0; e.Rate = 10
                    e.Lifetime = NumberRange.new(0.5, 1); e.Speed = NumberRange.new(8, 14); e.SpreadAngle = Vector2.new(70, 70)
                    e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
                    e.Acceleration = Vector3.new(0, -30, 0); e.EmissionDirection = Enum.NormalId.Top
                    e.Parent = sp
                    CollectionService:AddTag(e, "QThin")
                    n += 9
                end
            end
            if placed then break end
        end
    end
    return n
end

return B
