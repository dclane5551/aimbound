--!nocheck
-- RIFT TEAR (UPDATE 7 run encounter, L30, FLICKING -> Strip Shard; see Encounters for the shared rules). A violet tear
-- hangs by the entrance; OPEN THE TEAR spills targets into the room one after another for Params.Window s: each appears
-- somewhere 18-40 studs in front of you (within +-55 deg of where the tear faced you), lives Params.Life s, then
-- vanishes (no penalty). Every kill counts; the payout grows with kills (CombatServer.EncounterReward). Client-judged.
local E = require(script.Parent:WaitForChild("Encounters"))
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local M = {}
local DEF = E.Defs.RIFT_TEAR
local P = E.P
local session = nil
M.MAX_RATE = 3 -- (kills a second the server accepts at most: Window x MAX_RATE)

function M.Build(dungeon: Instance, layout: any, onStart: () -> ()): (Model, CFrame)
    local face = E.Face(dungeon, layout)
    local model = Instance.new("Model")
    model.Name = "Encounter_RIFT_TEAR"
    model:SetAttribute("KeepNeon", true)
    -- a broken stone frame round a tall glowing tear (stacked thin slabs = a lens shape), shards floating round it
    local stone = Color3.fromRGB(46, 42, 58)
    P(model, { Name = "Base", Size = Vector3.new(8, 0.8, 4), CFrame = face * CFrame.new(0, 0.4, 0), Color = stone, Material = Enum.Material.Slate })
    for _, sx in ipairs({ -1, 1 }) do
        P(model, { Name = "Pillar", Size = Vector3.new(1, 9, 1.4), CFrame = face * CFrame.new(sx * 3.4, 4.9, 0) * CFrame.Angles(0, 0, math.rad(sx * 4)), Color = stone, Material = Enum.Material.Slate })
    end
    -- the tear: an outer lens + a brighter inner slit, each a stretched sphere (smooth edges)
    local function Lens(name: string, w: number, h: number, col: Color3, t: number): BasePart
        local part = P(model, { Name = name, Size = Vector3.new(w, h, 0.25), CFrame = face * CFrame.new(0, 5, 0), CanCollide = false,
            Color = col, Material = Enum.Material.Neon, Transparency = t })
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.Sphere
        mesh.Parent = part
        return part
    end
    Lens("Tear", 4.4, 8.6, DEF.Color, 0.35)
    local core = Lens("TearCore", 1.3, 7.2, Color3.fromRGB(210, 120, 255), 0.1)
    for k = 1, 5 do
        local a = k * 1.256
        P(model, { Name = "Shard", Size = Vector3.new(0.3, 0.9, 0.3), CFrame = face * CFrame.new(math.cos(a) * 2.6, 5 + math.sin(a) * 3.4, -0.4) * CFrame.Angles(a, a * 2, 0),
            Color = DEF.Color, Material = Enum.Material.Neon, CanCollide = false })
    end
    E.Plate(model, face * CFrame.new(0, 1.3, -1.1), 4.2, "THE BREACH", DEF.Color)
    E.Prompt(core, DEF.Prompt, DEF.Name, onStart)
    model.PrimaryPart = core
    model.Parent = dungeon
    return model, face
end

function M.Mark(model: Model?, state: string)
    E.MarkPlate(model, state, "SEALED", "COLLAPSED")
    if state == "OPEN" or state == "JAMMED" then
        for _, p in ipairs(model and model:GetChildren() or {}) do
            if p:IsA("BasePart") and (p.Name == "Tear" or p.Name == "TearCore") then p.Transparency = 0.85 end
        end
    end
end

local function DropTarget(s, burst: boolean)
    local t = s.Target
    s.Target = nil
    if not t then return end
    if burst and t.Parent then
        local f = P(Workspace, { Name = "TearBurst", Shape = Enum.PartType.Ball, Size = t.Size * 2.2, CanCollide = false, Color = Color3.new(1, 1, 1),
            Material = Enum.Material.Neon, Transparency = 0.35, CFrame = t.CFrame })
        f.CanQuery = false
        game:GetService("Debris"):AddItem(f, 0.1)
    end
    t:Destroy()
end

local function Spawn(s, root: BasePart)
    local look = (s.Face.LookVector * Vector3.new(1, 0, 1))
    local base = look.Magnitude > 0.1 and math.atan2(look.X, look.Z) or 0
    local a = base + math.rad(s.Rng:NextNumber(-55, 55))
    local dist = s.Rng:NextNumber(18, 40)
    local pos = root.Position + Vector3.new(math.sin(a) * dist, s.Rng:NextNumber(-1, 7), math.cos(a) * dist)
    pos = Vector3.new(math.clamp(pos.X, s.CX - s.Half, s.CX + s.Half), pos.Y, math.clamp(pos.Z, s.CZ - s.Half, s.CZ + s.Half))
    local t = P(Workspace, { Name = "TearTarget", Shape = Enum.PartType.Ball, Size = Vector3.one * s.Params.Size, CanCollide = false,
        Color = DEF.Color, Material = Enum.Material.Neon, CFrame = CFrame.new(pos) })
    t.CanQuery = true
    t:SetAttribute("KeepNeon", true)
    s.Target, s.Born = t, os.clock()
end

local function Finish(s, why: string?)
    if session ~= s then return end
    session = nil
    if s.Conn then s.Conn:Disconnect() end
    DropTarget(s, false)
    E.HudDone(s.Hud, (s.Kills > 0) and (s.Kills .. " KILLS") or (why or "COLLAPSED"), why)
    pcall(s.OnDone, { Ok = s.Kills > 0, Resets = s.Kills, Kills = s.Kills, Time = os.clock() - s.Start })
end

function M.Active(): boolean return session ~= nil end
function M.Cancel() if session then Finish(session, "CLOSED") end end

function M.OnShot(result: RaycastResult?, _consumesAmmo: boolean?): boolean
    local s = session
    if not s or not s.Target or not result or result.Instance ~= s.Target then return false end
    s.Kills += 1
    if s.SoundHelper then pcall(s.SoundHelper.Play, "HitCrit") end
    DropTarget(s, true)
    s.NextAt = os.clock() + s.Params.Gap
    return true
end

function M.DevAct(what: string)
    local s = session
    if s and what == "hit" and s.Target then M.OnShot({ Instance = s.Target } :: any, true) end
end

function M.Start(ctx: any)
    if session then return end
    local layout = ctx.Layout
    local s = {
        Params = ctx.Params, SoundHelper = ctx.SoundHelper, OnDone = ctx.OnDone, Kills = 0, Start = os.clock(), Rng = Random.new(),
        Hud = E.BuildHud(ctx.UIStyle, "THE BREACH", DEF.Color), Face = ctx.Anchor, NextAt = os.clock() + 0.6,
        CZ = layout.CombatZ, CX = layout.CombatX or 0, Half = layout.CombatSize / 2 - 4, -- (CX: LINKED ROOMS side room)
    }
    session = s
    if s.SoundHelper then pcall(s.SoundHelper.Play, "ShieldUp") end
    s.Conn = RunService.RenderStepped:Connect(function()
        if session ~= s then return end
        local now = os.clock()
        if now - s.Start >= s.Params.Window then Finish(s, "CLOSED"); return end
        local char = Players.LocalPlayer.Character
        local r = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not r or not hum or hum.Health <= 0 or (ctx.Model and ctx.Model.Parent == nil) then Finish(s, "CLOSED"); return end
        if s.Target and now - s.Born >= s.Params.Life then DropTarget(s, false); s.NextAt = now + s.Params.Gap end
        if not s.Target and now >= s.NextAt then Spawn(s, r) end
        if s.Target then -- (it shrinks as its life runs out)
            local k = 1 - (now - s.Born) / s.Params.Life
            s.Target.Size = Vector3.one * s.Params.Size * (0.6 + 0.4 * k)
        end
        local h = s.Hud
        if h then
            E.HudTick(h)
            h.Main.Text = s.Kills .. " kills"
            h.Info.Text = string.format("%d s left", math.ceil(s.Params.Window - (now - s.Start)))
        end
    end)
end

return M
