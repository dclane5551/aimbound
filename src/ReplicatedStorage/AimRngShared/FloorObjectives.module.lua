--!nocheck
-- ============================================================================================
-- FLOOR OBJECTIVES (2026-10-04, owner: "floor objectives that test aim differently"): from floor 2 on, a regular solo
-- floor can carry ONE optional objective. Pull it off for a reward on top of the floor's own loot; fail it and the
-- floor plays as normal. Shown under the floor modifiers on the HUD.
--   BOUNTY     one enemy is marked (gold skull, tougher): kill it before the timer runs out
--   PRECISION  land N weak-spot kills on this floor
--   UNTOUCHED  clear the floor without taking a HEAVY hit (CombatServer.HEAVY_HIT_REL: small chip doesn't count)
--   BLITZ      clear the floor before the timer runs out
--   FOCUS      reach an N-stack Focus streak (weak-spot hits in a row)
--   SHARPSHOOTER  clear the floor with N% accuracy or better (trigger pulls that hit / pulls; 2026-10-06)
--   CHAIN      kill N enemies within 3 seconds of each other (2026-10-06)
-- Server: DungeonRuns rolls / tracks / resolves (folder attributes Objective, ObjNeed, ObjProgress, ObjState
-- "" | "DONE" | "FAILED", ObjDeadline = server time or 0); CombatServer.ObjectiveReward pays out.
-- Not on boss floors, in Rifts, the Daily, Boss Trials or party runs.
-- ============================================================================================
local FloorObjectives = {}

FloorObjectives.Defs = {
    BOUNTY = { Name = "Bounty", Color = Color3.fromRGB(255, 205, 80), Reward = "a top-four rarity item + gold" },
    PRECISION = { Name = "Precision", Color = Color3.fromRGB(255, 90, 90), Reward = "upgrade materials + an item" },
    UNTOUCHED = { Name = "Untouchable", Color = Color3.fromRGB(150, 230, 255), Reward = "a top-three rarity item" },
    BLITZ = { Name = "Blitz", Color = Color3.fromRGB(255, 150, 60), Reward = "gold + Prism Shards" },
    FOCUS = { Name = "Focus", Color = Color3.fromRGB(190, 140, 255), Reward = "a top-four rarity item" },
    SHARPSHOOTER = { Name = "Sharpshooter", Color = Color3.fromRGB(120, 230, 255), Reward = "a top-four rarity item + upgrade materials" },
    CHAIN = { Name = "Chain Reaction", Color = Color3.fromRGB(255, 120, 200), Reward = "gold + an item" },
}
FloorObjectives.Order = { "BOUNTY", "PRECISION", "UNTOUCHED", "BLITZ", "FOCUS", "SHARPSHOOTER", "CHAIN" }
FloorObjectives.CHAIN_WINDOW = 3 -- seconds between kills in a chain
FloorObjectives.CHANCE = 0.55
FloorObjectives.BOUNTY_HP = 1.6 -- the marked target is tougher

-- One objective for a floor, or nil. enemies = how many count toward the clear.
function FloorObjectives.Roll(floorNumber: number, isBossFloor: boolean, enemies: number, rng: Random?): any?
    if floorNumber < 2 or isBossFloor or enemies < 3 then return nil end
    local r = rng or Random.new()
    if r:NextNumber() >= FloorObjectives.CHANCE then return nil end
    return FloorObjectives.Make(FloorObjectives.Order[r:NextInteger(1, #FloorObjectives.Order)], enemies)
end

-- An objective of one kind for a floor with `enemies` foes (also used by the dev "floor" command).
function FloorObjectives.Make(id: string, enemies: number): any?
    if not FloorObjectives.Defs[id] then return nil end
    local o = { Id = id, Need = 1, Time = 0 }
    if id == "BOUNTY" then
        o.Time = 45
    elseif id == "PRECISION" then
        o.Need = math.clamp(math.floor(enemies * 0.5), 3, 10)
    elseif id == "BLITZ" then
        o.Time = math.clamp(25 + enemies * 5, 45, 110)
    elseif id == "FOCUS" then
        o.Need = 12
    elseif id == "SHARPSHOOTER" then
        o.Need = 65 -- (% of trigger pulls that hit)
    elseif id == "CHAIN" then
        o.Need = 3
    end
    return o
end

-- The HUD line ("kill the marked target", "3 / 6 weak-spot kills"...).
function FloorObjectives.Describe(id: string, need: number?, progress: number?): string
    local n, p = need or 1, progress or 0
    if id == "BOUNTY" then return "kill the marked target (gold skull) in time"
    elseif id == "PRECISION" then return string.format("%d / %d weak-spot kills", math.min(p, n), n)
    elseif id == "UNTOUCHED" then return "clear the floor without taking a heavy hit"
    elseif id == "BLITZ" then return "clear the floor in time"
    elseif id == "FOCUS" then return string.format("reach a %d Focus streak  (best %d)", n, math.min(p, n))
    elseif id == "SHARPSHOOTER" then return string.format("clear the floor at %d%%+ accuracy  (now %d%%)", n, p)
    elseif id == "CHAIN" then return string.format("kill %d enemies within %ds of each other  (best %d)", n, FloorObjectives.CHAIN_WINDOW, math.min(p, n))
    end
    return ""
end

return FloorObjectives
