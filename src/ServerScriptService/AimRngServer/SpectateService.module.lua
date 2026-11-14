--!nocheck
-- ============================================================================================
-- SPECTATE (0.62, owner: "spectate feature: spectate players currently playing, accurate first-person spectating
-- showing their gun + skin"). From the hub city you pick a player who is in a run and watch through their eyes.
-- (0.79: or in a DUEL -- PvpService.Info gives the score / health / arena; SpectateFeed "Duel" streams it.)
--   * Rules: the watcher must be in the hub city (not in a run / hideout / duel); the target must be in a run (solo or
--     party) and allow it (Settings.AllowSpectate ~= false). Nobody can watch a watcher.
--   * Watcher attribute WatchUid = the target's UserId (InstanceKey: the watcher "is" in the target's instance, so
--     the target's body, gear and shots show for them; nobody sees the watcher). Target attribute Spectators = count.
--   * SOLO targets: their floor is built on THEIR client only, so the watcher builds the same floor from its config
--     (SpectateFeed "Floor" = DungeonRuns.FloorInfo + the target's look: gun, item, cosmetics) and the enemies as
--     puppets (SpectateFeed "Roster" when the set changes, SpectatePos ~8/s = positions + health).
--   * PARTY targets: their floor is server-built; DungeonClient shows it to the watcher (UpdateRunVisibility).
--   * Stops when the target's run ends, either player leaves, or the watcher walks into anything but the hub.
-- Client: AimRngShared/SpectateClient.
-- ============================================================================================
local Players = game:GetService("Players")
local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Zones = require(Shared:WaitForChild("Zones"))

local SpectateService = {}
SpectateService.TICK = 1 / 8

local Combat
local watching: { [Player]: Player } = {}
local sent: { [Player]: any } = {} -- watcher -> { Token, RosterKey }

local function DungeonRuns() return require(script.Parent:WaitForChild("DungeonRuns")) end
local function PvpS() return require(script.Parent:WaitForChild("PvpService")) end

-- is the player in a run we can show? -> "Solo" | "Party" | "Duel" | nil
-- (0.79, owner: "Add spectating to pvp too"): a duelist in the arena (countdown / live / result) is watchable too; the
-- arena is server-built, so like a party run the watcher just looks (InstanceKey "watch:pvp:<id>" sees the duel)
local function RunKind(p: Player): string?
    if not p.Parent then return nil end
    if p:GetAttribute("PvpDuel") then
        local ok, info = pcall(function() return PvpS().Info(p) end)
        return (ok and info) and "Duel" or nil
    end
    if p:GetAttribute("RunId") then return "Party" end
    if DungeonRuns().Get(p) then return "Solo" end
    return nil
end

local function InCity(p: Player): boolean
    if p:GetAttribute("RunId") or p:GetAttribute("PvpDuel") or p:GetAttribute("HideoutOf") then return false end
    if DungeonRuns().Get(p) then return false end
    local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    return root ~= nil and Zones.Kind((root :: BasePart).Position) == "city"
end

local function Allows(p: Player): boolean
    local st = Combat and Combat.GetState(p)
    return not (st and type(st.Settings) == "table" and st.Settings.AllowSpectate == false)
end

local function CountFor(t: Player)
    local n = 0
    for _, tt in pairs(watching) do if tt == t then n += 1 end end
    t:SetAttribute("Spectators", n > 0 and n or nil)
end

local function Stop(w: Player, why: string?)
    local t = watching[w]
    watching[w] = nil
    sent[w] = nil
    if w.Parent then
        w:SetAttribute("WatchUid", nil)
        Remotes.GetEvent("SpectateFeed"):FireClient(w, "Stop", why)
    end
    if t then CountFor(t) end
end
SpectateService.Stop = Stop

-- the target's look for the first-person gun: weapon item, base gun, cosmetics (skin / gloves / sleeves)
local function LookOf(t: Player): any
    local st = Combat and Combat.GetState(t)
    if not st then return nil end
    local duelGun = t:GetAttribute("PvpGun") -- (a duel's shared gun: their skin on it, not their run weapon's item)
    -- (0.83: their own settings -- the watcher's client mirrors the visual ones -- and health-bar style)
    local settings = {}
    if type(st.Settings) == "table" then
        for k, v in pairs(st.Settings) do
            if type(k) == "string" and string.sub(k, 1, 4) ~= "Key_" and type(v) ~= "table" then settings[k] = v end
        end
    end
    return { Weapon = (not duelGun) and st.EquippedWeapon or nil, BaseId = duelGun or (st.EquippedWeapon and st.EquippedWeapon.BaseId),
        Cos = st.CosmeticsEquipped, Colorways = st.Colorways, Class = st.Class, Level = st.Level, Settings = settings, BarStyle = t:GetAttribute("BarStyle") }
end

local function RosterOf(run: any): ({ any }, string)
    local list, ids = {}, {}
    for _, proxy in ipairs(run.Enemies and run.Enemies:GetChildren() or {}) do
        if not proxy:GetAttribute("Dead") then
            local a = proxy:GetAttributes()
            table.insert(list, a)
            table.insert(ids, tostring(a.EnemyId))
        end
    end
    table.sort(ids)
    return list, table.concat(ids, ",")
end

local function List(): { any }
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local kind = RunKind(p)
        if kind and not p:GetAttribute("WatchUid") and Allows(p) then
            local f = (kind == "Solo") and DungeonRuns().Get(p).Folder or nil
            local diff = f and f:GetAttribute("Difficulty") or p:GetAttribute("PartyDifficulty")
            local duel = (kind == "Duel") and PvpS().Info(p) or nil
            table.insert(out, { UserId = p.UserId, Name = p.DisplayName, Kind = kind, Level = (Combat.GetState(p) or {}).Level, Duel = duel,
                Floor = f and f:GetAttribute("Floor") or p:GetAttribute("PartyFloor"), Difficulty = diff, Biome = f and f:GetAttribute("Biome"),
                Rift = f and (f:GetAttribute("Rift") or 0) > 0, Watchers = p:GetAttribute("Spectators") or 0 })
        end
    end
    return out
end

SpectateService.List = List -- (DevCmd duelbot "info")

-- (DevCmd ["spectself", on]: Studio-only, watch YOURSELF in a bot duel -- tests the live-view stream / hit relay / look
-- mirror round trip with one player)
function SpectateService.DevSelf(p: Player, on: boolean): string
    if on then
        watching[p] = p
        sent[p] = { Dev = true }
        p:SetAttribute("WatchUid", p.UserId)
    else
        Stop(p)
    end
    CountFor(p)
    return "self-watch " .. tostring(on)
end

-- (0.83) the watched player's hit -> their watchers, stamped (the watcher plays it at that moment of the view)
function SpectateService.RelayHit(t: Player, data: any)
    local feed = Remotes.GetEvent("SpectateFeed")
    local d = table.clone(data)
    d.Stamp = workspace:GetServerTimeNow()
    for w, tt in pairs(watching) do
        if tt == t then feed:FireClient(w, "Hit", d) end
    end
end

function SpectateService.Init(combat: any)
    Combat = combat
    Remotes.GetFunction("SpectateAction").OnServerInvoke = function(w: Player, action: any, uid: any)
        if action == "List" then
            return true, List()
        elseif action == "Stop" then
            if watching[w] then Stop(w, nil) end
            return true
        elseif action == "Watch" then
            local t = Players:GetPlayerByUserId(tonumber(uid) or 0)
            if not t or t == w then return false, "That player isn't here." end
            if not InCity(w) and not watching[w] then return false, "Spectate from the city." end
            if not RunKind(t) then return false, t.DisplayName .. " isn't in a run right now." end
            if t:GetAttribute("WatchUid") then return false, t.DisplayName .. " is watching someone." end
            if not Allows(t) then return false, t.DisplayName .. " doesn't allow spectators." end
            local old = watching[w]
            watching[w] = t
            sent[w] = {}
            w:SetAttribute("WatchUid", t.UserId)
            if old and old ~= t then CountFor(old) end
            CountFor(t)
            return true, "Watching " .. t.DisplayName
        end
        return false, "?"
    end
    Players.PlayerRemoving:Connect(function(p)
        if watching[p] then Stop(p) end
        for w, t in pairs(watching) do if t == p then Stop(w, p.DisplayName .. " left.") end end
    end)
    -- (0.83 LIVE VIEW) the watched client's camera + seen enemies -> its watchers (cosmetic, unreliable, rate-capped)
    do
        local specCam = Remotes.GetEvent("SpecCam")
        local specWorld = Remotes.GetEvent("SpecWorld")
        local lastCam, lastWorld = {}, {}
        Players.PlayerRemoving:Connect(function(p) lastCam[p] = nil; lastWorld[p] = nil end)
        specCam.OnServerEvent:Connect(function(t: Player, stamp: any, cf: any, fov: any)
            if type(stamp) ~= "number" or typeof(cf) ~= "CFrame" or type(fov) ~= "number" or fov ~= fov then return end
            if not t:GetAttribute("Spectators") then return end
            local now = os.clock()
            if now - (lastCam[t] or 0) < 1 / 45 then return end
            lastCam[t] = now
            for w, tt in pairs(watching) do
                if tt == t then (specCam :: any):FireClient(w, t.UserId, stamp, cf, math.clamp(fov, 1, 120)) end
            end
        end)
        specWorld.OnServerEvent:Connect(function(t: Player, stamp: any, ids: any, poss: any)
            if type(stamp) ~= "number" or type(ids) ~= "table" or type(poss) ~= "table" or #ids > 16 then return end
            if not t:GetAttribute("Spectators") then return end
            local now = os.clock()
            if now - (lastWorld[t] or 0) < 1 / 20 then return end
            lastWorld[t] = now
            for w, tt in pairs(watching) do
                if tt == t then (specWorld :: any):FireClient(w, t.UserId, stamp, ids, poss) end
            end
        end)
    end
    -- the feed
    local feed = Remotes.GetEvent("SpectateFeed")
    local posEv = Remotes.GetEvent("SpectatePos")
    task.spawn(function()
        while true do
            task.wait(SpectateService.TICK)
            for w, t in pairs(watching) do
                local ok, err = pcall(function()
                    local kind = RunKind(t)
                    if not kind then Stop(w, t.DisplayName .. "'s run ended."); return end
                    -- the watcher must stay put in the city (their body waits there)
                    if not (sent[w] and sent[w].Dev) and (w:GetAttribute("RunId") or DungeonRuns().Get(w) or w:GetAttribute("HideoutOf") or w:GetAttribute("PvpDuel")) then Stop(w); return end
                    local s = sent[w]
                    -- the gun in their hands changed (swap, equip, skin): rebuild the first-person rig
                    local look = LookOf(t)
                    local SkinFX = require(Shared:WaitForChild("SkinFX"))
                    local lk = look and (tostring(look.BaseId) .. "|" .. tostring(look.Cos and look.BaseId and look.Cos[SkinFX.EquipKey(look.BaseId)]) .. "|" .. tostring(look.Weapon and look.Weapon.Uid)
                        .. "|" .. game:GetService("HttpService"):JSONEncode(look.Settings or {}) .. "|" .. tostring(look.BarStyle)
                        .. "|" .. game:GetService("HttpService"):JSONEncode(look.Cos or {})) or "" -- (0.83: a settings / cosmetics change re-sends the look)
                    if s.Token and s.LookKey ~= lk then feed:FireClient(w, "Look", look) end
                    s.LookKey = lk
                    if kind == "Duel" then
                        local info = PvpS().Info(t)
                        if not info then Stop(w, t.DisplayName .. "'s duel ended."); return end
                        local token = "pvp:" .. tostring(info.Id)
                        if s.Token ~= token then
                            s.Token, s.DuelKey = token, nil
                            feed:FireClient(w, "Floor", { Duel = true, Arena = info.Arena }, LookOf(t), t)
                        end
                        local dk = table.concat({ info.Phase, info.MyFrags, info.OppFrags, info.MyHP, info.OppHP, tostring(info.Sudden) }, "|")
                        if s.DuelKey ~= dk then
                            s.DuelKey = dk
                            feed:FireClient(w, "Duel", info)
                        end
                        return
                    end
                    if kind == "Party" then
                        local rid = t:GetAttribute("RunId")
                        if s.Token ~= rid then
                            s.Token = rid
                            feed:FireClient(w, "Floor", { Party = true, RunId = rid }, LookOf(t), t)
                        end
                        return
                    end
                    local run = DungeonRuns().Get(t)
                    local f = run.Folder
                    local token = tostring(f:GetAttribute("RunToken")) .. ":" .. tostring(f:GetAttribute("Floor"))
                    if s.Token ~= token then
                        s.Token, s.RosterKey = token, nil
                        feed:FireClient(w, "Floor", DungeonRuns().FloorInfo(run), LookOf(t), t)
                    end
                    local list, key = RosterOf(run)
                    -- (0.93: also every 3 s -- a roster the watcher dropped while its floor was building came back never)
                    if s.RosterKey ~= key or os.clock() - (s.RosterAt or 0) > 3 then
                        s.RosterKey, s.RosterAt = key, os.clock()
                        feed:FireClient(w, "Roster", list)
                    end
                    local pos = {}
                    for _, proxy in ipairs(run.Enemies:GetChildren()) do
                        local id = proxy:GetAttribute("EnemyId")
                        local at = run.Pos[proxy] or proxy:GetAttribute("SpawnPos")
                        if id and at and not proxy:GetAttribute("Dead") then
                            pos[tostring(id)] = { at, proxy:GetAttribute("Health"), proxy:GetAttribute("MaxHealth") }
                        end
                    end
                    ;(posEv :: any):FireClient(w, pos, t:GetAttribute("AimPitch"))
                end)
                if not ok then warn("[Spectate] " .. tostring(err)) end
            end
        end
    end)
end

return SpectateService
