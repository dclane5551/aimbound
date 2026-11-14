--!nocheck
-- ENEMY ANIMATION (0.53, owner: "Enemy animations need a ton of improvement" -> "add animations to all enemies (MOBS AND
-- BOSSES)"). One client loop poses every enemy on top of its AI each frame (the AI only moves the model rigidly):
--   BODY   flyers hover-bob and bank into their movement; walkers bob with their stride and lean into it; bosses breathe
--   ATTACK a wind-up pose while a telegraph fills (EnemyAttacks stamps the model's AtkEnd), then a lunge / recoil
--   HIT    a flinch away from the shot when its Health drops
--   PARTS  decorations move by role, from their names (EnemyModels): wings / fins / feathers FLAP, kernels / shards /
--          nodes / clouds ORBIT, armour rings GYRATE, tails / tendrils / chains SWAY, jaws / lids OPEN on a wind-up,
--          eyes flare and glows pulse while it winds up
--   DEATH  EnemyAnim.Death(model): the model breaks apart (pieces tumble out and fade) instead of a plain flash
-- Solo enemies (their AI runs on this client, attribute NoSmooth) get the full treatment. Party enemies are interpolated
-- by AimRngClient's smoothing, which watches the body's CFrame for new server data, so only their client-side
-- decorations (LocalDeco) are posed. Server-run bosses are left to their kits. Kit-posed boss parts (Deco_*) are never
-- touched here. Budget: nothing beyond 260 studs, half rate beyond 110, at most MAX_DEBRIS death pieces alive.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local EnemyAnim = {}
local tracked: { [Model]: any } = {}
local MAX_DEBRIS = 260
local debris: { any } = {}

-- part name -> role (decorations from EnemyModels.Decorate)
local ROLE = {
    Wing = "Flap", WingTip = "Flap", WingEdge = "Flap", WingGrid = "Flap", Feather = "Flap", MothWing = "Flap", SolarWing = "Flap",
    Fin = "Fin", ShoulderFin = "Fin", TailFin = "Fin", Frill = "Fin", Ear = "Fin", Streamer = "Fin",
    Kernel = "Orbit", Node = "Orbit", Shard = "Orbit", Cloud = "Orbit", PixelShard = "Orbit", Pixel = "Orbit", StarMote = "Orbit",
    Moon = "Orbit", CrownOrb = "Orbit", FlakeArm = "Spin", FlakeBranch = "Spin", Crystal = "Spin", StarPoint = "Spin",
    ArmorRing = "Gyro", Rim = "Gyro",
    TailSegment = "Sway", Tendril = "Sway", Chain = "Sway", Plume = "Sway",
    Jaw = "Jaw", Lid = "Jaw", Lip = "Jaw",
    Iris = "Eye", BigIris = "Eye", Pupil = "Eye", EyeSpot = "Eye", FrostEye = "Eye", Lens = "Eye",
    Coil = "Glow", Vein = "Glow", Crack = "Glow", LightStrip = "Glow", PodGlow = "Glow", ChestCore = "Glow", Belly = "Glow", Maw = "Glow",
    RodTip = "Glow", ArcOrb = "Glow", GlitchCore = "Glow", FrostHeart = "Glow", ProjectorTip = "Glow", Tip = "Glow",
    Spring = "Spring", Pad = "Spring", SpringBoot = "Spring", Glow = "Glow",
}
-- parts the AI already drives (never posed here)
local SKIP = { ArmL = true, ArmR = true, LegL = true, LegR = true, Fist = true, ArmGun = true, Muzzle = true, DataTether = true,
    EliteShield = true, HealthHUD = true, DroneRoot = true }

local function Now() return Workspace:GetServerTimeNow() end

local function Collect(rec)
    local model = rec.Model
    local pv = model:GetPivot()
    rec.Base = pv
    rec.Parts, rec.Body = {}, {}
    local center = pv.Position
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and not SKIP[d.Name] and not string.find(d.Name, "^Deco_") then
            local role = ROLE[d.Name]
            local deco = d:GetAttribute("LocalDeco") == true
            if role or (rec.DecoOnly and deco) then
                local off = pv:ToObjectSpace(d.CFrame)
                local e = { Part = d, Off = off, Role = role }
                if role == "Flap" or role == "Fin" then
                    -- hinge on the body surface on the part's side, axis along the tangent there (parts of one wing share it)
                    local p = off.Position
                    local flat = Vector3.new(p.X, 0, p.Z)
                    local dir = (flat.Magnitude > 0.05) and flat.Unit or Vector3.new(0, 0, 1)
                    e.Hinge = CFrame.new(dir * rec.R * 0.8 + Vector3.new(0, p.Y, 0))
                    e.Axis = Vector3.new(-dir.Z, 0, dir.X)
                    e.Sign = (dir.X >= 0) and 1 or -1
                elseif role == "Jaw" then
                    e.Hinge = CFrame.new(off.Position + Vector3.new(0, 0, d.Size.Z * 0.45))
                elseif role == "Sway" then
                    e.Dist = off.Position.Magnitude
                elseif role == "Eye" or role == "Glow" then
                    e.Color, e.T = d.Color, d.Transparency
                end
                table.insert(rec.Parts, e)
            end
        end
    end
    rec.Ready = true
end

function EnemyAnim.Track(model: Model)
    if tracked[model] or not RunService:IsClient() then return end
    local smooth = model:GetAttribute("NoSmooth") ~= true and model:GetAttribute("LocalSim") ~= true -- (party: AimRngClient interpolates it)
    local boss = model:GetAttribute("IsBoss") == true or model:GetAttribute("IsMiniBoss") == true
    if boss and smooth then return end -- (server-run bosses: their kits pose them)
    local ext = model:GetExtentsSize()
    local rec = {
        Model = model, Boss = boss, DecoOnly = smooth, Ground = model:GetAttribute("AnimGround") == true,
        Style = model:GetAttribute("AnimStyle") or (boss and "Boss" or "Orb"),
        R = math.max(1, math.min(ext.X, ext.Z) * 0.35), Phase = math.random() * 6, Vel = Vector3.zero,
        LastPos = model:GetPivot().Position, Flinch = -9, FlinchDir = Vector3.zero, Hp = model:GetAttribute("Health"),
        Ready = false, Born = os.clock(),
    }
    tracked[model] = rec
    rec.Conn = model:GetAttributeChangedSignal("Health"):Connect(function()
        local h = model:GetAttribute("Health")
        if type(h) == "number" and type(rec.Hp) == "number" and h < rec.Hp then
            rec.Flinch = os.clock()
            local cam = Workspace.CurrentCamera
            if cam then rec.FlinchDir = (model:GetPivot().Position - cam.CFrame.Position) * Vector3.new(1, 0, 1) end
        end
        rec.Hp = h
    end)
end

local function Untrack(model)
    local rec = tracked[model]
    if rec and rec.Conn then rec.Conn:Disconnect() end
    tracked[model] = nil
end

-- ===== DEATH: the model breaks apart =====
function EnemyAnim.Death(model: Model)
    if not model or model:GetAttribute("AnimDied") then return end
    model:SetAttribute("AnimDied", true)
    local pv = model:GetPivot()
    local center = pv.Position
    local rec = tracked[model]
    local ground = rec and rec.Ground
    local list = {}
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "DroneRoot" and d.Name ~= "EliteShield" and d.Size.Magnitude < 40 then
            table.insert(list, d)
        end
    end
    for _, d in ipairs(list) do d.LocalTransparencyModifier = 1 end -- (the original lingers a moment on party floors)
    table.sort(list, function(a, b) return a.Size.Magnitude > b.Size.Magnitude end)
    local room = MAX_DEBRIS - #debris
    local folder = Workspace:FindFirstChild("EnemyDebris")
    if not folder then folder = Instance.new("Folder"); folder.Name = "EnemyDebris"; folder.Parent = Workspace end
    for i = 1, math.min(#list, 36, room) do
        local src = list[i]
        local ok, c = pcall(function() return src:Clone() end)
        if ok and c then
            for _, ch in ipairs(c:GetChildren()) do if not ch:IsA("SpecialMesh") and not ch:IsA("SurfaceAppearance") then ch:Destroy() end end
            c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
            c.LocalTransparencyModifier = 0
            c.Name = "Debris"
            c.Parent = folder
            local out = src.Position - center
            local dir = (out.Magnitude > 0.1) and out.Unit or Vector3.new(math.random() - 0.5, 0.5, math.random() - 0.5).Unit
            local v
            if ground then
                v = dir * (4 + math.random() * 5) + Vector3.new(0, 6 + math.random() * 6, 0)
            else
                v = dir * (8 + math.random() * 10) + Vector3.new(0, 4 + math.random() * 8, 0)
            end
            table.insert(debris, { Part = c, CF = src.CFrame, V = v, W = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 9,
                T0 = os.clock(), Life = 0.75 + math.random() * 0.35, T = src.Transparency })
        end
    end
    Untrack(model)
end

-- ===== the loop =====
local function Pose(rec, dt, t, camPos)
    local model = rec.Model
    if not rec.Ready then Collect(rec) end
    local pv = model:GetPivot()
    -- the AI set a fresh pivot this frame unless the pivot is still what WE drew last frame (party / idle frames)
    local base = (rec.Drawn and pv.Position:FuzzyEq(rec.Drawn.Position, 1e-3) and pv.LookVector:FuzzyEq(rec.Drawn.LookVector, 1e-4)) and rec.LastBase or pv
    rec.LastBase = base
    local pos = base.Position
    local v = (pos - rec.LastPos) / math.max(dt, 1 / 240)
    rec.LastPos = pos
    if v.Magnitude > 200 then v = Vector3.zero end -- (a blink / redeploy)
    rec.Vel = rec.Vel:Lerp(v, math.clamp(dt * 8, 0, 1))
    local lv = base:VectorToObjectSpace(rec.Vel)
    local speed = Vector3.new(lv.X, 0, lv.Z).Magnitude
    local ph = rec.Phase

    -- attack state (EnemyAttacks: AtkStart / AtkEnd in server time)
    local sNow = Now()
    local a0, a1 = model:GetAttribute("AtkStart") or 0, model:GetAttribute("AtkEnd") or 0
    local wind = (sNow >= a0 and sNow < a1) and math.clamp((sNow - a0) / math.max(0.05, a1 - a0), 0, 1) or 0
    local after = sNow - a1
    local strike = (after >= 0 and after < 0.35) and (1 - after / 0.35) or 0
    local fl = os.clock() - rec.Flinch
    local flinch = (fl < 0.22) and (1 - fl / 0.22) or 0

    -- BODY
    local body
    if rec.Boss then
        body = CFrame.new(0, math.sin(t * 1.6 + ph) * 0.25, 0) * CFrame.Angles(-wind * 0.12 + strike * 0.18 - flinch * 0.06, 0, 0)
    elseif rec.Ground then
        local stride = math.clamp(speed / 14, 0, 1.3)
        local bob = math.abs(math.sin(t * 7 + ph)) * 0.22 * stride + math.sin(t * 2 + ph) * 0.05
        local lean = math.clamp(lv.Z * 0.012, -0.22, 0.22) -- (-Z is forward: leaning into the run)
        local roll = math.clamp(-lv.X * 0.01, -0.15, 0.15)
        body = CFrame.new(0, bob, 0) * CFrame.Angles(lean - wind * 0.25 + strike * 0.35 - flinch * 0.2, 0, roll)
    else
        local hover = math.sin(t * 2.3 + ph) * 0.28 * math.max(0.6, rec.R * 0.4)
        local bank = math.clamp(-lv.X * 0.02, -0.4, 0.4)
        local pitch = math.clamp(lv.Z * 0.012, -0.25, 0.25)
        local shake = (wind > 0.75) and (math.sin(t * 60) * 0.03) or 0
        body = CFrame.new(0, hover, 0) * CFrame.Angles(pitch - wind * 0.3 + strike * 0.4 - flinch * 0.25 + shake, 0, bank + shake)
    end
    if flinch > 0 and rec.FlinchDir.Magnitude > 0.1 then
        body = CFrame.new(base:VectorToObjectSpace(rec.FlinchDir.Unit) * flinch * 0.35) * body
    end
    local root = base * body
    if not rec.DecoOnly then
        model:PivotTo(root)
        rec.Drawn = model:GetPivot()
    else
        rec.Drawn = nil
    end

    -- PARTS
    local parts, cfs = {}, {}
    local orbitA = t * (0.9 + wind * 2.5) + ph
    for _, e in ipairs(rec.Parts) do
        local p = e.Part
        if p.Parent then
            local role = e.Role
            local cf = nil
            if role == "Flap" then
                local amp = (rec.Style == "Angel" or rec.Style == "Ashwing" or rec.Style == "Gale") and 0.45 or 0.32
                local ang = math.sin(t * (6 + wind * 6) + ph) * amp * e.Sign
                cf = e.Hinge * CFrame.fromAxisAngle(e.Axis, ang) * e.Hinge:Inverse() * e.Off
            elseif role == "Fin" then
                local ang = math.sin(t * 3.2 + ph + e.Off.Position.Y) * (0.14 + wind * 0.2) * e.Sign
                cf = e.Hinge * CFrame.fromAxisAngle(e.Axis, ang) * e.Hinge:Inverse() * e.Off
            elseif role == "Orbit" then
                cf = CFrame.Angles(0, orbitA, 0) * e.Off
            elseif role == "Spin" then
                cf = e.Off * CFrame.Angles(0, t * (1.2 + wind * 4), 0)
            elseif role == "Gyro" then
                cf = CFrame.Angles(math.sin(t * 1.7 + ph) * 0.16, 0, math.cos(t * 1.3 + ph) * 0.16) * e.Off
            elseif role == "Sway" then
                cf = CFrame.Angles(0, math.sin(t * 3 + ph - e.Dist * 0.6) * 0.18, math.sin(t * 2.2 + ph - e.Dist * 0.5) * 0.08) * e.Off
            elseif role == "Jaw" then
                local open = math.max(wind, strike) * 0.55
                cf = e.Hinge * CFrame.Angles(open, 0, 0) * e.Hinge:Inverse() * e.Off
            elseif role == "Spring" then
                cf = CFrame.new(0, -math.abs(math.sin(t * 5 + ph)) * 0.25 - wind * 0.3, 0) * e.Off
            elseif role == "Eye" or role == "Glow" then
                -- (colour / transparency only, at most every other frame)
                if rec.Tick then
                    local k = math.max(wind, strike)
                    if role == "Eye" then
                        local c = (k > 0) and e.Color:Lerp(Color3.fromRGB(255, 70, 50), k) or e.Color
                        if p.Color ~= c then p.Color = c end
                    else
                        local tr = math.clamp(e.T + (math.sin(t * 3 + ph) * 0.5 + 0.5) * 0.25 - k * 0.3, 0, 0.9)
                        if math.abs(p.Transparency - tr) > 0.02 then p.Transparency = tr end
                    end
                end
                if rec.DecoOnly then cf = e.Off end
            elseif rec.DecoOnly then
                cf = e.Off -- (party decorations ride the posed body)
            end
            if cf then
                table.insert(parts, p)
                table.insert(cfs, root * cf)
            end
        end
    end
    if #parts > 0 then Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
end

local frame = 0
RunService:BindToRenderStep("AimRngEnemyAnim", Enum.RenderPriority.Character.Value + 2, function(dt)
    frame += 1
    local t = os.clock()
    local cam = Workspace.CurrentCamera
    local camPos = cam and cam.CFrame.Position or Vector3.zero
    for model, rec in pairs(tracked) do
        if not model.Parent then
            Untrack(model)
        elseif model:GetAttribute("Dead") == true then
            EnemyAnim.Death(model)
        elseif model:GetAttribute("PredictedDead") ~= true and model:GetAttribute("LinkSleep") ~= true then
            -- (optimization pass 2026-10-27: asleep linked-room bots -- far, or parked out of the workspace -- and bots
            -- well behind the camera aren't posed; no shadows in dungeons, so nothing of them can show. Bosses always are)
            local rel = model:GetPivot().Position - camPos
            local d = rel.Magnitude
            local behind = cam ~= nil and not rec.Boss and d > 16 and cam.CFrame.LookVector:Dot(rel) < -12
            if not behind and d < 260 and (d < 110 or (frame + (rec.Phase * 10) // 1) % 2 == 0) then
                rec.Tick = (frame % 2 == 0)
                local ok, err = pcall(Pose, rec, (d < 110) and dt or dt * 2, t, camPos)
                if not ok then
                    warn("[EnemyAnim] " .. tostring(err))
                    Untrack(model)
                end
            end
        end
    end
    -- death debris: tumble out, fall, fade
    for i = #debris, 1, -1 do
        local e = debris[i]
        local age = os.clock() - e.T0
        if age >= e.Life or not e.Part.Parent then
            if e.Part.Parent then e.Part:Destroy() end
            table.remove(debris, i)
        else
            e.V += Vector3.new(0, -46 * dt, 0)
            e.CF = (e.CF + e.V * dt) * CFrame.Angles(e.W.X * dt, e.W.Y * dt, e.W.Z * dt)
            e.Part.CFrame = e.CF
            local k = age / e.Life
            e.Part.Transparency = e.T + (1 - e.T) * (k * k)
            if k > 0.5 then e.Part.Size = e.Part.Size * (1 - dt * 1.4) end
        end
    end
end)

-- every enemy is tagged AimRngEnemy (DungeonGenerator); solo ones are built on this client, party ones replicate
if RunService:IsClient() then
    local function Add(m)
        if m:IsA("Model") then task.defer(function() if m.Parent then EnemyAnim.Track(m) end end) end
    end
    for _, m in ipairs(CollectionService:GetTagged("AimRngEnemy")) do Add(m) end
    CollectionService:GetInstanceAddedSignal("AimRngEnemy"):Connect(Add)
    CollectionService:GetInstanceRemovedSignal("AimRngEnemy"):Connect(function(m)
        if tracked[m] and m:GetAttribute("Dead") == true then EnemyAnim.Death(m) end
        Untrack(m)
    end)
end

return EnemyAnim
