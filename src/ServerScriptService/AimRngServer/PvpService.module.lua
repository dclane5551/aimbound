--!nocheck
-- PvpService (0.59): one-on-one DUELS, the lightning-gun duel rules in PvpData. Everything runs on the server:
--   1. CHALLENGE: A picks a player, an arena and whether to WAGER gear. B gets a request (30 s) that says both.
--      Both must be out of runs and loaded. Each picks ANY gun in the DUEL window ("SetGun"; 0.60): every gun deals
--      PvpData.DPS at perfect aim (damage per shot = DPS / its fire rate), and duelists are stripped to the plain R6 body.
--   2. WAGER (only if both agreed to it): each side puts in up to PvpData.WAGER_MAX guns / gear (never equipped ones,
--      never the starter pistol), READY, then CONFIRM after a short lock (like trades). On confirm the items leave both
--      bags into ESCROW (state.PvpEscrow, saved: a server crash gives them back on the next load).
--   3. THE DUEL: an arena is built at a free slot far east of the city (Zones "pvp"), both are moved in, a countdown,
--      then first to PvpData.FRAGS_TO_WIN. Shots come in on PvpShot and are checked here (rate, range, line of sight,
--      the hit really near where the target was in the last 0.6 s). Vampiric healing, armour, respawns: PvpData.
--   4. THE END: the winner takes every wagered item; stats (state.PvpStats); both go home after the results screen.
-- Leaving / disconnecting mid-duel FORFEITS (SaveService.LeaveHooks runs this before the leave save, so a quitter's
-- escrow can never come back to them).
-- DUELS v3 (2026-10-14): a MODE per duel (PvpData.MODES: Classic / Rotation / Instagib; d.Mode, player attr PvpMode),
-- smaller standard bodies (PvpData.BODY_SCALE), HEALTH PICKUPS on the floor (PvpData.PICKUPS; d.Pickups).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local PvpData = require(Shared:WaitForChild("PvpData"))
local Zones = require(Shared:WaitForChild("Zones"))
local SaveService = require(script.Parent:WaitForChild("SaveService"))

local PvpService = {}
PvpService.REQUEST_LIFE = 30
PvpService.LOCK_SECONDS = 3

local Combat = nil
local duels = {} -- [party] = duel
local requests = {} -- [target Player] = { [from Player] = { At, Arena, Wager } }
local lastAsk = {}
local slots = {} -- [n] = duel
local nextId = 0
local history = {} -- [party] = { {t, pos}, ... } (root positions, newest last)

local HUB_CF = CFrame.lookAt(Vector3.new(0, 7.2, 24), Vector3.new(0, 7.2, 0))

-- ===== who is who (a Player, or the Studio DUEL BOT table { IsBot, Name, UserId, Model, State }) =====
local function IsBot(p: any): boolean return type(p) == "table" and p.IsBot == true end
local function StateOf(p: any): any
    if IsBot(p) then return p.State end
    return Combat and Combat.GetState(p)
end
local function NameOf(p: any): string
    if IsBot(p) then return p.Name end
    return p.DisplayName ~= "" and p.DisplayName or p.Name
end
local function CharOf(p: any): Model? if IsBot(p) then return p.Model end return p.Character end
local function RootOf(p: any): BasePart?
    local c = CharOf(p)
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function Attr(p: any, k: string, v: any)
    if IsBot(p) then if p.Model then p.Model:SetAttribute(k, v) end return end
    p:SetAttribute(k, v)
end
local function Get(p: any, k: string): any
    if IsBot(p) then return p.Model and p.Model:GetAttribute(k) end
    return p:GetAttribute(k)
end
local function Fire(p: any, ...)
    if IsBot(p) or not p.Parent then return end
    Remotes.GetEvent("PvpUpdate"):FireClient(p, ...)
end
local function Sync(p: any)
    if IsBot(p) then return end
    local st = StateOf(p)
    if st then Remotes.GetEvent("SyncPlayerState"):FireClient(p, st) end
end
local function Save(p: any)
    if IsBot(p) then return end
    task.spawn(function() SaveService.Save(p, StateOf(p), false) end)
end
local function Other(d: any, p: any): any return (d.A == p) and d.B or d.A end

-- can this player duel right now? -> ok, why
local function CanDuel(p: any): (boolean, string?)
    if IsBot(p) then return true end
    if not p or not p.Parent then return false, "That player left." end
    if not SaveService.IsReady(p) or not StateOf(p) then return false, "Still loading." end
    if duels[p] then return false, NameOf(p) .. " is already in a duel." end
    if p:GetAttribute("RunId") or p:GetAttribute("Downed") or p:GetAttribute("Spectating") then return false, NameOf(p) .. " is in a run." end
    local root = RootOf(p)
    if not root then return false, NameOf(p) .. " isn't spawned." end
    local kind = Zones.Kind(root.Position)
    if kind == "dungeon" or kind == "pvp" then return false, NameOf(p) .. " is busy." end
    return true
end

-- ===== the gun each duelist picked (0.60: any lineup gun; equal DPS) =====
local picks = {} -- [Player] = base id picked in the DUEL window (kept between duels this session)
local abilityPick = {} -- [Player] = PvpData.ABILITIES id picked in the DUEL window (ABILITIES 2026-10-15; kept this session)
local function ValidGun(id: any): boolean
    if type(id) ~= "string" then return false end
    for _, g in ipairs(PvpData.GunChoices()) do if g == id then return true end end
    return false
end
local function DefaultGun(p: any): string
    if picks[p] and ValidGun(picks[p]) then return picks[p] end
    local st = StateOf(p)
    local w = st and st.EquippedWeapon
    if w and ValidGun(w.BaseId) then return w.BaseId end
    return "AK47"
end

-- ===== wager items (same rules as trades) =====
local function FindItem(st: any, kind: string, uid: string): (any, number?)
    local list = (kind == "Weapon") and st.Inventory or st.GearInventory
    for i, it in ipairs(list or {}) do if it.Uid == uid then return it, i end end
    return nil
end
local function IsEquipped(st: any, kind: string, uid: string): boolean
    if kind == "Weapon" then return st.EquippedWeapon ~= nil and st.EquippedWeapon.Uid == uid end
    for _, g in pairs(st.EquippedGear or {}) do if type(g) == "table" and g.Uid == uid then return true end end
    return false
end
local function ItemProblem(st: any, kind: string, uid: string): string?
    if kind ~= "Weapon" and kind ~= "Gear" then return "Only guns and gear can be wagered." end
    if type(uid) ~= "string" or not FindItem(st, kind, uid) then return "That item isn't in your bag." end
    if IsEquipped(st, kind, uid) then return "Take it off first: equipped items can't be wagered." end
    if uid == "W_STARTER_PISTOL" then return "The starter pistol can't be wagered." end
    return nil
end
local function GiveItem(st: any, kind: string, it: any)
    st.Inventory = st.Inventory or {}
    st.GearInventory = st.GearInventory or {}
    if FindItem(st, kind, it.Uid) then it.Uid = ((kind == "Weapon") and "W_" or "G_") .. math.random(10000000, 99999999) end
    it.RunLoot = nil
    table.insert((kind == "Weapon") and st.Inventory or st.GearInventory, it)
end

-- what each side sees
local function Snapshot(d: any, viewer: any): any
    local function Side(p: any)
        local items = {}
        if not d.Escrow then -- (wager / locked: what's on offer; from the start: what's in escrow)
            local st = StateOf(p) or {}
            for _, e in ipairs(d.Offer[p].Items) do
                local it = FindItem(st, e.Kind, e.Uid)
                if it then table.insert(items, { Kind = e.Kind, Item = it }) end
            end
        else
            for _, e in ipairs(d.Escrow[p] or {}) do table.insert(items, e) end
        end
        return { Name = NameOf(p), UserId = p.UserId, Items = items, Ready = d.Ready[p] == true, Confirm = d.Confirm[p] == true,
            Frags = d.Frags[p] or 0, Shots = d.Shots[p] or 0, Hits = d.Hits[p] or 0, Dealt = math.floor(d.Dealt[p] or 0) }
    end
    local arena = PvpData.ArenaById[d.Arena]
    return {
        Id = d.Id, Phase = d.Phase, Arena = d.Arena, ArenaName = arena and arena.Name or d.Arena, Wager = d.Wager,
        Me = Side(viewer), Them = Side(Other(d, viewer)),
        ConfirmIn = (d.Phase == "Locked") and math.max(0, PvpService.LOCK_SECONDS - (os.clock() - d.LockAt)) or nil,
        LiveAt = d.LiveAt, EndsAt = d.EndsAt, Sudden = d.Sudden, Winner = d.Winner and NameOf(d.Winner) or nil,
        WinnerIsMe = d.Winner == viewer, Why = d.Why, Max = PvpData.WAGER_MAX, Need = PvpData.ModeOf(d.Mode).FragsToWin,
        Mode = PvpData.ModeOf(d.Mode).Id, ModeName = PvpData.ModeOf(d.Mode).Name, Round = d.Round,
    }
end
local function Push(d: any)
    Fire(d.A, "Duel", Snapshot(d, d.A))
    Fire(d.B, "Duel", Snapshot(d, d.B))
end

-- ===== arena slots =====
local function TakeSlot(d: any): number
    local n = 0
    while slots[n] do n += 1 end
    slots[n] = d
    return n
end

-- STANDARD BODIES (0.60): accessories, R6 packages (CharacterMesh) and body meshes come off for the duel (kept in
-- ServerStorage and put back after), so every duelist is the same plain R6 body; shots test those limbs
local ServerStorage = game:GetService("ServerStorage")
-- (0.77, owner: "Models also currently arent standardized, the same exact model size needs to be forced"): stripping
-- accessories wasn't enough -- avatars kept their own body package meshes and scale values (R15), so limbs differed. Now
-- every duelist gets ONE standard body: the default blocky parts at scale 1 (height / width / depth / head 1, proportion
-- and body type 0) with no accessories or body packages, only their own colours / clothes / face kept. Their applied description is stored and put
-- back after the duel.
local function StandardBody(p: any)
    local char = CharOf(p)
    if IsBot(p) or not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local box = ServerStorage:FindFirstChild("PvpBody_" .. p.UserId)
    if not box then box = Instance.new("Folder"); box.Name = "PvpBody_" .. p.UserId; box.Parent = ServerStorage end
    local ref = box:FindFirstChild("Char") or Instance.new("ObjectValue")
    ref.Name = "Char"; ref.Value = char; ref.Parent = box
    if hum and not box:FindFirstChild("Saved") then
        local okGet, saved = pcall(function() return hum:GetAppliedDescription() end)
        if okGet and saved then
            saved.Name = "Saved"; saved.Parent = box
            local std = Instance.new("HumanoidDescription")
            for _, k in ipairs({ "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor",
                "Shirt", "Pants", "GraphicTShirt", "Face" }) do std[k] = saved[k] end -- (colours + clothes: they don't change size)
            std.HeightScale, std.WidthScale, std.DepthScale, std.HeadScale = 1, 1, 1, 1
            std.ProportionScale, std.BodyTypeScale = 0, 0
            pcall(function() hum:ApplyDescription(std) end)
        end
    end
    for _, c in ipairs(char:GetChildren()) do -- (anything ApplyDescription didn't own: e.g. the game's own avatar shells)
        if c:IsA("Accessory") or c:IsA("CharacterMesh") then c.Parent = box end
    end
    -- (DUELS v3: every duelist at PvpData.BODY_SCALE -- a smaller target; their own scale comes back in RestoreBody)
    if box:GetAttribute("Scale") == nil then box:SetAttribute("Scale", char:GetScale()) end
    pcall(function() char:ScaleTo(PvpData.BODY_SCALE) end)
    -- (0.78, owner: "Text should NEVER appear in front of the crosshair"): no name tag over the head you're aiming at
    if hum then box:SetAttribute("NameShow", hum.DisplayDistanceType.Name); hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
end
local function RestoreBody(p: any)
    if IsBot(p) then return end
    local box = ServerStorage:FindFirstChild("PvpBody_" .. p.UserId)
    if not box then return end
    local char = p.Character
    local ref = box:FindFirstChild("Char")
    if char and ref and ref.Value == char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local saved = box:FindFirstChild("Saved")
        if box:GetAttribute("Scale") then pcall(function() char:ScaleTo(box:GetAttribute("Scale")) end) end
        if hum and saved and saved:IsA("HumanoidDescription") then pcall(function() hum:ApplyDescription(saved) end) end
        if hum and box:GetAttribute("NameShow") then pcall(function() hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType[box:GetAttribute("NameShow")] end) end
        for _, c in ipairs(box:GetChildren()) do
            if c:IsA("ObjectValue") or c:IsA("HumanoidDescription") then continue end
            if c:IsA("Accessory") and hum then pcall(function() hum:AddAccessory(c) end) else c.Parent = char end
        end
    end
    box:Destroy()
end
local function ClearHitbox(p: any)
    local char = CharOf(p)
    local hb = char and char:FindFirstChild("PvpHitbox")
    if hb then hb:Destroy() end
end

local function MoveTo(p: any, cf: CFrame)
    if IsBot(p) then
        if p.Model then p.Model:PivotTo(cf) end
        return
    end
    local char = p.Character
    if char then char:PivotTo(cf) end -- (the server's copy at once; the client is told too)
    Remotes.GetEvent("TeleportPlayer"):FireClient(p, "Goto", cf)
end

local function FullHealth(p: any)
    Attr(p, "PvpHP", PvpData.HEALTH)
    Attr(p, "PvpArmor", PvpData.ARMOR)
    Attr(p, "PvpDead", nil)
    Attr(p, "PvpShield", Workspace:GetServerTimeNow() + PvpData.SPAWN_SHIELD)
end

-- the spawn farthest from the other player (one of the two farthest, so it isn't predictable)
local function SpawnFor(d: any, p: any): CFrame
    local them = RootOf(Other(d, p))
    local list = {}
    for _, cf in ipairs(d.Spawns) do
        table.insert(list, { cf = cf, dist = them and (cf.Position - them.Position).Magnitude or math.random() })
    end
    table.sort(list, function(a, b) return a.dist > b.dist end)
    local pick = list[math.random(1, math.min(2, #list))]
    return pick.cf + Vector3.new(0, 1, 0)
end

-- ===== the end =====
local function Teardown(d: any)
    if d.TornDown then return end -- (once: Finish's delayed teardown may come after a dev restart already did it)
    d.TornDown = true
    for _, p in ipairs({ d.A, d.B }) do
        if duels[p] == d then duels[p] = nil end
        history[p] = nil
        ClearHitbox(p)
        RestoreBody(p)
        for _, k in ipairs({ "PvpDuel", "PvpHP", "PvpArmor", "PvpDead", "PvpShield", "PvpOpp", "PvpFrags", "PvpGun", "PvpMoveMult", "PvpMode", "PvpAbility", "PvpAbilityReady", "PvpGuardUntil", "PvpPulseUntil" }) do Attr(p, k, nil) end
        if IsBot(p) then
            if p.Model then p.Model:Destroy() end
        elseif p.Parent then
            MoveTo(p, HUB_CF)
            if Combat and Combat.RefreshWorldGear then pcall(Combat.RefreshWorldGear, p) end
        end
    end
    if d.Folder then d.Folder:Destroy() end
    if d.Slot ~= nil and slots[d.Slot] == d then slots[d.Slot] = nil end
end

local function Finish(d: any, winner: any?, why: string)
    if d.Phase == "Over" or d.Closed then return end
    d.Phase = "Over"
    d.Winner = winner
    d.Why = why
    -- the wager: the winner takes everything in escrow; no winner = everyone gets their own back
    local function Clear(p) local st = StateOf(p); if st then st.PvpEscrow = nil end end
    if d.Wager and d.Escrow then
        local names = {}
        for _, p in ipairs({ d.A, d.B }) do
            local to = winner or p
            local st = StateOf(to)
            if st then
                for _, e in ipairs(d.Escrow[p] or {}) do
                    GiveItem(st, e.Kind, e.Item)
                    table.insert(names, NameOf(p) .. " -> " .. NameOf(to) .. ": " .. tostring(e.Item.Rarity) .. " " .. tostring(e.Item.Name))
                end
            end
        end
        print("[PvP] duel #" .. d.Id .. " wager: " .. (#names > 0 and table.concat(names, "; ") or "nothing"))
    end
    Clear(d.A); Clear(d.B)
    for _, p in ipairs({ d.A, d.B }) do
        local st = StateOf(p)
        if st and winner then
            st.PvpStats = type(st.PvpStats) == "table" and st.PvpStats or {}
            local s = st.PvpStats
            s.W = (s.W or 0) + ((p == winner) and 1 or 0)
            s.L = (s.L or 0) + ((p ~= winner) and 1 or 0)
            s.Frags = (s.Frags or 0) + (d.Frags[p] or 0)
            s.Shots = (s.Shots or 0) + (d.Shots[p] or 0)
            s.Hits = (s.Hits or 0) + (d.Hits[p] or 0)
        end
        Sync(p); Save(p)
    end
    print("[PvP] duel #" .. d.Id .. " over: " .. (winner and NameOf(winner) or "nobody") .. " wins (" .. why .. ")")
    Push(d)
    task.delay(7, function()
        d.Closed = true
        Teardown(d)
    end)
end
PvpService.Finish = Finish

-- ===== hits =====
local function Frag(d: any, killer: any, victim: any)
    d.Frags[killer] = (d.Frags[killer] or 0) + 1
    Attr(killer, "PvpFrags", d.Frags[killer])
    Attr(victim, "PvpDead", true)
    local vr = RootOf(victim)
    Fire(d.A, "Frag", { Killer = NameOf(killer), Victim = NameOf(victim), Pos = vr and vr.Position })
    Fire(d.B, "Frag", { Killer = NameOf(killer), Victim = NameOf(victim), Pos = vr and vr.Position })
    local mode = PvpData.ModeOf(d.Mode)
    if d.Frags[killer] >= mode.FragsToWin or d.Sudden then
        Finish(d, killer, d.Sudden and "sudden death" or (d.Frags[killer] .. " frags"))
        return
    end
    if mode.Rotate then -- (GUN ROTATION: a new gun of another class for both after every frag)
        d.Round = (d.Round or 1) + 1
        d.SharedGun = PvpData.RotationGun(d.SharedGun)
        local msg = "ROUND " .. d.Round .. ":  " .. PvpData.GunLabel(d.SharedGun)
        for _, p in ipairs({ d.A, d.B }) do
            d.Gun[p] = d.SharedGun
            d.Guard[p] = { Tokens = 3, At = os.clock() }
            Attr(p, "PvpGun", d.SharedGun)
            Fire(p, "GunPicked", msg)
            if not IsBot(p) and Combat and Combat.RefreshWorldGear then pcall(Combat.RefreshWorldGear, p) end
        end
    end
    Push(d)
    task.delay(PvpData.RESPAWN, function()
        if d.Phase ~= "Live" then return end
        MoveTo(victim, SpawnFor(d, victim))
        FullHealth(victim)
    end)
end

local function Damage(d: any, shooter: any, victim: any, dmg: number, head: boolean?)
    if (Get(victim, "PvpGuardUntil") or 0) > Workspace:GetServerTimeNow() then dmg *= (1 - PvpData.GUARD_CUT) end -- (ABILITIES: GUARD)
    local hp, ar = Get(victim, "PvpHP") or 0, Get(victim, "PvpArmor") or 0
    local nhp, nar, dealt = PvpData.ApplyHit(hp, ar, dmg)
    Attr(victim, "PvpHP", nhp)
    Attr(victim, "PvpArmor", nar)
    d.Dealt[shooter] = (d.Dealt[shooter] or 0) + dealt
    d.Hits[shooter] = (d.Hits[shooter] or 0) + 1
    -- VAMPIRIC: half the damage dealt comes back as health, up to MAX_HEALTH (Quake's 200; over 100 it ticks down), never armour
    local shp = Get(shooter, "PvpHP") or 0
    local vamp = PvpData.ModeOf(d.Mode).Instagib and 0 or PvpData.VAMPIRIC -- (INSTAGIB: one hit, nothing to heal)
    if not Get(shooter, "PvpDead") then Attr(shooter, "PvpHP", math.max(shp, math.min(PvpData.MAX_HEALTH, shp + dealt * vamp))) end
    local sr = RootOf(shooter)
    Fire(shooter, "Hit", { Dmg = dealt, Heal = dealt * vamp, Head = head == true })
    if not IsBot(shooter) and shooter:GetAttribute("Spectators") then -- (0.83: a duel's watchers see the hit marker + number)
        local vr = RootOf(victim)
        pcall(function()
            require(script.Parent:WaitForChild("SpectateService")).RelayHit(shooter, { Damage = math.round(dealt * 10) / 10, Kind = "Hit",
                IsWeakSpot = head == true, Position = vr and (vr.Position + Vector3.new(0, 2.6, 0)) or nil })
        end)
    end
    Fire(victim, "Hurt", { Dmg = dealt, From = sr and sr.Position })
    if nhp <= 0 then Frag(d, shooter, victim) end
end

-- is (pos) inside the victim's hitbox as it was at some moment in the last 0.6 s (+ slack)? (the shooter's screen shows
-- the other player a little in the past: interpolation + both pings)
local REACH = PvpData.REACH + 2.5
local function WasThere(victim: any, pos: Vector3): (boolean, Vector3?)
    local h = history[victim]
    local now = os.clock()
    if not h then return false end
    for i = #h, 1, -1 do
        local e = h[i]
        if now - e[1] > 0.6 then break end
        if (e[2] + Vector3.new(0, PvpData.BODY_Y, 0) - pos).Magnitude <= REACH then return true, e[2] end
    end
    return false
end

local function ClearShot(d: any, from: Vector3, to: Vector3): boolean
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { d.Geo }
    local r = Workspace:Raycast(from, to - from, params)
    return r == nil or (r.Position - to).Magnitude < 2
end

-- one trigger pull: hits = how many of its pellets hit the opponent (1 for single-shot guns; true = 1)
local function OnShot(shooter: any, hitPos: any, hits: any, heads: any)
    local d = duels[shooter]
    if not d or d.Phase ~= "Live" then return end
    if Get(shooter, "PvpDead") then return end
    local gun = PvpData.GunStatsFor(d.Mode, d.Gun and d.Gun[shooter])
    -- rate: a token bucket at the picked gun's fire rate (+30%, 3 at once for jitter)
    local g = d.Guard[shooter]
    local now = os.clock()
    g.Tokens = math.min(3, g.Tokens + (now - g.At) * gun.Rate * 1.3)
    g.At = now
    if g.Tokens < 1 then return end
    g.Tokens -= 1
    d.Shots[shooter] = (d.Shots[shooter] or 0) + 1
    Attr(shooter, "PvpShield", nil) -- (firing drops your spawn shield)
    if hits == true then hits = 1 end
    hits = math.clamp(math.floor(tonumber(hits) or 0), 0, gun.Pellets)
    if hits <= 0 or typeof(hitPos) ~= "Vector3" then return end
    local victim = Other(d, shooter)
    if Get(victim, "PvpDead") then return end
    if (Get(victim, "PvpShield") or 0) > Workspace:GetServerTimeNow() then return end
    local sr = RootOf(shooter)
    if not sr then return end
    local eye = sr.Position + Vector3.new(0, 1.5, 0)
    if (eye - hitPos).Magnitude > PvpData.RANGE + 6 then return end
    local there, rootAt = WasThere(victim, hitPos)
    if not there then
        if not IsBot(shooter) then shooter:SetAttribute("PvpRejected", (shooter:GetAttribute("PvpRejected") or 0) + 1) end
        return
    end
    if not ClearShot(d, eye, hitPos) then return end
    -- (0.77 HEADSHOTS: pellets on the head deal HEADSHOT_MULT -- only if the reported hit is at head height)
    heads = math.clamp(math.floor(tonumber(heads) or 0), 0, hits)
    if heads > 0 and not (rootAt and hitPos.Y - rootAt.Y >= PvpData.HEAD_MIN_Y) then heads = 0 end
    d.Hits[shooter] = (d.Hits[shooter] or 0) + hits / gun.Pellets - 1 -- (Damage counts 1; a pellet volley counts its share)
    local hs = heads > 0 and heads * 2 >= hits -- (the volley "was a headshot" for the hit marker)
    Damage(d, shooter, victim, gun.PerShot * (hits + heads * (PvpData.HEADSHOT_MULT - 1)) / gun.Pellets, hs)
end
PvpService.OnShot = OnShot

-- ===== start =====
local function CombatServerHeal(p: Player)
    local st = StateOf(p)
    if st then st.IsReloading = false; st.CurrentMag = st.MaxMag end
end
local function CanDuel_InSetup(p: any): (boolean, string?)
    if IsBot(p) then return true end
    if not p.Parent then return false, "A player left." end
    if p:GetAttribute("RunId") then return false, NameOf(p) .. " is in a run." end
    return true
end
-- HEALTH PICKUPS (DUELS v3): a floating cross over a glowing pad at each PvpData.PICKUPS point, dropped onto the arena's
-- floor by a ray. Walk through it (alive, under the cap) to heal; it comes back after its Respawn.
local function BuildPickups(d: any, origin: Vector3, size: Vector3, spots: { any }?)
    d.Pickups = {}
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { d.Geo }
    local box = Instance.new("Folder"); box.Name = "Pickups"; box.Parent = d.Folder
    -- (ARENAS v3: an arena may name its own spots, { Kind, At }; Heal / Respawn come from PvpData.PICKUPS by Kind)
    local byKind = {}
    for _, k in ipairs(PvpData.PICKUPS) do byKind[k.Kind] = byKind[k.Kind] or k end
    local list = PvpData.PICKUPS
    if spots then
        list = {}
        for _, sp in ipairs(spots) do
            local k = byKind[sp.Kind] or PvpData.PICKUPS[1]
            table.insert(list, { Kind = sp.Kind, At = sp.At, Heal = k.Heal, Respawn = k.Respawn })
        end
    end
    for _, def in ipairs(list) do
        local x, z = def.At.X * size.X, def.At.Y * size.Z
        local r = Workspace:Raycast(origin + Vector3.new(x, size.Y + 5, z), Vector3.new(0, -(size.Y + 40), 0), params)
        if r then
            local mega = def.Kind == "Mega"
            local col = mega and Color3.fromRGB(80, 170, 255) or Color3.fromRGB(110, 255, 150)
            local base = r.Position + Vector3.new(0, 0.05, 0)
            local pad = Instance.new("Part")
            pad.Name = "Pad"; pad.Anchored = true; pad.CanCollide = false; pad.CanQuery = false; pad.CanTouch = false; pad.CastShadow = false
            pad.Shape = Enum.PartType.Cylinder; pad.Size = Vector3.new(0.15, mega and 5 or 3.6, mega and 5 or 3.6)
            pad.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.pi / 2); pad.Material = Enum.Material.Neon; pad.Color = col; pad.Transparency = 0.35
            pad.Parent = box
            local cross = Instance.new("Model"); cross.Name = mega and "MegaHealth" or "Health"
            local s = mega and 1.35 or 1
            for i, sz in ipairs({ Vector3.new(0.5, 1.6, 0.5), Vector3.new(1.6, 0.5, 0.5) }) do
                local c = Instance.new("Part")
                c.Name = "Cross" .. i; c.Anchored = true; c.CanCollide = false; c.CanQuery = false; c.CanTouch = false; c.CastShadow = false
                c.Size = sz * s; c.Material = Enum.Material.Neon; c.Color = col
                c.CFrame = CFrame.new(base + Vector3.new(0, 2.4, 0))
                c.Parent = cross
            end
            cross:SetAttribute("Spin", true) -- (the client turns it: PvpClient)
            cross.Parent = box
            table.insert(d.Pickups, { Def = def, Pos = base, Cross = cross, Pad = pad, ReadyAt = 0 })
        end
    end
end
local function PickupTick(d: any)
    local now = os.clock()
    for _, pk in ipairs(d.Pickups or {}) do
        local up = now >= pk.ReadyAt
        local want = up and 0 or 1
        for _, c in ipairs(pk.Cross:GetChildren()) do if c:IsA("BasePart") and c.Transparency ~= want then c.Transparency = want end end
        pk.Pad.Transparency = up and 0.35 or 0.8
        if up then
            for _, p in ipairs({ d.A, d.B }) do
                local r = RootOf(p)
                local hp = Get(p, "PvpHP") or 0
                if r and not Get(p, "PvpDead") and hp < PvpData.MAX_HEALTH
                    and (Vector3.new(r.Position.X, pk.Pos.Y, r.Position.Z) - pk.Pos).Magnitude <= PvpData.PICKUP_RADIUS and math.abs(r.Position.Y - pk.Pos.Y) < 6 then
                    Attr(p, "PvpHP", math.min(PvpData.MAX_HEALTH, hp + pk.Def.Heal))
                    pk.ReadyAt = now + pk.Def.Respawn
                    Fire(p, "Pickup", { Heal = pk.Def.Heal, Mega = pk.Def.Kind == "Mega" })
                    Fire(Other(d, p), "PickupOther", { Mega = pk.Def.Kind == "Mega" })
                    break
                end
            end
        end
    end
end

local function Begin(d: any)
    -- the wager goes into escrow first (taken out of both bags; saved, so a crash gives it back)
    d.Escrow = { [d.A] = {}, [d.B] = {} }
    if d.Wager then
        for _, p in ipairs({ d.A, d.B }) do
            local st = StateOf(p)
            for _, e in ipairs(d.Offer[p].Items) do
                local it, idx = FindItem(st, e.Kind, e.Uid)
                if it and not IsEquipped(st, e.Kind, e.Uid) then
                    table.remove((e.Kind == "Weapon") and st.Inventory or st.GearInventory, idx)
                    table.insert(d.Escrow[p], { Kind = e.Kind, Item = it })
                end
            end
            st.PvpEscrow = { Duel = d.Id, Items = d.Escrow[p] }
            Sync(p); Save(p)
        end
    end
    d.Slot = TakeSlot(d)
    local origin = PvpData.SlotOrigin(d.Slot)
    local folder = Instance.new("Folder")
    folder.Name = "PvpArena_" .. d.Id
    folder:SetAttribute("PvpDuel", tostring(d.Id))
    local root = Workspace:FindFirstChild("PvpWorld")
    if not root then root = Instance.new("Folder"); root.Name = "PvpWorld"; root.Parent = Workspace end
    folder.Parent = root
    local arena = PvpData.ArenaById[d.Arena] or PvpData.ARENAS[1]
    local built = arena.Build(folder, origin)
    d.Folder, d.Geo, d.Spawns = folder, folder:FindFirstChild("Geo"), built.spawns
    local mode = PvpData.ModeOf(d.Mode)
    d.Mode, d.Round = mode.Id, 1
    if mode.Pickups then
        local ok, err = pcall(BuildPickups, d, origin, built.size or Vector3.new(100, 40, 100), arena.Pickups)
        if not ok then warn("[PvP] pickups: " .. tostring(err)) end
    end
    d.Phase = "Countdown"
    d.LiveAt = Workspace:GetServerTimeNow() + PvpData.COUNTDOWN
    d.Guard = { [d.A] = { Tokens = 3, At = os.clock() }, [d.B] = { Tokens = 3, At = os.clock() } }
    -- the two spawns farthest apart
    local best, bi, bj = -1, 1, 2
    for i = 1, #d.Spawns do for j = i + 1, #d.Spawns do
        local dist = (d.Spawns[i].Position - d.Spawns[j].Position).Magnitude
        if dist > best then best, bi, bj = dist, i, j end
    end end
    d.Gun = {}
    if not (d.SharedGun and ValidGun(d.SharedGun)) then d.SharedGun = PvpData.RandomGun() end -- (0.77: ONE gun for both)
    if mode.Instagib then d.SharedGun = PvpData.INSTAGIB_GUN end
    for i, p in ipairs({ d.A, d.B }) do
        d.Gun[p] = d.SharedGun
        Attr(p, "PvpGun", d.Gun[p])
        Attr(p, "PvpMode", mode.Id)
        StandardBody(p)
        Attr(p, "PvpDuel", tostring(d.Id))
        Attr(p, "PvpOpp", Other(d, p).UserId)
        Attr(p, "PvpFrags", 0)
        Attr(p, "PvpMoveMult", PvpData.MOVE_MULT) -- (0.77: a little faster in duels)
        Attr(p, "PvpAbility", PvpData.AbilityOf(not IsBot(p) and abilityPick[p] or nil).Id) -- (ABILITIES: usable once the duel is live)
        Attr(p, "PvpAbilityReady", d.LiveAt)
        Attr(p, "PvpGuardUntil", nil); Attr(p, "PvpPulseUntil", nil)
        FullHealth(p)
        MoveTo(p, d.Spawns[(i == 1) and bi or bj] + Vector3.new(0, 1, 0))
        if not IsBot(p) then CombatServerHeal(p) end
    end
    Push(d)
    task.delay(PvpData.COUNTDOWN, function()
        if d.Phase ~= "Countdown" then return end
        d.Phase = "Live"
        d.EndsAt = Workspace:GetServerTimeNow() + PvpData.TIME_LIMIT
        FullHealth(d.A); FullHealth(d.B)
        Push(d)
        if d.Pickups and #d.Pickups > 0 then
            task.spawn(function()
                while d.Phase == "Live" and not d.Closed do
                    local ok, err = pcall(PickupTick, d)
                    if not ok then warn("[PvP] pickup tick: " .. tostring(err)); break end
                    task.wait(0.1)
                end
            end)
        end
    end)
end

local function Open(a: any, b: any, arena: string, wager: boolean, gun: string?, mode: string?): any
    nextId += 1
    local d = { Id = nextId, A = a, B = b, Arena = arena, Wager = wager, Phase = wager and "Wager" or "Setup", SharedGun = gun, Mode = PvpData.ModeOf(mode).Id,
        Offer = { [a] = { Items = {} }, [b] = { Items = {} } }, Ready = {}, Confirm = {}, Frags = {}, Shots = {}, Hits = {}, Dealt = {} }
    duels[a], duels[b] = d, d
    if wager then Push(d) else Begin(d) end
    return d
end
PvpService.Open = Open

local function Cancel(d: any, why: string)
    if d.Phase == "Wager" or d.Phase == "Locked" or d.Phase == "Setup" then
        d.Closed = true
        if duels[d.A] == d then duels[d.A] = nil end
        if duels[d.B] == d then duels[d.B] = nil end
        Fire(d.A, "Closed", why); Fire(d.B, "Closed", why)
        if IsBot(d.A) and d.A.Model then d.A.Model:Destroy() end
        if IsBot(d.B) and d.B.Model then d.B.Model:Destroy() end
    else
        -- mid-duel: whoever caused it forfeits (the caller passes the leaver via d.Leaver)
        local loser = d.Leaver
        Finish(d, loser and Other(d, loser) or nil, why)
    end
end

-- ===== actions (RemoteFunction PvpAction) =====
local function Act(player: any, action: string, a: any, b: any, c: any, e: any, f: any): (boolean, string?)
    if action == "Challenge" then
        local mode = PvpData.ModeOf(f) -- (DUELS v3: the mode, 6th argument)
        local gunPick = (e == "Random" or ValidGun(e)) and e or "Random" -- (0.77: "Random" or one gun, for BOTH duelists)
        local target = Players:GetPlayerByUserId(tonumber(a) or 0)
        local arena = (type(b) == "string" and PvpData.ArenaById[b]) and b or PvpData.ARENAS[1].Id
        local wager = c == true
        if not target or target == player then return false, "Pick another player." end
        local ok, why = CanDuel(player); if not ok then return false, why end
        ok, why = CanDuel(target); if not ok then return false, why end
        local tst = StateOf(target)
        if tst and tst.Settings and tst.Settings.AllowDuelRequests == false then return false, NameOf(target) .. " isn't taking duel requests." end
        lastAsk[player] = lastAsk[player] or {}
        if os.clock() - (lastAsk[player][target] or -99) < 4 then return false, "Wait a moment before asking again." end
        lastAsk[player][target] = os.clock()
        requests[target] = requests[target] or {}
        requests[target][player] = { At = os.clock(), Arena = arena, Wager = wager, Gun = gunPick, Mode = mode.Id }
        Fire(target, "Request", { From = NameOf(player), FromId = player.UserId, Arena = arena, ArenaName = PvpData.ArenaById[arena].Name,
            Wager = wager, Life = PvpService.REQUEST_LIFE, Gun = gunPick, Mode = mode.Id, ModeName = mode.Name,
            GunName = mode.Instagib and "RAIL" or (mode.Rotate and "ROTATING GUNS" or PvpData.GunLabel(gunPick)) })
        return true, "Duel challenge sent to " .. NameOf(target) .. "."
    elseif action == "Respond" then
        local from = Players:GetPlayerByUserId(tonumber(a) or 0)
        local list = requests[player]
        local r = from and list and list[from]
        if list and from then list[from] = nil end
        if not r or os.clock() - r.At > PvpService.REQUEST_LIFE then return false, "That challenge expired." end
        if b ~= true then Fire(from, "Declined", NameOf(player)); return true end
        local ok, why = CanDuel(player); if not ok then return false, why end
        ok, why = CanDuel(from); if not ok then return false, why end
        -- the gun: theirs (a RANDOM roll now), or a COUNTERPICK -> a coin flip between the two
        local theirs = (r.Gun == "Random" or not ValidGun(r.Gun)) and PvpData.RandomGun() or r.Gun
        local gun, how = theirs, (r.Gun == "Random") and "random roll" or (NameOf(from) .. "'s pick")
        if ValidGun(c) and c ~= theirs then
            local flip = math.random() < 0.5
            gun = flip and c or theirs
            how = "coin flip: " .. (flip and (NameOf(player) .. "'s counterpick") or ((r.Gun == "Random") and "the random roll" or (NameOf(from) .. "'s pick")))
        end
        local mode = PvpData.ModeOf(r.Mode)
        local msg = mode.Instagib and "INSTAGIB: one hit kills" or (mode.Rotate and ("GUN ROTATION  •  ROUND 1:  " .. PvpData.GunLabel(gun))
            or ("DUEL GUN: " .. PvpData.GunLabel(gun) .. "  (" .. how .. ")"))
        Fire(from, "GunPicked", msg); Fire(player, "GunPicked", msg)
        Open(from, player, r.Arena, r.Wager, gun, mode.Id)
        return true
    end
    if action == "SetAbility" then -- (ABILITIES: your pick for the next duels; not mid-duel)
        if not PvpData.AbilityById[a or ""] then return false, "Pick an ability from the list." end
        local cur = duels[player]
        if cur and not cur.Closed and cur.Phase == "Live" then return false, "Change your ability between duels." end
        abilityPick[player] = a
        if cur and not cur.Closed and cur.Phase == "Countdown" then Attr(player, "PvpAbility", a) end
        return true
    end
    if action == "SetGun" and not duels[player] then
        if not ValidGun(a) then return false, "Pick a gun from the list." end
        picks[player] = a
        return true
    end
    local d = duels[player]
    if not d or d.Closed then return false, "You're not in a duel." end
    if action == "Cancel" or action == "Forfeit" then
        d.Leaver = player
        Cancel(d, NameOf(player) .. ((action == "Forfeit") and " forfeited." or " cancelled the duel."))
        return true
    elseif action == "UseAbility" then -- (ABILITIES: server checks the phase + cooldown; BLINK's move is the client's own)
        if d.Phase ~= "Live" then return false, "Not yet." end
        if Get(player, "PvpDead") then return false end
        local now = Workspace:GetServerTimeNow()
        if now < (Get(player, "PvpAbilityReady") or 0) - 0.1 then return false, "Not ready." end
        local ab = PvpData.AbilityOf(Get(player, "PvpAbility"))
        Attr(player, "PvpAbilityReady", now + ab.Cooldown)
        if ab.Id == "Guard" then Attr(player, "PvpGuardUntil", now + PvpData.GUARD_TIME)
        elseif ab.Id == "Pulse" then Attr(player, "PvpPulseUntil", now + PvpData.PULSE_TIME) end
        Fire(Other(d, player), "OppAbility", ab.Id) -- (your opponent hears / sees it go off)
        return true, ab.Id
    elseif action == "SetGun" then
        return false, "Both duelists use the same gun: it was set when the duel was accepted." -- (0.77)
    elseif action == "SetItem" then
        if d.Phase ~= "Wager" then return false, "Unready first to change your wager." end
        local kind, uid, on = a, b, c == true
        local mine = d.Offer[player].Items
        local at = nil
        for i, e in ipairs(mine) do if e.Kind == kind and e.Uid == uid then at = i end end
        if on then
            if at then return true end
            if #mine >= PvpData.WAGER_MAX then return false, "Up to " .. PvpData.WAGER_MAX .. " items each." end
            local why = ItemProblem(StateOf(player), kind, uid)
            if why then return false, why end
            table.insert(mine, { Kind = kind, Uid = uid })
        elseif at then
            table.remove(mine, at)
        end
        d.Ready, d.Confirm = {}, {}
        Push(d)
        return true
    elseif action == "Ready" then
        if d.Phase ~= "Wager" and d.Phase ~= "Locked" then return false end
        if a == false then d.Ready, d.Confirm, d.Phase = {}, {}, "Wager"; Push(d); return true end
        for _, p in ipairs({ d.A, d.B }) do
            for _, e in ipairs(d.Offer[p].Items) do
                if ItemProblem(StateOf(p), e.Kind, e.Uid) then return false, NameOf(p) .. "'s wager changed: check it again." end
            end
        end
        d.Ready[player] = true
        if d.Ready[d.A] and d.Ready[d.B] then d.Phase = "Locked"; d.LockAt = os.clock() end
        Push(d)
        return true
    elseif action == "Confirm" then
        if d.Phase ~= "Locked" then return false, "Both of you need to be ready." end
        if os.clock() - d.LockAt < PvpService.LOCK_SECONDS - 0.05 then return false, "Read the wager first." end
        d.Confirm[player] = true
        if d.Confirm[d.A] and d.Confirm[d.B] then
            for _, p in ipairs({ d.A, d.B }) do
                local ok, why = CanDuel_InSetup(p)
                if not ok then return false, why end
            end
            Begin(d)
        else
            Push(d)
        end
        return true
    end
    return false, "Unknown duel action."
end
PvpService.Act = Act

-- ===== Studio DUEL BOT (DevCommands "duelbot"): a moving, shooting dummy so one person can test duels =====
local function MakeBotModel(): Model
    local m = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
    m.Name = "DuelBot"
    for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.Color = Color3.fromRGB(200, 60, 80) end end
    pcall(function() m:ScaleTo(PvpData.BODY_SCALE) end) -- (DUELS v3: the same size as a duelist)
    m.Parent = Workspace
    return m
end
local function RunBot(d: any, bot: any, acc: number)
    task.spawn(function()
        local hum = bot.Model:FindFirstChildOfClass("Humanoid")
        local nextMove, lastShot = 0, 0
        while bot.Model.Parent and not d.Closed do
            local dt = task.wait(1 / PvpData.FIRE_RATE)
            local me, them = RootOf(bot), RootOf(Other(d, bot))
            if d.Phase == "Live" and me and them and not Get(bot, "PvpDead") then
                if os.clock() > nextMove and hum then
                    nextMove = os.clock() + 1 + math.random() * 1.5
                    local side = (them.Position - me.Position):Cross(Vector3.yAxis).Unit * (math.random() < 0.5 and -14 or 14)
                    hum:MoveTo(me.Position + side + (them.Position - me.Position).Unit * (math.random() * 10 - 3))
                end
                local dist = (them.Position - me.Position).Magnitude
                if dist <= PvpData.RANGE and not Get(Other(d, bot), "PvpDead") and ClearShot(d, me.Position + Vector3.new(0, 1.5, 0), them.Position) then
                    -- the bot "hits" by a coin flip at its accuracy; its shot lands on where you are
                    local hit = math.random() < acc
                    OnShot(bot, hit and (them.Position + Vector3.new(0, PvpData.BODY_Y, 0)) or me.Position, hit and 1 or 0)
                    local shot = { From = me.Position + Vector3.new(0, 1.5, 0), To = hit and them.Position or them.Position + Vector3.new(math.random(-6, 6), math.random(-2, 4), math.random(-6, 6)) }
                    Fire(Other(d, bot), "BotShot", shot)
                    local foe = Other(d, bot)
                    for _, w in ipairs(Players:GetPlayers()) do -- (0.79: spectators of the duel see the bot's shots too)
                        if not IsBot(foe) and w:GetAttribute("WatchUid") == foe.UserId then Remotes.GetEvent("PvpUpdate"):FireClient(w, "BotShot", shot) end
                    end
                end
            end
            local _ = dt + lastShot
        end
    end)
end
function PvpService.DevBot(player: Player, arena: string?, acc: number?, wager: boolean?, mode: string?): string
    if not RunService:IsStudio() then return "studio only" end
    local d = duels[player]
    if d then d.Leaver = nil; Finish(d, nil, "restart"); d.Closed = true; Teardown(d) end
    local st = { Inventory = {}, GearInventory = {}, EquippedGear = {}, Settings = {} }
    local w = ItemData.GenerateWeaponOfBase("AK47", "Rare", 1) -- (RARITY v4: was Legendary)
    if w then table.insert(st.Inventory, w) end
    local bot = { IsBot = true, Name = "DuelBot", UserId = -1, State = st, Model = MakeBotModel() }
    local dd = Open(player, bot, arena or "Rooftops", wager == true, nil, mode)
    RunBot(dd, bot, acc or 0.3)
    if wager then
        Act(bot, "SetItem", "Weapon", w.Uid, true)
        Act(bot, "Ready", true)
    end
    return "duel vs bot #" .. dd.Id .. " (" .. dd.Arena .. ", " .. tostring(dd.Mode) .. ", bot accuracy " .. tostring(acc or 0.3) .. (wager and ", wager: bot put in a Rare AK; it's ready" or "") .. ")"
end
function PvpService.DevBotConfirm(player: Player): string
    local d = duels[player]
    if not d then return "no duel" end
    local bot = Other(d, player)
    if not IsBot(bot) then return "not a bot duel" end
    if d.Phase == "Wager" then
        local ok, why = Act(bot, "Ready", true)
        return "bot ready: " .. tostring(ok) .. " " .. tostring(why) .. " (phase " .. d.Phase .. ")"
    end
    local ok, why = Act(bot, "Confirm")
    return "bot confirm: " .. tostring(ok) .. " " .. tostring(why)
end
function PvpService.DevState(player: Player): string
    local d = duels[player]
    if not d then return "no duel" end
    local o = Other(d, player)
    return string.format("#%d %s phase=%s me hp=%s ar=%s frags=%d shots=%d hits=%d | %s hp=%s ar=%s frags=%d | rejected=%s",
        d.Id, d.Arena, d.Phase, tostring(Get(player, "PvpHP")), tostring(Get(player, "PvpArmor")), d.Frags[player] or 0, d.Shots[player] or 0, d.Hits[player] or 0,
        NameOf(o), tostring(Get(o, "PvpHP")), tostring(Get(o, "PvpArmor")), d.Frags[o] or 0, tostring(player:GetAttribute("PvpRejected")))
end

function PvpService.InDuel(p: Player): boolean return duels[p] ~= nil end
-- (owner 2026-11-06) is this item (by Uid) in p's wager of a duel that isn't over? CombatServer.TradeHold refuses crafts on it
function PvpService.Offered(p: Player, uid: any): boolean
    local d = duels[p]
    if not d or d.Phase == "Over" or d.Closed or type(uid) ~= "string" or type(d.Offer) ~= "table" then return false end
    for _, e in ipairs((d.Offer[p] or {}).Items or {}) do if e.Uid == uid then return true end end
    return false
end

-- (0.79 SPECTATE, owner: "Add spectating to pvp too"): a duel's public numbers for SpectateService -- only once both are
-- in the arena (Countdown / Live / the result screen), never during the wager setup
function PvpService.Info(p: Player): any
    local d = duels[p]
    if not d or d.Closed or not (d.Phase == "Countdown" or d.Phase == "Live" or d.Phase == "Over") then return nil end
    local o = Other(d, p)
    return { Id = d.Id, Phase = d.Phase, Arena = (PvpData.ArenaById[d.Arena] or {}).Name or tostring(d.Arena), Gun = PvpData.GunLabel(d.SharedGun),
        Opp = NameOf(o), MyFrags = d.Frags[p] or 0, OppFrags = d.Frags[o] or 0, MyHP = math.ceil(Get(p, "PvpHP") or 0),
        OppHP = math.ceil(Get(o, "PvpHP") or 0), ToWin = PvpData.ModeOf(d.Mode).FragsToWin, EndsAt = d.EndsAt, Sudden = d.Sudden == true }
end

function PvpService.Init(combat: any)
    Combat = combat
    Remotes.GetFunction("PvpAction").OnServerInvoke = function(player: Player, action: any, a: any, b: any, c: any, e: any, f: any)
        if type(action) ~= "string" then return false, "?" end
        local ok, r1, r2 = pcall(Act, player, action, a, b, c, e, f)
        if not ok then warn("[PvP] " .. tostring(r1)); return false, "Duel error." end
        return r1, r2
    end
    Remotes.GetEvent("PvpShot").OnServerEvent:Connect(function(player: Player, hitPos: any, hits: any, heads: any)
        local ok, err = pcall(OnShot, player, hitPos, hits, heads)
        if not ok then warn("[PvP] shot: " .. tostring(err)) end
    end)
    -- a quitter forfeits BEFORE their leave save (their escrow goes to the winner and can't come back to them)
    SaveService.LeaveHooks = SaveService.LeaveHooks or {}
    table.insert(SaveService.LeaveHooks, function(p: Player)
        requests[p] = nil; lastAsk[p] = nil; picks[p] = nil; abilityPick[p] = nil
        for _, list in pairs(requests) do list[p] = nil end
        local d = duels[p]
        if d and not d.Closed then
            d.Leaver = p
            Cancel(d, NameOf(p) .. " left.")
            local st = StateOf(p)
            if st then st.PvpEscrow = nil end
        end
    end)
    -- position history (hit checks) + the clock (time limit) + escrow left over from a crash
    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        for p, d in pairs(duels) do
            if d.Phase == "Live" or d.Phase == "Countdown" then
                local r = RootOf(p)
                if r then
                    local h = history[p]
                    if not h then h = {}; history[p] = h end
                    table.insert(h, { now, r.Position })
                    if #h > 50 then table.remove(h, 1) end
                end
            end
        end
    end)
    task.spawn(function()
        while true do
            task.wait(0.5)
            local seen = {}
            for _, d in pairs(duels) do
                if not seen[d] and not d.Closed then
                    seen[d] = true
                    if d.Phase == "Live" then
                        -- QUAKE HEALTH DECAY: anything over BASE_HEALTH ticks down DECAY a second (this loop runs every 0.5 s)
                        for _, p in ipairs({ d.A, d.B }) do
                            local hp = Get(p, "PvpHP") or 0
                            if hp > PvpData.BASE_HEALTH and not Get(p, "PvpDead") then Attr(p, "PvpHP", math.max(PvpData.BASE_HEALTH, hp - PvpData.DECAY * 0.5)) end
                        end
                        -- fell out of the arena: back to a spawn (no frag)
                        for _, p in ipairs({ d.A, d.B }) do
                            local r = RootOf(p)
                            if r and d.Folder and r.Position.Y < PvpData.SlotOrigin(d.Slot).Y - 30 then MoveTo(p, SpawnFor(d, p)) end
                        end
                        if Workspace:GetServerTimeNow() >= (d.EndsAt or math.huge) and not d.Sudden then
                            local fa, fb = d.Frags[d.A] or 0, d.Frags[d.B] or 0
                            if fa ~= fb then Finish(d, (fa > fb) and d.A or d.B, "time")
                            else d.Sudden = true; Push(d) end
                        end
                    elseif d.Phase == "Locked" then
                        Push(d)
                    end
                end
            end
            -- escrow that never reached a result (server crash / Studio stop): give it back
            for _, p in ipairs(Players:GetPlayers()) do
                local st = SaveService.IsReady(p) and StateOf(p)
                if st and type(st.PvpEscrow) == "table" and not duels[p] then
                    for _, e in ipairs(st.PvpEscrow.Items or {}) do
                        if type(e) == "table" and type(e.Item) == "table" then GiveItem(st, e.Kind, e.Item) end
                    end
                    st.PvpEscrow = nil
                    print("[PvP] returned an unfinished duel's wager to " .. p.Name)
                    Sync(p); Save(p)
                end
            end
        end
    end)
end

return PvpService
