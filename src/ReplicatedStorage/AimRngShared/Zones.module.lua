-- Zones: where in the world a position is, for the areas outside the walled city (0.55, owner 2026-10-06: "Add trading
-- while I'm gone too, and a trading hub for players" + hideouts).
--   "city"     the hub city (and anything not listed below)
--   "range"    the Training Grounds yard
--   "dungeon"  solo floors / party floors / trials (z > 450)
--   "market"   THE BAZAAR: the shared trading hub, built by the server (HubMarket) west of the city
--   "showcase" (Update 6) the TRY IN FIRST PERSON studio range (TryRange): built on each client for itself only, far
--              west of the Bazaar; InstanceKey "showcase:<userid>" keeps everyone apart there
--   "hideout"  a player's hideout. Every hideout is built at the SAME place by each client from its owner's layout
--              (like the solo floors); InstanceKey keeps players in different hideouts apart.
-- Shared by HubCamera (third person), InstanceKey, the client's hub parking and the server (TradeService, Hideouts).
local Zones = {}

Zones.MARKET_CENTER = Vector3.new(-1600, 4, 0)
Zones.MARKET_HALF = Vector3.new(110, 140, 110)
-- (2026-10-07, owner: "Hideouts should overlook the spawn, right now you just see a big blob in the distance") every
-- hideout floats over the north end of the city's plaza, above the highest cables (y ~72): the balcony looks down on the
-- spawn and the waypoint. The city stays drawn while you're in it (AwayFromCity is false for hideouts).
Zones.HIDEOUT_ORIGIN = Vector3.new(0, 80, -36) -- the apartment floor's centre (top of the floor slab)
Zones.HIDEOUT_HALF = Vector3.new(50, 60, 47)
Zones.HIDEOUT_CENTER = Zones.HIDEOUT_ORIGIN + Vector3.new(12, 0, 1) -- (0.58 bigger hideout: the room + alcove + map room + balcony: local x -38..62, z -46..48)
-- the practice alcove in every hideout (first person + the dummy: HideoutData.SHELL.Range)
Zones.HIDEOUT_RANGE_MIN = Zones.HIDEOUT_ORIGIN + Vector3.new(-34, -12, -38)
Zones.HIDEOUT_RANGE_MAX = Zones.HIDEOUT_ORIGIN + Vector3.new(-14, 60, -14)

local function In(p: Vector3, c: Vector3, h: Vector3): boolean
    local d = p - c
    return math.abs(d.X) < h.X and math.abs(d.Z) < h.Z and d.Y > -40 and d.Y < h.Y
end
-- (the hideout box starts just under its floor: the city below it is never "hideout")
local function InHideoutBox(p: Vector3): boolean
    local d = p - Zones.HIDEOUT_CENTER
    return math.abs(d.X) < Zones.HIDEOUT_HALF.X and math.abs(d.Z) < Zones.HIDEOUT_HALF.Z and d.Y > -12 and d.Y < Zones.HIDEOUT_HALF.Y
end

-- (Update 6) the try-on studio range (TryRange builds it here, on the client, for that player alone)
Zones.SHOWCASE_ORIGIN = Vector3.new(-2600, 300, -1200)
Zones.SHOWCASE_HALF = Vector3.new(60, 40, 60)
-- (Update 6 TUTORIAL) the hands-on tutorial hall (AimRngShared/Tutorial): also client-only, south of the try range. It is
-- a "showcase" too (hub parked, private instance, the bright Showcase light, first person)
Zones.TUTORIAL_ORIGIN = Vector3.new(-2600, 300, -1700)
Zones.TUTORIAL_HALF = Vector3.new(90, 60, 190) -- (2026-10-22 autoplay test: the hall runs ~170 studs from the origin, turned; at 130 the boss
-- stage + exit portal were outside the box -> not "showcase" -> MovementController off there: no dash / slide in the boss step)

-- (0.59) the PvP arenas: built far east of the city (PvpData.SlotOrigin)
Zones.PVP_X = 3000
function Zones.Kind(p: Vector3): string
    if p.X > Zones.PVP_X then return "pvp" end
    if p.Z > 450 then return "dungeon" end
    if In(p, Zones.SHOWCASE_ORIGIN, Zones.SHOWCASE_HALF) then return "showcase" end
    if In(p, Zones.TUTORIAL_ORIGIN, Zones.TUTORIAL_HALF) then return "showcase" end
    if In(p, Zones.MARKET_CENTER, Zones.MARKET_HALF) then return "market" end
    if InHideoutBox(p) then return "hideout" end
    if p.Z > 74 and p.Z < 244 and math.abs(p.X) < 160 then return "range" end
    return "city"
end

function Zones.InMarket(p: Vector3): boolean return Zones.Kind(p) == "market" end
function Zones.InHideout(p: Vector3): boolean return Zones.Kind(p) == "hideout" end
-- the hideout's practice alcove: first person there (the dummy), third person everywhere else in the apartment
function Zones.InHideoutRange(p: Vector3): boolean
    local a, b = Zones.HIDEOUT_RANGE_MIN, Zones.HIDEOUT_RANGE_MAX
    return p.X > a.X and p.X < b.X and p.Z > a.Z and p.Z < b.Z and p.Y < b.Y
end
-- outside the city: the hub (HubWorld) can be parked on this client
function Zones.AwayFromCity(p: Vector3): boolean
    local k = Zones.Kind(p)
    return k == "dungeon" or k == "market" or k == "pvp" or k == "showcase"
end

return Zones
