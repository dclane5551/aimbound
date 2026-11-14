--!nocheck
-- ============================================================================================
-- GUILD SERVICE (UPDATE 7 B9; Guilds module has the rules). Storage (live DataStore Guilds_v1, Studio in memory):
--   "G_<id>"   the guild { Id, Name, Tag, Color, Leader, Members = { [uid] = { Name, Rank, Gave } }, Requests = { [uid] = name },
--              Bank, Research = { [node] = level }, Created }
--   "N_<name>" lowercase name -> id (claimed atomically: no two guilds share a name)
--   "M_<uid>"  a player's guild id ("" = none): the truth for membership (kicks / approvals land even while you're offline)
-- Every write is an UpdateAsync. Each online member's guild is re-read every REFRESH s (state.GuildPerks + the name tag).
-- Remote GuildAction: Get / Create(name, tag) / Request(name) / Approve(uid) / Deny(uid) / Invite(playerName) / Accept(id) /
-- Leave / Kick(uid) / Promote(uid) / Donate(n) / Research(node) / SetColor(id). Event GuildInvite(id, name, from) to the invitee.
-- ============================================================================================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local Guilds = require(Shared:WaitForChild("Guilds"))

local GuildService = {}
GuildService.MEMORY = RunService:IsStudio()
GuildService.REFRESH = 120
local CombatServer
local mem = {}
local ds = nil
local invites = {} -- [player] = { [guildId] = { Name, From } } (this server only)
local busy = {}

local function DS()
    if not ds then ds = game:GetService("DataStoreService"):GetDataStore("Guilds_v1") end
    return ds
end
local function Get(key: string): any
    if GuildService.MEMORY then return mem[key] and HttpService:JSONDecode(mem[key]) or nil end
    local ok, v = pcall(function() return DS():GetAsync(key) end)
    return ok and v or nil
end
local function Update(key: string, fn: (any) -> any): (boolean, any)
    if GuildService.MEMORY then
        local old = mem[key] and HttpService:JSONDecode(mem[key]) or nil
        local new = fn(old)
        if new == nil then return false, old end
        mem[key] = HttpService:JSONEncode(new)
        return true, new
    end
    local wrote, out = false, nil
    local ok = pcall(function()
        DS():UpdateAsync(key, function(old)
            local new = fn(old)
            if new == nil then out = old; return nil end
            wrote, out = true, new
            return new
        end)
    end)
    return ok and wrote, out
end
local function Filter(text: string, uid: number): string?
    if GuildService.MEMORY then return text end
    local ok, res = pcall(function() return game:GetService("TextService"):FilterStringAsync(text, uid):GetNonChatStringForBroadcastAsync() end)
    if not ok or not res or string.find(res, "#", 1, true) then return nil end
    return res
end

-- (WIPE 5, main's default for the owner's morning review -- reversible): a crew made before the current save wipe keeps its
-- name, tag, colour, members and ranks, but its BANK gold, RESEARCH levels and members' donated totals (Gave) came from the
-- old economy and reset once (g.Wipe = the wipe it was last brought up to; a crew without it is from wipe 4)
local function WipeNow(): number
    local ok, SS = pcall(require, script.Parent:WaitForChild("SaveService"))
    return ok and SS.WIPE or 4
end
local function WipeFix(id: string, g: any): any
    local w = WipeNow()
    if type(g) ~= "table" or (tonumber(g.Wipe) or 4) >= w or w < 5 then return g end
    local _, new = Update("G_" .. id, function(old)
        if type(old) ~= "table" or (tonumber(old.Wipe) or 4) >= w then return nil end
        old.Bank, old.Research, old.Wipe = 0, {}, w
        for _, m in pairs(old.Members or {}) do if type(m) == "table" then m.Gave = 0 end end
        return old
    end)
    return type(new) == "table" and new or g
end
local function MyGuild(player: Player): (string?, any)
    local id = Get("M_" .. player.UserId)
    if type(id) ~= "string" or id == "" then return nil, nil end
    local g = Get("G_" .. id)
    if not g or not g.Members or not g.Members[tostring(player.UserId)] then return nil, nil end
    return id, WipeFix(id, g)
end
local function RankOf(g: any, uid: number): number
    local m = g and g.Members and g.Members[tostring(uid)]
    return m and (Guilds.RANKS[m.Rank] or 1) or 0
end
local function Count(t: any): number local n = 0 for _ in pairs(t or {}) do n += 1 end return n end

-- the player's state mirrors the guild (perks, tag) + the name tag
function GuildService.Refresh(player: Player)
    local state = CombatServer and CombatServer.GetState(player)
    if not state then return end
    local id, g = MyGuild(player)
    state.Guild = id
    state.GuildPerks = g and Guilds.Perks(g) or nil
    state.GuildTag = g and g.Tag or nil
    state.GuildColor = g and Guilds.ColorOf(g):ToHex() or nil
    player:SetAttribute("GuildTag", g and g.Tag or nil)
    player:SetAttribute("GuildColor", g and Guilds.ColorOf(g):ToHex() or nil)
    pcall(CombatServer.UpdatePlayerTitleTag, player)
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
end
local function RefreshMembers(g: any)
    for uid in pairs(g and g.Members or {}) do
        local p = Players:GetPlayerByUserId(tonumber(uid))
        if p then task.spawn(GuildService.Refresh, p) end
    end
end

-- the view the window shows
local function View(player: Player): any
    local id, g = MyGuild(player)
    local inv = {}
    for gid, v in pairs(invites[player] or {}) do table.insert(inv, { Id = gid, Name = v.Name, From = v.From }) end
    if not g then return { Guild = nil, Invites = inv } end
    return { Guild = g, MyRank = RankOf(g, player.UserId), Perks = Guilds.Perks(g), Invites = inv }
end

local function Join(player: Player, id: string): (boolean, string?)
    local ok, g = Update("G_" .. id, function(old)
        if not old or Count(old.Members) >= Guilds.MAX_MEMBERS then return nil end
        old.Members[tostring(player.UserId)] = { Name = player.DisplayName, Rank = "Member", Gave = 0 }
        if old.Requests then old.Requests[tostring(player.UserId)] = nil end
        return old
    end)
    if not ok then return false, "That crew is full or gone." end
    Update("M_" .. player.UserId, function() return id end)
    GuildService.Refresh(player)
    RefreshMembers(g)
    return true, "You joined " .. g.Name .. "."
end

function GuildService.Act(player: Player, action: any, a: any): (boolean, any)
    local state = CombatServer.GetState(player)
    if not state then return false, "?" end
    if action == "Get" then return true, View(player) end
    if (state.Level or 1) < Guilds.UNLOCK then return false, "Crews open at level " .. Guilds.UNLOCK .. "." end
    local id, g = MyGuild(player)
    local rank = RankOf(g, player.UserId)
    if action == "Create" then
        if id then return false, "Leave your crew first." end
        local name, tag = Guilds.CleanName(type(a) == "table" and a.Name), Guilds.CleanTag(type(a) == "table" and a.Tag)
        if not name then return false, "Names are " .. Guilds.NAME_MIN .. "-" .. Guilds.NAME_MAX .. " letters / numbers." end
        if not tag then return false, "Tags are " .. Guilds.TAG_MIN .. "-" .. Guilds.TAG_MAX .. " letters / numbers." end
        name = Filter(name, player.UserId); tag = tag and Filter(tag, player.UserId)
        if not name or not tag then return false, "That name isn't allowed." end
        if (state.Gold or 0) < Guilds.CREATE_COST then return false, "Founding a crew costs " .. ItemData.FormatNumber(Guilds.CREATE_COST) .. " gold." end
        local gid = HttpService:GenerateGUID(false)
        local claimed = Update("N_" .. string.lower(name), function(old) if old and old ~= "" then return nil end return gid end)
        if not claimed then return false, "A crew already has that name." end
        state.Gold -= Guilds.CREATE_COST
        Update("G_" .. gid, function() return { Id = gid, Name = name, Tag = tag, Color = "Steel", Leader = player.UserId, Created = os.time(), Bank = 0, Research = {}, Requests = {}, Wipe = WipeNow(),
            Members = { [tostring(player.UserId)] = { Name = player.DisplayName, Rank = "Leader", Gave = 0 } } } end)
        Update("M_" .. player.UserId, function() return gid end)
        GuildService.Refresh(player)
        return true, "Founded " .. name .. " [" .. tag .. "]."
    elseif action == "Request" then
        if id then return false, "Leave your crew first." end
        local gid = type(a) == "string" and Get("N_" .. string.lower(a)) or nil
        if type(gid) ~= "string" or gid == "" then return false, "No crew has that name." end
        local ok = Update("G_" .. gid, function(old)
            if not old then return nil end
            old.Requests = old.Requests or {}
            if Count(old.Requests) >= 30 then return nil end
            old.Requests[tostring(player.UserId)] = player.DisplayName
            return old
        end)
        if not ok then return false, "That crew isn't taking requests." end
        return true, "Request sent: an officer of that crew can let you in."
    elseif action == "Accept" then
        if id then return false, "Leave your crew first." end
        local inv = invites[player] and invites[player][tostring(a)]
        if not inv then return false, "That invite is gone." end
        invites[player][tostring(a)] = nil
        return Join(player, tostring(a))
    end
    if not g then return false, "You're not in a crew." end
    if action == "Approve" or action == "Deny" then
        if rank < 2 then return false, "Officers and the leader decide." end
        local uid = tonumber(a)
        if not uid or not (g.Requests or {})[tostring(uid)] then return false, "That request is gone." end
        if action == "Deny" then
            Update("G_" .. id, function(old) if old and old.Requests then old.Requests[tostring(uid)] = nil end return old end)
            return true, "Denied."
        end
        local pending = Get("M_" .. uid)
        if type(pending) == "string" and pending ~= "" then
            Update("G_" .. id, function(old) if old and old.Requests then old.Requests[tostring(uid)] = nil end return old end)
            return false, "They joined another crew."
        end
        local name = g.Requests[tostring(uid)]
        local ok = Update("G_" .. id, function(old)
            if not old or Count(old.Members) >= Guilds.MAX_MEMBERS then return nil end
            old.Requests[tostring(uid)] = nil
            old.Members[tostring(uid)] = { Name = name, Rank = "Member", Gave = 0 }
            return old
        end)
        if not ok then return false, "The crew is full." end
        Update("M_" .. uid, function() return id end)
        local p = Players:GetPlayerByUserId(uid)
        if p then GuildService.Refresh(p) end
        return true, tostring(name) .. " joined."
    elseif action == "Invite" then
        if rank < 2 then return false, "Officers and the leader invite." end
        local target
        for _, p in ipairs(Players:GetPlayers()) do
            if type(a) == "string" and (string.lower(p.Name) == string.lower(a) or string.lower(p.DisplayName) == string.lower(a)) then target = p end
        end
        if not target or target == player then return false, "Nobody by that name in this server." end
        invites[target] = invites[target] or {}
        invites[target][id] = { Name = g.Name, From = player.DisplayName }
        Remotes.GetEvent("GuildInvite"):FireClient(target, id, g.Name, player.DisplayName)
        return true, "Invited " .. target.DisplayName .. "."
    elseif action == "Leave" then
        local promoted = nil
        Update("G_" .. id, function(old)
            if not old then return nil end
            old.Members[tostring(player.UserId)] = nil
            if old.Leader == player.UserId then
                local best, bestRank = nil, 0
                for uid, m in pairs(old.Members) do
                    local r = Guilds.RANKS[m.Rank] or 1
                    if r > bestRank then best, bestRank = uid, r end
                end
                if best then old.Leader = tonumber(best); old.Members[best].Rank = "Leader"; promoted = old.Members[best].Name end
            end
            return old
        end)
        Update("M_" .. player.UserId, function() return "" end)
        if Count(g.Members) <= 1 then -- (the last one out: the name is free again)
            Update("N_" .. string.lower(g.Name), function() return "" end)
        end
        GuildService.Refresh(player)
        RefreshMembers(g)
        return true, "You left " .. g.Name .. "." .. (promoted and (" " .. promoted .. " leads it now.") or "")
    elseif action == "Kick" or action == "Promote" then
        local uid = tonumber(a)
        local target = uid and g.Members[tostring(uid)]
        if not target or uid == player.UserId then return false, "?" end
        local trank = Guilds.RANKS[target.Rank] or 1
        if action == "Kick" then
            if rank <= trank then return false, "You can only remove lower ranks." end
            Update("G_" .. id, function(old) if old then old.Members[tostring(uid)] = nil end return old end)
            Update("M_" .. uid, function() return "" end)
            local p = Players:GetPlayerByUserId(uid)
            if p then GuildService.Refresh(p) end
            return true, tostring(target.Name) .. " was removed."
        end
        if rank < 3 then return false, "Only the leader promotes." end
        local newRank = (target.Rank == "Officer") and "Member" or "Officer"
        Update("G_" .. id, function(old) if old and old.Members[tostring(uid)] then old.Members[tostring(uid)].Rank = newRank end return old end)
        return true, tostring(target.Name) .. " is now " .. string.lower(newRank) .. "."
    elseif action == "Donate" then
        local n = math.floor(tonumber(a) or 0)
        if n < 1000 then return false, "Donate at least 1,000 gold." end
        if (state.Gold or 0) < n then return false, "You don't have that much." end
        local ok = Update("G_" .. id, function(old)
            if not old or not old.Members[tostring(player.UserId)] then return nil end
            old.Bank = (old.Bank or 0) + n
            old.Members[tostring(player.UserId)].Gave = (old.Members[tostring(player.UserId)].Gave or 0) + n
            return old
        end)
        if not ok then return false, "Couldn't reach the crew. Try again." end
        state.Gold -= n
        Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
        return true, "Donated " .. ItemData.FormatNumber(n) .. " gold."
    elseif action == "Research" then
        if rank < 2 then return false, "Officers and the leader fund research." end
        local r = Guilds.ById[tostring(a)]
        if not r then return false, "?" end
        local lvl = (g.Research or {})[r.Id] or 0
        local cost = r.Costs[lvl + 1]
        if not cost then return false, r.Name .. " is fully researched." end
        local ok = Update("G_" .. id, function(old)
            if not old or (old.Bank or 0) < cost or ((old.Research or {})[r.Id] or 0) ~= lvl then return nil end
            old.Bank -= cost
            old.Research = old.Research or {}
            old.Research[r.Id] = lvl + 1
            return old
        end)
        if not ok then return false, "The bank needs " .. ItemData.FormatNumber(cost) .. " gold." end
        RefreshMembers(g)
        return true, r.Name .. " " .. (lvl + 1) .. " researched."
    elseif action == "SetColor" then
        if rank < 3 then return false, "Only the leader picks the colour." end
        local idx
        for i, c in ipairs(Guilds.TAG_COLORS) do if c.Id == a then idx = i end end
        if not idx or (idx > 1 and Guilds.Perks(g).Colors < idx - 1) then return false, "Research Crest Dyes for that colour." end
        Update("G_" .. id, function(old) if old then old.Color = a end return old end)
        RefreshMembers(g)
        return true, "Tag colour: " .. a .. "."
    end
    return false, "?"
end

-- (Studio tests: a fake player asks to join)
function GuildService._TestRequest(gid: string, uid: number, name: string)
    Update("G_" .. gid, function(old) if old then old.Requests = old.Requests or {}; old.Requests[tostring(uid)] = name end return old end)
end

function GuildService.Init(combat: any)
    CombatServer = combat
    Remotes.GetFunction("GuildAction").OnServerInvoke = function(player: Player, action: any, a: any)
        local now = os.clock()
        if action ~= "Get" and busy[player] and now - busy[player] < 0.4 then return false, "One moment..." end
        busy[player] = now
        return GuildService.Act(player, action, a)
    end
    Players.PlayerRemoving:Connect(function(p) invites[p] = nil; busy[p] = nil end)
    task.spawn(function()
        local last = {}
        while true do
            task.wait(5)
            for _, p in ipairs(Players:GetPlayers()) do
                if CombatServer.GetState(p) and (not last[p] or os.clock() - last[p] >= GuildService.REFRESH) then
                    last[p] = os.clock()
                    pcall(GuildService.Refresh, p)
                end
            end
            for p in pairs(last) do if not p.Parent then last[p] = nil end end
        end
    end)
end

return GuildService
