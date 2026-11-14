--!nocheck
-- TUTORIAL (Update 6, owner: "We also need to add a proper tutorial. Right now the game is incredibly confusing to new players
-- of this genre" -> a GUIDED FIRST RUN, "but also include hideouts in there. When a player hits level 100, introduce them to
-- maps too"). Client only; nothing here touches the server or the save except two hidden settings.
--   1. THE BASICS: a short hands-on run in its own small hall, built on this client far west of the city (Zones "showcase"
--      box TUTORIAL_*: the hub is parked, nobody else sees you, the bright Showcase light profile). Move, dash, slide, shoot
--      a target, weak spots, three strafing bots with the EXPOSED mark, a gun drop + compare + equip (a loaner rifle, given
--      back at the end), a boss with telegraphed floor attacks and an aimed shield round, the portal home.
--   2. THE HUB: markers walk you to the Dungeon Rift, the skill tree, the forge, the stash and the season pass stand.
--   3. YOUR HIDEOUT: [U] -> GO TO MY HIDEOUT, the stash chest, the practice dummy, build mode, visitors.
--   4. MAPS (separate): the first time you're level 100 a short card set explains maps, sigils, the map room, risk /
--      reward and the map tree.
-- Every step = one short instruction in a card at the top of the screen (never over the crosshair), an objective with
-- progress, a screen marker (diamond on the target, an edge arrow when it's off screen) and it moves on by itself when
-- the objective is done. SKIP at any time; REPLAY from the guide. Inputs are worded for the device you're on.
-- Saved in GameSettings (hidden): TutorialStep 0 = never, 1 = the basics, 10+ = the hub / hideout tour step to resume,
-- 100 = done or skipped; MapsIntro = the level-100 cards were shown.
-- Watchdog: dying, a run starting, leaving the hall or 15 minutes in it end the hands-on part (the hub tour still runs);
-- falling out of the hall puts you back at its start. Nothing here can keep you from playing.
-- hooks (AimRngClient): State(), Rebuild(w), Teleport(cf), Hitmarker(weak), DamageText(amount, weak, crit, pos, model,
--   killed), Estimate(weak, model), MenuOpen(), CloseMenus(), Toast(text), StopTryOn()
local Tutorial = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Shared = script.Parent
local UIStyle = require(Shared:WaitForChild("UIStyle"))
local GameSettings = require(Shared:WaitForChild("GameSettings"))
local ItemData = require(Shared:WaitForChild("ItemData"))
local Zones = require(Shared:WaitForChild("Zones"))
local okSH, SoundHelper = pcall(function() return require(Shared:WaitForChild("SoundHelper")) end)

local LocalPlayer = Players.LocalPlayer
local C = UIStyle.Colors
local New = UIStyle.New
local ACCENT = C.Accent
local LIME = Color3.fromRGB(170, 255, 60)
local RED = Color3.fromRGB(255, 64, 56)
local STEP_HUB, STEP_DONE = 10, 100
local HUB_SPAWN = CFrame.lookAt(Vector3.new(0, 7.2, 24), Vector3.new(0, 7.2, 0)) -- (the hub spawn, facing the gates)

local hooks: any = {}
local S: any = nil -- the running session (nil = no tutorial on screen)
local gui, card, markerGui
local ui: any = {}

local function Sound(n: string) if okSH then pcall(SoundHelper.Play, n) end end
local function State(): any return (hooks.State and hooks.State()) or {} end
local function Root(): BasePart?
    local ch = LocalPlayer.Character
    return ch and ch:FindFirstChild("HumanoidRootPart") or nil
end
local function Alive(): boolean
    local ch = LocalPlayer.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end
local function Save(step: number) pcall(GameSettings.Set, "TutorialStep", step) end
local function Flat(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end

-- ===== inputs, worded for the device ===========================================================================
local function Device(): string
    if GameSettings.TouchOnly() then return "touch" end
    local t = UserInputService:GetLastInputType()
    if string.sub(t.Name, 1, 7) == "Gamepad" or (UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled) then return "pad" end
    return "kb"
end
local PAD = { Fire = "R2", Aim = "L2", Reload = "X", Dash = "LB", Slide = "B", Interact = "RB", Jump = "A" } -- (QOL L3: prompts are RB on a pad)
local TOUCH = { Fire = "FIRE", Aim = "AIM", Reload = "R", Dash = "DASH", Slide = "SLIDE", Jump = "JUMP" }
-- (UI CLEAN R-A2: keys in the off-white Text colour, bold -- no gold)
local function Cap(s: string): string return '<font color="#' .. C.Text:ToHex() .. '"><b>' .. s .. '</b></font>' end
-- a game action's input ("[L-SHIFT]", "LB", "the DASH button")
local function Key(action: string): string
    local d = Device()
    if d == "pad" then return Cap(PAD[action] or "?") end
    if d == "touch" then
        if action == "Interact" then return "the " .. Cap("PICK UP") .. " prompt" end
        return "the " .. Cap(TOUCH[action] or "?") .. " button"
    end
    return Cap("[" .. string.upper(GameSettings.KeyLabel(GameSettings.BindName(action))) .. "]")
end
-- a window's input: its key on a keyboard, else its card in the MENU window (2026-10-20: the side column became MENU)
local function Menu(action: string, tile: string): string
    if Device() == "kb" then return Cap("[" .. string.upper(GameSettings.KeyLabel(GameSettings.BindName(action))) .. "]") end
    return Cap("MENU") .. " > " .. Cap(tile)
end

-- ===== the card (top centre, never over the crosshair) =========================================================
local function BuildUI()
    if gui and gui.Parent then return end
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    gui = New("ScreenGui", { Name = "TutorialGui", ResetOnSpawn = false, DisplayOrder = 6, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg })
    gui:SetAttribute("NoSkin", true)
    UIStyle.ScaleGui(gui)
    card = New("Frame", { Name = "Card", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0.5, -300, 0, 52), Size = UDim2.fromOffset(600, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Visible = false, Parent = gui }, { UIStyle.Corner(2) })
    -- (UI CLEAN R-A2: the run-HUD card -- flat slate, one hairline; no facet / ink edge)
    card.BackgroundColor3 = C.Bg0; card.BackgroundTransparency = 0.06
    UIStyle.Stroke(C.Line, 1).Parent = card
    ui.fit = New("UIScale", { Parent = card })
    New("UIPadding", { PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = card })
    New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = card })
    -- the accent rule across the top (the house window look)
    local rule = New("Frame", { Name = "Rule", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.new(1, 32, 0, 2), LayoutOrder = 0, Parent = card })
    ui.ruleGrad = UIStyle.FacetGrad(ACCENT, UIStyle.Darken(ACCENT, 0.3))
    ui.ruleGrad.Parent = rule
    -- header: TUTORIAL • 3 / 9 • THE BASICS ............ [SKIP]
    local head = New("Frame", { Name = "Head", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 1, Parent = card })
    ui.head = UIStyle.Text({ Name = "Step", Text = "", TextSize = UIStyle.Size.Label, TextColor3 = C.Sub, Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, -110, 1, -2), Parent = head })
    ui.head:SetAttribute("TypeRole", "Label")
    ui.skip = UIStyle.Button(head, "SKIP", C.Steel, UDim2.fromOffset(96, 28), UDim2.new(1, -96, 0, 2), "Skip")
    ui.skip.Button.MouseButton1Click:Connect(function() Sound("Click"); Tutorial.Skip() end)
    -- the instruction (big, plain sentence)
    ui.text = UIStyle.Text({ Name = "Text", Text = "", RichText = true, TextSize = 20, TextWrapped = true, TextColor3 = C.Text, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = card })
    ui.text:SetAttribute("TypeRole", "Body")
    ui.text.FontFace = Font.new(UIStyle.RoleFace("Body").Family, Enum.FontWeight.Medium) -- (UI CLEAN R-A2: the body face, not the rounded default)
    ui.text:SetAttribute("NoSnap", true)
    -- the objective: ▶ GOAL ......... 1 / 3 + a slim bar
    local goal = New("Frame", { Name = "Goal", BackgroundColor3 = C.Well, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 3, Parent = card }, { UIStyle.Corner(2) })
    UIStyle.Stroke(C.Line, 1).Parent = goal
    ui.goal = UIStyle.Text({ Name = "GoalText", Text = "", RichText = true, TextSize = UIStyle.Size.Subhead, TextColor3 = ACCENT, Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -100, 1, -4), TextTruncate = Enum.TextTruncate.AtEnd, Parent = goal })
    ui.goal:SetAttribute("TypeRole", "Label")
    ui.count = UIStyle.Text({ Name = "Count", Text = "", TextSize = UIStyle.Size.Subhead, TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.fromOffset(90, 30), Parent = goal })
    ui.count:SetAttribute("TypeRole", "Accent")
    ui.barBack = New("Frame", { Name = "Bar", BackgroundColor3 = C.Bg2, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 4), Parent = goal })
    ui.bar = New("Frame", { Name = "Fill", BackgroundColor3 = ACCENT, BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), Parent = ui.barBack })
    ui.goalFrame = goal
    -- feedback line ("Dodged!", "IMMUNE: break its shield first")
    ui.note = UIStyle.Text({ Name = "Note", Text = "", RichText = true, TextSize = UIStyle.Size.Label, TextColor3 = C.Sub, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Visible = false, Parent = card })
    ui.note:SetAttribute("TypeRole", "Body")
    -- buttons (CONTINUE / PLAY / NO THANKS)
    ui.btnRow = New("Frame", { Name = "Buttons", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 5, Visible = false, Parent = card })
    New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8), Parent = ui.btnRow })
    -- the marker layer (no interface scale: it works in real viewport pixels)
    markerGui = New("ScreenGui", { Name = "TutorialMarker", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4, Parent = pg })
    markerGui:SetAttribute("NoSkin", true)
    local dia = New("Frame", { Name = "Diamond", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(20, 20), Rotation = 45, BackgroundColor3 = ACCENT,
        BorderSizePixel = 0, Visible = false, Parent = markerGui })
    UIStyle.InkEdge(2).Parent = dia
    ui.dia = dia
    ui.mLabel = UIStyle.Text({ Name = "Label", Text = "", TextSize = 14, TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.fromOffset(220, 20), Visible = false, BackgroundTransparency = 0.25, BackgroundColor3 = C.Ink, Parent = markerGui })
    ui.mLabel.BackgroundTransparency = 0.3
    ui.mLabel:SetAttribute("TypeRole", "Label")
    ui.arrow = UIStyle.Text({ Name = "Arrow", Text = "▲", TextSize = 30, TextColor3 = ACCENT, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(36, 36), Visible = false, Parent = markerGui })
    New("UIStroke", { Color = C.Ink, Thickness = 2, Parent = ui.arrow })
end

local function ClearButtons()
    for _, c in ipairs(ui.btnRow:GetChildren()) do if c:IsA("GuiButton") then c:Destroy() end end
    ui.btnRow.Visible = false
end
local function AddButton(text: string, color: Color3, w: number, fn: () -> ())
    local b = UIStyle.Button(ui.btnRow, text, color, UDim2.fromOffset(w, 38))
    b.Button.MouseButton1Click:Connect(function() Sound("Click"); fn() end)
    ui.btnRow.Visible = true
    return b
end
local function Note(text: string?, color: Color3?)
    if not ui.note then return end
    ui.note.Text = text or ""
    ui.note.TextColor3 = color or C.Sub
    ui.note.Visible = text ~= nil and text ~= ""
    if S then S.NoteAt = os.clock() end
end

-- ===== the session + step runner ================================================================================
local Steps = {} -- filled below: ARENA, HUB, MAPS
local function Disconnect(list) for _, c in ipairs(list or {}) do pcall(function() c:Disconnect() end) end end

local function Current(): any return S and S.Steps and S.Steps[S.Index] end

local function Render()
    local st = Current()
    if not (S and st and card) then return end
    local total = #S.Steps
    ui.head.Text = string.upper(S.Title) .. ((total > 1) and ("  •  " .. S.Index .. " / " .. total) or "") .. ((st.Tag and ("  •  " .. st.Tag)) or "")
    local t = st.Text
    ui.text.Text = type(t) == "function" and t() or t or ""
    local g = st.Goal
    ui.goal.Text = "▶  " .. string.upper((type(g) == "function" and g() or g) or "")
    ui.goalFrame.Visible = g ~= nil
    local n, m = st.N, st.Max
    if m and m > 1 then
        ui.count.Text = (n or 0) .. " / " .. m
        ui.bar.Size = UDim2.new(math.clamp((n or 0) / m, 0, 1), 0, 1, 0)
        ui.bar.BackgroundColor3 = ACCENT
        ui.barBack.Visible = true
    elseif st.Bar then
        ui.count.Text = string.format("%d%%", math.floor(math.clamp(st.Bar, 0, 1) * 100 + 0.5))
        ui.bar.Size = UDim2.new(math.clamp(st.Bar, 0, 1), 0, 1, 0)
        ui.bar.BackgroundColor3 = st.BarColor or ACCENT
        ui.barBack.Visible = true
    else
        ui.count.Text = ""
        ui.barBack.Visible = false
    end
    ui.skip.Button.Visible = S.Skippable ~= false and not st.NoSkip
end
Tutorial.Render = Render

local Next -- forward
local function EndStep()
    local st = Current()
    if st and st.Cleanup then pcall(st.Cleanup, st) end
    if S then Disconnect(S.StepConns); S.StepConns = {} end
end

local function SetStep(i: number)
    if not S then return end
    EndStep()
    S.Index = i
    local st = Current()
    if not st then
        -- (the finisher runs while the session is still up: leaving the hall needs to know where you stand in it)
        local s0, fin = S, S.OnFinish
        S.OnFinish = nil
        if fin then fin() end
        if S == s0 then Tutorial.Stop() end
        return
    end
    st.N, st.Bar, st.Done = 0, nil, false
    st.Max = st.Count
    st.ShownAt = os.clock()
    ClearButtons()
    Note(nil)
    if st.Save and S.SaveBase then Save(S.SaveBase + i - 1) end
    if st.Start then
        local ok, err = pcall(st.Start, st)
        if not ok then warn("[Tutorial] step start: " .. tostring(err)) end
    end
    if st.Button then AddButton(st.Button, C.Gold, 170, function() if Current() == st then Next() end end) end
    Render()
    if card then
        card.Visible = true
        ui.ruleGrad.Color = UIStyle.Facet(st.Accent or S.Accent or ACCENT, UIStyle.Darken(st.Accent or S.Accent or ACCENT, 0.3))
    end
end

-- the current step's objective is done: a beat of green, then the next one
Next = function()
    local st = Current()
    if not st or st.Done then return end
    st.Done = true
    Sound(st.DoneSound or "Upgrade")
    ui.goal.Text = '<font color="#60D66E">✓  DONE</font>'
    ui.count.Text = ""
    local s0, idx = S, S.Index
    task.delay(st.Linger or 0.7, function()
        if S == s0 and S.Index == idx then SetStep(idx + 1) end
    end)
end
Tutorial.Next = function() Next() end

-- ===== screen marker ===========================================================================================
local function Marker(pos: Vector3?, label: string?)
    if not ui.dia then return end
    local cam = workspace.CurrentCamera
    local root = Root()
    if not (pos and cam and root) or (hooks.MenuOpen and hooks.MenuOpen()) then
        ui.dia.Visible, ui.mLabel.Visible, ui.arrow.Visible = false, false, false
        return
    end
    local vs = cam.ViewportSize
    local v, on = cam:WorldToViewportPoint(pos)
    local dist = Flat(pos - root.Position).Magnitude
    local txt = (label and (string.upper(label) .. "  •  ") or "") .. math.floor(dist + 0.5) .. " STUDS"
    if on and v.Z > 0 and v.X > 40 and v.X < vs.X - 40 and v.Y > 40 and v.Y < vs.Y - 40 then
        -- (never over the crosshair: once the thing is near the middle of the screen you're already on it -- no marker)
        local cx, cy = vs.X / 2, vs.Y / 2
        if math.abs(v.X - cx) < 120 and math.abs(v.Y - cy) < 110 then
            ui.dia.Visible, ui.mLabel.Visible, ui.arrow.Visible = false, false, false
            return
        end
        ui.dia.Visible, ui.mLabel.Visible, ui.arrow.Visible = true, true, false
        ui.dia.Position = UDim2.fromOffset(v.X, v.Y)
        ui.mLabel.Position = UDim2.fromOffset(v.X, v.Y - 38) -- (the name above the diamond: below it sat on the target)
        ui.mLabel.Text = txt
    else
        -- off screen (or behind you): an arrow on an ellipse round the screen edge, pointing the way
        local rel = cam.CFrame:PointToObjectSpace(pos)
        local dx, dy = rel.X, -rel.Y
        if rel.Z > 0 then dx, dy = -dx, -dy; if math.abs(dx) < 1e-3 then dx = 1 end end -- (behind: flip to the side it's on)
        local a = math.atan2(dy, dx)
        local rx, ry = vs.X / 2 - 70, vs.Y / 2 - 90
        local px, py = vs.X / 2 + math.cos(a) * rx, vs.Y / 2 + math.sin(a) * ry
        ui.dia.Visible, ui.arrow.Visible = false, true
        ui.arrow.Position = UDim2.fromOffset(px, py)
        ui.arrow.Rotation = math.deg(a) + 90
        ui.mLabel.Visible = true
        ui.mLabel.Position = UDim2.fromOffset(px, py + 20)
        ui.mLabel.Text = txt
    end
end

-- ===== THE BASICS: the hall =====================================================================================
local W, L, H = 48, 176, 24
local function HallFrame(): CFrame
    -- turned like the try range: the Showcase profile's sun comes from behind your left shoulder
    if not Tutorial.SUN then
        local ct, lat = Lighting.ClockTime, Lighting.GeographicLatitude
        local ok, dir = pcall(function()
            Lighting.ClockTime, Lighting.GeographicLatitude = 14, 41.7
            return Lighting:GetSunDirection()
        end)
        Lighting.ClockTime, Lighting.GeographicLatitude = ct, lat
        Tutorial.SUN = ok and dir or Vector3.new(-0.42, 0.75, 0.51)
    end
    local sun = Tutorial.SUN
    local flat = Vector3.new(sun.X, 0, sun.Z)
    if flat.Magnitude < 1e-3 then flat = Vector3.new(0, 0, 1) end
    flat = flat.Unit
    local bl = Vector3.new(-1, 0, 1).Unit
    local yaw = math.atan2(flat.X, flat.Z) - math.atan2(bl.X, bl.Z)
    return CFrame.new(Zones.TUTORIAL_ORIGIN) * CFrame.Angles(0, yaw, 0)
end

local function Part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, t: number?): BasePart
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanTouch = false
    p.CastShadow = false
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = mat or Enum.Material.SmoothPlastic
    p.Transparency = t or 0
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p:SetAttribute("NoSkin", true)
    p.Parent = parent
    return p
end

-- ===== ground trail (owner 2026-10-13: "little guidelines to guide the players to stands such as the skill tree") ======
-- Hub + hideout steps: a row of small gold chevrons on the ground from your feet toward the step's target, a pulse running
-- along them toward it. Client only, TRAIL_N x 2 tiny non-colliding Neon parts, placed 10 times a second (one down-ray each),
-- hidden near the target, with a window open, or when the ground under a chevron is well above your feet (a wall / prop).
local TRAIL_N, TRAIL_GAP, TRAIL_START = 12, 3.6, 4
local trail = { Folder = nil :: Folder?, Bits = {} :: { any }, Next = 0 }
local function TrailHide() if trail.Folder then trail.Folder.Parent = nil end end
local function TrailBuild()
    local f = Instance.new("Folder")
    f.Name = "TutorialTrail"
    for i = 1, TRAIL_N do
        local b = { On = false, Parts = {} }
        for k = 1, 2 do
            local p = Part(f, "TrailBit", Vector3.new(0.24, 0.06, 1.25), CFrame.new(), C.Gold or Color3.fromRGB(255, 184, 28), Enum.Material.Neon, 1)
            p.CanCollide, p.CanQuery = false, false
            p:SetAttribute("KeepNeon", true)
            b.Parts[k] = p
        end
        trail.Bits[i] = b
    end
    trail.Folder = f
end
local function Trail(pos: Vector3?)
    local root = Root()
    if not (pos and root) or (hooks.MenuOpen and hooks.MenuOpen()) then TrailHide() return end
    local from = root.Position
    local d = Flat(pos - from)
    local dist = d.Magnitude
    if dist < TRAIL_START + 5 then TrailHide() return end
    if not trail.Folder then TrailBuild() end
    trail.Folder.Parent = workspace
    local now = os.clock()
    if now >= trail.Next then
        trail.Next = now + 0.1
        local dir = d.Unit
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { LocalPlayer.Character, trail.Folder }
        params.RespectCanCollide = true
        for i, b in ipairs(trail.Bits) do
            local along = TRAIL_START + (i - 1) * TRAIL_GAP
            b.On = false
            if along < dist - 4 then
                local p = from + dir * along
                local hit = workspace:Raycast(Vector3.new(p.X, from.Y + 2, p.Z), Vector3.new(0, -12, 0), params)
                if hit and hit.Position.Y < from.Y - 1 then
                    local g = hit.Position + Vector3.new(0, 0.1, 0)
                    local base = CFrame.lookAt(g, g + dir)
                    for k, sgn in ipairs({ -1, 1 }) do
                        local ang = math.rad(40 * sgn)
                        local c = Vector3.new(0, 0, -0.45) + Vector3.new(math.sin(ang), 0, math.cos(ang)) * 0.6
                        b.Parts[k].CFrame = base * CFrame.new(c) * CFrame.Angles(0, ang, 0)
                    end
                    b.On = true
                end
            end
        end
    end
    -- the pulse runs toward the target; the far end fades out
    for i, b in ipairs(trail.Bits) do
        local t = 1
        if b.On then
            local w = 0.5 + 0.5 * math.sin(now * 5 - i * 0.75)
            t = 0.2 + 0.45 * (1 - w) + 0.25 * (i / TRAIL_N)
        end
        for _, p in ipairs(b.Parts) do if p.Transparency ~= t then p.Transparency = t end end
    end
end

local function BuildHall(): (Model, CFrame)
    local old = workspace:FindFirstChild("TutorialWorld")
    if old then old:Destroy() end
    local m = Instance.new("Model")
    m.Name = "TutorialWorld"
    m:SetAttribute("NoSkin", true)
    local F = HallFrame()
    local function At(x, y, z) return F * CFrame.new(x, y, z) end
    local c = Color3.fromRGB
    local FLOOR, WALL, SIDE, CEIL = c(150, 148, 146), c(198, 195, 190), c(176, 173, 168), c(48, 50, 56)
    local z0, z1 = 8, 8 - L
    Part(m, "Floor", Vector3.new(W, 1, L), At(0, -0.5, (z0 + z1) / 2), FLOOR, Enum.Material.SmoothPlastic)
    Part(m, "WallBack", Vector3.new(W, H, 1), At(0, H / 2, z1 - 0.5), WALL)
    Part(m, "WallFront", Vector3.new(W, H, 1), At(0, H / 2, z0 + 0.5), SIDE)
    Part(m, "WallL", Vector3.new(1, H, L), At(-W / 2 - 0.5, H / 2, (z0 + z1) / 2), SIDE)
    Part(m, "WallR", Vector3.new(1, H, L), At(W / 2 + 0.5, H / 2, (z0 + z1) / 2), SIDE)
    Part(m, "Ceiling", Vector3.new(W + 2, 1, L + 2), At(0, H + 0.5, (z0 + z1) / 2), CEIL)
    for _, sx in ipairs({ -9, 9 }) do
        Part(m, "Softbox", Vector3.new(3, 0.2, L - 16), At(sx, H - 0.15, (z0 + z1) / 2), c(255, 250, 240), Enum.Material.Neon)
    end
    -- the four sections, each marked by a gold floor line + a number plate on the wall: 1 move, 2 aim, 3 bots, 4 boss
    for i, z in ipairs({ -26, -56, -96 }) do
        Part(m, "Line" .. i, Vector3.new(W - 2, 0.05, 0.3), At(0, 0.03, z), Color3.fromRGB(196, 150, 40), Enum.Material.SmoothPlastic, 0.2)
    end
    -- the bot section's low cover (aim over it) + the boss stage (a dark disc on the floor)
    for _, x in ipairs({ -13, 13 }) do
        Part(m, "Cover", Vector3.new(6, 3, 1.4), At(x, 1.5, -66), c(92, 96, 108), Enum.Material.SmoothPlastic)
    end
    local stage = Part(m, "Stage", Vector3.new(0.3, 34, 34), At(0, 0.06, -140) * CFrame.Angles(0, 0, math.rad(90)), c(58, 54, 72), Enum.Material.SmoothPlastic)
    stage.Shape = Enum.PartType.Cylinder
    local rim = Part(m, "StageRim", Vector3.new(0.2, 35, 35), At(0, 0.04, -140) * CFrame.Angles(0, 0, math.rad(90)), c(128, 78, 200), Enum.Material.Neon, 0.3)
    rim.Shape = Enum.PartType.Cylinder
    for _, p in ipairs(m:GetChildren()) do
        if p:IsA("BasePart") then p.CanQuery = (p.Name == "Floor" or string.sub(p.Name, 1, 4) == "Wall" or p.Name == "Cover" or p.Name == "Ceiling") end
        if p:IsA("BasePart") and (p.Name == "Softbox" or string.sub(p.Name, 1, 4) == "Line" or p.Name == "Stage" or p.Name == "StageRim") then p.CanCollide = false end
    end
    m.Parent = workspace
    return m, F
end

-- a walk-here ring on the floor
local function Ring(parent: Instance, cf: CFrame, r: number, color: Color3?): BasePart
    local p = Part(parent, "GoalRing", Vector3.new(0.2, r * 2, r * 2), cf * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), color or ACCENT, Enum.Material.Neon, 0.45)
    p.Shape = Enum.PartType.Cylinder
    p.CanCollide, p.CanQuery = false, false
    return p
end

-- ===== targets (bots, the dummy, the boss): pill bodies like the game's bots ===================================
local function Gun(): any return State().EquippedWeapon or {} end
local function ShotsPerSecond(): number
    local w = Gun()
    return math.max(0.4, (tonumber(w.BaseFireRate) or 4) * math.max(1, tonumber(w.BurstCount) or 1))
end
-- health in "body shots": about `seconds` of steady fire with the gun in your hands, kept between lo and hi
local function HpFor(seconds: number, lo: number, hi: number): number
    return math.clamp(math.floor(ShotsPerSecond() * seconds + 0.5), lo, hi)
end

local function Pill(parent: Instance, name: string, body: Color3, scale: number, cf: CFrame): Model
    local m = Instance.new("Model")
    m.Name = name
    local s = scale
    local function P(pn, shape, size, off, col, mat)
        local p = Part(m, pn, size, cf * off, col, mat)
        p.Shape = shape
        p.CanCollide = false
        p.CanQuery = pn ~= "Eye"
        return p
    end
    P("Body", Enum.PartType.Cylinder, Vector3.new(2.4 * s, 2 * s, 2 * s), CFrame.new(0, 2.4 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), body)
    P("Body", Enum.PartType.Ball, Vector3.new(2 * s, 2 * s, 2 * s), CFrame.new(0, 3.6 * s, 0), body)
    P("Body", Enum.PartType.Ball, Vector3.new(2 * s, 2 * s, 2 * s), CFrame.new(0, 1.2 * s, 0), body)
    P("Head", Enum.PartType.Ball, Vector3.new(1.5 * s, 1.5 * s, 1.5 * s), CFrame.new(0, 5.25 * s, 0), body:Lerp(Color3.new(1, 1, 1), 0.25))
    P("Eye", Enum.PartType.Block, Vector3.new(0.7 * s, 0.32 * s, 0.1), CFrame.new(0, 5.3 * s, -0.72 * s), RED, Enum.Material.Neon)
    m.WorldPivot = cf -- (the pivot is the bot's feet, upright: PivotTo(feet facing you) moves the whole pill)
    m.Parent = parent
    return m
end

-- an over-the-head health bar (not AlwaysOnTop: it hides behind cover like the body)
local function HpBar(m: Model, color: Color3?): Frame
    local head = m:FindFirstChild("Head")
    local bb = New("BillboardGui", { Name = "Hp", Size = UDim2.fromOffset(70, 8), StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0), Adornee = head, LightInfluence = 0, Parent = m })
    local back = New("Frame", { BackgroundColor3 = C.Ink, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = bb })
    return New("Frame", { BackgroundColor3 = color or RED, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = back })
end

-- t = { Model, Hp, Max, Mult(), OnHit(part, weak), OnDeath(), Immune }
local function Hit(t: any, part: BasePart, pos: Vector3): boolean
    if t.Dead then return true end
    local w = Gun()
    local unit = 1 / math.max(1, tonumber(w.PelletCount) or 1)
    local weak = part.Name == "Head"
    if t.OnPart and t.OnPart(part, pos) then return true end -- (shield orbs etc.)
    if t.Immune then
        Note('<font color="#A8FF3C"><b>GUARDED</b></font>: shoot the lime targets first', C.Text) -- (0.99u: real bosses guard (half damage) in a round; the lesson boss stays shut)
        return true
    end
    local mult = (weak and 2 or 1) * (t.Model:GetAttribute("Exposed") and 1.4 or 1) * (t.Stagger and 1.75 or 1)
    t.Hp -= unit * mult
    local killed = t.Hp <= 0.001
    -- the numbers + hit flash the real game shows
    local est = hooks.Estimate and hooks.Estimate(weak, t.Model) or nil
    local amount = (est and est / 0.85 or 12) * (t.Model:GetAttribute("Exposed") and 1.4 or 1) * (t.Stagger and 1.75 or 1)
    if hooks.DamageText then pcall(hooks.DamageText, amount, weak, false, pos, t.Model, killed) end
    for _, p in ipairs(t.Model:GetChildren()) do
        if p:IsA("BasePart") and (p.Name == "Body" or p.Name == "Head") then
            local c0 = p:GetAttribute("C0") or p.Color
            p:SetAttribute("C0", c0)
            p.Color = Color3.new(1, 1, 1)
            TweenService:Create(p, TweenInfo.new(0.12), { Color = c0 }):Play()
        end
    end
    if t.OnHit then t.OnHit(part, weak) end
    if t.Bar then t.Bar.Size = UDim2.fromScale(math.clamp(t.Hp / t.Max, 0, 1), 1) end
    if killed then
        t.Dead = true
        t.Model:SetAttribute("Health", nil)
        Sound("Kill")
        local pivot = t.Model:GetPivot()
        for _, p in ipairs(t.Model:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanQuery = false
                TweenService:Create(p, TweenInfo.new(0.35), { Transparency = 1, Size = p.Size * 0.4 }):Play()
            end
        end
        task.delay(0.4, function() if t.Model then t.Model:Destroy() end end)
        if t.OnDeath then t.OnDeath(pivot) end
    else
        t.Model:SetAttribute("Health", math.max(1, t.Hp / t.Max * 100))
    end
    return true
end

local function AddTarget(t: any): any
    game:GetService("CollectionService"):AddTag(t.Model, "AimAssistTarget") -- (touch aim assist: AimRngShared/AimAssist)
    t.Model:SetAttribute("Health", 100)
    t.Model:SetAttribute("MaxHealth", 100)
    table.insert(S.Targets, t)
    return t
end
local function ClearTargets()
    for _, t in ipairs(S and S.Targets or {}) do if t.Model then t.Model:Destroy() end end
    if S then S.Targets = {} end
end

-- ===== THE BASICS: the steps =====================================================================================
local function ArenaSteps(): { any }
    local function At(x, y, z) return S.F * CFrame.new(x, y, z) end
    local function Mover(): any
        local ok, M = pcall(function() return require(Shared:WaitForChild("MovementController")) end)
        return ok and M or nil
    end
    local function LocalZ(): number
        local r = Root()
        return r and S.F:PointToObjectSpace(r.Position).Z or 0
    end
    local steps = {}
    -- 1. move
    table.insert(steps, { Tag = "MOVE", Save = false,
        Text = function()
            local d = Device()
            if d == "touch" then return "Welcome to Aimbound. Move with the left stick and drag the right side of the screen to look around." end
            if d == "pad" then return "Welcome to Aimbound. Move with the left stick and look with the right stick." end
            return "Welcome to Aimbound. Move with " .. Cap("[W A S D]") .. " and look around with the mouse."
        end,
        Goal = "Walk into the glowing ring", -- (2026-10-22: the ring is the UI accent, cyan since UI v4 -- it said "gold")
        Start = function(st) st.Ring = Ring(S.Model, At(0, 0, -18), 3.5) end,
        Marker = function() return At(0, 1, -18).Position, "here" end,
        Update = function(st)
            local r = Root()
            return r ~= nil and Flat(r.Position - At(0, 0, -18).Position).Magnitude < 3.6
        end,
        Cleanup = function(st) if st.Ring then st.Ring:Destroy() end end,
    })
    -- 2. dash
    table.insert(steps, { Tag = "MOVE",
        Text = function() return "Press " .. Key("Dash") .. " to DASH: a quick burst the way you're moving. It's your best way out of an attack." end,
        Goal = "Dash twice", Count = 2,
        Update = function(st)
            local M = Mover()
            local now = M and M.State == "Dash"
            if now and not st.Was then st.N += 1; Render() end
            st.Was = now
            return st.N >= 2
        end,
    })
    -- 3. slide
    table.insert(steps, { Tag = "MOVE",
        Text = function()
            local hop = Device() == "kb" and (" Hold " .. Cap("[SPACE]") .. " to keep jumping as you land.") or ""
            return "While running, press " .. Key("Slide") .. " to SLIDE." .. hop .. " Movement only builds a little speed: good aim wins, not outrunning."
        end,
        Goal = "Slide once",
        Update = function(st)
            local M = Mover()
            return M ~= nil and (M.State == "Slide" or (M.SlideAmount or 0) > 0.5)
        end,
    })
    -- 4. shoot a target
    table.insert(steps, { Tag = "AIM",
        Text = function() return "Aim at the target and shoot with " .. Key("Fire") .. ". Reload with " .. Key("Reload") .. ". Every hit you land flashes the crosshair." end,
        Goal = "Destroy the target",
        Start = function(st)
            local m = Pill(S.Model, "TutorialTarget", Color3.fromRGB(70, 76, 92), 1, At(0, 0, -44))
            st.T = AddTarget({ Model = m, Hp = HpFor(0.8, 3, 8), Max = HpFor(0.8, 3, 8) })
            st.T.Bar = HpBar(m)
            st.T.OnDeath = function() st.Killed = true end
        end,
        Marker = function(st) return st.T and not st.T.Dead and At(0, 5, -44).Position or nil, "target" end,
        Update = function(st) return st.Killed == true end,
    })
    -- 5. weak spots
    table.insert(steps, { Tag = "AIM",
        Text = "The HEAD is every enemy's weak spot: double damage, and the hit numbers turn red. Aim high.",
        Goal = "Land headshots", Count = 3,
        Start = function(st)
            local m = Pill(S.Model, "TutorialTarget", Color3.fromRGB(70, 76, 92), 1.15, At(4, 0, -46))
            st.T = AddTarget({ Model = m, Hp = 1e9, Max = 1e9 })
            st.T.OnHit = function(_, weak)
                if weak then st.N += 1; Render() else Note("Body hit. Aim for the head (the ball on top).") end
            end
        end,
        Marker = function(st) return At(4, 6.4, -46).Position, "weak spot" end,
        Update = function(st) return st.N >= 3 end,
        Cleanup = function(st) if st.T and st.T.Model then st.T.Dead = true; st.T.Model:Destroy() end end,
    })
    -- 6. bots + the EXPOSED mark
    table.insert(steps, { Tag = "FIGHT",
        Text = function()
            return "Bots strafe like aim trainer targets. One at a time is EXPOSED: it glows " .. '<font color="#A8FF3C"><b>LIME</b></font>' ..
                " and takes 40% more damage, and the mark moves every 4 seconds. Anything lime is worth shooting."
        end,
        Goal = "Defeat the bots", Count = 3,
        Start = function(st)
            st.Bots = {}
            local cols = { Color3.fromRGB(64, 92, 170), Color3.fromRGB(150, 70, 160), Color3.fromRGB(40, 140, 150) }
            local hp = HpFor(1.1, 3, 10)
            for i = 1, 3 do
                local base = At((i - 2) * 12, 0, -78 - (i % 2) * 8)
                local m = Pill(S.Model, "TutorialBot", cols[i], 1, base)
                local hl = New("Highlight", { FillTransparency = 1, OutlineColor = LIME, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.Occluded, Enabled = false, Parent = m })
                local t = AddTarget({ Model = m, Hp = hp, Max = hp })
                t.Bar = HpBar(m)
                t.Base, t.Amp, t.W, t.Ph, t.HL = base, 7 + i * 1.5, 0.55 + i * 0.12, i * 1.9, hl
                t.OnDeath = function(pivot)
                    st.N += 1
                    st.LastAt = pivot
                    Render()
                    if st.Exposed == t then st.NextMark = 0 end
                end
                table.insert(st.Bots, t)
            end
            st.NextMark = 0
        end,
        Marker = function(st)
            for _, t in ipairs(st.Bots or {}) do if not t.Dead and t.Model:GetAttribute("Exposed") then return t.Model:GetPivot().Position + Vector3.new(0, 7, 0), "exposed" end end
            return nil
        end,
        Tick = function(st, dt)
            local now = os.clock()
            local r = Root()
            for _, t in ipairs(st.Bots or {}) do
                if not t.Dead and t.Model.Parent then
                    local x = math.sin(now * t.W + t.Ph) * t.Amp
                    local p = (t.Base * CFrame.new(x, 0, math.sin(now * 0.7 + t.Ph) * 1.5)).Position
                    local look = r and Vector3.new(r.Position.X, p.Y, r.Position.Z) or (p - S.F.LookVector)
                    t.Model:PivotTo(CFrame.lookAt(p, look))
                end
            end
            -- the mark: one living bot, moved every 4 s (and at once when the marked one dies)
            if now >= (st.NextMark or 0) then
                local alive = {}
                for _, t in ipairs(st.Bots) do if not t.Dead then table.insert(alive, t) end end
                if #alive > 0 then
                    local pick = alive[1]
                    if #alive > 1 then
                        repeat pick = alive[math.random(1, #alive)] until pick ~= st.Exposed
                    end
                    for _, t in ipairs(st.Bots) do
                        if t.Model.Parent then t.Model:SetAttribute("Exposed", t == pick or nil); t.HL.Enabled = (t == pick) end
                    end
                    st.Exposed = pick
                end
                st.NextMark = now + 4
            end
        end,
        Update = function(st) return st.N >= 3 end,
    })
    -- 7. loot: the drop, the compare card, equip
    table.insert(steps, { Tag = "LOOT", DoneSound = "Equip",
        Text = function()
            local function R(name)
                local c = (ItemData.RarityColors and ItemData.RarityColors[name]) or C.Text
                return '<font color="#' .. c:ToHex() .. '">' .. name .. "</font>"
            end
            -- (UPDATE 8 RARITY v4: the five rarities; rarer = more lines, harder content = higher line tiers)
            return "Loot drops from bots and chests. Its COLOUR is its rarity (" .. R("Common") .. ", " .. R("Uncommon") .. ", " .. R("Rare") ..
                ", " .. R("Mythic") .. ", " .. R("Relic") .. "): rarer gear has more lines. Walk to the beam and press " .. Key("Interact") .. " to pick it up."
        end,
        Goal = "Pick up the gun",
        Start = function(st)
            local real = Gun()
            local base = (real.BaseId == "AK47") and "M4A1" or "AK47"
            local lvl = tonumber(real.ItemLevel) or tonumber(State().Level) or 1
            local loan = ItemData.GenerateWeaponOfBase and ItemData.GenerateWeaponOfBase(base, "Rare", lvl)
            if type(loan) == "table" then
                loan.Uid = "__tutorial"
                loan.Procs, loan.Proc, loan.UniqueTrait, loan.Trait, loan.Exotic = nil, nil, nil, nil, nil
                -- (always the better gun here: a level-matched Rare rifle against your gun; nudged if yours is stronger)
                local mine = ItemData.CalculateTrueDPS(real)
                local its = ItemData.CalculateTrueDPS(loan)
                if mine > 0 and its < mine * 1.15 then loan.BaseDamage = (loan.BaseDamage or 1) * (mine * 1.2 / math.max(its, 0.01)) end
            end
            st.Loan = loan
            local where = st.Prev and st.Prev.LastAt or At(0, 0, -74)
            local p0 = Vector3.new(where.Position.X, S.F.Position.Y, where.Position.Z)
            local rc = (ItemData.RarityColors and ItemData.RarityColors.Rare) or Color3.fromRGB(74, 155, 255)
            local drop = Instance.new("Model")
            drop.Name = "TutorialDrop"
            local beam = Part(drop, "Beam", Vector3.new(0.5, 26, 0.5), CFrame.new(p0 + Vector3.new(0, 13, 0)), rc, Enum.Material.Neon, 0.35)
            beam.CanCollide, beam.CanQuery = false, false
            local box = Part(drop, "Item", Vector3.new(2.4, 0.6, 0.8), CFrame.new(p0 + Vector3.new(0, 1.2, 0)), rc, Enum.Material.SmoothPlastic)
            box.CanCollide, box.CanQuery = false, false
            local pp = New("ProximityPrompt", { ActionText = "Pick up", ObjectText = (loan and ItemData.DisplayName(loan) or "Rifle") .. "  •  Rare", HoldDuration = 0,
                MaxActivationDistance = 9, RequiresLineOfSight = false, KeyboardKeyCode = Enum.KeyCode.E, Parent = box })
            drop.Parent = S.Model
            st.Drop, st.At = drop, p0
            table.insert(S.StepConns, pp.Triggered:Connect(function() st.Picked = true end))
            -- spin the item
            table.insert(S.StepConns, RunService.RenderStepped:Connect(function()
                if box.Parent then box.CFrame = CFrame.new(p0 + Vector3.new(0, 1.2 + math.sin(os.clock() * 2) * 0.2, 0)) * CFrame.Angles(0, os.clock() * 1.5, 0) end
            end))
        end,
        Marker = function(st) return (st.At and not st.Compare) and (st.At + Vector3.new(0, 3, 0)) or nil, "loot" end,
        Update = function(st)
            if st.Picked and not st.Compare then
                st.Compare = true
                if st.Drop then st.Drop:Destroy() end
                Tutorial.ShowCompare(st)
            end
            return st.Equipped == true
        end,
        Cleanup = function(st)
            if st.Drop then st.Drop:Destroy() end
            if ui.compare then ui.compare:Destroy(); ui.compare = nil end
        end,
    })
    -- 8. the boss
    table.insert(steps, { Tag = "BOSS", Linger = 1.2, DoneSound = "Victory",
        Text = "A boss. Its attacks mark the floor in red before they land: step out before the red fills. When it's GUARDED, shoot the LIME targets to stagger it.",
        Goal = "Defeat THE WARDEN",
        Start = function(st)
            local base = At(0, 0, -142)
            local m = Pill(S.Model, "TutorialBoss", Color3.fromRGB(72, 44, 120), 1.7, base)
            local hp = HpFor(9, 12, 90)
            local t = AddTarget({ Model = m, Hp = hp, Max = hp })
            st.Boss, st.Base = t, base
            st.NextAtk = os.clock() + 2.2
            st.Bar = 1
            st.BarColor = RED
            t.OnHit = function()
                st.Bar = math.clamp(t.Hp / t.Max, 0, 1)
                Render()
                if not st.ShieldDone and not st.Shield and t.Hp / t.Max <= 0.6 then Tutorial.BossShield(st) end
            end
            t.OnDeath = function(pivot) st.Dead = true; st.DeadAt = pivot end
            -- the orbs live in the boss model: a hit on one never hurts the boss
            t.OnPart = function(part)
                if part.Name ~= "ShieldOrb" then return false end
                local o = st.Orbs and st.Orbs[part]
                if o then
                    o.Hp -= 1
                    part.Color = Color3.new(1, 1, 1)
                    TweenService:Create(part, TweenInfo.new(0.1), { Color = LIME }):Play()
                    if o.Hp <= 0 then
                        st.Orbs[part] = nil
                        part:Destroy()
                        Sound("Kill")
                        st.OrbsLeft -= 1
                        st.N = 3 - st.OrbsLeft
                        if st.OrbsLeft <= 0 then Tutorial.BossStagger(st) end
                        Render()
                    end
                end
                return true
            end
        end,
        Marker = function(st)
            if st.Boss and not st.Boss.Dead then return st.Boss.Model:GetPivot().Position + Vector3.new(0, 11, 0), st.Shield and "shield targets" or "the warden" end
            return nil
        end,
        Tick = function(st, dt)
            local t = st.Boss
            if not t or t.Dead or not t.Model.Parent then return end
            local now = os.clock()
            local r = Root()
            if not t.Stagger then
                st.Clock = (st.Clock or 0) + dt * (st.Shield and 0.5 or 1)
                local x = math.sin(st.Clock * 0.55) * 12
                local p = (st.Base * CFrame.new(x, math.abs(math.sin(st.Clock * 2.2)) * 0.4, 0)).Position
                local look = r and Vector3.new(r.Position.X, p.Y, r.Position.Z) or (p - S.F.LookVector)
                t.Model:PivotTo(CFrame.lookAt(p, look))
            end
            -- orbs circle it
            if st.Orbs then
                local i = 0
                local c = t.Model:GetPivot().Position
                for orb in pairs(st.Orbs) do
                    i += 1
                    local a = now * 0.9 + i * (math.pi * 2 / 3)
                    orb.CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 7, 5 + math.sin(now * 1.7 + i) * 1.6, math.sin(a) * 7))
                end
            end
            -- a telegraphed strike on the floor where you stand (not while it's staggered)
            if r and not t.Stagger and now >= st.NextAtk then
                st.NextAtk = now + 3.4
                Tutorial.Strike(st, Vector3.new(r.Position.X, S.F.Position.Y, r.Position.Z))
            end
            if st.Stagger and now >= st.StaggerEnd then
                t.Stagger, st.Stagger = false, false
                t.Model:SetAttribute("DamageTakenMult", nil)
                Note(nil)
                st.N, st.Max = 0, nil
                Render()
            end
        end,
        Update = function(st) return st.Dead == true end,
        Cleanup = function(st) for _, p in ipairs(st.Strikes or {}) do if p.Parent then p:Destroy() end end end,
    })
    -- 9. extract
    table.insert(steps, { Tag = "EXIT",
        Text = "Floor clear! In a run, a portal takes you to the next floor and the last one sends you home with your loot. Walk into the portal to head to the hub.",
        Goal = "Walk into the portal",
        Start = function(st)
            local prev = steps[8]
            local at = prev and prev.DeadAt or At(0, 0, -138)
            local p0 = Vector3.new(at.Position.X, S.F.Position.Y, at.Position.Z)
            local face = CFrame.lookAt(p0, p0 + S.F.LookVector) * CFrame.new(0, 5.4, 0)
            local mem = Part(S.Model, "Portal", Vector3.new(0.2, 9, 9), face * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(120, 90, 230), Enum.Material.Neon, 0.6)
            mem.Shape = Enum.PartType.Cylinder
            mem.CanCollide, mem.CanQuery = false, false
            local parts = { mem }
            local R, N = 4.9, 16
            for i = 0, N - 1 do
                local a = (i + 0.5) / N * math.pi * 2
                local seg = Part(S.Model, "Portal", Vector3.new(2 * math.pi * R / N + 0.08, 0.55, 0.55), face * CFrame.new(math.cos(a) * R, math.sin(a) * R, 0) * CFrame.Angles(0, 0, a + math.pi / 2),
                    (i % 2 == 0) and Color3.fromRGB(176, 136, 255) or Color3.fromRGB(96, 66, 190), Enum.Material.Neon)
                seg.CanCollide, seg.CanQuery = false, false
                table.insert(parts, seg)
            end
            st.At, st.Parts = p0, parts
            -- (the membrane breathes)
            table.insert(S.StepConns, RunService.RenderStepped:Connect(function()
                if mem.Parent then mem.Transparency = 0.55 + math.sin(os.clock() * 3) * 0.12 end
            end))
        end,
        Marker = function(st) return st.At and st.At + Vector3.new(0, 5, 0) or nil, "portal" end,
        Update = function(st)
            local r = Root()
            return r ~= nil and st.At ~= nil and Flat(r.Position - st.At).Magnitude < 4.5
        end,
        Linger = 0.3,
    })
    -- each step sees the one before it (the loot falls where the last bot died)
    for i = 2, #steps do steps[i].Prev = steps[i - 1] end
    return steps
end

-- the boss's floor strike: a red disc fills, then goes off; outside it = dodged
function Tutorial.Strike(st: any, at: Vector3)
    local R = 7
    local base = CFrame.new(at + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
    local edge = Part(S.Model, "Strike", Vector3.new(0.12, R * 2, R * 2), base, RED, Enum.Material.Neon, 0.7)
    local fill = Part(S.Model, "Strike", Vector3.new(0.16, 0.2, 0.2), base * CFrame.new(0.02, 0, 0), RED, Enum.Material.Neon, 0.35)
    for _, p in ipairs({ edge, fill }) do p.Shape = Enum.PartType.Cylinder; p.CanCollide = false; p.CanQuery = false end
    st.Strikes = st.Strikes or {}
    table.insert(st.Strikes, edge); table.insert(st.Strikes, fill)
    local FILL = 1.4
    TweenService:Create(fill, TweenInfo.new(FILL, Enum.EasingStyle.Linear), { Size = Vector3.new(0.16, R * 2, R * 2) }):Play()
    local s0 = S
    task.delay(FILL, function()
        if S ~= s0 or not edge.Parent then return end
        local r = Root()
        local inside = r ~= nil and Flat(r.Position - at).Magnitude < R
        edge.Color, fill.Color, fill.Transparency = Color3.new(1, 1, 1), Color3.new(1, 1, 1), 0.2
        if inside then
            st.Hits = (st.Hits or 0) + 1
            Note('<font color="#E84242"><b>HIT</b></font>: get out of the red before it fills (' .. Key("Dash") .. " helps). Here it costs nothing.", C.Text)
        else
            st.Dodges = (st.Dodges or 0) + 1
            Note('<font color="#60D66E"><b>DODGED</b></font>  ×' .. st.Dodges, C.Text)
        end
        task.delay(0.15, function() edge:Destroy(); fill:Destroy() end)
    end)
end

-- the shield round: immune until the three lime targets are shot (the game's aim rounds work the same way)
function Tutorial.BossShield(st: any)
    local t = st.Boss
    st.Shield, t.Immune = true, true
    st.Orbs, st.OrbsLeft = {}, 3
    local hp = HpFor(0.35, 1, 4)
    for i = 1, 3 do
        local o = Part(t.Model, "ShieldOrb", Vector3.new(1.8, 1.8, 1.8), t.Model:GetPivot() * CFrame.new(0, 5, 0), LIME, Enum.Material.Neon)
        o.Shape = Enum.PartType.Ball
        o.CanCollide, o.CanQuery = false, true
        st.Orbs[o] = { Hp = hp }
    end
    local hl = New("Highlight", { Name = "Shield", FillColor = Color3.fromRGB(120, 200, 255), FillTransparency = 0.6, OutlineTransparency = 1, Parent = t.Model })
    st.ShieldHL = hl
    st.N, st.Max = 0, 3
    st.Goal = "Shoot the 3 lime targets"
    Sound("Upgrade")
    Note('<font color="#A8FF3C"><b>TARGETS</b></font>: break the lime targets to STAGGER it (+75% damage).', C.Text)
    Render()
end
function Tutorial.BossStagger(st: any)
    local t = st.Boss
    st.Shield, t.Immune, st.ShieldDone = false, false, true
    st.Orbs = nil
    if st.ShieldHL then st.ShieldHL:Destroy() end
    t.Stagger, st.Stagger = true, true
    st.StaggerEnd = os.clock() + 6
    t.Model:SetAttribute("DamageTakenMult", 1.75)
    st.Goal = "Defeat THE WARDEN"
    st.Max = nil
    Sound("Victory")
    Note('<font color="#FFB81C"><b>STAGGERED</b></font>: 75% more damage for 6 seconds. Unload!', C.Text)
    Render()
end

-- (2026-10-13, owner's phone test: "you cant shoot with the tutorial menu open") on a touch screen the compare panel sat
-- over the right-hand touch buttons (DASH / SLIDE / R / SWAP and the top of FIRE). There it goes bottom-centre between the
-- HUD column and the touch cluster, shrunk to fit, its top kept below the crosshair keep-out. Keyboard / pad: unchanged.
function Tutorial.PlaceCompare(k: number)
    local panel = ui.compare
    if not (panel and ui.compareFit) then return end
    if Device() ~= "touch" then
        panel.AnchorPoint, panel.Position, ui.compareFit.Scale = Vector2.new(1, 1), UDim2.new(1, -24, 1, -150), 1
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vs = cam.ViewportSize
    local L = (16 + 400) * k + 12 -- (the HUD column: AimRngClient UI.HudStack X + W, same interface scale)
    local R = vs.X - 12
    local tg = LocalPlayer.PlayerGui:FindFirstChild("AimRngTouch")
    local holder = tg and tg:FindFirstChildOfClass("Frame")
    if holder and holder.Visible then
        for _, b in ipairs(holder:GetChildren()) do
            if b:IsA("GuiButton") and b.Visible and b.AbsolutePosition.X > vs.X * 0.5 then R = math.min(R, b.AbsolutePosition.X - 10) end
        end
    end
    local inset = 0
    pcall(function() inset = game:GetService("GuiService"):GetGuiInset().Y end)
    local bottom = vs.Y - inset - 10
    local top = vs.Y * 0.5 + 70 - inset -- (crosshair keep-out)
    local fit = math.min(1, (R - L) / (590 * k), (bottom - top) / (190 * k))
    fit = math.max(0.4, fit)
    ui.compareFit.Scale = fit
    panel.AnchorPoint = Vector2.new(0.5, 1)
    panel.Position = UDim2.fromOffset(((L + R) / 2) / k, bottom / k)
end

-- the compare card (the real game: the loot card + SHIFT over an item in the inventory)
function Tutorial.ShowCompare(st: any)
    if ui.compare then ui.compare:Destroy() end
    local mine, new = Gun(), st.Loan
    if type(new) ~= "table" then st.Equipped = true return end
    -- (its own slab low on the right, over the gun: the card stays short, nothing near the crosshair or the HUD on the left)
    local panel = New("Frame", { Name = "Compare", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -150), Size = UDim2.fromOffset(590, 190),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = gui }, { UIStyle.Corner(2) })
    ui.compareFit = New("UIScale", { Parent = panel })
    UIStyle.FacetGrad(C.Bg1, UIStyle.Darken(C.Bg1, 0.35), 0.64).Parent = panel
    UIStyle.InkEdge(2).Parent = panel
    local f = New("Frame", { Name = "Cols", Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 112), BackgroundTransparency = 1, Parent = panel })
    New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = f })
    local function Col(title: string, w: any, other: any)
        local rc = ItemData.ItemColor and ItemData.ItemColor(w) or C.Text
        local cc = New("Frame", { BackgroundColor3 = C.Bg2, BorderSizePixel = 0, Size = UDim2.fromOffset(270, 112), Parent = f }, { UIStyle.Corner(2) })
        UIStyle.Stroke(rc, 2).Parent = cc
        UIStyle.Text({ Text = title, TextSize = 13, TextColor3 = C.Sub, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 16), Parent = cc })
        UIStyle.Text({ Text = ItemData.DisplayName(w), TextSize = 18, TextColor3 = rc, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -20, 0, 24), Parent = cc })
        UIStyle.Text({ Text = string.upper(tostring(w.Rarity or "")) .. "  •  " .. (ItemData.WeaponTypeName and ItemData.WeaponTypeName(w) or ""), TextSize = 12, TextColor3 = C.Sub,
            Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 0, 16), Parent = cc })
        local d1, d2 = ItemData.CalculateTrueDPS(w), ItemData.CalculateTrueDPS(other)
        local better = d1 > d2 * 1.01
        local worse = d1 < d2 * 0.99
        local col = better and C.Good or worse and C.Bad or C.Text
        UIStyle.Text({ Text = "DPS  " .. ItemData.FormatNumber(d1) .. (better and "  ▲" or worse and "  ▼" or ""), TextSize = 20, TextColor3 = col, Position = UDim2.fromOffset(10, 66),
            Size = UDim2.new(1, -20, 0, 26), Parent = cc })
        UIStyle.Text({ Text = "damage " .. ItemData.FormatNumber(ItemData.GunDamage(w)) .. "  •  " .. tostring(w.BaseFireRate or "?") .. " shots/s", Font = UIStyle.BodyFont, TextSize = 12,
            TextColor3 = C.Sub, Position = UDim2.fromOffset(10, 92), Size = UDim2.new(1, -20, 0, 16), Parent = cc })
    end
    Col("EQUIPPED", mine, new)
    Col("NEW DROP", new, mine)
    ui.compare = panel
    ui.text.Text = "The new gun shows its stats beside yours: " .. '<font color="#60D66E">green ▲</font>' .. " is better. In your inventory " ..
        Menu("Inventory", "INVENTORY") .. ", " .. ((Device() == "kb") and ("hold " .. Cap("[SHIFT]") .. " over an item") or (Device() == "touch") and "tap an item" or "select an item") .. " to compare like this. Equip it."
    ui.goal.Text = "▶  EQUIP THE BETTER GUN"
    ClearButtons()
    local eq = UIStyle.Button(panel, "EQUIP" .. (Device() == "kb" and "  [E]" or ""), C.Gold, UDim2.fromOffset(220, 44), UDim2.new(0.5, -110, 1, -56), "Equip")
    eq.Button.MouseButton1Click:Connect(function() Sound("Click"); Tutorial.EquipLoan(st) end)
    if Device() == "kb" then
        table.insert(S.StepConns, UserInputService.InputBegan:Connect(function(input, gp)
            if gp or GameSettings.IsTyping() then return end
            if input.KeyCode == Enum.KeyCode.E or GameSettings.InputIs(input, "Interact") then Tutorial.EquipLoan(st) end
        end))
    end
end
function Tutorial.EquipLoan(st: any)
    if st.Equipped or not S then return end
    local s = State()
    local loan = st.Loan
    if type(loan) == "table" and type(s) == "table" then
        S.Real = S.Real or { Weapon = s.EquippedWeapon, Mag = s.CurrentMag }
        S.Loan = loan
        s.EquippedWeapon = loan
        s.CurrentMag = loan.MagazineSize or s.CurrentMag
        if hooks.Rebuild then pcall(hooks.Rebuild, loan) end
    end
    ClearButtons()
    st.Equipped = true
    Note("Equipped. (This rifle is a loaner for the tutorial: real drops go to your bag and are yours.)", C.Sub)
end

-- give your own gun back (end of the basics, skip, death)
local function ReturnLoan()
    if not (S and S.Real) then return end
    local s = State()
    if type(s) == "table" then
        s.EquippedWeapon = S.Real.Weapon
        if S.Real.Mag then s.CurrentMag = S.Real.Mag end
        if hooks.Rebuild then pcall(hooks.Rebuild, s.EquippedWeapon) end
    end
    S.Real, S.Loan = nil, nil
end
-- the server synced a new state while the loaner is in your hands: keep showing it
function Tutorial.Reapply(newState: any): any
    if S and S.Loan and type(newState) == "table" then
        S.Real = { Weapon = newState.EquippedWeapon, Mag = newState.CurrentMag }
        newState.EquippedWeapon = S.Loan
    end
    return newState
end

-- a shot from the real fire path (AimRngClient ExecuteRaycastShot): true = it was the tutorial's (nothing goes to the server)
function Tutorial.Shot(result: any): boolean
    if not (S and S.Kind == "arena" and result and result.Instance) then return false end
    local inst = result.Instance
    for _, t in ipairs(S.Targets) do
        if t.Model and inst:IsDescendantOf(t.Model) then return Hit(t, inst, result.Position) end
    end
    return S.Model ~= nil and inst:IsDescendantOf(S.Model)
end

-- ===== THE HUB + YOUR HIDEOUT ===================================================================================
local function HubPos(name: string): Vector3?
    local hub = workspace:FindFirstChild("HubWorld")
    local x = hub and hub:FindFirstChild(name)
    if not x then return nil end
    if x:IsA("BasePart") then return x.Position end
    if x:IsA("Model") then return x:GetPivot().Position end
    return nil
end
local function InCity(): boolean
    local r = Root()
    return r ~= nil and not LocalPlayer:GetAttribute("RunId") and Zones.Kind(r.Position) == "city"
end
local function InOwnHideout(): boolean
    local r = Root()
    return r ~= nil and LocalPlayer:GetAttribute("HideoutOf") == LocalPlayer.UserId and Zones.InHideout(r.Position)
end
local function HideoutPart(name: string): BasePart?
    local hl = workspace:FindFirstChild("HideoutLocal")
    local p = hl and hl:FindFirstChild(name, true)
    if p and p:IsA("Model") then p = p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true) end
    return (p and p:IsA("BasePart")) and p or nil
end

local function Visit(tag: string, target: string, label: string, text: any, goal: string, radius: number?): any
    return { Tag = tag, Save = true, Text = text, Goal = goal, Linger = 0.9,
        Marker = function() return HubPos(target), label end,
        Update = function(st)
            local r = Root()
            local p = HubPos(target)
            if not p then -- (not found: a CONTINUE button instead)
                if not st.Btn then st.Btn = AddButton("CONTINUE", C.Gold, 170, function() if Current() == st then Next() end end) end
                return false
            end
            return r ~= nil and os.clock() - st.ShownAt > 1.5 and Flat(r.Position - p).Magnitude < (radius or 20)
        end,
        Where = "city",
    }
end

local function HubSteps(): { any }
    local steps = {}
    table.insert(steps, Visit("THE HUB", "PortalVortex", "dungeon rift",
        "This is the hub. Every run starts at the DUNGEON RIFT: walk in, pick a DIFFICULTY (start on Easy) and BOT SKILL. Clear a floor, take the portal deeper, and the last floor sends you home with your loot.",
        "Walk to the Dungeon Rift", 26))
    table.insert(steps, Visit("THE HUB", "TreeAltar", "skill tree",
        function() return "Each level gives a passive point, and completing a difficulty the first time gives 2 more: never enough for the whole tree, so pick a direction. Open the SKILL TREE with " .. Menu("Tree", "SKILL TREE") .. ". The tree is also where your STRENGTH, DEXTERITY and INTELLECT come from." end,
        "Walk to the Skill Tree"))
    -- (2026-10-22, owner after the autoplay test: a new player reached level 9 with no class and 11 points unspent) pick the
    -- CLASS here, before the first run: one choice, the real class picker, the first pick is free
    table.insert(steps, { Tag = "CLASS", Save = true, Linger = 0.9,
        Text = "Pick your CLASS: it decides where your passive tree starts and which guns are yours (each class has a gun family and its own builds). You can path anywhere in the tree, and change class later at the Skill Tree with a Rebirth Shard. This first pick is free.",
        Goal = "Choose a class",
        Update = function(st)
            local s = State()
            if type(s) == "table" and s.Class ~= nil then return true end
            if not st.Btn then
                st.Btn = AddButton("CHOOSE CLASS", C.Gold, 200, function()
                    if Current() == st and hooks.OpenClassPicker then pcall(hooks.OpenClassPicker) end
                end)
            end
            return false
        end,
        Where = "any",
    })
    table.insert(steps, Visit("THE HUB", "RollAltar", "forge",
        "The FORGE rerolls and improves your weapons and gear with the materials you collect in runs. The UPGRADE anvil next to it levels a gun up.",
        "Walk to the Forge"))
    table.insert(steps, Visit("THE HUB", "InvLocker", "inventory",
        function() return "Your INVENTORY (with your stash) opens anywhere with " .. Menu("Inventory", "INVENTORY") .. ": equip guns and gear, compare them, or press EQUIP BEST to let the game pick. Guns have coloured SOCKETS for shot mods: " .. (Device() == "kb" and (Menu("Menu", "MENU") .. " > " .. Cap("MODS")) or Menu("Menu", "MODS")) .. "." end,
        "Walk to the Inventory"))
    table.insert(steps, Visit("THE HUB", "SeasonStand", "season pass",
        function() return "The SEASON PASS pays rewards as you play. Skins, gloves and more are in the STORE " .. Menu("Store", "STORE") .. " and your COSMETICS " .. Menu("Cosmetics", "COSMETICS") .. ": looks only, never power." end,
        "Walk to the Season Pass"))
    -- your hideout
    table.insert(steps, { Tag = "HIDEOUT", Save = true,
        Text = function() return "You have your own HIDEOUT. Open the hideout window with " .. Menu("Hideout", "HIDEOUT") .. " and press GO TO MY HIDEOUT." end,
        Goal = "Go to your hideout",
        Update = function() return InOwnHideout() end,
        Where = "any",
    })
    table.insert(steps, { Tag = "HIDEOUT", Save = true, Linger = 0.9,
        Text = "Home! This chest is your hideout STASH: extra room for gear between runs. Everything here works like the city's stations.",
        Goal = "Walk to the stash chest",
        Marker = function() local p = HideoutPart("HideoutStash"); return p and p.Position + Vector3.new(0, 3, 0) or nil, "stash" end,
        Update = function(st)
            local r, p = Root(), HideoutPart("HideoutStash")
            if not p then return os.clock() - st.ShownAt > 6 end
            return r ~= nil and os.clock() - st.ShownAt > 1.5 and Flat(r.Position - p.Position).Magnitude < 10
        end,
        Where = "hideout",
    })
    table.insert(steps, { Tag = "HIDEOUT", Save = true, Linger = 0.9,
        Text = "The practice alcove has a training DUMMY: shoot it to test your damage per second after a gear change.",
        Goal = "Walk into the practice alcove",
        Marker = function() return Zones.HIDEOUT_ORIGIN + Vector3.new(-24, 5, -30), "practice" end,
        Update = function(st)
            local r = Root()
            return r ~= nil and os.clock() - st.ShownAt > 1.5 and Zones.InHideoutRange(r.Position)
        end,
        Where = "hideout",
    })
    table.insert(steps, { Tag = "HIDEOUT", Save = true, Button = "CONTINUE",
        Text = function() return "Make it yours: " .. Menu("Hideout", "HIDEOUT") .. " > BUILD MODE places furniture on the grid. Buy pieces with gold in FURNITURE; trophies and rarer pieces come from bosses and achievements." end,
        Where = "any",
    })
    table.insert(steps, { Tag = "HIDEOUT", Save = true, Button = "CONTINUE",
        Text = "Friends and party members can walk into your hideout; anyone else can ASK while you're home (turn requests off in Settings > Social). The door takes you back to the city.",
        Where = "any",
    })
    table.insert(steps, { Tag = "DONE", Save = true, Button = "FINISH", Accent = C.Good, NoSkip = true,
        Text = "You're ready. Start your first run at the Dungeon Rift. The GUIDE button (top left of the hub) has a summary of everything and can replay this tutorial.",
        Where = "any",
    })
    return steps
end

-- ===== MAPS (level 100) =========================================================================================
local function MapSteps(): { any }
    local function Card(text: any, button: string?): any
        return { Button = button or "CONTINUE", Text = text, Where = "any" }
    end
    return {
        Card("Level 100: MAPS are open. A map is a timed 5-floor run that ends with a GUARDIAN boss, at your own level, and pays the best loot in the game."),
        Card(function() -- (LAUNCH CAP: names the top OPEN map band)
            local R = require(script.Parent:WaitForChild("Rifts"))
            local top = R.LADDER[math.clamp(math.ceil(math.min(R.MaxTier(), #R.LADDER * R.BAND) / R.BAND), 1, #R.LADDER)]
            return "Maps are opened with SIGILS. Your first ones come from bosses (with none in your bag, the next boss always drops one). After that, maps DROP INSIDE MAPS. A sigil's TIER sets the difficulty, from Ruin up to " .. tostring(top) .. ", and its mods change the floors."
        end),
        Card(function() return "Sigils open at the MAP DEVICE in your hideout's MAP ROOM: buy the room in the hideout window " .. Menu("Hideout", "HIDEOUT") ..
            " (gold or BOUND points), pick a sigil and its bot skill, then walk into the portal." end),
        Card("RISK AND REWARD: harder mods pay more loot. The guardian usually drops a new map; beat the timer (15 minutes on the first tiers, longer on the deep ones) and it often climbs a tier or two. Elites and the MAP CACHE by each floor's exit can drop maps too. Over time the guardian drops fewer and never higher ones; die and the map is gone."),
        Card("Your best tier, every map type beaten in time on each band (COMPLETION, on the map device) and maps finished earn MAP TREE points: upgrades to how your maps roll and what they pay. You'll never take the whole tree, so choose. Good hunting.", "GOT IT"),
    }
end

-- ===== UNLOCK CARDS (UPDATE 7, Loot Economy Plan section 6: "one new thing at a time ... Before the unlock level the
-- system is hidden entirely"): a short card for each system the moment your level opens it, the next time you're in the
-- hub / your hideout with no window open. Every unlock that's due and unseen goes into ONE session (an old save gets
-- them together once). GameSettings UnlockCards = the seen bits. Add an entry at the END (the bit is its index; 32 entries max, the setting holds 32 bits).
Tutorial.UNLOCKS = {
    { Level = 8, Tag = "LEVEL 8", Cards = {
        "TUMBLERS can now turn up on dungeon floors: a steel vault (in the side room on linked floors). PICK THE LOCK and hit each moving pin on its door before the next one shows.",
        "A missed shot or a pin you let slip resets the lock, and you have 30 seconds. Cracked: items with better odds, gold and (from level 18) Turncoats. No resets = a bonus.",
    } },
    { Level = 12, Tag = "LEVEL 12", Cards = {
        "The JOB BOARD is open (Challenges window, WEEKLY tab): five big jobs a week that count the same things as your daily contracts. Each pays gold, Prism and a crafting currency; all five pay a bonus. One reroll a week.",
    } },
    { Level = 15, Tag = "LEVEL 15", Cards = {
        "MARKSMAN GRADE: every mastery level on every gun is a point. Points open the next grade; pass its aim exam (an Aim Trial at a set rank, no timer, retry freely) to take it.",
        "Grades give bag slots, Job Board rerolls, contract slots, an early look at next week's Quarry and an emblem on your name tag. Never damage. Challenges window, MASTERY tab.",
    } },
    { Level = 18, Tag = "LEVEL 18", Cards = {
        "Two crafting currencies: TURNCOAT = REROLL GUN at the Forge (a gun becomes a random gun of your class). RIVET adds one random line to an item with room for it; it can be a penalty line.",
        "New floor encounter: THE RUNNER (a WANTED board; in the side room on linked floors). Call the mark and land enough hits as it sprints round the room before it escapes. It pays Rivets.",
    } },
    { Level = 30, Tag = "LEVEL 30", Cards = {
        "SCRAPE: removes one random line from an item. Every crafting currency does one random job: the Forge shows what each one does.",
        "New floor encounter: THE BREACH. Open it and targets spill out one after another, vanishing fast. Every kill before it closes pays more Scrapes.",
    } },
    { Level = 45, Tag = "LEVEL 45", Cards = {
        "Two more currencies: HONE raises one random line one tier (up to what the item's level allows), and WILDFIRE CORE rerolls everything on an item. Bosses drop Wildfire Cores.",
        "New floor encounter: THE MIRROR MATCH (a dark mirror). Your echo strafes and throws strikes at you: land enough hits without being hit once. It pays Hones.",
        "GUNWRIGHTS start dropping from bosses and elites: a mod for one gun with random lines. Fit it on a gun of that model (inventory, ITEMS tab); reroll it with Tuning Grit or salvage it for grit.",
    } },
    { Level = 80, Tag = "LEVEL 80", Cards = {
        "MARKED MAN: each week a named elite is marked on you. It can turn up on your floors (a gold skull with its name). Once you hit it, you have 6 seconds before it runs.",
        "If it gets away, or the floor clears around it, it comes back tougher and carrying a better gun. Bring it down and its gun is yours. A new Marked Man every Monday.",
    } },
    { Level = 65, Tag = "LEVEL 65", Cards = {
        "ZEROING: every gun has 5 zeroing tiers. Each one is earned by an aim feat with that gun (weak-spot kills, weak-spot hits in a row, elites, hits without a miss).",
        "Claim a tier for gold and a crafting currency, and pick one of its two perks. See them on the gun cards in Challenges > MASTERY.",
    } },
    { Level = 125, Tag = "LEVEL 125", Cards = {
        "HALLMARKS: now and then a drop comes with one line stamped into the metal (shown with a ◈). No crafting currency can change or remove it, so a great hallmark is the perfect base to craft around.",
    } },
    { Level = 100, Tag = "LEVEL 100", Cards = {
        "SIGIL MARKS: map guardians drop Sigil Marks. Draw up to two different ones onto a map at your map device before you open it (three with the map tree's WIDE MARGINS): more loot, more elites, a loot goblin, an encounter on every floor, or a sure Bearing.",
    } },
    { Level = 125, Tag = "LEVEL 125", Cards = {
        "THE SUMMIT: map guardians now drop BEARINGS (North, East, South, West). With one of each, press CLIMB THE SUMMIT at your map device: a major boss at full strength, with a big reward.",
        "BLACKFLUX: from guardians and the Summit. At the Forge, REDLINE pushes a Rare-or-better item past its limit (a bonus line, a reroll, nothing, or a line turns bad) and then locks it for good.",
    } },
    { Level = 100, Tag = "LEVEL 100", Cards = {
        "THE GAUNTLET RUN (Challenges > GAUNTLET RUN): three harsh floors, the same for everyone, on your hardest difficulty. One try a day, a big reward for a clear, and a board for the fastest.",
    } },
    { Level = 65, Tag = "LEVEL 65", Cards = {
        "CITY QUARTERS: three leaders now stand in the plaza (two by the wall between the gates, one at the market stall across from the Exchange). Each quarter hands out two bounties a day for STANDING, which buys currency, maps, Wildfire Cores and titles at its stall.",
        "Helping one quarter costs you half as much standing with its rival, so pick a side: Lantern Row likes precision, Wire Market speed, Iron Stair survival.",
    } },
    { Level = 80, Tag = "LEVEL 80", Cards = {
        "HAUL TAGS now drop from elites and bosses. Bring them into a PARTY run: when your party kills a boss, each tag adds two items to a shared chest and everyone who spent one picks an item.",
    } },
    { Level = 30, Tag = "LEVEL 30", Cards = {
        "THE EXCHANGE is open to you: put items in a TRADE tab of your stash, then list them at the Exchange stall in the plaza (or the stash's EXCHANGE button) for gold or any currency.",
        "Anyone can buy them, even while you're offline; your payment waits in the Exchange until you collect it (a 10% tax comes off).",
    } },
    { Level = 20, Tag = "LEVEL 20", Cards = {
        "CREWS (MENU > CREW): found one or ask to join one by name. Members share a tag on their name tags, a gold bank, and research that helps everyone: bag room, Exchange listings, Job Board rerolls and more.",
    } },
    -- (2026-10-22, owner: "move quarry to 22": it was the third card of the busy LEVEL 18 session)
    { Level = 22, Tag = "LEVEL 22", Cards = {
        "THE WEEK'S QUARRY: one Boss Trial boss a week with a twist, at your level's tier. Its first clear each week pays a big currency stack (Challenges window, WEEKLY tab).",
    } },
    -- (UPDATE 8 RARITY v4: Torment opens at 45 -- the first difficulty that drops Mythics)
    { Level = 45, Tag = "LEVEL 45", Cards = {
        "MYTHICS: from Torment up, drops can be MYTHIC (red): a Rare with one more line, up to 7. Very rare, and a little less rare on every harder difficulty.",
        "LODESTAR (any monster, incredibly rare): at the Forge, ASCEND turns a Rare into a Mythic and adds its Mythic line. Harder content also rolls higher ITEM LEVELS: those unlock the strongest line tiers.",
    } },
    -- (UPDATE 8 OFFENSE, the build systems; MENU > HOW IT WORKS = the Index's codex with all of it)
    { Level = 3, Tag = "LEVEL 3", Cards = {
        "SHOT MODS now drop from enemies (bosses drop better ones). Your gun has coloured SOCKETS: open MENU > MODS and put a mod in a socket of its own colour.",
        "Mods change what your shot DOES: chain to other enemies, fork, burst, add Heat or Volt, fire faster. Only the gun's BIGGEST LINKED group of sockets works, and mods level up as you kill.",
    } },
    { Level = 5, Tag = "LEVEL 5", Cards = {
        "Every hit has a DAMAGE TYPE: Kinetic, Heat, Cryo, Volt or Void. Each world resists one and is weak to another (the floor's title card says which), and each type has its own ailment: bleed, burn, freeze, shock, wither.",
        "Your gear guards you three ways: PLATING cuts plain hits, AGILITY dodges ordinary attacks (and a boss's plain hits, never its area attacks), WARD is a shield that recharges. RESISTANCES cut Heat, Cryo, Volt and Void. MENU > HOW IT WORKS has it all.",
    } },
    { Level = 8, Tag = "LEVEL 8", Cards = {
        "Socket currencies start dropping: BORE BIT rerolls how many sockets a gun has, SOLDER which ones are linked, TINT their colours (Forge, SOCKETS). Mods that no longer fit go back to your bag.",
        "Links need item level too: a 4-link from item level 25, a 5-link from 45, a 6-link from 75. A longer group on a lower-level gun only works up to that size.",
    } },
    { Level = 10, Tag = "LEVEL 10", Cards = {
        "BURNISH starts dropping: it adds 1-5% QUALITY to a mod in your bag (MENU > MODS, BURNISH on its row). Every 1% is +0.5% more damage, up to 20%.",
    } },
    { Level = 14, Tag = "LEVEL 14", Cards = {
        "ATTRIBUTES: STRENGTH, DEXTERITY and INTELLECT come only from the passive tree and gear lines. Strength adds life and Plating, Dexterity Agility and crit, Intellect Ward and elemental damage.",
        "Better guns, gear and mods now start to ASK for them: a tooltip line in red means you're short. Rifles, LMGs and shotguns need Strength, SMGs, pistols and snipers Dexterity, beam guns Intellect; red / green / blue mods the same.",
    } },
    -- (2026-10-22 tutorial audit: nothing told a new player where specializations come from)
    { Level = 35, Tag = "LEVEL 35", Cards = {
        "THE PROVING is open (Challenges window, PROVING tab): two floors of elites, then THE ASCENDANT. Every tier you clear gives 2 SPECIALIZATION points.",
        "Spend them in the skill tree (the SPECIALIZATION button). Each class has three specializations, each with one SIGNATURE rule nothing else in the game has. Your class's builds: MENU > HOW IT WORKS > CLASS BUILDS.",
    } },
}
local function UnlockSeen(): number return math.floor(tonumber(GameSettings.Get("UnlockCards")) or 0) end
function Tutorial.PendingUnlocks(level: number?): { number }
    local seen, out = UnlockSeen(), {}
    for i, u in ipairs(Tutorial.UNLOCKS) do
        if (level or 1) >= u.Level and bit32.band(seen, bit32.lshift(1, i - 1)) == 0 then table.insert(out, i) end
    end
    -- (a session of several cards plays them in level order, not list order: entries are appended as systems arrive)
    table.sort(out, function(a, b)
        local la, lb = Tutorial.UNLOCKS[a].Level, Tutorial.UNLOCKS[b].Level
        if la ~= lb then return la < lb end
        return a < b
    end)
    return out
end

-- ===== start / stop ==============================================================================================
function Tutorial.Active(): boolean return S ~= nil end
function Tutorial.InArena(): boolean return S ~= nil and S.Kind == "arena" end

function Tutorial.Stop()
    if not S then return end
    local s = S
    EndStep()
    ReturnLoan()
    Disconnect(s.Conns)
    if s.Model then s.Model:Destroy() end
    if ui.compare then ui.compare:Destroy(); ui.compare = nil end
    S = nil
    if card then card.Visible = false end
    if s.Quiet and hooks.Quiet then pcall(hooks.Quiet, false) end
    if ui.dia then ui.dia.Visible, ui.mLabel.Visible, ui.arrow.Visible = false, false, false end
    if trail.Folder then trail.Folder:Destroy(); trail.Folder = nil; trail.Bits = {} end
end

-- the frame loop of every session: markers, step ticks, objectives, the watchdog
local function Run(s: any)
    local acc = 0
    table.insert(s.Conns, RunService.RenderStepped:Connect(function(dt)
        if S ~= s then return end
        local st = Current()
        if not st then return end
        -- (the card steps aside while a window is open or you're in a run, and comes back after)
        local hidden = (hooks.MenuOpen and hooks.MenuOpen()) or (s.Kind ~= "arena" and LocalPlayer:GetAttribute("RunId") ~= nil)
        -- (2026-10-13, owner's phone test: a tutorial card stayed up in a fight) solo dungeon floors have no RunId: the card
        -- (offer / hub tour / maps) also steps aside anywhere you fight -- a dungeon floor or a duel arena -- until you're back
        if not hidden and s.Kind ~= "arena" then
            local r0 = Root()
            local zk = r0 and Zones.Kind(r0.Position)
            if zk == "dungeon" or zk == "pvp" then hidden = true end
        end
        -- (a hub / hideout step while you're somewhere else: the card stays, the step waits, it says where to go)
        local away = nil
        if s.Kind == "hub" and not hidden then
            local where = st.Where or "city"
            if where == "city" and not InCity() then away = "Head back to the hub city to carry on (or SKIP)." end
            if where == "hideout" and not InOwnHideout() then away = "Head back to your hideout to carry on (" .. Menu("Hideout", "HIDEOUT") .. " > GO TO MY HIDEOUT)." end
        end
        if away ~= s.Away2 then s.Away2 = away; Note(away, C.Warn) end
        card.Visible = not hidden
        if card.Visible ~= s.Quiet then s.Quiet = card.Visible; if hooks.Quiet then pcall(hooks.Quiet, card.Visible) end end
        -- placement: centred, but never over the hub's GUIDE / PATCH NOTES / CREDITS buttons (top left) and never wider than
        -- the screen (phones). The daily contracts box (top right) is hidden meanwhile (hooks.Quiet).
        local cam = workspace.CurrentCamera
        if cam and ui.fit then
            local kq = gui:FindFirstChild("InterfaceScale")
            local k = kq and kq.Scale or 1
            local vsx = cam.ViewportSize.X
            local w = 600 * k
            local left = (vsx - w) / 2
            if not (ui.corner and ui.corner.Parent) then
                local hud = LocalPlayer.PlayerGui:FindFirstChild("AimRngMasterHUD")
                ui.corner = hud and hud:FindFirstChild("GuideButtons", true) or nil
            end
            local cb = ui.corner
            if cb and cb.Visible and cb.Parent then
                -- (its buttons sit in a row from its left: the right edge of the last one)
                local right = cb.AbsolutePosition.X
                for _, b in ipairs(cb:GetChildren()) do
                    if b:IsA("GuiObject") and b.Visible then right = math.max(right, b.AbsolutePosition.X + b.AbsoluteSize.X) end
                end
                if left < right + 12 then left = right + 12 end
            end
            local fit = math.clamp((vsx - 12 - left) / w, 0.5, 1)
            if fit < 0.6 then left, fit = 12, math.min(1, (vsx - 24) / w) end -- (no room beside them: full width, it's a phone)
            -- (2026-10-13, owner's phone test) never down into the crosshair keep-out: a tall card on a short screen shrinks
            local vsy = cam.ViewportSize.Y
            local hgt = card.AbsoluteSize.Y / math.max(0.01, ui.fit.Scale) * fit
            local okI, ins = pcall(function() return game:GetService("GuiService"):GetGuiInset().Y end)
            -- (owner, same evening: the boxes got "a little TOO small" -> it may come down to 40 px above the centre (the
            -- crosshair keep-out is 44 px round it) and never under 0.6 of its size)
            local maxBottom = vsy * 0.5 - (okI and ins or 0) - 40 -- (gui space starts under the top bar)
            if 52 * k + hgt > maxBottom and hgt > 0 then fit = math.max(0.6, fit * (maxBottom - 52 * k) / hgt) end
            ui.fit.Scale = fit
            card.Position = UDim2.fromOffset(left / k, 52)
            if ui.compare and ui.compare.Parent then Tutorial.PlaceCompare(k) end
        end
        if st.Tick and not st.Done then
            local ok, err = pcall(st.Tick, st, dt)
            if not ok then warn("[Tutorial] tick: " .. tostring(err)) end
        end
        if st.Marker and not st.Done and not hidden and not away then
            local ok, p, label = pcall(st.Marker, st)
            Marker(ok and p or nil, ok and label or nil)
            if s.Kind ~= "arena" then Trail(ok and p or nil) else TrailHide() end
        else
            Marker(nil)
            TrailHide()
        end
        if st.Update and not st.Done and not hidden and not away then
            local ok, done = pcall(st.Update, st)
            if ok and done then Next() elseif not ok then warn("[Tutorial] update: " .. tostring(done)) end
        end
        -- fade the feedback line after a while
        if ui.note.Visible and not away and s.NoteAt and os.clock() - s.NoteAt > 4.5 then Note(nil) end
        -- the watchdog (4 times a second)
        acc += dt
        if acc < 0.25 then return end
        acc = 0
        if s.Kind == "arena" then
            local r = Root()
            local bad = (not Alive()) or LocalPlayer.Character ~= s.Char or LocalPlayer:GetAttribute("RunId") ~= nil or LocalPlayer:GetAttribute("PvpDuel") ~= nil
            if r and not bad then
                local rel = s.F:PointToObjectSpace(r.Position)
                local over = math.abs(rel.X) <= W and rel.Z <= 20 and rel.Z >= -L - 20 -- (above / below the hall's footprint)
                if not over or rel.Y > 60 or rel.Y < -400 then
                    -- (somewhere else entirely: a teleport home, the double-tap exit): the hands-on part ends
                    s.Away = (s.Away or 0) + 0.25
                    if s.Away > 1.5 then bad = true end
                elseif rel.Y < -25 then
                    if hooks.Teleport then pcall(hooks.Teleport, s.Start) end -- (fell out of the hall: back to its start)
                else
                    s.Away = 0
                end
            end
            if os.clock() - s.Began > 15 * 60 then
                if hooks.Toast then hooks.Toast("The tutorial timed out. You're back in the hub.") end
                Tutorial.LeaveArena(true)
            elseif bad then
                Tutorial.LeaveArena(false) -- (no teleport: a respawn / a run / a duel has already moved you)
            end
        end
    end))
end

local function NewSession(kind: string, title: string, steps: { any }, saveBase: number?): any
    BuildUI()
    Tutorial.Stop()
    S = { Kind = kind, Title = title, Steps = steps, Index = 0, Conns = {}, StepConns = {}, Targets = {}, SaveBase = saveBase, Began = os.clock(), Char = LocalPlayer.Character }
    return S
end

-- THE BASICS: build the hall, put you in it, run the steps; then the hub tour
function Tutorial.StartArena()
    local r = Root()
    if not (r and Alive()) then return false end
    local zk = Zones.Kind(r.Position)
    if LocalPlayer:GetAttribute("RunId") or LocalPlayer:GetAttribute("PvpDuel") or LocalPlayer:GetAttribute("Spectating") or zk == "dungeon" or zk == "pvp" then
        if hooks.Toast then hooks.Toast("Finish what you're doing first: the tutorial starts from the hub.") end
        return false
    end
    if hooks.StopTryOn then pcall(hooks.StopTryOn) end
    if hooks.CloseMenus then pcall(hooks.CloseMenus) end
    local s = NewSession("arena", "Tutorial", {}, nil)
    local model, F = BuildHall()
    s.Model, s.F = model, F
    s.Start = F * CFrame.new(0, 3.2, 0)
    s.Steps = ArenaSteps()
    Save(1)
    if hooks.Teleport then pcall(hooks.Teleport, s.Start) end
    s.OnFinish = function() Tutorial.LeaveArena(true, true) end
    Run(s)
    task.delay(0.4, function() if S == s then SetStep(1) end end)
    return true
end

-- leave the hall: your gun back, home (teleport = still standing in the hall), then the hub tour
function Tutorial.LeaveArena(teleport: boolean, finished: boolean?)
    local s = S
    if not (s and s.Kind == "arena") then return end
    local wasIn = false
    local r = Root()
    if r and s.F then
        local rel = s.F:PointToObjectSpace(r.Position)
        wasIn = math.abs(rel.X) < W and rel.Z < 20 and rel.Z > -L - 20 and rel.Y > -30 and rel.Y < 60
    end
    Tutorial.Stop()
    if teleport and wasIn and Alive() and hooks.Teleport then pcall(hooks.Teleport, HUB_SPAWN) end
    Save(STEP_HUB)
    if finished and hooks.Toast then hooks.Toast("Basics done! Now a quick look around the hub.") end
    -- the hub tour starts once you're standing in the city (a respawn / a run: when you're back)
    task.delay(1.2, function()
        if not S then Tutorial.StartHub(STEP_HUB) end
    end)
end

function Tutorial.StartHub(step: number?)
    local steps = HubSteps()
    local s = NewSession("hub", "Tutorial", steps, STEP_HUB)
    s.OnFinish = function()
        Save(STEP_DONE)
        if hooks.Toast then hooks.Toast("Tutorial complete. Good luck out there!") end
    end
    Run(s)
    local i = math.clamp((step or STEP_HUB) - STEP_HUB + 1, 1, #steps)
    SetStep(i)
    return true
end

function Tutorial.StartUnlocks(): boolean
    local st = State()
    local list = Tutorial.PendingUnlocks(type(st) == "table" and tonumber(st.Level) or 1)
    if #list == 0 then return false end
    local steps, mask = {}, 0
    for _, i in ipairs(list) do
        mask = bit32.bor(mask, bit32.lshift(1, i - 1))
        for _, text in ipairs(Tutorial.UNLOCKS[i].Cards) do
            table.insert(steps, { Button = "CONTINUE", Text = text, Where = "any", Tag = Tutorial.UNLOCKS[i].Tag })
        end
    end
    steps[#steps].Button = "GOT IT"
    local s = NewSession("unlock", "Unlocked", steps, nil)
    s.Accent = C.Gold
    s.UnlockMask = mask
    s.OnFinish = function() pcall(GameSettings.Set, "UnlockCards", bit32.bor(UnlockSeen(), mask)) end
    Run(s)
    SetStep(1)
    return true
end

function Tutorial.StartMaps()
    local s = NewSession("maps", "Maps", MapSteps(), nil)
    s.Accent = C.Purple
    s.OnFinish = function() pcall(GameSettings.Set, "MapsIntro", true) end
    Run(s)
    SetStep(1)
    return true
end

-- the one-time offer (saves from before the tutorial existed; Studio playtests)
function Tutorial.Offer()
    local s = NewSession("offer", "New", { { Tag = "TUTORIAL", Text = "New to Aimbound or want a refresher? A 4-minute guided run through the basics, the hub and your hideout.", Goal = nil } }, nil)
    s.Accent = C.Info
    s.Skippable = false
    Run(s)
    SetStep(1)
    AddButton("PLAY TUTORIAL", C.Gold, 190, function() Tutorial.StartArena() end)
    AddButton("NO THANKS", C.Steel, 150, function() Tutorial.Stop(); Save(STEP_DONE) end)
    -- (it goes away by itself after 30 seconds ON SCREEN: the guide window on top doesn't count)
    local s0 = S
    task.spawn(function()
        local shown = 0
        while S == s0 and shown < 30 do
            task.wait(0.5)
            if card and card.Visible then shown += 0.5 end
        end
        if S == s0 then Tutorial.Stop(); Save(STEP_DONE) end
    end)
    return true
end

-- SKIP: everything off, your gun back, home if you were in the hall
function Tutorial.Skip()
    if not S then return end
    local kind = S.Kind
    local s0mask = S.UnlockMask
    if kind == "arena" then
        local r = Root()
        local s = S
        local inHall = false
        if r and s.F then local rel = s.F:PointToObjectSpace(r.Position); inHall = math.abs(rel.X) < W and rel.Y > -30 and rel.Y < 60 end
        Tutorial.Stop()
        if inHall and Alive() and hooks.Teleport then pcall(hooks.Teleport, HUB_SPAWN) end
    else
        Tutorial.Stop()
    end
    if kind == "maps" then
        pcall(GameSettings.Set, "MapsIntro", true)
    elseif kind == "unlock" then
        pcall(GameSettings.Set, "UnlockCards", bit32.bor(UnlockSeen(), s0mask or 0)) -- (UPDATE 7: skipped = seen)
    else
        Save(STEP_DONE)
        if hooks.Toast then hooks.Toast("Tutorial skipped. Replay it any time from the GUIDE (top left of the hub).") end
    end
end

-- REPLAY (the guide's button)
function Tutorial.Replay()
    if hooks.CloseMenus then pcall(hooks.CloseMenus) end
    return Tutorial.StartArena()
end

-- ===== join + level 100 ==========================================================================================
local function NewSave(st: any): boolean
    local secs = type(st.StatsTracking) == "table" and tonumber(st.StatsTracking.PlaySeconds) or 0
    return (tonumber(st.Level) or 1) <= 1 and (secs or 0) < 900
end
-- called once the save is loaded (AimRngClient's welcome-guide spawn). true = the tutorial took the join (no guide)
function Tutorial.OnJoin(): boolean
    local step = tonumber(GameSettings.Get("TutorialStep")) or 0
    if step >= STEP_DONE then return false end
    if LocalPlayer:GetAttribute("RunId") then return false end
    if step >= STEP_HUB then
        Tutorial.StartHub(step)
        return true
    end
    -- (Studio playtests always start from a fresh mock save: there it's the offer card, unless workspace DevTutorialAuto)
    local studio = RunService:IsStudio() and not workspace:GetAttribute("DevTutorialAuto")
    if NewSave(State()) and not studio then
        return Tutorial.StartArena()
    end
    task.delay(4, function() if not S and (tonumber(GameSettings.Get("TutorialStep")) or 0) < STEP_DONE then Tutorial.Offer() end end)
    return false
end

function Tutorial.Init(h: any)
    hooks = h or {}
    BuildUI()
    -- level 100: the maps cards, once, the next time you're in the hub / your hideout with no window open
    task.spawn(function()
        while true do
            task.wait(2)
            local st = State()
            -- (PLAYTEST 2026-10-31: an UNLOCKED card popped up over a running Aim Trial's HUD -- hooks.Busy = a trial is running)
            local busy = hooks.Busy ~= nil and hooks.Busy() == true
            if not S and type(st) == "table" and (tonumber(st.Level) or 1) >= 100 and GameSettings.Get("MapsIntro") ~= true
                and not LocalPlayer:GetAttribute("RunId") and not (hooks.MenuOpen and hooks.MenuOpen()) and not busy then
                local r = Root()
                local k = r and Zones.Kind(r.Position)
                if k == "city" or k == "hideout" then Tutorial.StartMaps() end
            elseif not S and type(st) == "table" and (tonumber(GameSettings.Get("TutorialStep")) or 0) >= STEP_DONE
                and #Tutorial.PendingUnlocks(tonumber(st.Level) or 1) > 0
                and not LocalPlayer:GetAttribute("RunId") and not (hooks.MenuOpen and hooks.MenuOpen()) and not busy then
                -- (UPDATE 7 UNLOCK CARDS: after the tutorial, in the hub / your hideout)
                local r = Root()
                local k = r and Zones.Kind(r.Position)
                if k == "city" or k == "hideout" then Tutorial.StartUnlocks() end
            elseif S and (S.Kind == "maps" or S.Kind == "unlock") then
                -- (launch sweep 2026-10-13: the cards stayed up through a run / duel started without reading them --
                -- they step aside and come back on the next hub visit; MapsIntro is only set by finishing / skipping)
                local r = Root()
                local k = r and Zones.Kind(r.Position)
                if LocalPlayer:GetAttribute("RunId") or busy or (k ~= nil and k ~= "city" and k ~= "hideout") then Tutorial.Stop() end
            end
        end
    end)
    -- Studio test hook: Player attr DevTut = start | hub | maps | offer | skip | next | hit[:head] | kill | pickup | equip | orbs | reset
    if RunService:IsStudio() then
        LocalPlayer:GetAttributeChangedSignal("DevTut"):Connect(function()
            local v = LocalPlayer:GetAttribute("DevTut")
            if type(v) ~= "string" or v == "" then return end
            LocalPlayer:SetAttribute("DevTut", nil)
            local cmd, arg = v:match("^(%w+):?(.*)$")
            local st = Current()
            if cmd == "start" then Tutorial.StartArena()
            elseif cmd == "hub" then Tutorial.StartHub(tonumber(arg) or STEP_HUB)
            elseif cmd == "maps" then Tutorial.StartMaps()
            elseif cmd == "offer" then Tutorial.Offer()
            elseif cmd == "skip" then Tutorial.Skip()
            elseif cmd == "next" then Next()
            elseif cmd == "reset" then Save(0); pcall(GameSettings.Set, "MapsIntro", false); pcall(GameSettings.Set, "UnlockCards", 0)
            elseif cmd == "unlocks" then pcall(GameSettings.Set, "UnlockCards", 0); Tutorial.StartUnlocks()
            elseif cmd == "join" then Tutorial.OnJoin()
            elseif cmd == "pickup" and st then st.Picked = true
            elseif cmd == "equip" and st then Tutorial.EquipLoan(st)
            elseif cmd == "orbs" and st and st.Orbs then
                for orb in pairs(st.Orbs) do for _ = 1, 6 do if st.Boss.OnPart then st.Boss.OnPart(orb) end end end
            elseif (cmd == "hit" or cmd == "kill") and S then
                for _, t in ipairs(S.Targets) do
                    if not t.Dead and t.Model.Parent then
                        local part = t.Model:FindFirstChild(arg == "head" and "Head" or "Body")
                        if part then
                            local n = (cmd == "kill") and 400 or 1
                            for _ = 1, n do if t.Dead or not t.Model.Parent then break end; Hit(t, part, part.Position) end
                        end
                        if cmd == "hit" then break end
                    end
                end
            end
        end)
    end
end

return Tutorial
