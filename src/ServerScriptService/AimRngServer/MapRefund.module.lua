--!nocheck
-- DISCONNECT MAP REFUND (QOL PASS 2 R5, 2026-10-28; audit 14, the cheap version). A map (sigil) is consumed when it opens
-- (EndgameServer.StartRift). If the player LEAVES THE GAME before its floor 1 is cleared, the map comes back once on the next join.
--   * StartRift (after the map opened) -> state._MapRefund = the consumed sigil (live only: "_" fields are never saved)
--   * it is dropped for good by: the first FloorClear of the run (CombatServer.ContractEvent), any run end (ClearRunLives:
--     victory / extract / out of lives / back to the hub) and any run start (StartRunLives)
--   * SaveService.LeaveHooks (before the leave save): _MapRefund still set -> state.PendingMapRefund = that sigil (SAVED, additive
--     PLAIN_FIELDS field, nil = nothing; no SAVE_VERSION bump)
--   * next join (once the save is in): PendingMapRefund -> back into state.Sigils, the field cleared in the same step, a toast
--     "Your map was returned", a save. No dupe: the sigil only ever exists in ONE place (consumed -> _MapRefund -> Pending ->
--     Sigils), each move clears the source. Maps are solo-only runs, so no party member can be refunded for a map that goes on.
local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Remotes"))

local MapRefund = {}
local CombatServer, SaveService = nil, nil

-- the map just opened (EndgameServer.StartRift)
function MapRefund.Opened(state: any, sigil: any)
    if type(state) == "table" and type(sigil) == "table" then state._MapRefund = sigil end
end
-- the map is past floor 1 / the run ended / another run began: no refund any more
function MapRefund.Drop(state: any)
    if type(state) == "table" then state._MapRefund = nil end
end

-- SaveService leave hook (runs before the leave save)
function MapRefund.OnLeave(player: Player, state: any)
    if type(state) ~= "table" or type(state._MapRefund) ~= "table" then return end
    if type(state.PendingMapRefund) ~= "table" then -- (one pending map at most; a second can't exist: one map runs at a time)
        state.PendingMapRefund = state._MapRefund
    end
    state._MapRefund = nil
end

-- next join: the map back into the bag (returns true when one came back)
function MapRefund.OnJoin(player: Player, state: any): boolean
    if type(state) ~= "table" then return false end
    local sigil = state.PendingMapRefund
    if sigil == nil then return false end
    state.PendingMapRefund = nil -- (cleared first: whatever happens next, it can't be given twice)
    if type(sigil) ~= "table" or type(sigil.Uid) ~= "string" then return false end
    state.Sigils = type(state.Sigils) == "table" and state.Sigils or {}
    for _, s in ipairs(state.Sigils) do if type(s) == "table" and s.Uid == sigil.Uid then return false end end -- (already there)
    table.insert(state.Sigils, sigil)
    if player.Parent then
        Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "Your map was returned: you left before its first floor was cleared")
        if SaveService and SaveService.Save then task.spawn(SaveService.Save, player, state, false) end
    end
    return true
end

function MapRefund.Init(combat: any)
    CombatServer = combat
    SaveService = require(script.Parent:WaitForChild("SaveService"))
    SaveService.LeaveHooks = SaveService.LeaveHooks or {}
    table.insert(SaveService.LeaveHooks, function(p: Player, state: any) MapRefund.OnLeave(p, state) end)
    task.spawn(function() -- (each player once, as soon as their save is in)
        local done = {}
        while true do
            task.wait(3)
            for _, p in ipairs(Players:GetPlayers()) do
                if not done[p] and SaveService.IsReady and SaveService.IsReady(p) then
                    done[p] = true
                    pcall(function() MapRefund.OnJoin(p, CombatServer.GetState(p)) end)
                end
            end
            for p in pairs(done) do if not p.Parent then done[p] = nil end end
        end
    end)
end

return MapRefund
