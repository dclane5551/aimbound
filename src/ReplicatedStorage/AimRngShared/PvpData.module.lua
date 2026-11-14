--!nocheck
-- PvpData (0.59, owner: "ADD PVP ... like quake live lightning gun duel: shooting a player has a vampiric effect, so the
-- better player always wins. directly take from quake live lg duels with the calculations. Weapons available will only be
-- auto weapons, but the firerate and dps will always be standardized (this is to incentivize cosmetics while keeping pvp
-- balanced). Create a couple of pvp only arenas ... (a bit bigger than current maps). ... gear wagering ... an option both
-- players agree to").
-- Shared numbers + the PvP-only arenas. The server (PvpService) builds an arena per duel and runs every rule; the client
-- (PvpClient) draws the duel HUD and fires the standardized gun.
--
-- THE DUEL NUMBERS (the lightning gun duel, scaled to our studs):
--   * One weapon for everyone: 120 damage a second at 100% accuracy (the LG's 6 damage x 20 hits a second), delivered as
--     12 shots a second x 10 damage (a beam's 20 / s of tiny hits reads as noise with gun sounds). No spread, no recoil,
--     no reload, no crits. (0.77: HEADSHOTS deal HEADSHOT_MULT -- the rest of the body counts the same.) Range 80 studs (the LG's 768 units, at
--     our ~9.6 units a stud); past it the shot does nothing.
--   * (0.77) You start with HEALTH, no armour (ARMOR = 0 keeps the old armour rule switched off).
--   * VAMPIRIC: that share of the damage you deal comes back to you as health, up to MAX_HEALTH. Two players trading at the
--     same accuracy both bleed out slowly; the better aim gains every exchange.
--   * First to FRAGS_TO_WIN frags. After TIME_LIMIT the leader wins; a tie goes to sudden death (next frag wins).
--   * Respawn RESPAWN seconds after a frag, at the spawn farthest from the killer, with SPAWN_SHIELD seconds of no damage
--     (gone the moment you fire).
-- Your build, gear, tree, class and gun stats do nothing in a duel: only your aim and movement. The gun you hold (any
-- automatic: an AR, LMG, SMG or the beam) is just its look, sound and skin.
local PvpData = {}

PvpData.FIRE_RATE = 12 -- (the default gun's pace: an AR)
PvpData.DAMAGE = 10
-- (0.60, owner: "players should be able to SELECT a weapon, not have to have it equipped, change it so every weapon can be
-- selected, but the DPS for any given guns would be EXACTLY the same, scaled with firerate and damage"): every gun in the
-- lineup can be picked; it keeps its own fire rate (and pellets), and its damage per shot = DPS / fire rate, so every gun
-- deals exactly DPS at perfect aim. A shotgun splits a shot's damage across its pellets.
PvpData.DPS = 120
-- (0.60, owner: "hit reg and range is a little bit wonky"): 80 studs cut long shots off silently -- the range now covers
-- the whole arena
PvpData.RANGE = 400
-- QUAKE LIVE HEALTH (0.63, owner: "make the vamp and movement feel JUST like quake live lg duels ... I dont think the
-- fights last long enough"): you spawn with HEALTH (125, Quake's spawn health); the vampiric heal can take you past 100
-- up to MAX_HEALTH (200, Quake's cap), and anything over BASE_HEALTH ticks back down DECAY a second (Quake's 1 hp/s
-- countdown). A good streak banks a real lead; the fight lasts longer and swings.
-- (0.77, owner: "remove the armor and just make the health cap 300, because you cant heal the armor and it doesnt make
-- sense"): no armour; you spawn with 200 health (about what 125 health + 100 armour soaked) and the vampiric heal takes
-- you up to 300, ticking back down to 200.
PvpData.HEALTH = 200
PvpData.BASE_HEALTH = 200
PvpData.MAX_HEALTH = 300
PvpData.DECAY = 1
PvpData.ARMOR = 0
-- (0.77, owner: "slight increase movement speed"): duel run speed x this (the client reads the PvpMoveMult attribute)
PvpData.MOVE_MULT = 1 -- (2026-10-15 DUEL PACE: was 1.12; owner "a bit slower")
PvpData.ARMOR_TAKES = 2 / 3
-- (0.77, owner: "The vamp needs to be a good bit stronger too, you dont heal enough in the duels when hitting your shots")
PvpData.VAMPIRIC = 0.8
-- (0.77, owner: "Headshots should also deal 20% more damage"): a pellet that hits the head deals x1.2 (the server checks
-- the hit really is at head height of where the target was)
PvpData.HEADSHOT_MULT = 1.2
PvpData.HEAD_MIN_Y = 0.85 * 0.8 -- (an R6 head spans the root +0.9 .. +2.1 at full size; x BODY_SCALE 0.8 -- set again below)
PvpData.FRAGS_TO_WIN = 5
PvpData.TIME_LIMIT = 300
PvpData.RESPAWN = 1.8
PvpData.SPAWN_SHIELD = 1.2
PvpData.COUNTDOWN = 4
PvpData.WAGER_MAX = 4 -- items per side
-- STANDARD BODIES (0.60, owner: "models should also be standardized so hitbox cant be abused"): in a duel every
-- character is stripped to the plain R6 body (accessories, packages and body meshes are stored and given back after), and
-- shots test exactly those six limbs: what you see is what you hit. The server checks a hit within REACH of where the
-- body's centre was (an R6 body spans head top +2 .. feet -3 from the root, arms +-2).
-- DUELS v3 (2026-10-14, owner: "pvp ... feels kind of boring ... The models are big, you can jump spam, and its overall bland"):
--   * BODY_SCALE: every duelist (and the bot) is drawn at this size -- a smaller target that takes real tracking; the
--     server's hit checks below scale with it.
--   * JUMP_GAP: a jump at most every this many seconds (the client's movement; no more hold-Space hopping), and shots fired
--     in the air spread by AIR_SPREAD (PvpClient) -- jumping is a choice, not the default.
--   * Dash (1 charge, DASH_RECHARGE s) and slide are back in duels (MovementController T.Quake).
--   * PICKUPS: OFF (owner, same day: "There should not be any health packs"): every mode has Pickups = false; the code stays.
--   * MODES: Classic / Gun Rotation / Instagib (PvpData.MODES).
PvpData.BODY_SCALE = 0.8
PvpData.JUMP_GAP = 0.9
PvpData.AIR_SPREAD = 0.06

-- ===== ABILITIES (2026-10-15, owner: "add some more depth somehow, maybe abilities" -> "One ability each") =====
-- Each duelist picks ONE before the duel (the DUEL window; PvpAction "SetAbility", kept for the next duels too) and uses it
-- with Key_Ability (F) / the touch SKILL button / DPad down, on its own cooldown (server checked; player attrs PvpAbility +
-- PvpAbilityReady = server time it's usable again). Nothing here deals damage: they're movement / defence / information.
--   BLINK  you jump BLINK_DIST studs the way you're moving (or looking), stopped short of walls (client move, server allows it)
--   GUARD  GUARD_TIME s taking GUARD_CUT less damage (attr PvpGuardUntil; your opponent sees a shield on you)
--   PULSE  PULSE_TIME s of seeing your opponent through walls (attr PvpPulseUntil; only you see it)
PvpData.ABILITIES = {
    { Id = "Blink", Name = "BLINK", Cooldown = 8, Icon = "dash",
      Desc = "Blink 12 studs the way you're moving. Dodge a duel you're losing or close in on a hurt opponent." },
    { Id = "Guard", Name = "GUARD", Cooldown = 14, Icon = "shield",
      Desc = "Take 60% less damage for 1.5 seconds. Win a trade you'd lose, then keep tracking." },
    { Id = "Pulse", Name = "PULSE", Cooldown = 14, Icon = "eye",
      Desc = "See your opponent through walls for 3 seconds. Know where they'll peek before they do." },
}
PvpData.BLINK_DIST, PvpData.GUARD_TIME, PvpData.GUARD_CUT, PvpData.PULSE_TIME = 12, 1.5, 0.6, 3
PvpData.AbilityById = {}
for _, ab in ipairs(PvpData.ABILITIES) do PvpData.AbilityById[ab.Id] = ab end
function PvpData.AbilityOf(id: any): any return PvpData.AbilityById[id or ""] or PvpData.ABILITIES[1] end
PvpData.REACH = 4.2 * PvpData.BODY_SCALE
PvpData.BODY_Y = -0.5 * PvpData.BODY_SCALE -- (the body's middle under the root)
PvpData.HITBOX = Vector3.new(4, 5, 1) -- (the R6 body's outline, for the record)
PvpData.HITBOX_Y = -0.5

-- the guns you can pick (every lineup gun) and one gun's duel numbers: { Id, Name, Class, Rate, PerShot, Pellets, Spread }
function PvpData.GunChoices(): { string }
    local ItemData = require(script.Parent:WaitForChild("ItemData"))
    local out = {}
    for _, id in ipairs(ItemData.Lineup or {}) do if ItemData.BaseWeapons[id] then table.insert(out, id) end end
    return out
end
function PvpData.GunStats(id: string?): any
    local ItemData = require(script.Parent:WaitForChild("ItemData"))
    local def = id and ItemData.BaseWeapons[id]
    if not def then def = ItemData.BaseWeapons.AK47; id = "AK47" end
    local rate = math.clamp(tonumber(def.BaseFireRate) or PvpData.FIRE_RATE, 0.5, 20)
    local pellets = (def.Class == "Shotgun") and math.max(1, def.PelletCount or 8) or 1
    return { Id = id, Name = def.ShortName or def.Name or id, Class = def.Class, Rate = rate, PerShot = PvpData.DPS / rate,
        Pellets = pellets, Spread = (pellets > 1) and 0.07 or 0 }
end
-- (0.77, owner: "Duels need to have the same weapon, have each player be able to challenge to either: random weapon duel,
-- or a specific gun duel. The player being requested can either accept the duel or offer a counterpick for the gun, where
-- it will then be 50/50ed"): both duelists use ONE gun -- the challenger's pick ("Random" = rolled at the start), or a
-- coin flip between it and the other player's counterpick.
function PvpData.RandomGun(): string
    local list = PvpData.GunChoices()
    return list[math.random(1, #list)] or "AK47"
end
function PvpData.GunLabel(id: string?): string
    if id == nil or id == "Random" then return "RANDOM GUN" end
    return string.upper(PvpData.GunStats(id).Name)
end
-- (kept for old callers: any gun can be picked now)
function PvpData.IsAuto(w: any): boolean return type(w) == "table" end
PvpData.HEAD_MIN_Y = 0.85 * PvpData.BODY_SCALE

-- ===== MODES (DUELS v3) =====
--   CLASSIC   the lightning-gun duel above, first to 5, pickups on.
--   ROTATION  first to 4 (best of 7): after EVERY frag both duelists get a new gun of a different class.
--   INSTAGIB  one-shot rails (INSTAGIB_GUN, INSTAGIB_RATE shots a second), first to 10, no pickups, no healing.
PvpData.INSTAGIB_GUN = "AWP"
PvpData.INSTAGIB_RATE = 1.1
-- (2026-10-15, owner: "Lets remove the other 2 modes, and just keep classic"): only CLASSIC is offered; the Rotation /
-- Instagib entries are kept in OLD_MODES (their code paths stay) -- move one back into MODES to bring it back.
PvpData.MODES = {
    { Id = "Classic", Name = "CLASSIC", FragsToWin = 5, Pickups = false,
      Desc = "The same gun for both, hits heal you. First to 5." },
}
PvpData.OLD_MODES = {
    { Id = "Rotation", Name = "GUN ROTATION", FragsToWin = 4, Pickups = false, Rotate = true,
      Desc = "A new gun of a different class after every frag. First to 4 (best of 7): be good with everything." },
    { Id = "Instagib", Name = "INSTAGIB", FragsToWin = 10, Pickups = false, Instagib = true,
      Desc = "One hit kills, about one shot a second, no healing. Pure flick aim. First to 10." },
}
PvpData.ModeById = {}
for _, m in ipairs(PvpData.MODES) do PvpData.ModeById[m.Id] = m end
function PvpData.ModeOf(id: any): any return PvpData.ModeById[id or ""] or PvpData.MODES[1] end
-- a gun's duel numbers in a mode (Instagib: every gun is a one-shot rail at its own pace)
function PvpData.GunStatsFor(mode: any, id: string?): any
    local m = PvpData.ModeOf(mode)
    if m.Instagib then
        local g = PvpData.GunStats(id or PvpData.INSTAGIB_GUN)
        return { Id = g.Id, Name = g.Name, Class = g.Class, Rate = PvpData.INSTAGIB_RATE, PerShot = 100000, Pellets = 1, Spread = 0, Instagib = true }
    end
    return PvpData.GunStats(id)
end
-- GUN ROTATION: a random gun whose class differs from `prev`'s
function PvpData.RotationGun(prev: string?): string
    local ItemData = require(script.Parent:WaitForChild("ItemData"))
    local pc = prev and ItemData.BaseWeapons[prev] and ItemData.BaseWeapons[prev].Class
    local list = {}
    for _, id in ipairs(PvpData.GunChoices()) do
        local c = ItemData.BaseWeapons[id] and ItemData.BaseWeapons[id].Class
        if c ~= pc then table.insert(list, id) end
    end
    return list[math.random(1, math.max(1, #list))] or PvpData.RandomGun()
end
-- HEALTH PICKUPS: at points of the arena (fractions of its size from the centre), dropped onto the floor by the server
PvpData.PICKUPS = {
    { Kind = "Mega", At = Vector2.new(0, 0), Heal = 100, Respawn = 35 },
    { Kind = "Small", At = Vector2.new(0.32, 0.18), Heal = 35, Respawn = 18 },
    { Kind = "Small", At = Vector2.new(-0.32, -0.18), Heal = 35, Respawn = 18 },
}
PvpData.PICKUP_RADIUS = 4

-- the shot rule, shared so the client's numbers match: (health, armour, damage) -> health, armour, dealt
function PvpData.ApplyHit(hp: number, armor: number, dmg: number): (number, number, number)
    local toArmor = math.min(armor, dmg * PvpData.ARMOR_TAKES)
    local toHealth = dmg - toArmor
    local newHp = math.max(0, hp - toHealth)
    return newHp, armor - toArmor, (hp - newHp) + toArmor
end

-- ===== THE ARENAS (PvP only) =====
-- Each: Id, Name, Desc, Build(folder, origin) -> { spawns = { CFrame }, size }. Built by the server at a free slot far
-- east of the city (Zones "pvp"), torn down after the duel. Budget like a dungeon floor: < ~350 parts, few lights, no
-- shadows. Everything solid is in the folder "Geo" (the client's shots only test Geo + the opponent's hitbox).
local V, CF, C = Vector3.new, CFrame.new, Color3.fromRGB
local M = Enum.Material
local function R(d) return math.rad(d) end

local function Maker(folder: Instance, O: Vector3)
    local geo = Instance.new("Folder"); geo.Name = "Geo"; geo.Parent = folder
    local deco = Instance.new("Folder"); deco.Name = "Deco"; deco.Parent = folder
    local function P(cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material, o: any?): BasePart
        o = o or {}
        local p
        if o.Wedge then p = Instance.new("WedgePart") else p = Instance.new("Part") end
        if o.Shape then p.Shape = o.Shape end
        p.Anchored = true
        p.CFrame = CF(O) * cf
        p.Size = size
        p.Color = color
        p.Material = mat
        p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
        p.CastShadow = false
        if o.T then p.Transparency = o.T end
        if o.Deco then
            p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
            p.Parent = deco
        else
            p.CanTouch = false
            p.Parent = geo
        end
        return p
    end
    local function Light(p: BasePart, color: Color3, range: number, bright: number)
        local l = Instance.new("PointLight"); l.Color = color; l.Range = range; l.Brightness = bright; l.Shadows = false; l.Parent = p
    end
    -- invisible walls + a lid so nobody leaves the arena
    local function Bounds(w: number, d: number, h: number)
        for _, s in ipairs({ { V(0, h / 2, d / 2 + 1), V(w + 4, h, 2) }, { V(0, h / 2, -d / 2 - 1), V(w + 4, h, 2) },
            { V(w / 2 + 1, h / 2, 0), V(2, h, d + 4) }, { V(-w / 2 - 1, h / 2, 0), V(2, h, d + 4) }, { V(0, h + 1, 0), V(w + 4, 2, d + 4) } }) do
            local b = P(CF(s[1]), s[2], C(0, 0, 0), M.SmoothPlastic, { T = 1 })
            b.CanQuery = false -- (shots fly out into the sky; players still can't)
        end
    end
    return P, Light, Bounds
end

-- (0.77, owner: "The arenas are still not good, they look pretty horrible"): ARENAS v2. The same collision layout and spawns
-- as 0.63 (the fights stay the same), dressed properly: real materials, trims, signs, props, a skyline with depth. Still
-- inside the budget (~250 parts each, <= 6 lights, no shadows, cheap particles only).
local function VCyl(cf: CFrame): CFrame return cf * CFrame.Angles(0, 0, math.pi / 2) end -- (a cylinder standing up)
local function Sign(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?)
    local g = Instance.new("SurfaceGui")
    g.Face = face; g.LightInfluence = 0; g.Brightness = 2; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 24
    g.Parent = part
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.Text = text; t.TextScaled = true
    t.Font = font or Enum.Font.GothamBlack; t.TextColor3 = color
    t.Parent = g
    local s = Instance.new("UIStroke"); s.Color = Color3.new(0, 0, 0); s.Thickness = 2; s.Transparency = 0.4; s.Parent = t
end

-- a backdrop tower (no collisions, no queries): glass or concrete, lit floor bands, a set-back crown with a neon edge,
-- sometimes an antenna
local function Tower(P, cf: CFrame, w: number, h: number, d: number, neon: Color3, k: number)
    local glass = k % 2 == 0
    local body = glass and C(44, 56, 84) or C(86, 78, 86)
    P(cf * CF(0, h / 2, 0), V(w, h, d), body, glass and M.Glass or M.Concrete, { Deco = true })
    -- lit floors facing the arena (warm and cool offices, some dark)
    local warm, cool = C(255, 200, 130), C(150, 210, 255)
    local n = math.floor((h - 44) / 7)
    for f = 1, math.max(0, n) do
        if (f + k) % 3 ~= 0 then
            local lit = ((f * 7 + k * 3) % 5 == 0) and cool or warm
            P(cf * CF(((f + k) % 2 == 0) and -w * 0.12 or w * 0.12, 40 + f * 7, -d / 2 - 0.05), V(w * (0.45 + ((f * k) % 3) * 0.12), 1.6, 0.1), lit, M.Neon, { Deco = true, T = 0.45 })
        end
    end
    -- crown: a set-back top and a neon edge round the roof line
    P(cf * CF(0, h + 0.2, 0), V(w + 0.6, 0.4, d + 0.6), neon, M.Neon, { Deco = true })
    P(cf * CF(0, h + 3, 0), V(w * 0.62, 6, d * 0.62), glass and C(30, 36, 52) or C(64, 58, 66), M.Concrete, { Deco = true })
    P(cf * CF(w / 2 + 0.05, h / 2, -d / 2 + 0.05), V(0.3, h, 0.3), neon, M.Neon, { Deco = true })
    if k % 3 == 0 then
        P(cf * CF(0, h + 11, 0), V(0.5, 10, 0.5), C(120, 120, 130), M.Metal, { Deco = true })
        P(cf * CF(0, h + 16.2, 0), V(0.8, 0.8, 0.8), C(255, 40, 40), M.Neon, { Deco = true, Shape = Enum.PartType.Ball })
    end
end

PvpData.ARENAS = {
    {
        -- ARENAS v3 (2026-10-14, owner: "it allows people to head glitch, play height, and play cover way too much"): ONE
        -- flat level. Every solid is FULL height (a stair tower, an elevator shaft, four columns: you can't see over them or
        -- stand on them) or not solid at all; the helipad is paint on the roof. Lines of sight break, nobody gets a head-only
        -- peek or a high ground. (Before: a raised helipad with lips, two 8-up stair huts, planters, AC stacks + crates.)
        Id = "Rooftops", Name = "NEON ROOFTOPS",
        Desc = "A flat rooftop over the walled city at dusk: a painted helipad in the middle, two stair towers and four columns to break line of sight. No high ground, no head glitches.",
        -- health packs: point-symmetric, so neither side's spawn is closer (PvpService reads Pickups when an arena has it)
        Pickups = { { Kind = "Mega", At = Vector2.new(0, 0) }, { Kind = "Small", At = Vector2.new(0.32, -0.18) }, { Kind = "Small", At = Vector2.new(-0.32, 0.18) } },
        Build = function(folder: Instance, O: Vector3)
            local P, Light, Bounds = Maker(folder, O)
            local W, D = 100, 100
            local ROOF, SEAM, PARA, CAP = C(60, 62, 70), C(46, 48, 54), C(170, 158, 150), C(116, 118, 128)
            local BRICK, TRIM, STEEL, DARK = C(146, 82, 64), C(200, 190, 180), C(124, 128, 138), C(34, 36, 42)
            local PINK, CYAN, GOLD, WARM = C(255, 70, 170), C(70, 220, 255), C(255, 196, 70), C(255, 210, 150)
            local HEDGE, SOIL = C(78, 128, 62), C(70, 52, 40)
            -- the roof: tar with panel seams and a few puddles that catch the sky
            P(CF(0, -1, 0), V(W, 2, D), ROOF, M.Asphalt)
            for k = -4, 4 do
                P(CF(k * 10, 0.01, 0), V(0.25, 0.04, D - 4), SEAM, M.SmoothPlastic, { Deco = true })
                if k ~= 0 then P(CF(0, 0.01, k * 10), V(W - 4, 0.04, 0.25), SEAM, M.SmoothPlastic, { Deco = true }) end
            end
            for _, s in ipairs({ { -18, 30, 7, 4 }, { 20, -14, 5, 6 }, { -40, -8, 4, 3 }, { 12, 40, 6, 3 } }) do
                P(CF(s[1], 0.03, s[2]), V(s[3], 0.05, s[4]), C(70, 84, 120), M.Glass, { Deco = true, T = 0.3 })
            end
            -- painted lines (the old court lines, softer)
            for _, z in ipairs({ -26, 26 }) do P(CF(0, 0.04, z), V(W - 12, 0.05, 0.4), GOLD, M.SmoothPlastic, { Deco = true, T = 0.45 }) end
            for _, x in ipairs({ -26, 26 }) do P(CF(x, 0.04, 0), V(0.4, 0.05, D - 12), GOLD, M.SmoothPlastic, { Deco = true, T = 0.45 }) end
            -- PARAPETS (chest high): concrete, a metal coping, an LED strip along the foot
            for i, s in ipairs({ { V(0, 1.75, D / 2 - 1), V(W, 3.5, 2), -1 }, { V(0, 1.75, -D / 2 + 1), V(W, 3.5, 2), 1 },
                { V(W / 2 - 1, 1.75, 0), V(2, 3.5, D), -1 }, { V(-W / 2 + 1, 1.75, 0), V(2, 3.5, D), 1 } }) do
                P(CF(s[1]), s[2], PARA, M.Concrete)
                P(CF(s[1] + V(0, 1.85, 0)), V(s[2].X + 0.5, 0.25, s[2].Z + 0.5), CAP, M.Metal)
                local along = s[2].X > s[2].Z
                local off = along and V(0, -1.45, s[3] * 1.02) or V(s[3] * 1.02, -1.45, 0)
                P(CF(s[1] + off), along and V(W - 4, 0.18, 0.08) or V(0.08, 0.18, D - 4), (i <= 2) and PINK or CYAN, M.Neon, { Deco = true })
            end
            -- THE HELIPAD: paint on the roof only (a gold ring, the H, landing lights flush with the tar)
            P(VCyl(CF(0, 0.05, 0)), V(0.04, 15, 15), GOLD, M.SmoothPlastic, { Shape = Enum.PartType.Cylinder, Deco = true })
            P(VCyl(CF(0, 0.07, 0)), V(0.04, 14, 14), C(66, 68, 76), M.Asphalt, { Shape = Enum.PartType.Cylinder, Deco = true })
            for _, s in ipairs({ { V(-2.4, 0.09, 0), V(1, 0.04, 6.5) }, { V(2.4, 0.09, 0), V(1, 0.04, 6.5) }, { V(0, 0.09, 0), V(3.8, 0.04, 1) } }) do
                P(CF(s[1]), s[2], C(235, 235, 240), M.SmoothPlastic, { Deco = true })
            end
            for _, a in ipairs({ 0, 90, 180, 270 }) do
                P(CF(0, 0.08, 0) * CFrame.Angles(0, R(a + 45), 0) * CF(0, 0, 9), V(0.7, 0.06, 0.7), WARM, M.Neon, { Deco = true })
            end
            -- TWO STAIR TOWERS (full height: 18 up, no ramps, nothing on top you can reach) in opposite corners
            local function Tower2(x: number, z: number, i: number, c: { number })
                P(CF(x, 9, z), V(12, 18, 12), BRICK, M.Brick)
                for _, y in ipairs({ 6, 12 }) do P(CF(x, y, z), V(12.4, 0.5, 12.4), TRIM, M.Concrete, { Deco = true }) end
                P(CF(x, 18.2, z), V(12.6, 0.4, 12.6), CAP, M.Metal, { Deco = true })
                -- the door + exit sign on the court side
                P(CF(x, 3.6, z - c[2] * 6.05), V(4.6, 7.2, 0.08), TRIM, M.Concrete, { Deco = true })
                P(CF(x, 3.3, z - c[2] * 6.12), V(4, 6.6, 0.12), DARK, M.Metal, { Deco = true })
                P(CF(x, 6.95, z - c[2] * 6.12), V(1.6, 0.4, 0.1), C(80, 255, 140), M.Neon, { Deco = true })
                -- a neon BLADE SIGN on the outer corner
                local sx, sz = x + c[1] * 6.4, z - c[2] * 4
                P(CF(sx, 11, sz), V(0.5, 9, 3.4), DARK, M.Metal, { Deco = true })
                local neon = (i == 1) and PINK or CYAN
                local blade = P(CF(sx, 11, sz), V(0.6, 8.2, 2.6), neon, M.Neon, { Deco = true, T = 0.1 })
                Sign(blade, Enum.NormalId.Right, (i == 1) and "R\nA\nM\nE\nN" or "A\nR\nC\nA\nD\nE", C(255, 255, 255))
                Sign(blade, Enum.NormalId.Left, (i == 1) and "R\nA\nM\nE\nN" or "A\nR\nC\nA\nD\nE", C(255, 255, 255))
                Light(blade, neon, 26, 1.1)
                -- up top (out of reach, deco only): a water tank on one, an antenna on the other
                if i == 1 then
                    P(VCyl(CF(x, 21.5, z)), V(5, 5, 5), C(126, 88, 60), M.WoodPlanks, { Shape = Enum.PartType.Cylinder, Deco = true })
                    for _, o in ipairs({ { -1.6, -1.6 }, { 1.6, 1.6 } }) do P(CF(x + o[1], 19.2, z + o[2]), V(0.4, 1.6, 0.4), DARK, M.Metal, { Deco = true }) end
                else
                    P(CF(x, 24, z), V(0.45, 12, 0.45), C(150, 150, 160), M.Metal, { Deco = true })
                    P(CF(x, 30.2, z), V(0.8, 0.8, 0.8), C(255, 40, 40), M.Neon, { Deco = true, Shape = Enum.PartType.Ball })
                end
            end
            Tower2(-32, -32, 1, { -1, -1 })
            Tower2(32, 32, 2, { 1, 1 })
            -- FOUR COLUMNS round the helipad (full height: concrete, a steel band, an LED strip up one face)
            for i, c in ipairs({ { 18, 0 }, { -18, 0 }, { 0, 18 }, { 0, -18 } }) do
                P(CF(c[1], 9, c[2]), V(3.6, 18, 3.6), PARA, M.Concrete)
                P(CF(c[1], 2, c[2]), V(3.9, 0.6, 3.9), CAP, M.Metal, { Deco = true })
                P(CF(c[1], 17.6, c[2]), V(3.9, 0.6, 3.9), CAP, M.Metal, { Deco = true })
                local face = (c[1] ~= 0) and V(-math.sign(c[1]) * 1.82, 9, 0) or V(0, 9, -math.sign(c[2]) * 1.82)
                P(CF(V(c[1], 0, c[2]) + face), (c[1] ~= 0) and V(0.08, 14, 0.5) or V(0.5, 14, 0.08), (i % 2 == 0) and PINK or CYAN, M.Neon, { Deco = true })
            end
            -- the other two corners: an ELEVATOR SHAFT (full height) with an AC unit bolted high on its wall (out of reach)
            for _, c in ipairs({ { 1, -1 }, { -1, 1 } }) do
                local x, z = c[1] * 38, c[2] * 38
                P(CF(x, 9, z), V(9, 18, 9), C(150, 140, 136), M.Concrete)
                P(CF(x, 18.2, z), V(9.6, 0.4, 9.6), CAP, M.Metal, { Deco = true })
                P(CF(x - c[1] * 4.6, 12, z), V(0.6, 4, 6), C(178, 180, 188), M.Metal, { Deco = true })
                for _, o in ipairs({ -1.5, 1.5 }) do
                    P(CF(x - c[1] * 4.95, 12, z + o) * CFrame.Angles(0, 0, R(90)), V(0.1, 2.4, 2.4), DARK, M.Metal, { Shape = Enum.PartType.Cylinder, Deco = true })
                end
            end
            -- BILLBOARDS just past the parapets (backdrop)
            do
                local bz = D / 2 + 8
                for _, x in ipairs({ -10, 10 }) do P(CF(x, 2, bz), V(0.8, 22, 0.8), DARK, M.Metal, { Deco = true }) end
                local board = P(CF(0, 17, bz), V(34, 11, 0.6), C(20, 20, 30), M.SmoothPlastic, { Deco = true })
                Sign(board, Enum.NormalId.Front, "AIMBOUND", C(255, 120, 200))
                for _, s in ipairs({ { V(0, 22.6, bz - 0.35), V(35, 0.4, 0.2) }, { V(0, 11.4, bz - 0.35), V(35, 0.4, 0.2) }, { V(-17.4, 17, bz - 0.35), V(0.4, 11.6, 0.2) }, { V(17.4, 17, bz - 0.35), V(0.4, 11.6, 0.2) } }) do
                    P(CF(s[1]), s[2], PINK, M.Neon, { Deco = true })
                end
                Light(board, PINK, 40, 0.7)
                local bx = -W / 2 - 8
                P(CF(bx, 2, 0), V(0.8, 18, 0.8), DARK, M.Metal, { Deco = true })
                local b2 = P(CF(bx, 14, 0) * CFrame.Angles(0, -math.pi / 2, 0), V(20, 8, 0.6), C(20, 24, 34), M.SmoothPlastic, { Deco = true })
                Sign(b2, Enum.NormalId.Front, "1 V 1", C(110, 230, 255))
                for _, s in ipairs({ { V(0, 4.2, -0.35), V(21, 0.35, 0.2) }, { V(0, -4.2, -0.35), V(21, 0.35, 0.2) } }) do
                    P(CF(bx, 14, 0) * CFrame.Angles(0, -math.pi / 2, 0) * CF(s[1]), s[2], CYAN, M.Neon, { Deco = true })
                end
            end
            -- THE CITY around it: a near ring of towers + far silhouettes the haze swallows
            for k = 0, 11 do
                local ang = k / 12 * math.pi * 2 + 0.13
                local r = 96 + (k % 3) * 20
                local h = 66 + ((k * 37) % 40)
                Tower(P, CF(math.cos(ang) * r, -40, math.sin(ang) * r) * CFrame.Angles(0, -ang + math.pi / 2, 0), 26 + (k % 4) * 4, h, 22, (k % 2 == 0) and PINK or CYAN, k)
            end
            for k = 0, 7 do
                local ang = k / 8 * math.pi * 2 + 0.4
                local r = 230
                P(CF(math.cos(ang) * r, 10 + (k % 3) * 14, math.sin(ang) * r) * CFrame.Angles(0, -ang, 0), V(60, 100 + (k % 3) * 28, 40), C(52, 42, 62), M.Concrete, { Deco = true })
            end
            local mid = P(CF(0, 16, 0), V(1, 1, 1), GOLD, M.Neon, { Deco = true, T = 1 })
            Light(mid, C(255, 200, 150), 50, 0.8)
            Bounds(W, D, 40)
            local spawns = {}
            for _, s in ipairs({ { -44, 3, 22 }, { 44, 3, -22 }, { 22, 3, -44 }, { -22, 3, 44 }, { 0, 3, -40 }, { 0, 3, 40 }, { -40, 3, 0 }, { 40, 3, 0 } }) do
                local p = O + V(s[1], s[2], s[3])
                table.insert(spawns, CFrame.lookAt(p, Vector3.new(O.X, p.Y, O.Z)))
            end
            return { spawns = spawns, size = V(W, 40, D) }
        end,
    },
    {
        -- (0.63: 104 x 92) the steel works, packed tight: the furnace in the middle, a catwalk ring 7 up with two ramps and
        -- two bridges to the furnace collar, four containers. (0.77 v2: open roof trusses under the dusk sky, an overhead
        -- crane pouring a ladle, pipes, ribbed containers, hanging lamps, embers + chimney smoke.)
        -- ARENAS v3 (2026-10-14, owner: head glitches / height / cover): ONE flat floor. The catwalk ring, its ramps and
        -- bridges, the container stack + ramp, the barrel clusters and the mould are gone; the furnace runs floor to roof and the
        -- four containers are taller than a duelist can see over or jump onto. Everything solid is full height.
        Id = "Foundry", Name = "THE FOUNDRY",
        Desc = "A steel works on one flat floor: the glowing furnace in the middle and four containers to break line of sight. No catwalks, no high ground, no head glitches.",
        Pickups = { { Kind = "Small", At = Vector2.new(0.25, 0) }, { Kind = "Small", At = Vector2.new(-0.25, 0) },
            { Kind = "Small", At = Vector2.new(0, 0.35) }, { Kind = "Small", At = Vector2.new(0, -0.35) } },
        Build = function(folder: Instance, O: Vector3)
            local P, Light, Bounds = Maker(folder, O)
            local W, D = 104, 92
            local FLOOR, STEEL, RUST, DARK = C(84, 80, 76), C(104, 108, 116), C(132, 74, 48), C(38, 38, 44)
            local WALLC, BEAM, YEL = C(84, 88, 98), C(48, 50, 58), C(226, 176, 44)
            local LAVA, SODIUM = C(255, 110, 30), C(255, 176, 90)
            -- floor: concrete with a steel plate walkway round the furnace and painted bay lines
            P(CF(0, -1, 0), V(W, 2, D), FLOOR, M.Concrete)
            P(CF(0, 0.02, 0), V(30, 0.05, 30), C(70, 72, 78), M.DiamondPlate, { Deco = true })
            for _, s in ipairs({ { V(0, 0.06, 15.2), V(30.8, 0.04, 0.4) }, { V(0, 0.06, -15.2), V(30.8, 0.04, 0.4) }, { V(15.2, 0.06, 0), V(0.4, 0.04, 30.8) }, { V(-15.2, 0.06, 0), V(0.4, 0.04, 30.8) } }) do
                P(CF(s[1]), s[2], YEL, M.SmoothPlastic, { Deco = true })
            end
            for _, x in ipairs({ -26, 26 }) do P(CF(x, 0.03, 0), V(0.4, 0.04, D - 8), C(220, 220, 220), M.SmoothPlastic, { Deco = true, T = 0.4 }) end
            -- WALLS: corrugated steel with columns, a girder round the top and a band of sunset windows
            for _, s in ipairs({ { V(0, 11, D / 2), V(W, 22, 2) }, { V(0, 11, -D / 2), V(W, 22, 2) }, { V(W / 2, 11, 0), V(2, 22, D) }, { V(-W / 2, 11, 0), V(2, 22, D) } }) do
                P(CF(s[1]), s[2], WALLC, M.Metal)
                P(CF(s[1] + V(0, 10.6, 0)), s[2] * V(1, 0, 1) + V(1, 1.2, 1), BEAM, M.Metal, { Deco = true })
            end
            for k = -2, 2 do
                for _, z in ipairs({ -D / 2 + 1.5, D / 2 - 1.5 }) do P(CF(k * 24, 11, z), V(2, 22, 1.5), BEAM, M.Metal, { Deco = true }) end
            end
            for _, z in ipairs({ -15, 15 }) do
                for _, x in ipairs({ -W / 2 + 1.5, W / 2 - 1.5 }) do P(CF(x, 11, z), V(1.5, 22, 2), BEAM, M.Metal, { Deco = true }) end
            end
            for _, z in ipairs({ -D / 2 + 1.05, D / 2 - 1.05 }) do
                for k = -2, 1 do
                    P(CF(k * 24 + 12, 16.5, z), V(18, 3.4, 0.1), C(255, 150, 90), M.Neon, { Deco = true, T = 0.55 })
                end
            end
            -- ROOF TRUSSES (open to the sky; the invisible lid is far above)
            for k = -3, 3 do
                P(CF(k * 15, 22.6, 0), V(1.2, 1.2, D + 2), BEAM, M.Metal, { Deco = true })
            end
            for _, z in ipairs({ -30, 30 }) do P(CF(0, 21.4, z), V(W + 2, 0.8, 0.8), BEAM, M.Metal, { Deco = true }) end
            -- PIPES along the long walls (deco: they hug the walls), with flanges
            for i, z in ipairs({ -D / 2 + 3, D / 2 - 3 }) do
                local col = (i == 1) and C(150, 72, 46) or C(66, 96, 126)
                for _, y in ipairs({ 4, 5.8 }) do
                    P(CF(0, y, z), V(W - 6, 1.3, 1.3), col, M.Metal, { Shape = Enum.PartType.Cylinder, Deco = true })
                end
                for k = -2, 2 do
                    P(CF(k * 20 + 6, 4.9, z), V(0.4, 3.6, 1.8), DARK, M.Metal, { Deco = true })
                end
            end
            -- THE FURNACE: floor to roof (no plinth to stand on), the riveted body with steel bands, two grated mouths, a chimney
            P(CF(0, 11, 0) * CFrame.Angles(0, 0, R(90)), V(22, 12, 12), RUST, M.CorrodedMetal, { Shape = Enum.PartType.Cylinder })
            P(CF(0, 0.05, 0), V(16, 0.1, 16), C(70, 66, 64), M.Concrete, { Deco = true })
            for _, y in ipairs({ 1.6, 9.4, 18.8 }) do
                P(VCyl(CF(0, y, 0)), V(0.8, 12.8, 12.8), DARK, M.Metal, { Shape = Enum.PartType.Cylinder, Deco = true })
            end
            P(VCyl(CF(0, 4.4, 0)), V(0.5, 12.4, 12.4), LAVA, M.Neon, { Shape = Enum.PartType.Cylinder, Deco = true, T = 0.2 })
            local mouth
            for _, s in ipairs({ 1, -1 }) do
                local m = P(CF(0, 2.8, s * 6.05), V(4.4, 3.2, 0.3), LAVA, M.Neon, { Deco = true })
                for _, x in ipairs({ -1.3, 0, 1.3 }) do P(CF(x, 2.8, s * 6.25), V(0.3, 3.2, 0.2), DARK, M.Metal, { Deco = true }) end
                P(CF(0, 4.6, s * 6.25), V(5.2, 0.5, 0.4), DARK, M.Metal, { Deco = true })
                mouth = mouth or m
            end
            Light(mouth, LAVA, 34, 1.3)
            do -- embers out of the mouth
                local e = Instance.new("ParticleEmitter")
                e.Color = ColorSequence.new(C(255, 200, 90), C(255, 80, 20)); e.LightEmission = 1
                e.Size = NumberSequence.new(0.18, 0.05); e.Rate = 10; e.Lifetime = NumberRange.new(1.2, 2.2)
                e.Speed = NumberRange.new(3, 6); e.SpreadAngle = Vector2.new(35, 35); e.Acceleration = V(0, 3, 0)
                e.EmissionDirection = Enum.NormalId.Back -- (out of the +z mouth)
                e.Parent = mouth
            end
            P(VCyl(CF(0, 27, 0)), V(14, 5, 5), C(80, 74, 72), M.CorrodedMetal, { Shape = Enum.PartType.Cylinder, Deco = true })
            local chimTop = P(VCyl(CF(0, 34.2, 0)), V(0.6, 5.6, 5.6), DARK, M.Metal, { Shape = Enum.PartType.Cylinder, Deco = true })
            do
                local e = Instance.new("ParticleEmitter")
                e.Color = ColorSequence.new(C(70, 64, 66)); e.LightEmission = 0
                e.Size = NumberSequence.new(3, 9); e.Transparency = NumberSequence.new(0.55, 1)
                e.Rate = 2.5; e.Lifetime = NumberRange.new(5, 7); e.Speed = NumberRange.new(2, 4)
                e.SpreadAngle = Vector2.new(12, 12); e.Acceleration = V(1, 0.6, 0); e.Rotation = NumberRange.new(0, 360)
                e.EmissionDirection = Enum.NormalId.Right -- (the part is turned: its +X points up)
                e.Parent = chimTop
            end
            -- THE CRANE (deco, up in the trusses): rails, a yellow bridge, a trolley, a ladle pouring into a floor mould (paint)
            for _, z in ipairs({ -30, 30 }) do P(CF(0, 20.4, z), V(W - 4, 1, 1), DARK, M.Metal, { Deco = true }) end
            P(CF(-26, 19.6, 0), V(3, 2, 62), YEL, M.Metal, { Deco = true })
            P(CF(-26, 18.2, 6), V(4, 1.4, 4), DARK, M.Metal, { Deco = true })
            for _, x in ipairs({ -27, -25 }) do P(CF(x, 15.4, 6), V(0.15, 4.4, 0.15), C(30, 30, 30), M.Metal, { Deco = true }) end
            local ladle = CF(-26, 13.6, 6) * CFrame.Angles(R(18), 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
            P(ladle, V(4, 4.6, 4.6), C(70, 64, 62), M.Metal, { Shape = Enum.PartType.Cylinder, Deco = true })
            P(ladle * CF(1.97, 0, 0), V(0.1, 4, 4), LAVA, M.Neon, { Shape = Enum.PartType.Cylinder, Deco = true })
            local pour = P(VCyl(CF(-26, 6.6, 7.4)), V(12, 0.5, 0.5), C(255, 150, 50), M.Neon, { Shape = Enum.PartType.Cylinder, Deco = true })
            P(CF(-26, 0.06, 7.4), V(4, 0.1, 4), LAVA, M.Neon, { Deco = true })
            Light(pour, LAVA, 22, 1)
            -- FOUR CONTAINERS, 10 tall (a duelist can't see over one or jump onto it): ribbed sides, door bars, a stencil
            local CONT = { C(160, 56, 44), C(44, 96, 148), C(62, 126, 74), C(178, 126, 44) }
            for i, c in ipairs({ { 40, 0, 0, 0 }, { -40, 0, 0, 0 }, { 14, 0, 36, 90 }, { -14, 0, -36, 90 } }) do
                local cf = CF(c[1], 5, c[3]) * CFrame.Angles(0, R(c[4]), 0)
                local col = CONT[(i - 1) % 4 + 1]
                local box = P(cf, V(8, 10, 16), col, M.Metal)
                for _, sx in ipairs({ -4.06, 4.06 }) do
                    for _, rz in ipairs({ -4.5, 0, 4.5 }) do P(cf * CF(sx, 0, rz), V(0.12, 9.2, 0.5), col:Lerp(C(0, 0, 0), 0.25), M.Metal, { Deco = true }) end
                end
                for _, bx in ipairs({ -1.6, 1.6 }) do P(cf * CF(bx, 0, 8.06), V(0.2, 9.4, 0.12), C(40, 40, 44), M.Metal, { Deco = true }) end
                Sign(box, Enum.NormalId.Right, "AIM-0" .. i, C(235, 235, 235), Enum.Font.Code)
            end
            -- molten channels under grates (light + colour, never damage)
            for _, x in ipairs({ -31, 31 }) do
                local ch = P(CF(x, 0.03, 0), V(4, 0.06, 60), LAVA, M.Neon, { Deco = true, T = 0.15 })
                P(CF(x, 0.15, 0), V(4.4, 0.2, 60), DARK, M.DiamondPlate, { Deco = true, T = 0.45 })
                if x < 0 then Light(ch, LAVA, 20, 0.9) end
            end
            -- HANGING LAMPS (sodium) from the trusses
            for i, s in ipairs({ { -30, D / 2 - 14 }, { 30, -D / 2 + 14 }, { 30, D / 2 - 14 }, { -30, -D / 2 + 14 } }) do
                P(CF(s[1], 20, s[2]), V(0.12, 4.6, 0.12), C(30, 30, 30), M.Metal, { Deco = true })
                P(VCyl(CF(s[1], 17.4, s[2])), V(0.8, 2.6, 2.6), DARK, M.Metal, { Shape = Enum.PartType.Cylinder, Deco = true })
                local bulb = P(VCyl(CF(s[1], 16.95, s[2])), V(0.12, 2.1, 2.1), SODIUM, M.Neon, { Shape = Enum.PartType.Cylinder, Deco = true })
                if i <= 2 then Light(bulb, SODIUM, 44, 1) end
            end
            Bounds(W, D, 40)
            local spawns = {}
            for _, s in ipairs({ { -46, 3, -38 }, { 46, 3, 38 }, { 46, 3, -38 }, { -46, 3, 38 }, { 0, 3, -40 }, { 0, 3, 40 } }) do
                local p = O + V(s[1], s[2], s[3])
                table.insert(spawns, CFrame.lookAt(p, Vector3.new(O.X, p.Y, O.Z)))
            end
            return { spawns = spawns, size = V(W, 40, D) }
        end,
    },
}
PvpData.ArenaById = {}
for _, a in ipairs(PvpData.ARENAS) do PvpData.ArenaById[a.Id] = a end

-- where duel slot n is built (far east of the city: Zones "pvp")
PvpData.SLOT_X0, PvpData.SLOT_GAP = 4000, 700
function PvpData.SlotOrigin(n: number): Vector3
    return Vector3.new(PvpData.SLOT_X0 + n * PvpData.SLOT_GAP, 20, 0)
end

return PvpData
