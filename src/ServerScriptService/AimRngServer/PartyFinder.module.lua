--!nocheck
-- ============================================================================================
-- PARTY FINDER (2026-10-20, owner: "lets do right at launch ... systems" + "make it work across servers"; servers hold 12).
-- Every PUBLIC lobby room (PartyService) that still has room is published to a shared board that every server reads:
-- MemoryStore sorted map PartyFinder_v1, key "<JobId>_<roomId>" -> summary { J JobId, R room id, H host name, U host UserId,
-- L host level, D run key, S bot skill, T trial?, N members, M max, P players in that server, At listed-at }. Each entry lives
-- TTL seconds and is re-written every REFRESH s (and 2 s after any room change), so a crashed server's rooms fade on their own.
-- Remote PartyFinderAction: ("List") -> true, { Rooms, Listed } | ("Join", jobId, roomId) -> ok, msg, here?
--   same server: PartyService.JoinRoom. Another server: TeleportAsync into that JobId with TeleportData { PF = { R, U } };
--   on arrival (PlayerAdded -> Arrive) the player is put in the room once their save is in (SaveService session lock: the
--   new server waits for the old one's final save). A failed teleport (full server ...) comes back as a message.
-- Studio: the board is an in-memory table (like the market); joins across servers can't teleport there --
-- DevCmd ["pffake", n] adds n fake listings from other servers, ["pfarrive", roomId] runs the arrival step on you.
-- ============================================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local PartyFinder = {}
PartyFinder.TTL = 75 -- seconds an entry lives without a refresh
PartyFinder.REFRESH = 20
PartyFinder.CACHE = 5 -- seconds a server reuses its last read of the board
PartyFinder.MAX_SERVER = 12 -- (owner 2026-10-20: servers hold 12 players)
PartyFinder.MEMORY = RunService:IsStudio()

local CombatServer, PartyService, SaveService
local JOB = (game.JobId ~= "" and game.JobId) or "studio"
local GOOD = Color3.fromRGB(120, 255, 160)

-- ===== the board =====
local mapObj
local function Map()
    if not mapObj then mapObj = game:GetService("MemoryStoreService"):GetSortedMap("PartyFinder_v1") end
    return mapObj
end
local mem = {} -- (Studio) key -> { V = summary, Exp = os.time() }
local function Put(key: string, v: any)
    if PartyFinder.MEMORY then mem[key] = { V = v, Exp = os.time() + PartyFinder.TTL }; return end
    pcall(function() Map():SetAsync(key, v, PartyFinder.TTL) end)
end
local function Drop(key: string)
    if PartyFinder.MEMORY then mem[key] = nil; return end
    pcall(function() Map():RemoveAsync(key) end)
end
local function GetOne(key: string): any
    if PartyFinder.MEMORY then local e = mem[key]; return (e and e.Exp > os.time()) and e.V or nil end
    local ok, v = pcall(function() return Map():GetAsync(key) end)
    return ok and v or nil
end
local function ReadAll(): { any }? -- (nil = the read failed: keep the last good board)
    local out = {}
    if PartyFinder.MEMORY then
        local now = os.time()
        for k, e in pairs(mem) do if e.Exp > now then table.insert(out, e.V) else mem[k] = nil end end
        return out
    end
    local upper = nil
    for _ = 1, 2 do
        local ok, page = pcall(function() return Map():GetRangeAsync(Enum.SortDirection.Descending, 200, nil, upper) end)
        if not ok then
            if upper == nil then warn("[PartyFinder] board read failed: " .. tostring(page)); return nil end
            break
        end
        if not page or #page == 0 then break end
        for _, e in ipairs(page) do table.insert(out, e.value) end
        if #page < 200 then break end
        upper = { key = page[#page].key } -- (the next page starts below the last key)
    end
    return out
end
local cache, cacheAt, reading = {}, -math.huge, false
local function Board(): { any }
    -- (one read at a time per server: a dozen players refreshing the window together share it; a failed / throttled read keeps
    -- the last good board and tries again after CACHE seconds)
    if os.clock() - cacheAt > PartyFinder.CACHE and not reading then
        reading = true
        local ok, res = pcall(ReadAll)
        reading = false
        if ok and res then cache = res end
        cacheAt = os.clock()
    end
    return cache
end

-- ===== this server's rooms =====
local function Eligible(room: any): boolean
    return room.Privacy == "Public" and room.State == "Lobby" and not room.Raid and #room.Members > 0
        and #room.Members < PartyService.MAX_MEMBERS
end
local function Summary(room: any): any
    local snap = PartyService.Snapshot(room)
    local lvl = 1
    for _, m in ipairs(snap.Members) do if m.IsHost then lvl = m.Level or 1 end end
    room.ListedAt = room.ListedAt or os.time()
    return { J = JOB, R = room.Id, H = room.HostName, U = room.HostUserId, L = lvl, D = room.Difficulty, S = room.BotSkill,
        T = room.Trial, N = #room.Members, M = snap.Max, P = #Players:GetPlayers(), At = room.ListedAt }
end
local published = {}
local function Publish()
    local seen = {}
    for id, room in pairs(PartyService.Rooms()) do
        if Eligible(room) then
            local key = JOB .. "_" .. id
            Put(key, Summary(room))
            seen[key] = true
        end
    end
    for key in pairs(published) do if not seen[key] then Drop(key) end end
    published = seen
end
local dirty = false
function PartyFinder.Dirty()
    if dirty then return end
    dirty = true
    task.delay(2, function() dirty = false; pcall(Publish) end)
end

-- ===== actions =====
function PartyFinder.List(player: Player): any
    local out, listed = {}, false
    local mine = PartyService.RoomOf(player)
    for _, e in ipairs(Board()) do
        if type(e) == "table" and e.J ~= JOB then e.Here = false; table.insert(out, e) end
    end
    for id, room in pairs(PartyService.Rooms()) do -- (this server: always fresh)
        if Eligible(room) then
            if room == mine then listed = true
            else
                local s = Summary(room)
                s.Here = true
                table.insert(out, s)
            end
        end
    end
    table.sort(out, function(a, b)
        if a.Here ~= b.Here then return a.Here end
        return (a.At or 0) > (b.At or 0)
    end)
    return { Rooms = out, Listed = listed }
end

local function InRun(player: Player): boolean
    return player:GetAttribute("RunId") ~= nil or player:GetAttribute("Lives") ~= nil
end

local teleporting = {} -- player -> os.clock() of a teleport in flight (no second teleport / join while one is on its way)
function PartyFinder.Join(player: Player, jobId: any, roomId: any): (boolean, string, boolean?)
    if type(jobId) ~= "string" or (type(roomId) ~= "string" and type(roomId) ~= "number") then return false, "?" end
    roomId = tostring(roomId)
    if InRun(player) then return false, "Finish your run first." end
    if teleporting[player] and os.clock() - teleporting[player] < 20 then return false, "You're already on your way to a party." end
    if jobId == JOB then
        local ok, res = PartyService.JoinRoom(player, roomId)
        if not ok then return false, tostring(res) end
        return true, "You joined the party.", true
    end
    local e = GetOne(jobId .. "_" .. roomId)
    if not e then return false, "That party has closed." end
    if (e.N or 0) >= (e.M or 4) then return false, "That party is full." end
    if (e.P or 0) >= PartyFinder.MAX_SERVER then return false, "That party's server is full." end
    if PartyFinder.MEMORY then return false, "Joining a party in another server only works in the live game." end
    PartyService.Leave(player)
    local opts = Instance.new("TeleportOptions")
    opts.ServerInstanceId = jobId
    opts:SetTeleportData({ PF = { R = roomId, U = e.U } })
    teleporting[player] = os.clock()
    local ok, err = pcall(function() TeleportService:TeleportAsync(game.PlaceId, { player }, opts) end)
    if not ok then
        teleporting[player] = nil
        warn("[PartyFinder] teleport failed: " .. tostring(err))
        return false, "Couldn't move you to that server. Try again."
    end
    return true, "Taking you to " .. tostring(e.H) .. "'s server..."
end

-- the arrival side: put a player who came through the finder into the room they picked
function PartyFinder.Arrive(player: Player, roomId: string)
    local function Say(p: Player, msg: string, col: Color3?) Remotes.GetEvent("CombatFx"):FireClient(p, "Text", msg, col) end
    local ready = false
    for _ = 1, 120 do -- (up to a minute: the old server's final save + this load)
        if not player.Parent then return end
        if SaveService.IsReady(player) then ready = true; break end
        task.wait(0.5)
    end
    if not ready then return end -- (the save never came in: SaveService kicks / retries; no room for a player without a save)
    task.wait(2) -- (the client builds its windows)
    if not player.Parent then return end
    local room = PartyService.Rooms()[tostring(roomId)]
    if not room then Say(player, "That party closed before you got here. Open PARTY FINDER for another one.") return end
    local ok, res = PartyService.JoinRoom(player, tostring(roomId))
    if not ok then Say(player, tostring(res) .. " Open PARTY FINDER for another one.") return end
    Say(player, "You joined " .. tostring(room.HostName) .. "'s party.", GOOD)
    for _, m in ipairs(room.Members) do
        if m ~= player then Say(m, player.DisplayName .. " joined your party from the Party Finder.", GOOD) end
    end
    Remotes.GetEvent("OpenMenu"):FireClient(player, "Dungeons") -- (the Dungeons window shows the party)
end

function PartyFinder.Dev(player: Player, cmd: string, a: any): string
    if cmd == "pffake" then
        if not PartyFinder.MEMORY then return "pffake only runs on the Studio board (it would list fake rooms in every live server)" end
        local BT = require(Shared:WaitForChild("BossTrials"))
        local diffs = { "Easy", "Hard", "Endless:Torment", "Cataclysm", "Normal" }
        for i = 1, math.clamp(tonumber(a) or 3, 1, 20) do
            local firstId = BT.ById and next(BT.ById)
            local trial = (i % 4 == 0) and firstId and { Id = firstId, Tier = 2 } or nil
            Put("fake-server-" .. i .. "_1", { J = "fake-server-" .. i, R = "1", H = "Tester" .. i, U = -i, L = 20 + i * 17, D = diffs[(i - 1) % #diffs + 1],
                S = 3 + i % 6, T = trial, N = 1 + i % 3, M = 4, P = (i == 3) and 12 or (3 + i), At = os.time() - i * 30 })
        end
        cacheAt = -math.huge
        return "added fake listings"
    elseif cmd == "pfroom" then -- a PUBLIC room of yours (a = run key, e.g. "Hard" / "Endless:Torment")
        local ok, snap = PartyService.CreateRoom(player, { Privacy = "Public", Difficulty = tostring(a or "Easy") })
        PartyFinder.Dirty()
        return ok and ("room " .. tostring(snap.Id)) or tostring(snap)
    elseif cmd == "pfboard" then -- what the board holds now (JSON)
        cacheAt = -math.huge
        return game:GetService("HttpService"):JSONEncode(PartyFinder.List(player))
    elseif cmd == "pfarrive" then
        task.spawn(PartyFinder.Arrive, player, tostring(a))
        return "arriving into room " .. tostring(a)
    end
    return "?"
end

function PartyFinder.Init(combat: any)
    CombatServer = combat
    PartyService = require(script.Parent:WaitForChild("PartyService"))
    SaveService = require(script.Parent:WaitForChild("SaveService"))
    PartyService.OnChanged = PartyFinder.Dirty
    local busy = {}
    Remotes.GetFunction("PartyFinderAction").OnServerInvoke = function(player: Player, action: any, a: any, b: any)
        if action == "List" then return true, PartyFinder.List(player) end -- (the board read is cached per server)
        local now = os.clock()
        if busy[player] and now - busy[player] < 0.5 then return false, "One moment..." end
        busy[player] = now
        if action == "Join" then return PartyFinder.Join(player, a, b) end
        return false, "?"
    end
    Players.PlayerRemoving:Connect(function(p) busy[p] = nil; teleporting[p] = nil; PartyFinder.Dirty() end)
    Players.PlayerAdded:Connect(function(p)
        PartyFinder.Dirty() -- (the player count on this server's entries)
        local okJ, jd = pcall(function() return p:GetJoinData() end)
        local td = okJ and type(jd) == "table" and jd.TeleportData or nil
        local pf = type(td) == "table" and td.PF or nil
        if type(pf) == "table" and pf.R ~= nil then task.spawn(PartyFinder.Arrive, p, tostring(pf.R)) end
    end)
    TeleportService.TeleportInitFailed:Connect(function(p, result, msg)
        teleporting[p] = nil
        if not p.Parent then return end
        local why = (result == Enum.TeleportResult.GameFull) and "That server is full now." or "Couldn't reach that server."
        warn("[PartyFinder] TeleportInitFailed " .. tostring(result) .. " " .. tostring(msg))
        Remotes.GetEvent("CombatFx"):FireClient(p, "Text", why .. " Pick another party.")
    end)
    task.spawn(function()
        while true do
            pcall(Publish)
            task.wait(PartyFinder.REFRESH)
        end
    end)
    game:BindToClose(function() for key in pairs(published) do Drop(key) end end)
end

return PartyFinder
