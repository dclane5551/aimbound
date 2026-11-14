--!nocheck
-- ============================================================================================
-- THE DAILY LINE (UPDATE 7 B6, the vault's daily gauntlet renamed in Loot Economy Plan section 11; placeholder): from level
-- UNLOCK, one shared 3-floor run per UTC day, the same for everyone (biomes, two HARSH modifiers a floor, bot skill), floor 3 a
-- boss. You play it on the hardest difficulty you've unlocked. ONE try a day (state.DailyLine { Day, Tried, Done, Time });
-- dying / leaving spends it. A clear pays a rare stack (DailyLine.Reward) and your time goes on the day's board "Line_<day>".
-- Server: EndgameServer StartDailyLine + LineFinished; DungeonRuns run.Line (biomes / mods / the boss floor / the finish).
-- (The older DAILY CHALLENGE stays: Normal, 5 floors, unlimited tries.)
-- ============================================================================================
local DailyLine = {}

DailyLine.ON = true
DailyLine.UNLOCK = 100
DailyLine.FLOORS = 3
DailyLine.BOT_SKILL = 8
DailyLine.COLOR = Color3.fromRGB(255, 90, 90)
-- harsh only: no gifts, no easy risks
local HARSH = { "BRUTAL", "ARMORED", "SHARPSHOOTERS", "RELENTLESS", "SMALL_TARGETS", "ELEMENTAL", "STEEL_SKIN", "MENDING", "FRENZIED", "FORTIFIED" }
local BIOMES = { "Fire", "Ice", "Cyber", "Void", "Storm", "Dream", "Flats" }
do
    local ok, WB = pcall(require, script.Parent:WaitForChild("WorldBiomes"))
    if ok then for _, id in ipairs(WB.LIST) do table.insert(BIOMES, id) end end
end

function DailyLine.Today(): number return os.time() // 86400 end

-- the day's line (deterministic): { Day, Biomes = {3}, Mods = { [floor] = {2 ids} }, BotSkill }
function DailyLine.ForDay(day: number): any
    local r = Random.new(day * 104659 + 3)
    local c = { Day = day, Biomes = {}, Mods = {}, BotSkill = DailyLine.BOT_SKILL }
    local pool = table.clone(BIOMES)
    for f = 1, DailyLine.FLOORS do
        local i = r:NextInteger(1, #pool)
        c.Biomes[f] = pool[i]
        table.remove(pool, i)
        local mp = {}
        for _, m in ipairs(HARSH) do -- (never the floor before's modifiers again)
            if not (c.Mods[f - 1] and table.find(c.Mods[f - 1], m)) then table.insert(mp, m) end
        end
        local mods = {}
        for _ = 1, 2 do
            local j = r:NextInteger(1, #mp)
            table.insert(mods, mp[j])
            table.remove(mp, j)
        end
        c.Mods[f] = mods
    end
    return c
end

-- the player's record for today (nil-safe)
function DailyLine.Record(state: any): any
    local rec = type(state) == "table" and state.DailyLine
    if type(rec) ~= "table" or rec.Day ~= DailyLine.Today() then return { Day = DailyLine.Today(), Tried = false, Done = false } end
    return rec
end

function DailyLine.CanStart(state: any): (boolean, string?)
    if not DailyLine.ON then return false, "The Gauntlet Run is off." end
    if (type(state) == "table" and state.Level or 1) < DailyLine.UNLOCK then return false, "The Gauntlet Run opens at level " .. DailyLine.UNLOCK .. "." end
    if DailyLine.Record(state).Tried then return false, "You've run today's line. A new one at midnight (UTC)." end
    return true
end

-- the clear's reward
function DailyLine.Reward(level: number?): any
    return { Gold = math.round(30000 * (1 + (level or 1) / 40)), Prism = 15, Currencies = 3, Items = 2, Exotic = 0.1, Ink = 2 }
end

return DailyLine
