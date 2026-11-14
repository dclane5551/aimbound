--!nocheck
-- ENEMY ATTACK TELEGRAPHS (2026-10-02, owner: "getting hit feels random -- make every attack skill based: we should
-- know when and how enemies attack, but it shouldn't be easy"). Every enemy / boss attack goes through here:
--   Circle  a ground disc whose bright core grows to the edge over the wind-up, then it strikes everything inside
--   Line    a ground strip that fills from the attacker outward (charges, sweeps, lunges)
--   Cone    a fan in front of the attacker (swings, breath)
--   Ring    an expanding shockwave hugging the floor -- jump over it
--   Beam    an aim laser that tracks you, LOCKS (flashes, thickens) a moment before firing, then a hitscan beam
--   Charge  a growing glow on the attacker while a shot charges
--   Zone    a circle that lingers after it goes off, hurting anyone standing in it
--   Sweep   a floor laser that rotates around the attacker (jump it or outrun it)
--   Arena   the whole floor goes red except a few safe circles
--   Mark    a circle that hunts you, locks, then detonates
-- Damage lands only if you're still in the zone when the wind-up completes. Wind-ups are short (fast QTEs) and
-- shrink with difficulty (ctx.Windup). Works on the client (solo dungeons) and the server (party dungeons).
--
-- ctx = EnemyAttacks.Context{ Geo, Fx, Targets = fn -> {Player}, Hit = fn(player, mult), Alive = fn -> bool,
--                              Windup = scale, Color = Color3? }
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

local EA = {}
EA.WARN = Color3.fromRGB(255, 55, 40)
EA.CORE = Color3.fromRGB(255, 150, 70)
EA.FLASH = Color3.fromRGB(255, 240, 210)
-- READABILITY (owner 2026-10-05: "it is far too hard to see enemy attacks. The outlines are near transparent for the AOEs
-- and you usually cant tell that you are in it"): every area's edge is now a SOLID bright danger-red rim (was a 70%-opaque
-- near-black line that vanished on dark floors), wider, and the fills are more opaque. HurtFX shouts when you're inside.
EA.EDGE = Color3.fromRGB(255, 40, 40)
local RIM_PAD = 1.6 -- (studs added to the area's width: a 0.8-stud rim each side; fixes 2026-10-16 #8: was 1.3 solid)
-- (fixes 2026-10-16 #8, playtester: "enemy damage indicators have too much bloom especially in boss fights"): every
-- neon telegraph part is drawn at GLOW of its colour (neon brightness drives the bloom), the rim is a little see-through
-- and the strike flash is softer. Shapes, wind-ups and the dark outline are unchanged, so areas read the same.
local GLOW = 0.7
local function Dim(c: Color3): Color3 return Color3.new(c.R * GLOW, c.G * GLOW, c.B * GLOW) end

local FLOOR_Y = 2

-- HIT TOLERANCE (owner 2026-10-05: "A lot of boss attacks feel like they aren't accurate (i.e getting hit outside of the
-- range)"): how far past an area's edge your ROOT can be and still be hit. Solo floors run here on your own client (exact
-- positions): a small allowance for your body. Party floors run on the server, which sees you ~a ping late -- a player
-- who already stepped out was still "inside" there -- so the server gives the benefit of the doubt (negative = forgiving).
-- (0.61, owner: "I also really want to ensure that the AOES and projectiles enemies shoot are fully accurate. It still often
-- feels like I get hit when im completely outside of an enemy attack area"): solo is EXACT now -- your centre has to be
-- inside the filled area (the solid rim is drawn outside it). Party floors keep the server's benefit of the doubt.
local TOL = RunService:IsClient() and 0 or -0.4
EA.TOL = TOL
-- HEAVY HITS ARE ALWAYS READABLE (owner 2026-10-05: "Any hard-hitting attacks should be telegraphed"): difficulty and bot
-- skill shrink wind-ups (down to ~0.5x on the top tiers) -- fine for chip damage, unfair for a x1.4+ hit. Those keep at
-- least HEAVY_MIN seconds of wind-up (and everything at least ANY_MIN).
EA.HEAVY_MULT, EA.HEAVY_MIN, EA.ANY_MIN = 1.35, 1.0, 0.5
-- SLOWER PLAYERS (0.60, owner: "I want the player to be far slower than the bots ... scale back the momentum gain and add a
-- cap, and with that change the way ALL enemies attack, because we wouldn't have time to dodge"): the player now tops out at
-- 24 studs/s (MovementController MomentumCap), so every enemy attack gives more time and asks for less ground to cover:
-- REACT stretches every wind-up / lock / warn time, AREA shrinks circles / strips / marks / cones, SAFE_GROW widens arena
-- safe circles, MOVE_SPEED slows rings and rolling walls. Tune these four before touching individual kits.
-- (0.60b, owner: "The bots now feel a little bit too easy": 1.35 / 0.85 / 1.2 / 0.75 -> halfway back)
EA.REACT, EA.AREA, EA.SAFE_GROW, EA.MOVE_SPEED = 1.15, 0.95, 1.1, 0.85
local function CW(ctx: any): number return (ctx.Windup or 1) * EA.REACT end
local function WindupFor(ctx: any, windup: number, mult: number?): number
    local w = windup * CW(ctx)
    w = math.max(w, ((mult or 1) >= EA.HEAVY_MULT) and EA.HEAVY_MIN or EA.ANY_MIN)
    -- (0.53 EnemyAnim: the attacker's wind-up pose runs until its telegraph fills -- server time, so party bots match)
    local m = ctx.Model
    if m and m.Parent then
        local now = Workspace:GetServerTimeNow()
        local e = m:GetAttribute("AtkEnd") or 0
        if e < now then m:SetAttribute("AtkStart", now) end
        if now + w > e then m:SetAttribute("AtkEnd", now + w) end
    end
    return w
end
EA.WindupFor = WindupFor
-- PLATFORMS (owner 2026-10-05: "A lot of the biome allow you to walk up on platforms and completely avoid boss attacks"):
-- shockwave rings and floor sweeps are built to be JUMPED, so they only reach a few studs over the arena floor -- standing
-- on any platform dodged them for free. Now they also hit you while you're standing on something above their floor
-- (a jump still clears them: in the air nothing is under your feet).
local platParams = RaycastParams.new()
platParams.FilterType = Enum.RaycastFilterType.Exclude
local function StandingAbove(ctx: any, root: BasePart, floorY: number): boolean
    platParams.FilterDescendantsInstances = { root.Parent, ctx.Fx }
    local hit = Workspace:Raycast(root.Position, Vector3.new(0, -4.6, 0), platParams)
    return hit ~= nil and hit.Position.Y > floorY + 1.5
end

-- VFX budget (crash safety): when telegraph parts are being made very fast (many attacks overlapping), the decorative
-- inner "core" strips are skipped -- they're built but never parented, so the danger zones / hits are unchanged.
local BUDGET_WINDOW, BUDGET_PARTS = 0.5, 140
local made, windowStart = 0, os.clock()
-- HurtFX (the "you're standing in it" warning) watches these floor areas: tagged here, tags replicate to party clients.
-- Rings and sweeps aren't tagged (you jump those) -- nor beams (the laser itself is the warning).
local DANGER_NAMES = { AtkCircle = true, AtkLine = true, AtkCone = true, AtkZoneWarn = true, AtkZone = true, AtkMark = true, AtkArena = true, AtkDonut = true, AtkWallPath = true, AtkNova = true } -- (POE DAMAGE MODEL: a caster AURA is NOT tagged: an always-on danger tag kept "MOVE!" + the edge glow up the whole fight -- its floor disc is the tell)
local function P(props: { [string]: any }): Part
    local now = os.clock()
    if now - windowStart > BUDGET_WINDOW then windowStart = now; made = 0 end
    made += 1
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.Material = Enum.Material.Neon; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
    local skipCore = made > BUDGET_PARTS and type(props.Name) == "string" and string.sub(props.Name, -4) == "Core"
    for k, v in pairs(props) do
        if not (skipCore and k == "Parent") then (p :: any)[k] = v end
    end
    if props.Name == "AtkRim" then p.Material = Enum.Material.Neon; p.Color = EA.EDGE; p.Transparency = 0.2 end
    if p.Material == Enum.Material.Neon then p.Color = Dim(p.Color) end
    if DANGER_NAMES[props.Name] then CollectionService:AddTag(p, "AimDanger")
    elseif props.Name == "AtkSafe" then CollectionService:AddTag(p, "AimSafe") end
    return p
end

-- BIOME TELEGRAPHS (owner 2026-10-03: "the area that the player has to dodge should match the aesthetic of the biome, or
-- in boss cases, the boss"): inside a dungeon every telegraph is drawn in its biome's style -- an edge colour, a fill that
-- grows over the wind-up, and the MATERIAL of the area itself (molten lava, cracked ice, void shimmer, a cyber hologram,
-- storm light). Bosses swap in their own colours (BossAI) and keep the biome's material. Every area also gets a thin
-- dark OUTLINE so it reads on any floor. Found from ctx.Geo's dungeon folder (attribute Biome).
EA.BIOME = {
    Fire = { Warn = Color3.fromRGB(255, 130, 50), Core = Color3.fromRGB(255, 226, 140), Mat = Enum.Material.CrackedLava },  -- molten
    Ice = { Warn = Color3.fromRGB(110, 205, 255), Core = Color3.fromRGB(235, 250, 255), Mat = Enum.Material.Ice },          -- frost
    Void = { Warn = Color3.fromRGB(160, 60, 255), Core = Color3.fromRGB(255, 140, 240), Mat = Enum.Material.ForceField },   -- rift shimmer
    Cyber = { Warn = Color3.fromRGB(150, 255, 40), Core = Color3.fromRGB(240, 255, 220), Mat = Enum.Material.ForceField },  -- acid data-green hologram (the grid is cyan; magenta read as Void)
    Storm = { Warn = Color3.fromRGB(120, 190, 255), Core = Color3.fromRGB(250, 250, 200), Mat = Enum.Material.Neon },       -- storm light
    Dream = { Warn = Color3.fromRGB(255, 110, 210), Core = Color3.fromRGB(255, 230, 250), Mat = Enum.Material.ForceField },  -- (0.53) a pink dream shimmer
    Flats = { Warn = Color3.fromRGB(255, 120, 40), Core = Color3.fromRGB(255, 230, 160), Mat = Enum.Material.Neon },         -- (0.53) sunset neon
}
-- (0.87 WORLDS: each world's own telegraph colours)
do
    local ok, WB = pcall(require, script.Parent:WaitForChild("WorldBiomes"))
    if ok then for k, v in pairs(WB.EA) do EA.BIOME[k] = v end end
end
EA.OUTLINE = Color3.fromRGB(12, 12, 16)
-- (UPDATE 8 DEFENCE) STRIKES: the plain hit shapes (Circle / Line / Cone / Beam) land through StrikeHit, which raises EA.Strike
-- for the duration of the hit. DungeonGenerator.HitPlayer reads it: a non-boss's strike is an ORDINARY hit your Agility
-- can dodge; everything else (rings, sweeps, walls, zones, arena wipes, marks, donuts, rollers) is a mechanic that never misses.
-- (AGILITY vs BOSSES, 2026-10-24) EA.StrikePlain: the strike's opts.Plain -- set only by the boss moves on BossAI's allow-list
-- (M.PLAIN: a boss's plain swing / thrust / claw / shot at you). A boss's strike is dodgeable only with it.
EA.Strike = false
EA.StrikePlain = false
function EA.StrikeHit(ctx: any, p: Player, mult: number, plain: boolean?)
    EA.Strike = true
    EA.StrikePlain = plain == true
    local ok, err = pcall(ctx.Hit, p, mult)
    EA.Strike = false
    EA.StrikePlain = false
    if not ok then warn("[EnemyAttacks] " .. tostring(err)) end
end
function EA.Context(t: any): any
    local geo = t.Geo
    local biome = geo and geo.Parent and geo.Parent:GetAttribute("Biome")
    local pal = biome and EA.BIOME[biome]
    if pal then
        t.Color = pal.Warn; t.Core = pal.Core; t.Mat = pal.Mat
        t.MatT = (pal.Mat ~= Enum.Material.Neon) and 0.3 or 0.45 -- (owner 0.52: "a little less opaque" -- was 0.1 / 0.3; the solid rim keeps the edge readable)
    end
    t.Windup = t.Windup or 1
    t.Alive = t.Alive or function() return true end
    t.Fx = t.Fx or Workspace
    return t
end

-- the floor (or platform) height under a point
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
function EA.GroundY(ctx: any, pos: Vector3): number
    if ctx.Geo and ctx.Geo.Parent then
        -- (the open maps' ground is TERRAIN over a hidden floor part, and terrain voxels sit up to ~1 stud above it: markers
        -- drawn on the part were buried -- "you usually cant tell that you are in it". The terrain counts as ground now.)
        groundParams.FilterDescendantsInstances = { ctx.Geo, Workspace.Terrain }
        local hit = Workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -80, 0), groundParams)
        if hit then return hit.Position.Y + ((hit.Instance == Workspace.Terrain) and 0.35 or 0) end
    end
    return FLOOR_Y
end

local function Roots(ctx: any): { { Player: Player, Root: BasePart } }
    local out = {}
    for _, pl in ipairs(ctx.Targets()) do
        local c = pl.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if r and r:IsA("BasePart") and h and h.Health > 0 then table.insert(out, { Player = pl, Root = r }) end
    end
    return out
end

local SoundHelper
local function Boom(part: BasePart, kind: string?)
    -- (its own short-lived anchor: the flash part is gone after 0.12s and would cut the sound off)
    SoundHelper = SoundHelper or require(script.Parent:WaitForChild("SoundHelper"))
    local a = P({ Name = "AtkSound", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(part.Position), Parent = part.Parent })
    pcall(SoundHelper.PlayAt, kind or "AreaStrike", a)
    Debris:AddItem(a, 3)
end

local function Flash(ctx: any, part: BasePart)
    part.Color = Dim(EA.FLASH)
    part.Transparency = 0.3
    Debris:AddItem(part, 0.12)
end

-- runs fn(k) every frame for `dur` seconds (k = 0..1); stops early (returns false) if the attacker dies
local function Over(ctx: any, dur: number, fn: (number) -> ()): boolean
    local t0 = os.clock()
    while true do
        if not ctx.Alive() then return false end
        local k = math.clamp((os.clock() - t0) / math.max(dur, 0.01), 0, 1)
        fn(k)
        if k >= 1 then return true end
        RunService.Heartbeat:Wait()
    end
end

local DISC = CFrame.Angles(0, 0, math.rad(90))

-- ===== RED AREAS ARE COLUMNS (owner 2026-10-02: "the grapple lets you dodge anything with little effort -- look up, go to
-- the ceiling, repeat. I want the player to actually have to think about their movement") =====
-- Circles, lines, cones, arena wipes and marks hit at ANY height above their floor: going up doesn't leave an
-- area, moving out of it sideways does. Only the attacks built to be jumped stay low (Ring shockwaves, Sweep lasers) and the lingering floor Zones.
-- Every column attack draws its column (owner 2026-10-02: "it's hard to tell where the attacks go / if they hit you
-- vertically"): a faint wall of red rising from the floor area -- at least COLUMN_MIN tall, and up past any target
-- that's above it -- that fills in with the wind-up and flashes when it strikes.
local SKY = 400
EA.SKY = SKY
local COLUMN_MIN = 14
local function ColumnTop(ctx: any, center: Vector3, reach: number, y: number): number
    local top = COLUMN_MIN
    for _, pl in ipairs(ctx.Targets and ctx.Targets() or {}) do
        local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
        if r and Vector3.new(r.Position.X - center.X, 0, r.Position.Z - center.Z).Magnitude < reach + 14 then
            top = math.max(top, r.Position.Y - y + 6)
        end
    end
    return math.min(top, 80)
end
-- A column = two very faint parts: a band up to COLUMN_BAND over the floor and a fainter part above it, so it reads
-- as "this keeps going up" without walls of red stacking up over the screen (a boss can have 15+ out at once).
-- round = cylinder (circles, marks) or a box (lines; base = the strip's CFrame, w = width, d = length).
local COLUMN_BAND = 9
local function PlaceColumn(col: any, base: CFrame, w: number, d: number, top: number)
    if not col then return end
    local h1 = math.min(COLUMN_BAND, top)
    local h2 = math.max(0.2, top - h1)
    if col.Round then
        col.Lo.Size = Vector3.new(h1, w, d); col.Lo.CFrame = base * CFrame.new(0, h1 / 2, 0) * DISC
        col.Hi.Size = Vector3.new(h2, w, d); col.Hi.CFrame = base * CFrame.new(0, h1 + h2 / 2, 0) * DISC
    else
        col.Lo.Size = Vector3.new(w, h1, d); col.Lo.CFrame = base * CFrame.new(0, h1 / 2, 0)
        col.Hi.Size = Vector3.new(w, h2, d); col.Hi.CFrame = base * CFrame.new(0, h1 + h2 / 2, 0)
    end
end
-- FLAT NOTIFIERS (playtester 2026-10-02: "make multiple types of AoE attacks so it doesn't feel as visually cluttered
-- -- e.g. flat attack notifiers"): ordinary enemy attacks only draw their floor marker; the column is drawn when a
-- target is actually above the area (ColumnTop grew past COLUMN_MIN) or for contexts with Columns = true (bosses).
-- The hit volume is unchanged -- still a column -- so going up never dodges.
local function NewColumn(ctx: any, round: boolean, base: CFrame, w: number, d: number, top: number): any
    if not ctx.Columns and top <= COLUMN_MIN + 0.01 then return nil end
    local props = { Name = "AtkPillar", Color = ctx.Color or EA.WARN, Transparency = 0.96, Parent = ctx.Fx }
    if round then props.Shape = Enum.PartType.Cylinder end
    local col = { Round = round, Lo = P(table.clone(props)), Hi = P(table.clone(props)) }
    PlaceColumn(col, base, w, d, top)
    return col
end
local function Pillar(ctx: any, center: Vector3, radius: number, y: number): any
    return NewColumn(ctx, true, CFrame.new(center.X, y, center.Z), radius * 2, radius * 2, ColumnTop(ctx, center, radius, y))
end
local function DropColumn(col: any)
    if col then col.Lo:Destroy(); col.Hi:Destroy() end
end
local function FillColumn(col: any, k: number)
    if not col then return end
    col.Lo.Transparency = 0.955 - 0.04 * k
    col.Hi.Transparency = 0.985 - 0.02 * k
end
local function ColumnFlash(col: any)
    if not col then return end
    -- (huge areas -- half-arena burns, long lanes -- skip the flash: stacked, they whited out the screen)
    local s = col.Lo.Size
    local area = col.Round and (s.Y * s.Z) or (s.X * s.Z)
    if area > 700 then DropColumn(col) return end
    col.Lo.Color = Dim(EA.FLASH)
    col.Lo.Transparency = 0.84 -- (soft: a column is a lot of screen)
    Debris:AddItem(col.Lo, 0.14)
    col.Hi:Destroy()
end

-- ===== CIRCLE: ground disc =====
-- opts: Mult (damage x), OnStrike(center) -- a column: hits at any height (RED AREAS ARE COLUMNS)
function EA.Circle(ctx: any, center: Vector3, radius: number, windup: number, opts: any?)
    opts = opts or {}
    radius *= EA.AREA
    windup = WindupFor(ctx, windup, opts.Mult)
    task.spawn(function()
        local y = EA.GroundY(ctx, center)
        local cf = CFrame.new(center.X, y + 0.07, center.Z) * DISC
        local base = P({ Name = "AtkCircle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, radius * 2, radius * 2), CFrame = cf,
            Color = ctx.Color or EA.WARN, Material = ctx.Mat or Enum.Material.Neon, Transparency = ctx.MatT or 0.6, Parent = ctx.Fx })
        local rim = P({ Name = "AtkRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, radius * 2 + RIM_PAD, radius * 2 + RIM_PAD), CFrame = cf * CFrame.new(-0.02, 0, 0),
            Color = EA.OUTLINE, Material = Enum.Material.SmoothPlastic, Transparency = 0.3, Parent = ctx.Fx })
        task.delay(windup + 0.05, function() rim:Destroy() end)
        local core = P({ Name = "AtkCircleCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.2, 0.2), CFrame = cf * CFrame.new(0.01, 0, 0),
            Color = ctx.Core or EA.CORE, Transparency = 0.35, Parent = ctx.Fx })
        local pillar = Pillar(ctx, center, radius, y)
        local ok = Over(ctx, windup, function(k)
            local d = math.max(0.2, radius * 2 * k)
            core.Size = Vector3.new(0.12, d, d)
            FillColumn(pillar, k)
        end)
        base:Destroy()
        if pillar then if ok then ColumnFlash(pillar) else DropColumn(pillar) end end
        if not ok then core:Destroy() return end
        core.Size = Vector3.new(0.3, radius * 2, radius * 2)
        Flash(ctx, core)
        Boom(core, opts.Sound)
        local hTop = SKY -- (a column: see RED AREAS ARE COLUMNS)
        for _, t in ipairs(Roots(ctx)) do
            local rp = t.Root.Position
            local flat = Vector3.new(rp.X - center.X, 0, rp.Z - center.Z).Magnitude
            if flat <= radius + TOL and rp.Y - y <= hTop and rp.Y - y >= -3 then EA.StrikeHit(ctx, t.Player, opts.Mult or 1, opts.Plain) end
        end
        if opts.OnStrike then opts.OnStrike(Vector3.new(center.X, y, center.Z)) end
    end)
end

-- ===== LINE: ground strip from `from` toward `to` =====
-- opts: Height (default 6), Mult, OnStrike(from, to)
function EA.Line(ctx: any, from: Vector3, to: Vector3, width: number, windup: number, opts: any?)
    opts = opts or {}
    width *= EA.AREA
    windup = WindupFor(ctx, windup, opts.Mult)
    task.spawn(function()
        local y = EA.GroundY(ctx, from)
        local a = Vector3.new(from.X, y + 0.07, from.Z)
        local b = Vector3.new(to.X, y + 0.07, to.Z)
        local len = (b - a).Magnitude
        if len < 0.5 then return end
        local dir = (b - a).Unit
        local cf = CFrame.lookAt(a, b)
        local base = P({ Name = "AtkLine", Size = Vector3.new(width, 0.1, len), CFrame = cf * CFrame.new(0, 0, -len / 2),
            Color = ctx.Color or EA.WARN, Material = ctx.Mat or Enum.Material.Neon, Transparency = ctx.MatT or 0.6, Parent = ctx.Fx })
        local rim = P({ Name = "AtkRim", Size = Vector3.new(width + RIM_PAD, 0.08, len + RIM_PAD), CFrame = cf * CFrame.new(0, -0.02, -len / 2),
            Color = EA.OUTLINE, Material = Enum.Material.SmoothPlastic, Transparency = 0.3, Parent = ctx.Fx })
        task.delay(windup + 0.05, function() rim:Destroy() end)
        local core = P({ Name = "AtkLineCore", Size = Vector3.new(width * 0.9, 0.12, 0.2), CFrame = cf, Color = ctx.Core or EA.CORE, Transparency = 0.35, Parent = ctx.Fx })
        local mid = a:Lerp(b, 0.5)
        local top = ColumnTop(ctx, mid, len / 2, y)
        local wall = NewColumn(ctx, false, cf * CFrame.new(0, 0, -len / 2), width, len, top)
        local ok = Over(ctx, windup, function(k)
            local l = math.max(0.2, len * k)
            core.Size = Vector3.new(width * 0.9, 0.12, l)
            core.CFrame = cf * CFrame.new(0, 0.01, -l / 2)
            FillColumn(wall, k)
        end)
        base:Destroy()
        if ok then ColumnFlash(wall) else DropColumn(wall) end
        if not ok then core:Destroy() return end
        Flash(ctx, core)
        Boom(core, opts.Sound)
        local hTop = SKY -- (a column)
        for _, t in ipairs(Roots(ctx)) do
            local rel = t.Root.Position - a
            local along = rel:Dot(dir)
            local side = (Vector3.new(rel.X, 0, rel.Z) - Vector3.new(dir.X, 0, dir.Z) * along).Magnitude
            if along >= math.min(0, -TOL) and along <= len + TOL and side <= width / 2 + TOL and rel.Y <= hTop and rel.Y >= -3 then EA.StrikeHit(ctx, t.Player, opts.Mult or 1, opts.Plain) end -- (0.61: no 0.5-stud overhang past the ends)
        end
        if opts.OnStrike then opts.OnStrike(a, b) end
    end)
end

-- ===== CONE: fan in front of the attacker =====
-- opts: Height (default 7), Mult, Strips (visual detail, default 7)
function EA.Cone(ctx: any, origin: Vector3, facing: Vector3, range: number, halfAngleDeg: number, windup: number, opts: any?)
    halfAngleDeg *= EA.AREA
    opts = opts or {}
    windup = WindupFor(ctx, windup, opts.Mult)
    task.spawn(function()
        local y = EA.GroundY(ctx, origin)
        local o = Vector3.new(origin.X, y + 0.07, origin.Z)
        local f = Vector3.new(facing.X, 0, facing.Z)
        f = f.Magnitude > 0.01 and f.Unit or Vector3.new(0, 0, 1)
        local n = opts.Strips or 7
        local strips, cores = {}, {}
        local stripW = 2 * range * math.tan(math.rad(halfAngleDeg) / n) + 0.6
        for i = 1, n do
            local ang = math.rad(-halfAngleDeg + (i - 0.5) * (2 * halfAngleDeg / n))
            local d = CFrame.fromAxisAngle(Vector3.yAxis, ang):VectorToWorldSpace(f)
            local cf = CFrame.lookAt(o, o + d)
            strips[i] = { CF = cf, Part = P({ Name = "AtkCone", Size = Vector3.new(stripW, 0.1, range), CFrame = cf * CFrame.new(0, 0, -range / 2),
                Color = ctx.Color or EA.WARN, Material = ctx.Mat or Enum.Material.Neon, Transparency = ctx.MatT or 0.6, Parent = ctx.Fx }) }
            cores[i] = P({ Name = "AtkConeCore", Size = Vector3.new(stripW * 0.9, 0.12, 0.2), CFrame = cf, Color = ctx.Core or EA.CORE, Transparency = 0.4, Parent = ctx.Fx })
            -- (the fan's bright rim: each strip sits on a slightly bigger red strip, so the outer arc + edges show)
            local rim = P({ Name = "AtkRim", Size = Vector3.new(stripW + ((i == 1 or i == n) and RIM_PAD or 0.2), 0.08, range + RIM_PAD * 0.5),
                CFrame = cf * CFrame.new(0, -0.02, -(range + RIM_PAD * 0.5) / 2), Parent = ctx.Fx })
            task.delay(windup + 0.05, function() rim:Destroy() end)
        end
        -- (2026-10-07, owner: bosses keep "shooting out lasers ground level in a shotgun themed pattern": the fill used to grow
        -- out along each strip -- a fan of lasers. Now the whole wedge fills in evenly and brightens: one area, not lasers)
        for i, s in ipairs(strips) do
            cores[i].Size = Vector3.new(stripW * 0.98, 0.12, range)
            cores[i].CFrame = s.CF * CFrame.new(0, 0.01, -range / 2)
            cores[i].Transparency = 0.92
        end
        local ok = Over(ctx, windup, function(k)
            for i = 1, #cores do cores[i].Transparency = 0.92 - 0.6 * k * k end
        end)
        for _, s in ipairs(strips) do s.Part:Destroy() end
        if not ok then for _, c in ipairs(cores) do c:Destroy() end return end
        for _, c in ipairs(cores) do Flash(ctx, c) end
        if cores[1] then Boom(cores[1], opts.Sound) end
        local hTop = SKY -- (a column)
        local cosA = math.cos(math.rad(halfAngleDeg)) -- (0.61: exactly the drawn fan; was +1.5 deg, before that +4)
        for _, t in ipairs(Roots(ctx)) do
            local rel = t.Root.Position - o
            local flat = Vector3.new(rel.X, 0, rel.Z)
            -- (0.61: the "within 2 studs" rule hit you standing BEHIND the swing; now only right on top of its origin)
            if flat.Magnitude <= range + TOL and rel.Y <= hTop and rel.Y >= -3 and (flat.Magnitude < 0.75 or flat.Unit:Dot(f) >= cosA) then
                EA.StrikeHit(ctx, t.Player, opts.Mult or 1, opts.Plain)
            end
        end
    end)
end

-- ===== SAFE CONE (fixes 2026-10-16 #10): a GREEN wedge on the floor that does nothing -- "stand here" =====
-- Drawn for `dur` seconds (a boss's wedge attack passes the same windup); tagged AimSafe like the Arena's safe discs.
EA.SAFE = Color3.fromRGB(120, 255, 170)
function EA.SafeCone(ctx: any, origin: Vector3, facing: Vector3, range: number, halfAngleDeg: number, dur: number)
    halfAngleDeg *= EA.AREA
    task.spawn(function()
        local y = EA.GroundY(ctx, origin)
        local o = Vector3.new(origin.X, y + 0.1, origin.Z)
        local f = Vector3.new(facing.X, 0, facing.Z)
        f = f.Magnitude > 0.01 and f.Unit or Vector3.new(0, 0, 1)
        local n = math.max(3, math.ceil(halfAngleDeg / 6))
        local stripW = 2 * range * math.tan(math.rad(halfAngleDeg) / n) + 0.6
        local parts = {}
        for i = 1, n do
            local ang = math.rad(-halfAngleDeg + (i - 0.5) * (2 * halfAngleDeg / n))
            local d = CFrame.fromAxisAngle(Vector3.yAxis, ang):VectorToWorldSpace(f)
            local cf = CFrame.lookAt(o, o + d)
            table.insert(parts, P({ Name = "AtkSafe", Size = Vector3.new(stripW, 0.1, range), CFrame = cf * CFrame.new(0, 0, -range / 2),
                Color = EA.SAFE, Transparency = 0.55, Parent = ctx.Fx }))
        end
        Over(ctx, WindupFor(ctx, dur), function(k)
            for _, p in ipairs(parts) do p.Transparency = 0.55 + 0.15 * math.sin(k * math.pi * 6) end
        end)
        for _, p in ipairs(parts) do p:Destroy() end
    end)
end

-- ===== RING (0.74): an AIMED strike, no longer a wave =====
-- (owner: "you STILL havent gotten rid of the attack where the enemy shoots a ton of projectiles out in a shotgun manner
-- around them, remove it and replace it with more intuitive attacks"): the old ring was 20 wall segments flying OUT of
-- the enemy in every direction -- it read as a shotgun spray of projectiles, and you had to jump it. Every caller (boss
-- stomps / ripples / converges, the Juggernaut's third slam, the Arcwalker's clap, the Drowse lullaby ...) now marks a
-- circle ON each player the wave could reach, where they're heading, landing when the wave would have got there
-- (its windup + travel time). Same damage (opts.Mult); opts.Radius sets the circle (default 6).
function EA.Ring(ctx: any, center: Vector3, maxRadius: number, windup: number, opts: any?)
    opts = opts or {}
    local speed = (opts.Speed or 34) * EA.MOVE_SPEED
    local start = opts.StartRadius or 3
    for _, t in ipairs(Roots(ctx)) do
        local rp = t.Root.Position
        local d = Vector3.new(rp.X - center.X, 0, rp.Z - center.Z).Magnitude
        if d <= maxRadius + 6 then
            local travel = math.clamp(math.abs((opts.Inward and maxRadius or start) - d) / math.max(1, speed), 0, 1.2)
            local v = t.Root.AssemblyLinearVelocity
            local at = rp + Vector3.new(v.X, 0, v.Z) * 0.2
            EA.Circle(ctx, at, opts.Radius or 6, math.max(0.65, windup + travel), { Mult = opts.Mult, Sound = opts.Sound })
        end
    end
end

-- ===== WALL: a long low wall that sweeps straight across the arena -- jump it =====
-- (2026-10-07, owner: "bosses still spam the same attack often ... we need variation") from `from` it travels along
-- `dir` for `dist` studs; `length` = its width across. opts: Height (3.2: a jump clears it), Speed (24), Mult, Gap
-- (a slot that lets you walk through instead: { At = -1..1 along its length, W = studs }), Color
function EA.Wall(ctx: any, from: Vector3, dir: Vector3, dist: number, length: number, windup: number, opts: any?)
    opts = opts or {}
    windup = WindupFor(ctx, windup, opts.Mult)
    task.spawn(function()
        local d = Vector3.new(dir.X, 0, dir.Z)
        d = d.Magnitude > 0.01 and d.Unit or Vector3.new(0, 0, 1)
        local side = Vector3.new(-d.Z, 0, d.X)
        local y = EA.GroundY(ctx, from)
        local height = opts.Height or 3.2
        local col = opts.Color or ctx.Color or EA.WARN
        -- wind-up: the start line glows, an arrow strip shows the way it will travel
        local line = P({ Name = "AtkWallWarn", Size = Vector3.new(length, 0.12, 1.2), CFrame = CFrame.lookAt(Vector3.new(from.X, y + 0.08, from.Z), Vector3.new(from.X, y + 0.08, from.Z) + d),
            Color = col, Transparency = 0.4, Parent = ctx.Fx })
        local path = P({ Name = "AtkWallPath", Size = Vector3.new(length, 0.06, dist), CFrame = CFrame.lookAt(Vector3.new(from.X, y + 0.05, from.Z), Vector3.new(from.X, y + 0.05, from.Z) + d) * CFrame.new(0, 0, -dist / 2),
            Color = col, Transparency = 0.9, Parent = ctx.Fx })
        local ok = Over(ctx, windup, function(k)
            line.Transparency = 0.4 - 0.3 * math.sin(k * math.pi * 6) ^ 2
            path.Transparency = 0.92 - 0.12 * k
        end)
        line:Destroy(); path:Destroy()
        if not ok then return end
        local gap = opts.Gap
        local pieces = {}
        local function Piece(a0, a1)
            if a1 - a0 < 0.5 then return end
            table.insert(pieces, { A0 = a0, A1 = a1, Part = P({ Name = "AtkWall", Size = Vector3.new(a1 - a0, height, 1.6), Color = col, Transparency = 0.2, Parent = ctx.Fx }) })
        end
        if gap then
            local gc = (gap.At or 0) * length / 2
            Piece(-length / 2, gc - gap.W / 2)
            Piece(gc + gap.W / 2, length / 2)
        else
            Piece(-length / 2, length / 2)
        end
        if pieces[1] then Boom(pieces[1].Part, opts.Sound) end
        local speed = (opts.Speed or 24) * EA.MOVE_SPEED
        local hitDone = {}
        local t = 0
        local last = os.clock()
        while t < dist do
            if not ctx.Alive() then break end
            local now = os.clock()
            t += speed * math.min(now - last, 0.1)
            last = now
            local c = Vector3.new(from.X, y, from.Z) + d * t
            for _, pc in ipairs(pieces) do
                local mid = (pc.A0 + pc.A1) / 2
                pc.Part.CFrame = CFrame.lookAt(c + side * mid + Vector3.new(0, height / 2, 0), c + side * mid + Vector3.new(0, height / 2, 0) + d)
            end
            for _, tr in ipairs(Roots(ctx)) do
                if not hitDone[tr.Player] then
                    local rel = tr.Root.Position - c
                    local along = rel.X * d.X + rel.Z * d.Z
                    local across = rel.X * side.X + rel.Z * side.Z
                    if math.abs(along) <= 0.8 + TOL and rel.Y <= height + 1.2 and rel.Y >= -3 then
                        for _, pc in ipairs(pieces) do
                            if across >= pc.A0 - TOL and across <= pc.A1 + TOL then hitDone[tr.Player] = true; ctx.Hit(tr.Player, opts.Mult or 1) break end
                        end
                    end
                end
            end
            RunService.Heartbeat:Wait()
        end
        for _, pc in ipairs(pieces) do pc.Part:Destroy() end
    end)
end

-- ===== BEAM: tracking aim laser -> lock -> hitscan =====
-- originFn() -> Vector3 (moves with the attacker), target = BasePart to track. opts: LockTime (default 0.22 before firing),
-- Width (hit radius, default 1.6), Range (default 160), Mult, Color, OnFire(from, to)
function EA.Beam(ctx: any, originFn: () -> Vector3, target: BasePart, windup: number, opts: any?)
    opts = opts or {}
    windup = WindupFor(ctx, windup, opts.Mult)
    task.spawn(function()
        local lockAt = math.max(0, windup - (opts.LockTime or 0.22) * CW(ctx))
        local color = opts.Color or ctx.Color or EA.WARN
        local line = P({ Name = "AtkBeamAim", Size = Vector3.new(0.07, 0.07, 1), Color = color, Transparency = 0.35, Parent = ctx.Fx })
        local aim = target.Position
        local t0 = os.clock()
        local ok = Over(ctx, windup, function()
            local el = os.clock() - t0
            local a = originFn()
            if el < lockAt then
                aim = target.Parent and target.Position or aim
            else
                line.Size = Vector3.new(0.18, 0.18, line.Size.Z)
                line.Transparency = (math.floor(el * 30) % 2 == 0) and 0.05 or 0.5 -- locked: it flickers
            end
            local dir = aim - a
            local len = math.min(opts.Range or 160, dir.Magnitude + 40)
            if dir.Magnitude > 0.01 then
                line.Size = Vector3.new(line.Size.X, line.Size.Y, len)
                line.CFrame = CFrame.lookAt(a, a + dir) * CFrame.new(0, 0, -len / 2)
            end
        end)
        line:Destroy()
        if not ok then return end
        local a = originFn()
        local dir = aim - a
        if dir.Magnitude < 0.01 then return end
        local unit = dir.Unit
        local range = opts.Range or 160
        local stop = range
        if ctx.Geo and ctx.Geo.Parent then
            groundParams.FilterDescendantsInstances = { ctx.Geo }
            local hit = Workspace:Raycast(a, unit * range, groundParams)
            if hit then stop = (hit.Position - a).Magnitude end
        end
        local w = opts.Width or 1.6
        -- (2026-10-07, owner: "boss attacks often hit you when you're outside the radius": the beam was drawn 0.9 thick but
        -- hit 2.6 from its line -- now it is drawn exactly as wide as it hits)
        local beam = P({ Name = "AtkBeam", Size = Vector3.new(w * 1.4, w * 1.4, stop), CFrame = CFrame.lookAt(a, a + unit) * CFrame.new(0, 0, -stop / 2),
            Color = color, Transparency = 0.1, Parent = ctx.Fx })
        Debris:AddItem(beam, 0.14)
        Boom(beam, opts.Sound)
        for _, t in ipairs(Roots(ctx)) do
            local rel = t.Root.Position - a
            local along = rel:Dot(unit)
            if along > 0 and along <= stop + 1 and (rel - unit * along).Magnitude <= w * 0.7 + TOL then EA.StrikeHit(ctx, t.Player, opts.Mult or 1, opts.Plain) end
        end
        if opts.OnFire then opts.OnFire(a, a + unit * stop) end
    end)
end

-- ===== CHARGE: a glow that grows on the attacker while a shot charges (returns a stop function) =====
function EA.Charge(ctx: any, posFn: () -> Vector3, size: number, duration: number, color: Color3?): () -> ()
    local orb = P({ Name = "AtkCharge", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), Color = color or ctx.Color or EA.CORE,
        Transparency = 0.25, Parent = ctx.Fx })
    local t0 = os.clock()
    local alive = true
    task.spawn(function()
        while alive and orb.Parent and ctx.Alive() do
            local k = math.clamp((os.clock() - t0) / math.max(duration * CW(ctx), 0.01), 0, 1)
            local d = 0.3 + size * k
            orb.Size = Vector3.new(d, d, d)
            orb.CFrame = CFrame.new(posFn())
            RunService.Heartbeat:Wait()
        end
        if orb.Parent then orb:Destroy() end
    end)
    return function() alive = false; if orb.Parent then orb:Destroy() end end, orb -- (2026-10-30: + the orb, for a marksman's lock flicker)
end

-- ===== ZONE: a telegraphed circle that then LINGERS, hurting anyone standing in it (shrinks your safe space) =====
-- opts: Mult per tick (default 0.3), Tick (s, default 0.5), Color, Height (default 6), OnStart(center), OnEnd(), Tag, Hit (fn(player, mult))
function EA.Zone(ctx: any, center: Vector3, radius: number, windup: number, duration: number, opts: any?)
    opts = opts or {}
    windup = WindupFor(ctx, windup, opts.Mult)
    task.spawn(function()
        local y = EA.GroundY(ctx, center)
        local cf = CFrame.new(center.X, y + 0.08, center.Z) * DISC
        local base = P({ Name = "AtkZoneWarn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, radius * 2, radius * 2), CFrame = cf,
            Color = ctx.Color or EA.WARN, Material = ctx.Mat or Enum.Material.Neon, Transparency = ctx.MatT or 0.6, Parent = ctx.Fx })
        local rim = P({ Name = "AtkRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, radius * 2 + RIM_PAD, radius * 2 + RIM_PAD), CFrame = cf * CFrame.new(-0.02, 0, 0),
            Color = EA.OUTLINE, Material = Enum.Material.SmoothPlastic, Transparency = 0.3, Parent = ctx.Fx })
        task.delay(windup + duration + 0.05, function() rim:Destroy() end)
        local core = P({ Name = "AtkZoneCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.2, 0.2), CFrame = cf * CFrame.new(0.01, 0, 0),
            Color = ctx.Core or EA.CORE, Transparency = 0.35, Parent = ctx.Fx })
        local ok = Over(ctx, windup, function(k)
            local d = math.max(0.2, radius * 2 * k)
            core.Size = Vector3.new(0.12, d, d)
        end)
        base:Destroy()
        core:Destroy()
        if not ok then return end
        local col = opts.Color or ctx.Color or Color3.fromRGB(255, 70, 20)
        local zone = P({ Name = "AtkZone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, radius * 2, radius * 2), CFrame = cf,
            Color = col, Transparency = 0.5, Parent = ctx.Fx }) -- (the live hazard glows: neon, whatever the theme)
        Boom(zone, opts.Sound)
        if opts.OnStart then opts.OnStart(Vector3.new(center.X, y, center.Z), zone) end
        local hTop = opts.Height or 6 -- (lingering floor hazards stay low: jumping across a pool is fair movement)
        local tick = opts.Tick or 0.5
        local t0, lastTick = os.clock(), -1
        while os.clock() - t0 < duration and zone.Parent do
            local el = os.clock() - t0
            zone.Transparency = 0.5 + 0.12 * math.sin(el * 8) + (el > duration - 0.5 and (el - duration + 0.5) * 1.2 or 0)
            if el - lastTick >= tick then
                lastTick = el
                for _, t in ipairs(Roots(ctx)) do
                    local rp = t.Root.Position
                    local flat = Vector3.new(rp.X - center.X, 0, rp.Z - center.Z).Magnitude
                    if flat <= radius + math.min(0, TOL) and rp.Y - y <= hTop and rp.Y - y >= -3 then
                        EA.AreaHit = true -- (a pool you're standing in: no "hit from that way" arc toward the attacker)
                        EA.HitTag = opts.Tag -- (POE DAMAGE MODEL: "Chip" for the role pools; the Studio probe reads it)
                        if opts.Tag then EA.BurstFollow = true end -- (review 2: a role pool's tick never heals a Vampiric caster / rolls an ailment)
                        ;(opts.Hit or ctx.Hit)(t.Player, opts.Mult or 0.3) -- (opts.Hit: POE DAMAGE MODEL, a caster pool's hit)
                        EA.AreaHit = false
                        EA.HitTag = nil
                        EA.BurstFollow = nil
                    end
                end
            end
            RunService.Heartbeat:Wait()
        end
        zone:Destroy()
        if opts.OnEnd then opts.OnEnd() end
    end)
end

-- ===== SWEEP: a laser lying along the floor that ROTATES around an origin -- jump it or outrun it =====
-- originFn() -> Vector3. Angles in radians (0 = +Z). opts: Width (default 2.4), Height (default 3.4: a jump clears it),
-- Mult, Color, Warn (seconds of warning showing where it starts and which way it turns)
function EA.Sweep(ctx: any, originFn: () -> Vector3, startAngle: number, sweepAngle: number, duration: number, length: number, opts: any?)
    duration /= EA.MOVE_SPEED -- (a slower sweep: the player can't outrun the old one any more)
    opts = opts or {}
    task.spawn(function()
        local width, height = opts.Width or 2.4, opts.Height or 3.4
        local warnT = (opts.Warn or 0.6) * CW(ctx)
        local col = opts.Color or ctx.Color or EA.WARN
        local function Place(part, a, h)
            local o = originFn()
            local y = EA.GroundY(ctx, o)
            local dir = Vector3.new(math.sin(a), 0, math.cos(a))
            local base = Vector3.new(o.X, y + h / 2, o.Z)
            part.CFrame = CFrame.lookAt(base, base + dir) * CFrame.new(0, 0, -length / 2)
            return Vector3.new(o.X, y, o.Z), dir, y
        end
        -- warning: a ghost of the beam at its start + a second one a little along, showing the turn direction
        local w1 = P({ Name = "AtkSweepWarn", Size = Vector3.new(width, 0.12, length), Color = col, Transparency = 0.6, Parent = ctx.Fx })
        local w2 = P({ Name = "AtkSweepWarn", Size = Vector3.new(width * 0.5, 0.1, length), Color = ctx.Core or EA.CORE, Transparency = 0.75, Parent = ctx.Fx })
        local ok = Over(ctx, warnT, function(k)
            Place(w1, startAngle, 0.12)
            Place(w2, startAngle + sweepAngle * 0.12 * k, 0.1)
        end)
        w1:Destroy(); w2:Destroy()
        if not ok then return end
        local beam = P({ Name = "AtkSweep", Size = Vector3.new(width, height, length), Color = col, Transparency = 0.15, Parent = ctx.Fx })
        Boom(beam, opts.Sound)
        local hitDone = {}
        Over(ctx, duration, function(k)
            local a = startAngle + sweepAngle * k
            local o, dir, y = Place(beam, a, height)
            beam.Transparency = 0.15 + 0.1 * math.sin(os.clock() * 40)
            for _, t in ipairs(Roots(ctx)) do
                if not hitDone[t.Player] then
                    local rel = t.Root.Position - o
                    local along = rel.X * dir.X + rel.Z * dir.Z
                    local side = math.abs(rel.X * dir.Z - rel.Z * dir.X)
                    -- (0.61d: only the beam as drawn -- the "standing on something" rule hit you where the beam was buried)
                    if along >= 0 and along <= length and side <= width / 2 + TOL and rel.Y <= height + 1.2 and rel.Y >= -3 then
                        hitDone[t.Player] = true
                        ctx.Hit(t.Player, opts.Mult or 1)
                    end
                end
            end
        end)
        beam:Destroy()
    end)
end

-- ===== ARENA: the whole floor goes red except a few SAFE circles -- get to one =====
-- bounds = { MinX, MaxX, MinZ, MaxZ }, safe = { { Pos = Vector3, R = number }, ... }. opts: Mult, Height (default 10)
function EA.Arena(ctx: any, bounds: any, safe: { any }, windup: number, opts: any?)
    opts = opts or {}
    do -- (0.60: bigger safe circles for slower players)
        local grown = {}
        for _, sc in ipairs(safe) do table.insert(grown, { Pos = sc.Pos, R = sc.R * EA.SAFE_GROW }) end
        safe = grown
    end
    windup = WindupFor(ctx, windup, opts.Mult)
    task.spawn(function()
        local cx, cz = (bounds.MinX + bounds.MaxX) / 2, (bounds.MinZ + bounds.MaxZ) / 2
        local y = EA.GroundY(ctx, Vector3.new(cx, 0, cz))
        local sx, sz = bounds.MaxX - bounds.MinX + 16, bounds.MaxZ - bounds.MinZ + 16
        -- (0.61d, owner: "I die despite completely getting out of the range of the attack"): the wipe floor was drawn in the
        -- boss's own colour -- orange on a lava floor, nearly invisible, so it looked like you'd left it. It's a fixed deep
        -- crimson now on every biome, each safe circle gets a tall green light column, and only the drawn floor hits.
        local floor = P({ Name = "AtkArena", Size = Vector3.new(sx, 0.1, sz), CFrame = CFrame.new(cx, y + 0.06, cz), Color = Color3.fromRGB(190, 10, 40), Transparency = 0.45, Parent = ctx.Fx })
        local discs = {}
        for _, s in ipairs(safe) do
            local sy = EA.GroundY(ctx, s.Pos)
            table.insert(discs, P({ Name = "AtkSafe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, s.R * 2, s.R * 2),
                CFrame = CFrame.new(s.Pos.X, sy + 0.12, s.Pos.Z) * DISC, Color = Color3.fromRGB(120, 255, 170), Transparency = 0.3, Parent = ctx.Fx }))
            table.insert(discs, P({ Name = "AtkSafeBeam", Shape = Enum.PartType.Cylinder, Size = Vector3.new(36, s.R * 1.2, s.R * 1.2),
                CFrame = CFrame.new(s.Pos.X, sy + 18, s.Pos.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 255, 170), Transparency = 0.78, Parent = ctx.Fx }))
        end
        local ok = Over(ctx, windup, function(k)
            floor.Transparency = 0.85 - 0.3 * k + 0.06 * math.sin(k * math.pi * 10)
        end)
        for _, d in ipairs(discs) do d:Destroy() end
        if not ok then floor:Destroy() return end
        Flash(ctx, floor)
        Boom(floor, opts.Sound or "BossSlam")
        local hTop = SKY -- (a column: the wipe fills the arena top to bottom)
        for _, t in ipairs(Roots(ctx)) do
            local rp = t.Root.Position
            local inSafe = false
            for _, s in ipairs(safe) do
                if Vector3.new(rp.X - s.Pos.X, 0, rp.Z - s.Pos.Z).Magnitude <= s.R + 0.5 - math.min(0, TOL) * 2 then inSafe = true break end
            end
            local onFloor = rp.X >= cx - sx / 2 and rp.X <= cx + sx / 2 and rp.Z >= cz - sz / 2 and rp.Z <= cz + sz / 2
            if not inSafe and onFloor and rp.Y - y <= hTop then ctx.Hit(t.Player, opts.Mult or 1.5) end
        end
    end)
end

-- ===== MARK: a circle that hunts you for a while, then LOCKS and detonates -- move as it locks =====
-- opts: Lock (seconds locked before it goes off, default 0.35), Mult, Lag (how loosely it follows, default 6)
function EA.Mark(ctx: any, target: BasePart, radius: number, follow: number, opts: any?)
    radius *= EA.AREA
    opts = opts or {}
    task.spawn(function()
        local pos = target.Position
        local disc = P({ Name = "AtkMark", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, radius * 2, radius * 2), Color = ctx.Color or EA.WARN, Transparency = 0.4, Parent = ctx.Fx })
        local core = P({ Name = "AtkMarkCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, radius * 2, radius * 2), Color = ctx.Core or EA.CORE, Transparency = 0.35, Parent = ctx.Fx })
        local col = NewColumn(ctx, true, CFrame.new(pos), radius * 2, radius * 2, COLUMN_MIN)
        local lag = opts.Lag or 6
        local last = os.clock()
        local ok = Over(ctx, follow * CW(ctx), function(k)
            local now = os.clock()
            local dt = math.min(0.1, now - last)
            last = now
            if target.Parent then pos = pos:Lerp(target.Position, math.min(1, dt * lag)) end
            local y = EA.GroundY(ctx, pos)
            local cf = CFrame.new(pos.X, y + 0.08, pos.Z) * DISC
            disc.CFrame = cf
            PlaceColumn(col, CFrame.new(pos.X, y, pos.Z), radius * 2, radius * 2, ColumnTop(ctx, pos, radius, y))
            FillColumn(col, k)
            local d = radius * 2 * (1 - k * 0.85)
            core.Size = Vector3.new(0.14, d, d)
            core.CFrame = cf * CFrame.new(0.01, 0, 0)
        end)
        if not ok then disc:Destroy(); core:Destroy(); DropColumn(col) return end
        -- locked: it flashes in place
        -- (the lock is the dodge window -- the circle has been following you; a heavy mark keeps a fair one on every tier)
        local lockT = math.max((opts.Lock or 0.35) * CW(ctx), ((opts.Mult or 1.6) >= EA.HEAVY_MULT) and 0.6 or 0.4)
        ok = Over(ctx, lockT, function(k)
            disc.Transparency = (math.floor(k * 12) % 2 == 0) and 0.15 or 0.6
            core.Size = Vector3.new(0.14, radius * 2 * k, radius * 2 * k)
        end)
        disc:Destroy()
        if ok then ColumnFlash(col) else DropColumn(col) end
        if not ok then core:Destroy() return end
        local y = EA.GroundY(ctx, pos)
        core.Size = Vector3.new(0.3, radius * 2, radius * 2)
        Flash(ctx, core)
        Boom(core, opts.Sound or "BossSlam")
        for _, t in ipairs(Roots(ctx)) do
            local rp = t.Root.Position
            if Vector3.new(rp.X - pos.X, 0, rp.Z - pos.Z).Magnitude <= radius + TOL and rp.Y - y <= SKY then ctx.Hit(t.Player, opts.Mult or 1.6) end
        end
        if opts.OnStrike then opts.OnStrike(Vector3.new(pos.X, y, pos.Z)) end
    end)
end

-- Wind-up scale per difficulty: harder dungeons give you less time to react.
EA.DifficultyWindup = { Easy = 1.25, Normal = 1.1, Hard = 1.0, Brutal = 0.9, Nightmare = 0.82, Torment = 0.78, Cataclysm = 0.74, Oblivion = 0.7,
    Ruin = 0.68, Dread = 0.66, Apocalypse = 0.64, Annihilation = 0.62, Eternity = 0.6, Singularity = 0.58, Endless = 0.8 }

-- ===== ATTACK SLOTS ("honor system", playtester 2026-10-02: "you won't get attacked by every mob -- some mobs
-- reposition before attacking" / "maybe an enemy attack limit per second") =====
-- Before a bot winds up an attack on a player it takes one of that player's slots; only EA.SLOTS[difficulty] bots can
-- be winding up on the same player at once, and two attacks on the same player start at least EA.SLOT_GAP apart.
-- A bot that doesn't get a slot repositions (DungeonGenerator) and asks again a moment later. Elites and bosses
-- don't queue. Per Lua VM: the solo client runs its own bots, the server runs party bots.
-- (0.60c, owner: "later in the dungeons, the bots scale super hard and become harder than the bosses some times because there
-- are so many things attacking at once"): at most 2-3 wind-ups on you at once (4 only on the top three tiers), and elites
-- now queue too (TakeSlot extra = 1: they may be the one attacker past the limit, never a pile of them)
EA.SLOTS = { Easy = 2, Normal = 2, Hard = 2, Brutal = 2, Nightmare = 3, Torment = 3, Cataclysm = 3, Oblivion = 3,
    Ruin = 3, Dread = 3, Apocalypse = 3, Annihilation = 4, Eternity = 4, Singularity = 4, Endless = 3 }
EA.SLOT_GAP = 0.28 -- (0.60b: slots back to their old counts after "too easy"; a little more space between wind-ups than 0.22)
local slots = setmetatable({}, { __mode = "k" }) -- target part -> { holders = { [model] = until }, last = time }
function EA.TakeSlot(target: Instance, holder: Instance, holdFor: number, difficulty: string?, extra: number?, cap: number?): boolean
    local now = os.clock()
    local t = slots[target]
    if not t then t = { holders = {}, last = -99 }; slots[target] = t end
    local n = 0
    for h, untilT in pairs(t.holders) do
        if untilT <= now or not h.Parent then t.holders[h] = nil elseif h ~= holder then n += 1 end
    end
    if now - t.last < EA.SLOT_GAP then return false end
    if n >= (cap or EA.SLOTS[difficulty or ""] or 3) + (extra or 0) then return false end -- (cap: 0.61 BOT_PACE.Slots)
    t.holders[holder] = now + holdFor
    t.last = now
    return true
end

-- ===== DONUT: the ring BETWEEN two radii goes off -- stand inside rIn (by the attacker) or outside rOut =====
-- (BOSS v4 variety, 2026-10-06: the "get in / get out" read; paired with a Circle of radius rIn it's a two-step dance)
-- opts: Mult, Segments (default 18), Sound, OnStrike(center)
function EA.Donut(ctx: any, center: Vector3, rIn: number, rOut: number, windup: number, opts: any?)
    opts = opts or {}
    windup = WindupFor(ctx, windup, opts.Mult)
    task.spawn(function()
        local y = EA.GroundY(ctx, center)
        local c = Vector3.new(center.X, y + 0.07, center.Z)
        local segs = opts.Segments or 18
        local mid, w = (rIn + rOut) / 2, rOut - rIn
        local fills, rims = {}, {}
        for i = 1, segs do
            local a = (i - 0.5) / segs * math.pi * 2
            local pos = c + Vector3.new(math.cos(a) * mid, 0, math.sin(a) * mid)
            local cf = CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z))
            local arc = 2 * math.pi * rOut / segs + 0.3
            fills[i] = P({ Name = "AtkDonut", Size = Vector3.new(arc, 0.1, w), CFrame = cf, Color = ctx.Color or EA.WARN,
                Material = ctx.Mat or Enum.Material.Neon, Transparency = ctx.MatT or 0.6, Parent = ctx.Fx })
            -- the two bright edges (inner + outer) so the safe middle reads at a glance (cf looks at the centre: -Z = inward)
            local inArc = 2 * math.pi * rIn / segs + 0.3
            rims[#rims + 1] = P({ Name = "AtkRim", Size = Vector3.new(inArc, 0.08, 1.3), CFrame = cf * CFrame.new(0, -0.02, -(w / 2 - 0.65)), Parent = ctx.Fx })
            rims[#rims + 1] = P({ Name = "AtkRim", Size = Vector3.new(arc, 0.08, 1.3), CFrame = cf * CFrame.new(0, -0.02, w / 2 - 0.65), Parent = ctx.Fx })
        end
        local ok = Over(ctx, windup, function(k)
            for _, f in ipairs(fills) do f.Transparency = 0.75 - 0.4 * k end
        end)
        for _, r in ipairs(rims) do r:Destroy() end
        if not ok then for _, f in ipairs(fills) do f:Destroy() end return end
        for _, f in ipairs(fills) do f.Color = ctx.Core or EA.CORE; Flash(ctx, f) end
        if fills[1] then Boom(fills[1], opts.Sound) end
        for _, t in ipairs(Roots(ctx)) do
            local rp = t.Root.Position
            local flat = Vector3.new(rp.X - c.X, 0, rp.Z - c.Z).Magnitude
            if flat >= rIn - TOL and flat <= rOut + TOL and rp.Y - y <= SKY and rp.Y - y >= -3 then ctx.Hit(t.Player, opts.Mult or 1) end
        end
        if opts.OnStrike then opts.OnStrike(Vector3.new(center.X, y, center.Z)) end
    end)
end

-- ===== ROLLER: a ball that ROLLS along a marked path -- step off the trail of dots before it reaches you =====
-- (BOSS v4 variety: a moving hazard instead of another static strip.) path = { Vector3 } (2+ points, followed in order),
-- radius = the ball's, speed = studs/s. opts: Mult, Color, Look ("Ball" | "Wheel"), Sound
function EA.Roller(ctx: any, path: { Vector3 }, radius: number, speed: number, windup: number, opts: any?)
    opts = opts or {}
    windup = WindupFor(ctx, windup, opts.Mult)
    task.spawn(function()
        if #path < 2 then return end
        -- the trail: a dot every ~1.6 radii, so you can read where it will go
        local dots = {}
        for i = 1, #path - 1 do
            local a, b = path[i], path[i + 1]
            local len = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
            local n = math.max(1, math.floor(len / (radius * 1.6)))
            for k = 0, n - 1 do
                if #dots >= 40 then break end
                local q = a:Lerp(b, k / n)
                local gy = EA.GroundY(ctx, q)
                table.insert(dots, P({ Name = "AtkRollerPath", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, radius * 1.1, radius * 1.1),
                    CFrame = CFrame.new(q.X, gy + 0.07, q.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = ctx.Color or EA.WARN, Transparency = 0.75, Parent = ctx.Fx }))
            end
        end
        local ok = Over(ctx, windup, function(k)
            for _, d in ipairs(dots) do d.Transparency = 0.75 - 0.3 * k end
        end)
        if not ok then for _, d in ipairs(dots) do d:Destroy() end return end
        local wheel = opts.Look == "Wheel"
        local ball = P({ Name = "AtkRoller", Shape = wheel and Enum.PartType.Cylinder or Enum.PartType.Ball,
            Size = wheel and Vector3.new(radius * 0.9, radius * 2, radius * 2) or Vector3.new(radius * 2, radius * 2, radius * 2),
            Color = opts.Color or ctx.Color or EA.WARN, Material = Enum.Material.Neon, Transparency = 0.35, Parent = ctx.Fx })
        -- (the attacker's colour, a little see-through: the near-white core colour bloomed into a glowing orb)
        Boom(ball, opts.Sound)
        local hitDone = {}
        local spin = 0
        for i = 1, #path - 1 do
            local a, b = path[i], path[i + 1]
            local flatAB = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
            local len = flatAB.Magnitude
            local dir = len > 0.01 and flatAB.Unit or Vector3.zAxis
            local t0 = os.clock()
            local dur = len / speed
            while ctx.Alive() do
                local k = math.min(1, (os.clock() - t0) / math.max(dur, 0.01))
                local q = a:Lerp(b, k)
                local gy = EA.GroundY(ctx, q)
                spin += 0.25
                local at = Vector3.new(q.X, gy + radius, q.Z)
                local cf = CFrame.lookAt(at, at + dir)
                ball.CFrame = wheel and (cf * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(spin, 0, 0)) or (cf * CFrame.Angles(-spin, 0, 0))
                -- dots it has rolled over fade out
                for _, d in ipairs(dots) do
                    if d.Transparency < 1 and Vector3.new(d.Position.X - q.X, 0, d.Position.Z - q.Z).Magnitude < radius then d.Transparency = 1 end
                end
                for _, t in ipairs(Roots(ctx)) do
                    if not hitDone[t.Player] then
                        local rp = t.Root.Position
                        local flat = Vector3.new(rp.X - q.X, 0, rp.Z - q.Z).Magnitude
                        if flat <= radius + TOL and rp.Y - gy <= radius * 2 + 2 and rp.Y - gy >= -3 then
                            hitDone[t.Player] = true
                            ctx.Hit(t.Player, opts.Mult or 1)
                        end
                    end
                end
                if k >= 1 then break end
                RunService.Heartbeat:Wait()
            end
        end
        for _, d in ipairs(dots) do d:Destroy() end
        Flash(ctx, ball)
        task.delay(0.2, function() ball:Destroy() end)
    end)
end

-- ======================================================================================================================
-- ENEMY ATTACKS PILOT (2026-10-30, owner: "The bot attacks kind of just all feel the same and very boring"; contract
-- docs/ENEMY_ATTACKS_2026-10-30.md). Regular bots get ROLES (AimRngShared/BotRoles): the floor shapes above stay for heavies and
-- bosses, the rest of the damage comes from things you can SEE coming through the air or on the attacker's body:
--   Shot    one visible round (pooled: ONE part + one short Trail; no lights / particles / flashing), coloured by its damage
--           type, travel time, stopped by walls, fades harmlessly when its shooter dies
--   Shell   a slow lobbed round you can SHOOT DOWN (a "AtkShell" part the player's shots hit); its landing spot is marked
--   Swing   a melee swing told on the BODY (a growing glow), one short arc at the strike -- nothing on the floor
--   Aim     a marksman's charge: a glint growing on its body, a lock flicker, then one hard fast Shot; opts.Cancelled() (a weak-spot
--           hit, BotRoles) stops it
--   Stagger the attacker stops moving / attacking for a moment (model attr StaggerUntil, server time) + a small ring over it
-- CLUTTER: at most SHOT_CAP shots + shells in flight at one player (EA.ShotRoom); every attack still takes an attack slot.
-- ======================================================================================================================
EA.SHOT_CAP = 6
local NEAR_TAG -- (set below: the tag the client's near-camera fade watches)
EA.SHOT_SPEED = 48     -- gunners (x MOVE_SPEED): ~0.75 s over 30 studs -- moving clears it, standing still is hit (review re-measure: 58 hit 3-4x as often as the old floor shapes)
EA.SNIPE_SPEED = 95    -- marksmen
EA.SHOT_RANGE = 150
EA.SHOT_GLOW = 0.9     -- the round's neon is drawn at this share of its colour (no bloom)
EA.SHOT_LIFT = 0.35    -- ...after lifting it this far toward white (an orange round on a lava floor still reads)
EA.BODY_LO, EA.BODY_HI, EA.BODY_R = -2.6, 1.9, 0.7 -- the player's body vs their root (a capsule) for shots (0.85 -> 0.7: the torso, not the arms)
EA.STAGGER_S = 1.0
-- clutter probe (DevCmd / the frame probe read these): live = in flight now, Max = the most at once since the last reset
EA.ShotStats = { Live = 0, Max = 0, Fired = 0, Hits = 0, Walls = 0, Faded = 0, Shells = 0, Popped = 0, Landed = 0 }
function EA.ResetShotStats() for k in pairs(EA.ShotStats) do EA.ShotStats[k] = 0 end end
EA.Part = P
-- (Studio probe: workspace attr DevShotStats (solo client) / DevShotStatsSrv (party server) mirrors ShotStats -- MCP scripts can't
-- require modules; set DevShotReset to reset)
local IS_STUDIO = RunService:IsStudio()
local statsDirty = false
local function PublishStats()
    if not IS_STUDIO or statsDirty then return end
    statsDirty = true
    task.defer(function()
        statsDirty = false
        local S = EA.ShotStats
        Workspace:SetAttribute(RunService:IsClient() and "DevShotStats" or "DevShotStatsSrv", string.format("live=%d max=%d fired=%d hits=%d walls=%d faded=%d shells=%d popped=%d landed=%d",
            S.Live, S.Max, S.Fired, S.Hits, S.Walls, S.Faded, S.Shells, S.Popped, S.Landed))
    end)
end
if IS_STUDIO then
    Workspace:GetAttributeChangedSignal("DevShotReset"):Connect(function() EA.ResetShotStats(); PublishStats() end)
end

local liveAt = setmetatable({}, { __mode = "k" }) -- target part -> shots / shells in flight at it
local function LiveAt(target: Instance?): number return (target and liveAt[target]) or 0 end
EA.LiveAt = LiveAt
function EA.ShotRoom(target: Instance?, n: number?): boolean
    return LiveAt(target) + (n or 1) <= EA.SHOT_CAP
end
local function Count(rec: any, d: number)
    local t = rec.Target
    if t then liveAt[t] = math.max(0, (liveAt[t] or 0) + d) end
    local S = EA.ShotStats
    S.Live = math.max(0, S.Live + d)
    if S.Live > S.Max then S.Max = S.Live end
    PublishStats()
end

-- closest distance between segments p1-q1 and p2-q2
local function SegSeg(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3): number
    local d1, d2, r = q1 - p1, q2 - p2, p1 - p2
    local a, e, f = d1:Dot(d1), d2:Dot(d2), d2:Dot(r)
    local s, t
    if a <= 1e-6 and e <= 1e-6 then return r.Magnitude end
    if a <= 1e-6 then
        s, t = 0, math.clamp(f / e, 0, 1)
    else
        local c = d1:Dot(r)
        if e <= 1e-6 then
            t, s = 0, math.clamp(-c / a, 0, 1)
        else
            local b = d1:Dot(d2)
            local den = a * e - b * b
            s = (den > 1e-9) and math.clamp((b * f - c * e) / den, 0, 1) or 0
            t = (b * s + f) / e
            if t < 0 then t, s = 0, math.clamp(-c / a, 0, 1)
            elseif t > 1 then t, s = 1, math.clamp((b - c) / a, 0, 1) end
        end
    end
    return ((p1 + d1 * s) - (p2 + d2 * t)).Magnitude
end
EA.SegSeg = SegSeg

local LOW = RunService:IsClient() and (function()
    local ok, Q = pcall(require, script.Parent:WaitForChild("QualityMode"))
    return ok and Q or nil
end)() or nil
-- ----- NEAR-CAMERA FADE (client only): a round / shell that passes within EA.NEAR_FADE studs of YOUR camera fades out (fully gone
-- inside EA.NEAR_GONE) and its trail switches off, so a near miss never blots out the screen (a 0.75-stud ball 1 stud from the lens
-- filled a quarter of it). Works for party rounds too (the server's parts carry the tag; LocalTransparencyModifier is local).
-- One RenderStepped connection, only while a tagged part is in the world; a distance check per part, a write only on change.
NEAR_TAG = "AtkRound"
EA.NEAR_FADE, EA.NEAR_GONE = 9, 4 -- (6 / 2.5 still left a big see-through ball at ~3.5 studs in the first screenshot)
if RunService:IsClient() then
    local near = {}
    local nearN = 0
    local nearConn: RBXScriptConnection? = nil
    local function NearStep()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local c = cam.CFrame.Position
        for part in pairs(near) do
            local d = (part.Position - c).Magnitude
            local m = 0
            if d < EA.NEAR_FADE then m = math.clamp((EA.NEAR_FADE - d) / (EA.NEAR_FADE - EA.NEAR_GONE), 0, 1) end
            if part.LocalTransparencyModifier ~= m then
                part.LocalTransparencyModifier = m
                local tr = part:FindFirstChild("Trail")
                if tr and m >= 0.2 and tr.Enabled then tr.Enabled = false end -- (its trail streaked past the lens)
            end
        end
    end
    local function Add(part: Instance)
        if not part:IsA("BasePart") or near[part] then return end
        if LOW and LOW.IsLow() then -- (review N: Low graphics = no trails, party rounds too -- the server can't know your setting)
            local tr = part:FindFirstChild("Trail")
            if tr then tr.Enabled = false end
        end
        near[part] = true
        nearN += 1
        if not nearConn then nearConn = RunService.RenderStepped:Connect(NearStep) end
    end
    local function Remove(part: Instance)
        if not near[part] then return end
        near[part] = nil
        nearN -= 1
        if part:IsA("BasePart") then part.LocalTransparencyModifier = 0 end
        if nearN <= 0 and nearConn then nearConn:Disconnect(); nearConn = nil; nearN = 0 end
    end
    CollectionService:GetInstanceAddedSignal(NEAR_TAG):Connect(Add)
    CollectionService:GetInstanceRemovedSignal(NEAR_TAG):Connect(Remove)
    for _, p in ipairs(CollectionService:GetTagged(NEAR_TAG)) do Add(p) end
end

-- ----- the round pool (one part + a trail each; parked with Parent = nil) -----
local pool = {}
local function NewRound(): BasePart
    local p = Instance.new("Part")
    p.Name = "AtkShot"; p.Shape = Enum.PartType.Ball; p.Material = Enum.Material.Neon
    CollectionService:AddTag(p, NEAR_TAG) -- (the client fades it when it passes the camera, see NEAR-CAMERA FADE)
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    local a0 = Instance.new("Attachment"); a0.Name = "T0"; a0.Parent = p
    local a1 = Instance.new("Attachment"); a1.Name = "T1"; a1.Parent = p
    local tr = Instance.new("Trail")
    tr.Name = "Trail"; tr.Attachment0 = a0; tr.Attachment1 = a1
    tr.Lifetime = 0.12; tr.FaceCamera = true; tr.LightEmission = 0; tr.LightInfluence = 0; tr.MinLength = 0.05
    tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
    tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.25) })
    tr.Enabled = false
    tr.Parent = p
    return p
end
local function TakeRound(fx: Instance): BasePart
    while #pool > 0 do
        local p = table.remove(pool)
        local ok = pcall(function() p.Parent = fx end)
        if ok and p.Parent == fx then return p end
    end
    local p = NewRound()
    if not pcall(function() p.Parent = fx end) then p:Destroy() return nil :: any end -- (its floor was torn down)
    return p
end
local function ParkRound(p: BasePart)
    local tr = p:FindFirstChild("Trail") :: Trail?
    if tr then tr.Enabled = false end
    local ok = pcall(function() p.Parent = nil end) -- (a floor torn down under it destroyed it: drop it)
    if ok and #pool < 40 then table.insert(pool, p) elseif ok then p:Destroy() end
end

local live = {}     -- every shot / shell in flight
local shellOf = {}  -- shell part -> its record (PopShell)
local stepConn: RBXScriptConnection? = nil
local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Include

local function EndRec(rec: any, how: string)
    if rec.Done then return end
    rec.Done = true
    Count(rec, -1)
    local S = EA.ShotStats
    if how == "hit" then S.Hits += 1 elseif how == "wall" then S.Walls += 1 elseif how == "fade" then S.Faded += 1
    elseif how == "pop" then S.Popped += 1 elseif how == "land" then S.Landed += 1 end
    if rec.Shell then
        shellOf[rec.Part] = nil
        for _, d in ipairs(rec.Marks or {}) do if d.Parent then d:Destroy() end end
        local part = rec.Part
        if how == "pop" or how == "fade" then
            -- shot down / its heavy died: the shell bursts (or fades) in the air, harmless
            task.spawn(function()
                local s0 = part.Size.X
                local t0 = os.clock()
                while part.Parent and os.clock() - t0 < 0.18 do
                    local k = (os.clock() - t0) / 0.18
                    local d = s0 * (1 + ((how == "pop") and 0.9 or 0) * k)
                    part.Size = Vector3.new(d, d, d)
                    part.Transparency = 0.2 + 0.8 * k
                    RunService.Heartbeat:Wait()
                end
                if part.Parent then part:Destroy() end
            end)
            if how == "pop" then Boom(part, "EnemyHit") end
        else
            part:Destroy()
        end
        return
    end
    if how == "fade" then
        rec.FadeFrom = os.clock() -- (the stepper fades it, then parks it)
        rec.Done = false; rec.Fading = true; Count(rec, 1) -- (still on screen while it fades)
        return
    end
    ParkRound(rec.Part)
end

local function Step(dt: number)
    if #live == 0 then
        if stepConn then stepConn:Disconnect(); stepConn = nil end
        return
    end
    local now = os.clock()
    dt = math.min(dt, 0.1)
    -- (review N) one Roots() read a ctx a step (each read walks ctx.Targets()), cast params built once per ctx
    local rootsOf = {}
    local function RootsOf(ctx: any)
        local r = rootsOf[ctx]
        if not r then r = Roots(ctx); rootsOf[ctx] = r end
        return r
    end
    for i = #live, 1, -1 do
        local rec = live[i]
        local ctx = rec.Ctx
        if rec.Fading then
            local k = (now - rec.FadeFrom) / 0.15
            if k >= 1 or not rec.Part.Parent then
                rec.Fading = false; rec.Done = true; Count(rec, -1); ParkRound(rec.Part)
                table.remove(live, i)
            else
                rec.Part.Transparency = rec.T0 + (1 - rec.T0) * k
            end
            continue
        end
        if rec.Done then table.remove(live, i) continue end
        if not rec.Part.Parent then
            -- (review G) its floor was torn down under it: drop the record (and a shell's lookup + marks) too
            rec.Done = true; Count(rec, -1); table.remove(live, i)
            if rec.Shell then
                shellOf[rec.Part] = nil
                for _, d in ipairs(rec.Marks or {}) do if d.Parent then d:Destroy() end end
            end
            continue
        end
        if not ctx.Alive() then EndRec(rec, "fade"); if rec.Done then table.remove(live, i) end continue end
        if rec.Seek or rec.Static then -- (ENEMY VARIETY 2026-11-07: a homing SEEKER / a standing BEACON -- both shootable, like a shell)
            if rec.Popped then EndRec(rec, "pop"); table.remove(live, i) continue end
            if now - rec.Born >= rec.Life then EndRec(rec, "fade"); table.remove(live, i) continue end
            if rec.Static then continue end
            local t = rec.Target
            if t and t.Parent and now - rec.Born >= rec.Arm then
                local want = (t.Position + Vector3.new(0, 0.4, 0)) - rec.Pos
                if want.Magnitude > 0.1 then
                    want = want.Unit
                    local d = rec.Dir
                    local a = math.acos(math.clamp(d:Dot(want), -1, 1))
                    local maxA = rec.Turn * dt
                    if a > maxA then
                        local axis = d:Cross(want)
                        if axis.Magnitude < 1e-4 then axis = Vector3.yAxis end
                        rec.Dir = CFrame.fromAxisAngle(axis.Unit, maxA):VectorToWorldSpace(d).Unit
                    else
                        rec.Dir = want
                    end
                end
            end
            local from = rec.Pos
            local step = rec.Dir * rec.Speed * dt
            local to = from + step
            local wall = false
            if ctx.Geo and ctx.Geo.Parent then
                local cp = ctx._ShotCast
                if not cp then
                    cp = RaycastParams.new()
                    cp.FilterType = Enum.RaycastFilterType.Include
                    cp.FilterDescendantsInstances = { ctx.Geo, Workspace.Terrain }
                    ctx._ShotCast = cp
                end
                local hit = Workspace:Raycast(from, step, cp)
                if hit then to = hit.Position; wall = true end
            end
            for _, tt in ipairs(RootsOf(ctx)) do
                local rp = tt.Root.Position
                if SegSeg(from, to, rp + Vector3.new(0, EA.BODY_LO, 0), rp + Vector3.new(0, EA.BODY_HI, 0)) <= rec.R + EA.BODY_R + rec.Tol then
                    EA.HitTag = rec.Tag
                    EA.StrikeHit(ctx, tt.Player, rec.Mult, nil)
                    EA.HitTag = nil
                    EndRec(rec, "hit")
                    break
                end
            end
            if rec.Done then table.remove(live, i) continue end
            if wall then EndRec(rec, "wall"); table.remove(live, i) continue end
            rec.Pos = to
            rec.Part.CFrame = CFrame.new(to)
            continue
        end
        if rec.Shell then
            if rec.Popped then EndRec(rec, "pop"); table.remove(live, i) continue end
            local k = math.clamp((now - rec.Born) / rec.Flight, 0, 1)
            local pos = rec.From:Lerp(rec.To, k) + Vector3.new(0, 4 * rec.Apex * k * (1 - k), 0)
            rec.Part.CFrame = CFrame.new(pos)
            if rec.Core then
                local d = math.max(0.2, rec.R * 2 * k)
                rec.Core.Size = Vector3.new(0.12, d, d)
            end
            if k >= 1 then
                -- landed: everything inside the marked circle is hit (a column, like every heavy area)
                local c = rec.To
                for _, t in ipairs(RootsOf(ctx)) do
                    local rp = t.Root.Position
                    local flat = Vector3.new(rp.X - c.X, 0, rp.Z - c.Z).Magnitude
                    if flat <= rec.R + TOL and rp.Y - c.Y <= SKY and rp.Y - c.Y >= -3 then
                        EA.HitTag = rec.Tag
                        EA.StrikeHit(ctx, t.Player, rec.Mult, nil)
                        EA.HitTag = nil
                    end
                end
                if rec.Core and rec.Core.Parent then
                    rec.Core.Size = Vector3.new(0.3, rec.R * 2, rec.R * 2)
                    rec.Core.Parent = ctx.Fx
                    Flash(ctx, rec.Core)
                    rec.Marks[#rec.Marks] = nil -- (the core is the flash now; Debris removes it)
                end
                Boom(rec.Part, rec.Sound or "AreaStrike")
                if rec.OnStrike then pcall(rec.OnStrike, c) end
                EndRec(rec, "land")
                table.remove(live, i)
            end
            continue
        end
        -- a round
        local from = rec.Pos
        local step = rec.Vel * dt
        local to = from + step
        rec.Travel += step.Magnitude
        local ended = false
        -- walls / cover / terrain stop it
        if ctx.Geo and ctx.Geo.Parent then
            local cp = ctx._ShotCast
            if not cp then
                cp = RaycastParams.new()
                cp.FilterType = Enum.RaycastFilterType.Include
                cp.FilterDescendantsInstances = { ctx.Geo, Workspace.Terrain }
                ctx._ShotCast = cp
            end
            local hit = Workspace:Raycast(from, step, cp)
            if hit then to = hit.Position; ended = true end
        end
        -- the player's body (a capsule from root + BODY_LO to root + BODY_HI): exact on solo floors, the server's TOL on party ones
        for _, t in ipairs(RootsOf(ctx)) do
            if not rec.HitDone[t.Player] then
                local rp = t.Root.Position
                local d = SegSeg(from, to, rp + Vector3.new(0, EA.BODY_LO, 0), rp + Vector3.new(0, EA.BODY_HI, 0))
                if d <= rec.R + EA.BODY_R + rec.Tol then
                    rec.HitDone[t.Player] = true
                    -- (review B) a burst's round: only the first round that lands on this player rolls the ailment / Vampiric heal
                    -- (DungeonGenerator.HitPlayer reads EA.BurstFollow). (POE DAMAGE MODEL) Plating sizes a SPIKE burst as the whole
                    -- burst (EA.BurstScale); a CHIP burst's rounds are judged one by one -- small hits, which Plating cuts hardest.
                    local bu = rec.Burst
                    if bu then
                        if bu.Whole then EA.BurstScale = bu.Total / math.max(0.01, rec.Mult) end
                        EA.BurstFollow = bu.Landed[t.Player] == true
                        bu.Landed[t.Player] = true
                    end
                    EA.HitTag = rec.Tag
                    EA.StrikeHit(ctx, t.Player, rec.Mult, rec.Plain)
                    EA.BurstScale, EA.BurstFollow, EA.HitTag = nil, nil, nil
                    EndRec(rec, "hit")
                    break
                end
            end
        end
        if rec.Done then table.remove(live, i) continue end
        if ended then EndRec(rec, "wall"); table.remove(live, i) continue end
        if rec.Travel >= rec.Range then EndRec(rec, "fade"); if rec.Done then table.remove(live, i) end continue end
        rec.Pos = to
        rec.Part.CFrame = CFrame.lookAt(to, to + rec.Vel)
    end
end
local function Track(rec: any)
    table.insert(live, rec)
    Count(rec, 1)
    if not stepConn then stepConn = RunService.Heartbeat:Connect(Step) end
end

local function DimTo(c: Color3, k: number): Color3 return Color3.new(c.R * k, c.G * k, c.B * k) end

-- ===== SHOT: one visible round from `from` toward `aim` =====
-- opts: Speed (default SHOT_SPEED), Size (diameter, 0.75), Mult, Color (else ctx.ShotColor), Range, Plain, Target (the player part it is
-- fired at: the in-flight count), Sound (a fire sound at the muzzle; nil = none), Tag ("Chip" / "Spike": POE DAMAGE MODEL, the probe)
-- (POE DAMAGE MODEL) the round's real speed: base (studs/s) x MOVE_SPEED x the ctx's tier speed (CreateBot sets ctx.TierSpeed; bosses 1)
function EA.ShotSpeed(ctx: any, base: number?): number
    return (base or EA.SHOT_SPEED) * EA.MOVE_SPEED * ((ctx and ctx.TierSpeed) or 1)
end
function EA.Shot(ctx: any, from: Vector3, aim: Vector3, opts: any?)
    opts = opts or {}
    local dir = aim - from
    if dir.Magnitude < 0.05 then return end
    if opts.Target and LiveAt(opts.Target) >= EA.SHOT_CAP then return end -- (the clutter cap, checked at the release too)
    local speed = EA.ShotSpeed(ctx, opts.Speed)
    if IS_STUDIO and type(Workspace:GetAttribute("DevShotSlow")) == "number" then speed *= Workspace:GetAttribute("DevShotSlow") end -- (Studio: slow rounds for screenshots)
    local size = opts.Size or 0.75
    local col = (opts.Color or ctx.ShotColor or EA.WARN):Lerp(Color3.new(1, 1, 1), EA.SHOT_LIFT)
    local p = TakeRound(ctx.Fx)
    if not p then return end
    p.Size = Vector3.new(size, size, size)
    p.Color = DimTo(col, EA.SHOT_GLOW)
    p.Transparency = 0.1
    p.CFrame = CFrame.lookAt(from, from + dir)
    local tr = p:FindFirstChild("Trail") :: Trail?
    if tr then
        local a0, a1 = p:FindFirstChild("T0") :: Attachment?, p:FindFirstChild("T1") :: Attachment?
        if a0 and a1 then a0.Position = Vector3.new(0, size * 0.4, 0); a1.Position = Vector3.new(0, -size * 0.4, 0) end
        -- (the TRAIL wears the SHOOTER's own colour -- a Molten bot's rounds read as fire even when they hit Kinetic; the core keeps
        -- the honest damage-type colour)
        local tc = opts.TrailColor or ctx.TrailColor
        tr.Color = ColorSequence.new(tc and DimTo(tc:Lerp(Color3.new(1, 1, 1), 0.15), EA.SHOT_GLOW) or DimTo(col, EA.SHOT_GLOW))
        tr.Lifetime = (opts.Tag == "Chip") and math.clamp(6 / speed, 0.04, 0.12) or 0.12 -- (POE DAMAGE MODEL: a chip tracer leaves a ~6-stud streak, not 22)
        tr:Clear()
        tr.Enabled = not (LOW and LOW.IsLow())
    end
    EA.ShotStats.Fired += 1
    Track({ Part = p, Ctx = ctx, Pos = from, Vel = dir.Unit * speed, R = size / 2, Mult = opts.Mult or 1, Plain = opts.Plain,
        Range = opts.Range or EA.SHOT_RANGE, Travel = 0, Target = opts.Target, HitDone = {}, T0 = 0.1, Burst = opts.Burst, Tag = opts.Tag,
        -- (review 2) a CHIP round gets no server forgiveness: with TOL -0.4 the party fan had ~0.65-stud holes between its rounds
        -- (FAN_W 2 vs a 0.68 reach); chip is unreactable anyway, so party chip = solo chip. Spikes keep the benefit of the doubt.
        Tol = (opts.Tag == "Chip") and math.max(0, TOL) or TOL })
    if opts.Sound then Boom(p, opts.Sound) end
end

-- ===== SHELL: a slow lobbed round -- dodge where it lands, or SHOOT IT DOWN =====
-- from -> `to` (snapped to the floor under it) over `flight` seconds. opts: Mult, Radius (the marked landing circle, default 5),
-- Size (1.7), Color, Apex (arc height), Target, OnStrike(center), Sound (landing). Returns the shell part.
function EA.Shell(ctx: any, from: Vector3, to: Vector3, flight: number, opts: any?): BasePart?
    opts = opts or {}
    if opts.Target and LiveAt(opts.Target) >= EA.SHOT_CAP then return nil end -- (the clutter cap)
    local y = EA.GroundY(ctx, to)
    local land = Vector3.new(to.X, y, to.Z)
    local r = (opts.Radius or 5) * EA.AREA
    flight = math.max(0.6, flight * EA.REACT / ((ctx and ctx.TierSpeed) or 1)) -- (POE DAMAGE MODEL: higher tiers land sooner)
    if IS_STUDIO and type(Workspace:GetAttribute("DevShotSlow")) == "number" then flight /= math.max(0.05, Workspace:GetAttribute("DevShotSlow")) end
    local col = opts.Color or ctx.Color or EA.WARN
    local cf = CFrame.new(land.X, y + 0.07, land.Z) * DISC
    local marks = {}
    -- the landing mark: a ring + a core that fills with the flight (the heavy's floor tell)
    table.insert(marks, P({ Name = "AtkCircle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, r * 2, r * 2), CFrame = cf,
        Color = col, Material = ctx.Mat or Enum.Material.Neon, Transparency = ctx.MatT or 0.6, Parent = ctx.Fx }))
    table.insert(marks, P({ Name = "AtkRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, r * 2 + RIM_PAD, r * 2 + RIM_PAD), CFrame = cf * CFrame.new(-0.02, 0, 0),
        Color = EA.OUTLINE, Material = Enum.Material.SmoothPlastic, Transparency = 0.3, Parent = ctx.Fx }))
    local core = P({ Name = "AtkCircleCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.2, 0.2), CFrame = cf * CFrame.new(0.01, 0, 0),
        Color = ctx.Core or EA.CORE, Transparency = 0.35, Parent = ctx.Fx })
    table.insert(marks, core)
    local size = opts.Size or 1.7
    local shell = P({ Name = "AtkShell", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = CFrame.new(from),
        Color = col, Transparency = 0.05, Parent = ctx.Fx })
    shell.Color = DimTo(col, EA.SHOT_GLOW) -- (one part: a dim glowing ball, big enough to shoot)
    shell.CanQuery = true -- (the player's shots hit it: CombatServer / AimRngClient pop it)
    shell:SetAttribute("ShellShot", true)
    CollectionService:AddTag(shell, NEAR_TAG)
    local dist = Vector3.new(land.X - from.X, 0, land.Z - from.Z).Magnitude
    local rec = { Shell = true, Part = shell, Ctx = ctx, From = from, To = land, Flight = flight, Born = os.clock(),
        Apex = opts.Apex or math.max(5, dist * 0.22), R = r, Core = core, Marks = marks, Mult = opts.Mult or 1, Target = opts.Target,
        OnStrike = opts.OnStrike, Sound = opts.Sound, Tag = opts.Tag }
    shellOf[shell] = rec
    EA.ShotStats.Shells += 1
    Track(rec)
    return shell
end
-- a player's shot hit a shell (solo: the client's own; party: CombatServer after its checks) -> it bursts harmlessly
function EA.PopShell(part: Instance?): boolean
    local rec = part and shellOf[part]
    if not rec or rec.Done or rec.Popped then return false end
    rec.Popped = true
    return true
end
function EA.IsShell(part: Instance?): boolean return part ~= nil and shellOf[part] ~= nil end

-- ===== ENEMY VARIETY (2026-11-07; contract docs/ENEMY_VARIETY_2026-11-07.md, rows AimRngShared/BotVerbs) =====
-- SEEKER: one slow glowing orb that turns toward you (at most opts.Turn deg/s, after opts.Arm s) -- SHOOT IT DOWN (it is an
-- "AtkShell" part: the same pop path as a heavy's shell on both floor types) or beat its turn with a late sidestep. Life-limited.
-- opts: Mult, Speed (studs/s before MOVE_SPEED x tier), Turn (deg/s), Arm (s), Life (s), Size, Color, Target, Tag, Sound
function EA.Seeker(ctx: any, from: Vector3, opts: any): BasePart?
    local t = opts.Target
    if t and LiveAt(t) >= EA.SHOT_CAP then return nil end
    local size = opts.Size or 1.3
    local col = (opts.Color or ctx.ShotColor or EA.WARN):Lerp(Color3.new(1, 1, 1), EA.SHOT_LIFT)
    local orb = P({ Name = "AtkShell", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = CFrame.new(from),
        Color = DimTo(col, EA.SHOT_GLOW), Transparency = 0.05, Parent = ctx.Fx })
    orb.CanQuery = true
    orb:SetAttribute("ShellShot", true)
    CollectionService:AddTag(orb, NEAR_TAG)
    local dir = t and (t.Position - from) or Vector3.zAxis
    dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.zAxis
    local speed = EA.ShotSpeed(ctx, opts.Speed or 26)
    if IS_STUDIO and type(Workspace:GetAttribute("DevShotSlow")) == "number" then speed *= Workspace:GetAttribute("DevShotSlow") end
    local rec = { Shell = true, Seek = true, Part = orb, Ctx = ctx, Pos = from, Dir = dir, Speed = speed, Turn = math.rad(opts.Turn or 55),
        Arm = opts.Arm or 0.2, Life = opts.Life or 3.5, Born = os.clock(), R = size / 2, Mult = opts.Mult or 1, Target = t, Marks = {},
        Tag = opts.Tag or "Spike", Tol = TOL }
    shellOf[orb] = rec
    EA.ShotStats.Shells += 1
    Track(rec)
    if opts.Sound then Boom(orb, opts.Sound) end
    return orb
end
-- BEACON: a small standing shootable marker (one part + a faint floor ring of its reach); it holds for opts.Life s, until it is
-- shot (one hit) or its owner dies. Not counted against SHOT_CAP (it is not aimed at anyone). Returns the record (rec.Done = gone).
-- opts: Life, Size, Color, Reach (the ring), FloorY
function EA.Beacon(ctx: any, at: Vector3, opts: any): any
    local size = opts.Size or 1.2
    local col = opts.Color or ctx.ShotColor or EA.CORE
    local part = P({ Name = "AtkShell", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size * 1.6, size), CFrame = CFrame.new(at),
        Color = DimTo(col:Lerp(Color3.new(1, 1, 1), 0.25), EA.SHOT_GLOW), Transparency = 0.05, Parent = ctx.Fx })
    part.Shape = Enum.PartType.Block
    part.CanQuery = true
    part:SetAttribute("ShellShot", true)
    local marks = {}
    if opts.Reach then
        local y = opts.FloorY or EA.GroundY(ctx, at)
        local d = opts.Reach * 2
        table.insert(marks, P({ Name = "AtkBeaconRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, d, d),
            CFrame = CFrame.new(at.X, y + 0.06, at.Z) * DISC, Color = col, Material = Enum.Material.SmoothPlastic, Transparency = 0.82, Parent = ctx.Fx }))
    end
    local rec = { Shell = true, Static = true, Part = part, Ctx = ctx, Pos = at, Life = opts.Life or 10, Born = os.clock(), Marks = marks }
    shellOf[part] = rec
    Track(rec)
    return rec
end

-- ===== SWING: a melee swing told on the BODY -- a glow grows at its front, then one short arc; nothing on the floor =====
-- originFn() -> its body centre, faceFn() -> the flat way it faces. opts: Mult, Sound ("Melee"), Color, Glow (orb size)
function EA.Swing(ctx: any, originFn: () -> Vector3, faceFn: () -> Vector3, range: number, halfAngleDeg: number, windup: number, opts: any?)
    opts = opts or {}
    local raw = windup
    windup = WindupFor(ctx, windup, opts.Mult)
    -- (review E) the swing's direction is LOCKED when the wind-up starts (like the old floor cone): a sidestep during the glow dodges
    local f0 = faceFn()
    task.spawn(function()
        local stop = EA.Charge(ctx, function() return originFn() + f0 * 1.4 + Vector3.new(0, 0.4, 0) end, opts.Glow or 1.3, raw, opts.Color)
        local ok = Over(ctx, windup, function() end)
        stop()
        if not ok or EA.Staggered(ctx.Model) then return end
        local o, f = originFn(), f0
        f = Vector3.new(f.X, 0, f.Z)
        f = f.Magnitude > 0.01 and f.Unit or Vector3.new(0, 0, 1)
        -- the swing itself: one flat arc at chest height for a blink (no floor shape)
        local w = 2 * range * math.sin(math.rad(halfAngleDeg)) * 0.85
        local arc = P({ Name = "AtkSwing", Size = Vector3.new(w, 0.14, 0.7), CFrame = CFrame.lookAt(o + f * range * 0.7, o + f * (range + 1)),
            Color = opts.Color or ctx.Core or EA.CORE, Transparency = 0.35, Parent = ctx.Fx })
        Debris:AddItem(arc, 0.12)
        Boom(arc, opts.Sound or "Melee")
        local cosA = math.cos(math.rad(halfAngleDeg))
        for _, t in ipairs(Roots(ctx)) do
            local rel = t.Root.Position - o
            local flat = Vector3.new(rel.X, 0, rel.Z)
            if flat.Magnitude <= range + TOL and rel.Y <= 6 and rel.Y >= -5 and (flat.Magnitude < 0.75 or flat.Unit:Dot(f) >= cosA) then
                EA.HitTag = opts.Tag
                EA.StrikeHit(ctx, t.Player, opts.Mult or 1, opts.Plain)
                EA.HitTag = nil
            end
        end
    end)
    return windup -- (the scaled wind-up: the caller holds the bot still this long)
end

-- ===== AIM: a marksman's charged shot -- a glint grows on its body, flickers as it LOCKS, then one hard fast round =====
-- muzzleFn() -> where the shot leaves, target = the player's root. opts: Mult, Speed (SNIPE_SPEED), Size (0.9), Color, Glow (orb size),
-- LockTime (0.3: the aim freezes this long before the release -- move then), Cancelled() -> true stops it (a weak-spot hit),
-- OnCancel(), OnEnd(fired)
function EA.Aim(ctx: any, muzzleFn: () -> Vector3, target: BasePart, windup: number, opts: any?)
    opts = opts or {}
    local raw = windup
    windup = WindupFor(ctx, windup, opts.Mult)
    task.spawn(function()
        -- (POE DAMAGE MODEL) the lock -> release window (your reaction window) tightens with the tier: / ctx.TierSpeed
        local lockAt = math.max(0.2, windup - (opts.LockTime or 0.3) * CW(ctx) / ((ctx and ctx.TierSpeed) or 1))
        local stop, orb = EA.Charge(ctx, muzzleFn, opts.Glow or 1.2, raw, opts.Color or ctx.ShotColor)
        local aim = target.Position
        local t0 = os.clock()
        local warned = false
        local res = "fire"
        local glint = nil -- (the lock's GLINT: a thin streak across its muzzle, face-on to the player it aims at)
        while true do
            if not ctx.Alive() then res = "dead" break end
            if opts.Cancelled and opts.Cancelled() then res = "cancel" break end
            if EA.Staggered(ctx.Model) then res = "stagger" break end
            local el = os.clock() - t0
            if el >= windup then break end
            if el < lockAt then
                if target.Parent then aim = target.Position end
            else
                -- LOCKED: the aim stops following you, the orb goes to full and the glint streak grows across it -- move now
                -- (review J: it flickered at 9 Hz -- the owner's no-flashing rule: a steady brighten now)
                if orb and orb.Parent and orb.Transparency ~= 0.05 then orb.Transparency = 0.05 end
                local m = muzzleFn()
                local k = math.clamp((el - lockAt) / math.max(0.05, windup - lockAt), 0, 1)
                if not glint then
                    glint = P({ Name = "AtkGlint", Size = Vector3.new(0.2, 0.12, 0.05), Color = Color3.new(1, 1, 1):Lerp(opts.Color or ctx.ShotColor or EA.CORE, 0.3),
                        Transparency = 0.1, Parent = ctx.Fx })
                end
                local w = 0.4 + 3.6 * math.sin(k * math.pi * 0.5)
                glint.Size = Vector3.new(w, 0.12 + 0.1 * (1 - k), 0.05)
                if (aim - m).Magnitude > 0.1 then glint.CFrame = CFrame.lookAt(m, aim) * CFrame.new(0, 0, -0.3) end
                if not warned then
                    warned = true
                    pcall(function()
                        SoundHelper = SoundHelper or require(script.Parent:WaitForChild("SoundHelper"))
                        local m = ctx.Model and ctx.Model.PrimaryPart
                        if m then SoundHelper.PlayAt("AttackWarn", m) end
                    end)
                end
            end
            RunService.Heartbeat:Wait()
        end
        stop()
        if glint then glint:Destroy() end
        if res == "cancel" and opts.OnCancel then pcall(opts.OnCancel) end
        if res ~= "fire" then
            if opts.OnEnd then pcall(opts.OnEnd, false) end
            return
        end
        EA.Shot(ctx, muzzleFn(), aim + Vector3.new(0, 0.4, 0), { Speed = opts.Speed or EA.SNIPE_SPEED, Size = opts.Size or 0.9, Mult = opts.Mult,
            Color = opts.Color, Target = target, Plain = opts.Plain, Sound = opts.Sound or "ShootSniper", Tag = opts.Tag })
        if opts.OnEnd then pcall(opts.OnEnd, true) end
    end)
end
-- the charge's cancel window is open while ctx.Model's AimCharge attribute is set (BotRoles sets / clears it)

-- is it reeling right now? (attacks check it at their release: a stagger during a wind-up stops the attack -- review K)
function EA.Staggered(model: Instance?): boolean
    local u = model and model:GetAttribute("StaggerUntil")
    return type(u) == "number" and u > Workspace:GetServerTimeNow()
end

-- ===== STAGGER: it reels for `secs` (no moving, no attacking: CreateBot reads StaggerUntil) + a small ring over its head =====
function EA.Stagger(model: Instance, secs: number, fx: Instance?, color: Color3?)
    if not model or not model.Parent then return end
    local untilT = Workspace:GetServerTimeNow() + secs
    model:SetAttribute("StaggerUntil", math.max(untilT, model:GetAttribute("StaggerUntil") or 0))
    local head = model:FindFirstChild("Head")
    if not (head and head:IsA("BasePart")) then return end
    local d = math.max(1.6, head.Size.X * 1.9)
    local ring = P({ Name = "AtkStagger", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, d, d), Color = color or Color3.fromRGB(255, 240, 170),
        Transparency = 0.35, Parent = fx or model })
    task.spawn(function()
        local t0 = os.clock()
        while ring.Parent and head.Parent and os.clock() - t0 < secs do
            local k = (os.clock() - t0) / secs
            ring.CFrame = CFrame.new(head.Position + Vector3.new(0, head.Size.Y * 0.75, 0)) * CFrame.Angles(0, os.clock() * 6, math.rad(90) + 0.25)
            ring.Transparency = 0.35 + 0.6 * k * k
            RunService.Heartbeat:Wait()
        end
        ring:Destroy()
    end)
end

-- ======================================================================================================================
-- POE DAMAGE MODEL (2026-10-30, owner: "if you're moving, you just never take damage ... that deincentivizes the health and
-- resistance picks" -> "make it as close to POE as possible"; contract docs/ENEMY_ATTACKS_2026-10-30.md "POE DAMAGE MODEL ROUND").
-- Skill REDUCES damage, it never removes it, and every defence has a job:
--   CHIP   frequent small hits that are hard to avoid fully (led / spread rounds, a rusher's contact jab, a caster's degen aura,
--          an elite's death burst, pools) -> Plating (strong vs small hits), resistances (the elemental chip), Health
--   SPIKE  rare big telegraphed hits a good player dodges (a marksman's charged shot, shells, dives / swings / slams) -> whether a
--          missed one kills you is up to your Health / defences
-- Every role attack is tagged Chip / Spike in BotRoles.ROWS (Tag); EA.HitTag carries it to the Studio probe (DungeonGenerator).
-- Agility (evasion) works on ATTACKS only: rounds, shells, swings, dives, jabs go through StrikeHit (evadable); auras, pools and
-- death bursts set EA.AreaHit and never StrikeHit, so only Plating / resistances / Health stop them.
-- ======================================================================================================================
EA.HitTag = nil -- "Chip" | "Spike" while a role hit lands (probe only; no gameplay reads it)
-- TIER SCALING (role attacks only: CreateBot sets ctx.TierSpeed + the bot's lead / spread; bosses / old attacks never read these).
-- rank = ItemData.DifficultyRank (Easy 1 .. Cataclysm 7 .. Annihilation 12 .. Singularity 14; future tiers keep climbing to the caps).
-- Owner rule: Torment / Cataclysm movement is the reference -- low tiers stay methodical (slower rounds, few led shots), higher
-- tiers are only FASTER (rounds, shells, the marksman's lock window) and read your movement more; wind-ups stay flat (BOT_PACE).
EA.TIER_SPEED = { 0.9, 0.92, 0.95, 0.97, 1, 1, 1 } -- Easy .. Cataclysm; past it + TIER_SPEED_STEP a rank (Annihilation x1.30)
EA.TIER_SPEED_STEP, EA.TIER_SPEED_MAX = 0.06, 1.6
EA.LEAD_BASE, EA.LEAD_STEP, EA.LEAD_MAX = 0.1, 0.06, 0.85 -- share of chip bursts aimed where you'll BE (Easy 0.16, Torment 0.46, T12 0.82)
EA.SPREAD_BASE, EA.SPREAD_STEP, EA.SPREAD_MAX = 0.2, 0.08, 2 -- a round's extra cone, degrees (Torment 0.7, T12 1.2), centre-weighted
EA.LEAD_MAX_STUDS = 14 -- a led round never aims further ahead than this
-- CHIP rounds (a gunner's burst) are TRACERS: CHIP_SPEED (x MOVE_SPEED x the tier) = ~0.16 s over 30 studs at Torment -- faster
-- than any reaction sidestep (measured: at 85 / 127 studs/s a 0.25 s-reaction bot still sidestepped 40-80% of them). Its TELL is the
-- glow at the gunner's muzzle during the wind-up; the answer is cover, range, killing it, and your defences -- not watching each
-- round. Spikes keep their slower / locked, readable flights (SHOT_SPEED / SNIPE_SPEED, shells) and are what you dodge.
EA.CHIP_SPEED = 220
-- a chip burst is a FAN across the line of fire: round 1 on the aim point, the next at +-FAN_W studs (2 x a round's reach on your
-- body is 2.14, so the fan is one unbroken band ~6 studs wide: wherever you are inside it, ONE round lands -- standing in the
-- middle, strafing through it, or stepping to its edge). Each round that lands deals CHIP_HIT x the bot's old attack.
EA.FAN_W, EA.CHIP_HIT = 2.0, 0.32
-- a LONE round (pack fodder, a Splitling, the Warden's fallback) has no fan: it lands on movers as often as on a planted player.
-- Measured with packs on (review 2): at 0.32 a moving player took 1.6x (Torment) / 2.3x (T12) the old attacks -> CHIP_HIT_LONE.
EA.CHIP_HIT_LONE = 0.16
function EA.TierScale(rank: number?): any
    local r = math.max(1, math.floor(tonumber(rank) or 1))
    local sp = EA.TIER_SPEED[r] or math.min(EA.TIER_SPEED_MAX, EA.TIER_SPEED[#EA.TIER_SPEED] + EA.TIER_SPEED_STEP * (r - #EA.TIER_SPEED))
    return { Rank = r, Speed = sp, Lead = math.min(EA.LEAD_MAX, EA.LEAD_BASE + EA.LEAD_STEP * r),
        Spread = math.min(EA.SPREAD_MAX, EA.SPREAD_BASE + EA.SPREAD_STEP * r) }
end
-- where to aim a round of `speed` studs/s from `from` so it meets a target that KEEPS its current (flat) velocity
function EA.LeadPoint(target: BasePart, from: Vector3, speed: number): Vector3
    local p = target.Position
    local v = target.AssemblyLinearVelocity
    v = Vector3.new(v.X, 0, v.Z)
    if v.Magnitude < 2 or speed <= 1 then return p end
    local t = (p - from).Magnitude / speed
    for _ = 1, 2 do t = ((p + v * t) - from).Magnitude / speed end
    local lead = v * t
    if lead.Magnitude > EA.LEAD_MAX_STUDS then lead = lead.Unit * EA.LEAD_MAX_STUDS end
    return p + lead
end
-- `aim` turned by a centre-weighted random angle inside a cone of `deg` (yaw; a third of it in pitch)
function EA.SpreadAim(from: Vector3, aim: Vector3, deg: number): Vector3
    local d = aim - from
    if deg <= 0 or d.Magnitude < 0.1 then return aim end
    local a = math.rad(deg) * (math.random() + math.random() - 1)
    local e = math.rad(deg) * 0.33 * (math.random() + math.random() - 1)
    return from + (CFrame.lookAt(from, aim) * CFrame.Angles(e, a, 0)).LookVector * d.Magnitude
end
-- the attacker's short wind-up POSE without WindupFor's minimum (a jab's tell is shorter than ANY_MIN on purpose: it is chip)
local function Pose(ctx: any, w: number)
    local m = ctx.Model
    if m and m.Parent then
        local now = Workspace:GetServerTimeNow()
        if (m:GetAttribute("AtkEnd") or 0) < now then m:SetAttribute("AtkStart", now) end
        if now + w > (m:GetAttribute("AtkEnd") or 0) then m:SetAttribute("AtkEnd", now + w) end
    end
end

-- ===== JAB: a rusher's short CONTACT hit once it is on you -- a small glow on its front for EA.JAB_TELL s (flat on every tier), then
-- anyone still within `reach` (flat, from its body centre) is hit once. An attack: Agility can dodge it. CHIP: small and fast --
-- backing off in time avoids it, but a rusher in your face lands most of them. opts: Mult (0.3), Tell, Glow, Color, Sound
EA.JAB_TELL = 0.4
function EA.Jab(ctx: any, originFn: () -> Vector3, faceFn: () -> Vector3, reach: number, opts: any?): number
    opts = opts or {}
    local tell = opts.Tell or EA.JAB_TELL
    local f0 = faceFn()
    f0 = Vector3.new(f0.X, 0, f0.Z)
    f0 = f0.Magnitude > 0.01 and f0.Unit or Vector3.zAxis
    Pose(ctx, tell)
    task.spawn(function()
        local stop = EA.Charge(ctx, function() return originFn() + f0 * (opts.Front or 1.2) + Vector3.new(0, 0.3, 0) end, opts.Glow or 0.8, tell / CW(ctx), opts.Color)
        local ok = Over(ctx, tell, function() end)
        stop()
        if not ok or EA.Staggered(ctx.Model) then return end
        local o = originFn()
        local landed = false
        for _, t in ipairs(Roots(ctx)) do
            local rel = t.Root.Position - o
            if Vector3.new(rel.X, 0, rel.Z).Magnitude <= reach + TOL and rel.Y <= 6 and rel.Y >= -5 then
                EA.HitTag = "Chip"
                EA.AilScale = opts.Mult or 0.3 -- (review 2: a jab every 1.2 s rolled the ailment at the full chance -> x its chip share)
                EA.StrikeHit(ctx, t.Player, opts.Mult or 0.3, nil)
                EA.HitTag, EA.AilScale = nil, nil
                landed = true
            end
        end
        if landed then
            pcall(function()
                SoundHelper = SoundHelper or require(script.Parent:WaitForChild("SoundHelper"))
                local m = ctx.Model and ctx.Model.PrimaryPart
                if m then SoundHelper.PlayAt(opts.Sound or "Melee", m) end
            end)
        end
    end)
    return tell
end

-- ===== AURA: degen ground that FOLLOWS a body (a caster): ONE flat disc in the biome's floor material on the ground under it, steady
-- (no pulse, no flashing, no red rim: the first screenshot with the attacks' solid red rim read as a permanent alarm), ticking every
-- opts.Tick s on anyone standing in it. NOT an attack: Agility never dodges it (AreaHit, no StrikeHit);
-- Plating / resistances / Health do. Shown + ticking only while opts.Active() is true (the caster is fighting); its parts are made
-- once and parked (hidden, far below) while idle. opts: Mult per tick (0.1), Tick (0.5), Height (6), Color, Active,
-- Hit = fn(player, mult) (else ctx.Hit). Returns stop() (it also stops when ctx.Alive() goes false or its floor is torn down).
function EA.Aura(ctx: any, posFn: () -> Vector3, radius: number, opts: any?): () -> ()
    opts = opts or {}
    local running = true
    local discT = 0.5
    local disc = nil
    local function Make()
        disc = P({ Name = "AtkAura", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, radius * 2, radius * 2),
            Color = opts.Color or ctx.Color or EA.WARN, Material = ctx.Mat or Enum.Material.Neon, Transparency = discT, Parent = ctx.Fx })
        if disc.Material == Enum.Material.Neon then disc.Transparency = 0.7 end -- (a plain neon disc glows harder than a floor material)
        discT = disc.Transparency
    end
    local PARK = CFrame.new(0, -500, 0)
    -- (review 2) opts.Alive (the owner exists and isn't Dead) -- NOT ctx.Alive, which is also false while a kill is only PREDICTED
    -- (the bot can come back: Unhide); opts.Active hides the disc meanwhile
    local alive = opts.Alive or ctx.Alive
    task.spawn(function()
        local tick = opts.Tick or 0.5
        local hTop = opts.Height or 6
        local lastTick, groundAt, y, shown = os.clock(), -99, nil, false
        local lastC, wroteAt = nil, -1
        while running and alive() do
            local now = os.clock()
            if not ((opts.Active == nil) or opts.Active()) then
                if shown and disc then
                    disc.Transparency = 1
                    disc.CFrame = PARK
                    shown = false
                end
                task.wait(0.2)
                continue
            end
            if not disc then Make() end
            if not disc.Parent then break end -- (its floor was torn down)
            local c = posFn()
            if now - groundAt > 0.1 or not y then y = EA.GroundY(ctx, c); groundAt = now end
            -- (review 2, perf: the server replicates every write) only when it moved > 0.05 studs, at most 20 times a second
            if not shown or not lastC or ((c - lastC).Magnitude > 0.05 and now - wroteAt >= 0.05) then
                disc.CFrame = CFrame.new(c.X, y + 0.06, c.Z) * DISC
                lastC, wroteAt = c, now
            end
            if not shown then disc.Transparency = discT; shown = true; lastTick = now end
            if now - lastTick >= tick then
                lastTick = now
                for _, t in ipairs(Roots(ctx)) do
                    local rp = t.Root.Position
                    if Vector3.new(rp.X - c.X, 0, rp.Z - c.Z).Magnitude <= radius + math.min(0, TOL) and rp.Y - y <= hTop and rp.Y - y >= -3 then
                        EA.AreaHit = true
                        EA.HitTag = "Chip"
                        EA.BurstFollow = true -- (review 2: an aura tick never heals a Vampiric caster / rolls an ailment)
                        local ok, err = pcall(opts.Hit or ctx.Hit, t.Player, opts.Mult or 0.1)
                        EA.AreaHit = false
                        EA.HitTag = nil
                        EA.BurstFollow = nil
                        if not ok then warn("[EnemyAttacks] " .. tostring(err)) end
                    end
                end
            end
            RunService.Heartbeat:Wait()
        end
        running = false
        if disc then disc:Destroy() end
    end)
    return function() running = false end
end

-- ===== NOVA: an elite's short ON-DEATH burst -- a flat disc + rim where it fell for `tell` s (no fill, no flashing: it just sits
-- there), then everyone inside (a column up to opts.Height) is hit ONCE and the disc fades. NOT an attack: Agility never dodges it.
-- opts: Mult (0.5), Height (8), Color, Hit = fn(player, mult) (else ctx.Hit), Sound. The ctx needs no Alive (its owner is dead).
EA.NOVA_WINDOW, EA.NOVA_CAP = 0.5, 1.0
local novaWin = setmetatable({}, { __mode = "k" }) -- player -> { T, Used } (the burst window above)
function EA.Nova(ctx: any, center: Vector3, radius: number, tell: number, opts: any?)
    opts = opts or {}
    task.spawn(function()
        local y = EA.GroundY(ctx, center)
        local cf = CFrame.new(center.X, y + 0.08, center.Z) * DISC
        local disc = P({ Name = "AtkNova", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, radius * 2, radius * 2), CFrame = cf,
            Color = opts.Color or ctx.Color or EA.WARN, Material = ctx.Mat or Enum.Material.Neon, Transparency = ctx.MatT or 0.5, Parent = ctx.Fx })
        local rim = P({ Name = "AtkRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, radius * 2 + RIM_PAD, radius * 2 + RIM_PAD), CFrame = cf * CFrame.new(-0.02, 0, 0),
            Color = EA.OUTLINE, Material = Enum.Material.SmoothPlastic, Transparency = 0.3, Parent = ctx.Fx })
        if IS_STUDIO and type(Workspace:GetAttribute("DevShotSlow")) == "number" then tell /= math.max(0.05, Workspace:GetAttribute("DevShotSlow")) end -- (screenshots)
        Debris:AddItem(disc, tell + 1)
        Debris:AddItem(rim, tell + 1)
        local t0 = os.clock()
        local function Gone(): boolean -- (review 2: on solo floors ctx.Fx is Workspace -- the floor's Geo tells a teardown)
            return not disc.Parent or (ctx.Geo ~= nil and not ctx.Geo.Parent)
        end
        while os.clock() - t0 < tell do
            if Gone() then disc:Destroy(); rim:Destroy() return end -- (its floor was torn down)
            RunService.Heartbeat:Wait()
        end
        local hTop = opts.Height or 8
        local mult = opts.Mult or 0.5
        for _, t in ipairs(Roots(ctx)) do
            local rp = t.Root.Position
            if Vector3.new(rp.X - center.X, 0, rp.Z - center.Z).Magnitude <= radius + math.min(0, TOL) and rp.Y - y <= hTop and rp.Y - y >= -3 then
                -- (review 2) bursts landing on one player within NOVA_WINDOW share NOVA_CAP x an attack; only the first rolls the
                -- ailment / Vampiric (four elites dying together used to stack 4 x 0.5 = 2 x an attack in half a second)
                local w = novaWin[t.Player]
                local now = os.clock()
                if not w or now - w.T > EA.NOVA_WINDOW then w = { T = now, Used = 0 }; novaWin[t.Player] = w end
                local m = math.min(mult, EA.NOVA_CAP - w.Used)
                if m > 0.001 then
                    EA.AreaHit = true
                    EA.HitTag = "Chip"
                    EA.BurstFollow = w.Used > 0
                    w.Used += m
                    local ok, err = pcall(opts.Hit or ctx.Hit, t.Player, m)
                    EA.AreaHit = false
                    EA.HitTag = nil
                    EA.BurstFollow = nil
                    if not ok then warn("[EnemyAttacks] " .. tostring(err)) end
                end
            end
        end
        Boom(disc, opts.Sound or "AreaStrike")
        rim:Destroy()
        local tr0 = disc.Transparency
        local f0 = os.clock()
        while disc.Parent and os.clock() - f0 < 0.25 do -- (a fade out, not a flash)
            disc.Transparency = tr0 + (1 - tr0) * (os.clock() - f0) / 0.25
            RunService.Heartbeat:Wait()
        end
        if disc.Parent then disc:Destroy() end
    end)
end

return EA
