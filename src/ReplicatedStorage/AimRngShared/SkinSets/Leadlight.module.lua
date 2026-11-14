--!nocheck
-- ===================================================================================================================
-- LEADLIGHT (Skins V3, bundle 16 of docs/SKINS_V3_PLAN.md; SKINS BUILDER 10 "skins10"): 21E (HK21) + SR9 + Helios Beam
-- (ContinuousLaser) | Lancet Sword | 999 BP. STAINED GLASS GUNS (v8, the owner: "the entire barrel and parts of the guns
-- to be glass", "see-through"): the barrel is a leaded-glass TUBE (a pewter bore liner seen through it), the receiver side,
-- stock and ammo box are leaded glass in a thin iron skeleton. The ROBLOX RECIPE (proven in game, not just in a render):
-- see-through coloured SmoothPlastic panes (Clear parts ~0.55, never the Glass material), thick dark came standing proud,
-- NO Neon behind the glass (a v7 lit core blew the panes out into orange stripes in Roblox); the tube top is darker + less
-- see-through (the sight line). Neon only for the small cabochons (no glass flash: owner).
-- The guns are RESCULPTED models (WeaponAssets.SkinModels.Leadlight_<GUN>, tools/skins_v3/leadlight_v8.py, layouts from
-- tools/skins_v3/leadlight_cells.py, painted by tools/skin_v3_paint.py with tools/skins_v3/leadlight.json).
--   FIRE     the cabochons glint (the glass itself never flashes: owner)
--   ALIVE    the cabochons twinkle now and then
-- Muzzle: a warm flash + a small two-tone prism flare. Tracer: a soft warm light line with a prism glint at its head.
-- Impact: two or three coloured light dapples + a glass flake. Kill ASCENSION: a column of stained-glass light shafts rises
-- from the shoulders (never at body-centre height: the crosshair), a cross of light flaring above the head and small
-- crosses drifting up (1.5 s; low = the column + one cross). Banner: a leaded strip with five cabochons that light one per kill and shimmer at five.
-- ===================================================================================================================
local Set = { Kind = "Leadlight" }

local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local V = Vector3.new
-- (each colourway: four related glass tones T1 deep -> T4 light, the jewel, the core light behind the glass)
local PALETTES = {
    { Name = "Hearthglow", T1 = C(96, 8, 20), T2 = C(168, 24, 26), T3 = C(240, 112, 22), T4 = C(255, 182, 64), Jewel = C(210, 20, 52),
      Core = C(255, 150, 62), CoreHot = C(255, 214, 150), Lume = C(255, 170, 50), Pewter = C(150, 148, 150), Iron = C(46, 43, 48),
      Plate = C(16, 14, 18), Text = C(250, 236, 214) },
    { Name = "Evensong", T1 = C(18, 22, 88), T2 = C(62, 40, 142), T3 = C(112, 92, 204), T4 = C(244, 176, 74), Jewel = C(244, 172, 60),
      Core = C(196, 170, 255), CoreHot = C(236, 226, 255), Lume = C(200, 180, 255), Pewter = C(150, 152, 162), Iron = C(40, 42, 50),
      Plate = C(12, 13, 20), Text = C(232, 234, 250) },
    { Name = "Verdigris", T1 = C(6, 60, 40), T2 = C(20, 112, 82), T3 = C(64, 172, 124), T4 = C(232, 192, 84), Jewel = C(232, 170, 40),
      Core = C(190, 255, 200), CoreHot = C(236, 255, 236), Lume = C(170, 255, 200), Pewter = C(146, 156, 150), Iron = C(40, 48, 44),
      Plate = C(10, 16, 13), Text = C(230, 248, 236) },
}
local P = PALETTES[VAR] or PALETTES[1]
local LUME, HOT = P.Lume, P.CoreHot
Set.Palettes = PALETTES
Set.Colors = { Glow = LUME, Hot = HOT, Accent = P.Pewter, Mid = P.Pewter }
local TONE = { T1 = P.T1, T2 = P.T2, T3 = P.T3, T4 = P.T4, Jewel = P.Jewel, Core = P.Core, Amber = P.T4 }
local A = "rbxassetid://"
Set.Art = {   -- (IMAGE ids, resolved in Studio from the decal uploads in tools/skins_v3/leadlight_ids.json)
    EmblemLeadlight = A .. "93229138325385", ll_emblem = A .. "93229138325385", ll_emblem_mask = A .. "139343698585752",
    ll_flake = A .. "122806961781138", ll_dapple = A .. "104758486450169", ll_flare = A .. "133452174226697", ll_corner = A .. "124318055371329",
    ll_plate = A .. "112334678383150", ll_seg = A .. "118168915033971", tex_ll_bar = A .. "87532326885153",
    tex_ll_leather = A .. "84761484916544", tex_ll_tweed = A .. "90780486790360",
}
local ART = Set.Art
local function Tex(key: string, fallback: string): string
    local t = ART[key]
    return (t and t ~= "") and t or fallback
end

local TAU = math.pi * 2
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function bump(x, w) return math.max(0, 1 - math.abs(x) / w) end

local function GunDesc(gun: string): string
    local what = (gun == "SR9") and "the whole slide (flanks, rounded top and rear face) is see-through stained glass with pewter serration bars, and the frame and grip carry leaded panels"
        or (gun == "ContinuousLaser") and "the forward body is a see-through glass box round the glowing emitter, the rear body wears a leaded glass canopy, and the lantern, stock and magazine are glass too"
        or "the barrel is a stained-glass tube, and the receiver side, the stock and the ammo box are bodies of stained glass"
    return "Art-nouveau leaded glass: " .. what .. ". Long curved leads flow toward the muzzle through mottled panes in four warm tones you can see the world through; heavy black came, iron rims and pewter collars hold it together, and round cabochons glint. Every kill is an ASCENSION."
end

-- ===== the guns =====
Set.GunSkins = {
    { Id = "LeadlightHK21", Name = "Leadlight 21E", Gun = "HK21", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("HK21"),
      Model = "Leadlight_HK21", V3 = true, Color = LUME, Color2 = P.T3, Deco = "LeadlightGun", Fit = { G = "HK21", N = 6 } },
    { Id = "LeadlightSR9", Name = "Leadlight P99", Gun = "SR9", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("SR9"),
      Model = "Leadlight_SR9", V3 = true, Color = LUME, Color2 = P.T3, Deco = "LeadlightGun", Fit = { G = "SR9", N = 3 } },
    { Id = "LeadlightHelios", Name = "Leadlight Helios Beam", Gun = "ContinuousLaser", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("ContinuousLaser"),
      Model = "Leadlight_ContinuousLaser", V3 = true, Color = LUME, Color2 = P.T3, Deco = "LeadlightGun", Fit = { G = "ContinuousLaser", N = 3 },
      BeamColor = P.T4 },
}

-- the glass takes the colourway: Clear panes = tone x shade (transparency from the import), Neon parts with a Tone = the tone
local function Tint(root: Instance)
    for _, p in ipairs(root:GetDescendants()) do
        if p:IsA("BasePart") then
            local tone = p:GetAttribute("Tone")
            local col = tone and TONE[tone]
            if col then
                local sh = p:GetAttribute("Shade") or 1
                if sh ~= 1 then col = Color3.new(math.clamp(col.R * sh, 0, 1), math.clamp(col.G * sh, 0, 1), math.clamp(col.B * sh, 0, 1)) end
                p.Color = col
                p.CastShadow = false
                if p:GetAttribute("Clear") then p.Reflectance = 0 end
            end
        end
    end
end
Set.Build = {}
Set.Build.LeadlightGun = function(model: Model, frame: BasePart, f: any, forView: boolean, H: any)
    Tint(model)
end

-- ===== sounds (tools/skins_v3/leadlight_sfx.py: each gun's own recorded shot + a low glass clink + a soft hall tail; every
-- moment from CC0 recordings, all through tools/audio_screen.py) =====
Set.Sounds = {
    Fire = { Id = 0, Volume = 0 }, Equip = { Id = 81315174785551, Volume = 0.4 }, MagOut = { Id = 84046727935745, Volume = 0.36 },
    MagIn = { Id = 95719410614772, Volume = 0.36 }, Kill = { Id = 137706595886300, Volume = 0.5 }, Impact = { Id = 109367918410754, Volume = 0.2 },
    Swing = { Id = 128452069396515, Volume = 0.38 }, MeleeHit = { Id = 99227304830792, Volume = 0.42 }, Sweep = { Id = 102788446416866, Volume = 0.22 },
    Draw = { Id = 78615284422178, Volume = 0.4 },
    -- (each gun's own full shot; the SR9's was quietened 4.9 dB by the screen, so its volume is raised to match)
    FireGun = { HK21 = { Id = 119160613247479, Volume = 0.72 }, SR9 = { Id = 100697982083532, Volume = 0.95 },
        ContinuousLaser = { Id = 136788415148966, Volume = 0.6 } },
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
    H.Debris:AddItem(s, 3)
end

-- ===== motion: Sweep1..N (the glass bands grip -> muzzle), Jewel (the cabochons), Fuller1..5 (the sword) =====
local function SweepKeys(st: any, v: any, now: number, n: number, anim: string?, animT: number?)
    local ss = st.SinceShot or 99
    local se = st.SinceEquip or 99
    local rl = st.Reload or 0
    for b = 1, 6 do
        local x = (b - 1) / math.max(1, n - 1)
        -- rest: the core breathes (light behind glass), a little out of step band to band
        local g = 0.2 + 0.07 * math.sin(now * TAU / 3.2 + b * 0.9)
        -- fire: a light sweep runs grip -> muzzle
        g = math.max(g, 0.95 * bump(ss - 0.03 - x * 0.09, 0.07))
        -- equip: the panes light one by one from the grip outward, then settle
        if se < 1.2 then g = (se > 0.12 + x * 0.55) and math.max(g, 0.8 * (1 - smooth((se - 0.12 - x * 0.55) / 0.5))) or 0.03 end
        -- reload: dim while the magazine is out, relight band by band as it seats
        if rl > 0.1 and rl < 0.62 then g = 0.05 end
        if rl >= 0.62 and rl < 0.98 then g = (smooth((rl - 0.62) * 8 - x * 1.5) > 0.5) and g or 0.05 end
        -- inspect: a slow wave along the glass and back on the Present beat
        if anim == "Inspect" and animT then
            local t = animT - (v.Present or 0.6)
            if t > 0 and t < 1.8 then
                local head = (t < 0.9) and (t / 0.9) or (1 - (t - 0.9) / 0.9)
                g = math.max(g, 0.85 * bump(x - head, 0.35))
            end
        end
        st["Sweep" .. b] = math.clamp(g, 0, 1)
    end
    local tw = (now % 3.4) / 3.4
    st.Jewel = math.clamp(0.4 + 0.5 * bump(tw - 0.5, 0.06) + ((ss < 0.12) and 0.3 or 0), 0, 1)
end
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    local v = rig.SkinVars
    local an, at = rig.AnimName, rig.AnimTime
    if rig.Def and rig.Def.IsMelee then
        -- the sword's fuller panes: breathe at rest, a wave grip -> tip on every swing, a slow wave on the inspect
        local sw = st.SinceSwing or st.SinceShot or 99
        for k = 1, 5 do
            local x = (k - 1) / 4
            local g = 0.28 + 0.06 * math.sin(now * TAU / 2.8 + k)
            g = math.max(g, 0.9 * bump(sw - 0.02 - x * 0.08, 0.08))
            if an == "Inspect" and at then g = math.max(g, 0.85 * bump(x - ((at * 0.7) % 1.4), 0.3)) end
            st["Fuller" .. k] = math.clamp(g, 0, 1)
        end
        st.Jewel = math.clamp(0.45 + 0.45 * bump((now % 3.4) / 3.4 - 0.5, 0.06), 0, 1)
        return
    end
    if an == "Inspect" and rig.Anim and rig.Anim.Beats then v.Present = rig.Anim.Beats.Present or v.Present end
    local n = (rig.GunId == "HK21") and 6 or 3
    SweepKeys(st, v, now, n, an, at)
    -- (owner 2026-10-12: "I don't like the flashing glass when you fire" -- the panes never flash; only the cabochons
    -- glint on a shot, via st.Jewel in SweepKeys)
end
Set.OnEvent = function(rig: any, name: string, H: any, data: any)
    if name == "Present" then
        PlaySound(H, Set.Sounds.Sweep, 1.0)
    elseif name == "MagIn" then
        PlaySound(H, Set.Sounds.Sweep, 1.12)
    end
    if rig.Def and rig.Def.IsMelee and name == "Raise" then PlaySound(H, Set.Sounds.Draw, 1.0) end
end
Set.OnEquip = function(rig: any, H: any)
    if rig.Def and rig.Def.IsMelee then PlaySound(H, Set.Sounds.Draw, 1.0) end
    if not Set._Preloaded then
        Set._Preloaded = true
        task.spawn(function()
            local list = {}
            for _, k in ipairs({ "ll_flare", "ll_dapple", "ll_flake", "ll_emblem", "ll_plate", "ll_seg" }) do
                if ART[k] ~= "" then table.insert(list, ART[k]) end
            end
            pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
        end)
    end
end
-- other players' guns: the cores breathe
Set.World = function(rec: any, now: number, st: any)
    local v = rec.Vars
    st.SinceShot = 99; st.SinceEquip = 99; st.Reload = 0
    SweepKeys(st, v, now, 6, nil, nil)
    for k = 1, 5 do st["Fuller" .. k] = 0.3 end
end

-- ===== muzzle: a warm flash + one small two-tone prism flare card =====
Set.Muzzle = function(rig: any, flash: ParticleEmitter, light: PointLight, muzzle: Attachment, H: any)
    flash.Color = ColorSequence.new(HOT, LUME)
    flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.03) })
    light.Color = LUME
    light.Brightness = 0.6
    rig.Fx.LlFlare = H.Emitter(muzzle, { Name = "LlFlare", Texture = Tex("ll_flare", H.SPARK), Color = { C(255, 255, 255), C(255, 240, 220) }, Size = { 0.22, 0.08 },
        Life = { 0.06, 0.09 }, Speed = { 0, 0 }, Spread = 0, Trans = { 0.1, 1 }, Light = 1, Rate = 0 })
    rig.Fx.LlFlare.Rotation = NumberRange.new(-20, 20)
end
Set.OnFire = function(rig: any, H: any)
    if rig.Fx and rig.Fx.LlFlare then rig.Fx.LlFlare:Emit(1) end
end

-- ===== tracer: a soft warm light line with a prism glint at its head =====
Set.Tracer = function(H: any, from: Vector3, to: Vector3, peer: boolean?)
    local dist = (to - from).Magnitude
    if dist < 1.5 then return end
    local host = H.FxPart({ Transparency = 1, Size = V(0.05, 0.05, 0.05), CFrame = CFrame.new(from) })
    local a0, a1 = H.Att(host, from), H.Att(host, to)
    local core = Instance.new("Beam")
    core.Attachment0, core.Attachment1 = a0, a1
    core.Color = ColorSequence.new(P.T4, P.T2); core.LightEmission = 1; core.LightInfluence = 0; core.FaceCamera = true; core.Segments = 1
    core.Width0, core.Width1 = 0.012, peer and 0.028 or 0.038
    core.Parent = host
    local head = Instance.new("BillboardGui")
    head.Size = UDim2.fromScale(peer and 0.35 or 0.5, peer and 0.35 or 0.5); head.LightInfluence = 0
    local img = Instance.new("ImageLabel"); img.BackgroundTransparency = 1; img.Size = UDim2.fromScale(1, 1); img.Image = Tex("ll_flare", H.Art.Glow or "")
    img.Parent = head
    local hp = H.FxPart({ Transparency = 1, Size = V(0.05, 0.05, 0.05), CFrame = CFrame.new(from) })
    head.Adornee = hp; head.Parent = hp
    local dir = (to - from).Unit
    local travel = H.TRAVEL -- (hitscan: the shot is there at once, nothing flies)
    local dur = travel + 0.28
    H.Animate(dur, function(t)
        local hk = math.clamp(t / travel, 0, 1)
        local p = from + dir * dist * hk
        a1.WorldPosition = p
        hp.CFrame = CFrame.new(p)
        img.Rotation = t * 300
        local after = math.max(0, t - travel) / (dur - travel)
        core.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7 + 0.3 * after), NumberSequenceKeypoint.new(1, math.clamp(0.1 + after * 1.6, 0, 1)) })
        img.ImageTransparency = math.clamp(0.1 + after * 1.2, 0, 1)
    end, function() host:Destroy(); hp:Destroy() end)
end

-- ===== impact: two or three coloured light dapples on the surface (light through glass) + a small glass flake =====
Set.Impact = function(H: any, pos: Vector3, normal: Vector3?, peer: boolean?)
    if not H.Budget("LeadlightImpact", peer and 3 or 8, 0.5) then return end
    local n = (normal and normal.Magnitude > 0.1) and normal.Unit or V(0, 1, 0)
    local cols = { P.T4, P.T2, P.T3 }
    local parts = {}
    for k = 1, peer and 2 or 3 do
        local off = (CFrame.lookAt(V(), n) * CFrame.new(math.random() * 0.24 - 0.12, math.random() * 0.24 - 0.12, 0)).Position
        local face = CFrame.lookAt(pos + n * (0.02 + k * 0.003) + off, pos + n * 2 + off) * CFrame.Angles(0, 0, math.random() * TAU)
        local p = H.FxPart({ Transparency = 1, Size = V(0.2, 0.2, 0.02), CFrame = face })
        local d = Instance.new("Decal")
        d.Texture = Tex("ll_dapple", ""); d.Face = Enum.NormalId.Front; d.Color3 = cols[k]; d.Transparency = 0.15
        d.Parent = p
        table.insert(parts, { P = p, D = d })
    end
    local att = H.Att(parts[1].P, pos + n * 0.03)
    local em = H.Emitter(att, { Name = "LlFlake", Texture = Tex("ll_flake", H.SPARK), Color = { P.T4, P.T2 }, Size = { 0.05, 0.03 }, Life = { 0.25, 0.4 },
        Speed = { 1.4, 2.8 }, Spread = 40, Trans = { 0.1, 1 }, Light = 0.4, Drag = 3 })
    em.EmissionDirection = Enum.NormalId.Front
    em:Emit(peer and 1 or 2)
    H.Animate(0.6, function(t)
        local k = t / 0.6
        for i, it in ipairs(parts) do
            local s = 0.12 + (0.28 + i * 0.05) * (1 - (1 - math.min(1, k * 2.5)) ^ 3)
            it.P.Size = V(s, s, 0.02)
            it.D.Transparency = math.clamp(0.15 + math.max(0, k - 0.3) * 1.3, 0, 1)
        end
    end, function() for _, it in ipairs(parts) do it.P:Destroy() end end)
end

-- ===== STAINED GLASS kill (FX roll-out 2026-10-14; v1 "Ascension" = a pale light column + cross flares over the head --
-- the generic "beam of light", clipped white, scored 2). ONE idea: the enemy BECOMES A LEADED WINDOW. Its body is redrawn
-- as a panel of diamond quarries in the set's jewel tones, each pane lit from within and bound in dark lead came (the ink
-- backing: it reads on a bright floor and a dark one); a white crack runs through the leads on the beat (0.2 s) and the
-- panes fall out of the window one by one, tumbling down and outward, and shatter into glints where they hit the floor.
-- 1.3 s. Motion is DOWN and OUT. Budget: full <= 12 panes + 1 glint host (<= 24 sprites); low: 4 panes, no glints. =====
local function LlBody(pos: Vector3, H: any): (CFrame, Vector3)
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
    if best then
        local ok, cf, size = pcall(function() return best:GetBoundingBox() end)
        if ok and size.Magnitude < 20 then return cf, size end
    end
    return CFrame.new(pos - V(0, 1.4, 0)), V(1.8, 3.8, 1.2)
end
Set.Kill = function(H: any, pos: Vector3, low: boolean)
    local ground = H.Ground(pos)
    local bcf, bsz = LlBody(pos, H)
    local cam = workspace.CurrentCamera
    local rt = cam and cam.CFrame.RightVector or V(1, 0, 0)
    rt = V(rt.X, 0, rt.Z)
    rt = (rt.Magnitude > 0.05) and rt.Unit or V(1, 0, 0)
    local W = math.clamp(math.max(bsz.X, bsz.Z) * 1.15, 2.6, 5)
    local Hh = math.clamp(bsz.Y * 1.02, 4, 7.5)
    local cy = bcf.Position.Y
    local frame = CFrame.fromMatrix(V(bcf.Position.X, cy, bcf.Position.Z), rt, V(0, 1, 0)) * CFrame.new(0, 0, math.min(bsz.X, bsz.Z) * 0.5 + 0.12)
    local model = Instance.new("Model"); model.Name = "LeadlightKill"; model.Parent = H.FxFolder()
    -- the quarries: a diamond lattice over the body box (centres where a + b is even), sized for the budget
    local cap = low and 4 or 12
    local D = math.sqrt(2 * W * Hh / cap) * 1.02
    cy = math.max(cy, ground.Y + Hh / 2 + D * 0.4) -- (the lowest panes stand clear of the floor)
    frame = CFrame.fromMatrix(V(bcf.Position.X, cy, bcf.Position.Z), rt, V(0, 1, 0)) * CFrame.new(0, 0, math.min(bsz.X, bsz.Z) * 0.5 + 0.12)
    local spots = {}
    for a = -6, 6 do
        for b = -8, 8 do
            if (a + b) % 2 == 0 then
                local x, y = a * D / 2, b * D / 2
                if math.abs(x) <= W / 2 - D * 0.18 and math.abs(y) <= Hh / 2 - D * 0.18 then table.insert(spots, { X = x, Y = y }) end
            end
        end
    end
    table.sort(spots, function(p, q) return (p.X * p.X + p.Y * p.Y * 0.3) < (q.X * q.X + q.Y * q.Y * 0.3) end)
    while #spots > cap do table.remove(spots) end
    local tones = { P.T4, P.T3, P.T2, P.Jewel, P.T3, P.T1 }
    local side = D / math.sqrt(2) -- (a square of this side turned 45 deg spans D)
    local panes = {}
    for i, sp in ipairs(spots) do
        local tone = tones[(i - 1) % #tones + 1]
        local part = H.FxPart({ Transparency = 1, Size = V(side, side, 0.05), CFrame = frame * CFrame.new(sp.X, sp.Y, 0) * CFrame.Angles(0, 0, math.rad(45)) }, model)
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Back; sg.LightInfluence = 0; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 48
        sg.Parent = part
        local glass = H.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = P.CoreHot, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, sg)
        local lead = H.New("UIStroke", { Color = P.Iron, Thickness = 7, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, glass)
        -- (a darker inner bevel down one side of each pane: the hard facet of the house look)
        H.New("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)), Rotation = 35 }, glass)
        local out = (sp.X >= 0) and 1 or -1
        if math.abs(sp.X) < D * 0.25 then out = (i % 2 == 0) and 1 or -1 end
        table.insert(panes, { P = part, G = glass, L = lead, Tone = tone, X = sp.X, Y = sp.Y,
            Delay = 0.2 + (Hh / 2 - sp.Y) / Hh * 0.08 + math.random() * 0.12, -- (the top panes go first, a ripple down the window)
            Vel = V(out * (1.2 + math.random() * 2), 1 + math.random() * 1.6, (math.random() - 0.2) * 1.4),
            Spin = V(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 10, Half = side * 0.5, Broke = false })
    end
    local glints
    if not low then
        local host = H.FxPart({ Transparency = 1, Size = V(0.1, 0.1, 0.1), CFrame = CFrame.new(ground + V(0, 0.2, 0)) }, model)
        glints = H.Emitter(host, { Texture = H.SPARK, Color = { P.CoreHot, P.T4 }, Size = { 0.22, 0 }, Life = { 0.25, 0.45 }, Speed = { 3, 6 },
            Spread = 60, Accel = V(0, -20, 0), Drag = 1.5, Dir = Enum.NormalId.Top })
    end
    local dur = low and 1.0 or 1.3
    H.Animate(dur, function(t, dt)
        local step = math.clamp(dt, 0, 1 / 20)
        local fade = smooth((t - (dur - 0.25)) / 0.24)
        for _, q in ipairs(panes) do
            -- 1) the window lights: white light floods in and settles to each pane's tone
            local on = smooth(t / 0.08)
            q.G.BackgroundColor3 = P.CoreHot:Lerp(q.Tone, smooth((t - 0.04) / 0.14))
            -- 2) the crack: the leads flash pale for an instant on the beat
            local crack = (t > 0.19 and t < 0.24)
            q.L.Color = crack and P.CoreHot or P.Iron
            -- 3) each pane falls out of the window, tumbling, and breaks on the floor
            local k = t - q.Delay
            local p
            if k > 0 then
                q.Vel += V(0, -34, 0) * step
                q.Off = (q.Off or V(0, 0, 0)) + q.Vel * step
                q.Rot = (q.Rot or CFrame.new()) * CFrame.Angles(q.Spin.X * step, q.Spin.Y * step, q.Spin.Z * step)
                local cf = frame * CFrame.new(q.X + q.Off.X, q.Y + q.Off.Y, q.Off.Z) * q.Rot * CFrame.Angles(0, 0, math.rad(45))
                if cf.Position.Y - q.Half * 0.5 <= ground.Y and not q.Broke then
                    q.Broke = true
                    if glints then glints.Parent.CFrame = CFrame.new(V(cf.Position.X, ground.Y + 0.15, cf.Position.Z)); glints:Emit(2) end
                end
                q.P.CFrame = cf
                p = q.Broke and 1 or 0
            else
                p = 0
            end
            local tr = math.clamp(1 - on + p + fade, 0, 1)
            q.G.BackgroundTransparency = math.clamp(0.1 + tr, 0, 1)
            q.L.Transparency = tr
        end
    end, function() model:Destroy() end)
end

-- ===== the LEADED STRIP banner (lower right, beside the weapon card): a leaded strip with five cabochon sockets; each kill
-- in the streak lights one more cabochon in a deepening tone, at five they shimmer =====
local banner
local NUMFONT = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold)
local WORDS = { "LIT", "GLOWING", "RADIANT", "LUMINOUS", "CATHEDRAL OF LIGHT" }
local SOCK = {}
for k = 1, 5 do
    SOCK[k] = { 180 * (0.16 + 0.17 * (k - 1)), 90 * (0.5 - 0.06 * math.sin(math.pi * (k - 0.5) / 5)) }
end
Set.Banner = function(H: any, streak: number)
    local gui, root = H.BannerRoot("Leadlight", Vector2.new(180, 90), "Side")
    if not root then return end
    local New = H.New
    if not banner or banner.Root ~= root then
        local plate = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("ll_plate", ""), ImageColor3 = P.Pewter, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, root)
        local cabs = {}
        local tones = { P.T4, P.T3, P.T3, P.T2, P.Jewel }
        for i = 1, 5 do
            cabs[i] = New("ImageLabel", { BackgroundTransparency = 1, Image = Tex("ll_seg", H.Art.Glow or ""), ImageColor3 = tones[i], AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(SOCK[i][1], SOCK[i][2]), Size = UDim2.fromOffset(19, 19), ZIndex = 3, ImageTransparency = 1 }, root)
        end
        local word = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(90, 74), Size = UDim2.fromOffset(170, 16),
            FontFace = NUMFONT, TextSize = 12, TextColor3 = P.Text, Text = "", ZIndex = 3 }, root)
        word:SetAttribute("KeepFont", true)
        banner = { Root = root, Plate = plate, Cabs = cabs, Word = word, Token = 0 }
    end
    local b = banner
    b.Token += 1
    local token = b.Token
    local st = math.clamp(streak or 1, 1, 5)
    root.Visible = true
    b.Plate.ImageTransparency = 0
    b.Word.TextTransparency = 0
    b.Word.Text = WORDS[st] .. "  x" .. st
    for i, cb in ipairs(b.Cabs) do cb.ImageTransparency = (i < st) and 0.05 or 1 end
    H.Animate(1.6, function(t)
        if b.Token ~= token then return end
        if st >= 5 then
            for i, cb in ipairs(b.Cabs) do cb.ImageTransparency = 0.05 + 0.4 * (0.5 + 0.5 * math.sin(t * 9 + i * 1.2)) end
        else
            b.Cabs[st].ImageTransparency = 1 - smooth(t / 0.25) * 0.95
        end
    end)
    task.delay(1.6, function()
        if b.Token ~= token then return end
        local ti = TweenInfo.new(0.3)
        H.TweenService:Create(b.Plate, ti, { ImageTransparency = 1 }):Play()
        H.TweenService:Create(b.Word, ti, { TextTransparency = 1 }):Play()
        for _, cb in ipairs(b.Cabs) do H.TweenService:Create(cb, ti, { ImageTransparency = 1 }):Play() end
        task.delay(0.32, function() if b.Token == token then root.Visible = false end end)
    end)
end

-- ===== the LANCET SWORD (melee, Sword class): WeaponAssets.MeleeModels.Leadlight -- a straight arming sword whose fuller is
-- a flowing glass inlay cut by S-curved leads into five panes (they light grip -> tip on a swing), a pewter guard whose
-- quillons curl back like whiplash ironwork, a round cabochon in the boss, a black-leather grip with pewter rings =====
Set.Melee = {
    Skin = { Name = "Lancet Sword", Price = 449, ProductId = 0,
        Desc = "A straight arming sword with a see-through stained-glass window for a fuller: five panes in S-curved leads, framed by the steel edges -- you see the world through it. The pewter quillons curl back like art-nouveau ironwork and a round cabochon glows in the boss. Every kill is an ASCENSION." },
    Rig = { Class = "Sword", BladeLen = 1.12 },
    FlatBlade = true,
    Build = function(m: Model, o: any, H: any)
        local parts = H.CloneModel(m, "MeleeModels", "Leadlight", VAR, { [1] = LUME })
        Tint(m)
        local blade = parts.Blade
        if not blade then return end
        local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
        a0.Name, a1.Name = "TrailBase", "TrailTip"
        a0.Position = blade.CFrame:PointToObjectSpace(blade.Position - blade.CFrame.UpVector * blade.Size.Y * 0.3)
        a1.Position = blade.CFrame:PointToObjectSpace(blade.Position + blade.CFrame.UpVector * blade.Size.Y * 0.48)
        a0.Parent, a1.Parent = blade, blade
        local tr = Instance.new("Trail")
        tr.Attachment0, tr.Attachment1 = a0, a1
        tr.Color = ColorSequence.new(P.T4, P.T2)
        tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
        tr.LightEmission = 0.6; tr.LightInfluence = 0
        tr.Lifetime = 0.12; tr.MinLength = 0.02; tr.FaceCamera = true
        tr.Enabled = false
        tr:SetAttribute("SwingTrail", true)
        tr.Parent = blade
    end,
}

-- ===== arms: GLAZIER GLOVES + LAMPLIGHTER SLEEVES (mesh pieces, WeaponAssets.ArmsModels.Leadlight). Glove: black leather
-- (pebble grain) with a stitched pewter seam round the back and a whiplash line, a pewter oval bezel on the knuckles
-- holding one small glass cabochon; ONE effect: a soft light passes behind it every few seconds. A short gauntlet cuff with
-- a pewter rim. Sleeve: a charcoal wool-tweed lamplighter sleeve, an S-curved pewter piping down the outer arm ending in
-- a curl, a turned-back cuff, a buttoned tab. =====
Set.Glove = function(K: any)
    local V3 = K.V
    return {
        Id = "GlazierGloves", Name = "Glazier Gloves", Price = 449,
        Desc = "Black leather glazier's gloves: a stitched pewter seam and a whiplash line on the back, a pewter oval bezel on the knuckles holding a small glass cabochon that a soft light passes behind every few seconds, and a gauntlet cuff with a pewter rim. Part of the Leadlight set.",
        Base = { Color = C(22, 20, 24), Material = Enum.Material.SmoothPlastic, Reflectance = 0, Tex = "tex_ll_leather", TexTile = 1.4, TexT = 0, TexColor = C(40, 37, 42) },
        Parts = {
            { Mesh = "Leadlight/Back", MeshV = VAR, Size = V3(0.88, 0.11, 0.8), Off = V3(0, 0.53, 0.02) },
            { Mesh = "Leadlight/Knuckle", MeshV = VAR, Size = V3(0.42, 0.09, 0.44), Off = V3(0, 0.57, -0.28), Seat = true },
            { Mesh = "Leadlight/Pane", MeshV = VAR, Size = V3(0.24, 0.07, 0.33), Off = V3(0, 0.6, -0.28), Seat = true,
              Glow = true, Color = P.T4, Anim = "Twinkle", Period = 4.2, Dur = 0.8, PulseMin = 0.15, PulseMax = 0.75 },
            { Mesh = "Leadlight/Cuff", MeshV = VAR, Size = V3(1.18, 1.18, 0.42), Off = V3(0, 0, 0.44) },
        },
    }
end
Set.Sleeve = function(K: any)
    local V3 = K.V
    return {
        Id = "LamplighterSleeves", Name = "Lamplighter Sleeves", Price = 299,
        Desc = "A charcoal wool-tweed lamplighter's coat sleeve with an S-curved pewter piping down the outer arm that ends in a curl, a turned-back cuff and a pewter-buttoned tab. Part of the Leadlight set.",
        Base = { Color = C(38, 38, 42), Material = Enum.Material.SmoothPlastic, Reflectance = 0, Tex = "tex_ll_tweed", TexTile = 2.0, TexT = 0, TexColor = C(62, 62, 68) },
        Parts = {
            { Mesh = "Leadlight/Piping", MeshV = VAR, Size = V3(0.3, 0.06, 0.52), Off = V3(0, 0.52, 0.04), Seat = true },
            { Mesh = "Leadlight/Turn", MeshV = VAR, Size = V3(1.16, 1.16, 0.34), Off = V3(0, 0, -0.36) },
            { Mesh = "Leadlight/Tab", MeshV = VAR, Size = V3(0.16, 0.05, 0.2), Off = V3(-0.58, 0, -0.36), Rot = V3(0, 90, 0), Seat = true },
        },
    }
end

-- ===== health bar (BARS v2, FX roll-out): the house ink frame round a strip of warm glass panes divided by lead cames;
-- lost health SHATTERS -- the lost glass breaks into shards that drop -- and a glint runs along the leads on every hit;
-- elites / bosses carry a cut-glass jewel at the end of the fill =====
Set.Bar = { Id = "Leadlight", Name = "Leadlight", Price = 149,
    Desc = "A strip of warm stained-glass panes divided by lead cames: every hit shatters the lost glass into falling shards and sends a glint along the leads. On elites and bosses a cut-glass jewel rides the end. Part of the Leadlight set.",
    Look = "Ink", FillColor = P.T3, Tex = "tex_ll_bar", TexColor = P.T3:Lerp(C(255, 255, 255), 0.1), TexSpeed = 0, ChipMotion = "Shatter",
    Chip = P.T4:Lerp(C(255, 255, 255), 0.3), Back = P.Plate, Segments = 0, Decor = { "Cames", "Glint", "EndJewel" } }
Set.BarDecor = {
    Cames = function(ctx: any, K: any)
        -- lead cames: dark dividers across the fill (3 on small bars, 6 on big ones), each pane a different tone of glass
        local n = (ctx.Tier == "Small") and 3 or 6
        local panes, cames = {}, {}
        local tones = { P.T4, P.T3, P.T2, P.Jewel, P.T3, P.T4, P.T2 }
        for i = 1, n + 1 do
            panes[i] = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = tones[i], ZIndex = 4 }, ctx.Inner)
        end
        for i = 1, n do
            cames[i] = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = P.Iron, AnchorPoint = Vector2.new(0.5, 0), ZIndex = 7 }, ctx.Inner)
        end
        return function(now, dt, alpha, info)
            for i, p in ipairs(panes) do
                p.Size = UDim2.new(1 / (n + 1), 0, 1, 0)
                p.Position = UDim2.fromScale((i - 1) / (n + 1), 0)
                p.BackgroundTransparency = 1 - alpha * 0.45
            end
            for i, c in ipairs(cames) do
                c.Size = UDim2.new(0, math.max(1, math.floor(ctx.H * 0.22)), 1, 0)
                c.Position = UDim2.fromScale(i / (n + 1), 0)
                c.BackgroundTransparency = 1 - alpha
            end
        end
    end,
    Glint = function(ctx: any, K: any)
        local f = K.Fader()
        local gl = f.Add(K.Img(Tex("ll_flare", ""), { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 11 }, ctx.Holder), 1)
        local lastHit, t = 0, 99
        return function(now, dt, alpha, info)
            if (info.Hit or 0) > lastHit + 0.05 then t = 0 end
            lastHit = info.Hit or 0
            t += dt
            local s = math.max(8, ctx.H * 0.9)
            gl.Size = UDim2.fromOffset(s * 1.6, s)
            gl.Position = UDim2.fromOffset(ctx.W * math.clamp(info.Shown, 0, 1) * math.clamp(t / 0.3, 0, 1), ctx.H * 0.5)
            gl.ImageTransparency = 1 - alpha * ((t < 0.3) and 0.85 or 0)
        end
    end,
    EndJewel = function(ctx: any, K: any)
        if ctx.Tier == "Small" then return function() end end
        local j = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = P.Jewel, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, ZIndex = 12 }, ctx.Holder)
        local ink = K.New("UIStroke", { Color = P.Iron, Thickness = 2 }, j)
        return function(now, dt, alpha, info)
            local s = ctx.H * 1.25
            j.Size = UDim2.fromOffset(s, s)
            j.Position = UDim2.fromOffset(ctx.W * math.max(0.02, info.Shown), ctx.H / 2)
            j.BackgroundColor3 = P.Jewel:Lerp(P.CoreHot, 0.25 + 0.25 * math.sin(now * 2))
            j.BackgroundTransparency = 1 - alpha
            ink.Transparency = 1 - alpha
        end
    end,
}

-- ===== UI theme v2 (FX roll-out 2026-10-14; v1 = the shared template: a came corner sprite + watermark + motes + a flare).
-- Its own pieces, in the icon look: a LEAD CAME frame (faceted pewter bars, ink edged) runs round the inside of every
-- window, set at each corner and the top middle with a cut-glass JEWEL (a turned square in the set's jewel tones) that
-- glows softly in turn as if a light moved behind the window; under the content a faint pool of coloured light falls from
-- the top left, slowly shifting tone. OPEN = glazing: the came draws itself round the window clockwise and each jewel
-- lights as the lead reaches it (0.5 s). Title bars get a came line with three small quarries. Colours from the theme table.
local function LlFacet(ctx, o, lit, shade, inkW)
    local g = Instance.new("UIGradient")
    g.Color = ctx.UIStyle.Facet(lit, shade)
    g.Rotation = ctx.UIStyle.FACET_ROT or 35
    g.Parent = o
    local ink = ctx.UIStyle.InkEdge(inkW or 2)
    ink.Parent = o
end
local function LlDeco(ctx)
    if ctx.Kind ~= "Window" then return nil end
    local t = ctx.Theme
    local host = ctx.Root or ctx.Surface
    -- the coloured light pool, UNDER the content (in the deco layer)
    local pool = Instance.new("Frame")
    pool.Name = "LlPool"; pool.BorderSizePixel = 0; pool.BackgroundColor3 = t.Tone1; pool.Size = UDim2.fromScale(0.7, 0.75)
    pool.BackgroundTransparency = 0.86; pool.ZIndex = ctx.Frame.ZIndex; pool.Parent = ctx.Frame
    local pg = Instance.new("UIGradient"); pg.Rotation = 35
    pg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.6), NumberSequenceKeypoint.new(1, 1) })
    pg.Parent = pool
    local f = Instance.new("Frame")
    f.Name = "LlOverlay"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 20; f.Active = false
    f:SetAttribute("NoSkin", true); f:SetAttribute("Skinned", true)
    f.Parent = host
    local small = math.min(host.AbsoluteSize.X, host.AbsoluteSize.Y) < 260
    local th, inset = small and 3 or 5, small and 3 or 5
    local bars = {}
    for i = 1, 4 do
        local b = Instance.new("Frame")
        b.Name = "LlCame"; b.BorderSizePixel = 0; b.BackgroundColor3 = Color3.new(1, 1, 1); b.ZIndex = f.ZIndex + 1; b.Parent = f
        LlFacet(ctx, b, t.PewterFace, t.PewterShade, 1)
        bars[i] = b
    end
    local js = small and 9 or 15
    local jewels = {}
    local spots = { { 0, 0 }, { 0.5, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }
    local tones = { t.Tone1, t.Tone4, t.Tone2, t.Tone3, t.Jewel }
    for i, sp in ipairs(spots) do
        local j = Instance.new("Frame")
        j.Name = "LlJewel"; j.BorderSizePixel = 0; j.BackgroundColor3 = Color3.new(1, 1, 1); j.AnchorPoint = Vector2.new(0.5, 0.5)
        j.Size = UDim2.fromOffset(js, js); j.Rotation = 45; j.ZIndex = f.ZIndex + 2; j.Parent = f
        local g = Instance.new("UIGradient"); g.Color = ctx.UIStyle.Facet(tones[i], tones[i]:Lerp(Color3.new(0, 0, 0), 0.4)); g.Rotation = 35; g.Parent = j
        local ink = Instance.new("UIStroke"); ink.Color = t.Ink; ink.Thickness = small and 2 or 3; ink.Parent = j
        jewels[i] = { F = j, X = sp[1], Y = sp[2], G = g, Tone = tones[i] }
    end
    f:SetAttribute("LlGlaze", 1)
    local lastW, lastH, lastK = -1, -1, -1
    local ph = math.random() * 6.28
    return function(now, dt)
        local k = f:GetAttribute("LlGlaze") or 1
        local sz = f.AbsoluteSize
        if sz.X ~= lastW or sz.Y ~= lastH or k ~= lastK then
            lastW, lastH, lastK = sz.X, sz.Y, k
            local x0, y0, x1, y1 = inset, inset, sz.X - inset, sz.Y - inset
            local runs = { { x0, y0, 1, 0, x1 - x0 }, { x1, y0, 0, 1, y1 - y0 }, { x1, y1, -1, 0, x1 - x0 }, { x0, y1, 0, -1, y1 - y0 } }
            local total = 2 * (x1 - x0) + 2 * (y1 - y0)
            local left = total * k
            for i, r in ipairs(runs) do
                local len = math.clamp(left, 0, r[5])
                left -= len
                local b = bars[i]
                b.Visible = len > 1
                local ax = (r[3] < 0) and 1 or 0
                local ay = (r[4] < 0) and 1 or 0
                b.AnchorPoint = Vector2.new(r[3] ~= 0 and ax or 0.5, r[4] ~= 0 and ay or 0.5)
                b.Size = (r[3] ~= 0) and UDim2.fromOffset(len, th) or UDim2.fromOffset(th, len)
                b.Position = UDim2.fromOffset(r[1], r[2])
            end
            -- the jewels light as the lead reaches them (their position along the run, 0..1)
            local at = { 0, 0.5 * (x1 - x0) / total, (x1 - x0) / total, (2 * (x1 - x0) + (y1 - y0)) / total, 0.999 }
            for i, j in ipairs(jewels) do
                j.F.Position = UDim2.new(j.X, (j.X == 0) and inset or ((j.X == 1) and -inset or 0), j.Y, (j.Y == 0) and inset or -inset)
                j.F.Visible = k >= at[i] - 0.001
            end
        end
        -- a light moving behind the window: each jewel brightens in turn; the pool drifts through the tones
        for i, j in ipairs(jewels) do
            local w = 0.5 + 0.5 * math.sin(now * 0.9 - i * 1.25 + ph)
            local lit = j.Tone:Lerp(t.Hot, 0.35 * w * w)
            j.G.Color = ctx.UIStyle.Facet(lit, j.Tone:Lerp(Color3.new(0, 0, 0), 0.4))
        end
        local h = (now * 0.05 + ph) % 1
        pool.BackgroundColor3 = (h < 0.5) and t.Tone1:Lerp(t.Tone3, h * 2) or t.Tone3:Lerp(t.Tone1, (h - 0.5) * 2)
    end, { f }
end
local function LlOpen(ctx)
    local f = ctx.Root and ctx.Root:FindFirstChild("LlOverlay")
    if not f then return end
    local t0 = os.clock()
    f:SetAttribute("LlGlaze", 0)
    local conn
    conn = game:GetService("RunService").RenderStepped:Connect(function()
        local k = math.clamp((os.clock() - t0) / 0.5, 0, 1)
        if not f.Parent then conn:Disconnect() return end
        f:SetAttribute("LlGlaze", 1 - (1 - k) ^ 2)
        if k >= 1 then conn:Disconnect(); f:SetAttribute("LlGlaze", 1) end
    end)
end
local function LlTitle(ctx)
    local bar, t = ctx.Title, ctx.Theme
    local came = Instance.new("Frame")
    came.Name = "LlTitleCame"; came.BorderSizePixel = 0; came.BackgroundColor3 = t.PewterFace; came.AnchorPoint = Vector2.new(0, 1)
    came.Position = UDim2.new(0, 10, 1, -4); came.Size = UDim2.new(0.26, 0, 0, 2); came.ZIndex = bar.ZIndex + 1; came.Parent = bar
    local made = { came }
    for i, tone in ipairs({ t.Tone1, t.Tone4, t.Jewel }) do
        local q = Instance.new("Frame")
        q.Name = "LlQuarry"; q.BorderSizePixel = 0; q.BackgroundColor3 = tone; q.AnchorPoint = Vector2.new(0.5, 0.5); q.Rotation = 45
        q.Size = UDim2.fromOffset(8, 8); q.Position = UDim2.new(0.26, 6 + i * 13, 1, -5); q.ZIndex = bar.ZIndex + 1; q.Parent = bar
        local ink = Instance.new("UIStroke"); ink.Color = t.Ink; ink.Thickness = 1.5; ink.Parent = q
        table.insert(made, q)
    end
    return made
end
-- numbers v3 (SKIN UI roll-out 2026-10-29, owner: numbers "unique to the skin and the colorways you have equipped"): LIGHT
-- THROUGH GLASS. Inscriptional capitals (RomanAntique) that appear dark as lead and FLOOD WITH LIGHT (0.14 s, again on every
-- merged hit) while a pool of coloured light from this colourway's glass glows up behind them; they rise slowly with a slight
-- sway. CRIT = a PRISM: the pool splits into two glass colours either side and the digits burn with the core light; WEAK SPOT =
-- the pool is the jewel's colour and a ♦ quarry leads the digits; a KILL = the panes fall out: four leaded diamond quarries
-- drop away from the number, tumbling, and fade (the set's Ascension kill). Every colour is this copy's palette (P).
local function LlMotion(e, age, pa, life)
    local rise = 1 - (1 - math.min(1, age / 0.9)) ^ 3
    return 0.35 + rise * 1.35, 0.12 * math.sin(age * 4 + e.Seed) * rise, 1 + 0.06 * math.exp(-pa * 12), 0, 0, 0
end
local LL_PANES = { "T2", "T3", "T4", "Jewel" }
local function LlAccent(e)
    local box = Instance.new("Frame")
    box.Name = "LlGlass"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 0
    for i = 1, 2 do
        local p = Instance.new("ImageLabel")
        p.Name = "Pool" .. i; p.BackgroundTransparency = 1; p.Image = Tex("ll_dapple", ""); p.AnchorPoint = Vector2.new(0.5, 0.5)
        p.Position = UDim2.fromScale(0.5, 0.5); p.ScaleType = Enum.ScaleType.Stretch; p.ZIndex = 0; p.Parent = box
    end
    for i = 1, 4 do
        local q = Instance.new("Frame")
        q.Name = "Pane" .. i; q.BorderSizePixel = 0; q.AnchorPoint = Vector2.new(0.5, 0.5); q.Size = UDim2.fromOffset(8, 8); q.ZIndex = 1 -- (behind the digits)
        local st = Instance.new("UIStroke"); st.Thickness = 1.5; st.Parent = q
        q.Parent = box
    end
    e.Label.ZIndex = 2
    return box
end
local function LlAccentStep(e, box, age, pa, alpha)
    local tb = e.Label.TextBounds
    local crit = e.Crit and not e.Dot
    -- the digits start dark as lead and light floods into them
    local k = smooth(pa / 0.14)
    e.Label.TextColor3 = P.Iron:Lerp(e.Color, k)
    -- the pool of coloured light behind (two colours split apart on a crit: a prism)
    local glow = smooth(age / 0.2)
    for i = 1, 2 do
        local p = box:FindFirstChild("Pool" .. i)
        if p then
            p.Visible = not e.Dot and (i == 1 or crit)
            if p.Visible then
                local split = crit and (i == 1 and -1 or 1) * (4 + 8 * glow) or 0
                p.Size = UDim2.fromOffset(math.floor(tb.X + 34), math.floor(tb.Y + 24))
                p.Position = UDim2.new(0.5, math.floor(split), 0.5, 1)
                p.ImageColor3 = crit and ((i == 1) and P.T2 or P.T4) or ((e.Weak and P.Jewel) or P.T3)
                p.ImageTransparency = math.clamp(0.25 + 0.5 * (1 - glow) + alpha * 0.75 + 0.2 * smooth((age - 0.4) / 0.5), 0, 1)
            end
        end
    end
    -- kill: the panes fall out of the number, tumbling, and fade
    local t = (e.Killed and e.KillAt) and (os.clock() - e.KillAt) or -1
    for i = 1, 4 do
        local q = box:FindFirstChild("Pane" .. i)
        if q then
            local on = t >= 0 and t < 0.8 and not e.Dot
            q.Visible = on
            if on then
                local u = t / 0.8
                local x0 = (i - 2.5) / 1.5 * (tb.X * 0.5 + 6) -- (they drop out of the number's lower edge, never over the digits)
                q.Position = UDim2.new(0.5, math.floor(x0 + (i - 2.5) * 10 * u), 0.5, math.floor(tb.Y * 0.5 + 6 + 70 * u * u))
                q.Rotation = 45 + (i % 2 == 0 and 1 or -1) * 260 * u
                q.BackgroundColor3 = P[LL_PANES[i]]
                local tr = math.clamp(alpha + 0.15 + u * 0.75, 0, 1)
                q.BackgroundTransparency = tr
                local st = q:FindFirstChildOfClass("UIStroke"); if st then st.Color = P.Iron; st.Transparency = tr end
            end
        end
    end
end
-- ===== UI THEME v4 (SKIN UI THEMES roll-out 2026-10-29): the clean language in this colourway's iron + glass (UITheme Clean) +
-- the glazier's touches. Hooks read only the palette they are given (a colourway copy shares these functions):
--   TAB MARK  the underline is a STRIP OF LEADED GLASS: four panes of this colourway's glass in a dark lead came, a cabochon
--             jewel at its end (it twinkles on the top bar)
--   FIELD     a LEADED BORDER of diamond quarries runs down the left margin with a light passing slowly behind it, and two pools
--             of coloured light (the glass tones) fall across the screen and drift as if clouds pass the window
local LL_CLEAN = {
    Field = P.Plate:Lerp(P.T1, 0.12), Surface = P.Plate:Lerp(P.Iron, 0.35):Lerp(P.T1, 0.1), Raised = P.Iron:Lerp(P.T1, 0.2), Hover = P.Iron:Lerp(P.T2, 0.28),
    Well = P.Plate, Line = P.Iron:Lerp(P.Pewter, 0.32), Tip = P.Plate:Lerp(P.T1, 0.06),
    Accent = P.Lume, Mark = P.T3, Hair = P.Pewter,
    Text = P.Text, Sub = P.Text:Lerp(P.Pewter, 0.45), Muted = P.Pewter:Lerp(P.Text, 0.15), Ink = P.Plate,
    T1 = P.T1, T2 = P.T2, T3 = P.T3, T4 = P.T4, Jewel = P.Jewel, Came = P.Iron:Lerp(Color3.new(0, 0, 0), 0.35), Light = P.CoreHot, Core = P.Core,
}
-- (HudThemes.Variant keeps a colourway copy's Clean colour only when it DIFFERS from colourway 1's; one that is the same in
-- both palettes (the gold, a shared brass ...) went through the hue map instead -- Indigo's gold seam came out green. A
-- hair's difference keeps this copy's own colour.)
if VAR ~= 1 then for k, v in pairs(LL_CLEAN) do if typeof(v) == "Color3" then LL_CLEAN[k] = v:Lerp(Color3.new(0, 0, 0), 0.003) end end end
local function LlK(t, c) return ColorSequenceKeypoint.new(t, c) end
LL_CLEAN.TabMark = function(mark, Q)
    -- (children of a tab mark: offset-sized, inside the mark's width -- tab buttons are AutomaticSize X; the came is a stroke)
    local g = Instance.new("UIGradient")
    g.Name = "LlPanes"
    local c = Q.Came
    g.Color = ColorSequence.new({ LlK(0, Q.T3), LlK(0.225, Q.T3), LlK(0.23, c), LlK(0.25, c), LlK(0.255, Q.T4), LlK(0.485, Q.T4), LlK(0.49, c),
        LlK(0.51, c), LlK(0.515, Q.T2), LlK(0.745, Q.T2), LlK(0.75, c), LlK(0.77, c), LlK(0.775, Q.T4), LlK(1, Q.T4) })
    g.Parent = mark
    local st = Instance.new("UIStroke")
    st.Name = "LlCame"; st.Color = c; st.Thickness = 1; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = mark
    local j = Instance.new("Frame")
    j.Name = "LlJewel"; j.BorderSizePixel = 0; j.BackgroundColor3 = Q.Jewel; j.Position = UDim2.new(1, -6, 0, -2); j.Size = UDim2.fromOffset(6, 6)
    j.ZIndex = mark.ZIndex + 1; j.Parent = mark
    local jc = Instance.new("UICorner"); jc.CornerRadius = UDim.new(0.5, 0); jc.Parent = j
    local js = Instance.new("UIStroke"); js.Color = c; js.Thickness = 1.5; js.Parent = j
    return { g, st, j }
end
LL_CLEAN.Sig = function(ctx)
    local Q, f = ctx.P, ctx.Frame
    local topY = 64
    if ctx.Top and ctx.Top.AbsoluteSize.Y > 0 then topY = ctx.Top.AbsolutePosition.Y - f.AbsolutePosition.Y + ctx.Top.AbsoluteSize.Y end
    local made = {}
    -- two pools of coloured light across the screen (the window's light falling on the floor), drifting slowly
    local pools = {}
    for i, d in ipairs({ { 0.62, 0.72, 520, 300, "T3" }, { 0.2, 0.36, 380, 240, "T2" } }) do
        local p = Instance.new("ImageLabel")
        p.Name = "LlPool" .. i; p.BackgroundTransparency = 1; p.Image = Tex("ll_dapple", ""); p.ScaleType = Enum.ScaleType.Stretch
        p.ImageColor3 = Q[d[5]]; p.ImageTransparency = 0.86; p.AnchorPoint = Vector2.new(0.5, 0.5); p.Size = UDim2.fromOffset(d[3], d[4])
        p.Position = UDim2.fromScale(d[1], d[2]); p.ZIndex = 0; p.Parent = f
        pools[i] = { I = p, X = d[1], Y = d[2], Ph = i * 2.3 }
    end
    -- the leaded border: a column of diamond quarries down the left margin, a light passing slowly down behind it
    local col
    local light
    if not ctx.Phone then
        col = Instance.new("Frame")
        col.Name = "LlBorder"; col.BackgroundTransparency = 1; col.ClipsDescendants = true; col.Position = UDim2.new(0, 2, 0, topY + 8)
        col.Size = UDim2.new(0, 14, 1, -(topY + 16)); col.ZIndex = 0; col.Parent = f
        local came = Instance.new("Frame") -- (the lead came the quarries are set in)
        came.Name = "LlCameLine"; came.BorderSizePixel = 0; came.BackgroundColor3 = Q.Came; came.BackgroundTransparency = 0.3; came.AnchorPoint = Vector2.new(0.5, 0)
        came.Position = UDim2.fromScale(0.5, 0); came.Size = UDim2.new(0, 2, 1, 0); came.ZIndex = 1; came.Parent = col
        light = Instance.new("Frame")
        light.Name = "LlLight"; light.BorderSizePixel = 0; light.BackgroundColor3 = Q.Light; light.AnchorPoint = Vector2.new(0, 0.5)
        light.Size = UDim2.new(1, 0, 0, 160); light.ZIndex = 0; light.Parent = col
        local lg = Instance.new("UIGradient"); lg.Rotation = 90
        lg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) })
        lg.Parent = light
        local tones = { Q.T2, Q.T3, Q.T4, Q.T3 }
        for i = 0, 60 do
            local q = Instance.new("Frame")
            q.Name = "Quarry"; q.BorderSizePixel = 0; q.BackgroundColor3 = tones[i % 4 + 1]; q.BackgroundTransparency = 0.45; q.Rotation = 45
            q.AnchorPoint = Vector2.new(0.5, 0.5); q.Position = UDim2.new(0.5, 0, 0, 8 + i * 17); q.Size = UDim2.fromOffset(10, 10); q.ZIndex = 2
            local st = Instance.new("UIStroke"); st.Color = Q.Came; st.Thickness = 1.5; st.Transparency = 0.2; st.Parent = q
            q.Parent = col
        end
    end
    local ph = math.random() * 6
    local placedY = -1
    return function(now, _dt)
        -- (the border starts under the top bar: its size is only known once the menu has been laid out)
        if col and ctx.Top and ctx.Top.AbsoluteSize.Y > 0 then
            local y = ctx.Top.AbsolutePosition.Y - f.AbsolutePosition.Y + ctx.Top.AbsoluteSize.Y
            if math.abs(y - placedY) > 0.5 then
                placedY = y
                col.Position = UDim2.new(0, 2, 0, y + 10); col.Size = UDim2.new(0, 14, 1, -(y + 18))
            end
        end
        for _, p in ipairs(pools) do
            p.I.Position = UDim2.fromScale(p.X + 0.03 * math.sin(now * 0.11 + p.Ph), p.Y + 0.02 * math.sin(now * 0.08 + p.Ph * 1.7))
            p.I.ImageTransparency = 0.84 + 0.05 * math.sin(now * 0.23 + p.Ph)
        end
        if light then light.Position = UDim2.new(0, 0, ((now * 0.06 + ph) % 1.4) - 0.2, 0) end
        -- the cabochon on the selected tab twinkles now and then
        for _, m in ipairs(ctx.Marks()) do
            local j = m.Visible and m:FindFirstChild("LlJewel")
            if j then
                local k = math.max(0, math.sin(now * 1.3 + ph)) ^ 6
                j.BackgroundColor3 = Q.Jewel:Lerp(Q.Light, k * 0.7)
            end
        end
    end, made
end
local P1 = PALETTES[1]
local function PG(top, bottom) return { Top = top, Bottom = bottom } end
Set.Theme = { Name = "Leadlight", Desc = "Every menu is glazed in your colourway's glass: a leaded border of diamond quarries runs down the edge with a light passing behind it, pools of coloured light drift across the screen, and every tab is underlined with a strip of leaded glass and a jewel.",
    Panel = PG(C(22, 18, 22), C(7, 6, 8)), Card = PG(C(30, 24, 30), C(10, 8, 11)), Title = PG(C(120, 30, 24), C(40, 10, 8)),
    Accent = C(240, 150, 60), Accent2 = C(255, 200, 120), HpFill = C(240, 130, 50), HpBg = C(20, 12, 10), XpFill = C(255, 200, 120), Text = C(250, 236, 214),
    Tone1 = P1.T4, Tone2 = P1.T2, Tone3 = P1.T3, Tone4 = P1.T1, Jewel = P1.Jewel, Hot = P1.CoreHot, PewterFace = P1.Pewter, PewterShade = P1.Iron,
    Ink = C(10, 8, 10), Emblem = "EmblemLeadlight", BorderThick = 2,
    Deco = LlDeco, OpenFn = LlOpen, TitleDeco = LlTitle,
    Clean = LL_CLEAN, -- (SKIN UI THEMES: the clean iron + glass palette + leaded-glass tab marks + the leaded border / light pools; the old art is not drawn)
    -- (SKIN UI 2026-10-29: light through glass -- lead-dark digits flood with light over a glass pool; crit = prism, kill = panes fall out)
    Numbers = { Font = "RomanAntique", Glyph = "♦", NoBang = true, Motion = LlMotion, Accent = LlAccent, AccentStep = LlAccentStep,
        Normal = P.Text, Crit = P.Lume:Lerp(P.CoreHot, 0.3), Weak = P.T4, Stroke = P.Plate, StrokeThick = 2, Size = 1.08 } }

-- ===== bundle / kill effect / store hero =====
Set.KillEffect = { Id = "LeadlightAscension", Name = "Ascension", Image = Tex("ll_emblem", ""),
    How = "Own any Leadlight skin (or the Leadlight bundle)",
    Desc = "The enemy becomes a leaded window: its body is redrawn as diamond panes of lit jewel-toned glass bound in lead, a crack runs through the leads and the panes fall out one by one, tumbling, and shatter into glints on the floor. With the leaded-strip banner whose cabochons light one per kill." }
Set.Bundle = { Id = "LeadlightBundle", Name = "Leadlight Bundle", Price = 1999, BP = 699, ProductId = 0,
    Desc = "The whole Leadlight set: the Leadlight 21E, P99 and Helios Beam, the Lancet Sword, Glazier Gloves + Lamplighter Sleeves, the Leadlight health bar, the Leadlight UI theme and the Ascension kill effect.",
    Contents = { "WeaponSkin:LeadlightHK21", "WeaponSkin:LeadlightSR9", "WeaponSkin:LeadlightHelios", "MeleeSkin:Leadlight", "Glove:GlazierGloves",
        "Sleeve:LamplighterSleeves", "HealthBar:Leadlight", "KillEffect:LeadlightAscension" } }
Set.Hero = { Grad = { C(110, 30, 20), C(12, 8, 8) }, Stroke = LUME, Emblem = Tex("ll_emblem", ""), Name = C(250, 236, 214), Chip = C(140, 50, 20) }

return Set
