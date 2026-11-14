--!nocheck
-- ECHO DUEL (UPDATE 7 run encounter, L45, DODGE + HIT -> Temper; see Encounters for the shared rules). A dark mirror by
-- the entrance; FACE YOUR ECHO calls a ghost into the room. It strafes across your view and every Params.Every s throws a
-- telegraphed strike at where you stand: a CIRCLE (Params.Radius) or a LANE toward you, red ground marks that fill over
-- Params.Windup s. Standing in one when it fires = the echo wins (hit-only, no tanking: nothing damages you, it just ends).
-- Land Params.Hits (pulls x Encounters.ShotWeight()) inside Params.Window s. Client-judged; the server pays.
local E = require(script.Parent:WaitForChild("Encounters"))
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local M = {}
local DEF = E.Defs.ECHO_DUEL
local P = E.P
local session = nil
local RED = Color3.fromRGB(120, 230, 255) -- (the echo's strikes are ITS colour: the room's enemies already throw red)

function M.Build(dungeon: Instance, layout: any, onStart: () -> ()): (Model, CFrame)
    local face = E.Face(dungeon, layout)
    local model = Instance.new("Model")
    model.Name = "Encounter_ECHO_DUEL"
    model:SetAttribute("KeepNeon", true)
    local dark = Color3.fromRGB(26, 28, 36)
    P(model, { Name = "Base", Size = Vector3.new(6, 0.8, 3), CFrame = face * CFrame.new(0, 0.4, 0), Color = dark, Material = Enum.Material.Basalt })
    local frame = P(model, { Name = "Frame", Size = Vector3.new(5, 8.6, 0.6), CFrame = face * CFrame.new(0, 5.1, 0), Color = dark, Material = Enum.Material.Metal })
    local glass = P(model, { Name = "Mirror", Size = Vector3.new(4.2, 7.8, 0.1), CFrame = face * CFrame.new(0, 5.1, -0.34), Color = Color3.fromRGB(40, 60, 80),
        Material = Enum.Material.SmoothPlastic, Reflectance = 0.25, CanCollide = false })
    local _ = glass
    for _, sx in ipairs({ -1, 1 }) do
        P(model, { Name = "Edge", Size = Vector3.new(0.12, 7.8, 0.12), CFrame = face * CFrame.new(sx * 2.15, 5.1, -0.4), Color = DEF.Color, Material = Enum.Material.Neon, CanCollide = false })
    end
    P(model, { Name = "Crest", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = face * CFrame.new(0, 9.7, 0), Color = DEF.Color, Material = Enum.Material.Neon, CanCollide = false })
    E.Plate(model, face * CFrame.new(0, 1.5, -0.8), 4.2, "MIRROR MATCH", DEF.Color)
    E.Prompt(frame, DEF.Prompt, DEF.Name, onStart)
    model.PrimaryPart = frame
    model.Parent = dungeon
    return model, face
end

function M.Mark(model: Model?, state: string)
    E.MarkPlate(model, state, "SHATTERED", "OUTMATCHED")
end

-- ---------- the run ----------
local function MakeGhost(cf: CFrame, size: number): Model
    local m = Instance.new("Model")
    m.Name = "EchoGhost"
    m:SetAttribute("KeepNeon", true)
    local body = P(m, { Name = "Body", Size = Vector3.new(2, 3.6, 1.4) * size, CFrame = cf, Color = Color3.fromRGB(70, 150, 200), Material = Enum.Material.SmoothPlastic,
        Transparency = 0.25, CanCollide = false })
    P(m, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5) * size, CFrame = cf * CFrame.new(0, 2.6 * size, 0),
        Color = DEF.Color, Material = Enum.Material.Neon, CanCollide = false })
    local hl = Instance.new("Highlight")
    hl.FillColor, hl.FillTransparency = DEF.Color, 0.6
    hl.OutlineColor, hl.OutlineTransparency = Color3.new(1, 1, 1), 0
    hl.DepthMode = Enum.HighlightDepthMode.Occluded
    hl.Parent = m
    m.PrimaryPart = body
    m.Parent = Workspace
    return m
end

local function ClearMarks(s)
    for _, mk in ipairs(s.Marks) do if mk.Part then mk.Part:Destroy() end end
    s.Marks = {}
end

local function Finish(s, ok: boolean, why: string?)
    if session ~= s then return end
    session = nil
    if s.Conn then s.Conn:Disconnect() end
    if s.Ghost then s.Ghost:Destroy() end
    ClearMarks(s)
    E.HudDone(s.Hud, ok and "SHATTERED" or (why or "OUTMATCHED"), ok and string.format("%.1f s", os.clock() - s.Start) or "")
    pcall(s.OnDone, { Ok = ok, Resets = 0, Time = os.clock() - s.Start })
end

function M.Active(): boolean return session ~= nil end
function M.Cancel() if session then Finish(session, false, "OUTMATCHED") end end

function M.OnShot(result: RaycastResult?, consumesAmmo: boolean?): boolean
    local s = session
    if not s then return false end
    local hit = result and s.Ghost and result.Instance and result.Instance:IsDescendantOf(s.Ghost)
    if consumesAmmo ~= false then s.Pull = { Counted = false } end
    if not hit then return false end
    if s.Pull and not s.Pull.Counted then
        s.Pull.Counted = true
        s.Count += (E.ShotWeight and E.ShotWeight() or 1)
        if s.SoundHelper then pcall(s.SoundHelper.Play, "HitCrit") end
        if s.Count >= s.Params.Hits then Finish(s, true) end
    end
    return true
end

-- a strike: a red mark that fills over the windup, then judges where you stand
local function Strike(s, root: BasePart)
    local kind = (s.Rng:NextNumber() < 0.6) and "Circle" or "Lane"
    local at = root.Position + root.AssemblyLinearVelocity * Vector3.new(1, 0, 1) * 0.25 -- (a little lead)
    local gy = E.GroundY(s.Dungeon, at) + 0.15
    local part
    if kind == "Circle" then
        part = P(Workspace, { Name = "EchoMark", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, s.Params.Radius * 2, s.Params.Radius * 2),
            CFrame = CFrame.new(at.X, gy, at.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = RED, Material = Enum.Material.Neon, Transparency = 0.75, CanCollide = false })
    else
        local from = s.Ghost.PrimaryPart.Position
        local flat = Vector3.new(at.X - from.X, 0, at.Z - from.Z)
        local len = math.max(8, flat.Magnitude + 10)
        local dirv = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, 1)
        local mid = Vector3.new(from.X, gy, from.Z) + dirv * (len / 2)
        part = P(Workspace, { Name = "EchoMark", Size = Vector3.new(4, 0.12, len), CFrame = CFrame.lookAt(mid, mid + dirv), Color = RED,
            Material = Enum.Material.Neon, Transparency = 0.75, CanCollide = false })
    end
    part.CanQuery = false
    part:SetAttribute("KeepNeon", true)
    table.insert(s.Marks, { Part = part, Kind = kind, At = os.clock(), Center = Vector3.new(at.X, gy, at.Z) })
end

local function Judge(s, mk, root: BasePart): boolean
    local p = root.Position
    if math.abs(p.Y - mk.Part.Position.Y) > 7 then return false end -- (jumped clear / on a ledge)
    if mk.Kind == "Circle" then
        return (Vector3.new(p.X, 0, p.Z) - Vector3.new(mk.Center.X, 0, mk.Center.Z)).Magnitude <= s.Params.Radius
    end
    local rel = mk.Part.CFrame:PointToObjectSpace(p)
    return math.abs(rel.X) <= 2 and math.abs(rel.Z) <= mk.Part.Size.Z / 2
end

function M.DevAct(what: string)
    local s = session
    if not s then return end
    if what == "hit" and s.Ghost then M.OnShot({ Instance = s.Ghost.PrimaryPart } :: any, true)
    elseif what == "miss" then M.OnShot(nil, true)
    elseif what == "strike" then s.NextStrike = 0 end
end

function M.Start(ctx: any)
    if session then return end
    local layout = ctx.Layout
    local cz, half = layout.CombatZ, layout.CombatSize / 2 - 10
    local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local from = root and root.Position or ctx.Anchor.Position
    local cx = layout.CombatX or 0 -- (LINKED ROOMS: the side room)
    local toMid = (Vector3.new(cx, from.Y, cz) - from) * Vector3.new(1, 0, 1)
    local dir = toMid.Magnitude > 1 and toMid.Unit or Vector3.new(0, 0, 1)
    local home = from + dir * 30
    home = Vector3.new(math.clamp(home.X, cx - half, cx + half), home.Y, math.clamp(home.Z, cz - half, cz + half))
    local s = {
        Params = ctx.Params, SoundHelper = ctx.SoundHelper, OnDone = ctx.OnDone, Count = 0, Start = os.clock(), Rng = Random.new(),
        Hud = E.BuildHud(ctx.UIStyle, "MIRROR MATCH", DEF.Color), Dungeon = ctx.Dungeon, Home = home, Side = Vector3.new(dir.Z, 0, -dir.X),
        NextStrike = os.clock() + 1.5, Marks = {}, Y = E.GroundY(ctx.Dungeon, home) + 2.4,
    }
    s.Ghost = MakeGhost(CFrame.new(home.X, s.Y, home.Z), ctx.Params.Size or 1)
    session = s
    if s.SoundHelper then pcall(s.SoundHelper.Play, "ShieldUp") end
    s.Conn = RunService.RenderStepped:Connect(function()
        if session ~= s then return end
        local now = os.clock()
        if now - s.Start >= s.Params.Window then Finish(s, false, "OUT OF TIME"); return end
        local char = Players.LocalPlayer.Character
        local r = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not r or not hum or hum.Health <= 0 or (ctx.Model and ctx.Model.Parent == nil) then Finish(s, false, "OUTMATCHED"); return end
        -- strafe: a smooth sideways sweep (two sines) round its home, facing you
        local t = now - s.Start
        local amp = 14
        local off = s.Side * (math.sin(t * s.Params.Speed / amp) * amp + math.sin(t * 2.3) * 2)
        local pos = Vector3.new(s.Home.X + off.X, s.Y + math.sin(t * 3) * 0.4, s.Home.Z + off.Z)
        s.Ghost:PivotTo(CFrame.lookAt(pos, Vector3.new(r.Position.X, pos.Y, r.Position.Z)))
        -- strikes
        if now >= s.NextStrike then
            s.NextStrike = now + s.Params.Every
            Strike(s, r)
        end
        for i = #s.Marks, 1, -1 do
            local mk = s.Marks[i]
            local k = (now - mk.At) / s.Params.Windup
            if k >= 1 then
                local caught = Judge(s, mk, r)
                mk.Part:Destroy()
                table.remove(s.Marks, i)
                if caught then
                    if s.SoundHelper then pcall(s.SoundHelper.Play, "Empty") end
                    Finish(s, false, "HIT: OUTMATCHED")
                    return
                end
            else
                mk.Part.Transparency = 0.75 - 0.45 * k
            end
        end
        local h = s.Hud
        if h then
            E.HudTick(h)
            local n = math.min(s.Params.Hits, math.floor(s.Count + 0.001))
            h.Main.Text = string.format("%d / %d hits", n, s.Params.Hits)
            h.Info.Text = string.format("%d s left  •  don't get hit", math.ceil(s.Params.Window - t))
        end
    end)
end

return M
