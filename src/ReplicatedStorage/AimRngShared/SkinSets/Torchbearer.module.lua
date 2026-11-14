--!nocheck
-- ===================================================================================================================
-- TORCHBEARER (skinsB, 2026-10-13): the SEASON 1 "OPEN FIRE" champion reward -- premium tier 50 of the season pass, never
-- sold in the store (Unlock = "Season"). The player who carried the season's flame to the end: matte IVORY enamel armour
-- edged in polished GOLD and banded in SCARLET enamel over black leather and a charcoal technical weave. Pieces:
--   TORCHBEARER GAUNTLETS  black leather gloves; three stepped ivory knuckle lames with gold edges; on the back of the hand
--                          a gold laurel wreath round a gold TORCH CUP holding a LIVING FLAME (two Neon layers: it flickers,
--                          leans taller with sustained fire and flares on a kill / inspect); a flared ivory gauntlet cuff
--                          with a scarlet band between gold rims
--   TORCHBEARER SLEEVES    charcoal technical weave under an ivory enamel vambrace (a scarlet stripe down the top, gold
--                          piping on both edges) carrying a long gold LAUREL SPRIG; a gold rank band with three scarlet
--                          chevrons toward the wrist; an ivory cuff rimmed in gold; a glint runs along the gold now and then
--   TORCHBEARER BLADE      (melee, Knife class) a gold torch-cup dagger (flame-wing quillons, scarlet ring, ivory band, an
--                          ivory grip with black leather wraps, a gold pommel) whose BLADE IS FIRE: no blade geometry, dense
--                          flipbook flames (rendered in Blender, tools/skins_v3/torchbearer_fire_render.py) flying from the
--                          cup's mouth along six narrowing spawn volumes to a long thin point, each drawn facing the camera and
--                          turned along the blade's direction on screen (so the fire stays on the blade through a twirl);
--                          an additive glow layer + an alpha colour layer (it reads on bright snow too), a faint white-hot
--                          heart, embers, a smoke wisp, one small heat light. The draw lights the cup's coals and the fire
--                          climbs up the blade; cuts stream a fire trail, a heavy / kills make it flare, and the inspect is a
--                          CHAMPION'S SALUTE where it roars to full height before the twirl throws sparks.
--   COLOURWAYS             Champion (ivory / scarlet / gold, a classic orange flame), Bluefire (black / sapphire / gold, a
--                          BLUE flame from grey copies of the flame sheets), Inferno (scarlet / ivory / bronze, a deep red
--                          flame); the arms' crest flame always matches the blade.
-- Built with tools/skins_v3/torchbearer_build.py (arms) + torchbearer_knife3.py (the flame blade) (art/weapons/SkinsV3_Torchbearer.blend), painted by tools/skin_v3_paint.py
-- with tools/skins_v3/torchbearer.json; models MeleeModels.Torchbearer + ArmsModels.Torchbearer. Original design: a torch +
-- laurel champion motif in our own ivory / scarlet / gold, no emblem / mascot / name from any other game.
-- ===================================================================================================================
local Set = { Kind = "Torchbearer" }

local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local PALETTES = {
    { Name = "Champion", Ivory = C(202, 188, 162), Scarlet = C(164, 26, 32), Leather = C(30, 26, 28), Weave = C(40, 39, 46), Gold = C(212, 162, 62),
      Flame = C(255, 150, 40), Core = C(255, 236, 190), Ember = C(255, 110, 30),
      FRim = C(255, 196, 80), FOuter = C(226, 62, 22), FBody = C(255, 138, 32), FCore = C(255, 238, 196), FInk = C(46, 10, 8), FCoals = C(255, 120, 30) },
    -- BLUEFIRE (was Obsidian's amber flame, too close to Champion): black enamel, sapphire bands, gold, a BLUE flame (the
    -- fire uses grey copies of the flame sheets, tinted: cyan-white core -> blue -> deep indigo edges)
    { Name = "Bluefire", Ivory = C(44, 42, 48), Scarlet = C(38, 86, 180), Leather = C(18, 16, 18), Weave = C(30, 29, 34), Gold = C(220, 172, 72),
      Flame = C(70, 140, 255), Core = C(215, 242, 255), Ember = C(110, 190, 255), Grey = true,
      FRim = C(150, 215, 255), FOuter = C(40, 50, 170), FBody = C(70, 140, 255), FCore = C(225, 248, 255), FInk = C(8, 10, 30), FCoals = C(90, 170, 255) },
    { Name = "Inferno", Ivory = C(146, 26, 26), Scarlet = C(214, 204, 182), Leather = C(26, 20, 20), Weave = C(44, 26, 26), Gold = C(196, 126, 62),
      Flame = C(240, 70, 30), Core = C(255, 180, 120), Ember = C(255, 90, 40),
      FRim = C(255, 120, 60), FOuter = C(170, 16, 20), FBody = C(240, 60, 30), FCore = C(255, 210, 160), FInk = C(30, 4, 4), FCoals = C(255, 80, 40) },
}
local P = PALETTES[VAR] or PALETTES[1]
local FLAME, CORE, EMBER, GOLD = P.Flame, P.Core, P.Ember, P.Gold
Set.Palettes = PALETTES
Set.Colors = { Glow = FLAME, Hot = CORE, Spark = EMBER }

local A = "rbxassetid://"
Set.Art = {}

-- sounds (tools/skins_v3/torchbearer_sfx.py, CC0 recordings): an ignition whoosh on the draw, a fire-whipped swing, a
-- stab with a crackle on the hit, a soft fire swell on the inspect's salute (all PASS tools/audio_screen.py)
Set.Sounds = {
    Equip = { Id = 80107433605500, Volume = 0.45 }, Swing = { Id = 92392426975427, Volume = 0.42 }, MeleeHit = { Id = 110161498913083, Volume = 0.42 },
    Salute = { Id = 81822556681231, Volume = 0.35 },
}

local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

-- ===== the FLAME BLADE (v3; owner: "the blade should be an actual flame knife") =====
-- The blade IS fire (MeleeModels.Torchbearer, tools/skins_v3/torchbearer_knife3.py): nested Neon layers that each move on
-- their own -- FireO scales the silhouette (ink outline + bright rim + dark red-orange outer fire, one drive so the rim stays a
-- clean line), FireB the bright orange body, FireC the white-hot core (all grow from the torch cup); Lick1..6 the six free
-- tongues (each licks up and dies on its own cycle), Stream bends them back along the blade on a swing; Twist / TwistGlow the
-- white spiral that winds up the blade in the salute; Coals the embers in the cup; *Glow the layers' brightness flicker.
--   draw: the cup's coals catch, then the blade ERUPTS up out of the cup (overshoots, settles)
--   swing: the fire stretches, the tongues stream back, a fire trail     heavy: the whole blade FLARES bigger
--   kill: a quick flare                                                    inspect: the salute ROARS to full height + the spiral
local function FlameKeys(st: any, v: any, now: number, anim: string?, animT: number?)
    local se = st.SinceEquip or 99
    local function nz(a: number, b: number, c: number, ph: number): number
        return 0.5 * math.sin(now * a + ph) + 0.3 * math.sin(now * b + ph * 1.7) + 0.2 * math.sin(now * c + ph * 2.3)
    end
    local n1, n2, n3 = nz(9.3, 15.1, 23.7, 0.4), nz(11.1, 17.3, 27.1, 2.2), nz(13.7, 19.9, 31.3, 4.1)
    local coal = (se < 1) and smooth((se - 0.08) / 0.1) or 1
    local ign = (se < 1) and smooth((se - 0.2) / 0.26) or 1
    local burst = (se < 1) and 0.3 * math.exp(-((se - 0.5) / 0.1) ^ 2) or 0
    local sw = v.SwingT and (os.clock() - v.SwingT) or 99
    local leap = math.exp(-sw / 0.25)
    -- a kill: a quick flare (st.Streak climbs on every kill)
    local stk = st.Streak or 0
    if stk > (v.LastStreak or 0) then v.KillT = now end
    v.LastStreak = stk
    local kf = v.KillT and math.exp(-(now - v.KillT) / 0.35) or 0
    local hv, sal, tw = 0, 0, 0
    if anim and animT then
        if anim:find("Heavy") then hv = smooth(animT / 0.3) * (1 - smooth((animT - 0.5) / 0.3)) end
        if anim == "Inspect" then
            sal = smooth((animT - 0.45) / 0.5) * (1 - smooth((animT - 2.55) / 0.45))
            tw = smooth((animT - 0.5) / 0.8) * (1 - smooth((animT - 2.6) / 0.35))
        end
    end
    local up = 0.1 * leap + 0.28 * hv + 0.2 * kf + 0.16 * sal + burst
    st.FireO = ign * (0.985 + 0.02 * n1) + up
    st.FireB = ign * (0.95 + 0.05 * n2) + up * 1.15
    st.FireC = ign * (0.92 + 0.07 * n3) + up * 1.35
    st.RimGlow = math.clamp(0.82 + 0.18 * n2 + leap + kf + sal, 0, 1)
    st.OuterGlow = math.clamp(0.7 + 0.25 * n1 + 0.5 * leap + kf + sal, 0, 1)
    st.BodyGlow = math.clamp(0.75 + 0.25 * n3 + 0.5 * leap + kf + sal, 0, 1)
    st.CoreGlow = math.clamp(0.85 + 0.15 * n1 + leap + kf + sal, 0, 1)
    st.TongueGlow = math.clamp(0.6 + 0.3 * n2 + 0.5 * leap + kf + sal, 0, 1)
    for i = 1, 6 do
        local ph = (now * (1.5 + 0.19 * i) + i * 0.37) % 1
        local cyc = math.sin(math.pi * ph) ^ 0.7
        st["Lick" .. i] = ign * math.clamp(0.25 + 0.85 * cyc + 0.6 * leap + 0.45 * hv + 0.4 * sal + 0.4 * kf, 0.02, 1.6)
    end
    st.Stream = math.clamp(leap + 0.5 * hv, 0, 1)
    st.Twist, st.TwistGlow = math.max(0.02, tw), tw
    -- the REAL fire (flipbook particles): how much fire (rate multiplier) and whether the licks are big (draw / swing /
    -- heavy / salute / kill)
    st.FireRate = ign * (1 + 1.2 * leap + 1.5 * hv + 1.0 * sal + 1.5 * kf) + 4 * burst
    st.FireBig = math.clamp(0.5 * leap + hv + 0.7 * sal + kf + 2 * burst, 0, 1)
    st.Coals = coal * math.clamp(0.55 + 0.2 * n1 + 0.5 * leap + 0.5 * sal + 0.5 * kf + 0.4 * (1 - ign), 0, 1)
end
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    FlameKeys(st, rig.SkinVars, now, rig.AnimName, rig.AnimTime)
    -- (one small light rides the blade: brighter with the fire)
    local vars = rig.SkinVars
    local L = vars.TBLight
    if not (L and L.Parent) and rig.Gun and (vars.TBLookT or 0) < now - 1 then
        vars.TBLookT = now
        L = rig.Gun:FindFirstChild("TBHeat", true)
        vars.TBLight = L
    end
    if L and L.Parent then L.Brightness = 0.55 + 0.35 * (st.OuterGlow or 0) + 0.6 * (st.Stream or 0) end
    -- the real fire: each flame emitter's rate follows the fire (Low graphics thins it), its licks grow on a flare
    local fl = vars.TBFire
    if not fl or not (fl[1] and fl[1].Parent) then
        fl = nil
        if rig.Gun and (vars.TBFireLookT or 0) < now - 1 then
            vars.TBFireLookT = now
            fl = {}
            for _, d in ipairs(rig.Gun:GetDescendants()) do
                if d:IsA("ParticleEmitter") and d:GetAttribute("TBBase") then table.insert(fl, d) end
            end
            vars.TBFire = fl
        end
    end
    if fl then
        if vars.TBQM == nil then
            local ok, qm = pcall(function() return require(game:GetService("ReplicatedStorage").AimRngShared.QualityMode) end)
            vars.TBQM = ok and qm or false
        end
        local q = (vars.TBQM and vars.TBQM.IsLow()) and 0.35 or 1
        -- the flare grows the licks SMOOTHLY (a one-step Size swap resized every live flame at once: a pop at the salute's
        -- start + end); quantised to 4% steps so the sequence isn't rebuilt every frame
        local grow = math.floor((1 + 0.45 * math.clamp(st.FireBig or 0, 0, 1)) * 25 + 0.5) / 25
        -- the flames are drawn FACING THE CAMERA, each new one turned to the blade's direction ON SCREEN (owner: the fire
        -- "bugs out" in the inspect -- VelocityParallel streaks of flames locked to a blade twirling at ~1200 deg/s took the
        -- blade's motion as their direction and swung sideways); computed once a frame from the blade's ends
        local ang = vars.TBAng or 0
        local bl = fl[1] and fl[1].Parent and fl[1].Parent.Parent and fl[1].Parent.Parent:FindFirstChild("Blade")
        local cam = workspace.CurrentCamera
        if bl and cam then
            local a0 = cam:WorldToViewportPoint(bl.Position - bl.CFrame.UpVector * bl.Size.Y * 0.5)
            local a1 = cam:WorldToViewportPoint(bl.Position + bl.CFrame.UpVector * bl.Size.Y * 0.5)
            local dx, dy = a1.X - a0.X, a1.Y - a0.Y
            if dx * dx + dy * dy > 4 then ang = -math.deg(math.atan2(dx, -dy)) end -- (particle Rotation turns counter-clockwise)
            vars.TBAng = ang
        end
        -- INSPECT: the salute + twirl show the cup from the side / below, where the base flames' camera-facing quads reached
        -- past the rim (owner: "ever so slightly clips through the bottom on inspect") -> while inspecting, the lowest
        -- segment's flames shrink to 55% and thin out (eased in / out, quantised to 0.1 steps)
        local insT = (rig.AnimName == "Inspect") and 1 or 0
        vars.TBIns = (vars.TBIns or 0) + (insT - (vars.TBIns or 0)) * math.min(1, dt * 8)
        local ins = math.floor(vars.TBIns * 10 + 0.5) / 10
        local kk = math.clamp(st.FireO or 1, 0, 1.4)
        for _, pe in ipairs(fl) do
            local low = (pe:GetAttribute("TBT") or 1) < 0.1
            local on = ((pe:GetAttribute("TBT") or 0) <= kk) and 1 or 0
            pe.Rate = pe:GetAttribute("TBBase") * (st.FireRate or 1) * q * on * (low and (1 - 0.6 * ins) or 1)
            if pe:GetAttribute("TBT") then pe.Rotation = NumberRange.new(ang - 6, ang + 6) end
            local g2 = low and grow * (1 - 0.55 * ins) or grow
            if pe:GetAttribute("TBSize") and pe:GetAttribute("TBGrow") ~= g2 then
                pe:SetAttribute("TBGrow", g2)
                local sz = pe:GetAttribute("TBSize") * g2
                pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, sz * (pe:GetAttribute("TBBirth") or 0.4)), NumberSequenceKeypoint.new(0.35, sz),
                    NumberSequenceKeypoint.new(1, sz * 0.35) })
            end
        end
    end
    -- the fire BEAMS: the blade grows out of the cup (its attachments slide from the cup's mouth to their full spots), a
    -- flare widens it, the wisps' widths flicker on their own noise
    local fb = vars.TBBeam
    if not fb or not (fb.Atts[1] and fb.Atts[1].Parent) then
        fb = nil
        if rig.Gun and (vars.TBBeamLookT or 0) < now - 1 then
            vars.TBBeamLookT = now
            fb = { Atts = {}, Beams = {} }
            for _, d in ipairs(rig.Gun:GetDescendants()) do
                if d:IsA("Attachment") and d:GetAttribute("TBFull") then table.insert(fb.Atts, d)
                elseif d:IsA("Beam") and d:GetAttribute("TBW0") then table.insert(fb.Beams, d) end
            end
            vars.TBBeam = fb
        end
    end
    if fb then
        local k = math.clamp(st.FireO or 1, 0.02, 1.4)
        for _, at in ipairs(fb.Atts) do
            local full, root = at:GetAttribute("TBFull"), at:GetAttribute("TBRoot")
            at.Position = root + (full - root) * k
        end
        local wk = (1 + 0.35 * (st.FireBig or 0)) * math.min(1, k * 1.6)
        for i, bm in ipairs(fb.Beams) do
            local f = wk
            if bm:GetAttribute("TBWisp") then
                f *= 0.6 + 0.25 * (math.sin(now * (6.1 + i)) + 1) + 0.15 * math.sin(now * (13.7 + 2 * i) + i)
            else
                f *= 1 + 0.06 * math.sin(now * (9 + i) + i * 1.3)
            end
            -- (the white-hot heart's base narrows during the inspect too: seen from below it glowed over the cup's mouth)
            bm.Width0 = bm:GetAttribute("TBW0") * f * (1 - 0.75 * (vars.TBIns or 0))
            bm.Width1 = bm:GetAttribute("TBW1") * f
        end
    end
end
Set.OnAnim = function(rig: any, name: string)
    if name:find("Light") or name:find("Heavy") or name:find("Quick") then rig.SkinVars.SwingT = os.clock() end
end
Set.World = function(rec: any, now: number, st: any)
    st.SinceEquip = 99
    FlameKeys(st, rec.Vars, now, nil, nil)
end
Set.OnEvent = function(rig: any, name: string, H: any, data: any)
    local function Emit(nm: string, n: number)
        local gun = rig.Gun
        for _, d in ipairs(gun and gun:GetDescendants() or {}) do
            if d:IsA("ParticleEmitter") and d.Name == nm then d:Emit(n) end
        end
    end
    if name == "Swing" then Emit("TBEmbers", 8)
    elseif name == "Ignite" then Emit("TBErupt", 14)
    elseif name == "Erupt" then Emit("TBTipSparks", 10); Emit("TBEmbers", 10); Emit("TBFire1", 8); Emit("TBFire2", 6); Emit("TBFire3", 5)
    elseif name == "Flip" then Emit("TBTipSparks", 16); Emit("TBEmbers", 12) end
end

-- ===== the TORCHBEARER BLADE (melee, Knife class) =====
local Inspects = require(game:GetService("ReplicatedStorage"):WaitForChild("AimRngShared"):WaitForChild("Inspects")) -- (a leaf module)
local MK, MN = Inspects.K, Inspects.N
Set.Melee = {
    Skin = { Name = "Torchbearer Blade", ProductId = 0, Source = "Season", Rarity = "Mythic",
        How = "Season 1: Open Fire premium pass, tier 50",
        Desc = "The Season 1 champion's blade is a dagger made of living fire: licking tongues of flame around a white-hot core and a bright edge that tapers to a needle point, rising out of a gold torch cup with flame-wing quillons on an ivory grip with black leather wraps and a gold pommel. The draw lights the cup and the blade erupts out of it; every cut streams fire, a heavy strike flares it, kills make it flare, and the inspect is a champion's salute where the flame roars to full height with a spiral of white fire winding up the blade. Earned at tier 50 of the Season 1 premium pass." },
    Rig = { Class = "Knife", BladeLen = 0.8, FlatBlade = true },
    -- the DRAW: up from the hip with the blade still unlit, held up in view: the cup's coals catch (Ignite), then the fire blade
    -- ERUPTS up out of the cup (Erupt: a kick as it bursts, tip sparks) and settles to rest
    EquipAnim = { Length = 0.85, Tracks = {
        Gun = { MK(0, 0.1, -0.55, 0.15, -45, -8, -18), MK(0.18, 0.02, -0.1, 0.04, -4, -4, -4, "Out"), MK(0.3, 0, -0.02, 0, 4, -2, 0),
            MK(0.46, 0, 0.025, -0.012, 7, 0, 2, "Out"), MK(0.64, 0, -0.006, 0, -2, 0, 0), MK(0.85) },
        BladeRoll = { MN(0, 90), MN(0.2, 0), MN(0.85, 0) },
    }, Events = { { 0.04, "Equip" }, { 0.2, "Ignite" }, { 0.42, "Erupt" } } },
    -- LIGHT 1: a forehand cut from the upper right down across to the lower left
    Light1Anim = { Length = 0.42, Tracks = { Gun = {
        MK(0), MK(0.06, 0.12, 0.12, 0.04, 14, -14, -14), MK(0.14, -0.36, -0.08, -0.18, -16, 30, 16, "Out"), MK(0.22, -0.42, -0.1, -0.15, -18, 34, 18), MK(0.42),
    } }, Events = { { 0.09, "Swing" } } },
    -- LIGHT 2: a rising backhand cut from the lower left up to the right
    Light2Anim = { Length = 0.44, Tracks = { Gun = {
        MK(0), MK(0.07, -0.3, -0.06, 0.02, -8, 28, 16), MK(0.15, 0.1, 0.12, -0.18, 16, -24, -14, "Out"), MK(0.23, 0.13, 0.13, -0.15, 18, -26, -14), MK(0.44),
    } }, Events = { { 0.1, "Swing" } } },
    -- HEAVY: drawn back low, then a driving upward thrust
    HeavyAnim = { Length = 0.8, Tracks = { Gun = {
        MK(0), MK(0.24, 0.08, -0.14, 0.24, -16, -8, -6), MK(0.37, -0.12, 0.12, -0.56, 20, 16, 4, "Out"), MK(0.52, -0.11, 0.11, -0.5, 18, 15, 4), MK(0.8),
    } }, Events = { { 0.31, "Swing" } } },
    -- INSPECT: the CHAMPION'S SALUTE -- raised upright in front, the flame runs to the tip, a twirl on the fingers (Flip),
    -- shown on its other face, a downward flourish back to rest
    InspectAnim = { Length = 3.3, Beats = { Raise = 0.5, Flip = 1.8, Settle = 3.0 }, Tracks = {
        Gun = { MK(0), MK(0.5, -0.24, 0.2, 0.04, 40, -8, -10), MK(1.3, -0.25, 0.22, 0.04, 42, -10, -8), MK(1.55, -0.22, 0.2, 0.02, 34, -6, -4),
            MK(1.8, -0.18, 0.15, 0, 16, 8, 26), MK(2.45, -0.17, 0.15, 0, 14, 10, 30), MK(2.75, -0.05, -0.06, 0, -16, 4, 10),
            MK(3.0, 0, -0.01, 0, -2, 0, 2), MK(3.3) },
        BladeRoll = { MN(0, 0), MN(0.5, 8), MN(1.4, 12), MN(1.5, 12), MN(1.8, 372), MN(2.45, 376), MN(2.9, 360), MN(3.3, 360) },
    }, Events = { { 0.5, "Raise" }, { 0.6, "Sound", { Id = Set.Sounds.Salute.Id, Volume = Set.Sounds.Salute.Volume } }, { 1.8, "Flip" }, { 3.0, "Settle" } } },
    InspectEvents = { { "Flip", "Emit", { Name = "TBEmbers", Count = 10 } } },
    Build = function(m: Model, o: any, H: any, Part: any)
        local parts = H.CloneModel(m, "MeleeModels", "Torchbearer", VAR, { [1] = P.FOuter, [2] = P.FCore, [3] = P.FRim, [4] = P.FBody, [5] = P.FCoals })
        local blade = parts.Blade -- (the invisible proxy: the trail + emitter anchor, never scaled)
        if not blade then return end
        blade.Transparency = 1
        -- THE BLADE IS FIRE (owner: "the blade itself should be made from fire", the hilt stays metal): no modelled blade at
        -- all -- every Fire_ layer of the model goes; the blade is layered flame BEAMS (below) + a few licks + embers
        for _, nm in ipairs({ "Fire_Ink", "Fire_Rim", "Fire_Outer", "Fire_Body", "Fire_Core", "Fire_Spiral", "Fire_T1", "Fire_T2", "Fire_T3",
            "Fire_T4", "Fire_T5", "Fire_T6" }) do
            if parts[nm] then parts[nm]:Destroy(); parts[nm] = nil end
        end
        -- the COAL BED in the cup's mouth (below the rim): deep glowing embers the flames rise out of
        if parts.Fire_Coals then parts.Fire_Coals.Color = P.FCoals:Lerp(C(0, 0, 0), 0.4) end
        local cf = blade.CFrame
        local function At(fr: number): Vector3
            return cf:PointToObjectSpace(cf.Position + cf.UpVector * blade.Size.Y * fr)
        end
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Name, a1.Name = "TrailBase", "TrailTip"
        a0.Position, a1.Position = At(-0.25), At(0.5)
        a0.Parent, a1.Parent = blade, blade
        -- the swing trail: the fire streams off the blade (white-hot at the edge, the outer fire, gone to smoke-dark red)
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, P.FOuter), ColorSequenceKeypoint.new(0.55, P.FBody), ColorSequenceKeypoint.new(1, P.FCore) })
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) })
        tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1) })
        tr.LightEmission = 1; tr.LightInfluence = 0
        tr.Lifetime = 0.22; tr.MinLength = 0.02; tr.FaceCamera = true
        tr.Enabled = false
        tr:SetAttribute("SwingTrail", true)
        tr.Parent = blade
        -- embers rising off the fire (a few always: it's alive)
        local sa = Instance.new("Attachment")
        sa.Name = "TBEmberAt"
        sa.Position = At(-0.05)
        sa.Parent = blade
        H.Emitter(sa, { Name = "TBEmbers", Color = { P.FCore, P.FOuter }, Size = { 0.035, 0 }, Life = { 0.35, 0.7 }, Speed = { 0.4, 1.2 },
            Accel = Vector3.new(0, 2.2, 0), Rate = 3, SkinFx = true })
        -- THE FIRE BLADE (owner: the blade itself is FIRE, real-looking, like a reference photo of a flame dagger): no blade
        -- geometry -- dense flame PARTICLES (a Blender-rendered flipbook, tools/skins_v3/torchbearer_fire_render.py: fine
        -- strands, dark gaps, blackbody colours, premultiplied) spawning inside six invisible box segments down the blade that
        -- narrow to the point, so the flames themselves draw the dagger; locked to the blade so the shape holds; short lives,
        -- soft fade in / out, white-yellow -> orange -> deep red, a slight drift toward the tip. One faint white-hot beam runs up
        -- the middle near the base for the hot heart. Set.Drive scales the rates (the draw lights the segments one by one up
        -- from the cup; swings / heavy / salute / kills burn harder) and the lick size.
        local LICK, LICK_S = "rbxassetid://108068959738530", "rbxassetid://101383798706580"
        local HEART = "rbxassetid://96943283597184"
        if P.Grey then -- (a non-orange fire: the grey sheets take the palette's colour)
            LICK, LICK_S, HEART = "rbxassetid://139736976278353", "rbxassetid://87687912037683", "rbxassetid://96348975197742"
        end
        local up = cf.UpVector
        local function FireCF(t: number): CFrame
            local fr = (0.205 + 0.79 * t - 0.63) / 0.73
            return cf.Rotation + (cf.Position + up * blade.Size.Y * fr)
        end
        local function prof(t: number): number
            if t < 0.2 then return 0.6 + 0.4 * smooth(t / 0.2) end
            return math.max(0, 1 - (t - 0.2) / 0.8) ^ 1.12
        end
        local fcol = ColorSequence.new({ ColorSequenceKeypoint.new(0, P.FCore), ColorSequenceKeypoint.new(0.25, P.FRim),
            ColorSequenceKeypoint.new(0.6, P.FBody), ColorSequenceKeypoint.new(1, P.FOuter) })
        local ftr = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.15), NumberSequenceKeypoint.new(0.6, 0.35),
            NumberSequenceKeypoint.new(1, 1) })
        -- (the lowest segment starts ABOVE the cup's rim at y 0.264 -- a flame sprite reaches ~0.4 of its size behind where it
        -- spawns, so nothing may spawn lower; owner: "fire glitching through the torch at the bottom")
        local SEG = { { 0.085, 0.265, 44 }, { 0.245, 0.38, 45 }, { 0.36, 0.505, 42 }, { 0.485, 0.63, 36 }, { 0.61, 0.755, 30 }, { 0.735, 0.98, 24 } }
        for i, sg in ipairs(SEG) do
            local tm = (sg[1] + sg[2]) / 2
            local hw = 0.08 * prof(tm)
            local seg = Part(m, "TBSeg" .. i, Vector3.new(math.max(0.012, hw * 1.5), 0.79 * (sg[2] - sg[1]), 0.012), FireCF(tm), C(255, 255, 255))
            seg.Transparency = 1
            seg:SetAttribute("SkinDeco", true)
            local pe = Instance.new("ParticleEmitter")
            pe.Name = "TBFire" .. i
            pe.Texture = LICK
            pe.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
            pe.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
            pe.Shape = Enum.ParticleEmitterShape.Box
            pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
            pe.EmissionDirection = Enum.NormalId.Top
            pe.Color = fcol
            pe.Transparency = ftr
            local sz = math.max(0.056, hw * 3.4)
            if i == 1 then sz = math.min(sz, 0.14) end
            local b0 = (i == 1) and 0.15 or 0.45 -- (birth size: the lowest segment's flames are born tiny so none reaches into the cup)
            -- born TINY and grown (a full-size quad born at the rim reached down into the cup by half its size)
            pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, sz * b0), NumberSequenceKeypoint.new(0.35, sz), NumberSequenceKeypoint.new(1, sz * 0.35) })
            pe:SetAttribute("TBBirth", b0)
            pe.ZOffset = 0
            pe.Lifetime = NumberRange.new(0.2, 0.42)
            -- each flame flies ALONG the blade toward the point and is drawn stretched along its flight (the lick's
            -- strands run lengthwise: a continuous streaky blade, not puffs)
            pe.Orientation = Enum.ParticleOrientation.FacingCamera -- (turned to the blade's screen direction in Set.Drive)
            pe.Rotation = NumberRange.new(0, 0)
            pe.Speed = NumberRange.new(0.5, 1.0)
            pe.SpreadAngle = Vector2.new(6, 6) -- (strictly tipward: nothing drifts back toward the grip)
            pe.Acceleration = Vector3.zero
            pe.LightEmission = 1
            pe.LightInfluence = 0
            pe.LockedToPart = true
            pe.Rate = sg[3]
            pe:SetAttribute("TBBase", sg[3])
            pe:SetAttribute("TBSize", sz)
            pe:SetAttribute("TBT", sg[1])
            if i == 1 then
                -- (the lowest segment: slow + visible from birth, so the fire sits right on the cup's mouth with no gap)
                pe.Speed = NumberRange.new(0.15, 0.35)
                pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.12, 0.15),
                    NumberSequenceKeypoint.new(0.6, 0.35), NumberSequenceKeypoint.new(1, 1) })
            end
            pe:SetAttribute("SkinFx", true)
            pe.Parent = seg
            -- its COLOUR BODY: the same flames alpha-blended (a straight-alpha copy of the flipbook), so the fire keeps its
            -- orange over bright snow, where additive light alone vanished
            local bd = pe:Clone()
            bd.Name = "TBBody" .. i
            bd.Texture = LICK_S
            bd.LightEmission = 0.1
            bd.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, P.FRim), ColorSequenceKeypoint.new(0.3, P.FBody),
                ColorSequenceKeypoint.new(0.7, P.FOuter), ColorSequenceKeypoint.new(1, P.FOuter:Lerp(C(0, 0, 0), 0.35)) })
            bd.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, (i == 1) and 0.6 or 1), NumberSequenceKeypoint.new(0.15, 0.35),
                NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(1, 1) })
            bd.Rate = sg[3] * 0.5
            bd:SetAttribute("TBBase", sg[3] * 0.5)
            bd.Parent = seg
        end
        -- the hot heart: one faint white-yellow streak up the middle, gone by halfway (the flames do the rest)
        local function FirePos(t: number): Vector3 return cf:PointToObjectSpace(FireCF(t).Position) end
        local base0 = FirePos(0.085)
        local function Att(name: string, t: number): Attachment
            local at = Instance.new("Attachment")
            at.Name = "TBF_" .. name
            at.Position = FirePos(t)
            at:SetAttribute("TBFull", at.Position)
            at:SetAttribute("TBRoot", base0)
            at.Parent = blade
            return at
        end
        local hb = Instance.new("Beam")
        hb.Attachment0, hb.Attachment1 = Att("B", 0.1), Att("M", 0.6)
        hb.Texture = HEART; hb.TextureMode = Enum.TextureMode.Wrap; hb.TextureLength = 0.3; hb.TextureSpeed = 2.2
        hb.Width0, hb.Width1 = 0.07, 0.01
        hb.Color = ColorSequence.new(C(255, 252, 235), P.FRim)
        hb.Transparency = NumberSequence.new(0.1, 0.8)
        hb.LightEmission = 1; hb.LightInfluence = 0; hb.FaceCamera = true; hb.Segments = 10
        hb:SetAttribute("TBW0", 0.07); hb:SetAttribute("TBW1", 0.01)
        hb.Parent = hb.Attachment0
        -- a faint smoke wisp off the point
        local sm = Instance.new("Attachment")
        sm.Name = "TBSmokeAt"
        sm.Position = At(0.47)
        sm.Parent = blade
        H.Emitter(sm, { Name = "TBSmoke", Texture = "rbxasset://textures/particles/smoke_main.dds", Color = { C(52, 44, 42), C(30, 28, 28) },
            Size = { 0.05, 0.2 }, Trans = { 0.82, 1 }, Life = { 0.6, 1.0 }, Speed = { 0.2, 0.4 }, Spread = 15, Dir = Enum.NormalId.Top,
            Accel = Vector3.new(0, 1.2, 0), Rate = 3, Light = 0, Rot = { 0, 360 }, Spin = { -20, 20 }, SkinFx = true })
        -- the cup: a burst of flame-sparks when the coals catch on the draw
        local ca = Instance.new("Attachment")
        ca.Name = "TBCupAt"
        ca.Position = At(-0.5)
        ca.Parent = blade
        H.Emitter(ca, { Name = "TBErupt", Color = { P.FCore, P.FBody }, Size = { 0.05, 0 }, Life = { 0.15, 0.35 }, Speed = { 1.5, 3.5 },
            Spread = 35, Dir = Enum.NormalId.Top, Accel = Vector3.new(0, 2, 0), SkinFx = true })
        -- the point: a spray of sparks when the blade erupts / the salute peaks
        local ta = Instance.new("Attachment")
        ta.Name = "TBTipAt"
        ta.Position = At(0.48)
        ta.Parent = blade
        H.Emitter(ta, { Name = "TBTipSparks", Color = { P.FCore, P.FRim }, Size = { 0.04, 0 }, Life = { 0.2, 0.45 }, Speed = { 1.2, 3 },
            Accel = Vector3.new(0, 1.5, 0), SkinFx = true })
        -- one small light (the heat on the guard and the hand)
        local L = Instance.new("PointLight")
        L.Name = "TBHeat"
        L.Color = P.FBody
        L.Range = 4.5
        L.Brightness = 0.8
        L.Shadows = false
        L.Parent = sa
    end,
}

-- ===== arms: TORCHBEARER GAUNTLETS + TORCHBEARER SLEEVES (ArmsModels.Torchbearer mesh pieces) =====
local SEASON_HOW = "Season 1: Open Fire premium pass, tier 50"
Set.Glove = function(K: any)
    local V = K.V
    return {
        Id = "TorchbearerGauntlets", Name = "Torchbearer Gauntlets", Unlock = "Season", How = SEASON_HOW, Rarity = "Mythic",
        Desc = "The Season 1 champion's gauntlets: black leather under three stepped ivory knuckle lames edged in gold, a flared ivory cuff banded in scarlet, and on the back of the hand a gold laurel wreath round a torch cup that holds a living flame. It flickers, burns taller while you keep firing and flares on every kill.",
        Base = { Color = P.Leather, Material = K.SMOOTH, Reflectance = 0, Tex = "tex_bs_glove", TexTile = 1.1, TexT = 0, TexColor = P.Leather:Lerp(C(255, 255, 255), 0.06) },
        Parts = {
            { Mesh = "Torchbearer/Knuckle", MeshV = VAR, Size = V(1.0, 0.18, 0.552), Off = V(0, 0.59, -0.236), Seat = true },
            { Mesh = "Torchbearer/Crest", MeshV = VAR, Uniform = true, Size = V(0.657, 0.088, 0.634), Off = V(0, 0.535, 0.18), Seat = true },
            { Mesh = "Torchbearer/Flame", Glow = true, Color = FLAME, Uniform = true, Size = V(0.265, 0.036, 0.464), Off = V(0, 0.575, 0.04), Seat = true,
              Anim = "Flame", BurstOn = "Kill", Phase = 0 },
            { Mesh = "Torchbearer/FlameCore", Glow = true, Color = CORE, Uniform = true, Size = V(0.14, 0.058, 0.3), Off = V(0, 0.59, 0.085), Seat = true,
              Anim = "Flame", BurstOn = "Kill", Phase = 1.7 },
            { Mesh = "Torchbearer/Cuff", MeshV = VAR, Size = V(1.24, 1.24, 0.25), Off = V(0, 0, 0.5) },
        },
    }
end
Set.Sleeve = function(K: any)
    local V = K.V
    return {
        Id = "TorchbearerSleeves", Name = "Torchbearer Sleeves", Unlock = "Season", How = SEASON_HOW, Rarity = "Mythic",
        Desc = "Charcoal technical weave under an ivory enamel vambrace with a scarlet stripe and gold piping, a long gold laurel sprig down the forearm, a gold rank band with three scarlet chevrons and an ivory cuff rimmed in gold. A glint runs along the gold now and then.",
        Base = { Color = P.Weave, Material = K.SMOOTH, Reflectance = 0, Tex = "tex_ff_twill", TexTile = 0.9, TexT = 0, TexColor = P.Weave:Lerp(C(255, 255, 255), 0.08) },
        Parts = {
            { Mesh = "Torchbearer/Plate", MeshV = VAR, Size = V(1.118, 0.403, 0.74), Off = V(0, 0.354, 0.06) },
            { Mesh = "Torchbearer/Sprig", MeshV = VAR, Uniform = true, Size = V(0.475, 0.132, 2.09), Off = V(0, 0.62, 0.08), Seat = true },
            { Mesh = "Torchbearer/Band", MeshV = VAR, Size = V(1.12, 1.16, 0.144), Off = V(0, 0.02, -0.36) },
            { Mesh = "Torchbearer/SCuff", MeshV = VAR, Size = V(1.18, 1.18, 0.215), Off = V(0, 0, -0.46) },
            { Size = V(0.06, 0.015, 0.06), Off = V(0, 0.64, -0.36), Seat = true, Color = C(255, 246, 220), Glow = true, Uniform = true,
              Anim = "Twinkle", Period = 5.0, Dur = 0.35, PulseMin = 0.05, PulseMax = 1 },
        },
    }
end

-- ===== damage numbers (SKIN UI 2026-10-29, owner: numbers "unique to the skin and the colorways you have equipped"): with the
-- TORCHBEARER BLADE in your hands (HitNumbers reads Set.Numbers -- the set has no UI theme: it is a season reward, a theme
-- would be a new store item). THE CHAMPION'S FLAME: engraved serif digits (Garamond) that BURN like the blade -- a copy of the
-- digits laid over them carries this colourway's fire as a gradient (white-hot at the foot, the flame body, the outer flame at
-- the top: orange, blue or deep red) that licks up and down with a candle's flicker -- rising a little faster than usual.
-- CRIT = a gold LAUREL wreath closes round the digits leaf by leaf from the bottom up; WEAK SPOT = the digits burn white-hot;
-- a KILL = the fire FLARES (the whole number white-hot, then back) and embers rise off it.
-- (a flame image behind the digits was tried: the blade's own flipbook sheet read as pale smoke on a bright floor)
local TBR_LEAVES = 5 -- (leaves a side of the laurel)
local TBR_EMBERS = 3
local WHITE = Color3.new(1, 1, 1)
local function TbrMotion(e, age, pa, life)
    local k = math.min(1, age / 0.6)
    local up = 0.7 + 1.9 * (1 - (1 - k) ^ 2)
    local flick = math.sin(age * 23 + e.Seed) * 0.6 + math.sin(age * 37 + e.Seed * 2) * 0.4
    local scale = 1 + 0.02 * flick + ((pa < 0.07 and age > 0.08) and 0.06 * (1 - pa / 0.07) or 0)
    return up, 0, scale, 0, 0, flick * 0.8
end
local function TbrAccent(e)
    -- (ZIndex 2 over the number: the burning copy has to sit on top of the digits in either ZIndex mode)
    local f = Instance.new("Frame")
    f.Name = "TbrFire"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 2
    local burn = Instance.new("TextLabel")
    burn.Name = "Burn"; burn.BackgroundTransparency = 1; burn.Size = UDim2.fromScale(1, 1); burn.ZIndex = 3; burn.TextColor3 = WHITE
    burn:SetAttribute("KeepFont", true); burn.Parent = f
    local g = Instance.new("UIGradient"); g.Name = "Fire"; g.Rotation = 90; g.Parent = burn
    for side = 1, 2 do
        for j = 1, TBR_LEAVES do
            local l = Instance.new("Frame")
            l.Name = "Leaf" .. side .. "_" .. j; l.BorderSizePixel = 0; l.AnchorPoint = Vector2.new(0.5, 0.5); l.Size = UDim2.fromOffset(10, 4)
            l.ZIndex = 3; l.Parent = f
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = l
            local st = Instance.new("UIStroke"); st.Color = P.FInk; st.Thickness = 1; st.Parent = l
        end
    end
    for i = 1, TBR_EMBERS do
        local m = Instance.new("Frame")
        m.Name = "Ember" .. i; m.BorderSizePixel = 0; m.AnchorPoint = Vector2.new(0.5, 0.5); m.Size = UDim2.fromOffset(3, 3); m.ZIndex = 3; m.Parent = f
    end
    return f
end
local function TbrAccentStep(e, f, age, pa, alpha)
    local lbl = e.Label
    local tb = lbl.TextBounds
    local now = os.clock()
    local kt = (e.Killed and e.KillAt) and (now - e.KillAt) or nil
    local flare = kt and math.exp(-kt * 2.4) or 0
    local hot = (e.Weak and not e.Dot) and 0.55 or 0
    -- the burning copy of the digits: the fire gradient licks up and down (a candle's flicker)
    local burn = f:FindFirstChild("Burn")
    if burn then
        burn.Visible = not e.Dot
        if not e.Dot then
            if burn.Text ~= lbl.Text then burn.Text = lbl.Text end
            if burn.FontFace ~= lbl.FontFace then burn.FontFace = lbl.FontFace end
            if burn.TextSize ~= lbl.TextSize then burn.TextSize = lbl.TextSize end
            local fl = 0.5 + 0.5 * math.sin(age * 17 + e.Seed) * math.sin(age * 6.1 + e.Seed * 1.7)
            local g = burn:FindFirstChild("Fire")
            if g then
                local w = math.max(hot, flare)
                local top = (e.Crit and P.FRim or P.FOuter):Lerp(WHITE, w * 0.6)
                local mid = P.FBody:Lerp(WHITE, w)
                local foot = P.FCore:Lerp(WHITE, 0.2 + 0.8 * w)
                g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, top), ColorSequenceKeypoint.new(0.5, mid), ColorSequenceKeypoint.new(1, foot) })
                g.Offset = Vector2.new(0, (fl - 0.5) * 0.18)
            end
            burn.TextTransparency = math.clamp(alpha + 0.08 * fl, 0, 1)
        end
    end
    -- the laurel: two gold sprigs close round a crit from the bottom up each side, leaf by leaf, open at the top
    local crit = e.Crit and not e.Dot
    for side = 1, 2 do
        local s = (side == 1) and -1 or 1
        for j = 1, TBR_LEAVES do
            local l = f:FindFirstChild("Leaf" .. side .. "_" .. j)
            if l then
                l.Visible = crit
                if crit then
                    local k = math.clamp((age - (j - 1) * 0.03) / 0.06, 0, 1)
                    local th = math.rad(28 + (j - 1) * (112 / (TBR_LEAVES - 1))) -- (from under the digits up to their shoulder)
                    local rx, ry = tb.X / 2 + 8, tb.Y / 2 + 2
                    local x, y = s * math.sin(th) * rx, math.cos(th) * ry
                    local tx, ty = s * math.cos(th) * rx, -math.sin(th) * ry -- (leaves follow the sprig upward, tipped out a little)
                    l.Position = UDim2.new(0.5, x, 0.5, y)
                    l.Rotation = math.deg(math.atan2(ty, tx)) + s * 28
                    l.BackgroundColor3 = P.Gold:Lerp(P.Core, 0.3 * flare)
                    local tr = math.clamp(alpha + (1 - k), 0, 1)
                    l.BackgroundTransparency = tr
                    l:FindFirstChildOfClass("UIStroke").Transparency = math.clamp(tr + 0.3, 0, 1)
                end
            end
        end
    end
    -- embers off a kill: three sparks rising and drifting out of the flare
    for i = 1, TBR_EMBERS do
        local m = f:FindFirstChild("Ember" .. i)
        if m then
            local on = kt ~= nil and not e.Dot and kt < 1.1
            m.Visible = on
            if on then
                local k = kt / 1.1
                local sx = math.sin(e.Seed * 3 + i * 2.1) * (10 + 16 * k)
                m.Position = UDim2.new(0.5, sx, 0.5, -math.floor(tb.Y * 0.5) - 40 * k - i * 5)
                m.BackgroundColor3 = P.FCore:Lerp(P.Ember, k)
                m.BackgroundTransparency = math.clamp(alpha + k * 0.8, 0, 1)
            end
        end
    end
end
Set.Numbers = { Font = "Garamond", Glyph = "", NoBang = true, Motion = TbrMotion, Accent = TbrAccent, AccentStep = TbrAccentStep,
    Normal = P.FCore, Crit = P.FRim, Weak = P.FCore, Stroke = P.FInk, StrokeThick = 2, Size = 1.12 }
-- ===== the set entry: never sold (Unlock "Season", hidden from the store's bundle shelf); it ties the three pieces together
-- so the set's colourways work like every other set's (OwnsSetBase = every piece owned) and F6 can gift the whole set =====
Set.Bundle = { Id = "TorchbearerSet", Name = "Torchbearer Set", Unlock = "Season", How = SEASON_HOW, Rarity = "Mythic", ProductId = 0,
    Desc = "The Season 1 champion's set: the Torchbearer Gauntlets and Sleeves and the Torchbearer Blade. Earned at tier 50 of the Season 1 premium pass.",
    Contents = { "Glove:TorchbearerGauntlets", "Sleeve:TorchbearerSleeves", "MeleeSkin:Torchbearer" } }
Set.Hero = { Grad = { C(150, 110, 40), C(24, 16, 12) }, Stroke = C(255, 236, 190), Name = C(255, 246, 228), Chip = C(164, 26, 32) }

return Set
