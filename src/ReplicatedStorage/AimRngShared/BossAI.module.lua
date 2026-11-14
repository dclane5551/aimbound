--!nocheck
-- BOSS AI (stage 2 of the boss revamp, 2026-10-02). Owner: "make the bosses difficult, daunting, all with variety --
-- ranged bosses, melee chargers... we should know when and how they attack, but it shouldn't be easy", "no
-- projectiles: once the red area goes off, if you're in it you get hit", "they should have custom VFX".
--
-- One shared brain + a kit per boss. Every attack is an EnemyAttacks telegraph (Circle / Line / Cone / Ring / Beam).
--   * Phases at 66% / 33% health: a roar (heavily reduced damage taken while it roars), a burst + shockwaves, then a
--     faster, nastier move set. Owner (later): "they feel samey and too easy to dodge -- should feel chaotic and
--     daunting" -> every boss runs a constant PRESSURE layer under its moves (fissures / death marks / sweeping lasers /
--     artillery / lava pools / icicle storms), moves OVERLAP from phase 2 (Cadence + MaxActive), circles bracket
--     where you are AND where you're heading, arena-wide wipes leave only a few safe circles, camera shake + flashes.
--   * BOSSES v3 (2026-10-05, owner: "half of them teleport around or on top of you too much, and the attacks arent
--     learnable, they are just spammed" -- measured on the old Phantom, phase 1: 25 teleports in 25 s, came within 2
--     studs, 8 telegraphs at once, never a quiet second). The chaos layer above is GONE:
--       ROTATIONS  each phase is a fixed ORDER of moves (Moves[phase] = { { fn, "CALLOUT" }, ... }) -- the same fight
--                  every time, so it can be learned
--       TELL       before every move the boss plants, charges and its bar shows the move's name
--       ONE AT A TIME, then a RECOVERY window (Recover[phase] x pace) = your damage window
--       NO PRESSURE LOOPS (the old constant hazards became moves in the rotations; the Chronarch's metronome stays --
--                  it's a mechanic, not an attack)
--       AIMED AT YOU, NOT AHEAD: Brain:Lead returns where you are (no prediction), Rain drops on you one at a time
--       NO TELEPORTS: M.Step shows where it's going (>= 28 studs from you), then glides there; bosses stand still
--                  while attacking and keep their distance
--   * Movement per kit: Chase (closes to a range), Orbit (circles you slowly), Hold.
--   * Custom VFX: aura + light on the boss, charge-ups (particles pulled in, a growing glow), impact bursts, dash
--     trails, ghost afterimages, phase bursts, a death explosion.
-- DungeonGenerator builds each boss model + stats and hands it here: BossAI.Run(kind, model, config, deps).
-- deps = { SpawnPos, Geo, Fx, Windup, Speed, Bounds = {MinX, MaxX, MinZ, MaxZ}, Targets(), Hit(player, mult),
--          SetTakenMult(model, v), Summon(positions)?, LiveAdds()? }
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Shared = script.Parent
local EA = require(Shared:WaitForChild("EnemyAttacks"))

local BossAI = {}

-- ==================== VFX ====================
local VFX = {}
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function Part(props)
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.Material = Enum.Material.Neon
    for k, v in pairs(props) do p[k] = v end
    return p
end
local function Emitter(parent, props)
    local e = Instance.new("ParticleEmitter")
    for k, v in pairs(props) do e[k] = v end
    e.Parent = parent
    return e
end
local function Sound(kind, part)
    local ok, SH = pcall(require, Shared:WaitForChild("SoundHelper"))
    if ok and SH and part then pcall(SH.PlayAt, kind, part) end
end
local function Body(model)
    return model:FindFirstChild("Torso") or model.PrimaryPart
end

-- constant aura: drifting sparks + a coloured light on the body
function VFX.Aura(model, color)
    local body = Body(model)
    if not body then return end
    Emitter(body, { Texture = SPARK, Color = ColorSequence.new(color), LightEmission = 1, LightInfluence = 0, Rate = 14,
        Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
        Transparency = NumberSequence.new(0.2, 1), Name = "BossAura" })
    local l = Instance.new("PointLight")
    l.Name = "BossLight"; l.Color = color; l.Range = 20; l.Brightness = 1.6; l.Shadows = false
    l.Parent = body
end

-- charge-up: particles pulled into the boss + a growing glow; returns stop()
function VFX.Charge(B, dur, color)
    local fx = B.d.Fx
    local glow = Part({ Name = "BossCharge", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Color = color, Transparency = 0.55, Parent = fx })
    local field = Part({ Name = "BossChargeField", Size = Vector3.new(14, 14, 14), Transparency = 1, Parent = fx })
    local e = Emitter(field, { Texture = SPARK, Color = ColorSequence.new(color), LightEmission = 1, LightInfluence = 0, Rate = 60,
        Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
        ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Lifetime = NumberRange.new(0.35, 0.5), Speed = NumberRange.new(14, 18),
        Size = NumberSequence.new(0.35, 0.05), Transparency = NumberSequence.new(0.1, 0.8) })
    local light = Instance.new("PointLight")
    light.Color = color; light.Range = 24; light.Brightness = 0; light.Shadows = false; light.Parent = glow
    local t0, alive = os.clock(), true
    task.spawn(function()
        -- (2026-10-15, owner: "theres just a bugged circle in all of my runs"): a boss killed mid charge-up never called stop(),
        -- so its full-size glow stayed where it died -- the loop now also ends with the boss, and always cleans up
        while alive and glow.Parent and B.model.Parent and (tonumber(B.model:GetAttribute("Health")) or 1) > 0 do
            local k = math.clamp((os.clock() - t0) / math.max(dur * B.ctx.Windup, 0.05), 0, 1)
            local d = 2 + 6 * k
            glow.Size = Vector3.new(d, d, d)
            glow.Transparency = 0.55 - 0.3 * k
            light.Brightness = 4 * k
            glow.CFrame = CFrame.new(B.pos)
            field.CFrame = CFrame.new(B.pos)
            RunService.Heartbeat:Wait()
        end
        alive = false
        e.Enabled = false
        if glow.Parent then glow:Destroy() end
        if field.Parent then Debris:AddItem(field, 0.6) end
    end)
    return function()
        alive = false
        e.Enabled = false
        if glow.Parent then glow:Destroy() end
        Debris:AddItem(field, 0.6)
    end
end

-- impact / phase burst: an expanding neon shell, a spray of sparks and smoke, a light flash
function VFX.Burst(fx, pos, color, size, sound)
    local shell = Part({ Name = "BossBurst", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(pos), Color = color, Transparency = 0.2, Parent = fx })
    local e = Emitter(shell, { Texture = SPARK, Color = ColorSequence.new(color, Color3.new(1, 1, 1)), LightEmission = 1, LightInfluence = 0,
        Rate = 0, Lifetime = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(size * 1.5, size * 3), SpreadAngle = Vector2.new(180, 180),
        Size = NumberSequence.new(0.6, 0), Drag = 3 })
    local s = Emitter(shell, { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(60, 55, 60)), LightInfluence = 0.3, Rate = 0,
        Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(size * 0.5, size), SpreadAngle = Vector2.new(180, 180),
        Size = NumberSequence.new(size * 0.3, size * 0.6), Transparency = NumberSequence.new(0.5, 1), Drag = 2 })
    e:Emit(math.min(40, math.floor(14 + size * 1.2))) -- (capped: dozens of bursts at once is a lot of particles)
    s:Emit(6)
    local light = Instance.new("PointLight")
    light.Color = color; light.Range = math.min(30, size * 2.5); light.Brightness = 6; light.Shadows = false; light.Parent = shell
    if sound then Sound(sound, shell) end
    task.spawn(function()
        local t0 = os.clock()
        while true do
            local k = math.clamp((os.clock() - t0) / 0.35, 0, 1)
            local d = 1 + (size - 1) * (1 - (1 - k) ^ 2)
            shell.Size = Vector3.new(d, d, d)
            shell.Transparency = 0.2 + 0.8 * k
            light.Brightness = 6 * (1 - k)
            if k >= 1 then break end
            RunService.Heartbeat:Wait()
        end
        shell.Transparency = 1
        Debris:AddItem(shell, 1.5)
    end)
end

-- a dash trail behind the boss's body; returns remove()
function VFX.Trail(model, color)
    local body = Body(model)
    if not body then return function() end end
    local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, body.Size.Y * 0.45, 0); a0.Parent = body
    local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -body.Size.Y * 0.45, 0); a1.Parent = body
    local tr = Instance.new("Trail")
    tr.Attachment0 = a0; tr.Attachment1 = a1; tr.Color = ColorSequence.new(color); tr.LightEmission = 1
    tr.Lifetime = 0.35; tr.Transparency = NumberSequence.new(0.2, 1); tr.FaceCamera = true
    tr.Parent = body
    return function() tr.Enabled = false; Debris:AddItem(tr, 0.5); Debris:AddItem(a0, 0.5); Debris:AddItem(a1, 0.5) end
end

-- a translucent afterimage that fades (Phantom decoys, blink exits)
function VFX.Ghost(fx, pos, color, life)
    local g = Part({ Name = "BossGhost", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 6, 5), CFrame = CFrame.new(pos), Color = color,
        Material = Enum.Material.ForceField, Transparency = 0.1, Parent = fx })
    Emitter(g, { Texture = SMOKE, Color = ColorSequence.new(color), LightEmission = 0.5, Rate = 18, Lifetime = NumberRange.new(0.6, 1),
        Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(1.5, 3), Transparency = NumberSequence.new(0.5, 1) })
    task.delay(life or 1.2, function() if g.Parent then g:Destroy() end end)
    return g
end
BossAI.VFX = VFX

-- camera shake + screen flash for big hits (client only: solo floors run here; party floors run on the server,
-- where these do nothing)
local shakeAmp = 0
local flashGui
if RunService:IsClient() then
    RunService:BindToRenderStep("BossShake", Enum.RenderPriority.Camera.Value + 10, function(dt)
        if shakeAmp > 0.02 then
            local cam = workspace.CurrentCamera
            if cam then
                cam.CFrame = cam.CFrame * CFrame.Angles((math.random() - 0.5) * shakeAmp * 0.035, (math.random() - 0.5) * shakeAmp * 0.035, 0)
            end
            shakeAmp = math.max(0, shakeAmp - dt * 5)
        end
    end)
end
function VFX.Shake(pos, amp)
    if not RunService:IsClient() then return end
    local lp = Players.LocalPlayer
    local r = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    local d = (r and pos) and (r.Position - pos).Magnitude or 0
    shakeAmp = math.max(shakeAmp, amp * math.clamp(1 - d / 140, 0.25, 1))
end
function VFX.ScreenFlash(color, strength)
    -- (0.99u: OFF -- owner's standing rule "no full-screen flashes"; the phase roar / enrage / stagger flashes were still live)
    if true then return end
    if not RunService:IsClient() then return end
    local lp = Players.LocalPlayer
    if not flashGui or not flashGui.Parent then
        flashGui = Instance.new("ScreenGui")
        flashGui.Name = "BossFlash"; flashGui.IgnoreGuiInset = true; flashGui.ResetOnSpawn = false; flashGui.DisplayOrder = 5
        local f = Instance.new("Frame")
        f.Name = "F"; f.Size = UDim2.fromScale(1, 1); f.BorderSizePixel = 0; f.BackgroundTransparency = 1
        f.Parent = flashGui
        flashGui.Parent = lp:WaitForChild("PlayerGui")
    end
    local f = flashGui.F
    f.BackgroundColor3 = color
    task.spawn(function()
        local t0 = os.clock()
        while os.clock() - t0 < 0.5 do
            f.BackgroundTransparency = 1 - (strength or 0.35) * (1 - (os.clock() - t0) / 0.5)
            RunService.Heartbeat:Wait()
        end
        f.BackgroundTransparency = 1
    end)
end

-- big centre-screen banner: the boss's name when the fight starts, PHASE N on every phase change (client only)
local bannerGui = nil
function VFX.Banner(top, title, color)
    if not RunService:IsClient() then return end
    local lp = Players.LocalPlayer
    if not bannerGui or not bannerGui.Parent then
        bannerGui = Instance.new("ScreenGui")
        bannerGui.Name = "BossBanner"; bannerGui.IgnoreGuiInset = true; bannerGui.ResetOnSpawn = false; bannerGui.DisplayOrder = 6
        bannerGui.Parent = lp:WaitForChild("PlayerGui")
        pcall(function() require(script.Parent:WaitForChild("UIStyle")).ScaleGui(bannerGui) end) -- (Update 5: Interface Scale)
    end
    for _, c in ipairs(bannerGui:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end -- (keeps the InterfaceScale UIScale)
    -- (UI CLEAN R-C 2026-10-28: the run HUD plate -- flat slate sized to the words, small caps line on top in the event's
    -- colour over a 2 px mark, the big line in display caps Text; a short fade + 8 px slide, no gradient band, no grow pop)
    local okU, UIStyle = pcall(require, script.Parent:WaitForChild("UIStyle"))
    local UC = okU and UIStyle.Colors or {}
    local holder = Instance.new("Frame")
    holder.AnchorPoint = Vector2.new(0.5, 0.5); holder.Position = UDim2.new(0.5, 0, 0.35, 8) -- (under the boss bar + the top lines, clear of the crosshair)
    holder.AutomaticSize = Enum.AutomaticSize.XY; holder.Size = UDim2.fromOffset(360, 0)
    holder.BorderSizePixel = 0; holder.BackgroundColor3 = UC.Bg0 or Color3.fromRGB(16, 18, 22); holder.BackgroundTransparency = 1
    holder.Parent = bannerGui
    local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 28); pad.PaddingRight = UDim.new(0, 28)
    pad.PaddingTop = UDim.new(0, 12); pad.PaddingBottom = UDim.new(0, 14); pad.Parent = holder
    local lay = Instance.new("UIListLayout"); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
    lay.Padding = UDim.new(0, 6); lay.Parent = holder
    local function Label(text, size, role, col, order)
        local t = Instance.new("TextLabel")
        t.BackgroundTransparency = 1; t.AutomaticSize = Enum.AutomaticSize.X; t.Size = UDim2.fromOffset(0, size + 4)
        t.Text = text; t.TextSize = size; t.TextColor3 = col; t.TextStrokeTransparency = 1; t.TextTransparency = 1; t.LayoutOrder = order
        if okU then t.FontFace = UIStyle.RoleFace(role); t:SetAttribute("TypeRole", role) else t.Font = Enum.Font.GothamBlack end
        local cap = Instance.new("UISizeConstraint"); cap.MaxSize = Vector2.new(820, size + 4); cap.Parent = t
        t.TextTruncate = Enum.TextTruncate.AtEnd
        t.Parent = holder
        return t
    end
    local topL = Label(string.upper(tostring(top or "")), 15, "Label", (color or UC.Sub or Color3.new(1, 1, 1)):Lerp(Color3.new(1, 1, 1), 0.25), 1)
    local mark = Instance.new("Frame"); mark.BorderSizePixel = 0; mark.BackgroundColor3 = color or Color3.new(1, 1, 1); mark.BackgroundTransparency = 1
    mark.Size = UDim2.fromOffset(40, 2); mark.LayoutOrder = 2; mark.Parent = holder
    local titleL = Label(string.upper(tostring(title or "")), 38, "Header", UC.Text or Color3.new(1, 1, 1), 3)
    if title == nil or title == "" then titleL.Visible = false end
    local TS = game:GetService("TweenService")
    local inT = TweenInfo.new(0.22, Enum.EasingStyle.Quart)
    TS:Create(holder, inT, { Position = UDim2.fromScale(0.5, 0.35), BackgroundTransparency = 0.45 }):Play()
    TS:Create(mark, inT, { BackgroundTransparency = 0 }):Play()
    TS:Create(topL, inT, { TextTransparency = 0 }):Play()
    TS:Create(titleL, inT, { TextTransparency = 0 }):Play()
    task.delay(2.0, function()
        if not holder.Parent then return end
        local out = TweenInfo.new(0.4, Enum.EasingStyle.Quad)
        TS:Create(holder, out, { BackgroundTransparency = 1 }):Play()
        TS:Create(mark, out, { BackgroundTransparency = 1 }):Play()
        TS:Create(topL, out, { TextTransparency = 1 }):Play()
        TS:Create(titleL, out, { TextTransparency = 1 }):Play()
        task.delay(0.45, function() holder:Destroy() end)
    end)
end

-- every glowing trim on a boss heats up with the phase: its own colour -> orange -> white-hot (enrage you can see)
local PHASE_HEAT = { 0, 0.45, 0.8 }
local function HeatGlow(B, phase)
    B.glowOrig = B.glowOrig or {}
    if not next(B.glowOrig) then
        for _, p in ipairs(B.model:GetDescendants()) do
            if p:IsA("BasePart") and p:GetAttribute("Glow") then B.glowOrig[p] = p.Color end
        end
    end
    local hot = (phase >= 3) and Color3.fromRGB(255, 236, 210) or Color3.fromRGB(255, 130, 40)
    for p, c in pairs(B.glowOrig) do
        if p.Parent then p.Color = c:Lerp(hot, PHASE_HEAT[phase] or 0) end
    end
    if phase >= 3 and not B.embers then
        local torso = B.model:FindFirstChild("Torso")
        if torso then
            local att = Instance.new("Attachment"); att.Parent = torso
            local pe = Instance.new("ParticleEmitter")
            pe.Name = "Enrage"; pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
            pe.Color = ColorSequence.new(Color3.fromRGB(255, 200, 120), Color3.fromRGB(255, 60, 20)); pe.LightEmission = 1
            pe.Size = NumberSequence.new(0.6, 0); pe.Lifetime = NumberRange.new(0.8, 1.4); pe.Rate = 26
            pe.Speed = NumberRange.new(4, 9); pe.SpreadAngle = Vector2.new(180, 180); pe.Acceleration = Vector3.new(0, 6, 0)
            pe.Parent = att
            B.embers = pe
        end
    end
end

-- ==================== brain helpers ====================
local function Flat(v) return Vector3.new(v.X, 0, v.Z) end
local function Unit(v)
    local f = Flat(v)
    return f.Magnitude > 0.01 and f.Unit or Vector3.new(0, 0, 1)
end

local Brain = {}
Brain.__index = Brain

function Brain:Alive()
    return self.model.Parent ~= nil and self.model:GetAttribute("Dead") ~= true
end
function Brain:Root()
    local best, bd = nil, math.huge
    for _, p in ipairs(self.d.Targets()) do
        local c = p.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if r and r:IsA("BasePart") and h and h.Health > 0 and r.Position.Z > 450 then
            local dd = (r.Position - self.pos).Magnitude
            if dd < bd then best, bd = r, dd end
        end
    end
    return best
end
-- (v3) where the target IS: bosses no longer aim ahead of you (the predicted lead + EnemyMind made every attack land
-- where you were going -- nothing to learn, moving didn't help). The t argument is kept for the old call sites.
function Brain:Lead(_t)
    local r = self:Root()
    if not r then return self.pos end
    return r.Position
end
function Brain:Clamp(p)
    local b = self.d.Bounds
    local q = Vector3.new(math.clamp(p.X, b.MinX, b.MaxX), p.Y, math.clamp(p.Z, b.MinZ, b.MaxZ))
    -- (0.62, owner: "Forgeheart gets stuck outside of the arena"): a boss arena is a DISC inside that box -- the box's
    -- corners reach past the fight floor's curb, and a boss that slipped over it couldn't steer back in
    if b.R then
        local off = Vector3.new(q.X - b.CX, 0, q.Z - b.CZ)
        if off.Magnitude > b.R then q = Vector3.new(b.CX, q.Y, b.CZ) + off.Unit * b.R end
    end
    return q
end
function Brain:Inside(q)
    local b = self.d.Bounds
    if q.X < b.MinX or q.X > b.MaxX or q.Z < b.MinZ or q.Z > b.MaxZ then return false end
    return not b.R or Vector3.new(q.X - b.CX, 0, q.Z - b.CZ).Magnitude <= b.R
end
function Brain:Wait(t)
    local t0 = os.clock()
    while os.clock() - t0 < t do
        if not self:Alive() then return false end
        local dt = RunService.Heartbeat:Wait()
        -- de-aggro: nobody to fight (everyone is in the safe entry room) -> the fight's clock stops, no new attacks
        if not self:Root() then t0 += dt end
    end
    return self:Alive()
end
-- wind-up time scaled by difficulty (EA scales the telegraphs itself; this is for the boss's own pacing)
function Brain:W(t) return t * self.ctx.Windup end
function Brain:Hold(t) self.hold = math.max(self.hold, os.clock() + t) end
-- the boss bar (EnemyBars) reads BossTitle / BossPhase / BossColor; the old overhead label is kept in sync too
function Brain:Title(text, color)
    self.model:SetAttribute("BossTitle", text)
    self.model:SetAttribute("BossPhase", self.phase)
    local hud = self.model:FindFirstChild("HealthHUD")
    local lbl = hud and hud:FindFirstChildWhichIsA("TextLabel", true)
    if lbl then lbl.Text = text; if color then lbl.TextColor3 = color end end
end
-- dash in a straight line (walls stop it) with a trail
function Brain:Dash(to, dur)
    to = self:Clamp(Vector3.new(to.X, self.pos.Y, to.Z))
    local from = self.pos
    local stopTrail = VFX.Trail(self.model, self.kit.Color)
    self.dashing = true
    local t0 = os.clock()
    while self:Alive() do
        local k = math.clamp((os.clock() - t0) / dur, 0, 1)
        local want = from:Lerp(to, k)
        self.pos = self.d.Step(self.pos, want, (want - self.pos).Magnitude, 1)
        if k >= 1 then break end
        RunService.Heartbeat:Wait()
    end
    self.dashing = false
    stopTrail()
end
function Brain:Charge(dur)
    return VFX.Charge(self, dur, self.kit.Color)
end
-- a random open spot in the arena, at least minD from p
function Brain:Spot(p, minD, maxD)
    for _ = 1, 12 do
        local a = math.random() * math.pi * 2
        local d = minD + math.random() * ((maxD or minD + 30) - minD)
        local q = self:Clamp(p + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d))
        if (Flat(q - p)).Magnitude >= minD * 0.7 then return q end
    end
    return self:Clamp(p)
end
-- (v3) a point `range` from p at angle a (radians) that is INSIDE the arena -- tries angles either side of a. Used so a
-- boss never gets squashed against a wall right beside you (clamping an off-arena point used to park it 3-8 studs away)
function Brain:RingSpot(p, range, a)
    for k = 0, 12 do
        for _, sgn in ipairs({ 1, -1 }) do
            local aa = a + sgn * k * 0.26
            local q = Vector3.new(p.X + math.cos(aa) * range, self.pos.Y, p.Z + math.sin(aa) * range)
            if self:Inside(q) then return q, aa end
            if k == 0 then break end
        end
    end
    return self:Clamp(Vector3.new(p.X + math.cos(a) * range, self.pos.Y, p.Z + math.sin(a) * range)), a
end
function Brain:Boom(pos, size, sound)
    VFX.Burst(self.d.Fx, pos + Vector3.new(0, 2, 0), self.kit.Color, size, sound)
    VFX.Shake(pos, math.clamp(size / 10, 0.4, 2.2))
end

-- ==================== shared moves ====================
local M = {}

-- (AGILITY vs BOSSES, 2026-10-24) EVADABLE BOSS ATTACKS -- the PoE 2 rule: evasion works on any monster's NON-AREA hits,
-- bosses included; area hits and the big telegraphed boss moves never miss. Every boss move here is a telegraph, so this is
-- an explicit ALLOW-LIST: only these moves pass opts.Plain to their strike (EnemyAttacks.StrikeHit -> EA.StrikePlain ->
-- DungeonGenerator.HitPlayer), and only those hits can be dodged with Agility (at the full evade chance x StatCalculator.BOSS_EVADE).
-- PLAIN = one aimed strike from the boss itself: a swing, thrust, claw, scythe / blade cut or a lock-on shot.
--   LockOn     M.Snipe from the boss's own body (Phantom LOCK-ON) -- NOT from decoys / drones / lances (DECOYS, DRONE LOCK, Archon)
--   ShadowStep M.Step's one cone after the glide          Claws    M.Claws (Ravager SHRED)
--   Riposte    M.Riposte (Duelist EN GARDE)                Rake     RavagerSwipe (RAKE)
--   Flurry     DuelFlurry's thrusts (not the shadow echo)  KeyThrust WardKeyThrust (Lockwarden KEY THRUST / TWIN KEYS / KEY STORM)
--   Reap       the Harvest Lord's scythe (WorldFoes Autumn)  Iaijutsu the Sakura superboss's draw-cuts (WorldFoes Sakura)
-- NEVER evadable (no Plain): everything placed on the floor or around you (Rain, Pounce, Predict, Carpet, Cage, Hexfall, Mines,
-- Debris, Salvo, Lanes, Crossfire, Star, Stampede, LungeCross, Flank ...), charges / lunges / rams (Goliath CHARGE, DuelLunge,
-- KingRam, Skate), breaths, wide sweeps and wheels (FireBreath, ForgeBreath, BroodSweep, Sigils, Quadrants, Roulette, Shockfront,
-- Headlights, Crescent), rings, walls, zones, arena wipes, marks, donuts, rollers, seekers / pylons, mechanic-mode moves
-- (MECH_MOVES / MAJOR_MECH), encounter mechanics, aim rounds, hazards and damage over time.
M.PLAIN = { LockOn = true, ShadowStep = true, Claws = true, Riposte = true, Rake = true, Flurry = true, KeyThrust = true,
    Reap = true, Iaijutsu = true }

-- (v3) RAIN: circles drop onto where you stand, one at a time on a steady rhythm -- keep moving and they land behind you.
-- (spread is unused now: the old version bracketed you with random circles where you were heading)
function M.Rain(B, count, radius, windup, _spread, stagger, opts)
    windup = math.max(windup, 0.8)
    stagger = math.max(stagger or 0.4, 0.4)
    for i = 1, count do
        if not B:Alive() then return end
        local r = B:Root()
        if not r then return end
        EA.Circle(B.ctx, r.Position, radius, windup, opts or { Mult = 1, OnStrike = (i % 3 == 0) and function(c) VFX.Shake(c, 0.5) end or nil })
        B:Wait(stagger)
    end
    B:Wait(B:W(windup))
end

-- a stomp: circle around the boss, then a train of shockwave rings to jump (rings = how many)
function M.Stomp(B, radius, rings, gap)
    B:Hold(B:W(0.7) + 0.3 + (rings or 0) * (gap or 0.45))
    local stop = B:Charge(0.6)
    EA.Circle(B.ctx, B.pos, radius, 0.6, { Mult = 1.6, Sound = "BossSlam", OnStrike = function(c) B:Boom(c, radius) end })
    B:Wait(B:W(0.6))
    stop()
    for i = 1, (rings or 0) do
        if not B:Alive() then return end
        EA.Ring(B.ctx, B.pos, 80, 0.12, { Mult = 1.1, Speed = 36 + i * 4 })
        B:Wait(gap or 0.45)
    end
end

-- RADIAL COOLDOWN (0.63, owner: "Bosses still spam that attack that shoots lasers around them out, please please please
-- tone down on using this, that attack is so horribly boring"): lines fanned out from the boss (spokes / spirals /
-- rotating sweeps) play at most once every RADIAL_GAP seconds per boss; inside the gap the move becomes a PREDICT
-- (circles where you're heading) instead. Most kits lost these moves outright too.
-- (fields on M, not locals: this module's main chunk is at Luau's 200-local limit)
M.RADIAL_GAP = 35
function M.RadialOK(B)
    -- (0.68, owner: "remove the lasers in general shooting out all around the bosses"): never -- every spoke / spiral /
    -- sweep / fan plays as a PREDICT (circles where you're heading) instead
    return false
end

-- lanes fanned out from a point (spokes), rotating in waves
function M.Spokes(B, n, length, width, windup, waves, rot, from)
    if not M.RadialOK(B) then return M.Predict(B, 3) end
    B:Hold(B:W(windup) * waves + 0.4)
    local o = from or B.pos
    local base = math.random() * math.pi * 2
    local r = B:Root()
    if r then base = math.atan2(r.Position.X - o.X, r.Position.Z - o.Z) + math.pi / n end
    for w = 0, waves - 1 do
        if not B:Alive() then return end
        local stop = B:Charge(windup * 0.8)
        for i = 0, n - 1 do
            local a = base + (i / n) * math.pi * 2 + w * (rot or 0)
            EA.Line(B.ctx, o, o + Vector3.new(math.sin(a), 0, math.cos(a)) * length, width, windup, { Mult = 1.3, Height = 12 })
        end
        B:Wait(B:W(windup) * 0.75) -- the next wave starts before this one finishes
        stop()
    end
    B:Wait(B:W(windup) * 0.3)
end

-- parallel lanes through your position with narrow gaps (crossToo = a second set at right angles)
function M.Lanes(B, count, width, gap, windup, crossToo)
    local r = B:Root()
    if not r then return end
    local center = B:Lead(0.35)
    local dir = Unit(center - B.pos)
    local side = Vector3.new(-dir.Z, 0, dir.X)
    local offset = math.random() * (width + gap)
    local stop = B:Charge(windup * 0.7)
    for i = -math.floor(count / 2), math.floor(count / 2) do
        local c = center + side * (i * (width + gap) + offset - (width + gap) / 2)
        EA.Line(B.ctx, c - dir * 80, c + dir * 80, width, windup, { Mult = 1.3, Height = 12 })
    end
    if crossToo then
        for i = -math.floor(count / 2), math.floor(count / 2) do
            local c = center + dir * (i * (width + gap) + offset)
            EA.Line(B.ctx, c - side * 80, c + side * 80, width, windup + 0.45, { Mult = 1.3, Height = 12 })
        end
    end
    B:Wait(B:W(windup + (crossToo and 0.45 or 0)))
    stop()
end

-- lock-on lasers (from the boss or given origins), staggered so they converge
function M.Snipe(B, count, windup, origins, stagger)
    local r = B:Root()
    if not r then return end
    local own = origins == nil -- (only the boss's own shot is a plain hit: M.PLAIN.LockOn)
    origins = origins or { function() return B.pos + Vector3.new(0, 1, 0) end }
    for i = 1, count do
        if not B:Alive() then return end
        local from = origins[((i - 1) % #origins) + 1]
        EA.Beam(B.ctx, from, r, windup, { Mult = 1.7, LockTime = 0.22, Width = 2, Range = 240, Plain = own and M.PLAIN.LockOn,
            OnFire = function(a, b) VFX.Burst(B.d.Fx, b, B.kit.Color, 6); VFX.Shake(b, 0.4) end })
        B:Wait(stagger or 0.45) -- (v3: one beam at a time, 0.45 s apart -- they used to land as one)
    end
    B:Wait(B:W(windup))
end

-- marching rows of circles across the arena toward / through you (carpet bombing)
function M.Carpet(B, rows, perRow, radius, windup, rowGap)
    local r = B:Root()
    if not r then return end
    local target = B:Lead(0.4)
    local dir = Unit(target - B.pos)
    local side = Vector3.new(-dir.Z, 0, dir.X)
    local start = target - dir * (rows / 2) * radius * 1.7
    local stop = B:Charge(0.5)
    task.delay(B:W(0.5), stop)
    for i = 0, rows - 1 do
        if not B:Alive() then return end
        local rowC = start + dir * i * radius * 1.7
        for j = 0, perRow - 1 do
            local off = (j - (perRow - 1) / 2) * radius * 1.9 + ((i % 2 == 0) and 0 or radius * 0.95)
            EA.Circle(B.ctx, rowC + side * off, radius, windup, { Mult = 1.1, OnStrike = (j == 0) and function(c) VFX.Shake(c, 0.6) end or nil })
        end
        B:Wait(rowGap)
    end
    B:Wait(B:W(windup))
end

-- the whole arena goes red except a few safe circles (placed away from you -- run)
-- (owner 2026-10-05: "Some boss attacks hit entire map even when out of the aoe (magma superboss)"): the safe circles were
-- picked 26-60 studs from you with a 1.5 s wind-up shortened by difficulty (~1 s on Oblivion) -- at 16-20 studs/s often
-- unreachable, so the wipe hit everyone; they could also land on a rock or a mound. Now: 14-30 studs away, on open floor
-- level with the arena, and the wipe always gives at least 2 s (real time) whatever the difficulty / Bot Skill.
function M.ArenaWipe(B, safeCount, safeR, windup, nearBoss)
    local r = B:Root()
    if not r then return end
    windup = math.max(windup, 2.0 / math.max(0.1, B.ctx.Windup))
    local floorY = EA.GroundY(B.ctx, B.d.SpawnPos or B.pos)
    local safe = {}
    -- (0.59, owner: "Boss attacks that cover the entire middle area (that say 'get beside it')": the one safe circle
    -- beside the boss sat in its body with the whole middle red. The near-boss wipes now leave THREE safe circles spread
    -- round the arena, 30-38 studs out from the boss, never on top of it.)
    if nearBoss then safeCount = math.max(safeCount, 3) end
    local base = math.random() * math.pi * 2
    for i = 1, safeCount do
        local p
        for _ = 1, 8 do
            if nearBoss then
                local a = base + (i - 1) / safeCount * math.pi * 2 + (math.random() - 0.5) * 0.4
                p = B:Clamp(B.pos + Vector3.new(math.cos(a), 0, math.sin(a)) * (30 + math.random() * 8))
            else
                p = B:Spot(r.Position, 14, 30)
            end
            if math.abs(EA.GroundY(B.ctx, p) - floorY) <= 2.5 then break end -- (not on a rock / pillar / mound)
        end
        table.insert(safe, { Pos = p, R = math.max(safeR, nearBoss and 11 or 9) })
    end
    B:Hold(B:W(windup) + 0.3)
    local stop = B:Charge(windup)
    VFX.ScreenFlash(B.kit.Color, 0.18)
    EA.Arena(B.ctx, B.d.Bounds, safe, windup, { Mult = 1.8 })
    B:Wait(B:W(windup))
    stop()
    VFX.Shake(B.pos, 2.2)
    VFX.ScreenFlash(Color3.new(1, 1, 1), 0.3)
end

-- (v3) the cloak used by the gliding bosses (was Phantom-only)
local function Cloak(B, on)
    B.cloakOrig = B.cloakOrig or {}
    for _, n in ipairs({ "Torso", "Core", "Head" }) do
        local p = B.model:FindFirstChild(n)
        if p then
            if B.cloakOrig[p] == nil then B.cloakOrig[p] = p.Transparency end
            p.Transparency = on and 0.85 or B.cloakOrig[p]
        end
    end
end

-- (v3) STEP -- replaces the old blink (teleported right behind you, 2-4 times in a row): a ghost marks where it's going,
-- always >= 28 studs from you; it fades and GLIDES there (a visible trail, not a teleport), then fires one wide cone at you
function M.Step(B, range, angle)
    local r = B:Root()
    if not r then return end
    local dest
    for _ = 1, 16 do
        local q = B:Spot(r.Position, 28, 42)
        -- (and the glide mustn't pass through you: the path keeps >= 12 studs clear)
        local ab, ap = Flat(q - B.pos), Flat(r.Position - B.pos)
        local t = math.clamp(ap:Dot(ab) / math.max(1e-3, ab:Dot(ab)), 0, 1)
        local clear = (ap - ab * t).Magnitude
        if Flat(q - r.Position).Magnitude >= 26 and ab.Magnitude >= 14 and clear >= 12 then dest = q break end
    end
    dest = dest or B:Spot(r.Position, 28, 42)
    dest = Vector3.new(dest.X, B.pos.Y, dest.Z)
    VFX.Ghost(B.d.Fx, dest, B.kit.Color, 1.2) -- (where it's going, shown first)
    B:Wait(B:W(0.55))
    Cloak(B, true)
    B:Dash(dest, 0.4)
    Cloak(B, false)
    r = B:Root()
    if not r or not B:Alive() then return end
    local stop = B:Charge(0.85)
    EA.Cone(B.ctx, B.pos, Unit(r.Position - B.pos), range or 60, angle or 26, 0.85, { Mult = 1.5, Plain = M.PLAIN.ShadowStep })
    B:Wait(B:W(0.85))
    stop()
end

-- (v3) FISSURES: n quake lines fanned toward you from the boss (was Goliath's constant pressure loop)
function M.Fissures(B, n, spread)
    if not M.RadialOK(B) then return M.Predict(B, math.max(2, n or 3)) end -- (0.68: a fan of lines from the boss -> circles)
    local r = B:Root()
    if not r then return end
    local base = Unit(r.Position - B.pos)
    for i = 1, n do
        local a = (i - (n + 1) / 2) * spread
        local dir = CFrame.fromAxisAngle(Vector3.yAxis, a):VectorToWorldSpace(base)
        EA.Line(B.ctx, B.pos, B.pos + dir * 90, 5, 0.9, { Mult = 1.0, Height = 8 })
    end
    B:Wait(B:W(0.9))
end

-- (v3) MARKS: death marks that hunt you, one after another (was Phantom / Void / Echo pressure)
function M.Marks(B, n)
    for _ = 1, n do
        local r = B:Root()
        if not r or not B:Alive() then return end
        EA.Mark(B.ctx, r, 7, 1.5, { Mult = 1.5, OnStrike = function(c) B:Boom(c, 7) end })
        B:Wait(0.8)
    end
    B:Wait(B:W(1.2))
end

-- (v3) SWEEP: rotating floor lasers from the boss (jump them); reverse = a second pass the other way (was Sentinel /
-- Cyber pressure)
function M.Sweep(B, arms, dur, reverse)
    if not M.RadialOK(B) then return M.Predict(B, 3) end
    local r = B:Root()
    local start = r and (math.atan2(r.Position.X - B.pos.X, r.Position.Z - B.pos.Z) + math.pi / arms) or 0
    local passes = reverse and 2 or 1
    for pass = 1, passes do
        if not B:Alive() then return end
        local sgn = (pass == 1) and 1 or -1
        for i = 0, arms - 1 do
            EA.Sweep(B.ctx, function() return B.pos end, start + i * math.pi * 2 / arms, sgn * math.pi * 0.9, dur, 88,
                { Mult = 1.1, Color = B.kit.Color, Warn = 0.8 })
        end
        B:Wait(B:W(0.8) + dur + 0.3)
    end
end

-- (v3) POOLS: lingering pools on you and in a ring around you -- the floor shrinks for a few seconds (was Fire pressure)
function M.Pools(B, count)
    local r = B:Root()
    if not r then return end
    local c = r.Position
    EA.Zone(B.ctx, c, 7, 0.9, 5, { Mult = 0.35 })
    for i = 1, count - 1 do
        local a = i / (count - 1) * math.pi * 2
        EA.Zone(B.ctx, c + Vector3.new(math.cos(a) * 16, 0, math.sin(a) * 16), 7, 0.9, 5, { Mult = 0.35 })
    end
    B:Wait(B:W(0.9) + 0.4)
end

-- ===== 0.49 PHASE MOVES (owner: "boss phases should introduce different attacks, not the same exact ones") =====
-- CAGE: a ring of circles drops round where you stand with ONE gap, then the middle caves in -- leave through the gap
function M.Cage(B, n, radius, windup)
    local r = B:Root()
    if not r then return end
    local c = r.Position
    local gap = math.random(1, n)
    local stop = B:Charge(windup * 0.8)
    for i = 1, n do
        if i ~= gap then
            local a = (i / n) * math.pi * 2
            EA.Circle(B.ctx, c + Vector3.new(math.cos(a), 0, math.sin(a)) * radius, radius * 0.55, windup, { Mult = 1.2 })
        end
    end
    EA.Circle(B.ctx, c, radius * 0.7, windup + 0.5, { Mult = 1.4, OnStrike = function(p) VFX.Shake(p, 0.6) end })
    B:Wait(B:W(windup + 0.5))
    stop()
end

-- CHECKER: the floor splits into big tiles -- every other tile strikes, then the rest: stand on one, then step across
function M.Checker(B, tile, windup)
    local b = B.d.Bounds
    local stop = B:Charge(0.6)
    local ox, oz = math.random() * tile, math.random() * tile
    for pass = 0, 1 do
        if not B:Alive() then break end
        for ix = 0, math.ceil((b.MaxX - b.MinX) / tile) do
            for iz = 0, math.ceil((b.MaxZ - b.MinZ) / tile) do
                if (ix + iz) % 2 == pass then
                    local p = Vector3.new(b.MinX - ox + (ix + 0.5) * tile, B.pos.Y, b.MinZ - oz + (iz + 0.5) * tile)
                    if p.X > b.MinX - tile * 0.4 and p.X < b.MaxX + tile * 0.4 and p.Z > b.MinZ - tile * 0.4 and p.Z < b.MaxZ + tile * 0.4 then
                        EA.Line(B.ctx, p - Vector3.new(tile / 2 - 0.6, 0, 0), p + Vector3.new(tile / 2 - 0.6, 0, 0), tile - 1.2, windup, { Mult = 1.2, Height = 0 })
                    end
                end
            end
        end
        if pass == 0 then stop() end
        B:Wait(B:W(windup) + 0.15)
    end
end

-- PINCER: walls march in from both sides of the arena, one step at a time, toward the lane you stood in -- hold the lane
function M.Pincer(B, width, windup, stepGap)
    local r = B:Root()
    if not r then return end
    local b = B.d.Bounds
    local horiz = math.random() < 0.5
    local lane = horiz and r.Position.X or r.Position.Z
    local lo, hi = horiz and b.MinX or b.MinZ, horiz and b.MaxX or b.MaxZ
    local stop = B:Charge(0.6)
    task.delay(B:W(0.6), stop)
    local function Wall(at)
        if horiz then
            EA.Line(B.ctx, Vector3.new(at, B.pos.Y, b.MinZ), Vector3.new(at, B.pos.Y, b.MaxZ), width, windup, { Mult = 1.3, Height = 12 })
        else
            EA.Line(B.ctx, Vector3.new(b.MinX, B.pos.Y, at), Vector3.new(b.MaxX, B.pos.Y, at), width, windup, { Mult = 1.3, Height = 12 })
        end
    end
    local left, right = lo + width / 2, hi - width / 2
    while B:Alive() and (left < lane - width * 1.1 or right > lane + width * 1.1) do
        if left < lane - width * 1.1 then Wall(left); left += width end
        if right > lane + width * 1.1 then Wall(right); right -= width end
        B:Wait(stepGap)
    end
    B:Wait(B:W(windup))
end

-- CROSSFIRE: two long lines cross on where you stand (an X); each wave re-aims and turns 45 degrees
function M.Crossfire(B, waves, width, windup)
    local a0 = math.random() * math.pi
    for w = 0, waves - 1 do
        local r = B:Root()
        if not r or not B:Alive() then return end
        local c = r.Position
        local stop = B:Charge(windup * 0.7)
        for k = 0, 1 do
            local a = a0 + w * math.pi / 4 + k * math.pi / 2
            local d = Vector3.new(math.cos(a), 0, math.sin(a))
            EA.Line(B.ctx, c - d * 80, c + d * 80, width, windup, { Mult = 1.3, Height = 12 })
        end
        B:Wait(B:W(windup) * 0.85)
        stop()
    end
    B:Wait(B:W(windup) * 0.3)
end

-- RIPPLE: shockwave rings burst from points round the arena one after another -- jump each as it reaches you
function M.Ripple(B, n, speed)
    for _ = 1, n do
        if not B:Alive() then return end
        local r = B:Root()
        local p = B:Spot(r and r.Position or B.pos, 22, 48)
        VFX.Ghost(B.d.Fx, p + Vector3.new(0, 3, 0), B.kit.Color, 1.2)
        EA.Ring(B.ctx, p, 75, 0.7, { Mult = 1.0, Speed = speed, StartRadius = 3 })
        B:Wait(0.85)
    end
    B:Wait(B:W(0.7))
end

-- SPIRAL: a slow windmill of arms from the boss, a notch further each wave -- walk round with it
function M.Spiral(B, arms, waves)
    M.Spokes(B, arms, 95, 6, 0.6, waves, math.pi / (arms * 2.5))
end

-- ==================== boss kits ====================
-- Each kit (v3): Color, Move ("Chase" / "Orbit" / "Hold"), Range, SpeedMul, Recover[phase] (seconds of nothing between
-- moves -- the damage window, x pace), Moves[phase] = { { fn, "CALLOUT" }, ... } played IN ORDER, Names (title per
-- phase). Pressure is only for mechanics that aren't attacks (the Chronarch's metronome).
-- ==================== BOSS v4 VARIETY (2026-10-06) ====================
-- Owner: "A lot of their attacks literally do the exact same thing, and are just tedious to fight (Tank for example, all
-- bosses just shooting straight lasers all around them out)". Lanes / spokes / crossfire / pincers / spirals were ~60
-- move slots across the bosses. These six read differently from a lane, and every boss now keeps at most ONE
-- straight-line move (the one that is its identity: Goliath's charge, the Sentinel's floor laser ...).

-- GET IN / GET OUT: a circle on the boss (get out), then the donut round it (get back in close) -- or the reverse
-- (inFirst: hug it, then run). The second step always follows, so it's a dance you learn, not a dice roll.
function M.InOut(B, rIn, rOut, inFirst, windup)
    windup = windup or 1.0
    local w2 = math.max(0.75, windup * 0.85)
    B:Hold(B:W(windup) + B:W(w2) + 0.8)
    local c = B.pos
    local function Out(w) EA.Circle(B.ctx, c, rIn, w, { Mult = 1.6, Sound = "BossSlam", OnStrike = function(p) B:Boom(p, rIn) end }) end
    local function In(w) EA.Donut(B.ctx, c, rIn, rOut, w, { Mult = 1.5, Sound = "BossSlam" }) end
    local stop = B:Charge(windup)
    if inFirst then In(windup) else Out(windup) end
    B:Wait(B:W(windup))
    stop()
    B:Wait(0.15)
    if not B:Alive() then return end
    if inFirst then Out(w2) else In(w2) end
    B:Wait(B:W(w2) + 0.2)
end

-- QUADRANTS: the floor round it splits into four pie slices -- the pair you stand in goes off first, then the other
-- pair (waves 3+ turn 45 degrees). Read the lit slices, step across the seam.
function M.Quadrants(B, range, waves, windup)
    -- (fixes 2026-10-16 #10: standing mid-slice the seam is ~21 studs away at 30 out -- 0.95 s wasn't enough to cross it)
    windup = (windup or 0.95) * 1.5
    waves = waves or 2
    B:Hold(B:W(windup) * waves + 0.15 * waves + 0.4)
    local r = B:Root()
    local base = r and math.atan2(r.Position.X - B.pos.X, r.Position.Z - B.pos.Z) or math.random() * math.pi * 2
    for w = 0, waves - 1 do
        if not B:Alive() then return end
        local a0 = base + (w % 2) * math.pi / 2 + (w >= 2 and math.pi / 4 or 0)
        local stop = B:Charge(windup * 0.8)
        for k = 0, 1 do
            local a = a0 + k * math.pi
            EA.Cone(B.ctx, B.pos, Vector3.new(math.sin(a), 0, math.cos(a)), range, 45, windup, { Mult = 1.4, Strips = 6 })
        end
        B:Wait(B:W(windup) + 0.15)
        stop()
    end
end

-- TIDE (2026-10-07, owner: "bosses still spam the same attack ... we need variation"): walls sweep across the arena
-- from the boss toward you. Low walls = jump them; with `gaps`, every other wall is TALL with one gap in it = walk
-- through the gap (it shifts each wave). Nothing radiates from the boss: read it, then time a jump or find the gap.
function M.Tide(B, waves, gaps)
    local r = B:Root()
    if not r then return end
    local toYou = Unit(Flat(r.Position - B.pos))
    local from = B.pos - toYou * 6
    B:Hold(B:W(1.0) + waves * 0.9 + 2.5)
    local stop = B:Charge(0.9)
    for w = 1, waves do
        if not B:Alive() then break end
        local tall = gaps and (w % 2 == 0)
        local opts = { Mult = 1.3, Speed = 26, Height = tall and 9 or 3.2 }
        if tall then opts.Gap = { At = math.random() * 1.2 - 0.6, W = 10 } end
        -- every other wave comes in at a tilt, so it isn't the same line twice
        local tilt = (w % 2 == 0) and math.rad(math.random(-25, 25)) or 0
        local dir = CFrame.fromAxisAngle(Vector3.yAxis, tilt):VectorToWorldSpace(toYou)
        local wu = (w == 1) and 1.0 or 0.75
        EA.Wall(B.ctx, from, dir, 130, 110, wu, opts)
        B:Wait(B:W(wu) + 0.9)
    end
    stop()
    B:Wait(1.6)
end

-- the farthest point along dir from `from` that is still inside the arena (10-stud steps)
local function RunOut(B, from, dir, maxLen)
    local b = B.d.Bounds
    local far = from
    for d = 10, maxLen or 260, 10 do
        local q = from + dir * d
        if q.X < b.MinX or q.X > b.MaxX or q.Z < b.MinZ or q.Z > b.MaxZ then break end
        far = q
    end
    return far
end

-- ROLL: boulders (or wheels) roll from the boss along a dotted trail through where you stand to the wall; bounce = they
-- glance off that wall and roll on. Step off the trail; the 2nd+ ones are aimed a little off you.
function M.Roll(B, count, radius, speed, look, bounce)
    for i = 1, count do
        if not B:Alive() then return end
        local r = B:Root()
        if not r then return end
        local from = Vector3.new(B.pos.X, B.pos.Y, B.pos.Z)
        local aim = r.Position
        if i > 1 then aim += Vector3.new((math.random() - 0.5) * 34, 0, (math.random() - 0.5) * 34) end
        local dir = Unit(aim - from)
        local far = RunOut(B, from, dir)
        local path = { from, far }
        if bounce then
            -- glance off the wall it reached: flip the axis it ran out on, roll on a while
            local b = B.d.Bounds
            local nx = (far.X + 10 * dir.X < b.MinX or far.X + 10 * dir.X > b.MaxX) and -dir.X or dir.X
            local nz = (far.Z + 10 * dir.Z < b.MinZ or far.Z + 10 * dir.Z > b.MaxZ) and -dir.Z or dir.Z
            local d2 = Unit(Vector3.new(nx, 0, nz))
            table.insert(path, RunOut(B, far, d2, 90))
        end
        local stop = B:Charge(0.5)
        EA.Roller(B.ctx, path, radius, speed, 1.0, { Mult = 1.5, Look = look, Sound = "BossSlam" })
        B:Wait(0.6)
        stop()
    end
    B:Wait(B:W(1.0) + 0.8)
end

-- FOOTSTEPS: it watches you move (glowing footprints appear where you step), then your trail erupts oldest-first,
-- racing after you -- keep going, never double back over your own tracks
function M.Footsteps(B, steps, radius)
    local prints, trail = {}, {}
    local stop = B:Charge(steps * 0.22)
    for _ = 1, steps * 3 do
        local r = B:Root()
        if not r or not B:Alive() then break end
        local p = r.Position
        if #trail == 0 or Flat(p - trail[#trail]).Magnitude > radius * 1.3 then
            table.insert(trail, p)
            local gy = EA.GroundY(B.ctx, p)
            local fp = Instance.new("Part")
            fp.Name = "BossFootprint"; fp.Anchored = true; fp.CanCollide = false; fp.CanQuery = false; fp.CanTouch = false; fp.CastShadow = false
            fp.Shape = Enum.PartType.Cylinder; fp.Material = Enum.Material.Neon; fp.Color = B.kit.Color; fp.Transparency = 0.55
            fp.Size = Vector3.new(0.1, radius * 0.9, radius * 0.9)
            fp.CFrame = CFrame.new(p.X, gy + 0.1, p.Z) * CFrame.Angles(0, 0, math.pi / 2)
            fp.Parent = B.d.Fx
            table.insert(prints, fp)
            if #trail >= steps then break end
        end
        B:Wait(0.22)
    end
    stop()
    for i, p in ipairs(trail) do
        if not B:Alive() then break end
        EA.Circle(B.ctx, p, radius, 0.55, { Mult = 1.3, OnStrike = (i % 2 == 0) and function(c) VFX.Shake(c, 0.4) end or nil })
        local fp = prints[i]
        task.delay(0.6, function() if fp then fp:Destroy() end end)
        B:Wait(0.16)
    end
    for _, fp in ipairs(prints) do task.delay(1.5, function() if fp.Parent then fp:Destroy() end end) end
    B:Wait(B:W(0.55) + 0.3)
end

-- COLLAPSE: shockwaves start at the arena wall and CLOSE IN on the boss -- jump each one as it passes you
function M.Converge(B, rings, gap)
    local b = B.d.Bounds
    local maxR = math.max(b.MaxX - b.MinX, b.MaxZ - b.MinZ) * 0.72
    gap = gap or 0.9
    B:Hold(B:W(0.7) + (rings - 1) * gap + maxR / 30 + 0.3)
    local stop = B:Charge(0.7)
    for i = 1, rings do
        if not B:Alive() then break end
        EA.Ring(B.ctx, B.pos, maxR, i == 1 and 0.7 or 0.12, { Mult = 1.2, Speed = 30 + i * 3, Inward = true, StartRadius = 5, Segments = 24 })
        if i == 1 then B:Wait(B:W(0.7)); stop() end
        B:Wait(gap)
    end
    B:Wait(maxR / 33)
end

-- ORBIT: n hazards circle the boss at about your distance for one lap (dotted track) -- stay in a gap, move with it
function M.Orbit(B, n, radius, lapTime, look)
    local r = B:Root()
    local dist = r and math.clamp(Flat(r.Position - B.pos).Magnitude, 16, 40) or 24
    local c = B.pos
    lapTime = lapTime or 4.5
    local speed = 2 * math.pi * dist / lapTime
    local spin = (math.random() < 0.5) and 1 or -1
    B:Hold(B:W(1.0) + lapTime + 0.5)
    local stop = B:Charge(1.0)
    for i = 1, n do
        local a0 = (i / n) * math.pi * 2
        local path = {}
        for k = 0, 16 do
            local a = a0 + spin * (k / 16) * math.pi * 2
            table.insert(path, c + Vector3.new(math.cos(a) * dist, 0, math.sin(a) * dist))
        end
        EA.Roller(B.ctx, path, radius, speed, 1.0, { Mult = 1.3, Look = look })
    end
    B:Wait(B:W(1.0))
    stop()
    B:Wait(lapTime + 0.3)
end


-- ===== SIGNATURE MOVES (0.59, owner: "A lot of bosses still shoot the same") =====
-- The shared patterns (Checker, Cage, InOut, Tide, Footsteps, Orbit, Rain, ArenaWipe, Ripple) were in 6-9 kits each.
-- Every one is now in at most ~3-4; the rest of the slots got these -- each a different SHAPE to read and dodge.
local function Aim(B) local r = B:Root(); return r and r.Position or B.pos end
local function Dir(a, b) return Unit(Flat(b - a)) end
local function Perp(d) return Vector3.new(-d.Z, 0, d.X) end

-- RUBBLE LINE: boulders land in a line from the boss out through where you stand, one after another (sidestep it)
function M.Debris(B, n, radius)
    local o, t = B.pos, Aim(B)
    local d = Dir(o, t)
    local stop = B:Charge(0.6)
    for i = 1, n do
        if not B:Alive() then break end
        EA.Circle(B.ctx, B:Clamp(o + d * (8 + i * radius * 1.6)), radius, 0.7, { Mult = 1.3, OnStrike = function(c) VFX.Shake(c, 0.4) end })
        B:Wait(0.16)
    end
    stop()
    B:Wait(B:W(0.7))
end
-- FAULT LINES: three jagged cracks open side by side across your path (the gaps between them are safe)
function M.FaultLines(B, gap)
    local t = Aim(B)
    local d = Dir(B.pos, t)
    local side = Perp(d)
    local stop = B:Charge(0.7)
    for k = -1, 1 do
        local c = t + d * (k * gap)
        local p = c - side * 50
        for _ = 1, 5 do
            local q = p + side * 20 + d * ((math.random() - 0.5) * 6)
            EA.Line(B.ctx, p, q, 4, 0.9, { Mult = 1.4, Height = 12 })
            p = q
        end
    end
    B:Wait(B:W(0.9))
    stop()
end
-- SHOCKFRONT: three cones roll out of its front, each longer and narrower -- get out to the side
function M.Shockfront(B)
    local d = Dir(B.pos, Aim(B))
    local stop = B:Charge(0.6)
    for i, c in ipairs({ { 22, 55 }, { 38, 38 }, { 56, 24 } }) do
        if not B:Alive() then break end
        EA.Cone(B.ctx, B.pos, d, c[1], c[2], 0.6 + i * 0.15, { Mult = 1.4 })
        B:Wait(0.3)
    end
    stop()
    B:Wait(B:W(0.9))
end
-- BOUNCE: a beam lane fires at you and ricochets off the arena wall twice (three legs)
function M.Bounce(B, width)
    local b = B.d.Bounds
    local p, d = B.pos, Dir(B.pos, Aim(B))
    local stop = B:Charge(0.7)
    for leg = 1, 3 do
        local tx = (d.X > 0) and (b.MaxX - p.X) / d.X or (d.X < 0) and (b.MinX - p.X) / d.X or math.huge
        local tz = (d.Z > 0) and (b.MaxZ - p.Z) / d.Z or (d.Z < 0) and (b.MinZ - p.Z) / d.Z or math.huge
        local tt = math.min(tx, tz, 160)
        local q = p + d * tt
        EA.Line(B.ctx, p, q, width, 0.7 + (leg - 1) * 0.35, { Mult = 1.4, Height = 12 })
        if tx < tz then d = Vector3.new(-d.X, 0, d.Z) else d = Vector3.new(d.X, 0, -d.Z) end
        p = q
    end
    B:Wait(B:W(1.4))
    stop()
end
-- MINES: six mines settle in a ring round you, then go off one by one round the ring -- step out between blasts
function M.Mines(B, radius)
    local c = Aim(B)
    local a0 = math.random() * math.pi * 2
    local stop = B:Charge(0.5)
    for i = 0, 5 do
        if not B:Alive() then break end
        local a = a0 + i / 6 * math.pi * 2
        EA.Circle(B.ctx, B:Clamp(c + Vector3.new(math.cos(a), 0, math.sin(a)) * radius), radius * 0.6, 0.8 + i * 0.22, { Mult = 1.2 })
    end
    EA.Circle(B.ctx, c, radius * 0.45, 0.8 + 6 * 0.22, { Mult = 1.4 })
    stop()
    B:Wait(B:W(0.8) + 1.4)
end
-- CLAWS: three slashes rake across you, then three more crossing them (an X of claw marks)
function M.Claws(B, sets)
    for k = 1, sets do
        if not B:Alive() then break end
        local t = Aim(B)
        local a = math.random() * math.pi + (k * math.pi / 2)
        local d = Vector3.new(math.cos(a), 0, math.sin(a))
        local side = Perp(d)
        local stop = B:Charge(0.45)
        for j = -1, 1 do
            local c = t + side * (j * 5)
            EA.Line(B.ctx, c - d * 16, c + d * 16, 2.6, 0.55, { Mult = 1.3, Height = 10, Plain = M.PLAIN.Claws })
        end
        B:Wait(B:W(0.55) + 0.1)
        stop()
    end
end
-- POUNCE: it leaps at you three times in a row -- each landing marks where you are NOW, keep moving
function M.Pounce(B, n, radius)
    for _ = 1, n do
        if not B:Alive() then break end
        local t = Aim(B)
        EA.Circle(B.ctx, t, radius, 0.6, { Mult = 1.5, OnStrike = function(c) B:Boom(c, radius) end })
        B:Wait(B:W(0.6) + 0.12)
    end
end
-- STAMPEDE: lanes charge across the arena from its wall, aimed through you, one after another
function M.Stampede(B, n, width)
    local b = B.d.Bounds
    for i = 1, n do
        if not B:Alive() then break end
        local t = Aim(B)
        local a = math.random() * math.pi * 2
        local d = Vector3.new(math.cos(a), 0, math.sin(a))
        EA.Line(B.ctx, B:Clamp(t - d * 90), B:Clamp(t + d * 90), width, 0.75, { Mult = 1.4, Height = 12 })
        B:Wait(0.5)
    end
    B:Wait(B:W(0.75))
    local _ = b
end
-- FLANK: it circles you -- cones strike in from three sides, 120 degrees apart, one by one
function M.Flank(B, range)
    local t = Aim(B)
    local a0 = math.random() * math.pi * 2
    for i = 0, 2 do
        if not B:Alive() then break end
        local a = a0 + i * math.pi * 2 / 3
        local from = B:Clamp(t + Vector3.new(math.cos(a), 0, math.sin(a)) * range)
        EA.Cone(B.ctx, from, Dir(from, t), range + 10, 26, 0.7, { Mult = 1.4 })
        B:Wait(0.35)
    end
    B:Wait(B:W(0.7))
end
-- STAR: a five-point star of lines drawn over you -- stand in one of its points' gaps
function M.Star(B, radius)
    local t = Aim(B)
    local a0 = math.random() * math.pi * 2
    local pts = {}
    for i = 0, 4 do
        local a = a0 + i * math.pi * 2 / 5
        table.insert(pts, t + Vector3.new(math.cos(a), 0, math.sin(a)) * radius)
    end
    local stop = B:Charge(0.7)
    for i = 1, 5 do
        local q = pts[((i + 1) % 5) + 1]
        EA.Line(B.ctx, pts[i], q, 3.4, 0.9 + i * 0.08, { Mult = 1.4, Height = 12 })
    end
    B:Wait(B:W(1.3))
    stop()
end
-- WARD: a ring closes round you with a calm centre -- stand still in the middle until it passes
function M.Ward(B, rIn, rOut)
    local t = Aim(B)
    local stop = B:Charge(0.6)
    EA.Donut(B.ctx, t, rIn, rOut, 1.0, { Mult = 1.5 })
    B:Wait(B:W(1.0))
    stop()
end
-- LINGER: the ground you just crossed curses: three slow zones where you were, lasting a few seconds
function M.Linger(B, radius, dur)
    for _ = 1, 3 do
        if not B:Alive() then break end
        EA.Zone(B.ctx, Aim(B), radius, 0.7, dur, { Mult = 0.6 })
        B:Wait(0.7)
    end
end
-- HEXFALL: circles fall in a hexagon round you, then the middle -- a ring to step through, then out
function M.Hexfall(B, radius)
    local t = Aim(B)
    local a0 = math.random() * math.pi * 2
    for i = 0, 5 do
        local a = a0 + i * math.pi / 3
        EA.Circle(B.ctx, B:Clamp(t + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 1.8), radius, 0.8, { Mult = 1.2 })
    end
    B:Wait(0.6)
    EA.Circle(B.ctx, t, radius * 1.2, 0.9, { Mult = 1.4 })
    B:Wait(B:W(0.9))
end
-- SIGILS: three rotating cones turn round the boss, a third of a turn -- stay in the gap and turn with it
function M.Sigils(B, range)
    local a0 = math.random() * math.pi * 2
    for step = 0, 3 do
        if not B:Alive() then break end
        for i = 0, 2 do
            local a = a0 + i * math.pi * 2 / 3 + step * 0.4
            EA.Cone(B.ctx, B.pos, Vector3.new(math.cos(a), 0, math.sin(a)), range, 22, 0.6, { Mult = 1.2 })
        end
        B:Wait(0.45)
    end
    B:Wait(B:W(0.6))
end
-- SALVO: a missile barrage walks from the boss straight through you and on -- two lines, crossed
function M.Salvo(B, radius)
    local t = Aim(B)
    for k = 0, 1 do
        if not B:Alive() then break end
        local d = Dir(B.pos, t)
        if k == 1 then d = Perp(d) end
        local start = (k == 0) and B.pos or (t - d * 40)
        for i = 1, 8 do
            EA.Circle(B.ctx, B:Clamp(start + d * (i * radius * 1.5)), radius, 0.6 + i * 0.1, { Mult = 1.2 })
        end
        B:Wait(0.6)
    end
    B:Wait(B:W(1.4))
end
-- MORTAR RING: shells land in a ring round you, then a wider ring -- stand in the gap between them
function M.MortarRing(B)
    local t = Aim(B)
    for k, rr in ipairs({ 12, 26 }) do
        if not B:Alive() then break end
        local n = (k == 1) and 6 or 10
        for i = 0, n - 1 do
            local a = i / n * math.pi * 2
            EA.Circle(B.ctx, B:Clamp(t + Vector3.new(math.cos(a), 0, math.sin(a)) * rr), 5, 0.8, { Mult = 1.2 })
        end
        B:Wait(0.55)
    end
    B:Wait(B:W(0.8))
end
-- ERUPTION: geysers burst in an outward spiral from the boss
function M.Eruption(B, n)
    local a0 = math.random() * math.pi * 2
    for i = 1, n do
        if not B:Alive() then break end
        local a = a0 + i * 0.7
        EA.Circle(B.ctx, B:Clamp(B.pos + Vector3.new(math.cos(a), 0, math.sin(a)) * (10 + i * 4)), 6, 0.7, { Mult = 1.3 })
        B:Wait(0.12)
    end
    B:Wait(B:W(0.7))
end
-- BLOOM: a crystal flower grows out from your spot -- petals in two waves, the second filling the first's gaps
function M.Bloom(B, radius)
    local t = Aim(B)
    local a0 = math.random() * math.pi * 2
    for w = 0, 1 do
        for i = 0, 5 do
            local a = a0 + i * math.pi / 3 + w * math.pi / 6
            local q = B:Clamp(t + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * (1.2 + w))
            EA.Line(B.ctx, t, q, 3, 0.8 + w * 0.45, { Mult = 1.3, Height = 10 })
        end
    end
    B:Wait(B:W(1.25))
end
-- PRISON: three walls box you in on three sides -- the fourth side is open, go
function M.Prison(B, half)
    local t = Aim(B)
    local open = math.random(0, 3)
    local stop = B:Charge(0.6)
    for i = 0, 3 do
        if i ~= open then
            local a = i * math.pi / 2
            local n = Vector3.new(math.cos(a), 0, math.sin(a))
            local c = t + n * half
            EA.Line(B.ctx, c - Perp(n) * half, c + Perp(n) * half, 4, 0.8, { Mult = 1.3, Height = 12 })
        end
    end
    EA.Circle(B.ctx, t, half * 0.8, 1.3, { Mult = 1.4 })
    B:Wait(B:W(1.3))
    stop()
end
-- HALVES: one half of the arena strikes, then the other -- cross the line at the right moment
function M.Halves(B, windup)
    local b = B.d.Bounds
    local cx, cz = (b.MinX + b.MaxX) / 2, (b.MinZ + b.MaxZ) / 2
    local horiz = math.random() < 0.5
    for k = 0, 1 do
        if not B:Alive() then break end
        local s = (k == 0) and -1 or 1
        if horiz then
            local x0 = (s < 0) and b.MinX or cx
            local x1 = (s < 0) and cx or b.MaxX
            EA.Line(B.ctx, Vector3.new((x0 + x1) / 2, B.pos.Y, b.MinZ), Vector3.new((x0 + x1) / 2, B.pos.Y, b.MaxZ), x1 - x0, windup + k * 0.9, { Mult = 1.4, Height = 0 })
        else
            local z0 = (s < 0) and b.MinZ or cz
            local z1 = (s < 0) and cz or b.MaxZ
            EA.Line(B.ctx, Vector3.new(b.MinX, B.pos.Y, (z0 + z1) / 2), Vector3.new(b.MaxX, B.pos.Y, (z0 + z1) / 2), z1 - z0, windup + k * 0.9, { Mult = 1.4, Height = 0 })
        end
    end
    B:Wait(B:W(windup) + 1.0)
end
-- FREEZE: the outer arena freezes from the walls in -- get in toward the middle
function M.Freeze(B, rIn)
    local b = B.d.Bounds
    local c = Vector3.new((b.MinX + b.MaxX) / 2, B.pos.Y, (b.MinZ + b.MaxZ) / 2)
    local stop = B:Charge(0.8)
    EA.Donut(B.ctx, c, rIn, math.max(b.MaxX - b.MinX, b.MaxZ - b.MinZ), 1.8, { Mult = 1.6 })
    B:Wait(B:W(1.8))
    stop()
end
-- FLOES: ice floes slide across the arena in parallel lanes -- dodge between them
function M.Floes(B, n, radius)
    local b = B.d.Bounds
    local horiz = math.random() < 0.5
    for i = 1, n do
        local f = (i - 0.5) / n
        local path
        if horiz then
            local z = b.MinZ + f * (b.MaxZ - b.MinZ)
            path = { Vector3.new(b.MinX, B.pos.Y, z), Vector3.new(b.MaxX, B.pos.Y, z) }
            if i % 2 == 0 then path = { path[2], path[1] } end
        else
            local x = b.MinX + f * (b.MaxX - b.MinX)
            path = { Vector3.new(x, B.pos.Y, b.MinZ), Vector3.new(x, B.pos.Y, b.MaxZ) }
            if i % 2 == 0 then path = { path[2], path[1] } end
        end
        EA.Roller(B.ctx, path, radius, 26, 0.9, { Mult = 1.3 })
    end
    B:Wait(B:W(0.9) + 4)
end
-- IMPLOSION: a ring closes in on you from 20 studs -- jump it as it arrives
function M.Implosion(B)
    local t = Aim(B)
    EA.Ring(B.ctx, t, 22, 0.8, { Mult = 1.3, Speed = 22, Inward = true, StartRadius = 2, Segments = 20 })
    B:Wait(B:W(0.8) + 1.2)
end
-- HORIZON: everything far from the boss is torn away -- a huge ring round it, the near ground (r 34) is safe
function M.Horizon(B)
    local stop = B:Charge(0.9)
    EA.Donut(B.ctx, B.pos, 34, 140, 1.8, { Mult = 1.7 })
    B:Wait(B:W(1.8))
    stop()
end
-- TRACE: a scanner sweeps the arena -- a line through your X, then a line through your Z, then both again
function M.Trace(B, width)
    local b = B.d.Bounds
    for k = 1, 4 do
        if not B:Alive() then break end
        local t = Aim(B)
        if k % 2 == 1 then
            EA.Line(B.ctx, Vector3.new(t.X, B.pos.Y, b.MinZ), Vector3.new(t.X, B.pos.Y, b.MaxZ), width, 0.6, { Mult = 1.3, Height = 12 })
        else
            EA.Line(B.ctx, Vector3.new(b.MinX, B.pos.Y, t.Z), Vector3.new(b.MaxX, B.pos.Y, t.Z), width, 0.6, { Mult = 1.3, Height = 12 })
        end
        B:Wait(0.45)
    end
    B:Wait(B:W(0.6))
end
-- REFRAIN: a ring of circles round you, then the same ring echoed, turned half a step
function M.Refrain(B, radius)
    local t = Aim(B)
    local a0 = math.random() * math.pi * 2
    for w = 0, 1 do
        for i = 0, 7 do
            local a = a0 + (i + w * 0.5) / 8 * math.pi * 2
            EA.Circle(B.ctx, B:Clamp(t + Vector3.new(math.cos(a), 0, math.sin(a)) * radius), radius * 0.45, 0.8 + w * 0.8, { Mult = 1.2 })
        end
    end
    B:Wait(B:W(1.6))
end
-- CLUTCH: eggs scattered round the arena burst at once, strands of web joining them -- find the open floor
function M.Clutch(B, n)
    local pts = {}
    for _ = 1, n do table.insert(pts, B:Spot(Aim(B), 6, 30)) end
    for i, q in ipairs(pts) do
        EA.Circle(B.ctx, q, 6, 0.9, { Mult = 1.2 })
        if i > 1 then EA.Line(B.ctx, pts[i - 1], q, 1.6, 0.9, { Mult = 1.0, Height = 8 }) end
    end
    B:Wait(B:W(0.9))
end
-- LUNGE CROSS: it lunges at you from the four diagonals, one after another
function M.LungeCross(B, width)
    local t = Aim(B)
    for i = 0, 3 do
        if not B:Alive() then break end
        local a = math.pi / 4 + i * math.pi / 2
        local d = Vector3.new(math.cos(a), 0, math.sin(a))
        EA.Line(B.ctx, B:Clamp(t - d * 40), B:Clamp(t + d * 40), width, 0.6, { Mult = 1.4, Height = 12 })
        B:Wait(0.3)
    end
    B:Wait(B:W(0.6))
end
-- RIPOSTE: thrusts to your left, your right, then straight at you
function M.Riposte(B, range)
    local d = Dir(B.pos, Aim(B))
    for _, off in ipairs({ -0.5, 0.5, 0 }) do
        if not B:Alive() then break end
        local a = math.atan2(d.Z, d.X) + off
        EA.Cone(B.ctx, B.pos, Vector3.new(math.cos(a), 0, math.sin(a)), range, 14, 0.55, { Mult = 1.4, Plain = M.PLAIN.Riposte })
        B:Wait(0.35)
    end
    B:Wait(B:W(0.55))
end
-- ROULETTE: the wheel round the boss -- find the wedge that doesn't strike.
-- (fixes 2026-10-16 #10, playtester: "pie chart boss attack too unfair"): it was 8 wedges, 7 striking at once after 1.3 s,
-- and the one safe wedge could be on the far side of the boss (~90 studs of walking at 30 studs out). Now the SAFE PAIR
-- (two wedges, a quarter of the wheel) is drawn GREEN, it opens within 80 degrees of where you stand, and the other six
-- strike in two waves of three (2.2 s, then the far half 0.8 s later) -- a short walk, with time to make it.
function M.Roulette(B, range)
    local r = B:Root()
    local you = r and math.atan2(r.Position.Z - B.pos.Z, r.Position.X - B.pos.X) or math.random() * math.pi * 2
    local safeMid = you + math.rad(math.random(-80, 80))
    local a0 = safeMid - math.pi / 8 -- (wedge 0 and wedge 1 are the safe pair, centred on safeMid)
    local WIND = 2.2
    local stop = B:Charge(0.9)
    EA.SafeCone(B.ctx, B.pos, Vector3.new(math.cos(safeMid), 0, math.sin(safeMid)), range, 45, WIND + 0.8)
    for wave = 0, 1 do
        if not B:Alive() then break end
        for j = 1, 3 do
            local i = (wave == 0) and (1 + j) or (8 - j) -- (2, 3, 4 then 7, 6, 5: one side of the wheel, then the other)
            local a = a0 + (i + 0.5) / 8 * math.pi * 2 - math.pi / 8
            EA.Cone(B.ctx, B.pos, Vector3.new(math.cos(a), 0, math.sin(a)), range, 22.5, WIND + wave * 0.8, { Mult = 1.6 })
        end
    end
    B:Wait(B:W(WIND + 0.8))
    stop()
end
-- REELS: three columns of the arena strike in a random order, like slot reels stopping
function M.Reels(B)
    local b = B.d.Bounds
    local w = (b.MaxX - b.MinX) / 3
    local order = { 0, 1, 2 }
    for i = 3, 2, -1 do local j = math.random(1, i); order[i], order[j] = order[j], order[i] end
    for k, col in ipairs(order) do
        if not B:Alive() then break end
        local x = b.MinX + (col + 0.5) * w
        EA.Line(B.ctx, Vector3.new(x, B.pos.Y, b.MinZ), Vector3.new(x, B.pos.Y, b.MaxZ), w - 2, 0.9, { Mult = 1.4, Height = 0 })
        B:Wait(0.75)
        local _ = k
    end
    B:Wait(B:W(0.9))
end
-- COIN TOSS: a coin bounces toward you, landing four times, each bounce a bigger circle
function M.Coins(B)
    for c = 1, 2 do
        if not B:Alive() then break end
        local t = Aim(B)
        local d = Dir(B.pos, t)
        for i = 1, 4 do
            EA.Circle(B.ctx, B:Clamp(B.pos + d * (Flat(t - B.pos).Magnitude * i / 3)), 3 + i * 1.5, 0.5 + i * 0.22, { Mult = 1.2 })
        end
        B:Wait(0.6)
        local _ = c
    end
    B:Wait(B:W(1.4))
end
-- JACKPOT: three rows across the arena strike one by one: 7, 7, 7
function M.Jackpot(B)
    local b = B.d.Bounds
    local h = (b.MaxZ - b.MinZ) / 3
    for i = 0, 2 do
        if not B:Alive() then break end
        local z = b.MinZ + (i + 0.5) * h
        EA.Line(B.ctx, Vector3.new(b.MinX, B.pos.Y, z), Vector3.new(b.MaxX, B.pos.Y, z), h - 2, 0.9, { Mult = 1.4, Height = 0 })
        B:Wait(0.8)
    end
    B:Wait(B:W(0.9))
end

local KITS = {}
local MINIBOSS_KINDS = { Goliath = true, Phantom = true, Sentinel = true, Ravager = true, Hexcaller = true }

-- GOLIATH -- a relentless juggernaut: chained charges, quake fissures, ring trains
local function GoliathCharge(B)
    local n = B.phase -- (v3: 1 / 2 / 3 charges, was 2 / 3 / 4)
    for _ = 1, n do
        local r = B:Root()
        if not r or not B:Alive() then return end
        local aim = B:Lead(0.25)
        local dir = Unit(aim - B.pos)
        local to = B:Clamp(B.pos + dir * 80)
        local len = (Flat(to - B.pos)).Magnitude
        B:Hold(B:W(0.55) + 0.45)
        local stop = B:Charge(0.5)
        EA.Line(B.ctx, B.pos, B.pos + dir * len, 10, 0.5, { Mult = 1.8, Height = 12 })
        B:Wait(B:W(0.5))
        stop()
        local from = B.pos
        B:Dash(to, math.max(0.45, len / 170)) -- (v3: a readable charge, ~170 studs/s; 80 studs in 0.28 s looked like a teleport)
        B:Boom(B.pos, 11, "BossSlam")
        -- (signature) it skids to a stop facing AWAY along its charge: its armoured front is turned, the backplate is open
        local stuck = ({ 2.3, 2.0, 1.7 })[B.phase] or 1.9 -- (2026-10-07: longer openings, was 1.7 / 1.4 / 1.2)
        B.faceDir, B.faceUntil = dir, os.clock() + stuck
        B.rooted = true
        B:Title(B.kit.Names[B.phase] .. "   >>  STUCK: HIT ITS BACK")
        B:Wait(stuck)
        B.rooted = false
        if B.phase >= 2 then
            -- the lane it tore through erupts a moment later
            for k = 1, 3 do EA.Zone(B.ctx, from:Lerp(B.pos, k / 4), 5, 0.35, 3.5, { Mult = 0.3 }) end
        end
        B:Wait(0.5)
    end
end
local function GoliathBulwark(B) -- (unused since the signature rework: its front is always armoured now)
    local shield = B.model:FindFirstChild("BarrierShield")
    if shield then shield.Transparency = 0.25 end
    B.d.SetTakenMult(B.model, 0.35)
    B:Title(B.kit.Names[B.phase] .. "  [SHIELDED: FLANK IT]")
    local r = B:Root()
    if r then EA.Mark(B.ctx, r, 8, 1.6, { Mult = 1.7, OnStrike = function(c) B:Boom(c, 8) end }) end
    B:Wait(B:W(1.0))
    M.Stomp(B, 14, 1, 0.45)
    B.d.SetTakenMult(B.model, 1)
    if shield and shield.Parent then shield.Transparency = 0.9 end
    B:Title(B.kit.Names[B.phase])
end
KITS.Goliath = {
    Color = Color3.fromRGB(255, 140, 30), Move = "Chase", Range = 18, SpeedMul = 1.1,
    Names = { "GOLIATH ENFORCER", "GOLIATH ENFORCER: ENRAGED", "GOLIATH ENFORCER: BERSERK" },
    -- (0.61e, owner: "Almost all of the minibosses do the same thing"): each miniboss now owns its attack family -- no
    -- pattern is shared between minibosses. GOLIATH = earth: charges (one per pass, a double in BERSERK), slams, rolling
    -- boulders, fault lines, rubble; it alone keeps the aftershock ripples.
    Moves = {
        { { GoliathCharge, "CHARGE" }, { function(B) M.Stomp(B, 14, 1, 0.5) end, "STOMP" }, { function(B) M.Roll(B, 1, 6, 46, "Ball") end, "BOULDER ROLL" },
          { function(B) M.Debris(B, 5, 5) end, "RUBBLE LINE" } },
        { { GoliathCharge, "CHARGE" }, { function(B) M.FaultLines(B, 9) end, "FAULT LINES" }, { function(B) M.Fissures(B, 3, 0.5) end, "EARTH WAVE" }, { function(B) M.TwinQuake(B) end, "AFTERSHOCK" },
          { function(B) M.Shockfront(B) end, "SHOCKFRONT" } },
        { { function(B) GoliathCharge(B); if B:Alive() then GoliathCharge(B) end end, "DOUBLE CHARGE" }, { function(B) M.Roll(B, 3, 6, 52, "Ball", true) end, "AVALANCHE" },
          { function(B) M.Debris(B, 8, 5) end, "RUBBLE LINE" }, { function(B) M.Ripple(B, 3, 30) end, "AFTERSHOCKS" } },
    },
}

-- PHANTOM -- an assassin: hunting death marks, blink flurries, converging lasers from decoys
local function PhantomDecoys(B)
    local r = B:Root()
    if not r then return end
    local origins = { function() return B.pos + Vector3.new(0, 1, 0) end }
    for i = 1, 1 + B.phase do
        local gp = B:Spot(r.Position, 30, 45)
        gp = Vector3.new(gp.X, B.pos.Y + 1, gp.Z)
        VFX.Ghost(B.d.Fx, gp, B.kit.Color, 2.4)
        table.insert(origins, function() return gp end)
    end
    M.Snipe(B, #origins * (B.phase >= 3 and 2 or 1), 0.85, origins, 0.12)
end
KITS.Phantom = {
    Color = Color3.fromRGB(180, 110, 255), Move = "Orbit", Range = 36, SpeedMul = 1.0,
    Names = { "PHANTOM STALKER", "PHANTOM STALKER: UNVEILED", "PHANTOM STALKER: NIGHTMARE" },
    Moves = {
        { { function(B) M.Snipe(B, 2, 0.95) end, "LOCK-ON" }, { M.Step, "SHADOW STEP" }, { function(B) M.Footsteps(B, 7, 6) end, "STALK" } },
        { { PhantomDecoys, "DECOYS" }, { function(B) M.Seekers(B, 2, Color3.fromRGB(190, 120, 255)) end, "SHADE HUNTERS" }, { function(B) M.Marks(B, 2) end, "DEATH MARK" }, { function(B) M.InOut(B, 13, 44, true, 1.0) end, "ECLIPSE" }, { M.Step, "SHADOW STEP" } },
        { { M.Step, "SHADOW STEP" }, { function(B) M.Predict(B, 4) end, "PREDATOR" }, { function(B) M.Cage(B, 8, 12, 0.95) end, "BLADE PRISON" }, { function(B) M.Footsteps(B, 9, 6) end, "STALK" },
          { function(B) M.ArenaWipe(B, 2, 8, 1.5) end, "NIGHTFALL" } },
    },
}

-- SENTINEL -- zone control: rotating floor lasers all fight long, pulse trains, a bastion you must get close to
-- (signature) VENT: after pulsing it overheats -- the shield drops, the core rises out of the hull and glows: shoot it
local function SentinelVent(B)
    local shield = B.model:FindFirstChild("Shield")
    local core = B.model:FindFirstChild("Core")
    B.rooted = true
    B.staggered = true
    B.rawTaken(B.model, 1.5)
    if shield then shield.Transparency = 0.9; shield.CanQuery = false end
    local coreSize = core and core.Size
    if core then core.Size = coreSize * 1.8; core.Color = Color3.fromRGB(255, 240, 160) end
    VFX.Banner("VENTING", "the shield is down: shoot the core", Color3.fromRGB(255, 220, 120))
    local tEnd = os.clock() + 3.2
    while B:Alive() and os.clock() < tEnd do
        B:Title(string.format("%s   >>  VENTING: SHOOT THE CORE (%ds)", B.kit.Names[B.phase], math.ceil(tEnd - os.clock())), Color3.fromRGB(255, 220, 120))
        B:Wait(0.1)
    end
    if core and core.Parent then core.Size = coreSize; core.Color = B.kit.Color end
    if shield and shield.Parent then shield.Transparency = 0.25; shield.CanQuery = true end
    B.staggered = false
    B.rawTaken(B.model, B.baseTaken or 1)
    B.rooted = false
end
local function SentinelPulses(B)
    B:Hold(1.0 + B.phase * 0.4)
    local stop = B:Charge(0.5)
    B:Wait(B:W(0.5))
    stop()
    -- (0.61d, owner: "Bosses spam these attacks so often": 2 + phase rings -> 2, a beat further apart; the rings have gaps)
    for _ = 1, 2 do
        if not B:Alive() then return end
        EA.Ring(B.ctx, B.pos, 80, 0.1, { Mult = 1.2, Speed = 30 + B.phase * 5 })
        B:Wait(0.9)
    end
    SentinelVent(B)
end
local function SentinelBastion(B)
    local panel = B.model:FindFirstChild("Shield")
    if panel then panel.Transparency = 0.2 end
    B.d.SetTakenMult(B.model, 0.25)
    B:Title(B.kit.Names[B.phase] .. "  [BASTION: REACH A SAFE CIRCLE]")
    M.ArenaWipe(B, 1, 9, 1.5, true) -- (three safe circles away from it)
    B.d.SetTakenMult(B.model, 1)
    if panel and panel.Parent then panel.Transparency = 0.9 end
    B:Title(B.kit.Names[B.phase])
end
KITS.Sentinel = {
    Color = Color3.fromRGB(90, 200, 255), Move = "Chase", Range = 26, SpeedMul = 0.7,
    Names = { "BULWARK SENTINEL", "BULWARK SENTINEL: OVERDRIVE", "BULWARK SENTINEL: MELTDOWN" },
    Moves = {
        { { function(B) M.Sweep(B, 2, 3.0) end, "SWEEPER" }, { function(B) M.Mines(B, 13) end, "ORBITAL MINES" }, { SentinelPulses, "PULSE" },
          { function(B) M.Pylons(B, 2, 6, Color3.fromRGB(90, 200, 255)) end, "SHIELD PYLONS" } },
        -- (0.61e/f) SENTINEL = lasers and grids only: laser grid, closing beams, triple sweep, spoke storm (its old
        -- ripples / collapse / target circles were the Goliath's, the Hexcaller's and the Phantom's moves)
        { { SentinelPulses, "PULSE" }, { SentinelBastion, "BASTION" }, { function(B) M.Lanes(B, 4, 5, 8, 0.85, false) end, "LASER GRID" },
          { function(B) M.Bounce(B, 6) end, "RICOCHET BEAM" } },
        { { SentinelPulses, "PULSE" }, { function(B) M.Pincer(B, 12, 0.9, 0.42) end, "CLOSING BEAMS" }, { function(B) M.TwinQuake(B) end, "SHOCK EMITTERS" },
          { function(B) M.Predict(B, 4) end, "TARGET LOCK" }, { function(B) M.Pylons(B, 3, 6, Color3.fromRGB(90, 200, 255)) end, "SHIELD PYLONS" } },
    },
}

-- RAVAGER (2026-10-07) -- a beast: it POUNCES where you stand, swipes, howls; its FRENZY builds to a RAMPAGE
local function RavagerPounce(B, count)
    count = count or 1
    if B.rampage then count = 3 end
    for n = 1, count do
        local r = B:Root()
        if not r or not B:Alive() then return end
        local at = B:Clamp(r.Position)
        local wu = (n == 1) and 0.95 or 0.7
        B:Hold(B:W(wu) + 0.7)
        EA.Circle(B.ctx, at, 10, wu, { Mult = B.rampage and 1.6 or 1.4, Sound = "BossSlam", OnStrike = function(c)
            B:Boom(c, 12, "BossSlam")
            if B.phase >= 2 then EA.Ring(B.ctx, c, 46, 0.05, { Mult = 0.9, Speed = 30 }) end
        end })
        B:Wait(B:W(wu) * 0.5)
        B.yOff = 7
        B:Dash(at - Unit(at - B.pos) * 3, B:W(wu) * 0.5)
        B.yOff = 0
        B:Wait(0.55)
    end
    B.rampage = false
end
local function RavagerSwipe(B)
    local r = B:Root()
    if not r then return end
    local base = Unit(Flat(r.Position - B.pos))
    B:Hold(B:W(0.8) + 0.9)
    -- a short wide claw rake, then the other paw from the other side
    for i, a in ipairs({ -0.5, 0.5 }) do
        local dir = CFrame.fromAxisAngle(Vector3.yAxis, a):VectorToWorldSpace(base)
        task.delay((i - 1) * B:W(0.45), function() if B:Alive() then EA.Cone(B.ctx, B.pos, dir, 26, 40, 0.8, { Mult = 1.3, Strips = 4, Plain = M.PLAIN.Rake }) end end)
    end
    B:Wait(B:W(0.8) + 0.5)
end
local function RavagerHowl(B)
    local stop = B:Charge(0.7)
    B:Wait(B:W(0.7))
    stop()
    for k = 1, (B.phase >= 3 and 2 or 1) do
        if not B:Alive() then return end
        EA.Ring(B.ctx, B.pos, 70, 0.05, { Mult = 1.1, Speed = 26 + k * 4, StartRadius = 4 })
        B:Wait(0.7)
    end
    B:Wait(0.6)
end
KITS.Ravager = {
    Color = Color3.fromRGB(255, 96, 60), Move = "Chase", Range = 22, SpeedMul = 1.15,
    Names = { "RAVAGER", "RAVAGER: BLOODIED", "RAVAGER: FERAL" },
    Moves = {
        { { RavagerPounce, "POUNCE" }, { RavagerSwipe, "RAKE" }, { RavagerHowl, "HOWL" }, { function(B) M.Flank(B, 26) end, "PROWL" } },
        { { function(B) RavagerPounce(B, 2) end, "POUNCE" }, { function(B) M.Stampede(B, 4, 8) end, "STAMPEDE" }, { RavagerSwipe, "RAKE" },
          { function(B) M.Pounce(B, 3, 7) end, "CORNERED" }, { function(B) M.Predict(B, 4) end, "CUT OFF" }, { RavagerHowl, "HOWL" } },
        { { function(B) RavagerPounce(B, 2) end, "POUNCE" }, { function(B) M.Stampede(B, 4, 8) end, "STAMPEDE" }, { RavagerHowl, "HOWL" },
          { function(B) M.Claws(B, 2) end, "SHRED" }, { RavagerSwipe, "RAKE" } },
    },
}

-- HEXCALLER (2026-10-07) -- a caster: slow hexes and sigils while three warding crystals circle it (break them all)
KITS.Hexcaller = {
    Color = Color3.fromRGB(70, 235, 190), Move = "Orbit", Range = 40, SpeedMul = 0.85,
    Names = { "HEXCALLER", "HEXCALLER: UNBOUND", "HEXCALLER: ASCENDANT" },
    Moves = {
        -- (0.61e/f) HEXCALLER = spell patterns: hex rain, snares, orbiting hexes, wards, spirals, walls, stars, hex storm
        -- (its SIGIL target circles were the Phantom's DEATH MARK, its COLLAPSE the Sentinel's)
        { { function(B) M.Hexfall(B, 6) end, "HEX RAIN" }, { function(B) M.Linger(B, 6, 3) end, "HEX SNARE" }, { function(B) M.Sigils(B, 60) end, "ORBITING HEX" } },
        { { function(B) M.Pylons(B, 2, 6, Color3.fromRGB(70, 235, 190)) end, "HEX TOTEMS" }, { function(B) M.Ward(B, 5, 24) end, "WARD CIRCLE" },
          { function(B) M.Crossfire(B, 2, 6, 0.9) end, "HEX WALL" }, { function(B) M.Hexfall(B, 6) end, "HEX RAIN" } },
        { { function(B) M.Linger(B, 8, 4) end, "CURSED GROUND" }, { function(B) M.Star(B, 22) end, "HEX STAR" },
          { function(B) M.Hexfall(B, 8) end, "HEX STORM" }, { function(B) M.Predict(B, 4) end, "CURSED STEPS" }, { function(B) M.Crossfire(B, 2, 6, 0.9) end, "HEX WALL" } },
    },
}

-- APEX TITAN -- artillery that never stops, carpet bombing, sweeping lasers, escorts, an orbital strike
local function TitanEscorts(B)
    if not (B.d.Summon and B.d.LiveAdds) then return M.Carpet(B, 5, 4, 6, 0.75, 0.2) end
    local missing = 2 - B.d.LiveAdds()
    if missing <= 0 then return M.Carpet(B, 5 + B.phase, 4, 6, 0.75, 0.18) end
    local spots = {}
    for i = 1, missing do table.insert(spots, B.pos + Vector3.new(i == 1 and 20 or -20, 12, math.random(-15, 15))) end
    B:Boom(B.pos + Vector3.new(0, 4, 0), 12)
    B.d.Summon(spots)
    B:Wait(0.6)
end
local function TitanSweep(B)
    local r = B:Root()
    if not r then return end
    local a0 = math.atan2(r.Position.X - B.pos.X, r.Position.Z - B.pos.Z) - math.rad(100)
    B:Hold(B:W(0.6) + 1.6)
    local stop = B:Charge(0.6)
    EA.Sweep(B.ctx, function() return B.pos end, a0, math.rad(200), 1.5 - B.phase * 0.15, 130, { Mult = 1.6, Width = 3.2, Height = 3.6, Warn = 0.6 })
    if B.phase >= 2 then
        EA.Sweep(B.ctx, function() return B.pos end, a0 + math.rad(200), -math.rad(200), 1.5 - B.phase * 0.15, 130, { Mult = 1.6, Width = 3.2, Height = 3.6, Warn = 0.9 })
    end
    B:Wait(B:W(0.6) + 1.4)
    stop()
end
KITS.Titan = {
    Color = Color3.fromRGB(255, 60, 60), Move = "Orbit", Range = 34, SpeedMul = 0.9,
    Names = { "APEX TITAN MECH", "APEX TITAN MECH: WEAPONS FREE", "APEX TITAN MECH: OVERLOAD" },
    Moves = {
        { { function(B) M.Rain(B, 2 + 2 * (B.gunsUp or 2), 6, 0.9, 0, 0.45) end, "ARTILLERY" }, { function(B) M.Carpet(B, 4, 4, 6, 0.9, 0.3) end, "CARPET BOMB" }, { function(B) M.Stomp(B, 14, 1, 0.5) end, "STOMP" } },
        { { function(B) M.Rain(B, 2 + 2 * (B.gunsUp or 2), 6, 0.85, 0, 0.42) end, "ARTILLERY" }, { TitanSweep, "SWEEP" }, { TitanEscorts, "ESCORTS" },
          { function(B) M.MortarRing(B) end, "MORTAR RING" }, { function(B) M.Pylons(B, 3, 6, Color3.fromRGB(255, 70, 50)) end, "SENSOR PYLONS" } },
        { { function(B) M.Rain(B, 3 + 2 * (B.gunsUp or 2), 6, 0.8, 0, 0.4) end, "ARTILLERY" }, { function(B) M.Tide(B, 3, true) end, "SIEGE WALL" },
          { function(B) M.Checker(B, 34, 0.95) end, "BOMBARDMENT" }, { function(B) M.Salvo(B, 6) end, "ORBITAL SALVO" },
          { function(B) M.Seekers(B, 3, Color3.fromRGB(255, 90, 60)) end, "HUNTER MISSILES" } },
    },
}

-- BIOME SUPERBOSSES -- each biome's signature fight
local function FireBreath(B)
    local r = B:Root()
    if not r then return end
    B:Hold(2.2)
    local base = Unit(r.Position - B.pos)
    local sweeps = 1 + B.phase -- (v3: 2 / 3 / 4 gouts sweeping one way, 0.4 s apart -- were 4-6 alternating every 0.2 s)
    for i = 0, sweeps - 1 do
        if not B:Alive() then return end
        local a = (i - (sweeps - 1) / 2) * math.rad(30)
        local dir = CFrame.fromAxisAngle(Vector3.yAxis, a):VectorToWorldSpace(base)
        EA.Cone(B.ctx, B.pos, dir, 50, 22, 0.8, { Mult = 1.5, Strips = 5 })
        B:Wait(0.4)
    end
    B:Wait(B:W(0.8))
end
local function Meteors(B)
    local n = 1 + B.phase
    local stop = B:Charge(1.0)
    for i = 1, n do
        local at = (i == 1) and B:Lead(0.7) or B:Spot(B:Lead(0.4), 8, 26)
        EA.Circle(B.ctx, at, 15, 1.25, { Mult = 2.0, Height = 16, Sound = "Explosion", OnStrike = function(c)
            B:Boom(c, 18, nil)
            EA.Zone(B.ctx, c, 9, 0.05, 4, { Mult = 0.35 })
        end })
        B:Wait(0.3)
    end
    B:Wait(B:W(1.25))
    stop()
end
local function FrostNova(B)
    B:Hold(B:W(1.0) + 0.6)
    local stop = B:Charge(0.95)
    EA.Circle(B.ctx, B.pos, 26, 0.95, { Mult = 1.8, Height = 14, Sound = "BossSlam", OnStrike = function(c) B:Boom(c, 26) end })
    B:Wait(B:W(0.95))
    stop()
    for i = 1, B.phase do
        EA.Ring(B.ctx, B.pos, 85, 0.1, { Mult = 1.1, Speed = 40 + i * 4 })
        B:Wait(0.4)
    end
    for _ = 1, B.phase do EA.Zone(B.ctx, B:Spot(B.pos, 18, 40), 8, 0.5, 5, { Mult = 0.3 }) end
end
local function Singularity(B)
    local c = Vector3.new((B.d.Bounds.MinX + B.d.Bounds.MaxX) / 2, B.pos.Y, (B.d.Bounds.MinZ + B.d.Bounds.MaxZ) / 2)
    local stop = B:Charge(1.1)
    VFX.Ghost(B.d.Fx, c, B.kit.Color, 2)
    EA.Circle(B.ctx, c, 22, 1.15, { Mult = 1.8, Height = 16, Sound = "Explosion", OnStrike = function(p) B:Boom(p, 22) end })
    B:Wait(B:W(1.15))
    stop()
    -- (0.63: was a spoke fan out of the centre) the collapse throws two rings out of it -- jump them
    for k = 1, 2 do
        if not B:Alive() then return end
        EA.Ring(B.ctx, c, 90, 0.7, { Mult = 1.1, Speed = 30 + 6 * B.phase, StartRadius = 23 })
        B:Wait(B:W(0.7) + 0.5)
    end
end
local function GridFloor(B)
    local b = B.d.Bounds
    local stop = B:Charge(0.8)
    local step = 20
    local off = math.random(0, step - 1)
    for x = b.MinX + off, b.MaxX, step do
        EA.Line(B.ctx, Vector3.new(x, B.pos.Y, b.MinZ), Vector3.new(x, B.pos.Y, b.MaxZ), 6, 0.8, { Mult = 1.4, Height = 14 })
    end
    B:Wait(B:W(0.8) * 0.6)
    stop()
    off = math.random(0, step - 1)
    for z = b.MinZ + off, b.MaxZ, step do
        EA.Line(B.ctx, Vector3.new(b.MinX, B.pos.Y, z), Vector3.new(b.MaxX, B.pos.Y, z), 6, 0.8, { Mult = 1.4, Height = 14 })
    end
    B:Wait(B:W(0.8))
end
local function DroneLocks(B)
    local origins = {}
    for i = 1, 2 + B.phase do
        local a = (i / (2 + B.phase)) * math.pi * 2
        local sp = B.pos + Vector3.new(math.cos(a) * 20, 8, math.sin(a) * 20)
        VFX.Ghost(B.d.Fx, sp, B.kit.Color, 2.4)
        table.insert(origins, function() return sp end)
    end
    M.Snipe(B, #origins, 0.85, origins, 0.15)
end
-- ===== TEMPEST SOVEREIGN (STORMSPIRE superboss) -- every move asks you to read lightning differently =====
-- CONDUCTOR WEB: it plants lightning rods across the arena and arcs lightning BETWEEN them, re-wiring the web each wave
local function ConductorWeb(B)
    local b = B.d.Bounds
    local n = 4 + B.phase
    local rods = {}
    for _ = 1, n do
        local p = Vector3.new(b.MinX + math.random() * (b.MaxX - b.MinX), B.pos.Y, b.MinZ + math.random() * (b.MaxZ - b.MinZ))
        table.insert(rods, p)
        VFX.Ghost(B.d.Fx, p + Vector3.new(0, 4, 0), B.kit.Color, 1.4 + B.phase * 0.9)
    end
    local stop = B:Charge(0.6)
    B:Wait(B:W(0.5))
    stop()
    for wave = 1, 1 + B.phase do
        if not B:Alive() then return end
        for i = 1, n do
            local j = ((i - 1 + wave) % n) + 1 -- each wave connects every rod to a different partner
            if j ~= i then EA.Line(B.ctx, rods[i], rods[j], 4, 0.75, { Mult = 1.2, Height = 12 }) end
        end
        B:Wait(B:W(0.75) + 0.25)
    end
end
-- CHAIN LIGHTNING: a strike that keeps hopping to where you're heading, a little faster each hop
local function ChainLightning(B)
    if not B:Root() then return end
    local stop = B:Charge(0.5)
    task.delay(B:W(0.5), stop)
    for i = 1, 3 + B.phase do
        if not B:Alive() then return end
        EA.Circle(B.ctx, B:Lead(0.45), 5, 0.8, { Mult = 1.1 })
        B:Wait(0.42)
    end
    B:Wait(B:W(0.6))
end
-- DOWNBURST: a wall of rain sweeps across the arena -- one gap in it, and the gap drifts: follow it
local function Downburst(B)
    local b = B.d.Bounds
    local horiz = math.random() < 0.5
    local rows, cols = 6, 11
    local gap = math.random(2, cols - 3)
    local stop = B:Charge(0.6)
    task.delay(B:W(0.6), stop)
    for row = 0, rows - 1 do
        if not B:Alive() then return end
        local t = row / (rows - 1)
        for col = 0, cols - 1 do
            if col ~= gap and col ~= gap + 1 then
                local u = col / (cols - 1)
                local p = horiz and Vector3.new(b.MinX + (b.MaxX - b.MinX) * u, B.pos.Y, b.MinZ + (b.MaxZ - b.MinZ) * t)
                    or Vector3.new(b.MinX + (b.MaxX - b.MinX) * t, B.pos.Y, b.MinZ + (b.MaxZ - b.MinZ) * u)
                EA.Circle(B.ctx, p, 8, 0.7, { Mult = 1.1 })
            end
        end
        B:Wait(0.4)
        gap = math.clamp(gap + math.random(-1, 1), 1, cols - 3)
    end
    B:Wait(B:W(0.7))
end
-- EYE OF THE STORM: the whole arena lights up but three calm circles (0.59: they were one circle beside the boss). Then a
-- shockwave rolls out from it: jump it.
-- (owner 2026-10-05: "The boss attack that highlights the middle breaks and hits the entire map": the shockwave left the
-- safe circle 0.1 s after the wipe, so whoever stood in the "safe" spot was hit anyway -- every spot was a hit. Now the
-- safe circle is bigger, the ring waits and winds up (a pulse at the boss) and it starts at the circle's edge: jump it.)
local function EyeOfTheStorm(B)
    B:Hold(B:W(1.4) + 1.6)
    local stop = B:Charge(1.4)
    VFX.ScreenFlash(B.kit.Color, 0.2)
    local eye = Vector3.new(B.pos.X, B.pos.Y, B.pos.Z)
    local calm = {}
    local base = math.random() * math.pi * 2
    for i = 1, 3 do
        local a = base + (i - 1) / 3 * math.pi * 2
        table.insert(calm, { Pos = B:Clamp(eye + Vector3.new(math.cos(a), 0, math.sin(a)) * 34), R = 12 })
    end
    EA.Arena(B.ctx, B.d.Bounds, calm, 1.4, { Mult = 1.9 })
    B:Wait(B:W(1.4) + 0.3)
    stop()
    EA.Ring(B.ctx, eye, 70, 0.8, { Mult = 1.0, Speed = 30, StartRadius = 4 })
    B:Wait(B:W(0.8))
end

local SUPER = {
    Fire = {
        Color = Color3.fromRGB(255, 100, 30), Move = "Chase", Range = 22, SpeedMul = 0.8, Recover = { 1.9, 1.6, 1.3 },
        Names = { "IGNIS, THE FORGE TYRANT", "IGNIS: MOLTEN FURY", "IGNIS: CATACLYSM" },
        Moves = {
            { { FireBreath, "FIRE BREATH" }, { function(B) M.Rain(B, 6, 7, 0.85, 0, 0.42) end, "EMBER RAIN" }, { function(B) M.Pools(B, 3) end, "MAGMA VENTS" } },
            { { Meteors, "METEORS" }, { function(B) M.Pools(B, 4) end, "LAVA POOLS" }, { function(B) M.Eruption(B, 8) end, "FLAME VENTS" }, { FireBreath, "FIRE BREATH" } },
            { { function(B) M.Carpet(B, 2, 5, 6, 0.9, 0.5) end, "MAGMA RAIN" }, { function(B) M.Eruption(B, 14) end, "MOLTEN CORE" }, { FireBreath, "FIRE BREATH" },
              { function(B) M.ArenaWipe(B, 3, 8, 1.5) end, "CATACLYSM" } },
        },
    },
    Ice = {
        Color = Color3.fromRGB(140, 210, 255), Move = "Chase", Range = 24, SpeedMul = 0.8, Recover = { 1.9, 1.6, 1.3 },
        Names = { "THE FROST SOVEREIGN", "FROST SOVEREIGN: WHITEOUT", "FROST SOVEREIGN: ABSOLUTE ZERO" },
        Moves = {
            { { FrostNova, "FROST NOVA" }, { function(B) M.Rain(B, 7, 4, 0.8, 0, 0.4) end, "ICICLES" }, { function(B) M.Quadrants(B, 70, 2, 0.95) end, "SHATTER" } },
            { { function(B) M.Converge(B, 2, 1.0) end, "BLIZZARD WALL" }, { function(B) M.Prison(B, 12) end, "ICE PRISON" }, { FrostNova, "FROST NOVA" },
              { function(B) M.Halves(B, 1.4) end, "WHITEOUT" } },
            { { function(B) M.Bloom(B, 20) end, "CRYSTAL BLOOM" }, { function(B) M.Floes(B, 5, 6) end, "ICE FLOES" }, { function(B) M.Lanes(B, 5, 6, 7, 0.8, true) end, "GLACIER CROSS" },
              { function(B) M.Freeze(B, 36) end, "ABSOLUTE ZERO" } },
        },
    },
    Void = {
        Color = Color3.fromRGB(170, 80, 255), Move = "Orbit", Range = 32, SpeedMul = 1.0, Recover = { 1.9, 1.6, 1.3 },
        Names = { "THE UNBLINKING", "THE UNBLINKING: OPEN EYE", "THE UNBLINKING: EVENT HORIZON" },
        Moves = {
            -- (0.61f, owner: "there needs to be more variety": it was the Phantom Stalker's kit -- shadow step, death mark, decoys,
            -- stalking steps -- so a Void run met the same moves twice. Its own set now.)
            { { function(B) M.Orbit(B, 3, 5, 5) end, "ORBITING EYES" }, { function(B) M.Salvo(B, 6) end, "STAR FALL" }, { function(B) M.Converge(B, 3, 0.9) end, "COLLAPSING RIFT" } },
            { { Singularity, "SINGULARITY" }, { function(B) M.Halves(B, 1.4) end, "SPLIT REALITY" }, { function(B) M.Implosion(B) end, "VOID PRISON" }, { function(B) M.Orbit(B, 4, 6, 4.4) end, "ORBITING EYES" } },
            { { Singularity, "SINGULARITY" }, { function(B) M.MortarRing(B) end, "DARK STARS" }, { function(B) M.Converge(B, 3, 0.8) end, "COLLAPSING RIFT" },
              { function(B) M.Horizon(B) end, "EVENT HORIZON" } },
        },
    },
    Cyber = {
        Color = Color3.fromRGB(60, 255, 190), Move = "Orbit", Range = 34, SpeedMul = 0.9, Recover = { 1.9, 1.6, 1.3 },
        Names = { "OMNISCIENCE CORE", "OMNISCIENCE CORE: OVERCLOCKED", "OMNISCIENCE CORE: KERNEL PANIC" },
        Moves = {
            { { GridFloor, "GRID" }, { DroneLocks, "DRONE LOCK" }, { function(B) M.Carpet(B, 4, 4, 6, 0.85, 0.3) end, "PACKET STORM" } },
            { { function(B) M.Roll(B, 3, 5, 55, "Wheel", true) end, "DATA PACKETS" }, { function(B) M.Checker(B, 34, 1.0) end, "BIT FLIP" }, { DroneLocks, "DRONE LOCK" },
              { function(B) M.ArenaWipe(B, 3, 8, 1.5) end, "PURGE" } },
            { { GridFloor, "GRID" }, { function(B) M.Tide(B, 3, true) end, "PACKET WAVE" }, { function(B) M.Trace(B, 6) end, "TRACE ROUTE" },
              { function(B) M.ArenaWipe(B, 2, 8, 1.5) end, "KERNEL PANIC" } },
        },
    },
    Storm = {
        Color = Color3.fromRGB(150, 210, 255), Move = "Orbit", Range = 30, SpeedMul = 0.9, Recover = { 1.9, 1.6, 1.3 },
        Names = { "TEMPEST SOVEREIGN", "TEMPEST SOVEREIGN: GATHERING", "TEMPEST SOVEREIGN: EYE OF THE STORM" },
        Moves = {
            { { ConductorWeb, "CONDUCTOR WEB" }, { ChainLightning, "CHAIN LIGHTNING" } },
            { { Downburst, "DOWNBURST" }, { function(B) M.Carpet(B, 3, 4, 5, 0.85, 0.45) end, "THUNDERCLAPS" }, { ChainLightning, "CHAIN LIGHTNING" } },
            { { EyeOfTheStorm, "EYE OF THE STORM" }, { function(B) M.Orbit(B, 4, 6, 4.2) end, "CYCLONE" }, { ConductorWeb, "CONDUCTOR WEB" }, { function(B) M.Tide(B, 2, true) end, "STORM SURGE" } },
        },
    },
}
-- ==================== ENDGAME TRIAL BOSSES (BossTrials) -- each built around ONE mechanic you have to learn ====================
-- posing helpers: parts matched by name are re-placed every frame from their rest offset (BossAI moves the model with
-- PivotTo, then the kit's Animate(B, pivot, now) turns wings / hands / shards about model-space hinges)
local function PoseParts(B, pattern)
    B.poseCache = B.poseCache or {}
    local list = B.poseCache[pattern]
    if not list then
        list = {}
        local pv = B.model:GetPivot()
        for _, p in ipairs(B.model:GetDescendants()) do
            if p:IsA("BasePart") and string.find(p.Name, pattern, 1, true) then table.insert(list, { Part = p, Off = pv:ToObjectSpace(p.CFrame) }) end
        end
        B.poseCache[pattern] = list
    end
    return list
end
-- (0.62 human-sized bosses: DungeonGenerator shrinks every boss with Model:ScaleTo, so the hinge / slide offsets written
-- in full-size studs below are scaled by the model's scale)
local function Scaled(cf: CFrame, k: number): CFrame
    if k == 1 then return cf end
    return cf.Rotation + cf.Position * k
end
local function Pose(B, pattern, pivot, hinge, rot)
    B.poseScale = B.poseScale or B.model:GetScale()
    local k = B.poseScale
    hinge, rot = Scaled(hinge, k), Scaled(rot, k)
    for _, e in ipairs(PoseParts(B, pattern)) do
        e.Part.CFrame = pivot * hinge * rot * hinge:Inverse() * e.Off
    end
end

-- the walker: legs stride with its movement (diagonal pairs), rotary cannons spin up while it attacks,
-- the reactor ring turns, missile pods pulse (EnemyModels "Titan" names the parts)
KITS.Titan.Animate = function(B, pivot, now)
    local dt = math.min(0.1, now - (B.animT or now)); B.animT = now
    local moved = Flat(B.pos - (B.animPos or B.pos)).Magnitude
    B.animPos = B.pos
    B.stride = (B.stride or 0) + moved * 0.45
    B.walkW = (B.walkW or 0) + (((moved > 0.01) and 1 or 0) - (B.walkW or 0)) * math.min(1, dt * 6)
    local T = Vector3.new(10, 14, 7)
    for i, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
        local o = Vector3.new(c[1], 0, c[2]).Unit
        local ph = B.stride + ((i == 1 or i == 4) and 0 or math.pi)
        local lift = math.max(0, math.sin(ph)) * 0.42 * B.walkW + math.sin(now * 1.3 + i) * 0.015
        local hip = CFrame.new(c[1] * (T.X / 2 - 0.6), -T.Y * 0.32, c[2] * (T.Z / 2 - 0.8))
        Pose(B, "Deco_Leg" .. i, pivot, hip, CFrame.fromAxisAngle(o:Cross(Vector3.yAxis), lift))
    end
    Pose(B, "Deco_Reactor", pivot, CFrame.new(0, 2.0, -4.5), CFrame.Angles(0, 0, now * (1.2 + B.phase * 0.8)))
    B.spin = (B.spin or 0) + dt * ((B.active > 0) and (10 + B.phase * 4) or 1.5)
    for _, sx in ipairs({ -1, 1 }) do
        local side = sx < 0 and "L" or "R"
        local elbow = Vector3.new(sx * (T.X / 2 + 2.4), -T.Y * 0.12, -1.6)
        Pose(B, "Deco_Barrel" .. side, pivot, CFrame.new(elbow + Vector3.new(0, -0.4, -3.4)), CFrame.Angles(0, 0, B.spin * sx))
    end
    local pulse = 0.5 + 0.5 * math.sin(now * (3 + B.phase * 2))
    for _, e in ipairs(PoseParts(B, "Deco_GlowPod")) do e.Part.Transparency = 0.45 * (1 - pulse) end
end
-- Goliath: wheels roll with its movement, the ram punches out on a charge
KITS.Goliath.Animate = function(B, pivot, now)
    local moved = Flat(B.pos - (B.animPos or B.pos)).Magnitude
    B.animPos = B.pos
    local sk = B.poseScale or B.model:GetScale() -- (0.62: hinges below are full-size studs; the boss is shrunk)
    B.roll = (B.roll or 0) + moved / (0.85 * sk)
    local T = Vector3.new(7, 6, 6)
    for k = 0, 3 do
        local z = -T.Z / 2 + 0.3 + k * (T.Z - 0.6) / 3
        for _, sx in ipairs({ -1, 1 }) do
            local side = sx < 0 and "L" or "R"
            -- (each wheel is its own pattern so it turns about its own axle)
            B.wheels = B.wheels or {}
            local key = side .. k
            if not B.wheels[key] then
                local list = {}
                for _, e in ipairs(PoseParts(B, "Deco_Wheel" .. side)) do
                    if math.abs(e.Off.Position.Z - z * sk) < 0.3 * sk then table.insert(list, e) end
                end
                B.wheels[key] = list
            end
            local hinge = CFrame.new(Vector3.new(sx * (T.X / 2 + 1.0), -T.Y / 2 - 0.15, z) * sk)
            for _, e in ipairs(B.wheels[key]) do e.Part.CFrame = pivot * hinge * CFrame.Angles(-B.roll, 0, 0) * hinge:Inverse() * e.Off end
        end
    end
    B.ramOut = (B.ramOut or 0) + (((B.dashing and 1) or 0) - (B.ramOut or 0)) * 0.35
    Pose(B, "Deco_Ram", pivot, CFrame.new(), CFrame.new(0, 0, -1.4 * B.ramOut))
end
-- Phantom: the cloak billows, the scythes sway (and rise while it's attacking), the shard crown turns
KITS.Phantom.Animate = function(B, pivot, now)
    local T = Vector3.new(4.6, 5.4, 4.6)
    Pose(B, "Deco_Cloak", pivot, CFrame.new(0, 1.2, 0), CFrame.Angles(math.sin(now * 2.1) * 0.06, math.sin(now * 0.7) * 0.15, math.sin(now * 1.7) * 0.05))
    B.raise = (B.raise or 0) + ((((B.active > 0) and 1) or 0) - (B.raise or 0)) * 0.15
    for _, sx in ipairs({ -1, 1 }) do
        local side = sx < 0 and "L" or "R"
        local sway = math.sin(now * 1.6 + sx) * 0.12 - B.raise * 0.55
        Pose(B, "Deco_Arm" .. side, pivot, CFrame.new(sx * T.X * 0.48, T.Y * 0.18, 0), CFrame.Angles(sway, 0, sx * math.sin(now * 1.1) * 0.08))
    end
    Pose(B, "Deco_Crown", pivot, CFrame.new(0, T.Y * 0.75 + 0.6, 0), CFrame.Angles(0, now * 1.4, 0))
end
-- Ravager: legs stride in diagonal pairs, the jaw opens while it attacks, the tail sways
KITS.Ravager.Animate = function(B, pivot, now)
    local T = Vector3.new(6, 4.4, 8)
    local stride = math.sin(now * 7) * 0.45
    for _, sx in ipairs({ -1, 1 }) do
        for _, sz in ipairs({ -1, 1 }) do
            local s = (sx * sz > 0) and stride or -stride
            Pose(B, "Deco_Leg" .. (sx < 0 and "L" or "R") .. (sz < 0 and "F" or "B"), pivot, CFrame.new(sx * T.X * 0.5, 0, sz * T.Z * 0.32), CFrame.Angles(s, 0, 0))
        end
    end
    B.raise = (B.raise or 0) + ((((B.active > 0) and 1) or 0) - (B.raise or 0)) * 0.2
    Pose(B, "Deco_Jaw", pivot, CFrame.new(0, 0.6, -T.Z / 2 - 0.2), CFrame.Angles(B.raise * 0.5, 0, 0))
    Pose(B, "Deco_Tail", pivot, CFrame.new(0, 0.6, T.Z / 2), CFrame.Angles(0, math.sin(now * 2.4) * 0.35, 0))
end
-- Hexcaller: the robe drifts, the sigil ring turns, the staff raises while it casts
KITS.Hexcaller.Animate = function(B, pivot, now)
    local T = Vector3.new(4.4, 6, 4.4)
    Pose(B, "Deco_Robe", pivot, CFrame.new(0, -T.Y * 0.1, 0), CFrame.Angles(math.sin(now * 1.8) * 0.05, math.sin(now * 0.6) * 0.2, 0))
    Pose(B, "Deco_Sigil", pivot, CFrame.new(), CFrame.Angles(0, now * (0.8 + B.phase * 0.4), 0))
    B.raise = (B.raise or 0) + ((((B.active > 0) and 1) or 0) - (B.raise or 0)) * 0.15
    Pose(B, "Deco_Staff", pivot, CFrame.new(3, -T.Y * 0.55, -0.6), CFrame.Angles(-B.raise * 0.5, 0, 0))
end
-- Sentinel: rune ring + crown turn, crystals bob, drones orbit
KITS.Sentinel.Animate = function(B, pivot, now)
    local T = Vector3.new(8, 9, 8)
    Pose(B, "Deco_BaseRing", pivot, CFrame.new(), CFrame.Angles(0, now * 0.5, 0))
    Pose(B, "Deco_Crown", pivot, CFrame.new(), CFrame.Angles(0, -now * (1 + B.phase * 0.6), 0))
    Pose(B, "Deco_Orbit", pivot, CFrame.new(), CFrame.Angles(0, now * (0.9 + B.phase * 0.4), 0))
    for i = 1, 4 do
        Pose(B, "Deco_Crystal" .. i, pivot, CFrame.new(), CFrame.new(0, math.sin(now * 2 + i * 1.6) * 0.45, 0))
    end
end
-- SUPERBOSSES v3 animation (EnemyModels.SUPER_BODIES names the parts; model space, -Z faces the player)
local function Lift(B, rate)
    B.lift = (B.lift or 0) + ((((B.active > 0) and 1) or 0) - (B.lift or 0)) * (rate or 0.08)
    return B.lift
end
-- Ignis: the knuckle-walking arms sway, rear up while it attacks and pound down after; the jaw drops
SUPER.Fire.Animate = function(B, pivot, now)
    local l = Lift(B, 0.1)
    for _, sx in ipairs({ -1, 1 }) do
        local swing = math.sin(now * 1.8 + (sx > 0 and math.pi or 0)) * 0.08 - l * 0.9
        Pose(B, "Deco_Arm" .. (sx < 0 and "L" or "R"), pivot, CFrame.new(sx * 9, 3, -0.5), CFrame.Angles(swing, 0, sx * l * 0.15))
    end
    Pose(B, "Deco_Jaw", pivot, CFrame.new(0, 2.6, -4.4), CFrame.Angles(l * 0.45 + math.sin(now * 2) * 0.03, 0, 0))
end
-- BOSS LOOK v2 (AimRngShared/BossLook): the pill-family bodies pose their own Deco_* pieces with this Pose
M.LookAnimate = function(B, pivot, now)
    B.lookMod = B.lookMod or require(Shared:WaitForChild("BossLook"))
    B.lookMod.Animate(B, pivot, now, Pose)
end
-- Frost Sovereign: blades sway (raised while attacking), the gown and cape drift, the halo turns
SUPER.Ice.Animate = function(B, pivot, now)
    local l = Lift(B)
    for _, sx in ipairs({ -1, 1 }) do
        Pose(B, "Deco_Arm" .. (sx < 0 and "L" or "R"), pivot, CFrame.new(sx * 3.6, 5.8, 0), CFrame.Angles(math.sin(now * 1.2 + sx) * 0.1 - l * 0.7, 0, sx * (0.05 + l * 0.25)))
    end
    Pose(B, "Deco_Gown", pivot, CFrame.new(0, -3, 0), CFrame.Angles(math.sin(now * 1.1) * 0.06, now * 0.25, math.sin(now * 0.9) * 0.05))
    Pose(B, "Deco_Cape", pivot, CFrame.new(0, 6, 2.4), CFrame.Angles(math.sin(now * 1.4) * 0.08, 0, 0))
    Pose(B, "Deco_Halo", pivot, CFrame.new(0, 9.4, 1.8), CFrame.Angles(0, 0, now * (0.4 + B.phase * 0.2)))
end
-- The Unblinking: tendrils sway, shards orbit, the rune ring turns; it blinks now and then and shuts while BLINDED
SUPER.Void.Animate = function(B, pivot, now)
    for i = 1, 6 do
        local a = i / 6 * math.pi * 2
        Pose(B, "Deco_Tendril" .. i, pivot, CFrame.new(math.cos(a) * 4, -2.4, math.sin(a) * 3 + 1.5), CFrame.Angles(math.sin(now * 1.3 + i) * 0.25, 0, math.cos(now * 1.1 + i * 2) * 0.25))
    end
    Pose(B, "Deco_Shard", pivot, CFrame.new(0, 3, 0), CFrame.Angles(0, now * (0.5 + B.phase * 0.2), 0))
    Pose(B, "Deco_Halo", pivot, CFrame.new(0, 3, 5), CFrame.Angles(0, 0, -now * 0.35))
    if not B.blinkAt then B.blinkAt = now + 3 elseif now > B.blinkAt + 0.25 then B.blinkAt = now + 3 + math.random() * 3 end
    local blink = (now >= B.blinkAt and now < B.blinkAt + 0.22) and 1 or 0
    B.shut = (B.shut or 0) + ((B.blinded and 1 or blink) - (B.shut or 0)) * 0.35
    Pose(B, "Deco_LidT", pivot, CFrame.new(0, 3, 0), CFrame.Angles(-B.shut * 0.62, 0, 0))
    Pose(B, "Deco_LidB", pivot, CFrame.new(0, 3, 0), CFrame.Angles(B.shut * 0.62, 0, 0))
end
-- Omniscience Core: the server panels orbit; on SYSTEM CRASH they fly apart and the rings spin wild
SUPER.Cyber.Animate = function(B, pivot, now)
    local ang = now * (0.25 + B.phase * 0.1)
    B.open = (B.open or 0) + ((B.crashed and 1 or 0) - (B.open or 0)) * 0.12
    for i = 1, 4 do
        local a = math.rad(45 + (i - 1) * 90)
        local radial = Vector3.new(math.cos(a), 0, math.sin(a)) * (B.open * 8)
        Pose(B, "Deco_Panel" .. i, pivot, CFrame.new(0, 3, 0), CFrame.Angles(0, ang, 0) * CFrame.new(radial + Vector3.new(0, B.open * ((i % 2 == 0) and 1.5 or -1.5), 0)))
    end
    local wild = 1 + B.open * 4
    Pose(B, "Deco_RingA", pivot, CFrame.new(0, 1, 0), CFrame.Angles(0, now * 0.6 * wild, 0))
    Pose(B, "Deco_RingB", pivot, CFrame.new(0, 4.5, 0), CFrame.Angles(0, -now * 0.45 * wild, 0))
end
-- Tempest Sovereign: wings beat slowly, the tail flickers, lightning crackles between its crown, wingtips and heart
SUPER.Storm.Animate = function(B, pivot, now)
    local l = Lift(B)
    for _, sx in ipairs({ -1, 1 }) do
        Pose(B, "Deco_Wing" .. (sx < 0 and "L" or "R"), pivot, CFrame.new(sx * 2.4, 6, 1.6), CFrame.Angles(0, sx * l * 0.25, sx * (math.sin(now * 1.6) * 0.16 + l * 0.2)))
    end
    for _, e in ipairs(PoseParts(B, "Deco_Tail")) do e.Part.Transparency = (math.random() < 0.15) and 0.6 or 0 end
    if now < (B.arcT or 0) then return end
    B.arcT = now + math.max(0.08, 0.32 - B.phase * 0.07)
    if not B.arcNodes then
        B.arcNodes = {}
        for _, p in ipairs(B.model:GetDescendants()) do
            if p:IsA("BasePart") and (string.find(p.Name, "Tip$") or p.Name == "Deco_HeartGlow") then table.insert(B.arcNodes, p) end
        end
    end
    local n = #B.arcNodes
    if n < 2 then return end
    local a, b = B.arcNodes[math.random(1, n)], B.arcNodes[math.random(1, n)]
    if a == b then return end
    local p0, p1 = a.Position, b.Position
    local pts = { p0 }
    for i = 1, 3 do table.insert(pts, p0:Lerp(p1, i / 4) + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.4) end
    table.insert(pts, p1)
    for i = 1, #pts - 1 do
        local s = Instance.new("Part")
        s.Anchored = true; s.CanCollide = false; s.CanQuery = false; s.CanTouch = false; s.CastShadow = false
        s.Material = Enum.Material.Neon; s.Color = Color3.fromRGB(215, 235, 255); s.Name = "StormArc"
        s.Size = Vector3.new(0.22, 0.22, (pts[i + 1] - pts[i]).Magnitude)
        s.CFrame = CFrame.lookAt((pts[i] + pts[i + 1]) / 2, pts[i + 1])
        s.Parent = B.d.Fx
        game:GetService("Debris"):AddItem(s, 0.09)
    end
end
-- a telegraph windup that lasts exactly `sec` real seconds (EA stretches windups by the difficulty's scale)
local function Exact(B, sec) return sec / math.max(0.05, B.ctx.Windup or 1) end

-- ----- SERAPH ARCHON: AVERT YOUR EYES + SCALES OF JUDGEMENT -----
local ARCHON_LIGHT = Color3.fromRGB(255, 240, 200)
-- is this player looking at the boss right now? (your own camera on the client; the character's facing otherwise)
local function LookingAt(B, p)
    local c = p.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if not r then return false end
    local look
    if RunService:IsClient() and p == Players.LocalPlayer and workspace.CurrentCamera then
        look = workspace.CurrentCamera.CFrame.LookVector
    else
        look = r.CFrame.LookVector
    end
    local to = (B.pos + Vector3.new(0, 4, 0)) - r.Position
    return to.Magnitude > 0.1 and look:Dot(to.Unit) > 0.4
end
-- (playtester 2026-10-02: the light "needs a reduction on how often they do that AoE one shot, and it should be slower
-- and more noticeable"): a 14 s cooldown (shared with Verdict), a 2.6 s+ wind-up, a centre-screen TURN AWAY countdown,
-- and it hits for 1.6x instead of 2.2x)
local function TurnAwayCountdown(seconds)
    if not RunService:IsClient() then return end
    local gui = Instance.new("ScreenGui")
    gui.Name = "ArchonWarning"; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false; gui.DisplayOrder = 7
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1; t.AnchorPoint = Vector2.new(0.5, 0.5); t.Position = UDim2.fromScale(0.5, 0.36); t.Size = UDim2.fromOffset(900, 80)
    t.Font = Enum.Font.GothamBlack; t.TextSize = 54; t.TextColor3 = Color3.fromRGB(255, 236, 170); t.TextStrokeTransparency = 0.1
    t.Parent = gui
    local edge = Instance.new("Frame")
    edge.Size = UDim2.fromScale(1, 1); edge.BackgroundTransparency = 1; edge.BorderSizePixel = 0; edge.Parent = gui
    local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(255, 220, 140); st.Thickness = 0; st.Parent = edge
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    task.spawn(function()
        local t0 = os.clock()
        while gui.Parent and os.clock() - t0 < seconds do
            local left = seconds - (os.clock() - t0)
            t.Text = string.format("TURN AWAY  %d", math.ceil(left))
            local pulse = 0.5 + 0.5 * math.sin(os.clock() * 12)
            st.Thickness = 10 + 26 * (1 - left / seconds) * (0.6 + 0.4 * pulse)
            t.TextTransparency = 0.1 * pulse
            RunService.Heartbeat:Wait()
        end
        gui:Destroy()
    end)
end
local function ArchonJudgement(B)
    local dur = math.max(2.6, 3.0 * B.pace)
    B:Hold(dur + 0.8)
    B:Title(B.kit.Names[B.phase] .. "  [AVERT YOUR EYES]", ARCHON_LIGHT)
    Sound("BossRoar", Body(B.model))
    TurnAwayCountdown(dur)
    local stop = VFX.Charge(B, dur / math.max(0.05, B.ctx.Windup or 1), ARCHON_LIGHT)
    local sun = Part({ Name = "ArchonSun", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Color = ARCHON_LIGHT, Transparency = 0.4, Parent = B.d.Fx })
    local light = Instance.new("PointLight")
    light.Color = ARCHON_LIGHT; light.Range = 30; light.Brightness = 0; light.Shadows = false; light.Parent = sun
    local t0 = os.clock()
    while os.clock() - t0 < dur and B:Alive() do
        local k = (os.clock() - t0) / dur
        sun.Size = Vector3.new(1, 1, 1) * (2 + k * k * 16)
        sun.CFrame = CFrame.new(B.pos + Vector3.new(0, 2, -1))
        sun.Transparency = 0.45 - k * 0.4
        light.Brightness = k * 6
        RunService.Heartbeat:Wait()
    end
    stop()
    if B:Alive() then
        -- THE LIGHT FIRES: only those looking at it are struck
        local struck = false
        for _, p in ipairs(B.d.Targets()) do
            if LookingAt(B, p) then
                B.d.Hit(p, 1.6)
                if RunService:IsClient() and p == Players.LocalPlayer then struck = true end
            end
        end
        VFX.ScreenFlash(Color3.new(1, 0.98, 0.9), struck and 0.85 or 0.18)
        VFX.Shake(B.pos, struck and 2 or 0.6)
    end
    sun.Size = Vector3.new(30, 30, 30)
    sun.Transparency = 0.2
    task.delay(0.12, function() sun:Destroy() end)
    B:Title(B.kit.Names[B.phase])
end
local function ArchonScales(B)
    local r = B:Root()
    if not r then return end
    local toP = Unit(r.Position - B.pos)
    local right = Vector3.new(-toP.Z, 0, toP.X) -- the boss's right (it always faces you)
    local safe = (math.random() < 0.5) and 1 or -1
    local windup = math.max(2.0, 2.4 * B.pace) -- (slower: half the arena is a lot to cross)
    B.raised = safe -- Animate lifts that wing
    B:Hold(windup + 0.5)
    B:Title(B.kit.Names[B.phase] .. "  [SCALES OF JUDGEMENT]", ARCHON_LIGHT)
    local stop = B:Charge(windup)
    -- the half on the lowered wing's side burns
    local c = B.pos - right * safe * 64
    EA.Line(B.ctx, c - toP * 140, c + toP * 140, 124, Exact(B, windup), { Mult = 1.5, Height = 10,
        OnStrike = function() VFX.Shake(B.pos, 1.6) end })
    B:Wait(windup)
    stop()
    B:Boom(B.pos - right * safe * 30, 18, "BossSlam")
    B:Wait(0.3)
    B.raised = nil
    B:Title(B.kit.Names[B.phase])
end
local function ArchonVerdict(B) -- phase 3: the scales, then the light right after -- read both
    ArchonScales(B)
    if B:Alive() then ArchonJudgement(B) end
end
local function ArchonLances(B)
    local origins = {}
    for i = 1, 2 + B.phase do
        local a = (i / (2 + B.phase)) * math.pi * 2
        local sp = B.pos + Vector3.new(math.cos(a) * 9, 7, math.sin(a) * 9)
        VFX.Ghost(B.d.Fx, sp, B.kit.Color, 2)
        table.insert(origins, function() return sp end)
    end
    M.Snipe(B, #origins, 0.85, origins, 0.14)
end
KITS.Archon = {
    Color = Color3.fromRGB(255, 214, 120), Move = "Orbit", Range = 40, SpeedMul = 0.8,
    Telegraph = { Warn = Color3.fromRGB(255, 196, 30), Core = Color3.fromRGB(255, 255, 240) }, -- (holy gold on the Cryo snow)
    Animate = function(B, pivot, now)
        -- wings: a slow beat; SCALES raises one side high
        B.wingL = B.wingL or 0
        B.wingR = B.wingR or 0
        local flap = math.sin(now * 1.6) * 0.12
        local wantL = (B.raised == -1) and 0.9 or ((B.raised == 1) and -0.35 or 0)
        local wantR = (B.raised == 1) and 0.9 or ((B.raised == -1) and -0.35 or 0)
        B.wingL += (wantL - B.wingL) * 0.12
        B.wingR += (wantR - B.wingR) * 0.12
        -- (model space: the boss faces -Z, so +X is its right; raising = tips swing up about the shoulder)
        Pose(B, "WingL", pivot, CFrame.new(-1.6, 2.6, 1.6), CFrame.Angles(0, 0, -(B.wingL + flap)))
        Pose(B, "WingR", pivot, CFrame.new(1.6, 2.6, 1.6), CFrame.Angles(0, 0, B.wingR + flap))
    end,
    Names = { "SERAPH ARCHON", "SERAPH ARCHON: WRATHFUL", "SERAPH ARCHON: FINAL VERDICT" },
    Moves = {
        { { ArchonScales, "SCALES OF JUDGEMENT" }, { function(B) M.InOut(B, 14, 46, false, 1.0) end, "HALO" }, { ArchonJudgement, "AVERT YOUR EYES" },
          { function(B) M.Rain(B, 5, 6, 0.85, 0, 0.45) end, "FEATHERFALL" } },
        { { ArchonScales, "SCALES OF JUDGEMENT" }, { ArchonLances, "LANCES" }, { ArchonJudgement, "AVERT YOUR EYES" }, { function(B) M.Ripple(B, 3, 28) end, "HALLOWED RINGS" } },
        { { ArchonVerdict, "FINAL VERDICT" }, { ArchonLances, "LANCES" }, { function(B) M.Cage(B, 8, 12, 1.0) end, "CONSECRATION" }, { function(B) M.ArenaWipe(B, 2, 8, 1.5) end, "RAPTURE" } },
    },
}

-- ----- CHRONARCH: OFF-BEAT (armored on the beat, core open every 4th) + countdown bombs + clock hands -----
local CHRONO = Color3.fromRGB(90, 230, 255)
local BPM = { 72, 88, 104 }
local function BeatLen(B) return 60 / BPM[B.phase] end
-- seconds until the next beat that is `n` beats away
local function UntilBeat(B, n) return math.max(0.05, (B.nextBeat or os.clock()) - os.clock()) + (n - 1) * BeatLen(B) end
-- (playtester 2026-10-02: "some of the attacks are way too fast") the first beat at least minSec away -- landing on
-- "the next beat" could leave a 0.05 s warning when a beat was just about to tick. Returns (seconds, beats away).
local CHRONO_MIN = 0.85
local function BeatAtLeast(B, minSec)
    local n = 1
    while UntilBeat(B, n) < (minSec or CHRONO_MIN) and n < 8 do n += 1 end
    return UntilBeat(B, n), n
end
local function ChronoBombs(B)
    local r = B:Root()
    if not r then return end
    -- three waves, each timed to land exactly on a beat (2, 3, 4 beats away)
    local waves = { { r.Position }, { B:Lead(1.0) }, {} }
    local c = r.Position
    for i = 0, 3 do
        local a = i * math.pi / 2 + math.random() * 0.5
        table.insert(waves[3], c + Vector3.new(math.cos(a) * 11, 0, math.sin(a) * 11))
    end
    B:Hold(0.3)
    local _, first = BeatAtLeast(B, 1.0)
    for w, list in ipairs(waves) do
        local sec = UntilBeat(B, first + w - 1)
        for _, p in ipairs(list) do
            EA.Circle(B.ctx, p, 8, Exact(B, sec), { Mult = 1.4, OnStrike = function(cc) VFX.Burst(B.d.Fx, cc + Vector3.new(0, 1, 0), CHRONO, 7) end })
        end
    end
    B:Wait(UntilBeat(B, first + 2))
end
local function ChronoHands(B)
    -- the hour + minute hands sweep the floor from the boss, opposite ways, over 4 / 2 beats
    local len = BeatLen(B)
    local r = B:Root()
    local a0 = r and math.atan2(r.Position.X - B.pos.X, r.Position.Z - B.pos.Z) or 0
    B:Hold(0.6)
    EA.Sweep(B.ctx, function() return B.pos end, a0 + math.pi * 0.5, math.pi * 1.6, len * 4, 95, { Mult = 1.4, Warn = (BeatAtLeast(B, 1.0)), Width = 3.4 })
    if B.phase >= 2 then
        EA.Sweep(B.ctx, function() return B.pos end, a0 - math.pi * 0.5, -math.pi * 1.6, len * 2.5, 95, { Mult = 1.4, Warn = (BeatAtLeast(B, 1.4)), Width = 2.6 })
    end
    B:Wait(len * 4.5)
end
local function ChronoPendulum(B)
    -- a wide blade swings across you on every beat, left-right-left...
    local r = B:Root()
    if not r then return end
    local swings = 3 + B.phase
    local sgn = 1
    for _ = 1, swings do
        if not B:Alive() then return end
        r = B:Root()
        if not r then return end
        local dir = Unit(r.Position - B.pos)
        local side = Vector3.new(-dir.Z, 0, dir.X)
        -- (the blade lands ON you, a little to one side -- it used to sit 1-13 studs off to your side, so standing still
        -- was safe and stepping "out" walked into it: "weird hitboxes")
        local c = r.Position + side * sgn * 2
        local wu = BeatAtLeast(B, CHRONO_MIN)
        EA.Line(B.ctx, c - dir * 40, c + dir * 40, 10, Exact(B, wu), { Mult = 1.3, Height = 8 })
        sgn = -sgn
        B:Wait(wu + 0.02)
    end
end
local function ChronoRings(B)
    for _ = 1, 2 + B.phase do
        if not B:Alive() then return end
        local wu = BeatAtLeast(B, CHRONO_MIN)
        EA.Ring(B.ctx, B.pos, 85, Exact(B, wu), { Mult = 1.1, Speed = 30 + B.phase * 4 })
        B:Wait(wu + BeatLen(B))
    end
end
KITS.Chronarch = {
    Color = CHRONO, Move = "Chase", Range = 32, SpeedMul = 0.55,
    Telegraph = { Warn = Color3.fromRGB(255, 186, 30), Core = Color3.fromRGB(255, 250, 220) }, -- (clockwork gold: Cyber's grid is cyan)
    Pressure = function(B)
        -- THE METRONOME: armored on the beat; every 4th beat the core opens (x3 damage) -- that's your window
        local n = 0
        local core = B.model:FindFirstChild("Core")
        local coreColor = core and core.Color
        while B:Alive() do
            n += 1
            local len = BeatLen(B)
            B.nextBeat = os.clock() + len
            B.beat = n
            local open = (n % 4 == 0)
            if not B.roaring then
                B.d.SetTakenMult(B.model, open and 3 or 0.3)
                B:Title(open and (B.kit.Names[B.phase] .. "  [CORE OPEN: STRIKE!]") or B.kit.Names[B.phase], open and Color3.fromRGB(255, 240, 140) or nil)
            end
            if core and core.Parent then
                core.Color = open and Color3.fromRGB(255, 245, 170) or coreColor
                core.Size = Vector3.new(1, 1, 1) * (open and 3.2 or 1.8)
            end
            -- a tick pulse on the floor so you can feel the tempo
            VFX.Burst(B.d.Fx, B.pos - Vector3.new(0, 6, 0), open and Color3.fromRGB(255, 240, 140) or CHRONO, open and 9 or 4)
            Sound(open and "Crit" or "Click", Body(B.model))
            if not B:Wait(len) then break end
        end
    end,
    Animate = function(B, pivot, now)
        -- hands: the minute hand jumps a notch every beat, the hour hand creeps; pendulum swings with the beat
        local beat = B.beat or 0
        local frac = 1 - math.clamp(((B.nextBeat or now) - now) / BeatLen(B), 0, 1)
        local fz = -1.75
        Pose(B, "HandB", pivot, CFrame.new(0, 0, fz), CFrame.Angles(0, 0, -(beat * math.pi / 6)))
        Pose(B, "HandA", pivot, CFrame.new(0, 0, fz), CFrame.Angles(0, 0, -(now * 0.25)))
        local swing = math.sin((beat + frac) * math.pi) * 0.45
        Pose(B, "Pendulum", pivot, CFrame.new(0, -4.5, -0.6), CFrame.Angles(0, 0, swing))
        Pose(B, "GearL", pivot, CFrame.new(-5, -2.6, 0), CFrame.Angles(now * 0.8, 0, 0))
        Pose(B, "GearR", pivot, CFrame.new(5, -2.6, 0), CFrame.Angles(-now * 0.8, 0, 0))
    end,
    Names = { "CHRONARCH", "CHRONARCH: ACCELERANDO", "CHRONARCH: PRESTISSIMO" },
    Moves = {
        { { ChronoBombs, "COUNTDOWN" }, { ChronoHands, "CLOCK HANDS" }, { ChronoPendulum, "PENDULUM" }, { ChronoRings, "TOLL" } },
        { { ChronoBombs, "COUNTDOWN" }, { ChronoHands, "CLOCK HANDS" }, { function(B) M.Footsteps(B, 8, 6) end, "TIMELINES" }, { function(B) M.Checker(B, 34, 1.0) end, "STOPPED TIME" } },
        { { ChronoBombs, "COUNTDOWN" }, { ChronoPendulum, "PENDULUM" }, { function(B) M.Orbit(B, 4, 5, 5) end, "CLOCKWORK" }, { function(B) M.ArenaWipe(B, 2, 8, 1.5) end, "MIDNIGHT" } },
    },
}

-- ----- ECHO WARDEN: every attack happens again a few seconds later, in the same place -----
local ECHO = Color3.fromRGB(170, 90, 255)
local function EchoCtx(B)
    if not B.echoCtx then
        B.echoCtx = table.clone(B.ctx)
        B.echoCtx.Color = ECHO
        -- (playtester 2026-10-02: "echowarden is actually just broken" -- every echo re-drew the light COLUMNS of five
        -- lanes / seven spokes on top of the originals, which stacked into a solid white wall over the arena)
        B.echoCtx.Columns = false
    end
    return B.echoCtx
end
-- run fn(ctx) now, then replay it (purple) after the echo delay -- twice in phase 3
local function Echo(B, fn)
    fn(B.ctx)
    local delays = (B.phase >= 3) and { 3.0, 5.8 } or { 3.2 }
    for _, dl in ipairs(delays) do
        task.delay(dl * math.max(0.8, B.pace), function()
            if B:Alive() then
                local ok, err = pcall(fn, EchoCtx(B))
                if not ok then warn("[BossAI] echo: " .. tostring(err)) end
            end
        end)
    end
end
local function EchoRain(B)
    local r = B:Root()
    if not r then return end
    -- (v3) a fixed pattern: one on you + a ring around you -- step out through a gap, then remember where they were
    local spots = { r.Position }
    local n = 3 + B.phase
    local a0 = math.random() * math.pi * 2
    for i = 1, n do
        local a = a0 + i / n * math.pi * 2
        table.insert(spots, r.Position + Vector3.new(math.cos(a) * 14, 0, math.sin(a) * 14))
    end
    Echo(B, function(ctx) for _, p in ipairs(spots) do EA.Circle(ctx, p, 7, 0.9, { Mult = 1.2 }) end end)
    B:Wait(B:W(1.0))
end
local function EchoLanes(B)
    local r = B:Root()
    if not r then return end
    local center = B:Lead(0.35)
    local dir = Unit(center - B.pos)
    local side = Vector3.new(-dir.Z, 0, dir.X)
    local lines = {}
    for i = -2, 2 do
        local c = center + side * (i * 12 + math.random(-2, 2))
        table.insert(lines, { c - dir * 80, c + dir * 80 })
    end
    Echo(B, function(ctx) for _, l in ipairs(lines) do EA.Line(ctx, l[1], l[2], 6, 0.75, { Mult = 1.3, Height = 10 }) end end)
    B:Wait(B:W(0.8))
end
local function EchoSpokes(B)
    if not M.RadialOK(B) then return M.Predict(B, 3) end
    local o = B.pos
    local n = 5 + B.phase
    local base = math.random() * math.pi * 2
    Echo(B, function(ctx)
        for i = 0, n - 1 do
            local a = base + i / n * math.pi * 2
            EA.Line(ctx, o, o + Vector3.new(math.sin(a), 0, math.cos(a)) * 90, 6, 0.8, { Mult = 1.3, Height = 10 })
        end
    end)
    B:Wait(B:W(0.9))
end
-- (v3) LEAP -- replaces the blink (popped up right next to you): it marks where you stand, LEAPS there (a visible dash)
-- as the slam goes off, and the slam echoes; then it walks back out
local function EchoLeap(B)
    local r = B:Root()
    if not r then return end
    local at = Vector3.new(r.Position.X, r.Position.Y, r.Position.Z)
    B:Hold(B:W(1.1) + 0.5)
    Echo(B, function(ctx) EA.Circle(ctx, at, 13, 1.1, { Mult = 1.6, Sound = "BossSlam" }) end)
    B:Wait(B:W(1.1) * 0.45)
    B:Dash(at - Unit(at - B.pos) * 4, B:W(1.1) * 0.55)
    VFX.Burst(B.d.Fx, B.pos, ECHO, 8)
    B:Wait(0.4)
end
local function EchoMarks(B)
    local r = B:Root()
    if not r then return end
    EA.Mark(B.ctx, r, 7, 1.5, { Mult = 1.4, OnStrike = function(c)
        B:Boom(c, 7)
        task.delay(2.9 * math.max(0.8, B.pace), function() if B:Alive() then EA.Circle(EchoCtx(B), c, 7, 0.9, { Mult = 1.2 }) end end)
    end })
    B:Wait(B:W(1.5) + 0.4)
end
-- (0.49) ECHO PRISON: a cage of circles round you with one gap, the middle caves in -- and it all happens again
local function EchoCage(B)
    local r = B:Root()
    if not r then return end
    local c, n, rad = r.Position, 8, 12
    local gap = math.random(1, n)
    Echo(B, function(ctx)
        for i = 1, n do
            if i ~= gap then
                local a = i / n * math.pi * 2
                EA.Circle(ctx, c + Vector3.new(math.cos(a), 0, math.sin(a)) * rad, rad * 0.55, 0.95, { Mult = 1.2 })
            end
        end
        EA.Circle(ctx, c, rad * 0.7, 1.45, { Mult = 1.4 })
    end)
    B:Wait(B:W(1.45))
end
-- (0.49) CROSSED ECHOES: an X of lines on you -- and again where it was
local function EchoCross(B)
    local r = B:Root()
    if not r then return end
    local c, a0 = r.Position, math.random() * math.pi
    Echo(B, function(ctx)
        for k = 0, 1 do
            local a = a0 + k * math.pi / 2
            local d = Vector3.new(math.cos(a), 0, math.sin(a))
            EA.Line(ctx, c - d * 80, c + d * 80, 6, 0.9, { Mult = 1.3 })
        end
    end)
    B:Wait(B:W(0.9))
end
KITS.EchoWarden = {
    Color = Color3.fromRGB(190, 110, 255), Move = "Orbit", Range = 30, SpeedMul = 0.9,
    Animate = function(B, pivot, now)
        Pose(B, "Shard", pivot, CFrame.new(0, 0, 0), CFrame.Angles(0, now * 0.9, 0))
        Pose(B, "Ghost", pivot, CFrame.new(0, 0, 0), CFrame.new(0, math.sin(now * 2) * 0.6, 0))
    end,
    Names = { "ECHO WARDEN", "ECHO WARDEN: RESONANT", "ECHO WARDEN: INFINITE REFRAIN" },
    Moves = {
        { { EchoRain, "RESONANCE" }, { EchoLanes, "ECHO LANES" }, { EchoSpokes, "REFRAIN" } },
        { { EchoLeap, "LEAP" }, { EchoMarks, "DEATH MARK" }, { EchoCage, "ECHO PRISON" }, { EchoRain, "RESONANCE" } },
        { { EchoCross, "CROSSED ECHOES" }, { EchoLeap, "LEAP" }, { function(B) M.Pylons(B, 3, 6, Color3.fromRGB(190, 110, 255)) end, "ECHO STONES" }, { function(B) M.Refrain(B, 16) end, "INFINITE REFRAIN" } },
    },
}

-- ----- FORGEHEART: BRANDS (a slag shell -- only the three crawling brands take full damage; CombatServer applies it) +
-- MAGMA TIDE (pillars rise, the floor floods: get up high) + HAMMERFALL (it leaps onto you; jump the ring) -----
local FORGE = Color3.fromRGB(255, 130, 40)
local FORGE_LAVA = Color3.fromRGB(255, 90, 20)
local FORGE_SAFE = Color3.fromRGB(150, 220, 255)
local function ForgeHammerfall(B)
    local r = B:Root()
    if not r then return end
    local at = B:Clamp(B:Lead(0.55))
    local wu = 1.15
    B.raise = os.clock() + B:W(wu) -- the hammer goes up until the impact (Animate)
    B:Hold(B:W(wu) + 0.6)
    EA.Circle(B.ctx, at, 11, wu, { Mult = 1.6, Sound = "BossSlam", OnStrike = function(c)
        B:Boom(c, 14, "BossSlam")
        for i = 1, (B.phase >= 2) and 2 or 1 do
            task.delay((i - 1) * 0.45, function()
                if B:Alive() then EA.Ring(B.ctx, c, 70, 0.05, { Mult = 1.2, Speed = 32 + B.phase * 4 }) end
            end)
        end
    end })
    -- the leap: it crouches, then lands as the circle goes off
    B:Wait(B:W(wu) * 0.4)
    B:Dash(at - Unit(at - B.pos) * 3, B:W(wu) * 0.6)
    B:Wait(1.0)
end
local function ForgeBreath(B)
    local r = B:Root()
    if not r then return end
    local dir = Unit(B:Lead(0.4) - B.pos)
    B:Hold(B:W(1.0))
    local stop = B:Charge(0.8)
    task.delay(B:W(0.8), stop)
    EA.Cone(B.ctx, B.pos, dir, 70, 24, 0.95, { Mult = 1.4 })
    if B.phase >= 2 then
        -- a second gout swung to one side
        local d2 = CFrame.Angles(0, ((math.random() < 0.5) and 1 or -1) * math.rad(42), 0):VectorToWorldSpace(dir)
        task.delay(B:W(0.55), function() if B:Alive() then EA.Cone(B.ctx, B.pos, d2, 70, 24, 0.75, { Mult = 1.4 }) end end)
    end
    B:Wait(B:W(1.3))
end
-- MAGMA TIDE: basalt pillars rise (one within reach of every player, never on top of anyone), the floor glows, then
-- floods with lava for a few seconds -- anyone low (root < 5.4 above the floor) burns every 0.3 s. Phase 3: the pillar
-- nearest a player cracks and sinks mid-flood -- move to another.
local function ForgeTide(B)
    if not B:Root() then return end
    local b = B.d.Bounds
    local count = ({ 5, 4, 4 })[B.phase] or 4
    local SIZE, H = 9, 5
    local players = {}
    for _, pl in ipairs(B.d.Targets()) do
        local rr = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
        if rr then table.insert(players, rr.Position) end
    end
    local spots = {}
    local function Clear(q)
        for _, pp in ipairs(players) do if Flat(q - pp).Magnitude < 8 then return false end end
        for _, sp in ipairs(spots) do if Flat(q - sp).Magnitude < 22 then return false end end
        return true
    end
    for _, pp in ipairs(players) do
        for _ = 1, 24 do
            local q = B:Spot(pp, 12, 24)
            if Clear(q) then table.insert(spots, q) break end
        end
    end
    local tries = 0
    while #spots < count and tries < 100 do
        tries += 1
        local q = Vector3.new(b.MinX + 7 + math.random() * (b.MaxX - b.MinX - 14), 0, b.MinZ + 7 + math.random() * (b.MaxZ - b.MinZ - 14))
        if Clear(q) then table.insert(spots, q) end
    end
    local floorY = math.huge
    for _, sp in ipairs(spots) do floorY = math.min(floorY, EA.GroundY(B.ctx, sp)) end
    if floorY == math.huge then floorY = 2 end

    B:Title(B.kit.Names[B.phase] .. "  [MAGMA TIDE: GET HIGH]", FORGE)
    VFX.Banner("MAGMA TIDE", "GET UP ON A PILLAR", FORGE)
    Sound("BossRoar", Body(B.model))
    local pillars = {}
    for _, sp in ipairs(spots) do
        local pil = Instance.new("Part")
        pil.Name = "ForgePillar"; pil.Anchored = true; pil.CanCollide = true; pil.CanQuery = true; pil.CanTouch = false
        pil.Material = Enum.Material.Basalt; pil.Color = Color3.fromRGB(58, 50, 48); pil.Size = Vector3.new(SIZE, H, SIZE)
        pil.TopSurface = Enum.SurfaceType.Smooth; pil.BottomSurface = Enum.SurfaceType.Smooth
        pil.CFrame = CFrame.new(sp.X, floorY - H / 2 - 0.2, sp.Z)
        pil:SetAttribute("Live", true) -- (PARTY TWIN: geo is a Scenery folder; members' clients keep it shown)
        pil.Parent = (B.d.Geo and B.d.Geo.Parent) and B.d.Geo or B.d.Fx
        local rim = Instance.new("Part")
        rim.Name = "ForgePillarRim"; rim.Anchored = true; rim.CanCollide = false; rim.CanQuery = false; rim.CanTouch = false; rim.CastShadow = false
        rim.Material = Enum.Material.Neon; rim.Color = FORGE_SAFE; rim.Transparency = 0.35; rim.Size = Vector3.new(SIZE + 0.3, 0.3, SIZE + 0.3)
        rim.CFrame = pil.CFrame
        rim.Parent = B.d.Fx
        table.insert(pillars, { P = pil, Rim = rim, At = sp, K = 0 })
    end
    local function Place(e)
        local cy = floorY - H / 2 - 0.2 + (H + 0.2) * e.K
        e.P.CFrame = CFrame.new(e.At.X, cy, e.At.Z)
        e.Rim.CFrame = CFrame.new(e.At.X, cy + H / 2 + 0.02, e.At.Z)
    end
    local cx, cz = (b.MinX + b.MaxX) / 2, (b.MinZ + b.MaxZ) / 2
    local lava = Instance.new("Part")
    lava.Name = "ForgeLava"; lava.Anchored = true; lava.CanCollide = false; lava.CanQuery = false; lava.CanTouch = false; lava.CastShadow = false
    lava.Material = Enum.Material.Neon; lava.Color = FORGE_LAVA; lava.Transparency = 0.88
    lava.Size = Vector3.new(b.MaxX - b.MinX + 16, 0.2, b.MaxZ - b.MinZ + 16)
    lava.CFrame = CFrame.new(cx, floorY + 0.1, cz)
    lava.Parent = B.d.Fx
    local function Cleanup()
        lava:Destroy()
        for _, e in ipairs(pillars) do e.P:Destroy(); e.Rim:Destroy() end
    end

    -- warning: the pillars rise, the floor glows hotter and hotter
    local wu = (({ 3.2, 2.9, 2.6 })[B.phase] or 2.6) * B.ctx.Windup
    local t0 = os.clock()
    while os.clock() - t0 < wu do
        if not B:Alive() then Cleanup() return end
        local k = (os.clock() - t0) / wu
        for _, e in ipairs(pillars) do e.K = math.min(1, k / 0.35); Place(e) end
        lava.Transparency = 0.88 - 0.4 * k + 0.08 * math.sin(k * math.pi * 12)
        RunService.Heartbeat:Wait()
    end
    for _, e in ipairs(pillars) do e.K = 1; Place(e) end

    -- THE FLOOD
    local dur = ({ 4.5, 5.0, 5.5 })[B.phase] or 5
    lava.Size = Vector3.new(lava.Size.X, 1.6, lava.Size.Z)
    lava.CFrame = CFrame.new(cx, floorY + 0.8, cz)
    lava.Transparency = 0.12
    local bubbles = Instance.new("ParticleEmitter")
    bubbles.Texture = FIRE; bubbles.Rate = 60; bubbles.Lifetime = NumberRange.new(0.4, 0.8); bubbles.Speed = NumberRange.new(2, 5)
    bubbles.Size = NumberSequence.new(1.6, 0); bubbles.LightEmission = 0.6; bubbles.EmissionDirection = Enum.NormalId.Top
    bubbles.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), FORGE_LAVA); bubbles.Parent = lava
    VFX.Shake(B.pos, 1.4)
    Sound("Explosion", lava)
    local crumble = (B.phase >= 3 and #pillars >= 3) and { At = 1.8, Done = false } or nil
    local start, lastTick = os.clock(), -1
    while os.clock() - start < dur do
        if not B:Alive() then Cleanup() return end
        local el = os.clock() - start
        lava.Transparency = 0.12 + 0.06 * math.sin(el * 7)
        if el - lastTick >= 0.3 then
            lastTick = el
            for _, pl in ipairs(B.d.Targets()) do
                local c = pl.Character
                local rr = c and c:FindFirstChild("HumanoidRootPart")
                local h = c and c:FindFirstChildOfClass("Humanoid")
                if rr and h and h.Health > 0 then
                    local rp = rr.Position
                    if rp.X > b.MinX - 8 and rp.X < b.MaxX + 8 and rp.Z > b.MinZ - 8 and rp.Z < b.MaxZ + 8 and rp.Y - floorY <= 5.4 then
                        B.ctx.Hit(pl, 0.3)
                    end
                end
            end
        end
        -- phase 3: the pillar someone is standing on (or nearest) cracks red, then sinks
        if crumble and not crumble.Done and el >= crumble.At then
            crumble.Done = true
            local best, bd = nil, math.huge
            for _, pl in ipairs(B.d.Targets()) do
                local rr = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
                if rr then
                    for _, e in ipairs(pillars) do
                        local dd = Flat(rr.Position - e.At).Magnitude
                        if dd < bd then best, bd = e, dd end
                    end
                end
            end
            if best then
                task.spawn(function()
                    best.Rim.Color = Color3.fromRGB(255, 50, 40)
                    local c0 = os.clock()
                    while os.clock() - c0 < 1.2 * B.ctx.Windup and best.Rim.Parent do
                        best.Rim.Transparency = 0.1 + 0.5 * math.abs(math.sin((os.clock() - c0) * 14))
                        RunService.Heartbeat:Wait()
                    end
                    local s0 = os.clock()
                    while os.clock() - s0 < 0.6 and best.P.Parent do
                        best.K = 1 - (os.clock() - s0) / 0.6
                        Place(best)
                        RunService.Heartbeat:Wait()
                    end
                    best.K = 0
                    if best.P.Parent then Place(best) end
                end)
            end
        end
        RunService.Heartbeat:Wait()
    end

    -- drain: the lava fades, the pillars sink
    bubbles.Enabled = false
    local d0 = os.clock()
    while os.clock() - d0 < 0.8 do
        local k = (os.clock() - d0) / 0.8
        lava.Transparency = 0.12 + 0.88 * k
        for _, e in ipairs(pillars) do e.K = math.min(e.K, 1 - k); Place(e) end
        RunService.Heartbeat:Wait()
    end
    Cleanup()
    if B:Alive() and not B.roaring then B:Title(B.kit.Names[B.phase]) end
end
KITS.Forgeheart = {
    Color = FORGE, Move = "Chase", Range = 24, SpeedMul = 0.6,
    Animate = function(B, pivot, now)
        -- the brands crawl round the shell (a box around the 9 x 6 torso), bobbing; faster each phase
        if not B.brands then
            B.brands, B.brandRims = {}, {}
            for _, p in ipairs(B.model:GetChildren()) do
                local i = p:GetAttribute("BrandIndex")
                if i then
                    if p.Name == "Brand" then B.brands[i] = p else B.brandRims[i] = p end
                end
            end
        end
        local dt = math.min(0.1, now - (B.brandT or now))
        B.brandT = now
        B.brandA = (B.brandA or 0) + (({ 0.45, 0.6, 0.8 })[B.phase] or 0.6) * dt
        for i = 1, 3 do
            local a = B.brandA + (i - 1) * math.pi * 2 / 3
            local x, z = math.sin(a), -math.cos(a)
            local k = 1 / math.max(math.abs(x) / 4.75, math.abs(z) / 3.25, 0.001)
            local off = Vector3.new(x * k, 0.2 + math.sin(now * 0.8 + i * 2.1) * 2.2, z * k)
            local n = (math.abs(x) / 4.75 > math.abs(z) / 3.25) and Vector3.new(math.sign(x), 0, 0) or Vector3.new(0, 0, math.sign(z))
            local sk = B.poseScale or B.model:GetScale() -- (0.62: the shell box is in full-size studs; the boss is shrunk)
            local cf = pivot * CFrame.lookAt((off + n * 0.55) * sk, (off + n * 2) * sk) -- (proud of the recessed furnace core)
            if B.brands[i] then B.brands[i].CFrame = cf end
            if B.brandRims[i] then B.brandRims[i].CFrame = cf * CFrame.new(0, 0, 0.12) end
        end
        -- the hammer: raised over the shoulder for HAMMERFALL, slammed down on impact
        local up = (now < (B.raise or 0)) and 1 or 0
        B.hamK = (B.hamK or 0) + (up - (B.hamK or 0)) * ((up == 1) and 0.1 or 0.5)
        Pose(B, "Deco_Hammer", pivot, CFrame.new(6.3, 1.4, 0), CFrame.Angles(math.rad(130) * B.hamK, 0, 0))
        -- the chimneys flame up from phase 2
        if B.flamePhase ~= B.phase then
            B.flamePhase = B.phase
            for _, e in ipairs(B.model:GetDescendants()) do
                if e:IsA("ParticleEmitter") and e.Name == "ForgeFlame" then e.Rate = (B.phase >= 3 and 24) or (B.phase >= 2 and 12) or 0 end
            end
        end
    end,
    Names = { "FORGEHEART", "FORGEHEART: WHITE HEAT", "FORGEHEART: MELTDOWN" },
    Moves = {
        { { ForgeHammerfall, "HAMMERFALL" }, { ForgeBreath, "FORGE BREATH" }, { function(B) M.Rain(B, 5, 6, 0.9, 0, 0.45) end, "SLAG SPIT" } },
        { { ForgeTide, "MAGMA TIDE" }, { ForgeHammerfall, "HAMMERFALL" }, { function(B) M.Stomp(B, 13, 2, 0.5) end, "QUAKE" }, { function(B) M.Ripple(B, 3, 28) end, "SLAG RINGS" } },
        { { ForgeTide, "MAGMA TIDE" }, { ForgeBreath, "FORGE BREATH" }, { function(B) M.Checker(B, 34, 0.95) end, "SLAG GRID" }, { function(B) M.ArenaWipe(B, 2, 8, 1.5) end, "MELTDOWN" } },
    },
}

BossAI.Kits = KITS
BossAI.SuperKits = SUPER

-- ==================== phases ====================
local PHASE_AT = { 0.66, 0.33 }
-- chaos scales with difficulty: >1 = more time between moves / pressure ticks (Easy is the first boss most players meet)
local PACE = { Easy = 1.6, Normal = 1.3, Hard = 1.1, Brutal = 1.0, Nightmare = 0.9, Torment = 0.85, Cataclysm = 0.8, Oblivion = 0.75,
    Ruin = 0.72, Dread = 0.7, Apocalypse = 0.68, Annihilation = 0.66, Eternity = 0.64, Singularity = 0.62, Endless = 0.85 }
BossAI.DIFF_PACE = PACE -- (FUTURE-PROOF: read by ContentCheck)
-- BOT SKILL -> BOSS SPEED (owner 2026-10-05: "Boss speed (attacks and movement should scale with bot difficulty for
-- dungeons)"): the Bot Skill slider (1-10, default 4 = 1.0) speeds up a dungeon boss's movement and its move rhythm
-- (recovery / tells: pace / f) and, more gently, its wind-ups (/ sqrt f). Boss Trials / the Trial of Ascension keep their own
-- tier pacing (TrialPace). Roughly the bots' own Speed curve (DungeonGenerator.BotSkillLevels), flattened for bosses.
local SKILL_SPEED = { 0.8, 0.85, 0.92, 1.0, 1.1, 1.2, 1.32, 1.4, 1.48, 1.6 }
local function SkillFactor(config: any): number
    if config.BossTrial or config.AscTrial then return 1 end
    local lvl = math.clamp(math.floor(config.BossSkill or config.BotSkill or 4), 1, 10) -- (BOT MOVEMENT POE: a map's BossSkill = its old roll)
    return SKILL_SPEED[lvl] or 1
end

-- ==================== SIGNATURES (owner 2026-10-05: "Please make ALL the boss fights unique, no two bosses should feel the
-- same ... take from games such as destiny and dark souls. The bosses should also be harder to hit") ====================
-- Every regular boss has ONE signature mechanic running beside its rotation (SIG[key], started when it first sees you),
-- and its own way of moving (EVADE: a strafe + quick side-dodges) so it's never a standing target.
--   Goliath  BACKSTAB: an armoured front (CombatServer: 30% damage anywhere but its glowing BACKPLATE). After every
--            charge it skids to a stop facing away. Enough backplate hits break its POSTURE: it kneels, taking 2x.
--   Phantom  MIRROR DANCE: it splits into mirror images that weave round you and fire; only the real one (the one
--            with the glowing head) can be hurt (decoys: no damage).
--   Sentinel SHIELD WALL: its shield always faces you (10%) -- flank it; after its pulses it VENTS (core out, 1.5x).
--   Titan    BREAK THE CANNONS: two shoulder cannons; its hull takes 50% while one stands; each cannon down = less
--            artillery; both down = OVERLOAD (kneels, 2x), then it rebuilds them.
--   Fire     HEAT: Ignis LEAPS round the arena (an airborne target) and keeps heating up; hits on its blazing CORE
--            cool it. At 100% heat: SUPERNOVA.
--   Ice      SKATE: it skates at you along a marked lane and slides on; dodge so it slams into a WALL and it's DAZED
--            (1.75x). Its frozen hide takes 60% otherwise.
--   Void     LIGHT WELLS: it takes only 10% unless someone stands in one of the drifting wells of light.
--   Cyber    FIREWALL NODES: the shield-orb fight (ShieldOrbs below) -- the only boss built on it.
--   Storm    LIGHTNING RIDE: it turns into lightning and zig-zags across the arena (every dash a lane), then is
--            GROUNDED (2x) for a few seconds.
-- Parts a signature adds are children of the boss model ("BreakPart<i>" -- CombatServer counts hits into the model's
-- "Orb<i>" attribute and treats them as weak spots; decoys live outside it, so hitting one is a miss), so they move with it and hits route to it.
local SIG = {}
local EVADE = {
    Goliath = { Amp = 5, Rate = 1.2 }, Phantom = { Amp = 14, Rate = 2.6, Dodge = 2.4 }, Sentinel = { Amp = 9, Rate = 1.0 },
    Ravager = { Amp = 7, Rate = 1.4, Dodge = 3.4 }, Hexcaller = { Amp = 11, Rate = 1.6 },
    Titan = { Amp = 9, Rate = 1.1, Dodge = 4.5 },
    SuperFire = { Amp = 8, Rate = 1.4 }, SuperIce = { Amp = 10, Rate = 1.6, Dodge = 3.5 }, SuperVoid = { Amp = 12, Rate = 1.8, Dodge = 3.2 },
    SuperCyber = { Amp = 13, Rate = 2.0, Dodge = 3.5 }, SuperStorm = { Amp = 14, Rate = 2.4, Dodge = 2.8 },
}
-- (0.62, owner: "The bosses need to move in general a lot more. A lot of them kind of just stand there"): every boss
-- without its own entry (trial bosses, new-biome superbosses, custom minibosses) strafes + side-dodges with this one
local EVADE_DEFAULT = { Amp = 10, Rate = 1.4, Dodge = 4 }
local GOLD = Color3.fromRGB(255, 215, 110)
local function SigKey(B) return (B.kind == "SuperBoss") and ("Super" .. tostring(B.config.Biome)) or B.kind end
local function PartySize(B) return math.max(1, #(B.d.Targets and B.d.Targets() or {})) end
-- (0.62 human-sized bosses: size / offset are in full-size studs and scale with the shrunk model; callers that build from
-- the body's size pass FullSize(B, body))
local function FullSize(B, body) return body.Size / B.model:GetScale() end
local function Attach(B, name, size, off, color, shape)
    local body = Body(B.model)
    if not body then return nil end
    local k = B.model:GetScale()
    size, off = size * k, off.Rotation + off.Position * k
    local p = Part({ Name = name, Size = size, Color = color, CanQuery = true, CFrame = body.CFrame * off })
    if shape then p.Shape = shape end
    p.Parent = B.model
    return p
end
local function Hits(B, i) return B.model:GetAttribute("Orb" .. i) or 0 end
-- a timed damage window: rooted, taking `mult`, the bar counting down
local function Window(B, top, sub, mult, secs, color)
    B.rooted, B.staggered = true, true
    B.rawTaken(B.model, mult)
    B:Hold(secs)
    B.nextMove = math.max(B.nextMove, os.clock() + secs + 0.4)
    VFX.Banner(top, sub, color or GOLD)
    VFX.ScreenFlash(color or GOLD, 0.2)
    local tEnd = os.clock() + secs
    while B:Alive() and os.clock() < tEnd do
        B:Title(string.format("%s   >>  %s (%ds)", B.kit.Names[B.phase], top, math.ceil(tEnd - os.clock())), color or GOLD)
        B:Wait(0.1)
    end
    B.staggered, B.rooted = false, false
    B.rawTaken(B.model, B.baseTaken or 1)
    if B:Alive() then B:Title(B.kit.Names[B.phase]) end
end
-- take the move slot for a signature action (the rotation waits) and give it back after
local function TakeTurn(B)
    while B:Alive() and (B.active ~= 0 or B.roaring or B.rooted) do B:Wait(0.1) end
    B.active = 1
    B.nextMove = math.huge
end
local function GiveTurn(B, after)
    B.active = 0
    B.nextMove = os.clock() + (after or 1.2) * B.pace
end
-- MECHANIC MODE (0.49, owner: "you cant really do the mechanics if the boss is spam attacking you always, attacks should be
-- less frequent or completely different ... if you have to complete a mechanic"): while a mechanic asks the team to do
-- something (plates, glyphs, nodes, rods, decoys, shield orbs, trials), the rotation pauses and the boss only throws
-- light, slow MECH_MOVES (one at a time, MECH_RECOVER apart). Nested-safe counter.
local MECH_BREAK = 11 -- seconds of the normal rotation (this phase's attacks) between two mechanic rounds
local function Mech(B, on)
    B.mechN = math.max(0, (B.mechN or 0) + (on and 1 or -1))
end

SIG.Goliath = function(B)
    local body = Body(B.model)
    if not body then return end
    local bs = FullSize(B, body)
    local plate = Attach(B, "BreakPart1", Vector3.new(bs.X * 0.62, bs.Y * 0.6, 0.7), CFrame.new(0, bs.Y * 0.08, bs.Z / 2 + 0.3), Color3.fromRGB(255, 170, 60))
    local _ = plate
    local base = Hits(B, 1)
    while B:Alive() do
        local need = (6 + 2 * B.phase) * (1 + 0.5 * (PartySize(B) - 1)) -- (2026-10-07: was 10 + 2 x phase)
        B.model:SetAttribute("BossInfo", string.format("POSTURE %d%%", math.floor(math.clamp((Hits(B, 1) - base) / need, 0, 1) * 100)))
        if Hits(B, 1) - base >= need then
            base = Hits(B, 1)
            Window(B, "POSTURE BROKEN", "it's down: hit it hard", 2, 5)
            base = Hits(B, 1)
        end
        B:Wait(0.15)
    end
end

SIG.Phantom = function(B)
    while B:Alive() do
        B:Wait(math.max(6, 11 - B.phase * 1.5))
        if not B:Alive() then return end
        local body = Body(B.model)
        local head = B.model:FindFirstChild("Head")
        if not body then return end
        local n = 1 + B.phase
        local decoys = {}
        for i = 1, n do
            local dp = Part({ Name = "Decoy", Shape = Enum.PartType.Ball, Size = body.Size, Color = B.kit.Color, Material = Enum.Material.Neon,
                Transparency = 0.1, CanQuery = true, CFrame = body.CFrame })
            dp.Parent = B.d.Fx -- (not part of the boss: a shot on a decoy is a plain miss)
            table.insert(decoys, { Part = dp, Off = (i / (n + 1)) * math.pi * 2, Next = os.clock() + 1 + i * 0.6 })
        end
        local hc, hm = head and head.Color, head and head.Material
        if head then head.Color = Color3.new(1, 1, 1); head.Material = Enum.Material.Neon end
        B.decoys = decoys
        Mech(B, true)
        VFX.Banner("MIRROR DANCE", "only the real one bleeds: find the glowing head", B.kit.Color)
        local tEnd = os.clock() + 7 + B.phase
        while B:Alive() and os.clock() < tEnd do
            local r = B:Root()
            for _, dd in ipairs(decoys) do
                if r and os.clock() >= dd.Next and dd.Part.Parent then
                    dd.Next = os.clock() + 2.4
                    local from = dd.Part.Position
                    local dir = Unit(r.Position - from)
                    EA.Line(B.ctx, Vector3.new(from.X, B.pos.Y, from.Z), Vector3.new(from.X, B.pos.Y, from.Z) + dir * 70, 4, 0.8, { Mult = 0.8, Height = 10 })
                end
            end
            B:Wait(0.1)
        end
        B.decoys = nil
        Mech(B, false)
        for _, dd in ipairs(decoys) do
            if dd.Part.Parent then VFX.Burst(B.d.Fx, dd.Part.Position, B.kit.Color, 8, nil); dd.Part:Destroy() end
        end
        if head and head.Parent then head.Color = hc; head.Material = hm end
    end
end
SIG.PhantomTick = function(B, now)
    local r = B:Root()
    if not (B.decoys and r) then return end
    for _, dd in ipairs(B.decoys) do
        if dd.Part.Parent then
            local a = dd.Off + now * 0.9
            local wob = math.sin(now * 3 + dd.Off * 2) * 6
            local p = B:Clamp(Vector3.new(r.Position.X + math.cos(a) * (B.kit.Range + wob), B.pos.Y, r.Position.Z + math.sin(a) * (B.kit.Range + wob)))
            dd.Part.CFrame = CFrame.new(p)
        end
    end
end

-- RAVAGER: FRENZY fills over time (faster each phase); at 100% its next pounce is a RAMPAGE of three. Its back SPINES
-- (BreakPart1-2, sticking up behind the shoulders, visible from the front) count hits: enough = STAGGER + frenzy reset.
SIG.Ravager = function(B)
    local body = Body(B.model)
    if not body then return end
    for i, sx in ipairs({ -1, 1 }) do
        local sp = Attach(B, "BreakPart" .. i, Vector3.new(1.0, 2.6, 1.0), CFrame.new(sx * 1.6, FullSize(B, body).Y / 2 + 1.4, -1.2) * CFrame.Angles(math.rad(-15), 0, math.rad(sx * -12)), Color3.fromRGB(255, 120, 70))
        if sp then sp.Material = Enum.Material.Neon end
    end
    local frenzy, base = 0, Hits(B, 1) + Hits(B, 2)
    local last = os.clock()
    while B:Alive() do
        local now = os.clock()
        frenzy = math.min(100, frenzy + (now - last) * (3 + B.phase * 1.2))
        last = now
        local need = (8 + 3 * B.phase) * (1 + 0.5 * (PartySize(B) - 1))
        local got = Hits(B, 1) + Hits(B, 2) - base
        B.model:SetAttribute("BossInfo", string.format("FRENZY %d%%  •  SPINES %d%%", math.floor(frenzy), math.floor(math.clamp(got / need, 0, 1) * 100)))
        if got >= need then
            frenzy, B.rampage = 0, false
            Window(B, "STAGGERED", "its stride is broken: hit it", 1.75, 4)
            base = Hits(B, 1) + Hits(B, 2)
            last = os.clock()
        elseif frenzy >= 100 and not B.rampage then
            B.rampage = true
            frenzy = 0
            VFX.Banner("RAMPAGE", "its next pounce comes three times", B.kit.Color)
        end
        B:Wait(0.15)
    end
end

-- HEXCALLER: three warding CRYSTALS (BreakPart1-3) orbit it; while any stands it takes 30%. Break all three = DISPELLED
-- (2x, 6 s), then it calls new ones. The crystals move -- a tracking test while you dodge its hexes.
SIG.Hexcaller = function(B)
    local body = Body(B.model)
    if not body then return end
    B.sigOwn = true
    B.baseTaken = 0.3
    local function Build()
        local cr = {}
        for i = 1, 3 do
            local p = Attach(B, "BreakPart" .. i, Vector3.new(1.4, 2.4, 1.4), CFrame.new(0, 0, 0), Color3.fromRGB(120, 255, 215))
            if p then p.Material = Enum.Material.Neon end
            cr[i] = { Part = p, Base = Hits(B, i), Up = true, Off = (i - 1) / 3 * math.pi * 2 }
        end
        B.crystals = cr
        B.rawTaken(B.model, B.baseTaken)
        return cr
    end
    local cr = Build()
    while B:Alive() do
        local need = (5 + 2 * B.phase) * (1 + 0.5 * (PartySize(B) - 1))
        local up = 0
        for i, c in ipairs(cr) do
            if c.Up and Hits(B, i) - c.Base >= need then
                c.Up = false
                if c.Part and c.Part.Parent then VFX.Burst(B.d.Fx, c.Part.Position, B.kit.Color, 12, nil); c.Part:Destroy() end
            end
            if c.Up then up += 1 end
        end
        B.model:SetAttribute("BossInfo", string.format("WARD CRYSTALS %d/3", up))
        if up == 0 then
            B.crystals = nil
            Window(B, "DISPELLED", "the ward is down: hit it", 2, 6)
            if not B:Alive() then return end
            VFX.Banner("NEW WARD", "three crystals: break them again", B.kit.Color)
            cr = Build()
        end
        B:Wait(0.15)
    end
end
SIG.HexcallerTick = function(B, now)
    local body = Body(B.model)
    if not (B.crystals and body) then return end
    local speed = 0.9 + B.phase * 0.35
    for _, c in ipairs(B.crystals) do
        if c.Up and c.Part and c.Part.Parent then
            local a = c.Off + now * speed
            local bob = math.sin(now * 2 + c.Off) * 1.2
            c.Part.CFrame = CFrame.new(body.Position + Vector3.new(math.cos(a) * 7, 1.5 + bob, math.sin(a) * 7)) * CFrame.Angles(0, a, 0)
        end
    end
end

SIG.Sentinel = function(B)
    local panel = B.model:FindFirstChild("ShieldPanel") or B.model:FindFirstChild("Shield")
    if panel then panel.Name = "Shield"; panel.Transparency = 0.25; panel.CanQuery = true; panel.Material = Enum.Material.ForceField end
    -- (phase 3: the shield wheels round the hull instead of facing you -- shoot through the gap)
    local body = Body(B.model)
    if not (panel and body) then return end
    B.shieldRest = body.CFrame:ToObjectSpace(panel.CFrame)
end
SIG.SentinelTick = function(B, now)
    local panel = B.model:FindFirstChild("Shield")
    local body = Body(B.model)
    if B.phase >= 3 and panel and body and B.shieldRest then
        panel.CFrame = body.CFrame * CFrame.Angles(0, now * 1.3, 0) * B.shieldRest
    end
end

SIG.Titan = function(B)
    local body = Body(B.model)
    if not body then return end
    B.sigOwn = true
    B.baseTaken = 0.5
    local function Build()
        local guns = {}
        for i, sx in ipairs({ -1, 1 }) do
            local bs = FullSize(B, body)
            local g = Attach(B, "BreakPart" .. i, Vector3.new(2.6, 2.6, 6), CFrame.new(sx * (bs.X / 2 + 1.6), bs.Y / 2 + 0.6, -0.5), Color3.fromRGB(255, 70, 50))
            guns[i] = { Part = g, Base = Hits(B, i), Up = true }
        end
        B.gunsUp = 2
        B.rawTaken(B.model, B.baseTaken)
        return guns
    end
    local guns = Build()
    while B:Alive() do
        local need = (14 + 4 * B.phase) * (1 + 0.5 * (PartySize(B) - 1))
        for _, g in ipairs(guns) do
            if g.Up and Hits(B, table.find(guns, g)) - g.Base >= need then
                g.Up = false
                B.gunsUp -= 1
                if g.Part and g.Part.Parent then VFX.Burst(B.d.Fx, g.Part.Position, Color3.fromRGB(255, 120, 60), 14, "Explosion"); g.Part:Destroy() end
                VFX.Banner("CANNON DESTROYED", B.gunsUp > 0 and "one left" or "", Color3.fromRGB(255, 140, 80))
            end
        end
        B.model:SetAttribute("BossInfo", string.format("CANNONS %d/2  •  HULL %d%%", B.gunsUp, B.gunsUp > 0 and 50 or 100))
        if B.gunsUp == 0 then
            Window(B, "OVERLOAD", "both cannons down: it's open", 2, 6)
            if not B:Alive() then return end
            VFX.Banner("REBUILDING", "new cannons online", Color3.fromRGB(255, 120, 80))
            guns = Build()
        end
        B:Wait(0.15)
    end
end

-- ==================== SUPERBOSSES v3: ENCOUNTERS (2026-10-05, owner: "The current superbosses are just simple reskins,
-- they need to be unique with distinct mechanics, like destiny") ====================
-- Every biome boss is an ENCOUNTER: it shrugs off damage (IMMUNE: 20% taken) until the team does ITS mechanic, which opens
-- a DAMAGE PHASE; the rotation of telegraphed attacks keeps going the whole time, so you do the mechanic while dodging.
-- Each one tests a different skill:
--   Fire  QUENCH     positioning: lit coolant plates, stand on each in order before the forge goes supernova
--   Ice   SHATTER    flank + precision: frost crystals on its back / sides (it turns away to channel, skates into walls)
--   Void  ORACLES    memory + flicks: glyphs flash a sequence, shoot them in that order, then fight inside the light well
--   Cyber FIREWALL   tracking: nodes on moving paths round the arena, break them all before the purge
--   Storm STORMCHARGE carry: one player is charged, they have to reach a lightning rod to ground the boss
local IMMUNE = 0.25 -- (0.60b: 0.2 -> 0.25, shooting between the mechanic windows counts a little more)
local function SigImmune(B)
    B.sigOwn = true
    B.baseTaken = IMMUNE
    B.rawTaken(B.model, IMMUNE)
end
local function TargetRoots(B)
    local out = {}
    for _, pl in ipairs(B.d.Targets()) do
        local rt = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
        local h = pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
        if rt and h and h.Health > 0 then table.insert(out, { Player = pl, Root = rt }) end
    end
    return out
end
local function AnyoneIn(B, pos, r)
    for _, t in ipairs(TargetRoots(B)) do
        if (Flat(t.Root.Position - pos)).Magnitude <= r then return t.Player end
    end
    return nil
end
-- n spots in the arena, at least `gap` apart and `avoidR` from `avoid`, `margin` from the walls
local function SpreadSpots(B, n, gap, avoid, avoidR, margin)
    local b = B.d.Bounds
    local spots = {}
    for _ = 1, n do
        local best, bestScore = nil, -math.huge
        for _ = 1, 24 do
            local p = Vector3.new(b.MinX + margin + math.random() * (b.MaxX - b.MinX - margin * 2), B.d.SpawnPos.Y, b.MinZ + margin + math.random() * (b.MaxZ - b.MinZ - margin * 2))
            local score = math.huge
            for _, q in ipairs(spots) do score = math.min(score, (Flat(p - q)).Magnitude - gap) end
            if avoid then score = math.min(score, (Flat(p - avoid)).Magnitude - avoidR) end
            if score >= 0 then best = p; break end
            if score > bestScore then best, bestScore = p, score end
        end
        table.insert(spots, best)
    end
    return spots
end
local function FloorDisc(B, pos, r, color, transp, name)
    local y = EA.GroundY(B.ctx, pos)
    local d = Part({ Name = name or "SigDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, r * 2, r * 2), Color = color, Transparency = transp or 0.3,
        CFrame = CFrame.new(pos.X, y + 0.14, pos.Z) * CFrame.Angles(0, 0, math.rad(90)) })
    d.Parent = B.d.Fx
    return d, y
end
local function Column(B, pos, y, r, h, color, transp)
    local c = Part({ Name = "SigColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, r * 2, r * 2), Color = color, Transparency = transp or 0.85,
        CFrame = CFrame.new(pos.X, y + h / 2, pos.Z) * CFrame.Angles(0, 0, math.rad(90)) })
    c.Parent = B.d.Fx
    return c
end
local function Kill(list) for _, p in ipairs(list) do if p and p.Parent then p:Destroy() end end table.clear(list) end
-- a lightning bolt between two points (a few jagged neon segments, gone in a moment)
local function Bolt(B, p0, p1, color, life)
    local pts = { p0 }
    for i = 1, 5 do table.insert(pts, p0:Lerp(p1, i / 6) + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3) end
    table.insert(pts, p1)
    for i = 1, #pts - 1 do
        local s = Part({ Name = "SigBolt", Size = Vector3.new(0.45, 0.45, (pts[i + 1] - pts[i]).Magnitude), Color = color, CFrame = CFrame.lookAt((pts[i] + pts[i + 1]) / 2, pts[i + 1]) })
        s.Parent = B.d.Fx
        game:GetService("Debris"):AddItem(s, life or 0.25)
    end
end
local function Info(B, text) B.model:SetAttribute("BossInfo", text) end
-- damage phase helper: TakeTurn -> Window -> GiveTurn (the rotation waits)
local function DamagePhase(B, top, sub, mult, secs, color)
    TakeTurn(B)
    B.active = 0
    Window(B, top, sub, mult, secs, color)
    GiveTurn(B, 1.0)
end
local function Wipe(B, top, sub, color)
    TakeTurn(B)
    VFX.Banner(top, sub, color or Color3.fromRGB(255, 120, 90))
    M.ArenaWipe(B, 3, 9, 1.7)
    GiveTurn(B, 1.4)
end

-- ----- FIRE: QUENCH -----
local COOLANT = Color3.fromRGB(90, 220, 255)
SIG.SuperFire = function(B)
    SigImmune(B)
    local HOLD, R = 2.4, 7
    local first = true
    while B:Alive() do
        B:Wait(first and 3.5 or MECH_BREAK) -- (0.49: an attack stretch between mechanic rounds)
        first = false
        if not B:Alive() then return end
        local plates, junk = {}, {}
        for _, p in ipairs(SpreadSpots(B, 3, 36, B.pos, 18, 16)) do
            local disc, y = FloorDisc(B, p, R, COOLANT, 0.7, "CoolantPlate")
            local fill = FloorDisc(B, p, 0.3, Color3.new(1, 1, 1), 0.2, "CoolantFill")
            local col = Column(B, p, y, R * 0.8, 40, COOLANT, 0.92)
            table.insert(junk, disc); table.insert(junk, fill); table.insert(junk, col)
            table.insert(plates, { Pos = p, Disc = disc, Fill = fill, Col = col, Y = y })
        end
        VFX.Banner("QUENCH THE FORGE", "stand on the lit coolant plates, one after another", COOLANT)
        Mech(B, true)
        local idx, prog = 1, 0
        local limit = 34 - B.phase * 3
        local tEnd = os.clock() + limit
        local last = os.clock()
        while B:Alive() and idx <= #plates and os.clock() < tEnd do
            local now = os.clock()
            local dt = now - last
            last = now
            for i, pl in ipairs(plates) do
                pl.Disc.Transparency = (i == idx) and 0.2 or ((i < idx) and 0.9 or 0.72)
                pl.Col.Transparency = (i == idx) and 0.8 or 0.97
            end
            local cur = plates[idx]
            if AnyoneIn(B, cur.Pos, R) then prog += dt else prog = math.max(0, prog - dt * 0.6) end
            local k = math.clamp(prog / HOLD, 0.02, 1)
            cur.Fill.Size = Vector3.new(0.3, R * 2 * k, R * 2 * k)
            if prog >= HOLD then
                VFX.Burst(B.d.Fx, Vector3.new(cur.Pos.X, cur.Y + 2, cur.Pos.Z), COOLANT, 12, nil)
                cur.Fill.Transparency = 1
                idx += 1
                prog = 0
            end
            Info(B, string.format("QUENCH %d/%d  •  %ds", idx - 1, #plates, math.max(0, math.ceil(tEnd - now))))
            B:Wait(0.1)
        end
        Kill(junk)
        Mech(B, false)
        if not B:Alive() then return end
        if idx > #plates then
            Info(B, "SHELL CRACKED")
            DamagePhase(B, "SHELL CRACKED", "the forge is cooled: unload on it", 1.75, 8, COOLANT)
        else
            Info(B, "SUPERNOVA")
            Wipe(B, "SUPERNOVA", "too slow: get to a safe circle", Color3.fromRGB(255, 120, 40))
        end
    end
end

-- ----- ICE: SHATTER -----
local FROST = Color3.fromRGB(190, 240, 255)
SIG.SuperIce = function(B)
    SigImmune(B)
    local body = Body(B.model)
    if not body then return end
    local SPOTS = { CFrame.new(-1.7, 2.4, 2.4) * CFrame.Angles(math.rad(20), 0, math.rad(-15)), CFrame.new(1.7, 2.4, 2.4) * CFrame.Angles(math.rad(20), 0, math.rad(15)),
        CFrame.new(-3.4, -1.2, 1.0) * CFrame.Angles(0, 0, math.rad(-35)), CFrame.new(3.4, -1.2, 1.0) * CFrame.Angles(0, 0, math.rad(35)) }
    local crystals = {}
    local function Grow()
        for _, c in ipairs(crystals) do if c.Part and c.Part.Parent then c.Part:Destroy() end end
        table.clear(crystals)
        for i, off in ipairs(SPOTS) do
            local p = Attach(B, "BreakPart" .. i, Vector3.new(1.5, 3, 1.5), off, FROST)
            if p then
                p.Material = Enum.Material.Neon; p.Transparency = 0.1
                table.insert(crystals, { Part = p, Base = Hits(B, i), I = i, Alive = true })
            end
        end
        B.poseCache = nil
    end
    Grow()
    VFX.Banner("SHATTER", "break the frost crystals on its back", FROST)
    local nextAct = os.clock() + 7
    local skate = false
    while B:Alive() do
        local need = math.ceil((5 + 2 * B.phase) * (1 + 0.5 * (PartySize(B) - 1)))
        local left = 0
        for _, c in ipairs(crystals) do
            if c.Alive then
                if Hits(B, c.I) - c.Base >= need then
                    c.Alive = false
                    VFX.Burst(B.d.Fx, c.Part.Position, FROST, 9, "Explosion")
                    c.Part:Destroy()
                else
                    left += 1
                end
            end
        end
        Info(B, string.format("CRYSTALS %d/%d  •  hit them on its back", #crystals - left, #crystals))
        if left == 0 then
            DamagePhase(B, "SHATTERED", "its armour is gone: full damage", 1.75, 8, FROST)
            if not B:Alive() then return end
            Grow()
            nextAct = os.clock() + 5
        elseif os.clock() >= nextAct and B.active == 0 and not B.rooted then
            skate = not skate
            TakeTurn(B)
            local r = B:Root()
            if r and skate then
                -- SKATE: it charges down a lane; if it hits a wall it's stuck facing it (its back is yours)
                VFX.Banner("SKATE", "dodge it into a wall", B.kit.Color)
                for _ = 1, 1 + B.phase do
                    r = B:Root()
                    if not r or not B:Alive() then break end
                    local dir = Unit(r.Position - B.pos)
                    local to = B.pos + dir * 75
                    local clamped = B:Clamp(to)
                    local hitsWall = (Flat(clamped - to)).Magnitude > 0.5
                    EA.Line(B.ctx, B.pos, clamped, 9, 0.75, { Mult = 1.6, Height = 12 })
                    B:Wait(B:W(0.75))
                    B:Dash(clamped, math.max(0.3, (Flat(clamped - B.pos)).Magnitude / 130))
                    if hitsWall then
                        B:Boom(B.pos, 16, "BossSlam")
                        B.faceDir, B.faceUntil = dir, os.clock() + 4
                        B.rooted = true
                        VFX.Banner("STUCK IN THE WALL", "its back is open: break the crystals", FROST)
                        B:Wait(4)
                        B.rooted = false
                        break
                    end
                    B:Wait(0.35)
                end
            elseif r then
                -- GLACIAL CHANNEL: it turns its back to call down icicles (rooted)
                VFX.Banner("GLACIAL CHANNEL", "it turned away: get behind it", B.kit.Color)
                B.faceDir, B.faceUntil = Unit(B.pos - r.Position), os.clock() + 4.5
                B.rooted = true
                M.Rain(B, 6 + B.phase * 2, 5, 0.8, 0, 0.45)
                local t = os.clock() + 4.5
                while B:Alive() and os.clock() < t do B:Wait(0.1) end
                B.rooted = false
            end
            GiveTurn(B, 1.0)
            nextAct = os.clock() + math.max(7, 12 - B.phase * 1.5)
        end
        B:Wait(0.12)
    end
end

-- ----- VOID: ORACLES -----
local GLYPH = Color3.fromRGB(170, 90, 255)
local GLYPH_ON = Color3.fromRGB(255, 240, 255)
local GLYPH_DONE = Color3.fromRGB(255, 215, 110)
SIG.SuperVoid = function(B)
    SigImmune(B)
    local first = true
    while B:Alive() do
        B:Wait(first and 3 or MECH_BREAK)
        first = false
        if not B:Alive() then return end
        local b = B.d.Bounds
        local cx, cz = (b.MinX + b.MaxX) / 2, (b.MinZ + b.MaxZ) / 2
        local rad = math.min(b.MaxX - b.MinX, b.MaxZ - b.MinZ) * 0.38
        local n = (B.phase >= 3) and 6 or 5
        local glyphs, junk = {}, {}
        local a0 = math.random() * math.pi * 2
        for i = 1, n do
            local a = a0 + (i - 1) * math.pi * 2 / n
            local pos = Vector3.new(cx + math.cos(a) * rad, B.d.SpawnPos.Y + 6 + (i % 2) * 6, cz + math.sin(a) * rad)
            local g = Part({ Name = "ShieldOrb" .. i, Shape = Enum.PartType.Ball, Size = Vector3.one * 4, Color = GLYPH, Transparency = 0.35, CanQuery = true, CFrame = CFrame.new(pos) })
            g:SetAttribute("BossOrb", true)
            local link = Instance.new("ObjectValue"); link.Name = "HitModel"; link.Value = B.model; link.Parent = g
            local ring = Part({ Name = "GlyphRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 6, 6), Color = GLYPH, Transparency = 0.4, CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)) })
            ring.Parent = g
            g.Parent = B.d.Fx
            table.insert(junk, g)
            table.insert(glyphs, { Part = g, Ring = ring, I = i, Seen = Hits(B, i), Pos = pos })
        end
        -- the sequence: L distinct glyphs, shown one by one
        local L = math.min(n, 2 + B.phase)
        local order = {}
        for i = 1, n do order[i] = i end
        for i = n, 2, -1 do local j = math.random(1, i); order[i], order[j] = order[j], order[i] end
        local seq = {}
        for i = 1, L do seq[i] = order[i] end
        VFX.Banner("THE EYE SPEAKS", "watch the glyphs, then shoot them in the same order", GLYPH)
        Mech(B, true)
        Info(B, "WATCH THE GLYPHS")
        B:Wait(1.6)
        for _, gi in ipairs(seq) do
            if not B:Alive() then Kill(junk) return end
            local g = glyphs[gi]
            g.Part.Color, g.Part.Transparency, g.Ring.Color = GLYPH_ON, 0, GLYPH_ON
            g.Part.Size = Vector3.one * 5.2
            VFX.Burst(B.d.Fx, g.Pos, GLYPH_ON, 8, nil)
            Sound("UIClick", g.Part)
            B:Wait(0.75)
            g.Part.Color, g.Part.Transparency, g.Ring.Color = GLYPH, 0.35, GLYPH
            g.Part.Size = Vector3.one * 4
            B:Wait(0.25)
        end
        for _, g in ipairs(glyphs) do g.Seen = Hits(B, g.I) end
        -- the answer
        local idx, ok, wrong = 1, false, false
        local tEnd = os.clock() + 14 + L * 2
        while B:Alive() and os.clock() < tEnd do
            for _, g in ipairs(glyphs) do
                local h = Hits(B, g.I)
                if h > g.Seen then
                    g.Seen = h
                    if g.I == seq[idx] then
                        g.Part.Color, g.Ring.Color, g.Part.Transparency = GLYPH_DONE, GLYPH_DONE, 0
                        VFX.Burst(B.d.Fx, g.Pos, GLYPH_DONE, 7, nil)
                        idx += 1
                        if idx > L then ok = true end
                    elseif not table.find(seq, g.I) or table.find(seq, g.I) > idx then
                        wrong = true
                    end
                end
                if ok or wrong then break end
            end
            if ok or wrong then break end
            Info(B, string.format("ORACLES %d/%d  •  %ds", idx - 1, L, math.max(0, math.ceil(tEnd - os.clock()))))
            B:Wait(0.08)
        end
        Kill(junk)
        Mech(B, false)
        if not B:Alive() then return end
        if ok then
            -- BLINDED: a light well opens; inside it you deal double, outside normal damage
            TakeTurn(B)
            B.active = 0
            B.blinded = true
            local spot = SpreadSpots(B, 1, 0, B.pos, 22, 22)[1]
            local disc, y = FloorDisc(B, spot, 12, Color3.fromRGB(255, 230, 150), 0.35, "LightWell")
            local col = Column(B, spot, y, 11, 60, Color3.fromRGB(255, 240, 190), 0.88)
            VFX.Banner("THE EYE IS BLINDED", "stand in the light for double damage", Color3.fromRGB(255, 230, 150))
            B.rooted, B.staggered = true, true
            B:Hold(8)
            -- (a solo boss runs on your client: the server allows one 8 s damage window, opened by a value > 1 -- x2 in the
            -- light, x1.5 outside)
            local tw = os.clock() + 8
            local inside = nil
            while B:Alive() and os.clock() < tw do
                local now = AnyoneIn(B, spot, 12) ~= nil
                if now ~= inside then inside = now; B.rawTaken(B.model, now and 2 or 1.5) end
                B:Title(string.format("%s   >>  BLINDED %s (%ds)", B.kit.Names[B.phase], now and "x2" or "x1.5", math.ceil(tw - os.clock())), Color3.fromRGB(255, 230, 150))
                Info(B, now and "IN THE LIGHT: DOUBLE DAMAGE" or "BLINDED: STAND IN THE LIGHT FOR x2")
                B:Wait(0.1)
            end
            B.rooted, B.staggered, B.blinded = false, false, false
            B.rawTaken(B.model, IMMUNE)
            if disc.Parent then disc:Destroy() end
            if col.Parent then col:Destroy() end
            if B:Alive() then B:Title(B.kit.Names[B.phase]) end
            GiveTurn(B, 1.0)
        else
            Info(B, "GAZE OF THE VOID")
            Wipe(B, "GAZE OF THE VOID", wrong and "wrong glyph: get to a safe circle" or "too slow: get to a safe circle", GLYPH)
        end
    end
end

-- ----- CYBER: FIREWALL (moving nodes) -----
local NODE = Color3.fromRGB(60, 255, 190)
SIG.SuperCyber = function(B)
    SigImmune(B)
    local body = Body(B.model)
    if not body then return end
    local first = true
    while B:Alive() do
        B:Wait(first and 3 or MECH_BREAK)
        first = false
        if not B:Alive() then return end
        local b = B.d.Bounds
        local cx, cz = (b.MinX + b.MaxX) / 2, (b.MinZ + b.MaxZ) / 2
        local span = math.min(b.MaxX - b.MinX, b.MaxZ - b.MinZ)
        local count = (B.phase >= 3) and 4 or 3
        local need = math.ceil((4 + 2 * B.phase) * (1 + 0.5 * (PartySize(B) - 1)))
        local size = B.model:GetExtentsSize()
        local bubble = Part({ Name = "ShieldBubble", Shape = Enum.PartType.Ball, Size = Vector3.one * (math.max(size.X, size.Y, size.Z) + 3), Color = NODE, Material = Enum.Material.ForceField, Transparency = 0.3, CFrame = body.CFrame })
        bubble.Parent = B.d.Fx
        local nodes = {}
        for i = 1, count do
            local o = Part({ Name = "ShieldOrb" .. i, Shape = Enum.PartType.Ball, Size = Vector3.one * 4, Color = NODE, CanQuery = true })
            o:SetAttribute("BossOrb", true)
            local core = Part({ Name = "OrbCore", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, Color = Color3.new(1, 1, 1) })
            core.Parent = o
            local link = Instance.new("ObjectValue"); link.Name = "HitModel"; link.Value = B.model; link.Parent = o
            local a1 = Instance.new("Attachment"); a1.Parent = o
            local a2 = Instance.new("Attachment"); a2.Parent = body
            local beam = Instance.new("Beam")
            beam.Attachment0, beam.Attachment1 = a1, a2
            beam.Width0, beam.Width1 = 0.5, 1; beam.FaceCamera = true; beam.LightEmission = 1
            beam.Color = ColorSequence.new(NODE); beam.Transparency = NumberSequence.new(0.4); beam.Texture = SPARK; beam.TextureSpeed = 1.5; beam.Parent = o
            o.Parent = B.d.Fx
            -- each node runs its own loop: radius, speed, direction, height and a figure-eight wobble differ
            table.insert(nodes, { Part = o, Core = core, I = i, Base = Hits(B, i), Alive = true, R = span * (0.18 + 0.08 * i), W = (0.35 + 0.12 * B.phase + i * 0.05) * ((i % 2 == 0) and -1 or 1),
                A = math.random() * math.pi * 2, Y = 5 + i * 3, Wob = math.random() * 6 })
        end
        VFX.Banner("FIREWALL", string.format("track and break the %d moving nodes", count), NODE)
        Mech(B, true)
        local t0 = os.clock()
        local limit = 26
        local lastMove = 0
        while B:Alive() do
            local now = os.clock()
            local left = 0
            for _, nd in ipairs(nodes) do
                if nd.Alive then
                    if Hits(B, nd.I) - nd.Base >= need then
                        nd.Alive = false
                        VFX.Burst(B.d.Fx, nd.Part.Position, NODE, 9, "Explosion")
                        nd.Part:Destroy()
                    else
                        left += 1
                    end
                end
            end
            if left == 0 then break end
            -- (server-run party bosses move them at 10 Hz: every move replicates)
            if not RunService:IsServer() or now - lastMove >= 0.1 then
                local dt = now - (lastMove > 0 and lastMove or now)
                lastMove = now
                for _, nd in ipairs(nodes) do
                    if nd.Alive then
                        nd.A += nd.W * dt
                        local p = Vector3.new(cx + math.cos(nd.A) * nd.R, B.d.SpawnPos.Y + nd.Y + math.sin(now * 1.3 + nd.Wob) * 3, cz + math.sin(nd.A * 2) * nd.R * 0.55)
                        nd.Part.CFrame = CFrame.new(p)
                        nd.Core.CFrame = nd.Part.CFrame
                    end
                end
            end
            if bubble.Parent then bubble.CFrame = body.CFrame end
            Info(B, string.format("FIREWALL %d/%d  •  %ds", count - left, count, math.max(0, math.ceil(limit - (now - t0)))))
            if now - t0 >= limit then break end
            RunService.Heartbeat:Wait()
        end
        local cleared = true
        for _, nd in ipairs(nodes) do if nd.Alive then cleared = false end if nd.Part.Parent then nd.Part:Destroy() end end
        if bubble.Parent then bubble:Destroy() end
        Mech(B, false)
        if not B:Alive() then return end
        if cleared then
            B.crashed = true
            DamagePhase(B, "SYSTEM CRASH", "the core is exposed: full damage", 1.75, 8, NODE)
            B.crashed = false
        else
            Wipe(B, "PURGE", "the firewall held: get to a safe circle", Color3.fromRGB(255, 80, 120))
        end
    end
end

-- ----- STORM: STORMCHARGE -----
local COPPER = Color3.fromRGB(176, 106, 58)
local CHARGE = Color3.fromRGB(150, 210, 255)
SIG.SuperStorm = function(B)
    SigImmune(B)
    local rods, rodJunk = {}, {}
    local function Raise()
        Kill(rodJunk)
        table.clear(rods)
        for _, p in ipairs(SpreadSpots(B, 3, 44, B.pos, 20, 18)) do
            local y = EA.GroundY(B.ctx, p)
            local pole = Part({ Name = "LightningRod", Shape = Enum.PartType.Cylinder, Size = Vector3.new(16, 0.9, 0.9), Color = COPPER, Material = Enum.Material.Metal, CFrame = CFrame.new(p.X, y + 8, p.Z) * CFrame.Angles(0, 0, math.rad(90)) })
            pole.Parent = B.d.Fx
            local tip = Part({ Name = "LightningRodTip", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = CHARGE, CFrame = CFrame.new(p.X, y + 16.5, p.Z) })
            tip.Parent = B.d.Fx
            local pad = FloorDisc(B, p, 7, CHARGE, 0.7, "RodPad")
            table.insert(rodJunk, pole); table.insert(rodJunk, tip); table.insert(rodJunk, pad)
            table.insert(rods, { Pos = p, Tip = tip, Pad = pad, Spent = false, Y = y })
        end
    end
    Raise()
    local first = true
    while B:Alive() do
        B:Wait(first and 5 or MECH_BREAK - 2)
        first = false
        if not B:Alive() then break end
        local any = false
        for _, r in ipairs(rods) do if not r.Spent then any = true end end
        if not any then
            Raise()
            VFX.Banner("THE RODS RECHARGE", "", CHARGE)
            B:Wait(1)
        end
        local ts = TargetRoots(B)
        if #ts == 0 then continue end
        local tg = ts[math.random(1, #ts)]
        local limit = 11
        VFX.Banner("STORMCHARGED", (#B.d.Targets() > 1 and (tg.Player.DisplayName .. ": ") or "") .. "run to a lightning rod to ground the storm", CHARGE)
        local ring = Part({ Name = "ChargeRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 9, 9), Color = CHARGE, Transparency = 0.25 })
        ring.Parent = B.d.Fx
        local halo = Part({ Name = "ChargeHalo", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = CHARGE })
        halo.Parent = B.d.Fx
        local tEnd = os.clock() + limit
        local grounded = nil
        Mech(B, true)
        while B:Alive() and os.clock() < tEnd do
            local rt = tg.Root
            if not rt.Parent then break end
            local p = rt.Position
            ring.CFrame = CFrame.new(p.X, p.Y - 2.8, p.Z) * CFrame.Angles(0, 0, math.rad(90))
            halo.CFrame = CFrame.new(p + Vector3.new(0, 4.5, 0))
            if math.random() < 0.3 then Bolt(B, p + Vector3.new(0, 4.5, 0), p + Vector3.new(math.random(-3, 3), -2, math.random(-3, 3)), CHARGE, 0.1) end
            for _, r in ipairs(rods) do
                if not r.Spent and (Flat(p - r.Pos)).Magnitude <= 7 then grounded = r break end
            end
            if grounded then break end
            Info(B, string.format("STORMCHARGED  •  %ds", math.max(0, math.ceil(tEnd - os.clock()))))
            B:Wait(0.05)
        end
        local at = tg.Root.Parent and tg.Root.Position or B.pos
        Mech(B, false)
        if ring.Parent then ring:Destroy() end
        if halo.Parent then halo:Destroy() end
        if not B:Alive() then break end
        if grounded then
            grounded.Spent = true
            grounded.Tip.Color = Color3.fromRGB(60, 64, 72)
            grounded.Pad.Transparency = 0.92
            for _ = 1, 3 do Bolt(B, grounded.Tip.Position, B.pos + Vector3.new(0, 4, 0), CHARGE, 0.35) end
            VFX.Shake(B.pos, 1.4)
            DamagePhase(B, "GROUNDED", "the storm is grounded: full damage", 1.75, 8, CHARGE)
        else
            TakeTurn(B)
            VFX.Banner("OVERCHARGE", "the charge blew: stay away from it", Color3.fromRGB(255, 120, 90))
            EA.Circle(B.ctx, at, 18, 0.7, { Mult = 1.6 })
            EA.Ring(B.ctx, at, 60, 0.6, { Mult = 1.0, Speed = 36 })
            B:Wait(B:W(0.9))
            GiveTurn(B, 1.2)
        end
    end
    Kill(rodJunk)
end

-- ==================== THE ASCENDANT (Trial of Ascension boss, AscensionTrials) ====================
-- Its phases ARE the trials: PRECISION (a ward; small fast sigils whirl round it -- break them all), NERVE (phase 2: one
-- quarter of the arena is sanctified -- you only hurt it from inside, and judgement burns everywhere else), FINAL ASCENSION
-- (phase 3 sigils + at 12% it starts to ascend: a DPS race, or the arena burns). Tier (config.AscTier) adds sigils, health
-- and pace (DungeonGenerator.CreateAscendant).
local ASC = Color3.fromRGB(60, 240, 210)
local ASC_GOLD = Color3.fromRGB(255, 215, 110)
KITS.Ascendant = {
    Color = ASC, Move = "Orbit", Range = 30, SpeedMul = 0.9, Recover = { 2.0, 1.7, 1.45 },
    Names = { "THE ASCENDANT", "THE ASCENDANT: TRIAL OF NERVE", "THE ASCENDANT: FINAL ASCENSION" },
    Moves = {
        { { function(B) M.Roll(B, 2, 6, 50, "Wheel") end, "VERDICT" }, { function(B) M.InOut(B, 14, 46, true, 0.95) end, "HALO" }, { function(B) M.Hexfall(B, 6) end, "SIGIL RAIN" } },
        { { function(B) M.Quadrants(B, 70, 2, 0.9) end, "JUDGEMENT" }, { function(B) M.Fissures(B, 3, math.rad(20)) end, "RIFT STRIKE" }, { function(B) M.Orbit(B, 4, 5, 4.2) end, "BLADE HALO" },
          { function(B) M.Cage(B, 8, 12, 1.0) end, "HALO CAGE" } },
        { { function(B) M.Marks(B, 2) end, "SENTENCE" }, { function(B) M.Carpet(B, 5, 4, 6, 0.85, 0.28) end, "CONDEMNATION" }, { function(B) M.Converge(B, 3, 0.85) end, "HALO COLLAPSE" },
          { function(B) M.Pincer(B, 12, 0.9, 0.42) end, "THE NARROW PATH" } },
    },
}
EVADE.Ascendant = { Amp = 10, Rate = 1.6, Dodge = 3.4 }
KITS.Ascendant.Animate = function(B, pivot, now)
    B.lift = (B.lift or 0) + ((((B.active > 0) and 1) or 0) - (B.lift or 0)) * 0.1
    Pose(B, "Deco_Wheel", pivot, CFrame.new(0, 4.5, 2.6), CFrame.Angles(0, 0, now * (0.35 + B.phase * 0.2)))
    Pose(B, "Deco_Robe", pivot, CFrame.new(0, -3.6, 0), CFrame.Angles(math.sin(now * 1.2) * 0.05, now * 0.2, math.sin(now) * 0.04))
    for _, sx in ipairs({ -1, 1 }) do
        Pose(B, "Deco_Pauldron" .. (sx < 0 and "L" or "R"), pivot, CFrame.new(), CFrame.new(0, math.sin(now * 1.5 + sx) * 0.35, 0))
    end
    Pose(B, "Deco_Sword", pivot, CFrame.new(0, 0.6, -3.2), CFrame.Angles(-B.lift * 1.3, 0, 0))
end

local function AscPrecision(B, tier)
    local body = Body(B.model)
    if not body then return end
    local startPhase = B.phase
    local count = math.min(6, 4 + ((tier >= 3) and 1 or 0) + ((B.phase >= 3) and 1 or 0))
    local need = math.ceil((3 + tier) * (1 + 0.5 * (PartySize(B) - 1)))
    local sig = {}
    for i = 1, count do
        local o = Part({ Name = "ShieldOrb" .. i, Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, Color = ASC, CanQuery = true })
        o:SetAttribute("BossOrb", true)
        local core = Part({ Name = "OrbCore", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, Color = Color3.new(1, 1, 1) })
        core.Parent = o
        local link = Instance.new("ObjectValue"); link.Name = "HitModel"; link.Value = B.model; link.Parent = o
        o.Parent = B.d.Fx
        table.insert(sig, { Part = o, Core = core, I = i, Base = Hits(B, i), Alive = true, R = 9 + (i % 3) * 2.5, A = (i - 1) / count * math.pi * 2,
            W = (1.0 + 0.25 * B.phase + 0.1 * tier) * ((i % 2 == 0) and -1 or 1), Y = -1 + (i % 3) * 3.5 })
    end
    local size = B.model:GetExtentsSize()
    local ward = Part({ Name = "AscWard", Shape = Enum.PartType.Ball, Size = Vector3.one * (math.max(size.X, size.Y) * 0.8), Color = ASC, Material = Enum.Material.ForceField, Transparency = 0.35, CFrame = body.CFrame })
    ward.Parent = B.d.Fx
    VFX.Banner("TRIAL OF PRECISION", string.format("break the %d sigils round it", count), ASC)
    Mech(B, true)
    local t0, limit, lastMove = os.clock(), 22, 0
    local cleared, aborted = false, false
    while B:Alive() do
        local now = os.clock()
        if B.finalAsc or B.phase ~= startPhase then aborted = true break end
        local left = 0
        for _, s in ipairs(sig) do
            if s.Alive then
                if Hits(B, s.I) - s.Base >= need then
                    s.Alive = false
                    VFX.Burst(B.d.Fx, s.Part.Position, ASC, 7, nil)
                    s.Part:Destroy()
                else
                    left += 1
                end
            end
        end
        if left == 0 then cleared = true break end
        if not RunService:IsServer() or now - lastMove >= 0.1 then
            local dt = now - (lastMove > 0 and lastMove or now)
            lastMove = now
            local c = body.Position
            for _, s in ipairs(sig) do
                if s.Alive then
                    s.A += s.W * dt
                    s.Part.CFrame = CFrame.new(c + Vector3.new(math.cos(s.A) * s.R, s.Y + math.sin(now * 2 + s.I) * 1.2, math.sin(s.A) * s.R))
                    s.Core.CFrame = s.Part.CFrame
                end
            end
        end
        if ward.Parent then ward.CFrame = body.CFrame end
        Info(B, string.format("SIGILS %d/%d  •  %ds", count - left, count, math.max(0, math.ceil(limit - (now - t0)))))
        if now - t0 >= limit then break end
        RunService.Heartbeat:Wait()
    end
    for _, s in ipairs(sig) do if s.Part.Parent then s.Part:Destroy() end end
    if ward.Parent then ward:Destroy() end
    Mech(B, false)
    if not B:Alive() or aborted then return end
    if cleared then
        DamagePhase(B, "WARD BROKEN", "the trial is passed: strike it", 1.75, 8, ASC)
    else
        Wipe(B, "JUDGEMENT", "the ward held: get to a safe circle", ASC)
    end
end

local function AscNerve(B)
    local b = B.d.Bounds
    local cx, cz = (b.MinX + b.MaxX) / 2, (b.MinZ + b.MaxZ) / 2
    local hw, hd = (b.MaxX - b.MinX) / 2, (b.MaxZ - b.MinZ) / 2
    local q = math.random(1, 4)
    if q == B.lastQuad then q = (q % 4) + 1 end
    B.lastQuad = q
    local sx, sz = (q == 1 or q == 4) and -1 or 1, (q <= 2) and -1 or 1
    local qc = Vector3.new(cx + sx * hw / 2, B.d.SpawnPos.Y, cz + sz * hd / 2)
    local y = EA.GroundY(B.ctx, qc)
    local pad = Part({ Name = "Sanctified", Size = Vector3.new(hw - 4, 0.25, hd - 4), Color = ASC_GOLD, Transparency = 0.75, CFrame = CFrame.new(qc.X, y + 0.15, qc.Z) })
    pad.Parent = B.d.Fx
    local col = Column(B, qc, y, math.min(hw, hd) * 0.3, 50, ASC_GOLD, 0.93)
    local function Inside()
        for _, t in ipairs(TargetRoots(B)) do
            local p = t.Root.Position
            if math.abs(p.X - qc.X) <= hw / 2 and math.abs(p.Z - qc.Z) <= hd / 2 then return true end
        end
        return false
    end
    VFX.Banner("TRIAL OF NERVE", "fight from the sanctified quarter", ASC_GOLD)
    Info(B, "GET TO THE SANCTIFIED QUARTER")
    Mech(B, true)
    B:Wait(3)
    pad.Transparency = 0.5
    local tEnd = os.clock() + 8
    local inside = nil
    while B:Alive() and os.clock() < tEnd do
        if B.finalAsc or B.phase ~= 2 then break end
        local now = Inside()
        if now ~= inside then inside = now; B.rawTaken(B.model, now and 1.75 or 1) end
        Info(B, string.format("%s  •  %ds", now and "SANCTIFIED: FULL DAMAGE" or "STAND IN THE GOLD", math.max(0, math.ceil(tEnd - os.clock()))))
        B:Wait(0.1)
    end
    B.rawTaken(B.model, IMMUNE)
    Mech(B, false)
    if B:Alive() and not B.finalAsc and B.phase == 2 then
        TakeTurn(B)
        VFX.Banner("JUDGEMENT FALLS", "only the sanctified quarter is safe", ASC_GOLD)
        EA.Arena(B.ctx, B.d.Bounds, { { Pos = qc, R = math.min(hw, hd) * 0.42 } }, 1.5, { Mult = 1.9 })
        B:Wait(B:W(1.5) + 0.3)
        GiveTurn(B, 1.2)
    end
    if pad.Parent then pad:Destroy() end
    if col.Parent then col:Destroy() end
end

local function AscFinal(B, tier)
    B.rawTaken(B.model, 1)
    VFX.Banner("FINAL ASCENSION", "kill it before it ascends", ASC)
    while B:Alive() do
        local limit = math.max(14, 22 - tier * 1.5)
        local tEnd = os.clock() + limit
        while B:Alive() and os.clock() < tEnd do
            local left = tEnd - os.clock()
            B.yOff = (1 - left / limit) * 9
            Info(B, string.format("ASCENDING  •  %ds", math.ceil(left)))
            B:Wait(0.1)
        end
        if not B:Alive() then break end
        TakeTurn(B)
        VFX.Banner("ASCENDED", "it broke the sky: get to the safe circle", ASC)
        M.ArenaWipe(B, 1, 11, 1.6)
        B.yOff = 0
        GiveTurn(B, 1.4)
    end
    B.yOff = 0
end

SIG.Ascendant = function(B)
    SigImmune(B)
    local tier = B.config.AscTier or 1
    task.spawn(function()
        while B:Alive() and not B.finalAsc do
            local hp, mx = B.model:GetAttribute("Health") or 1, B.model:GetAttribute("MaxHealth") or 1
            if B.phase >= 3 and hp / math.max(1, mx) <= 0.12 then B.finalAsc = true end
            B:Wait(0.2)
        end
    end)
    B:Wait(3)
    while B:Alive() do
        if B.finalAsc then AscFinal(B, tier) break end
        if B.phase == 2 then AscNerve(B) else AscPrecision(B, tier) end
        B:Wait(MECH_BREAK - 3)
    end
end

-- ==================== SHIELD ORBS (owner 2026-10-05: "Current bosses feel unengaging, add more mechanics (shooting
-- orbs / weakspots, destiny style bosses etc)") ====================
-- At each phase change the boss raises a SHIELD (immune) and floats glowing orbs round the arena, each tethered to it by
-- a beam. Shoot every orb to break the shield: the boss is STAGGERED (stops attacking, takes +75% damage for a few
-- seconds -- the damage phase). Too slow, and every orb still up blasts where you stand, then they reform.
-- Hits: the orbs are parts of the boss model named "ShieldOrb<i>"; CombatServer counts a hit on one into the model's /
-- stand-in's attribute "Orb<i>" (no damage), which DungeonClient mirrors to a solo boss. Here we read the counts.
-- Bosses with their own damage-window mechanic (the Boss Trial bosses) don't use it.
-- ==================== MAJOR BOSSES (0.52) ====================
-- Owner: "add 4 more bosses, all with VERY unique attacks, phases and mechanics ... these SHOULD be difficult, as you are
-- going to farm exotics from these". Boss Trials (BossTrials Major = true): more health / harder hits (DungeonGenerator
-- MAJOR_HP / MAJOR_DMG), their signature runs in the trial (the old trial bosses' don't), an ENRAGE timer
-- (cfg.EnrageAt), their own mechanic-mode moves (kit.MechMoves) and their own body animation (kit.Animate).
-- Damage windows go through MajorWindow: a solo boss runs on the client and the server only accepts a window (> 1)
-- every 13 s (DungeonRuns EnemyFlag), so windows closer than that are skipped rather than shown and not counted.
local function CanWindow(B) return os.clock() - (B.winAt or -99) >= 13.5 end
local function MajorWindow(B, top, sub, mult, secs, color, own)
    if not CanWindow(B) then return false end
    B.winAt = os.clock()
    if own then Window(B, top, sub, mult, secs, color) else DamagePhase(B, top, sub, mult, secs, color) end
    return true
end
-- how many hits a target needs, scaled for the party (the same rule as the shield orbs)
local function NeedHits(B, base) return math.ceil(base * (1 + 0.5 * (PartySize(B) - 1))) end
-- ENRAGE: past the timer the boss attacks 40% faster and hits 60% harder (the bar says so); a party that can't
-- beat the mechanics in time can't out-heal it forever
local function MajorEnrage(B)
    local at = B.config.EnrageAt or 420
    local t0 = os.clock()
    while B:Alive() do
        B:Wait(1)
        if os.clock() - t0 >= at and not B.enraged then
            B.enraged = true
            B.pace *= 0.6
            B.hitMult = (B.hitMult or 1) * 1.6
            B.kit = table.clone(B.kit)
            B.kit.Names = { B.kit.Names[1] .. "  [ENRAGED]", B.kit.Names[2] .. "  [ENRAGED]", B.kit.Names[3] .. "  [ENRAGED]" }
            VFX.Banner("ENRAGED", "too slow: it hits far harder now", Color3.fromRGB(255, 60, 60))
            VFX.ScreenFlash(Color3.fromRGB(255, 40, 40), 0.35)
            if not B.roaring then B:Title(B.kit.Names[B.phase], Color3.fromRGB(255, 80, 80)) end
            return
        end
    end
end
-- the mechanic-mode moves the major bosses throw while you work a mechanic: lighter than their rotation, heavier
-- than the regular bosses' (they're the hard fights)
local MAJOR_MECH = {
    { function(B) M.Rain(B, 2, 6, 1.1, 0, 0.6, { Mult = 0.8 }) end, "SEEKERS" },
    { function(B)
        EA.Ring(B.ctx, B.pos, 75, 0.7, { Mult = 0.8, Speed = 28, StartRadius = 4 })
        B:Wait(0.6)
        EA.Ring(B.ctx, B.pos, 75, 0.4, { Mult = 0.8, Speed = 28, StartRadius = 4 })
        B:Wait(B:W(0.8) + 0.4)
    end, "TWIN PULSE" },
    { function(B)
        local r = B:Root()
        if r then EA.Beam(B.ctx, function() return B.pos + Vector3.new(0, 1, 0) end, r, 1.2, { Mult = 0.9, LockTime = 0.3, Width = 2, Range = 240 }) end
        B:Wait(B:W(1.2))
    end, "LOCK-ON" },
}

-- ----- THE LOCKWARDEN (Storm): LOCKDOWN -- four coloured locks on its body, four tiles of the same colours on the
-- floor; a lock only counts hits while someone stands on its tile. All four = VAULT OPEN. Phase 2 the tiles move,
-- phase 3 the locks circle its body. -----
local WARD = Color3.fromRGB(120, 200, 255)
local LOCK_COLORS = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(80, 255, 120), Color3.fromRGB(80, 150, 255), Color3.fromRGB(255, 220, 60) }
local LOCK_NAMES = { "RED", "GREEN", "BLUE", "GOLD" }
local function WardChainSweep(B, reverse)
    local r = B:Root()
    if not r then return end
    local toward = math.atan2(r.Position.X - B.pos.X, r.Position.Z - B.pos.Z)
    local arc = math.rad(150 + 20 * B.phase)
    local start = toward + (reverse and 1 or -1) * arc / 2
    B:Hold(B:W(1.0) + 2.0)
    local stop = B:Charge(0.7)
    B:Wait(B:W(0.7))
    stop()
    EA.Sweep(B.ctx, function() return B.pos end, start, (reverse and -1 or 1) * arc, 1.6, 52, { Mult = 1.3 })
    B:Wait(1.8)
end
local function WardKeyThrust(B, n)
    for k = 1, n or 1 do
        if not B:Alive() then return end
        local r = B:Root()
        if not r then return end
        local dir = Unit(r.Position - B.pos)
        if (n or 1) > 1 then dir = CFrame.Angles(0, math.rad((k - (n + 1) / 2) * 24), 0):VectorToWorldSpace(dir) end
        B:Hold(B:W(0.95) + 0.4)
        EA.Line(B.ctx, B.pos, B.pos + dir * 110, 7, 0.95, { Mult = 1.5, Height = 12, Plain = M.PLAIN.KeyThrust })
        B:Wait(0.3)
    end
    B:Wait(B:W(0.95))
end
local function WardTesla(B)
    local r = B:Root()
    if not r then return end
    local c = r.Position
    for _, o in ipairs({ Vector3.new(12, 0, 0), Vector3.new(-12, 0, 0), Vector3.new(0, 0, 12), Vector3.new(0, 0, -12) }) do
        EA.Circle(B.ctx, B:Clamp(c + o), 7, 1.0, { Mult = 1.1 })
    end
    B:Wait(B:W(1.0) * 0.6)
    local r2 = B:Root()
    if r2 then EA.Circle(B.ctx, r2.Position, 8, 0.9, { Mult = 1.3, Sound = "BossSlam" }) end
    B:Wait(B:W(0.9) + 0.2)
end
KITS.Lockwarden = {
    Color = WARD, Move = "Chase", Range = 30, SpeedMul = 0.55, MechMoves = MAJOR_MECH,
    Names = { "THE LOCKWARDEN", "THE LOCKWARDEN: SECURITY BREACH", "THE LOCKWARDEN: TOTAL LOCKDOWN" },
    Moves = {
        { { function(B) WardChainSweep(B, false) end, "CHAIN SWEEP" }, { function(B) WardKeyThrust(B, 1) end, "KEY THRUST" }, { WardTesla, "TESLA COILS" } },
        { { function(B) M.Stomp(B, 14, 2, 0.5) end, "VAULT SLAM" }, { function(B) M.Tide(B, 2, true) end, "SECURITY SWEEP" },
            { function(B) WardChainSweep(B, true) end, "CHAIN SWEEP" }, { function(B) WardKeyThrust(B, 2) end, "TWIN KEYS" } },
        { { function(B) M.Checker(B, 30, 0.95) end, "LASER GRID" }, { function(B) WardKeyThrust(B, 3) end, "KEY STORM" },
            { function(B) M.Pincer(B, 10, 1.0, 0.5) end, "CLOSING DOORS" }, { WardTesla, "TESLA COILS" }, { function(B) M.Stomp(B, 15, 3, 0.45) end, "VAULT SLAM" } },
    },
    Animate = function(B, pivot, now)
        local dt = math.min(0.1, now - (B.animT or now)); B.animT = now
        local moved = (B.pos - (B.animPos or B.pos)).Magnitude / math.max(dt, 0.01); B.animPos = B.pos
        B.walk = (B.walk or 0) + dt * math.clamp(moved / 4, 0, 3)
        B.wheelA = (B.wheelA or 0) + dt * ((B.locking and 3.0) or 0.4)
        Pose(B, "Deco_Wheel", pivot, CFrame.new(0, 0.6, -4.15), CFrame.Angles(0, 0, B.wheelA))
        for _, sx in ipairs({ -1, 1 }) do
            local side = sx < 0 and "L" or "R"
            local sw = math.sin(B.walk * 2.4 + (sx > 0 and math.pi or 0)) * math.rad(18) * math.clamp(moved / 6, 0, 1)
            Pose(B, "Deco_Leg" .. side, pivot, CFrame.new(sx * 2.2, -4.7, 0), CFrame.Angles(sw, 0, 0))
            Pose(B, "Deco_Foot" .. side, pivot, CFrame.new(sx * 2.2, -4.7, 0), CFrame.Angles(sw, 0, 0))
            Pose(B, "Deco_Chain" .. side, pivot, CFrame.new(sx * 5.2, -4.8, -0.3), CFrame.Angles(math.sin(now * 1.7 + sx) * 0.25, 0, math.sin(now * 1.3) * 0.12))
        end
    end,
}
SIG.Lockwarden = function(B)
    local body = Body(B.model)
    if not body then return end
    B.sigOwn = true
    B.baseTaken = 0.3
    B.rawTaken(B.model, 0.3)
    local first = true
    while B:Alive() do
        B:Wait(first and 5 or MECH_BREAK + 2)
        first = false
        if not B:Alive() then return end
        -- four locks round the hull (front and sides: you can always see two), four tiles
        local SLOTS = { -0.6, 0.6, -1.57, 1.57 } -- (angles from its front)
        local locks, junk = {}, {}
        local need = NeedHits(B, 4 + B.phase * 2)
        for i = 1, 4 do
            local a = SLOTS[i]
            local lk = Attach(B, "BreakPart" .. i, Vector3.new(2.2, 2.2, 1.2), CFrame.Angles(0, a, 0) * CFrame.new(0, 2.4, -4.0), LOCK_COLORS[i])
            if lk then table.insert(junk, lk) end
            locks[i] = { Part = lk, A = a, Last = Hits(B, i), Prog = 0, Done = false }
        end
        local function PlaceTiles()
            local spots = SpreadSpots(B, 4, 26, B.pos, 18, 14)
            for i = 1, 4 do
                local lk = locks[i]
                if lk.Disc then lk.Disc:Destroy(); lk.Col:Destroy() end
                local disc, y = FloorDisc(B, spots[i], 7, LOCK_COLORS[i], 0.35, "LockTile")
                lk.Disc, lk.Col, lk.Pos = disc, Column(B, spots[i], y, 6, 30, LOCK_COLORS[i], 0.9), spots[i]
                if lk.Done then lk.Disc.Transparency = 0.85; lk.Col.Transparency = 1 end
            end
        end
        PlaceTiles()
        VFX.Banner("LOCKDOWN", "a lock only breaks while someone stands on ITS colour", WARD)
        Mech(B, true)
        B.locking = true
        local tEnd = os.clock() + (42 - 4 * B.phase) * math.max(1, B.pace)
        local nextShuffle = os.clock() + 9
        local orbitA = 0
        local broken = 0
        while B:Alive() and broken < 4 and os.clock() < tEnd do
            local now = os.clock()
            if B.phase >= 2 and now >= nextShuffle then
                nextShuffle = now + 9
                PlaceTiles()
                VFX.Banner("TILES SHIFTED", "find your colour again", WARD)
            end
            if B.phase >= 3 then orbitA += 0.1 * 0.9 end
            broken = 0
            local status = {}
            for i, lk in ipairs(locks) do
                local h = Hits(B, i)
                local d = h - lk.Last
                lk.Last = h
                if not lk.Done then
                    if d > 0 and AnyoneIn(B, lk.Pos, 7) then lk.Prog += d end
                    if lk.Part and lk.Part.Parent then
                        lk.Part.CFrame = body.CFrame * CFrame.Angles(0, lk.A + orbitA, 0) * CFrame.new(0, 2.4, -4.0)
                        local open = AnyoneIn(B, lk.Pos, 7) ~= nil
                        lk.Part.Transparency = open and 0 or 0.45
                        lk.Disc.Transparency = open and 0.15 or 0.35
                    end
                    if lk.Prog >= need then
                        lk.Done = true
                        VFX.Burst(B.d.Fx, lk.Part and lk.Part.Position or B.pos, LOCK_COLORS[i], 10, "Explosion")
                        if lk.Part then lk.Part:Destroy() end
                        lk.Disc.Transparency = 0.85; lk.Col.Transparency = 1
                    end
                end
                if lk.Done then broken += 1 end
                table.insert(status, lk.Done and "-" or string.format("%s %d%%", LOCK_NAMES[i], math.floor(lk.Prog / need * 100)))
            end
            Info(B, string.format("LOCKDOWN %d/4  •  %ds  •  %s", broken, math.max(0, math.ceil(tEnd - now)), table.concat(status, "  ")))
            B:Wait(0.1)
        end
        B.locking = false
        for _, lk in ipairs(locks) do if lk.Disc then lk.Disc:Destroy(); lk.Col:Destroy() end end
        Kill(junk)
        Mech(B, false)
        if not B:Alive() then return end
        if broken >= 4 then
            Info(B, "VAULT OPEN")
            MajorWindow(B, "VAULT OPEN", "all four locks broken: unload on it", 2, 8, WARD)
        else
            Info(B, "ALARM")
            Wipe(B, "ALARM", "the vault sealed: get to a safe circle", Color3.fromRGB(255, 80, 80))
        end
        Info(B, "")
    end
end

-- ----- THE BROODMOTHER (Fire): CLUTCH -- eggs round the arena; every egg that hatches sends her into a FRENZY
-- (faster, harder, until a clutch is cleared). Clear a whole clutch = SHRIEK (stunned, x2). She burrows, webs the
-- floor and in phase 3 climbs out of reach and rains fire. -----
local BROOD = Color3.fromRGB(255, 120, 60)
local function BroodPounce(B)
    local r = B:Root()
    if not r then return end
    local at = B:Clamp(r.Position)
    local wu = 1.05
    B:Hold(B:W(wu) + 0.6)
    EA.Circle(B.ctx, at, 11, wu, { Mult = 1.6, Sound = "BossSlam", OnStrike = function(c)
        B:Boom(c, 14, "BossSlam")
        EA.Ring(B.ctx, c, 70, 0.05, { Mult = 1.1, Speed = 34 })
    end })
    B:Wait(B:W(wu) * 0.45)
    B.yOff = 6
    B:Dash(at - Unit(at - B.pos) * 3, B:W(wu) * 0.55)
    B.yOff = 0
    B:Wait(0.9)
end
local function BroodSweep(B)
    local r = B:Root()
    if not r then return end
    B:Hold(B:W(0.9) + 0.5)
    local dir = Unit(r.Position - B.pos)
    EA.Cone(B.ctx, B.pos, dir, 34, 62, 0.9, { Mult = 1.4 })
    B:Wait(B:W(0.9) + 0.3)
end
local function BroodBurrow(B)
    -- she sinks; three circles chase you one after another; she bursts up under the last one
    B.yOff = -14
    local last
    for i = 1, 3 do
        if not B:Alive() then break end
        local r = B:Root()
        if not r then break end
        last = B:Clamp(r.Position)
        EA.Circle(B.ctx, last, (i == 3) and 11 or 8, 1.0, { Mult = (i == 3) and 1.6 or 1.2, Sound = (i == 3) and "BossSlam" or nil })
        B:Wait(B:W(1.0) * 0.75)
    end
    if last then
        B:Wait(B:W(1.0) * 0.3)
        B.pos = B:Clamp(Vector3.new(last.X, B.pos.Y, last.Z))
        B:Boom(last, 14, "BossSlam")
    end
    B.yOff = 0
    B:Wait(0.8)
end
local function BroodWeb(B)
    -- lingering burning web patches: one on you, the others where you'd run
    local r = B:Root()
    if not r then return end
    local c = r.Position
    local n = 2 + B.phase
    for i = 1, n do
        local p = (i == 1) and c or B:Spot(c, 14, 30)
        EA.Zone(B.ctx, p, 8, 0.9, 6, { Mult = 0.5 })
    end
    B:Wait(B:W(0.9) + 0.5)
end
local function BroodAscend(B)
    -- she climbs out of reach (no damage taken), carpets the arena, then drops onto you
    B.yOff = 22
    B.rawTaken(B.model, 0)
    VFX.Banner("SHE CLIMBS", "out of reach: survive the rain", BROOD)
    M.Carpet(B, 5, 3, 6, 1.0, 0.45)
    M.Rain(B, 3, 7, 0.9, 0, 0.5)
    B.rawTaken(B.model, B.baseTaken or 0.3)
    B.yOff = 0
    BroodPounce(B)
end
KITS.Broodmother = {
    Color = BROOD, Move = "Orbit", Range = 40, SpeedMul = 0.7, MechMoves = MAJOR_MECH,
    Names = { "THE BROODMOTHER", "THE BROODMOTHER: THE NEST STIRS", "THE BROODMOTHER: QUEEN OF CINDERS" },
    Moves = {
        { { BroodPounce, "POUNCE" }, { function(B) M.Rain(B, 4, 6, 0.9, 0, 0.5) end, "MAGMA SPIT" }, { BroodSweep, "LEG SWEEP" } },
        { { BroodBurrow, "BURROW" }, { BroodWeb, "WEB" }, { BroodPounce, "POUNCE" }, { function(B) M.Clutch(B, 7) end, "BROOD PULSE" } },
        { { BroodAscend, "CEILING RAIN" }, { function(B) M.Roll(B, 3, 5, 44, "Ball", true) end, "EGG SACS" }, { BroodWeb, "WEB" }, { function(B) M.Cage(B, 6, 14, 1.0) end, "COCOON" }, { BroodBurrow, "BURROW" } },
    },
    Animate = function(B, pivot, now)
        local dt = math.min(0.1, now - (B.animT or now)); B.animT = now
        local moved = (B.pos - (B.animPos or B.pos)).Magnitude / math.max(dt, 0.01); B.animPos = B.pos
        local frenzy = 1 + 0.25 * (B.frenzy or 0)
        B.walk = (B.walk or 0) + dt * (1.2 + math.clamp(moved / 3, 0, 5)) * frenzy
        local amt = 0.35 + 0.65 * math.clamp(moved / 8, 0, 1)
        for i = 1, 4 do
            for _, sx in ipairs({ -1, 1 }) do
                local ph = B.walk * 3 + ((i + (sx > 0 and 1 or 0)) % 2) * math.pi
                local lift = math.max(0, math.sin(ph)) * math.rad(22) * amt
                local swing = math.cos(ph) * math.rad(16) * amt
                local z = -3 + (i - 1) * 2.6
                Pose(B, "Deco_Leg" .. i .. (sx < 0 and "L" or "R"), pivot, CFrame.new(sx * 3.4, 1.4, z), CFrame.Angles(0, swing * sx, lift * sx))
            end
        end
        local snap = math.abs(math.sin(now * 4 * frenzy)) * 0.35
        Pose(B, "Deco_MandibleL", pivot, CFrame.new(-1.2, -1.2, -5.7), CFrame.Angles(0, -snap, 0))
        Pose(B, "Deco_MandibleR", pivot, CFrame.new(1.2, -1.2, -5.7), CFrame.Angles(0, snap, 0))
    end,
}
local EGG = Color3.fromRGB(255, 170, 70)
SIG.Broodmother = function(B)
    B.sigOwn = true
    B.baseTaken = 0.3
    B.rawTaken(B.model, 0.3)
    B.frenzy = 0
    local basePace, baseHit = B.pace, B.hitMult or 1
    local function SetFrenzy(n)
        B.frenzy = math.min(6, n)
        B.pace = basePace * (0.88 ^ B.frenzy) * (B.enraged and 0.6 or 1)
        B.hitMult = baseHit * (1.12 ^ B.frenzy) * (B.enraged and 1.6 or 1)
    end
    local first = true
    while B:Alive() do
        B:Wait(first and 6 or MECH_BREAK + 3)
        first = false
        if not B:Alive() then return end
        local count = 3 + B.phase
        local need = NeedHits(B, 3 + B.phase)
        local eggs = {}
        for i, p in ipairs(SpreadSpots(B, count, 22, B.pos, 14, 12)) do
            local y = EA.GroundY(B.ctx, p)
            local o = Part({ Name = "ShieldOrb" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 4.2, 3.4), Color = EGG, CanQuery = true,
                Material = Enum.Material.Neon, CFrame = CFrame.new(p.X, y + 2.2, p.Z) })
            o:SetAttribute("BossOrb", true)
            local shell = Part({ Name = "EggShell", Shape = Enum.PartType.Ball, Size = Vector3.new(3.8, 4.6, 3.8), Color = Color3.fromRGB(60, 30, 24),
                Material = Enum.Material.Basalt, Transparency = 0.35, CFrame = o.CFrame })
            shell.Parent = o
            local link = Instance.new("ObjectValue"); link.Name = "HitModel"; link.Value = B.model; link.Parent = o
            o.Parent = B.d.Fx
            table.insert(eggs, { Part = o, Key = "Orb" .. i, Start = B.model:GetAttribute("Orb" .. i) or 0, Alive = true, Pos = o.Position })
        end
        VFX.Banner("CLUTCH", string.format("pop all %d eggs before they hatch", count), BROOD)
        Mech(B, true)
        local limit = (24 - 2 * B.phase) * math.max(1, B.pace)
        local tEnd = os.clock() + limit
        local left = count
        while B:Alive() and left > 0 and os.clock() < tEnd do
            local now = os.clock()
            left = 0
            local k = 1 - (tEnd - now) / limit -- (eggs swell and pulse faster as they're about to hatch)
            for _, e in ipairs(eggs) do
                if e.Alive then
                    local hits = (B.model:GetAttribute(e.Key) or 0) - e.Start
                    if hits >= need then
                        e.Alive = false
                        VFX.Burst(B.d.Fx, e.Pos, EGG, 9, "Explosion")
                        e.Part:Destroy()
                    else
                        left += 1
                        local s = 1 + k * 0.35 + math.sin(now * (3 + k * 10)) * 0.06 * (1 + k)
                        e.Part.Size = Vector3.new(3.4, 4.2, 3.4) * s * (1 - 0.3 * hits / need)
                        local sh = e.Part:FindFirstChild("EggShell")
                        if sh then sh.Size = e.Part.Size * 1.1; sh.CFrame = e.Part.CFrame end
                    end
                end
            end
            Info(B, string.format("CLUTCH: %d left  •  %ds  •  FRENZY %d", left, math.max(0, math.ceil(tEnd - now)), B.frenzy))
            B:Wait(0.1)
        end
        Mech(B, false)
        if not B:Alive() then
            for _, e in ipairs(eggs) do if e.Part.Parent then e.Part:Destroy() end end
            return
        end
        if left == 0 then
            SetFrenzy(0)
            Info(B, "SHRIEK")
            MajorWindow(B, "SHRIEK", "the clutch is gone: she's stunned", 2, 8, BROOD)
        else
            -- each hatchling bursts where it was and feeds her frenzy
            for _, e in ipairs(eggs) do
                if e.Alive then
                    e.Alive = false
                    EA.Circle(B.ctx, e.Pos, 8, 0.6, { Mult = 1.0 })
                    VFX.Burst(B.d.Fx, e.Pos, BROOD, 10, "Explosion")
                    e.Part:Destroy()
                end
            end
            SetFrenzy(B.frenzy + left)
            VFX.Banner("FRENZY " .. B.frenzy, string.format("%d hatched: she's faster and hits harder", left), Color3.fromRGB(255, 70, 40))
        end
        Info(B, (B.frenzy > 0) and ("FRENZY " .. B.frenzy .. ": clear a clutch to calm her") or "")
    end
end

-- ----- THE DUELIST (Void): RIPOSTE -- it raises a GUARD (a void shell): hits on it don't hurt it, they charge its
-- RIPOSTE (a strike under everyone, stronger per hit). A guard nobody hits = PERFECT READ (x1.75). After a lunge it's
-- OFF BALANCE (x2). Phase 2 its cuts are repeated by afterimages; phase 3 the DEATH DUEL: break its heart sigil in
-- time or be executed. -----
local DUEL = Color3.fromRGB(200, 120, 255)
local function DuelAfter(B, fn, delay)
    if B.phase < 2 then return end
    task.delay(delay or 1.1, function()
        if B:Alive() then
            local c = B.duelCtx
            if not c then c = table.clone(B.ctx); c.Color = Color3.fromRGB(120, 60, 200); c.Columns = false; B.duelCtx = c end
            pcall(fn, c)
        end
    end)
end
local function DuelLunge(B, n)
    for k = 1, n or 1 do
        if not B:Alive() then return end
        local r = B:Root()
        if not r then return end
        local from = B.pos
        local dir = Unit(r.Position - from)
        local to = B:Clamp(r.Position + dir * 14)
        local wu = 0.85
        B:Hold(B:W(wu) + 0.6)
        B.lungeAt = os.clock() + B:W(wu)
        EA.Line(B.ctx, from, to, 6, wu, { Mult = 1.6, Height = 12 })
        DuelAfter(B, function(c) EA.Line(c, from, to, 6, 0.6, { Mult = 1.2, Height = 12 }) end, 1.3)
        B:Wait(B:W(wu))
        B:Dash(to, 0.18)
        B:Wait(0.25)
    end
    -- off balance after the (last) lunge
    -- (not when its guard is due soon: the server allows one damage window every 13 s and PERFECT READ comes first)
    if B:Alive() and not B.guarding and os.clock() + 10 < (B.nextGuardAt or 0) then MajorWindow(B, "OFF BALANCE", "it overcommitted: hit it now", 2, 3, DUEL, true) end
end
local function DuelFlurry(B)
    for k = 1, 3 do
        if not B:Alive() then return end
        local r = B:Root()
        if not r then return end
        local o, dir = B.pos, Unit(r.Position - B.pos)
        B:Hold(0.8)
        EA.Cone(B.ctx, o, dir, 28, 24, 0.55, { Mult = 1.2, Plain = M.PLAIN.Flurry })
        DuelAfter(B, function(c) EA.Cone(c, o, dir, 28, 24, 0.5, { Mult = 0.9 }) end, 1.2)
        B:Wait(B:W(0.55) * 0.8)
    end
    B:Wait(0.5)
end
local function DuelCrescent(B)
    local r = B:Root()
    if not r then return end
    B:Hold(B:W(0.9) + 0.6)
    local o = B.pos
    EA.Ring(B.ctx, o, 60, 0.9, { Mult = 1.2, Speed = 34, StartRadius = 4 })
    EA.Cone(B.ctx, o, Unit(r.Position - o), 40, 40, 0.9, { Mult = 1.3 })
    DuelAfter(B, function(c) EA.Ring(c, o, 60, 0.5, { Mult = 0.9, Speed = 34, StartRadius = 4 }) end, 1.4)
    B:Wait(B:W(0.9) + 0.4)
end
KITS.Duelist = {
    Color = DUEL, Move = "Chase", Range = 20, SpeedMul = 0.95, MechMoves = MAJOR_MECH,
    Names = { "THE DUELIST", "THE DUELIST: AFTERIMAGE", "THE DUELIST: DEATH DUEL" },
    Moves = {
        { { function(B) DuelLunge(B, 1) end, "LUNGE" }, { DuelFlurry, "FLURRY" }, { DuelCrescent, "CRESCENT" } },
        { { DuelFlurry, "FLURRY" }, { function(B) DuelLunge(B, 1) end, "LUNGE" }, { function(B) M.LungeCross(B, 6) end, "BLADE CROSS" }, { DuelCrescent, "CRESCENT" } },
        { { function(B) DuelLunge(B, 2) end, "TWIN LUNGE" }, { DuelFlurry, "FLURRY" }, { function(B) M.Footsteps(B, 8, 5) end, "SHADOW WALTZ" },
            { function(B) M.Riposte(B, 50) end, "EN GARDE" } },
    },
    Animate = function(B, pivot, now)
        local lunging = os.clock() < (B.lungeAt or 0) + 0.3
        local want = (B.guarding and 1) or (lunging and 2) or 0
        B.swordK = B.swordK or 0
        -- 0 = en garde, 1 = blade raised to guard, 2 = drawn back for the lunge
        local rot = (want == 1) and CFrame.Angles(math.rad(55), 0, math.rad(-30)) or (want == 2) and CFrame.Angles(math.rad(-35), math.rad(20), 0)
            or CFrame.Angles(math.sin(now * 2.2) * 0.08, math.sin(now * 1.3) * 0.1, 0)
        Pose(B, "Deco_Sword", pivot, CFrame.new(2.1, 3.0, 0), rot)
        B.shardA = (B.shardA or 0) + 0.1 * (1 + B.phase)
        Pose(B, "Deco_Shard", pivot, CFrame.new(0, 4.2, 2.2), CFrame.Angles(0, 0, math.sin(B.shardA) * 0.3))
        local step = math.sin(now * 5) * math.rad(10)
        Pose(B, "Deco_LegL", pivot, CFrame.new(-0.8, -3.4, 0), CFrame.Angles(step, 0, 0))
        Pose(B, "Deco_LegR", pivot, CFrame.new(0.8, -3.4, 0), CFrame.Angles(-step, 0, 0))
    end,
}
EVADE.Duelist = { Amp = 12, Rate = 2.2, Dodge = 3.0 }
SIG.Duelist = function(B)
    B.sigOwn = true
    B.baseTaken = 1
    local duelAt = nil
    local first = true
    while B:Alive() do
        -- (a guard every ~20 s: room for one OFF BALANCE window after a guard and the guard's own PERFECT READ)
        local gap = first and 7 or 20
        B.nextGuardAt = os.clock() + gap
        B:Wait(gap)
        first = false
        if not B:Alive() then return end
        if B.phase >= 3 and (not duelAt or os.clock() - duelAt > 30) then
            -- DEATH DUEL: rooted, a heart sigil on its chest; break it before the mark fills
            duelAt = os.clock()
            TakeTurn(B)
            B.rooted = true
            local sig = Attach(B, "BreakPart5", Vector3.new(2.4, 2.4, 0.6), CFrame.new(0, 1.4, -1.6), Color3.fromRGB(255, 240, 255))
            local need = NeedHits(B, 14)
            local base = Hits(B, 5)
            VFX.Banner("DEATH DUEL", "break its heart sigil before the mark fills", DUEL)
            local tEnd = os.clock() + 7 * math.max(1, B.pace)
            while B:Alive() and os.clock() < tEnd and Hits(B, 5) - base < need do
                Info(B, string.format("DEATH DUEL  •  SIGIL %d%%  •  %.1fs", math.floor((Hits(B, 5) - base) / need * 100), math.max(0, tEnd - os.clock())))
                B:Wait(0.1)
            end
            if sig then sig:Destroy() end
            B.rooted = false
            B.active = 0
            if not B:Alive() then return end
            if Hits(B, 5) - base >= need then
                MajorWindow(B, "DISARMED", "you won the duel: finish it", 2, 6, DUEL)
                GiveTurn(B, 1)
            else
                VFX.Banner("EXECUTION", "you lost the duel: reach a safe circle", Color3.fromRGB(255, 80, 120))
                M.ArenaWipe(B, 1, 10, 1.6, true)
                GiveTurn(B, 1.4)
            end
        else
            -- GUARD
            TakeTurn(B)
            B.guarding = true
            B.rooted = true
            local size = B.model:GetExtentsSize() / B.model:GetScale()
            local shell = Attach(B, "BreakPart6", Vector3.one * (math.max(size.X, size.Y) + 3), CFrame.new(0, 0, 0), DUEL, Enum.PartType.Ball)
            if shell then shell.Material = Enum.Material.ForceField; shell.Transparency = 0.25 end
            B.rawTaken(B.model, 0)
            VFX.Banner("GUARD", "stop shooting: every hit powers its riposte", DUEL)
            local base = Hits(B, 6)
            local dur = (3.0 + 0.5 * B.phase) * math.max(1, B.pace)
            local tEnd = os.clock() + dur
            while B:Alive() and os.clock() < tEnd do
                if shell then shell.CFrame = Body(B.model).CFrame end
                Info(B, string.format("GUARD  •  RIPOSTE POWER %d  •  %.1fs", Hits(B, 6) - base, math.max(0, tEnd - os.clock())))
                B:Wait(0.05)
            end
            if shell then shell:Destroy() end
            B.guarding = false
            B.rooted = false
            B.rawTaken(B.model, 1)
            B.active = 0
            if not B:Alive() then return end
            local hits = Hits(B, 6) - base
            if hits <= 0 then
                Info(B, "PERFECT READ")
                MajorWindow(B, "PERFECT READ", "you held your fire: it's open", 1.75, 5, DUEL)
                GiveTurn(B, 0.8)
            else
                -- RIPOSTE: a fast strike under every player, stronger per hit landed on the guard
                VFX.Banner("RIPOSTE", string.format("%d hits turned back on you", hits), Color3.fromRGB(255, 80, 160))
                for _, t in ipairs(TargetRoots(B)) do
                    EA.Circle(B.ctx, t.Root.Position, 7, 0.55, { Mult = math.min(3, 0.6 + 0.12 * hits), Sound = "BossSlam" })
                end
                B:Wait(0.8)
                GiveTurn(B, 1.2)
            end
        end
        Info(B, "")
    end
end

-- ----- THE FORTUNE ENGINE (Cyber): HOUSE RULES -- it pulls its lever, the reels spin, and a RULE takes over the arena:
-- JACKPOT (shoot the coins), GOLD TILES (only gold is safe; survive = payout), HIGH ROLLER (ride the moving pad),
-- DOUBLE OR NOTHING (both sides hit twice as hard), BUST (phase 2+: three safe seats). -----
local FORTUNE = Color3.fromRGB(255, 210, 60)
local function FortuneSlots(B, crossToo)
    M.Lanes(B, 3, 8, 10, 1.0, crossToo)
end
local function FortunePayout(B)
    local r = B:Root()
    if not r then return end
    B:Hold(B:W(0.9) * 2 + 0.6)
    local dir = Unit(r.Position - B.pos)
    for k = 0, 1 do
        local d = CFrame.Angles(0, math.rad((k == 0) and -22 or 22), 0):VectorToWorldSpace(dir)
        EA.Cone(B.ctx, B.pos, d, 60, 30, 0.9, { Mult = 1.3 })
        B:Wait(B:W(0.9) * 0.7)
    end
    B:Wait(B:W(0.9) * 0.5)
end
KITS.FortuneEngine = {
    Color = FORTUNE, Move = "Orbit", Range = 38, SpeedMul = 0.5, MechMoves = MAJOR_MECH,
    Names = { "THE FORTUNE ENGINE", "THE FORTUNE ENGINE: HIGH STAKES", "THE FORTUNE ENGINE: ALL IN" },
    Moves = {
        { { function(B) M.Coins(B) end, "COIN TOSS" }, { function(B) FortuneSlots(B, false) end, "THREE OF A KIND" }, { FortunePayout, "PAYOUT" } },
        { { function(B) M.Roulette(B, 70) end, "ROULETTE" }, { function(B) M.Coins(B) end, "COIN TOSS" },
            { function(B) M.Sweep(B, 2, 3.5) end, "LEVER SWEEP" }, { function(B) FortuneSlots(B, true) end, "JACKPOT LINES" } },
        { { function(B) M.Reels(B) end, "SPINNING REELS" }, { function(B) M.Quadrants(B, 70, 3, 0.95) end, "RED OR BLACK" },
            { FortunePayout, "PAYOUT" }, { function(B) M.Jackpot(B) end, "JACKPOT" } },
    },
    Animate = function(B, pivot, now)
        local dt = math.min(0.1, now - (B.animT or now)); B.animT = now
        local spin = now < (B.spinUntil or 0)
        for i = 1, 3 do
            local stopAt = (B.spinUntil or 0) - (3 - i) * 0.35 -- (the reels stop left to right)
            B["reel" .. i] = (B["reel" .. i] or 0) + dt * ((now < stopAt) and 18 or 0)
            Pose(B, "Deco_Reel" .. i, pivot, CFrame.new((i - 2) * 2.9, 1.4, -1.6), CFrame.Angles(B["reel" .. i], 0, 0))
        end
        local pull = math.clamp(1 - (now - (B.leverAt or -9)) / 0.6, 0, 1)
        Pose(B, "Deco_Lever", pivot, CFrame.new(6, 0.5, 0.5), CFrame.Angles(math.rad(70) * math.sin(pull * math.pi), 0, 0))
        -- marquee bulbs chase (faster while spinning)
        if not B.bulbs then
            B.bulbs = {}
            for _, p in ipairs(B.model:GetChildren()) do if p.Name == "Deco_Bulb" then table.insert(B.bulbs, p) end end
            table.sort(B.bulbs, function(a, b) return a.Position.X < b.Position.X end)
        end
        local step = math.floor(now * (spin and 12 or 3))
        if step ~= B.bulbStep then
            B.bulbStep = step
            for k, p in ipairs(B.bulbs) do p.Color = ((k + step) % 3 == 0) and Color3.fromRGB(255, 60, 70) or Color3.fromRGB(255, 240, 170) end
        end
    end,
}
local RULES = { "JACKPOT", "GOLD TILES", "HIGH ROLLER", "DOUBLE OR NOTHING", "BUST" }
local function FortuneJackpot(B)
    local count = 4 + math.min(2, B.phase - 1)
    local need = NeedHits(B, 3 + B.phase)
    local coins = {}
    local b = B.d.Bounds
    local cx, cz = (b.MinX + b.MaxX) / 2, (b.MinZ + b.MaxZ) / 2
    local rad = math.min(b.MaxX - b.MinX, b.MaxZ - b.MinZ) * 0.34
    local a0 = math.random() * math.pi * 2
    for i = 1, count do
        local a = a0 + (i - 1) * math.pi * 2 / count
        local p = Vector3.new(cx + math.cos(a) * rad, B.d.SpawnPos.Y + 5 + (i % 2) * 7, cz + math.sin(a) * rad)
        local o = Part({ Name = "ShieldOrb" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 4.4, 4.4), Color = FORTUNE, CanQuery = true,
            Material = Enum.Material.Neon, CFrame = CFrame.new(p) })
        o:SetAttribute("BossOrb", true)
        local link = Instance.new("ObjectValue"); link.Name = "HitModel"; link.Value = B.model; link.Parent = o
        o.Parent = B.d.Fx
        table.insert(coins, { Part = o, Key = "Orb" .. i, Start = B.model:GetAttribute("Orb" .. i) or 0, Alive = true, Base = p, Ph = math.random() * 6 })
    end
    Mech(B, true)
    local tEnd = os.clock() + 20 * math.max(1, B.pace)
    local left = count
    while B:Alive() and left > 0 and os.clock() < tEnd do
        local now = os.clock()
        left = 0
        for _, c in ipairs(coins) do
            if c.Alive then
                if (B.model:GetAttribute(c.Key) or 0) - c.Start >= need then
                    c.Alive = false
                    VFX.Burst(B.d.Fx, c.Part.Position, FORTUNE, 9, "Explosion")
                    c.Part:Destroy()
                else
                    left += 1
                    -- coins spin (and bob on the client; server-run bosses keep them still)
                    local cf = CFrame.new(c.Base + (RunService:IsServer() and Vector3.zero or Vector3.new(0, math.sin(now * 1.5 + c.Ph) * 1.4, 0)))
                    c.Part.CFrame = cf * CFrame.Angles(0, now * 2 + c.Ph, 0)
                end
            end
        end
        Info(B, string.format("JACKPOT: %d coins  •  %ds", left, math.max(0, math.ceil(tEnd - now))))
        B:Wait(RunService:IsServer() and 0.1 or 0.03)
    end
    Mech(B, false)
    for _, c in ipairs(coins) do if c.Part.Parent then c.Part:Destroy() end end
    if not B:Alive() then return end
    if left == 0 then
        MajorWindow(B, "JACKPOT", "the machine pays out: hit it", 2, 8, FORTUNE)
    else
        TakeTurn(B)
        VFX.Banner("THE HOUSE WINS", "coins missed: it collects", Color3.fromRGB(255, 80, 80))
        M.Carpet(B, 6, 3, 6, 1.0, 0.4)
        GiveTurn(B, 1.2)
    end
end
local function FortuneGoldTiles(B)
    TakeTurn(B)
    VFX.Banner("GOLD TILES", "only the gold is safe: three rounds", FORTUNE)
    for w = 1, 3 do
        if not B:Alive() then break end
        local r = B:Root()
        if not r then break end
        local safe = {}
        for _, p in ipairs(SpreadSpots(B, 4 - math.min(2, B.phase - 1), 24, nil, 0, 14)) do
            table.insert(safe, { Pos = p, R = 9 })
        end
        Info(B, string.format("GOLD TILES  •  ROUND %d/3", w))
        EA.Arena(B.ctx, B.d.Bounds, safe, math.max(2.2 / math.max(0.1, B.ctx.Windup), 2.0), { Mult = 1.6 })
        B:Wait(math.max(2.2, B:W(2.0)) + 0.6)
    end
    GiveTurn(B, 0.6)
    if B:Alive() then MajorWindow(B, "PAYOUT", "you beat the table: hit it", 1.5, 6, FORTUNE) end
end
local function FortuneHighRoller(B)
    local spots = SpreadSpots(B, 4, 30, nil, 0, 16)
    local disc, y = FloorDisc(B, spots[1], 8, FORTUNE, 0.25, "RollerPad")
    local col = Column(B, spots[1], y, 7, 30, FORTUNE, 0.9)
    local pos = spots[1]
    local seg, segT = 1, 0
    local need = 6
    local stood = 0
    Mech(B, true)
    local tEnd = os.clock() + 22 * math.max(1, B.pace)
    local last = os.clock()
    while B:Alive() and os.clock() < tEnd and stood < need do
        local now = os.clock()
        local dt = now - last
        last = now
        -- the pad glides from spot to spot (faster each phase)
        segT += dt * (0.12 + 0.03 * B.phase)
        if segT >= 1 then segT = 0; seg = (seg % #spots) + 1 end
        local a, b2 = spots[seg], spots[(seg % #spots) + 1]
        pos = a:Lerp(b2, segT)
        disc.CFrame = CFrame.new(pos.X, y + 0.14, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
        col.CFrame = CFrame.new(pos.X, y + 15, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
        if AnyoneIn(B, pos, 8) then stood += dt end
        Info(B, string.format("HIGH ROLLER: ride the pad %d%%  •  %ds", math.floor(stood / need * 100), math.max(0, math.ceil(tEnd - now))))
        B:Wait(RunService:IsServer() and 0.1 or 0.03)
    end
    Mech(B, false)
    disc:Destroy(); col:Destroy()
    if B:Alive() and stood >= need then MajorWindow(B, "HIGH ROLLER", "you rode it out: big payout", 2, 8, FORTUNE) end
end
local function FortuneDouble(B)
    if not CanWindow(B) then return end
    B.winAt = os.clock()
    VFX.Banner("DOUBLE OR NOTHING", "for 8 seconds you both hit twice as hard", FORTUNE)
    B.rawTaken(B.model, 2)
    B.hitMult = (B.hitMult or 1) * 2
    local tEnd = os.clock() + 8
    while B:Alive() and os.clock() < tEnd do
        Info(B, string.format("DOUBLE OR NOTHING  •  %ds", math.ceil(tEnd - os.clock())))
        B:Wait(0.1)
    end
    B.hitMult = (B.hitMult or 2) / 2
    B.rawTaken(B.model, B.baseTaken or 0.3)
end
local function FortuneBust(B)
    TakeTurn(B)
    VFX.Banner("BUST", "the house takes everything: grab one of three seats", Color3.fromRGB(255, 80, 80))
    Info(B, "BUST")
    M.ArenaWipe(B, 1, 10, 1.7, true)
    GiveTurn(B, 1.4)
end
SIG.FortuneEngine = function(B)
    B.sigOwn = true
    B.baseTaken = 0.3
    B.rawTaken(B.model, 0.3)
    local lastRule = nil
    local first = true
    while B:Alive() do
        B:Wait(first and 6 or MECH_BREAK)
        first = false
        if not B:Alive() then return end
        -- pull the lever, spin, pick a rule (never the same twice running; BUST from phase 2, rarer)
        B.leverAt = os.clock()
        B.spinUntil = os.clock() + 2.4
        Info(B, "THE REELS ARE SPINNING...")
        B:Wait(2.4)
        local pool = {}
        for _, rname in ipairs(RULES) do
            if rname ~= lastRule and (rname ~= "BUST" or B.phase >= 2) then
                table.insert(pool, rname)
                if rname ~= "BUST" then table.insert(pool, rname) end -- (BUST counts once, the rest twice)
            end
        end
        local rule = pool[math.random(1, #pool)]
        lastRule = rule
        VFX.Banner("HOUSE RULE: " .. rule, "", FORTUNE)
        if rule == "JACKPOT" then FortuneJackpot(B)
        elseif rule == "GOLD TILES" then FortuneGoldTiles(B)
        elseif rule == "HIGH ROLLER" then FortuneHighRoller(B)
        elseif rule == "DOUBLE OR NOTHING" then FortuneDouble(B)
        else FortuneBust(B) end
        if B:Alive() then Info(B, "") end
    end
end

-- ==================== THE ORIGINAL TRIAL BOSSES, REWORKED (0.53) ====================
-- Owner: "Cover old bosses and such too ... improving their boss fights as a whole just like the new ones". Each old trial
-- boss keeps its identity mechanic (look away / metronome / echoes / brands) and gains a SIGNATURE round from phase 2 on:
-- a team task with a damage window when it's done and an arena wipe when it isn't, plus the enrage timer (cfg.EnrageAt).
local SIG_PHASE = 2 -- (the rounds start in phase 2: phase 1 teaches the identity mechanic alone)
local function WaitPhase(B, ph)
    while B:Alive() and B.phase < ph do B:Wait(0.5) end
    return B:Alive()
end

-- ARCHON: FALLEN WINGS -- two golden wing-roots light up on its shoulders; break both before the light gathers
SIG.Archon = function(B)
    if not WaitPhase(B, SIG_PHASE) then return end
    while B:Alive() do
        B:Wait(MECH_BREAK + 4)
        if not B:Alive() then return end
        local roots = {}
        for i, sx in ipairs({ -1, 1 }) do
            local p = Attach(B, "BreakPart" .. i, Vector3.new(1.6, 1.6, 1.6), CFrame.new(sx * 3.4, 3.0, -0.6), Color3.fromRGB(255, 220, 120), Enum.PartType.Ball)
            roots[i] = { Part = p, Base = Hits(B, i) }
        end
        local need = NeedHits(B, 6 + 2 * B.phase)
        VFX.Banner("FALLEN WINGS", "break both golden wing-roots before the light gathers", Color3.fromRGB(255, 220, 120))
        Mech(B, true)
        local tEnd = os.clock() + (16 - B.phase) * math.max(1, B.pace)
        local done = 0
        while B:Alive() and os.clock() < tEnd do
            done = 0
            for i, r in ipairs(roots) do
                if Hits(B, i) - r.Base >= need then
                    if r.Part and r.Part.Parent then VFX.Burst(B.d.Fx, r.Part.Position, GOLD, 9, "Explosion"); r.Part:Destroy() end
                    done += 1
                end
            end
            if done >= 2 then break end
            Info(B, string.format("FALLEN WINGS %d/2  •  %ds", done, math.max(0, math.ceil(tEnd - os.clock()))))
            B:Wait(0.1)
        end
        for _, r in ipairs(roots) do if r.Part and r.Part.Parent then r.Part:Destroy() end end
        Mech(B, false)
        if not B:Alive() then return end
        if done >= 2 then
            MajorWindow(B, "FALLEN", "its wings are broken: it falls", 2, 8, GOLD)
        else
            Wipe(B, "DIVINE JUDGEMENT", "the light gathered: get to a safe circle", Color3.fromRGB(255, 240, 200))
        end
        Info(B, "")
    end
end

-- CHRONARCH: CHIMES -- four tiles at the clock's quarters; one lights at a time going round. Stand on it when it chimes,
-- four chimes in a row. A missed chime starts the count again.
SIG.Chronarch = function(B)
    if not WaitPhase(B, SIG_PHASE) then return end
    local b = B.d.Bounds
    local c = Vector3.new((b.MinX + b.MaxX) / 2, B.d.SpawnPos.Y, (b.MinZ + b.MaxZ) / 2)
    local rad = math.min(b.MaxX - b.MinX, b.MaxZ - b.MinZ) * 0.3
    while B:Alive() do
        B:Wait(MECH_BREAK + 3)
        if not B:Alive() then return end
        local tiles, junk = {}, {}
        for k = 0, 3 do
            local a = k * math.pi / 2
            local p = c + Vector3.new(math.sin(a), 0, -math.cos(a)) * rad
            local disc, y = FloorDisc(B, p, 7, Color3.fromRGB(90, 230, 255), 0.7, "ChimeTile")
            local col = Column(B, p, y, 6, 30, Color3.fromRGB(90, 230, 255), 0.97)
            table.insert(junk, disc); table.insert(junk, col)
            tiles[k + 1] = { Pos = p, Disc = disc, Col = col }
        end
        VFX.Banner("CHIMES", "stand on each tile as it rings: four in a row", Color3.fromRGB(90, 230, 255))
        Mech(B, true)
        local streak, idx = 0, math.random(1, 4)
        local tEnd = os.clock() + 34 * math.max(1, B.pace)
        local ring = math.max(1.6, 2.6 - 0.3 * B.phase) * math.max(1, B.pace) -- (seconds per chime)
        while B:Alive() and streak < 4 and os.clock() < tEnd do
            local t = tiles[idx]
            for _, tt in ipairs(tiles) do tt.Disc.Transparency = (tt == t) and 0.15 or 0.8; tt.Col.Transparency = (tt == t) and 0.82 or 0.97 end
            local chimeAt = os.clock() + ring
            while B:Alive() and os.clock() < chimeAt do
                Info(B, string.format("CHIMES %d/4  •  %.1fs", streak, chimeAt - os.clock()))
                B:Wait(0.1)
            end
            if AnyoneIn(B, t.Pos, 7) then
                streak += 1
                VFX.Burst(B.d.Fx, t.Pos + Vector3.new(0, 2, 0), Color3.fromRGB(90, 230, 255), 8, nil)
            else
                streak = 0
            end
            idx = idx % 4 + 1
        end
        Kill(junk)
        Mech(B, false)
        if not B:Alive() then return end
        if streak >= 4 then
            MajorWindow(B, "TIME STOP", "the clock is stopped: hit it", 2, 8, Color3.fromRGB(90, 230, 255))
        else
            Wipe(B, "MIDNIGHT", "the hour struck: get to a safe circle", Color3.fromRGB(90, 230, 255))
        end
        Info(B, "")
    end
end

-- ECHO WARDEN: MIRROR SEQUENCE -- four mirrors round the arena flash a sequence; shoot them in that order. A wrong mirror
-- shows the sequence again (and echoes a strike at you).
SIG.EchoWarden = function(B)
    if not WaitPhase(B, SIG_PHASE) then return end
    local PURPLE = Color3.fromRGB(180, 100, 255)
    while B:Alive() do
        B:Wait(MECH_BREAK + 3)
        if not B:Alive() then return end
        local mirrors = {}
        for i, p in ipairs(SpreadSpots(B, 4, 30, B.pos, 18, 16)) do
            local o = Part({ Name = "ShieldOrb" .. i, Size = Vector3.new(3.2, 4.4, 0.4), Color = Color3.fromRGB(220, 200, 255), CanQuery = true,
                Material = Enum.Material.Glass, Reflectance = 0.5, Transparency = 0.1, CFrame = CFrame.lookAt(p + Vector3.new(0, 6, 0), B.pos + Vector3.new(0, 6, 0)) })
            o:SetAttribute("BossOrb", true)
            local link = Instance.new("ObjectValue"); link.Name = "HitModel"; link.Value = B.model; link.Parent = o
            o.Parent = B.d.Fx
            mirrors[i] = { Part = o, Key = "Orb" .. i, Last = B.model:GetAttribute("Orb" .. i) or 0 }
        end
        local len = 2 + B.phase
        local seq = {}
        for k = 1, len do
            local m
            repeat m = math.random(1, 4) until m ~= seq[k - 1]
            seq[k] = m
        end
        local function Show()
            for _, k in ipairs(seq) do
                if not B:Alive() then return end
                local o = mirrors[k].Part
                o.Material = Enum.Material.Neon; o.Color = PURPLE
                B:Wait(0.7)
                o.Material = Enum.Material.Glass; o.Color = Color3.fromRGB(220, 200, 255)
                B:Wait(0.25)
            end
            for _, mm in ipairs(mirrors) do mm.Last = B.model:GetAttribute(mm.Key) or 0 end -- (hits while watching don't count)
        end
        VFX.Banner("MIRROR SEQUENCE", "watch the mirrors, then shoot them in the same order", PURPLE)
        Mech(B, true)
        Show()
        local pos = 1
        local tEnd = os.clock() + 30 * math.max(1, B.pace)
        while B:Alive() and pos <= len and os.clock() < tEnd do
            for i, mm in ipairs(mirrors) do
                local h = B.model:GetAttribute(mm.Key) or 0
                if h > mm.Last then
                    mm.Last = h
                    if i == seq[pos] then
                        VFX.Burst(B.d.Fx, mm.Part.Position, PURPLE, 6, nil)
                        pos += 1
                    else
                        -- wrong mirror: it echoes a strike at you and plays the sequence again
                        VFX.Banner("WRONG MIRROR", "the sequence starts over", Color3.fromRGB(255, 90, 140))
                        local r = B:Root()
                        if r then EA.Circle(B.ctx, r.Position, 8, 0.8, { Mult = 1.0 }) end
                        pos = 1
                        Show()
                        break
                    end
                end
            end
            Info(B, string.format("MIRRORS %d/%d  •  %ds", pos - 1, len, math.max(0, math.ceil(tEnd - os.clock()))))
            B:Wait(0.05)
        end
        for _, mm in ipairs(mirrors) do if mm.Part.Parent then mm.Part:Destroy() end end
        Mech(B, false)
        if not B:Alive() then return end
        if pos > len then
            MajorWindow(B, "SHATTERED", "its reflection broke: hit it", 2, 8, PURPLE)
        else
            Wipe(B, "ENDLESS ECHO", "too slow: get to a safe circle", PURPLE)
        end
        Info(B, "")
    end
end

-- FORGEHEART: OVERHEAT -- two white-hot vents burst open on its shoulders; break both before the furnace blows
SIG.Forgeheart = function(B)
    if not WaitPhase(B, SIG_PHASE) then return end
    while B:Alive() do
        B:Wait(MECH_BREAK + 5)
        if not B:Alive() then return end
        local vents = {}
        for i, sx in ipairs({ -1, 1 }) do
            local p = Attach(B, "BreakPart" .. i, Vector3.new(1.8, 1.4, 1.8), CFrame.new(sx * 5.4, 5.0, -0.8), Color3.fromRGB(255, 236, 190)) -- (on its pauldrons: it always faces you)
            vents[i] = { Part = p, Base = Hits(B, i) }
        end
        local need = NeedHits(B, 6 + 2 * B.phase)
        VFX.Banner("OVERHEAT", "break both white-hot shoulder vents before it blows", Color3.fromRGB(255, 130, 40))
        Mech(B, true)
        local tEnd = os.clock() + (17 - B.phase) * math.max(1, B.pace)
        local done = 0
        while B:Alive() and os.clock() < tEnd do
            done = 0
            for i, v in ipairs(vents) do
                if Hits(B, i) - v.Base >= need then
                    if v.Part and v.Part.Parent then VFX.Burst(B.d.Fx, v.Part.Position, Color3.fromRGB(255, 130, 40), 9, "Explosion"); v.Part:Destroy() end
                    done += 1
                end
            end
            if done >= 2 then break end
            Info(B, string.format("OVERHEAT %d/2  •  %ds", done, math.max(0, math.ceil(tEnd - os.clock()))))
            B:Wait(0.1)
        end
        for _, v in ipairs(vents) do if v.Part and v.Part.Parent then v.Part:Destroy() end end
        Mech(B, false)
        if not B:Alive() then return end
        if done >= 2 then
            MajorWindow(B, "VENTED", "the furnace is open: hit it", 1.75, 8, Color3.fromRGB(255, 130, 40))
        else
            Wipe(B, "ERUPTION", "it blew: get to a safe circle", Color3.fromRGB(255, 90, 20))
        end
        Info(B, "")
    end
end

-- ==================== NEW BIOME SUPERBOSSES (0.53: NewBiomes) ====================
-- THE SANDMAN (Dreamscape): COUNTING SHEEP -- dream sheep hop across the arena in a line; shoot them before they reach
-- the far side. Three that make it across = DEEP SLEEP (arena wipe); stop the herd = it WAKES with a start (x1.75).
local DREAM = Color3.fromRGB(255, 150, 230)
local function SandmanLullaby(B)
    -- slow rings of sand rolling out (jump them), a circle under you between them
    for k = 1, 2 + (B.phase >= 2 and 1 or 0) do
        if not B:Alive() then return end
        EA.Ring(B.ctx, B.pos, 85, 0.6, { Mult = 1.0, Speed = 26 + k * 3, StartRadius = 4 })
        local r = B:Root()
        if r then EA.Circle(B.ctx, r.Position, 7, 0.9, { Mult = 1.2 }) end
        B:Wait(B:W(0.9) + 0.3)
    end
end
local function SandmanDust(B)
    -- handfuls of dream sand thrown along your path: a row of circles from it to you and past
    local r = B:Root()
    if not r then return end
    local dir = Unit(r.Position - B.pos)
    for i = 1, 6 do
        local at = B:Clamp(B.pos + dir * (i * 9))
        task.delay(i * 0.09, function() if B:Alive() then EA.Circle(B.ctx, at, 5, 0.8, { Mult = 1.1 }) end end)
    end
    B:Wait(B:W(0.8) + 0.8)
end
SUPER.Dream = {
    Color = DREAM, Move = "Orbit", Range = 32, SpeedMul = 0.85, Recover = { 1.9, 1.6, 1.3 },
    Names = { "THE SANDMAN", "THE SANDMAN: NIGHTFALL", "THE SANDMAN: ENDLESS SLEEP" },
    Moves = {
        { { SandmanLullaby, "LULLABY" }, { SandmanDust, "DREAM DUST" }, { function(B) M.Rain(B, 6, 6, 0.85, 0, 0.42) end, "FALLING STARS" } },
        { { function(B) M.Orbit(B, 4, 5, 5) end, "DRIFTING DREAMS" }, { SandmanDust, "DREAM DUST" }, { function(B) M.Cage(B, 8, 13, 1.0) end, "NIGHTMARE" }, { SandmanLullaby, "LULLABY" } },
        { { function(B) M.Checker(B, 32, 0.95) end, "DREAM TILES" }, { function(B) M.Roll(B, 3, 5, 55, "Ball", true) end, "SHOOTING STARS" }, { SandmanLullaby, "LULLABY" },
            { function(B) M.ArenaWipe(B, 2, 8, 1.5) end, "ENDLESS SLEEP" } },
    },
    Animate = function(B, pivot, now)
        B.robeT = now
        Pose(B, "Deco_Robe", pivot, CFrame.new(0, -1.2, 0), CFrame.Angles(math.sin(now * 1.4) * 0.06, now * 0.15, math.cos(now * 1.1) * 0.06))
        Pose(B, "Deco_Star", pivot, CFrame.new(0, 4, 0), CFrame.Angles(0, now * (0.4 + 0.25 * B.phase), 0))
    end,
}
EVADE.SuperDream = { Amp = 10, Rate = 1.4, Dodge = 3.6 }
SIG.SuperDream = function(B)
    SigImmune(B)
    local SHEEP = Color3.fromRGB(250, 246, 255)
    local first = true
    while B:Alive() do
        B:Wait(first and 4 or MECH_BREAK)
        first = false
        if not B:Alive() then return end
        local b = B.d.Bounds
        local count = 3 + B.phase
        local need = NeedHits(B, 3 + B.phase)
        -- a herd runs from one side of the arena to the other, hopping, staggered
        local goingEast = math.random() < 0.5
        local x0, x1 = goingEast and (b.MinX + 6) or (b.MaxX - 6), goingEast and (b.MaxX - 6) or (b.MinX + 6)
        local sheep = {}
        for i = 1, count do
            local z = b.MinZ + 14 + (i - 0.5) / count * (b.MaxZ - b.MinZ - 28)
            local o = Part({ Name = "ShieldOrb" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 2.8, 4), Color = SHEEP, CanQuery = true,
                Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(x0, B.d.SpawnPos.Y, z) })
            o:SetAttribute("BossOrb", true)
            local head = Part({ Name = "SheepHead", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.5, Color = Color3.fromRGB(70, 56, 110), CFrame = o.CFrame })
            head.Parent = o
            local link = Instance.new("ObjectValue"); link.Name = "HitModel"; link.Value = B.model; link.Parent = o
            o.Parent = B.d.Fx
            table.insert(sheep, { Part = o, Head = head, Key = "Orb" .. i, Start = B.model:GetAttribute("Orb" .. i) or 0, Z = z, Delay = (i - 1) * 1.4, Alive = true })
        end
        VFX.Banner("COUNTING SHEEP", string.format("shoot the sheep before they cross: %d across and everyone sleeps", 3), DREAM)
        Mech(B, true)
        local run = (11 - B.phase) * math.max(1, B.pace) -- (seconds for one sheep to cross)
        local t0 = os.clock()
        local crossed, left = 0, count
        while B:Alive() and left > 0 do
            local now = os.clock() - t0
            left = 0
            for _, sh in ipairs(sheep) do
                if sh.Alive then
                    if (B.model:GetAttribute(sh.Key) or 0) - sh.Start >= need then
                        sh.Alive = false
                        VFX.Burst(B.d.Fx, sh.Part.Position, SHEEP, 8, nil)
                        sh.Part:Destroy()
                    else
                        local k = math.clamp((now - sh.Delay) / run, 0, 1)
                        if k >= 1 then
                            sh.Alive = false
                            crossed += 1
                            VFX.Burst(B.d.Fx, sh.Part.Position, DREAM, 10, nil)
                            sh.Part:Destroy()
                        else
                            left += 1
                            local hop = math.abs(math.sin(now * 5 + sh.Z)) * 3.5
                            local x = x0 + (x1 - x0) * k
                            local y = EA.GroundY(B.ctx, Vector3.new(x, B.d.SpawnPos.Y, sh.Z)) + 2 + hop
                            local cf = CFrame.lookAt(Vector3.new(x, y, sh.Z), Vector3.new(x1, y, sh.Z))
                            sh.Part.CFrame = cf
                            sh.Head.CFrame = cf * CFrame.new(0, 0.6, -2.2)
                        end
                    end
                end
            end
            Info(B, string.format("COUNTING SHEEP  •  %d left  •  %d/3 crossed", left, crossed))
            if crossed >= 3 then break end
            B:Wait(RunService:IsServer() and 0.1 or 0.03)
        end
        for _, sh in ipairs(sheep) do if sh.Part.Parent then sh.Part:Destroy() end end
        Mech(B, false)
        if not B:Alive() then return end
        if crossed >= 3 then
            Wipe(B, "DEEP SLEEP", "too many sheep got across: get to a safe circle", DREAM)
        else
            MajorWindow(B, "WIDE AWAKE", "the herd is stopped: it woke with a start", 1.75, 8, DREAM)
        end
        Info(B, "")
    end
end

-- HIGHWAY KING (Neon Flats): NITRO LAPS -- it drives a lap of the arena, dropping a nitro canister at each corner; shoot
-- every canister before the lap ends and they blow up under it (WRECKED, x2). Miss one and it BURNS OUT round the
-- whole arena (three safe circles).
local FLATS = Color3.fromRGB(255, 120, 60)
local function KingRam(B)
    -- revs, then rams along a marked lane at you (and a second lane in phase 2+)
    for k = 1, (B.phase >= 2) and 2 or 1 do
        if not B:Alive() then return end
        local r = B:Root()
        if not r then return end
        local dir = Unit(r.Position - B.pos)
        local to = B:Clamp(r.Position + dir * 16)
        B:Hold(B:W(0.9) + 0.6)
        EA.Line(B.ctx, B.pos, to, 9, 0.9, { Mult = 1.6, Height = 12 })
        B:Wait(B:W(0.9))
        B:Dash(to, 0.3)
        B:Boom(to, 12, "BossSlam")
        B:Wait(0.4)
    end
end
local function KingBurnout(B)
    -- spins its wheels in place: a burning ring round it, smoke rings rolling out
    B:Hold(B:W(1.0) + 1.2)
    EA.Circle(B.ctx, B.pos, 14, 1.0, { Mult = 1.4, Sound = "BossSlam" })
    B:Wait(B:W(1.0))
    for i = 1, 2 do
        EA.Ring(B.ctx, B.pos, 80, 0.1, { Mult = 1.0, Speed = 34 + i * 4 })
        B:Wait(0.45)
    end
end
local function KingHeadlights(B)
    -- high beams: two wide cones swept across the floor
    local r = B:Root()
    if not r then return end
    local dir = Unit(r.Position - B.pos)
    B:Hold(B:W(0.9) * 2 + 0.8)
    for k, a in ipairs({ -20, 20 }) do
        local d = CFrame.Angles(0, math.rad(a), 0):VectorToWorldSpace(dir)
        task.delay((k - 1) * B:W(0.6), function() if B:Alive() then EA.Cone(B.ctx, B.pos, d, 70, 22, 0.9, { Mult = 1.3 }) end end)
    end
    B:Wait(B:W(0.9) * 1.8)
end
SUPER.Flats = {
    Color = FLATS, Move = "Chase", Range = 28, SpeedMul = 0.95, Recover = { 1.9, 1.6, 1.3 },
    Names = { "HIGHWAY KING", "HIGHWAY KING: REDLINE", "HIGHWAY KING: LAST RIDE" },
    Moves = {
        { { KingRam, "RAM" }, { KingHeadlights, "HIGH BEAMS" }, { function(B) M.Rain(B, 5, 6, 0.85, 0, 0.45) end, "SPARE PARTS" } },
        { { KingBurnout, "BURNOUT" }, { KingRam, "DOUBLE RAM" }, { function(B) M.Lanes(B, 4, 7, 8, 0.85) end, "TRAFFIC" }, { KingHeadlights, "HIGH BEAMS" } },
        { { function(B) M.Footsteps(B, 8, 6) end, "SKID MARKS" }, { KingRam, "DOUBLE RAM" }, { function(B) M.Roll(B, 3, 6, 58, "Wheel", true) end, "ONCOMING TRAFFIC" },
            { KingBurnout, "BURNOUT" } },
    },
    Animate = function(B, pivot, now)
        local dt = math.min(0.1, now - (B.animT or now)); B.animT = now
        local moved = (B.pos - (B.animPos or B.pos)).Magnitude / math.max(dt, 0.01); B.animPos = B.pos
        B.wheelA = (B.wheelA or 0) + dt * (1 + moved * 0.5)
        for _, sx in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                -- (each wheel about its own axle; the name holds its hub and spoke too)
                Pose(B, "Deco_Wheel" .. (sx < 0 and "L" or "R") .. (sz < 0 and "F" or "B"), pivot, CFrame.new(sx * 6.4, -2.6, sz * 3.4), CFrame.Angles(B.wheelA, 0, 0))
            end
        end
        Pose(B, "Deco_Blower", pivot, CFrame.new(0, 5.2, -3.4), CFrame.Angles(now * 9, 0, 0))
    end,
}
EVADE.SuperFlats = { Amp = 9, Rate = 1.2, Dodge = 4.0 }
SIG.SuperFlats = function(B)
    SigImmune(B)
    local NITRO = Color3.fromRGB(80, 230, 255)
    local first = true
    while B:Alive() do
        B:Wait(first and 4 or MECH_BREAK)
        first = false
        if not B:Alive() then return end
        local b = B.d.Bounds
        local m = 18
        local corners = { Vector3.new(b.MinX + m, B.pos.Y, b.MinZ + m), Vector3.new(b.MaxX - m, B.pos.Y, b.MinZ + m), Vector3.new(b.MaxX - m, B.pos.Y, b.MaxZ - m), Vector3.new(b.MinX + m, B.pos.Y, b.MaxZ - m) }
        local need = NeedHits(B, 3 + B.phase)
        TakeTurn(B)
        VFX.Banner("NITRO LAPS", "shoot every nitro canister before it finishes the lap", NITRO)
        Mech(B, true)
        local cans = {}
        local start = 1
        local best = math.huge
        for i, c in ipairs(corners) do local d = (Flat(c - B.pos)).Magnitude if d < best then best, start = d, i end end
        local lapTime = (9 - B.phase) * math.max(1, B.pace)
        -- the lap: corner to corner, a canister dropped at each
        for k = 0, 4 do
            if not B:Alive() then break end
            local c = corners[((start - 1 + k) % 4) + 1]
            B:Dash(c, lapTime / 5)
            if k < 4 then
                local i = #cans + 1
                local y = EA.GroundY(B.ctx, c)
                local o = Part({ Name = "ShieldOrb" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 1.8, 1.8), Color = NITRO, CanQuery = true,
                    Material = Enum.Material.Neon, CFrame = CFrame.new(c.X, y + 1.2, c.Z) * CFrame.Angles(0, 0, math.rad(90)) })
                o:SetAttribute("BossOrb", true)
                local link = Instance.new("ObjectValue"); link.Name = "HitModel"; link.Value = B.model; link.Parent = o
                o.Parent = B.d.Fx
                table.insert(cans, { Part = o, Key = "Orb" .. i, Start = B.model:GetAttribute("Orb" .. i) or 0, Alive = true })
            end
            local left = 0
            for _, cn in ipairs(cans) do
                if cn.Alive and (B.model:GetAttribute(cn.Key) or 0) - cn.Start >= need then
                    cn.Alive = false
                    VFX.Burst(B.d.Fx, cn.Part.Position, NITRO, 10, "Explosion")
                    cn.Part:Destroy()
                end
                if cn.Alive then left += 1 end
            end
            Info(B, string.format("NITRO LAPS  •  %d/%d canisters standing", left, #cans))
        end
        -- a beat for the last canister
        local tEnd = os.clock() + 1.5
        local left = 0
        while B:Alive() and os.clock() < tEnd do
            left = 0
            for _, cn in ipairs(cans) do
                if cn.Alive and (B.model:GetAttribute(cn.Key) or 0) - cn.Start >= need then
                    cn.Alive = false
                    VFX.Burst(B.d.Fx, cn.Part.Position, NITRO, 10, "Explosion")
                    cn.Part:Destroy()
                end
                if cn.Alive then left += 1 end
            end
            Info(B, string.format("NITRO LAPS  •  %d/%d canisters standing", left, #cans))
            if left == 0 then break end
            B:Wait(0.1)
        end
        for _, cn in ipairs(cans) do if cn.Part.Parent then cn.Part:Destroy() end end
        Mech(B, false)
        B.active = 0
        if not B:Alive() then return end
        if left == 0 then
            MajorWindow(B, "WRECKED", "the nitro blew under it: hit it", 2, 8, FLATS)
            GiveTurn(B, 1)
        else
            VFX.Banner("BURNOUT", "it floors it round the arena: reach a safe circle", Color3.fromRGB(255, 90, 60))
            M.ArenaWipe(B, 1, 10, 1.6, true)
            GiveTurn(B, 1.4)
        end
        Info(B, "")
    end
end

local ORB_KINDS = { Goliath = true, Phantom = true, Sentinel = true, Ravager = true, Hexcaller = true, Titan = true, SuperBoss = true }
local ORB_TIME = 26 -- seconds before un-broken orbs blast and reform
local STAGGER_TIME, STAGGER_MULT = 6, 1.75
local function ShieldOrbs(B)
    local model, kit = B.model, B.kit
    local body = Body(model)
    if not body then return end
    local mini = MINIBOSS_KINDS[B.kind] == true
    local count = (B.phase >= 3 and 4 or 3) - (mini and 1 or 0) + (B.config.Raid and 2 or 0) -- (raid boss: 5 / 6 orbs)
    local players = math.max(1, #(B.d.Targets and B.d.Targets() or {}))
    local need = (4 + B.phase * 2 + (B.kind == "SuperBoss" and 4 or 0)) * (1 + 0.5 * (players - 1)) -- (hits per orb)
    need = math.ceil(need)
    B.shielded = true
    Mech(B, true)
    B.rawTaken(model, M.AIM_GUARD) -- (0.99u: raid shield orbs guard (half damage) like an aim round, no longer immune)
    B:Title(B.kit.Names[B.phase] .. "   >>  FIREWALL: SHOOT THE NODES", Color3.fromRGB(120, 200, 255))
    VFX.Banner("FIREWALL UP", string.format("BREAK THE %d NODES", count), Color3.fromRGB(120, 200, 255))
    Sound("BossRoar", body)
    -- a translucent bubble round the boss while it holds
    local size = model:GetExtentsSize()
    local bubble = Part({ Name = "ShieldBubble", Shape = Enum.PartType.Ball, Size = Vector3.one * (math.max(size.X, size.Y, size.Z) + 4),
        Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.ForceField, Transparency = 0.3, CFrame = body.CFrame })
    bubble.Parent = B.d.Fx
    local b = B.d.Bounds
    local cx = b and (b.MinX + b.MaxX) / 2 or B.pos.X
    local cz = b and (b.MinZ + b.MaxZ) / 2 or B.pos.Z
    local rad = b and math.min(b.MaxX - b.MinX, b.MaxZ - b.MinZ) * 0.36 or 50
    local orbs = {}
    local function Spawn()
        for _, o in ipairs(orbs) do if o.Part.Parent then o.Part:Destroy() end end
        table.clear(orbs)
        local a0 = math.random() * math.pi * 2
        for i = 1, count do
            local a = a0 + (i - 1) * math.pi * 2 / count
            local r = rad * (0.75 + math.random() * 0.35)
            local base = Vector3.new(cx + math.cos(a) * r, B.d.SpawnPos.Y + 4 + (i % 2) * 10 + math.random() * 6, cz + math.sin(a) * r)
            local o = Part({ Name = "ShieldOrb" .. i, Shape = Enum.PartType.Ball, Size = Vector3.one * 4.2, Color = Color3.fromRGB(150, 220, 255),
                CanQuery = true, CFrame = CFrame.new(base) })
            o:SetAttribute("BossOrb", true)
            local core = Part({ Name = "OrbCore", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = Color3.new(1, 1, 1), CFrame = o.CFrame })
            core.Parent = o
            local a1 = Instance.new("Attachment"); a1.Parent = o
            local a2 = Instance.new("Attachment"); a2.Parent = body
            local beam = Instance.new("Beam")
            beam.Attachment0, beam.Attachment1 = a1, a2
            beam.Width0, beam.Width1 = 0.6, 1.2; beam.FaceCamera = true; beam.LightEmission = 1
            beam.Color = ColorSequence.new(Color3.fromRGB(150, 220, 255)); beam.Transparency = NumberSequence.new(0.35)
            beam.Texture = SPARK; beam.TextureSpeed = 1.5; beam.Parent = o
            -- (NOT inside the boss model: every PivotTo of the boss dragged the orbs along and they snapped back -- "the
            -- orbs bug around a lot". A HitModel link routes hits on the orb to the boss instead.)
            local link = Instance.new("ObjectValue"); link.Name = "HitModel"; link.Value = model; link.Parent = o
            o.Parent = B.d.Fx
            table.insert(orbs, { Part = o, Base = base, Key = "Orb" .. i, Start = model:GetAttribute("Orb" .. i) or 0, Alive = true, Phase = math.random() * 6 })
        end
    end
    Spawn()
    local t0 = os.clock()
    local lastAnim = 0
    while B:Alive() do
        local now = os.clock()
        local left = 0
        for _, o in ipairs(orbs) do
            if o.Alive then
                local hits = (model:GetAttribute(o.Key) or 0) - o.Start
                if hits >= need then
                    o.Alive = false
                    VFX.Burst(B.d.Fx, o.Part.Position, Color3.fromRGB(150, 220, 255), 9, "Explosion")
                    o.Part:Destroy()
                else
                    left += 1
                    local k = 1 - hits / need
                    o.Part.Size = Vector3.one * (2.6 + 1.6 * k)
                    -- (server-run party bosses keep them still: a 10 Hz bob replicated as a stutter)
                    if not RunService:IsServer() then
                        local cf = CFrame.new(o.Base + Vector3.new(0, math.sin(now * 1.6 + o.Phase) * 1.6, 0))
                        o.Part.CFrame = cf
                        local core = o.Part:FindFirstChild("OrbCore")
                        if core then core.CFrame = cf end
                    end
                end
            end
        end
        if not RunService:IsServer() or now - lastAnim >= 0.1 then lastAnim = now end
        if bubble.Parent then bubble.CFrame = body.CFrame end
        if left == 0 then break end
        B:Title(string.format("%s   >>  FIREWALL: %d NODE%s LEFT  (%ds)", B.kit.Names[B.phase], left, left == 1 and "" or "S", math.max(0, math.ceil(ORB_TIME - (now - t0)))), Color3.fromRGB(120, 200, 255))
        if now - t0 >= ORB_TIME then
            -- too slow: every orb still up blasts where you stand, then they all reform
            VFX.Banner("OVERLOAD", "the orbs fire, move!", Color3.fromRGB(255, 120, 90))
            for _, o in ipairs(orbs) do
                if o.Alive then
                    local r = B:Root()
                    if r then EA.Circle(B.ctx, Flat(r.Position) + Vector3.new(0, B.d.SpawnPos.Y, 0), 12, 1.1, { Mult = 1.2 }) end
                    B:Wait(0.25)
                end
            end
            Spawn()
            t0 = os.clock()
        end
        RunService.Heartbeat:Wait()
    end
    for _, o in ipairs(orbs) do if o.Part.Parent then o.Part:Destroy() end end
    if bubble.Parent then bubble:Destroy() end
    B.shielded = false
    Mech(B, false)
    if not B:Alive() then return end
    -- STAGGER: the damage phase
    VFX.Banner("SHIELD BROKEN", "STAGGERED: DAMAGE IT NOW", Color3.fromRGB(255, 220, 120))
    VFX.ScreenFlash(Color3.fromRGB(150, 220, 255), 0.25)
    VFX.Burst(B.d.Fx, B.pos, Color3.fromRGB(150, 220, 255), 22, "Explosion")
    B.staggered = true
    B.rawTaken(model, STAGGER_MULT)
    B:Hold(STAGGER_TIME)
    B.nextMove = math.max(B.nextMove, os.clock() + STAGGER_TIME + 0.4)
    local glow = Part({ Name = "StaggerGlow", Shape = Enum.PartType.Ball, Size = Vector3.one * 3, Color = Color3.fromRGB(255, 220, 120), Transparency = 0.2, CFrame = body.CFrame })
    glow.Parent = B.d.Fx
    local tEnd = os.clock() + STAGGER_TIME
    while B:Alive() and os.clock() < tEnd do
        B:Title(string.format("%s   >>  STAGGERED  +75%% DAMAGE  (%ds)", B.kit.Names[B.phase], math.ceil(tEnd - os.clock())), Color3.fromRGB(255, 220, 120))
        if glow.Parent then glow.CFrame = body.CFrame end
        B:Wait(0.1)
    end
    if glow.Parent then glow:Destroy() end
    B.staggered = false
    B.rawTaken(model, B.baseTaken or B.wantTaken or 1)
    if B:Alive() then B:Title(B.kit.Names[B.phase]) end
end

local function PhaseChange(B, newPhase)
    B.phase = newPhase
    B.roaring = true
    B:Hold(1.4)
    B.d.SetTakenMult(B.model, 0.15) -- roaring: heavily reduced damage
    B:Title(B.kit.Names[newPhase] .. "  [PHASE " .. newPhase .. "]", Color3.fromRGB(255, 90, 90))
    VFX.Banner("PHASE " .. newPhase .. ((newPhase == 3) and "  •  FINAL" or ""), B.kit.Names[newPhase], (newPhase == 3) and Color3.fromRGB(255, 230, 200) or Color3.fromRGB(255, 120, 40))
    HeatGlow(B, newPhase)
    local stop = B:Charge(0.9)
    Sound("BossRoar", Body(B.model))
    VFX.ScreenFlash(Color3.fromRGB(255, 30, 30), 0.3)
    VFX.Shake(B.pos, 1.2)
    B:Wait(B:W(0.9))
    stop()
    B:Boom(B.pos, 26, "BossSlam")
    VFX.Shake(B.pos, 2.5)
    for i = 1, newPhase do
        EA.Ring(B.ctx, B.pos, 85, 0.05, { Mult = 1, Speed = 40 + i * 6 })
        B:Wait(0.35)
    end
    B.d.SetTakenMult(B.model, 1)
    -- (0.53: a signature that took over damage-taken mid-roar blocked that reset and left the roar's x0.15 stuck --
    -- put back the signature's own base unless a window is open)
    -- (0.99u: a roar that ends DURING an aim round keeps the round's guard -- it used to drop the boss to its base mid-round)
    if B.sigOwn and not B.staggered then B.rawTaken(B.model, B.shielded and M.AIM_GUARD or (B.baseTaken or 1)) end
    B:Title(B.kit.Names[newPhase])
    B.roaring = false
    B.nextMove = os.clock() + 0.3
    -- (shield orbs are the CYBER superboss's own mechanic -- owner: "I just meant for that to be a reference to have on 1
    -- boss"; a RAID boss of any biome uses them too: a team mechanic)
    -- (SUPERBOSSES v3: the Cyber core has its own moving FIREWALL nodes now; raid bosses keep the shield orbs)
    if B.kind == "SuperBoss" and B.config.Raid then ShieldOrbs(B) end
end

-- ==================== AIM ROUNDS (0.68) ====================
-- Owner: "the boss fights are still incredibly confusing and half of the time dont work, the parts you need to shoot are
-- glitchy, all boss mechanics should be aim focused" (+ "The look away ones are fine"). Every boss now has ONE mechanic,
-- the same everywhere so it's learned once: a TARGET ROUND. The boss shields up (it takes no damage) and lime targets
-- appear round it -- separate parts in d.Fx (never inside the boss model, whose every move dragged them), linked to the
-- boss by HitModel, counted through "Orb<i>" like the old shield orbs (CombatServer: by the gun's pace, so every gun
-- breaks one in about the same time). Break them all before the timer: STAGGERED (x1.75 damage for 6 s). Too slow: the
-- targets fire on you (dodge the circles), and the round ends. Three KovaaK-style patterns, a boss plays them in turn:
--   SWITCH  several still targets at once (target switching)       TRACK  one target gliding round the boss (tracking)
--   FLICK   one target at a time, each popping up somewhere new (flicking)
-- Old signatures (stand on tiles, light wells, rods, guards ...) and the Chronarch's metronome are off; the Archon's
-- look-away move stays (a kit move). Outside a round a superboss / major boss takes 50% (their health was set for long
-- immune stretches), everything else 100%.
M.AIM_PATTERNS = { "Switch", "Track", "Flick" }
-- (fixes 2026-10-16 #3, playtester: the green targets have "no health bars / damage numbers, too much health (150+ shots),
-- too frequent; looking up at them hides the boss's attack indicators"):
--   * HEALTH: hits are counted in RIFLE HITS (CombatServer OrbWeight = 10 / shots a second, so every gun needs the same
--     time on target): 6 + phase (+1 superboss) per target, x1.35 per extra player (was 5 + 2 x phase (+2), x1.5), TRACK
--     x2.5 (was x4: a phase-3 superboss track in a party was ~150 SMG shots). An AR now needs ~7-10 shots, a sniper 1-2.
--   * every target shows a HEALTH BAR, and your hits on it show a damage number (rifle hit = 10)
--   * rounds come less often: first after 14 s, then every 40 / 36 / 32 s by phase (was 9, then 24 / 21 / 18)
--   * targets sit near EYE LEVEL round the boss (3.5-6.5 studs off the floor, was 11-20): floor telegraphs stay in view
M.AIM_FIRST, M.AIM_GAP = 14, { 40, 36, 32 } -- (first round after N s of fighting; then the gap by phase, x pace)
-- BOSS PACE (0.99u, owner: bosses "feel like bullet sponges" -> short fights: minis ~15 s, majors ~30 s, superbosses ~60 s):
-- every boss takes FULL damage outside a round (superbosses / major trial bosses took 50%), and during a round it GUARDS
-- (M.AIM_GUARD: half damage, was none) -- the round is a bonus stagger, not a gate. Rounds come sooner and closer so a short
-- fight still has one: first after AIM_FIRST_MINI 5 s (mini-bosses) / AIM_FIRST_BOSS 8 s, then every AIM_GAP s by phase (x pace).
M.AIM_GUARD = 0.5
M.AIM_FIRST_MINI, M.AIM_FIRST_BOSS = 5, 8
M.AIM_GAP = { 24, 22, 20 }
M.AIM_TIME = { Switch = 14, Track = 12, Flick = 14 }
M.AIM_COLOR = Color3.fromRGB(170, 255, 60)
function M.AimNeed(B): number
    local players = math.max(1, #(B.d.Targets and B.d.Targets() or {}))
    -- (MAPS V2: a map guardian's targets need +Rifts.GUARDIAN_AIM (8%) more hits a band above Ruin -- the higher band asks more)
    local band = tonumber(B.config and B.config.GuardianBand) or 1
    return math.ceil((6 + B.phase + (B.kind == "SuperBoss" and 1 or 0)) * (1 + 0.35 * (players - 1)) * (1 + 0.08 * math.max(0, band - 1)))
end
function M.AimRound(B, pattern: string)
    local model = B.model
    local body = Body(model)
    if not body or not B:Alive() then return end
    local mini = MINIBOSS_KINDS[B.kind] == true
    local need = M.AimNeed(B)
    local count = (pattern == "Track") and 1 or ((B.phase >= 3 and 4 or 3) - (mini and 1 or 0) + ((pattern == "Flick") and 2 or 0))
    if pattern == "Track" then need = math.ceil(need * (mini and 2 or 2.5)) end
    if pattern == "Flick" then need = math.max(3, math.ceil(need * 0.6)) end
    B.shielded = true
    Mech(B, true)
    B.rawTaken(model, M.AIM_GUARD) -- (0.99u: it guards -- half damage -- instead of no damage)
    -- (MAPS V2) kit.AimTheme = a boss's own TARGETS: Label[pattern], Size[pattern], Spot(B, pattern, k, n, a0, floorY, prev) -> Vector3,
    -- Dress(B, o, pattern) (parts beside the target, never CanQuery), Move(B, pattern, o, now, t0, floorY) -> CFrame?, Place(B, o, cf).
    -- Same lime targets, counting, timer and stagger as every boss; only where they sit and how they move is the boss's own.
    local theme = B.kit.AimTheme
    local label = (theme and theme.Label and theme.Label[pattern]) or ({ Switch = "SHOOT EVERY TARGET", Track = "TRACK THE TARGET", Flick = "FLICK THE TARGETS" })[pattern]
    VFX.Banner("TARGETS", label, M.AIM_COLOR)
    Sound("ShieldUp", body)
    local size = model:GetExtentsSize()
    local bubble = Part({ Name = "ShieldBubble", Shape = Enum.PartType.Ball, Size = Vector3.one * (math.max(size.X, size.Y, size.Z) + 4),
        Color = M.AIM_COLOR, Material = Enum.Material.ForceField, Transparency = 0.45, CFrame = body.CFrame })
    bubble.Parent = B.d.Fx
    local server = RunService:IsServer()
    local function Target(i: number, at: Vector3, r: number)
        local o = Part({ Name = "ShieldOrb" .. i, Shape = Enum.PartType.Ball, Size = Vector3.one * r, Color = M.AIM_COLOR,
            CanQuery = true, CFrame = CFrame.new(at) })
        o:SetAttribute("BossOrb", true)
        local core = Part({ Name = "OrbCore", Shape = Enum.PartType.Ball, Size = Vector3.one * (r * 0.45), Color = Color3.new(1, 1, 1), CFrame = o.CFrame })
        core.Parent = o
        local link = Instance.new("ObjectValue"); link.Name = "HitModel"; link.Value = model; link.Parent = o
        o:SetAttribute("OrbNeed", need) -- (the client's damage number: one rifle hit = 10 of need x 10)
        -- (fixes #3) a health bar over the target (never on the target itself: that's where the crosshair sits)
        local bb = Instance.new("BillboardGui")
        bb.Name = "OrbBar"; bb.Size = UDim2.fromOffset(64, 9); bb.StudsOffset = Vector3.new(0, r * 0.5 + 1.4, 0)
        bb.AlwaysOnTop = true; bb.LightInfluence = 0; bb.MaxDistance = 260
        local back = Instance.new("Frame")
        back.Size = UDim2.fromScale(1, 1); back.BackgroundColor3 = Color3.fromRGB(14, 16, 22); back.BorderSizePixel = 0; back.Parent = bb
        local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(0, 0, 0); stroke.Thickness = 1.5; stroke.Parent = back
        local fill = Instance.new("Frame")
        fill.Name = "Fill"; fill.Size = UDim2.fromScale(1, 1); fill.BackgroundColor3 = M.AIM_COLOR; fill.BorderSizePixel = 0; fill.Parent = back
        bb.Parent = o
        o.Parent = B.d.Fx
        local t = { Part = o, Key = "Orb" .. i, Start = model:GetAttribute("Orb" .. i) or 0, Alive = true, Base = at, R = r, Ph = math.random() * 6.28, Fill = fill, Born = os.clock(), I = i }
        if theme and theme.Dress then pcall(theme.Dress, B, t, pattern) end
        return t
    end
    -- (fixes #3: heights from the arena FLOOR -- d.SpawnPos sits ~8 studs above it, which put "eye level" overhead)
    local floorY = EA.GroundY(B.ctx, B.pos)
    -- spots round the boss, inside the arena, at aim heights (never behind the boss's own body)
    local function Spot(k: number, n: number, a0: number, prev: any?): Vector3
        if theme and theme.Spot then
            local ok, p = pcall(theme.Spot, B, pattern, k, n, a0, floorY, prev)
            if ok and typeof(p) == "Vector3" then return p end
        end
        local a = a0 + (k - 1) * math.pi * 2 / math.max(1, n) + (math.random() - 0.5) * 0.5
        local r = 14 + math.random() * 10
        local p = B:Clamp(Vector3.new(B.pos.X + math.cos(a) * r, 0, B.pos.Z + math.sin(a) * r))
        return Vector3.new(p.X, floorY + 3.5 + math.random() * 3, p.Z) -- (fixes #3: eye level (~4.6 up) +- 1.5, was 11-20 up)
    end
    local targets = {}
    local a0 = math.random() * math.pi * 2
    local flickI = 0
    if pattern == "Flick" then
        flickI = 1
        table.insert(targets, Target(1, Spot(1, count, a0), (theme and theme.Size and theme.Size.Flick) or 3.6))
    else
        for i = 1, count do table.insert(targets, Target(i, Spot(i, count, a0), (theme and theme.Size and theme.Size[pattern]) or (pattern == "Track" and 4.4 or 4))) end
    end
    local limit = (M.AIM_TIME[pattern] or 14) / math.max(0.75, math.min(1.2, B.pace or 1)) -- (slower paces give a little more time)
    local t0 = os.clock()
    local done = 0
    while B:Alive() do
        local now = os.clock()
        local left = 0
        for _, o in ipairs(targets) do
            if o.Alive then
                local hits = (model:GetAttribute(o.Key) or 0) - o.Start
                if hits >= need then
                    o.Alive = false
                    done += 1
                    VFX.Burst(B.d.Fx, o.Part.Position, M.AIM_COLOR, 10, "Explosion")
                    Sound("ShieldDown", o.Part)
                    o.Part:Destroy()
                    if pattern == "Flick" and flickI < count then
                        flickI += 1
                        table.insert(targets, Target(flickI, Spot(math.random(1, count), count, a0 + flickI * 1.7, o), (theme and theme.Size and theme.Size.Flick) or 3.6))
                    end
                else
                    left += 1
                    local k = 1 - hits / need
                    o.Part.Size = Vector3.one * (o.R * (0.6 + 0.4 * k))
                    if o.Fill then o.Fill.Size = UDim2.fromScale(math.clamp(k, 0, 1), 1) end
                    local cf
                    if theme and theme.Move then
                        local okM, c2 = pcall(theme.Move, B, pattern, o, now, t0, floorY)
                        if okM then cf = c2 end
                    end
                    if cf then
                        -- (the theme moved it)
                    elseif pattern == "Track" then
                        -- a smooth figure-eight round the boss (speed rises with the phase), never a snap
                        local t = (now - t0) * (0.55 + 0.12 * B.phase) + o.Ph
                        local rr = 16 + 4 * math.sin(t * 0.7)
                        local pos = B:Clamp(Vector3.new(B.pos.X + math.cos(t) * rr, 0, B.pos.Z + math.sin(t) * rr))
                        cf = CFrame.new(pos.X, floorY + 5 + 1.5 * math.sin(t * 2), pos.Z) -- (fixes #3: eye level, was 11-19 up)
                    elseif not server then
                        cf = CFrame.new(o.Base + Vector3.new(0, math.sin(now * 1.4 + o.Ph) * 0.8, 0))
                    end
                    if cf then
                        o.Part.CFrame = cf
                        local core = o.Part:FindFirstChild("OrbCore")
                        if core then core.CFrame = cf end
                    end
                    if theme and theme.Place then pcall(theme.Place, B, o, cf or o.Part.CFrame) end
                end
            end
        end
        if bubble.Parent then bubble.CFrame = body.CFrame end
        local total = (pattern == "Flick") and count or #targets
        if left == 0 and (pattern ~= "Flick" or flickI >= count) then break end
        local secs = math.max(0, math.ceil(limit - (now - t0)))
        B:Title(string.format("%s   >>  %s  %d / %d  (%ds)", B.kit.Names[B.phase], label, done, total, secs), M.AIM_COLOR)
        if now - t0 >= limit then
            VFX.Banner("TOO SLOW", "the targets fire: move!", Color3.fromRGB(255, 120, 90))
            for _, o in ipairs(targets) do
                if o.Alive then
                    local r = B:Root()
                    if r then EA.Circle(B.ctx, Flat(r.Position) + Vector3.new(0, B.d.SpawnPos.Y, 0), 10, 1.1, { Mult = 1.1 }) end
                    o.Alive = false
                    if o.Part.Parent then o.Part:Destroy() end
                    B:Wait(0.3)
                end
            end
            break
        end
        RunService.Heartbeat:Wait()
    end
    local won = true
    for _, o in ipairs(targets) do
        if o.Part.Parent then o.Part:Destroy() end
    end
    if pattern == "Flick" then won = done >= count else won = done >= #targets end
    if bubble.Parent then bubble:Destroy() end
    B.shielded = false
    Mech(B, false)
    if not B:Alive() then return end
    if not won then
        B.rawTaken(model, B.baseTaken or 1)
        B:Title(B.kit.Names[B.phase])
        return
    end
    VFX.Banner("STAGGERED", "+75% DAMAGE: HIT IT NOW", Color3.fromRGB(255, 220, 120))
    VFX.ScreenFlash(M.AIM_COLOR, 0.2)
    VFX.Burst(B.d.Fx, B.pos, M.AIM_COLOR, 22, "Explosion")
    B.staggered = true
    B.rawTaken(model, STAGGER_MULT)
    B:Hold(STAGGER_TIME)
    B.nextMove = math.max(B.nextMove, os.clock() + STAGGER_TIME + 0.4)
    local tEnd = os.clock() + STAGGER_TIME
    while B:Alive() and os.clock() < tEnd do
        B:Title(string.format("%s   >>  STAGGERED  +75%% DAMAGE  (%ds)", B.kit.Names[B.phase], math.ceil(tEnd - os.clock())), Color3.fromRGB(255, 220, 120))
        B:Wait(0.1)
    end
    B.staggered = false
    if B:Alive() then
        B.rawTaken(model, B.baseTaken or 1)
        B:Title(B.kit.Names[B.phase])
    end
end
-- HIT FEEDBACK (0.99u, owner: bosses "feel like bullet sponges" -- make the damage LAND): every 10% of health the boss loses
-- it FLINCHES (a short rock back, M.Flinch -> the pose loop's pivot) and armour CHIPS spray off its flank (a few small sparks
-- on its side, never its head where you aim). The boss bar breaks into the same 10% chunks (EnemyBars). No screen flash,
-- nothing at the crosshair.
M.FLINCH_TIME, M.FLINCH_TILT, M.FLINCH_PUSH = 0.24, 0.11, 0.5
function M.Flinch(B, frac: number, now: number): CFrame
    local chunk = math.ceil(frac * 10 - 1e-6)
    if B.chunk == nil then B.chunk = chunk end
    if chunk < B.chunk and frac > 0 then
        B.chunk = chunk
        B.flinchAt = now
        local body = Body(B.model)
        if body then
            local cf = body.CFrame
            local side = ((math.random() < 0.5) and -1 or 1) * math.max(1.2, body.Size.X * 0.5)
            local at = Part({ Name = "BossChips", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = cf * CFrame.new(side, -body.Size.Y * 0.15, 0), Parent = B.d.Fx })
            local col = B.kit.Color or Color3.fromRGB(255, 200, 120)
            local e = Emitter(at, { Texture = SPARK, Color = ColorSequence.new(col, Color3.fromRGB(60, 56, 64)), LightEmission = 0.6, LightInfluence = 0.3,
                Rate = 0, Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(10, 18), SpreadAngle = Vector2.new(35, 35),
                Acceleration = Vector3.new(0, -60, 0), Size = NumberSequence.new(0.45, 0), Drag = 2,
                EmissionDirection = (side > 0) and Enum.NormalId.Right or Enum.NormalId.Left })
            e:Emit(9)
            Debris:AddItem(at, 1)
        end
    elseif chunk > B.chunk then
        B.chunk = chunk -- (healed / a new phase's bar)
    end
    local k = B.flinchAt and math.max(0, 1 - (now - B.flinchAt) / M.FLINCH_TIME) or 0
    if k <= 0 then return CFrame.identity end
    k = k * k
    return CFrame.new(0, 0, M.FLINCH_PUSH * k) * CFrame.Angles(M.FLINCH_TILT * k, 0, 0)
end
-- the round loop (started at engagement instead of a signature)
function M.AimLoop(B)
    local key = SigKey(B)
    local h = 0
    for i = 1, #key do h = (h * 31 + string.byte(key, i)) % 997 end
    local idx = h % #M.AIM_PATTERNS -- (each boss starts on its own pattern, then plays them in turn)
    B.baseTaken = 1 -- (0.99u BOSS PACE: full damage for every boss outside a round; superbosses / major trial bosses took 0.5)
    B.sigOwn = true -- (moves can't change what it takes; the rounds own that)
    B.rawTaken(B.model, B.baseTaken)
    local nextAt = os.clock() + ((MINIBOSS_KINDS[B.kind] == true) and M.AIM_FIRST_MINI or M.AIM_FIRST_BOSS)
    while B:Alive() do
        if os.clock() >= nextAt and not B.roaring and not B.shielded and not B.staggered and B.active == 0 then
            idx = idx % #M.AIM_PATTERNS + 1
            M.AimRound(B, M.AIM_PATTERNS[idx])
            -- (UPDATE 8 BOSS GUARD, owner: no "bullet sponge" bosses): the gap never shrinks below AIM_GAP on fast (high-tier)
            -- paces. Rounds there last up to 14 / 0.75 s and the gap went down to x0.7 -- a boss whose targets nobody breaks spent
            -- ~60% of the fight guarded (Ruin superboss 1.6x its fight time); now ~40% (~1.3x). Breaking a round still ends the guard
            -- at once and staggers (x1.75), so fast breakers keep their shorter fight.
            nextAt = os.clock() + (M.AIM_GAP[B.phase] or 20) * math.clamp(B.pace or 1, 1, 1.4)
        end
        B:Wait(0.25)
    end
end

-- (v3) Moves[phase] = { { fn, "CALLOUT" }, ... } played IN ORDER, looping; the rotation restarts at a phase change
local RECOVER = { 2.2, 1.8, 1.5 } -- (seconds of nothing after each move -- the damage window; x pace)
-- MECHANIC MODE moves: one slow, light attack at a time -- keep moving, but your eyes stay on the mechanic
local MECH_RECOVER = 3.4
-- (0.61f: PULSE / LOCK-ON renamed -- they were the Sentinel's and the Phantom's callouts)
local MECH_MOVES = {
    { function(B) -- SEEKER: one slow circle where you stand
        local r = B:Root()
        if r then EA.Circle(B.ctx, r.Position, 6, 1.4, { Mult = 0.7 }) end
        B:Wait(B:W(1.4))
    end, "SEEKER" },
    { function(B) -- PULSE: one slow ring from the boss (jump it)
        EA.Ring(B.ctx, B.pos, 70, 0.8, { Mult = 0.7, Speed = 24, StartRadius = 4 })
        B:Wait(B:W(0.8) + 0.4)
    end, "SHOCKWAVE" },
    { function(B) -- LOCK-ON: a single slow beam
        local r = B:Root()
        if r then EA.Beam(B.ctx, function() return B.pos + Vector3.new(0, 1, 0) end, r, 1.3, { Mult = 0.8, LockTime = 0.3, Width = 2, Range = 240 }) end
        B:Wait(B:W(1.3))
    end, "SIGHTLINE" },
    -- (2026-10-07: three more, picked at random, so a long mechanic isn't the same three attacks on a loop)
    { function(B) -- WAVE: one low wall rolls across (jump it)
        local r = B:Root()
        if r then EA.Wall(B.ctx, B.pos, Flat(r.Position - B.pos), 120, 70, 1.0, { Mult = 0.7, Speed = 22 }) end
        B:Wait(B:W(1.0) + 1.2)
    end, "WAVE" },
    { function(B) -- TRAIL: three small circles drop on the path you're running
        for _ = 1, 3 do
            local r = B:Root()
            if not r or not B:Alive() then return end
            EA.Circle(B.ctx, r.Position, 5, 1.1, { Mult = 0.6 })
            B:Wait(0.45)
        end
        B:Wait(B:W(1.1))
    end, "TRAIL" },
    { function(B) -- CLOSE GUARD: a circle right round the boss (don't hug it)
        EA.Circle(B.ctx, B.pos, 12, 1.2, { Mult = 0.7 })
        B:Wait(B:W(1.2) + 0.3)
    end, "CLOSE GUARD" },
}
-- ==================== TRACKING MECHANICS (0.62) ====================
-- (owner: "The phantom stalker is an example of one of the FUN bosses to fight, use that as a reference without directly
-- copying it. I want bosses to have a lot of target switching / tracking mechanics"): what makes the Phantom fun is that
-- you're always choosing WHAT to shoot and following it as it moves. Three engines, each boss dressed in its own (TRACKS
-- below; the Phantom keeps its Mirror Dance):
--   SATELLITES  2-3 small targets swing round the boss (flat ring / tilted rings / swarm). Break them all in time:
--               EXPOSED (1.75x). Any left fire a line at you.                      -> target switching on movers
--   WISP        one small, fast target sweeps smooth curves round the boss; keep your shots on it to fill the meter:
--               EXPOSED. Run out of time: it dives at you.                          -> sustained tracking
--   RELAY       targets blink in one at a time round YOU, each well away from the last, gone in ~1.5 s. Pop 70%:
--               EXPOSED. Fewer: a mark hunts you.                                    -> flick switching
-- Targets are "ShieldOrb7-9" outside the boss (HitModel link: counted hits, no damage, no range check), sized well
-- under the boss. Rounds run in MECHANIC MODE (light moves only) and never overlap another mechanic.
local TRACK_GAP = 13 -- seconds between two tracking rounds (minus 1 a phase)
local function TrackOrb(B, i, size, color, shape)
    local o = Part({ Name = "ShieldOrb" .. i, Shape = shape or Enum.PartType.Ball, Size = Vector3.one * size, Color = color, CanQuery = true,
        Material = Enum.Material.Neon, Transparency = 0.05 })
    o:SetAttribute("BossOrb", true)
    local link = Instance.new("ObjectValue"); link.Name = "HitModel"; link.Value = B.model; link.Parent = o
    o.Parent = B.d.Fx
    return o
end
local function TrackStep()
    if RunService:IsServer() then task.wait(0.1) else RunService.Heartbeat:Wait() end -- (server-run party bosses: 10 Hz)
end
local function TrackNeed(B, base) return math.ceil(base * (1 + 0.5 * (PartySize(B) - 1))) end
local function TrackWin(B, c) Window(B, c.Win or "EXPOSED", c.WinSub or "it's open: hit it hard", 1.75, 4, c.Color) end
local function TrackCentre(B)
    local body = Body(B.model)
    return body and body.Position or (B.pos + Vector3.new(0, 2, 0))
end
local function Gone(B, part, color)
    if part and part.Parent then VFX.Burst(B.d.Fx, part.Position, color, 7, nil); part:Destroy() end
end

-- ==================== NEW MOVES (0.63, owner: "continue to improve boss attacks and variety") ====================
-- PYLONS: n small pylons rise round the arena, away from each other; shoot each one down (a couple of hits) before the
-- timer runs out -- every pylon still standing fires a beam at you. Target switching on the move, not a floor pattern.
function M.Pylons(B, n, secs, color)
    local r = B:Root()
    if not r then return end
    -- (a tracking round / mechanic already running: never two at once -- wait a moment for it, else something light)
    local w0 = os.clock()
    while (B.mechN or 0) > 0 and os.clock() - w0 < 3 and B:Alive() do B:Wait(0.25) end
    if (B.mechN or 0) > 0 then return M.Predict(B, 3) end
    local bnd = B.d.Bounds
    local cx, cz = (bnd.MinX + bnd.MaxX) / 2, (bnd.MinZ + bnd.MaxZ) / 2
    local R = math.min(bnd.MaxX - bnd.MinX, bnd.MaxZ - bnd.MinZ) * 0.36
    local need = TrackNeed(B, 2)
    local col = color or B.kit.Color
    local a0 = math.random() * math.pi * 2
    local list = {}
    for k = 1, n do
        local a = a0 + (k - 1) / n * math.pi * 2 + (math.random() - 0.5) * 0.5
        local q = B:Clamp(Vector3.new(cx + math.cos(a) * R, 0, cz + math.sin(a) * R))
        local y = EA.GroundY(B.ctx, q) + 3 + math.random() * 4
        local i = 3 + k
        local o = TrackOrb(B, i, 2.2, col, Enum.PartType.Cylinder)
        o.CFrame = CFrame.new(q.X, y, q.Z) * CFrame.Angles(0, 0, math.pi / 2)
        VFX.Burst(B.d.Fx, o.Position, col, 6, nil)
        list[k] = { Part = o, I = i, Base = Hits(B, i), Up = true, Y = y, Q = q }
    end
    Mech(B, true)
    local tEnd = os.clock() + secs
    while B:Alive() and os.clock() < tEnd do
        local up = 0
        for k, st in ipairs(list) do
            if st.Up then
                if Hits(B, st.I) - st.Base >= need then
                    st.Up = false
                    Gone(B, st.Part, col)
                else
                    up += 1
                    st.Part.CFrame = CFrame.new(st.Q.X, st.Y + math.sin(os.clock() * 3 + k) * 0.5, st.Q.Z) * CFrame.Angles(0, 0, math.pi / 2)
                end
            end
        end
        if up == 0 then break end
        Info(B, string.format("PYLONS %d LEFT  •  %ds", up, math.max(0, math.ceil(tEnd - os.clock()))))
        TrackStep()
    end
    Mech(B, false)
    Info(B, "")
    for _, st in ipairs(list) do
        if st.Up and st.Part.Parent and B:Alive() then
            local rr = B:Root()
            local from = st.Part.Position
            if rr then EA.Beam(B.ctx, function() return from end, rr, 0.9, { Mult = 1.0, LockTime = 0.25, Width = 2, Range = 240 }) end
            B:Wait(0.25)
        end
    end
    B:Wait(1.0)
    for _, st in ipairs(list) do Gone(B, st.Part, col) end
end
-- SEEKERS: n slow homing orbs leave the boss and drift after you on wavy paths; pop each (a couple of hits) before it
-- reaches you -- one that does bursts where you stand. Tracking moving targets that come TO you.
function M.Seekers(B, n, color)
    local r = B:Root()
    if not r then return end
    local w0 = os.clock()
    while (B.mechN or 0) > 0 and os.clock() - w0 < 3 and B:Alive() do B:Wait(0.25) end
    if (B.mechN or 0) > 0 then return M.Predict(B, 3) end
    local col = color or B.kit.Color
    local need = TrackNeed(B, 2)
    local speed = 7.5 + 1.5 * B.phase
    local list = {}
    local body = TrackCentre(B)
    for k = 1, n do
        local i = 3 + k
        local o = TrackOrb(B, i, 1.6, col, Enum.PartType.Ball)
        local side = (k - (n + 1) / 2) * 5
        local start = body + Vector3.new(0, 2 + k, 0) + Unit(Flat(r.Position - body)):Cross(Vector3.yAxis) * side
        o.CFrame = CFrame.new(start)
        VFX.Burst(B.d.Fx, start, col, 5, nil)
        list[k] = { Part = o, I = i, Base = Hits(B, i), Up = true, P = start, Ph = math.random() * 6, Delay = (k - 1) * 0.35 }
    end
    Mech(B, true)
    local t0, last = os.clock(), os.clock()
    while B:Alive() and os.clock() - t0 < 9 do
        local now = os.clock()
        local dt = now - last
        last = now
        local up = 0
        local rr = B:Root()
        for _, st in ipairs(list) do
            if st.Up then
                if Hits(B, st.I) - st.Base >= need then
                    st.Up = false
                    Gone(B, st.Part, col)
                elseif rr then
                    up += 1
                    if now - t0 > st.Delay then
                        local target = rr.Position + Vector3.new(0, 1.5, 0)
                        local dir = target - st.P
                        local dist = dir.Magnitude
                        if dist < 3.2 then
                            st.Up = false
                            EA.Circle(B.ctx, rr.Position, 6, 0.3, { Mult = 0.9 })
                            Gone(B, st.Part, col)
                        else
                            local wob = Vector3.new(math.sin(now * 3 + st.Ph), math.cos(now * 2.4 + st.Ph) * 0.6, math.cos(now * 3 + st.Ph)) * 2.2
                            st.P = st.P + (dir.Unit * speed + wob) * dt
                            st.Part.CFrame = CFrame.new(st.P)
                        end
                    end
                end
            end
        end
        if up == 0 then break end
        Info(B, string.format("SEEKERS %d INCOMING", up))
        TrackStep()
    end
    Mech(B, false)
    Info(B, "")
    for _, st in ipairs(list) do Gone(B, st.Part, col) end
end
-- PREDICT: circles land where you're GOING (your velocity, ~0.9 s ahead), one after another -- change direction
function M.Predict(B, n)
    for _ = 1, n do
        local r = B:Root()
        if not r or not B:Alive() then return end
        local v = r.AssemblyLinearVelocity
        local lead = Vector3.new(v.X, 0, v.Z) * 0.9
        if lead.Magnitude > 22 then lead = lead.Unit * 22 end
        EA.Circle(B.ctx, B:Clamp(r.Position + lead), 6.5, 0.85, { Mult = 1.2 })
        B:Wait(B:W(0.55))
    end
    B:Wait(B:W(0.85))
end
-- TWIN QUAKE: two shockwave rings from two points either side of you, the second a beat later -- jump one, then the other
function M.TwinQuake(B)
    local r = B:Root()
    if not r then return end
    local d = Unit(Flat(r.Position - B.pos))
    local side = Perp(d)
    local p1 = B:Clamp(r.Position + side * 26)
    local p2 = B:Clamp(r.Position - side * 26)
    VFX.Ghost(B.d.Fx, p1, B.kit.Color, 1)
    VFX.Ghost(B.d.Fx, p2, B.kit.Color, 1)
    EA.Ring(B.ctx, p1, 70, 0.8, { Mult = 1.1, Speed = 26, StartRadius = 3 })
    B:Wait(B:W(0.8) + 0.6)
    EA.Ring(B.ctx, p2, 70, 0.6, { Mult = 1.1, Speed = 26, StartRadius = 3 })
    B:Wait(B:W(0.6) + 1.2)
end

local TRACK = {}
function TRACK.Satellites(B, c)
    local n = math.min(3, (c.N or 2) + ((B.phase >= 2) and 1 or 0))
    local need = TrackNeed(B, (c.Need or 3) + B.phase)
    local secs = (c.Secs or 9) + n
    local sats = {}
    for k = 1, n do
        local i = 6 + k
        sats[k] = { Part = TrackOrb(B, i, c.Size or 1.8, c.Color, c.Shape), I = i, Base = Hits(B, i), Up = true, A = (k - 1) / n * math.pi * 2,
            Tilt = CFrame.Angles(math.rad(25 + 30 * k), (k - 1) * 2.1, 0), Seed = math.random() * 10 }
    end
    VFX.Banner(c.Name, c.Sub or string.format("break the %d moving targets", n), c.Color)
    Mech(B, true)
    local t0, last = os.clock(), os.clock()
    while B:Alive() and os.clock() - t0 < secs do
        local now = os.clock()
        local dt = now - last
        last = now
        local up = 0
        local centre = TrackCentre(B)
        local w = (c.Speed or 1.4) * (1 + 0.15 * (B.phase - 1))
        local R = c.Radius or 8
        for _, st in ipairs(sats) do
            if st.Up then
                if Hits(B, st.I) - st.Base >= need then
                    st.Up = false
                    Gone(B, st.Part, c.Color)
                else
                    up += 1
                    st.A += w * dt
                    local off
                    if c.Pattern == "Tilt" then
                        off = st.Tilt * Vector3.new(math.cos(st.A) * R, 0, math.sin(st.A) * R)
                    elseif c.Pattern == "Swarm" then
                        local t = now * w + st.Seed
                        off = Vector3.new(math.sin(t * 0.9) * R, math.sin(t * 1.3 + 1) * R * 0.45, math.cos(t * 0.7 + 2) * R)
                    else
                        off = Vector3.new(math.cos(st.A) * R, 1.5 + math.sin(now * 1.7 + st.Seed) * 1.5, math.sin(st.A) * R)
                    end
                    st.Part.CFrame = CFrame.new(centre + off)
                end
            end
        end
        Info(B, string.format("%s %d/%d  •  %ds", c.Name, n - up, n, math.max(0, math.ceil(secs - (now - t0)))))
        if up == 0 then break end
        TrackStep()
    end
    Mech(B, false)
    local left = {}
    for _, st in ipairs(sats) do
        if st.Up and st.Part.Parent then table.insert(left, st.Part.Position) end
        Gone(B, st.Part, c.Color)
    end
    Info(B, "")
    if not B:Alive() then return end
    if #left == 0 then
        TrackWin(B, c)
    else
        local r = B:Root()
        for _, from in ipairs(left) do
            if r then
                local f = Vector3.new(from.X, B.pos.Y, from.Z)
                EA.Line(B.ctx, f, f + Unit(Flat(r.Position - f)) * 70, 4, 0.85, { Mult = 0.9, Height = 10 })
            end
        end
    end
end
function TRACK.Wisp(B, c)
    local need = TrackNeed(B, (c.Need or 7) + 2 * B.phase)
    local secs = c.Secs or 8
    local i = 9
    local wisp = TrackOrb(B, i, c.Size or 1.6, c.Color)
    local base = Hits(B, i)
    VFX.Banner(c.Name, c.Sub or "keep your aim on it", c.Color)
    Mech(B, true)
    local t0 = os.clock()
    local fx, fy, fz = 0.9 + math.random() * 0.3, 1.4 + math.random() * 0.4, 0.6 + math.random() * 0.3
    local ph = math.random() * 6
    local done = false
    while B:Alive() and os.clock() - t0 < secs do
        local now = os.clock()
        local got = Hits(B, i) - base
        if got >= need then done = true break end
        local t = (now - t0) * (c.Speed or 1.5) * (1 + 0.12 * (B.phase - 1)) + ph
        local R = c.Radius or 11
        local p = TrackCentre(B) + Vector3.new(math.sin(t * fx) * R, 2 + math.sin(t * fy) * (c.Rise or 3.5), math.cos(t * fz) * R * 0.85)
        p = B:Clamp(p)
        wisp.CFrame = CFrame.new(p)
        Info(B, string.format("%s %d%%  •  %ds", c.Name, math.floor(math.clamp(got / need, 0, 1) * 100), math.max(0, math.ceil(secs - (now - t0)))))
        TrackStep()
    end
    Mech(B, false)
    Gone(B, wisp, c.Color)
    Info(B, "")
    if not B:Alive() then return end
    if done then
        TrackWin(B, c)
    else
        local r = B:Root()
        if r then EA.Circle(B.ctx, B:Clamp(r.Position), 9, 0.9, { Mult = 1.2, OnStrike = function(cc) B:Boom(cc, 8) end }) end
    end
end
function TRACK.Relay(B, c)
    local total = (c.N or 5) + B.phase
    local life = math.max(1.0, (c.Life or 1.7) - 0.15 * (B.phase - 1))
    local needHits = TrackNeed(B, 1)
    VFX.Banner(c.Name, c.Sub or string.format("%d targets, one at a time: pop them fast", total), c.Color)
    Mech(B, true)
    local popped, lastA = 0, nil
    for k = 1, total do
        if not B:Alive() then break end
        local r = B:Root()
        if not r then break end
        -- somewhere round YOU, at least 60 degrees from the last one (you have to turn to it)
        local a = math.random() * math.pi * 2
        for _ = 1, 12 do
            if not lastA or math.abs(((a - lastA + math.pi) % (2 * math.pi)) - math.pi) > math.rad(60) then break end
            a = math.random() * math.pi * 2
        end
        lastA = a
        local d = 18 + math.random() * 18
        local q = B:Clamp(Vector3.new(r.Position.X + math.cos(a) * d, 0, r.Position.Z + math.sin(a) * d))
        local y = EA.GroundY(B.ctx, q) + 3 + math.random() * 7
        local i = 7 + (k % 2)
        local node = TrackOrb(B, i, c.Size or 2.0, c.Color, c.Shape)
        node.CFrame = CFrame.new(q.X, y, q.Z)
        VFX.Burst(B.d.Fx, node.Position, c.Color, 5, nil)
        local base = Hits(B, i)
        local tEnd = os.clock() + life
        local hit = false
        while B:Alive() and os.clock() < tEnd do
            if Hits(B, i) - base >= needHits then hit = true break end
            node.CFrame = CFrame.new(q.X, y + math.sin(os.clock() * 4 + k) * 0.6, q.Z) -- (a slow bob: not a static dot)
            Info(B, string.format("%s %d/%d", c.Name, popped, total))
            TrackStep()
        end
        if hit then popped += 1 end
        Gone(B, node, hit and c.Color or Color3.fromRGB(90, 90, 100))
        B:Wait(0.15)
    end
    Mech(B, false)
    Info(B, "")
    if not B:Alive() then return end
    if popped >= math.ceil(total * 0.7) then
        TrackWin(B, c)
    else
        local r = B:Root()
        if r then EA.Mark(B.ctx, r, 8, 1.4, { Mult = 1.4, OnStrike = function(cc) B:Boom(cc, 8) end }) end
    end
end

-- each boss's two tracking rounds (alternating), in its own colours / names (key = SigKey)
local function TK(engine, name, color, opts)
    local c = opts or {}
    c.Name, c.Color, c.Engine = name, color, engine
    return c
end
local BLOCK, CYL = Enum.PartType.Block, Enum.PartType.Cylinder
local TRACKS = {
    Goliath = { TK("Satellites", "SHRAPNEL", Color3.fromRGB(255, 170, 60), { Pattern = "Tilt", Radius = 7, Speed = 1.2, Shape = BLOCK }),
        TK("Relay", "SEISMIC NODES", Color3.fromRGB(255, 150, 40), { N = 4, Life = 1.9 }) },
    Sentinel = { TK("Relay", "SENSOR GRID", Color3.fromRGB(90, 200, 255), { N = 5, Shape = BLOCK }),
        TK("Satellites", "PATROL DRONES", Color3.fromRGB(140, 220, 255), { Pattern = "Ring", Radius = 9, Speed = 1.6 }) },
    Ravager = { TK("Wisp", "BLOOD SCENT", Color3.fromRGB(255, 70, 60), { Radius = 10, Speed = 1.7 }),
        TK("Relay", "PREY", Color3.fromRGB(255, 120, 80), { N = 4, Life = 1.6 }) },
    Hexcaller = { TK("Relay", "RUNE CHAIN", Color3.fromRGB(70, 235, 190), { N = 5, Shape = BLOCK }),
        TK("Wisp", "HEX SPIRIT", Color3.fromRGB(120, 255, 215), { Radius = 12, Rise = 4.5 }) },
    Titan = { TK("Relay", "TARGET BEACONS", Color3.fromRGB(255, 70, 50), { N = 5, Shape = BLOCK }),
        TK("Satellites", "ESCORT DRONES", Color3.fromRGB(255, 120, 90), { Pattern = "Swarm", Radius = 10, Speed = 1.1 }) },
    SuperFire = { TK("Satellites", "EMBER CROWN", Color3.fromRGB(255, 140, 50), { Pattern = "Tilt", Radius = 8, Speed = 1.6 }),
        TK("Wisp", "WILL-O-WISP", Color3.fromRGB(255, 200, 80), { Radius = 12 }) },
    SuperIce = { TK("Wisp", "SNOW SPIRIT", Color3.fromRGB(170, 230, 255), { Radius = 12, Speed = 1.4 }),
        TK("Relay", "ICICLES", Color3.fromRGB(140, 210, 255), { N = 5, Shape = BLOCK }) },
    SuperVoid = { TK("Satellites", "VOID MOTES", Color3.fromRGB(170, 90, 255), { Pattern = "Swarm", Radius = 11, Speed = 1.2 }),
        TK("Relay", "RIFTS", Color3.fromRGB(200, 120, 255), { N = 5 }) },
    SuperCyber = { TK("Wisp", "PACKET TRACE", Color3.fromRGB(60, 255, 190), { Radius = 12, Speed = 1.7 }),
        TK("Relay", "PING", Color3.fromRGB(60, 230, 220), { N = 6, Life = 1.5, Shape = BLOCK }) },
    SuperStorm = { TK("Relay", "BALL LIGHTNING", Color3.fromRGB(150, 210, 255), { N = 6, Life = 1.5 }),
        TK("Satellites", "STORM EYES", Color3.fromRGB(200, 230, 255), { Pattern = "Tilt", Radius = 9, Speed = 1.8 }) },
    SuperDream = { TK("Wisp", "DREAM MOTH", Color3.fromRGB(255, 190, 240), { Radius = 12, Rise = 4.5 }),
        TK("Satellites", "COUNTED SHEEP", Color3.fromRGB(240, 240, 255), { Pattern = "Ring", Radius = 9, Speed = 1.3 }) },
    SuperFlats = { TK("Relay", "DUST DEVILS", Color3.fromRGB(240, 200, 120), { N = 5 }),
        TK("Wisp", "HEAT HAZE", Color3.fromRGB(255, 220, 140), { Radius = 13 }) },
    Archon = { TK("Satellites", "CHOIR OF LIGHT", Color3.fromRGB(255, 230, 150), { Pattern = "Tilt", Radius = 8, Speed = 1.4 }),
        TK("Relay", "HALOS", Color3.fromRGB(255, 214, 120), { N = 5, Shape = CYL }) },
    Chronarch = { TK("Relay", "TIME SHARDS", Color3.fromRGB(90, 230, 255), { N = 5, Shape = BLOCK }),
        TK("Wisp", "SECOND HAND", Color3.fromRGB(150, 240, 255), { Radius = 11, Speed = 1.8 }) },
    EchoWarden = { TK("Wisp", "ECHO", Color3.fromRGB(190, 110, 255), { Radius = 12 }),
        TK("Satellites", "RESONANCE", Color3.fromRGB(220, 160, 255), { Pattern = "Ring", Radius = 9, Speed = 1.5 }) },
    Forgeheart = { TK("Satellites", "SLAG SPARKS", Color3.fromRGB(255, 130, 40), { Pattern = "Swarm", Radius = 9, Speed = 1.2 }),
        TK("Relay", "RIVETS", Color3.fromRGB(255, 180, 90), { N = 5, Shape = BLOCK }) },
    Lockwarden = { TK("Wisp", "STRAY KEY", Color3.fromRGB(120, 200, 255), { Radius = 11 }),
        TK("Relay", "TUMBLERS", Color3.fromRGB(160, 220, 255), { N = 5, Shape = CYL }) },
    Broodmother = { TK("Relay", "HATCHLINGS", Color3.fromRGB(255, 120, 60), { N = 6, Life = 1.6 }),
        TK("Satellites", "BROOD GUARD", Color3.fromRGB(255, 160, 90), { Pattern = "Swarm", Radius = 10, Speed = 1.3 }) },
    Duelist = { TK("Wisp", "FEINT", Color3.fromRGB(200, 120, 255), { Radius = 10, Speed = 1.8 }),
        TK("Relay", "RIPOSTE POINTS", Color3.fromRGB(230, 170, 255), { N = 5, Life = 1.5 }) },
    FortuneEngine = { TK("Satellites", "SPINNING COINS", Color3.fromRGB(255, 210, 60), { Pattern = "Ring", Radius = 9, Speed = 1.7, Shape = CYL }),
        TK("Relay", "JACKPOT", Color3.fromRGB(255, 230, 120), { N = 6 }) },
    Ascendant = { TK("Relay", "ASCENSION SPARKS", Color3.fromRGB(150, 220, 255), { N = 6 }),
        TK("Wisp", "PROVING LIGHT", Color3.fromRGB(200, 240, 255), { Radius = 12, Speed = 1.7 }) },
}
local function TrackLoop(B)
    local list = TRACKS[SigKey(B)]
    if not list then return end
    local k = 0
    B:Wait(7)
    while B:Alive() do
        -- never on top of another mechanic, a phase roar or a damage window
        while B:Alive() and ((B.mechN or 0) > 0 or B.roaring or B.rooted or B.staggered) do B:Wait(0.5) end
        if not B:Alive() then return end
        k = k % #list + 1
        local c = list[k]
        local ok, err = pcall(TRACK[c.Engine], B, c)
        if not ok then warn("[BossAI] tracking: " .. tostring(err)) end
        B:Wait(math.max(8, TRACK_GAP - B.phase))
    end
end

-- (0.63 boss variety) every biome superboss also gets the new moves in its own colours: SEEKERS in phase 2, PYLONS in
-- phase 3 (a loop, not new locals: this chunk is at the 200-local limit)
for _, kit in pairs(SUPER) do
    if kit.Moves and kit.Moves[2] and kit.Moves[3] then
        table.insert(kit.Moves[2], { function(B) M.Seekers(B, 2, kit.Color) end, "HUNTERS" })
        table.insert(kit.Moves[3], { function(B) M.Pylons(B, 3, 6, kit.Color) end, "PYLONS" })
    end
end

local function PickMove(B)
    if (B.mechN or 0) > 0 then
        local mm = B.kit.MechMoves or MECH_MOVES
        local k = math.random(1, #mm)
        if #mm > 1 and k == B.mechIdx then k = (k % #mm) + 1 end
        B.mechIdx = k
        local m = mm[k]
        return m[1], m[2], true
    end
    -- (2026-10-07, owner: "bosses still spam the same attack often ... we need variation") each pass through a phase's
    -- moves is a fresh SHUFFLE (the phase's first move still opens the phase): every move comes once per pass, and the
    -- same CALLOUT never plays twice in a row
    local list = B.kit.Moves[B.phase] or B.kit.Moves[1]
    local fresh = B.rotPhase ~= B.phase
    if fresh then B.rotPhase, B.rotIdx, B.rotBag = B.phase, 0, nil end
    if not B.rotBag or B.rotIdx >= #B.rotBag then
        local bag = {}
        for i = 1, #list do bag[i] = i end
        for i = #bag, 2, -1 do local j = math.random(1, i); bag[i], bag[j] = bag[j], bag[i] end
        if fresh then
            for i, v in ipairs(bag) do if v == 1 then table.remove(bag, i) break end end
            table.insert(bag, 1, 1)
        end
        B.rotBag, B.rotIdx = bag, 0
    end
    B.rotIdx += 1
    local m = list[B.rotBag[B.rotIdx]]
    if m[2] == B.lastCallout and #list > 1 then
        -- swap with a later move in this pass (or, at the end of a pass, take any other move)
        if B.rotIdx < #B.rotBag then
            B.rotBag[B.rotIdx], B.rotBag[B.rotIdx + 1] = B.rotBag[B.rotIdx + 1], B.rotBag[B.rotIdx]
            m = list[B.rotBag[B.rotIdx]]
        else
            for _, v in ipairs(B.rotBag) do if list[v][2] ~= B.lastCallout then m = list[v] break end end
        end
    end
    B.lastCallout = m[2]
    return m[1], m[2]
end

-- ==================== run ====================
-- (2026-10-05, owner: "minibosses ... should be about 20% easier") the miniboss tier fights at an easier tempo than the
-- bosses: telegraphs 20% longer (more time to react) and 20% longer recovery windows (~17% fewer attacks a minute).
-- Their health / damage were already below the Titan's (HP 30-58%, damage 62-77%), so those are unchanged.
local MINIBOSS = MINIBOSS_KINDS
local MINIBOSS_EASE = 1.2
function BossAI.Run(kind: string, model: Model, config: any, d: any)
    local kit = (kind == "SuperBoss") and (SUPER[config.Biome] or SUPER.Fire) or KITS[kind]
    if not kit then return end
    -- (shield orbs: while the shield is up / the boss is staggered, a move's own damage-taken change only takes effect
    -- afterwards -- B.rawTaken sets it for real)
    local rawSet = d.SetTakenMult
    d = table.clone(d)
    if d.Speed then d.Speed *= SkillFactor(config) end -- (Bot Skill: boss movement)
    -- (0.91, owner: "make the bigger bosses either a little smaller or move a bit faster"): wide bosses are easier to hit,
    -- so their travel + strafe speed rises with the footprint -- +0% at 4 studs across, +20% at 7.5 and wider
    do
        local ok, ext = pcall(function() return model:GetExtentsSize() end)
        local wide = ok and math.max(ext.X, ext.Z) or 4
        d.SizeK = 1 + math.clamp((wide - 4) / 3.5, 0, 1) * 0.2
    end
    local B
    d.SetTakenMult = function(m, v)
        if not m.Parent or m:GetAttribute("Dead") == true then return end
        if B then
            B.wantTaken = v
            if B.shielded or B.staggered or B.sigOwn then return end
        end
        rawSet(m, v)
    end
    B = setmetatable({
        kind = kind, model = model, config = config, d = d, kit = kit,
        pos = d.SpawnPos, phase = 1, hold = 0, active = 0, roaring = false, dashing = false, orbit = math.random() * math.pi * 2,
        nextMove = os.clock() + 1.6, lastMove = nil, engaged = false,
        pace = (PACE[config.Difficulty] or 1) * (config.TrialPace or 1) * (MINIBOSS[kind] and MINIBOSS_EASE or 1) / SkillFactor(config), -- (Boss Trials: the tier's pace on top)
        -- (never from a dead / removed boss: enemy ids repeat between floors, so a late change landed on the NEXT boss)
        rawTaken = function(m, v) if m.Parent and m:GetAttribute("Dead") ~= true then rawSet(m, v) end end,
    }, Brain)
    -- ATTACK COLOURS (2026-10-03): every boss move draws in the BOSS's colours (kit.Telegraph, else kit.Color) on the biome's
    -- material (EnemyAttacks.BIOME, from d.Geo) with a dark outline. Moves no longer pass their own colours.
    B.ctx = EA.Context({
        Geo = d.Geo, Fx = d.Fx, Windup = d.Windup * (MINIBOSS[kind] and MINIBOSS_EASE or 1) / math.sqrt(SkillFactor(config)), Color = nil, Columns = true, -- (boss attacks always draw their column)
        Model = model, -- (EnemyAnim: its wind-up lean)
        Targets = d.Targets,
        Alive = function() return model.Parent ~= nil and model:GetAttribute("Dead") ~= true end,
        Hit = function(p, mult) d.Hit(p, (mult or 1) * (B.hitMult or 1)) end, -- (B.hitMult: major-boss frenzy / enrage / double or nothing)
    })
    -- the boss's own colours (owner: "in boss cases, the boss"): kit.Telegraph if set, else its kit colour with a pale fill
    if kit.Telegraph then
        B.ctx.Color, B.ctx.Core = kit.Telegraph.Warn, kit.Telegraph.Core
    elseif kit.Color then
        B.ctx.Color, B.ctx.Core = kit.Color, kit.Color:Lerp(Color3.new(1, 1, 1), 0.65)
    end
    VFX.Aura(model, kit.Color)
    model:SetAttribute("BossColor", kit.Color)
    model:SetAttribute("BossPhases", "0.66,0.33")
    B:Title(kit.Names[1])

    task.spawn(function()
        local last = os.clock()
        local lastPos = B.pos
        while B:Alive() do
            local now = os.clock()
            local dt = math.min(0.1, now - last)
            last = now
            local r = B:Root()
            -- the constant pressure layer starts the first time it sees you
            if r and not B.engaged then
                B.engaged = true
                VFX.Banner(config.BossTrial and "BOSS TRIAL" or (((kind == "SuperBoss" and not model:GetAttribute("Lite")) and "SUPERBOSS" or "BOSS") .. "  •  FLOOR " .. tostring(config.FloorNumber or "")), kit.Names[1], kit.Color)
                VFX.Shake(B.pos, 1.0)
                -- (0.68: kit.Pressure -- the Chronarch's metronome, a timing mechanic -- is off: every mechanic is an aim round now)
                local sig = M.AimLoop -- (0.68 AIM ROUNDS: one aim mechanic for every boss; the old SIG signatures are off)
                if config.EnrageAt then task.spawn(MajorEnrage, B) end -- (every Boss Trial since 0.53)
                if sig then task.spawn(function() local ok, err = pcall(sig, B); if not ok then warn("[BossAI] signature: " .. tostring(err)) end end) end
                -- (0.68: the 0.62 tracking / target-switching rounds (TRACKS / TrackLoop) are off -- they ran alongside the aim
                -- rounds as a second mini-game at once; the aim rounds cover tracking and switching)
            end
            -- phases
            local hp, maxHp = model:GetAttribute("Health") or 1, model:GetAttribute("MaxHealth") or 1
            local frac = hp / math.max(1, maxHp)
            if not B.roaring and B.phase < 3 and frac <= PHASE_AT[B.phase] then
                task.spawn(PhaseChange, B, B.phase + 1)
            end
            -- MOVEMENT v4 (0.67, owner: "the bosses speed is fine, but the movement is incredibly glitchy and just kind of bug
            -- around. They should replicate fast kovaaks smooth scenarios"): ONE velocity, accel-limited, so every change of
            -- direction is a smooth swing. Its parts: travel to the kit's spot (orbit / chase, a slow drift while it attacks),
            -- the EVADE strafe across your aim (a sine whose rhythm wanders a little), and DODGES as a burst that eases out
            -- (they used to be 0.2 s dashes = hops). Moves that dash / glide on their own (B.dashing) still own the position.
            if r and not B.dashing then
                local slow = model:GetAttribute("SlowMult") or 1
                local tp = r.Position
                local desired
                if kit.Move == "Orbit" then
                    if now >= (B.orbitFlipAt or 0) then
                        B.orbitDir = (B.orbitFlipAt and -(B.orbitDir or 1)) or 1
                        B.orbitFlipAt = now + 4 + math.random() * 3
                    end
                    -- (the turn rate eases toward the new direction: no instant reversal)
                    B.orbitW = (B.orbitW or 0) + math.clamp((B.orbitDir or 1) - (B.orbitW or 0), -dt * 0.8, dt * 0.8)
                    B.orbit += dt * (0.2 + 0.05 * B.phase) * (d.Boost or 1) * B.orbitW
                    desired, B.orbit = B:RingSpot(tp, kit.Range, B.orbit)
                elseif kit.Move == "Chase" then
                    if now >= (B.wanderAt or 0) then
                        B.wanderGoal = ((math.random() < 0.5) and -1 or 1) * (0.5 + math.random() * 0.4)
                        B.wanderAt = now + 3 + math.random() * 2
                    end
                    B.wanderOff = (B.wanderOff or 0) + math.clamp((B.wanderGoal or 0) - (B.wanderOff or 0), -dt * 0.35, dt * 0.35)
                    local away = Flat(B.pos - tp)
                    desired = B:RingSpot(tp, kit.Range, math.atan2(away.Z, away.X) + B.wanderOff)
                else
                    desired = B.pos
                end
                desired = B:Clamp(desired)
                local speed = d.Speed * kit.SpeedMul * (1 + 0.18 * (B.phase - 1)) * slow * (d.Boost or 1) * (d.SizeK or 1)
                local to = Flat(desired - B.pos)
                local want = (to.Magnitude > 0.3) and to.Unit * math.min(speed, to.Magnitude * 2) or Vector3.zero
                if not (now >= B.hold and B.active == 0) then want *= 0.3 end -- (attacking: a slow drift, not a dead stop)
                local ev = EVADE[SigKey(B)] or EVADE_DEFAULT
                if ev and not B.rooted then
                    B.evT = (B.evT or 0) + dt * ev.Rate * (0.85 + 0.3 * math.sin(now * 0.37))
                    local perp = Unit(tp - B.pos):Cross(Vector3.yAxis)
                    want += perp * math.cos(B.evT) * ev.Amp * (d.Boost or 1) * (d.SizeK or 1) * ev.Rate * ((B.active > 0) and 0.5 or 1)
                    if ev.Dodge and B.active == 0 and not B.roaring then
                        B.nextDodge = B.nextDodge or (now + ev.Dodge)
                        if now >= B.nextDodge then
                            B.nextDodge = now + ev.Dodge * (0.8 + math.random() * 0.6)
                            B.dodgeV = perp * ((math.random() < 0.5) and -1 or 1) * (28 + math.random() * 10)
                        end
                    end
                end
                if B.dodgeV then
                    want += B.dodgeV
                    B.dodgeV *= math.exp(-dt * 4)
                    if B.dodgeV.Magnitude < 1 then B.dodgeV = nil end
                end
                if B.rooted then want = Vector3.zero; B.dodgeV = nil end
                B.vel = B.vel or Vector3.zero
                local dv = want - B.vel
                local acc = 70 * dt
                if dv.Magnitude > acc then dv = dv.Unit * acc end
                B.vel += dv
                B.pos = d.Step(B.pos, B:Clamp(B.pos + B.vel * dt), 400, dt)
            else
                B.vel = Vector3.zero -- (a dash / glide owns the position; start from rest after it)
            end
            B.pos = B:Clamp(Vector3.new(B.pos.X, d.SpawnPos.Y, B.pos.Z))
            local shown = B.pos + Vector3.new(0, B.yOff or 0, 0)
            local flinch = M.Flinch(B, frac, now) -- (0.99u hit feedback: a short rock back every 10% of health)
            if B.faceDir and now < (B.faceUntil or 0) then
                model:PivotTo(CFrame.lookAt(shown, shown + B.faceDir) * flinch)
            elseif r then
                model:PivotTo(CFrame.lookAt(shown, Vector3.new(r.Position.X, shown.Y, r.Position.Z)) * flinch)
            else
                model:PivotTo(CFrame.new(shown) * flinch)
            end
            local tick = nil -- (0.68: the signatures' ticks went with them)
            if tick and (not RunService:IsServer() or now - (B.lastSigTick or 0) >= 0.1) then B.lastSigTick = now; tick(B, now) end
            -- (wings / clock hands / shards; server-run party bosses pose at 10 Hz -- every posed part replicates)
            -- (BOSS LOOK v2: a boss in the pill-family look is posed by AimRngShared/BossLook, not its kit's old Animate)
            if (kit.Animate or B.looked) and (not RunService:IsServer() or now - (B.lastPose or 0) >= 0.1) then
                B.lastPose = now
                if B.looked == nil then B.looked = model:GetAttribute("BossLook") == 2 end
                if B.looked then M.LookAnimate(B, model:GetPivot(), now) else kit.Animate(B, model:GetPivot(), now) end
            end
            lastPos = B.pos
            -- attacks (v3): ONE move at a time, in the rotation's order: TELL (it plants + charges, the bar names the move),
            -- the move, then a RECOVERY window before the next one
            if r and not B.roaring and now >= B.nextMove and B.active == 0 then
                local fn, callout, light = PickMove(B)
                B.active = 1
                B.nextMove = math.huge
                task.spawn(function()
                    if callout then B:Title(B.kit.Names[B.phase] .. "   >>  " .. callout) end
                    local stop = B:Charge(0.5)
                    B:Wait(B:W(0.5))
                    stop()
                    local ok, err = pcall(fn, B)
                    if not ok then warn("[BossAI] " .. tostring(err)) end
                    if B:Alive() and not B.roaring and not B.staggered then B:Title(B.kit.Names[B.phase]) end
                    B.active = 0
                    local rec = ((kit.Recover or RECOVER)[B.phase] or 1.8) * B.pace
                    if light or (B.mechN or 0) > 0 then rec = math.max(rec, MECH_RECOVER * B.pace) end
                    B.nextMove = os.clock() + rec
                end)
            end
            RunService.Heartbeat:Wait()
        end
        -- death: a big burst where it fell (only when actually killed, not on floor cleanup)
        if model:GetAttribute("Dead") == true then
            VFX.Burst(d.Fx, lastPos, kit.Color, 30, "Explosion")
            VFX.Shake(lastPos, 2.5)
            VFX.ScreenFlash(Color3.new(1, 1, 1), 0.35)
        end
    end)
end

-- (0.89 WORLD FOES: each world's superboss kit + evade; inside a function on M -- the main chunk is at Luau's local limit)
M.RegisterWorldBosses = function()
    local ok, WF = pcall(require, Shared:WaitForChild("WorldFoes"))
    if not ok then return end
    local H = { M = M, EA = EA, Pose = Pose, Unit = Unit, VFX = VFX, Info = Info, Wipe = Wipe, Part = Part, Flat = Flat }
    for id, sup in pairs(WF.Super) do
        local okK, kit = pcall(sup.Kit, H)
        if okK and kit then
            SUPER[id] = kit
            EVADE["Super" .. id] = sup.Evade or EVADE_DEFAULT
        else
            warn("[BossAI] world boss " .. id .. " kit failed: " .. tostring(kit))
        end
    end
end
M.RegisterWorldBosses()
-- (MAPS V2 2026-10-30: the maps-only guardians -- AimRngShared/MapBosses Defs[id] = { Kit(H), Evade } -> KITS[id] + EVADE[id])
M.RegisterMapBosses = function()
    local mod = Shared:FindFirstChild("MapBosses")
    local ok, MB = pcall(function() return mod and require(mod) end)
    if not (ok and type(MB) == "table" and MB.Defs) then
        if mod then warn("[BossAI] MapBosses failed: " .. tostring(MB)) end
        return
    end
    local H = { M = M, EA = EA, Pose = Pose, Unit = Unit, VFX = VFX, Info = Info, Part = Part, Flat = Flat, Body = Body, Sound = Sound }
    for id, def in pairs(MB.Defs) do
        local okK, kit = pcall(def.Kit, H)
        if okK and type(kit) == "table" then
            KITS[id] = kit
            EVADE[id] = def.Evade or EVADE_DEFAULT
        else
            warn("[BossAI] map boss " .. tostring(id) .. " kit failed: " .. tostring(kit))
        end
    end
end
M.RegisterMapBosses()

return BossAI
