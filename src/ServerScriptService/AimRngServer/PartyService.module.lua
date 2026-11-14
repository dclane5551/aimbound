--!nocheck
-- Dungeon lobby rooms (Dungeon Lootr-style): a player creates a room (Public = anyone can join,
-- Friends = only the host's Roblox friends), others browse and join (max 4), the host picks (biomes are mixed per floor)
-- difficulty / bot skill and starts. One player starting alone = a normal solo run on their own client.
--
-- Remotes: PartyRequest (RemoteFunction) action, args -> ok, result
--   "List"                      -> rooms you can see/join
--   "Create" { Privacy, Biome, Difficulty, BotSkill }
--   "Join" roomId | "Leave" | "Update" { ...same fields } (host) | "Kick" userId (host)
--   "Start" (host)              -> { Solo = true, Config } when alone (the client starts its own run)
-- PartyUpdate (RemoteEvent) -> each member: the room snapshot (nil after leaving)
-- PartyRoomsChanged (RemoteEvent) -> everyone: the room list changed (refresh if browsing)
local Players = game:GetService("Players")

local Remotes = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Remotes"))
local ItemData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ItemData"))
local BossTrials = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("BossTrials"))

local PartyService = {}
PartyService.MAX_MEMBERS = 4
-- RAIDS (owner 2026-10-05: "Add raids (8-12 players)"): a room with Raid = true holds up to 12 and needs 8 to start
-- (Studio: any number, for testing). PartyRuns plays it as RAID_FLOORS floors ending on a raid boss.
PartyService.RAID_MAX = 12
-- RAIDS OFF (owner 2026-10-05: "just remove raids for now, that will come later"): rooms can't become raids; the raid
-- code (PartyRuns RAID_FLOORS, BossAI raid orbs, LobbyMenu RAIDS_ON) stays for the return. true = back on.
PartyService.RAIDS_ON = false
PartyService.RAID_MIN = 8
PartyService.READY_SECONDS = 15 -- (QOL F4 READY CHECK: how long members have to answer before the leader can START ANYWAY)
local function MaxOf(room: any): number return room.Raid and PartyService.RAID_MAX or PartyService.MAX_MEMBERS end

local PartyRuns: any = nil
local CombatServer: any = nil
local rooms: { [string]: any } = {}
local roomOf: { [Player]: any } = {}
local nextId = 0
local VALID_BIOMES = { Fire = true, Ice = true, Void = true, Cyber = true, Storm = true, Dream = true, Flats = true }
do -- (0.87 WORLDS)
    local ok, WB = pcall(require, game:GetService("ReplicatedStorage"):WaitForChild("AimRngShared"):WaitForChild("WorldBiomes"))
    if ok then for _, id in ipairs(WB.LIST) do VALID_BIOMES[id] = true end end
end
local friendCache: { [string]: { Value: boolean, At: number } } = {}

local function IsFriend(a: Player, bUserId: number): boolean
    if a.UserId == bUserId then return true end
    local key = a.UserId .. ":" .. bUserId
    local c = friendCache[key]
    if c and os.clock() - c.At < 60 then return c.Value end
    local ok, v = pcall(function() return a:IsFriendsWith(bUserId) end)
    v = ok and v or false
    friendCache[key] = { Value = v, At = os.clock() }
    return v
end

local function Snapshot(room: any): any
    local members = {}
    for _, p in ipairs(room.Members) do
        local st = CombatServer.GetState(p)
        table.insert(members, { UserId = p.UserId, Name = p.DisplayName, Level = st.Level, IsHost = p.UserId == room.HostUserId })
    end
    return {
        Id = room.Id, HostUserId = room.HostUserId, HostName = room.HostName, Privacy = room.Privacy,
        Biome = room.Biome, Difficulty = room.Difficulty, BotSkill = room.BotSkill,
        State = room.State, Members = members, Max = MaxOf(room), Raid = room.Raid == true, RaidMin = PartyService.RAID_MIN,
        Trial = room.Trial, -- (BOSS ROOMS: { Id, Tier } -- a party gathered for a Boss Trial; the host starts it from the boss card)
        Ready = room.Ready and { Until = room.Ready.Until, Secs = PartyService.READY_SECONDS, Answers = (function() -- (QOL F4: READY CHECK; keys = tostring(userId))
            local a = {}
            for uid, v in pairs(room.Ready.Answers) do a[tostring(uid)] = v end
            return a
        end)() } or nil,
    }
end

local function Push(room: any)
    local snap = Snapshot(room)
    for _, p in ipairs(room.Members) do
        Remotes.GetEvent("PartyUpdate"):FireClient(p, snap)
        -- (the Challenges menu reads these: SOLO vs WITH PARTY on the trials)
        p:SetAttribute("PartySize", #room.Members)
        p:SetAttribute("PartyHost", room.HostUserId == p.UserId)
    end
    Remotes.GetEvent("PartyRoomsChanged"):FireAllClients()
    if PartyService.OnChanged then PartyService.OnChanged() end -- (PartyFinder: re-publish this server's rooms)
end

local function Sanitize(room: any, opts: any)
    if type(opts) ~= "table" then return end
    if opts.Privacy == "Public" or opts.Privacy == "Friends" then room.Privacy = opts.Privacy end
    if VALID_BIOMES[opts.Biome] then room.Biome = opts.Biome end
    if ItemData.ParseRunKey(opts.Difficulty) then room.Difficulty = opts.Difficulty end -- ("Torment" or "Endless:Torment")
    if type(opts.BotSkill) == "number" and opts.BotSkill == opts.BotSkill then room.BotSkill = math.clamp(math.floor(opts.BotSkill), 1, 10) end
    if not PartyService.RAIDS_ON then room.Raid = nil
    elseif type(opts.Raid) == "boolean" and (opts.Raid or #room.Members <= PartyService.MAX_MEMBERS) then room.Raid = opts.Raid end
    if room.Raid then room.Difficulty = (ItemData.ParseRunKey(room.Difficulty)) or "Easy" end -- (a raid is never Endless)
    -- BOSS ROOMS (owner 0.52: "You should be able to create a party at the bosses too, not only at the dungeons")
    if opts.Trial == false then room.Trial = nil
    elseif type(opts.Trial) == "table" and BossTrials.ById[opts.Trial.Id] and not BossTrials.ById[opts.Trial.Id].MapOnly and type(opts.Trial.Tier) == "number" then -- (MAPS V2: no maps-only boss rooms)
        local t = math.clamp(math.floor(opts.Trial.Tier), 1, BossTrials.MAX_TIER)
        room.Trial = { Id = opts.Trial.Id, Tier = t }
        room.Difficulty = BossTrials.Tiers[t].Difficulty
    end
end

local function Leave(player: Player)
    local room = roomOf[player]
    if not room then return end
    roomOf[player] = nil
    local i = table.find(room.Members, player)
    if i then table.remove(room.Members, i) end
    room.Ready = nil -- (QOL F4: someone left: the ready check is off)
    if player.Parent then
        Remotes.GetEvent("PartyUpdate"):FireClient(player, nil)
        player:SetAttribute("PartySize", 0)
        player:SetAttribute("PartyHost", false)
    end
    if #room.Members == 0 then
        rooms[room.Id] = nil
        Remotes.GetEvent("PartyRoomsChanged"):FireAllClients()
        if PartyService.OnChanged then PartyService.OnChanged() end
        return
    end
    if room.HostUserId == player.UserId then
        room.HostUserId = room.Members[1].UserId
        room.HostName = room.Members[1].DisplayName
    end
    Push(room)
end
PartyService.Leave = Leave

local function CanSee(player: Player, room: any): boolean
    if room.Privacy == "Public" then return true end
    return IsFriend(player, room.HostUserId)
end

local handlers = {}
function handlers.List(player: Player)
    local out = {}
    for _, room in pairs(rooms) do
        if roomOf[player] ~= room and CanSee(player, room) then table.insert(out, Snapshot(room)) end
    end
    table.sort(out, function(a, b) return a.Id < b.Id end)
    return true, out
end
function handlers.Create(player: Player, opts: any)
    Leave(player)
    nextId += 1
    local room = {
        Id = tostring(nextId), HostUserId = player.UserId, HostName = player.DisplayName,
        Privacy = "Public", Biome = "Fire", Difficulty = "Easy", BotSkill = 4, State = "Lobby", Members = { player },
    }
    room.OnRunEnded = function(r)
        r.State = "Lobby"
        if rooms[r.Id] then Push(r) end
    end
    Sanitize(room, opts)
    rooms[room.Id] = room
    roomOf[player] = room
    Push(room)
    return true, Snapshot(room)
end
function handlers.Join(player: Player, roomId: any)
    local room = rooms[tostring(roomId)]
    if not room then return false, "That room no longer exists." end
    if room.State ~= "Lobby" then return false, "That party is already in a dungeon." end
    if #room.Members >= MaxOf(room) then return false, "That room is full." end
    if not CanSee(player, room) then return false, "That room is friends-only." end
    Leave(player)
    table.insert(room.Members, player)
    roomOf[player] = room
    room.Ready = nil -- (QOL F4: a new member: ask again)
    Push(room)
    return true, Snapshot(room)
end
function handlers.Leave(player: Player)
    Leave(player)
    return true
end
function handlers.Update(player: Player, opts: any)
    local room = roomOf[player]
    if not room or room.HostUserId ~= player.UserId then return false, "Only the host can change the room." end
    if room.State ~= "Lobby" then return false, "The party is in a dungeon." end
    Sanitize(room, opts)
    room.Ready = nil -- (QOL F4: new settings: the ready check starts over)
    Push(room)
    return true, Snapshot(room)
end
-- (QOL F4) a member's answer to the READY CHECK (yes = true / false); everyone ready -> the run starts (the leader's START path)
function handlers.Ready(player: Player, yes: any)
    local room = roomOf[player]
    local rc = room and room.Ready
    if not rc or room.State ~= "Lobby" then return false, "There's no ready check right now." end
    rc.Answers[player.UserId] = (yes == true)
    for _, m in ipairs(room.Members) do
        if rc.Answers[m.UserId] ~= true then Push(room); return true end
    end
    local host = nil
    for _, m in ipairs(room.Members) do if m.UserId == room.HostUserId then host = m end end
    if host then
        local ok, why = handlers.Start(host)
        if not ok and host.Parent then Remotes.GetEvent("CombatFx"):FireClient(host, "Text", tostring(why), Color3.fromRGB(255, 190, 120)) end
    end
    return true
end
-- (QOL F4) the leader calls the ready check off
function handlers.ReadyCancel(player: Player)
    local room = roomOf[player]
    if not room or room.HostUserId ~= player.UserId or not room.Ready then return false end
    room.Ready = nil
    Push(room)
    return true
end
function handlers.Kick(player: Player, userId: any)
    local room = roomOf[player]
    if not room or room.HostUserId ~= player.UserId or room.State ~= "Lobby" then return false, "Only the host can kick." end
    for _, p in ipairs(room.Members) do
        if p.UserId == userId and p ~= player then
            Leave(p)
            return true
        end
    end
    return false, "Not in your room."
end
function handlers.Start(player: Player)
    local room = roomOf[player]
    if not room or room.HostUserId ~= player.UserId then return false, "Only the host can start." end
    if room.State ~= "Lobby" then return false, "Already in a dungeon." end
    -- every member needs the difficulty unlocked (ItemData.DifficultyUnlock)
    local diffId = ItemData.ParseRunKey(room.Difficulty)
    for _, m in ipairs(room.Members) do
        local ok, why = ItemData.DifficultyUnlock(CombatServer.GetState(m), diffId or "Easy")
        if not ok then return false, (m == player and "" or (m.DisplayName .. ": ")) .. tostring(why) end
    end
    if room.Raid and #room.Members < PartyService.RAID_MIN and not game:GetService("RunService"):IsStudio() then
        return false, string.format("A raid needs at least %d players (%d/%d).", PartyService.RAID_MIN, #room.Members, PartyService.RAID_MAX)
    end
    if #room.Members == 1 and not room.Raid then
        -- alone: a normal solo run on the player's own client
        return true, { Solo = true, Biome = room.Biome, Difficulty = room.Difficulty, BotSkill = room.BotSkill }
    end
    -- READY CHECK (QOL F4, 2026-10-28): the leader's START asks every member READY? for READY_SECONDS. Everyone ready = the run
    -- starts by itself; unanswered counts as not ready; once the timer runs out the leader can START ANYWAY.
    local rc = room.Ready
    if rc and workspace:GetServerTimeNow() > rc.Until + 60 then rc = nil end -- (QOL F4: an old, ignored check asks again)
    if not rc then
        local now = workspace:GetServerTimeNow()
        rc = { Until = now + PartyService.READY_SECONDS, Answers = { [player.UserId] = true } }
        room.Ready = rc
        Push(room)
        task.delay(PartyService.READY_SECONDS + 0.2, function() if room.Ready == rc and rooms[room.Id] then Push(room) end end) -- (clients: START ANYWAY)
        return true, { ReadyCheck = true }
    end
    local nReady = 0
    for _, m in ipairs(room.Members) do if rc.Answers[m.UserId] == true then nReady += 1 end end
    if nReady < #room.Members and workspace:GetServerTimeNow() < rc.Until then
        return false, string.format("Ready check: %d / %d ready. START ANYWAY opens when the timer runs out.", nReady, #room.Members)
    end
    room.Ready = nil
    room.State = "Running"
    Push(room)
    local run = PartyRuns.Start(room)
    if not run then
        room.State = "Lobby"
        Push(room)
        return false, "Couldn't start the dungeon."
    end
    for _, m in ipairs(room.Members) do -- (QOL F1: RUN AGAIN = this room again, started by its leader)
        pcall(function() require(script.Parent.RunAgain).Note(m, { Kind = "Party", RoomId = room.Id }) end)
    end
    return true, { Solo = false }
end

-- (QOL F1 RUN AGAIN) the leader's START, from the run summary / victory banner: the same checks as the Dungeons window
function PartyService.StartRoom(player: Player): (boolean, any)
    return handlers.Start(player)
end

function PartyService.RoomOf(player: Player): any
    return roomOf[player]
end

-- (2026-10-20 PARTY FINDER) the rooms of this server, a room's snapshot, and the same Join a JOIN button sends
function PartyService.Rooms(): { [string]: any } return rooms end
PartyService.Snapshot = Snapshot
function PartyService.JoinRoom(player: Player, roomId: any): (boolean, any) return handlers.Join(player, roomId) end
function PartyService.CreateRoom(player: Player, opts: any): (boolean, any) return handlers.Create(player, opts) end -- (Studio: DevCmd pfroom)

-- PARTY TRIALS (EndgameServer: a Boss Trial / Trial of Ascension started by the room's host): nil when the player isn't in
-- a room with others (they play it solo); else true / false, why
function PartyService.StartSpecial(player: Player, overrides: any): (boolean?, string?)
    local room = roomOf[player]
    if not room or #room.Members < 2 then return nil end
    if room.HostUserId ~= player.UserId then return false, "Only the room's host can start it for the party." end
    if room.State ~= "Lobby" then return false, "Your party is already in a dungeon." end
    if room.Raid then return false, "Raid rooms can't start trials. Switch the room back to a normal party." end
    room.State = "Running"
    Push(room)
    local run = PartyRuns.Start(room, overrides)
    if not run then
        room.State = "Lobby"
        Push(room)
        return false, "Couldn't start it."
    end
    return true
end

function PartyService.Init(combat: any, partyRuns: any)
    CombatServer = combat
    PartyRuns = partyRuns
    Remotes.GetFunction("PartyRequest").OnServerInvoke = function(player: Player, action: any, arg: any)
        local h = type(action) == "string" and handlers[action]
        if not h then return false, "Unknown action." end
        local ok, a, b = pcall(h, player, arg)
        if not ok then
            warn("[PartyService] " .. tostring(action) .. " failed: " .. tostring(a))
            return false, "Something went wrong."
        end
        return a, b
    end
    Players.PlayerRemoving:Connect(Leave)
end

return PartyService
