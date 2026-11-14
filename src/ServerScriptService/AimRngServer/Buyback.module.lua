--!nocheck
-- BUYBACK (QOL2 I3 2026-10-28, owner: "Do all 14 for now" -- audit: "the row's sell button sells for good").
-- The server keeps the LAST 10 weapons / gear pieces each player SOLD this session -- the row sell buttons (SellWeapon /
-- SellGear), SELL UP TO + quick sell (QuickSellRarity) and auto-sell (new drops) all call Buyback.Add. MEMORY ONLY: never
-- saved, gone when the player leaves (PlayerRemoving). Buying one back costs the gold it sold for and needs bag room.
-- Dupe rule: an entry is the sold item table itself (it already left the bag); Buy takes it OUT of the list before it goes
-- into the bag, with no yield between the checks and the move, and refuses a Uid the player already holds anywhere.
-- Remote function "Buyback": ("List") -> { { Uid, Item, Kind, Gold } } newest first; ("Buy", uid) -> ok, message.
-- Player attribute BuybackCount = the list size (the client shows / hides its BUYBACK button on it; no polling).
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("AimRngShared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemData = require(Shared:WaitForChild("ItemData"))

local Buyback = {}
Buyback.MAX = 10

local lists: { [number]: { any } } = {}
local dirty: { [Player]: boolean } = {}
local lastBuy: { [Player]: number } = {}
local CS = nil

-- the count attribute, once per frame however many items one bulk sell added
local function Touch(player: Player)
    if dirty[player] then return end
    dirty[player] = true
    task.defer(function()
        dirty[player] = nil
        if player.Parent then player:SetAttribute("BuybackCount", #(lists[player.UserId] or {})) end
    end)
end

-- item = the sold table (already out of the bag), kind "Weapon" | "Gear", gold = what it sold for
function Buyback.Add(player: Player, item: any, kind: string, gold: number?)
    if typeof(player) ~= "Instance" or type(item) ~= "table" or type(item.Uid) ~= "string" then return end
    if kind ~= "Weapon" and kind ~= "Gear" then return end
    if item.Uid == "W_STARTER_PISTOL" then return end
    local l = lists[player.UserId]
    if not l then l = {}; lists[player.UserId] = l end
    for i = #l, 1, -1 do if l[i].Item.Uid == item.Uid then table.remove(l, i) end end
    table.insert(l, { Item = item, Kind = kind, Gold = math.max(0, math.floor(tonumber(gold) or 0)) })
    while #l > Buyback.MAX do table.remove(l, 1) end
    Touch(player)
end

local function Holds(state: any, uid: string): boolean
    for _, w in ipairs(state.Inventory or {}) do if w.Uid == uid then return true end end
    for _, g in ipairs(state.GearInventory or {}) do if g.Uid == uid then return true end end
    if state.EquippedWeapon and state.EquippedWeapon.Uid == uid then return true end
    for _, g in pairs(state.EquippedGear or {}) do if type(g) == "table" and g.Uid == uid then return true end end
    return false
end

function Buyback.List(player: Player): { any }
    local out = {}
    local l = lists[player.UserId] or {}
    for i = #l, 1, -1 do
        local e = l[i]
        table.insert(out, { Uid = e.Item.Uid, Item = e.Item, Kind = e.Kind, Gold = e.Gold })
    end
    return out
end

function Buyback.Buy(player: Player, uid: any): (boolean, string)
    if type(uid) ~= "string" then return false, "Pick an item to buy back." end
    local now = os.clock()
    if now - (lastBuy[player] or 0) < 0.2 then return false, "" end
    lastBuy[player] = now
    local state = CS and CS.GetState(player)
    if not state then return false, "Try again in a moment." end
    local l = lists[player.UserId] or {}
    local idx = nil
    for i, e in ipairs(l) do if e.Item.Uid == uid then idx = i end end
    if not idx then return false, "That item isn't in your buyback list any more." end
    local e = l[idx]
    if Holds(state, uid) then -- (should never happen: drop the stale entry, give nothing)
        table.remove(l, idx)
        Touch(player)
        return false, "You already have that item."
    end
    if (state.Gold or 0) < e.Gold then return false, "Not enough gold: it costs " .. ItemData.FormatNumber(e.Gold) .. "." end
    if ItemData.BagRoom(state) <= 0 then return false, "Your bag is full (" .. ItemData.BagCap(state) .. "). Make room first." end
    -- out of the list FIRST, then into the bag (no yield in between)
    table.remove(l, idx)
    state.Gold -= e.Gold
    if e.Kind == "Gear" then
        state.GearInventory = state.GearInventory or {}
        table.insert(state.GearInventory, e.Item)
    else
        table.insert(state.Inventory, e.Item)
    end
    Touch(player)
    Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    return true, "Bought back " .. tostring(e.Item.Name or "it") .. " for " .. ItemData.FormatNumber(e.Gold) .. " gold."
end

function Buyback.Init(combatServer: any)
    CS = combatServer
    Remotes.GetFunction("Buyback").OnServerInvoke = function(player: Player, action: any, uid: any)
        if action == "List" then return Buyback.List(player) end
        if action == "Buy" then return Buyback.Buy(player, uid) end
        return false, ""
    end
    Players.PlayerRemoving:Connect(function(p)
        lists[p.UserId] = nil
        dirty[p] = nil
        lastBuy[p] = nil
    end)
end

return Buyback
