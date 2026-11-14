--!nocheck
-- ===================================================================================================================
-- FISSION (Skins V3, bundle 8 of docs/SKINS_V3_PLAN.md): AA-12 + M249 + Ion Accelerator | Control Rod | 1,199 BP.
-- A portable reactor in your hands: graphite masses, blue-grey reactor-steel shielding with hex bolts, lead-grey hardware.
-- The guns, the hammer, the arm pieces are RESCULPTED models (WeaponAssets.SkinModels.Fission_<GUN>, MeleeModels.Fission,
-- ArmsModels.Fission; built with tools/skins_v3/fission_build.py in art/weapons/SkinsV3_Fission.blend, painted by
-- tools/skin_v3_paint.py with tools/skins_v3/fission.json). This module brings:
--   PORTHOLE  a round lead-glass sight port in a bolted ring on the camera side, set in a bay turned toward your eye: behind
--             it a pool of Cherenkov-blue water (Neon) with dark fuel rods standing in it. The water BREATHES (slow, deep),
--             brightens with fire and the streak; coolant ports on the jacket glow with it
--   SCRAM     control-rod blades drop into the port on a reload and the glow dies to near black; they withdraw and the
--             light comes back as the new round is in; the draw is a reactor start (rods up, black -> blue, needle swings)
--   GAUGE     a needle pressure gauge beside the port: it trembles at idle, climbs with sustained fire, falls on a SCRAM
--   HATCH     the inspect slides the bolted shielding hatch on the right side open over a second port; the glow surges and
--             steam puffs from the vents
-- A compact blue-white muzzle flash with a shock ring and a wisp of steam, an IONISED tracer (white core, blue halo fading
-- along it), an ion SPLASH impact with steam and a faint scorch, the DECAY kill (the body glows from within, the light
-- condenses into a sphere at chest height that sinks into the ground as a glowing pool) and a reactor-GAUGE banner beside
-- the HUD's weapon card. Original design (the plan's Originality line): a round bolted reactor sight port with rods in
-- glowing water, a SCRAM reload and a needle gauge are ours; no copper, no coils, no frost, no white shell, no row of lit
-- capsules, no radiation trefoil, no hazard stripes.
-- ===================================================================================================================
local Set = { Kind = "Fission" }

local VAR = script:GetAttribute("Colorway") or 1
local C = Color3.fromRGB
local V = Vector3.new
local PALETTES = {
    { Name = "Cherenkov", Body = C(36, 40, 46), Mid = C(50, 60, 70), Detail = C(46, 48, 53), Glow = C(50, 130, 255), Hot = C(175, 215, 255),
      Spark = C(120, 190, 255), Dark = C(10, 12, 16), Text = C(210, 230, 255), Dim = C(30, 60, 110), Ink = C(4, 10, 24), Steam = C(196, 208, 222),
      Scorch = C(20, 40, 90) },
    { Name = "Isotope", Body = C(30, 36, 24), Mid = C(46, 54, 38), Detail = C(44, 47, 40), Glow = C(120, 255, 90), Hot = C(210, 255, 190),
      Spark = C(160, 255, 120), Dark = C(8, 10, 6), Text = C(222, 240, 210), Dim = C(40, 90, 30), Ink = C(6, 14, 4), Steam = C(204, 212, 196),
      Scorch = C(30, 70, 20) },
    { Name = "Hot Core", Body = C(36, 33, 33), Mid = C(64, 56, 51), Detail = C(52, 48, 45), Glow = C(255, 150, 40), Hot = C(255, 222, 172),
      Spark = C(255, 190, 110), Dark = C(12, 10, 9), Text = C(245, 228, 210), Dim = C(110, 60, 20), Ink = C(20, 10, 4), Steam = C(218, 208, 198),
      Scorch = C(90, 40, 10) },
    { Name = "Plutonium", Body = C(34, 24, 46), Mid = C(58, 48, 76), Detail = C(48, 42, 60), Glow = C(235, 70, 200), Hot = C(255, 196, 242),
      Spark = C(255, 140, 230), Dark = C(10, 8, 16), Text = C(240, 222, 245), Dim = C(100, 30, 90), Ink = C(16, 6, 20), Steam = C(212, 202, 222),
      Scorch = C(80, 20, 70) },
}
local P = PALETTES[VAR] or PALETTES[1]
local GLOW, HOT, SPARK, DARK, STEAM = P.Glow, P.Hot, P.Spark, P.Dark, P.Steam
local WHITE = C(240, 248, 255)
Set.Palettes = PALETTES
Set.Colors = { Glow = GLOW, Hot = HOT, Spark = SPARK }

-- art (tools/make_fission_art.py, uploaded as decals; IMAGE ids resolved in Studio)
local A = "rbxassetid://"
Set.Art = {
    EmblemFission = A .. "99673387859538", fs_emblem_mask = A .. "136197492592959", tex_fs_caustics = A .. "112319500685180",
    fs_corner = A .. "101466448963342", fs_dial = A .. "129892755236605", fs_needle = A .. "104815279209705", fs_zone = A .. "75024783464978",
    fs_ring = A .. "94386307431764", tex_fs_bar = A .. "104870215959106", fs_bubble = A .. "94055052415670",
    tex_fs_suit = A .. "127090211223096", tex_fs_rubber = A .. "137997369101158", -- (skins12 touch-up: arm materials, make_fission_art.py arms)
}
local ART = Set.Art

-- sounds (tools/skins_v3/fission_sfx.py -> art/sounds/v3/skin_fission_*.wav: each gun's own shot + a deep latch 'thoom'
-- and a short low motor hum; moments from CC0 recordings -- a heavy cellar-door latch, steam hiss, a drive's spin-down
-- played backwards, bubbling water, a splash, an anvil). Uploaded through tools/upload_audio.py (screened), ids also in
-- tools/skins_v3/fission_audio_ids.json.
Set.Sounds = {
    Equip = { Id = 123724217259005, Volume = 0.42 }, MagOut = { Id = 79256245964263, Volume = 0.32 }, MagIn = { Id = 114946612056174, Volume = 0.34 },
    Kill = { Id = 86942987502175, Volume = 0.5 }, Impact = { Id = 121596400131109, Volume = 0.18 }, Swing = { Id = 113337600663268, Volume = 0.4 },
    MeleeHit = { Id = 78365085289082, Volume = 0.42 }, Hatch = { Id = 118612853414365, Volume = 0.3 },
    -- (volumes matched to the base guns' level: tools/skins_v3/fission_sfx.py RMS check AA12 +1.9 / M249 +4.1 / Ion +0.4 dB;
    -- the AA-12 / M249 files were then turned down by tools/audio_screen.py --quieten (0.9 / 2.9 dB) to pass the upload
    -- screen, so their volumes are raised by the same factor: 0.65 x 1.11, 0.5 x 1.40)
    FireGun = { AA12 = { Id = 128234780588436, Volume = 0.72 }, M249 = { Id = 122614677229997, Volume = 0.7 }, PlasmaCannon = { Id = 109981713525885, Volume = 0.78 } },
}

local function GunDesc(gun: string): string
    local what = (gun == "M249") and "the receiver carries a shielded reactor housing with the sight port and a pressure gauge, the handguard is a heavy cooling jacket with glowing coolant ports, the stock is graphite with a coolant line to the receiver and the box magazine is a shielded fuel cask with its own port"
        or (gun == "PlasmaCannon") and "a reactor housing with a big sight port and a pressure gauge is bolted to the body, clamp collars ride the barrel shroud, its vents burn Cherenkov blue and the canister cell is a banded fuel cask with two ports"
        or "the receiver wears a bolted shield plate with the sight port and a pressure gauge, the handguard is a heavy cooling jacket with glowing coolant ports, a moderator can sits on the muzzle, the stock is a graphite shield block and the magazine a fuel cask with its own port"
    return "A portable reactor: graphite, blue-grey reactor steel and hex bolts. " .. string.upper(string.sub(what, 1, 1)) .. string.sub(what, 2) .. ". Behind the lead glass, fuel rods stand in water that glows Cherenkov blue and breathes, brighter as you fire. A reload is a SCRAM: the control rods drop and the light dies, then comes back. The inspect slides the right-side hatch open on a second port. Ionised tracers, ion splash impacts and the DECAY kill: the body glows from within and sinks into a pool of light."
end

-- ===== the guns =====
Set.GunSkins = {
    { Id = "FissionAA12", Name = "Fission AA-12", Gun = "AA12", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("AA12"),
      Model = "Fission_AA12", V3 = true, Color = GLOW, Color2 = HOT, Deco = "FissionGun", PerShot = 0.11 },
    { Id = "FissionM249", Name = "Fission M249", Gun = "M249", Rarity = "Mythic", Price = 399, ProductId = 0, Desc = GunDesc("M249"),
      Model = "Fission_M249", V3 = true, Color = GLOW, Color2 = HOT, Deco = "FissionGun", PerShot = 0.035 },
    { Id = "FissionPlasmaCannon", Name = "Fission Ion Accelerator", Gun = "PlasmaCannon", Rarity = "Mythic", Price = 399, ProductId = 0,
      Desc = GunDesc("PlasmaCannon"), Model = "Fission_PlasmaCannon", V3 = true, Color = GLOW, Color2 = HOT, BeamColor = GLOW, Deco = "FissionGun", PerShot = 0.14 },
}

-- ===== the dress: glow depths for the drives (the water and ports go nearly black when the core is down), steam emitters
-- on every port (the inspect's puff, first person only) =====
Set.Build = {}
Set.Build.FissionGun = function(model: Model, frame: BasePart, f: any, forView: boolean, H: any)
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            local n = p.Name
            if string.find(n, "^Glow_") and string.find(n, "Water$") then
                p:SetAttribute("GlowCold", 0.9); p:SetAttribute("GlowHot", 0)
            elseif string.find(n, "^Glow_") and string.find(n, "Ports$") then
                p:SetAttribute("GlowCold", 0.86); p:SetAttribute("GlowHot", 0.05)
            elseif string.find(n, "^Glow_") and string.find(n, "Arc$") then
                p:SetAttribute("GlowCold", 0.7); p:SetAttribute("GlowHot", 0.15)
            end
            -- (gate budget, skins9: <= 2 emitters per piece -- one steam emitter on the camera-side port only (Glass_A / _M /
            -- _I), the muzzle steam rides the engine's own Smoke emitter, the shock ring is the second)
            if forView and string.find(n, "^Glass_[AMI]$") then
                local att = Instance.new("Attachment"); att.Name = "FSteamAtt"; att.Parent = p
                H.Emitter(att, { Name = "FSteam", Texture = H.SMOKE, Color = { STEAM, STEAM }, Size = { 0.06, 0.32 }, Life = { 0.5, 0.9 }, Speed = { 0.4, 1.0 },
                    Accel = V(0, 1.2, 0), Trans = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.7), NumberSequenceKeypoint.new(1, 1) }),
                    Light = 0, Influence = 1, Spread = 35, SkinFx = true })
            end
        end
    end
end

-- ===== motion =====
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function pulse(t, w) return math.exp(-(t / w) ^ 2) end
local function PlaySound(H: any, d: any)
    if not d or (d.Id or 0) == 0 then return end
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. tostring(d.Id)
    s.Volume = d.Volume or 0.4
    local grp = H.SoundService:FindFirstChild("AimRngMix_Weapons")
    if grp then s.SoundGroup = grp end
    s.Parent = H.SoundService
    s:Play()
    H.Debris:AddItem(s, 3)
end
-- st keys: Core (water / ports / gauge band), Scram (control rods 0 = up .. 1 = in), Pressure (needle 0..1), Hatch (0..1),
-- Barrel (the Ion's vents). v = the rig's own vars.
local function FillKeys(st: any, v: any, dt: number, now: number, perShot: number)
    local ss = st.SinceShot or 99
    local se = st.SinceEquip or 99
    local streak = math.min(st.Streak or 0, 5)
    if ss < 0.08 and ss < (v.LastSS or 99) - 1e-4 then v.Heat = math.min(1, (v.Heat or 0) + perShot) end
    v.LastSS = ss
    local heat = v.Heat or 0
    if ss > 0.3 then heat = heat * math.exp(-dt / 1.3) end
    v.Heat = heat
    -- SCRAM: the rods drop at the start of a reload, hold, withdraw as it ends; on the draw they withdraw up
    local rl = st.Reload or 0
    local scram = 0
    if rl > 0 then
        scram = smooth(rl / 0.1) * (1 - smooth((rl - 0.8) / 0.18))
        v.Scrammed = now
    end
    if se < 0.4 then scram = math.max(scram, 1 - smooth((se - 0.04) / 0.3)) end
    st.Scram = scram
    -- the water: slow deep breathing, brighter with heat + the streak + the inspect; dark while scrammed; the draw ramps it
    -- up from black in 0.5 s after the rods are out
    local breathe = 0.5 + 0.09 * math.sin(now * 1.15) + 0.05 * math.sin(now * 2.6 + 1.3)
    local core = breathe + 0.38 * heat + 0.035 * streak + 0.32 * (st.Inspect or 0) + 0.25 * math.exp(-ss / 0.12)
    core *= (1 - 0.94 * scram)
    if se < 0.75 then core *= smooth((se - 0.18) / 0.5) end
    st.Core = math.clamp(core, 0, 1)
    st.Barrel = math.clamp(0.45 + 0.4 * heat + 0.4 * math.exp(-ss / 0.1) + 0.04 * streak, 0, 1) * (1 - 0.8 * scram)
    -- the gauge: idles in the band, climbs with sustained fire, trembles; falls on a SCRAM; swings in on the draw
    local pr = 0.5 + 0.38 * heat + 0.02 * streak + 0.012 * math.sin(now * 23) + 0.008 * math.sin(now * 37 + 2)
    pr = pr * (1 - 0.75 * scram)
    if se < 0.9 then pr *= smooth((se - 0.3) / 0.55) end
    st.Pressure = math.clamp(pr, 0, 1)
    -- the hatch: open from the inspect's Tilt (the right side faces you) to just before Settle
    local hatch = 0
    if st.Anim == "Inspect" and st.AnimT and v.Beats then
        local b = v.Beats
        local t0 = (b.Tilt or b.Flip or 1.6) - 0.45
        local t1 = (b.Settle or (t0 + 1.2)) - 0.25
        hatch = smooth((st.AnimT - t0) / 0.3) * (1 - smooth((st.AnimT - t1) / 0.25))
    end
    st.Hatch = hatch
end
Set.Drive = function(rig: any, st: any, dt: number, now: number, H: any)
    local v = rig.SkinVars
    st.Anim, st.AnimT = rig.AnimName, rig.AnimTime
    v.Beats = rig.Anim and rig.Anim.Beats or v.Beats
    if rig.Def and rig.Def.IsMelee then
        local sw = v.SwingT and (now - v.SwingT) or 99
        local flare = v.FlareT and (now - v.FlareT) or 99
        local se = st.SinceEquip or 99
        local core = 0.5 + 0.08 * math.sin(now * 1.15) + 0.3 * math.exp(-sw / 0.25) + 0.45 * pulse(flare - 0.1, 0.3)
        if se < 0.6 then core *= smooth((se - 0.1) / 0.45) end
        st.Core = math.clamp(core, 0, 1)
        st.Scram, st.Pressure, st.Hatch = 0, 0.5, 0
        return
    end
    local sk = rig.Skin or {}
    FillKeys(st, v, dt, now, sk.PerShot or 0.08)
    -- (the SCRAM clunk + hiss is Set.Sounds.MagOut: the rig plays it on the gun's own MagOut event)
end
Set.OnAnim = function(rig: any, name: string)
    if rig.Def and rig.Def.IsMelee and (name:find("Light") or name:find("Heavy") or name:find("Quick")) then rig.SkinVars.SwingT = os.clock() end
end
Set.OnEvent = function(rig: any, name: string, H: any, data: any)
    local v = rig.SkinVars
    if not v then return end
    if rig.Def and rig.Def.IsMelee then
        if name == "Flip" then v.FlareT = os.clock() end
        return
    end
    if name == "Tilt" or name == "Flip" then
        -- the hatch slides, the vents breathe steam
        PlaySound(H, Set.Sounds.Hatch)
        local m = rig.Gun
        if m then for _, e in ipairs(m:GetDescendants()) do if e:IsA("ParticleEmitter") and e.Name == "FSteam" then e:Emit(6) end end end
    end
end
-- other players' guns: the breathing water and an idle needle; now and then a short surge
Set.World = function(rec: any, now: number, st: any)
    st.SinceShot = 99; st.SinceEquip = 99; st.Reload = 0; st.Streak = 1; st.Anim = nil; st.AnimT = nil; st.Inspect = 0
    local v = rec.Vars
    local dt = v.LastNow and math.clamp(now - v.LastNow, 0, 0.2) or 0
    v.LastNow = now
    FillKeys(st, v, dt, now, 0)
end

-- the inspect: the class inspect; the set's beats come from OnEvent (Tilt / Flip: the hatch sound + steam) and the Hatch
-- channel above (no extra timed events)

-- ===== muzzle: a compact blue-white flash, a Cherenkov shock ring, a wisp of steam =====
Set.Muzzle = function(rig: any, flash: ParticleEmitter, light: PointLight, muzzle: Attachment, H: any)
    flash.Color = ColorSequence.new(WHITE, GLOW)
    flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.05) })
    light.Color = GLOW
    light.Brightness = math.min(light.Brightness, 0.9)
    if rig.Fx and rig.Fx.Smoke then rig.Fx.Smoke.Color = ColorSequence.new(STEAM) end
    -- (gate, skins9: with Speed 0 the VelocityPerpendicular ring had no velocity to face along -- on the Ion Accelerator it
    -- drew as a huge blue-white triangle across the screen centre; it now drifts forward a little, like FERROFLUX's ring)
    rig.Fx.FRing = H.Emitter(muzzle, { Name = "FShockRing", Texture = ART.fs_ring, Color = { HOT, GLOW }, Size = { 0.05, 0.42 }, Life = { 0.11, 0.13 },
        Speed = { 1.5, 2.5 }, Trans = { 0.15, 1 }, Light = 1, Orient = Enum.ParticleOrientation.VelocityPerpendicular, Dir = Enum.NormalId.Right, Spread = 0 })
end
Set.OnFire = function(rig: any, H: any)
    local v = rig.SkinVars
    if rig.Fx and rig.Fx.FRing then rig.Fx.FRing:Emit(1) end
    if rig.Fx and rig.Fx.Smoke then
        -- (the wisp of steam: the engine's muzzle smoke, recoloured to steam in Set.Muzzle, one extra puff every 3rd shot)
        v.SteamN = ((v.SteamN or 0) + 1) % 3
        if v.SteamN == 0 then rig.Fx.Smoke:Emit(1) end
    end
end

-- ===== IONISED tracer: a thin white core inside a blue halo; the halo fades along the line from the muzzle out =====
Set.Tracer = function(H: any, from: Vector3, to: Vector3, peer: boolean?)
    local dist = (to - from).Magnitude
    if dist < 1.5 then return end
    local host = H.FxPart({ Size = V(0.05, 0.05, 0.05), Transparency = 1, CFrame = CFrame.new(from) })
    local a0, a1 = H.Att(host, from), H.Att(host, from)
    local halo = Instance.new("Beam")
    halo.Attachment0, halo.Attachment1 = a0, a1
    halo.FaceCamera, halo.LightEmission, halo.LightInfluence, halo.Segments = true, 1, 0, 1
    halo.Width0, halo.Width1 = 0.05, peer and 0.13 or 0.16
    halo.Color = ColorSequence.new(GLOW)
    halo.Parent = host
    local core = Instance.new("Beam")
    core.Attachment0, core.Attachment1 = a0, a1
    core.FaceCamera, core.LightEmission, core.LightInfluence, core.Segments = true, 1, 0, 1
    core.Width0, core.Width1 = 0.012, 0.03
    core.Color = ColorSequence.new(WHITE, HOT)
    core.Parent = host
    local dir = (to - from).Unit
    local travel = H.TRAVEL -- (hitscan: the shot is there at once, nothing flies)
    local life = travel + (peer and 0.1 or 0.13)
    H.Animate(life, function(t)
        local hk = math.clamp(t / travel, 0, 1)
        a1.WorldPosition = from + dir * dist * hk
        local f = math.clamp((t - travel) / (life - travel), 0, 1)
        -- the halo is thinnest + faintest at the muzzle end (the ionised air relaxing behind the round)
        halo.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.95), NumberSequenceKeypoint.new(0.6, 0.55 + 0.45 * f), NumberSequenceKeypoint.new(1, 0.25 + 0.75 * f) })
        core.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7 + 0.3 * f), NumberSequenceKeypoint.new(1, 0.05 + 0.95 * f) })
    end, function() host:Destroy() end)
end

-- ===== ION SPLASH impact: a blue disc of light splashing out flat on the surface, a few blue sparks, a steam puff and a
-- faint blue scorch that fades =====
Set.Impact = function(H: any, pos: Vector3, normal: Vector3?, peer: boolean?)
    if not H.Budget("FissionImpact", peer and 3 or 8, 0.8) then return end
    local nrm = (normal and normal.Magnitude > 0.1) and normal.Unit or V(0, 1, 0)
    local face = CFrame.lookAt(pos + nrm * 0.02, pos + nrm * 2) * H.ANG(0, H.R(90), 0)
    local splash = H.FxPart({ Shape = Enum.PartType.Cylinder, Size = V(0.012, 0.15, 0.15), CFrame = face, Color = HOT, Transparency = 0.1 })
    local scorch = H.FxPart({ Shape = Enum.PartType.Cylinder, Size = V(0.008, 0.34, 0.34), CFrame = face * CFrame.new(-0.004, 0, 0), Color = P.Scorch,
        Transparency = 0.35, Material = Enum.Material.SmoothPlastic })
    local att = H.Att(splash, pos + nrm * 0.05)
    if not peer then
        local sp = H.Emitter(att, { Name = "FSparks", Color = { HOT, GLOW }, Size = { 0.05, 0 }, Life = { 0.15, 0.3 }, Speed = { 2.5, 6 }, Spread = 60,
            Accel = V(0, -12, 0), Dir = Enum.NormalId.Left })
        sp:Emit(5)
    end
    local st = H.Emitter(att, { Name = "FImpSteam", Texture = H.SMOKE, Color = { STEAM, STEAM }, Size = { 0.1, 0.35 }, Life = { 0.35, 0.55 }, Speed = { 0.5, 1.2 },
        Spread = 40, Dir = Enum.NormalId.Left, Trans = { 0.7, 1 }, Light = 0, Influence = 1 })
    st:Emit(peer and 1 or 2)
    H.Animate(0.8, function(t)
        local k = math.clamp(t / 0.22, 0, 1)
        local r = 0.15 + 0.45 * (1 - (1 - k) ^ 2)
        splash.Size = V(0.012, r, r)
        splash.Color = HOT:Lerp(GLOW, k)
        splash.Transparency = 0.1 + 0.9 * smooth(t / 0.3)
        scorch.Transparency = 0.35 + 0.65 * smooth((t - 0.2) / 0.6)
    end, function() splash:Destroy(); scorch:Destroy() end)
end

-- (the dying body's visible parts, for the kill below)
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
            if p:IsA("BasePart") and p.Transparency < 0.6 and p.Size.Magnitude < 12 and #out < 22 then table.insert(out, p) end
        end
    end
    return out
end
-- ===== MELTDOWN kill (FX roll-out 2026-10-14; v1 DECAY recoloured the body neon blue and dropped a white ball into a pool
-- -- a body-shell recolour + a primitive ball). ONE idea: the body MELTS DOWN -- it sags (every part squashes and spreads
-- and slides down, the high parts most), glowing drips fall off it, and it runs into a Cherenkov-blue pool on the floor
-- that PULSES TWICE (a hot ring flashes out round it, 0.72 s and 0.92 s) and then DRAINS to its centre (1.4 s). The pool
-- is >= 6 studs across on a dark ink disc (reads on any floor); motion is all DOWN. Budget: full = 3 pool parts + <= 8
-- body parts + 4 drips; low: 3 pool parts + 3 body parts. =====
Set.Kill = function(H: any, pos: Vector3, low: boolean)
    local model = Instance.new("Model")
    model.Name = "FissionKill"
    model.Parent = H.FxFolder()
    local ground = H.Ground(pos)
    local axis = V(pos.X, ground.Y, pos.Z)
    local function disc(y, col, mat)
        return H.FxPart({ Shape = Enum.PartType.Cylinder, Size = V(0.04, 0.2, 0.2), CFrame = CFrame.new(axis + V(0, y, 0)) * H.ANG(0, 0, H.R(90)),
            Color = col, Transparency = 1, Material = mat }, model)
    end
    local ink = disc(0.03, P.Ink, Enum.Material.SmoothPlastic)
    local pool = disc(0.11, GLOW, Enum.Material.Neon)
    local ring = disc(0.07, HOT, Enum.Material.Neon)
    -- the body, melting (its own colours: it is the body that melts, not a glow shell)
    local bits = {}
    local srcs = BodyParts(pos, H)
    table.sort(srcs, function(a, b) return a.Size.Magnitude > b.Size.Magnitude end)
    for _, s in ipairs(srcs) do
        if #bits >= (low and 3 or 8) then break end
        local ok, c = pcall(function() return s:Clone() end)
        if ok and c then
            for _, ch in ipairs(c:GetChildren()) do
                if not (ch:IsA("SpecialMesh") or ch:IsA("DataModelMesh") or ch:IsA("SurfaceAppearance")) then ch:Destroy() end
            end
            c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
            c.Parent = model
            local hgt = math.max(0, c.Position.Y - ground.Y)
            table.insert(bits, { P = c, CF = c.CFrame, Size = c.Size, C0 = c.Color, Hgt = hgt, Start = 0.04 + math.random() * 0.06 })
        end
    end
    -- glowing drips off the sagging body
    local drips = {}
    if not low then
        for i = 1, 4 do
            local b = bits[((i - 1) % math.max(1, #bits)) + 1]
            local from = b and b.CF.Position or (axis + V(0, 2, 0))
            local d = H.FxPart({ Shape = Enum.PartType.Ball, Size = V(0.32, 0.32, 0.32), Color = HOT, Transparency = 1,
                CFrame = CFrame.new(from) }, model)
            table.insert(drips, { P = d, From = from + V((math.random() - 0.5) * 0.8, 0, (math.random() - 0.5) * 0.8), T0 = 0.12 + i * 0.09, Vy = 0 })
        end
    end
    local dur = low and 1.1 or 1.4
    H.Animate(dur, function(t, dt)
        -- 1) SAG (0.04 -> 0.6): squash + spread + slide down, the high parts furthest; colour runs toward the glow at the base
        for _, b in ipairs(bits) do
            local k = smooth((t - b.Start) / 0.56)
            local p = b.P
            local y = b.CF.Position.Y
            local drop = (y - ground.Y) * k * 0.92
            local sz = b.Size * V(1 + 0.5 * k, math.max(0.08, 1 - 0.85 * k), 1 + 0.5 * k)
            p.Size = sz
            p.CFrame = b.CF - V(0, drop, 0)
            p.Color = b.C0:Lerp(GLOW, math.clamp((k - 0.55) / 0.45, 0, 1) * 0.7)
            p.Transparency = smooth((t - 0.55) / 0.15)
        end
        -- 2) DRIPS fall off the body into the pool
        for _, d in ipairs(drips) do
            if t >= d.T0 then
                local tt = t - d.T0
                local y = d.From.Y - 0.5 * 30 * tt * tt
                if y > ground.Y + 0.1 then
                    d.P.CFrame = CFrame.new(d.From.X, y, d.From.Z)
                    d.P.Size = V(0.26, 0.26 + math.min(0.4, tt * 1.6), 0.26)
                    d.P.Transparency = 0
                else
                    d.P.Transparency = 1
                end
            end
        end
        -- 3) the POOL: spreads under the melt (0.15 -> 0.6), pulses twice, drains to its centre (1.0 -> 1.4)
        local spread = smooth((t - 0.15) / 0.45)
        local drain = smooth((t - (dur - 0.42)) / 0.4)
        local R = 3.2 * spread * (1 - drain)
        local function pulse(at) return math.exp(-((t - at) / 0.07) ^ 2) end
        local p1, p2 = pulse(low and 0.6 or 0.72), pulse(low and 0.78 or 0.92)
        local pk = math.max(p1, p2)
        local dia = math.max(0.1, R * 2)
        pool.Size = V(0.04, dia, dia)
        ink.Size = V(0.03, dia + 0.5, dia + 0.5)
        -- (opaque: transparent discs this close sort wrongly and the ink drew over the pool)
        pool.Transparency = (R < 0.05) and 1 or 0
        pool.Color = GLOW:Lerp(HOT, pk * 0.6)
        ink.Transparency = (R < 0.05) and 1 or 0
        pool.CFrame = CFrame.new(axis + V(0, 0.11, 0)) * CFrame.Angles(0, t * 3 * drain, 0) * H.ANG(0, 0, H.R(90))
        -- the pulse ring flashes OUT from the pool's edge
        local ringK = (t < (low and 0.7 or 0.82)) and math.clamp((t - (low and 0.6 or 0.72) + 0.1) / 0.3, 0, 1) or math.clamp((t - (low and 0.78 or 0.92) + 0.1) / 0.3, 0, 1)
        local rd = dia + 0.4 + 2.2 * ringK
        ring.Size = V(0.025, rd, rd)
        ring.Transparency = (spread < 0.5) and 1 or (0.25 + 0.75 * ringK)
    end, function() model:Destroy() end)
end

-- ===== REACTOR GAUGE banner (lower right, beside the weapon card): a round dial plate with five zones; the needle steps one
-- zone per kill of the streak; at 5 the dial floods with the glow =====
local banner
Set.Banner = function(H: any, streak: number)
    local gui, root = H.BannerRoot("Fission", Vector2.new(180, 90), "Side")
    if not root then return end
    if not banner or banner.Root ~= root then
        local New = H.New
        local plate = New("Frame", { BackgroundColor3 = P.Ink:Lerp(DARK, 0.4), BackgroundTransparency = 0.1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, root,
            { New("UIStroke", { Color = P.Mid, Thickness = 1.5 }) })
        local glowBack = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.fs_ring, ImageColor3 = GLOW, ImageTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(46, 46), Size = UDim2.fromOffset(92, 92) }, plate)
        local dial = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.fs_dial, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(46, 46),
            Size = UDim2.fromOffset(78, 78) }, plate)
        local zones = {}
        for i = 1, 5 do
            zones[i] = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.fs_zone, ImageColor3 = P.Dim, AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(46, 46), Size = UDim2.fromOffset(78, 78), Rotation = -96 + (i - 1) * 48 }, plate)
        end
        local needle = New("ImageLabel", { BackgroundTransparency = 1, Image = ART.fs_needle, ImageColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(46, 46), Size = UDim2.fromOffset(78, 78), Rotation = -120 }, plate)
        local num = New("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(96, 22), Size = UDim2.fromOffset(78, 34), Font = Enum.Font.Oswald,
            TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = P.Text, Text = "" }, plate)
        local word = New("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(96, 56), Size = UDim2.fromOffset(78, 16), Font = Enum.Font.Oswald,
            TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GLOW, Text = "" }, plate)
        banner = { Root = root, Plate = plate, Dial = dial, Zones = zones, Needle = needle, Num = num, Word = word, Glow = glowBack, Token = 0, T0 = 0, From = -120, To = -120 }
        H.RunService.RenderStepped:Connect(function()
            local b = banner
            if not (b and b.Root.Visible) then return end
            local t = os.clock() - b.T0
            -- the needle swings to its zone with a small overshoot and settles trembling
            local k = math.clamp(t / 0.3, 0, 1)
            local ease = 1 - (1 - k) ^ 3
            local over = math.sin(math.clamp((t - 0.22) / 0.3, 0, 1) * math.pi) * 6 * (1 - math.clamp((t - 0.22) / 0.3, 0, 1))
            b.Needle.Rotation = b.From + (b.To - b.From) * ease + over + math.sin(os.clock() * 31) * 0.6
        end)
    end
    local b = banner
    b.Token += 1
    local token = b.Token
    root.Visible = true
    b.T0 = os.clock()
    local n = math.clamp(streak, 1, 5)
    b.From = (n == 1) and -120 or (-120 + (n - 1.5) * 48)
    b.To = -120 + (n - 0.5) * 48
    b.Num.Text = "x" .. tostring(streak)
    b.Word.Text = (n >= 5) and "CRITICAL" or "PRESSURE"
    b.Word.TextColor3 = (n >= 5) and HOT or GLOW
    for i, z in ipairs(b.Zones) do z.ImageColor3 = (i <= n) and GLOW or P.Dim; z.ImageTransparency = 0 end
    b.Glow.ImageTransparency = (n >= 5) and 0.25 or 1
    b.Plate.BackgroundTransparency = 0.1
    for _, o in ipairs({ b.Dial, b.Needle }) do o.ImageTransparency = 0 end
    b.Num.TextTransparency = 0; b.Word.TextTransparency = 0
    task.delay(1.4, function()
        if b.Token ~= token then return end
        local ti = TweenInfo.new(0.3)
        H.TweenService:Create(b.Plate, ti, { BackgroundTransparency = 1 }):Play()
        for _, o in ipairs({ b.Dial, b.Needle, b.Glow }) do H.TweenService:Create(o, ti, { ImageTransparency = 1 }):Play() end
        for _, z in ipairs(b.Zones) do H.TweenService:Create(z, ti, { ImageTransparency = 1 }):Play() end
        H.TweenService:Create(b.Num, ti, { TextTransparency = 1 }):Play()
        H.TweenService:Create(b.Word, ti, { TextTransparency = 1 }):Play()
        task.delay(0.32, function() if b.Token == token then root.Visible = false end end)
    end)
end

-- ===== the CONTROL ROD (melee, Blunt class): a heavy hammer whose head is a shielded rod housing with a sight port (the
-- water glowing inside), a graphite haft with steel bands; the port flares at the inspect's peak =====
Set.Melee = {
    Skin = { Name = "Control Rod", Price = 449, ProductId = 0,
        Desc = "A heavy hammer built round a reactor control-rod housing: a shielded steel head with a bolted sight port where the water glows Cherenkov blue, a graphite haft with steel bands and a lead-grey grip. Every swing brightens the core, and the inspect flares it. Every kill DECAYS." },
    Rig = { Class = "Blunt", BladeLen = 1.1 },
    InspectEvents = { { "Flip", "Emit", { Name = "FRodSteam", Count = 8 } } },
    Build = function(m: Model, o: any, H: any)
        local parts = H.CloneModel(m, "MeleeModels", "Fission", VAR, { [1] = GLOW, [2] = HOT })
        local head = parts.Blade or parts.Head
        if head then
            local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
            a0.Name, a1.Name = "TrailBase", "TrailTip"
            a0.Position = head.CFrame:PointToObjectSpace(head.CFrame:PointToWorldSpace(V(0, 0, 0)) + head.CFrame.RightVector * -0.12)
            a1.Position = head.CFrame:PointToObjectSpace(head.CFrame:PointToWorldSpace(V(0, 0, 0)) + head.CFrame.RightVector * 0.12)
            a0.Parent, a1.Parent = head, head
            local tr = Instance.new("Trail")
            tr.Attachment0, tr.Attachment1 = a0, a1
            tr.Color = ColorSequence.new(HOT, GLOW)
            tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
            tr.LightEmission, tr.LightInfluence = 0.8, 0
            tr.Lifetime, tr.MinLength, tr.FaceCamera = 0.14, 0.02, true
            tr.Enabled = false
            tr:SetAttribute("SwingTrail", true)
            tr.Parent = head
            local sa = Instance.new("Attachment"); sa.Parent = head
            H.Emitter(sa, { Name = "FRodSteam", Texture = H.SMOKE, Color = { STEAM, STEAM }, Size = { 0.08, 0.35 }, Life = { 0.5, 0.8 }, Speed = { 0.4, 1 },
                Accel = V(0, 1.2, 0), Trans = { 0.7, 1 }, Light = 0, Influence = 1, Spread = 40, SkinFx = true })
        end
        for _, p in ipairs(m:GetDescendants()) do
            if p:IsA("BasePart") and string.find(p.Name, "^Glow_") then p:SetAttribute("GlowCold", 0.88); p:SetAttribute("GlowHot", 0) end
        end
    end,
}

-- ===== arms: CONTAINMENT GLOVES + SEALED SLEEVES (mesh pieces, WeaponAssets.ArmsModels.Fission) =====
-- glove: a thick lead-grey rubber glove with a steel wrist ring; ONE effect: a dosimeter badge on the wrist whose blue bar
-- slowly fills and drops back (it fills at once on a kill)
Set.Glove = function(K: any)
    local V3 = K.V
    return {
        Id = "ContainmentGloves", Name = "Containment Gloves", Price = 449,
        Desc = "Thick lead-grey rubber containment gloves with a ribbed back, a steel wrist ring and a dosimeter badge clipped to the cuff. The badge's blue bar slowly fills and drops back, and fills at once on a kill.",
        -- (skins12 touch-up, arms bar: a grip-stippled rubber on the hand block + a steel taped seam down each side -- the
        -- block read as one flat grey colour)
        Base = { Color = P.Detail:Lerp(C(0, 0, 0), 0.25), Material = K.SMOOTH, Reflectance = 0.03, Tex = "tex_fs_rubber", TexTile = 0.8, TexT = 0,
                 TexColor = P.Detail:Lerp(C(0, 0, 0), 0.05) },
        Parts = {
            { Mesh = "Fission/Back", MeshV = VAR, Size = V3(0.96, 0.11, 0.86), Off = V3(0, 0.53, -0.04) },
            { Size = V3(0.04, 0.07, 0.74), Off = V3(0.5, 0.12, -0.06), Color = P.Mid, Material = K.SMOOTH, Reflectance = 0.06 },
            { Size = V3(0.04, 0.07, 0.74), Off = V3(-0.5, 0.12, -0.06), Color = P.Mid, Material = K.SMOOTH, Reflectance = 0.06 },
            { Mesh = "Fission/Ring", MeshV = VAR, Size = V3(1.18, 1.18, 0.16), Off = V3(0, 0, 0.42) },
            { Mesh = "Fission/Badge", MeshV = VAR, Size = V3(0.34, 0.07, 0.29), Off = V3(0, 0.55, 0.3), Seat = true },
            { Size = V3(0.05, 0.02, 0.16), Off = V3(0, 0.6, 0.22), Color = GLOW, Glow = true, Seat = true, Root = 1, Anim = "Fill", Period = 7, MinScale = 0.08, BurstOn = "Kill" },
        },
    }
end
-- sleeve: a sealed suit sleeve: a sculpted ribbed accordion section at the wrist and a heavy cuff ring with clamps
Set.Sleeve = function(K: any)
    local V3 = K.V
    return {
        Id = "SealedSleeves", Name = "Sealed Sleeves", Price = 299,
        Desc = "A sealed suit sleeve in dark graphite rubber: a sculpted ribbed accordion section at the wrist and a heavy steel cuff ring held by clamps. Part of the Fission set.",
        -- (skins12 touch-up, arms bar: the long side face of the sleeve filled the left of the screen as one flat graphite
        -- block -> a rubber-coated suit fabric on the block, a heat-sealed steel tape seam down each flank and a small
        -- bolted suit valve on the forearm)
        Base = { Color = P.Body, Material = K.SMOOTH, Reflectance = 0.03, Tex = "tex_fs_suit", TexTile = 1.0, TexT = 0, TexColor = P.Body:Lerp(C(255, 255, 255), 0.06) },
        Parts = {
            { Mesh = "Fission/Accordion", MeshV = VAR, Size = V3(1.1, 1.1, 0.34), Off = V3(0, 0, -0.3) },
            { Mesh = "Fission/Cuff", MeshV = VAR, Size = V3(1.28, 1.28, 0.2), Off = V3(0, 0, -0.06) },
            { Mesh = "Fission/Seam", MeshV = VAR, Size = V3(0.14, 0.07, 0.8), Off = V3(0, 0.535, 0.1) },
            { Size = V3(0.045, 0.09, 0.56), Off = V3(0.5, 0.08, 0.24), Color = P.Mid, Material = K.SMOOTH, Reflectance = 0.06 },
            { Size = V3(0.045, 0.09, 0.56), Off = V3(-0.5, 0.08, 0.24), Color = P.Mid, Material = K.SMOOTH, Reflectance = 0.06 },
            { Size = V3(0.06, 0.2, 0.2), Off = V3(0.5, -0.18, 0.3), Color = P.Detail, Material = K.SMOOTH, Reflectance = 0.05 },
            { Size = V3(0.08, 0.1, 0.1), Off = V3(0.5, -0.18, 0.3), Color = P.Mid, Material = K.METAL, Reflectance = 0.15 },
            { Size = V3(0.06, 0.2, 0.2), Off = V3(-0.5, -0.18, 0.3), Color = P.Detail, Material = K.SMOOTH, Reflectance = 0.05 },
            { Size = V3(0.08, 0.1, 0.1), Off = V3(-0.5, -0.18, 0.3), Color = P.Mid, Material = K.METAL, Reflectance = 0.15 },
        },
    }
end

-- ===== health bar v2 (BARS v2, FX roll-out): a coolant tube in the house ink frame -- a Cherenkov-blue fill with dark fuel
-- rods standing in it (elites / bosses), and every hit sends bubbles up out of the lost piece (v1's bubbles, kept) =====
Set.Bar = { Id = "Fission", Name = "Fission", Price = 149,
    Desc = "The enemy's health as a coolant tube: Cherenkov-blue water in an ink frame, dark fuel rods standing in it on elites and bosses, and every hit sends bubbles up out of the water. Part of the Fission set.",
    Look = "Ink", FillColor = GLOW, ChipMotion = "Drain", Chip = HOT, Back = C(6, 10, 18), Segments = 5, Decor = { "Rods", "Bubbles" } }
Set.BarDecor = {
    Rods = function(ctx: any, K: any)
        if ctx.Tier == "Small" then return function() end end
        local rods = {}
        local n = (ctx.Tier == "Boss") and 9 or 4
        for i = 1, n do
            rods[i] = K.New("Frame", { BorderSizePixel = 0, BackgroundColor3 = DARK, AnchorPoint = Vector2.new(0.5, 1), ZIndex = 4 }, ctx.Inner)
        end
        return function(now, dt, alpha, info)
            for i, r in ipairs(rods) do
                r.Size = UDim2.new(0, math.max(2, ctx.H * 0.22), 0.72, 0)
                r.Position = UDim2.new((i - 0.5) / n, 0, 1, 0)
                r.BackgroundTransparency = 1 - alpha * 0.55
            end
        end
    end,
    Bubbles = function(ctx: any, K: any)
        local pool = {}
        for i = 1, 6 do
            pool[i] = { Img = K.Img("fs_bubble", { AnchorPoint = Vector2.new(0.5, 0.5), ImageColor3 = HOT, ImageTransparency = 1, ZIndex = 12 }, ctx.Holder), T = 99, X = 0, S = 1 }
        end
        local kick, nextI = 0, 1
        return function(now, dt, alpha, info)
            local hit = info.Hit or 0
            if hit > kick + 0.2 then
                -- a hit: three bubbles rise out of the piece it took
                local x0 = info.DropX0 or (ctx.W * math.max(0.02, info.Shown))
                local x1 = info.DropX1 or x0
                for _ = 1, 3 do
                    local b = pool[nextI]; nextI = nextI % #pool + 1
                    b.T = 0; b.X = x0 + (x1 - x0) * math.random(); b.S = 0.4 + math.random() * 0.3
                end
            end
            kick = math.max(hit, kick - dt * 3)
            for _, b in ipairs(pool) do
                b.T += dt
                local k = b.T / 0.7
                if k < 1 then
                    local sz = math.max(5, ctx.H * b.S * 1.4)
                    b.Img.Size = UDim2.fromOffset(sz, sz)
                    b.Img.Position = UDim2.fromOffset(b.X + math.sin(b.T * 14) * 2, ctx.H * (0.75 - 1.6 * k))
                    b.Img.ImageTransparency = 1 - alpha * (1 - k) * 0.95
                else
                    b.Img.ImageTransparency = 1
                end
            end
        end
    end,
}

-- ===== UI theme v2 (FX roll-out 2026-10-14; v1 = the shared template): a REACTOR PANEL, icon look. Hex bolts in the four
-- corners, a COOLANT GAUGE down the window's left edge (a glass tube whose Cherenkov-blue level breathes, a bubble rising
-- in it now and then), a small PRESSURE DIAL on every title bar whose needle swings into the red and settles when the
-- window opens (its own open: a blue coolant line sweeps up the window). Colours from the theme table (Steel / Glow / Hot /
-- Ink / Red). =====
local function FsBolt(parent, z, t, s)
    local b = Instance.new("Frame")
    b.Name = "FsBolt"; b.BorderSizePixel = 0; b.BackgroundColor3 = t.Steel; b.AnchorPoint = Vector2.new(0.5, 0.5); b.Size = UDim2.fromOffset(s, s)
    b.Rotation = 45; b.ZIndex = z
    local st = Instance.new("UIStroke"); st.Color = t.Ink; st.Thickness = 1.5; st.Parent = b
    local g = Instance.new("UIGradient"); g.Rotation = 90
    g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, t.Steel:Lerp(Color3.new(1, 1, 1), 0.3)), ColorSequenceKeypoint.new(0.49, t.Steel:Lerp(Color3.new(1, 1, 1), 0.3)),
        ColorSequenceKeypoint.new(0.5, t.Steel), ColorSequenceKeypoint.new(1, t.Steel:Lerp(t.Ink, 0.3)) })
    g.Parent = b
    b.Parent = parent
    return b
end
local function FsDeco(ctx)
    if ctx.Kind ~= "Window" then return nil end
    local t = ctx.Theme
    local host = ctx.Root or ctx.Surface
    local f = Instance.new("Frame")
    f.Name = "FsOverlay"; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = 20; f.Active = false
    f:SetAttribute("NoSkin", true); f:SetAttribute("Skinned", true)
    f.Parent = host
    local abs = host.AbsoluteSize
    local small = math.min(abs.X, abs.Y) < 260
    local s = small and 8 or 12
    for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
        local b = FsBolt(f, f.ZIndex + 1, t, s)
        b.Position = UDim2.new(c[1], (c[1] == 0) and 9 or -9, c[2], (c[2] == 0) and 9 or -9)
    end
    if small then return nil, { f } end
    -- the coolant gauge: a glass tube on the left edge, below the title bar
    local tube = Instance.new("Frame")
    tube.Name = "FsTube"; tube.BorderSizePixel = 0; tube.BackgroundColor3 = t.Ink; tube.BackgroundTransparency = 0.15
    tube.AnchorPoint = Vector2.new(0, 1); tube.Position = UDim2.new(0, 4, 1, -30); tube.Size = UDim2.new(0, 8, 0.5, 0); tube.ZIndex = f.ZIndex + 1
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(1, 0); tc.Parent = tube
    local ts = Instance.new("UIStroke"); ts.Color = t.Steel; ts.Thickness = 1.5; ts.Parent = tube
    tube.Parent = f
    local level = Instance.new("Frame")
    level.BorderSizePixel = 0; level.BackgroundColor3 = t.Glow; level.AnchorPoint = Vector2.new(0.5, 1); level.Position = UDim2.new(0.5, 0, 1, -2)
    level.Size = UDim2.new(1, -4, 0.6, 0); level.ZIndex = f.ZIndex + 2
    local lc = Instance.new("UICorner"); lc.CornerRadius = UDim.new(1, 0); lc.Parent = level
    level.Parent = tube
    local bub = Instance.new("Frame")
    bub.BorderSizePixel = 0; bub.BackgroundColor3 = t.Hot; bub.AnchorPoint = Vector2.new(0.5, 0.5); bub.Size = UDim2.fromOffset(3, 3); bub.ZIndex = f.ZIndex + 3
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(1, 0); bc.Parent = bub
    bub.Parent = tube
    return function(now, dt)
        local lv = 0.55 + 0.25 * math.sin(now * 0.6) + 0.04 * math.sin(now * 3.1)
        level.Size = UDim2.new(1, -4, lv, -2)
        local cyc = now % 3.4
        if cyc < 1.4 then
            bub.Visible = true
            bub.Position = UDim2.new(0.5, math.sin(now * 9) * 1.2, 1 - lv * (cyc / 1.4), -3)
        else
            bub.Visible = false
        end
    end, { f }
end
local function FsOpen(ctx)
    -- the coolant line sweeps up the window (0.36 s) and the title's pressure needle swings into the red, then settles
    local t = ctx.Theme
    local root = ctx.Root
    if not root then return end
    local f = root:FindFirstChild("FsOverlay") or ctx.Frame
    local line = Instance.new("Frame")
    line.BorderSizePixel = 0; line.BackgroundColor3 = t.Glow; line.AnchorPoint = Vector2.new(0.5, 0.5); line.Position = UDim2.fromScale(0.5, 1)
    line.Size = UDim2.new(1, 0, 0, 3); line.ZIndex = f.ZIndex + 6
    local g = Instance.new("UIGradient"); g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }); g.Parent = line
    line.Parent = f
    ctx.Tween:Create(line, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0), BackgroundTransparency = 1 }):Play()
    task.delay(0.36, function() line:Destroy() end)
    local needle = root:FindFirstChild("FsNeedle", true)
    if needle then
        needle.Rotation = -110
        ctx.Tween:Create(needle, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 70 }):Play()
        task.delay(0.24, function()
            if needle.Parent then ctx.Tween:Create(needle, TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 10 }):Play() end
        end)
    end
end
local function FsTitle(ctx)
    -- a small pressure dial on the title bar (right side): steel rim, ink face, a red zone, a white needle
    local bar, t = ctx.Title, ctx.Theme
    local h = math.max(bar.AbsoluteSize.Y, 30)
    local dial = Instance.new("Frame")
    dial.Name = "FsDial"; dial.BorderSizePixel = 0; dial.BackgroundColor3 = t.Ink; dial.AnchorPoint = Vector2.new(1, 0.5)
    dial.Size = UDim2.fromOffset(24, 24); dial.Position = UDim2.new(1, -(h * 2.9 + 14), 0.5, 0); dial.ZIndex = bar.ZIndex + 1
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = dial
    local st = Instance.new("UIStroke"); st.Color = t.Steel; st.Thickness = 2; st.Parent = dial
    local red = Instance.new("Frame")
    red.BorderSizePixel = 0; red.BackgroundColor3 = t.Red; red.AnchorPoint = Vector2.new(0.5, 0.5); red.Position = UDim2.new(0.5, 6, 0.5, -5)
    red.Size = UDim2.fromOffset(5, 3); red.Rotation = 40; red.ZIndex = bar.ZIndex + 2
    red.Parent = dial
    local pivot = Instance.new("Frame")
    pivot.Name = "FsNeedle"; pivot.BackgroundTransparency = 1; pivot.AnchorPoint = Vector2.new(0.5, 0.5); pivot.Position = UDim2.fromScale(0.5, 0.5)
    pivot.Size = UDim2.fromOffset(20, 20); pivot.Rotation = 10; pivot.ZIndex = bar.ZIndex + 3
    pivot.Parent = dial
    local needle = Instance.new("Frame")
    needle.BorderSizePixel = 0; needle.BackgroundColor3 = t.Hot; needle.AnchorPoint = Vector2.new(0.5, 1); needle.Position = UDim2.fromScale(0.5, 0.5)
    needle.Size = UDim2.fromOffset(2, 9); needle.ZIndex = bar.ZIndex + 3
    needle.Parent = pivot
    dial.Parent = bar
    return { dial }
end
-- numbers v3 (SKIN UI 2026-10-29, owner: numbers "unique to the skin and the colorways you have equipped"): A REACTOR READOUT.
-- A monospaced readout that COUNTS UP to its total (the digits roll, a Geiger crackle for a moment) in a small window of dark
-- lead glass lit from inside by CHERENKOV light, its rim breathing in the colourway's glow (a soft glow sprite alone did not
-- show on bright floors). CRIT = the core goes critical: the window flares and its rim burns brighter and thicker; WEAK
-- SPOT = a porthole glyph in front; a KILL = MELTDOWN: the number sags and glowing drips run off its bottom edge while the
-- window's light drains. Every colour is this copy's palette P.
local FS_DRIPS = 3
local function FsMotion(e, age, pa, life)
    local k = math.min(1, age / 0.9)
    local ease = 1 - (1 - k) ^ 2
    local jit = (math.floor(age * 24 + e.Seed * 7) % 2 == 0) and 1 or -1
    local kt = (e.Killed and e.KillAt) and (os.clock() - e.KillAt) or nil
    local sag = kt and math.min(1, kt / 0.5) or 0
    return 0.5 + ease * 1.3 * (1 - 0.6 * sag), (age < 0.25) and 0.04 * jit or 0, 1 - 0.06 * sag, 10 * sag, 0, 0
end
local function FsAccent(e)
    local box = Instance.new("Frame")
    box.Name = "FsCore"; box.BackgroundTransparency = 1; box.Size = UDim2.fromScale(1, 1); box.ZIndex = 0
    -- the readout window: dark lead glass lit from inside by the Cherenkov glow (a rounded pane + its lit rim)
    local pool = Instance.new("Frame")
    pool.Name = "Pool"; pool.BorderSizePixel = 0; pool.AnchorPoint = Vector2.new(0.5, 0.5); pool.Position = UDim2.fromScale(0.5, 0.5); pool.ZIndex = 0
    local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 6); pc.Parent = pool
    local pg = Instance.new("UIGradient"); pg.Rotation = 90; pg.Parent = pool
    local ps = Instance.new("UIStroke"); ps.Thickness = 1.5; ps.Parent = pool
    pool.Parent = box
    for i = 1, FS_DRIPS do
        local d = Instance.new("Frame")
        d.Name = "Drip" .. i; d.BorderSizePixel = 0; d.AnchorPoint = Vector2.new(0.5, 0); d.Size = UDim2.fromOffset(4, 7); d.ZIndex = 2
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = d
        d.Parent = box
    end
    return box
end
local function FsAccentStep(e, box, age, pa, alpha)
    local tb = e.Label.TextBounds
    local kt = (e.Killed and e.KillAt) and (os.clock() - e.KillAt) or nil
    local pool = box:FindFirstChild("Pool")
    if pool then
        local breathe = 0.5 + 0.5 * math.sin(age * 4 + e.Seed)
        local crit = (e.Crit and not e.Dot) and math.max(0.3, 1 - pa / 0.3) or 0
        local spread = kt and math.min(1, kt / 0.5) or 0
        pool.Visible = not e.Dot
        pool.Size = UDim2.fromOffset(tb.X + 16 + 10 * crit, tb.Y + 2 + 6 * crit)
        pool.Position = UDim2.new(0.5, 0, 0.5, 1)
        local lit = GLOW:Lerp(HOT, 0.35 * crit)
        pool.BackgroundColor3 = P.Ink:Lerp(lit, 0.28 + 0.1 * breathe + 0.3 * crit)
        pool.BackgroundTransparency = math.clamp(alpha + 0.22 + 0.3 * spread, 0, 1)
        local g = pool:FindFirstChildOfClass("UIGradient")
        if g then g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.55, 0.55, 0.55)) end
        local st = pool:FindFirstChildOfClass("UIStroke")
        if st then
            st.Color = lit; st.Thickness = 1.5 + 1.5 * crit
            st.Transparency = math.clamp(alpha + 0.45 - 0.25 * breathe - 0.4 * crit, 0, 1)
        end
    end
    for i = 1, FS_DRIPS do
        local d = box:FindFirstChild("Drip" .. i)
        if d then
            local t = kt and (kt - (i - 1) * 0.12) or -1
            local on = t > 0 and t < 0.6
            d.Visible = on
            if on then
                local q = t / 0.6
                d.Position = UDim2.new(0.5, (i - 2) * tb.X * 0.28, 0.5, tb.Y * 0.35 + 30 * q * q)
                d.Size = UDim2.fromOffset(4, math.floor(5 + 6 * q))
                d.BackgroundColor3 = HOT:Lerp(GLOW, q); d.BackgroundTransparency = math.clamp(alpha + q * 0.8, 0, 1)
            end
        end
    end
end
-- ===== UI THEME v4 (SKIN UI THEMES 2026-10-29 roll-out, owner: themes must "change up the colorways and provide a bit more
-- style than the default", no stretched header art): the clean language in this colourway's reactor steel (UITheme Clean:
-- roles from P) + two touches of a reactor. Hooks read only the palette they are given (a colourway copy shares them):
--   TAB MARK  CONTROL RODS: three dark rods wait under the Cherenkov-lit bar; the bar breathes, and now and then the selected
--             tab SCRAMs -- the rods drive up into it, the light dies, they withdraw and it comes back (under the bar: above it
--             they ran into the tab words)
--   FIELD     a needle PRESSURE GAUGE in the lower right (the dial art at its own shape, tinted in the steel and the glow) whose
--             needle trembles at idle and climbs + falls back with each SCRAM cycle
local FS_CLEAN = {
    Field = P.Dark:Lerp(C(0, 0, 0), 0.2), Surface = P.Dark:Lerp(P.Body, 0.45), Raised = P.Body:Lerp(P.Dark, 0.22), Hover = P.Body:Lerp(P.Mid, 0.65),
    Well = P.Dark, Line = P.Mid:Lerp(P.Steam, 0.16), Tip = P.Dark:Lerp(P.Body, 0.3),
    Accent = P.Glow, Mark = P.Glow, Hair = P.Steam:Lerp(P.Mid, 0.45),
    Text = P.Text, Sub = P.Steam:Lerp(P.Mid, 0.3), Muted = P.Mid:Lerp(P.Steam, 0.5), Ink = P.Ink,
    Rod = P.Steam:Lerp(P.Dark, 0.5), Core = P.Glow, CoreHot = P.Hot, Steel = P.Mid, Dial = P.Steam, InkLine = P.Ink,
}
local FS_ROD_X = { -10, -2, 6 }
FS_CLEAN.TabMark = function(mark, Q)
    -- (offset children anchored at their left / top, inside the mark: tab buttons size themselves to their children)
    local made = {}
    local g = Instance.new("UIGradient")
    g.Name = "FsLight"; g.Color = ColorSequence.new(Color3.new(1, 1, 1)); g.Parent = mark
    table.insert(made, g)
    for i = 1, 3 do
        local r = Instance.new("Frame")
        r.Name = "FsRod"; r.BorderSizePixel = 0; r.BackgroundColor3 = Q.Rod; r.Size = UDim2.fromOffset(3, 7)
        r.Position = UDim2.new(0.5, FS_ROD_X[i], 0, 4); r.ZIndex = mark.ZIndex + 1
        r.Parent = mark
        table.insert(made, r)
    end
    return made
end
FS_CLEAN.Sig = function(ctx)
    local Q, f = ctx.P, ctx.Frame
    local cam = workspace.CurrentCamera
    local vh = (cam and cam.ViewportSize.Y or 800)
    local D = math.clamp(math.floor(vh * 0.16), 90, 150)
    local dial = Instance.new("ImageLabel")
    dial.Name = "FsGauge"; dial.BackgroundTransparency = 1; dial.Image = ART.fs_dial; dial.ScaleType = Enum.ScaleType.Fit
    dial.ImageColor3 = Q.Dial; dial.ImageTransparency = 0.2; dial.AnchorPoint = Vector2.new(1, 1); dial.Position = UDim2.new(1, -18, 1, -16)
    dial.Size = UDim2.fromOffset(D, D); dial.ZIndex = 0; dial.Parent = f
    -- the red-line arc: a lit sector of the glow behind the top right ticks
    local zone = Instance.new("ImageLabel")
    zone.Name = "FsZone"; zone.BackgroundTransparency = 1; zone.Image = ART.fs_zone; zone.ScaleType = Enum.ScaleType.Fit
    zone.ImageColor3 = Q.Core; zone.ImageTransparency = 0.35; zone.Size = UDim2.fromScale(1, 1); zone.Rotation = 40; zone.ZIndex = 1; zone.Parent = dial
    local pivot = Instance.new("Frame")
    pivot.Name = "FsPivot"; pivot.BackgroundTransparency = 1; pivot.AnchorPoint = Vector2.new(0.5, 0.5); pivot.Position = UDim2.fromScale(0.5, 0.5)
    pivot.Size = UDim2.fromScale(1, 1); pivot.ZIndex = 2; pivot.Parent = dial
    local needle = Instance.new("ImageLabel")
    needle.Name = "FsNeedle"; needle.BackgroundTransparency = 1; needle.Image = ART.fs_needle; needle.ScaleType = Enum.ScaleType.Fit
    needle.ImageColor3 = Q.CoreHot; needle.Size = UDim2.fromScale(1, 1); needle.ZIndex = 2; needle.Parent = pivot
    local word = Instance.new("TextLabel")
    word.Name = "FsReadout"; word.BackgroundTransparency = 1; word.AnchorPoint = Vector2.new(0.5, 0); word.Position = UDim2.new(0.5, 0, 0.62, 0)
    word.Size = UDim2.fromOffset(60, 14); word.Font = Enum.Font.RobotoMono; word.TextSize = 12; word.TextColor3 = Q.Core; word.ZIndex = 3
    word:SetAttribute("NoSnap", true); word:SetAttribute("KeepFont", true); word:SetAttribute("TextRole", "Glyph"); word.Parent = dial
    local seed = math.random() * 9
    local lastTxt = ""
    return function(now, _dt)
        -- the SCRAM cycle (~9 s): 0..0.35 rods drop + the light dies, 0.35..1.3 dark, 1.3..2.2 rods withdraw + it comes back
        local c = (now + seed) % 9
        local light, rod
        if c < 0.35 then light, rod = 1 - c / 0.35, c / 0.35
        elseif c < 1.3 then light, rod = 0, 1
        elseif c < 2.2 then local k = (c - 1.3) / 0.9; light, rod = k, 1 - k
        else light, rod = 1, 0 end
        local breathe = 0.82 + 0.18 * math.sin(now * 1.1)
        local lv = 0.12 + 0.88 * light * breathe
        -- the needle: trembles at idle, sits high while the core runs, falls on a SCRAM
        local ang = -110 + 175 * (0.25 + 0.6 * light) + math.sin(now * 23) * 1.4 + math.sin(now * 7.3) * 2
        pivot.Rotation = ang
        local txt = string.format("%03d%%", math.floor((0.25 + 0.6 * light) * 100 + 0.5))
        if txt ~= lastTxt then lastTxt = txt; word.Text = txt end
        zone.ImageTransparency = 0.35 + 0.5 * (1 - light)
        for _, m in ipairs(ctx.Marks()) do
            if m.Visible then
                local g = m:FindFirstChild("FsLight"); if g then g.Color = ColorSequence.new(Color3.new(lv, lv, lv)) end
                for _, r in ipairs(m:GetChildren()) do
                    if r.Name == "FsRod" then r.Position = UDim2.new(0.5, r.Position.X.Offset, 0, 4 - math.floor(7 * rod + 0.5)) end
                end
            end
        end
    end, nil
end
local P1 = PALETTES[1]
Set.Theme = { Name = "Fission", Desc = "A reactor's control panel: control rods stand over every tab's glowing Cherenkov bar and now and then SCRAM down into it, and a needle pressure gauge in the corner trembles, climbs and falls with the core.",
    Panel = { Top = C(14, 22, 34), Bottom = C(4, 8, 14) }, Card = { Top = C(22, 34, 50), Bottom = C(8, 14, 22) }, Title = { Top = C(40, 100, 180), Bottom = C(14, 30, 60) },
    Accent = P1.Glow, Accent2 = C(180, 220, 255), HpFill = P1.Glow, HpBg = C(6, 12, 22), XpFill = C(180, 220, 255), Text = C(210, 230, 255),
    Tex = "tex_fs_caustics", TexT = 0.86, TexTile = 240, TexScroll = Vector2.new(6, 3),
    Emblem = "EmblemFission", BorderThick = 2,
    Steel = C(130, 146, 166), Glow = P1.Glow, Hot = P1.Hot, Ink = P1.Ink, Red = C(235, 70, 60),
    Deco = FsDeco, OpenFn = FsOpen, TitleDeco = FsTitle,
    Clean = FS_CLEAN, -- (SKIN UI THEMES: the clean palette + control-rod tab marks + the pressure gauge; the old art is not drawn)
    -- (SKIN UI 2026-10-29: a counting readout over a breathing Cherenkov pool, a flare on crits, meltdown drips on a kill; this colourway's P)
    Numbers = { Font = "RobotoMono", Glyph = "◉", NoBang = true, Motion = FsMotion, Accent = FsAccent, AccentStep = FsAccentStep, Count = true,
        Normal = P.Text, Crit = P.Spark, Weak = P.Hot, Stroke = P.Ink, StrokeThick = 2, Size = 1.05 } }

-- ===== kill effect / bundle / store hero =====
Set.KillEffect = { Id = "Decay", Name = "Meltdown", Image = ART.EmblemFission,
    How = "Own any Fission skin (or the Fission bundle)",
    Desc = "MELTDOWN: the body sags and melts down, glowing drips falling off it, into a Cherenkov-blue pool that pulses twice and drains away. With the Fission reactor-gauge banner." }
Set.Bundle = { Id = "FissionBundle", Name = "Fission Bundle", Price = 2199, BP = 799, ProductId = 0,
    Desc = "The whole Fission set: the Fission AA-12, M249 and Ion Accelerator, the Control Rod, Containment Gloves and Sealed Sleeves, the Fission health bar and the Meltdown kill effect.",
    Contents = { "WeaponSkin:FissionAA12", "WeaponSkin:FissionM249", "WeaponSkin:FissionPlasmaCannon", "MeleeSkin:Fission", "Glove:ContainmentGloves", "Sleeve:SealedSleeves", "HealthBar:Fission", "KillEffect:Decay" } }
Set.Hero = { Grad = { C(18, 40, 80), C(4, 8, 14) }, Stroke = P1.Glow, Emblem = ART.EmblemFission, Name = C(220, 236, 255), Chip = C(30, 70, 140) }

-- (gate, skins9: the first banner of a session showed only "x1 PRESSURE" -- the dial sprites were still downloading: the
-- set module is first required at the first kill, so a load-time preload came too late) the banner + bar art is fetched
-- the first time a Fission piece is drawn (BESPOKE's OnEquip preload)
local artLoaded = false
Set.OnEquip = function(rig: any, H: any)
    if artLoaded then return end
    artLoaded = true
    task.spawn(function()
        pcall(function()
            game:GetService("ContentProvider"):PreloadAsync({ ART.fs_dial, ART.fs_zone, ART.fs_needle, ART.fs_ring, ART.fs_bubble, ART.tex_fs_bar, ART.EmblemFission })
        end)
    end)
end

return Set
