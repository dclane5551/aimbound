--!nocheck
-- ============================================================================================
-- FRIEND INVITES, server (rules: AimRngShared/Referrals). Storage: DataStore Referrals_v1 key "R_<inviterUserId>" =
-- { List = { ["<friendUserId>"] = { N = name, At = time, Done = bool } } } (Studio: in-memory). The inviter may be offline:
-- the friend's server writes Done, the inviter's server pays it on their next check.
--   JOIN (a brand-new save + join data ReferredByPlayerId): checks friend list + account age -> state.ReferredBy
--     { Id, Name, Days = { utc days played }, Paid } (or { Id, Name, No = reason } when it doesn't count), the entry in R_<inviter>.
--   EVERY 60 s per player: the friend's qualify check (LEVEL + PLAY_SECONDS + DAYS) -> Done in R_<inviter> + REWARD_BP;
--     the inviter's collect (every 120 s): new Done entries -> REWARD_BP each (MAX_PAID friends), titles at 1 / 3 / 10.
-- state.Referrals { Paid = { [uid] = true (paid) | false (counted, over the cap) } } (PLAIN_FIELDS).
-- Remote ReferralAction ("Get") -> view for the INVITE FRIENDS window.
-- Studio: DevCmd ["refer", inviterId] (you join as their invite, checks shown), ["referskip", inviterId] (skip the
-- account-age / friend / new-save checks), ["referdays", n] / ["referplay", seconds], ["referdone", uid, name] (a friend
-- of yours finished), ["refercheck"] (run both checks now).
-- ============================================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local Referrals = require(Shared:WaitForChild("Referrals"))

local ReferralService = {}
ReferralService.MEMORY = RunService:IsStudio()
local CombatServer, SaveService
local GOOD = Color3.fromRGB(120, 255, 160)

-- ===== storage =====
local mem = {}
local ds
local function DS()
    if not ds then ds = game:GetService("DataStoreService"):GetDataStore("Referrals_v1") end
    return ds
end
local function Get(key: string): any
    if ReferralService.MEMORY then return mem[key] and HttpService:JSONDecode(mem[key]) or nil end
    local ok, v = pcall(function() return DS():GetAsync(key) end)
    return ok and v or nil
end
local function Update(key: string, fn: (any) -> any): boolean
    if ReferralService.MEMORY then
        local old = mem[key] and HttpService:JSONDecode(mem[key]) or nil
        local new = fn(old)
        if new == nil then return false end
        mem[key] = HttpService:JSONEncode(new)
        return true
    end
    local wrote = false
    local ok = pcall(function()
        DS():UpdateAsync(key, function(old)
            local new = fn(old)
            if new ~= nil then wrote = true end
            return new
        end)
    end)
    return ok and wrote
end

local function Say(p: Player, msg: string, col: Color3?) Remotes.GetEvent("CombatFx"):FireClient(p, "Text", msg, col) end
local function Sync(p: Player, st: any) Remotes.GetEvent("SyncPlayerState"):FireClient(p, st) end
local function PlaySeconds(st: any): number
    local stt = type(st.StatsTracking) == "table" and st.StatsTracking or {}
    local live = tonumber((st :: any)._PlayTick) and math.max(0, os.clock() - (st :: any)._PlayTick) or 0
    return (tonumber(stt.PlaySeconds) or 0) + live
end
local function NameOf(uid: number): string
    local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(uid) end)
    return ok and tostring(n) or ("Player " .. uid)
end

-- ===== the invited player =====
-- skip = { Age, Friend, New } (Studio tests only)
function ReferralService.OnJoin(player: Player, st: any, inviter: number, skip: any?)
    skip = skip or {}
    if type(st.ReferredBy) == "table" then return end -- (one inviter per player, for good)
    if not inviter or inviter <= 0 or inviter == player.UserId then return end
    local name = NameOf(inviter)
    local why
    if not skip.New and not SaveService.IsNewPlayer(player) then why = "you had played Aimbound before"
    elseif not skip.Age and player.AccountAge < Referrals.ACCOUNT_AGE then why = "your Roblox account is under " .. Referrals.ACCOUNT_AGE .. " days old"
    elseif not skip.Friend then
        local ok, isF = pcall(function() return player:IsFriendsWith(inviter) end)
        if not (ok and isF) then why = "you weren't on " .. name .. "'s friends list" end
    end
    if why then
        st.ReferredBy = { Id = inviter, Name = name, No = why }
        return
    end
    st.ReferredBy = { Id = inviter, Name = name, Days = { Referrals.Today() }, Paid = false }
    Update("R_" .. inviter, function(old)
        old = type(old) == "table" and old or {}
        old.List = type(old.List) == "table" and old.List or {}
        local n = 0
        for _ in pairs(old.List) do n += 1 end
        if old.List[tostring(player.UserId)] or n >= 100 then return nil end
        old.List[tostring(player.UserId)] = { N = player.DisplayName, At = os.time(), Done = false }
        return old
    end)
    Say(player, "You joined from " .. name .. "'s invite! Reach level " .. Referrals.LEVEL .. " (" .. (Referrals.PLAY_SECONDS // 3600)
        .. " hours on " .. Referrals.DAYS .. " days) and you both get " .. Referrals.REWARD_BP .. " BOUND points.", GOOD)
    local inv = Players:GetPlayerByUserId(inviter)
    if inv then Say(inv, player.DisplayName .. " joined from your invite. MENU > INVITE FRIENDS shows their progress.", GOOD) end
end

function ReferralService.CheckFriend(player: Player, st: any)
    local rb = type(st.ReferredBy) == "table" and st.ReferredBy or nil
    if not rb or rb.No or rb.Paid then return end
    rb.Days = type(rb.Days) == "table" and rb.Days or {}
    local today = Referrals.Today()
    if not table.find(rb.Days, today) then table.insert(rb.Days, today); while #rb.Days > 4 do table.remove(rb.Days, 1) end end
    if (st.Level or 1) < Referrals.LEVEL or PlaySeconds(st) < Referrals.PLAY_SECONDS or #rb.Days < Referrals.DAYS then return end
    local done = Update("R_" .. rb.Id, function(old)
        old = type(old) == "table" and old or {}
        old.List = type(old.List) == "table" and old.List or {}
        local e = old.List[tostring(player.UserId)] or { N = player.DisplayName, At = os.time() }
        if e.Done then return nil end
        e.Done = true
        e.DoneAt = os.time()
        old.List[tostring(player.UserId)] = e
        return old
    end)
    if not done and not ReferralService.MEMORY then
        -- (already marked Done: a second server raced it -- pay the friend once all the same)
        local cur = Get("R_" .. rb.Id)
        local e = cur and cur.List and cur.List[tostring(player.UserId)]
        if not (e and e.Done) then return end
    end
    rb.Paid = true
    CombatServer.GrantBoundPoints(player, st, Referrals.REWARD_BP)
    Say(player, "Welcome gift from " .. tostring(rb.Name) .. "'s invite: +" .. Referrals.REWARD_BP .. " BOUND points!", GOOD)
    Sync(player, st)
    local inv = Players:GetPlayerByUserId(rb.Id)
    if inv then task.spawn(ReferralService.Collect, inv, CombatServer.GetState(inv)) end
end

-- ===== the inviter =====
local viewCache = {} -- userId -> { At, Rec }: the window can't spend this server's DataStore read budget (one read / 10 s each)
function ReferralService.Collect(player: Player, st: any)
    if not st then return end
    local rec = Get("R_" .. player.UserId)
    if rec then viewCache[player.UserId] = { At = os.clock(), Rec = rec } end -- (the window shows this fresh read)
    local list = rec and type(rec.List) == "table" and rec.List or {}
    st.Referrals = type(st.Referrals) == "table" and st.Referrals or {}
    st.Referrals.Paid = type(st.Referrals.Paid) == "table" and st.Referrals.Paid or {}
    local paid = st.Referrals.Paid
    local changed = false
    for uid, e in pairs(list) do
        if type(e) == "table" and e.Done and paid[uid] == nil then
            local nPaid = 0
            for _, v in pairs(paid) do if v then nPaid += 1 end end
            if nPaid < Referrals.MAX_PAID then
                paid[uid] = true
                CombatServer.GrantBoundPoints(player, st, Referrals.REWARD_BP)
                Say(player, tostring(e.N or "Your friend") .. " got going in Aimbound: +" .. Referrals.REWARD_BP .. " BOUND points for inviting them!", GOOD)
            else
                paid[uid] = false
                Say(player, tostring(e.N or "Your friend") .. " got going in Aimbound! (BOUND rewards stop after " .. Referrals.MAX_PAID .. " friends.)", GOOD)
            end
            changed = true
        end
    end
    local n = 0
    for _ in pairs(paid) do n += 1 end
    st.UnlockedTitles = st.UnlockedTitles or {}
    for _, m in ipairs(Referrals.TITLES) do
        if n >= m.Need and not table.find(st.UnlockedTitles, m.Title) then
            table.insert(st.UnlockedTitles, m.Title)
            Say(player, "New title: " .. ((ItemData.Titles[m.Title] or {}).Title or m.Title) .. " (" .. m.Need .. " friend" .. (m.Need == 1 and "" or "s") .. " invited)", GOOD)
            changed = true
        end
    end
    if changed then Sync(player, st) end
end

-- ===== the window's view =====
function ReferralService.View(player: Player): any
    local st = CombatServer.GetState(player)
    if not st then return {} end
    local vc = viewCache[player.UserId]
    local rec
    if vc and os.clock() - vc.At < 10 then rec = vc.Rec
    else
        rec = Get("R_" .. player.UserId)
        viewCache[player.UserId] = { At = os.clock(), Rec = rec }
    end
    local mine = {}
    local paid = (type(st.Referrals) == "table" and type(st.Referrals.Paid) == "table") and st.Referrals.Paid or {}
    for uid, e in pairs(rec and rec.List or {}) do
        if type(e) == "table" then
            table.insert(mine, { Name = tostring(e.N or "?"), Done = e.Done == true, At = e.At or 0, Paid = paid[uid] == true })
        end
    end
    table.sort(mine, function(a, b) return (a.At or 0) > (b.At or 0) end)
    local by
    local rb = type(st.ReferredBy) == "table" and st.ReferredBy or nil
    if rb then
        by = { Name = rb.Name, No = rb.No, Paid = rb.Paid == true,
            Progress = Referrals.Progress(st.Level or 1, PlaySeconds(st), type(rb.Days) == "table" and #rb.Days or 0) }
    end
    local counted = 0
    for _ in pairs(paid) do counted += 1 end
    return { Mine = mine, Counted = counted, By = by }
end

function ReferralService.Dev(player: Player, cmd: string, a: any, b: any): string
    local st = CombatServer.GetState(player)
    if cmd == "refer" or cmd == "referskip" then
        st.ReferredBy = nil
        ReferralService.OnJoin(player, st, tonumber(a) or 1, cmd == "referskip" and { Age = true, Friend = true, New = true } or nil)
        Sync(player, st)
        return HttpService:JSONEncode(st.ReferredBy)
    elseif cmd == "referdays" then
        local rb = st.ReferredBy
        if type(rb) == "table" and type(rb.Days) == "table" then
            for i = 1, tonumber(a) or 1 do table.insert(rb.Days, 1, Referrals.Today() - i) end
        end
        return HttpService:JSONEncode(rb)
    elseif cmd == "referplay" then
        st.StatsTracking = st.StatsTracking or {}
        st.StatsTracking.PlaySeconds = (tonumber(st.StatsTracking.PlaySeconds) or 0) + (tonumber(a) or 3600)
        return "play " .. math.floor(PlaySeconds(st))
    elseif cmd == "referdone" then
        local uid = tostring(a or 99)
        Update("R_" .. player.UserId, function(old)
            old = type(old) == "table" and old or {}
            old.List = type(old.List) == "table" and old.List or {}
            old.List[uid] = { N = tostring(b or ("Friend" .. uid)), At = os.time(), Done = true }
            return old
        end)
        ReferralService.Collect(player, st)
        return "BP " .. tostring(st.BoundPoints) .. " titles " .. HttpService:JSONEncode(st.UnlockedTitles)
    elseif cmd == "refercheck" then
        ReferralService.CheckFriend(player, st)
        ReferralService.Collect(player, st)
        return HttpService:JSONEncode(ReferralService.View(player))
    end
    return "?"
end

function ReferralService.Init(combat: any)
    CombatServer = combat
    SaveService = require(script.Parent:WaitForChild("SaveService"))
    Remotes.GetFunction("ReferralAction").OnServerInvoke = function(player: Player, action: any)
        if action == "Get" then return true, ReferralService.View(player) end
        return false, "?"
    end
    local function Track(p: Player)
        task.spawn(function()
            local t0 = os.clock()
            while not SaveService.IsReady(p) do -- (a slow load -- the old server's lock -- can take over a minute)
                if not p.Parent or os.clock() - t0 > 600 then return end
                task.wait(0.5)
            end
            local st = CombatServer.GetState(p)
            if not st then return end
            local okJ, jd = pcall(function() return p:GetJoinData() end)
            local inviter = okJ and type(jd) == "table" and tonumber(jd.ReferredByPlayerId) or 0
            if inviter and inviter > 0 then pcall(ReferralService.OnJoin, p, st, inviter) end
            local n = 0
            while p.Parent do
                pcall(ReferralService.CheckFriend, p, st)
                if n % 2 == 0 then pcall(ReferralService.Collect, p, st) end
                n += 1
                task.wait(60)
            end
        end)
    end
    Players.PlayerAdded:Connect(Track)
    Players.PlayerRemoving:Connect(function(p) viewCache[p.UserId] = nil end)
    for _, p in ipairs(Players:GetPlayers()) do Track(p) end
end

return ReferralService
