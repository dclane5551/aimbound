--!nocheck
-- ===================================================================================================================
-- IRONRUNE (Skins V3, bundle 7 of docs/SKINS_V3_PLAN.md): 870 Pump + SCAR-H + SVD | Bearded Axe | 1,199 BP.
-- Northern forge-work: blackened hand-forged iron, dark oak carved in interlaced knotwork, braided leather and bronze,
-- with EMBER GLYPHS that kindle as you kill. The models are RESCULPTED (WeaponAssets.SkinModels.Ironrune_<GUN>, built by
-- tools/skins_v3/ironrune_build.py in art/weapons/SkinsV3_Ironrune.blend, painted by tools/skin_v3_paint.py with
-- tools/skins_v3/ironrune.json: hammered iron, oak grain, carved knotwork, braided leather): carved oak stocks + pump /
-- handguards, forged iron plates on the camera side carrying a line of glyphs (Neon parts Glow_G1..n, grip -> muzzle),
-- bronze bands, rivets, caps and bosses. This module brings their motion and the rest:
--   EMBERS    every glyph glows like a banked ember -- a slow, irregular flicker of its own -- brighter with the streak; a
--             rare spark drifts off the plate
--   KINDLING  equip: the glyphs catch one by one, grip -> muzzle, each with a flare
--   BREATH    inspect: a breath of heat runs along the glyphs and the plate's edges glow orange, then cool
--   RELOAD    the glyphs bank down and re-kindle in order as the reload completes (the 870: one per shell loaded)
-- Muzzle: a forge spark spray + an ember core; tracer: a hot streak shedding a few falling sparks; impact: a
-- hammer-on-anvil spark burst + one of our glyphs scorched into the surface, fading; kill FORGEFALL v2 (the body goes
-- white-hot, breaks into ingots that drop, tumble and cool to iron on a ring of glyphs); banner: a round
-- iron shield plate with a bronze boss beside the HUD weapon card -- each kill kindles one glyph on its rim, at 5 the boss
-- glows.
-- Original design (the plan's Originality line): forged iron + carved knotwork oak + braided leather is in none of its
-- references; the glyphs are OUR invented set (arcs, bars, dots -- no letter of any real alphabet, no words), no stone
-- blocks, no crystal, no named myth figures.
-- ===================================================================================================================
local Set = { Kind = "Ironrune" }

-- COLOURWAYS: each colourway is a whole palette; the module copy SkinFX loads for colourway v has attribute Colorway = v.
local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local PALETTES = {
    { Name = "Hearthfire", Iron = C(36, 31, 30), Oak = C(66, 40, 26), Bronze = C(150, 100, 52), Leather = C(34, 22, 16), Ember = C(255, 90, 30),
      Hot = C(255, 210, 140), Char = C(26, 20, 18), Ash = C(90, 80, 74), Text = C(240, 220, 200), Ink = C(14, 6, 4), Wool = C(28, 23, 21) },
    { Name = "Frostforged", Iron = C(30, 36, 48), Oak = C(52, 52, 56), Bronze = C(108, 116, 128), Leather = C(28, 32, 42), Ember = C(120, 210, 255),
      Hot = C(220, 245, 255), Char = C(20, 24, 32), Ash = C(110, 120, 136), Text = C(225, 235, 245), Ink = C(4, 8, 14), Wool = C(26, 29, 36) },
    { Name = "Bloodforge", Iron = C(22, 17, 17), Oak = C(60, 17, 17), Bronze = C(112, 64, 44), Leather = C(30, 12, 12), Ember = C(255, 50, 70),
      Hot = C(255, 190, 180), Char = C(18, 10, 10), Ash = C(96, 70, 70), Text = C(245, 220, 216), Ink = C(12, 2, 2), Wool = C(30, 15, 17) },
}
local P = PALETTES[VAR] or PALETTES[1]
local EMBER, HOT, IRON, OAK, BRONZE, LEATHER, CHAR, ASH = P.Ember, P.Hot, P.Iron, P.Oak, P.Bronze, P.Leather, P.Char, P.Ash
Set.Palettes = PALETTES
Set.Colors = { Glow = EMBER, Hot = HOT, Mid = BRONZE }
-- art (tools/make_ironrune_art.py -> art/cosmetics/irn_*; uploaded as decals with tools/upload_asset.py; these are the IMAGE
-- ids, resolved in Studio)
local A = "rbxassetid://"
Set.Art = {
    EmblemIronrune = A .. "126767193728826", irn_emblem = A .. "126767193728826", irn_emblem_mask = A .. "116723109845675", irn_corner = A .. "83803374701779", irn_plate = A .. "74972526595872",
    irn_boss = A .. "121467691968208", irn_spark = A .. "75722506392201", tex_irn_iron = A .. "127532838361151", tex_irn_knot = A .. "115902116472722", tex_irn_bar = A .. "85308298884207",
    tex_irn_wool = A .. "135582420882151", tex_irn_leather = A .. "109692083900392", -- (skins9 touch-up: arm materials, make_ironrune_art.py arms)
    irn_glyph1 = A .. "101065816628306", irn_glyph2 = A .. "137078521954314", irn_glyph3 = A .. "96459427472500", irn_glyph4 = A .. "71015960231173", irn_glyph5 = A .. "128230788882686", irn_glyph6 = A .. "114864577179114",
}
local ART = Set.Art
local function Glyph(i: number): string return ART["irn_glyph" .. (((i - 1) % 6) + 1)] end

-- sounds (tools/make_skin_sfx_v3.py ironrune: each gun's own recorded shot + a DRY forge accent -- the first 20 ms of a
-- blacksmith's hammer blow (the strike, no ring), a knock of oak and a short puff of fire; v2 2026-10-11: the v1 shots with
-- a hammer clank pitched down under them drew a Disruptive Audio warning, every shot now passes tools/audio_screen.py; the
-- moments from CC0 recordings of an anvil, a fire lighting, embers crackling, a leather creak and an axe biting wood --
-- tools/sound_sources.json)
Set.Sounds = {
    Equip = { Id = 87855972744637, Volume = 0.45 }, MagOut = { Id = 108739373321942, Volume = 0.3 }, MagIn = { Id = 110462832225084, Volume = 0.35 },
    Kill = { Id = 117473491993636, Volume = 0.55 }, Impact = { Id = 110133998272224, Volume = 0.18 }, Swing = { Id = 84849794941392, Volume = 0.4 },
    MeleeHit = { Id = 91718171552839, Volume = 0.4 },
    FireGun = { R870 = { Id = 108195338126854, Volume = 0.9 }, SCAR = { Id = 83299081223882, Volume = 0.9 }, SVD = { Id = 78873959943976, Volume = 0.9 } },
}
local SND = { Kindle = 132371928083548 }
-- the inspect's breath of heat: a low lighting puff as it starts
Set.InspectEvents = { { "Present+0.1", "Sound", { Id = SND.Kindle, Volume = 0.3 } } }

local TAU = math.pi * 2
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

local function GunDesc(gun: string): string
    local what = (gun == "R870") and "a carved dark-oak stock and pump wrapped in braided leather, a forged iron plate on the receiver with three ember glyphs, bronze bands down the barrel and a bronze boss on the tube"
        or (gun == "SCAR") and "a carved oak paddle stock with a bronze butt, a forged iron handguard with riveted strips and a braided leather wrap, and a line of five ember glyphs on the receiver"
        or "its thumbhole stock and handguard carved from dark oak in knotwork, a forged iron strip of five ember glyphs on the receiver under the scope and bronze rings on the scope"
    return "Northern forge-work in blackened iron, carved oak and bronze: " .. what .. ". The glyphs smoulder like banked embers, brighter with every kill. Drawn, they KINDLE one by one; inspected, a breath of heat runs through them. Forge-spark muzzle, an ember tracer, and every kill is FORGEFALL."
end

-- ===== the guns =====
-- (Fit, gun-space studs measured on the sculpt: the plate centre (a rare ember drifts off it) + the mag well)
Set.GunSkins = {
    { Id = "IronruneR870", Name = "Ironrune 870", Gun = "R870", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = GunDesc("R870"), Model = "Ironrune_R870", V3 = true, Color = EMBER, Deco = "IronruneGun", Glyphs = 3,
      Fit = { ember = Vector3.new(-0.77, 0.176, -0.06) } },
    { Id = "IronruneSCAR", Name = "Ironrune SCAR-L", Gun = "SCAR", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = GunDesc("SCAR"), Model = "Ironrune_SCAR", V3 = true, Color = EMBER, Deco = "IronruneGun", Glyphs = 5,
      Fit = { ember = Vector3.new(-0.31, 0.17, -0.048), well = Vector3.new(-0.1695, 0.0825, 0.0284) } },
    { Id = "IronruneSVD", Name = "Ironrune SVD", Gun = "SVD", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = GunDesc("SVD"), Model = "Ironrune_SVD", V3 = true, Color = EMBER, Deco = "IronruneGun", Glyphs = 5,
      Fit = { ember = Vector3.new(-0.65, 0.027, -0.11), well = Vector3.new(-0.5028, -0.0624, -0.0435) } },
}
local GLYPHS_OF = { R870 = 3, SCAR = 5, SVD = 5 }

-- ===== small Roblox-part bits: the rare ember off the plate + the mag-well sparks (attachments, no parts) =====
Set.Build = {}
Set.Build.IronruneGun = function(model: Model, frame: BasePart, f: any, forView: boolean, H: any)
    if f.ember then
        local a = Instance.new("Attachment")
        a.Name = "IRNEmber"
        a.Position = f.ember
        a.Parent = frame
        H.Emitter(a, { Name = "IRNEmber", Texture = H.SPARK, Color = { HOT, EMBER }, Size = { 0.05, 0 }, Life = { 0.6, 1.1 }, Speed = { 0.3, 0.8 },
            Rate = forView and 0.45 or 0.3, Spread = 35, Accel = Vector3.new(0, 1.2, 0), Drag = 1, Dir = Enum.NormalId.Top, SkinFx = true })
    end
    if f.well then
        local a = Instance.new("Attachment")
        a.Name = "IRNWell"
        a.Position = f.well
        a.Parent = frame
        H.Emitter(a, { Name = "IRNWell", Texture = H.SPARK, Color = { HOT, EMBER }, Size = { 0.06, 0 }, Life = { 0.25, 0.5 }, Speed = { 1, 3 },
            Spread = 40, Accel = Vector3.new(0, -16, 0), Dir = Enum.NormalId.Bottom, SkinFx = true })
    end
end

-- ===== motion: every key the parts read =====
-- st.G1..Gn (glyph glow 0..1), st.Heat (the plate's edge glow). v = rig.SkinVars / rec.Vars
local function Keys(st: any, v: any, n: number, now: number, sinceShot: number, insP: number?)
    local se = st.SinceEquip or 99
    local streak = math.min(st.Streak or 0, 5)
    local base = 0.36 + 0.09 * streak
    local shot = 0.35 * math.exp(-sinceShot / 0.18)
    local rl = st.Reload or 0
    for i = 1, n do
        -- banked ember: slow irregular flicker of its own (two noise octaves) + a faint fast shimmer
        local fl = 0.16 * math.noise(now * 0.9, i * 7.13) + 0.08 * math.noise(now * 2.7, i * 3.71 + 11) + 0.03 * math.sin(now * 9 + i * 2.1)
        local g = base + fl + shot
        -- the inspect's breath of heat: a bright wave running grip -> muzzle
        if insP then
            local c = 0.1 + 0.8 * insP
            g += 0.75 * math.exp(-((c - (i - 0.5) / n) / 0.16) ^ 2)
        end
        -- reload: bank down, then re-kindle in order as it completes
        if rl > 0 then
            if rl < 0.25 then g *= 1 - 0.75 * (rl / 0.25)
            elseif rl < 0.6 + 0.35 * (i - 1) / n then g *= 0.25
            else
                local k = (rl - (0.6 + 0.35 * (i - 1) / n)) / 0.08
                g = g * 0.25 + (g * 0.75 + 0.6 * math.exp(-k)) * smooth(k)
            end
        end
        -- equip: KINDLING -- unlit until its turn, a flare as it catches, then its ember
        local at = 0.14 + (i - 1) * 0.11
        if se < at then g = 0 elseif se < at + 0.16 then g = 1 end
        st["G" .. i] = math.clamp(g, 0, 1)
    end
    st.Heat = insP and smooth(math.sin(math.clamp(insP, 0, 1) * math.pi) * 1.4) or 0
end
local function InspectProgress(rig: any): number?
    if rig.AnimName ~= "Inspect" or not rig.Anim then return nil end
    local L = rig.Anim.Length or 3
    local b = rig.Anim.Beats
    local a0 = (b and (b.Present or b.Raise)) or 0.3
    local a1 = (b and (b.Settle)) or (L - 0.4)
    return math.clamp(((rig.AnimTime or 0) - a0) / math.max(0.3, a1 - a0), 0, 1)
end
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    -- (ViewmodelRig writes st.Anim / st.AnimT only AFTER the set's Drive: the anim is read from the rig itself)
    local n = GLYPHS_OF[rig.GunId or ""] or (rig.Skin and rig.Skin.Glyphs) or 5
    Keys(st, rig.SkinVars, n, now, st.SinceShot or 99, InspectProgress(rig))
end
-- the reload sparks: the SVD / SCAR mag drops a few from the well; the 870's shells each kindle (a sound)
Set.OnEvent = function(rig: any, name: string, H: any)
    if name == "MagOut" and rig.Gun then
        local a = rig.Gun:FindFirstChild("IRNWell", true)
        local e = a and a:FindFirstChild("IRNWell")
        if e then e:Emit(5) end
    elseif name == "ShellIn" then
        -- (one glyph kindling per shell: a short low lighting puff under the gun's own shell sound)
        local snd = Instance.new("Sound")
        snd.SoundId = "rbxassetid://" .. SND.Kindle; snd.Volume = 0.22
        snd.Parent = H.SoundService
        snd:Play()
        H.Debris:AddItem(snd, 2)
    end
end
-- other players' guns: the embers, now and then a breath of heat
Set.World = function(rec: any, now: number, st: any)
    local v = rec.Vars
    v.NextLook = v.NextLook or (now + 5 + math.random() * 6)
    local insP
    if now >= v.NextLook then
        local k = (now - v.NextLook) / 2.2
        if k >= 1 then v.NextLook = now + 9 + math.random() * 7 else insP = k end
    end
    st.SinceEquip = 99; st.Reload = 0; st.Streak = 1
    Keys(st, v, 5, now, 99, insP)
end

-- ===== muzzle: a forge spark spray + an ember core flash (no fireball) =====
Set.Muzzle = function(rig: any, flash: ParticleEmitter, light: PointLight, muzzle: Attachment, H: any)
    flash.Color = ColorSequence.new(HOT, EMBER)
    flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.16), NumberSequenceKeypoint.new(1, 0.03) })
    light.Color = EMBER
    light.Brightness = 0.7
    if rig.Fx and rig.Fx.Smoke then rig.Fx.Smoke.Color = ColorSequence.new(ASH) end
    rig.Fx.IRNSparks = H.Emitter(muzzle, { Name = "IRNSparks", Texture = H.SPARK, Color = { HOT, EMBER }, Size = { 0.05, 0 }, Life = { 0.12, 0.3 },
        Speed = { 6, 14 }, Spread = 22, Dir = Enum.NormalId.Right, Accel = Vector3.new(0, -18, 0), Drag = 2 })
end
Set.OnFire = function(rig: any, H: any)
    if rig.Fx and rig.Fx.IRNSparks then rig.Fx.IRNSparks:Emit(6) end
end

-- ===== EMBER tracer: a hot streak (white-hot at the gun, ember along it) shedding a few falling sparks =====
Set.Tracer = function(H: any, from: Vector3, to: Vector3, peer: boolean?)
    local dist = (to - from).Magnitude
    if dist < 2 then return end
    local host = H.FxPart({ Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1), CFrame = CFrame.new(from) })
    local a0, a1 = H.Att(host, from), H.Att(host, to)
    local line = Instance.new("Beam")
    line.Attachment0, line.Attachment1 = a0, a1
    line.Color = ColorSequence.new(HOT, EMBER); line.LightEmission = 1; line.LightInfluence = 0; line.FaceCamera = true; line.Segments = 1
    line.Width0, line.Width1 = 0.05, 0.025
    line.Parent = host
    if not peer then
        for k = 1, 3 do
            local p = from + (to - from) * (0.25 + 0.22 * k + (math.random() - 0.5) * 0.1)
            local sa = H.Att(host, p)
            local e = H.Emitter(sa, { Texture = H.SPARK, Color = { HOT, EMBER }, Size = { 0.06, 0 }, Life = { 0.3, 0.55 }, Speed = { 0.5, 1.5 },
                Spread = 180, Accel = Vector3.new(0, -12, 0) })
            e:Emit(2)
        end
    end
    local dur = peer and 0.18 or 0.28
    H.Animate(dur + 0.4, function(t)
        local k = math.clamp(t / dur, 0, 1)
        line.Transparency = NumberSequence.new(math.clamp(0.1 + k, 0, 1))
        line.Width0 = 0.05 * (1 - k)
    end, function() host:Destroy() end)
end

-- ===== impact: a hammer-on-anvil spark burst (8) + one of our glyphs scorched into the surface, fading (no light) =====
Set.Impact = function(H: any, pos: Vector3, normal: Vector3?, peer: boolean?)
    if not H.Budget("IronruneImpact", peer and 3 or 7, 0.45) then return end
    local n = (normal and normal.Magnitude > 0.1) and normal.Unit or Vector3.yAxis
    local face = CFrame.lookAt(pos + n * 0.03, pos + n * 2) * CFrame.Angles(0, 0, math.random() * 6.28)
    local p = H.FxPart({ Transparency = 1, Size = Vector3.new(0.5, 0.5, 0.02), CFrame = face })
    local dec = Instance.new("Decal")
    dec.Texture = Glyph(math.random(1, 6)); dec.Face = Enum.NormalId.Front; dec.Color3 = HOT; dec.Transparency = 0
    dec.Parent = p
    local att = H.Att(p, pos + n * 0.05)
    local sp = H.Emitter(att, { Texture = H.SPARK, Color = { HOT, EMBER }, Size = { 0.08, 0 }, Life = { 0.18, 0.4 }, Speed = { 5, 11 }, Spread = 60,
        Accel = Vector3.new(0, -20, 0), Drag = 1 })
    sp.EmissionDirection = Enum.NormalId.Front
    sp:Emit(peer and 3 or 8)
    H.Animate(0.9, function(t)
        local k = t / 0.9
        dec.Color3 = HOT:Lerp(EMBER, math.min(1, k * 2.5)):Lerp(CHAR, math.clamp((k - 0.4) / 0.6, 0, 1))
        dec.Transparency = math.clamp(k ^ 1.4, 0, 1)
    end, function() p:Destroy() end)
end

-- the visible parts of the body a kill landed on (<= 22): the Forgefall ingots are cut from them
local function BodyParts(pos: Vector3, H: any): { BasePart }
    local op = OverlapParams.new()
    op.FilterType = Enum.RaycastFilterType.Exclude
    local ex = { H.FxFolder() }
    for _, pl in ipairs(H.Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
    if workspace.CurrentCamera then table.insert(ex, workspace.CurrentCamera) end
    op.FilterDescendantsInstances = ex
    local hits = workspace:GetPartBoundsInRadius(pos, 3.5, op)
    local best, count = nil, {}
    for _, p in ipairs(hits) do
        local m = p:FindFirstAncestorOfClass("Model")
        while m and not (m:FindFirstChild("Head") or m:FindFirstChild("Torso")) do m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model") end
        if m then count[m] = (count[m] or 0) + 1; if not best or count[m] > count[best] then best = m end end
    end
    local out = {}
    if best then
        for _, p in ipairs(best:GetDescendants()) do
            if p:IsA("BasePart") and p.Transparency < 0.6 and p.Size.Magnitude < 12 and #out < 20 then table.insert(out, p) end
        end
    end
    return out
end
-- ===== FORGEFALL kill v2 (FX audit pilot 2026-10-14; v1 recoloured the body brown and slid it into the floor -- read as a
-- recolour, and its glyph ring sat inside the body). ONE idea: the enemy is FORGED -- it goes white-hot, breaks into
-- glowing ingots that drop and tumble to the floor, and they cool to black iron on a ring of the set's glyphs. 1.4 s.
-- Motion is DOWN and OUT (away from the crosshair line). Budget: full <= 16 ingots + 1 ring part + 1 emitter (<= 24 sparks);
-- low: the glyph ring + 6 ingots, no sparks. =====
Set.Kill = function(H: any, pos: Vector3, low: boolean)
    local ground = H.Ground(pos)
    local R = 3.1
    local ringPart = H.FxPart({ Transparency = 1, Size = Vector3.new(R * 2, 0.05, R * 2), CFrame = CFrame.new(ground + Vector3.new(0, 0.05, 0)) })
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Top; sg.LightInfluence = 0; sg.AlwaysOnTop = false; sg.CanvasSize = Vector2.new(400, 400)
    sg.Parent = ringPart
    local New = H.New
    local glyphs = {}
    for i = 1, 6 do
        local a = TAU * (i - 1) / 6
        glyphs[i] = New("ImageLabel", { BackgroundTransparency = 1, Image = Glyph(i), ImageColor3 = EMBER, AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromScale(0.24, 0.24), Position = UDim2.fromScale(0.5 + math.cos(a) * 0.37, 0.5 + math.sin(a) * 0.38), Rotation = math.deg(a) + 90,
            ImageTransparency = 1 }, sg)
    end
    -- the ingots: every body part cut into bars -- 3 along its long side, 2 across its wide side (seen in play: halves
    -- read as the body falling over in two blocks, not as ingots) -- at most 16
    local model = Instance.new("Model")
    model.Name = "IronruneKill"
    model.Parent = H.FxFolder()
    local ingots = {}
    local center = pos - Vector3.new(0, 1.2, 0)
    local cap = low and 6 or 16
    local function axes(sz: Vector3)
        local list = { { Vector3.xAxis, sz.X }, { Vector3.yAxis, sz.Y }, { Vector3.zAxis, sz.Z } }
        table.sort(list, function(a, b) return a[2] > b[2] end)
        return list[1], list[2]
    end
    for _, src in ipairs(BodyParts(pos, H)) do
        if #ingots >= cap then break end
        local sz, cf = src.Size, src.CFrame
        local A1, A2 = axes(sz)
        local n1 = low and 1 or ((A1[2] > 1.6) and 3 or ((A1[2] > 0.9) and 2 or 1))
        local n2 = (not low and A2[2] > 0.9) and 2 or 1
        local piece = sz - A1[1] * (A1[2] - A1[2] / n1) - A2[1] * (A2[2] - A2[2] / n2)
        for i = 1, n1 do
            for j = 1, n2 do
                if #ingots >= cap then break end
                local off = cf:VectorToWorldSpace(A1[1] * ((i - (n1 + 1) / 2) * A1[2] / n1) + A2[1] * ((j - (n2 + 1) / 2) * A2[2] / n2))
                local p = H.FxPart({ Material = Enum.Material.Neon, Color = HOT, Size = piece * 0.9, CFrame = cf + off }, model)
                local out = (p.Position - center) * Vector3.new(1, 0, 1)
                out = (out.Magnitude > 0.05) and out.Unit or Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
                table.insert(ingots, { P = p, Pos = p.Position, Rot = cf - cf.Position, Vel = out * (2 + math.random() * 2.5) + Vector3.new(0, 3 + math.random() * 3, 0),
                    Spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 9, Half = math.min(piece.X, piece.Y, piece.Z) * 0.45, Landed = false })
            end
        end
    end
    local sparks
    if not low then
        local host = H.FxPart({ Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1), CFrame = CFrame.new(center) }, model)
        sparks = H.Emitter(H.Att(host, center), { Texture = H.SPARK, Color = { HOT, EMBER }, Size = { 0.13, 0 }, Life = { 0.35, 0.7 }, Speed = { 6, 12 },
            Spread = 75, Accel = Vector3.new(0, -26, 0), Drag = 1.2, Dir = Enum.NormalId.Top })
    end
    local broke = false
    H.Animate(1.4, function(t, dt)
        -- 1) HEAT (0 -> 0.2): white-hot, still standing
        -- 2) BREAK at 0.2: the ingots fly out and drop under gravity, tumbling; each bounces once and lies
        if t >= 0.2 and not broke then broke = true; if sparks then sparks:Emit(24) end end
        local step = math.clamp(dt, 0, 1 / 20)
        for i, g in ipairs(ingots) do
            local p = g.P
            if broke and not g.Landed then
                g.Vel += Vector3.new(0, -40, 0) * step
                g.Pos += g.Vel * step
                g.Rot = g.Rot * CFrame.Angles(g.Spin.X * step, g.Spin.Y * step, g.Spin.Z * step)
                if g.Pos.Y - g.Half <= ground.Y then
                    g.Pos = Vector3.new(g.Pos.X, ground.Y + g.Half, g.Pos.Z)
                    if g.Vel.Y < -6 then g.Vel = Vector3.new(g.Vel.X * 0.4, -g.Vel.Y * 0.28, g.Vel.Z * 0.4); g.Spin *= 0.4
                    else g.Landed = true end
                end
            end
            -- 3) COOL: white-hot -> ember -> black iron, then sink into the floor
            local cool = math.clamp((t - 0.25) / 0.8, 0, 1)
            p.Color = (cool < 0.4) and HOT:Lerp(EMBER, cool / 0.4) or EMBER:Lerp(CHAR, (cool - 0.4) / 0.6)
            if cool > 0.75 and p.Material ~= Enum.Material.SmoothPlastic then p.Material = Enum.Material.SmoothPlastic end
            local sink = smooth((t - 1.05) / 0.35)
            p.CFrame = CFrame.new(g.Pos - Vector3.new(0, sink * g.Half * 2.2, 0)) * g.Rot
            p.Transparency = math.clamp(sink ^ 2, 0, 1)
        end
        -- the glyph ring kindles under the pile as the ingots land (0.45 -> 0.75), then banks down
        for i, gl in ipairs(glyphs) do
            local k = math.clamp((t - 0.45 - (i - 1) * 0.04) / 0.1, 0, 1)
            local fade = math.clamp((t - 1.0) / 0.4, 0, 1)
            gl.ImageTransparency = math.clamp(1 - k + fade, 0, 1)
            gl.ImageColor3 = HOT:Lerp(EMBER, math.clamp((t - 0.5) / 0.3, 0, 1)):Lerp(CHAR, fade)
        end
    end, function() ringPart:Destroy(); model:Destroy() end)
end

-- ===== SHIELD banner (beside the HUD's weapon card, <= 180 x 90): a round iron shield plate with a bronze boss; each kill
-- of the streak kindles one glyph on its rim; at 5 the boss glows ember =====
local banner
local NUMFONT = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold)
Set.Banner = function(H: any, streak: number)
    local gui, root = H.BannerRoot("Ironrune", Vector2.new(180, 90), "Side")
    if not root then return end
    local New = H.New
    if not banner or banner.Root ~= root then
        local glow = New("ImageLabel", { BackgroundTransparency = 1, Image = H.Art.Glow, ImageColor3 = EMBER, AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(120, 120), Position = UDim2.fromOffset(45, 45), ImageTransparency = 0.9, ZIndex = 1 }, root)
        local plate = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.irn_plate, ImageColor3 = IRON:Lerp(Color3.new(1, 1, 1), 0.35),
            Size = UDim2.fromOffset(84, 84), Position = UDim2.fromOffset(3, 3), ZIndex = 2 }, root)
        local runes = {}
        for i = 1, 5 do
            local a = math.rad(-90 + (i - 1) * 72)
            runes[i] = New("ImageLabel", { BackgroundTransparency = 1, Image = Glyph(i), ImageColor3 = EMBER, AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromOffset(17, 17), Position = UDim2.fromOffset(45 + math.cos(a) * 25, 45 + math.sin(a) * 25), Rotation = math.deg(a) + 90, ZIndex = 4 }, root)
        end
        local boss = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.irn_boss, ImageColor3 = BRONZE:Lerp(Color3.new(1, 1, 1), 0.25), AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(45, 45), ZIndex = 5 }, root)
        local num = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(96, 42), Size = UDim2.fromOffset(80, 40),
            FontFace = NUMFONT, TextSize = 32, TextColor3 = P.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 6 }, root)
        num:SetAttribute("KeepFont", true)
        New("UIStroke", { Color = P.Ink, Thickness = 2 }, num)
        banner = { Root = root, Plate = plate, Runes = runes, Boss = boss, Glow = glow, Num = num, Token = 0 }
    end
    local b = banner
    b.Token += 1
    local token = b.Token
    local st = math.clamp(streak or 1, 1, 5)
    root.Visible = true
    b.Plate.ImageTransparency = 0
    b.Num.TextTransparency = 0
    b.Num.Text = "x" .. st
    b.Num.TextColor3 = (st >= 5) and HOT or P.Text
    local bossCol = BRONZE:Lerp(Color3.new(1, 1, 1), 0.25)
    b.Boss.ImageTransparency = 0
    b.Boss.ImageColor3 = bossCol
    for i, r in ipairs(b.Runes) do r.ImageTransparency = (i < st) and 0.05 or 0.88; r.ImageColor3 = EMBER end
    H.Animate(0.4, function(t)
        if b.Token ~= token then return end
        local k = t / 0.4
        -- the newest glyph catches: a hot flare settling to ember
        local r = b.Runes[st]
        r.ImageTransparency = math.clamp(0.88 - 0.83 * math.min(1, k * 3), 0, 1)
        r.ImageColor3 = HOT:Lerp(EMBER, k)
        if st >= 5 then
            local f = math.sin(k * math.pi)
            b.Boss.ImageColor3 = bossCol:Lerp(HOT, 0.4 + 0.6 * f)
            b.Glow.ImageTransparency = 0.9 - 0.5 * f
        end
    end, function()
        if b.Token == token and st >= 5 then b.Boss.ImageColor3 = bossCol:Lerp(EMBER, 0.6) end
    end)
    task.delay(1.6, function()
        if b.Token ~= token then return end
        local ti = TweenInfo.new(0.3)
        for _, o in ipairs({ b.Plate, b.Boss, b.Glow }) do H.TweenService:Create(o, ti, { ImageTransparency = 1 }):Play() end
        for _, r in ipairs(b.Runes) do H.TweenService:Create(r, ti, { ImageTransparency = 1 }):Play() end
        H.TweenService:Create(b.Num, ti, { TextTransparency = 1 }):Play()
        task.delay(0.32, function() if b.Token == token then root.Visible = false end end)
    end)
end

-- ===== the BEARDED AXE (melee, class Axe): a forged iron bearded head (the edge bright worked steel), a squared poll, an
-- ember glyph line near the edge on both flats; a dark oak haft with a carved band, a braided leather grip, bronze rings
-- and a bronze pommel cap (MeleeModels.Ironrune). Our beat on the class inspect: the glyph line kindles on the Flip =====
Set.Melee = {
    Skin = { Name = "Bearded Axe", Price = 449, ProductId = 0,
        Desc = "A forged bearded axe: a blackened iron head hammered thin to a bright worked edge, a squared poll, and a line of ember glyphs near the edge that kindle when you look it over. A dark oak haft with a carved band, a braided leather grip and bronze rings. Every kill is FORGEFALL." },
    Rig = { Class = "Axe", BladeLen = 1.1 },
    InspectEvents = { { "Flip", "Emit", { Name = "IRNAxeSparks", Count = 8 } }, { "Flip", "Sound", { Id = SND.Kindle, Volume = 0.3 } } },
    Build = function(m: Model, o: any, H: any)
        local parts = H.CloneModel(m, "MeleeModels", "Ironrune", VAR, { [1] = EMBER })
        local blade = parts.Blade
        if not blade then return end
        -- the swing trail along the edge (melee space: the bearded edge runs x 0.22 -> 0.3, y 0.61 -> 1.06)
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Name, a1.Name = "TrailBase", "TrailTip"
        a0.Position = blade.CFrame:PointToObjectSpace(Vector3.new(0.24, 0.66, 0))
        a1.Position = blade.CFrame:PointToObjectSpace(Vector3.new(0.29, 1.04, 0))
        a0.Parent, a1.Parent = blade, blade
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Color = ColorSequence.new(HOT, EMBER)
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
        tr.LightEmission = 0.8; tr.LightInfluence = 0
        tr.Lifetime = 0.14; tr.MinLength = 0.02; tr.FaceCamera = true
        tr.Enabled = false
        tr:SetAttribute("SwingTrail", true)
        tr.Parent = blade
        local sa = Instance.new("Attachment"); sa.Position = blade.CFrame:PointToObjectSpace(Vector3.new(0.22, 0.88, 0)); sa.Parent = blade
        H.Emitter(sa, { Name = "IRNAxeSparks", Texture = H.SPARK, Color = { HOT, EMBER }, Size = { 0.06, 0 }, Life = { 0.3, 0.6 }, Speed = { 0.5, 1.5 },
            Spread = 180, Accel = Vector3.new(0, 2, 0), Drag = 1, SkinFx = true })
    end,
}
local function MeleeKeys(st: any, v: any, now: number)
    local sw = v.SwingT and (os.clock() - v.SwingT) or 99
    local fl = 0.12 * math.noise(now * 0.9, 3.3) + 0.05 * math.noise(now * 2.6, 9.1)
    st.Edge = math.clamp(0.4 + fl + 0.55 * (st.Inspect or 0) + 0.45 * math.exp(-sw / 0.25), 0, 1)
end
local gunDrive = Set.Drive
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    if rig.Def and rig.Def.IsMelee then MeleeKeys(st, rig.SkinVars, now) return end
    gunDrive(rig, st, dt, now, H)
end
Set.OnAnim = function(rig: any, name: string)
    if rig.Def and rig.Def.IsMelee and (name:find("Light") or name:find("Heavy") or name:find("Quick")) then rig.SkinVars.SwingT = os.clock() end
end

-- ===== arms: FORGE WRAPS + BRACER SLEEVES =====
-- glove: a dark leather glove with a braided leather wrist binding and an iron knuckle plate (bronze rivets); ONE effect:
-- an ember glyph on the plate breathes faintly and flares on a kill
Set.Glove = function(K: any)
    local V = K.V
    return {
        Id = "ForgeWraps", Name = "Forge Wraps", Price = 449,
        Desc = "Dark leather work gloves bound at the wrist with braided leather, an iron knuckle plate riveted in bronze. An ember glyph on the plate breathes like a banked coal and flares on every kill.",
        -- (skins9 touch-up: oiled work-leather grain + scorch on the glove block -- it read as one flat block)
        Base = { Color = LEATHER:Lerp(C(10, 8, 8), 0.2), Material = K.SMOOTH, Reflectance = 0.02, Tex = "tex_irn_leather", TexTile = 1.3, TexT = 0,
            TexColor = LEATHER:Lerp(C(10, 8, 8), 0.2):Lerp(C(255, 255, 255), 0.06) },
        Parts = {
            -- (the plate mesh: 0.32 x 0.031 x 0.15 studs as built -> 0.85 of the hand's width; Seat keeps it on the knuckles' face)
            { Mesh = "Ironrune/Plate", MeshV = VAR, Uniform = true, Size = V(0.85, 0.082, 0.4), Off = V(0, 0.5, -0.22), OffW = V(0, 0.045, 0), Seat = true },
            { Mesh = "Ironrune/Glyph", MeshV = VAR, Glow = true, Color = EMBER, Uniform = true, Size = V(0.128, 0.041, 0.221), Off = V(0, 0.5, -0.22),
              OffW = V(0, 0.088, 0), Seat = true, Anim = "Pulse", PulseMin = 0.15, PulseMax = 0.55, Speed = 1.3, FlashOn = "Kill" },
            { Mesh = "Ironrune/Bind", MeshV = VAR, Size = V(1.12, 1.12, 0.2), Off = V(0, 0, 0.4) },
        },
    }
end
-- sleeve: a dark wool tunic sleeve with a sculpted hardened-leather bracer laced with crossed cords and bronze studs
Set.Sleeve = function(K: any)
    local V = K.V
    return {
        Id = "BracerSleeves", Name = "Bracer Sleeves", Price = 299,
        Desc = "A dark wool tunic sleeve under a sculpted hardened-leather bracer, laced shut with crossed cords through bronze eyelets and studded down both sides.",
        -- (skins8: Fabric's scanned weave read as a light-grey plank down the forearm in Molten; skins9 touch-up: our own heathered
        -- twill wool texture instead, so the long forearm reads as woven cloth and not one flat colour)
        Base = { Color = P.Wool, Material = K.SMOOTH, Reflectance = 0, Tex = "tex_irn_wool", TexTile = 1.1, TexT = 0, TexColor = P.Wool:Lerp(C(255, 255, 255), 0.1) },
        Parts = {
            { Mesh = "Ironrune/Bracer", MeshV = VAR, Size = V(1.16, 1.16, 0.5), Off = V(0, 0, -0.18) },
        },
    }
end

-- ===== health bar: a riveted iron bar engraved with knotwork, an ember fill; a hit throws sparks off the fill's end =====
-- (BARS v2, FX roll-out: the ink frame round a slow-shifting ember fill; lost health BURNS -- it flares white-hot and chars
-- to iron; every hit throws sparks off the fill's end; elites / bosses add the bronze rivets)
Set.Bar = { Id = "Ironrune", Name = "Ironrune", Price = 149,
    Desc = "A forged bar filled with a slow-shifting ember glow. Lost health flares white-hot and chars to iron, and every hit throws sparks off the end of the fill; elites and bosses wear bronze rivets. Part of the Ironrune set.",
    Look = "Ink", Tex = "tex_irn_bar", TexSpeed = 4, TexColor = EMBER:Lerp(HOT, 0.2), ChipMotion = "Burn", Chip = HOT, Back = CHAR, Segments = 5,
    Decor = { "EmberFill", "Rivets", "HitSparks" } }
Set.BarDecor = {
    -- the fill texture is neutral: tint it the colourway's ember
    EmberFill = function(ctx: any, K: any)
        for _, c in ipairs(ctx.Inner:GetChildren()) do if c:IsA("ImageLabel") then c.ImageColor3 = EMBER:Lerp(HOT, 0.2) end end
        return function() end
    end,
    Rivets = function(ctx: any, K: any)
        if ctx.Tier == "Small" then return function() end end
        local f = K.Fader()
        local rv = {}
        for i = 1, 6 do
            local r = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = BRONZE, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 11 }, ctx.Holder)
            K.New("UICorner", { CornerRadius = UDim.new(0.5, 0) }, r)
            K.New("UIStroke", { Color = CHAR, Thickness = 1 }, r)
            f.Add(r, 0, "BackgroundTransparency")
            rv[i] = r
        end
        return function(now, dt, alpha, info)
            local s = math.max(3, ctx.H * 0.28)
            for i, r in ipairs(rv) do
                r.Size = UDim2.fromOffset(s, s)
                r.Position = UDim2.fromOffset(ctx.W * (i - 0.5) / 6, (i % 2 == 0) and -ctx.H * 0.08 or ctx.H * 1.08)
            end
            f.Apply(alpha)
        end
    end,
    HitSparks = function(ctx: any, K: any)
        local sparks = {}
        for i = 1, 5 do
            local s = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = HOT, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 13 }, ctx.Holder)
            K.New("UICorner", { CornerRadius = UDim.new(0.5, 0) }, s)
            sparks[i] = { F = s, T = 99, VX = 0, VY = 0 }
        end
        return function(now, dt, alpha, info)
            if (info.Hit or 0) > 0.95 then
                for _, sp in ipairs(sparks) do sp.T = 0; sp.VX = (math.random() - 0.3) * 90; sp.VY = -40 - math.random() * 60 end
            end
            local x0 = ctx.W * math.clamp(info.Shown, 0.02, 1)
            for _, sp in ipairs(sparks) do
                sp.T += dt
                local k = sp.T / 0.45
                if k < 1 then
                    sp.F.Size = UDim2.fromOffset(3, 3)
                    sp.F.Position = UDim2.fromOffset(x0 + sp.VX * sp.T, ctx.H / 2 + sp.VY * sp.T + 160 * sp.T * sp.T)
                    sp.F.BackgroundColor3 = HOT:Lerp(EMBER, k)
                    sp.F.BackgroundTransparency = math.clamp(k + (1 - alpha), 0, 1)
                else
                    sp.F.BackgroundTransparency = 1
                end
            end
        end
    end,
}

-- ===== UI theme v2 (FX audit pilot 2026-10-14; v1 = the shared template: tiled glass + 4 corner sprites + watermark + ember
-- motes + a flare -- "only a recolour" next to the other sets). Its own pieces, all in the icon look (flat lit face, one hard
-- facet, ink edge; no gloss, no stripes): FORGED IRON STRAPS riveted over every window corner, a WELD SEAM of banked
-- embers along the top that breathes, a HAMMER STRIKE now and then (a few sparks jump off a bottom strap and fall), an
-- ember bead under every title bar with a stamped glyph, and windows open with a QUENCH (a white-hot line runs down the
-- window and the straps cool from ember to iron). Colours come from the theme table, so colourways recolour all of it.
local function Facet(ctx, o, lit, shade)
    local g = Instance.new("UIGradient")
    g.Color = ctx.UIStyle.Facet(lit, shade)
    g.Rotation = ctx.UIStyle.FACET_ROT or 35
    g.Parent = o
    local ink = ctx.UIStyle.InkEdge(o:IsA("Frame") and o.Size.X.Offset < 10 and 1 or 2)
    ink.Parent = o
end
local function Strap(ctx, parent, ax, ay, len, th)
    -- an L-shaped iron strap on a corner (two bars) with two bronze rivets
    local t = ctx.Theme
    local iron, ironLit, bronze = t.IronShade, t.IronFace, t.Accent2
    local holder = Instance.new("Frame")
    holder.Name = "IrnStrap"; holder.BackgroundTransparency = 1; holder.Size = UDim2.fromOffset(len, len)
    holder.AnchorPoint = Vector2.new(ax, ay); holder.Position = UDim2.new(ax, ax == 0 and 5 or -5, ay, ay == 0 and 5 or -5)
    holder.ZIndex = parent.ZIndex + 2; holder.Parent = parent
    local bars = {}
    for i = 1, 2 do
        local b = Instance.new("Frame")
        b.Name = "IrnBar"; b.BorderSizePixel = 0; b.BackgroundColor3 = Color3.new(1, 1, 1); b.ZIndex = holder.ZIndex
        if i == 1 then b.Size = UDim2.fromOffset(len, th) else b.Size = UDim2.fromOffset(th, len) end
        b.AnchorPoint = Vector2.new(ax, ay); b.Position = UDim2.fromScale(ax, ay)
        b.Parent = holder
        Facet(ctx, b, ironLit, iron)
        table.insert(bars, b)
    end
    for _, d in ipairs({ len * 0.42, len * 0.8 }) do
        for i = 1, 2 do
            local r = Instance.new("Frame")
            r.Name = "IrnRivet"; r.BorderSizePixel = 0; r.BackgroundColor3 = bronze; r.ZIndex = holder.ZIndex + 1
            local s = math.max(4, math.floor(th * 0.55))
            r.Size = UDim2.fromOffset(s, s); r.AnchorPoint = Vector2.new(0.5, 0.5)
            local along = (ax == 0) and d or (len - d)
            local down = (ay == 0) and d or (len - d)
            local mid = th / 2
            if i == 1 then r.Position = UDim2.fromOffset(along, (ay == 0) and mid or (len - mid))
            else r.Position = UDim2.fromOffset((ax == 0) and mid or (len - mid), down) end
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = r
            local ink = Instance.new("UIStroke"); ink.Thickness = 1; ink.Color = Color3.fromRGB(8, 6, 6); ink.Parent = r
            r.Parent = holder
        end
    end
    return holder, bars
end
local function IrnDeco(ctx)
    local t = ctx.Theme
    if ctx.Kind ~= "Window" then return nil end -- (HUD panels stay clean: straps there read as clutter by the crosshair line)
    -- (seen in play: straps in the deco layer sat UNDER the title bar and the content -- only two tiny corners showed. They
    -- live on an overlay over the whole window now; the overlay takes no input)
    local host = ctx.Root or ctx.Surface
    local f = Instance.new("Frame")
    f.Name = "IrnOverlay"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 20; f.Active = false
    f:SetAttribute("NoSkin", true); f:SetAttribute("Skinned", true)
    f.Parent = host
    local abs = host.AbsoluteSize
    local small = math.min(abs.X, abs.Y) < 260 -- (the store's mini preview)
    local len = math.clamp(math.floor(math.min(abs.X, abs.Y) * 0.2), small and 22 or 40, small and 40 or 96)
    local th = small and 8 or 14
    for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do Strap(ctx, f, c[1], c[2], len, th) end
    -- the weld seam: banked embers along the top edge, fading at both ends, breathing slowly
    local seam = Instance.new("Frame")
    seam.Name = "IrnSeam"; seam.BorderSizePixel = 0; seam.BackgroundColor3 = t.Accent; seam.AnchorPoint = Vector2.new(0.5, 0)
    seam.Position = UDim2.new(0.5, 0, 0, 4); seam.Size = UDim2.new(1, -2 * (len + 14), 0, 4); seam.ZIndex = f.ZIndex + 1; seam.Parent = f
    local sg = Instance.new("UIGradient")
    sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.15), NumberSequenceKeypoint.new(0.85, 0.15),
        NumberSequenceKeypoint.new(1, 1) })
    sg.Color = ColorSequence.new(t.Accent, t.HotEdge or t.Accent); sg.Parent = seam
    -- the hammer strike: every 5-9 s a few sparks jump off a bottom strap and fall back (6 frames, reused)
    local sparks = {}
    for i = 1, 6 do
        local s = Instance.new("Frame")
        s.Name = "IrnSpark"; s.BorderSizePixel = 0; s.BackgroundColor3 = t.HotEdge or t.Accent; s.Size = UDim2.fromOffset(2, 7)
        s.AnchorPoint = Vector2.new(0.5, 0.5); s.Visible = false; s.ZIndex = f.ZIndex + 3; s.Parent = f
        sparks[i] = { F = s }
    end
    local nextStrike = os.clock() + 2 + math.random() * 4
    local strikeAt, side = -10, 0
    return function(now, dt)
        seam.BackgroundTransparency = 0.25 + 0.3 * (0.5 + 0.5 * math.sin(now * 1.7))
        if now >= nextStrike then
            nextStrike = now + 5 + math.random() * 4
            strikeAt, side = now, (math.random() < 0.5) and 0 or 1
            for _, sp in ipairs(sparks) do
                sp.X, sp.Y = (side == 0) and (len * 0.5) or (f.AbsoluteSize.X - len * 0.5), f.AbsoluteSize.Y - len * 0.5
                sp.VX, sp.VY = ((side == 0) and 1 or -1) * (40 + math.random() * 90), -(90 + math.random() * 110)
                sp.F.Visible = true
            end
        end
        local age = now - strikeAt
        if age < 0.7 then
            for _, sp in ipairs(sparks) do
                sp.VY += 420 * dt
                sp.X += sp.VX * dt; sp.Y += sp.VY * dt
                sp.F.Position = UDim2.fromOffset(sp.X, sp.Y)
                sp.F.Rotation = math.deg(math.atan2(sp.VY, sp.VX)) + 90
                sp.F.BackgroundTransparency = math.clamp(age / 0.7, 0, 1)
            end
        elseif sparks[1].F.Visible then
            for _, sp in ipairs(sparks) do sp.F.Visible = false end
        end
    end, { f }
end
local function IrnOpen(ctx)
    -- QUENCH: a white-hot line runs down the window (0.32 s) and the straps cool from ember to iron (0.6 s)
    local t = ctx.Theme
    local f = (ctx.Root and ctx.Root:FindFirstChild("IrnOverlay")) or ctx.Frame
    local line = Instance.new("Frame")
    line.Name = "IrnQuench"; line.BorderSizePixel = 0; line.BackgroundColor3 = t.HotEdge or t.Accent; line.Size = UDim2.new(1, 0, 0, 4)
    line.ZIndex = f.ZIndex + 4; line.Parent = f
    local g = Instance.new("UIGradient"); g.Rotation = 90; g.Color = ColorSequence.new(t.HotEdge or t.Accent, t.Accent)
    g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6) }); g.Parent = line
    ctx.Tween:Create(line, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0, 0, 1, -4), BackgroundTransparency = 0.5 }):Play()
    task.delay(0.36, function() line:Destroy() end)
    for _, d in ipairs(f:GetDescendants()) do
        if d.Name == "IrnBar" then
            local gr = d:FindFirstChildOfClass("UIGradient")
            if gr then
                gr.Color = ctx.UIStyle.Facet(t.HotEdge or t.Accent, t.Accent)
                task.delay(0.12, function() if gr.Parent then gr.Color = ctx.UIStyle.Facet(t.Accent, t.IronShade) end end)
                task.delay(0.6, function() if gr.Parent then gr.Color = ctx.UIStyle.Facet(t.IronFace, t.IronShade) end end)
            end
        end
    end
end
local function IrnTitle(ctx)
    -- a forge-weld bead under the title bar: a short ember line from the left with a stamped glyph at its end
    local bar, t = ctx.Title, ctx.Theme
    local bead = Instance.new("Frame")
    bead.Name = "IrnBead"; bead.BorderSizePixel = 0; bead.BackgroundColor3 = t.Accent; bead.AnchorPoint = Vector2.new(0, 1)
    bead.Position = UDim2.new(0, 10, 1, -2); bead.Size = UDim2.new(0.3, 0, 0, 2); bead.ZIndex = bar.ZIndex + 1; bead.Parent = bar
    local g = Instance.new("UIGradient")
    g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.85) }); g.Parent = bead
    local gl = Instance.new("ImageLabel")
    gl.Name = "IrnStamp"; gl.BackgroundTransparency = 1; gl.Image = Glyph(1); gl.ImageColor3 = t.Accent; gl.AnchorPoint = Vector2.new(0.5, 0.5)
    gl.Size = UDim2.fromOffset(12, 12); gl.Position = UDim2.new(0.3, 16, 1, -3); gl.ZIndex = bar.ZIndex + 1; gl.Parent = bar
    return { bead, gl }
end
-- numbers v3 (SKIN UI 2026-10-28, owner: numbers "unique to the skin and the colorways"): STRUCK AT THE ANVIL. A serif
-- (Merriweather) number is hammered down into place white-hot, throws a few sparks off the strike and cools to iron as it
-- rises; CRIT / WEAK SPOT = a RUNE burns into the iron beside it (one of the set's six carved runes, picked by the hit) and the
-- sparks fly further; a KILL = the rune flares hot and a second shower of sparks goes up. Every colour is this copy's palette
-- (P = the colourway: Hearthfire embers, Frostforged ice-blue, Bloodforge crimson).
local IRN_SPARKS = 4
local function IrnArt(key: string): string return ART[key] or "" end
-- (the runes + spark only show once loaded: fetch them as soon as the set loads on a client, so the first number has them)
if game:GetService("RunService"):IsClient() then
    task.spawn(function()
        local ids = { ART.irn_spark }
        for n = 1, 6 do table.insert(ids, ART["irn_glyph" .. n]) end
        pcall(function() game:GetService("ContentProvider"):PreloadAsync(ids) end)
    end)
end
local function IrnMotion(e, age, pa, life)
    local k = math.min(1, pa / 0.07)
    local amp = e.BumpAmp or 1
    local scale = 1 + 0.28 * amp * (1 - k)
    local dy = -14 * amp * (1 - k) * (1 - k)
    local up = 0.9 * (1 - (1 - math.min(1, age / 0.8)) ^ 3)
    local shake = (pa < 0.1) and math.sin(pa * 180) * 1.2 or 0
    return up, 0, scale, dy, 0, shake
end
local function IrnAccent(e)
    local box = Instance.new("Frame")
    box.Name = "IrnForge"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 0
    local rune = Instance.new("ImageLabel")
    rune.Name = "Rune"; rune.BackgroundTransparency = 1; rune.AnchorPoint = Vector2.new(1, 0.5); rune.Size = UDim2.fromOffset(22, 22)
    rune.ZIndex = 2; rune.Parent = box
    for i = 1, IRN_SPARKS do
        local sp = Instance.new("ImageLabel")
        sp.Name = "Spark" .. i; sp.BackgroundTransparency = 1; sp.Image = IrnArt("irn_spark"); sp.AnchorPoint = Vector2.new(0.5, 0.5)
        sp.Size = UDim2.fromOffset(8, 8); sp.ZIndex = 2; sp.Parent = box
    end
    return box
end
local function IrnAccentStep(e, box, age, pa, alpha)
    local tb = e.Label.TextBounds
    local marked = (e.Crit or e.Weak or e.Killed) and not e.Dot
    local rune = box:FindFirstChild("Rune")
    if rune then
        rune.Visible = marked
        if marked then
            local n = 1 + math.floor(e.Seed / (math.pi * 2) * 6) % 6
            local img = IrnArt("irn_glyph" .. n)
            if rune.Image ~= img then rune.Image = img end
            local hot = e.Killed and math.max(0, 1 - (os.clock() - (e.KillAt or 0)) / 0.5) or 0
            local burn = math.clamp(age / 0.12, 0, 1)
            rune.ImageColor3 = P.Ember:Lerp(P.Hot, hot)
            rune.Position = UDim2.new(0.5, -math.floor(tb.X / 2) - 3, 0.5, 1)
            local sz = math.floor(e.Label.TextSize * 1.05 + 8 * hot)
            rune.Size = UDim2.fromOffset(sz, sz)
            rune.ImageTransparency = math.clamp(alpha + (1 - burn), 0, 1)
        end
    end
    -- sparks: off every strike (pa resets on a merged hit), further on a crit, a second shower on a kill
    local t = (e.Killed and e.KillAt) and math.min(pa, os.clock() - e.KillAt) or pa
    local reach = (e.Killed and 46) or (e.Crit and 36) or 22
    for i = 1, IRN_SPARKS do
        local sp = box:FindFirstChild("Spark" .. i)
        if sp then
            local on = t < 0.3
            sp.Visible = on
            if on then
                local k = t / 0.3
                local a = e.Seed + i * 1.9
                local d = reach * (1 - (1 - k) ^ 2)
                sp.Position = UDim2.new(0.5, math.cos(a) * d, 0.5, -math.abs(math.sin(a)) * d + 30 * k * k)
                sp.ImageColor3 = P.Hot:Lerp(P.Ember, k)
                sp.ImageTransparency = math.clamp(alpha + k * 0.9, 0, 1)
            end
        end
    end
end
-- ===== UI THEME v4 (SKIN UI THEMES 2026-10-28, owner: themes "lazy and not much different", header art stretched): the clean
-- language in this colourway's colours (UITheme Clean) + two touches of a smithy. Hooks read only the palette they get:
--   TAB MARK  an EMBER WELD: the underline is a bead running white-hot in the middle to ember at the ends, a heat haze round it
--             (the top bar's breathes)
--   FIELD     a forged iron STRAP under the top bar, riveted every ~150 px (rivets in this colourway's fittings), the whole width
local IRN_CLEAN = {
    Field = P.Char:Lerp(P.Ink, 0.35), Surface = P.Char, Raised = P.Iron:Lerp(P.Oak, 0.12), Hover = P.Iron:Lerp(P.Bronze, 0.16),
    Well = P.Ink, Line = P.Ash:Lerp(P.Iron, 0.45), Tip = P.Char:Lerp(P.Ink, 0.2),
    Accent = P.Ember, Mark = P.Hot, Hair = P.Bronze, -- (Mark = the bead's hot core; its gradient cools the ends to ember)
    Text = P.Text, Sub = P.Text:Lerp(P.Ash, 0.42), Muted = P.Ash:Lerp(P.Text, 0.3), Ink = P.Ink,
    Heat = P.Hot, Strap = P.Iron:Lerp(P.Ash, 0.35), StrapEdge = P.Ink, Rivet = P.Bronze,
}
IRN_CLEAN.TabMark = function(mark, Q)
    -- (the heat is a stroke round the bead: tab buttons size themselves to their children and a scale-sized frame inside the
    -- mark grew the tab across the screen -- a stroke never counts)
    local heat = Instance.new("UIStroke")
    heat.Name = "IrnHeat"; heat.Color = Q.Heat; heat.Thickness = 2; heat.Transparency = 0.4; heat.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    heat.Parent = mark
    -- (the bead's own colour runs hot in the middle, cooling to ember at both ends)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Q.Accent), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Q.Accent) })
    g.Parent = mark
    return { heat, g }
end
IRN_CLEAN.Sig = function(ctx)
    local Q = ctx.P
    local made = {}
    local top = ctx.Top
    if top then
        local strap = Instance.new("Frame")
        strap.Name = "IrnStrap"; strap.BorderSizePixel = 0; strap.BackgroundColor3 = Q.Strap; strap.Position = UDim2.new(0, 0, 1, 0)
        strap.Size = UDim2.new(1, 0, 0, 6); strap.ZIndex = 0; strap.Active = false
        local sg = Instance.new("UIGradient")
        sg.Rotation = 90
        sg.Color = ColorSequence.new(Q.Strap:Lerp(Color3.new(1, 1, 1), 0.12), Q.Strap:Lerp(Color3.new(0, 0, 0), 0.35))
        sg.Parent = strap
        local edge = Instance.new("Frame")
        edge.Name = "Edge"; edge.BorderSizePixel = 0; edge.BackgroundColor3 = Q.StrapEdge; edge.AnchorPoint = Vector2.new(0, 1)
        edge.Position = UDim2.fromScale(0, 1); edge.Size = UDim2.new(1, 0, 0, 1); edge.ZIndex = 0; edge.Parent = strap
        local w = top.AbsoluteSize.X
        local k = math.max(0.05, (top.AbsoluteSize.Y > 0) and (top.AbsoluteSize.Y / math.max(1, top.Size.Y.Offset)) or 1)
        local n = math.max(2, math.floor((w / k) / 150))
        for i = 0, n do
            local r = Instance.new("Frame")
            r.Name = "Rivet"; r.BorderSizePixel = 0; r.BackgroundColor3 = Q.Rivet; r.AnchorPoint = Vector2.new(0.5, 0.5)
            r.Position = UDim2.new((i + 0.5) / (n + 1), 0, 0.5, 0); r.Size = UDim2.fromOffset(5, 5); r.ZIndex = 1; r.Parent = strap
            local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = r
            local st = Instance.new("UIStroke"); st.Color = Q.StrapEdge; st.Thickness = 1; st.Parent = r
        end
        strap.Parent = top
        table.insert(made, strap)
    end
    return function(now, _dt)
        -- the weld under the selected tab breathes (banked heat)
        local k = 0.5 + 0.5 * math.sin(now * 1.6)
        for _, m in ipairs(ctx.Marks()) do
            local h = m.Visible and m:FindFirstChild("IrnHeat")
            if h then
                h.Transparency = 0.25 + 0.5 * k
                h.Thickness = 1.5 + 2 * (1 - k)
            end
        end
    end, made
end

local P1 = PALETTES[1]
Set.Theme = { Name = "Ironrune", Desc = "A smithy in every window: forged iron straps riveted over the corners, a weld seam of banked embers along the top that breathes, now and then a hammer strike throws sparks off a strap, and an ember bead and a stamped glyph under every title.",
    Panel = { Top = C(30, 24, 22), Bottom = C(10, 8, 8) }, Card = { Top = C(44, 34, 30), Bottom = C(18, 14, 12) }, Title = { Top = C(120, 70, 40), Bottom = C(40, 22, 14) },
    Accent = P1.Ember, Accent2 = C(190, 140, 80), HpFill = C(255, 100, 40), HpBg = C(20, 12, 10), XpFill = C(190, 140, 80), Text = P1.Text,
    IronFace = C(84, 74, 68), IronShade = C(40, 34, 32), HotEdge = P1.Hot,
    Tex = "tex_irn_iron", TexT = 0.86, TexTile = 240, TexScroll = Vector2.new(0, 0), Tex2 = "tex_irn_knot", Tex2T = 0.92, Tex2Tile = 200,
    Emblem = "EmblemIronrune", BorderThick = 2,
    Deco = IrnDeco, OpenFn = IrnOpen, TitleDeco = IrnTitle,
    Clean = IRN_CLEAN, -- (SKIN UI THEMES: the clean palette + ember-weld tab marks + the riveted strap; the old art is not drawn)
    -- (FX audit pilot: numbers struck white-hot into place in a serif face, then cooling to iron as they rise; no pop)
    -- (SKIN UI 2026-10-28: struck at the anvil -- white-hot, sparks, a burning rune on crits / weak spots; this colourway's P)
    Numbers = { Font = "Merriweather", Glyph = "", NoBang = true, Motion = IrnMotion, Accent = IrnAccent, AccentStep = IrnAccentStep,
        Cool = { P.Hot, P.Ash }, Normal = P.Text, Crit = P.Ember, Weak = P.Hot, Stroke = P.Ink, Size = 1.05 } }

-- ===== kill effect / bundle / store hero =====
Set.KillEffect = { Id = "Forgefall", Name = "Forgefall", Image = ART.EmblemIronrune,
    How = "Own any Ironrune skin (or the Ironrune bundle)",
    Desc = "The enemy is forged: it goes white-hot, breaks into glowing ingots that drop and tumble to the floor, and they cool to black iron on a ring of ember glyphs. With the Ironrune shield banner." }
Set.Bundle = { Id = "IronruneBundle", Name = "Ironrune Bundle", Price = 2199, BP = 799, ProductId = 0,
    Desc = "The whole Ironrune set: the Ironrune 870, SCAR-L and SVD, the Bearded Axe, Forge Wraps and Bracer Sleeves, the Ironrune health bar and the Forgefall kill effect.",
    Contents = { "WeaponSkin:IronruneR870", "WeaponSkin:IronruneSCAR", "WeaponSkin:IronruneSVD", "MeleeSkin:Ironrune", "Glove:ForgeWraps", "Sleeve:BracerSleeves", "HealthBar:Ironrune", "KillEffect:Forgefall" } }
Set.Hero = { Grad = { C(70, 34, 20), C(14, 9, 8) }, Stroke = C(255, 120, 50), Emblem = ART.EmblemIronrune, Name = C(250, 226, 200), Chip = C(110, 52, 26) }

return Set
