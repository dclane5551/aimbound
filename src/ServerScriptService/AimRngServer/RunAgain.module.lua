--!nocheck
-- RUN AGAIN (QOL F1, 2026-10-28; contract docs/QOL_2026-10-28.md): the run summary + the DUNGEON CLEARED banner offer the same
-- run again. The SERVER remembers how your last run was started (never the client's word) and starts the next one through the
-- REAL start path, so every check and cost still applies:
--   Solo  -- the Dungeons window's solo run (CombatServer StartDungeonRaid floor 1): difficulty / game type + bot skill. Go
--            answers { Solo = { Biome, Key, BotSkill } } and the client calls the same StartDungeonRaid (unlock checked again).
--   Map   -- a map from the map device / Challenges (EndgameServer.StartRift): another map of the SAME TIER from your bag (same
--            world first) is consumed like normal; no map of that tier = no button. Bot-skill pick kept.
--   Party -- a lobby room's run (PartyService Start): the leader starts the same room again (its READY CHECK included); members
--            see WAITING FOR LEADER.
-- Every run start clears the record first (CombatServer.StartRunLives -> RunAgain.Clear): trials / the daily / the Daily Line
-- etc. are never "run again" (and never leave an older run's record behind).
-- Remote RunAgain (RemoteFunction): ("Info") -> info | ("Go") -> ok, why|result
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AimRngShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))

local RunAgain = {}
local last: { [Player]: any } = {}

function RunAgain.Clear(player: Player)
    last[player] = nil
end

-- rec = { Kind = "Solo", Key, BotSkill } | { Kind = "Map", Tier, Biome, Skill } | { Kind = "Party", RoomId }
function RunAgain.Note(player: Player, rec: any)
    if type(rec) == "table" then last[player] = rec end
end

function RunAgain.Get(player: Player): any
    return last[player]
end

local function Svc(name: string): any
    return require(script.Parent:WaitForChild(name))
end

-- the map to use: same tier, the same world first (Rifts sigils in state.Sigils)
local function PickSigil(state: any, rec: any): (any, number)
    local same, any, n = nil, nil, 0
    for _, s in ipairs(state.Sigils or {}) do
        if type(s) == "table" and s.Tier == rec.Tier then
            n += 1
            any = any or s
            if rec.Biome and s.Biome == rec.Biome then same = same or s end
        end
    end
    return same or any, n
end

-- what the button shows: { Show, Ok, Label, Why, Kind }
function RunAgain.Info(player: Player): any
    local rec = last[player]
    if not rec then return { Show = false } end
    local CombatServer = Svc("CombatServer")
    local state = CombatServer.GetState(player)
    if rec.Kind == "Solo" then
        local diff, endless = ItemData.ParseRunKey(rec.Key)
        if not diff then return { Show = false } end
        local ok, why = ItemData.DifficultyUnlock(state, diff)
        return { Show = true, Kind = "Solo", Ok = ok == true, Why = (not ok) and tostring(why) or nil,
            Label = "RUN AGAIN", Sub = string.upper((endless and "Endless " or "") .. diff) .. "  •  bot skill " .. tostring(rec.BotSkill or 4) }
    elseif rec.Kind == "Map" then
        local Rifts = require(Shared:WaitForChild("Rifts"))
        local sg, n = PickSigil(state, rec)
        local tierTxt = "TIER " .. tostring(rec.Tier) .. " MAP"
        if not sg then return { Show = true, Kind = "Map", Ok = false, Label = "RUN AGAIN", Sub = tierTxt, Why = "No tier " .. tostring(rec.Tier) .. " map left in your bag." } end
        return { Show = true, Kind = "Map", Ok = true, Label = "RUN AGAIN", Sub = tierTxt .. "  •  " .. Rifts.DisplayName(sg) .. "  •  " .. n .. " left" }
    elseif rec.Kind == "Party" then
        local PartyService = Svc("PartyService")
        local room = PartyService.RoomOf(player)
        if not room or room.Id ~= rec.RoomId then return { Show = false } end
        local diff, endless = ItemData.ParseRunKey(room.Difficulty)
        local sub = string.upper((endless and "Endless " or "") .. tostring(diff)) .. "  •  party of " .. #room.Members
        if room.HostUserId ~= player.UserId then
            return { Show = true, Kind = "Party", Ok = false, Wait = true, Label = "WAITING FOR LEADER", Sub = sub, Why = "Only the party leader can start the next run." }
        end
        if room.State ~= "Lobby" then
            return { Show = true, Kind = "Party", Ok = false, Label = "RUN AGAIN", Sub = sub, Why = "Your party is still in the run: RUN AGAIN opens when everyone is back." }
        end
        return { Show = true, Kind = "Party", Ok = true, Label = "RUN AGAIN", Sub = sub }
    end
    return { Show = false }
end

-- leaves the run you're in (the vault after a win) exactly like RETURN TO HUB does (TeleportPlayer "Hub" on the server)
local function LeaveRun(player: Player)
    local DungeonRuns, PartyRuns = Svc("DungeonRuns"), Svc("PartyRuns")
    if DungeonRuns.Get(player) then DungeonRuns.EndRun(player) end
    if PartyRuns.RunOfPlayer(player) then PartyRuns.RemoveMember(player) end
end

function RunAgain.Go(player: Player): (boolean, any)
    local info = RunAgain.Info(player)
    if not info.Show then return false, "Nothing to run again." end
    if not info.Ok then return false, info.Why or "You can't run that again right now." end
    local rec = last[player]
    if rec.Kind == "Solo" then
        LeaveRun(player)
        return true, { Solo = { Biome = "Fire", Key = rec.Key, BotSkill = rec.BotSkill } } -- (the client calls StartDungeonRaid: checked there)
    elseif rec.Kind == "Map" then
        local state = Svc("CombatServer").GetState(player)
        local sg = PickSigil(state, rec)
        if not sg then return false, "No map of that tier left." end
        LeaveRun(player)
        local ok, why = Svc("EndgameServer").StartRift(player, sg.Uid, rec.Skill) -- (consumes the map, all its checks)
        return ok == true, ok and { Map = true } or (why or "Couldn't open the map.")
    elseif rec.Kind == "Party" then
        local ok, res = Svc("PartyService").StartRoom(player) -- (the leader's START: unlocks, ready check)
        return ok == true, res
    end
    return false, "Nothing to run again."
end

function RunAgain.Init()
    Remotes.GetFunction("RunAgain").OnServerInvoke = function(player: Player, action: any)
        local ok, a, b = pcall(function()
            if action == "Info" then return RunAgain.Info(player) end
            if action == "Go" then return RunAgain.Go(player) end
            return nil
        end)
        if not ok then
            warn("[RunAgain] " .. tostring(action) .. " failed: " .. tostring(a))
            return action == "Go" and false or { Show = false }, "Something went wrong."
        end
        return a, b
    end
    Players.PlayerRemoving:Connect(function(p) last[p] = nil end)
end

return RunAgain
