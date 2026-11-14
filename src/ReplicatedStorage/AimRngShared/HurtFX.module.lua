--!nocheck
-- HURT FX (owner 2026-10-03: "it's rather hard to see when you take damage, alongside to tell when you're in an area of
-- effect ... without visual clutter"). Client only. Everything sits at the screen EDGES or as a thin ring around the
-- crosshair -- nothing ever covers the middle of the screen, so it never gets in the way of aiming:
--   * Hit arcs      a thin arc around the crosshair pointing at whoever hit you; it keeps pointing there while you turn
--   * Edge glow     the screen edges flash on a hit (stronger for bigger hits, coloured by the element)
--   * Danger        while you stand in an attack's area (a telegraph winding up, a lingering pool) the edges glow in that
--                   area's colour and a small pip pulses under the crosshair -- you know without looking at the floor
--   * Hit ring      (0.67) a ring pops round the crosshair on every hit, the damage under it
--   * Low health    below 40% health the edges pulse red, faster and stronger the lower you go
--   * Hurt sound    a thump (our own clip, never a Roblox sound)
-- Areas: EnemyAttacks tags its floor areas "AimDanger" (and the Arena's safe circles "AimSafe"); tags replicate, so
-- party dungeons (server-built attacks) work the same as solo ones.
--
--   HurtFX.Init(healthFn)          healthFn() -> hp, maxHp
--   HurtFX.Damage(dmg, maxHp, kind, fromPos?)
--   HurtFX.Arc(fromPos)            (solo dungeons: the client decides a hit, so it shows the arc at once)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local HurtFX = {}
HurtFX.DANGER_TAG = "AimDanger"
HurtFX.SAFE_TAG = "AimSafe"

local LocalPlayer = Players.LocalPlayer
local RED = Color3.fromRGB(255, 40, 40)
local KIND_COLORS = {
    Fire = Color3.fromRGB(255, 110, 20), Burn = Color3.fromRGB(255, 110, 20), Cold = Color3.fromRGB(90, 190, 255),
    Chaos = Color3.fromRGB(120, 220, 60), Bleed = Color3.fromRGB(200, 0, 20),
    -- (UPDATE 8 DEFENCE) the damage types (Kinetic stays the plain red)
    Heat = Color3.fromRGB(255, 110, 20), Cryo = Color3.fromRGB(90, 190, 255), Volt = Color3.fromRGB(255, 225, 60), Void = Color3.fromRGB(175, 95, 255),
}
-- (0.62, owner: "Still really no way to tell if youre getting hit"): bigger, longer arcs, stronger edges, a louder thump and
-- a short full-screen HURT PULSE (red tint + a little desaturation, Lighting ColorCorrection -- nothing drawn over the aim)
local ARC_RADIUS, ARC_LIFE, ARC_MAX = 118, 1.5, 4
local cc = nil -- the hurt pulse (ColorCorrectionEffect)
local pulseI = 0

local gui, edges, pip, arcs = nil, {}, nil, {}
-- (0.67, owner: "The visibility and knowing when you lose health is still bad"): a HIT RING round the crosshair -- where
-- your eyes already are -- pops on every hit (thicker for bigger hits) with the damage under it; it sits outside the
-- crosshair (radius ~40 px) and is gone in under half a second, so it never covers the target
local ring, ringNum, ringAt, ringK = nil, nil, -99, 0
local healthFn = nil
local hurtI, hurtCol = 0, RED
local dangerI, dangerCol, dangerHas = 0, RED, false
local lastSound = 0

local function Edge(name, size, pos, rot, seq)
    local f = Instance.new("Frame")
    f.Name = name; f.Size = size; f.Position = pos; f.BorderSizePixel = 0
    f.BackgroundColor3 = RED; f.BackgroundTransparency = 1; f.Parent = gui
    local g = Instance.new("UIGradient")
    g.Rotation = rot
    g.Transparency = seq
    g.Parent = f
    table.insert(edges, f)
end

local function Build()
    gui = Instance.new("ScreenGui")
    gui.Name = "AimHurtFX"; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false
    gui.DisplayOrder = -1 -- (under the HUD: health bar / ammo stay readable through a glow)
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    -- solid at the screen edge, gone a short way in (a curve, so there's no visible band)
    local inward = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.35, 0.55), NumberSequenceKeypoint.new(1, 1) })
    local outward = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.65, 0.55), NumberSequenceKeypoint.new(1, 0) })
    Edge("Top", UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0), 90, inward) -- (0.67: 14% / 9% -> 20% / 13%)
    Edge("Bottom", UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0.8), 90, outward)
    Edge("Left", UDim2.fromScale(0.13, 1), UDim2.fromScale(0, 0), 0, inward)
    Edge("Right", UDim2.fromScale(0.13, 1), UDim2.fromScale(0.87, 0), 0, outward)
    ring = Instance.new("Frame")
    ring.Name = "HitRing"; ring.AnchorPoint = Vector2.new(0.5, 0.5); ring.Position = UDim2.fromScale(0.5, 0.5)
    ring.Size = UDim2.fromOffset(80, 80); ring.BackgroundTransparency = 1; ring.Parent = gui
    for i, nm in ipairs({ "InkRing", "RedRing" }) do -- (a dark ring under the coloured one: reads on any biome)
        local f = Instance.new("Frame")
        f.Name = nm; f.AnchorPoint = Vector2.new(0.5, 0.5); f.Position = UDim2.fromScale(0.5, 0.5); f.Size = UDim2.fromScale(1, 1)
        f.BackgroundTransparency = 1; f.ZIndex = i; f.Parent = ring
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = f
        local st = Instance.new("UIStroke"); st.Color = (i == 1) and Color3.new(0, 0, 0) or RED; st.Thickness = (i == 1) and 6 or 3
        st.Transparency = 1; st.Parent = f
    end
    ringNum = Instance.new("TextLabel")
    ringNum.Name = "HitNum"; ringNum.AnchorPoint = Vector2.new(0.5, 0); ringNum.Position = UDim2.new(0.5, 0, 0.5, 96) -- (0.78: was +52, too close to the crosshair)
    ringNum.Size = UDim2.fromOffset(140, 24); ringNum.BackgroundTransparency = 1; ringNum.Font = Enum.Font.GothamBlack
    ringNum.TextSize = 20; ringNum.TextColor3 = Color3.fromRGB(255, 80, 70); ringNum.TextStrokeColor3 = Color3.new(0, 0, 0)
    ringNum.TextTransparency = 1; ringNum.TextStrokeTransparency = 1; ringNum.Text = ""; ringNum.Parent = gui
    -- danger pip: a small diamond under the crosshair
    pip = Instance.new("Frame")
    pip.Name = "DangerPip"; pip.AnchorPoint = Vector2.new(0.5, 0.5); pip.Position = UDim2.new(0.5, 0, 0.5, 34)
    pip.Size = UDim2.fromOffset(14, 14); pip.Rotation = 45; pip.BorderSizePixel = 0; pip.BackgroundTransparency = 1
    pip.Parent = gui
    -- (owner 2026-10-05: "you usually cant tell that you are in it") a loud callout over the crosshair while you're in one
    local mv = Instance.new("TextLabel")
    mv.Name = "DangerMove"; mv.AnchorPoint = Vector2.new(0.5, 0.5); mv.Position = UDim2.new(0.5, 0, 0.5, -120) -- (0.78: was -64, over the aim)
    mv.Size = UDim2.fromOffset(220, 34); mv.BackgroundTransparency = 1; mv.Font = Enum.Font.GothamBlack; mv.TextSize = 26
    mv.Text = "MOVE!"; mv.TextColor3 = Color3.fromRGB(255, 70, 60); mv.TextStrokeColor3 = Color3.new(0, 0, 0)
    mv.TextTransparency = 1; mv.TextStrokeTransparency = 1; mv.Parent = gui
    local st = Instance.new("UIStroke"); st.Color = Color3.new(0, 0, 0); st.Thickness = 1; st.Transparency = 1; st.Parent = pip
end

local function NewArc()
    local f = Instance.new("Frame")
    f.Name = "HitArc"; f.AnchorPoint = Vector2.new(0.5, 0.5); f.Size = UDim2.fromOffset(104, 10)
    f.BorderSizePixel = 0; f.BackgroundColor3 = RED; f.BackgroundTransparency = 1; f.Parent = gui
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = f
    local g = Instance.new("UIGradient") -- (tapered ends: reads as a curved arc, not a bar)
    g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.1), NumberSequenceKeypoint.new(0.7, 0.1), NumberSequenceKeypoint.new(1, 1) })
    g.Parent = f
    local s = Instance.new("UIStroke"); s.Color = Color3.new(0, 0, 0); s.Thickness = 2; s.Transparency = 1; s.Parent = f
    return { Frame = f, Stroke = s, Pos = nil, At = -99, Col = RED }
end

-- is this point standing in a tagged area? (flat footprint; a column reaches any height above its floor)
local function Inside(part, p)
    local rel = part.CFrame:PointToObjectSpace(p)
    local s = part.Size
    if part.Shape == Enum.PartType.Cylinder then
        -- discs are laid flat (axis = local X, pointing up)
        if rel.X < -4 then return false end
        return rel.Y * rel.Y + rel.Z * rel.Z <= (s.Y * 0.5) ^ 2
    end
    local w = part.CFrame:VectorToObjectSpace(Vector3.yAxis) -- (boxes lie flat: local Y is up)
    if math.abs(w.Y) < 0.9 then return false end
    return math.abs(rel.X) <= s.X * 0.5 and math.abs(rel.Z) <= s.Z * 0.5 and rel.Y >= -4
end

-- (party floors all overlap the same coordinates: only YOUR floor's attack areas count -- owner 2026-10-05: "players on
-- the previous floor get hit by enemies fighting the players on the next floor")
local function RunIdOf(inst)
    local node = inst
    while node and node ~= Workspace do
        local id = node:GetAttribute("RunId")
        if id then return id end
        node = node.Parent
    end
    return nil
end
local function Mine(part) return RunIdOf(part) == LocalPlayer:GetAttribute("RunId") end
local function Step(dt)
    local now = os.clock()
    -- danger: a few tagged parts at most, checked every frame (cheap)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local inDanger, col = false, nil
    if root then
        local p = root.Position - Vector3.new(0, 2.5, 0) -- (feet)
        local safe = false
        for _, s in ipairs(CollectionService:GetTagged(HurtFX.SAFE_TAG)) do
            if s:IsA("BasePart") and s:IsDescendantOf(Workspace) and Mine(s) and Inside(s, p) then safe = true break end
        end
        if not safe then
            for _, d in ipairs(CollectionService:GetTagged(HurtFX.DANGER_TAG)) do
                if d:IsA("BasePart") and d:IsDescendantOf(Workspace) and Mine(d) and Inside(d, p) then inDanger, col = true, d.Color break end
            end
        end
    end
    if col then dangerCol = col:Lerp(RED, 0.6) end -- (pale biome colours -- ice, storm -- read as danger too)
    dangerHas = inDanger
    dangerI += ((inDanger and 1 or 0) - dangerI) * math.min(1, dt * 14)
    local pulse = 0.5 + 0.5 * math.sin(now * 14)
    local dangerA = dangerI * (0.5 + 0.25 * pulse) -- (was 0.28-0.42: easy to miss)

    hurtI *= math.exp(-dt * 3.2)
    pulseI *= math.exp(-dt * 7)
    if cc then
        cc.TintColor = Color3.new(1, 1 - 0.35 * pulseI, 1 - 0.35 * pulseI)
        cc.Saturation = -0.35 * pulseI
        cc.Enabled = pulseI > 0.01
    end

    local lowA = 0
    if healthFn then
        local hp, mx = healthFn()
        if hp and mx and mx > 0 and hp > 0 and hp < mx * 0.4 then -- (0.67: from 40%, about twice as strong)
            local k = 1 - hp / (mx * 0.4)
            local beat = math.max(0, math.sin(now * (6.4 + 3 * k))) ^ 3 -- (a heartbeat that speeds up as you drop)
            lowA = (0.18 + 0.32 * k) * (0.45 + 0.55 * beat)
        end
    end
    -- the hit ring round the crosshair
    if ring then
        local age = now - ringAt
        local st = ring.RedRing:FindFirstChildOfClass("UIStroke")
        local inkS = ring.InkRing:FindFirstChildOfClass("UIStroke")
        if age < 0.45 then
            local f = 1 - age / 0.45
            local d = 70 + 26 * math.min(1, age / 0.08) - 8 * (age / 0.45) -- (pops out, then settles)
            ring.Size = UDim2.fromOffset(d, d)
            st.Color = hurtCol
            st.Thickness = 2.5 + 4 * ringK
            st.Transparency = 1 - f
            inkS.Thickness = 6 + 4 * ringK; inkS.Transparency = 1 - 0.55 * f
            ringNum.TextTransparency = 1 - f
            ringNum.TextStrokeTransparency = 1 - 0.8 * f
            ringNum.Position = UDim2.new(0.5, 0, 0.5, 96 - 10 * (age / 0.45))
        elseif st.Transparency < 1 then
            st.Transparency = 1
            inkS.Transparency = 1
            ringNum.TextTransparency = 1; ringNum.TextStrokeTransparency = 1
        end
    end

    local a = math.max(hurtI, dangerA, lowA)
    local wsum = hurtI + dangerA + lowA
    local c = RED
    if wsum > 0.001 then
        local r = (hurtCol.R * hurtI + dangerCol.R * dangerA + RED.R * lowA) / wsum
        local g = (hurtCol.G * hurtI + dangerCol.G * dangerA + RED.G * lowA) / wsum
        local b = (hurtCol.B * hurtI + dangerCol.B * dangerA + RED.B * lowA) / wsum
        c = Color3.new(r, g, b)
    end
    for _, e in ipairs(edges) do
        e.BackgroundTransparency = 1 - math.clamp(a, 0, 0.9)
        e.BackgroundColor3 = c
    end
    pip.BackgroundColor3 = dangerCol
    pip.BackgroundTransparency = 1 - dangerI * (0.55 + 0.45 * pulse)
    local mv = gui:FindFirstChild("DangerMove")
    if mv then
        mv.TextTransparency = 1 - dangerI * (0.6 + 0.4 * pulse)
        mv.TextStrokeTransparency = 1 - dangerI * 0.8
        mv.Size = UDim2.fromOffset(220, 34 + 6 * pulse * dangerI)
    end
    pip:FindFirstChildOfClass("UIStroke").Transparency = 1 - dangerI * 0.6

    -- arcs: keep pointing at the attacker as the camera turns
    local cam = Workspace.CurrentCamera
    for _, arc in ipairs(arcs) do
        local age = now - arc.At
        if arc.Pos and age < ARC_LIFE and cam then
            local rel = cam.CFrame:PointToObjectSpace(arc.Pos)
            local ang = math.atan2(rel.X, -rel.Z) -- 0 = straight ahead, + = to the right
            arc.Frame.Position = UDim2.new(0.5, math.sin(ang) * ARC_RADIUS, 0.5, -math.cos(ang) * ARC_RADIUS)
            arc.Frame.Rotation = math.deg(ang)
            local fade = age < 0.5 and 1 or 1 - (age - 0.5) / (ARC_LIFE - 0.5)
            arc.Frame.BackgroundColor3 = arc.Col
            arc.Frame.BackgroundTransparency = 1 - 0.95 * fade
            arc.Stroke.Transparency = 1 - 0.7 * fade
            arc.Frame.Size = UDim2.fromOffset(104 + 24 * math.max(0, 1 - age / 0.2), 10) -- (it lands with a little pop)
        elseif arc.Frame.BackgroundTransparency < 1 then
            arc.Frame.BackgroundTransparency = 1
            arc.Stroke.Transparency = 1
            arc.Pos = nil
        end
    end
end

function HurtFX.Init(fn)
    if gui then return end
    healthFn = fn
    Build()
    for i = 1, ARC_MAX do arcs[i] = NewArc() end
    cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "AimHurtPulse"; cc.Enabled = false
    cc.Parent = game:GetService("Lighting")
    RunService.RenderStepped:Connect(Step)
end

function HurtFX.Arc(fromPos: Vector3?, color: Color3?)
    if not gui or typeof(fromPos) ~= "Vector3" then return end
    local now = os.clock()
    local cam = Workspace.CurrentCamera
    -- the same attacker again (or close by): refresh its arc instead of stacking a new one
    local best, oldest = nil, nil
    for _, arc in ipairs(arcs) do
        if arc.Pos and now - arc.At < ARC_LIFE and (arc.Pos - fromPos).Magnitude < 6 then best = arc break end
        if not oldest or arc.At < oldest.At then oldest = arc end
    end
    local arc = best or oldest
    if cam and (cam.CFrame.Position - fromPos).Magnitude < 1 then return end
    arc.Pos, arc.At, arc.Col = fromPos, now, color or RED
end

local SoundHelper
-- (ENEMY ATTACKS PILOT 2026-10-30) ONE EFFECT A BURST: an enemy's 3-round burst landed as three hits -- three ring pops, two thumps.
-- Hits within MERGE_GAP of the last one (and MERGE_MAX of the group's first) join the group: the ring's number grows to the group's
-- total, the edge glow follows the group's size, the arc refreshes -- but nothing re-pops and no second thump. Health / damage
-- numbers are untouched (this is only the hurt FX).
local MERGE_GAP, MERGE_MAX = 0.3, 0.6
local grpStart, grpLast, grpDmg = -99, -99, 0
HurtFX.Merged = 0 -- (Studio probe: hits folded into a group)
function HurtFX.Damage(dmg: number, maxHp: number, kind: string?, fromPos: Vector3?)
    if not gui then return end
    local col = KIND_COLORS[kind or ""] or RED
    local tick = (kind == "Burn" or kind == "Bleed") -- (damage over time: a faint pulse, no sound)
    local now0 = os.clock()
    if not tick and now0 - grpLast <= MERGE_GAP and now0 - grpStart <= MERGE_MAX then
        grpLast = now0
        grpDmg += dmg
        HurtFX.Merged += 1
        if RunService:IsStudio() and LocalPlayer then LocalPlayer:SetAttribute("DevHurtMerged", HurtFX.Merged) end -- (probe)
        local kg = (maxHp and maxHp > 0) and grpDmg / maxHp or 0.1
        local strength = math.clamp(0.45 + kg * 2.2, 0.45, 0.88)
        if strength >= hurtI then hurtCol = col end
        hurtI = math.max(hurtI, strength)
        if fromPos then HurtFX.Arc(fromPos, col ~= RED and col or nil) end
        if ring then
            ringK = math.max(ringK, math.clamp(kg * 4, 0, 1))
            ringNum.Text = "-" .. ((grpDmg >= 1e5) and string.format("%.0fK", grpDmg / 1000) or tostring(math.round(grpDmg)))
            ringNum.TextSize = 18 + math.floor(10 * ringK)
        end
        return
    end
    if not tick then
        grpStart, grpLast, grpDmg = now0, now0, dmg
        if RunService:IsStudio() and LocalPlayer then LocalPlayer:SetAttribute("DevHurtGroups", (LocalPlayer:GetAttribute("DevHurtGroups") or 0) + 1) end -- (probe)
    end
    local k = (maxHp and maxHp > 0) and dmg / maxHp or 0.1
    local strength = tick and 0.15 or math.clamp(0.45 + k * 2.2, 0.45, 0.88)
    if strength >= hurtI then hurtCol = col end
    hurtI = math.max(hurtI, strength)
    if not tick then pulseI = math.max(pulseI, math.clamp(0.55 + k * 3, 0.55, 1)) end
    if fromPos then HurtFX.Arc(fromPos, col ~= RED and col or nil) end
    if not tick and ring then
        ringAt, ringK = os.clock(), math.clamp(k * 4, 0, 1)
        ringNum.Text = "-" .. ((dmg >= 1e5) and string.format("%.0fK", dmg / 1000) or tostring(math.round(dmg)))
        ringNum.TextSize = 18 + math.floor(10 * ringK)
    end
    local now = os.clock()
    if not tick and now - lastSound > 0.2 then
        lastSound = now
        SoundHelper = SoundHelper or require(script.Parent:WaitForChild("SoundHelper"))
        pcall(SoundHelper.Play, "PlayerHurt")
    end
end

function HurtFX.InDanger(): boolean return dangerHas end

return HurtFX
