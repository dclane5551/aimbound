--!nocheck
-- Hideouts (0.55, server). Owner 2026-10-06 (see HideoutData's header for the full spec).
-- state.Hideout = { Owned = { [id] = count }, Layout = { { I = id, X = gx, Z = gz, R = rot } ... } } (saved: PLAIN_FIELDS).
-- Every hideout is drawn by each client at the same place (HideoutData.Origin) from its owner's layout, which the server
-- publishes on the OWNER: player attribute "HideoutLayout" (JSON). Whose hideout you're standing in = attribute
-- "HideoutOf" (InstanceKey keeps different hideouts apart). The server only owns: ownership, the layout, who may enter.
--   Remote HideoutAction(action, ...):
--     "Enter"                         go to your own hideout
--     "Leave"                         back to the city
--     "Visit", userId                 a FRIEND or PARTY member's hideout (they must be in this server)
--     "RequestVisit", userId          anyone else: only while they're IN their hideout, only if their Settings allow it
--                                     (AllowVisitRequests), one request per pair every REQUEST_GAP s
--     "RespondVisit", userId, yes     the owner answers (yes = that player may come in this session)
--     "Kick", userId                  the owner sends a visitor back to the city
--     "Place", id, gx, gz, rot        put a piece down (owner, in their own hideout); "Move", index, gx, gz, rot;
--                                     "Remove", index (back to your furniture)
--     "Buy", id                       a gold piece (Price) / a Robux piece (ProductId; free in Studio while it's 0)
--     "Expand"                        buy the next EXPANSION (gold + level; HideoutData.EXPANSIONS)
--     "BuyTheme", id / "SetTheme", id a prebuilt THEME (Robux; free in Studio while ProductId is 0) / show an owned one
--   state.Hideout.Exp (expansions owned), .Theme, .Themes = { [id] = true }; the owner's attribute "HideoutTheme"
--   Remote event HideoutUpdate -> client: ("VisitRequest", { From, FromId }) | ("Toast", text) | ("Got", id)
--   (UPDATE 6) SHOWCASE PIECES (title wall, stats board, trophy shelf, weapon rack, jukebox, arcade): the owner attr
--   "HideoutShowcase" (JSON, Showcase() below) is what every visitor's client draws on them -- the OWNER's data only, built
--   here from the owner's save. Owner actions: "SetRack", slot 1-3, uid ("" clears) / "SetMusic", id ("" = off) /
--   "Showcase" (re-publish). Anyone: "ArcadeStart" then "ArcadeEnd", score, hits (checked: the round's real length, a
--   believable hit rate, the most a hit can score) -> state.Hideout.ArcadeBest (your own best, wherever you played).
-- Drops: CombatServer.OnBossKillLoot (a boss / superboss / trial boss kill) rolls the trophy for that boss.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Zones = require(Shared:WaitForChild("Zones"))
local HideoutData = require(Shared:WaitForChild("HideoutData"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local StashTabs = require(Shared:WaitForChild("StashTabs")) -- (UPDATE 7 C7 stash tabs)
local PartyService = require(script.Parent:WaitForChild("PartyService"))

local Hideouts = {}
Hideouts.REQUEST_GAP = 20
local Combat = nil
local passes = {} -- [owner] = { [visitor] = true }  (a yes to a request: lets them in for this session)
local asked = {} -- [from] = { [owner] = os.clock() }
local friendCache = {} -- [a.UserId .. ":" .. b.UserId] = bool
local sentAt = {} -- [player] = os.clock() of the last SendTo (the client takes a moment to arrive)

local function St(p: Player): any return Combat and Combat.GetState(p) end
local function Data(st: any): any
    st.Hideout = type(st.Hideout) == "table" and st.Hideout or {}
    local h = st.Hideout
    h.Owned = type(h.Owned) == "table" and h.Owned or {}
    h.Layout = type(h.Layout) == "table" and h.Layout or {}
    h.Themes = type(h.Themes) == "table" and h.Themes or {}
    h.Stash = type(h.Stash) == "table" and h.Stash or {}
    h.Stash.W = type(h.Stash.W) == "table" and h.Stash.W or {}
    h.Stash.G = type(h.Stash.G) == "table" and h.Stash.G or {}
    h.Rack = type(h.Rack) == "table" and h.Rack or {} -- (UPDATE 6: { ["1"] = uid, ["2"] = uid, ["3"] = uid }; string keys: no sparse arrays in the save)
    StashTabs.Ensure(st) -- (UPDATE 7: h.Tabs + the free TRADE tab)
    return h
end
local function Toast(p: Player, text: string) Remotes.GetEvent("HideoutUpdate"):FireClient(p, "Toast", text) end
local function Sync(p: Player)
    local st = St(p)
    if st then Remotes.GetEvent("SyncPlayerState"):FireClient(p, st) end
end
-- publish a layout on its owner (every client draws hideouts from this)
local function Publish(p: Player)
    local st = St(p)
    if not st then return end
    local h = Data(st)
    local ok, json = pcall(HttpService.JSONEncode, HttpService, h.Layout)
    p:SetAttribute("HideoutLayout", ok and json or "[]")
    p:SetAttribute("HideoutTheme", HideoutData.ThemeOf(st))
    -- (0.58) the map room + the stash / portal skins every visitor draws
    p:SetAttribute("HideoutMapRoom", HideoutData.HasMapRoom(st))
    local okC, Cosmetics = pcall(require, Shared:WaitForChild("Cosmetics"))
    if okC then
        p:SetAttribute("HideoutStashSkin", Cosmetics.EquippedId(st, "HideoutStash") or "Standard")
        p:SetAttribute("HideoutPortalSkin", Cosmetics.EquippedId(st, "HideoutPortal") or "Riftgate")
    end
    -- (UPDATE 6) what the showcase pieces show
    local okS, show = pcall(Hideouts.Showcase, p, st)
    if okS then
        local okJ, sj = pcall(HttpService.JSONEncode, HttpService, show)
        if okJ then p:SetAttribute("HideoutShowcase", sj) end
    else
        warn("[Hideout] showcase: " .. tostring(show))
    end
end
Hideouts.Publish = Publish

-- ===== (UPDATE 6) SHOWCASE: the owner's titles, lifetime stats, trophies, racked guns, music and arcade best =====
local function FindWeapon(st: any, uid: any): (any, string?)
    if type(uid) ~= "string" or uid == "" then return nil end
    if st.EquippedWeapon and st.EquippedWeapon.Uid == uid then return st.EquippedWeapon, "equipped" end
    for _, w in ipairs(st.Inventory or {}) do if w.Uid == uid then return w, "bag" end end
    Data(st)
    for _, box in ipairs(StashTabs.AllBoxes(st)) do -- (every stash tab)
        for _, w in ipairs(box.W) do if w.Uid == uid then return w, "stash" end end
    end
    return nil
end
Hideouts.FindWeapon = FindWeapon
local SkinFX = nil
local function SkinOf(st: any, gun: string): (string?, number)
    local ce = type(st.CosmeticsEquipped) == "table" and st.CosmeticsEquipped or {}
    local id = ce["WeaponSkin/" .. tostring(gun)]
    if type(id) ~= "string" then return nil, 1 end
    if SkinFX == nil then
        local ok, m = pcall(require, Shared:WaitForChild("SkinFX"))
        SkinFX = ok and m or false
    end
    local sk = SkinFX and SkinFX.GunSkinById[id]
    if not (sk and sk.Gun == gun) then return nil, 1 end
    local v = 1
    if sk.Set then
        local ok, cw = pcall(require, Shared:WaitForChild("Colorways"))
        if ok then v = cw.VariantFor(st, sk.Set, "WeaponSkin:" .. id) end
    end
    return id, v
end
function Hideouts.Showcase(p: Player, st: any): any
    local h = Data(st)
    local out = { N = p.DisplayName }
    local T = {}
    for _, id in ipairs(type(st.UnlockedTitles) == "table" and st.UnlockedTitles or {}) do
        if type(id) == "string" and ItemData.Titles[id] and not table.find(T, id) then table.insert(T, id) end
    end
    table.sort(T, function(a, b) return (ItemData.Titles[a].Order or 0) > (ItemData.Titles[b].Order or 0) end) -- (rarest first)
    out.T, out.E = T, st.EquippedTitle
    local S = type(st.StatsTracking) == "table" and st.StatsTracking or {}
    local function N(k) return math.floor(tonumber(S[k]) or 0) end
    out.S = { k = N("TotalKills"), o = N("OwnKills"), w = N("WeakSpotKills"), d = N("Deaths"), b = N("BossKills"), e = N("EliteKills"),
        m = N("MeleeKills"), r = N("Runs"), c = N("RunsCleared"), f = N("FloorsCleared"), h = N("HighestFloorCleared"), s = N("Shots"),
        i = N("Hits"), t = N("PlaySeconds"), q = N("BestStreak"), l = math.floor(tonumber(st.Level) or 1) }
    local B = {}
    for id, v in pairs(type(st.BossTrials) == "table" and st.BossTrials or {}) do
        if type(id) == "string" and type(v) == "table" and (tonumber(v.Best) or 0) > 0 then B[id] = math.floor(tonumber(v.Best)) end
    end
    out.B = B
    local X, seen = {}, {}
    local function Ex(it) if type(it) == "table" and it.Exotic and not seen[tostring(it.Exotic)] then seen[tostring(it.Exotic)] = true; table.insert(X, tostring(it.Exotic)) end end
    Ex(st.EquippedWeapon)
    for _, g in pairs(type(st.EquippedGear) == "table" and st.EquippedGear or {}) do Ex(g) end
    for _, list in ipairs({ st.Inventory or {}, st.GearInventory or {} }) do for _, it in ipairs(list) do Ex(it) end end
    for _, box in ipairs(StashTabs.AllBoxes(st)) do for _, list in ipairs({ box.W, box.G }) do for _, it in ipairs(list or {}) do Ex(it) end end end
    out.X = X
    local fb = type(S.FloorsByDifficulty) == "table" and S.FloorsByDifficulty or {}
    for _, d in ipairs(ItemData.DifficultyOrder) do
        local m = ItemData.DifficultyModes[d]
        if (tonumber(fb[d]) or 0) >= ((m and m.MaxWaves) or 999) then out.C = d end
    end
    out.A, out.R = math.floor(tonumber(st.AscTrialBest) or 0), math.floor(tonumber(st.RiftBest) or 0)
    out.K = {}
    for i = 1, 3 do
        local w, where = FindWeapon(st, h.Rack[tostring(i)])
        if w and w.BaseId then
            local sid, v = SkinOf(st, w.BaseId)
            local okD, dps = pcall(function() return ItemData.FormatNumber(ItemData.CalculateTrueDPS(w)) end)
            local okT, tl = pcall(ItemData.WeaponTypeLine, w)
            out.K[tostring(i)] = { g = w.BaseId, u = w.Uid, n = ItemData.DisplayName(w), r = w.Rarity, x = w.Exotic and tostring(w.Exotic) or nil,
                s = sid, v = v, d = okD and dps or nil, t = okT and tl or nil, w = where }
        end
    end
    out.M = (type(h.Music) == "string" and HideoutData.MusicById[h.Music]) and h.Music or nil
    out.P = math.floor(tonumber(h.ArcadeBest) or 0)
    return out
end
local arcadeAt = {} -- [player] = os.clock() when their round started

-- drop invalid pieces from a loaded layout (catalog changes, ownership lost)
local function Clean(st: any)
    local h = Data(st)
    local keep = {}
    for _, e in ipairs(h.Layout) do
        if type(e) == "table" and HideoutData.Items[e.I] and HideoutData.CanPlace(keep, e.I, e.X, e.Z, e.R or 0, nil, HideoutData.ExpLevel(st))
            and HideoutData.PlacedCount(keep, e.I) < HideoutData.OwnedCount(st, e.I) and #keep < HideoutData.MAX_PIECES then
            table.insert(keep, { I = e.I, X = e.X, Z = e.Z, R = (e.R or 0) % 4 })
        end
    end
    h.Layout = keep
end

local function InOwnHideout(p: Player): boolean
    local char = p.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return root ~= nil and Zones.InHideout(root.Position) and p:GetAttribute("HideoutOf") == p.UserId
end
local function Free(p: Player): (boolean, string?)
    if p:GetAttribute("RunId") or p:GetAttribute("Downed") or p:GetAttribute("Spectating") then return false, "Not during a run." end
    local char = p.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false, "Not spawned." end
    if Zones.Kind(root.Position) == "dungeon" or Zones.Kind(root.Position) == "pvp" then return false, "Not during a run or a duel." end
    return true
end
local function Friends(a: Player, b: Player): boolean
    local key = math.min(a.UserId, b.UserId) .. ":" .. math.max(a.UserId, b.UserId)
    if friendCache[key] ~= nil then return friendCache[key] end
    local ok, yes = pcall(function() return a:IsFriendsWith(b.UserId) end)
    friendCache[key] = ok and yes == true
    return friendCache[key]
end
local function SameParty(a: Player, b: Player): boolean
    local ra = PartyService.RoomOf(a)
    return ra ~= nil and ra == PartyService.RoomOf(b)
end
local function MayVisit(visitor: Player, owner: Player): boolean
    if RunService:IsStudio() and visitor == owner then return true end
    return Friends(visitor, owner) or SameParty(visitor, owner) or (passes[owner] ~= nil and passes[owner][visitor] == true)
end
local function SendTo(p: Player, ownerId: number)
    sentAt[p] = os.clock()
    p:SetAttribute("HideoutOf", ownerId)
    local cf = HideoutData.SPAWN
    if ownerId ~= p.UserId then cf = cf * CFrame.new(math.random(-3, 3), 0, math.random(-3, 3)) end
    Remotes.GetEvent("TeleportPlayer"):FireClient(p, "Goto", cf)
end
local function ToCity(p: Player)
    p:SetAttribute("HideoutOf", nil)
    Remotes.GetEvent("TeleportPlayer"):FireClient(p, "Goto", CFrame.lookAt(Vector3.new(0, 7.2, 24), Vector3.new(0, 7.2, 0))) -- (feet on the street)
end
Hideouts.ToCity = ToCity

-- grant a piece (drops / receipts / dev): owned count +1 up to its Max
-- BOUND SHOP (0.97): spend BOUND points (state.BoundPoints; the player attribute mirrors it)
function Hideouts.PayBP(p: Player, st: any, price: number): (boolean, string?)
    local have = math.floor(tonumber(st.BoundPoints) or 0)
    if have < price then return false, string.format("Not enough BOUND points (%d / %d).", have, price) end
    st.BoundPoints = have - price
    p:SetAttribute("BoundPoints", st.BoundPoints)
    return true
end
function Hideouts.Grant(p: Player, id: string, quiet: boolean?): boolean
    local def = HideoutData.Items[id]
    local st = St(p)
    if not def or not st then return false end
    local h = Data(st)
    local have = tonumber(h.Owned[id]) or 0
    if have >= def.Max then return false end
    h.Owned[id] = have + 1
    if not quiet then
        Remotes.GetEvent("CombatFx"):FireClient(p, "Text", "HIDEOUT FURNITURE: " .. def.Name .. "!", ItemData.RarityColors[def.Rarity] or Color3.new(1, 1, 1))
        Remotes.GetEvent("HideoutUpdate"):FireClient(p, "Got", id)
    end
    Sync(p)
    return true
end

-- a boss died: roll its trophy (chance x (1 + 0.15 per difficulty rank)); the APEX pedestal on Ruin+ from any boss
function Hideouts.OnBossKill(p: Player, modelName: string?, biome: string?, difficulty: string?)
    local rank = (ItemData.DifficultyRank or {})[difficulty or "Easy"] or 1 -- (Easy 1 .. Oblivion 8, Ruin 9 ..)
    for _, id in ipairs(HideoutData.Order) do
        local def = HideoutData.Items[id]
        local d = def.Drop
        if d then
            local match = (d.Any and rank >= (d.MinRank or 0)) or (d.Model == modelName and (not d.Biome or d.Biome == biome))
            if match and math.random() < d.Chance * (1 + 0.15 * math.max(0, rank - 1)) then
                Hideouts.Grant(p, id)
            end
        end
    end
end

-- grant a THEME (receipts / Studio / dev); shows it straight away
function Hideouts.GrantTheme(p: Player, id: string): boolean
    local st = St(p)
    if not st or not HideoutData.THEMES[id] then return false end
    local h = Data(st)
    h.Themes[id] = true
    h.Theme = id
    Publish(p)
    Sync(p)
    return true
end

-- MarketplaceService receipt for a Robux piece -> decision or nil (not ours)
function Hideouts.Receipt(receipt: any, player: Player?): any
    local mr = HideoutData.MAP_ROOM
    if (mr.ProductId or 0) ~= 0 and mr.ProductId == receipt.ProductId then
        if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
        local st = St(player)
        if st then Data(st).MapRoom = true; Publish(player); Sync(player) end
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    for k, e in ipairs(HideoutData.EXPANSIONS) do
        if (e.ProductId or 0) ~= 0 and e.ProductId == receipt.ProductId then
            if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
            local st = St(player)
            if st then
                local h = Data(st)
                h.Exp = math.max(HideoutData.ExpLevel(st), k)
                Sync(player)
            end
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
    end
    for _, tid in ipairs(HideoutData.THEME_ORDER) do
        local t = HideoutData.THEMES[tid]
        if (t.ProductId or 0) ~= 0 and t.ProductId == receipt.ProductId then
            if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
            Hideouts.GrantTheme(player, tid)
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
    end
    for _, id in ipairs(HideoutData.Order) do
        local def = HideoutData.Items[id]
        if def.Source == "Robux" and (def.ProductId or 0) ~= 0 and def.ProductId == receipt.ProductId then
            if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
            Hideouts.Grant(player, id)
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
    end
    return nil
end

local function Act(p: Player, action: string, a: any, b: any, c: any, d: any): (boolean, string?)
    local st = St(p)
    if not st then return false, "Still loading." end
    local h = Data(st)
    if action == "Enter" then
        local ok, why = Free(p); if not ok then return false, why end
        Publish(p)
        SendTo(p, p.UserId)
        return true
    elseif action == "Leave" then
        -- ("Leave", "Stay": the teleport menu is moving you itself -- just stop being in the hideout)
        if a == "Stay" then p:SetAttribute("HideoutOf", nil) else ToCity(p) end
        return true
    elseif action == "Visit" or action == "RequestVisit" then
        local owner = Players:GetPlayerByUserId(tonumber(a) or 0)
        if not owner then return false, "That player isn't in this server." end
        local ok, why = Free(p); if not ok then return false, why end
        if action == "Visit" then
            if not MayVisit(p, owner) then return false, "Only friends and party members can walk in. Send a visit request instead." end
            if owner ~= p and not owner:GetAttribute("HideoutLayout") then Publish(owner) end
            SendTo(p, owner.UserId)
            return true
        end
        -- a request: only while they're in their own hideout, only if they take requests
        if owner == p then return false, "That's you." end
        if not InOwnHideout(owner) then return false, owner.DisplayName .. " isn't in their hideout right now." end
        local ost = St(owner)
        if ost and ost.Settings and ost.Settings.AllowVisitRequests == false then return false, owner.DisplayName .. " isn't taking visit requests." end
        asked[p] = asked[p] or {}
        if os.clock() - (asked[p][owner] or -99) < Hideouts.REQUEST_GAP then return false, "You asked recently. Give them a moment." end
        asked[p][owner] = os.clock()
        Remotes.GetEvent("HideoutUpdate"):FireClient(owner, "VisitRequest", { From = p.DisplayName, FromId = p.UserId })
        return true, "Visit request sent to " .. owner.DisplayName .. "."
    elseif action == "RespondVisit" then
        local from = Players:GetPlayerByUserId(tonumber(a) or 0)
        if not from then return false, "They left." end
        if not (asked[from] and asked[from][p]) then return false, "That request expired." end
        asked[from][p] = nil
        if b ~= true then Toast(from, p.DisplayName .. " declined your visit."); return true end
        passes[p] = passes[p] or {}
        passes[p][from] = true
        local ok = Free(from)
        if ok and InOwnHideout(p) then
            SendTo(from, p.UserId)
            Toast(from, "Welcome to " .. p.DisplayName .. "'s hideout!")
        end
        return true
    elseif action == "Kick" then
        local v = Players:GetPlayerByUserId(tonumber(a) or 0)
        if v and v ~= p and v:GetAttribute("HideoutOf") == p.UserId then
            if passes[p] then passes[p][v] = nil end
            ToCity(v)
            Toast(v, p.DisplayName .. " sent you back to the city.")
        end
        return true
    elseif action == "Buy" then
        local id = tostring(a)
        local def = HideoutData.Items[id]
        if not def then return false, "Unknown piece." end
        local have = tonumber(h.Owned[id]) or 0
        if have >= def.Max then return false, "You already have the most you can own (" .. def.Max .. ")." end
        if def.Source == "Gold" then
            if (st.Gold or 0) < def.Price then return false, "Not enough gold." end
            st.Gold -= def.Price
            h.Owned[id] = have + 1
            Sync(p)
            return true, def.Name .. " bought."
        elseif def.Source == "Robux" then -- (0.97 BOUND SHOP: BOUND points)
            local ok, why = Hideouts.PayBP(p, st, HideoutData.BPPrice(def.Price))
            if not ok then return false, why end
            Hideouts.Grant(p, id, true)
            return true, def.Name .. " bought."
        end
        return false, (def.How or "Earned in play") .. "."
    elseif action == "Expand" then
        return false, "Expansions are bought with BOUND points now." -- (2026-10-20 owner: stash room costs BOUND points)
    elseif action == "ExpandRobux" then
        local cur = HideoutData.ExpLevel(st)
        local nxt = HideoutData.EXPANSIONS[cur + 1]
        if not nxt then return false, "Your hideout is fully expanded." end
        local ok, why = Hideouts.PayBP(p, st, HideoutData.BPPrice(nxt.Robux)) -- (0.97 BOUND SHOP)
        if not ok then return false, why end
        h.Exp = cur + 1
        Sync(p)
        return true, nxt.Name .. " bought: room for " .. nxt.Cap .. " pieces."
    elseif action == "BuyMapRoom" or action == "MapRoomRobux" then
        -- THE MAP ROOM (0.58): a wing with the map device (HideoutData.MAP_ROOM)
        local mr = HideoutData.MAP_ROOM
        if h.MapRoom then return false, "You already have the map room." end
        if action == "MapRoomRobux" then
            local ok, why = Hideouts.PayBP(p, st, HideoutData.BPPrice(mr.Robux)) -- (0.97 BOUND SHOP)
            if not ok then return false, why end
            h.MapRoom = true; Publish(p); Sync(p)
            return true, "Map room built: put a sigil in the map device."
        end
        if (st.Level or 1) < mr.Level then return false, "The map room needs level " .. mr.Level .. "." end
        if (st.Gold or 0) < mr.Price then return false, "Not enough gold." end
        st.Gold -= mr.Price
        h.MapRoom = true
        Publish(p)
        Sync(p)
        return true, "Map room built: put a sigil in the map device."
    elseif action == "OpenMap" then
        -- the MAP DEVICE: a sigil goes in, the portal opens for PORTAL_OPEN_SECONDS (owner attrs HideoutPortal / Until)
        if not InOwnHideout(p) then return false, "The map device is in your hideout." end
        if not h.MapRoom then return false, "Build the map room first." end
        if (st.Level or 1) < HideoutData.MAP_ROOM.Level then return false, "Maps open at level " .. HideoutData.MAP_ROOM.Level .. "." end
        local found = false
        for _, sg in ipairs(st.Sigils or {}) do if sg.Uid == a then found = true end end
        if not found then return false, "That sigil is gone." end
        p:SetAttribute("HideoutPortal", a)
        -- (bot skill pick: b = 1..10, nil = the map's own roll)
        local skill = tonumber(b)
        p:SetAttribute("HideoutPortalSkill", skill and math.clamp(math.floor(skill), 1, 10) or nil)
        p:SetAttribute("HideoutPortalUntil", workspace:GetServerTimeNow() + HideoutData.PORTAL_OPEN_SECONDS)
        return true, "The portal is open."
    elseif action == "CraftMap" then
        -- (0.62 MAPS v3) craft a map at the device: Imbue (Normal -> Magic) / Empower (Magic -> Rare) / Reroll, paid in Prism
        if not InOwnHideout(p) then return false, "The map device is in your hideout." end
        local Rifts = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Rifts"))
        local craft = Rifts.CRAFT[tostring(b)]
        if not craft then return false, "Unknown craft." end
        local sg
        for _, s in ipairs(st.Sigils or {}) do if s.Uid == a then sg = s end end
        if not sg then return false, "That map is gone." end
        if p:GetAttribute("HideoutPortal") == a then return false, "That map is in the open portal." end
        local ok, why = Rifts.CanCraft(sg, tostring(b))
        if not ok then return false, why end
        st.Materials = st.Materials or {}
        local mat = Rifts.CraftMaterial(tostring(b)) -- (Prism, or the 0.66 map-only Chart Shards)
        local cost = craft.Fixed and craft.Cost or require(game.ReplicatedStorage.AimRngShared.AtlasData).CraftCost(st, craft.Cost) -- (MAP TREE: Artisan; MAPS V2: HONE / RUPTURE always full price)
        local matName = (require(game.ReplicatedStorage.AimRngShared.ItemData).MaterialDefs[mat] or {}).Name or mat
        if (st.Materials[mat] or 0) < cost then return false, string.format("Needs %d %s.", cost, matName) end
        st.Materials[mat] -= cost
        local what = Rifts.ApplyCraft(sg, tostring(b))
        Sync(p)
        return true, craft.Name .. ": " .. Rifts.DisplayName(sg) .. (what and ("  (" .. what .. ")") or "")
    elseif action == "InkMap" then
        -- (UPDATE 7 C3 MAP INKS) draw an ink onto a map: one ink of that kind, up to MapInks.MAX_PER_MAP different ones a map
        if not InOwnHideout(p) then return false, "The map device is in your hideout." end
        local MI = require(game.ReplicatedStorage.AimRngShared.MapInks)
        local key = tostring(b)
        local sg
        for _, s in ipairs(st.Sigils or {}) do if s.Uid == a then sg = s end end
        if not sg then return false, "That map is gone." end
        if p:GetAttribute("HideoutPortal") == a then return false, "That map is in the open portal." end
        local ok, why = MI.CanInk(sg, key, require(game.ReplicatedStorage.AimRngShared.AtlasData).Stats(st)) -- (MAPS V2: Wide Margins = a 3rd mark)
        if not ok then return false, why end
        st.Materials = st.Materials or {}
        if (st.Materials[key] or 0) < 1 then return false, "You have no " .. MI.Defs[key].Name .. "." end
        st.Materials[key] -= 1
        sg.Inks = type(sg.Inks) == "table" and sg.Inks or {}
        table.insert(sg.Inks, key)
        pcall(function() require(script.Parent:WaitForChild("CombatServer")).SeasonGoalEvent(p, st, "MapInk", 1) end)
        Sync(p)
        return true, MI.Defs[key].Name .. " drawn onto " .. require(game.ReplicatedStorage.AimRngShared.Rifts).DisplayName(sg) .. "."
    elseif action == "EnterPortal" then
        if not InOwnHideout(p) then return false, "Not your portal." end
        local uid = p:GetAttribute("HideoutPortal")
        if not uid or workspace:GetServerTimeNow() > (p:GetAttribute("HideoutPortalUntil") or 0) then return false, "The portal is closed." end
        local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if not root or (root.Position - (HideoutData.Origin + HideoutData.MAP.Portal)).Magnitude > 16 then return false, "Walk up to the portal." end
        local skill = p:GetAttribute("HideoutPortalSkill")
        p:SetAttribute("HideoutPortal", nil)
        p:SetAttribute("HideoutPortalSkill", nil)
        p:SetAttribute("HideoutPortalUntil", nil)
        local Endgame = require(script.Parent:WaitForChild("EndgameServer"))
        p:SetAttribute("HideoutOf", nil)
        local ok, why = Endgame.StartRift(p, uid, skill)
        if not ok then p:SetAttribute("HideoutOf", p.UserId) end
        return ok, why
    elseif action == "Store" or action == "Take" then
        -- the STASH: only at your own hideout
        if not InOwnHideout(p) then return false, "Your stash is in your hideout." end
        local kind = (b == "Gear") and "Gear" or "Weapon"
        local uid = tostring(a)
        local bag = (kind == "Weapon") and st.Inventory or st.GearInventory
        -- (UPDATE 7 STASH TABS: c = the tab's id; nil / "STASH" = the old stash)
        local tabId = (type(c) == "string" and c ~= "") and c or "STASH"
        local tabBox = StashTabs.Box(st, tabId)
        if not tabBox then return false, "Pick a stash tab." end
        local box = (kind == "Weapon") and tabBox.W or tabBox.G
        if action == "Store" then
            if StashTabs.Count(tabBox) >= StashTabs.Cap(st, tabId) then
                return false, (tabId == "STASH") and "Your stash is full. Expansions make room, or use another tab." or "That tab is full. Pick another tab."
            end
            if kind == "Weapon" and st.EquippedWeapon and st.EquippedWeapon.Uid == uid then return false, "Unequip it first." end
            for i, it in ipairs(bag or {}) do
                if it.Uid == uid then
                    table.remove(bag, i)
                    table.insert(box, it)
                    Sync(p)
                    return true
                end
            end
            return false, "That item is gone."
        else
            if ItemData.BagRoom(st) <= 0 then return false, "Your bag is full (" .. ItemData.BagCap(st) .. ")." end
            for i, it in ipairs(box) do
                if it.Uid == uid then
                    table.remove(box, i)
                    table.insert(bag, it)
                    Sync(p)
                    return true
                end
            end
            return false, "That item is gone."
        end
    elseif action == "StoreUpTo" then
        -- QOL L7 (2026-10-28): STASH UP TO -- a = a rarity, b = the tab id: every bag weapon + gear at or below it goes into that
        -- tab (best-first is irrelevant: it fills until the tab is full). Equipped, LOCKED and the starter pistol stay.
        if not InOwnHideout(p) then return false, "Your stash is in your hideout." end
        local rank = ItemData.RarityRank[tostring(a)]
        if not rank then return false, "Pick a rarity." end
        local tabId = (type(b) == "string" and b ~= "") and b or "STASH"
        local tabBox = StashTabs.Box(st, tabId)
        if not tabBox then return false, "Pick a stash tab." end
        local cap = StashTabs.Cap(st, tabId)
        local moved, full = 0, false
        for _, spec in ipairs({ { st.Inventory, tabBox.W, "Weapon" }, { st.GearInventory, tabBox.G, "Gear" } }) do
            local bag, box = spec[1] or {}, spec[2]
            for i = #bag, 1, -1 do
                local it = bag[i]
                if type(it) == "table" and not it.Locked and it.Uid ~= "W_STARTER_PISTOL" and (ItemData.RarityRank[it.Rarity] or 1) <= rank
                    and not (spec[3] == "Weapon" and st.EquippedWeapon and st.EquippedWeapon.Uid == it.Uid) then
                    if StashTabs.Count(tabBox) >= cap then full = true; break end
                    table.remove(bag, i)
                    table.insert(box, it)
                    moved += 1
                end
            end
        end
        if moved > 0 then Sync(p) end
        if moved == 0 then return false, full and "That tab is full." or "Nothing in your bag to stash at that rarity (locked items stay)." end
        return true, "Stashed " .. moved .. " item" .. (moved == 1 and "" or "s") .. (full and " (the tab is full now)." or ".")
    elseif action == "BuyTab" then
        -- (UPDATE 7 STASH TABS) a = "General" | "Trade" | "Gem" | "Map": BOUND points only (2026-10-20: the gold trade tab is gone)
        local kind = tostring(a)
        local def = StashTabs.Kinds[kind]
        if not def then return false, "Unknown tab." end
        if def.Special then -- (UPDATE 7: GEM / MAP special tabs raise a bag's room)
            if StashTabs.Special(st, kind) >= StashTabs.SPECIAL_MAX then return false, "You have every " .. def.Name .. " tab." end
            local ok, why = Hideouts.PayBP(p, st, def.BP)
            if not ok then return false, why end
            h.Special = type(h.Special) == "table" and h.Special or {}
            h.Special[kind] = StashTabs.Special(st, kind) + 1
            Sync(p)
            return true, def.Name .. " tab bought: " .. def.Text
        end
        local bought = StashTabs.Bought(st, "General") + StashTabs.Bought(st, "Trade")
        if bought >= StashTabs.MAX_TABS then return false, "That's every tab the stash can hold." end
        do
            local ok, why = Hideouts.PayBP(p, st, def.BP)
            if not ok then return false, why end
        end
        local n = StashTabs.Bought(st, kind) + 1
        table.insert(h.Tabs, { Id = kind:upper() .. "B" .. n .. "_" .. tostring(os.time() % 100000), Kind = kind, Name = def.Name .. " " .. (n + 1), W = {}, G = {} })
        Sync(p)
        return true, def.Name .. " tab bought."
    elseif action == "RenameTab" then
        local name = string.upper(string.sub(tostring(b or ""), 1, 14)):gsub("[^%w %-]", "")
        if name == "" then return false, "Give it a name." end
        for _, t in ipairs(h.Tabs) do
            if t.Id == a then
                local okF, filtered = pcall(function() return game:GetService("TextService"):FilterStringAsync(name, p.UserId):GetNonChatStringForBroadcastAsync() end)
                t.Name = okF and filtered or t.Name
                Sync(p)
                return true
            end
        end
        return false, "That tab can't be renamed."
    elseif action == "BuyTheme" then
        local id = tostring(a)
        local t = HideoutData.THEMES[id]
        if not t then return false, "Unknown theme." end
        if t.Free or h.Themes[id] then return false, "You already own it." end
        local ok, why = Hideouts.PayBP(p, st, HideoutData.THEME_BP) -- (0.97 BOUND SHOP)
        if not ok then return false, why end
        Hideouts.GrantTheme(p, id)
        return true, t.Name .. " bought."
    elseif action == "SetTheme" then
        local id = tostring(a)
        local t = HideoutData.THEMES[id]
        if not t then return false, "Unknown theme." end
        if not (t.Free or h.Themes[id]) then return false, "You don't own that theme." end
        h.Theme = id
        Publish(p)
        Sync(p)
        return true, t.Name .. " is now your hideout."
    elseif action == "Place" or action == "Move" then
        if not InOwnHideout(p) then return false, "Build in your own hideout." end
        local id, gx, gz, rot, skip
        if action == "Place" then
            id, gx, gz, rot = tostring(a), tonumber(b), tonumber(c), tonumber(d) or 0
            local cap = HideoutData.Cap(HideoutData.ExpLevel(st))
            if #h.Layout >= cap then return false, "Your hideout is full (" .. cap .. " pieces). Expansions (Hideout > Home) make room for more." end
            if HideoutData.PlacedCount(h.Layout, id) >= HideoutData.OwnedCount(st, id) then return false, "You have none of those left to place." end
        else
            skip = tonumber(a)
            local e = skip and h.Layout[skip]
            if not e then return false, "That piece is gone." end
            id, gx, gz, rot = e.I, tonumber(b), tonumber(c), tonumber(d) or 0
        end
        rot = math.floor(rot or 0) % 4
        local ok, why = HideoutData.CanPlace(h.Layout, id, gx, gz, rot, skip, HideoutData.ExpLevel(st))
        if not ok then return false, why end
        if skip then h.Layout[skip] = { I = id, X = gx, Z = gz, R = rot } else table.insert(h.Layout, { I = id, X = gx, Z = gz, R = rot }) end
        Publish(p)
        return true
    elseif action == "SetRack" then
        -- (UPDATE 6) the weapon rack: slot 1-3 shows one of YOUR guns (bag, hand or stash); "" empties it
        if not InOwnHideout(p) then return false, "That's done at your own rack." end
        local slot = math.floor(tonumber(a) or 0)
        if slot < 1 or slot > 3 then return false, "No such rack slot." end
        if a == nil or b == nil or b == "" then
            h.Rack[tostring(slot)] = nil
        else
            local w = FindWeapon(st, b)
            if not w then return false, "That gun is gone." end
            for k, u in pairs(h.Rack) do if u == b then h.Rack[k] = nil end end -- (one gun, one peg)
            h.Rack[tostring(slot)] = b
        end
        Publish(p)
        return true
    elseif action == "SetMusic" then
        if not InOwnHideout(p) then return false, "Pick the music at your own jukebox." end
        local id = tostring(a or "")
        if id ~= "" and not HideoutData.MusicById[id] then return false, "Unknown track." end
        h.Music = (id ~= "") and id or nil
        Publish(p)
        return true, (id ~= "") and ("Now playing: " .. HideoutData.MusicById[id].Name) or "The jukebox is off."
    elseif action == "Showcase" then
        Publish(p)
        return true
    elseif action == "ArcadeStart" then
        local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if not (root and Zones.InHideout(root.Position)) then return false, "The arcade is in the hideout." end
        arcadeAt[p] = os.clock()
        return true
    elseif action == "ArcadeEnd" then
        local A = HideoutData.ARCADE
        local t0 = arcadeAt[p]
        arcadeAt[p] = nil
        if not t0 then return false, "That round didn't count." end
        local el = os.clock() - t0
        local score, hits = math.floor(tonumber(a) or -1), math.floor(tonumber(b) or -1)
        if el < A.Time - 0.5 or el > A.Time + 30 or score < 0 or hits < 0 or hits > el * A.MaxRate or score > hits * A.MaxPerHit then
            return false, "That round didn't count."
        end
        local best = math.floor(tonumber(h.ArcadeBest) or 0)
        local new = score > best
        if new then h.ArcadeBest = score; Sync(p) end
        if new and InOwnHideout(p) then Publish(p) end
        return true, new and ("NEW BEST: " .. score) or ("Score " .. score .. "  (best " .. best .. ")")
    elseif action == "Remove" then
        if not InOwnHideout(p) then return false, "Build in your own hideout." end
        local i = tonumber(a)
        if not i or not h.Layout[i] then return false, "That piece is gone." end
        table.remove(h.Layout, i)
        Publish(p)
        return true
    end
    return false, "Unknown hideout action."
end
Hideouts.Act = Act

function Hideouts.Init(combat: any, hubGenerator: any)
    Combat = combat
    Remotes.GetFunction("HideoutAction").OnServerInvoke = function(p: Player, action: any, a: any, b: any, c: any, d: any)
        if type(action) ~= "string" then return false, "?" end
        local ok, r1, r2 = pcall(Act, p, action, a, b, c, d)
        if not ok then warn("[Hideout] " .. tostring(r1)); return false, "Hideout error." end
        return r1, r2
    end
    combat.OnBossKillLoot = function(p, st, modelName, biome, difficulty) Hideouts.OnBossKill(p, modelName, biome, difficulty) end
    combat.ExtraReceipt = Hideouts.Receipt
    -- the practice dummy every hideout's alcove shows (one server dummy: all hideouts sit at the same place)
    task.spawn(function()
        local ok, err = pcall(function()
            local holder = workspace:FindFirstChild("HideoutWorld") or Instance.new("Folder")
            holder.Name = "HideoutWorld"
            holder.Parent = workspace
            if not holder:FindFirstChild("DpsDummy") and hubGenerator and hubGenerator.SpawnDpsDummy then
                local dummy = hubGenerator.SpawnDpsDummy(HideoutData.DUMMY_POS, holder)
                if dummy then dummy:SetAttribute("NoXRay", true) end
            end
            -- a server-side safety floor under every hideout (each client draws its own floor a moment after arriving)
            if not holder:FindFirstChild("SafetyFloor") then
                local f = Instance.new("Part")
                f.Name = "SafetyFloor"; f.Anchored = true; f.Transparency = 1; f.CanQuery = false; f.CanTouch = false
                f.Size = Vector3.new(94, 2, 88); f.CFrame = CFrame.new(HideoutData.Origin + Vector3.new(10, -1.05, 1)) -- (0.58: the bigger hideout + alcove + map room; no standing in the sky)
                f.Parent = holder
            end
        end)
        if not ok then warn("[Hideout] dummy: " .. tostring(err)) end
    end)
    -- publish each player's layout once their save is in; tidy up who's where
    local function Ready(p: Player)
        task.spawn(function()
            for _ = 1, 60 do
                local st = St(p)
                if st and st.Level then
                    Clean(st)
                    Publish(p)
                    return
                end
                task.wait(1)
            end
        end)
    end
    Players.PlayerAdded:Connect(Ready)
    for _, p in ipairs(Players:GetPlayers()) do Ready(p) end
    Players.PlayerRemoving:Connect(function(owner)
        sentAt[owner] = nil
        arcadeAt[owner] = nil
        passes[owner] = nil
        asked[owner] = nil
        for _, list in pairs(asked) do list[owner] = nil end
        for _, list in pairs(passes) do list[owner] = nil end
        -- visitors of a leaving owner go home
        for _, v in ipairs(Players:GetPlayers()) do
            if v ~= owner and v:GetAttribute("HideoutOf") == owner.UserId then ToCity(v); Toast(v, owner.DisplayName .. " left the server.") end
        end
    end)
    task.spawn(function()
        while true do
            task.wait(1)
            for _, p in ipairs(Players:GetPlayers()) do
                local char = p.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local settling = os.clock() - (sentAt[p] or -99) < 4 -- (on the way in: don't undo SendTo)
                if settling then
                    -- nothing
                elseif root and p:GetAttribute("HideoutOf") and not Zones.InHideout(root.Position) then
                    p:SetAttribute("HideoutOf", nil) -- (left by the door / teleport menu / a run)
                elseif root and Zones.InHideout(root.Position) and not p:GetAttribute("HideoutOf") then
                    p:SetAttribute("HideoutOf", p.UserId) -- (respawned / teleported in some other way: your own)
                end
            end
        end
    end)
end

return Hideouts
