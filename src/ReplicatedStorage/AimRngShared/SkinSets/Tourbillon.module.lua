--!nocheck
-- ===================================================================================================================
-- TOURBILLON (Skins V3, bundle 3 of docs/SKINS_V3_PLAN.md): AWP + Rhino | Escapement Balisong | 999 BP.
-- Haute horlogerie: the rifle is a skeleton watch movement in blued steel and deep rose gold. A rose-gold case on the
-- receiver -- angled to the shooter's eye like a watch on a wrist -- holds a TOURBILLON: a three-armed cage that turns
-- slowly with the escape wheel riding it, the balance wheel beating inside it under a domed crystal. The models are
-- RESCULPTED (WeaponAssets.SkinModels.Tourbillon_<GUN>, built by tools/skins_v3/tourbillon_build.py in
-- art/weapons/SkinsV3_Tourbillon.blend, painted by tools/skin_v3_paint.py with tools/skins_v3/tourbillon.json:
-- guilloche on the blued panels, perlage on the movement plates). This module brings their motion and the rest:
--   BEAT      the balance wheel never stops (+-110 deg at 2.5 Hz, riding the cage): the gun's heartbeat
--   CAGE      the tourbillon cage turns in small jumping steps; every shot advances it one escape tooth
--   TRAIN     a gear train behind a rose-gold shutter (AWP): the shutter slides away on inspect and the train runs a
--             quick-set spin, then settles; each shot steps it
--   BEZEL     the case bezel turns 60 deg on every reload (a diver's bezel click)
--   LUME      the indices + hands glow mint, brighter with the streak; equip = WINDING (the balance starts from rest
--             and builds amplitude over 0.6 s while the lume comes up)
--   SECONDS   the AWP's stock carries a sweeping seconds sub-dial; its magazine a POWER RESERVE gauge (rounds left)
-- Muzzle: a crisp flash + a dial ring of 12 lume indices; tracer: a fine line with 12 tick marks lighting in sequence
-- (a chronograph timing the shot); impact: a dial ring turning a quarter turn + brass sparks; kill STOPPED TIME (a dial
-- forms over the body, both hands sweep to twelve and freeze, it greys and fades); banner: a round watch plate beside
-- the HUD weapon card with a chronograph sub-dial whose hand laps once over a 5-kill streak.
-- Original design (the plan's Originality line): a mechanical watch movement -- escapement, balance wheel, crown,
-- guilloche, perlage, jewels -- is in none of its references; no orb, no ribbons, no gold truss, no capsule row.
-- ===================================================================================================================
local Set = { Kind = "Tourbillon" }

-- COLOURWAYS: each colourway is a whole palette; the module copy SkinFX loads for colourway v has attribute Colorway = v.
-- The painted model maps are separate SurfaceAppearances (SkinFX.V3Swap); Colorways.Sets.Tourbillon lists the names.
local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local PALETTES = {
    { Name = "Blued", Body = C(16, 22, 60), Mid = C(138, 74, 60), Detail = C(50, 54, 66), Dark = C(8, 10, 18), Ruby = C(150, 16, 34),
      Lume = C(130, 255, 200), Hot = C(220, 255, 240), Brass = C(255, 196, 140), Text = C(230, 225, 240), Ink = C(6, 8, 20), Grey = C(150, 156, 170), Shirt = C(24, 28, 50) },
    { Name = "Onyx", Body = C(16, 16, 19), Mid = C(150, 108, 44), Detail = C(50, 48, 50), Dark = C(6, 6, 8), Ruby = C(140, 16, 30),
      Lume = C(255, 210, 140), Hot = C(255, 240, 210), Brass = C(255, 210, 130), Text = C(240, 232, 214), Ink = C(4, 4, 6), Grey = C(160, 156, 150), Shirt = C(22, 22, 26) },
    { Name = "Sapphire Dial", Body = C(10, 44, 44), Mid = C(104, 108, 122), Detail = C(44, 54, 56), Dark = C(4, 13, 13), Ruby = C(150, 16, 34),
      Lume = C(160, 220, 255), Hot = C(225, 245, 255), Brass = C(210, 220, 235), Text = C(220, 236, 240), Ink = C(2, 10, 10), Grey = C(150, 160, 168), Shirt = C(14, 36, 38) },
    { Name = "Ruby", Body = C(48, 8, 17), Mid = C(138, 78, 64), Detail = C(56, 48, 50), Dark = C(13, 3, 6), Ruby = C(170, 26, 44),
      Lume = C(255, 226, 180), Hot = C(255, 244, 225), Brass = C(255, 200, 160), Text = C(245, 228, 226), Ink = C(12, 2, 6), Grey = C(165, 150, 150), Shirt = C(40, 14, 22) },
}
local P = PALETTES[VAR] or PALETTES[1]
local LUME, HOT, BODY, MID, DARK, RUBY, BRASS = P.Lume, P.Hot, P.Body, P.Mid, P.Dark, P.Ruby, P.Brass
Set.Palettes = PALETTES
Set.Colors = { Glow = LUME, Hot = HOT, Mid = MID }
-- art (tools/make_tourbillon_art.py, uploaded as decals with tools/upload_asset.py; these are the IMAGE ids, resolved in Studio)
local A = "rbxassetid://"
Set.Art = {
    EmblemTourbillon = A .. "123256427592575", tb_emblem = A .. "123256427592575", tb_emblem_mask = A .. "95742867000070",
    tb_dialring = A .. "71846226050356", tb_ticks = A .. "134605932790787", tb_dial = A .. "88157107839018", tb_hand = A .. "110495813207454",
    tb_plate = A .. "117867550548284", tb_subdial = A .. "103013855494490", tb_corner = A .. "114261254649005", tb_gear = A .. "70932771854439",
    SpGear = A .. "70932771854439", tb_balance = A .. "128312883013985", tex_tb_guilloche = A .. "80761443869336",
    tex_tb_perlage = A .. "137858810176473", tex_tb_bar = A .. "92685031404876",
    tex_tb_oxford = A .. "128697139227294", tex_tb_leather = A .. "90990506749126", -- (skins11 touch-up: arm materials)
}
local ART = Set.Art

-- sounds (tools/make_skin_sfx_v3.py tourbillon: each gun's own recorded shot + a deep escapement clack and two low watch
-- ticks; the moments from CC0 recordings of a pocket watch's winding, a stopwatch, wind-ups, a clockwork motor and a
-- balisong -- tools/sound_sources.json)
Set.Sounds = {
    Equip = { Id = 91650164141910, Volume = 0.45 }, MagOut = { Id = 130635497836081, Volume = 0.3 }, MagIn = { Id = 100459018614709, Volume = 0.35 },
    Kill = { Id = 136073478596025, Volume = 0.55 }, Impact = { Id = 117351898866339, Volume = 0.18 }, Swing = { Id = 113556446748870, Volume = 0.4 },
    MeleeHit = { Id = 73421901861098, Volume = 0.4 },
    FireGun = { AWP = { Id = 106118771413663, Volume = 0.9 }, RHINO = { Id = 122174705434413, Volume = 0.9 } },
}
local SND = { Bali = 76477500269815, Latch = 123950285830690, Quick = 126133497399087 }
-- the inspect's QUICK-SET whirr on the class inspect (every Tourbillon gun)
Set.InspectEvents = { { "Present+0.25", "Sound", { Id = SND.Quick, Volume = 0.3 } } }

local TAU = math.pi * 2
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

local function GunDesc(gun: string): string
    local what = (gun == "RHINO") and "a small sapphire window in the barrel shroud holds a tourbillon, the cylinder is cut like a crown wheel in rose-gold teeth and the grip carries engine-turned blued panels in a rose-gold frame"
        or "a rose-gold case on the receiver, angled to your eye, holds a tourbillon under a domed crystal; a gear train waits behind a sliding shutter, the stock carries a sweeping seconds sub-dial and the magazine a power-reserve gauge of the rounds left"
    return "Haute horlogerie in blued steel and deep rose gold. " .. string.upper(string.sub(what, 1, 1)) .. string.sub(what, 2) .. ". The balance wheel never stops beating, the cage steps forward with every shot and the bezel clicks round on every reload. Drawn, it WINDS: the balance starts from rest and the lume comes up. Dial-ring muzzle, a chronograph tracer, and every kill STOPS TIME."
end

-- ===== the guns =====
Set.GunSkins = {
    { Id = "TourbillonAWP", Name = "Tourbillon AWM", Gun = "AWP", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = GunDesc("AWP"), Model = "Tourbillon_AWP", V3 = true, Color = LUME, Deco = "TourbillonAWP",
      -- (gun-space studs, measured on the sculpt: the stock's seconds sub-dial + the magazine's power-reserve slot)
      Fit = { subdial = Vector3.new(-1.40, 0.025, -0.0612), subR = 0.039,
              reserve = { X = -0.465, Y0 = -0.14, Y1 = 0.012, Z = -0.0552, W = 0.03 } } },
    { Id = "TourbillonRHINO", Name = "Tourbillon Rhino", Gun = "RHINO", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = GunDesc("RHINO"), Model = "Tourbillon_RHINO", V3 = true, Color = LUME },
}

-- ===== small Roblox-part bits (the sculpt is the model) =====
Set.Build = {}
-- the AWP: the stock's sweeping seconds hand (lume needle + a rose-gold cap) and the magazine's power-reserve segments
Set.Build.TourbillonAWP = function(model: Model, frame: BasePart, f: any, forView: boolean, H: any)
    local c = f.subdial
    if c then
        local L = f.subR or 0.039
        local axis = frame.CFrame:VectorToWorldSpace(Vector3.new(0, 0, -1))
        local hand = H.Deco(model, { Name = "SecHand", Size = Vector3.new(0.0042, L * 1.25, 0.0016),
            CFrame = frame.CFrame * CFrame.new(c + Vector3.new(0, L * 0.38, -0.002)), Color = LUME, Glow = true })
        H.Rotor(hand, (frame.CFrame * CFrame.new(c)).Position, axis, 0)
        hand:SetAttribute("TurnDrive", "Seconds")
        local cap = H.Deco(model, { Name = "SecCap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.003, 0.012, 0.012),
            CFrame = frame.CFrame * CFrame.new(c + Vector3.new(0, 0, -0.0035)) * CFrame.Angles(0, math.pi / 2, 0), Color = MID, Material = Enum.Material.SmoothPlastic })
    end
    local r = f.reserve
    if r then
        -- five lume segments stacked in the slot, bottom = slot 1; they ride the magazine (out on a reload)
        local n = 5
        local h = (r.Y1 - r.Y0) / n
        for i = 1, n do
            local y = r.Y0 + (i - 0.5) * h
            local seg = H.Deco(model, { Name = "Reserve", Size = Vector3.new(r.W, h * 0.72, 0.003),
                CFrame = frame.CFrame * CFrame.new(r.X, y, r.Z), Color = LUME, Glow = true })
            seg:SetAttribute("Follow", "Magazine")
            seg:SetAttribute("CountDrive", "Reserve")
            seg:SetAttribute("CountSlot", i)
        end
    end
end

-- ===== motion: every key the parts read =====
-- (v = rig.SkinVars / rec.Vars: Phase, CageT, CageShot, CageGoal, Train, TrainGoal, TrainShot, Bezel, BezelGoal, Sec)
local function Quick(st: any, v: any): number
    -- the inspect's QUICK-SET: the train + cage run fast from just after the Present beat to the Tilt beat
    if st.Anim ~= "Inspect" or not st.AnimT then return 0 end
    local a, b = (v.QuickA or 0.8) + 0.25, (v.QuickB or 2.15) + 0.1
    local t = st.AnimT
    if t <= a or t >= b then return 0 end
    return math.sin((t - a) / (b - a) * math.pi) ^ 0.6
end
local function Keys(st: any, v: any, dt: number, now: number, quick: number, sinceShot: number)
    local se = st.SinceEquip or 99
    -- the cage: small jumping steps (5 a second), a full turn in ~15 s; a shot advances it one escape tooth (1/15)
    v.CageT = (v.CageT or math.random() * 15) + dt * (1 + 7 * quick)
    local steps = v.CageT * 5
    local stepAng = TAU / 15 / 5
    local cage = (math.floor(steps) + smooth((steps % 1) * 4)) * stepAng
    v.CageShot = (v.CageShot or 0) + ((v.CageGoal or 0) - (v.CageShot or 0)) * math.min(1, dt * 22)
    st.Cage = -(cage + v.CageShot)
    -- the balance: beats on top of the cage (coaxial) -- amplitude builds over 0.6 s after the draw (WINDING)
    local amp = 1.92 * smooth(se / 0.6)
    v.Phase = (v.Phase or 0) + dt * 2.5 * TAU * (1 + 0.8 * quick)
    st.Beat = st.Cage + amp * math.sin(v.Phase)
    -- the train wheel: slow, stepped by shots, spun by the quick-set
    v.Train = (v.Train or 0) + dt * (TAU / 24) * (1 + 60 * quick)
    v.TrainShot = (v.TrainShot or 0) + ((v.TrainGoal or 0) - (v.TrainShot or 0)) * math.min(1, dt * 18)
    st.Train = v.Train + v.TrainShot
    -- the bezel: eased toward its goal (60 deg per reload)
    v.Bezel = (v.Bezel or 0) + ((v.BezelGoal or 0) - (v.Bezel or 0)) * math.min(1, dt * 14)
    st.Bezel = -v.Bezel
    -- the seconds hand sweeps (a turn in 12 s), faster during the quick-set
    v.Sec = (v.Sec or 0) + dt * (TAU / 12) * (1 + 10 * quick)
    st.Seconds = -v.Sec
    -- the shutter: open for the inspect
    st.Shutter = smooth((st.Inspect or 0) * 1.25)
    -- lume: comes up on the draw, brighter with the streak and the inspect, a flick on each shot
    local lume = 0.42 + 0.09 * math.min(st.Streak or 0, 5) + 0.35 * (st.Inspect or 0) + 0.35 * math.exp(-sinceShot / 0.25)
    if se < 0.6 then lume *= smooth(se / 0.6) end
    st.Lume = math.clamp(lume, 0, 1)
    -- power reserve: the rounds left in 5 segments; a reload drains it, then refills bottom -> top
    local res = math.ceil((st.Ammo or 1) * 5 - 1e-6)
    local rl = st.Reload or 0
    if rl > 0 then
        if rl < 0.3 then res = math.ceil(res * (1 - rl / 0.3)) elseif rl < 0.6 then res = 0 else res = math.floor(smooth((rl - 0.6) / 0.35) * 5 + 0.5) end
    end
    st.Reserve = res
end
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    local v = rig.SkinVars
    -- (ViewmodelRig writes st.Anim / st.AnimT only AFTER the set's Drive: read them from the rig, or the quick-set never ran)
    st.Anim, st.AnimT = rig.AnimName, rig.AnimTime
    if rig.Anim and rig.Anim.Beats and st.Anim == "Inspect" then
        v.QuickA = rig.Anim.Beats.Present or rig.Anim.Beats.Raise or v.QuickA
        v.QuickB = rig.Anim.Beats.Tilt or rig.Anim.Beats.Flip or v.QuickB
    end
    Keys(st, v, dt, now, Quick(st, v), st.SinceShot or 99)
end
Set.OnFire = function(rig: any, H: any)
    local v = rig.SkinVars
    if not v then return end
    v.CageGoal = (v.CageGoal or 0) + TAU / 15
    v.TrainGoal = (v.TrainGoal or 0) + TAU / 24
end
-- the reload: the bezel clicks round 60 deg as the new magazine (AWP) / the cylinder (Rhino) seats
Set.OnEvent = function(rig: any, name: string, H: any)
    local v = rig.SkinVars
    if not v then return end
    if name == "MagIn" or name == "CylClose" then
        v.BezelGoal = (v.BezelGoal or 0) + TAU / 6
    end
end
-- other players' guns: the beat, the cage and the train turning, now and then the shutter opens for a look
Set.World = function(rec: any, now: number, st: any)
    local v = rec.Vars
    local last = v.LastT or now
    v.LastT = now
    local dt = math.clamp(now - last, 0, 0.2)
    v.NextLook = v.NextLook or (now + 4 + math.random() * 6)
    local ins = 0
    if now >= v.NextLook then
        local k = (now - v.NextLook) / 2.4
        if k >= 1 then v.NextLook = now + 9 + math.random() * 6 else ins = math.clamp(math.sin(k * math.pi) * 1.6, 0, 1) end
    end
    st.Inspect = ins
    st.Anim, st.AnimT = nil, nil
    st.SinceEquip = 99; st.Reload = 0; st.Streak = 1; st.Ammo = 1
    Keys(st, v, dt, now, ins > 0.6 and 0.5 or 0, 99)
end

-- ===== muzzle: a crisp small flash (no fireball), a dial ring of 12 lume indices snapping open (0.12 s) =====
Set.Muzzle = function(rig: any, flash: ParticleEmitter, light: PointLight, muzzle: Attachment, H: any)
    flash.Color = ColorSequence.new(HOT, LUME)
    flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.02) })
    light.Color = LUME
    light.Brightness = 0.7
    if rig.Fx and rig.Fx.Smoke then rig.Fx.Smoke.Color = ColorSequence.new(C(60, 62, 72)) end
    rig.Fx.TBDial = H.Emitter(muzzle, { Name = "TBDial", Texture = ART.tb_dialring, Color = { HOT, LUME }, Size = { 0.08, 0.72 },
        Life = { 0.12, 0.13 }, Speed = { 0.4, 0.8 }, Spread = 0, Dir = Enum.NormalId.Right, Orient = Enum.ParticleOrientation.VelocityPerpendicular,
        Trans = { 0.05, 1 }, Locked = false })
end
local baseOnFire = Set.OnFire
Set.OnFire = function(rig: any, H: any)
    baseOnFire(rig, H)
    if rig.Fx and rig.Fx.TBDial then rig.Fx.TBDial:Emit(1) end
end

-- ===== CHRONOGRAPH tracer: a fine lume line + 12 tick marks along it that light in sequence from the gun to the hit
-- (a chronograph timing the shot), then fade (0.3 s) =====
local function TickSeq(front: number, age: number): NumberSequence
    -- ticks behind the front are lit (fading with age), ahead of it dark; 11 keypoints over the length
    local kp = {}
    for i = 0, 10 do
        local x = i / 10
        local tr = (x <= front) and math.clamp(0.05 + age + (front - x) * 0.25, 0, 1) or 1
        kp[#kp + 1] = NumberSequenceKeypoint.new(x, tr)
    end
    return NumberSequence.new(kp)
end
Set.Tracer = function(H: any, from: Vector3, to: Vector3, peer: boolean?)
    local dist = (to - from).Magnitude
    if dist < 2 then return end
    local host = H.FxPart({ Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1), CFrame = CFrame.new(from) })
    local a0, a1 = H.Att(host, from), H.Att(host, to)
    local line = Instance.new("Beam")
    line.Attachment0, line.Attachment1 = a0, a1
    line.Color = ColorSequence.new(HOT, LUME); line.LightEmission = 1; line.LightInfluence = 0; line.FaceCamera = true; line.Segments = 1
    line.Width0, line.Width1 = 0.035, 0.02
    line.Parent = host
    local ticks = Instance.new("Beam")
    ticks.Attachment0, ticks.Attachment1 = a0, a1
    ticks.Texture = ART.tb_ticks; ticks.TextureMode = Enum.TextureMode.Stretch; ticks.TextureLength = 1
    ticks.Color = ColorSequence.new(LUME); ticks.LightEmission = 1; ticks.LightInfluence = 0; ticks.FaceCamera = true; ticks.Segments = 1
    ticks.Width0, ticks.Width1 = 0.24, 0.16
    ticks.Transparency = NumberSequence.new(1)
    ticks.Parent = host
    local dur = peer and 0.22 or 0.32
    H.Animate(dur, function(t)
        local front = 1 -- (hitscan look: every tick lights at once, no front running down the line)
        ticks.Transparency = TickSeq(front, math.clamp((t - 0.12) / (dur - 0.12), 0, 1))
        line.Transparency = NumberSequence.new(math.clamp(0.15 + t / dur, 0, 1))
        line.Width0 = 0.035 * (1 - t / dur)
    end, function() host:Destroy() end)
end

-- ===== impact: a dial ring set into the surface turns a quarter turn and fades + a few brass sparks (no light) =====
Set.Impact = function(H: any, pos: Vector3, normal: Vector3?, peer: boolean?)
    if not H.Budget("TourbillonImpact", peer and 3 or 8, 0.45) then return end
    local n = (normal and normal.Magnitude > 0.1) and normal.Unit or Vector3.yAxis
    local face = CFrame.lookAt(pos + n * 0.03, pos + n * 2) * CFrame.Angles(0, 0, math.random() * 6.28)
    local p = H.FxPart({ Transparency = 1, Size = Vector3.new(0.6, 0.6, 0.02), CFrame = face })
    local dec = Instance.new("Decal")
    dec.Texture = ART.tb_dialring; dec.Face = Enum.NormalId.Front; dec.Color3 = LUME; dec.Transparency = 0.05
    dec.Parent = p
    local att = H.Att(p, pos + n * 0.05)
    local sp = H.Emitter(att, { Texture = H.SPARK, Color = { BRASS, MID }, Size = { 0.07, 0 }, Life = { 0.15, 0.3 }, Speed = { 3, 7 }, Spread = 55,
        Accel = Vector3.new(0, -14, 0) })
    sp.EmissionDirection = Enum.NormalId.Front
    sp:Emit(peer and 2 or 6)
    H.Animate(0.4, function(t)
        local k = t / 0.4
        local e = 1 - (1 - math.min(k / 0.6, 1)) ^ 3
        local s = 0.42 + 0.3 * e
        p.Size = Vector3.new(s, s, 0.02)
        p.CFrame = face * CFrame.Angles(0, 0, -e * math.pi / 2)
        dec.Transparency = math.clamp(0.05 + k ^ 1.6, 0, 1)
    end, function() p:Destroy() end)
end

-- ===== WOUND DOWN kill (v3, owner 2026-10-14 on v2 "not great ... Fission or Ferroflux are the ideal": the BODY itself
-- must transform into a big finish on the real floor). ONE idea: the enemy's time runs out -- it is wound down into a clock.
-- 1) THE DIAL (0 -> 0.2): a watch dial opens on the real floor (~6.6 studs, lume ring on a blued face over an ink disc);
-- 2) WOUND DOWN (0.06 -> 0.6): the body is wound into it -- every part spirals round the body's axis (backwards, like a
-- spring unwinding), drawing in, shrinking and dropping, warming to brass as it goes; the two rose-gold hands on the dial
-- spin backwards fast (time rewinding); 3) TICK - TICK - STOP (0.62 / 0.76 / 0.9): the hands slow to three hard ticks and
-- lock on twelve -- a lume ring clicks out and a few cogs jump; 4) the dial winds shut to its centre (1.0 -> 1.4).
-- All motion is IN and DOWN; the glow is flat on the floor. Budget: full = ink + dial card + 2 hands + ring + host +
-- <= 8 body parts = 14 parts, 10 cogs; low: ink + dial card + 2 hands + host + 3 body parts, 5 cogs. =====
local GREY = P.Grey
local function TbBits(pos: Vector3, H: any): { BasePart }
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
    end
    return out
end
Set.Kill = function(H: any, pos: Vector3, low: boolean)
    local model = Instance.new("Model")
    model.Name = "TourbillonKill"
    model.Parent = H.FxFolder()
    local ground = H.Ground(pos)
    local axis = Vector3.new(pos.X, ground.Y, pos.Z)
    local cam = workspace.CurrentCamera
    local toCam = cam and (cam.CFrame.Position - axis) or Vector3.new(0, 0, 1)
    toCam = Vector3.new(toCam.X, 0, toCam.Z)
    toCam = (toCam.Magnitude > 0.05) and toCam.Unit or Vector3.new(0, 0, 1)
    -- the dial frame on the floor: "twelve" points away from you, so the hands read as a clock from where you stand
    local dialCF = CFrame.lookAt(axis, axis - toCam) -- (-Z = away = twelve)
    local RD = 3.3
    local ink = H.FxPart({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Size = Vector3.new(0.04, 0.2, 0.2), Color = P.Ink,
        Transparency = 1, CFrame = CFrame.new(axis + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.pi / 2) }, model)
    local card = H.FxPart({ Transparency = 1, Size = Vector3.new(0.2, 0.02, 0.2), CFrame = dialCF + Vector3.new(0, 0.07, 0) }, model)
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Top; sg.LightInfluence = 0; sg.AlwaysOnTop = false; sg.CanvasSize = Vector2.new(400, 400); sg.Parent = card
    local face = H.New("Frame", { BackgroundColor3 = BODY, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.94, 0.94), BackgroundTransparency = 1 }, sg)
    H.New("UICorner", { CornerRadius = UDim.new(0.5, 0) }, face)
    local dial = H.New("ImageLabel", { BackgroundTransparency = 1, Image = ART.tb_dial, ImageColor3 = LUME, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.86), ImageTransparency = 1, ZIndex = 2 }, sg)
    local bezel = H.New("ImageLabel", { BackgroundTransparency = 1, Image = ART.tb_dialring, ImageColor3 = BRASS, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ImageTransparency = 1, ZIndex = 3 }, sg)
    -- the two hands: rose-gold bars lying on the dial (hour + minute), turning about the dial's centre
    local function hand(len, wid)
        return H.FxPart({ Material = Enum.Material.SmoothPlastic, Size = Vector3.new(wid, 0.12, len), Color = BRASS:Lerp(MID, 0.35), Transparency = 1, CFrame = dialCF }, model)
    end
    local hHour, hMin = hand(RD * 0.5, 0.36), hand(RD * 0.78, 0.24)
    local ring = (not low) and H.FxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.025, 0.2, 0.2), Color = LUME, Transparency = 1,
        CFrame = CFrame.new(axis + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2) }, model) or nil
    -- the body (its own colours), wound down into the dial
    local bits = {}
    for _, s in ipairs(TbBits(pos, H)) do
        if #bits >= (low and 3 or 8) then break end
        local col = (math.min(s.Color.R, s.Color.G, s.Color.B) > 0.9) and GREY or s.Color -- (a hit-flash white body: grey)
        local p = H.FxPart({ Material = (s.Material == Enum.Material.Neon) and Enum.Material.Neon or Enum.Material.SmoothPlastic, Size = s.Size, CFrame = s.CFrame,
            Color = col, Transparency = s.Transparency, Shape = (s:IsA("Part") and s.Shape == Enum.PartType.Ball) and Enum.PartType.Ball or nil }, model)
        local rel = s.CFrame.Position - axis
        table.insert(bits, { P = p, CF = s.CFrame, Size = s.Size, C0 = col, T = s.Transparency, Ang = math.atan2(rel.Z, rel.X), Rad = math.max(0.35, Vector3.new(rel.X, 0, rel.Z).Magnitude),
            Hgt = rel.Y, Delay = math.random() * 0.06 })
    end
    local host = H.FxPart({ Transparency = 1, Size = Vector3.new(1.2, 0.3, 1.2), CFrame = CFrame.new(axis + Vector3.new(0, 0.3, 0)) }, model)
    local cogs = H.Emitter(host, { Name = "TbCogs", Texture = ART.SpGear, Color = { BRASS, MID }, Size = { 0.7, 0.45 }, Life = { 0.45, 0.65 },
        Speed = { 6, 10 }, Spread = 50, Dir = Enum.NormalId.Top, Accel = Vector3.new(0, -34, 0), Drag = 0.6, Light = 0, Influence = 0.6, Spin = { -260, 260 }, Rot = { 0, 360 } })
    cogs.Shape = Enum.ParticleEmitterShape.Box
    local TICKS = { 0.62, 0.76, 0.9 }
    local clicked = false
    local dur = low and 1.15 or 1.4
    local hourA0, minA0 = math.random() * TAU, math.random() * TAU
    H.Animate(dur, function(t, dt)
        -- 1) the DIAL opens on the floor (0 -> 0.2) and 4) winds shut to its centre at the end
        local open = 1 - (1 - math.min(1, t / 0.2)) ^ 3
        local shut = smooth((t - (dur - 0.4)) / 0.38)
        local R = RD * open * (1 - shut)
        local dia = math.max(0.1, R * 2)
        ink.Size = Vector3.new(0.04, dia + 0.5, dia + 0.5)
        ink.Transparency = (R < 0.05) and 1 or 0
        card.Size = Vector3.new(dia, 0.02, dia)
        card.CFrame = dialCF * CFrame.Angles(0, -shut * 2.5, 0) + Vector3.new(0, 0.07, 0)
        local vis = (R < 0.05) and 1 or 0
        face.BackgroundTransparency = vis; dial.ImageTransparency = vis; bezel.ImageTransparency = vis
        -- 2) WOUND DOWN: each part spirals backwards round the axis, in and down, shrinking, warming to brass
        for _, b in ipairs(bits) do
            local k = smooth((t - 0.06 - b.Delay) / 0.54)
            local a = b.Ang - k * TAU * 1.25
            -- (the parts swing OUT on the spiral, then in: a whirl you can see at range, not a spin in place)
            local rad = b.Rad * (1 - k) + 0.2 * k + 1.6 * math.sin(k * math.pi)
            local y = ground.Y + b.Hgt * (1 - k) ^ 1.4 + 0.25 * k
            b.P.CFrame = CFrame.new(axis.X + math.cos(a) * rad, y, axis.Z + math.sin(a) * rad) * CFrame.Angles(0, -k * TAU * 1.25, 0) * b.CF.Rotation
            b.P.Size = b.Size * (1 - 0.7 * k)
            b.P.Color = b.C0:Lerp(BRASS, smooth((k - 0.35) / 0.6) * 0.8)
            b.P.Transparency = (k >= 0.98) and 1 or b.T
        end
        -- the hands: spin BACKWARDS fast while it winds (rewinding), then three hard ticks onto twelve, then lock
        local hA, mA
        if t < TICKS[1] then
            local r = smooth(t / TICKS[1])
            mA = minA0 - t * 22 * (1 - 0.6 * r) - TAU * 2
            hA = hourA0 - t * 6
            -- (ease toward the first tick position)
            local blend = smooth((t - TICKS[1] + 0.15) / 0.15)
            mA = mA * (1 - blend) + (math.rad(-18)) * blend
            hA = hA * (1 - blend) + (math.rad(-12)) * blend
        else
            local n = 0
            for _, tk in ipairs(TICKS) do if t >= tk then n += 1 end end
            local since = t - TICKS[n]
            local snap = math.min(1, since / 0.04)
            local fromM, toM = math.rad(-18 + 6 * (n - 1)), math.rad(-18 + 6 * n)
            local fromH, toH = math.rad(-12 + 4 * (n - 1)), math.rad(-12 + 4 * n)
            if n >= 3 then toM, toH = 0, 0 end
            local recoil = math.sin(math.min(1, since / 0.1) * math.pi) * math.exp(-since * 20) * math.rad(3)
            mA = fromM + (toM - fromM) * snap + recoil
            hA = fromH + (toH - fromH) * snap + recoil * 0.6
        end
        local hv = (R < 0.3) and 1 or 0
        local function place(p, ang, len)
            local L = math.min(len, R * (len / RD) * 1.0)
            p.Size = Vector3.new(p.Size.X, 0.12, math.max(0.1, L))
            p.CFrame = dialCF * CFrame.Angles(0, -ang, 0) * CFrame.new(0, 0.16, -L / 2)
            p.Transparency = hv
        end
        place(hMin, mA, RD * 0.78)
        place(hHour, hA, RD * 0.5)
        -- 3) STOP: at the third tick a lume ring clicks out across the dial and cogs jump
        if t >= TICKS[3] and not clicked then
            clicked = true
            cogs:Emit(low and 5 or 10)
        end
        if ring then
            local rk = math.clamp((t - TICKS[3]) / 0.3, 0, 1)
            local rd = RD * 1.2 + RD * 1.2 * rk
            ring.Size = Vector3.new(0.025, rd, rd)
            ring.Transparency = (t < TICKS[3] or rk >= 1) and 1 or (0.1 + 0.9 * rk)
        end
    end, function() model:Destroy() end)
end

-- ===== CHRONOGRAPH banner (beside the HUD's weapon card, <= 180 x 90): a round watch plate with a lume sub-dial; each kill
-- of the streak advances its hand a fifth of a lap (one more index lights); at 5 the hand completes the lap and the
-- lume ring flares once. The number is the HUD's number face. =====
local banner
local NUMFONT = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold)
Set.Banner = function(H: any, streak: number)
    local gui, root = H.BannerRoot("Tourbillon", Vector2.new(180, 90), "Side")
    if not root then return end
    local New = H.New
    if not banner or banner.Root ~= root then
        local plate = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.tb_plate, ImageColor3 = MID, Size = UDim2.fromOffset(84, 84),
            Position = UDim2.fromOffset(3, 3), ZIndex = 2 }, root)
        local sub = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.tb_subdial, ImageColor3 = LUME, AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(45, 45), ImageTransparency = 0.25, ZIndex = 3 }, root)
        local pips = {}
        for i = 1, 5 do
            local a = math.rad(-90 + (i - 1) * 72)
            pips[i] = New("Frame", { BorderSizePixel = 0, BackgroundColor3 = LUME, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6),
                Position = UDim2.fromOffset(45 + math.cos(a) * 18.5, 45 + math.sin(a) * 18.5), ZIndex = 4 }, root, { New("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        end
        local pv = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), Position = UDim2.fromOffset(45, 45), ZIndex = 5 }, root)
        local hand = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.tb_hand, ImageColor3 = HOT, AnchorPoint = Vector2.new(0.5, 0.875),
            Size = UDim2.fromOffset(7, 30), ZIndex = 5 }, pv)
        local cap = New("Frame", { BorderSizePixel = 0, BackgroundColor3 = MID, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7),
            Position = UDim2.fromOffset(45, 45), ZIndex = 6 }, root, { New("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
        local glow = New("ImageLabel", { BackgroundTransparency = 1, Image = H.Art.Glow, ImageColor3 = LUME, AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(120, 120), Position = UDim2.fromOffset(45, 45), ImageTransparency = 0.85, ZIndex = 1 }, root)
        local num = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(96, 42), Size = UDim2.fromOffset(80, 40),
            FontFace = NUMFONT, TextSize = 32, TextColor3 = P.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 6 }, root)
        num:SetAttribute("KeepFont", true)
        New("UIStroke", { Color = P.Ink, Thickness = 2 }, num)
        banner = { Root = root, Plate = plate, Sub = sub, Pips = pips, Pivot = pv, Hand = hand, Cap = cap, Glow = glow, Num = num, Token = 0, Angle = 0 }
    end
    local b = banner
    b.Token += 1
    local token = b.Token
    local st = math.clamp(streak or 1, 1, 5)
    root.Visible = true
    for _, o in ipairs({ b.Plate, b.Hand }) do o.ImageTransparency = 0 end
    b.Sub.ImageTransparency = 0.25
    b.Cap.BackgroundTransparency = 0
    b.Num.TextTransparency = 0
    b.Num.Text = "x" .. st
    b.Num.TextColor3 = (st >= 5) and LUME or P.Text
    for i, pp in ipairs(b.Pips) do pp.BackgroundTransparency = (i <= st) and 0 or 0.8 end
    local from, to = (st - 1) * 72, st * 72
    H.Animate(0.38, function(t)
        if b.Token ~= token then return end
        local k = t / 0.38
        local c = 1.7
        local e = 1 + (c + 1) * (k - 1) ^ 3 + c * (k - 1) ^ 2 -- (back-out: the hand overshoots and settles like a jumping seconds)
        b.Pivot.Rotation = from + (to - from) * e
        if st >= 5 then
            b.Sub.ImageTransparency = 0.25 * (1 - math.sin(k * math.pi))
            b.Glow.ImageTransparency = 0.85 - 0.45 * math.sin(k * math.pi)
        end
    end)
    task.delay(1.6, function()
        if b.Token ~= token then return end
        local ti = TweenInfo.new(0.3)
        for _, o in ipairs({ b.Plate, b.Sub, b.Hand }) do H.TweenService:Create(o, ti, { ImageTransparency = 1 }):Play() end
        H.TweenService:Create(b.Glow, ti, { ImageTransparency = 1 }):Play()
        H.TweenService:Create(b.Num, ti, { TextTransparency = 1 }):Play()
        H.TweenService:Create(b.Cap, ti, { BackgroundTransparency = 1 }):Play()
        for _, pp in ipairs(b.Pips) do H.TweenService:Create(pp, ti, { BackgroundTransparency = 1 }):Play() end
        task.delay(0.32, function() if b.Token == token then root.Visible = false end end)
    end)
end

-- ===== the ESCAPEMENT BALISONG (melee, class Balisong): blued-steel skeleton handles cut like watch bridges (polished
-- rose-gold anglage, ruby jewels showing through their windows from the movement plate behind), rose-gold pins, a
-- slim spear-point blade in engine-turned blued steel with a lume line, a winding-crown latch that spins on the final
-- catch (MeleeModels.Tourbillon) =====
local Inspects = require(game:GetService("ReplicatedStorage"):WaitForChild("AimRngShared"):WaitForChild("Inspects"))
local PIN_A, PIN_B = Vector3.new(-0.022, 0.225, 0), Vector3.new(0.022, 0.225, 0) -- (tourbillon_build.py PIN_A / PIN_B + MELEE_LIFT 0.06)
Set.Melee = {
    Skin = { Name = "Escapement Balisong", Price = 449, ProductId = 0,
        Desc = "A butterfly knife built like a watch: blued-steel skeleton handles cut as movement bridges with polished rose-gold edges and rubies glinting through their windows, rose-gold pins, and a slim spear-point blade in engine-turned blued steel with a lume line. It flips open on the draw, fans and flips in the hand when you inspect it, and the winding crown at its butt spins as it latches. Every kill STOPS TIME." },
    Rig = { Class = "Balisong", BladeLen = 0.62 },
    -- (our own beat on the class inspect: the latch crown spins on the final catch -- Set.OnEvent "BaliLatch" -- and the
    -- lume brightens on the fan)
    InspectEvents = { { "Fan", "Emit", { Name = "TBMeleeLume", Count = 5 } }, { "Flip+0.4", "Sound", { Id = SND.Bali, Volume = 0.35 } },
        { "Flip+0.57", "Sound", { Id = SND.Latch, Volume = 0.35 } } },
    -- the class draw + its BaliOpen / BaliLatch moments: our flip click + the crown's ratchet as it latches
    EquipAnim = function(rig: any, classAnim: any)
        if type(classAnim) ~= "table" then return nil end
        local a = table.clone(classAnim)
        a.Events = table.clone(classAnim.Events or {})
        for _, e in ipairs(classAnim.Events or {}) do
            if e[2] == "BaliOpen" then table.insert(a.Events, { e[1], "Sound", { Id = SND.Bali, Volume = 0.35 } }) end
            if e[2] == "BaliLatch" then table.insert(a.Events, { e[1], "Sound", { Id = SND.Latch, Volume = 0.3 } }) end
        end
        table.sort(a.Events, function(x, y) return x[1] < y[1] end)
        return a
    end,
    Build = function(m: Model, o: any, H: any)
        local parts = H.CloneModel(m, "MeleeModels", "Tourbillon", VAR, { [1] = LUME })
        -- (handle A's lume pips are part of the grip: named so, the melee clip check treats them as held, not as a blade)
        if parts.Glow_A then parts.Glow_A.Name = "Glow_GripA" end
        for _, n in ipairs({ "Blade", "Glow_Blade" }) do if parts[n] then Inspects.Hinge(parts[n], PIN_A, Vector3.zAxis, 180, "BaliBlade") end end
        for _, n in ipairs({ "HandleB", "Glow_B" }) do if parts[n] then Inspects.Hinge(parts[n], PIN_B, Vector3.zAxis, 180, "BaliB") end end
        local blade = parts.Blade
        if not blade then return end
        -- the swing trail: down the blade (its root -> tip, melee space)
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Name, a1.Name = "TrailBase", "TrailTip"
        a0.Position = blade.CFrame:PointToObjectSpace(Vector3.new(0.005, 0.38, 0))
        a1.Position = blade.CFrame:PointToObjectSpace(Vector3.new(0.003, 0.86, 0))
        a0.Parent, a1.Parent = blade, blade
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Color = ColorSequence.new(HOT, LUME)
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
        tr.LightEmission = 0.8; tr.LightInfluence = 0
        tr.Lifetime = 0.14; tr.MinLength = 0.02; tr.FaceCamera = true
        tr.Enabled = false
        tr:SetAttribute("SwingTrail", true)
        tr.Parent = blade
        local sa = Instance.new("Attachment"); sa.Position = blade.CFrame:PointToObjectSpace(Vector3.new(0, 0.51, 0)); sa.Parent = blade
        H.Emitter(sa, { Name = "TBMeleeLume", Texture = ART.tb_dialring, Color = { HOT, LUME }, Size = { 0.04, 0.22 }, Life = { 0.25, 0.35 },
            Speed = { 0.2, 0.5 }, Trans = { 0.2, 1 }, SkinFx = true })
    end,
}
-- the melee's keys: the lume, the latch crown spin (after a BaliLatch), the swing flick
local function MeleeKeys(st: any, v: any, now: number)
    local sw = v.SwingT and (os.clock() - v.SwingT) or 99
    st.Lume = math.clamp(0.45 + 0.35 * (st.Inspect or 0) + 0.4 * math.exp(-sw / 0.25), 0, 1)
    local lt = v.LatchT and (os.clock() - v.LatchT) or 99
    v.LatchBase = v.LatchBase or 0
    st.Latch = v.LatchBase + ((lt < 99) and (TAU * 2.5 * (1 - math.exp(-lt * 5))) or 0)
end
local gunDrive = Set.Drive
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    if rig.Def and rig.Def.IsMelee then MeleeKeys(st, rig.SkinVars, now) return end
    gunDrive(rig, st, dt, now, H)
end
Set.OnAnim = function(rig: any, name: string)
    if rig.Def and rig.Def.IsMelee and (name:find("Light") or name:find("Heavy") or name:find("Quick")) then rig.SkinVars.SwingT = os.clock() end
end
local gunEvent = Set.OnEvent
Set.OnEvent = function(rig: any, name: string, H: any, data: any)
    local v = rig.SkinVars
    if v and name == "BaliLatch" then
        -- (the crown keeps its last angle, then spins two and a half turns as the latch catches)
        local lt = v.LatchT and (os.clock() - v.LatchT) or 99
        v.LatchBase = (v.LatchBase or 0) + ((lt < 99) and (TAU * 2.5 * (1 - math.exp(-lt * 5))) or 0)
        v.LatchT = os.clock()
        return
    end
    gunEvent(rig, name, H)
end

-- ===== arms: HOROLOGIST GLOVES + BENCH SLEEVES =====
-- glove: a thin black leather glove with a small rose-gold wristwatch on the back of the wrist (blued engine-turned dial,
-- lume indices, a ruby on its crown); ONE effect: its seconds hand sweeps (the lume flares on a kill)
Set.Glove = function(K: any)
    local V = K.V
    -- (piece offsets: the watch mesh's bbox centre is 0.0065 off the case centre on X (the crown) and the lume sits on the
    -- dial face, 0.011 mesh-studs above the bbox middle -- converted to the hand's units)
    return {
        Id = "HorologistGloves", Name = "Horologist Gloves", Price = 449,
        Desc = "Thin black leather gloves with a small rose-gold wristwatch on the back of the wrist: a blued, engine-turned dial with lume indices and a ruby on its crown. Its seconds hand sweeps without a stop, and the lume flares on every kill.",
        -- (skins11 touch-up, arms bar: fine kid-leather grain on the hand block -- it read as one flat black block)
        Base = { Color = C(16, 16, 20), Material = K.SMOOTH, Reflectance = 0.06, Tex = "tex_tb_leather", TexTile = 1.3, TexT = 0, TexColor = C(26, 26, 32) },
        Parts = {
            -- the strap (two short lengths each side of the case) + the watch
            -- (seen in play: at the wrist end the watch sat off the bottom of the screen -- the back of the hand is what the
            -- camera sees, so the watch is set into the glove's back, a thin blued band closing the cuff)
            { Size = V(1.1, 1.1, 0.1), Off = V(0, 0, 0.45), Color = DARK:Lerp(BODY, 0.5), Material = K.SMOOTH, Reflectance = 0.04 },
            -- (seen in play: tipped 40 deg toward the eye, half the case sank into the glove block and the lugs stood up like
            -- two posts -- it read as a bug, not a watch. The hands that show the watch (the melee hold, the support hand) show
            -- the glove's back face well, so the watch lies FLAT on it, case bottom on the face; nearer the wrist the rolled sleeve
            -- cuff hid it, so it sits just behind the knuckles' half of the back. GloveFX.Place scales offsets by the glove fit
            -- (0.8) while the hand block keeps its size: Off y 0.5 alone landed 0.03 stud INSIDE the block (measured in play)
            -- -> Seat = true keeps the Off point on the face in first AND third person, OffW = the case's half thickness)
            -- the lugs run ACROSS the wrist like a real wristwatch, the crown points at the fingers (the watch turned 90 deg; the
            -- dial's crown-side offset turns with it: mesh -X -> owner +Z). (A leather strap wrapping the glove was tried: under
            -- Molten it read as a second big red band on the hand -- the watch head alone reads cleaner.)
            { Mesh = "Tourbillon/Watch", MeshV = VAR, Uniform = true, Size = V(0.56, 0.113, 0.628), Off = V(0, 0.5, 0.08), OffW = V(0, 0.06, 0), Rot = V(0, 90, 0), Seat = true },
            { Mesh = "Tourbillon/WatchLume", MeshV = VAR, Glow = true, Color = LUME, Uniform = true, Size = V(0.37, 0.017, 0.37), Off = V(0, 0.5, 0.08),
              OffW = V(0, 0.11, 0.03), Rot = V(0, 90, 0), Seat = true, Transparency = 0.2, FlashOn = "Kill" },
            { Size = V(0.018, 0.009, 0.18), Uniform = true, Off = V(0, 0.5, 0.08), OffW = V(0, 0.116, 0.03), Seat = true, Color = LUME, Glow = true,
              Anim = "Clock", Hand = "S", Root = 1, Transparency = 0.1, FlashOn = "Kill" },
        },
    }
end
-- sleeve: a midnight oxford shirt sleeve rolled up in two crisp sculpted rolls at the wrist (the lining shows at the
-- fold), held by a blued-steel sleeve garter with a rose-gold clasp and a ruby
Set.Sleeve = function(K: any)
    local V = K.V
    return {
        Id = "BenchSleeves", Name = "Bench Sleeves", Price = 299,
        Desc = "A midnight oxford shirt sleeve rolled up for bench work: two crisp sculpted rolls at the wrist with the lining showing at the fold, held up the forearm by a blued, engine-turned sleeve garter with a rose-gold clasp and a ruby.",
        -- (the colourway's shirt; skins11 touch-up: an oxford weave texture -- the Fabric material's scanned weave never showed, the
        -- sleeve read as one flat navy block)
        Base = { Color = P.Shirt, Material = K.SMOOTH, Reflectance = 0, Tex = "tex_tb_oxford", TexTile = 1.2, TexT = 0, TexColor = P.Shirt:Lerp(C(255, 255, 255), 0.1) },
        Parts = {
            { Mesh = "Tourbillon/Roll", MeshV = VAR, Size = V(1.25, 1.25, 0.16), Off = V(0, 0, -0.42) },
            { Mesh = "Tourbillon/Garter", MeshV = VAR, Size = V(1.17, 1.17, 0.032), Off = V(0, 0, 0.02) },
            { Mesh = "Tourbillon/Clasp", MeshV = VAR, Uniform = true, Size = V(0.2, 0.067, 0.167), Off = V(0, 0.5, 0.02), OffW = V(0, 0.055, 0) },
        },
    }
end

-- ===== health bar: a slim blued-steel bar in a rose-gold frame, a lume fill with fine engine lines; a tiny balance wheel
-- rides the fill's end, oscillating -- a hit makes it tick backwards; rose-gold end caps =====
Set.Bar = { Id = "Tourbillon", Name = "Tourbillon", Price = 149,
    Desc = "A watch movement in a bar: a lume fill run through with fine engine lines over blued steel. Lost health is ticked away like a second hand -- it holds, then clicks out in steps -- and a lume escapement tick rides the end of the fill. On elites and bosses a tiny balance wheel beats there between rose-gold end caps. Part of the Tourbillon set.",
    Look = "Ink", FillColor = LUME, Tex = "tex_tb_bar", TexColor = LUME:Lerp(Color3.new(1, 1, 1), 0.15), TexSpeed = 6, ChipMotion = "Snap", Chip = BRASS,
    Back = DARK, Glow = LUME, Segments = 5, Decor = { "Escapement", "BalanceWheel", "RoseCaps" } }
Set.BarDecor = {
    -- (BARS v2, every size) the ESCAPEMENT: a lume tick in an ink notch at the end of the fill that steps once a second
    -- (a seconds hand), and kicks back a tick on every hit
    Escapement = function(ctx: any, K: any)
        local f = K.Fader()
        local ink = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = P.Ink, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 12 }, ctx.Holder)
        local tick = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = HOT, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(0, 2, 1, -2), ZIndex = 13 }, ink)
        f.Add(ink, 0, "BackgroundTransparency")
        f.Add(tick, 0, "BackgroundTransparency")
        local kick = 0
        return function(now, dt, alpha, info)
            if (info.Hit or 0) > 0.95 then kick = 1 end
            kick = math.max(0, kick - dt / 0.2)
            local stepOn = (now % 1) < 0.12
            ink.Size = UDim2.fromOffset(4, ctx.H + 4)
            ink.Position = UDim2.fromOffset(ctx.W * math.clamp(info.Shown, 0, 1) - 2 - kick * 3, ctx.H / 2)
            tick.BackgroundColor3 = stepOn and HOT or LUME
            f.Apply(alpha)
        end
    end,
    -- the fill texture is neutral: tint it the colourway's lume (a set image keeps its colours otherwise)
    LumeFill = function(ctx: any, K: any)
        for _, c in ipairs(ctx.Inner:GetChildren()) do if c:IsA("ImageLabel") then c.ImageColor3 = LUME:Lerp(Color3.new(1, 1, 1), 0.15) end end
        return function() end
    end,
    BalanceWheel = function(ctx: any, K: any)
        if ctx.Tier == "Small" then return function() end end
        local U = ctx.U
        local f = K.Fader()
        local pv = K.Pivot(ctx.Holder, 12)
        local wheel = f.Add(K.Img(ART.tb_balance, { AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = MID, ZIndex = 12 }, pv), 0)
        local jewel = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = RUBY, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 13 }, pv)
        K.New("UICorner", { CornerRadius = UDim.new(0.5, 0) }, jewel)
        f.Add(jewel, 0, "BackgroundTransparency")
        local back = 0
        return function(now, dt, alpha, info)
            local s = U * 1.15
            wheel.Size = UDim2.fromOffset(s, s)
            jewel.Size = UDim2.fromOffset(math.max(2, s * 0.18), math.max(2, s * 0.18))
            pv.Position = UDim2.fromOffset(ctx.W * math.clamp(info.Shown, 0.02, 1), ctx.H / 2)
            -- beats +-40 deg at 2.5 Hz; a hit kicks it a tick backwards (eased back out)
            back = math.max((info.Hit or 0) * 1, back - dt * 4)
            wheel.Rotation = 40 * math.sin(now * 2.5 * TAU) - 70 * back
            f.Apply(alpha)
        end
    end,
    RoseCaps = function(ctx: any, K: any)
        if ctx.Tier == "Small" then return function() end end
        local f = K.Fader()
        local caps = {}
        for i = 1, 2 do
            local c = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = MID, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 11 }, ctx.Holder)
            K.New("UICorner", { CornerRadius = UDim.new(0.35, 0) }, c)
            K.New("UIStroke", { Color = DARK, Thickness = 1 }, c)
            f.Add(c, 0, "BackgroundTransparency")
            caps[i] = c
        end
        return function(now, dt, alpha, info)
            local h = ctx.H * 1.35
            for i, c in ipairs(caps) do
                c.Size = UDim2.fromOffset(math.max(3, ctx.H * 0.42), h)
                c.Position = UDim2.fromOffset((i == 1) and -ctx.H * 0.1 or ctx.W + ctx.H * 0.1, ctx.H / 2)
            end
            f.Apply(alpha)
        end
    end,
}

local P1 = PALETTES[1]
-- ===== UI theme v2 (FX roll-out 2026-10-14; v1 = the shared template: tiled glass + 4 corner sprites + watermark + gears
-- ambient + the shared Sweep). Its own pieces in the icon look (flat lit face, one hard facet, ink edge): rose-gold BEZEL
-- BRACKETS on every window corner whose knurled edge turns slowly, a small SUB-DIAL riding the lower-right bracket whose
-- lume hand ticks once a second, a MINUTE TRACK under every title (fine ticks, every fifth long, one lume marker), and
-- windows open with a lume HAND sweeping once round the window while the knurls spin. Colours from the theme table. =====
local function TbFacet(ctx, o, lit, shade, th)
    local g = Instance.new("UIGradient")
    g.Color = ctx.UIStyle.Facet(lit, shade)
    g.Rotation = ctx.UIStyle.FACET_ROT or 20
    g.Parent = o
    ctx.UIStyle.InkEdge(th or 2).Parent = o
    return g
end
-- a knurl: fine dark ridges across a bracket arm (one gradient; its Offset turns the knurl)
local function Knurl(ctx, arm, vertical)
    local t = ctx.Theme
    local k = Instance.new("Frame")
    k.Name = "TbKnurl"; k.BackgroundColor3 = Color3.new(1, 1, 1); k.BorderSizePixel = 0; k.ZIndex = arm.ZIndex + 1
    k.Size = vertical and UDim2.new(0, 3, 1, -6) or UDim2.new(1, -6, 0, 3)
    k.AnchorPoint = Vector2.new(0.5, 0.5); k.Position = UDim2.fromScale(0.5, 0.5); k.Parent = arm
    local g = Instance.new("UIGradient")
    local kp = {}
    for i = 0, 9 do
        local a = i / 9
        table.insert(kp, ColorSequenceKeypoint.new(a, (i % 2 == 0) and t.BezelShade or t.BezelLit))
    end
    g.Color = ColorSequence.new(kp)
    g.Rotation = vertical and 90 or 0
    g.Parent = k
    return g
end
local function TbDeco(ctx)
    local t = ctx.Theme
    if ctx.Kind ~= "Window" then return nil end -- (HUD panels stay clean)
    local host = ctx.Root or ctx.Surface
    local f = Instance.new("Frame")
    f.Name = "TbOverlay"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 20; f.Active = false
    f:SetAttribute("NoSkin", true); f:SetAttribute("Skinned", true)
    f.Parent = host
    local abs = host.AbsoluteSize
    local small = math.min(abs.X, abs.Y) < 260
    local len = math.clamp(math.floor(math.min(abs.X, abs.Y) * 0.18), small and 20 or 38, small and 36 or 84)
    local th = small and 7 or 12
    local knurls = {}
    for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
        local ax, ay = c[1], c[2]
        for i = 1, 2 do
            local b = Instance.new("Frame")
            b.Name = "TbBezel"; b.BorderSizePixel = 0; b.BackgroundColor3 = Color3.new(1, 1, 1); b.ZIndex = f.ZIndex + 1
            b.Size = (i == 1) and UDim2.fromOffset(len, th) or UDim2.fromOffset(th, len)
            b.AnchorPoint = Vector2.new(ax, ay); b.Position = UDim2.new(ax, ax == 0 and 4 or -4, ay, ay == 0 and 4 or -4)
            b.Parent = f
            TbFacet(ctx, b, t.BezelLit, t.BezelShade)
            if not small then table.insert(knurls, Knurl(ctx, b, i == 2)) end
        end
    end
    -- the sub-dial on the lower-right bracket: a dark face, a rose-gold ring, a lume seconds hand
    local dial, hand
    if not small then
        local s = math.floor(len * 0.62)
        dial = Instance.new("Frame")
        dial.Name = "TbSubDial"; dial.BackgroundColor3 = t.DialFace; dial.BorderSizePixel = 0; dial.AnchorPoint = Vector2.new(0.5, 0.5)
        dial.Size = UDim2.fromOffset(s, s); dial.Position = UDim2.new(1, -4 - th - s * 0.55, 1, -4 - th - s * 0.55); dial.ZIndex = f.ZIndex + 2
        dial.Parent = f
        local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0.5, 0); cr.Parent = dial
        local ring = Instance.new("UIStroke"); ring.Color = t.BezelLit; ring.Thickness = 3; ring.Parent = dial
        for q = 0, 3 do -- (four lume indices)
            local ix = Instance.new("Frame")
            ix.BorderSizePixel = 0; ix.BackgroundColor3 = t.Lume; ix.AnchorPoint = Vector2.new(0.5, 0.5); ix.ZIndex = dial.ZIndex + 1
            ix.Size = UDim2.fromOffset(2, math.max(3, math.floor(s * 0.14)))
            ix.Rotation = q * 90
            ix.Position = UDim2.fromScale(0.5 + 0.38 * math.sin(q * math.pi / 2), 0.5 - 0.38 * math.cos(q * math.pi / 2))
            ix.Parent = dial
        end
        local pv = Instance.new("Frame")
        pv.BackgroundTransparency = 1; pv.Size = UDim2.fromScale(1, 1); pv.ZIndex = dial.ZIndex + 2; pv.Parent = dial
        hand = Instance.new("Frame")
        hand.BorderSizePixel = 0; hand.BackgroundColor3 = t.Lume; hand.AnchorPoint = Vector2.new(0.5, 1); hand.ZIndex = pv.ZIndex
        hand.Size = UDim2.new(0, 2, 0.4, 0); hand.Position = UDim2.fromScale(0.5, 0.5); hand.Parent = pv
        hand = pv
    end
    local lastSec = -1
    return function(now, dt)
        -- the knurls turn slowly (a bezel being wound)
        local off = (now * 0.08) % 0.2
        for _, g in ipairs(knurls) do g.Offset = Vector2.new(off, 0) end
        if hand then
            local sec = math.floor(now)
            if sec ~= lastSec then lastSec = sec; hand.Rotation = (sec % 60) * 6 end
        end
    end, { f }
end
local function TbOpen(ctx)
    -- a lume HAND sweeps once round the window from twelve (0.45 s) with a short fading trail; the knurls spin with it
    local t = ctx.Theme
    local f = (ctx.Root and ctx.Root:FindFirstChild("TbOverlay")) or ctx.Frame
    local abs = f.AbsoluteSize
    local L = math.max(40, math.min(abs.X, abs.Y) * 0.46)
    local pv = Instance.new("Frame")
    pv.Name = "TbSweep"; pv.BackgroundTransparency = 1; pv.AnchorPoint = Vector2.new(0.5, 0.5); pv.Position = UDim2.fromScale(0.5, 0.5)
    pv.Size = UDim2.fromOffset(L * 2, L * 2); pv.ZIndex = f.ZIndex + 5; pv.Parent = f
    local hands = {}
    for i = 0, 2 do -- (the hand + two fading echoes behind it: the trail)
        local h = Instance.new("Frame")
        h.BorderSizePixel = 0; h.BackgroundColor3 = (i == 0) and t.Lume or t.BezelLit; h.AnchorPoint = Vector2.new(0.5, 1)
        h.Size = UDim2.fromOffset(i == 0 and 4 or 3, L); h.Position = UDim2.fromScale(0.5, 0.5); h.ZIndex = pv.ZIndex + (2 - i)
        h.BackgroundTransparency = 0.15 + i * 0.3
        local g = Instance.new("UIGradient"); g.Rotation = 90
        g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.85) }); g.Parent = h
        if i == 0 then ctx.UIStyle.InkEdge(1).Parent = h end
        local holder = Instance.new("Frame")
        holder.BackgroundTransparency = 1; holder.Size = UDim2.fromScale(1, 1); holder.ZIndex = h.ZIndex; holder.Parent = pv
        h.Parent = holder
        hands[i + 1] = holder
    end
    local knurls = {}
    for _, d in ipairs(f:GetDescendants()) do
        if d.Name == "TbKnurl" then local g = d:FindFirstChildOfClass("UIGradient"); if g then table.insert(knurls, g) end end
    end
    local t0 = os.clock()
    local conn
    conn = game:GetService("RunService").RenderStepped:Connect(function()
        local k = math.min(1, (os.clock() - t0) / 0.45)
        local e = 1 - (1 - k) ^ 2
        for i, h in ipairs(hands) do h.Rotation = 360 * e - (i - 1) * 9 * (1 - k) end
        for _, g in ipairs(knurls) do g.Offset = Vector2.new((e * 0.6) % 0.2, 0) end
        if k >= 1 then conn:Disconnect(); pv:Destroy() end
    end)
end
local function TbTitle(ctx)
    -- a MINUTE TRACK under the title bar: a fine rose-gold line, 13 ticks (every third long) and one lume marker
    local bar, t = ctx.Title, ctx.Theme
    local track = Instance.new("Frame")
    track.Name = "TbTrack"; track.BackgroundTransparency = 1; track.AnchorPoint = Vector2.new(0, 1)
    track.Position = UDim2.new(0, 10, 1, -2); track.Size = UDim2.new(0.34, 0, 0, 7); track.ZIndex = bar.ZIndex + 1; track.Parent = bar
    local line = Instance.new("Frame")
    line.BorderSizePixel = 0; line.BackgroundColor3 = t.BezelLit; line.Size = UDim2.new(1, 0, 0, 1); line.AnchorPoint = Vector2.new(0, 1)
    line.Position = UDim2.fromScale(0, 1); line.ZIndex = track.ZIndex; line.Parent = track
    for i = 0, 12 do
        local tk = Instance.new("Frame")
        tk.BorderSizePixel = 0; tk.BackgroundColor3 = (i == 8) and t.Lume or t.BezelLit; tk.AnchorPoint = Vector2.new(0.5, 1)
        local long = (i % 3 == 0)
        tk.Size = UDim2.fromOffset((i == 8) and 3 or 1, (i == 8) and 7 or (long and 5 or 3))
        tk.Position = UDim2.fromScale(i / 12, 1); tk.ZIndex = track.ZIndex + ((i == 8) and 1 or 0); tk.Parent = track
    end
    return { track }
end
-- numbers v3 (SKIN UI 2026-10-29, owner: numbers "unique to the skin and the colorways you have equipped"; the minute track
-- under the number went -- a line under a number reads as "wrong"): TICK-TOCK. A slim face (Jura) that steps up and to the
-- right in five second-hand ticks (each a snap with a small recoil), a small SUB-DIAL beside it (a rose-gold case, a lume
-- hand) whose hand jumps one fifth with every tick. CRIT = the hand sweeps a full lap at once and the case flashes lume;
-- WEAK SPOT = the RUBY jewel at the dial's centre glints; a KILL = STOPPED TIME: the hand snaps to twelve, the digits stop
-- dead where they are and grey out. Every colour is this copy's palette (P = the colourway: Blued, Onyx, Sapphire Dial, Ruby).
local TB_TICK = 0.13
local function TbTicks(e, age)
    if e.Killed and e.KillAt then return math.min(age, math.max(0, e.KillAt - e.Born)) end -- (time stops at the kill)
    return age
end
local function TbMotion(e, age, pa, life)
    local t = TbTicks(e, age)
    local n = math.min(5, math.floor(t / TB_TICK))
    local sub = t - n * TB_TICK
    local k = (n == 0) and 0 or (n - 1 + math.min(1, sub / 0.035))
    local recoil = (n < 5) and math.sin(math.min(1, sub / 0.09) * math.pi) * math.exp(-sub * 25) or 0
    local up = 0.32 * math.min(k, 5)
    local side = 0.16 * math.min(k, 5)
    local scale = 1 + ((pa < 0.07 and age > 0.08) and 0.06 * (1 - pa / 0.07) or 0)
    return up, side, scale, 0, 0, -1.5 * recoil
end
local function TbAccent(e)
    local f = Instance.new("Frame")
    f.Name = "TbSubDial"; f.BackgroundTransparency = 1; f.AnchorPoint = Vector2.new(0.5, 0.5); f.Size = UDim2.fromOffset(20, 20)
    f.BackgroundColor3 = P.Dark
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = f
    local s = Instance.new("UIStroke"); s.Name = "Case"; s.Thickness = 2; s.Parent = f
    local hand = Instance.new("Frame")
    hand.Name = "Hand"; hand.BackgroundTransparency = 1; hand.AnchorPoint = Vector2.new(0.5, 0.5); hand.Position = UDim2.fromScale(0.5, 0.5)
    hand.Size = UDim2.fromScale(1, 1); hand.Parent = f
    local blade = Instance.new("Frame")
    blade.Name = "Blade"; blade.BorderSizePixel = 0; blade.AnchorPoint = Vector2.new(0.5, 1); blade.Position = UDim2.fromScale(0.5, 0.5)
    blade.Size = UDim2.fromOffset(2, 8); blade.Parent = hand
    local jewel = Instance.new("Frame")
    jewel.Name = "Jewel"; jewel.BorderSizePixel = 0; jewel.AnchorPoint = Vector2.new(0.5, 0.5); jewel.Position = UDim2.fromScale(0.5, 0.5)
    jewel.Size = UDim2.fromOffset(4, 4); jewel.ZIndex = 2; jewel.Parent = f
    local jc = Instance.new("UICorner"); jc.CornerRadius = UDim.new(1, 0); jc.Parent = jewel
    return f
end
local function TbAccentStep(e, f, age, pa, alpha)
    local tb = e.Label.TextBounds
    local now = os.clock()
    local kt = (e.Killed and e.KillAt) and (now - e.KillAt) or nil
    f.Visible = not e.Dot
    if e.Dot then return end
    f.Position = UDim2.new(0.5, -math.floor(tb.X / 2) - 14, 0.5, 0)
    f.BackgroundTransparency = math.clamp(0.25 + alpha, 0, 1)
    -- the hand: one fifth a tick; a crit sweeps a whole lap first; a kill snaps it to twelve
    local n = math.min(5, math.floor(TbTicks(e, age) / TB_TICK))
    local ang = n * 72
    if e.Crit and pa < 0.25 then ang += 360 * (1 - (1 - pa / 0.25) ^ 2) - 360 end
    if kt then ang = 0 end
    local hand = f:FindFirstChild("Hand")
    if hand then
        hand.Rotation = ang
        local blade = hand:FindFirstChild("Blade")
        if blade then blade.BackgroundColor3 = P.Lume; blade.BackgroundTransparency = alpha end
    end
    local case = f:FindFirstChild("Case")
    if case then
        local flash = (e.Crit and pa < 0.3) and (1 - pa / 0.3) or 0
        case.Color = P.Mid:Lerp(P.Lume, flash)
        case.Transparency = math.clamp(alpha, 0, 1)
    end
    -- the ruby jewel: glints on a weak-spot hit
    local jewel = f:FindFirstChild("Jewel")
    if jewel then
        local glint = (e.Weak and pa < 0.35) and math.sin(pa / 0.35 * math.pi) or 0
        local sz = math.floor(4 + 4 * glint)
        jewel.Size = UDim2.fromOffset(sz, sz)
        jewel.BackgroundColor3 = P.Ruby:Lerp(P.Hot, glint * 0.7)
        jewel.BackgroundTransparency = alpha
    end
    -- stopped time: the digits grey out
    if kt then e.Label.TextColor3 = e.Color:Lerp(P.Grey, math.clamp(kt / 0.3, 0, 0.85)) end
end
-- ===== UI THEME v4 (SKIN UI THEMES, roll-out 2026-10-29): the clean language in this colourway's colours (UITheme Clean)
-- + two touches of a watch movement. Hooks read only the palette they get (a colourway copy shares these functions):
--   TAB MARK  a MINUTE TRACK: fine ticks stand on the lume bar (every fourth a longer one); on the top bar a lume seconds
--             pip DEAD-BEATS along it, one tick a second
--   FIELD     a SUB-DIAL in the lower-right corner (a rose-gold minute track of 60 ticks, lume indices) with the BALANCE WHEEL
--             beating inside it -- its rim, three spokes and a ruby jewel swinging back and forth at 2.5 beats a second, the
--             gun's heartbeat
local TB_CLEAN = {
    Field = P.Dark:Lerp(P.Ink, 0.3), Surface = P.Dark:Lerp(P.Body, 0.45), Raised = P.Body:Lerp(P.Dark, 0.3), Hover = P.Body:Lerp(P.Mid, 0.18),
    Well = P.Ink, Line = P.Mid:Lerp(P.Body, 0.5), Tip = P.Dark:Lerp(P.Body, 0.25),
    Accent = P.Brass, Mark = P.Lume, Hair = P.Mid:Lerp(P.Brass, 0.35),
    Text = P.Text, Sub = P.Text:Lerp(P.Grey, 0.55), Muted = P.Grey:Lerp(P.Body, 0.15), Ink = P.Ink,
    Gold = P.Mid:Lerp(P.Brass, 0.3), Lume = P.Lume, Ruby = P.Ruby, Dial = P.Dark:Lerp(P.Body, 0.3),
}
-- (HudThemes.Variant keeps a colourway copy's Clean colour only where it DIFFERS from colourway 1's -- an equal one goes through
-- the hue map and can come out wrong: nudge every copy colour a hair so this palette wins)
if VAR ~= 1 then for k, v in pairs(TB_CLEAN) do if typeof(v) == "Color3" then TB_CLEAN[k] = v:Lerp(Color3.new(0, 0, 0), 0.003) end end end
local TB_MT = 9 -- (the minute track's ticks on a tab mark)
TB_CLEAN.TabMark = function(mark, Q)
    local made = {}
    for i = 0, TB_MT - 1 do
        local long = (i % 4 == 0)
        local t = Instance.new("Frame")
        t.Name = "TbTick"; t.BorderSizePixel = 0; t.BackgroundColor3 = Q.Hair; t.BackgroundTransparency = long and 0.1 or 0.35
        t.AnchorPoint = Vector2.new(0, 0); t.Size = UDim2.fromOffset(1, long and 5 or 3)
        t.Position = UDim2.new(i / (TB_MT - 1), (i == TB_MT - 1) and -1 or 0, 0, -(long and 5 or 3)); t.ZIndex = mark.ZIndex; t.Parent = mark
        table.insert(made, t)
    end
    local pip = Instance.new("Frame")
    pip.Name = "TbPip"; pip.BorderSizePixel = 0; pip.BackgroundColor3 = Q.Lume; pip.AnchorPoint = Vector2.new(0, 0)
    pip.Size = UDim2.fromOffset(3, 4); pip.Position = UDim2.new(0, 0, 0, -1); pip.ZIndex = mark.ZIndex + 1; pip.Parent = mark
    local ps = Instance.new("UIStroke"); ps.Color = Q.Ink; ps.Thickness = 1; ps.Parent = pip
    table.insert(made, pip)
    return made
end
TB_CLEAN.Sig = function(ctx)
    local Q, f = ctx.P, ctx.Frame
    local cam = workspace.CurrentCamera
    local vh = (cam and cam.ViewportSize.Y or 800)
    local R = ctx.Phone and math.clamp(math.floor(vh * 0.07), 40, 56) or math.clamp(math.floor(vh * 0.1), 52, 84)
    local S = R * 2 + 12
    -- (built the first time this field shows: the Sig runs for every menu field at once; built unparented and marked UITKeep
    -- before it goes in, so the palette walk never touches it)
    local wheel
    local function Build()
    local dial = Instance.new("Frame")
    dial.Name = "TbDial"; dial.BackgroundTransparency = 1; dial.AnchorPoint = Vector2.new(1, 1); dial.Position = UDim2.new(1, -22, 1, -18)
    dial.Size = UDim2.fromOffset(S, S); dial.ZIndex = 0
    local face = Instance.new("Frame")
    face.Name = "Face"; face.BorderSizePixel = 0; face.BackgroundColor3 = Q.Dial; face.BackgroundTransparency = 0.35; face.AnchorPoint = Vector2.new(0.5, 0.5)
    face.Position = UDim2.fromScale(0.5, 0.5); face.Size = UDim2.fromOffset(R * 2, R * 2); face.ZIndex = 0; face.Parent = dial
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1, 0); fc.Parent = face
    local fs = Instance.new("UIStroke"); fs.Color = Q.Gold; fs.Thickness = 1.5; fs.Transparency = 0.25; fs.Parent = face
    -- the minute track: 60 ticks just inside the case, the five-minute ones longer, lume dots at the hours
    local cx, cy = S / 2, S / 2
    for i = 0, 59 do
        local a = math.rad(i * 6)
        local five = (i % 5 == 0)
        local len = five and 7 or 4
        local r0 = R - 4 - len / 2
        local t = Instance.new("Frame")
        t.BorderSizePixel = 0; t.BackgroundColor3 = Q.Gold; t.BackgroundTransparency = five and 0.05 or 0.3; t.AnchorPoint = Vector2.new(0.5, 0.5)
        t.Position = UDim2.fromOffset(cx + math.sin(a) * r0, cy - math.cos(a) * r0); t.Size = UDim2.fromOffset(1, len); t.Rotation = i * 6
        t.ZIndex = 1; t.Parent = dial
        if five then
            local dr = R - 16
            local d = Instance.new("Frame")
            d.BorderSizePixel = 0; d.BackgroundColor3 = Q.Lume; d.BackgroundTransparency = 0.2; d.AnchorPoint = Vector2.new(0.5, 0.5)
            d.Position = UDim2.fromOffset(cx + math.sin(a) * dr, cy - math.cos(a) * dr); d.Size = UDim2.fromOffset(3, 3); d.ZIndex = 1; d.Parent = dial
            local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = d
        end
    end
    -- the balance wheel: a rim, three spokes, the ruby jewel at the staff; the WHOLE wheel turns (one property a frame)
    local wr = math.floor(R * 0.5)
    wheel = Instance.new("Frame")
    wheel.Name = "TbBalance"; wheel.BackgroundTransparency = 1; wheel.AnchorPoint = Vector2.new(0.5, 0.5); wheel.Position = UDim2.fromScale(0.5, 0.5)
    wheel.Size = UDim2.fromOffset(wr * 2, wr * 2); wheel.ZIndex = 1; wheel.Parent = dial
    local rim = Instance.new("Frame")
    rim.BackgroundTransparency = 1; rim.Size = UDim2.fromScale(1, 1); rim.ZIndex = 1; rim.Parent = wheel
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(1, 0); rc.Parent = rim
    local rs = Instance.new("UIStroke"); rs.Color = Q.Gold; rs.Thickness = 3; rs.Transparency = 0.1; rs.Parent = rim
    for i = 0, 2 do -- (three arms out of the staff)
        local arm = Instance.new("Frame")
        arm.BackgroundTransparency = 1; arm.AnchorPoint = Vector2.new(0.5, 0.5); arm.Position = UDim2.fromScale(0.5, 0.5)
        arm.Size = UDim2.fromOffset(wr * 2, 2); arm.Rotation = i * 120 - 90; arm.ZIndex = 1; arm.Parent = wheel
        local sp = Instance.new("Frame")
        sp.BorderSizePixel = 0; sp.BackgroundColor3 = Q.Gold; sp.BackgroundTransparency = 0.1; sp.AnchorPoint = Vector2.new(0, 0.5)
        sp.Position = UDim2.fromScale(0.5, 0.5); sp.Size = UDim2.fromOffset(wr - 1, 2); sp.ZIndex = 1; sp.Parent = arm
    end
    for i = 0, 3 do -- (timing screws on the rim)
        local a = math.rad(i * 90 + 45)
        local sc = Instance.new("Frame")
        sc.BorderSizePixel = 0; sc.BackgroundColor3 = Q.Accent; sc.AnchorPoint = Vector2.new(0.5, 0.5); sc.Size = UDim2.fromOffset(4, 4)
        sc.Position = UDim2.fromOffset(wr + math.cos(a) * wr, wr + math.sin(a) * wr); sc.ZIndex = 2; sc.Parent = wheel
        local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(1, 0); cc.Parent = sc
    end
    local jewel = Instance.new("Frame")
    jewel.BorderSizePixel = 0; jewel.BackgroundColor3 = Q.Ruby; jewel.AnchorPoint = Vector2.new(0.5, 0.5); jewel.Position = UDim2.fromScale(0.5, 0.5)
    jewel.Size = UDim2.fromOffset(7, 7); jewel.ZIndex = 3; jewel.Parent = dial
    local jc = Instance.new("UICorner"); jc.CornerRadius = UDim.new(1, 0); jc.Parent = jewel
    local js = Instance.new("UIStroke"); js.Color = Q.Gold; js.Thickness = 1; js.Parent = jewel
    dial:SetAttribute("UITKeep", true)
    for _, d in ipairs(dial:GetDescendants()) do d:SetAttribute("UITKeep", true) end
    dial.Parent = f
    end
    local lastSec = -1
    return function(now, _dt)
        if not wheel then Build() end
        wheel.Rotation = math.sin(now * math.pi * 2 * 1.25) * 110 -- (2.5 beats a second: one swing each way)
        -- the seconds pip on the selected tab's minute track: one jump a second (a dead-beat seconds hand)
        local sec = math.floor(now)
        if sec ~= lastSec then
            lastSec = sec
            local k = (sec % TB_MT) / (TB_MT - 1)
            for _, m in ipairs(ctx.Marks()) do
                local p = m.Visible and m:FindFirstChild("TbPip")
                if p then p.Position = UDim2.new(k, (k >= 1) and -3 or 0, 0, -1) end
            end
        end
    end, nil
end
Set.Theme = { Name = "Tourbillon", Desc = "A watchmaker's bench in every window: rose-gold bezel brackets on the corners whose knurled edges turn slowly, a small sub-dial whose lume hand ticks the seconds, and a minute track under every title.",
    Panel = { Top = C(14, 20, 52), Bottom = C(5, 7, 20) }, Card = { Top = C(22, 30, 70), Bottom = C(10, 14, 34) }, Title = { Top = C(60, 80, 160), Bottom = C(20, 28, 70) },
    Accent = C(210, 140, 110), Accent2 = P1.Lume, HpFill = P1.Lume, HpBg = C(8, 14, 20), XpFill = C(210, 140, 110), Text = C(230, 225, 240),
    BezelLit = C(232, 166, 132), BezelShade = C(120, 66, 52), DialFace = C(10, 14, 36), Lume = P1.Lume,
    Tex = "tex_tb_guilloche", TexT = 0.9, TexTile = 220, TexScroll = Vector2.new(2, -1),
    Emblem = "EmblemTourbillon", BorderThick = 2,
    Deco = TbDeco, OpenFn = TbOpen, TitleDeco = TbTitle,
    Clean = TB_CLEAN, -- (SKIN UI THEMES roll-out: the clean palette + minute-track tab marks with a dead-beat pip + the balance-wheel sub-dial; the old art is not drawn)
    -- (SKIN UI 2026-10-29: TICK-TOCK -- a sub-dial beside the digits, a lap on crits, the ruby glints on weak spots, stopped
    -- time on a kill; the minute track under the number is gone; this colourway's P)
    Numbers = { Font = "Jura", Glyph = "", NoBang = true, Motion = TbMotion, Accent = TbAccent, AccentStep = TbAccentStep,
        Normal = P.Text, Crit = P.Lume, Weak = P.Brass, Stroke = P.Ink, Size = 1.05 } }

-- ===== kill effect / bundle / store hero =====
Set.KillEffect = { Id = "StoppedTime", Name = "Stopped Time", Image = ART.EmblemTourbillon,
    How = "Own any Tourbillon skin (or the Tourbillon bundle)",
    Desc = "Wound down: a watch dial opens on the floor, the enemy is wound into it -- spiralling backwards, drawing in and down, warming to brass -- while the hands spin back, then tick, tick, stop on twelve with a click of lume. With the Tourbillon chronograph banner." }
Set.Bundle = { Id = "TourbillonBundle", Name = "Tourbillon Bundle", Price = 1799, BP = 699, ProductId = 0,
    Desc = "The whole Tourbillon set: the Tourbillon AWM and Rhino, the Escapement Balisong, Horologist Gloves and Bench Sleeves, the Tourbillon health bar and the Stopped Time kill effect.",
    Contents = { "WeaponSkin:TourbillonAWP", "WeaponSkin:TourbillonRHINO", "MeleeSkin:Tourbillon", "Glove:HorologistGloves", "Sleeve:BenchSleeves", "HealthBar:Tourbillon", "KillEffect:StoppedTime" } }
Set.Hero = { Grad = { C(34, 44, 104), C(6, 8, 22) }, Stroke = C(210, 140, 110), Emblem = ART.EmblemTourbillon, Name = C(240, 220, 214), Chip = C(120, 70, 58) }

return Set
