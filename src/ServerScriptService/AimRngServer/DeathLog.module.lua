--!nocheck
-- DEATH RECAP (QOL PASS 2 R1, 2026-10-28; owner: "Do all 14 for now", audit 9 "you die and don't know what killed you").
-- CombatServer.DamagePlayer passes a SOURCE string per hit (an enemy's display name / "Boss: MOVE", "Hazard", Burn / Bleed
-- ticks): Add writes it into a fixed 5-slot ring per player (parallel arrays, made once per player -- no table per hit).
-- On a run death CombatServer calls Recap: the last hits of the last RECENT seconds, newest first, set on the Player as the
-- attribute "DeathRecap" (JSON, once per death) and kept on the run's RunStats record (the RUN SUMMARY's DEATH line).
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local DeathLog = {}
DeathLog.SLOTS = 5
DeathLog.RECENT = 30 -- (hits older than this before the death are left out)
DeathLog.MERGE = 1.2 -- (damage over time: ticks of the same source within this many seconds add up into one line)

local logs: { [Player]: any } = {}
local serial = 0

local function Log(player: Player): any
    local l = logs[player]
    if not l then
        l = { I = 0, N = 0, S = table.create(DeathLog.SLOTS, ""), D = table.create(DeathLog.SLOTS, 0), E = table.create(DeathLog.SLOTS, ""), T = table.create(DeathLog.SLOTS, 0) }
        logs[player] = l
    end
    return l
end

-- one landed hit (dmg = what it took from life + Ward); src = the source's name (nil = "Unknown"), el = its damage type
function DeathLog.Add(player: Player, src: string?, dmg: number, el: string?)
    if not dmg or dmg <= 0 then return end
    local l = Log(player)
    local now = os.clock()
    src = src or "Unknown"
    local i = l.I
    if i > 0 and (el == "Burn" or el == "Bleed") and l.S[i] == src and now - l.T[i] <= DeathLog.MERGE then
        l.D[i] += dmg -- (a DoT keeps ticking into its own line)
        l.T[i] = now
        return
    end
    i = (i % DeathLog.SLOTS) + 1
    l.I = i
    l.N = math.min(DeathLog.SLOTS, l.N + 1)
    l.S[i], l.D[i], l.E[i], l.T[i] = src, dmg, el or "Kinetic", now
end

-- the recap of the death that just happened: { K = killer, H = { { S, D, E, A = seconds before death }, ... newest first }, L = lives
-- left, N = serial }. Clears the log (the next death starts fresh).
function DeathLog.Recap(player: Player, livesLeft: number?): any
    local l = logs[player]
    local now = os.clock()
    local hits = {}
    if l then
        local i = l.I
        for _ = 1, l.N do
            local age = now - l.T[i]
            if age <= DeathLog.RECENT then
                table.insert(hits, { S = l.S[i], D = math.round(l.D[i]), E = l.E[i], A = math.round(age * 10) / 10 })
            end
            i = (i - 2) % DeathLog.SLOTS + 1
        end
        l.N, l.I = 0, 0
    end
    serial += 1
    return { K = hits[1] and hits[1].S or "Unknown", H = hits, L = livesLeft or 0, N = serial }
end

-- set the Player attribute (the client's life-lost card / OUT OF LIVES panel read it) and return the recap
function DeathLog.Publish(player: Player, livesLeft: number?): any
    local r = DeathLog.Recap(player, livesLeft)
    local ok, js = pcall(HttpService.JSONEncode, HttpService, r)
    if ok then player:SetAttribute("DeathRecap", js) end
    return r
end

-- a fresh run: no hits from the last one
function DeathLog.Clear(player: Player)
    local l = logs[player]
    if l then l.N, l.I = 0, 0 end
end

Players.PlayerRemoving:Connect(function(p) logs[p] = nil end)

return DeathLog
