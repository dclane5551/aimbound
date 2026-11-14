--!nocheck
-- ENEMY MIND (shared: solo floors run it on the client, party floors on the server). Owner (2026-10-02): "Improve the
-- enemy AI, make them learn any patterns you might start to do to avoid feeling stupid when fighting them."
-- Every enemy on a floor shares one profile per player (a hive mind), built while you fight:
--   RHYTHM  -- your strafe reversals (A-D-A-D): once it has the beat, attacks land where you'll be AFTER the next
--              reversal instead of where you were heading (plain lead = easy to juke by turning around).
--   DODGE   -- which way you leave red areas (relative to the attacker): a habit (always left / always back) gets
--              some attacks placed where you're about to run.
--   PEEKS   -- where you step out of cover: a corner you keep using gets pre-fired while you're hidden.
-- It forgets: habits fade as you change them, and a profile is dropped after ~20 s out of combat (back in the hub).
-- A purple eye flashes over an enemy when it uses a read (EnemyMind.Cue), so players learn to mix it up.
--   EnemyMind.Aim(root, from, strikeIn, learn) -> aimPoint, tag ("Rhythm" | "Dodge" | nil)
--   EnemyMind.Predict(root, t)                  -> where the rhythm says you'll be in t s (bosses' Lead)
--   EnemyMind.RecordDodge(root, from, center, strikeIn)
--   EnemyMind.Peek(root)  /  EnemyMind.PeekSpot(root) -> Vector3?
--   EnemyMind.Cue(model)
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local EnemyMind = {}

-- how strongly each difficulty uses what it learned (0 = never, 1 = every read it trusts)
EnemyMind.LearnByDifficulty = setmetatable({ Easy = 0.4, Normal = 0.65, Hard = 0.85, Brutal = 1, Nightmare = 1, Torment = 1, Cataclysm = 1, Oblivion = 1, Endless = 1 }, { __index = function() return 1 end })

local SAMPLE = 0.1      -- s between movement samples
local FORGET = 20       -- s without being targeted -> profile dropped
local MIN_SPEED = 6     -- studs/s: slower than this isn't a strafe

local profiles = {} -- [BasePart] -> profile (strong keys + pruning; weak Instance keys lose entries)
local sampler = nil

local function Flat(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end

local function Profile(root: BasePart)
    local p = profiles[root]
    if not p then
        p = {
            Used = os.clock(),
            Dir = nil, SegStart = os.clock(), SegLen = 0.6, Revs = {}, -- rhythm
            DodgeR = 0, DodgeF = 0, DodgeDist = 8, DodgeN = 0,         -- dodge habit
            Peeks = {}, LosWas = true,                                  -- peek spots
        }
        profiles[root] = p
    end
    p.Used = os.clock()
    return p
end

local function Sample()
    local now = os.clock()
    for root, p in pairs(profiles) do
        if not root.Parent or now - p.Used > FORGET then
            profiles[root] = nil
        else
            local v = Flat(root.AssemblyLinearVelocity)
            if v.Magnitude >= MIN_SPEED then
                local dir = v.Unit
                if not p.Dir then
                    p.Dir, p.SegStart = dir, now
                elseif dir:Dot(p.Dir) < -0.3 then
                    -- a reversal: one beat of the strafe
                    local seg = now - p.SegStart
                    if seg > 0.12 and seg < 2 then p.SegLen = p.SegLen * 0.6 + seg * 0.4 end
                    table.insert(p.Revs, now)
                    if #p.Revs > 8 then table.remove(p.Revs, 1) end
                    p.Dir, p.SegStart = dir, now
                elseif dir:Dot(p.Dir) > 0.5 then
                    p.Dir = (p.Dir * 0.7 + dir * 0.3).Unit -- (follows a curving run)
                end
            end
        end
    end
end

local function Ensure()
    if sampler then return end
    local acc = 0
    sampler = RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < SAMPLE then return end
        acc = 0
        Sample()
    end)
end

-- has it got your strafe beat? (3+ reversals in the last 4 s at a steady-ish tempo)
local function HasRhythm(p): boolean
    local now, n = os.clock(), 0
    for _, t in ipairs(p.Revs) do if now - t < 4 then n += 1 end end
    return n >= 3 and p.SegLen > 0.15 and p.SegLen < 1.4
end

-- where the rhythm says you'll be in t seconds (falls back to a straight lead)
function EnemyMind.Predict(root: BasePart, t: number): Vector3
    Ensure()
    local p = Profile(root)
    local pos, v = root.Position, Flat(root.AssemblyLinearVelocity)
    if not HasRhythm(p) or v.Magnitude < MIN_SPEED then return pos + v * t end
    local left = math.max(0, p.SegLen - (os.clock() - p.SegStart))
    if t <= left then return pos + v * t end
    local back = math.min(t - left, p.SegLen)
    return pos + v * left - v * back -- you'll have turned around by then
end

-- the aim point for an attack that goes off in strikeIn seconds; learn = 0..1 (difficulty)
function EnemyMind.Aim(root: BasePart, from: Vector3, strikeIn: number, learn: number?): (Vector3, string?)
    Ensure()
    learn = learn or 1
    local p = Profile(root)
    local pos, v = root.Position, Flat(root.AssemblyLinearVelocity)
    local base = pos + v * 0.3 -- (the old aim: where you are + a little lead)
    if learn <= 0 then return base, nil end
    if HasRhythm(p) and v.Magnitude >= MIN_SPEED and math.random() < learn then
        return EnemyMind.Predict(root, strikeIn), "Rhythm"
    end
    local bias = math.max(math.abs(p.DodgeR), math.abs(p.DodgeF))
    if p.DodgeN >= 4 and bias > 0.35 and math.random() < 0.45 * learn then
        local fwd = Flat(pos - from)
        fwd = fwd.Magnitude > 0.1 and fwd.Unit or Vector3.new(0, 0, 1)
        local right = Vector3.new(-fwd.Z, 0, fwd.X)
        local off = (right * p.DodgeR + fwd * p.DodgeF) * math.clamp(p.DodgeDist, 4, 14)
        return pos + off, "Dodge"
    end
    return base, nil
end

-- after an attack goes off, note which way you got out of it (relative to the attacker)
function EnemyMind.RecordDodge(root: BasePart, from: Vector3, center: Vector3, strikeIn: number)
    task.delay(strikeIn, function()
        if not root.Parent then return end
        local p = profiles[root]
        if not p then return end
        local disp = Flat(root.Position - center)
        local d = disp.Magnitude
        if d < 3 then return end -- stood in it / barely moved: no habit to learn
        local fwd = Flat(center - from)
        fwd = fwd.Magnitude > 0.1 and fwd.Unit or Vector3.new(0, 0, 1)
        local right = Vector3.new(-fwd.Z, 0, fwd.X)
        local u = disp / d
        p.DodgeR = p.DodgeR * 0.75 + u:Dot(right) * 0.25
        p.DodgeF = p.DodgeF * 0.75 + u:Dot(fwd) * 0.25
        p.DodgeDist = p.DodgeDist * 0.7 + math.min(d, 16) * 0.3
        p.DodgeN = math.min(p.DodgeN + 1, 12)
    end)
end

-- line of sight came back: you stepped out here
function EnemyMind.Peek(root: BasePart)
    local p = Profile(root)
    table.insert(p.Peeks, { Pos = root.Position, T = os.clock() })
    if #p.Peeks > 6 then table.remove(p.Peeks, 1) end
end

-- a corner you've stepped out of twice in the last 25 s (the most recent such spot), or nil
function EnemyMind.PeekSpot(root: BasePart): Vector3?
    local p = profiles[root]
    if not p then return nil end
    local now = os.clock()
    for i = #p.Peeks, 1, -1 do
        local a = p.Peeks[i]
        if now - a.T < 25 then
            for j = i - 1, 1, -1 do
                local b = p.Peeks[j]
                if now - b.T < 25 and (a.Pos - b.Pos).Magnitude < 7 then return (a.Pos + b.Pos) / 2 end
            end
        end
    end
    return nil
end

-- the "I've read you" tell: a purple eye over the enemy for a moment
function EnemyMind.Cue(model: Instance)
    local head = model:FindFirstChild("Head") or (model:IsA("Model") and model.PrimaryPart)
    if not head or not head:IsA("BasePart") then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "MindCue"
    bb.Size = UDim2.fromOffset(34, 34)
    bb.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y * 0.5 + 2.2, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = 140
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Size = UDim2.fromScale(1, 1)
    t.Font = Enum.Font.GothamBlack
    t.Text = "◉"
    t.TextScaled = true
    t.TextColor3 = Color3.fromRGB(200, 120, 255)
    t.TextStrokeTransparency = 0.2
    t.TextStrokeColor3 = Color3.fromRGB(40, 0, 70)
    t.Parent = bb
    bb.Adornee = head
    bb.Parent = head
    Debris:AddItem(bb, 0.7)
end

return EnemyMind
