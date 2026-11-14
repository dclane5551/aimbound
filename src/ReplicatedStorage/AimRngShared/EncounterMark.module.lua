--!nocheck
-- BOUNTY MARK (UPDATE 7 run encounter, L18, TRACKING -> Graft; see Encounters for the shared rules). A WANTED board by the
-- entrance; CALL THE MARK sends a marked target sprinting round the combat room: it jukes (a new heading every Juke s,
-- leaning away from you and off the walls) and bolts for 0.6 s whenever it's hit. Land Params.Hits (each trigger pull that
-- lands counts once x Encounters.ShotWeight(): slow guns count more) inside Params.Window s, or it escapes. Judged on the
-- client like the Vault Lock; the server pays (DungeonRuns EncounterAction -> CombatServer.EncounterReward).
local E = require(script.Parent:WaitForChild("Encounters"))
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local M = {}
local DEF = E.Defs.BOUNTY_MARK
local P = E.P
local session = nil

function M.Build(dungeon: Instance, layout: any, onStart: () -> ()): (Model, CFrame)
    local face = E.Face(dungeon, layout)
    local model = Instance.new("Model")
    model.Name = "Encounter_BOUNTY_MARK"
    model:SetAttribute("KeepNeon", true)
    local wood, dark = Color3.fromRGB(92, 64, 44), Color3.fromRGB(32, 35, 42)
    -- two posts + a board with a wanted poster (a red skull mark) and a lantern
    for _, sx in ipairs({ -1, 1 }) do
        P(model, { Name = "Post", Size = Vector3.new(0.6, 8, 0.6), CFrame = face * CFrame.new(sx * 3.2, 4, 0), Color = wood, Material = Enum.Material.Wood })
    end
    local board = P(model, { Name = "Board", Size = Vector3.new(7, 4.6, 0.4), CFrame = face * CFrame.new(0, 5.4, 0), Color = Color3.fromRGB(70, 50, 36), Material = Enum.Material.WoodPlanks })
    local poster = P(model, { Name = "Poster", Size = Vector3.new(3.4, 4, 0.06), CFrame = face * CFrame.new(0, 5.4, -0.24), Color = Color3.fromRGB(214, 196, 150), Material = Enum.Material.SmoothPlastic, CanCollide = false })
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 50
    sg.LightInfluence = 0.6
    sg.Parent = poster
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Size = UDim2.fromScale(1, 0.3)
    t.Font = Enum.Font.GothamBlack
    t.TextScaled = true
    t.Text = "WANTED"
    t.TextColor3 = Color3.fromRGB(120, 30, 20)
    t.Parent = sg
    local mk = Instance.new("TextLabel")
    mk.BackgroundTransparency = 1
    mk.Position = UDim2.fromScale(0.15, 0.3)
    mk.Size = UDim2.fromScale(0.7, 0.55)
    mk.Font = Enum.Font.GothamBlack
    mk.TextScaled = true
    mk.Text = "◆"
    mk.TextColor3 = DEF.Color
    mk.Parent = sg
    P(model, { Name = "Lantern", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), CFrame = face * CFrame.new(3.2, 8.3, 0), Color = DEF.Color, Material = Enum.Material.Neon, CanCollide = false })
    E.Plate(model, face * CFrame.new(0, 1.6, -0.35), 4.6, "THE RUNNER", DEF.Color)
    E.Prompt(board, DEF.Prompt, DEF.Name, onStart)
    model.PrimaryPart = board
    model.Parent = dungeon
    return model, face
end

function M.Mark(model: Model?, state: string)
    E.MarkPlate(model, state, "COLLECTED", "ESCAPED")
end

-- ---------- the run ----------
local function MakeTarget(cf: CFrame, size: number): Model
    local m = Instance.new("Model")
    m.Name = "BountyTarget"
    m:SetAttribute("KeepNeon", true)
    local body = P(m, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4) * size, CFrame = cf, Color = Color3.fromRGB(120, 30, 26), Material = Enum.Material.SmoothPlastic, CanCollide = false })
    P(m, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3) * size, CFrame = cf * CFrame.new(0, 1.7 * size, 0), Color = DEF.Color, Material = Enum.Material.Neon, CanCollide = false })
    local ring = P(m, { Name = "MarkRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 2.2, 2.2) * size, CanCollide = false,
        CFrame = cf * CFrame.new(0, 3.1 * size, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 205, 80), Material = Enum.Material.Neon })
    ring.CanQuery = false
    local hl = Instance.new("Highlight") -- (readable at 40+ studs against a busy room; not through walls)
    hl.FillColor, hl.FillTransparency = DEF.Color, 0.55
    hl.OutlineColor, hl.OutlineTransparency = Color3.fromRGB(255, 230, 160), 0
    hl.DepthMode = Enum.HighlightDepthMode.Occluded
    hl.Parent = m
    m.PrimaryPart = body
    m.Parent = Workspace
    return m
end

local function Finish(s, ok: boolean, why: string?)
    if session ~= s then return end
    session = nil
    if s.Conn then s.Conn:Disconnect() end
    if s.Target then s.Target:Destroy() end
    E.HudDone(s.Hud, ok and "COLLECTED" or (why or "ESCAPED"), ok and string.format("%.1f s", os.clock() - s.Start) or "")
    pcall(s.OnDone, { Ok = ok, Resets = 0, Time = os.clock() - s.Start })
end

function M.Active(): boolean return session ~= nil end
function M.Cancel() if session then Finish(session, false, "ESCAPED") end end

local function Hit(s)
    local w = E.ShotWeight and E.ShotWeight() or 1
    s.Count += w
    s.BoltUntil = os.clock() + 0.6
    if s.SoundHelper then pcall(s.SoundHelper.Play, "HitCrit") end
    local head = s.Target and s.Target:FindFirstChild("Head")
    if head then
        head.Color = Color3.new(1, 1, 1)
        task.delay(0.08, function() if head.Parent then head.Color = DEF.Color end end)
    end
    if s.Count >= s.Params.Hits then Finish(s, true) end
end

-- a pull that lands counts once (its other pellets / burst rounds join the same pull); nothing resets on a miss
function M.OnShot(result: RaycastResult?, consumesAmmo: boolean?): boolean
    local s = session
    if not s then return false end
    local hit = result and s.Target and result.Instance and result.Instance:IsDescendantOf(s.Target)
    if consumesAmmo ~= false then s.Pull = { Counted = false } end
    if not hit then return false end
    if s.Pull and not s.Pull.Counted then
        s.Pull.Counted = true
        Hit(s)
    end
    return true
end

function M.DevAct(what: string)
    local s = session
    if not s then return end
    if what == "hit" and s.Target then M.OnShot({ Instance = s.Target.PrimaryPart } :: any, true)
    elseif what == "miss" then M.OnShot(nil, true) end
end

function M.Start(ctx: any)
    if session then return end
    local layout, dungeon = ctx.Layout, ctx.Dungeon
    local cz, half = layout.CombatZ, layout.CombatSize / 2 - 8
    local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local from = root and root.Position or ctx.Anchor.Position
    -- spawn toward the middle of the room, 35-50 studs from you
    local cx = layout.CombatX or 0 -- (LINKED ROOMS: the side room)
    local toMid = (Vector3.new(cx, from.Y, cz) - from) * Vector3.new(1, 0, 1)
    local dir = toMid.Magnitude > 1 and toMid.Unit or Vector3.new(0, 0, 1)
    local p0 = from + dir * 42
    p0 = Vector3.new(math.clamp(p0.X, cx - half, cx + half), p0.Y, math.clamp(p0.Z, cz - half, cz + half))
    local s = {
        Params = ctx.Params, SoundHelper = ctx.SoundHelper, OnDone = ctx.OnDone, Count = 0, Start = os.clock(), Rng = Random.new(),
        Hud = E.BuildHud(ctx.UIStyle, "THE RUNNER", DEF.Color), Pos = p0, Heading = math.atan2(dir.X, dir.Z), Want = 0, NextJuke = 0,
        BoltUntil = 0, GroundAt = 0, Y = p0.Y, Dungeon = dungeon, CZ = cz, CX = cx, Half = half,
    }
    s.Want = s.Heading
    s.Target = MakeTarget(CFrame.new(p0), ctx.Params.Size or 1)
    session = s
    if s.SoundHelper then pcall(s.SoundHelper.Play, "ShieldUp") end
    s.Conn = RunService.RenderStepped:Connect(function(dt)
        if session ~= s then return end
        local now = os.clock()
        if now - s.Start >= s.Params.Window then Finish(s, false, "ESCAPED"); return end
        local char = Players.LocalPlayer.Character
        local r = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not r or not hum or hum.Health <= 0 or (ctx.Model and ctx.Model.Parent == nil) then Finish(s, false, "ESCAPED"); return end
        -- juke: a new heading, away from you (+-70 deg) and back toward the middle near a wall
        if now >= s.NextJuke then
            s.NextJuke = now + s.Params.Juke * s.Rng:NextNumber(0.7, 1.3)
            local away = (s.Pos - r.Position) * Vector3.new(1, 0, 1)
            local base = away.Magnitude > 0.1 and math.atan2(away.X, away.Z) or s.Heading
            s.Want = base + math.rad(s.Rng:NextNumber(-110, 110))
        end
        local edge = math.max(math.abs(s.Pos.X - s.CX) / s.Half, math.abs(s.Pos.Z - s.CZ) / s.Half)
        if edge > 0.82 then s.Want = math.atan2(s.CX - s.Pos.X, s.CZ - s.Pos.Z) end
        local d = (s.Want - s.Heading + math.pi) % (2 * math.pi) - math.pi
        s.Heading += math.clamp(d, -7 * dt, 7 * dt)
        local speed = s.Params.Speed * ((now < s.BoltUntil) and 1.6 or 1)
        local np = s.Pos + Vector3.new(math.sin(s.Heading), 0, math.cos(s.Heading)) * speed * dt
        np = Vector3.new(math.clamp(np.X, s.CX - s.Half, s.CX + s.Half), np.Y, math.clamp(np.Z, s.CZ - s.Half, s.CZ + s.Half))
        if now >= s.GroundAt then -- (the floor under it, 8 times a second)
            s.GroundAt = now + 0.125
            s.Y = E.GroundY(s.Dungeon, np) + 1.6
        end
        s.Pos = Vector3.new(np.X, s.Pos.Y + (s.Y - s.Pos.Y) * math.min(1, dt * 10), np.Z)
        local bob = math.sin(now * 14) * 0.15
        s.Target:PivotTo(CFrame.new(s.Pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, s.Heading, 0))
        local h = s.Hud
        if h then
            E.HudTick(h)
            local n = math.min(s.Params.Hits, math.floor(s.Count + 0.001))
            h.Main.Text = string.format("%d / %d hits", n, s.Params.Hits)
            h.Info.Text = string.format("%d s left", math.ceil(s.Params.Window - (now - s.Start)))
        end
    end)
end

return M
