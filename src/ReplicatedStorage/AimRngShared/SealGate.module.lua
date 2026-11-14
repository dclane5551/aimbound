--!nocheck
-- SEAL GATE (2026-10-26, owner: the room barriers "look very lazy and bad, they clip through the world and come across as very
-- low quality, they have no progress bar"). The client's barrier across a sealed room's way on (LinkedRooms SEAL; DungeonClient
-- builds one per sealed door from LinkedRooms.SealFrame):
--   * a FRAME, not a slab: two dark pylons set into the path's walls (their outer faces sit SET_IN studs into the rock, so a
--     rough terrain wall swallows them instead of showing a gap), a header between them, a footing trim -- the field only ever
--     spans pylon to pylon, so nothing of it touches the rock, the floor or the opening's top (H stays under PATH_H 14)
--   * the field = BEAMS neon bars + a faint accent sheet (SurfaceGui, lit by itself) between the pylons
--   * PROGRESS on the gate itself: the header's display reads "CLEAR THE ROOM  n LEFT" over a bar, and the beams go dark from the
--     top as the room empties (5 beams = a beam per 20%) -- so the gate drains as you clear
--   * OPEN: the strips and the bar turn green, the beams go out top-down, then the whole gate sinks into the floor (no flash)
-- ~16 parts, no lights, no particles (performance first). Neon parts carry KeepNeon (the NeonTamer leaves them alone).
-- SOUNDS (2026-10-26, SoundHelper GateBeam / GateOpen, 3D at the gate): a relay clunk as each beam goes dark, and on OPEN a latch
-- + seal release, the sink, then a thud timed to the frame bottoming out (0.7 s wait + 1.1 s fall). Played from a sound-only part
-- of its own (the gate model is destroyed when the sink ends: its sound would be cut before the thud).
-- API: SealGate.Build(parent, cf, width, accent) -> gate; gate:Set(left, total); gate:Open(); gate.Model
local TweenService = game:GetService("TweenService")
local Shared = script.Parent

local SealGate = {}
SealGate.H = 13 -- (pylons' height above the floor; caps reach H + 0.5 -- under the path opening, LinkedRooms.PATH_H 14)
SealGate.SINK = 1.5 -- (how far the pylons go into the floor: planted, never floating on an uneven floor)
SealGate.SET_IN = 0.6 -- (the pylons' outer faces this far into the path's walls)
SealGate.PYLON_W, SealGate.PYLON_D = 2.2, 2.8
SealGate.BEAMS = 5
SealGate.METAL = Color3.fromRGB(24, 24, 30)
SealGate.TRIM = Color3.fromRGB(11, 11, 15) -- (the caps / footing / lip: the ink edge round the lighter body)
SealGate.GOOD = Color3.fromRGB(90, 228, 140) -- (UIStyle Good)
-- (owner: "make sure the beam's colors match the environment") Neon blooms a bright colour toward white / yellow -- the beams and
-- strips are drawn this much darker so they RENDER in the biome's colour (Molten's lava orange read yellow at full strength)
SealGate.NEON_DIM = 0.3

local Gate = {}
Gate.__index = Gate

-- a 3D sound at the gate's header height, on an invisible part that outlives the gate
local function Sound(cf: CFrame, parent: Instance?, kind: string)
    if not parent or not parent.Parent then return end
    local ok, SoundHelper = pcall(require, Shared:WaitForChild("SoundHelper"))
    if not ok then return end
    local p = Instance.new("Part")
    p.Name = "GateSound"
    p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
    p.Transparency = 1
    p.Size = Vector3.new(0.2, 0.2, 0.2)
    p.CFrame = cf * CFrame.new(0, SealGate.H * 0.6, 0)
    p.Parent = parent
    SoundHelper.PlayAt(kind, p)
    game:GetService("Debris"):AddItem(p, 3.2)
end

-- cf: the doorway's centre on the floor, LookVector pointing back into the room being cleared (the parts' Front faces it)
function SealGate.Build(parent: Instance, cf: CFrame, width: number, accent: Color3): any
    local UIStyle = require(Shared:WaitForChild("UIStyle"))
    local H, S, pw, pd = SealGate.H, SealGate.SINK, SealGate.PYLON_W, SealGate.PYLON_D
    local m = Instance.new("Model")
    m.Name = "SealGate"
    local function P(name: string, size: Vector3, at: Vector3, col: Color3, neon: boolean?): BasePart
        local p = Instance.new("Part")
        p.Name = name
        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
        p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
        p.Color = col
        p.Size = size
        p.CFrame = cf * CFrame.new(at)
        if neon then p:SetAttribute("KeepNeon", true); p:SetAttribute("Glow", true) end
        p.Parent = m
        return p
    end
    local neonCol = accent:Lerp(Color3.new(0, 0, 0), SealGate.NEON_DIM)
    local px = width / 2 + SealGate.SET_IN - pw / 2 -- (pylon centre, across)
    local inner = 2 * (px - pw / 2) -- (the clear span between the pylons)
    local strips = {}
    for _, s in ipairs({ -1, 1 }) do
        P("Pylon", Vector3.new(pw, H + S, pd), Vector3.new(s * px, (H - S) / 2, 0), SealGate.METAL)
        P("Footing", Vector3.new(pw + 0.4, 1, pd + 0.4), Vector3.new(s * px, 0.2, 0), SealGate.TRIM)
        P("Cap", Vector3.new(pw + 0.4, 0.5, pd + 0.4), Vector3.new(s * px, H + 0.25, 0), SealGate.TRIM)
        -- the accent strip down the pylon's inner face (the field's edge)
        table.insert(strips, P("Strip", Vector3.new(0.14, H - 3.4, 0.7), Vector3.new(s * (px - pw / 2 - 0.07), (H - 2) / 2 + 0.2, 0), neonCol, true))
    end
    P("Header", Vector3.new(inner + 0.6, 1.8, pd - 0.6), Vector3.new(0, H - 0.9, 0), SealGate.METAL)
    P("Lip", Vector3.new(inner, 0.22, pd - 0.3), Vector3.new(0, H - 1.9, 0), SealGate.TRIM)
    -- the header's display: "CLEAR THE ROOM   n LEFT" + the progress bar (lit by itself: readable in the darkest biome)
    local disp = P("Display", Vector3.new(inner - 1.2, 1.36, 0.05), Vector3.new(0, H - 0.9, -(pd - 0.6) / 2 - 0.03), SealGate.METAL)
    disp.Transparency = 1
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.LightInfluence = 0
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 60
    sg.Parent = disp
    local C = UIStyle.Colors
    local function Txt(name: string, x: number, align: Enum.TextXAlignment, col: Color3): TextLabel
        local t = Instance.new("TextLabel")
        t.Name = name
        t.BackgroundTransparency = 1
        t.Position = UDim2.new(x, x > 0 and -6 or 6, 0, 4)
        t.Size = UDim2.new(0.5, 0, 0.6, 0)
        t.Font = UIStyle.Font
        t.TextSize = 42 -- (one size for both: TextScaled gave the shorter word bigger letters)
        t.TextXAlignment = align
        t.TextColor3 = col
        t.Text = ""
        t.Parent = sg
        return t
    end
    local title = Txt("Title", 0, Enum.TextXAlignment.Left, C.Text or Color3.new(1, 1, 1))
    title.Text = "CLEAR THE ROOM"
    local count = Txt("Count", 0.5, Enum.TextXAlignment.Right, accent)
    local track = Instance.new("Frame")
    track.Name = "Track"
    track.BorderSizePixel = 0
    track.BackgroundColor3 = accent:Lerp(Color3.new(0, 0, 0), 0.72) -- (a dim track of the accent: the whole bar reads before any kill)
    track.Position = UDim2.new(0, 6, 0.72, 0)
    track.Size = UDim2.new(1, -12, 0.2, 0)
    track.Parent = sg
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.BorderSizePixel = 0
    fill.BackgroundColor3 = Color3.new(1, 1, 1)
    fill.Size = UDim2.fromScale(0, 1)
    fill.Parent = track
    local grad = UIStyle.FacetGrad(accent, accent:Lerp(Color3.new(0, 0, 0), 0.35)) -- (the icons' facet look)
    grad.Parent = fill
    -- the field: a faint accent sheet, strongest at the floor
    local sheet = P("Field", Vector3.new(inner, H - 2.2, 0.05), Vector3.new(0, (H - 2.2) / 2 + 0.2, 0), accent)
    sheet.Transparency = 1
    local fg = Instance.new("SurfaceGui")
    fg.Face = Enum.NormalId.Front
    fg.LightInfluence = 0
    fg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    fg.PixelsPerStud = 8
    fg.Parent = sheet
    local glow = Instance.new("Frame")
    glow.BorderSizePixel = 0
    glow.BackgroundColor3 = accent
    glow.BackgroundTransparency = 0
    glow.Size = UDim2.fromScale(1, 1)
    glow.Parent = fg
    local fgr = Instance.new("UIGradient")
    fgr.Rotation = 90
    fgr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.97), NumberSequenceKeypoint.new(0.7, 0.88), NumberSequenceKeypoint.new(1, 0.74) })
    fgr.Parent = glow
    -- the beams, top first (they go dark in this order as the room empties)
    local beams = {}
    local y0, y1 = 1.4, H - 2.9
    for k = 1, SealGate.BEAMS do
        local y = y1 - (k - 1) * (y1 - y0) / math.max(1, SealGate.BEAMS - 1)
        local b = P("Beam" .. k, Vector3.new(inner + 0.3, 0.2, 0.2), Vector3.new(0, y, 0), neonCol, true)
        b.Shape = Enum.PartType.Cylinder
        table.insert(beams, b)
    end
    -- solid to you and your shots: the doorway wall to wall, floor to over the gate
    local col = P("Collider", Vector3.new(width + 1, H + 1, 1.2), Vector3.new(0, (H + 1) / 2, 0), accent)
    col.Transparency = 1
    col.CanCollide, col.CanQuery = true, true
    m.PrimaryPart = col
    m.Parent = parent
    return setmetatable({ Model = m, Beams = beams, Strips = strips, Fill = fill, Grad = grad, Count = count, Title = title,
        Collider = col, Accent = accent, Lit = SealGate.BEAMS, At = -1, Cf = cf, Born = os.clock() }, Gate)
end

-- left / total: the room's foes still standing and the most seen (the bar's whole)
function Gate:Set(left: number, total: number)
    if self.Opening then return end
    total = math.max(total or 0, left or 0, 1)
    local prog = math.clamp(1 - (left or 0) / total, 0, 1)
    self.Count.Text = string.format("%d LEFT", left or 0)
    if math.abs(prog - self.At) > 0.001 then
        self.At = prog
        TweenService:Create(self.Fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(prog, 1) }):Play()
    end
    -- a beam goes dark for each 1 / BEAMS of the room cleared (top first); they never come back on
    local lit = math.max(1, SealGate.BEAMS - math.floor(prog * SealGate.BEAMS + 1e-6))
    -- (one clunk per drop, not per beam; none for a gate built on a room that was already part cleared)
    if self.Lit > lit and os.clock() - self.Born > 0.5 then Sound(self.Cf, self.Model.Parent, "GateBeam") end
    while self.Lit > lit do
        local b = self.Beams[SealGate.BEAMS - self.Lit + 1]
        self.Lit -= 1
        if b then TweenService:Create(b, TweenInfo.new(0.35), { Transparency = 0.86 }):Play() end
    end
end

-- the room is clear: green, the beams go out top-down, the gate sinks into the floor; the way is open at once
function Gate:Open()
    if self.Opening then return end
    self.Opening = true
    self.Collider.CanCollide, self.Collider.CanQuery = false, false
    Sound(self.Cf, self.Model.Parent, "GateOpen")
    local good = SealGate.GOOD
    self.Count.Text = "OPEN"
    self.Count.TextColor3 = good
    self.Title.Text = "WAY OPEN"
    self.Grad.Color = ColorSequence.new(good, good:Lerp(Color3.new(0, 0, 0), 0.35))
    TweenService:Create(self.Fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(1, 1) }):Play()
    local goodNeon = good:Lerp(Color3.new(0, 0, 0), SealGate.NEON_DIM)
    for _, s in ipairs(self.Strips) do TweenService:Create(s, TweenInfo.new(0.3), { Color = goodNeon }):Play() end
    for k, b in ipairs(self.Beams) do
        task.delay(0.06 * (k - 1), function()
            if b.Parent then TweenService:Create(b, TweenInfo.new(0.25), { Transparency = 1 }):Play() end
        end)
    end
    local sheet = self.Model:FindFirstChild("Field")
    local fg = sheet and sheet:FindFirstChildOfClass("SurfaceGui")
    local glow = fg and fg:FindFirstChildOfClass("Frame")
    if glow then TweenService:Create(glow, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play() end
    -- then the frame sinks (every part by the same offset, one CFrame value tween: no per-frame Lua)
    task.delay(0.7, function()
        local m = self.Model
        if not m.Parent then return end
        local drop = SealGate.H + SealGate.SINK + 1
        local v = Instance.new("CFrameValue")
        v.Value = CFrame.new()
        local base = {}
        for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then base[p] = p.CFrame end end
        v.Changed:Connect(function(off)
            for p, c in pairs(base) do p.CFrame = off * c end
        end)
        local tw = TweenService:Create(v, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = CFrame.new(0, -drop, 0) })
        tw.Completed:Connect(function() v:Destroy(); if m.Parent then m:Destroy() end end)
        tw:Play()
    end)
end

return SealGate
