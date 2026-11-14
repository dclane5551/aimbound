--!nocheck
-- BOT ROLES (ENEMY ATTACKS PILOT, 2026-10-30; owner: "The bot attacks kind of just all feel the same and very boring";
-- contract docs/ENEMY_ATTACKS_2026-10-30.md). Every regular bot attack used to be a red floor shape at your spot -- the answer
-- was always "step out of the red", with your eyes on the floor in an aim game. Now each bot has a ROLE, and each role asks a
-- different answer (Path of Exile-style; NOT Destiny-style AI: no cover, flanking, retreating -- the owner rejected those):
--   Rusher    a wind-up on its BODY, then a swing / dive at close range; nothing in the air  -> kill it first or sidestep
--   Gunner    a fast VOLLEY of tracer rounds in a small fan (chip: about one lands)         -> cover, range, kill it, defences
--   Marksman  a glint + charge on its body, then one hard shot                             -> a weak-spot hit during the charge
--                                                                                             CANCELS it and staggers it
--   Heavy     a slow shell you can SHOOT DOWN (landing marked), or the old floor slam      -> dodge / shoot the shell
--   Caster    wards an ally (half damage, bubble + tether) or lays a zone / heals          -> kill it first
-- Movement patterns are untouched. Damage per attack and the attack rate are each bot's old numbers (the TOTAL of a burst =
-- the old hit). Every attack still takes an attack slot (EnemyAttacks.TakeSlot) and rounds obey EnemyAttacks.SHOT_CAP.
-- A bot WITHOUT a row keeps its old attack (the other biomes, until they're converted). Studio A/B: workspace attr
-- DevAttacksOld = true -> every bot uses the old attacks.
--
-- ADD / CONVERT A BOT (append a row; ContentCheck checks every row): ROWS[<archetype id>] = { Role = <role>, Attack = <attack>, ... }
--   Burst  (Gunner)   Shots 1-3, Mult (total, default 1), Windup (0.6), Gap (0.14 s between rounds), Size (0.75), Speed
--   Aimed  (Marksman) Mult (1), Windup (1.0), Speed (EA.SNIPE_SPEED), Size (0.9)
--   Shell  (Heavy)    Count 1-2, Mult (each), Radius (5), Flight (1.2 s), Windup (0.8), Pool = { R, Time, Mult } (a burning pool)
--   Slam   (Heavy)    Keep = true: the bot's old floor slam (melee heavies)
--   Swing  (Rusher)   Range (+ its body radius), Arc (half angle, deg), Windup, Mult -- a MELEE bot (A.Melee)
--   Dash   (Rusher)   Windup, Mult, Len (max studs), Dur (s), Reach (+ radius) -- melee or ranged bots
--   Ward   (Caster)   Range, Time, Windup; Fallback = a Burst / Pool / Zone row used when no ally needs a ward
--   Zone / Pool (Caster) Radius, Windup, Time, Mult (per tick)
-- (POE DAMAGE MODEL 2026-10-30; contract "POE DAMAGE MODEL ROUND") every row (and a Fallback) carries
--   Tag      "Chip" (frequent small hits, hard to avoid fully: Plating / resistances / Health handle them) or "Spike" (rare, big,
--            telegraphed: you dodge them; Health decides whether a missed one kills you). ContentCheck requires it.
--   Contact  (Rushers) { Reach (studs past its body), Mult, Gap (s) }: a short fast JAB once it is on you (EA.Jab; chip, evadable)
--   Aura     (Casters) { R (studs past its body), Mult (per tick), Tick (0.5) }: degen ground under it while it fights (EA.Aura;
--            chip, NOT evadable, the bot's own damage type)
--   Every    (Heavies / Marksmen) n: the SPIKE (shell / charged shot) is only every n-th attack; the others are a chip FAN of
--            ChipShots (2) rounds (Mult = ChipMult, default 1 = its old attack). Spikes are rare, big and told; chip is the steady part.
-- A chip burst is a FAN (EA.FAN_W) aimed where you are -- or, with the tier's Lead chance, where you'll BE -- at EA.CHIP_SPEED; every role elite
-- drops a short death burst (BotRoles.DEATH_BURST; chip, not evadable, the bot's own type) unless it is Volatile (its own blast).
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Shared = script.Parent
local EA = require(Shared:WaitForChild("EnemyAttacks"))
-- (ENEMY VARIETY 2026-11-07) the pilot's own rows + verbs (AimRngShared/BotVerbs; it never requires this module)
local Verbs = require(Shared:WaitForChild("BotVerbs"))

local BotRoles = {}
BotRoles.Verbs = Verbs

BotRoles.ORDER = { "Rusher", "Gunner", "Marksman", "Heavy", "Caster" }
BotRoles.ROLES = {
    Rusher = { Name = "Rusher", Answer = "Kill it first, or sidestep the swing." },
    Gunner = { Name = "Gunner", Answer = "Its volleys are too fast to dodge: use cover and range, kill it first, and lean on your defences." },
    Marksman = { Name = "Marksman", Answer = "Hit its weak spot while it charges to cancel the shot (it staggers)." },
    Heavy = { Name = "Heavy", Answer = "Step off the marked spot, or shoot the shell down in the air." },
    Caster = { Name = "Caster", Answer = "Kill it first: it protects the others." },
}
-- which role each attack belongs to (ContentCheck: a row's Attack must fit its Role)
BotRoles.ATTACK_ROLE = { Burst = "Gunner", Aimed = "Marksman", Shell = "Heavy", Slam = "Heavy", Swing = "Rusher", Dash = "Rusher",
    Ward = "Caster", Zone = "Caster", Pool = "Caster" }
for k, v in pairs(Verbs.ATTACK_ROLE) do BotRoles.ATTACK_ROLE[k] = v end -- (ENEMY VARIETY: Seeker / Beacon / Counter / Channel / Leap / Raise)

BotRoles.ROWS = {
    -- WIND-UPS = each bot's OLD attack's wind-up (review M: cadence must not drift): Strip 0.75, Quick 0.6, Big / Snipe 1.0, a plain
    -- circle / Barrage 0.8, Flare 0.8, Fissure 0.7, Scorch 0.75, Crucible 1.1, Carom 0.75, Charger 0.8, Brute 0.5
    -- TAGS (POE DAMAGE MODEL): gunner bursts / pools / auras / jabs = Chip; marksmen, shells, dives, swings, slams = Spike
    -- the common roster (every biome)
    Tracker = { Role = "Gunner", Attack = "Burst", Shots = 3, Windup = 0.75, Tag = "Chip" },
    Strafer = { Role = "Gunner", Attack = "Burst", Shots = 3, Windup = 0.6, Tag = "Chip" },
    Drifter = { Role = "Heavy", Attack = "Shell", Count = 1, Mult = 1, Radius = 5.5, Flight = 1.2, Windup = 1.0, Tag = "Spike", Every = 2 },
    Blinker = { Role = "Marksman", Attack = "Aimed", Mult = 1, Windup = 0.8, Tag = "Spike", Every = 2 },
    Hopper = { Role = "Gunner", Attack = "Burst", Shots = 3, Windup = 0.8, Tag = "Chip" },
    Charger = { Role = "Rusher", Attack = "Dash", Windup = 0.8, Mult = 1.35, Len = 34, Dur = 0.3, Reach = 1.6, Tag = "Spike",
        Contact = { Reach = 2.6, Mult = 0.3, Gap = 1.2 } },
    Juggernaut = { Role = "Heavy", Attack = "Slam", Keep = true, Tag = "Spike" },
    Sniper = { Role = "Marksman", Attack = "Aimed", Mult = 1.6, Windup = 1.0, Tag = "Spike", Every = 2 },
    Runner = { Role = "Gunner", Attack = "Burst", Shots = 3, Windup = 0.75, Tag = "Chip" },
    Skirmisher = { Role = "Gunner", Attack = "Burst", Shots = 2, Windup = 0.6, Tag = "Chip" },
    Brute = { Role = "Rusher", Attack = "Swing", Range = 10, Arc = 55, Windup = 0.5, Mult = 1.35, Tag = "Spike",
        Contact = { Reach = 2.6, Mult = 0.3, Gap = 1.2 } },
    Warden = { Role = "Caster", Attack = "Ward", Range = 34, Time = 4, Windup = 0.75, Tag = "Chip", Aura = { R = 7, Mult = 0.08 },
        Fallback = { Attack = "Burst", Shots = 1, Windup = 0.75, Tag = "Chip" } },
    -- (its heals: DungeonRuns, unchanged; the pool's whole life <= the old single hit: 5 ticks x 0.2)
    Medic = { Role = "Caster", Attack = "Zone", Radius = 5, Windup = 0.6, Time = 2.5, Mult = 0.2, Tag = "Chip", Aura = { R = 6, Mult = 0.08 } },
    Splitter = { Role = "Gunner", Attack = "Burst", Shots = 3, Windup = 0.8, Tag = "Chip" },
    Splitling = { Role = "Gunner", Attack = "Burst", Shots = 1, Windup = 0.6, Tag = "Chip" },
    Popper = { Role = "Gunner", Attack = "Burst", Shots = 2, Windup = 0.6, Tag = "Chip" },
    Pasu = { Role = "Gunner", Attack = "Burst", Shots = 3, Windup = 0.8, Tag = "Chip" },
    Seraph = { Role = "Gunner", Attack = "Burst", Shots = 3, Windup = 0.75, Tag = "Chip" },
    Zipper = { Role = "Gunner", Attack = "Burst", Shots = 2, Windup = 0.6, Tag = "Chip" },
    Orbiter = { Role = "Gunner", Attack = "Burst", Shots = 3, Windup = 0.75, Tag = "Chip" },
    Leaper = { Role = "Gunner", Attack = "Burst", Shots = 3, Windup = 0.8, Tag = "Chip" },
    Gunship = { Role = "Heavy", Attack = "Shell", Count = 2, Mult = 0.8, Radius = 4.5, Flight = 1.3, Windup = 0.8, Tag = "Spike", Every = 2 },
    Comet = { Role = "Gunner", Attack = "Burst", Shots = 2, Windup = 0.6, Tag = "Chip" },
    -- MOLTEN (Fire)
    Cinder = { Role = "Gunner", Attack = "Burst", Shots = 3, Windup = 0.8, Tag = "Chip" },
    -- (the shell = the old Fissure's one burst on you, x0.6 = a spike; its pool 0.2 a tick = chip -- was 0.9 + 0.3 before review M)
    Magmaw = { Role = "Heavy", Attack = "Shell", Count = 1, Mult = 0.6, Radius = 5, Flight = 1.25, Windup = 0.7, Tag = "Spike", Every = 2, Pool = { R = 4, Time = 2.4, Mult = 0.2 } },
    Ashwing = { Role = "Marksman", Attack = "Aimed", Mult = 0.9, Windup = 0.75, Tag = "Spike", Every = 2 },
    Smelter = { Role = "Caster", Attack = "Ward", Range = 34, Time = 4, Windup = 1.1, Color = Color3.fromRGB(255, 170, 80), Tag = "Chip",
        Aura = { R = 7.5, Mult = 0.1 }, Fallback = { Attack = "Pool", Radius = 7.5, Windup = 1.1, Time = 4.5, Mult = 0.35, Tag = "Chip" } },
    Slagroller = { Role = "Rusher", Attack = "Dash", Windup = 0.75, Mult = 1.2, Len = 30, Dur = 0.5, Reach = 1.4, Tag = "Spike",
        Contact = { Reach = 2.4, Mult = 0.25, Gap = 1.3 } },
}
-- pack FODDER (PacksPilot.FODDER: plain movers in rings of 4-10) fire ONE round -- the smallest tell (owner's clutter worry)
BotRoles.FODDER_ROW = { Role = "Gunner", Attack = "Burst", Shots = 1, Tag = "Chip" }
-- (review M) a fodder round keeps its archetype's OLD wind-up + damage: one row per archetype, built from FODDER_ROW
local fodderRows = {}
function BotRoles.FodderRow(archetype: string, row: any): any
    local f = fodderRows[archetype]
    if not f then
        f = table.clone(BotRoles.FODDER_ROW)
        f.Windup = row.Windup
        f.Mult = (row.Attack == "Shell" and (row.Mult or 1) * (row.Count or 1)) or row.Mult
        f.IsFodder = true -- (ENEMY VARIETY: its pack's family verb replaces it at the first attack -- BotVerbs.FodderLite)
        fodderRows[archetype] = f
    end
    return f
end
BotRoles.WARD_COLOR = Color3.fromRGB(120, 200, 255)
-- (POE DAMAGE MODEL) a SPIKE (shell, charged shot, dive, swing) hits SPIKE_MULT x the row's Mult: spikes come half as often now
-- (Every 2 on heavies / marksmen), so each one is bigger -- a missed one is what your Health has to survive. The wind-up timing
-- still reads the row's own Mult (cadence unchanged). SPIKE_CAP: the server caps a solo hit at 2.2 x the bot's attack.
BotRoles.SPIKE_MULT, BotRoles.SPIKE_CAP = 2.0, 2.1
function BotRoles.Spike(mult: number): number return math.min(mult * BotRoles.SPIKE_MULT, BotRoles.SPIKE_CAP) end

-- the row a bot uses, or nil = its old attack (no row, or DevAttacksOld in Studio)
function BotRoles.Old(): boolean
    return RunService:IsStudio() and Workspace:GetAttribute("DevAttacksOld") == true
end
-- (ENEMY VARIETY 2026-11-07) the row this archetype uses NOW: the pilot's BotVerbs row while it is on, else its BotRoles row
function BotRoles.ActiveRow(archetype: string?): any
    if not archetype or BotRoles.Old() then return nil end
    if Verbs.On() then
        local v = Verbs.ROWS[archetype]
        if v then return v end
    end
    return BotRoles.ROWS[archetype]
end
function BotRoles.RowFor(archetype: string?, fodder: boolean?): any
    if BotRoles.Old() then return nil end
    local row = BotRoles.ActiveRow(archetype)
    if not row then return nil end
    -- (a fodder round keeps its archetype's OLD cadence + damage: built from the BotRoles row, never the pilot's)
    if fodder and (row.Role == "Gunner" or row.Role == "Heavy") and not row.Keep then return BotRoles.FodderRow(archetype :: string, BotRoles.ROWS[archetype :: string] or row) end
    return row
end

-- ===== helpers on the bot handle b (built once per bot in DungeonGenerator.CreateBot) =====
-- b = { Row, Model, Atk (EnemyAttacks ctx), PosFn() -> body centre, Radius, Head (part), Group ({ [model] = pos }), Fx, SetTaken(model, v),
--       Tier (EA.TierScale: Speed / Lead / Spread), AreaHit (fn(player, mult): a hit in the BIOME's damage type -- auras, caster
--       pools, the death burst) }
local function Toward(b: any, target: BasePart): Vector3
    local p = b.PosFn()
    local d = target.Position - p
    return d.Magnitude > 0.1 and d.Unit or Vector3.zAxis
end
local function Muzzle(b: any, target: BasePart): Vector3
    return b.PosFn() + Toward(b, target) * (b.Radius + 0.4)
end
local function HeadFront(b: any, target: BasePart): Vector3
    local h = b.Head
    if h and h.Parent then return h.Position + Toward(b, target) * (h.Size.X * 0.55 + 0.2) end
    return Muzzle(b, target)
end
local function Chest(target: BasePart): Vector3 return target.Position + Vector3.new(0, 0.4, 0) end
local function Alive(b: any): boolean return b.Atk.Alive() end
-- (review K) a stagger that lands during the wind-up stops the attack at its release
local function Staggered(b: any): boolean return EA.Staggered(b.Model) end

-- rounds an attack puts in the air (EnemyAttacks.ShotRoom checks it before the slot is taken)
function BotRoles.Rounds(row: any): number
    local a = row.Attack
    if a == "Burst" then return row.Shots or 3 end
    if a == "Aimed" then return 1 end
    if a == "Shell" then return row.Count or 1 end
    if a == "Ward" then return (row.Fallback and row.Fallback.Attack == "Burst") and (row.Fallback.Shots or 1) or 0 end
    return 0
end
local rounds0 = BotRoles.Rounds
function BotRoles.Rounds(row: any): number
    local v = Verbs.Rounds(row)
    if v then return row.Every and math.max(v, row.ChipShots or 2) or v end
    local n = rounds0(row)
    if row.Every then n = math.max(n, row.ChipShots or 2) end -- (POE DAMAGE MODEL: its chip fan)
    return n
end
-- (POE DAMAGE MODEL) the chip fan a spike row fires between its spikes (one cached row per spike row)
local chipRows = setmetatable({}, { __mode = "k" })
function BotRoles.ChipRow(row: any): any
    local c = chipRows[row]
    if not c then
        c = { Role = "Gunner", Attack = "Burst", Shots = row.ChipShots or 2, Windup = row.Windup, Mult = row.ChipMult or 1, Tag = "Chip" }
        chipRows[row] = c
    end
    return c
end
function BotRoles.Ready(b: any, target: BasePart): boolean
    return EA.ShotRoom(target, BotRoles.Rounds(b.Row))
end

-- (POE DAMAGE MODEL) a CHIP burst is a FAN: one roll per burst decides its aim point -- where you ARE, or (the tier's Lead chance)
-- where you'll BE if you keep going -- and round i sits at FAN_OFF[n][i] x EA.FAN_W studs across the line of fire (+ the tier's
-- small Spread cone). The band is one unbroken ~6 studs: standing in it, ONE round lands; strafing on through a led fan, one lands;
-- changing direction beats a led fan, holding one direction does not. Spike bursts (none today) keep plain aim.
local FAN_OFF = { { 0 }, { 0, 1 }, { 0, 1, -1 } }
local function RoundSpeed(row: any): number? return row.Speed or ((row.Tag ~= "Spike") and EA.CHIP_SPEED or nil) end
local function AimFor(b: any, row: any, target: BasePart, from: Vector3, i: number, n: number, lead: boolean, side: number): Vector3
    if row.Low then return target.Position + Vector3.new(0, -2.0, 0) end -- (ENEMY VARIETY skip shot: at your shins -- jump it)
    local aim = Chest(target)
    local tier = b.Tier
    if not tier or row.Tag == "Spike" then return aim end
    if lead then aim = EA.LeadPoint(target, from, EA.ShotSpeed(b.Atk, RoundSpeed(row))) + Vector3.new(0, 0.4, 0) end
    local off = (FAN_OFF[math.clamp(n, 1, 3)][i] or 0) * side
    if off ~= 0 then
        local d = Vector3.new(aim.X - from.X, 0, aim.Z - from.Z)
        if d.Magnitude > 0.1 then aim += Vector3.yAxis:Cross(d.Unit) * off * EA.FAN_W end
    end
    return EA.SpreadAim(from, aim, tier.Spread)
end

-- ----- the attacks (each returns the RAW wind-up; CreateBot times the next attack off it like before) -----
local function Burst(b: any, row: any, target: BasePart): number
    local atk = b.Atk
    local n = math.max(1, row.Shots or 3)
    local wu = row.Windup or 0.6
    -- (POE DAMAGE MODEL) a chip fan's round = CHIP_HIT x the old attack (about one lands); a spike burst splits its total
    local each = (row.Tag == "Spike") and (row.Big and BotRoles.Spike(row.Mult or 1) or (row.Mult or 1)) / n or (row.Mult or 1) * ((n == 1) and EA.CHIP_HIT_LONE or EA.CHIP_HIT)
    local stop = EA.Charge(atk, function() return Muzzle(b, target) end, math.max(0.5, b.Radius * 0.45), wu, atk.ShotColor)
    local scaled = EA.WindupFor(atk, wu, row.Mult)
    task.delay(scaled, function()
        stop()
        if Staggered(b) then return end
        -- (review B) a burst = ONE attack: every round carries the burst's total as its hit size (Plating), and only the first round
        -- that lands rolls the ailment / heals a Vampiric shooter (EnemyAttacks reads Burst in the round's hit)
        -- (POE DAMAGE MODEL) a CHIP burst's rounds are judged one by one by Plating (no Whole) -- small hits
        local burst = (n > 1) and { Total = row.Mult or 1, Landed = {}, Whole = row.Tag == "Spike" } or nil
        local lead = b.Tier ~= nil and math.random() < math.max(b.Tier.Lead, row.Lead or 0) -- (ENEMY VARIETY: a hunter always leads)
        local side = (math.random() < 0.5) and -1 or 1
        for i = 1, n do
            if not Alive(b) or not target.Parent or Staggered(b) then break end
            local from = Muzzle(b, target)
            if row.Low then from -= Vector3.new(0, b.Radius * 0.6, 0) end
            EA.Shot(atk, from, AimFor(b, row, target, from, i, n, lead, side), { Mult = each, Size = row.Size, Speed = RoundSpeed(row), Target = target,
                Plain = nil, Sound = (i == 1) and (row.Sound or "ShootPistol") or nil, Burst = burst, Tag = row.Tag or "Chip" })
            -- (POE DAMAGE MODEL) a chip fan is ONE volley (all rounds at once: with sequential rounds a strafer ran across the fan
            -- into two or three of them -- measured 2x the planted player's chip); a spike burst keeps its 0.14 s rhythm
            if i < n and row.Tag == "Spike" then task.wait(row.Gap or 0.14) end
        end
    end)
    return wu
end

local function Aimed(b: any, row: any, target: BasePart): number
    local atk, model = b.Atk, b.Model
    local wu = row.Windup or 1.0
    local chargeAt = Workspace:GetServerTimeNow()
    model:SetAttribute("AimCharge", chargeAt)
    EA.Aim(atk, function() return HeadFront(b, target) end, target, wu, {
        Mult = BotRoles.Spike(row.Mult or 1), Speed = row.Speed, Size = row.Size, Glow = math.max(1.8, (b.Head and b.Head.Size.X or 1) * 1.5), -- (the big tell: bigger than a gunner's muzzle glow)
        Tag = row.Tag or "Spike",
        Cancelled = function() return (model:GetAttribute("WeakHitAt") or 0) >= chargeAt end,
        OnCancel = function()
            EA.Stagger(model, EA.STAGGER_S, b.Fx)
            model:SetAttribute("Cancels", (model:GetAttribute("Cancels") or 0) + 1) -- (play-test counter)
            pcall(function() require(Shared:WaitForChild("SoundHelper")).PlayAt("ShieldDown", model.PrimaryPart) end)
        end,
        OnEnd = function() if model:GetAttribute("AimCharge") == chargeAt then model:SetAttribute("AimCharge", nil) end end,
    })
    return wu
end

local function Shell(b: any, row: any, target: BasePart): number
    local atk = b.Atk
    local wu = row.Windup or 0.8
    local stop = EA.Charge(atk, function() return b.PosFn() + Vector3.new(0, b.Radius * 1.15, 0) + Toward(b, target) * (b.Radius * 0.4) end, math.max(1.2, b.Radius * 0.8), wu, atk.ShotColor)
    local scaled = EA.WindupFor(atk, wu, row.Mult)
    task.delay(scaled, function()
        stop()
        if not Alive(b) or not target.Parent or Staggered(b) then return end
        local n = math.max(1, row.Count or 1)
        local flight = row.Flight or 1.2
        for i = 1, n do
            local at = target.Position
            if i == 2 then -- the second lands where you're heading (at most 10 studs ahead)
                local v = target.AssemblyLinearVelocity
                local ahead = Vector3.new(v.X, 0, v.Z) * flight * EA.REACT
                if ahead.Magnitude > 10 then ahead = ahead.Unit * 10 end
                if ahead.Magnitude < 4 then ahead = Toward(b, target):Cross(Vector3.yAxis) * 6 end
                at += ahead
            end
            local pool = row.Pool
            EA.Shell(atk, b.PosFn() + Vector3.new(0, b.Radius * 0.9, 0), at, flight, { Mult = BotRoles.Spike(row.Mult or 1), Radius = row.Radius or 5, Target = target,
                Color = atk.ShotColor, Sound = "AreaStrike", Tag = row.Tag or "Spike",
                OnStrike = pool and function(c) if Alive(b) then EA.Zone(atk, c, pool.R or 4, 0.05, pool.Time or 2.4, { Mult = pool.Mult or 0.3, Height = 5, Tag = "Chip", Hit = b.AreaHit }) end end or nil })
            if i == 1 and n > 1 then pcall(function() require(Shared:WaitForChild("SoundHelper")).PlayAt("ShootHeavy", b.Model.PrimaryPart) end) end
            if i < n then task.wait(0.25) end
        end
    end)
    return wu
end

local function Zone(b: any, row: any, target: BasePart, pool: boolean?): number
    local wu = row.Windup or 1.0
    EA.Zone(b.Atk, target.Position, row.Radius or 5, wu, row.Time or 2.5, { Mult = row.Mult or 0.35, Height = 5, Tag = row.Tag or "Chip", Hit = b.AreaHit }) -- (POE DAMAGE MODEL: a follow tick, the bot.s own type)
    return wu
end

-- CASTER: ward the ally that needs it most (elites first, then the nearest) for row.Time seconds -- half damage, a bubble on it and a
-- tether back to the caster; the ward drops the moment the caster dies (that's the answer: kill it first)
-- (review I) an elite with its own shield phase (Shielded / Warded) shares DamageTakenMult: its phase end would clear our ward
local function HasShieldMod(m: Instance): boolean
    local mods = m:GetAttribute("EliteMods")
    if type(mods) ~= "string" or mods == "" then return false end
    local t = "," .. mods .. ","
    return string.find(t, ",Shielded,", 1, true) ~= nil or string.find(t, ",Warded,", 1, true) ~= nil
end
local function PickAlly(b: any, row: any): Model?
    local me = b.PosFn()
    local best, bestScore = nil, math.huge
    for other, pos in pairs(b.Group or {}) do
        if other ~= b.Model and other.Parent and typeof(pos) == "Vector3" and not other:GetAttribute("Dead") and not other:GetAttribute("IsBoss")
            and other:GetAttribute("DamageTakenMult") == nil and not other:GetAttribute("WardedBy") and not other:GetAttribute("Fodder")
            and not HasShieldMod(other) then
            local d = (pos - me).Magnitude
            if d <= (row.Range or 34) then
                local score = d - (other:GetAttribute("IsElite") and 40 or 0)
                if score < bestScore then best, bestScore = other, score end
            end
        end
    end
    return best
end
local function Ward(b: any, row: any, target: BasePart): number
    local ally = PickAlly(b, row)
    if not ally then
        local fb = row.Fallback
        if not fb then return 0.6 end
        if fb.Attack == "Burst" then return Burst(b, fb, target) end
        return Zone(b, fb, target)
    end
    local atk, model = b.Atk, b.Model
    local col = row.Color or BotRoles.WARD_COLOR
    local wu = row.Windup or 0.8
    ally:SetAttribute("WardedBy", true) -- (reserved during the wind-up: two casters don't pick the same ally)
    local stop = EA.Charge(atk, function() return b.PosFn() + Vector3.new(0, b.Radius + 0.6, 0) end, math.max(1, b.Radius * 0.8), wu, col)
    local scaled = EA.WindupFor(atk, wu)
    task.delay(scaled, function()
        stop()
        if not Alive(b) or not ally.Parent or ally:GetAttribute("Dead") or Staggered(b) then
            if ally.Parent then ally:SetAttribute("WardedBy", nil) end
            return
        end
        b.SetTaken(ally, 0.5)
        local size = ally:GetExtentsSize()
        local d = math.max(size.X, size.Y, size.Z) * 1.05 + 0.8
        local bubble = EA.Part({ Name = "AtkWard", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), Color = col, Transparency = 0.35, Parent = b.Fx })
        bubble.Material = Enum.Material.ForceField
        local tether = EA.Part({ Name = "AtkTether", Size = Vector3.new(0.14, 0.14, 1), Color = col, Transparency = 0.45, Parent = b.Fx })
        pcall(function() require(Shared:WaitForChild("SoundHelper")).PlayAt("ShieldUp", ally.PrimaryPart or bubble) end)
        local t0 = os.clock()
        while os.clock() - t0 < (row.Time or 4) do
            if not Alive(b) or not ally.Parent or ally:GetAttribute("Dead") then break end
            local a, c = b.PosFn(), ally:GetPivot().Position
            bubble.CFrame = CFrame.new(c)
            local len = math.max(0.2, (c - a).Magnitude)
            tether.Size = Vector3.new(0.14, 0.14, len)
            tether.CFrame = CFrame.lookAt((a + c) / 2, c)
            RunService.Heartbeat:Wait()
        end
        bubble:Destroy(); tether:Destroy()
        if ally.Parent then
            ally:SetAttribute("WardedBy", nil)
            if not ally:GetAttribute("Dead") then
                b.SetTaken(ally, nil)
                pcall(function() require(Shared:WaitForChild("SoundHelper")).PlayAt("ShieldDown", ally.PrimaryPart) end)
            end
        end
    end)
    return wu
end

-- a ranged role attack on `target`; returns the raw wind-up (or nil: this row isn't a ranged attack)
function BotRoles.Ranged(b: any, target: BasePart): number?
    local row = b.Row
    -- (ENEMY VARIETY) pack fodder fire their pack's family verb (BotVerbs.FodderLite; nil = the plain tracer)
    if row.IsFodder and Verbs.On() then row = Verbs.FodderLite(b) or row end
    -- (POE DAMAGE MODEL) a spike row's spike only every Every-th attack (the first one is at a random place in the cycle); before the
    -- pilot's verbs too (ENEMY VARIETY: a Seeker row / lite fires its chip between orbs)
    if row.Every and row.Every > 1 then
        b.Nth = (b.Nth or math.random(0, row.Every - 1)) + 1
        if b.Nth % row.Every ~= 0 then return Burst(b, BotRoles.ChipRow(row), target) end
    end
    local va = Verbs.ATTACKS[row.Attack]
    if va then return va(b, row, target) end
    local a = row.Attack
    if a == "Burst" then return Burst(b, row, target) end
    if a == "Aimed" then return Aimed(b, row, target) end
    if a == "Shell" then return Shell(b, row, target) end
    if a == "Ward" then return Ward(b, row, target) end
    if a == "Zone" or a == "Pool" then return Zone(b, row, target) end
    return nil
end

-- RUSHER swing (a melee bot): body glow, then the arc -- same reach / arc / damage as its old floor cone
function BotRoles.Swing(b: any, faceFn: () -> Vector3): any
    local row = b.Row
    local scaled = EA.Swing(b.Atk, b.PosFn, faceFn, b.Radius + (row.Range or 10), row.Arc or 55, row.Windup or 0.5, { Mult = BotRoles.Spike(row.Mult or 1.35), Tag = row.Tag or "Spike" })
    return { Raw = row.Windup or 0.5, Scaled = scaled }
end
-- RUSHER dash: it stops and glows (CreateBot holds it still), then dives / rolls along the line it locked at the start; anyone it
-- passes within Reach (+ its radius) is hit once. Returns { Wu, Scaled, Len, Dur, Mult, Reach }
function BotRoles.DashPlan(b: any, dist: number, dir: Vector3?, target: BasePart?): any
    local row = b.Row
    local wu = row.Windup or 0.8
    local d = (dir and dir.Magnitude > 0.01) and dir.Unit or Vector3.zAxis
    -- (the glow sits on its FRONT, toward you: inside the body it was hidden by the body itself)
    local stop = EA.Charge(b.Atk, function() return b.PosFn() + d * (b.Radius + 0.35) end, math.max(1.4, b.Radius * 0.9), wu, b.Atk.ShotColor)
    local scaled = EA.WindupFor(b.Atk, wu, row.Mult)
    task.delay(scaled, stop)
    return { Wu = wu, Scaled = scaled, Len = math.clamp(dist + 5, 12, row.Len or 34), Dur = row.Dur or 0.3, Mult = BotRoles.Spike(row.Mult or 1.35),
        Reach = b.Radius + (row.Reach or 1.5), Leap = (row.Attack == "Leap") and Verbs.LeapPlan(b, target) or nil } -- (ENEMY VARIETY leap slam)
end

-- ===== POE DAMAGE MODEL: chip pieces (CreateBot calls these; DevAttacksOld = no role = none of them) =====
-- RUSHER CONTACT: once it is on you (flat distance <= its body + Contact.Reach), a JAB every Contact.Gap s. Not while a big wind-up
-- holds it (CreateBot passes busy), mid-dive, staggered or dying. No attack slot: a jab is chip and puts nothing in the air (the
-- slots cap rounds + big wind-ups); b.JabUntil keeps the big attack from starting inside a jab's tell. Returns true when it jabbed.
function BotRoles.Contact(b: any, target: BasePart, busy: boolean): boolean
    local c = b.Row.Contact
    if not c or busy or not target or not target.Parent or not Alive(b) or Staggered(b) then return false end
    local now = os.clock()
    if now < (b.JabAt or 0) then return false end
    local rel = target.Position - b.PosFn()
    local reach = b.Radius + (c.Reach or 2.5)
    if Vector3.new(rel.X, 0, rel.Z).Magnitude > reach or math.abs(rel.Y) > 6 then return false end
    -- (the hit checks reach + 0.6 at the release: a step back during the tell avoids it, standing your ground does not)
    local tell = EA.Jab(b.Atk, b.PosFn, function() return target.Parent and (target.Position - b.PosFn()) or Vector3.zAxis end, reach + 0.6, { Mult = c.Mult or 0.3 })
    b.JabUntil = now + tell
    b.JabAt = now + tell + (c.Gap or 1.2) * BotRoles.RallyMult(b.Model)
    return true
end
-- CASTER AURA: degen ground under the caster while it is fighting (active() -> bool: CreateBot's "has a target, not in the safe room")
function BotRoles.StartAura(b: any, active: () -> boolean): (() -> ())?
    pcall(Verbs.OnCreate, b) -- (ENEMY VARIETY: every role bot passes here once at creation -- pack leaders, raise tells, attack rate)
    local a = b.Row.Aura
    if not a then return nil end
    local m = b.Model
    return EA.Aura(b.Atk, b.PosFn, b.Radius + (a.R or 7), { Mult = a.Mult or 0.1, Tick = a.Tick, Hit = b.AreaHit, Active = active,
        Alive = function() return m.Parent ~= nil and m:GetAttribute("Dead") ~= true end })
end
-- ELITE DEATH BURST: a role elite that really died (not Volatile: it has its own bigger blast) leaves a short burst where it fell:
-- radius = its body + R, a flat tell, then ONE hit of Mult x its hit in its own damage type (not evadable). ctx = a fresh EnemyAttacks
-- context (the bot's own Alive is false now) on the floor's Geo / Fx / Targets.
BotRoles.DEATH_BURST = { R = 5, Tell = 0.45, Mult = 0.5 }
function BotRoles.DeathBurst(b: any, ctx: any, pos: Vector3)
    local d = BotRoles.DEATH_BURST
    EA.Nova(ctx, pos, b.Radius + d.R, d.Tell, { Mult = d.Mult, Hit = b.AreaHit })
end

-- ======================================================================================================================
-- ELITE MODS (the pilot's three; defs in DungeonGenerator.EliteModDefs)
-- ======================================================================================================================
-- SHELLED: a shell of SHELL_FRAC of its max health in front of its life. The MATCHING damage type breaks it SHELL_MATCH x as fast,
-- every other type SHELL_OTHER x. When it breaks the bot STAGGERS SHELL_STAGGER s. Server-side (CombatServer.DealEnemyDamage); the
-- attrs ShellType / ShellHp / ShellMax / StaggerUntil mirror to a solo client model (DungeonClient MIRRORED).
-- the pilot's elite-mod keys (DungeonGenerator.ELITE_MOD_KEYS): DevAttacksOld keeps them from rolling (review H)
BotRoles.PILOT_MODS = { Shelled = true, Avenging = true, Skittish = true }
BotRoles.SHELL_FRAC, BotRoles.SHELL_MATCH, BotRoles.SHELL_OTHER, BotRoles.SHELL_STAGGER = 0.4, 2.5, 0.75, 1.2
BotRoles.SHELL_TYPE = { ShellKinetic = "Kinetic", ShellHeat = "Heat", ShellCryo = "Cryo", ShellVolt = "Volt", ShellVoid = "Void" }
function BotRoles.ShellTypeOf(mods: { [string]: boolean }?): string?
    if not mods then return nil end
    for k, t in pairs(BotRoles.SHELL_TYPE) do if mods[k] then return t end end
    return nil
end
function BotRoles.InitShell(model: Instance)
    if not model:GetAttribute("ShellType") or model:GetAttribute("ShellMax") then return end
    local mh = model:GetAttribute("MaxHealth")
    if type(mh) ~= "number" or mh <= 0 then return end
    local s = math.max(1, math.round(mh * BotRoles.SHELL_FRAC))
    model:SetAttribute("ShellMax", s)
    model:SetAttribute("ShellHp", s)
end
-- (review L) a bounty / contract target's health bonus lands after InitShell: keep the shell at SHELL_FRAC of the new max
function BotRoles.RescaleShell(model: Instance)
    local old = model:GetAttribute("ShellMax")
    local mh = model:GetAttribute("MaxHealth")
    if type(old) ~= "number" or old <= 0 or type(mh) ~= "number" then return end
    local sz = math.max(1, math.round(mh * BotRoles.SHELL_FRAC))
    if sz == old then return end
    model:SetAttribute("ShellMax", sz)
    model:SetAttribute("ShellHp", math.round((model:GetAttribute("ShellHp") or old) * sz / old))
end
-- (review A) a solo shell shot is NEUTRAL for Focus only while a Heavy (shell) stand-in lives, budgeted per Heavy: Count claims per
-- CLAIM_GAP x its old attack gap (DungeonRuns.ShellClaim); past that a shell claim is an ordinary miss
BotRoles.CLAIM_GAP = 0.8
local DTm = nil
-- -> the damage that gets through to its life (0 while the shell holds)
function BotRoles.ShellAbsorb(model: Instance, dmg: number, stats: any, kind: string?): number
    local typ = model:GetAttribute("ShellType")
    if not typ then return dmg end
    BotRoles.InitShell(model)
    local hp = model:GetAttribute("ShellHp")
    if type(hp) ~= "number" or hp <= 0 then return dmg end
    DTm = DTm or require(Shared:WaitForChild("DamageTypes"))
    local share
    local at = kind and DTm.AILMENT_TYPE[kind]
    if at then share = (at == typ) and 1 or 0
    else
        local shares = stats and stats.DamageShares
        share = (type(shares) == "table" and shares[typ]) or ((typ == "Kinetic" and type(shares) ~= "table") and 1 or 0)
    end
    local eff = share * BotRoles.SHELL_MATCH + (1 - share) * BotRoles.SHELL_OTHER
    local toShell = dmg * eff
    if toShell < hp then
        model:SetAttribute("ShellHp", hp - toShell)
        return 0
    end
    model:SetAttribute("ShellHp", 0)
    model:SetAttribute("ShellBroke", Workspace:GetServerTimeNow())
    model:SetAttribute("StaggerUntil", Workspace:GetServerTimeNow() + BotRoles.SHELL_STAGGER)
    return (toShell - hp) / math.max(0.01, eff)
end

-- AVENGING: when an ally within RALLY_R of an Avenging elite dies, the elite and every enemy within RALLY_R of it attack RALLY_STEP
-- more often (their gap between attacks shrinks; wind-ups unchanged; no movement speed -- Hasted was removed as "not fun to shoot")
-- for RALLY_S s, stacking to RALLY_MAX. Called from the dead bot's AI loop (solo: the client, party: the server).
BotRoles.RALLY_R, BotRoles.RALLY_S, BotRoles.RALLY_STEP, BotRoles.RALLY_MAX = 36, 6, 0.15, 3
function BotRoles.AllyDown(group: any, pos: Vector3, dead: Instance, fx: Instance?)
    pcall(Verbs.OnDeath, dead, pos) -- (ENEMY VARIETY: a Popper's parting shell)
    if not group then return end
    local now = Workspace:GetServerTimeNow()
    for m, p in pairs(group) do
        if m ~= dead and m.Parent and typeof(p) == "Vector3" and m:GetAttribute("Avenging") and not m:GetAttribute("Dead") and (p - pos).Magnitude <= BotRoles.RALLY_R then
            for o, op in pairs(group) do
                if o ~= dead and o.Parent and typeof(op) == "Vector3" and not o:GetAttribute("Dead") and (op - p).Magnitude <= BotRoles.RALLY_R then
                    local n = ((o:GetAttribute("RallyUntil") or 0) > now) and (o:GetAttribute("RallyN") or 0) or 0
                    o:SetAttribute("RallyN", math.min(BotRoles.RALLY_MAX, n + 1))
                    o:SetAttribute("RallyUntil", now + BotRoles.RALLY_S)
                end
            end
            -- its tell: a short flare rising off it (no ring on the floor -- that would read as an attack)
            local flare = EA.Part({ Name = "AtkRally", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 0.5, 0.5),
                CFrame = CFrame.new(p + Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 120, 90), Transparency = 0.3, Parent = fx or m })
            task.spawn(function()
                local t0 = os.clock()
                while flare.Parent and os.clock() - t0 < 0.45 do
                    local k = (os.clock() - t0) / 0.45
                    flare.Size = Vector3.new(6 + 6 * k, 0.5 * (1 - k) + 0.1, 0.5 * (1 - k) + 0.1)
                    flare.CFrame = CFrame.new(p + Vector3.new(0, 4 + 5 * k, 0)) * CFrame.Angles(0, 0, math.rad(90))
                    flare.Transparency = 0.3 + 0.7 * k
                    RunService.Heartbeat:Wait()
                end
                flare:Destroy()
            end)
            pcall(function() require(Shared:WaitForChild("SoundHelper")).PlayAt("EliteAbility", m.PrimaryPart) end)
        end
    end
end
-- the gap-between-attacks multiplier a rallied bot uses (1 = none)
function BotRoles.RallyMult(model: Instance): number
    -- (ENEMY VARIETY) its own attack rate (Rate: run-and-gun / channel) x a live beacon near it
    local k = (model:GetAttribute("AtkRate") or 1) * Verbs.BeaconMult(model)
    local u = model:GetAttribute("RallyUntil")
    if not u or u <= Workspace:GetServerTimeNow() then return k end
    return k * (1 - BotRoles.RALLY_STEP * math.clamp(model:GetAttribute("RallyN") or 1, 1, BotRoles.RALLY_MAX))
end
-- (ENEMY VARIETY) shootable things a cycle for DungeonRuns.ShellClaim (the archetype's ACTIVE row)
function BotRoles.Shootable(archetype: string?): (any, number)
    local row = BotRoles.ActiveRow(archetype)
    return row, row and Verbs.Shootable(row) or 0
end

-- SKITTISH: blinks SKIT_DIST studs aside when it is hit, at most once every SKIT_CD s (CreateBot, beside the old Blinking code)
BotRoles.SKIT_DIST, BotRoles.SKIT_CD = { 6, 9 }, 5

-- (ENEMY VARIETY) BotVerbs builds its attacks on these
Verbs.Bind({ Burst = Burst, Aimed = Aimed, Muzzle = Muzzle, Chest = Chest, Toward = Toward, Alive = Alive, Staggered = Staggered, Spike = BotRoles.Spike })

return BotRoles
