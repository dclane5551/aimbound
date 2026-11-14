--!nocheck
-- MAP TREE (server): AtlasAction ("Allocate", nodeId) / ("Refund", nodeId) -> ok, message. The rules (points, links,
-- refund cost) live in AimRngShared.AtlasData; the effects are read where maps run (EndgameServer StartRift /
-- RiftFinished / GiveSigil, DungeonRuns, DungeonGenerator, Hideouts CraftMap).
local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local AtlasData = require(Shared:WaitForChild("AtlasData"))

local AtlasService = {}

function AtlasService.Init(CombatServer: any)
    local busy = {}
    Remotes.GetFunction("AtlasAction").OnServerInvoke = function(p: Player, action: any, id: any): (boolean, string?)
        if busy[p] then return false, "One moment." end
        local state = CombatServer.GetState(p)
        if not state or type(id) ~= "string" or not AtlasData.Nodes[id] then return false, "Unknown node." end
        busy[p] = true
        local ok, msg = false, "Unknown action."
        state.Atlas = type(state.Atlas) == "table" and state.Atlas or {}
        state.Atlas.Nodes = type(state.Atlas.Nodes) == "table" and state.Atlas.Nodes or {}
        if action == "Allocate" then
            ok, msg = AtlasData.CanAllocate(state, id)
            if ok then
                state.Atlas.Nodes[id] = true
                msg = AtlasData.Nodes[id].Name .. " taken."
            end
        elseif action == "Refund" then
            ok, msg = AtlasData.CanRefund(state, id)
            if ok then
                state.Materials = state.Materials or {}
                if (state.Materials.Prism or 0) < AtlasData.REFUND_COST then
                    ok, msg = false, string.format("A refund costs %d Prism.", AtlasData.REFUND_COST)
                else
                    state.Materials.Prism -= AtlasData.REFUND_COST
                    state.Atlas.Nodes[id] = nil
                    msg = AtlasData.Nodes[id].Name .. " refunded."
                end
            end
        end
        if ok then Remotes.GetEvent("SyncPlayerState"):FireClient(p, state) end
        busy[p] = nil
        return ok, msg
    end
    game:GetService("Players").PlayerRemoving:Connect(function(p) busy[p] = nil end)
end

return AtlasService
