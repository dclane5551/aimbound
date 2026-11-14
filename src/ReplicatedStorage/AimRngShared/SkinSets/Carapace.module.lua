--!nocheck
-- ===================================================================================================================
-- CARAPACE (Skins V3, bundle 6 of docs/SKINS_V3_PLAN.md; SKINS BUILDER 5): Vector + AUG + Spark Pistol | Mandibles |
-- 1,199 BP. Jewel-beetle armour: every gun's body becomes a pair of smooth domed WING CASES -- jewel lacquer with fine
-- lengthwise grooves, turning violet where the shell curves away, a bronze rim -- over a segmented LANTERN that glows lime
-- between black chitin rings. The guns are RESCULPTED models (WeaponAssets.SkinModels.Carapace_<GUN>, built by
-- tools/skins_v3/carapace_build.py in art/weapons/SkinsV3_Carapace.blend, painted by tools/skin_v3_paint.py with
-- tools/skins_v3/carapace.json); this module brings their motion, effects, sounds and the rest of the bundle.
--   LANTERN     blinks a two-flash signal every 3 s (the stock bead answers half a beat later), a little brighter with
--               every kill of the streak; each shot flicks it up
--   WING CASES  hinged at their top edge: the draw snaps them shut; the inspect splits them wide open on the Present beat
--               (the lantern flares underneath), the thin membrane wings unfurl from under them and buzz, fold again on
--               the Tilt beat, the cases close on Settle; a reload lifts them a crack while the magazine is out; the Spark
--               Pistol's small cases flick open with every shot
-- Muzzle: a gold-green flash + a few glowing motes that drift off. Tracer: a lime comet head with a blinking tail.
-- Impact: a ring of motes rising off the hit + dark shell chips. Kill "Swarm Light": a swarm of glowing motes spirals up
-- out of the body in a column and scatters while a soft light swells inside it. Banner: a closed shell that opens a
-- little wider with every kill of the streak, the lantern inside brighter.
-- Original design (plan "Originality"): no insect head / legs / eyes on any gun, no egg pods, no faceted plates.
-- ===================================================================================================================
local Set = { Kind = "Carapace" }

local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local V = Vector3.new
local PALETTES = {
    { Name = "Jewel", Body = C(12, 48, 38), Irid = C(46, 20, 80), Mid = C(82, 52, 24), Dark = C(14, 18, 16), Glow = C(180, 255, 70),
      Membrane = C(170, 235, 150), Amber = C(225, 150, 40), Text = C(220, 255, 220), Ink = C(5, 10, 8) },
    { Name = "Scarab Gold", Body = C(82, 54, 10), Irid = C(40, 60, 12), Mid = C(30, 25, 20), Dark = C(14, 12, 10), Glow = C(255, 190, 60),
      Membrane = C(235, 205, 130), Amber = C(235, 140, 30), Text = C(255, 238, 200), Ink = C(10, 7, 3) },
    { Name = "Ruby Shell", Body = C(70, 10, 30), Irid = C(34, 16, 74), Mid = C(82, 52, 24), Dark = C(17, 12, 14), Glow = C(255, 110, 170),
      Membrane = C(245, 165, 200), Amber = C(205, 60, 95), Text = C(255, 222, 236), Ink = C(10, 4, 7) },
    { Name = "Blue Morpho", Body = C(12, 28, 86), Irid = C(10, 70, 84), Mid = C(38, 44, 60), Dark = C(10, 12, 19), Glow = C(80, 240, 255),
      Membrane = C(150, 215, 255), Amber = C(60, 140, 220), Text = C(214, 244, 255), Ink = C(3, 5, 12) },
}
local P = PALETTES[VAR] or PALETTES[1]
local BODY, IRID, MID, DARK, GLOW = P.Body, P.Irid, P.Mid, P.Dark, P.Glow
local WHITEG = GLOW:Lerp(Color3.new(1, 1, 1), 0.6)
Set.Palettes = PALETTES
Set.Colors = { Glow = GLOW, Body = BODY, Mid = MID }
-- image ids of tools/make_carapace_art.py (decals uploaded, resolved to images in Studio)
local A = "rbxassetid://"
Set.Art = {
    EmblemCarapace = A .. "123159023344963", EmblemCarapaceMask = A .. "100852129702050", CarapaceElytronL = A .. "81450407395727",
    CarapaceElytronR = A .. "103255339291293", CarapaceLantern = A .. "123114411529644", CarapaceCorner = A .. "132010701371340",
    SpFirefly = A .. "79751595955846", CarapaceScales = A .. "136493468760542", tex_carapace = A .. "102012027570673",
    -- (touch-up, skins10 2026-10-12: the arm blocks were one flat colour -- tools/skins_v3/carapace_arms_tex.py)
    tex_cp_glove = A .. "119860603819079", tex_cp_sleeve = A .. "107337120484622",
}
local ART = Set.Art

local function GunDesc(gun: string): string
    return "Jewel-beetle armour. The gun is resculpted into a pair of smooth, domed wing cases -- jewel lacquer with fine grooves that turns violet where the shell curves away, rimmed in bronze -- over a segmented lantern that glows between black chitin rings and blinks a quiet two-flash signal. Drawn, the cases snap shut; inspected, they split wide open, the lantern flares and thin membrane wings unfurl and buzz before everything folds away. Glowing motes drift off the muzzle, tracers fly like a comet with a blinking tail, hits send up a ring of light and every kill releases a SWARM of light."
end

-- ===== the guns (V3 models) =====
Set.GunSkins = {
    { Id = "CarapaceVECTOR", Name = "Carapace Vector", Gun = "VECTOR", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("VECTOR"),
      Model = "Carapace_VECTOR", V3 = true, Color = GLOW, Deco = "CarapaceGun", Fit = { Motes = V(0.56, 0.14, -0.085) } },
    { Id = "CarapaceAUG", Name = "Carapace AUG", Gun = "AUG", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("AUG"),
      Model = "Carapace_AUG", V3 = true, Color = GLOW, Deco = "CarapaceGun", Fit = { Motes = V(-0.02, 0.12, -0.085) } },
    { Id = "CarapaceSparkPistol", Name = "Carapace Spark Pistol", Gun = "SparkPistol", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("SparkPistol"),
      Model = "Carapace_SparkPistol", V3 = true, Color = GLOW, BeamColor = GLOW, Deco = "CarapaceGun", Flick = true, Fit = { Motes = V(0.03, 0.235, 0) } },
}

-- ===== the sculpt's clear parts take the colourway's tints (membrane wings, the AUG's amber magazine shell); a mote
-- emitter at the lantern (equip / inspect bursts, first person) =====
Set.Build = {}
Set.Build.CarapaceGun = function(model: Model, frame: BasePart, f: any, forView: boolean, H: any)
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            if p:GetAttribute("Tint") then p.Color = P.Membrane:Lerp(BODY, 0.35) end
            -- (seen in play: a resting lantern at GlowCold 0.42 read as a solid bright bar; it rests dimmer and the signal
            -- carries the light)
            if p.Name == "Glow_Lantern" or p.Name == "Glow" or p.Name == "Glow_MagCore" then p:SetAttribute("GlowCold", 0.66) end
            if p:GetAttribute("Amber") then p.Color = P.Amber end
        end
    end
    if forView and frame and f.Motes then
        local a = H.Att(frame, frame.CFrame * f.Motes)
        a.Name = "CPMotesAt"
        H.Emitter(a, { Name = "CPMotes", Texture = ART.SpFirefly, Color = { WHITEG, GLOW }, Size = { 0.05, 0.02 }, Life = { 0.6, 1.1 }, Speed = { 0.3, 0.9 },
            Spread = 70, Accel = V(0, 0.8, 0), Drag = 2.5, Light = 1, SkinFx = true,
            Trans = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.18, 0.7), NumberSequenceKeypoint.new(0.32, 0.05),
                NumberSequenceKeypoint.new(0.55, 0.75), NumberSequenceKeypoint.new(0.72, 0.15), NumberSequenceKeypoint.new(1, 1) }) })
    end
end

-- ===== motion: the lantern signal, the wing cases, the membrane wings =====
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function pulse(t, w) return math.exp(-(t / w) ^ 2) end
-- the two-flash signal: two quick blinks every 3 s (offset by `ph` seconds)
local function Signal(now: number, ph: number): number
    local t = (now + ph) % 3
    return math.max(pulse(t - 0.08, 0.06), pulse(t - 0.36, 0.06))
end
local function Keys(rig: any, st: any, v: any, now: number, flick: boolean)
    local ss = st.SinceShot or 99
    local se = st.SinceEquip or 99
    local streak = math.min(st.Streak or 0, 5)
    local base = 0.16 + 0.07 * streak
    -- the inspect (events from the class beats: Present opens, Tilt / Flip folds the wings, Settle closes)
    local inInspect = rig and rig.AnimName == "Inspect"
    if not inInspect then v.OpenT, v.FoldT, v.CloseT = nil, nil, nil end
    local open, wing, show = 0, 0, 0
    if v.OpenT then
        local t = now - v.OpenT
        open = smooth(t / 0.22)
        if v.CloseT then open *= 1 - smooth((now - v.CloseT) / 0.26) end
        local unf = smooth((t - 0.14) / 0.24)
        local fold = v.FoldT and smooth((now - v.FoldT) / 0.24) or 0
        wing = unf * (1 - fold)
        show = 0.3 * math.min(1, unf * 3) * (1 - fold)
        -- the buzz: a fast small flutter for ~0.6 s once they are out
        if t > 0.38 and t < 1.0 and not v.FoldT then wing += 0.09 * math.sin(now * 74) end
    end
    -- the draw: the cases start open and snap shut (0.35 s), a short overshoot
    if se < 0.5 then open = math.max(open, 1 - smooth(se / 0.3)) - 0.06 * math.sin(math.clamp((se - 0.3) / 0.2, 0, 1) * math.pi) end
    -- the reload: a crack open while the magazine is out
    local rl = st.Reload or 0
    if rl > 0 then open = math.max(open, 0.28 * smooth(rl / 0.12) * (1 - smooth((rl - 0.72) / 0.12))) end
    -- the Spark Pistol: its small cases flick open with every shot
    if flick and ss < 0.4 then open = math.max(open, 0.5 * math.exp(-ss / 0.07)) end
    st.Elytra = open
    st.Wing = wing
    st.WingShow = show
    -- the lantern: the signal over its resting glow, a flick per shot, a flare while the cases are open + on the draw
    local sig = Signal(now, 0)
    local lam = math.max(base, base + (1 - base) * sig, 0.85 * math.exp(-ss / 0.09), open * 1.0)
    if se < 0.6 then lam = math.max(lam, pulse(se - 0.32, 0.1)) end
    st.Lantern = lam
    st.Bead = math.max(base * 0.8, Signal(now, -1.5), 0.6 * math.exp(-ss / 0.12))
    st.Muzzle = 0.22 + 0.78 * math.exp(-ss / 0.06)
    -- a burst of motes off the lantern as it is drawn
    if se < 0.12 and (v.LastSE or 99) > se + 0.01 and rig and rig.Gun then
        for _, d in ipairs(rig.Gun:GetDescendants()) do if d.Name == "CPMotes" and d:IsA("ParticleEmitter") then d:Emit(6) end end
    end
    v.LastSE = se
end
local function MeleeKeys(st: any, v: any, now: number)
    local sw = v.SwingT and (now - v.SwingT) or 99
    local cross = v.CrossT and (now - v.CrossT) or 99
    st.Bead = math.max(0.2, Signal(now, 0), 0.8 * math.exp(-sw / 0.18), (cross < 1.2) and (1 - smooth((cross - 0.5) / 0.7)) or 0)
end
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    local v = rig.SkinVars
    if rig.Def and rig.Def.IsMelee then MeleeKeys(st, v, now) return end
    Keys(rig, st, v, now, rig.Skin and rig.Skin.Flick)
end
Set.OnAnim = function(rig: any, name: string)
    if rig.Def and rig.Def.IsMelee and (name:find("Light") or name:find("Heavy") or name:find("Quick")) then rig.SkinVars.SwingT = os.clock() end
end
Set.OnEvent = function(rig: any, name: string, H: any, data: any)
    local v = rig.SkinVars
    if not v then return end
    local now = os.clock()
    if rig.Def and rig.Def.IsMelee then
        if name == "CPCross" or name == "Flip" then v.CrossT = now end
        return
    end
    if name == "Present" then
        v.OpenT, v.FoldT, v.CloseT = now, nil, nil
        if rig.Gun then for _, d in ipairs(rig.Gun:GetDescendants()) do if d.Name == "CPMotes" and d:IsA("ParticleEmitter") then d:Emit(10) end end end
    elseif name == "Tilt" or name == "Flip" then
        if v.OpenT then v.FoldT = now end
    elseif name == "Settle" then
        if v.OpenT then v.CloseT = now end
    end
end
-- other players' guns: the lantern signal, now and then the cases open for a moment
Set.World = function(rec: any, now: number, st: any)
    local v = rec.Vars
    v.NextOpen = v.NextOpen or (now + 4 + math.random() * 6)
    local open = 0
    if now >= v.NextOpen then
        local t = now - v.NextOpen
        if t > 1.6 then v.NextOpen = now + 9 + math.random() * 7 else open = smooth(t / 0.25) * (1 - smooth((t - 1.2) / 0.3)) * 0.7 end
    end
    st.Elytra, st.Wing, st.WingShow = open, 0, 0
    st.Lantern = math.max(0.2, Signal(now, 0), open)
    st.Bead = math.max(0.2, Signal(now, -1.5))
    st.Muzzle = 0.22
end

-- ===== muzzle: a small gold-green flash + a few glowing motes drifting off =====
Set.Muzzle = function(rig: any, flash: ParticleEmitter, light: PointLight, muzzle: Attachment, H: any)
    flash.Color = ColorSequence.new(C(255, 240, 170), GLOW)
    flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.02) })
    light.Color = GLOW
    light.Brightness = 0.8
    rig.Fx.CPFly = H.Emitter(muzzle, { Name = "CPFly", Texture = ART.SpFirefly, Color = { WHITEG, GLOW }, Size = { 0.045, 0.02 }, Life = { 0.5, 0.9 },
        Speed = { 0.8, 1.8 }, Spread = 55, Dir = Enum.NormalId.Right, Accel = V(0, 0.6, 0), Drag = 2.2, Light = 1,
        Trans = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.2, 0.75), NumberSequenceKeypoint.new(0.35, 0.05),
            NumberSequenceKeypoint.new(0.6, 0.8), NumberSequenceKeypoint.new(0.75, 0.2), NumberSequenceKeypoint.new(1, 1) }) })
end
Set.OnFire = function(rig: any, H: any)
    if rig.Fx and rig.Fx.CPFly and H.Budget("CarapaceFly", 18, 0.8) then rig.Fx.CPFly:Emit(2) end
end

-- ===== COMET tracer: a soft lime head racing out, its tail blinking in dashes as it fades =====
Set.Tracer = function(H: any, from: Vector3, to: Vector3, peer: boolean?)
    local dist = (to - from).Magnitude
    if dist < 1.5 then return end
    local host = H.FxPart({ Size = V(0.05, 0.05, 0.05), Transparency = 1, CFrame = CFrame.new(from) })
    local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
    a0.Parent, a1.Parent = host, host
    local bm = Instance.new("Beam")
    bm.Attachment0, bm.Attachment1 = a0, a1
    bm.FaceCamera = true
    bm.LightEmission, bm.LightInfluence = 1, 0
    bm.Segments = 32   -- (the dashes are a many-key Transparency sequence: a 1-segment Beam only samples its two ends)
    bm.Width0, bm.Width1 = 0.012, peer and 0.05 or 0.065
    bm.Color = ColorSequence.new(GLOW:Lerp(C(0, 0, 0), 0.35), GLOW)
    bm.Parent = host
    local head = H.FxPart({ Shape = Enum.PartType.Ball, Size = V(0.09, 0.09, 0.09), Color = WHITEG, Transparency = 0.1, CFrame = CFrame.new(from) }, host)
    local dir = (to - from).Unit
    local travel = H.TRAVEL -- (hitscan: the shot is there at once, nothing flies)
    local tailLen = math.min(dist, 12)
    local dur = travel + 0.16
    local function Dashes(phase: number, fade: number): NumberSequence
        local kp = { NumberSequenceKeypoint.new(0, 1) }
        for i = 1, 7 do
            local x = (i - 0.5 + phase) / 8
            if x > 0.02 and x < 0.97 then
                local on = (i % 2 == 0) and 0.15 or 0.7
                table.insert(kp, NumberSequenceKeypoint.new(x, math.clamp(on + fade * (1 - on), 0, 1)))
            end
        end
        table.insert(kp, NumberSequenceKeypoint.new(1, math.clamp(0.05 + fade, 0, 1)))
        table.sort(kp, function(a, b) return a.Time < b.Time end)
        return NumberSequence.new(kp)
    end
    H.Animate(dur, function(t)
        local hk = math.clamp(t / travel, 0, 1)
        local hp = from + dir * dist * hk
        local tl = from -- (hitscan look: the whole line, muzzle -> hit)
        a0.WorldPosition, a1.WorldPosition = tl, hp
        head.CFrame = CFrame.new(hp)
        local fade = math.clamp((t - travel) / 0.16, 0, 1)
        head.Transparency = 0.1 + 0.9 * fade
        bm.Transparency = Dashes((t * 9) % 1, fade)
    end, function() host:Destroy() end)
end

-- ===== impact: a ring of motes rising off the hit + a few dark shell chips =====
Set.Impact = function(H: any, pos: Vector3, normal: Vector3?, peer: boolean?)
    if not H.Budget("CarapaceImpact", peer and 3 or 7, 0.65) then return end
    local nrm = (normal and normal.Magnitude > 0.1) and normal.Unit or V(0, 1, 0)
    local right = nrm:Cross(math.abs(nrm.Y) < 0.9 and V(0, 1, 0) or V(1, 0, 0)).Unit
    local up = right:Cross(nrm).Unit
    local n = peer and 4 or 6
    local motes = {}
    for i = 1, n do
        local a = (i / n) * math.pi * 2
        motes[i] = { P = H.FxPart({ Shape = Enum.PartType.Ball, Size = V(0.06, 0.06, 0.06), Color = (i % 2 == 0) and WHITEG or GLOW, Transparency = 0.1,
            CFrame = CFrame.new(pos + nrm * 0.05) }), A = a }
    end
    if not peer then
        local host = H.FxPart({ Size = V(0.05, 0.05, 0.05), Transparency = 1, CFrame = CFrame.new(pos + nrm * 0.05) })
        local em = H.Emitter(host, { Name = "CPChips", Color = { BODY:Lerp(C(0, 0, 0), 0.2), MID }, Size = { 0.05, 0.02 }, Life = { 0.2, 0.4 },
            Speed = { 3, 6 }, Spread = 60, Accel = V(0, -20, 0), Light = 0, Influence = 1, Dir = Enum.NormalId.Top })
        em:Emit(4)
        H.Debris:AddItem(host, 0.6)
    end
    H.Animate(0.6, function(t)
        local k = t / 0.6
        local r = 0.12 + 0.3 * smooth(k)
        for i, m in ipairs(motes) do
            local a = m.A + k * 1.6
            m.P.CFrame = CFrame.new(pos + nrm * (0.05 + 0.5 * k) + (right * math.cos(a) + up * math.sin(a)) * r)
            local blink = (math.floor((t + i * 0.07) * 14) % 3 == 0) and 0.45 or 0
            m.P.Transparency = math.clamp(0.1 + blink + 0.9 * k ^ 1.5, 0, 1)
        end
    end, function() for _, m in ipairs(motes) do m.P:Destroy() end end)
end

-- ===== BURROW kill v3 (2026-10-14; owner on v2 ECLOSION: "not great" -- "Fission or Ferroflux are ... the ideal", see
-- FX_AUDIT "WHAT MAKES FISSION / FERROFLUX WORK"). ONE idea in that mould: the BODY CURLS UP like a dead beetle (every
-- part folds in to the axis and down to the floor), two big iridescent WING CASES rise out of the floor on either side and
-- CLAMP SHUT over it into a beetle's back -- a dome 4.4 long on the real floor, ink-outlined, its seam lighting lime -- and
-- the dome BURROWS: it rocks and sinks into a dark ring of turned earth while the lantern light escapes up the seam as
-- fireflies (1.4 s). Beats: curl 0.05-0.42 / clamp 0.28-0.56 / seam pulse 0.62 / burrow 0.8-1.3. Motion is in + DOWN.
-- Budget: full = 2 cases + seam + earth ring + <= 6 body parts + 1 Highlight + 1 emitter (<= 18); low = 2 cases + seam +
-- ring + 2 body parts, 8 fireflies. =====
local function BodyParts(pos: Vector3, H: any): { BasePart }
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
            if p:IsA("BasePart") and p.Transparency < 0.6 and p.Size.Magnitude < 12 and #out < 20 then table.insert(out, p) end
        end
        table.sort(out, function(a, b) return a.Size.Magnitude > b.Size.Magnitude end)
    end
    return out
end
Set.Kill = function(H: any, pos: Vector3, low: boolean)
    local ground = H.Ground(pos)
    local axis = V(pos.X, ground.Y, pos.Z)
    local cam = workspace.CurrentCamera
    local rt = cam and cam.CFrame.RightVector or V(1, 0, 0)
    rt = V(rt.X, 0, rt.Z)
    rt = (rt.Magnitude > 0.05) and rt.Unit or V(1, 0, 0)
    local base = CFrame.fromMatrix(axis, rt, V(0, 1, 0)) -- (X = your right: the dome lies long across your view; Z = toward you)
    local model = Instance.new("Model")
    model.Name = "CarapaceKill"
    model.Parent = H.FxFolder()
    local SM = Enum.Material.SmoothPlastic
    -- the earth ring the beetle burrows into (opaque, dark, on the floor)
    local earth = H.FxPart({ Shape = Enum.PartType.Cylinder, Material = SM, Color = P.Ink, Size = V(0.04, 0.2, 0.2), Transparency = 1,
        CFrame = CFrame.new(axis + V(0, 0.03, 0)) * CFrame.Angles(0, 0, math.pi / 2) }, model)
    -- the body, curling up
    local bits = {}
    for _, s in ipairs(BodyParts(pos, H)) do
        if #bits >= (low and 2 or 6) then break end
        local ok, c = pcall(function() return s:Clone() end)
        if ok and c then
            for _, ch in ipairs(c:GetChildren()) do
                if not (ch:IsA("SpecialMesh") or ch:IsA("DataModelMesh") or ch:IsA("SurfaceAppearance")) then ch:Destroy() end
            end
            c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
            c.Parent = model
            local out = c.Position - axis
            out = V(out.X, 0, out.Z)
            local fold = (out.Magnitude > 0.05) and out.Unit:Cross(V(0, 1, 0)) or rt
            table.insert(bits, { P = c, CF = c.CFrame, Size = c.Size, Fold = fold, D = math.random() * 0.06 })
        end
    end
    -- the two wing cases (ellipsoid slabs, ink-outlined) + the seam where they meet
    local LEN, HGT, THK = 4.4, 2.6, 1.3
    local cases = {}
    for _, s in ipairs({ -1, 1 }) do
        cases[s] = H.FxPart({ Shape = Enum.PartType.Ball, Material = SM, Color = BODY, Reflectance = 0.08, Size = V(LEN, HGT, THK), Transparency = 1,
            CFrame = base }, model)
    end
    local hl = Instance.new("Highlight")
    hl.Adornee = model; hl.FillTransparency = 1; hl.OutlineColor = P.Ink; hl.OutlineTransparency = 1
    hl.DepthMode = Enum.HighlightDepthMode.Occluded
    hl.Parent = model
    local seam = H.FxPart({ Color = GLOW, Size = V(LEN * 0.82, 0.24, 0.24), Transparency = 1, CFrame = base }, model)
    local flies = H.Emitter(H.Att(seam, axis + V(0, 1.4, 0)), { Texture = H.SPARK, Color = { WHITEG, GLOW }, Size = { 0.32, 0.1 }, Life = { 0.6, 1.0 },
        Speed = { 5, 9 }, Spread = 40, Dir = Enum.NormalId.Top, Accel = V(0, 2, 0), Drag = 1.5,
        Shape = Enum.ParticleEmitterShape.Box, Rot = { 0, 360 } })
    local fired = false
    local dur = low and 1.15 or 1.4
    H.Animate(dur, function(t)
        -- 1) CURL (0.05 -> 0.42): each part folds over toward the axis, shrinks and drops to the floor
        for _, b in ipairs(bits) do
            local k = smooth((t - 0.05 - b.D) / 0.37)
            local home = b.CF.Position
            local target = V(axis.X + (home.X - axis.X) * 0.35, ground.Y + 0.5 + (home.Y - ground.Y) * 0.12, axis.Z + (home.Z - axis.Z) * 0.35)
            local at = home:Lerp(target, k)
            b.P.CFrame = CFrame.fromAxisAngle(b.Fold, k * 1.3) * (b.CF - home) + at
            b.P.Size = b.Size * (1 - 0.35 * k)
            b.P.Transparency = (t > 0.56) and 1 or 0
        end
        -- 2) CLAMP (0.28 -> 0.56): the cases rise from lying flat outward to lean together over the body, overshoot, settle
        local cl = smooth((t - 0.28) / 0.28)
        local over = math.sin(math.clamp((t - 0.5) / 0.14, 0, 1) * math.pi) * 0.12
        -- 4) BURROW (0.8 -> 1.3): the dome rocks and sinks into the earth ring
        local bur = smooth((t - (dur - 0.6)) / 0.5)
        local rock = math.sin(t * 34) * 0.07 * math.clamp((t - (dur - 0.62)) / 0.1, 0, 1) * (1 - bur)
        local sink = bur * (HGT + 0.3)
        for s, c in pairs(cases) do
            local ang = s * ((1 - cl) * 1.45 - 0.42 - over)
            local zc = s * ((1 - cl) * 1.7 + 0.6)
            local cf = base * CFrame.Angles(0, 0, rock) * CFrame.new(0, 0.55 * cl + 0.1 - sink, zc) * CFrame.Angles(ang, 0, 0)
            c.CFrame = cf
            c.Color = BODY:Lerp(IRID, 0.5 + 0.5 * math.sin(t * 7 + s))
            c.Transparency = (t < 0.26) and 1 or 0
        end
        hl.OutlineTransparency = (t < 0.26) and 1 or 0
        -- 3) the SEAM lights where the cases meet and pulses once (0.62), the fireflies escape up it
        local lit = smooth((t - 0.5) / 0.08)
        local pk = math.exp(-((t - 0.62) / 0.06) ^ 2)
        seam.CFrame = base * CFrame.Angles(0, 0, rock) * CFrame.new(0, 0.1 + 0.55 + HGT * 0.42 - sink, 0)
        seam.Size = V(LEN * 0.82, 0.24 + 0.14 * pk, 0.24 + 0.14 * pk)
        seam.Color = GLOW:Lerp(WHITEG, pk)
        seam.Transparency = (lit <= 0) and 1 or math.max(0, bur * 1.3 - 0.3)
        if t >= 0.6 and not fired then fired = true; flies:Emit(low and 8 or 18) end
        -- the earth ring opens under the dome as it starts to burrow, then closes over it
        local open = smooth((t - 0.2) / 0.3) * (1 - smooth((t - (dur - 0.12)) / 0.12))
        local d = 5.6 * open + 0.1
        earth.Size = V(0.04, d, d)
        earth.Transparency = (open < 0.02) and 1 or 0
    end, function() model:Destroy() end)
end

local WORDS = { "GLOW", "FLICKER", "SWARM", "BEACON", "LUMINOUS" } -- (name check: "Radiant" is a reference-game term)
local banner
Set.Banner = function(H: any, streak: number)
    local gui, root = H.BannerRoot("Carapace", Vector2.new(180, 90), "Side")
    if not root then return end
    if not banner or banner.Root ~= root then
        local New = H.New
        local plate = New("Frame", { BackgroundColor3 = P.Ink:Lerp(BODY, 0.35), BackgroundTransparency = 0.12, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, root,
            { New("UIStroke", { Color = MID, Thickness = 1.5 }) })
        local lamp = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.CarapaceLantern, ImageColor3 = GLOW, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(42, 48), Size = UDim2.fromOffset(44, 74), Rotation = 90 }, plate)
        local el = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.CarapaceElytronL, ImageColor3 = BODY:Lerp(Color3.new(1, 1, 1), 0.25),
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(42, 46), Size = UDim2.fromOffset(34, 70) }, plate)
        local er = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.CarapaceElytronR, ImageColor3 = BODY:Lerp(Color3.new(1, 1, 1), 0.25),
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(42, 46), Size = UDim2.fromOffset(34, 70) }, plate)
        local word = New("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(86, 18), Size = UDim2.fromOffset(88, 24),
            Font = Enum.Font.Oswald, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = P.Text, Text = "" }, plate)
        local segs = {}
        for i = 1, 5 do
            segs[i] = New("Frame", { BorderSizePixel = 0, BackgroundColor3 = DARK:Lerp(BODY, 0.6), Position = UDim2.fromOffset(86 + (i - 1) * 17, 54), Size = UDim2.fromOffset(14, 12) },
                plate, { New("UICorner", { CornerRadius = UDim.new(0, 5) }) })
        end
        banner = { Root = root, Plate = plate, Lamp = lamp, L = el, R = er, Word = word, Segs = segs, Token = 0, T0 = 0, Spread = 0, From = 0 }
        H.RunService.RenderStepped:Connect(function()
            local b = banner
            if not (b and b.Root.Visible) then return end
            local k = smooth((os.clock() - b.T0) / 0.28)
            local s = b.From + (b.Spread - b.From) * k
            b.L.Rotation, b.R.Rotation = -s, s
            b.L.Position = UDim2.fromOffset(42 - s * 0.35, 46 - s * 0.12)
            b.R.Position = UDim2.fromOffset(42 + s * 0.35, 46 - s * 0.12)
        end)
    end
    local b = banner
    b.Token += 1
    local token = b.Token
    root.Visible = true
    b.T0 = os.clock()
    b.From = (streak <= 1) and 0 or b.Spread
    b.Spread = 6 + 5 * math.clamp(streak, 1, 5)
    b.Word.Text = WORDS[math.clamp(streak, 1, 5)]
    b.Word.TextTransparency = 0
    b.Lamp.ImageTransparency = 0.55 - 0.1 * math.clamp(streak, 1, 5)
    b.Plate.BackgroundTransparency = 0.12
    b.L.ImageTransparency, b.R.ImageTransparency = 0, 0
    for i, sg in ipairs(b.Segs) do
        sg.BackgroundColor3 = (i <= streak) and GLOW or DARK:Lerp(BODY, 0.6)
        sg.BackgroundTransparency = 0
    end
    task.delay(1.35, function()
        if b.Token ~= token then return end
        local ti = TweenInfo.new(0.3)
        H.TweenService:Create(b.Plate, ti, { BackgroundTransparency = 1 }):Play()
        H.TweenService:Create(b.Word, ti, { TextTransparency = 1 }):Play()
        for _, im in ipairs({ b.Lamp, b.L, b.R }) do H.TweenService:Create(im, ti, { ImageTransparency = 1 }):Play() end
        for _, sg in ipairs(b.Segs) do H.TweenService:Create(sg, ti, { BackgroundTransparency = 1 }):Play() end
        task.delay(0.32, function() if b.Token == token then root.Visible = false end end)
    end)
end

-- ===== sounds (tools/skins_v3/carapace_sfx.py: every moment from CC0 recordings; tools/audio_ids.json) =====
local SND = { Inspect = 134113545948835 }
Set.Sounds = {
    Fire = { Id = 0, Volume = 0 }, Equip = { Id = 139865418477763, Volume = 0.4 }, MagOut = { Id = 126059794942663, Volume = 0.3 },
    MagIn = { Id = 103973386627661, Volume = 0.34 }, Kill = { Id = 101706636948856, Volume = 0.5 }, Impact = { Id = 77992665431669, Volume = 0.18 },
    Swing = { Id = 133069023637617, Volume = 0.4 }, MeleeHit = { Id = 91255239414971, Volume = 0.42 },
    -- (each gun's own full shot; volumes matched to the base guns' level: carapace_sfx.py RMS check -- Vector +5.4 dB)
    FireGun = { VECTOR = { Id = 83690049618618, Volume = 0.38 }, AUG = { Id = 112993380715342, Volume = 0.83 }, SparkPistol = { Id = 73096348934064, Volume = 0.63 } },
}
-- the inspect: the cases opening + the wing buzz on the Present beat, a burst of motes
Set.InspectEvents = { { "Present", "Sound", { Id = SND.Inspect, Volume = 0.34 } } }

-- ===== the MANDIBLES (melee, Dual class: a blade in each hand): a stag-beetle mandible -- a curved jewel blade whose inner
-- edge carries two bronze teeth and ends in a forked tip, a bronze edge bevel, a small domed wing-case guard, a segmented
-- chitin grip and a lantern bead in a bronze claw pommel (WeaponAssets.MeleeModels.Carapace). The beads blink the
-- signal; as the blades cross on the inspect they flare together =====
Set.Melee = {
    Skin = { Name = "Mandibles", Price = 449, ProductId = 0,
        Desc = "A pair of curved blades shaped like a stag beetle's mandibles, one in each hand: jewel lacquer with a bronze edge, two inner teeth and a forked tip, a small domed guard, segmented chitin grips and a lantern bead in each claw pommel that blinks a quiet signal. Swings leave a lime trail; when you inspect them the blades cross and both lanterns flare. Every kill releases a SWARM of light." },
    Rig = { Class = "Dual", BladeLen = 0.7 },
    FlatBlade = true,
    InspectEvents = { { "Flip", "CPCross" }, { "Raise+0.1", "Sound", { Id = SND.Inspect, Volume = 0.3 } } },
    Build = function(m: Model, o: any, H: any)
        local parts = H.CloneModel(m, "MeleeModels", "Carapace", VAR, { [1] = GLOW })
        local blade = parts.Blade
        if not blade then return end
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Name, a1.Name = "TrailBase", "TrailTip"
        a0.Position = blade.CFrame:PointToObjectSpace(V(0.0, 0.32, 0))
        a1.Position = blade.CFrame:PointToObjectSpace(V(0.12, 0.9, 0))
        a0.Parent, a1.Parent = blade, blade
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Color = ColorSequence.new(WHITEG, GLOW)
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
        tr.LightEmission, tr.LightInfluence = 0.85, 0
        tr.Lifetime, tr.MinLength, tr.FaceCamera = 0.14, 0.02, true
        tr.Enabled = false
        tr:SetAttribute("SwingTrail", true)
        tr.Parent = blade
    end,
}

-- ===== arms: CHITIN GRIPS (glove) + EXOSKELETON SLEEVES (sculpted mesh pieces, WeaponAssets.ArmsModels.Carapace) =====
-- Glove: a dark green glove, segmented chitin ridges over the fingers, a small domed shell on the back of the hand; ONE
-- effect: a tiny lantern bead on the back of the wrist blinks the two-flash signal every few seconds (a kill makes it flare).
-- Sleeve: five overlapping chitin rings, each a little larger toward the elbow, jewel lacquer with violet edges; no glow.
Set.Glove = function(K: any)
    local C3, V3 = K.C, K.V
    return {
        Id = "ChitinGrips", Name = "Chitin Grips", Price = 449,
        Desc = "Dark green gloves with segmented chitin ridges over the fingers and a small domed wing-case shell on the back of the hand. A tiny lantern bead at the wrist blinks a quiet two-flash signal every few seconds, and flares on a kill.",
        Base = { Color = C3(18, 34, 26), Material = Enum.Material.SmoothPlastic, Reflectance = 0, Tex = "tex_cp_glove", TexTile = 1.2, TexT = 0, TexColor = C3(30, 52, 40) },
        Parts = {
            { Mesh = "Carapace/Knuckle", MeshV = VAR, Size = V3(1.04, 0.2, 0.32), Off = V3(0, 0.52, -0.26) },
            { Mesh = "Carapace/HandShell", MeshV = VAR, Size = V3(0.6, 0.16, 0.42), Off = V3(0, 0.56, 0.12) },
            { Shape = "Ball", Uniform = true, Size = V3(0.07, 0.07, 0.07), Off = V3(0, 0.58, 0.4), Color = GLOW, Glow = true,
              Anim = "Blink", Period = 3.2, Dur = 0.16, Gap = 0.3, Count = 2, PulseMin = 0, PulseMax = 0.8, BurstOn = "Kill" },
        },
    }
end
Set.Sleeve = function(K: any)
    local C3, V3 = K.C, K.V
    local parts = {}
    for i = 0, 4 do
        -- (the piece flares at its own +Z end: turned round, each ring's flared lip sits at its wrist end, over the ring
        -- before it -- the rings telescope out toward the elbow)
        local s = 1.324 * (1 + 0.012 * i)
        table.insert(parts, { Mesh = "Carapace/Ring", MeshV = VAR, Size = V3(s, s, 0.18), Off = V3(0, 0, -0.4 + i * 0.19), Rot = V3(0, 180, 0) })
    end
    return {
        Id = "ExoskeletonSleeves", Name = "Exoskeleton Sleeves", Price = 299,
        Desc = "Five overlapping chitin rings round the forearm, each a little larger toward the elbow -- jewel lacquer that turns violet at the edges, a bronze lip on each ring. Part of the Carapace set.",
        Base = { Color = C3(16, 28, 22), Material = Enum.Material.SmoothPlastic, Reflectance = 0, Tex = "tex_cp_sleeve", TexTile = 1.6, TexT = 0, TexColor = C3(28, 44, 36) },
        Parts = parts,
    }
end

-- ===== health bar: segmented chitin (abdomen rings) with a lantern-lime fill; a hit sends a mote of light up off the fill
-- (no flashing, no strobe at low health) =====
-- (BARS v2, FX roll-out: the house ink frame; a firefly-lime fill with a slow glow travelling along it like a lantern
-- breathing; lost health breaks off as CHITIN FLAKES that drop; elites / bosses add the wing-case end and the hit mote)
Set.Bar = { Id = "Carapace", Name = "Carapace", Price = 149,
    Desc = "The enemy's health as a firefly's lantern: a lime glow that breathes along the bar, and every hit breaks the lost piece off as falling chitin flakes. Part of the Carapace set.",
    Look = "Ink", FillColor = GLOW, ChipMotion = "Shatter", Chip = IRID:Lerp(C(255, 255, 255), 0.35), Back = C(6, 14, 10),
    Decor = { "LanternBreath", "WingCase", "HitMote" } }
Set.BarDecor = {
    LanternBreath = function(ctx: any, K: any)
        -- a soft brighter band that travels along the fill every ~2 s (the lantern breathing)
        local band = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = WHITEG, Size = UDim2.new(0.18, 0, 1, 0), ZIndex = 4 }, ctx.Inner)
        K.New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.45),
            NumberSequenceKeypoint.new(1, 1) }) }, band)
        return function(now, dt, alpha, info)
            band.Position = UDim2.fromScale(((now * 0.5) % 1.4) - 0.2, 0)
            band.BackgroundTransparency = 1 - alpha
        end
    end,
    WingCase = function(ctx: any, K: any)
        -- elites / bosses: two small wing-case tips at the bar's right end, iridescent, ink-edged
        if ctx.Tier == "Small" then return function() end end
        local f = K.Fader()
        local tips = {}
        for i, s in ipairs({ -1, 1 }) do
            local t = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = BODY:Lerp(IRID, 0.5), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 10 }, ctx.Holder)
            K.New("UICorner", { CornerRadius = UDim.new(1, 0) }, t)
            K.New("UIStroke", { Color = C(6, 8, 8), Thickness = 1.5 }, t)
            f.Add(t, 0, "BackgroundTransparency")
            tips[i] = { F = t, S = s }
        end
        return function(now, dt, alpha, info)
            for _, tp in ipairs(tips) do
                tp.F.Size = UDim2.fromOffset(ctx.H * 1.6, ctx.H * 0.7)
                tp.F.Position = UDim2.fromOffset(ctx.W + 2, ctx.H / 2 + tp.S * ctx.H * 0.32)
                tp.F.Rotation = tp.S * (14 + 6 * math.sin(now * 2))
                tp.F.BackgroundColor3 = BODY:Lerp(IRID, 0.5 + 0.4 * math.sin(now * 1.3 + tp.S))
            end
            f.Apply(alpha)
        end
    end,
    LanternFill = function(ctx: any, K: any)
        local f = K.Fader()
        local fill = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 4 }, ctx.Inner)
        K.New("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, GLOW:Lerp(C(0, 0, 0), 0.45)), ColorSequenceKeypoint.new(0.7, GLOW),
            ColorSequenceKeypoint.new(1, WHITEG) }), Rotation = 0 }, fill)
        f.Add(fill, 0.35, "BackgroundTransparency")
        return function(now, dt, alpha, info)
            f.Apply(alpha)
        end
    end,
    HitMote = function(ctx: any, K: any)
        if ctx.Tier == "Small" then return function() end end
        local pool = {}
        for i = 1, 3 do
            pool[i] = { Img = K.Img("glow", { AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = WHITEG, ImageTransparency = 1, ZIndex = 9 }, ctx.Holder), T = 99 }
        end
        local idx, last = 0, 0
        return function(now, dt, alpha, info)
            if (info.Hit or 0) > 0.6 and now - last > 0.12 then
                last = now
                idx = idx % #pool + 1
                pool[idx].T = 0
                pool[idx].X = ctx.W * (info.Shown or 1)
            end
            for _, m in ipairs(pool) do
                m.T += dt
                local k = m.T / 0.7
                if k < 1 then
                    m.Img.Position = UDim2.fromOffset((m.X or 0) + 6 * math.sin(k * 8), ctx.H / 2 - k * ctx.H * 1.6)
                    m.Img.Size = UDim2.fromOffset(ctx.U * 1.1, ctx.U * 1.1)
                    m.Img.ImageTransparency = 1 - alpha * (1 - k) * 0.9
                else
                    m.Img.ImageTransparency = 1
                end
            end
        end
    end,
}

-- ===== UI theme: jewel shell glass (UI design system v3: dark green slabs, lime as the accent, violet as the second) =====
-- ===== UI theme v2 (FX roll-out 2026-10-14; v1 = the shared template). Its own pieces, icon look (flat facet + ink edge):
-- WING-CASE TIPS -- a pair of iridescent elytra tips folded over the top corners, their colour sliding body -> violet as
-- you look at the window; a LANTERN SEAM -- a line of lime lantern segments along the bottom edge that breathes; three
-- FIREFLIES that wander the lower half and blink their two-flash signal; windows open by the ELYTRA SPLIT -- two shell
-- halves cover the window and swing apart; every title gets a lantern-segment bead. Colours from the theme table
-- (CaseA / CaseB / Lantern / Ink) so colourways recolour them.
local function CpFacet(ctx, o, lit, shade, inkTh)
    local g = Instance.new("UIGradient")
    g.Color = ctx.UIStyle.Facet(lit, shade)
    g.Rotation = ctx.UIStyle.FACET_ROT or 35
    g.Parent = o
    local ink = ctx.UIStyle.InkEdge(inkTh or 2)
    ink.Parent = o
    return g
end
local function CpOverlay(host)
    local f = Instance.new("Frame")
    f.Name = "CpOverlay"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 20; f.Active = false
    f:SetAttribute("NoSkin", true); f:SetAttribute("Skinned", true)
    f.Parent = host
    return f
end
local function CpDeco(ctx)
    if ctx.Kind ~= "Window" then return nil end
    local t = ctx.Theme
    local host = ctx.Root or ctx.Surface
    local f = CpOverlay(host)
    local abs = host.AbsoluteSize
    local small = math.min(abs.X, abs.Y) < 260
    -- the wing-case tips: long rounded slabs crossing each top corner
    local tips = {}
    for i, c in ipairs({ { 0, -1 }, { 1, 1 } }) do
        -- (seen in play: big slabs crossing the corner covered the title + close button -- the tips now poke OUT of the
        -- window's top corners, angled up and away)
        local L = small and 28 or 58
        local tip = Instance.new("Frame")
        tip.Name = "CpTip"; tip.BorderSizePixel = 0; tip.BackgroundColor3 = Color3.new(1, 1, 1); tip.AnchorPoint = Vector2.new(0.5, 0.5)
        tip.Size = UDim2.fromOffset(L, small and 8 or 14); tip.Rotation = -c[2] * 32
        tip.Position = UDim2.new(c[1], (c[1] == 0) and -L * 0.32 or L * 0.32, 0, -L * 0.12); tip.ZIndex = f.ZIndex + 1
        local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(1, 0); cr.Parent = tip
        local g = CpFacet(ctx, tip, t.CaseA, t.CaseB)
        tip.Parent = f
        tips[i] = { F = tip, G = g, Ph = i * 1.7 }
    end
    -- the lantern seam: segments along the bottom edge
    local segs = {}
    local N = small and 5 or 9
    for i = 1, N do
        local sg = Instance.new("Frame")
        sg.Name = "CpLantern"; sg.BorderSizePixel = 0; sg.BackgroundColor3 = t.Lantern; sg.AnchorPoint = Vector2.new(0.5, 1)
        sg.Size = UDim2.new(0.5 / N, 0, 0, small and 3 or 4); sg.Position = UDim2.new(0.25 + (i - 0.5) * 0.5 / N, 0, 1, -3); sg.ZIndex = f.ZIndex + 1
        local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(1, 0); cr.Parent = sg
        sg.Parent = f
        segs[i] = sg
    end
    -- fireflies: three lime dots with an ink rim wandering the lower half, two-flash blink
    local flies = {}
    for i = 1, (small and 2 or 3) do
        local d = Instance.new("Frame")
        d.Name = "CpFly"; d.BorderSizePixel = 0; d.BackgroundColor3 = t.Lantern; d.AnchorPoint = Vector2.new(0.5, 0.5)
        d.Size = UDim2.fromOffset(small and 4 or 6, small and 4 or 6); d.ZIndex = f.ZIndex + 2
        local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(1, 0); cr.Parent = d
        local st = Instance.new("UIStroke"); st.Color = t.Ink; st.Thickness = 1; st.Parent = d
        d.Parent = f
        flies[i] = { F = d, S = st, Ph = math.random() * 6.28, Sp = 0.05 + math.random() * 0.04 }
    end
    return function(now, dt)
        for _, tp in ipairs(tips) do
            local k = 0.5 + 0.5 * math.sin(now * 0.8 + tp.Ph)
            tp.G.Color = ctx.UIStyle.Facet(t.CaseA:Lerp(t.CaseB, k * 0.6), t.CaseB:Lerp(t.Ink, 0.3))
        end
        for i, sg in ipairs(segs) do
            sg.BackgroundTransparency = 0.25 + 0.55 * (0.5 + 0.5 * math.sin(now * 2 - i * 0.6))
        end
        for _, fl in ipairs(flies) do
            local x = 0.5 + 0.42 * math.sin(now * fl.Sp * 6 + fl.Ph)
            local y = 0.72 + 0.18 * math.sin(now * fl.Sp * 9 + fl.Ph * 2)
            fl.F.Position = UDim2.fromScale(x, y)
            local blink = ((now + fl.Ph) % 2.4)
            local on = blink < 0.12 or (blink > 0.25 and blink < 0.37)
            fl.F.BackgroundTransparency = on and 0 or 0.75
            fl.S.Transparency = on and 0 or 0.7
        end
    end, { f }
end
local function CpOpen(ctx)
    -- ELYTRA SPLIT: two shell halves cover the window and swing apart (0.45 s)
    local t = ctx.Theme
    local root = ctx.Root
    if not root then return end
    local f = root:FindFirstChild("CpOverlay") or ctx.Frame
    for i, side in ipairs({ -1, 1 }) do
        local half = Instance.new("Frame")
        half.Name = "CpShell"; half.BorderSizePixel = 0; half.BackgroundColor3 = Color3.new(1, 1, 1)
        half.AnchorPoint = Vector2.new(side < 0 and 1 or 0, 0); half.Position = UDim2.fromScale(0.5, 0); half.Size = UDim2.fromScale(0.5, 1)
        half.ZIndex = f.ZIndex + 5
        local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0, 24); cr.Parent = half
        CpFacet(ctx, half, t.CaseA, t.CaseB, 3)
        half.Parent = f
        ctx.Tween:Create(half, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.fromScale(0.5 + side * 0.55, -0.15), Rotation = side * 24, BackgroundTransparency = 1 }):Play()
        task.delay(0.45, function() half:Destroy() end)
        for _, d in ipairs(half:GetChildren()) do
            if d:IsA("UIStroke") then ctx.Tween:Create(d, TweenInfo.new(0.42), { Transparency = 1 }):Play() end
        end
    end
end
local function CpTitle(ctx)
    -- a lantern-segment bead under the title: three lime pills, the first brightest
    local bar, t = ctx.Title, ctx.Theme
    local made = {}
    for i = 1, 3 do
        local p = Instance.new("Frame")
        p.Name = "CpBead"; p.BorderSizePixel = 0; p.BackgroundColor3 = t.Lantern; p.AnchorPoint = Vector2.new(0, 1)
        p.Size = UDim2.fromOffset(18 - i * 3, 3); p.Position = UDim2.new(0, 10 + (i - 1) * 20, 1, -2); p.BackgroundTransparency = (i - 1) * 0.3
        p.ZIndex = bar.ZIndex + 1
        local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(1, 0); cr.Parent = p
        p.Parent = bar
        made[i] = p
    end
    return made
end
-- numbers v3 (SKIN UI 2026-10-29, owner: numbers "unique to the skin and the colorways you have equipped"): TAKING FLIGHT.
-- Every number hatches out of a closed pair of WING CASES -- two jewel-lacquer shells with a bronze rim meet over the digits
-- and split open off them (the gun's inspect), then the number lifts away slowly with a little flutter, its digits carrying
-- the shell's iridescent sheen. CRIT = the LANTERN behind it blinks the set's two-flash signal (a lit ring round the number)
-- and the digits are lantern-coloured; WEAK SPOT = a wing glyph in front; a KILL = the SWARM LIGHT: a ring of glowing motes
-- spirals up out of the number and scatters. Every colour is this copy's palette P (the colourway).
local CP_MOTES = 5
local function CpMotion(e, age, pa, life)
    local rise = 1 - (1 - math.min(1, age / 1.0)) ^ 2
    local flutter = math.sin(age * 11 + e.Seed) * 0.08 * math.min(1, age / 0.3)
    local hatch = math.min(1, age / 0.14)
    local b = math.min(1, pa / 0.1)
    local scale = (0.82 + 0.18 * hatch) * (1 + 0.1 * (e.BumpAmp or 1) * (1 - b) * (age > 0.15 and 1 or 0))
    return 0.35 + 1.25 * rise, flutter, scale, 0, 0, flutter * 18
end
local function CpCase(name)
    local w = Instance.new("Frame")
    w.Name = name; w.BorderSizePixel = 0; w.BackgroundColor3 = Color3.new(1, 1, 1); w.AnchorPoint = Vector2.new(0.5, 0.5); w.ZIndex = 4
    local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(1, 0); cr.Parent = w
    local g = Instance.new("UIGradient"); g.Rotation = 60; g.Parent = w
    local st = Instance.new("UIStroke"); st.Thickness = 1.5; st.Parent = w
    return w
end
local function CpAccent(e)
    local box = Instance.new("Frame")
    box.Name = "CpFlight"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 2
    CpCase("CaseL").Parent = box
    CpCase("CaseR").Parent = box
    local ring = Instance.new("Frame")
    ring.Name = "Lantern"; ring.BackgroundTransparency = 1; ring.AnchorPoint = Vector2.new(0.5, 0.5); ring.Position = UDim2.fromScale(0.5, 0.5); ring.ZIndex = 3
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(1, 0); rc.Parent = ring
    local rs = Instance.new("UIStroke"); rs.Thickness = 2; rs.Parent = ring
    ring.Parent = box
    for i = 1, CP_MOTES do
        local m = Instance.new("Frame")
        m.Name = "Mote" .. i; m.BorderSizePixel = 0; m.AnchorPoint = Vector2.new(0.5, 0.5); m.Size = UDim2.fromOffset(5, 5); m.ZIndex = 5
        local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(1, 0); mc.Parent = m
        local ms = Instance.new("UIStroke"); ms.Thickness = 1; ms.Parent = m
        m.Parent = box
    end
    return box
end
local CP_SHELL = ColorSequence.new(BODY:Lerp(Color3.new(1, 1, 1), 0.3), IRID:Lerp(Color3.new(1, 1, 1), 0.2))
local function CpAccentStep(e, box, age, pa, alpha)
    local tb = e.Label.TextBounds
    -- the wing cases: closed over the digits for a beat, then split apart on their hinges and fade (0.24 s)
    local k = math.clamp((age - 0.03) / 0.21, 0, 1)
    local open = 1 - (1 - k) ^ 2
    for i, side in ipairs({ -1, 1 }) do
        local w = box:FindFirstChild(i == 1 and "CaseL" or "CaseR")
        if w then
            w.Visible = k < 1 and not e.Dot
            if w.Visible then
                local hw = math.max(10, tb.X / 2 + 4)
                w.Size = UDim2.fromOffset(hw, tb.Y + 8)
                w.Position = UDim2.new(0.5, side * (hw / 2 + open * hw * 0.7), 0.5, -open * 10)
                w.Rotation = side * open * 38
                w.BackgroundTransparency = math.clamp(alpha + open * 0.9, 0, 1)
                local g = w:FindFirstChildOfClass("UIGradient"); if g then g.Color = CP_SHELL end
                local st = w:FindFirstChildOfClass("UIStroke"); if st then st.Color = MID; st.Transparency = math.clamp(alpha + open, 0, 1) end
            end
        end
    end
    -- the lantern: a lit ring round a crit that blinks the two-flash signal
    local ring = box:FindFirstChild("Lantern")
    if ring then
        local on = e.Crit and not e.Dot
        ring.Visible = on
        if on then
            local t = age % 1.2
            local lit = (t < 0.1 or (t > 0.2 and t < 0.3)) and 1 or 0.2
            ring.Size = UDim2.fromOffset(tb.X + 22, tb.Y + 10)
            local st = ring:FindFirstChildOfClass("UIStroke")
            if st then st.Color = GLOW; st.Transparency = math.clamp(alpha + (1 - lit) * 0.75, 0, 1) end
        end
    end
    -- swarm light: motes spiral up out of the number and scatter on a kill
    local kt = (e.Killed and e.KillAt) and (os.clock() - e.KillAt) or nil
    for i = 1, CP_MOTES do
        local m = box:FindFirstChild("Mote" .. i)
        if m then
            local on = kt ~= nil and kt < 0.9
            m.Visible = on
            if on then
                local q = kt / 0.9
                local a = e.Seed + i * (math.pi * 2 / CP_MOTES) + q * 7
                local r = 8 + 26 * q
                m.Position = UDim2.new(0.5, math.cos(a) * r, 0.5, math.sin(a) * r * 0.45 - 44 * q)
                local blink = ((kt * 6 + i) % 2 < 1.4) and 0 or 0.6
                m.BackgroundColor3 = GLOW; m.BackgroundTransparency = math.clamp(alpha + blink + q * 0.4, 0, 1)
                local st = m:FindFirstChildOfClass("UIStroke"); if st then st.Color = P.Ink; st.Transparency = m.BackgroundTransparency end
            end
        end
    end
end
-- ===== UI THEME v4 (SKIN UI THEMES 2026-10-29 roll-out, owner: themes must "change up the colorways and provide a bit more
-- style than the default", no stretched header art): the clean language in this colourway's shell (UITheme Clean: roles
-- from P) + two touches of a jewel beetle. Hooks read only the palette they are given (a colourway copy shares them):
--   TAB MARK  a WING-CASE EDGE: the underline carries the shell's iridescent sheen (body -> lantern -> violet) that slides
--             as you look, and the selected tab's edge blinks the lantern's two-flash signal every 3 s
--   FIELD     the beetle's LANTERN: a column of glowing segments between dark chitin rings down the right margin, a slow wave
--             of light travelling down it and the two-flash signal every few seconds, and fireflies drifting beside it
local CP_CLEAN = {
    Field = P.Dark:Lerp(P.Ink, 0.45), Surface = P.Dark:Lerp(P.Body, 0.3), Raised = P.Dark:Lerp(P.Body, 0.55), Hover = P.Body:Lerp(P.Irid, 0.32):Lerp(P.Dark, 0.1),
    Well = P.Ink, Line = P.Body:Lerp(P.Mid, 0.5):Lerp(C(255, 255, 255), 0.05), Tip = P.Dark:Lerp(P.Body, 0.2),
    Accent = P.Glow, Mark = P.Glow:Lerp(C(255, 255, 255), 0.55), Hair = P.Mid:Lerp(P.Text, 0.4),
    Text = P.Text, Sub = P.Membrane:Lerp(P.Body, 0.3), Muted = P.Membrane:Lerp(P.Dark, 0.42), Ink = P.Ink,
    Lantern = P.Glow, Sheen = P.Irid:Lerp(C(255, 255, 255), 0.35), Shell = P.Body:Lerp(C(255, 255, 255), 0.3), Chitin = P.Dark, InkLine = P.Ink,
}
CP_CLEAN.TabMark = function(mark, Q)
    -- (a gradient + a stroke, never child frames: tab buttons size themselves to their children)
    local g = Instance.new("UIGradient")
    g.Name = "CpSheen"
    g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Q.Shell), ColorSequenceKeypoint.new(0.45, Q.Lantern),
        ColorSequenceKeypoint.new(0.75, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Q.Sheen) })
    g.Parent = mark
    local sig = Instance.new("UIStroke")
    sig.Name = "CpSignal"; sig.Color = Q.Lantern; sig.Thickness = 2; sig.Transparency = 1; sig.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    sig.Parent = mark
    return { g, sig }
end
CP_CLEAN.Sig = function(ctx)
    local Q, f = ctx.P, ctx.Frame
    local col = Instance.new("Frame")
    col.Name = "CpLanternCol"; col.BackgroundTransparency = 1; col.AnchorPoint = Vector2.new(1, 0); col.ZIndex = 0; col.Parent = f
    local N = 16
    local segs = {}
    for i = 1, N do
        local s = Instance.new("Frame")
        s.Name = "CpSeg"; s.BorderSizePixel = 0; s.BackgroundColor3 = Q.Lantern; s.AnchorPoint = Vector2.new(0.5, 0)
        s.Position = UDim2.new(0.5, 0, (i - 1) / N, 2); s.Size = UDim2.new(1, -1, 1 / N, -5); s.ZIndex = 0
        local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0, 3); cr.Parent = s
        local ck = Instance.new("UIStroke"); ck.Color = Q.Chitin; ck.Thickness = 1.5; ck.Parent = s
        s.Parent = col
        segs[i] = s
    end
    local flies = {}
    for i = 1, 3 do
        local d = Instance.new("Frame")
        d.Name = "CpFly"; d.BorderSizePixel = 0; d.BackgroundColor3 = Q.Lantern; d.AnchorPoint = Vector2.new(0.5, 0.5); d.Size = UDim2.fromOffset(5, 5); d.ZIndex = 0
        local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(1, 0); cr.Parent = d
        d.Parent = f
        flies[i] = { F = d, Ph = i * 2.3 + math.random() * 2, Sp = 0.6 + i * 0.17 }
    end
    local lastW, lastH = -1, -1
    local x1, y0, y1 = 0, 0, 0
    return function(now, _dt)
        local sz = f.AbsoluteSize
        if sz.X ~= lastW or sz.Y ~= lastH then
            lastW, lastH = sz.X, sz.Y
            local topY = 70
            if ctx.Top then topY = ctx.Top.AbsolutePosition.Y - f.AbsolutePosition.Y + ctx.Top.AbsoluteSize.Y end
            x1, y0, y1 = sz.X - 7, topY + 16, sz.Y - 16
            col.Position = UDim2.fromOffset(x1 + 3, y0); col.Size = UDim2.fromOffset(6, math.max(40, y1 - y0))
        end
        -- a slow wave of light runs down the lantern; every 3 s it blinks the two-flash signal
        local t = now % 3
        local flash = (t < 0.12 or (t > 0.24 and t < 0.36)) and 1 or 0
        for i, s in ipairs(segs) do
            local w = 0.5 + 0.5 * math.sin(now * 1.8 - i * 0.45)
            s.BackgroundTransparency = flash > 0 and 0.05 or (0.35 + 0.45 * (1 - w))
        end
        for _, fl in ipairs(flies) do
            local x = x1 - 22 - 16 * (0.5 + 0.5 * math.sin(now * fl.Sp * 0.7 + fl.Ph))
            local y = y0 + (y1 - y0) * (0.5 + 0.45 * math.sin(now * fl.Sp * 0.23 + fl.Ph * 1.7))
            fl.F.Position = UDim2.fromOffset(x, y)
            local b = (now * 0.8 + fl.Ph) % 2.6
            fl.F.BackgroundTransparency = (b < 0.12 or (b > 0.25 and b < 0.37)) and 0 or 0.8
        end
        local slide = math.sin(now * 0.6) * 0.35
        for _, m in ipairs(ctx.Marks()) do
            if m.Visible then
                local g = m:FindFirstChild("CpSheen"); if g then g.Offset = Vector2.new(slide, 0) end
                local s = m:FindFirstChild("CpSignal"); if s then s.Transparency = flash > 0 and 0.1 or 1 end
            end
        end
    end, nil
end
local function PG(top, bottom) return { Top = top, Bottom = bottom } end
local T = {
    { Panel = PG(C(12, 40, 32), C(4, 14, 12)), Card = PG(C(20, 56, 44), C(8, 24, 20)), Title = PG(C(40, 120, 90), C(30, 20, 70)), Accent = C(180, 255, 70), Accent2 = C(150, 90, 220) },
    { Panel = PG(C(42, 30, 10), C(14, 10, 4)), Card = PG(C(58, 42, 14), C(22, 16, 6)), Title = PG(C(130, 90, 20), C(40, 54, 14)), Accent = C(255, 190, 60), Accent2 = C(150, 190, 60) },
    { Panel = PG(C(40, 10, 22), C(14, 4, 9)), Card = PG(C(56, 16, 32), C(22, 6, 13)), Title = PG(C(120, 26, 60), C(36, 18, 80)), Accent = C(255, 110, 170), Accent2 = C(130, 90, 230) },
    { Panel = PG(C(10, 22, 52), C(4, 8, 20)), Card = PG(C(16, 32, 70), C(6, 12, 28)), Title = PG(C(26, 70, 150), C(10, 70, 80)), Accent = C(80, 240, 255), Accent2 = C(40, 150, 200) },
}
local TV = T[VAR] or T[1]
Set.Theme = { Name = "Carapace", Desc = "Menus inside a jewel beetle's shell: the tabs carry the wing cases' iridescent sheen, and the beetle's lantern runs down the edge of the screen, breathing light and blinking its two-flash signal while fireflies drift beside it.",
    Panel = TV.Panel, Card = TV.Card, Title = TV.Title, Accent = TV.Accent, Accent2 = TV.Accent2, HpFill = GLOW, HpBg = C(8, 20, 14), XpFill = WHITEG, Text = P.Text,
    Tex = "CarapaceScales", TexT = 0.9, TexTile = 220, TexScroll = Vector2.new(0, -2),
    Emblem = "EmblemCarapace", BorderThick = 2,
    CaseA = BODY:Lerp(C(255, 255, 255), 0.18), CaseB = IRID, Lantern = GLOW, Ink = P.Ink,
    Deco = CpDeco, OpenFn = CpOpen, TitleDeco = CpTitle,
    Clean = CP_CLEAN, -- (SKIN UI THEMES: the clean palette + iridescent wing-case tab marks + the lantern column and fireflies; the old art is not drawn)
    -- (SKIN UI 2026-10-29: hatched out of a pair of wing cases, a lantern ring on crits, a swarm of motes on a kill; this colourway's P)
    Numbers = { Font = "JosefinSans", Glyph = "❖", NoBang = true, Motion = CpMotion, Accent = CpAccent, AccentStep = CpAccentStep,
        Shine = { P.Membrane, IRID:Lerp(C(255, 255, 255), 0.45) }, Normal = P.Text, Crit = GLOW, Weak = P.Membrane, Stroke = P.Ink, StrokeThick = 2, Size = 1.08 } }

-- ===== bundle / kill effect / store hero =====
Set.KillEffect = { Id = "SwarmLight", Name = "Swarm Light", Image = ART.EmblemCarapace,
    How = "Own any Carapace skin (or the Carapace bundle)",
    Desc = "The body curls up like a beetle, two iridescent wing cases rise out of the floor and clamp shut over it, their seam lights up, and the shell burrows into the ground as the light escapes as fireflies. With the Shell kill banner, which opens wider with every kill of your streak." }
Set.Bundle = { Id = "CarapaceBundle", Name = "Carapace Bundle", Price = 2199, BP = 799, ProductId = 0,
    Desc = "The whole Carapace set: the Carapace Vector, AUG and Spark Pistol, the Mandibles, Chitin Grips + Exoskeleton Sleeves, the Carapace health bar, the Carapace UI theme and the Swarm Light kill effect.",
    Contents = { "WeaponSkin:CarapaceVECTOR", "WeaponSkin:CarapaceAUG", "WeaponSkin:CarapaceSparkPistol", "MeleeSkin:Carapace", "Glove:ChitinGrips", "Sleeve:ExoskeletonSleeves",
        "HealthBar:Carapace", "KillEffect:SwarmLight" } }
Set.Hero = { Grad = { C(16, 54, 42), C(6, 10, 16) }, Stroke = GLOW, Emblem = ART.EmblemCarapace, Name = C(220, 255, 220), Chip = C(70, 40, 110) }

-- (gate: the first banner of a session showed only its word: the sprites were still downloading) the client fetches the
-- banner + theme art when the set loads
if game:GetService("RunService"):IsClient() then
    task.spawn(function()
        pcall(function()
            game:GetService("ContentProvider"):PreloadAsync({ ART.CarapaceLantern, ART.CarapaceElytronL, ART.CarapaceElytronR, ART.EmblemCarapace, ART.SpFirefly })
        end)
    end)
end

return Set
