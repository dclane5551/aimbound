--!nocheck
-- ENEMY VARIETY PILOT (2026-11-07; owner: "the enemies also still feel kind of boring to fight and very samey"; contract + numbers
-- docs/ENEMY_VARIETY_2026-11-07.md). The 2026-10-30 ROLES pilot gave the common roster five roles, but 15 of its 23 bots ended up
-- with the SAME verb (a 1-3 round chip volley) and every pack's fodder (~85% of the bots in a room) fires one chip tracer -- so a
-- room asked one question. Path of Exile makes packs feel different by giving each monster FAMILY its own mechanic and building a
-- pack out of one family (the normal monsters share the leader's trick), with supports / raisers / totems that change who you
-- shoot first. This module is that, as data:
--   ROWS        one row per common-roster bot, each its OWN verb (no two rows share a Verb -- ContentCheck). It replaces the bot's
--               BotRoles.ROWS row while the pilot is on (BotRoles.ActiveRow); bots without a row here keep their BotRoles row.
--   LITE        the small "fodder" version of a verb family; a pack's fodder use their LEADER's family (LITE_OF), or -- leaders
--               without a family (biome bots, melee leaders, supports) -- one of PACK_KINDS picked per pack, so two packs in a room
--               differ. Fodder keep their own body, movement, health and damage scale (PacksPilot is untouched).
--   PAIRING     a linked room's leaders are one PRESSURE bot + one PRIORITY bot when both come from the common roster
--               (a support / raiser / counter behind something that pushes you): RollLinkedRoster is wrapped (Install).
-- PoE feel, NOT Destiny AI (no cover, no retreat-to-heal, no flanking); wind-ups flat; every attack still takes an attack slot and
-- rounds / seekers obey EnemyAttacks.SHOT_CAP. Studio A/B: workspace attr DevVarietyOld = true (read at bot creation + roster roll)
-- = the 2026-10-30 rows exactly. BotVerbs.ON = false switches the pilot off everywhere (live too).
--
-- NEW ATTACKS (rows here; BotRoles.ATTACK_ROLE knows them):
--   Seeker  (Gunner)  one slow homing orb: shoot it down (it is an AtkShell) or beat its turn late. Mult, Speed, Turn, Life, Size, Big
--   Beacon  (Gunner)  plants a small shootable beacon; enemies within Reach attack Boost more often while it stands. Reach, Life,
--                     Boost (0-0.5), Fallback (its attack while a beacon of its own stands)
--   Counter (Gunner)  a gold guard bubble for Guard s: hurt it during the guard and it fires straight back (a fast round, Mult, Big);
--                     left alone, it ends the guard with its Fallback volley
--   Channel (Heavy)   plants and channels Windup s; Break x its life dealt during the channel breaks it (stagger 1.5 s), else
--                     Count shells (Mult each, Radius, Flight). PlantAll = it stands through the whole channel
--   Leap    (Rusher)  crouches (Windup), leaps onto your spot (Radius, Flight, Apex), stands winded -- DungeonGenerator dash code
--   Raise   (Caster)  the SERVER raises a fallen fodder near it (RaiseTick: Range, Time, Max, Gap, Break); the beam is the tell;
--                     hurting it for Break x its life during the raise cancels it + staggers it. Fallback = its own attack
-- NEW BURST FIELDS (BotRoles.Burst): Big (a Spike burst hits BotRoles.Spike(Mult)), Low (aimed at your shins: jump it), Lead (forced
--   lead chance), Sound, NoPlant (BotMove: fires on the move), Rate (attack-gap x; model attr AtkRate), Pop (a parting shell on
--   death: { Mult, Radius, Flight })
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Shared = script.Parent
local EA = require(Shared:WaitForChild("EnemyAttacks"))

local BotVerbs = {}
BotVerbs.ON = true
function BotVerbs.Old(): boolean
    return RunService:IsStudio() and Workspace:GetAttribute("DevVarietyOld") == true
end
function BotVerbs.On(): boolean return BotVerbs.ON and not BotVerbs.Old() end

local GOLD = Color3.fromRGB(255, 205, 90)
BotVerbs.GUARD_COLOR, BotVerbs.RAISE_COLOR, BotVerbs.BEACON_COLOR = GOLD, Color3.fromRGB(150, 255, 190), Color3.fromRGB(255, 150, 230)

-- ===== the common roster, one verb each (APPEND a row to give a bot its own verb; Verb must be unique) =====
-- Damage: a chip volley lands ~0.35-0.45 of an attack; a dodgeable spike that a mover avoids about half the time is sized ~1.0-1.3
-- of an attack (Spike = Mult x 2 capped 2.1). Wind-ups = each bot's old one (cadence), except the verbs that ARE their wind-up.
-- UNAVOIDABLE SHARE (owner call 2026-11-07: "skill reduces damage, never removes it" -> a PERFECT dodger takes about HALF what a
-- planted player takes): the pure-dodge verbs (Seeker / Stream / Lance / Skip / Snap) fire their verb every 2nd attack (Every = 2)
-- and their chip fan between (BotRoles.ChipRow); their pack's lite rounds do the same with ONE tracer (ChipShots 1, ChipMult 2 =
-- one fan round's hit). Modelled (tools/sim/enemy_variety.py --split): perfect dodger / planted 45% Brutal, 50% Nightmare on the
-- common roster + fodder (was 21-22% as first built; 64-73% with DevVarietyOld). Knobs: Every, the LITE Mult / ChipMult, PACK_KINDS.
BotVerbs.ROWS = {
    -- PRESSURE (they push you: dodge / move / keep your defences up)
    Runner = { Verb = "Volley", Role = "Gunner", Attack = "Burst", Shots = 3, Windup = 0.75, Tag = "Chip" }, -- (the rank and file: unchanged)
    Tracker = { Verb = "Seeker", Role = "Gunner", Attack = "Seeker", Windup = 0.75, Mult = 0.5, Big = true, Speed = 26, Turn = 55, Life = 3.5, Size = 1.3, Tag = "Spike", Every = 2 },
    Strafer = { Verb = "Stream", Role = "Gunner", Attack = "Burst", Shots = 3, Windup = 0.6, Mult = 1.2, Speed = 40, Gap = 0.32, Size = 0.7, Tag = "Spike", Every = 2 },
    Pasu = { Verb = "Lance", Role = "Gunner", Attack = "Burst", Shots = 1, Windup = 0.8, Mult = 0.55, Big = true, Speed = 30, Size = 1.6, Sound = "ShootHeavy", Tag = "Spike", Every = 2 },
    Skirmisher = { Verb = "Skip shot", Role = "Gunner", Attack = "Burst", Shots = 1, Windup = 0.6, Mult = 0.55, Big = true, Speed = 34, Size = 1.1, Low = true, Sound = "ShootHeavy", Tag = "Spike", Every = 2 },
    Comet = { Verb = "Hunter volley", Role = "Gunner", Attack = "Burst", Shots = 2, Windup = 0.6, Lead = 1, Speed = 70, Tag = "Chip" },
    Zipper = { Verb = "Run-and-gun", Role = "Gunner", Attack = "Burst", Shots = 1, Windup = 0.6, Mult = 0.6, NoPlant = true, Rate = 0.55, Tag = "Chip" },
    Popper = { Verb = "Parting shell", Role = "Gunner", Attack = "Burst", Shots = 2, Windup = 0.6, Tag = "Chip", Pop = { Mult = 0.5, Radius = 4, Flight = 1.1 } },
    Splitter = { Verb = "Split", Role = "Gunner", Attack = "Burst", Shots = 2, Windup = 0.8, Tag = "Chip" }, -- (its verb is the split on death: DungeonRuns)
    Splitling = { Verb = "Dart", Role = "Rusher", Attack = "Dash", Windup = 0.6, Mult = 0.6, Len = 22, Dur = 0.3, Reach = 1.0, Tag = "Spike" },
    Leaper = { Verb = "Leap slam", Role = "Rusher", Attack = "Leap", Windup = 0.7, Mult = 0.65, Radius = 5, Flight = 0.8, Apex = 9, Tag = "Spike" },
    -- PRIORITY (they change who you shoot first)
    Blinker = { Verb = "Snap shot", Role = "Marksman", Attack = "Aimed", Mult = 0.55, Windup = 0.55, Tag = "Spike", Every = 2 },
    Hopper = { Verb = "Beacon", Role = "Gunner", Attack = "Beacon", Windup = 0.8, Reach = 22, Life = 10, Boost = 0.25, Tag = "Chip",
        Fallback = { Attack = "Burst", Shots = 1, Windup = 0.8, Tag = "Chip" } },
    Orbiter = { Verb = "Counter", Role = "Gunner", Attack = "Counter", Windup = 0.75, Guard = 1.5, Mult = 0.6, Big = true, Tag = "Spike",
        Fallback = { Attack = "Burst", Shots = 2, Windup = 0.75, Tag = "Chip" } },
    Seraph = { Verb = "Raise", Role = "Caster", Attack = "Raise", Windup = 0.75, Range = 34, Time = 1.8, Max = 3, Gap = 6, Break = 0.15, Tag = "Chip",
        Fallback = { Attack = "Burst", Shots = 1, Windup = 0.75, Tag = "Chip" } },
    Gunship = { Verb = "Channel", Role = "Heavy", Attack = "Channel", Windup = 1.6, Break = 0.18, Count = 2, Mult = 0.6, Radius = 4.5, Flight = 1.3,
        Rate = 1.25, PlantAll = true, Tag = "Spike" },
}
-- the 2026-10-30 rows that already are their own verb (shared tables: changing them changes the old rows too)
BotVerbs.KEEP = { Drifter = "Shell", Charger = "Dive", Juggernaut = "Slam", Sniper = "Charged shot", Brute = "Swing", Warden = "Ward", Medic = "Heal" }
-- which side of the room pairing a common leader is on
BotVerbs.PRIORITY = { Blinker = true, Hopper = true, Sniper = true, Warden = true, Medic = true, Splitter = true, Seraph = true, Orbiter = true, Gunship = true }
-- the pairing re-picks from these ({ id, first floor it can appear on }, = PickArchetypeBase's floor gates)
BotVerbs.PRIORITY_POOL = { { "Hopper", 2 }, { "Seraph", 2 }, { "Orbiter", 1 }, { "Blinker", 2 }, { "Warden", 1 }, { "Medic", 4 } }
BotVerbs.PRESSURE_POOL = { { "Runner", 1 }, { "Tracker", 1 }, { "Strafer", 1 }, { "Pasu", 1 }, { "Skirmisher", 2 }, { "Leaper", 2 },
    { "Charger", 1 }, { "Brute", 2 }, { "Zipper", 3 } }

-- ===== fodder: the small version of a family's verb =====
-- (damage: a fodder round is already x PacksPilot.DMG; a chip tracer lands ~always for CHIP_HIT_LONE 0.16, a dodgeable lite round
-- is 0.2 and a perfect dodger never takes it -- so the dodge families alternate with one tracer at ChipMult 2 (= 0.32): the chip floor)
BotVerbs.LITE = {
    Volley = false, -- (= BotRoles.FODDER_ROW: one chip tracer)
    Seeker = { Role = "Gunner", Attack = "Seeker", Mult = 0.2, Speed = 24, Turn = 40, Life = 2.6, Size = 1.0, Tag = "Spike", Every = 2, ChipShots = 1, ChipMult = 2 },
    Stream = { Role = "Gunner", Attack = "Burst", Shots = 1, Mult = 0.2, Speed = 40, Size = 0.7, Tag = "Spike", Every = 2, ChipShots = 1, ChipMult = 2 },
    Lance = { Role = "Gunner", Attack = "Burst", Shots = 1, Mult = 0.2, Speed = 30, Size = 1.2, Tag = "Spike", Every = 2, ChipShots = 1, ChipMult = 2 },
    Skip = { Role = "Gunner", Attack = "Burst", Shots = 1, Mult = 0.2, Speed = 34, Size = 0.9, Low = true, Tag = "Spike", Every = 2, ChipShots = 1, ChipMult = 2 },
    Hunter = { Role = "Gunner", Attack = "Burst", Shots = 1, Lead = 1, Speed = 70, Tag = "Chip" },
    RunGun = { Role = "Gunner", Attack = "Burst", Shots = 1, Mult = 0.6, Rate = 0.6, Tag = "Chip" },
    Counter = { Role = "Gunner", Attack = "Counter", Guard = 1.2, Mult = 0.3, Tag = "Spike", Fallback = { Attack = "Burst", Shots = 1, Tag = "Chip" } },
    Snap = { Role = "Marksman", Attack = "Aimed", Mult = 0.1, Windup = 0.55, Tag = "Spike", Every = 2, ChipShots = 1, ChipMult = 2 },
}
BotVerbs.LITE_OF = { Tracker = "Seeker", Strafer = "Stream", Pasu = "Lance", Skirmisher = "Skip", Comet = "Hunter", Zipper = "RunGun",
    Orbiter = "Counter", Blinker = "Snap" }
-- a pack whose leader has no family (a biome bot, a melee / support leader) gets one of these by its pack number -- consecutive packs
-- (a room's) differ. Half chip, half dodgeable (and the dodge kinds alternate with a tracer): the PoE damage model's chip floor stays.
BotVerbs.PACK_KINDS = { "Volley", "Stream", "Hunter", "Lance", "Volley", "Skip", "RunGun", "Seeker", "Counter", "Snap" }

-- ===== bestiary text while the pilot is on (DungeonGenerator.BotLore rows are replaced at Install) =====
BotVerbs.LORE = {
    Runner = { Role = "Gunner: ground strafer", Text = "The rank and file: walks from spot to spot and stops to fire three-round tracer volleys. Its pack fires single tracers.", Tip = "Too fast to dodge: kill it, use cover, lean on your defences." },
    Tracker = { Role = "Gunner: seeker", Text = "Glides at range and launches a slow glowing orb that turns after you. Its pack launches small ones.", Tip = "Shoot the orb down (one hit), or sidestep late: it can't turn sharply." },
    Strafer = { Role = "Gunner: stream", Text = "A fast flyer that fires a stream of three slow rounds, one after another, each at where you are. Its pack fires single slow rounds.", Tip = "Keep moving and every round misses. Standing still eats all three." },
    Pasu = { Role = "Gunner: lancer", Text = "Glides in straight lines, then fires one big, slow, glowing bolt. Its pack fires smaller bolts.", Tip = "Sidestep the bolt at the last moment, then punish the stop." },
    Skirmisher = { Role = "Gunner: skipper", Text = "Fast and fragile on the ground; it rolls a heavy round low along the floor at your feet. Its pack does the same.", Tip = "Jump it (or sidestep). It goes down in a few hits." },
    Comet = { Role = "Gunner: hunter", Text = "Small, very fast and fragile: its two-round volleys always aim where you're GOING. Its pack leads you too. Only on Nightmare and above.", Tip = "Change direction when it fires. Holding one direction gets you hit." },
    Zipper = { Role = "Gunner: run-and-gun", Text = "Zips from spot to spot and fires single rounds WHILE it moves, twice as often as other gunners. Its pack shoots on the move too.", Tip = "It never stops for you: track it, it has little health." },
    Popper = { Role = "Gunner: popcorn", Text = "Pops from spot to spot in high arcs and stands to fire two-round volleys. When it dies it spits one parting shell at you.", Tip = "After the kill, step off the marked spot or shoot the shell down." },
    Splitter = { Role = "Gunner: splitter", Text = "Fires two-round volleys and splits into two darting Splitlings when destroyed.", Tip = "Keep some ammo for the pieces, or kill it where you can see them coming." },
    Splitling = { Role = "Rusher: fragment", Text = "Tiny, fast pieces of a Splitter. Each stops, glows and darts straight through you.", Tip = "Sidestep the dart, then one or two shots each." },
    Leaper = { Role = "Rusher: leaper", Text = "A walker that crouches, then LEAPS onto your spot (the landing is marked) and stands winded where it lands.", Tip = "Step off the mark while it's in the air, then shoot it while it recovers." },
    Blinker = { Role = "Marksman: snapper", Text = "Teleports, then snaps off a quick charged shot (a short glint on its head).", Tip = "Flick to its head during the glint: that cancels the shot and staggers it." },
    Hopper = { Role = "Support: beacon", Text = "Hops in low arcs and plants a small glowing beacon. Every enemy near a beacon attacks a third more often while it stands.", Tip = "Shoot the beacon (one hit) or the Hopper first." },
    Orbiter = { Role = "Gunner: counter", Text = "Works its way round you and raises a gold guard. Hurt it while the guard is up and it fires straight back, hard. Its pack guards too.", Tip = "Switch targets while it guards; shoot it the moment the guard drops." },
    Seraph = { Role = "Support: raiser", Text = "Hangs back behind its allies and RAISES fallen pack-mates (a green beam to the body), up to three times.", Tip = "Kill it first, or hurt it hard during the beam: that stops the raise and staggers it." },
    Gunship = { Role = "Heavy: channeller", Text = "Slow and armoured; it plants and CHANNELS a barrage (a big glow grows on it), then lobs two shells, one at you and one where you're heading.", Tip = "Burst it during the channel: enough damage breaks it and staggers it. Too late? Shoot the shells down." },
}

-- ===== helpers (BotRoles binds its locals here; BotRoles requires this module, not the other way round) =====
local H = nil :: any
function BotVerbs.Bind(h: any) H = h end
local function Spike(m: number): number return H.Spike(m) end
local function Snd(name: string, part: Instance?)
    if not part then return end
    pcall(function() require(Shared:WaitForChild("SoundHelper")).PlayAt(name, part) end)
end

-- the per-machine registry (solo: this client; party: the server): pack leaders by group, live beacons, handles by model
local leadersOf = setmetatable({}, { __mode = "k" }) -- group -> { [pack] = archetype }
local handleOf = setmetatable({}, { __mode = "k" }) -- model -> b
local beacons = {} -- { Rec, Pos, Reach, Group, Boost }

-- called for EVERY role bot right after it is made (BotRoles.StartAura)
function BotVerbs.OnCreate(b: any)
    if not BotVerbs.On() then return end
    local m = b.Model
    handleOf[m] = b
    local row = b.Row
    if not row.IsFodder and b.Group then
        local pack = m:GetAttribute("LinkPack")
        if pack then
            local reg = leadersOf[b.Group]
            if not reg then reg = {}; leadersOf[b.Group] = reg end
            reg[pack] = m:GetAttribute("DroneType")
        end
    end
    if row.Rate then m:SetAttribute("AtkRate", row.Rate) end
    if row.Attack == "Raise" then BotVerbs.WatchRaise(b) end
end

-- a pack's family: its leader's (LITE_OF), else PACK_KINDS by the pack's number (the server computes the same: config.VerbKinds)
function BotVerbs.PackKind(leader: string?, pack: number): string
    return (leader and BotVerbs.LITE_OF[leader]) or BotVerbs.PACK_KINDS[(math.floor(pack) % #BotVerbs.PACK_KINDS) + 1]
end
-- the fodder version this pack's fodder use (nil = the plain tracer); resolved at the first attack (the leader may be made later)
local liteCache = {}
function BotVerbs.FodderLite(b: any): any
    if b.LiteDone then return b.Lite end
    local m = b.Model
    local pack = m:GetAttribute("LinkPack")
    if not pack or not b.Group then b.LiteDone = true return nil end
    local reg = leadersOf[b.Group]
    local lead = reg and reg[pack]
    if not lead then
        b.LiteTries = (b.LiteTries or 0) + 1
        if b.LiteTries < 3 then return nil end -- (try again next attack)
    end
    local kind = BotVerbs.PackKind(lead, pack)
    b.LiteDone = true
    local t = BotVerbs.LITE[kind]
    if not t then return nil end
    local key = kind .. "|" .. tostring(b.Row.Windup) .. "|" .. tostring(b.Row.Mult)
    local lite = liteCache[key]
    if not lite then
        lite = table.clone(t)
        lite.Windup = t.Windup or b.Row.Windup
        lite.IsFodder, lite.Kind = true, kind
        -- (the fodder row's Mult = its archetype's old attack scale; a lite Mult is relative to that)
        lite.Mult = (t.Mult or 1) * (b.Row.Mult or 1)
        if lite.Fallback then lite.Fallback = table.clone(lite.Fallback); lite.Fallback.Windup = lite.Fallback.Windup or lite.Windup end
        liteCache[key] = lite
    end
    b.Lite = lite
    if lite.Rate then m:SetAttribute("AtkRate", lite.Rate) end
    if RunService:IsStudio() then m:SetAttribute("DevVerb", "fodder:" .. kind) end
    return lite
end

-- ===== SEEKER =====
local function Seeker(b: any, row: any, target: BasePart): number
    local wu = row.Windup or 0.75
    local stop = EA.Charge(b.Atk, function() return H.Muzzle(b, target) end, math.max(0.7, b.Radius * 0.6), wu, b.Atk.ShotColor)
    local scaled = EA.WindupFor(b.Atk, wu, row.Mult)
    task.delay(scaled, function()
        stop()
        if not H.Alive(b) or not target.Parent or H.Staggered(b) then return end
        EA.Seeker(b.Atk, H.Muzzle(b, target), { Mult = row.Big and Spike(row.Mult or 1) or (row.Mult or 1), Speed = row.Speed, Turn = row.Turn,
            Life = row.Life, Size = row.Size, Target = target, Tag = "Spike", Sound = "ShootHeavy" })
    end)
    return wu
end

-- ===== BEACON =====
local function Beacon(b: any, row: any, target: BasePart): number
    if b.Beacon and not b.Beacon.Rec.Done then return H.Burst(b, row.Fallback, target) end
    local wu = row.Windup or 0.8
    local stop = EA.Charge(b.Atk, function() return b.PosFn() - Vector3.new(0, b.Radius * 0.9, 0) end, math.max(1, b.Radius * 0.7), wu, BotVerbs.BEACON_COLOR)
    local scaled = EA.WindupFor(b.Atk, wu)
    task.delay(scaled, function()
        stop()
        if not H.Alive(b) or H.Staggered(b) then return end
        local p = b.PosFn()
        local y = EA.GroundY(b.Atk, p)
        local at = Vector3.new(p.X, math.min(p.Y, y + 2.6), p.Z)
        local rec = EA.Beacon(b.Atk, at, { Life = row.Life or 10, Size = 1.1, Color = BotVerbs.BEACON_COLOR, Reach = row.Reach or 22, FloorY = y })
        local e = { Rec = rec, Pos = at, Reach = row.Reach or 22, Group = b.Group, Boost = row.Boost or 0.25 }
        b.Beacon = e
        table.insert(beacons, e)
        Snd("ShieldUp", rec.Part)
    end)
    return wu
end
-- the attack-gap multiplier from a live beacon near this bot (1 = none; one beacon's worth at most)
function BotVerbs.BeaconMult(model: Instance): number
    if #beacons == 0 then return 1 end
    local best = 1
    local pos = nil
    for i = #beacons, 1, -1 do
        local e = beacons[i]
        if e.Rec.Done then table.remove(beacons, i)
        elseif e.Group and e.Group[model] ~= nil then
            if not pos then
                local ok, p = pcall(function() return (model :: Model):GetPivot().Position end)
                if not ok then return 1 end
                pos = p
            end
            if (pos - e.Pos).Magnitude <= e.Reach then best = math.min(best, 1 - e.Boost) end
        end
    end
    return best
end

-- ===== COUNTER =====
local function Counter(b: any, row: any, target: BasePart): number
    local m = b.Model
    local guard = row.Guard or 1.5
    local fb = row.Fallback
    local size = m:GetExtentsSize()
    local d = math.max(size.X, size.Y, size.Z) * 1.1 + 0.8
    local bubble = EA.Part({ Name = "AtkGuard", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), Color = BotVerbs.GUARD_COLOR, Transparency = 0.4, Parent = b.Fx })
    bubble.Material = Enum.Material.ForceField
    bubble.CFrame = CFrame.new(b.PosFn())
    m:SetAttribute("Guarding", true)
    Snd("ShieldUp", m.PrimaryPart)
    local h0 = m:GetAttribute("Health")
    local fired = false
    local conn
    conn = m:GetAttributeChangedSignal("Health"):Connect(function()
        local h = m:GetAttribute("Health")
        if fired or type(h) ~= "number" then return end
        if type(h0) == "number" and h < h0 - 0.01 and H.Alive(b) and target.Parent and not H.Staggered(b) then
            fired = true
            -- the answer: a fast hard round straight back (no fan, no dodge window: the guard was the warning)
            local from = H.Muzzle(b, target)
            EA.Shot(b.Atk, from, H.Chest(target), { Mult = row.Big and Spike(row.Mult or 0.6) or (row.Mult or 0.6), Speed = EA.CHIP_SPEED, Size = 0.85,
                Target = target, Tag = "Spike", Sound = "ShootSniper" })
            m:SetAttribute("Counters", (m:GetAttribute("Counters") or 0) + 1) -- (play-test counter)
        end
        h0 = h
    end)
    task.spawn(function()
        local t0 = os.clock()
        while os.clock() - t0 < guard * EA.REACT and not fired and H.Alive(b) and bubble.Parent do
            bubble.CFrame = CFrame.new(b.PosFn())
            RunService.Heartbeat:Wait()
        end
        conn:Disconnect()
        if bubble.Parent then bubble:Destroy() end
        if m.Parent then m:SetAttribute("Guarding", nil) end
        if not fired and H.Alive(b) and target.Parent and not H.Staggered(b) and fb then H.Burst(b, fb, target) end
    end)
    return guard * EA.REACT + ((fb and fb.Windup) or 0.75)
end

-- ===== CHANNEL =====
local function Channel(b: any, row: any, target: BasePart): number
    local m, atk = b.Model, b.Atk
    local wu = row.Windup or 1.6
    local stop = EA.Charge(atk, function() return b.PosFn() + Vector3.new(0, b.Radius * 1.2, 0) end, math.max(2.2, b.Radius * 1.5), wu, atk.ShotColor)
    local scaled = EA.WindupFor(atk, wu, 1.4) -- (a big spike: HEAVY_MIN)
    local h0, mh = m:GetAttribute("Health"), m:GetAttribute("MaxHealth")
    local broke = false
    local conn = m:GetAttributeChangedSignal("Health"):Connect(function()
        local h = m:GetAttribute("Health")
        if broke or type(h) ~= "number" or type(h0) ~= "number" or type(mh) ~= "number" or mh <= 0 then return end
        if h0 - h >= (row.Break or 0.18) * mh and H.Alive(b) then
            broke = true
            stop()
            EA.Stagger(m, 1.5, b.Fx)
            m:SetAttribute("Breaks", (m:GetAttribute("Breaks") or 0) + 1) -- (play-test counter)
            Snd("ShieldDown", m.PrimaryPart)
        end
    end)
    task.delay(scaled, function()
        conn:Disconnect()
        stop()
        if broke or not H.Alive(b) or not target.Parent or H.Staggered(b) then return end
        local n = math.max(1, row.Count or 2)
        local flight = row.Flight or 1.3
        for i = 1, n do
            local at = target.Position
            if i == 2 then
                local v = target.AssemblyLinearVelocity
                local ahead = Vector3.new(v.X, 0, v.Z) * flight * EA.REACT
                if ahead.Magnitude > 10 then ahead = ahead.Unit * 10 end
                if ahead.Magnitude < 4 then ahead = H.Toward(b, target):Cross(Vector3.yAxis) * 6 end
                at += ahead
            end
            EA.Shell(atk, b.PosFn() + Vector3.new(0, b.Radius * 0.9, 0), at, flight, { Mult = Spike(row.Mult or 0.6), Radius = row.Radius or 4.5, Target = target,
                Color = atk.ShotColor, Sound = "AreaStrike", Tag = "Spike" })
            if i == 1 then Snd("ShootHeavy", m.PrimaryPart) end
            if i < n then task.wait(0.25) end
        end
    end)
    return wu
end

-- ===== LEAP (DungeonGenerator's dash code moves the body: BotRoles.DashPlan -> pl.Leap, BotVerbs.LeapStart at the release) =====
function BotVerbs.LeapPlan(b: any, target: BasePart): any
    local row = b.Row
    return { Radius = row.Radius or 5, Flight = row.Flight or 0.8, Apex = row.Apex or 9, Mult = Spike(row.Mult or 0.65), Target = target, Max = 30 }
end
-- the wind-up is over: lock the landing on where you are NOW (at most Max studs), mark it, return (landing, flight s)
function BotVerbs.LeapStart(b: any, lp: any, from: Vector3): (Vector3, number)
    local t = lp.Target
    local to = (t and t.Parent) and t.Position or from
    local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
    if flat.Magnitude > lp.Max then flat = flat.Unit * lp.Max end
    local land = Vector3.new(from.X + flat.X, from.Y, from.Z + flat.Z)
    local dur = EA.WindupFor(b.Atk, lp.Flight, lp.Mult)
    EA.Circle(b.Atk, land, lp.Radius, lp.Flight, { Mult = lp.Mult, Sound = "Melee" })
    Snd("Dash", b.Model.PrimaryPart)
    return land, dur
end

-- ===== RAISE: the tell (the SERVER decides: RaiseTick) =====
function BotVerbs.WatchRaise(b: any)
    local m = b.Model
    local beam, glow = nil, nil
    local function Clear()
        if beam then beam:Destroy(); beam = nil end
        if glow then glow:Destroy(); glow = nil end
    end
    m:GetAttributeChangedSignal("RaiseAt"):Connect(function()
        local at, pos = m:GetAttribute("RaiseAt"), m:GetAttribute("RaisePos")
        Clear()
        if type(at) ~= "number" or typeof(pos) ~= "Vector3" then return end
        local col = BotVerbs.RAISE_COLOR
        beam = EA.Part({ Name = "AtkRaise", Size = Vector3.new(0.18, 0.18, 1), Color = col, Transparency = 0.35, Parent = b.Fx })
        glow = EA.Part({ Name = "AtkRaiseMark", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.2, 1.2), Color = col, Transparency = 0.5, Parent = b.Fx })
        Snd("EliteAbility", m.PrimaryPart)
        local myBeam = beam
        task.spawn(function()
            while myBeam.Parent and m.Parent and m:GetAttribute("RaiseAt") == at and m:GetAttribute("Dead") ~= true and Workspace:GetServerTimeNow() < at + 0.3 do
                local a = b.PosFn()
                local len = math.max(0.2, (pos - a).Magnitude)
                myBeam.Size = Vector3.new(0.18, 0.18, len)
                myBeam.CFrame = CFrame.lookAt((a + pos) / 2, pos)
                local k = math.clamp(1 - (at - Workspace:GetServerTimeNow()) / 2, 0, 1)
                if glow then glow.Size = Vector3.new(2 + 3 * k, 1.2 + k, 1.2 + k); glow.CFrame = CFrame.new(pos + Vector3.new(0, 1 + k, 0)) * CFrame.Angles(0, 0, math.rad(90)) end
                RunService.Heartbeat:Wait()
            end
            if beam == myBeam then Clear() end
        end)
    end)
end

-- the server: a dead fodder becomes a corpse a raiser can use (store = the run table)
BotVerbs.CORPSE_LIFE = 25
function BotVerbs.NoteCorpse(store: any, m: Instance, pos: Vector3?)
    if not BotVerbs.On() or not pos or not m:GetAttribute("Fodder") then return end
    store.VerbCorpses = store.VerbCorpses or {}
    local list = store.VerbCorpses
    if #list > 40 then table.remove(list, 1) end
    table.insert(list, { Pos = pos, Arch = m:GetAttribute("Archetype") or m:GetAttribute("DroneType") or "Runner", T = os.clock(), F = store.Folder,
        LinkRoom = m:GetAttribute("LinkRoom"), LinkFloor = m:GetAttribute("LinkFloor"), Uncounted = m:GetAttribute("Uncounted") })
end
-- the server, every ~0.5 s: start / finish / break raises. ad = { Store (the run table), List () -> { Instance }, PosOf (m) -> Vector3?,
-- Spawn (entry, raiser) -> Instance? (also adds it to the floor's count) }
function BotVerbs.RaiseTick(ad: any, now: number)
    if not BotVerbs.On() then return end
    local store = ad.Store
    local corpses = store.VerbCorpses
    local srv = Workspace:GetServerTimeNow()
    for _, m in ipairs(ad.List()) do
        local arch = m:GetAttribute("Archetype") or m:GetAttribute("DroneType")
        local row = arch and BotVerbs.ROWS[arch]
        if row and row.Attack == "Raise" and not m:GetAttribute("Dead") and not m:GetAttribute("Fodder")
            and (m:GetAttribute("LinkPack") == nil or m:GetAttribute("Awake")) then
            local at = m:GetAttribute("RaiseAt")
            local hp, mh = m:GetAttribute("Health"), m:GetAttribute("MaxHealth")
            if type(at) == "number" then
                local h0 = m:GetAttribute("RaiseHp")
                if type(hp) == "number" and type(h0) == "number" and type(mh) == "number" and h0 - hp >= (row.Break or 0.15) * mh then
                    -- hurt hard during the raise: it fails and the raiser reels
                    m:SetAttribute("RaiseAt", nil); m:SetAttribute("RaisePos", nil)
                    m:SetAttribute("StaggerUntil", srv + 1.2)
                    m:SetAttribute("RaiseBreaks", (m:GetAttribute("RaiseBreaks") or 0) + 1)
                elseif srv >= at then
                    local pos = m:GetAttribute("RaisePos")
                    local c = m:GetAttribute("RaiseArch")
                    m:SetAttribute("RaiseAt", nil); m:SetAttribute("RaisePos", nil)
                    if typeof(pos) == "Vector3" then
                        local sp = ad.Spawn({ Kind = "Bot", Archetype = c or "Runner", Fodder = true, IsSummon = true,
                            LinkRoom = m:GetAttribute("LinkRoom"), LinkPack = m:GetAttribute("LinkPack"), LinkFloor = m:GetAttribute("LinkFloor"),
                            Counted = not m:GetAttribute("Uncounted"), Pos = pos }, m)
                        if sp then
                            sp:SetAttribute("Awake", true)
                            sp:SetAttribute("Raised", true)
                            m:SetAttribute("Raises", (m:GetAttribute("Raises") or 0) + 1)
                        end
                    end
                    m:SetAttribute("RaiseNext", now + (row.Gap or 6))
                end
            elseif corpses and #corpses > 0 and (m:GetAttribute("Raises") or 0) < (row.Max or 3) and now >= (m:GetAttribute("RaiseNext") or 0) then
                local st = m:GetAttribute("StaggerUntil")
                local me = ad.PosOf(m)
                if me and not (type(st) == "number" and st > srv) then
                    local best, bi, bd = nil, nil, (row.Range or 34)
                    for i = #corpses, 1, -1 do
                        local c = corpses[i]
                        if now - c.T > BotVerbs.CORPSE_LIFE or c.F ~= store.Folder then table.remove(corpses, i) -- (old / another floor's)
                        else
                            local d = (c.Pos - me).Magnitude
                            if d <= bd and c.LinkRoom == m:GetAttribute("LinkRoom") then best, bi, bd = c, i, d end
                        end
                    end
                    if best then
                        table.remove(corpses, bi)
                        m:SetAttribute("RaiseHp", hp)
                        m:SetAttribute("RaiseArch", best.Arch)
                        m:SetAttribute("RaisePos", best.Pos)
                        m:SetAttribute("RaiseAt", srv + (row.Time or 1.8) * EA.REACT)
                    end
                end
            end
        end
    end
end

-- ===== the bot's death (BotRoles.AllyDown, every real kill): a Popper's parting shell =====
function BotVerbs.OnDeath(dead: Instance, pos: Vector3)
    local b = handleOf[dead]
    if not b then return end
    handleOf[dead] = nil
    local pop = b.Row and b.Row.Pop
    if not pop then return end
    local atk = b.Atk
    local ctx = EA.Context({ Geo = atk.Geo, Fx = b.Fx, Windup = atk.Windup, Targets = atk.Targets, Hit = atk.Hit, ShotColor = atk.ShotColor,
        TierSpeed = atk.TierSpeed })
    -- the nearest player it was fighting
    local best, bd = nil, 70
    for _, t in ipairs(ctx.Targets() or {}) do
        local r = t.Character and t.Character:FindFirstChild("HumanoidRootPart")
        if r and (r.Position - pos).Magnitude < bd then best, bd = r, (r.Position - pos).Magnitude end
    end
    if not best then return end
    EA.Shell(ctx, pos + Vector3.new(0, 1, 0), best.Position, pop.Flight or 1.1, { Mult = Spike(pop.Mult or 0.5), Radius = pop.Radius or 4, Target = best,
        Color = atk.ShotColor, Sound = "AreaStrike", Tag = "Spike", Size = 1.3 })
end

-- ===== attack dispatch (BotRoles.Ranged) + rounds in the air (EnemyAttacks.ShotRoom) + shootable claims (DungeonRuns.ShellClaim) =====
BotVerbs.ATTACKS = { Seeker = Seeker, Beacon = Beacon, Counter = Counter, Channel = Channel,
    Raise = function(b, row, target)
        local at = b.Model:GetAttribute("RaiseAt")
        if type(at) == "number" and at > Workspace:GetServerTimeNow() then return 0.5 end -- (busy raising)
        return H.Burst(b, row.Fallback, target)
    end }
BotVerbs.ATTACK_ROLE = { Seeker = "Gunner", Beacon = "Gunner", Counter = "Gunner", Channel = "Heavy", Leap = "Rusher", Raise = "Caster" }
function BotVerbs.Rounds(row: any): number?
    local a = row.Attack
    if a == "Seeker" then return 1 end
    if a == "Channel" then return row.Count or 2 end
    if a == "Counter" then return 1 + ((row.Fallback and row.Fallback.Shots) or 1) end
    if a == "Beacon" or a == "Raise" then return (row.Fallback and row.Fallback.Shots) or 1 end
    if a == "Leap" then return 0 end
    return nil
end
-- shootable things this row puts in the air a cycle (a solo shell claim's budget), 0 = none
function BotVerbs.Shootable(row: any): number
    local a = row and row.Attack
    if a == "Shell" or a == "Channel" then return row.Count or 1 end
    if a == "Seeker" or a == "Beacon" then return 1 end
    if row and row.Pop then return 1 end
    return 0
end

-- ===== the roster: room PAIRING (server) =====
local function PoolPick(pool: any, floor: number, avoid: { [string]: boolean }): string?
    local ok = {}
    for _, e in ipairs(pool) do if floor >= e[2] and not avoid[e[1]] then table.insert(ok, e[1]) end end
    return (#ok > 0) and ok[math.random(1, #ok)] or nil
end
function BotVerbs.ComposeRoster(roster: { any }, config: any, DG: any)
    if not BotVerbs.On() or DG.ForceArchetypes then return end
    local rooms = {}
    for _, e in ipairs(roster) do
        if e.Kind == "Bot" and not e.Fodder and not e.Horde and not e.LinkPath and e.LinkRoom then
            rooms[e.LinkRoom] = rooms[e.LinkRoom] or {}
            table.insert(rooms[e.LinkRoom], e)
        end
    end
    local floor = config.FloorNumber or 1
    local swaps = 0
    for _, leads in pairs(rooms) do
        if #leads >= 2 then
            local seen, pri, pre, common = {}, 0, 0, {}
            for _, e in ipairs(leads) do
                seen[e.Archetype] = true
                if BotVerbs.ROWS[e.Archetype] or BotVerbs.KEEP[e.Archetype] then
                    table.insert(common, e)
                    if BotVerbs.PRIORITY[e.Archetype] then pri += 1 else pre += 1 end
                end
            end
            -- every common leader of the room on one side -> the last one swaps sides (biome leaders are left alone)
            if #common >= 2 and (pri == 0 or pre == 0) then
                local e = common[#common]
                local new = PoolPick((pri == 0) and BotVerbs.PRIORITY_POOL or BotVerbs.PRESSURE_POOL, floor, seen)
                if new then
                    e.Archetype = new
                    e.Pos = Vector3.new(e.Pos.X, DG.IsGroundArchetype(new) and 5 or math.random(10, 18), e.Pos.Z)
                    swaps += 1
                end
            end
        end
    end
    -- every pack's family (DungeonRuns.ShellClaim budgets a Seeker pack's fodder orbs; Studio: DevVarietyKinds)
    local kinds, leaders = {}, {}
    for _, e in ipairs(roster) do if e.Kind == "Bot" and not e.Fodder and e.LinkPack then leaders[e.LinkPack] = e.Archetype end end
    local tally = {}
    for _, e in ipairs(roster) do
        if e.Kind == "Bot" and e.Fodder and e.LinkPack and not kinds[e.LinkPack] then
            local k = BotVerbs.PackKind(leaders[e.LinkPack], e.LinkPack)
            kinds[e.LinkPack] = k
            tally[k] = (tally[k] or 0) + 1
        end
    end
    config.VerbKinds = kinds
    if RunService:IsStudio() then
        Workspace:SetAttribute("DevVarietySwaps", swaps)
        local parts = {}
        for k, n in pairs(tally) do table.insert(parts, k .. "=" .. n) end
        table.sort(parts)
        Workspace:SetAttribute("DevVarietyKinds", table.concat(parts, ","))
    end
end

-- DungeonGenerator calls this once at load: the roster wrap + the bestiary text
function BotVerbs.Install(DG: any)
    if not BotVerbs.ON then return end
    local roll = DG.RollLinkedRoster
    DG.RollLinkedRoster = function(config)
        local r = roll(config)
        local ok, err = pcall(BotVerbs.ComposeRoster, r, config, DG)
        if not ok then warn("[BotVerbs] " .. tostring(err)) end
        return r
    end
    for id, l in pairs(BotVerbs.LORE) do if DG.BotLore then DG.BotLore[id] = l end end
end

return BotVerbs
