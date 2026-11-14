--!nocheck
-- GOAL TRACKER feed (QOL PASS 2 R4, 2026-10-28; client = AimRngShared/GoalTracker). The daily contracts + weekly bounties move
-- on kills / floor clears (CombatServer.ContractEvent), but the client only got the lists on SyncPlayerState (when one FINISHED).
-- ContractEvent marks the player dirty; once a second the dirty players' progress numbers go out as ONE Player attribute
-- "GoalProg" = "<day>:<p1>,<p2>,..|<week>:<p1>,..." -- only when the string changed. Never per hit (events are per kill / floor).
local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Remotes"))

local GoalTrack = {}
GoalTrack.GetState = nil :: any -- (set by CombatServer: player -> state)
local dirty: { [Player]: boolean } = {}
local lists: { [Player]: string } = {} -- the day / week / list sizes the client last got with a full sync from here

function GoalTrack.Mark(player: Player)
    dirty[player] = true
end

local function Part(list: any): string
    local t = {}
    if type(list) == "table" then
        for i, c in ipairs(list) do t[i] = tostring(math.floor(tonumber(type(c) == "table" and c.Progress) or 0)) end
    end
    return table.concat(t, ",")
end
-- the attribute text for this state
function GoalTrack.Text(state: any): string
    local c = type(state) == "table" and state.Contracts or nil
    local w = type(state) == "table" and state.Weekly or nil
    return string.format("%s:%s|%s:%s", tostring(c and c.Day or 0), Part(c and c.List), tostring(w and w.Week or 0), Part(w and w.Bounties))
end

function GoalTrack.Push(player: Player)
    local gs = GoalTrack.GetState
    local state = gs and gs(player)
    if not state then return end
    local s = GoalTrack.Text(state)
    if player:GetAttribute("GoalProg") ~= s then player:SetAttribute("GoalProg", s) end
    -- a NEW list (first event of a day / week: EnsureContracts / EnsureWeekly just rolled it) -> one full sync so the client
    -- has the goals' texts + targets (only the numbers ride the attribute)
    local c, w = state.Contracts, state.Weekly
    local sig = string.format("%s/%d/%s/%d", tostring(c and c.Day), (c and type(c.List) == "table") and #c.List or 0,
        tostring(w and w.Week), (w and type(w.Bounties) == "table") and #w.Bounties or 0)
    if lists[player] ~= sig then -- (also the session's first push: the join sync may predate the week's board -- EnsureWeekly runs on events)
        lists[player] = sig
        Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    end
end

task.spawn(function()
    while true do
        task.wait(1)
        for p in pairs(dirty) do
            dirty[p] = nil
            if p.Parent then pcall(GoalTrack.Push, p) end
        end
    end
end)
Players.PlayerRemoving:Connect(function(p) dirty[p] = nil; lists[p] = nil end)

return GoalTrack
