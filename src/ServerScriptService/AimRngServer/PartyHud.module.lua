--!nocheck
-- ============================================================================================
-- PARTY HUD feed (QOL2 H4, 2026-10-28; audit: "you can't see how your teammates are doing"). NOT a revive.
-- For every player in a PARTY run (PartyRuns.RunOfPlayer, 2+ in the party) the server keeps two Player attributes that the
-- client's AimRngShared/PartyHud draws as small frames on the left:
--   PartyHud = the party's id (members of one party share it; nil solo / in the hub -> the frames hide)
--   HpPct    = health rounded to 5 % (0-100)
-- Lives / Downed / Spectating are the existing LIVES attributes (CombatServer). One loop, TICK (4x a second), and an attribute is
-- only written when its value CHANGED -- no per-hit remotes, nothing at all while nobody is in a party run.
-- ============================================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PartyHud = {}
PartyHud.TICK = 0.25

local CombatServer, PartyRuns

local function Set(p: Player, name: string, v: any)
    if p:GetAttribute(name) ~= v then p:SetAttribute(name, v) end
end

function PartyHud.Update(p: Player)
    local run = PartyRuns.RunOfPlayer(p)
    local members = run and PartyRuns.PartyMembers(run)
    -- (Studio: workspace attr DevPartyHudSolo = a 1-player party run counts, to test the feed alone)
    local min = (RunService:IsStudio() and workspace:GetAttribute("DevPartyHudSolo")) and 1 or 2
    if not run or not members or #members < min then
        Set(p, "PartyHud", nil)
        Set(p, "HpPct", nil)
        return
    end
    local st = CombatServer.GetState(p)
    local hp, max = st and tonumber(st.Health) or 0, st and tonumber(st.MaxHealth) or 0
    local pct = (max > 0) and math.clamp(math.floor(hp / max * 20 + 0.5) * 5, 0, 100) or 0
    if hp > 0 and pct == 0 then pct = 5 end -- (alive never reads 0)
    Set(p, "PartyHud", tostring(run.Party and run.Party.Id or run.Id))
    Set(p, "HpPct", pct)
end

function PartyHud.Init(combat: any)
    CombatServer = combat
    PartyRuns = require(script.Parent:WaitForChild("PartyRuns"))
    task.spawn(function()
        while true do
            task.wait(PartyHud.TICK)
            for _, p in ipairs(Players:GetPlayers()) do
                pcall(PartyHud.Update, p)
            end
        end
    end)
end

return PartyHud
