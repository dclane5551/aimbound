--!nocheck
-- JOIN CURTAIN (2026-10-21, owner: "you still get spawned in the ground for a few seconds when you first load in").
-- The server builds every character itself (AimRngServer/R6Spawner: ~3 s for the avatar, up to 8 s before the plain-body
-- fallback), so for the first seconds there is no character and the camera sits at its default spot under the street.
-- This runs first (ReplicatedFirst) and covers the screen in the UI v4 look until the first character is in the world
-- and the client has had a moment to place the camera, then fades out. Never comes back (respawns keep the old view).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local MAX_WAIT = 25 -- s: never trap anyone behind it
local SETTLE = 0.6 -- s after the character arrives (the hub camera / tutorial teleport takes over)

local gui = Instance.new("ScreenGui")
gui.Name = "JoinCurtain"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(10, 10, 18) -- UIStyle Bg0
bg.BorderSizePixel = 0
bg.Parent = gui

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.46)
title.Size = UDim2.fromOffset(600, 60)
title.BackgroundTransparency = 1
title.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
title.Text = "AIMBOUND"
title.TextSize = 48
title.TextColor3 = Color3.fromRGB(235, 238, 248)
title.Parent = bg

local line = Instance.new("Frame")
line.AnchorPoint = Vector2.new(0.5, 0.5)
line.Size = UDim2.fromOffset(0, 2)
line.Position = UDim2.new(0.5, 0, 0.46, 36)
line.BackgroundColor3 = Color3.fromRGB(48, 226, 255) -- Colors.Neon
line.BorderSizePixel = 0
line.Parent = bg

local sub = Instance.new("TextLabel")
sub.AnchorPoint = Vector2.new(0.5, 0)
sub.Position = UDim2.new(0.5, 0, 0.46, 48)
sub.Size = UDim2.fromOffset(600, 22)
sub.BackgroundTransparency = 1
sub.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Medium)
sub.Text = "LOADING"
sub.TextSize = 16
sub.TextColor3 = Color3.fromRGB(150, 156, 178)
sub.Parent = bg

gui.Parent = player:WaitForChild("PlayerGui")

-- the neon line fills while we wait (one tween, no loop)
TweenService:Create(line, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(240, 2) }):Play()

local t0 = os.clock()
local function Ready(): boolean
    local c = player.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    return root ~= nil and c:IsDescendantOf(workspace)
end
while not Ready() and os.clock() - t0 < MAX_WAIT do
    task.wait(0.1)
end
task.wait(SETTLE)
RunService.RenderStepped:Wait()

local fade = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(bg, fade, { BackgroundTransparency = 1 }):Play()
TweenService:Create(title, fade, { TextTransparency = 1 }):Play()
TweenService:Create(sub, fade, { TextTransparency = 1 }):Play()
TweenService:Create(line, fade, { BackgroundTransparency = 1 }):Play()
task.wait(0.4)
gui:Destroy()
