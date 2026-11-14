--!nocheck
-- ============================================================================================
-- SHARED SPOILS (UPDATE 7 B4, the vault's "Seals / party cracking" renamed in Loot Economy Plan section 11; placeholder): from
-- level UNLOCK, SEALS (material SpoilsSeal) drop from elites and bosses. When a PARTY brings down a boss, every member there
-- carrying a seal breaks one: each seal adds PER_SEAL items to one pooled chest, and everyone who broke a seal picks ONE item
-- from the whole pool (first come first served, PICK_TIME seconds; whoever hasn't picked then gets a random one left).
-- A reason to party up: four seals = eight items to choose from. Solo runs never use seals.
-- Server: PartyRuns (a party boss floor cleared) -> SharedSpoils.Open(members, cfg); remote SpoilsAction ("Pick", sid, i);
-- event Spoils(session) to the pickers. Client: AimRngShared/SpoilsMenu.
-- ============================================================================================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Remotes = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Remotes"))
local ItemData = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ItemData"))

local SharedSpoils = {}
SharedSpoils.ON = true
SharedSpoils.UNLOCK = 80
SharedSpoils.PER_SEAL = 2
SharedSpoils.PICK_TIME = 40
SharedSpoils.SEAL_CHANCE = { Elite = 0.015, Boss = 0.12 } -- (CombatServer kill rewards, from UNLOCK)
SharedSpoils.STUDIO_SOLO = true -- (Studio: a one-player party may break seals, for testing)

local CombatServer
local sessions = {}

local function View(s: any): any
    local items = {}
    for i, e in ipairs(s.Items) do
        items[i] = { Item = e.Item, Kind = e.Kind, From = e.From, TakenBy = e.TakenBy }
    end
    local pickers = {}
    for _, p in ipairs(s.Pickers) do table.insert(pickers, { Name = p.DisplayName, UserId = p.UserId, Picked = s.Picked[p] ~= nil }) end
    return { Id = s.Id, Items = items, Pickers = pickers, EndsAt = s.EndsAt }
end
local function Push(s: any)
    local v = View(s)
    for _, p in ipairs(s.Pickers) do if p.Parent then Remotes.GetEvent("Spoils"):FireClient(p, v) end end
end

local function Give(s: any, p: Player, i: number)
    local e = s.Items[i]
    e.TakenBy = p.DisplayName
    s.Picked[p] = i
    local st = CombatServer.GetState(p)
    if st then CombatServer.DropGiven(p, st, e.Item, e.Kind) end
end

-- a party boss is down: members with a seal break it; returns the session id or nil
function SharedSpoils.Open(members: { Player }, cfg: any): string?
    if not SharedSpoils.ON or not CombatServer then return nil end
    local isStudio = game:GetService("RunService"):IsStudio()
    if #members < 2 and not (isStudio and SharedSpoils.STUDIO_SOLO) then return nil end
    local pickers, minLevel = {}, math.huge
    for _, p in ipairs(members) do
        local st = CombatServer.GetState(p)
        if st and (st.Level or 1) >= SharedSpoils.UNLOCK and ((st.Materials or {}).SpoilsSeal or 0) >= 1 then
            st.Materials.SpoilsSeal -= 1
            table.insert(pickers, p)
            pcall(CombatServer.SeasonGoalEvent, p, st, "Spoils", 1)
            minLevel = math.min(minLevel, st.Level or 1)
            Remotes.GetEvent("SyncPlayerState"):FireClient(p, st)
        end
    end
    if #pickers == 0 then return nil end
    -- the pool: PER_SEAL items per seal, one step under the floor's top rarity, at the lowest picker's level (everyone can use them)
    -- (UPDATE 8 RARITY v4: always Rare -- the workhorse; was one step under the top of the old 15-step ladder)
    local rarity = "Rare"
    local items = {}
    for _, p in ipairs(pickers) do
        for _ = 1, SharedSpoils.PER_SEAL do
            local item, kind
            if math.random() < 0.6 then
                item, kind = ItemData.GenerateRandomWeapon(rarity, nil, minLevel, true), "Weapon"
            else
                item, kind = ItemData.GenerateRandomGear(nil, rarity, nil, minLevel, true), "Gear"
            end
            if item then table.insert(items, { Item = item, Kind = kind, From = p.DisplayName }) end
        end
    end
    local s = { Id = HttpService:GenerateGUID(false), Items = items, Pickers = pickers, Picked = {}, EndsAt = workspace:GetServerTimeNow() + SharedSpoils.PICK_TIME }
    sessions[s.Id] = s
    SharedSpoils.Last = s.Id -- (Studio tests: DevCmd "spoils")
    for _, p in ipairs(pickers) do
        Remotes.GetEvent("CombatFx"):FireClient(p, "Text", "SPLIT THE HAUL: " .. #pickers .. " tag" .. (#pickers == 1 and "" or "s") .. " broken, " .. #items .. " items to choose from!", Color3.fromRGB(255, 205, 110))
    end
    Push(s)
    task.delay(SharedSpoils.PICK_TIME + 0.5, function()
        if sessions[s.Id] ~= s then return end
        for _, p in ipairs(s.Pickers) do
            if p.Parent and not s.Picked[p] then
                local left = {}
                for i, e in ipairs(s.Items) do if not e.TakenBy then table.insert(left, i) end end
                if #left > 0 then Give(s, p, left[math.random(1, #left)]) end
            end
        end
        Push(s)
        sessions[s.Id] = nil
    end)
    return s.Id
end

function SharedSpoils.Pick(player: Player, sid: any, i: any): (boolean, string?)
    local s = sessions[tostring(sid)]
    if not s then return false, "That haul is gone." end
    if not table.find(s.Pickers, player) then return false, "You didn't spend a Haul Tag." end
    if s.Picked[player] then return false, "You've picked already." end
    local idx = tonumber(i)
    local e = idx and s.Items[idx]
    if not e then return false, "?" end
    if e.TakenBy then return false, e.TakenBy .. " took that one." end
    Give(s, player, idx)
    Push(s)
    return true, "Yours: " .. tostring(e.Item.Name)
end

function SharedSpoils.Init(combat: any)
    CombatServer = combat
    Remotes.GetFunction("SpoilsAction").OnServerInvoke = function(player: Player, action: any, sid: any, i: any)
        if action == "Pick" then return SharedSpoils.Pick(player, sid, i) end
        return false, "?"
    end
end

return SharedSpoils
