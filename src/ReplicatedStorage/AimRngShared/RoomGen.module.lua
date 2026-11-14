--!nocheck
-- ============================================================================================
-- ROOM GEN (0.86, owner: "I want rooms to be procedurally generated. Maps should have random aspects so they dont get
-- stale" -> "Do number one [the full generator], just ensure that it doesnt look bad or place things that get in the way
-- of aiming"). Replaces the six hand-made traversal layouts on every non-boss floor.
--
-- PLAN (pure data, deterministic from the rng -> party servers, clients and spectators build the same room):
--   * a SHAPE: Open / Hall (side massifs: a long hall) / Cross (corner massifs) / Split (a raised terrace down one side) /
--     Canyon (a ridge down one side) / Courtyard (a broken ring of low walls round the plaza)
--   * SYMMETRY: mirrored across the spine (most rooms) or free
--   * PIECES on a 4-stud grid: low walls (straight / L, waist high: you aim OVER them), biome cover props, a few tall
--     blocks (only out at the sides, spaced apart), raised decks with a ramp + low parapet
--   * always CLEAR: the spine (entrance -> plaza -> portals, |x| <= 9), the plaza (chest + landmark), the portal block,
--     both doorways, the corner pillars when the room keeps them, a margin along the walls
--   * VALIDATED: every free cell must be reachable from the entrance (no sealed pockets), the portal and plaza
--     reachable, the room <= 34% blocked; a failed roll re-rolls (8 tries, then a plain Open room)
-- BUILD: real arena coordinates (no design-size shrink: pieces keep true proportions), the biome's surfaces and its own
-- cover props. On solo open maps MapShell.Terrainify turns the solid pieces into same-shape terrain rock afterwards.
-- ============================================================================================
local RoomGen = {}
RoomGen.CELL = 4
RoomGen.SPINE = 9 -- (|x| <= this stays clear the whole length of the room)
RoomGen.PLAZA = 24 -- (nothing within this of the centre: chest + landmark)
RoomGen.PORTAL = { X = 46, Z0 = 4, Z1 = 44 } -- (the portal block, x +-X, z Z0..Z1)
RoomGen.DOOR = { X = 22, Depth = 20 } -- (the north doorway: |x| < X within Depth of the north wall)
RoomGen.MAX_BLOCKED = 0.34
RoomGen.SHAPES = { -- weight
    { Id = "Open", W = 3 }, { Id = "Hall", W = 2 }, { Id = "Cross", W = 2 }, { Id = "Split", W = 2 }, { Id = "Canyon", W = 2 }, { Id = "Courtyard", W = 2 },
}
-- (a map's fixed layout name -> its shape: every floor of that map shares a shape, the pieces still roll per floor)
RoomGen.LAYOUT_SHAPE = { Gauntlet = "Hall", Towers = "Canyon", Ring = "Courtyard", Pillars = "Open", Terraces = "Split", Bunkers = "Cross" }

local function Pick(rng: Random, list: { any }): any
    local total = 0
    for _, e in ipairs(list) do total += e.W end
    local r = rng:NextNumber() * total
    for _, e in ipairs(list) do
        r -= e.W
        if r <= 0 then return e end
    end
    return list[#list]
end

-- axis-aligned half extents of a w x d rectangle turned by yaw (radians)
local function HalfAABB(w: number, d: number, yaw: number): (number, number)
    local c, s = math.abs(math.cos(yaw)), math.abs(math.sin(yaw))
    return (c * w + s * d) / 2, (s * w + c * d) / 2
end

-- ===================== PLAN =====================
function RoomGen.Plan(rng: Random, arena: number, opts: any?): any
    opts = opts or {}
    local half = arena / 2
    local C = RoomGen.CELL
    local n = math.floor(arena / C)
    local function Cell(v: number): number return math.clamp(math.floor((v + half) / C), 0, n - 1) end
    local function Centre(i: number): number return -half + (i + 0.5) * C end

    local function Keep(x: number, z: number, piece: boolean, keepPillars: boolean): boolean
        if math.abs(x) <= RoomGen.SPINE then return true end
        if x * x + z * z < RoomGen.PLAZA * RoomGen.PLAZA then return true end
        local P = RoomGen.PORTAL
        if math.abs(x) < P.X and z > P.Z0 and z < P.Z1 then return true end
        if math.abs(x) < RoomGen.DOOR.X and z < -half + RoomGen.DOOR.Depth then return true end
        if piece and (math.abs(x) > half - 5 or math.abs(z) > half - 5) then return true end
        if keepPillars then
            for _, sx in ipairs({ -1, 1 }) do
                for _, sz in ipairs({ -1, 1 }) do
                    local dx, dz = x - sx * 50, z - sz * 50
                    if dx * dx + dz * dz < 11 * 11 then return true end
                end
            end
        end
        return false
    end

    for attempt = 1, 9 do
        local shape = opts.Shape or (attempt <= 8 and Pick(rng, RoomGen.SHAPES).Id or "Open")
        if attempt == 9 then shape = "Open" end
        local plan = { Shape = shape, Mirror = rng:NextNumber() < 0.62, Pieces = {}, Pillars = true, Arena = arena }
        local occ: { [number]: boolean } = {}
        local function Key(i: number, j: number): number return i * 1000 + j end
        local function Mark(x0, z0, x1, z1)
            for i = Cell(x0), Cell(x1) do for j = Cell(z0), Cell(z1) do occ[Key(i, j)] = true end end
        end
        -- can a footprint (centre x, z; half extents hx, hz) go here?
        local function Fits(x: number, z: number, hx: number, hz: number, pad: number): boolean
            if math.abs(x) + hx > half - 2 or math.abs(z) + hz > half - 2 then return false end
            for i = Cell(x - hx - pad), Cell(x + hx + pad) do
                for j = Cell(z - hz - pad), Cell(z + hz + pad) do
                    if occ[Key(i, j)] then return false end
                end
            end
            -- the keep zones on the footprint itself (+1)
            for i = Cell(x - hx - 1), Cell(x + hx + 1) do
                for j = Cell(z - hz - 1), Cell(z + hz + 1) do
                    if Keep(Centre(i), Centre(j), true, plan.Pillars) then return false end
                end
            end
            return true
        end
        local function Add(p: any, hx: number, hz: number)
            table.insert(plan.Pieces, p)
            Mark(p.X - hx, p.Z - hz, p.X + hx, p.Z + hz)
        end
        -- place a piece and (mirrored rooms) its twin across the spine; both or neither
        local function Place(p: any, hx: number, hz: number, pad: number): boolean
            if not Fits(p.X, p.Z, hx, hz, pad) then return false end
            if plan.Mirror then
                if not Fits(-p.X, p.Z, hx, hz, pad) then return false end
                Add(p, hx, hz)
                local q = table.clone(p)
                q.X = -p.X
                q.Yaw = -(p.Yaw or 0)
                q.Flip = not p.Flip
                Add(q, hx, hz)
            else
                Add(p, hx, hz)
            end
            return true
        end
        -- (0.87) space the caller already filled (the plaza landmark): occupied before anything is placed
        for _, b in ipairs(opts.Blocked or {}) do Mark(b.X - b.R, b.Z - b.R, b.X + b.R, b.Z + b.R) end
        local function Massif(x0, z0, x1, z1, h)
            local p = { Kind = "Massif", X = (x0 + x1) / 2, Z = (z0 + z1) / 2, W = x1 - x0, D = z1 - z0, H = h, Yaw = 0 }
            table.insert(plan.Pieces, p)
            Mark(x0, z0, x1, z1)
        end

        -- ---- the SHAPE ----
        local tallBudget, deckBudget, lowBudget, coverBudget = rng:NextInteger(0, 2), rng:NextInteger(0, 2), rng:NextInteger(4, 7), rng:NextInteger(2, 5)
        if shape == "Hall" then
            local w = rng:NextNumber(12, 15)
            local h = rng:NextNumber(18, 26)
            for _, sx in ipairs({ -1, 1 }) do
                local x0, x1 = (sx < 0) and -half or half - w, (sx < 0) and -half + w or half
                Massif(x0, -half, x1, half, h)
            end
            plan.Pillars = false
            tallBudget = 0
        elseif shape == "Cross" then
            local s = rng:NextNumber(17, 22)
            local h = rng:NextNumber(16, 24)
            for _, sx in ipairs({ -1, 1 }) do
                Massif((sx < 0) and -half or half - s, -half, (sx < 0) and -half + s or half, -half + s, h)
                local sw = math.min(s, half - RoomGen.PORTAL.X) -- (south corners stop short of the portal block)
                Massif((sx < 0) and -half or half - sw, half - s, (sx < 0) and -half + sw or half, half, h)
            end
            plan.Pillars = false
        elseif shape == "Split" then
            -- a raised terrace down one side, two ramps up, a low parapet on its edge
            local side = (rng:NextNumber() < 0.5) and -1 or 1
            local w, h = rng:NextNumber(16, 20), rng:NextNumber(6, 9)
            local x = side * (half - w / 2)
            local z0, z1 = -half + 6, half - 6
            table.insert(plan.Pieces, { Kind = "Terrace", X = x, Z = (z0 + z1) / 2, W = w, D = z1 - z0, H = h, Side = side,
                Ramps = { -half * 0.42, half * 0.05 } })
            Mark(x - w / 2 - 12, z0, x + w / 2, z1) -- (the ramps run inward up to 12 off the face)
            plan.Mirror = false
            plan.Pillars = false
        elseif shape == "Canyon" then
            local side = (rng:NextNumber() < 0.5) and -1 or 1
            local w = rng:NextNumber(14, 18)
            local zEnd = rng:NextNumber(-6, 4)
            Massif((side < 0) and -half or half - w, -half, (side < 0) and -half + w or half, zEnd, rng:NextNumber(20, 30))
            -- the other side gets a short spur near the south
            local w2 = math.min(w * 0.8, half - RoomGen.PORTAL.X)
            Massif((side > 0) and -half or half - w2, half - 22, (side > 0) and -half + w2 or half, half, rng:NextNumber(14, 20))
            plan.Mirror = false
            plan.Pillars = false
            tallBudget = math.min(tallBudget, 1)
        elseif shape == "Courtyard" then
            -- a broken ring of low walls round the plaza (gaps at the spine and the sides)
            local r = rng:NextNumber(32, 38)
            for _, a in ipairs({ 200, 235, 270, 305, 340 }) do
                local ang = math.rad(a + rng:NextNumber(-6, 6))
                local x, z = math.cos(ang) * r, math.sin(ang) * r
                if math.abs(x) > RoomGen.SPINE + 6 and not Keep(x, z, true, true) then
                    local yaw = -ang + math.pi / 2
                    local hx, hz = HalfAABB(11, 2.6, yaw)
                    if Fits(x, z, hx, hz, 2) then Add({ Kind = "Low", X = x, Z = z, L = 11, H = rng:NextNumber(3.6, 4.4), Yaw = yaw }, hx, hz) end
                end
            end
            plan.Mirror = false
            lowBudget = math.max(2, lowBudget - 3)
        end

        -- (Studio test hook, UPDATE 4 wrap-up: workspace attr DevTall = every room gets its 2 tall pillars to look at)
        if game:GetService("RunService"):IsStudio() and workspace:GetAttribute("DevTall") and shape ~= "Hall" then tallBudget = 2 end
        -- ---- the PIECES ----
        local function TryMany(count: number, make: () -> (any, number, number, number))
            local placed, tries = 0, 0
            while placed < count and tries < count * 14 do
                tries += 1
                local p, hx, hz, pad = make()
                if p and Place(p, hx, hz, pad) then placed += (plan.Mirror and 2 or 1) end
            end
        end
        local function RandX(minAbs: number): number
            local x = rng:NextNumber(minAbs, half - 8)
            if plan.Mirror then return x end
            return (rng:NextNumber() < 0.5) and -x or x
        end
        -- raised decks (out at the sides, a ramp toward the middle)
        TryMany(deckBudget, function()
            local w, d = rng:NextNumber(14, 19), rng:NextNumber(12, 16)
            local h = rng:NextNumber(4.5, 7)
            local x, z = RandX(26), rng:NextNumber(-half + 22, half - 50)
            -- the ramp runs from the deck's inner face toward the spine
            local inward = (x > 0) and -1 or 1
            local rampLen = h * 2.6
            -- the footprint covers deck + ramp (X = its centre; DeckX = the deck's own centre)
            local hx, hz = (w + rampLen) / 2, d / 2
            return { Kind = "Deck", X = x + inward * rampLen / 2, Z = z, W = w, D = d, H = h, Ramp = rampLen, Inward = inward, DeckX = x }, hx, hz, 6
        end)
        -- tall blocks: few, at the sides, spaced apart (peek cover that never stands in the middle of a fight)
        local talls = {}
        TryMany(tallBudget, function()
            local s = rng:NextNumber(6, 8.5)
            local x, z = RandX(30), rng:NextNumber(-half + 16, half - 16)
            for _, t in ipairs(talls) do
                if (t.X - x) ^ 2 + (t.Z - z) ^ 2 < 30 * 30 then return nil, 0, 0, 0 end
            end
            local p = { Kind = "Tall", X = x, Z = z, W = s, H = rng:NextNumber(12, 19), Yaw = (rng:NextNumber() < 0.3) and math.rad(45) or 0 }
            table.insert(talls, p)
            local hx, hz = HalfAABB(s + 1.6, s + 1.6, p.Yaw)
            return p, hx, hz, 7
        end)
        -- low walls: the main cover (waist high, straight or L)
        TryMany(lowBudget, function()
            local L = rng:NextNumber(10, 20)
            local yaw = ({ 0, math.pi / 2, 0, math.pi / 2, math.rad(30), math.rad(-30), math.rad(60) })[rng:NextInteger(1, 7)]
            local x, z = RandX(RoomGen.SPINE + 6), rng:NextNumber(-half + 14, half - 14)
            local arm = (rng:NextNumber() < 0.35) and rng:NextNumber(6, 9) or nil
            local hx, hz = HalfAABB(L + (arm and 2 or 0), arm and (arm * 2 + 2.6) or 2.6, yaw)
            return { Kind = "Low", X = x, Z = z, L = L, H = rng:NextNumber(3.5, 4.6), Yaw = yaw, Arm = arm }, hx, hz, 5
        end)
        -- the biome's own cover props (crates, ruined walls, crystals ...)
        TryMany(coverBudget, function()
            local x, z = RandX(RoomGen.SPINE + 8), rng:NextNumber(-half + 14, half - 14)
            return { Kind = "Cover", X = x, Z = z }, 6, 6, 5
        end)

        -- ---- VALIDATE: no sealed pockets, the portal + plaza reachable, not too full ----
        local free, blocked = 0, 0
        local function Walk(i: number, j: number): boolean
            return i >= 0 and j >= 0 and i < n and j < n and not occ[Key(i, j)]
        end
        for i = 0, n - 1 do
            for j = 0, n - 1 do
                if occ[Key(i, j)] then blocked += 1 else free += 1 end
            end
        end
        local seen, queue, head = {}, { { Cell(0), Cell(-half + 8) } }, 1
        seen[Key(Cell(0), Cell(-half + 8))] = true
        local reached = 1
        while head <= #queue do
            local c = queue[head]
            head += 1
            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                local i, j = c[1] + d[1], c[2] + d[2]
                local k = Key(i, j)
                if not seen[k] and Walk(i, j) then
                    seen[k] = true
                    reached += 1
                    table.insert(queue, { i, j })
                end
            end
        end
        local ok = seen[Key(Cell(0), Cell(30))] and seen[Key(Cell(0), Cell(0))]
            and reached >= free * 0.97 and blocked / (n * n) <= RoomGen.MAX_BLOCKED
        plan.Stats = { Free = free, Blocked = blocked, Reached = reached, Attempt = attempt }
        if ok then return plan end
    end
    return { Shape = "Open", Mirror = false, Pieces = {}, Pillars = true, Arena = arena, Stats = { Attempt = 10 } }
end

-- ===================== BUILD =====================
-- ctx = { geo, theme, propSet, rng, zC, F (floor top), Block, Ramp, Shade }
-- returns reserved spots for the prop passes ({ Pos, R })
-- COVER STYLE (UPDATE 4: the low walls, pillars and massifs were plain blocks with a trim cap -- "the plainest-looking
-- things on screen" next to the scanned props). Each piece is dressed in its biome's own style, read off the wall
-- material: MASONRY (stone / ice / brick / concrete): stones of uneven lengths and shades, set-back joints, separate
-- capstones, now and then a broken end stepped down with its capstone fallen beside it; TECH (metal / plastic): a
-- panelled body between end posts, a bevelled cap, a lit seam in the shadow of the plinth; TIMBER (wood): plank faces
-- on a post frame under a top rail. Same footprints, heights (3.5-4.6: you aim over) and solid colliders as before.
-- The look draws on its own seeded stream (the layout rng draws exactly what it always did: same rooms, same props).
-- Pieces carry a Shade attribute (MapShell.Terrainify gives them the ground rock's colour x that shade on open maps)
-- and dressing that would sit on terrain rock is RockTrim (hidden on terrain maps, kept on server-built floors).
local MAT = Enum.Material
RoomGen.STYLE = {
    [MAT.Metal] = "Tech", [MAT.SmoothPlastic] = "Tech", [MAT.DiamondPlate] = "Tech", [MAT.CorrodedMetal] = "Tech",
    [MAT.Foil] = "Tech", [MAT.Plastic] = "Tech", [MAT.Glass] = "Tech", [MAT.Neon] = "Tech",
    [MAT.Wood] = "Timber", [MAT.WoodPlanks] = "Timber",
}
function RoomGen.StyleOf(theme: any): string
    return RoomGen.STYLE[theme.Wall.Material] or "Masonry"
end
local function Scale(c: Color3, k: number): Color3
    return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

-- ===================== WORLD DRESS (UPDATE 4 wrap-up; WORLDS agent: "the plain brick Tall massifs read as blocks next to
-- the real props", owner's bar "breathtaking and intentional") =====================
-- Each biome dresses its room pieces in its own language, on top of the cover style above. NOTHING about play changes:
-- the colliders are the same parts at the same sizes; the dressing never collides or takes shots.
--   Stone = the cover stone (MapShell.Terrainify's material for every room piece: terrain rock on solo maps, part stone
--           on party floors). The default (the rim's first material) put square GRASS / SAND / MUD pillars and grass
--           walls in half the worlds.
--   Crown = a real model from the world's own kit standing on top of every Tall pillar (a shrine lantern on a stone
--           pier, an angel on a cemetery column ...): { World | Kit, Name, Fit (share of the pillar width), MaxH }.
--   Built = (masonry worlds) the pieces stay BUILT stone on solo terrain maps too (Keep), as party floors show them.
--   Clad  = the Tall pillar IS a real model of the world (a carved glyph pillar, a basalt column cluster), stretched to
--           the pillar's exact box: its drums stay as invisible colliders, no terrain rock is filled.
-- The 12 worlds bring theirs in their module (W.Cover -> WorldBiomes.Cover); the original biomes are here (EnvKit sets).
-- Tech (Station / Cyber) and timber (Bayou) pieces keep their built look and take a crown only.
RoomGen.DRESS = {
    Fire = { Clad = { Kit = "Fire", Name = "BasaltColsA" } },
    Ice = { Crown = { Kit = "Ice", Name = "IceCrystalsB", Fit = 0.95, MaxH = 7, Alt = { "FrozenStatue", "Pine" } } },
    Void = { Crown = { Kit = "Void", Name = "VoidCrystalsA", Fit = 0.95, MaxH = 7, Alt = { "VoidStatue", "BrokenObelisk" } } },
    Storm = { Crown = { Kit = "Storm", Name = "RodStone", Fit = 0.45, MaxH = 7.5, Alt = { "StruckTree", "Stump" } } },
    -- (Neon Flats' sandstone mesa pillars, Dreamscape's salt + glacier and the Cyber tech columns read as their world already)
}
local WB_COVER = nil
function RoomGen.DressFor(biome: string?): any?
    if not biome then return nil end
    -- (Studio before / after hook: workspace attr DevNoDress = the plain pieces)
    if game:GetService("RunService"):IsStudio() and workspace:GetAttribute("DevNoDress") then return nil end
    if WB_COVER == nil then
        local ok, wb = pcall(function() return require(script.Parent:WaitForChild("WorldBiomes")) end)
        WB_COVER = (ok and wb.Cover) or false
    end
    return (WB_COVER and WB_COVER[biome]) or RoomGen.DRESS[biome]
end
-- a dress model's template (WorldProps.<World>.<Name> or EnvKit.<Kit>.<Name>); nil in an unsaved place -> no dress
local function DressTemplate(spec: any): Model?
    local RS = game:GetService("ReplicatedStorage")
    local root = spec.World and RS:FindFirstChild("WorldProps") or RS:FindFirstChild("EnvKit")
    local set = root and root:FindFirstChild(spec.World or spec.Kit)
    local m = set and set:FindFirstChild(spec.Name)
    return (m and m:IsA("Model")) and m or nil
end
-- a clone that never collides, takes shots or gets turned to rock (WP: MapShell.Terrainify leaves world pieces alone)
local function DressClone(t: Model, shadow: boolean): Model
    local m = t:Clone()
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") then
            p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = shadow
            p:SetAttribute("WP", true)
            if p.Material == Enum.Material.Neon then p:SetAttribute("KeepNeon", true) end -- (NeonTamer: a lit lantern stays lit)
        end
    end
    m:SetAttribute("WP", true)
    m:SetAttribute("RoomDress", true)
    return m
end
-- stretch a model so its bounding box is exactly `size`, its bottom centre on `cf` (per axis: MeshParts take any size)
local function FitBox(m: Model, cf: CFrame, size: Vector3)
    local bbCF, bb = m:GetBoundingBox()
    local k = Vector3.new(size.X / math.max(bb.X, 0.01), size.Y / math.max(bb.Y, 0.01), size.Z / math.max(bb.Z, 0.01))
    local base = bbCF * CFrame.new(0, -bb.Y / 2, 0)
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") then
            local rel = base:ToObjectSpace(p.CFrame)
            local r = rel.Rotation
            -- (a part turned inside the model: scale its own axes by the model axes it lies along)
            local ax = Vector3.new(math.abs(r.RightVector.X), math.abs(r.RightVector.Y), math.abs(r.RightVector.Z))
            local ay = Vector3.new(math.abs(r.UpVector.X), math.abs(r.UpVector.Y), math.abs(r.UpVector.Z))
            local az = Vector3.new(math.abs(r.LookVector.X), math.abs(r.LookVector.Y), math.abs(r.LookVector.Z))
            p.Size = Vector3.new(p.Size.X * ax:Dot(k), p.Size.Y * ay:Dot(k), p.Size.Z * az:Dot(k))
            p.CFrame = cf * CFrame.new(rel.Position * k) * r
        end
    end
end

function RoomGen.Build(plan: any, ctx: any): { any }
    local geo, theme, zC, F, Block = ctx.geo, ctx.theme, ctx.zC, ctx.F, ctx.Block
    local Shade = ctx.Shade or function(s) return s end
    local rng = ctx.rng
    local reserved = {}
    local style = RoomGen.StyleOf(theme)
    -- (WORLD DRESS Built: a built world -- skyport, temples, shrine, cemetery -- keeps its masonry as BUILT stone on solo
    -- terrain maps too, as party floors always showed it; natural worlds still turn it into terrain rock)
    local built = ctx.Dress and ctx.Dress.Built and style == "Masonry"
    local vr = Random.new(math.floor(zC) * 7 + #plan.Pieces * 131 + #tostring(plan.Shape) * 17 + (ctx.Seed or 0)) -- (the look's own stream)
    RoomGen._crownN = 0 -- (MAPVIBE: crowns counted per room)
    local wallMat = theme.Wall.Material
    local trimC, trimMat = theme.WallTrim.Color, theme.WallTrim.Material
    local accent = { Color = theme.Accent:Lerp(Color3.new(0, 0, 0), 0.45), Material = Enum.Material.Neon }
    local xC = ctx.xC or 0 -- (LINKED ROOMS pilot: a room off the x = 0 axis -- the side room)
    local function R(x, z, r) table.insert(reserved, { Pos = Vector3.new(xC + x, 0, zC + z), R = r }) end
    local function W(x, z) return Vector3.new(xC + x, F, zC + z) end
    local collect = nil -- (WORLD DRESS: the parts of the piece being built, while a dress needs them)
    local function Glow(size: Vector3, cf: CFrame)
        local g = Block(geo, size, cf, accent)
        g.CanCollide = false
        g.CanQuery = false
        if collect then table.insert(collect, g) end
        return g
    end

    -- trims on pieces that turn into terrain rock on solo maps (MapShell.Terrainify hides these there: thin bands left
    -- over the rock read as picture frames)
    local function Trim(size: Vector3, cf: CFrame, surf: any)
        local t = Block(geo, size, cf, surf)
        t:SetAttribute("RockTrim", true)
        if built then t:SetAttribute("Keep", true) end
        if collect then table.insert(collect, t) end
        return t
    end

    -- one dressed piece: k = its shade (kept as an attribute for Terrainify); solid = a collider (else loose rubble)
    local function Piece(size: Vector3, cf: CFrame, col: Color3, mat: Enum.Material, k: number, solid: boolean?, class: string?)
        local p = Block(geo, size, cf, { Color = Scale(col, k), Material = mat }, class)
        if collect then table.insert(collect, p) end
        p:SetAttribute("Shade", k)
        if style ~= "Masonry" or built then p:SetAttribute("Keep", true) end -- (wood / tech / built dressing keeps its own look on open maps)
        if solid == false then
            p.CanCollide = false
            p.CastShadow = false
        end
        return p
    end
    local capMat = (wallMat == MAT.Brick) and MAT.Concrete or wallMat -- (brick courses under stone copings)

    local function MasonryWall(cf: CFrame, len: number, h: number, depth: number, base: Color3)
        local n = math.max(2, math.floor(len / 4.2 + 0.5))
        local ws, sum = {}, 0
        for i = 1, n do ws[i] = vr:NextNumber(0.75, 1.25); sum += ws[i] end
        local broken = (len >= 8 and vr:NextNumber() < 0.6) and (vr:NextNumber() < 0.5 and 1 or n) or 0
        local x = -len / 2
        for i = 1, n do
            local w = ws[i] / sum * len
            local cx = x + w / 2
            local k = vr:NextNumber(0.84, 1.08)
            local d = (i % 2 == 0) and depth or depth - 0.16 -- (alternate stones set back: the joints read)
            if i == broken then
                local e = (i == 1) and -1 or 1
                local bh = h * vr:NextNumber(0.62, 0.74)
                Piece(Vector3.new(w, bh, d), cf * CFrame.new(cx, bh / 2, 0), base, wallMat, k)
                -- the break: a stub slanting down to the end, its capstone fallen beside the wall
                local wl, wh = math.min(w * 0.7, 3), (h - bh) * 0.8
                Piece(Vector3.new(d - 0.12, wh, wl), cf * CFrame.new(cx - e * (w / 2 - wl / 2), bh + wh / 2, 0) * CFrame.Angles(0, -e * math.pi / 2, 0),
                    base, wallMat, k, true, "WedgePart")
                local side = vr:NextNumber() < 0.5 and -1 or 1
                Piece(Vector3.new(w * 0.6, 0.42, 1.3), cf * CFrame.new(cx + e * 0.5, 0.2, side * (depth / 2 + 0.95))
                    * CFrame.Angles(vr:NextNumber(-0.12, 0.12), vr:NextNumber(-0.5, 0.5), vr:NextNumber(-0.2, 0.2)), base, capMat, k * 1.1, false)
            else
                local top = h - vr:NextNumber(0, 0.05)
                local ct = (i % 2 == 0) and 0.42 or 0.48 -- (neighbouring capstones never share a plane)
                local sunk = vr:NextNumber() < 0.22 -- (a worn capstone settled out of line)
                Piece(Vector3.new(w, top, d), cf * CFrame.new(cx, top / 2, 0), base, wallMat, k)
                Piece(Vector3.new(w - 0.08, ct, depth + 0.3 + (i % 2) * 0.08), cf * CFrame.new(cx, top + ct / 2 - (sunk and 0.05 or 0), vr:NextNumber(-0.05, 0.05))
                    * CFrame.Angles(sunk and vr:NextNumber(-0.05, 0.05) or 0, vr:NextNumber(-0.02, 0.02), sunk and vr:NextNumber(-0.035, 0.035) or 0),
                    base, capMat, math.min(k * 1.12 + 0.04, 1.3))
            end
            x += w
        end
        for _ = 1, (len > 10 and 2 or 1) do -- (chips at the foot)
            local r = vr:NextNumber(0.45, 0.85)
            Piece(Vector3.new(r * 1.3, r * 0.8, r), cf * CFrame.new(vr:NextNumber(-len / 2 + 1, len / 2 - 1), r * 0.3, (vr:NextNumber() < 0.5 and -1 or 1) * (depth / 2 + 0.25 + r * 0.4))
                * CFrame.Angles(vr:NextNumber(-0.4, 0.4), vr:NextNumber(0, 6.28), vr:NextNumber(-0.4, 0.4)), base, wallMat, 0.9, false)
        end
    end

    local function TechWall(cf: CFrame, len: number, h: number, depth: number, base: Color3)
        local bl = math.max(len - 1.3, 1)
        local gh = 0.7 -- (the plinth: narrower, the lit seam in its shadow)
        local bh = h - gh - 0.3
        Piece(Vector3.new(bl, gh, depth - 0.5), cf * CFrame.new(0, gh / 2, 0), trimC, trimMat, 0.9)
        Piece(Vector3.new(bl, bh, depth), cf * CFrame.new(0, gh + bh / 2, 0), base, wallMat, 1)
        Piece(Vector3.new(bl, 0.3, depth - 0.5), cf * CFrame.new(0, h - 0.15, 0), trimC, trimMat, 1.05)
        for _, sd in ipairs({ -1, 1 }) do
            -- bevels along the cap (low edge outward), end posts standing proud, face panels, the seam
            Piece(Vector3.new(bl, 0.3, 0.25), cf * CFrame.new(0, h - 0.15, sd * (depth / 2 - 0.125)) * CFrame.Angles(0, sd == 1 and math.pi or 0, 0),
                trimC, trimMat, 1.05, true, "WedgePart")
            Piece(Vector3.new(0.65, h + 0.2, depth + 0.3), cf * CFrame.new(sd * (len / 2 - 0.325), (h + 0.2) / 2, 0), trimC, trimMat, 0.95)
            local np = bl > 9 and 2 or 1
            local pl = bl / np
            for j = 1, np do
                Piece(Vector3.new(pl - 0.5, bh - 0.7, 0.14), cf * CFrame.new(-bl / 2 + pl * (j - 0.5), gh + bh / 2, sd * depth / 2), base, wallMat, 1.14)
            end
            Glow(Vector3.new(bl - 0.4, 0.14, 0.1), cf * CFrame.new(0, gh * 0.5, sd * (depth / 2 - 0.2)))
        end
    end

    local function TimberWall(cf: CFrame, len: number, h: number, depth: number, base: Color3)
        Piece(Vector3.new(len - 0.4, h - 0.35, depth - 0.9), cf * CFrame.new(0, (h - 0.35) / 2, 0), base, wallMat, 0.62) -- (the dark core)
        local posts = len > 10 and 3 or 2
        for j = 0, posts - 1 do
            local ph = h + vr:NextNumber(0.1, 0.45)
            Piece(Vector3.new(0.8, ph, depth), cf * CFrame.new(-len / 2 + 0.4 + (len - 0.8) * j / (posts - 1), ph / 2, 0)
                * CFrame.Angles(0, vr:NextNumber(-0.06, 0.06), 0), base, wallMat, vr:NextNumber(0.8, 0.95))
        end
        local rows = 3
        local rh = (h - 0.5) / rows
        for _, sd in ipairs({ -1, 1 }) do
            for r = 1, rows do
                Piece(Vector3.new(len - 0.7 - vr:NextNumber(0, 0.5), rh - 0.1, 0.22), cf * CFrame.new(vr:NextNumber(-0.2, 0.2), 0.25 + rh * (r - 0.5), sd * (depth / 2 - 0.34))
                    * CFrame.Angles(0, 0, vr:NextNumber(-0.012, 0.012)), base, MAT.WoodPlanks, vr:NextNumber(0.85, 1.1))
            end
        end
        Piece(Vector3.new(len - 0.2, 0.3, depth - 0.5), cf * CFrame.new(0, h - 0.2, 0), base, wallMat, 0.95)
    end

    local WALL = { Masonry = MasonryWall, Tech = TechWall, Timber = TimberWall }
    local function LowWall(cf: CFrame, len: number, h: number)
        local base = Shade(theme.Wall, rng).Color -- (the one layout-rng draw it always made)
        WALL[style](cf, len, h, 2.4, base)
    end

    -- a big block's face dressed by its length (a 120-stud massif face must not read as one slab): MASONRY buttresses
    -- every ~13 studs under sloped caps + a few loose stones; TECH ribs every ~10 studs, a cornice, a lit seam low down.
    -- face = the face's centre at floor level, along = the direction it runs, out = its outward normal. All of it is
    -- RockTrim (on terrain maps the block itself is rock).
    local function DressFace(face: Vector3, along: Vector3, out: Vector3, span: number, h: number, base: Color3)
        local rot = CFrame.Angles(0, math.atan2(-along.Z, along.X), 0) -- (local X = along)
        local flip = (rot.LookVector:Dot(out) > 0) and CFrame.new() or CFrame.Angles(0, math.pi, 0) -- (wedges: low edge out)
        local function At(u: number, up: number, o: number): CFrame
            return CFrame.new(face + along * u + out * o + Vector3.new(0, up, 0)) * rot
        end
        if style == "Tech" then
            local n = math.max(2, math.floor(span / 10))
            for i = 1, n do
                Piece(Vector3.new(1.1, h - 1.2, 0.6), At(-span / 2 + span * (i - 0.5) / n, (h - 1.2) / 2 + 0.2, 0.3), trimC, trimMat, 0.95):SetAttribute("RockTrim", true)
            end
            Piece(Vector3.new(span - 0.4, 0.6, 0.9), At(0, h - 0.5, 0.45), trimC, trimMat, 1.05):SetAttribute("RockTrim", true)
            Glow(Vector3.new(span - 1.2, 0.18, 0.12), At(0, 1.1, 0.06)):SetAttribute("RockTrim", true)
            return
        end
        local n = math.max(2, math.floor(span / 13))
        for i = 1, n do
            local u = -span / 2 + span * (i - 0.5) / n + vr:NextNumber(-0.8, 0.8)
            local bh = h * vr:NextNumber(0.72, 0.95)
            local bw = vr:NextNumber(2.2, 3.0)
            local k = vr:NextNumber(0.86, 1.04)
            Piece(Vector3.new(bw, bh, 1.4), At(u, bh / 2, 0.7), base, wallMat, k):SetAttribute("RockTrim", true)
            Piece(Vector3.new(bw + 0.2, 0.8, 1.6), At(u, bh + 0.4, 0.8) * flip, base, capMat, math.min(k * 1.12, 1.25), true, "WedgePart"):SetAttribute("RockTrim", true)
        end
        for _ = 1, math.max(1, math.floor(span / 18)) do
            local sh = vr:NextNumber(1.1, 2.2)
            Piece(Vector3.new(vr:NextNumber(2.6, 5.5), sh, 0.5), At(vr:NextNumber(-span * 0.45, span * 0.45), vr:NextNumber(0.8, math.max(h - sh - 0.6, 1)) + sh / 2, 0.12),
                base, wallMat, vr:NextNumber(0.85, 1.1)):SetAttribute("RockTrim", true)
        end
    end

    for _, p in ipairs(plan.Pieces) do
        if p.Kind == "Low" then
            local cf = CFrame.new(W(p.X, p.Z)) * CFrame.Angles(0, p.Yaw or 0, 0)
            LowWall(cf, p.L, p.H)
            if p.Arm then
                local s = p.Flip and -1 or 1
                LowWall(cf * CFrame.new(s * (p.L / 2 - 1.2), 0, p.Arm / 2 + 1.2) * CFrame.Angles(0, math.pi / 2, 0), p.Arm, p.H)
            end
            R(p.X, p.Z, p.L / 2 + 3)
        elseif p.Kind == "Cover" then
            local pool = ctx.propSet and ctx.propSet.Cover
            if pool and #pool > 0 then
                pool[rng:NextInteger(1, #pool)](geo, theme, rng, W(p.X, p.Z))
            end
            R(p.X, p.Z, 8)
        elseif p.Kind == "Tall" then
            local cf = CFrame.new(W(p.X, p.Z)) * CFrame.Angles(0, p.Yaw or 0, 0)
            local s, h = p.W, p.H
            local base = Shade(theme.Wall, rng).Color
            local crownC = Shade(theme.Wall, rng).Color -- (the two layout-rng draws it always made)
            local dress = ctx.Dress
            local cladT = dress and dress.Clad and style == "Masonry" and DressTemplate(dress.Clad) or nil
            local crownT = dress and dress.Crown and plan.Shape ~= "Pillar" and DressTemplate(dress.Crown) or nil -- (corner pillars carry a walkable top)
            -- (MAPVIBE 2026-10-25, owner: "copy and paste the same few props": the two Talls of a room wore the same crown,
            -- mirrored across the room. The second crown of a room takes the world's Alt piece when it has one)
            if crownT and not (game:GetService("RunService"):IsStudio() and workspace:GetAttribute("DevPropsOff") == true) then
                RoomGen._crownN = (RoomGen._crownN or 0) + 1
                local alt = dress.Crown.Alt
                if alt and #alt > 0 and RoomGen._crownN % 2 == 0 then
                    local a = alt[(math.floor(RoomGen._crownN / 2) - 1) % #alt + 1]
                    crownT = DressTemplate({ World = dress.Crown.World, Kit = dress.Crown.Kit, Name = a }) or crownT
                end
            end
            collect = cladT and {} or nil
            if style == "Masonry" then
                -- stacked drums, each a little off true, on a plinth under a capital (the band + glow ring z-fought)
                -- (WORLD DRESS Built: the plinth + capital in the world's TRIM -- brass on the skyport's brick, vermilion lacquer
                -- on the shrine stone, jade on the temple -- with a matching band where the first drum meets the second)
                local trimSurf = built and theme.WallTrim or nil
                Trim(Vector3.new(s + 1.2, 1.0, s + 1.2), cf * CFrame.new(0, 0.5, 0), trimSurf or { Color = Scale(base, 0.9), Material = capMat }):SetAttribute("Shade", 0.9)
                local y = 0
                for i, f in ipairs({ 0.36, 0.33, 0.31 }) do
                    local dh = h * f
                    local dw = s - ({ 0, 0.7, 0.3 })[i] -- (each drum a clear step in: the joints read from across the room)
                    Piece(Vector3.new(dw, dh, dw), cf * CFrame.new(0, y + dh / 2, 0) * CFrame.Angles(0, vr:NextNumber(-0.06, 0.06), 0), base, wallMat, ({ 0.82, 1.04, 0.9 })[i] * vr:NextNumber(0.95, 1.05))
                    y += dh
                    if trimSurf and i == 1 then
                        local band = Trim(Vector3.new(s + 0.3, 0.42, s + 0.3), cf * CFrame.new(0, y, 0), trimSurf)
                        band.CanCollide = false; band.CanQuery = false -- (a visual band 0.15 proud: the collider stays the drums)
                    end
                end
                Trim(Vector3.new(s + 0.8, 0.7, s + 0.8), cf * CFrame.new(0, h + 0.35, 0), trimSurf or { Color = Scale(base, 1.12), Material = capMat }):SetAttribute("Shade", 1.12)
                Trim(Vector3.new(s * 0.68, 0.9, s * 0.68), cf * CFrame.new(0, h + 1.15, 0) * CFrame.Angles(0, vr:NextNumber(-0.08, 0.08), 0), { Color = crownC, Material = wallMat }):SetAttribute("Shade", 1)
            else
                -- a body with corner ribs standing proud, plinth + cap; tech keeps a glow ring (proud of the body, ribs over its corners)
                local mat2 = style == "Tech" and trimMat or wallMat
                local c2 = style == "Tech" and trimC or base
                Trim(Vector3.new(s + 1.0, 0.8, s + 1.0), cf * CFrame.new(0, 0.4, 0), { Color = Scale(c2, 0.9), Material = mat2 }):SetAttribute("Shade", 0.9)
                Piece(Vector3.new(s, h, s), cf * CFrame.new(0, h / 2, 0), base, wallMat, 1)
                for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
                    local rb = Piece(Vector3.new(0.7, h - 1.2, 0.7), cf * CFrame.new(c[1] * s / 2, 0.8 + (h - 1.2) / 2, c[2] * s / 2), c2, mat2, 0.95)
                    rb:SetAttribute("RockTrim", true)
                end
                Trim(Vector3.new(s + 0.7, 0.7, s + 0.7), cf * CFrame.new(0, h + 0.35, 0), { Color = c2, Material = mat2 }):SetAttribute("Shade", 1)
                Trim(Vector3.new(s * 0.6, 1.0, s * 0.6), cf * CFrame.new(0, h + 1.2, 0), { Color = crownC, Material = wallMat }):SetAttribute("Shade", 1)
                if style == "Tech" then Glow(Vector3.new(s + 0.24, 0.22, s + 0.24), cf * CFrame.new(0, h * 0.62, 0)) end
            end
            -- (WORLD DRESS) the pillar as the world's own model: every part above stays as an invisible collider (the
            -- trims stop colliding on terrain maps, as Terrainify always made them); no terrain rock is filled for it
            if cladT and collect then
                for _, part in ipairs(collect) do
                    part.Transparency = 1
                    part.CastShadow = false
                    part:SetAttribute("Clad", true)
                    if ctx.Terrain and not built and part:GetAttribute("RockTrim") then part.CanCollide = false end
                end
                local m = DressClone(cladT, true)
                m:PivotTo(CFrame.new())
                FitBox(m, cf, Vector3.new(s + 0.2, h + 1.6, s + 0.2)) -- (up to the capital + crown top: a corner pillar's deck sits right on it)
                m.Name = "TallDress"
                m.Parent = geo
            end
            collect = nil
            -- a crown from the world's kit on top (scaled to the pillar, turned by the look stream)
            if crownT then
                local top = cladT and (h + 1.6) or (style == "Masonry" and ((ctx.Terrain and not built) and h - 0.3 or h + 1.6) or h + 1.7)
                local spec = dress.Crown
                local m = DressClone(crownT, true)
                m:PivotTo(CFrame.Angles(0, vr:NextNumber(0, math.pi * 2), 0))
                local _, bb = m:GetBoundingBox()
                local k = math.min((spec.Fit or 0.8) * s / math.max(bb.X, bb.Z, 0.01), (spec.MaxH or 1e9) / math.max(bb.Y, 0.01))
                m:ScaleTo(m:GetScale() * k)
                local bbCF, bb2 = m:GetBoundingBox()
                local bottom = bbCF.Position - Vector3.new(0, bb2.Y / 2, 0)
                m:PivotTo(m:GetPivot() + (cf.Position + Vector3.new(0, top - (spec.Sink or 0.15), 0) - bottom))
                m.Name = "TallCrown"
                m:SetAttribute("Src", crownT.Name) -- (which model: the copy-paste scan reads it)
                m.Parent = geo
            end
            R(p.X, p.Z, s / 2 + 5)
        elseif p.Kind == "Deck" then
            local dx, w, d, h = p.DeckX, p.W, p.D, p.H
            local base = W(dx, p.Z)
            local bc = Shade(theme.Wall, rng).Color
            Piece(Vector3.new(w, h, d), CFrame.new(base + Vector3.new(0, h / 2, 0)), bc, wallMat, 1)
            Trim(Vector3.new(w + 0.6, 0.5, d + 0.6), CFrame.new(base + Vector3.new(0, h + 0.25, 0)), theme.Floor) -- the walkable top
            if style == "Tech" then Glow(Vector3.new(w + 0.7, 0.2, d + 0.7), CFrame.new(base + Vector3.new(0, h - 0.15, 0))) end
            for _, ez in ipairs({ -1, 1 }) do -- (the deck's two end faces: the inner one carries the ramp)
                DressFace(base + Vector3.new(0, 0, ez * d / 2), Vector3.new(1, 0, 0), Vector3.new(0, 0, ez), w, h, bc)
            end
            -- the ramp: from the floor up to the deck's inner face
            local face = base + Vector3.new(p.Inward * w / 2, 0, 0)
            local foot = face + Vector3.new(p.Inward * p.Ramp, 0, 0)
            if ctx.Ramp then ctx.Ramp(geo, theme, foot, face + Vector3.new(0, h + 0.5, 0), math.min(d - 2, 9)) end
            -- a low parapet along the outer edge (cover up top, never above head height)
            local px = dx - p.Inward * (w / 2 - 0.9)
            WALL[style](CFrame.new(W(px, p.Z) + Vector3.new(0, h + 0.5, 0)) * CFrame.Angles(0, math.pi / 2, 0), d * 0.75, 2.8, 1.4, bc)
            R(dx, p.Z, math.max(w, d) / 2 + 4)
            R(p.X, p.Z, p.Ramp / 2 + 4)
        elseif p.Kind == "Massif" then
            -- stepped: a broad base and a set-back upper tier toward the wall, trim between them
            local cf = CFrame.new(W(p.X, p.Z))
            local h = p.H
            local lowerH = h * 0.62
            local mc = Shade(theme.Wall, rng).Color
            Piece(Vector3.new(p.W, lowerH, p.D), cf * CFrame.new(0, lowerH / 2, 0), mc, wallMat, 1)
            local coping = style == "Masonry" and { Color = Scale(mc, 1.12), Material = capMat } or theme.WallTrim
            Trim(Vector3.new(p.W + 0.6, 0.9, p.D + 0.6), cf * CFrame.new(0, lowerH + 0.45, 0), coping):SetAttribute("Shade", 1.12)
            local inset = math.min(p.W, p.D) * 0.28
            local sx = (p.X > 0) and 1 or -1
            local sz = (math.abs(p.D - plan.Arena) < 1) and 0 or ((p.Z > 0) and 1 or -1)
            local upW, upD = p.W - inset, (sz ~= 0) and (p.D - inset) or p.D
            Piece(Vector3.new(upW, h - lowerH, upD), cf * CFrame.new(sx * inset / 2, lowerH + (h - lowerH) / 2 + 0.9, sz * inset / 2), Shade(theme.Wall, rng).Color, wallMat, 0.94)
            Trim(Vector3.new(upW + 0.5, 0.7, upD + 0.5), cf * CFrame.new(sx * inset / 2, h + 1.25, sz * inset / 2), coping):SetAttribute("Shade", 1.12)
            if style == "Tech" then Glow(Vector3.new(p.W + 0.7, 0.22, p.D + 0.7), cf * CFrame.new(0, 1.2, 0)) end
            -- the faces toward the room
            local fpos = W(p.X, p.Z)
            DressFace(fpos - Vector3.new(sx * p.W / 2, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-sx, 0, 0), p.D, lowerH, mc)
            if sz ~= 0 then DressFace(fpos - Vector3.new(0, 0, sz * p.D / 2), Vector3.new(1, 0, 0), Vector3.new(0, 0, -sz), p.W, lowerH, mc) end
            if style == "Masonry" then -- (a broken skyline: a couple of loose blocks along the top)
                for _ = 1, 2 do
                    local bw = vr:NextNumber(2.5, 5)
                    local bh2 = vr:NextNumber(0.6, 1.3)
                    local b = Piece(Vector3.new(bw, bh2, vr:NextNumber(1.8, 2.8)), cf * CFrame.new(sx * inset / 2 + vr:NextNumber(-upW / 3, upW / 3), h + 1.6 + bh2 / 2, sz * inset / 2 + vr:NextNumber(-upD / 3, upD / 3))
                        * CFrame.Angles(0, vr:NextNumber(0, 3.14), 0), mc, wallMat, vr:NextNumber(0.9, 1.1))
                    b:SetAttribute("RockTrim", true)
                end
            end
            R(p.X, p.Z, math.max(p.W, p.D) / 2 + 2)
        elseif p.Kind == "Terrace" then
            local x, z, w, d, h = p.X, p.Z, p.W, p.D, p.H
            local cf = CFrame.new(W(x, z))
            local tc = Shade(theme.Wall, rng).Color
            Piece(Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), tc, wallMat, 1)
            Trim(Vector3.new(w + 0.4, 0.5, d + 0.4), cf * CFrame.new(0, h + 0.25, 0), theme.Floor)
            if style == "Tech" then Glow(Vector3.new(0.25, 0.2, d), cf * CFrame.new(-p.Side * (w / 2 + 0.1), h - 0.2, 0)) end
            -- parapet on the inner edge with gaps over the ramps
            local inner = -p.Side * (w / 2 - 0.8)
            local zs = { -d / 2, p.Ramps[1] - 7, p.Ramps[1] + 7, p.Ramps[2] - 7, p.Ramps[2] + 7, d / 2 }
            for k = 1, #zs - 1, 2 do
                local a, b = zs[k], zs[k + 1]
                if b - a > 4 then
                    WALL[style](cf * CFrame.new(inner, h + 0.5, (a + b) / 2 - z) * CFrame.Angles(0, math.pi / 2, 0), b - a, 3, 1.4, tc)
                end
            end
            for _, rz in ipairs(p.Ramps) do
                local face = W(x - p.Side * w / 2, rz)
                if ctx.Ramp then ctx.Ramp(geo, theme, face + Vector3.new(-p.Side * 12 * (h / 8), 0, 0), face + Vector3.new(0, h + 0.5, 0), 9) end
            end
            for zz = -d / 2, d / 2, 16 do R(x, z + zz, w / 2 + 2) end
        end
    end
    return reserved
end

-- (UPDATE 4 COVER) the room's corner pillars (BuildThemedDungeon, open shapes) in the same style: one Tall piece at
-- (x, z from the room centre), s wide, h high; ctx as Build's (its rng only gives the two base shades). The caller keeps
-- its walkable top.
function RoomGen.Pillar(ctx: any, x: number, z: number, s: number, h: number)
    RoomGen.Build({ Pieces = { { Kind = "Tall", X = x, Z = z, W = s, H = h } }, Shape = "Pillar" }, ctx)
end

return RoomGen
