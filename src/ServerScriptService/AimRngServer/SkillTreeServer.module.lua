--!nocheck
-- Passive tree + gem sockets (server side).
--   AllocateSkillNode(id)      a node next to your tree (or inside a Thread of Fate gem's radius)
--   RefundSkillNode(id)        un-allocate one node if the rest of your tree stays connected
--   RespecSkillTree()          refund everything; gems go back to your gem bag
--   ExpertiseAction("Pick", expertiseNodeId, effectId) / ("Refund", expertiseNodeId)
--                              (2026-10-22) EXPERTISE: 1 point once you hold a notable of its ring, one effect of its family,
--                              each effect once per tree (ExpertiseData); changing a pick = one refund
--   REFUNDS (2026-10-22, the reference game's per-point refunds): every point back costs one Unwind if you have one, else
--   ItemData.RefundGold(level) gold (free through ItemData.REFUND_FREE_LEVEL); a full respec = that x every point
--   SocketGem(socketId, uid)   put a gem from your bag into an allocated socket (hub only); a gem already
--                              there goes back to the bag
--   UnsocketGem(socketId)      take it out (hub only)
--   SalvageGem(uid)            break a bag gem into materials
--   ChooseClass(classId)       pick your class (first time free); changing it costs a Rebirth Shard and refunds the tree
-- State fields: Class, AllocatedNodes, SkillPoints, Gems (bag, list), SocketedGems (socketId -> gem), TreeVersion,
-- Expertise ({ [expertise node id] = effect id }).
-- TREE v4 (2026-10-05): your tree grows from your CLASS's start node (ClassData), not a shared Origin. No class = no
-- tree yet (AllocatedNodes empty) -- the client shows the class picker.
local Remotes = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Remotes"))
local SkillTreeData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("SkillTreeData"))
local GemData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("GemData"))
local ItemData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ItemData"))
local ClassData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ClassData"))
local AscendancyData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("AscendancyData"))
local ExpertiseData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ExpertiseData"))

local function GetCombatServer(): any
    local mod = script.Parent:FindFirstChild("CombatServer") or (script:FindFirstChild("CombatServer"))
    if not mod then
        mod = script.Parent:WaitForChild("CombatServer", 5) or script:WaitForChild("CombatServer", 5)
    end
    return require(mod :: ModuleScript)
end
local CombatServer = GetCombatServer()

local SkillTreeServer = {}

SkillTreeServer.TREE_VERSION = 10 -- (v10: CLASS BUILDS -- Cornerstones moved between spots + Slug Rounds / Field Commander / Carom Shot, some notables re-pointed; v9: UPDATE 8 phase 4 -- the tree rebuilt on the new stats, ~2,500 nodes; specialization nodes refunded) bump when node ids/meanings change: older trees are refunded on load (v8: 2026-10-21 passive points v5 + node values v5, the reference game's bands; v7: 0.63 playstyle keystones moved to the outer edge; v6: 0.62 playstyle passives; v4: classes, v5: weapon classes)
-- PLAYSTYLE KEYSTONES (0.63, owner: "You should NOT be able to get all of those"): the 10 universal X_PSK_* keystones sit
-- on the outer edge (~80 points to the nearest one) and at most PLAYSTYLE_MAX of them can be allocated at once.
SkillTreeServer.PLAYSTYLE_MAX = 3
local function IsPlaystyle(id: string): boolean return string.sub(id, 1, 6) == "X_PSK_" end

local function SetOf(list: { string }): { [string]: boolean }
    local s = {}
    for _, id in ipairs(list) do s[id] = true end
    return s
end

-- ===== EXPERTISE (2026-10-22) =====
-- EXPERTISE_OF[notable id] = the expertise node whose ring holds it
local EXPERTISE_OF: { [string]: string } = {}
for id, n in pairs(SkillTreeData) do
    if n.Type == "Expertise" then
        for _, nid in ipairs(n.Ring or {}) do EXPERTISE_OF[nid] = id end
    end
end
SkillTreeServer.EXPERTISE_OF = EXPERTISE_OF
local function RingHeld(node: any, allocSet: { [string]: boolean }): boolean
    for _, nid in ipairs(node.Ring or {}) do if allocSet[nid] then return true end end
    return false
end
local function ExpertiseCount(state: any): number
    local n = 0
    for _ in pairs(type(state.Expertise) == "table" and state.Expertise or {}) do n += 1 end
    return n
end
SkillTreeServer.ExpertiseCount = ExpertiseCount
-- keeps only picks whose node exists, whose ring has a held notable, whose effect is of the node's family and not used twice
local function ValidateExpertise(state: any, allocSet: { [string]: boolean })
    local picks = type(state.Expertise) == "table" and state.Expertise or {}
    local out, used = {}, {}
    local ids = {}
    for id in pairs(picks) do table.insert(ids, id) end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local node, eff = SkillTreeData[id], picks[id]
        local e = type(eff) == "string" and ExpertiseData.Effects[eff]
        if node and node.Type == "Expertise" and e and e.Family == node.Family and not used[eff] and RingHeld(node, allocSet) then
            out[id] = eff
            used[eff] = true
        end
    end
    state.Expertise = out
end
SkillTreeServer.ValidateExpertise = ValidateExpertise

-- ===== PAID REFUNDS (2026-10-22) =====
-- pays for n refunded points (Unwinds first, then gold); returns ok, a " for ..." text or the reason it can't
local function PayRefund(state: any, n: number): (boolean, string)
    local u, gold = ItemData.RefundCost(state, n)
    if (state.Gold or 0) < gold then
        local per = ItemData.RefundGold(state.Level)
        return false, string.format("Refunding costs %s gold a point (or one Unwind): %s gold for this.", ItemData.FormatNumber(per), ItemData.FormatNumber(gold))
    end
    state.Materials = state.Materials or ItemData.NewMaterials()
    if u > 0 then state.Materials.Unwind = math.max(0, (state.Materials.Unwind or 0) - u) end
    state.Gold -= gold
    local parts = {}
    if u > 0 then table.insert(parts, u .. " Unwind" .. (u == 1 and "" or "s")) end
    if gold > 0 then table.insert(parts, ItemData.FormatNumber(gold) .. " gold") end
    return true, (#parts > 0) and (" for " .. table.concat(parts, " + ")) or ""
end
SkillTreeServer.PayRefund = PayRefund

-- Every allocated node that is still reachable from the root (your class start; through allocated nodes; Thread of
-- Fate radius nodes count as anchored when their socket is reachable).
local function Reachable(allocated: { [string]: boolean }, socketed: { [string]: any }?, root: string?): { [string]: boolean }
    if not root then return {} end
    local seen = { [root] = true }
    local queue, head = { root }, 1
    local function visit(id: string)
        if allocated[id] and not seen[id] then
            seen[id] = true
            table.insert(queue, id)
        end
    end
    while head <= #queue do
        local cur = queue[head]
        head += 1
        local node = SkillTreeData[cur]
        for _, nb in ipairs(node and node.Connections or {}) do visit(nb) end
        local g = socketed and socketed[cur]
        if g and type(g) == "table" and g.Unique == "THREAD" then
            for _, id in ipairs(GemData.NodesInRadius(cur)) do visit(id) end
        end
    end
    return seen
end
SkillTreeServer.Reachable = Reachable

local function InDungeon(player: Player): boolean
    local DungeonRuns = require(script.Parent:WaitForChild("DungeonRuns"))
    local PartyRuns = require(script.Parent:WaitForChild("PartyRuns"))
    return DungeonRuns.Attr(player, "RaidActive") == true or PartyRuns.RunOfPlayer(player) ~= nil
end

local function Sync(player: Player, state: any)
    CombatServer.RecalculateMaxHealth(state)
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
end

-- Load-time cleanup (called from CombatServer.GetState): refund trees from an older tree version, drop
-- unknown node ids, refund nodes no longer connected, return gems in unallocated / unknown sockets.
-- ASCENDANCY (tree v4): it must belong to your class; its nodes must be its own, connected from its start (a
-- mini-tree: every node has one parent) and within your points (AscendancyData.PointsFor = 2 per Boss Trial tier).
local function ValidateAsc(state: any)
    state.AscNodes = type(state.AscNodes) == "table" and state.AscNodes or {}
    local a = state.Ascendancy and AscendancyData.ById[state.Ascendancy]
    if not a or a.Class ~= state.Class then
        state.Ascendancy, state.AscNodes = nil, {}
        return
    end
    local set = {}
    for _, id in ipairs(state.AscNodes) do
        local n = AscendancyData.Nodes[id]
        if n and n.Asc == a.Id then set[id] = true end
    end
    local budget = AscendancyData.PointsFor(state)
    local kept, queue = { a.Start }, { a.Start }
    while #queue > 0 do
        local id = table.remove(queue, 1)
        for _, ch in ipairs(AscendancyData.Nodes[id].Children) do
            if set[ch] and #kept - 1 < budget then
                table.insert(kept, ch)
                table.insert(queue, ch)
            end
        end
    end
    state.AscNodes = kept
end
SkillTreeServer.ValidateAsc = ValidateAsc

-- PASSIVE SKILLS (0.49): every allocated keystone is unlocked; state.EquippedPassives (max ClassData.PassiveLimit(state.Level)) are
-- the ones that work (StatCalculator). Saves from before 0.49 (no list): whatever was allocated was in use -- equipped.
local function ValidatePassives(state: any)
    local alloc = SetOf(state.AllocatedNodes or {})
    local eq = {}
    local function Try(id)
        local n = type(id) == "string" and SkillTreeData[id]
        if n and n.Type == "Keystone" and alloc[id] and not table.find(eq, id) and #eq < ClassData.PassiveLimit(state.Level) then table.insert(eq, id) end
    end
    if type(state.EquippedPassives) == "table" then
        for _, id in ipairs(state.EquippedPassives) do Try(id) end
    else
        for _, id in ipairs(state.AllocatedNodes or {}) do Try(id) end
    end
    state.EquippedPassives = eq
end
SkillTreeServer.ValidatePassives = ValidatePassives

function SkillTreeServer.Validate(state: any)
    state.Gems = type(state.Gems) == "table" and state.Gems or {}
    state.SocketedGems = type(state.SocketedGems) == "table" and state.SocketedGems or {}
    if state.Class ~= nil and not ClassData.ById[state.Class] then state.Class = nil end
    ValidateAsc(state)
    local root = ClassData.StartOf(state.Class)
    state.AllocatedNodes = type(state.AllocatedNodes) == "table" and state.AllocatedNodes or {}
    if (state.TreeVersion or 1) < SkillTreeServer.TREE_VERSION then
        -- tree v4: everything refunded, and the points recomputed for the new income (123 at level 100)
        local spent = 0
        for _, id in ipairs(state.AllocatedNodes) do if id ~= "Origin" and id ~= "Root" then spent += 1 end end
        state.AllocatedNodes = {}
        state.EquippedPassives = {} -- (v6: every passive changed -- pick them again)
        state.Expertise = {}
        state.SkillPoints = ItemData.TreePointsTotal(state)
        if spent > 0 then -- (2026-10-22) a few free refunds while the player settles into the new tree
            state.Materials = state.Materials or ItemData.NewMaterials()
            state.Materials.Unwind = (state.Materials.Unwind or 0) + ItemData.UNWIND_RESET_GIFT
        end
        if (state.TreeVersion or 1) < 10 then state.AscNodes = {} end -- (v9: every specialization node changed meaning; v10 CLASS BUILDS: signature notables + re-pointed nodes; the pick stays)
        if (state.TreeVersion or 1) < 5 then
            -- v5 WEAPON CLASSES (2026-10-05): every class changed meaning, so everyone picks again (free: no class yet)
            -- and the ascendancy is refunded with it
            state.Class = nil
            state.Ascendancy, state.AscNodes = nil, {}
            root = nil
        end
        state.TreeVersion = SkillTreeServer.TREE_VERSION
        state.TreeWasReset = spent > 0 -- the client tells the player once
    end
    if not root then
        -- no class yet: no tree (the picker comes up); any stray nodes are refunded
        local stray = 0
        for _, id in ipairs(state.AllocatedNodes) do if SkillTreeData[id] and SkillTreeData[id].Type ~= "ClassStart" then stray += 1 end end
        state.AllocatedNodes = {}
        state.SkillPoints = (state.SkillPoints or 0) + stray
        for sid, g in pairs(state.SocketedGems) do
            state.SocketedGems[sid] = nil
            if type(g) == "table" then table.insert(state.Gems, g) end
        end
        state.EquippedPassives = {}
        state.Expertise = {}
        state.SkillPoints = ItemData.TreePointsTotal(state)
        return
    end
    local set = {}
    local refunded = 0
    for _, id in ipairs(state.AllocatedNodes) do
        local n = SkillTreeData[id]
        if n and not set[id] and (n.Type ~= "ClassStart" or id == root) then set[id] = true
        elseif id ~= "Root" and id ~= "Origin" and not (n and n.Type == "ClassStart") then refunded += 1 end
    end
    set[root] = true
    local reach = Reachable(set, state.SocketedGems, root)
    local kept = { root }
    for id in pairs(set) do
        if id ~= root then
            if reach[id] then table.insert(kept, id) else refunded += 1 end
        end
    end
    state.AllocatedNodes = kept
    local keptSet = SetOf(kept)
    ValidateExpertise(state, keptSet)
    -- (passive points v5) unspent = everything earned (levels + difficulty clears) minus the nodes kept (+ expertise picks):
    -- the count can never drift from the income, whatever an older version or a refund did to it
    state.SkillPoints = math.max(0, ItemData.TreePointsTotal(state) - (#kept - 1) - ExpertiseCount(state))
    for sid, g in pairs(state.SocketedGems) do
        if not keptSet[sid] or not GemData.IsSocket(sid) or type(g) ~= "table" then
            state.SocketedGems[sid] = nil
            if type(g) == "table" then table.insert(state.Gems, g) end
        end
    end
    ValidatePassives(state)
end

-- Gives a gem (drop / reward); full bag = auto-salvaged into materials.
function SkillTreeServer.GiveGem(player: Player, state: any, gem: any, noAuto: boolean?)
    state.Gems = state.Gems or {}
    -- (0.75 GEM AUTO-SALVAGE: a gem given straight to the bag at or under the threshold salvages instead)
    local gRank = ItemData.RarityRank[state.GemAutoSalvage or ""] or 0 -- (UPDATE 8 GEM GRADES v4: the 5 rarities)
    if not noAuto and gRank > 0 and (ItemData.RarityRank[gem.Rarity] or 1) <= gRank then
        CombatServer.GrantMaterials(player, state, GemData.Yield(gem), nil, true)
        Remotes.GetEvent("CombatFx"):FireClient(player, "Text", "GEM AUTO-SALVAGED: " .. string.upper(gem.Rarity), Color3.fromRGB(170, 150, 220))
        return false
    end
    if #state.Gems >= require(game.ReplicatedStorage.AimRngShared.StashTabs).GemCap(state) then -- (UPDATE 7: + GEM tabs)
        local y = GemData.Yield(gem)
        CombatServer.GrantMaterials(player, state, y, nil, true)
        return false
    end
    table.insert(state.Gems, gem)
    Remotes.GetEvent("LootAnnounce"):FireClient(player, gem, nil, false)
    return true
end

function SkillTreeServer.Init()
    local function Allocate(player: Player, targetNodeId: string): (boolean, string)
        if type(targetNodeId) ~= "string" then return false, "Bad node." end
        local state = CombatServer.GetState(player)
        local node = SkillTreeData[targetNodeId]
        if not node then return false, "Node not found." end
        if table.find(state.AllocatedNodes, targetNodeId) then return false, "Already allocated." end
        if not ClassData.StartOf(state.Class) then return false, "Pick a class first." end
        if state.SkillPoints <= 0 then return false, "No unspent skill points." end
        if node.Type == "ClassStart" then return false, "That's another class's start." end
        if node.Type == "Expertise" then return false, "Pick an Expertise effect from its panel." end

        local allocatedSet = SetOf(state.AllocatedNodes)
        local connected = false
        for _, conn in ipairs(node.Connections) do
            if allocatedSet[conn] then connected = true; break end
        end
        if not connected and GemData.LeapNodes(state.SocketedGems, allocatedSet)[targetNodeId] then connected = true end
        if not connected then return false, "Node must connect to an allocated node." end
        if IsPlaystyle(targetNodeId) then
            local n = 0
            for _, id in ipairs(state.AllocatedNodes) do if IsPlaystyle(id) then n += 1 end end
            if n >= SkillTreeServer.PLAYSTYLE_MAX then
                return false, string.format("You can hold at most %d playstyle cornerstones: refund one first.", SkillTreeServer.PLAYSTYLE_MAX)
            end
        end

        state.SkillPoints -= 1
        table.insert(state.AllocatedNodes, targetNodeId)
        local extra = ""
        if node.Type == "Keystone" then -- (a free slot equips it straight away)
            state.EquippedPassives = type(state.EquippedPassives) == "table" and state.EquippedPassives or {}
            if #state.EquippedPassives < ClassData.PassiveLimit(state.Level) then
                table.insert(state.EquippedPassives, targetNodeId)
                extra = " (equipped)"
            else
                extra = string.format(" (unlocked: all %d passive slots are full, swap it in with ★ PASSIVES)", ClassData.PassiveLimit(state.Level))
            end
        end
        Sync(player, state)
        return true, "Allocated: " .. node.Name .. extra
    end
    Remotes.GetFunction("AllocateSkillNode").OnServerInvoke = Allocate
    SkillTreeServer.Allocate = Allocate -- (DevCommands "treepath")

    -- (QOL M2 2026-10-28, owner: "Undo-before applying in passive") APPLY of the tree's PENDING nodes (client TreePending): the
    -- whole set in one call, validated as a SET by the same rules as Allocate -- class picked, enough points, no class start /
    -- Expertise / already-held node, the cornerstone limit, and every node connected to what you hold (or to a gem's radius) or
    -- to another node of the set that is (any order) -- then ALL of them or NONE, one state sync.
    local function AllocateMany(player: Player, list: any): (boolean, string)
        if type(list) ~= "table" then return false, "Bad list." end
        local ids, seen = {}, {}
        for i, v in ipairs(list) do
            if i > 400 then return false, "Too many nodes at once." end
            if type(v) ~= "string" or seen[v] then return false, "Bad node." end
            seen[v] = true
            table.insert(ids, v)
        end
        if #ids == 0 then return false, "Nothing to apply." end
        local state = CombatServer.GetState(player)
        if not ClassData.StartOf(state.Class) then return false, "Pick a class first." end
        if #ids > state.SkillPoints then return false, string.format("Needs %d skill points (you have %d).", #ids, state.SkillPoints) end
        local set = SetOf(state.AllocatedNodes)
        local leap = GemData.LeapNodes(state.SocketedGems, set)
        local nPlay = 0
        for _, id in ipairs(state.AllocatedNodes) do if IsPlaystyle(id) then nPlay += 1 end end
        for _, id in ipairs(ids) do
            local node = SkillTreeData[id]
            if not node then return false, "Node not found." end
            if set[id] then return false, node.Name .. " is already allocated." end
            if node.Type == "ClassStart" then return false, "That's another class's start." end
            if node.Type == "Expertise" then return false, "Pick an Expertise effect from its panel." end
            if IsPlaystyle(id) then nPlay += 1 end
        end
        if nPlay > SkillTreeServer.PLAYSTYLE_MAX then
            return false, string.format("You can hold at most %d playstyle cornerstones: refund one first.", SkillTreeServer.PLAYSTYLE_MAX)
        end
        -- connectivity: grow from the held tree until nothing more joins
        local order, left = {}, ids
        local grown = table.clone(set)
        while #left > 0 do
            local rest = {}
            for _, id in ipairs(left) do
                local ok = leap[id] == true
                if not ok then for _, c in ipairs(SkillTreeData[id].Connections) do if grown[c] then ok = true break end end end
                if ok then grown[id] = true; table.insert(order, id) else table.insert(rest, id) end
            end
            if #rest == #left then return false, SkillTreeData[rest[1]].Name .. " doesn't connect to your tree." end
            left = rest
        end
        local extra = ""
        for _, id in ipairs(order) do
            state.SkillPoints -= 1
            table.insert(state.AllocatedNodes, id)
            if SkillTreeData[id].Type == "Keystone" then -- (as Allocate: a free slot equips it straight away)
                state.EquippedPassives = type(state.EquippedPassives) == "table" and state.EquippedPassives or {}
                if #state.EquippedPassives < ClassData.PassiveLimit(state.Level) then
                    table.insert(state.EquippedPassives, id)
                    extra ..= "  •  " .. SkillTreeData[id].Name .. " equipped"
                else
                    extra ..= "  •  " .. SkillTreeData[id].Name .. " unlocked (passive slots full: swap it in with ★ PASSIVES)"
                end
            end
        end
        Sync(player, state)
        return true, string.format("Applied %d node%s%s", #order, #order == 1 and "" or "s", extra)
    end
    Remotes.GetFunction("AllocateSkillNodes").OnServerInvoke = AllocateMany
    SkillTreeServer.AllocateMany = AllocateMany -- (DevCommands / tests)

    -- ★ PASSIVES menu: equip (on = true) / unequip an allocated passive skill
    Remotes.GetFunction("PassiveEquip").OnServerInvoke = function(player: Player, nodeId: any, on: any): (boolean, string)
        local state = CombatServer.GetState(player)
        local node = type(nodeId) == "string" and SkillTreeData[nodeId]
        if not node or node.Type ~= "Keystone" then return false, "That isn't a passive skill." end
        if not table.find(state.AllocatedNodes or {}, nodeId) then return false, "Allocate it on the tree first." end
        ValidatePassives(state)
        local eq = state.EquippedPassives
        local i = table.find(eq, nodeId)
        if on == true then
            if i then return false, node.Name .. " is already equipped." end
            if #eq >= ClassData.PassiveLimit(state.Level) then return false, string.format("All %d slots are full: unequip one first.", ClassData.PassiveLimit(state.Level)) end
            table.insert(eq, nodeId)
        else
            if not i then return false, node.Name .. " isn't equipped." end
            table.remove(eq, i)
        end
        Sync(player, state)
        return true, (on == true and "Equipped " or "Unequipped ") .. node.Name .. "."
    end

    local function RefundNode(player: Player, nodeId: string): (boolean, string)
        if type(nodeId) ~= "string" or (SkillTreeData[nodeId] and SkillTreeData[nodeId].Type == "ClassStart") then return false, "Can't refund that." end
        local state = CombatServer.GetState(player)
        local idx = table.find(state.AllocatedNodes, nodeId)
        if not idx then return false, "Not allocated." end
        local set = SetOf(state.AllocatedNodes)
        set[nodeId] = nil
        local socketed = table.clone(state.SocketedGems or {})
        socketed[nodeId] = nil
        local reach = Reachable(set, socketed, ClassData.StartOf(state.Class))
        for id in pairs(set) do
            if not reach[id] then return false, "Other nodes depend on it. Refund the outer nodes first." end
        end
        -- (expertise) the last held notable of a ring can't go while its Expertise is picked
        local expId = EXPERTISE_OF[nodeId]
        if expId and type(state.Expertise) == "table" and state.Expertise[expId] and not RingHeld(SkillTreeData[expId], set) then
            return false, "Its " .. SkillTreeData[expId].Name .. " needs it: take that back first."
        end
        if GemData.IsSocket(nodeId) and state.SocketedGems and state.SocketedGems[nodeId] and InDungeon(player) then
            return false, "Unsocket that gem in the hub first."
        end
        local paid, how = PayRefund(state, 1)
        if not paid then return false, how end
        if GemData.IsSocket(nodeId) and state.SocketedGems and state.SocketedGems[nodeId] then
            table.insert(state.Gems, state.SocketedGems[nodeId])
            state.SocketedGems[nodeId] = nil
        end
        table.remove(state.AllocatedNodes, idx)
        state.SkillPoints += 1
        ValidatePassives(state)
        Sync(player, state)
        return true, "Refunded " .. SkillTreeData[nodeId].Name .. how .. "."
    end
    SkillTreeServer.RefundNode = RefundNode
    Remotes.GetFunction("RefundSkillNode").OnServerInvoke = RefundNode

    -- Full respec: refunds every point (nodes + expertise picks) at the single-refund price per point (PayRefund)
    local function Respec(player: Player): (boolean, string)
        local state = CombatServer.GetState(player)
        local root = ClassData.StartOf(state.Class)
        local spent = 0
        for _, id in ipairs(state.AllocatedNodes) do
            if id ~= root then spent += 1 end
        end
        spent += ExpertiseCount(state)
        if spent == 0 then return false, "Nothing to refund." end
        if next(state.SocketedGems or {}) and InDungeon(player) then return false, "Respec in the hub (your gems come out of their sockets)." end
        local paid, how = PayRefund(state, spent)
        if not paid then return false, how end
        state.AllocatedNodes = { root }
        state.EquippedPassives = {}
        state.Expertise = {}
        state.SkillPoints += spent
        for sid, g in pairs(state.SocketedGems or {}) do
            table.insert(state.Gems, g)
            state.SocketedGems[sid] = nil
        end
        Sync(player, state)
        return true, string.format("Refunded %d points%s.", spent, how)
    end
    SkillTreeServer.Respec = Respec
    Remotes.GetFunction("RespecSkillTree").OnServerInvoke = Respec

    -- EXPERTISE: ("Pick", nodeId, effectId) takes an Expertise for 1 point, or changes its pick for one refund;
    -- ("Refund", nodeId) gives the point back for one refund
    local function ExpertiseAct(player: Player, action: any, nodeId: any, effId: any): (boolean, string)
        local state = CombatServer.GetState(player)
        local node = type(nodeId) == "string" and SkillTreeData[nodeId]
        if not node or node.Type ~= "Expertise" then return false, "That isn't an Expertise." end
        if not ClassData.StartOf(state.Class) then return false, "Pick a class first." end
        state.Expertise = type(state.Expertise) == "table" and state.Expertise or {}
        local cur = state.Expertise[nodeId]
        if action == "Pick" then
            local e = type(effId) == "string" and ExpertiseData.Effects[effId]
            if not e or e.Family ~= node.Family then return false, "That effect isn't part of this Expertise." end
            if cur == effId then return false, e.Name .. " is already picked here." end
            for id, other in pairs(state.Expertise) do
                if other == effId and id ~= nodeId then return false, e.Name .. " is already taken at another " .. node.Name .. ". Each effect works once." end
            end
            if not RingHeld(node, SetOf(state.AllocatedNodes or {})) then
                return false, "Allocate a notable of this cluster first."
            end
            if cur == nil then
                if (state.SkillPoints or 0) <= 0 then return false, "No unspent skill points." end
                state.SkillPoints -= 1
                state.Expertise[nodeId] = effId
                Sync(player, state)
                return true, node.Name .. ": " .. e.Name .. "."
            end
            local paid, how = PayRefund(state, 1)
            if not paid then return false, how end
            state.Expertise[nodeId] = effId
            Sync(player, state)
            return true, node.Name .. " changed to " .. e.Name .. how .. "."
        elseif action == "Refund" then
            if cur == nil then return false, "Nothing picked there." end
            local paid, how = PayRefund(state, 1)
            if not paid then return false, how end
            state.Expertise[nodeId] = nil
            state.SkillPoints = (state.SkillPoints or 0) + 1
            Sync(player, state)
            return true, "Refunded " .. node.Name .. how .. "."
        end
        return false, "Bad request."
    end
    SkillTreeServer.ExpertiseAct = ExpertiseAct
    Remotes.GetFunction("ExpertiseAction").OnServerInvoke = ExpertiseAct

    -- CLASS (tree v4): the first pick is free; a change costs 1 Rebirth Shard (Studio: free) and refunds the whole tree
    -- (gems back to the bag) -- in the hub only
    Remotes.GetFunction("ChooseClass").OnServerInvoke = function(player: Player, classId: any): (boolean, string)
        local c = type(classId) == "string" and ClassData.ById[classId]
        if not c then return false, "Unknown class." end
        local state = CombatServer.GetState(player)
        if state.Class == c.Id then return false, "You're already a " .. c.Id .. "." end
        if InDungeon(player) and state.Class ~= nil then return false, "Change class in the hub." end -- (the FIRST pick works anywhere)
        if state.Class ~= nil then
            state.Materials = state.Materials or {}
            if (state.Materials.RebirthShard or 0) < 1 and not game:GetService("RunService"):IsStudio() then
                return false, "Changing class costs 1 Rebirth Shard."
            end
            if (state.Materials.RebirthShard or 0) >= 1 then state.Materials.RebirthShard -= 1 end
        end
        local spent = 0
        for _, id in ipairs(state.AllocatedNodes or {}) do
            local n = SkillTreeData[id]
            if n and n.Type ~= "ClassStart" then spent += 1 end
        end
        for sid, g in pairs(state.SocketedGems or {}) do
            table.insert(state.Gems, g)
            state.SocketedGems[sid] = nil
        end
        spent += ExpertiseCount(state)
        state.Expertise = {}
        state.SkillPoints = (state.SkillPoints or 0) + spent
        local firstPick = state.Class == nil
        state.Class = c.Id
        -- (0.61c, owner: "Starting weapon should be a random weapon from your chosen classes pool"): the FIRST pick swaps the
        -- starter pistol (if you still hold it) for a random Common gun of your class's group
        if firstPick then
            local ItemData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ItemData"))
            local w = ItemData.CreateStarterWeapon(c.Group)
            local old = state.EquippedWeapon
            if old and old.Uid == "W_STARTER_PISTOL" then
                for i, inv in ipairs(state.Inventory) do if inv == old or inv.Uid == old.Uid then table.remove(state.Inventory, i) break end end
            end
            table.insert(state.Inventory, w)
            state.EquippedWeapon = w
            state.IsReloading = false
            state.CurrentMag = w.MagazineSize or state.CurrentMag
        end
        state.AllocatedNodes = { c.Start }
        state.EquippedPassives = {}
        state.Ascendancy, state.AscNodes = nil, {} -- (ascendancy: refunded with the class)
        Sync(player, state)
        return true, (spent > 0) and string.format("You are now a %s. %d passive points refunded.", c.Id, spent) or ("You are now a " .. c.Id .. ".")
    end

    -- ASCENDANCY: ("Choose", ascId) -- free the first time, switching costs a Rebirth Shard (free in Studio);
    -- ("Allocate", nodeId) -- its parent must be allocated and a point free; ("Refund", nodeId) -- free, leaves only
    Remotes.GetFunction("AscendancyAction").OnServerInvoke = function(player: Player, action: any, arg: any): (boolean, string)
        local state = CombatServer.GetState(player)
        if type(action) ~= "string" then return false, "Bad request." end
        if not state.Class then return false, "Pick a class first." end
        state.AscNodes = type(state.AscNodes) == "table" and state.AscNodes or {}
        if action == "Choose" then
            local a = type(arg) == "string" and AscendancyData.ById[arg]
            if not a or a.Class ~= state.Class then return false, "That specialization isn't for your class." end
            if state.Ascendancy == a.Id then return false, "You already follow the " .. a.Name .. "." end
            if InDungeon(player) then return false, "Change specialization in the hub." end
            if AscendancyData.PointsFor(state) <= 0 then
                return false, "Clear a Boss Trial (Challenges > BOSSES) to earn your first specialization points."
            end
            if state.Ascendancy ~= nil then
                state.Materials = state.Materials or {}
                if (state.Materials.RebirthShard or 0) < 1 and not game:GetService("RunService"):IsStudio() then
                    return false, "Switching specialization costs 1 Rebirth Shard."
                end
                if (state.Materials.RebirthShard or 0) >= 1 then state.Materials.RebirthShard -= 1 end
            end
            state.Ascendancy, state.AscNodes, state.AscBuffs = a.Id, { a.Start }, nil
            Sync(player, state)
            return true, "You are now a " .. a.Name .. "."
        end
        local n = type(arg) == "string" and AscendancyData.Nodes[arg]
        if not n or n.Asc ~= state.Ascendancy then return false, "That isn't part of your specialization." end
        if action == "Allocate" then
            if table.find(state.AscNodes, arg) then return false, "Already allocated." end
            if not (n.Parent and table.find(state.AscNodes, n.Parent)) then return false, "Allocate the node before it first." end
            if AscendancyData.Spent(state) >= AscendancyData.PointsFor(state) then
                return false, "No specialization points left. Clear a higher Boss Trial tier for more."
            end
            table.insert(state.AscNodes, arg)
            Sync(player, state)
            return true, "Allocated " .. n.Name .. "."
        elseif action == "Refund" then
            local i = table.find(state.AscNodes, arg)
            if not i or n.Type == "AscStart" then return false, "Can't refund that." end
            for _, ch in ipairs(n.Children) do
                if table.find(state.AscNodes, ch) then return false, "Refund the nodes after it first." end
            end
            table.remove(state.AscNodes, i)
            Sync(player, state)
            return true, "Refunded " .. n.Name .. "."
        end
        return false, "Bad request."
    end

    Remotes.GetFunction("SocketGem").OnServerInvoke = function(player: Player, socketId: string, uid: string): (boolean, string)
        if type(socketId) ~= "string" or type(uid) ~= "string" then return false, "Bad request." end
        local state = CombatServer.GetState(player)
        if InDungeon(player) then return false, "Gems can only be changed in the hub." end
        if not GemData.IsSocket(socketId) then return false, "That isn't a gem socket." end
        if not table.find(state.AllocatedNodes, socketId) then return false, "Allocate the socket first." end
        local idx
        for i, g in ipairs(state.Gems) do if g.Uid == uid then idx = i; break end end
        if not idx then return false, "Gem not found." end
        local gem = state.Gems[idx]
        local ok, why = GemData.CanSocket(state.SocketedGems, socketId, gem)
        if not ok then return false, why or "Can't socket that." end
        table.remove(state.Gems, idx)
        local old = state.SocketedGems[socketId]
        if old then table.insert(state.Gems, old) end
        state.SocketedGems[socketId] = gem
        Sync(player, state)
        return true, "Socketed " .. (gem.Name or "gem") .. "."
    end

    Remotes.GetFunction("UnsocketGem").OnServerInvoke = function(player: Player, socketId: string): (boolean, string)
        local state = CombatServer.GetState(player)
        if InDungeon(player) then return false, "Gems can only be changed in the hub." end
        local gem = type(socketId) == "string" and state.SocketedGems[socketId]
        if not gem then return false, "Nothing socketed there." end
        state.SocketedGems[socketId] = nil
        table.insert(state.Gems, gem)
        -- a Thread of Fate leaving can strand nodes it anchored: refund those
        SkillTreeServer.Validate(state)
        Sync(player, state)
        return true, "Removed " .. (gem.Name or "gem") .. "."
    end

    Remotes.GetFunction("SalvageGem").OnServerInvoke = function(player: Player, uid: string, upTo: any): (boolean, string)
        local state = CombatServer.GetState(player)
        if uid == "*UpTo" then -- (2026-10-14: SALVAGE GEMS UP TO -- every bag gem at or below the rarity; locked ones stay)
            local cap = type(upTo) == "string" and ItemData.RarityRank[upTo] -- (UPDATE 8 GEM GRADES v4: the 5 rarities)
            if not cap then return false, "Pick a rarity." end
            local keep, total, n = {}, {}, 0
            for _, g in ipairs(state.Gems or {}) do
                if (ItemData.RarityRank[g.Rarity] or 99) <= cap and not g.Locked then
                    n += 1
                    for k, v in pairs(GemData.Yield(g)) do total[k] = (total[k] or 0) + v end
                else
                    table.insert(keep, g)
                end
            end
            if n == 0 then return false, "No unlocked gems at " .. upTo .. " or below in your bag." end
            state.Gems = keep
            CombatServer.GrantMaterials(player, state, total, nil, true)
            Sync(player, state)
            local parts = {}
            for _, k in ipairs({ "Scrap", "Alloy", "Prism" }) do
                if total[k] then table.insert(parts, total[k] .. " " .. (ItemData.MaterialDefs[k] and ItemData.MaterialDefs[k].Name or k)) end
            end
            return true, string.format("Salvaged %d gem%s (%s and below) into %s.", n, n == 1 and "" or "s", upTo, table.concat(parts, ", "))
        end
        for i, g in ipairs(state.Gems) do
            if g.Uid == uid then
                if g.Locked then return false, "That gem is locked." end -- (0.76 item lock)
                table.remove(state.Gems, i)
                local y = GemData.Yield(g)
                CombatServer.GrantMaterials(player, state, y, nil, true)
                Sync(player, state)
                local parts = {}
                for _, k in ipairs({ "Scrap", "Alloy", "Prism" }) do
                    if y[k] then table.insert(parts, y[k] .. " " .. (ItemData.MaterialDefs[k] and ItemData.MaterialDefs[k].Name or k)) end
                end
                return true, "Salvaged into " .. table.concat(parts, ", ") .. "."
            end
        end
        return false, "Gem not found."
    end
end

return SkillTreeServer
