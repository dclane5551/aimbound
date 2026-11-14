--!nocheck
-- ===================================================================================================================
-- BESPOKE (Skins V3, bundle 4 of docs/SKINS_V3_PLAN.md): Desert Eagle + Double Barrel + M40 | Bespoke Stiletto | 1,199 BP.
-- The bespoke gunmaker's case set: quilted oxblood leather with saddle stitching, engraved smoked nickel and ebony -- a
-- magnum, a side-by-side and a bolt rifle that belong together. Luxury, chill. The guns, the stiletto, the arm pieces and the
-- kill drape are RESCULPTED models (WeaponAssets.SkinModels.Bespoke_<GUN> / _FX, MeleeModels.Bespoke, ArmsModels.Bespoke;
-- built with tools/skin_v3_blender.py in art/weapons/SkinsV3_Bespoke.blend, painted by tools/skin_v3_paint.py with
-- tools/skins_v3/bespoke.json: quilting, scrollwork engraving and stitching are painted patterns). This module brings:
--   GLINT    a thin highlight glides across the engraved nickel every ~5 s (jewellery catching lamplight); the inspect
--            sweeps it twice, the equip runs it once brighter ("the engraving inks in")
--   JEWEL    one rose jewel per gun set in an engraved nickel rosette on the camera side; it breathes slowly, warms with
--            every shot and with the streak
--   INSPECT  the class inspect + our own beats: the Desert Eagle's slide eases back and forward, the Double Barrel breaks
--            open a few degrees and snaps shut, the M40's bolt lifts and drops
-- A warm soft muzzle flash with a small smoke ring and a few slow sparks, a STITCHED tracer (a dashed thread of light that
-- sews itself from the muzzle to the target), an embroidered ROSETTE impact with a dust puff, the TAILORED kill (a ring of
-- stitches zips round the body on the ground, a sculpted oxblood velvet drape falls over it, settles and fades) and a
-- stitched leather TAG banner beside the HUD's weapon card. Original design (the plan's Originality line): tailored
-- quilting + saddle stitching on guns, a stitched tracer and a draped-cloth finisher are ours; the engraving is generic
-- scrollwork drawn for us; no camera dials, no baroque claws.
-- ===================================================================================================================
local Set = { Kind = "Bespoke" }

local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local PALETTES = {
    { Name = "Oxblood", Body = C(78, 20, 30), Mid = C(86, 88, 98), Detail = C(30, 21, 18), Glow = C(255, 130, 160), Hot = C(255, 214, 220),
      Spark = C(255, 190, 150), Dark = C(14, 8, 10), Text = C(245, 225, 215), Dim = C(120, 50, 64), Ink = C(30, 6, 12), Thread = C(236, 212, 186),
      Velvet = C(96, 18, 32), Glint = C(255, 244, 228) },
    { Name = "Bourbon", Body = C(104, 58, 32), Mid = C(138, 104, 56), Detail = C(34, 22, 16), Glow = C(255, 180, 80), Hot = C(255, 232, 190),
      Spark = C(255, 200, 120), Dark = C(16, 10, 6), Text = C(245, 230, 205), Dim = C(130, 82, 40), Ink = C(26, 12, 4), Thread = C(240, 222, 186),
      Velvet = C(120, 62, 30), Glint = C(255, 240, 210) },
    { Name = "Midnight", Body = C(22, 28, 58), Mid = C(112, 116, 132), Detail = C(16, 16, 22), Glow = C(170, 210, 255), Hot = C(225, 240, 255),
      Spark = C(190, 220, 255), Dark = C(8, 9, 16), Text = C(220, 228, 245), Dim = C(50, 70, 120), Ink = C(6, 8, 20), Thread = C(200, 210, 236),
      Velvet = C(26, 34, 78), Glint = C(235, 244, 255) },
}
local P = PALETTES[VAR] or PALETTES[1]
local GLOW, HOT, BODY, MID, DARK, SPARK, THREAD = P.Glow, P.Hot, P.Body, P.Mid, P.Dark, P.Spark, P.Thread
Set.Palettes = PALETTES
Set.Colors = { Glow = GLOW, Hot = HOT, Spark = SPARK }

-- art (tools/make_bespoke_art.py, uploaded as decals; IMAGE ids resolved in Studio)
local A = "rbxassetid://"
Set.Art = {
    EmblemBespoke = A .. "92247128494009", bs_emblem_mask = A .. "139132031957652", tex_bs_quilt = A .. "127940810718130",
    bs_corner = A .. "95749432789719", bs_tag = A .. "137161616112606", bs_plate = A .. "127872522997941", bs_stitchrow = A .. "94345663343538",
    tex_bs_bar = A .. "94805905973675", bs_buckle = A .. "92042362859084", bs_thread = A .. "130107791509455", bs_rosette = A .. "89657362510172",
    bs_ring = A .. "81194046461850", -- (a plain soft ring sprite: the smoke ring)
    tex_bs_nappa = A .. "90981721721582", tex_bs_glove = A .. "94105219489757", -- (skins12 touch-up: arm leathers, make_bespoke_art.py arms)
}
local ART = Set.Art

-- sounds (tools/make_skin_sfx_v3.py bespoke: each gun's own shot + a wooden-stock thock and a leather-damped tail; moments
-- from CC0 recordings -- leather creak, a briefcase latch, a canvas drop cloth, a sewing machine, a knock on wood)
Set.Sounds = {
    Equip = { Id = 84945948943408, Volume = 0.45 }, MagOut = { Id = 124366112222541, Volume = 0.3 }, MagIn = { Id = 108395872938079, Volume = 0.35 },
    Kill = { Id = 113214887056693, Volume = 0.55 }, Impact = { Id = 79261824629062, Volume = 0.2 }, Swing = { Id = 94115214016074, Volume = 0.4 },
    MeleeHit = { Id = 136255802464643, Volume = 0.4 },
    FireGun = { DEAGLE = { Id = 132039572143547, Volume = 0.75 }, DBARREL = { Id = 92641865516234, Volume = 0.8 }, M40 = { Id = 102492161528940, Volume = 0.82 } },
}

local function GunDesc(gun: string): string
    local what = (gun == "DBARREL") and "engraved nickel lock plates carry a rose jewel in a rosette, the stock and the fore-end are wrapped in quilted leather with oxblood piping and a leather butt pad, and the shells come out oxblood"
        or (gun == "M40") and "the stock is wrapped in quilted leather with a quilted cheek piece, the action wears an engraved nickel plate with a rose jewel, a leather band rides the scope and the bolt ends in an ebony ball on a nickel collar"
        or "the slide wears an engraved nickel side plate with a rose jewel in a rosette, the grip is quilted leather piped in black over the ebony frame and the muzzle carries an engraved band"
    return "The bespoke gunmaker's case set: quilted oxblood leather, saddle stitching, engraved smoked nickel and ebony. " .. string.upper(string.sub(what, 1, 1)) .. string.sub(what, 2) .. ". A soft glint glides across the engraving every few seconds and the jewel breathes; the inspect works the action like a gunsmith showing it off. A stitched tracer sews itself to the target, impacts bloom into embroidered rosettes, and every kill is TAILORED: the body folds down into a stack of velvet and a needle sews it shut."
end

-- ===== the guns =====
Set.GunSkins = {
    { Id = "BespokeDEAGLE", Name = "Bespoke Desert Eagle", Gun = "DEAGLE", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = GunDesc("DEAGLE"), Model = "Bespoke_DEAGLE", V3 = true, Color = GLOW, Color2 = P.Glint },
    { Id = "BespokeDBARREL", Name = "Bespoke Double Barrel", Gun = "DBARREL", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = GunDesc("DBARREL"), Model = "Bespoke_DBARREL", V3 = true, Color = GLOW, Color2 = P.Glint, ShellColor = C(110, 22, 34) },
    { Id = "BespokeM40", Name = "Bespoke M40", Gun = "M40", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = GunDesc("M40"), Model = "Bespoke_M40", V3 = true, Color = GLOW, Color2 = P.Glint },
}

-- ===== motion =====
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
-- GLINT: st.GlintX (0 -> 1 = the highlight's sweep along the plate) + st.Glint (its brightness)
local function Glint(st: any, v: any, now: number, inspectT0: number?)
    v.GlintPh = v.GlintPh or (math.random() * 5)
    local x, k = 0, 0
    local ph = (now + v.GlintPh) % 5.2
    if ph < 0.75 then x = ph / 0.75; k = math.sin(math.pi * x) * 0.8 end
    if st.Anim == "Inspect" and st.AnimT then
        for _, off in ipairs({ 0, 1.05 }) do
            local t = st.AnimT - (inspectT0 or 0.62) - off
            if t > 0 and t < 0.65 then x = t / 0.65; k = math.sin(math.pi * x) end
        end
    end
    local se = st.SinceEquip or 99
    if se < 0.6 then x = se / 0.55; k = math.sin(math.pi * math.clamp(x, 0, 1)) end -- (equip: the engraving inks in)
    st.GlintX = math.clamp(x, 0, 1)
    st.Glint = math.clamp(k, 0, 1)
end
local function Jewel(st: any, now: number, sinceShot: number)
    st.Jewel = math.clamp(0.35 + 0.22 * (0.5 + 0.5 * math.sin(now * 1.25)) + 0.45 * math.exp(-sinceShot / 0.3)
        + 0.06 * math.min(st.Streak or 0, 5) + 0.35 * (st.Inspect or 0), 0, 1)
end
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    local v = rig.SkinVars
    local t0 = rig.Anim and rig.Anim.Beats and (rig.Anim.Beats.Present or rig.Anim.Beats.Raise) or nil
    if rig.Def and rig.Def.IsMelee then
        local sw = v.SwingT and (os.clock() - v.SwingT) or 99
        Glint(st, v, now, t0)
        Jewel(st, now, sw)
        return
    end
    Glint(st, v, now, t0)
    Jewel(st, now, st.SinceShot or 99)
end
Set.OnAnim = function(rig: any, name: string)
    if rig.Def and rig.Def.IsMelee and (name:find("Light") or name:find("Heavy") or name:find("Quick")) then rig.SkinVars.SwingT = os.clock() end
end
Set.World = function(rec: any, now: number, st: any)
    st.SinceEquip = 99; st.Reload = 0; st.Streak = 1; st.Ammo = 1; st.Inspect = 0; st.Anim = nil; st.AnimT = nil
    Glint(st, rec.Vars, now, nil)
    Jewel(st, now, 99)
end

-- the inspect: the class inspect + the gun's own action worked on its beats (channels the rig already drives)
local function WithTrack(base: any, name: string, keys: any): any
    local a = table.clone(base)
    a.Tracks = table.clone(base.Tracks or {})
    a.Tracks[name] = keys
    return a
end
Set.GunInspect = function(def: any, id: string?, base: any): any
    if not base then return nil end
    local b = base.Beats or {}
    local L = base.Length or 3
    if id == "DEAGLE" then
        local t = (b.Flip or b.Present or 1.0) + 0.15 -- (the slide eases back as the pistol turns, then runs home)
        return WithTrack(base, "Slide", { { 0, 0 }, { t, 0 }, { t + 0.35, 0.55 }, { t + 0.75, 0.55 }, { t + 0.9, 0, "Out" }, { L, 0 } })
    elseif id == "DBARREL" then
        local t = (b.Rack or b.Tilt or 1.9)
        return WithTrack(base, "Break", { { 0, 0 }, { t - 0.05, 0 }, { t + 0.2, 0.22, "Out" }, { t + 0.45, 0.22 }, { t + 0.55, 0, "In" }, { L, 0 } })
    elseif id == "M40" then
        local t = (b.Tilt or b.Present or 1.6) + 0.1
        return WithTrack(base, "BoltLift", { { 0, 0 }, { t, 0 }, { t + 0.12, 1, "Out" }, { t + 0.5, 1 }, { t + 0.6, 0, "In" }, { L, 0 } })
    end
    return nil
end

-- ===== muzzle: a soft warm flash, a small smoke ring, a few slow sparks =====
Set.Muzzle = function(rig: any, flash: ParticleEmitter, light: PointLight, muzzle: Attachment, H: any)
    flash.Color = ColorSequence.new(C(255, 236, 214), C(255, 170, 120))
    flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.04) })
    light.Color = C(255, 196, 150)
    light.Brightness = 0.7
    if rig.Fx and rig.Fx.Smoke then rig.Fx.Smoke.Color = ColorSequence.new(C(120, 110, 104)) end
    rig.Fx.BSRing = H.Emitter(muzzle, { Name = "BSRing", Texture = ART.bs_ring, Color = { C(200, 190, 182), C(150, 140, 136) }, Size = { 0.05, 0.4 },
        Life = { 0.35, 0.45 }, Speed = { 1.2, 2 }, Spread = 0, Dir = Enum.NormalId.Right, Orient = Enum.ParticleOrientation.VelocityPerpendicular,
        Trans = { 0.55, 1 }, Light = 0, Influence = 0.6, Locked = false })
    rig.Fx.BSSparks = H.Emitter(muzzle, { Name = "BSSparks", Texture = H.SPARK, Color = { SPARK, GLOW }, Size = { 0.05, 0 }, Life = { 0.25, 0.5 },
        Speed = { 1.5, 3.5 }, Spread = 25, Dir = Enum.NormalId.Right, Accel = Vector3.new(0, -3, 0) })
end
Set.OnFire = function(rig: any, H: any)
    if rig.Fx and rig.Fx.BSRing then rig.Fx.BSRing:Emit(1) end
    if rig.Fx and rig.Fx.BSSparks then rig.Fx.BSSparks:Emit(3) end
end

-- ===== STITCHED tracer: a dashed thread of light sews itself from the muzzle to the target (0.06 s), runs, then fades =====
Set.Tracer = function(H: any, from: Vector3, to: Vector3, peer: boolean?)
    local dist = (to - from).Magnitude
    if dist < 2 then return end
    local host = H.FxPart({ Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1), CFrame = CFrame.new(from) })
    local a0, a1 = H.Att(host, from), H.Att(host, from)
    local thread = Instance.new("Beam")
    thread.Attachment0, thread.Attachment1 = a0, a1
    thread.Texture = ART.bs_thread; thread.TextureMode = Enum.TextureMode.Static; thread.TextureLength = 0.9; thread.TextureSpeed = -6
    thread.Color = ColorSequence.new(THREAD); thread.LightEmission = 0.7; thread.LightInfluence = 0; thread.FaceCamera = true
    thread.Width0, thread.Width1 = 0.14, 0.1
    thread.Parent = host
    local core = Instance.new("Beam")
    core.Attachment0, core.Attachment1 = a0, a1
    core.Color = ColorSequence.new(GLOW); core.LightEmission = 1; core.LightInfluence = 0; core.FaceCamera = true
    core.Width0, core.Width1 = 0.025, 0.015
    core.Parent = host
    local life = peer and 0.16 or 0.2
    H.Animate(life, function(t)
        a1.WorldPosition = to -- (hitscan look: the whole thread at once)
        local f = math.clamp((t - 0.08) / (life - 0.08), 0, 1)
        thread.Transparency = NumberSequence.new(0.05 + 0.95 * f ^ 1.5)
        core.Transparency = NumberSequence.new(0.5 + 0.5 * f)
    end, function() host:Destroy() end)
end

-- ===== ROSETTE impact: an 8-petal rosette of light blooms flat on the surface + a dust puff =====
Set.Impact = function(H: any, pos: Vector3, normal: Vector3?, peer: boolean?)
    if not H.Budget("BespokeImpact", peer and 3 or 7, 0.4) then return end
    local nrm = (normal and normal.Magnitude > 0.1) and normal.Unit or Vector3.yAxis
    local host = H.FxPart({ Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05), CFrame = CFrame.lookAt(pos + nrm * 0.04, pos + nrm * 1.04) * CFrame.Angles(-math.pi / 2, 0, 0) })
    local att = Instance.new("Attachment"); att.Parent = host
    local ro = H.Emitter(att, { Texture = ART.bs_rosette, Color = { HOT, GLOW }, Size = { 0.08, 0.55 }, Life = { 0.32, 0.32 }, Speed = { 0.02, 0.02 },
        Spread = 0, Dir = Enum.NormalId.Top, Orient = Enum.ParticleOrientation.VelocityPerpendicular, Trans = { 0.05, 1 }, Rot = { 0, 360 } })
    local dust = H.Emitter(att, { Texture = H.SMOKE, Color = { C(150, 130, 116) }, Size = { 0.12, 0.35 }, Life = { 0.3, 0.5 }, Speed = { 0.6, 1.4 },
        Spread = 50, Dir = Enum.NormalId.Top, Trans = { 0.6, 1 }, Light = 0, Influence = 1 })
    ro:Emit(1)
    dust:Emit(peer and 2 or 4)
    task.delay(0.6, function() host:Destroy() end)
end

local V = Vector3.new
-- ===== TAILORED v3 kill (2026-10-14; owner on v2: "not great" -- the drape was a prop dropped over a body that just
-- vanished. In the FX_AUDIT "WHAT MAKES FISSION / FERROFLUX WORK" mould now): the BODY IS FOLDED DOWN LIKE CLOTH -- from
-- the top down, every part drops and flattens into a layer of oxblood velvet, each layer turned a little, piling up as a
-- folded stack on the real floor; then a big nickel needle races round the stack trailing glowing thread and sews a ring
-- of thick stitches round it (6+ studs across, ink-backed), the thread pulls TIGHT (the stack gathers, every stitch flashes)
-- and it all sinks away (1.4 s). Beats: fold 0.04-0.5 / sew 0.5-0.92 / pull tight 0.95 / sink 1.1-1.4. Motion is DOWN and
-- ROUND on the floor. Budget: full = <= 7 body layers + stitch ring + needle + 1 trail + 10 dust; low = 3 layers + ring +
-- needle, 1.1 s. =====
local TAU = math.pi * 2
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
    local model = Instance.new("Model"); model.Name = "BespokeKill"; model.Parent = H.FxFolder()
    local dur = low and 1.1 or 1.4
    local SM = Enum.Material.SmoothPlastic
    -- the body's parts, highest first: each becomes one folded layer of the stack
    local srcs = BodyParts(pos, H)
    local list = {}
    for i = 1, math.min(#srcs, low and 3 or 7) do list[i] = srcs[i] end
    table.sort(list, function(a, b) return a.Position.Y > b.Position.Y end)
    local layers = {}
    local n = #list
    for i, s in ipairs(list) do
        local ok, c = pcall(function() return s:Clone() end)
        if ok and c then
            for _, ch in ipairs(c:GetChildren()) do
                if not (ch:IsA("SpecialMesh") or ch:IsA("DataModelMesh")) then ch:Destroy() end
            end
            c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
            if c:IsA("MeshPart") then c.TextureID = "" end
            c.Parent = model
            -- the order it lands in the stack: the LAST to fold (lowest part) lies on top
            local slot = n - i
            local w = math.clamp(3.3 - slot * 0.22, 2.0, 3.3)
            local yaw = (i % 2 == 0 and 1 or -1) * (0.15 + 0.1 * i)
            table.insert(layers, { P = c, CF = c.CFrame, Size = c.Size, C0 = c.Color, M0 = c.Material,
                T0 = 0.04 + (i - 1) * (0.32 / math.max(1, n)),
                Flat = V(w, 0.2, w * 0.82), Y = ground.Y + 0.12 + slot * 0.2, Yaw = yaw,
                Col = (i % 2 == 0) and P.Velvet or P.Velvet:Lerp(BODY, 0.5) })
        end
    end
    -- the stitch ring (thick thread dashes on ink, sewn behind the needle)
    local R = 2.95
    local ringPart = H.FxPart({ Transparency = 1, Size = V(R * 2.3, 0.05, R * 2.3), CFrame = CFrame.new(axis + V(0, 0.06, 0)) }, model)
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Top; sg.LightInfluence = 0; sg.CanvasSize = Vector2.new(460, 460); sg.Parent = ringPart
    local N = 16
    local dashes = {}
    local a0 = math.random() * TAU
    for i = 1, N do
        local a = a0 + (i - 0.5) / N * TAU
        local dsh = H.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = GLOW, AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromScale(0.13, 0.07), Position = UDim2.fromScale(0.5 + math.cos(a) * 0.435, 0.5 + math.sin(a) * 0.435),
            Rotation = math.deg(a) + 90 + 14, BackgroundTransparency = 1 }, sg)
        H.New("UICorner", { CornerRadius = UDim.new(0.5, 0) }, dsh)
        local ink = H.New("UIStroke", { Color = P.Ink, Thickness = 6, Transparency = 1 }, dsh)
        dashes[i] = { F = dsh, Ink = ink }
    end
    -- the needle: polished nickel, its thread a glowing trail
    local needle = H.FxPart({ Material = SM, Color = MID, Reflectance = 0.3, Size = V(0.26, 0.26, 2.4), Transparency = 1, CFrame = CFrame.new(axis) }, model)
    local t0, t1 = Instance.new("Attachment"), Instance.new("Attachment")
    t0.Position, t1.Position = V(0, 0.13, 1.15), V(0, -0.13, 1.15)
    t0.Parent, t1.Parent = needle, needle
    local trail = Instance.new("Trail")
    trail.Attachment0, trail.Attachment1 = t0, t1
    trail.Color = ColorSequence.new(HOT, GLOW); trail.LightEmission = 1; trail.LightInfluence = 0; trail.FaceCamera = true
    trail.Lifetime = 0.22; trail.WidthScale = NumberSequence.new(1, 0.4)
    trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
    trail.Enabled = false; trail.Parent = needle
    local dust = (not low) and H.Emitter(H.Att(ringPart, axis + V(0, 0.3, 0)), { Texture = H.SMOKE, Color = { P.Velvet:Lerp(THREAD, 0.4), P.Velvet },
        Size = { 0.7, 1.4 }, Life = { 0.35, 0.6 }, Speed = { 3, 6 }, Spread = 90, Drag = 5, Light = 0, Influence = 1,
        Trans = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }), Dir = Enum.NormalId.Top }) or nil
    local sewFrom = low and 0.4 or 0.5
    local sewTo = sewFrom + 0.42
    local puffed = false
    H.Animate(dur, function(t)
        local tight = smooth((t - sewTo) / 0.1)
        local sink = smooth((t - (dur - 0.3)) / 0.3)
        -- 1) FOLD: top first, each part drops, flattens and turns into a layer of velvet on the stack
        for _, L in ipairs(layers) do
            local k = smooth((t - L.T0) / 0.2)
            local home = L.CF.Position
            local flatCF = CFrame.new(axis.X, L.Y - sink * 1.6, axis.Z) * CFrame.Angles(0, L.Yaw, 0)
            local fold = (L.CF - home):Lerp(flatCF - flatCF.Position, k) + home:Lerp(flatCF.Position, k)
            L.P.CFrame = fold
            local gather = 1 - 0.14 * tight
            L.P.Size = L.Size:Lerp(L.Flat * V(gather, 1, gather), k)
            L.P.Color = L.C0:Lerp(L.Col, math.clamp(k * 1.4, 0, 1))
            if k > 0.5 and L.P.Material ~= SM then L.P.Material = SM end
            L.P.Transparency = sink
        end
        if not puffed and t > 0.42 then puffed = true; if dust then dust:Emit(10) end end
        -- 2) SEW: the needle races once round the stack, dipping through, the stitches appear behind it
        local k = (t - sewFrom) / (sewTo - sewFrom)
        if k > 0 and k < 1.35 then
            local kk = math.min(k, 1)
            local a = a0 + kk * TAU
            local r = R * (1 - 0.1 * tight)
            local p = axis + V(math.cos(a) * r, 0.45 + 0.22 * math.sin(kk * N * math.pi), math.sin(a) * r)
            local tang = V(-math.sin(a), 0, math.cos(a))
            if k > 1 then p += V(0, (k - 1) * 9, 0) + tang * (k - 1) * 4 end
            needle.CFrame = CFrame.lookAt(p, p - tang) * CFrame.Angles(math.rad(-12), 0, 0)
            needle.Transparency = (k > 1) and math.clamp((k - 1) / 0.3, 0, 1) or 0
            trail.Enabled = k < 1.2
        else
            needle.Transparency = 1; trail.Enabled = false
        end
        -- 3) PULL TIGHT: the ring draws in, every stitch flashes hot, then everything sinks
        local rs = R * 2.3 * (1 - 0.1 * tight)
        ringPart.Size = V(rs, 0.05, rs)
        local flash = math.exp(-((t - sewTo - 0.05) / 0.06) ^ 2)
        for i, d in ipairs(dashes) do
            local on = math.clamp((k - (i - 1) / N) * N, 0, 1)
            local tr = math.clamp(1 - on + sink, 0, 1)
            d.F.BackgroundTransparency = tr
            d.Ink.Transparency = math.clamp(tr + 0.1, 0, 1)
            d.F.BackgroundColor3 = HOT:Lerp(GLOW, math.clamp((k - i / N) * 6, 0, 1)):Lerp(HOT, flash)
        end
    end, function() model:Destroy() end)
end

-- (skins6, BESPOKE gate) the first Tailored of a session fell as a WHITE sheet (seen in play: the drape's maps were still
-- streaming in; the second kill showed the oxblood velvet). The drape (this colourway's maps) is preloaded the first time
-- a Bespoke piece is drawn.
local drapeLoaded = false
Set.OnEquip = function(rig: any, H: any)
    if drapeLoaded or not H then return end
    drapeLoaded = true
    task.spawn(function()
        local src = H.ModelSource("SkinModels", "Bespoke_FX")
        local d = src and src:FindFirstChild("Drape")
        if not d then return end
        local c = d:Clone()
        if VAR > 1 then pcall(H.V3Swap, c, VAR) end
        pcall(function() game:GetService("ContentProvider"):PreloadAsync({ c }) end)
        c:Destroy()
    end)
end

-- ===== TAG banner (beside the HUD's weapon card): a stitched leather tag with a nickel plate slides in; each kill of the
-- streak adds a stitch row (1-5) that sews itself across =====
local banner
Set.Banner = function(H: any, streak: number)
    local gui, root = H.BannerRoot("Bespoke", Vector2.new(180, 90), "Side")
    if not root then return end
    if not banner or banner.Root ~= root then
        local New = H.New
        local slide = New("Frame", { Name = "Slide", BackgroundTransparency = 1, Size = UDim2.fromOffset(180, 90) }, root)
        local tag = New("ImageLabel", { Name = "Tag", BackgroundTransparency = 1, Image = ART.bs_tag, ImageColor3 = PALETTES[VAR].Velvet:Lerp(C(255, 255, 255), 0.05),
            Size = UDim2.fromOffset(176, 88), Position = UDim2.fromOffset(2, 1), ZIndex = 2 }, slide)
        local plate = New("ImageLabel", { Name = "Plate", BackgroundTransparency = 1, Image = ART.bs_plate, ImageColor3 = MID:Lerp(C(255, 255, 255), 0.45),
            Size = UDim2.fromOffset(92, 36), Position = UDim2.fromOffset(62, 10), ZIndex = 3 }, slide)
        local num = New("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(92, 36), Position = UDim2.fromOffset(62, 10),
            Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = C(34, 30, 32), Text = "", ZIndex = 4 }, slide)
        local rows = {}
        for i = 1, 5 do
            local clip = New("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.fromOffset(0, 6),
                Position = UDim2.fromOffset(60, 50 + (i - 1) * 6.5), ZIndex = 4 }, slide)
            New("ImageLabel", { BackgroundTransparency = 1, Image = ART.bs_stitchrow, ImageColor3 = THREAD, Size = UDim2.fromOffset(100, 6), ZIndex = 4 }, clip)
            rows[i] = clip
        end
        banner = { Root = root, Slide = slide, Tag = tag, Plate = plate, Num = num, Rows = rows, Token = 0, T0 = 0, Streak = 1 }
        H.RunService.RenderStepped:Connect(function()
            local b = banner
            if not (b and b.Root.Visible) then return end
            local t = os.clock() - b.T0
            b.Slide.Position = UDim2.fromOffset(-24 * (1 - smooth(t / 0.18)), 0)
            for i, r in ipairs(b.Rows) do
                local w = 0
                if i < b.Streak then w = 100 elseif i == b.Streak then w = 100 * smooth((t - 0.1) / 0.28) end
                r.Size = UDim2.fromOffset(w, 6)
            end
        end)
    end
    local b = banner
    b.Token += 1
    local token = b.Token
    b.T0 = os.clock()
    b.Streak = math.clamp(streak or 1, 1, 5)
    root.Visible = true
    b.Num.Text = "x" .. b.Streak
    for _, o in ipairs({ b.Tag, b.Plate }) do o.ImageTransparency = 0 end
    b.Num.TextTransparency = 0
    for _, r in ipairs(b.Rows) do local img = r:FindFirstChildOfClass("ImageLabel"); if img then img.ImageTransparency = 0 end end
    task.delay(1.6, function()
        if b.Token ~= token then return end
        local ti = TweenInfo.new(0.3)
        for _, o in ipairs({ b.Tag, b.Plate }) do H.TweenService:Create(o, ti, { ImageTransparency = 1 }):Play() end
        H.TweenService:Create(b.Num, ti, { TextTransparency = 1 }):Play()
        for _, r in ipairs(b.Rows) do local img = r:FindFirstChildOfClass("ImageLabel"); if img then H.TweenService:Create(img, ti, { ImageTransparency = 1 }):Play() end end
        task.delay(0.32, function() if b.Token == token then root.Visible = false end end)
    end)
end

-- ===== the BESPOKE STILETTO (melee, Knife class; MeleeModels.Bespoke, tools/skins_v3/bespoke_stiletto.py). (skinsB
-- 2026-10-13, owner: the Barber's Razor "looks like a French fry right now" -> a stiletto.) A slim needle-point blade, a
-- narrow engraved smoked-nickel flat down each face between polished hollow-ground bevels, a brass cross-guard with ball
-- finials and diamond langets, an oxblood leather grip wound with twisted brass wire, a faceted brass pommel carrying the
-- rose jewel. Same MeleeSkin id "Bespoke" as the razor (owners keep it, no migration). Its own move set: a tailor's
-- draw (spun up out of the cuff), quick thrusts (forehand stab, backhand cut-and-stab), an overhand heavy driven down at
-- the crosshair, and an inspect that shows the engraving, runs the light down the blade (Glint) and twirls it on the
-- fingers. =====
local Inspects = require(game:GetService("ReplicatedStorage"):WaitForChild("AimRngShared"):WaitForChild("Inspects")) -- (a leaf module; colourway copies of this module live outside SkinSets)
local MK, MN = Inspects.K, Inspects.N
Set.Melee = {
    Skin = { Name = "Bespoke Stiletto", Price = 449, ProductId = 0,
        Desc = "Turns your melee into a bespoke stiletto: a slim needle-point blade with an engraved smoked-nickel flat between polished bevels, a brass cross-guard with ball finials, an oxblood leather grip wound with brass wire and a faceted brass pommel set with a rose jewel. It spins up out of the cuff on the draw and strikes in quick thrusts; inspect it and the light runs down the engraving before it twirls on your fingers. Every kill is TAILORED: a ring of stitches and a falling velvet drape." },
    Rig = { Class = "Knife", BladeLen = 0.8, FlatBlade = true },
    -- the DRAW: up from below the cuff, spun one and a half turns about the blade as it rises, caught flat to you
    EquipAnim = { Length = 0.6, Tracks = {
        Gun = { MK(0, 0.06, -0.55, 0.12, -46, 8, -24), MK(0.18, 0.03, -0.16, 0.05, -12, 2, -8), MK(0.32, 0, 0.035, -0.01, 6, -4, 3, "Out"),
            MK(0.44, 0, -0.008, 0, -1.5, 0, 0), MK(0.6) },
        BladeRoll = { MN(0, -540), MN(0.3, -30), MN(0.42, 4), MN(0.6, 0) },
    }, Events = { { 0.05, "Equip" }, { 0.32, "Catch" } } },
    -- LIGHT 1: a quick forehand THRUST -- a short draw back, then driven forward at the crosshair
    Light1Anim = { Length = 0.4, Tracks = { Gun = {
        MK(0), MK(0.05, 0.05, -0.02, 0.09, 8, -8, -4), MK(0.12, -0.15, 0.06, -0.46, -6, 16, 6, "Out"), MK(0.2, -0.14, 0.05, -0.41, -5, 15, 6), MK(0.4),
    } }, Events = { { 0.08, "Swing" } } },
    -- LIGHT 2: a BACKHAND cut that turns into a stab -- swept out to the left, then snapped back in and forward
    Light2Anim = { Length = 0.44, Tracks = { Gun = {
        MK(0), MK(0.07, -0.3, 0.06, 0.0, 6, 30, 14), MK(0.15, 0.06, 0.02, -0.34, -8, -20, -10, "Out"), MK(0.23, 0.08, 0.01, -0.3, -8, -22, -10), MK(0.44),
    } }, Events = { { 0.1, "Swing" } } },
    -- HEAVY: raised overhand (tip back over the fist), then driven down and forward into the target
    HeavyAnim = { Length = 0.8, Tracks = { Gun = {
        MK(0), MK(0.24, 0.08, 0.2, 0.2, 38, -10, -6), MK(0.37, -0.12, -0.03, -0.55, -30, 18, 4, "Out"), MK(0.52, -0.11, -0.02, -0.5, -28, 17, 4), MK(0.8),
    } }, Events = { { 0.31, "Swing" } } },
    -- INSPECT: raised toward the middle, tip up, the engraved flat to you (the Glint runs down the blade on Raise), tipped
    -- along its length, TWIRLED once on the fingers (Flip), shown on the other face, settled
    InspectAnim = { Length = 3.2, Beats = { Raise = 0.45, Flip = 1.75, Settle = 2.9 }, Tracks = {
        Gun = { MK(0), MK(0.45, -0.19, 0.15, 0.02, 28, -16, -30), MK(1.15, -0.2, 0.16, 0.02, 16, -24, -38), MK(1.45, -0.18, 0.15, 0.01, 18, -12, -20),
            MK(1.75, -0.16, 0.13, 0, 12, 6, 30), MK(2.45, -0.15, 0.13, 0, 10, 10, 32), MK(2.9, 0, -0.01, 0, -2, 0, 2), MK(3.2) },
        BladeRoll = { MN(0, 0), MN(0.5, 14), MN(1.3, 20), MN(1.45, 20), MN(1.75, 380), MN(2.45, 384), MN(2.85, 360), MN(3.2, 360) },
    }, Events = { { 0.45, "Raise" }, { 1.5, "Sound", { Id = Set.Sounds.MagOut.Id, Volume = 0.18 } },
        { 1.75, "Sound", { Id = Set.Sounds.MagIn.Id, Volume = 0.28 } }, { 1.75, "Flip" }, { 2.9, "Settle" } } },
    InspectEvents = { { "Flip", "Emit", { Name = "BSMeleeSparks", Count = 8 } } },
    Build = function(m: Model, o: any, H: any)
        local parts = H.CloneModel(m, "MeleeModels", "Bespoke", VAR, { [1] = GLOW })
        local blade = parts.Blade
        if not blade then return end
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Name, a1.Name = "TrailBase", "TrailTip"
        a0.Position = blade.CFrame:PointToObjectSpace(Vector3.new(0, 0.34, 0))
        a1.Position = blade.CFrame:PointToObjectSpace(Vector3.new(0, 0.95, 0))
        a0.Parent, a1.Parent = blade, blade
        -- the swing trail: a thin stitched ribbon (the thread colour into the jewel) that fades quickly
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Color = ColorSequence.new(THREAD, GLOW)
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
        tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
        tr.LightEmission = 0.6; tr.LightInfluence = 0
        tr.Lifetime = 0.12; tr.MinLength = 0.02; tr.FaceCamera = true
        tr.Enabled = false
        tr:SetAttribute("SwingTrail", true)
        tr.Parent = blade
        local sa = Instance.new("Attachment"); sa.Position = blade.CFrame:PointToObjectSpace(Vector3.new(0, 0.7, 0)); sa.Parent = blade
        H.Emitter(sa, { Name = "BSMeleeSparks", Color = { HOT, GLOW }, Size = { 0.05, 0 }, Life = { 0.2, 0.4 }, Speed = { 0.8, 2 }, Accel = Vector3.new(0, -4, 0), SkinFx = true })
    end,
}

-- ===== arms: DRIVING GLOVES + BESPOKE SLEEVES =====
-- glove: an oxblood perforated leather driving glove (a knuckle cut-out, a snap strap at the wrist); ONE effect: a highlight
-- glints across the nickel snap every few seconds
Set.Glove = function(K: any)
    local V = K.V
    return {
        Id = "DrivingGloves", Name = "Driving Gloves", Price = 449,
        Desc = "Oxblood perforated leather driving gloves with a knuckle cut-out, saddle stitching and a snap strap at the wrist. Every few seconds a highlight glints across the nickel snap.",
        -- (darker than the panel: the back panel reads as its own piece; skins12 touch-up: a lambskin grain on the hand block --
        -- it read as one flat red block in first person)
        Base = { Color = PALETTES[VAR].Body:Lerp(C(0, 0, 0), 0.5), Material = K.SMOOTH, Reflectance = 0.04, Tex = "tex_bs_glove", TexTile = 1.1, TexT = 0,
                 TexColor = PALETTES[VAR].Body:Lerp(C(0, 0, 0), 0.3) },
        Parts = {
            { Mesh = "Bespoke/Back", MeshV = VAR, Size = V(0.98, 0.12, 0.9), Off = V(0, 0.5, -0.03) },
            { Mesh = "Bespoke/Strap", MeshV = VAR, Size = V(1.08, 0.2, 0.18), Off = V(0, 0.52, 0.42) },
            -- (skins12 touch-up: a black piped side seam down each side of the hand -- the side face is what the idle hold shows)
            { Size = V(0.04, 0.05, 0.78), Off = V(0.5, 0.18, -0.04), Color = DARK, Material = K.SMOOTH, Reflectance = 0.04 },
            { Size = V(0.04, 0.05, 0.78), Off = V(-0.5, 0.18, -0.04), Color = DARK, Material = K.SMOOTH, Reflectance = 0.04 },
            { Size = V(0.07, 0.015, 0.07), Off = V(0.27, 0.63, 0.42), Color = P.Glint, Glow = true, Uniform = true,
              Anim = "Twinkle", Period = 4.2, Dur = 0.35, PulseMin = 0.05, PulseMax = 1 },
        },
    }
end
-- sleeve: a quilted black leather jacket sleeve (diamond quilting on the forearm), a sculpted nickel zip running to the
-- cuff, oxblood piping, a rolled leather cuff with a nickel edge
Set.Sleeve = function(K: any)
    local V = K.V
    return {
        Id = "BespokeSleeves", Name = "Bespoke Leather Sleeves", Price = 299,
        Desc = "A quilted black leather jacket sleeve: diamond quilting along the forearm, oxblood piping, a sculpted nickel zip running down to a rolled leather cuff with a nickel edge.",
        -- (skins12 touch-up, arms bar: the sleeve's long side face filled the left of the screen as one flat black block ->
        -- a pebbled nappa leather on the block, an oxblood piped side seam down each flank and a nickel snap tab at the cuff)
        Base = { Color = C(16, 15, 18), Material = K.SMOOTH, Reflectance = 0.05, Tex = "tex_bs_nappa", TexTile = 0.9, TexT = 0, TexColor = C(32, 29, 34) },
        Parts = {
            { Mesh = "Bespoke/Quilt", MeshV = VAR, Size = V(1.0, 0.13, 0.9), Off = V(0, 0.5, 0.02) },
            { Mesh = "Bespoke/Zip", MeshV = VAR, Size = V(0.12, 0.08, 0.92), Off = V(0, 0.57, 0.02) },
            { Mesh = "Bespoke/Cuff", MeshV = VAR, Size = V(1.16, 1.16, 0.2), Off = V(0, 0, -0.41) },
            { Size = V(0.04, 0.05, 0.84), Off = V(0.5, 0.12, 0.06), Color = BODY, Material = K.SMOOTH, Reflectance = 0.04 },
            { Size = V(0.04, 0.05, 0.84), Off = V(-0.5, 0.12, 0.06), Color = BODY, Material = K.SMOOTH, Reflectance = 0.04 },
            { Size = V(0.05, 0.16, 0.12), Off = V(0.5, -0.12, -0.24), Color = DARK:Lerp(BODY, 0.6), Material = K.SMOOTH },
            { Size = V(0.06, 0.08, 0.08), Off = V(0.5, -0.12, -0.24), Color = MID, Material = K.METAL, Reflectance = 0.2 },
            { Size = V(0.05, 0.16, 0.12), Off = V(-0.5, -0.12, -0.24), Color = DARK:Lerp(BODY, 0.6), Material = K.SMOOTH },
            { Size = V(0.06, 0.08, 0.08), Off = V(-0.5, -0.12, -0.24), Color = MID, Material = K.METAL, Reflectance = 0.2 },
        },
    }
end

-- ===== health bar (BARS v2, FX roll-out): the house ink frame round a strap of oxblood leather with a saddle-stitch line
-- sewn along it; every hit POPS A STITCH -- a short end of thread flicks off the lost piece and falls -- while the lost
-- leather drains away; elites / bosses wear the nickel buckle riding the end of the fill =====
Set.Bar = { Id = "Bespoke", Name = "Bespoke", Price = 149,
    Desc = "A strap of oxblood leather with a saddle-stitch line sewn along it: every hit pops a stitch, a loose end of thread flicking off where the leather drains away. On elites and bosses a nickel buckle rides the end. Part of the Bespoke set.",
    Look = "Ink", FillColor = P.Velvet:Lerp(GLOW, 0.6), ChipMotion = "Drain",
    Chip = THREAD, Back = DARK, Segments = 0, Decor = { "StitchLine", "PopStitch", "Buckle" } }
Set.BarDecor = {
    StitchLine = function(ctx: any, K: any)
        -- the saddle stitch along the middle of the fill (inside the bar, so it shows even at 84 x 8)
        local row = K.Img("bs_stitchrow", { ImageColor3 = THREAD, ScaleType = Enum.ScaleType.Tile, AnchorPoint = Vector2.new(0, 0.5), ZIndex = 6 }, ctx.Inner)
        return function(now, dt, alpha, info)
            local h = math.max(6, ctx.H * 1.2)
            row.TileSize = UDim2.fromOffset(h * 8, h)
            row.Size = UDim2.new(1, 0, 0, h)
            row.Position = UDim2.new(0, 0, 0.5, 0)
            row.ImageTransparency = 1 - alpha * 0.85
        end
    end,
    PopStitch = function(ctx: any, K: any)
        -- a popped stitch: a short thread end flicks up off the lost piece, curls and falls (two reused frames)
        local ends = {}
        for i = 1, 2 do
            local f = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = THREAD, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 13 }, ctx.Holder)
            K.New("UIStroke", { Color = P.Ink, Thickness = 1 }, f)
            ends[i] = { F = f, T = 99 }
        end
        local n = 0
        return function(now, dt, alpha, info)
            if (info.Drop or 0) > 0.004 then
                n = n % 2 + 1
                local e = ends[n]
                e.T, e.X, e.Y = 0, info.DropX1 or ctx.W * info.Shown, ctx.H / 2
                e.VX, e.VY, e.R = 20 + math.random() * 30, -30 - math.random() * 30, math.random(-30, 30)
                e.F.Visible = true
            end
            local len = math.max(4, ctx.H * 0.9)
            for _, e in ipairs(ends) do
                if e.T < 0.5 then
                    e.T += dt
                    e.VY += 220 * dt
                    e.X += e.VX * dt; e.Y += e.VY * dt; e.R += 540 * dt
                    e.F.Size = UDim2.fromOffset(len, 2)
                    e.F.Position = UDim2.fromOffset(e.X, e.Y)
                    e.F.Rotation = e.R
                    e.F.BackgroundTransparency = math.clamp(e.T / 0.5 + (1 - alpha), 0, 1)
                elseif e.F.Visible then e.F.Visible = false end
            end
        end
    end,
    Buckle = function(ctx: any, K: any)
        if ctx.Tier == "Small" then return function() end end
        local bk = K.Img("bs_buckle", { AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = MID:Lerp(C(255, 255, 255), 0.45), ZIndex = 12 }, ctx.Holder)
        return function(now, dt, alpha, info)
            local h = ctx.H * 1.5
            bk.Size = UDim2.fromOffset(h * 0.62, h)
            bk.Position = UDim2.fromOffset(ctx.W * math.max(0.02, info.Shown), ctx.H / 2)
            bk.ImageTransparency = 1 - alpha
        end
    end,
}

-- ===== UI theme v2 (FX roll-out 2026-10-14; v1 = the shared template: quilt tile + 4 corner sprites + watermark + motes +
-- a sweep -- "a recolour of the same window"). Its own pieces, in the icon look (flat faces, one hard facet, ink edges):
-- a SADDLE-STITCH seam of thread runs round the inside of every window, a stitched leather MAKER'S TAG hangs off the top
-- right corner on a thread and sways a little, every title bar gets a short stitched underline ending in a nickel button,
-- and windows open SEWN: the seam stitches itself round the window clockwise behind a bright needle glint (0.5 s).
-- Colours come from the theme table (Thread / Leather / Nickel / Accent), so colourways recolour all of it.
local function BsFacet(ctx, o, lit, shade, inkW)
    local g = Instance.new("UIGradient")
    g.Color = ctx.UIStyle.Facet(lit, shade)
    g.Rotation = ctx.UIStyle.FACET_ROT or 35
    g.Parent = o
    local ink = ctx.UIStyle.InkEdge(inkW or 2)
    ink.Parent = o
end
local function BsEdges(f, th)
    -- the four seam runs as tiled stitch rows (rotated for the sides); placed in pixels from the overlay's size
    local rows = {}
    for i = 1, 4 do
        local im = Instance.new("ImageLabel")
        im.Name = "BsSeam"; im.BackgroundTransparency = 1; im.Image = ART.bs_stitchrow; im.ScaleType = Enum.ScaleType.Tile
        im.TileSize = UDim2.fromOffset(th * 8, th); im.AnchorPoint = Vector2.new(0.5, 0.5); im.ZIndex = f.ZIndex + 1
        im.Rotation = (i % 2 == 0) and 90 or 0
        im.Parent = f
        rows[i] = im
    end
    return rows
end
local function BsLayout(f, rows, th, inset, k)
    -- k = 0..1 how much of the seam is sewn (clockwise from the top left); returns the needle's point
    local w, h = f.AbsoluteSize.X, f.AbsoluteSize.Y
    local x0, y0, x1, y1 = inset, inset, w - inset, h - inset
    local runs = { { x0, y0, 1, 0, x1 - x0 }, { x1, y0, 0, 1, y1 - y0 }, { x1, y1, -1, 0, x1 - x0 }, { x0, y1, 0, -1, y1 - y0 } }
    local total = 2 * (x1 - x0) + 2 * (y1 - y0)
    local left = math.max(0, total * k)
    local nx, ny = x0, y0
    for i, r in ipairs(runs) do
        local len = math.clamp(left, 0, r[5])
        left -= len
        local im = rows[i]
        im.Visible = len > 1
        im.Size = UDim2.fromOffset(math.max(1, len), th)
        im.Position = UDim2.fromOffset(r[1] + r[3] * len / 2, r[2] + r[4] * len / 2)
        if len > 0 then nx, ny = r[1] + r[3] * len, r[2] + r[4] * len end
    end
    return nx, ny
end
local function BsDeco(ctx)
    if ctx.Kind ~= "Window" then return nil end
    local t = ctx.Theme
    local host = ctx.Root or ctx.Surface
    local f = Instance.new("Frame")
    f.Name = "BsOverlay"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 20; f.Active = false
    f:SetAttribute("NoSkin", true); f:SetAttribute("Skinned", true)
    f.Parent = host
    local small = math.min(host.AbsoluteSize.X, host.AbsoluteSize.Y) < 260
    local th, inset = small and 10 or 14, small and 3 or 4
    local rows = BsEdges(f, th)
    for _, r in ipairs(rows) do r.ImageColor3 = t.Thread end
    f:SetAttribute("BsSewn", 1)
    -- the maker's tag: a stitched leather tag on a thread off the top right corner, with a nickel eyelet
    local tw, tl = small and 16 or 26, small and 22 or 34
    local pivot = Instance.new("Frame")
    pivot.Name = "BsTagPivot"; pivot.BackgroundTransparency = 1; pivot.AnchorPoint = Vector2.new(0.5, 0)
    pivot.Position = UDim2.new(0.64, 0, 0, 2); pivot.Size = UDim2.fromOffset(tw, tl + 10); pivot.ZIndex = f.ZIndex + 2
    pivot.Parent = f
    local thread = Instance.new("Frame")
    thread.Name = "BsTagThread"; thread.BorderSizePixel = 0; thread.BackgroundColor3 = t.Thread; thread.AnchorPoint = Vector2.new(0.5, 0)
    thread.Position = UDim2.fromScale(0.5, 0); thread.Size = UDim2.fromOffset(2, 12); thread.ZIndex = pivot.ZIndex; thread.Parent = pivot
    local tag = Instance.new("Frame")
    tag.Name = "BsTag"; tag.BorderSizePixel = 0; tag.BackgroundColor3 = Color3.new(1, 1, 1); tag.AnchorPoint = Vector2.new(0.5, 0)
    tag.Position = UDim2.new(0.5, 0, 0, 9); tag.Size = UDim2.fromOffset(tw, tl); tag.ZIndex = pivot.ZIndex + 1; tag.Parent = pivot
    BsFacet(ctx, tag, t.LeatherFace, t.LeatherShade, 2)
    local seam = Instance.new("ImageLabel")
    seam.Name = "BsTagStitch"; seam.BackgroundTransparency = 1; seam.Image = ART.bs_stitchrow; seam.ImageColor3 = t.Thread
    seam.ScaleType = Enum.ScaleType.Tile; seam.TileSize = UDim2.fromOffset(48, 6); seam.AnchorPoint = Vector2.new(0.5, 1)
    seam.Position = UDim2.new(0.5, 0, 1, -3); seam.Size = UDim2.new(1, -6, 0, 6); seam.ZIndex = tag.ZIndex + 1; seam.Parent = tag
    local eye = Instance.new("Frame")
    eye.Name = "BsEyelet"; eye.BorderSizePixel = 0; eye.BackgroundColor3 = t.Nickel; eye.AnchorPoint = Vector2.new(0.5, 0.5)
    eye.Position = UDim2.new(0.5, 0, 0, small and 6 or 9); eye.Size = UDim2.fromOffset(small and 6 or 9, small and 6 or 9); eye.ZIndex = tag.ZIndex + 1
    eye.Parent = tag
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = eye
    local ek = Instance.new("UIStroke"); ek.Color = t.Ink; ek.Thickness = 2; ek.Parent = eye
    local lastW, lastH, lastK = -1, -1, -1
    local ph = math.random() * 6.28
    return function(now, dt)
        -- the seam is laid out again only when the window changes size or while it is being sewn
        local k = f:GetAttribute("BsSewn") or 1
        local sz = f.AbsoluteSize
        local needle = f:FindFirstChild("BsNeedle")
        if sz.X ~= lastW or sz.Y ~= lastH or k ~= lastK then
            lastW, lastH, lastK = sz.X, sz.Y, k
            local nx, ny = BsLayout(f, rows, th, inset, k)
            if needle then needle.Position = UDim2.fromOffset(nx, ny); needle.Visible = k < 1 end
        end
        -- the tag sways a little on its thread
        pivot.Rotation = 4 * math.sin(now * 1.3 + ph) + 1.5 * math.sin(now * 3.1 + ph * 2)
    end, { f }
end
local function BsOpen(ctx)
    -- SEWN: the seam stitches itself round the window clockwise (0.5 s) behind a bright needle glint
    local t = ctx.Theme
    local f = ctx.Root and ctx.Root:FindFirstChild("BsOverlay")
    if not f then return end
    local needle = f:FindFirstChild("BsNeedle")
    if not needle then
        needle = Instance.new("Frame")
        needle.Name = "BsNeedle"; needle.BorderSizePixel = 0; needle.BackgroundColor3 = t.Glint; needle.AnchorPoint = Vector2.new(0.5, 0.5)
        needle.Size = UDim2.fromOffset(16, 4); needle.ZIndex = f.ZIndex + 3; needle.Parent = f
        local ink = Instance.new("UIStroke"); ink.Color = t.Ink; ink.Thickness = 1.5; ink.Parent = needle
    end
    local t0 = os.clock()
    f:SetAttribute("BsSewn", 0)
    local conn
    conn = game:GetService("RunService").RenderStepped:Connect(function()
        local k = math.clamp((os.clock() - t0) / 0.5, 0, 1)
        if not f.Parent then conn:Disconnect() return end
        f:SetAttribute("BsSewn", 1 - (1 - k) ^ 2)
        needle.Rotation = (os.clock() - t0) * 900
        if k >= 1 then conn:Disconnect(); f:SetAttribute("BsSewn", 1); needle.Visible = false end
    end)
end
local function BsTitle(ctx)
    -- a short stitched underline from the left ending in a nickel button
    local bar, t = ctx.Title, ctx.Theme
    local row = Instance.new("ImageLabel")
    row.Name = "BsTitleStitch"; row.BackgroundTransparency = 1; row.Image = ART.bs_stitchrow; row.ImageColor3 = t.Thread
    row.ScaleType = Enum.ScaleType.Tile; row.TileSize = UDim2.fromOffset(80, 10); row.AnchorPoint = Vector2.new(0, 1)
    row.Position = UDim2.new(0, 10, 1, 1); row.Size = UDim2.new(0.28, 0, 0, 10); row.ZIndex = bar.ZIndex + 1; row.Parent = bar
    local btn = Instance.new("Frame")
    btn.Name = "BsButton"; btn.BorderSizePixel = 0; btn.BackgroundColor3 = t.Nickel; btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.Position = UDim2.new(0.28, 18, 1, -4); btn.Size = UDim2.fromOffset(9, 9); btn.ZIndex = bar.ZIndex + 1; btn.Parent = bar
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = btn
    local ink = Instance.new("UIStroke"); ink.Color = t.Ink; ink.Thickness = 1.5; ink.Parent = btn
    return { row, btn }
end
-- numbers v3 (SKIN UI 2026-10-28, owner: numbers "unique to the skin and the colorways you have equipped"): ENGRAVED. The
-- number is an engraver's italic serif in the colourway's thread colour, PRESSED into place like a stamp into leather (a
-- quick press, then it rises slowly), and the set's GLINT -- the highlight that glides over the engraved nickel -- sweeps
-- across the digits on every hit. CRIT = a cut jewel (the gun's rosette stone) is pinned in front of the number, which turns
-- jewel-coloured and sits at a slight tilt; WEAK SPOT = a cross-stitch in front; a KILL = a ring of stitches zips round the
-- number clockwise (the TAILORED finisher) and the jewel flares. No line under it. Every colour is this copy's palette P.
local BS_RING = 12
local function BsMotion(e, age, pa, life)
    local press = math.min(1, pa / 0.1)
    local scale = 1 + 0.16 * (e.BumpAmp or 1) * (1 - press) ^ 2
    local up = 0.3 + 1.0 * (1 - (1 - math.min(1, age / 0.9)) ^ 3)
    local tilt = (e.Crit and not e.Dot) and (-4 - 3 * math.exp(-age * 7)) or 0
    return up, 0, scale, 0, 0, tilt
end
local function BsAccent(e)
    local box = Instance.new("Frame")
    box.Name = "BsEngrave"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 2
    -- the glint: a copy of the digits in the glint colour, shown only through a narrow moving band
    local gl = Instance.new("TextLabel")
    gl.Name = "Glint"; gl.BackgroundTransparency = 1; gl.Size = UDim2.fromScale(1, 1); gl.ZIndex = 3
    gl:SetAttribute("KeepFont", true); gl.Parent = box
    local g = Instance.new("UIGradient")
    g.Rotation = 20
    g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.1),
        NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) })
    g.Parent = gl
    -- the jewel: a cut stone (a turned square, a light facet, an ink edge)
    local j = Instance.new("Frame")
    j.Name = "Jewel"; j.BorderSizePixel = 0; j.AnchorPoint = Vector2.new(0.5, 0.5); j.Rotation = 45; j.Size = UDim2.fromOffset(11, 11); j.ZIndex = 4
    local jk = Instance.new("UIStroke"); jk.Thickness = 1.5; jk.Parent = j
    local fac = Instance.new("Frame")
    fac.Name = "Facet"; fac.BorderSizePixel = 0; fac.Position = UDim2.fromOffset(1, 1); fac.Size = UDim2.fromOffset(4, 4); fac.ZIndex = 5; fac.Parent = j
    j.Parent = box
    -- the kill ring: stitches round the number
    for i = 1, BS_RING do
        local d = Instance.new("Frame")
        d.Name = "St" .. i; d.BorderSizePixel = 0; d.AnchorPoint = Vector2.new(0.5, 0.5); d.Size = UDim2.fromOffset(7, 2); d.ZIndex = 3
        d.Parent = box
    end
    return box
end
local function BsAccentStep(e, box, age, pa, alpha)
    local lbl = e.Label
    local tb = lbl.TextBounds
    local gl = box:FindFirstChild("Glint")
    if gl then
        if gl.Text ~= lbl.Text then gl.Text = lbl.Text end
        if gl.FontFace ~= lbl.FontFace then gl.FontFace = lbl.FontFace end
        gl.TextSize = lbl.TextSize
        local k = math.clamp((pa - 0.04) / 0.32, 0, 1) -- (each hit: the glint glides across once)
        gl.TextColor3 = P.Glint
        gl.TextTransparency = (k >= 1) and 1 or alpha
        local g = gl:FindFirstChildOfClass("UIGradient")
        if g then g.Offset = Vector2.new(-0.75 + 1.5 * k, 0) end
    end
    local kill = (e.Killed and e.KillAt) and (os.clock() - e.KillAt) or nil
    local j = box:FindFirstChild("Jewel")
    if j then
        local on = (e.Crit or kill ~= nil) and not e.Dot
        j.Visible = on
        if on then
            local flare = kill and math.max(0, 1 - kill / 0.45) or 0
            local s = math.floor(11 + 5 * flare + 3 * math.max(0, 1 - pa / 0.12))
            j.Size = UDim2.fromOffset(s, s)
            j.Position = UDim2.new(0.5, -math.floor(tb.X / 2) - 9, 0.5, 0)
            j.BackgroundColor3 = P.Glow:Lerp(P.Hot, flare)
            j.BackgroundTransparency = alpha
            local st = j:FindFirstChildOfClass("UIStroke"); if st then st.Color = P.Ink; st.Transparency = alpha end
            local fac = j:FindFirstChild("Facet"); if fac then fac.BackgroundColor3 = P.Hot; fac.BackgroundTransparency = math.clamp(alpha + 0.15, 0, 1) end
        end
    end
    -- the ring of stitches zips round clockwise from the top on a kill
    local n = kill and math.floor(math.clamp(kill / 0.3, 0, 1) * BS_RING + 0.5) or 0
    local rx, ry = tb.X / 2 + 14, tb.Y / 2 + 9
    for i = 1, BS_RING do
        local d = box:FindFirstChild("St" .. i)
        if d then
            local on = i <= n
            d.Visible = on
            if on then
                local a = -math.pi / 2 + (i - 0.5) / BS_RING * math.pi * 2
                d.Position = UDim2.new(0.5, math.cos(a) * rx, 0.5, math.sin(a) * ry)
                d.Rotation = math.deg(math.atan2(math.cos(a) * ry, -math.sin(a) * rx)) + 180
                d.BackgroundColor3 = P.Thread; d.BackgroundTransparency = alpha
            end
        end
    end
end
-- ===== UI THEME v4 (SKIN UI THEMES 2026-10-29 roll-out, owner: themes must "change up the colorways and provide a bit more
-- style than the default", no stretched header art): the clean language in this colourway's leather (UITheme Clean: roles
-- from P) + two touches of a gunmaker's case. Hooks read only the palette they are given (a colourway copy shares them):
--   TAB MARK  a SADDLE STITCH: the underline is four long stitches of thread (a dashed gradient, no extra frames), and the
--             selected tab's thread sews itself in again every ~7 s (Sig's tick slides the stitches in from the left)
--   FIELD     a saddle-stitch seam runs round the inside of the screen, like the lining of a gun case, and an engraved nickel
--             MAKER'S PLATE sits in the lower right with the set's rose jewel; the engraving's glint glides across it
local BS_CLEAN = {
    Field = P.Dark:Lerp(P.Ink, 0.4), Surface = P.Dark:Lerp(P.Body, 0.24), Raised = P.Dark:Lerp(P.Body, 0.44), Hover = P.Body:Lerp(P.Dark, 0.28):Lerp(P.Mid, 0.1),
    Well = P.Ink:Lerp(P.Dark, 0.5), Line = P.Dim:Lerp(P.Dark, 0.4), Tip = P.Dark:Lerp(P.Body, 0.16),
    Accent = P.Glow, Mark = P.Thread, Hair = P.Thread:Lerp(P.Mid, 0.45),
    Text = P.Text, Sub = P.Thread:Lerp(P.Mid, 0.42), Muted = P.Mid:Lerp(P.Thread, 0.3), Ink = P.Ink,
    Thread = P.Thread, Nickel = P.Mid:Lerp(C(255, 255, 255), 0.5), Jewel = P.Glow, JewelHot = P.Hot, Glint = P.Glint, InkLine = P.Ink,
}
local function BsStitches(n, duty)
    -- a transparency sequence of n hard-edged stitches (<= 20 keypoints: n <= 4)
    local kp = { NumberSequenceKeypoint.new(0, 1) }
    for i = 0, n - 1 do
        local a = (i + (1 - duty) / 2) / n
        local b = a + duty / n
        table.insert(kp, NumberSequenceKeypoint.new(a, 1)); table.insert(kp, NumberSequenceKeypoint.new(a + 0.002, 0))
        table.insert(kp, NumberSequenceKeypoint.new(b, 0)); table.insert(kp, NumberSequenceKeypoint.new(b + 0.002, 1))
    end
    table.insert(kp, NumberSequenceKeypoint.new(1, 1))
    return NumberSequence.new(kp)
end
local BS_STITCH = BsStitches(4, 0.68)
BS_CLEAN.TabMark = function(mark, Q)
    -- (a gradient, not child frames: tab buttons size themselves to their children)
    local g = Instance.new("UIGradient")
    g.Name = "BsStitch"; g.Transparency = BS_STITCH
    g.Parent = mark
    return { g }
end
BS_CLEAN.Sig = function(ctx)
    local Q, f = ctx.P, ctx.Frame
    local made = {}
    -- the seam: four tiled stitch rows (the sides turned), laid out again only when the field changes size
    local rows = {}
    for i = 1, 4 do
        local im = Instance.new("ImageLabel")
        im.Name = "BsSeam"; im.BackgroundTransparency = 1; im.Image = ART.bs_stitchrow; im.ScaleType = Enum.ScaleType.Tile
        im.TileSize = UDim2.fromOffset(64, 8); im.AnchorPoint = Vector2.new(0.5, 0.5); im.ImageColor3 = Q.Thread; im.ImageTransparency = 0.55
        im.Rotation = (i % 2 == 0) and 90 or 0; im.ZIndex = 0; im.Parent = f
        rows[i] = im
    end
    -- the maker's plate: engraved nickel (Fit: the art keeps its 160 x 64 shape), the set's name engraved, the jewel set in it
    local plate = Instance.new("ImageLabel")
    plate.Name = "BsPlate"; plate.BackgroundTransparency = 1; plate.Image = ART.bs_plate; plate.ScaleType = Enum.ScaleType.Fit
    plate.ImageColor3 = Q.Nickel; plate.ImageTransparency = 0.1; plate.AnchorPoint = Vector2.new(1, 1); plate.Size = UDim2.fromOffset(130, 52)
    plate.ClipsDescendants = true; plate.ZIndex = 0; plate.Parent = f
    local word = Instance.new("TextLabel")
    word.Name = "BsMaker"; word.BackgroundTransparency = 1; word.Text = "Bespoke"; word.TextSize = 19; word.TextColor3 = Q.InkLine
    word.TextTransparency = 0.25; word.Position = UDim2.fromOffset(42, 0); word.Size = UDim2.new(1, -54, 1, 0); word.ZIndex = 1
    word.FontFace = Font.new("rbxasset://fonts/families/AccanthisADFStd.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
    word:SetAttribute("NoSnap", true); word:SetAttribute("KeepFont", true); word:SetAttribute("TextRole", "Glyph"); word.Parent = plate
    local jewel = Instance.new("Frame")
    jewel.Name = "BsJewel"; jewel.BorderSizePixel = 0; jewel.BackgroundColor3 = Q.Jewel; jewel.AnchorPoint = Vector2.new(0.5, 0.5); jewel.Rotation = 45
    jewel.Position = UDim2.new(0, 30, 0.5, 0); jewel.Size = UDim2.fromOffset(12, 12); jewel.ZIndex = 1; jewel.Parent = plate
    local jk = Instance.new("UIStroke"); jk.Color = Q.InkLine; jk.Thickness = 1.5; jk.Parent = jewel
    local jf = Instance.new("Frame")
    jf.BorderSizePixel = 0; jf.BackgroundColor3 = Q.JewelHot; jf.Position = UDim2.fromOffset(1, 1); jf.Size = UDim2.fromOffset(4, 4); jf.ZIndex = 2; jf.Parent = jewel
    local glint = Instance.new("Frame")
    glint.Name = "BsGlint"; glint.BorderSizePixel = 0; glint.BackgroundColor3 = Q.Glint; glint.BackgroundTransparency = 0.6; glint.AnchorPoint = Vector2.new(0.5, 0.5)
    glint.Rotation = 22; glint.Size = UDim2.new(0, 4, 1.6, 0); glint.Position = UDim2.new(-0.2, 0, 0.5, 0); glint.ZIndex = 3; glint.Parent = plate
    local lastW, lastH = -1, -1
    local seed = math.random() * 5
    return function(now, _dt)
        local sz = f.AbsoluteSize
        if sz.X ~= lastW or sz.Y ~= lastH then
            lastW, lastH = sz.X, sz.Y
            local topY = 70
            if ctx.Top then topY = ctx.Top.AbsolutePosition.Y - f.AbsolutePosition.Y + ctx.Top.AbsoluteSize.Y + 6 end
            local x0, x1, y0, y1 = 8, sz.X - 8, topY, sz.Y - 8
            rows[1].Position = UDim2.fromOffset((x0 + x1) / 2, y0); rows[1].Size = UDim2.fromOffset(x1 - x0, 8)
            rows[3].Position = UDim2.fromOffset((x0 + x1) / 2, y1); rows[3].Size = UDim2.fromOffset(x1 - x0, 8)
            rows[2].Position = UDim2.fromOffset(x1, (y0 + y1) / 2); rows[2].Size = UDim2.fromOffset(y1 - y0, 8)
            rows[4].Position = UDim2.fromOffset(x0, (y0 + y1) / 2); rows[4].Size = UDim2.fromOffset(y1 - y0, 8)
            plate.Position = UDim2.fromOffset(x1 - 12, y1 - 12)
        end
        -- the glint glides across the plate every ~5 s (jewellery catching lamplight)
        local k = ((now + seed) % 5.2) / 0.7
        glint.Visible = k < 1
        if k < 1 then glint.Position = UDim2.new(-0.15 + 1.3 * k, 0, 0.5, 0) end
        -- the selected tab's thread sews itself in again every ~7 s
        local s = ((now + seed) % 7) / 0.6
        for _, m in ipairs(ctx.Marks()) do
            local g = m.Visible and m:FindFirstChild("BsStitch")
            if g then g.Offset = Vector2.new((s < 1) and (-1 + (1 - (1 - s) ^ 2)) or 0, 0) end
        end
    end, made
end
local P1 = PALETTES[1]
Set.Theme = { Name = "Bespoke", Desc = "A gunmaker's case in every window: a saddle-stitch seam runs round the inside of the screen, the tabs are stitched in thread, and an engraved nickel maker's plate with a rose jewel catches the light in the corner.",
    Panel = { Top = C(44, 16, 22), Bottom = C(16, 6, 9) }, Card = { Top = C(56, 20, 28), Bottom = C(24, 8, 12) }, Title = { Top = C(112, 34, 46), Bottom = C(48, 12, 20) },
    Accent = C(230, 200, 170), Accent2 = P1.Glow, HpFill = C(200, 60, 80), HpBg = C(30, 8, 12), XpFill = C(230, 200, 170), Text = C(245, 225, 215),
    Thread = P1.Thread, LeatherFace = P1.Velvet:Lerp(C(255, 255, 255), 0.12), LeatherShade = P1.Velvet:Lerp(C(0, 0, 0), 0.45), Nickel = C(196, 196, 204),
    Glint = P1.Glint, Ink = P1.Ink,
    Tex = "tex_bs_quilt", TexT = 0.88, TexTile = 220, TexScroll = Vector2.new(0, 0), Emblem = "EmblemBespoke", BorderThick = 2,
    Deco = BsDeco, OpenFn = BsOpen, TitleDeco = BsTitle,
    Clean = BS_CLEAN, -- (SKIN UI THEMES: the clean palette + saddle-stitch tab marks + the case seam and maker's plate; the old art is not drawn)
    -- (SKIN UI 2026-10-29: engraved -- pressed in, a glint across the digits, a jewel on crits, stitches round a kill; this colourway's P)
    Numbers = { Font = "AccanthisADFStd", Italic = true, Glyph = "✚", NoBang = true, Motion = BsMotion, Accent = BsAccent, AccentStep = BsAccentStep,
        Normal = P.Thread, Crit = P.Glow, Weak = P.Hot, Stroke = P.Ink, StrokeThick = 2, Size = 1.1 } }

-- ===== kill effect / bundle / store hero =====
Set.KillEffect = { Id = "Tailored", Name = "Tailored", Image = ART.EmblemBespoke,
    How = "Own any Bespoke skin (or the Bespoke bundle)",
    Desc = "The enemy is taken in by the tailor: the body folds down layer by layer into a stack of velvet on the floor, a big nickel needle races round it trailing glowing thread, sews a ring of stitches, pulls them tight, and it all sinks away. With the Bespoke stitched tag banner." }
Set.Bundle = { Id = "BespokeBundle", Name = "Bespoke Bundle", Price = 2199, BP = 799, ProductId = 0,
    Desc = "The whole Bespoke set: the Bespoke Desert Eagle, Double Barrel and M40, the Bespoke Stiletto, Driving Gloves and Bespoke Leather Sleeves, the Bespoke health bar and the Tailored kill effect.",
    Contents = { "WeaponSkin:BespokeDEAGLE", "WeaponSkin:BespokeDBARREL", "WeaponSkin:BespokeM40", "MeleeSkin:Bespoke", "Glove:DrivingGloves", "Sleeve:BespokeSleeves", "HealthBar:Bespoke", "KillEffect:Tailored" } }
Set.Hero = { Grad = { C(70, 18, 28), C(16, 6, 9) }, Stroke = C(230, 200, 170), Emblem = ART.EmblemBespoke, Name = C(250, 228, 212), Chip = C(120, 34, 48) }

return Set
