--!nocheck
-- PACKS PILOT (2026-10-21, owner: the game "feels boring" -> PoE direction plan, phase 1 pilot; vault `AIMBOUND/PoE Direction
-- plan.md`). An admin switch (F6 > COMMANDS > Runs > "Packs pilot") on ONE player: their solo floors get packs of weak
-- FODDER bots around every regular bot (the pack leader), the packs arrive in waves, and fodder kills drop a stream of
-- lower-odds loot. Off = the game exactly as before. Party floors, trials, the daily and the Daily Line are never changed.
--   Server: DungeonRuns (config.PacksPilot, the pack queue, fodder stand-ins), DungeonGenerator.AddPilotPacks (roster),
--   CombatServer GiveKillRewards (fodder loot). Client: GroundLoot (no light on common drops while it's on).
local PacksPilot = {}

-- (UPDATE 8 Phase 5, LOOT/RUN builder: PACKS ARE THE NORMAL GAME -- every regular floor of every difficulty, solo AND party
-- (PartyRuns has its own pack queue). Trials, Ascension, the Daily Challenge and the Gauntlet Run stay pack-free. The F6 switch
-- is now an OFF switch for A/B ("Packs off", DevCmd "packsoff"): Player attr PacksOff = true -> that player's solo floors have no packs.)
PacksPilot.ATTR = "PacksOff" -- (Player attribute; replicates, so the client knows too)
PacksPilot.ON = true
-- MINI-BOSS FLOORS (owner's answer: "a small pack wave on mini-boss floors only"): MINI_PACKS packs come with the mini-boss,
-- MINI_START of them at once, the rest once fewer than MINI_REFILL_BELOW enemies are alive (mid-fight). Major / super boss
-- floors stay boss-only.
PacksPilot.MINI_PACKS, PacksPilot.MINI_START, PacksPilot.MINI_REFILL_BELOW = 3, 2, 6

-- packs: every regular bot leads PACK_MIN..PACK_MAX fodder in a ring PACK_R studs round it
PacksPilot.PACK_MIN, PacksPilot.PACK_MAX = 4, 5
-- (PACK SIZE BY DIFFICULTY, owner: "pack size should probably scale up throughout difficulty, no?") the fodder a leader brings
-- grows smoothly with ItemData.DifficultyRank: PACK_MIN..PACK_MAX on Easy -> + PACK_GROW x that at PACK_GROW_RANK (Annihilation,
-- the top open tier: 8-10) and on past it. RollFodder = an integer with the range's mean (Easy = exactly the old 4 / 5 roll).
-- ItemData.PACK_XP_TIER keeps the XP a minute on the RUN_PACE model (tools/sim/pack_size.py).
PacksPilot.PACK_GROW, PacksPilot.PACK_GROW_RANK = 1.0, 12
PacksPilot.PARTY_LIVE_CAP = 48 -- (a party's opening wave: START_PACKS + 1 a member, trimmed back to START_PACKS until packs x size fits)
function PacksPilot.PackRange(difficulty: string?): (number, number)
    local ok, ItemData = pcall(require, script.Parent:WaitForChild("ItemData"))
    local rank = (ok and ItemData.DifficultyRank and ItemData.DifficultyRank[difficulty or ""]) or 1
    local t = 1 + PacksPilot.PACK_GROW * (rank - 1) / (PacksPilot.PACK_GROW_RANK - 1)
    return PacksPilot.PACK_MIN * t, PacksPilot.PACK_MAX * t
end
-- (2026-10-23 EARLY RAMP, owner: "When you literally join the first area, there is still like 10+ bots when you only have a glock.
-- The early quantity of bots should definitely be a bit less") a fresh run starts small and grows to today's numbers by Hard:
-- PacksPilot.Early(difficulty, floor) = a 0..1 scale on the floor's pack COUNT (packs a room / START_PACKS / REFILL_BELOW), the
-- fodder a leader brings, the horde room (x scale^1.5) and the path stragglers. Anchors per difficulty at floors 1 / 3 / 5, linear
-- between, then on to 1 by floor 10 (Endless). Hard and up: 1 (unchanged). ItemData.KillXp pays x EarlyXp on those floors so the
-- fewer kills don't slow the first levels down.
-- (RUNFIX 2026-10-25, owner: "Easy still too many bots early" -> ~3-5 bots engaging at once): Easy's pack COUNT starts lower (one
-- pack a room on floor 1: 2-3 x 0.48 rounds to 1) while each pack keeps a few more fodder (EARLY_FODDER), so a room is one group of
-- 3-5 instead of 1-2 groups of 3-4; the horde room takes scale^2 (DungeonGenerator RollLinkedRoster) = an elite + 4-5 fodder.
-- Was Easy { 0.55, 0.7, 0.8 } for both.
-- (EARLY DENSITY 2026-11-07, owner: "enemies still scale up in quantity too quick before you get any AOE stuff") the ramp now runs
-- on to Torment instead of stopping at Hard: area damage (an Area shot mod in a socket of its colour ~440-1600 bot kills in, the
-- Shrapnel / Bank Shot / Carom keystones ~L22-30) is realistic from about Brutal / Nightmare, so the bots awake in a room climb
-- ~6 Easy -> 9 Normal -> 10 Hard -> 12 Brutal -> 14 Nightmare -> 16 Torment (unchanged from Torment up; was 6 / 12 / 14 / 15 / 15 / 16)
-- and the horde room 8 -> 11 -> 14 -> 16 -> 18 -> 22 (was 8 / 15 / 22 / 22 / 22 / 22). Fewer kills each PAY more (PAY below), so a
-- run's XP, gold and item drops stay as before. Measured offline: tools/sim/early_density.py. Was Normal { 0.75, 0.85, 0.92 },
-- no Hard / Brutal / Nightmare rows. (Hard+ floors have 2 packs a room: EARLY >= 0.75 keeps both, the fodder row does the thinning.)
-- (NIGHTMARE = BRUTAL 2026-11-07, owner: an L30 player with no AOE "felt overwhelmed" -> Nightmare gets Brutal's enemy counts and
-- Torment is the first full-crowd tier) Nightmare = Brutal's EARLY row + Brutal's fodder row x PackRange(Brutal) / PackRange(Nightmare)
-- 14 / 15 (a Nightmare pack rolls bigger by rank): bots awake in a main room 13.8 -> 11.6, horde room 18.3 -> 15.8, a run (f1-5)
-- 121 -> 103 (= Brutal; tools/sim/early_density.py --new --nm). Was Nightmare { 0.88, 0.93, 0.97 } / fodder { 0.85, 0.9, 0.95 }.
PacksPilot.EARLY = { Easy = { 0.48, 0.6, 0.75 }, Normal = { 0.6, 0.7, 0.8 }, Hard = { 0.76, 0.8, 0.85 }, Brutal = { 0.8, 0.86, 0.92 },
    Nightmare = { 0.8, 0.86, 0.92 } }
PacksPilot.EARLY_FODDER = { Easy = { 0.7, 0.8, 0.9 }, Normal = { 0.8, 0.85, 0.9 }, Hard = { 0.6, 0.65, 0.7 }, Brutal = { 0.72, 0.78, 0.84 },
    Nightmare = { 0.67, 0.73, 0.78 } } -- (fodder a leader; a difficulty without a row uses EARLY)
-- EarlyXp's own curve = the 2026-10-25 ramp (the XP-a-minute model the owner played); PAY covers what the 2026-11-07 rows took away
PacksPilot.EARLY_XP = { Easy = { 0.48, 0.6, 0.75 }, Normal = { 0.75, 0.85, 0.92 } }
-- PAY: XP, gold and the item chance of every regular-floor bot kill (not bosses) = HEAD's reward units of that floor / the new ones
-- (tools/sim/early_density.py --pay, anchors floors 1 / 3 / 5 like EARLY; 1 from floor 10 on; no row = 1)
PacksPilot.PAY = { Normal = { 1.14, 1.37, 1.01 }, Hard = { 1.19, 1.16, 1.14 }, Brutal = { 1.15, 1.1, 1.07 }, Nightmare = { 1.17, 1.12, 1.11 } } -- (Nightmare was 1.08 / 1.05 / 1.02 before NIGHTMARE = BRUTAL)
function PacksPilot.EarlyPay(difficulty: string?, floor: number?): number
    local d = tostring(difficulty or "Easy"):gsub("^Endless:", "")
    if not PacksPilot.PAY[d] then return 1 end
    return PacksPilot.Early(d, floor, PacksPilot.PAY)
end
-- (NIGHTMARE = BRUTAL A/B, Studio) workspace attr DevNightmareOld = true -> Nightmare's rows before 2026-11-07 (set it BEFORE the floor)
PacksPilot.NIGHTMARE_OLD = { EARLY = { 0.88, 0.93, 0.97 }, FODDER = { 0.85, 0.9, 0.95 }, PAY = { 1.08, 1.05, 1.02 } }
function PacksPilot.Early(difficulty: string?, floor: number?, tbl: any?): number
    local d = tostring(difficulty or "Easy"):gsub("^Endless:", "")
    local t = (tbl and tbl[d]) or PacksPilot.EARLY[d]
    if d == "Nightmare" and workspace:GetAttribute("DevNightmareOld") == true then
        local O = PacksPilot.NIGHTMARE_OLD
        t = (tbl == PacksPilot.EARLY_FODDER and O.FODDER) or (tbl == PacksPilot.PAY and O.PAY) or O.EARLY
    end
    if not t then return 1 end
    local f = math.max(1, tonumber(floor) or 1)
    if f <= 1 then return t[1] end
    if f <= 3 then return t[1] + (t[2] - t[1]) * (f - 1) / 2 end
    if f <= 5 then return t[2] + (t[3] - t[2]) * (f - 3) / 2 end
    return math.min(1, t[3] + (1 - t[3]) * (f - 5) / 5)
end
-- XP a kill on a ramped floor: fewer, smaller packs -> each kill pays a little more (a model: kills ~ scale^2, time ~ scale^0.75 of a
-- floor -> XP a minute about the same at EARLY_XP_EXP 0.55)
PacksPilot.EARLY_XP_EXP = 0.55
function PacksPilot.EarlyXp(difficulty: string?, floor: number?): number
    local d = tostring(difficulty or "Easy"):gsub("^Endless:", "")
    if not PacksPilot.EARLY_XP[d] then return 1 end
    return PacksPilot.Early(d, floor, PacksPilot.EARLY_XP) ^ -PacksPilot.EARLY_XP_EXP
end
function PacksPilot.RollFodder(difficulty: string?, floor: number?): number
    local lo, hi = PacksPilot.PackRange(difficulty)
    local s = PacksPilot.Early(difficulty, floor, PacksPilot.EARLY_FODDER)
    lo, hi = lo * s, hi * s
    return math.max(1, math.floor(lo + math.random() * (hi - lo + 1)))
end
-- the opening wave / refill line of a regular (non-linked) floor, ramped
function PacksPilot.StartPacks(difficulty: string?, floor: number?): number
    return math.max(1, math.round(PacksPilot.START_PACKS * PacksPilot.Early(difficulty, floor)))
end
function PacksPilot.RefillBelow(difficulty: string?, floor: number?): number
    return math.max(3, math.round(PacksPilot.REFILL_BELOW * PacksPilot.Early(difficulty, floor)))
end
PacksPilot.PACK_R = { 5, 12 } -- (MOVEMENT ROUND 2: 4-9 -> 5-12, a pack starts spread out)
PacksPilot.FODDER = { "Runner", "Runner", "Tracker", "Drifter", "Strafer" } -- (plain movers; no specialists / twitchy types)
-- waves: START_PACKS packs at the floor start, the next pack when fewer than REFILL_BELOW enemies are alive,
-- at least AWAY studs from you
PacksPilot.START_PACKS = 3
PacksPilot.REFILL_BELOW = 8
PacksPilot.AWAY = 35
-- a fodder bot vs a plain bot of the same type
PacksPilot.HP = 0.25 -- (a plain bot ~1.1-2.4 s -> fodder ~0.3-0.6 s)
PacksPilot.DMG = 0.4
PacksPilot.XP = 0.15 -- (20 fodder ~ 3 plain bots of XP; a floor also takes longer -> XP a minute about the same, estimate)
PacksPilot.GOLD = 0.15
-- loot stream: an item chance per fodder kill (x loot quantity, capped), rolled at FODDER_ODDS per rarity step
-- (UPDATE 8 RARITY v4: 0.65^2 = x0.42 Rare, 0.65^3 = x0.27 Mythic per item -- the stream is mostly Commons / Uncommons; Mythic hours
-- stay the same with or without packs, tools/sim/raritysim.py)
-- (LOOT SCARCITY 2026-11-07: CombatServer reads ItemData.LOOT_SCARCITY.Fodder / FodderCap instead while that table is ON; these
-- two are the fallback. EarlyPay no longer touches the item chance -- XP / gold only.)
PacksPilot.ITEM_CHANCE = 0.2
PacksPilot.ITEM_CAP = 0.6
PacksPilot.ODDS = 0.65
-- flat per-kill rolls (gems, Fate Shards, Ascension Essence, season XP) x RARE on fodder, so 5x the kills isn't 5x of those
PacksPilot.RARE = 0.15

function PacksPilot.For(player: Player?): boolean
    return PacksPilot.ON and not (player ~= nil and player:GetAttribute(PacksPilot.ATTR) == true)
end

return PacksPilot
