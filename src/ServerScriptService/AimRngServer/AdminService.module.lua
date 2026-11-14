--!nocheck
-- ADMIN GIFTS (owner request 2026-10-02: "gift my friends stuff for free as the dev"). The owner (and anyone in
-- ADMINS) opens a hidden panel (AdminPanel, key F6) and gives / takes back cosmetics, the premium season pass or
-- "everything premium" for any player in the same server. Every action is checked here on the server: nobody else
-- can call it, whatever their client sends. Gifts go through the same grant path as a Robux purchase (and save).
-- Remote AdminAction: ("Check") -> bool | ("Players") -> list | ("Owned", userId) -> { [ref] = true, SeasonPass }
--   | ("Give" / "Take", userId, ref) -> ok, msg.   ref = "Category:Id" | "SeasonPass" | "AllPremium"
--   | ("Cmd", userId, commandId, { raw field values }) -> ok, result text (AimRngShared.AdminCommands; DevCommands.Run)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Seasons = require(Shared:WaitForChild("Seasons"))
local Colorways = require(Shared:WaitForChild("Colorways"))
local ItemData = require(Shared:WaitForChild("ItemData")) -- (UPDATE 7: currency gift rows)

local AdminService = {}

-- extra admins by user id (the experience owner is always an admin): { [userId] = true }
-- (2026-10-14: the game moves to the owner's group -> its rank-255 owner is admin; the owner's own account stays admin too)
local ADMINS = { [3890253770] = true }

function AdminService.IsAdmin(p: Player): boolean
    if RunService:IsStudio() then return true end
    if ADMINS[p.UserId] then return true end
    if game.CreatorType == Enum.CreatorType.User then return p.UserId == game.CreatorId end
    local ok, rank = pcall(function() return p:GetRankInGroup(game.CreatorId) end)
    return ok and rank == 255 -- group-owned: the group owner
end

-- everything worth gifting: every cosmetic that isn't free or level-unlocked
function AdminService.Giftable()
    local out = {}
    for _, e in ipairs(Cosmetics.All()) do
        if e.Unlock ~= "Free" and e.Unlock ~= "Level" then table.insert(out, e) end
    end
    return out
end

local function Revoke(player: Player, state: any, e: any)
    if e.Cat == "Bundle" then
        for _, ref in ipairs(e.Contents or {}) do
            local cat, id = string.match(ref, "^(.-):(.*)$")
            local ce = cat and Cosmetics.Find(cat, id)
            if ce then Revoke(player, state, ce) end
        end
        return
    end
    Cosmetics.Revoke(state, e) -- (2026-10-14: shared with skin trading; also takes both halves of a pair of arms)
end

-- MUSIC AUDITION KEEPS (dev only; see MusicAudition). record = { [tostring(id)] = { Name, By, Group, At, Who } }
local musicMem = nil
local function MusicStore()
    -- (Studio play-tests keep the picks in memory only, like ErrorLog: Studio has no API access here, and every
    -- DataStore call printed a warning. The "MUSIC KEEP:" lines in the Output are the record there.)
    if RunService:IsStudio() then return nil end
    local ok, st = pcall(function()
        return game:GetService("DataStoreService"):GetDataStore(require(Shared:WaitForChild("MusicAudition")).STORE)
    end)
    return ok and st or nil
end
local function MusicLoad(): any
    if musicMem then return musicMem end
    local st = MusicStore()
    local ok, data = false, nil
    if st then ok, data = pcall(function() return st:GetAsync(require(Shared.MusicAudition).KEY) end) end
    if st and not ok then warn("[MusicAudition] keeps store unreachable (memory only this session): " .. tostring(data)) end
    musicMem = type(data) == "table" and data or {}
    return musicMem
end
function AdminService.MusicKeeps(admin: Player, action: string, id: any, on: any)
    local MA = require(Shared:WaitForChild("MusicAudition"))
    local rec = MusicLoad()
    if action == "MusicKeeps" then
        local out = {}
        for k in pairs(rec) do out[tonumber(k) or k] = true end
        return out
    end
    if action == "MusicKeepsPrint" then
        local n = 0
        for _, t in ipairs(MA.LIST) do
            if rec[tostring(t.Id)] then n += 1; print("MUSIC KEEP: " .. t.Id .. " " .. t.Name .. "  (" .. t.By .. ", " .. t.Group .. ")") end
        end
        print("MUSIC KEEPS: " .. n .. " kept")
        return true, n .. " kept: printed to the Output."
    end
    local t = MA.ById[tonumber(id) or -1]
    if not t or t.Group == "Reference" then return false, "Not an audition track." end
    local key = tostring(t.Id)
    if on then
        rec[key] = { Name = t.Name, By = t.By, Group = t.Group, At = os.time(), Who = admin.Name }
        print("MUSIC KEEP: " .. t.Id .. " " .. t.Name .. "  (" .. t.By .. ", " .. t.Group .. ")")
    else
        rec[key] = nil
        print("MUSIC UNKEEP: " .. t.Id .. " " .. t.Name)
    end
    local st = MusicStore()
    local saved = false
    if st then
        saved = pcall(function()
            st:UpdateAsync(MA.KEY, function(old)
                old = type(old) == "table" and old or {}
                old[key] = rec[key]
                return old
            end)
        end)
    end
    if not saved and st then warn("[MusicAudition] pick kept in memory only (DataStore write failed)") end
    return true, saved and "Saved." or (st and "Kept (memory only: the DataStore write failed)." or "Kept for this session (Studio: the Output has the MUSIC KEEP line).")
end

function AdminService.Init(CombatServer: any)
    local function Target(uid: any): (Player?, any)
        local p = type(uid) == "number" and Players:GetPlayerByUserId(uid) or nil
        return p, p and CombatServer.GetState(p) or nil
    end
    local function Notify(p: Player, text: string)
        Remotes.GetEvent("CombatFx"):FireClient(p, "Text", text, Color3.fromRGB(255, 196, 70))
    end
    local function Sync(p: Player, state: any)
        if CombatServer.SyncBarStyle then pcall(CombatServer.SyncBarStyle, p, state) end
        Remotes.GetEvent("SyncPlayerState"):FireClient(p, state)
    end

    -- (AdminService.Act: the same function, for DevCmd "admin" -- a remote's callback can't be read back)
    AdminService.Act = function(admin: Player, action: any, uid: any, ref: any, cmdArgs: any)
        if not AdminService.IsAdmin(admin) then return false, "Not an admin." end
        if action == "Check" then return true end
        -- the LIVE ERROR LOG (ErrorLog): every server's + player's script errors, grouped and counted
        if action == "Errors" then return require(script.Parent:WaitForChild("ErrorLog")).List() end
        if action == "ClearErrors" then
            require(script.Parent:WaitForChild("ErrorLog")).Clear()
            print("[Admin] " .. admin.Name .. " cleared the error log")
            return true, "Error log cleared."
        end
        if action == "Players" then
            local out = {}
            for _, p in ipairs(Players:GetPlayers()) do
                table.insert(out, { UserId = p.UserId, Name = p.Name, DisplayName = p.DisplayName, You = p == admin })
            end
            return out
        end
        -- (2026-10-24) MUSIC AUDITION picks (F6 > MUSIC, AimRngShared/MusicAudition): ("MusicKeeps") -> { [id] = true },
        -- ("MusicKeep", id, on) -> ok, msg, ("MusicKeepsPrint") -> ok, msg. Saved in DataStore DevMusicAudition_v1 / "keeps"
        -- so they survive a Studio Stop / Play (memory only if the store can't be reached); every change prints a line.
        if action == "MusicKeeps" or action == "MusicKeep" or action == "MusicKeepsPrint" then
            return AdminService.MusicKeeps(admin, action, uid, ref)
        end
        local target, state = Target(uid)
        if not target or not state then return false, "That player isn't in this server any more." end
        -- ADMIN MENU COMMANDS (0.65): ref = command id, cmdArgs = the raw field values (AdminCommands)
        if action == "Cmd" then
            local AC = require(Shared:WaitForChild("AdminCommands"))
            local cmd = type(ref) == "string" and AC.ById[ref] or nil
            if not cmd then return false, "Unknown command." end
            if cmd.Studio and not RunService:IsStudio() then return false, cmd.Label .. " only works in Studio." end
            local args = AC.Coerce(cmd, cmdArgs)
            print("[Admin] " .. admin.Name .. " ran " .. cmd.Id .. " on " .. target.Name .. " " .. game:GetService("HttpService"):JSONEncode(args))
            if cmd.Server then
                local function Root(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
                if cmd.Id == "goto" or cmd.Id == "bring" then
                    local from, to = admin, target
                    if cmd.Id == "bring" then from, to = target, admin end
                    local r1, r2 = Root(from), Root(to)
                    if not (r1 and r2) then return false, "No character to move." end
                    if from == to then return false, "That's you." end
                    from.Character:PivotTo(r2.CFrame * CFrame.new(0, 0, 4))
                    return true, (cmd.Id == "goto") and ("Went to " .. target.DisplayName .. ".") or ("Brought " .. target.DisplayName .. ".")
                elseif cmd.Id == "kick" then
                    if target == admin then return false, "You can't kick yourself." end
                    target:Kick(args[1] or "Kicked by an admin")
                    return true, "Kicked " .. target.DisplayName .. "."
                end
                return false, "Unknown command."
            end
            local DC = require(script.Parent:WaitForChild("DevCommands"))
            if not DC.Run then return false, "Commands aren't ready yet." end
            local ok, res = pcall(DC.Run, target, cmd.Id, table.unpack(args, 1, #cmd.Args))
            if not ok then return false, "Error: " .. tostring(res) end
            return true, tostring(res)
        end
        if action == "Owned" then
            local out = {}
            for _, e in ipairs(AdminService.Giftable()) do
                if Cosmetics.Owns(state, e) then out[e.Cat .. ":" .. e.Id] = true end
            end
            for _, e in ipairs(Colorways.GiftRows()) do -- (0.93; BOUND points rows are never "owned": always GIVE)
                if e.Kind and Colorways.Owns(state, e.Kind, e.V) then out[e.Cat .. ":" .. e.Id] = true end
            end
            for _, list in ipairs({ state.Inventory or {}, state.GearInventory or {} }) do -- (CHASE ITEMS: a Zenith in the bag = owned)
                for _, it in ipairs(list) do if type(it) == "table" and ItemData.ZenithOf(it) then out["Zenith:" .. it.Exotic] = true end end
            end
            local s = Seasons.Ensure(state)
            out.SeasonPass = s.Premium == true
            return out
        end
        if type(ref) ~= "string" then return false, "Pick an item." end
        local who = target.DisplayName
        -- (0.93) COLOURWAYS "Colorway:Tempest:2" (give = own + wear it on the whole set; take = remove + back to the
        -- original where it was worn) and BOUND POINTS "BoundPoints:100" (give adds, take removes that many)
        local cwKind, cwV = string.match(ref, "^Colorway:(.-):(%d+)$")
        local bpN = tonumber(string.match(ref, "^BoundPoints:(%d+)$") or "")
        -- (UPDATE 7) STASH TABS "StashTab:<kind>"
        local tabKind = string.match(ref, "^StashTab:(%a+)$")
        if tabKind then
            local ST = require(game.ReplicatedStorage.AimRngShared.StashTabs)
            if not ST.Kinds[tabKind] then return false, "Unknown tab." end
            state.Hideout = type(state.Hideout) == "table" and state.Hideout or {}
            local h = ST.Ensure(state)
            if ST.Kinds[tabKind].Special then -- (GEM / MAP: a count, not a box)
                h.Special = type(h.Special) == "table" and h.Special or {}
                h.Special[tabKind] = math.clamp(ST.Special(state, tabKind) + ((action == "Give") and 1 or -1), 0, ST.SPECIAL_MAX)
                if action == "Give" then Notify(target, "★ " .. admin.DisplayName .. " gifted you a " .. string.upper(tabKind) .. " tab") end
                Sync(target, state)
                return true, (action == "Give" and "Gave " or "Took ") .. "a " .. tabKind .. " tab (" .. who .. " has " .. ST.Special(state, tabKind) .. ")."
            end
            if action == "Give" then
                local n = ST.Bought(state, tabKind) + 1
                table.insert(h.Tabs, { Id = tabKind:upper() .. "G" .. n .. "_" .. tostring(os.time() % 100000), Kind = tabKind, Name = ST.Kinds[tabKind].Name .. " " .. (n + 1), W = {}, G = {} })
                Notify(target, "★ " .. admin.DisplayName .. " gifted you a " .. string.upper(tabKind) .. " stash tab")
            else
                local removed = false
                for i = #h.Tabs, 1, -1 do
                    local t = h.Tabs[i]
                    if t.Kind == tabKind and t.Id ~= "TRADE1" and ST.Count(t) == 0 then table.remove(h.Tabs, i); removed = true; break end
                end
                if not removed then return false, "No empty bought " .. tabKind .. " tab to take." end
            end
            Sync(target, state)
            return true, (action == "Give" and "Gave " or "Took ") .. "a " .. tabKind .. " tab (" .. who .. " has " .. ST.Bought(state, tabKind) .. " bought)."
        end
        -- (UPDATE 8 phase 3) SHOT MODS "ShotMod:<id|ALL>:<level>" (Colorways.GiftRows): give = into the mod bag, take = the
        -- first one of that mod in the bag (ALL: one of each)
        local smId, smLv = string.match(ref, "^ShotMod:(%w+):(%d+)$")
        if smId then
            local SMod = require(game.ReplicatedStorage.AimRngShared.ShotMods)
            local ids = (smId == "ALL") and SMod.ORDER or { smId }
            if smId ~= "ALL" and not SMod.DEFS[smId] then return false, "Unknown mod." end
            local n = 0
            state.ShotMods = type(state.ShotMods) == "table" and state.ShotMods or {}
            for _, id in ipairs(ids) do
                if action == "Give" then
                    if CombatServer.Off.GiveShotMod(target, state, id, tonumber(smLv) or 1, 0, true) then n += 1 end
                else
                    for i, it in ipairs(state.ShotMods) do if it.Mod == id then table.remove(state.ShotMods, i); n += 1; break end end
                end
            end
            if action == "Give" and n > 0 then Notify(target, "★ " .. admin.DisplayName .. " gifted you " .. ((n == 1) and ("the mod " .. SMod.DEFS[ids[1]].Name) or (n .. " mods"))) end
            Sync(target, state)
            print("[Admin] " .. admin.Name .. " " .. string.lower(action) .. " " .. ref .. " -> " .. target.Name)
            return n > 0, (action == "Give" and "Gave " or "Took ") .. n .. " mod" .. (n == 1 and "" or "s") .. " (" .. who .. " has " .. #state.ShotMods .. " in the bag)."
        end
        -- (CHASE ITEMS 2026-11-06) ZENITHS "Zenith:<id>": give = one into the bag at the target's level (ItemData.MakeZenith; the
        -- ZENITH_LIVE switch never blocks a gift), take = the first one of that id in the bag (equipped ones are left alone)
        local zId = string.match(ref, "^Zenith:(%w+)$")
        if zId then
            local d = ItemData.Exotics[zId]
            if not (d and d.Zenith) then return false, "Unknown Zenith." end
            local isW = d.Kind == "Weapon"
            local list = isW and state.Inventory or state.GearInventory
            if action == "Give" then
                local it = ItemData.MakeZenith(zId, ItemData.ZenithLevel(state.Level)) -- (the target's level, clamped like every item level)
                if not it then return false, "Couldn't make it." end
                table.insert(list, it)
                if isW then state.StatsTracking.DiscoveredWeapons[it.BaseId] = true end
                Notify(target, "★ " .. admin.DisplayName .. " gifted you the Zenith " .. d.Name)
            else
                local gone = false
                for i, it in ipairs(list) do if it.Exotic == zId and not (isW and state.EquippedWeapon == it) then table.remove(list, i); gone = true; break end end
                if not gone then return false, who .. " has no " .. d.Name .. " in the bag." end
            end
            Sync(target, state)
            print("[Admin] " .. admin.Name .. " " .. string.lower(action) .. " " .. ref .. " -> " .. target.Name)
            local n = 0
            for _, it in ipairs(list) do if it.Exotic == zId then n += 1 end end
            return true, (action == "Give" and "Gave " or "Took ") .. d.Name .. " (" .. who .. " has " .. n .. " in the bag)."
        end
        -- (UPDATE 7) CURRENCIES "Currency:<key>:<n>" (Colorways.GiftRows): give adds n, take removes n (never below 0)
        local curKey, curN = string.match(ref, "^Currency:(%w+):(%d+)$")
        if curKey and ItemData.MaterialDefs[curKey] then
            local n = tonumber(curN) or 0
            state.Materials = state.Materials or ItemData.NewMaterials()
            state.Materials[curKey] = math.max(0, (state.Materials[curKey] or 0) + ((action == "Give") and n or -n))
            local name = ItemData.MaterialDefs[curKey].Name
            if action == "Give" then Notify(target, "★ " .. admin.DisplayName .. " gifted you " .. n .. " " .. name) end
            Sync(target, state)
            print("[Admin] " .. admin.Name .. " " .. string.lower(action) .. " " .. ref .. " -> " .. target.Name)
            return true, (action == "Give" and "Gave " or "Took ") .. n .. " " .. name .. " (" .. who .. " has " .. state.Materials[curKey] .. ")."
        end
        if cwKind and Colorways.Info(cwKind, tonumber(cwV)) then
            local v = tonumber(cwV)
            state.Colorways = type(state.Colorways) == "table" and state.Colorways or {}
            local rec = type(state.Colorways[cwKind]) == "table" and state.Colorways[cwKind] or {}
            rec.Own = type(rec.Own) == "table" and rec.Own or {}
            rec.Items = type(rec.Items) == "table" and rec.Items or {}
            local name = cwKind .. ": " .. Colorways.Info(cwKind, v).Name
            if action == "Give" then
                rec.Own[tostring(v)] = true
                rec.Set, rec.Items = v, {}
                Notify(target, "★ " .. admin.DisplayName .. " gifted you the " .. string.upper(name) .. " colourway")
            else
                rec.Own[tostring(v)] = nil
                if tonumber(rec.Set) == v then rec.Set = nil end
                for r, iv in pairs(rec.Items) do if tonumber(iv) == v then rec.Items[r] = nil end end
            end
            state.Colorways[cwKind] = rec
            CombatServer.SyncBarStyle(target, state)
            Sync(target, state)
            print("[Admin] " .. admin.Name .. " " .. string.lower(action) .. " " .. ref .. " -> " .. target.Name)
            return true, (action == "Give" and "Gave " or "Took ") .. name .. (action == "Give" and " to " or " from ") .. who .. "."
        elseif bpN then
            CombatServer.GrantBoundPoints(target, state, action == "Give" and bpN or -bpN)
            if action == "Give" then Notify(target, "★ " .. admin.DisplayName .. " gifted you " .. bpN .. " BOUND points") end
            Sync(target, state)
            print("[Admin] " .. admin.Name .. " " .. string.lower(action) .. " " .. ref .. " -> " .. target.Name)
            return true, (action == "Give" and "Gave " or "Took ") .. bpN .. " BOUND points (" .. who .. " has " .. Colorways.Points(state) .. ")."
        end
        if action == "Give" then
            if ref == "SeasonPass" then
                CombatServer.GrantSeasonPremium(target, state)
                Notify(target, "★ " .. admin.DisplayName .. " gifted you the PREMIUM SEASON PASS")
                print("[Admin] " .. admin.Name .. " gave " .. target.Name .. " the season pass")
                return true, "Gave " .. who .. " the premium season pass."
            elseif ref == "AllPremium" then
                local n = 0
                for _, e in ipairs(AdminService.Giftable()) do
                    -- (0.65: bundle-only pieces too -- the set UI themes + kill effects were skipped)
                    if (e.Unlock == "Robux" or e.Unlock == "Bundle") and e.Cat ~= "Bundle" and not Cosmetics.Owns(state, e) then
                        Cosmetics.Grant(state, e); n += 1
                    end
                end
                -- (0.93) every colourway too (owned, not worn)
                state.Colorways = type(state.Colorways) == "table" and state.Colorways or {}
                for _, e in ipairs(Colorways.GiftRows()) do
                    if e.Kind and not Colorways.Owns(state, e.Kind, e.V) then
                        local rec = type(state.Colorways[e.Kind]) == "table" and state.Colorways[e.Kind] or {}
                        rec.Own = type(rec.Own) == "table" and rec.Own or {}
                        rec.Items = type(rec.Items) == "table" and rec.Items or {}
                        rec.Own[tostring(e.V)] = true
                        state.Colorways[e.Kind] = rec
                        n += 1
                    end
                end
                Sync(target, state)
                Notify(target, "★ " .. admin.DisplayName .. " gifted you EVERY premium cosmetic. Check COSMETICS [H]")
                print("[Admin] " .. admin.Name .. " gave " .. target.Name .. " all premium cosmetics (" .. n .. ")")
                return true, "Gave " .. who .. " " .. n .. " premium cosmetics."
            end
            local cat, id = string.match(ref, "^(.-):(.*)$")
            local e = cat and Cosmetics.Find(cat, id)
            if not e then return false, "Unknown item." end
            if Cosmetics.Tradeable(e) and Cosmetics.Owns(state, e) then -- (2026-10-14 COPIES: owned already -> one more copy)
                Cosmetics.AddCopy(state, e)
                Sync(target, state)
            else
                CombatServer.GrantCosmetic(target, state, cat, id, false)
            end
            Notify(target, "★ " .. admin.DisplayName .. " gifted you " .. string.upper(e.Name) .. ". Equip it in COSMETICS [H]")
            print("[Admin] " .. admin.Name .. " gave " .. target.Name .. " " .. ref)
            return true, "Gave " .. who .. " " .. e.Name .. "."
        elseif action == "Take" then
            if ref == "SeasonPass" then
                local s = Seasons.Ensure(state)
                s.Premium = false
                Sync(target, state)
                print("[Admin] " .. admin.Name .. " took the season pass from " .. target.Name)
                return true, "Took the premium season pass from " .. who .. " (premium rewards already claimed stay)."
            end
            local cat, id = string.match(ref, "^(.-):(.*)$")
            local e = cat and Cosmetics.Find(cat, id)
            if not e then return false, "Unknown item." end
            Revoke(target, state, e)
            Sync(target, state)
            print("[Admin] " .. admin.Name .. " took " .. ref .. " from " .. target.Name)
            return true, "Took " .. e.Name .. " from " .. who .. "."
        end
        return false, "Unknown action."
    end
    Remotes.GetFunction("AdminAction").OnServerInvoke = AdminService.Act
end

return AdminService
