--!nocheck
-- ============================================================================================
-- INSPECTS (Update 5, owner: "Ensure the inspects on the weapons and melees function properly without clipping,
-- glitches etc ... to have better animations and allow for future custom inspects with skins").
--
-- Every inspect (and a skin's own equip) is DATA: a keyframed animation in the ViewmodelRig format
--   { Length = s, Tracks = { <Channel> = { { t, value, ease? }, ... } }, Events = { { t, name, data? }, ... } }
-- Per weapon CLASS (guns: GUN_CLASS below; melees: MeleeData.ClassAnims), overridable per GUN (Inspects.GUN) and per SKIN
-- (skin.InspectAnim / skin.EquipAnim, or the skin's set: set.GunInspect / set.GunEquip / set.Melee.InspectAnim /
-- set.Melee.EquipAnim), plus timed events on top of any of them (skin.InspectEvents / set.InspectEvents).
-- Full guide for skin authors: docs/INSPECTS.md. Leaf module: requires nothing (WeaponRigs + MeleeData load it).
-- ============================================================================================
local Inspects = {}

local R = math.rad
local V3 = Vector3.new

-- ==================== authoring helpers ====================
-- Inspects.K(t, x, y, z, pitch, yaw, roll, ease): a "Gun" key. Camera space about the right fist's grip point (studs,
-- degrees): +x right, +y up, +z toward you; pitch + = muzzle / tip up, yaw + = muzzle / tip swings LEFT (toward the
-- crosshair), roll + = the top turns left (counter-clockwise on screen). Rotation order: roll, then pitch, then yaw.
-- ease (optional): "InOut" (default) | "Out" | "In" | "Linear" | "Step". Melee rigs run un-eased keys on a smooth spline.
function Inspects.K(t: number, x: number?, y: number?, z: number?, pitch: number?, yaw: number?, roll: number?, ease: string?): any
    return { t, CFrame.new(x or 0, y or 0, z or 0) * CFrame.fromEulerAnglesYXZ(R(pitch or 0), R(yaw or 0), R(roll or 0)), ease }
end
-- a number key (LCradle, ArmFollowR, BladeRoll, your own skin channels ...)
function Inspects.N(t: number, v: number, ease: string?): any
    return { t, v, ease }
end

-- a set builder's helper for MOVING PARTS driven by an animation channel (docs/INSPECTS.md section 4): the part swings about
-- `pivot` round `axis` (both in model / melee / gun space, i.e. where the part is while you build) by angleDeg x st[channel]
-- (0 = as built). E.g. a balisong: blade parts Inspects.Hinge(p, PIN_A, Vector3.zAxis, 180, "BaliBlade"), the bite handle's
-- parts Inspects.Hinge(p, PIN_B, Vector3.zAxis, 180, "BaliB").
function Inspects.Hinge(part: BasePart, pivot: Vector3, axis: Vector3, angleDeg: number, channel: string)
    local rel = part.CFrame:PointToObjectSpace(pivot)
    local sz = part.Size
    part:SetAttribute("SkinDeco", true)
    part:SetAttribute("HingeFrac", Vector3.new(rel.X / sz.X, rel.Y / sz.Y, rel.Z / sz.Z))
    part:SetAttribute("HingeAxis", part.CFrame:VectorToObjectSpace(axis.Unit))
    part:SetAttribute("HingeAngle", angleDeg)
    part:SetAttribute("HingeDrive", channel)
end

-- channels the rig itself understands (anything else in Tracks is a CUSTOM skin channel: sampled every frame and handed to
-- the skin as st[<name>] -- so a part with attribute HingeDrive / ShiftDrive / TurnDrive / GlowDrive / ShowDrive / CountDrive
-- / TintDrive = "<name>" moves / glows with it; see docs/INSPECTS.md)
Inspects.CHANNELS = {
    Gun = "CFrame: the whole weapon, camera space about the grip (Inspects.K)",
    ArmRoll = "degrees: turn the weapon about the forearm (shoulder -> fist) axis",
    GunL = "CFrame (DUAL melees): the left-hand copy, camera space about its own grip (MeleeData KM = the mirror of K)",
    BladeRollL = "degrees (DUAL melees): the left copy turns about its own handle axis",
    BladeRoll = "degrees (melee): turn the weapon about its own handle -> tip axis through the grip",
    LHand = "0..1: the support hand leaves the gun for LFree (0 = on its grip)",
    LFree = "CFrame (gun space): where the support hand goes while LHand > 0",
    LFreeCam = "CFrame (camera space): where the support hand goes while LHand > 0 (wins over LFree)",
    LHandPose = "string: support hand shape (bone arms only)",
    RHandPose = "string: shooting hand shape (bone arms only)",
    LCradle = "0..1 (guns): the support fist rolls round the handguard and stays UNDER it as the gun turns",
    ArmFollowR = "0..1 (guns): the shooting forearm turns with the gun (1 = rigid with it: the rest pose can't clip)",
    ArmFollowL = "0..1 (guns): the support forearm turns with the gun",
    Mag = "CFrame (gun space): magazine offset", MagHand = "0/1: magazine rides the support hand", MagShow = "0/1",
    LFollowMag = "0..1: support hand rides the magazine",
    Slide = "0..1: slide / bolt back", BoltLift = "0..1: bolt handle up (bolt-actions)", RFollowBolt = "0..1: shooting hand on the bolt",
    Pump = "0..1: pump back (the support fist rides it)", Break = "0..1: break-action barrels open", CylSwing = "0..1: revolver cylinder out",
    Trigger = "0..1", ShellHold = "0/1: a round in the support hand",
}

-- ==================== GUN CLASS INSPECTS ====================
-- Our own choreography in the Valorant manner (raise, turn to show the side, tilt to show the top / ejection side,
-- return): every class has the same beats so a skin's VFX can sync to them by NAME (Beats): Present (the side faces
-- you), Tilt (top / ejection side up), Settle (back at the hold). Pistols flip the wrist instead of tilting; LMGs and
-- snipers are heavier and slower. Poses = { t, position, { pitch, yaw, roll }, ease } (Inspects.K terms).
-- The support hand: LCradle keeps it on the handguard as the gun turns (on the side the support arm comes from); rifles,
-- shotguns and snipers let go while the gun is stood on end (LHand: one thick forearm across the screen otherwise) and take
-- it back; LMGs keep both hands on and only roll the top toward you. ArmFollowR turns the shooting forearm with the gun
-- (1 = rigid with it: the clip-free rest pose, so it can never cut through it). Pistols are one-handed for the flip.
local function P(t, x, y, z, p, yw, r, ease) return { t, V3(x, y, z), V3(p, yw, r), ease } end
Inspects.GUN_CLASS = {
    Rifle = {
        Length = 3.2,
        Beats = { Present = 0.62, Tilt = 1.9, Settle = 2.95 },
        Poses = {
            P(0, 0, 0, 0, 0, 0, 0),
            P(0.18, 0.02, -0.03, 0.03, -3, -4, -4),           -- a small dip: the weight shifts before the lift
            P(0.62, -0.22, 0.07, -0.1, 5, 56, -14, "Out"),     -- PRESENT: swung in, the left side broadside to you
            P(1.25, -0.23, 0.09, -0.11, 4, 52, -10),           -- (drift while you look; the support hand lets go)
            P(1.58, -0.18, 0.06, -0.3, 34, -10, -6),           -- (on the way: every step <= ~90 deg)
            P(1.9, -0.08, 0.0, -0.75, 82, -82, 0),             -- TILT: stood on end in the shooting hand, the RIGHT (ejection) side to you
            P(2.4, -0.07, 0.01, -0.74, 80, -79, 0),
            P(2.65, -0.03, 0.01, -0.04, 10, -10, 0),           -- (back near the hold: the support hand takes it again)
            P(2.95, 0, -0.015, 0, -2.5, -2, 2),                -- SETTLE: lands back on the hold with a little give
            P(3.2, 0, 0, 0, 0, 0, 0),
        },
        Tracks = {
            LCradle = { { 0, 0 }, { 0.25, 1 }, { 2.8, 1 }, { 3.1, 0 } },
            ArmFollowR = { { 0, 1 } },
            LHand = { { 0, 0 }, { 1.28, 0 }, { 1.48, 1 }, { 2.62, 1 }, { 2.98, 0 } },
        },
    },
    Shotgun = {
        Length = 3.4,
        Beats = { Present = 0.62, Tilt = 1.9, Rack = 2.82, Settle = 3.15 },
        Poses = {
            P(0, 0, 0, 0, 0, 0, 0),
            P(0.18, 0.02, -0.03, 0.03, -3, -4, -4),
            P(0.62, -0.2, 0.06, -0.1, 4, 50, -12, "Out"),
            P(1.25, -0.21, 0.08, -0.11, 3, 47, -9),
            P(1.58, -0.16, 0.05, -0.3, 32, -8, -6),
            P(1.9, -0.07, 0.0, -0.75, 80, -80, 0),            -- TILT: stood on end, the loading / ejection side to you
            P(2.35, -0.06, 0.01, -0.74, 78, -77, 0),
            P(2.56, -0.03, 0.01, -0.03, 8, -8, 2),
            P(2.82, -0.03, 0.01, -0.02, 3, -4, 4),             -- RACK (pump guns rack the pump here)
            P(3.15, 0, -0.02, 0, -3, -1, 2),
            P(3.4, 0, 0, 0, 0, 0, 0),
        },
        Tracks = {
            LCradle = { { 0, 0 }, { 0.25, 1 }, { 3.05, 1 }, { 3.3, 0 } },
            ArmFollowR = { { 0, 1 } },
            LHand = { { 0, 0 }, { 1.28, 0 }, { 1.48, 1 }, { 2.52, 1 }, { 2.8, 0 } },
        },
    },
    Sniper = { -- heavier: slower in, a weighted settle
        Length = 3.7,
        Beats = { Present = 0.8, Tilt = 2.15, Settle = 3.4 },
        Poses = {
            P(0, 0, 0, 0, 0, 0, 0),
            P(0.24, 0.02, -0.04, 0.04, -3, -3, -3),
            P(0.8, -0.18, 0.05, -0.12, 4, 42, -10, "Out"),
            P(1.5, -0.19, 0.07, -0.13, 3, 39, -7),
            P(1.82, -0.15, 0.04, -0.32, 32, -8, -6),
            P(2.15, -0.08, 0.0, -0.62, 78, -80, 0),            -- TILT: stood on end, the bolt / scope side to you
            P(2.85, -0.07, 0.01, -0.61, 76, -77, 0),
            P(3.08, -0.03, 0.01, -0.04, 9, -9, 0),
            P(3.4, 0, -0.025, 0.01, -3, -1, 2),
            P(3.7, 0, 0, 0, 0, 0, 0),
        },
        Tracks = {
            LCradle = { { 0, 0 }, { 0.3, 1 }, { 3.3, 1 }, { 3.6, 0 } },
            ArmFollowR = { { 0, 1 } },
            LHand = { { 0, 0 }, { 1.52, 0 }, { 1.72, 1 }, { 3.05, 1 }, { 3.42, 0 } },
        },
    },
    LMG = { -- the heaviest: both hands stay on, hefted low, turned less; the top rolled toward you; a slow settle with a dip
        Length = 3.7,
        Beats = { Present = 0.85, Tilt = 2.15, Settle = 3.4 },
        Poses = {
            P(0, 0, 0, 0, 0, 0, 0),
            P(0.26, 0.02, -0.05, 0.04, -4, -3, -3),
            P(0.85, -0.16, 0.03, -0.1, 3, 34, -8, "Out"),
            P(1.55, -0.17, 0.04, -0.11, 2, 32, -6),
            P(2.15, -0.12, 0.06, -0.08, -4, 16, 30),           -- TILT: the feed cover / top rolled toward you
            P(2.85, -0.11, 0.06, -0.08, -4, 15, 28),
            P(3.4, 0, -0.035, 0.01, -3.5, -1, 2),
            P(3.7, 0, 0, 0, 0, 0, 0),
        },
        Tracks = {
            LCradle = { { 0, 0 }, { 0.3, 1 }, { 3.3, 1 }, { 3.6, 0 } },
            ArmFollowR = { { 0, 1 } },
        },
    },
    Pistol = { -- one hand: raise, show the side, FLIP the wrist over (no twirl), back
        Length = 2.5,
        Beats = { Present = 0.5, Flip = 1.5, Settle = 2.3 },
        Poses = {
            P(0, 0, 0, 0, 0, 0, 0),
            P(0.14, 0.01, -0.02, 0.02, -3, -3, -3),
            P(0.5, -0.12, 0.12, -0.04, 8, 46, -16, "Out"),     -- PRESENT: the side to you
            P(1.05, -0.13, 0.13, -0.05, 7, 43, -13),
            P(1.28, -0.12, 0.15, -0.05, 12, 30, 38),           -- (mid-flip: keeps every step under 100 deg)
            P(1.5, -0.1, 0.16, -0.05, 14, 18, 92, "Out"),      -- FLIP: rolled over, the other side up
            P(1.95, -0.1, 0.16, -0.05, 13, 17, 88),
            P(2.3, 0, -0.012, 0, -2.5, -1, 3),
            P(2.5, 0, 0, 0, 0, 0, 0),
        },
        Tracks = {
            ArmFollowR = { { 0, 1 } },
            -- the support hand drops away for the flip and comes back (LFreeCam = Inspects.PISTOL_REST, below the screen)
            LHand = { { 0, 0 }, { 0.3, 1 }, { 2.15, 1 }, { 2.45, 0 } },
        },
    },
}
-- RIVALS class (WeaponRigs.RivalsClass) -> inspect class
Inspects.CLASS_OF = { AR = "Rifle", SMG = "Rifle", SHOTGUN = "Shotgun", SNIPER = "Sniper", LMG = "LMG", PISTOL = "Pistol", HEAVY = "Pistol" }
-- SMGs are lighter: the rifle choreography, quicker
Inspects.TIME_SCALE = { SMG = 0.9 }
-- where a free support hand waits for a one-handed inspect (camera space: below the bottom-left of the screen)
Inspects.PISTOL_REST = CFrame.new(-1.1, -2.1, -0.3) -- (well clear: a stood-up bullpup's stock reaches y -1.75)

-- PER-GUN TUNING (after tools/gun_clipcheck.luau): { Amp = motion scale (1 = class), Shift = Vector3 extra camera-space
-- offset on the held poses, Time = length scale, Class = another class's choreography, Rigid = true (the support hand +
-- forearm stay fixed to the gun like the shooting arm -- for guns whose forearm passes the gun closely at rest), NoRack =
-- true (no pump rack), Anim = a whole anim (or a function (def, id, base) -> anim) }. Only what a gun needs to stay
-- clip-free / on screen goes here.
Inspects.GUN = {
    -- (support forearm / fist within a hair of the gun at rest: the whole hold turns as one piece)
    MP40 = { Rigid = true }, MP5 = { Rigid = true }, VECTOR = { Rigid = true }, VoidDisintegrator = { Rigid = true, Class = "LMG" },
    USAS12 = { Rigid = true, Class = "LMG" }, -- (its box magazine sits under the support hand's way down: the two-hand roll instead)
    KSG = { NoRack = true }, -- (the bullpup's pump racks back into the receiver's front: the fist riding it touched it)
    M40 = { Shift = Vector3.new(0.1, 0.03, 0) }, -- (its long stock swept through the parked support arm on the way back)
    PKM = { Rigid = true }, M60 = { Rigid = true }, HK21 = { Rigid = true }, M249 = { Rigid = true }, -- (Update 6 pass 2 / 3: the support fist cradles
    -- the ammo box -- the hold turns as one piece)
}

-- ==================== building ====================
local function Scaled(pose: any, amp: number, shift: Vector3, w: number, ts: number): any
    local pos, rot = pose[2] * amp + shift * w, pose[3] * amp
    return { pose[1] * ts, CFrame.new(pos) * CFrame.fromEulerAnglesYXZ(R(rot.X), R(rot.Y), R(rot.Z)), pose[4] }
end
local function CopyTrack(keys: any, ts: number): any
    local out = {}
    for i, k in ipairs(keys) do out[i] = { k[1] * ts, k[2], k[3] } end
    return out
end

-- the class inspect for one gun (def = its WeaponRigs entry, id = its gun id)
function Inspects.GunInspect(def: any, id: string?): any
    local o = Inspects.GUN[id or ""] or {}
    local clsKey = o.Class or Inspects.CLASS_OF[def.RivalsClass or ""] or "Rifle"
    local cls = Inspects.GUN_CLASS[clsKey] or Inspects.GUN_CLASS.Rifle
    local amp, shift = o.Amp or 1, o.Shift or Vector3.zero
    local ts = (o.Time or 1) * (Inspects.TIME_SCALE[def.RivalsClass or ""] or 1)
    local gun = {}
    for i, pose in ipairs(cls.Poses) do
        local w = (i == 1 or i == #cls.Poses) and 0 or 1
        gun[i] = Scaled(pose, amp, shift, w, ts)
    end
    local tracks = { Gun = gun }
    for name, keys in pairs(cls.Tracks or {}) do tracks[name] = CopyTrack(keys, ts) end
    if o.Rigid and tracks.ArmFollowR then
        tracks.LCradle = nil
        tracks.ArmFollowL = CopyTrack(tracks.ArmFollowR, 1)
    end
    if o.KeepHand then tracks.LHand = nil end
    if tracks.LHand then tracks.LFreeCam = { { 0, Inspects.PISTOL_REST } } end -- (a hand that lets go waits below the screen)
    local events = {}
    for name, t in pairs(cls.Beats or {}) do table.insert(events, { t * ts, name }) end
    -- pump guns rack the pump on the way back (the support fist rides it; the gun's own pump sounds)
    if clsKey == "Shotgun" and def.PumpTravel and cls.Beats.Rack and not o.NoRack then
        local t0 = cls.Beats.Rack * ts
        tracks.Pump = { { 0, 0 }, { t0 - 0.02, 0 }, { t0 + 0.12, 1, "Out" }, { t0 + 0.17, 1 }, { t0 + 0.3, 0, "In" } }
        table.insert(events, { t0 + 0.02, "PumpBack" })
        table.insert(events, { t0 + 0.26, "PumpForward" })
    end
    table.sort(events, function(a, b) return a[1] < b[1] end)
    local anim = { Length = cls.Length * ts, Tracks = tracks, Events = events, Beats = {}, Class = clsKey }
    for name, t in pairs(cls.Beats or {}) do anim.Beats[name] = t * ts end
    if o.Anim then
        if type(o.Anim) == "function" then anim = o.Anim(def, id, anim) or anim else anim = o.Anim end
    end
    return anim
end

-- ==================== skin overrides ====================
-- Beat-relative times: an event / key time may be a number (seconds) or a string "<Beat>" / "<Beat>+0.2" / "<Beat>-0.1"
-- resolved against the anim's Beats (so a skin can hang its VFX on the class inspect without knowing its timing).
function Inspects.Time(anim: any, t: any): number
    if type(t) == "number" then return t end
    local name, sign, off = string.match(tostring(t), "^(%a+)%s*([%+%-]?)%s*([%d%.]*)$")
    local base = anim and anim.Beats and name and anim.Beats[name]
    if not base then return 0 end
    local d = tonumber(off) or 0
    return base + ((sign == "-") and -d or d)
end

-- merge extra events into a copy of an anim (events = { { time | "Beat+x", name, data? }, ... })
function Inspects.WithEvents(anim: any, events: any): any
    if not (anim and events and #events > 0) then return anim end
    local out = table.clone(anim)
    out.Events = table.clone(anim.Events or {})
    for _, e in ipairs(events) do
        table.insert(out.Events, { math.clamp(Inspects.Time(anim, e[1]), 0, anim.Length or 99), e[2], e[3] })
    end
    table.sort(out.Events, function(a, b) return a[1] < b[1] end)
    return out
end

-- resolve one override field: an anim table, or a function(def, id, base) -> anim
local function Resolve(v: any, def: any, id: string?, base: any): any
    if type(v) == "function" then
        local ok, r = pcall(v, def, id, base)
        if ok then return r end
        warn("[Inspects] skin anim builder failed: " .. tostring(r))
        return nil
    end
    return v
end

-- The rig's per-weapon overrides for a skin: { Inspect = anim?, Equip = anim? } (nil when the skin changes nothing).
-- Order: the skin's own field (skin.InspectAnim / skin.EquipAnim), then its SET (sets = SkinFX.Sets, keyed by skin.FX):
-- set.GunInspect / set.GunEquip for guns (set melees: set.Melee.InspectAnim / EquipAnim are compiled into the set's melee
-- rig by MeleeData.SetRig). skin.InspectEvents / set.InspectEvents add timed events to whichever inspect plays (the class
-- one included).
function Inspects.SkinAnims(def: any, id: string?, skin: any?, sets: any?): any
    if not skin or not def then return nil end
    local set = sets and skin.FX and sets[skin.FX] or nil
    local base = def.Anims or {}
    local out = {}
    for _, name in ipairs({ "Inspect", "Equip" }) do
        local v = skin[name .. "Anim"]
        if v == nil and set then
            if def.IsMelee then v = nil -- (set melees: compiled into the rig by MeleeData.SetRig)
            else v = set["Gun" .. name] end
        end
        local a = v ~= nil and Resolve(v, def, id, base[name]) or nil
        if name == "Inspect" then
            local ev = skin.InspectEvents or (set and not def.IsMelee and set.InspectEvents) or nil
            if ev then a = Inspects.WithEvents(a or base.Inspect, ev) end
        end
        out[name] = a
    end
    if out.Inspect == nil and out.Equip == nil then return nil end
    return out
end

-- ==================== validation (docs/INSPECTS.md "Checklist") ====================
-- Returns a list of human-readable problems ({} = fine). The rig plays anything, but these make clips / pops.
function Inspects.Validate(anim: any, name: string?): { string }
    local out = {}
    local function W(s) table.insert(out, (name or "anim") .. ": " .. s) end
    if type(anim) ~= "table" then W("not a table"); return out end
    local len = anim.Length
    if type(len) ~= "number" or len <= 0 then W("Length missing") len = 0 end
    for ch, keys in pairs(anim.Tracks or {}) do
        local last = -1
        for i, k in ipairs(keys) do
            if type(k[1]) ~= "number" then W(ch .. " key " .. i .. " has no time") end
            if (k[1] or 0) < last then W(ch .. " keys out of order at " .. i) end
            last = k[1] or last
            if typeof(k[2]) == "CFrame" and keys[i - 1] and typeof(keys[i - 1][2]) == "CFrame" then
                local _, ang = (keys[i - 1][2].Rotation:Inverse() * k[2].Rotation):ToAxisAngle()
                if math.deg(math.abs(ang)) > 100 then W(string.format("%s step %d turns %.0f deg (a CFrame lerp takes the short way round: split it, <= 100)", ch, i, math.deg(math.abs(ang)))) end
            end
        end
        if #keys > 0 and len > 0 and (keys[#keys][1] or 0) > len + 1e-3 then W(ch .. " has keys past Length") end
        if ch == "Gun" and #keys > 0 then
            local e = keys[#keys][2]
            if typeof(e) == "CFrame" then
                local _, a = e.Rotation:ToAxisAngle()
                if e.Position.Magnitude > 0.01 or math.deg(math.abs(a)) > 1 then W("Gun does not end at the hold (last key must be CFrame.identity)") end
            end
        end
        if not Inspects.CHANNELS[ch] then W("note: custom channel '" .. ch .. "' (handed to the skin as st." .. ch .. ")") end
    end
    for i, e in ipairs(anim.Events or {}) do
        if type(e[1]) ~= "number" then W("event " .. i .. " has no time")
        elseif len > 0 and e[1] > len then W("event " .. i .. " (" .. tostring(e[2]) .. ") is after the end") end
    end
    return out
end

return Inspects
