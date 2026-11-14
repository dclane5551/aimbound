--!nocheck
-- LIVE ERROR LOG (launch checklist: "Live error logging somewhere the owner can read it"). Script errors from every
-- server (ScriptContext.Error) and every player's client (ErrorReport -> remote "ReportError", rate limited) are
-- grouped by message, counted, and merged into one DataStore key every FLUSH seconds. The owner reads them in the F6
-- admin panel (ERRORS): AdminAction "Errors" -> list, "ClearErrors" -> wipes the store.
-- Studio play-tests keep the log in memory only (they never touch real data stores).
local ScriptContext = game:GetService("ScriptContext")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Remotes"))

local ErrorLog = {}
ErrorLog.FLUSH = 60          -- seconds between saves
ErrorLog.KEEP = 120          -- distinct errors kept in the store (most recent first)
ErrorLog.CLIENT_PER_MIN = 6  -- reports a player's client may send a minute
local STORE, KEY = "ErrorLog_v1", "all"

local useStore = not RunService:IsStudio()
local store = useStore and DataStoreService:GetDataStore(STORE) or nil
local pending = {}   -- [key] = entry not saved yet
local memory = {}    -- [key] = everything seen by this server (Studio reads this)
local budget = {}    -- [player] = { n, resetAt }

local function Clean(s: any, n: number): string
    s = tostring(s or "")
    s = s:gsub("[%c]", " ")
    return s:sub(1, n)
end
-- group messages that differ only by numbers / instance paths of players (Players.Name.PlayerGui...)
local function KeyOf(side: string, msg: string): string
    local k = msg:gsub("Players%.[%w_]+", "Players.<p>"):gsub("%d+%.?%d*", "#")
    return side .. "|" .. k:sub(1, 160)
end

function ErrorLog.Record(side: string, msg: any, trace: any, who: string?)
    msg, trace = Clean(msg, 300), Clean(trace, 600)
    if msg == "" then return end
    local key = KeyOf(side, msg)
    local now = os.time()
    for _, t in ipairs({ pending, memory }) do
        local e = t[key]
        if e then
            e.N += 1; e.Last = now
        else
            t[key] = { K = key, Side = side, M = msg, T = trace, N = 1, First = now, Last = now, V = game.PlaceVersion, Who = who }
        end
    end
end

local function Merge(into: { any }, from: { [string]: any })
    local byKey = {}
    for _, e in ipairs(into) do byKey[e.K] = e end
    for k, e in pairs(from) do
        local o = byKey[k]
        if o then
            o.N += e.N; o.Last = math.max(o.Last, e.Last); o.V = e.V; o.T = e.T; o.Who = e.Who or o.Who
        else
            table.insert(into, { K = e.K, Side = e.Side, M = e.M, T = e.T, N = e.N, First = e.First, Last = e.Last, V = e.V, Who = e.Who })
        end
    end
    table.sort(into, function(a, b) return a.Last > b.Last end)
    while #into > ErrorLog.KEEP do table.remove(into) end
    return into
end

local function Flush()
    if not next(pending) then return end
    local batch = pending
    pending = {}
    if not store then return end
    local ok = pcall(function()
        store:UpdateAsync(KEY, function(old)
            return Merge(type(old) == "table" and old or {}, batch)
        end)
    end)
    if not ok then -- (keep them for the next try)
        for k, e in pairs(batch) do
            if pending[k] then pending[k].N += e.N else pending[k] = e end
        end
    end
end

-- the list the admin panel shows: the store (live) or this server's memory (Studio), plus anything not saved yet
function ErrorLog.List(): { any }
    local list = {}
    if store then
        local ok, v = pcall(function() return store:GetAsync(KEY) end)
        if ok and type(v) == "table" then list = v end
        Merge(list, pending)
    else
        Merge(list, memory)
    end
    return list
end

function ErrorLog.Clear()
    pending, memory = {}, {}
    if store then pcall(function() store:RemoveAsync(KEY) end) end
end

function ErrorLog.Init()
    ScriptContext.Error:Connect(function(msg, trace)
        ErrorLog.Record("Server", msg, trace)
    end)
    Remotes.GetEvent("ReportError").OnServerEvent:Connect(function(p: Player, msg: any, trace: any)
        local b = budget[p]
        local now = os.clock()
        if not b or now > b.Reset then b = { N = 0, Reset = now + 60 }; budget[p] = b end
        if b.N >= ErrorLog.CLIENT_PER_MIN then return end
        b.N += 1
        ErrorLog.Record("Client", msg, trace, p.Name)
    end)
    Players.PlayerRemoving:Connect(function(p) budget[p] = nil end)
    task.spawn(function()
        while true do
            task.wait(ErrorLog.FLUSH)
            Flush()
        end
    end)
    game:BindToClose(function() Flush() end)
end

return ErrorLog
