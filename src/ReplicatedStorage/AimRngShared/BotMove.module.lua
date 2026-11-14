--!nocheck
-- BOT MOVEMENT: POE STYLE (2026-10-30; owner, T12 maps with an L200 kit: "The bots were moving so fast that they arent even fun
-- to shoot ... the only way to shoot those super fast t12 bots is to hold your crosshair in the middle of the pack and they strafe
-- into it ... all the bots strafe the same direction at the same time, just forming a massive wall. I think it would be better to
-- do what POE does"; contract + measurements docs/BOT_MOVEMENT_2026-10-30.md).
--
-- WHAT IT DOES. A bot with a ROLE row (AimRngShared/BotRoles) no longer runs a strafe pattern: it gets a MOVEMENT BRAIN for its
-- role, each bot on its own clock (its own random timers, side and depth -- nothing shares a clock, so a pack never moves as one):
--   Rusher    closes in, STOPS at its reach (a swing: arm's length; a dive: its stand-off), attacks, a short re-engage hop
--   Gunner    holds a (wide) distance band and GLIDES from spot to spot: long smooth moves (16-28 studs), most of them CHAINED into
--             the next without a stop (Chain), short holds between the rest; it keeps walking into a wind-up and plants only for
--             its last PlantLead s + the volley
--   Marksman  holds a far band, plants for its whole charge, steps off to a new spot after it fires
--   Heavy     drifts / plods in, chained short steps, plants for the end of its wind-up to lob / slam
--   Caster    stays behind the nearest ally (away from you); none left = hangs back at the far edge of its band
-- Moves are smooth (acceleration-limited; a step that isn't chained slows down into its spot), a big change of direction brakes
-- first. SPACING: a new spot is scored by floor crowding (bots and their spots inside SEP + 3) AND by SCREEN crowding (other bots
-- within ANG_SEP deg of it as you see them) and kept inside the FAN (FAN_DEG either side of the room's bots' middle bearing from
-- you): a pack fans out into separate targets in front of you and over its band's depth; a soft push below SEP on top. Fliers use
-- the same brains at their own height (+-4 a step). A marksman / caster never starts an attack while walking (Busy); a gunner /
-- heavy starts its wind-up on the move and its step pauses for the shot, then carries on.
-- STUCK (owner: "bots shouldnt be stuck for more than about a second"): every STALL_EVERY s a walking bot that came < ~1 stud closer
-- to its spot over STALL_WIN s detours at once to a spot its BODY can reach in a straight line (DungeonGenerator.PathClear); spot
-- picks mark down spots behind cover (no line on you / no straight path); a holder without a line on you re-picks after
-- BLIND_REPICK s. Measured worst case 0.6-0.7 s (docs, ROUND 2).
-- Bots WITHOUT a row keep their old pattern (other biomes convert later through the same rows); KEEP_PATTERN bots (the
-- Blinker's blinks, the Magmaw's burrow) keep theirs too -- those ARE their repositioning.
-- ROUND 2 (2026-11-01; owner after a T12 Abyss map: "The bots barely move now ... giant silly cluster ... stuck behind objects"):
-- the step-then-hold brains moved ~half the time at ~3 deg/s; now ~88% of the time at ~15 deg/s (the old Torment reference: 91%,
-- 17.6), still under the cap. Numbers + calls: docs/BOT_MOVEMENT_2026-10-30.md "ROUND 2". Offline sim: tools/sim/botmove_sim.py.
--
-- SPEED = a trait of the bot: ROLE speeds (slow-to-moderate) x FAST archetypes (a few fast, fragile ones: they die in a few hits
-- and are the priority targets) x the bot-skill step (BotSkillLevels Speed / the Standard step) x FRENZIED / RELENTLESS (the
-- speed mods) x the tier speed, which STOPS at SPEED_TIER_CAP (Torment: the owner's reference pace; tiers above add toughness,
-- not speed). On top of every bot (role or not): the READABILITY CAP -- a bot's own motion across your screen is held under
-- CAP_DEG degrees a second (DungeonGenerator CreateBot clamps the part of its velocity across the line to you to
-- CAP_DEG x max(distance, CAP_DMIN)). Dives (a rusher's attack) and told blinks / teleports are not motion it can be capped on.
--
-- A / B (Studio): workspace attr DevMoveOld = true -> every bot moves the old way (patterns, tier speed, no cap) and maps roll
-- their old 6-10 bot skill (Rifts). Read when a bot is made: set it BEFORE the floor.
-- ADD A BOT: give it a BotRoles row (docs/EXTENDING.md "Give a bot ROLE MOVEMENT"); optional FAST / STYLE / KEEP_PATTERN rows here.
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local BotRoles = require(script.Parent:WaitForChild("BotRoles"))

local BotMove = {}
BotMove.DG = nil -- (DungeonGenerator sets itself here: IsSpotBlocked / OpenAt / LinkSees / BodyInTerrain)

-- per-role movement (studs/s at the Standard bot skill on Easy; Accel studs/s^2; Hold = seconds planted between steps;
-- Step = studs a step; Band = { near, far } studs from you (nil = the archetype's own Range); Far = the far share of the band
-- it prefers (0 near .. 1 far, each bot draws its own around it))
-- (ROUND 2) Chain = the share of its steps that run on into the next one (no stop; CHAIN_KEEP of its speed at the spot); Band =
-- x its archetype's Range { near, far } (a wider band = the pack spreads in depth)
-- PlantLead = (ROUND 2) it keeps walking through the start of a wind-up and plants only for the last PlantLead s of it (+ the
-- volley); nil = it plants for the whole wind-up (marksmen: the charge you cancel with a head hit; casters)
BotMove.ROLE = {
    Rusher = { Speed = 13, Accel = 24, Hop = { 3.5, 6.5 }, HopChance = 0.65 },
    Gunner = { Speed = 16, Accel = 26, Hold = { 0.3, 0.8 }, Step = { 16, 28 }, Far = 0.5, AfterFire = 0.55, PlantLead = 0.35, Chain = 0.85, Band = { 0.85, 1.3 } },
    Marksman = { Speed = 11, Accel = 16, Hold = { 1.2, 2.4 }, Step = { 12, 20 }, Far = 0.8, AfterFire = 0.85, MinNear = 30 },
    Heavy = { Speed = 8, Accel = 11, Hold = { 0.4, 1.0 }, Step = { 10, 16 }, Far = 0.25, AfterFire = 0.25, PlantLead = 0.5, Chain = 0.6 },
    Caster = { Speed = 7.5, Accel = 11, Repick = { 1.4, 2.4 }, Behind = { 8, 13 } },
}
-- FAST, FRAGILE archetypes: Speed x, Accel x, Hold x (they step more often), Hp x (health -- every place that builds the bot)
BotMove.FAST = {
    Skirmisher = { Speed = 1.35, Accel = 1.35, Hold = 0.45, Hp = 0.7 }, -- (ROUND 2: x1.75-1.9 -> 1.35-1.45 on the faster gunner base: same top speed as before)
    Zipper = { Speed = 1.4, Accel = 1.4, Hold = 0.4, Hp = 0.7 },
    Comet = { Speed = 1.45, Accel = 1.35, Hold = 0.5, Hp = 0.7 },
    Splitling = { Speed = 1.3, Accel = 1.3, Hold = 0.5, Hp = 1 }, -- (already 40 health: the split-off of a Splitter)
}
-- how a step LOOKS (the archetype's flavour on the same brain): Hop = a low arc in the air (H studs) along the step
BotMove.STYLE = {
    Hopper = { Hop = 3.5 }, Leaper = { Hop = 5 }, Popper = { Hop = 4.5 },
    -- Low = it keeps low on the floor (its middle at the walkers' floor height + 0.6, never under 5): the roller rolls, it doesn't fly
    Slagroller = { Low = true },
}
-- patterns that ARE the bot's repositioning (kept: the brain is not used for them)
BotMove.KEEP_PATTERN = { Blink = true, Burrow = true }
-- tier speed (DungeonGenerator.HardSpeed) stops at this hard tier: 2 = Torment, the owner's reference ("Torment / Cataclysm
-- movement is the reference"). Measured (docs): T12 bots moved 1.9-2.7x Torment's angular speed with the old +6% a tier.
BotMove.SPEED_TIER_CAP = 2
-- the readability cap: the bot's own motion across your screen <= CAP_DEG deg/s, judged at max(its distance, CAP_DMIN)
BotMove.CAP_DEG = 48
BotMove.CAP_DMIN = 14
BotMove.STD_SPEED = 0.59 -- (BotSkillLevels[4].Speed: the role speeds above are at this step)
BotMove.STD_FREQ = 0.69 -- (BotSkillLevels[4].Freq: holds / re-picks shorten by Freq / this on the higher steps, like the old patterns' clocks)
BotMove.PUSH_HZ = 10 -- (the soft push between bots is recomputed this often a second, not every frame)
BotMove.SEP = 10 -- studs: bots closer than this push apart softly and re-pick their spot (ROUND 2: 8 -> 10)
BotMove.BRAKE = 3 -- x Accel while planting
-- (ROUND 2, owner: packs "look like this giant silly cluster") SCREEN SPACING: a new spot is scored by how close it sits ON YOUR
-- SCREEN to the other bots and their spots (the angle between them as you see them), not only by studs on the floor -- a pack fans
-- out into separate targets across FAN_DEG either side of its middle (never all round you) and over its whole distance band
BotMove.ANG_SEP = 14 -- deg: two bots closer than this on your screen count as crowding
BotMove.CROWD_W = 1.5 -- score points a stud of floor crowding (other bots / their spots inside SEP + 3)
BotMove.SCREEN_W = 30 -- score points for a full on-screen overlap with another bot (a stud off its preferred depth = 0.4)
BotMove.FAN_DEG = 80 -- deg: either side of the room's bots' middle bearing (from you) before a spot is marked down
BotMove.FAN_W = 1.5 -- score points a degree past the fan
-- (ROUND 2, owner: "bots shouldnt be stuck for more than about a second") STALL WATCH: every STALL_EVERY s while it walks, a bot
-- that came less than ~1 stud closer to its spot over the last STALL_WIN s detours at once (a spot it can REACH with its body)
BotMove.STALL_EVERY, BotMove.STALL_WIN = 0.25, 0.5
BotMove.CHAIN_KEEP = 0.75 -- (ROUND 2) share of its top speed a chained step still has at its spot
BotMove.BLIND_REPICK = 0.35 -- s without a line on you while it holds -> a new spot (scored for sight)
BotMove.DEBUG = RunService:IsStudio() -- (Studio: model attrs MoveGoal (each step's goal) + MoveDetours)

function BotMove.Old(): boolean
    return RunService:IsStudio() and Workspace:GetAttribute("DevMoveOld") == true
end
-- does this archetype (with this role row) get a brain? (CreateBot also requires: a target-fighting bot, not a range bay /
-- boss floor -- the same rules as its role row)
function BotMove.Wants(archetype: string?, A: any, row: any): boolean
    if not row or BotMove.Old() then return false end
    if A and (BotMove.KEEP_PATTERN[A.Pattern or ""] or (A.Speed or 0) <= 0) then return false end
    return BotMove.ROLE[row.Role] ~= nil
end
-- health x for a fast, fragile archetype (1 otherwise; only where it moves with a brain)
function BotMove.HpMult(archetype: string?, A: any, row: any): number
    local f = archetype and BotMove.FAST[archetype]
    if not f or not BotMove.Wants(archetype, A, row) then return 1 end
    return f.Hp or 1
end
-- the hard tier the SPEED reads (HardSpeed / the pattern tempo): capped, unless DevMoveOld
function BotMove.SpeedTier(hardTier: number): number
    if BotMove.Old() then return hardTier end
    return math.min(hardTier, BotMove.SPEED_TIER_CAP)
end
-- the readability cap on a velocity seen from `eye` (nil = no cap: DevMoveOld)
function BotMove.Cap(vel: Vector3, pos: Vector3, eye: Vector3): Vector3
    local rel = pos - eye
    local d = rel.Magnitude
    if d < 0.5 then return vel end
    local u = rel / d
    local vr = u * vel:Dot(u)
    local vt = vel - vr
    local lim = math.rad(BotMove.CAP_DEG) * math.max(d, BotMove.CAP_DMIN)
    local m = vt.Magnitude
    if m <= lim then return vel end
    return vr + vt * (lim / m)
end

local function Flat(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end
local function R(rng: Random, t: { number }): number return rng:NextNumber(t[1], t[2]) end

-- a new brain. o = { Rng, Row (the archetype's REAL row -- a fodder Drifter still moves like a heavy), A (archetype def), Arch (id),
-- Radius, Ground, GroundY, Height (fliers' own height), Speed (the bot's speed factor: skill x mods x tier, 1 = Standard on Easy),
-- Freq (the bot-skill step's Freq, mods included), Melee, Clamp(fn), Geo, Group ({ [model] = pos }), Model, Client }
function BotMove.New(o: any): any
    local rng = o.Rng
    local role = o.Row.Role
    local P = BotMove.ROLE[role]
    local fast = BotMove.FAST[o.Arch or ""]
    local spd = P.Speed * (o.Speed or 1) * (fast and fast.Speed or 1)
    -- (REVIEW ROUND) the bot-skill step's tempo: higher steps hold shorter and re-pick sooner (the old patterns ran their clocks at Freq)
    local freq = math.max(0.5, (o.Freq or BotMove.STD_FREQ) / BotMove.STD_FREQ)
    local A = o.A
    local lo, hi = A.Range[1], A.Range[2]
    if role == "Marksman" then lo = math.max(lo, P.MinNear or lo); hi = math.max(hi, lo + 10) end
    if P.Band then lo, hi = lo * P.Band[1], hi * P.Band[2] end -- (ROUND 2: a wider band = the pack spreads in DEPTH, not one arc)
    local mv = {
        Role = role, P = P, Fast = fast, Style = BotMove.STYLE[o.Arch or ""], Rng = rng,
        Top = spd, Acc = P.Accel * math.max(0.6, o.Speed or 1) * (fast and fast.Accel or 1), -- (REVIEW ROUND: accel follows speed 1:1, the step's shape stays)
        HoldMul = (fast and fast.Hold or 1) / freq, Freq = freq,
        Lo = lo, Hi = hi, Depth = math.clamp((P.Far or 0.5) + rng:NextNumber(-0.45, 0.45), 0, 1), -- (ROUND 2: +-0.25 -> 0.45: the pack fills its band)
        Side = (rng:NextNumber() < 0.5) and -1 or 1, -- its own preferred way round you
        Off = rng:NextNumber(-0.45, 0.45), -- (rushers: its own angle of approach, so a pack doesn't arrive on one line)
        Radius = o.Radius, Ground = o.Ground, GroundY = o.GroundY, H = o.Height or 10, Melee = o.Melee,
        Clamp = o.Clamp, Geo = o.Geo, Group = o.Group, Model = o.Model, Client = o.Client,
        Row = o.Row,
        Pos = nil, Vel = Vector3.zero, State = "Hold", Goal = nil, HoldAt = nil,
        NextPick = os.clock() + rng:NextNumber(0.3, 1.6), -- (a fresh pack does NOT step off together)
        Ph = rng:NextNumber(0, 6.28), Ph2 = rng:NextNumber(0, 6.28), Wf = rng:NextNumber(0.7, 1.2),
        Last = 0, Moving = false, Planted = false,
    }
    -- reach for rushers / melee heavies (studs from you to its middle)
    local row = o.Row
    if role == "Rusher" then
        if row.Attack == "Swing" then mv.Reach = o.Radius + 2.2
        elseif o.Melee then mv.Reach = rng:NextNumber(15, 20) -- (a melee diver: the Charger's stand-off, inside its 7-30 dive range)
        else mv.Reach = rng:NextNumber(11, 16) end -- (a roller: inside its 5-32 roll range)
    elseif role == "Heavy" and o.Melee then
        mv.Reach = o.Radius + 2.4 -- (a slammer: inside its slam reach)
    end
    return mv
end

-- is a spot fine to stand on? (open, not in rock on the client)
local function Open(mv: any, p: Vector3): boolean
    local DG = BotMove.DG
    if not DG then return true end
    if mv.Client then return DG.OpenAt(p, mv.Radius + 0.4, mv.Geo) end
    return not DG.IsSpotBlocked(p, mv.Radius + 0.4, mv.Geo)
end
-- how crowded a spot is: the other bots of the room (where they ARE and where they're going)
local goals = setmetatable({}, { __mode = "k" }) -- [model] = the spot it is walking to / holding
BotMove._goals = goals
local function Crowd(mv: any, p: Vector3): number
    local c = 0
    local lim = BotMove.SEP + 3
    for other, op in pairs(mv.Group) do
        if other ~= mv.Model and other.Parent then
            local m = (Flat(op - p)).Magnitude
            if m < lim then c += (lim - m) end
            local g = goals[other]
            if g then
                local mg = (Flat(g - p)).Magnitude
                if mg < lim then c += (lim - mg) * 0.8 end
            end
        end
    end
    return c
end
local function SpotY(mv: any, tp: Vector3): number
    if mv.Ground then return mv.GroundY end
    if mv.Style and mv.Style.Low then return math.max(5, mv.GroundY + 0.6) end -- (REVIEW ROUND: the roller rolls on the floor, as its old Roll did)
    if mv.Role == "Rusher" then return math.max(5, tp.Y + 3) end -- (a flying rusher dives at your chest height)
    if mv.Melee then return math.max(4, tp.Y + 0.5) end -- (REVIEW ROUND: a flying melee heavy -- Juggernaut -- comes down to you, as its old chase did)
    return mv.H
end

-- (ROUND 2) SCREEN crowding of a spot: the other bots (and the spots they are heading to) that would sit within ANG_SEP deg of it
-- as you see them (eye = your head); + how far the spot's bearing is outside the room's fan (FAN_DEG either side of the middle
-- bearing of its bots: they spread out IN FRONT of you, not all round you)
local function ScreenCrowd(mv: any, p: Vector3, eye: Vector3): (number, number)
    local rel = p - eye
    local dm = rel.Magnitude
    if dm < 1 then return 0, 0 end
    local u = rel / dm
    local lim = math.cos(math.rad(BotMove.ANG_SEP))
    local c = 0
    local sx, sz, n = 0, 0, 0
    for other, op in pairs(mv.Group) do
        if other ~= mv.Model and other.Parent then
            local e = op - eye
            local em = e.Magnitude
            if em > 1 then
                local dot = u:Dot(e / em)
                if dot > lim then c += (BotMove.ANG_SEP - math.deg(math.acos(math.min(1, dot)))) / BotMove.ANG_SEP * 0.6 end
                if em < 90 then sx += e.X / em; sz += e.Z / em; n += 1 end
            end
            local g = goals[other]
            if g then
                local f = g - eye
                local fm = f.Magnitude
                if fm > 1 then
                    local dot = u:Dot(f / fm)
                    if dot > lim then c += (BotMove.ANG_SEP - math.deg(math.acos(math.min(1, dot)))) / BotMove.ANG_SEP end
                end
            end
        end
    end
    local fan = 0
    if n >= 3 and (sx * sx + sz * sz) > 0.01 then -- (the middle of where the room's bots stand, seen from you: the fan's centre)
        local mid = math.atan2(sz, sx)
        local off = math.abs(math.deg(math.atan2(math.sin(math.atan2(u.Z, u.X) - mid), math.cos(math.atan2(u.Z, u.X) - mid))))
        if off > BotMove.FAN_DEG then fan = (off - BotMove.FAN_DEG) * BotMove.FAN_W end
    end
    return c, fan
end
-- can its BODY walk from a to b in a straight line? (DungeonGenerator.PathClear: a body-wide cast + terrain; no DG = open room)
local function Reach(mv: any, a: Vector3, b: Vector3): boolean
    local DG = BotMove.DG
    if not (DG and DG.PathClear) then return true end
    return DG.PathClear(a, b, mv.Radius or 2, mv.Geo)
end
-- pick a new spot at distance band [lo, hi] round the player, stepping `side`-ways from where it is now. (ROUND 2) 6 candidates:
-- its own way round you, the other way, a short one each way, a long one each way (a crowded bot fans out faster); each at its own
-- depth in the band (+-6 round its preferred one) and, for fliers, its own height (+-4); scored by distance from its preferred depth,
-- floor crowding, SCREEN crowding + the fan, a line on you, and whether its body can walk there straight
local CAND_STEP = { 1, 1, 0.6, 0.6, 1.5, 1.5 }
local function PickBand(mv: any, tp: Vector3, cur: Vector3, lo: number, hi: number): Vector3?
    local rng, P = mv.Rng, mv.P
    local rel = Flat(cur - tp)
    local d = rel.Magnitude
    local ang = (d > 0.5) and math.atan2(rel.Z, rel.X) or rng:NextNumber(0, 6.28)
    local pref = lo + (hi - lo) * mv.Depth
    if rng:NextNumber() < 0.3 then mv.Side = -mv.Side end -- (now and then it switches the way it works round you)
    local best, bestScore = nil, math.huge
    local DG = BotMove.DG
    local eye = tp + Vector3.new(0, 1.5, 0)
    for i = 1, #CAND_STEP do
        local side = (i % 2 == 1) and mv.Side or -mv.Side
        local step = R(rng, P.Step or { 6, 12 }) * CAND_STEP[i]
        local dist = math.clamp(pref + rng:NextNumber(-6, 6), lo, hi)
        -- the bearing change that makes about `step` studs of movement along the arc at that distance
        local da = side * math.clamp(step / math.max(8, dist), 0.12, 1.1)
        local a = ang + da
        local cand = Vector3.new(tp.X + math.cos(a) * dist, 0, tp.Z + math.sin(a) * dist)
        cand = Vector3.new(cand.X, SpotY(mv, tp) + (mv.Ground and 0 or rng:NextNumber(-4, 4)), cand.Z)
        cand = mv.Clamp(cand)
        local sc, fan = ScreenCrowd(mv, cand, eye)
        local score = math.abs(Flat(cand - tp).Magnitude - pref) * 0.4 + Crowd(mv, cand) * BotMove.CROWD_W + sc * BotMove.SCREEN_W + fan + ((i == 3 or i == 4) and 2 or 0)
        if score < bestScore then
            if not Open(mv, cand) then score += 1000 end
            if score < 1000 and DG and mv.Geo and not DG.LinkSees(cand + Vector3.new(0, 1, 0), tp + Vector3.new(0, 1.5, 0), mv.Geo) then score += 30 end
            if score < bestScore and not Reach(mv, cur, cand) then score += 40 end -- (cover in the way: it would walk into it and stall)
            if score < bestScore then best, bestScore = cand, score end
        end
    end
    if bestScore >= 1000 then return nil end
    return best
end
-- a caster's spot: behind the nearest ally (the side away from you), at least its band's near edge from you
local function PickBehind(mv: any, tp: Vector3, cur: Vector3): Vector3?
    local rng, P = mv.Rng, mv.P
    local best, bd = nil, math.huge
    for other, op in pairs(mv.Group) do
        if other ~= mv.Model and other.Parent and other:GetAttribute("Dead") ~= true then
            local ty = other:GetAttribute("DroneType")
            local orow = ty and (BotRoles.ActiveRow and BotRoles.ActiveRow(ty) or BotRoles.ROWS[ty]) -- (ENEMY VARIETY: a Seraph is a caster now)
            if not (orow and orow.Role == "Caster") then
                local m = (op - cur).Magnitude
                if m < bd and m < 70 then best, bd = op, m end
            end
        end
    end
    if not best then return PickBand(mv, tp, cur, mv.Hi - 4, mv.Hi + 4) end
    local away = Flat(best - tp)
    away = (away.Magnitude > 0.5) and away.Unit or Flat(cur - tp).Unit
    local across = Vector3.yAxis:Cross(away)
    -- (REVIEW ROUND) two tries (its own side, then the other): a spot it can SEE you from wins -- wards / zones need a line
    local DG = BotMove.DG
    local fallback = nil
    for k = 1, 2 do
        local side = (k == 1) and mv.Side or -mv.Side
        local p = best + away * R(rng, P.Behind) + across * (side * rng:NextNumber(1, 4))
        local d = Flat(p - tp).Magnitude
        if d < mv.Lo then p = tp + Flat(p - tp).Unit * mv.Lo end
        p = mv.Clamp(Vector3.new(p.X, SpotY(mv, tp), p.Z))
        -- (behind the ally is a wall -- you stand near the room's edge -- the clamp pulled it in close: not this one)
        if Open(mv, p) and Flat(p - tp).Magnitude >= mv.Lo * 0.8 then
            if not (DG and mv.Geo) or DG.LinkSees(p + Vector3.new(0, 1, 0), tp + Vector3.new(0, 1.5, 0), mv.Geo) then return p end
            fallback = fallback or p
        end
    end
    return fallback or PickBand(mv, tp, cur, mv.Lo, mv.Hi)
end

local function Go(mv: any, goal: Vector3, now: number)
    -- (owner: smooth, no snapping) a big change of direction brakes first: a short settle before it sets off the other way
    local way = Flat(goal - mv.Pos)
    if mv.Vel.Magnitude > 2 and way.Magnitude > 0.5 and Flat(mv.Vel).Unit:Dot(way.Unit) < 0.35 then
        mv.SettleUntil = now + mv.Rng:NextNumber(0.12, 0.25)
    end
    mv.Goal, mv.State = goal, "Move"
    mv.MoveT0, mv.StallHist = now, nil -- (ROUND 2: the stall watch starts with the step)
    mv.Chain = mv.P.Chain ~= nil and mv.Rng:NextNumber() < mv.P.Chain -- (ROUND 2: this step runs on into the next one, no stop)
    mv.MoveFrom, mv.MoveLen = mv.Pos, math.max(0.5, (goal - mv.Pos).Magnitude)
    mv.MoveUntil = now + mv.MoveLen / math.max(0.5, mv.TopNow or mv.Top) * 2 + 1.2 -- (a step that never arrives -- a wall -- gives up; REVIEW ROUND: at the speed it really has now -- chilled, idle)
    goals[mv.Model] = goal
    if BotMove.DEBUG and mv.Model then mv.Model:SetAttribute("MoveGoal", goal); mv.Model:SetAttribute("MoveSt", "M") end -- (Studio: where its last step was headed)
end
-- STALLED (a wall / pillar / tower / rock between it and its spot -- CreateBot's unstick never sees a brain stall: its point stays a
-- few studs ahead): a detour to an open spot its BODY can walk to in a straight line (ROUND 2: DungeonGenerator.PathClear, a
-- body-wide cast + terrain -- the old thin ray let it pick a spot past a corner it then brushed and stalled on again), nearest to
-- where it wanted to go, a spot that sees you preferred; two rings (8-13, then 14-20 studs), every direction
local function Detour(mv: any, now: number, pos: Vector3, tp: Vector3?): boolean
    local DG = BotMove.DG
    if not (DG and mv.Goal) then return false end
    local best, bs = nil, math.huge
    local eye = tp and (tp + Vector3.new(0, 1.5, 0))
    for ring = 1, 2 do
        for i = 0, 11 do
            local a = i * math.pi / 6 + mv.Rng:NextNumber(-0.2, 0.2) + ring * 0.26
            local cand = mv.Clamp(pos + Vector3.new(math.cos(a), 0, math.sin(a)) * ((ring == 1) and mv.Rng:NextNumber(8, 13) or mv.Rng:NextNumber(14, 20)))
            if mv.Ground then cand = Vector3.new(cand.X, mv.GroundY, cand.Z) else cand = Vector3.new(cand.X, pos.Y, cand.Z) end
            if (Flat(cand - pos)).Magnitude > 4 then
                local sc = (cand - mv.Goal).Magnitude
                if sc < bs and eye and mv.Geo and not DG.LinkSees(cand, eye, mv.Geo) then sc += 12 end
                if sc < bs and Open(mv, cand) and Reach(mv, pos, cand) then best, bs = cand, sc end
            end
        end
        if best then break end
    end
    if not best then return false end
    mv.Detour, mv.DetourGoal = best, mv.Goal
    mv.Goal, mv.State = best, "Move"
    mv.MoveFrom, mv.MoveLen = mv.Pos, (best - mv.Pos).Magnitude
    mv.MoveUntil = now + mv.MoveLen / math.max(0.5, mv.TopNow or mv.Top) * 2 + 1
    mv.MoveT0, mv.StallHist = now, nil
    mv.SettleUntil = nil -- (no brake-before-turn: it is standing still against the cover anyway)
    goals[mv.Model] = best
    mv.Detours = (mv.Detours or 0) + 1
    if BotMove.DEBUG and mv.Model then mv.Model:SetAttribute("MoveSt", "D") end
    if BotMove.DEBUG and mv.Model and mv.Model.Parent then mv.Model:SetAttribute("MoveDetours", mv.Detours) end -- (Studio play-test counter)
    return true
end
local function Hold(mv: any, now: number, holdFor: number?)
    if BotMove.DEBUG and mv.State ~= "Hold" and mv.Model then mv.Model:SetAttribute("MoveSt", "H") end -- (Studio: the probe's stuck report)
    mv.State, mv.HoldAt = "Hold", mv.Pos
    goals[mv.Model] = mv.Pos
    local P = mv.P
    mv.NextPick = now + (holdFor or (P.Hold and R(mv.Rng, P.Hold) or 1.8)) * mv.HoldMul
end

-- one frame. c = { Now, Dt, Pos (the body), Target (your position) | nil, Plant (winding up / staggered / mid-dive), Dash (mid-dive),
-- Slow (the bot's SlowMult x idle pace: Dt already carries it; the brain's timeouts read it),
-- Recover (a rusher winded after its dive), Safe (you're in the safe room / its pack is idle), Wander (the idle spot), Los,
-- AtkIn (s to its next attack) } -> the spot the body should be at this frame (CreateBot's smoothing follows it)
function BotMove.Step(mv: any, c: any): Vector3
    local now, dt, pos = c.Now, c.Dt, c.Pos
    -- the brain's own point follows the body (a teleport / blink / unstick / dive / wall puts it back on the body)
    if not mv.Pos or now - mv.Last > 0.35 then mv.Pos, mv.Vel = pos, Vector3.zero; Hold(mv, now, 0.3) end
    mv.Last = now
    local off = mv.Pos - (pos - Vector3.yAxis * (mv.Arc or 0)) -- (the hop arc is drawn on top of the brain's point)
    local om = off.Magnitude
    -- (REVIEW ROUND) a TELEPORT sets mv.Jump at its site in CreateBot (Skittish, a Blinking elite, the sight watchdog, an unembed
    -- step-out): the brain starts over from the new spot, never walks back. Without the flag only a jump bigger than a frame's
    -- worth of its own movement counts (a frame hitch is not a teleport).
    if mv.Jump or om > math.max(4, 2.5 + mv.Top * dt) then
        mv.Jump = nil
        mv.Pos, mv.Vel = pos - Vector3.yAxis * (mv.Arc or 0), Vector3.zero
        mv.Detour, mv.Hopping = nil, nil
        Hold(mv, now, mv.Rng:NextNumber(0.2, 0.6))
    elseif om > 2.5 then
        mv.Pos = pos + off * (2.5 / om)
    end
    if c.Dash or mv.WasDash then mv.Pos, mv.Vel = pos, Vector3.zero end -- (mid-dive the dive owns the body: the brain rides along, + the frame after it)
    mv.WasDash = c.Dash
    -- the speed it has NOW (chilled / frozen, an idle linked pack, an idle walk): timeouts + the stall watch read it
    mv.TopNow = mv.Top * (c.Slow or 1) * ((c.Safe or not c.Target) and 0.55 or 1)
    -- PLANT: c.Plant (CreateBot: a rusher's wind-up / dive, a stagger) or the model's attack wind-up (c.AtkEnd, server time c.SrvNow:
    -- EnemyAttacks stamps AtkEnd when the wind-up starts). (ROUND 2) a role with PlantLead keeps walking through the start of the
    -- wind-up and plants only for its last PlantLead s + 0.15 s for the volley; the others plant through the whole wind-up + 0.2 s
    local P0 = mv.P
    local ae, sn = c.AtkEnd, c.SrvNow
    local plant = c.Plant == true
    if not plant and type(ae) == "number" and type(sn) == "number" then
        local rw = mv.Row
        if rw and rw.NoPlant then -- (ENEMY VARIETY run-and-gun: it fires on the move, never plants for its own wind-up)
        elseif P0.PlantLead and not (rw and rw.PlantAll) then plant = sn < ae + 0.15 and sn > ae - P0.PlantLead -- (PlantAll: a channel stands)
        else plant = sn < ae + 0.2 and sn > ae - 6 end
    end
    -- PROGRESS WATCH (ROUND 2; owner: "bots shouldnt be stuck for more than about a second"): every STALL_EVERY s while it walks,
    -- how much CLOSER to its spot it came over the last STALL_WIN s (sliding along a wall doesn't count: that's no progress either);
    -- under ~1 stud (less if it is slowed) -> a detour at once. Not in the first 0.3 s of a step (it is still speeding up), not while
    -- it brakes before a turn / plants / idles (an idle pack ambles at a fraction of its speed: REVIEW ROUND false stalls).
    if now >= (mv.StallAt or 0) then
        mv.StallAt = now + BotMove.STALL_EVERY
        local g = mv.Goal
        local gd = g and (mv.Ground and Flat(g - pos) or (g - pos)).Magnitude or 0
        local watching = mv.State == "Move" and not plant and not c.Safe and g ~= nil and gd > 3 and now - (mv.MoveT0 or now) >= 0.3
            and not (mv.SettleUntil and now < mv.SettleUntil + 0.3) and not mv.Hopping
        if not watching then
            mv.StallHist = nil
        else
            local h = mv.StallHist
            if not h then h = {}; mv.StallHist = h end
            table.insert(h, gd)
            local k = math.max(1, math.round(BotMove.STALL_WIN / BotMove.STALL_EVERY))
            if #h > k + 1 then table.remove(h, 1) end
            if #h == k + 1 then
                local want = math.min(1, mv.TopNow * BotMove.STALL_WIN * 0.4)
                if h[1] - gd < want then
                    mv.StallHist = nil
                    mv.Stalled = (mv.Stalled or 0) + 1
                    if not Detour(mv, now, pos, c.Target) then mv.Side = -mv.Side; Hold(mv, now, 0.3); mv.NextPick = now + 0.3 end
                end
            end
        end
    end
    local tp = c.Target
    local wantV = Vector3.zero
    local acc = mv.Acc
    local top = mv.Top
    local P = mv.P
    if plant then
        -- PLANTED (a wind-up, a volley, a stagger, a dive): it stands -- brakes hard, never snaps
        acc *= BotMove.BRAKE
        if not mv.Planted then mv.Planted = true end
        if mv.State == "Move" and mv.Role ~= "Rusher" and not c.Plant then
            -- (ROUND 2) a step PAUSES for the shot and carries on after it (the strafe stays long; its timeout waits too)
            mv.MoveUntil = (mv.MoveUntil or now) + dt
            mv.MoveT0 = now
        else
            if mv.State == "Move" then Hold(mv, now) end
            mv.HoldAt = mv.Pos -- (it holds where it stands -- after a dive that's where the dive ended, never the spot it left)
        end
    else
        if mv.Planted then
            -- just fired: a gunner / marksman often steps off now (the "step after the volley"), a rusher hops
            mv.Planted = false
            if tp and mv.Rng:NextNumber() < (P.AfterFire or 0) then mv.NextPick = math.min(mv.NextPick, now + mv.Rng:NextNumber(0.25, 0.7)) end
            if tp and mv.Role == "Rusher" and mv.Rng:NextNumber() < (P.HopChance or 0) then mv.HopAt = now + mv.Rng:NextNumber(0.15, 0.4) end
        end
        if c.Safe or not tp then
            -- idle (you're in the safe room / its pack hasn't seen you): walks slowly between the idle spots it's given
            local w = c.Wander
            if w then
                local g = mv.Clamp(Vector3.new(w.X, mv.Ground and mv.GroundY or w.Y, w.Z))
                if not mv.Detour and (not mv.Goal or (mv.Goal - g).Magnitude > 2) then Go(mv, g, now) end
            end
            top *= 0.55
        elseif mv.Role == "Rusher" or (mv.Role == "Heavy" and mv.Reach) then
            -- CLOSE IN and STOP at its reach; winded after a dive = it stays put (a free shot); then a short hop to a new angle
            local rel = Flat(mv.Pos - tp)
            local d = rel.Magnitude
            local reach = mv.Reach or 6
            if c.Recover then
                if mv.State == "Move" then Hold(mv, now) end
                mv.HoldAt = mv.Pos
            elseif (mv.Hopping or mv.Detour) and mv.State == "Move" then
                -- (the hop / the detour plays out)
            elseif mv.HopAt and now >= mv.HopAt then
                mv.HopAt = nil
                local dir = (d > 0.5) and rel.Unit or Vector3.xAxis
                local across = Vector3.yAxis:Cross(dir) * mv.Side
                if mv.Rng:NextNumber() < 0.5 then mv.Side = -mv.Side end
                local g = mv.Clamp(mv.Pos + across * R(mv.Rng, P.Hop or { 3, 6 }) + dir * mv.Rng:NextNumber(0, 2))
                g = Vector3.new(g.X, SpotY(mv, tp), g.Z)
                if Open(mv, g) then Go(mv, g, now); mv.Hopping = true end
            elseif mv.Role == "Rusher" and mv.Row.Attack ~= "Swing" and d < reach - 6 and mv.State ~= "Move" then
                -- (REVIEW ROUND) a DIVER you walked up to backs out to its stand-off: its dive needs the room (7+ studs) -- it used to sit
                -- next to you with its dive switched off for good
                local dir = (d > 0.5) and rel.Unit or Vector3.xAxis
                local g = mv.Clamp(Vector3.new(tp.X + dir.X * reach, SpotY(mv, tp), tp.Z + dir.Z * reach))
                if Open(mv, g) then Go(mv, g, now) end
            elseif d > reach + 2.5 or mv.State == "Move" then
                -- the stand-off point on its own line in (its own angle offset, fading as it arrives), re-aimed as you move
                local a = math.atan2(rel.Z, rel.X) + mv.Off * math.clamp((d - reach) / 20, 0, 1)
                local g = mv.Clamp(Vector3.new(tp.X + math.cos(a) * reach, SpotY(mv, tp), tp.Z + math.sin(a) * reach))
                if mv.State ~= "Move" then Go(mv, g, now) else mv.Goal = g; goals[mv.Model] = g end
                mv.MoveUntil = now + 3 -- (a chase never times out while you move; CreateBot's unstick handles walls)
            end
        elseif mv.Role == "Caster" then
            if not c.Los then mv.NoLos = (mv.NoLos or 0) + dt else mv.NoLos = 0 end
            if mv.State ~= "Move" and (mv.NoLos or 0) > BotMove.BLIND_REPICK then
                -- (REVIEW ROUND) behind its ally it can't see you (its ward / zone need a line): its band, scored for sight
                mv.NoLos = 0
                mv.NextPick = now + R(mv.Rng, P.Repick) / mv.Freq
                local g = PickBand(mv, tp, mv.Pos, mv.Lo, mv.Hi)
                if g then Go(mv, g, now) end
            elseif mv.State ~= "Move" and now >= mv.NextPick then
                mv.NextPick = now + R(mv.Rng, P.Repick) / mv.Freq
                local g = PickBehind(mv, tp, mv.Pos)
                if g and (g - mv.Pos).Magnitude > 3 then Go(mv, g, now) end
            end
        else
            -- GUNNER / MARKSMAN / ranged HEAVY: hold its band, step to a new spot on its own timer
            local d = Flat(mv.Pos - tp).Magnitude
            if mv.State == "Hold" then
                local outOfBand = d < mv.Lo - 5 or d > mv.Hi + 8
                if not c.Los then mv.NoLos = (mv.NoLos or 0) + dt else mv.NoLos = 0 end
                local due = now >= mv.NextPick or outOfBand or (mv.NoLos or 0) > BotMove.BLIND_REPICK
                -- (better shooting windows) it doesn't set off right before it fires: the step waits for the volley
                -- (once a step: an attack that keeps failing -- no line, no slot -- must not pin it in place)
                if due and not P.PlantLead and c.Los and c.AtkIn and c.AtkIn > -0.2 and c.AtkIn < 0.55 and not outOfBand and not mv.Deferred then
                    due = false; mv.Deferred = true; mv.NextPick = now + 0.8
                end
                if due then
                    mv.Deferred = nil
                    local g = PickBand(mv, tp, mv.Pos, mv.Lo, mv.Hi)
                    if g then Go(mv, g, now) else Hold(mv, now, 0.6) end
                    mv.NoLos = 0
                end
            end
        end
        -- walk to the goal: accelerate, cruise, slow down into the spot (it arrives at rest)
        if mv.State == "Move" and mv.Goal then
            local to = mv.Goal - mv.Pos
            if mv.Ground then to = Flat(to) end
            local dist = to.Magnitude
            if mv.Detour and (dist < 2 or now >= (mv.MoveUntil or math.huge)) then
                mv.Detour, mv.DetourGoal = nil, nil
                Hold(mv, now, 0) -- (ROUND 2: round the corner it picks its next spot at once, still moving)
            elseif dist < (mv.Chain and 2 or 0.35) or now >= (mv.MoveUntil or math.huge) then
                if now >= (mv.MoveUntil or math.huge) then mv.Side = -mv.Side end -- (blocked: next time the other way)
                mv.Hopping = nil
                -- (ROUND 2) a CHAINED step runs on into the next one (no stop: a glide, PoE-style); the others arrive at rest and hold
                if mv.Chain and now < (mv.MoveUntil or math.huge) then Hold(mv, now, 0) else Hold(mv, now) end
            elseif mv.SettleUntil and now < mv.SettleUntil then
                wantV = Vector3.zero -- (the brake before a turn)
            else
                -- (ROUND 2) a chained step keeps CHAIN_KEEP of its speed at the spot (it carries on into the next step)
                local ve = (mv.Chain or mv.Detour) and top * BotMove.CHAIN_KEEP or 0
                local v = math.min(top, math.sqrt(2 * acc * 0.8 * dist + ve * ve))
                wantV = to.Unit * v
            end
        end
        if mv.State == "Hold" and mv.HoldAt then
            -- holding: alive, not frozen -- a slow sway round its spot (under a stud a second)
            local t = now * mv.Wf
            local sway = Vector3.new(math.sin(t + mv.Ph) * 0.9, mv.Ground and 0 or math.sin(t * 0.8 + mv.Ph2) * 0.6, math.cos(t * 0.9 + mv.Ph2) * 0.9)
            local to = (mv.HoldAt + sway) - mv.Pos
            if mv.Ground then to = Flat(to) end
            wantV = to * 1.5
            if wantV.Magnitude > 1.6 then wantV = wantV.Unit * 1.6 end
        end
        -- personal space: a soft push away from bots closer than SEP (and a holder that's crowded picks a new spot). (REVIEW ROUND) the
        -- room's bots are scanned PUSH_HZ times a second (cached between), and a removed bot leaves the group here (brain bots skip
        -- CreateBot's own separation loop, which used to do that)
        if now >= (mv.PushAt or 0) then
            mv.PushAt = now + 1 / BotMove.PUSH_HZ
            local push = Vector3.zero
            for other, op in pairs(mv.Group) do
                if other ~= mv.Model then
                    if not other.Parent then mv.Group[other] = nil else
                        local dd = Flat(mv.Pos - op)
                        local m = dd.Magnitude
                        if m < BotMove.SEP and m > 0.01 then push += dd.Unit * ((BotMove.SEP - m) / BotMove.SEP) end
                    end
                end
            end
            mv.Push = push
        end
        local push = mv.Push or Vector3.zero
        if push.Magnitude > 0.01 then
            if push.Magnitude > 1 then push = push.Unit end
            wantV += push * (mv.Top * 0.6)
            if mv.State == "Hold" and push.Magnitude > 0.5 and tp and mv.Role ~= "Rusher" then mv.NextPick = math.min(mv.NextPick, now + 0.3) end
        end
    end
    -- acceleration-limited velocity (smooth starts / stops / turns)
    local dv = wantV - mv.Vel
    local lim = acc * dt
    if dv.Magnitude > lim then dv = dv.Unit * lim end
    mv.Vel += dv
    if mv.Ground then mv.Vel = Flat(mv.Vel) end
    mv.Pos += mv.Vel * dt
    mv.Pos = mv.Clamp(mv.Pos)
    mv.Moving = mv.State == "Move" or mv.Vel.Magnitude > 2.5
    local out = mv.Pos
    if mv.Ground then
        out = Vector3.new(out.X, mv.GroundY, out.Z)
        mv.Pos = out
    end
    -- the step's flavour: a hopper's step is a low arc in the air. (REVIEW ROUND) a step cut short (a wind-up, a teleport) lets the
    -- arc come down over ~0.15 s instead of snapping to the floor
    local arc = 0
    if mv.Style and mv.Style.Hop then
        if mv.State == "Move" and mv.MoveFrom and mv.Goal and not mv.Hopping and not mv.Detour then
            local u = math.clamp(Flat(mv.Pos - mv.MoveFrom).Magnitude / math.max(0.5, Flat(mv.Goal - mv.MoveFrom).Magnitude), 0, 1)
            arc = mv.Style.Hop * math.sin(math.pi * u)
        end
        local prev = mv.Arc or 0
        if arc < prev then arc = math.max(arc, prev - mv.Style.Hop / 0.15 * dt) end
    end
    mv.Arc = arc
    if arc > 0 then out += Vector3.yAxis * arc end
    return out
end
-- busy walking? (the ranged attack waits until it has planted). (ROUND 2) a role with PlantLead never waits: it starts its wind-up on
-- the move, the step pauses for the last PlantLead s and the shot, then carries on -- only marksmen / casters wait for their spot
function BotMove.Busy(mv: any?): boolean
    return mv ~= nil and mv.State == "Move" and not mv.Hopping and mv.Role ~= "Rusher" and not mv.P.PlantLead
end
function BotMove.Forget(model: Instance) goals[model] = nil end

return BotMove
