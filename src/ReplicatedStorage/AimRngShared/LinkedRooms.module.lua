--!nocheck
-- LINKED ROOMS PILOT (2026-10-21; owner: "how hard would it be to make something more similar to POE in terms of a bigger
-- world / area and finding hordes throughout it?" -> option A "Linked rooms" -> "Lets try A then"). Contract:
-- docs/LINKED_ROOMS.md. An admin switch (F6 > COMMANDS > Runs > "Linked rooms" = Player attr LinkedRooms; DevCmd
-- ["linkedrooms", true|false]) on ONE player: their solo REGULAR floors become a line of combat rooms joined by short paths
-- (+ one optional side room off the middle), with the packs PLACED in the rooms and idle until you come near. The exit
-- (chest + portals) opens in the last room when its packs are dead -- the earlier rooms and the side room may be skipped.
-- Off = the game exactly as before. Boss / mini-boss floors, trials, the Daily, the Gauntlet Run, maps and party floors
-- are never linked.
--
-- This module = the tunables + the LAYOUT (pure data, the same on the server and the client from the floor seed):
--   LinkedRooms.Layout(seed, difficulty, combatZ, roomSize) -> L
--     L.Rooms[i] = { Index, X, Z, Kind = "Main" | "Exit" | "Side", Doors = { N, S, E, W }, Links = { j, ... } }
--       room 1 = today's combat room (BuildThemedDungeon builds it; the entry corridor is its north door); rooms 2..Main run
--       on along +Z on the same axis (x = 0); the last main room is the EXIT room; the side room sits off room L.Mid to
--       the east or west (its own dead end)
--     L.Paths[k] = { A, B, Axis = "Z" | "X", X, Z (centre), SX, SZ (size), W, Len }
--     L.Main, L.Exit, L.Side, L.Mid, L.Half, L.Size, L.MinX .. L.MaxZ (the whole footprint)
--   LinkedRooms.RoomAt(L, pos) -> index of the room you're in (inside its walls) or the nearest one, inside?
--   LinkedRooms.Hops(L, a, b) -> links between two rooms;  LinkedRooms.Box(L, i, inset) -> x0, x1, z0, z1
--   LinkedRooms.DoorPoint(L, a, b) -> the mouth of the path from room a to room b, on room a's wall
-- Server: DungeonRuns (config.Linked, the per-room roster, spawning rooms as you near them, waking packs, the exit-room clear,
-- the side cache). Builds: DungeonGenerator (BuildLinked / RollLinkedRoster / LinkCheck in CreateBot). Client: DungeonClient
-- (far rooms parked, the ROOM n / m line + the edge arrow, the side cache chest).
local LinkedRooms = {}

LinkedRooms.ATTR = "LinkedRooms" -- (Player attribute: true = linked floors for this player; replicates, resets on leave)
LinkedRooms.ON = true -- (the global kill switch: false = nobody gets linked floors, whatever the attribute says)

-- the line: MAIN combat rooms (the last one is the exit room), MAIN_HARD from HARD_FROM up, SIDE side rooms (0 or 1)
LinkedRooms.MAIN, LinkedRooms.MAIN_HARD, LinkedRooms.HARD_FROM = 3, 2, "Hard" -- (v2 ramp, main: 3 rooms on every tier -- 4 made Torment runs +33%;
-- RUN PACE 2026-10-24, owner: runs too long vs PoE maps -> 2 main rooms (+ the side room) from Hard up: measured on-level runs there
-- were 10-23 min, ~85-95% of it fighting; a 2-room floor drops a room's packs + a path. Easy / Normal keep 3 (their EARLY RAMP packs))
LinkedRooms.SIDE = 1
-- paths between rooms (studs): length / width ranges, rolled per path from the floor seed
LinkedRooms.PATH_LEN = { 16, 24 } -- (v2, owner "runs relatively short": was 24-40; v4 DOGLEG paths are BAND + W + BAND long instead)
-- (v4 VISIBILITY, owner: "you can see the entire next area and the enemies which is kind of visually overwhelming") every path is a
-- DOGLEG: out of room A's door, a sideways leg, into room B by a door DOGLEG_OFF studs to the side -- a BAND of rock either side of
-- the leg (terrain banks / solid walls on part maps), so the next room only shows once you're in the leg's last stretch. A room's
-- enemies are only built on your screen once you're in it or on a path into it (or they're awake and chasing you).
LinkedRooms.BAND = 6 -- (rock between a room's wall and the sideways leg, each side)
LinkedRooms.DOGLEG_EXTRA = 8 -- (room B's door sits W + this to the side of room A's)
LinkedRooms.PATH_W = { 14, 18 }
LinkedRooms.PATH_H = 14 -- (the path's opening height in the room wall; terrain banks rise well above it)
-- packs per room (PacksPilot leaders + fodder); the side room adds SIDE_ELITE forced elite leaders on top of the usual chances
LinkedRooms.PACKS_PER_ROOM = { 2, 3 }
LinkedRooms.PACKS_PER_ROOM_HARD = { 2, 2 } -- (v2: a 4-room floor's rooms; RUN PACE 2026-10-24: also a 2-room floor's (Torment up); 3-room floors keep 2-3)
LinkedRooms.SIDE_PACKS = { 3, 3 } -- (v2: the detour pays -- a full side room + the encounter + the cache)
LinkedRooms.SIDE_PACKS_SHORT = { 2, 2 } -- (RUN PACE 2026-10-24: a 2-room floor's side room -- 3 packs were ~30-40% of a full clear's time)
LinkedRooms.SIDE_ELITE = 1
LinkedRooms.SPOT_GAP = 30 -- (packs at least this far apart)
-- (v2, owner: "make the floors feel like a zone and still so the runs are relatively short. Linked floor can count as 2")
-- HORDE ROOM: one random main room holds ONE dense pack -- an elite + HORDE_FODDER fodder in a ring HORDE_R round it -- instead of
-- its 2-3 small packs (about the HP of 3 packs: a Magic / Rare elite ~2-3 bots + 16-20 fodder at 0.25 each)
LinkedRooms.HORDE = true
LinkedRooms.HORDE_FODDER = { 18, 22 }
LinkedRooms.HORDE_R = { 6, 22 } -- (MOVEMENT ROUND 2, owner: the horde "look[s] like this giant silly cluster": 4-15 -> 6-22)
-- PATH PACKS: every path at least STRAGGLER_LEN long has a few stragglers in it (a plain leader + PATH_FODDER fodder), leashed to the path
LinkedRooms.STRAGGLER_LEN = 28 -- (v4: dogleg paths are 26-30 long -- about half of them)
LinkedRooms.PATH_FODDER = { 2, 3 }
-- SHORT RUNS: a linked floor COUNTS AS FLOOR_STEP floors -- the portal after it leads FLOOR_STEP floors on (DungeonRuns), jobs count
-- it FLOOR_STEP times, and a floor is only linked when the floor after it is a regular one (boss / mini-boss arenas stay as they are)
LinkedRooms.FLOOR_STEP = 2
LinkedRooms.DOOR_CLEAR = 30 -- (no pack within this of a doorway: you don't walk out of a path into a pack's lap)
-- idle packs: asleep until you're within WAKE_DIST or you've hurt one of them; then the whole pack wakes
LinkedRooms.WAKE_DIST = 55
LinkedRooms.ENGAGE_MARGIN = 26 -- (an awake pack fights you while you're inside its room or within this of its walls)
LinkedRooms.BOX_INSET = 4 -- (the LEASH: bots stay this far inside their own room's walls)
LinkedRooms.PATH_INSET = 3.5 -- (RUNFIX 2026-10-25: ... and this far inside a path's walls -- 1.5 let a flier's body (radius up to ~2.5) into
-- the canyon rock, which smooth terrain rounds ~1-2 studs past the carved box, worst in the dogleg's inside corners)
LinkedRooms.IDLE_PACE = 0.35 -- (an idle bot mills round its spot in slow motion)
LinkedRooms.IDLE_WANDER = 9 -- (studs round its spot)
LinkedRooms.SLEEP_DIST = 120 -- (farther than this, an idle / out-of-room bot runs no AI at all: a cheap check 4x a second)
LinkedRooms.XRAY_NEAR = 8 -- (BOTFIX: an enemy outline shows through walls only in your room / path, or this close; owner 2026-10-24: 18 -> 8 = a doorway)
-- (v3, owner after playing: "you can just run through the rooms and nothing really happens") ROOMS ENGAGE YOU:
--   * stepping inside a room wakes EVERY pack in it at once (a path's stragglers: stepping into the path), and a pack also wakes
--     when one of its bots within LOS_WAKE studs can see you -- awake packs fight at once (no idle mill once you're in)
--   * awake packs CHASE: their leash grows from their room to the room + the paths and rooms one link away (never the entry
--     room), so sprinting through drags them after you -- a growing horde
--   * AWAKE_CAP: past that many awake bots the earliest-woken packs outside your room give up (Homing) and walk home; they only
--     wake again when you step into their room or hurt them
LinkedRooms.LOS_WAKE = 70
LinkedRooms.CHASE = false -- (SEALED ROOMS 2026-10-25: off -- packs never leave their own room; see SEAL below)
LinkedRooms.CHASE_MARGIN = 12 -- (an awake bot fights you while you're within this of its chase area)
LinkedRooms.AWAKE_CAP = 45
LinkedRooms.MAP_TIME = 1.1 -- (MAPS: the map timer x this when its floors are linked: tools/sim/linked_pace.py -- a linked map rushed takes 0.84-0.98x a
-- single-room map, fully cleared 1.09-1.25x)
LinkedRooms.PARTY_AWAKE_PER = 3 -- (party linked floors: + this many awake bots a member past the first -- 54 for four; server-run bots
-- cost the server heartbeat, measured in CLAUDE.md)
LinkedRooms.PARTY_PACK_SCALE = 0.5 -- (party linked floors: packs a room x (1 + this x (CountMult - 1)) -- a room holds more than a
-- solo one, but a whole line of rooms spawned near four members is a lot of server-run bots: measured, see CLAUDE.md)
-- (v3 perf, owner rule "must run on almost anything") only the FX_NEAREST bots nearest the camera keep their particles (element auras):
-- a chase costs no more particles than a normal fight; re-picked every 0.5 s on the client. A room's stand-ins are made SPAWN_BATCH
-- per frame (server) and the client builds at most CLIENT_SPAWN_PER_FRAME enemies a frame -- no frame builds a whole room.
LinkedRooms.FX_NEAREST = 12
LinkedRooms.SPAWN_BATCH = 4
LinkedRooms.CLIENT_SPAWN_PER_FRAME = 3
-- what exists: stand-ins for the rooms within SPAWN_HOPS links of yours; the client draws the room you're in + any room whose
-- walls are within PARK_DIST studs of you (in its doorway / on its path); the others are parked out of the workspace (their
-- kit, props and cover parts; the terrain always stays). PARK_DIST > ENGAGE_MARGIN: a room's colliders are always there
-- while its packs can fight you.
LinkedRooms.SPAWN_HOPS = 1 -- (SEALED ROOMS: no longer read -- rooms spawn on ARRIVAL, below)
-- SEALED ROOMS (2026-10-25, owner: "I still saw some of the bots in the next areas ... what if we spawned the bots in when you hit a
-- certain point" + "wouldnt grouping all of the bots be incredibly meta? ... Blocking the next corridor until you clear the room?"):
--   * ARRIVAL: a room's packs are made when someone steps ARRIVE_IN studs inside it (ArriveAt; 2026-10-26: no longer from the
--     path's leg / door band), a path's stragglers wait in the room it leads to (PATH_PACKS_IN_ROOM). Room 1 at the floor's start.
--   * SEAL: the way on from a main room (its door to the next main room) is closed by a barrier until that room's packs are dead
--     (folder attr LinkSeal = "<room>:<left>,..." from SealState; DungeonClient builds the barrier + the HUD line). The way back, the
--     side room's door and the exit room never close. Soft-lock guard: SEAL_STUCK_LEFT or fewer left and none killed for
--     SEAL_STUCK_S while someone is in the room -> it opens anyway.
--   * NO CHASE (CHASE false): a pack's leash is its room + the band of its doors (never the sealed one), so nothing is dragged down a
--     corridor or into the next room; one room's packs can still be fought at its door.
LinkedRooms.SEAL = true
LinkedRooms.SEAL_STUCK_LEFT = 3
LinkedRooms.SEAL_STUCK_S = 45
LinkedRooms.SEAL_H = 13.5 -- (the barrier panel's height from the floor: just under the path's opening, PATH_H 14)
LinkedRooms.SEAL_U = 2 -- (where it stands: this far into the path's first band, past the room's wall; SealGate's pylons span u 0.6..3.4)
-- (2026-10-26, owner: "bots spawn when walking into the path to the next area sometimes, whereas it should only be when you enter the
-- next area" + pushing into the barrier spawned the next area's bots) ARRIVE_IN: a room's packs are made once someone is this far
-- inside its walls -- never from a path. PATH_PACKS_IN_ROOM: a path's stragglers wait in the room the path leads to (one more small
-- pack there, made with it) instead of in the path, so a path is never where anything appears.
LinkedRooms.ARRIVE_IN = 0 -- (owner: "they should spawn as you are walking into the room": the moment you cross its doorway)
LinkedRooms.PATH_PACKS_IN_ROOM = true
LinkedRooms.ARRIVE_TICK = 0.1 -- (the arrival check's own fast loop -- the 0.5 s run tick let you walk ~8 studs in before anything came)
LinkedRooms.PARK = true
LinkedRooms.PARK_DIST = 70
-- the world between rooms (client, terrain maps): rock banks this high either side of a path / between rooms
LinkedRooms.BANK_H = { 26, 36 }
LinkedRooms.BANK_OUT = 30 -- (the banks run this far past the rooms' side walls)

local Shared = script.Parent

function LinkedRooms.For(player: Player?): boolean
    if not LinkedRooms.ON or player == nil then return false end
    local v = player:GetAttribute(LinkedRooms.ATTR)
    -- (2026-10-22, owner: keep linked rooms, "copy whatever PoE does" = every zone is a big area) ON for everyone, live too;
    -- F6 "Linked rooms off" (DevCmd linkedoff) sets the attr false on one player for a comparison
    return v ~= false
end

function LinkedRooms.MainCount(difficulty: string?): number
    local ItemData = require(Shared:WaitForChild("ItemData"))
    local r = ItemData.DifficultyRank[difficulty or "Easy"] or 1
    local hard = ItemData.DifficultyRank[LinkedRooms.HARD_FROM] or 5
    return (r >= hard) and LinkedRooms.MAIN_HARD or LinkedRooms.MAIN
end

-- (v4) a DOGLEG path in its own frame: u runs from room A's wall (0) to room B's (G), v across (room A's door at v = 0, room B's at
-- v = Off). Segments { u0, u1, v0, v1 }: out of A's door through the band, the sideways leg, through the band into B's door.
local function AddPath(L: any, a: number, b: number, axis: string, w: number, off: number)
    local T = LinkedRooms.BAND
    local G = 2 * T + w
    local A = L.Rooms[a]
    local dir = (axis == "Z") and 1 or ((L.Rooms[b].X > A.X) and 1 or -1)
    local p = { A = a, B = b, Axis = axis, W = w, Len = G, Off = off, Dir = dir, Band = T,
        U0 = (axis == "Z") and (A.Z + L.Half) or (A.X + dir * L.Half), V0 = (axis == "Z") and A.X or A.Z,
        Segs = { { 0, T, -w / 2, w / 2 }, { T, G - T, math.min(0, off) - w / 2, math.max(0, off) + w / 2 }, { G - T, G, off - w / 2, off + w / 2 } } }
    -- the world bounding box (old fields: X, Z = centre, SX, SZ = size)
    local x0, x1, z0, z1 = LinkedRooms.PathRect(p, 0, G, math.min(0, off) - w / 2, math.max(0, off) + w / 2)
    p.X, p.Z, p.SX, p.SZ = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
    table.insert(L.Paths, p)
    table.insert(A.Links, b)
    table.insert(L.Rooms[b].Links, a)
end
-- a rectangle in a path's (u, v) frame -> world x0, x1, z0, z1
function LinkedRooms.PathRect(p: any, u0: number, u1: number, v0: number, v1: number): (number, number, number, number)
    if p.Axis == "Z" then return p.V0 + v0, p.V0 + v1, p.U0 + u0, p.U0 + u1 end
    local xa, xb = p.U0 + p.Dir * u0, p.U0 + p.Dir * u1
    return math.min(xa, xb), math.max(xa, xb), p.V0 + v0, p.V0 + v1
end
-- a path's walkable segments as world boxes { x0, x1, z0, z1 } (pad: grow every side; into: the end segments reach on into the rooms)
function LinkedRooms.PathBoxes(p: any, pad: number?, into: number?): { any }
    local out, d, i = {}, pad or 0, into or 0
    for k, sg in ipairs(p.Segs) do
        local u0, u1 = sg[1] - ((k == 1) and i or 0), sg[2] + ((k == #p.Segs) and i or 0)
        local x0, x1, z0, z1 = LinkedRooms.PathRect(p, u0, u1, sg[3] - d, sg[4] + d)
        table.insert(out, { x0, x1, z0, z1 })
    end
    return out
end

function LinkedRooms.Layout(seed: number?, difficulty: string?, combatZ: number, roomSize: number): any
    local rng = Random.new(((seed or 1) * 31 + 7) % 2147483647)
    local half = roomSize / 2
    local main = LinkedRooms.MainCount(difficulty)
    local L = { Rooms = {}, Paths = {}, Size = roomSize, Half = half, Main = main, Exit = main }
    local z = combatZ
    local widths, offs = {}, {}
    for i = 1, main do
        -- (v4) every room leaves by its south door in the middle (room 1's is BuildChamber's) and is entered by a north door off to
        -- one side (Doors[side] = the door's offset along that wall)
        L.Rooms[i] = { Index = i, X = 0, Z = z, Kind = (i == main) and "Exit" or "Main", Doors = { N = (i == 1) and 0 or offs[i - 1], S = (i < main) and 0 or nil }, Links = {} }
        if i < main then
            widths[i] = rng:NextInteger(LinkedRooms.PATH_W[1], LinkedRooms.PATH_W[2])
            offs[i] = ((rng:NextNumber() < 0.5) and -1 or 1) * (widths[i] + LinkedRooms.DOGLEG_EXTRA)
            z += half + (2 * LinkedRooms.BAND + widths[i]) + half
        end
    end
    for i = 1, main - 1 do AddPath(L, i, i + 1, "Z", widths[i], offs[i]) end
    if LinkedRooms.SIDE > 0 and main >= 2 then
        local mid = math.max(2, math.ceil(main / 2)) -- (3 rooms -> room 2, 4 rooms -> room 2: off the middle of the line; RUN PACE
        -- 2026-10-24: 2 rooms -> off the EXIT room -- room 1 is BuildChamber's room, which has no east / west door)
        local m = L.Rooms[mid]
        local sx = (rng:NextNumber() < 0.5) and -1 or 1
        local w = rng:NextInteger(LinkedRooms.PATH_W[1], LinkedRooms.PATH_W[2])
        local off = ((rng:NextNumber() < 0.5) and -1 or 1) * (w + LinkedRooms.DOGLEG_EXTRA)
        local idx = main + 1
        L.Rooms[idx] = { Index = idx, X = sx * (roomSize + 2 * LinkedRooms.BAND + w), Z = m.Z, Kind = "Side", Doors = {}, Links = {}, Dir = sx }
        m.Doors[(sx > 0) and "E" or "W"] = 0
        L.Rooms[idx].Doors[(sx > 0) and "W" or "E"] = off
        AddPath(L, mid, idx, "X", w, off)
        L.Side, L.Mid, L.SideDir = idx, mid, sx
    end
    L.Horde = LinkedRooms.HORDE and rng:NextInteger(1, main) or nil -- (v2: the horde room, any room of the main line)
    local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
    for _, r in ipairs(L.Rooms) do
        minX, maxX = math.min(minX, r.X - half), math.max(maxX, r.X + half)
        minZ, maxZ = math.min(minZ, r.Z - half), math.max(maxZ, r.Z + half)
    end
    L.MinX, L.MaxX, L.MinZ, L.MaxZ = minX, maxX, minZ, maxZ
    return L
end

-- a room's box (x0, x1, z0, z1), `inset` studs inside its walls (negative = outside)
function LinkedRooms.Box(L: any, i: number, inset: number?): (number, number, number, number)
    local r = L.Rooms[i]
    local h = L.Half - (inset or 0)
    return r.X - h, r.X + h, r.Z - h, r.Z + h
end

-- the room you're in (inside its walls, +1), else the nearest room by distance to its box; second value = inside
function LinkedRooms.RoomAt(L: any, pos: Vector3): (number, boolean)
    local best, bestD = 1, math.huge
    for i, r in ipairs(L.Rooms) do
        local dx = math.max(0, math.abs(pos.X - r.X) - L.Half)
        local dz = math.max(0, math.abs(pos.Z - r.Z) - L.Half)
        local d = dx * dx + dz * dz
        if d <= 1 then return i, true end
        if d < bestD then best, bestD = i, d end
    end
    return best, false
end

-- how far pos is from room i's walls (0 inside)
function LinkedRooms.BoxDist(L: any, i: number, pos: Vector3): number
    local r = L.Rooms[i]
    local dx = math.max(0, math.abs(pos.X - r.X) - L.Half)
    local dz = math.max(0, math.abs(pos.Z - r.Z) - L.Half)
    return math.sqrt(dx * dx + dz * dz)
end

-- links between two rooms (a breadth-first walk of a handful of rooms)
function LinkedRooms.Hops(L: any, a: number, b: number): number
    if a == b then return 0 end
    local seen, frontier, n = { [a] = true }, { a }, 0
    while #frontier > 0 do
        n += 1
        local nxt = {}
        for _, i in ipairs(frontier) do
            for _, j in ipairs(L.Rooms[i].Links) do
                if j == b then return n end
                if not seen[j] then seen[j] = true; table.insert(nxt, j) end
            end
        end
        frontier = nxt
    end
    return math.huge
end

function LinkedRooms.PathBetween(L: any, a: number, b: number): any?
    for _, p in ipairs(L.Paths) do
        if (p.A == a and p.B == b) or (p.A == b and p.B == a) then return p end
    end
    return nil
end

-- the mouth of the path from room a to room b, on room a's wall (floor height y) -- v4: room B's door is off to the side
function LinkedRooms.DoorPoint(L: any, a: number, b: number, y: number?): Vector3?
    local p = LinkedRooms.PathBetween(L, a, b)
    if not p then return nil end
    local atA = p.A == a
    local u, v = atA and 0 or p.Len, atA and 0 or p.Off
    local x0, _, z0 = LinkedRooms.PathRect(p, u, u, v, v)
    return Vector3.new(x0, y or 2, z0)
end

-- (the side room as a chamber layout, below)
function LinkedRooms.SideLayout(L: any, base: any): any
    local side = L.Side and L.Rooms[L.Side]
    if not side then return base end
    local out = table.clone(base)
    out.CombatX, out.CombatZ, out.CombatSize = side.X, side.Z, L.Size
    out.BossZ, out.BossSize = side.Z, L.Size
    return out
end

-- a path's bounding box (x0, x1, z0, z1), `into` studs on into the rooms at both ends (v4: the dogleg's whole box -- use PathBoxes
-- for anything that must stay on the walkable part)
function LinkedRooms.PathBox(p: any, into: number?): (number, number, number, number)
    local i = into or 0
    local x0, x1, z0, z1 = LinkedRooms.PathRect(p, -i, p.Len + i, math.min(0, p.Off) - p.W / 2, math.max(0, p.Off) + p.W / 2)
    return x0, x1, z0, z1
end
-- (v4) the sideways leg's box (the stragglers stand there)
function LinkedRooms.LegBox(p: any): (number, number, number, number)
    local sg = p.Segs[2]
    return LinkedRooms.PathRect(p, sg[1], sg[2], sg[3] + 2, sg[4] - 2)
end

-- (v3) a bot's leash as boxes { x0, x1, z0, z1 }: HOME = its room (BOX_INSET in) or its path; CHASE = home + the paths from it + the
-- rooms one link away (a path's stragglers: the path + both its rooms). Each list comes with its bounding box.
local function BB(list: { any }): { number }
    local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
    for _, b in ipairs(list) do x0, x1, z0, z1 = math.min(x0, b[1]), math.max(x1, b[2]), math.min(z0, b[3]), math.max(z1, b[4]) end
    return { x0, x1, z0, z1 }
end
function LinkedRooms.LeashBoxes(L: any, room: number, pathIdx: number?): ({ any }, { any }, { number }, { number })
    local ins = LinkedRooms.BOX_INSET
    local function RoomBox(i: number) local a, b, c, d = LinkedRooms.Box(L, i, ins); return { a, b, c, d } end
    local function Add(list, p) for _, b in ipairs(LinkedRooms.PathBoxes(p, -LinkedRooms.PATH_INSET, 8)) do table.insert(list, b) end end -- (v4: the dogleg's segments)
    local home, chase = {}, {}
    if pathIdx and L.Paths[pathIdx] then
        local p = L.Paths[pathIdx]
        Add(home, p)
        Add(chase, p)
        table.insert(chase, RoomBox(p.A)); table.insert(chase, RoomBox(p.B))
    else
        home = { RoomBox(room) }
        -- (SEALED ROOMS) + the band of each of its doors (a pack meets you in its doorway), never the sealed way on
        for _, p in ipairs(L.Paths) do
            local sealed = LinkedRooms.SEAL and p.A == room and p.Axis == "Z" and room < L.Main
            if not sealed and (p.A == room or p.B == room) then
                local sg = (p.A == room) and p.Segs[1] or p.Segs[#p.Segs]
                local u0, u1 = sg[1], sg[2]
                if p.A == room then u0 -= ins + 1 else u1 += ins + 1 end
                local x0, x1, z0, z1 = LinkedRooms.PathRect(p, u0, u1, sg[3] + LinkedRooms.PATH_INSET, sg[4] - LinkedRooms.PATH_INSET)
                table.insert(home, { x0, x1, z0, z1 })
            end
        end
        chase = { RoomBox(room) }
        for _, j in ipairs(L.Rooms[room].Links) do
            local p = LinkedRooms.PathBetween(L, room, j)
            if p then Add(chase, p) end
            table.insert(chase, RoomBox(j))
        end
    end
    return home, chase, BB(home), BB(chase)
end
function LinkedRooms.InBoxes(list: { any }, p: Vector3, margin: number?): boolean
    local m = margin or 0
    for _, b in ipairs(list) do
        if p.X >= b[1] - m and p.X <= b[2] + m and p.Z >= b[3] - m and p.Z <= b[4] + m then return true end
    end
    return false
end

-- every doorway of room i (to its linked rooms; room 1 also has the entry corridor on its north wall)
function LinkedRooms.Doors(L: any, i: number, y: number?): { Vector3 }
    local out = {}
    for _, j in ipairs(L.Rooms[i].Links) do
        local d = LinkedRooms.DoorPoint(L, i, j, y)
        if d then table.insert(out, d) end
    end
    if i == 1 then table.insert(out, Vector3.new(0, y or 2, L.Rooms[1].Z - L.Half)) end
    return out
end

-- (v4) the paths touching room i, and is pos on one of them (its walkable segments, pad studs of slack)
function LinkedRooms.OnPathTo(L: any, i: number, pos: Vector3, pad: number?): boolean
    for _, p in ipairs(L.Paths) do
        if p.A == i or p.B == i then
            if LinkedRooms.InBoxes(LinkedRooms.PathBoxes(p, pad or 1, 0), pos, 0) then return true end -- (a step into the path, not the doorway)
        end
    end
    return false
end

-- (BOTFIX 2026-10-24, owner: "I still saw some bots when moving to next areas that were visible before they should be / like
-- stuck in terrain") WAKE + X-RAY by AREA, not straight-line distance: the rock between two rooms is ~30 studs thick, so WAKE_DIST
-- woke the next room's packs from the room before (they then showed up early, pressing at the rock). A distance wake now
-- counts only from the bot's own room or a path into it (a path's stragglers: that path); sight wakes (LOS_WAKE) are unchanged.
-- NearBoxes = those boxes (cached on L); AreaAt = "R<i>" inside room i / "P<k>" on path k / nil.
function LinkedRooms.NearBoxes(L: any, room: number?, pathIdx: number?): { any }
    L._near = L._near or {}
    local key = tostring(room) .. ":" .. tostring(pathIdx)
    local got = L._near[key]
    if got then return got end
    local out = {}
    if pathIdx and L.Paths[pathIdx] then
        for _, b in ipairs(LinkedRooms.PathBoxes(L.Paths[pathIdx], 2, 2)) do table.insert(out, b) end
    elseif room and L.Rooms[room] then
        local x0, x1, z0, z1 = LinkedRooms.Box(L, room, -2)
        table.insert(out, { x0, x1, z0, z1 })
        for _, p in ipairs(L.Paths) do
            if p.A == room or p.B == room then
                for _, b in ipairs(LinkedRooms.PathBoxes(p, 1, 0)) do table.insert(out, b) end
            end
        end
    end
    L._near[key] = out
    return out
end
function LinkedRooms.WakeReach(L: any, room: number?, pathIdx: number?, pos: Vector3): boolean
    if room == nil and pathIdx == nil then return true end
    return LinkedRooms.InBoxes(LinkedRooms.NearBoxes(L, room, pathIdx), pos, 0)
end
-- (nil only with exact = true; otherwise a spot in neither = the nearest room)
function LinkedRooms.AreaAt(L: any, pos: Vector3, exact: boolean?): string?
    local i, inside = LinkedRooms.RoomAt(L, pos)
    if inside then return "R" .. i end
    if not L._pathB then
        L._pathB = {}
        for k, p in ipairs(L.Paths) do L._pathB[k] = LinkedRooms.PathBoxes(p, 1, 0) end
    end
    for k, list in ipairs(L._pathB) do
        if LinkedRooms.InBoxes(list, pos, 0) then return "P" .. k end
    end
    return (not exact) and ("R" .. i) or nil
end

-- ==================== SEALED ROOMS (see SEAL at the top) ====================
local function InRect(pos: Vector3, x0: number, x1: number, z0: number, z1: number): boolean
    return pos.X >= x0 and pos.X <= x1 and pos.Z >= z0 and pos.Z <= z1
end
-- has someone at pos ARRIVED at room i: ARRIVE_IN studs inside its walls (2026-10-26: was "or in the leg / door band of a path into
-- it" -- the next room's bots appeared while you were still in the corridor)
function LinkedRooms.ArriveAt(L: any, i: number, pos: Vector3): boolean
    return InRect(pos, LinkedRooms.Box(L, i, LinkedRooms.ARRIVE_IN))
end
-- is pos anywhere on path k's walkable segments
function LinkedRooms.InPath(L: any, k: number, pos: Vector3): boolean
    local p = L.Paths[k]
    return p ~= nil and LinkedRooms.InBoxes(LinkedRooms.PathBoxes(p, 1, 0), pos, 0)
end
-- where a path's stragglers stand: the far end of the leg, in front of room B's door (round the corner from room A's door)
function LinkedRooms.StragglerBox(p: any): (number, number, number, number)
    local sg = p.Segs[2]
    return LinkedRooms.PathRect(p, sg[1] + 2, sg[2] - 2, p.Off - p.W / 2 + 2, p.Off + p.W / 2 - 2)
end
-- the main room whose way on path p is (nil = never sealed: the side room's path)
function LinkedRooms.SealOf(L: any, p: any): number?
    if LinkedRooms.SEAL and p.Axis == "Z" and p.A < L.Main and p.B == p.A + 1 then return p.A end
    return nil
end
-- room i's barrier: a thin panel across its door to the next main room, just inside the path's first band, a hair inside the
-- band's walls, floor and opening top -> (CFrame, Size). (2026-10-25, owner: "the barriers flicker a bunch in the corridors": the
-- first one was a ForceField box poking into the rock, the floor and the lid -- that material draws a shimmer on every cut)
function LinkedRooms.SealBox(L: any, i: number, floorY: number): (CFrame?, Vector3?)
    local p = LinkedRooms.PathBetween(L, i, i + 1)
    if not p then return nil, nil end
    local u = LinkedRooms.SEAL_U
    local x0, x1, z0, z1 = LinkedRooms.PathRect(p, u - 0.2, u + 0.2, -p.W / 2 + 0.3, p.W / 2 - 0.3)
    local h = LinkedRooms.SEAL_H
    return CFrame.new((x0 + x1) / 2, floorY + 0.15 + h / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, h, z1 - z0)
end
-- (2026-10-26 SEAL GATE) room i's gate: the doorway's centre on the floor, facing back into room i (SealGate.Build's cf), + the
-- path's width (the gate's pylons go into the walls either side)
function LinkedRooms.SealFrame(L: any, i: number, floorY: number): (CFrame?, number?)
    local p = LinkedRooms.PathBetween(L, i, i + 1)
    if not p then return nil, nil end
    local u = LinkedRooms.SEAL_U
    local x0, x1, z0, z1 = LinkedRooms.PathRect(p, u, u, 0, 0)
    local at = Vector3.new((x0 + x1) / 2, floorY, (z0 + z1) / 2)
    local back = (p.Axis == "Z") and Vector3.new(0, 0, -1) or Vector3.new(-p.Dir, 0, 0)
    return CFrame.lookAt(at, at + back), p.W
end
-- the floor's seal string from what is left: left[i] = room i's live packs (stragglers / goblins not counted), here[i] = someone is
-- inside room i. lk = the run's linked record (Spawned, Open, SealSeen). "" = nothing sealed.
function LinkedRooms.SealState(lk: any, L: any, left: { [number]: number }, here: { [number]: boolean }, now: number): string
    if not LinkedRooms.SEAL then return "" end
    lk.Open = lk.Open or {}
    lk.SealSeen = lk.SealSeen or {}
    lk.SealTot = lk.SealTot or {} -- (the most seen in the room: the progress bar's whole)
    local out = {}
    for i = 1, L.Main - 1 do
        if not lk.Open[i] then
            local n = left[i] or 0
            lk.SealTot[i] = math.max(lk.SealTot[i] or 0, n)
            if lk.Spawned[i] == true and n == 0 then
                lk.Open[i] = true
            else
                local s = lk.SealSeen[i]
                if not s or s.Left ~= n or not here[i] then
                    lk.SealSeen[i] = { Left = n, At = now }
                elseif lk.Spawned[i] == true and n <= LinkedRooms.SEAL_STUCK_LEFT and now - s.At >= LinkedRooms.SEAL_STUCK_S then
                    lk.Open[i] = true -- (soft-lock guard: a bot stuck where nobody can hit it)
                end
                if not lk.Open[i] then table.insert(out, i .. ":" .. n .. ":" .. lk.SealTot[i]) end
            end
        end
    end
    return table.concat(out, ",")
end
-- "<room>:<left>:<total>,..." -> { [room] = left }, { [room] = total }
function LinkedRooms.SealParse(s: any): ({ [number]: number }, { [number]: number })
    local out, tot = {}, {}
    if type(s) ~= "string" then return out, tot end
    for i, n, t in string.gmatch(s, "(%d+):(%d+):?(%d*)") do
        local k = tonumber(i) :: number
        out[k] = tonumber(n) :: number
        tot[k] = math.max(tonumber(t) or 0, out[k])
    end
    return out, tot
end

return LinkedRooms
