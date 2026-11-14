--!nocheck
-- ===================================================================================================================
-- ORBITER (Skins V3, bundle 11 of docs/SKINS_V3_PLAN.md; SKINS BUILDER 8 "skins8"): P90 + F2000 + Quadbeam | Antenna
-- Glaive | 1,199 BP. Real spacecraft hardware: crinkled multi-layer insulation FOIL blankets in deep gold with taped
-- seams, flat graphite SOLAR-CELL panels, black thermal equipment bays with a row of small ceramic heat-shield tiles, a
-- REACTION WHEEL turning in a titanium housing, a two-leaf SOLAR WING along the side, tiny RCS thruster nozzles and one
-- green status light. The guns are RESCULPTED models (WeaponAssets.SkinModels.Orbiter_<GUN>, built by
-- tools/skins_v3/orbiter_build.py in art/weapons/SkinsV3_Orbiter.blend, painted by tools/skin_v3_paint.py with
-- tools/skins_v3/orbiter.json: crinkled foil, solar cells and busbars, heat-shield tiles); this module brings their motion:
--   WHEEL    the reaction wheel always turns slowly, spins up with every shot and the streak, races on the inspect
--   WING     drawn, the hinged leaf of the solar wing swings out from over its twin and lies flat (DEPLOY); the inspect
--            tilts it out a little to track the sun; a reload folds it back over its twin, the magazine leaves with a
--            puff of the RCS (SEPARATION) and the new one DOCKS (a clamp click + the status light flaring)
--   GLINT    a sheen of light crosses the solar cells every few seconds
--   STATUS   a small green status light blinks slowly and steadily
--   RCS      tiny thruster puffs: on the draw, along the body on the inspect, at the magazine on a reload
-- Muzzle: a small flash, a green nozzle ring and a puff. Tracer: a thin green line with a soft exhaust trail. Impact: a
-- small green spark burst + drifting gold-foil flakes. Kill ZERO-G: a soft green column lifts the body: it floats up,
-- turning slowly, foil flakes drifting, and fades with a soft flash. Banner: a round mission patch with an orbit ring --
-- each kill puts a satellite on the orbit, at five the ring closes. Original design (plan "Originality"): actual
-- spacecraft materials (MLI foil, solar cells, a reaction wheel, RCS puffs, docking) and a zero-g finisher -- no 50s
-- enamel + chrome fins, no lit capsule row, no white armour, no star emblem.
-- ===================================================================================================================
local Set = { Kind = "Orbiter" }

local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local V = Vector3.new
-- (ORBITER v2, skins9; owner on the v2 renders: "Im not sure I like the colors, but the design is good" -> picked the default:
-- WHITE + ORANGE (off-white painted body, safety-orange bands / latches / stencils, black cells, titanium hardware); the
-- others Bright Gold + White, Silver Foil + Red, Black + Violet. Foil = the main body colour, Tile = the accent)
local PALETTES = {
    { Name = "Launch White", Body = C(16, 16, 20), Foil = C(164, 160, 152), Thermal = C(22, 22, 24), Tile = C(214, 84, 18), Ti = C(146, 150, 158),
      Lume = C(255, 140, 40), Hot = C(255, 220, 180), Text = C(246, 242, 236), Ink = C(10, 8, 6), Plate = C(60, 58, 54), Jacket = C(66, 68, 74) },
    { Name = "Bright Gold", Body = C(16, 16, 20), Foil = C(190, 142, 36), Thermal = C(22, 22, 24), Tile = C(166, 162, 154), Ti = C(146, 150, 158),
      Lume = C(255, 214, 110), Hot = C(255, 244, 210), Text = C(250, 244, 226), Ink = C(10, 8, 4), Plate = C(70, 54, 18), Jacket = C(66, 68, 74) },
    { Name = "Silver Foil", Body = C(18, 18, 22), Foil = C(142, 144, 150), Thermal = C(22, 22, 24), Tile = C(184, 28, 28), Ti = C(120, 124, 132),
      Lume = C(255, 72, 60), Hot = C(255, 210, 200), Text = C(244, 240, 240), Ink = C(8, 4, 4), Plate = C(56, 56, 62), Jacket = C(60, 62, 68) },
    { Name = "Black Violet", Body = C(30, 24, 44), Foil = C(30, 28, 34), Thermal = C(16, 16, 18), Tile = C(116, 56, 196), Ti = C(110, 108, 122),
      Lume = C(180, 120, 255), Hot = C(232, 214, 255), Text = C(232, 226, 250), Ink = C(6, 4, 10), Plate = C(26, 22, 36), Jacket = C(24, 22, 28) },
}
local P = PALETTES[VAR] or PALETTES[1]
local BODY, FOIL, THERMAL, TI, LUME, HOT = P.Body, P.Foil, P.Thermal, P.Ti, P.Lume, P.Hot
Set.Palettes = PALETTES
Set.Colors = { Glow = LUME, Hot = HOT, Accent = FOIL, Mid = TI }
-- art (tools/make_orbiter_art.py, uploaded as decals; these are the IMAGE ids, resolved in Studio)
local A = "rbxassetid://"
Set.Art = {
    EmblemOrbiter = "rbxassetid://112304594858214", ob_emblem = "rbxassetid://112304594858214", ob_emblem_mask = "rbxassetid://93481048322651", ob_patch = "rbxassetid://80768927543118", ob_orbit = "rbxassetid://123474266499955", ob_ring = "rbxassetid://134325533725984",
    ob_flake = "rbxassetid://127344311697345", ob_column = "rbxassetid://96262618578061", ob_corner = "rbxassetid://113929604100571", tex_ob_cells = "rbxassetid://109106474171169", tex_ob_bar = "rbxassetid://114847927316726",
}
local ART = Set.Art

local TAU = math.pi * 2
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

-- the RCS nozzles of each sculpt (gun-space studs, from tools/skins_v3/orbiter_build.py) + their puff direction
local RCS = {
    P90 = { { C = V(-0.74, 0.128, -0.085), D = V(0, 0, -1) }, { C = V(-0.62, 0.128, -0.085), D = V(0, 0, -1) },
        { C = V(-0.37, 0.13, -0.07), D = V(0, 0, -1) }, { C = V(0.43, 0.13, -0.07), D = V(0, 0, -1) } },   -- (v2: the capsule's two)
    F2000 = { { C = V(-1.0, 0.185, -0.075), D = V(0, 0, -1) }, { C = V(0.74, -0.05, -0.075), D = V(0, 0, -1) } },
    -- (v2: the docking ring's three guide pins replace the thruster quad)
    QuadBeam = { { C = V(1.665, 0.143, 0.162), D = V(1, 0, 0) }, { C = V(1.665, 0.283, -0.081), D = V(1, 0, 0) },
        { C = V(1.665, 0.003, -0.081), D = V(1, 0, 0) } },
}

local function GunDesc(gun: string): string
    local what = (gun == "F2000") and "the bullpup body a satellite bus in crinkled gold foil with a solar wing, and a folded dish antenna that swings out on the draw and slowly scans"
        or (gun == "QuadBeam") and "a foil-blanketed body with a solar wing, and a heavy docking ring round both emitters that spins up as you fire"
        or "the body and stock in crinkled gold foil, and a ceramic payload capsule for a magazine: through its window a tiny satellite floats, tumbling faster as you fire"
    return "Real spacecraft hardware: " .. what .. ". Black equipment bays with their own stencils, a reaction wheel that never stops turning, RCS puffs and one green status light. Green exhaust tracers, gold foil flakes on impact, and every kill floats away in ZERO-G."
end

-- ===== the guns =====
Set.GunSkins = {
    { Id = "OrbiterP90", Name = "Orbiter P90", Gun = "P90", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("P90"),
      Model = "Orbiter_P90", V3 = true, Color = LUME, Deco = "OrbiterGun", Fit = { G = "P90" } },
    { Id = "OrbiterF2000", Name = "Orbiter FAMAS", Gun = "F2000", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("F2000"),
      Model = "Orbiter_F2000", V3 = true, Color = LUME, Deco = "OrbiterGun", Fit = { G = "F2000" } },
    { Id = "OrbiterQuadBeam", Name = "Orbiter Quadbeam", Gun = "QuadBeam", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("QuadBeam"),
      Model = "Orbiter_QuadBeam", V3 = true, Color = LUME, BeamColor = LUME, Deco = "OrbiterGun", Fit = { G = "QuadBeam" } },
}

-- ===== small Roblox bits: the RCS puff emitters (attachments on the frame) + the magazine's separation puff =====
local function Puff(H: any, att: Attachment, dir: Vector3, name: string, forView: boolean)
    att.Axis = dir
    return H.Emitter(att, { Name = name, Texture = H.SMOKE, Color = { C(235, 240, 248), C(190, 196, 206) }, Size = { 0.025, forView and 0.16 or 0.24 },
        Life = { 0.22, 0.4 }, Speed = { 1.4, 2.6 }, Spread = 12, Trans = { 0.35, 1 }, Light = 0, Influence = 1, Drag = 6, Dir = Enum.NormalId.Right, SkinFx = true })
end
Set.Build = {}
-- (gate, skins9: ONE puff emitter per gun -- the gate allows two per piece. Its attachment is moved to each RCS nozzle /
-- the magazine before every Emit; particles stay where they were born.)
Set.Build.OrbiterGun = function(model: Model, frame: BasePart, f: any, forView: boolean, H: any)
    local pts = RCS[f.G or ""] or {}
    local a = Instance.new("Attachment")
    a.Name = "OBRcs"
    a.Position = pts[1] and pts[1].C or V(0, 0, 0)
    a.Parent = frame
    a:SetAttribute("OBGun", f.G or "")
    Puff(H, a, pts[1] and pts[1].D or V(0, 0, -1), "OBRcs", forView)
end
-- ===== sounds (tools/skins_v3/orbiter_sfx.py: each gun's own recorded shot + a helmet-muffled body and a soft radio-click
-- tail; the moments from CC0 recordings -- tools/sound_sources.json). Id 0 = silent until uploaded. =====
Set.Sounds = {
    Equip = { Id = 78406557251363, Volume = 0.42 }, MagOut = { Id = 112791299449828, Volume = 0.32 }, MagIn = { Id = 101285961576415, Volume = 0.36 }, Kill = { Id = 101673794048107, Volume = 0.5 },
    Impact = { Id = 139173822587217, Volume = 0.18 }, Swing = { Id = 93124301708610, Volume = 0.38 }, MeleeHit = { Id = 128850193810169, Volume = 0.42 }, Puff = { Id = 100963479880104, Volume = 0.2 },
    -- (F2000 / Quadbeam shots sit ~2 dB under the plain ones after the peak cap: their volumes are raised to match)
    FireGun = { P90 = { Id = 75279550063656, Volume = 0.8 }, F2000 = { Id = 73699005503640, Volume = 0.95 }, QuadBeam = { Id = 132263897279829, Volume = 1.0 } },
}
local function PlaySound(H: any, d: any, pitch: number?)
    if not d or (d.Id or 0) == 0 then return end
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. tostring(d.Id)
    s.Volume = d.Volume or 0.4
    s.PlaybackSpeed = pitch or 1
    local grp = H.SoundService:FindFirstChild("AimRngMix_Weapons")
    if grp then s.SoundGroup = grp end
    s.Parent = H.SoundService
    s:Play()
    H.Debris:AddItem(s, 2)
end
local function PuffAll(gun: Model?, what: string, n: number)
    -- what = "OBRcs" (every RCS nozzle of this gun) | "OBSep" (the magazine: SEPARATION)
    if not gun then return end
    for _, d in ipairs(gun:GetDescendants()) do
        if d:IsA("ParticleEmitter") and d.Name == "OBRcs" and d.Parent and d.Parent:IsA("Attachment") then
            local a = d.Parent
            local frame = a.Parent
            if what == "OBSep" then
                local mag = gun:FindFirstChild("Magazine", true)
                if mag and mag:IsA("BasePart") then
                    a.WorldPosition = mag.Position + mag.CFrame.UpVector * mag.Size.Y * 0.45
                    a.WorldAxis = mag.CFrame.UpVector
                    d:Emit(n)
                end
            else
                local pts = RCS[a:GetAttribute("OBGun") or ""] or {}
                local k = math.max(1, math.ceil(n / math.max(1, #pts)))
                for _, r in ipairs(pts) do
                    a.Position = r.C
                    a.Axis = r.D
                    d:Emit(k)
                end
            end
            return
        end
    end
end

-- ===== motion: every key the parts read =====
-- st.Wheel (the reaction wheel's angle), st.Fold (1 = the wing's leaf folded over its twin, 0 = flat, > 0 small = tilted
-- out), st.Glint / st.GlintA (the sheen crossing the cells), st.Status (the status light). v = rig.SkinVars / rec.Vars
local function Keys(st: any, v: any, dt: number, now: number, anim: string?, animT: number?, beats: any?)
    local ss = st.SinceShot or 99
    local se = st.SinceEquip or 99
    local streak = math.min(st.Streak or 0, 5)
    local rl = st.Reload or 0
    local insp = anim == "Inspect" and animT or nil
    -- the reaction wheel: never still; every shot spins it up; the inspect races it
    local spin = 0.9 + 0.3 * streak + 7 * math.exp(-ss / 0.35)
    if insp then
        local a, s = (beats and beats.Present) or 0.6, (beats and beats.Settle) or 2.9
        spin += 14 * smooth((insp - a) / 0.4) * (1 - smooth((insp - s + 0.3) / 0.4))
    end
    if se < 0.6 then spin += 10 * (1 - se / 0.6) end
    v.WheelA = ((v.WheelA or 0) + spin * dt) % (TAU * 64)
    st.Wheel = v.WheelA
    -- the solar wing: deploys on the draw, folds for a reload, tilts out on the inspect
    local fold = 0
    if se < 0.65 then fold = 1 - smooth((se - 0.18) / 0.42) end
    if rl > 0 then
        if rl < 0.18 then fold = math.max(fold, smooth(rl / 0.18))
        elseif rl < 0.78 then fold = 1
        else fold = math.max(fold, 1 - smooth((rl - 0.78) / 0.17)) end
    end
    if insp then
        local a, b, s = (beats and beats.Present) or 0.6, (beats and (beats.Tilt or beats.Flip or beats.Rack)) or 1.9, (beats and beats.Settle) or 2.9
        local tilt = 0.13 * smooth((insp - a) / 0.5) * (1 - smooth((insp - s + 0.4) / 0.4))
        tilt += 0.04 * math.sin(math.clamp((insp - b) / 0.6, 0, 1) * math.pi)   -- (a small extra lean on the signature beat)
        fold = math.max(fold, tilt)
    end
    st.Fold = fold
    -- the glint: a sheen crosses the cells every ~4.2 s (and once on the draw)
    local gp = (now % 4.2) / 0.9
    if se < 1.2 then gp = math.clamp((se - 0.5) / 0.6, 0, 1.01) end
    if gp < 1 then st.Glint = gp; st.GlintA = math.sin(gp * math.pi) * 0.9 else st.GlintA = 0 end
    -- the status light: a slow steady blink; a seated magazine (DOCKED) holds it on for a moment
    local blink = ((now % 1.8) < 0.14) and 1 or 0.18
    local dk = v.DockT and (now - v.DockT) or 99
    if dk < 0.7 then blink = math.max(blink, 1 - dk / 0.9) end
    if se < 0.5 then blink = ((se % 0.2) < 0.1) and 1 or 0.2 end
    st.Status = blink
    -- (v2) the P90's floating PAYLOAD tumbles slowly, faster with every shot and the streak
    v.PayA = ((v.PayA or 0) + (0.7 + 0.25 * streak + 5 * math.exp(-ss / 0.4) + (insp and 2.5 or 0)) * dt) % (TAU * 64)
    st.Payload = v.PayA
    -- (v2) the F2000's DISH: folded flat until the draw swings it out, then it nods slowly as it scans; a reload tucks it in
    local dep = 0.82 + 0.12 * math.sin(now * 0.7)
    if se < 0.75 then dep = dep * smooth((se - 0.15) / 0.5) end
    if rl > 0 then dep = dep * (1 - 0.7 * math.sin(math.clamp(rl, 0, 1) * math.pi)) end
    if insp then dep = math.max(dep, 1) end
    st.Deploy = dep
    -- (v2) the Quadbeam's DOCKING RING turns slowly and spins up with the fire rate
    v.RingA = ((v.RingA or 0) + (0.5 + 0.2 * streak + 9 * math.exp(-ss / 0.3) + (se < 0.6 and 6 * (1 - se / 0.6) or 0)) * dt) % (TAU * 64)
    st.Ring = v.RingA
end
local function MeleeKeys(st: any, v: any, now: number)
    -- the glaive's blade folds down beside the boom until the draw swings it up (DEPLOY); its cell strip breathes and
    -- brightens on the inspect / a swing
    local se = st.SinceEquip or 99
    st.Deploy = 1 - smooth((se - 0.1) / 0.4)
    local sw = v.SwingT and (os.clock() - v.SwingT) or 99
    st.Strip = math.clamp(0.4 + 0.2 * math.sin(now * 1.6) + 0.5 * (st.Inspect or 0) + 0.5 * math.exp(-sw / 0.25), 0, 1)
end
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    local v = rig.SkinVars
    if rig.Def and rig.Def.IsMelee then MeleeKeys(st, v, now) return end
    -- (ViewmodelRig writes st.Anim / st.AnimT only AFTER the set's Drive: read the anim from the rig itself)
    local beats = (rig.AnimName == "Inspect" and rig.Anim and rig.Anim.Beats) or nil
    Keys(st, v, dt, now, rig.AnimName, rig.AnimTime, beats)
    -- the draw's thruster puff (once, as the wing starts to swing out)
    local se = st.SinceEquip or 99
    if se < 0.3 and not v.EquipPuffed and se > 0.15 then
        v.EquipPuffed = true
        PuffAll(rig.Gun, "OBRcs", 3)
        PlaySound(H, Set.Sounds.Puff, 0.95 + 0.1 * math.random())
    elseif se > 0.6 then
        v.EquipPuffed = false
    end
end
Set.InspectEvents = { { "Present+0.2", "OBPuff" }, { "Tilt", "OBPuff" }, { "Settle-0.4", "OBPuff" } }
Set.OnEvent = function(rig: any, name: string, H: any, data: any)
    local v = rig.SkinVars
    if not v then return end
    if name == "OBPuff" or name == "Flip" then
        PuffAll(rig.Gun, "OBRcs", 4)
        PlaySound(H, Set.Sounds.Puff, 0.9 + 0.2 * math.random())
    elseif name == "MagOut" then
        PuffAll(rig.Gun, "OBSep", 6)                -- SEPARATION
    elseif name == "MagIn" or name == "ShellIn" then
        v.DockT = os.clock()                        -- DOCKED
    end
end
Set.OnAnim = function(rig: any, name: string)
    if rig.Def and rig.Def.IsMelee and (name:find("Light") or name:find("Heavy") or name:find("Quick")) then rig.SkinVars.SwingT = os.clock() end
end
-- other players' guns: the wheel turning, the glint, the status light; now and then a tilt of the wing
Set.World = function(rec: any, now: number, st: any)
    local v = rec.Vars
    local dt = v.LastNow and math.clamp(now - v.LastNow, 0, 0.2) or 0
    v.LastNow = now
    st.SinceShot = 99; st.SinceEquip = 99; st.Reload = 0; st.Streak = 1
    Keys(st, v, dt, now, nil, nil, nil)
end

-- ===== muzzle: a small flash, a green nozzle ring, a soft puff (no fireball) =====
Set.Muzzle = function(rig: any, flash: ParticleEmitter, light: PointLight, muzzle: Attachment, H: any)
    flash.Color = ColorSequence.new(HOT, LUME)
    flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.02) })
    light.Color = LUME
    light.Brightness = 0.6
    -- (gate, skins9: Speed 1.5-2.5 -- with Speed 0 a VelocityPerpendicular ring has no velocity to face along and can draw as a
    -- screen-wide triangle, FISSION's lesson; the soft puff now rides the engine's own muzzle smoke, recoloured)
    rig.Fx.OBRing = H.Emitter(muzzle, { Name = "OBRing", Texture = ART.ob_ring ~= "" and ART.ob_ring or H.SPARK, Color = { HOT, LUME }, Size = { 0.05, 0.3 },
        Life = { 0.09, 0.1 }, Speed = { 1.5, 2.5 }, Trans = { 0.15, 1 }, Light = 1, Orient = Enum.ParticleOrientation.VelocityPerpendicular,
        Dir = Enum.NormalId.Right, Spread = 0 })
    if rig.Fx and rig.Fx.Smoke then rig.Fx.Smoke.Color = ColorSequence.new(C(225, 232, 240), C(170, 176, 186)) end
end
Set.OnFire = function(rig: any, H: any)
    if rig.Fx and rig.Fx.OBRing then rig.Fx.OBRing:Emit(1) end
    local v = rig.SkinVars
    if rig.Fx and rig.Fx.Smoke and v then
        v.PuffN = ((v.PuffN or 0) + 1) % 2
        if v.PuffN == 0 then rig.Fx.Smoke:Emit(1) end
    end
end

-- ===== EXHAUST tracer: a thin green line + a soft wider exhaust trail behind it that lingers a moment =====
Set.Tracer = function(H: any, from: Vector3, to: Vector3, peer: boolean?)
    local dist = (to - from).Magnitude
    if dist < 1.5 then return end
    local host = H.FxPart({ Transparency = 1, Size = V(0.05, 0.05, 0.05), CFrame = CFrame.new(from) })
    local a0, a1 = H.Att(host, from), H.Att(host, to)
    local core = Instance.new("Beam")
    core.Attachment0, core.Attachment1 = a0, a1
    core.Color = ColorSequence.new(HOT, LUME); core.LightEmission = 1; core.LightInfluence = 0; core.FaceCamera = true; core.Segments = 1
    core.Width0, core.Width1 = 0.02, 0.03
    core.Parent = host
    local trail = Instance.new("Beam")
    trail.Attachment0, trail.Attachment1 = a0, a1
    trail.Color = ColorSequence.new(LUME, C(200, 210, 220)); trail.LightEmission = 0.4; trail.LightInfluence = 0.3; trail.FaceCamera = true; trail.Segments = 1
    trail.Width0, trail.Width1 = 0.05, peer and 0.14 or 0.2
    trail.Parent = host
    local dir = (to - from).Unit
    local travel = H.TRAVEL -- (hitscan: the shot is there at once, nothing flies)
    local dur = travel + (peer and 0.18 or 0.32)
    H.Animate(dur, function(t)
        local hk = math.clamp(t / travel, 0, 1)
        a1.WorldPosition = from + dir * dist * hk
        local k = math.clamp((t - travel) / (dur - travel), 0, 1)
        core.Transparency = NumberSequence.new(math.clamp(0.05 + k * 1.2, 0, 1))
        trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82 + 0.18 * k), NumberSequenceKeypoint.new(1, 0.6 + 0.4 * k) })
        trail.Width1 = (peer and 0.14 or 0.2) * (1 + 0.8 * k)
    end, function() host:Destroy() end)
end

-- ===== impact: a small green spark burst + three gold-foil flakes drifting off (no light) =====
Set.Impact = function(H: any, pos: Vector3, normal: Vector3?, peer: boolean?)
    if not H.Budget("OrbiterImpact", peer and 3 or 8, 0.4) then return end
    local n = (normal and normal.Magnitude > 0.1) and normal.Unit or V(0, 1, 0)
    local p = H.FxPart({ Transparency = 1, Size = V(0.1, 0.1, 0.1), CFrame = CFrame.lookAt(pos + n * 0.04, pos + n * 2) })
    local att = H.Att(p, pos + n * 0.05)
    local sp = H.Emitter(att, { Texture = H.SPARK, Color = { HOT, LUME }, Size = { 0.06, 0 }, Life = { 0.12, 0.28 }, Speed = { 4, 9 }, Spread = 55,
        Drag = 2, Accel = V(0, -6, 0) })
    sp.EmissionDirection = Enum.NormalId.Front
    sp:Emit(peer and 3 or 7)
    if not peer then
        local fl = H.Emitter(att, { Texture = ART.ob_flake ~= "" and ART.ob_flake or H.SPARK, Color = { FOIL:Lerp(C(255, 230, 160), 0.35), FOIL }, Size = { 0.07, 0.05 },
            Life = { 0.7, 1.1 }, Speed = { 0.6, 1.4 }, Spread = 70, Drag = 2.5, Accel = V(0, -0.8, 0), Light = 0.2, Influence = 1,
            Spin = { -260, 260 }, Rot = { 0, 360 } })
        fl.EmissionDirection = Enum.NormalId.Front
        fl:Emit(3)
    end
    H.Debris:AddItem(p, 1.4)
end

-- ===== ZERO-G v2 kill (FX roll-out 2026-10-14; v1 = a soft green column lifted the whole body a couple of studs: "right
-- idea, but just 'the body lifts'"). ONE idea: gravity switches off. With a hard POP the body breaks into blocks (each part
-- cut in two or three) that drift apart in every direction, slowly tumbling, never falling, gold foil flecks floating among
-- them, while a safety-orange ORBIT RING (~6 studs, tilted, on an ink ring) opens round them and a satellite runs once round
-- it; then the blocks fade out as they drift. 1.4 s. The pieces leave the centre in a burst (fast first, then floating);
-- nothing lit sits on the crosshair. Budget: full <= 12 blocks + ring card + satellite + host = 15 parts, 18 flecks; low:
-- 4 blocks + ring card, 8 flecks. =====
local function ObBody(pos: Vector3, H: any): ({ BasePart }, CFrame, Vector3)
    local op = OverlapParams.new()
    op.FilterType = Enum.RaycastFilterType.Exclude
    local ex = { H.FxFolder() }
    for _, pl in ipairs(H.Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
    if workspace.CurrentCamera then table.insert(ex, workspace.CurrentCamera) end
    op.FilterDescendantsInstances = ex
    local best, count = nil, {}
    for _, p in ipairs(workspace:GetPartBoundsInRadius(pos, 3.5, op)) do
        local m = p:FindFirstAncestorOfClass("Model")
        while m and not (m:FindFirstChild("Head") or m:FindFirstChild("Torso")) do m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model") end
        if m then count[m] = (count[m] or 0) + 1; if not best or count[m] > count[best] then best = m end end
    end
    local out = {}
    if best then
        for _, p in ipairs(best:GetDescendants()) do
            if p:IsA("BasePart") and p.Transparency < 0.6 and p.Size.Magnitude < 12 then table.insert(out, p) end
        end
        table.sort(out, function(a, b) return a.Size.Magnitude > b.Size.Magnitude end)
        local ok, cf, size = pcall(function() return best:GetBoundingBox() end)
        if ok and size.Magnitude < 20 then return out, cf, size end
    end
    return out, CFrame.new(pos - V(0, 1.4, 0)), V(1.8, 3.8, 1.2)
end
Set.Kill = function(H: any, pos: Vector3, low: boolean)
    local parts, bcf, bsz = ObBody(pos, H)
    local center = bcf.Position
    local cam = workspace.CurrentCamera
    local rt = cam and cam.CFrame.RightVector or Vector3.xAxis
    rt = V(rt.X, 0, rt.Z)
    rt = (rt.Magnitude > 0.05) and rt.Unit or Vector3.xAxis
    local base = CFrame.fromMatrix(center, rt, Vector3.yAxis) -- (+Z = toward you)
    local model = Instance.new("Model")
    model.Name = "OrbiterKill"
    model.Parent = H.FxFolder()
    -- 1) the blocks: each body part cut along its long side into 2-3 pieces (its own colour), at most 12
    local cap = low and 4 or 12
    local blocks = {}
    for _, src in ipairs(parts) do
        if #blocks >= cap then break end
        local sz, cf = src.Size, src.CFrame
        local list = { { Vector3.xAxis, sz.X }, { Vector3.yAxis, sz.Y }, { Vector3.zAxis, sz.Z } }
        table.sort(list, function(a, b) return a[2] > b[2] end)
        local ax, L = list[1][1], list[1][2]
        local n = low and 1 or ((L > 1.6) and 3 or ((L > 0.8) and 2 or 1))
        local piece = sz - ax * (L - L / n)
        for i = 1, n do
            if #blocks >= cap then break end
            local off = cf:VectorToWorldSpace(ax * ((i - (n + 1) / 2) * L / n))
            local col = (math.min(src.Color.R, src.Color.G, src.Color.B) > 0.9) and FOIL or src.Color -- (a hit-flash white body: foil)
            local p = H.FxPart({ Material = (src.Material == Enum.Material.Neon) and Enum.Material.Neon or Enum.Material.SmoothPlastic, Color = col,
                Size = piece * 0.94, CFrame = cf + off, Transparency = src.Transparency }, model)
            local out = p.Position - center
            out = (out.Magnitude > 0.1) and out.Unit or V(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5).Unit
            -- (sideways / up / down in your view -- the drift never comes at you)
            out = (out - base.ZVector * out:Dot(base.ZVector) * 0.7).Unit
            table.insert(blocks, { P = p, Pos = p.Position, Rot = cf - cf.Position, T = src.Transparency,
                Vel = out * (5 + math.random() * 2.5) + V(0, 0.6, 0), Spin = V(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.4 })
        end
    end
    -- 2) the orbit ring: the set's orbit art on a tilted card, an ink ring under a safety-orange one
    local R = math.clamp(math.max(bsz.Y, bsz.X) * 0.75, 3, 4.6)
    local tilt = CFrame.Angles(math.rad(62), 0, math.rad(-14))
    local ringPart = H.FxPart({ Transparency = 1, Size = V(R * 2.2, 0.05, R * 2.2), CFrame = base * tilt }, model)
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Top; sg.LightInfluence = 0; sg.AlwaysOnTop = false; sg.CanvasSize = Vector2.new(400, 400); sg.Parent = ringPart
    local ringArt = (ART.ob_ring ~= "" and ART.ob_ring) or ART.ob_orbit
    local inkRing = H.New("ImageLabel", { BackgroundTransparency = 1, Image = ringArt, ImageColor3 = P.Ink, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.92, 0.92), ImageTransparency = 1 }, sg)
    local litRing = H.New("ImageLabel", { BackgroundTransparency = 1, Image = ringArt, ImageColor3 = LUME, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.88, 0.88), ImageTransparency = 1, ZIndex = 2 }, sg)
    -- (the ring draws on its top face only: a second gui on the bottom so it reads from below the tilt too)
    local sg2 = sg:Clone(); sg2.Face = Enum.NormalId.Bottom; sg2.Parent = ringPart
    local ink2, lit2
    for _, c in ipairs(sg2:GetChildren()) do if c.ZIndex == 2 then lit2 = c else ink2 = c end end
    local sat = (not low) and H.FxPart({ Size = V(0.8, 0.45, 0.45), Color = HOT, Transparency = 1, CFrame = base }, model) or nil
    -- 3) the foil flecks: gold flakes tumbling slowly in place, no gravity
    local host = H.FxPart({ Transparency = 1, Size = V(math.max(1.4, bsz.X), math.max(2, bsz.Y * 0.8), 1), CFrame = base }, model)
    local fl = H.Emitter(host, { Name = "ObFlecks", Texture = ART.ob_flake ~= "" and ART.ob_flake or H.SPARK, Color = { FOIL:Lerp(C(255, 230, 160), 0.35), FOIL },
        Size = { 0.32, 0.22 }, Life = { 1.0, 1.3 }, Speed = { 1.2, 3.2 }, Spread = 180, Drag = 1.6, Accel = V(0, 0.3, 0), Light = 0.2, Influence = 1,
        Spin = { -160, 160 }, Rot = { 0, 360 } })
    fl.Shape = Enum.ParticleEmitterShape.Box
    fl:Emit(low and 8 or 18)
    H.Animate(1.4, function(t, dt)
        local step = math.clamp(dt, 0, 1 / 20)
        -- the POP: a 0.06 s jolt outward, then floating (drag 1.6/s: they slow but never stop, never fall)
        local fade = math.clamp((t - 0.95) / 0.45, 0, 1)
        for _, b in ipairs(blocks) do
            b.Vel *= math.exp(-2.2 * step)
            b.Pos += b.Vel * step
            b.Rot = b.Rot * CFrame.Angles(b.Spin.X * step, b.Spin.Y * step, b.Spin.Z * step)
            b.P.CFrame = CFrame.new(b.Pos) * b.Rot
            b.P.Transparency = math.clamp(b.T + fade, 0, 1)
        end
        -- the ring opens (0.04 -> 0.3), turns slowly, the satellite runs once round it, both fade with the blocks
        local open = 1 - (1 - math.clamp((t - 0.04) / 0.26, 0, 1)) ^ 3
        local spin = CFrame.Angles(0, t * 0.6, 0)
        local rcf = base * tilt * spin
        ringPart.CFrame = rcf
        local s = 0.3 + 0.58 * open
        litRing.Size = UDim2.fromScale(s, s); lit2.Size = litRing.Size
        inkRing.Size = UDim2.fromScale(s * 1.05, s * 1.05); ink2.Size = inkRing.Size
        local rt2 = math.clamp(1 - open + fade, 0, 1)
        litRing.ImageTransparency = rt2; lit2.ImageTransparency = rt2
        inkRing.ImageTransparency = math.clamp(1 - 0.7 * open + fade, 0, 1); ink2.ImageTransparency = inkRing.ImageTransparency
        if sat then
            local a = -t * (math.pi * 2 / 1.1)
            local r = R * 2.2 * s * 0.5
            sat.CFrame = rcf * CFrame.new(math.cos(a) * r, 0.1, math.sin(a) * r) * CFrame.Angles(0, -a, 0)
            sat.Transparency = math.clamp(1 - open + fade, 0, 1)
        end
    end, function() model:Destroy() end)
end

-- ===== MISSION PATCH banner (beside the HUD's weapon card, <= 180 x 90): a round patch with an orbit ring; each kill puts
-- a satellite on the orbit; at five the ring closes (lit all the way round) =====
local banner
local NUMFONT = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold)
Set.Banner = function(H: any, streak: number)
    local gui, root = H.BannerRoot("Orbiter", Vector2.new(180, 90), "Side")
    if not root then return end
    local New = H.New
    if not banner or banner.Root ~= root then
        local glow = New("ImageLabel", { BackgroundTransparency = 1, Image = H.Art.Glow, ImageColor3 = LUME, AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(120, 120), Position = UDim2.fromOffset(45, 45), ImageTransparency = 0.92, ZIndex = 1 }, root)
        local plate = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.ob_patch, ImageColor3 = P.Plate:Lerp(C(255, 255, 255), 0.15),
            Size = UDim2.fromOffset(84, 84), Position = UDim2.fromOffset(3, 3), ZIndex = 2 }, root)
        local world = New("Frame", { BorderSizePixel = 0, BackgroundColor3 = LUME:Lerp(C(0, 0, 0), 0.25), AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(45, 46), Size = UDim2.fromOffset(16, 16), ZIndex = 4 }, root, { New("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        local orbit = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.ob_orbit, ImageColor3 = P.Text, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(45, 46), Size = UDim2.fromOffset(66, 30), Rotation = -22, ImageTransparency = 0.45, ZIndex = 3 }, root)
        local sats = {}
        for i = 1, 5 do
            sats[i] = New("Frame", { BorderSizePixel = 0, BackgroundColor3 = FOIL:Lerp(C(255, 230, 160), 0.4), AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromOffset(7, 7), ZIndex = 5 }, root, { New("UICorner", { CornerRadius = UDim.new(0.3, 0) }) })
        end
        local num = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(96, 42), Size = UDim2.fromOffset(80, 40),
            FontFace = NUMFONT, TextSize = 32, TextColor3 = P.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 6 }, root)
        num:SetAttribute("KeepFont", true)
        New("UIStroke", { Color = P.Ink, Thickness = 2 }, num)
        banner = { Root = root, Plate = plate, World = world, Orbit = orbit, Sats = sats, Glow = glow, Num = num, Token = 0 }
    end
    local b = banner
    b.Token += 1
    local token = b.Token
    local st = math.clamp(streak or 1, 1, 5)
    root.Visible = true
    b.Plate.ImageTransparency = 0
    b.World.BackgroundTransparency = 0
    b.Num.TextTransparency = 0
    b.Num.Text = "x" .. st
    b.Num.TextColor3 = (st >= 5) and LUME or P.Text
    b.Orbit.ImageTransparency = 0.45
    b.Orbit.ImageColor3 = P.Text
    -- satellite i sits at an angle on the tilted ellipse
    local function SatPos(i, extra)
        local a = math.rad(-150 + (i - 1) * 62 + (extra or 0))
        local ex, ey = math.cos(a) * 31, math.sin(a) * 13
        local r = math.rad(-22)
        return 45 + ex * math.cos(r) - ey * math.sin(r), 46 + ex * math.sin(r) + ey * math.cos(r)
    end
    for i, s in ipairs(b.Sats) do
        local x, y = SatPos(i)
        s.Position = UDim2.fromOffset(x, y)
        s.BackgroundTransparency = (i < st) and 0 or 1
    end
    H.Animate(0.45, function(t)
        if b.Token ~= token then return end
        local k = t / 0.45
        -- the newest satellite slides onto the orbit from behind the world, settling into its slot
        local s = b.Sats[st]
        local x, y = SatPos(st, -50 * (1 - smooth(k)))
        s.Position = UDim2.fromOffset(x, y)
        s.BackgroundTransparency = math.clamp(1 - k * 2.5, 0, 1)
        if st >= 5 then
            -- the ring closes: it lights all the way round
            b.Orbit.ImageColor3 = P.Text:Lerp(LUME, smooth(k))
            b.Orbit.ImageTransparency = 0.45 - 0.4 * smooth(k)
            b.Glow.ImageTransparency = 0.92 - 0.45 * math.sin(k * math.pi)
        end
    end)
    task.delay(1.6, function()
        if b.Token ~= token then return end
        local ti = TweenInfo.new(0.3)
        for _, o in ipairs({ b.Plate, b.Orbit, b.Glow }) do H.TweenService:Create(o, ti, { ImageTransparency = 1 }):Play() end
        for _, s in ipairs(b.Sats) do H.TweenService:Create(s, ti, { BackgroundTransparency = 1 }):Play() end
        H.TweenService:Create(b.World, ti, { BackgroundTransparency = 1 }):Play()
        H.TweenService:Create(b.Num, ti, { TextTransparency = 1 }):Play()
        task.delay(0.32, function() if b.Token == token then root.Visible = false end end)
    end)
end

-- ===== the ANTENNA GLAIVE (melee, Spear class): WeaponAssets.MeleeModels.Orbiter -- a boom of gold-foil segments between
-- titanium collars, black thermal grips for both hands, a thruster-bell pommel, a ring of ceramic tiles under the socket;
-- the head = a flat swept blade (titanium frame, solar-cell insert, a bright worked edge) with a green cell strip along its
-- spine, folded down beside the boom until the draw swings it up =====
Set.Melee = {
    Skin = { Name = "Antenna Glaive", Price = 449, ProductId = 0,
        Desc = "A boom of gold-foil-wrapped segments joined by titanium collars, black thermal grips for both hands and a little thruster bell for a pommel. Its head is an antenna that folds out into a flat swept blade: a titanium frame round a solar-cell insert, a bright worked edge and a green cell strip down its spine. Drawn, the blade swings up and locks. Every kill floats away in ZERO-G." },
    -- (skins9: the class PresentDir put the long glaive's head right on the crosshair -- tipped up so it rests up and right of it)
    Rig = { Class = "Spear", BladeLen = 2.2, PresentDir = V(-0.12, 0.46, -0.88) },
    FlatBlade = true,
    InspectEvents = { { "Flip", "OBGlaive" } },
    Build = function(m: Model, o: any, H: any)
        local parts = H.CloneModel(m, "MeleeModels", "Orbiter", VAR, { [1] = LUME })
        local blade = parts.Blade
        if not blade then return end
        -- the swing trail along the edge (melee space: the edge runs (0.2, 2.36) -> (0.02, 2.93))
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Name, a1.Name = "TrailBase", "TrailTip"
        a0.Position = blade.CFrame:PointToObjectSpace(V(0.2, 2.3, 0))
        a1.Position = blade.CFrame:PointToObjectSpace(V(0.03, 2.9, 0))
        a0.Parent, a1.Parent = blade, blade
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Color = ColorSequence.new(HOT, LUME)
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
        tr.LightEmission = 0.7; tr.LightInfluence = 0
        tr.Lifetime = 0.14; tr.MinLength = 0.02; tr.FaceCamera = true
        tr.Enabled = false
        tr:SetAttribute("SwingTrail", true)
        tr.Parent = blade
    end,
}

-- ===== arms: EVA GLOVES + FLIGHT JACKET SLEEVES (sculpted mesh pieces, WeaponAssets.ArmsModels.Orbiter) =====
-- glove: a navy glove with a gold-foil knuckle shield (titanium rim, rivets) and a titanium wrist ring; ONE effect: a tiny
-- green beacon on the ring blinks slowly and steadily. Sleeve: a padded navy nylon flight-jacket sleeve (three soft
-- quilted rolls, side seams) with a ribbed knit cuff and an abstract gold-foil mission patch.
Set.Glove = function(K: any)
    local V3 = K.V
    return {
        Id = "EVAGloves", Name = "EVA Gloves", Price = 449,
        Desc = "EVA gloves with a crinkled gold-foil knuckle shield in a titanium rim and a titanium wrist ring. A tiny green beacon on the ring blinks slowly and steadily. Part of the Orbiter set.",
        Base = { Color = P.Jacket, Material = Enum.Material.SmoothPlastic, Reflectance = 0 },
        Parts = {
            { Mesh = "Orbiter/Shield", MeshV = VAR, Uniform = true, Size = V3(0.88, 0.09, 0.42), Off = V3(0, 0.5, -0.22), OffW = V3(0, 0.045, 0), Seat = true },
            { Mesh = "Orbiter/Ring", MeshV = VAR, Size = V3(1.12, 1.12, 0.19), Off = V3(0, 0, 0.42) },
            { Mesh = "Orbiter/Beacon", MeshV = VAR, Glow = true, Color = LUME, Uniform = true, Size = V3(0.12, 0.045, 0.12), Off = V3(0, 0.56, 0.42),
              Seat = true, Anim = "Pulse", PulseMin = 0.15, PulseMax = 0.75, Speed = 1.1, FlashOn = "Kill" },
        },
    }
end
Set.Sleeve = function(K: any)
    local V3 = K.V
    return {
        Id = "FlightJacketSleeves", Name = "Flight Jacket Sleeves", Price = 299,
        Desc = "A padded nylon flight-jacket sleeve -- soft quilted rolls and side seams -- with a ribbed knit cuff and an abstract gold-foil mission patch. Part of the Orbiter set.",
        Base = { Color = P.Jacket, Material = Enum.Material.SmoothPlastic, Reflectance = 0 },
        Parts = {
            { Mesh = "Orbiter/Jacket", MeshV = VAR, Size = V3(1.1, 1.1, 0.92), Off = V3(0, 0, 0.02) },
            { Mesh = "Orbiter/Cuff", MeshV = VAR, Size = V3(1.16, 1.16, 0.09), Off = V3(0, 0, -0.45) },
            { Mesh = "Orbiter/Patch", MeshV = VAR, Uniform = true, Size = V3(0.5, 0.035, 0.5), Off = V3(0, 0.56, 0.1), Seat = true },
        },
    }
end

-- ===== health bar: a solar-panel bar (cells as segments), a green fill; a hit dims one cell for a moment (no flash) =====
Set.Bar = { Id = "Orbiter", Name = "Orbiter", Price = 149,
    Desc = "A solar-panel bar -- each segment a cell -- with a safety-orange fill. Lost health floats away: the piece breaks into little blocks that drift UP out of the bar in zero-g. On elites and bosses a hit dims the cell at the end of the fill. Part of the Orbiter set.",
    Look = "Ink", FillColor = LUME, Tex = "tex_ob_bar", TexColor = LUME:Lerp(HOT, 0.25), TexSpeed = 0, ChipMotion = "Drain", Chip = HOT,
    Back = C(8, 10, 22), Glow = LUME, Segments = 5, Decor = { "ZeroGChip", "CellDim" } }
Set.BarDecor = {
    -- (BARS v2) ZERO-G CHIP: the piece a hit knocks off breaks into blocks that drift up out of the bar, turning, and fade
    ZeroGChip = function(ctx: any, K: any)
        local N = (ctx.Tier == "Small") and 3 or 5
        local bits = {}
        for i = 1, N do
            local b = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = HOT, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 13 }, ctx.Holder)
            K.New("UIStroke", { Color = P.Ink, Thickness = 1 }, b)
            bits[i] = { F = b, T = 99 }
        end
        local nxt = 1
        return function(now, dt, alpha, info)
            if (info.Drop or 0) > 0.004 then
                local x0, x1 = info.DropX0 or 0, info.DropX1 or 0
                for _ = 1, 2 do
                    local b = bits[nxt]; nxt = nxt % N + 1
                    b.T, b.X, b.Y = 0, x0 + math.random() * math.max(2, x1 - x0), ctx.H / 2
                    b.VX, b.VY, b.R = (math.random() - 0.5) * 14, -(10 + math.random() * 14), (math.random() - 0.5) * 200
                end
            end
            local s = math.max(3, math.floor(ctx.H * 0.6))
            for _, b in ipairs(bits) do
                b.T += dt
                local k = b.T / 0.9
                if k < 1 then
                    b.F.Size = UDim2.fromOffset(s, s)
                    b.F.Position = UDim2.fromOffset(b.X + b.VX * b.T, b.Y + b.VY * b.T)
                    b.F.Rotation = b.R * b.T
                    b.F.BackgroundTransparency = 1 - alpha * (1 - k)
                    b.F:FindFirstChildOfClass("UIStroke").Transparency = 1 - alpha * (1 - k)
                else
                    b.F.BackgroundTransparency = 1
                    b.F:FindFirstChildOfClass("UIStroke").Transparency = 1
                end
            end
        end
    end,
    GreenFill = function(ctx: any, K: any)
        for _, c in ipairs(ctx.Inner:GetChildren()) do if c:IsA("ImageLabel") then c.ImageColor3 = LUME:Lerp(C(255, 255, 255), 0.1) end end
        return function() end
    end,
    CellDim = function(ctx: any, K: any)
        if ctx.Tier == "Small" then return function() end end
        local cell = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = C(4, 6, 14), BackgroundTransparency = 1, ZIndex = 12 }, ctx.Holder)
        local k, lastHit = 1, 0
        return function(now, dt, alpha, info)
            if (info.Hit or 0) > lastHit + 0.05 then k = 0 end
            lastHit = info.Hit or 0
            k = math.min(1, k + dt / 0.5)
            local w = ctx.W / 5
            local x = ctx.W * math.clamp(info.Shown, 0, 1)
            cell.Size = UDim2.fromOffset(w, ctx.H)
            cell.Position = UDim2.fromOffset(math.max(0, x - w), 0)
            cell.BackgroundTransparency = 1 - alpha * (1 - k) * 0.55
        end
    end,
}

local P1 = PALETTES[1]
-- ===== UI theme v2 (FX roll-out 2026-10-14; v1 = the shared template: 4 corner sprites + watermark + star + mote ambient +
-- the shared Sweep). Its own pieces in the icon look: strips of gold FOIL TAPE stuck diagonally across every window corner
-- (faceted foil, ink edge, a titanium rivet each), a small SATELLITE (an orange body with two solar wings) that makes a slow
-- lap of the window's edge, a mission STATUS row under every title (an orange stencil bar + a green status light blinking
-- slowly), and windows open with the tape PEELING: each strip starts lifted and big, swings down and presses flat onto its
-- corner. Colours from the theme table. =====
local function ObFacet(ctx, o, lit, shade, th)
    local g = Instance.new("UIGradient")
    g.Color = ctx.UIStyle.Facet(lit, shade)
    g.Rotation = ctx.UIStyle.FACET_ROT or 20
    g.Parent = o
    if th then ctx.UIStyle.InkEdge(th).Parent = o end
    return g
end
local function ObDeco(ctx)
    local t = ctx.Theme
    if ctx.Kind ~= "Window" then return nil end -- (HUD panels stay clean)
    local host = ctx.Root or ctx.Surface
    local f = Instance.new("Frame")
    f.Name = "ObOverlay"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 20; f.Active = false; f.ClipsDescendants = true
    f:SetAttribute("NoSkin", true); f:SetAttribute("Skinned", true)
    f.Parent = host
    local abs = host.AbsoluteSize
    local small = math.min(abs.X, abs.Y) < 260
    local len = math.clamp(math.floor(math.min(abs.X, abs.Y) * 0.15), small and 24 or 44, small and 40 or 80)
    local th = small and 9 or 16
    for _, c in ipairs({ { 0, 0, -45 }, { 1, 0, 45 }, { 0, 1, 45 }, { 1, 1, -45 } }) do
        local tape = Instance.new("Frame")
        tape.Name = "ObTape"; tape.BorderSizePixel = 0; tape.BackgroundColor3 = Color3.new(1, 1, 1); tape.AnchorPoint = Vector2.new(0.5, 0.5)
        tape.Size = UDim2.fromOffset(len, th); tape.Rotation = c[3]
        local inset = len * 0.15 -- (tight in the corner: further in it covered the title / close button)
        tape.Position = UDim2.new(c[1], (c[1] == 0) and inset or -inset, c[2], (c[2] == 0) and inset or -inset)
        tape.ZIndex = f.ZIndex + 1; tape.Parent = f
        tape:SetAttribute("Rot", c[3])
        ObFacet(ctx, tape, t.FoilLit, t.FoilShade, 2)
        local rv = Instance.new("Frame")
        rv.BorderSizePixel = 0; rv.BackgroundColor3 = t.Ti; rv.AnchorPoint = Vector2.new(0.5, 0.5); rv.Size = UDim2.fromOffset(th * 0.4, th * 0.4)
        rv.Position = UDim2.fromScale(0.5, 0.5); rv.ZIndex = tape.ZIndex + 1; rv.Parent = tape
        local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0.5, 0); cr.Parent = rv
        ctx.UIStyle.InkEdge(1).Parent = rv
    end
    if small then return nil, { f } end
    -- the satellite: a body + two wings, lapping the window edge once every ~40 s
    local sat = Instance.new("Frame")
    sat.Name = "ObSat"; sat.BackgroundTransparency = 1; sat.AnchorPoint = Vector2.new(0.5, 0.5); sat.Size = UDim2.fromOffset(26, 10); sat.ZIndex = f.ZIndex + 2
    sat.Parent = f
    local body = Instance.new("Frame")
    body.BorderSizePixel = 0; body.BackgroundColor3 = t.Accent2; body.AnchorPoint = Vector2.new(0.5, 0.5); body.Size = UDim2.fromOffset(8, 8)
    body.Position = UDim2.fromScale(0.5, 0.5); body.ZIndex = sat.ZIndex + 1; body.Parent = sat
    ctx.UIStyle.InkEdge(1).Parent = body
    for i = -1, 1, 2 do
        local w = Instance.new("Frame")
        w.BorderSizePixel = 0; w.BackgroundColor3 = t.Cell; w.AnchorPoint = Vector2.new(0.5, 0.5); w.Size = UDim2.fromOffset(8, 5)
        w.Position = UDim2.new(0.5, i * 9, 0.5, 0); w.ZIndex = sat.ZIndex; w.Parent = sat
        local st = Instance.new("UIStroke"); st.Color = t.Ti; st.Thickness = 1; st.Parent = w
    end
    local t0 = math.random() * 40
    return function(now, dt)
        local W, Hh = f.AbsoluteSize.X - 12, f.AbsoluteSize.Y - 12
        local per = 2 * (W + Hh)
        local d = ((now + t0) / 40 % 1) * per
        local x, y, rot
        if d < W then x, y, rot = d, 0, 0
        elseif d < W + Hh then x, y, rot = W, d - W, 90
        elseif d < 2 * W + Hh then x, y, rot = W - (d - W - Hh), Hh, 180
        else x, y, rot = 0, Hh - (d - 2 * W - Hh), 270 end
        sat.Position = UDim2.fromOffset(6 + x, 6 + y)
        sat.Rotation = rot
    end, { f }
end
local function ObOpen(ctx)
    -- PEEL: the tape strips start lifted (big, turned up), swing down and press flat onto their corners (0.4 s)
    local f = (ctx.Root and ctx.Root:FindFirstChild("ObOverlay")) or ctx.Frame
    local tapes = {}
    for _, d in ipairs(f:GetChildren()) do
        if d.Name == "ObTape" then
            local sc = d:FindFirstChildOfClass("UIScale") or Instance.new("UIScale"); sc.Parent = d
            table.insert(tapes, { F = d, S = sc, R = d:GetAttribute("Rot") or 0 })
        end
    end
    local t0 = os.clock()
    local conn
    conn = game:GetService("RunService").RenderStepped:Connect(function()
        local a = os.clock() - t0
        for i, tp in ipairs(tapes) do
            local k = math.clamp((a - (i - 1) * 0.05) / 0.25, 0, 1)
            local e = 1 - (1 - k) ^ 3
            local press = (k >= 1) and math.max(0, 1 - (a - (i - 1) * 0.05 - 0.25) / 0.08) or 0
            tp.S.Scale = 1.5 - 0.5 * e - 0.06 * press
            tp.F.Rotation = tp.R + 35 * (1 - e) * ((i % 2 == 0) and 1 or -1)
        end
        if a >= 0.5 then
            conn:Disconnect()
            for _, tp in ipairs(tapes) do tp.S.Scale = 1; tp.F.Rotation = tp.R end
        end
    end)
end
local function ObTitle(ctx)
    -- a mission STATUS row under the title: an orange stencil bar (three cut blocks) + a green status light blinking slowly
    local bar, t = ctx.Title, ctx.Theme
    local row = Instance.new("Frame")
    row.Name = "ObStatus"; row.BackgroundTransparency = 1; row.AnchorPoint = Vector2.new(0, 1); row.Position = UDim2.new(0, 10, 1, -2)
    row.Size = UDim2.fromOffset(120, 5); row.ZIndex = bar.ZIndex + 1; row.Parent = bar
    for i, w in ipairs({ 40, 22, 10 }) do
        local b = Instance.new("Frame")
        b.BorderSizePixel = 0; b.BackgroundColor3 = t.Accent2; b.Size = UDim2.fromOffset(w, 3); b.AnchorPoint = Vector2.new(0, 0.5)
        b.Position = UDim2.new(0, ({ 0, 44, 70 })[i], 0.5, 0); b.ZIndex = row.ZIndex; b.Parent = row
    end
    local led = Instance.new("Frame")
    led.Name = "ObLed"; led.BorderSizePixel = 0; led.BackgroundColor3 = t.Status; led.AnchorPoint = Vector2.new(0, 0.5); led.Size = UDim2.fromOffset(5, 5)
    led.Position = UDim2.new(0, 86, 0.5, 0); led.ZIndex = row.ZIndex; led.Parent = row
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = led
    local tw = ctx.Tween:Create(led, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.75 })
    tw:Play()
    led.Destroying:Connect(function() tw:Cancel() end)
    return { row }
end
-- numbers v3 (SKIN UI 2026-10-29, owner: numbers "unique to the skin and the colorways you have equipped"): ZERO-G. A
-- condensed mission stencil face (Oswald) that floats straight up at a constant speed with no easing, tumbling very slowly as
-- if nothing holds it, while a small satellite (a body in the band colour + two solar wings) orbits it. CRIT = DOCKING: a
-- ring in the status-light colour closes in round the digits and locks on; WEAK SPOT = a lume dot in front (the status
-- light); a KILL = the orbit ring OPENS out and fades (the Zero-G kill) while the satellite runs a fast lap. Every colour is
-- this copy's palette (P = the colourway: Launch White orange, Bright Gold, Silver Foil red, Black Violet).
local OB_WING = (select(3, P.Foil:ToHSV()) > 0.35) and P.Foil or P.Ti -- (Black Violet's foil is black: its wings take titanium)
local function ObMotion(e, age, pa, life)
    local up = 0.4 + 2.0 * (age / life)
    local dir = (e.Seed > math.pi) and 1 or -1
    local scale = 1 + ((pa < 0.07 and age > 0.08) and 0.05 or 0)
    return up, 0.15 * math.sin(e.Seed), scale, 0, 0, dir * age * 9
end
local function ObAccent(e)
    local box = Instance.new("Frame")
    box.Name = "ObZeroG"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 0
    local ring = Instance.new("Frame")
    ring.Name = "Ring"; ring.BackgroundTransparency = 1; ring.AnchorPoint = Vector2.new(0.5, 0.5); ring.Position = UDim2.fromScale(0.5, 0.5)
    ring.ZIndex = 0; ring.Parent = box
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0.5, 0); rc.Parent = ring
    local rs = Instance.new("UIStroke"); rs.Thickness = 2; rs.Parent = ring
    local sat = Instance.new("Frame")
    sat.Name = "Sat"; sat.BackgroundTransparency = 1; sat.AnchorPoint = Vector2.new(0.5, 0.5); sat.Size = UDim2.fromOffset(22, 8); sat.Parent = box
    local body = Instance.new("Frame")
    body.Name = "Body"; body.BorderSizePixel = 0; body.AnchorPoint = Vector2.new(0.5, 0.5); body.Position = UDim2.fromScale(0.5, 0.5)
    body.Size = UDim2.fromOffset(7, 7); body.BackgroundColor3 = P.Tile; body.Parent = sat
    local bs = Instance.new("UIStroke"); bs.Color = P.Ink; bs.Thickness = 1; bs.Parent = body
    for i = -1, 1, 2 do
        local w = Instance.new("Frame")
        w.Name = "Wing"; w.BorderSizePixel = 0; w.AnchorPoint = Vector2.new(0.5, 0.5); w.Position = UDim2.new(0.5, i * 8, 0.5, 0)
        w.Size = UDim2.fromOffset(7, 4); w.BackgroundColor3 = OB_WING; w.Parent = sat
        local ws = Instance.new("UIStroke"); ws.Color = P.Ink; ws.Thickness = 1; ws.Parent = w
    end
    local led = Instance.new("Frame")
    led.Name = "Led"; led.BorderSizePixel = 0; led.AnchorPoint = Vector2.new(0.5, 0.5); led.Size = UDim2.fromOffset(8, 8); led.BackgroundColor3 = P.Lume
    led.Parent = box
    local lc = Instance.new("UICorner"); lc.CornerRadius = UDim.new(0.5, 0); lc.Parent = led
    local ls = Instance.new("UIStroke"); ls.Color = P.Ink; ls.Thickness = 1; ls.Parent = led
    return box
end
local function ObAccentStep(e, box, age, pa, alpha)
    local tb = e.Label.TextBounds
    local now = os.clock()
    local kt = (e.Killed and e.KillAt) and (now - e.KillAt) or nil
    -- the satellite: an orbit round the digits (a fast lap once the kill lands)
    local sat = box:FindFirstChild("Sat")
    if sat then
        local a = age * 6 + e.Seed + (kt and math.min(1, kt / 0.4) * math.pi * 2 or 0)
        local rx, ry = tb.X / 2 + 12, tb.Y * 0.36
        sat.Position = UDim2.new(0.5, math.cos(a) * rx, 0.5, math.sin(a) * ry)
        sat.Rotation = math.deg(a) * 0.25
        sat.ZIndex = (math.sin(a) > 0) and 2 or 0
        for _, c in ipairs(sat:GetChildren()) do
            c.BackgroundTransparency = alpha
            local st = c:FindFirstChildOfClass("UIStroke"); if st then st.Transparency = math.clamp(0.25 + alpha, 0, 1) end
        end
    end
    -- the ring: docking on a crit (closes in, locks on), opening out on a kill
    local ring = box:FindFirstChild("Ring")
    if ring then
        local on = (e.Crit or e.Killed) and not e.Dot
        ring.Visible = on
        if on then
            local rs = ring:FindFirstChildOfClass("UIStroke")
            local base = math.max(tb.X, tb.Y) + 14
            local d, tr
            if kt then -- (the orbit opens out, then stays as a wide faint ring round the drifting number)
                local k = math.min(1, kt / 0.5)
                d = base * (1 + 1.0 * (1 - (1 - k) ^ 2)); tr = 0.1 + 0.45 * k
                rs.Thickness = 2.5 - 1.2 * k
            else
                local k = math.min(1, pa / 0.16)
                d = base * (1 + 0.9 * (1 - k) ^ 2); tr = (k < 1) and 0.1 or 0.35
                rs.Thickness = 2
            end
            ring.Size = UDim2.fromOffset(d, d)
            rs.Color = kt and P.Hot or P.Lume
            rs.Transparency = math.clamp(alpha + tr, 0, 1)
        end
    end
    -- the status light in front of a weak-spot number (it blinks once as it lands)
    local led = box:FindFirstChild("Led")
    if led then
        local on = e.Weak and not e.Dot
        led.Visible = on
        if on then
            led.Position = UDim2.new(0.5, -math.floor(tb.X / 2) - 7, 0.5, -math.floor(tb.Y * 0.28))
            local blink = (age < 0.25 and (age * 16) % 2 > 1) and 0.6 or 0
            led.BackgroundTransparency = math.clamp(alpha + blink, 0, 1)
            led:FindFirstChildOfClass("UIStroke").Transparency = math.clamp(alpha + 0.2, 0, 1)
        end
    end
end
-- ===== UI THEME v4 (SKIN UI THEMES, roll-out 2026-10-29): the clean language in this colourway's colours (UITheme Clean)
-- + two touches of a spacecraft. Hooks read only the palette they get (a colourway copy shares these functions):
--   TAB MARK  a strip of crinkled FOIL (a crinkle of light and shade along it) with a STATUS LIGHT at its end; on the top bar
--             the light blinks slowly and steadily, like the gun's
--   FIELD     a PLANET LIMB rising out of the bottom edge of the screen -- the night side, its atmosphere a thin glowing line
--             in the status-light colour -- and a small satellite crossing slowly along its orbit arc above it
local function ObV(c) local _, _, v = c:ToHSV() return v end
local OB_MARK = (ObV(P.Foil) > 0.35) and P.Foil or P.Tile
local OB_CLEAN = {
    Field = P.Thermal:Lerp(P.Ink, 0.4), Surface = P.Thermal:Lerp(P.Plate, 0.25), Raised = P.Thermal:Lerp(P.Plate, 0.5),
    Hover = P.Plate:Lerp(P.Tile, 0.14), Well = P.Ink, Line = P.Ti:Lerp(P.Thermal, 0.62), Tip = P.Thermal:Lerp(P.Ink, 0.2),
    Accent = P.Lume, Mark = OB_MARK, Hair = P.Ti,
    Text = P.Text, Sub = P.Text:Lerp(P.Ti, 0.5), Muted = P.Ti:Lerp(P.Thermal, 0.12), Ink = P.Ink,
    Status = P.Lume, Band = P.Tile, Wing = OB_WING, Planet = P.Thermal:Lerp(P.Plate, 0.35), Air = P.Lume:Lerp(P.Hot, 0.3),
}
-- (HudThemes.Variant keeps a colourway copy's Clean colour only where it DIFFERS from colourway 1's -- an equal one goes through
-- the hue map and can come out wrong: nudge every copy colour a hair so this palette wins)
if VAR ~= 1 then for k, v in pairs(OB_CLEAN) do if typeof(v) == "Color3" then OB_CLEAN[k] = v:Lerp(Color3.new(0, 0, 0), 0.003) end end end
OB_CLEAN.TabMark = function(mark, Q)
    -- (the crinkle is a gradient over the mark's own colour; the light is a small offset frame inside the mark's right end --
    -- tab buttons size themselves to their children, so it never reaches past the mark)
    local g = Instance.new("UIGradient")
    local W, D = Color3.new(1, 1, 1), Color3.new(0.62, 0.62, 0.62)
    g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, D), ColorSequenceKeypoint.new(0.11, W), ColorSequenceKeypoint.new(0.19, D),
        ColorSequenceKeypoint.new(0.34, W), ColorSequenceKeypoint.new(0.41, Color3.new(0.78, 0.78, 0.78)), ColorSequenceKeypoint.new(0.55, W),
        ColorSequenceKeypoint.new(0.66, D), ColorSequenceKeypoint.new(0.8, W), ColorSequenceKeypoint.new(0.9, Color3.new(0.74, 0.74, 0.74)),
        ColorSequenceKeypoint.new(1, W) })
    g.Parent = mark
    local led = Instance.new("Frame")
    led.Name = "ObLed"; led.BorderSizePixel = 0; led.BackgroundColor3 = Q.Status; led.AnchorPoint = Vector2.new(0, 0)
    led.Position = UDim2.new(1, -5, 0, -2); led.Size = UDim2.fromOffset(5, 5); led.ZIndex = mark.ZIndex + 1; led.Parent = mark
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = led
    local st = Instance.new("UIStroke"); st.Color = Q.Ink; st.Thickness = 1; st.Parent = led
    return { g, led }
end
OB_CLEAN.Sig = function(ctx)
    local Q, f = ctx.P, ctx.Frame
    local cam = workspace.CurrentCamera
    local vh = (cam and cam.ViewportSize.Y or 800)
    local limbH = ctx.Phone and 18 or math.clamp(math.floor(vh * 0.075), 34, 72) -- (phones: a thin sliver, the cards reach the bottom)
    local D = 2.6 -- (the planet's diameter, x the field's width)
    -- the planet: a huge disc whose top peeks out of the bottom edge, night side fading into the field, its rim of air lit
    local planet = Instance.new("Frame")
    planet.Name = "ObPlanet"; planet.BorderSizePixel = 0; planet.BackgroundColor3 = Q.Planet; planet.BackgroundTransparency = 0.15
    planet.AnchorPoint = Vector2.new(0.5, 0); planet.Position = UDim2.new(0.5, 0, 1, -limbH); planet.Size = UDim2.fromScale(D, D)
    planet.SizeConstraint = Enum.SizeConstraint.RelativeXX; planet.ZIndex = 0; planet.Parent = f
    local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0.5, 0); pc.Parent = planet
    local pg = Instance.new("UIGradient"); pg.Rotation = 90
    pg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.03, 0.55), NumberSequenceKeypoint.new(1, 1) })
    pg.Parent = planet
    local air = Instance.new("UIStroke"); air.Name = "Air"; air.Color = Q.Air; air.Thickness = 1.5; air.Transparency = 0.35; air.Parent = planet
    local haze = Instance.new("Frame")
    haze.Name = "ObHaze"; haze.BackgroundTransparency = 1; haze.AnchorPoint = Vector2.new(0.5, 0.5); haze.Position = UDim2.fromScale(0.5, 0.5)
    haze.Size = UDim2.new(1, 10, 1, 10); haze.ZIndex = 0; haze.Parent = planet
    local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(0.5, 0); hc.Parent = haze
    local hs = Instance.new("UIStroke"); hs.Color = Q.Air; hs.Thickness = 7; hs.Transparency = 0.86; hs.Parent = haze
    -- the orbit: a hairline ring round the same centre, a little higher
    local gap = math.floor(limbH * (ctx.Phone and 1.1 or 1.25))
    local orbit = Instance.new("Frame")
    orbit.Name = "ObOrbit"; orbit.BackgroundTransparency = 1; orbit.AnchorPoint = Vector2.new(0.5, 0)
    orbit.Position = UDim2.new(0.5, 0, 1, -limbH - gap); orbit.Size = UDim2.new(D, gap * 2, D, gap * 2)
    orbit.SizeConstraint = Enum.SizeConstraint.RelativeXX; orbit.ZIndex = 0; orbit.Parent = f
    local oc = Instance.new("UICorner"); oc.CornerRadius = UDim.new(0.5, 0); oc.Parent = orbit
    local os_ = Instance.new("UIStroke"); os_.Color = Q.Hair; os_.Thickness = 1; os_.Transparency = 0.72; os_.Parent = orbit
    -- the satellite: a body in the band colour, two solar wings, a blinking status light
    local sat = Instance.new("Frame")
    sat.Name = "ObSat"; sat.BackgroundTransparency = 1; sat.AnchorPoint = Vector2.new(0.5, 0.5); sat.Size = UDim2.fromOffset(30, 10); sat.ZIndex = 1
    sat.Parent = f
    local body = Instance.new("Frame")
    body.BorderSizePixel = 0; body.BackgroundColor3 = Q.Band; body.AnchorPoint = Vector2.new(0.5, 0.5); body.Position = UDim2.fromScale(0.5, 0.5)
    body.Size = UDim2.fromOffset(9, 9); body.ZIndex = 2; body.Parent = sat
    local bst = Instance.new("UIStroke"); bst.Color = Q.Ink; bst.Thickness = 1; bst.Parent = body
    for i = -1, 1, 2 do
        local w = Instance.new("Frame")
        w.BorderSizePixel = 0; w.BackgroundColor3 = Q.Wing; w.AnchorPoint = Vector2.new(0.5, 0.5); w.Position = UDim2.new(0.5, i * 10, 0.5, 0)
        w.Size = UDim2.fromOffset(9, 6); w.ZIndex = 1; w.Parent = sat
        local wst = Instance.new("UIStroke"); wst.Color = Q.Ink; wst.Thickness = 1; wst.Parent = w
    end
    local led = Instance.new("Frame")
    led.BorderSizePixel = 0; led.BackgroundColor3 = Q.Status; led.AnchorPoint = Vector2.new(0.5, 0.5); led.Position = UDim2.fromScale(0.5, 0.5)
    led.Size = UDim2.fromOffset(3, 3); led.ZIndex = 3; led.Parent = sat
    local t0 = math.random() * 60
    local function UScale() -- (field pixels -> this layer's own units: the menu gui may carry a UIScale)
        local s, o = 1, f
        while o and not o:IsA("BasePlayerGui") do -- (the ScreenGui's own UIScale counts too)
            local u = o:FindFirstChildOfClass("UIScale"); if u then s *= u.Scale end
            o = o.Parent
        end
        return s
    end
    local us, usAt = 1, -99
    return function(now, _dt)
        -- the satellite crosses along the orbit arc (one pass a minute, left to right), banking with the arc
        if now - usAt > 2 then usAt = now; us = UScale() end
        local W, H = f.AbsoluteSize.X / us, f.AbsoluteSize.Y / us
        if W > 0 then
            local r = W * D / 2 + gap
            local cy = H - limbH - gap + r
            local maxA = math.asin(math.clamp((W / 2 + 30) / r, 0, 1))
            local a = -maxA + ((now + t0) % 60) / 60 * 2 * maxA
            sat.Position = UDim2.fromOffset(W / 2 + math.sin(a) * r, cy - math.cos(a) * r)
            sat.Rotation = math.deg(a)
        end
        led.BackgroundTransparency = ((now % 2.4) < 0.25) and 0 or 0.7
        -- the status light on the selected tab's foil blinks slowly and steadily
        local k = 0.5 + 0.5 * math.sin(now * 2.2)
        for _, m in ipairs(ctx.Marks()) do
            local l = m.Visible and m:FindFirstChild("ObLed")
            if l then l.BackgroundTransparency = 0.7 * k end
        end
    end, nil
end
local function PG(top, bottom) return { Top = top, Bottom = bottom } end
Set.Theme = { Name = "Orbiter", Desc = "Mission control in every window: graphite glass with safety-orange titles, strips of gold foil tape stuck across the corners with titanium rivets, a small satellite making a slow lap of the window's edge, and a status row with a blinking green light under every title.",
    Panel = PG(C(34, 34, 36), C(10, 10, 11)), Card = PG(C(44, 44, 46), C(14, 14, 15)), Title = PG(C(150, 62, 16), C(56, 22, 6)),
    Accent = P1.Lume, Accent2 = C(214, 84, 18), HpFill = P1.Lume, HpBg = C(20, 10, 4), XpFill = C(214, 84, 18), Text = P1.Text,
    FoilLit = C(232, 190, 92), FoilShade = C(130, 90, 30), Ti = C(150, 154, 162), Cell = C(24, 28, 52), Status = C(90, 230, 120),
    Emblem = "EmblemOrbiter", BorderThick = 2,
    Deco = ObDeco, OpenFn = ObOpen, TitleDeco = ObTitle,
    Clean = OB_CLEAN, -- (SKIN UI THEMES roll-out: the clean palette + foil tab marks with a status light + the planet limb and its satellite; the old art is not drawn)
    -- (SKIN UI 2026-10-29: ZERO-G -- weightless stencil digits, an orbiting satellite, a docking ring on crits, the ring opens on a kill; this colourway's P)
    Numbers = { Font = "Oswald", Glyph = "", Motion = ObMotion, Accent = ObAccent, AccentStep = ObAccentStep,
        Normal = P.Text, Crit = P.Lume, Weak = P.Lume:Lerp(P.Hot, 0.55), Stroke = P.Ink, Size = 1.05 } }

-- ===== kill effect / bundle / store hero =====
Set.KillEffect = { Id = "ZeroG", Name = "Zero-G", Image = ART.ob_emblem,
    How = "Own any Orbiter skin (or the Orbiter bundle)",
    Desc = "Zero-G: gravity switches off -- with a pop the enemy breaks into blocks that drift apart, slowly tumbling, never falling, gold foil flecks floating among them, while an orange orbit ring opens round them and a satellite runs once round it. With the Mission Patch kill banner." }
Set.Bundle = { Id = "OrbiterBundle", Name = "Orbiter Bundle", Price = 2199, BP = 799, ProductId = 0,
    Desc = "The whole Orbiter set: the Orbiter P90, FAMAS and Quadbeam, the Antenna Glaive, EVA Gloves + Flight Jacket Sleeves, the Orbiter health bar, the Orbiter UI theme and the Zero-G kill effect.",
    Contents = { "WeaponSkin:OrbiterP90", "WeaponSkin:OrbiterF2000", "WeaponSkin:OrbiterQuadBeam", "MeleeSkin:Orbiter", "Glove:EVAGloves",
        "Sleeve:FlightJacketSleeves", "HealthBar:Orbiter", "KillEffect:ZeroG" } }
Set.Hero = { Grad = { C(70, 70, 74), C(14, 14, 16) }, Stroke = C(214, 84, 18), Emblem = ART.ob_emblem, Name = C(246, 242, 236), Chip = C(150, 60, 14) }

return Set
