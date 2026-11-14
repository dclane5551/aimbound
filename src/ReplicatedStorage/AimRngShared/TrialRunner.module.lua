--!nocheck
-- ============================================================================================
-- AIM TRIAL RUNNER (client): builds a private target room far above the map, runs one AimTrials scenario
-- with the equipped gun (unlimited ammo, standing still) and reports the score to the server.
--   TrialRunner.Start(scenarioId, hooks) where hooks = {
--       Teleport = fn(CFrame),            -- move the character (also sets where the camera faces)
--       SetActive = fn(on),               -- client turns the trial shooting hook / infinite ammo on and off
--       Toast = fn(text), Sound = fn(name),
--       OnFinish = fn(result | nil, score, hits, shots),   -- result from the server (nil = rejected)
--   }
--   TrialRunner.OnShot(raycastResult) -> true   -- AimRngClient calls this for every shot while active
--   TrialRunner.IsRunning()
-- ============================================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = script.Parent
local Remotes = require(Shared:WaitForChild("Remotes"))
local AimTrials = require(Shared:WaitForChild("AimTrials"))
local UIStyle = require(Shared:WaitForChild("UIStyle"))

local LocalPlayer = Players.LocalPlayer
local TrialRunner = {}

local ORIGIN = Vector3.new(0, 600, -4000) -- room center (player stands here)
local WALL_Z = ORIGIN.Z - 32 -- target wall plane (in front: -Z)

local running = false
local abortReason: string? = nil -- "quit" (player left) / "dungeon" (a run started: don't teleport back)
local scenario: any = nil
local room: Folder? = nil
local hud: ScreenGui? = nil
local hudText: TextLabel? = nil
local hudScore: TextLabel? = nil
local hits, shots, score = 0, 0, 0
local onTargetHit: ((Part) -> ())? = nil
local diff: any = nil -- AimTrials.Difficulties entry for this run (size / speed / lifetime)
local hitHook: ((boolean) -> ())? = nil -- hooks.Hit(head): hit sound + hitmarker

function TrialRunner.IsRunning(): boolean return running end
-- the running scenario (AimTrials entry: FireRate etc.) -- AimRngClient fires the universal trial weapon from it
function TrialRunner.Scenario(): any return running and scenario or nil end

local function Spark(pos: Vector3, color: Color3)
    local p = Instance.new("Part")
    p.Shape = Enum.PartType.Ball
    p.Size = Vector3.one * 0.8
    p.Position = pos
    p.Material = Enum.Material.Neon
    p.Color = color
    p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
    p.Parent = Workspace
    TweenService:Create(p, TweenInfo.new(0.15), { Size = Vector3.one * 2.2, Transparency = 1 }):Play()
    Debris:AddItem(p, 0.2)
end

local function BuildRoom(): Folder
    local f = Instance.new("Folder")
    f.Name = "AimTrialRoom"
    local function Block(size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?)
        local p = Instance.new("Part")
        p.Size = size
        p.Position = pos
        p.Color = color
        p.Material = material or Enum.Material.SmoothPlastic
        p.Anchored = true
        p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
        p.Parent = f
        return p
    end
    local dark = Color3.fromRGB(28, 30, 38)
    Block(Vector3.new(90, 2, 90), ORIGIN + Vector3.new(0, -4, -10), Color3.fromRGB(40, 42, 52))           -- floor
    Block(Vector3.new(90, 50, 2), Vector3.new(ORIGIN.X, ORIGIN.Y + 18, WALL_Z - 4), dark)             -- back wall
    Block(Vector3.new(2, 50, 90), ORIGIN + Vector3.new(-45, 18, -10), dark)                           -- sides
    Block(Vector3.new(2, 50, 90), ORIGIN + Vector3.new(45, 18, -10), dark)
    Block(Vector3.new(90, 50, 2), ORIGIN + Vector3.new(0, 18, 35), dark)                              -- behind
    Block(Vector3.new(90, 2, 90), ORIGIN + Vector3.new(0, 43, -10), dark)                             -- ceiling
    -- grid lines on the target wall
    for i = -4, 4 do
        Block(Vector3.new(0.15, 40, 0.2), Vector3.new(ORIGIN.X + i * 8, ORIGIN.Y + 14, WALL_Z - 2.9), Color3.fromRGB(55, 60, 75))
    end
    local lamp = Block(Vector3.new(30, 0.5, 30), ORIGIN + Vector3.new(0, 42, -15), Color3.fromRGB(240, 240, 255), Enum.Material.Neon)
    local light = Instance.new("SurfaceLight")
    light.Face = Enum.NormalId.Bottom
    light.Range = 60
    light.Brightness = 2
    light.Parent = lamp
    f.Parent = Workspace
    return f
end

local function MakeTarget(pos: Vector3, size: number, color: Color3): Part
    local t = Instance.new("Part")
    t.Name = "TrialTarget"
    t.Shape = Enum.PartType.Ball
    t.Size = Vector3.one * size * (diff and diff.Size or 1)
    t.Position = pos
    -- (owner 2026-10-05: "hitreg is still slightly off, especially in aim trials"): a Neon ball blooms well past its edge,
    -- so shots on the visible glow missed the real sphere -- solid bright plastic is exactly as big as its hitbox
    t.Material = Enum.Material.SmoothPlastic
    t.Color = color
    t.Anchored, t.CanCollide, t.CanTouch = true, false, false
    t:SetAttribute("TrialTarget", true)
    t.Parent = room
    return t
end

-- TRIAL BOTS (0.93, owner: "Aim trials are still really bad, bots dont even make sense"): the targets are small hovering
-- bots like the dungeon's -- a body and a head (the head is the weak spot: hitmarker + a score bonus) -- that stand off the
-- floor and move like the game's bots (smooth strafes with eased turns), instead of balls sliding along a wall.
local FLOOR_Y = ORIGIN.Y - 3 -- top of the room floor
local BOTS: { [Model]: any } = {}
local function MakeBot(pos: Vector3, size: number, color: Color3): any
    size *= (diff and diff.Size or 1)
    local m = Instance.new("Model")
    m.Name = "TrialBot"
    m:SetAttribute("TrialBot", true)
    local function Ball(name: string, d: number, col: Color3, head: boolean): Part
        local p = Instance.new("Part")
        p.Name = name
        p.Shape = Enum.PartType.Ball
        p.Size = Vector3.one * d
        p.Material = Enum.Material.SmoothPlastic
        p.Color = col
        p.Anchored, p.CanCollide, p.CanTouch = true, false, false
        p:SetAttribute("TrialTarget", true)
        if head then p:SetAttribute("Head", true) end
        p.Parent = m
        return p
    end
    local body = Ball("Body", size, color, false)
    local head = Ball("Head", size * 0.6, color:Lerp(Color3.new(1, 1, 1), 0.45), true)
    local core = Instance.new("Part") -- a dark visor band so it reads as a bot, not a ball (not hittable)
    core.Name = "Visor"
    core.Size = Vector3.new(size * 0.62, size * 0.16, size * 0.2)
    core.Color = Color3.fromRGB(20, 22, 28)
    core.Material = Enum.Material.SmoothPlastic
    core.Anchored, core.CanCollide, core.CanTouch, core.CanQuery = true, false, false, false
    core.Parent = m
    m.PrimaryPart = body
    m.Parent = room
    local bot = { Model = m, Body = body, Head = head, Size = size, Pos = pos }
    function bot.Move(p: Vector3)
        bot.Pos = p
        body.Position = p
        local hp = p + Vector3.new(0, size * 0.5 + size * 0.3 - 0.05, 0)
        head.Position = hp
        core.CFrame = CFrame.lookAt(hp, ORIGIN) * CFrame.new(0, 0, -size * 0.24)
    end
    function bot.Destroy() BOTS[m] = nil; m:Destroy() end
    bot.Move(pos)
    BOTS[m] = bot
    return bot
end
-- a spot standing off the floor, at a bearing (degrees from straight ahead) and distance from you
local function BotSpot(yawDeg: number, dist: number, hover: number): Vector3
    local d = CFrame.Angles(0, math.rad(yawDeg), 0).LookVector * Vector3.new(1, 0, 1)
    local p = Vector3.new(ORIGIN.X, FLOOR_Y + hover, ORIGIN.Z) - d.Unit * -dist
    return Vector3.new(p.X, FLOOR_Y + hover, p.Z)
end
-- one smooth strafe (the dungeon bots' brain in small): pick a lateral speed for a while, ease into it, turn at the lane end
local function Strafer(r: Random, lane: number, speed: number): any
    local s = { X = r:NextNumber(-lane, lane), V = 0, Want = speed * ((r:NextNumber() < 0.5) and -1 or 1), Next = os.clock() + r:NextNumber(0.5, 1.2) }
    function s.Step(dt: number)
        local now = os.clock()
        if now >= s.Next then
            local dir = (r:NextNumber() < 0.7) and -math.sign(s.Want) or math.sign(s.Want)
            if dir == 0 then dir = 1 end
            s.Want = dir * speed * r:NextNumber(0.7, 1.15)
            if r:NextNumber() < 0.1 then s.Want = 0 end -- a short stop
            s.Next = now + r:NextNumber(0.45, 1.2)
        end
        if math.abs(s.X) > lane and math.sign(s.X) == math.sign(s.Want) then s.Want = -s.Want end
        local acc = speed * 4.5
        s.V += math.clamp(s.Want - s.V, -acc * dt, acc * dt)
        s.X += s.V * dt
        return s.X
    end
    return s
end

local function SetHud(text: string)
    if hudText then hudText.Text = text end
    if hudScore then hudScore.Text = tostring(math.floor(score)) end
end

-- Every shot while a trial runs (AimRngClient routes them here instead of the server).
function TrialRunner.OnShot(result: RaycastResult?): boolean
    if not running then return false end
    shots += 1
    local inst = result and result.Instance
    if inst and inst:GetAttribute("TrialTarget") and onTargetHit then
        hits += 1
        local head = inst:GetAttribute("Head") == true
        Spark(result.Position, inst.Color)
        if hitHook then hitHook(head) end -- (0.93: the game's own hit sound + hitmarker)
        local bot = inst.Parent and inst.Parent:GetAttribute("TrialBot") and inst.Parent or nil
        onTargetHit(bot or inst, head)
    elseif scenario and scenario.Id == "GRIDSHOT" then
        score = math.max(0, score - 40) -- gridshot punishes misses
    end
    return true
end

-- ===================== scenarios =====================
local function RandWallPos(r: Random, spreadX: number, yLo: number, yHi: number): Vector3
    return Vector3.new(ORIGIN.X + r:NextNumber(-spreadX, spreadX), ORIGIN.Y + r:NextNumber(yLo, yHi), WALL_Z)
end

local Scenarios = {}

Scenarios.GRIDSHOT = function(r: Random, isOver: () -> boolean)
    local slots = {}
    for gx = -2, 2 do for gy = 0, 2 do table.insert(slots, Vector3.new(ORIGIN.X + gx * 5, ORIGIN.Y - 1 + gy * 4, WALL_Z)) end end
    local used: { [number]: Part } = {}
    local function Spawn()
        local free = {}
        for i = 1, #slots do if not used[i] then table.insert(free, i) end end
        local i = free[r:NextInteger(1, #free)]
        local t = MakeTarget(slots[i], 2.6, Color3.fromRGB(255, 120, 60))
        t:SetAttribute("Slot", i)
        used[i] = t
    end
    for _ = 1, 3 do Spawn() end
    onTargetHit = function(t)
        used[t:GetAttribute("Slot")] = nil
        t:Destroy()
        score += 120
        Spawn()
    end
    while not isOver() do task.wait(0.1) end
end

Scenarios.FLICK = function(r: Random, isOver: () -> boolean)
    -- one bot at a time, standing somewhere in front of you (left to right, near to far); kill it fast, a headshot pays more
    local current: any = nil
    local spawnedAt = 0
    local LIFE = 1.8 * (diff and diff.Life or 1)
    onTargetHit = function(t, head)
        if not current or t ~= current.Model then return end
        local dt = os.clock() - spawnedAt
        score += math.round((50 + 250 * math.clamp(1 - dt / LIFE, 0, 1)) * (head and 1.25 or 1))
        current.Destroy()
        current = nil
    end
    while not isOver() do
        if not current then
            task.wait(0.3)
            if isOver() then break end
            current = MakeBot(BotSpot(r:NextNumber(-55, 55), r:NextNumber(16, 30), r:NextNumber(1.5, 6)), 1.9, Color3.fromRGB(90, 200, 255))
            spawnedAt = os.clock()
        elseif os.clock() - spawnedAt > LIFE then
            current.Destroy() -- too slow: no points
            current = nil
        end
        task.wait()
    end
    if current then current.Destroy() end
end

Scenarios.TRACKING = function(r: Random, isOver: () -> boolean)
    -- AIR (0.97, owner: "The tracking trial feels terrible, the bot is too repetitive. Make it more like the kovaaks scenario
    -- 'air'"): one ball floating in a 3D box in front of you at a steady speed. Every 0.35-0.9 s it picks a new heading
    -- (mostly sideways, some up / down, a little toward / away) and TURNS into it smoothly (a capped turn rate, no snaps),
    -- bouncing off the box walls. Keep the crosshair on it: every hit scores.
    local sp = diff and diff.Speed or 1
    local ball = MakeTarget(Vector3.new(ORIGIN.X, FLOOR_Y + 7, ORIGIN.Z - 24), 2.6, Color3.fromRGB(120, 255, 140))
    onTargetHit = function() score += 12 end
    local BOX_MIN = Vector3.new(ORIGIN.X - 14, FLOOR_Y + 2.5, ORIGIN.Z - 30)
    local BOX_MAX = Vector3.new(ORIGIN.X + 14, FLOOR_Y + 15, ORIGIN.Z - 18)
    local speed = 13 * sp
    local function Heading(): Vector3
        local v = Vector3.new(r:NextNumber(-1, 1), r:NextNumber(-0.65, 0.65), r:NextNumber(-0.3, 0.3))
        return v.Magnitude > 0.05 and v.Unit or Vector3.xAxis
    end
    local pos = ball.Position
    local dir = Heading()
    local want = Heading()
    local nextTurn = os.clock() + r:NextNumber(0.35, 0.9)
    local TURN = math.rad(260) * math.sqrt(sp) -- max turn per second (smooth arcs, never a snap)
    local last = os.clock()
    while not isOver() do
        local now = os.clock()
        local dt = math.min(0.05, now - last)
        last = now
        if now >= nextTurn then
            want = Heading()
            if r:NextNumber() < 0.35 then want = Vector3.new(-dir.X, want.Y, want.Z).Unit end -- a reversal now and then
            nextTurn = now + r:NextNumber(0.35, 0.9)
        end
        -- bounce: a heading that leaves the box flips on that axis
        for _, ax in ipairs({ "X", "Y", "Z" }) do
            local lo, hi = BOX_MIN[ax], BOX_MAX[ax]
            local function flip(v: Vector3): Vector3
                return Vector3.new(ax == "X" and -v.X or v.X, ax == "Y" and -v.Y or v.Y, ax == "Z" and -v.Z or v.Z)
            end
            if (pos[ax] <= lo and dir[ax] < 0) or (pos[ax] >= hi and dir[ax] > 0) then
                dir = flip(dir)
                if (pos[ax] <= lo and want[ax] < 0) or (pos[ax] >= hi and want[ax] > 0) then want = flip(want) end
            end
        end
        -- turn toward the wanted heading at a capped rate
        local ang = math.acos(math.clamp(dir:Dot(want), -1, 1))
        if ang > 1e-3 then
            local t = math.min(1, TURN * dt / ang)
            dir = (dir:Lerp(want, t)).Unit
        end
        pos += dir * speed * dt
        pos = Vector3.new(math.clamp(pos.X, BOX_MIN.X, BOX_MAX.X), math.clamp(pos.Y, BOX_MIN.Y, BOX_MAX.Y), math.clamp(pos.Z, BOX_MIN.Z, BOX_MAX.Z))
        ball.Position = pos
        RunService.RenderStepped:Wait() -- (moved where the frame is drawn, before your shot's ray -- what you see is what you hit)
    end
    ball:Destroy()
end

Scenarios.SWITCH = function(r: Random, isOver: () -> boolean)
    -- three bots strafing in their own lanes (near, middle, far); 3 hits each (a headshot counts double). Kill one and the
    -- next takes its lane -- the score is kills, plus a bonus for fast ones
    local sp = diff and diff.Speed or 1
    local LANES = { { Dist = 15, Lane = 9 }, { Dist = 23, Lane = 13 }, { Dist = 31, Lane = 17 } }
    local alive = {}
    local function Spawn(i: number)
        local L = LANES[i]
        local bot = MakeBot(BotSpot(0, L.Dist, r:NextNumber(2, 5)), 2.1, Color3.fromRGB(255, 200, 70))
        bot.HP, bot.Lane, bot.Born, bot.Y = 3, i, os.clock(), bot.Pos.Y - FLOOR_Y
        bot.Strafe = Strafer(r, L.Lane, 7 * sp)
        alive[i] = bot
    end
    for i = 1, #LANES do Spawn(i) end
    onTargetHit = function(t, head)
        for i, bot in pairs(alive) do
            if bot.Model == t then
                bot.HP -= head and 2 or 1
                local k = math.clamp(bot.HP / 3, 0, 1)
                bot.Body.Color = Color3.fromRGB(255, 200, 70):Lerp(Color3.fromRGB(255, 60, 60), 1 - k)
                if bot.HP <= 0 then
                    score += 100 + math.round(math.max(0, 100 - (os.clock() - bot.Born) * 40)) -- fast kills pay a bonus
                    bot.Destroy()
                    alive[i] = nil
                    task.delay(0.25, function() if not isOver() and not alive[i] then Spawn(i) end end)
                end
                return
            end
        end
    end
    local last = os.clock()
    while not isOver() do
        local now = os.clock()
        local dt = math.min(0.05, now - last)
        last = now
        for _, bot in pairs(alive) do
            local x = bot.Strafe.Step(dt)
            bot.Move(BotSpot(0, LANES[bot.Lane].Dist, bot.Y) + Vector3.new(x, 0, 0))
        end
        RunService.RenderStepped:Wait()
    end
    for _, bot in pairs(alive) do bot.Destroy() end
end

-- ===================== run one =====================
function TrialRunner.Start(id: string, hooks: any, difficultyId: string?)
    if running then return end
    local def = AimTrials.ById[id]
    local run = Scenarios[id]
    if not def or not run then return end
    diff = AimTrials.DifficultyById[difficultyId or "Standard"] or AimTrials.DifficultyById.Standard
    if not Remotes.GetFunction("BeginTrial"):InvokeServer(id, diff.Id) then
        if hooks.Toast then hooks.Toast("Aim Trials can only be started from the hub.") end
        return
    end
    running, scenario = true, def
    abortReason = nil
    hits, shots, score = 0, 0, 0
    onTargetHit = nil
    hitHook = hooks.Hit
    room = BuildRoom()

    -- HUD
    hud = Instance.new("ScreenGui")
    hud.Name = "AimTrialHUD"
    hud.ResetOnSpawn = false
    hud.IgnoreGuiInset = true
    hud.Parent = LocalPlayer:WaitForChild("PlayerGui")
    UIStyle.ScaleGui(hud) -- (Update 5: Interface Scale)
    -- (UI CLEAN R-C: ONE run HUD plate at the top centre (AimRngShared/RunHud) holding the trial line (display caps Text), the
    -- score (a big display number), the weapon rule (Sub) and the leave hint (Muted) -- no coloured stroked text over the room)
    do
        local RunHud = require(script.Parent:WaitForChild("RunHud"))
        local plate = Instance.new("Frame")
        plate.Name = "Plate"; plate.AnchorPoint = Vector2.new(0.5, 0); plate.Position = UDim2.new(0.5, 0, 0, 64)
        plate.Size = UDim2.fromOffset(600, 0); plate.AutomaticSize = Enum.AutomaticSize.Y; plate.Parent = hud
        RunHud.Plate(plate)
        RunHud.Pad(plate, 16, 16, 10, 10)
        local lay = Instance.new("UIListLayout"); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
        lay.Padding = UDim.new(0, 2); lay.Parent = plate
        local function Line(text, h, order)
            local t = UIStyle.Text({ Size = UDim2.new(1, 0, 0, h), Text = text, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = order, Parent = plate })
            return t
        end
        hudText = Line("", 24, 1); RunHud.Role(hudText, "SectionHead"); hudText.TextSize = 18
        hudScore = Line("0", 40, 2); RunHud.Num(hudScore, 36, UIStyle.Colors.Text)
        local rule = Line(string.format("Trial weapon: %s shots/s, no recoil. The same for everyone", tostring(def.FireRate or 5)), 18, 3)
        RunHud.Role(rule, "Label"); rule.TextSize = 13
        local leave = Line("Double tap " .. (hooks.LeaveKey or "J") .. " to leave the trial", 18, 4)
        RunHud.Role(leave, "Meta")
    end

    local backCF = (LocalPlayer.Character and LocalPlayer.Character:GetPivot()) or CFrame.new(0, 6, 0)
    hooks.Teleport(CFrame.lookAt(ORIGIN, ORIGIN + Vector3.new(0, 0, -1)))
    hooks.SetActive(true)
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    local oldJump = hum and hum.JumpPower
    -- standing still: the trial is pure aim (re-applied every frame, other code may set WalkSpeed)
    -- (0.97, owner: "Aim trials should lock you in place, right now you can move to the sides of the bots"): WalkSpeed 0
    -- never stopped the movement controller's dashes / slides / bhops (it drives velocity itself) -> the root is ANCHORED
    -- at the trial spot for the whole trial; the camera still turns freely
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local lockCF = root and root.CFrame
    if root then root.AssemblyLinearVelocity = Vector3.zero; root.Anchored = true end
    local freeze = RunService.Heartbeat:Connect(function()
        if hum then hum.WalkSpeed = 0; hum.JumpPower = 0 end
        if root and root.Parent then
            root.Anchored = true
            if lockCF and (root.Position - lockCF.Position).Magnitude > 0.2 then root.CFrame = CFrame.new(lockCF.Position) * (root.CFrame - root.CFrame.Position) end
        end
    end)

    for i = 3, 1, -1 do
        if not running then break end
        SetHud(string.upper(def.Name) .. " (" .. string.upper(diff.Id) .. ")  starts in " .. i)
        if hooks.Sound then hooks.Sound("Click") end
        task.wait(1)
    end
    local endAt = os.clock() + def.Duration
    local function IsOver() return os.clock() >= endAt or not running end
    task.spawn(function()
        while not IsOver() do
            SetHud(string.format("%s   %.1fs   •   %d / %d hits", string.upper(def.Name), math.max(0, endAt - os.clock()), hits, shots))
            task.wait(0.05)
        end
    end)
    if running then run(Random.new(), IsOver) end

    -- finish
    local acc = shots > 0 and hits / shots or 0
    if id == "TRACKING" then score = math.round(score * (0.6 + 0.4 * acc)) end
    score = math.round(score * diff.Mult) -- difficulty multiplier
    running = false
    onTargetHit = nil
    hitHook = nil
    hooks.SetActive(false)
    freeze:Disconnect()
    if root and root.Parent then root.Anchored = false end
    if hum then
        hum.JumpPower = oldJump or 50
        hum.WalkSpeed = 16
    end
    if room then room:Destroy(); room = nil end
    if hud then hud:Destroy(); hud = nil end
    local reason = abortReason
    abortReason = nil
    if reason ~= "dungeon" then hooks.Teleport(backCF) end -- a dungeon that started mid-trial already moved you
    if reason then
        if hooks.OnAborted then hooks.OnAborted(reason) end
        return -- left early: nothing is recorded
    end
    local result = Remotes.GetFunction("SubmitTrial"):InvokeServer(id, score, hits, shots)
    if hooks.OnFinish then hooks.OnFinish(result, score, hits, shots) end
end

-- Leave early: "quit" (the player pressed leave) or "dungeon" (a run started -- stay where it put you).
function TrialRunner.Abort(reason: string?)
    if not running then return end
    abortReason = reason or "quit"
    running = false
end

return TrialRunner
