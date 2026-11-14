--!nocheck
-- GLOVES + SLEEVES v2 (owner, 2026-10-02: "the gloves feel incredibly low effort, nobody would buy this -- gloves need
-- their own unique appeal"). Every premium glove is a small hand-built model with its own signature:
--   * a textured base (CosmeticArt seamless textures on the hand block, some scrolling: data flowing, stars drifting)
--   * a VAMBRACE (forearm guard) -- in first person the gun covers the top of the hand, so the art lives on the wrist
--     and forearm where you can actually see it
--   * moving parts: flapping wings, orbiting shards, spinning rings / gears, clock hands, pistons, a lagging ghost
--   * light: lightning / energy beams, an arc between both hands, holo displays, pulsing / heat-driven glow
--   * events: Fire (each shot), Kill, Inspect -> particle bursts, shock effects (nova / implosion / eruption), wings
--     flaring, sigils + light rays on inspect, heat building up while you keep firing
-- One renderer for both views: first person (ViewmodelRig dresses the block hand / arm) and third person (the
-- server puts plain shells on every character's hands / arms with LookKind / LookId attributes; each CLIENT dresses
-- them -- GloveFX.StartWorld -- so the moving parts stay smooth and cost no replication).
--
-- Unit space of an owner (hand or arm block): X = width, Y = up (back of the hand), Z = length (-Z = fingertips).
-- A part: Off = fraction of the owner's size (per axis), OffW = extra offset in units of the owner's width w,
-- Size = fractions per axis, or (Uniform = true) units of w (round things stay round on a short hand block).
-- Seat = true: the Off point stays ON the owner's surface in first person too (the glove fit, d.Fit < 1, scales only OffW
-- and the size) -- a rigid piece that must sit on a face (a watch on the back of the hand) instead of sinking into the
-- block in first person or floating over the arm in third person.
local GloveFX = {}

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Art = require(script.Parent:WaitForChild("CosmeticArt"))

local C = Color3.fromRGB
local V = Vector3.new
local V2 = Vector2.new
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local FEATHER = Art.Feather
local NEON, METAL, FABRIC, GLASS, SMOOTH = Enum.Material.Neon, Enum.Material.Metal, Enum.Material.Fabric, Enum.Material.Glass, Enum.Material.SmoothPlastic

local GOLD, PALEGOLD, PEARL = C(255, 200, 80), C(255, 236, 170), C(212, 208, 199) -- (brighter whites blow out under warm light + bloom)
local GOLDMETAL = C(214, 166, 72)

-- ==================== catalog helpers ====================
local function Join(...)
    local out = {}
    for _, l in ipairs({ ... }) do for _, x in ipairs(l) do table.insert(out, x) end end
    return out
end
-- a point on the vambrace: x / y in -1..1 of its half width (surface at +-1), z 0..1 along its length
local function At(t, x, y, z, len)
    t.Off = V(0, 0, 0.5)
    t.OffW = V(x * 0.57, y * 0.57, z * (len or 1))
    return t
end
local function Vamb(len, props)
    local t = { Size = V(1.14, 1.14, len), Uniform = true, Off = V(0, 0, 0.5), OffW = V(0, 0, len / 2), Name = "Vambrace" }
    for k, v in pairs(props) do t[k] = v end
    return t
end
-- end bands of the vambrace
local function Bands(len, color, mat, glowColor)
    local out = {
        At({ Size = V(1.2, 1.2, 0.09), Uniform = true, Color = color, Material = mat or METAL, Reflectance = 0.3 }, 0, 0, 0.05, len),
        At({ Size = V(1.2, 1.2, 0.09), Uniform = true, Color = color, Material = mat or METAL, Reflectance = 0.3 }, 0, 0, 0.95, len),
    }
    if glowColor then
        table.insert(out, At({ Size = V(1.22, 1.22, 0.03), Uniform = true, Color = glowColor, Glow = true, Anim = "Pulse", PulseMin = 0, PulseMax = 0.55 }, 0, 0, 0.15, len))
    end
    return out
end
-- a four-point star lying on a face: axis "Y" (top face) or "X" (side face)
local function Star(t, size, axis, color)
    local function S(sz, rot, col, tr)
        local p = table.clone(t)
        p.Size, p.Uniform, p.Color, p.Glow, p.Rot = sz, true, col, true, rot
        p.Anim, p.PulseMin, p.PulseMax, p.Speed = "Pulse", 0, tr or 0.35, 3.2
        return p
    end
    if axis == "X" then
        return { S(V(0.03, size, 0.07), V(0, 0, 0), color or GOLD), S(V(0.03, 0.07, size * 0.62), V(0, 0, 0), color or GOLD),
                 S(V(0.035, size * 0.26, size * 0.26), V(45, 0, 0), C(255, 255, 245), 0.2) }
    end
    return { S(V(0.07, 0.03, size), V(0, 0, 0), color or GOLD), S(V(size * 0.62, 0.03, 0.07), V(0, 0, 0), color or GOLD),
             S(V(size * 0.26, 0.035, size * 0.26), V(0, 45, 0), C(255, 255, 245), 0.2) }
end
-- a wing of n feathers on side s (+1 / -1) of the vambrace, fanning back + up; flaps, flares on kills, opens on inspect
local function Wing(s, o)
    local out = {}
    local len = o.VL or 1
    for i = 1, (o.N or 3) do
        local L = (o.Len or 0.95) * (1 - (i - 1) * 0.15)
        local H = (o.H or 0.28) * (1 - (i - 1) * 0.12)
        local base = { Wedge = true, WedgeFlip = true, Root = 1, Uniform = true, Size = V(0.035, H, L), Side = s,
            Color = o.Color or PEARL, Material = o.Material or SMOOTH, Reflectance = o.Refl or 0.08,
            Rot = V(-(12 + i * 12), s * (14 + i * 9), 0), Anim = "Flap", Amp = o.Amp or 8, Speed = o.Speed or 2.2, Phase = i * 0.55,
            FlareOn = "Kill", OpenOn = "Inspect", OpenAng = o.OpenAng or 32, OpenFor = 1.8 }
        At(base, s * 1.02, 0.2 + (i - 1) * 0.2, o.Z or 0.14, len)
        table.insert(out, base)
        local edge = table.clone(base)
        edge.Wedge, edge.WedgeFlip = nil, nil
        edge.Size = V(0.045, 0.028, L * 0.98)
        edge.ShiftW = V(0, -H / 2 + 0.014, 0)
        edge.Color, edge.Material, edge.Reflectance = o.Edge or GOLD, METAL, 0.32
        if o.EdgeGlow then edge.Glow = true; edge.Color = o.EdgeGlow end
        table.insert(out, edge)
    end
    return out
end

-- ===== OUTFIT KIT (2026-10-07, owner: "a lot of them literally look like baby outfits, especially the sleeves ... the
-- sleeves and gloves look not great and rather low effort"). A tailored combat-idol look for the kawaii line instead of
-- a pastel tube with a pattern: a DEEP base, the set's MAIN colour on shaped armour, polished TRIM metal and one GLOW
-- piping colour; the set's identity lives in a small crisp EMBLEM, not in a print all over the cloth.
-- pal = { Dark, Dark2 (lighter dark: cuff turn-back, strap), Main, Main2 (darker main: back panel), Trim, Glow,
--         Emblem = function(off, offW, s) -> parts,
--         MainMat (default SmoothPlastic; Metal for gold / chrome armour), VambLen (glove cuff length, default 0.42; the
--         older sets use 1.0 = a full gauntlet so their forearm pieces (K.At(..., L)) sit on it),
--         NoKnuckle / NoBack / NoTips (the set brings its own knuckle / back-of-hand / fingertip pieces) }
-- (Fabric renders as a dark speckle on light colours: a pale cuff (Seraphim pearl) read charcoal -> smooth there)
local function ClothMat(c: Color3): Enum.Material return (c.R + c.G + c.B) / 3 > 0.45 and SMOOTH or FABRIC end
local function Shade(c: Color3, k: number): Color3 return C(math.clamp(c.R * 255 * k, 0, 255), math.clamp(c.G * 255 * k, 0, 255), math.clamp(c.B * 255 * k, 0, 255)) end
local OE = {} -- emblems, lying flat on a top face at off / offW, s = size in units of w; -Z (away from the eye) = "up"
function OE.Heart(off, offW, s, col, glow)
    local o = {}
    for _, sx in ipairs({ -1, 1 }) do
        table.insert(o, { Shape = "Ball", Uniform = true, Size = V(s * 0.55, s * 0.4, s * 0.55), Off = off, OffW = offW + V(sx * s * 0.2, 0, -s * 0.1), Color = col, Glow = glow, Material = (not glow) and SMOOTH or nil, Reflectance = 0.2,
            Anim = glow and "Pulse" or nil, PulseMin = 0.05, PulseMax = 0.35, Speed = 2.4 })
    end
    table.insert(o, { Uniform = true, Size = V(s * 0.56, s * 0.3, s * 0.56), Off = off, OffW = offW + V(0, 0, s * 0.12), Rot = V(0, 45, 0), Color = col, Glow = glow, Material = (not glow) and SMOOTH or nil, Reflectance = 0.2,
        Anim = glow and "Pulse" or nil, PulseMin = 0.05, PulseMax = 0.35, Speed = 2.4 })
    return o
end
function OE.Star(off, offW, s, col, glow)
    return {
        { Uniform = true, Size = V(s * 0.22, s * 0.25, s), Off = off, OffW = offW, Rot = V(0, 0, 0), Color = col, Glow = glow, Material = (not glow) and METAL or nil, Reflectance = 0.3, Anim = glow and "Pulse" or nil, PulseMin = 0, PulseMax = 0.35, Speed = 3 },
        { Uniform = true, Size = V(s * 0.7, s * 0.25, s * 0.22), Off = off, OffW = offW, Color = col, Glow = glow, Material = (not glow) and METAL or nil, Reflectance = 0.3, Anim = glow and "Pulse" or nil, PulseMin = 0, PulseMax = 0.35, Speed = 3 },
        { Uniform = true, Size = V(s * 0.3, s * 0.3, s * 0.3), Off = off, OffW = offW, Rot = V(0, 45, 0), Color = col, Glow = glow, Material = (not glow) and METAL or nil, Reflectance = 0.3 },
    }
end
function OE.Diamond(off, offW, s, col, glow)
    return { { Uniform = true, Size = V(s * 0.62, s * 0.3, s * 0.62), Off = off, OffW = offW, Rot = V(0, 45, 0), Color = col, Glow = glow, Material = (not glow) and SMOOTH or nil, Reflectance = 0.25,
        Anim = glow and "Pulse" or nil, PulseMin = 0.05, PulseMax = 0.35, Speed = 2 } }
end
function OE.Flower(off, offW, s, col, glow, center)
    local o = {}
    for k = 0, 4 do
        local a = k / 5 * math.pi * 2
        table.insert(o, { Shape = "Ball", Uniform = true, Size = V(s * 0.38, s * 0.22, s * 0.38), Off = off, OffW = offW + V(math.sin(a) * s * 0.26, 0, -math.cos(a) * s * 0.26), Color = col, Material = SMOOTH, Reflectance = 0.15 })
    end
    table.insert(o, { Shape = "Ball", Uniform = true, Size = V(s * 0.26, s * 0.28, s * 0.26), Off = off, OffW = offW + V(0, s * 0.04, 0), Color = center or col, Glow = glow, Material = (not glow) and SMOOTH or nil,
        Anim = glow and "Pulse" or nil, PulseMin = 0.05, PulseMax = 0.35, Speed = 2 })
    return o
end
function OE.Moon(off, offW, s, col, glow)
    local o = {}
    for k = 0, 6 do -- a crescent: an arc of small blocks, thick in the middle
        local a = math.rad(-110 + k * 36.6)
        local t = 1 - math.abs(k - 3) / 4.5
        table.insert(o, { Uniform = true, Size = V(s * 0.16 * (0.6 + t), s * 0.22, s * 0.2), Off = off, OffW = offW + V(math.cos(a) * s * 0.36 - s * 0.08, 0, math.sin(a) * s * 0.36), Rot = V(0, -math.deg(a), 0),
            Color = col, Glow = glow, Material = (not glow) and METAL or nil, Reflectance = 0.3, Anim = glow and "Pulse" or nil, PulseMin = 0.05, PulseMax = 0.35, Speed = 1.6 })
    end
    return o
end
function OE.Hex(off, offW, s, col, glow, center)
    local o = {}
    for k = 0, 2 do
        table.insert(o, { Uniform = true, Size = V(s * 0.5, s * 0.22, s * 0.87), Off = off, OffW = offW, Rot = V(0, k * 60, 0), Color = col, Material = METAL, Reflectance = 0.3 })
    end
    table.insert(o, { Shape = "Ball", Uniform = true, Size = V(s * 0.42, s * 0.3, s * 0.42), Off = off, OffW = offW + V(0, s * 0.06, 0), Color = center or col, Glow = glow or nil, Anim = "Pulse", PulseMin = 0, PulseMax = 0.35, Speed = 2 })
    return o
end
function OE.Orb(off, offW, s, col, glow, ring)
    return {
        { Shape = "Cylinder", Uniform = true, Size = V(s * 0.12, s * 0.8, s * 0.8), Off = off, OffW = offW, Rot = V(0, 0, 90), Color = ring or col, Material = METAL, Reflectance = 0.35 },
        { Shape = "Ball", Uniform = true, Size = V(s * 0.55, s * 0.4, s * 0.55), Off = off, OffW = offW + V(0, s * 0.08, 0), Color = col, Glow = glow, Material = (not glow) and SMOOTH or nil, Reflectance = 0.3,
            Anim = glow and "Pulse" or nil, PulseMin = 0.05, PulseMax = 0.35, Speed = 2 },
    }
end
function OE.Paw(off, offW, s, col, glow)
    local function P(sz, w) return { Shape = "Ball", Uniform = true, Size = V(sz, sz, sz), Off = off, OffW = offW + w, Color = col, Glow = glow, Material = (not glow) and SMOOTH or nil,
        Anim = glow and "Pulse" or nil, PulseMin = 0.05, PulseMax = 0.35, Speed = 2 } end
    return { P(s * 0.46, V(0, 0, s * 0.12)), P(s * 0.22, V(-s * 0.26, 0, -s * 0.16)), P(s * 0.22, V(0, 0, -s * 0.27)), P(s * 0.22, V(s * 0.26, 0, -s * 0.16)) }
end
function OE.Fish(off, offW, s, col, glow, fin)
    return {
        { Uniform = true, Size = V(s * 0.36, s * 0.22, s * 0.36), Off = off, OffW = offW + V(0, 0, -s * 0.06), Rot = V(0, 45, 0), Color = col, Glow = glow, Material = (not glow) and SMOOTH or nil, Reflectance = 0.2,
            Anim = glow and "Pulse" or nil, PulseMin = 0.05, PulseMax = 0.35, Speed = 1.6 },
        { Shape = "Ball", Uniform = true, Size = V(s * 0.3, s * 0.3, s * 0.3), Off = off, OffW = offW + V(0, 0, -s * 0.2), Color = col, Glow = glow, Material = (not glow) and SMOOTH or nil },
        { Uniform = true, Size = V(s * 0.3, s * 0.16, s * 0.12), Off = off, OffW = offW + V(-s * 0.1, 0, s * 0.24), Rot = V(0, 35, 0), Color = fin or col, Material = SMOOTH },
        { Uniform = true, Size = V(s * 0.3, s * 0.16, s * 0.12), Off = off, OffW = offW + V(s * 0.1, 0, s * 0.24), Rot = V(0, -35, 0), Color = fin or col, Material = SMOOTH },
    }
end
function OE.Fox(off, offW, s, col, accent)
    return {
        { Uniform = true, Size = V(s * 0.5, s * 0.22, s * 0.5), Off = off, OffW = offW + V(0, 0, s * 0.06), Rot = V(0, 45, 0), Color = col, Material = SMOOTH, Reflectance = 0.1 },
        { Uniform = true, Size = V(s * 0.2, s * 0.22, s * 0.2), Off = off, OffW = offW + V(-s * 0.22, 0, -s * 0.22), Rot = V(0, 45, 0), Color = col, Material = SMOOTH },
        { Uniform = true, Size = V(s * 0.2, s * 0.22, s * 0.2), Off = off, OffW = offW + V(s * 0.22, 0, -s * 0.22), Rot = V(0, 45, 0), Color = col, Material = SMOOTH },
        { Uniform = true, Size = V(s * 0.1, s * 0.26, s * 0.06), Off = off, OffW = offW + V(-s * 0.11, 0, -s * 0.02), Color = accent, Glow = true, Anim = "Pulse", PulseMin = 0, PulseMax = 0.4, Speed = 2.2 },
        { Uniform = true, Size = V(s * 0.1, s * 0.26, s * 0.06), Off = off, OffW = offW + V(s * 0.11, 0, -s * 0.02), Color = accent, Glow = true, Anim = "Pulse", PulseMin = 0, PulseMax = 0.4, Speed = 2.2 },
    }
end
function OE.Bat(off, offW, s, col, wing)
    local o = OE.Heart(off, offW + V(0, s * 0.02, 0), s * 0.6, col, true)
    for _, sx in ipairs({ -1, 1 }) do
        table.insert(o, { Uniform = true, Size = V(s * 0.42, s * 0.12, s * 0.16), Off = off, OffW = offW + V(sx * s * 0.36, 0, -s * 0.06), Rot = V(0, sx * 28, 0), Color = wing, Material = SMOOTH, Reflectance = 0.15 })
        table.insert(o, { Uniform = true, Size = V(s * 0.26, s * 0.12, s * 0.12), Off = off, OffW = offW + V(sx * s * 0.42, 0, s * 0.1), Rot = V(0, -sx * 22, 0), Color = wing, Material = SMOOTH, Reflectance = 0.15 })
    end
    return o
end
-- a medallion: a trim disc with an emblem on it
local function Medallion(pal, off, offW, s)
    local o = { { Shape = "Cylinder", Uniform = true, Size = V(s * 0.1, s, s), Off = off, OffW = offW, Rot = V(0, 0, 90), Color = pal.Trim, Material = METAL, Reflectance = 0.35 },
                { Shape = "Cylinder", Uniform = true, Size = V(s * 0.12, s * 0.82, s * 0.82), Off = off, OffW = offW + V(0, s * 0.01, 0), Rot = V(0, 0, 90), Color = pal.Dark, Material = SMOOTH, Reflectance = 0.1 } }
    if pal.Emblem then for _, p in ipairs(pal.Emblem(off, offW + V(0, s * 0.08, 0), s * 0.62)) do table.insert(o, p) end end
    return o
end

-- ===== STYLES (2026-10-07, owner: "Gloves and sleeves are good, but all really have the same pattern, needs far more
-- variation"): pal.Style picks the CUT of the piece; the palette / emblem / extras stay the set's own.
--   sleeves: "Plated" (the default: guard plates down the forearm), "Wrapped" (diagonal cloth wraps + a loose tail),
--            "Scaled" (rows of overlapping scales), "Flowing" (a wide bell cuff, drapes, a tassel), "Tech" (segmented
--            rings, a conduit, a lit panel), "Layered" (tiered frills, a ribbon bow, lace dots), "Bracer" (one hard
--            shell over the top, straps, studs)
--   gloves:  "Gauntlet" (the default), "Fingerless" (open fingers, wraps across the knuckles), "Claw" (talons, scaled
--            back), "Tech" (circuit back, knuckle light, wrist display), "Mitt" (puffy rounded, fluffy cuff),
--            "Lace" (fine trims, a bow, a ring), "Paw" (a mitt with big pads)
local SleeveStyles = {}
local GloveStyles = {}
local function Cuff(pal, o)
    local Dark2 = pal.Dark2 or Shade(pal.Dark, 1.7)
    table.insert(o, { Size = V(1.15, 1.15, 0.05), Off = V(0, 0, -0.477), Color = pal.Trim, Material = METAL, Reflectance = 0.35 })
    table.insert(o, { Size = V(1.17, 1.17, 0.012), Off = V(0, 0, -0.447), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.05, PulseMax = 0.4, Speed = 1.4 })
    table.insert(o, { Size = V(1.12, 1.12, 0.08), Off = V(0, 0, -0.40), Color = Dark2, Material = ClothMat(Dark2) })
end
function SleeveStyles.Wrapped(pal)
    local Main2 = pal.Main2 or Shade(pal.Main, 0.62)
    local o = {}
    Cuff(pal, o)
    -- cloth wraps spiralling up the forearm (tilted bands), a glowing thread between them
    for i = 0, 5 do
        local z = -0.33 + i * 0.105
        local tilt = (i % 2 == 0) and 14 or -14
        local col = (i % 2 == 0) and pal.Main or Main2
        table.insert(o, { Size = V(1.1, 1.1, 0.065), Off = V(0, 0, z), Rot = V(tilt, 0, 0), Color = col, Material = ClothMat(col), Reflectance = 0.02 })
        if i < 5 then table.insert(o, { Size = V(1.105, 1.105, 0.01), Off = V(0, 0, z + 0.052), Rot = V(-tilt * 0.5, 0, 0), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.1, PulseMax = 0.5, Speed = 1 + i * 0.15 }) end
    end
    -- the loose tail of the wrap, swaying off the outer side
    table.insert(o, { Size = V(0.04, 0.42, 0.09), Off = V(0.56, -0.32, -0.12), Rot = V(0, 0, 8), Color = pal.Main, Material = ClothMat(pal.Main), Anim = "Bob", Amp = 0.04, Speed = 2.1 })
    table.insert(o, { Size = V(0.04, 0.3, 0.08), Off = V(0.57, -0.42, -0.02), Rot = V(0, 0, -6), Color = Main2, Material = ClothMat(Main2), Anim = "Bob", Amp = 0.05, Speed = 2.5, Phase = 1 })
    -- a stitched tag with the emblem
    table.insert(o, { Size = V(0.34, 0.04, 0.18), Off = V(0, 0.55, -0.2), Color = pal.Trim, Material = METAL, Reflectance = 0.3 })
    if pal.Emblem then for _, p in ipairs(pal.Emblem(V(0, 0.55, -0.2), V(0, 0.03, 0), 0.24)) do table.insert(o, p) end end
    return o
end
function SleeveStyles.Scaled(pal)
    local Main2 = pal.Main2 or Shade(pal.Main, 0.62)
    local MM = pal.MainMat or SMOOTH
    local o = {}
    Cuff(pal, o)
    -- three rows of overlapping scales over the top and the upper sides, each row offset half a scale
    for row = 0, 2 do
        local z = -0.3 + row * 0.15
        local shift = (row % 2 == 0) and 0 or 0.11
        for c = -2, 1 do
            local x = c * 0.22 + 0.11 + shift
            if math.abs(x) < 0.5 then
                table.insert(o, { Wedge = true, Size = V(0.2, 0.05, 0.17), Off = V(x, 0.535 + row * 0.004, z), Rot = V(-10, 0, 0), Color = ((c + row) % 2 == 0) and pal.Main or Main2, Material = MM, Reflectance = 0.15 })
            end
        end
        for _, sx in ipairs({ -1, 1 }) do
            table.insert(o, { Size = V(0.05, 0.2, 0.15), Off = V(sx * 0.535, 0.28, z + 0.02), Rot = V(-10, 0, 0), Color = (row % 2 == 0) and Main2 or pal.Main, Material = MM, Reflectance = 0.15 })
            table.insert(o, { Size = V(0.05, 0.18, 0.15), Off = V(sx * 0.535, 0.04, z + 0.08), Rot = V(-10, 0, 0), Color = (row % 2 == 0) and pal.Main or Main2, Material = MM, Reflectance = 0.15 })
        end
        table.insert(o, { Size = V(0.95, 0.012, 0.014), Off = V(0, 0.565, z + 0.085), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.1, PulseMax = 0.55, Speed = 1.2 + row * 0.3 })
    end
    -- a spine ridge
    table.insert(o, { Uniform = true, Size = V(0.07, 0.07, 0.9), Off = V(0, 0.5, -0.05), OffW = V(0, 0.07, 0), Color = pal.Trim, Material = METAL, Reflectance = 0.35 })
    for _, p in ipairs(Medallion(pal, V(0, 0.5, -0.4), V(0, 0.07, 0), 0.3)) do table.insert(o, p) end
    return o
end
function SleeveStyles.Flowing(pal)
    local Main2 = pal.Main2 or Shade(pal.Main, 0.62)
    local o = {}
    -- the bell: a wide flared cuff (outer + lining + trim edge), a second tier above it
    table.insert(o, { Size = V(1.36, 1.36, 0.02), Off = V(0, 0, -0.535), Color = pal.Trim, Material = METAL, Reflectance = 0.35 })
    table.insert(o, { Size = V(1.34, 1.34, 0.13), Off = V(0, 0, -0.47), Color = pal.Main, Material = ClothMat(pal.Main) })
    table.insert(o, { Size = V(1.3, 1.3, 0.02), Off = V(0, 0, -0.545), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.2, PulseMax = 0.55, Speed = 1 })
    table.insert(o, { Size = V(1.24, 1.24, 0.11), Off = V(0, 0, -0.36), Color = Main2, Material = ClothMat(Main2) })
    table.insert(o, { Size = V(1.26, 1.26, 0.015), Off = V(0, 0, -0.30), Color = pal.Trim, Material = METAL, Reflectance = 0.3 })
    -- drapes hanging under the arm, swaying
    table.insert(o, { Size = V(0.9, 0.34, 0.26), Off = V(0, -0.64, -0.34), Color = pal.Main, Material = ClothMat(pal.Main), Anim = "Bob", Amp = 0.03, Speed = 1.6 })
    table.insert(o, { Wedge = true, Size = V(0.9, 0.2, 0.26), Off = V(0, -0.92, -0.34), Rot = V(0, 0, 180), Color = pal.Main, Material = ClothMat(pal.Main), Anim = "Bob", Amp = 0.03, Speed = 1.6 })
    table.insert(o, { Size = V(0.92, 0.012, 0.27), Off = V(0, -0.47, -0.34), Color = pal.Trim, Material = METAL, Reflectance = 0.3 })
    -- embroidery: two glowing threads along the top
    for _, sx in ipairs({ -1, 1 }) do
        table.insert(o, { Size = V(0.025, 0.01, 0.62), Off = V(sx * 0.2, 0.505, 0.02), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.15, PulseMax = 0.5, Speed = 1.1 })
    end
    -- a cord + tassel off the outer side
    table.insert(o, { Uniform = true, Size = V(0.05, 0.36, 0.05), Off = V(0.62, -0.1, -0.28), OffW = V(0, -0.18, 0), Color = pal.Trim, Material = METAL, Anim = "Bob", Amp = 0.04, Speed = 2.2 })
    table.insert(o, { Shape = "Ball", Uniform = true, Size = V(0.12, 0.12, 0.12), Off = V(0.62, -0.1, -0.28), OffW = V(0, -0.38, 0), Color = pal.Trim, Material = METAL, Reflectance = 0.35, Anim = "Bob", Amp = 0.04, Speed = 2.2 })
    table.insert(o, { Uniform = true, Size = V(0.1, 0.22, 0.1), Off = V(0.62, -0.1, -0.28), OffW = V(0, -0.52, 0), Color = pal.Glow, Glow = true, Anim = "Bob", Amp = 0.05, Speed = 2.2 })
    for _, p in ipairs(Medallion(pal, V(0, 0.5, -0.47), V(0, 0.18, 0), 0.32)) do table.insert(o, p) end
    return o
end
function SleeveStyles.Tech(pal)
    local Main2 = pal.Main2 or Shade(pal.Main, 0.62)
    local o = {}
    Cuff(pal, o)
    -- segmented rings, each with its own light line (they breathe out of step)
    for i = 0, 3 do
        local z = -0.3 + i * 0.15
        table.insert(o, { Size = V(1.12, 1.12, 0.05), Off = V(0, 0, z), Color = Main2, Material = SMOOTH, Reflectance = 0.15 })
        table.insert(o, { Size = V(1.13, 1.13, 0.01), Off = V(0, 0, z + 0.03), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0, PulseMax = 0.6, Speed = 1.5 + i * 0.45 })
    end
    -- a conduit along the outer side (metal tube, a lit core strip), two ports
    table.insert(o, { Shape = "Cylinder", Uniform = true, Size = V(0.95, 0.1, 0.1), Off = V(0.56, 0.12, -0.05), Rot = V(0, 90, 0), Color = pal.Trim, Material = METAL, Reflectance = 0.4 })
    table.insert(o, { Size = V(0.025, 0.04, 0.6), Off = V(0.585, 0.12, -0.05), Color = pal.Glow, Glow = true, Anim = "Flicker", Speed = 3 })
    for _, z in ipairs({ -0.36, 0.26 }) do
        table.insert(o, { Shape = "Ball", Uniform = true, Size = V(0.11, 0.11, 0.11), Off = V(0.56, 0.12, z), Color = pal.Main, Material = METAL, Reflectance = 0.3 })
    end
    -- the lit display on top, framed
    table.insert(o, { Size = V(0.44, 0.03, 0.26), Off = V(0, 0.53, -0.18), Color = pal.Trim, Material = METAL, Reflectance = 0.35 })
    table.insert(o, { Size = V(0.38, 0.035, 0.2), Off = V(0, 0.535, -0.18), Color = pal.Glow, Glow = true, Transparency = 0.15, Anim = "Flicker", Speed = 1.4 })
    table.insert(o, { Size = V(0.3, 0.04, 0.02), Off = V(0, 0.54, -0.21), Color = pal.Main, Material = SMOOTH })
    table.insert(o, { Size = V(0.2, 0.04, 0.02), Off = V(-0.05, 0.54, -0.15), Color = pal.Main, Material = SMOOTH })
    if pal.Emblem then for _, p in ipairs(pal.Emblem(V(0, 0.5, 0.2), V(0, 0.07, 0), 0.26)) do table.insert(o, p) end end
    return o
end
function SleeveStyles.Layered(pal)
    local Main2 = pal.Main2 or Shade(pal.Main, 0.62)
    local o = {}
    -- three tiers of frill at the cuff, each a little wider, trim / main / glow
    local tiers = { { 1.32, pal.Main, ClothMat(pal.Main) }, { 1.24, Main2, ClothMat(Main2) }, { 1.17, pal.Main, ClothMat(pal.Main) } }
    for i, t in ipairs(tiers) do
        local z = -0.505 + (i - 1) * 0.06
        table.insert(o, { Size = V(t[1], t[1], 0.045), Off = V(0, 0, z), Color = t[2], Material = t[3] })
        table.insert(o, { Size = V(t[1] + 0.02, t[1] + 0.02, 0.01), Off = V(0, 0, z - 0.024), Color = (i == 2) and pal.Glow or pal.Trim, Glow = (i == 2) or nil, Material = (i ~= 2) and METAL or nil, Reflectance = 0.3 })
    end
    -- scallop dots round the edge
    for k = 0, 7 do
        local a = k / 8 * math.pi * 2
        table.insert(o, { Shape = "Ball", Uniform = true, Size = V(0.09, 0.09, 0.09), Off = V(math.cos(a) * 0.66, math.sin(a) * 0.66, -0.53), Color = pal.Trim, Material = SMOOTH, Reflectance = 0.2 })
    end
    -- a ribbon bow on top (two loops, the knot carries the emblem, two tails)
    for _, sx in ipairs({ -1, 1 }) do
        table.insert(o, { Shape = "Ball", Uniform = true, Size = V(0.2, 0.2, 0.2), Off = V(0, 0.5, -0.24), OffW = V(sx * 0.17, 0.08, 0), Color = pal.Main, Material = SMOOTH, Reflectance = 0.1 })
        table.insert(o, { Uniform = true, Size = V(0.07, 0.03, 0.24), Off = V(0, 0.5, -0.24), OffW = V(sx * 0.08, 0.05, 0.15), Rot = V(0, sx * 18, 0), Color = Main2, Material = SMOOTH, Anim = "Bob", Amp = 0.02, Speed = 2 })
    end
    table.insert(o, { Shape = "Ball", Uniform = true, Size = V(0.12, 0.12, 0.12), Off = V(0, 0.5, -0.24), OffW = V(0, 0.09, 0), Color = pal.Trim, Material = METAL, Reflectance = 0.35 })
    -- lace dot rows down both sides
    for _, sx in ipairs({ -1, 1 }) do
        for k = 0, 4 do
            table.insert(o, { Shape = "Ball", Uniform = true, Size = V(0.05, 0.05, 0.05), Off = V(sx * 0.54, 0.22, -0.3 + k * 0.13), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.1, PulseMax = 0.5, Speed = 1.2 + k * 0.2 })
        end
    end
    if pal.Emblem then for _, p in ipairs(pal.Emblem(V(0, 0.5, 0.15), V(0, 0.06, 0), 0.26)) do table.insert(o, p) end end
    return o
end
function SleeveStyles.Bracer(pal)
    local Main2 = pal.Main2 or Shade(pal.Main, 0.62)
    local MM = pal.MainMat or SMOOTH
    local o = {}
    Cuff(pal, o)
    -- one hard shell over the top half of the forearm, trimmed front + back, engraved light lines
    table.insert(o, { Size = V(1.16, 0.56, 0.7), Off = V(0, 0.24, -0.08), Color = pal.Main, Material = MM, Reflectance = 0.2 })
    table.insert(o, { Wedge = true, Size = V(1.16, 0.56, 0.08), Off = V(0, 0.24, -0.47), Color = pal.Main, Material = MM, Reflectance = 0.2 })
    table.insert(o, { Size = V(1.18, 0.03, 0.72), Off = V(0, 0.535, -0.08), Color = Main2, Material = MM, Reflectance = 0.2 })
    for _, z in ipairs({ -0.43, 0.27 }) do table.insert(o, { Size = V(1.18, 0.58, 0.02), Off = V(0, 0.24, z), Color = pal.Trim, Material = METAL, Reflectance = 0.4 }) end
    for _, x in ipairs({ -0.28, 0, 0.28 }) do
        table.insert(o, { Size = V(0.025, 0.01, 0.56), Off = V(x, 0.552, -0.08), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.1, PulseMax = 0.55, Speed = 1.3 })
    end
    -- two straps under it, buckled on the outer side
    for _, z in ipairs({ -0.3, 0.14 }) do
        table.insert(o, { Size = V(1.12, 1.12, 0.05), Off = V(0, 0, z), Color = Main2, Material = SMOOTH })
        table.insert(o, { Uniform = true, Size = V(0.07, 0.16, 0.16), Off = V(0.56, -0.15, z), Color = pal.Trim, Material = METAL, Reflectance = 0.4 })
    end
    -- studs along the shell's edges
    for _, sx in ipairs({ -1, 1 }) do
        for k = 0, 3 do
            table.insert(o, { Shape = "Ball", Uniform = true, Size = V(0.06, 0.06, 0.06), Off = V(sx * 0.585, 0.08, -0.36 + k * 0.2), Color = pal.Trim, Material = METAL, Reflectance = 0.4 })
        end
    end
    for _, p in ipairs(Medallion(pal, V(0, 0.55, -0.1), V(0, 0.03, 0), 0.3)) do table.insert(o, p) end
    return o
end

-- the SLEEVE: a fitted cuff (trim band, glowing seam, a turned-back cuff carrying the medallion), three shaped guard
-- plates over the forearm (chamfered fronts, trim lips), side panels with glowing piping, a strap + buckle higher up
local function OutfitSleeve(pal, extra)
    local style = pal.Style and SleeveStyles[pal.Style]
    if style then
        local o = style(pal)
        for _, p in ipairs(extra or {}) do table.insert(o, p) end
        return o
    end
    local Dark2 = pal.Dark2 or Shade(pal.Dark, 1.7)
    local Main2 = pal.Main2 or Shade(pal.Main, 0.62)
    local o = {
        { Size = V(1.15, 1.15, 0.05), Off = V(0, 0, -0.477), Color = pal.Trim, Material = METAL, Reflectance = 0.35 },
        { Size = V(1.17, 1.17, 0.012), Off = V(0, 0, -0.447), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.05, PulseMax = 0.4, Speed = 1.4 },
        { Size = V(1.12, 1.12, 0.1), Off = V(0, 0, -0.39), Color = Dark2, Material = ClothMat(Dark2) },
        { Size = V(1.13, 1.13, 0.012), Off = V(0, 0, -0.335), Color = pal.Trim, Material = METAL, Reflectance = 0.3 },
        -- the strap + buckle round the upper forearm
        { Size = V(1.12, 1.12, 0.045), Off = V(0, 0, 0.16), Color = Main2, Material = SMOOTH, Reflectance = 0.08 },
        { Uniform = true, Size = V(0.24, 0.07, 0.15), Off = V(0, 0.5, 0.16), OffW = V(0, 0.05, 0), Color = pal.Trim, Material = METAL, Reflectance = 0.4 },
        { Uniform = true, Size = V(0.14, 0.08, 0.06), Off = V(0, 0.5, 0.16), OffW = V(0, 0.07, 0), Color = Dark2, Material = SMOOTH },
    }
    -- guard plates: a narrow spine of plates down the top of the forearm, wrist -> mid forearm, each narrower + a little
    -- higher than the last (they overlap like armour). Kept NARROW: full-width colour plates turned the whole arm into a
    -- pink tube in first person (the base must stay the biggest colour)
    for i = 0, 2 do
        local z = -0.27 + i * 0.13
        local wd = 0.56 - i * 0.06
        local y = 0.535 + i * 0.006
        table.insert(o, { Size = V(wd, 0.07, 0.13), Off = V(0, y, z), Rot = V(-5, 0, 0), Color = pal.Main, Material = pal.MainMat or SMOOTH, Reflectance = pal.MainMat and 0.25 or 0.04 })
        table.insert(o, { Wedge = true, Size = V(wd, 0.07, 0.045), Off = V(0, y, z - 0.087), Color = pal.Main, Material = pal.MainMat or SMOOTH, Reflectance = pal.MainMat and 0.25 or 0.04 })
        table.insert(o, { Size = V(wd + 0.02, 0.022, 0.018), Off = V(0, y + 0.04, z + 0.06), Color = pal.Trim, Material = METAL, Reflectance = 0.4 })
    end
    -- side panels (a shade lighter than the base) + glowing piping above them + a trim seam below (both sides: the same
    -- sleeve dresses either arm)
    for _, sx in ipairs({ -1, 1 }) do
        table.insert(o, { Size = V(0.05, 0.46, 0.5), Off = V(sx * 0.535, -0.06, -0.06), Color = Dark2, Material = SMOOTH, Reflectance = 0.04 })
        table.insert(o, { Size = V(0.06, 0.022, 0.5), Off = V(sx * 0.54, 0.19, -0.06), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.05, PulseMax = 0.45, Speed = 1.2 })
        table.insert(o, { Size = V(0.06, 0.018, 0.5), Off = V(sx * 0.54, -0.3, -0.06), Color = pal.Trim, Material = METAL, Reflectance = 0.3 })
        table.insert(o, { Wedge = true, Size = V(0.05, 0.46, 0.06), Off = V(sx * 0.535, -0.06, -0.34), Color = Dark2, Material = SMOOTH, Reflectance = 0.04 })
    end
    for _, p in ipairs(Medallion(pal, V(0, 0.5, -0.39), V(0, 0.07, 0), 0.34)) do table.insert(o, p) end
    for _, p in ipairs(extra or {}) do table.insert(o, p) end
    return o
end
-- the GLOVE: deep leather with a shaped knuckle guard (chamfer + trim lip), a back-of-hand plate carrying the emblem,
-- piping down both sides, tipped fingers and a short armoured cuff with trim bands
-- the cuff every glove style shares (the vambrace of pal.VambLen, two trim bands, a glow band: the older sets' forearm
-- pieces sit on it)
local function GloveCuff(pal)
    local Dark2 = pal.Dark2 or Shade(pal.Dark, 1.7)
    local VL = pal.VambLen or 0.42
    return Join(
        { Vamb(VL, { Color = Dark2, Material = ClothMat(Dark2) }) },
        { At({ Size = V(1.2, 1.2, 0.07), Uniform = true, Color = pal.Trim, Material = METAL, Reflectance = 0.35 }, 0, 0, 0.08 * 0.42 / VL, VL),
          At({ Size = V(1.2, 1.2, 0.07), Uniform = true, Color = pal.Trim, Material = METAL, Reflectance = 0.35 }, 0, 0, 1 - 0.08 * 0.42 / VL, VL),
          At({ Size = V(1.22, 1.22, 0.025), Uniform = true, Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.05, PulseMax = 0.45, Speed = 1.4 }, 0, 0, 0.21 / VL, VL) })
end
function GloveStyles.Fingerless(pal)
    local Main2 = pal.Main2 or Shade(pal.Main, 0.62)
    local o = GloveCuff(pal)
    -- the glove stops at the knuckles: a cut edge with a trim lip, wraps across the knuckles and the palm
    table.insert(o, { Size = V(1.04, 1.04, 0.04), Off = V(0, 0, -0.33), Color = pal.Trim, Material = METAL, Reflectance = 0.35 })
    table.insert(o, { Size = V(1.06, 1.06, 0.06), Off = V(0, 0, -0.27), Color = pal.Main, Material = ClothMat(pal.Main) })
    table.insert(o, { Size = V(1.06, 1.06, 0.06), Off = V(0, 0, -0.17), Rot = V(12, 0, 0), Color = Main2, Material = ClothMat(Main2) })
    -- an X strap over the back of the hand
    for _, a in ipairs({ 35, -35 }) do
        table.insert(o, { Size = V(0.12, 0.03, 0.62), Off = V(0, 0.52, 0.02), Rot = V(0, a, 0), Color = pal.Main, Material = ClothMat(pal.Main) })
    end
    table.insert(o, { Size = V(0.04, 0.02, 0.5), Off = V(0, 0.54, 0.02), Rot = V(0, 35, 0), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.1, PulseMax = 0.5, Speed = 1.3 })
    -- bare-looking finger section: a darker band (the open fingers)
    table.insert(o, { Size = V(1.02, 1.02, 0.14), Off = V(0, 0, -0.43), Color = Shade(pal.Dark, 0.8), Material = SMOOTH })
    if pal.Emblem then for _, p in ipairs(pal.Emblem(V(0, 0.5, 0.18), V(0, 0.07, 0), 0.24)) do table.insert(o, p) end end
    return o
end
function GloveStyles.Claw(pal)
    local Main2 = pal.Main2 or Shade(pal.Main, 0.62)
    local MM = pal.MainMat or SMOOTH
    local o = GloveCuff(pal)
    -- a heavy knuckle guard and four talons reaching past the fingertips
    table.insert(o, { Size = V(1.04, 0.12, 0.22), Off = V(0, 0.53, -0.28), Color = pal.Main, Material = MM, Reflectance = 0.2 })
    for i, x in ipairs({ -0.33, -0.11, 0.11, 0.33 }) do
        table.insert(o, { Wedge = true, Uniform = true, Size = V(0.09, 0.14, 0.34), Off = V(x, 0.34, -0.55), Rot = V(-28, 0, 0), Color = pal.Trim, Material = METAL, Reflectance = 0.4 })
        table.insert(o, { Uniform = true, Size = V(0.04, 0.05, 0.2), Off = V(x, 0.42, -0.5), Rot = V(-28, 0, 0), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.1, PulseMax = 0.6, Speed = 1.5 + i * 0.2 })
    end
    -- overlapping scales down the back of the hand
    for row = 0, 2 do
        local z = -0.12 + row * 0.14
        for _, x in ipairs({ -0.2, 0.2, (row % 2 == 1) and 0 or nil }) do
            table.insert(o, { Wedge = true, Size = V(0.3, 0.05, 0.16), Off = V(x, 0.53, z), Rot = V(-10, 0, 0), Color = (row % 2 == 0) and pal.Main or Main2, Material = MM, Reflectance = 0.15 })
        end
    end
    if pal.Emblem then for _, p in ipairs(pal.Emblem(V(0, 0.5, 0.3), V(0, 0.07, 0), 0.22)) do table.insert(o, p) end end
    return o
end
function GloveStyles.Tech(pal)
    local Main2 = pal.Main2 or Shade(pal.Main, 0.62)
    local o = GloveCuff(pal)
    -- a back panel with circuit lines, a knuckle light bar, finger segment rings, a wrist display
    table.insert(o, { Size = V(0.72, 0.05, 0.5), Off = V(0, 0.525, 0.02), Color = Main2, Material = SMOOTH, Reflectance = 0.15 })
    for _, x in ipairs({ -0.22, 0, 0.22 }) do
        table.insert(o, { Size = V(0.02, 0.01, 0.42), Off = V(x, 0.555, 0.02), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0, PulseMax = 0.6, Speed = 2 + x * 3 })
    end
    table.insert(o, { Size = V(0.48, 0.01, 0.02), Off = V(0, 0.555, -0.12), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0, PulseMax = 0.6, Speed = 2.6 })
    table.insert(o, { Size = V(1.0, 0.09, 0.14), Off = V(0, 0.52, -0.3), Color = pal.Main, Material = SMOOTH, Reflectance = 0.2 })
    table.insert(o, { Size = V(0.86, 0.02, 0.04), Off = V(0, 0.57, -0.3), Color = pal.Glow, Glow = true, Anim = "Flicker", Speed = 2 })
    for _, z in ipairs({ -0.4, -0.46 }) do table.insert(o, { Size = V(1.03, 1.03, 0.015), Off = V(0, 0, z), Color = pal.Trim, Material = METAL, Reflectance = 0.35 }) end
    table.insert(o, At({ Uniform = true, Size = V(0.4, 0.06, 0.22), Color = pal.Trim, Material = METAL, Reflectance = 0.35 }, 0, 1.02, 0.55, pal.VambLen or 0.42))
    table.insert(o, At({ Uniform = true, Size = V(0.34, 0.07, 0.17), Color = pal.Glow, Glow = true, Transparency = 0.15, Anim = "Flicker", Speed = 1.4 }, 0, 1.03, 0.55, pal.VambLen or 0.42))
    if pal.Emblem then for _, p in ipairs(pal.Emblem(V(0, 0.5, 0.16), V(0, 0.08, 0), 0.2)) do table.insert(o, p) end end
    return o
end
function GloveStyles.Mitt(pal)
    local Main2 = pal.Main2 or Shade(pal.Main, 0.62)
    local o = GloveCuff(pal)
    -- a rounded, puffy hand: soft lobes over the fingers and the back, a fluffy ring of puffs at the wrist
    for i, x in ipairs({ -0.3, 0, 0.3 }) do
        table.insert(o, { Shape = "Ball", Uniform = true, Size = V(0.42, 0.42, 0.42), Off = V(x, 0.3, -0.36), Color = (i == 2) and pal.Main or Main2, Material = ClothMat(pal.Main), Reflectance = 0.05 })
    end
    table.insert(o, { Shape = "Ball", Uniform = true, Size = V(0.6, 0.6, 0.6), Off = V(0, 0.3, 0.05), Color = pal.Main, Material = ClothMat(pal.Main), Reflectance = 0.05 })
    for k = 0, 7 do
        local a = k / 8 * math.pi * 2
        table.insert(o, At({ Shape = "Ball", Uniform = true, Size = V(0.24, 0.24, 0.24), Color = pal.Trim, Material = SMOOTH, Reflectance = 0.1 }, math.cos(a) * 0.95, math.sin(a) * 0.95, 0.08, pal.VambLen or 0.42))
    end
    table.insert(o, { Size = V(0.04, 0.02, 0.4), Off = V(0, 0.62, -0.02), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.1, PulseMax = 0.5, Speed = 1.2 })
    if pal.Emblem then for _, p in ipairs(pal.Emblem(V(0, 0.55, 0.06), V(0, 0.2, 0), 0.3)) do table.insert(o, p) end end
    return o
end
function GloveStyles.Paw(pal)
    local o = GloveStyles.Mitt(pal)
    -- big soft pads on the fingertips + the palm side you see when you inspect
    for _, x in ipairs({ -0.3, 0, 0.3 }) do
        table.insert(o, { Shape = "Ball", Uniform = true, Size = V(0.2, 0.2, 0.2), Off = V(x, -0.1, -0.5), Color = pal.Glow, Material = SMOOTH, Reflectance = 0.1 })
    end
    table.insert(o, { Shape = "Ball", Uniform = true, Size = V(0.4, 0.4, 0.4), Off = V(0, -0.4, -0.1), Color = pal.Glow, Material = SMOOTH, Reflectance = 0.1 })
    return o
end
function GloveStyles.Lace(pal)
    local Main2 = pal.Main2 or Shade(pal.Main, 0.62)
    local o = GloveCuff(pal)
    -- fine work: thin trim lines at the knuckles, a lace scallop at the cuff, a ribbon bow, a ring on the finger
    for _, z in ipairs({ -0.3, -0.2 }) do table.insert(o, { Size = V(1.03, 1.03, 0.012), Off = V(0, 0, z), Color = pal.Trim, Material = METAL, Reflectance = 0.4 }) end
    for k = 0, 9 do
        local a = k / 10 * math.pi * 2
        table.insert(o, At({ Shape = "Ball", Uniform = true, Size = V(0.1, 0.1, 0.1), Color = pal.Main, Material = SMOOTH }, math.cos(a) * 1.0, math.sin(a) * 1.0, 0.9, pal.VambLen or 0.42))
    end
    for _, sx in ipairs({ -1, 1 }) do
        table.insert(o, At({ Shape = "Ball", Uniform = true, Size = V(0.18, 0.18, 0.18), Color = pal.Main, Material = SMOOTH, Reflectance = 0.1 }, sx * 0.3, 1.05, 0.45, pal.VambLen or 0.42))
        table.insert(o, At({ Uniform = true, Size = V(0.06, 0.03, 0.22), Rot = V(0, sx * 20, 0), Color = Main2, Material = SMOOTH, Anim = "Bob", Amp = 0.02, Speed = 2 }, sx * 0.14, 1.03, 0.75, pal.VambLen or 0.42))
    end
    table.insert(o, At({ Shape = "Ball", Uniform = true, Size = V(0.1, 0.1, 0.1), Color = pal.Trim, Material = METAL, Reflectance = 0.4 }, 0, 1.08, 0.45, pal.VambLen or 0.42))
    table.insert(o, { Size = V(0.26, 0.26, 0.04), Off = V(0.25, 0, -0.4), Color = pal.Trim, Material = METAL, Reflectance = 0.45 })
    table.insert(o, { Uniform = true, Size = V(0.08, 0.08, 0.08), Off = V(0.25, 0.5, -0.4), OffW = V(0, 0.04, 0), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.1, PulseMax = 0.5, Speed = 2 })
    for _, sx in ipairs({ -1, 1 }) do
        table.insert(o, { Size = V(0.02, 0.02, 0.6), Off = V(sx * 0.51, 0.35, -0.02), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.1, PulseMax = 0.45, Speed = 1.1 })
    end
    if pal.Emblem then for _, p in ipairs(pal.Emblem(V(0, 0.5, 0.05), V(0, 0.06, 0), 0.24)) do table.insert(o, p) end end
    return o
end
local function OutfitGlove(pal, extra)
    local gstyle = pal.GloveStyle and GloveStyles[pal.GloveStyle]
    if gstyle then
        local o = gstyle(pal)
        for _, p in ipairs(extra or {}) do table.insert(o, p) end
        return o
    end
    local Dark2 = pal.Dark2 or Shade(pal.Dark, 1.7)
    local Main2 = pal.Main2 or Shade(pal.Main, 0.62)
    local VL = pal.VambLen or 0.42
    local MM = pal.MainMat or SMOOTH
    local MR = pal.MainMat and 0.25 or 0.04
    local o = Join(
        { Vamb(VL, { Color = Dark2, Material = ClothMat(Dark2) }) },
        { At({ Size = V(1.2, 1.2, 0.07), Uniform = true, Color = pal.Trim, Material = METAL, Reflectance = 0.35 }, 0, 0, 0.08 * 0.42 / VL, VL),
          At({ Size = V(1.2, 1.2, 0.07), Uniform = true, Color = pal.Trim, Material = METAL, Reflectance = 0.35 }, 0, 0, 1 - 0.08 * 0.42 / VL, VL),
          At({ Size = V(1.22, 1.22, 0.025), Uniform = true, Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.05, PulseMax = 0.45, Speed = 1.4 }, 0, 0, 0.21 / VL, VL) })
    if not pal.NoKnuckle then
        for _, p in ipairs({
            { Size = V(1.0, 0.1, 0.2), Off = V(0, 0.52, -0.27), Color = pal.Main, Material = MM, Reflectance = MR },
            { Wedge = true, Size = V(1.0, 0.1, 0.07), Off = V(0, 0.52, -0.405), Color = pal.Main, Material = MM, Reflectance = MR },
            { Size = V(1.02, 0.025, 0.025), Off = V(0, 0.585, -0.17), Color = pal.Trim, Material = METAL, Reflectance = 0.4 },
        }) do table.insert(o, p) end
    end
    if not pal.NoBack then
        table.insert(o, { Size = V(0.66, 0.06, 0.34), Off = V(0, 0.53, 0.1), Color = Main2, Material = SMOOTH, Reflectance = 0.04 })
        table.insert(o, { Size = V(0.7, 0.02, 0.02), Off = V(0, 0.565, -0.075), Color = pal.Trim, Material = METAL, Reflectance = 0.4 })
    end
    if not pal.NoTips then
        table.insert(o, { Size = V(1.04, 1.04, 0.08), Off = V(0, 0, -0.47), Color = Main2, Material = SMOOTH, Reflectance = 0.04 })
    end
    for _, sx in ipairs({ -1, 1 }) do
        table.insert(o, { Size = V(0.03, 0.03, 0.62), Off = V(sx * 0.515, 0.3, -0.02), Color = pal.Glow, Glow = true, Anim = "Pulse", PulseMin = 0.05, PulseMax = 0.45, Speed = 1.2 })
    end
    if pal.Emblem then for _, p in ipairs(pal.Emblem(V(0, 0.5, 0.1), V(0, 0.08, 0), 0.3)) do table.insert(o, p) end end
    for _, p in ipairs(extra or {}) do table.insert(o, p) end
    return o
end
GloveFX.OutfitKit = { Sleeve = OutfitSleeve, Glove = OutfitGlove, Emblem = OE, Medallion = Medallion, Shade = Shade, SleeveStyles = SleeveStyles, GloveStyles = GloveStyles }

-- ==================== GLOVES ====================
local L = 1.0 -- vambrace length (units of w)
GloveFX.Gloves = {
    { Id = "BareHands", Name = "Bare Hands", Rarity = "Common", Unlock = "Free", Desc = "No gloves: your own skin.", Base = nil },
    { Id = "Tactical", Name = "Tactical", Rarity = "Common", Unlock = "Free", Desc = "Black synthetic gloves with a hard knuckle plate and a wrist strap.",
      Base = { Color = C(34, 36, 42), Material = FABRIC },
      Parts = { { Size = V(1.04, 0.3, 0.55), Off = V(0, 0.42, -0.1), Color = C(70, 74, 84), Material = METAL },
                { Size = V(1.06, 1.06, 0.3), Off = V(0, 0, 0.42), Color = C(24, 25, 30), Material = FABRIC } } },
    { Id = "Leather", Name = "Field Leather", Rarity = "Uncommon", Unlock = "Level", Level = 5, Desc = "Worn brown leather with a stitched cuff.",
      Base = { Color = C(112, 74, 46), Material = SMOOTH },
      Parts = { { Size = V(1.06, 1.06, 0.28), Off = V(0, 0, 0.38), Color = C(74, 48, 30), Material = FABRIC },
                { Size = V(1.07, 0.04, 0.9), Off = V(0, 0.5, 0), Color = C(200, 170, 120), Material = FABRIC } } },
    { Id = "Carbon", Name = "Carbon Strike", Rarity = "Rare", Unlock = "Level", Level = 15, Desc = "Real carbon weave with a red racing stripe.",
      Base = { Color = C(26, 26, 30), Material = SMOOTH, Reflectance = 0.08, Tex = "Carbon", TexTile = 0.45 },
      Parts = { { Size = V(0.22, 1.05, 1.02), Off = V(0, 0, 0), Color = C(210, 40, 50), Material = SMOOTH },
                { Size = V(1.04, 0.28, 0.5), Off = V(0, 0.42, -0.15), Color = C(50, 50, 58), Material = METAL, Reflectance = 0.2 } } },
    { Id = "Ranger", Name = "Ranger", Rarity = "Rare", Unlock = "Level", Level = 25, Desc = "Olive drab with tan armoured knuckles.",
      Base = { Color = C(78, 86, 56), Material = FABRIC },
      Parts = { { Size = V(1.06, 0.3, 0.6), Off = V(0, 0.42, -0.12), Color = C(170, 146, 104), Material = SMOOTH } } },

    -- ----- super rare boss drops (tier V trials only, 0.25% per clear) -----
    { Id = "SeraphGrips", Name = "Seraph Grips", Rarity = "Mythic", Unlock = "Drop", DropFrom = "Trial", How = "Retired: the Seraph Archon trial drops relics now (kept by anyone who owns it)",
      Desc = "Pearl gauntlets wrapped in gold filigree. Small wings fold along the wrist and spread when you inspect; a star on the forearm never stops shining.",
      Base = { Color = PEARL, Material = SMOOTH, Reflectance = 0.06, Tex = "Filigree", TexTile = 0.8 },
      Parts = Join(
          { Vamb(0.75, { Color = PEARL, Material = SMOOTH, Reflectance = 0.08, Tex = "Filigree", TexTile = 0.8 }) },
          Bands(0.75, GOLDMETAL, METAL, PALEGOLD),
          Star(At({}, 0, 1.03, 0.5, 0.75), 0.4, "Y"),
          { { Size = V(1.08, 1.08, 0.14), Off = V(0, 0, -0.44), Color = GOLDMETAL, Material = METAL, Reflectance = 0.25 } },
          Wing(1, { N = 2, VL = 0.75, Amp = 3, Len = 0.7, H = 0.22 }), Wing(-1, { N = 2, VL = 0.75, Amp = 3, Len = 0.7, H = 0.22 })),
      Emit = { { Texture = SPARK, Color = { C(255, 240, 200), GOLD }, Rate = 4, Size = 0.28, Speed = 0.3, Life = 0.9 },
               { Burst = "Kill", Texture = FEATHER, Color = { C(255, 255, 255) }, Size = 0.45, Speed = 2.5, Life = 1.2, Count = 10, Accel = V(0, -1, 0), Spin = true, LightEmission = 0.25 },
               { Burst = "Kill", Texture = SPARK, Color = { C(255, 255, 255), GOLD }, Size = 0.6, Speed = 3, Life = 0.6, Count = 16 } } },
    { Id = "ChronoGauntlets", Name = "Chrono Gauntlets", Rarity = "Mythic", Unlock = "Drop", DropFrom = "Trial", How = "Retired: the Chronarch trial drops relics now (kept by anyone who owns it)",
      Desc = "Engraved bronze with a working clock on the forearm, hour, minute and sweeping second hand, and gears that turn at the wrist. Every shot ticks it.",
      Base = { Color = C(120, 84, 48), Material = METAL, Reflectance = 0.12, Tex = "Brass", TexTile = 0.9 },
      Parts = Join(
          { Vamb(L, { Color = C(132, 94, 54), Material = METAL, Reflectance = 0.15, Tex = "Brass", TexTile = 0.9 }) },
          Bands(L, C(200, 160, 90), METAL, C(90, 230, 255)),
          { -- the clock: an ivory face on top of the forearm, gold rim, glowing cyan ring, three hands
            At({ Shape = "Cylinder", Uniform = true, Size = V(0.05, 0.86, 0.86), Rot = V(0, 0, 90), Color = C(236, 228, 210), Material = SMOOTH }, 0, 1.02, 0.5, L),
            At({ Ring = 14, Radius = 0.45, Thick = 0.05, Axis = "Y", Color = C(214, 170, 90), Material = METAL }, 0, 1.06, 0.5, L),
            At({ Ring = 14, Radius = 0.5, Thick = 0.022, Axis = "Y", Color = C(90, 230, 255), Glow = true, Anim = "Pulse", PulseMin = 0, PulseMax = 0.5, FlashOn = "Fire" }, 0, 1.04, 0.5, L),
            At({ Uniform = true, Size = V(0.05, 0.02, 0.22), Root = -1, Color = C(30, 26, 22), Anim = "Clock", Hand = "H" }, 0, 1.1, 0.5, L),
            At({ Uniform = true, Size = V(0.035, 0.02, 0.33), Root = -1, Color = C(30, 26, 22), Anim = "Clock", Hand = "M" }, 0, 1.12, 0.5, L),
            At({ Uniform = true, Size = V(0.018, 0.02, 0.38), Root = -1, Color = C(220, 50, 40), Glow = true, Anim = "Clock", Hand = "S" }, 0, 1.14, 0.5, L),
            At({ Shape = "Cylinder", Uniform = true, Size = V(0.04, 0.08, 0.08), Rot = V(0, 0, 90), Color = GOLD, Material = METAL }, 0, 1.15, 0.5, L),
            -- gears on both sides of the wrist, turning against each other
            At({ Ring = 10, Radius = 0.3, Thick = 0.07, Axis = "X", Teeth = true, Color = C(200, 160, 90), Material = METAL, Reflectance = 0.25, Anim = "Spin", Speed = 1.2 }, 1.08, 0, 0.3, L),
            At({ Ring = 10, Radius = 0.3, Thick = 0.07, Axis = "X", Teeth = true, Color = C(200, 160, 90), Material = METAL, Reflectance = 0.25, Anim = "Spin", Speed = -1.2 }, -1.08, 0, 0.3, L),
            At({ Shape = "Ball", Uniform = true, Size = V(0.14, 0.14, 0.14), Color = C(90, 230, 255), Glow = true, Anim = "Pulse" }, 1.12, 0, 0.3, L),
            At({ Shape = "Ball", Uniform = true, Size = V(0.14, 0.14, 0.14), Color = C(90, 230, 255), Glow = true, Anim = "Pulse" }, -1.12, 0, 0.3, L),
            { Size = V(1.08, 1.08, 0.14), Off = V(0, 0, -0.44), Color = C(200, 160, 90), Material = METAL, Reflectance = 0.25 },
          }),
      Emit = { { Burst = "Fire", Texture = SPARK, Color = { C(140, 240, 255) }, Size = 0.25, Speed = 1.5, Life = 0.25, Count = 3 },
               { Burst = "Kill", Texture = SPARK, Color = { C(90, 230, 255), C(255, 255, 255) }, Size = 0.55, Speed = 3, Life = 0.55, Count = 18 } },
      Shock = { Kill = { Kind = "Nova", Color = C(90, 230, 255) } } },
    { Id = "EchoWraps", Name = "Echo Wraps", Rarity = "Mythic", Unlock = "Drop", DropFrom = "Trial", How = "Retired: the Echo Warden trial drops relics now (kept by anyone who owns it)",
      Desc = "Void-dark wraps full of drifting stars, their cracks flickering with purple light.",
      Base = { Color = C(26, 16, 40), Material = FABRIC, Tex = "Stars", TexTile = 0.9, TexScroll = V2(0.02, 0.05) },
      Parts = Join(
          { Vamb(0.8, { Color = C(30, 18, 46), Material = FABRIC, Tex = "Stars", TexTile = 0.9, TexScroll = V2(0.02, 0.05) }) },
          { At({ Size = V(1.18, 0.16, 0.3), Uniform = true, Rot = V(0, 0, 18), Color = C(50, 32, 74), Material = FABRIC }, 0, 0, 0.25, 0.8),
            At({ Size = V(1.18, 0.16, 0.3), Uniform = true, Rot = V(0, 0, -18), Color = C(50, 32, 74), Material = FABRIC }, 0, 0, 0.7, 0.8),
            { Size = V(0.06, 0.06, 0.8), Off = V(0.3, 0.52, 0), Rot = V(0, 25, 0), Color = C(190, 110, 255), Glow = true, Anim = "Flicker" },
            { Size = V(0.06, 0.06, 0.6), Off = V(-0.25, 0.52, -0.15), Rot = V(0, -35, 0), Color = C(190, 110, 255), Glow = true, Anim = "Flicker" },
            { Size = V(0.04, 0.7, 0.05), Off = V(0.52, 0, 0), Rot = V(0, 0, 12), Color = C(190, 110, 255), Glow = true, Anim = "Flicker", Rate = 9 },
            { Size = V(0.04, 0.7, 0.05), Off = V(-0.52, 0, 0), Rot = V(0, 0, -12), Color = C(190, 110, 255), Glow = true, Anim = "Flicker", Rate = 9 },
            -- (the two lagging "echo" copies of the hand are gone -- owner 2026-10-03: "the void gloves leave behind an annoying trail")
          }),
      Emit = { { Texture = SMOKE, Color = { C(120, 60, 200) }, Rate = 4, Size = 0.6, Speed = 0.2, Life = 1.0, Transparency = 0.6 },
               { Burst = "Kill", Texture = SPARK, Color = { C(190, 110, 255) }, Size = 0.6, Speed = 3.5, Life = 0.6, Count = 16 } },
      Shock = { Kill = { Kind = "Implode", Color = C(170, 90, 255) } } },
    { Id = "ForgeheartGrips", Name = "Forgeheart Grips", Rarity = "Mythic", Unlock = "Drop", DropFrom = "Trial", How = "Retired: the Forgeheart trial drops relics now (kept by anyone who owns it)",
      Desc = "Blackened forge iron with a furnace burning inside the forearm. Every shot stokes it white-hot and throws hammer sparks. Brand runes crawl down both sides; kills erupt.",
      Base = { Color = C(44, 40, 38), Material = Enum.Material.CorrodedMetal, Reflectance = 0.05 },
      Parts = Join(
          { Vamb(L, { Color = C(50, 46, 44), Material = Enum.Material.CorrodedMetal, Reflectance = 0.05 }) },
          Bands(L, C(86, 78, 72), METAL, C(255, 120, 30)),
          { -- the furnace window: an iron frame on top of the forearm, the fire behind it, three grate bars across
            At({ Size = V(0.74, 0.08, 0.5), Uniform = true, Color = C(30, 26, 24), Material = METAL }, 0, 1.0, 0.5, L),
            At({ Size = V(0.6, 0.06, 0.38), Uniform = true, Color = C(255, 120, 30), Glow = true, HeatGlow = true }, 0, 1.06, 0.5, L),
            At({ Size = V(0.62, 0.07, 0.4), Uniform = true, Color = C(255, 240, 200), Glow = true, Anim = "Pulse", PulseMin = 0.2, PulseMax = 1, Speed = 5, FlashOn = "Fire" }, 0, 1.07, 0.5, L),
            At({ Size = V(0.05, 0.06, 0.44), Uniform = true, Color = C(24, 22, 20), Material = METAL }, -0.2, 1.12, 0.5, L),
            At({ Size = V(0.05, 0.06, 0.44), Uniform = true, Color = C(24, 22, 20), Material = METAL }, 0, 1.12, 0.5, L),
            At({ Size = V(0.05, 0.06, 0.44), Uniform = true, Color = C(24, 22, 20), Material = METAL }, 0.2, 1.12, 0.5, L),
            At({ Size = V(0.8, 0.1, 0.06), Uniform = true, Color = C(86, 78, 72), Material = METAL }, 0, 1.08, 0.24, L),
            At({ Size = V(0.8, 0.1, 0.06), Uniform = true, Color = C(86, 78, 72), Material = METAL }, 0, 1.08, 0.76, L),
            -- the anvil-horn knuckle plate
            { Size = V(1.1, 0.26, 0.5), Off = V(0, 0.44, -0.18), Color = C(70, 64, 60), Material = METAL, Reflectance = 0.15 },
            { Wedge = true, Uniform = true, Size = V(0.9, 0.16, 0.3), Off = V(0, 0.5, -0.52), Color = C(70, 64, 60), Material = METAL, Reflectance = 0.15 },
            { Size = V(1.12, 0.05, 0.05), Off = V(0, 0.58, -0.2), Color = C(255, 140, 40), Glow = true, HeatGlow = true } },
          (function()
              -- brand runes chasing down both sides (white-hot chevrons)
              local out = {}
              for _, sx in ipairs({ 1, -1 }) do
                  for i, z in ipairs({ 0.22, 0.5, 0.78 }) do
                      table.insert(out, At({ Size = V(0.04, 0.2, 0.2), Uniform = true, Rot = V(45, 0, 0), Color = C(255, 236, 190), Glow = true, Anim = "Chase", Index = i }, sx * 1.02, 0.15, z, L))
                  end
                  -- rivets along the bands
                  for _, z in ipairs({ 0.05, 0.95 }) do
                      table.insert(out, At({ Shape = "Ball", Uniform = true, Size = V(0.1, 0.1, 0.1), Color = C(140, 128, 118), Material = METAL }, sx * 1.06, 0.6, z, L))
                  end
              end
              return out
          end)()),
      Emit = { { Texture = SPARK, Color = { C(255, 170, 70) }, Rate = 4, Size = 0.16, Speed = 1.2, Life = 0.7, Accel = V(0, 2.5, 0), Off = V(0, 0, 0.5), OffW = V(0, 0.62, 0.5) },
               { Texture = SMOKE, Color = { C(60, 54, 50) }, Rate = 2, Size = 0.5, Speed = 0.5, Life = 1.1, Transparency = 0.6, Accel = V(0, 1.2, 0), Off = V(0, 0, 0.5), OffW = V(0, 0.62, 0.5) },
               { Burst = "Fire", Texture = SPARK, Color = { C(255, 240, 190), C(255, 150, 50) }, Size = 0.22, Speed = 5, Life = 0.35, Count = 6, Accel = V(0, -10, 0), Off = V(0, 0, 0.5), OffW = V(0, 0.62, 0.5) },
               { Burst = "Kill", Texture = FIRE, Color = { C(255, 240, 200), C(255, 110, 30) }, Size = 1.0, Speed = 4.5, Life = 0.55, Count = 20 },
               { Burst = "Kill", Texture = SPARK, Color = { C(255, 255, 230) }, Size = 0.5, Speed = 6, Life = 0.5, Count = 14, Accel = V(0, -8, 0) } },
      Shock = { Kill = { Kind = "Erupt", Color = C(255, 210, 140) } } },
    { Id = "Titanbreakers", Name = "Titanbreakers", Rarity = "Legendary", Unlock = "Drop", DropFrom = "Titan", DropChance = 0.005, How = "Apex Titan Mech: 0.5% per kill",
      Desc = "Mech fists torn off the Apex Titan: stacked armour, hydraulic pistons that kick with every shot, a red reactor core and steam vents.",
      Base = { Color = C(26, 26, 30), Material = METAL, Reflectance = 0.1, Tex = "Carbon", TexTile = 0.45 },
      Parts = Join(
          { Vamb(L, { Color = C(40, 42, 48), Material = METAL, Reflectance = 0.15, Tex = "Scales", TexTile = 0.5 }) },
          { { Size = V(1.18, 0.38, 0.75), Off = V(0, 0.42, -0.1), Color = C(48, 50, 58), Material = METAL, Reflectance = 0.22 },
            { Size = V(1.2, 0.08, 0.1), Off = V(0, 0.62, -0.42), Color = C(255, 50, 40), Glow = true, Anim = "Pulse", PulseMin = 0, PulseMax = 0.4 },
            At({ Size = V(1.24, 0.22, 0.34), Uniform = true, Color = C(56, 58, 66), Material = METAL, Reflectance = 0.2 }, 0, 0.98, 0.2, L),
            At({ Size = V(1.24, 0.22, 0.34), Uniform = true, Color = C(50, 52, 60), Material = METAL, Reflectance = 0.2 }, 0, 0.94, 0.52, L),
            At({ Size = V(1.24, 0.22, 0.34), Uniform = true, Color = C(44, 46, 54), Material = METAL, Reflectance = 0.2 }, 0, 0.9, 0.84, L),
            -- reactor core on top
            At({ Shape = "Ball", Uniform = true, Size = V(0.3, 0.3, 0.3), Color = C(255, 50, 40), Glow = true, Anim = "Pulse", PulseMin = 0, PulseMax = 0.35, FlashOn = "Fire" }, 0, 1.25, 0.52, L),
            At({ Ring = 8, Radius = 0.22, Thick = 0.05, Axis = "Y", Color = C(70, 72, 80), Material = METAL }, 0, 1.22, 0.52, L),
            -- hydraulic pistons along both sides: sleeve + rod that kicks back on each shot
            At({ Shape = "Cylinder", Uniform = true, Size = V(0.5, 0.17, 0.17), Rot = V(0, 90, 0), Color = C(60, 62, 70), Material = METAL, Reflectance = 0.3 }, 1.12, 0.3, 0.6, L),
            At({ Shape = "Cylinder", Uniform = true, Size = V(0.55, 0.09, 0.09), Rot = V(0, 90, 0), Color = C(200, 204, 210), Material = METAL, Reflectance = 0.5, Anim = "Piston", Dist = 0.18 }, 1.12, 0.3, 0.2, L),
            At({ Shape = "Cylinder", Uniform = true, Size = V(0.5, 0.17, 0.17), Rot = V(0, 90, 0), Color = C(60, 62, 70), Material = METAL, Reflectance = 0.3 }, -1.12, 0.3, 0.6, L),
            At({ Shape = "Cylinder", Uniform = true, Size = V(0.55, 0.09, 0.09), Rot = V(0, 90, 0), Color = C(200, 204, 210), Material = METAL, Reflectance = 0.5, Anim = "Piston", Dist = 0.18 }, -1.12, 0.3, 0.2, L),
            -- warning stripes
            At({ Size = V(0.04, 0.5, 0.05), Uniform = true, Color = C(255, 180, 30), Glow = true }, 1.0, -0.3, 0.85, L),
            At({ Size = V(0.04, 0.5, 0.05), Uniform = true, Color = C(255, 180, 30), Glow = true }, -1.0, -0.3, 0.85, L) }),
      Emit = { { Texture = SPARK, Color = { C(255, 90, 60) }, Rate = 3, Size = 0.22, Speed = 0.6, Life = 0.5 },
               { Burst = "Fire", Texture = SMOKE, Color = { C(230, 230, 235) }, Size = 0.45, Speed = 1.6, Life = 0.4, Count = 2, Transparency = 0.5, Off = V(0, 0.4, 0.5), OffW = V(0, 0.4, 0.9) },
               { Burst = "Kill", Texture = FIRE, Color = { C(255, 120, 60), C(255, 40, 20) }, Size = 0.6, Speed = 2, Life = 0.45, Count = 14 } },
      Shock = { Kill = { Kind = "Nova", Color = C(255, 60, 40) } } },

    -- ----- Robux: the INSANE ones -----
    { Id = "CelestialFury", Name = "Celestial Fury", Rarity = "Mythic", Unlock = "Robux", Price = 799, ProductId = 3716099911,
      -- (v2 2026-10-07: the tailored kit in pearl + gold, the wings / halo / stars / sigil kept)
      Desc = "Pearl gauntlets armoured in gold: a gold knuckle guard, pale-gold piping and a star of light on the back of each hand, with living wings along the forearm. A halo spins at the wrist, every shot rings out in gold, kills scatter feathers in a burst of light, and inspecting raises a radiant sigil.",
      Base = { Color = PEARL, Material = METAL, Reflectance = 0.12 },
      Parts = OutfitGlove({ Dark = PEARL, Dark2 = C(190, 184, 172), Main = GOLDMETAL, MainMat = METAL, Main2 = C(176, 136, 60), Trim = PALEGOLD, Glow = PALEGOLD, VambLen = L,
              Emblem = function(off, offW, s) return OE.Star(off, offW, s, GOLD, true) end },
          Join(
          { At({ Size = V(0.05, 0.05, 0.78), Uniform = true, Color = PALEGOLD, Glow = true, Anim = "Chase", Index = 1 }, 0.86, 1.0, 0.5, L),
            At({ Size = V(0.05, 0.05, 0.78), Uniform = true, Color = PALEGOLD, Glow = true, Anim = "Chase", Index = 2 }, -0.86, 1.0, 0.5, L) },
          Star({ Off = V(0.53, 0, -0.05) }, 0.42, "X"), Star({ Off = V(-0.53, 0, -0.05) }, 0.42, "X"),
          Wing(1, { N = 3 }), Wing(-1, { N = 3 }),
          { { Ring = 12, Radius = 0.74, Thick = 0.05, Off = V(0, 0, 0.5), OffW = V(0, 0, 0.3), Color = PALEGOLD, Glow = true, Anim = "Spin", Speed = 1.4, FlashOn = "Fire" },
            -- inspect: a radiant sigil around the forearm + light rays
            { Ring = 22, Radius = 1.3, Thick = 0.035, Off = V(0, 0, 0.5), OffW = V(0, 0, 0.5), Color = GOLD, Glow = true, Anim = "Spin", Speed = -0.9, ShowOn = "Inspect", ShowFor = 1.9 },
            { Ring = 16, Radius = 1.05, Thick = 0.02, Off = V(0, 0, 0.5), OffW = V(0, 0, 0.5), Color = PALEGOLD, Glow = true, Anim = "Spin", Speed = 1.5, ShowOn = "Inspect", ShowFor = 1.9 },
            { Rays = true, Off = V(0, 0, 0.5), OffW = V(0, 0.2, 0.4), Size = 3.6, Color = PALEGOLD, ShowOn = "Inspect", ShowFor = 1.9, Spin = 30 } })),
      Emit = { { Texture = SPARK, Color = { C(255, 245, 210), GOLD }, Rate = 7, Size = 0.26, Speed = 0.35, Life = 1.0, Accel = V(0, 0.5, 0) },
               { Texture = FEATHER, Color = { C(255, 252, 240) }, Rate = 0.7, Size = 0.32, Speed = 0.25, Life = 1.8, Accel = V(0, -0.35, 0), Spin = true, LightEmission = 0.2 },
               { Burst = "Fire", Texture = SPARK, Color = { C(255, 255, 255), GOLD }, Size = 0.36, Speed = 2.5, Life = 0.22, Count = 5, Off = V(0, 0, -0.6) },
               { Burst = "Kill", Texture = FEATHER, Color = { C(255, 255, 255), C(255, 236, 190) }, Size = 0.55, Speed = 3.2, Life = 1.3, Count = 14, Accel = V(0, -1.2, 0), Spin = true, LightEmission = 0.3 },
               { Burst = "Kill", Texture = SPARK, Color = { C(255, 255, 255), GOLD }, Size = 0.85, Speed = 4, Life = 0.7, Count = 24 },
               { Burst = "Inspect", Texture = SPARK, Color = { GOLD }, Size = 0.5, Speed = 1.2, Life = 1.4, Count = 30 } },
      Shock = { Kill = { Kind = "Nova", Color = GOLD } } },
    { Id = "Voidrend", Name = "Voidrend", Rarity = "Mythic", Unlock = "Robux", Price = 799, ProductId = 3716099918,
      Desc = "Obsidian split by living purple cracks. Black holes sit in your forearms with spinning accretion rings; void lightning crawls to your knuckles, and every kill implodes.",
      Base = { Color = C(14, 10, 20), Material = GLASS, Reflectance = 0.18, Tex = "VoidCracks", TexTile = 0.8, TexScroll = V2(0.01, 0.03) },
      Parts = Join(
          { Vamb(L, { Color = C(16, 12, 24), Material = GLASS, Reflectance = 0.22, Tex = "VoidCracks", TexTile = 0.9, TexScroll = V2(-0.01, 0.03) }) },
          Bands(L, C(36, 24, 52), GLASS, C(190, 90, 255)),
          { At({ Wedge = true, Uniform = true, Size = V(0.1, 0.26, 0.3), Color = C(40, 26, 60), Material = GLASS, Reflectance = 0.35 }, 0, 1.2, 0.3, L),
            At({ Wedge = true, Uniform = true, Size = V(0.1, 0.32, 0.34), Color = C(40, 26, 60), Material = GLASS, Reflectance = 0.35 }, 0, 1.24, 0.6, L),
            At({ Wedge = true, Uniform = true, Size = V(0.1, 0.22, 0.26), Color = C(40, 26, 60), Material = GLASS, Reflectance = 0.35 }, 0, 1.18, 0.88, L) },
          (function()
              local out = {}
              for _, s in ipairs({ 1, -1 }) do
                  table.insert(out, At({ Shape = "Ball", Uniform = true, Size = V(0.32, 0.32, 0.32), Color = C(0, 0, 0), Material = NEON, Tag = "Orb" .. s }, s * 1.3, 0.1, 0.5, L))
                  table.insert(out, At({ Shape = "Ball", Uniform = true, Size = V(0.42, 0.42, 0.42), Color = C(150, 60, 255), Glow = true, Transparency = 0.8, Anim = "Pulse", PulseMin = 0.72, PulseMax = 0.9 }, s * 1.3, 0.1, 0.5, L))
                  table.insert(out, At({ Ring = 10, Radius = 0.3, Thick = 0.035, Axis = "X", Tilt = V(25, 0, 0), Color = C(190, 90, 255), Glow = true, Anim = "Spin", Speed = 5, BoostOn = "Inspect" }, s * 1.3, 0.1, 0.5, L))
                  table.insert(out, At({ Ring = 8, Radius = 0.42, Thick = 0.02, Axis = "X", Tilt = V(-35, 0, 0), Color = C(240, 200, 255), Glow = true, Transparency = 0.3, Anim = "Spin", Speed = -3.2, BoostOn = "Inspect" }, s * 1.3, 0.1, 0.5, L))
                  table.insert(out, { Beam = true, FromOff = V(0, 0, 0.5), FromW = V(s * 1.3 * 0.57, 0.1 * 0.57, 0.5), ToOff = V(s * 0.5, 0.3, -0.5), ToW = V(0, 0, 0),
                      Color = C(220, 150, 255), Width = 0.045, Lightning = true })
              end
              return out
          end)(),
          { { Size = V(0.05, 0.05, 0.9), Off = V(0.25, 0.53, 0), Rot = V(0, 20, 0), Color = C(200, 90, 255), Glow = true, Anim = "Flicker" },
            { Size = V(0.05, 0.05, 0.7), Off = V(-0.2, 0.53, -0.1), Rot = V(0, -30, 0), Color = C(200, 90, 255), Glow = true, Anim = "Flicker" },
            { Size = V(0.9, 0.04, 0.04), Off = V(0, 0.58, -0.4), Color = C(240, 210, 255), Glow = true, Anim = "Flicker", Rate = 9 } }),
      Emit = { { Texture = SMOKE, Color = { C(60, 20, 90), C(10, 0, 20) }, Rate = 6, Size = 0.7, Speed = 0.3, Life = 1.2, Transparency = 0.45 },
               { Texture = SPARK, Color = { C(210, 120, 255) }, Rate = 6, Size = 0.18, Speed = -1.0, Life = 0.4 },
               { Burst = "Fire", Texture = SPARK, Color = { C(220, 150, 255) }, Size = 0.32, Speed = -2, Life = 0.2, Count = 4 },
               { Burst = "Kill", Texture = SMOKE, Color = { C(170, 60, 255), C(20, 0, 40) }, Size = 1.1, Speed = -2, Life = 0.6, Count = 18 } },
      Shock = { Kill = { Kind = "Implode", Color = C(170, 70, 255) } } },
    { Id = "InfernoGauntlets", Name = "Inferno Gauntlets", Rarity = "Mythic", Unlock = "Robux", Price = 799, ProductId = 3716099928,
      Desc = "Basalt plates over rivers of lava, knuckle spikes and a molten core in each forearm. Keep firing and they HEAT UP: the lava blazes, flames roar off the knuckles, the vents smoke. Kills erupt.",
      Base = { Color = C(30, 22, 20), Material = Enum.Material.Slate, Tex = "Lava", TexTile = 0.8, TexHeat = true },
      Parts = Join(
          { Vamb(L, { Color = C(30, 22, 20), Material = Enum.Material.Slate, Tex = "Lava", TexTile = 0.9, TexHeat = true }) },
          Bands(L, C(52, 38, 32), Enum.Material.Basalt, C(255, 110, 30)),
          { { Wedge = true, Uniform = true, Size = V(0.12, 0.2, 0.28), Off = V(0.32, 0.5, -0.5), Color = C(60, 44, 38), Material = METAL, Reflectance = 0.15 },
            { Wedge = true, Uniform = true, Size = V(0.12, 0.22, 0.32), Off = V(0, 0.5, -0.5), Color = C(60, 44, 38), Material = METAL, Reflectance = 0.15 },
            { Wedge = true, Uniform = true, Size = V(0.12, 0.2, 0.28), Off = V(-0.32, 0.5, -0.5), Color = C(60, 44, 38), Material = METAL, Reflectance = 0.15 },
            At({ Size = V(1.24, 0.2, 0.42), Uniform = true, Color = C(52, 36, 30), Material = Enum.Material.Basalt }, 0, 0.95, 0.28, L),
            At({ Size = V(1.24, 0.2, 0.42), Uniform = true, Color = C(48, 34, 28), Material = Enum.Material.Basalt }, 0, 0.92, 0.72, L),
            At({ Size = V(1.26, 0.05, 0.05), Uniform = true, Color = C(255, 120, 30), Glow = true, HeatGlow = true }, 0, 1.08, 0.5, L) },
          (function()
              local out = {}
              for _, s in ipairs({ 1, -1 }) do
                  table.insert(out, At({ Shape = "Ball", Uniform = true, Size = V(0.3, 0.3, 0.3), Color = C(255, 130, 30), Glow = true, HeatGlow = true }, s * 1.12, 0, 0.55, L))
                  table.insert(out, At({ Ring = 6, Radius = 0.22, Thick = 0.07, Axis = "X", Color = C(52, 38, 32), Material = Enum.Material.Basalt }, s * 1.16, 0, 0.55, L))
              end
              return out
          end)()),
      Emit = { { Texture = FIRE, Color = { C(255, 170, 60), C(255, 60, 20) }, Rate = 6, HeatAdd = 28, Size = 0.42, Speed = 0.8, Life = 0.45, Accel = V(0, 2, 0), Off = V(0, 0.3, -0.55) },
               { Texture = SPARK, Color = { C(255, 150, 60) }, Rate = 5, HeatAdd = 20, Size = 0.15, Speed = 1.5, Life = 0.6, Accel = V(0, 2, 0) },
               { Texture = SMOKE, Color = { C(60, 50, 46) }, Rate = 0, HeatAdd = 9, HeatMin = 0.45, Size = 0.7, Speed = 0.6, Life = 1.0, Transparency = 0.5, Accel = V(0, 1.5, 0), Off = V(0, 0.5, 0.5), OffW = V(0, 0.4, 0.9) },
               { Burst = "Fire", Texture = FIRE, Color = { C(255, 200, 80), C(255, 80, 20) }, Size = 0.45, Speed = 2, Life = 0.25, Count = 4, Off = V(0, 0.3, -0.55) },
               { Burst = "Kill", Texture = FIRE, Color = { C(255, 220, 100), C(255, 60, 20) }, Size = 1.0, Speed = 4, Life = 0.6, Count = 22 } },
      Shock = { Kill = { Kind = "Erupt", Color = C(255, 120, 30) } } },
    -- INFERNAL set (2026-10-04): obsidian over hellfire cracks, horn blades along the forearm, a demon eye in each wrist
    { Id = "HellboundTalons", Name = "Hellbound Talons", Rarity = "Mythic", Unlock = "Robux", Price = 799, ProductId = 0, Set = "Infernal",
      -- (v2 2026-10-07: the tailored kit in obsidian + blood + hell-iron, the horns / eyes / claws kept)
      Desc = "Obsidian gauntlets with a blood-red knuckle guard edged in hell-iron, hellfire piping and a demon eye on the back of each hand. Curved horn blades sweep back along your forearms and FLARE when you inspect, a demon eye burns in each wrist with a violet sigil turning around it, and crimson claws tip every finger. Kills erupt in hellfire.",
      Base = { Color = C(20, 12, 20), Material = SMOOTH, Reflectance = 0.16 },
      Parts = OutfitGlove({ GloveStyle = "Claw", Dark = C(20, 12, 20), Main = C(110, 18, 34), Trim = C(74, 40, 50), Glow = C(235, 40, 60), VambLen = L, NoTips = true,
              Emblem = function(off, offW, s) return OE.Orb(off, offW, s, C(255, 60, 70), true, C(160, 70, 255)) end },
          Join(
          (function()
              local out = {}
              -- horn blades: three per side, sweeping back and up along the vambrace; flap a little, flare on kills,
              -- open wide on inspect
              for _, s in ipairs({ 1, -1 }) do
                  for i = 1, 3 do
                      local hornP = { Wedge = true, WedgeFlip = true, Root = 1, Uniform = true, Size = V(0.05, 0.22 - i * 0.04, 0.62 - i * 0.12), Side = s,
                          Color = (i == 1) and C(58, 38, 50) or C(46, 28, 40), Material = SMOOTH, Reflectance = 0.12,
                          Rot = V(-(8 + i * 10), s * (10 + i * 8), 0), Anim = "Flap", Amp = 3, Speed = 1.6, Phase = i * 0.7,
                          FlareOn = "Kill", OpenOn = "Inspect", OpenAng = 28, OpenFor = 1.8 }
                      At(hornP, s * 1.02, 0.35 + (i - 1) * 0.22, 0.2 + (i - 1) * 0.22, L)
                      table.insert(out, hornP)
                      local edge = table.clone(hornP)
                      edge.Wedge, edge.WedgeFlip = nil, nil
                      edge.Size = V(0.055, 0.024, (0.62 - i * 0.12) * 0.96)
                      edge.ShiftW = V(0, -(0.22 - i * 0.04) / 2 + 0.012, 0)
                      edge.Color, edge.Glow = C(235, 40, 60), true
                      table.insert(out, edge)
                  end
                  -- the demon eye: a black orb with a crimson iris, a violet sigil ring turning round it
                  table.insert(out, At({ Shape = "Ball", Uniform = true, Size = V(0.3, 0.3, 0.3), Color = C(8, 2, 8), Material = SMOOTH }, s * 1.22, -0.05, 0.55, L))
                  table.insert(out, At({ Shape = "Ball", Uniform = true, Size = V(0.16, 0.2, 0.16), Color = C(255, 60, 70), Glow = true, Anim = "Pulse", PulseMin = 0, PulseMax = 0.35, Speed = 2.4 }, s * 1.34, -0.05, 0.55, L))
                  table.insert(out, At({ Ring = 10, Radius = 0.26, Thick = 0.03, Axis = "X", Tilt = V(15, 0, 0), Color = C(160, 70, 255), Glow = true, Anim = "Spin", Speed = 2.6 * s, BoostOn = "Inspect" }, s * 1.24, -0.05, 0.55, L))
              end
              return out
          end)(),
          -- crimson claws over the fingertips + a glowing seam across the knuckles
          { { Wedge = true, Uniform = true, Size = V(0.08, 0.14, 0.3), Off = V(0.34, 0.42, -0.62), Rot = V(-20, 0, 0), Color = C(235, 40, 60), Glow = true },
            { Wedge = true, Uniform = true, Size = V(0.08, 0.16, 0.34), Off = V(0.11, 0.44, -0.64), Rot = V(-20, 0, 0), Color = C(235, 40, 60), Glow = true },
            { Wedge = true, Uniform = true, Size = V(0.08, 0.16, 0.34), Off = V(-0.12, 0.44, -0.64), Rot = V(-20, 0, 0), Color = C(235, 40, 60), Glow = true },
            { Wedge = true, Uniform = true, Size = V(0.08, 0.14, 0.3), Off = V(-0.35, 0.42, -0.62), Rot = V(-20, 0, 0), Color = C(235, 40, 60), Glow = true },
            { Size = V(0.9, 0.035, 0.04), Off = V(0, 0.59, -0.32), Color = C(160, 70, 255), Glow = true, Anim = "Pulse", PulseMin = 0, PulseMax = 0.5 } })),
      Emit = { { Texture = FIRE, Color = { C(255, 120, 130), C(235, 40, 60), C(140, 50, 255) }, Rate = 5, Size = 0.32, Speed = 0.5, Life = 0.5, Accel = V(0, 2, 0) },
               { Texture = SPARK, Color = { C(255, 140, 90), C(235, 40, 60) }, Rate = 4, Size = 0.14, Speed = 1.0, Life = 0.7, Accel = V(0, 1.5, 0) },
               { Burst = "Fire", Texture = SPARK, Color = { C(255, 150, 150) }, Size = 0.3, Speed = 2, Life = 0.2, Count = 4 },
               { Burst = "Kill", Texture = FIRE, Color = { C(255, 140, 150), C(235, 40, 60), C(140, 50, 255) }, Size = 1.0, Speed = 4, Life = 0.6, Count = 22 },
               { Burst = "Inspect", Texture = SPARK, Color = { C(200, 140, 255) }, Size = 0.25, Speed = 1.5, Life = 0.6, Count = 12 } },
      Shock = { Kill = { Kind = "Erupt", Color = C(235, 40, 60) } } },
    { Id = "PrismShift", Name = "Prism Shift", Rarity = "Mythic", Unlock = "Robux", Price = 699, ProductId = 3716099936,
      Desc = "Holographic chrome that flows through every colour. Five crystal shards orbit the wrist with beams of light refracting between them; kills blow the shards outward in a rainbow nova.",
      Base = { Color = C(220, 225, 235), Material = METAL, Reflectance = 0.5, Anim = "Rainbow", Tex = "Holo", TexTile = 1.0, TexT = 0.35, TexScroll = V2(0.08, 0.04) },
      Parts = Join(
          { Vamb(L, { Color = C(225, 228, 238), Material = METAL, Reflectance = 0.45, Tex = "Holo", TexTile = 1.0, TexT = 0.3, TexScroll = V2(-0.08, 0.05) }) },
          { At({ Size = V(1.22, 1.22, 0.05), Uniform = true, Color = C(255, 255, 255), Glow = true, Anim = "Rainbow" }, 0, 0, 0.06, L),
            At({ Size = V(1.22, 1.22, 0.05), Uniform = true, Color = C(255, 255, 255), Glow = true, Anim = "Rainbow", Phase = 0.5 }, 0, 0, 0.94, L),
            { Size = V(1.08, 1.08, 0.12), Off = V(0, 0, -0.44), Color = C(255, 255, 255), Glow = true, Anim = "Rainbow", Phase = 0.25 } },
          (function()
              local out = {}
              for i = 0, 4 do
                  table.insert(out, { Tag = "Shard" .. i, Uniform = true, Size = V(0.13, 0.36, 0.13), Off = V(0, 0, 0.5), OffW = V(0.95, 0, 0.1), Rot = V(0, 0, 25),
                      Color = C(255, 255, 255), Material = GLASS, Transparency = 0.1, Reflectance = 0.3, Anim = "SpinOrbit", Speed = 1.8, Phase = i * 1.2566, BurstOn = "Kill", BoostOn = "Inspect" })
              end
              for i = 0, 4 do
                  table.insert(out, { Beam = true, LinkA = "Shard" .. i, LinkB = "Shard" .. ((i + 1) % 5), Color = Color3.fromHSV(i / 5, 0.7, 1), Width = 0.025, Transparency = 0.25, Flow = true })
              end
              return out
          end)()),
      Emit = { { Texture = SPARK, Color = "Rainbow", Rate = 9, Size = 0.28, Speed = 0.6, Life = 0.8 },
               { Burst = "Kill", Texture = SPARK, Color = "Rainbow", Size = 0.8, Speed = 4, Life = 0.7, Count = 26 } },
      Shock = { Kill = { Kind = "Nova", Color = "Rainbow" } } },
    { Id = "ArcPulse", Name = "Arc Pulse", Rarity = "Legendary", Unlock = "Robux", Price = 499, ProductId = 3716099945,
      Desc = "Tech gauntlets with data streaming through their circuits, a live AMMO holo-display on your forearm and an electric arc crackling between your hands.",
      Base = { Color = C(36, 40, 50), Material = METAL, Reflectance = 0.1, Tex = "Circuit", TexTile = 0.8, TexScroll = V2(0, 0.25) },
      Arc = { Color = C(120, 240, 255), Width = 0.03 },
      Parts = Join(
          { Vamb(L, { Color = C(32, 36, 46), Material = METAL, Reflectance = 0.12, Tex = "Circuit", TexTile = 0.8, TexScroll = V2(0, -0.25) }) },
          Bands(L, C(60, 66, 80), METAL, C(60, 240, 255)),
          { At({ Holo = true, Uniform = true, Size = V(0.86, 0.02, 0.66), Rot = V(12, 0, 0), Color = C(60, 240, 255) }, 0, 1.12, 0.5, L),
            At({ Size = V(0.06, 0.06, 0.06), Uniform = true, Color = C(60, 240, 255), Glow = true, Anim = "Pulse" }, 1.0, 1.0, 0.08, L),
            At({ Size = V(0.06, 0.06, 0.06), Uniform = true, Color = C(60, 240, 255), Glow = true, Anim = "Pulse" }, -1.0, 1.0, 0.08, L),
            At({ Size = V(0.04, 0.04, 0.2), Uniform = true, Color = C(60, 240, 255), Glow = true, Anim = "Chase", Index = 1 }, 1.02, 0.3, 0.2, L),
            At({ Size = V(0.04, 0.04, 0.2), Uniform = true, Color = C(60, 240, 255), Glow = true, Anim = "Chase", Index = 2 }, 1.02, 0.3, 0.5, L),
            At({ Size = V(0.04, 0.04, 0.2), Uniform = true, Color = C(60, 240, 255), Glow = true, Anim = "Chase", Index = 3 }, 1.02, 0.3, 0.8, L),
            At({ Size = V(0.04, 0.04, 0.2), Uniform = true, Color = C(60, 240, 255), Glow = true, Anim = "Chase", Index = 1 }, -1.02, 0.3, 0.2, L),
            At({ Size = V(0.04, 0.04, 0.2), Uniform = true, Color = C(60, 240, 255), Glow = true, Anim = "Chase", Index = 2 }, -1.02, 0.3, 0.5, L),
            At({ Size = V(0.04, 0.04, 0.2), Uniform = true, Color = C(60, 240, 255), Glow = true, Anim = "Chase", Index = 3 }, -1.02, 0.3, 0.8, L),
            { Ring = 8, Radius = 0.75, Thick = 0.04, Off = V(0, 0, 0.5), OffW = V(0, 0, 0), Color = C(60, 240, 255), Glow = true, Transparency = 0.3, Anim = "Spin", Speed = -2.4, BoostOn = "Inspect" },
            { Size = V(0.05, 0.05, 0.25), Off = V(0, 0.54, -0.4), Color = C(60, 240, 255), Glow = true, Anim = "Chase", Index = 1 },
            { Size = V(0.05, 0.05, 0.25), Off = V(0, 0.54, -0.1), Color = C(60, 240, 255), Glow = true, Anim = "Chase", Index = 2 } }),
      Emit = { { Burst = "Fire", Texture = SPARK, Color = { C(120, 250, 255) }, Size = 0.28, Speed = 2, Life = 0.2, Count = 4 },
               { Burst = "Kill", Texture = SPARK, Color = { C(60, 240, 255), C(255, 255, 255) }, Size = 0.6, Speed = 3.5, Life = 0.5, Count = 16 } },
      Shock = { Kill = { Kind = "Nova", Color = C(60, 240, 255) } } },
}

-- ==================== SLEEVES ====================
-- ===== SLEEVE KIT (2026-10-04, owner: "the sleeves all feel incredibly lazy and low quality ... textures bug out") =====
-- On the arm block: X / Y = its width, Z = its length (-0.5 = the wrist end, the part you see in first person). Every
-- layer stands clearly off the block (GloveFX.Place also pushes any band to >= 8%), so nothing shares a face with it.
local function SCuff(color, mat, accent, glow)
    local t = {
        { Size = V(1.16, 1.16, 0.05), Off = V(0, 0, -0.475), Color = color, Material = mat or METAL, Reflectance = (mat == FABRIC) and 0 or 0.22 },
        { Size = V(1.13, 1.13, 0.028), Off = V(0, 0, -0.41), Color = color, Material = mat or METAL, Reflectance = (mat == FABRIC) and 0 or 0.22 },
    }
    if accent then
        table.insert(t, { Size = V(1.19, 1.19, 0.012), Off = V(0, 0, -0.446), Color = accent, Glow = glow or nil, Material = (not glow) and METAL or nil,
            Reflectance = (not glow) and 0.35 or nil, Anim = glow and "Pulse" or nil, PulseMin = 0, PulseMax = 0.45 })
    end
    return t
end
-- lamellar plates over the top and both sides of the forearm, overlapping like armour scales, cuff -> elbow
local function SPlates(n, color, mat, refl, edgeColor, edgeGlow)
    local out = {}
    for i = 0, n - 1 do
        local z = -0.355 + i * 0.09
        local tilt = -7
        table.insert(out, { Size = V(1.12, 0.16, 0.08), Off = V(0, 0.5, z), Rot = V(tilt, 0, 0), Color = color, Material = mat or METAL, Reflectance = refl or 0.12 })
        for _, sx in ipairs({ -1, 1 }) do
            table.insert(out, { Size = V(0.16, 0.86, 0.08), Off = V(sx * 0.5, 0.04, z), Rot = V(tilt, 0, 0), Color = color, Material = mat or METAL, Reflectance = refl or 0.12 })
        end
        if edgeColor then
            table.insert(out, { Size = V(1.14, 0.05, 0.014), Off = V(0, 0.56, z - 0.035), Color = edgeColor, Glow = edgeGlow or nil, Material = (not edgeGlow) and METAL or nil,
                Anim = edgeGlow and "Pulse" or nil, PulseMin = 0, PulseMax = 0.5, Speed = 1.6, Phase = i * 0.6 })
        end
    end
    return out
end
-- rivets on the plates' corners (uniform cubes)
local function SRivets(n, color)
    local out = {}
    for i = 0, n - 1 do
        for _, sx in ipairs({ -1, 1 }) do
            table.insert(out, { Uniform = true, Size = V(0.07, 0.05, 0.07), Off = V(sx * 0.4, 0.58, -0.355 + i * 0.09), Color = color, Material = METAL, Reflectance = 0.4 })
        end
    end
    return out
end
-- stitched seams down the outer sides / along the top
local function SSeams(color, glow)
    return {
        { Size = V(1.1, 0.035, 0.86), Off = V(0, 0.18, 0.06), Color = color, Glow = glow or nil, Material = (not glow) and FABRIC or nil },
        { Size = V(0.035, 1.1, 0.86), Off = V(0.28, 0, 0.06), Color = color, Glow = glow or nil, Material = (not glow) and FABRIC or nil },
    }
end
GloveFX.SleeveKit = { Cuff = SCuff, Plates = SPlates, Rivets = SRivets, Seams = SSeams }


GloveFX.Sleeves = {
    { Id = "Standard", Name = "Standard Issue", Rarity = "Common", Unlock = "Free", Desc = "Dark combat sleeves with a ribbed cuff and taped seams.",
      Parts = Join(SCuff(C(28, 30, 34), FABRIC), SSeams(C(46, 50, 58))) },
    { Id = "Urban", Name = "Urban Camo", Rarity = "Uncommon", Unlock = "Level", Level = 5, Desc = "Grey urban camouflage with a strapped cuff and a utility pocket.",
      Base = { Color = C(92, 96, 102), Material = FABRIC },
      Parts = Join(
          { { Size = V(1.1, 0.5, 0.18), Off = V(0.1, 0.3, -0.2), Color = C(60, 62, 68), Material = FABRIC },
            { Size = V(1.1, 0.4, 0.14), Off = V(-0.1, -0.2, 0.15), Color = C(130, 132, 136), Material = FABRIC },
            { Size = V(0.6, 1.1, 0.16), Off = V(-0.15, 0.1, -0.05), Color = C(72, 74, 80), Material = FABRIC },
            -- the utility pocket on the outer side: a patch, its flap and a press stud
            { Size = V(1.14, 0.5, 0.2), Off = V(0, -0.05, -0.22), Color = C(70, 72, 78), Material = FABRIC },
            { Size = V(1.17, 0.18, 0.21), Off = V(0, 0.16, -0.22), Color = C(56, 58, 64), Material = FABRIC },
            { Uniform = true, Size = V(0.09, 0.09, 0.05), Off = V(0, 0.16, -0.22), OffW = V(0.6, 0, 0), Color = C(150, 150, 156), Material = METAL, Reflectance = 0.3 } },
          SCuff(C(36, 38, 42), FABRIC),
          { { Uniform = true, Size = V(0.22, 0.12, 0.1), Off = V(0, 0.5, -0.46), OffW = V(0, 0.07, 0), Color = C(140, 142, 148), Material = METAL, Reflectance = 0.35 } }, -- the strap's buckle
          SSeams(C(66, 68, 74))) },
    { Id = "Crimson", Name = "Crimson Guard", Rarity = "Rare", Unlock = "Level", Level = 15, Desc = "Deep red cloth under blackened lamellar plates, gold rivets and a banded black cuff.",
      Base = { Color = C(130, 24, 32), Material = FABRIC },
      Parts = Join(SPlates(4, C(24, 22, 26), METAL, 0.18), SRivets(4, C(214, 170, 80)), SCuff(C(20, 20, 22), METAL, C(214, 170, 80))) },
    { Id = "RoyalPearl", Name = "Royal Pearl", Rarity = "Legendary", Unlock = "Robux", Price = 299, ProductId = 3716099960, Desc = "Pearl silk embroidered with gold filigree, gold diamond inlays, pearl studs and a polished gold cuff with a glowing seam.",
      Base = { Color = PEARL, Material = SMOOTH, Reflectance = 0.05, Tex = "Filigree", TexTile = 0.9 },
      Parts = Join(
          SCuff(GOLD, METAL, C(255, 236, 170), true),
          (function()
              local out = {}
              for i = 0, 2 do
                  local z = -0.32 + i * 0.12
                  table.insert(out, { Uniform = true, Size = V(0.32, 0.05, 0.32), Off = V(0, 0.5, z), Rot = V(0, 45, 0), Color = GOLD, Material = METAL, Reflectance = 0.35 })
                  table.insert(out, { Uniform = true, Size = V(0.18, 0.07, 0.18), Off = V(0, 0.5, z), Rot = V(0, 45, 0), Color = PEARL, Material = SMOOTH, Reflectance = 0.15 })
                  for _, sx in ipairs({ -1, 1 }) do
                      table.insert(out, { Shape = "Ball", Uniform = true, Size = V(0.1, 0.1, 0.1), Off = V(sx * 0.5, 0.2, z), Color = C(244, 240, 232), Material = SMOOTH, Reflectance = 0.25 })
                  end
              end
              return out
          end)(),
          { { Size = V(0.05, 1.12, 0.86), Off = V(0, 0, 0.06), Color = GOLD, Glow = true, Anim = "Pulse", PulseMin = 0.2, PulseMax = 0.55 } }) },
    { Id = "VoidSilk", Name = "Void Silk", Rarity = "Mythic", Unlock = "Robux", Price = 399, ProductId = 3716099967, Desc = "Midnight silk with a living starfield drifting through it, two rune rings turning round the forearm and motes of void light.",
      Base = { Color = C(22, 12, 38), Material = FABRIC, Tex = "Stars", TexTile = 1.2, TexScroll = V2(0.03, 0.08) },
      Parts = Join(
          SCuff(C(30, 20, 54), METAL, C(190, 110, 255), true),
          { { Ring = 10, Radius = 0.92, Thick = 0.07, Axis = "Z", Off = V(0, 0, -0.3), Color = C(190, 110, 255), Glow = true, Anim = "Spin", Speed = 1.4 },
            { Ring = 8, Radius = 0.86, Thick = 0.05, Axis = "Z", Off = V(0, 0, -0.12), Tilt = V(12, 0, 0), Color = C(120, 200, 255), Glow = true, Anim = "Spin", Speed = -1.0 } },
          SSeams(C(190, 110, 255), true)),
      Emit = { { Texture = SPARK, Color = { C(200, 140, 255) }, Rate = 5, Size = 0.2, Speed = 0.3, Life = 1.2 } } },
    { Id = "Emberweave", Name = "Emberweave", Rarity = "Mythic", Unlock = "Robux", Price = 399, ProductId = 3716099977, Desc = "Charcoal weave over smouldering lava seams, charred plates glowing at the gaps, shedding embers.",
      Base = { Color = C(26, 22, 22), Material = FABRIC, Tex = "Lava", TexTile = 1.4, TexT = 0.45, TexScroll = V2(0, 0.06) },
      Parts = Join(SPlates(4, C(30, 24, 22), SMOOTH, 0, C(255, 110, 30), true), SCuff(C(34, 28, 26), METAL, C(255, 110, 30), true)),
      Emit = { { Texture = SPARK, Color = { C(255, 150, 60) }, Rate = 6, Size = 0.18, Speed = 0.8, Life = 0.9, Accel = V(0, 1.5, 0) } } },
    { Id = "Hellbound", Name = "Hellbound Sleeves", Rarity = "Mythic", Unlock = "Robux", Price = 399, ProductId = 0, Set = "Infernal",
      Desc = "A tailored obsidian sleeve with faint hellfire cracks, blood-red guard plates edged in hell-iron with a ridge of horns rising off them, hellfire piping, a strapped buckle and a cuff carrying a demon-eye medallion, made to match the Infernal set.",
      Base = { Color = C(26, 12, 18), Material = FABRIC, Tex = "Infernal", TexTile = 1.1, TexT = 0.6, TexScroll = V2(0, 0.05) },
      Parts = OutfitSleeve({ Style = "Scaled", Dark = C(26, 12, 18), Main = C(110, 18, 34), Trim = C(74, 40, 50), Glow = C(235, 40, 60),
              Emblem = function(off, offW, s) return OE.Orb(off, offW, s, C(255, 60, 70), true, C(160, 70, 255)) end },
          (function()
              local out = {}
              -- the horn ridge: three curved spines standing up off the plates, shrinking toward the elbow
              for i = 0, 2 do
                  local h = 0.22 - i * 0.05
                  table.insert(out, { Wedge = true, Size = V(0.08, h * 1.6, 0.06), Off = V(0, 0.58 + h * 0.8, -0.27 + i * 0.13), Rot = V(-18, 0, 0), Color = C(58, 38, 50), Material = SMOOTH, Reflectance = 0.06 })
              end
              return out
          end)()),
      Emit = { { Texture = SPARK, Color = { C(255, 140, 90), C(235, 40, 60) }, Rate = 5, Size = 0.16, Speed = 0.6, Life = 0.9, Accel = V(0, 1.5, 0) } } },
    { Id = "Seraphim", Name = "Seraphim Sleeves", Rarity = "Mythic", Unlock = "Robux", Price = 399, ProductId = 3716099987, Desc = "A tailored pearl-silk sleeve with faint gold filigree, polished gold guard plates, pale-gold piping, layered golden feathers that stir as you move, a strapped gold buckle and a cuff carrying a star medallion inside a turning halo, made to match the Seraphim set.",
      Base = { Color = PEARL, Material = SMOOTH, Tex = "Filigree", TexTile = 0.9, TexT = 0.6 },
      Parts = OutfitSleeve({ Style = "Flowing", Dark = PEARL, Dark2 = C(190, 184, 172), Main = GOLDMETAL, MainMat = METAL, Main2 = C(176, 136, 60), Trim = PALEGOLD, Glow = PALEGOLD,
              Emblem = function(off, offW, s) return OE.Star(off, offW, s, GOLD, true) end },
          Join((function()
              local out = {}
              -- feathers: three overlapping gold vanes on each side, sweeping back toward the elbow (outside the side panels)
              for _, sx in ipairs({ -1, 1 }) do
                  for i = 0, 2 do
                      table.insert(out, { Wedge = true, Size = V(0.05, 0.5 - i * 0.07, 0.26), Off = V(sx * 0.585, 0.12 + i * 0.05, -0.24 + i * 0.13), Rot = V(-10, 0, 0),
                          Color = (i % 2 == 0) and GOLD or C(246, 214, 140), Material = METAL, Reflectance = 0.3, Anim = "Flap", Amp = 4, Speed = 1.8, Phase = i * 0.8, Side = sx })
                  end
              end
              return out
          end)(),
          { { Ring = 12, Radius = 0.9, Thick = 0.06, Axis = "Z", Off = V(0, 0, -0.5), OffW = V(0, 0, -0.05), Color = GOLD, Material = METAL, Reflectance = 0.35, Anim = "Spin", Speed = 0.8 } })),
      Emit = { { Texture = SPARK, Color = { C(255, 240, 200) }, Rate = 3, Size = 0.18, Speed = 0.2, Life = 0.9 } } },
}

-- every SkinSets set's glove + sleeve: set.Glove(K) / set.Sleeve(K) -> an entry like the ones above, built from this kit
-- (its own textures go in set.Art = { Key = "rbxassetid://..." } and are looked up like every other Tex key)
do
    local K = { Join = Join, At = At, Vamb = Vamb, Bands = Bands, Star = Star, SleeveKit = GloveFX.SleeveKit, Outfit = GloveFX.OutfitKit, C = C, V = V, V2 = V2,
        SPARK = SPARK, SMOKE = SMOKE, FIRE = FIRE, NEON = NEON, METAL = METAL, FABRIC = FABRIC, GLASS = GLASS, SMOOTH = SMOOTH, L = L }
    local okS, SkinFX = pcall(require, script.Parent:WaitForChild("SkinFX"))
    GloveFX.SetKit = K -- (0.93: colourway copies of a set build their glove / sleeve from the same kit)
    for _, set in ipairs(okS and SkinFX.SetOrder or {}) do
        for k, id in pairs(set.Art or {}) do if Art[k] == nil then Art[k] = id end end
        for _, pair in ipairs({ { set.Glove, GloveFX.Gloves }, { set.Sleeve, GloveFX.Sleeves } }) do
            if type(pair[1]) == "function" then
                local ok, e = pcall(pair[1], K)
                if ok and type(e) == "table" then
                    e.Set = e.Set or set.Kind
                    e.Rarity = e.Rarity or "Mythic"
                    e.Unlock = e.Unlock or "Robux"
                    e.ProductId = e.ProductId or 0
                    table.insert(pair[2], e)
                elseif not ok then
                    warn("[GloveFX] " .. set.Kind .. ": " .. tostring(e))
                end
            end
        end
    end
end
-- (Update 5 SKINS V3: the old premium / boss-drop gloves and sleeves are RETIRED -- out of the catalog, the store, the
-- locker and every look; their definitions above stay dormant. Backup: git tag skins-v2-backup, archive/skins_v2/. An old
-- save that wears one falls back to the default look (GloveFor / SleeveFor return nil). Kept: the free + level items.)
GloveFX.RETIRED_V2 = { CelestialFury = true, Voidrend = true, InfernoGauntlets = true, HellboundTalons = true, PrismShift = true,
    ArcPulse = true, SeraphGrips = true, ChronoGauntlets = true, EchoWraps = true, ForgeheartGrips = true, Titanbreakers = true,
    RoyalPearl = true, VoidSilk = true, Emberweave = true, Hellbound = true, Seraphim = true }
for _, list in ipairs({ GloveFX.Gloves, GloveFX.Sleeves }) do
    for i = #list, 1, -1 do if GloveFX.RETIRED_V2[list[i].Id] then table.remove(list, i) end end
end
GloveFX.GloveById, GloveFX.SleeveById = {}, {}
for _, g in ipairs(GloveFX.Gloves) do GloveFX.GloveById[g.Id] = g end
for _, s in ipairs(GloveFX.Sleeves) do GloveFX.SleeveById[s.Id] = s end

-- the equipped glove / sleeve (generic cosmetics storage); nil = the default look
-- (0.93 COLORWAYS) "TempestGauntlets#2" = the same glove built by the set's recoloured copy (SkinFX.Sets["Tempest#2"]);
-- the server tags world shells with that id (LookId), so every client dresses the recoloured one
do
    local Colorways = require(script.Parent:WaitForChild("Colorways"))
    local function Variant(byId: any, fnName: string, key: any): any
        if type(key) ~= "string" then return nil end
        local id, v = string.match(key, "^(.-)#(%d+)$")
        local base = id and rawget(byId, id)
        v = tonumber(v)
        if not (base and v and v > 1 and base.Set and Colorways.Has(base.Set)) then return nil end
        local okS, SkinFX = pcall(require, script.Parent:WaitForChild("SkinFX"))
        local set = okS and SkinFX.Sets[base.Set .. "#" .. v]
        if not (set and type(set[fnName]) == "function" and GloveFX.SetKit) then return nil end
        -- (the set builds its glove with the kit's C: the copy's kit maps it through the colourway too)
        local kit = table.clone(GloveFX.SetKit)
        kit.C = Colorways.C3For(base.Set, v)
        local ok, e = pcall(set[fnName], kit)
        if not ok or type(e) ~= "table" then return nil end
        e.Set, e.Rarity, e.Unlock, e.ProductId, e.Price = base.Set, base.Rarity, base.Unlock, base.ProductId, base.Price
        e.BaseId, e.Variant, e.Id = base.Id, v, key
        return e
    end
    setmetatable(GloveFX.GloveById, { __index = function(t, k) local e = Variant(t, "Glove", k); rawset(t, k, e or false); return e or nil end })
    setmetatable(GloveFX.SleeveById, { __index = function(t, k) local e = Variant(t, "Sleeve", k); rawset(t, k, e or false); return e or nil end })
    GloveFX.WithColorway = function(state: any, def: any, cat: string): any
        if not (def and def.Set and Colorways.Has(def.Set)) then return def end
        local v = Colorways.VariantFor(state, def.Set, cat .. ":" .. def.Id)
        if v <= 1 then return def end
        local alt = (cat == "Sleeve" and GloveFX.SleeveById or GloveFX.GloveById)[def.Id .. "#" .. v]
        return alt or def
    end
end
function GloveFX.GloveFor(state: any): any
    local eq = type(state) == "table" and type(state.CosmeticsEquipped) == "table" and state.CosmeticsEquipped.Glove
    local g = GloveFX.GloveById[eq or ""]
    return (g and g.Base) and GloveFX.WithColorway(state, g, "Glove") or nil
end
-- first person: no glove equipped = the free black Tactical gloves (owner: arms "look horrific" -- the bare default fist
-- was a pale block); picking Bare Hands keeps your skin
function GloveFX.ViewGloveFor(state: any): any
    local g = GloveFX.GloveFor(state)
    if g then return g end
    local eq = type(state) == "table" and type(state.CosmeticsEquipped) == "table" and state.CosmeticsEquipped.Glove
    if eq == "BareHands" then return nil end
    return GloveFX.GloveById.Tactical
end
function GloveFX.SleeveFor(state: any): any
    local eq = type(state) == "table" and type(state.CosmeticsEquipped) == "table" and state.CosmeticsEquipped.Sleeve
    local s = GloveFX.SleeveById[eq or ""]
    return (s and s.Base) and GloveFX.WithColorway(state, s, "Sleeve") or nil
end

-- the first-person holo-display text (the client sets it: ammo); third-person holos show a scrolling readout
GloveFX.LocalHolo = { Big = "--", Sub = "AMMO", Frac = 1 }

-- ==================== building ====================
local function ColorSeq(c)
    if c == "Rainbow" then
        return ColorSequence.new({ ColorSequenceKeypoint.new(0, C(255, 80, 80)), ColorSequenceKeypoint.new(0.33, C(80, 255, 120)),
            ColorSequenceKeypoint.new(0.66, C(80, 140, 255)), ColorSequenceKeypoint.new(1, C(255, 80, 220)) })
    end
    if #c == 1 then return ColorSequence.new(c[1]) end
    return ColorSequence.new(c[1], c[2])
end

-- seamless texture on all six faces of a part (tile = studs per tile)
local FACES = { Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Front, Enum.NormalId.Back }
local function ApplyTex(part: BasePart, key: string?, tile: number, transparency: number?, color: Color3?)
    for _, t in ipairs(part:GetChildren()) do if t.Name == "GloveTex" then t:Destroy() end end
    local id = key and Art[key]
    if not id then return {} end
    local out = {}
    for _, f in ipairs(FACES) do
        local t = Instance.new("Texture")
        t.Name = "GloveTex"
        t.Texture = id
        t.Face = f
        t.StudsPerTileU, t.StudsPerTileV = tile, tile
        t.Transparency = transparency or 0
        if color then t.Color3 = color end
        t.Parent = part
        table.insert(out, t)
    end
    return out
end
GloveFX.ApplyTex = ApplyTex

local AXIS = { Z = CFrame.identity, X = CFrame.Angles(0, math.pi / 2, 0), Y = CFrame.Angles(math.pi / 2, 0, 0) }
local function Rot(v) return v and CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z)) or CFrame.identity end

-- Build a look's decorations + emitters for an owner part (hand / arm block, or a character's shell).
-- scale = studs per unit of particle size (about the owner's width); parent = where the parts go.
-- Returns a dressing { Owner, Def, Parts, Emitters, Bursts, Beams, ... } for Place / Event / Clear.
function GloveFX.Dress(def: any, owner: BasePart, parent: Instance, scale: number): any
    local d = { Owner = owner, Def = def, Parts = {}, Emitters = {}, Bursts = {}, Beams = {}, Atts = {}, Guis = {}, Ev = {}, Heat = 0,
        Parent = parent, Scale = scale, Tagged = {}, BulkP = {}, BulkC = {}, HeatEmit = {} }
    if not def then return d end
    local function NewPart(pd)
        -- (SKINS V3, gate C4) a sculpted MESH piece: Mesh = "<Kind>/<Piece>" clones WeaponAssets.ArmsModels.<Kind>.<Piece>
        -- (its painted SurfaceAppearance kept; MeshV = the set's colourway -> its _V<v> maps), placed + sized like any part
        if pd.Mesh then
            local kind, piece = string.match(pd.Mesh, "^(.-)/(.+)$")
            local wa = game.ReplicatedStorage:WaitForChild("AimRngShared"):FindFirstChild("WeaponAssets")
            local f = wa and wa:FindFirstChild("ArmsModels")
            local src = f and kind and f:FindFirstChild(kind) and f[kind]:FindFirstChild(piece)
            if src then
                local p = src:Clone()
                p.Name = "GloveDeco"
                p.Anchored = true
                p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
                if pd.Glow then p.Material = NEON; p.Color = pd.Color or p.Color; for _, sa in ipairs(p:GetChildren()) do if sa:IsA("SurfaceAppearance") then sa:Destroy() end end end
                p.Transparency = pd.Transparency or 0
                if (pd.MeshV or 1) > 1 then
                    local okS, SkinFX = pcall(require, script.Parent:WaitForChild("SkinFX"))
                    if okS and SkinFX.V3Swap then SkinFX.V3Swap(p, pd.MeshV) end
                end
                p.Size = V(0.05, 0.05, 0.05)
                p.Parent = parent
                return p
            end
        end
        local p = Instance.new(pd.Wedge and "WedgePart" or "Part")
        if pd.Shape == "Cylinder" then p.Shape = Enum.PartType.Cylinder elseif pd.Shape == "Ball" then p.Shape = Enum.PartType.Ball end
        p.Name = "GloveDeco"
        p.Anchored = true
        p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
        p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        p.Color = pd.Color or C(200, 200, 200)
        p.Material = pd.Glow and NEON or (pd.Material or SMOOTH)
        -- (Glass is drawn in the transparent pass: textured glass layers over a textured arm sort-flickered. Polished
        -- plastic reads the same here.)
        if p.Material == GLASS then p.Material = SMOOTH; p.Reflectance = math.max(pd.Reflectance or 0, 0.18) end
        p.Reflectance = pd.Reflectance or 0
        p.Transparency = pd.Transparency or 0
        p.Size = V(0.05, 0.05, 0.05)
        p.Parent = parent
        return p
    end
    local function Add(pd, extra)
        local p = NewPart(pd)
        -- Eps: every part a hair bigger than the last (0.4-2.8%), so no two layers ever share a face exactly -- the
        -- vambrace, its bands and trims and the arm block's end all lined up and flickered (owner 2026-10-04: "sleeves
        -- are still flickering")
        local e = { Part = p, Def = pd, BaseT = p.Transparency, Eps = 1 + ((#d.Parts % 7) + 1) * 0.004 }
        if extra then for k, v in pairs(extra) do e[k] = v end end
        if pd.Tex then e.Tex = ApplyTex(p, pd.Tex, 1, pd.TexT, pd.TexColor) end
        if pd.Tag then d.Tagged[pd.Tag] = p end
        table.insert(d.Parts, e)
        return e
    end
    for _, pd in ipairs(def.Parts or {}) do
        if pd.Ring then
            local chord = 2 * math.pi * pd.Radius / pd.Ring * 1.12
            for i = 0, pd.Ring - 1 do
                Add(pd, { RingAngle = i / pd.Ring * 360, Chord = chord })
                if pd.Teeth then Add(pd, { RingAngle = (i + 0.5) / pd.Ring * 360, Tooth = true }) end
            end
        elseif pd.Beam then
            table.insert(d.Beams, { Def = pd })
        elseif pd.Holo then
            local e = Add({ Uniform = true, Size = pd.Size, Off = pd.Off, OffW = pd.OffW, Rot = pd.Rot, Color = pd.Color, Glow = true, Transparency = 0.82, Anim = pd.Anim })
            local gui = Instance.new("SurfaceGui")
            gui.Face = Enum.NormalId.Top
            gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
            gui.CanvasSize = V2(240, 184)
            gui.LightInfluence = 0
            gui.Brightness = 2.2
            gui.AlwaysOnTop = false
            local big = Instance.new("TextLabel")
            big.Name = "Big"; big.BackgroundTransparency = 1; big.Size = UDim2.new(1, 0, 0.62, 0); big.Position = UDim2.fromScale(0, 0.06)
            big.FontFace = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Bold); big.TextScaled = true
            big.TextColor3 = pd.Color; big.Text = "--"; big.Parent = gui
            local sub = Instance.new("TextLabel")
            sub.Name = "Sub"; sub.BackgroundTransparency = 1; sub.Size = UDim2.new(1, 0, 0.18, 0); sub.Position = UDim2.fromScale(0, 0.66)
            sub.FontFace = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Regular); sub.TextScaled = true
            sub.TextColor3 = pd.Color; sub.Text = "AMMO"; sub.Parent = gui
            local barBg = Instance.new("Frame")
            barBg.BackgroundColor3 = pd.Color; barBg.BackgroundTransparency = 0.75; barBg.BorderSizePixel = 0
            barBg.Size = UDim2.new(0.84, 0, 0.06, 0); barBg.Position = UDim2.fromScale(0.08, 0.88); barBg.Parent = gui
            local bar = Instance.new("Frame")
            bar.Name = "Bar"; bar.BackgroundColor3 = pd.Color; bar.BorderSizePixel = 0; bar.Size = UDim2.fromScale(1, 1); bar.Parent = barBg
            gui.Adornee = e.Part
            gui.Parent = e.Part
            e.Holo = { Gui = gui, Big = big, Sub = sub, Bar = bar }
            table.insert(d.Guis, gui)
        elseif pd.Rays then
            local att = Instance.new("Attachment"); att.Name = "GloveRays"; att.Parent = owner
            local bb = Instance.new("BillboardGui")
            bb.LightInfluence = 0; bb.AlwaysOnTop = false; bb.Size = UDim2.fromScale(1, 1); bb.Adornee = att
            local img = Instance.new("ImageLabel")
            img.BackgroundTransparency = 1; img.Size = UDim2.fromScale(1, 1); img.Image = Art.Rays; img.ImageColor3 = pd.Color or PALEGOLD
            img.ImageTransparency = 1; img.Parent = bb
            bb.Parent = att
            table.insert(d.Parts, { Def = pd, RaysAtt = att, RaysGui = bb, RaysImg = img })
            table.insert(d.Guis, bb)
        else
            Add(pd)
        end
    end
    -- beams: between two points of the owner (FromOff/FromW, ToOff/ToW), or between two tagged parts (LinkA / LinkB)
    for _, b in ipairs(d.Beams) do
        local bd = b.Def
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        if bd.LinkA then
            a0.Parent = d.Tagged[bd.LinkA] or owner
            a1.Parent = d.Tagged[bd.LinkB] or owner
        else
            a0.Parent, a1.Parent = owner, owner
            b.Moving = true
        end
        local beam = Instance.new("Beam")
        beam.Attachment0, beam.Attachment1 = a0, a1
        beam.Color = ColorSequence.new(bd.Color or C(255, 255, 255))
        beam.LightEmission = 1
        beam.LightInfluence = 0
        beam.FaceCamera = true
        beam.Segments = bd.Lightning and 6 or 2
        beam.Texture = bd.Flow and SPARK or ""
        beam.TextureMode = Enum.TextureMode.Wrap
        beam.TextureLength = 0.3
        beam.TextureSpeed = bd.Flow and 1.5 or 0
        beam.Transparency = NumberSequence.new(bd.Transparency or 0)
        beam.Parent = owner
        b.A0, b.A1, b.Beam = a0, a1, beam
        table.insert(d.Atts, a0); table.insert(d.Atts, a1)
    end
    -- emitters: on the owner's centre, or on their own attachment (Off / OffW)
    local att = Instance.new("Attachment")
    att.Name = "GloveFX"
    att.Parent = owner
    d.Attachment = att
    for _, ed in ipairs(def.Emit or {}) do
        local host = att
        if ed.Off or ed.OffW then
            host = Instance.new("Attachment"); host.Name = "GloveEmit"; host.Parent = owner
            table.insert(d.Atts, host)
            table.insert(d.Parts, { Def = { EmitAt = true, Off = ed.Off, OffW = ed.OffW }, EmitAtt = host })
        end
        local pe = Instance.new("ParticleEmitter")
        pe.Texture = ed.Texture or SPARK
        pe.Color = ColorSeq(ed.Color or { C(255, 255, 255) })
        pe.LightEmission = ed.LightEmission or 1
        pe.LightInfluence = 0
        local sz = (ed.Size or 0.3) * scale
        pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, sz), NumberSequenceKeypoint.new(1, 0) })
        pe.Transparency = NumberSequence.new(ed.Transparency or 0.1, 1)
        pe.Lifetime = NumberRange.new((ed.Life or 0.6) * 0.7, ed.Life or 0.6)
        local sp = (ed.Speed or 0.5) * scale
        pe.Speed = NumberRange.new(math.min(sp * 0.5, sp), math.max(sp * 0.5, sp))
        pe.SpreadAngle = V2(180, 180)
        pe.Acceleration = (ed.Accel or V(0, 0, 0)) * scale
        if ed.Spin then pe.Rotation = NumberRange.new(0, 360); pe.RotSpeed = NumberRange.new(-120, 120) end
        pe.LockedToPart = false
        pe.Rate = ed.Burst and 0 or (ed.Rate or 4)
        pe:SetAttribute("SkinFx", true)
        pe.Parent = host
        if ed.Burst then
            d.Bursts[ed.Burst] = d.Bursts[ed.Burst] or {}
            table.insert(d.Bursts[ed.Burst], { Emitter = pe, Count = ed.Count or 10 })
        else
            table.insert(d.Emitters, pe)
            if ed.HeatAdd then
                table.insert(d.HeatEmit, { Emitter = pe, Rate = ed.Rate or 0, Add = ed.HeatAdd, Min = ed.HeatMin or 0 })
            else
                -- (bug sweep 2026-10-13: glove / sleeve emitters ran at full rate on Graphics Quality Low -- the Torchbearer
                -- gauntlets' flame among them; QThin = THIN of the rate on Low. Heat-driven emitters set their own rate.)
                local okQ, QM = pcall(function() return require(script.Parent:FindFirstChild("QualityMode") :: any) end)
                if okQ and QM and QM.Thin then QM.Thin(pe) end
            end
        end
    end
    return d
end

-- event age -> 0..1 "shown" factor (fade in 0.25s, hold, fade out over the last 0.4s of `dur`)
local function Shown(d, kind, now, dur)
    local t = d.Ev[kind]
    if not t then return 0 end
    local age = now - t
    if age > dur then return 0 end
    return math.clamp(age / 0.25, 0, 1) * math.clamp((dur - age) / 0.4, 0, 1)
end
local function Since(d, kind, now)
    local t = d.Ev[kind]
    return t and (now - t) or 99
end

-- Place a dressing on its owner (call every frame after the owner moved). ownerCF / ownerSize = the owner's frame in
-- the look's unit space (-Z = fingertips); now = os.clock().
function GloveFX.Place(d: any, ownerCF: CFrame, ownerSize: Vector3, now: number)
    if not d or not d.Def then return end
    -- d.LenRef (first-person sleeves): lay the pieces out on a block LenRef long anchored at the owner's -Z (wrist) end,
    -- so a long arm doesn't stretch its cuff / plates along with it
    if d.LenRef and ownerSize.Z > d.LenRef then
        ownerCF = ownerCF * CFrame.new(0, 0, (d.LenRef - ownerSize.Z) / 2)
        ownerSize = Vector3.new(ownerSize.X, ownerSize.Y, d.LenRef)
    end
    local dt = d.LastT and math.clamp(now - d.LastT, 0, 0.1) or 0
    d.LastT = now
    d.Heat = (d.Heat or 0) * math.exp(-dt * 0.9)
    local heat = d.Heat
    local w = math.max(ownerSize.X, ownerSize.Y)
    local bulkP, bulkC = d.BulkP, d.BulkC
    table.clear(bulkP); table.clear(bulkC)
    -- GLOVE FIT (0.93, owner: "the gloves in general are too big, wearing only the sleeves almost always looks nicer"):
    -- d.Fit < 1 (first-person gloves) pulls every piece in toward the hand and keeps only part of the extra thickness of the
    -- shells that wrap it (a 1.3x gauntlet block becomes ~1.18x) -- still wrapping (>= 1.08, see below), far less bulky
    local fit = d.Fit or 1
    local function Pt(off, offW, seat) return (off and off * ownerSize or Vector3.zero) * (seat and 1 or fit) + (offW and offW * w or Vector3.zero) * fit end
    for _, e in ipairs(d.Parts) do
        local pd = e.Def
        if e.EmitAtt then
            e.EmitAtt.WorldPosition = ownerCF:PointToWorldSpace(Pt(pd.Off, pd.OffW))
            continue
        end
        if e.RaysAtt then
            local k = Shown(d, pd.ShowOn or "Inspect", now, pd.ShowFor or 1.8)
            e.RaysAtt.WorldPosition = ownerCF:PointToWorldSpace(Pt(pd.Off, pd.OffW))
            local s = (pd.Size or 3) * w
            e.RaysGui.Size = UDim2.fromScale(s, s)
            e.RaysImg.ImageTransparency = 1 - k * 0.75
            e.RaysImg.Rotation = now * (pd.Spin or 20)
            continue
        end
        local p = e.Part
        local size
        if pd.Ring then
            size = e.Tooth and V(pd.Thick * w * 1.3, pd.Thick * w * 1.6, pd.Thick * w * 1.2) or V(e.Chord * w, pd.Thick * w, pd.Thick * w)
        elseif pd.Uniform then
            size = pd.Size * w * fit
        else
            -- (never within 8% of the owner's own width on an axis it spans: a band at 1.04x shared its faces with the
            -- arm block -- and the 1.04x glove block next to it -- and flickered. Owner 2026-10-04: "textures bug out")
            local sz = pd.Size
            local sx, sy, sz3 = sz.X, sz.Y, sz.Z
            if fit < 1 then -- (wrap shells keep part of their margin; small pieces just shrink)
                local function F(v) return (v >= 1) and math.max(1.08, 1 + (v - 1) * (2 * fit - 1)) or v * fit end
                sx, sy, sz3 = F(sx), F(sy), sz3 * fit
            end
            if d.WrapK and sx > 1.08 and sy > 1.08 then -- (first-person sleeves: wrap bands keep WrapK of their extra width; order kept)
                sx, sy = 1.08 + (sx - 1.08) * d.WrapK, 1.08 + (sy - 1.08) * d.WrapK
            end
            if sx > 0.9 and sx < 1.08 then sx = 1.08 end
            if sy > 0.9 and sy < 1.08 then sy = 1.08 end
            size = V(sx, sy, sz3) * ownerSize
        end
        size *= (e.Eps or 1)
        if pd.Anim == "Grow" then
            -- (SKINS V3) GROW: rests at MinScale, swells to full size for Dur s every Period s (offset Phase); BoostOn /
            -- BurstOn events (e.g. "Kill", "Inspect") make it grow at once. Grows from its root with Root = 1.
            local per, dur = pd.Period or 6, pd.Dur or 0.9
            local t = (now + (pd.Phase or 0)) % per
            local k = (t < dur) and math.sin(t / dur * math.pi) or 0
            if pd.BurstOn then k = math.max(k, math.exp(-Since(d, pd.BurstOn, now) * 3) * (Since(d, pd.BurstOn, now) < 1.2 and 1 or 0)) end
            local mn = pd.MinScale or 0.08
            size *= mn + (1 - mn) * k
        elseif pd.Anim == "Flame" then
            -- (skinsB, TORCHBEARER) a LIVING FLAME: layered noise stretches it along its length (Z) and width (X), it burns
            -- taller with sustained fire (heat) and BurstOn (e.g. "Kill") flares it up for a moment
            local ph = pd.Phase or 0
            local n1 = 0.5 * math.sin(now * 7.3 + ph) + 0.3 * math.sin(now * 11.9 + 1.3 + ph) + 0.2 * math.sin(now * 17.1 + 0.6 + ph)
            local n2 = 0.6 * math.sin(now * 9.7 + 2.1 + ph) + 0.4 * math.sin(now * 13.3 + ph)
            local fl = 0
            if pd.BurstOn then local s = Since(d, pd.BurstOn, now); if s < 1.5 then fl = math.exp(-s * 2.5) end end
            size = V(size.X * (1 + 0.07 * n2 + 0.15 * fl), size.Y, size.Z * (0.86 + 0.09 * n1 + 0.18 * (heat or 0) + 0.35 * fl))
        elseif pd.Anim == "Fill" then
            -- (skins6, FISSION) FILL: a meter bar that fills slowly along its own Z over Period s and drops back (a dosimeter);
            -- BurstOn (e.g. "Kill") fills it at once for a moment. Use Root = 1 so it grows out of its base.
            local per = pd.Period or 7
            local t = ((now + (pd.Phase or 0)) % per) / per
            local k = (t < 0.9) and (t / 0.9) or (1 - (t - 0.9) / 0.1)
            if pd.BurstOn and Since(d, pd.BurstOn, now) < 0.8 then k = 1 end
            local mn = pd.MinScale or 0.06
            size = V(size.X, size.Y, size.Z * (mn + (1 - mn) * k))
        end
        if e.LastSize ~= size then p.Size = size; e.LastSize = size end -- (a Size write is costly; most frames it's unchanged)
        local base = ownerCF * CFrame.new(Pt(pd.Off, pd.OffW, pd.Seat))
        local boost = (pd.BoostOn and Shown(d, pd.BoostOn, now, 1.8) or 0) * 2.5 + 1
        local burst = pd.BurstOn and math.exp(-Since(d, pd.BurstOn, now) * 4) or 0
        local cf
        local anim = pd.Anim
        if pd.Ring then
            local spin = (anim == "Spin") and (now * (pd.Speed or 1) * boost) or 0
            local r = pd.Radius * w * (1 + burst * 0.6) * fit
            if e.Tooth then r += pd.Thick * w * 0.9 end
            cf = base * AXIS[pd.Axis or "Z"] * Rot(pd.Tilt) * CFrame.Angles(0, 0, math.rad(e.RingAngle) + spin) * CFrame.new(0, r, 0)
        elseif anim == "SpinOrbit" then
            e.Ang = (e.Ang or (pd.Phase or 0)) + dt * (pd.Speed or 1) * boost
            local a = e.Ang
            local r = (pd.OffW and pd.OffW.X or 0.9) * w * (1 + burst * 1.4)
            cf = ownerCF * CFrame.new(Pt(pd.Off, V(0, 0, pd.OffW and pd.OffW.Z or 0))) * CFrame.Angles(0, 0, a) * CFrame.new(r, 0, 0) * Rot(pd.Rot) * CFrame.Angles(0, a * 2, 0)
        elseif anim == "Flap" then
            local s = pd.Side or 1
            local amp = (pd.Amp or 8) * (1 + 2.2 * (pd.FlareOn and math.exp(-Since(d, pd.FlareOn, now) * 3.5) or 0))
            local ang = math.sin(now * (pd.Speed or 2.2) + (pd.Phase or 0)) * amp + (pd.OpenOn and Shown(d, pd.OpenOn, now, pd.OpenFor or 1.8) * (pd.OpenAng or 30) or 0)
            cf = base * Rot(pd.Rot) * CFrame.Angles(0, math.rad(ang * s), 0)
        elseif anim == "Clock" then
            local a
            if pd.Hand == "S" then a = (now % 60) / 60 * 2 * math.pi + Since(d, "Fire", now) * 0 -- smooth sweep
            elseif pd.Hand == "M" then a = math.floor(now) / 60 * 2 * math.pi / 6 -- a notch every second
            else a = now / 3600 * 2 * math.pi * 6 end
            cf = base * Rot(pd.Rot) * CFrame.Angles(0, -a, 0)
        elseif anim == "Piston" then
            local kick = math.exp(-Since(d, "Fire", now) * 14)
            cf = base * Rot(pd.Rot) * CFrame.new((pd.Dist or 0.15) * w * kick, 0, 0)
        elseif anim == "Bob" then
            cf = base * CFrame.new(0, math.sin(now * (pd.Speed or 2) + (pd.Phase or 0)) * (pd.Amp or 0.05) * w, 0) * Rot(pd.Rot)
        elseif anim == "Drip" then
            -- (skins11, SILKFANG) DRIP: a dewdrop that slides along Path (block units, like Off) for Dur s every Period s
            -- (offset Phase), eased, fading in at the start and out at the end, hidden between; BurstOn (e.g. "Kill")
            -- starts a slide at once
            local per, dur = pd.Period or 5, pd.Dur or 1.6
            local t = (now + (pd.Phase or 0)) % per
            if pd.BurstOn and Since(d, pd.BurstOn, now) < dur then t = Since(d, pd.BurstOn, now) end
            local u = math.clamp(t / dur, 0, 1)
            e.DripK = (t < dur) and math.sqrt(math.sin(u * math.pi)) or 0
            cf = base * CFrame.new((pd.Path or V(0, 0, 0.4)) * ownerSize * (pd.Seat and 1 or fit) * (u * u * (3 - 2 * u))) * Rot(pd.Rot)
        elseif anim == "Ghost" then
            local target = base * Rot(pd.Rot)
            e.G = e.G and e.G:Lerp(target, 1 - math.exp(-dt * (pd.Lag or 7))) or target
            if (e.G.Position - target.Position).Magnitude > w * 4 then e.G = target end
            cf = e.G
        else
            cf = base * Rot(pd.Rot)
        end
        if pd.Root then cf = cf * CFrame.new(0, 0, pd.Root * size.Z / 2) end
        if pd.ShiftW then cf = cf * CFrame.new(pd.ShiftW * w) end
        if pd.WedgeFlip then cf = cf * CFrame.Angles(0, math.pi, 0) end
        table.insert(bulkP, p); table.insert(bulkC, cf)
        -- look animations (transparency / colour)
        local tr = e.BaseT
        if anim == "Pulse" then
            local k = 0.5 + 0.5 * math.sin(now * (pd.Speed or 2.4) + (pd.Phase or 0))
            local lo, hi = pd.PulseMin or 0, pd.PulseMax or 0.5
            tr = lo + (hi - lo) * (1 - k)
        elseif anim == "Flicker" then
            local slot = math.floor(now * (pd.Rate or 6))
            tr = ((slot * 7919 + math.floor((pd.Off and pd.Off.X or 0) * 100)) % 5 == 0) and 0.9 or 0
        elseif anim == "Chase" then
            local k = 0.5 + 0.5 * math.sin(now * 6 - (pd.Index or 1) * 1.2)
            tr = 0.6 * (1 - k)
        elseif anim == "Rainbow" then
            p.Color = Color3.fromHSV((now * 0.15 + (pd.Phase or 0)) % 1, 0.65, 1)
        elseif anim == "Blink" then
            -- (SKINS V3, builder 5 CARAPACE) a firefly's signal: Count quick blinks (each Dur long, Gap apart) every Period
            -- seconds, dark between (PulseMax = how faint it rests, PulseMin = the peak); BurstOn (e.g. "Kill") flares it
            local per, dur, gap, cnt = pd.Period or 3, pd.Dur or 0.14, pd.Gap or 0.3, pd.Count or 2
            local t = (now + (pd.Phase or 0)) % per
            local k = 0
            for i = 0, cnt - 1 do
                local u = (t - i * gap) / dur
                if u > 0 and u < 1 then k = math.max(k, math.sin(u * math.pi)) end
            end
            if pd.BurstOn then k = math.max(k, math.exp(-Since(d, pd.BurstOn, now) * 3) * (Since(d, pd.BurstOn, now) < 1.2 and 1 or 0)) end
            local lo, hi = pd.PulseMin or 0, pd.PulseMax or 0.85
            tr = hi - (hi - lo) * k
        elseif anim == "Drip" then
            local lo, hi = pd.PulseMin or 0, pd.PulseMax or 1
            tr = hi - (hi - lo) * (e.DripK or 0)
        elseif anim == "Twinkle" then
            -- (2026-10-10 cosmetic overhaul, "SUBTLE but cool"): dark most of the time, one soft flash every Period seconds
            -- (Dur long, offset by Phase); PulseMax = how faint it rests, PulseMin = the peak
            local per, dur = pd.Period or 4.5, pd.Dur or 0.5
            local t = (now + (pd.Phase or 0)) % per
            local k = (t < dur) and math.sin(t / dur * math.pi) or 0
            local lo, hi = pd.PulseMin or 0, pd.PulseMax or 0.95
            tr = hi - (hi - lo) * k
        end
        if pd.HeatGlow then
            tr = 0.55 * (1 - heat) + (0.5 + 0.5 * math.sin(now * (3 + heat * 6))) * 0.25 * (1 - heat)
            p.Color = C(255, 110, 30):Lerp(C(255, 230, 150), heat)
        end
        if pd.HeatBloom then
            -- (SKINS V3, builder 2) HEAT BLOOM: hidden at rest; sustained fire (d.Heat past Min) makes the piece bloom
            -- through the set's ramp A -> Mid -> B, fading as the heat bleeds off (~2 s); a softer flash on Kill / Inspect
            local hb = pd.HeatBloom
            local mn = hb.Min or 0.3
            local k = math.clamp((heat - mn) / (1 - mn), 0, 1)
            k = math.max(k, math.exp(-Since(d, "Kill", now) * 2.2) * 0.75, Shown(d, "Inspect", now, 1.6) * 0.45)
            tr = 1 - k * (hb.Peak or 0.85)
            local a, m, b = hb.A or C(70, 20, 110), hb.Mid or C(200, 30, 60), hb.B or C(255, 120, 30)
            p.Color = (k < 0.5) and a:Lerp(m, k * 2) or m:Lerp(b, k * 2 - 1)
        end
        if pd.FlashOn then tr = tr * (1 - math.exp(-Since(d, pd.FlashOn, now) * 10)) end
        if pd.ShowOn then tr = 1 - (1 - tr) * Shown(d, pd.ShowOn, now, pd.ShowFor or 1.8) end
        if e.LastT ~= tr then p.Transparency = tr; e.LastT = tr end
        if e.Holo and (not e.HoloT or now - e.HoloT > 0.1) then
            e.HoloT = now
            local h = e.Holo
            if d.Local then
                local lh = GloveFX.LocalHolo
                local flash = Since(d, "Kill", now) < 0.6
                h.Big.Text = flash and "+1" or tostring(lh.Big)
                h.Sub.Text = flash and "KILL" or tostring(lh.Sub)
                h.Bar.Size = UDim2.fromScale(math.clamp(lh.Frac or 1, 0, 1), 1)
            else
                h.Big.Text = string.format("%02d", math.floor(now * 3) % 100)
                h.Sub.Text = "ARC//LINK"
                h.Bar.Size = UDim2.fromScale(0.5 + 0.5 * math.sin(now * 2), 1)
            end
        end
    end
    if #bulkP > 0 then
        if d.Parent and d.Parent:IsDescendantOf(workspace) then
            workspace:BulkMoveTo(bulkP, bulkC, Enum.BulkMoveMode.FireCFrameChanged)
        else -- (a ViewportFrame preview: not in the workspace)
            for i = 1, #bulkP do bulkP[i].CFrame = bulkC[i] end
        end
    end
    -- beams
    for _, b in ipairs(d.Beams) do
        local bd = b.Def
        if b.Moving then
            b.A0.WorldPosition = ownerCF:PointToWorldSpace(Pt(bd.FromOff, bd.FromW))
            b.A1.WorldPosition = ownerCF:PointToWorldSpace(Pt(bd.ToOff, bd.ToW))
        end
        local wd = (bd.Width or 0.04) * w
        if bd.Lightning then
            if not b.NextT or now >= b.NextT then
                b.NextT = now + 0.05 + math.random() * 0.04
                b.Beam.CurveSize0 = (math.random() - 0.5) * w * 1.2
                b.Beam.CurveSize1 = (math.random() - 0.5) * w * 1.2
                local on = math.random() < 0.8
                b.Beam.Width0 = on and wd * (0.6 + math.random()) or 0
                b.Beam.Width1 = on and wd * 0.3 or 0
            end
        elseif b.LastW ~= wd then
            b.Beam.Width0, b.Beam.Width1 = wd, wd
            b.LastW = wd
        end
    end
    -- the arc between both hands (GloveFX.Link)
    if d.Link and (not d.LinkT or now >= d.LinkT) then
        d.LinkT = now + 0.06
        local bm = d.Link
        bm.CurveSize0 = (math.random() - 0.5) * w * 3
        bm.CurveSize1 = (math.random() - 0.5) * w * 3
        local wd = (d.Def.Arc.Width or 0.03) * w
        bm.Width0 = (math.random() < 0.85) and wd * (0.5 + math.random()) or 0
        bm.Width1 = bm.Width0 * 0.6
    end
    -- base texture animation (scroll / heat)
    local bt = d.BaseTex
    if bt and bt.Def and not d.Hidden then
        local bdef = bt.Def
        if bdef.TexScroll then
            local u, v = (now * bdef.TexScroll.X * bt.Tile) % bt.Tile, (now * bdef.TexScroll.Y * bt.Tile) % bt.Tile
            for _, t in ipairs(bt.List) do t.OffsetStudsU = u; t.OffsetStudsV = v end
        end
        if bdef.TexHeat then
            local tr = 0.42 * (1 - heat) + 0.08 * math.sin(now * 3)
            for _, t in ipairs(bt.List) do t.Transparency = math.max(0, tr) end
        end
    end
    -- part textures that scroll / heat (vambraces)
    for _, e in ipairs(d.Parts) do
        if e.Tex and e.Def.TexTile and e.Part then
            local tile = e.Def.TexTile * w
            if e.TexTile ~= tile then
                for _, t in ipairs(e.Tex) do t.StudsPerTileU, t.StudsPerTileV = tile, tile end
                e.TexTile = tile
            end
            if e.Def.TexScroll then
                local u, v = (now * e.Def.TexScroll.X * tile) % tile, (now * e.Def.TexScroll.Y * tile) % tile
                for _, t in ipairs(e.Tex) do t.OffsetStudsU = u; t.OffsetStudsV = v end
            end
            if e.Def.TexHeat and not d.Hidden then
                local tr = math.max(0, 0.42 * (1 - heat) + 0.08 * math.sin(now * 3 + 1))
                for _, t in ipairs(e.Tex) do t.Transparency = tr end
            end
        end
    end
    -- heat-driven emitters
    for _, he in ipairs(d.HeatEmit) do
        local r = he.Rate + he.Add * (heat > he.Min and (heat - he.Min) / (1 - he.Min) or 0)
        if math.abs(he.Emitter.Rate - r) > 0.5 then he.Emitter.Rate = r end
    end
    if d.Def.Base and d.Def.Base.Anim == "Rainbow" and d.Owner then
        d.Owner.Color = Color3.fromHSV((now * 0.15 + 0.3) % 1, 0.4, 1)
    end
end

-- one-shot world effects for events (nova / implosion / eruption) at a world position
local function Shock(kind: string, color: any, pos: Vector3, w: number)
    local rainbow = color == "Rainbow"
    local c = rainbow and Color3.fromHSV(math.random(), 0.7, 1) or color
    local folder = workspace:FindFirstChild("GloveShocks")
    if not folder then folder = Instance.new("Folder"); folder.Name = "GloveShocks"; folder.Parent = workspace end
    local function Ball(size, tr)
        local p = Instance.new("Part")
        p.Shape = Enum.PartType.Ball
        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
        p.Material = NEON; p.Color = c; p.Transparency = tr
        p.Size = V(size, size, size); p.CFrame = CFrame.new(pos)
        p.Parent = folder
        Debris:AddItem(p, 1)
        return p
    end
    if kind == "Nova" then
        local b = Ball(w * 0.4, 0.15)
        TweenService:Create(b, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = V(w * 4, w * 4, w * 4), Transparency = 1 }):Play()
        local ring = Instance.new("Part")
        ring.Shape = Enum.PartType.Cylinder
        ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
        ring.Material = NEON; ring.Color = c; ring.Transparency = 0.2
        ring.Size = V(w * 0.05, w, w); ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
        ring.Parent = folder
        Debris:AddItem(ring, 1)
        TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = V(w * 0.02, w * 7, w * 7), Transparency = 1 }):Play()
    elseif kind == "Implode" then
        local b = Ball(w * 4, 0.6)
        b.Color = C(10, 0, 20)
        TweenService:Create(b, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = V(w * 0.1, w * 0.1, w * 0.1), Transparency = 0.1 }):Play()
        local rim = Ball(w * 4.3, 0.75)
        TweenService:Create(rim, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = V(w * 0.2, w * 0.2, w * 0.2), Transparency = 0.3 }):Play()
        task.delay(0.28, function()
            local f = Ball(w * 0.3, 0)
            TweenService:Create(f, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = V(w * 2.2, w * 2.2, w * 2.2), Transparency = 1 }):Play()
        end)
    elseif kind == "Erupt" then
        local b = Ball(w * 0.6, 0.1)
        TweenService:Create(b, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = V(w * 3, w * 3, w * 3), Transparency = 1 }):Play()
        local att = Instance.new("Attachment"); att.WorldPosition = pos
        local host = Instance.new("Part"); host.Anchored = true; host.CanCollide = false; host.CanQuery = false; host.CanTouch = false
        host.Transparency = 1; host.Size = V(0.1, 0.1, 0.1); host.CFrame = CFrame.new(pos); host.Parent = folder
        att.Parent = host
        local pe = Instance.new("ParticleEmitter")
        pe.Texture = FIRE; pe.Color = ColorSequence.new(C(255, 220, 120), C(255, 60, 20)); pe.LightEmission = 1
        pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, w * 0.8), NumberSequenceKeypoint.new(1, 0) })
        pe.Lifetime = NumberRange.new(0.4, 0.7); pe.Speed = NumberRange.new(w * 4, w * 8); pe.SpreadAngle = V2(30, 30)
        pe.EmissionDirection = Enum.NormalId.Top; pe.Acceleration = V(0, w * 4, 0); pe.Rate = 0; pe.Parent = att
        pe:Emit(26)
        local light = Instance.new("PointLight"); light.Color = C(255, 140, 40); light.Range = w * 12; light.Brightness = 3; light.Parent = host
        TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
        Debris:AddItem(host, 1.2)
    end
end

-- an event (Fire / Kill / Inspect): bursts, shocks, heat, and the timestamps the animations react to
function GloveFX.Event(d: any, kind: string)
    if not d or not d.Def then return end
    local now = os.clock()
    d.Ev[kind] = now
    if kind == "Fire" then d.Heat = math.min(1, (d.Heat or 0) + 0.06) end
    for _, b in ipairs(d.Bursts[kind] or {}) do
        if b.Emitter.Parent and b.Emitter.Enabled ~= false then b.Emitter:Emit(b.Count) end
    end
    local sh = d.Def.Shock and d.Def.Shock[kind]
    if sh and d.Owner and d.Owner.Parent and not d.Hidden then
        local w = math.max(d.Owner.Size.X, d.Owner.Size.Y) * (d.Local and 0.6 or 1) -- (first person: right under the camera)
        pcall(Shock, sh.Kind, sh.Color, d.Owner.Position, w)
    end
end
GloveFX.Burst = GloveFX.Event

-- the electric arc between both hands (gloves with def.Arc)
function GloveFX.Link(a: any, b: any)
    if not (a and b and a.Def and a.Def.Arc and a.Attachment and b.Attachment) then return end
    local beam = Instance.new("Beam")
    beam.Attachment0, beam.Attachment1 = a.Attachment, b.Attachment
    beam.Color = ColorSequence.new(a.Def.Arc.Color or C(120, 240, 255))
    beam.LightEmission = 1; beam.LightInfluence = 0; beam.FaceCamera = true; beam.Segments = 10
    beam.Parent = a.Owner
    a.Link = beam
end

-- show / hide the things LocalTransparencyModifier doesn't reach: beams, guis, emitters -- and TEXTURES (Roblox keeps
-- drawing a hidden part's textures: a hidden viewmodel / your own arm shells left floating filigree on screen)
function GloveFX.SetShown(d: any, on: boolean)
    if not d then return end
    d.Hidden = not on
    for _, b in ipairs(d.Beams or {}) do if b.Beam then b.Beam.Enabled = on end end
    if d.Link then d.Link.Enabled = on end
    for _, g in ipairs(d.Guis or {}) do g.Enabled = on end
    for _, pe in ipairs(d.Emitters or {}) do pe.Enabled = on end
    local bt = d.BaseTex
    if bt and bt.List then
        for _, t in ipairs(bt.List) do t.Transparency = on and ((bt.Def and bt.Def.TexT) or 0) or 1 end
    end
    for _, e in ipairs(d.Parts or {}) do
        if e.Tex then for _, t in ipairs(e.Tex) do t.Transparency = on and (e.Def.TexT or 0) or 1 end end
    end
end

function GloveFX.Clear(d: any)
    if not d then return end
    for _, e in ipairs(d.Parts or {}) do
        if e.Part then e.Part:Destroy() end
        if e.RaysAtt then e.RaysAtt:Destroy() end
    end
    for _, b in ipairs(d.Beams or {}) do if b.Beam then b.Beam:Destroy() end end
    for _, a in ipairs(d.Atts or {}) do a:Destroy() end
    if d.Link then d.Link:Destroy() end
    if d.Attachment then d.Attachment:Destroy() end
    d.Parts, d.Emitters, d.Bursts, d.Beams, d.Atts, d.Guis, d.HeatEmit = {}, {}, {}, {}, {}, {}, {}
    d.Link = nil
end

-- base look on the owner part itself (+ its texture). w = the owner's width (texture tiling); returns the texture
-- record for Place (scrolling / heat) -- put it in dressing.BaseTex.
function GloveFX.ApplyBase(def: any, owner: BasePart, fallback: Color3?, w: number?, noTex: boolean?): any
    local b = def and def.Base
    if b then
        owner.Color = b.Color
        owner.Material = b.Material or SMOOTH
        owner.Reflectance = b.Reflectance or 0
        if owner.Material == GLASS then owner.Material = SMOOTH; owner.Reflectance = math.max(b.Reflectance or 0, 0.18) end -- (see Dress)
    elseif fallback then
        owner.Color = fallback
        owner.Material = SMOOTH
        owner.Reflectance = 0
    end
    local tile = ((b and b.TexTile) or 1) * (w or math.max(owner.Size.X, owner.Size.Y))
    if noTex then return { Def = b, List = {}, Tile = tile } end -- (server shells: each client textures them itself)
    local list = ApplyTex(owner, b and b.Tex, tile, b and b.TexT, b and b.TexColor)
    return { Def = b, List = list, Tile = tile }
end

-- drop a world shell's dressing (and its local textures) so the next scan dresses it again from its attributes
function GloveFX.ForgetShell(sh: BasePart)
    local live = GloveFX._live
    local rec = live and live[sh]
    if rec then GloveFX.Clear(rec.D); live[sh] = nil end
    for _, t in ipairs(sh:GetChildren()) do if t.Name == "GloveTex" then t:Destroy() end end
end

-- ==================== third person (client): dress every character's shells ====================
-- The server welds plain shells (hands: "LeftHandGlove" / "RightHandGlove", arms: "...Sleeve") into each
-- character's "WorldGloves" model, with attributes LookKind ("Glove" / "Sleeve"), LookId and Side ("L" / "R").
-- Each client builds the decorations locally and moves them every frame (smooth, no replication).
local LOOK_R = CFrame.fromMatrix(Vector3.zero, V(0, 0, 1), V(1, 0, 0), V(0, 1, 0)) -- right limb: look +Y = outer side, -Z = down the limb
local LOOK_L = CFrame.fromMatrix(Vector3.zero, V(0, 0, -1), V(-1, 0, 0), V(0, 1, 0))
GloveFX.WorldRot = { L = LOOK_L, R = LOOK_R } -- (CosmeticPreview dresses shells on your avatar's clone the same way)
-- (2026-10-13) the WORLD version of a look (what other players see on your R6 arms). Owner, pass 1: the gloves "look a
-- little silly" (oversized shells + bands covering the gun); pass 2: "The arms just dont have enough detail from other
-- players pov". So: the SAME sculpted pieces first person wears (Mesh = "<Kind>/<Piece>" ArmsModels, emblems, plates,
-- seams, the colourway's maps) fitted onto the slim world shells, but nothing wider than the arm (pieces' cross-section
-- capped at WORLD_MAX_CROSS x the shell), no first-person-only bits (ammo hologram, rays, beams, the arc between the
-- hands) and only burst particles. Distance LOD in StartWorld (WORLD_DETAIL_DIST). Cached per look (colourways included).
local WORLD_MAX_CROSS = 1.1
GloveFX.WORLD_DETAIL_DIST = 60
local worldDefs = setmetatable({}, { __mode = "k" })
local WORLD_SLEEVE_LONG = 1.45 -- (an R6 sleeve is ~1.6 shell-widths long: a long uniform piece -- the Torchbearer sprig -- ran past the shoulder)
function GloveFX.WorldDef(def: any, kind: string?): any
    if not def then return def end
    local w = worldDefs[def]
    if w then return w end
    w = setmetatable({ Parts = {}, Emit = {}, Arc = false }, { __index = def })
    for _, pd in ipairs(def.Parts or {}) do
        if not (pd.Beam or pd.Holo or pd.Rays) and #w.Parts < 40 then
            local sz = pd.Size
            if sz and not pd.Uniform and (sz.X > WORLD_MAX_CROSS or sz.Y > WORLD_MAX_CROSS) then
                pd = setmetatable({ Size = V(math.min(sz.X, WORLD_MAX_CROSS), math.min(sz.Y, WORLD_MAX_CROSS), sz.Z) }, { __index = pd })
            elseif sz and pd.Uniform and kind == "Sleeve" and math.max(sz.X, sz.Y, sz.Z) > WORLD_SLEEVE_LONG then
                pd = setmetatable({ Size = sz * (WORLD_SLEEVE_LONG / math.max(sz.X, sz.Y, sz.Z)) }, { __index = pd })
            end
            table.insert(w.Parts, pd)
        end
    end
    for _, ed in ipairs(def.Emit or {}) do if ed.Burst then table.insert(w.Emit, ed) end end
    worldDefs[def] = w
    return w
end

function GloveFX.StartWorld()
    if GloveFX.WorldStarted or not RunService:IsClient() then return end
    GloveFX.WorldStarted = true
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    local folder = Instance.new("Folder")
    folder.Name = "WorldGloveFX"
    folder.Parent = workspace
    local live = {} -- shell -> { D = dressing, Player = player }
    GloveFX._live = live
    local pulses = {} -- player -> last KillPulse
    local lastScan = 0
    -- new shells (respawns, entering / leaving a dungeon rebuilds them) are dressed on the very next frame
    workspace.DescendantAdded:Connect(function(dsc)
        if dsc.Name == "WorldGloves" or (dsc.Parent and dsc.Parent.Name == "WorldGloves") then lastScan = 0 end
    end)
    RunService.RenderStepped:Connect(function()
        local now = os.clock()
        local cam = workspace.CurrentCamera
        if now - lastScan > 0.5 then
            lastScan = now
            for _, p in ipairs(Players:GetPlayers()) do
                local wg = p.Character and p.Character:FindFirstChild("WorldGloves")
                if wg then
                    for _, sh in ipairs(wg:GetChildren()) do
                        if sh:IsA("BasePart") and sh:GetAttribute("LookId") and not live[sh] then
                            local kind = sh:GetAttribute("LookKind")
                            local def = (kind == "Sleeve" and GloveFX.SleeveById or GloveFX.GloveById)[sh:GetAttribute("LookId")]
                            if def and def.Base then
                                local w = math.max(sh.Size.X, sh.Size.Z)
                                local d = GloveFX.Dress(GloveFX.WorldDef(def, sh:GetAttribute("LookKind")), sh, folder, w * 1.1)
                                d.BaseTex = GloveFX.ApplyBase(def, sh, nil, w) -- (textures are local: the server shell has none)
                                live[sh] = { D = d, Player = p, Rot = (sh:GetAttribute("Side") == "L") and LOOK_L or LOOK_R, Hidden = nil }
                            end
                        end
                    end
                end
                -- kills: the server bumps the player's KillPulse attribute (dummies: Studio pose tests)
                local kp = p:GetAttribute("KillPulse")
                if kp and pulses[p] and kp ~= pulses[p] then
                    for sh, rec in pairs(live) do if rec.Player == p then GloveFX.Event(rec.D, "Kill") end end
                end
                pulses[p] = kp
            end
            -- (Studio: CharacterPoser test dummies wear their world gloves too)
            if RunService:IsStudio() then
                for _, m in ipairs(game:GetService("CollectionService"):GetTagged("AimPoseDummy")) do
                    local wg = m:FindFirstChild("WorldGloves")
                    for _, sh in ipairs(wg and wg:GetChildren() or {}) do
                        if sh:IsA("BasePart") and sh:GetAttribute("LookId") and not live[sh] then
                            local def = (sh:GetAttribute("LookKind") == "Sleeve" and GloveFX.SleeveById or GloveFX.GloveById)[sh:GetAttribute("LookId")]
                            if def and def.Base then
                                local w = math.max(sh.Size.X, sh.Size.Z)
                                local d = GloveFX.Dress(GloveFX.WorldDef(def, sh:GetAttribute("LookKind")), sh, folder, w * 1.1)
                                d.BaseTex = GloveFX.ApplyBase(def, sh, nil, w)
                                live[sh] = { D = d, Player = m, Rot = (sh:GetAttribute("Side") == "L") and LOOK_L or LOOK_R, Hidden = nil }
                            end
                        end
                    end
                end
            end
            -- arcs between a character's two gloves
            for sh, rec in pairs(live) do
                if rec.D.Def.Arc and not rec.D.Link and sh:GetAttribute("Side") == "R" then
                    for sh2, rec2 in pairs(live) do
                        if rec2.Player == rec.Player and sh2 ~= sh and sh2:GetAttribute("LookKind") == "Glove" then GloveFX.Link(rec.D, rec2.D) end
                    end
                end
            end
        end
        local thirdPerson = lp:GetAttribute("ThirdPerson")
        for sh, rec in pairs(live) do
            if not sh.Parent or not sh:IsDescendantOf(workspace) then
                GloveFX.Clear(rec.D)
                live[sh] = nil
            else
                local own = rec.Player == lp
                local far = (cam.CFrame.Position - sh.Position).Magnitude > GloveFX.WORLD_DETAIL_DIST -- (beyond: the plain shell)
                -- your own: hidden whenever the camera is in / near your head (first person, camera blends, close zoom)
                local head = own and rec.Player.Character and rec.Player.Character:FindFirstChild("Head")
                local camClose = head and (cam.CFrame.Position - head.Position).Magnitude < 3
                local hide
                if own then
                    hide = not thirdPerson or camClose or sh.Transparency >= 1
                    -- (your own shell itself too: in first person the camera sits inside your body)
                    local ltm = hide and 1 or 0
                    if sh.LocalTransparencyModifier ~= ltm then sh.LocalTransparencyModifier = ltm end
                else
                    hide = far or sh.Transparency >= 1 or sh.LocalTransparencyModifier >= 1
                end
                if hide ~= rec.Hidden then
                    rec.Hidden = hide
                    -- (SetShown also hides the shell's textures: Roblox draws textures on parts hidden by the
                    -- transparency modifier, so in first person your own arm textures floated across the screen)
                    GloveFX.SetShown(rec.D, not hide)
                    for _, e in ipairs(rec.D.Parts) do if e.Part then e.Part.LocalTransparencyModifier = hide and 1 or 0 end end
                end
                if not hide then
                    local s = sh.Size
                    GloveFX.Place(rec.D, sh.CFrame * rec.Rot, V(s.Z, s.X, s.Y), now)
                end
            end
        end
    end)
end

return GloveFX
