--!nocheck
-- ============================================================================================
-- DAILY CHALLENGE (Diablo Challenge Rift / PoE races): one fixed 5-floor run per UTC day, the same for
-- everyone -- same biomes (one per floor, MIXED RUNS), bot skill, floor modifiers and dungeon events. Clear floor 5 (a boss) as fast as
-- you can; your best time goes on the day's leaderboard. First clear of the day pays a Rare+ gem, Prism
-- Shards and gold. Unlimited attempts; dying ends the attempt.
-- Server: EndgameServer.StartDailyChallenge -> DungeonRuns (run.Daily) forces each floor's mods / event.
-- ============================================================================================
local DailyChallenge = {}

DailyChallenge.FLOORS = 5
DailyChallenge.DIFFICULTY = "Normal"
DailyChallenge.BOT_SKILL = 5
local BIOMES = { "Fire", "Ice", "Cyber", "Void", "Storm", "Dream", "Flats" }
do -- (0.87 WORLDS)
    local ok, WB = pcall(require, script.Parent:WaitForChild("WorldBiomes"))
    if ok then for _, id in ipairs(WB.LIST) do table.insert(BIOMES, id) end end
end
local MOD_POOL = { "FRENZIED", "FORTIFIED", "SWARMING", "ELITE_PACK", "GLASS_ARENA", "HEADHUNTER" }
-- (FUTURE-PROOF 2026-10-25: the live floor events -- DungeonEvents.Order; the old copy still held BOON_SHRINE twice, a dead shrine
-- on 40% of the Daily's event floors since boons were cut)
local EVENT_POOL = require(script.Parent:WaitForChild("DungeonEvents")).Order

function DailyChallenge.Today(): number
    return os.time() // 86400
end

-- The day's challenge (deterministic): { Day, Biome, Difficulty, BotSkill, Mods = { [floor] = {ids} }, Events = { [floor] = id? } }
function DailyChallenge.ForDay(day: number): any
    local r = Random.new(day * 7919 + 17)
    local c = {
        Day = day, Biome = BIOMES[r:NextInteger(1, #BIOMES)], Difficulty = DailyChallenge.DIFFICULTY,
        BotSkill = DailyChallenge.BOT_SKILL, Mods = {}, Events = {},
    }
    for floor = 1, DailyChallenge.FLOORS do
        local mods = {}
        if floor >= 2 and floor < DailyChallenge.FLOORS then
            local pool = table.clone(MOD_POOL)
            for _ = 1, (floor >= 3) and 2 or 1 do
                local i = r:NextInteger(1, #pool)
                table.insert(mods, pool[i])
                table.remove(pool, i)
            end
        end
        c.Mods[floor] = mods
        c.Events[floor] = (floor >= 2 and floor < DailyChallenge.FLOORS) and EVENT_POOL[r:NextInteger(1, #EVENT_POOL)] or ""
    end
    -- each floor's biome: a shuffle of all five, seeded by the day (its own Random: the mods above stay as they were)
    local br = Random.new(day * 7919 + 101)
    local order = table.clone(BIOMES)
    for i = #order, 2, -1 do
        local j = br:NextInteger(1, i)
        order[i], order[j] = order[j], order[i]
    end
    c.Biomes = order
    c.Biome = order[1]
    return c
end

-- the biome of one of the day's floors (wraps past the fifth)
function DailyChallenge.BiomeOf(c: any, floor: number): string
    local b = c.Biomes or { c.Biome or "Fire" }
    return b[((floor - 1) % #b) + 1]
end

function DailyChallenge.FormatTime(seconds: number?): string
    if not seconds or seconds ~= seconds or seconds >= 1e8 then return "--:--" end
    local m = math.floor(seconds / 60)
    return string.format("%d:%04.1f", m, seconds - m * 60)
end

return DailyChallenge
