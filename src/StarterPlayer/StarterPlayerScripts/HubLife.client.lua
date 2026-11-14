--!nocheck
-- HUB LIFE (UPDATE 4, owner: the hub "looks a bit worse than all of the new biomes" -- nothing in it moved). Client-only
-- motion for the server-built walled city, found by CollectionService tags (they replicate):
--   "HubFlicker"  a Neon part (or a sign's TextLabel) that now and then stutters like a failing tube (a short burst of
--                 on / off, then steady)
--   "HubSway"     a Model (a street board on its wires) that swings a little about its WorldPivot
-- Runs at 30 Hz, only while the hub is out (HubWorld under workspace -- in runs the client parks it), only near the camera.
-- On Graphics Quality Low (AimRngShared.QualityMode) the sway stops; the flicker is a property write, it stays.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QM
task.spawn(function()
    local ok, m = pcall(function() return require(ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("QualityMode", 20)) end)
    QM = ok and m or nil
end)
local function Low(): boolean
    return QM ~= nil and QM.IsLow ~= nil and QM.IsLow() == true
end

local flick = {} -- [part] = { base, next, untilT, phase }
local spin = {} -- [ImageLabel] = deg/s ("HubSpin": the gates' vortex layers)
local sway = {} -- [model] = { base, amp, rate, phase }

local function AddFlicker(p: Instance)
    if flick[p] then return end
    if p:IsA("BasePart") then
        flick[p] = { Base = p.Transparency, Next = os.clock() + math.random() * 10 + 2, Till = 0 }
    elseif p:IsA("TextLabel") then -- (a sign's lettering: its text stutters, the board stays)
        flick[p] = { Base = p.TextTransparency, Next = os.clock() + math.random() * 10 + 2, Till = 0, Text = true }
    end
end
local function AddSway(m: Instance)
    if m:IsA("Model") and not sway[m] then
        sway[m] = { Base = m:GetPivot(), Amp = math.rad(1.1 + math.random() * 0.9), Rate = 0.55 + math.random() * 0.35, Phase = math.random() * 6.28 }
    end
end
for _, p in ipairs(CollectionService:GetTagged("HubFlicker")) do AddFlicker(p) end
for _, m in ipairs(CollectionService:GetTagged("HubSway")) do AddSway(m) end
CollectionService:GetInstanceAddedSignal("HubFlicker"):Connect(AddFlicker)
for _, l in ipairs(CollectionService:GetTagged("HubSpin")) do spin[l] = l:GetAttribute("SpinRate") or 20 end
CollectionService:GetInstanceAddedSignal("HubSpin"):Connect(function(l) spin[l] = l:GetAttribute("SpinRate") or 20 end)
CollectionService:GetInstanceRemovedSignal("HubSpin"):Connect(function(l) spin[l] = nil end)
CollectionService:GetInstanceAddedSignal("HubSway"):Connect(AddSway)
CollectionService:GetInstanceRemovedSignal("HubFlicker"):Connect(function(p) flick[p] = nil end)
CollectionService:GetInstanceRemovedSignal("HubSway"):Connect(function(m) sway[m] = nil end)

local acc = 0
RunService.Heartbeat:Connect(function(dt)
    acc += dt
    if acc < 1 / 30 then return end
    acc = 0
    local hub = workspace:FindFirstChild("HubWorld")
    if not hub then return end
    local cam = workspace.CurrentCamera
    local eye = cam and cam.CFrame.Position or Vector3.zero
    local t = os.clock()
    for p, f in pairs(flick) do
        if not p.Parent then
            flick[p] = nil
        elseif p:IsDescendantOf(hub) then
            local prop = f.Text and "TextTransparency" or "Transparency"
            local at = f.Text and (p:FindFirstAncestorWhichIsA("BasePart") :: BasePart) or (p :: BasePart)
            if at and (at.Position - eye).Magnitude < 260 then
                if t >= f.Next then -- start a burst: 0.35-0.9 s of stutter, then 5-16 s steady
                    f.Till = t + 0.35 + math.random() * 0.55
                    f.Next = f.Till + 5 + math.random() * 11
                end
                if t < f.Till then
                    p[prop] = (math.random() < 0.55) and math.min(1, f.Base + 0.75) or f.Base
                elseif p[prop] ~= f.Base then
                    p[prop] = f.Base
                end
            end
        end
    end
    for l, rate in pairs(spin) do
        if not l.Parent then spin[l] = nil elseif l:IsDescendantOf(hub) then l.Rotation = (t * rate) % 360 end
    end
    if Low() then return end
    for m, s in pairs(sway) do
        if not m.Parent then
            sway[m] = nil
        elseif m:IsDescendantOf(hub) and (s.Base.Position - eye).Magnitude < 220 then
            local k = t * s.Rate + s.Phase
            m:PivotTo(s.Base * CFrame.Angles(math.sin(k * 0.7) * s.Amp * 0.4, 0, math.sin(k) * s.Amp))
        end
    end
end)
