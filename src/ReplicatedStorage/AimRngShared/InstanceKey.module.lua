-- InstanceKey: which "instance" a player is in. Players only see / hear each other inside the same instance (owner
-- 2026-10-05: "Make lobbies entirely separate ... it should all be single instances, even within parties").
--   "hub"            the hub (the walled city since 0.38; shared: the social space)
--   "range:<userid>" your own Training Grounds (other people's range shooting stays out of yours)
--   "solo:<userid>"  your solo dungeon / Boss Trial / Aim Trial (every solo floor is built at the same coordinates)
--   "market"         the Bazaar (the trading hub, shared like the city; Zones)
--   "hideout:<owner>" the hideout of that player's user id (every hideout is built at the same place on each client;
--                    attribute HideoutOf = whose hideout you're in, set by the server's Hideouts module)
--   "showcase:<userid>" (Update 6) the TRY IN FIRST PERSON studio range (Zones "showcase"): every client builds its own
--                    copy at the same place, so nobody sees anybody there
--   "watch:<key>"    (0.62 SPECTATE) someone in the hub watching a player: they see that player's instance <key>;
--                    nobody sees them (their body stays parked in the hub)
--   "run:<runId>"    one floor of a party run (each floor has its own RunId, so a teammate who went on through the
--                    portal is in a different instance until you follow)
-- Used by DungeonClient (hides other instances' characters, effects and sounds) and CombatServer (ShotFx relay).
local InstanceKey = {}
local Zones = require(script.Parent:WaitForChild("Zones"))

local RANGE_Z0, RANGE_Z1, RANGE_X = 74, 244, 160 -- (HubGenerator.RANGE: the yard south of the gatehouse)
local DUNGEON_Z = 450

function InstanceKey.Of(player: Player, pos: Vector3?): string
    local w = player:GetAttribute("WatchUid") -- (0.62 SPECTATE)
    if w then
        local t = game:GetService("Players"):GetPlayerByUserId(w)
        if t and t ~= player and not t:GetAttribute("WatchUid") then return "watch:" .. InstanceKey.Of(t) end
    end
    local duel = player:GetAttribute("PvpDuel") -- (0.59: "pvp:<duel id>" -- the two duelists see only each other)
    if duel then return "pvp:" .. tostring(duel) end
    local rid = player:GetAttribute("RunId")
    if rid then return "run:" .. tostring(rid) end
    if not pos then
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        pos = root and (root :: BasePart).Position
    end
    if not pos then return "hub" end
    if pos.Z > DUNGEON_Z then return "solo:" .. player.UserId end
    local kind = Zones.Kind(pos)
    if kind == "market" then return "market" end
    if kind == "showcase" then return "showcase:" .. player.UserId end
    if kind == "hideout" then return "hideout:" .. tostring(player:GetAttribute("HideoutOf") or player.UserId) end
    if pos.Z > RANGE_Z0 and pos.Z < RANGE_Z1 and math.abs(pos.X) < RANGE_X then return "range:" .. player.UserId end
    return "hub"
end

-- (0.58, owner: "while players in the hub shouldn't see players or the hideouts that are up there, the hideout should
-- be able to see players in the hub"): one-way -- someone in a hideout ALSO sees the hub's players (the loft looks down
-- on the plaza; a themed hideout parks the city, so not there: lookingAtCity = false). Nobody in the hub sees hideouts.
function InstanceKey.Sees(viewerKey: string, otherKey: string, lookingAtCity: boolean?): boolean
    if viewerKey == otherKey then return true end
    if string.sub(viewerKey, 1, 6) == "watch:" then return string.sub(viewerKey, 7) == otherKey end -- (0.62 SPECTATE)
    return lookingAtCity ~= false and otherKey == "hub" and string.sub(viewerKey, 1, 8) == "hideout:"
end

function InstanceKey.Same(a: Player, b: Player): boolean
    return InstanceKey.Of(a) == InstanceKey.Of(b)
end

return InstanceKey
