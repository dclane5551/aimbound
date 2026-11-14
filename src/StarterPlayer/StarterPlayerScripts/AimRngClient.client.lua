--!nocheck
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local function GetLocalPlayer(): Player
    local lp = Players.LocalPlayer
    while not lp do
        task.wait(0.05)
        lp = Players.LocalPlayer
    end
    return lp
end
local LocalPlayer = GetLocalPlayer()

local function GetPlayerGui(): PlayerGui
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:FindFirstChild("PlayerGui")
    while not pg do
        task.wait(0.05)
        pg = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:FindFirstChild("PlayerGui")
    end
    return pg
end
local PlayerGui = GetPlayerGui()
local Camera = Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")
local vmFOV = 90 -- FOV the viewmodel is fitted for: the hip FOV (never the ADS zoom)
local baseFOV = 90 -- FOV set by the settings slider; the render loop below lerps toward this (or the weapon ADS zoom) every frame
local activeSlot = "Gun" -- "Gun" or "Melee" (MELEE SYSTEM: [1] gun, [3] melee, [Q] swap)
local ApplyMeleeToRig: () -> () -- defined with the melee system below; RebuildViewmodelForWeapon calls it
local isAiming = false -- right mouse (hold or toggle, see Settings > Gameplay); declared up here for the camera
-- Player settings (values, change notifications, saving) and the Settings window built from them.
local GameSettings = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("GameSettings"))
local SettingsMenu = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("SettingsMenu"))
local UIStyle = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("UIStyle"))
-- one type system for every screen + world label (UIStyle.InstallType maps the old fonts to Builder Sans weights)
UIStyle.InstallType(game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))
UIStyle.InstallType(workspace)
-- (UI CLEAN R-A: the menus / progress / social / store windows join the full-screen menu system BEFORE they build --
-- AimRngShared/MenuKit; UIStyle.MENU_WINDOWS / MenuChrome are builder clean's)
pcall(function() require(game.ReplicatedStorage.AimRngShared:WaitForChild("MenuKit")).Register(UIStyle) end)
-- "[R]"-style label for a rebindable action (Settings > Controls), used in HUD hints.
local function KeyTag(action: string): string
    if GameSettings.TouchOnly() then return "" end -- (phones: no keys to show)
    return "[" .. string.upper(GameSettings.KeyLabel(GameSettings.BindName(action))) .. "]"
end

-- 1. STRICT FIRST-PERSON CAMERA LOCK & CURSOR CENTERING (FRAME 0)
LocalPlayer.CameraMinZoomDistance = 0.5
LocalPlayer.CameraMaxZoomDistance = 0.5
LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

local isCursorUnlocked = false
local isAnyMenuOpen = false
local spectateTarget: Player? = nil -- LIVES: out of lives in a party -> the camera follows this teammate

local function SetMouseLocked(locked: boolean)
    -- (CameraMode stays LockFirstPerson either way -- the custom camera below owns the view, and flipping
    -- the default camera module between modes on every menu open/close only caused hitches.)
    LocalPlayer:SetAttribute("CursorFree", not locked) -- (MovementController reads this: menus / free cursor pause movement)
    if locked then
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        UserInputService.MouseIconEnabled = false
        isCursorUnlocked = false
    else
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
        isCursorUnlocked = true
    end
end
SetMouseLocked(true)

-- ==================== RAW-INPUT FIRST-PERSON CAMERA ====================
-- Replaces Roblox's default camera while alive. The default one scales vertical mouse movement to ~77%
-- of horizontal and runs through the camera module's zoom/occlusion pipeline -- that's the "not raw"
-- feel. Here every pixel of mouse delta maps to the same angle on both axes, applied the same frame,
-- with no smoothing or acceleration (aim-trainer / Rivals style). ADS keeps the same feel by scaling
-- sensitivity with the zoom ratio. The in-game Sensitivity setting still works (MouseDeltaSensitivity).
local CAM_RAD_PER_PIXEL = math.rad(0.5) -- matches Roblox's default horizontal rate, now on both axes
local CAM_PITCH_LIMIT = math.rad(88)
local CAM_EYE_HEIGHT = 1.5 -- HumanoidRootPart center -> head center (R6 and default R15)
local camYaw, camPitch = 0, 0
local camInitialized = false
local camHiddenParts: { BasePart } = {}

local function TrackCharacterForCamera(char: Model)
    camInitialized = false
    camHiddenParts = {}
    local list = camHiddenParts
    -- (2026-11-07, owner: the Infrared M4A1's thermal finger marks floated in the air in first person) decals ride along:
    -- a Decal / Texture on a hidden part still draws, so your own world gun's decals showed beside the viewmodel
    local function add(d: Instance)
        if d:IsA("BasePart") or d:IsA("Decal") then table.insert(list, d :: any) end
    end
    for _, d in ipairs(char:GetDescendants()) do add(d) end
    char.DescendantAdded:Connect(add)
end
if LocalPlayer.Character then TrackCharacterForCamera(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(TrackCharacterForCamera)

-- Recoil & other scripted camera kicks go through here (writing Camera.CFrame directly would be
-- overwritten by this camera next frame).
-- Mouse movement is accumulated from every raw input event and consumed once per frame, so no motion
-- is dropped or bunched up between frames (polling GetMouseDelta once per frame can return uneven
-- deltas at high frame rates, which reads as choppy / "not quite following my hand").
local camPendingDelta = Vector2.zero
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        camPendingDelta += Vector2.new(input.Delta.X, input.Delta.Y)
    end
end)

-- Alt-tabbing out drops the OS mouse lock even though MouseBehavior still reads LockCenter, which left
-- the cursor stuck on screen. Re-apply the lock from scratch whenever the window regains focus.
UserInputService.WindowFocused:Connect(function()
    if not isCursorUnlocked and not isAnyMenuOpen then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        task.defer(function()
            if not isCursorUnlocked and not isAnyMenuOpen then
                UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                UserInputService.MouseIconEnabled = false
            end
        end)
    end
end)

local function AddCameraKick(pitchRad: number, yawRad: number)
    camPitch = math.clamp(camPitch + pitchRad, -CAM_PITCH_LIMIT, CAM_PITCH_LIMIT)
    camYaw += yawRad
end

-- SMOOTH EYE (owner 2026-10-03: "the gun / screen jitters a bit when jumping around"). Physics steps at a fixed rate that
-- doesn't line up with the frame rate, so the root moves in uneven chunks per frame (measured mid-hop: 0.64 / 1.06 / 0.77 /
-- 1.26 studs on consecutive frames for a steady fall) and the camera -- and the gun on it -- judders, worst at speed and on
-- high-refresh screens. The eye now rides a copy of the root position that moves by your velocity each frame and eases
-- the leftover error out over ~40 ms: no lag (it's velocity-predicted), just the step noise gone. A real jump in position
-- (teleport / respawn / floor change) snaps.
do
local eyeSmooth: Vector3? = nil
RunService:BindToRenderStep("AimRngRawCamera", Enum.RenderPriority.Camera.Value, function(camDt)
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    -- spectating a teammate (out of lives in a party): see through their eyes (their body hidden, their
    -- facing + shared AimPitch, smoothed); a downed teammate or your own fallen body: orbit; the mouse turns the view
    local st = spectateTarget
    local stRoot = st and st.Character and st.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if stRoot and st ~= LocalPlayer and not st:GetAttribute("Downed") then
        if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
        camPendingDelta = Vector2.zero
        -- (0.83 LIVE VIEW) a city watcher plays back the target's REAL camera (SpectateClient: stamped, interpolated)
        local scf, sfov = nil, nil
        if UI.watching == st and UI.spectate and UI.spectate.CameraNow then scf, sfov = UI.spectate.CameraNow() end
        if scf then
            cam.CFrame = scf
            cam.Focus = scf
            cam.FieldOfView = sfov or cam.FieldOfView
            UI.spectateFov = sfov
            local lv = scf.LookVector
            camYaw, camPitch = math.atan2(-lv.X, -lv.Z), math.asin(math.clamp(lv.Y, -1, 1))
            for _, d in ipairs(st.Character:GetDescendants()) do
                if (d:IsA("BasePart") or d:IsA("Decal")) and d.LocalTransparencyModifier ~= 1 then d.LocalTransparencyModifier = 1 end
            end
            return
        end
        UI.spectateFov = nil
        local look = stRoot.CFrame.LookVector
        local tYaw = math.atan2(-look.X, -look.Z)
        local tPitch = tonumber(st:GetAttribute("AimPitch")) or 0
        local k = 1 - math.exp(-20 * (1 / 60))
        camYaw += ((tYaw - camYaw + math.pi) % (2 * math.pi) - math.pi) * k
        camPitch += (tPitch - camPitch) * k
        local stHum = st.Character:FindFirstChildOfClass("Humanoid")
        local camCF = CFrame.new(stRoot.Position + Vector3.new(0, CAM_EYE_HEIGHT, 0) + (stHum and stHum.CameraOffset or Vector3.zero)) * CFrame.Angles(0, camYaw, 0) * CFrame.Angles(camPitch, 0, 0)
        cam.CFrame = camCF
        cam.Focus = camCF
        -- (only the one whose eyes these are hides: everyone else keeps the instance rules' visibility, 0.62)
        for _, d in ipairs(st.Character:GetDescendants()) do
            if (d:IsA("BasePart") or d:IsA("Decal")) and d.LocalTransparencyModifier ~= 1 then d.LocalTransparencyModifier = 1 end
        end
        return
    end
    if stRoot then
        for _, d in ipairs(st.Character:GetDescendants()) do
            if (d:IsA("BasePart") or d:IsA("Decal")) and st ~= LocalPlayer and d.LocalTransparencyModifier ~= 0 then d.LocalTransparencyModifier = 0 end
        end
        if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
        local d = (isCursorUnlocked or isAnyMenuOpen) and Vector2.zero or camPendingDelta * UserInputService.MouseDeltaSensitivity
        camPendingDelta = Vector2.zero
        if st == LocalPlayer then camYaw += 0.004 end -- downed: the camera slowly circles your body
        camYaw -= d.X * CAM_RAD_PER_PIXEL
        camPitch = math.clamp(camPitch - d.Y * CAM_RAD_PER_PIXEL, -1.2, 0.6)
        local rot = CFrame.Angles(0, camYaw, 0) * CFrame.Angles(camPitch, 0, 0)
        local focus = stRoot.Position + Vector3.new(0, 2.5, 0)
        local camCF = CFrame.new(focus) * rot * CFrame.new(1.5, 0.5, 11)
        cam.CFrame = camCF
        cam.Focus = CFrame.new(focus)
        return
    end
    if not root or not hum or hum.Health <= 0 then
        -- Dead / respawning: hand the camera back to Roblox's default death/spawn behavior.
        if cam.CameraType == Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Custom end
        camInitialized = false
        return
    end
    if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
    if not camInitialized then
        local look = root.CFrame.LookVector
        camYaw = math.atan2(-look.X, -look.Z)
        camPitch = 0
        camInitialized = true
    end

    if LocalPlayer:GetAttribute("ThirdPerson") and not isAnyMenuOpen then
        -- third-person hub: a normal Roblox camera -- free cursor, hold right mouse to orbit (HubCamera reads the drag)
        local d = require(game:GetService("ReplicatedStorage").AimRngShared.HubCamera).OrbitDelta() * UserInputService.MouseDeltaSensitivity
        if GameSettings.Get("InvertY") then d = Vector2.new(d.X, -d.Y) end
        camYaw -= d.X * CAM_RAD_PER_PIXEL * 0.8
        camPitch = math.clamp(camPitch - d.Y * CAM_RAD_PER_PIXEL * 0.8, -1.25, 1.0)
    elseif not isCursorUnlocked and not isAnyMenuOpen then
        if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        end
        if UserInputService.MouseIconEnabled then UserInputService.MouseIconEnabled = false end
        local d = camPendingDelta * UserInputService.MouseDeltaSensitivity * (isAiming and GameSettings.Get("ADSSensitivity") or 1)
        if GameSettings.Get("InvertY") then d = Vector2.new(d.X, -d.Y) end
        if d.X ~= 0 or d.Y ~= 0 then
            local zoom = math.tan(math.rad(cam.FieldOfView) * 0.5) / math.tan(math.rad(baseFOV) * 0.5)
            camYaw -= d.X * CAM_RAD_PER_PIXEL * zoom
            camPitch = math.clamp(camPitch - d.Y * CAM_RAD_PER_PIXEL * zoom, -CAM_PITCH_LIMIT, CAM_PITCH_LIMIT)
        end
    end

    if LocalPlayer:GetAttribute("DevTurn") then camYaw -= LocalPlayer:GetAttribute("DevTurn") * camDt end -- (Studio test hook: yaw rad/s, + = right)
    -- (Studio test hook, tools/autoplay.luau) Player attr DevLook = a world direction (Vector3): the camera looks along it this frame,
    -- so shots take the real Camera.CFrame path
    if typeof(LocalPlayer:GetAttribute("DevLook")) == "Vector3" and RunService:IsStudio() and LocalPlayer:GetAttribute("DevLook").Magnitude > 0.01 then
        camYaw = math.atan2(-LocalPlayer:GetAttribute("DevLook").Unit.X, -LocalPlayer:GetAttribute("DevLook").Unit.Z)
        camPitch = math.clamp(math.asin(math.clamp(LocalPlayer:GetAttribute("DevLook").Unit.Y, -1, 1)), -CAM_PITCH_LIMIT, CAM_PITCH_LIMIT)
    end
    camPendingDelta = Vector2.zero -- consumed (or discarded while a menu/free cursor is up)

    -- hub hall: third-person orbit camera (HubCamera); it pulls back out of / pushes back into these eyes smoothly
    do
        local tpCF = require(game:GetService("ReplicatedStorage").AimRngShared.HubCamera).Update(camDt or 1 / 60, char, root, hum, camYaw, camPitch)
        if tpCF then
            cam.CFrame = tpCF
            cam.Focus = CFrame.new(root.Position + Vector3.new(0, 2, 0))
            eyeSmooth = nil
            return
        end
    end

    -- Body faces wherever you look (what LockFirstPerson used to do), then the eye rides the root.
    -- Only rewrite the root when its facing actually differs -- a CFrame write every frame nudges the
    -- character's physics and shows up as micro-jitter in the camera.
    if hum.AutoRotate then hum.AutoRotate = false end
    local rootPos = root.Position
    local look = root.CFrame.LookVector
    camYaw = (camYaw + math.pi) % (2 * math.pi) - math.pi
    local yawCF = CFrame.Angles(0, camYaw, 0)
    local yawDiff = (math.atan2(-look.X, -look.Z) - camYaw + math.pi) % (2 * math.pi) - math.pi
    if math.abs(yawDiff) > 0.0005 then
        root.CFrame = CFrame.new(rootPos) * yawCF
    end
    -- movement tech feel (MovementController): slide crouch / landing dip on the eye height, lean on dashes
    local MV = require(game:GetService("ReplicatedStorage").AimRngShared.MovementController)
    local eyeDt = math.clamp(camDt or 1 / 60, 0, 0.1)
    local pred = eyeSmooth and (eyeSmooth + root.AssemblyLinearVelocity * eyeDt)
    if not pred or (rootPos - pred).Magnitude > 5 then
        eyeSmooth = rootPos
    else
        eyeSmooth = pred + (rootPos - pred) * (1 - math.exp(-eyeDt * 25))
    end
    local camCF = CFrame.new(eyeSmooth + Vector3.new(0, CAM_EYE_HEIGHT + MV.EyeOffset, 0) + hum.CameraOffset) * yawCF * CFrame.Angles(camPitch, 0, 0) * CFrame.Angles(0, 0, MV.CamRoll)
    cam.CFrame = camCF
    cam.Focus = camCF

    for i = 1, #camHiddenParts do
        local p = camHiddenParts[i]
        if p.LocalTransparencyModifier ~= 1 then p.LocalTransparencyModifier = 1 end
    end
end)
end

pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    -- No Roblox tools in this game (custom weapons): the backpack hotbar would also swallow the 1/2/3 keys
    -- used to pick run boons.
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- 2. CORE UI CONTAINER & SCREEN GUI
local UI = {}
UI.Zones = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Zones")) -- (no new top-level local: the main chunk is at the 200-local limit)
UI.hudGui = Instance.new("ScreenGui")
local hudGui = UI.hudGui
hudGui.Name = "AimRngMasterHUD"
hudGui.ResetOnSpawn = false
hudGui.IgnoreGuiInset = true
hudGui.Enabled = true
hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
hudGui.Parent = PlayerGui

-- 3. LOAD REPLICATED MODULES
local sharedFolder = game.ReplicatedStorage:WaitForChild("AimRngShared", 15)
if not sharedFolder then
    error("[AimRngClient] ReplicatedStorage.AimRngShared missing!")
end
local Remotes = require(sharedFolder:WaitForChild("Remotes", 15) :: ModuleScript)
local ItemData = require(sharedFolder:WaitForChild("ItemData", 15) :: ModuleScript)
local StatCalculator = require(sharedFolder:WaitForChild("StatCalculator", 15) :: ModuleScript)
local SkillTreeData = require(sharedFolder:WaitForChild("SkillTreeData", 15) :: ModuleScript)
local SoundHelper = require(sharedFolder:WaitForChild("SoundHelper", 15) :: ModuleScript)
local WeaponMeshes = require(sharedFolder:WaitForChild("WeaponMeshes", 15) :: ModuleScript)

-- 1. Client State
local initialWeapon = ItemData.CreateStarterPistol()
local clientState = {
    EquippedWeapon = initialWeapon,
    Inventory = { initialWeapon } :: { ItemData.WeaponInstance },
    EquippedGear = {} :: { [string]: ItemData.GearInstance },
    GearInventory = {} :: { ItemData.GearInstance },
    AllocatedNodes = {},
    Streak = 0,
    SkillPoints = 5,
    StatPoints = 5,
    Attributes = {
        Strength = 5,
        Dexterity = 5,
        Vitality = 5,
        Luck = 5,
    },
    Gold = 1000,
    UpgradeShards = 40,
    ForgeCores = 0,
    RollsCount = 0,
    AutoSellThreshold = "OFF",
    Level = 1,
    XP = 0,
    MaxXP = 150,
    Health = 150,
    MaxHealth = 150,
    EquippedGlove = "Tactical",
    GloveInventory = { "Tactical" },
    EquippedKnife = "Knife",
    KnifeInventory = { "Knife" },
    EquippedTitle = "Rookie",
    UnlockedTitles = { "Rookie" },
    DungeonDifficulty = "Easy",
    CurrentMag = initialWeapon.MagazineSize or 18,
    MaxMag = initialWeapon.MagazineSize or 18,
    IsReloading = false,
    StatsTracking = {
        SniperHeadshots = 0,
        MeleeKills = 0,
        BossKills = 0,
        ExplosiveDamageDealt = 0,
        TotalKills = 0,
        DiscoveredWeapons = { [initialWeapon.BaseId] = true },
    },
}

local canShoot = true
local isMouseDown = false
-- (isAnyMenuOpen / isCursorUnlocked are declared once, at the top next to SetMouseLocked. They used to be
-- re-declared here too, so the menu code and the mouse-lock code were updating two different copies.)
-- reload/melee active states
local isReloading = false
local isPerformingMelee = false
local pendingBetterWeapon: ItemData.WeaponInstance? = nil

-- Viewmodel animation & recoil state
local vmRecoilZ = 0
local vmRecoilY = 0
local vmBobPhase, vmBobAmount = 0, 0
local vmRevolverCylRot = 0
local vmMinigunRot = 0
local dualShotToggle = false


local function TeleportClient(cf: CFrame)
    if not UI.Zones.AwayFromCity(cf.Position) and UI.ShowHub then UI.ShowHub() end -- (the hub is parked while you're away: back first)
    -- the custom camera keeps its own yaw/pitch: face where the teleport points
    local look = cf.LookVector
    camYaw = math.atan2(-look.X, -look.Z)
    camPitch = 0
    local char = LocalPlayer.Character
    if char then
        char:PivotTo(cf)
        local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if root then
            root.CFrame = cf
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

-- Private dungeons: the floor and its enemies are built on this client (see DungeonClient / DungeonRuns).
local DungeonClient = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("DungeonClient"))
local DungeonGeneratorShared = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("DungeonGenerator"))
DungeonClient.Init({ Teleport = TeleportClient })
-- (owner 2026-10-07: "finishing a dungeon or dying, and then respawning often bugs you out in the hub and you fall over")
-- your character can never trip / ragdoll: a teleport or a spawn that lands a little inside geometry used to knock it
-- over. The client owns its character's physics, so the states are switched off here, on every new character.
;(function()
    local function NoTrip(char: Model)
        local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
        if not hum then return end
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    end
    if LocalPlayer.Character then task.spawn(NoTrip, LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(NoTrip)
    -- DOWNED POSE (0.59, owner: "Character falls over and starts kicking on ground upon death in dungeons"): the server
    -- tips you over, but the Humanoid kept trying to stand and run, so the legs kicked on the floor. Out of lives: lie
    -- still (PlatformStand, animations stopped, root anchored flat where you fell); a revive / respawn lets go.
    local frozen = false
    local function Downed()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not (hum and root) then return end
        local down = LocalPlayer:GetAttribute("Downed") == true
        if down and not frozen then
            frozen = true
            hum.PlatformStand = true
            local animator = hum:FindFirstChildOfClass("Animator")
            if animator then for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do tr:Stop(0.1) end end
            local _, yaw = root.CFrame:ToOrientation()
            local ray = Workspace:Raycast(root.Position + Vector3.new(0, 4, 0), Vector3.new(0, -16, 0), (function()
                local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = { char }; return rp
            end)())
            local floorY = ray and ray.Position.Y or (root.Position.Y - 3)
            root.AssemblyLinearVelocity = Vector3.zero
            root.CFrame = CFrame.new(root.Position.X, floorY + 0.6, root.Position.Z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
            root.Anchored = true
        elseif not down and frozen then
            frozen = false
            root.Anchored = false
            hum.PlatformStand = false
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end) -- (RUNFIX 2026-11-07: straight back on your feet after a revive)
        end
    end
    LocalPlayer:GetAttributeChangedSignal("Downed"):Connect(Downed)
    LocalPlayer.CharacterAdded:Connect(function() frozen = false end)
end)()
-- in your OWN hideout (the stash works there)
UI.InOwnHideout = function(): boolean
    local ch = LocalPlayer.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local Zm = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Zones"))
    return Zm.Kind(root.Position) == "hideout" and LocalPlayer:GetAttribute("HideoutOf") == LocalPlayer.UserId
end
-- (owner 2026-10-07: "Boss text (i.e turn away) carries over into hub if you leave") boss screen text belongs to the
-- fight: out of a dungeon (no run, not in the dungeon band) the boss warnings, banners and flashes are cleared
;(function()
    local Zones = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Zones"))
    local function ClearBossText()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        local w = pg:FindFirstChild("ArchonWarning")
        if w then w:Destroy() end
        local b = pg:FindFirstChild("BossBanner") -- (rebuilt on each banner)
        if b then for _, c in ipairs(b:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end end -- (keeps its InterfaceScale)
        local f = pg:FindFirstChild("BossFlash")
        local ff = f and f:FindFirstChild("F")
        if ff then ff.BackgroundTransparency = 1 end
    end
    local acc = 0
    RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < 0.3 then return end
        acc = 0
        if LocalPlayer:GetAttribute("RunId") then return end
        local ch = LocalPlayer.Character
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if root and Zones.Kind(root.Position) ~= "dungeon" then ClearBossText() end
    end)
end)()
-- the dungeon's entry room, by this client's OWN position (the server's SafeZone attribute lags a tick behind: walking out
-- you couldn't shoot for a moment). Attacks are locked only while the server says safe AND you're still in the room.
;(function()
    local SAFE_Z = DungeonGeneratorShared.GetChamberLayout(false).CorridorAStart
    UI.InSafeRoom = function(): boolean
        if not LocalPlayer:GetAttribute("SafeZone") then return false end
        local ch = LocalPlayer.Character
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if not root then return true end
        local z = root.Position.Z
        return z > 450 and z < SAFE_Z
    end
end)()


-- Forward declarations: assigned inside BuildHUD() but used by code outside it
local ShowToast
local UpdateWeaponHUD
local RebuildViewmodelForWeapon
local PromptBetterWeapon
local AdvanceNextFloor
DungeonClient.SetOpt("Toast", function(t) if ShowToast then ShowToast(t) end end) -- (merchant messages; ShowToast is set in BuildHUD)
-- (UPDATE 7 encounters: a landed pull's weight toward hit goals -- slow guns count more, 8 / fire rate, 1..6)
DungeonClient.SetOpt("ShotWeight", function()
    local w = clientState and clientState.EquippedWeapon
    local base = w and ItemData.BaseWeapons[w.BaseId]
    local rate = base and base.BaseFireRate or 8
    return math.clamp(8 / math.max(0.5, rate), 1, 6)
end)
local ReturnFromVictory: () -> ()
local nextFloorReady = false -- set when the floor is cleared; the portal's [E] prompt advances
local RequestExitToHub
local EquipPendingWeapon
local currentRaidBiome, currentRaidDiff, currentRaidFloor
local chL, chR, chT, chB
-- Client-side enemy look preferences (Settings > Enemies), applied by the ENEMY VISUALS manager below.
local EnemyVisuals = {
    Outline = true, OutlineColor = "Contrast", ThroughWalls = false, Fill = "Subtle",
    Brightness = "Normal", WeakSpotGlow = true, HealthBars = true,
}
local RefreshEnemyVisuals: () -> () = function() end

-- ==================== [HUD CHROME: shared panel styling so HUD/menu panels stop looking like flat placeholders] ====================
-- Declared at file scope (not inside BuildHUD) so both BuildHUD and the later menu-building code
-- (inventory, shop, forge, arena, settings, index panels) can reuse the same chrome helpers.
local function ApplyPanelChrome(frame: Frame, accentColor: Color3?, cornerRadius: number?, noStroke: boolean?)
    -- (Update 5 UI pass: the icon look -- square slab, ONE hard facet over the slab's own colour, a heavy ink edge, the
    -- panel's colour as a block down its left edge. It was a coloured hairline + a soft translucent white wash.)
    frame.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, math.min(cornerRadius or 8, 2)) -- (square slabs)
    corner.Parent = frame

    -- (UI CLEAN 2026-10-28: flat -- a hairline edge, a 2 px colour edge down the left when asked, no facet / gradient)
    if not noStroke then UIStyle.Stroke(UIStyle.Colors.Line, 1).Parent = frame end
    if accentColor then
        local block = Instance.new("Frame")
        block.Name = "Block"
        block.BackgroundColor3 = accentColor
        block.BorderSizePixel = 0
        block.Size = UDim2.new(0, 2, 1, 0)
        block.ZIndex = frame.ZIndex
        block:SetAttribute("Skinned", true)
        block.Parent = frame
    end
end

local function RoundCorners(inst: Instance, radius: number?)
    local c = Instance.new("UICorner")
    local r = radius or 6
    c.CornerRadius = UDim.new(0, (r >= 40) and r or math.min(r, 2)) -- (Mega-City: square, unless it's meant to be round)
    c.Parent = inst
end

-- ==================== [CORE HUD BUILDER] ====================
local function BuildHUD()
    -- Pixel-Perfect Centered Crosshair
    UI.crosshair = Instance.new("Frame")
    UI.crosshair.Name = "Crosshair"
    UI.crosshair.Size = UDim2.new(0, 4, 0, 4)
    UI.crosshair.Position = UDim2.new(0.5, -2, 0.5, -2)
    UI.crosshair.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    UI.crosshair.BorderSizePixel = 0
    UI.crosshair.Parent = hudGui

    chL = Instance.new("Frame")
    chL.Size = UDim2.new(0, 6, 0, 2); chL.Position = UDim2.new(0.5, -10, 0.5, -1); chL.BackgroundColor3 = Color3.fromRGB(0, 255, 255); chL.BorderSizePixel = 0; chL.Parent = hudGui
    chR = Instance.new("Frame")
    chR.Size = UDim2.new(0, 6, 0, 2); chR.Position = UDim2.new(0.5, 4, 0.5, -1); chR.BackgroundColor3 = Color3.fromRGB(0, 255, 255); chR.BorderSizePixel = 0; chR.Parent = hudGui
    chT = Instance.new("Frame")
    chT.Size = UDim2.new(0, 2, 0, 6); chT.Position = UDim2.new(0.5, -1, 0.5, -10); chT.BackgroundColor3 = Color3.fromRGB(0, 255, 255); chT.BorderSizePixel = 0; chT.Parent = hudGui
    chB = Instance.new("Frame")
    chB.Size = UDim2.new(0, 2, 0, 6); chB.Position = UDim2.new(0.5, -1, 0.5, 4); chB.BackgroundColor3 = Color3.fromRGB(0, 255, 255); chB.BorderSizePixel = 0; chB.Parent = hudGui

    -- Hitmarker
    UI.hitmarker = Instance.new("Frame")
    UI.hitmarker.Name = "Hitmarker"
    UI.hitmarker.Size = UDim2.new(0, 20, 0, 20)
    UI.hitmarker.Position = UDim2.new(0.5, -10, 0.5, -10)
    UI.hitmarker.BackgroundTransparency = 1
    UI.hitmarker.Visible = false
    UI.hitmarker.Parent = hudGui

    for i = 1, 4 do
        local line = Instance.new("Frame")
        line.Size = UDim2.new(0, 6, 0, 2)
        line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        line.BorderSizePixel = 0
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Rotation = 45 + (i - 1) * 90
        line.Position = UDim2.new(0.5, math.cos(math.rad(45 + (i - 1) * 90)) * 9, 0.5, math.sin(math.rad(45 + (i - 1) * 90)) * 9)
        line.Parent = UI.hitmarker
    end

    UI.streakLabel = Instance.new("TextLabel")
    UI.streakLabel.Name = "StreakLabel"
    UI.streakLabel.Size = UDim2.new(0, 440, 0, 30)
    -- (Update 5: under the crosshair KEEP-OUT -- it sat 32 px below the centre, inside the 44 px square that stays clear)
    UI.streakLabel.Position = UDim2.new(0.5, -220, 0.5, 84)
    UI.streakLabel.TextStrokeTransparency = 0.5
    UI.streakLabel.BackgroundTransparency = 1
    UI.streakLabel.Font = Enum.Font.GothamBold
    UI.streakLabel.TextSize = 18
    UI.streakLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    UI.streakLabel.Text = "FOCUS STREAK: x0"
    UI.streakLabel.Parent = hudGui

    -- ==================== [BOTTOM-LEFT HUD STACK: LEVEL, HEALTH, WEAPON] ====================
    -- (Update 5 UI pass, owner: "it should feel far more professional and intentional") ONE column, one width, one gap:
    -- level card / health bar / weapon card, 16 px from the left and bottom edges (the top-left corner is Roblox's own
    -- menu / chat buttons). UI.HudStack has the numbers; the lives hearts / shift-lock hint and the status + build chips
    -- stack above it (HS.TopY). (0.97: the health bar lives here so it doesn't cover the viewmodel's fists.)
    UI.HudStack = { X = 16, W = 400, Gap = 8, Bottom = 16, WeaponH = 100, HealthH = 44, LevelH = 38 }
    local HS = UI.HudStack
    HS.HealthY = -(HS.Bottom + HS.WeaponH + HS.Gap) -- bottom edge of the health bar
    HS.LevelY = HS.HealthY - HS.HealthH - HS.Gap -- bottom edge of the level card
    HS.TopY = HS.LevelY - HS.LevelH - HS.Gap -- bottom edge of whatever sits above the stack
    local HUD_C = UIStyle.Colors

    UI.levelFrame = Instance.new("Frame")
    UI.levelFrame.Name = "LevelHUD"
    UI.levelFrame.AnchorPoint = Vector2.new(0, 1)
    UI.levelFrame.Size = UDim2.new(0, HS.W, 0, HS.LevelH)
    UI.levelFrame.Position = UDim2.new(0, HS.X, 1, HS.LevelY)
    UI.levelFrame.BackgroundColor3 = HUD_C.Bg0
    UI.levelFrame.BackgroundTransparency = 0.08
    UI.levelFrame.ZIndex = 5
    UI.levelFrame.Parent = hudGui
    ApplyPanelChrome(UI.levelFrame, nil, 2)

    -- the level number on an accent block (the icons' lit face + ink), then title / XP readout over a thin XP bar
    UI.lvlBadge = Instance.new("TextLabel")
    UI.lvlBadge.Name = "LevelBadge"
    UI.lvlBadge.Size = UDim2.new(0, 48, 1, 0)
    UI.lvlBadge.BackgroundColor3 = HUD_C.Bg1 -- (UI v4: a dark block; a UIGradient tints TEXT too, so the facet stays near white)
    UI.lvlBadge.BorderSizePixel = 0
    UI.lvlBadge.Font = Enum.Font.GothamBlack
    UI.lvlBadge.TextSize = 20
    UI.lvlBadge.TextColor3 = HUD_C.Accent -- (UI v4: the number in neon on a dark block; the XP fill is the card's one neon)
    UI.lvlBadge.Text = "1"
    UI.lvlBadge.ZIndex = 6
    UI.lvlBadge:SetAttribute("TypeRole", "Accent")
    UI.lvlBadge:SetAttribute("Skinned", true)
    UI.lvlBadge.Parent = UI.levelFrame
    UI.lvlBadgeGrad = UIStyle.FacetGrad(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 225))
    UI.lvlBadgeGrad.Parent = UI.lvlBadge
    local lvlCap = Instance.new("UITextSizeConstraint"); lvlCap.MaxTextSize = 20; lvlCap.MinTextSize = 13; lvlCap.Parent = UI.lvlBadge
    UI.lvlBadge.TextScaled = true

    UI.titleHeaderLbl = Instance.new("TextLabel")
    UI.titleHeaderLbl.Name = "TitleHeaderLbl"
    UI.titleHeaderLbl.Size = UDim2.new(0.55, -60, 0, 18)
    UI.titleHeaderLbl.Position = UDim2.new(0, 58, 0, 4)
    UI.titleHeaderLbl.BackgroundTransparency = 1
    UI.titleHeaderLbl.Font = Enum.Font.GothamBlack
    UI.titleHeaderLbl.TextSize = 14
    UI.titleHeaderLbl.TextXAlignment = Enum.TextXAlignment.Left
    UI.titleHeaderLbl.TextTruncate = Enum.TextTruncate.AtEnd
    UI.titleHeaderLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
    UI.titleHeaderLbl.Text = "ROOKIE"
    UI.titleHeaderLbl.ZIndex = 6
    UI.titleHeaderLbl:SetAttribute("TypeRole", "Label")
    UI.titleHeaderLbl:SetAttribute("Skinned", true)
    UI.titleHeaderLbl.Parent = UI.levelFrame
    UI.titleHeaderLbl.TextStrokeTransparency = 1

    UI.lvlLabel = Instance.new("TextLabel") -- (the XP readout; "LEVEL UP" shows here for a moment)
    UI.lvlLabel.Name = "XpLabel"
    UI.lvlLabel.AnchorPoint = Vector2.new(1, 0)
    UI.lvlLabel.Size = UDim2.new(0.45, -10, 0, 18)
    UI.lvlLabel.Position = UDim2.new(1, -10, 0, 4)
    UI.lvlLabel.BackgroundTransparency = 1
    UI.lvlLabel.Font = Enum.Font.GothamBold
    UI.lvlLabel.TextSize = 13
    UI.lvlLabel.TextXAlignment = Enum.TextXAlignment.Right
    UI.lvlLabel.TextTruncate = Enum.TextTruncate.AtEnd
    UI.lvlLabel.TextColor3 = HUD_C.Sub
    UI.lvlLabel.Text = "0 / 150 XP"
    UI.lvlLabel.ZIndex = 6
    UI.lvlLabel:SetAttribute("Skinned", true)
    UI.lvlLabel.Parent = UI.levelFrame

    local xpBg = Instance.new("Frame")
    xpBg.Name = "XpTrack"
    xpBg.Size = UDim2.new(1, -68, 0, 6)
    xpBg.Position = UDim2.new(0, 58, 1, -12)
    xpBg.BackgroundColor3 = HUD_C.Well
    xpBg.BorderSizePixel = 0
    xpBg.ZIndex = 6
    xpBg:SetAttribute("Skinned", true)
    xpBg.Parent = UI.levelFrame

    UI.xpFill = Instance.new("Frame")
    UI.xpFill.Name = "XpFill"
    UI.xpFill.Size = UDim2.new(0, 0, 1, 0)
    UI.xpFill.BackgroundColor3 = HUD_C.Accent
    UI.xpFill.BorderSizePixel = 0
    UI.xpFill.ZIndex = 6
    UI.xpFill:SetAttribute("Skinned", true)
    UI.xpFill.Parent = xpBg

    -- HEALTH BAR (2026-10-05, owner: "move the ui or make it bigger so its more obvious when the player is using health"):
    -- big HP number on a wide bar. A white CHIP behind the fill shows the chunk a hit just took and drains after a beat;
    -- the bar shakes on hits, a damage number pops over it, it pulses under 30% (+ a LOW tag: not colour alone) and
    -- flashes green on a heal (animated by the HEALTH BAR FX block next to the HurtFX setup)
    UI.healthFrame = Instance.new("Frame")
    UI.healthFrame.Name = "HealthHUD"
    UI.healthFrame.AnchorPoint = Vector2.new(0, 1)
    UI.healthFrame.Size = UDim2.new(0, HS.W, 0, HS.HealthH)
    UI.healthFrame.Position = UDim2.new(0, HS.X, 1, HS.HealthY)
    UI.healthFrame.BackgroundColor3 = HUD_C.Bg0
    UI.healthFrame.BackgroundTransparency = 0.08
    UI.healthFrame.BorderSizePixel = 0
    UI.healthFrame.ZIndex = 5
    UI.healthFrame.Parent = hudGui
    ApplyPanelChrome(UI.healthFrame, nil, 2, true)
    UI.hpStroke = UIStyle.InkEdge(2) -- (the bar's edge: ink, white on a hit, red while low)
    UI.hpStroke.Parent = UI.healthFrame

    local hpBg = Instance.new("Frame")
    hpBg.Name = "HpTrack"
    hpBg.Size = UDim2.new(1, -8, 1, -8)
    hpBg.Position = UDim2.new(0, 4, 0, 4)
    hpBg.BackgroundColor3 = HUD_C.Well
    hpBg.BorderSizePixel = 0
    hpBg.ClipsDescendants = true
    hpBg.ZIndex = 5
    hpBg:SetAttribute("Skinned", true)
    hpBg.Parent = UI.healthFrame

    UI.hpChip = Instance.new("Frame")
    UI.hpChip.Name = "HpChip"
    UI.hpChip.Size = UDim2.new(1, 0, 1, 0)
    UI.hpChip.BackgroundColor3 = Color3.fromRGB(255, 236, 214)
    UI.hpChip.BorderSizePixel = 0
    UI.hpChip.ZIndex = 5
    UI.hpChip:SetAttribute("Skinned", true)
    UI.hpChip.Parent = hpBg

    UI.hpFill = Instance.new("Frame")
    UI.hpFill.Name = "HpFill"
    UI.hpFill.Size = UDim2.new(1, 0, 1, 0)
    UI.hpFill.BackgroundColor3 = Color3.fromRGB(196, 38, 44) -- (a deep signal red on the gunmetal slab)
    UI.hpFill.BorderSizePixel = 0
    UI.hpFill.ZIndex = 6
    UI.hpFill:SetAttribute("Skinned", true)
    UI.hpFill.Parent = hpBg
    -- the icons' lit facet: a hard lighter band along the top of the fill
    local sheen = Instance.new("Frame")
    sheen.Name = "Facet"
    sheen.BackgroundColor3 = Color3.new(1, 1, 1)
    sheen.BackgroundTransparency = 0.86
    sheen.BorderSizePixel = 0
    sheen.Size = UDim2.new(1, 0, 0.4, 0)
    sheen.ZIndex = 6
    sheen:SetAttribute("Skinned", true)
    sheen.Parent = UI.hpFill

    UI.hpLabel = Instance.new("TextLabel")
    UI.hpLabel.Name = "HpLabel"
    UI.hpLabel.Size = UDim2.new(1, -24, 1, 0)
    UI.hpLabel.Position = UDim2.new(0, 14, 0, 0)
    UI.hpLabel.BackgroundTransparency = 1
    UI.hpLabel.Font = Enum.Font.GothamBlack
    UI.hpLabel.RichText = true
    UI.hpLabel.TextSize = 24
    UI.hpLabel.TextXAlignment = Enum.TextXAlignment.Left
    UI.hpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    UI.hpLabel.TextStrokeTransparency = 0.55
    UI.hpLabel.Text = "150"
    UI.hpLabel.ZIndex = 7
    UI.hpLabel:SetAttribute("TypeRole", "Accent")
    UI.hpLabel:SetAttribute("Skinned", true)
    UI.hpLabel.Parent = UI.healthFrame
    UI.hpArmor = Instance.new("TextLabel")
    UI.hpArmor.Name = "ArmorLabel"
    UI.hpArmor.Size = UDim2.new(1, -24, 1, 0)
    UI.hpArmor.Position = UDim2.new(0, 10, 0, 0)
    UI.hpArmor.BackgroundTransparency = 1
    UI.hpArmor.Font = Enum.Font.GothamBold
    UI.hpArmor.TextSize = 14
    UI.hpArmor.TextXAlignment = Enum.TextXAlignment.Right
    UI.hpArmor.TextColor3 = Color3.fromRGB(220, 224, 232)
    UI.hpArmor.TextStrokeTransparency = 0.55
    UI.hpArmor.Text = "ARMOR 0"
    UI.hpArmor.ZIndex = 7
    UI.hpArmor:SetAttribute("TypeRole", "Accent")
    UI.hpArmor:SetAttribute("Skinned", true)
    UI.hpArmor.Parent = UI.healthFrame

    -- Dungeon Raid Status Banner & NEXT FLOOR KEYBIND [N]
    UI.RunHud = UI.RunHud or require(sharedFolder:WaitForChild("RunHud")) -- (UI CLEAN R-C: the run HUD plate / type helpers)
    UI.raidBanner = Instance.new("Frame")
    UI.raidBanner.Name = "RaidBanner"
    UI.raidBanner.Size = UDim2.new(0, 660, 0, 34)
    UI.raidBanner.AnchorPoint = Vector2.new(0.5, 0)
    UI.raidBanner.Position = UDim2.new(0.5, 0, 0, 64)
    UI.raidBanner.Visible = false
    UI.raidBanner.Parent = hudGui
    UI.RunHud.Plate(UI.raidBanner) -- (UI CLEAN R-C: the one HUD plate -- no gold edge bar, no hairline box)

    UI.raidLabel = Instance.new("TextLabel")
    UI.raidLabel.Size = UDim2.new(1, -165, 1, 0)
    UI.raidLabel.TextTruncate = Enum.TextTruncate.AtEnd
    UI.raidLabel.Position = UDim2.new(0, 14, 0, 0)
    UI.raidLabel.BackgroundTransparency = 1
    UI.raidLabel.TextXAlignment = Enum.TextXAlignment.Left
    UI.raidLabel.Text = "IN A RUN"
    UI.raidLabel.Parent = UI.raidBanner
    UI.RunHud.Role(UI.raidLabel, "SectionHead") -- (display caps, Text)
    UI.raidLabel.TextSize = 18

    UI.btnReturnHub = Instance.new("TextButton")
    UI.btnReturnHub.AnchorPoint = Vector2.new(1, 0)
    UI.btnReturnHub.AutomaticSize = Enum.AutomaticSize.X -- (grows left for "n LEFT ON GROUND! CONFIRM EXIT?")
    UI.btnReturnHub.Size = UDim2.new(0, 0, 0, 24)
    UI.btnReturnHub.Position = UDim2.new(1, -5, 0, 5)
    UI.btnReturnHub.Text = "EXIT TO HUB " .. KeyTag("ExitRun")
    UI.btnReturnHub.Parent = UI.raidBanner
    do -- (UI CLEAN R-C: a quiet secondary -- transparent, 1 px hairline, caps in Sub; the confirm state turns the words Warn)
        local b = UI.btnReturnHub
        b.BackgroundColor3 = UIStyle.Colors.Bg2; b.BackgroundTransparency = 1; b.BorderSizePixel = 0; b.AutoButtonColor = false
        b:SetAttribute("NoSkin", true); b:SetAttribute("Skinned", true)
        local st = Instance.new("UIStroke"); st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Color = UIStyle.Colors.Text; st.Transparency = 0.8; st.Thickness = 1; st.Parent = b
        UI.RunHud.Role(b, "Button", { Color = "Sub" })
        b.TextSize = 13
        UI.RunHud.Pad(b, 10, 10)
        b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.6 end)
        b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
    end

    UI.btnNextFloor = Instance.new("TextButton")
    UI.btnNextFloor.Size = UDim2.new(0, 130, 0, 26)
    UI.btnNextFloor.Position = UDim2.new(1, -265, 0, 4)
    UI.btnNextFloor.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
    UI.btnNextFloor.Font = Enum.Font.GothamBold
    UI.btnNextFloor.TextSize = 15
    UI.btnNextFloor.TextColor3 = Color3.fromRGB(255, 255, 255)
    UI.btnNextFloor.Text = "▶ NEXT FLOOR [N]"
    UI.btnNextFloor.Visible = false -- the next floor is now entered through the in-world portal ([E]); kept hidden
    UI.btnNextFloor.Parent = UI.raidBanner
    RoundCorners(UI.btnNextFloor, 6)

    currentRaidBiome = "Fire"
    currentRaidDiff = "Easy"
    currentRaidFloor = 1

    function AdvanceNextFloor(pathIndex: number?)
        if nextFloorReady then
            nextFloorReady = false
            SoundHelper.Play("Click")
            if not DungeonClient.EnterFloor(currentRaidBiome, ItemData.RunKey(currentRaidDiff, UI.runEndless), currentRaidFloor + 1, nil, pathIndex) then
                nextFloorReady = true -- server refused (shouldn't happen after a clear): let them try again
            end
            if not isAnyMenuOpen then SetMouseLocked(true) end
        end
    end

    -- EXIT TO HUB: a tap-then-confirm flow (rather than firing instantly on the first press/click) so a
    -- stray keypress or misclick mid-run can't yank you out of a dungeon. Works identically whether
    -- triggered by clicking the button or by the [J] keybind. The button itself doubles as the mouse-click
    -- path -- it's reachable because DungeonUpdate/DungeonVictory below unlock the cursor whenever combat
    -- isn't actively happening (arena cleared / dungeon complete), which is the only time this matters;
    -- during active combat the cursor stays locked for aiming and [J] is the way to back out.
    local hubConfirmArmed = false
    local hubConfirmToken = 0

    local function CancelHubConfirm()
        hubConfirmArmed = false
        UI.btnReturnHub.Text = "EXIT TO HUB " .. KeyTag("ExitRun")
        UI.btnReturnHub.TextColor3 = UIStyle.Colors.Sub
    end

    function RequestExitToHub()
        if not UI.raidBanner.Visible then return end
        SoundHelper.Play("Click")
        if hubConfirmArmed then
            CancelHubConfirm()
            TeleportClient(CFrame.lookAt(Vector3.new(0, 6, 24), Vector3.new(0, 6, 0)))
            Remotes.GetEvent("TeleportPlayer"):FireServer("Hub")
            UI.raidBanner.Visible = false
            SetMouseLocked(true)
        else
            hubConfirmArmed = true
            hubConfirmToken += 1
            local myToken = hubConfirmToken
            local left = UI.LootLeft and UI.LootLeft() or 0 -- (QOL L1: say what's still on the ground)
            UI.btnReturnHub.Text = (left > 0 and (left .. " LEFT ON GROUND! ") or "") .. "CONFIRM EXIT? " .. KeyTag("ExitRun")
            UI.btnReturnHub.TextColor3 = UIStyle.Colors.Warn -- (UI CLEAN R-C: the words, not a yellow slab)
            task.delay(4, function()
                if hubConfirmArmed and myToken == hubConfirmToken then
                    CancelHubConfirm()
                end
            end)
        end
    end

    Remotes.GetEvent("PortalNextFloor").OnClientEvent:Connect(AdvanceNextFloor)
    DungeonGeneratorShared.OnPortal = function(pathIndex) AdvanceNextFloor(pathIndex) end -- the portal is built on this client
    DungeonGeneratorShared.OnRevisit = function(dir) -- BACK PORTAL
        SoundHelper.Play("Click")
        DungeonClient.Revisit(dir)
        if not isAnyMenuOpen then SetMouseLocked(true) end
    end
    DungeonClient.OnFloorBuilt = function(info)
        currentRaidBiome, currentRaidDiff, currentRaidFloor = info.Biome, info.Difficulty, info.FloorNumber
        UI.runEndless = info.Endless == true
        nextFloorReady = false
        -- (0.61f, owner: "portals break when going back a floor and then coming back to the current floor to continue"):
        -- back on a floor you had already cleared, no new clear ever fires -- its exit portals are live straight away
        local rf = LocalPlayer.PlayerGui:FindFirstChild("AimRngRun")
        if rf and rf:GetAttribute("ReturnCleared") == true and (rf:GetAttribute("Revisit") or 0) == 0 then nextFloorReady = true end
    end
    UI.btnReturnHub.MouseButton1Click:Connect(RequestExitToHub)

    -- BACK TO HUB, ANYWHERE (0.80, owner: "Add double hitting J to allow back to hub in ANY mode (including pvp)"): tap the
    -- ExitRun key twice within DOUBLE_TAP seconds and you're sent to the hub from wherever you are -- a solo / party run
    -- or map, an Aim Trial, a duel (forfeit; the server brings you back after the result screen), spectating, a hideout,
    -- the Bazaar, the training grounds. The first tap only shows a hint.
    local DOUBLE_TAP = 0.6
    local lastExitTap = 0
    local HUB_CF = CFrame.lookAt(Vector3.new(0, 6, 24), Vector3.new(0, 6, -40)) -- (the teleport menu's "Center")
    local function GoHubNow(closeAll: any)
        SoundHelper.Play("Click")
        if closeAll then closeAll() end -- (CloseAllMenus is defined further down: the key handler passes it)
        if LocalPlayer:GetAttribute("PvpDuel") then
            task.spawn(function() pcall(function() Remotes.GetFunction("PvpAction"):InvokeServer("Forfeit") end) end)
            ShowToast("Left the duel (forfeit). Back to the hub after the result.")
            return
        end
        if UI.watching or LocalPlayer:GetAttribute("WatchUid") then
            task.spawn(function() pcall(function() Remotes.GetFunction("SpectateAction"):InvokeServer("Stop") end) end)
        end
        if UI.TrialRunner and UI.TrialRunner.IsRunning() then
            UI.TrialRunner.Abort("quit")
            task.delay(0.5, function() TeleportClient(HUB_CF) end) -- (after the trial has cleaned up)
            SetMouseLocked(true)
            return
        end
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root and UI.Zones.Kind((root :: BasePart).Position) == "hideout" then
            task.spawn(function() pcall(function() Remotes.GetFunction("HideoutAction"):InvokeServer("Leave", "Stay") end) end)
            if UI.ShowHub then UI.ShowHub() end
        end
        CancelHubConfirm()
        UI.raidBanner.Visible = false
        TeleportClient(HUB_CF)
        Remotes.GetEvent("TeleportPlayer"):FireServer("Hub") -- (ends a solo / party run on the server; harmless elsewhere)
        SetMouseLocked(true)
    end
    function UI.ExitAnywhere(closeAll: any)
        local now = os.clock()
        if now - lastExitTap > DOUBLE_TAP then
            lastExitTap = now
            ShowToast("Press " .. KeyTag("ExitRun") .. " again to go back to the hub")
            return
        end
        lastExitTap = 0
        if UI.LootGate and not UI.LootGate("double tap " .. KeyTag("ExitRun") .. " again to leave") then return end -- (QOL L1)
        GoHubNow(closeAll)
    end

    -- Live Currency Counter Widget (Top Right)
    -- Currency chips (top right): one rounded pill per currency, like the Forge / Dungeons windows.
    UI.currencyHUD = Instance.new("Frame")
    UI.currencyHUD.Name = "CurrencyHUD"
    UI.currencyHUD.AnchorPoint = Vector2.new(1, 0)
    UI.currencyHUD.Size = UDim2.new(0, 0, 0, 36)
    UI.currencyHUD.AutomaticSize = Enum.AutomaticSize.X
    UI.currencyHUD.Position = UDim2.new(1, -UIStyle.MARGIN, 0, 20) -- (UI CLEAN P5: the screen grid)
    UI.currencyHUD.BackgroundTransparency = 1
    UI.currencyHUD:SetAttribute("NoSkin", true)
    UI.currencyHUD.Parent = hudGui
    -- (UI CLEAN R-C: one plate, icon + display number pairs -- no box per currency; AimRngShared/RunHud)
    UI.RunHud = UI.RunHud or require(sharedFolder:WaitForChild("RunHud"))
    UI.currencyChips = UI.RunHud.Currency(UI.currencyHUD, {
        { Key = "Gold", Icon = "cur_gold", Color = UIStyle.Colors.Gold },
        { Key = "Scrap", Icon = "cur_scrap", Color = Color3.fromRGB(205, 210, 225) },
        { Key = "Alloy", Icon = "cur_alloy", Color = Color3.fromRGB(120, 200, 255) },
        { Key = "Prism", Icon = "cur_prism", Color = Color3.fromRGB(200, 130, 255) },
        { Key = "SP", Icon = "cur_sp", Color = UIStyle.Colors.Good },
    })

    -- Top Bar Navigation Buttons. Auto-sized by a list layout: each button grows to fit its label and the
    -- bar grows to fit its buttons, so nothing can spill outside the box (SETTINGS used to).
    UI.navBar = Instance.new("Frame")
    UI.navBar.AutomaticSize = Enum.AutomaticSize.X
    UI.navBar.Size = UDim2.new(0, 0, 0, 38)
    UI.navBar.AnchorPoint = Vector2.new(0.5, 0)
    UI.navBar.Position = UDim2.new(0.5, 0, 0, 18)
    UI.navBar.BackgroundColor3 = Color3.fromRGB(18, 24, 34)
    UI.navBar.BorderSizePixel = 1
    UI.navBar.BorderColor3 = Color3.fromRGB(55, 70, 95)
    UI.navBar.Parent = hudGui
    ApplyPanelChrome(UI.navBar, Color3.fromRGB(90, 140, 220), 10)
    local navList = Instance.new("UIListLayout")
    navList.FillDirection = Enum.FillDirection.Horizontal
    navList.VerticalAlignment = Enum.VerticalAlignment.Center
    navList.SortOrder = Enum.SortOrder.LayoutOrder
    navList.Padding = UDim.new(0, 4)
    navList.Parent = UI.navBar
    local navPad = Instance.new("UIPadding")
    navPad.PaddingLeft = UDim.new(0, 4)
    navPad.PaddingRight = UDim.new(0, 4)
    navPad.Parent = UI.navBar

    local navOrder = 0
    local function CreateNavBtn(title: string, hotkey: string, _posX: number?, _w: number?): TextButton
        navOrder += 1
        local btn = Instance.new("TextButton")
        btn.AutomaticSize = Enum.AutomaticSize.X
        btn.Size = UDim2.new(0, 0, 1, -8)
        btn.LayoutOrder = navOrder
        btn.BackgroundColor3 = Color3.fromRGB(30, 40, 55)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.TextColor3 = Color3.fromRGB(240, 240, 240)
        btn.Text = hotkey .. " " .. title
        btn.Parent = UI.navBar
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 9)
        pad.PaddingRight = UDim.new(0, 9)
        pad.Parent = btn
        RoundCorners(btn, 6)
        return btn
    end

    UI.btnRoll = CreateNavBtn("FORGE", "[F]")
    UI.btnTree = CreateNavBtn("TREE", "[P]")
    UI.btnInv = CreateNavBtn("ARSENAL", "[TAB]")
    UI.btnShop = CreateNavBtn("SHOP", "[B]")
    UI.btnUpg = CreateNavBtn("UPGRADE", "[U]")
    UI.btnArmory = CreateNavBtn("ARMORY", "[G]")
    UI.btnDung = CreateNavBtn("ARENA", "[H]")
    UI.btnIndex = CreateNavBtn("INDEX", "[K]")
    UI.btnChall = CreateNavBtn("CHALLENGES", "[L]")
    UI.btnSet = CreateNavBtn("SETTINGS", "[M]")

    UI.btnTree.BackgroundColor3 = Color3.fromRGB(60, 190, 110)
    UI.btnInv.BackgroundColor3 = Color3.fromRGB(50, 130, 230)
    UI.btnUpg.BackgroundColor3 = Color3.fromRGB(230, 80, 90)
    UI.btnSet.BackgroundColor3 = Color3.fromRGB(110, 120, 150)
    UI.btnRoll.BackgroundColor3 = Color3.fromRGB(210, 140, 25)
    UI.btnShop.BackgroundColor3 = Color3.fromRGB(40, 150, 90)
    UI.btnArmory.BackgroundColor3 = Color3.fromRGB(220, 110, 30)
    UI.btnDung.BackgroundColor3 = Color3.fromRGB(150, 40, 220)
    UI.btnIndex.BackgroundColor3 = Color3.fromRGB(0, 160, 210)
    UI.btnChall.BackgroundColor3 = Color3.fromRGB(240, 120, 30)
    UI.navBar.Visible = false -- replaced by the side dock (Stash / Teleport / Settings, see TELEPORT MENU)

    -- Fullscreen Sniper/DMR Scope Overlay: a near-opaque vignette (blocks peripheral vision like a real
    -- scope) with a round, mostly-clear "lens" circle and a mil-dot reticle drawn inside it.
    -- IMPORTANT: the vignette is built from four bars framing the lens, NOT one full-screen dark panel --
    -- Roblox GuiObjects don't punch a transparent "hole" through a parent for a child to show through;
    -- a child frame just draws on top of whatever its parent already rendered. A single near-opaque
    -- full-screen panel made the "clear" lens sitting on top of it nearly as dark as the vignette
    -- around it, since the almost-opaque black was still there underneath the lens the whole time --
    -- that's what made every sniper scope look like looking through a welding mask. The root container
    -- below is fully invisible on its own; only the four bars (and the lens itself) ever draw anything,
    -- so the lens area has nothing opaque behind it at all.
    UI.sniperScopeOverlay = Instance.new("Frame")
    UI.sniperScopeOverlay.Name = "SniperScopeOverlay"
    UI.sniperScopeOverlay.Size = UDim2.new(1, 0, 1, 0)
    UI.sniperScopeOverlay.BackgroundTransparency = 1
    UI.sniperScopeOverlay.Visible = false
    UI.sniperScopeOverlay.Parent = hudGui

    local LENS_RADIUS_PX = 190 -- half of the 380x380 lens below -- keep these two in sync
    local vignetteColor = Color3.fromRGB(0, 0, 0)
    local vignetteTransparency = 0.06 -- near-opaque, same "blocks peripheral vision" darkness as before

    local vigTop = Instance.new("Frame")
    vigTop.Name = "VignetteTop"
    vigTop.Position = UDim2.new(0, 0, 0, 0)
    vigTop.Size = UDim2.new(1, 0, 0.5, -LENS_RADIUS_PX)
    vigTop.BackgroundColor3 = vignetteColor
    vigTop.BackgroundTransparency = vignetteTransparency
    vigTop.BorderSizePixel = 0
    vigTop.Parent = UI.sniperScopeOverlay

    local vigBottom = Instance.new("Frame")
    vigBottom.Name = "VignetteBottom"
    vigBottom.Position = UDim2.new(0, 0, 0.5, LENS_RADIUS_PX)
    vigBottom.Size = UDim2.new(1, 0, 0.5, -LENS_RADIUS_PX)
    vigBottom.BackgroundColor3 = vignetteColor
    vigBottom.BackgroundTransparency = vignetteTransparency
    vigBottom.BorderSizePixel = 0
    vigBottom.Parent = UI.sniperScopeOverlay

    local vigLeft = Instance.new("Frame")
    vigLeft.Name = "VignetteLeft"
    vigLeft.Position = UDim2.new(0, 0, 0.5, -LENS_RADIUS_PX)
    vigLeft.Size = UDim2.new(0.5, -LENS_RADIUS_PX, 0, LENS_RADIUS_PX * 2)
    vigLeft.BackgroundColor3 = vignetteColor
    vigLeft.BackgroundTransparency = vignetteTransparency
    vigLeft.BorderSizePixel = 0
    vigLeft.Parent = UI.sniperScopeOverlay

    local vigRight = Instance.new("Frame")
    vigRight.Name = "VignetteRight"
    vigRight.Position = UDim2.new(0.5, LENS_RADIUS_PX, 0.5, -LENS_RADIUS_PX)
    vigRight.Size = UDim2.new(0.5, -LENS_RADIUS_PX, 0, LENS_RADIUS_PX * 2)
    vigRight.BackgroundColor3 = vignetteColor
    vigRight.BackgroundTransparency = vignetteTransparency
    vigRight.BorderSizePixel = 0
    vigRight.Parent = UI.sniperScopeOverlay

    local scopeCenter = Instance.new("Frame")
    scopeCenter.Name = "Lens"
    scopeCenter.Size = UDim2.new(0, 380, 0, 380)
    scopeCenter.Position = UDim2.new(0.5, -190, 0.5, -190)
    scopeCenter.BackgroundColor3 = Color3.fromRGB(5, 10, 15)
    scopeCenter.BackgroundTransparency = 0.94
    scopeCenter.BorderSizePixel = 3
    scopeCenter.BorderColor3 = Color3.fromRGB(0, 255, 230)
    scopeCenter.Parent = UI.sniperScopeOverlay

    local lensCorner = Instance.new("UICorner")
    lensCorner.CornerRadius = UDim.new(1, 0) -- round lens, not a square
    lensCorner.Parent = scopeCenter

    UI.scopeLineH = Instance.new("Frame")
    UI.scopeLineH.Size = UDim2.new(1, 0, 0, 2)
    UI.scopeLineH.Position = UDim2.new(0, 0, 0.5, -1)
    UI.scopeLineH.BackgroundColor3 = Color3.fromRGB(0, 255, 230)
    UI.scopeLineH.BorderSizePixel = 0
    UI.scopeLineH.Parent = scopeCenter

    UI.scopeLineV = Instance.new("Frame")
    UI.scopeLineV.Size = UDim2.new(0, 2, 1, 0)
    UI.scopeLineV.Position = UDim2.new(0.5, -1, 0, 0)
    UI.scopeLineV.BackgroundColor3 = Color3.fromRGB(0, 255, 230)
    UI.scopeLineV.BorderSizePixel = 0
    UI.scopeLineV.Parent = scopeCenter

    -- Mil-dot ticks along both crosshair arms, mirrored on each side of center
    for _, offsetPx in ipairs({ 45, 90, 135 }) do
        for _, sign in ipairs({ -1, 1 }) do
            local tickH = Instance.new("Frame")
            tickH.Size = UDim2.new(0, 2, 0, 14)
            tickH.Position = UDim2.new(0.5, sign * offsetPx - 1, 0.5, -7)
            tickH.BackgroundColor3 = Color3.fromRGB(0, 255, 230)
            tickH.BorderSizePixel = 0
            tickH.Parent = scopeCenter

            local tickV = Instance.new("Frame")
            tickV.Size = UDim2.new(0, 14, 0, 2)
            tickV.Position = UDim2.new(0.5, -7, 0.5, sign * offsetPx - 1)
            tickV.BackgroundColor3 = Color3.fromRGB(0, 255, 230)
            tickV.BorderSizePixel = 0
            tickV.Parent = scopeCenter
        end
    end

    -- WEAPON CARD (bottom of the left stack: in the bottom-right it covered the gun hand and glove skins). (Update 5)
    -- name in its rarity colour with the rarity's SHAPE (colour-blind safe), one type line, one stats line, the trait
    -- line when there is one; the ammo count big on the right over its key hint; a thin ammo bar along the bottom.
    UI.weaponCard = Instance.new("Frame")
    UI.weaponCard.Name = "WeaponCard"
    UI.weaponCard.AnchorPoint = Vector2.new(0, 1)
    UI.weaponCard.Size = UDim2.new(0, HS.W, 0, HS.WeaponH)
    UI.weaponCard.Position = UDim2.new(0, HS.X, 1, -HS.Bottom)
    UI.weaponCard.BackgroundColor3 = HUD_C.Bg0
    UI.weaponCard.BackgroundTransparency = 0.08
    UI.weaponCard.BorderSizePixel = 0
    UI.weaponCard.Parent = hudGui
    ApplyPanelChrome(UI.weaponCard, Color3.fromRGB(88, 90, 98), 2)
    UI.weaponBlock = UI.weaponCard:FindFirstChild("Block") -- (the left edge takes the weapon's rarity colour)

    local function CardLabel(name: string, x: number, y: number, w: UDim, h: number, size: number, font: Enum.Font, col: Color3, role: string?): TextLabel
        local l = Instance.new("TextLabel")
        l.Name = name
        l.Size = UDim2.new(w.Scale, w.Offset, 0, h)
        l.Position = UDim2.new(0, x, 0, y)
        l.BackgroundTransparency = 1
        l.Font = font
        l.TextSize = size
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.TextColor3 = col
        l.Text = ""
        l.ZIndex = 6
        if role then l:SetAttribute("TypeRole", role) end
        l:SetAttribute("Skinned", true)
        l.Parent = UI.weaponCard
        return l
    end
    UI.weaponNameLbl = CardLabel("WeaponName", 14, 8, UDim.new(1, -158), 24, 19, Enum.Font.GothamBlack, Color3.fromRGB(255, 255, 255), "Header")
    UI.weaponNameLbl.Text = "Loading weapon"
    UI.weaponTypeLbl = CardLabel("WeaponType", 14, 33, UDim.new(1, -158), 16, 13, Enum.Font.GothamBold, HUD_C.Sub)
    UI.weaponStatsLbl = CardLabel("WeaponStats", 14, 50, UDim.new(1, -158), 16, 13, Enum.Font.GothamBold, Color3.fromRGB(214, 218, 228))
    UI.weaponTraitLbl = CardLabel("WeaponTrait", 14, 67, UDim.new(1, -158), 16, 13, Enum.Font.GothamBold, Color3.fromRGB(255, 225, 70))

    -- the ammo block (right side): big count, the magazine under it, the key hint at the bottom
    UI.ammoContainer = Instance.new("Frame")
    UI.ammoContainer.Name = "Ammo"
    UI.ammoContainer.AnchorPoint = Vector2.new(1, 0)
    UI.ammoContainer.Size = UDim2.new(0, 136, 1, -14)
    UI.ammoContainer.Position = UDim2.new(1, -12, 0, 4)
    UI.ammoContainer.BackgroundTransparency = 1
    UI.ammoContainer:SetAttribute("Skinned", true)
    UI.ammoContainer.Parent = UI.weaponCard

    UI.ammoCounterLbl = Instance.new("TextLabel")
    UI.ammoCounterLbl.Name = "AmmoCount"
    UI.ammoCounterLbl.Size = UDim2.new(1, 0, 0, 40)
    UI.ammoCounterLbl.BackgroundTransparency = 1
    UI.ammoCounterLbl.Font = Enum.Font.GothamBlack
    UI.ammoCounterLbl.TextSize = 34
    UI.ammoCounterLbl.RichText = true
    UI.ammoCounterLbl.TextColor3 = Color3.fromRGB(240, 240, 240)
    UI.ammoCounterLbl.TextXAlignment = Enum.TextXAlignment.Right
    UI.ammoCounterLbl.Text = "18"
    UI.ammoCounterLbl.ZIndex = 6
    UI.ammoCounterLbl:SetAttribute("TypeRole", "Accent")
    UI.ammoCounterLbl:SetAttribute("Skinned", true)
    UI.ammoCounterLbl.Parent = UI.ammoContainer
    local ammoCap = Instance.new("UITextSizeConstraint"); ammoCap.MaxTextSize = 34; ammoCap.MinTextSize = 14; ammoCap.Parent = UI.ammoCounterLbl
    UI.ammoCounterLbl.TextScaled = true

    UI.ammoMagLbl = Instance.new("TextLabel")
    UI.ammoMagLbl.Name = "AmmoMag"
    UI.ammoMagLbl.Size = UDim2.new(1, 0, 0, 16)
    UI.ammoMagLbl.Position = UDim2.new(0, 0, 0, 40)
    UI.ammoMagLbl.BackgroundTransparency = 1
    UI.ammoMagLbl.Font = Enum.Font.GothamBold
    UI.ammoMagLbl.TextSize = 13
    UI.ammoMagLbl.TextColor3 = HUD_C.Sub
    UI.ammoMagLbl.TextXAlignment = Enum.TextXAlignment.Right
    UI.ammoMagLbl.Text = "/ 18"
    UI.ammoMagLbl.ZIndex = 6
    UI.ammoMagLbl:SetAttribute("TypeRole", "Accent")
    UI.ammoMagLbl:SetAttribute("Skinned", true)
    UI.ammoMagLbl.Parent = UI.ammoContainer

    UI.ammoHintLbl = Instance.new("TextLabel")
    UI.ammoHintLbl.Name = "AmmoHint"
    UI.ammoHintLbl.AnchorPoint = Vector2.new(1, 0)
    UI.ammoHintLbl.Size = UDim2.new(1, 0, 0, 14)
    UI.ammoHintLbl.Position = UDim2.new(1, 0, 0, 60)
    UI.ammoHintLbl.BackgroundTransparency = 1
    UI.ammoHintLbl.Font = Enum.Font.GothamBold
    UI.ammoHintLbl.TextSize = 12
    UI.ammoHintLbl.TextColor3 = HUD_C.Muted
    UI.ammoHintLbl.TextXAlignment = Enum.TextXAlignment.Right
    UI.ammoHintLbl.TextTruncate = Enum.TextTruncate.AtEnd
    UI.ammoHintLbl.Text = "[R] RELOAD  [V] MELEE"
    UI.ammoHintLbl.ZIndex = 6
    UI.ammoHintLbl:SetAttribute("Skinned", true)
    UI.ammoHintLbl.Parent = UI.ammoContainer

    local ammoBarBg = Instance.new("Frame")
    ammoBarBg.Name = "AmmoTrack"
    ammoBarBg.AnchorPoint = Vector2.new(0, 1)
    ammoBarBg.Size = UDim2.new(1, -28, 0, 5)
    ammoBarBg.Position = UDim2.new(0, 14, 1, -9)
    ammoBarBg.BackgroundColor3 = HUD_C.Well
    ammoBarBg.BorderSizePixel = 0
    ammoBarBg.ZIndex = 6
    ammoBarBg:SetAttribute("Skinned", true)
    ammoBarBg.Parent = UI.weaponCard

    UI.ammoBarFill = Instance.new("Frame")
    UI.ammoBarFill.Name = "AmmoFill"
    UI.ammoBarFill.Size = UDim2.new(1, 0, 1, 0)
    UI.ammoBarFill.BackgroundColor3 = Color3.fromRGB(236, 236, 240)
    UI.ammoBarFill.BorderSizePixel = 0
    UI.ammoBarFill.ZIndex = 6
    UI.ammoBarFill:SetAttribute("Skinned", true)
    UI.ammoBarFill.Parent = ammoBarBg

    -- the ammo readout (every shot / reload): white count, LOW in red + the word under 25% (not colour alone)
    UI.ShowAmmo = function(curMag: number, maxMag: number)
        if UI.Zen and UI.Zen.ShowAmmo(curMag, maxMag) then return end -- (CHASE ITEMS: Furnace Heart's heat bar)
        if isReloading then -- (StartReload / the HUD refresh while reloading)
            UI.ammoCounterLbl.Text = "RELOAD"
            UI.ammoCounterLbl.TextColor3 = Color3.fromRGB(255, 214, 90)
            UI.ammoMagLbl.Text = "/ " .. tostring(maxMag)
            return
        end
        local low = curMag <= math.max(3, math.floor(maxMag * 0.25))
        UI.ammoCounterLbl.Text = tostring(curMag)
        UI.ammoCounterLbl.TextColor3 = low and Color3.fromRGB(255, 96, 96) or Color3.fromRGB(240, 240, 240)
        UI.ammoMagLbl.Text = (low and "LOW  " or "") .. "/ " .. tostring(maxMag)
        UI.ammoMagLbl.TextColor3 = low and Color3.fromRGB(255, 120, 120) or HUD_C.Sub
        local aPct = math.clamp(curMag / math.max(1, maxMag), 0, 1)
        UI.ammoBarFill.Size = UDim2.new(aPct, 0, 1, 0)
        UI.ammoBarFill.BackgroundColor3 = low and Color3.fromRGB(232, 66, 66) or Color3.fromRGB(236, 236, 240)
    end

    -- Dungeon Victory Celebration Banner
    UI.victoryBanner = Instance.new("Frame")
    UI.victoryBanner.Name = "DungeonVictoryBanner"
    UI.victoryBanner.Size = UDim2.new(0, 560, 0, 220)
    UI.victoryBanner.AnchorPoint = Vector2.new(0.5, 0) -- (centred on its top edge: on a phone it grows from there)
    UI.victoryBanner.Position = UDim2.new(0.5, 0, 0.18, 0) -- (up out of the way of the vault + loot)
    UI.victoryBanner:SetAttribute("PhoneBoostW", 560) -- (phones: drawn at the phone window scale -- UIStyle.PhoneBoostK)
    UI.victoryBanner:SetAttribute("PhoneBoostH", 220)
    UI.victoryBanner.Visible = false
    UI.victoryBanner.Parent = hudGui
    UI.RunHud.Plate(UI.victoryBanner, UI.RunHud.CARD_T) -- (UI CLEAN R-C: a flat card -- no gold border / block)

    local vTitle = Instance.new("TextLabel")
    vTitle.Size = UDim2.new(1, 0, 0, 45)
    vTitle.Position = UDim2.fromOffset(0, 14)
    vTitle.BackgroundTransparency = 1
    vTitle.Text = "DUNGEON CLEARED"
    vTitle.Parent = UI.victoryBanner
    UI.RunHud.Role(vTitle, "WindowTitle"); vTitle.TextSize = 30
    UI.bannerHeaders = { [UI.victoryBanner] = vTitle }

    local vDesc = Instance.new("TextLabel")
    vDesc.Size = UDim2.new(1, -48, 0, 60)
    vDesc.Position = UDim2.new(0, 24, 0, 62)
    vDesc.BackgroundTransparency = 1
    vDesc.TextWrapped = true
    vDesc.Text = "Every floor cleared: +1,800 gold and crafting materials. Loot the vault, then take the gold portal home."
    vDesc.Parent = UI.victoryBanner
    UI.RunHud.Role(vDesc, "Body", { Color = "Sub" }); vDesc.TextSize = 15

    local btnVictoryHub = Instance.new("TextButton")
    btnVictoryHub.Size = UDim2.new(0, 220, 0, 38)
    btnVictoryHub.Position = UDim2.new(0.5, 10, 1, -55)
    btnVictoryHub.Text = "RETURN TO HUB  [J]"
    UI.btnVictoryHub = btnVictoryHub
    btnVictoryHub.Parent = UI.victoryBanner
    UI.RunHud.Btn(btnVictoryHub, "Primary") -- (UI CLEAN R-C: the primary)

    function ReturnFromVictory()
        if UI.LootGate and not UI.LootGate() then return end -- (QOL L1: drops left on the ground warn first)
        SoundHelper.Play("Click")
        UI.victoryBanner.Visible = false
        UI.raidBanner.Visible = false
        TeleportClient(CFrame.lookAt(Vector3.new(0, 6, 24), Vector3.new(0, 6, 0)))
        Remotes.GetEvent("TeleportPlayer"):FireServer("Hub")
        if not isAnyMenuOpen then SetMouseLocked(true) end
    end
    btnVictoryHub.MouseButton1Click:Connect(ReturnFromVictory)
    -- (owner 2026-10-03: "the pop up saying youre finished has no way to be closed. This makes it annoying to collect
    -- loot") KEEP LOOTING closes it; it also closes itself after a few seconds
    local btnVictoryClose = Instance.new("TextButton")
    btnVictoryClose.Size = UDim2.new(0, 220, 0, 38)
    btnVictoryClose.Position = UDim2.new(0.5, -230, 1, -55)
    btnVictoryClose.Text = "KEEP LOOTING"
    btnVictoryClose.Parent = UI.victoryBanner
    UI.RunHud.Btn(btnVictoryClose, "Secondary") -- (UI CLEAN R-C: the quiet secondary)
    btnVictoryClose.MouseButton1Click:Connect(function()
        SoundHelper.Play("Click")
        UI.victoryBanner.Visible = false
        if not isAnyMenuOpen then SetMouseLocked(true) end
    end)

    -- Toast Notification Banner
    -- (Update 5: a faceted slab with an ink edge and an accent block, sized to its text up to 640 px, wrapping after)
    UI.toastLabel = Instance.new("TextLabel")
    UI.toastLabel.Name = "ToastLabel"
    UI.toastLabel.AnchorPoint = Vector2.new(0.5, 1)
    UI.toastLabel.AutomaticSize = Enum.AutomaticSize.XY
    UI.toastLabel.Size = UDim2.new(0, 0, 0, 0)
    UI.toastLabel.Position = UDim2.new(0.5, 0, 1, -128)
    UI.toastLabel.TextWrapped = true
    UI.toastLabel.Visible = false
    UI.toastLabel.ZIndex = 50 -- above open menus (menus are created later, so they'd otherwise cover it)
    UI.toastLabel.Parent = hudGui
    do
        -- (UI CLEAN R-C: the run HUD plate, nearly solid (toasts also sit over open windows) -- no gradient, no hairline box,
        -- no accent edge; body 14 Text. Important lines get ONE 2 px off-white tick on the left (AimRngShared/ToastStack).)
        UI.RunHud.Plate(UI.toastLabel, 0.12)
        UI.toastLabel:SetAttribute("PlateT", 0.12)
        UI.RunHud.Role(UI.toastLabel, "Body")
        local tp = Instance.new("UIPadding"); tp.PaddingLeft = UDim.new(0, 14); tp.PaddingRight = UDim.new(0, 14)
        tp.PaddingTop = UDim.new(0, 7); tp.PaddingBottom = UDim.new(0, 7); tp.Parent = UI.toastLabel
        local tc = Instance.new("UISizeConstraint"); tc.MaxSize = Vector2.new(640, 200); tc.MinSize = Vector2.new(160, 30); tc.Parent = UI.toastLabel
    end

    -- QOL L4 (2026-10-28): the lines STACK now (AimRngShared/ToastStack: up to 4, newest on top, each fades on its own;
    -- BAG FULL / REVIVED / left-behind / ShowToast(text, true) stay longer). UI.toastLabel is its hidden template; the old
    -- single-label code below is the fallback if the module fails to load.
    UI.ToastStack = (function()
        local ok, TS = pcall(require, game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ToastStack"))
        if not ok then warn("[ToastStack] " .. tostring(TS)); return nil end
        TS.Init(UI.toastLabel, hudGui)
        return TS
    end)()
    local toastSeq = 0
    function ShowToast(text: string, important: boolean?)
        if UI.ToastStack then -- (the RUN SUMMARY opens without OpenMenuFrame: it counts as a window for the toasts' spot)
            UI.ToastStack.Show(text, important, isAnyMenuOpen or (UI.runSummary ~= nil and UI.runSummary.Visible))
            return
        end
        local t = UI.toastLabel
        toastSeq += 1
        local my = toastSeq
        local tw = UIStyle.Motion.Tween
        local edge, blk = t:FindFirstChild("ToastEdge"), t:FindFirstChild("Block")
        local wasShown = t.Visible and t.TextTransparency < 0.5
        -- (UI v4: with a window open the toast sits at the top centre, above every window's footprint -- at the bottom it
        -- covered the inventory's last rows; with none it keeps its spot above the HUD, clear of the crosshair)
        local atTop = isAnyMenuOpen
        local final = atTop and UDim2.new(0.5, 0, 0, 10) or UDim2.new(0.5, 0, 1, -128)
        local anchor = atTop and Vector2.new(0.5, 0) or Vector2.new(0.5, 1)
        if t.AnchorPoint ~= anchor then t.AnchorPoint = anchor; wasShown = false end
        t.Text = text
        t.Visible = true
        if not wasShown then
            t.Position = atTop and UDim2.new(0.5, 0, 0, 0) or UDim2.new(0.5, 0, 1, -118)
            t.TextTransparency, t.BackgroundTransparency = 1, 1
            if edge then edge.Transparency = 1 end
            if blk then blk.BackgroundTransparency = 1 end
        end
        tw(t, 0.16, { Position = final, TextTransparency = 0, BackgroundTransparency = 0.12 }, Enum.EasingStyle.Quart)
        if edge then tw(edge, 0.16, { Transparency = 0 }) end
        if blk then tw(blk, 0.16, { BackgroundTransparency = 0 }) end
        task.delay(3.5, function()
            if my ~= toastSeq then return end
            tw(t, 0.22, { TextTransparency = 1, BackgroundTransparency = 1 })
            if edge then tw(edge, 0.22, { Transparency = 1 }) end
            if blk then tw(blk, 0.22, { BackgroundTransparency = 1 }) end
            task.delay(0.24, function() if my == toastSeq then t.Visible = false end end)
        end)
    end
    -- Short server callouts (Mythic gem triggers: "UNDYING", "MIDAS x6 GOLD").
    Remotes.GetEvent("CombatFx").OnClientEvent:Connect(function(kind, text)
        if kind == "Text" and type(text) == "string" then ShowToast(text) end
    end)

    -- ==================== [LOOT POPUPS: upgraded card UI] ====================
    -- Every loot drop used to be either a single-line plain-gray text toast (gear, "stored in stash",
    -- auto-sold) or this one plain flat rectangle (a strictly-better weapon) -- no rarity color, no
    -- glow, no stats, nothing that makes finding a Celestial feel any different from finding a Common.
    -- Both are rebuilt below into proper rarity-themed cards: a colored gradient fill, a glowing
    -- rarity-colored outline (thicker for higher rarities), a rarity banner line, and the item's real
    -- stats -- plus a pop-in scale tween instead of just snapping visible.
    local function RarityGlyph(rarity: string): string
        -- (0.62: only shapes the UI fonts actually have -- ✦ ✪ ❈ ✵ ✶ ✹ ❋ ♛ ✺ drew as empty boxes, ☄ as a Roblox emoji)
        -- (UPDATE 8: Relic ★; the old names stay for gem grades)
        return ItemData.RarityGlyph(rarity) -- (QOL2 I2: the table lives in ItemData.RARITY_GLYPHS, shared with GroundLoot)
    end
    UI.RarityGlyph = RarityGlyph -- also used by the LootAnnounce handler far below, outside this block
    local RarityStrokeWidth: { [string]: number } = { Relic = 4, Common = 1, Uncommon = 1, Rare = 2, Epic = 2, Legendary = 3, Mythic = 3, Celestial = 4, Transcendent = 4,
        Astral = 4, Empyrean = 4, Primordial = 5, Sovereign = 5, Eclipse = 5, Genesis = 5, Infinite = 6 }

    -- Applies the shared rarity-themed chrome (gradient + glowing stroke) to a popup card frame.
    local function StyleLootCard(card: Frame, rarity: string)
        local rColor = ItemData.RarityColors[rarity] or Color3.fromRGB(200, 200, 200)
        card.BackgroundColor3 = Color3.fromRGB(14, 16, 22)

        -- (the HUD skin (UIStyle.Skin -> EnsureGloss) gives every filled panel its own near-white gloss UIGradient; with two
        -- gradients on one frame Roblox draws only one, and the white gloss over this white background made item popups WHITE.
        -- The card is styled here, so the skin keeps off it and any extra gradient goes.)
        card:SetAttribute("Skinned", true)
        for _, ch in ipairs(card:GetChildren()) do
            if ch:IsA("UIGradient") and ch.Name ~= "RarityGradient" then ch:Destroy() end
        end
        local grad = card:FindFirstChild("RarityGradient") :: UIGradient?
        if not grad then
            grad = Instance.new("UIGradient")
            grad.Name = "RarityGradient"
            grad.Rotation = 90
            grad.Parent = card
        end
        -- (UI CLEAN R-C: the target's item card -- flat slate, a 2 px rarity line along the top, a 1 px hairline round it (the
        -- same weight for every rarity: the colour + the name carry the rarity); no facet gradient, no thick rarity stroke)
        grad.Color = ColorSequence.new(UIStyle.Colors.Bg0)
        grad.Transparency = NumberSequence.new(0.04)
        card.BackgroundColor3 = Color3.new(1, 1, 1)
        local band = card:FindFirstChild("RarityBand") :: Frame?
        if not band then
            band = Instance.new("Frame")
            band.Name = "RarityBand"
            band.BorderSizePixel = 0
            band.Size = UDim2.new(1, 0, 0, 2)
            band.ZIndex = card.ZIndex + 1
            band:SetAttribute("Skinned", true)
            band.Parent = card
        end
        band.BackgroundColor3 = rColor

        local stroke = card:FindFirstChild("RarityStroke") :: UIStroke?
        if not stroke then
            stroke = Instance.new("UIStroke")
            stroke.Name = "RarityStroke"
            stroke.Parent = card
        end
        stroke.Color = UIStyle.Colors.Text
        stroke.Thickness = 1
        stroke.Transparency = 0.84
        local _ = RarityStrokeWidth

        local corner = card:FindFirstChild("RarityCorner") :: UICorner?
        if not corner then
            corner = Instance.new("UICorner")
            corner.Name = "RarityCorner"
            corner.CornerRadius = UDim.new(0, 2) -- (Update 5: square slabs)
            corner.Parent = card
        end
    end

    -- Pops a card in with a quick scale-up tween instead of just flipping Visible on -- makes a drop
    -- feel like an actual event rather than a menu toggling.
    local function PopInCard(card: Frame)
        local scale = card:FindFirstChildOfClass("UIScale") :: UIScale?
        if not scale then
            scale = Instance.new("UIScale")
            scale.Parent = card
        end
        scale.Scale = 0.97 -- (UI CLEAN R-C: a short settle, no Back overshoot / big pop)
        card.Visible = true
        TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
    end

    -- ==================== [AUTO-EQUIP CARD: a strictly-better weapon just dropped] ====================
    UI.betterWeaponBanner = Instance.new("Frame")
    UI.betterWeaponBanner.Name = "BetterWeaponBanner"
    UI.betterWeaponBanner.Size = UDim2.new(0, 460, 0, 160)
    UI.betterWeaponBanner.Position = UDim2.new(0.5, -230, 1, -275)
    UI.betterWeaponBanner.BorderSizePixel = 0
    UI.betterWeaponBanner.Visible = false
    UI.betterWeaponBanner.Parent = hudGui

    local bHeader = Instance.new("TextLabel")
    bHeader.Size = UDim2.new(1, -20, 0, 22)
    bHeader.Position = UDim2.new(0, 12, 0, 8)
    bHeader.BackgroundTransparency = 1
    bHeader.Font = Enum.Font.GothamBlack
    bHeader.TextSize = 17
    bHeader.TextColor3 = Color3.fromRGB(0, 255, 160)
    bHeader.TextXAlignment = Enum.TextXAlignment.Left
    bHeader.Text = "▲ UPGRADE FOUND: HIGHER TOTAL DPS!"
    bHeader.Parent = UI.betterWeaponBanner

    UI.bWeaponName = Instance.new("TextLabel")
    UI.bWeaponName.Size = UDim2.new(1, -20, 0, 24)
    UI.bWeaponName.Position = UDim2.new(0, 12, 0, 30)
    UI.bWeaponName.BackgroundTransparency = 1
    UI.bWeaponName.Font = Enum.Font.GothamBold
    UI.bWeaponName.TextSize = 20
    UI.bWeaponName.TextColor3 = Color3.fromRGB(255, 255, 255)
    UI.bWeaponName.TextXAlignment = Enum.TextXAlignment.Left
    UI.bWeaponName.Text = "[RARE] Weapon Name"
    UI.bWeaponName.Parent = UI.betterWeaponBanner

    UI.bReasons = Instance.new("TextLabel")
    UI.bReasons.Size = UDim2.new(1, -20, 0, 56)
    UI.bReasons.Position = UDim2.new(0, 12, 0, 56)
    UI.bReasons.BackgroundTransparency = 1
    UI.bReasons.Font = Enum.Font.Gotham
    UI.bReasons.TextSize = 16
    UI.bReasons.TextColor3 = Color3.fromRGB(180, 255, 210)
    UI.bReasons.TextXAlignment = Enum.TextXAlignment.Left
    UI.bReasons.TextYAlignment = Enum.TextYAlignment.Top
    UI.bReasons.TextWrapped = true
    UI.bReasons.Text = "• Higher True DPS Output"
    UI.bReasons.Parent = UI.betterWeaponBanner

    local btnEquipNow = Instance.new("TextButton")
    btnEquipNow.Size = UDim2.new(0, 210, 0, 34)
    btnEquipNow.Position = UDim2.new(0, 12, 1, -42)
    btnEquipNow.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
    btnEquipNow.BorderSizePixel = 0
    btnEquipNow.Font = Enum.Font.GothamBold
    btnEquipNow.TextSize = 17
    btnEquipNow.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnEquipNow.Text = "EQUIP NOW  [E]"
    UI.btnEquipNow = btnEquipNow
    btnEquipNow.Parent = UI.betterWeaponBanner
    Instance.new("UICorner", btnEquipNow).CornerRadius = UDim.new(0, 6)

    local btnKeepInventory = Instance.new("TextButton")
    btnKeepInventory.Size = UDim2.new(0, 210, 0, 34)
    btnKeepInventory.Position = UDim2.new(1, -222, 1, -42)
    btnKeepInventory.BackgroundColor3 = Color3.fromRGB(40, 50, 65)
    btnKeepInventory.BorderSizePixel = 0
    btnKeepInventory.Font = Enum.Font.GothamBold
    btnKeepInventory.TextSize = 16
    btnKeepInventory.TextColor3 = Color3.fromRGB(200, 215, 235)
    btnKeepInventory.Text = "KEEP IN STASH  [X]"
    UI.btnKeepInventory = btnKeepInventory
    btnKeepInventory.Parent = UI.betterWeaponBanner
    Instance.new("UICorner", btnKeepInventory).CornerRadius = UDim.new(0, 6)


    function EquipPendingWeapon()
        -- take the weapon and clear the offer BEFORE asking the server: spamming the key used to send several
        -- equips, and every reply after the first equipped "nothing" (the offer was already cleared) -- the gun
        -- vanished and shooting locked up
        local w = pendingBetterWeapon
        if not w then return end
        pendingBetterWeapon = nil
        UI.betterWeaponBanner.Visible = false
        SoundHelper.Play("Equip")
        local ok = Remotes.GetFunction("EquipWeapon"):InvokeServer(w.Uid)
        if ok and w then
            clientState.EquippedWeapon = w
            RebuildViewmodelForWeapon(w)
            UpdateWeaponHUD()
        end
    end

    btnEquipNow.MouseButton1Click:Connect(EquipPendingWeapon)
    btnKeepInventory.MouseButton1Click:Connect(function()
        SoundHelper.Play("Click")
        pendingBetterWeapon = nil
        UI.betterWeaponBanner.Visible = false
    end)

    function PromptBetterWeapon(w: ItemData.WeaponInstance, comp: ItemData.WeaponComparison)
        -- (0.61f, owner: "equip best popup shouldnt show non-class weapons"): only guns of your class's group are offered
        local grp = require(sharedFolder:WaitForChild("ClassData")).GroupOf(clientState.Class)
        if grp and ItemData.WeaponGroupOf(w) ~= grp then
            if ShowLootPopup then ShowLootPopup(w, "Weapon", RarityGlyph(w.Rarity) .. " STORED IN STASH") end
            return
        end
        pendingBetterWeapon = w
        StyleLootCard(UI.betterWeaponBanner, w.Rarity)
        bHeader.Text = RarityGlyph(w.Rarity) .. "  UPGRADE FOUND  •  HIGHER DPS"
        -- (Update 5: name first, then rarity + type in plain words -- no [BRACKETS])
        UI.bWeaponName.Text = ItemData.DisplayName(w) .. "   •   " .. ItemData.RarityLabel(w) .. " " .. ItemData.WeaponTypeLine(w) .. "  •  iLvl " .. (w.ItemLevel or 1)
        UI.bWeaponName.TextColor3 = ItemData.ItemColor(w)
        UI.bReasons.Text = table.concat(comp.Reasons, "  |  ") .. string.format("\nDPS: %s | DMG: %s | Rate: %.1f/s", ItemData.FormatNumber(ItemData.CalculateTrueDPS(w)), ItemData.FormatNumber(ItemData.GunDamage(w)), w.BaseFireRate)
        PopInCard(UI.betterWeaponBanner)

        task.delay(12, function()
            if pendingBetterWeapon == w and UI.betterWeaponBanner.Visible then
                UI.betterWeaponBanner.Visible = false
                pendingBetterWeapon = nil
            end
        end)
    end

    -- ==================== [GENERAL LOOT CARD: gear, lower-DPS weapons, auto-sold] ====================
    -- Same visual language as the upgrade card above (rarity gradient + glow + pop-in), just without
    -- the equip/keep decision -- these are informational: something was added to your stash (or sold
    -- automatically), here's what it was and what it rolled.
    UI.lootCard = Instance.new("Frame")
    UI.lootCard.Name = "LootCard"
    UI.lootCard.Size = UDim2.new(0, 380, 0, 108)
    UI.lootCard.Position = UDim2.new(1, -400, 1, -230)
    UI.lootCard.BorderSizePixel = 0
    UI.lootCard.Visible = false
    UI.lootCard.Parent = hudGui

    UI.lootCardHeader = Instance.new("TextLabel")
    UI.lootCardHeader.Size = UDim2.new(1, -20, 0, 20)
    UI.lootCardHeader.Position = UDim2.new(0, 12, 0, 8)
    UI.lootCardHeader.BackgroundTransparency = 1
    UI.lootCardHeader.Font = Enum.Font.GothamBlack
    UI.lootCardHeader.TextSize = 16
    UI.lootCardHeader.TextXAlignment = Enum.TextXAlignment.Left
    UI.lootCardHeader.Text = "★ LOOT"
    UI.lootCardHeader.Parent = UI.lootCard

    UI.lootCardName = Instance.new("TextLabel")
    UI.lootCardName.Size = UDim2.new(1, -20, 0, 22)
    UI.lootCardName.Position = UDim2.new(0, 12, 0, 28)
    UI.lootCardName.BackgroundTransparency = 1
    UI.lootCardName.Font = Enum.Font.GothamBold
    UI.lootCardName.TextSize = 19
    UI.lootCardName.TextColor3 = Color3.fromRGB(255, 255, 255)
    UI.lootCardName.TextXAlignment = Enum.TextXAlignment.Left
    UI.lootCardName.Parent = UI.lootCard

    UI.lootCardStats = Instance.new("TextLabel")
    UI.lootCardStats.Size = UDim2.new(1, -20, 0, 40)
    UI.lootCardStats.Position = UDim2.new(0, 12, 0, 52)
    UI.lootCardStats.BackgroundTransparency = 1
    UI.lootCardStats.Font = Enum.Font.Gotham
    UI.lootCardStats.TextSize = 16
    UI.lootCardStats.TextColor3 = Color3.fromRGB(190, 205, 225)
    UI.lootCardStats.TextXAlignment = Enum.TextXAlignment.Left
    UI.lootCardStats.TextYAlignment = Enum.TextYAlignment.Top
    UI.lootCardStats.TextWrapped = true
    UI.lootCardStats.Parent = UI.lootCard

    -- itemKind: "Weapon" | "Gear". headerText overrides the default "★ LOOT" line (e.g. for auto-sold).
    function ShowLootPopup(item: any, itemKind: string, headerText: string?)
        StyleLootCard(UI.lootCard, item.Rarity)
        local exotic = ItemData.ExoticOf(item) ~= nil
        local rColor = exotic and ItemData.ItemColor(item) or ItemData.RarityColors[item.Rarity] or Color3.fromRGB(200, 200, 200) -- (CHASE ITEMS: Zenith colour)
        UI.lootCardHeader.TextColor3 = rColor
        UI.lootCardHeader.Text = headerText or (ItemData.ZenithOf(item) and "❖ ZENITH LOOT") or (exotic and "◆ RELIC LOOT" or (RarityGlyph(item.Rarity) .. " " .. item.Rarity:upper() .. " LOOT"))
        UI.lootCardName.TextColor3 = rColor
        if not exotic then ItemData.StyleRarityText(UI.lootCardName, item.Rarity) end

        if itemKind == "Gem" then
            local GemData = require(sharedFolder:WaitForChild("GemData"))
            local d = GemData.Describe(item)
            UI.lootCardName.Text = GemData.Icon(item) .. " " .. d.Title .. "  (" .. d.Subtitle .. ")"
            UI.lootCardStats.Text = table.concat(d.Lines, "  |  ") .. (d.Special and (" | " .. d.Special) or "")
        elseif itemKind == "Gear" then
            local desc = ItemData.DescribeGear(item)
            UI.lootCardName.Text = item.Name .. "  (" .. desc.Subtitle .. ")"
            local parts = {}
            for _, line in ipairs(desc.Lines) do
                if line.Kind ~= "note" then table.insert(parts, line.Text) end
            end
            UI.lootCardStats.Text = table.concat(parts, "  |  ")
        else
            UI.lootCardName.Text = item.Name .. " (" .. ItemData.WeaponTypeLine(item) .. ", iLvl " .. (item.ItemLevel or 1) .. ")"
            local affixTexts = {}
            for _, a in ipairs(item.Prefixes or {}) do table.insert(affixTexts, ItemData.FormatStat(a.Stat, a.Value)) end
            if ItemData.FamilyLine and ItemData.FamilyLine(item) then table.insert(affixTexts, 1, ItemData.FamilyLine(item)) end -- (CLASS BUILDS) FAMILY: the built-in line
            UI.lootCardStats.Text = string.format("DPS: %s | DMG: %s | Rate: %.1f/s | Weak-Spot: %d%%", ItemData.FormatNumber(ItemData.CalculateTrueDPS(item)), ItemData.FormatNumber(ItemData.GunDamage(item)), item.BaseFireRate, math.round((item.BaseWeakSpotMultiplier or 2.0) * 100))
                .. (#affixTexts > 0 and ("\n" .. table.concat(affixTexts, "  |  ")) or "")
        end

        PopInCard(UI.lootCard)
        local rarityRank = table.find(ItemData.Rarities, item.Rarity) or 1
        local holdTime = 3.0 + rarityRank * 0.35 -- rarer drops stay on screen a bit longer to read
        task.delay(holdTime, function()
            if UI.lootCard.Visible then UI.lootCard.Visible = false end
        end)
    end


end
BuildHUD()

-- ==================== [4. HIGH-FIDELITY 3D VIEWMODELS (22 WEAPON ARCHETYPES)] ====================
local viewmodel: Model? = nil
local vmPartCache = {} -- { {Part, Offset, Kind, Index} } so the render loop needs no GetChildren/GetAttribute
local vmKnifeParts = {} -- { {Part, Offset} } for the 3 procedural melee-knife parts (Kind 3 in vmPartCache)
local vmMeleeSwingT = 1.0 -- 0 = swing just started, 1 = idle/finished; drives the arc in the render loop
local vmMeleeWasActive = false
local MELEE_SWING_DURATION = 0.3
local muzzleFlashPart: BasePart? = nil
local activeBaseWeaponType = ""

-- Live mesh-rotation touch-up tool (orientation is automatic now; this is only for stragglers). See the "[Mesh Tuning]" input handler far below.
local vmTuneModeOn = false
local vmTuneBaseId: string? = nil -- the gun currently shown in the viewmodel (real or previewed), kept in sync by RebuildViewmodelForWeapon
local vmTuneActiveWeapon: ItemData.WeaponInstance? = nil -- whatever was last passed to RebuildViewmodelForWeapon, so nudges/presets/cycling can rebuild the SAME thing (real equip or preview)
local currentWeaponHasScope = false
local vmHiddenForScope = false

-- Real-mesh viewmodel (shared rigged arms + multi-part gun, see ViewmodelRig / WeaponRigs). Guns with a
-- WeaponRigs entry use it instead of the procedural hands + pack mesh below.
local ViewmodelRig = require(sharedFolder:WaitForChild("ViewmodelRig"))
local realRig: any = nil
local vmSizePreset = 1 -- Studio-only Y-key comparison presets (see keybinds)

-- ==================== VIEWMODEL LAYOUT ====================
-- The whole viewmodel is laid out around ONE point: where the right hand grips the gun. That point sits
-- at VM_GRIP_ANCHOR in camera space. Each gun is sized to a consistent length for its class, then shifted
-- so its real grip (found by the server's silhouette probe, see AimRngServer) lands on that anchor, and
-- the hands are built around the real grip / handguard dimensions.
local HttpService = game:GetService("HttpService")
local VM_GRIP_ANCHOR = Vector3.new(0.44, -0.46, -1.1) -- camera space: right of center, below center, in front
-- Slight inward yaw + roll so the muzzle converges toward the crosshair instead of pointing dead-parallel.
local VM_TILT = CFrame.Angles(0, math.rad(4.5), math.rad(-3))
-- Off-screen shoulder points (anchor space). Each arm = gloved hand -> forearm -> elbow (dropping down
-- and out, like a real hold) -> upper arm to the shoulder.
local VM_RIGHT_SHOULDER = Vector3.new(0.55, -1.25, 1.35)
local VM_LEFT_SHOULDER = Vector3.new(-1.25, -1.2, 1.2)
local VM_FOREARM_LEN = 0.95

-- Longest on-screen dimension each class is normalized to (studs). The source meshes range from ~1 to ~7
-- studs at their own scales; unnormalized, rifles poked through the camera and some pistols were tiny.
local VM_CLASS_LENGTH: { [string]: number } = {
    Pistol = 0.92, Revolver = 1.02, SMG = 1.9, Rifle = 2.6, Burst = 2.6, Shotgun = 2.6,
    Sniper = 3.0, Heavy = 2.8, Laser = 2.3, Launcher = 2.9,
}
local VM_LENGTH_OVERRIDE: { [string]: number } = { SawedOff = 1.9, DualDeagle = 0.95, HuntersBow = 2.5 }
-- One-handers sit a little lower and further out than long guns (anchor-space shift, applied by the render
-- loop); at the long-gun anchor a pistol filled the middle of the screen.
local VM_CLASS_ANCHOR_SHIFT: { [string]: Vector3 } = {
    Pistol = Vector3.new(-0.03, -0.09, -0.16), Revolver = Vector3.new(-0.03, -0.09, -0.16),
}
local vmAnchorShift = Vector3.zero

-- FALLBACK hand placement (only used until/unless the server's grip probe for a gun is available):
-- fractions of the gun's normalized size. Grip = (toward-rear fraction of length, downward fraction of
-- height) for the right hand; Support = same for the left hand, or nil for a two-handed pistol cup.
local VM_HAND_LAYOUT: { [string]: { Grip: Vector2, Support: Vector2? } } = {
    Pistol   = { Grip = Vector2.new(0.30, -0.22) },
    Revolver = { Grip = Vector2.new(0.32, -0.22) },
    SMG      = { Grip = Vector2.new(0.10, -0.26), Support = Vector2.new(-0.24, -0.18) },
    Rifle    = { Grip = Vector2.new(0.14, -0.26), Support = Vector2.new(-0.24, -0.18) },
    Burst    = { Grip = Vector2.new(0.14, -0.26), Support = Vector2.new(-0.24, -0.18) },
    Shotgun  = { Grip = Vector2.new(0.18, -0.16), Support = Vector2.new(-0.22, -0.20) },
    Sniper   = { Grip = Vector2.new(0.16, -0.20), Support = Vector2.new(-0.24, -0.18) },
    Heavy    = { Grip = Vector2.new(0.10, -0.28), Support = Vector2.new(-0.20, -0.25) },
    Laser    = { Grip = Vector2.new(0.12, -0.26), Support = Vector2.new(-0.22, -0.18) },
    Launcher = { Grip = Vector2.new(0.05, -0.36), Support = Vector2.new(-0.22, -0.36) },
}

-- Per-weapon MANUAL rotation overrides, applied instead of WeaponMeshes' automatic Orient. Empty on
-- purpose: Orient is derived from the source pack for all 50 meshes. Only add a line here (from the
-- tuning tool's readout) if one specific gun still looks wrong in-game.
local MESH_ROTATION_FIX: { [string]: CFrame } = {}

-- Runtime overrides written live by the in-game mesh-tuning tool (see "[Mesh Tuning]" far below).
local MeshRotationOverride: { [string]: CFrame } = {}

-- Per-gun FIT fixes: Scale multiplies the class length, Offset slides the gun relative to the hands
-- (anchor space: +X right, +Y up, -Z forward). Unlike a rotation override these keep the grip probe.
-- Paste lines from the tuner's readout here.
local MESH_FIT_FIX: { [string]: { Scale: number?, Offset: Vector3? } } = {}
local MeshFitOverride: { [string]: { Scale: number, Offset: Vector3 } } = {}
local function GetMeshFit(key: string): (number, Vector3)
    local f = MeshFitOverride[key] or MESH_FIT_FIX[key]
    if not f then return 1, Vector3.zero end
    return f.Scale or 1, f.Offset or Vector3.zero
end

local function GetMeshRotationFix(key: string): CFrame
    local manual = MeshRotationOverride[key] or MESH_ROTATION_FIX[key]
    if manual then return manual end
    local data = WeaponMeshes.Guns[key] or WeaponMeshes.Melee[key]
    return (data and data.Orient) or CFrame.new()
end

-- The mesh's rendered size in its OWN axes at its WeaponMeshes Scale: the server's exact measurement
-- when it has arrived (ReplicatedStorage.AimRngShared.MeshBounds), else the static fallback Bounds.
local function GetMeshNativeSize(meshData: any): Vector3
    local id = tostring(meshData.MeshId):match("(%d+)")
    local folder = sharedFolder:FindFirstChild("MeshBounds")
    local measured = (folder and id) and folder:GetAttribute("m" .. id) or nil
    if typeof(measured) == "Vector3" then
        local s = meshData.Scale
        return measured * Vector3.new(math.abs(s.X), math.abs(s.Y), math.abs(s.Z))
    end
    return meshData.Bounds or Vector3.new(0.4, 1, 2)
end

-- Axis-aligned extents (viewmodel X/Y/Z) of a box of the given size after rotation by cf.
local function RotatedExtents(cf: CFrame, size: Vector3): Vector3
    local a, b, c = cf.XVector, cf.YVector, cf.ZVector
    return Vector3.new(
        math.abs(a.X) * size.X + math.abs(b.X) * size.Y + math.abs(c.X) * size.Z,
        math.abs(a.Y) * size.X + math.abs(b.Y) * size.Y + math.abs(c.Y) * size.Z,
        math.abs(a.Z) * size.X + math.abs(b.Z) * size.Y + math.abs(c.Z) * size.Z
    )
end

-- The server's grip probe for a gun (grip / handguard / muzzle positions in viewmodel axes, unscaled),
-- or nil if it hasn't arrived / failed. Only valid for the gun's automatic orientation.
local gunRigCache: { [string]: { Raw: string, Rig: any } } = {}
local function GetGunRig(baseId: string): any?
    if MeshRotationOverride[baseId] or MESH_ROTATION_FIX[baseId] then return nil end
    local folder = sharedFolder:FindFirstChild("MeshBounds")
    local raw = folder and folder:GetAttribute("rig_" .. baseId)
    if type(raw) ~= "string" then return nil end
    local cached = gunRigCache[baseId]
    if cached and cached.Raw == raw then return cached.Rig end
    local ok, rig = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or type(rig) ~= "table" then return nil end
    gunRigCache[baseId] = { Raw = raw, Rig = rig }
    return rig
end

local function V3(t: any, k: number): Vector3?
    if type(t) ~= "table" or #t < 3 then return nil end
    return Vector3.new(t[1] * k, t[2] * k, t[3] * k)
end

-- Fixed, generous Part.Size for every real-mesh viewmodel part. A FileMesh SpecialMesh ignores its
-- Part's Size when rendering, so this is only a renderer safety margin (collision is off).
local VM_MESH_PART_SIZE = Vector3.new(6, 6, 6)

local vmRainbowParts: { BasePart } = {} -- weapon finishes with Animated = "Rainbow"

RebuildViewmodelForWeapon = function(weapon: ItemData.WeaponInstance)
    if not viewmodel then return end
    for _, child in ipairs(viewmodel:GetChildren()) do child:Destroy() end
    vmPartCache = {}
    vmRainbowParts = {}
    if not weapon then return end

    local baseId = weapon.BaseId or "Revolver"
    vmTuneBaseId = baseId
    vmTuneActiveWeapon = weapon
    local rarity = weapon.Rarity or "Common"
    local accentColor = ItemData.RarityColors[rarity] or Color3.new(1, 1, 1)
    local baseDef = ItemData.BaseWeapons[baseId]
    local weaponClass = (baseDef and baseDef.Class) or weapon.Class or "Pistol"
    vmAnchorShift = (baseId == "DualDeagle") and Vector3.new(0.05, -0.06, -0.12) or (VM_CLASS_ANCHOR_SHIFT[weaponClass] or Vector3.zero)

    activeBaseWeaponType = baseId
    currentWeaponHasScope = (weapon.HasScope == true)
    vmHiddenForScope = false -- force the render loop to re-apply visibility for the new weapon

    -- Cosmetics (all future skins plug in through these three lookups).
    -- old glove / sleeve / finish cosmetics don't fit the current hands: default look; premium per-gun skins
    -- (SkinFX, e.g. Seraphim M4A1) are the new skin line and show here + on your world gun
    local gloveData = ItemData.Gloves.Tactical
    local sleeveData = ItemData.ArmSkins.Standard
    local skinData = require(sharedFolder:WaitForChild("SkinFX")).GunSkinFor(clientState, baseId) or ItemData.WeaponSkins.Factory

    -- (the children loop above destroyed any previous real rig's model along with the old parts)
    if realRig then realRig:Destroy(); realRig = nil end
    local useRealRig = ViewmodelRig.HasRig(baseId)
    if useRealRig then
        realRig = ViewmodelRig.new(viewmodel)
        realRig.CalTier = (function() -- (UPDATE 7 B2 CALIBRATION: the gun model's claimed tiers -> notches on the receiver)
            local okC, Cal = pcall(require, sharedFolder:WaitForChild("Calibration"))
            if not okC or not Cal.Unlocked(clientState) then return 0 end
            local c = Cal.Of(clientState, baseId)
            return c and c.T or 0
        end)()
        realRig:SetWeapon(baseId, weapon, skinData)
        local GloveFX = require(sharedFolder:WaitForChild("GloveFX"))
        realRig:ApplyCosmetics({ Glove = gloveData, Sleeve = sleeveData, Skin = skinData, HandFX = { Glove = GloveFX.ViewGloveFor(clientState), Sleeve = GloveFX.SleeveFor(clientState) } })
        muzzleFlashPart = nil
        if activeSlot == "Melee" and ApplyMeleeToRig then ApplyMeleeToRig() end -- the melee is out: keep showing it
    end

    local function MakeVmPart(name: string, sz: Vector3, cfOffset: CFrame, color: Color3?, mat: Enum.Material?): Part
        local p = Instance.new("Part")
        p.Name = name
        p.Size = sz
        p.Material = mat or Enum.Material.SmoothPlastic
        p.Color = color or Color3.fromRGB(90, 90, 95)
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.Anchored = true
        p.CastShadow = false -- viewmodel parts move every frame; shadow casting forces constant shadow updates
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent = viewmodel
        local kind = name:find("Melee") and 3 or 0 -- Kind 3 = positioned by the melee-swing logic instead
        table.insert(vmPartCache, { Part = p, Offset = cfOffset, Kind = kind, Index = 0 })
        return p
    end

    -- Real-mesh body. Preferred path: clone the server's MeshPart template for this mesh (identical to the
    -- geometry the grip probe measured, so hands line up exactly). Fallback until/unless a template
    -- exists: a SpecialMesh on a Part. scaleMult normalizes the gun's size; applySkin = weapon finish.
    -- Returns the part and the offset actually used (MeshParts need a sign-corrected rotation).
    local templates = sharedFolder:FindFirstChild("MeshTemplates")
    local function MakeVmMeshPart(name: string, meshData: any, cfOffset: CFrame, scaleMult: number, kindOverride: number?, applySkin: boolean?): (BasePart, CFrame)
        local id = tostring(meshData.MeshId):match("(%d+)")
        local s = meshData.Scale
        -- Meshes whose pack Scale mirrors them (odd number of negative axes) were authored inside-out and
        -- rely on that mirror to face the right way. A MeshPart can't mirror, so it rendered them with the
        -- faces pointing inward (half-invisible). Those keep the SpecialMesh, which reproduces the pack exactly.
        local mirrored = (s.X * s.Y * s.Z) < 0
        local template = (not mirrored) and templates and id and templates:FindFirstChild("m" .. id) or nil
        local p: BasePart
        if template and template:IsA("MeshPart") then
            local mp = template:Clone()
            mp.Size = template.MeshSize * Vector3.new(math.abs(s.X), math.abs(s.Y), math.abs(s.Z)) * scaleMult
            mp.TextureID = meshData.TextureId
            -- Same proper rotation as the server probe: a MeshPart can't mirror, so negative Scale axes
            -- become a 180-degree turn (flipping whichever mesh axis ends up sideways).
            local sx, sy, sz = math.sign(s.X), math.sign(s.Y), math.sign(s.Z)
            if sx * sy * sz < 0 then
                local rotOnly = cfOffset - cfOffset.Position
                local cols = { rotOnly.XVector, rotOnly.YVector, rotOnly.ZVector }
                local bi, best = 1, -1
                for i, c in ipairs(cols) do if math.abs(c.X) > best then best = math.abs(c.X); bi = i end end
                if bi == 1 then sx = -sx elseif bi == 2 then sy = -sy else sz = -sz end
            end
            cfOffset = cfOffset * CFrame.fromMatrix(Vector3.zero, Vector3.new(sx, 0, 0), Vector3.new(0, sy, 0), Vector3.new(0, 0, sz))
            p = mp
        else
            local part = Instance.new("Part")
            part.Size = VM_MESH_PART_SIZE
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = meshData.MeshId
            mesh.TextureId = meshData.TextureId
            mesh.Scale = meshData.Scale * scaleMult
            mesh.Parent = part
            p = part
        end
        p.Name = name
        p.Material = Enum.Material.SmoothPlastic
        p.Color = Color3.fromRGB(163, 162, 165)
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.Anchored = true
        p.CastShadow = false
        if applySkin and skinData.Id ~= "Factory" then
            -- Finishes are solid materials: the texture is removed and the part's color/material show.
            if p:IsA("MeshPart") then (p :: MeshPart).TextureID = "" end
            local mesh = p:FindFirstChildOfClass("SpecialMesh")
            if mesh then mesh.TextureId = "" end
            p.Color = skinData.Tint
            p.Material = skinData.Material or Enum.Material.Metal
            p.Reflectance = skinData.Reflectance or 0
            if skinData.Animated == "Rainbow" then table.insert(vmRainbowParts, p) end
        end
        p.Parent = viewmodel
        table.insert(vmPartCache, { Part = p, Offset = cfOffset, Kind = kindOverride or 0, Index = 0 })
        return p, cfOffset
    end

    -- ===== Hand & arm primitives (all offsets in anchor space) =====
    local gloveColor, gloveAccent = gloveData.PrimaryColor, gloveData.AccentColor
    local gloveMat, knuckleMat = gloveData.Material, gloveData.KnuckleMaterial
    if knuckleMat == Enum.Material.Neon then knuckleMat = Enum.Material.SmoothPlastic end -- no glowing knuckles in your face
    local FINGER = 0.078

    local function Box(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?)
        return MakeVmPart(name, size, cf, color, mat or gloveMat)
    end
    -- Cylinder whose axis runs along cf's X axis.
    local function Cyl(name: string, len: number, dia: number, cf: CFrame, color: Color3, mat: Enum.Material?)
        local p = MakeVmPart(name, Vector3.new(len, dia, dia), cf, color, mat or gloveMat)
        p.Shape = Enum.PartType.Cylinder
        return p
    end
    local function Knob(name: string, dia: number, pos: Vector3, color: Color3, mat: Enum.Material?)
        local p = MakeVmPart(name, Vector3.new(dia, dia, dia), CFrame.new(pos), color, mat or gloveMat)
        p.Shape = Enum.PartType.Ball
        return p
    end
    local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- cylinder axis -> Z
    local ALONG_Y = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis -> Y

    -- Cylinder spanning two points.
    local function Span(name: string, a: Vector3, b: Vector3, dia: number, color: Color3, mat: Enum.Material?)
        local len = math.max(0.02, (b - a).Magnitude)
        return Cyl(name, len, dia, CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), color, mat)
    end
    -- Glove cuff -> sleeved forearm -> elbow -> upper arm, from the wrist toward an off-screen shoulder.
    local function Forearm(side: string, wrist: Vector3, shoulder: Vector3)
        local toShoulder = (shoulder - wrist).Unit
        local cuffEnd = wrist + toShoulder * 0.15
        Span("Vm" .. side .. "Cuff", wrist, cuffEnd, 0.235, gloveAccent:Lerp(gloveColor, 0.55), gloveMat) -- muted: bright accents read as glowing blocks up close
        -- the elbow drops below the straight hand->shoulder line, so the forearm rises into view from below
        local elbow = cuffEnd + (toShoulder + Vector3.new(0, -0.55, 0)).Unit * VM_FOREARM_LEN
        Span("Vm" .. side .. "Arm", cuffEnd, elbow, 0.28, sleeveData.SleeveColor, sleeveData.Material)
        Span("Vm" .. side .. "SleeveCuff", cuffEnd, cuffEnd + (elbow - cuffEnd).Unit * 0.06, 0.295, sleeveData.CuffColor, sleeveData.Material)
        if sleeveData.StripeColor then
            local sDir = (elbow - cuffEnd).Unit
            Span("Vm" .. side .. "SleeveStripe", cuffEnd + sDir * 0.34, cuffEnd + sDir * 0.41, 0.29, sleeveData.StripeColor, sleeveData.Material)
        end
        Knob("Vm" .. side .. "Elbow", 0.31, elbow, sleeveData.SleeveColor, sleeveData.Material)
        Span("Vm" .. side .. "UpperArm", elbow, shoulder, 0.33, sleeveData.SleeveColor, sleeveData.Material)
    end

    -- A hand wrapped around a vertical-ish grip. H = grip frame (origin at the grip's center where the
    -- hand sits, +Y up the grip, -Z toward the muzzle). w/d = grip width / front-to-back depth.
    -- mirror = -1 builds a left hand (akimbo).
    local function GripHand(side: string, H: CFrame, w: number, d: number, shoulder: Vector3, mirror: number)
        local m = mirror
        local function P(x: number, y: number, z: number): CFrame return H * CFrame.new(x * m, y, z) end
        -- back of hand on the outer side + heel wrapping the backstrap
        Box("Vm" .. side .. "Palm", Vector3.new(0.085, 0.31, d + 0.08), P(w / 2 + 0.042, -0.04, 0.03), gloveColor)
        Box("Vm" .. side .. "Web", Vector3.new(w + 0.12, 0.2, 0.09), P(0.03, 0.02, d / 2 + 0.045), gloveColor)
        Box("Vm" .. side .. "Knuckles", Vector3.new(0.025, 0.12, d * 0.75), P(w / 2 + 0.095, 0.0, -0.01), gloveAccent, knuckleMat)
        -- middle / ring / pinky wrapped around the front strap, tips curling onto the far side
        for i, yo in ipairs({ -0.03, -0.115, -0.195 }) do
            local len = w + 0.13 - (i == 3 and 0.02 or 0)
            Cyl("Vm" .. side .. "Finger" .. i, len, FINGER, P(0.02, yo, -d / 2 - FINGER * 0.45), gloveColor)
            Cyl("Vm" .. side .. "Tip" .. i, d * 0.45, FINGER * 0.95, P(-w / 2 - FINGER * 0.4, yo, -d / 2 + d * 0.18) * ALONG_Z, gloveColor)
        end
        -- index finger laid along the frame above the guard (trigger discipline reads naturally in 1st person)
        Cyl("Vm" .. side .. "Index", 0.25, FINGER, P(w / 2 + 0.03, 0.1, -d / 2 - 0.07) * ALONG_Z, gloveColor)
        -- thumb high on the far side, pointing forward
        Cyl("Vm" .. side .. "Thumb", 0.22, FINGER * 1.05, P(-w / 2 - 0.042, 0.1, -0.03) * CFrame.Angles(0.18, 0, 0) * ALONG_Z, gloveColor)
        local wrist = (H * CFrame.new((w / 2 - 0.01) * m, -0.15, d / 2 + 0.03)).Position
        Knob("Vm" .. side .. "WristJoint", 0.24, wrist, gloveColor)
        Forearm(side, wrist, shoulder)
    end

    -- Left hand under a handguard/tube. S = frame at the underside center of the handguard.
    local function SupportHand(S: CFrame, ws: number, hs: number)
        Box("VmLeftPalm", Vector3.new(ws + 0.07, 0.085, 0.31), S * CFrame.new(0, -0.045, 0.02), gloveColor)
        local fingerLen = math.clamp(hs * 0.75, 0.12, 0.26)
        for i, zo in ipairs({ -0.12, -0.04, 0.04, 0.12 }) do
            Cyl("VmLeftFinger" .. i, fingerLen, FINGER, S * CFrame.new(ws / 2 + FINGER * 0.45, fingerLen / 2 - 0.03, zo) * ALONG_Y, gloveColor)
        end
        Box("VmLeftKnuckles", Vector3.new(0.02, 0.07, 0.3), S * CFrame.new(ws / 2 + FINGER + 0.005, 0.0, 0.0), gloveAccent, knuckleMat)
        Cyl("VmLeftThumb", 0.24, FINGER * 1.05, S * CFrame.new(-ws / 2 - FINGER * 0.45, hs * 0.35, -0.04) * ALONG_Z, gloveColor)
        Box("VmLeftHeel", Vector3.new(0.09, 0.15, 0.2), S * CFrame.new(-ws / 2 - 0.03, 0.02, 0.08), gloveColor)
        local wrist = (S * CFrame.new(-ws / 2 + 0.02, -0.11, 0.17)).Position
        Knob("VmLeftWristJoint", 0.24, wrist, gloveColor)
        Forearm("Left", wrist, VM_LEFT_SHOULDER)
    end

    -- Two-handed pistol hold: the left hand cups the right from the far side and in front.
    local function CupHand(H: CFrame, w: number, d: number)
        local function P(x: number, y: number, z: number): CFrame return H * CFrame.new(x, y, z) end
        Box("VmLeftPalm", Vector3.new(0.085, 0.29, d + 0.1), P(-w / 2 - 0.13, -0.1, 0.0), gloveColor)
        for i, yo in ipairs({ -0.09, -0.17, -0.25 }) do
            Cyl("VmLeftFinger" .. i, w + 0.28, FINGER, P(0.0, yo, -d / 2 - FINGER * 1.5), gloveColor)
        end
        Box("VmLeftKnuckles", Vector3.new(0.02, 0.11, d * 0.7), P(-w / 2 - 0.18, -0.1, 0.0), gloveAccent, knuckleMat)
        Cyl("VmLeftThumb", 0.24, FINGER * 1.05, P(-w / 2 - 0.1, 0.04, -0.11) * CFrame.Angles(0.1, 0, 0) * ALONG_Z, gloveColor)
        local wrist = (H * CFrame.new(-w / 2 - 0.12, -0.26, d / 2 - 0.02)).Position
        Knob("VmLeftWristJoint", 0.24, wrist, gloveColor)
        Forearm("Left", wrist, VM_LEFT_SHOULDER)
    end

    local gunMesh = WeaponMeshes.Guns[baseId]
    if useRealRig then
        -- nothing: the real rig above is the gun and the arms
    elseif gunMesh then
        local rot = GetMeshRotationFix(baseId)
        local ext = RotatedExtents(rot, GetMeshNativeSize(gunMesh))
        local maxDim = math.max(ext.X, ext.Y, ext.Z, 0.05)
        local fitScale, fitOffset = GetMeshFit(baseId)
        local target = (VM_LENGTH_OVERRIDE[baseId] or VM_CLASS_LENGTH[weaponClass] or 2.4) * fitScale
        local k = target / maxDim
        local rig = GetGunRig(baseId)
        if rig and type(rig.Ext) == "table" then
            -- Use the probe's own extents so its positions and our scale agree exactly.
            local rigMax = math.max(rig.Ext[1], rig.Ext[2], rig.Ext[3], 0.05)
            k = target / rigMax
            ext = Vector3.new(rig.Ext[1], rig.Ext[2], rig.Ext[3])
        end
        ext = ext * k
        local L, H = ext.Z, ext.Y
        local pistolLike = (weaponClass == "Pistol" or weaponClass == "Revolver")
        local layout = VM_HAND_LAYOUT[weaponClass] or VM_HAND_LAYOUT.Rifle

        -- Grip point (gun space = mesh bounds center, viewmodel axes), its size, and its rake.
        local grip = rig and V3(rig.Grip, k)
        -- The probe posed mirrored meshes as a rotation; the SpecialMesh we draw them with is the true
        -- mirror, i.e. the probe's picture flipped across the sideways axis.
        local gs = gunMesh.Scale
        local flipX = (gs.X * gs.Y * gs.Z) < 0 and -1 or 1
        if grip then grip = Vector3.new(grip.X * flipX, grip.Y, grip.Z) end
        local gripW = rig and rig.GripW and rig.GripW * k or nil
        local gripD = rig and rig.GripD and rig.GripD * k or nil
        local rake = rig and rig.Rake or nil
        if not grip then
            grip = Vector3.new(0, layout.Grip.Y * H, layout.Grip.X * L)
        end
        if baseId == "HuntersBow" then
            grip = Vector3.new(0, 0, 0)
            gripW, gripD, rake = 0.13, 0.18, 0.05
        end
        -- A little clearance over the measured grip so glove geometry wraps the surface instead of
        -- sinking into it (the probe measures the bare mesh at one row; grips flare and texture bulges).
        gripW = math.clamp((gripW or math.min(ext.X * 0.55, 0.2)) + 0.03, 0.12, 0.34)
        gripD = math.clamp((gripD or (pistolLike and 0.2 or 0.17)) + 0.025, 0.15, 0.42)
        rake = math.clamp(rake or (pistolLike and 0.3 or 0.35), -0.2, 0.65)

        local gunOffset = -grip + fitOffset -- gun center in anchor space
        local gripFrame = CFrame.Angles(-rake, 0, 0) -- right-hand frame at the anchor, tilted with the grip

        if baseId == "DualDeagle" then
            -- Akimbo: one gun per hand, the left one mirrored across the screen.
            local leftShift = Vector3.new(-1.18, 0, 0)
            MakeVmMeshPart("R_GunBody", gunMesh, CFrame.new(gunOffset) * rot, k, nil, true)
            MakeVmMeshPart("L_GunBody", gunMesh, CFrame.new(gunOffset + leftShift) * rot, k, nil, true)
            GripHand("Right", gripFrame, gripW, gripD, VM_RIGHT_SHOULDER, 1)
            GripHand("Left", CFrame.new(leftShift) * gripFrame, gripW, gripD, VM_LEFT_SHOULDER, -1)
        else
            MakeVmMeshPart("GunBody", gunMesh, CFrame.new(gunOffset) * rot, k, nil, true)
            GripHand("Right", gripFrame, gripW, gripD, VM_RIGHT_SHOULDER, 1)
            if baseId == "HuntersBow" then
                -- Draw hand pulled back on the string behind the bow grip.
                local draw = Vector3.new(-0.02, 0.02, 0.7)
                Knob("VmLeftFist", 0.26, draw, gloveColor)
                Knob("VmLeftWristJoint", 0.24, draw + Vector3.new(-0.05, -0.08, 0.12), gloveColor)
                Forearm("Left", draw + Vector3.new(-0.05, -0.08, 0.12), VM_LEFT_SHOULDER)
            elseif pistolLike then
                CupHand(gripFrame, gripW, gripD)
            else
                local support = rig and V3(rig.Support, k)
                if support then support = Vector3.new(support.X * flipX, support.Y, support.Z) end
                local ws = rig and rig.SupportW and rig.SupportW * k or nil
                local hs = rig and rig.SupportH and rig.SupportH * k or nil
                if not support then
                    local sup = layout.Support or Vector2.new(-0.24, -0.18)
                    support = Vector3.new(0, sup.Y * H, sup.X * L)
                end
                ws = math.clamp((ws or math.min(ext.X * 0.6, 0.22)) + 0.035, 0.12, 0.45)
                hs = math.clamp(hs or H * 0.3, 0.1, 0.5)
                SupportHand(CFrame.new(support + gunOffset + Vector3.new(0, -0.02, 0)), ws, hs)
            end
        end

        -- Muzzle flash at the gun's real front end.
        local muzzle = rig and V3(rig.Muzzle, k) or Vector3.new(0, 0.18 * H, -0.5 * L)
        muzzle = Vector3.new(muzzle.X * flipX, muzzle.Y, muzzle.Z)
        local flash = MakeVmPart("EnergyCore", Vector3.new(0.3, 0.3, 0.3), CFrame.new(muzzle + gunOffset + Vector3.new(0, 0, -0.08)), accentColor, Enum.Material.Neon)
        flash.Shape = Enum.PartType.Ball
        flash.Transparency = 1 -- hidden until a shot briefly flashes it visible
        muzzleFlashPart = flash
    else
        -- DEFAULT FALLBACK for any future/unmapped baseId -- procedural placeholder gun.
        MakeVmPart("GunBody", Vector3.new(0.25, 0.5, 1.4), CFrame.new(0, 0.28, -0.35), Color3.fromRGB(60, 62, 70), Enum.Material.Metal)
        MakeVmPart("GunBarrel", Vector3.new(0.16, 0.16, 0.9), CFrame.new(0, 0.38, -1.4), Color3.fromRGB(45, 47, 52), Enum.Material.Metal)
        local gf = CFrame.Angles(-0.3, 0, 0)
        GripHand("Right", gf, 0.16, 0.2, VM_RIGHT_SHOULDER, 1)
        CupHand(gf, 0.16, 0.2)
        local holo = MakeVmPart("EnergyCore", Vector3.new(0.25, 0.25, 0.25), CFrame.new(0, 0.38, -1.9), accentColor, Enum.Material.Neon)
        holo.Transparency = 1
        muzzleFlashPart = holo
    end

    -- Real-mesh melee weapon -- rebuilt alongside the gun (so it survives weapon switches) but rendered
    -- and positioned entirely separately by the render loop: hidden while shooting, swapped in for the
    -- swing arc during a melee attack. Which mesh shows depends on clientState.EquippedKnife.
    local knifeId = clientState.EquippedKnife or "Knife"
    local knifeMesh = WeaponMeshes.Melee[knifeId] or WeaponMeshes.Melee.Crowbar
    local knifeRotFix = GetMeshRotationFix(WeaponMeshes.Melee[knifeId] and knifeId or "Crowbar")
    local knifeExt = RotatedExtents(knifeRotFix, GetMeshNativeSize(knifeMesh))
    local knifeK = 1.6 / math.max(knifeExt.X, knifeExt.Y, knifeExt.Z, 0.05)
    local meleePart, meleeOffset = MakeVmMeshPart("MeleeWeaponMesh", knifeMesh, knifeRotFix, knifeK, 3, false)
    meleePart:SetAttribute("IsMelee", true)
    meleePart.LocalTransparencyModifier = 1 -- hidden until a melee swing is actually playing
    vmKnifeParts = { { Part = meleePart, Offset = meleeOffset } }
end

-- Re-lay-out the viewmodel once the server's mesh measurements / grip probes arrive (they stream in over
-- the first seconds after join), coalesced so ~90 attribute updates cause at most a couple rebuilds.
task.spawn(function()
    local folder = sharedFolder:WaitForChild("MeshBounds", 30)
    if not folder then return end
    local pending = false
    local function Refresh()
        if pending then return end
        pending = true
        task.delay(0.6, function()
            pending = false
            local w = vmTuneActiveWeapon or clientState.EquippedWeapon
            if w and ViewmodelRig.HasRig(w.BaseId) then return end -- real rigs don't use the probe data
            if viewmodel and w then RebuildViewmodelForWeapon(w) end
        end)
    end
    folder.AttributeChanged:Connect(Refresh)
    local templatesFolder = sharedFolder:WaitForChild("MeshTemplates", 30)
    if templatesFolder then templatesFolder.ChildAdded:Connect(Refresh) end
    Refresh()
end)

-- Chill (from Frozen enemies) slows you: re-applied whenever the server changes ChillMult.
local baseMoveSpeedMult = 1
local MeleeDataHUD = require(sharedFolder:WaitForChild("MeleeData"))
LocalPlayer:GetAttributeChangedSignal("ChillMult"):Connect(function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        -- (MovementController builds momentum on top of this base speed and owns hum.WalkSpeed)
        hum:SetAttribute("BaseWalkSpeed", 16 * baseMoveSpeedMult * (LocalPlayer:GetAttribute("ChillMult") or 1))
        hum.WalkSpeed = hum:GetAttribute("BaseWalkSpeed")
    end
end)

-- Status chips (bottom-left, above the level panel): what enemy elements are doing to you right now.
do
    local bar = Instance.new("Frame")
    bar.Name = "StatusChips"
    bar.AnchorPoint = Vector2.new(0, 1)
    bar.Size = UDim2.new(0, 260, 0, 22)
    bar.Position = UDim2.new(0, UI.HudStack.X, 1, UI.HudStack.TopY - 2) -- (the row above the HUD stack, left end)
    bar.BackgroundTransparency = 1
    bar.Parent = hudGui
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Horizontal
    list.Padding = UDim.new(0, 6)
    list.Parent = bar
    local defs = {
        -- (UPDATE 8 DEFENCE: the five damage types' ailments on you)
        { Attr = "Burning", Text = "BURNING", Color = Color3.fromRGB(255, 120, 40), Tip = "Taking Heat damage over time. Heat Resistance helps." },
        { Attr = "Chilled", Text = "CHILLED", Color = Color3.fromRGB(110, 200, 255), Tip = "Moving slower. Cryo Resistance weakens the slow." },
        { Attr = "Bleeding", Text = "BLEEDING", Color = Color3.fromRGB(220, 40, 60), Tip = "Taking Kinetic damage over time." },
        { Attr = "Shocked", Text = "SHOCKED", Color = Color3.fromRGB(255, 225, 60), Tip = "Taking increased damage for a moment. Volt Resistance weakens it." },
        { Attr = "Withered", Text = "WITHERED", Color = Color3.fromRGB(175, 95, 255), Tip = "Taking increased damage, more with each stack. Void Resistance weakens it." },
    }
    for i, d in ipairs(defs) do
        local chip = Instance.new("TextLabel")
        chip.Size = UDim2.new(0, 0, 1, 0)
        chip.AutomaticSize = Enum.AutomaticSize.X -- (Update 5: fits its word at the 12 px floor)
        chip.BackgroundColor3 = d.Color:Lerp(Color3.new(0, 0, 0), 0.62)
        chip.TextColor3 = d.Color
        chip.Font = Enum.Font.GothamBlack
        chip.TextSize = 12
        chip.Text = d.Text
        local cpad = Instance.new("UIPadding"); cpad.PaddingLeft = UDim.new(0, 8); cpad.PaddingRight = UDim.new(0, 8); cpad.Parent = chip
        chip.LayoutOrder = i
        chip.Visible = false
        chip.Parent = bar
        RoundCorners(chip, 4)
        local function Upd()
            chip.Visible = LocalPlayer:GetAttribute(d.Attr) == true
            if d.Attr == "Withered" then chip.Text = d.Text .. ((LocalPlayer:GetAttribute("WitherStacks") or 1) > 1 and (" x" .. tostring(LocalPlayer:GetAttribute("WitherStacks"))) or "") end
        end
        LocalPlayer:GetAttributeChangedSignal(d.Attr):Connect(Upd)
        if d.Attr == "Withered" then LocalPlayer:GetAttributeChangedSignal("WitherStacks"):Connect(Upd) end
        Upd()
    end
end
-- QOL L5 (2026-10-28): BAG chip -- first in the status-chip row while a run is on and the bag is >= 85% full ("BAG 52/60",
-- amber; red "BAG FULL 60/60"). Recounted on state syncs / bag lines / run start + end only (no per-frame work).
;(function()
    local bar = hudGui:FindFirstChild("StatusChips")
    if not bar then return end
    local chip = Instance.new("TextLabel")
    chip.Name = "BagChip"
    chip.Size = UDim2.new(0, 0, 1, 0)
    chip.AutomaticSize = Enum.AutomaticSize.X
    chip.Font = Enum.Font.GothamBlack
    chip.TextSize = 12
    chip.LayoutOrder = 0
    chip.Visible = false
    local cpad = Instance.new("UIPadding"); cpad.PaddingLeft = UDim.new(0, 8); cpad.PaddingRight = UDim.new(0, 8); cpad.Parent = chip
    chip.Parent = bar
    RoundCorners(chip, 4)
    local AMBER, RED = Color3.fromRGB(255, 196, 70), Color3.fromRGB(255, 92, 80)
    local queued = false
    local function Upd()
        queued = false
        local inRun = LocalPlayer:GetAttribute("Lives") ~= nil or LocalPlayer:GetAttribute("RunId") ~= nil
        local n, cap = ItemData.BagCount(clientState), ItemData.BagCap(clientState)
        if not inRun or cap <= 0 or n < cap * 0.85 then chip.Visible = false; return end
        local full = n >= cap
        local col = full and RED or AMBER
        chip.Text = (full and "BAG FULL " or "BAG ") .. n .. "/" .. cap
        chip.TextColor3 = col
        chip.BackgroundColor3 = col:Lerp(Color3.new(0, 0, 0), 0.62)
        chip.Visible = true
    end
    local function Queue() if not queued then queued = true; task.defer(Upd) end end
    UI.BagChipRefresh = Queue
    Remotes.GetEvent("SyncPlayerState").OnClientEvent:Connect(Queue)
    Remotes.GetEvent("LootAnnounce").OnClientEvent:Connect(Queue)
    LocalPlayer:GetAttributeChangedSignal("Lives"):Connect(Queue)
    LocalPlayer:GetAttributeChangedSignal("RunId"):Connect(Queue)
    Queue()
end)()

-- Build chips (above the status chips): passive-tree / gem conditions, lit while they're active, so you
-- can see your build working (Run and Gun while moving, Last Rounds near the end of a mag, Undying ready...).
do
    local bar = Instance.new("Frame")
    bar.Name = "BuildChips"
    bar.AnchorPoint = Vector2.new(0, 1)
    bar.Size = UDim2.new(0, 400, 0, 22)
    bar.Position = UDim2.new(0, UI.HudStack.X, 1, UI.HudStack.TopY - 30)
    bar.BackgroundTransparency = 1
    bar.Parent = hudGui
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Horizontal
    list.Padding = UDim.new(0, 6)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = bar
    local function Moving(): boolean
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return false end
        local v = (root :: BasePart).AssemblyLinearVelocity
        return Vector3.new(v.X, 0, v.Z).Magnitude >= 1.5
    end
    local function Pct(v: number): string return tostring(math.round(v * 100)) .. "%" end
    -- Has(stats) = the build cares about it; Active(stats) = lit right now; Text(stats, on) = label
    local defs = {
        { Color = Color3.fromRGB(120, 255, 160),
            Has = function(st) return (st.Cond.MovingDamage or 0) > 0 or st.SpecialMechanics.RUN_AND_GUN == true end,
            Active = function() return Moving() end,
            Text = function(st) return "MOVING" .. (((st.Cond.MovingDamage or 0) > 0) and (" +" .. Pct(st.Cond.MovingDamage)) or "") end },
        { Color = Color3.fromRGB(255, 220, 120),
            Has = function(st) return (st.Cond.StillDamage or 0) > 0 or (st.Cond.StillDR or 0) > 0 or st.SpecialMechanics.ENTRENCHED == true end,
            Active = function() return not Moving() end,
            Text = function(st) return "BRACED" .. (((st.Cond.StillDamage or 0) > 0) and (" +" .. Pct(st.Cond.StillDamage)) or "") end },
        { Color = Color3.fromRGB(255, 150, 90),
            Has = function(st) return (st.Cond.LastMagDamage or 0) > 0 end,
            Active = function(st)
                local m = clientState.MaxMag or st.MagazineSize
                return (clientState.CurrentMag or m) <= math.floor(m * 0.3)
            end,
            Text = function(st) return "LAST ROUNDS +" .. Pct(st.Cond.LastMagDamage) end },
        { Color = Color3.fromRGB(255, 110, 110),
            Has = function(st) return (st.Cond.LowLifeDR or 0) > 0 end,
            Active = function() return (clientState.Health or 1) < (clientState.MaxHealth or 1) * 0.5 end,
            Text = function(st) return "LAST STAND -" .. Pct(st.Cond.LowLifeDR) .. " DMG TAKEN" end },
        { Color = Color3.fromRGB(255, 120, 200),
            Has = function(st) return st.SpecialMechanics.UNDYING == true end,
            Active = function() return workspace:GetServerTimeNow() >= (LocalPlayer:GetAttribute("UndyingReadyAt") or 0) end,
            Text = function(_, on)
                if on then return "UNDYING READY" end
                return "UNDYING " .. math.ceil((LocalPlayer:GetAttribute("UndyingReadyAt") or 0) - workspace:GetServerTimeNow()) .. "s"
            end },
    }
    local chips = {}
    for i in ipairs(defs) do
        local chip = Instance.new("TextLabel")
        chip.Size = UDim2.new(0, 0, 1, 0)
        chip.AutomaticSize = Enum.AutomaticSize.X
        chip.Font = Enum.Font.GothamBlack
        chip.TextSize = 10
        chip.LayoutOrder = i
        chip.Visible = false
        chip:SetAttribute("NoSkin", true)
        local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 7); pad.PaddingRight = UDim.new(0, 7); pad.Parent = chip
        local stroke = Instance.new("UIStroke"); stroke.Thickness = 1; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.Parent = chip
        chip.Parent = bar
        RoundCorners(chip, 4)
        chips[i] = { Chip = chip, Stroke = stroke }
    end
    task.spawn(function()
        while true do
            task.wait(0.2)
            local st = UI.lastHudStats
            if st and st.Cond then
                for i, d in ipairs(defs) do
                    local c = chips[i]
                    local has = d.Has(st)
                    c.Chip.Visible = has
                    if has then
                        local on = d.Active(st)
                        c.Chip.Text = d.Text(st, on)
                        c.Chip.TextColor3 = on and d.Color or d.Color:Lerp(Color3.fromRGB(90, 90, 100), 0.65)
                        c.Chip.BackgroundColor3 = on and d.Color:Lerp(Color3.new(0, 0, 0), 0.6) or Color3.fromRGB(18, 20, 26)
                        c.Chip.BackgroundTransparency = on and 0.05 or 0.35
                        c.Stroke.Color = on and d.Color or Color3.fromRGB(50, 55, 66)
                    end
                end
            end
        end
    end)
end

-- Run boons: a Boon Shrine or a boss floor offers 3 (clientState.BoonOffer); pick with 1 / 2 / 3 (or click
-- with the cursor free). UIStyle look: gradient cards, chunky outlined FredokaOne text, rarity ribbons,
-- bouncy pop-in. The run's boons and their "heat" show as chips under the dungeon banner.
do
    local BoonData = require(sharedFolder:WaitForChild("BoonData"))
    local TweenSvc = game:GetService("TweenService")
    local UC = UIStyle.Colors

    local panel = UIStyle.New("Frame", {
        Name = "BoonOffer", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -140),
        Size = UDim2.fromOffset(720, 288), BackgroundTransparency = 1, Visible = false, ZIndex = 30, Parent = hudGui, -- (taller for combo lines)
    })
    panel:SetAttribute("UIStyled", true)
    UI.boonPanel = panel -- (while it's open, 1/2/3 pick a boon and don't switch weapons -- see the weapon-slot actions)
    local pop = UIStyle.New("UIScale", { Parent = panel })
    -- header ribbon
    local ribbon = UIStyle.New("Frame", { Size = UDim2.fromOffset(360, 40), Position = UDim2.new(0.5, -180, 0, 0), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 31, Parent = panel }, { UIStyle.Corner(12) })
    UIStyle.Gradient(UIStyle.Lighten(UC.Purple, 0.15), UIStyle.Darken(UC.Purple, 0.3)).Parent = ribbon
    UIStyle.Stroke(UC.Border, 3).Parent = ribbon
    local ribbonText = UIStyle.Text({ Size = UDim2.fromScale(1, 1), Text = "CHOOSE A BOON", TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, Stroke = 2.5, ZIndex = 32, Parent = ribbon })
    UIStyle.Text({ Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 44), Text = (GameSettings.TouchOnly() and "Tap a card" or "Press 1, 2 or 3") .. "   •   lasts this run   •   each boon makes enemies 6% tougher",
        Font = UIStyle.BodyFont, TextSize = 13, TextColor3 = UC.Sub, TextXAlignment = Enum.TextXAlignment.Center, Stroke = 1.5, ZIndex = 31, Parent = panel })

    local cards = {}
    for i = 1, 3 do
        local card = UIStyle.New("TextButton", {
            Name = "Card" .. i, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1),
            Size = UDim2.fromOffset(228, 214), Position = UDim2.fromOffset((i - 1) * 246, 70), ZIndex = 31, Parent = panel,
        }, { UIStyle.Corner(16) })
        local grad = UIStyle.Gradient(UC.Card, UC.CardDark)
        grad.Parent = card
        local stroke = UIStyle.Stroke(UC.Border, 3)
        stroke.Parent = card
        UIStyle.Hover(card, 0.04)
        -- rarity band across the top
        local band = UIStyle.New("Frame", { Size = UDim2.new(1, -10, 0, 30), Position = UDim2.fromOffset(5, 5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 32, Parent = card }, { UIStyle.Corner(11) })
        local bandGrad = UIStyle.Gradient(UC.Blue, UC.Blue)
        bandGrad.Parent = band
        local keyBadge = UIStyle.New("Frame", { Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0, -2, 0, 0), BackgroundColor3 = UC.Border, ZIndex = 33, Parent = band }, { UIStyle.Corner(10) })
        UIStyle.Text({ Size = UDim2.fromScale(1, 1), Text = tostring(i), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 34, Parent = keyBadge })
        local rarity = UIStyle.Text({ Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(36, 0), Text = "", TextSize = 15, Stroke = 2, ZIndex = 33, Parent = band })
        local name = UIStyle.Text({ Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(12, 40), Text = "", TextSize = 21, TextWrapped = true, Stroke = 2.5, ZIndex = 32, Parent = card })
        local body = UIStyle.Text({ Size = UDim2.new(1, -24, 1, -80), Position = UDim2.fromOffset(12, 74), Text = "", Font = UIStyle.BodyFont, TextSize = 14,
            TextColor3 = Color3.fromRGB(225, 232, 248), TextWrapped = true, RichText = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 32, Parent = card })
        cards[i] = { Card = card, Stroke = stroke, BandGrad = bandGrad, Rarity = rarity, Name = name, Body = body }
    end

    -- run tray: one chip per boon (x2 when stacked) + the heat chip
    -- (y 176: under the floor modifiers / objective lines -- at 104 it sat under the SAFE ZONE banner)
    local tray = UIStyle.New("Frame", { Name = "BoonTray", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 176),
        Size = UDim2.fromOffset(900, 24), BackgroundTransparency = 1, Visible = false, Parent = hudGui })
    tray:SetAttribute("UIStyled", true)
    UIStyle.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tray })
    local function TrayChip(text: string, color: Color3, order: number)
        local chip = UIStyle.New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order, Parent = tray }, {
            UIStyle.Corner(12), UIStyle.New("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }),
        })
        UIStyle.Gradient(UC.Card, UC.CardDark).Parent = chip
        UIStyle.Stroke(UIStyle.Darken(color, 0.2), 2).Parent = chip
        UIStyle.Text({ Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextSize = 13, TextColor3 = color, Stroke = 1.5, Parent = chip })
    end

    local choosing = false
    local function Choose(i: number)
        local offer = clientState.BoonOffer
        if choosing or not offer or not offer[i] then return end
        choosing = true
        local c = cards[i]
        TweenSvc:Create(c.Card:FindFirstChildOfClass("UIScale") or UIStyle.New("UIScale", { Parent = c.Card }), TweenInfo.new(0.12), { Scale = 1.12 }):Play()
        local ok, msg = Remotes.GetFunction("ChooseBoon"):InvokeServer(i)
        choosing = false
        if ok then
            SoundHelper.Play("Upgrade")
            ShowToast("Boon gained: " .. tostring(msg))
        end
    end
    for i, c in ipairs(cards) do
        c.Card.MouseButton1Click:Connect(function() Choose(i) end)
    end
    UserInputService.InputBegan:Connect(function(input)
        if not panel.Visible or GameSettings.IsTyping() then return end
        local idx = (input.KeyCode == Enum.KeyCode.One and 1) or (input.KeyCode == Enum.KeyCode.Two and 2) or (input.KeyCode == Enum.KeyCode.Three and 3)
        if idx then Choose(idx) end
    end)

    function UI.RefreshBoons()
        local offer = clientState.BoonOffer
        local shown = offer ~= nil and #offer > 0
        if shown and not panel.Visible then
            SoundHelper.Play("Loot")
            local k = UIStyle.PhoneBoostK(panel, 720, 288) -- (phones: the cards at the phone window scale, not the HUD's 0.55)
            pop.Scale = 0.8 * k
            TweenSvc:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = k }):Play()
        end
        panel.Visible = shown
        if shown then
            for i, c in ipairs(cards) do
                local b = BoonData.ById[offer[i] or ""]
                c.Card.Visible = b ~= nil
                local sc = c.Card:FindFirstChildOfClass("UIScale")
                if sc then sc.Scale = 1 end
                if b then
                    local col = BoonData.RarityColors[b.Rarity] or Color3.new(1, 1, 1)
                    c.Stroke.Color = UIStyle.Darken(col, 0.25)
                    c.Stroke.Thickness = (b.Rarity == "Common") and 3 or 4
                    c.BandGrad.Color = ColorSequence.new(UIStyle.Lighten(col, 0.1), UIStyle.Darken(col, 0.35))
                    c.Rarity.Text = string.upper(b.Rarity)
                    c.Name.Text = b.Name
                    c.Name.TextColor3 = UIStyle.Lighten(col, 0.35)
                    c.Body.Text = table.concat(BoonData.Lines(b.Id, ItemData.FormatStat), "\n")
                        .. ((b.Rarity == "Cursed") and "\n\nA big upside with a real cost." or "")
                    -- (boon combos: this pick would finish one -- say which, and what it adds)
                    for _, combo in ipairs(BoonData.CombosCompletedBy(b.Id, clientState.RunBoons)) do
                        local lines = {}
                        local keys = {}
                        for kk in pairs(combo.Stats) do table.insert(keys, kk) end
                        table.sort(keys)
                        for _, kk in ipairs(keys) do table.insert(lines, ItemData.FormatStat(kk, combo.Stats[kk])) end
                        c.Body.Text ..= string.format('\n\n<font color="#%s">COMBO: %s</font>\n%s', BoonData.COMBO_COLOR:ToHex(), string.upper(combo.Name), table.concat(lines, "\n"))
                    end
                end
            end
        end
        for _, ch in ipairs(tray:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
        local owned = clientState.RunBoons or {}
        tray.Visible = #owned > 0
        if #owned > 0 then
            local counts, order = {}, {}
            for _, id in ipairs(owned) do
                if not counts[id] then table.insert(order, id) end
                counts[id] = (counts[id] or 0) + 1
            end
            for i, id in ipairs(order) do
                local b = BoonData.ById[id]
                TrayChip((b and b.Name or id) .. ((counts[id] > 1) and (" x" .. counts[id]) or ""), b and BoonData.RarityColors[b.Rarity] or UC.Sub, i)
            end
            for ci, combo in ipairs(BoonData.ActiveCombos(owned)) do
                TrayChip("COMBO: " .. combo.Name, BoonData.COMBO_COLOR, 500 + ci)
            end
            TrayChip(string.format("ENEMIES +%d%% HP  (%d/%d)", math.round(#owned * BoonData.HEAT_PER_BOON * 100), #owned, BoonData.MAX_BOONS), UC.Red, 999)
        end
    end
end

-- Shrine of Precision countdown (run folder TrialUntil / TrialKills).
do
    local DungeonEvents = require(sharedFolder:WaitForChild("DungeonEvents"))
    local lbl = UIStyle.Text({ Name = "TrialHUD", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.32, 0), Size = UDim2.fromOffset(600, 40),
        Text = "", TextSize = 30, TextColor3 = Color3.fromRGB(120, 230, 255), TextXAlignment = Enum.TextXAlignment.Center, Stroke = 3, Visible = false, Parent = hudGui })
    lbl:SetAttribute("UIStyled", true)
    task.spawn(function()
        local f = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("AimRngRun", math.huge)
        while true do
            task.wait(0.1)
            local untilT = f:GetAttribute("TrialUntil") or 0
            local left = untilT - workspace:GetServerTimeNow()
            if untilT > 0 and left > 0 then
                lbl.Visible = true
                lbl.Text = string.format("PRECISION TRIAL  %.1fs   •   %d / %d WEAK-SPOT KILLS", left, f:GetAttribute("TrialKills") or 0, DungeonEvents.TRIAL_TARGETS)
            else
                lbl.Visible = false
            end
        end
    end)
end

-- Loot Storm banner (workspace LootStormUntil / NextLootStorm, see EndgameServer): live countdown, and a heads-up
-- in the last 2 minutes before the next one.
do
    local lbl = UIStyle.Text({ Name = "LootStormBanner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 188), Size = UDim2.fromOffset(640, 26),
        Text = "", TextSize = 20, TextColor3 = UIStyle.Colors.Text, TextXAlignment = Enum.TextXAlignment.Center, Stroke = 2.5, Visible = false, Parent = hudGui })
    lbl:SetAttribute("UIStyled", true)
    UI.RunHud.Line(lbl) -- (UI CLEAN R-C: the HUD plate; words in Text -- gold is for currency only)
    task.spawn(function()
        while true do
            task.wait(0.25)
            local now = workspace:GetServerTimeNow()
            local untilT = workspace:GetAttribute("LootStormUntil") or 0
            local nextT = workspace:GetAttribute("NextLootStorm") or 0
            if now < untilT then
                lbl.Visible = true
                lbl.TextColor3 = UIStyle.Colors.Text
                local left = math.floor(untilT - now)
                lbl.Text = string.format("LOOT STORM  %d:%02d   •   +50%% loot luck, XP and gold   •   double gems", left // 60, left % 60)
            elseif nextT > now and nextT - now <= 120 then
                lbl.Visible = true
                lbl.TextColor3 = UIStyle.Colors.Sub
                local left = math.floor(nextT - now)
                lbl.Text = string.format("Loot Storm in %d:%02d", left // 60, left % 60)
            else
                lbl.Visible = false
            end
            -- (2026-10-22 autoplay test: the DUNGEON CLEARED popup sits over this line + the City Broadcast one: text on text)
            if lbl.Visible and UI.victoryBanner and UI.victoryBanner.Visible then lbl.Visible = false end
        end
    end)
end

-- WORLD ALERTS banner (UPDATE 7 B7, WorldAlerts: the same alert in every server): running = name + time left + what it does;
-- the last 10 minutes before one = a heads-up. Under the Loot Storm line.
do
    local WA = require(sharedFolder:WaitForChild("WorldAlerts"))
    local lbl = UIStyle.Text({ Name = "WorldAlertBanner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 216), Size = UDim2.fromOffset(760, 24),
        Text = "", TextSize = 18, TextColor3 = UIStyle.Colors.Text, TextXAlignment = Enum.TextXAlignment.Center, Stroke = 2.5, Visible = false, Parent = hudGui })
    lbl:SetAttribute("UIStyled", true)
    UI.RunHud.Line(lbl) -- (UI CLEAN R-C: the HUD plate)
    task.spawn(function()
        while true do
            task.wait(0.5)
            local now = workspace:GetServerTimeNow()
            local a = WA.Current(now)
            local zc = UI.Zen and UI.Zen.Call(now) -- (CHASE ITEMS: "<player> found ZENITH <name>" takes the line for a few seconds)
            if zc then
                lbl.Visible = true
                lbl.TextColor3 = ItemData.ZENITH_COLOR
                lbl.Text = zc
            elseif a then
                local left = math.max(0, math.floor(a.End - now))
                lbl.Visible = true
                lbl.TextColor3 = UIStyle.Colors.Text
                lbl.Text = string.format("CITY BROADCAST: %s  %d:%02d   •   %s", WA.Defs[a.Id].Name, left // 60, left % 60, WA.Text(a))
            else
                local n = WA.Next(now)
                if n and n.Start - now <= WA.LEAD then
                    local left = math.floor(n.Start - now)
                    lbl.Visible = true
                    lbl.TextColor3 = UIStyle.Colors.Sub
                    lbl.Text = string.format("City Broadcast in %d:%02d: %s", left // 60, left % 60, WA.Defs[n.Id].Name)
                else
                    lbl.Visible = false
                end
            end
            if lbl.Visible and UI.victoryBanner and UI.victoryBanner.Visible then lbl.Visible = false end -- (under the DUNGEON CLEARED popup)
        end
    end)
end

-- Daily Challenge clock (run folder Daily / DailyStart), right under the dungeon banner area.
do
    local DailyChallenge = require(sharedFolder:WaitForChild("DailyChallenge"))
    local lbl = UIStyle.Text({ Name = "DailyClock", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 160), Size = UDim2.fromOffset(500, 30),
        Text = "", TextSize = 24, TextColor3 = UIStyle.Colors.Text, TextXAlignment = Enum.TextXAlignment.Center, Stroke = 2.5, Visible = false, Parent = hudGui })
    lbl:SetAttribute("UIStyled", true)
    UI.RunHud.Line(lbl) -- (UI CLEAN R-C: the HUD plate; the clock in Text, Warn only once over time)
    task.spawn(function()
        local f = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("AimRngRun", math.huge)
        while true do
            task.wait(0.1)
            local start = f:GetAttribute("DailyStart") or 0
            local on = f:GetAttribute("Daily") == true and start > 0 and f:GetAttribute("RaidActive") == true
            local riftTier = f:GetAttribute("Rift") or 0
            local riftStart = f:GetAttribute("RiftStart") or 0
            local riftOn = riftTier > 0 and riftStart > 0 and f:GetAttribute("RaidActive") == true
            lbl.Visible = on or riftOn
            if on then
                lbl.TextColor3 = UIStyle.Colors.Text
                lbl.Text = string.format("DAILY CHALLENGE  %s   •   FLOOR %d / %d", DailyChallenge.FormatTime(workspace:GetServerTimeNow() - start), f:GetAttribute("Floor") or 1, DailyChallenge.FLOORS)
            elseif riftOn then
                local limit = f:GetAttribute("RiftLimit") or 300
                local used = workspace:GetServerTimeNow() - riftStart
                lbl.TextColor3 = (used > limit) and UIStyle.Colors.Warn or UIStyle.Colors.Text
                lbl.Text = string.format("MAP TIER %d   %s / %s   •   FLOOR %d / 5%s", riftTier, DailyChallenge.FormatTime(used), DailyChallenge.FormatTime(limit),
                    f:GetAttribute("Floor") or 1, (used > limit) and "   (over time)" or "")
            end
        end
    end)
end

-- Floor modifiers (FloorMods): one line under the dungeon banner while a floor has any.
do
    local FloorMods = require(sharedFolder:WaitForChild("FloorMods"))
    local lbl = Instance.new("TextLabel")
    lbl.Name = "FloorModsLabel"
    lbl.AnchorPoint = Vector2.new(0.5, 0)
    lbl.Position = UDim2.new(0.5, 0, 0, 132)
    lbl.RichText = true
    lbl.Visible = false
    lbl.Parent = hudGui
    UI.RunHud.Line(lbl) -- (UI CLEAN R-C: the HUD plate; the mods keep their own colours inside the line)
    local announced = ""
    local function Upd(f: Instance)
        local mods = FloorMods.Parse(f:GetAttribute("Mods"))
        local active = f:GetAttribute("RaidActive") == true and #mods > 0
        lbl.Visible = active
        if not active then announced = ""; return end
        local parts = {}
        for _, id in ipairs(mods) do -- (UPDATE 8 MAPS: 3+ mods (Rare maps) show names only -- the texts ran off the screen; the map device lists them in full)
            local d = FloorMods.Defs[id]
            table.insert(parts, (#mods >= 3) and string.format('<font color="#%s">%s</font>', d.Color:ToHex(), string.upper(d.Name))
                or string.format('<font color="#%s">%s</font>: <font color="#%s">%s</font>', d.Color:ToHex(), string.upper(d.Name), UIStyle.Colors.Sub:ToHex(), FloorMods.TextOf(id, f:GetAttribute("ModScale")))) -- (MAPS V2: the tier's real numbers)
        end
        local bonus = FloorMods.RewardBonus(mods, f:GetAttribute("ModScale"))
        lbl.Text = string.format('<font color="#%s">FLOOR MODIFIERS</font>   ', UIStyle.Colors.Sub:ToHex()) .. table.concat(parts, "   ") .. ((bonus > 0) and string.format('   +%d%% REWARDS', math.round(bonus * 100)) or "")
        local key = (f:GetAttribute("Mods") or "") .. "|" .. tostring(f:GetAttribute("RunToken"))
        if key ~= announced then
            announced = key
            SoundHelper.Play("Click")
        end
    end
    task.spawn(function()
        local f = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("AimRngRun", math.huge)
        for _, a in ipairs({ "Mods", "RaidActive", "RunToken", "ModScale" }) do
            f:GetAttributeChangedSignal(a):Connect(function() Upd(f) end)
        end
        Upd(f)
    end)
end

-- (2026-10-22 autoplay test: on a map's GUARDIAN floor the boss bar, the FLOOR MODIFIERS line and the MAP TIER clock were drawn
-- on top of each other) while a boss bar shows, the HUD's banner lines move down under it (same order, same gaps) and back after
do
    local LINES = { "FloorModsLabel", "FloorObjectiveLabel", "DailyClock", "LootStormBanner", "WorldAlertBanner" }
    task.spawn(function()
        local bars = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("EnemyBars", math.huge)
        while true do
            task.wait(0.2)
            local bottom = nil
            for _, layer in ipairs(bars:GetChildren()) do
                if layer:IsA("Frame") then
                    for _, root in ipairs(layer:GetChildren()) do
                        -- (PLAYTEST 2026-10-31: the boss plate is 56 px x the HUD scale -- 49 px at 0.88 missed the old >= 50 test and the
                        -- FLOOR MODIFIERS line sat on the guardian's bar; any wide plate 36+ px tall counts)
                        if root:IsA("Frame") and root.Visible and root.AnchorPoint.X == 0.5 and root.AbsoluteSize.Y >= 36 and root.AbsoluteSize.X >= 300 then
                            local goal = root:FindFirstChild("Objective")
                            local b = root.AbsolutePosition.Y + 56 + ((goal and goal.Text ~= "") and 26 or 0)
                            bottom = math.max(bottom or 0, b)
                        end
                    end
                end
            end
            local sc = hudGui:FindFirstChildOfClass("UIScale")
            local k = (sc and sc.Scale > 0) and sc.Scale or 1
            -- the topmost showing line's screen y at its BASE offset (the HUD scale doesn't pivot at the top: measure, don't assume)
            local topAbs = math.huge
            for _, n in ipairs(LINES) do
                local o = hudGui:FindFirstChild(n)
                if o and o:IsA("GuiObject") then
                    if o:GetAttribute("BaseY") == nil then o:SetAttribute("BaseY", o.Position.Y.Offset) end
                    if o.Visible then topAbs = math.min(topAbs, o.AbsolutePosition.Y - (o.Position.Y.Offset - o:GetAttribute("BaseY")) * k) end
                end
            end
            local shift = (bottom and topAbs < math.huge) and math.max(0, (bottom + 4 - topAbs) / k) or 0
            for _, n in ipairs(LINES) do
                local o = hudGui:FindFirstChild(n)
                if o and o:IsA("GuiObject") then
                    local y = o:GetAttribute("BaseY") + shift
                    if math.abs(o.Position.Y.Offset - y) > 0.5 then o.Position = UDim2.new(o.Position.X.Scale, o.Position.X.Offset, 0, y) end
                end
            end
        end
    end)
end

-- Floor objective (FloorObjectives): one line under the floor modifiers -- what to do, progress / time left, and
-- DONE / FAILED once it's settled.
do
    local FloorObjectives = require(sharedFolder:WaitForChild("FloorObjectives"))
    local lbl = Instance.new("TextLabel")
    lbl.Name = "FloorObjectiveLabel"
    lbl.AnchorPoint = Vector2.new(0.5, 0)
    lbl.Position = UDim2.new(0.5, 0, 0, 160)
    lbl.RichText = true
    lbl.Visible = false
    lbl.Parent = hudGui
    UI.RunHud.Line(lbl) -- (UI CLEAN R-C: the HUD plate)
    task.spawn(function()
        local f = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("AimRngRun", math.huge)
        while true do
            local id = f:GetAttribute("Objective") or ""
            local def = FloorObjectives.Defs[id]
            local active = f:GetAttribute("RaidActive") == true and def ~= nil
            lbl.Visible = active
            if active then
                local st = f:GetAttribute("ObjState") or ""
                local text = FloorObjectives.Describe(id, f:GetAttribute("ObjNeed"), f:GetAttribute("ObjProgress"))
                local deadline = f:GetAttribute("ObjDeadline") or 0
                if st == "" and deadline > 0 then
                    local left = math.max(0, deadline - workspace:GetServerTimeNow())
                    text ..= string.format("   %d:%02d", math.floor(left / 60), math.floor(left % 60))
                end
                local C2 = UIStyle.Colors -- (UI CLEAN R-C: head Sub, name in its colour, the rest Text; DONE / FAILED in Good / Bad words)
                local tag = (st == "DONE" and string.format('<font color="#%s">   DONE</font>', C2.Good:ToHex())) or (st == "FAILED" and string.format('<font color="#%s">   FAILED</font>', C2.Bad:ToHex()))
                    or string.format('<font color="#%s">   REWARD: %s</font>', C2.Sub:ToHex(), string.upper(tostring(def.Reward)))
                lbl.Text = string.format('<font color="#%s">OBJECTIVE</font>   <font color="#%s">%s</font>   %s%s', C2.Sub:ToHex(), def.Color:ToHex(), string.upper(def.Name), text, tag)
            end
            task.wait(0.25)
        end
    end)
end

-- Daily contracts tracker (top-right, under the currency chips). Data: clientState.Contracts (Contracts module).
do
    local Contracts = require(sharedFolder:WaitForChild("Contracts"))
    local box = Instance.new("Frame")
    box.Name = "ContractsTracker"
    box.AnchorPoint = Vector2.new(1, 0)
    box.Position = UDim2.new(1, -16, 0, 66)
    -- (Update 5: the HUD slab -- facet + ink edge -- with the type scale: header 13 caps, task 13, reward 12; it was 10-12)
    box.Size = UDim2.new(0, 320, 0, 0)
    box.AutomaticSize = Enum.AutomaticSize.Y
    box.BackgroundColor3 = UIStyle.Colors.Bg0
    box.BackgroundTransparency = 0.12
    box.Visible = false
    box:SetAttribute("NoSkin", true)
    box.Parent = hudGui
    RoundCorners(box, 2)
    local stroke = UIStyle.InkEdge(2); stroke.Parent = box
    UIStyle.FacetGrad(Color3.new(1, 1, 1), Color3.fromRGB(205, 207, 212), 0.62).Parent = box
    local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 10); pad.PaddingLeft = UDim.new(0, 12); pad.PaddingRight = UDim.new(0, 12); pad.Parent = box
    local list = Instance.new("UIListLayout"); list.Padding = UDim.new(0, 6); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = box
    local head = Instance.new("TextLabel")
    head.Size = UDim2.new(1, 0, 0, 18); head.BackgroundTransparency = 1; head.Font = Enum.Font.GothamBlack; head.TextSize = 13
    head.TextXAlignment = Enum.TextXAlignment.Left; head.TextColor3 = UIStyle.Colors.Sub; head.LayoutOrder = 0
    head:SetAttribute("NoSkin", true); head:SetAttribute("TypeRole", "Label"); head.Parent = box
    local rows = {}
    local bonus = Instance.new("TextLabel")
    bonus.Size = UDim2.new(1, 0, 0, 16); bonus.AutomaticSize = Enum.AutomaticSize.Y; bonus.BackgroundTransparency = 1; bonus.Font = Enum.Font.GothamBold; bonus.TextSize = 12
    bonus.TextXAlignment = Enum.TextXAlignment.Left; bonus.LayoutOrder = 9; bonus.TextWrapped = true
    bonus:SetAttribute("NoSkin", true); bonus.Parent = box
    for i = 1, 5 do -- (3 contracts + up to 2 from mastery rank, UPDATE 7)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 44); row.BackgroundTransparency = 1; row.LayoutOrder = i
        row:SetAttribute("NoSkin", true); row.Parent = box
        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.new(1, -54, 0, 17); txt.BackgroundTransparency = 1; txt.Font = Enum.Font.GothamBold; txt.TextSize = 13
        txt.TextXAlignment = Enum.TextXAlignment.Left; txt.TextTruncate = Enum.TextTruncate.AtEnd; txt.TextColor3 = UIStyle.Colors.Text
        txt:SetAttribute("NoSkin", true); txt.Parent = row
        local num = Instance.new("TextLabel")
        num.Size = UDim2.new(0, 52, 0, 17); num.Position = UDim2.new(1, -52, 0, 0); num.BackgroundTransparency = 1; num.Font = Enum.Font.GothamBold
        num.TextSize = 13; num.TextXAlignment = Enum.TextXAlignment.Right; num.TextColor3 = UIStyle.Colors.Sub
        num:SetAttribute("NoSkin", true); num:SetAttribute("TypeRole", "Accent"); num.Parent = row
        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 0, 5); bg.Position = UDim2.new(0, 0, 0, 21); bg.BackgroundColor3 = UIStyle.Colors.Well; bg.BorderSizePixel = 0
        bg:SetAttribute("NoSkin", true); bg.Parent = row
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0, 0, 1, 0); fill.BackgroundColor3 = UIStyle.Colors.Accent; fill.BorderSizePixel = 0
        fill:SetAttribute("NoSkin", true); fill.Parent = bg
        local rew = Instance.new("TextLabel")
        rew.Size = UDim2.new(1, 0, 0, 14); rew.Position = UDim2.new(0, 0, 0, 29); rew.BackgroundTransparency = 1; rew.Font = Enum.Font.GothamMedium
        rew.TextSize = 12; rew.TextXAlignment = Enum.TextXAlignment.Left; rew.TextTruncate = Enum.TextTruncate.AtEnd; rew.TextColor3 = UIStyle.Colors.Sub
        rew:SetAttribute("NoSkin", true); rew.Parent = row
        rows[i] = { Row = row, Txt = txt, Num = num, Fill = fill, Rew = rew }
    end
    function UI.RefreshContracts()
        local c = clientState.Contracts
        local listData = c and c.List
        -- (owner 2026-10-05: "hide contracts in dungeon"): only in the hub -- the run banner is up during any run
        local inRun = UI.raidBanner ~= nil and UI.raidBanner.Visible
        -- (2026-10-13, owner: overlaps -- the box sat on top of wide windows / every window on a phone): hidden while a window is open
        box.Visible = type(listData) == "table" and #listData > 0 and not inRun and not UI.tutorialQuiet and not isAnyMenuOpen -- (Update 6: the tutorial card's spot)
        if not box.Visible then return end
        local done = 0
        for i, r in ipairs(rows) do
            local item = listData[i]
            r.Row.Visible = item ~= nil
            if item then
                if item.Done then done += 1 end
                r.Txt.Text = Contracts.Text(item)
                r.Txt.TextColor3 = item.Done and UIStyle.Colors.Good or UIStyle.Colors.Text
                r.Num.Text = item.Done and "DONE" or string.format("%d / %d", item.Progress or 0, item.Target or 1)
                r.Num.TextColor3 = item.Done and UIStyle.Colors.Good or UIStyle.Colors.Sub
                r.Fill.Size = UDim2.new(math.clamp((item.Progress or 0) / math.max(1, item.Target or 1), 0, 1), 0, 1, 0)
                r.Fill.BackgroundColor3 = item.Done and UIStyle.Colors.Good or UIStyle.Colors.Accent
                r.Rew.Text = (item.Done and "Paid: " or "Reward: ") .. Contracts.RewardText(item)
                r.Rew.TextColor3 = item.Done and UIStyle.Colors.Good or UIStyle.Colors.Sub
            end
        end
        local secs = ((os.time() // 86400) + 1) * 86400 - os.time()
        head.Text = string.format("DAILY CONTRACTS  %d / 3   •   NEW IN %dH %02dM", done, secs // 3600, (secs % 3600) // 60)
        bonus.Text = c.BonusPaid and "All 3 bonus paid" or "All 3 bonus: skill gem, Rare-or-better item, 2 Prism Shards"
        bonus.TextColor3 = c.BonusPaid and UIStyle.Colors.Good or UIStyle.Colors.Accent
    end
    task.spawn(function()
        while not UI.raidBanner do task.wait(0.5) end
        UI.raidBanner:GetPropertyChangedSignal("Visible"):Connect(function() UI.RefreshContracts() end)
        UI.RefreshContracts()
    end)
    task.spawn(function()
        while true do
            task.wait(30)
            if UI.RefreshContracts then UI.RefreshContracts() end
        end
    end)
end

UpdateWeaponHUD = function()
    local w = clientState.EquippedWeapon
    if not w then return end

    local stats = StatCalculator.Calculate(w, clientState.AllocatedNodes, clientState.Streak, clientState.Level, clientState.Attributes, clientState.EquippedGear, clientState.EquippedTitle, clientState.SocketedGems, clientState.RunBoons, clientState)
    UI.lastHudStats = stats

    local char = LocalPlayer.Character
    baseMoveSpeedMult = LocalPlayer:GetAttribute("PvpDuel") and (LocalPlayer:GetAttribute("PvpMoveMult") or 1) or stats.MovementSpeedMult -- (duels: everyone runs the same, PvpData.MOVE_MULT)
    if activeSlot == "Melee" and not LocalPlayer:GetAttribute("PvpDuel") then -- melee out: move faster (base bonus + the melee's own)
        local md = ItemData.MeleeWeapons[clientState.EquippedKnife or "Knife"] or ItemData.MeleeWeapons.Knife
        baseMoveSpeedMult *= 1 + 0.12 + (md.MovementSpeedBonus or 0)
    end
    if char and char:FindFirstChild("Humanoid") then
        local hum = char.Humanoid :: Humanoid
        hum:SetAttribute("BaseWalkSpeed", 16 * baseMoveSpeedMult * (LocalPlayer:GetAttribute("ChillMult") or 1)) -- (MovementController builds on this)
        hum.WalkSpeed = hum:GetAttribute("BaseWalkSpeed")
    end


    -- (Update 5 card: the rarity's SHAPE leads the name -- colour-blind safe -- instead of "[RARITY]" in brackets)
    local glyph = w.Exotic and ItemData.ItemGlyph(w) or (UI.RarityGlyph and UI.RarityGlyph(w.Rarity) or "●")
    UI.weaponNameLbl.Text = glyph .. "  " .. string.upper(ItemData.ZenithOf(w) and tostring(w.Name or "") or ItemData.DisplayName(w)) .. ((w.UpgradeLevel and w.UpgradeLevel > 0) and (" +" .. w.UpgradeLevel) or "")
    UI.weaponNameLbl.TextColor3 = ItemData.ItemColor(w)
    ItemData.StyleRarityText(UI.weaponNameLbl, (not w.Exotic) and w.Rarity or nil) -- (0.68: top rarities' gradient on the HUD card)
    if UI.weaponBlock then UI.weaponBlock.BackgroundColor3 = ItemData.ItemColor(w) end

    local procDef = w.Proc and ItemData.WeaponProcs[w.Proc.Id]
    if w.UniqueTrait or procDef then
        local parts = {}
        if procDef then table.insert(parts, string.upper(procDef.Prefix) .. string.format(" %d%%", math.round(ItemData.ProcChance(w, stats.AilmentChance) * 100))) end
        if w.UniqueTrait then table.insert(parts, "★ " .. w.UniqueTrait.Name) end
        UI.weaponTraitLbl.Text = table.concat(parts, "  •  ")
        UI.weaponTraitLbl.TextColor3 = procDef and procDef.Color or Color3.fromRGB(255, 210, 90)
        UI.weaponTraitLbl.Visible = true
    else
        UI.weaponTraitLbl.Text = ""
        UI.weaponTraitLbl.Visible = false
    end

    -- one type line, one stats line (the full sheet is in the inventory and the tooltip)
    local hudDps = stats.Damage * stats.FireRate * math.max(1, stats.PelletCount or 1) * math.max(1, stats.BurstCount or 1) * (1 + stats.CritChance * (stats.CritMultiplier - 1))
    UI.weaponTypeLbl.Text = string.format("%s %s  •  iLvl %d", ItemData.RarityLabel(w), (ItemData.WeaponTypeLine(w):gsub(" class", "")), w.ItemLevel or 1)
    UI.weaponStatsLbl.Text = string.format("DMG %s  •  %.1f/s  •  Crit %d%%  •  DPS %s", ItemData.FormatNumber(stats.Damage), stats.FireRate,
        math.round(stats.CritChance * 100), ItemData.FormatNumber(hudDps))

    -- Live Ammo & Reload HUD
    local curMag = clientState.CurrentMag or stats.MagazineSize
    local maxMag = stats.MagazineSize
    clientState.MaxMag = maxMag
    UI.ShowAmmo(curMag, maxMag)
    if not isReloading and realRig then -- (skin sets read them: SkinSets st.Ammo / AmmoCount)
        realRig.AmmoFrac = math.clamp(curMag / math.max(1, maxMag), 0, 1); realRig.AmmoCount = curMag; realRig.AmmoMax = maxMag
    end

    if activeSlot ~= "Melee" and UI.ammoHintGun then UI.ammoHintLbl.Text = UI.ammoHintGun end
    -- melee out: the card shows the melee instead
    if activeSlot == "Melee" then
        local md = ItemData.MeleeWeapons[clientState.EquippedKnife or "Knife"] or ItemData.MeleeWeapons.Knife
        local skin = MeleeDataHUD.SkinFor(clientState, md.Id)
        local col = ItemData.RarityColors[md.Rarity] or Color3.new(1, 1, 1)
        UI.weaponNameLbl.Text = (UI.RarityGlyph and UI.RarityGlyph(md.Rarity) or "●") .. "  " .. string.upper(md.Name)
        UI.weaponNameLbl.TextColor3 = col
        ItemData.StyleRarityText(UI.weaponNameLbl, nil)
        if UI.weaponBlock then UI.weaponBlock.BackgroundColor3 = col end
        UI.weaponTypeLbl.Text = "Melee" .. ((skin and skin.Name ~= "Factory") and ("  •  " .. skin.Name) or "") .. string.format("  •  Move speed +%d%%", math.round((0.12 + (md.MovementSpeedBonus or 0)) * 100))
        UI.weaponTraitLbl.Text = ""
        UI.weaponTraitLbl.Visible = false
        local dmg = (stats.MeleeDamage or 12) * (md.BaseDamage or 90) / 90
        UI.weaponStatsLbl.Text = string.format("Light %s  •  Heavy %s  •  %.1f/s  •  Reach %d", ItemData.FormatNumber(dmg), ItemData.FormatNumber(dmg * 2.2), md.AttackRate or 1, md.Range or 9)
        -- the big readout names the main attack; the key hint says the rest
        UI.ammoCounterLbl.Text = "MELEE"
        UI.ammoCounterLbl.TextColor3 = col
        UI.ammoMagLbl.Text = "" -- (UI CLEAN: no always-on key hints; the guide's CONTROLS card has them)
        UI.ammoHintLbl.Text = UI.ammoHintMelee or "RMB DASH | [1] GUN"
        UI.ammoBarFill.Size = UDim2.new(1, 0, 1, 0)
        UI.ammoBarFill.BackgroundColor3 = col
    end

    -- Title Tag & Header
    local titleId = clientState.EquippedTitle or "Rookie"
    local tData = ItemData.Titles[titleId] or ItemData.Titles.Rookie
    UI.titleHeaderLbl.Text = tData.Title:upper() -- (Mega-City: no stars / brackets)
    UI.titleHeaderLbl.TextColor3 = tData.Color

    -- (the title tag over your head is the server's (CombatServer.UpdatePlayerTitleTag). This client used to build its
    -- own local copy with the same name, and each side updated whichever it found first -- so changing title stacked
    -- the new one on top of the old (playtester 2026-10-02: "titles are layering onto each other").)

    local atCap = (clientState.Level or 1) >= ItemData.MAX_LEVEL -- (XP stops at the cap; Paragon removed 2026-10-13)
    local pct
    if UI.lvlBadge then UI.lvlBadge.Text = "LV " .. tostring(clientState.Level or 1) end
    if not UI.levelUpShowing then
        UI.lvlLabel.Text = atCap and "MAX LEVEL"
            or (ItemData.FormatNumber(clientState.XP or 0) .. " / " .. ItemData.FormatNumber(clientState.MaxXP or 0) .. " XP")
    end
    if atCap then
        pct = 1
    else
        pct = math.clamp(clientState.XP / math.max(1, clientState.MaxXP), 0, 1)
    end
    UI.xpFill.Size = UDim2.new(pct, 0, 1, 0)

    clientState.MaxHealth = stats.MaxHP
    if not clientState.Health or clientState.Health > clientState.MaxHealth then
        clientState.Health = clientState.MaxHealth
    end
    local hpPct = math.clamp(clientState.Health / math.max(1, clientState.MaxHealth), 0, 1)
    -- (under 30%: the word LOW too, not just the pulse colour)
    -- (UI CLEAN: the big number, "/ max" small in the secondary colour; LOW in words too -- not colour alone)
    UI.hpLabel.Text = string.format('%s<font size="%d" color="#A09D98"> / %s</font>%s', ItemData.FormatNumber(math.round(clientState.Health)), UI.hpSubSize or 18, ItemData.FormatNumber(clientState.MaxHealth),
        (hpPct < 0.3 and clientState.Health > 0) and string.format('<font size="%d" color="#E85C5C">  LOW</font>', UI.hpSubSize or 18) or "")
    if UI.hpArmor then -- (UPDATE 8 DEFENCE: Armor -> Plating; the Ward block adds WARD n in front)
        UI.platTxt = "PLATING " .. ItemData.FormatNumber(math.round(stats.Plating or stats.Armor or 0))
        if UI.HpTag then UI.HpTag() else UI.hpArmor.Text = UI.platTxt end
    end
    UI.hpFill.Size = UDim2.new(hpPct, 0, 1, 0)
    -- (the chip drains / the heal flash are animated by the HEALTH BAR FX block from UI.hpPct)
    if UI.hpPct and hpPct > UI.hpPct + 0.03 then UI.hpHealAt = os.clock() end -- (a real heal, not a regen tick)
    UI.hpPct = hpPct

    local mats = clientState.Materials or {}
    local chips = UI.currencyChips
    -- (UI v4: gold rolls up / down to its new value -- a short tween only when it changes)
    UIStyle.CountUp(chips.Gold, clientState.Gold or 0, UI.FmtWhole or function(v) return ItemData.FormatNumber(math.floor(v + 0.5)) end)
    chips.Scrap.Text = tostring(mats.Scrap or 0)
    chips.Alloy.Text = tostring(mats.Alloy or 0)
    chips.Prism.Text = tostring(mats.Prism or 0)
    chips.SP.Text = tostring(clientState.SkillPoints or 0) .. " SP"

end



-- Cheap ammo-only HUD update (used every shot instead of the full UpdateWeaponHUD)
local function UpdateAmmoHUD()
    if activeSlot == "Melee" then return end -- the weapon card shows the melee's controls instead
    local curMag = clientState.CurrentMag or clientState.MaxMag or 0
    local maxMag = clientState.MaxMag or curMag
    UI.ShowAmmo(curMag, maxMag)
    if not isReloading and realRig then -- (skin sets read them: SkinSets st.Ammo / AmmoCount)
        realRig.AmmoFrac = math.clamp(curMag / math.max(1, maxMag), 0, 1); realRig.AmmoCount = curMag; realRig.AmmoMax = maxMag
    end
end
;(function() -- (CHASE ITEMS 2026-11-06) ZENITH client half: Furnace heat, Long Promise, Bloomshot spread, the server-wide call
    UI.Zen = require(sharedFolder:WaitForChild("ZenithClient"))
    UI.Zen.Init({ UI = UI, GetState = function() return clientState end, Refresh = function() UpdateAmmoHUD() end,
        Toast = function(t: string, imp: boolean?) if ShowToast then ShowToast(t, imp) end end })
end)()

-- Coalesces bursts of updates (hits taken, combat deltas) into at most ~10 full HUD refreshes per second
local hudRefreshQueued = false
local function ScheduleHudRefresh()
    if hudRefreshQueued then return end
    hudRefreshQueued = true
    task.delay(0.1, function()
        hudRefreshQueued = false
        UpdateWeaponHUD()
    end)
end

-- Ensure Viewmodel attaches reliably to the current active camera
local function EnsureViewmodel()
    Camera = Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")
    if not Camera then return end
    if not viewmodel or not viewmodel.Parent or viewmodel.Parent ~= Camera then
        if viewmodel then viewmodel:Destroy() end
        viewmodel = Instance.new("Model")
        viewmodel.Name = "GunViewmodel"
        viewmodel.Parent = Camera
        RebuildViewmodelForWeapon(clientState.EquippedWeapon)
    end
end


local function SetupClientCharacter()
    pcall(function()
        LocalPlayer.CameraMinZoomDistance = 0.5
        LocalPlayer.CameraMaxZoomDistance = 0.5
        LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
        EnsureViewmodel()
        UpdateWeaponHUD()
    end)
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.1)
    SetupClientCharacter()
end)

EnsureViewmodel()
UpdateWeaponHUD()

if LocalPlayer.Character then
    task.spawn(function()
        task.wait(0.05)
        SetupClientCharacter()
    end)
end



local vmBulkParts: { BasePart } = {}
local vmBulkCFrames: { CFrame } = {}

-- Viewmodel Placement, Smooth ADS Zoom & Mechanical Recoil
-- Bound just after the default camera update so the gun uses this frame's camera CFrame (no 1-frame lag / jitter)
local SlideVM = require(sharedFolder:WaitForChild("MovementController"))
RunService:BindToRenderStep("AimRngViewmodel", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not Camera or Camera.Parent == nil then
        Camera = Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")
    end
    if not Camera then return end
    EnsureViewmodel()
    if not viewmodel then return end

    vmRecoilZ = math.max(0, vmRecoilZ - dt * 4.5)
    vmRecoilY = math.max(0, vmRecoilY - dt * 4.0)

    -- RIVALS-STYLE ADS: aiming is purely a camera FOV zoom now -- the gun never lifts into a raised
    -- iron-sight position and no scope lens overlay ever covers the screen, so nothing about the weapon
    -- model is ever "in the way." How much the camera zooms is still varied per weapon (ADSZoom is
    -- already tuned per class in ItemData: snipers zoom the most, SMGs/pistols the least) -- only HOW
    -- that zoom is achieved changed, not the fact that different guns zoom different amounts.
    local w = clientState.EquippedWeapon
    if UI.Zen then UI.Zen.AdsTick(isAiming, w) end -- (CHASE ITEMS: Long Promise moves 30% slower aiming down sights)
    local targetFOV = baseFOV
    -- Studio-only: play-test tooling can force an FOV via the player's DevFOV attribute
    if RunService:IsStudio() and Players.LocalPlayer:GetAttribute("DevFOV") then targetFOV = Players.LocalPlayer:GetAttribute("DevFOV") end
    -- the viewmodel is laid out for the hip FOV and is NOT re-fitted while aiming: the ADS zoom just zooms the
    -- camera (rescaling the gun to cancel the zoom distorted it -- the muzzle grew while the grip shrank)
    vmFOV = targetFOV
    if isAiming and w then
        -- Zoom FOV setting: the aim FOV for a standard gun (ADSZoom 60); each gun keeps its own zoom relative
        -- to that (snipers further, pistols less). Independent of the hip FOV, never wider than it.
        local zoomSetting = tonumber(GameSettings.Get("ZoomFOV")) or 60
        targetFOV = math.min(targetFOV, zoomSetting * (w.ADSZoom or 60) / 60)
    end
    -- movement tech FOV kick (dash / speed), mostly muted while aiming
    targetFOV += require(sharedFolder.MovementController).FovKick * (isAiming and 0.3 or 1)
    UI.sniperScopeOverlay.Visible = false
    if UI.watching and UI.spectateFov then
        Camera.FieldOfView = UI.spectateFov -- (0.83: watching -- the target's own FOV, zoom included)
    else
        Camera.FieldOfView = Camera.FieldOfView + (targetFOV - Camera.FieldOfView) * math.clamp(dt * 14, 0, 1)
    end

    -- Same hip-fire transform whether aiming or not -- the gun physically stays put; only the FOV above changes.
    -- targetCF = the right-hand grip anchor; every viewmodel part's Offset is relative to it.
    -- Subtle walk bob scaled by horizontal speed (no mouse-driven sway: that would add input lag).
    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local planarSpeed = 0
    if rootPart then
        local v = rootPart.AssemblyLinearVelocity
        planarSpeed = Vector2.new(v.X, v.Z).Magnitude
    end
    -- (owner 2026-10-03: "the gun still starts to move around faster as the player moves faster") the bob is a WALK bob:
    -- it used to speed up and grow with your speed without limit, so at bhop speed (~70) the gun shook ~5x a second, in
    -- the air too. Now it only plays on the ground, and its size and pace stop growing at run speed.
    local bobHum = char and char:FindFirstChildOfClass("Humanoid")
    local onFloor = bobHum ~= nil and bobHum.FloorMaterial ~= Enum.Material.Air
    local walkSpeed = math.min(planarSpeed, 16)
    local bobTarget = onFloor and walkSpeed / 16 or 0
    vmBobAmount += (bobTarget - vmBobAmount) * math.clamp(dt * 8, 0, 1)
    vmBobPhase += dt * (6 + walkSpeed * 0.35)
    local bobScale = GameSettings.Get("ViewBob") / 100
    local bobX = math.cos(vmBobPhase) * 0.022 * vmBobAmount * bobScale
    local bobY = -math.abs(math.sin(vmBobPhase)) * 0.028 * vmBobAmount * bobScale
    local aimTuck = 0 -- aiming only zooms the camera; the gun doesn't move

    local anchor = VM_GRIP_ANCHOR + vmAnchorShift
    local targetCF = Camera.CFrame * CFrame.new(anchor.X + bobX - aimTuck, anchor.Y + bobY + vmRecoilY + aimTuck * 0.5, anchor.Z + vmRecoilZ) * VM_TILT

    if #vmRainbowParts > 0 then
        local hueColor = Color3.fromHSV((os.clock() * 0.09) % 1, 0.5, 1)
        for i = 1, #vmRainbowParts do vmRainbowParts[i].Color = hueColor end
    end

    -- One batched move for the whole viewmodel instead of ~15 individual CFrame writes per frame.
    local n = 0
    for i = 1, #vmPartCache do
        local e = vmPartCache[i]
        local child = e.Part
        if e.Kind ~= 3 and child.Parent then -- Kind 3 = melee mesh, positioned by the swing block below
            n += 1
            vmBulkParts[n] = child
            vmBulkCFrames[n] = targetCF * e.Offset
        end
    end
    for i = #vmBulkParts, n + 1, -1 do
        vmBulkParts[i] = nil
        vmBulkCFrames[i] = nil
    end
    if n > 0 then
        Workspace:BulkMoveTo(vmBulkParts, vmBulkCFrames, Enum.BulkMoveMode.FireCFrameChanged)
    end

    -- Melee swing: animates the procedural knife through a real slash arc instead of the old
    -- "gun does a tiny forward punch, no visible weapon motion at all" recoil-only feedback. The gun
    -- itself is hidden for the duration and the knife takes over, swapping back the instant it finishes.
    if vmMeleeSwingT < 1 then
        vmMeleeSwingT = math.min(1, vmMeleeSwingT + dt / MELEE_SWING_DURATION)
    end
    local meleeActive = vmMeleeSwingT < 1
    if meleeActive ~= vmMeleeWasActive then
        vmMeleeWasActive = meleeActive
        for i = 1, #vmPartCache do
            local e = vmPartCache[i]
            if e.Kind == 3 then
                e.Part.LocalTransparencyModifier = meleeActive and 0 or 1
            else
                e.Part.LocalTransparencyModifier = meleeActive and 1 or 0
            end
        end
    end
    if meleeActive then
        -- Ease-out ease (fast start, slower finish) driving a forward thrust + diagonal slash sweep.
        local t = vmMeleeSwingT
        local ease = 1 - (1 - t) * (1 - t)
        local swingYaw = math.rad(-55 + 100 * ease) -- sweeps left-to-right across the screen
        local swingPitch = math.rad(12 - 22 * ease) -- slight downward chop, settling level
        local thrust = math.sin(ease * math.pi) -- 0 -> 1 -> 0: thrusts forward mid-swing, eases back
        local knifeCF = targetCF * CFrame.new(0.35, -0.35 + thrust * 0.1, -0.55 - thrust * 0.35) * CFrame.Angles(swingPitch, swingYaw, 0)
        for i = 1, #vmKnifeParts do
            local kp = vmKnifeParts[i]
            if kp.Part.Parent then
                kp.Part.CFrame = knifeCF * kp.Offset
            end
        end
    end

    -- Real-mesh rig: the knife swing above still uses the classic knife, so the rig hides meanwhile.
    if realRig then
        realRig:SetVisible(not meleeActive and not LocalPlayer:GetAttribute("Downed") and not LocalPlayer:GetAttribute("Spectating") and not LocalPlayer:GetAttribute("ThirdPerson")) -- (no gun while out of lives / in the third-person hub)
        -- sliding: the gun lowers (a hair right, a slight cant), CoD / Apex style (MovementController.SlideAmount)
        -- (owner 2026-10-03: the first-person slide legs "look horrific" -- removed; "just make the gun act how it would as
        -- if you were sliding. Lowering down to the right a bit (make this work properly on all fovs)"). The offset is
        -- scaled by the camera's FOV (tan^1.6): tan^1 alone moves the gun the same share of the screen at any FOV, and the
        -- extra ^0.6 evens out where it ENDS (the gun rests lower at 70 and nearer the middle at 120), so the slide pose
        -- sits about the same place at 70, 90 or 120. Measured: down ~8% / 10% / 14% of the screen.
        local sa = SlideVM.SlideAmount or 0
        if LocalPlayer:GetAttribute("DevSlidePose") and RunService:IsStudio() then sa = 1 end -- (Studio test hook: hold the pose)
        local fk = (math.tan(math.rad(math.clamp(Camera.FieldOfView, 30, 120)) / 2) / math.tan(math.rad(90) / 2)) ^ 1.6 / math.max(0.2, realRig.FovScale or 1)
        -- (owner 2026-10-03: "shouldn't tilt as much to the right, it should just lower for the most part")
        local slideOff = CFrame.new(0.05 * sa * fk, -0.28 * sa * fk, 0.06 * sa) * CFrame.Angles(math.rad(-2) * sa, math.rad(1) * sa, math.rad(-4) * sa)
        -- (0.56) DASH: the gun pulls in low and cants toward the dash, then springs back (MovementController.DashAmount)
        local da = SlideVM.DashAmount or 0
        if da > 0.01 then
            local sd = SlideVM.DashSide or 0
            slideOff = slideOff * CFrame.new(-0.06 * sd * da * fk, -0.16 * da * fk, 0.12 * da) * CFrame.Angles(math.rad(-9) * da, math.rad(4 * sd) * da, math.rad(10 * sd) * da)
        end
        realRig:Update(dt, Camera.CFrame, CFrame.new(bobX - aimTuck, bobY + aimTuck * 0.5, 0) * slideOff, vmFOV)
        -- (GEAR LIGHT, owner 2026-10-09: "guns should always look like they do during daytime" -- gun, melee, gloves and
        -- sleeves: one short neutral light behind the camera fills in whatever daylight the biome's lighting lacks)
        -- (third person, 2026-10-10: your OWN world gear -- back gun, hip melee, glove / sleeve shells + their local
        -- decorations -- is corrected the same way, so the darker hub plaza doesn't darken it)
        local tpGear = nil
        if LocalPlayer:GetAttribute("ThirdPerson") and not LocalPlayer:GetAttribute("Downed") then
            local ch = LocalPlayer.Character
            if ch then
                tpGear = {}
                for _, n in ipairs({ "WorldGun", "WorldMelee", "WorldGloves" }) do
                    local m = ch:FindFirstChild(n)
                    if m then table.insert(tpGear, m) end
                end
                local live = require(sharedFolder:WaitForChild("GloveFX"))._live
                if live then
                    for _, rec in pairs(live) do
                        if rec.Player == LocalPlayer and rec.D and rec.D.Parts then
                            for _, e in ipairs(rec.D.Parts) do if e.Part then table.insert(tpGear, e.Part) end end
                        end
                    end
                end
            end
        end
        require(sharedFolder:WaitForChild("GearLight")).Step(Camera.CFrame, not LocalPlayer:GetAttribute("Downed")
            and not LocalPlayer:GetAttribute("Spectating") and not LocalPlayer:GetAttribute("ThirdPerson"), tpGear)
    end
end)

-- ==================== ZONE LIGHTING (client-side) ====================
-- Lighting changes made on the client stay local, so each player gets the profile for wherever THEY are:
-- a calmer hub, and a moody per-biome profile inside the dungeon (night sky, fog, low bloom, gentle color
-- grading). This replaces the one bright daytime setup everything used to share -- which, combined with
-- the Neon-heavy rooms, is what made the dungeon (Cryo most of all) blinding.
local Lighting = game:GetService("Lighting")
type LightProfile = {
    ClockTime: number, Brightness: number, Ambient: Color3, OutdoorAmbient: Color3,
    FogColor: Color3, FogStart: number, FogEnd: number, Exposure: number,
    BloomIntensity: number, BloomThreshold: number, BloomSize: number,
    CCBrightness: number, CCContrast: number, CCSaturation: number, CCTint: Color3,
}
local LIGHT_PROFILES: { [string]: LightProfile } = {
    -- (2026-10-05 skies: every biome was midnight -- a black sky; owner: "shouldn't just be black". Each biome has its own
    -- time of day now so the sky + Atmosphere colour the horizon: Molten sunset, Cryo dawn, Void / Cyber dusk, Storm day)
    -- (HUB v3 2026-10-03: daylight through the oculus does the lighting -- warmer, brighter ambient, sun a touch stronger)
    -- (HUB v4 "FRONTIER FORTRESS" 2026-10-05: DUSK -- a low warm sun over the walls, cool violet ambient, warm haze; the
    -- braziers and lanterns make the light pools)
    -- (HUB v5 "WALLED CITY" 2026-10-05: NIGHT -- a dim violet ambient, haze, the neon does the lighting; bloom up so
    -- every sign glows, a warm-red grade)
    -- (2026-10-10, owner: "The hub area in general feels incredibly dark (including bazaar)" + the shooting range turned
    -- guns "almost pitch black": a grey plate at the gear read 24 / 255. Same night + neon, much more ambient + exposure)
    -- (UPDATE 4: ClockTime 13 + Brightness 0.6 so the painted overcast night sky (BiomeSkies.Hub) shows -- a night clock
    -- dims painted skies to black; the street looks about the same, the ambient carries it)
    -- (UPDATE 4 NIGHT, owner: "its like full-bright feeling almost even though its suppossed to be night time"): the light
    -- that reaches the GEAR stays (ambient + exposure unchanged: guns must stay readable) -- the night comes from darker
    -- city SURFACES (HubCity.PLAZA_DIM), a low dim sun at the painted sky's dusk edge, a denser violet haze (ATMO.Hub), more
    -- bloom on the neon and more grade contrast; the signs' self-lit pools do the street lighting
    -- (Update 6 TRY RANGE, owner: "Trialing bundles should bring you to its own more lit area"): the try-on studio range
    -- (AimRngShared/TryRange, Zones "showcase"): a bright, neutral daylight clock with shadows off (only the hub casts
    -- them), soft grey ambient, no fog / haze, a near-neutral grade -- skins read at their authored colours. Leaving the
    -- range puts the hub's own profile back (this loop), so nothing needs restoring by hand.
    Showcase = { ClockTime = 14, Brightness = 2, Ambient = Color3.fromRGB(166, 164, 161), OutdoorAmbient = Color3.fromRGB(166, 164, 161),
        FogColor = Color3.fromRGB(200, 198, 195), FogStart = 400, FogEnd = 3000, Exposure = 0.08, EnvDiffuse = 0.5, EnvSpecular = 0.7,
        BloomIntensity = 0.5, BloomThreshold = 1.6, BloomSize = 22,
        CCBrightness = 0.02, CCContrast = 0.06, CCSaturation = 0.06, CCTint = Color3.fromRGB(255, 253, 250) },
    Hub = { ClockTime = 17.4, Brightness = 0.25, Ambient = Color3.fromRGB(152, 143, 157), OutdoorAmbient = Color3.fromRGB(165, 157, 170),
        FogColor = Color3.fromRGB(34, 20, 36), FogStart = 90, FogEnd = 560, Exposure = 1.30, EnvDiffuse = 0.35, EnvSpecular = 0.6, -- (HUBFIX 2026-10-24: exposure 1.16 -> 1.30, with lighter city surfaces (HubCity.PLAZA_DIM 0.62): the hub read "incredibly dark")
        BloomIntensity = 0.85, BloomThreshold = 1.15, BloomSize = 26, -- (UPDATE 4 NO VEIL: only the neon blooms)
        CCBrightness = 0, CCContrast = 0.24, CCSaturation = 0.18, CCTint = Color3.fromRGB(248, 246, 255) }, -- (neutral, a touch cool: the pink tint read as a veil)
    -- (brighter + warmer 2026-10-02: the molten rooms read too dark)
    -- (2026-10-03 visual pass: every biome a touch more contrast + colour, bloom a little stronger so the glows pop)
    -- (2026-10-05 map shells: the arenas are open now -- a touch more sky light so the rims and props read)
    -- (UPDATE 4 LIGHTING AUDIT, owner: "its incredibly dark in some biomes, you cant even see the gun": the open arena's light
    -- had almost no green / blue (grey plate 30,2,0 under Obsidian Night) and GearLight can only dim a textured gun's red
    -- -> a black gun. Brighter, less saturated ambient + exposure: grey plate 58,39,32, the scene still molten)
    Fire = { ClockTime = 17.7, Brightness = 1.4, Ambient = Color3.fromRGB(204, 170, 150), OutdoorAmbient = Color3.fromRGB(213, 178, 158),
        FogColor = Color3.fromRGB(64, 26, 14), FogStart = 160, FogEnd = 760, Exposure = 1.06,
        BloomIntensity = 0.32, BloomThreshold = 1.35, BloomSize = 18,
        CCBrightness = 0, CCContrast = 0.15, CCSaturation = 0.08, CCTint = Color3.fromRGB(255, 236, 222) },
    -- (ClockTime 8.5 = the painted sky's morning sun, ~25 degrees up. 2026-10-10: this comment used to sit mid-line and
    -- swallowed Ice's Ambient / OutdoorAmbient -- Ice kept whatever ambient the last area left behind)
    -- (UPDATE 4 LIGHTING AUDIT: Ice / Storm a touch brighter -- gun slide L41 / L45 -> L51 / L57; snow + white stone not blown)
    Ice = { ClockTime = 8.5, Brightness = 1.1, Ambient = Color3.fromRGB(130, 148, 175), OutdoorAmbient = Color3.fromRGB(136, 161, 194),
        FogColor = Color3.fromRGB(40, 56, 80), FogStart = 140, FogEnd = 700, Exposure = 0.45,
        BloomIntensity = 0.28, BloomThreshold = 1.5, BloomSize = 16,
        CCBrightness = -0.02, CCContrast = 0.14, CCSaturation = -0.04, CCTint = Color3.fromRGB(230, 242, 255) },
    -- (Void + Cyber brighter 2026-10-02, playtester: "cyber is extremely dark, void is also pretty dark" -- same treatment
    -- the Fire rooms got: more ambient light and exposure, fog pushed back)
    -- (UPDATE 4 SKIES: Void / Cyber / Dream on a day clock + low Brightness -- at 18.2 / 18.4 / 0.2 Roblox dimmed their
    -- painted skies to black; "night" comes from the painting, the geometry looks about the same)
    -- (UPDATE 4 LIGHTING AUDIT: Void / Cyber ambient + exposure up -- the gun's slide read L29 / L23 in the open arena, now
    -- ~L56 / L64; stars and neon still read as night)
    Void = { ClockTime = 13, Brightness = 0.5, Ambient = Color3.fromRGB(171, 145, 215), OutdoorAmbient = Color3.fromRGB(182, 148, 229),
        FogColor = Color3.fromRGB(24, 14, 40), FogStart = 170, FogEnd = 820, Exposure = 1.05,
        BloomIntensity = 0.32, BloomThreshold = 1.35, BloomSize = 18,
        CCBrightness = 0, CCContrast = 0.16, CCSaturation = 0.1, CCTint = Color3.fromRGB(242, 230, 255) },
    Cyber = { ClockTime = 13, Brightness = 0.5, Ambient = Color3.fromRGB(154, 186, 192), OutdoorAmbient = Color3.fromRGB(155, 186, 192),
        FogColor = Color3.fromRGB(10, 22, 26), FogStart = 170, FogEnd = 800, Exposure = 1.1,
        BloomIntensity = 0.38, BloomThreshold = 1.25, BloomSize = 18,
        CCBrightness = 0, CCContrast = 0.18, CCSaturation = 0.1, CCTint = Color3.fromRGB(232, 255, 248) },
    -- STORMSPIRE: an overcast storm -- cool grey-blue, desaturated, fog closer in (the rain and the flashes do the rest)
    Storm = { ClockTime = 13, Brightness = 1.3, Ambient = Color3.fromRGB(144, 154, 175), OutdoorAmbient = Color3.fromRGB(159, 168, 189),
        FogColor = Color3.fromRGB(52, 58, 72), FogStart = 120, FogEnd = 640, Exposure = 0.45, -- (0.5 blew the white stone out at the old ambient; LIGHTING AUDIT 0.45)
        BloomIntensity = 0.24, BloomThreshold = 1.5, BloomSize = 18,
        CCBrightness = 0, CCContrast = 0.1, CCSaturation = -0.15, CCTint = Color3.fromRGB(228, 238, 255) },
    -- DREAMSCAPE (0.53): a pastel night -- lavender ambient, soft pink haze, bloom up so the dream glass glows
    Dream = { ClockTime = 13, Brightness = 0.2, Ambient = Color3.fromRGB(150, 128, 176), OutdoorAmbient = Color3.fromRGB(170, 140, 200),
        FogColor = Color3.fromRGB(70, 50, 110), FogStart = 170, FogEnd = 820, Exposure = 0.4, EnvDiffuse = 0.25,
        BloomIntensity = 0.5, BloomThreshold = 1.1, BloomSize = 24,
        CCBrightness = 0.02, CCContrast = 0.12, CCSaturation = 0.12, CCTint = Color3.fromRGB(255, 236, 252) },
    -- NEON FLATS (0.53): synthwave dusk -- a low hot sun, warm orange ambient, magenta haze
    -- (UPDATE 4 LIGHTING AUDIT: the red ambient left the gun's slide at L32 (grey plate 41,11,13): brighter, less red
    -- ambient + exposure -> L55, the dusk still magenta)
    Flats = { ClockTime = 17.9, Brightness = 1.6, Ambient = Color3.fromRGB(178, 146, 144), OutdoorAmbient = Color3.fromRGB(193, 153, 153),
        FogColor = Color3.fromRGB(110, 40, 90), FogStart = 180, FogEnd = 900, Exposure = 0.9,
        BloomIntensity = 0.45, BloomThreshold = 1.15, BloomSize = 22,
        CCBrightness = 0, CCContrast = 0.16, CCSaturation = 0.14, CCTint = Color3.fromRGB(255, 232, 236) },
    -- HIDEOUT THEMES (2026-10-07: themes are their own places now, not recolours): inside a Deep Aquarium or Forest
    -- Cabin hideout (HideoutClient sets LocalPlayer "HideoutView") -- underwater blue noon; a warm evening in the canopy
    -- (UPDATE 4 LIGHTING AUDIT: the deep-blue Aquarium ambient left the gun's slide at L34 -> brighter, less saturated + exposure)
    HideoutAquarium = { ClockTime = 12, Brightness = 1.4, Ambient = Color3.fromRGB(122, 150, 172), OutdoorAmbient = Color3.fromRGB(112, 158, 190),
        FogColor = Color3.fromRGB(14, 60, 96), FogStart = 60, FogEnd = 300, Exposure = 0.6,
        BloomIntensity = 0.45, BloomThreshold = 1.15, BloomSize = 24,
        CCBrightness = 0, CCContrast = 0.1, CCSaturation = 0.1, CCTint = Color3.fromRGB(205, 235, 255) },
    -- (0.59 DUELS: a clear dusk so both players read against the arena -- night neon hid the opponent)
    Pvp = { ClockTime = 16.8, Brightness = 2.2, Ambient = Color3.fromRGB(150, 140, 160), OutdoorAmbient = Color3.fromRGB(160, 146, 176),
        FogColor = Color3.fromRGB(70, 46, 80), FogStart = 160, FogEnd = 900, Exposure = 0.3, EnvDiffuse = 0.4, EnvSpecular = 0.4,
        BloomIntensity = 0.55, BloomThreshold = 1.05, BloomSize = 24,
        CCBrightness = 0, CCContrast = 0.12, CCSaturation = 0.14, CCTint = Color3.fromRGB(255, 242, 246) },
    -- (0.59 EMBER FORGE: inside a volcano at night -- warm ambient, the lava + hearth do the light, a red-orange haze)
    HideoutForge = { ClockTime = 0, Brightness = 1.6, Ambient = Color3.fromRGB(170, 124, 100), OutdoorAmbient = Color3.fromRGB(180, 120, 90),
        FogColor = Color3.fromRGB(70, 28, 14), FogStart = 90, FogEnd = 520, Exposure = 0.45,
        BloomIntensity = 0.5, BloomThreshold = 1.0, BloomSize = 24,
        CCBrightness = 0, CCContrast = 0.12, CCSaturation = 0.1, CCTint = Color3.fromRGB(255, 236, 222) },
    -- (0.89) STARWHALE: deep night so the default sky's stars + moon show (a hideout uses the default sky, not a painted
    -- one); CRYSTAL HOLLOW: a closed cavern, the crystals + lanterns do the light, a teal haze
    -- (UPDATE 6: the Starwhale has its own painted deep-space sky now, BiomeSkies.HideoutStarwhale -- a painted face needs a
    -- day clock (a night clock blacks it out): ClockTime 13 with a low Brightness, the sky + the lamps are the night)
    HideoutStarwhale = { ClockTime = 13, Brightness = 0.4, Ambient = Color3.fromRGB(122, 128, 162), OutdoorAmbient = Color3.fromRGB(110, 118, 170),
        FogColor = Color3.fromRGB(8, 11, 30), FogStart = 500, FogEnd = 1500, Exposure = 0.5,
        BloomIntensity = 0.5, BloomThreshold = 1.05, BloomSize = 24,
        CCBrightness = 0, CCContrast = 0.1, CCSaturation = 0.1, CCTint = Color3.fromRGB(238, 240, 255) },
    HideoutCrystal = { ClockTime = 0, Brightness = 1.0, Ambient = Color3.fromRGB(104, 118, 146), OutdoorAmbient = Color3.fromRGB(80, 104, 140),
        FogColor = Color3.fromRGB(10, 30, 46), FogStart = 140, FogEnd = 700, Exposure = 0.35,
        BloomIntensity = 0.55, BloomThreshold = 1.0, BloomSize = 24,
        CCBrightness = 0, CCContrast = 0.12, CCSaturation = 0.12, CCTint = Color3.fromRGB(230, 244, 255) },
    HideoutForest = { ClockTime = 14.5, Brightness = 1.5, Ambient = Color3.fromRGB(112, 108, 100), OutdoorAmbient = Color3.fromRGB(128, 124, 110),
        FogColor = Color3.fromRGB(190, 200, 170), FogStart = 120, FogEnd = 600, Exposure = 0.05,
        BloomIntensity = 0.3, BloomThreshold = 1.35, BloomSize = 20,
        CCBrightness = 0, CCContrast = 0.1, CCSaturation = 0.08, CCTint = Color3.fromRGB(255, 248, 238) },
}
-- (0.87 WORLDS: the twelve world biomes bring their own light, haze, terrain palette and enemy contrast colour -- kept on
-- UI: the main chunk is at the 200-local limit)
do
    local ok, WB = pcall(require, sharedFolder:WaitForChild("WorldBiomes"))
    UI.WB = ok and WB or nil
    if ok then for k, v in pairs(WB.Light) do LIGHT_PROFILES[k] = v end end
end

local function GetLightingEffect(className: string, name: string): Instance
    local fx = Lighting:FindFirstChild(name)
    if not fx or not fx:IsA(className) then
        fx = Lighting:FindFirstChildOfClass(className :: any)
    end
    if not fx then
        fx = Instance.new(className)
        fx.Name = name
        fx.Parent = Lighting
    end
    return fx
end

-- (0.81, owner: "Can we lower the overall bloom / highlights of the game? It feels a bit too bright overall"): one global
-- tone-down applied on top of EVERY profile (so each area keeps its own look relative to the others): less bloom and only
-- from brighter pixels, a touch less exposure, softer specular highlights, fainter sun rays. (On UI: the main chunk is at
-- the 200-local limit.)
-- (2026-10-09, owner: "Overall game feels pretty dark now, slightly up brightness without adding back more neon lights"):
-- exposure -0.18 -> -0.06 and the shadow fill (Ambient / OutdoorAmbient) x1.15 -- the dark sides lift, bloom stays down.
UI.LightTone = { Exposure = -0.06, Bloom = 0.55, Threshold = 0.2, Specular = 0.65, Rays = 0.5, AmbientLift = 1.15 }
-- (fixes 2026-10-16 #5, playtester: "environment in the ice boss fight arena is too bright"): per-biome trims on the BOSS
-- STAGE only (the boss bowl's 1.2x ambient lift blew the Cryo snow + ice floor to near-white; normal Ice floors are fine).
-- Measured in the Frost Sovereign arena: exposure 0.40 -> 0.05 and ambient x0.8 brings the floor back to readable ice.
UI.BossStageTrim = { Ice = { Exposure = -0.35, Ambient = 0.8 } }

local activeLightProfile = ""
local function ApplyLightProfile(key: string)
    if key == activeLightProfile then return end
    activeLightProfile = key
    -- (0.86 BIOME MOODS) "<key>@<mood>": the floor's mood (UI.lightMood, read from its folder by the light loop) grades
    -- the profile, the haze and the terrain colours (BiomeMood)
    local mood = nil
    do
        local at = string.find(key, "@", 1, true)
        if at then key = string.sub(key, 1, at - 1); mood = UI.lightMood end
    end
    -- (0.58 BOSS STAGES: "<biome>:Boss" = the biome's profile, graded darker and punchier -- see the end)
    local bossStage = string.sub(key, -5) == ":Boss"
    if bossStage then key = string.sub(key, 1, -6) end
    local p = LIGHT_PROFILES[key] or LIGHT_PROFILES.Hub
    pcall(function() p = require(sharedFolder:WaitForChild("RoomAtmo")).Light(bossStage and (key .. ":Boss") or key, p) end) -- (MAPVIBE PASS 2)
    Lighting:SetAttribute("GearProfile", LIGHT_PROFILES[key] and key or "Hub") -- (GearLight's measured correction table)
    if mood then p = require(sharedFolder:WaitForChild("BiomeMood")).LightAdjust(p, mood) end
    local info = TweenInfo.new(0.8, Enum.EasingStyle.Sine)
    Lighting.ClockTime = p.ClockTime -- instant: tweening the clock would sweep through a sunset
    UI.lightClock = p.ClockTime -- (HUBFIX: the light loop re-applies if anything else moves the clock)
    -- (HUB v3: the sun stands high over the oculus; sky bounce light fills the hall -- off in the dungeons)
    Lighting.GeographicLatitude = (key == "Hub") and 20 or 41.7
    -- (0.76, owner: "Continue to improve the visual quality of our world. It still looks a little bit low quality"): most
    -- areas had NO sky light / reflections (0 / 0), so every PBR surface -- the guns' SurfaceAppearances, metal, glass --
    -- read flat and dark. Every area now gets some (no shadow cost); profiles can still set their own.
    Lighting.EnvironmentDiffuseScale = (p :: any).EnvDiffuse or 0.3
    Lighting.EnvironmentSpecularScale = ((p :: any).EnvSpecular or 0.45) * UI.LightTone.Specular
    do -- subtle sun rays where there's a sun to see
        local rays = GetLightingEffect("SunRaysEffect", "AimRngRays") :: SunRaysEffect
        rays.Intensity = ((key == "Hub" or string.sub(key, 1, 7) == "Hideout") and 0.015 or 0.035) * UI.LightTone.Rays
        rays.Spread = 0.55
        rays.Enabled = not require(sharedFolder:WaitForChild("QualityMode")).IsLow() -- (UPDATE 4 QualityMode: Low has no sun rays)
    end
    Lighting.GlobalShadows = GameSettings.Get("Shadows") and key == "Hub" and not require(sharedFolder:WaitForChild("QualityMode")).IsLow() -- (PERFORMANCE: no shadows in the dark dungeons)
    -- (UPDATE 4: boss stages sit in a bowl of stands that shades the sky light -- the Molten forge read near-black under
    -- Obsidian Night: a little more ambient there instead of the old darker grade)
    local trim = bossStage and UI.BossStageTrim[key] or nil
    local ambLift = UI.LightTone.AmbientLift * (bossStage and 1.2 or 1) * (trim and trim.Ambient or 1)
    TweenService:Create(Lighting, info, {
        Brightness = p.Brightness,
        -- (a profile without ambient keeps the current one: nil goals are skipped)
        Ambient = p.Ambient and Color3.new(math.min(1, p.Ambient.R * ambLift), math.min(1, p.Ambient.G * ambLift), math.min(1, p.Ambient.B * ambLift)),
        OutdoorAmbient = p.OutdoorAmbient and Color3.new(math.min(1, p.OutdoorAmbient.R * ambLift), math.min(1, p.OutdoorAmbient.G * ambLift), math.min(1, p.OutdoorAmbient.B * ambLift)),
        FogColor = p.FogColor, FogStart = p.FogStart, FogEnd = p.FogEnd, ExposureCompensation = p.Exposure + UI.LightTone.Exposure + (trim and trim.Exposure or 0),
    }):Play()
    local bloom = GetLightingEffect("BloomEffect", "AimRngBloom") :: BloomEffect
    TweenService:Create(bloom, info, { Intensity = p.BloomIntensity * UI.LightTone.Bloom, Threshold = p.BloomThreshold + UI.LightTone.Threshold, Size = p.BloomSize }):Play()
    local cc = GetLightingEffect("ColorCorrectionEffect", "AimRngGrade") :: ColorCorrectionEffect
    TweenService:Create(cc, info, { Brightness = p.CCBrightness, Contrast = p.CCContrast + (bossStage and 0.05 or 0), Saturation = p.CCSaturation + (bossStage and 0.08 or 0),
        TintColor = p.CCTint }):Play()
    -- (UPDATE 4: the boss grade no longer darkens -- exposure -0.18 + contrast 0.12 crushed the Molten forge to black; it
    -- keeps a touch of punch and the closer fog)
    if bossStage then TweenService:Create(Lighting, info, { ExposureCompensation = p.Exposure + UI.LightTone.Exposure + (trim and trim.Exposure or 0), FogEnd = p.FogEnd * 0.85 }):Play() end
    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmo then atmo = Instance.new("Atmosphere"); atmo.Parent = Lighting end
    -- per-biome sky haze (owner 2026-10-05: "Skyboxes and outside areas ... shouldn't just be black"): the horizon glows in
    -- the biome's colour and the far mountains (DungeonGenerator VISTA) fade into it. { Density, Color, Decay, Haze, Glare }
    local ATMO = {
        Hub = { 0.34, Color3.fromRGB(34, 22, 44), Color3.fromRGB(10, 6, 16), 0, 0 }, -- (the walled city; UPDATE 4 NO VEIL, owner: "weird tint / fog sort of brightness": dark night air -- the towers fade to dark, not to a bright pink fog. 2026-10-23 "like a box": Haze 0 -- any Haze fills the sky's lower half with one flat colour, a wall round the city; the painted sky's far city shows instead)
        HideoutForge = { 0.45, Color3.fromRGB(200, 90, 40), Color3.fromRGB(60, 20, 10), 1.8, 0.2 }, -- (smoke + ember glow)
        HideoutStarwhale = { 0, Color3.fromRGB(40, 50, 110), Color3.fromRGB(10, 12, 40), 0, 0 }, -- (UPDATE 6: no haze -- it banded the painted sky's horizon)
        HideoutCrystal = { 0.4, Color3.fromRGB(40, 120, 160), Color3.fromRGB(10, 30, 50), 1.6, 0 }, -- (cave haze, crystal-lit)
        Showcase = { 0, Color3.fromRGB(220, 218, 214), Color3.fromRGB(200, 198, 195), 0, 0 }, -- (Update 6 try range: clear air)
        Pvp = { 0.3, Color3.fromRGB(230, 130, 150), Color3.fromRGB(90, 50, 110), 1.6, 0.4 }, -- (duel arenas: a pink dusk over the city)
        -- (BIOME SKIES 2026-10-05: lighter haze so the painted skies show; each colour is its sky's horizon)
        Fire = { 0.27, Color3.fromRGB(255, 110, 40), Color3.fromRGB(120, 36, 16), 1.1, 0 },
        Ice = { 0.24, Color3.fromRGB(226, 238, 250), Color3.fromRGB(150, 186, 226), 0.9, 0 },
        Void = { 0.22, Color3.fromRGB(90, 50, 140), Color3.fromRGB(30, 12, 50), 0.8, 0 },
        Cyber = { 0.26, Color3.fromRGB(230, 70, 170), Color3.fromRGB(60, 20, 80), 1.1, 0 },
        Storm = { 0.32, Color3.fromRGB(150, 160, 172), Color3.fromRGB(70, 78, 92), 1.6, 0 },
        Dream = { 0.26, Color3.fromRGB(255, 190, 235), Color3.fromRGB(110, 80, 170), 1.0, 0 },
        Flats = { 0.24, Color3.fromRGB(255, 120, 160), Color3.fromRGB(120, 40, 90), 0.9, 0 },
        HideoutAquarium = { 0.55, Color3.fromRGB(30, 130, 185), Color3.fromRGB(8, 46, 80), 2.6, 0 }, -- (deep water: close blue haze)
        HideoutForest = { 0.4, Color3.fromRGB(196, 206, 176), Color3.fromRGB(110, 130, 100), 2, 0.3 }, -- (a soft green-gold canopy haze)
    }
    local a = ATMO[key] or (UI.WB and UI.WB.Atmo[key]) or ATMO.Hub
    if mood then a = require(sharedFolder:WaitForChild("BiomeMood")).AtmoAdjust(a, mood) end
    pcall(function() a = require(sharedFolder:WaitForChild("RoomAtmo")).Atmo(bossStage and (key .. ":Boss") or key, a) end) -- (MAPVIBE PASS 2)
    atmo.Density = a[1]; atmo.Color = a[2]; atmo.Decay = a[3]; atmo.Haze = a[4]; atmo.Glare = a[5]; atmo.Offset = (key == "Hub") and 0.1 or 0.25
    -- BIOME SKIES (owner 2026-10-05: "no duplicate atmospheres, every biome should look very nice and unique"): every
    -- biome has its own painted skybox (BiomeSkies, from tools/make_skies.py: Molten's ash + eruption, Glacier's clear polar
    -- day with an ice halo, Void's nebula + black hole, Cyber's neon smog, Storm's supercell). The sun / moon / stars are
    -- part of the painting. A biome without uploaded faces falls back to a blank sky the haze colours.
    UI.dungeonSky = UI.dungeonSky or (function()
        local sk = Instance.new("Sky")
        sk.Name = "AimRngSky"
        return sk
    end)()
    local skyFaces = nil
    do
        local BiomeSkies = require(sharedFolder:WaitForChild("BiomeSkies"))
        skyFaces = BiomeSkies[key]
        local sk = UI.dungeonSky :: any
        for _, f in ipairs({ "Bk", "Dn", "Ft", "Lf", "Rt", "Up" }) do sk["Skybox" .. f] = skyFaces and skyFaces[f] or "" end
        sk.CelestialBodiesShown = skyFaces == nil
        sk.StarCount = skyFaces and 0 or 2000
    end
    -- (the hideout themes keep the default sky: the blank biome sky painted the forest's sky dark red)
    -- (UPDATE 4: the hub + Bazaar ("Hub") get BiomeSkies.Hub, the painted overcast night -- it needs the day clock in LIGHT_PROFILES.Hub)
    -- (UPDATE 4 wrap-up: any key with painted faces gets them -- the Forest Cabin + the duel arenas showed Roblox's stock
    -- cartoon-cloud skybox. The night hideouts (Forge, Starwhale, Crystal) have no faces on purpose: a painted face goes
    -- black at a night clock, the stock night = real stars + moon.)
    UI.dungeonSky.Parent = (skyFaces ~= nil or (key ~= "Pvp" and key:sub(1, 7) ~= "Hideout")) and Lighting or nil
    -- TERRAIN PALETTES (0.58, owner: "the ground and wall textures need to make more sense with the themes of the biome,
    -- some of them feel random (such as neon flats)"): terrain colours are per material and global, so each biome tints
    -- the materials its maps use (solo floors are terrain, one floor at a time); the hub / hideouts get the defaults back.
    -- Neon Flats: the salt crust was glowing snow-white and the mesas' Sandstone read as orange wood grain.
    do
        local TM = Enum.Material
        local C = Color3.fromRGB
        local PAL = {
            Fire = { [TM.Basalt] = C(52, 42, 40), [TM.Slate] = C(70, 58, 54), [TM.Rock] = C(88, 70, 62), [TM.CrackedLava] = C(235, 225, 215) }, -- (UPDATE 4 LAVA: the crust map carries its own colours -- warm basalt + orange cracks)
            Ice = { [TM.Glacier] = C(170, 210, 235), [TM.Ice] = C(150, 200, 232), [TM.Rock] = C(110, 118, 132), [TM.Slate] = C(100, 108, 122), [TM.Ground] = C(96, 100, 110) },
            -- (Void: Slate flagstones + Glacier "void glass" -- Basalt's built-in specks turned into colour noise under a violet tint)
            Void = { [TM.Slate] = C(58, 48, 80), [TM.Glacier] = C(74, 46, 124), [TM.Asphalt] = C(34, 28, 48), [TM.Mud] = C(46, 34, 60), [TM.Ground] = C(56, 44, 72),
                [TM.Basalt] = C(36, 34, 44) },
            Storm = { [TM.Grass] = C(78, 98, 70), [TM.Slate] = C(70, 76, 86), [TM.Mud] = C(60, 56, 52), [TM.Rock] = C(86, 90, 98), [TM.Pavement] = C(96, 98, 104),
                [TM.Basalt] = C(54, 58, 66), [TM.Ground] = C(72, 70, 64) },
            Dream = { [TM.Salt] = C(172, 152, 206), [TM.Glacier] = C(170, 160, 236), [TM.Limestone] = C(190, 170, 214), [TM.Snow] = C(200, 186, 226) },
            Flats = { [TM.Salt] = C(176, 142, 150), [TM.Sand] = C(172, 116, 92), [TM.Asphalt] = C(78, 74, 84), [TM.Sandstone] = C(128, 62, 58),
                [TM.Rock] = C(96, 62, 64) },
            -- (HUB LOOK 2026-10-24: the Training Grounds' yard is terrain -- with the stock colours the firing side read as
            -- orange-brown dirt (Concrete 127,102,63) beside the city's dark asphalt; night-street greys now)
            Hub = { [TM.Concrete] = C(84, 82, 88), [TM.Asphalt] = C(70, 68, 76), [TM.Ground] = C(92, 82, 70) }, -- (RANGE REDO 2026-10-24: the range's packed-dirt lanes + backstop berm)
        }
        local terrain = Workspace.Terrain
        UI.terrainDefaults = UI.terrainDefaults or {}
        if UI.WB then for k, v in pairs(UI.WB.Terrain) do PAL[k] = PAL[k] or v end end -- (0.87 WORLDS)
        local want = PAL[key] or {}
        -- (MAPVIBE ATMOSPHERE PASS 2: a pilot biome's terrain darker -- RoomAtmo.Palette; its sun is cut in RoomAtmo.Light)
        pcall(function() want = require(sharedFolder:WaitForChild("RoomAtmo")).Palette(bossStage and (key .. ":Boss") or key, want) end)
        if mood then
            local BM = require(sharedFolder:WaitForChild("BiomeMood"))
            local shifted = {}
            for mat, col in pairs(want) do shifted[mat] = BM.Shift(col, mood) end
            want = shifted
        end
        for _, pal in pairs(PAL) do
            for mat in pairs(pal) do
                -- (0.87: guarded -- a non-terrain material in a palette threw here and cut the rest of the light setup off)
                pcall(function()
                    if UI.terrainDefaults[mat] == nil then UI.terrainDefaults[mat] = terrain:GetMaterialColor(mat) end
                    terrain:SetMaterialColor(mat, want[mat] or UI.terrainDefaults[mat])
                end)
            end
        end
    end
    bloom.Enabled = GameSettings.Get("PostFX") and not require(sharedFolder:WaitForChild("QualityMode")).IsLow()
    cc.Enabled = GameSettings.Get("PostFX")
end

task.spawn(function()
    while true do
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local key = "Hub"
        local watchLight = UI.watching and require(sharedFolder:WaitForChild("SpectateClient")).Light
        if LocalPlayer:GetAttribute("PvpDuel") then
            key = "Pvp"
        elseif watchLight then
            key = watchLight -- (0.62 SPECTATE: the watched floor's light)
        elseif root and root.Position.Z > 450 then
            local myRun = LocalPlayer:GetAttribute("RunId")
            local partyRuns = Workspace:FindFirstChild("PartyRuns")
            local dungeon = (myRun and partyRuns and partyRuns:FindFirstChild("Run_" .. myRun)) or Workspace:FindFirstChild("DungeonFacility")
            key = (dungeon and dungeon:GetAttribute("Biome")) or "Fire"
            if dungeon and dungeon:GetAttribute("BossArena") then key ..= ":Boss" end
            if dungeon and dungeon:GetAttribute("MoodId") then -- (0.86 BIOME MOODS)
                local BM = require(sharedFolder:WaitForChild("BiomeMood"))
                UI.lightMood = BM.FromFolder(dungeon)
                key ..= "@" .. BM.Key(UI.lightMood)
            end
        else
            local hv = LocalPlayer:GetAttribute("HideoutView")
            if hv and hv ~= "Apartment" then key = "Hideout" .. hv end -- (every themed hideout has its own profile)
            if root and UI.Zones.Kind(root.Position) == "showcase" then key = "Showcase" end -- (Update 6 try range)
        end
        -- (Studio: workspace attr DevLightKey forces a light profile -- "Fire", "Fire:Boss", "Fire@Ashfall" (a mood, fixed
        -- jitter), "HideoutForge" -- for tools/gear_calibrate.luau)
        if RunService:IsStudio() then
            local dk = Workspace:GetAttribute("DevLightKey")
            if type(dk) == "string" and dk ~= "" then
                local base, moodId = string.match(dk, "^([^@]+)@(.+)$")
                if base then
                    local BM = require(sharedFolder:WaitForChild("BiomeMood"))
                    UI.lightMood = BM.Roll((string.gsub(base, ":Boss$", "")), Random.new(7), moodId)
                    key = base .. "@" .. BM.Key(UI.lightMood)
                else
                    key = dk
                end
            end
        end
        -- (HUBFIX 2026-10-24, owner: "incredibly dark ... there's no night skybox"): in a Studio playtest the server's
        -- Lighting writes + its own hazy Atmosphere replicated AFTER this profile (clock 0.5 = a black painted sky, two
        -- Atmospheres). The server no longer writes them, and anything that still moves the clock or adds a second
        -- Atmosphere makes this loop keep one Atmosphere and re-apply the profile: Studio Play == live.
        do
            local nAt = 0
            for _, c in ipairs(Lighting:GetChildren()) do
                if c:IsA("Atmosphere") then nAt += 1; if nAt > 1 then c:Destroy() end end
            end
            if nAt > 1 or (UI.lightClock and math.abs(Lighting.ClockTime - UI.lightClock) > 0.05) then activeLightProfile = "" end
        end
        -- (pcall: one bad profile used to kill this loop -- the lighting then never changed again that session)
        local okL, errL = pcall(ApplyLightProfile, key)
        if not okL then warn("[Light] " .. tostring(key) .. ": " .. tostring(errL)) end
        task.wait(0.5)
    end
end)

-- PERFORMANCE (2026-10-03, owner: "EXTREMELY well optimized... run on almost anything"): while you're in a dungeon the
-- hub (600+ parts, 40+ lights) is far behind you but was still being drawn. Park it out of the workspace on this client
-- (a local reparent: the server and other players are unaffected) and put it back the instant you're in the hub again
-- (TeleportClient and respawns call UI.ShowHub before you land).
;(function()
    local holder = Instance.new("Folder")
    holder.Name = "ParkedHub"
    holder.Parent = game:GetService("ReplicatedStorage")
    local parked: Instance? = nil
    local parkedMarket: Instance? = nil -- (UPDATE 6: the Bazaar's towers stood on the Starwhale's horizon: parked in themed hideouts too)
    -- (UPDATE 6, owner: the Starwhale "just looks like a box, can you just make it look infinite almost"): the hub's TERRAIN
    -- (the plateau + range yard, ~80 under the hideout) is copied out and cleared on this client while you're in the
    -- Starwhale, so there is no floor at all under the whale -- the painted sky all the way down; pasted back by ShowHub
    -- (any way out: the door, a portal, a respawn). Client terrain edits never replicate. TERRAIN_PARK = the region (cells).
    local parkedTerrain: any = nil
    local TERRAIN_PARK = Region3int16.new(Vector3int16.new(-60, -32, -50), Vector3int16.new(60, 4, 90))
    local since: number? = nil
    -- (the leaderboards are SurfaceGuis in PlayerGui adorned to hub parts: they kept drawing with the hub parked -- a
    -- "RIFTS (all time)" board hung under the forest hideout. Off while parked)
    local boardsOff = {}
    function UI.ShowHub()
        local p = parked
        parked = nil
        if p and p.Parent == holder then p.Parent = Workspace end
        local mk = parkedMarket
        parkedMarket = nil
        if mk and mk.Parent == holder then mk.Parent = Workspace end
        for g in pairs(boardsOff) do if g.Parent then g.Enabled = true end end
        table.clear(boardsOff)
        local tr = parkedTerrain
        parkedTerrain = nil
        if tr then pcall(function() Workspace.Terrain:PasteRegion(tr, TERRAIN_PARK.Min, true) end) end
    end
    LocalPlayer.CharacterAdded:Connect(function() UI.ShowHub() end)
    RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local pos = root and (root :: BasePart).Position
        -- (2026-10-07: inside a themed hideout too -- the aquarium / forest are their own places, and the city's towers
        -- stood up through them. 2026-10-23: the loft too -- the hub's north row stood 24 studs past its windows ("look
        -- like glued on"); it has its own city block now (HideoutData BuildShell CITY VIEW). Leaving teleports through
        -- TeleportClient, which shows the hub first)
        local hv = LocalPlayer:GetAttribute("HideoutView")
        local themed = pos ~= nil and hv ~= nil and UI.Zones.InHideout(pos)
        if pos and (UI.Zones.AwayFromCity(pos) or themed or UI.watching) then -- (dungeons, the Bazaar, themed hideouts, watching a run)
            since = since or os.clock()
            if not parked and os.clock() - since > (themed and 0.1 or 1.5) then
                local hub = Workspace:FindFirstChild("HubWorld")
                if hub then
                    parked = hub; hub.Parent = holder
                    for _, g in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
                        if g:IsA("SurfaceGui") and g.Enabled and g.Adornee and g.Adornee:IsDescendantOf(hub) then g.Enabled = false; boardsOff[g] = true end
                    end
                end
            end
            -- (optimization pass 2026-10-27: the Bazaar -- ~680 parts, 3 lights, far west -- stayed drawn through every
            -- dungeon / duel / try range too; parked anywhere but the Bazaar itself. A server rebuild while parked leaves the
            -- old copy destroyed: drop it and park the new one)
            if parkedMarket and parkedMarket.Parent ~= holder then parkedMarket = nil end
            if (themed or not UI.Zones.InMarket(pos)) and not parkedMarket and parked then
                local mk = Workspace:FindFirstChild("MarketWorld")
                if mk then parkedMarket = mk; mk.Parent = holder end
            end
            if themed and hv == "Starwhale" and parked and not parkedTerrain then
                local okT, tr = pcall(function() return Workspace.Terrain:CopyRegion(TERRAIN_PARK) end)
                if okT and tr then
                    parkedTerrain = tr
                    local a, b = TERRAIN_PARK.Min, TERRAIN_PARK.Max
                    pcall(function()
                        Workspace.Terrain:FillRegion(Region3.new(Vector3.new(a.X, a.Y, a.Z) * 4, Vector3.new(b.X + 1, b.Y + 1, b.Z + 1) * 4), 4, Enum.Material.Air)
                    end)
                end
            end
        else
            since = nil
            if parked then UI.ShowHub() end
        end
    end)
end)()

-- HUB v3 centerpiece: the gyroscope reticle's two rings turn slowly (local only; 30 Hz; only while you're in the hub)
;(function()
    local acc, ang = 0, 0
    RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < 1 / 30 then return end
        local step = acc
        acc = 0
        local hub = Workspace:FindFirstChild("HubWorld")
        local cp = hub and hub:FindFirstChild("Centerpiece")
        if not cp then return end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root or (root :: BasePart).Position.Z > 450 then return end
        local outer, inner = cp:FindFirstChild("OuterRing"), cp:FindFirstChild("InnerRing")
        if not (outer and inner) then return end
        ang += step
        local c0 = Vector3.new(0, 36 + 0.6 * math.sin(ang * 0.8), 0)
        ;(outer :: Model):PivotTo(CFrame.new(c0) * CFrame.Angles(math.rad(12) * math.sin(ang * 0.3), ang * 0.25, 0))
        ;(inner :: Model):PivotTo(CFrame.new(c0) * CFrame.Angles(0, -ang * 0.4, math.rad(90)) * CFrame.Angles(ang * 0.6, 0, 0))
        local core = cp:FindFirstChild("ReticleCore")
        if core then (core :: BasePart).CFrame = CFrame.new(c0) end
    end)
end)()

-- ==================== JUMP PADS (client-side launch) ====================
-- Pads are tagged by the server with a LaunchTarget (a vantage platform). When you step on one, compute a
-- ballistic arc that peaks just above the platform and lands on it, and apply it to your own character.
do
    local CollectionServiceJP = game:GetService("CollectionService")
    local lastLaunch = 0
    RunService.Heartbeat:Connect(function()
        if os.clock() - lastLaunch < 1 then return end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not root or root.Position.Z < 450 then return end
        for _, pad in ipairs(CollectionServiceJP:GetTagged("AimRngJumpPad")) do
            if pad:IsA("BasePart") then
                local rel = root.Position - pad.Position
                -- (the whole 5.6-stud pad + a hop's height over it: a bhop across the pad used to skip it)
                if Vector2.new(rel.X, rel.Z).Magnitude < 3.4 and rel.Y > -1 and rel.Y < 6.5 then
                    local target = pad:GetAttribute("LaunchTarget")
                    if typeof(target) == "Vector3" then
                        lastLaunch = os.clock()
                        local g = Workspace.Gravity
                        -- aim for standing height on the platform (root sits ~3 above the surface), with the apex
                        -- 6 studs higher so the feet clear the platform's edge on the way in
                        local rise = math.max(2, (target.Y + 3) - root.Position.Y + 9)
                        local vy = math.sqrt(2 * g * rise)
                        local flight = vy / g + math.sqrt(2 * 9 / g)
                        -- (MovementController's speed caps would clamp this arc -- they stand aside for the flight)
                        local planar = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
                        local launchVel = planar / flight + Vector3.new(0, vy, 0)
                        root.AssemblyLinearVelocity = launchVel
                        require(sharedFolder:WaitForChild("MovementController")).Launch(flight + 0.3, launchVel)
                        SoundHelper.Play("Upgrade")
                    end
                    break
                end
            end
        end
    end)
end

-- ==================== ENEMY VISUALS (outlines, brightness, health bars) ====================
-- Default: every nearby enemy gets a clean outline (Highlight). Roblox draws at most 31 Highlights at
-- once, so outlines go to the nearest ENEMY_OUTLINE_BUDGET enemies and are re-assigned as you move.
-- All of this is local to your client and driven by Settings > Enemies (EnemyVisuals).
do
    local CollectionServiceEV = game:GetService("CollectionService")
    local ENEMY_OUTLINE_BUDGET = 22 -- (0.63: BossCues keeps up to 7 of the 31 for weak points)
    local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
    local OUTLINE_COLORS: { [string]: Color3 } = {
        Red = Color3.fromRGB(255, 70, 70), White = Color3.fromRGB(255, 255, 255), Yellow = Color3.fromRGB(255, 225, 60),
        Magenta = Color3.fromRGB(255, 80, 225), Cyan = Color3.fromRGB(70, 230, 255),
    }
    local FILL_TRANSPARENCY: { [string]: number } = { Off = 1, Subtle = 0.78, Strong = 0.6 } -- (0.62: Subtle 0.85 -> 0.78)
    local tracked: { [Model]: { Orig: { [BasePart]: { Color: Color3, Material: Enum.Material } }, HL: Highlight?, Auto: Color3 } } = {}

    local function AutoColor(model: Model): Color3
        -- Elites and bosses read at a glance: rare elites gold, magic elites blue, bosses orange.
        local tier = model:GetAttribute("EliteTier")
        if tier == "Rare" then return Color3.fromRGB(255, 205, 60) end
        if tier == "Magic" then return Color3.fromRGB(110, 150, 255) end
        if model:GetAttribute("IsBoss") == true then return Color3.fromRGB(255, 120, 40) end
        local weak = model:FindFirstChild("Head") or model:FindFirstChild("Core")
        local c = (weak and weak:IsA("BasePart")) and weak.Color or Color3.fromRGB(255, 80, 80)
        local h, s = c:ToHSV()
        return Color3.fromHSV(h, math.max(0.55, s), 1)
    end

    local function LookFor(o: any): (Color3, Enum.Material)
        local col = o.Color
        if EnemyVisuals.Brightness == "Dim" then col = col:Lerp(BLACK, 0.3)
        elseif EnemyVisuals.Brightness == "Bright" then col = col:Lerp(WHITE, 0.18) end
        local mat = o.Material
        if mat == Enum.Material.Neon and not EnemyVisuals.WeakSpotGlow then mat = Enum.Material.SmoothPlastic end
        return col, mat
    end

    local function ApplyPart(part: BasePart, o: any)
        local col, mat = LookFor(o)
        o.Writing = true
        part.Color = col
        part.Material = mat
        o.Writing = false
        o.Shown = col
    end

    local function ApplyLook(model: Model, st: any)
        for part, o in pairs(st.Orig) do
            if part.Parent then ApplyPart(part, o) end
        end
        local hud = model:FindFirstChild("HealthHUD")
        if hud and hud:IsA("BillboardGui") then hud.Enabled = false end -- (EnemyBars draws the bars now)
    end

    -- CONTRAST (0.61c, owner: "The enemy visibility is a bit low in some of the biomes"): normal enemies take a colour picked
    -- against the biome you're in (its floors / light / telegraphs)
    local BIOME_CONTRAST: { [string]: Color3 } = {
        Fire = Color3.fromRGB(70, 230, 255), Flats = Color3.fromRGB(70, 230, 255), -- (orange / red worlds: cyan)
        Ice = Color3.fromRGB(255, 50, 110), -- (white / pale blue: hot red)
        Void = Color3.fromRGB(255, 230, 60), -- (purple / black: yellow)
        Cyber = Color3.fromRGB(255, 80, 225), -- (dark + green / cyan grid: magenta)
        Storm = Color3.fromRGB(255, 180, 40), -- (blue / grey: amber)
        Dream = Color3.fromRGB(70, 255, 120), -- (pink / lilac pastel: green)
    }
    if UI.WB then for k, v in pairs(UI.WB.Contrast) do BIOME_CONTRAST[k] = v end end -- (0.87 WORLDS)
    local function ContrastColor(st: any, model: Model?): Color3
        -- (every enemy, elites and bosses too: a blue magic elite vanished on Ice; elites still read by size + name tag)
        local run = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("AimRngRun")
        local biome = run and run:GetAttribute("Biome")
        return (biome and BIOME_CONTRAST[biome]) or WHITE
    end
    local function ConfigureOutline(hl: Highlight, st: any, model: Model?) -- (model: the enemy, when hl adorns one of its parts)
        local col = (EnemyVisuals.OutlineColor == "Contrast" and ContrastColor(st, (model or hl.Adornee) :: any)) or OUTLINE_COLORS[EnemyVisuals.OutlineColor] or st.Auto
        hl.OutlineColor = col
        hl.OutlineTransparency = 0.05
        hl.FillColor = col
        hl.FillTransparency = FILL_TRANSPARENCY[EnemyVisuals.Fill] or 1
        -- (BOSS LOOK v2, 2026-10-13: the 0.62 strong boss fill (0.55) washed the new boss colours out at fighting range --
        -- bosses now take a LIGHT fill 0.85 (unless body tint is Off): the outline still pops the silhouette, the colours read)
        local own = model or hl.Adornee
        if own and own:GetAttribute("IsBoss") == true and hl.FillTransparency < 1 then hl.FillTransparency = 0.85 end
        hl.DepthMode = EnemyVisuals.ThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
        local owner = model or hl.Adornee or hl.Parent -- (the hideout's practice dummy: never through the apartment walls)
        if owner and owner:GetAttribute("NoXRay") then hl.DepthMode = Enum.HighlightDepthMode.Occluded end
    end

    -- Enemies are tracked for their whole life, not just the moment they appear: parts and the health bar
    -- can replicate in after the model does (dungeon spawns stream in piece by piece), and the server
    -- re-colors some parts mid-fight (telegraphs, elite pulses). Every such change is picked up and your
    -- current settings are re-applied on top of it, so the look is the same in the hub and every dungeon.
    local function Track(model: Instance)
        if not model:IsA("Model") or tracked[model] then return end
        if DungeonGeneratorShared.RunIdOf(model) ~= LocalPlayer:GetAttribute("RunId") then return end -- another party's dungeon
        local st: any = { Orig = {}, HL = nil, Auto = AutoColor(model), Conns = {} }
        tracked[model] = st
        local function AddPart(d: Instance)
            if d:IsA("BasePart") and not st.Orig[d] and d.Transparency < 1 then
                local o = { Color = d.Color, Material = d.Material, Writing = false, Shown = d.Color }
                st.Orig[d] = o
                ApplyPart(d, o)
                table.insert(st.Conns, d:GetPropertyChangedSignal("Color"):Connect(function()
                    if o.Writing or d.Color == o.Shown then return end
                    o.Color = d.Color -- server changed it: that's the new base color
                    ApplyPart(d, o)
                end))
                if d.Name == "Head" or d.Name == "Core" then
                    st.Auto = AutoColor(model)
                    if st.HL then ConfigureOutline(st.HL, st) end
                end
            elseif d:IsA("BillboardGui") and d.Name == "HealthHUD" then
                d.Enabled = false -- (EnemyBars draws the bars now)
            end
        end
        for _, d in ipairs(model:GetDescendants()) do AddPart(d) end
        table.insert(st.Conns, model.DescendantAdded:Connect(AddPart))
        -- Status effects you've applied (burn / chill / bleed / decay) show as particles on the enemy.
        local STATUS_FX = {
            Burning = { Color = Color3.fromRGB(255, 120, 30), Speed = 3, Accel = Vector3.new(0, 6, 0), Rate = 16 },
            Chilled = { Color = Color3.fromRGB(150, 220, 255), Speed = 1, Accel = Vector3.new(0, -1, 0), Rate = 12 },
            Bleeding = { Color = Color3.fromRGB(200, 20, 40), Speed = 0.5, Accel = Vector3.new(0, -12, 0), Rate = 10 },
            Decayed = { Color = Color3.fromRGB(130, 210, 60), Speed = 1.5, Accel = Vector3.new(0, 2, 0), Rate = 10 },
        }
        for attr, fx in pairs(STATUS_FX) do
            local emitter: ParticleEmitter? = nil
            local function Upd()
                local on = model:GetAttribute(attr) == true
                if on and not emitter then
                    local torso = model:FindFirstChild("Torso") or model.PrimaryPart
                    if torso and torso:IsA("BasePart") then
                        local pe = Instance.new("ParticleEmitter")
                        pe.Name = "Status_" .. attr
                        pe.Color = ColorSequence.new(fx.Color)
                        pe.LightEmission = 0.5
                        pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
                        pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
                        pe.Lifetime = NumberRange.new(0.4, 0.8)
                        pe.Rate = fx.Rate
                        pe.Speed = NumberRange.new(fx.Speed)
                        pe.Acceleration = fx.Accel
                        pe.SpreadAngle = Vector2.new(180, 180)
                        pe.Parent = torso
                        emitter = pe
                    end
                elseif not on and emitter then
                    emitter:Destroy()
                    emitter = nil
                end
            end
            table.insert(st.Conns, model:GetAttributeChangedSignal(attr):Connect(Upd))
            Upd()
        end
        table.insert(st.Conns, model.DescendantRemoving:Connect(function(d)
            if st.Orig[d] then st.Orig[d] = nil end
        end))
    end
    local function Untrack(model: Instance)
        local st = tracked[model :: Model]
        if st then
            if st.HL then st.HL:Destroy() end
            for _, h in pairs(st.HLParts or {}) do h:Destroy() end
            for _, c in ipairs(st.Conns) do c:Disconnect() end
            tracked[model :: Model] = nil
        end
    end
    for _, m in ipairs(CollectionServiceEV:GetTagged("AimRngEnemy")) do Track(m) end
    CollectionServiceEV:GetInstanceAddedSignal("AimRngEnemy"):Connect(Track)
    CollectionServiceEV:GetInstanceRemovedSignal("AimRngEnemy"):Connect(Untrack)

    RefreshEnemyVisuals = function()
        for model, st in pairs(tracked) do
            ApplyLook(model, st)
            if st.HL then ConfigureOutline(st.HL, st) end
            for _, h in pairs(st.HLParts or {}) do ConfigureOutline(h, st, model) end
        end
    end

    -- (0.85, owner: "Only parts of the enemies that can be hit should be highlighted"): one Highlight on the model lit up
    -- EVERY part -- a boss's legs, arms, hammer, helm ... that shots pass through (CanQuery off). An enemy with visible
    -- parts you can't hit gets one Highlight per HITTABLE visible part instead (bosses: a handful); everyone else keeps
    -- the single model outline. Re-checked every pass, so a part switching (a boss head while its weak-point glow is up)
    -- follows. Each per-part Highlight counts against the same budget.
    local function HasDeadParts(model: Model): boolean
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 0.95 then return true end
        end
        return false
    end
    local function HittableParts(model: Model): { BasePart }
        local list = {}
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") and d.CanQuery and d.Transparency < 0.95 then table.insert(list, d) end
        end
        return list
    end
    local function ClearOutline(st: any)
        if st.HL then st.HL:Destroy(); st.HL = nil end
        if st.HLParts then
            for _, h in pairs(st.HLParts) do h:Destroy() end
            st.HLParts = nil
        end
    end

    -- Outline assignment: nearest enemies first, within the budget.
    task.spawn(function()
        while true do
            local cam = Workspace.CurrentCamera
            local camPos = cam and cam.CFrame.Position or Vector3.zero
            local list = {}
            -- Only enemies in the area you're in get outlines: inside a dungeon (Z > 450) the hub's practice
            -- dummies used to keep theirs and showed through every wall with "through walls" on.
            local myChar = LocalPlayer.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local inDungeon = myRoot ~= nil and (myRoot :: BasePart).Position.Z > 450
            for model, st in pairs(tracked) do
                if not model.Parent then
                    Untrack(model)
                else
                    local pos = model:GetPivot().Position
                    local d = (pos - camPos).Magnitude
                    local sameArea = (pos.Z > 450) == inDungeon and not (inDungeon and model:GetAttribute("IsPracticeDummy"))
                    if sameArea and d < 600 then
                        -- (bosses first: their outline never loses to the budget)
                        table.insert(list, { M = model, St = st, D = (model:GetAttribute("IsBoss") == true) and -1 or d })
                    elseif st.HL or st.HLParts then
                        ClearOutline(st)
                    end
                end
            end
            table.sort(list, function(a, b) return a.D < b.D end)
            local used = 0
            for _, e in ipairs(list) do
                if EnemyVisuals.Outline and used < ENEMY_OUTLINE_BUDGET then
                    if false and HasDeadParts(e.M) then -- (0.91, owner: the per-part outlines "don't really make sense": every
                        -- boss part takes hits now, so the whole model gets one outline again; the 0.85 code is kept, switched off)
                        -- only the parts a shot can hit
                        if e.St.HL then e.St.HL:Destroy(); e.St.HL = nil end
                        e.St.HLParts = e.St.HLParts or {}
                        local keep = {}
                        for _, p in ipairs(HittableParts(e.M)) do
                            if used >= ENEMY_OUTLINE_BUDGET then break end
                            keep[p] = true
                            local h = e.St.HLParts[p]
                            if not h or not h.Parent then
                                h = Instance.new("Highlight")
                                h.Name = "AimRngOutline"
                                h.Adornee = p
                                ConfigureOutline(h, e.St, e.M)
                                h.Parent = e.M
                                e.St.HLParts[p] = h
                            end
                            used += 1
                        end
                        for p, h in pairs(e.St.HLParts) do
                            if not keep[p] then h:Destroy(); e.St.HLParts[p] = nil end
                        end
                    else
                        if e.St.HLParts then
                            for _, h in pairs(e.St.HLParts) do h:Destroy() end
                            e.St.HLParts = nil
                        end
                        if not e.St.HL or not e.St.HL.Parent then
                            local hl = Instance.new("Highlight")
                            hl.Name = "AimRngOutline"
                            hl.Adornee = e.M
                            ConfigureOutline(hl, e.St)
                            hl.Parent = e.M
                            e.St.HL = hl
                        end
                        do -- (BOTFIX 2026-10-24: linked floors switch NoXRay as you move between rooms -- DungeonClient)
                            local want = (EnemyVisuals.ThroughWalls and e.M:GetAttribute("NoXRay") ~= true) and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
                            if e.St.HL.DepthMode ~= want then e.St.HL.DepthMode = want end
                        end
                        used += 1
                    end
                elseif e.St.HL or e.St.HLParts then
                    ClearOutline(e.St)
                end
            end
            task.wait(0.3)
        end
    end)
end

-- ==================== ENEMY MOTION SMOOTHING ====================
-- The server steps enemies with PivotTo 10-20 times a second (bosses 10x/s). Anchored-part moves are
-- NOT interpolated by Roblox, so on screen every enemy teleported in small hops -- the stutter. Here each
-- tagged enemy is rendered slightly in the past, interpolating between the last server updates it
-- received, so motion is continuous every frame. Hits still register exactly: the client raycasts
-- against what's drawn and the server trusts the reported part (CombatServer ReportHit).
local CollectionService = game:GetService("CollectionService")
local ENEMY_MAX_SNAPSHOTS = 5
local enemySmooth: { [Model]: any } = {}
local enemyBulkParts: { BasePart } = {}
local enemyBulkCFrames: { CFrame } = {}

local function CFDiffers(a: CFrame, b: CFrame): boolean
    return (a.Position - b.Position).Magnitude > 0.002
        or a.XVector:Dot(b.XVector) < 0.999995
        or a.YVector:Dot(b.YVector) < 0.999995
end

local function RegisterEnemy(model: Instance)
    if not model:IsA("Model") or enemySmooth[model] then return end
    if model:GetAttribute("NoSmooth") or model:GetAttribute("LocalSim") then return end -- moved every frame by its own AI on this client
    if DungeonGeneratorShared.RunIdOf(model) ~= LocalPlayer:GetAttribute("RunId") then return end -- another party's dungeon
    local st = { Parts = {}, LastSet = {}, Snaps = {}, Interval = 0.05, LastArrival = os.clock(), Ref = nil :: BasePart? }
    local first = { t = os.clock(), cfs = {} }
    local function addPart(d: Instance)
        if d:IsA("BasePart") and not st.LastSet[d] and not d:GetAttribute("LocalDeco") then
            table.insert(st.Parts, d)
            st.LastSet[d] = d.CFrame
            for _, s in ipairs(st.Snaps) do s.cfs[d] = d.CFrame end
            first.cfs[d] = d.CFrame
        end
    end
    for _, d in ipairs(model:GetDescendants()) do addPart(d) end
    st.Snaps[1] = first
    st.Ref = model.PrimaryPart or st.Parts[1]
    -- server-run (party) bots come plain: dress them here; the decorations ride on the body (st.Local)
    local okD, deco = pcall(DungeonGeneratorShared.DecorateReplicated, model)
    if okD and deco then
        local pv = model:GetPivot()
        for _, e in ipairs(deco) do e.Off = pv:ToObjectSpace(e.Part.CFrame) end
        st.Local = deco
    end
    st.Conn = model.DescendantAdded:Connect(addPart)
    enemySmooth[model] = st
end

local function UnregisterEnemy(model: Instance)
    local st = enemySmooth[model]
    if st then
        if st.Conn then st.Conn:Disconnect() end
        enemySmooth[model] = nil
    end
end

for _, m in ipairs(CollectionService:GetTagged("AimRngEnemy")) do RegisterEnemy(m) end
CollectionService:GetInstanceAddedSignal("AimRngEnemy"):Connect(RegisterEnemy)
CollectionService:GetInstanceRemovedSignal("AimRngEnemy"):Connect(UnregisterEnemy)

RunService:BindToRenderStep("AimRngEnemySmoothing", Enum.RenderPriority.Character.Value, function()
    local now = os.clock()
    local n = 0
    for model, st in pairs(enemySmooth) do
        -- (optimization pass 2026-10-27: solo bosses / mini-bosses / goblins / trial bosses get LocalSim from DungeonClient
        -- only after their tag registered them here, so they were re-posed ~2 frames behind their own client AI every frame
        -- -- three full-model moves a frame on the biggest models. Party (server-run) enemies never carry LocalSim)
        if not model.Parent or model:GetAttribute("LocalSim") then
            UnregisterEnemy(model)
            continue
        end
        local ref = st.Ref
        if not ref or not ref.Parent then
            st.Ref = model.PrimaryPart or st.Parts[1]
            ref = st.Ref
            if not ref then continue end
        end
        local snaps = st.Snaps
        local latest = snaps[#snaps]
        -- (0.66 fix: a re-picked ref -- the old one gone, a PrimaryPart never seen by addPart -- had no LastSet entry and
        -- CFDiffers errored every frame on party bosses)
        if st.LastSet[ref] == nil then st.LastSet[ref] = ref.CFrame end

        -- A new server update arrived if the reference part's CFrame is no longer what we drew.
        if CFDiffers(ref.CFrame, st.LastSet[ref]) then
            local gap = now - st.LastArrival
            st.LastArrival = now
            if gap < 0.3 then
                st.Interval = st.Interval + (math.clamp(gap, 1 / 60, 0.2) - st.Interval) * 0.25
            else
                -- Was standing still: re-anchor the old pose one interval ago so it starts moving crisply.
                latest.t = now - st.Interval
            end
            local cfs = table.clone(latest.cfs)
            latest = { t = now, cfs = cfs }
            table.insert(snaps, latest)
            if #snaps > ENEMY_MAX_SNAPSHOTS then table.remove(snaps, 1) end
        end

        -- Pick up every part's server-written CFrame (sub-parts can arrive a frame after the ref part).
        local parts = st.Parts
        for i = 1, #parts do
            local p = parts[i]
            local cur = p.CFrame
            if CFDiffers(cur, st.LastSet[p]) then latest.cfs[p] = cur end
        end

        -- Render one update-interval (+ jitter margin) in the past, between the two bracketing updates.
        local renderT = now - (st.Interval + 0.02)
        local s0, s1 = snaps[1], snaps[1]
        for i = #snaps, 1, -1 do
            if snaps[i].t <= renderT then
                s0 = snaps[i]
                s1 = snaps[i + 1] or snaps[i]
                break
            end
        end
        local alpha = 1
        if s1 ~= s0 then alpha = math.clamp((renderT - s0.t) / math.max(s1.t - s0.t, 1e-3), 0, 1) end

        for i = 1, #parts do
            local p = parts[i]
            if p.Parent then
                local a, b = s0.cfs[p], s1.cfs[p]
                if a and b then
                    local cf = (alpha >= 1) and b or a:Lerp(b, alpha)
                    n += 1
                    enemyBulkParts[n] = p
                    enemyBulkCFrames[n] = cf
                    st.LastSet[p] = cf
                end
            end
        end
        -- locally built decorations follow the drawn body (pivot = the reference part's drawn pose)
        if st.Local and model.PrimaryPart and st.LastSet[model.PrimaryPart] then
            local pv = st.LastSet[model.PrimaryPart] * model.PrimaryPart.PivotOffset
            for _, e in ipairs(st.Local) do
                if e.Part.Parent then
                    n += 1
                    enemyBulkParts[n] = e.Part
                    enemyBulkCFrames[n] = pv * e.Off
                end
            end
        end
        -- (COMMAND REACH 2026-11-07) a party Commander's faint floor ring: built here, on the first drawn frame (at register time
        -- the root / mods may not be there yet), so nothing extra replicates; it follows the drawn body. false = not a Commander.
        if st.CmdRing ~= false and model.PrimaryPart and st.LastSet[model.PrimaryPart] then
            local at = st.LastSet[model.PrimaryPart].Position
            if st.CmdRing == nil then
                local okC, cr = pcall(function()
                    return DungeonGeneratorShared.HasEliteMod(model:GetAttribute("EliteMods"), "Commander") and DungeonGeneratorShared.CommandFloorRing(model, at) or false
                end)
                st.CmdRing = okC and cr or false
            end
            if st.CmdRing then DungeonGeneratorShared.CommandFloorStep(st.CmdRing, model, at, now) end
        end
    end
    for i = #enemyBulkParts, n + 1, -1 do
        enemyBulkParts[i] = nil
        enemyBulkCFrames[i] = nil
    end
    if n > 0 then
        Workspace:BulkMoveTo(enemyBulkParts, enemyBulkCFrames, Enum.BulkMoveMode.FireCFrameChanged)
    end
end)

-- HIT NUMBERS v2 (0.58): pooled, merging, styled by the equipped UI theme (AimRngShared/HitNumbers)
local HitNumbersM = require(sharedFolder:WaitForChild("HitNumbers"))
UI.Encounters = require(sharedFolder:WaitForChild("Encounters")) -- (UPDATE 7 run encounters; a field: this chunk is at the 200-local limit)
local function SpawnDamageText(amount: number, isWeakSpot: boolean, isCrit: boolean, worldPos: Vector3, kind: string?, culled: boolean?, elem: string?, killed: boolean?, target: any?, dtype: string?)
    local dnMode = GameSettings.Get("DamageNumbers")
    if dnMode == "Off" or (dnMode == "Big hits only" and not (isWeakSpot or isCrit or culled)) then return end
    if dnMode == "Boss fights only" then -- (fixes 2026-10-16 #4: a boss / boss orb hit, or anything on a boss arena floor)
        local bossFight = false
        local m = typeof(target) == "Instance" and target or nil
        while m and m ~= Workspace and not bossFight do
            bossFight = m:GetAttribute("IsBoss") == true or m:GetAttribute("BossOrb") == true
            m = m.Parent
        end
        if not bossFight then
            local myRun = LocalPlayer:GetAttribute("RunId")
            local partyRuns = Workspace:FindFirstChild("PartyRuns")
            local dungeon = (myRun and partyRuns and partyRuns:FindFirstChild("Run_" .. myRun)) or Workspace:FindFirstChild("DungeonFacility")
            bossFight = dungeon ~= nil and dungeon:GetAttribute("BossArena") ~= nil and dungeon:GetAttribute("BossArena") ~= false
        end
        if not bossFight then return end
    end
    if typeof(worldPos) ~= "Vector3" or type(amount) ~= "number" then return end
    HitNumbersM.Show(amount, worldPos, { Weak = isWeakSpot, Crit = isCrit, Kind = kind, Culled = culled, Elem = elem, Killed = killed, Target = target, DType = dtype }) -- (UPDATE 8: DType colours it)
end

local function TriggerHitmarker(isWeakSpot: boolean)
    if not GameSettings.Get("Hitmarker") then return end
    UI.hitmarker.Visible = true
    for _, l in ipairs(UI.hitmarker:GetChildren()) do
        if l:IsA("Frame") then
            l.BackgroundColor3 = isWeakSpot and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(255, 255, 255)
        end
    end
    task.delay(0.08, function() UI.hitmarker.Visible = false end)
end

Remotes.GetEvent("HitConfirmed").OnClientEvent:Connect(function(data)
    -- Gun hits already played their sound + hitmarker instantly on the client (ExecuteRaycastShot);
    -- only melee needs it here. DoT / explosion / arc numbers just show their colored number.
    if data.Kind == "Melee" then
        if GameSettings.Get("HitSound") ~= "Off" then SoundHelper.Play("HitNormal") end
        TriggerHitmarker(false)
        if UI.MeleeImpactFor then pcall(UI.MeleeImpactFor, data) end
    end
    if data.Killed then SoundHelper.Play("Kill") end
    if data.Killed and UI.SkinKill then UI.SkinKill(data) end
    SpawnDamageText(data.Damage, data.IsWeakSpot, data.IsCrit, data.Position, data.Kind, data.Culled, data.Elem, data.Killed, data.Target, data.DType)
end)

;(function()
    -- UI THEMES (HudThemes + UITheme): the equipped theme restyles EVERY window, title bar, card and chip (UIStyle
    -- tags them) plus these HUD panels and bars; premium themes add art, animated borders, fonts, ambient particles
    -- and window-open effects. Default restores the original look.
    local HudThemes = require(sharedFolder:WaitForChild("HudThemes"))
    local UITheme = require(sharedFolder:WaitForChild("UITheme"))
    local CS = game:GetService("CollectionService")
    for _, p in ipairs({ UI.levelFrame, UI.healthFrame, UI.weaponCard, UI.raidBanner, hudGui:FindFirstChild("ContractsTracker"),
        hudGui:FindFirstChild("LootCard"), hudGui:FindFirstChild("GroundLootCard"), hudGui:FindFirstChild("BetterWeaponBanner"),
        hudGui:FindFirstChild("DungeonVictoryBanner"), hudGui:FindFirstChild("BoonOffer"), hudGui:FindFirstChild("SpectateBar") }) do
        if p and p:IsA("GuiObject") then CS:AddTag(p, UITheme.Tags.Hud) end
    end
    UITheme.SetBars({ HpFill = UI.hpFill, HpBg = UI.hpFill and UI.hpFill.Parent, XpFill = UI.xpFill })
    -- (Update 5: the level badge + XP readout follow the theme's accent / text; the badge's ink stays readable)
    UITheme.OnChanged(function(t)
        local acc = (t and t.Accent) or UIStyle.Colors.Accent
        local _ = acc -- (UI CLEAN: "LV n" is plain text -- the theme's text colour, no badge slab)
        if UI.lvlBadge then UI.lvlBadge.TextColor3 = (t and t.Text) or UIStyle.Colors.Text end
    end)
    UI.ApplyHudTheme = function(t) UITheme.Apply(t) end
    UI.ApplyHudTheme(HudThemes.For(clientState))
    UI.RefreshHudTheme = function() UI.ApplyHudTheme(HudThemes.For(clientState)) end
end)()

;(function()
    -- OTHER PLAYERS' SHOTS: your trigger pulls go to the server (ShotFx, unreliable) and come back to everyone nearby,
    -- who draw a muzzle flash + tracer from your world gun and hear your gun (3D, from where you stand)
    local shotFx = Remotes.GetEvent("ShotFx")
    local WeaponRigsS = require(sharedFolder:WaitForChild("WeaponRigs"))
    local Debris = game:GetService("Debris")
    UI.ShotFx = function(hitPos: Vector3)
        if Players.LocalPlayer:GetAttribute("ThirdPerson") then return end
        if Players.LocalPlayer:GetAttribute("TryOnFP") then return end -- (try-ons are private: nobody else sees or hears them)
        (shotFx :: any):FireServer(hitPos, Workspace:GetServerTimeNow()) -- (0.83: stamped: spectators play it in step)
    end
    local live = 0
    local soundT: { [Player]: number } = {}
    local SkinFXP = require(sharedFolder:WaitForChild("SkinFX"))
    local InstanceKeyP = require(sharedFolder:WaitForChild("InstanceKey"))
    UI.SameInstance = function(p: Player): boolean return InstanceKeyP.Of(p) == InstanceKeyP.Of(Players.LocalPlayer) end
    local function OnPeerShot(shooter: Player, hitPos: Vector3, baseId: string, skinKind: string?)
        if UI.Poser then UI.Poser.Shot(shooter.Character) end -- (their body kicks with the shot)
        if UI.SpectateShot and UI.SpectateShot(shooter, hitPos, baseId, skinKind) then return end -- (0.62: the watched player's shot, drawn from their first-person gun)
        -- (single instances; 0.83: a watcher sees everyone in the watched instance too -- a duel's opponent)
        if UI.SameInstance and not UI.SameInstance(shooter) and not InstanceKeyP.Sees(InstanceKeyP.Of(Players.LocalPlayer), InstanceKeyP.Of(shooter)) then return end
        local char = shooter.Character
        if not char or live > 40 then return end
        local def = WeaponRigsS.Guns[baseId or ""]
        local gun = char:FindFirstChild("WorldGun")
        local frame = gun and gun:FindFirstChild("Frame") :: BasePart?
        local from: Vector3
        if frame and def and def.Points and def.Points.Muzzle then
            from = frame.CFrame:PointToWorldSpace(def.Points.Muzzle.Position * (gun :: Model):GetScale())
        else
            local head = char:FindFirstChild("Head") :: BasePart?
            if not head then return end
            from = head.Position + (hitPos - head.Position).Unit * 1.5
        end
        local cam = Workspace.CurrentCamera
        if cam and (from - cam.CFrame.Position).Magnitude > 320 then return end
        live += 1
        task.delay(0.12, function() live -= 1 end)
        -- flash: a bright star at the muzzle + a short light (BEAM GUNS v5: an Arcwright gun's is a smaller discharge in
        -- its beam colour, and its tracer too)
        local ecol = def and def.Energy and (def.BeamColor or Color3.fromRGB(70, 215, 255)) or nil
        local flash = Instance.new("Part")
        flash.Name = "PeerFlash"; flash.Anchored = true; flash.CanCollide = false; flash.CanQuery = false; flash.CanTouch = false; flash.CastShadow = false
        flash.Material = Enum.Material.Neon; flash.Color = ecol or Color3.fromRGB(255, 214, 140); flash.Shape = Enum.PartType.Ball
        flash.Size = ecol and Vector3.new(0.45, 0.45, 0.45) or Vector3.new(0.7, 0.7, 0.7); flash.CFrame = CFrame.new(from); flash.Transparency = 0.15
        local light = Instance.new("PointLight"); light.Color = ecol or Color3.fromRGB(255, 190, 110); light.Range = 9; light.Brightness = 2.5; light.Parent = flash
        flash.Parent = Workspace
        TweenService:Create(flash, TweenInfo.new(0.07), { Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2) }):Play()
        TweenService:Create(light, TweenInfo.new(0.07), { Brightness = 0 }):Play()
        Debris:AddItem(flash, 0.1)
        -- tracer: a thin streak to where it landed (a SkinSets skin draws its own)
        local dist = (hitPos - from).Magnitude
        if type(skinKind) == "string" and SkinFXP.Sets[skinKind] and dist > 1.5 then
            SkinFXP.ShotFx(skinKind, from, hitPos, nil, true)
        elseif dist > 1.5 then
            local tr = Instance.new("Part")
            tr.Name = "PeerTracer"; tr.Anchored = true; tr.CanCollide = false; tr.CanQuery = false; tr.CanTouch = false; tr.CastShadow = false
            tr.Material = Enum.Material.Neon; tr.Color = ecol or Color3.fromRGB(255, 226, 170); tr.Transparency = 0.25
            tr.Size = Vector3.new(0.07, 0.07, dist); tr.CFrame = CFrame.lookAt((from + hitPos) / 2, hitPos)
            tr.Parent = Workspace
            TweenService:Create(tr, TweenInfo.new(0.09), { Transparency = 1 }):Play()
            Debris:AddItem(tr, 0.11)
        end
        -- sound: the gun's own fire sound, from the shooter (rolls off with distance)
        local now = os.clock()
        if now - (soundT[shooter] or 0) < 0.05 then return end
        soundT[shooter] = now
        local set = def and WeaponRigsS.Sounds[def.Sounds or ""]
        local s = set and set.Fire
        local sk = type(skinKind) == "string" and SkinFXP.FireFor(skinKind, baseId) -- (a skinned gun's own shot)
        if sk then s = { Id = "rbxassetid://" .. tostring(sk.Id), Volume = sk.Volume, Pitch = 1 } end
        local at = Instance.new("Attachment")
        at.WorldPosition = from
        at.Parent = Workspace.Terrain
        local snd = Instance.new("Sound")
        snd.SoundId = s and s.Id or "rbxassetid://3603368006"
        snd.Volume = (s and s.Volume or 0.8) * 0.75
        snd.PlaybackSpeed = (s and s.Pitch or 1) * (0.96 + math.random() * 0.08)
        snd.RollOffMode = Enum.RollOffMode.InverseTapered
        snd.RollOffMinDistance = 12; snd.RollOffMaxDistance = 260
        local grp = game:GetService("SoundService"):FindFirstChild("AimRngMix_Weapons")
        if grp then snd.SoundGroup = grp :: SoundGroup end
        snd.Parent = at
        snd:Play()
        Debris:AddItem(at, 2)
    end
    shotFx.OnClientEvent:Connect(function(shooter: Player, hitPos: Vector3, baseId: string, skinKind: string?, stamp: number?)
        if typeof(shooter) ~= "Instance" or typeof(hitPos) ~= "Vector3" then return end
        if UI.watching and UI.spectate and UI.spectate.AtStamp and type(stamp) == "number" then
            UI.spectate.AtStamp(stamp, function() OnPeerShot(shooter, hitPos, baseId, skinKind) end) -- (0.83: in step with the view)
        else
            OnPeerShot(shooter, hitPos, baseId, skinKind)
        end
    end)
end)()

;(function()
    -- premium skin kill effects (SkinFX): the melee's skin for melee kills, the held gun's skin for everything else
    local SkinFX = require(sharedFolder:WaitForChild("SkinFX"))
    UI.SkinKill = function(data, cs: any?) -- (0.83: cs = someone else's look -- a watched player's kill)
        if not cs and realRig and realRig.GloveBurst then realRig:GloveBurst("Kill") end -- (glove cosmetics: kill burst)
        cs = cs or clientState
        local skin
        if data.Kind == "Melee" then
            skin = MeleeDataHUD.SkinFor(cs, cs.EquippedKnife)
        else
            skin = SkinFX.GunSkinFor(cs, cs.EquippedWeapon and cs.EquippedWeapon.BaseId)
        end
        -- the KILL EFFECTS cosmetic (Cosmetics "KillEffect"): Auto = the skin's own, Off = none, else that set's effect
        local ke = type(cs.CosmeticsEquipped) == "table" and cs.CosmeticsEquipped.KillEffect or "Auto"
        if ke == "Off" then skin = nil
        elseif ke == "Ascension" then skin = { FX = "Seraphim" }
        elseif ke == "Claimed" then skin = { FX = "Infernal" }
        elseif ke ~= "Auto" then
            -- a SkinSets kill effect (Cosmetics KillEffect items carry the set's FX kind)
            local okC, CosM = pcall(require, sharedFolder:WaitForChild("Cosmetics"))
            local ce = okC and CosM.Find("KillEffect", ke)
            if ce and ce.FX then skin = { FX = SkinFX.KillFX(cs, ce.FX, "KillEffect:" .. ke) } end -- (colourways: the equipped one, see SkinFX.KillFX)
        end
        if skin and skin.FX then
            -- (colourways, owner 2026-10-14) the effect + banner always in the colourway this player wears on the set
            local fx = SkinFX.KillFX(cs, skin.FX, (ke ~= "Auto" and ke ~= "Off") and ("KillEffect:" .. ke)
                or ((data.Kind == "Melee") and "MeleeSkin:" or "WeaponSkin:") .. tostring(skin.Id or ""))
            SkinFX.KillEffect({ FX = fx }, data.Position)
            -- escalating kill chord + the kill banner (a pip per kill in the streak)
            local okS, streak = pcall(SkinFX.Sound, "Kill")
            pcall(SkinFX.KillBanner, (okS and streak) or 1, fx)
        end
    end
    SkinFX.StartWorld() -- other players' premium skins move like yours (wings, halos, sweeps)
end)()

;(function()
    -- gloves / sleeves on every character (GloveFX.StartWorld dresses the server's shells locally) + the
    -- first-person holo display (Arc Pulse) reads your ammo
    local GloveFX = require(sharedFolder:WaitForChild("GloveFX"))
    GloveFX.StartWorld()
    task.spawn(function()
        while true do
            task.wait(0.1)
            local cs = clientState
            if cs then
                local mx = math.max(1, cs.MaxMag or 1)
                GloveFX.LocalHolo.Big = tostring(cs.CurrentMag or 0)
                GloveFX.LocalHolo.Sub = cs.IsReloading and "RELOAD" or "AMMO"
                GloveFX.LocalHolo.Frac = (cs.CurrentMag or 0) / mx
            end
        end
    end)
end)()

-- HURT FX (HurtFX): hit arcs around the crosshair, an edge glow on hits, a "you're standing in an attack" warning and a
-- low-health pulse -- all at the screen edges / around the crosshair (the old full-screen tint covered your aim)
local HurtFX = require(sharedFolder:WaitForChild("HurtFX"))
HurtFX.Init(function() return clientState.Health, clientState.MaxHealth end)
require(sharedFolder:WaitForChild("BossCues")).Init() -- (0.62: weak points + mechanic targets marked; off-screen arrows)
Remotes.GetEvent("PlayerDamaged").OnClientEvent:Connect(function(dmg, currHp, maxHp, kind, from, ward)
    if kind == "Evade" then if UI.DefFx then UI.DefFx("Evade") end return end -- (UPDATE 8 DEFENCE: Agility dodged it)
    clientState.Health = currHp
    clientState.MaxHealth = maxHp
    ScheduleHudRefresh()
    HurtFX.Damage(dmg + (tonumber(ward) or 0), maxHp, kind, typeof(from) == "Vector3" and from or nil)
    if UI.HpHit and dmg > 0 then UI.HpHit(dmg, maxHp) end
    if UI.DefFx and (tonumber(ward) or 0) > 0 then UI.DefFx("Ward", ward) end -- (the part Ward took)
end)
-- (UPDATE 8 DEFENCE) WARD BAR + defence pop-ups. Ward (Player attrs Ward / WardMax, CombatServer) is a cyan band across the
-- top of the health bar (a shield over your life), its number beside your Plating on the bar. "EVADED" / "-n" (Ward) float
-- up over the health bar -- never near the crosshair, nothing flashes.
;(function()
    local track = UI.hpFill and UI.hpFill.Parent
    if not track then return end
    local CYAN = Color3.fromRGB(90, 220, 255)
    local band = Instance.new("Frame")
    band.Name = "WardFill"
    band.AnchorPoint = Vector2.new(0, 0)
    band.Position = UDim2.new(0, 0, 0, 0)
    band.Size = UDim2.new(0, 0, 0.32, 0)
    band.BackgroundColor3 = CYAN
    band.BorderSizePixel = 0
    band.ZIndex = 6
    band.Visible = false
    band:SetAttribute("Skinned", true)
    band.Parent = track
    UI.HpTag = function()
        if not UI.hpArmor then return end
        local w, m = LocalPlayer:GetAttribute("Ward"), LocalPlayer:GetAttribute("WardMax")
        local wardTxt = (type(m) == "number" and m > 0) and ('<font color="#5ADCFF">WARD ' .. ItemData.FormatNumber(math.round(tonumber(w) or 0)) .. '</font>  •  ') or ""
        UI.hpArmor.RichText = true
        UI.hpArmor.Text = wardTxt .. (UI.platTxt or "")
    end
    local function Upd()
        local w, m = LocalPlayer:GetAttribute("Ward"), LocalPlayer:GetAttribute("WardMax")
        local on = type(m) == "number" and m > 0
        band.Visible = on
        if on then
            local f = math.clamp((tonumber(w) or 0) / m, 0, 1)
            TweenService:Create(band, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Size = UDim2.new(f, 0, band.Size.Y.Scale, band.Size.Y.Offset) }):Play() -- (the height is the HUD layout's: HudClean)
        end
        UI.HpTag()
    end
    LocalPlayer:GetAttributeChangedSignal("Ward"):Connect(Upd)
    LocalPlayer:GetAttributeChangedSignal("WardMax"):Connect(Upd)
    Upd()
    UI.DefFx = function(kind, n)
        local hs = UI.HudStack
        local t = Instance.new("TextLabel")
        t.BackgroundTransparency = 1
        t.AnchorPoint = Vector2.new(0.5, 1)
        t.Size = UDim2.fromOffset(160, 26)
        t.Position = UDim2.new(0, hs.X + hs.W * 0.5 + math.random(-50, 50), 1, hs.HealthY - hs.HealthH - 4)
        t.Font = Enum.Font.GothamBlack
        t.TextSize = 18
        t.TextStrokeTransparency = 0.3
        t.TextColor3 = (kind == "Evade") and Color3.fromRGB(200, 255, 210) or CYAN
        t.Text = (kind == "Evade") and "EVADED" or ("-" .. ItemData.FormatNumber(math.round(tonumber(n) or 0)))
        t.ZIndex = 8
        t.Parent = hudGui
        TweenService:Create(t, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = t.Position - UDim2.fromOffset(0, 36), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
        task.delay(0.75, function() t:Destroy() end)
    end
end)()
-- HEALTH BAR FX (2026-10-05): the chip lingers then drains, the bar shakes + flashes on a hit, a damage number floats
-- up over the bar, a red pulse under 30% health, a green flash on heals
;(function()
    local chipPct, chipHoldUntil, shakeUntil, shakeAmp, hitFlashAt = 1, 0, 0, 0, -99
    local basePos = UI.healthFrame.Position
    -- (UI CLEAN: the default bar is off-white; under 30% it shifts smoothly toward red -- no pulse, no flashing)
    local RED, LOW, HEAL = UIStyle.Colors.Text, Color3.fromRGB(232, 80, 80), Color3.fromRGB(96, 206, 140)
    local Theme = require(sharedFolder:WaitForChild("UITheme"))
    UI.HpHit = function(dmg, maxHp)
        local frac = math.clamp((tonumber(dmg) or 0) / math.max(1, tonumber(maxHp) or 1), 0, 1)
        chipHoldUntil = os.clock() + 0.45
        shakeUntil = os.clock() + 0.28
        shakeAmp = 1 + 3 * math.min(1, frac * 3) -- (UI CLEAN: a small nudge, not a shake)
        hitFlashAt = os.clock()
        -- the damage number, floating up from the bar
        local n = Instance.new("TextLabel")
        n.BackgroundTransparency = 1
        n.AnchorPoint = Vector2.new(0.5, 1)
        n.Size = UDim2.fromOffset(160, 30)
        local hs = UI.HudStack
        n.Position = UDim2.new(0, hs.X + hs.W * 0.5 + math.random(-60, 60), 1, hs.HealthY - hs.HealthH - 4) -- (over the bottom-left health bar)
        n.Font = Enum.Font.GothamBlack
        n.TextSize = 20 + math.floor(14 * math.min(1, frac * 3))
        n.TextColor3 = Color3.fromRGB(255, 90, 90)
        n.TextStrokeTransparency = 0.2
        n.Text = "-" .. tostring(math.round(tonumber(dmg) or 0))
        n.ZIndex = 8
        n.Parent = hudGui
        TweenService:Create(n, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = n.Position - UDim2.fromOffset(0, 46), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
        task.delay(0.85, function() n:Destroy() end)
    end
    local idle = false -- (Update 5: nothing to animate -> skip the frame; the bar used to repaint every frame)
    RunService.RenderStepped:Connect(function(dt)
        local f = UI.hpFill
        if not (f and UI.hpChip and UI.healthFrame.Visible) then return end
        local pct = UI.hpPct or 1
        local now = os.clock()
        local busy = pct ~= chipPct or now < shakeUntil or now - hitFlashAt < 0.2 or now - (UI.hpHealAt or -99) < 0.55
        if not busy then
            if idle then return end
            idle = true -- (one last frame to settle the colours)
        else
            idle = false
        end
        -- chip: snaps up with heals, lingers on a hit, then drains to the fill
        if pct >= chipPct then chipPct = pct
        elseif now >= chipHoldUntil then chipPct = math.max(pct, chipPct - dt * 0.9) end
        UI.hpChip.Size = UDim2.new(chipPct, 0, 1, 0)
        -- shake
        if now < shakeUntil then
            local k = (shakeUntil - now) / 0.28
            UI.healthFrame.Position = (UI.hpBasePos or basePos) + UDim2.fromOffset(math.random(-1, 1) * shakeAmp * k, math.random(-1, 1) * shakeAmp * 0.4 * k)
        else
            UI.healthFrame.Position = UI.hpBasePos or basePos -- (UI.hpBasePos: the phone HUD layout moves the bar)
        end
        -- colour: hit flash (white) -> low-health pulse (red) -> heal flash (green)
        local low = pct < 0.3
        local pulse = 0
        local th = Theme.Current()
        local norm = (type(th) == "table" and th.HpFill) or RED -- (a premium UI theme's own bar colour stays the base)
        local base = low and norm:Lerp(LOW, math.clamp((0.3 - pct) / 0.2, 0.35, 1)) or norm
        local healK = math.clamp(1 - (now - (UI.hpHealAt or -99)) / 0.5, 0, 1)
        local hitK = math.clamp(1 - (now - hitFlashAt) / 0.18, 0, 1)
        f.BackgroundColor3 = base:Lerp(HEAL, healK):Lerp(LOW, hitK * 0.5) -- (a hit tints it red for a moment)
        if UI.hpStroke then
            -- (Update 5: the edge is ink like every slab; it lights on a hit, red while low, green on a heal)
            UI.hpStroke.Color = low and LOW or ((healK > 0) and HEAL or ((hitK > 0) and Color3.fromRGB(240, 240, 240) or UIStyle.Colors.Ink))
            UI.hpStroke.Thickness = 2 + 2 * math.max(hitK, pulse * 0.5)
            UI.hpStroke.Transparency = 0
        end
    end)
end)()

-- ==================== [5. WEAPON SHOOTING LOGIC] ====================
-- consumesAmmo defaults to true (a normal single-shot weapon fires once, consumes once). Shotgun
-- pellets and burst-fire follow-up rounds pass false for every shot after the first in the same
-- trigger pull -- the mag already had its one round deducted client-side in FireWeapon, and the
-- server must mirror that exactly (one deduction per trigger pull), not once per raycast, or a
-- shotgun's 8 pellets / a burst's 3 rounds drain 8x / 3x as fast as the client's own ammo counter.
-- SHOT AIM (owner 2026-10-05: "hitreg is still slightly off, especially in aim trials"): mouse movement is saved up and
-- only turns the camera when the next frame draws, but a click fires at once -- so a flick-and-click shot left from where
-- the crosshair was a frame BEFORE the end of the flick. The shot now adds the not-yet-applied mouse movement (same maths
-- as the camera); if another camera is in charge (hub orbit, spectate), it uses the camera as drawn.
UI.ShotLook = function(): Vector3?
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local nowDir = (CFrame.Angles(0, camYaw, 0) * CFrame.Angles(camPitch, 0, 0)).LookVector
    if nowDir:Dot(cam.CFrame.LookVector) < 0.9995 then return nil end -- (not our first-person camera this frame)
    if isCursorUnlocked or isAnyMenuOpen then return nil end
    local d = camPendingDelta * UserInputService.MouseDeltaSensitivity * (isAiming and GameSettings.Get("ADSSensitivity") or 1)
    if GameSettings.Get("InvertY") then d = Vector2.new(d.X, -d.Y) end
    if d.X == 0 and d.Y == 0 then return nil end
    local zoom = math.tan(math.rad(cam.FieldOfView) * 0.5) / math.tan(math.rad(baseFOV) * 0.5)
    local yaw = camYaw - d.X * CAM_RAD_PER_PIXEL * zoom
    local pitch = math.clamp(camPitch - d.Y * CAM_RAD_PER_PIXEL * zoom, -CAM_PITCH_LIMIT, CAM_PITCH_LIMIT)
    return (CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)).LookVector
end
local function ExecuteRaycastShot(dirOffset: Vector3?, consumesAmmo: boolean?)
    local origin = Camera.CFrame.Position
    local baseDir = UI.ShotLook() or Camera.CFrame.LookVector
    if dirOffset then baseDir = (baseDir + dirOffset).Unit end
    local direction = baseDir * 1000

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filterList = {}
    if viewmodel then table.insert(filterList, viewmodel) end
    if LocalPlayer.Character then table.insert(filterList, LocalPlayer.Character) end
    params.FilterDescendantsInstances = filterList

    local result = Workspace:Raycast(origin, direction, params)
    local hitPos = result and result.Position or (origin + direction)
    if realRig then realRig:Tracer(hitPos, result and result.Normal) end
    if UI.ShotFx and consumesAmmo ~= false and not UI.TrialActive then UI.ShotFx(hitPos) end -- (others see + hear the shot)
    if UI.TryOnShot and result then UI.TryOnShot(result) end -- (store try-on: the target dummy)
    -- (UPDATE 7 RUN ENCOUNTERS: a running Vault Lock judges every ray -- a pin hit is the lock's shot; a missed pull resets it)
    if UI.Encounters and UI.Encounters.Active() and UI.Encounters.OnShot(result, consumesAmmo) then TriggerHitmarker(false); return end
    if UI.PvpShot and UI.PvpShot(origin, baseDir) then return end -- (0.59 DUELS: PvpClient tests the arena + the opponent's hitbox)
    if UI.TrialActive and UI.TrialRunner then
        UI.TrialRunner.OnShot(result) -- Aim Trials score locally; nothing goes to the server
        return
    end
    if UI.Range then UI.Range.CountShot(consumesAmmo) end -- Training Grounds accuracy

    -- (ENEMY ATTACKS PILOT 2026-10-30) a heavy's SHELL in the air: shooting it pops it (solo: it only exists on this client, the
    -- server hears a shell CLAIM it budgets per live Heavy -- neutral for Focus within the budget; party: the server's own shell,
    -- CombatServer checks the hit + pops it)
    if result and result.Instance and result.Instance.Name == "AtkShell" and result.Instance:GetAttribute("ShellShot") then
        local EAc = require(game.ReplicatedStorage.AimRngShared.EnemyAttacks)
        TriggerHitmarker(false)
        if GameSettings.Get("HitSound") ~= "Off" then SoundHelper.Play("HitNormal") end
        if EAc.IsShell(result.Instance) then
            EAc.PopShell(result.Instance)
            Remotes.GetEvent("ReportHit"):FireServer(nil, result.Position, consumesAmmo, "AtkShell")
        else
            Remotes.GetEvent("ReportHit"):FireServer(result.Instance, result.Position, consumesAmmo)
        end
        return
    end

    if result and result.Instance then
        local spark = Instance.new("Part")
        spark.Name = "ImpactSpark"; spark.Anchored = true; spark.CanCollide = false; spark.CanQuery = false; spark.CanTouch = false; spark.Material = Enum.Material.Neon
        local hitName = result.Instance:GetAttribute("HitAs") or result.Instance.Name -- (enemy decorations: the part they sit on)
        local isCritSpot = hitName == "Head" -- (0.76: the head is the only weak spot)
        spark.BrickColor = isCritSpot and BrickColor.new("Really red") or BrickColor.new("Bright yellow")
        spark.Size = Vector3.new(0.35, 0.35, 0.35)
        spark.Position = hitPos
        spark.Parent = Workspace
        game:GetService("Debris"):AddItem(spark, 0.04)

        local model = result.Instance.Parent
        local link = result.Instance:FindFirstChild("HitModel") -- (boss shield orbs live outside the boss model)
        if link and link:IsA("ObjectValue") and link.Value then model = link.Value end
        while model and model ~= Workspace and not model:GetAttribute("Health") do model = model.Parent end -- (0.91: nested boss parts)
        if model == Workspace then model = nil end
        if model and model:GetAttribute("Health") then
            -- (ENEMY ATTACKS PILOT) a head hit on a solo marksman while it charges cancels its shot (BotRoles reads WeakHitAt)
            if isCritSpot and model:GetAttribute("AimCharge") then model:SetAttribute("WeakHitAt", Workspace:GetServerTimeNow()) end
            SoundHelper.ChainHit() -- (HIT CHAIN: consecutive hits climb in pitch)
            if isCritSpot then
                if GameSettings.Get("HeadHitSound") ~= "Off" then SoundHelper.Play("HitCrit") end
            elseif GameSettings.Get("HitSound") ~= "Off" then
                SoundHelper.Play("HitNormal")
            end
            TriggerHitmarker(isCritSpot)
        end

        -- (Update 6 TUTORIAL) the tutorial hall's targets only exist on this client: scored there, nothing to the server
        if UI.TutorialShot and UI.TutorialShot(result) then return end
        -- Training Grounds bots only exist on this client and are scored here
        if UI.Range and UI.Range.HandleHit(result.Instance, result.Position) then return end
        -- show the hit (and a clearly lethal kill) at once; the server's numbers follow (DungeonClient.PredictHit)
        if model and model:GetAttribute("Health") and UI.EstimateShot and not string.find(hitName, "^ShieldOrb") then DungeonClient.PredictHit(result.Instance, UI.EstimateShot(isCritSpot, model)) end
        -- (fixes 2026-10-16 #3) a boss target shows your hit: its "health" is OrbNeed rifle hits x 10, and a hit counts like
        -- CombatServer.OrbWeight (10 / shots a second, split over pellets) -- a rifle hit reads 10, a sniper's ~140
        if model and string.find(hitName, "^ShieldOrb") and result.Instance:GetAttribute("OrbNeed") then
            local w = clientState.EquippedWeapon
            local wt = math.clamp(10 / math.max(0.2, (w and w.BaseFireRate) or 10), 0.5, 20) / ((UI.CBSlug and 1) or math.max(1, (w and w.PelletCount) or 1)) -- ((CLASS BUILDS) a slug = one whole shot)
            SpawnDamageText(math.max(1, math.round(wt * 10)), false, false, result.Position, nil, nil, nil, nil, model)
        end
        -- private-dungeon enemies only exist here: report their server stand-in + which part was hit
        local proxy, partName = DungeonClient.ProxyForPart(result.Instance)
        if proxy then
            Remotes.GetEvent("ReportHit"):FireServer(proxy, result.Position, consumesAmmo, partName)
        else
            -- a party bot's decorations exist only on this client: report the real part it sits on
            local hitInst = result.Instance
            if hitInst:GetAttribute("LocalDeco") and model then hitInst = model:FindFirstChild(hitName) or model:FindFirstChild("Torso") or hitInst end
            Remotes.GetEvent("ReportHit"):FireServer(hitInst, result.Position, consumesAmmo)
        end
    else
        SoundHelper.ChainMiss()
        Remotes.GetEvent("ReportHit"):FireServer(nil, hitPos, consumesAmmo)
    end
end

-- a conservative guess of one shot's damage, for showing hits at once (the server's real number follows); stats cached
;(function()
    local cache, cacheAt = nil, 0
    UI.EstimateShot = function(weak: boolean, model: Instance): number?
        local now = os.clock()
        if not cache or now - cacheAt > 0.5 then
            local ok, st = pcall(StatCalculator.Calculate, clientState.EquippedWeapon, clientState.AllocatedNodes, clientState.Streak, clientState.Level,
                clientState.Attributes, clientState.EquippedGear, clientState.EquippedTitle, clientState.SocketedGems, clientState.RunBoons, clientState)
            cache = ok and st or nil
            cacheAt = now
        end
        if not cache or activeSlot ~= "Gun" then return nil end
        local d = (cache.Damage or 0) * (weak and (cache.WeakSpotMultiplier or 2) or (cache.BodyShotMult or 1))
        d *= (model:GetAttribute("DamageTakenMult") or 1)
        if not weak then d *= (model:GetAttribute("BodyArmor") or 1) end -- (BodyArmor = the share a body shot keeps, as CombatServer reads it)
        if model:GetAttribute("ResSet") then -- (UPDATE 8 OFFENSE: the enemy's resistances to this build's damage types)
            local DT = require(sharedFolder:WaitForChild("DamageTypes"))
            d *= DT.ResistMult(cache.DamageShares, DT.ReadResists(model))
        end
        if model:GetAttribute("ModelName") == "TrialForgeheart" then return nil end -- (its shell rules live on the server)
        return d * 0.85 -- (on the low side: a predicted kill should never be wrong)
    end
end)()

-- (2026-10-07, owner: "Reloading should be cancelable with melee, and the inverse would be true with weapons") a reload
-- is cancelled by the melee (quick melee or switching to it): the magazine stays as it was. Each reload has a token so
-- a cancelled one never refills at its old end time.
UI.reloadToken = 0
UI.CancelReload = function()
    if not isReloading then return end
    isReloading = false
    UI.reloadToken += 1
    if realRig and realRig.Stop then pcall(function() realRig:Stop() end) end
    task.spawn(function() pcall(function() Remotes.GetFunction("Reload"):InvokeServer("Cancel") end) end)
end
local function StartReload()
    if isReloading then return end
    if UI.Zen and UI.Zen.IsFurnace(clientState) then return end -- (CHASE ITEMS: Furnace Heart never reloads)
    local cur = clientState.CurrentMag or 0
    local mx = clientState.MaxMag or 18
    if cur >= mx then return end

    isReloading = true
    if not realRig then SoundHelper.Play("Reload") end -- real rigs play their own mag / slide sounds
    UI.ShowAmmo(cur, mx)

    local w = clientState.EquippedWeapon
    local stats = StatCalculator.Calculate(w, clientState.AllocatedNodes, clientState.Streak, clientState.Level, clientState.Attributes, clientState.EquippedGear, clientState.EquippedTitle, clientState.SocketedGems, clientState.RunBoons, clientState)
    local rTime = math.max(0.6, (w.ReloadTime or 2.2) / stats.ReloadSpeed)
    if realRig then
        -- empty = mag drop + slide release; the animation is sped up / slowed to match the real reload time
        local animName = (cur <= 0) and "ReloadEmpty" or "Reload"
        local len = realRig:AnimLength(animName)
        if len > 0 then realRig:Play(animName, len / rTime) end
    end

    vmRecoilY = -0.45
    vmRecoilZ = 0.35

    task.spawn(function()
        Remotes.GetFunction("Reload"):InvokeServer()
    end)

    local startTime = os.clock()
    UI.reloadToken += 1
    local token = UI.reloadToken
    task.spawn(function()
        while isReloading and UI.reloadToken == token and (os.clock() - startTime) < rTime do
            local prog = (os.clock() - startTime) / rTime
            UI.ammoBarFill.Size = UDim2.new(prog, 0, 1, 0)
            task.wait(0.03)
        end
        if UI.reloadToken ~= token then UpdateWeaponHUD() return end -- (cancelled: the magazine stays as it was)
        isReloading = false
        clientState.CurrentMag = clientState.MaxMag
        UpdateWeaponHUD()
        -- (0.62, owner: "After reloading, holding down the mouse doesn't keep shooting"): the held-fire chain stops while
        -- reloading; pick it back up if the trigger is still held (the server's reload flag can trail a moment)
        for _ = 1, 12 do
            if not isMouseDown or isAnyMenuOpen or isCursorUnlocked or isReloading then break end
            if canShoot and not clientState.IsReloading and UI.FireWeapon then UI.FireWeapon() break end
            task.wait(0.05)
        end
    end)
end

local function TriggerQuickMelee()
    if isPerformingMelee or isAnyMenuOpen then return end
    isPerformingMelee = true
    SoundHelper.Play("Melee")

    vmRecoilZ = -0.6
    vmRecoilY = 0.45
    vmMeleeSwingT = 0 -- kicks off the actual knife swing arc, animated in the render loop

    task.spawn(function()
        Remotes.GetFunction("PerformMelee"):InvokeServer()
    end)

    task.delay(0.35, function()
        isPerformingMelee = false
        vmRecoilZ = 0
        vmRecoilY = 0
    end)
end

-- ==================== MELEE SYSTEM (MeleeData) ====================
-- The melee is its own weapon slot drawn by the arms rig: light attacks alternate forehand / backhand
-- (left click, hold to keep swinging), heavy attack on right click, [T] inspects. The hit lands on the
-- animation's "Swing" event (server: PerformMelee("Light"/"Heavy"), range + facing + pace checks).
local MeleeData = require(sharedFolder:WaitForChild("MeleeData"))
local meleeBusyUntil = 0
local meleeCombo = 0
local pendingMeleeKind: string? = nil

local function MeleeStats()
    return ItemData.MeleeWeapons[clientState.EquippedKnife or "Knife"] or ItemData.MeleeWeapons.Knife
end

local function OnRigEvent(name: string)
    if name == "Swing" and pendingMeleeKind then
        local kind = pendingMeleeKind
        pendingMeleeKind = nil
        SoundHelper.Play("Melee")
        -- range bots live only on this client, so the swing is applied to them here (same reach / arc / damage
        -- as the server's melee); everything else goes through the server
        if UI.Range and UI.Range.IsActive() and Camera then
            local md = ItemData.MeleeWeapons[clientState.EquippedKnife or "Knife"] or ItemData.MeleeWeapons.Knife
            local atk = MeleeData.Attacks[kind] or MeleeData.Attacks.Light
            local st = UI.lastHudStats or {}
            local dmg = (st.MeleeDamage or 12) * (md.BaseDamage or 90) / 90 * (atk.Mult or 1)
            if math.random() < (md.CritChance or 0) then dmg *= (md.CritMultiplier or 1.5) end
            local origin = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.CFrame) or Camera.CFrame
            UI.Range.MeleeSweep(CFrame.new(origin.Position) * Camera.CFrame.Rotation, (md.Range or 9) + (atk.RangeBonus or 0), atk.Arc or 0.3, math.round(dmg * 10) / 10)
        end
        if LocalPlayer:GetAttribute("TryOnFP") then return end -- (a try-on swing stays on this screen)
        Remotes.GetFunction("PerformMelee"):InvokeServer(kind)
    end
end

ApplyMeleeToRig = function()
    if not viewmodel then return end
    if not realRig then realRig = ViewmodelRig.new(viewmodel) end
    -- (2026-10-06: a SkinSets melee skin is passed to the rig so its set runs in first person -- its Drive, moving parts,
    -- swing trail, sparkles and swing sounds; without it none of the set melees ever animated in your hand)
    local mskin = MeleeData.SkinFor(clientState, clientState.EquippedKnife)
    realRig:SetWeapon(MeleeData.RigIdFor(clientState.EquippedKnife, clientState), nil, (mskin and mskin.Set) and mskin or nil)
    realRig:ApplyCosmetics({ Glove = ItemData.Gloves.Tactical, Sleeve = ItemData.ArmSkins.Standard, Skin = mskin,
        HandFX = { Glove = require(sharedFolder:WaitForChild("GloveFX")).ViewGloveFor(clientState), Sleeve = require(sharedFolder:WaitForChild("GloveFX")).SleeveFor(clientState) } })
    realRig.OnEvent = OnRigEvent
    for _, e in ipairs(vmPartCache) do if e.Part and e.Part.Parent and e.Kind ~= 3 then e.Part.LocalTransparencyModifier = 1 end end -- hide any old-style gun parts
end

local function SetSlot(slot: string)
    if slot == activeSlot then return end
    if isReloading then UI.CancelReload() end -- (switching to the melee cancels a reload)
    if slot == "Melee" and UI.TrialActive then return end -- Aim Trials are gun-only
    if slot == "Melee" and LocalPlayer:GetAttribute("PvpDuel") then return end -- (0.60: duels are gun-only)
    if slot == "Melee" and LocalPlayer:GetAttribute("ThirdPerson") then return end -- the third-person hub: no weapons out
    activeSlot = slot
    isAiming = false
    pcall(function() Remotes.GetEvent("MoveState"):FireServer("slot:" .. slot) end) -- (CharacterPoser: others see what's in your hand)
    if UI.PlatformControls then UI.PlatformControls.SetLabel("Aim", slot == "Melee" and "DASH" or "AIM") end
    pendingMeleeKind = nil
    meleeBusyUntil = os.clock() + 0.35 -- the equip animation
    UI.meleeBusyIsEquip = true -- (owner 2026-10-03: the DASH-STRIKE goes out instantly when you take the melee out -- see MeleeAttack)
    if slot == "Melee" then
        ApplyMeleeToRig()
    else
        RebuildViewmodelForWeapon(clientState.EquippedWeapon)
        if realRig then realRig.OnEvent = nil end
    end
    UpdateWeaponHUD()
end
UI.SetSlot = SetSlot
UI.ActiveSlot = function() return activeSlot end

local function MeleeAttack(kind: string)
    -- (the 0.35 s equip lock only holds back swings: a dash-strike right as the melee comes out goes immediately)
    local equipOnly = kind == "Heavy" and UI.meleeBusyIsEquip
    if isAnyMenuOpen or not realRig or (os.clock() < meleeBusyUntil and not equipOnly) or UI.InSafeRoom() or LocalPlayer:GetAttribute("ThirdPerson") then return end
    local MC = require(sharedFolder:WaitForChild("MovementController"))
    -- (2026-10-07, owner: "When dashing, your melee shouldn't attack") right click with the melee out is a DASH only (no
    -- swing, no hit), and no swing starts while any dash is running
    if kind == "Heavy" then
        if activeSlot == "Melee" then UI.meleeBusyIsEquip = false; MC.MeleeDash() end
        return
    end
    if MC.Dashing and MC.Dashing() then return end
    UI.meleeBusyIsEquip = false
    local md = MeleeStats()
    local atk = MeleeData.Attacks[kind]
    local interval = atk.Interval / math.max(0.3, md.AttackRate or 1)
    local anim = (kind == "Heavy") and "Heavy" or ((meleeCombo % 2 == 0) and "Light1" or "Light2")
    meleeCombo += 1
    meleeBusyUntil = os.clock() + interval
    pendingMeleeKind = kind
    local len = realRig:AnimLength(anim)
    realRig:Play(anim, math.clamp(len / math.max(0.2, interval), 0.6, 1.8))
    -- keep swinging while the button is held
    task.delay(interval + 0.02, function()
        if activeSlot == "Melee" and isMouseDown and kind == "Light" and not isAnyMenuOpen and not isCursorUnlocked then MeleeAttack("Light") end
    end)
end
UI.MeleeAttack = MeleeAttack
-- a landed melee hit (owner 2026-10-07: melee "hits"): hit-stop + a knock through the arms, and the melee skin's impact
-- (slash flash, sparks, ring, its own hit sound) where the blow landed
UI.MeleeImpactFor = function(data)
    local big = (data.IsCrit or data.Killed) and 1.4 or 1
    if realRig and realRig.MeleeHit then realRig:MeleeHit(big) end
    local _, skinId = MeleeData.SkinFor(clientState, clientState.EquippedKnife)
    local SkinFXm = require(sharedFolder:WaitForChild("SkinFX"))
    if typeof(data.Position) == "Vector3" then SkinFXm.MeleeImpact(data.Position, (skinId ~= "Factory") and skinId or nil, data.IsCrit, data.Killed) end
end

-- QUICK MELEE [V] with the gun out: the arms swap straight to your melee mid-swing (no equip), slash once
-- (the hit lands on the swing's "Swing" event like a normal light attack), then draw the gun back.
local quickMeleeBusy = false
local function QuickMeleeSwing(): boolean
    -- (mid-swing / busy: swallow the press -- returning false here made the caller fall back to the old
    -- procedural melee animation whenever the key was spammed)
    if quickMeleeBusy or isAnyMenuOpen or LocalPlayer:GetAttribute("ThirdPerson") then return true end
    if isReloading then UI.CancelReload() end -- (a quick melee cancels the reload)
    if not viewmodel or not realRig then return false end
    if UI.TrialActive then return true end -- Aim Trials: no melee
    quickMeleeBusy = true
    UI.quickMeleeToken = (UI.quickMeleeToken or 0) + 1
    local qtoken = UI.quickMeleeToken
    local gun = clientState.EquippedWeapon
    local qskin = MeleeData.SkinFor(clientState, clientState.EquippedKnife)
    realRig:SetWeapon(MeleeData.RigIdFor(clientState.EquippedKnife, clientState), nil, (qskin and qskin.Set) and qskin or nil)
    realRig:ApplyCosmetics({ Glove = ItemData.Gloves.Tactical, Sleeve = ItemData.ArmSkins.Standard, Skin = qskin })
    realRig.OnEvent = OnRigEvent
    pendingMeleeKind = "Quick"
    meleeCombo += 1
    local len = realRig:AnimLength("Light1")
    realRig:Play((meleeCombo % 2 == 0) and "Light2" or "Light1", 1.25)
    task.delay(len / 1.25 + 0.03, function()
        if UI.quickMeleeToken ~= qtoken then return end -- (already cancelled by the gun)
        quickMeleeBusy = false
        pendingMeleeKind = nil
        if activeSlot == "Gun" and gun and clientState.EquippedWeapon then RebuildViewmodelForWeapon(clientState.EquippedWeapon) end
    end)
    return true
end
UI.QuickMeleeSwing = QuickMeleeSwing
-- (the inverse: firing, reloading or swapping cuts a quick melee short and brings the gun straight back; a swing whose
-- hit already landed stays landed)
UI.CancelQuickMelee = function(): boolean
    if not quickMeleeBusy then return false end
    UI.quickMeleeToken = (UI.quickMeleeToken or 0) + 1
    quickMeleeBusy = false
    pendingMeleeKind = nil
    if activeSlot == "Gun" and clientState.EquippedWeapon then RebuildViewmodelForWeapon(clientState.EquippedWeapon) end
    return true
end
-- Studio-only test hook: Player attribute DevAct = "<action>:<anything>" (change the suffix to repeat) plays
-- inspect / melee / gun / light / heavy / quick, so play-test tooling can drive the viewmodel without keypresses
if RunService:IsStudio() then
    LocalPlayer:GetAttributeChangedSignal("DevAct"):Connect(function()
        local act, arg = string.match(tostring(LocalPlayer:GetAttribute("DevAct") or ""), "^(%a+):?([^:]*)")
        if act == "inspect" then if realRig then realRig:Play("Inspect") end
        elseif act == "lock" then if UI.Encounters and RunService:IsStudio() then UI.Encounters.DevAct(arg) end -- (UPDATE 7: "lock:start|hit|miss")
        elseif act == "archive" then if UI.OpenArchive then UI.OpenArchive() end -- (UPDATE 7: the Index's ARCHIVE tab)
        elseif act == "codex" then if UI.OpenGuideCodex then UI.OpenGuideCodex() end -- (UPDATE 8: the Index's HOW IT WORKS tab)
        elseif act == "boundpress" or act == "boundcancel" then -- (2026-10-20: the BOUND popup's BUY / CANCEL)
            local BS = require(sharedFolder:WaitForChild("BoundShop"))
            if act == "boundpress" then BS.DevPress() else BS.DevCancel() end
        elseif act == "boundtab" then if UI.BuyStashTab then UI.BuyStashTab(arg) end -- ("boundtab:Gem": a stash tab's BOUND popup)
        elseif act == "revive" then if UI.DoRevive then UI.DoRevive() end -- (the revive button)
        elseif act == "boundpremium" then -- (the season pass popup: BOUND + BUY WITH ROBUX, as the Season window opens it)
            local Seasons = require(sharedFolder:WaitForChild("Seasons"))
            require(sharedFolder:WaitForChild("BoundShop")).Confirm({ Name = "the premium season pass", Price = Seasons.Premium.Price,
                Desc = "+25% Season XP and the premium reward row (it pays back more BOUND points than it costs).",
                OnBuy = function() return Remotes.GetFunction("BoundBuy"):InvokeServer("SeasonPremium") end,
                Robux = { Price = Seasons.Premium.RobuxPrice or Seasons.Premium.Price, OnBuy = function() return Remotes.GetFunction("SeasonAction"):InvokeServer("BuyPremium") end } })
        elseif act == "settingsaction" then -- (UPDATE 7: "settingsaction:DropRules" = a Settings button row's window)
            local fn = require(sharedFolder:WaitForChild("SettingsMenu")).Actions[arg]
            if fn then fn() end
        elseif act == "stash" then -- (UPDATE 7: "stash:<tabId>" = the inventory on that stash tab, e.g. "stash:TRADE1" / "stash:SKINS")
            UI.stashTab = (arg ~= "" and arg) or "STASH"
            UI.stashBuyOpen = string.sub(arg, 1, 3) == "buy"
            if UI.stashBuyOpen then UI.stashTab = "STASH" end
            if UI.OpenMenuByName then UI.OpenMenuByName("Inventory") end
            local tabName = (arg == "ITEMS") and "Items" or "Stash" -- ("stash:ITEMS" = the ITEMS tab: materials, gems, Riftmods)
            if UI.ShowStashTab then UI.ShowStashTab("Weapons"); UI.ShowStashTab(tabName) end -- (twice: forces a refresh)
        elseif act == "pose" then -- (Update 5) "pose:<Anim>@<t>" freezes that animation at t (clip checks); "pose:none" stops
            local an, t = string.match(arg or "", "^(%w+)@([%d%.]+)$")
            if realRig then if an then realRig:PoseAt(an, tonumber(t) or 0) else realRig:Stop() end end
        elseif act == "rig" and realRig then -- (Update 5) "rig:<RigId>": show any gun / melee rig in hand (class test rigs)
            realRig:SetWeapon(arg, nil, nil)
        elseif act == "close" and UI.CloseAllMenus then UI.CloseAllMenus() -- (closes every window, e.g. the welcome guide of a fresh mock save)
        elseif act == "touchmenu" and UI.TouchMenuOpen then UI.TouchMenuOpen() -- (2026-10-13: the touch MENU card)
        elseif act == "open" and UI.OpenMenuByName then UI.OpenMenuByName(arg) -- (UI v4 2026-10-21: "open:<menu name>" as OpenMenu would)
        elseif act == "ui" and type(UI[arg]) == "function" then UI[arg]() -- (UI v4 2026-10-21: "ui:<UI function>", e.g. ui:OpenLostGear / ui:OpenClassPicker)
        elseif act == "profile" and UI.OpenProfile then UI.OpenProfile(nil, arg ~= "" and arg or "Aim") -- (2026-10-20: "profile:Aim|Overview")
        elseif act == "treehover" and UI.DevHoverNode then UI.DevHoverNode(arg ~= "" and arg or nil) -- (2026-10-20: a tree node's tooltip)
        elseif act == "treeclick" and UI.DevClickNode then -- (2026-10-22) "treeclick:<nodeId>[:right]" = a click on a tree node
            local nid, r = string.match(tostring(LocalPlayer:GetAttribute("DevAct") or ""), "^treeclick:([^:]+):?(%a*)$") -- (the full value: arg stops at the 2nd colon, so ":right" was lost)
            if nid then UI.DevClickNode(nid, r == "right") end
        elseif act == "exppick" and UI.ExpertiseChoose then UI.ExpertiseChoose(arg) -- (2026-10-22) the Expertise panel's button for effect <id>
        elseif act == "expback" and UI.ExpertiseTakeBack then UI.ExpertiseTakeBack() -- (2026-10-22) the panel's TAKE BACK
        elseif act == "pf" and UI.OpenPartyFinder then -- (2026-10-20) "pf:<filter>:<0|1 only mine>[:<row to JOIN>]"
            local p = string.split(tostring(LocalPlayer:GetAttribute("DevAct")), ":")
            UI.OpenPartyFinder()
            if UI.PartyFinderApi then UI.PartyFinderApi.Dev(p[2], p[3], p[4]) end
        elseif act == "ability" and UI.duel and UI.duel.UseAbility then UI.duel.UseAbility() -- (2026-10-15: the duel ability key)
        elseif act == "duelwin" and UI.duel then UI.duel.Open() -- (2026-10-15: the DUEL window, as its dock tile opens it)
        elseif act == "melee" then SetSlot("Melee")
        elseif act == "gun" then SetSlot("Gun")
        elseif act == "reload" then -- (0.97: the gun-check probe; "reload:part" = half a mag left, else empty)
            clientState.CurrentMag = (arg == "part") and math.floor((clientState.MaxMag or 10) / 2) or 0
            StartReload()
        elseif act == "light" then MeleeAttack("Light")
        elseif act == "heavy" then MeleeAttack("Heavy")
        elseif act == "quick" then QuickMeleeSwing()
        elseif act == "startrun" and UI.StartSolo then -- (2026-10-22 autoplay) "startrun:<difficulty>[:<bot skill>]" = the Dungeons window's START
            if UI.CloseAllMenus then UI.CloseAllMenus() end
            UI.StartSolo("Fire", (arg ~= "" and arg) or "Easy", tonumber(string.match(tostring(LocalPlayer:GetAttribute("DevAct")), "^%a+:%a+:(%d+)")))
        elseif act == "portal" and DungeonGeneratorShared.OnPortal then -- take the first path portal (prompts can't be pressed by tooling)
            DungeonGeneratorShared.OnPortal(1)
        elseif (act == "back" or act == "return") and DungeonGeneratorShared.OnRevisit then -- BACK PORTAL test hook
            DungeonGeneratorShared.OnRevisit(act == "back" and "Back" or "Return")
        elseif act == "shoot" and realRig and Camera then -- a visual burst only (viewmodel shot + tracer, no damage): skin FX tests
            task.spawn(function()
                for _ = 1, math.clamp(tonumber(arg) or 16, 1, 60) do -- ("shoot:N" = N shots, 0.09 s apart)
                    if not realRig then break end
                    realRig:Fire()
                    local cf = Camera.CFrame
                    local hit = workspace:Raycast(cf.Position, cf.LookVector * 200)
                    realRig:Tracer(hit and hit.Position or (cf.Position + cf.LookVector * 200), hit and hit.Normal)
                    task.wait(0.09)
                end
            end)
        elseif act == "killfx" and UI.SkinKill and Camera then -- the equipped skin's kill effect 14 studs ahead
            UI.SkinKill({ Kind = (activeSlot == "Melee") and "Melee" or "Hit", Position = Camera.CFrame.Position + Camera.CFrame.LookVector * 14 })
        elseif act == "tryon" and UI.TryOnStart then -- (Update 6) "tryon:<Cat>/<Id>" = TRY IN FIRST PERSON on that item; "tryon:off" ends it
            local TryOnM = require(game.ReplicatedStorage.AimRngShared:WaitForChild("TryOn"))
            if arg == "off" then TryOnM.Stop(true) else
                local cat, id = string.match(arg, "^(%w+)/(.+)$")
                local e = cat and require(game.ReplicatedStorage.AimRngShared:WaitForChild("Cosmetics")).Find(cat, id)
                if e then UI.TryOnStart(e, "FP") end
            end
        elseif act == "numbers" and Camera then -- (FX AUDIT 2026-10-14) "numbers:<n>" = a test burst of damage numbers 16 studs ahead, left of the crosshair
            task.spawn(function()
                local cf = Camera.CFrame
                local at = cf.Position + cf.LookVector * 16 - cf.RightVector * 4
                local key = "devnum" .. tostring(arg)
                for i = 1, 6 do HitNumbersM.Show(37 + i * 3, at, { Target = key, Crit = (i == 4) }); task.wait(0.09) end
                task.wait(0.15)
                HitNumbersM.Show(212, at + cf.RightVector * 2.5 + Vector3.new(0, 0.6, 0), { Weak = true, Target = key .. "w" })
                task.wait(0.2)
                HitNumbersM.Show(96, at + cf.RightVector * 8, { Crit = true, Target = key .. "c" })
                task.wait(0.2)
                HitNumbersM.Show(150, at + cf.RightVector * 5 - Vector3.new(0, 1.5, 0), { Killed = true, Target = key .. "k" })
            end)
        elseif act == "bars" then -- (FX roll-out 2026-10-14) "bars:<StyleId>" = the three bar sizes taking hits (BarStyles.DevPreview)
            require(game.ReplicatedStorage.AimRngShared:WaitForChild("BarStyles")).DevPreview(LocalPlayer.PlayerGui, arg)
        elseif act == "trykill" then -- (FX AUDIT 2026-10-14) "trykill:<i>" = kill try-range stand i through its real hit path
            require(game.ReplicatedStorage.AimRngShared:WaitForChild("TryOn")).DevKill(tonumber(arg))
        elseif act == "quality" then -- (bug sweep 2026-10-13) "quality:Low" / "quality:High" / "quality:Auto" = Settings > Video > Graphics Quality
            GameSettings.Set("GraphicsQuality", (arg == "Low" or arg == "Auto") and arg or "High")
        elseif act == "notes" and UI.welcome and UI.welcome.OpenNotes then -- the PATCH NOTES window
            UI.welcome.OpenNotes()
        end
    end)
end

local function FireWeapon()
    if LocalPlayer:GetAttribute("Downed") or LocalPlayer:GetAttribute("Spectating") then return end -- out of lives
    if UI.InSafeRoom() then return end -- no shooting out of the dungeon's safe zone
    if LocalPlayer:GetAttribute("ThirdPerson") then return end -- the hub hall is third person: no gun out
    if activeSlot == "Melee" then MeleeAttack("Light") return end
    if quickMeleeBusy and UI.CancelQuickMelee then UI.CancelQuickMelee() end
    if not canShoot or isAnyMenuOpen or isPerformingMelee or quickMeleeBusy then return end

    if UI.Zen and not UI.Zen.Pull(clientState) then -- (CHASE ITEMS: Furnace Heart locked out)
        UpdateAmmoHUD()
        -- a held trigger picks the chain back up when the lockout ends (it stopped here and needed a fresh click)
        local _, _, lockLeft = UI.Zen.Effective(clientState)
        if lockLeft and not UI.zenResume then
            UI.zenResume = true
            task.delay(lockLeft + 0.03, function()
                UI.zenResume = nil
                if isMouseDown and canShoot and not isAnyMenuOpen and not isCursorUnlocked then FireWeapon() end
            end)
        end
        return
    end
    if (clientState.CurrentMag or 1) <= 0 then
        if not (realRig and realRig:PlaySound("DryFire")) then SoundHelper.Play("Empty") end
        StartReload()
        return
    end

    if isReloading or clientState.IsReloading then return end
    if not clientState.EquippedWeapon then return end

    canShoot = false
    -- failsafe: if anything in this shot errors, the trigger must not stay locked forever
    local shotStarted = os.clock()
    UI.lastShotStarted = shotStarted
    task.delay(2, function()
        if not canShoot and UI.lastShotStarted == shotStarted then canShoot = true end
    end)
    if not UI.TrialActive and not (UI.PvpDef and UI.PvpDef()) then -- Aim Trials + duels: unlimited ammo
        clientState.CurrentMag = math.max(0, (clientState.CurrentMag or 1) - 1)
        if UI.Zen then UI.Zen.AfterPull(clientState) end -- (CHASE ITEMS: full heat -> the lockout)
    end
    UpdateAmmoHUD()

    local weapon = clientState.EquippedWeapon
    local stats = StatCalculator.Calculate(weapon, clientState.AllocatedNodes, clientState.Streak, clientState.Level, clientState.Attributes, clientState.EquippedGear, clientState.EquippedTitle, clientState.SocketedGems, clientState.RunBoons, clientState)
    -- AIM TRIALS: the universal trial weapon -- the scenario's fire rate, no recoil, one exact ray (AimTrials)
    UI.CBSlug = stats.Slug == true -- ((CLASS BUILDS) Slug Rounds, read by the orb hit number)
    local trialDef = (UI.TrialActive and UI.TrialRunner and UI.TrialRunner.Scenario and UI.TrialRunner.Scenario()) or (UI.PvpDef and UI.PvpDef()) or nil -- (0.59: duels use the same one-ray standard gun)

    if realRig then
        realRig:Fire((clientState.CurrentMag or 0) <= 0) -- its own sound, flash, slide, shell; locks back on the last round
    else
        SoundHelper.PlayWeaponFire(weapon.Class, weapon.BaseId)
    end

    -- Distinct gun-specific mechanical recoil & camera punch
    local pitch = (weapon.RecoilPitch or 1.0) * stats.RecoilMultiplier
    local yaw = (weapon.RecoilYaw or 0.3) * stats.RecoilMultiplier
    local kickZ = (weapon.RecoilKickZ or 0.35) * stats.RecoilMultiplier

    vmRecoilZ = trialDef and kickZ * 0.4 or kickZ
    vmRecoilY = trialDef and 0 or pitch * 0.08
    -- (no camera kick: owner 2026-10-05 "remove the camera recoil setting, just always have it set to zero")

    if weapon.BaseId == "Revolver" then
        vmRevolverCylRot += 60
    elseif weapon.BaseId == "Minigun" then
        vmMinigunRot += 45
    elseif weapon.BaseId == "DualDeagle" then
        dualShotToggle = not dualShotToggle
    end

    if muzzleFlashPart then
        local oldTrans = muzzleFlashPart.Transparency
        muzzleFlashPart.Transparency = 0
        task.delay(0.04, function() if muzzleFlashPart then muzzleFlashPart.Transparency = oldTrans end end)
    end

    -- Firing modes
    if trialDef then
        ExecuteRaycastShot()
    elseif weapon.Class == "Shotgun" and not stats.Slug then -- ((CLASS BUILDS) Slug Rounds: one slug = the single ray below)
        local pellets = weapon.PelletCount or 8
        local sw = 0.07 * ((UI.Zen and UI.Zen.SpreadMult(weapon)) or 1) -- (CHASE ITEMS: Bloomshot's pellets spread 40% wider)
        for p = 1, pellets do
            local spread = Vector3.new(
                (math.random() - 0.5) * sw,
                (math.random() - 0.5) * sw,
                (math.random() - 0.5) * sw
            )
            -- Only pellet #1 consumes the one round this trigger pull used; the rest of the spread
            -- still deals its own damage, it just doesn't drain extra ammo.
            ExecuteRaycastShot(spread, p == 1)
        end

    elseif weapon.Class == "Burst" then
        task.spawn(function()
            for b = 1, (weapon.BurstCount or 3) do
                -- Same rule as the shotgun: only the first round of the burst consumes ammo.
                ExecuteRaycastShot(nil, b == 1)
                task.wait(0.06)
            end
        end)

    else
        ExecuteRaycastShot()
    end

    local cd = 1 / math.max(0.5, trialDef and (trialDef.FireRate or 5) or stats.FireRate)
    SoundHelper.ChainRate = 1 / cd * math.max(1, stats.BurstCount or 1) -- (HIT CHAIN: how fast the hit sound climbs)
    task.delay(cd, function()
        canShoot = true
        if UI.Zen and UI.Zen.AutoReload(weapon) and (clientState.CurrentMag or 1) <= 0 and not isReloading then StartReload() return end -- (CHASE ITEMS: Long Promise's one round)
        if isMouseDown and not isAnyMenuOpen and not isCursorUnlocked then
            FireWeapon()
        end
    end)
end
UI.FireWeapon = FireWeapon -- (the reload's held-fire resume, declared above this)
-- Studio-only test hook: Player attribute DevFire = "<shots>:<anything>" pulls the trigger that many times (tooling
-- can't hold the mouse button in a playtest); "hold" / "release" = the fire button held down / let go (the real
-- fire-rate chain + the reload's held-fire resume: tools/autoplay.luau)
if RunService:IsStudio() then
    LocalPlayer:GetAttributeChangedSignal("DevFire"):Connect(function()
        if LocalPlayer:GetAttribute("DevFire") == "hold" then
            isMouseDown = true
            if not isAnyMenuOpen and not isCursorUnlocked then FireWeapon() end
            return
        elseif LocalPlayer:GetAttribute("DevFire") == "release" then
            isMouseDown = false
            return
        end
        local n = tonumber(string.match(tostring(LocalPlayer:GetAttribute("DevFire") or ""), "^(%d+)")) or 0
        for _ = 1, math.min(n, 200) do
            FireWeapon()
            task.wait(0.2)
        end
    end)
end

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard and GameSettings.IsTyping() then return end
    if SettingsMenu.IsCapturingKey() then return end
    if GameSettings.InputIs(input, "Fire") then -- (Settings > Controls: any key or mouse button)
        isMouseDown = true
        if not isAnyMenuOpen and not isCursorUnlocked and not LocalPlayer:GetAttribute("ThirdPerson") then
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
            UserInputService.MouseIconEnabled = false
            FireWeapon()
        end
    elseif GameSettings.InputIs(input, "Aim") then
        if activeSlot == "Melee" then
            if not isAnyMenuOpen and not isCursorUnlocked then MeleeAttack("Heavy") end
            return
        end
        if LocalPlayer:GetAttribute("ThirdPerson") then return end
        if GameSettings.Get("ADSMode") == "Toggle" then isAiming = not isAiming else isAiming = true end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if GameSettings.InputIs(input, "Fire") then
        isMouseDown = false
    elseif GameSettings.InputIs(input, "Aim") then
        if GameSettings.Get("ADSMode") ~= "Toggle" then isAiming = false end
    end
    -- FREE CURSOR is a HOLD: let go and the mouse locks again
    if UI.freeCursorHeld and GameSettings.InputIs(input, "FreeCursor") then
        UI.freeCursorHeld = false
        if not isAnyMenuOpen then SetMouseLocked(true) end
    end
end)
-- tabbing out: the key-up never arrives, so drop a held free cursor here (and stop firing / aiming)
UserInputService.WindowFocusReleased:Connect(function()
    isMouseDown = false
    if GameSettings.Get("ADSMode") ~= "Toggle" then isAiming = false end
    if UI.freeCursorHeld then
        UI.freeCursorHeld = false
        if not isAnyMenuOpen then SetMouseLocked(true) end
    end
end)

-- 6. Menus Management
UI.menuFolder = Instance.new("Folder")
UI.menuFolder.Name = "Menus"
UI.menuFolder.Parent = hudGui
require(sharedFolder:WaitForChild("UITheme")).SetMenuRoots({ UI.menuFolder }) -- (SKIN UI THEMES: menus follow a theme's clean palette)

local function CloseAllMenus()
    if UI.HideTooltip then UI.HideTooltip() end
    isAnyMenuOpen = false
    if UI.RefreshContracts then task.defer(UI.RefreshContracts) end -- (the contracts box comes back)
    SetMouseLocked(not (UI.victoryBanner and UI.victoryBanner.Visible)) -- (the run-complete popup keeps the cursor up)
    if UI.weaponCard then UI.weaponCard.Visible = true end
    for _, child in ipairs(UI.menuFolder:GetChildren()) do
        if child:IsA("Frame") then child.Visible = false end
    end
end
UI.CloseAllMenus = CloseAllMenus -- (Studio test hook DevAct "close": agents may not send real keys / clicks -- owner 2026-10-11)

local function OpenMenuFrame(frame: Frame)
    if UI.TryOnStopForMenu then UI.TryOnStopForMenu(frame) end -- (any other window ends a try-on first)
    local wasVisible = frame.Visible
    CloseAllMenus()
    if not wasVisible then
        frame.Visible = true
        isAnyMenuOpen = true
        do local lt = hudGui:FindFirstChild("LootToasts"); if lt then lt.Visible = false end end -- (PLAYTEST 2026-10-31: loot lines off the window)
        -- (2026-10-20, owner: "Talking to the NPCs breaks your camera"): windows whose X only hides them (QUARTERS, CREW,
        -- EXCHANGE ...) left isAnyMenuOpen on -> no hub camera orbit, cursor stuck free. Whatever hides the open window now
        -- runs the normal close.
        UI.openFrame = frame
        if not frame:GetAttribute("CloseWatch") then
            frame:SetAttribute("CloseWatch", true)
            frame:GetPropertyChangedSignal("Visible"):Connect(function()
                if frame.Visible or not isAnyMenuOpen or UI.openFrame ~= frame then return end
                task.defer(function()
                    if isAnyMenuOpen and UI.openFrame == frame and not frame.Visible then CloseAllMenus() end
                end)
            end)
        end
        if UI.RefreshContracts then UI.RefreshContracts() end -- (the contracts box steps aside)
        if UI.weaponCard then UI.weaponCard.Visible = false end -- the HUD gun card would sit on top of the window
        SetMouseLocked(false)
        if UI.PadMenus then UI.PadMenus.OnOpen(frame) end -- (QOL Q1: a pad gets a first selection)
    end
end

local RefreshInventory: () -> ()
local RefreshTree: () -> ()
local RefreshShopMenu: () -> ()
local RefreshUpgradeMenu: () -> ()
local RefreshArmoryMenu: () -> ()
local RenderIndexContent: () -> ()

-- Mirrors claimTitleFunc's server-side eligibility checks exactly (same thresholds, same stats --
-- clientState.StatsTracking/Level/etc. are the full server PlayerState replicated via SyncPlayerState)
-- so the Titles menu's claim button can be predicted here: grey while locked, yellow once truly earned,
-- instead of always looking the same regardless of progress.
local function CheckTitleRequirement(titleId: string): boolean
    return (ItemData.TitleProgress(titleId, clientState))
end

-- ==================== [ALL 9 MENUS SCOPED BUILDER] ====================
local function BuildAllMenus()
    -- ==================== [MENU 1: WEAPON FORGE] ====================
    UI.rollFrame = Instance.new("Frame")
    UI.rollFrame.Name = "RollMenu"
    UI.rollFrame.Size = UDim2.new(0, 520, 0, 420)
    UI.rollFrame.Position = UDim2.new(0.5, -260, 0.5, -210)
    UI.rollFrame.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
    UI.rollFrame.BorderSizePixel = 2
    UI.rollFrame.BorderColor3 = Color3.fromRGB(240, 160, 30)
    UI.rollFrame.Visible = false
    UI.rollFrame.Parent = UI.menuFolder
    ApplyPanelChrome(UI.rollFrame, Color3.fromRGB(240, 160, 30), 12)

    local rHeader = Instance.new("TextLabel")
    rHeader.Size = UDim2.new(1, 0, 0, 42); rHeader.BackgroundColor3 = Color3.fromRGB(26, 32, 44); rHeader.Font = Enum.Font.GothamBold; rHeader.TextSize = 20; rHeader.TextColor3 = Color3.fromRGB(255, 200, 50); rHeader.Text = "DAILY FREE ROLL  [ESC to Close]"; rHeader.Parent = UI.rollFrame
    UI.windowHeaders = UI.windowHeaders or {}; UI.windowHeaders[UI.rollFrame] = rHeader

    UI.rGoldBal = Instance.new("TextLabel")
    UI.rGoldBal.Size = UDim2.new(1, -20, 0, 24); UI.rGoldBal.Position = UDim2.new(0, 10, 0, 46); UI.rGoldBal.BackgroundTransparency = 1; UI.rGoldBal.Font = Enum.Font.GothamBold; UI.rGoldBal.TextSize = 17; UI.rGoldBal.TextColor3 = Color3.fromRGB(255, 215, 0); UI.rGoldBal.Text = "One free gun a day, rolled at your level."; UI.rGoldBal.Parent = UI.rollFrame

    local rCard = Instance.new("Frame")
    rCard.Size = UDim2.new(1, -40, 0, 220); rCard.Position = UDim2.new(0, 20, 0, 75); rCard.BackgroundColor3 = Color3.fromRGB(22, 28, 38); rCard.BorderSizePixel = 2; rCard.BorderColor3 = Color3.fromRGB(80, 95, 120); rCard.Parent = UI.rollFrame

    local rName = Instance.new("TextLabel")
    rName.Size = UDim2.new(1, -20, 0, 32); rName.Position = UDim2.new(0, 10, 0, 8); rName.BackgroundTransparency = 1; rName.Font = Enum.Font.GothamBold; rName.TextSize = 20; rName.TextColor3 = Color3.fromRGB(255, 255, 255); rName.Text = "WEAPON ANVIL READY"; rName.Parent = rCard

    local rStats = Instance.new("TextLabel")
    rStats.Size = UDim2.new(1, -20, 0, 130); rStats.Position = UDim2.new(0, 10, 0, 42); rStats.BackgroundTransparency = 1; rStats.Font = Enum.Font.GothamMedium; rStats.TextSize = 16; rStats.TextColor3 = Color3.fromRGB(200, 215, 235); rStats.TextYAlignment = Enum.TextYAlignment.Top; rStats.TextWrapped = true; rStats.Text = "Roll one free weapon every day, at your current level with normal drop odds.\nIf it beats your current gun, you can equip it right away."; rStats.Parent = rCard

    local rEquipOptionBtn = Instance.new("TextButton")
    rEquipOptionBtn.Size = UDim2.new(0, 200, 0, 32); rEquipOptionBtn.Position = UDim2.new(0.5, -100, 1, -38); rEquipOptionBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100); rEquipOptionBtn.BorderSizePixel = 0; rEquipOptionBtn.Font = Enum.Font.GothamBold; rEquipOptionBtn.TextSize = 17; rEquipOptionBtn.TextColor3 = Color3.fromRGB(255, 255, 255); rEquipOptionBtn.Text = "★ EQUIP THIS WEAPON"; rEquipOptionBtn.Visible = false; rEquipOptionBtn.Parent = rCard

    local lastRolledWeapon: ItemData.WeaponInstance? = nil

    rEquipOptionBtn.MouseButton1Click:Connect(function()
        if lastRolledWeapon then
            SoundHelper.Play("Equip")
            Remotes.GetFunction("EquipWeapon"):InvokeServer(lastRolledWeapon.Uid)
            clientState.EquippedWeapon = lastRolledWeapon
            RebuildViewmodelForWeapon(lastRolledWeapon)
            UpdateWeaponHUD()
            rEquipOptionBtn.Visible = false
            rStats.Text = rStats.Text .. "\n>> NOW EQUIPPED! <<"
            if RefreshInventory then RefreshInventory() end
        end
    end)

    local rBtn = Instance.new("TextButton")
    rBtn.Size = UDim2.new(0, 260, 0, 48); rBtn.Position = UDim2.new(0.5, -130, 1, -62); rBtn.BackgroundColor3 = Color3.fromRGB(230, 140, 20); rBtn.Font = Enum.Font.GothamBold; rBtn.TextSize = 22; rBtn.TextColor3 = Color3.fromRGB(255, 255, 255); rBtn.Text = "FREE DAILY ROLL"; rBtn.Parent = UI.rollFrame

    local isRolling = false
    rBtn.MouseButton1Click:Connect(function()
        if isRolling then return end
        local today = os.time() // 86400
        if (clientState.LastDailyRoll or 0) >= today then
            SoundHelper.Play("Click")
            local secs = (today + 1) * 86400 - os.time()
            rStats.Text = string.format("Today's free roll is used.\nNext one in %dh %02dm.", secs // 3600, (secs % 3600) // 60)
            return
        end

        isRolling = true
        rEquipOptionBtn.Visible = false
        SoundHelper.Play("Click")
        rName.Text = "FORGING WEAPON..."
        rStats.Text = "Cycling procedural rolls..."

        task.spawn(function()
            local ok, callErr = pcall(function()
                for i = 1, 6 do
                    local fakeRarities = ItemData.Rarities
                    local r = fakeRarities[math.random(1, #fakeRarities)]
                    rCard.BorderColor3 = ItemData.RarityColors[r]
                    rName.TextColor3 = ItemData.RarityColors[r]
                    task.wait(0.05)
                end

                local w, comparison, err, wasAutoSold, dailyPrism, prismJackpot = Remotes.GetFunction("RollWeaponRNG"):InvokeServer()
                if err and not wasAutoSold then
                    rStats.Text = tostring(err)
                elseif w then
                    SoundHelper.Play("Roll")
                    lastRolledWeapon = w
                    clientState.LastDailyRoll = os.time() // 86400

                    rCard.BorderColor3 = ItemData.RarityColors[w.Rarity]
                    rName.TextColor3 = ItemData.ItemColor(w)
                    rName.Text = ItemData.DisplayName(w) .. "   •   " .. ItemData.RarityLabel(w) .. " " .. ItemData.WeaponTypeLine(w)

                    local lines = {}
                    if type(dailyPrism) == "number" and dailyPrism > 0 then -- (fixes #9: the guaranteed Prism stack)
                        table.insert(lines, string.format("%s+%d PRISM SHARDS (daily stack)", prismJackpot and "TRIPLE STACK!  " or "", dailyPrism))
                    end
                    table.insert(lines, string.format("DPS: %s | DMG: %s | Rate: %.1f/s", ItemData.FormatNumber(ItemData.CalculateTrueDPS(w)), ItemData.FormatNumber(ItemData.GunDamage(w)), w.BaseFireRate))
                    if w.UniqueTrait then
                        table.insert(lines, "★ UNIQUE TRAIT: " .. w.UniqueTrait.Name .. " - " .. w.UniqueTrait.Description)
                    end
                    for _, list in ipairs({ w.Prefixes or {}, w.Suffixes or {} }) do
                        for _, a in ipairs(list) do table.insert(lines, "• " .. ItemData.FormatStat(a.Stat, a.Value)) end
                    end

                    if wasAutoSold then
                        table.insert(lines, "\nAUTO-SOLD! " .. tostring(err))
                        rEquipOptionBtn.Visible = false
                        ShowToast("Auto-sold: " .. w.Rarity .. " " .. w.Name)
                    elseif comparison and comparison.IsBetter then
                        table.insert(lines, "\n★ HIGHER TOTAL DPS THAN EQUIPPED:")
                        for _, reason in ipairs(comparison.Reasons) do table.insert(lines, reason) end
                        rEquipOptionBtn.Visible = true -- (its own EQUIP button; no upgrade popup on top: owner 2026-10-23 "slim line only")
                    else
                        table.insert(lines, "\nStored in Inventory. (Current equipped weapon has superior DPS)")
                        rEquipOptionBtn.Visible = false
                        ShowToast("Stored in your stash: " .. w.Rarity .. " " .. w.Name .. " (lower DPS)")
                    end

                    rStats.Text = table.concat(lines, "\n")
                    if RefreshInventory then RefreshInventory() end
                end
            end)
            if not ok then
                warn("[Roll Error]: " .. tostring(callErr))
                rStats.Text = "Roll failed: " .. tostring(callErr)
            end
            isRolling = false
        end)
    end)

    -- ==================== [MENU 2: PASSIVE TREE + GEM SOCKETS] ====================
    -- 249-node tree (SkillTreeData, generated by tools/gen_tree.py): six sectors, three branches each,
    -- a keystone at every branch end, 12 gem sockets (GemData). Left-click = allocate the shortest path,
    -- right-click an allocated node = refund it, click an allocated socket = pick a gem.
    do
    local GemData = require(sharedFolder:WaitForChild("GemData"))
    UI.treeFrame = Instance.new("Frame")
    UI.treeFrame.Name = "TreeMenu"
    UI.treeFrame.Size = UDim2.new(0.92, 0, 0.92, 0)
    UI.treeFrame.Position = UDim2.new(0.04, 0, 0.04, 0)
    UI.treeFrame.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
    UI.treeFrame.BorderSizePixel = 2
    UI.treeFrame.BorderColor3 = Color3.fromRGB(60, 75, 95)
    UI.treeFrame.Visible = false
    UI.treeFrame.Parent = UI.menuFolder
    ApplyPanelChrome(UI.treeFrame, Color3.fromRGB(60, 75, 95), 12)

    local tHeader = Instance.new("TextLabel")
    tHeader.Size = UDim2.new(1, 0, 0, 42); tHeader.BackgroundColor3 = Color3.fromRGB(18, 22, 30); tHeader.Font = Enum.Font.GothamBold; tHeader.TextSize = 18; tHeader.TextColor3 = Color3.fromRGB(80, 220, 140); tHeader.Text = "PASSIVE TREE"; tHeader.Parent = UI.treeFrame
    UI.windowHeaders = UI.windowHeaders or {}; UI.windowHeaders[UI.treeFrame] = tHeader

    local SIDE_W = 270
    local treeCanvas = Instance.new("Frame")
    treeCanvas.Name = "Canvas"; treeCanvas.Size = UDim2.new(1, -SIDE_W, 1, -85); treeCanvas.Position = UDim2.new(0, 0, 0, 42); treeCanvas.BackgroundColor3 = Color3.fromRGB(7, 9, 14); treeCanvas.BorderSizePixel = 0; treeCanvas.ClipsDescendants = true; treeCanvas.Parent = UI.treeFrame

    local treeWorld = Instance.new("Frame")
    treeWorld.Name = "WorldContainer"; treeWorld.Size = UDim2.new(0, 1, 0, 1); treeWorld.Position = UDim2.new(0.5, 0, 0.5, 0); treeWorld.BackgroundTransparency = 1; treeWorld.Parent = treeCanvas

    local ringsFolder = Instance.new("Folder"); ringsFolder.Name = "Rings"; ringsFolder.Parent = treeWorld
    local linesFolder = Instance.new("Folder"); linesFolder.Name = "Lines"; linesFolder.Parent = treeWorld
    local nodesFolder = Instance.new("Folder"); nodesFolder.Name = "Nodes"; nodesFolder.Parent = treeWorld
    local labelsFolder = Instance.new("Folder"); labelsFolder.Name = "Labels"; labelsFolder.Parent = treeWorld

    local tDesc = Instance.new("TextLabel")
    tDesc.Size = UDim2.new(1, -20, 0, 40); tDesc.Position = UDim2.new(0, 10, 1, -42); tDesc.BackgroundColor3 = UIStyle.Colors.BgBottom; tDesc.BorderSizePixel = 1; tDesc.BorderColor3 = UIStyle.Colors.Line; tDesc.Font = Enum.Font.GothamMedium; tDesc.TextSize = 14; tDesc.TextColor3 = UIStyle.Colors.Sub; tDesc.TextWrapped = true
    local HELP_TEXT = GameSettings.TouchOnly() and "Tap a node to see it, tap it again to add the path (pending until APPLY)  •  tap an allocated node twice to refund it  •  tap a ◈ Expertise in a cluster you hold to pick its effect  •  drag to pan, pinch to zoom"
        or "Click a node to add the path to it (pending until APPLY; UNDO / CLEAR / click it again to take it back)  •  Right-click an allocated node to refund it  •  Click a ◈ Expertise (cluster centre) to pick its effect  •  Drag to pan, scroll to zoom"
    tDesc.Text = HELP_TEXT
    -- (2026-10-22 TREE LOOK v2: a quiet hint line, not a boxed banner)
    tDesc.BackgroundTransparency = 1; tDesc.BorderSizePixel = 0; tDesc.TextSize = 12; tDesc.TextColor3 = UIStyle.Colors.Muted
    tDesc:SetAttribute("Skinned", true)
    tDesc.Parent = UI.treeFrame

    -- Side panel: everything your allocated nodes add up to, gems, respec.
    local side = Instance.new("Frame")
    side.Size = UDim2.new(0, SIDE_W - 10, 1, -95); side.Position = UDim2.new(1, -SIDE_W + 5, 0, 47)
    side.BackgroundColor3 = UIStyle.Colors.CardDark; side.BorderSizePixel = 0; side.Parent = UI.treeFrame -- (UI v4: a dark well)
    RoundCorners(side, 8)
    local sideTitle = Instance.new("TextLabel")
    sideTitle.Size = UDim2.new(1, -16, 0, 24); sideTitle.Position = UDim2.new(0, 8, 0, 4); sideTitle.BackgroundTransparency = 1
    sideTitle.Font = Enum.Font.GothamBlack; sideTitle.TextSize = 15; sideTitle.TextColor3 = UIStyle.Colors.Sub; sideTitle.TextXAlignment = Enum.TextXAlignment.Left -- (Update 5: section-header style)
    sideTitle.Text = "YOUR BUILD"; sideTitle.Parent = side
    local sideScroll = Instance.new("ScrollingFrame")
    sideScroll.Size = UDim2.new(1, -12, 1, -212); sideScroll.Position = UDim2.new(0, 6, 0, 30); sideScroll.BackgroundTransparency = 1; sideScroll.BorderSizePixel = 0
    sideScroll.ScrollBarThickness = 4; sideScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; sideScroll.CanvasSize = UDim2.new(0, 0, 0, 0); sideScroll.Parent = side
    local sideList = Instance.new("UIListLayout"); sideList.Padding = UDim.new(0, 2); sideList.SortOrder = Enum.SortOrder.LayoutOrder; sideList.Parent = sideScroll
    local gemsBtn = Instance.new("TextButton")
    gemsBtn.Size = UDim2.new(1, -16, 0, 34); gemsBtn.Position = UDim2.new(0, 8, 1, -84); gemsBtn.BackgroundColor3 = Color3.fromRGB(70, 50, 130)
    gemsBtn.Font = Enum.Font.GothamBold; gemsBtn.TextSize = 13; gemsBtn.TextColor3 = Color3.new(1, 1, 1); gemsBtn.Text = "GEM BAG"; gemsBtn.Parent = side
    RoundCorners(gemsBtn, 6)
    local respecBtn = Instance.new("TextButton")
    respecBtn.Size = UDim2.new(1, -16, 0, 34); respecBtn.Position = UDim2.new(0, 8, 1, -42); respecBtn.BackgroundColor3 = Color3.fromRGB(120, 45, 45)
    respecBtn.Font = Enum.Font.GothamBold; respecBtn.TextSize = 13; respecBtn.TextColor3 = Color3.new(1, 1, 1); respecBtn.Text = "RESPEC"; respecBtn.Parent = side
    RoundCorners(respecBtn, 6)
    -- CHANGE CLASS (owner: "change at the monolith"; costs a Rebirth Shard -- the class picker window explains)
    local classBtn = Instance.new("TextButton")
    classBtn.Name = "ChangeClassBtn"
    classBtn.Size = UDim2.new(1, -16, 0, 34); classBtn.Position = UDim2.new(0, 8, 1, -126); classBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 130)
    classBtn.Font = Enum.Font.GothamBold; classBtn.TextSize = 13; classBtn.TextColor3 = Color3.new(1, 1, 1); classBtn.Text = "CHANGE CLASS"; classBtn.Parent = side
    RoundCorners(classBtn, 6)
    classBtn.MouseButton1Click:Connect(function()
        SoundHelper.Play("Click")
        if UI.OpenClassPicker then UI.OpenClassPicker() end
    end)
    UI.treeClassBtn = classBtn
    -- (2026-10-22 TREE LOOK v2, owner: "it looks super lazy": four differently-filled slabs -> one calm style, each its own accent)
    local function TreeBtn(b: GuiButton, accent: Color3, primary: boolean?)
        if not primary then accent = UIStyle.Colors.Text end -- (UI CLEAN R-B: one quiet outline for every side button; the accent colours are gone)
        b.AutoButtonColor = false; b.BorderSizePixel = 0
        b.BackgroundColor3 = primary and accent or UIStyle.Colors.Bg1
        b.TextColor3 = primary and Color3.fromRGB(18, 16, 10) or accent
        local c = b:FindFirstChildOfClass("UICorner") or Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 3); c.Parent = b
        local st = b:FindFirstChild("TreeStroke") or Instance.new("UIStroke")
        st.Name = "TreeStroke"; st.Color = accent; st.Transparency = primary and 1 or 0.55; st.Thickness = 1
        st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = b
        b:SetAttribute("Skinned", true)
        if not b:GetAttribute("TreeHover") then
            b:SetAttribute("TreeHover", true)
            b.MouseEnter:Connect(function() local s2 = b:FindFirstChild("TreeStroke"); if s2 and s2.Transparency < 1 then s2.Transparency = 0.1 end end)
            b.MouseLeave:Connect(function() local s2 = b:FindFirstChild("TreeStroke"); if s2 and s2.Transparency < 1 then s2.Transparency = 0.55 end end)
        end
    end
    UI.TreeBtn = TreeBtn
    ;(function() -- (UI CLEAN R-B) the tree is a full-screen menu too: the field + the GEAR top bar (PASSIVES selected); the tree sits under it
        local tf = UI.treeFrame
        UIStyle.MenuField(tf, { Items = UIStyle.MENU_NAV.GEAR, Selected = "PASSIVES", OnClose = function() CloseAllMenus() end,
            Place = function(barBottom: number, phone: boolean)
                if phone then return end -- (phones: the tree stays the phone sheet)
                tf.Position = UDim2.new(0, 16, 0, barBottom + 6)
                tf.Size = UDim2.new(1, -32, 1, -(barBottom + 14))
                tf.BackgroundTransparency = 1
                tf.BorderSizePixel = 0
                tHeader.Visible = false
                side.BackgroundTransparency = 1
                local sc = side:FindFirstChildOfClass("UIStroke"); if sc then sc.Transparency = 0.9 end
            end })
        UIStyle.TextRole(sideTitle, "SectionHead")
    end)()
    TreeBtn(gemsBtn, Color3.fromRGB(190, 140, 255))
    TreeBtn(respecBtn, Color3.fromRGB(255, 120, 110))
    TreeBtn(classBtn, Color3.fromRGB(120, 200, 255))
    local respecArmed = false
    respecBtn.MouseButton1Click:Connect(function()
        if not respecArmed then
            respecArmed = true
            respecBtn.Text = UI.respecCost and ("CLICK AGAIN TO PAY " .. string.upper(UI.respecCost)) or "CLICK AGAIN TO CONFIRM" -- (refunds are expensive: say the price)
            task.delay(3, function() respecArmed = false; if RefreshTree then RefreshTree() end end)
            return
        end
        respecArmed = false
        local ok, msg = Remotes.GetFunction("RespecSkillTree"):InvokeServer()
        ShowToast(msg or (ok and "Tree reset." or "Can't respec."))
        if ok then SoundHelper.Play("Upgrade") end
    end)

    -- ===== TREE v4 renderer (2026-10-05): ~1,500 nodes, drawn cheaply.
    --   * the static look (every line + every SMALL node, unallocated) is 16 pre-rendered image TILES (SkillTreeTiles,
    --     made by tools/gen_tree_v4.py): laying out ~3,500 GUI objects cost ~10 ms a frame while zooming / panning
    --   * the ~300 big nodes are single images; small nodes get an overlay image only when they need one (allocated,
    --     adjacent, on the hovered path, a search hit) -- pooled
    --   * hover / click use a HIT TEST against node positions (a spatial grid) instead of 1,500 buttons
    --   * zoom = one UIScale on treeWorld, pan = treeWorld's position
    -- Lives in its own function scope (the main chunk is at Luau's 200-local limit).
    ;(function()
    local ClassData = require(sharedFolder:WaitForChild("ClassData"))
    local Tiles = require(sharedFolder:WaitForChild("SkillTreeTiles"))
    local S0 = 0.25 -- world units -> pixels at zoom 1
    local PX = { Minor = 10, Notable = 17, Keystone = 26, Socket = 15, ClassStart = 36, Expertise = 16 } -- (Expertise: a diamond, TREE LOOK v2)
    local IMG = { Disc = "rbxassetid://113529141356504", Ring = "rbxassetid://76845609957677",
        Sq = "rbxassetid://71584781396644", SqRing = "rbxassetid://74453838390213" }
    local SOCKET_COLOR = Color3.fromRGB(190, 140, 255)
    local CLASS_COLOR: { [string]: Color3 } = {}
    for _, c in ipairs(ClassData.List) do CLASS_COLOR[c.Id] = c.Color end
    local function NodeColor(node: any): Color3
        if node.Type == "Socket" then return SOCKET_COLOR end
        if node.Blend then -- (hybrid seams: halfway between their two classes' colours)
            local a, b = string.match(node.Blend, "^(%w+),(%w+)$")
            local ca, cb = a and CLASS_COLOR[a], b and CLASS_COLOR[b]
            if ca and cb then return ca:Lerp(cb, 0.5):Lerp(Color3.new(1, 1, 1), 0.15) end
        end
        return CLASS_COLOR[node.Class or node.Sector or ""] or Color3.fromRGB(200, 200, 220)
    end

    -- (NoSkin: UIStyle's auto-skin was adding a gradient + corner + stroke to every tile and node -- the stroke drew seams
    -- between tiles, and its text fitting turned long class names TextScaled)
    treeWorld:SetAttribute("NoSkin", true)
    local worldScale = Instance.new("UIScale")
    worldScale.Parent = treeWorld
    local function Layer(name: string, z: number): Frame
        local f = Instance.new("Frame")
        f.Name = name; f.BackgroundTransparency = 1; f.Size = UDim2.fromOffset(0, 0); f.ZIndex = z; f.Parent = treeWorld
        return f
    end
    local tileLayer, activeLayer, minorLayer, majorLayer = Layer("TileLayer", 1), Layer("ActiveLines", 2), Layer("MinorLayer", 3), Layer("MajorLayer", 4)
    local zoomScale = 1.0
    local minZoom, maxZoom = 0.18, 3.0
    local panOffset = Vector2.zero
    local isPanning = false
    local panStartPos = Vector2.zero
    local initialPanOffset = Vector2.zero
    local fittedOnce = false
    local classLabels: { TextLabel } = {}
    local NodeAt: (screen: Vector2) -> string?
    local HoverNode: (id: string?) -> ()
    local ClickNode: (id: string, right: boolean?) -> ()

    local function UpdateCanvasTransform()
        worldScale.Scale = zoomScale
        treeWorld.Position = UDim2.new(0.5, panOffset.X, 0.5, panOffset.Y)
        -- (class names stay readable: their text grows a little as you zoom out)
        local ts = math.clamp(math.round(16 / math.max(0.35, zoomScale)), 14, 46)
        for _, l in ipairs(classLabels) do l.TextSize = ts end
    end
    -- (the HUD has its own UIScale -- auto-fit on small screens -- so screen pixels != layout pixels: HudScale() is the
    -- ratio, measured from the canvas itself)
    local function HudScale(): number
        local t = tileLayer:FindFirstChildOfClass("ImageLabel")
        if t and t.Size.X.Offset > 0 then return t.AbsoluteSize.X / t.Size.X.Offset / zoomScale end
        return 1
    end
    -- zoom about a screen point (the cursor / pinch centre): the world point under it stays put
    local function ZoomAt(newZoom: number, screenPos: Vector2?)
        newZoom = math.clamp(newZoom, minZoom, maxZoom)
        local hud = HudScale()
        local ca = treeCanvas.AbsolutePosition + treeCanvas.AbsoluteSize / 2
        local sp = screenPos or ca
        local origin = treeWorld.AbsolutePosition
        local w = (sp - origin) / (hud * zoomScale)         -- layout px of world space under the point
        zoomScale = newZoom
        panOffset = (sp - w * hud * zoomScale - ca) / hud
        UpdateCanvasTransform()
    end
    local function CenterOn(worldPos: Vector2, zoom: number?)
        if zoom then zoomScale = math.clamp(zoom, minZoom, maxZoom) end
        panOffset = -worldPos * S0 * zoomScale
        UpdateCanvasTransform()
    end
    -- INPUT -> GUI AbsolutePosition space. InputObject positions are already in it (both measure from below the top bar,
    -- even in an IgnoreGuiInset ScreenGui); GetMouseLocation is from the window corner, so it loses the inset.
    -- (Studio MCP test note: user_mouse_input's x/y land 58 px LOWER than the same screenshot pixel -- aim at y - 58.)
    local function ToGui(p: Vector2): Vector2
        return p
    end
    local function MouseScreen(): Vector2
        return UserInputService:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()
    end
    local function OverCanvas(p: Vector2): boolean
        local a, s = treeCanvas.AbsolutePosition, treeCanvas.AbsoluteSize
        return p.X >= a.X and p.Y >= a.Y and p.X <= a.X + s.X and p.Y <= a.Y + s.Y
    end

    -- input: drag pans, a press that doesn't move = a click on the node under it; wheel / pinch zoom
    local panInput: InputObject? = nil
    local pressAt: Vector2? = nil
    treeCanvas.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or (input.UserInputType == Enum.UserInputType.Touch and not panInput) then
            isPanning = true; panStartPos = Vector2.new(input.Position.X, input.Position.Y); initialPanOffset = panOffset
            pressAt = ToGui(panStartPos)
            if input.UserInputType == Enum.UserInputType.Touch then panInput = input end
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            pressAt = ToGui(Vector2.new(input.Position.X, input.Position.Y))
        end
    end)
    local function Release(input: InputObject)
        local p = ToGui(Vector2.new(input.Position.X, input.Position.Y))
        local tapped = pressAt and (p - pressAt).Magnitude < 7
        pressAt = nil
        if not tapped then return end
        local id = NodeAt(p)
        if id then ClickNode(id, input.UserInputType == Enum.UserInputType.MouseButton2) end
    end
    treeCanvas.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input == panInput then
            isPanning = false; panInput = nil
            Release(input)
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            Release(input)
        end
    end)
    UserInputService.TouchEnded:Connect(function(input) if input == panInput then isPanning = false; panInput = nil end end)
    UI.treeFrame:GetPropertyChangedSignal("Visible"):Connect(function()
        if not UI.treeFrame.Visible then UI.treeTouchSel = nil; HoverNode(nil) end
    end)
    local pinchStart = nil
    UserInputService.TouchPinch:Connect(function(touches, scale, _, state)
        if not UI.treeFrame.Visible then return end
        if state == Enum.UserInputState.Begin or not pinchStart then pinchStart = zoomScale; isPanning = false; panInput = nil; pressAt = nil end
        local c = (#touches >= 2) and ToGui((touches[1] + touches[2]) / 2) or nil
        ZoomAt(pinchStart * scale, c)
        if state == Enum.UserInputState.End then pinchStart = nil end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not UI.treeFrame.Visible then return end
        if isPanning and (input.UserInputType == Enum.UserInputType.MouseMovement or input == panInput) then
            local delta = Vector2.new(input.Position.X, input.Position.Y) - panStartPos
            panOffset = initialPanOffset + delta / HudScale()
            UpdateCanvasTransform()
        elseif input.UserInputType == Enum.UserInputType.MouseWheel then
            local m = MouseScreen()
            if OverCanvas(m) then ZoomAt(zoomScale * ((input.Position.Z > 0) and 1.15 or 0.87), m) end
        end
    end)
    -- hover: from the canvas's own mouse events (its InputObject position, converted to GUI space)
    treeCanvas.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and not GameSettings.TouchOnly() and not isPanning then
            HoverNode(NodeAt(ToGui(Vector2.new(input.Position.X, input.Position.Y))))
        end
    end)
    treeCanvas.MouseLeave:Connect(function() if not GameSettings.TouchOnly() then HoverNode(nil) end end)
    UI.treeHoverClear = function() HoverNode(nil) end

    local function MakeTreeControlBtn(txt: string, posX: number, onClick: () -> ()): TextButton
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 32, 0, 32); b.Position = UDim2.new(1, posX - SIDE_W, 0, 50); b.BackgroundColor3 = Color3.fromRGB(30, 40, 55); b.BorderSizePixel = 1; b.BorderColor3 = Color3.fromRGB(80, 100, 130); b.Font = Enum.Font.GothamBold; b.TextSize = 20; b.TextColor3 = Color3.fromRGB(240, 240, 240); b.Text = txt; b.ZIndex = 3; b.Parent = UI.treeFrame
        b.MouseButton1Click:Connect(onClick)
        -- (TREE LOOK v2: quiet dark keys with a hairline)
        b.BackgroundColor3 = UIStyle.Colors.Bg1; b.BorderSizePixel = 0; b.TextColor3 = UIStyle.Colors.Sub
        if #txt > 1 then b.TextSize = 11 end
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 3); c.Parent = b
        local st = Instance.new("UIStroke"); st.Color = UIStyle.Colors.Line; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = b
        b:SetAttribute("Skinned", true)
        return b
    end
    local function FitZoom()
        local sz = treeCanvas.AbsoluteSize
        local span = (Tiles.Half * 2) * S0
        if sz.X > 10 and sz.Y > 10 then zoomScale = math.clamp(math.min(sz.X / span, sz.Y / span) * 1.05, minZoom, maxZoom) end
        panOffset = Vector2.zero
    end
    local function MyStart(): string?
        return ClassData.StartOf(clientState.Class)
    end
    MakeTreeControlBtn("+", -160, function() ZoomAt(zoomScale * 1.25) end)
    MakeTreeControlBtn("-", -120, function() ZoomAt(zoomScale / 1.25) end)
    MakeTreeControlBtn("FIT", -80, function() FitZoom(); UpdateCanvasTransform() end)
    MakeTreeControlBtn("⌂", -40, function()
        local s = MyStart()
        CenterOn(s and SkillTreeData[s].Position or Vector2.zero, 1.0)
    end)

    -- SEARCH: highlights every node whose name or stats contain the text
    local search = Instance.new("TextBox")
    search.Size = UDim2.new(0, 220, 0, 28); search.Position = UDim2.new(0, 10, 0, 50)
    search.BackgroundColor3 = Color3.fromRGB(20, 25, 36); search.BorderSizePixel = 1; search.BorderColor3 = Color3.fromRGB(80, 100, 130)
    search.Font = Enum.Font.GothamMedium; search.TextSize = 13; search.TextColor3 = Color3.fromRGB(230, 235, 245)
    search.PlaceholderText = "Search the tree (e.g. crit, burn, pistol)"; search.PlaceholderColor3 = Color3.fromRGB(120, 130, 150)
    search.Text = ""; search.ClearTextOnFocus = false; search.ZIndex = 3; search.Parent = UI.treeFrame
    do -- (TREE LOOK v2: an inset field)
        search.BackgroundColor3 = UIStyle.Colors.Well; search.BorderSizePixel = 0
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 3); c.Parent = search
        local st = Instance.new("UIStroke"); st.Color = UIStyle.Colors.Line; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = search
        local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 8); pad.Parent = search
        search.TextXAlignment = Enum.TextXAlignment.Left
        search:SetAttribute("Skinned", true)
    end
    local searchCount = Instance.new("TextLabel")
    searchCount.Size = UDim2.new(0, 160, 0, 28); searchCount.Position = UDim2.new(0, 236, 0, 50); searchCount.BackgroundTransparency = 1
    searchCount.Font = Enum.Font.GothamBold; searchCount.TextSize = 12; searchCount.TextColor3 = Color3.fromRGB(255, 220, 120)
    searchCount.TextXAlignment = Enum.TextXAlignment.Left; searchCount.Text = ""; searchCount.ZIndex = 3; searchCount.Parent = UI.treeFrame

    -- (QOL M2 2026-10-28) PENDING nodes (AimRngShared/TreePending): the APPLY / UNDO / CLEAR bar under the tree, and closing the tree
    -- with pending nodes brings it back with an APPLY / DISCARD / KEEP EDITING prompt (unless another window took over: they wait)
    ;(function()
        local TP = require(sharedFolder:WaitForChild("TreePending"))
        -- (the buttons' actions as UI functions: Studio tests press them with DevAct "ui:TreePendUndo" etc.)
        UI.TreePendUndo = function() TP.Undo() end
        UI.TreePendClear = function() TP.Clear() end
        UI.treePendBar = TP.Bar(UI.treeFrame, TreeBtn, function() if UI.TreeApplyPending then UI.TreeApplyPending() end end,
            function() UI.TreePendUndo() end, function() UI.TreePendClear() end)
        UI.treePendBar.Frame.Position = UDim2.new(0.5, -SIDE_W / 2, 1, -48)
        local closing = false
        local function CloseNow() closing = true; CloseAllMenus(); closing = false end
        UI.TreePendPromptApply = function() if UI.TreeApplyPending and UI.TreeApplyPending() then UI.treePendPrompt.Hide(); CloseNow() end end
        UI.TreePendPromptDiscard = function() TP.Clear(); UI.treePendPrompt.Hide(); CloseNow() end
        UI.treePendPrompt = TP.Prompt(UI.treeFrame, TreeBtn, function() UI.TreePendPromptApply() end, function() UI.TreePendPromptDiscard() end,
            function() UI.treePendPrompt.Hide() end)
        TP.OnChange = function()
            if TP.Count() == 0 then UI.treePendPrompt.Hide() end -- (nothing left to ask about)
            if UI.treeFrame.Visible and RefreshTree then RefreshTree() end
        end
        UI.treeFrame:GetPropertyChangedSignal("Visible"):Connect(function()
            if UI.treeFrame.Visible then return end
            UI.treePendPrompt.Hide()
            if closing or TP.Count() == 0 then return end
            task.defer(function()
                if UI.treeFrame.Visible or TP.Count() == 0 then return end
                if UI.openFrame and UI.openFrame ~= UI.treeFrame and UI.openFrame.Visible then return end -- (another window: they wait)
                OpenMenuFrame(UI.treeFrame)
                RefreshTree()
                UI.treePendPrompt.Show(TP.Count())
            end)
        end)
    end)()

    -- Shortest path of unallocated nodes from the allocated tree to `targetId` (inclusive), or nil.
    -- Nodes inside a Thread of Fate gem's radius are allocatable on their own (leapSet).
    local function PathTo(targetId: string, allocatedSet: { [string]: boolean }, leapSet: { [string]: boolean }): { string }?
        if allocatedSet[targetId] then return nil end
        local prev: { [string]: string } = {}
        local queue, head = { targetId }, 1
        local seen = { [targetId] = true }
        while head <= #queue do
            local cur = queue[head]
            head += 1
            local node = SkillTreeData[cur]
            local anchored = leapSet[cur] == true
            if not anchored then
                for _, nb in ipairs(node and node.Connections or {}) do
                    if allocatedSet[nb] then anchored = true; break end
                end
            end
            if anchored then
                local path = { cur }
                local c = cur
                while c ~= targetId do
                    c = prev[c]
                    table.insert(path, c)
                end
                return path -- ordered from the allocated edge outward to the target
            end
            for _, nb in ipairs(node and node.Connections or {}) do
                if not seen[nb] and SkillTreeData[nb] and not allocatedSet[nb] then
                    seen[nb] = true
                    prev[nb] = cur
                    table.insert(queue, nb)
                end
            end
        end
        return nil
    end

    -- (2026-10-20, owner: "Within the skill tree, it should show the stat increase relative to your level, not the uncapped"):
    -- every tree number is shown as what it really adds at YOUR level (StatCalculator.TreeEffective: the tree layer's soft
    -- ceiling, on top of what you already have), the raw number in brackets when the cap trims it. (Own function scope:
    -- this block is at the local limit.)
    ;(function()
        local cache, cacheAt = nil, -1
        local function Compiled()
            if cache and os.clock() - cacheAt < 0.5 then return cache end
            local ok, cs = pcall(StatCalculator.Calculate, clientState.EquippedWeapon, clientState.AllocatedNodes or {}, 0, clientState.Level, clientState.Attributes,
                clientState.EquippedGear, clientState.EquippedTitle, clientState.SocketedGems, clientState.RunBoons, clientState)
            cache, cacheAt = ok and cs or nil, os.clock()
            return cache
        end
        local function Group() return clientState.EquippedWeapon and ItemData.WeaponGroupOf(clientState.EquippedWeapon) or nil end
        local function Raw(k, v) return string.match(ItemData.FormatStat(k, v), "^[%+%-]?[%d%.,]+%%?") or tostring(v) end
        -- (owner 2026-10-22: "having it say damage vs uncapped etc is incredibly confusing": ONE number, what it gives at your
        -- level; the raw / uncapped bracket is gone. Gun-type stats still say they need that gun.)
        local function Line(k, v, eff, why)
            local full = ItemData.FormatStat(k, v)
            local tail = (why == "offgun") and "  (only with that gun type)" or ""
            if math.abs(eff - v) <= math.max(0.0005, math.abs(v) * 0.03) then return full .. tail end
            local raw = Raw(k, v)
            local main = ItemData.FormatStat(k, eff)
            if tonumber(string.match(main, "[%d%.]+") or "") == 0 then -- (rounds to nothing: two decimals instead of "+0%")
                local pct = string.sub(raw, -1) == "%"
                main = string.format(pct and "+%.2f%%" or "+%.2f", pct and eff * 100 or eff) .. string.sub(full, #raw + 1)
            end
            return main .. tail
        end
        local function Keys(stats)
            local keys = {}
            for k, v in pairs(stats or {}) do if type(v) == "number" then table.insert(keys, k) end end
            table.sort(keys)
            return keys
        end
        -- stats { [stat] = value } -> lines; removing = already in your build (an allocated node: what it gives now)
        UI.TreeStatLines = function(stats, removing)
            local cs, grp, out = Compiled(), Group(), {}
            for _, k in ipairs(Keys(stats)) do
                local gain, gk, dup = StatCalculator.CeilGain(k, stats[k], cs and cs.Ceilings, clientState.Level, removing, cs and cs.CeilNotables)
                if gain then -- (CEILING NOTABLES: the raise itself + what it frees up for your build now)
                    local what = ({ Damage = "Weapon Damage", MaxHP = "Max Health", CritChance = "Crit Chance", CritMulti = "Crit Damage",
                        WeakSpot = "Weak-Spot Damage", Armor = "Armor", Burn = "Burn Damage", Freeze = "Freeze Effect", Bleed = "Bleed Damage",
                        Decay = "Decay Effect", Explosion = "Explosion Damage" })[gk or ""] or tostring(gk)
                    local now = dup and (removing and "  (another one of these already counts: the same ceiling doesn't stack)"
                        or "  (you already have one: the same ceiling doesn't stack)")
                        or (gain > 0.0005) and string.format("  (%s +%.1f%% %s for your build now)", removing and "gives" or "would give", gain * 100, what)
                        or "  (your build doesn't stack this yet)"
                    table.insert(out, ItemData.FormatStat(k, stats[k]) .. now)
                else
                    local eff, why = StatCalculator.TreeEffective(k, stats[k], cs and cs.Ceilings, clientState.Level, grp, removing)
                    table.insert(out, Line(k, stats[k], eff, why))
                end
            end
            return out
        end
        -- the side panel's totals: each stat's share of the tree layer that counts at your level
        UI.TreeTotalLine = function(k, v)
            local cs = Compiled()
            local share, why = StatCalculator.TreeShare(k, cs and cs.Ceilings, Group())
            if why == "offgun" then return Line(k, v, StatCalculator.TreeEffective(k, v, cs and cs.Ceilings, clientState.Level, Group(), false)) end
            return Line(k, v, v * share, why)
        end
        UI.TreeStatsDirty = function() cache = nil end
    end)()
    local function NodeStatLines(node: any, allocated: boolean?): { string }
        return UI.TreeStatLines(node.Stats, allocated)
    end

    -- (2026-10-14 GemData.Contribution) the set of allocated nodes, read fresh (the tree's own allocatedSet is declared later)
    local function GemAllocSet(): { [string]: boolean }
        local set = {}
        for _, nid in ipairs(clientState.AllocatedNodes or {}) do set[nid] = true end
        return set
    end
    -- the "RIGHT NOW" block for a gem in `socketId` (RichText-free strings)
    local function GemNowLines(g: any, socketId: string?): { string }
        if not socketId then return {} end
        local set = GemAllocSet()
        if not set[socketId] then return { "Allocate this socket for the gem to work." } end
        local c = GemData.Contribution(g, socketId, set)
        local out = { c.Header }
        for _, l in ipairs(c.Lines) do table.insert(out, "  " .. l) end
        return out
    end
    local function GemTooltipLines(g: any, socketId: string?): { any }
        local d = GemData.Describe(g)
        local col = ItemData.RarityColors[g.Rarity] or Color3.new(1, 1, 1)
        local lines = { { Text = d.Title, Bold = true, Size = 15, Color = col }, { Text = d.Subtitle, Size = 12, Color = Color3.fromRGB(150, 160, 180) }, { Sep = true } }
        for _, l in ipairs(d.Lines) do table.insert(lines, { Text = l, Color = Color3.fromRGB(150, 205, 255) }) end
        if d.Special then table.insert(lines, { Text = d.Special, Color = Color3.fromRGB(255, 210, 90) }) end
        local now = GemNowLines(g, socketId)
        if #now > 0 then
            table.insert(lines, { Sep = true })
            for i, l in ipairs(now) do table.insert(lines, { Text = l, Size = (i == 1) and 12 or nil, Color = (i == 1) and Color3.fromRGB(150, 160, 180) or Color3.fromRGB(120, 230, 150) }) end
        end
        return lines
    end

    -- ----- Gem panel (socket picker / gem bag) -----
    local gemPanel = Instance.new("Frame")
    gemPanel.Name = "GemPanel"; gemPanel.Size = UDim2.new(0, 330, 1, -110); gemPanel.Position = UDim2.new(1, -SIDE_W - 340, 0, 90)
    gemPanel.BackgroundColor3 = Color3.fromRGB(16, 14, 26); gemPanel.BorderSizePixel = 0; gemPanel.Visible = false; gemPanel.ZIndex = 20; gemPanel.Parent = UI.treeFrame
    RoundCorners(gemPanel, 8)
    do
        local st = Instance.new("UIStroke"); st.Color = SOCKET_COLOR; st.Thickness = 2; st.Parent = gemPanel
    end
    local gemTitle = Instance.new("TextLabel")
    gemTitle.Size = UDim2.new(1, -50, 0, 30); gemTitle.Position = UDim2.new(0, 10, 0, 6); gemTitle.BackgroundTransparency = 1
    gemTitle.Font = Enum.Font.GothamBlack; gemTitle.TextSize = 14; gemTitle.TextColor3 = SOCKET_COLOR; gemTitle.TextXAlignment = Enum.TextXAlignment.Left; gemTitle.ZIndex = 21; gemTitle.Parent = gemPanel
    local gemClose = Instance.new("TextButton")
    gemClose.Size = UDim2.new(0, 30, 0, 30); gemClose.Position = UDim2.new(1, -38, 0, 6); gemClose.BackgroundColor3 = Color3.fromRGB(90, 40, 50)
    gemClose.Text = "X"; gemClose.Font = Enum.Font.GothamBold; gemClose.TextSize = 14; gemClose.TextColor3 = Color3.new(1, 1, 1); gemClose.ZIndex = 21; gemClose.Parent = gemPanel
    RoundCorners(gemClose, 6)
    local gemSub = Instance.new("TextLabel")
    gemSub.Size = UDim2.new(1, -20, 0, 34); gemSub.Position = UDim2.new(0, 10, 0, 36); gemSub.BackgroundTransparency = 1; gemSub.TextWrapped = true
    gemSub.Font = Enum.Font.GothamMedium; gemSub.TextSize = 11; gemSub.TextColor3 = Color3.fromRGB(170, 170, 200); gemSub.TextXAlignment = Enum.TextXAlignment.Left; gemSub.TextYAlignment = Enum.TextYAlignment.Top; gemSub.ZIndex = 21; gemSub.Parent = gemPanel
    local gemScroll = Instance.new("ScrollingFrame")
    gemScroll.Size = UDim2.new(1, -16, 1, -84); gemScroll.Position = UDim2.new(0, 8, 0, 76); gemScroll.BackgroundTransparency = 1; gemScroll.BorderSizePixel = 0
    gemScroll.ScrollBarThickness = 5; gemScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; gemScroll.CanvasSize = UDim2.new(0, 0, 0, 0); gemScroll.ZIndex = 21; gemScroll.Parent = gemPanel
    local gemList = Instance.new("UIListLayout"); gemList.Padding = UDim.new(0, 4); gemList.SortOrder = Enum.SortOrder.LayoutOrder; gemList.Parent = gemScroll
    local gemPanelSocket: string? = nil -- socket being edited, nil = browsing the bag
    local salvageArmed: string? = nil
    local RenderGemPanel: () -> ()

    local function GemRow(g: any, order: number, buttonText: string, buttonColor: Color3, onClick: () -> (), nowLines: { string }?)
        local col = ItemData.RarityColors[g.Rarity] or Color3.new(1, 1, 1)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, 0); row.AutomaticSize = Enum.AutomaticSize.Y; row.BackgroundColor3 = Color3.fromRGB(26, 24, 40); row.BorderSizePixel = 0; row.LayoutOrder = order; row.ZIndex = 22; row.Parent = gemScroll
        RoundCorners(row, 6)
        local stroke = Instance.new("UIStroke"); stroke.Color = col; stroke.Thickness = 1; stroke.Parent = row
        local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 5); pad.PaddingBottom = UDim.new(0, 5); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 86); pad.Parent = row
        local d = GemData.Describe(g)
        local text = Instance.new("TextLabel")
        text.Size = UDim2.new(1, 0, 0, 0); text.AutomaticSize = Enum.AutomaticSize.Y; text.BackgroundTransparency = 1; text.TextWrapped = true; text.RichText = true
        text.Font = Enum.Font.GothamMedium; text.TextSize = 11; text.TextXAlignment = Enum.TextXAlignment.Left; text.TextColor3 = Color3.fromRGB(190, 205, 230); text.ZIndex = 23
        local body = table.concat(d.Lines, "\n") .. (d.Special and ("\n" .. d.Special) or "")
        if nowLines and #nowLines > 0 then -- (2026-10-14: what it gives in this socket)
            body ..= '\n<font color="#78e696">' .. table.concat(nowLines, "\n") .. "</font>"
        end
        text.Text = string.format('<font color="#%s"><b>%s %s</b></font>  <font color="#8c8ca8">%s</font>\n%s', col:ToHex(), GemData.Icon(g), d.Title, g.Rarity, body)
        text.Parent = row
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 74, 0, 26); b.AnchorPoint = Vector2.new(1, 0.5); b.Position = UDim2.new(1, 80, 0.5, 0); b.BackgroundColor3 = buttonColor
        b.Font = Enum.Font.GothamBold; b.TextSize = 11; b.TextColor3 = Color3.new(1, 1, 1); b.Text = buttonText; b.ZIndex = 24; b.Parent = row
        RoundCorners(b, 5)
        b.MouseButton1Click:Connect(onClick)
        return row, b
    end

    RenderGemPanel = function()
        for _, c in ipairs(gemScroll:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local gems = clientState.Gems or {}
        local socketed = clientState.SocketedGems or {}
        local order = 0
        if gemPanelSocket then
            local inSocket = socketed[gemPanelSocket]
            gemTitle.Text = "GEM SOCKET"
            gemSub.Text = string.format("Pick a gem for this socket (hub only). Green = what it gives here with your nodes. Limit: %d build rule and %d transforms.", GemData.MAX_MYTHIC, GemData.MAX_LEGENDARY)
            if inSocket then
                order += 1
                GemRow(inSocket, order, "REMOVE", Color3.fromRGB(130, 60, 60), function()
                    local ok, msg = Remotes.GetFunction("UnsocketGem"):InvokeServer(gemPanelSocket)
                    ShowToast(msg or (ok and "Removed." or "Can't remove that."))
                end, GemNowLines(inSocket, gemPanelSocket))
            end
        else
            gemTitle.Text = string.format("GEM BAG  (%d / %d)", #gems, require(sharedFolder:WaitForChild("StashTabs")).GemCap(clientState))
            gemSub.Text = "Gems drop from elites, bosses, the loot goblin and chests. Socket them by clicking an allocated socket (purple diamond) on the tree. Salvage spares into materials."
        end
        local sorted = table.clone(gems)
        table.sort(sorted, function(a, b)
            local ra, rb = (ItemData.RarityRank[a.Rarity] or 0) + (tonumber(a.PowerMult) or 0) / 10, (ItemData.RarityRank[b.Rarity] or 0) + (tonumber(b.PowerMult) or 0) / 10 -- (UPDATE 8 GEM GRADES v4: rarity, then power)
            if ra ~= rb then return ra > rb end
            return (a.Name or "") < (b.Name or "")
        end)
        for _, g in ipairs(sorted) do
            order += 1
            if gemPanelSocket then
                GemRow(g, order, "SOCKET", Color3.fromRGB(80, 60, 150), function()
                    local ok, msg = Remotes.GetFunction("SocketGem"):InvokeServer(gemPanelSocket, g.Uid)
                    ShowToast(msg or (ok and "Socketed." or "Can't socket that."))
                    if ok then SoundHelper.Play("Upgrade") end
                end, GemNowLines(g, gemPanelSocket))
            else
                local armed = salvageArmed == g.Uid
                GemRow(g, order, armed and "CONFIRM?" or "SALVAGE", armed and Color3.fromRGB(170, 60, 40) or Color3.fromRGB(70, 70, 90), function()
                    if salvageArmed ~= g.Uid then
                        salvageArmed = g.Uid
                        RenderGemPanel()
                        return
                    end
                    salvageArmed = nil
                    local ok, msg = Remotes.GetFunction("SalvageGem"):InvokeServer(g.Uid)
                    ShowToast(msg or (ok and "Salvaged." or "Can't salvage that."))
                end)

            end
        end
        if #sorted == 0 then
            local l = Instance.new("TextLabel")
            l.Size = UDim2.new(1, -6, 0, 40); l.BackgroundTransparency = 1; l.TextWrapped = true; l.ZIndex = 22
            l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextColor3 = Color3.fromRGB(150, 150, 175)
            l.Text = "No gems in your bag yet."; l.LayoutOrder = order + 1; l.Parent = gemScroll
        end
    end
    local function OpenGemPanel(socketId: string?)
        gemPanelSocket = socketId
        salvageArmed = nil
        gemPanel.Visible = true
        RenderGemPanel()
    end
    gemClose.MouseButton1Click:Connect(function() gemPanel.Visible = false end)
    do -- (0.75, owner: "Gem bag needs an autosell option"): gems at or under the pick salvage into materials as they drop
        local gAuto = Instance.new("TextButton")
        gAuto.Name = "GemAutoSalvage"; gAuto.Size = UDim2.new(0, 150, 0, 24); gAuto.Position = UDim2.new(1, -196, 0, 9)
        gAuto.BackgroundColor3 = Color3.fromRGB(60, 50, 90); gAuto.Font = Enum.Font.GothamBold; gAuto.TextSize = 11
        gAuto.TextColor3 = Color3.new(1, 1, 1); gAuto.ZIndex = 21; gAuto.Parent = gemPanel
        RoundCorners(gAuto, 6)
        local function Lbl() gAuto.Text = "AUTO-SALVAGE: " .. string.upper(clientState.GemAutoSalvage or "OFF") .. " ▼" end
        Lbl()
        gemPanel:GetPropertyChangedSignal("Visible"):Connect(Lbl)
        gAuto.MouseButton1Click:Connect(function()
            SoundHelper.Play("Click")
            local list = { "OFF" }
            for _, r in ipairs({ "Common", "Uncommon", "Rare", "Mythic" }) do table.insert(list, r) end -- (UPDATE 8 GEM GRADES v4)
            if not UI.RarityPick then return end
            UI.RarityPick(gAuto, list, function(r)
                clientState.GemAutoSalvage = r
                Lbl()
                Remotes.GetFunction("SetGemAutoSalvage"):InvokeServer(r)
                ShowToast("Gem auto-salvage: " .. r .. (r ~= "OFF" and " and below" or ""))
            end, "gems")
        end)
    end
    gemsBtn.MouseButton1Click:Connect(function()
        if gemPanel.Visible and gemPanelSocket == nil then gemPanel.Visible = false else OpenGemPanel(nil) end
    end)

    -- ----- PASSIVES panel (0.49, owner: "add a menu in the tree to choose what passives you have equipped"): every ★
    -- passive skill you've allocated is UNLOCKED; up to ClassData.PassiveLimit(clientState.Level) of them are EQUIPPED (only equipped ones
    -- work). Server: SkillTreeServer "PassiveEquip".
    do
        local GOLDP = Color3.fromRGB(255, 210, 90)
        sideScroll.Size = UDim2.new(1, -12, 1, -202) -- (room for the PASSIVES button above CHANGE CLASS)
        local pBtn = Instance.new("TextButton")
        pBtn.Name = "PassivesBtn"
        pBtn.Size = UDim2.new(1, -16, 0, 34); pBtn.Position = UDim2.new(0, 8, 1, -168); pBtn.BackgroundColor3 = Color3.fromRGB(120, 92, 30)
        pBtn.Font = Enum.Font.GothamBold; pBtn.TextSize = 13; pBtn.TextColor3 = Color3.new(1, 1, 1); pBtn.Text = "★ PASSIVES"; pBtn.Parent = side
        RoundCorners(pBtn, 6)
        if UI.TreeBtn then UI.TreeBtn(pBtn, Color3.fromRGB(255, 205, 90)) end
        local panel = Instance.new("Frame")
        panel.Name = "PassivePanel"; panel.Size = UDim2.new(0, 360, 1, -110); panel.Position = UDim2.new(1, -SIDE_W - 370, 0, 90)
        panel.BackgroundColor3 = Color3.fromRGB(22, 18, 12); panel.BorderSizePixel = 0; panel.Visible = false; panel.ZIndex = 20; panel.Parent = UI.treeFrame
        RoundCorners(panel, 8)
        local stp = Instance.new("UIStroke"); stp.Color = GOLDP; stp.Thickness = 2; stp.Parent = panel
        -- (UI CLEAN R-A2 sweep: the passives + gem panels on the slate -- MenuKit.Sweep neutralises their gold edges / heads / hue buttons)
        panel.BackgroundColor3 = UIStyle.Colors.Bg0; gemPanel.BackgroundColor3 = UIStyle.Colors.Bg0
        for _, f in ipairs({ panel, gemPanel }) do for _, c in ipairs(f:GetChildren()) do if c:IsA("UICorner") then c:Destroy() end end end
        pcall(function() local mk = require(sharedFolder:WaitForChild("MenuKit")); mk.Sweep(panel); mk.Sweep(gemPanel) end)
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -50, 0, 30); title.Position = UDim2.new(0, 10, 0, 6); title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBlack; title.TextSize = 14; title.TextColor3 = GOLDP; title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 21; title.Parent = panel
        local close = Instance.new("TextButton")
        close.Size = UDim2.new(0, 30, 0, 30); close.Position = UDim2.new(1, -38, 0, 6); close.BackgroundColor3 = Color3.fromRGB(90, 40, 50)
        close.Text = "X"; close.Font = Enum.Font.GothamBold; close.TextSize = 14; close.TextColor3 = Color3.new(1, 1, 1); close.ZIndex = 21; close.Parent = panel
        RoundCorners(close, 6)
        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1, -20, 0, 34); sub.Position = UDim2.new(0, 10, 0, 36); sub.BackgroundTransparency = 1; sub.TextWrapped = true
        sub.Font = Enum.Font.GothamMedium; sub.TextSize = 11; sub.TextColor3 = Color3.fromRGB(200, 190, 160); sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.TextYAlignment = Enum.TextYAlignment.Top; sub.ZIndex = 21; sub.Parent = panel
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, -16, 1, -84); scroll.Position = UDim2.new(0, 8, 0, 76); scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 5; scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.CanvasSize = UDim2.new(0, 0, 0, 0); scroll.ZIndex = 21; scroll.Parent = panel
        local lay = Instance.new("UIListLayout"); lay.Padding = UDim.new(0, 5); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Parent = scroll
        local busy = false
        local function Equipped(): { string } return type(clientState.EquippedPassives) == "table" and clientState.EquippedPassives or {} end
        local function Render()
            for _, c in ipairs(scroll:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
            local eq = Equipped()
            local owned = {}
            for _, id in ipairs(clientState.AllocatedNodes or {}) do
                local n = SkillTreeData[id]
                if n and n.Type == "Keystone" then table.insert(owned, { Id = id, Node = n, On = table.find(eq, id) ~= nil }) end
            end
            table.sort(owned, function(a, b) if a.On ~= b.On then return a.On end return a.Node.Name < b.Node.Name end)
            title.Text = string.format("PASSIVE SKILLS  %d / %d EQUIPPED", #eq, ClassData.PassiveLimit(clientState.Level))
            sub.Text = (#owned == 0) and "Allocate a ★ node on the tree to unlock a passive skill. The ones far out on the edge of your class's area are the strongest twists."
                or string.format("Every ★ you allocate is unlocked. Equip up to %d; only equipped passives work (and only while you hold their weapon class).", ClassData.PassiveLimit(clientState.Level))
            for i, o in ipairs(owned) do
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, -6, 0, 0); row.AutomaticSize = Enum.AutomaticSize.Y; row.BackgroundColor3 = o.On and Color3.fromRGB(48, 40, 18) or Color3.fromRGB(30, 28, 26)
                row.BorderSizePixel = 0; row.LayoutOrder = i; row.ZIndex = 22; row.Parent = scroll
                RoundCorners(row, 6)
                local rs = Instance.new("UIStroke"); rs.Color = o.On and GOLDP or Color3.fromRGB(70, 64, 54); rs.Thickness = 1; rs.Parent = row
                local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 6); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 96); pad.Parent = row
                local grp = o.Node.Group and ItemData.WeaponGroups.Label[o.Node.Group]
                local txt = Instance.new("TextLabel")
                txt.Size = UDim2.new(1, 0, 0, 0); txt.AutomaticSize = Enum.AutomaticSize.Y; txt.BackgroundTransparency = 1; txt.TextWrapped = true; txt.RichText = true
                txt.Font = Enum.Font.GothamMedium; txt.TextSize = 11; txt.TextXAlignment = Enum.TextXAlignment.Left; txt.TextColor3 = Color3.fromRGB(205, 200, 185); txt.ZIndex = 23
                txt.Text = string.format('<font color="#%s"><b>★ %s</b></font>%s\n%s', (o.On and GOLDP or Color3.fromRGB(190, 180, 150)):ToHex(), o.Node.Name,
                    grp and ('  <font color="#8c8478">' .. grp .. '</font>') or "", o.Node.Description or "")
                txt.Parent = row
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(0, 84, 0, 28); b.AnchorPoint = Vector2.new(1, 0.5); b.Position = UDim2.new(1, 90, 0.5, 0)
                b.BackgroundColor3 = o.On and Color3.fromRGB(110, 50, 45) or Color3.fromRGB(60, 120, 60)
                b.Font = Enum.Font.GothamBold; b.TextSize = 12; b.TextColor3 = Color3.new(1, 1, 1); b.Text = o.On and "UNEQUIP" or "EQUIP"; b.ZIndex = 23; b.Parent = row
                RoundCorners(b, 6)
                b.MouseButton1Click:Connect(function()
                    if busy then return end
                    busy = true
                    SoundHelper.Play("Click")
                    local ok, msg = Remotes.GetFunction("PassiveEquip"):InvokeServer(o.Id, not o.On)
                    busy = false
                    if msg then ShowToast(msg) end
                    if ok then SoundHelper.Play("Upgrade") end
                end)
            end
        end
        UI.RefreshPassives = function()
            local n = #Equipped()
            local owned = 0
            for _, id in ipairs(clientState.AllocatedNodes or {}) do local nd = SkillTreeData[id]; if nd and nd.Type == "Keystone" then owned += 1 end end
            pBtn.Text = string.format("★ PASSIVES  %d / %d equipped  (%d unlocked)", n, ClassData.PassiveLimit(clientState.Level), owned)
            pBtn.Visible = clientState.Class ~= nil
            if panel.Visible then Render() end
        end
        UI.OpenPassives = function()
            gemPanel.Visible = false
            panel.Visible = true
            Render()
        end
        pBtn.MouseButton1Click:Connect(function()
            SoundHelper.Play("Click")
            if panel.Visible then panel.Visible = false else UI.OpenPassives() end
        end)
        close.MouseButton1Click:Connect(function() panel.Visible = false end)
        gemsBtn.MouseButton1Click:Connect(function() panel.Visible = false end)
        UI.treeFrame:GetPropertyChangedSignal("Visible"):Connect(function() if not UI.treeFrame.Visible then panel.Visible = false end end)
    end
    UI.treeFrame:GetPropertyChangedSignal("Visible"):Connect(function()
        if not UI.treeFrame.Visible then gemPanel.Visible = false; if UI.HideTooltip then UI.HideTooltip() end end
    end)

    -- gem radius rings (world units -- only a handful)
    local function MakeRing(center: Vector2, color: Color3, transparency: number, name: string)
        local ring = Instance.new("Frame")
        ring.Name = name
        local d = GemData.RADIUS * 2 * S0
        ring.Size = UDim2.fromOffset(d, d)
        ring.Position = UDim2.fromOffset(center.X * S0 - d / 2, center.Y * S0 - d / 2)
        ring.BackgroundColor3 = color; ring.BackgroundTransparency = transparency; ring.BorderSizePixel = 0
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = ring
        local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = 1.5; s.Transparency = 0.2; s.Parent = ring
        ring.Parent = ringsFolder
        return ring
    end
    local hoverRing = MakeRing(Vector2.zero, Color3.fromRGB(255, 255, 255), 0.95, "HoverRing")
    hoverRing.Visible = false
    local function MoveRing(ring: Frame, center: Vector2)
        local d = GemData.RADIUS * 2 * S0
        ring.Position = UDim2.fromOffset(center.X * S0 - d / 2, center.Y * S0 - d / 2)
    end

    local bigImg: { [string]: ImageLabel } = {}       -- big nodes (always drawn)
    local frames: { [string]: ImageLabel } = {}       -- (TREE LOOK v2) the outer frame ring of notables / keystones / class starts
    local overlay: { [string]: ImageLabel } = {}      -- small nodes' overlays (made on demand, reused)
    local lineList: { { Line: Frame?, Glow: Frame?, A: string, B: string } } = {}
    local glyphs: { [string]: TextLabel } = {}
    local searchHits: { [string]: boolean } = {}
    local allocatedSet: { [string]: boolean } = {}
    local leapSet: { [string]: boolean } = {}
    local socketed: { [string]: any } = {}
    local nodeState: { [string]: { Alloc: boolean, Adj: boolean } } = {}
    local pathSet: { [string]: boolean } = {}
    local allocating = false
    local hoverPath: { string }? = nil
    local hoveredId: string? = nil
    local built = false
    local GRID = 160
    local grid: { [string]: { string } } = {}
    local DIM = Color3.fromRGB(40, 45, 60)
    UI.TP = require(sharedFolder:WaitForChild("TreePending")) -- (QOL M2: pending nodes until APPLY; no new local -- this block is full)

    local function Place(gui: GuiObject, node: any, px: number)
        gui.Size = UDim2.fromOffset(px, px)
        gui.Position = UDim2.fromOffset(node.Position.X * S0 - px / 2, node.Position.Y * S0 - px / 2)
    end
    local function Overlay(id: string): ImageLabel
        local o = overlay[id]
        if not o then
            o = Instance.new("ImageLabel")
            o.Name = "O"; o.BackgroundTransparency = 1; o.ZIndex = 3
            Place(o, SkillTreeData[id], PX.Minor + 1)
            o.Parent = minorLayer
            overlay[id] = o
        end
        return o
    end

    -- the look of one node in its current state (highlight = on the hovered path)
    local function StyleNode(id: string)
        local node = SkillTreeData[id]
        if not node then return end
        local st = nodeState[id] or { Alloc = false, Adj = false }
        local hl = pathSet[id] == true
        local gem = node.Type == "Socket" and socketed[id] or nil
        local col = gem and (ItemData.RarityColors[gem.Rarity] or SOCKET_COLOR) or NodeColor(node)
        if node.Type == "Minor" then
            local img, c
            if hl then img, c = IMG.Disc, Color3.new(1, 1, 1)
            elseif UI.TP.Set[id] then img, c = IMG.Disc, UI.TP.COLOR -- (QOL M2: pending)
            elseif searchHits[id] then img, c = IMG.Disc, Color3.fromRGB(255, 220, 90)
            elseif st.Alloc then img, c = IMG.Disc, col
            elseif st.Adj then img, c = IMG.Ring, col end
            if img then
                local o = Overlay(id)
                o.Image, o.ImageColor3, o.Visible = img, c, true
            elseif overlay[id] then
                overlay[id].Visible = false
            end
            return
        end
        local b = bigImg[id]
        if not b then return end
        local square = node.Type == "Keystone" or node.Type == "Socket" or node.Type == "Expertise"
        local filled, c
        if node.Type == "ClassStart" then
            local mine = clientState.Class == node.Class
            filled, c = true, mine and col or col:Lerp(Color3.new(0, 0, 0), clientState.Class and 0.6 or 0.25)
        elseif hl then filled, c = true, Color3.new(1, 1, 1)
        elseif UI.TP.Set[id] then filled, c = true, UI.TP.COLOR -- (QOL M2: pending)
        elseif searchHits[id] then filled, c = true, Color3.fromRGB(255, 220, 90)
        elseif st.Alloc then filled, c = true, col
        elseif st.Adj then filled, c = false, col
        else filled, c = false, col:Lerp(DIM, 0.45) end
        b.Image = filled and (square and IMG.Sq or IMG.Disc) or (square and IMG.SqRing or IMG.Ring)
        b.ImageColor3 = c
        local fr = frames[id]
        if fr then
            fr.ImageColor3 = (filled or st.Adj) and c or col
            fr.ImageTransparency = (node.Type == "ClassStart") and (clientState.Class == node.Class and 0.15 or 0.65)
                or (filled and 0.15) or (st.Adj and 0.4) or 0.72
        end
        if node.Type == "Socket" then
            -- (0.71, owner: "Gems over legendary dont even appear to be equipped in the skill tree"): Astral read as the
            -- empty-socket purple and Transcendent / Empyrean / Infinite as the white hover highlight. A socketed gem now
            -- gets a ring around its socket, and Celestial+ gems their rarity colours (gradient) on both.
            local seq = gem and ItemData.RARITY_GRADIENT[gem.Rarity] or nil
            local grad = b:FindFirstChild("GemGrad")
            if seq and filled and not hl then
                if not grad then grad = Instance.new("UIGradient"); grad.Name = "GemGrad"; grad.Parent = b end
                grad.Color = seq
                b.ImageColor3 = Color3.new(1, 1, 1)
            elseif grad then grad:Destroy() end
            local halo = b:FindFirstChild("GemHalo")
            if gem then
                if not halo then
                    halo = Instance.new("ImageLabel")
                    halo.Name = "GemHalo"; halo.BackgroundTransparency = 1; halo.Image = IMG.SqRing
                    halo.Size = UDim2.fromScale(1.8, 1.8); halo.Position = UDim2.fromScale(-0.4, -0.4); halo.ZIndex = 4
                    halo.Parent = b
                end
                local hg = halo:FindFirstChild("G")
                if seq then
                    if not hg then hg = Instance.new("UIGradient"); hg.Name = "G"; hg.Parent = halo end
                    hg.Color = seq
                    halo.ImageColor3 = Color3.new(1, 1, 1)
                else
                    if hg then hg:Destroy() end
                    halo.ImageColor3 = ItemData.RarityColors[gem.Rarity] or SOCKET_COLOR
                end
            elseif halo then halo:Destroy() end
        end
        local g = glyphs[id]
        if g then
            if node.Type == "Socket" then g.Text = gem and GemData.Icon(gem) or "" end
            if g:IsA("ImageLabel") then g.ImageColor3 = filled and Color3.fromRGB(15, 15, 20) or c
            else g.TextColor3 = filled and Color3.fromRGB(15, 15, 20) or c end
        end
    end
    local function SetPathHighlight(path: { string }?, on: boolean)
        if not path then return end
        for _, pid in ipairs(path) do
            pathSet[pid] = on or nil
            StyleNode(pid)
        end
    end

    local function Build()
        built = true
        -- the static tiles
        local tileSize = Tiles.Half * 2 / Tiles.N * S0
        for _, t in ipairs(Tiles.Tiles) do
            local im = Instance.new("ImageLabel")
            im.Name = "T"; im.BorderSizePixel = 0; im.BackgroundColor3 = Color3.fromRGB(7, 9, 14)
            im.Image = t.Id; im.ScaleType = Enum.ScaleType.Stretch
            -- (sample 1 px in from the edges: the outermost texels bled a light seam between tiles)
            im.ImageRectOffset = Vector2.new(1, 1); im.ImageRectSize = Vector2.new(1022, 1022)
            im.Size = UDim2.fromOffset(math.ceil(tileSize) + 1, math.ceil(tileSize) + 1)
            im.Position = UDim2.fromOffset(-Tiles.Half * S0 + t.X * tileSize, -Tiles.Half * S0 + t.Y * tileSize)
            im.Parent = tileLayer
        end
        -- edges (for the coloured active overlays) + the hit-test grid
        for id, node in pairs(SkillTreeData) do
            for _, connId in ipairs(node.Connections) do
                if SkillTreeData[connId] and id < connId then table.insert(lineList, { A = id, B = connId }) end
            end
            local key = math.floor(node.Position.X / GRID) .. "," .. math.floor(node.Position.Y / GRID)
            grid[key] = grid[key] or {}
            table.insert(grid[key], id)
            if node.Type ~= "Minor" then
                local im = Instance.new("ImageLabel")
                im.Name = "B"; im.BackgroundTransparency = 1; im.ZIndex = 4
                Place(im, node, PX[node.Type] or 16)
                if node.Type == "Socket" or node.Type == "Expertise" then im.Rotation = 45 end
                im.Parent = majorLayer
                bigImg[id] = im
                -- (2026-10-22 TREE LOOK v2: notables, keystones and class starts sit in a thin outer frame of their colour --
                -- brighter once allocated -- so the important nodes read at a glance instead of being slightly bigger rings)
                if node.Type == "Notable" or node.Type == "Keystone" or node.Type == "ClassStart" then
                    local fr = Instance.new("ImageLabel")
                    fr.Name = "F"; fr.BackgroundTransparency = 1; fr.ZIndex = 3
                    fr.Image = (node.Type == "Keystone") and IMG.SqRing or IMG.Ring
                    Place(fr, node, math.round((PX[node.Type] or 16) * ((node.Type == "ClassStart") and 1.3 or 1.55)))
                    if node.Type == "Keystone" then fr.Rotation = 45 end
                    fr.Parent = majorLayer
                    frames[id] = fr
                end
                local cls = node.Type == "ClassStart" and ClassData.ById[node.Class or ""]
                if cls and UIStyle.HasIcon(cls.IconKey) then -- (0.61f: the class's custom icon, not a Roblox emoji)
                    glyphs[id] = UIStyle.Icon(cls.IconKey, { Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.19, 0.19), ZIndex = 5, Parent = im })
                elseif node.Type == "Socket" or node.Type == "Keystone" or node.Type == "Expertise" then
                    local g = Instance.new("TextLabel")
                    g.Size = UDim2.fromScale(0.7, 0.7); g.Position = UDim2.fromScale(0.15, 0.15); g.BackgroundTransparency = 1
                    g.Font = Enum.Font.GothamBlack; g.TextScaled = true; g.ZIndex = 5; g.Rotation = (node.Type == "Socket" or node.Type == "Expertise") and -45 or 0
                    if node.Type == "Expertise" then g.Size = UDim2.fromScale(0.5, 0.5); g.Position = UDim2.fromScale(0.25, 0.25) end
                    g.Text = (node.Type == "Keystone") and "★" or (node.Type == "Expertise") and "◆" or ""
                    g.Parent = im
                    glyphs[id] = g
                end
                if cls then
                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.fromOffset(240, 30); lbl.BackgroundTransparency = 1
                    lbl.Position = UDim2.fromOffset(node.Position.X * S0 - 120, node.Position.Y * S0 + PX.ClassStart / 2 + 2)
                    lbl.Font = Enum.Font.GothamBlack; lbl.TextSize = 16; lbl.TextStrokeTransparency = 0.4
                    lbl.TextColor3 = NodeColor(node); lbl.Text = string.upper(node.Name); lbl.ZIndex = 5
                    lbl:SetAttribute("NoRarityDrift", true) -- (Vanguard's orange = the Eclipse rarity colour: it drifted magenta)
                    lbl.Parent = labelsFolder
                    table.insert(classLabels, lbl)
                end
            end
        end
    end

    -- HIT TEST: the node under a screen point (nearest within its drawn radius + a little slack)
    NodeAt = function(screen: Vector2): string?
        if not built then return nil end
        -- (owner 2026-10-05: "Ascendency class tree overlaps when hovering with normal skill tree": the hit test is
        -- positional, so nodes UNDER the open ascendancy panel still lit up / took clicks -- the panel owns the screen)
        local ap = UI.treeFrame:FindFirstChild("AscPanel")
        if ap and ap.Visible then return nil end
        local k = HudScale() * zoomScale
        local w = (screen - treeWorld.AbsolutePosition) / k / S0
        local gx, gy = math.floor(w.X / GRID), math.floor(w.Y / GRID)
        local best, bestD = nil, math.huge
        for dx = -1, 1 do
            for dy = -1, 1 do
                for _, id in ipairs(grid[(gx + dx) .. "," .. (gy + dy)] or {}) do
                    local n = SkillTreeData[id]
                    local d = (n.Position - w).Magnitude
                    local r = ((PX[n.Type] or 10) / 2 + 5) / (zoomScale * S0)
                    r = math.max(r, 14) -- (zoomed far out: still catchable)
                    if d <= r and d < bestD then best, bestD = id, d end
                end
            end
        end
        return best
    end

    -- ===== EXPERTISE (2026-10-22; owner: "Lets work on the not done parts now"): the ◈ in a cluster's centre. 1 point once you
    -- hold a notable of its ring, then one effect of its family (each effect once per tree; SkillTreeServer ExpertiseAction).
    -- Tooltip, click and the pick panel live here (own scope: the tree block is near the local limit). Refund prices:
    -- UI.RefundCostText (Unwinds first, then gold: ItemData.RefundCost).
    ;(function()
        local ExpertiseData = require(sharedFolder:WaitForChild("ExpertiseData"))
        local EXP_COLOR = Color3.fromRGB(120, 235, 200)
        local function Picks() return type(clientState.Expertise) == "table" and clientState.Expertise or {} end
        local function Held(node)
            for _, nid in ipairs(node.Ring or {}) do if allocatedSet[nid] then return true end end
            return false
        end
        local function UsedAt(effId, except)
            for nid, e in pairs(Picks()) do if e == effId and nid ~= except then return nid end end
            return nil
        end
        UI.RefundCostText = function(n)
            local u, gold = ItemData.RefundCost(clientState, n or 1)
            if u == 0 and gold == 0 then return "free until level " .. ItemData.REFUND_FREE_LEVEL end
            local parts = {}
            if u > 0 then table.insert(parts, u .. " Unwind" .. (u == 1 and "" or "s")) end
            if gold > 0 then table.insert(parts, ItemData.FormatNumber(gold) .. " gold") end
            return table.concat(parts, " + ")
        end
        local function EffectLines(e, here)
            local out = {}
            for _, l in ipairs(UI.TreeStatLines(e.Stats or {}, here)) do table.insert(out, l) end
            if e.Desc then table.insert(out, e.Desc) end
            return out
        end
        UI.ExpertiseTooltip = function(id, col)
            local node = SkillTreeData[id]
            local fam = ExpertiseData.Families[node.Family]
            local mine = Picks()[id]
            local held = Held(node)
            local lines = {
                { Text = node.Name, Bold = true, Size = 15, Color = EXP_COLOR },
                { Text = "Expertise  •  " .. ((node.Sector == "Hybrid" and node.Blend) and string.gsub(node.Blend, ",", " / ") or tostring(node.Sector)), Size = 12, Color = Color3.fromRGB(150, 160, 180) },
                { Sep = true },
                { Text = "Costs 1 point once you hold a notable of this cluster. Pick ONE effect; each effect works once in your whole tree.", Size = 12, Color = Color3.fromRGB(190, 195, 210) },
            }
            for _, effId in ipairs(fam and fam.Effects or {}) do
                local e = ExpertiseData.Effects[effId]
                local used = UsedAt(effId, id)
                local tag = (mine == effId) and "  (PICKED HERE)" or used and "  (taken at another ◈)" or ""
                table.insert(lines, { Text = "◈ " .. e.Name .. tag, Bold = true, Size = 13, Color = (mine == effId) and EXP_COLOR or used and Color3.fromRGB(120, 120, 135) or Color3.fromRGB(230, 235, 245) })
                for _, l in ipairs(EffectLines(e, mine == effId)) do
                    table.insert(lines, { Text = "    " .. l, Size = 12, Color = used and Color3.fromRGB(110, 115, 130) or Color3.fromRGB(120, 200, 255) })
                end
            end
            table.insert(lines, { Sep = true })
            local tap = GameSettings.TouchOnly()
            if not clientState.Class then
                table.insert(lines, { Text = "Pick a class first", Size = 12, Color = Color3.fromRGB(240, 200, 110) })
            elseif mine then
                table.insert(lines, { Text = string.format("%s to change it (%s)  •  %s to take it back", tap and "Tap again" or "Click", UI.RefundCostText(1), tap and "use the panel" or "right-click"), Size = 12, Color = Color3.fromRGB(150, 150, 170) })
            elseif held then
                table.insert(lines, { Text = string.format("%s to pick an effect: 1 point%s", tap and "Tap again" or "Click", (clientState.SkillPoints or 0) < 1 and "  (no points left)" or ""), Size = 12, Color = (clientState.SkillPoints or 0) < 1 and Color3.fromRGB(240, 110, 110) or Color3.fromRGB(110, 230, 140) })
            else
                table.insert(lines, { Text = "Allocate a notable of this cluster to open it", Size = 12, Color = Color3.fromRGB(240, 200, 110) })
            end
            if UI.ShowTooltip then UI.ShowTooltip(col or EXP_COLOR, lines) end
            tDesc.Text = node.Name .. ": pick one of " .. #(fam and fam.Effects or {}) .. " effects (each works once in your tree)"
        end

        -- the pick panel (beside the side panel, like the gem panel)
        local panel = Instance.new("Frame")
        panel.Name = "ExpertisePanel"; panel.Size = UDim2.new(0, 340, 1, -110); panel.Position = UDim2.new(1, -SIDE_W - 350, 0, 90)
        panel.BackgroundColor3 = Color3.fromRGB(12, 20, 22); panel.BorderSizePixel = 0; panel.Visible = false; panel.ZIndex = 20; panel.Parent = UI.treeFrame
        RoundCorners(panel, 8)
        do local st = Instance.new("UIStroke"); st.Color = EXP_COLOR; st.Thickness = 2; st.Parent = panel end
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -50, 0, 30); title.Position = UDim2.new(0, 10, 0, 6); title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBlack; title.TextSize = 14; title.TextColor3 = EXP_COLOR; title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 21; title.Parent = panel
        local close = Instance.new("TextButton")
        close.Size = UDim2.new(0, 30, 0, 30); close.Position = UDim2.new(1, -38, 0, 6); close.BackgroundColor3 = Color3.fromRGB(90, 40, 50)
        close.Text = "X"; close.Font = Enum.Font.GothamBold; close.TextSize = 14; close.TextColor3 = Color3.new(1, 1, 1); close.ZIndex = 21; close.Parent = panel
        RoundCorners(close, 6)
        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1, -20, 0, 46); sub.Position = UDim2.new(0, 10, 0, 36); sub.BackgroundTransparency = 1; sub.TextWrapped = true
        sub.Font = Enum.Font.GothamMedium; sub.TextSize = 12; sub.TextColor3 = Color3.fromRGB(170, 190, 200); sub.TextXAlignment = Enum.TextXAlignment.Left; sub.TextYAlignment = Enum.TextYAlignment.Top; sub.ZIndex = 21; sub.Parent = panel
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, -16, 1, -134); scroll.Position = UDim2.new(0, 8, 0, 86); scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 5; scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.CanvasSize = UDim2.new(0, 0, 0, 0); scroll.ZIndex = 21; scroll.Parent = panel
        local list = Instance.new("UIListLayout"); list.Padding = UDim.new(0, 6); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = scroll
        local back = Instance.new("TextButton")
        back.Name = "TakeBack"; back.Size = UDim2.new(1, -16, 0, 36); back.Position = UDim2.new(0, 8, 1, -44); back.BackgroundColor3 = Color3.fromRGB(110, 50, 50)
        back.Font = Enum.Font.GothamBold; back.TextSize = 13; back.TextColor3 = Color3.new(1, 1, 1); back.ZIndex = 21; back.Parent = panel
        RoundCorners(back, 6)
        local openId: string? = nil
        local armed: string? = nil -- (a change / take-back costs a refund: the first click arms, the second pays)
        local busy = false
        local Render: () -> ()
        local function Act(action, effId)
            if busy or not openId then return end
            busy = true
            local called, ok, msg = pcall(function() return Remotes.GetFunction("ExpertiseAction"):InvokeServer(action, openId, effId) end)
            busy = false
            if not called then ok, msg = false, nil end
            ShowToast(msg or (ok and "Done." or "Can't do that."))
            if ok then SoundHelper.Play("Upgrade") end
            armed = nil
        end
        UI.ExpertiseChoose = function(effId)
            if not openId then return end
            local mine = Picks()[openId]
            if mine == effId then return end
            if mine and armed ~= effId then armed = effId; Render(); return end
            Act("Pick", effId)
        end
        UI.ExpertiseTakeBack = function()
            if not openId or not Picks()[openId] then return end
            if armed ~= "__back" then armed = "__back"; Render(); return end
            Act("Refund")
        end
        Render = function()
            for _, c in ipairs(scroll:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
            local node = openId and SkillTreeData[openId]
            if not node then panel.Visible = false return end
            local fam = ExpertiseData.Families[node.Family]
            local mine = Picks()[openId]
            local held = Held(node)
            title.Text = string.upper(node.Name)
            sub.Text = held and ("Pick ONE effect for 1 point. Each effect works once in your whole tree. Changing or taking it back costs a refund (" .. UI.RefundCostText(1) .. ").")
                or "Allocate a notable of this cluster first, then come back to pick an effect."
            for i, effId in ipairs(fam and fam.Effects or {}) do
                local e = ExpertiseData.Effects[effId]
                local used = UsedAt(effId, openId)
                local row = Instance.new("Frame")
                row.Name = "Eff_" .. effId; row.Size = UDim2.new(1, -6, 0, 0); row.AutomaticSize = Enum.AutomaticSize.Y; row.BackgroundColor3 = (mine == effId) and Color3.fromRGB(24, 52, 46) or Color3.fromRGB(22, 30, 34)
                row.BorderSizePixel = 0; row.LayoutOrder = i; row.ZIndex = 22; row.Parent = scroll
                RoundCorners(row, 6)
                local st = Instance.new("UIStroke"); st.Color = (mine == effId) and EXP_COLOR or Color3.fromRGB(60, 80, 90); st.Thickness = 1; st.Parent = row
                local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 6); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 104); pad.Parent = row
                local t = Instance.new("TextLabel")
                t.Size = UDim2.new(1, 0, 0, 0); t.AutomaticSize = Enum.AutomaticSize.Y; t.BackgroundTransparency = 1; t.TextWrapped = true; t.RichText = true
                t.Font = Enum.Font.GothamMedium; t.TextSize = 12; t.TextXAlignment = Enum.TextXAlignment.Left; t.TextColor3 = Color3.fromRGB(190, 210, 225); t.ZIndex = 23
                t.Text = string.format('<b><font color="#%s">◈ %s</font></b>\n%s', ((mine == effId) and EXP_COLOR or Color3.fromRGB(235, 240, 245)):ToHex(), e.Name, table.concat(EffectLines(e, mine == effId), "\n"))
                t.Parent = row
                local b = Instance.new("TextButton")
                b.Name = "Pick"; b.Size = UDim2.new(0, 92, 0, 30); b.AnchorPoint = Vector2.new(1, 0.5); b.Position = UDim2.new(1, 98, 0.5, 0)
                b.Font = Enum.Font.GothamBold; b.TextSize = 11; b.TextWrapped = true; b.TextColor3 = Color3.new(1, 1, 1); b.ZIndex = 24; b.Parent = row
                RoundCorners(b, 5)
                if mine == effId then b.Text, b.BackgroundColor3, b.Active, b.AutoButtonColor = "PICKED", Color3.fromRGB(40, 110, 90), false, false
                elseif used then b.Text, b.BackgroundColor3, b.Active, b.AutoButtonColor = "TAKEN ELSEWHERE", Color3.fromRGB(55, 55, 65), false, false
                elseif not held then b.Text, b.BackgroundColor3, b.Active, b.AutoButtonColor = "LOCKED", Color3.fromRGB(55, 55, 65), false, false
                elseif mine then b.Text, b.BackgroundColor3 = (armed == effId) and "CONFIRM SWITCH" or "SWITCH", (armed == effId) and Color3.fromRGB(170, 120, 40) or Color3.fromRGB(60, 90, 110)
                else b.Text, b.BackgroundColor3 = "PICK  (1 POINT)", Color3.fromRGB(40, 140, 110) end
                if b.Text == "PICK  (1 POINT)" or b.Text == "SWITCH" or b.Text == "CONFIRM SWITCH" then
                    b.MouseButton1Click:Connect(function() UI.ExpertiseChoose(effId) end)
                end
            end
            back.Visible = mine ~= nil
            back.Text = (armed == "__back") and ("CONFIRM: TAKE BACK FOR " .. string.upper(UI.RefundCostText(1))) or ("TAKE BACK  (+1 point, costs " .. UI.RefundCostText(1) .. ")")
        end
        back.MouseButton1Click:Connect(function() UI.ExpertiseTakeBack() end)
        close.MouseButton1Click:Connect(function() panel.Visible = false end)
        UI.ExpertisePanelRefresh = function() if panel.Visible then Render() end end
        UI.treeFrame:GetPropertyChangedSignal("Visible"):Connect(function() if not UI.treeFrame.Visible then panel.Visible = false end end)
        UI.ExpertiseClick = function(id, right)
            if right then
                if Picks()[id] then
                    openId, armed = id, nil
                    gemPanel.Visible = false
                    panel.Visible = true
                    UI.ExpertiseTakeBack()
                    Render()
                end
                return
            end
            if not clientState.Class then ShowToast("Pick a class first: click one of the big class circles."); return end
            openId, armed = id, nil
            gemPanel.Visible = false
            panel.Visible = true
            Render()
        end
        gemsBtn.MouseButton1Click:Connect(function() panel.Visible = false end)
    end)()

    local function ShowNodeTooltip(id: string)
        local node = SkillTreeData[id]
        if node.Type == "Expertise" then UI.ExpertiseTooltip(id, NodeColor(node)) return end
        local isAllocated = allocatedSet[id] == true
        local isSocket = node.Type == "Socket"
        local gem = isSocket and socketed[id] or nil
        local col = gem and (ItemData.RarityColors[gem.Rarity] or SOCKET_COLOR) or NodeColor(node)
        local subtitle
        if node.Type == "ClassStart" then subtitle = "Class start" .. ((clientState.Class == node.Class) and "  •  YOUR CLASS" or "")
        elseif isSocket then subtitle = "Gem Socket" .. ((node.Sector and node.Sector ~= "Hybrid") and ("  •  " .. node.Sector) or "")
        else subtitle = node.Type .. (node.Branch and ("  •  " .. node.Branch) or "") .. ((node.Sector == "Hybrid" and node.Blend) and ("  •  " .. string.gsub(node.Blend, ",", " / ")) or ((node.Sector and node.Sector ~= "Hybrid") and ("  •  " .. node.Sector) or "")) end
        local lines = {
            { Text = node.Name, Bold = true, Size = 15, Color = col },
            { Text = subtitle, Size = 12, Color = Color3.fromRGB(150, 160, 180) },
            { Sep = true },
        }
        for _, l in ipairs(NodeStatLines(node, isAllocated)) do table.insert(lines, { Text = l, Color = Color3.fromRGB(120, 200, 255) }) end
        if node.Description then table.insert(lines, { Text = node.Description, Color = (node.Type == "Keystone") and Color3.fromRGB(255, 210, 90) or Color3.fromRGB(190, 195, 210) }) end
        if node.Type == "Keystone" and not node.Group then -- (0.62 playstyle keystones: any gun)
            table.insert(lines, { Text = "PLAYSTYLE: works with any gun and any class. Allocating unlocks it; equip it in ★ PASSIVES (" .. tostring(ClassData.PassiveLimit(clientState.Level)) .. " slots at your level, more at 75 and 200).",
                Size = 12, Color = Color3.fromRGB(255, 210, 90) })
        end
        if node.Type == "Keystone" and node.Group then
            -- class passive: which guns it works with, and the limit
            local grp = ItemData.WeaponGroups.Label[node.Group] or node.Group
            local held = clientState.EquippedWeapon and ItemData.WeaponGroupOf(clientState.EquippedWeapon) == node.Group
            table.insert(lines, { Text = "PASSIVE SKILL: works only while you hold " .. (ItemData.WeaponGroups.Long[node.Group] or grp) .. ". Allocating unlocks it; equip up to " .. tostring(ClassData.PassiveLimit(clientState.Level)) .. " in ★ PASSIVES.",
                Size = 12, Color = held and Color3.fromRGB(110, 230, 140) or Color3.fromRGB(255, 150, 120) })
        end
        if gem then
            table.insert(lines, { Sep = true })
            for _, l in ipairs(GemTooltipLines(gem, id)) do table.insert(lines, l) end
        end
        table.insert(lines, { Sep = true })
        local tap = GameSettings.TouchOnly()
        if node.Type == "ClassStart" then
            if not clientState.Class then
                table.insert(lines, { Text = (tap and "Tap again" or "Click") .. " to become a " .. node.Name, Color = Color3.fromRGB(110, 230, 140), Size = 12 })
            elseif clientState.Class ~= node.Class then
                table.insert(lines, { Text = "Change class at the Skill Tree (costs a Rebirth Shard)", Color = Color3.fromRGB(150, 150, 170), Size = 12 })
            end
        elseif not clientState.Class then
            table.insert(lines, { Text = "Pick a class first: click a class start (the big circles)", Color = Color3.fromRGB(240, 200, 110), Size = 12 })
        elseif not isAllocated then
            -- (0.62, owner: "when hovering over a node in the skill tree that goes over other nodes, list all of the buffs you
            -- unlock along the way up until the unlock"): the path's nodes before this one, stats summed, big nodes named
            if hoverPath and #hoverPath > 1 then
                local sum, keys, named = {}, {}, {}
                for _, pid in ipairs(hoverPath) do
                    local pn = pid ~= id and SkillTreeData[pid]
                    if pn then
                        for k, v in pairs(pn.Stats or {}) do
                            if type(v) == "number" then
                                if sum[k] == nil then table.insert(keys, k); sum[k] = 0 end
                                sum[k] += v
                            end
                        end
                        if pn.Type == "Notable" or pn.Type == "Keystone" or pn.Type == "Socket" then
                            table.insert(named, { Text = "◆ " .. tostring(pn.Name) .. "  (" .. pn.Type .. ")" .. ((pn.Type ~= "Socket" and pn.Description) and (": " .. pn.Description) or ""),
                                Color = (pn.Type == "Keystone") and Color3.fromRGB(255, 210, 90) or NodeColor(pn), Size = 12 })
                        end
                    end
                end
                table.sort(keys)
                table.insert(lines, { Text = string.format("ALONG THE WAY  (%d node%s before this one, at your level)", #hoverPath - 1, (#hoverPath == 2) and "" or "s"), Bold = true, Size = 13, Color = Color3.fromRGB(150, 230, 255) })
                for i, l in ipairs(UI.TreeStatLines(sum, false)) do
                    if i > 12 then table.insert(lines, { Text = string.format("+%d more stats", #keys - 12), Size = 12, Color = Color3.fromRGB(150, 160, 180) }) break end
                    table.insert(lines, { Text = l, Size = 12, Color = Color3.fromRGB(120, 200, 255) })
                end
                for i, l in ipairs(named) do
                    if i > 6 then table.insert(lines, { Text = string.format("+%d more notables", #named - 6), Size = 12, Color = Color3.fromRGB(150, 160, 180) }) break end
                    table.insert(lines, l)
                end
                table.insert(lines, { Sep = true })
            end
            if UI.TP.Set[id] then -- (QOL M2)
                table.insert(lines, { Text = (tap and "PENDING  •  tap again to take it back (free)" or "PENDING  •  click to take it back (free)  •  APPLY spends the points"), Color = UI.TP.COLOR, Size = 12 })
            end
            if hoverPath then
                local n = #hoverPath
                local pts = clientState.SkillPoints - UI.TP.Count() -- (QOL M2: points not already pending)
                table.insert(lines, { Text = string.format("%s to add: %d point%s%s", tap and "Tap again" or "Click", n, n == 1 and "" or "s", (n > pts) and "  (not enough points)" or "  (pending until APPLY)"), Color = (n > pts) and Color3.fromRGB(240, 110, 110) or Color3.fromRGB(110, 230, 140), Size = 12 })
            end
        elseif isSocket then
            table.insert(lines, { Text = (tap and "Tap again to choose a gem" or "Click to choose a gem  •  Right-click to refund") .. "  (refund: " .. UI.RefundCostText(1) .. ")", Color = SOCKET_COLOR, Size = 12 })
        else
            table.insert(lines, { Text = (tap and "Tap again to refund this node" or "Right-click to refund this node") .. "  (" .. UI.RefundCostText(1) .. ")", Color = Color3.fromRGB(150, 150, 170), Size = 12 })
        end
        if UI.ShowTooltip then UI.ShowTooltip(col, lines) end
        tDesc.Text = node.Name .. ((#NodeStatLines(node, isAllocated) > 0) and (": " .. table.concat(NodeStatLines(node, isAllocated), ", ")) or (node.Description and (": " .. node.Description) or ""))
    end

    UI.DevHoverNode = function(id) HoverNode(id) end -- (Studio test hook: DevAct "treehover:<nodeId>")
    HoverNode = function(id: string?)
        if id == hoveredId then return end
        SetPathHighlight(hoverPath, false)
        hoverPath = nil
        hoverRing.Visible = false
        hoveredId = id
        if not id then
            if UI.HideTooltip then UI.HideTooltip() end
            tDesc.Text = HELP_TEXT
            return
        end
        local node = SkillTreeData[id]
        if clientState.Class and not (UI.treeEff or allocatedSet)[id] and node.Type ~= "ClassStart" then hoverPath = PathTo(id, UI.treeEff or allocatedSet, leapSet) end -- (QOL M2: from allocated + pending)
        SetPathHighlight(hoverPath, true)
        if node.Type == "Socket" then MoveRing(hoverRing, node.Position); hoverRing.Visible = true end
        ShowNodeTooltip(id)
    end

    local function Refund(id: string)
        local node = SkillTreeData[id]
        if not allocatedSet[id] or node.Type == "ClassStart" or allocating then return end
        allocating = true
        local called, ok, msg = pcall(function() return Remotes.GetFunction("RefundSkillNode"):InvokeServer(id) end)
        allocating = false
        if not called then ok, msg = false, nil end
        ShowToast(msg or (ok and "Refunded." or "Can't refund that."))
        if UI.HideTooltip then UI.HideTooltip() end
    end
    UI.DevClickNode = function(id, right) if SkillTreeData[id] then ClickNode(id, right) end end -- (Studio: DevAct "treeclick:<id>[:right]")
    ClickNode = function(id: string, right: boolean?)
        if allocating then return end
        local node = SkillTreeData[id]
        if node.Type == "Expertise" then
            if GameSettings.TouchOnly() and UI.treeTouchSel ~= id then
                UI.treeTouchSel = id; hoveredId = nil; HoverNode(id)
                return
            end
            UI.treeTouchSel = nil
            UI.ExpertiseClick(id, right)
            return
        end
        local isAllocated = allocatedSet[id] == true
        local isSocket = node.Type == "Socket"
        if UI.TP.Set[id] and not isAllocated then -- (QOL M2: a pending node comes back free -- click, right-click or a 2nd tap)
            if GameSettings.TouchOnly() and UI.treeTouchSel ~= id then UI.treeTouchSel = id; hoveredId = nil; HoverNode(id); return end
            UI.treeTouchSel = nil
            UI.TP.Remove(id, allocatedSet, leapSet)
            SoundHelper.Play("Click")
            hoveredId = nil
            HoverNode(nil)
            return
        end
        if right then Refund(id) return end
        if GameSettings.TouchOnly() then
            -- phones: no hover -- the first tap selects (shows the node + its path), a second tap acts
            if UI.treeTouchSel ~= id then
                UI.treeTouchSel = id
                hoveredId = nil
                HoverNode(id)
                return
            end
            UI.treeTouchSel = nil
            if isAllocated and not isSocket and node.Type ~= "ClassStart" then Refund(id) return end
        end
        if node.Type == "ClassStart" then
            if not clientState.Class then
                allocating = true
                local called, ok, msg = pcall(function() return Remotes.GetFunction("ChooseClass"):InvokeServer(node.Class) end)
                allocating = false
                if not called then ok, msg = false, nil end
                ShowToast(msg or (ok and "Class chosen." or "Can't pick that."))
                if ok then SoundHelper.Play("Upgrade") end
            end
            return
        end
        if isAllocated then
            if isSocket then OpenGemPanel(id) end
            return
        end
        if not clientState.Class then ShowToast("Pick a class first: click one of the big class circles."); return end
        -- (QOL M2 2026-10-28, owner: "Undo-before applying in passive"): the path goes PENDING -- nothing is spent until APPLY
        -- (UI.TreeApplyPending -> the batch remote AllocateSkillNodes, validated there). One click = one UNDO step.
        local path = PathTo(id, UI.TP.Eff(allocatedSet), leapSet)
        if not path then return end
        local pts = clientState.SkillPoints - UI.TP.Count()
        if #path > pts then
            ShowToast(string.format("Needs %d skill points (you have %d%s).", #path, pts, UI.TP.Count() > 0 and " not already pending" or ""))
            return
        end
        UI.TP.AddPath(path)
        SoundHelper.Play("Click")
        hoveredId = nil
        HoverNode(nil)
    end
    -- (QOL M2) APPLY: every pending node in one server call; true when it went through
    UI.TreeApplyPending = function(): boolean
        if allocating or UI.TP.Count() == 0 then return false end
        allocating = true
        local ok, msg = UI.TP.Apply()
        allocating = false
        ShowToast(msg or (ok and "Applied." or "Couldn't apply those nodes."))
        if ok then SoundHelper.Play("Upgrade") end
        RefreshTree()
        UpdateWeaponHUD()
        return ok
    end

    -- ===== RESTYLE (every state change): node looks, coloured lines between allocated nodes, gem rings =====
    local function Restyle()
        allocatedSet = {}
        for _, id in ipairs(clientState.AllocatedNodes or {}) do allocatedSet[id] = true end
        socketed = clientState.SocketedGems or {}
        leapSet = GemData.LeapNodes(socketed, allocatedSet)
        if UI.TP.Prune(allocatedSet, leapSet, clientState.SkillPoints or 0, clientState.Class ~= nil) then task.defer(RefreshTree) end -- (QOL M2: a refund / respec drops what hung on it; the header + bar redo their counts)
        UI.treeEff = UI.TP.Eff(allocatedSet) -- (allocated + pending: adjacency, lines, paths)
        local picks = type(clientState.Expertise) == "table" and clientState.Expertise or {}
        for id, node in pairs(SkillTreeData) do
            if node.Type == "Expertise" then -- (2026-10-22: filled = picked, ring = open to pick)
                local open = false
                if not picks[id] then for _, nid in ipairs(node.Ring or {}) do if allocatedSet[nid] then open = true break end end end
                nodeState[id] = { Alloc = picks[id] ~= nil, Adj = open }
                StyleNode(id)
                continue
            end
            local isAllocated = allocatedSet[id] == true
            local adjacent = false
            if not isAllocated then
                adjacent = leapSet[id] == true
                if not adjacent and clientState.Class then
                    for _, c in ipairs(node.Connections) do if UI.treeEff[c] then adjacent = true break end end
                end
            end
            nodeState[id] = { Alloc = isAllocated, Adj = adjacent }
            StyleNode(id)
        end
        for _, l in ipairs(lineList) do
            local active = UI.treeEff[l.A] and UI.treeEff[l.B]
            if active and not l.Line then
                local na, nb = SkillTreeData[l.A], SkillTreeData[l.B]
                local p1, p2 = na.Position * S0, nb.Position * S0
                local diff = p2 - p1
                local line = Instance.new("Frame")
                line.Name = "A"; line.BorderSizePixel = 0; line.AnchorPoint = Vector2.new(0.5, 0.5)
                line.Size = UDim2.fromOffset(diff.Magnitude, 4)
                line.Position = UDim2.fromOffset((p1.X + p2.X) / 2, (p1.Y + p2.Y) / 2)
                line.Rotation = math.deg(math.atan2(diff.Y, diff.X))
                line.BackgroundColor3 = NodeColor(na):Lerp(NodeColor(nb), 0.5)
                line:SetAttribute("Col", line.BackgroundColor3) -- (QOL M2: its own colour, back after a pending stretch is applied)
                line.ZIndex = 2
                line.Parent = activeLayer
                l.Line = line
                -- (TREE LOOK v2: a soft wide glow under an allocated path)
                local glow = line:Clone()
                glow.Name = "G"; glow.Size = UDim2.fromOffset(diff.Magnitude, 11); glow.BackgroundTransparency = 0.82; glow.ZIndex = 1
                local gc = Instance.new("UICorner"); gc.CornerRadius = UDim.new(1, 0); gc.Parent = glow
                glow.Parent = activeLayer
                l.Glow = glow
            end
            if l.Line then l.Line.Visible = active == true end
            if l.Glow then l.Glow.Visible = active == true end
            if l.Line and active then -- (QOL M2: a line to a pending node in the pending colour)
                local pc = (UI.TP.Set[l.A] or UI.TP.Set[l.B]) and UI.TP.COLOR or l.Line:GetAttribute("Col")
                if pc and l.Line.BackgroundColor3 ~= pc then l.Line.BackgroundColor3 = pc; if l.Glow then l.Glow.BackgroundColor3 = pc end end
            end
        end
        for _, c in ipairs(ringsFolder:GetChildren()) do if c ~= hoverRing then c:Destroy() end end
        for sid, g in pairs(socketed) do
            local sn = SkillTreeData[sid]
            if sn and allocatedSet[sid] then MakeRing(sn.Position, ItemData.RarityColors[g.Rarity] or SOCKET_COLOR, 0.93, "Ring_" .. sid) end
        end
    end

    local function ApplySearch()
        local q = string.lower(string.gsub(search.Text, "^%s+", ""))
        searchHits = {}
        local n = 0
        if #q >= 2 then
            for id, node in pairs(SkillTreeData) do
                local hit = string.find(string.lower(node.Name), q, 1, true) ~= nil
                if not hit then
                    for _, l in ipairs(NodeStatLines(node)) do if string.find(string.lower(l), q, 1, true) then hit = true break end end
                end
                if not hit and node.Description and string.find(string.lower(node.Description), q, 1, true) then hit = true end
                if not hit and node.Type == "Expertise" then -- (its effects' names + texts)
                    local ED = require(sharedFolder:WaitForChild("ExpertiseData"))
                    for _, effId in ipairs((ED.Families[node.Family] or {}).Effects or {}) do
                        local e = ED.Effects[effId]
                        if string.find(string.lower(e.Name .. " " .. (e.Desc or "")), q, 1, true) then hit = true break end
                    end
                end
                if hit then searchHits[id] = true; n += 1 end
            end
            searchCount.Text = n .. " match" .. (n == 1 and "" or "es")
        else
            searchCount.Text = ""
        end
        if built then Restyle() end
    end
    search:GetPropertyChangedSignal("Text"):Connect(ApplySearch)

    RefreshTree = function()
        local totalTreeNodes = 0
        for _, n in pairs(SkillTreeData) do if n.Type ~= "ClassStart" and n.Type ~= "Expertise" then totalTreeNodes += 1 end end
        local mine = MyStart()
        local spent = 0
        for _, id in ipairs(clientState.AllocatedNodes or {}) do if id ~= mine then spent += 1 end end
        local treeKey = string.upper(GameSettings.KeyLabel(GameSettings.BindName("Tree")))
        if not clientState.Class then
            -- (0.93: no class pop-up on join -- you pick one here when you're ready)
            -- (TREE LOOK v2: no key hint in the title -- owner rule "hints on hover"; "100 / 3999 NODES" read as a to-do list)
            tHeader.Text = "PASSIVE TREE   •   NO CLASS YET   •   PICK ONE BOTTOM RIGHT, THE FIRST IS FREE"
        else
            tHeader.Text = string.format("PASSIVE TREE   •   %s   •   %d SPENT   •   %d POINT%s TO SPEND   •   %d UNWIND%s",
                string.upper(clientState.Class), spent, clientState.SkillPoints - UI.TP.Count(), (clientState.SkillPoints - UI.TP.Count()) == 1 and "" or "S",
                (clientState.Materials or {}).Unwind or 0, ((clientState.Materials or {}).Unwind or 0) == 1 and "" or "S")
                .. ((UI.TP.Count() > 0) and string.format("   •   %d PENDING", UI.TP.Count()) or "") -- (QOL M2)
        end
        if UI.treePendBar then UI.treePendBar.Set(UI.TP.Count(), clientState.SkillPoints - UI.TP.Count()) end
        local _ = totalTreeNodes; local _k = treeKey
        -- (2026-10-22 PAID REFUNDS: every point back costs an Unwind, else gold by level; the respec = all of them)
        for _ in pairs(type(clientState.Expertise) == "table" and clientState.Expertise or {}) do spent += 1 end
        UI.respecCost = (spent > 0) and UI.RefundCostText(spent) or nil
        if not respecArmed then respecBtn.Text = (spent > 0) and ("RESPEC  (" .. UI.respecCost .. ")") or "RESPEC" end
        if UI.ExpertisePanelRefresh then UI.ExpertisePanelRefresh() end
        gemsBtn.Text = string.format("GEM BAG  (%d)", #(clientState.Gems or {}))
        if UI.RefreshAsc then UI.RefreshAsc() end
        UI.treeClassBtn.Visible = true
        -- (0.60f, owner: "class changes should only cost 1 rebirth shard, not 2": it always cost 1 -- this showed the count
        -- you OWN, which read as the price)
        if clientState.Class then
            UI.treeClassBtn.Text = string.format("CHANGE CLASS  (shards: %d)", (clientState.Materials or {}).RebirthShard or 0) -- (short: the long cost text ran out of the button on phones; the picker explains the cost)
            UI.TreeBtn(UI.treeClassBtn, Color3.fromRGB(120, 200, 255))
        else -- (0.93: the way in for a new player)
            UI.treeClassBtn.Text = "★ CHOOSE YOUR CLASS  (free)"
            UI.TreeBtn(UI.treeClassBtn, UIStyle.Colors.Accent, true) -- (UI CLEAN R-A2 sweep: the primary = the off-white accent, not a gold slab)
        end
        -- (a socket that got refunded / respecced away closes its gem panel)
        if gemPanel.Visible and gemPanelSocket and not table.find(clientState.AllocatedNodes or {}, gemPanelSocket) then gemPanel.Visible = false end
        if gemPanel.Visible then RenderGemPanel() end
        if UI.RefreshPassives then UI.RefreshPassives() end

        if not built then
            local t0 = os.clock()
            Build()
            UI.treeBuildMs = math.round((os.clock() - t0) * 1000)
        end
        Restyle()

        -- side panel totals
        for _, c in ipairs(sideScroll:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local totals: { [string]: number } = {}
        local keystones = {}
        for _, id in ipairs(clientState.AllocatedNodes or {}) do
            local node = SkillTreeData[id]
            if node then
                if node.Type == "Keystone" then table.insert(keystones, node) end
                for k, v in pairs(node.Stats or {}) do totals[k] = (totals[k] or 0) + v end
            end
        end
        local order = 0
        local function SideLine(text: string, color: Color3, bold: boolean?)
            order += 1
            local l = Instance.new("TextLabel")
            l.Size = UDim2.new(1, -6, 0, 0); l.AutomaticSize = Enum.AutomaticSize.Y; l.BackgroundTransparency = 1
            l.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium; l.TextSize = 12; l.TextColor3 = color
            l.TextXAlignment = Enum.TextXAlignment.Left; l.TextWrapped = true; l.Text = text; l.LayoutOrder = order
            l.Parent = sideScroll
        end
        -- (2026-10-22 TREE LOOK v2, owner: "it looks super lazy": a wall of 12 px lines -> section headers and stat ROWS, the
        -- name on the left and the number right-aligned in the class colour; gun-type stats grouped under one header instead
        -- of "(only with that gun type)" on every line)
        local function Section(text: string, color: Color3?)
            order += 1
            local f = UIStyle.SectionHeader(sideScroll, text, { LayoutOrder = order, Height = 22, Color = color, TextSize = 12 })
            f.Size = UDim2.new(1, -6, 0, 22)
        end
        local function StatRow(text: string, valueColor: Color3)
            local val, name = string.match(text, "^([%+%-]?[%d%.,]+[%%x]?)%s+(.+)$")
            if not val then SideLine(text, valueColor) return end
            order += 1
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -6, 0, 17); row.BackgroundTransparency = 1; row.LayoutOrder = order; row.Parent = sideScroll
            row:SetAttribute("Skinned", true)
            local n = Instance.new("TextLabel")
            n.BackgroundTransparency = 1; n.Size = UDim2.new(1, -66, 1, 0); n.Font = Enum.Font.GothamMedium; n.TextSize = 12
            n.TextColor3 = UIStyle.Colors.Sub; n.TextXAlignment = Enum.TextXAlignment.Left; n.TextTruncate = Enum.TextTruncate.AtEnd
            n.Text = name; n.Parent = row
            local v = Instance.new("TextLabel")
            v.BackgroundTransparency = 1; v.Size = UDim2.new(0, 64, 1, 0); v.Position = UDim2.new(1, -64, 0, 0); v.Font = Enum.Font.GothamBold
            v.TextSize = 12; v.TextColor3 = valueColor; v.TextXAlignment = Enum.TextXAlignment.Right; v.Text = val; v.Parent = row
        end
        local cls = clientState.Class and ClassData.ById[clientState.Class]
        if cls then
            order += 1
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, -6, 0, 0); card.AutomaticSize = Enum.AutomaticSize.Y; card.BackgroundColor3 = UIStyle.Colors.Bg1
            card.BorderSizePixel = 0; card.LayoutOrder = order; card.Parent = sideScroll
            card:SetAttribute("Skinned", true)
            local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 3); cc.Parent = card
            -- (the text sits in an inner auto-sized frame; the class-colour bar follows its height -- a scale-sized bar inside an
            -- auto-sized card fed back into its size and stretched the panel)
            local inner = Instance.new("Frame")
            inner.BackgroundTransparency = 1; inner.Size = UDim2.new(1, -12, 0, 0); inner.Position = UDim2.fromOffset(12, 0)
            inner.AutomaticSize = Enum.AutomaticSize.Y; inner.Parent = card
            local bar = Instance.new("Frame"); bar.BackgroundColor3 = cls.Color; bar.BorderSizePixel = 0; bar.Size = UDim2.fromOffset(3, 0); bar.Parent = card
            inner:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() bar.Size = UDim2.fromOffset(3, inner.AbsoluteSize.Y) end)
            local pad = Instance.new("UIPadding"); pad.PaddingRight = UDim.new(0, 8); pad.PaddingTop = UDim.new(0, 6)
            pad.PaddingBottom = UDim.new(0, 7); pad.Parent = inner
            local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 2); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = inner
            local t1 = Instance.new("TextLabel")
            t1.BackgroundTransparency = 1; t1.Size = UDim2.new(1, 0, 0, 18); t1.Font = Enum.Font.GothamBlack; t1.TextSize = 15; t1.TextColor3 = cls.Color
            t1.TextXAlignment = Enum.TextXAlignment.Left; t1.Text = string.upper(cls.Id); t1.LayoutOrder = 1; t1.Parent = inner
            t1:SetAttribute("NoRarityDrift", true)
            local t2 = Instance.new("TextLabel")
            t2.BackgroundTransparency = 1; t2.Size = UDim2.new(1, 0, 0, 14); t2.Font = Enum.Font.GothamBold; t2.TextSize = 11; t2.TextColor3 = UIStyle.Colors.Sub
            t2.TextXAlignment = Enum.TextXAlignment.Left; t2.Text = string.upper(cls.Role); t2.LayoutOrder = 2; t2.Parent = inner
            local t3 = Instance.new("TextLabel")
            t3.BackgroundTransparency = 1; t3.Size = UDim2.new(1, 0, 0, 0); t3.AutomaticSize = Enum.AutomaticSize.Y; t3.Font = Enum.Font.Gotham; t3.TextSize = 11
            t3.TextColor3 = UIStyle.Colors.Muted; t3.TextWrapped = true; t3.TextXAlignment = Enum.TextXAlignment.Left; t3.Text = cls.Blurb; t3.LayoutOrder = 3; t3.Parent = inner
        end
        local eqP = type(clientState.EquippedPassives) == "table" and clientState.EquippedPassives or {}
        if #keystones > 0 then
            Section(string.format("PASSIVES  %d / %d  (%d unlocked)", #eqP, ClassData.PassiveLimit(clientState.Level), #keystones), Color3.fromRGB(255, 210, 90))
        end
        for _, ks in ipairs(keystones) do
            local grp = ks.Group and ItemData.WeaponGroups.Label[ks.Group]
            local on = false
            for _, id in ipairs(eqP) do if SkillTreeData[id] == ks then on = true end end
            SideLine((on and "★ " or "☆ ") .. ks.Name .. (grp and ("  (" .. grp .. ")") or "") .. (on and "" or "  [not equipped]"),
                on and Color3.fromRGB(255, 210, 90) or Color3.fromRGB(150, 140, 120), true)
            if ks.Description and on then SideLine(ks.Description, Color3.fromRGB(190, 190, 205)) end
        end
        do -- (2026-10-22) EXPERTISE picks: names here, their stats join the totals below
            local ED = require(sharedFolder:WaitForChild("ExpertiseData"))
            local picks = type(clientState.Expertise) == "table" and clientState.Expertise or {}
            local ids = {}
            for nid in pairs(picks) do table.insert(ids, nid) end
            table.sort(ids)
            if #ids > 0 then Section(string.format("EXPERTISE  (%d)", #ids), Color3.fromRGB(120, 235, 200)) end
            for _, nid in ipairs(ids) do
                local e, n = ED.Effects[picks[nid]], SkillTreeData[nid]
                if e and n then
                    SideLine("◈ " .. e.Name .. "  (" .. n.Name .. ")", Color3.fromRGB(120, 235, 200), true)
                    if e.Desc then SideLine(e.Desc, Color3.fromRGB(190, 195, 210)) end
                    for k, v in pairs(e.Stats or {}) do totals[k] = (totals[k] or 0) + v end
                end
            end
        end
        for sid, g in pairs(socketed) do
            if allocatedSet[sid] then
                local d = GemData.Describe(g)
                SideLine(GemData.Icon(g) .. " " .. d.Title, ItemData.RarityColors[g.Rarity] or SOCKET_COLOR, true)
                for _, l in ipairs(d.Lines) do SideLine(l, Color3.fromRGB(190, 170, 240)) end
                if d.Special then SideLine(d.Special, Color3.fromRGB(255, 210, 90)) end
                for i, l in ipairs(GemNowLines(g, sid)) do SideLine(l, (i == 1) and Color3.fromRGB(150, 160, 180) or Color3.fromRGB(120, 230, 150)) end
            end
        end
        local keys = {}
        for k in pairs(totals) do table.insert(keys, k) end
        table.sort(keys, function(a, b)
            local la = ItemData.StatDefs[a] and ItemData.StatDefs[a].Label or a
            local lb = ItemData.StatDefs[b] and ItemData.StatDefs[b].Label or b
            return la < lb
        end)
        if UI.TreeStatsDirty then UI.TreeStatsDirty() end
        local valCol = cls and cls.Color:Lerp(Color3.new(1, 1, 1), 0.25) or Color3.fromRGB(150, 205, 255)
        local general, gunOnly = {}, {}
        local TAIL = "  (only with that gun type)"
        for _, k in ipairs(keys) do
            if math.abs(totals[k]) > 1e-6 then
                local line = UI.TreeTotalLine(k, totals[k])
                if string.sub(line, -#TAIL) == TAIL then table.insert(gunOnly, string.sub(line, 1, -#TAIL - 1)) else table.insert(general, line) end
            end
        end
        if #general > 0 then
            Section("TREE BONUSES")
            for _, l in ipairs(general) do StatRow(l, valCol) end
        end
        if #gunOnly > 0 then
            Section("WITH THAT GUN TYPE ONLY")
            for _, l in ipairs(gunOnly) do StatRow(l, valCol:Lerp(UIStyle.Colors.Muted, 0.35)) end
        end
        if #general + #gunOnly > 0 then SideLine("What they give at your level, before gem bonuses.", UIStyle.Colors.Muted) end
        if not cls then
            SideLine("No class yet: press CHOOSE YOUR CLASS below when you know how you like to play (the first pick is free). Each of the five class starts sits in the area of the tree that suits its guns, but you can path anywhere. Zoom out (scroll / pinch) to see the whole tree.", Color3.fromRGB(150, 160, 180))
        elseif #keys == 0 and #keystones == 0 then
            SideLine("Nothing allocated yet. Your class's area (its colour) holds its weapon's nodes; the ★ PASSIVE SKILLS work only with your class's guns: allocate as many as you like, equip " .. ClassData.PassiveLimit(clientState.Level) .. " at a time in ★ PASSIVES. Search for a stat at the top-left.", Color3.fromRGB(150, 160, 180))
        end
        if clientState.TreeWasReset and not UI.treeResetShown then
            UI.treeResetShown = true
            ShowToast("The passive tree and specializations were rebuilt. All your points were refunded for free. Spend them again!")
        end

        if not fittedOnce then
            fittedOnce = true
            task.defer(function()
                local s = MyStart()
                -- (0.99u: a fresh save (no class) opened on the WHOLE tree at the fit zoom ~0.18, where the pre-rendered tiles
                -- are drawn ~10x smaller than their pixels and the lines average away into the background -- the tree read
                -- dim / empty. Open on the five class starts instead (zoom 0.6); "O" still shows the whole tree.)
                if s then CenterOn(SkillTreeData[s].Position, 1.0) else CenterOn(Vector2.zero, 0.6) end
            end)
        end
        UpdateCanvasTransform()
    end
    end)()
    end

    -- ==================== [MENU 3: INVENTORY, CHARACTER SHEET & STASH] ====================
    -- Three columns: CHARACTER (level, attributes, every stat with a hover description) | EQUIPPED
    -- (weapon + 7 gear slots) | STASH (weapons / gear, sortable compact rows). Hovering any item shows a
    -- tooltip with its full details, affixes and how it compares to what you have equipped.
    local C = Color3.fromRGB
    -- (Update 5: the design system's neutral surfaces + text steps; the inventory was a blue-tinted set of its own)
    -- (UI v4 NEON: the three columns are dark wells in the window, rows a step up, hover a step more)
    local COL_BG, COL_PANEL, COL_ROW, COL_ROW_HOVER = UIStyle.Colors.Bg0, UIStyle.Colors.CardDark, UIStyle.Colors.Bg1, UIStyle.Colors.Bg2
    local COL_TEXT, COL_DIM, COL_ACCENT = UIStyle.Colors.Text, UIStyle.Colors.Sub, UIStyle.Colors.Accent

    UI.invFrame = Instance.new("Frame")
    UI.invFrame.Name = "InvMenu"
    UI.invFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    UI.invFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    UI.invFrame.Size = UDim2.new(1, 0, 1, 0) -- (UI CLEAN INV: a full-screen menu, the owner's accepted target)
    UI.invFrame.BackgroundColor3 = COL_BG
    UI.invFrame.Visible = false
    UI.invFrame.Parent = UI.menuFolder
    ApplyPanelChrome(UI.invFrame, COL_ACCENT, 12)
    local invSizeLimit = Instance.new("UISizeConstraint")
    invSizeLimit.MinSize = Vector2.new(820, 460)
    invSizeLimit.MaxSize = Vector2.new(100000, 100000) -- (UI CLEAN INV: full screen)
    invSizeLimit.Parent = UI.invFrame

    local function Label(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font?, xAlign: Enum.TextXAlignment?): TextLabel
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Font = font or Enum.Font.GothamMedium
        l.TextSize = size
        l.TextColor3 = color
        l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.Text = text
        l.Parent = parent
        return l
    end
    local function SmallButton(parent: Instance, text: string, color: Color3, w: number): TextButton
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, w, 0, 24)
        b.BackgroundColor3 = color
        b.Font = Enum.Font.GothamBlack -- (UI CLEAN: display caps -- the type pass maps it to the condensed face)
        b.TextSize = 14
        b.TextColor3 = UIStyle.Colors.Text
        b.Text = text
        b:SetAttribute("TextRole", "Button")
        b.AutoButtonColor = false
        b.Parent = parent
        return b
    end
    local function Panel(parent: Instance, pos: UDim2, size: UDim2, title: string): (Frame, TextLabel)
        local f = Instance.new("Frame")
        f.Position = pos
        f.Size = size
        f.BackgroundColor3 = COL_PANEL
        f.BackgroundTransparency = 1 -- (UI CLEAN: the columns are open areas of the window, split by one hairline)
        f.BorderSizePixel = 0
        f.Parent = parent
        if pos.X.Scale > 0 then
            local rule = Instance.new("Frame")
            rule.Name = "ColumnRule"; rule.BorderSizePixel = 0; rule.BackgroundColor3 = UIStyle.Colors.Line
            rule.Position = UDim2.new(0, -7, 0, 6); rule.Size = UDim2.new(0, 1, 1, -12)
            rule:SetAttribute("Skinned", true); rule.Parent = f
        end
        local t = Label(f, title, 15, COL_TEXT, Enum.Font.GothamBlack) -- (UI CLEAN P4: a head is never dimmer than its content)
        UIStyle.TextRole(t, "SectionHead")
        t.Size = UDim2.new(1, -16, 0, 26)
        t.Position = UDim2.new(0, 10, 0, 4)
        return f, t
    end

    -- Header
    local iHeader = Label(UI.invFrame, "INVENTORY", 18, COL_ACCENT, Enum.Font.GothamBlack)
    iHeader.Size = UDim2.new(0.5, 0, 0, 34)
    iHeader.Position = UDim2.new(0, 16, 0, 4)
    UI.windowHeaders = UI.windowHeaders or {}; UI.windowHeaders[UI.invFrame] = iHeader
    -- EQUIP BEST: the server picks your highest-DPS weapon and the gear that raises your DPS most
    local btnBest = Instance.new("TextButton")
    btnBest.Name = "EquipBest"
    btnBest.Size = UDim2.fromOffset(170, 30)
    btnBest.Position = UDim2.new(0, 150, 0, 6)
    btnBest.BackgroundColor3 = C(60, 190, 110)
    btnBest.Font = Enum.Font.GothamBlack
    btnBest.TextSize = 15
    btnBest.TextColor3 = C(255, 255, 255)
    btnBest.Text = "EQUIP BEST"
    btnBest.ZIndex = 4
    btnBest.Parent = UI.invFrame
    RoundCorners(btnBest, 8)
    -- build presets: the arrow opens a dropdown; picking one equips that build right away
    local BUILDS = {
        { "DPS", "MAX DPS", "Highest damage per second", C(60, 190, 110) },
        { "Tank", "TANK", "Most health and damage reduction", C(90, 140, 230) },
        { "Burn", "BURN", "Burning weapons and burn bonuses", C(255, 130, 50) },
        { "Freeze", "FREEZE", "Freezing weapons and chill bonuses", C(120, 210, 255) },
        { "Bleed", "BLEED", "Bleeding weapons and bleed bonuses", C(215, 50, 65) },
        { "Decay", "DECAY", "Decaying weapons and decay bonuses", C(150, 220, 70) },
        { "Crit", "CRIT", "Crit chance and crit damage", C(240, 200, 60) },
    }
    local buildIdx = 1
    btnBest.Size = UDim2.fromOffset(200, 30)
    local btnDrop = Instance.new("TextButton")
    btnDrop.Name = "BuildDropdown"
    btnDrop.Size = UDim2.fromOffset(32, 30)
    btnDrop.Position = UDim2.new(0, 354, 0, 6)
    btnDrop.BackgroundColor3 = C(40, 46, 64)
    btnDrop.Font = Enum.Font.GothamBlack
    btnDrop.TextSize = 14
    btnDrop.TextColor3 = C(255, 255, 255)
    btnDrop.Text = "▼"
    btnDrop.ZIndex = 4
    btnDrop.Parent = UI.invFrame
    RoundCorners(btnDrop, 8)
    local list = Instance.new("Frame")
    list.Name = "BuildList"
    list.Position = UDim2.new(0, 150, 0, 40)
    list.Size = UDim2.fromOffset(300, #BUILDS * 46 + 8)
    list.BackgroundColor3 = C(16, 18, 26)
    list.Visible = false
    list.ZIndex = 50
    list.Parent = UI.invFrame
    RoundCorners(list, 10)
    local ls = Instance.new("UIStroke"); ls.Thickness = 2; ls.Color = C(70, 80, 110); ls.Parent = list
    local function RefreshBest()
        local b = BUILDS[buildIdx]
        btnBest.Text = "EQUIP BEST: " .. b[2]
        btnBest.BackgroundColor3 = UIStyle.Colors.Steel -- (UI CLEAN INV: a quiet outline button; the preset is in its words)
        require(sharedFolder:WaitForChild("LoadoutScore")).Mode = b[1] -- (QOL2 I4: the gear upgrade signal scores for this build)
    end
    local bestBusy = false
    local function RunBest()
        if bestBusy then return end
        bestBusy = true
        SoundHelper.Play("Click")
        local ok, _done, msg = pcall(function() return Remotes.GetFunction("EquipBest"):InvokeServer(BUILDS[buildIdx][1]) end)
        ShowToast(ok and tostring(msg or "Done") or "Couldn't equip right now")
        task.wait(0.3)
        if UI.invFrame.Visible then RefreshInventory() end
        bestBusy = false
    end
    for i, b in ipairs(BUILDS) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -8, 0, 42)
        row.Position = UDim2.fromOffset(4, 4 + (i - 1) * 46)
        row.BackgroundColor3 = C(28, 31, 44)
        row.Text = ""
        row.AutoButtonColor = true
        row.ZIndex = 51
        row.Parent = list
        RoundCorners(row, 8)
        local dot = Instance.new("Frame")
        dot.Size = UDim2.fromOffset(8, 30)
        dot.Position = UDim2.fromOffset(8, 6)
        dot.BackgroundColor3 = b[4]
        dot.ZIndex = 52
        dot.Parent = row
        RoundCorners(dot, 4)
        local n = Label(row, b[2], 15, b[4], Enum.Font.GothamBlack); UIStyle.TextRole(n, "ItemName", { Keep = true })
        n.Position = UDim2.fromOffset(24, 3); n.Size = UDim2.new(1, -30, 0, 20); n.ZIndex = 52
        local d = Label(row, b[3], 13, COL_DIM, Enum.Font.GothamMedium); UIStyle.TextRole(d, "Meta")
        d.Position = UDim2.fromOffset(24, 21); d.Size = UDim2.new(1, -30, 0, 18); d.ZIndex = 52
        row.MouseButton1Click:Connect(function()
            buildIdx = i
            list.Visible = false
            RefreshBest()
            RunBest()
        end)
    end
    btnDrop.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); list.Visible = not list.Visible end)
    btnBest.MouseButton1Click:Connect(function() list.Visible = false; RunBest() end)
    UI.invFrame:GetPropertyChangedSignal("Visible"):Connect(function() if not UI.invFrame.Visible then list.Visible = false end end)
    RefreshBest()
    local iHint = Label(UI.invFrame, GameSettings.TouchOnly() and "Tap anything for details" or "Hover anything for details", 13, COL_DIM, Enum.Font.Gotham, Enum.TextXAlignment.Right)
    UIStyle.TextRole(iHint, "Meta")
    -- sits on the right of the (full-width) title bar, clear of its close button
    iHint.Size = UDim2.new(0.5, -76, 0, 34)
    iHint.Position = UDim2.new(0.5, 0, 0, 6)
    iHint.ZIndex = 3
    -- (owner 2026-10-04: the stash's top text didn't match the rest of the game) -- same as every title bar's subtitle
    iHint.TextColor3 = UIStyle.Colors.Sub
    iHint.Font = UIStyle.BodyFont
    iHint.TextStrokeTransparency = 1
    iHint:SetAttribute("Skinned", true)
    UIStyle.TextRole(iHint, "Meta") -- (a quiet hint, no outline; the X closes the window)

    -- ===== Tooltip (shared by every menu via UI.ShowTooltip / UI.HideTooltip) =====
    -- + a second card: hold SHIFT over an item to see what you have equipped beside it
    -- (UI CLEAN INV: the target's item card -- a rarity band on top (tinted, a 2 px rarity line, the big icon, the name + its
    -- sub-line), then BASE / MODIFIERS / the compare strip / the footer in an inner padded list. Other tooltips use only the inner.)
    UI.CARD_BG = Color3.fromRGB(10, 12, 16)
    local function MakeTip(name: string): (Frame, UIStroke)
        local function Mk(class, props)
            local o = Instance.new(class)
            for k, v in pairs(props) do if k ~= "Parent" then o[k] = v end end
            if o:IsA("GuiObject") then o:SetAttribute("Skinned", true) end
            o.Parent = props.Parent
            return o
        end
        local f = Mk("Frame", { Name = name, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(0, 330, 0, 0), BackgroundColor3 = UI.CARD_BG,
            BackgroundTransparency = 0, BorderSizePixel = 0, Visible = false, ZIndex = 200, Parent = hudGui })
        f:SetAttribute("NoSkin", true)
        Mk("UIScale", { Name = "PhoneScale", Parent = f }) -- (phones: UI.ShowTooltip sets it -- the HUD's 0.55 short-screen scale made ~7 pt text)
        local st = Mk("UIStroke", { Thickness = 1, Color = UIStyle.Colors.Text, Transparency = 0.84, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
        Mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0), Parent = f })
        local band = Mk("Frame", { Name = "Band", Size = UDim2.new(1, 0, 0, 112), LayoutOrder = 1, BorderSizePixel = 0, BackgroundColor3 = UI.CARD_BG,
            ClipsDescendants = true, Visible = false, ZIndex = 201, Parent = f })
        Mk("Frame", { Name = "Edge", Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0, ZIndex = 202, Parent = band })
        Mk("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12),
            Size = UDim2.fromOffset(200, 64), ScaleType = Enum.ScaleType.Fit, ZIndex = 202, Parent = band })
        local tag = Mk("TextLabel", { Name = "Tag", BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 10), Size = UDim2.new(0.5, 0, 0, 16), Text = "",
            Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 203, Parent = band })
        UIStyle.TextRole(tag, "Meta", { Color = "Sub" })
        local nm = Mk("TextLabel", { Name = "ItemName", BackgroundTransparency = 1, Position = UDim2.new(0, 18, 1, -58), Size = UDim2.new(1, -36, 0, 28), Text = "",
            Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 203, Parent = band })
        UIStyle.TextRole(nm, "WindowTitle", { Keep = true }); nm.TextSize = 24
        local sub = Mk("TextLabel", { Name = "Sub", BackgroundTransparency = 1, Position = UDim2.new(0, 18, 1, -28), Size = UDim2.new(1, -36, 0, 16), Text = "",
            Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 203, Parent = band })
        UIStyle.TextRole(sub, "Label")
        local inner = Mk("Frame", { Name = "Inner", AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2, BackgroundTransparency = 1,
            ZIndex = 201, Parent = f })
        Mk("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), Parent = inner })
        Mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = inner })
        return f, st
    end
    local tip, tipStroke = MakeTip("ItemTooltip")
    local cmpTip, cmpStroke = MakeTip("CompareTooltip")
    require(sharedFolder:WaitForChild("UITheme")).SetMenuRoots({ tip, cmpTip }) -- (SKIN UI THEMES: the item cards take the theme's palette)
    local tipCompare: any = nil -- () -> (lines, color)? for the item under the cursor
    local function ShiftHeld(): boolean
        return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
    end

    local tipFollow: RBXScriptConnection? = nil
    local function PlaceTooltip()
        -- (the HUD gui has a UIScale -- Interface Scale x short-screen factor -- so work in screen pixels and divide:
        -- unscaled offsets put the card off the right edge whenever the scale wasn't 1)
        local sc = hudGui:FindFirstChildOfClass("UIScale")
        local s = sc and sc.Scale or 1
        if s <= 0 then s = 1 end
        local m = UserInputService:GetMouseLocation()
        local vp = Camera and Camera.ViewportSize or Vector2.new(1920, 1080)
        if UI.tipFitIn then -- (QOL2 I6: a card (+ the compare card) taller / wider than the screen shrinks to fit -- once, after layout)
            UI.tipFitIn -= 1
            if UI.tipFitIn <= 0 then
                UI.tipFitIn = nil
                local tw = tip.AbsoluteSize.X + (cmpTip.Visible and (cmpTip.AbsoluteSize.X + 8) or 0)
                local th = math.max(tip.AbsoluteSize.Y, cmpTip.Visible and cmpTip.AbsoluteSize.Y or 0)
                local f = math.min(1, (vp.Y - 16) / math.max(th, 1), (vp.X - 16) / math.max(tw, 1))
                if f < 0.99 then
                    for _, t in ipairs({ tip, cmpTip }) do
                        local ps = t:FindFirstChild("PhoneScale")
                        if ps then ps.Scale = math.max(0.4, ps.Scale * f) end
                    end
                end
            end
        end
        local w, h = tip.AbsoluteSize.X, tip.AbsoluteSize.Y
        local showCmp = cmpTip.Visible
        local cw, ch = cmpTip.AbsoluteSize.X, cmpTip.AbsoluteSize.Y
        local total = w + (showCmp and (cw + 8) or 0)
        local x = m.X + 18
        if x + total > vp.X - 8 then x = m.X - total - 18 end
        x = math.clamp(x, 8, math.max(8, vp.X - total - 8))
        local y = m.Y + 12
        local anc = UI.tipAnchor -- (QOL2 I1: a pad-selected row -- the card sits beside the row, never across the screen centre)
        if anc and anc.Parent then
            local ap, as = anc.AbsolutePosition + game:GetService("GuiService"):GetGuiInset(), anc.AbsoluteSize -- (AbsolutePosition is below the top bar; the mouse + tip.Position are window pixels)
            local right, left = ap.X + as.X + 10, ap.X - total - 10
            local cx = vp.X / 2
            local function Fits(px) return px >= 8 and px + total <= vp.X - 8 end
            local function Clear(px) return px >= cx or px + total <= cx end
            if Fits(right) and Clear(right) then x = right
            elseif Fits(left) and Clear(left) then x = left
            elseif Fits(right) then x = right
            elseif Fits(left) then x = left
            else x = nil end
            if x then y = ap.Y
            else -- (QOL2 I6: a row too wide for a side (the Exchange) -> under the row, or over it when there's no room below)
                x = math.clamp(ap.X + 24, 8, math.max(8, vp.X - total - 8))
                local hh = math.max(h, showCmp and ch or 0)
                local below = ap.Y + as.Y + 6
                y = (below + hh <= vp.Y - 8) and below or math.max(8, ap.Y - hh - 6)
            end
        end
        if y + h > vp.Y - 8 then y = math.max(8, vp.Y - h - 8) end
        tip.Position = UDim2.fromOffset(x / s, y / s)
        if showCmp then
            local cy = math.clamp(y, 8, math.max(8, vp.Y - ch - 8))
            cmpTip.Position = UDim2.fromOffset((x + w + 8) / s, cy / s)
        end
    end

    -- lines = { {Text, Color, Size?, Bold?, Head?, Cap?, Kind?} }. An ITEM card (lines[1].Head, or "EQUIPPED" Cap + Head) gets the
    -- target layout: band (name / sub / icon), meta, BASE (a 2-column label / value grid from the "Label: value" stat lines),
    -- MODIFIERS (affix / trait / other stat lines, the tier on the right), the build lines, the compare strip (Kind "cmp") and the
    -- footer (Kind "foot"). Any other tooltip: one line per entry on the roles (colours snapped to Text / Sub / Muted or Good / Bad).
    local function FillTip(frame: Frame, stroke: UIStroke, borderColor: Color3, lines: { any })
        local inner, band = frame:FindFirstChild("Inner"), frame:FindFirstChild("Band")
        for _, c in ipairs(inner:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local _ = borderColor
        stroke.Color = UIStyle.Colors.Text; stroke.Transparency = 0.84
        local UC = UIStyle.Colors
        local order = 0
        local function Next() order += 1; return order end
        local function Sem(col: Color3?): (Color3?, boolean)
            if not col then return nil, false end
            local hh, ss = col:ToHSV()
            if ss > 0.35 and hh >= 0.22 and hh <= 0.45 then return UC.Good, true end
            if ss > 0.35 and (hh < 0.04 or hh > 0.95) then return UC.Bad, true end
            return nil, false
        end
        local function Line(text: string, role: string, col: Color3?, rich: boolean?, parent: Instance?): TextLabel
            local l = Instance.new("TextLabel")
            l.BackgroundTransparency = 1; l.AutomaticSize = Enum.AutomaticSize.Y; l.Size = UDim2.new(1, 0, 0, 0)
            l.TextWrapped = true; l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 202; l.LayoutOrder = Next()
            l.Font = (role == "SectionHead" or role == "Title") and Enum.Font.GothamBlack or Enum.Font.GothamMedium
            l:SetAttribute("Skinned", true)
            UIStyle.TextRole(l, role, col and { Keep = true } or nil)
            if col then l.TextColor3 = col end
            l.RichText = rich == true
            l.Text = text
            l.Parent = parent or inner
            return l
        end
        local off = 0
        if lines[1] and lines[1].Cap and lines[2] and lines[2].Head then off = 1 end -- (the compare card: "EQUIPPED" over its band)
        local head = lines[1 + off] and lines[1 + off].Head and lines[1 + off]
        band.Visible = head ~= nil
        if not head then
            for _, line in ipairs(lines) do
                if line.Sep then
                    local sep = Instance.new("Frame")
                    sep.Name = "Sep"; sep.Size = UDim2.new(1, 0, 0, 1); sep.BackgroundColor3 = UC.Text; sep.BackgroundTransparency = 0.9
                    sep.BorderSizePixel = 0; sep.LayoutOrder = Next(); sep.ZIndex = 202; sep:SetAttribute("Skinned", true); sep.Parent = inner
                else
                    local col = line.Color or COL_TEXT
                    local sc, sem = Sem(col)
                    local lum = UIStyle.Luma(col)
                    local role = line.Cap and "SectionHead" or line.Bold and "Body" or sem and "Body" or (lum >= 0.5 and "Body") or ((line.Size or 13) <= 12 and "Meta") or "Label"
                    local l = Line(line.RichText or (line.Cap and string.upper(line.Text or "") or line.Text or ""), role, sc, line.RichText ~= nil)
                    if line.Bold and not sem then l.TextColor3 = UC.Text end
                end
            end
            return
        end
        -- ===== ITEM CARD =====
        local col = head.Color or COL_TEXT
        band.BackgroundColor3 = UI.CARD_BG:Lerp(col, 0.10)
        band.Edge.BackgroundColor3 = col
        band.Tag.Text = (off == 1) and string.upper(lines[1].Text or "") or ""
        band.ItemName.Text = string.upper(head.Text or "")
        band.ItemName.TextColor3 = UI.InvL and UI.InvL.Readable(col, band.BackgroundColor3) or col -- (UI CLEAN: >= 4.6:1 on its band)
        if head.Rarity then ItemData.StyleRarityText(band.ItemName, head.Rarity) end
        local subL = lines[2 + off]
        band.Sub.Text = (subL and not subL.Sep and not subL.Head and subL.Text) or ""
        if UI.InvL then
            local spec = UI.InvL.IconFor(head.Item, head.SlotKey)
            UI.InvL.ApplyIcon(band.Icon, spec, 200, 64, 58)
            band.Icon.ImageTransparency = spec.Glyph and 0.3 or 0
        end
        local meta, kv, mods, build, foot, cmp = {}, {}, {}, {}, {}, nil
        local LABEL = { ["Weak-Spot Damage"] = "Weak spot", ["Weapon DPS"] = "DPS", ["Fire Rate"] = "Fire rate" }
        local inBuild = false
        for i = 3 + off, #lines do
            local l = lines[i]
            if l.Sep then -- (structure comes from the heads)
            elseif l.Kind == "cmp" then if not cmp then cmp = l else table.insert(meta, l) end
            elseif l.Kind == "foot" then table.insert(foot, l)
            elseif l.Cap then inBuild = true; table.insert(build, l)
            elseif inBuild then table.insert(build, l)
            elseif l.Kind == "stat" and not l.RichText then
                local got = false
                for seg in string.gmatch((l.Text or "") .. "   ", "(.-)%s%s%s+") do
                    local k, v = string.match(seg, "^([^%s:][^:]*):%s*(.-)%s*$")
                    if k and v ~= "" and #v <= 16 and #k <= 22 then table.insert(kv, { LABEL[k] or k, v }); got = true end
                end
                if not got then table.insert(mods, l) end
            elseif l.Kind == "affix" or l.Kind == "trait" or l.Kind == "stat" or string.find(l.Text or "", "(family)", 1, true) then table.insert(mods, l)
            else table.insert(meta, l) end
        end
        for _, l in ipairs(meta) do
            local sc = Sem(l.Color)
            Line(l.RichText or l.Text or "", "Meta", sc, l.RichText ~= nil)
        end
        local function Head(text: string) Line(text, "SectionHead") end
        if #kv > 0 then
            Head("BASE")
            local g = Instance.new("Frame")
            g.Name = "Base"; g.BackgroundTransparency = 1; g.AutomaticSize = Enum.AutomaticSize.Y; g.Size = UDim2.new(1, 0, 0, 0); g.LayoutOrder = Next()
            g.ZIndex = 202; g:SetAttribute("Skinned", true); g.Parent = inner
            local gl = Instance.new("UIGridLayout"); gl.CellSize = UDim2.new(0.5, -10, 0, 21); gl.CellPadding = UDim2.fromOffset(20, 0)
            gl.SortOrder = Enum.SortOrder.LayoutOrder; gl.Parent = g
            for j, p in ipairs(kv) do
                local cell = Instance.new("Frame"); cell.BackgroundTransparency = 1; cell.LayoutOrder = j; cell:SetAttribute("Skinned", true); cell.Parent = g
                local a = Line(p[1], "Label", nil, false, cell); a.AutomaticSize = Enum.AutomaticSize.None; a.Size = UDim2.new(0.6, 0, 1, 0); a.TextSize = 13
                a.TextWrapped = false; a.TextTruncate = Enum.TextTruncate.AtEnd
                local b = Line(p[2], "Value", nil, false, cell); b.AutomaticSize = Enum.AutomaticSize.None; b.Size = UDim2.new(0.4, 0, 1, 0); b.Position = UDim2.fromScale(0.6, 0)
                b.TextXAlignment = Enum.TextXAlignment.Right; b.TextSize = 13; b.TextWrapped = false
            end
        end
        if #mods > 0 then
            Head("MODIFIERS")
            for _, l in ipairs(mods) do
                local text = l.RichText or l.Text or ""
                local tier = nil
                if not l.RichText then
                    local body, t, rest = string.match(text, "^(.-)%s*%((T%d+)%)(.*)$")
                    if body then text, tier = body .. (rest or ""), t end
                end
                local sc = Sem(l.Color)
                local c = sc or ((l.Kind == "affix") and UC.Text or UC.Sub)
                if l.Negative then c = UC.Bad end
                local row = Instance.new("Frame")
                row.BackgroundTransparency = 1; row.AutomaticSize = Enum.AutomaticSize.Y; row.Size = UDim2.new(1, 0, 0, 0); row.LayoutOrder = Next()
                row.ZIndex = 202; row:SetAttribute("Skinned", true); row.Parent = inner
                local tl = Line((string.gsub(text, "^%s+", "")), "Body", c, l.RichText ~= nil, row); tl.Size = UDim2.new(1, tier and -30 or 0, 0, 0); tl.TextSize = 13
                if tier then
                    local tt = Line(tier, "Meta", nil, false, row); tt.AnchorPoint = Vector2.new(1, 0); tt.Position = UDim2.new(1, 0, 0, 0)
                    tt.AutomaticSize = Enum.AutomaticSize.None; tt.Size = UDim2.fromOffset(28, 17); tt.TextXAlignment = Enum.TextXAlignment.Right
                end
            end
        end
        for _, l in ipairs(build) do
            if l.Cap then Head(string.upper(l.Text or "")) else Line(l.Text or "", "Label", Sem(l.Color)) end
        end
        if cmp then
            local sc = Sem(cmp.Color) or UC.Text
            local strip = Instance.new("Frame")
            strip.Name = "Compare"; strip.BorderSizePixel = 0; strip.BackgroundColor3 = sc; strip.BackgroundTransparency = 0.9
            strip.Size = UDim2.new(1, 0, 0, 38); strip.LayoutOrder = Next(); strip.ZIndex = 202; strip:SetAttribute("Skinned", true); strip.Parent = inner
            local bar = Instance.new("Frame"); bar.BorderSizePixel = 0; bar.BackgroundColor3 = sc; bar.Size = UDim2.new(0, 2, 1, 0); bar.ZIndex = 203
            bar:SetAttribute("Skinned", true); bar.Parent = strip
            local a = Line(cmp.CmpLabel or cmp.Text or "", "Label", nil, false, strip)
            a.AutomaticSize = Enum.AutomaticSize.None; a.Position = UDim2.fromOffset(12, 0); a.Size = UDim2.new(1, -100, 1, 0); a.TextSize = 13
            a.TextTruncate = Enum.TextTruncate.AtEnd; a.TextWrapped = false
            if cmp.CmpValue then
                local v = Line(cmp.CmpValue, "Title", sc, false, strip)
                v.AutomaticSize = Enum.AutomaticSize.None; v.AnchorPoint = Vector2.new(1, 0); v.Position = UDim2.new(1, -10, 0, 0); v.Size = UDim2.new(0, 90, 1, 0)
                v.TextXAlignment = Enum.TextXAlignment.Right; v.TextSize = 22
            end
        end
        for _, l in ipairs(foot) do
            local t = l.Text or ""
            local gold = string.match(t, "^Sells for (%S+) gold")
            if gold then
                t = string.gsub(t, "^Sells for %S+ gold", string.format('Sells for <font color="#%s">%s</font>', UC.Gold:ToHex(), gold))
                Line(t, "Meta", nil, true)
            else
                Line(t, "Meta")
            end
        end
    end
    local function RefreshCompare()
        local lines, color
        -- (touch: no SHIFT -- a tapped item shows the equipped one beside it)
        if tip.Visible and tipCompare and (ShiftHeld() or GameSettings.TouchOnly() or UI.tipAnchor ~= nil) then lines, color = tipCompare() end -- (QOL2 I1: a pad selection compares without SHIFT)
        if lines then
            table.insert(lines, 1, { Text = "EQUIPPED", Color = COL_DIM, Size = 13, Cap = true })
            FillTip(cmpTip, cmpStroke, color or COL_ACCENT, lines)
            cmpTip.Visible = true
        else
            cmpTip.Visible = false
        end
        if tip.Visible then PlaceTooltip() end
    end
    function UI.ShowTooltip(borderColor: Color3, lines: { any }, compare: any?)
        do -- (2026-10-13 phones: the card is drawn at the phone window scale, not the HUD's short-screen 0.55)
            local hs = hudGui:FindFirstChildOfClass("UIScale")
            local kk = (hs and hs.Scale or 1) / UIStyle.SimK()
            local k = UIStyle.IsPhone() and math.max(1, UIStyle.PhoneScale() / math.max(kk, 0.1)) or 1
            for _, t in ipairs({ tip, cmpTip }) do
                local ps = t:FindFirstChild("PhoneScale")
                if ps then ps.Scale = k end
            end
        end
        tipCompare = compare
        FillTip(tip, tipStroke, borderColor, lines)
        tip.Visible = true
        RefreshCompare()
        UI.tipFitIn = 2 -- (QOL2 I6: PlaceTooltip fits it to the screen 2 frames from now)
        if not tipFollow then
            tipFollow = RunService.RenderStepped:Connect(PlaceTooltip)
        end
    end
    function UI.HideTooltip()
        UI.tipAnchor = nil -- (QOL2 I1)
        tip.Visible = false
        cmpTip.Visible = false
        tipCompare = nil
        if tipFollow then tipFollow:Disconnect(); tipFollow = nil end
    end
    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then RefreshCompare() end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then RefreshCompare() end
    end)
    UI.invFrame:GetPropertyChangedSignal("Visible"):Connect(function()
        if not UI.invFrame.Visible then UI.HideTooltip() end
    end)

    local KIND_COLORS = { stat = COL_TEXT, affix = C(120, 200, 255), trait = C(255, 210, 90), note = COL_DIM }

    -- Full tooltip for a weapon or gear piece, with a comparison against what's equipped.
    local function ItemTooltipLines(item: any, isGear: boolean): { any }
        local playerStats = nil
        if not isGear and clientState.EquippedWeapon then
            -- proc chances in the tooltip include your own Proc Chance bonuses
            playerStats = StatCalculator.Calculate(clientState.EquippedWeapon, clientState.AllocatedNodes, 0, clientState.Level, clientState.Attributes, clientState.EquippedGear, clientState.EquippedTitle, clientState.SocketedGems, clientState.RunBoons, clientState)
        end
        local desc = isGear and ItemData.DescribeGear(item) or ItemData.DescribeWeapon(item, playerStats)
        local rColor = ItemData.ItemColor(item)
        local lines = {
            { Text = desc.Title, Color = rColor, Size = 18, Head = true, Rarity = (not ItemData.ExoticOf(item)) and item.Rarity or nil,
                Item = item, SlotKey = isGear and ItemData.GearType(item.Slot) or "Weapon" }, -- (UI CLEAN INV: the card's band + icon)
            { Text = desc.Subtitle, Color = COL_DIM, Size = 13 },
            { Sep = true },
        }
        do -- (UPDATE 8 OFFENSE phase 4) attribute requirements: dim when you meet them, red when you don't
            local rl = ItemData.ReqLine(item, clientState.Level)
            if rl then
                local okA, st = pcall(StatCalculator.Calculate, clientState.EquippedWeapon, clientState.AllocatedNodes, 0, clientState.Level, clientState.Attributes, clientState.EquippedGear, clientState.EquippedTitle, clientState.SocketedGems, clientState.RunBoons, clientState)
                local met = okA and st and ItemData.MeetsReq(item, ItemData.AttrTotals(st), clientState.Level)
                table.insert(lines, 3, { Text = rl .. (met and "" or "  (not met)"), Color = met and COL_DIM or C(240, 100, 100), Size = 12 })
            end
        end
        for _, l in ipairs(desc.Lines) do
            table.insert(lines, { Text = l.Text, RichText = l.RichText, Color = l.Color or KIND_COLORS[l.Kind] or COL_TEXT, Kind = l.Kind, Negative = l.Negative }) -- (UPDATE 8: RichText = coloured sockets; UI CLEAN INV: Kind sorts the card)
        end
        -- comparison
        if not isGear then
            -- WITH YOUR BUILD (owner 2026-10-05: "Ensure that damage buffs from the stat tree directly update the stats of
            -- the weapons"): the lines above are the gun's own rolls; this is the same gun through StatCalculator with your
            -- tree, gear, gems, level, title and run boons -- what it actually does in your hands (same formula as the HUD)
            local function BuildStats(w: any): any
                return StatCalculator.Calculate(w, clientState.AllocatedNodes, 0, clientState.Level, clientState.Attributes, clientState.EquippedGear, clientState.EquippedTitle, clientState.SocketedGems, clientState.RunBoons, clientState)
            end
            local function BuildDps(st: any): number
                return st.Damage * st.FireRate * math.max(1, st.PelletCount or 1) * math.max(1, st.BurstCount or 1) * (1 + st.CritChance * (st.CritMultiplier - 1))
            end
            local okS, mine = pcall(BuildStats, item)
            if okS and mine then
                table.insert(lines, { Sep = true })
                table.insert(lines, { Text = "With your build (tree, gear, gems)", Color = COL_DIM, Size = 13, Cap = true })
                table.insert(lines, { Text = string.format("Damage %s%s  •  %.1f/s  •  Weak-Spot %d%%", ItemData.FormatNumber(mine.Damage), (mine.PelletCount or 1) > 1 and (" x" .. mine.PelletCount) or "", mine.FireRate, math.round(mine.WeakSpotMultiplier * 100)), Color = COL_TEXT, Size = 12 })
                table.insert(lines, { Text = string.format("Crit %d%% (+%d%% dmg)  •  Reload %d%%  •  DPS %s", math.round(mine.CritChance * 100), math.round((mine.CritMultiplier - 1) * 100), math.round(mine.ReloadSpeed * 100), ItemData.FormatNumber(BuildDps(mine))), Color = COL_TEXT, Size = 12 })
            end
            local curr = clientState.EquippedWeapon
            if curr and curr.Uid ~= item.Uid then
                local okC, cs = pcall(BuildStats, curr)
                local diff = (okS and okC and mine and cs) and (BuildDps(mine) - BuildDps(cs)) or (ItemData.CalculateTrueDPS(item) - ItemData.CalculateTrueDPS(curr))
                table.insert(lines, { Sep = true })
                table.insert(lines, {
                    Text = string.format("vs equipped %s: %s%s DPS (your build)", curr.Name, diff >= 0 and "+" or "", ItemData.FormatNumber(diff)),
                    Color = diff >= 0 and C(90, 230, 130) or C(240, 100, 100), Size = 12,
                    Kind = "cmp", CmpLabel = "DPS with your build vs equipped", CmpValue = (diff >= 0 and "+" or "") .. ItemData.FormatNumber(diff), -- (UI CLEAN INV: the strip)
                })
            end
        else
            local gType = ItemData.GearType(item.Slot)
            local eq = clientState.EquippedGear or {}
            local compareTo = (gType == "Ring") and (eq.Ring1 or eq.Ring2) or eq[gType]
            if compareTo and compareTo.Uid ~= item.Uid then
                table.insert(lines, { Sep = true })
                table.insert(lines, { Text = "Equipped: " .. compareTo.Name, Color = COL_DIM, Size = 12 })
                local gain = UI.GearGain and UI.GearGain(item) -- (QOL2 I4: EQUIP BEST's build score with this piece in that slot)
                if gain then
                    table.insert(lines, { Text = string.format("%s%.1f%% vs equipped (EQUIP BEST score)", gain >= 0 and "+" or "", gain * 100), Color = gain >= 0.0005 and C(90, 230, 130) or (gain <= -0.0005 and C(240, 100, 100) or COL_DIM), Size = 12,
                        Kind = "cmp", CmpLabel = "Build score vs equipped", CmpValue = string.format("%s%.1f%%", gain >= 0 and "+" or "", gain * 100) })
                end
                if (item.Armor or 0) > 0 or (compareTo.Armor or 0) > 0 then
                    local d = (item.Armor or 0) - (compareTo.Armor or 0)
                    table.insert(lines, { Text = string.format("Armor %s%d", d >= 0 and "+" or "", math.round(d)), Color = d >= 0 and C(90, 230, 130) or C(240, 100, 100), Size = 12 })
                end
            end
        end
        local sell = isGear and ItemData.GetGearSellValue(item) or ItemData.GetSellValue(item)
        table.insert(lines, { Text = "Sells for " .. sell .. " gold  •  Dismantles into " .. ItemData.DismantleText(item.Rarity), Color = COL_DIM, Size = 11, Kind = "foot" })
        return lines
    end
    -- what an item is compared against: the equipped weapon / the equipped piece in that gear slot (or nil)
    local function EquippedFor(item: any, isGear: boolean): any
        if not isGear then return clientState.EquippedWeapon end
        local gType = ItemData.GearType(item.Slot)
        local eq = clientState.EquippedGear or {}
        if gType == "Ring" then return eq.Ring1 or eq.Ring2 end
        return eq[gType]
    end
    local touchTipToken = nil
    local function HookTooltip(gui: GuiObject, getLines: () -> ({ any }, Color3), compare: any?)
        gui.MouseEnter:Connect(function()
            UI.tipAnchor = nil -- (QOL2 I1: the mouse -> the card follows the cursor again)
            local lines, color = getLines()
            UI.ShowTooltip(color, lines, compare)
            UI.tipLast = { getLines, compare } -- (QOL F3: ALT redraws it with affix ranges)
        end)
        gui.MouseLeave:Connect(function()
            if GameSettings.TouchOnly() then return end -- (touch: the tap below keeps it up for a moment)
            if UI.tipAnchor then return end -- (QOL2 I1: a pad-selected card stays until the selection moves)
            UI.HideTooltip()
        end)
        -- (QOL2 I1 2026-10-28) pad: selecting the row shows its card beside the row (+ the equipped one, no SHIFT needed)
        gui.SelectionGained:Connect(function()
            UI.tipAnchor = gui
            local lines, color = getLines()
            UI.ShowTooltip(color, lines, compare)
            UI.tipLast = { getLines, compare }
        end)
        gui.SelectionLost:Connect(function()
            if UI.tipAnchor == gui then UI.tipLostPad = { gui, os.clock() }; UI.HideTooltip() end
        end)
        -- phones / tablets have no hover: tapping an item shows its stats for a few seconds
        gui.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Touch then return end
            local lines, color = getLines()
            UI.ShowTooltip(color, lines, compare)
            local token = {}
            touchTipToken = token
            task.delay(4, function() if touchTipToken == token and UI.tipAnchor ~= gui then UI.HideTooltip() end end) -- (QOL2 I6: a pinned card stays)
        end)
        -- (QOL2 I6 2026-10-28) gui attr CardPin (the Exchange rows): a click / tap / pad A PINS the card beside the row (clamped to
        -- the screen, flips side); the same again closes it; hovering another row shows that one instead
        if gui:GetAttribute("CardPin") and gui:IsA("GuiButton") then
            (gui :: GuiButton).Activated:Connect(function()
                if UI.tipAnchor == gui and tip.Visible then UI.HideTooltip() return end
                UI.tipAnchor = gui
                local lines, color = getLines()
                UI.ShowTooltip(color, lines, compare)
                UI.tipLast = { getLines, compare }
            end)
        end
    end
    -- (QOL2 I6) a plain text card (shot mods / Riftmods on the Exchange): same hover / tap / pad / pin as an item card
    UI.HookTextCard = function(gui: GuiObject, getLines: () -> ({ any }, Color3))
        gui:SetAttribute("CardPin", true)
        HookTooltip(gui, getLines)
    end
    UI.HookItemCard = function(gui: GuiObject, item: any, isGear: boolean) -- (QOL2 I6: the bag's card + click-to-pin)
        gui:SetAttribute("CardPin", true)
        UI.HookItemTooltip(gui, item, isGear)
    end
    -- (UI CLEAN R-B2) the inventory's item card built INTO another window (the Forge's middle zone): one card per host, refilled
    UI.CardInto = function(host: GuiObject, item: any, isGear: boolean): Frame?
        if not (host and item) then return nil end
        local f = host:FindFirstChild("EmbeddedCard")
        if not f then
            local fr, st = MakeTip("EmbeddedCard")
            fr.Parent = host; fr.AnchorPoint = Vector2.zero; fr.Position = UDim2.new(); fr.ZIndex = 1
            UI.embedStrokes = UI.embedStrokes or {}
            UI.embedStrokes[fr] = st
            f = fr
        end
        FillTip(f, UI.embedStrokes[f], ItemData.ItemColor(item), ItemTooltipLines(item, isGear))
        f.Visible = true
        return f
    end
    UI.HookItemTooltip = function(gui: GuiObject, item: any, isGear: boolean)
        HookTooltip(gui, function()
            local lines = ItemTooltipLines(item, isGear)
            local eq = EquippedFor(item, isGear)
            local padNow = UI.PadMenus and UI.PadMenus.IsPad()
            if UI.tipAnchor ~= nil and padNow then -- (QOL2 I1: a pad selection -- the equipped card already shows beside it)
                table.insert(lines, { Text = "SELECT: affix ranges", Color = C(150, 170, 200), Size = 11, Kind = "foot" })
            elseif UI.tipAnchor ~= nil and not GameSettings.TouchOnly() then -- (QOL2 I6: a card pinned by a click)
                table.insert(lines, { Text = "ALT: affix ranges  •  click again to close", Color = C(150, 170, 200), Size = 11, Kind = "foot" })
            elseif eq and eq.Uid ~= item.Uid and not GameSettings.TouchOnly() then
                table.insert(lines, { Text = "Hold SHIFT to compare with your equipped item  •  ALT: affix ranges", Color = C(150, 170, 200), Size = 11, Kind = "foot" }) -- (QOL F3)
            end
            return lines, ItemData.RarityColors[item.Rarity] or COL_ACCENT
        end, function()
            local eq = EquippedFor(item, isGear)
            if not eq or eq.Uid == item.Uid then return nil end
            return ItemTooltipLines(eq, isGear), ItemData.RarityColors[eq.Rarity] or COL_ACCENT
        end)
    end
    -- (UPDATE 8 OFFENSE, Studio test hook: DevAct "ui:DevItemTip" shows the equipped gun's tooltip -- sockets, types, lines)
    UI.DevItemTip = function()
        local w = clientState.EquippedWeapon
        if w then UI.ShowTooltip(ItemData.RarityColors[w.Rarity] or COL_ACCENT, ItemTooltipLines(w, false)) end
        if w then UI.tipLast = { function() return ItemTooltipLines(w, false), ItemData.RarityColors[w.Rarity] or COL_ACCENT end } end -- (QOL F3: DevAltRanges redraws it)
        local gs = LocalPlayer:GetAttribute("DevTipGear") -- (QOL F3 Studio: attr DevTipGear = an equipped gear slot -> that piece's tooltip)
        local g = type(gs) == "string" and (clientState.EquippedGear or {})[gs] or nil
        if type(g) == "table" then
            UI.tipLast = { function() return ItemTooltipLines(g, true), ItemData.RarityColors[g.Rarity] or COL_ACCENT end } -- (QOL F3)
            UI.ShowTooltip(ItemData.RarityColors[g.Rarity] or COL_ACCENT, ItemTooltipLines(g, true))
        end
    end
    -- (QOL F3 2026-10-28) hold ALT over an item tooltip: every line shows the min-max it can roll at its tier (ItemData.RangeSuffix).
    -- Only redraws on the key press / release while a tooltip is up -- nothing per frame. Studio: Player attr DevAltRanges = true / false.
    ;(function()
        local function Redraw(on: boolean)
            if ItemData.ShowRanges == on then return end
            ItemData.ShowRanges = on
            local last = UI.tipLast
            if tip.Visible and last then
                local lines, color = last[1]()
                UI.ShowTooltip(color, lines, last[2])
            end
        end
        local function IsAlt(input) return input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt end
        UserInputService.InputBegan:Connect(function(input) if IsAlt(input) then Redraw(true) end end)
        UserInputService.InputEnded:Connect(function(input) if IsAlt(input) then Redraw(false) end end)
        -- (QOL2 I1) pad: ButtonSelect TOGGLES the ranges while a card is up (no hold on a pad); closing the inventory resets it.
        -- Studio: DevAct "ui:PadToggleRanges" = the button.
        -- (Roblox's own ButtonSelect toggles pad selection off: the row is re-selected right after, so its card comes back with ranges)
        UI.PadToggleRanges = function()
            local anc, lost = UI.tipAnchor, UI.tipLostPad
            if not anc and lost and os.clock() - lost[2] < 0.3 and lost[1].Parent then anc = lost[1] end
            if not (tip.Visible or anc) then return end
            Redraw(not ItemData.ShowRanges)
            if anc then
                task.delay(0.05, function()
                    local gs = game:GetService("GuiService")
                    if anc.Parent and anc.Visible and gs.SelectedObject ~= anc then pcall(function() gs.SelectedObject = anc end) end
                end)
            end
        end
        UserInputService.InputBegan:Connect(function(input) if input.KeyCode == Enum.KeyCode.ButtonSelect then UI.PadToggleRanges() end end)
        UI.invFrame:GetPropertyChangedSignal("Visible"):Connect(function() if not UI.invFrame.Visible then ItemData.ShowRanges = false end end)
        if RunService:IsStudio() then
            LocalPlayer:GetAttributeChangedSignal("DevAltRanges"):Connect(function() Redraw(LocalPlayer:GetAttribute("DevAltRanges") == true) end)
        end
    end)()

    -- ===== Column 1: CHARACTER =====
    -- (0.84 column split 0.3 / 0.3 / 0.4 -> 0.27 / 0.35 / 0.38: the equipped paper doll had three columns in 30%)
    local charPanel = Panel(UI.invFrame, UDim2.new(0, 12, 0, 42), UDim2.new(0.27, -18, 1, -54), "CHARACTER")
    local levelLbl = Label(charPanel, "", 15, COL_TEXT, Enum.Font.GothamBold); UIStyle.TextRole(levelLbl, "Value")
    levelLbl.Size = UDim2.new(1, -20, 0, 18); levelLbl.Position = UDim2.new(0, 10, 0, 30)
    local pointsLbl = Label(charPanel, "", 13, C(255, 215, 90), Enum.Font.GothamBold); UIStyle.TextRole(pointsLbl, "Meta")
    pointsLbl.Size = UDim2.new(1, -90, 0, 16); pointsLbl.Position = UDim2.new(0, 10, 0, 48)
    if false then -- (UPDATE 8 OFFENSE phase 4: no hand-placed attributes, no RESET) RESET: refund every attribute point
        local rb = SmallButton(charPanel, "RESET", C(60, 64, 74), 66)
        rb.Name = "ResetAttributes"; rb.Size = UDim2.fromOffset(66, 18); rb.Position = UDim2.new(1, -76, 0, 47); rb.TextSize = 11
        local armedAt = 0
        rb.MouseButton1Click:Connect(function()
            SoundHelper.Play("Click")
            if os.clock() - armedAt > 3 then
                armedAt = os.clock(); rb.Text = "CONFIRM?"; rb.BackgroundColor3 = C(190, 60, 50)
                task.delay(3, function() if os.clock() - armedAt >= 2.9 then rb.Text = "RESET"; rb.BackgroundColor3 = C(60, 64, 74) end end)
                return
            end
            armedAt = 0; rb.Text = "RESET"; rb.BackgroundColor3 = C(60, 64, 74)
            local ok = Remotes.GetFunction("ResetAttributes"):InvokeServer()
            if ok then
                SoundHelper.Play("Upgrade")
                if RefreshInventory then RefreshInventory() end
                UpdateWeaponHUD()
            end
        end)
        HookTooltip(rb, function()
            return { { Text = "Reset Attributes", Size = 15, Bold = true }, { Text = "Free. Every point you put into Strength, Dexterity, Vitality and Luck comes back to spend again.", Color = COL_DIM } }, COL_ACCENT
        end)
    end

    -- AMOUNT BOX (owner 2026-10-05: "the game lags when spam adding into attributes. Add a little box to input how many
    -- attributes you want to add"): every + spends this many points in one request (capped at what you have)
    local amountBox = Instance.new("TextBox")
    amountBox.Name = "AttrAmount"; amountBox.Size = UDim2.fromOffset(46, 18); amountBox.Position = UDim2.new(1, -128, 0, 47)
    amountBox.BackgroundColor3 = C(30, 33, 40); amountBox.BorderSizePixel = 0; amountBox.TextColor3 = COL_TEXT
    amountBox.Font = Enum.Font.GothamBold; amountBox.TextSize = 12; amountBox.Text = "1"; amountBox.PlaceholderText = "1"
    amountBox.ClearTextOnFocus = true; amountBox.Parent = charPanel
    amountBox.Visible = false -- (UPDATE 8 phase 4: no points to spend)
    RoundCorners(amountBox, 4)
    local amtLbl = Label(charPanel, "x", 11, COL_DIM, Enum.Font.GothamBold)
    amtLbl.Size = UDim2.fromOffset(10, 18); amtLbl.Position = UDim2.new(1, -140, 0, 47); amtLbl.Visible = false
    amountBox.FocusLost:Connect(function()
        local v = math.floor(tonumber(amountBox.Text) or 1)
        amountBox.Text = tostring(math.max(1, v))
    end)
    HookTooltip(amountBox, function()
        return { { Text = "Points per click", Size = 15, Bold = true }, { Text = "Each + spends this many attribute points at once (up to what you have).", Color = COL_DIM } }, COL_ACCENT
    end)
    local allocBusy = false
    local ATTRS = { "Strength", "Dexterity", "Intellect" } -- (UPDATE 8 phase 4: read-only totals from the tree + gear)
    local attrRows = {}
    for i, attr in ipairs(ATTRS) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -20, 0, 26)
        row.Position = UDim2.new(0, 10, 0, 68 + (i - 1) * 29)
        row.BackgroundColor3 = COL_ROW
        row.BackgroundTransparency = 1 -- (UI CLEAN: label left, value right, no slab)
        row.Parent = charPanel
        local l = Label(row, attr, 14, COL_DIM, Enum.Font.GothamMedium); UIStyle.TextRole(l, "Label")
        l.Size = UDim2.new(0.5, 0, 1, 0); l.Position = UDim2.new(0, 0, 0, 0)
        local val = Label(row, "", 18, COL_TEXT, Enum.Font.GothamBlack, Enum.TextXAlignment.Right)
        val.Name = "Value"; UIStyle.TextRole(val, "Value")
        val.Size = UDim2.new(0.5, 0, 1, 0); val.Position = UDim2.new(0.5, 0, 0, 0)
        local plus = SmallButton(row, "+", C(0, 170, 100), 26)
        plus.Position = UDim2.new(1, -30, 0, 1)
        plus.TextSize = 16
        plus.MouseButton1Click:Connect(function()
            if allocBusy then return end -- (one request at a time: spam clicks queued dozens of full syncs)
            allocBusy = true
            SoundHelper.Play("Click")
            local n = math.max(1, math.floor(tonumber(amountBox.Text) or 1))
            local ok = Remotes.GetFunction("AllocateStatPoint"):InvokeServer(attr, n)
            allocBusy = false
            if ok then SoundHelper.Play("Upgrade") end -- (the server's state sync refreshes the panel + HUD)
        end)
        HookTooltip(row, function()
            local def = ItemData.StatDefs[attr]
            return { { Text = attr, Size = 15, Bold = true }, { Text = def and def.Desc or "", Color = COL_DIM } }, COL_ACCENT
        end)
        attrRows[attr] = { Label = l, Plus = plus, Value = val }
    end

    local statsScroll = Instance.new("ScrollingFrame")
    statsScroll.Position = UDim2.new(0, 10, 0, 68 + 3 * 29 + 6)
    statsScroll.Size = UDim2.new(1, -20, 1, -(68 + 3 * 29 + 16))
    statsScroll.BackgroundTransparency = 1
    statsScroll.BorderSizePixel = 0
    statsScroll.ScrollBarThickness = 4
    statsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    statsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    statsScroll.Parent = charPanel
    local statsList = Instance.new("UIListLayout")
    statsList.Padding = UDim.new(0, 2)
    statsList.SortOrder = Enum.SortOrder.LayoutOrder
    statsList.Parent = statsScroll

    -- ===== LIFETIME STATS (Update 5, owner: "Add some simple stats somewhere (kills, headshot kills, deaths etc)") =====
    -- a SHEET | STATS switch in the CHARACTER header; STATS covers the column with your record (server-counted, see
    -- CombatServer.Life). Refreshed with the inventory (UI.RefreshLifeStats) and when the tab opens.
    ;(function()
        local S = UIStyle.Colors
        local seg = Instance.new("Frame")
        seg.Name = "SheetSwitch"
        seg.AnchorPoint = Vector2.new(1, 0)
        seg.Position = UDim2.new(1, -8, 0, 5)
        seg.Size = UDim2.fromOffset(146, 24)
        seg.BackgroundTransparency = 1
        seg:SetAttribute("NoSkin", true)
        seg.ZIndex = 6
        seg.Parent = charPanel
        local bSheet = UIStyle.Button(seg, "SHEET", S.Bg1, UDim2.fromOffset(70, 24), UDim2.new(0, 0, 0, 0), "Sheet")
        local bStats = UIStyle.Button(seg, "STATS", S.Bg1, UDim2.fromOffset(70, 24), UDim2.new(0, 76, 0, 0), "Stats")
        bSheet.SetQuiet(true); bStats.SetQuiet(true) -- (UI CLEAN: word tabs, the accent underline marks the open one)
        bSheet.SetSelected(true) -- (UI v4 NEON)
        bSheet.Label.TextSize = 15; bStats.Label.TextSize = 15 -- (UI CLEAN P4: the Tab role)
        bSheet.Label:SetAttribute("TextRole", "Tab"); bStats.Label:SetAttribute("TextRole", "Tab")

        local life = Instance.new("ScrollingFrame")
        life.Name = "LifetimeStats"
        life.Position = UDim2.new(0, 0, 0, 34)
        life.Size = UDim2.new(1, 0, 1, -34)
        life.BackgroundColor3 = COL_PANEL
        life.BorderSizePixel = 0
        life.ZIndex = 5
        life.Visible = false
        life.AutomaticCanvasSize = Enum.AutomaticSize.Y
        life.CanvasSize = UDim2.new()
        life.ScrollingDirection = Enum.ScrollingDirection.Y
        life:SetAttribute("NoSkin", true)
        UIStyle.StyleScroll(life, 4)
        life.Parent = charPanel
        local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 14); pad.PaddingBottom = UDim.new(0, 10); pad.Parent = life
        local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 2); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = life

        local order = 0
        local function Next() order += 1; return order end
        local rows = {}
        local zebra = false
        local function Header(text: string)
            zebra = false
            local h = UIStyle.SectionHeader(life, text, { Height = 30, LayoutOrder = Next() })
            h.ZIndex = 6
            for _, d in ipairs(h:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex = 6 end end
        end
        local function Row(key: string, label: string, tip: string)
            zebra = not zebra
            local r = UIStyle.StatRow(life, label, "0", { Height = 28, LayoutOrder = Next() }) -- (P4: role sizes, no zebra slabs)
            r.ZIndex = 6
            for _, d in ipairs(r:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex = 6 end end
            rows[key] = r:FindFirstChild("Value")
            HookTooltip(r, function() return { { Text = label, Size = 15, Bold = true }, { Text = tip, Color = COL_DIM } }, COL_ACCENT end)
        end
        Header("Combat")
        Row("Kills", "Kills", "Every enemy killed in your runs, maps and trials (in a party each member counts the party's kills).")
        Row("WeakKills", "Weak-spot kills", "Kills where the final hit landed on a weak spot (head or core). Counted from Update 5 on.")
        Row("WeakPct", "Weak-spot kill rate", "Your own killing blows that landed on a weak spot, as a share of all your killing blows (from Update 5 on).")
        Row("Elites", "Elite kills", "Elite enemies (the ones with modifiers) you have killed.")
        Row("Bosses", "Boss kills", "Floor bosses, superbosses and trial bosses.")
        Row("Melee", "Melee kills", "Kills with your melee weapon.")
        Row("Deaths", "Deaths", "Lives lost in runs. Counted from Update 5 on.")
        Row("KD", "Kills per death", "Your own killing blows divided by deaths, both counted from Update 5 on.")
        Header("Aim")
        Row("Accuracy", "Accuracy", "Trigger pulls in runs that hit an enemy (a shotgun blast that lands any pellet counts as a hit). Counted from Update 5 on.")
        Row("Shots", "Shots fired", "Trigger pulls in runs. Counted from Update 5 on.")
        Row("Streak", "Best focus streak", "Your highest focus streak (hits in a row without missing).")
        Row("HsRun", "Best weak-spot chain", "The most weak-spot hits you have landed in a row.")
        Header("Runs")
        Row("Runs", "Runs started", "Solo and party runs. Counted from Update 5 on.")
        Row("Cleared", "Runs cleared", "Runs you finished to the last floor. Counted from Update 5 on.")
        Row("Floors", "Floors cleared", "Every floor you have cleared. Counted from Update 5 on.")
        Row("Highest", "Highest floor", "The deepest floor you have cleared on any difficulty.")
        Row("Fastest", "Fastest floor", "Your quickest floor clear.")
        Header("Duels")
        Row("Duels", "Duels won / lost", "Your duel record against other players.")
        Header("Time")
        Row("Time", "Time played", "Time in the game, saved every minute and a half. Counted from Update 5 on.")
        local note = UIStyle.Text({ Name = "Note", Text = "Weak-spot kills, deaths, accuracy, runs, floors and time played count from Update 5 on: older play wasn't recorded.", Font = UIStyle.BodyFont, TextSize = 13,
            TextColor3 = S.Muted, TextWrapped = true, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = Next(), ZIndex = 6, Parent = life })
        UIStyle.TextRole(note, "Meta")

        local FN = ItemData.FormatNumber
        local function Dur(sec: number): string
            sec = math.max(0, math.floor(sec))
            local h, m = math.floor(sec / 3600), math.floor(sec % 3600 / 60)
            if h > 0 then return string.format("%dh %02dm", h, m) end
            return string.format("%dm %02ds", m, sec % 60)
        end
        UI.RefreshLifeStats = function()
            if not life.Visible then return end
            local st = clientState.StatsTracking or {}
            local function N(k) return tonumber(st[k]) or 0 end
            local kills, own, wk, deaths = N("TotalKills"), N("OwnKills"), N("WeakSpotKills"), N("Deaths")
            rows.Kills.Text = FN(kills)
            rows.WeakKills.Text = FN(wk)
            rows.WeakPct.Text = (own > 0) and string.format("%.1f%%", 100 * wk / own) or "-"
            rows.Elites.Text = FN(N("EliteKills"))
            rows.Bosses.Text = FN(N("BossKills"))
            rows.Melee.Text = FN(N("MeleeKills"))
            rows.Deaths.Text = FN(deaths)
            rows.KD.Text = (deaths > 0) and string.format("%.2f", own / deaths) or ((own > 0) and "No deaths" or "-")
            local shots, hits = N("Shots"), N("Hits")
            rows.Accuracy.Text = (shots > 0) and string.format("%.1f%%", 100 * hits / shots) or "-"
            rows.Shots.Text = FN(shots)
            rows.Streak.Text = FN(N("BestStreak"))
            rows.HsRun.Text = FN(N("BestHeadshotRun"))
            rows.Runs.Text = FN(N("Runs"))
            rows.Cleared.Text = FN(N("RunsCleared"))
            rows.Floors.Text = FN(N("FloorsCleared"))
            rows.Highest.Text = (N("HighestFloorCleared") > 0) and ("Floor " .. N("HighestFloorCleared")) or "-"
            local fast = tonumber(st.FastestFloorClearSeconds)
            rows.Fastest.Text = (fast and fast < 1e8) and Dur(fast) or "-"
            local pv = type(clientState.PvpStats) == "table" and clientState.PvpStats or {}
            rows.Duels.Text = string.format("%s / %s", FN(tonumber(pv.W) or 0), FN(tonumber(pv.L) or 0))
            rows.Time.Text = Dur(N("PlaySeconds"))
        end
        local function Show(stats: boolean)
            life.Visible = stats
            bSheet.SetSelected(not stats) -- (UI v4 NEON)
            bStats.SetSelected(stats)
            if stats then UI.RefreshLifeStats() end
        end
        bSheet.Button.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); Show(false) end)
        bStats.Button.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); Show(true) end)
        UI.ShowLifeStats = Show
    end)()

    -- ===== Column 2: EQUIPPED =====
    local eqPanel = Panel(UI.invFrame, UDim2.new(0.27, 0, 0, 42), UDim2.new(0.35, -12, 1, -54), "EQUIPPED")
    -- (owner 2026-10-04: "equip best needs to be repositioned as it currently overlaps" -- it sat on the window's title bar)
    -- EQUIP BEST + its build dropdown live in the EQUIPPED column's header now
    btnBest.Parent = eqPanel; btnBest.AnchorPoint = Vector2.new(1, 0)
    btnBest.Size = UDim2.fromOffset(176, 24); btnBest.Position = UDim2.new(1, -40, 0, 5); UIStyle.TextRole(btnBest, "Button", { Keep = true })
    btnDrop.Parent = eqPanel; btnDrop.AnchorPoint = Vector2.new(1, 0)
    btnDrop.Size = UDim2.fromOffset(28, 24); btnDrop.Position = UDim2.new(1, -8, 0, 5)
    list.Parent = eqPanel; list.AnchorPoint = Vector2.new(1, 0); list.Position = UDim2.new(1, -8, 0, 34)
    local eqHolder = Instance.new("Frame")
    eqHolder.Position = UDim2.new(0, 10, 0, 32)
    eqHolder.Size = UDim2.new(1, -20, 1, -40)
    eqHolder.BackgroundTransparency = 1
    eqHolder.Parent = eqPanel
    -- LOADOUT (UI CLEAN INV 2026-10-28, the owner's accepted target docs/ui_target/inventory_target.html): 2 x 5 IDENTICAL slot
    -- cards (InvLayout.SlotCard), the gun included -- slot label, name in the rarity colour, one stat line, the icon in a reserved
    -- right area (never under the name). Same slot objects + clicks as before (UI.paperSlots); TOTAL DPS / defence / title moved
    -- to the left column (InvLayout.Identity).
    do
        UI.paperSlots = {}
        local IL = require(sharedFolder:WaitForChild("InvLayout"))
        local ORDER = { { "Weapon", "GUN" }, { "Melee", "MELEE" }, { "Helmet", "HELMET" }, { "ChestPiece", "CHEST" }, { "Leggings", "LEGS" },
            { "Gloves", "GLOVES" }, { "Boots", "BOOTS" }, { "Necklace", "AMULET" }, { "Ring1", "RING" }, { "Ring2", "RING" } }
        local grid = Instance.new("UIGridLayout")
        grid.CellSize = UDim2.new(0.5, -4, 0, IL.SLOT_H); grid.CellPadding = UDim2.fromOffset(8, 8); grid.SortOrder = Enum.SortOrder.LayoutOrder
        grid.Parent = eqHolder
        for i, row in ipairs(ORDER) do
            local key, label = row[1], row[2]
            local slot = IL.SlotCard(eqHolder, key, label)
            slot.Btn.LayoutOrder = i
            UI.paperSlots[key] = slot
            local b, x = slot.Btn, slot.X
            if key == "Weapon" or ItemData.GearSlotLabels[key] then
                HookTooltip(b, function()
                    local it = slot.Item
                    if not it then return { { Text = label .. ": empty", Bold = true, Size = 14 }, { Text = "Click to open the " .. (key == "Weapon" and "weapon" or "gear") .. " bag.", Color = COL_DIM } }, COL_ACCENT end
                    return ItemTooltipLines(it, key ~= "Weapon"), ItemData.RarityColors[it.Rarity] or COL_ACCENT
                end)
            end
            if ItemData.GearSlotLabels[key] then
                x.MouseButton1Click:Connect(function()
                    SoundHelper.Play("Click")
                    Remotes.GetFunction("UnequipGear"):InvokeServer(key)
                end)
                b.MouseButton1Click:Connect(function() if UI.ShowStashTab then UI.ShowStashTab("Gear") end end)
            elseif key == "Weapon" then
                b.MouseButton1Click:Connect(function() if UI.ShowStashTab then UI.ShowStashTab("Weapons") end end)
            end
        end
    end

    -- ===== Column 3: STASH =====
    -- (2026-10-07: the carried list is the BAG now -- 60 items, ItemData.BAG_CAP; the STASH lives in your hideout and its
    -- tab shows while you're home. A search box filters every list by name, gun, type, rarity or stat.)
    local stashPanel = Panel(UI.invFrame, UDim2.new(0.62, 0, 0, 42), UDim2.new(0.38, -12, 1, -54), "BAG")
    local tabW = SmallButton(stashPanel, "WEAPONS", C(40, 60, 90), 110)
    tabW.Position = UDim2.new(0, 10, 0, 32)
    tabW.Size = UDim2.new(0.23, -10, 0, 38)
    local tabG = SmallButton(stashPanel, "GEAR", C(25, 30, 42), 110)
    tabG.Position = UDim2.new(0.23, 2, 0, 32)
    tabG.Size = UDim2.new(0.17, -4, 0, 38)
    -- (0.75, owner: "In the inventory, have another bag for materials and gems and other misc items")
    UI.invTabI = SmallButton(stashPanel, "ITEMS", C(25, 30, 42), 110)
    UI.invTabI.Position = UDim2.new(0.40, 0, 0, 32)
    UI.invTabI.Size = UDim2.new(0.14, -4, 0, 38)
    UI.invTabS = SmallButton(stashPanel, "STASH", C(25, 30, 42), 110)
    UI.invTabS.Position = UDim2.new(0.54, 0, 0, 32)
    UI.invTabS.Size = UDim2.new(0.18, -6, 0, 38)
    for _, t in ipairs({ tabW, tabG, UI.invTabI, UI.invTabS }) do -- (UI v4 NEON: text tabs, the underline marks the open one)
        t.BackgroundTransparency = 1; t.AutoButtonColor = false; t.TextColor3 = UIStyle.Colors.Sub
    end
    local sortBtn = SmallButton(stashPanel, "SORT: RARITY", UIStyle.Colors.Steel, 118) -- (UI CLEAN: quiet secondary)
    sortBtn.Position = UDim2.new(0.72, 0, 0, 36)
    sortBtn.Size = UDim2.new(0.28, -10, 0, 30)
    do -- (UI CLEAN P4: the tabs are words in a row at their own width -- one size, no shrinking -- on the column's inset)
        local tabRow = Instance.new("Frame")
        tabRow.Name = "TabRow"; tabRow.BackgroundTransparency = 1; tabRow.Position = UDim2.new(0, 10, 0, 32); tabRow.Size = UDim2.new(0.72, -14, 0, 38)
        tabRow.Parent = stashPanel
        local tl = Instance.new("UIListLayout"); tl.FillDirection = Enum.FillDirection.Horizontal; tl.Padding = UDim.new(0, 18)
        tl.SortOrder = Enum.SortOrder.LayoutOrder; tl.VerticalAlignment = Enum.VerticalAlignment.Center; tl.Parent = tabRow
        for i, b in ipairs({ tabW, tabG, UI.invTabI, UI.invTabS }) do
            b.Parent = tabRow; b.LayoutOrder = i
            b.TextScaled = false; b.AutomaticSize = Enum.AutomaticSize.X; b.Size = UDim2.new(0, 0, 0, 38)
            b.TextXAlignment = Enum.TextXAlignment.Left
            UIStyle.TextRole(b, "Tab", { Keep = true })
        end
        sortBtn.TextScaled = true
        local lim = Instance.new("UITextSizeConstraint"); lim.MaxTextSize = 14; lim.MinTextSize = 10; lim.Parent = sortBtn
        local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 4); pad.PaddingRight = UDim.new(0, 4); pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 4); pad.Parent = sortBtn
        UIStyle.TextRole(sortBtn, "Button", { Keep = true })
    end

    local sellBar = Instance.new("Frame")
    sellBar.Position = UDim2.new(0, 10, 0, 76)
    sellBar.Size = UDim2.new(1, -20, 0, 30) -- (0.84: 24 -> 30)
    sellBar.BackgroundTransparency = 1
    sellBar.Parent = stashPanel
    local sellList = Instance.new("UIListLayout")
    sellList.FillDirection = Enum.FillDirection.Horizontal
    sellList.Padding = UDim.new(0, 6)
    sellList.Parent = sellBar
    -- Four equal columns that always fit the panel (fixed pixel widths overflowed it at smaller sizes).
    local function FitBar(b: TextButton)
        b.Size = UDim2.new(0.25, -5, 0, 30)
        b.TextScaled = true
        local lim = Instance.new("UITextSizeConstraint")
        lim.MaxTextSize = 14 -- (UI CLEAN P4: the Button role)
        lim.MinTextSize = 9
        lim.Parent = b
        b:SetAttribute("TextRole", "Button")
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 4); pad.PaddingRight = UDim.new(0, 4)
        pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 4)
        pad.Parent = b
    end
    -- (0.58, owner: "Auto sell needs to go up to a higher rarity (with a confirm popup before allowing you to go through with
    -- higher rarities), and the sell button should be one button with a drop down allowing you to sell up to X rarity"):
    -- AUTO-SELL and SELL UP TO are two pickers (PopupUI dropdowns), any rarity up to Genesis (never Infinite); from
    -- Legendary up a confirm popup comes first
    UI.PopupUI = UI.PopupUI or require(sharedFolder:WaitForChild("PopupUI"))
    local btnAutoSell = SmallButton(sellBar, "AUTO-SELL: OFF ▼", UIStyle.Colors.Steel, 128)
    FitBar(btnAutoSell)
    btnAutoSell.Size = UDim2.new(0.5, -3, 0, 30)
    local thresholds = { "OFF" }
    for i, r in ipairs(ItemData.Rarities) do if i <= 4 then table.insert(thresholds, r) end end -- (UPDATE 8 RARITY v4: Common .. Mythic; Relics never)
    UI.RarityPick = function(anchor: GuiObject, list: { string }, onPick: (string) -> (), what: string?) -- (what = "gems")
        local items = {}
        for _, r in ipairs(list) do
            table.insert(items, { Text = (r == "OFF") and "OFF" or string.upper(r), Color = ItemData.RarityColors[r] or COL_DIM, Value = r })
        end
        UI.PopupUI.Dropdown(anchor, items, function(r)
            -- (say what it means first -- items from Rare up, gems (old ladder) from Legendary up; UPDATE 8 RARITY v4)
            if (what == "gems" and (ItemData.RarityRank[r] or 0) >= ItemData.RarityRank.Mythic) or (what ~= "gems" and (ItemData.RarityRank[r] or 0) >= ItemData.RarityRank.Rare) then
                UI.PopupUI.Confirm("Are you sure?", (what == "gems")
                    and ("This includes " .. string.upper(r) .. " gems and everything below them. Salvaged gems turn into materials and can't be recovered.")
                    or ("This includes " .. string.upper(r) .. " items and everything below them. Only the last 10 items you sell can be bought back (BUYBACK, this session)."), -- (QOL2 I3)
                    "YES, " .. string.upper(r), ItemData.RarityColors[r] or COL_ACCENT, function() onPick(r) end)
            else
                onPick(r)
            end
        end)
    end
    -- (2026-11-09 AUTO-SELL FILTER, owner: "a more in depth filter for auto sell aside from rarity (panel that opens up ...)"): the
    -- picker became a panel (AimRngShared/AutoSellRules: the rarity + KEEP rules by sockets / links / item level / type / stats, a
    -- bag preview, SAVE -> SetAutoSellThreshold(threshold, rules); the server cleans the rules). Studio: Player attr DevAutoSell =
    -- "open" | "close" | "save" | "rarity:<R>" | "rules:<JSON>" (sets the open panel's draft) -> DevAutoSellResult.
    UI.PickAutoSell = function(anchor: GuiObject) -- (UI CLEAN INV: the bag's SELL menu calls it too)
        local AR = require(sharedFolder:WaitForChild("AutoSellRules"))
        AR.Open({
            Parent = hudGui,
            State = function() return clientState end,
            Save = function(th, rules)
                local ok = Remotes.GetFunction("SetAutoSellThreshold"):InvokeServer(th, rules)
                if ok then
                    clientState.AutoSellThreshold = th
                    clientState.AutoSellRules = AR.Clean(rules)
                    btnAutoSell.Text = "AUTO-SELL: " .. AR.Short(th, clientState.AutoSellRules) .. " ▼"
                end
                return ok, ok and ("Auto-sell: " .. AR.Short(th, clientState.AutoSellRules)) or "Couldn't save auto-sell."
            end,
            Toast = function(t) ShowToast(t) end,
            Click = function() SoundHelper.Play("Click") end,
            Tip = function(gui, fn) HookTooltip(gui, fn) end,
            CloseWith = UI.invFrame,
        })
    end
    if RunService:IsStudio() then
        LocalPlayer:GetAttributeChangedSignal("DevAutoSell"):Connect(function()
            local v = tostring(LocalPlayer:GetAttribute("DevAutoSell") or "")
            if v == "" then return end
            local AR = require(sharedFolder:WaitForChild("AutoSellRules"))
            local res = "ok"
            local okP, err = pcall(function()
                if v == "open" then UI.PickAutoSell(btnAutoSell)
                elseif v == "close" then AR.Close()
                else
                    local cur = AR.Current()
                    if not cur then res = "not open" return end
                    if v == "save" then cur.Save()
                    elseif string.sub(v, 1, 7) == "rarity:" then cur.SetThreshold(string.sub(v, 8))
                    elseif string.sub(v, 1, 6) == "rules:" then
                        local t = game:GetService("HttpService"):JSONDecode(string.sub(v, 7))
                        for k in pairs(cur.Draft) do cur.Draft[k] = nil end
                        for k, x in pairs(t) do cur.Draft[k] = x end
                        cur.Draft.MinSockets, cur.Draft.MinLinks, cur.Draft.MinIlvl = cur.Draft.MinSockets or 0, cur.Draft.MinLinks or 0, cur.Draft.MinIlvl or 0
                        cur.Draft.Types, cur.Draft.Stats, cur.Draft.StatCount = cur.Draft.Types or {}, cur.Draft.Stats or {}, cur.Draft.StatCount or 1
                        cur.Render()
                    end
                end
            end)
            LocalPlayer:SetAttribute("DevAutoSellResult", okP and res or ("error " .. tostring(err)))
            LocalPlayer:SetAttribute("DevAutoSell", "")
        end)
    end
    btnAutoSell.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); UI.PickAutoSell(btnAutoSell) end)
    HookTooltip(btnAutoSell, function()
        return { { Text = "Auto-Sell (guns + gear)", Bold = true, Size = 14 }, { Text = "New weapon and gear drops at or below this rarity are sold for gold automatically, unless a KEEP rule (sockets, links, item level, type, stats) matches. Gems have their own setting on the ITEMS tab.", Color = COL_DIM } }, COL_ACCENT
    end)
    -- (0.84, owner: "Gem auto selling is broken, and seems to conflict with the weapon one. They need to be two separate
    -- mechanisms"): the ITEMS tab (where gems live) showed the WEAPON auto-sell, so setting it there changed guns + gear,
    -- not gems (the gem setting only lived in the Skill Tree's gem window). The ITEMS tab now has its own GEM
    -- AUTO-SALVAGE picker in that bar (state.GemAutoSalvage, SetGemAutoSalvage); the gun + gear pair shows on the others.
    UI.gemThresholds = { "OFF", "Common", "Uncommon", "Rare", "Mythic" } -- (UPDATE 8 GEM GRADES v4: the 5 rarities; Relic gems never)
    UI.btnGemAuto = SmallButton(sellBar, "GEM AUTO-SALVAGE: OFF ▼", UIStyle.Colors.Steel, 128)
    FitBar(UI.btnGemAuto)
    UI.btnGemAuto.Size = UDim2.new(0.5, -3, 0, 30) -- (2026-10-14: shares the ITEMS bar with SALVAGE GEMS UP TO)
    UI.btnGemAuto.Visible = false
    HookTooltip(UI.btnGemAuto, function()
        return { { Text = "Gem Auto-Salvage", Bold = true, Size = 14 }, { Text = "New GEMS at or below this rarity salvage into materials as they drop. Separate from the gun + gear auto-sell.", Color = COL_DIM } }, C(170, 150, 220)
    end)
    UI.PickGemAuto = function(anchor: GuiObject) -- (UI CLEAN INV: the bag's SELL menu calls it too)
        UI.RarityPick(anchor, UI.gemThresholds, function(r)
            clientState.GemAutoSalvage = r
            UI.btnGemAuto.Text = "GEM AUTO-SALVAGE: " .. string.upper(r) .. " ▼"
            Remotes.GetFunction("SetGemAutoSalvage"):InvokeServer(r)
            ShowToast("Gem auto-salvage: " .. r .. (r ~= "OFF" and " and below" or ""))
        end, "gems")
    end
    UI.btnGemAuto.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); UI.PickGemAuto(UI.btnGemAuto) end)
    -- (2026-10-14, owner: "Gems need a sell up to x rarity button"): every bag gem at or below the rarity -> materials
    -- (socketed + locked gems stay; SkillTreeServer SalvageGem("*UpTo", rarity))
    UI.btnGemSalvage = SmallButton(sellBar, "SALVAGE GEMS UP TO ▼", UIStyle.Colors.Steel, 118)
    FitBar(UI.btnGemSalvage)
    UI.btnGemSalvage.Size = UDim2.new(0.5, -3, 0, 30)
    UI.btnGemSalvage.Visible = false
    HookTooltip(UI.btnGemSalvage, function()
        return { { Text = "Salvage gems up to a rarity", Bold = true, Size = 14 }, { Text = "Salvages every gem in your bag at or below the rarity you pick into materials. Socketed and locked gems are kept.", Color = COL_DIM } }, C(170, 150, 220)
    end)
    UI.PickGemSalvage = function(anchor: GuiObject) -- (UI CLEAN INV: the bag's SELL menu calls it too)
        UI.RarityPick(anchor, { table.unpack(UI.gemThresholds, 2) }, function(r)
            local ok, msg = Remotes.GetFunction("SalvageGem"):InvokeServer("*UpTo", r)
            if ok then SoundHelper.Play("Coin") end
            ShowToast(tostring(msg or ""))
            RefreshInventory()
        end, "gems")
    end
    UI.btnGemSalvage.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); UI.PickGemSalvage(UI.btnGemSalvage) end)
    UI.btnSellUpTo = SmallButton(sellBar, "SELL UP TO ▼", UIStyle.Colors.Steel, 118)
    FitBar(UI.btnSellUpTo)
    UI.btnSellUpTo.Size = UDim2.new(0.5, -3, 0, 30)
    HookTooltip(UI.btnSellUpTo, function()
        return { { Text = "Sell up to a rarity", Bold = true, Size = 14 }, { Text = "Sells every unequipped item in your bag (weapons and gear) at or below the rarity you pick.", Color = COL_DIM } }, COL_ACCENT
    end)
    UI.PickSellUpTo = function(anchor: GuiObject) -- (UI CLEAN INV: the bag's SELL menu calls it too)
        UI.RarityPick(anchor, { table.unpack(thresholds, 2) }, function(r)
            SoundHelper.Play("Coin")
            local count, g = Remotes.GetFunction("QuickSellRarity"):InvokeServer(r, "AllUpTo")
            ShowToast(string.format("Sold %d items (%s and below) for +%s gold", count or 0, r, ItemData.FormatNumber(g or 0)))
            RefreshInventory()
        end)
    end
    UI.btnSellUpTo.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); UI.PickSellUpTo(UI.btnSellUpTo) end)
    ;(function() -- QOL L7 (2026-10-28): STASH UP TO (in your hideout, beside SELL UP TO) + ctrl-click a row = bag <-> stash
        local b = SmallButton(sellBar, "STASH UP TO ▼", UIStyle.Colors.Steel, 118)
        FitBar(b)
        b.Visible = false
        UI.btnStashUpTo = b
        HookTooltip(b, function()
            return { { Text = "Stash up to a rarity", Bold = true, Size = 14 }, { Text = "Moves every unequipped item in your bag (weapons and gear) at or below the rarity you pick into the stash tab you have open, until it's full. Locked items stay in the bag. Tip: ctrl-click any row to move just that item between bag and stash.", Color = COL_DIM } }, C(255, 200, 90)
        end)
        UI.PickStashUpTo = function(anchor: GuiObject) -- (UI CLEAN INV: the bag's SELL menu)
            local list = {}
            for _, r in ipairs(ItemData.Rarities) do
                table.insert(list, { Text = string.upper(r) .. " AND BELOW", Color = ItemData.RarityColors[r] or COL_DIM, Value = r })
            end
            UI.PopupUI.Dropdown(anchor, list, function(r)
                local tab = (UI.stashTab and UI.stashTab ~= "SKINS") and UI.stashTab or "STASH"
                local ok, msg = Remotes.GetFunction("HideoutAction"):InvokeServer("StoreUpTo", r, tab)
                if msg then ShowToast(tostring(msg)) end
                if ok then RefreshInventory() end
            end)
        end
        b.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); UI.PickStashUpTo(b) end)
        -- the three sell-bar buttons share the row at home (thirds); elsewhere STASH UP TO is hidden (halves, as before)
        UI.LayoutStashUpTo = function(itemsTab: boolean, home: boolean)
            local on = home and not itemsTab
            b.Visible = on
            local w = on and UDim2.new(1 / 3, -4, 0, 30) or UDim2.new(0.5, -3, 0, 30)
            btnAutoSell.Size = w
            UI.btnSellUpTo.Size = w
        end
        local busy = false
        UI.RowCtrlClick = function(row: GuiButton, item: any, isGear: boolean)
            if not item or not item.Uid or item.Uid == "W_STARTER_PISTOL" then return end
            row.MouseButton1Click:Connect(function()
                if busy then return end
                if not (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then return end
                if not (UI.InOwnHideout and UI.InOwnHideout()) then ShowToast("Your stash is in your hideout: ctrl-click moves items there."); return end
                local inBag = false
                for _, it in ipairs((isGear and clientState.GearInventory or clientState.Inventory) or {}) do
                    if it.Uid == item.Uid then inBag = true; break end
                end
                local tab = (UI.stashTab and UI.stashTab ~= "SKINS") and UI.stashTab or "STASH"
                busy = true
                SoundHelper.Play("Click")
                local ok, why = Remotes.GetFunction("HideoutAction"):InvokeServer(inBag and "Store" or "Take", item.Uid, isGear and "Gear" or "Weapon", tab)
                busy = false
                if not ok and why then ShowToast(tostring(why)) end
            end)
        end
    end)()

    -- search + bag count
    UI.invSearch = Instance.new("TextBox")
    UI.invSearch.Name = "InventorySearch"
    UI.invSearch.Position = UDim2.new(0, 10, 0, 112)
    UI.invSearch.Size = UDim2.new(1, -130, 0, 26)
    UI.invSearch.BackgroundColor3 = UIStyle.Colors.Well -- (UI CLEAN: an inset field with a hairline)
    UI.invSearch.BackgroundTransparency = 0.2
    UI.invSearch.BorderSizePixel = 0
    UI.invSearch.ClearTextOnFocus = false
    UI.invSearch.Text = ""
    UI.invSearch.PlaceholderText = "Search: name, gun, type, rarity, stat..."
    UI.invSearch.PlaceholderColor3 = UIStyle.Colors.Muted
    UI.invSearch.TextColor3 = UIStyle.Colors.Text
    UI.invSearch.Font = Enum.Font.GothamMedium
    UI.invSearch.TextSize = 14
    UI.invSearch:SetAttribute("TextRole", "Body")
    UI.invSearch.TextXAlignment = Enum.TextXAlignment.Left
    UI.invSearch.Parent = stashPanel
    do
        local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 8); pad.Parent = UI.invSearch
        local ss = UIStyle.Stroke(UIStyle.Colors.Line, 1); ss.Parent = UI.invSearch
    end
    UI.invBagLbl = Label(stashPanel, "BAG 0 / 60", 14, COL_DIM, UIStyle.BodyFont, Enum.TextXAlignment.Right); UIStyle.TextRole(UI.invBagLbl, "Label")
    UI.invBagLbl.Position = UDim2.new(1, -118, 0, 112)
    UI.invBagLbl.Size = UDim2.new(0, 108, 0, 26)
    ;(function() -- QOL2 I3 (2026-10-28): BUYBACK -- the last 10 items sold this session (AimRngShared/BuybackMenu + AimRngServer/Buyback)
        local ok, BM = pcall(require, sharedFolder:WaitForChild("BuybackMenu"))
        if not ok then warn("[Buyback] " .. tostring(BM)); return end
        BM.Init({
            Panel = stashPanel, Search = UI.invSearch, InvFrame = UI.invFrame, PadMenus = function() return UI.PadMenus end,
            Toast = function(t) ShowToast(t) end,
            Tooltip = function(gui, item, isGear) if UI.HookItemTooltip then UI.HookItemTooltip(gui, item, isGear) end end,
            Refresh = function() RefreshInventory() end,
            Click = function() SoundHelper.Play("Click") end, Coin = function() SoundHelper.Play("Coin") end,
            Gold = function() return clientState.Gold or 0 end, State = function() return clientState end,
        })
        UI.Buyback = BM
    end)()
    ;(function() -- QOL2 I4 (2026-10-28): gear upgrade signal = EQUIP BEST's own score (AimRngShared/LoadoutScore), cached per loadout
        local LS = require(sharedFolder:WaitForChild("LoadoutScore"))
        UI.GearGain = function(g) return (LS.GearGain(clientState, g)) end
        UI.GearBadge = function(g)
            if not ItemData.CanEquipLevel(g, clientState.Level) then return "" end
            local gain = LS.GearGain(clientState, g)
            return (gain and gain > 0.02) and "  ▲" or "" -- (2%: the same bar as the weapon rows' DPS arrow)
        end
        if RunService:IsStudio() then -- (Studio: DevAct "ui:DevEquipBest" = the EQUIP BEST button at its build -> attr DevEquipBestResult)
            UI.DevEquipBest = function()
                local ok, _d, msg = pcall(function() return Remotes.GetFunction("EquipBest"):InvokeServer(LS.Mode) end)
                LocalPlayer:SetAttribute("DevEquipBestResult", tostring(ok) .. " " .. tostring(msg))
            end
            UI.DevGearTab = function() if UI.ShowStashTab then UI.ShowStashTab("Gear") end end -- (DevAct "ui:DevGearTab")
        end
    end)()
    local stashScroll = Instance.new("ScrollingFrame")
    stashScroll.Position = UDim2.new(0, 10, 0, 144)
    stashScroll.Size = UDim2.new(1, -20, 1, -152)
    stashScroll.BackgroundTransparency = 1
    stashScroll.BorderSizePixel = 0
    stashScroll.ScrollBarThickness = 5
    stashScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    stashScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    stashScroll.Parent = stashPanel
    local stashList = Instance.new("UIListLayout")
    stashList.Padding = UDim.new(0, 4)
    stashList.SortOrder = Enum.SortOrder.LayoutOrder
    stashList.Parent = stashScroll

    -- ITEMS bag (0.75): materials (with what each one does), the gem bag (salvage here too) and misc counters
    UI.RenderItemsBag = function(scroll: ScrollingFrame)
        local order = 0
        local function Head(text: string)
            order += 1
            local l = Label(scroll, text, 15, COL_TEXT, UIStyle.Font, Enum.TextXAlignment.Left)
            UIStyle.TextRole(l, "SectionHead")
            l.Size = UDim2.new(1, -8, 0, 26); l.LayoutOrder = order
        end
        local function Row(h: number): Frame
            order += 1
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, -8, 0, h); f.BackgroundColor3 = C(26, 30, 42); f.BorderSizePixel = 0; f.LayoutOrder = order
            f.Parent = scroll
            local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0, 6); cr.Parent = f
            return f
        end
        Head("MATERIALS")
        local mats = clientState.Materials or {}
        for _, k in ipairs(ItemData.MaterialOrder) do
            local def = ItemData.MaterialDefs[k]
            -- (UPDATE 7 CRAFTING v5: a currency shows from its unlock level, or once you own one)
            if def and (ItemData.MaterialUnlocked(k, clientState.Level) or (mats[k] or 0) > 0) then
                local f = Row(46)
                if def.IconKey and UIStyle.HasIcon and UIStyle.HasIcon(def.IconKey) then
                    UIStyle.Icon(def.IconKey, { Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(32, 32), Parent = f })
                end
                local n = Label(f, def.Name .. "   x" .. ItemData.FormatNumber(mats[k] or 0), 15, def.Color or COL_TEXT, UIStyle.Font, Enum.TextXAlignment.Left)
                UIStyle.TextRole(n, "ItemName", { Keep = true })
                n.Position = UDim2.fromOffset(48, 3); n.Size = UDim2.new(1, -56, 0, 18)
                local d = Label(f, def.Desc or "", 13, COL_DIM, UIStyle.BodyFont, Enum.TextXAlignment.Left); UIStyle.TextRole(d, "Meta", { Color = "Sub" })
                d.Position = UDim2.fromOffset(48, 21); d.Size = UDim2.new(1, -56, 0, 24); d.TextWrapped = true
                d.TextTruncate = Enum.TextTruncate.AtEnd
            end
        end
        local gems = clientState.Gems or {}
        local GD = require(sharedFolder:WaitForChild("GemData"))
        Head(string.format("GEMS  (%d / %d)  •  socket them at the Skill Tree", #gems, require(sharedFolder:WaitForChild("StashTabs")).GemCap(clientState)))
        local sorted = table.clone(gems)
        table.sort(sorted, function(a, b)
            local ra, rb = (ItemData.RarityRank[a.Rarity] or 0) + (tonumber(a.PowerMult) or 0) / 10, (ItemData.RarityRank[b.Rarity] or 0) + (tonumber(b.PowerMult) or 0) / 10 -- (UPDATE 8 GEM GRADES v4: rarity, then power)
            if ra ~= rb then return ra > rb end
            return (a.Name or "") < (b.Name or "")
        end)
        for _, g in ipairs(sorted) do
            local dsc = GD.Describe(g)
            local f = Row(52)
            local col = ItemData.RarityColors[g.Rarity] or COL_TEXT
            local t = Label(f, GD.Icon(g) .. " " .. dsc.Title, 15, col, UIStyle.Font, Enum.TextXAlignment.Left); UIStyle.TextRole(t, "ItemName", { Keep = true })
            t.Position = UDim2.fromOffset(10, 3); t.Size = UDim2.new(1, -96, 0, 18)
            local body = table.concat(dsc.Lines, "  •  ") .. (dsc.Special and ("  •  " .. dsc.Special) or "")
            local b = Label(f, dsc.Subtitle .. "  •  " .. body, 13, COL_DIM, UIStyle.BodyFont, Enum.TextXAlignment.Left); UIStyle.TextRole(b, "Meta", { Color = "Sub" })
            b.Position = UDim2.fromOffset(10, 21); b.Size = UDim2.new(1, -96, 0, 28); b.TextWrapped = true
            b.TextTruncate = Enum.TextTruncate.AtEnd
            local sb = SmallButton(f, "SALVAGE", C(110, 75, 150), 76)
            sb.Position = UDim2.new(1, -84, 0.5, -12)
            local armed = false
            sb.MouseButton1Click:Connect(function()
                SoundHelper.Play("Click")
                if not armed then armed = true; sb.Text = "SURE?"; sb.BackgroundColor3 = C(170, 60, 40) return end
                local ok, msg = Remotes.GetFunction("SalvageGem"):InvokeServer(g.Uid)
                ShowToast(msg or (ok and "Salvaged." or "Can't salvage that."))
            end)
        end
        if #sorted == 0 then
            local l = Label(scroll, "No gems yet: elites, bosses, the loot goblin and chests drop them.", 12, COL_DIM, UIStyle.BodyFont, Enum.TextXAlignment.Left)
            order += 1; l.LayoutOrder = order; l.Size = UDim2.new(1, -8, 0, 24)
        end
        Head("MISC")
        local misc = {
            { "Revive credits", clientState.ReviveCredits or 0 },
            { "Maps (sigils)", type(clientState.Sigils) == "table" and #clientState.Sigils or 0 },
        }
        for _, m in ipairs(misc) do
            local f = Row(30)
            local l = Label(f, m[1] .. "   x" .. ItemData.FormatNumber(m[2]), 14, COL_TEXT, UIStyle.Font, Enum.TextXAlignment.Left); UIStyle.TextRole(l, "Body")
            l.Position = UDim2.fromOffset(10, 0); l.Size = UDim2.new(1, -20, 1, 0)
        end
    end
    local currentStashTab = "Weapons"
    local sortModes = { "RARITY", "LEVEL", "DPS / ARMOR", "NEWEST" }
    local sortIdx = 1
    tabW.MouseButton1Click:Connect(function() currentStashTab = "Weapons"; RefreshInventory() end)
    tabG.MouseButton1Click:Connect(function() currentStashTab = "Gear"; RefreshInventory() end)
    UI.invTabI.MouseButton1Click:Connect(function() currentStashTab = "Items"; RefreshInventory() end)
    UI.ShowStashTab = function(tab: string) if currentStashTab ~= tab then currentStashTab = tab; SoundHelper.Play("Click"); RefreshInventory() end end
    UI.invTabS.MouseButton1Click:Connect(function()
        if not (UI.InOwnHideout and UI.InOwnHideout()) then ShowToast("Your stash is in your hideout: open it at the stash chest.") return end
        currentStashTab = "Stash"; RefreshInventory()
    end)
    UI.invSearch:GetPropertyChangedSignal("Text"):Connect(function()
        -- (typing re-filters after a short pause)
        UI.invSearchToken = (UI.invSearchToken or 0) + 1
        local t = UI.invSearchToken
        task.delay(0.18, function() if UI.invSearchToken == t then RefreshInventory() end end)
    end)
    sortBtn.MouseButton1Click:Connect(function()
        sortIdx = (sortIdx % #sortModes) + 1
        sortBtn.Text = "SORT: " .. sortModes[sortIdx]
        RefreshInventory()
    end)

    -- One compact item row: rarity bar, name, one-line summary, action buttons.
    local function ItemRow(parent: Instance, order: number, item: any, isGear: boolean, summary: string, badge: string?): Frame
        local rColor = ItemData.ItemColor(item)
        if parent == UI.bagGrid and UI.InvL then -- (UI CLEAN INV: an image tile in the bag grid -- the target's bag)
            local IL = UI.InvL
            local tile = Instance.new("TextButton")
            tile.Name = "Tile"
            tile.LayoutOrder = order
            tile:SetAttribute("Skinned", true)
            tile.Parent = parent
            local up = badge ~= nil and string.find(badge, "▲", 1, true) ~= nil
            local eqd = badge ~= nil and string.find(badge, "EQUIPPED", 1, true) ~= nil
            local t = IL.PaintTile(tile, item, ItemData.DisplayName(item), rColor, up, eqd)
            local lk
            if item.Uid and item.Uid ~= "W_STARTER_PISTOL" then -- ITEM LOCK (0.76): gold when locked
                lk = Instance.new("ImageButton")
                lk.Name = "Lock"; lk.BackgroundTransparency = 1; lk.ZIndex = tile.ZIndex + 2
                lk.Image = (UIStyle.Icons and UIStyle.Icons.lock) or ""; lk.ScaleType = Enum.ScaleType.Fit
                lk.AnchorPoint = Vector2.new(1, 0); lk.Position = UDim2.new(1, up and -24 or -6, 0, 5); lk.Size = UDim2.fromOffset(16, 16)
                lk:SetAttribute("Skinned", true); lk:SetAttribute("TileW", 22)
                lk.Parent = tile
                local function PaintLock()
                    lk.ImageColor3 = item.Locked and UIStyle.Colors.Gold or UIStyle.Colors.Sub
                    lk.ImageTransparency = item.Locked and 0 or 0.2
                end
                PaintLock()
                lk.MouseButton1Click:Connect(function()
                    SoundHelper.Play("Click")
                    local ok, locked = Remotes.GetFunction("ToggleItemLock"):InvokeServer(item.Uid)
                    if ok then
                        item.Locked = locked or nil
                        PaintLock()
                        ShowToast(locked and "Locked: it can't be sold or dismantled." or "Unlocked.")
                    end
                end)
            end
            UI.HookItemTooltip(tile, item, isGear)
            if UI.MarkNew then UI.MarkNew(tile, item) end -- (QOL L6)
            if UI.RowCtrlClick then UI.RowCtrlClick(tile, item, isGear) end -- (QOL L7)
            -- the actions the caller adds (EQUIP / R1 R2 / price / dismantle / STASH) + the lock: a row along the tile's top on hover
            -- (mouse) or on a tap / pad A (touch, pad: one tile open at a time); never always-on
            task.defer(function()
                if not tile.Parent then return end
                local acts = {}
                if lk then table.insert(acts, lk) end
                for _, c in ipairs(tile:GetChildren()) do
                    if c:IsA("TextButton") then
                        local n = #(c.Text or "")
                        c:SetAttribute("TileW", (n <= 2) and 26 or math.max(40, n * 7 + 12))
                        c.TextSize = 13
                        table.insert(acts, c)
                    end
                end
                local function Show(on: boolean)
                    if on then IL.TileActions(tile, acts) end
                    for _, a in ipairs(acts) do a.Visible = on or (a == lk and item.Locked == true) end
                    if lk and not on then lk.AnchorPoint = Vector2.new(1, 0); lk.Position = UDim2.new(1, up and -24 or -6, 0, 5); lk.Size = UDim2.fromOffset(16, 16) end
                    if t.Up then t.Up.Visible = not on end
                end
                Show(false)
                if #acts == 0 then return end
                -- a tap / pad A / click toggles (one tile open at a time); a mouse also opens on hover (a pad plugged in keeps hover)
                tile.Activated:Connect(function()
                    local was = UI.tileOpen == tile
                    if UI.tileOpen and UI.tileOpenFn then pcall(UI.tileOpenFn, false) end
                    UI.tileOpen, UI.tileOpenFn = nil, nil
                    if not was then Show(true); UI.tileOpen, UI.tileOpenFn = tile, Show end
                end)
                if not GameSettings.TouchOnly() then
                    tile.MouseEnter:Connect(function() Show(true) end)
                    tile.MouseLeave:Connect(function() if UI.tileOpen ~= tile then Show(false) end end)
                end
                if RunService:IsStudio() then tile:GetAttributeChangedSignal("DevOpen"):Connect(function() Show(tile:GetAttribute("DevOpen") == true) end) end
            end)
            return tile :: any
        end
        local row = Instance.new("TextButton")
        row.AutoButtonColor = false
        row.Text = ""
        row.Size = UDim2.new(1, -6, 0, 52) -- (0.84: 48 -> 52)
        local rowBg = UIStyle.Colors.Bg1:Lerp(rColor, 0.06) -- (UI CLEAN R-B: the item row card's faint rarity tint)
        row.BackgroundColor3 = rowBg
        row.LayoutOrder = order
        row:SetAttribute("NoNeon", true) -- (UI CLEAN: no button outline on rows; its own hover below)
        row.Parent = parent
        -- (UI CLEAN: a flat row, a 2 px rarity edge down its left side, the name in display caps, one body sub-line)
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, 0, 0, 2) -- (UI CLEAN R-B: the 2 px rarity edge along the bottom, like every item card)
        bar.Position = UDim2.new(0, 0, 1, -2)
        bar.BackgroundColor3 = rColor
        bar.BorderSizePixel = 0
        bar:SetAttribute("Skinned", true)
        bar.Parent = row
        if item.Exotic then
            -- relics: a thin edge in their colour round the row (rarity stays in the summary line)
            local edge = Instance.new("UIStroke")
            edge.Color = rColor
            edge.Thickness = 1
            edge.Transparency = 0.45
            edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            edge.Parent = row
        end
        local name = Label(row, string.upper((GameSettings.Get("RaritySymbols") ~= false) and ItemData.SymbolName(item) or ItemData.DisplayName(item)) .. (badge or ""), 17, rColor, UIStyle.Font) -- (QOL2 I2: the rarity symbol first)
        UIStyle.TextRole(name, "Title", { Keep = true }) -- (UI CLEAN P4: the name leads the row)
        name.TextSize = 17
        local TX = 14
        if UI.InvL then -- (UI CLEAN R-B: the item's icon in a reserved box on the left, aspect kept; the name in a readable rarity colour)
            local img = Instance.new("ImageLabel")
            img.Name = "Icon"; img.BackgroundTransparency = 1; img.AnchorPoint = Vector2.new(0.5, 0.5); img.Position = UDim2.new(0, 12 + 28, 0.5, -1)
            img.ScaleType = Enum.ScaleType.Fit; img.ImageColor3 = UIStyle.Colors.Text; img:SetAttribute("Skinned", true); img.Parent = row
            local spec = UI.InvL.IconFor(item, isGear and nil or "Weapon")
            -- (2026-11-09 SOCKETS) a gun's sockets under its icon (the stash list); the icon lifts 5 px for them
            if UI.InvL.Sockets and UI.InvL.Sockets(row, item, { Dot = 8, MaxW = 72, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, 40, 1, -6), ZIndex = row.ZIndex + 1 }) then
                img.Position = UDim2.new(0, 40, 0, 20)
                UI.InvL.ApplyIcon(img, spec, 56, 22, 22)
            else
                UI.InvL.ApplyIcon(img, spec, 56, 24, 24)
            end
            img.ImageTransparency = spec.Glyph and 0.3 or 0.1
            name.TextColor3 = UI.InvL.Readable(rColor, rowBg)
            TX = 80
        end
        name.Position = UDim2.new(0, TX, 0, 5)
        name.Size = UDim2.new(1, -(TX + 76), 0, 22)
        if not item.Exotic then ItemData.StyleRarityText(name, item.Rarity) end -- (0.68: the rarity gradient in the stash too)
        local sub = Label(row, summary, 14, UIStyle.Colors.Sub, Enum.Font.GothamMedium); UIStyle.TextRole(sub, "Label")
        sub.Position = UDim2.new(0, TX, 0, 28)
        sub.Size = UDim2.new(1, -(TX + 76), 0, 18)
        -- ITEM LOCK (0.76): a padlock left of the row's buttons -- gold when locked (no selling / dismantling / bulk sell)
        if item.Uid and item.Uid ~= "W_STARTER_PISTOL" then
            name.Size = UDim2.new(1, -(TX + 100), 0, 22) -- (UI CLEAN R-B: the list rows are the stash's now: TAKE + the lock on the right)
            local lk = Instance.new("ImageButton")
            lk.Name = "Lock"; lk.Size = UDim2.fromOffset(20, 20); lk.Position = UDim2.new(1, -94, 0, 4)
            lk.BackgroundTransparency = 1; lk.ZIndex = row.ZIndex + 2; lk.Parent = row
            lk.Image = (UIStyle.Icons and UIStyle.Icons.lock) or ""
            lk.ImageColor3 = item.Locked and C(255, 205, 80) or C(90, 98, 120)
            lk.ImageTransparency = item.Locked and 0 or 0.3
            lk.MouseButton1Click:Connect(function()
                SoundHelper.Play("Click")
                local ok, locked = Remotes.GetFunction("ToggleItemLock"):InvokeServer(item.Uid)
                if ok then
                    item.Locked = locked or nil
                    lk.ImageColor3 = locked and C(255, 205, 80) or C(90, 98, 120)
                    lk.ImageTransparency = locked and 0 or 0.3
                    ShowToast(locked and "Locked: it can't be sold or dismantled." or "Unlocked.")
                end
            end)
        end
        row.MouseEnter:Connect(function() row.BackgroundColor3 = UIStyle.Colors.Bg1:Lerp(rColor, 0.11) end)
        row.MouseLeave:Connect(function() row.BackgroundColor3 = rowBg end)
        UI.HookItemTooltip(row, item, isGear)
        if UI.MarkNew then UI.MarkNew(row, item) end -- (QOL L6: a dot on items you haven't looked at yet)
        if UI.RowCtrlClick then UI.RowCtrlClick(row, item, isGear) end -- (QOL L7: ctrl-click = bag <-> stash, at home)
        -- (UI v4 NEON LAYOUT: a row's actions (EQUIP / sell / dismantle / STASH / the open padlock) show on hover -- a
        -- bag of 60 rows with three coloured buttons each read as a wall of buttons. Touch + gamepad keep them visible.)
        if not GameSettings.TouchOnly() and not UserInputService.GamepadEnabled then
            task.defer(function()
                if not row.Parent then return end
                local acts = {}
                for _, c in ipairs(row:GetChildren()) do
                    if c:IsA("TextButton") or (c:IsA("ImageButton") and c.Name == "Lock" and not item.Locked) then
                        table.insert(acts, c); c.Visible = false
                    end
                end
                if #acts == 0 then return end
                row.MouseEnter:Connect(function() for _, c in ipairs(acts) do c.Visible = true end end)
                row.MouseLeave:Connect(function() for _, c in ipairs(acts) do c.Visible = false end end)
            end)
        end
        return row :: any
    end

    local function RarityRankOf(item: any): number return ItemData.SortRank(item) end -- (exotics: their own group on top)

    local function StatSheet(stats: any)
        for _, c in ipairs(statsScroll:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local w = clientState.EquippedWeapon
        local dps = stats.Damage * stats.FireRate * math.max(1, stats.PelletCount or 1) * math.max(1, stats.BurstCount or 1) * (1 + stats.CritChance * (stats.CritMultiplier - 1))
        local P = function(v: number): string return ItemData.FormatNumber(v * 100) .. "%" end
        local diffName = clientState.DungeonDifficulty or "Easy"
        local function ResText(element: string, raw: number): string -- (UPDATE 8 DEFENCE: typed resists, each with its own max)
            local eff = StatCalculator.EffectiveResist(stats, element, diffName)
            local shown = math.min(raw or 0, stats["Max" .. element .. "Resist"] or stats.MaxResist or 0.75)
            if math.abs(eff - shown) > 0.001 then
                return P(shown) .. "  (" .. P(eff) .. " " .. diffName .. ")"
            end
            return P(shown)
        end
        local procText, procTip = "None", "Weapons can roll one prefix: Burning, Freezing, Bleeding, Decaying, Giantslayer, Fixated or Explosive."
        if w and w.Proc and ItemData.WeaponProcs[w.Proc.Id] then
            procText = ItemData.WeaponProcs[w.Proc.Id].Prefix
            procTip = ItemData.DescribeProc(w, stats) or procTip
        end
        local rows = {
            { "OFFENSE" },
            { "Damage per Shot", ItemData.FormatNumber(stats.Damage) .. ((stats.PelletCount or 1) > 1 and (" x" .. stats.PelletCount) or ""), "Damage of one shot with your current weapon, after every bonus (not counting crits or weak spots)." },
            { "Damage per Second", ItemData.FormatNumber(dps), "Average damage per second including fire rate, pellets/bursts and crits, before weak-spot hits." },
            { "Fire Rate", string.format("%.1f/s", stats.FireRate), "Shots (or bursts) per second." },
            { "Crit Chance", P(stats.CritChance), "Chance for any shot to critically hit. Base 5%, +0.4% per Dexterity." },
            { "Crit Damage", "+" .. P(stats.CritMultiplier - 1), "Extra damage on a critical hit. Base +50%." },
            { "Weak-Spot Damage", P(stats.WeakSpotMultiplier), "Damage dealt when you hit an enemy's head or core, as a % of a normal hit." },
            { "Damage Bonus", "+" .. P(stats.DamageBonusPct or 0), "Total bonus weapon damage from Strength, gear, skills and your title." },
            { "Focus Bonus / Stack", "+" .. P(stats.StreakBonusPerStack), "Each consecutive weak-spot hit adds a Focus stack (max " .. tostring(stats.MaxFocusStacks or 25) .. "). Missing resets it; taking damage resets it too unless your tree says otherwise." },
            { "Magazine", tostring(stats.MagazineSize), "Rounds per magazine." },
            { "Reload Speed", P(stats.ReloadSpeed), "Reload speed relative to normal (100%)." },
            { "Melee Damage", ItemData.FormatNumber(stats.MeleeDamage), "Base damage of a melee swing [V], before your blade's multiplier." },
            { "DEFENSE" },
            { "Max Health", tostring(stats.MaxHP), "Grows with your level; +0.1% per Strength, plus gear and the tree." },
            { "Health Regen", ItemData.FormatNumber(stats.HPRegen) .. "/s", "Health restored every second." },
            { "Plating", ItemData.FormatNumber(stats.Plating or stats.Armor or 0) .. "  (-" .. math.round((stats.DamageReduction or 0) * 100) .. "% Kinetic)", "Plating cuts Kinetic hits. The cut shown is against an ordinary enemy hit at your level; small hits are cut more and big hits (boss slams) less. At most " .. math.round(StatCalculator.PLATING_MAX * 100) .. "%." },
            { "Agility", ItemData.FormatNumber(stats.Agility or 0) .. "  (" .. P(stats.EvadeChance or 0) .. " evade)", "Chance for an ordinary enemy hit to miss you entirely. Boss hits and floor mechanics always land: dodging them by moving is up to you. At most " .. math.round(StatCalculator.AGILITY_MAX * 100) .. "%." },
            { "Ward", ItemData.FormatNumber(stats.Ward or 0), "A shield in front of your health. It takes damage first and recharges " .. string.format("%.1f", stats.WardDelay or StatCalculator.WARD_DELAY) .. " s after you were last hit (" .. P(stats.WardRate or StatCalculator.WARD_RATE) .. " of it a second). Void damage goes straight past it." },
            { "Life Leech", P(stats.LifeLeechPct), "Portion of damage dealt returned as health." },
            { "RESISTANCES" },
            { "Heat Resistance", ResText("Heat", stats.HeatResist or stats.FireResist), "Reduces Heat damage taken and weakens Burns on you. Max " .. P(stats.MaxHeatResist or stats.MaxResist) .. ". " .. diffName .. " lowers every resistance by " .. P(-StatCalculator.ResistPenalty(diffName)) .. " (harder difficulties lower them more)." },
            { "Cryo Resistance", ResText("Cryo", stats.CryoResist or stats.ColdResist), "Reduces Cryo damage taken and weakens Chill slows on you. Max " .. P(stats.MaxCryoResist or stats.MaxResist) .. ". Lowered on harder difficulties." },
            { "Volt Resistance", ResText("Volt", stats.VoltResist or 0), "Reduces Volt damage taken and weakens Shock on you. Max " .. P(stats.MaxVoltResist or stats.MaxResist) .. ". Lowered on harder difficulties." },
            { "Void Resistance", ResText("Void", stats.VoidResist or stats.ChaosResist), "Reduces Void damage taken and weakens Wither on you. Void damage skips Ward. Max " .. P(stats.MaxVoidResist or stats.MaxResist) .. ". Lowered on harder difficulties." },
            { "WEAPON EFFECTS" },
            { "Prefix", procText, procTip },
            { "Proc Chance", "+" .. P(stats.AilmentChance or 0), "Increases the trigger chance of Burning, Freezing, Bleeding, Decaying and Explosive weapons." },
            { "Effect Duration", "+" .. P(stats.AilmentDuration or 0), "Your Burns, Freezes, Bleeds and Decays last longer." },
            { "Burn Damage", "+" .. P(stats.BurnDamage or 0), "Increases the damage of your Burns." },
            { "Freeze Effect", "+" .. P(stats.FreezeEffect or 0), "Your Freezes slow more and deal more damage." },
            { "Bleed Damage", "+" .. P(stats.BleedDamage or 0), "Increases the damage of your Bleeds." },
            { "Decay Effect", "+" .. P(stats.DecayEffect or 0), "Decayed enemies take even more damage." },
            { "Explosion Damage", "+" .. P(stats.ExplosionDamage or 0), "Increases explosion damage (Explosive / Fixation weapons, launcher splash)." },
            { "UTILITY" },
            { "Move Speed", P(stats.MovementSpeedMult), "Walking speed relative to normal (100%)." },
            { "Loot Luck", "+" .. P(stats.LuckMultiplier - 1), "Improves the odds of higher-rarity drops (every tier, and most of all the rarest). +2.5% per Luck, plus tree nodes and gear; each source has its own ceiling for your level." },
            { "Gold Find", "+" .. P(stats.GoldBonusMult - 1), "Extra gold from kills and chests." },
        }
        -- STAT CEILINGS (StatCalculator.CEILINGS): a stat held back by your level's ceiling says so -- "(capped)" on the value,
        -- and the tooltip shows your raw total, what it counts as and the cap at your level (it rises as you level)
        do
            local CEIL = { ["Fire Rate"] = "FireRate", ["Crit Chance"] = "CritChance", ["Crit Damage"] = "CritMulti", ["Weak-Spot Damage"] = "WeakSpot",
                ["Damage Bonus"] = "Damage", ["Focus Bonus / Stack"] = "Streak", ["Magazine"] = "MagSize", ["Reload Speed"] = "Reload",
                ["Max Health"] = "MaxHP", ["Health Regen"] = "Regen", ["Plating"] = "Armor", ["Life Leech"] = "Leech", ["Proc Chance"] = "AilChance",
                ["Effect Duration"] = "AilDuration", ["Burn Damage"] = "Burn", ["Freeze Effect"] = "Freeze", ["Bleed Damage"] = "Bleed",
                ["Decay Effect"] = "Decay", ["Explosion Damage"] = "Explosion", ["Move Speed"] = "MoveSpeed", ["Loot Luck"] = "Luck", ["Gold Find"] = "Gold" }
            local ceil = stats.Ceilings or {}
            for _, r in ipairs(rows) do
                local c = #r >= 2 and CEIL[r[1]] and ceil[CEIL[r[1]]]
                if c and c.Raw > c.Eff * 1.15 and c.Raw - c.Eff > 0.01 then -- (only once it is clearly into the curve)
                    r[2] = r[2] .. "  (capped)"
                    -- (each source has its own ceiling: passive tree, attribute points, gear)
                    local parts = {}
                    for _, src in ipairs({ { "tree", c.Tree }, { "attributes", c.Attr }, { "gear", c.Gear } }) do
                        local t = src[2]
                        if t and t[1] > 0.0001 then table.insert(parts, string.format("%s +%s counts +%s (cap +%s)", src[1], P(t[1]), P(t[2]), P(t[3] ~= math.huge and t[3] or t[1]))) end
                    end
                    r[3] = (r[3] or "") .. "  •  LEVEL CEILINGS at level " .. tostring(clientState.Level or 1) .. ": " .. table.concat(parts, "; ") .. ". The caps rise as you level, most of all near 400."
                end
            end
        end
        -- BUILD: keystones / Mythic gem rules and the passive tree's conditional bonuses.
        do
            local GemData = require(sharedFolder:WaitForChild("GemData"))
            local mechs = {}
            for m in pairs(stats.SpecialMechanics or {}) do table.insert(mechs, m) end
            table.sort(mechs)
            local cond = stats.Cond or {}
            local ck = {}
            for k, v in pairs(cond) do if math.abs(v) > 1e-6 then table.insert(ck, k) end end
            table.sort(ck, function(a, b) return (ItemData.StatDefs[a] and ItemData.StatDefs[a].Label or a) < (ItemData.StatDefs[b] and ItemData.StatDefs[b].Label or b) end)
            if #mechs > 0 or #ck > 0 then
                table.insert(rows, { "BUILD (TREE & GEMS)" })
                for _, m in ipairs(mechs) do
                    local name, desc = m, ""
                    for _, node in pairs(SkillTreeData) do
                        if node.SpecialMechanic == m then name, desc = node.Name, node.Description or ""; break end
                    end
                    local myth = GemData.Mythics[m]
                    if myth then name, desc = myth.Name .. " (gem)", myth.Text end
                    table.insert(rows, { "★ " .. name, "active", desc })
                end
                for _, k in ipairs(ck) do
                    local def = ItemData.StatDefs[k]
                    local v = cond[k]
                    local txt = (def and def.Kind == "pct") and ("+" .. P(v)) or ("+" .. ItemData.FormatNumber(v))
                    table.insert(rows, { def and def.Label or k, txt, def and def.Desc or "" })
                end
            end
        end
        -- (UI v4 NEON LAYOUT: section headers = caps + a hairline with room above them; rows have no zebra, a hover
        -- highlight instead; a stat held back by its level ceiling gets a small CAP tag instead of "(capped)" text;
        -- effect / utility lines at +0% are left out -- nothing to read there)
        local section = ""
        local first = true
        for i, r in ipairs(rows) do
            if #r == 1 then
                section = r[1]
                local hh = first and 26 or 36
                first = false
                local h = Instance.new("Frame"); h.Name = "Head"; h.BackgroundTransparency = 1; h.Size = UDim2.new(1, -6, 0, hh); h.LayoutOrder = i; h.Parent = statsScroll
                local hl = Label(h, r[1], 15, UIStyle.Colors.Text, Enum.Font.GothamBlack)
                UIStyle.TextRole(hl, "SectionHead") -- (UI CLEAN P4: the head is brighter / bigger than its rows)
                hl.AnchorPoint = Vector2.new(0, 1); hl.Position = UDim2.new(0, 0, 1, -4); hl.Size = UDim2.new(1, -8, 0, 18)
                local rule = Instance.new("Frame"); rule.BorderSizePixel = 0; rule.BackgroundColor3 = UIStyle.Colors.Line
                rule.AnchorPoint = Vector2.new(0, 1); rule.Position = UDim2.new(0, 0, 1, 0); rule.Size = UDim2.new(1, -8, 0, 1)
                rule:SetAttribute("Skinned", true); rule.Parent = h
            elseif not ((section == "WEAPON EFFECTS" or section == "UTILITY") and r[2] == "+0%" and r[1] ~= "Prefix") then
                local capped = string.find(r[2], "  (capped)", 1, true) ~= nil
                local valText = capped and (r[2]:gsub("  %(capped%)", "")) or r[2]
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, -6, 0, 24)
                row.BackgroundTransparency = 1
                row.BackgroundColor3 = UIStyle.Colors.Bg2
                row.BorderSizePixel = 0
                row.LayoutOrder = i
                row:SetAttribute("NoSkin", true)
                row.Parent = statsScroll
                local l = Label(row, r[1], 14, UIStyle.Colors.Sub, Enum.Font.GothamMedium); UIStyle.TextRole(l, "Label")
                l.Size = UDim2.new(0.58, -4, 1, 0); l.Position = UDim2.new(0, 0, 0, 0)
                local v = Label(row, valText, 16, COL_TEXT, Enum.Font.GothamBlack, Enum.TextXAlignment.Right)
                v:SetAttribute("TypeRole", "Accent") -- (UI CLEAN: label left in body Sub, the number right in the display face)
                v.Size = UDim2.new(0.42, capped and -40 or -8, 1, 0)
                v.Position = UDim2.new(0.58, 0, 0, 0)
                v.TextScaled = true
                local lim = Instance.new("UITextSizeConstraint"); lim.MaxTextSize = 15; lim.MinTextSize = 11; lim.Parent = v
                UIStyle.TextRole(v, "Value")
                if capped then
                    local tag = Label(row, "CAP", 13, UIStyle.Colors.Sub, Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
                    UIStyle.TextRole(tag, "Meta", { Color = "Sub" }) -- (P4: the warn colour stays on its edge only)
                    tag.AnchorPoint = Vector2.new(1, 0.5); tag.Position = UDim2.new(1, -6, 0.5, 0); tag.Size = UDim2.fromOffset(30, 16)
                    tag.BackgroundTransparency = 0; tag.BackgroundColor3 = UIStyle.Colors.Bg1
                    tag:SetAttribute("AllowTiny", true)
                    local ts = Instance.new("UIStroke"); ts.Color = UIStyle.Colors.Warn:Lerp(UIStyle.Colors.Bg1, 0.5); ts.Thickness = 1; ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; ts.Parent = tag
                end
                row.MouseEnter:Connect(function() row.BackgroundTransparency = 0 end)
                row.MouseLeave:Connect(function() row.BackgroundTransparency = 1 end)
                HookTooltip(row, function()
                    return { { Text = r[1], Bold = true, Size = 14 }, { Text = r[3], Color = COL_DIM } }, COL_ACCENT
                end)
            end
        end
        if w then
            levelLbl.Text = string.format("Level %d   •   %s / %s XP", clientState.Level or 1, ItemData.FormatNumber(math.floor(clientState.XP or 0)), ItemData.FormatNumber(clientState.MaxXP or 0))
        end
    end

    -- ===== UI CLEAN INV (2026-10-28): the full-screen inventory of the owner's accepted target (docs/ui_target/inventory_target.html):
    -- top nav (INVENTORY / STASH / FORGE / EXCHANGE / PASSIVES) + currencies + close, then three zones split by hairlines --
    -- LEFT who you are + power numbers (ALL STATS = the old full sheet, charPanel, over the column), CENTRE the loadout (10 identical
    -- slot cards), RIGHT the bag (word tabs, search / SORT / SELL, an image-tile grid for weapons + gear; ITEMS / STASH keep the
    -- list). AimRngShared/InvLayout builds + paints the pieces; every action stays here.
    ;(function()
        local IL = require(sharedFolder:WaitForChild("InvLayout"))
        UI.InvL = IL
        local Ccol = UIStyle.Colors
        local function NavStash()
            if not (UI.InOwnHideout and UI.InOwnHideout()) then ShowToast("Your stash is in your hideout: open it at the stash chest.") return end
            SoundHelper.Play("Click"); currentStashTab = "Stash"; RefreshInventory()
        end
        local ui = IL.Chrome(UI.invFrame, {
            Selected = "INVENTORY",
            Nav = {
                { Id = "INVENTORY", Text = "INVENTORY", OnClick = function() SoundHelper.Play("Click"); if currentStashTab == "Stash" then currentStashTab = "Weapons"; RefreshInventory() end end },
                { Id = "STASH", Text = "STASH", OnClick = NavStash },
                { Id = "FORGE", Text = "FORGE", OnClick = function() SoundHelper.Play("Click"); if UI.HubWindow then UI.HubWindow("Forge") end end },
                { Id = "MODS", Text = "MODS", OnClick = function() SoundHelper.Play("Click"); if UI.OpenShotMods then UI.OpenShotMods() end end },
                { Id = "EXCHANGE", Text = "EXCHANGE", OnClick = function() SoundHelper.Play("Click"); if UI.OpenMarket then UI.OpenMarket() end end },
                { Id = "PASSIVES", Text = "PASSIVES", OnClick = function() SoundHelper.Play("Click"); CloseAllMenus(); UI.OpenMenuByName("Skills") end },
            },
            OnClose = function() CloseAllMenus() end,
            Currencies = { { Key = "Gold", Icon = "cur_gold" }, { Key = "Scrap", Icon = "cur_scrap" }, { Key = "Alloy", Icon = "cur_alloy" },
                { Key = "Prism", Icon = "cur_prism" }, { Key = "SP", Icon = "cur_sp" } },
        })
        UI.invUi = ui
        game:GetService("CollectionService"):AddTag(UI.invFrame, "UIT_Field") -- (SKIN UI THEMES: the set's signature touches)
        -- (UI CLEAN R-B) the GEAR group's nav in every full-screen menu's top bar (UIStyle.MenuTop) opens the same windows
        UIStyle.NavOpen.INVENTORY = function() SoundHelper.Play("Click"); CloseAllMenus(); currentStashTab = (currentStashTab == "Stash") and "Weapons" or currentStashTab; UI.OpenMenuByName("Inventory") end
        UIStyle.NavOpen.STASH = function()
            if not (UI.InOwnHideout and UI.InOwnHideout()) then ShowToast("Your stash is in your hideout: open it at the stash chest.") return end
            SoundHelper.Play("Click"); CloseAllMenus(); currentStashTab = "Stash"; UI.OpenMenuByName("Inventory")
        end
        UIStyle.NavOpen.FORGE = function() SoundHelper.Play("Click"); if UI.HubWindow then UI.HubWindow("Forge") end end
        UIStyle.NavOpen.MODS = function() SoundHelper.Play("Click"); if UI.OpenShotMods then UI.OpenShotMods() end end
        UIStyle.NavOpen.EXCHANGE = function() SoundHelper.Play("Click"); if UI.OpenMarket then UI.OpenMarket() end end
        UIStyle.NavOpen.PASSIVES = function() SoundHelper.Play("Click"); CloseAllMenus(); UI.OpenMenuByName("Skills") end
        if RunService:IsStudio() then UI.DevNavStash = UIStyle.NavOpen.STASH end -- (Studio: DevAct "ui:DevNavStash" = the STASH nav)
        -- LEFT: identity + power; ALL STATS = the old sheet (charPanel) over the column, its head turns into BACK
        local function AllStats(on: boolean)
            charPanel.Visible = on
            -- (the zone scrolls on short screens; the sheet has its own list, so the zone stops scrolling under it)
            ui.Left.CanvasPosition = Vector2.zero
            ui.Left.CanvasSize = on and UDim2.new() or UDim2.fromOffset(0, 590)
            if on and UI.RefreshLifeStats then UI.RefreshLifeStats() end
        end
        UI.invAllStats = AllStats
        UI.invId = IL.Identity(ui.Left, function() SoundHelper.Play("Click"); AllStats(true) end)
        do -- the title is the identity line now: clicking it opens your titles (was the TITLE tile)
            local tb = Instance.new("TextButton")
            tb.Name = "TitleClick"; tb.Text = ""; tb.BackgroundTransparency = 1; tb.AutoButtonColor = false
            tb.Position = UDim2.fromOffset(IL.PAD + 56, 50); tb.Size = UDim2.new(1, -(IL.PAD * 2 + 56), 0, 16); tb.Parent = ui.Left
            tb:SetAttribute("Skinned", true)
            tb.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); if UI.OpenTitles then UI.OpenTitles() end end)
        end
        charPanel.Parent = ui.Left
        charPanel.Position = UDim2.new(0, 0, 0, 0); charPanel.Size = UDim2.new(1, 0, 1, 0)
        charPanel.BackgroundColor3 = Color3.fromRGB(13, 16, 21); charPanel.BackgroundTransparency = 0; charPanel.ZIndex = 5
        charPanel.Visible = false
        do
            local head = charPanel:FindFirstChildWhichIsA("TextLabel")
            if head then head.Text = "‹  BACK" end
            local back = Instance.new("TextButton")
            back.Name = "AllStatsBack"; back.Text = ""; back.BackgroundTransparency = 1; back.AutoButtonColor = false
            back.Position = UDim2.fromOffset(0, 0); back.Size = UDim2.new(0.5, 0, 0, 30); back.ZIndex = 6; back.Parent = charPanel
            back:SetAttribute("Skinned", true)
            back.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); AllStats(false) end)
        end
        UI.invFrame:GetPropertyChangedSignal("Visible"):Connect(function() if not UI.invFrame.Visible then charPanel.Visible = false end end)
        -- CENTRE: the loadout column
        eqPanel.Parent = ui.Body
        local function Cols(p: Frame)
            local rule = p:FindFirstChild("ColumnRule")
            if rule then rule.Position = UDim2.new(0, 0, 0, 0); rule.Size = UDim2.new(0, 1, 1, 0); rule.BackgroundColor3 = Ccol.Text; rule.BackgroundTransparency = 0.9 end
            local head = p:FindFirstChildWhichIsA("TextLabel")
            if head then head.Visible = false end
        end
        Cols(eqPanel)
        IL.Head(eqPanel, "LOADOUT", 24, IL.PAD, 150)
        btnBest.AnchorPoint = Vector2.new(1, 0); btnBest.Size = UDim2.fromOffset(150, 30); btnBest.Position = UDim2.new(1, -(IL.PAD + 36), 0, 18)
        btnDrop.AnchorPoint = Vector2.new(1, 0); btnDrop.Size = UDim2.fromOffset(30, 30); btnDrop.Position = UDim2.new(1, -IL.PAD, 0, 18)
        for _, b in ipairs({ btnBest, btnDrop }) do -- (quiet outline buttons, no tinted slab)
            b.BackgroundTransparency = 1; b:SetAttribute("NoNeon", true)
            local s = Instance.new("UIStroke"); s.Color = Ccol.Text; s.Transparency = 0.78; s.Thickness = 1; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = b
        end
        btnBest.TextColor3 = Ccol.Text; btnDrop.TextColor3 = Ccol.Text
        list.Position = UDim2.new(1, -IL.PAD, 0, 52)
        do -- (the 10 cards scroll when the column is short: phones, small windows)
            local ls = Instance.new("ScrollingFrame")
            ls.Name = "LoadoutScroll"; ls.BackgroundTransparency = 1; ls.BorderSizePixel = 0
            ls.Position = UDim2.fromOffset(IL.PAD, 62); ls.Size = UDim2.new(1, -IL.PAD * 2 + 6, 1, -70)
            ls.CanvasSize = UDim2.fromOffset(0, 5 * IL.SLOT_H + 4 * 8 + 4); ls.ScrollingDirection = Enum.ScrollingDirection.Y
            ls:SetAttribute("Skinned", true); ls.Parent = eqPanel
            UIStyle.StyleScroll(ls, 3)
            eqHolder.Parent = ls
            eqHolder.Position = UDim2.new(0, 0, 0, 0); eqHolder.Size = UDim2.new(1, -6, 0, 5 * IL.SLOT_H + 4 * 8)
        end
        -- RIGHT: the bag
        stashPanel.Parent = ui.Body
        Cols(stashPanel)
        local tabRow = stashPanel:FindFirstChild("TabRow")
        if tabRow then tabRow.Position = UDim2.fromOffset(IL.PAD, 14); tabRow.Size = UDim2.new(1, -(IL.PAD * 2 + 90), 0, 36) end
        UI.invTabS.Visible = false -- (the STASH is in the top nav)
        for _, t in ipairs({ tabW, tabG, UI.invTabI }) do t.RichText = true end
        IL.Rule(stashPanel, { Name = "TabsRule", Position = UDim2.fromOffset(IL.PAD, 50), Size = UDim2.new(1, -IL.PAD * 2, 0, 1) })
        UI.invBagLbl.AnchorPoint = Vector2.new(1, 0); UI.invBagLbl.Position = UDim2.new(1, -IL.PAD, 0, 14); UI.invBagLbl.Size = UDim2.fromOffset(90, 34)
        UI.invBagLbl:SetAttribute("TypeRole", "Label"); UI.invBagLbl.Font = Enum.Font.GothamBlack
        -- tools: search | SORT | SELL (SELL = one menu for every sell / auto-sell / stash-up-to / buyback / gem salvage picker)
        sellBar.Visible = false
        local SELL_W, SORT_W = 64, 118
        UI.invSearch.Position = UDim2.fromOffset(IL.PAD, 62); UI.invSearch.Size = UDim2.new(1, -(IL.PAD * 2 + SORT_W + SELL_W + 12), 0, 30)
        UI.invSearch.PlaceholderText = "Search name, type, stat"
        sortBtn.AnchorPoint = Vector2.new(1, 0); sortBtn.Position = UDim2.new(1, -(IL.PAD + SELL_W + 6), 0, 62); sortBtn.Size = UDim2.fromOffset(SORT_W, 30)
        sortBtn.BackgroundTransparency = 1; sortBtn:SetAttribute("NoNeon", true); sortBtn.TextColor3 = Ccol.Text
        do local s = Instance.new("UIStroke"); s.Color = Ccol.Text; s.Transparency = 0.78; s.Thickness = 1; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = sortBtn end
        local sellBtn = IL.Btn(stashPanel, "SELL", { Name = "SellMenu", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -IL.PAD, 0, 62), Size = UDim2.fromOffset(SELL_W, 30) })
        UI.invSellBtn = sellBtn
        UI.OpenSellMenu = function()
            local items = {}
            local function Add(text, fn) table.insert(items, { Text = text, Color = Ccol.Text, Value = fn }) end
            if currentStashTab == "Items" then
                Add("SALVAGE GEMS UP TO ...", function() UI.PickGemSalvage(sellBtn) end)
                Add("GEM AUTO-SALVAGE: " .. string.upper(clientState.GemAutoSalvage or "OFF"), function() UI.PickGemAuto(sellBtn) end)
            else
                Add("SELL UP TO ...", function() UI.PickSellUpTo(sellBtn) end)
                Add("AUTO-SELL: " .. require(sharedFolder:WaitForChild("AutoSellRules")).Short(clientState.AutoSellThreshold, clientState.AutoSellRules) .. " ...", function() UI.PickAutoSell(sellBtn) end) -- (2026-11-09: opens the AUTO-SELL panel)
                if UI.InOwnHideout and UI.InOwnHideout() and UI.PickStashUpTo then Add("STASH UP TO ...", function() UI.PickStashUpTo(sellBtn) end) end
            end
            local n = tonumber(LocalPlayer:GetAttribute("BuybackCount")) or 0
            if n > 0 and UI.Buyback then Add("BUYBACK (" .. n .. ")", function() UI.Buyback.Open(true) end) end
            UI.PopupUI.Dropdown(sellBtn, items, function(fn) if type(fn) == "function" then task.defer(fn) end end)
        end
        sellBtn.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); UI.OpenSellMenu() end)
        if RunService:IsStudio() then -- (Studio: DevAct "ui:DevSellMenu" / "ui:DevItemsTab" / "ui:DevAllStats" / "ui:DevPhoneStats")
            UI.DevSellMenu = function() UI.OpenSellMenu() end
            UI.DevItemsTab = function() UI.ShowStashTab("Items") end
            UI.DevAllStats = function() UI.invAllStats(not charPanel.Visible) end
            UI.DevPhoneStats = function() if UI.invUi then UI.invUi.PhoneLeft = not UI.invUi.PhoneLeft; if UI.invPlace then UI.invPlace() end end end
        end
        -- the image-tile grid (weapons + gear); ITEMS / STASH stay a list (stashScroll)
        local grid = Instance.new("ScrollingFrame")
        grid.Name = "BagGrid"; grid.BackgroundTransparency = 1; grid.BorderSizePixel = 0
        grid.Position = UDim2.fromOffset(IL.PAD, 106); grid.Size = UDim2.new(1, -IL.PAD * 2 + 6, 1, -128)
        grid.AutomaticCanvasSize = Enum.AutomaticSize.Y; grid.CanvasSize = UDim2.new(); grid.ScrollingDirection = Enum.ScrollingDirection.Y
        grid.ScrollBarThickness = 3
        grid.Parent = stashPanel
        UIStyle.StyleScroll(grid, 3)
        local gl = Instance.new("UIGridLayout"); gl.CellPadding = UDim2.fromOffset(6, 6); gl.SortOrder = Enum.SortOrder.LayoutOrder; gl.Parent = grid
        local function Cells()
            local hs = hudGui:FindFirstChildOfClass("UIScale")
            local pop = UI.invFrame:FindFirstChild("PopScale")
            local k = math.max((hs and hs.Scale or 1) * (pop and pop.Scale or 1), 0.05)
            local w = grid.AbsoluteSize.X / k - 8
            local cols = math.clamp(math.floor((w + 6) / 128), 2, 4)
            gl.CellSize = UDim2.new(1 / cols, -math.ceil(6 * (cols - 1) / cols) - 2, 0, IL.TILE_H)
        end
        grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(Cells)
        task.defer(Cells)
        UI.bagGrid = grid
        stashScroll.Position = UDim2.fromOffset(IL.PAD, 106); stashScroll.Size = UDim2.new(1, -IL.PAD * 2 + 6, 1, -128)
        -- BUYBACK lives in the SELL menu; its panel covers the grid
        local bb = stashPanel:FindFirstChild("BuybackButton")
        if bb then bb.Visible = false; bb:GetPropertyChangedSignal("Visible"):Connect(function() if bb.Visible then bb.Visible = false end end) end
        local bp = stashPanel:FindFirstChild("BuybackPanel")
        if bp then bp.Position = UDim2.fromOffset(IL.PAD, 106); bp.Size = UDim2.new(1, -IL.PAD * 2, 1, -128) end
        -- PHONES: no left column (STATS in the top bar swaps the centre for it), centre + bag half / half
        local statsBtn = IL.Btn(ui.Top, "STATS", { Name = "PhoneStats", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -470, 0.5, 0), Size = UDim2.fromOffset(84, 30) })
        statsBtn.Visible = false
        local function Place()
            local phone = UIStyle.IsPhone()
            local hs = hudGui:FindFirstChildOfClass("UIScale")
            local kk = math.max(hs and hs.Scale or 1, 0.05)
            local inset = phone and 0 or math.floor(UIStyle.TopInset() * UIStyle.SimK() / kk + 0.5)
            IL.Layout(ui, eqPanel, stashPanel, phone, inset)
            statsBtn.Visible = phone
            statsBtn.Text = ui.PhoneLeft and "LOADOUT" or "STATS"
            local navHolder = ui.Top:FindFirstChild("Nav")
            if navHolder then navHolder.Size = UDim2.new(1, phone and -560 or -460, 1, 0) end
            UI.invFrame.BackgroundColor3 = UIStyle.Colors.Field; UI.invFrame.BackgroundTransparency = 0.06
            iHeader.Visible = false; iHint.Visible = false
        end
        statsBtn.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); ui.PhoneLeft = not ui.PhoneLeft; Place() end)
        UI.invPlace = Place
        -- the HUD under a full-screen menu: hidden while it is open (it read through the see-through window), back as it was after
        local hidden = {}
        local function HideHud(on: boolean)
            if on then
                for _, n in ipairs({ "LevelHUD", "HealthHUD", "CurrencyHUD", "StatusChips", "BuildChips", "PartyHud" }) do
                    local o = hudGui:FindFirstChild(n)
                    if o and o:IsA("GuiObject") and o.Visible then hidden[o] = true; o.Visible = false end
                end
            else
                for o in pairs(hidden) do if o.Parent then o.Visible = true end end
                table.clear(hidden)
            end
        end
        local reasons = {} -- (the inventory + any full-screen menu field, UIStyle.OnMenuField)
        local function HudReason(r: string, on: boolean)
            reasons[r] = on or nil
            HideHud(next(reasons) ~= nil)
        end
        UIStyle.OnMenuField = function(on: boolean) HudReason("menu", on) end
        UI.invFrame:GetPropertyChangedSignal("Visible"):Connect(function()
            HudReason("inv", UI.invFrame.Visible)
            if UI.invFrame.Visible then task.defer(Place) end
        end)
        if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() if UI.invFrame.Visible then task.defer(Place) end end) end
        LocalPlayer:GetAttributeChangedSignal("DevPhone"):Connect(function() task.delay(0.1, Place) end)
        task.defer(Place)
    end)()

    RefreshInventory = function()
        UI.HideTooltip()
        local attrs = clientState.Attributes or { Strength = 5, Dexterity = 5, Vitality = 5, Luck = 5 }
        local stats = StatCalculator.Calculate(clientState.EquippedWeapon, clientState.AllocatedNodes or {}, clientState.Streak or 0, clientState.Level, attrs, clientState.EquippedGear, clientState.EquippedTitle, clientState.SocketedGems, clientState.RunBoons, clientState)
        local _ = attrs
        pointsLbl.Text = "From the passive tree + gear" -- (UPDATE 8 phase 4; short: it truncated on phones)
        pointsLbl.TextColor3 = UIStyle.Colors.Muted
        local totals = ItemData.AttrTotals(stats)
        for _, attr in ipairs(ATTRS) do
            local base = ItemData.ATTR_BASE
            local total = math.floor(totals[attr] or base)
            attrRows[attr].Label.Text = attr
            attrRows[attr].Value.Text = tostring(total) .. ((total ~= base) and ("  (" .. base .. " + " .. (total - base) .. ")") or "")
            attrRows[attr].Plus.Visible = false
        end
        StatSheet(stats)
        if UI.RefreshLifeStats then UI.RefreshLifeStats() end -- (Update 5: the STATS tab)
        btnAutoSell.Text = "AUTO-SELL: " .. require(sharedFolder:WaitForChild("AutoSellRules")).Short(clientState.AutoSellThreshold, clientState.AutoSellRules) .. " ▼"
        do -- (0.84: the ITEMS tab shows the gem auto-salvage instead of the gun + gear pair)
            local itemsTab = currentStashTab == "Items"
            btnAutoSell.Visible = not itemsTab
            UI.btnSellUpTo.Visible = not itemsTab
            UI.btnGemAuto.Visible = itemsTab
            UI.btnGemSalvage.Visible = itemsTab
            UI.btnGemAuto.Text = "GEM AUTO-SALVAGE: " .. string.upper(clientState.GemAutoSalvage or "OFF") .. " ▼"
        end
        -- (UI v4 NEON: the bag tabs are text tabs -- bright label + the neon underline when selected, quiet otherwise)
        -- (the STASH tab only exists at home: fall back BEFORE painting, or the underline sat on STASH over a weapon list)
        if currentStashTab == "Stash" and not (UI.InOwnHideout and UI.InOwnHideout()) then currentStashTab = "Weapons" end
        for _, tb in ipairs({ { tabW, "Weapons" }, { tabG, "Gear" }, { UI.invTabI, "Items" } }) do
            tb[1].TextColor3 = (currentStashTab == tb[2]) and UIStyle.Colors.Text or UIStyle.Colors.Sub
        end
        for _, tb in ipairs({ { tabW, "Weapons" }, { tabG, "Gear" }, { UI.invTabI, "Items" }, { UI.invTabS, "Stash" } }) do
            local edge = tb[1] and tb[1]:FindFirstChild("SelEdge")
            if tb[1] and not edge then
                edge = Instance.new("Frame"); edge.Name = "SelEdge"; edge.BorderSizePixel = 0; edge.BackgroundColor3 = COL_ACCENT
                edge.AnchorPoint = Vector2.new(0, 1); edge.Position = UDim2.new(0, 0, 1, 0); edge.Size = UDim2.new(0, 40, 0, 2); edge.ZIndex = tb[1].ZIndex + 2
                edge:SetAttribute("Skinned", true); edge.Parent = tb[1]
            end
            if edge then
                edge.Visible = currentStashTab == tb[2]
                task.defer(function() if tb[1].Parent then edge.Size = UDim2.new(0, math.max(12, tb[1].TextBounds.X), 0, 2) end end) -- (under the word)
            end
        end
        do -- (UI CLEAN INV: the word + its count in the muted colour, as the target)
            local mh = UIStyle.Colors.Muted:ToHex()
            tabW.Text = string.format('WEAPONS <font color="#%s">%d</font>', mh, #(clientState.Inventory or {}))
            tabG.Text = string.format('GEAR <font color="#%s">%d</font>', mh, #(clientState.GearInventory or {}))
            local cu = UI.invUi and UI.invUi.Cur
            if cu then
                local mats = clientState.Materials or {}
                cu.Gold.Text = ItemData.FormatNumber(clientState.Gold or 0); cu.Scrap.Text = tostring(mats.Scrap or 0)
                cu.Alloy.Text = tostring(mats.Alloy or 0); cu.Prism.Text = tostring(mats.Prism or 0); cu.SP.Text = tostring(clientState.SkillPoints or 0)
            end
        end
        for _, t in ipairs({ tabW, tabG, UI.invTabI, UI.invTabS }) do t.TextWrapped = false end -- (UI CLEAN: one line)
        local HDm = require(sharedFolder:WaitForChild("HideoutData"))
        local home = UI.InOwnHideout and UI.InOwnHideout() or false
        if UI.LayoutStashUpTo then UI.LayoutStashUpTo(currentStashTab == "Items", home) end -- (QOL L7)
        if currentStashTab == "Stash" and not home then currentStashTab = "Weapons" end
        local hst = type(clientState.Hideout) == "table" and clientState.Hideout or {}
        -- (UPDATE 7 STASH TABS: UI.stashTab picks the tab; StashTabs owns the rules + the strip / skins view)
        UI.StashTabs = UI.StashTabs or require(sharedFolder:WaitForChild("StashTabs"))
        UI.stashTab = UI.stashTab or "STASH"
        local stashBox = UI.StashTabs.Box(clientState, UI.stashTab) or ((UI.stashTab == "SKINS") and {} or (type(hst.Stash) == "table" and hst.Stash or {}))
        local stashCap = UI.StashTabs.Cap(clientState, UI.stashTab)
        UI.invTabS.Text = "STASH " .. HDm.StashCount(clientState)
        UI.invTabS.TextColor3 = (currentStashTab == "Stash") and UIStyle.Colors.Text or (home and UIStyle.Colors.Sub or UIStyle.Colors.Muted)
        if UI.InvL and UI.invUi then UI.InvL.SetNav(UI.invUi, (currentStashTab == "Stash") and "STASH" or "INVENTORY") end -- (UI CLEAN R-B)
        local bagN = ItemData.BagCount(clientState)
        UI.invBagLbl.Text = (currentStashTab == "Stash") and ((UI.stashTab == "SKINS") and "SKINS" or string.format("%s %d / %d", UI.stashTab == "STASH" and "STASH" or "TAB", UI.StashTabs.Count(stashBox), stashCap)) or string.format("%d / %d", bagN, ItemData.BagCap(clientState))
        UI.invBagLbl.TextColor3 = (bagN >= ItemData.BagCap(clientState) and currentStashTab ~= "Stash") and UIStyle.Colors.Bad or COL_DIM
        -- the search: every word must appear in the item's name / gun / type / rarity / stat lines
        local query = string.lower(UI.invSearch and UI.invSearch.Text or "")
        local words = {}
        for w in string.gmatch(query, "%S+") do table.insert(words, w) end
        local function Matches(it: any, isGear: boolean): boolean
            if #words == 0 then return true end
            local parts = { tostring(it.Name), tostring(it.BaseId), tostring(it.Rarity) }
            if isGear then
                table.insert(parts, tostring(ItemData.GearType(it.Slot)))
                table.insert(parts, tostring(ItemData.GearBaseNames[ItemData.GearType(it.Slot)] or ""))
                for _, l in ipairs(it.StatLines or {}) do table.insert(parts, ItemData.FormatStat(l.Stat, l.Value)) end
            else
                table.insert(parts, ItemData.WeaponTypeLine(it))
                for _, list in ipairs({ it.Prefixes, it.Suffixes, it.Affixes }) do
                    for _, a in ipairs(type(list) == "table" and list or {}) do if type(a) == "table" and a.Stat then table.insert(parts, ItemData.FormatStat(a.Stat, a.Value or 0)) end end
                end
                if type(it.UniqueTrait) == "table" then table.insert(parts, tostring(it.UniqueTrait.Name)) end
                if type(it.Proc) == "table" then table.insert(parts, tostring(it.Proc.Id)) end
            end
            local hay = string.lower(table.concat(parts, " "))
            for _, w in ipairs(words) do if not string.find(hay, w, 1, true) then return false end end
            return true
        end
        local function StoreButton(row: Instance, uid: string, kind: string)
            if not home then return end
            local b = SmallButton(row, "STASH", UIStyle.Colors.Steel, 52)
            b.Position = UDim2.new(1, -204, 0.5, -12)
            b.MouseButton1Click:Connect(function()
                SoundHelper.Play("Click")
                local ok, why = Remotes.GetFunction("HideoutAction"):InvokeServer("Store", uid, kind, (UI.stashTab ~= "SKINS") and UI.stashTab or "STASH")
                if not ok and why then ShowToast(why) end
            end)
        end

        -- ===== Loadout: the 10 identical slot cards + the left column's identity / power numbers (UI CLEAN INV) =====
        local currW = clientState.EquippedWeapon
        do
            local P = UI.paperSlots
            local IL = UI.InvL or require(sharedFolder:WaitForChild("InvLayout"))
            local FN = ItemData.FormatNumber
            local touchX = GameSettings.TouchOnly() or (UI.PadMenus ~= nil and UI.PadMenus.IsPad())
            local function Fill(key: string, item: any, isGear: boolean, sub: string)
                local sl = P[key]
                if not sl then return end
                sl.ShowX = touchX
                IL.PaintSlot(sl, item, item and ItemData.ItemColor(item) or nil, item and ItemData.DisplayName(item) or nil, sub, isGear)
            end
            Fill("Weapon", currW, false, currW and string.format("%s DPS  ·  iLvl %d", FN(ItemData.CalculateTrueDPS(currW)), currW.ItemLevel or 1) or "")
            for _, slotName in ipairs(ItemData.GEAR_EQUIP_SLOTS) do -- (UPDATE 8: + Gloves)
                local g = clientState.EquippedGear and clientState.EquippedGear[slotName]
                local sub = ""
                if g then
                    local first = g.StatLines and g.StatLines[1]
                    local gd = ItemData.GearDefOf(g)
                    local parts = {}
                    if gd.Plating > 0 then table.insert(parts, FN(gd.Plating) .. " plating") end
                    if gd.Agility > 0 then table.insert(parts, FN(gd.Agility) .. " agility") end
                    if gd.Ward > 0 then table.insert(parts, FN(gd.Ward) .. " ward") end
                    local lead = (#parts > 0) and table.concat(parts, " ") or (g.Implicit and ItemData.FormatStat(g.Implicit.Stat, g.Implicit.Value or 0)) or (first and ItemData.FormatStat(first.Stat, first.Value)) or ""
                    sub = (lead ~= "" and (lead .. "  ·  ") or "") .. "iLvl " .. (g.ItemLevel or 1)
                end
                Fill(slotName, g, true, sub)
            end
            local md = ItemData.MeleeWeapons[clientState.EquippedKnife or "Knife"] or ItemData.MeleeWeapons.Knife
            if P.Melee then
                P.Melee.ShowX = false
                IL.PaintSlot(P.Melee, md, ItemData.RarityColors[md.Rarity] or UIStyle.Colors.Text, md.Name or "Combat Knife", FN(stats.MeleeDamage or 0) .. " damage", false,
                    IL.IconFor({ Kind = "Melee", Id = md.Id }, "Melee"))
            end
            -- the left column: who you are + the power numbers (summary before detail)
            local dps = stats.Damage * stats.FireRate * math.max(1, stats.PelletCount or 1) * math.max(1, stats.BurstCount or 1) * (1 + stats.CritChance * (stats.CritMultiplier - 1))
            if UI.invId then
                local CD = require(sharedFolder:WaitForChild("ClassData"))
                local cls = clientState.Class and CD.ById[clientState.Class]
                local tdef = clientState.EquippedTitle and ItemData.Titles and ItemData.Titles[clientState.EquippedTitle]
                local tcol = (tdef and tdef.Color) or UIStyle.Colors.Gold
                local meta = "LEVEL " .. tostring(clientState.Level or 1) .. (cls and ("  ·  " .. string.upper(cls.Id)) or "")
                    .. (tdef and string.format('  ·  <font color="#%s">%s</font>', tcol:ToHex(), string.upper(tdef.Title or tdef.Name or "")) or "")
                local totalsA = ItemData.AttrTotals(stats)
                local atCap = (clientState.Level or 1) >= ItemData.MAX_LEVEL
                UI.invId.Set({
                    Icon = (cls and UIStyle.Icons[cls.IconKey]) or UIStyle.Icons.g_aim or "", -- (no class picked yet: the aim glyph)
                    Name = string.upper(LocalPlayer.DisplayName),
                    Meta = meta,
                    Xp = atCap and 1 or ((clientState.XP or 0) / math.max(1, clientState.MaxXP or 1)),
                    Dps = FN(dps),
                    Pair = { HEALTH = FN(math.floor((stats.MaxHP or 100) + 0.5)), PLATING = FN(math.round(stats.Plating or stats.Armor or 0)),
                        EVADE = math.round((stats.EvadeChance or 0) * 100) .. "%", CRIT = FN(stats.CritChance * 100) .. "%" },
                    Attr = { STR = tostring(math.floor(totalsA.Strength or 10)), DEX = tostring(math.floor(totalsA.Dexterity or 10)), INT = tostring(math.floor(totalsA.Intellect or 10)) },
                    Rows = { { "Weak-spot damage", FN(stats.WeakSpotMultiplier * 100) .. "%" }, { "Crit damage", "+" .. FN((stats.CritMultiplier - 1) * 100) .. "%" },
                        { "Fire rate", string.format("%.1f/s", stats.FireRate) }, { "Magazine", tostring(stats.MagazineSize) } },
                })
            end
        end

        -- ===== Bag =====
        for _, c in ipairs(stashScroll:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local tileTab = currentStashTab == "Weapons" or currentStashTab == "Gear"
        local bagHost = (tileTab and UI.bagGrid) or stashScroll -- (UI CLEAN INV: weapons + gear = the image-tile grid)
        if UI.bagGrid then
            for _, c in ipairs(UI.bagGrid:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
            UI.bagGrid.Visible = tileTab
            stashScroll.Visible = not tileTab
        end
        local mode = sortModes[sortIdx]
        if currentStashTab == "Stash" then
            -- (UPDATE 7) the tab strip + BUY TAB, then the tab's items (SKINS: your tradeable skins)
            UI.StashTabs.RenderStrip(stashScroll, clientState, UI.stashTab, function(id)
                SoundHelper.Play("Click"); UI.stashTab = id; UI.stashBuyOpen = false; RefreshInventory()
            end, function()
                SoundHelper.Play("Click"); UI.stashBuyOpen = not UI.stashBuyOpen; RefreshInventory()
            end, function() -- (UPDATE 7 C7: the MARKET button)
                SoundHelper.Play("Click"); if UI.OpenMarket then UI.OpenMarket() end
            end)
            if UI.stashBuyOpen then
                UI.BuyStashTab = UI.BuyStashTab or function(kind)
                    local d = UI.StashTabs.Kinds[kind] or {}
                    require(sharedFolder:WaitForChild("BoundShop")).Confirm({ Name = tostring(d.Name or kind) .. " TAB", Price = d.BP or 0, Desc = d.Text,
                        OnBuy = function() -- (BoundShop: the price + your balance first, then the server charges)
                            local ok, why = Remotes.GetFunction("HideoutAction"):InvokeServer("BuyTab", kind, "BP")
                            if ok then ShowToast(tostring(why or "Tab bought.")); UI.stashBuyOpen = false end
                            return ok, why
                        end })
                end
                UI.StashTabs.RenderBuy(stashScroll, clientState, function(kind, cur)
                    SoundHelper.Play("Click")
                    UI.BuyStashTab(kind)
                end)
            end
          if UI.stashTab == "SKINS" then
            UI.StashTabs.RenderSkins(stashScroll, clientState)
          else
            -- the HIDEOUT STASH: weapons then gear, TAKE moves one into your bag
            local entries = {}
            for _, w in ipairs(type(stashBox.W) == "table" and stashBox.W or {}) do if Matches(w, false) then table.insert(entries, { It = w, Gear = false }) end end
            for _, g in ipairs(type(stashBox.G) == "table" and stashBox.G or {}) do if Matches(g, true) then table.insert(entries, { It = g, Gear = true }) end end
            table.sort(entries, function(a, b)
                local ra, rb = RarityRankOf(a.It), RarityRankOf(b.It)
                if ra ~= rb then return ra > rb end
                return (a.It.ItemLevel or 1) > (b.It.ItemLevel or 1)
            end)
            for i, e in ipairs(entries) do
                local it = e.It
                local summary = e.Gear and ((ItemData.GearBaseNames[ItemData.GearType(it.Slot)] or "Gear") .. "  •  iLvl " .. (it.ItemLevel or 1))
                    or string.format("%s  •  iLvl %d  •  %s DPS", ItemData.WeaponTypeLine(it), it.ItemLevel or 1, ItemData.FormatNumber(ItemData.CalculateTrueDPS(it)))
                local row = ItemRow(stashScroll, i, it, e.Gear, summary)
                local b = SmallButton(row, "TAKE", COL_ACCENT, 60)
                b.Position = UDim2.new(1, -66, 0.5, -12)
                b.MouseButton1Click:Connect(function()
                    SoundHelper.Play("Click")
                    local ok, why = Remotes.GetFunction("HideoutAction"):InvokeServer("Take", it.Uid, e.Gear and "Gear" or "Weapon", UI.stashTab)
                    if not ok and why then ShowToast(why) end
                end)
            end
            if #entries == 0 then
                local l = Label(stashScroll, (#words > 0) and "Nothing in this tab matches that." or "This tab is empty. Use STASH on items in your bag to store them in the tab you have open.", 13, COL_DIM, UIStyle.BodyFont, Enum.TextXAlignment.Center)
                l.Size = UDim2.new(1, 0, 0, 40); l.TextWrapped = true
            end
          end
        elseif currentStashTab == "Items" then
            UI.RenderItemsBag(stashScroll)
            -- (UPDATE 7 RIFTMODS: their list + FIT / REROLL / SALVAGE under the items)
            require(sharedFolder:WaitForChild("Riftmods")).Render(stashScroll, clientState, function(action, a, b)
                SoundHelper.Play("Click")
                task.spawn(function()
                    local ok, msg = Remotes.GetFunction("RiftmodAction"):InvokeServer(action, a, b)
                    if msg then ShowToast(tostring(msg)) end
                end)
            end)
            if UI.ShotModsBag then UI.ShotModsBag(stashScroll) end -- (UPDATE 8 OFFENSE phase 3: the MODS block + OPEN MODS)
        elseif currentStashTab == "Weapons" then
            local items = {}
            for _, it in ipairs(clientState.Inventory or {}) do if Matches(it, false) then table.insert(items, it) end end
            if mode == "RARITY" then table.sort(items, function(a, b) local ra, rb = RarityRankOf(a), RarityRankOf(b); if ra ~= rb then return ra > rb end return (a.ItemLevel or 1) > (b.ItemLevel or 1) end)
            elseif mode == "LEVEL" then table.sort(items, function(a, b) return (a.ItemLevel or 1) > (b.ItemLevel or 1) end)
            elseif mode == "DPS / ARMOR" then table.sort(items, function(a, b) return ItemData.CalculateTrueDPS(a) > ItemData.CalculateTrueDPS(b) end)
            else
                local rev = {}
                for i = #items, 1, -1 do table.insert(rev, items[i]) end
                items = rev
            end
            local currDPS = currW and ItemData.CalculateTrueDPS(currW) or 0
            for i, item in ipairs(items) do
                local isEq = currW and item.Uid == currW.Uid
                local dps = ItemData.CalculateTrueDPS(item)
                local badge = isEq and "   •   EQUIPPED" or (dps > currDPS * 1.02 and "  ▲" or "")
                local row = ItemRow(bagHost, i, item, false, string.format("%s  •  iLvl %d  •  %s DPS", ItemData.WeaponTypeLine(item), item.ItemLevel or 1, ItemData.FormatNumber(dps)), badge)
                if not isEq then
                    StoreButton(row, item.Uid, "Weapon")
                    local eqB = SmallButton(row, "EQUIP", COL_ACCENT, 52) -- (UI CLEAN: the row's primary action)
                    eqB.Position = UDim2.new(1, -148, 0.5, -12)
                    eqB.MouseButton1Click:Connect(function()
                        SoundHelper.Play("Equip")
                        Remotes.GetFunction("EquipWeapon"):InvokeServer(item.Uid)
                        clientState.EquippedWeapon = item
                        RebuildViewmodelForWeapon(item)
                        UpdateWeaponHUD()
                        RefreshInventory()
                    end)
                    local sellB = SmallButton(row, tostring(ItemData.GetSellValue(item)) .. "g", UIStyle.Colors.Steel, 50)
                    sellB.TextColor3 = UIStyle.Colors.Gold -- (gold = currency)
                    sellB.Position = UDim2.new(1, -92, 0.5, -12)
                    sellB.MouseButton1Click:Connect(function()
                        local function Go(zenOk: boolean?) -- (ZENITH: the server wants the confirm flag; UI.Zen.SellAsk asks first)
                            SoundHelper.Play("Coin")
                            local ok, g = Remotes.GetFunction("SellWeapon"):InvokeServer(item.Uid, zenOk)
                            if ok then ShowToast("Sold " .. item.Name .. " for +" .. g .. " gold"); RefreshInventory() end
                        end
                        if not (UI.Zen and UI.Zen.SellAsk(item, false, false, Go)) then Go(nil) end
                    end)
                    local disB = SmallButton(row, "", UIStyle.Colors.Steel, 36) -- (0.61f: custom scrap icon, not the Roblox gear emoji)
                UIStyle.Icon("cur_scrap", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), Parent = disB })
                    disB.Position = UDim2.new(1, -40, 0.5, -12)
                    disB.MouseButton1Click:Connect(function()
                        local function Go(zenOk: boolean?)
                            SoundHelper.Play("Coin")
                            local ok = Remotes.GetFunction("DismantleItem"):InvokeServer(item.Uid, "Weapon", zenOk)
                            if ok then RefreshInventory() end -- the materials popup shows what it gave
                        end
                        if not (UI.Zen and UI.Zen.SellAsk(item, false, true, Go)) then Go(nil) end
                    end)
                end
            end
            if #items == 0 then -- (UI v4: an empty list says so, calmly)
                if UI.bagGrid then UI.bagGrid.Visible = false; stashScroll.Visible = true end
                UIStyle.EmptyState(stashScroll, (#words > 0) and "Nothing matches" or "No weapons", (#words > 0) and "Try fewer words in the search." or "Guns you find in runs land here.", { Size = UDim2.new(1, -6, 0, 120) })
            end
        else
            local items = {}
            for _, it in ipairs(clientState.GearInventory or {}) do if Matches(it, true) then table.insert(items, it) end end
            if mode == "RARITY" then table.sort(items, function(a, b) local ra, rb = RarityRankOf(a), RarityRankOf(b); if ra ~= rb then return ra > rb end return (a.ItemLevel or 1) > (b.ItemLevel or 1) end)
            elseif mode == "LEVEL" then table.sort(items, function(a, b) return (a.ItemLevel or 1) > (b.ItemLevel or 1) end)
            elseif mode == "DPS / ARMOR" then table.sort(items, function(a, b) return (a.Armor or 0) > (b.Armor or 0) end)
            else
                local rev = {}
                for i = #items, 1, -1 do table.insert(rev, items[i]) end
                items = rev
            end
            for i, g in ipairs(items) do
                local gType = ItemData.GearType(g.Slot)
                local first = g.StatLines and g.StatLines[1]
                local gb = ItemData.GearBaseOf(g) -- (UPDATE 8 GEAR v3: the base's name + defence type)
                local summary = (gb and (gb.Name .. (gb.Def and (" (" .. ItemData.GEAR_DEF_WORD[gb.Def] .. ")") or "")) or ItemData.GearBaseNames[gType] or gType) .. "  •  iLvl " .. (g.ItemLevel or 1)
                    .. ((g.Armor or 0) > 0 and ("  •  " .. g.Armor .. " Plating") or (first and ("  •  " .. ItemData.FormatStat(first.Stat, first.Value)) or ""))
                local row = ItemRow(bagHost, i, g, true, summary, UI.GearBadge and UI.GearBadge(g) or nil) -- (QOL2 I4: ▲ = a gear upgrade)
                StoreButton(row, g.Uid, "Gear")
                local function Equip(target: string?)
                    SoundHelper.Play("Equip")
                    Remotes.GetFunction("EquipGear"):InvokeServer(g.Uid, target)
                    UpdateWeaponHUD()
                end
                if gType == "Ring" then
                    local r1 = SmallButton(row, "R1", C(0, 130, 190), 25)
                    r1.Position = UDim2.new(1, -148, 0.5, -12)
                    r1.MouseButton1Click:Connect(function() Equip("Ring1") end)
                    local r2 = SmallButton(row, "R2", C(0, 130, 190), 25)
                    r2.Position = UDim2.new(1, -121, 0.5, -12)
                    r2.MouseButton1Click:Connect(function() Equip("Ring2") end)
                else
                    local eqB = SmallButton(row, "EQUIP", C(0, 130, 190), 52)
                    eqB.Position = UDim2.new(1, -148, 0.5, -12)
                    eqB.MouseButton1Click:Connect(function() Equip(nil) end)
                end
                local sellB = SmallButton(row, tostring(ItemData.GetGearSellValue(g)) .. "g", C(150, 45, 45), 50)
                sellB.Position = UDim2.new(1, -92, 0.5, -12)
                sellB.MouseButton1Click:Connect(function()
                    local function Go(zenOk: boolean?) -- (ZENITH: confirm first)
                        SoundHelper.Play("Coin")
                        local ok, gold = Remotes.GetFunction("SellGear"):InvokeServer(g.Uid, zenOk)
                        if ok then ShowToast("Sold " .. g.Name .. " for +" .. gold .. " gold"); RefreshInventory() end
                    end
                    if not (UI.Zen and UI.Zen.SellAsk(g, true, false, Go)) then Go(nil) end
                end)
                local disB = SmallButton(row, "", C(110, 75, 150), 36) -- (0.61f: custom scrap icon, not the Roblox gear emoji)
                UIStyle.Icon("cur_scrap", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), Parent = disB })
                disB.Position = UDim2.new(1, -40, 0.5, -12)
                disB.MouseButton1Click:Connect(function()
                    local function Go(zenOk: boolean?)
                        SoundHelper.Play("Coin")
                        local ok = Remotes.GetFunction("DismantleItem"):InvokeServer(g.Uid, "Gear", zenOk)
                        if ok then RefreshInventory() end
                    end
                    if not (UI.Zen and UI.Zen.SellAsk(g, true, true, Go)) then Go(nil) end
                end)
            end
            if #items == 0 then -- (UI v4: an empty list says so, calmly)
                if UI.bagGrid then UI.bagGrid.Visible = false; stashScroll.Visible = true end
                UIStyle.EmptyState(stashScroll, (#words > 0) and "Nothing matches" or "No gear", (#words > 0) and "Try fewer words in the search." or "Helmets, chest pieces, rings and more drop in runs.", { Size = UDim2.new(1, -6, 0, 120) })
            end
        end
    end

    -- ==================== [MENU 4: ROTATING 5-MINUTE ARMORY SHOP] ====================
    UI.shopFrame = Instance.new("Frame")
    UI.shopFrame.Name = "ShopMenu"
    UI.shopFrame.Size = UDim2.new(0, 720, 0, 460)
    UI.shopFrame.Position = UDim2.new(0.5, -360, 0.5, -230)
    UI.shopFrame.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
    UI.shopFrame.BorderSizePixel = 2
    UI.shopFrame.BorderColor3 = Color3.fromRGB(255, 180, 20)
    UI.shopFrame.Visible = false
    UI.shopFrame.Parent = UI.menuFolder
    ApplyPanelChrome(UI.shopFrame, Color3.fromRGB(255, 180, 20), 12)

    local shopHeader = Instance.new("TextLabel")
    shopHeader.Size = UDim2.new(1, 0, 0, 40); shopHeader.BackgroundColor3 = Color3.fromRGB(24, 30, 42); shopHeader.Font = Enum.Font.GothamBold; shopHeader.TextSize = 19; shopHeader.TextColor3 = Color3.fromRGB(255, 200, 40); shopHeader.Text = "SHOP  (your own stock, restocks every hour)  [B / ESC to Close]"; shopHeader.Parent = UI.shopFrame
    UI.windowHeaders = UI.windowHeaders or {}; UI.windowHeaders[UI.shopFrame] = shopHeader

    local shopTimerLbl = Instance.new("TextLabel")
    shopTimerLbl.Size = UDim2.new(1, -20, 0, 24); shopTimerLbl.Position = UDim2.new(0, 10, 0, 44); shopTimerLbl.BackgroundTransparency = 1; shopTimerLbl.Font = Enum.Font.GothamBold; shopTimerLbl.TextSize = 14; shopTimerLbl.RichText = true; shopTimerLbl.TextColor3 = Color3.fromRGB(0, 255, 200); shopTimerLbl.Text = "NEXT RESTOCK IN: 60:00"; shopTimerLbl.Parent = UI.shopFrame

    local shopScroll = Instance.new("ScrollingFrame")
    shopScroll.Size = UDim2.new(1, -20, 1, -80); shopScroll.Position = UDim2.new(0, 10, 0, 72); shopScroll.BackgroundColor3 = Color3.fromRGB(10, 12, 18); shopScroll.BorderSizePixel = 1; shopScroll.BorderColor3 = Color3.fromRGB(50, 60, 80); shopScroll.ScrollBarThickness = 6; shopScroll.Parent = UI.shopFrame

    RefreshShopMenu = function()
        local stock, timeLeft, odds = Remotes.GetFunction("GetShopStock"):InvokeServer()
        local mins = math.floor((timeLeft or 0) / 60)
        local secs = (timeLeft or 0) % 60
        local oddsText = {}
        for _, o in ipairs(odds or {}) do
            table.insert(oddsText, string.format('<font color="#%s">%s %s%%</font>', (ItemData.RarityColors[o[1]] or Color3.new(1, 1, 1)):ToHex(), o[1], tostring(o[2])))
        end
        shopTimerLbl.Text = string.format("RESTOCK IN %02d:%02d  |  GOLD: %s  |  ", mins, secs, ItemData.FormatNumber(clientState.Gold or 0)) .. table.concat(oddsText, "  ")

        for _, c in ipairs(shopScroll:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        shopScroll.CanvasSize = UDim2.new(0, 0, 0, #(stock or {}) * 64 + 10)

        for idx, entry in ipairs(stock or {}) do
            local item = entry.Item
            local price = entry.Price

            local card = Instance.new("Frame")
            card.Size = UDim2.new(0.96, 0, 0, 56); card.Position = UDim2.new(0.02, 0, 0, (idx - 1) * 64 + 4); card.BackgroundColor3 = Color3.fromRGB(20, 25, 36); card.BorderSizePixel = 1; card.BorderColor3 = ItemData.RarityColors[item.Rarity]; card.Parent = shopScroll
            if UI.HookItemTooltip then UI.HookItemTooltip(card, item, entry.Type ~= "Weapon") end

            local info = Instance.new("TextLabel")
            info.Size = UDim2.new(1, -140, 1, 0); info.Position = UDim2.new(0, 8, 0, 0); info.BackgroundTransparency = 1; info.Font = Enum.Font.GothamMedium; info.TextSize = 15; info.TextColor3 = ItemData.RarityColors[item.Rarity]; info.TextXAlignment = Enum.TextXAlignment.Left
            if entry.Type == "Weapon" then
                local traitTag = item.UniqueTrait and (" | ★ " .. item.UniqueTrait.Name) or ""
                info.Text = ItemData.DisplayName(item) .. traitTag .. "   •   " .. ItemData.RarityLabel(item) .. " " .. ItemData.WeaponTypeLine(item) .. "  •  iLvl " .. (item.ItemLevel or 1) .. "\nDPS " .. ItemData.FormatNumber(ItemData.CalculateTrueDPS(item)) .. "  •  DMG " .. ItemData.FormatNumber(ItemData.GunDamage(item)) .. "  •  " .. item.BaseFireRate .. "/s"
            else
                local sLines = {}
                for _, line in ipairs(ItemData.DescribeGear(item).Lines) do
                    if line.Kind ~= "note" then table.insert(sLines, line.Text) end
                end
                info.Text = ItemData.DisplayName(item) .. "   •   " .. ItemData.RarityLabel(item) .. "  •  iLvl " .. (item.ItemLevel or 1) .. "\n" .. table.concat(sLines, "  •  ")
            end
            info.Parent = card

            local btnBuy = Instance.new("TextButton")
            btnBuy.Size = UDim2.new(0, 110, 0, 30); btnBuy.Position = UDim2.new(1, -120, 0.5, -15)
            btnBuy.BackgroundColor3 = (clientState.Gold >= price) and Color3.fromRGB(230, 140, 20) or Color3.fromRGB(60, 60, 70)
            btnBuy.Font = Enum.Font.GothamBold; btnBuy.TextSize = 16; btnBuy.TextColor3 = Color3.fromRGB(255, 255, 255); btnBuy.Text = "BUY " .. price .. "g"; btnBuy.Parent = card

            btnBuy.MouseButton1Click:Connect(function()
                SoundHelper.Play("Click")
                local ok, err = Remotes.GetFunction("BuyShopItem"):InvokeServer(item.Uid)
                if ok then
                    SoundHelper.Play("Purchase")
                    ShowToast("Purchased " .. item.Name .. "!")
                    RefreshShopMenu()
                    RefreshInventory()
                else
                    ShowToast(tostring(err))
                end
            end)
        end
    end

    Remotes.GetEvent("ShopRefreshed").OnClientEvent:Connect(function()
        if UI.shopFrame.Visible then RefreshShopMenu() end
    end)

    -- ==================== [MENU 5: THE FORGE] ====================
    -- Was just a single "+12% damage forever" button. Now three real levers on the equipped weapon:
    -- Upgrade (capped, same as before), Reroll (spend Forge Cores + Gold to re-roll its affixes without
    -- losing rarity/level), and Raise Item Level (catch this weapon's own item level up to your
    -- character level, rescaling its stats with it). Dismantling unwanted items for Forge Cores is
    -- done from the inventory list itself (see RefreshInventory's per-item Dismantle button).
    -- The Forge (ForgeMenu module): upgrades, reforge / tune / prefix crafting and re-leveling for any weapon.
    local ForgeMenu = require(sharedFolder:WaitForChild("ForgeMenu"))
    local forge = ForgeMenu.Build(UI.menuFolder, {
        GetState = function() return clientState end,
        OnItemChanged = function(w)
            local eq = clientState.EquippedWeapon
            if eq and w and eq.Uid == w.Uid then
                clientState.EquippedWeapon = w
                UpdateWeaponHUD()
            end
            if RefreshInventory and UI.invFrame.Visible then RefreshInventory() end
        end,
        PlayClick = function() SoundHelper.Play("Click") end,
        PlaySuccess = function() SoundHelper.Play("Craft") end, -- (v4 game sounds: a Forge craft has its own sound)
        PlayFail = function() SoundHelper.Play("Empty") end,
        OnClose = function() CloseAllMenus() end,
        ItemCard = function(host, item, isGear) if UI.CardInto then UI.CardInto(host, item, isGear) end end, -- (UI CLEAN R-B2: the inventory's card in the Forge)
    })
    UI.upgFrame = forge.Frame
    UI.Forge = forge
    RefreshUpgradeMenu = forge.Refresh

    -- ==================== [MENU 6: DUNGEONS LOBBY (solo / friends / public rooms)] ====================
    local LobbyMenu = require(sharedFolder:WaitForChild("LobbyMenu"))
    UI.StartSolo = function(biome, diff, botSkill) -- (the Dungeons window's START; also Studio DevAct "startrun:<diff>[:<skill>]")
        UI.noGateUntil = os.clock() + 10 -- (the gate you're standing in can't pop this window back open mid-load)
        currentRaidBiome, currentRaidFloor = biome, 1
        currentRaidDiff, UI.runEndless = ItemData.ParseRunKey(diff)
        task.spawn(function()
            if not DungeonClient.EnterFloor(biome, diff, 1, botSkill) then ShowToast("Couldn't start the dungeon. Try again.") end
        end)
    end
    local lobby = LobbyMenu.Build(UI.menuFolder, {
        StartSolo = UI.StartSolo,
        PlayClick = function() SoundHelper.Play("Click") end,
        OnClose = function() CloseAllMenus() end,
        Toast = function(t) ShowToast(t) end,
        GetState = function() return clientState end,
        OpenFinder = function() if UI.OpenPartyFinder then UI.OpenPartyFinder() end end, -- (2026-10-20: ALL SERVERS)
    })
    UI.dungFrame = lobby.Frame

    -- ==================== GROUND LOOT (rarity beams + pickup card) ====================
    require(sharedFolder:WaitForChild("GroundLoot")).Init({
        GetState = function() return clientState end,
        PlaySound = function(name, part) if part then SoundHelper.PlayAt(name, part) else SoundHelper.Play(name) end end,
        Toast = function(t, important) ShowToast(t, important) end,
        InteractKey = function() return GameSettings.KeyFor("Interact") end,
        PickupAllKey = function() return string.upper(GameSettings.KeyLabel(GameSettings.BindName("PickupAll"))) end, -- (QOL L2)
        MenuOpen = function() return isAnyMenuOpen end, -- (PLAYTEST 2026-10-31: loot lines stay off open windows)
        Parent = hudGui,
    })
    ;(function() -- QOL L1 (2026-10-28): the exits warn while pickable drops are still on the ground (GroundLoot.LeaveGate)
        local GL = require(sharedFolder:WaitForChild("GroundLoot"))
        UI.LootGate = GL.LeaveGate
        UI.LootLeft = GL.LeftCount
        DungeonGeneratorShared.LeaveGate = function() return GL.LeaveGate() end -- (solo portals / extract, built on this client)
        -- QOL L2: PICK UP ALL NEARBY -- Key_PickupAll (default Z) or the pad's D-pad left, while playing (no window open)
        UserInputService.InputBegan:Connect(function(input)
            if input.KeyCode ~= Enum.KeyCode.DPadLeft and GameSettings.ActionForInput(input) ~= "PickupAll" then return end
            if GameSettings.IsTyping() or SettingsMenu.IsCapturingKey() or isAnyMenuOpen or UI.watching then return end
            task.spawn(GL.PickupNearby)
        end)
        -- Studio test hook (QOL loot pass): Player attr DevLoot = "left" | "gate" | "portal" | "exit" | "pickall" | "toast:<text>[|!]"
        -- -> DevLootResult (the MCP tools can't press keys / call this client's module copy)
        if game:GetService("RunService"):IsStudio() then
            LocalPlayer:GetAttributeChangedSignal("DevLoot"):Connect(function()
                local v = tostring(LocalPlayer:GetAttribute("DevLoot") or "")
                if v == "" then return end
                LocalPlayer:SetAttribute("DevLoot", nil)
                local r = ""
                if v == "left" then r = "left=" .. GL.LeftCount() .. " near=" .. GL.NearbyCount()
                elseif v == "gate" then r = "gate=" .. tostring(GL.LeaveGate())
                elseif v == "portal" then r = "portal=" .. tostring(DungeonGeneratorShared.LeaveGate(LocalPlayer, "portal"))
                elseif v == "exit" then UI.ExitAnywhere(UI.CloseAllMenus); UI.ExitAnywhere(UI.CloseAllMenus); r = "exit sent"
                elseif v == "pickall" then GL.PickupNearby(); r = "picked; left=" .. GL.LeftCount()
                elseif string.sub(v, 1, 6) == "toast:" then
                    local t = string.sub(v, 7)
                    local imp = string.sub(t, -2) == "|!"
                    ShowToast(imp and string.sub(t, 1, -3) or t, imp or nil); r = "toast"
                end
                LocalPlayer:SetAttribute("DevLootResult", r)
            end)
        end
    end)()
    ;(function() -- QOL L6 (2026-10-28): NEW markers -- items that reached your bag this session (LootAnnounce, not auto-sold)
        -- get a small accent dot on their inventory row until you hover the row, or open the bag and close it again (then
        -- every new row you were shown counts as seen). Client-side, per session.
        local newItems, shown = {}, {}
        local hooked = false
        UI.IsNewItem = function(uid) return uid ~= nil and newItems[uid] == true end
        Remotes.GetEvent("LootAnnounce").OnClientEvent:Connect(function(item, _comp, wasAutoSold)
            if not wasAutoSold and type(item) == "table" and item.Uid then newItems[item.Uid] = true end
        end)
        UI.MarkNew = function(row: GuiObject, item: any)
            local uid = type(item) == "table" and item.Uid
            if not uid or not newItems[uid] then return end
            if not hooked and UI.invFrame then
                hooked = true
                UI.invFrame:GetPropertyChangedSignal("Visible"):Connect(function()
                    if UI.invFrame.Visible then return end
                    for u in pairs(shown) do newItems[u] = nil end
                    table.clear(shown)
                end)
            end
            shown[uid] = true
            local dot = Instance.new("Frame")
            dot.Name = "NewDot"
            dot.Size = UDim2.fromOffset(7, 7)
            dot.Position = UDim2.fromOffset(11, 6)
            dot.BackgroundColor3 = UIStyle.Colors.Accent
            dot.BorderSizePixel = 0
            dot.ZIndex = row.ZIndex + 2
            dot:SetAttribute("Skinned", true)
            local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(1, 0); cr.Parent = dot
            dot.Parent = row
            local c; c = row.MouseEnter:Connect(function()
                newItems[uid] = nil
                shown[uid] = nil
                dot:Destroy()
                c:Disconnect()
            end)
        end
    end)()
    -- ==================== DUNGEON SAFE ZONE (server: CombatServer UpdateSafeZone) ====================
    -- While Player attribute SafeZone is set you can't be hurt (entry room); once SafeLocked, an energy barrier
    -- closes the doorway behind you until you're next placed in an entry room.
    do
        local layout = require(sharedFolder:WaitForChild("DungeonGenerator")).GetChamberLayout(false)
        local banner = Instance.new("TextLabel")
        banner.Name = "SafeZoneBanner"
        banner.AnchorPoint = Vector2.new(0.5, 0)
        -- (UI CLEAN R-C: the same plate as the floor banner, the banner's width, right under it; "SAFE ZONE" in Good words,
        -- the rule in Sub -- no green slab edge, no rounded box)
        banner.Position = UDim2.new(0.5, 0, 0, 64 + 34 + 4)
        banner.Size = UDim2.fromOffset(660, 26)
        banner.RichText = true
        banner.Text = string.format("<font color=\"#%s\"><b>SAFE ZONE</b></font>     <font color=\"#%s\">You can't be hurt (or shoot) until you walk out</font>",
            UIStyle.Colors.Good:ToHex(), UIStyle.Colors.Sub:ToHex())
        banner.Visible = false
        banner.Parent = hudGui
        UI.RunHud.Plate(banner)
        UI.RunHud.Role(banner, "Body", { Color = "Sub" }) -- (the rich text colours the words; the base colour is Sub)
        local barrier: BasePart? = nil
        local function Refresh()
            banner.Visible = LocalPlayer:GetAttribute("SafeZone") == true
            local locked = LocalPlayer:GetAttribute("SafeLocked") == true
            if locked and not barrier then
                local b = Instance.new("Part")
                b.Name = "SafeZoneBarrier"
                b.Anchored = true
                b.Size = Vector3.new(layout.CorridorWidth + 4, 20, 1)
                b.CFrame = CFrame.new(0, 12, layout.CorridorAStart - 3.3) -- (a few studs inside: it never appears on top of you; UPDATE 4: its back face sat ON the wall's inner face + the lintel's front -> flicker; now 0.3 clear of both)
                b.Material = Enum.Material.ForceField
                b.Color = Color3.fromRGB(90, 255, 200)
                b.Transparency = 0.2
                b.CanCollide = true
                b.CanQuery = false -- shots and bot sight lines aren't blocked by it
                b.CastShadow = false
                b.Parent = Workspace
                barrier = b
            elseif not locked and barrier then
                barrier:Destroy()
                barrier = nil
            end
        end
        LocalPlayer:GetAttributeChangedSignal("SafeZone"):Connect(Refresh)
        LocalPlayer:GetAttributeChangedSignal("SafeLocked"):Connect(Refresh)
        -- one-way: it only blocks you from the arena side, so you can never get stuck behind it
        RunService.Heartbeat:Connect(function()
            local root = barrier and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then barrier.CanCollide = root.Position.Z > barrier.Position.Z end
        end)
        Refresh()
    end

    -- ==================== HUB: live leaderboards + Training Grounds range ====================
    require(sharedFolder:WaitForChild("HubBoards")).Init()
    do
        local cachedStats, cachedAt = nil, 0
        UI.Range = require(sharedFolder:WaitForChild("RangeClient"))
        UI.Range.Init({
            GetState = function() return clientState end,
            GetStats = function()
                if not cachedStats or os.clock() - cachedAt > 1 then
                    local w = clientState.EquippedWeapon
                    cachedStats = w and StatCalculator.Calculate(w, clientState.AllocatedNodes, clientState.Streak, clientState.Level, clientState.Attributes, clientState.EquippedGear,
                        clientState.EquippedTitle, clientState.SocketedGems, clientState.RunBoons, clientState)
                    cachedAt = os.clock()
                end
                return cachedStats
            end,
            DamageText = function(...) SpawnDamageText(...) end,
            PlaySound = function(n) SoundHelper.Play(n) end,
            Parent = hudGui,
        })
    end

    -- ==================== [MENU 6b: CHALLENGES (Daily Challenge, Aim Trials, Mastery)] ====================
    UI.TrialRunner = require(sharedFolder:WaitForChild("TrialRunner"))
    local ChallengesMenu = require(sharedFolder:WaitForChild("ChallengesMenu"))
    local challenges
    challenges = ChallengesMenu.Build(UI.menuFolder, {
        GetState = function() return clientState end,
        PlayClick = function() SoundHelper.Play("Click") end,
        OnClose = function() CloseAllMenus() end,
        Toast = function(t) ShowToast(t) end,
        StartRift = function(uid)
            CloseAllMenus()
            task.spawn(function()
                local ok, msg = Remotes.GetFunction("StartRift"):InvokeServer(uid)
                if not ok then ShowToast(msg or "Couldn't open the map.") end
            end)
        end,
        StartBossTrial = function(id, tier, mode, weekly)
            CloseAllMenus()
            task.spawn(function()
                local ok, msg = Remotes.GetFunction("StartBossTrial"):InvokeServer(id, tier, mode, weekly == true) -- (UPDATE 7: the weekly boss)
                if not ok then ShowToast(msg or "Couldn't start the trial.") end
            end)
        end,
        StartAscTrial = function(tier, mode)
            CloseAllMenus()
            task.spawn(function()
                local ok, msg = Remotes.GetFunction("StartAscTrial"):InvokeServer(tier, mode)
                if not ok then ShowToast(msg or "Couldn't start the trial.") end
            end)
        end,
        StartDaily = function()
            CloseAllMenus()
            task.spawn(function()
                local ok, msg = Remotes.GetFunction("StartDailyChallenge"):InvokeServer()
                if not ok then ShowToast(msg or "Couldn't start the Daily Challenge.") end
            end)
        end,
        StartLine = function() -- (UPDATE 7 B6: THE DAILY LINE)
            CloseAllMenus()
            task.spawn(function()
                local ok, msg = Remotes.GetFunction("StartDailyLine"):InvokeServer()
                if not ok then ShowToast(msg or "Couldn't start the Gauntlet Run.") end
            end)
        end,
        StartTrial = function(id, diffId)
            if UI.TrialRunner.IsRunning() then return end
            CloseAllMenus()
            task.spawn(function()
                if UI.SetSlot then UI.SetSlot("Gun") end -- Aim Trials are gun-only
                UI.TrialRunner.Start(id, {
                    Teleport = TeleportClient,
                    LeaveKey = (GameSettings.KeyFor("ExitRun") or Enum.KeyCode.J).Name,
                    OnAborted = function(reason)
                        if reason == "quit" then ShowToast("Left the Aim Trial. No score recorded.") end
                    end,
                    SetActive = function(on) UI.TrialActive = on end,
                    Toast = function(t) ShowToast(t) end,
                    Sound = function(n) SoundHelper.Play(n) end,
                    Hit = function(head) SoundHelper.ChainHit(); if head then if GameSettings.Get("HeadHitSound") ~= "Off" then SoundHelper.Play("HitCrit") end elseif GameSettings.Get("HitSound") ~= "Off" then SoundHelper.Play("HitNormal") end; TriggerHitmarker(head) end, -- (0.93 trial hit feedback)
                    OnFinish = function(result, score, hits, shots)
                        if type(result) ~= "table" then
                            ShowToast(string.format("Trial over: %d points (not recorded)", score))
                            return
                        end
                        local AimTrials = require(sharedFolder:WaitForChild("AimTrials"))
                        local rank = AimTrials.RankName(result.Rank)
                        local msg = string.format("%s: %d points%s  •  %d/%d hits%s", AimTrials.ById[id].Name, result.Score, result.IsBest and " (NEW BEST!)" or "",
                            hits, shots, rank and ("  •  " .. string.upper(rank)) or "")
                        if #result.Unlocked > 0 then msg ..= "  •  unlocked " .. table.concat(result.Unlocked, ", ") .. "!" end
                        if result.Reward then msg ..= string.format("  •  +%d gold%s", result.Reward.Gold, (result.Reward.Scrap > 0) and (", +" .. result.Reward.Scrap .. " Scrap") or "") end
                        ShowToast(msg)
                        SoundHelper.Play(result.IsBest and "Victory" or "Upgrade")
                    end,
                }, diffId)
            end)
        end,
    })
    UI.challFrame = challenges.Frame
    if RunService:IsStudio() then
        -- Studio test hook: Player attribute DevTrial = "TRACKING:Standard" starts that Aim Trial (results print)
        LocalPlayer:GetAttributeChangedSignal("DevTrial"):Connect(function()
            local v = LocalPlayer:GetAttribute("DevTrial")
            if type(v) ~= "string" or v == "" or UI.TrialRunner.IsRunning() then return end
            LocalPlayer:SetAttribute("DevTrial", nil)
            local id, dId = string.match(v, "^(%w+):?(%w*)$")
            CloseAllMenus()
            task.spawn(function()
                if UI.SetSlot then UI.SetSlot("Gun") end
                UI.TrialRunner.Start(id, {
                    Teleport = TeleportClient, SetActive = function(on) UI.TrialActive = on end,
                    Toast = function(t) ShowToast(t) end, Sound = function(n) SoundHelper.Play(n) end,
                    Hit = function(head) SoundHelper.ChainHit(); if head then if GameSettings.Get("HeadHitSound") ~= "Off" then SoundHelper.Play("HitCrit") end elseif GameSettings.Get("HitSound") ~= "Off" then SoundHelper.Play("HitNormal") end; TriggerHitmarker(head) end, -- (0.93 trial hit feedback)
                    OnFinish = function(result, score, hits, shots)
                        LocalPlayer:SetAttribute("DevTrialResult", string.format("%s score %d hits %d/%d recorded=%s", id, score, hits, shots, tostring(type(result) == "table")))
                    end,
                }, dId ~= "" and dId or "Standard")
            end)
        end)
    end
    UI.challenges = challenges
    UI.Challenges = challenges
    -- the season stand's own window: the season journey alone (it used to open the Challenges window)
    UI.season = ChallengesMenu.Build(UI.menuFolder, {
        Only = "Season",
        GetState = function() return clientState end,
        PlayClick = function() SoundHelper.Play("Click") end,
        OnClose = function() CloseAllMenus() end,
        Toast = function(t) ShowToast(t) end,
    })
    UI.seasonFrame = UI.season.Frame

    -- ==================== [MENU 7: SETTINGS] ====================
    -- The window is generated from GameSettings.Defs (SettingsMenu module); values save with the player.
    -- Everything below just applies each setting to the game whenever it changes.
    UI.setFrame = SettingsMenu.Build(UI.menuFolder, {
        PlayClick = function() SoundHelper.Play("Click") end,
        OnClose = function() CloseAllMenus() end,
    })

    -- HUD crosshair
    local hudCross = { Dot = UI.crosshair, L = chL, R = chR, T = chT, B = chB }
    for _, k in ipairs({ "CrossColor", "CrossDot", "CrossLength", "CrossThickness", "CrossGap", "CrossOutline", "CrossOpacity" }) do
        GameSettings.OnChanged(k, function() SettingsMenu.DrawCrosshair(hudCross) end)
    end
    -- third-person hub: no crosshair (redrawn from the settings when you're back in first person)
    LocalPlayer:GetAttributeChangedSignal("ThirdPerson"):Connect(function()
        if LocalPlayer:GetAttribute("ThirdPerson") then
            for _, f in pairs(hudCross) do f.Visible = false end
            isAiming = false
            if UI.ActiveSlot and UI.ActiveSlot() == "Melee" and UI.SetSlot then UI.SetSlot("Gun") end -- melee out when walking into the hub: put it away
            -- (fixes 2026-10-16 #11, owner: inspecting skins in third person bugs your camera): inspects are first person
            -- only -- one still playing when the view pulls back out is cut off, so nothing of it rides into third person
            if realRig and realRig.AnimName == "Inspect" then realRig:Stop() end
        else
            for _, f in pairs(hudCross) do f.Visible = true end
            SettingsMenu.DrawCrosshair(hudCross)
        end
    end)
    -- (owner 2026-10-02: "when in the hub, make sure the crosshair isn't in the center of your screen") -- enforced, not just
    -- on the switch: joining straight into the hub, or a crosshair setting redrawing it there, used to leave it showing
    local crossForWatch = false -- (0.83: watching someone shows THEIR crosshair even though your body is in the hub)
    -- (0.84, owner: "Spectated players UI blocks the leave button, while spectating you can still interact with things and
    -- the hud and see text such as SHIFT LOCK: ON"): while watching, only the watched view's pieces stay up -- the
    -- crosshair, hitmarker, the spectate bar and toasts. Your own HUD (health bar over the STOP button, level card, dock,
    -- shift-lock hint ...), the movement pips and every interact prompt go away until you stop; keys are blocked in the
    -- key handler.
    local watchHidden: { [Instance]: boolean } = {}
    local keepWhileWatching: { [Instance]: boolean } = {}
    for _, f in pairs(hudCross) do keepWhileWatching[f] = true end
    local PromptService = game:GetService("ProximityPromptService")
    RunService.Heartbeat:Connect(function()
        if UI.watching then
            if not crossForWatch then
                crossForWatch = true
                for _, f in pairs(hudCross) do f.Visible = true end
                SettingsMenu.DrawCrosshair(hudCross)
            end
            for _, c in ipairs(hudGui:GetChildren()) do
                if c:IsA("GuiObject") and c.Visible and not keepWhileWatching[c] and c ~= UI.hitmarker
                    and c.Name ~= "SpectateWatchBar" and c.Name ~= "ToastLabel" and c.Name ~= "ToastStack" then -- (QOL L4: the stack)
                    watchHidden[c] = true
                    c.Visible = false
                end
            end
            local mv = LocalPlayer.PlayerGui:FindFirstChild("MovementHUD")
            if mv and mv:IsA("ScreenGui") and mv.Enabled then mv.Enabled = false; watchHidden[mv] = true end
            pcall(function() if PromptService.Enabled then PromptService.Enabled = false end end)
            return
        end
        if crossForWatch then -- (just stopped watching: give back what it hid)
            for g in pairs(watchHidden) do
                if g.Parent then
                    if g:IsA("ScreenGui") then g.Enabled = true else (g :: GuiObject).Visible = true end
                end
            end
            table.clear(watchHidden)
            pcall(function() PromptService.Enabled = true end)
        end
        crossForWatch = false
        if LocalPlayer:GetAttribute("ThirdPerson") then
            for _, f in pairs(hudCross) do if f.Visible then f.Visible = false end end
        end
    end)

    -- view & mouse
    GameSettings.OnChanged("FOV", function(v) v = math.clamp(tonumber(v) or 90, 70, 103); baseFOV = v; hudGui:SetAttribute("SavedFOV", v) end)
    GameSettings.OnChanged("Sensitivity", function(v) UserInputService.MouseDeltaSensitivity = v end)
    GameSettings.OnChanged("ADSMode", function() isAiming = false end)

    -- enemy look (the ENEMY VISUALS manager reads EnemyVisuals)
    local enemyFields = {
        EnemyOutline = "Outline", EnemyOutlineColor2 = "OutlineColor", EnemyThroughWalls = "ThroughWalls", EnemyFill2 = "Fill",
        EnemyBrightness = "Brightness", EnemyWeakSpotGlow = "WeakSpotGlow", EnemyHealthBars = "HealthBars",
    }
    for key, field in pairs(enemyFields) do
        GameSettings.OnChanged(key, function(v)
            if EnemyVisuals[field] ~= v then EnemyVisuals[field] = v; RefreshEnemyVisuals() end
        end)
    end

    -- graphics
    GameSettings.OnChanged("Shadows", function(v) Lighting.GlobalShadows = v and activeLightProfile == "Hub" and not require(sharedFolder:WaitForChild("QualityMode")).IsLow() end)
    -- (UPDATE 4 QualityMode, owner: "a low quality option in the settings for players with worse computers"): Low = no
    -- shadows, bloom, sun rays or terrain grass; tagged decoration is hidden / thinned by AimRngShared.QualityMode itself
    require(sharedFolder:WaitForChild("QualityMode")).OnChanged(function(low)
        Lighting.GlobalShadows = GameSettings.Get("Shadows") and activeLightProfile == "Hub" and not low
        pcall(function() (workspace.Terrain :: any).Decoration = not low end) -- (not scriptable in every client build: never break the rest)
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("BloomEffect") then (e :: any).Enabled = GameSettings.Get("PostFX") and not low end -- (by class: the place's own "Bloom" is reused by GetLightingEffect, so the name never matched)
            if e.Name == "AimRngRays" then (e :: any).Enabled = not low end
        end
    end)
    GameSettings.OnChanged("PostFX", function(v)
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("BloomEffect") then (e :: any).Enabled = v and not require(sharedFolder:WaitForChild("QualityMode")).IsLow() end
            if e.Name == "AimRngGrade" then (e :: any).Enabled = v end
        end
    end)

    -- interface scale (menus live inside the HUD gui, so they scale too)
    -- (x an automatic factor on short screens -- phones in landscape are ~360-430 px tall -- so the HUD doesn't overlap)
    local hudScale = Instance.new("UIScale")
    hudScale.Parent = hudGui
    local function ApplyHudScale()
        -- (0.89: UIStyle.HudAuto = height / 820, min 0.55, on the planned screen -- a DevPhone preview included)
        hudScale.Scale = (tonumber(GameSettings.Get("UIScale")) or 100) / 100 * UIStyle.HudAuto()
        if UIStyle.RefitAll then task.defer(UIStyle.RefitAll) end
    end
    GameSettings.OnChanged("UIScale", ApplyHudScale)
    ApplyHudScale()
    if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ApplyHudScale) end
    LocalPlayer:GetAttributeChangedSignal("DevPhone"):Connect(ApplyHudScale)

    -- FPS & ping readout
    do
        local perf = Instance.new("TextLabel")
        perf.Name = "PerfStats"
        perf.Position = UDim2.new(0, 14, 0, 62)
        perf.Size = UDim2.fromOffset(150, 20)
        perf.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
        perf.BackgroundTransparency = 0.35
        perf.Font = Enum.Font.Code
        perf.TextSize = 13
        perf.TextColor3 = Color3.fromRGB(170, 255, 170)
        perf.TextXAlignment = Enum.TextXAlignment.Left
        perf.Visible = false
        perf.Parent = hudGui
        RoundCorners(perf, 4)
        local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 6); pad.Parent = perf
        local frames, since = 0, os.clock()
        RunService.RenderStepped:Connect(function()
            if not perf.Visible then return end
            frames += 1
            local now = os.clock()
            if now - since >= 0.5 then
                local fps = frames / (now - since)
                frames, since = 0, now
                local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5)
                perf.Text = string.format("%d FPS  %d ms", math.floor(fps + 0.5), ping)
            end
        end)
        GameSettings.OnChanged("ShowFPS", function(v) perf.Visible = v end)
    end

    -- audio: one SoundGroup per category; SoundHelper / ViewmodelRig tag their own sounds, everything
    -- else that plays in the world counts as Combat & World.
    do
        local SoundService = game:GetService("SoundService")
        local groups = {}
        for _, cat in ipairs({ "Weapons", "Effects", "UI" }) do
            local g = SoundService:FindFirstChild("AimRngMix_" .. cat) or Instance.new("SoundGroup")
            g.Name = "AimRngMix_" .. cat
            g.Parent = SoundService
            groups[cat] = g
        end
        local settingFor = { Weapons = "VolWeapons", Effects = "VolEffects", UI = "VolUI" }
        local function ApplyVolumes()
            local master = GameSettings.Get("VolMaster") / 100
            for cat, g in pairs(groups) do g.Volume = master * GameSettings.Get(settingFor[cat]) / 100 end
        end
        for _, k in ipairs({ "VolMaster", "VolWeapons", "VolEffects", "VolUI" }) do GameSettings.OnChanged(k, ApplyVolumes) end

        -- catch-all: untagged sounds -> Combat & World; particle emitters thinned when Effects Detail is
        -- Reduced; proximity prompts ([E] at chests / portal) use the Interact key.
        local function Adopt(d: Instance)
            if d:IsA("Sound") then
                if not d.SoundGroup then d.SoundGroup = groups.Effects end
            elseif d:IsA("ParticleEmitter") then
                if GameSettings.Get("Particles") == "Reduced" and not d:GetAttribute("AimRngThinned") then
                    d:SetAttribute("AimRngThinned", true)
                    d.Rate *= 0.5
                end
            elseif d:IsA("ProximityPrompt") then
                local kc = GameSettings.KeyFor("Interact")
                if kc then d.KeyboardKeyCode = kc end
                -- (QOL L3 2026-10-28: every prompt on a pad = RB; Roblox's default ButtonX is our Reload, PlatformControls PAD_DOWN)
                if d.GamepadKeyCode == Enum.KeyCode.ButtonX then d.GamepadKeyCode = Enum.KeyCode.ButtonR1 end
            end
        end
        for _, d in ipairs(Workspace:GetDescendants()) do Adopt(d) end
        Workspace.DescendantAdded:Connect(Adopt)
        GameSettings.OnChanged("Key_Interact", function()
            for _, d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("ProximityPrompt") then Adopt(d) end
            end
        end)
    end

    -- HUB MUSIC (2026-10-23): city + hideout only, fades out for runs / duels / the tutorial / try range / Aim Trials /
    -- spectating, yields to a hideout jukebox track (AimRngShared/HubMusic; Settings > Audio > Music).
    ;(function()
        local ok, HubMusic = pcall(require, game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("HubMusic"))
        if not ok then warn("[HubMusic] " .. tostring(HubMusic)); return end
        UI.HubMusic = HubMusic
        HubMusic.Start({
            GameSettings = GameSettings,
            Zones = require(game.ReplicatedStorage.AimRngShared:WaitForChild("Zones")),
            Blocked = function() return UI.TrialActive or UI.watching end,
        })
    end)()

    -- key hints shown on the HUD follow the Controls bindings
    do
        local function RefreshKeyHints()
            if UI.RefreshDockKeys then UI.RefreshDockKeys() end
            UI.btnSet.Text = KeyTag("Settings") .. " SETTINGS"
            UI.ammoHintGun = KeyTag("Reload") .. " RELOAD | " .. KeyTag("Melee") .. " MELEE"
            UI.ammoHintMelee = KeyTag("Aim") .. " DASH | " .. KeyTag("SlotGun") .. " GUN"
            if GameSettings.TouchOnly() then UI.ammoHintGun, UI.ammoHintMelee = "", "DASH button: melee dash" end
            UI.ammoHintLbl.Text = (activeSlot == "Melee") and UI.ammoHintMelee or UI.ammoHintGun
            if UI.btnEquipNow then UI.btnEquipNow.Text = "EQUIP NOW  " .. KeyTag("Interact") end
            if UI.btnKeepInventory then UI.btnKeepInventory.Text = "KEEP IN STASH  " .. KeyTag("Dismiss") end
            if UI.btnVictoryHub then UI.btnVictoryHub.Text = "RETURN TO HUB  " .. KeyTag("ExitRun") end
            if UI.btnReturnHub and not string.find(UI.btnReturnHub.Text, "CONFIRM") then UI.btnReturnHub.Text = "EXIT TO HUB " .. KeyTag("ExitRun") end
        end
        GameSettings.OnChanged("*", function(key) if string.sub(key, 1, 4) == "Key_" then RefreshKeyHints() end end)
        LocalPlayer:GetAttributeChangedSignal("DevTouch"):Connect(RefreshKeyHints) -- (Studio touch preview)
        RefreshKeyHints()
    end

    -- ==================== [MENU 9: WEAPON ARMORY & COSMETICS (GLOVES & KNIVES)] ====================
    UI.armoryFrame = Instance.new("Frame")
    UI.armoryFrame.Name = "ArmoryMenu"
    UI.armoryFrame.Size = UDim2.new(0, 740, 0, 480)
    UI.armoryFrame.Position = UDim2.new(0.5, -370, 0.5, -240)
    UI.armoryFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
    UI.armoryFrame.BorderSizePixel = 2
    UI.armoryFrame.BorderColor3 = Color3.fromRGB(255, 140, 20)
    UI.armoryFrame.Visible = false
    UI.armoryFrame.Parent = UI.menuFolder
    ApplyPanelChrome(UI.armoryFrame, Color3.fromRGB(255, 140, 20), 12)

    local armHeader = Instance.new("TextLabel")
    armHeader.Size = UDim2.new(1, 0, 0, 42)
    armHeader.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
    armHeader.Font = Enum.Font.GothamBlack
    armHeader.TextSize = 20
    armHeader.TextColor3 = Color3.fromRGB(255, 160, 40)
    armHeader.Text = "MELEE ARMORY  [G / ESC to Close]"
    armHeader.Parent = UI.armoryFrame
    UI.windowHeaders = UI.windowHeaders or {}; UI.windowHeaders[UI.armoryFrame] = armHeader
    -- (UI CLEAN audit: the window language -- flat slate body, the title left in display caps Text (the key hint was in the
    -- title), its tabs / buttons flattened by MenuKit.Sweep)
    UI.armoryFrame.BorderSizePixel = 0; UI.armoryFrame.BackgroundColor3 = UIStyle.Colors.Bg0
    armHeader.BackgroundTransparency = 1; armHeader.TextXAlignment = Enum.TextXAlignment.Left; armHeader.Text = "   MELEE ARMORY"
    armHeader.FontFace = UIStyle.RoleFace("Header"); armHeader.TextColor3 = UIStyle.Colors.Text; armHeader.TextSize = 22; armHeader:SetAttribute("NoSnap", true)
    pcall(function() require(sharedFolder:WaitForChild("MenuKit")).Sweep(UI.armoryFrame) end)

    local armTabsBar = Instance.new("Frame")
    armTabsBar.Size = UDim2.new(1, -20, 0, 32)
    armTabsBar.Position = UDim2.new(0, 10, 0, 48)
    armTabsBar.BackgroundTransparency = 1
    armTabsBar.Parent = UI.armoryFrame

    local function MakeArmTab(text: string, idx: number): TextButton
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.25, -6, 1, 0)
        btn.Position = UDim2.new(0.25 * (idx - 1), 3, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.TextColor3 = Color3.fromRGB(230, 235, 245)
        btn.Text = text
        btn.Parent = armTabsBar
        RoundCorners(btn, 6)
        return btn
    end
    local tabKnivesBtn = MakeArmTab("MELEE", 1)
    local tabGlovesBtn = MakeArmTab("GLOVES", 2)
    local tabSleevesBtn = MakeArmTab("SLEEVES", 3)
    local tabSkinsBtn = MakeArmTab("WEAPON FINISHES", 4)
    -- Gloves / sleeves / finishes were built for the old hand models and no longer apply: the armory is
    -- melee only (the cosmetic tabs stay hidden until cosmetics are redone for the current hands).
    armTabsBar.Visible = false

    local armScroll = Instance.new("ScrollingFrame")
    armScroll.Size = UDim2.new(1, -20, 1, -62)
    armScroll.Position = UDim2.new(0, 10, 0, 52)
    armScroll.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
    armScroll.BorderSizePixel = 1
    armScroll.BorderColor3 = Color3.fromRGB(45, 60, 85)
    armScroll.ScrollBarThickness = 6
    armScroll.Parent = UI.armoryFrame

    local currentArmTab = "Knives"

    RefreshArmoryMenu = function()
        for _, c in ipairs(armScroll:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        tabKnivesBtn.BackgroundColor3 = (currentArmTab == "Knives") and Color3.fromRGB(78, 82, 94) or Color3.fromRGB(30, 31, 37)
        tabGlovesBtn.BackgroundColor3 = (currentArmTab == "Gloves") and Color3.fromRGB(78, 82, 94) or Color3.fromRGB(30, 31, 37)
        tabSleevesBtn.BackgroundColor3 = (currentArmTab == "Sleeves") and Color3.fromRGB(78, 82, 94) or Color3.fromRGB(30, 31, 37)
        tabSkinsBtn.BackgroundColor3 = (currentArmTab == "Skins") and Color3.fromRGB(78, 82, 94) or Color3.fromRGB(30, 31, 37)

        if currentArmTab == "Knives" then
            local knifeKeys = ItemData.MeleeLineup
            armScroll.CanvasSize = UDim2.new(0, 0, 0, #knifeKeys * 105 + 20)

            for idx, kId in ipairs(knifeKeys) do
                local kData = ItemData.MeleeWeapons[kId]
                if kData then
                    local card = Instance.new("Frame")
                    card.Size = UDim2.new(0.96, 0, 0, 96)
                    card.Position = UDim2.new(0.02, 0, 0, (idx - 1) * 104 + 6)
                    card.BackgroundColor3 = UIStyle.Colors.Bg1
                    card.BorderSizePixel = 1
                    card.BorderColor3 = ItemData.RarityColors[kData.Rarity]
                    card.Parent = armScroll

                    local title = Instance.new("TextLabel")
                    title.Size = UDim2.new(0.65, 0, 0, 22)
                    title.Position = UDim2.new(0, 10, 0, 4)
                    title.BackgroundTransparency = 1
                    title.Font = Enum.Font.GothamBold
                    title.TextSize = 17
                    title.TextColor3 = ItemData.RarityColors[kData.Rarity]
                    title.TextXAlignment = Enum.TextXAlignment.Left
                    title.Text = (UI.RarityGlyph and UI.RarityGlyph(kData.Rarity) .. "  " or "") .. kData.Name .. "   •   " .. kData.Rarity
                    title.Parent = card

                    local stats = Instance.new("TextLabel")
                    stats.Size = UDim2.new(0.65, 0, 0, 20)
                    stats.Position = UDim2.new(0, 10, 0, 26)
                    stats.BackgroundTransparency = 1
                    stats.Font = Enum.Font.GothamBold
                    stats.TextSize = 14
                    stats.TextColor3 = Color3.fromRGB(214, 218, 228)
                    stats.TextXAlignment = Enum.TextXAlignment.Left
                    stats.Text = string.format("Base DMG: %s  |  Rate: %.1f/s  |  Crit: %d%% (x%.1f)  |  Pen: %d%%", ItemData.FormatNumber(kData.BaseDamage), kData.AttackRate, math.round(kData.CritChance * 100), kData.CritMultiplier, math.round(kData.ArmorPenetration * 100))
                    stats.Parent = card

                    local desc = Instance.new("TextLabel")
                    desc.Size = UDim2.new(0.65, 0, 0, 36)
                    desc.Position = UDim2.new(0, 10, 0, 48)
                    desc.BackgroundTransparency = 1
                    desc.Font = Enum.Font.Gotham
                    desc.TextSize = 14
                    desc.TextColor3 = Color3.fromRGB(180, 200, 225)
                    desc.TextXAlignment = Enum.TextXAlignment.Left
                    desc.TextWrapped = true
                    desc.Text = kData.Description
                    desc.Parent = card

                    local isOwned = table.find(clientState.KnifeInventory or {}, kId) ~= nil
                    local isEquipped = (clientState.EquippedKnife == kId)

                    -- melee skin (MeleeData.Skins): cycles through the skins you own; shows on this melee everywhere
                    if isOwned then
                        local MD = require(sharedFolder:WaitForChild("MeleeData"))
                        local cur, curId = MD.SkinFor(clientState, kId)
                        local btnSkin = Instance.new("TextButton")
                        btnSkin.Size = UDim2.new(0, 140, 0, 28)
                        btnSkin.Position = UDim2.new(1, -150, 0, 8)
                        btnSkin.Font = Enum.Font.GothamBold
                        btnSkin.TextSize = 13
                        btnSkin.BorderSizePixel = 0
                        btnSkin.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
                        btnSkin.TextColor3 = ItemData.RarityColors[cur.Rarity] or Color3.new(1, 1, 1)
                        btnSkin.Text = "SKIN: " .. cur.Name .. "  >"
                        btnSkin.Parent = card
                        btnSkin.MouseButton1Click:Connect(function()
                            SoundHelper.Play("Click")
                            local order = MD.SkinOrder
                            local start = table.find(order, curId) or 1
                            for step = 1, #order do
                                local nextId = order[(start - 1 + step) % #order + 1]
                                if MD.Owns(clientState, nextId) then
                                    if nextId ~= curId and Remotes.GetFunction("EquipMeleeSkin"):InvokeServer(kId, nextId) then
                                        clientState.MeleeSkinFor = clientState.MeleeSkinFor or {}
                                        clientState.MeleeSkinFor[kId] = nextId
                                        if UI.ActiveSlot and UI.ActiveSlot() == "Melee" and clientState.EquippedKnife == kId and ApplyMeleeToRig then ApplyMeleeToRig() end
                                    end
                                    break
                                end
                            end
                            RefreshArmoryMenu()
                        end)
                    end

                    local btnAction = Instance.new("TextButton")
                    btnAction.Size = UDim2.new(0, 140, 0, 32)
                    btnAction.Position = UDim2.new(1, -150, 1, -42)
                    btnAction.Font = Enum.Font.GothamBold
                    btnAction.TextSize = 15
                    btnAction.BorderSizePixel = 0
                    btnAction.Parent = card

                    if isEquipped then
                        btnAction.Text = "EQUIPPED"
                        btnAction.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
                        btnAction.TextColor3 = Color3.fromRGB(255, 255, 255)
                    elseif isOwned then
                        btnAction.Text = "EQUIP"
                        btnAction.BackgroundColor3 = Color3.fromRGB(0, 160, 220)
                        btnAction.TextColor3 = Color3.fromRGB(255, 255, 255)
                        btnAction.MouseButton1Click:Connect(function()
                            SoundHelper.Play("Click")
                            Remotes.GetFunction("EquipKnife"):InvokeServer(kId)
                            clientState.EquippedKnife = kId
                            RefreshArmoryMenu()
                        end)
                    else
                        btnAction.Text = "BUY " .. kData.CostGold .. "g / " .. kData.CostShards .. " SHARDS"
                        btnAction.BackgroundColor3 = Color3.fromRGB(240, 140, 20)
                        btnAction.TextColor3 = Color3.fromRGB(255, 255, 255)
                        btnAction.MouseButton1Click:Connect(function()
                            SoundHelper.Play("Click")
                            local ok, err = Remotes.GetFunction("BuyKnife"):InvokeServer(kId)
                            if ok then
                                SoundHelper.Play("Purchase")
                                ShowToast("Purchased " .. kData.Name .. "!")
                                RefreshArmoryMenu()
                            else
                                ShowToast(tostring(err))
                            end
                        end)
                    end
                end
            end
        else
            -- Gloves / Sleeves / Weapon finishes: one generic cosmetic list (drop-only items show where they drop).
            local catalog, kind, invField, equipField, icon
            if currentArmTab == "Gloves" then
                catalog, kind, invField, equipField, icon = ItemData.Gloves, "Glove", "GloveInventory", "EquippedGlove", ""
            elseif currentArmTab == "Sleeves" then
                catalog, kind, invField, equipField, icon = ItemData.ArmSkins, "Sleeve", "SleeveInventory", "EquippedSleeve", ""
            else
                catalog, kind, invField, equipField, icon = ItemData.WeaponSkins, "WeaponSkin", "WeaponSkinInventory", "EquippedWeaponSkin", ""
            end
            local ids = ItemData.SortedCosmeticIds(catalog)
            armScroll.CanvasSize = UDim2.new(0, 0, 0, #ids * 94 + 20)

            for idx, cId in ipairs(ids) do
                local cData = catalog[cId]
                local rColor = ItemData.RarityColors[cData.Rarity] or Color3.new(1, 1, 1)
                local card = Instance.new("Frame")
                card.Size = UDim2.new(0.96, 0, 0, 86)
                card.Position = UDim2.new(0.02, 0, 0, (idx - 1) * 94 + 6)
                card.BackgroundColor3 = UIStyle.Colors.Bg1
                card.BorderSizePixel = 1
                card.BorderColor3 = rColor
                card.Parent = armScroll

                -- color swatch preview
                local swatchA = Instance.new("Frame")
                swatchA.Size = UDim2.new(0, 34, 0, 34)
                swatchA.Position = UDim2.new(0, 10, 0.5, -17)
                swatchA.BorderSizePixel = 0
                swatchA.BackgroundColor3 = cData.PrimaryColor or cData.SleeveColor or cData.Tint or Color3.new(1, 1, 1)
                swatchA.Parent = card
                RoundCorners(swatchA, 6)
                local swatchB = Instance.new("Frame")
                swatchB.Size = UDim2.new(0, 14, 0, 34)
                swatchB.Position = UDim2.new(0, 46, 0.5, -17)
                swatchB.BorderSizePixel = 0
                swatchB.BackgroundColor3 = cData.AccentColor or cData.CuffColor or (cData.StripeColor) or swatchA.BackgroundColor3
                swatchB.Parent = card
                RoundCorners(swatchB, 4)

                local title = Instance.new("TextLabel")
                title.Size = UDim2.new(1, -240, 0, 22)
                title.Position = UDim2.new(0, 70, 0, 6)
                title.BackgroundTransparency = 1
                title.Font = Enum.Font.GothamBold
                title.TextSize = 16
                title.TextColor3 = rColor
                title.TextXAlignment = Enum.TextXAlignment.Left
                title.TextTruncate = Enum.TextTruncate.AtEnd
                title.Text = cData.Name .. "   •   " .. cData.Rarity
                title.Parent = card

                local desc = Instance.new("TextLabel")
                desc.Size = UDim2.new(1, -240, 0, 48)
                desc.Position = UDim2.new(0, 70, 0, 30)
                desc.BackgroundTransparency = 1
                desc.Font = Enum.Font.Gotham
                desc.TextSize = 13
                desc.TextColor3 = Color3.fromRGB(180, 200, 225)
                desc.TextXAlignment = Enum.TextXAlignment.Left
                desc.TextYAlignment = Enum.TextYAlignment.Top
                desc.TextWrapped = true
                desc.Text = cData.Description
                desc.Parent = card

                local isOwned = table.find(clientState[invField] or {}, cId) ~= nil
                local isEquipped = (clientState[equipField] == cId)

                local btnAction = Instance.new("TextButton")
                btnAction.Size = UDim2.new(0, 150, 0, 32)
                btnAction.Position = UDim2.new(1, -160, 0.5, -16)
                btnAction.Font = Enum.Font.GothamBold
                btnAction.TextSize = 13
                btnAction.BorderSizePixel = 0
                btnAction.TextColor3 = Color3.fromRGB(255, 255, 255)
                btnAction.TextWrapped = true
                btnAction.Parent = card
                RoundCorners(btnAction, 6)

                if isEquipped then
                    btnAction.Text = "EQUIPPED"
                    btnAction.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
                elseif isOwned then
                    btnAction.Text = "EQUIP"
                    btnAction.BackgroundColor3 = Color3.fromRGB(0, 160, 220)
                    btnAction.MouseButton1Click:Connect(function()
                        SoundHelper.Play("Click")
                        local ok = Remotes.GetFunction("EquipCosmetic"):InvokeServer(kind, cId)
                        if ok then
                            clientState[equipField] = cId
                            RebuildViewmodelForWeapon(clientState.EquippedWeapon)
                            RefreshArmoryMenu()
                        end
                    end)
                elseif cData.DropOnly then
                    btnAction.Text = "DROPS FROM\n" .. string.upper(cData.DropSource or "BOSSES")
                    btnAction.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
                    btnAction.TextColor3 = Color3.fromRGB(170, 175, 190)
                    btnAction.AutoButtonColor = false
                elseif kind == "Glove" then
                    btnAction.Text = "BUY " .. cData.CostGold .. "g / " .. cData.CostShards .. " SHARDS"
                    btnAction.BackgroundColor3 = Color3.fromRGB(240, 140, 20)
                    btnAction.MouseButton1Click:Connect(function()
                        SoundHelper.Play("Click")
                        local ok, err = Remotes.GetFunction("BuyGlove"):InvokeServer(cId)
                        if ok then
                            SoundHelper.Play("Purchase")
                            ShowToast("Purchased " .. cData.Name .. "!")
                        else
                            ShowToast(tostring(err))
                        end
                    end)
                else
                    btnAction.Text = "LOCKED"
                    btnAction.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
                    btnAction.AutoButtonColor = false
                end
            end
        end
    end

    tabKnivesBtn.MouseButton1Click:Connect(function() currentArmTab = "Knives"; RefreshArmoryMenu() end)
    tabGlovesBtn.MouseButton1Click:Connect(function() currentArmTab = "Gloves"; RefreshArmoryMenu() end)
    tabSleevesBtn.MouseButton1Click:Connect(function() currentArmTab = "Sleeves"; RefreshArmoryMenu() end)
    tabSkinsBtn.MouseButton1Click:Connect(function() currentArmTab = "Skins"; RefreshArmoryMenu() end)
    UI.btnArmory.MouseButton1Click:Connect(function() OpenMenuFrame(UI.armoryFrame); RefreshArmoryMenu() end)

    -- ==================== [MENU 8: THE COMPLETE ARSENAL & BESTIARY INDEX] ====================
    UI.indexFrame = Instance.new("Frame")
    UI.indexFrame.Name = "IndexMenu"
    UI.indexFrame.Size = UDim2.new(0, 880, 0, 540)
    UI.indexFrame.Position = UDim2.new(0.5, -440, 0.5, -270)
    UI.indexFrame.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
    UI.indexFrame.BorderSizePixel = 2
    UI.indexFrame.BorderColor3 = Color3.fromRGB(0, 200, 255)
    UI.indexFrame.Visible = false
    UI.indexFrame.Parent = UI.menuFolder
    ApplyPanelChrome(UI.indexFrame, Color3.fromRGB(0, 200, 255), 12)

    local idxHeader = Instance.new("TextLabel")
    idxHeader.Size = UDim2.new(1, 0, 0, 40); idxHeader.BackgroundColor3 = Color3.fromRGB(22, 28, 42); idxHeader.Font = Enum.Font.GothamBold; idxHeader.TextSize = 20; idxHeader.TextColor3 = Color3.fromRGB(0, 220, 255); idxHeader.Text = "INDEX  [K / ESC to Close]"; idxHeader.Parent = UI.indexFrame
    UI.windowHeaders = UI.windowHeaders or {}; UI.windowHeaders[UI.indexFrame] = idxHeader

    local idxTabsBar = Instance.new("Frame")
    idxTabsBar.Size = UDim2.new(1, -20, 0, 32); idxTabsBar.Position = UDim2.new(0, 10, 0, 46); idxTabsBar.BackgroundTransparency = 1; idxTabsBar.Parent = UI.indexFrame

    local function CreateIndexTabBtn(title: string, posX: number, w: number): TextButton
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, w, 1, 0); btn.Position = UDim2.new(0, posX, 0, 0); btn.BackgroundColor3 = Color3.fromRGB(28, 36, 52); btn.BorderSizePixel = 1; btn.BorderColor3 = Color3.fromRGB(60, 80, 110); btn.Font = Enum.Font.GothamBold; btn.TextSize = 15; btn.TextColor3 = Color3.fromRGB(200, 225, 255); btn.Text = title; btn.Parent = idxTabsBar
        return btn
    end

    local tabWeaponsIdx = CreateIndexTabBtn("WEAPONS", 0, 100)
    local tabGearIdx = CreateIndexTabBtn("GEAR", 105, 85)
    local tabTraitsIdx = CreateIndexTabBtn("RARITIES", 195, 105)
    local tabBestiaryIdx = CreateIndexTabBtn("ENEMIES", 305, 100)
    local tabTitlesIdx = CreateIndexTabBtn("TITLES & REWARDS", 410, 165)
    UI.tabArchiveIdx = CreateIndexTabBtn("LEDGER", 580, 110) -- (UPDATE 7 A4: ArchiveView; a UI field -- this chunk is at the local limit)
    UI.tabGuideIdx = CreateIndexTabBtn("HOW IT WORKS", 695, 140) -- (UPDATE 8 OFFENSE: GuideCodex -- attributes, tree, sockets, mods, damage, defences)

    local idxContentScroll = Instance.new("ScrollingFrame")
    idxContentScroll.Size = UDim2.new(1, -20, 1, -90); idxContentScroll.Position = UDim2.new(0, 10, 0, 82); idxContentScroll.BackgroundColor3 = Color3.fromRGB(10, 12, 18); idxContentScroll.BorderSizePixel = 1; idxContentScroll.BorderColor3 = Color3.fromRGB(45, 60, 85); idxContentScroll.ScrollBarThickness = 6; idxContentScroll.Parent = UI.indexFrame

    local currentIdxTab = "Weapons"

    RenderIndexContent = function()
        for _, c in ipairs(idxContentScroll:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        idxContentScroll.AutomaticCanvasSize = Enum.AutomaticSize.None -- (the ARCHIVE tab sizes itself; the others set CanvasSize)
        UI.tabArchiveIdx.BackgroundColor3 = (currentIdxTab == "Archive") and Color3.fromRGB(78, 82, 94) or Color3.fromRGB(30, 31, 37)
        UI.tabGuideIdx.BackgroundColor3 = (currentIdxTab == "Guide") and Color3.fromRGB(78, 82, 94) or Color3.fromRGB(30, 31, 37)

        tabWeaponsIdx.BackgroundColor3 = (currentIdxTab == "Weapons") and Color3.fromRGB(78, 82, 94) or Color3.fromRGB(30, 31, 37)
        tabGearIdx.BackgroundColor3 = (currentIdxTab == "Gear") and Color3.fromRGB(78, 82, 94) or Color3.fromRGB(30, 31, 37)
        tabTraitsIdx.BackgroundColor3 = (currentIdxTab == "Traits") and Color3.fromRGB(78, 82, 94) or Color3.fromRGB(30, 31, 37)
        tabBestiaryIdx.BackgroundColor3 = (currentIdxTab == "Bestiary") and Color3.fromRGB(78, 82, 94) or Color3.fromRGB(30, 31, 37)
        tabTitlesIdx.BackgroundColor3 = (currentIdxTab == "Titles") and Color3.fromRGB(78, 82, 94) or Color3.fromRGB(30, 31, 37)

        if currentIdxTab == "Weapons" then
            local weaponKeys = {}
            for k, def in pairs(ItemData.BaseWeapons) do
                if not def.TestOnly and not def.Legacy then table.insert(weaponKeys, k) end
            end
            table.sort(weaponKeys)
            idxContentScroll.CanvasSize = UDim2.new(0, 0, 0, #weaponKeys * 116 + 20) -- ((CLASS BUILDS) FAMILY: +20 a card for the family line)

            for i, key in ipairs(weaponKeys) do
                local base = ItemData.BaseWeapons[key]
                local card = Instance.new("Frame")
                card.Size = UDim2.new(0.96, 0, 0, 108); card.Position = UDim2.new(0.02, 0, 0, (i - 1) * 116 + 8); card.BackgroundColor3 = UIStyle.Colors.Bg1; card.BorderSizePixel = 1; card.BorderColor3 = UIStyle.Colors.Line; card.Parent = idxContentScroll -- ((CLASS BUILDS) FAMILY: 108 tall)

                local title = Instance.new("TextLabel")
                title.Size = UDim2.new(1, -20, 0, 24); title.Position = UDim2.new(0, 10, 0, 4); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBold; title.TextSize = 17; title.TextColor3 = UIStyle.Colors.Text; title.TextXAlignment = Enum.TextXAlignment.Left
                title.Text = base.Name .. "   •   " .. base.Class .. " class"
                title.Parent = card

                local stats = Instance.new("TextLabel")
                stats.Size = UDim2.new(1, -20, 0, 20); stats.Position = UDim2.new(0, 10, 0, 26); stats.BackgroundTransparency = 1; stats.Font = Enum.Font.GothamBold; stats.TextSize = 15; stats.TextColor3 = Color3.fromRGB(214, 218, 228); stats.TextXAlignment = Enum.TextXAlignment.Left
                stats.Text = string.format("Damage at Lv 1: %s  |  Fire Rate: %.1f/s  |  Weak-Spot: %d%%  |  Mag: %d  |  Range: %d studs", ItemData.FormatNumber(base.BaseDamage * ItemData.GunTune(key)), base.BaseFireRate, math.round(base.BaseWeakSpotMultiplier * 100), base.MagazineSize, base.EffectiveRange)
                stats.Parent = card

                local desc = Instance.new("TextLabel")
                desc.Size = UDim2.new(1, -20, 0, 36); desc.Position = UDim2.new(0, 10, 0, 46); desc.BackgroundTransparency = 1; desc.Font = Enum.Font.GothamMedium; desc.TextSize = 15; desc.TextColor3 = UIStyle.Colors.Sub; desc.TextXAlignment = Enum.TextXAlignment.Left; desc.TextWrapped = true
                desc.Text = base.Description or "Precision weapon with bespoke mechanics and procedural 3D model."
                desc.Parent = card
                if ItemData.FamilyLine and ItemData.FamilyLine(key) then -- (CLASS BUILDS) FAMILY: the gun family's built-in line, under the text
                    local fl = desc:Clone()
                    fl.Name = "FamilyLine"; fl.Position = UDim2.new(0, 10, 0, 82); fl.Size = UDim2.new(1, -20, 0, 22)
                    fl.TextColor3 = ItemData.GUN_FAMILY_COLOR; fl.Text = ItemData.FamilyLine(key); fl.Parent = card
                    -- (UI CLEAN audit: gold is for prices; the family rule reads as a modifier line = Text, the "(family)" tag in Sub)
                    fl.TextColor3 = UIStyle.Colors.Text; fl.RichText = true; fl:SetAttribute("NoSnap", true)
                    fl.Text = string.gsub(fl.Text, "%(family%)", '<font color="#' .. UIStyle.Colors.Sub:ToHex() .. '">(family)</font>')
                end
            end

        elseif currentIdxTab == "Gear" then
            local slots = ItemData.GEAR_TYPES -- (UPDATE 8 GEAR v3: + Gloves; the new pools + each slot's bases)
            idxContentScroll.CanvasSize = UDim2.new(0, 0, 0, #slots * 115 + 20)

            for i, s in ipairs(slots) do
                local pool = ItemData.GearPoolV3(s, nil, false)
                for _, b in ipairs(ItemData.GEAR_BASES[s] or {}) do for _, d in ipairs(ItemData.GearPoolV3(s, b, false)) do table.insert(pool, d) end end
                do local seen = {} local u = {} for _, d in ipairs(pool) do if not seen[d.Stat] then seen[d.Stat] = true; table.insert(u, d) end end pool = u end

                local card = Instance.new("Frame")
                card.Size = UDim2.new(0.96, 0, 0, 105); card.Position = UDim2.new(0.02, 0, 0, (i - 1) * 115 + 8); card.BackgroundColor3 = UIStyle.Colors.Bg1; card.BorderSizePixel = 1; card.BorderColor3 = UIStyle.Colors.Line; card.Parent = idxContentScroll

                local title = Instance.new("TextLabel")
                title.Size = UDim2.new(1, -20, 0, 24); title.Position = UDim2.new(0, 10, 0, 4); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBold; title.TextSize = 17; title.TextColor3 = Color3.fromRGB(80, 200, 255); title.TextXAlignment = Enum.TextXAlignment.Left
                title.Text = string.upper(ItemData.GearBaseNames[s] or s) .. ((s == "Ring") and "  (fits either ring slot)" or "")
                title.Parent = card
                -- (UI CLEAN audit: the slot name is the card head -- display caps 20 in Text; the slot's drawn icon on the right)
                title.FontFace = UIStyle.RoleFace("Label"); title.TextSize = 20; title.TextColor3 = UIStyle.Colors.Text; title:SetAttribute("NoSnap", true)
                pcall(function()
                    local Icons = require(sharedFolder:WaitForChild("ItemIcons", 2))
                    if Icons.For(s) then
                        local im = Instance.new("ImageLabel"); im.Name = "KitIcon"; im.BackgroundTransparency = 1; im.AnchorPoint = Vector2.new(1, 0.5)
                        im.Position = UDim2.new(1, -14, 0.5, 0); im.Size = UDim2.fromOffset(72, 72); im:SetAttribute("Skinned", true); im.Parent = card
                        Icons.Apply(im, s)
                    end
                end)

                local affixesText = {}
                for _, aff in ipairs(pool) do
                    local def = ItemData.StatDefs[aff.Stat]
                    table.insert(affixesText, def and def.Label or aff.Stat)
                end

                local poolLbl = Instance.new("TextLabel")
                poolLbl.Size = UDim2.new(1, -20, 0, 72); poolLbl.Position = UDim2.new(0, 10, 0, 26); poolLbl.BackgroundTransparency = 1; poolLbl.Font = Enum.Font.GothamMedium; poolLbl.TextSize = 15; poolLbl.TextColor3 = Color3.fromRGB(190, 210, 235); poolLbl.TextXAlignment = Enum.TextXAlignment.Left; poolLbl.TextYAlignment = Enum.TextYAlignment.Top; poolLbl.TextWrapped = true
                -- (UI CLEAN audit: the base line once per card, short; the line-count rule lives on the RARITIES tab)
                poolLbl.Size = UDim2.new(1, -120, 0, 72); poolLbl.TextColor3 = UIStyle.Colors.Text; poolLbl.RichText = true; poolLbl:SetAttribute("NoSnap", true); poolLbl.TextSize = 14
                local subHex = UIStyle.Colors.Sub:ToHex()
                poolLbl.Text = '<font color="#' .. subHex .. '">Can roll:</font>  ' .. table.concat(affixesText, ", ") .. "\n"
                    .. '<font color="#' .. subHex .. '">' .. ((s == "Ring" or s == "Necklace") and "Base: an implicit line (a resistance, damage or a broad stat)." or "Base: Plating, Agility, Ward or a hybrid, plus an implicit line.") .. "</font>"
                poolLbl.Parent = card
            end

        elseif currentIdxTab == "Traits" then
            local totalEntries = #ItemData.Rarities + #ItemData.UniqueTraitsCatalog
            idxContentScroll.CanvasSize = UDim2.new(0, 0, 0, totalEntries * 80 + 30)

            local posY = 8
            local sec1 = Instance.new("TextLabel")
            sec1.Size = UDim2.new(0.96, 0, 0, 24); sec1.Position = UDim2.new(0.02, 0, 0, posY); sec1.BackgroundTransparency = 1; sec1.Font = Enum.Font.GothamBlack; sec1.TextSize = 17; sec1.TextColor3 = Color3.fromRGB(214, 218, 228); sec1.TextXAlignment = Enum.TextXAlignment.Left; sec1.Text = "THE 5 RARITIES"; sec1.Parent = idxContentScroll; if UI.KitHead then UI.KitHead(sec1) end
            posY += 30

            for _, r in ipairs(ItemData.Rarities) do
                local card = Instance.new("Frame")
                card.Size = UDim2.new(0.96, 0, 0, 52); card.Position = UDim2.new(0.02, 0, 0, posY); card.BackgroundColor3 = Color3.fromRGB(18, 22, 30); card.BorderSizePixel = 1; card.BorderColor3 = ItemData.RarityColors[r]; card.Parent = idxContentScroll

                local tLbl = Instance.new("TextLabel")
                tLbl.Size = UDim2.new(1, -20, 0, 22); tLbl.Position = UDim2.new(0, 10, 0, 4); tLbl.BackgroundTransparency = 1; tLbl.Font = Enum.Font.GothamBold; tLbl.TextSize = 17; tLbl.TextColor3 = ItemData.RarityColors[r]; tLbl.TextXAlignment = Enum.TextXAlignment.Left
                tLbl.Text = r:upper() -- (UI CLEAN audit: the rarity's name as the head, display caps in its colour)
                tLbl.FontFace = UIStyle.RoleFace("Label"); tLbl.TextSize = 18; tLbl:SetAttribute("NoSnap", true)
                tLbl.Parent = card

                local mult = ItemData.RarityDamageMult[r] or 1.0
                local sell = ItemData.BaseSellPrices[r] or 15
                local rank = ItemData.RarityRank[r] or 1
                local lo, hi = ItemData.LineBand(r) -- (ITEM SCALING v2: guns + gear share the rarity's line band)
                local band = (lo == hi) and tostring(lo) or (lo .. "-" .. hi)
                local dLbl = Instance.new("TextLabel")
                dLbl.Size = UDim2.new(1, -20, 0, 20); dLbl.Position = UDim2.new(0, 10, 0, 26); dLbl.BackgroundTransparency = 1; dLbl.Font = Enum.Font.GothamMedium; dLbl.TextSize = 15; dLbl.TextColor3 = Color3.fromRGB(180, 200, 220); dLbl.TextXAlignment = Enum.TextXAlignment.Left
                local prefixChance = math.round((ItemData.PROC_CHANCE_BY_RARITY[r] or 0) * 100)
                dLbl.Text = string.format("Damage/armor x%.2f  |  Affix lines %s (gear lines +%d%% strength)  |  Weapon prefix %d%%  |  Sells from %d gold", mult, band, math.round(((ItemData.AFFIX_POWER and ItemData.AFFIX_POWER[r] or (1 + 0.14 * (rank - 1))) - 1) * 100), prefixChance, sell)
                if r == "Relic" then dLbl.Text = "About 40 named items with fixed build-changing lines (guns: fixed sockets too). Bosses, trials, maps, and very rarely any drop; some only on harder tiers" end
                dLbl.TextScaled = true
                local dLim = Instance.new("UITextSizeConstraint"); dLim.MaxTextSize = 14; dLim.Parent = dLbl
                dLbl.Parent = card

                posY += 60
            end
            if UI.Zen and UI.Zen.Shown() then posY = UI.Zen.IndexSection(idxContentScroll, posY) end -- (CHASE ITEMS: the ZENITH section, hidden while dark)

            local sec2 = Instance.new("TextLabel")
            sec2.Size = UDim2.new(0.96, 0, 0, 24); sec2.Position = UDim2.new(0.02, 0, 0, posY); sec2.BackgroundTransparency = 1; sec2.Font = Enum.Font.GothamBlack; sec2.TextSize = 17; sec2.TextColor3 = Color3.fromRGB(255, 225, 70); sec2.TextXAlignment = Enum.TextXAlignment.Left; sec2.Text = "UNIQUE TRAITS"; sec2.Parent = idxContentScroll; if UI.KitHead then UI.KitHead(sec2) end
            posY += 30

            for _, trait in ipairs(ItemData.UniqueTraitsCatalog) do
                local card = Instance.new("Frame")
                card.Size = UDim2.new(0.96, 0, 0, 68); card.Position = UDim2.new(0.02, 0, 0, posY); card.BackgroundColor3 = Color3.fromRGB(22, 26, 38); card.BorderSizePixel = 2; card.BorderColor3 = Color3.fromRGB(255, 225, 70); card.Parent = idxContentScroll

                local tLbl = Instance.new("TextLabel")
                tLbl.Size = UDim2.new(1, -20, 0, 22); tLbl.Position = UDim2.new(0, 10, 0, 4); tLbl.BackgroundTransparency = 1; tLbl.Font = Enum.Font.GothamBold; tLbl.TextSize = 17; tLbl.TextColor3 = Color3.fromRGB(255, 225, 70); tLbl.TextXAlignment = Enum.TextXAlignment.Left
                tLbl.Text = "★ " .. string.upper(trait.Name) -- (UI CLEAN audit: the internal id is gone; the name in display caps Text)
                tLbl.FontFace = UIStyle.RoleFace("Label"); tLbl.TextSize = 17; tLbl.TextColor3 = UIStyle.Colors.Text; tLbl:SetAttribute("NoSnap", true)
                tLbl.Parent = card

                local dLbl = Instance.new("TextLabel")
                dLbl.Size = UDim2.new(1, -20, 0, 36); dLbl.Position = UDim2.new(0, 10, 0, 26); dLbl.BackgroundTransparency = 1; dLbl.Font = Enum.Font.GothamMedium; dLbl.TextSize = 15; dLbl.TextColor3 = Color3.fromRGB(220, 235, 255); dLbl.TextXAlignment = Enum.TextXAlignment.Left; dLbl.TextWrapped = true
                dLbl.Text = trait.Description
                dLbl.Parent = card

                posY += 76
            end

        elseif currentIdxTab == "Bestiary" then
            -- Built from the live game data (DungeonGenerator.BotArchetypes / BotLore / BossLore / EliteMods), with
            -- your kill counts (StatsTracking.EnemyKills). Enemies you haven't defeated yet show as "???".
            local kills = (clientState.StatsTracking and clientState.StatsTracking.EnemyKills) or {}
            local entries = {}
            local order = { "Tracker", "Strafer", "Drifter", "Runner", "Skirmisher", "Hopper", "Blinker", "Charger", "Brute", "Juggernaut", "Sniper",
                "Warden", "Medic", "Splitter", "Splitling", "Gunship", "Pasu", "Orbiter", "Popper", "Zipper", "Leaper", "Seraph" }
            for _, id in ipairs(order) do
                local a = DungeonGeneratorShared.BotArchetypes[id]
                local lore = DungeonGeneratorShared.BotLore[id]
                if a and lore then
                    table.insert(entries, { Name = a.Label, Role = lore.Role, Text = lore.Text, Tip = lore.Tip, Color = a.Color, Kills = kills[id] or 0,
                        Stats = string.format("Health %d  •  Damage %d  •  Speed %d  •  %s", a.Hp, a.Dmg, a.Speed, a.Ground and "walks" or "flies") })
                end
            end
            for _, b in ipairs(DungeonGeneratorShared.BossLore) do
                table.insert(entries, { Name = b.Name, Role = b.Role, Text = "", Tip = b.Tip, Color = Color3.fromRGB(255, 90, 90), Kills = kills[b.Id] or 0, Boss = true })
            end
            local discovered = 0
            for _, e in ipairs(entries) do if e.Kills > 0 then discovered += 1 end end
            local y = 8
            local head = Instance.new("TextLabel")
            head.Size = UDim2.new(0.96, 0, 0, 24); head.Position = UDim2.new(0.02, 0, 0, y); head.BackgroundTransparency = 1; head.Font = Enum.Font.GothamBold; head.TextSize = 16
            head.TextColor3 = UIStyle.Colors.Text; head.TextXAlignment = Enum.TextXAlignment.Left
            head.Text = string.format("ENEMIES DISCOVERED  %d / %d   •   defeat an enemy to unlock its entry", discovered, #entries)
            head.Parent = idxContentScroll
            y += 32
            for _, e in ipairs(entries) do
                local known = e.Kills > 0
                local card = Instance.new("Frame")
                card.Size = UDim2.new(0.96, 0, 0, 92); card.Position = UDim2.new(0.02, 0, 0, y); card.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
                card.BorderSizePixel = 1; card.BorderColor3 = known and e.Color or Color3.fromRGB(50, 56, 70); card.Parent = idxContentScroll
                local swatch = Instance.new("Frame")
                swatch.Size = UDim2.new(0, 8, 1, -12); swatch.Position = UDim2.new(0, 6, 0, 6); swatch.BorderSizePixel = 0
                swatch.BackgroundColor3 = known and e.Color or Color3.fromRGB(60, 64, 76); swatch.Parent = card
                -- (UI CLEAN audit: the enemy's colour as ONE 2 px line along the bottom, not a side bar + coloured box)
                swatch.Size = UDim2.new(1, 0, 0, 2); swatch.Position = UDim2.new(0, 0, 1, -2); swatch.Visible = known; card.BorderSizePixel = 0
                local title = Instance.new("TextLabel")
                title.Size = UDim2.new(0.7, -24, 0, 24); title.Position = UDim2.new(0, 22, 0, 4); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBlack; title.TextSize = 18
                title.TextXAlignment = Enum.TextXAlignment.Left; title.TextColor3 = known and e.Color or Color3.fromRGB(120, 125, 140)
                title.Text = known and (string.upper(e.Name) .. "   •   " .. e.Role) or ("???   •   " .. e.Role)
                title.RichText = true; title.FontFace = UIStyle.RoleFace("Label"); title.TextSize = 18; title:SetAttribute("NoSnap", true)
                title.TextColor3 = known and UIStyle.Colors.Text or UIStyle.Colors.Sub; title.Position = UDim2.new(0, 12, 0, 6)
                title.Text = string.format('%s   <font color="#%s" size="13">%s</font>', known and string.upper(e.Name) or "???", UIStyle.Colors.Sub:ToHex(), string.upper(e.Role or ""))
                title.Parent = card
                local kl = Instance.new("TextLabel")
                kl.Size = UDim2.new(0.3, -12, 0, 24); kl.Position = UDim2.new(0.7, 0, 0, 4); kl.BackgroundTransparency = 1; kl.Font = Enum.Font.GothamBold; kl.TextSize = 14
                kl.TextXAlignment = Enum.TextXAlignment.Right; kl.TextColor3 = known and UIStyle.Colors.Text or UIStyle.Colors.Muted
                kl.Text = known and (tostring(e.Kills) .. " defeated") or "not yet defeated"
                kl.Parent = card
                local body = Instance.new("TextLabel")
                body.Size = UDim2.new(1, -34, 0, 56); body.Position = UDim2.new(0, 22, 0, 30); body.BackgroundTransparency = 1; body.Font = Enum.Font.GothamMedium; body.TextSize = 13
                body.TextXAlignment = Enum.TextXAlignment.Left; body.TextYAlignment = Enum.TextYAlignment.Top; body.TextWrapped = true; body.TextColor3 = UIStyle.Colors.Sub; body.Position = UDim2.new(0, 12, 0, 32); body.Size = UDim2.new(1, -24, 0, 56)
                if known then
                    body.Text = (e.Stats and (e.Stats .. "\n") or "") .. (e.Text ~= "" and (e.Text .. "  ") or "") .. "Tactics: " .. e.Tip
                else
                    body.Text = "Defeat one to learn its stats and how to beat it."
                end
                body.Parent = card
                y += 100
            end
            -- elite modifiers
            local eh = Instance.new("TextLabel")
            eh.Size = UDim2.new(0.96, 0, 0, 24); eh.Position = UDim2.new(0.02, 0, 0, y + 6); eh.BackgroundTransparency = 1; eh.Font = Enum.Font.GothamBold; eh.TextSize = 16
            eh.TextColor3 = UIStyle.Colors.Text; eh.TextXAlignment = Enum.TextXAlignment.Left
            eh.Text = "ELITE MODIFIERS   •   blue = Magic (1-2 modifiers), gold = Rare (3-4); at most one toughness modifier each" -- (UPDATE 8 Phase 5)
            eh.Parent = idxContentScroll
            y += 36
            -- (FUTURE-PROOF 2026-10-25: a GROUP key -- Resistant, Extra -- lists each of its variants; a key with no def is skipped. The
            -- page used to stop at the first group key: it has no def of its own)
            local rows = {}
            for _, key in ipairs(DungeonGeneratorShared.EliteModKeys or {}) do
                local group = DungeonGeneratorShared.ELITE_GROUPS and DungeonGeneratorShared.ELITE_GROUPS[key]
                for _, k in ipairs(group or { key }) do
                    local d = DungeonGeneratorShared.EliteMods[k]
                    if d and d.Word then table.insert(rows, d) end
                end
            end
            for _, d in ipairs(rows) do
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(0.96, 0, 0, 22); l.Position = UDim2.new(0.02, 0, 0, y); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamMedium; l.TextSize = 14
                l.TextXAlignment = Enum.TextXAlignment.Left; l.TextColor3 = Color3.fromRGB(200, 210, 230)
                l.Text = string.upper(d.Word) .. "  •  " .. tostring(d.Desc or "")
                l.Parent = idxContentScroll
                y += 24
            end
            idxContentScroll.CanvasSize = UDim2.new(0, 0, 0, y + 16)
        elseif currentIdxTab == "Archive" then
            require(sharedFolder:WaitForChild("ArchiveView")).Render(idxContentScroll, clientState)
        elseif currentIdxTab == "Guide" then
            local okS, st = pcall(StatCalculator.Calculate, clientState.EquippedWeapon, clientState.AllocatedNodes or {}, 0, clientState.Level, clientState.Attributes, clientState.EquippedGear, clientState.EquippedTitle, clientState.SocketedGems, clientState.RunBoons, clientState)
            require(sharedFolder:WaitForChild("GuideCodex")).Render(idxContentScroll, clientState, okS and st and ItemData.AttrTotals(st) or nil)
        elseif currentIdxTab == "Titles" then
            local titleKeys = {}
            for k, t in pairs(ItemData.Titles) do
                -- (retired titles only show for players who already own them)
                if not t.Retired or table.find(clientState.UnlockedTitles or {}, k) then table.insert(titleKeys, k) end
            end
            table.sort(titleKeys, function(a, b)
                return (ItemData.Titles[a].Order or 99) < (ItemData.Titles[b].Order or 99)
            end)

            idxContentScroll.CanvasSize = UDim2.new(0, 0, 0, #titleKeys * 105 + 20)

            for i, tKey in ipairs(titleKeys) do
                local tData = ItemData.Titles[tKey]
                if tData then
                    local card = Instance.new("Frame")
                    card.Size = UDim2.new(0.96, 0, 0, 96)
                    card.Position = UDim2.new(0.02, 0, 0, (i - 1) * 104 + 8)
                    card.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
                    card.BorderSizePixel = 1
                    card.BorderColor3 = tData.Color
                    card.Parent = idxContentScroll

                    local tName = Instance.new("TextLabel")
                    tName.Size = UDim2.new(0.65, 0, 0, 22)
                    tName.Position = UDim2.new(0, 10, 0, 4)
                    tName.BackgroundTransparency = 1
                    tName.Font = Enum.Font.GothamBlack
                    tName.TextSize = 17
                    tName.TextColor3 = tData.Color
                    tName.TextXAlignment = Enum.TextXAlignment.Left
                    tName.Text = "★ " .. tData.Title .. "   •   " .. tData.Rarity
                    tName.Parent = card
                    -- (UI CLEAN audit: the title's name is the card head -- display caps 20 in its own colour, the grade in Sub; no
                    -- coloured box round the card)
                    card.BorderSizePixel = 0
                    tName.FontFace = UIStyle.RoleFace("Label"); tName.TextSize = 20; tName.RichText = true; tName:SetAttribute("NoSnap", true)
                    tName.Text = string.format('%s   <font color="#%s" size="13">%s</font>', string.upper(tData.Title), UIStyle.Colors.Sub:ToHex(), string.upper(tData.Rarity or ""))

                    -- Display Title Stat Buffs
                    local buffLines = {}
                    if tData.StatBuffs then
                        for sName, sVal in pairs(tData.StatBuffs) do
                            local sFmt = (sVal > 0 and "+" or "") .. tostring(sVal * (sVal < 1 and 100 or 1)) .. (sVal < 1 and "% " or " ") .. sName
                            table.insert(buffLines, sFmt)
                        end
                    end
                    local tBuffs = Instance.new("TextLabel")
                    tBuffs.Size = UDim2.new(0.65, 0, 0, 20)
                    tBuffs.Position = UDim2.new(0, 10, 0, 26)
                    tBuffs.BackgroundTransparency = 1
                    tBuffs.Font = Enum.Font.GothamBold
                    tBuffs.TextSize = 14
                    tBuffs.TextColor3 = UIStyle.Colors.Good
                    tBuffs.TextXAlignment = Enum.TextXAlignment.Left
                    tBuffs.Text = "◆ " .. tData.Description
                    tBuffs.Parent = card

                    local tReq = Instance.new("TextLabel")
                    tReq.Size = UDim2.new(0.65, 0, 0, 20)
                    tReq.Position = UDim2.new(0, 10, 0, 46)
                    tReq.BackgroundTransparency = 1
                    tReq.Font = Enum.Font.GothamMedium
                    tReq.TextSize = 14
                    tReq.TextColor3 = Color3.fromRGB(200, 220, 245)
                    tReq.TextXAlignment = Enum.TextXAlignment.Left
                    local _, cur, need = ItemData.TitleProgress(tKey, clientState)
                    tReq.Text = "Requirement: " .. tData.Requirement .. ((need > 1 and not table.find(clientState.UnlockedTitles or {}, tKey)) and string.format("  (%s / %s)", ItemData.FormatNumber(cur), ItemData.FormatNumber(need)) or "")
                    tReq.Parent = card

                    local tReward = Instance.new("TextLabel")
                    tReward.Size = UDim2.new(0.65, 0, 0, 20)
                    tReward.Position = UDim2.new(0, 10, 0, 68)
                    tReward.BackgroundTransparency = 1
                    tReward.Font = Enum.Font.GothamBold
                    tReward.TextSize = 14
                    tReward.TextColor3 = Color3.fromRGB(214, 218, 228)
                    tReward.TextXAlignment = Enum.TextXAlignment.Left
                    local rw = { string.format("+%s Gold", ItemData.FormatNumber(tData.RewardGold or 0)) }
                    for _, mat in ipairs(ItemData.MaterialOrder) do
                        local n = (tData.RewardMats or {})[mat]
                        if n then table.insert(rw, string.format("+%d %s", n, ItemData.MaterialDefs[mat].Short)) end
                    end
                    if (tData.RewardGold or 0) <= 0 then table.remove(rw, 1) end -- (UI CLEAN audit: no "+0 Gold" line)
                    tReward.Text = (#rw > 0) and ("Rewards: " .. table.concat(rw, "  |  ")) or "No reward: the starting title"
                    tReward.Parent = card

                    local isEquipped = (clientState.EquippedTitle == tKey)
                    local isUnlocked = table.find(clientState.UnlockedTitles or {}, tKey) ~= nil
                    local canClaim = (not isUnlocked) and CheckTitleRequirement(tKey)

                    local btnAction = Instance.new("TextButton")
                    btnAction.Size = UDim2.new(0, 140, 0, 32)
                    btnAction.Position = UDim2.new(1, -150, 0.5, -16)
                    btnAction.Font = Enum.Font.GothamBold
                    btnAction.TextSize = 15
                    btnAction.BorderSizePixel = 0
                    btnAction.Parent = card

                    -- (UI CLEAN audit: the button roles -- CLAIM = the primary, EQUIP = an outline, EQUIPPED / LOCKED = words, not slabs)
                    btnAction.FontFace = UIStyle.RoleFace("Label"); btnAction.TextSize = 14; btnAction.AutoButtonColor = false; btnAction:SetAttribute("NoSkin", true)
                    if isEquipped then
                        btnAction.Text = "✓ EQUIPPED"
                        btnAction.BackgroundTransparency = 1
                        btnAction.TextColor3 = UIStyle.Colors.Text
                    elseif isUnlocked then
                        btnAction.Text = "EQUIP TITLE"
                        btnAction.BackgroundTransparency = 1
                        btnAction.TextColor3 = UIStyle.Colors.Text
                        local es = Instance.new("UIStroke"); es.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; es.Color = UIStyle.Colors.Text; es.Transparency = 0.84; es.Parent = btnAction
                        btnAction.MouseButton1Click:Connect(function()
                            SoundHelper.Play("Click")
                            Remotes.GetFunction("EquipTitle"):InvokeServer(tKey)
                            clientState.EquippedTitle = tKey
                            RenderIndexContent()
                            UpdateWeaponHUD()
                        end)
                    elseif canClaim then
                        -- Requirement actually met: light the button up gold/yellow so it's obvious
                        -- at a glance which titles are actually ready to claim.
                        btnAction.Text = "★ CLAIM REWARD"
                        btnAction.BackgroundColor3 = UIStyle.Colors.Accent
                        btnAction.TextColor3 = UIStyle.Colors.OnAccent
                        btnAction.MouseButton1Click:Connect(function()
                            SoundHelper.Play("Click")
                            local ok, err = Remotes.GetFunction("ClaimTitle"):InvokeServer(tKey)
                            if ok then
                                SoundHelper.Play("Victory")
                                ShowToast("★ Title Unlocked: " .. tData.Title .. "!")
                                RenderIndexContent()
                                UpdateWeaponHUD()
                            else
                                ShowToast(tostring(err))
                                RenderIndexContent()
                            end
                        end)
                    else
                        -- Requirement not yet met: grey and non-claiming, so the always-lit-up look
                        -- that made every title feel claimable regardless of progress is gone.
                        btnAction.Text = "LOCKED"
                        btnAction.BackgroundTransparency = 1
                        btnAction.TextColor3 = UIStyle.Colors.Muted
                        btnAction.MouseButton1Click:Connect(function()
                            SoundHelper.Play("Click")
                            ShowToast("Requirement: " .. tData.Requirement)
                        end)
                    end
                end
            end
        end

    end

    tabWeaponsIdx.MouseButton1Click:Connect(function() currentIdxTab = "Weapons"; RenderIndexContent() end)
    tabGearIdx.MouseButton1Click:Connect(function() currentIdxTab = "Gear"; RenderIndexContent() end)
    tabTraitsIdx.MouseButton1Click:Connect(function() currentIdxTab = "Traits"; RenderIndexContent() end)
    tabBestiaryIdx.MouseButton1Click:Connect(function() currentIdxTab = "Bestiary"; RenderIndexContent() end)
    tabTitlesIdx.MouseButton1Click:Connect(function() currentIdxTab = "Titles"; RenderIndexContent() end)
    UI.tabArchiveIdx.MouseButton1Click:Connect(function() currentIdxTab = "Archive"; RenderIndexContent() end)
    UI.tabGuideIdx.MouseButton1Click:Connect(function() currentIdxTab = "Guide"; RenderIndexContent() end)
    -- (UI CLEAN audit, Studio: DevAct "ui:DevIdxTab" opens the tab named by Player attr DevIdxTab -- no input tools to click it)
    -- (UI CLEAN audit) a section head in the Index pages: SectionHead caps in Text, the display face, no dashes
    UI.KitHead = function(l) l.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.SemiBold); l.TextSize = 15; l.TextColor3 = UIStyle.Colors.Text; l:SetAttribute("NoSnap", true) end
    UI.DevIdxTab = function() currentIdxTab = tostring(LocalPlayer:GetAttribute("DevIdxTab") or "Weapons"); RenderIndexContent() end
    pcall(function() -- (UPDATE 7 B4 SHARED SPOILS) the party pick window
        require(sharedFolder:WaitForChild("SpoilsMenu")).Init(UI.menuFolder, {
            Toast = function(t) ShowToast(t) end,
            Click = function() SoundHelper.Play("Click") end,
        })
    end)
    do -- (UPDATE 7 B9) THE GUILD window (dock tile GUILD)
        local gm
        UI.OpenGuild = function()
            gm = gm or require(sharedFolder:WaitForChild("GuildMenu")).Init(UI.menuFolder, {
                Toast = function(t) ShowToast(t) end,
                Click = function() SoundHelper.Play("Click") end,
                OpenFrame = function(f) OpenMenuFrame(f) end,
            })
            gm.Open()
        end
    end
    do -- (2026-10-20) THE PARTY FINDER window (MENU tile, the Dungeons window's ALL SERVERS button)
        local pf
        UI.OpenPartyFinder = function()
            pf = pf or require(sharedFolder:WaitForChild("PartyFinderMenu")).Init(UI.menuFolder, {
                Toast = function(t) ShowToast(t) end,
                Click = function() SoundHelper.Play("Click") end,
                OpenFrame = function(f) OpenMenuFrame(f) end,
                Close = function() CloseAllMenus() end,
                GetState = function() return clientState end,
                OpenDungeons = function() if UI.dungFrame and not UI.dungFrame.Visible then OpenMenuFrame(UI.dungFrame) end end,
            })
            UI.PartyFinderApi = pf
            pf.Open()
        end
    end
;(function() -- (UPDATE 8 OFFENSE phase 3) the MODS window: shot mods into gun sockets (AimRngShared/ShotModMenu; MENU tile MODS,
        -- the inventory ITEMS tab, OpenMenu "ShotMods", Studio DevAct "open:ShotMods")
        local smm
        UI.OpenShotMods = function(gunUid)
            smm = smm or require(sharedFolder:WaitForChild("ShotModMenu")).Init(UI.menuFolder, {
                Toast = function(t) ShowToast(t) end,
                Click = function() SoundHelper.Play("Click") end,
                OpenFrame = function(f) OpenMenuFrame(f) end,
                Close = function() CloseAllMenus() end,
                GetState = function() return clientState end,
                HookItemTooltip = function(gui, item, isGear) if UI.HookItemTooltip then UI.HookItemTooltip(gui, item, isGear) end end,
            })
            UI.ShotModsApi = smm
            smm.Open(gunUid)
        end
        UI.ShotModsBag = function(scroll)
            require(sharedFolder:WaitForChild("ShotModMenu")).RenderBag(scroll, clientState, function()
                SoundHelper.Play("Click")
                UI.OpenShotMods()
            end)
        end
    end)()
    do -- (2026-10-20) PROFILES window: anyone's gear / build / cosmetics + the AIM profile (MENU tile, a click on a player in
        -- the city, a Hall of Aim statue)
        local pm
        UI.OpenProfile = function(uid, tab)
            pm = pm or require(sharedFolder:WaitForChild("ProfileMenu")).Init(UI.menuFolder, {
                Toast = function(t) ShowToast(t) end,
                Click = function() SoundHelper.Play("Click") end,
                OpenFrame = function(f) OpenMenuFrame(f) end,
                Close = function() CloseAllMenus() end,
                HookItemTooltip = function(gui, item, isGear) if UI.HookItemTooltip then UI.HookItemTooltip(gui, item, isGear) end end,
            })
            pm.Open(uid, tab)
        end
        -- click (or tap) another player in the third-person city -> their profile
        local function TryInspect(screenPos: Vector2)
            if isAnyMenuOpen or not LocalPlayer:GetAttribute("ThirdPerson") or UI.watching then return end
            local cam = workspace.CurrentCamera
            if not cam then return end
            local ray = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { LocalPlayer.Character }
            local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
            local model = hit and hit.Instance and hit.Instance:FindFirstAncestorOfClass("Model")
            while model and not Players:GetPlayerFromCharacter(model) and model.Parent and model.Parent:IsA("Model") do model = model.Parent end
            local who = model and Players:GetPlayerFromCharacter(model)
            if who and who ~= LocalPlayer then SoundHelper.Play("Click"); UI.OpenProfile(who.UserId, "Overview") end
        end
        UserInputService.InputBegan:Connect(function(input, processed)
            if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            TryInspect(UserInputService:GetMouseLocation())
        end)
        UserInputService.TouchTapInWorld:Connect(function(pos, processed) if not processed then TryInspect(pos) end end)
    end
    do -- (2026-10-20) INVITE FRIENDS window (MENU tile)
        local rm
        UI.OpenReferrals = function()
            rm = rm or require(sharedFolder:WaitForChild("ReferralMenu")).Init(UI.menuFolder, {
                Toast = function(t) ShowToast(t) end,
                Click = function() SoundHelper.Play("Click") end,
                OpenFrame = function(f) OpenMenuFrame(f) end,
                Close = function() CloseAllMenus() end,
            })
            rm.Open()
        end
    end
    do -- (UPDATE 7 C7) THE MARKET window (hub market board, the stash's MARKET button)
        local mm
        UI.OpenMarket = function(t)
            mm = mm or require(sharedFolder:WaitForChild("MarketMenu")).Init(UI.menuFolder, {
                GetState = function() return clientState end,
                Toast = function(t2) ShowToast(t2) end,
                Click = function() SoundHelper.Play("Click") end,
                OpenFrame = function(f) OpenMenuFrame(f) end,
                -- (QOL2 I6: every row with an item gets the bag's card -- hover, click / tap to pin, pad selection)
                Card = function(gui, item, isGear) if UI.HookItemCard then UI.HookItemCard(gui, item, isGear) end end,
                TextCard = function(gui, fn) if UI.HookTextCard then UI.HookTextCard(gui, fn) end end,
                HideTooltip = function() if UI.HideTooltip then UI.HideTooltip() end end,
            })
            mm.Open(t)
        end
    end
    do -- (UPDATE 7 B5 CITY DISTRICTS) the window the hub's district leaders open
        local dm
        UI.OpenDistricts = function(id)
            dm = dm or require(sharedFolder:WaitForChild("DistrictsMenu")).Init(UI.menuFolder, {
                GetState = function() return clientState end,
                Toast = function(t) ShowToast(t) end,
                Click = function() SoundHelper.Play("Click") end,
                OpenFrame = function(f) OpenMenuFrame(f) end,
            })
            dm.Open(id)
        end
        Remotes.GetEvent("SyncPlayerState").OnClientEvent:Connect(function() if dm then task.defer(dm.Refresh) end end)
    end
    UI.OpenArchive = function() -- (UPDATE 7: the Index on its ARCHIVE tab; Studio: Player attr DevAct "archive:1")
        currentIdxTab = "Archive"
        if not UI.indexFrame.Visible then OpenMenuFrame(UI.indexFrame) end
        RenderIndexContent()
    end
    -- (0.93, owner: "titles need to be in a more accessible place"): the TITLES dock tile and the inventory's TITLE slot open
    -- the Index straight on its Titles tab (claim / equip / progress)
    UI.OpenGuideCodex = function() -- (UPDATE 8 OFFENSE: the Index on its HOW IT WORKS tab; unlock cards + Studio DevAct "codex:1")
        currentIdxTab = "Guide"
        if not UI.indexFrame.Visible then OpenMenuFrame(UI.indexFrame) end
        RenderIndexContent()
    end
    UI.OpenTitles = function()
        currentIdxTab = "Titles"
        if not UI.indexFrame.Visible then OpenMenuFrame(UI.indexFrame) end
        RenderIndexContent()
    end


    local function AddModalCapture(frame: Frame)
        local btn = Instance.new("TextButton")
        btn.Name = "ModalCapture"
        btn.Size = UDim2.new(0, 0, 0, 0)
        btn.Position = UDim2.new(0, 0, 0, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Modal = true
        btn.Parent = frame
    end
    AddModalCapture(UI.rollFrame)
    AddModalCapture(UI.treeFrame)
    AddModalCapture(UI.invFrame)
    AddModalCapture(UI.shopFrame)
    AddModalCapture(UI.upgFrame)
    AddModalCapture(UI.dungFrame)
    AddModalCapture(UI.setFrame)
    AddModalCapture(UI.armoryFrame)
    AddModalCapture(UI.indexFrame)

    -- Menus sit above the always-on HUD (Level/Health panels are ZIndex 5) but below toasts (50)
    -- and tooltips (200), so an open menu is never partly covered by the HUD.
    for _, m in ipairs(UI.menuFolder:GetChildren()) do
        if m:IsA("GuiObject") then m.ZIndex = 10 end
    end
end
BuildAllMenus()

-- One look everywhere: old windows become themed windows (title bar + close), and every HUD / menu
-- element (including rows and popups built later) is restyled to match Settings / Dungeons / Forge.
for frame, header in pairs(UI.windowHeaders or {}) do
    UIStyle.SkinWindow(frame, header, function() CloseAllMenus() end)
end
for frame, header in pairs(UI.bannerHeaders or {}) do UIStyle.SkinWindow(frame, header) end
UIStyle.Skin(hudGui)
-- open windows always draw above the HUD (gun card, level / HP panels)
for _, w in ipairs(UI.menuFolder:GetChildren()) do
    if w:IsA("GuiObject") then w.ZIndex = math.max(w.ZIndex, 10) end
end

pcall(function()
    if RefreshInventory then RefreshInventory() end
    if RefreshShopMenu then RefreshShopMenu() end
    if RefreshUpgradeMenu then RefreshUpgradeMenu() end
    if RefreshArmoryMenu then RefreshArmoryMenu() end
    if RenderIndexContent then RenderIndexContent() end
end)

-- Top Nav Buttons Connections
UI.btnRoll.MouseButton1Click:Connect(function()
    UI.rGoldBal.Text = string.format("YOUR GOLD: %d  |  ROLL COST: 150 GOLD", clientState.Gold or 0)
    OpenMenuFrame(UI.rollFrame)
end)
UI.btnTree.MouseButton1Click:Connect(function() OpenMenuFrame(UI.treeFrame); RefreshTree() end)
UI.btnInv.MouseButton1Click:Connect(function() OpenMenuFrame(UI.invFrame); RefreshInventory() end)
UI.btnShop.MouseButton1Click:Connect(function() OpenMenuFrame(UI.shopFrame); RefreshShopMenu() end)
UI.btnUpg.MouseButton1Click:Connect(function() RefreshUpgradeMenu(); OpenMenuFrame(UI.upgFrame) end)
UI.btnDung.MouseButton1Click:Connect(function() OpenMenuFrame(UI.dungFrame) end)
UI.btnIndex.MouseButton1Click:Connect(function() OpenMenuFrame(UI.indexFrame); RenderIndexContent() end)
UI.btnChall.MouseButton1Click:Connect(function() OpenMenuFrame(UI.challFrame) end)
UI.btnSet.MouseButton1Click:Connect(function() OpenMenuFrame(UI.setFrame) end)

-- HUB WARP: in the hub (only there -- never in a dungeon, party run, rift or Aim Trial), opening a menu with its key
-- also teleports you in front of that menu's station, facing it. Closing a menu with its key doesn't move you.
local HUB_WARP = {
    Shop = { "ShopStand", function() return UI.shopFrame end }, Forge = { "RollAltar", function() return UI.rollFrame end },
    Upgrade = { "UpgradeAnvil", function() return UI.upgFrame end }, Inventory = { "InvLocker", function() return UI.invFrame end },
    Tree = { "TreeAltar", function() return UI.treeFrame end }, Index = { "IndexAltar", function() return UI.indexFrame end },
    Armory = { "ArmoryStand", function() return UI.armoryFrame end }, Arena = { "PortalVortex", function() return UI.dungFrame end },
    Challenges = { "ChallengeVortex", function() return UI.challFrame end },
}
local function HubWarp(action: string?)
    local spec = action and HUB_WARP[action]
    if not spec then return end
    local frame = spec[2]()
    if not frame or frame.Visible then return end -- this key press closes the menu
    if UI.TrialRunner and UI.TrialRunner.IsRunning() then return end
    if LocalPlayer:GetAttribute("RunId") then return end
    local run = LocalPlayer.PlayerGui:FindFirstChild("AimRngRun")
    if run and run:GetAttribute("RaidActive") then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hub = Workspace:FindFirstChild("HubWorld")
    local anchor = hub and hub:FindFirstChild(spec[1])
    if not root or not anchor or not anchor:IsA("BasePart") then return end
    if root.Position.Z > 450 or root.Position.Y > 300 then return end -- not standing in the hub
    local a = anchor.Position
    local stand
    if spec[1] == "PortalVortex" or spec[1] == "ChallengeVortex" then
        stand = Vector3.new(a.X, 6, a.Z + 26) -- at the foot of the gate's stairs
    else
        local out = Vector3.new(-a.X, 0, 0).Unit -- booths sit on the side walls and face the middle
        stand = Vector3.new(a.X, 6, a.Z) + out * 9
    end
    if (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(stand.X, 0, stand.Z)).Magnitude < 6 then return end
    TeleportClient(CFrame.lookAt(stand, Vector3.new(a.X, 6, a.Z)))
    SoundHelper.Play("Click")
end

-- ==================== TELEPORT MENU ([G], hub only) + SIDE DOCK + LOST GEAR ====================
-- (its own function: the main chunk is at Luau's 200-local limit)
;(function()
    local C = UIStyle.Colors
    local function Corner(o, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, math.min(r, 2)); c.Parent = o end -- (Mega-City: square)
    local function Stroke(o, t, col) local st = Instance.new("UIStroke"); st.Thickness = t; st.Color = col or Color3.fromRGB(16, 18, 28); st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Parent = o end
    local function Label(parent, props)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.TextColor3 = Color3.new(1, 1, 1)
        l.Font = UIStyle.Font or Enum.Font.GothamBlack
        for k, v in pairs(props) do l[k] = v end
        l.Parent = parent
        return l
    end

    -- name, what it's for, kind, hub anchor, colour, postcard (0.58, owner: "Teleport icons need a full revamp":
    -- tools/make_teleport_cards.py draws each place as a neon sign on a walled-city wall, its Chinese shop name on a blade)
    local TP = "rbxassetid://"
    local DESTS = {
        { "DUNGEONS", "Start a run: pick a difficulty, solo or with a party. Every floor is a new biome", "Gate", "PortalVortex", Color3.fromRGB(230, 60, 230), TP .. "137937768806723" },
        { "CHALLENGES", "Boss Trials, Provings, the Daily Challenge, Aim Trials and weapon mastery", "Gate", "ChallengeVortex", Color3.fromRGB(240, 200, 40), TP .. "116618152206377" },
        { "TRAINING GROUNDS", "DPS test and a practice range for every bot type", "Range", nil, Color3.fromRGB(0, 210, 235), TP .. "72435219682059" },
        { "SHOP", "Buy guns and gear, stock refreshes every hour", "Booth", "ShopStand", Color3.fromRGB(245, 205, 60), TP .. "110968360999834" },
        { "FORGE", "Free daily roll, upgrades and affix rerolls", "Booth", "RollAltar", Color3.fromRGB(255, 145, 40), TP .. "126279366856868" },
        { "UPGRADE", "Spend materials to push a gun up to +20", "Booth", "UpgradeAnvil", Color3.fromRGB(60, 210, 255), TP .. "133025573223148" },
        { "INVENTORY", "Your bag: weapons, gear and currencies (your stash is in your hideout)", "Booth", "InvLocker", Color3.fromRGB(70, 145, 255), TP .. "129256548812605" },
        { "SKILL TREE", "Spend skill points on the passive tree and socket gems", "Booth", "TreeAltar", Color3.fromRGB(70, 225, 120), TP .. "116871783561871" },
        { "INDEX", "Every gun, rarity and enemy. The game's index", "Booth", "IndexAltar", Color3.fromRGB(0, 195, 225), TP .. "134959908285703" },
        { "ARMORY", "Melee weapons", "Booth", "ArmoryStand", Color3.fromRGB(240, 70, 90), TP .. "140586406954626" },
        { "SEASON PASS", "50 tiers of free rewards this season", "Booth", "SeasonStand", Color3.fromRGB(195, 120, 255), TP .. "127764720323317" },
        { "THE BAZAAR", "The trading hub: trade tables, traders and the furniture stall", "Market", nil, Color3.fromRGB(64, 200, 160), TP .. "126060014435997" },
        { "MY HIDEOUT", "Your own hideout: decorate it, use its stations, open maps, invite friends", "Hideout", nil, Color3.fromRGB(255, 150, 90), TP .. "113208053369430" },
        { "HUB CENTER", "Back to the middle of the hub", "Center", nil, Color3.fromRGB(110, 140, 255), TP .. "76971809026940" },
    }
    local panel = UIStyle.Panel(UI.menuFolder, { Name = "TeleportMenu", Size = UDim2.fromOffset(900, 690), Accent = Color3.fromRGB(150, 40, 220) })
    UIStyle.TitleBar(panel, "TELEPORT", Color3.fromRGB(150, 40, 220), "go straight to any area of the hub", function() CloseAllMenus() end)
    -- (2026-10-13 phones: the cards scroll -- a phone gets the window only as tall as its screen; on desktop they all fit)
    panel:SetAttribute("PhoneMinH", 300)
    local grid = Instance.new("ScrollingFrame")
    grid.BackgroundTransparency = 1
    grid.BorderSizePixel = 0
    grid.Position = UDim2.fromOffset(20, 80)
    grid.Size = UDim2.new(1, -40, 1, -146)
    grid.CanvasSize = UDim2.new()
    grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
    grid.ScrollingDirection = Enum.ScrollingDirection.Y
    grid.ScrollBarThickness = 4
    grid.Parent = panel
    local layout = Instance.new("UIGridLayout")
    layout.CellSize = UDim2.fromOffset(280, 100)
    layout.CellPadding = UDim2.fromOffset(10, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = grid
    -- (UI CLEAN R-A2: the cards' neon art reaches over the cell top; the scroll clipped the first row under the top bar)
    local gpad = Instance.new("UIPadding"); gpad.PaddingTop = UDim.new(0, 10); gpad.Parent = grid -- (no side padding: 3 x 280 + 2 x 10 = the full 860)

    local function InHub(): boolean
        if UI.TrialRunner and UI.TrialRunner.IsRunning() then return false end
        if LocalPlayer:GetAttribute("RunId") then return false end
        local run = LocalPlayer.PlayerGui:FindFirstChild("AimRngRun")
        if run and run:GetAttribute("RaidActive") then return false end
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        return root ~= nil and root.Position.Z < 450 and root.Position.Y < 300
    end
    local function Go(d)
        if not InHub() then ShowToast("Teleport only works in the hub") return end
        -- (0.62, owner: "cant use teleport menu from your hideout"): a themed hideout parks the city (HubWorld out of the
        -- world), so every area's anchor was missing. Bring the city back first, and leave the hideout on the server
        -- (without its own walk-you-to-the-street teleport) once we go somewhere else.
        if UI.ShowHub then UI.ShowHub() end
        local root0 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local fromHideout = root0 ~= nil and UI.Zones.Kind(root0.Position) == "hideout" and d[3] ~= "Hideout"
        local stand, look
        if d[3] == "Range" then
            stand, look = Vector3.new(0, 6, 77), Vector3.new(0, 6, 120) -- the training grounds' firing line
        elseif d[3] == "Hideout" then
            CloseAllMenus()
            task.spawn(function() Remotes.GetFunction("HideoutAction"):InvokeServer("Enter") end)
            SoundHelper.Play("Click")
            return
        elseif d[3] == "Market" then
            local o = UI.Zones.MARKET_CENTER
            stand, look = o + Vector3.new(0, 3, 52), o + Vector3.new(0, 3, 0) -- (HubMarket.SPAWN)
        elseif d[3] == "Center" then
            stand, look = Vector3.new(0, 6, 24), Vector3.new(0, 6, -40) -- (HUB v4: by the waypoint)
        else
            local hub = Workspace:FindFirstChild("HubWorld")
            local anchor = hub and hub:FindFirstChild(d[4])
            if not anchor or not anchor:IsA("BasePart") then ShowToast("That area isn't built yet") return end
            local a = anchor.Position
            if d[3] == "Gate" then
                stand = Vector3.new(a.X, 6, a.Z + 26) -- at the foot of the gate's stairs
            else
                stand = Vector3.new(a.X, 6, a.Z) + Vector3.new(-a.X, 0, 0).Unit * 9 -- booths face the middle
            end
            look = Vector3.new(a.X, 6, a.Z)
        end
        CloseAllMenus()
        if fromHideout then task.spawn(function() pcall(function() Remotes.GetFunction("HideoutAction"):InvokeServer("Leave", "Stay") end) end) end
        TeleportClient(CFrame.lookAt(stand, look))
        SoundHelper.Play("Click")
    end
    -- the info bar under the grid: what the hovered place is for
    local info = Instance.new("Frame")
    info.Name = "TpInfo"
    info.Position = UDim2.new(0, 20, 1, -58)
    info.Size = UDim2.new(1, -40, 0, 42)
    info.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
    info:SetAttribute("NoSkin", true)
    info.Parent = panel
    Corner(info, 6)
    local infoBar = Instance.new("Frame"); infoBar.Size = UDim2.new(0, 4, 1, -10); infoBar.Position = UDim2.fromOffset(6, 5); infoBar.BorderSizePixel = 0
    infoBar.BackgroundColor3 = Color3.fromRGB(150, 40, 220); infoBar.Parent = info
    local infoText = Label(info, { Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -30, 1, 0), Text = "Pick a place. You're there in a blink.", TextSize = 16,
        Font = UIStyle.BodyFont or Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 206, 222), TextWrapped = true })
    -- one POSTCARD per destination: the neon-sign art, its name across the bottom, a glowing frame on hover
    for i, d in ipairs(DESTS) do
        local card = Instance.new("ImageButton")
        card.Name = d[1]
        card.LayoutOrder = i
        card.AutoButtonColor = false
        card.Image = d[6]
        card.ScaleType = Enum.ScaleType.Crop
        card.BackgroundColor3 = Color3.fromRGB(14, 12, 18)
        card:SetAttribute("NoSkin", true)
        card.Parent = grid
        Corner(card, 8)
        local cst = Instance.new("UIStroke"); cst.Thickness = 2; cst.Color = d[5]:Lerp(Color3.new(0, 0, 0), 0.45); cst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; cst.Parent = card
        local zoom = Instance.new("UIScale"); zoom.Parent = card
        -- a dark fade along the bottom so the name reads over the art
        local shade = Instance.new("Frame")
        shade.BackgroundColor3 = Color3.new(0, 0, 0); shade.BorderSizePixel = 0
        shade.Position = UDim2.fromScale(0, 0.52); shade.Size = UDim2.fromScale(1, 0.48)
        shade.Parent = card
        Corner(shade, 8)
        local sg = Instance.new("UIGradient"); sg.Rotation = 90
        sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.35), NumberSequenceKeypoint.new(1, 0.15) }); sg.Parent = shade
        Label(card, { Position = UDim2.new(0, 12, 1, -32), Size = UDim2.new(1, -24, 0, 26), Text = d[1], TextSize = 21, ZIndex = 2,
            TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = d[5]:Lerp(Color3.new(1, 1, 1), 0.45), TextStrokeTransparency = 0.4 })
        local edge = Instance.new("Frame") -- (a neon underline that lights on hover)
        edge.BorderSizePixel = 0; edge.BackgroundColor3 = d[5]; edge.BackgroundTransparency = 1
        edge.Position = UDim2.new(0, 12, 1, -6); edge.Size = UDim2.new(0, 0, 0, 3); edge.ZIndex = 2; edge.Parent = card
        local function Hover(on: boolean)
            TweenService:Create(zoom, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = on and 1.035 or 1 }):Play()
            TweenService:Create(edge, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Size = UDim2.new(0, on and 120 or 0, 0, 3), BackgroundTransparency = on and 0 or 1 }):Play()
            cst.Color = on and d[5] or d[5]:Lerp(Color3.new(0, 0, 0), 0.45)
            cst.Thickness = on and 3 or 2
            if on then
                infoText.Text = d[1] .. "  •  " .. d[2]
                infoBar.BackgroundColor3 = d[5]
            end
        end
        card.MouseEnter:Connect(function() Hover(true) end)
        card.MouseLeave:Connect(function() Hover(false) end)
        card.SelectionGained:Connect(function() Hover(true) end)
        card.SelectionLost:Connect(function() Hover(false) end)
        card.MouseButton1Click:Connect(function() Go(d) end)
    end
    UI.ToggleTeleportMenu = function()
        if not panel.Visible and not InHub() then ShowToast("Teleport only works in the hub") return end
        OpenMenuFrame(panel)
    end

    -- ===== LOST GEAR (run loot you lost): buy items back one at a time until your next run =====
    local RL = ItemData.RunLoot
    local lostPanel = UIStyle.Panel(UI.menuFolder, { Name = "LostGearMenu", Size = UDim2.fromOffset(620, 520), Accent = Color3.fromRGB(220, 60, 60) })
    lostPanel:SetAttribute("PhoneMinH", 300) -- (phones: as tall as the screen; its list scrolls)
    UIStyle.TitleBar(lostPanel, "LOST LOOT", Color3.fromRGB(200, 50, 50), "Mythic and Relic drops you left behind. Buy them back any time", function() CloseAllMenus() end)
    local list = Instance.new("ScrollingFrame")
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.Position = UDim2.fromOffset(20, 80)
    list.Size = UDim2.new(1, -40, 1, -100)
    list.ScrollBarThickness = 8
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.CanvasSize = UDim2.new()
    list.Parent = lostPanel
    local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 8); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = list
    local function RenderLost()
        for _, c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local lost = clientState.LostLoot or {}
        if #lost == 0 then
            UIStyle.EmptyState(list, "Nothing to recover", "Mythic and Relic drops you leave on a floor show up here.", { Size = UDim2.new(1, -12, 0, 120) })
            return
        end
        for i, e in ipairs(lost) do
            local it = e.Item or {}
            local rarity = it.Rarity or "Common"
            local col = (e.Kind ~= "Gem" and ItemData.ItemColor(it)) or ItemData.RarityColors[rarity] or Color3.new(1, 1, 1) -- (CHASE ITEMS review: a Zenith shows as ZENITH, not Relic)
            -- (UI CLEAN R-B: the shared item row card -- InvLayout.ItemRow: rarity edge + tint, display name, sub-line, icon box)
            local rr = UI.InvL.ItemRow(list, { Item = it, Color = col, Order = i, Height = 58, RightPad = 210, NoIcon = e.Kind == "Gem",
                Name = ((e.Kind ~= "Gem" and ItemData.ZenithOf(it)) and "❖ " or "") .. tostring(it.Name or it.BaseId or "Item"),
                Sub = ((e.Kind ~= "Gem") and ItemData.RarityLabel(it) or rarity) .. "  " .. tostring(e.Kind or "") .. (it.ItemLevel and ("  •  iLvl " .. it.ItemLevel) or "") .. (it.Twinned and "  •  TWINNED" or "") })
            local row = rr.Btn
            row.Size = UDim2.new(1, -12, 0, 58)
            if e.Kind ~= "Gem" and UI.HookItemTooltip then UI.HookItemTooltip(row, it, e.Kind == "Gear") end
            -- (2026-10-20: BOUND points, behind the popup that shows how many you need)
            local price = RL.RecoverPrices[rarity] or 250
            local btn = UIStyle.Button(row, "RECOVER  -  " .. tostring(price) .. " BOUND", UIStyle.Colors.Steel, UDim2.fromOffset(200, 36), UDim2.new(1, -(rr.Reserved + 204), 0.5, -18)) -- (R-B2: a row's buy = secondary, like the Exchange's BUY)
            btn.Label.TextSize = 15
            btn.Button.MouseButton1Click:Connect(function()
                SoundHelper.Play("Click")
                require(sharedFolder:WaitForChild("BoundShop")).Confirm({ Name = tostring(it.Name or it.BaseId or "this item"), Price = price, Desc = "Back into your bag.",
                    OnBuy = function()
                        local ok, msg = Remotes.GetFunction("BoundBuy"):InvokeServer("Recover", i)
                        if ok then task.delay(0.3, function() if lostPanel.Visible then RenderLost() end end) end
                        return ok, msg
                    end })
            end)
        end
    end
    UI.OpenLostGear = function() RenderLost(); if not lostPanel.Visible then OpenMenuFrame(lostPanel) end end
    Remotes.GetEvent("RunLootLost").OnClientEvent:Connect(function(n)
        ShowToast(n .. " Mythic / Relic item" .. (n == 1 and "" or "s") .. " left behind went to LOST LOOT: buy them back from MENU > LOST LOOT in the city")
    end)

    -- SIDE DOCK v3 (0.60f, owner: "The list of keybinds on the left is a little overwhelming, and also doesn't match our
    -- aesthetic (text wise and icon wise)"): the tiles are built like the Mega-City icons themselves -- a square gunmetal
    -- slab with one hard shaded facet and a heavy edge, the icon in the accent. No always-on name pills or key badges:
    -- hovering a tile turns it to the accent (icon in ink) and ONE flag slides out beside it with the name and the key.
    local TILE, GAP = 54, 8
    local dock = Instance.new("Frame")
    dock.Name = "SideDock"
    dock.BackgroundTransparency = 1
    -- starts under the GUIDE / PATCH NOTES buttons (y 72..130) and scales down to fit short screens (see the Heartbeat below)
    dock.AnchorPoint = Vector2.new(0, 0)
    dock.Position = UDim2.new(0, 16, 0, 142)
    dock.Size = UDim2.fromOffset(TILE, 9 * (TILE + GAP))
    dock:SetAttribute("NoSkin", true)
    dock.Parent = hudGui
    UI.dockScale = Instance.new("UIScale"); UI.dockScale.Parent = dock
    local dl = Instance.new("UIListLayout"); dl.Padding = UDim.new(0, GAP); dl.SortOrder = Enum.SortOrder.LayoutOrder; dl.Parent = dock
    local badges = {} -- (v2 key badges; the key now shows on the hover flag)
    local dockTiles = {}
    local DOCK_BG = Color3.fromRGB(14, 15, 18) -- (Mega-City gunmetal; every tile in Justice gold)
    local INK = UIStyle.Colors.Ink
    local function Dark(c, t) return c:Lerp(Color3.new(0, 0, 0), t) end
    -- the hover flag: an accent slab (faceted, ink edge) with the name in ink and the key on a dark cap
    local flag = Instance.new("Frame")
    flag.Name = "DockFlag"
    flag.AnchorPoint = Vector2.new(0, 0.5)
    flag.Position = UDim2.new(1, 10, 0.5, 0)
    flag.Size = UDim2.fromOffset(0, 32)
    flag.AutomaticSize = Enum.AutomaticSize.X
    flag.BackgroundColor3 = Color3.new(1, 1, 1)
    flag.BorderSizePixel = 0
    flag.Visible = false
    flag.ZIndex = 20
    flag:SetAttribute("NoSkin", true)
    local flagGrad = UIStyle.FacetGrad(Color3.new(1, 1, 1), Color3.new(0.7, 0.7, 0.7))
    flagGrad.Parent = flag
    UIStyle.InkEdge(2).Parent = flag
    local fp = Instance.new("UIPadding"); fp.PaddingLeft = UDim.new(0, 10); fp.PaddingRight = UDim.new(0, 5); fp.Parent = flag
    local fl = Instance.new("UIListLayout"); fl.FillDirection = Enum.FillDirection.Horizontal; fl.VerticalAlignment = Enum.VerticalAlignment.Center
    fl.Padding = UDim.new(0, 8); fl.SortOrder = Enum.SortOrder.LayoutOrder; fl.Parent = flag
    local flagName = Instance.new("TextLabel")
    flagName.BackgroundTransparency = 1
    flagName.Font = Enum.Font.GothamBlack -- (Label role: the condensed caps the icons' cards use)
    flagName.TextSize = 17
    flagName.TextColor3 = INK
    flagName.AutomaticSize = Enum.AutomaticSize.X
    flagName.Size = UDim2.fromOffset(0, 32)
    flagName.LayoutOrder = 1
    flagName.ZIndex = 21
    flagName.Parent = flag
    local flagKey = Instance.new("TextLabel")
    flagKey.BackgroundColor3 = INK
    flagKey.Font = Enum.Font.Code -- (Accent role: keys read as data)
    flagKey.TextSize = 13
    flagKey.AutomaticSize = Enum.AutomaticSize.X
    flagKey.Size = UDim2.fromOffset(0, 22)
    flagKey.LayoutOrder = 2
    flagKey.ZIndex = 21
    flagKey.Parent = flag
    local kp = Instance.new("UIPadding"); kp.PaddingLeft = UDim.new(0, 6); kp.PaddingRight = UDim.new(0, 6); kp.Parent = flagKey
    local function ShowFlag(rec)
        local acc = rec.Acc or rec.Col
        flagGrad.Color = UIStyle.Facet(acc, Dark(acc, 0.25))
        flagName.Text = rec.Name
        local key = rec.Action and not GameSettings.TouchOnly() and string.upper(GameSettings.KeyLabel(GameSettings.BindName(rec.Action))) or nil
        flagKey.Visible = key ~= nil
        flagKey.Text = key or ""
        flagKey.TextColor3 = acc
        flag.Parent = rec.Holder
        flag.Visible = true
    end
    local function Tile(order, icon, name, action, col, onClick)
        local holder = Instance.new("Frame")
        holder.Name = name
        holder.LayoutOrder = order
        holder.BackgroundTransparency = 1
        holder.Size = UDim2.fromOffset(TILE, TILE)
        holder.Parent = dock
        local t = Instance.new("TextButton")
        t.Name = "Tile"
        t.Text = ""
        t.AutoButtonColor = false
        t.Size = UDim2.fromScale(1, 1)
        t.BackgroundColor3 = Color3.new(1, 1, 1)
        t.BorderSizePixel = 0
        t:SetAttribute("NoSkin", true)
        t.Parent = holder
        local grad = UIStyle.FacetGrad(DOCK_BG, DOCK_BG)
        grad.Parent = t
        local st = UIStyle.InkEdge(2)
        st.Parent = t
        local glyph
        if UIStyle.HasIcon(icon) then
            glyph = UIStyle.Icon(icon, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(32, 32), ZIndex = 2, Parent = t })
        else
            glyph = Label(t, { Size = UDim2.fromScale(1, 1), Text = icon, TextSize = 28, Font = Enum.Font.GothamBold })
        end
        local rec = { Tile = t, Grad = grad, Stroke = st, Glyph = glyph, Col = col, Name = name, Action = action, Holder = holder, Hover = false, IconKey = icon, Click = onClick }
        table.insert(dockTiles, rec)
        t.MouseEnter:Connect(function() rec.Hover = true; if UI.PaintDock then UI.PaintDock() end; ShowFlag(rec) end)
        t.MouseLeave:Connect(function()
            rec.Hover = false
            if UI.PaintDock then UI.PaintDock() end
            if flag.Parent == holder then flag.Visible = false end
        end)
        t.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); onClick() end)
        return holder
    end
    UI.PaintDock = function()
        local okT, UIT = pcall(require, sharedFolder:WaitForChild("UITheme"))
        local themed = okT and UIT.Current() or nil
        for _, r in ipairs(dockTiles) do
            local acc = themed and themed.Accent or r.Col
            local bg = themed and themed.Panel and themed.Panel.Bottom or DOCK_BG
            r.Acc = acc
            if r.Hover then -- lit: the slab in the accent, the icon in ink
                r.Grad.Color = UIStyle.Facet(acc, Dark(acc, 0.28))
                r.Stroke.Color = INK
                if r.Glyph:IsA("ImageLabel") then r.Glyph.ImageColor3 = INK else r.Glyph.TextColor3 = INK end
            else
                r.Grad.Color = UIStyle.Facet(bg:Lerp(Color3.new(1, 1, 1), 0.07), bg)
                r.Stroke.Color = Dark(acc, 0.45)
                if r.Glyph:IsA("ImageLabel") then r.Glyph.ImageColor3 = acc else r.Glyph.TextColor3 = acc end
            end
        end
    end
    Tile(1, "stash", "INVENTORY", "Inventory", Color3.fromRGB(255, 184, 28), function() OpenMenuFrame(UI.invFrame); RefreshInventory() end)
    -- (0.97 UPDATE 3, owner: "There is still no passive tree hotkey on the left, either in hub or in round"): the tree's
    -- own tile (key Tree, default P) -- shown in the hub AND in runs
    Tile(2, UIStyle.HasIcon("g_build") and "g_build" or "✚", "SKILL TREE", "Tree", Color3.fromRGB(255, 184, 28), function()
        if UI.treeFrame.Visible then CloseAllMenus() else OpenMenuFrame(UI.treeFrame); RefreshTree() end
    end)
    -- the cosmetics revamp (2026-10-02, owner: "a dedicated cosmetic shop on the left in the hub and a dedicated
    -- inventory for cosmetics -- right now they're far too hard to find"): CosmeticsMenu, two doors into one window
    Tile(3, "cosmetics", "COSMETICS", "Cosmetics", Color3.fromRGB(255, 184, 28), function() if UI.OpenCosmetics then UI.OpenCosmetics("Locker") end end)
    Tile(4, "store", "STORE", "Store", Color3.fromRGB(255, 184, 28), function() if UI.OpenCosmetics then UI.OpenCosmetics("Shop") end end)
    Tile(5, "teleport", "TELEPORT", "Teleport", Color3.fromRGB(255, 184, 28), function() UI.ToggleTeleportMenu() end)
    Tile(6, UIStyle.HasIcon("trade") and "trade" or "⇄", "TRADE", "Trade", Color3.fromRGB(255, 184, 28), function() if UI.trade then UI.trade.Open() end end)
    Tile(7, UIStyle.HasIcon("hideout") and "hideout" or "⌂", "HIDEOUT", "Hideout", Color3.fromRGB(255, 184, 28), function() if UI.ToggleHideoutMenu then UI.ToggleHideoutMenu() end end)
    Tile(8, UIStyle.HasIcon("duel") and "duel" or "✕", "DUEL", "Duel", Color3.fromRGB(255, 184, 28), function() if UI.duel then UI.duel.Open() end end)
    Tile(9, UIStyle.HasIcon("title") and "title" or "★", "TITLES", nil, Color3.fromRGB(255, 184, 28), function() if UI.OpenTitles then UI.OpenTitles() end end) -- (0.93)
    Tile(10, "settings", "SETTINGS", "Settings", Color3.fromRGB(255, 184, 28), function() OpenMenuFrame(UI.setFrame) end)
    Tile(11, "◐", "SPECTATE", nil, Color3.fromRGB(255, 184, 28), function() if UI.spectate then UI.spectate.Open() end end) -- (0.62)
    local lostTile = Tile(12, "lostgear", "LOST LOOT", nil, Color3.fromRGB(210, 55, 55), function() UI.OpenLostGear() end)
    Tile(13, "❖", "CREW", nil, Color3.fromRGB(255, 184, 28), function() if UI.OpenGuild then UI.OpenGuild() end end) -- (UPDATE 7 B9)
    Tile(16, UIStyle.HasIcon("g_aim") and "g_aim" or "◎", "PROFILES", nil, Color3.fromRGB(255, 184, 28), function() if UI.OpenProfile then UI.OpenProfile(nil, "Aim") end end) -- (2026-10-20)
    Tile(15, UIStyle.HasIcon("cat_heart") and "cat_heart" or "♦", "INVITE FRIENDS", nil, Color3.fromRGB(255, 184, 28), function() if UI.OpenReferrals then UI.OpenReferrals() end end) -- (2026-10-20)
    Tile(14, UIStyle.HasIcon("g_team") and "g_team" or "◆", "PARTY FINDER", nil, Color3.fromRGB(255, 184, 28), function() if UI.OpenPartyFinder then UI.OpenPartyFinder() end end) -- (2026-10-20)
    Tile(17, UIStyle.HasIcon("g_build") and "g_build" or "●", "MODS", nil, Color3.fromRGB(255, 184, 28), function() if UI.OpenShotMods then UI.OpenShotMods() end end) -- (UPDATE 8 OFFENSE phase 3)
    Tile(18, UIStyle.HasIcon("guide") and "guide" or "◈", "HOW IT WORKS", nil, Color3.fromRGB(255, 184, 28), function() if UI.OpenGuideCodex then UI.OpenGuideCodex() end end) -- (UPDATE 8 OFFENSE: the Index's codex)
    -- (QOL F2 / F3, 2026-10-28) the Dungeons window from anywhere in the city (key O) and the Forge in the city / hideout (key I):
    -- no walk to the gate / anvil any more (the stations still work). Never in a run, a duel, an Aim Trial or the try-on range.
    Tile(19, UIStyle.HasIcon("g_endgame") and "g_endgame" or "▲", "DUNGEONS", "Dungeons", Color3.fromRGB(255, 184, 28), function() if UI.HubWindow then UI.HubWindow("Dungeons") end end)
    Tile(20, UIStyle.HasIcon("f_upgrade") and "f_upgrade" or "⚒", "FORGE", "ForgeWin", Color3.fromRGB(255, 184, 28), function() if UI.HubWindow then UI.HubWindow("Forge") end end)
    Tile(21, UIStyle.HasIcon("g_loot") and "g_loot" or "$", "EXCHANGE", nil, Color3.fromRGB(255, 184, 28), function() if UI.OpenMarket then UI.OpenMarket() end end) -- (QOL2 H3: the Exchange from the MENU; dot = sold listings waiting)
    Tile(22, UIStyle.HasIcon("notes") and "notes" or "≡", "LAST RUN", nil, Color3.fromRGB(255, 184, 28), function() if UI.OpenLastRun then UI.OpenLastRun() end end) -- (QOL2 R2: the last RUN SUMMARY again; shown once a run ended this session)
    UI.HubWindow = function(which: string) -- (QOL F2 / F3) which = "Dungeons" | "Forge"; the same key again closes it
        local frame = (which == "Dungeons") and UI.dungFrame or UI.upgFrame
        if not frame then return end
        if frame.Visible then CloseAllMenus(); return end
        if UI.InRunLocked() or LocalPlayer:GetAttribute("PvpDuel") or (UI.TrialRunner and UI.TrialRunner.IsRunning()) then
            ShowToast((which == "Dungeons" and "The Dungeons window" or "The Forge") .. " opens in the city, not during a run.")
            return
        end
        local rt = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local kind = rt and UI.Zones.Kind((rt :: BasePart).Position) or "city"
        local okZone = (kind == "city" or kind == "range") or (which == "Forge" and (kind == "hideout" or kind == "market"))
        if not okZone then
            ShowToast(which == "Dungeons" and "The Dungeons window opens in the city." or "The Forge opens in the city or your hideout.")
            return
        end
        if which == "Forge" then RefreshUpgradeMenu() end
        OpenMenuFrame(frame)
    end
    UI.DevKeyDungeons = function() UI.HubWindow("Dungeons") end -- (QOL F2 / F3 Studio hooks: DevAct "ui:DevKeyDungeons" / "ui:DevKeyForge" = the key)
    UI.DevKeyForge = function() UI.HubWindow("Forge") end

    -- SPECTATE (0.62): watch a player's run from the city through their eyes (SpectateClient / SpectateService)
    task.spawn(function()
        local SpectateClient = require(sharedFolder:WaitForChild("SpectateClient"))
        UI.spectate = SpectateClient.Init({
            menuFolder = UI.menuFolder, Hud = hudGui,
            OpenFrame = function(f) OpenMenuFrame(f) end,
            CloseAll = function() CloseAllMenus() end,
            Toast = function(m) ShowToast(m) end,
            Click = function() SoundHelper.Play("Click") end,
            ApplyLook = function(look) -- (0.83: THEIR settings + UI theme + health-bar style while you watch; yours after)
                GameSettings.SetMirror(look and look.Settings or nil)
                local HudThemesW = require(sharedFolder:WaitForChild("HudThemes"))
                if look then
                    if UI.ApplyHudTheme then pcall(UI.ApplyHudTheme, HudThemesW.For({ CosmeticsEquipped = look.Cos, Colorways = look.Colorways })) end
                    if UI.ownBarStyle == nil then UI.ownBarStyle = LocalPlayer:GetAttribute("BarStyle") or false end
                    LocalPlayer:SetAttribute("BarStyle", look.BarStyle)
                else
                    if UI.RefreshHudTheme then pcall(UI.RefreshHudTheme) end
                    if UI.ownBarStyle ~= nil then LocalPlayer:SetAttribute("BarStyle", UI.ownBarStyle or nil); UI.ownBarStyle = nil end
                end
            end,
            WatchHit = function(d, look) -- (0.83: the watched player's hit as THEY saw it: hitmarker, hit sounds, number, kill)
                local gunHit = d.Kind == nil or d.Kind == "Hit"
                if gunHit then
                    SoundHelper.ChainHit()
                    if d.IsWeakSpot then
                        if GameSettings.Get("HeadHitSound") ~= "Off" then SoundHelper.Play("HitCrit") end
                    elseif GameSettings.Get("HitSound") ~= "Off" then
                        SoundHelper.Play("HitNormal")
                    end
                    TriggerHitmarker(d.IsWeakSpot == true)
                end
                if d.Killed then
                    SoundHelper.Play("Kill")
                    if UI.SkinKill and look then
                        pcall(UI.SkinKill, d, { CosmeticsEquipped = look.Cos or {}, EquippedWeapon = look.Weapon or { BaseId = look.BaseId },
                            Colorways = look.Colorways, MeleeSkinFor = look.MeleeSkinFor }) -- (their colourways: the kill effect in THEIR colour)
                    end
                end
                if typeof(d.Position) == "Vector3" and type(d.Damage) == "number" then
                    SpawnDamageText(d.Damage, d.IsWeakSpot == true, d.IsCrit == true, d.Position, d.Kind, d.Culled, d.Elem, d.Killed, d.Target, d.DType)
                end
            end,
            SetTarget = function(p)
                UI.watching = p
                spectateTarget = p
                camInitialized = false
                if p then SetMouseLocked(false) end
            end,
        })
        UI.SpectateShot = function(...) return UI.spectate.Shot(...) end
    end)

    -- ADMIN GIFT PANEL (F6): only built for admins (the server says who; AdminService re-checks every action)
    task.spawn(function()
        pcall(function() require(sharedFolder:WaitForChild("ErrorReport")).Start() end) -- (live error log: report client errors)
        local AdminPanel = require(sharedFolder:WaitForChild("AdminPanel"))
        UI.admin = AdminPanel.Init(UI.menuFolder, {
            Open = function(f) OpenMenuFrame(f) end,
            Close = function() CloseAllMenus() end,
            Toast = function(m) ShowToast(m) end,
            Click = function() SoundHelper.Play("Click") end,
        })
    end)

    UI.RefreshDockKeys = function()
        for action, kb in pairs(badges) do
            kb.Text = string.upper(GameSettings.KeyLabel(GameSettings.BindName(action)))
            kb.Visible = not GameSettings.TouchOnly() -- (phones: no key badges on the dock)
        end
    end
    UI.RefreshDockKeys()
    UI.PaintDock()
    require(sharedFolder:WaitForChild("UITheme")).OnChanged(function() UI.PaintDock() end)

    -- ===== RUN BAG: inside a run the stash is locked; a bag on the right shows what you've found this run =====
    UI.InRunLocked = function(): boolean
        return LocalPlayer:GetAttribute("Lives") ~= nil or LocalPlayer:GetAttribute("RunId") ~= nil
    end
    local function RunItems()
        local out = {}
        for _, spec in ipairs({ { clientState.Inventory or {}, "WEAPON" }, { clientState.GearInventory or {}, "GEAR" }, { clientState.Gems or {}, "GEM" } }) do
            for _, it in ipairs(spec[1]) do if type(it) == "table" and it.RunLoot then table.insert(out, { Item = it, Kind = spec[2] }) end end
        end
        for _, g in pairs(clientState.EquippedGear or {}) do if type(g) == "table" and g.RunLoot then table.insert(out, { Item = g, Kind = "GEAR" }) end end
        return out
    end
    local bagPanel = UIStyle.Panel(UI.menuFolder, { Name = "RunBagMenu", Size = UDim2.fromOffset(560, 500), Accent = Color3.fromRGB(230, 170, 50) })
    bagPanel:SetAttribute("PhoneMinH", 300) -- (phones: as tall as the screen; its list scrolls)
    UIStyle.TitleBar(bagPanel, "RUN BAG", Color3.fromRGB(210, 150, 40), "found this run. Finish the run or extract to keep it", function() CloseAllMenus() end)
    local bagList = Instance.new("ScrollingFrame")
    bagList.BackgroundTransparency = 1
    bagList.BorderSizePixel = 0
    bagList.Position = UDim2.fromOffset(20, 80)
    bagList.Size = UDim2.new(1, -40, 1, -100)
    bagList.ScrollBarThickness = 8
    bagList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    bagList.CanvasSize = UDim2.new()
    bagList.Parent = bagPanel
    local bl = Instance.new("UIListLayout"); bl.Padding = UDim.new(0, 8); bl.SortOrder = Enum.SortOrder.LayoutOrder; bl.Parent = bagList
    local function RenderBag()
        for _, c in ipairs(bagList:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        local items = RunItems()
        if #items == 0 then
            Label(bagList, { Size = UDim2.new(1, -12, 0, 60), Text = "Nothing found yet: loot drops here as you pick it up.", TextSize = 16, TextWrapped = true,
                TextColor3 = Color3.fromRGB(180, 186, 200) })
            return
        end
        for i, e in ipairs(items) do
            local it = e.Item
            local rarity = it.Rarity or "Common"
            local col = ItemData.RarityColors[rarity] or Color3.new(1, 1, 1)
            local row = Instance.new("Frame")
            row.LayoutOrder = i
            row.Size = UDim2.new(1, -12, 0, 52)
            row.BackgroundColor3 = Color3.fromRGB(28, 31, 44)
            row.Parent = bagList
            -- hover: the full stat card (same tooltip as the stash)
            if e.Kind ~= "GEM" and UI.HookItemTooltip then UI.HookItemTooltip(row, it, e.Kind == "GEAR") end
            Corner(row, 10)
            Stroke(row, 2, col:Lerp(Color3.new(0, 0, 0), 0.3))
            Label(row, { Position = UDim2.fromOffset(14, 5), Size = UDim2.new(1, -28, 0, 24), Text = tostring(it.Name or it.BaseId or "Item"), TextSize = 18,
                TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = col, TextTruncate = Enum.TextTruncate.AtEnd })
            Label(row, { Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 18), Text = string.upper(rarity) .. "  " .. e.Kind,
                TextSize = 13, Font = UIStyle.BodyFont or Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(170, 176, 196) })
        end
    end
    UI.ToggleRunBag = function()
        if bagPanel.Visible then CloseAllMenus() return end
        RenderBag()
        OpenMenuFrame(bagPanel)
    end
    -- the bag button: right side of the screen, only during a run, with a count of what's inside
    -- (owner 2026-10-03: "we need a better Bag icon... it currently looks disgusting") -- built like a dock tile: dark
    -- glass, a gold line icon, a soft wash, a small count badge and a label pill underneath
    local BAG_ACC = Color3.fromRGB(255, 196, 80)
    local bagBtn = Instance.new("TextButton")
    bagBtn.Name = "RunBag"
    bagBtn.AnchorPoint = Vector2.new(1, 0.5)
    bagBtn.Position = UDim2.new(1, -24, 0.55, 0)
    bagBtn.Size = UDim2.fromOffset(66, 66)
    bagBtn.Text = ""
    bagBtn.AutoButtonColor = false
    bagBtn.BackgroundColor3 = DOCK_BG
    bagBtn.BackgroundTransparency = 0.12
    bagBtn.Visible = false
    bagBtn:SetAttribute("NoSkin", true)
    bagBtn.Parent = hudGui
    Corner(bagBtn, 18)
    local bagStroke = Instance.new("UIStroke"); bagStroke.Thickness = 2; bagStroke.Color = BAG_ACC; bagStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; bagStroke.Parent = bagBtn
    local bagWash = Instance.new("Frame"); bagWash.BorderSizePixel = 0; bagWash.Size = UDim2.fromScale(1, 1); bagWash.BackgroundColor3 = BAG_ACC
    bagWash.BackgroundTransparency = 0.78; bagWash.Parent = bagBtn; Corner(bagWash, 18)
    local bwg = Instance.new("UIGradient"); bwg.Rotation = 90; bwg.Transparency = NumberSequence.new(0, 1); bwg.Parent = bagWash
    -- (the backpack icon: the stash tile is hidden during a run, so they never show together)
    local bagIcon = UIStyle.Icon("stash", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(34, 34),
        ImageColor3 = BAG_ACC, BackgroundTransparency = 1, ZIndex = 2, Parent = bagBtn })
    local bagCount = Instance.new("TextLabel")
    bagCount.AnchorPoint = Vector2.new(0.5, 0.5)
    bagCount.Position = UDim2.new(1, -6, 0, 6)
    bagCount.Size = UDim2.fromOffset(24, 20)
    bagCount.BackgroundColor3 = BAG_ACC
    bagCount.TextColor3 = DOCK_BG
    bagCount.Font = Enum.Font.GothamBlack
    bagCount.TextSize = 13
    bagCount.ZIndex = 3
    bagCount.Parent = bagBtn
    Corner(bagCount, 10)
    local bagKey = Instance.new("TextLabel")
    bagKey.AnchorPoint = Vector2.new(0.5, 0)
    bagKey.Position = UDim2.new(0.5, 0, 1, 4)
    bagKey.Size = UDim2.fromOffset(86, 20)
    bagKey.BackgroundColor3 = DOCK_BG
    bagKey.BackgroundTransparency = 0.12
    bagKey.TextColor3 = Color3.new(1, 1, 1)
    bagKey.Font = Enum.Font.GothamBlack
    bagKey.TextSize = 12
    bagKey.Parent = bagBtn
    Corner(bagKey, 10)
    local bks = Instance.new("UIStroke"); bks.Thickness = 1.5; bks.Color = BAG_ACC:Lerp(Color3.new(0, 0, 0), 0.2); bks.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; bks.Parent = bagKey
    local bsc = Instance.new("UIScale"); bsc.Parent = bagBtn
    bagBtn.MouseEnter:Connect(function() bsc.Scale = 1.06; bagStroke.Color = Color3.new(1, 1, 1); bagIcon.ImageColor3 = Color3.new(1, 1, 1) end)
    bagBtn.MouseLeave:Connect(function() bsc.Scale = 1; bagStroke.Color = BAG_ACC; bagIcon.ImageColor3 = BAG_ACC end)
    bagBtn.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); UI.ToggleRunBag() end)
    local dockStash, dockTele = dock:FindFirstChild("STASH"), dock:FindFirstChild("TELEPORT")
    local dockCos, dockShop = dock:FindFirstChild("COSMETICS"), dock:FindFirstChild("STORE")
    -- MAIN MENU (owner 2026-10-20: "turn them into a menu that opens up a big menu of all of the buttons that are currently
    -- on the side, so that way players dont need to hover over each one"): the dock column is hidden on EVERY device now
    -- (it still holds the tiles: their actions + the run / lost-loot visibility). ONE MENU button sits where it started
    -- (key Menu, default L) and opens the MENU window: each visible tile as a big card with its icon, name, key and one
    -- line on what it does. A real window (menuFolder), so Esc / X / the key again close it, the cursor frees and phones
    -- fit it like any window. (Grew out of the touch-only MENU card of 2026-10-13: owner, the side buttons "are a bit
    -- annoying on mobile, maybe turn it into one smaller button that opens a big menu".)
    ;(function()
        -- (UI v4 NEON 2026-10-21: quiet dark cards with hairlines; the neon -- a halo, the edge, the icon -- only lights
        -- on the card under the pointer / gamepad selection. LOST LOOT keeps its red.)
        local UC = UIStyle.Colors
        local GOLD = UC.Neon
        local INFO = {
            INVENTORY = "Your stash: equip guns, gear and gems.",
            ["SKILL TREE"] = "Spend passive points and pick your specialization.",
            COSMETICS = "Equip the skins, gloves and effects you own.",
            STORE = "Skins, bundles and BOUND points.",
            TELEPORT = "Jump to any station in the city.",
            TRADE = "Swap items and skins with a player here.",
            HIDEOUT = "Go home, decorate, or visit a friend's.",
            DUEL = "Challenge a player to a 1v1.",
            TITLES = "Pick the title shown under your name.",
            SETTINGS = "Controls, sensitivity, video and sound.",
            SPECTATE = "Watch someone's run through their eyes.",
            ["LOST LOOT"] = "Buy back Mythic and Relic drops you left behind.",
            CREW = "Your crew: members, bank and research.",
            ["PARTY FINDER"] = "Join an open party in any server.",
            ["INVITE FRIENDS"] = "Invite a friend: you both get 50 BOUND points.",
            PROFILES = "Your aim stats, and anyone's gear and build.",
            MODS = "Socket mods into your gun: they change what its shot does.",
            ["HOW IT WORKS"] = "Attributes, the tree, sockets, mods, damage types, defences and class builds.",
            DUNGEONS = "Start a run or open a party room, from anywhere in the city.", FORGE = "Upgrade and craft your guns and gear (city or hideout).", -- (QOL F2 / F3)
            EXCHANGE = "Buy and sell with every player, even offline. Collect your sales here.", -- (QOL2 H3)
        }
        local tg = Instance.new("ScreenGui")
        tg.Name = "TouchMenu"; tg.ResetOnSpawn = false; tg.IgnoreGuiInset = true; tg.DisplayOrder = 25
        tg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        tg.Parent = LocalPlayer:WaitForChild("PlayerGui")
        local function Txt(parent, text, size, color, props)
            local l = Instance.new("TextLabel")
            l.BackgroundTransparency = 1; l.Text = text; l.TextSize = size; l.TextColor3 = color; l.Font = Enum.Font.GothamBlack
            for k, v in pairs(props or {}) do l[k] = v end
            l.Parent = parent
            return l
        end
        -- the button: three gold bars + MENU, its key on a cap at the corner (keyboards), a red dot while LOST LOOT has items
        local btn = Instance.new("TextButton")
        btn.Name = "MenuButton"; btn.Text = ""; btn.AutoButtonColor = false; btn.Size = UDim2.fromOffset(54, 54); btn.Visible = false
        -- (UI CLEAN R-C: the run HUD plate -- flat, square, no facet / hairline box / glow; hover = the plate one step more solid)
        btn.BackgroundColor3 = UC.Bg0; btn.BackgroundTransparency = UI.RunHud.PLATE_T; btn.BorderSizePixel = 0; btn:SetAttribute("NoSkin", true)
        btn.Parent = tg
        UI.MenuButton = btn -- (UI CLEAN P5: the goal tracker hangs under it on the screen grid)
        local bsc = Instance.new("UIScale"); bsc.Parent = btn
        local bars = {}
        for i = 0, 2 do
            local bar = Instance.new("Frame")
            bar.BorderSizePixel = 0; bar.BackgroundColor3 = UC.Text; bar.AnchorPoint = Vector2.new(0.5, 0.5)
            bar.Position = UDim2.new(0.5, 0, 0, 14 + i * 7); bar.Size = UDim2.fromOffset(i == 1 and 18 or 24, 2); bar.Parent = btn
            bars[i + 1] = bar
        end
        local menuLbl = Txt(btn, "MENU", 12, UC.Sub, { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -18) })
        UI.RunHud.Role(menuLbl, "Label"); menuLbl.FontFace = UIStyle.RoleFace("Label"); menuLbl.TextSize = 12
        -- the key: plain Meta text beside the button (no boxed cap)
        local keyCap = Txt(btn, "", 13, UC.Sub, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 6, 0.5, 0), Size = UDim2.fromOffset(0, 20),
            AutomaticSize = Enum.AutomaticSize.X, ZIndex = 2, TextStrokeTransparency = 0.6 })
        keyCap.FontFace = UIStyle.RoleFace("Label")
        local dot = Instance.new("Frame")
        dot.Name = "LostDot"; dot.BorderSizePixel = 0; dot.BackgroundColor3 = Color3.fromRGB(225, 55, 55); dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Position = UDim2.new(1, -6, 0, 6); dot.Size = UDim2.fromOffset(8, 8); dot.ZIndex = 3; dot.Visible = false; dot.Parent = btn
        local function BtnLit(on)
            btn.BackgroundTransparency = on and 0.12 or UI.RunHud.PLATE_T
            menuLbl.TextColor3 = on and UC.Text or UC.Sub
        end
        btn.MouseEnter:Connect(function() BtnLit(true) end)
        btn.MouseLeave:Connect(function() BtnLit(false) end)
        -- the window
        local panel = UIStyle.Panel(UI.menuFolder, { Name = "MainMenu", Size = UDim2.fromOffset(820, 400), Accent = GOLD })
        UIStyle.TitleBar(panel, "MENU", GOLD, "Every window in one place", function() CloseAllMenus() end)
        local grid = Instance.new("Frame")
        grid.Name = "Grid"; grid.BackgroundTransparency = 1; grid.Position = UDim2.fromOffset(24, 88); grid.Parent = panel
        local CW, CH, CG = 248, 84, 12
        local gl = Instance.new("UIGridLayout")
        gl.CellSize = UDim2.fromOffset(CW, CH); gl.CellPadding = UDim2.fromOffset(CG, CG); gl.SortOrder = Enum.SortOrder.LayoutOrder
        gl.Parent = grid
        local function Open()
            for _, c in ipairs(grid:GetChildren()) do if c:IsA("GuiButton") then c:Destroy() end end
            local list = {}
            for _, r in ipairs(dockTiles) do if r.Holder.Visible then table.insert(list, r) end end
            -- (UI CLEAN audit, owner: "make sure all menus make sense": the cards in groups -- play, build, trade, look, people, help)
            local RANK = { DUNGEONS = 1, ["PARTY FINDER"] = 2, DUEL = 3, TELEPORT = 4, INVENTORY = 5, ["SKILL TREE"] = 6, MODS = 7, FORGE = 8,
                EXCHANGE = 9, TRADE = 10, ["LOST LOOT"] = 11, ["LAST RUN"] = 12, COSMETICS = 13, STORE = 14, TITLES = 15, HIDEOUT = 16,
                PROFILES = 17, CREW = 18, ["INVITE FRIENDS"] = 19, SPECTATE = 20, ["HOW IT WORKS"] = 21, SETTINGS = 22 }
            table.sort(list, function(a, b) return (RANK[a.Name] or 100 + a.Holder.LayoutOrder) < (RANK[b.Name] or 100 + b.Holder.LayoutOrder) end)
            local touch = GameSettings.TouchOnly()
            for i, r in ipairs(list) do
                local hot = r.Col and not UIStyle.IsPrimary(r.Col) and r.Col or nil -- (LOST LOOT keeps its red)
                local acc = hot or GOLD
                local b = Instance.new("TextButton")
                b.Name = r.Name; b.Text = ""; b.AutoButtonColor = false; b.LayoutOrder = i
                -- (UI CLEAN R-C: the target's card -- the raised surface (Text at ~4.5%), no facet / stroke / glow / grow; hover or pad
                -- selection = one step brighter + a 2 px line along the bottom (in the tile's own hue for LOST LOOT))
                b.BackgroundColor3 = UC.Text; b.BackgroundTransparency = 0.955; b.BorderSizePixel = 0; b:SetAttribute("NoSkin", true)
                local mark = Instance.new("Frame"); mark.Name = "Mark"; mark.BorderSizePixel = 0; mark.BackgroundColor3 = acc; mark.AnchorPoint = Vector2.new(0, 1)
                mark.Position = UDim2.fromScale(0, 1); mark.Size = UDim2.new(1, 0, 0, 2); mark.Visible = hot ~= nil; mark.Parent = b
                b.Parent = grid
                if r.Name == "EXCHANGE" and UI.ExchangeDot then UI.ExchangeDot(b) end -- (QOL2 H3: sold listings waiting)
                local iconCol = hot or UC.Sub
                local icon
                if UIStyle.HasIcon(r.IconKey) then
                    icon = UIStyle.Icon(r.IconKey, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), Size = UDim2.fromOffset(34, 34),
                        ImageColor3 = iconCol, Parent = b })
                else
                    icon = Txt(b, r.IconKey or "?", 28, iconCol, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), Size = UDim2.fromOffset(34, 34) })
                end
                local key = (r.Action and not touch) and string.upper(GameSettings.KeyLabel(GameSettings.BindName(r.Action))) or nil
                local nm = Txt(b, r.Name, 17, UC.Text, { Position = UDim2.fromOffset(66, 14), Size = UDim2.new(1, key and -124 or -80, 0, 20),
                    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
                UI.RunHud.Role(nm, "ItemName"); nm.TextSize = 17
                local cap
                if key then
                    -- (the key shows on hover only: owner rule "key hints on hover, not always")
                    cap = UIStyle.KeyCap(b, key, { Color = UC.Sub, Height = 20, Position = UDim2.new(1, -12, 0, 14) })
                    cap.AnchorPoint = Vector2.new(1, 0)
                    cap.Visible = false
                end
                local info = Txt(b, INFO[r.Name] or "", 13, UC.Sub, { TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(66, 38), Size = UDim2.new(1, -80, 0, 40) })
                UI.RunHud.Role(info, "Label"); info.TextSize = 13
                local tw = UIStyle.Motion.Tween
                local function Lit(on)
                    b.BackgroundTransparency = on and 0.91 or 0.955
                    mark.Visible = on or hot ~= nil
                    if icon:IsA("ImageLabel") then tw(icon, 0.12, { ImageColor3 = on and (hot or UC.Text) or iconCol }) else icon.TextColor3 = on and (hot or UC.Text) or iconCol end
                    if cap then cap.Visible = on end
                end
                b.MouseEnter:Connect(function() Lit(true) end)
                b.MouseLeave:Connect(function() Lit(false) end)
                b.SelectionGained:Connect(function() Lit(true) end)
                b.SelectionLost:Connect(function() Lit(false) end)
                b.MouseButton1Down:Connect(function() b.BackgroundTransparency = 0.94 end) -- (pressed: a touch darker, no shrink)
                b.MouseButton1Click:Connect(function()
                    SoundHelper.Play("Click")
                    CloseAllMenus()
                    pcall(r.Click)
                end)
            end
            local n = math.max(1, #list)
            local cols = math.min(n, n > 9 and 4 or 3)
            local rows = math.ceil(n / cols)
            gl.FillDirectionMaxCells = cols
            local gw, gh = cols * CW + (cols - 1) * CG, rows * CH + (rows - 1) * CG
            grid.Size = UDim2.fromOffset(gw, gh)
            panel.Size = UDim2.fromOffset(math.max(gw + 48, 420), gh + 88 + 24)
            if not panel.Visible then OpenMenuFrame(panel) end
        end
        UI.ToggleMainMenu = function() if panel.Visible then CloseAllMenus() else Open() end end
        btn.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); UI.ToggleMainMenu() end)
        UI.TouchMenuOpen = Open -- (Studio test hook: DevAct "touchmenu")
        UI.TouchMenuSync = function()
            local touch = GameSettings.TouchOnly() or UIStyle.IsPhone()
            if dock.Visible then dock.Visible = false end
            local show = not UI.watching and not isAnyMenuOpen and hudGui.Enabled
            btn.Visible = show
            dot.Visible = lostTile.Visible or (UI.ExchangeSoldOn ~= nil and UI.ExchangeSoldOn()) -- (QOL2 H3: + Exchange sales, green)
            dot.BackgroundColor3 = lostTile.Visible and Color3.fromRGB(225, 55, 55) or Color3.fromRGB(110, 230, 150)
            if show then
                local hs = hudGui:FindFirstChildOfClass("UIScale")
                local kk = hs and hs.Scale or 1
                btn.Position = UDim2.fromOffset(UIStyle.MARGIN * kk, dock.Position.Y.Offset * kk) -- (UI CLEAN P5: the screen grid)
                bsc.Scale = touch and (48 * UIStyle.SimK() / 54) or kk
                -- (UI CLEAN R-C fix: the key lives INSIDE the button under the bars ("MENU  L"), not as a stray letter beside it)
                keyCap.Visible = false
                local mt = touch and "MENU" or ("MENU  " .. string.upper(GameSettings.KeyLabel(GameSettings.BindName("Menu"))))
                if menuLbl.Text ~= mt then menuLbl.Text = mt end
            end
        end
    end)()
    local RUN_HIDDEN_TILES = { "TELEPORT", "TRADE", "HIDEOUT", "DUEL", "TITLES", "SPECTATE", "CREW", "PARTY FINDER", "INVITE FRIENDS", "DUNGEONS", "FORGE", "EXCHANGE" } -- (QOL F2 / F3: + DUNGEONS, FORGE; QOL2 H3: + EXCHANGE)
    -- (2026-10-13: this ran on every Heartbeat; now 4 times a second + right away on a run start / end, a resize or a
    -- phone preview -- nothing in it needs frame accuracy)
    local function DockTick()
        local inRun = UI.InRunLocked()
        local items = RunItems()
        bagBtn.Visible = false -- (owner 2026-10-04: the run bag is gone -- loot is yours the moment you pick it up)
        if inRun then
            bagCount.Text = tostring(#items)
            bagCount.Visible = #items > 0
            bagKey.Text = GameSettings.TouchOnly() and "RUN BAG" or ("RUN BAG  " .. string.upper(GameSettings.KeyLabel(GameSettings.BindName("Inventory"))))
            if bagPanel.Visible and bagPanel:GetAttribute("Count") ~= #items then bagPanel:SetAttribute("Count", #items); RenderBag() end
        end
        -- in a run only Settings stays on the dock (and the bag on the right)
        if dockStash then dockStash.Visible = true end -- (the stash works in a run again: equip what you find)
        -- (0.97, owner: "When in any sort of dungeon / map / boss etc. you should only be able to open the cosmetics menu
        -- (store), inventory, and skill tree") -- Settings stays too (sensitivity / keybinds mid-run)
        if dockCos then dockCos.Visible = true end
        if dockShop then dockShop.Visible = true end
        for _, nm in ipairs(RUN_HIDDEN_TILES) do
            local t = dock:FindFirstChild(nm)
            if t then t.Visible = not inRun end
        end
        -- (2026-10-22 first-hour pass, Loot Economy Plan section 6 "before the unlock level the system is hidden entirely"):
        -- CREW waits for its level (GuildService refuses below it; the LEVEL 20 unlock card introduces it)
        local crewT = dock:FindFirstChild("CREW")
        if crewT and crewT.Visible and (clientState.Level or 1) < require(game.ReplicatedStorage.AimRngShared.Guilds).UNLOCK then crewT.Visible = false end
        lostTile.Visible = (not inRun) and #(clientState.LostLoot or {}) > 0 -- LOST LOOT: only when there's something to buy back
        do local lr = dock:FindFirstChild("LAST RUN"); if lr then lr.Visible = (not inRun) and UI.lastRunRows ~= nil end end -- (QOL2 R2)
        -- fit the visible tiles between the guide buttons and the bottom-left HUD
        do
            local vis = 0
            for _, c in ipairs(dock:GetChildren()) do if c:IsA("Frame") and c.Visible then vis += 1 end end
            -- (owner 2026-10-03: "the loot buy back button is hidden under the side UI") measure the real top of the
            -- level / health card instead of guessing a 140 px margin -- with 7 tiles the last one slid under it
            local cam = workspace.CurrentCamera
            -- (2026-10-13 phones: the hub's GUIDE / PATCH NOTES / CREDITS row moved below the Roblox top bar -- the dock
            -- starts under that row; 142 everywhere else)
            local dockY = UIStyle.BelowTopBarY(dock, 72) + 70
            if dock.Position.Y.Offset ~= dockY then dock.Position = UDim2.new(0, 16, 0, dockY) end
            local lvl = hudGui:FindFirstChild("LevelHUD")
            local bottom = (lvl and lvl.Visible and lvl.AbsoluteSize.Y > 0) and (lvl.AbsolutePosition.Y - 14) or ((cam and cam.ViewportSize.Y or 900) - 170)
            local avail = bottom - dock.AbsolutePosition.Y
            -- (0.89 phones: 10 tiles at 0.5x still ran under the level card) below 0.7x one column wraps into two
            local k = hudGui:FindFirstChildOfClass("UIScale")
            local kk = k and k.Scale or 1
            local s1 = avail / math.max(1, (vis * (TILE + GAP) - GAP) * kk)
            local cols, s = 1, math.clamp(s1, 0.5, 1)
            if s1 < 0.86 then -- (Update 5: two columns of full-size tiles beat one column of small ones)
                cols = 2
                s = math.clamp(avail / math.max(1, (math.ceil(vis / 2) * (TILE + GAP) - GAP) * kk), 0.5, 1)
            end
            if UIStyle.IsPhone() then
                -- (2026-10-13 phones: tiles ~44 pt -- a finger's size -- in up to 3 columns; the HUD's 0.55 made them ~30 pt)
                local kp = kk / UIStyle.SimK()
                local sp = math.max(1, 44 / (TILE * math.max(kp, 0.1)))
                local availD = avail / math.max(kk, 0.01)
                local rows = math.max(1, math.floor((availD + GAP) / ((TILE + GAP) * sp)))
                cols, s = math.min(3, math.ceil(vis / rows)), sp
                if math.ceil(vis / cols) > rows then -- (not even 3 columns fit at 44 pt: shrink to fit)
                    cols = 3
                    s = math.clamp(availD / math.max(1, math.ceil(vis / 3) * (TILE + GAP) - GAP), 0.5, sp)
                end
            end
            UI.dockScale.Scale = s
            dl.Wraps = cols > 1
            dock.Size = UDim2.fromOffset(cols * TILE + (cols - 1) * GAP, cols > 1 and math.ceil(vis / cols) * (TILE + GAP) or 9 * (TILE + GAP))
            -- (0.89) on a phone a window covers the screen: every open window draws over the HUD (layers 1-5) and under
            -- popups / loot cards / tooltips (30+); its own layer comes back off the phone
            local phone = UIStyle.IsPhone()
            for _, w in ipairs(UI.menuFolder:GetChildren()) do
                if w:IsA("GuiObject") and not w:GetAttribute("MenuFieldFor") then -- (UI CLEAN R-B: a menu's field stays one layer under its window)
                    local z0 = w:GetAttribute("Z0")
                    if phone and w.ZIndex < 12 then w:SetAttribute("Z0", w.ZIndex); w.ZIndex = 12
                    elseif not phone and z0 then w.ZIndex = z0; w:SetAttribute("Z0", nil) end
                end
            end
        end
        if UI.TouchMenuSync then UI.TouchMenuSync() end
        if not inRun and bagPanel.Visible then CloseAllMenus() end
        if lostPanel.Visible and lostPanel:GetAttribute("Count") ~= #(clientState.LostLoot or {}) then
            lostPanel:SetAttribute("Count", #(clientState.LostLoot or {}))
            RenderLost()
        end
    end
    local function Tick() local ok, err = pcall(DockTick) if not ok then warn("[Dock] " .. tostring(err)) end end
    task.spawn(function() while true do Tick(); task.wait(0.25) end end)
    for _, a in ipairs({ "RunId", "Lives", "DevPhone" }) do LocalPlayer:GetAttributeChangedSignal(a):Connect(function() task.defer(Tick) end) end
    if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() task.defer(Tick) end) end
    UI.menuFolder.ChildAdded:Connect(function() task.defer(Tick) end)
end)()

-- NEON TAMER (0.93, owner: "too neon ... All of it bothers me, including on skins"): one pass over everything drawn
-- (AimRngShared/NeonTamer); Settings > Video > Neon Glow switches it off
;(function()
    local NT = require(sharedFolder:WaitForChild("NeonTamer"))
    NT.Start(GameSettings.Get("NeonGlow") ~= "Full")
    local first = true
    GameSettings.OnChanged("NeonGlow", function(v)
        if first then first = false; return end -- (OnChanged calls once right away with the current value)
        NT.SetEnabled(v ~= "Full")
    end)
end)()

-- Keybinds (rebindable in Settings > Controls; GameSettings maps the pressed key to an action)
UserInputService.InputBegan:Connect(function(input, _)
    if GameSettings.IsTyping() then return end -- (chat bar included: hotkeys used to open menus mid-sentence)
    if SettingsMenu.IsCapturingKey() then return end -- the Controls tab is taking this key press
    local action = GameSettings.ActionForInput(input) -- (keys and mouse buttons)
    -- (0.84: spectating -- nothing to interact with; double-tap ExitRun still stops it, Settings still opens)
    if UI.watching and action ~= "ExitRun" and action ~= "Settings" then return end

    local lootCard = hudGui:FindFirstChild("GroundLootCard")
    if UI.betterWeaponBanner.Visible and action == "Interact" and not (lootCard and lootCard.Visible) then -- near a drop, the key picks it up instead
        EquipPendingWeapon()
        return
    elseif UI.betterWeaponBanner.Visible and action == "Dismiss" then
        UI.betterWeaponBanner.Visible = false
        pendingBetterWeapon = nil
        return
    end

    if action == "ExitRun" and UI.victoryBanner.Visible then
        ReturnFromVictory() -- run's over: no confirm step needed
        return
    end
    if action == "ExitRun" then
        UI.ExitAnywhere(CloseAllMenus) -- (0.80: double tap = back to the hub from ANY mode)
        return
    end
    -- (0.93, owner: "in a run, only have stash and skill tree keybinds"): every other menu key is off in a run
    -- (Settings still opens from the dock tile)
    local RUN_MENU_OK = { Inventory = true, Tree = true, Cosmetics = true, Store = true } -- (0.97: + the cosmetics window)
    local MENU_KEYS = { Teleport = true, Trade = true, Duel = true, Hideout = true, Cosmetics = true, Store = true, Settings = true,
        Forge = true, Shop = true, Upgrade = true, Armory = true, Arena = true, Index = true, Challenges = true }
    if MENU_KEYS[action] and not RUN_MENU_OK[action] and UI.InRunLocked and UI.InRunLocked() then return end
    if action == "Menu" then -- (2026-10-20: the MENU window, every side tile in one place; it lists only what a run allows)
        if UI.ToggleMainMenu then UI.ToggleMainMenu() end
        return
    end

    if action == "Teleport" then
        if UI.ToggleTeleportMenu then UI.ToggleTeleportMenu() end
        return
    end
    if action == "Trade" then -- (0.55: TradeMenu; same key again closes it)
        if UI.trade and UI.trade.Panel.Visible then CloseAllMenus()
        elseif UI.trade and not LocalPlayer:GetAttribute("RunId") then UI.trade.Open() end
        return
    end
    if action == "Ability" then -- (2026-10-15: the duel ability; nothing outside a duel)
        if UI.duel and UI.duel.UseAbility then UI.duel.UseAbility() end
        return
    end
    if action == "Duel" then -- (0.59: PvpClient; same key again closes it)
        if UI.duel and UI.duel.Panel.Visible then CloseAllMenus()
        elseif UI.duel and not LocalPlayer:GetAttribute("RunId") then UI.duel.Open() end
        return
    end
    if action == "Hideout" then -- (0.55: Hideouts)
        if UI.ToggleHideoutMenu then UI.ToggleHideoutMenu() end
        return
    end
    if action == "Dungeons" or action == "ForgeWin" then -- (QOL F2 / F3: Key_Dungeons O / Key_Forge I -> UI.HubWindow)
        if UI.HubWindow then UI.HubWindow(action == "Dungeons" and "Dungeons" or "Forge") end
        return
    end
    if action == "Cosmetics" or action == "Store" then -- (hub only, like their dock tiles)
        local want = (action == "Store") and "Shop" or "Locker"
        local open = UI.cosmetics and UI.cosmetics.Frame.Visible and select(2, UI.cosmetics.Selected()) == want
        if open then CloseAllMenus() -- (same key again closes it)
        elseif UI.OpenCosmetics then UI.OpenCosmetics(want) end
        return
    end

    local weaponAction = action == "Reload" or action == "Melee" or action == "SlotGun" or action == "SlotMelee" or action == "SwapWeapon"
    if weaponAction and LocalPlayer:GetAttribute("ThirdPerson") then return end -- the third-person hub: no weapons out
    if (action == "Melee" or action == "SlotMelee" or action == "SwapWeapon") and LocalPlayer:GetAttribute("PvpDuel") then return end -- (0.60: no knife in duels)
    -- (owner 2026-10-03: "If I click 3 to select boon 3, it shouldnt swap to my melee weapon")
    if (action == "SlotGun" or action == "SlotMelee") and UI.boonPanel and UI.boonPanel.Visible then return end

    if action == "Reload" then
        if activeSlot == "Gun" then
            if UI.CancelQuickMelee then UI.CancelQuickMelee() end
            StartReload()
        end
    elseif action == "Melee" then
        if activeSlot == "Melee" then MeleeAttack("Light") elseif not QuickMeleeSwing() then TriggerQuickMelee() end
    elseif action == "SlotGun" then
        SetSlot("Gun")
    elseif action == "SlotMelee" then
        SetSlot("Melee")
    elseif action == "SwapWeapon" then
        SetSlot(activeSlot == "Gun" and "Melee" or "Gun")
    elseif action == "Forge" then
        UI.rGoldBal.Text = ((clientState.LastDailyRoll or 0) >= os.time() // 86400) and "Today's free roll is used. Come back tomorrow." or "Your free roll for today is ready: a gun + a guaranteed Prism Shard stack!"
        OpenMenuFrame(UI.rollFrame)
    elseif action == "Tree" then -- (0.93: Key_Tree, default P)
        if UI.treeFrame.Visible then CloseAllMenus() else OpenMenuFrame(UI.treeFrame); RefreshTree() end
    elseif action == "Inventory" then
        OpenMenuFrame(UI.invFrame); RefreshInventory()
    elseif action == "Shop" then
        OpenMenuFrame(UI.shopFrame); RefreshShopMenu()
    elseif action == "Upgrade" then
        RefreshUpgradeMenu(); OpenMenuFrame(UI.upgFrame)
    elseif action == "Armory" then
        OpenMenuFrame(UI.armoryFrame); RefreshArmoryMenu()
    elseif action == "Arena" then
        OpenMenuFrame(UI.dungFrame)
    elseif action == "Index" then
        OpenMenuFrame(UI.indexFrame); RenderIndexContent()
    elseif action == "Challenges" then
        if not (UI.TrialRunner and UI.TrialRunner.IsRunning()) then OpenMenuFrame(UI.challFrame) end
    elseif action == "Settings" then
        OpenMenuFrame(UI.setFrame)
    elseif action == "Inspect" then
        if realRig and not isReloading and not LocalPlayer:GetAttribute("ThirdPerson") then realRig:Play("Inspect") end -- (fixes #11: first person only)
    elseif action == "FreeCursor" then
        -- HOLD to free the cursor (owner: "tabbing out sometimes messes with the cursor" + "sometimes can't dash in
        -- spawn": it was a TOGGLE on Left Alt, so Alt+Tab switched it on -- you came back with a cursor on screen and
        -- movement paused, dash included)
        if not isCursorUnlocked then UI.freeCursorHeld = true; SetMouseLocked(false) end
    elseif input.KeyCode == Enum.KeyCode.Y and RunService:IsStudio() and realRig and clientState.EquippedWeapon then
        -- Studio only: flip between viewmodel size presets on the equipped real-mesh gun, to compare them
        local WeaponRigs = require(sharedFolder:WaitForChild("WeaponRigs"))
        local def = WeaponRigs.Guns[clientState.EquippedWeapon.BaseId]
        if def then
            def.BaseHold = def.BaseHold or def.Hold.Position
            def.BaseScale = def.BaseScale or (def.Scale or 1)
            local presets = {
                { "1/4 Current", 1, 1 }, { "2/4 Closer (15%)", 0.85, 1 },
                { "3/4 Bigger gun (+12%)", 1, 1.12 }, { "4/4 Closer + bigger gun", 0.85, 1.12 },
            }
            vmSizePreset = vmSizePreset % #presets + 1
            local p = presets[vmSizePreset]
            def.Hold.Position = def.BaseHold * p[2]
            def.Scale = def.BaseScale * p[3]
            RebuildViewmodelForWeapon(clientState.EquippedWeapon)
            ShowToast("Viewmodel size: " .. p[1] .. "  (Y for next)")
        end
    elseif input.KeyCode == Enum.KeyCode.F8 and RunService:IsStudio() then
        -- Studio play-tests only (DevCommands): F8 = next new-lineup gun, Shift+F8 = next prefix on it
        local dev = game.ReplicatedStorage:FindFirstChild("AimRngDevRemote")
        local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
        if dev then dev:FireServer(shift and "TestGun" or "NextGun") end
    elseif input.KeyCode == Enum.KeyCode.Escape then
        CloseAllMenus()
    end
end)

-- QOL Q1 (2026-10-28): controller menus -- AimRngShared/PadMenus (first selection on open, selection dropped on close, the
-- accent highlight); B already closes (PlatformControls Back). The inventory starts on the first bag row, Dungeons on START.
;(function()
    local ok, PM = pcall(require, sharedFolder:WaitForChild("PadMenus"))
    if not ok then warn("[PadMenus] " .. tostring(PM)); return end
    PM.Init({ IsMenuOpen = function() return isAnyMenuOpen end, OpenFrame = function() return UI.openFrame end, Accent = UIStyle.Colors.Accent })
    UI.PadMenus = PM
    if UI.invFrame then
        PM.SetFirst(UI.invFrame, function(f)
            local best, by = nil, math.huge
            for _, d in ipairs(f:GetDescendants()) do
                if d:IsA("TextButton") and d.Parent and d.Parent:IsA("ScrollingFrame") and d.Visible and d.AbsoluteSize.Y >= 30 and d.AbsoluteSize.Y <= 120 -- (UI CLEAN INV: bag tiles too)
                    and d.AbsolutePosition.Y < by then best, by = d, d.AbsolutePosition.Y end
            end
            return best
        end)
    end
    if UI.dungFrame then PM.SetFirst(UI.dungFrame, function(f) return f:FindFirstChild("Go", true) end) end -- (Dungeons: START)
end)()

-- ==================== PHONES / TABLETS / GAMEPADS (PlatformControls) ====================
-- touch buttons + drag to look, gamepad triggers + right stick; they drive the same actions as mouse + keyboard
;(function()
    local PlatformControls = require(sharedFolder:WaitForChild("PlatformControls"))
    UI.PlatformControls = PlatformControls
    local Movement = require(sharedFolder:WaitForChild("MovementController"))
    local function Alive()
        local c = LocalPlayer.Character
        local hm = c and c:FindFirstChildOfClass("Humanoid")
        return hm ~= nil and hm.Health > 0
    end
    PlatformControls.Start({
        Mode = function()
            if isAnyMenuOpen then return "Menu" end
            if not Alive() or LocalPlayer:GetAttribute("Downed") then return "Off" end
            if LocalPlayer:GetAttribute("ThirdPerson") then return "Hub" end
            return "Play"
        end,
        Look = function(d) camPendingDelta += d end,
        Orbit = function(d)
            local HubCamera = require(sharedFolder:WaitForChild("HubCamera"))
            HubCamera.PendingPad += d
        end,
        Fire = function(down)
            isMouseDown = down
            if down and not isAnyMenuOpen and not LocalPlayer:GetAttribute("ThirdPerson") then
                if activeSlot == "Melee" then MeleeAttack("Light") else FireWeapon() end
            end
        end,
        Aim = function(down)
            if activeSlot == "Melee" then
                if down then MeleeAttack("Heavy") end
                return
            end
            isAiming = down
        end,
        Reload = function() if activeSlot == "Gun" then StartReload() end end,
        Melee = function()
            if activeSlot == "Melee" then MeleeAttack("Light") elseif not QuickMeleeSwing() then TriggerQuickMelee() end
        end,
        Swap = function() SetSlot(activeSlot == "Gun" and "Melee" or "Gun") end,
        Inspect = function() if realRig and not isReloading and not LocalPlayer:GetAttribute("ThirdPerson") then realRig:Play("Inspect") end end,
        Move = function(name, down) if Movement.Action then Movement.Action(name, down) end end,
        Menu = function()
            if isAnyMenuOpen then CloseAllMenus() else OpenMenuFrame(UI.setFrame) end
        end,
        Back = function() CloseAllMenus() end,
        -- AIM ASSIST (2026-10-13, owner: "Mobile should have ... slight aim assist ... (only in pve)"): touch only; never
        -- in duels (PvpDuel / UI.PvpDef), Aim Trials (UI.TrialActive: scored), spectating, menus, the hub or with the melee out
        Assist = {
            Allowed = function()
                if isAnyMenuOpen or isCursorUnlocked or activeSlot ~= "Gun" or UI.TrialActive or UI.watching then return false end
                if LocalPlayer:GetAttribute("PvpDuel") or LocalPlayer:GetAttribute("ThirdPerson") or LocalPlayer:GetAttribute("Downed")
                    or LocalPlayer:GetAttribute("Spectating") then return false end
                if UI.PvpDef and UI.PvpDef() then return false end
                return GameSettings.TouchOnly() and Alive()
            end,
            Nudge = function(yaw, pitch) AddCameraKick(pitch, yaw) end,
            Exclude = function()
                local list = {}
                if viewmodel then table.insert(list, viewmodel) end
                if LocalPlayer.Character then table.insert(list, LocalPlayer.Character) end
                return list
            end,
        },
    })
end)()

-- ==================== [Mesh Tuning] Live viewmodel-rotation dev tool (v2) ====================
-- Every gun now gets its orientation automatically (WeaponMeshes' Orient, derived from the source pack).
-- This tool is only for touching up a gun that still looks off -- its readout line goes into
-- MESH_ROTATION_FIX.
--
-- v1 of this tool rebuilt CFrame.Angles(x,y,z) from an accumulated degrees triple every nudge -- which
-- meant "Up/Down" only meant pure pitch on the FIRST nudge; the moment yaw or roll was nonzero, the
-- axes started interacting (standard Euler-angle gimbal behavior) and arrows stopped doing what they
-- said. Fixed here by composing every nudge/preset as a WORLD-SPACE delta, left-multiplied onto the
-- current override (`delta * current`) instead of recomputed from scratch -- so Up/Down always means
-- "tilt relative to how you're looking at it right now," no matter what's already been applied.
--
-- Also adds 90-degree SNAP presets (most of these meshes are off by a clean 90/180, not an arbitrary
-- angle -- a snap usually gets you 90% of the way there in one keypress) and a gun CYCLER so you can
-- tune all 43 without equipping each one through actual gameplay.
--
--   [               toggle tuning mode (auto-previews a gun if none is equipped yet)
--   PageUp/PageDown  cycle to the next/previous gun archetype (preview only -- doesn't touch your real inventory)
--   Arrow Up/Down     fine pitch nudge, 5 degrees
--   Arrow Left/Right  fine yaw nudge, 5 degrees
--   ,  and  .          fine roll nudge, 5 degrees
--   1 / 2            snap pitch -90 / +90
--   3 / 4            snap yaw   -90 / +90
--   5 / 6            snap roll  -90 / +90
--   7                flip 180 (yaw) -- for a gun that's exactly backwards
--   ]                reset this gun back to its automatic orientation
--
-- The on-screen label (mid-left) always shows the exact line to send back once a gun looks right.
local tuneLabel = Instance.new("TextLabel")
tuneLabel.Name = "MeshTuneLabel"
tuneLabel.Size = UDim2.new(0, 520, 0, 150)
tuneLabel.Position = UDim2.new(0, 16, 0.5, -75) -- mid-left, clear of Roblox's top-left buttons
tuneLabel.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
tuneLabel.BackgroundTransparency = 0.15
tuneLabel.BorderSizePixel = 0
tuneLabel.Font = Enum.Font.Code
tuneLabel.TextSize = 14
tuneLabel.TextColor3 = Color3.fromRGB(0, 255, 140)
tuneLabel.TextXAlignment = Enum.TextXAlignment.Left
tuneLabel.TextYAlignment = Enum.TextYAlignment.Top
tuneLabel.TextWrapped = true
tuneLabel.Visible = false
tuneLabel.ZIndex = 50
tuneLabel.Parent = hudGui

local ALL_GUN_BASE_IDS: { string } = {}
for id in pairs(WeaponMeshes.Guns) do table.insert(ALL_GUN_BASE_IDS, id) end
table.sort(ALL_GUN_BASE_IDS)
local vmTuneCycleIndex = 1

-- Builds a minimal-but-valid WeaponInstance purely for viewmodel preview (never sent to the server,
-- never touches your real equipped weapon/inventory) so you can flip through every archetype instantly.
local function PreviewGun(baseId: string)
    local base = ItemData.BaseWeapons[baseId]
    if not base then return end
    local synthetic: any = {
        Uid = "preview", BaseId = baseId, Name = base.Name, Class = base.Class,
        Rarity = "Rare", UpgradeLevel = 0, ItemLevel = 1, HasScope = false,
    }
    RebuildViewmodelForWeapon(synthetic :: ItemData.WeaponInstance)
end

local function RefreshTunedView()
    if vmTuneActiveWeapon then
        RebuildViewmodelForWeapon(vmTuneActiveWeapon)
    end
end

local function ReportLine(): string
    if not vmTuneBaseId then return "" end
    local cf = GetMeshRotationFix(vmTuneBaseId)
    local rx, ry, rz = cf:ToOrientation()
    local line = ""
    if MeshRotationOverride[vmTuneBaseId] then
        line = string.format(
            'ROT ["%s"] = CFrame.Angles(math.rad(%.0f), math.rad(%.0f), math.rad(%.0f)),\n',
            vmTuneBaseId, math.deg(rx), math.deg(ry), math.deg(rz))
    end
    local sc, off = GetMeshFit(vmTuneBaseId)
    return line .. string.format('FIT ["%s"] = { Scale = %.2f, Offset = Vector3.new(%.2f, %.2f, %.2f) },',
        vmTuneBaseId, sc, off.X, off.Y, off.Z)
end

local function ApplyFitDelta(dScale: number, dOffset: Vector3)
    if not vmTuneBaseId then return end
    local sc, off = GetMeshFit(vmTuneBaseId)
    MeshFitOverride[vmTuneBaseId] = { Scale = math.clamp(sc * dScale, 0.4, 2.5), Offset = off + dOffset }
    RefreshTunedView()
    print("[MeshTune] " .. ReportLine())
end

local function RefreshTuneLabel()
    if not vmTuneBaseId then
        tuneLabel.Text = "[Mesh Tune] No gun to show yet, press PageDown/PageUp to preview one."
        return
    end
    tuneLabel.Text = string.format(
        "[Mesh Tune] %s  (%d/%d: PgUp/PgDn to cycle)\n%sArrows=pitch/yaw  ,.=roll  1-7=90deg snaps\n- / = size   Numpad 8/2 up/down  4/6 left/right  9/3 fwd/back\n]=reset  [=exit   Copy this back once it looks right:",
        vmTuneBaseId, vmTuneCycleIndex, #ALL_GUN_BASE_IDS, ""
    ) .. "\n" .. ReportLine()
end

-- Applies a WORLD-SPACE rotation delta on top of whatever's currently active for this gun (its saved
-- automatic orientation the first time, or the in-progress override after that) -- left-multiplied
-- so every axis keeps meaning the same thing regardless of what's already been dialed in.
local function ApplyWorldDelta(deltaCF: CFrame)
    if not vmTuneBaseId then return end
    local current = GetMeshRotationFix(vmTuneBaseId)
    MeshRotationOverride[vmTuneBaseId] = deltaCF * current
    RefreshTuneLabel()
    RefreshTunedView()
    print("[MeshTune] " .. ReportLine())
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or GameSettings.IsTyping() then return end
    if not RunService:IsStudio() then return end -- (2026-10-14: a dev tool -- live players pressing [ opened it)

    if input.KeyCode == Enum.KeyCode.LeftBracket then
        vmTuneModeOn = not vmTuneModeOn
        tuneLabel.Visible = vmTuneModeOn
        if vmTuneModeOn and not vmTuneBaseId then
            PreviewGun(ALL_GUN_BASE_IDS[vmTuneCycleIndex])
        end
        if vmTuneModeOn then RefreshTuneLabel() end
        return
    end

    if not vmTuneModeOn then return end

    if input.KeyCode == Enum.KeyCode.PageDown then
        vmTuneCycleIndex = (vmTuneCycleIndex % #ALL_GUN_BASE_IDS) + 1
        PreviewGun(ALL_GUN_BASE_IDS[vmTuneCycleIndex])
        RefreshTuneLabel()
    elseif input.KeyCode == Enum.KeyCode.PageUp then
        vmTuneCycleIndex = ((vmTuneCycleIndex - 2) % #ALL_GUN_BASE_IDS) + 1
        PreviewGun(ALL_GUN_BASE_IDS[vmTuneCycleIndex])
        RefreshTuneLabel()
    elseif input.KeyCode == Enum.KeyCode.RightBracket then
        if vmTuneBaseId then
            MeshRotationOverride[vmTuneBaseId] = nil
            MeshFitOverride[vmTuneBaseId] = nil
            RefreshTuneLabel()
            RefreshTunedView()
        end
    elseif input.KeyCode == Enum.KeyCode.Up then
        ApplyWorldDelta(CFrame.Angles(math.rad(-5), 0, 0))
    elseif input.KeyCode == Enum.KeyCode.Down then
        ApplyWorldDelta(CFrame.Angles(math.rad(5), 0, 0))
    elseif input.KeyCode == Enum.KeyCode.Left then
        ApplyWorldDelta(CFrame.Angles(0, math.rad(-5), 0))
    elseif input.KeyCode == Enum.KeyCode.Right then
        ApplyWorldDelta(CFrame.Angles(0, math.rad(5), 0))
    elseif input.KeyCode == Enum.KeyCode.Comma then
        ApplyWorldDelta(CFrame.Angles(0, 0, math.rad(-5)))
    elseif input.KeyCode == Enum.KeyCode.Period then
        ApplyWorldDelta(CFrame.Angles(0, 0, math.rad(5)))
    elseif input.KeyCode == Enum.KeyCode.One then
        ApplyWorldDelta(CFrame.Angles(math.rad(-90), 0, 0))
    elseif input.KeyCode == Enum.KeyCode.Two then
        ApplyWorldDelta(CFrame.Angles(math.rad(90), 0, 0))
    elseif input.KeyCode == Enum.KeyCode.Three then
        ApplyWorldDelta(CFrame.Angles(0, math.rad(-90), 0))
    elseif input.KeyCode == Enum.KeyCode.Four then
        ApplyWorldDelta(CFrame.Angles(0, math.rad(90), 0))
    elseif input.KeyCode == Enum.KeyCode.Five then
        ApplyWorldDelta(CFrame.Angles(0, 0, math.rad(-90)))
    elseif input.KeyCode == Enum.KeyCode.Six then
        ApplyWorldDelta(CFrame.Angles(0, 0, math.rad(90)))
    elseif input.KeyCode == Enum.KeyCode.Seven then
        ApplyWorldDelta(CFrame.Angles(0, math.rad(180), 0))
    elseif input.KeyCode == Enum.KeyCode.Minus then ApplyFitDelta(1 / 1.05, Vector3.zero); RefreshTuneLabel()
    elseif input.KeyCode == Enum.KeyCode.Equals then ApplyFitDelta(1.05, Vector3.zero); RefreshTuneLabel()
    elseif input.KeyCode == Enum.KeyCode.KeypadEight then ApplyFitDelta(1, Vector3.new(0, 0.02, 0)); RefreshTuneLabel()
    elseif input.KeyCode == Enum.KeyCode.KeypadTwo then ApplyFitDelta(1, Vector3.new(0, -0.02, 0)); RefreshTuneLabel()
    elseif input.KeyCode == Enum.KeyCode.KeypadFour then ApplyFitDelta(1, Vector3.new(-0.02, 0, 0)); RefreshTuneLabel()
    elseif input.KeyCode == Enum.KeyCode.KeypadSix then ApplyFitDelta(1, Vector3.new(0.02, 0, 0)); RefreshTuneLabel()
    elseif input.KeyCode == Enum.KeyCode.KeypadNine then ApplyFitDelta(1, Vector3.new(0, 0, -0.02)); RefreshTuneLabel()
    elseif input.KeyCode == Enum.KeyCode.KeypadThree then ApplyFitDelta(1, Vector3.new(0, 0, 0.02)); RefreshTuneLabel()
    end
end)

-- Server Remotes
-- (UI.OpenMenuByName: hideout stations open the same windows as the city stations)
UI.OpenMenuByName = function(menuName: string, a1: any?, a2: any?)
    -- hub stations only open in the hub (2026-10-03 bug: a late gate touch popped the Dungeons window in a dungeon)
    do
        local ch = LocalPlayer.Character
        local rt = ch and ch:FindFirstChild("HumanoidRootPart")
        if rt and (rt :: BasePart).Position.Z > 450 and menuName ~= "Settings" then return end
        if (menuName == "Dungeons" or menuName == "Challenges") and os.clock() < (UI.noGateUntil or 0) then return end
    end
    -- (a station only ever OPENS its menu: its prompt used to toggle an open menu shut -- owner 2026-10-05, the skill
    -- tree "would just close each time" when a click landed where the Monolith's prompt floated over the window)
    local function Open(frame: any) if not frame.Visible then OpenMenuFrame(frame) end end
    if menuName == "Roll" then
        UI.rGoldBal.Text = ((clientState.LastDailyRoll or 0) >= os.time() // 86400) and "Today's free roll is used. Come back tomorrow." or "Your free roll for today is ready: a gun + a guaranteed Prism Shard stack!"
        Open(UI.rollFrame)
    elseif menuName == "Skills" then Open(UI.treeFrame); RefreshTree()
    elseif menuName == "Inventory" then Open(UI.invFrame); RefreshInventory()
    elseif menuName == "Shop" then Open(UI.shopFrame); RefreshShopMenu()
    elseif menuName == "Upgrade" then RefreshUpgradeMenu(); Open(UI.upgFrame)
    elseif menuName == "Dungeons" then if not UI.dungFrame.Visible then OpenMenuFrame(UI.dungFrame) end
    elseif menuName == "Index" then Open(UI.indexFrame); RenderIndexContent()
    elseif menuName == "Trade" then if UI.trade then UI.trade.Open() end
    elseif menuName == "HideoutShop" then if UI.OpenHideoutShop then UI.OpenHideoutShop() end
    elseif menuName == "Settings" then Open(UI.setFrame)
    elseif menuName == "BarStyles" then if UI.OpenCosmetics then UI.OpenCosmetics("Locker", "HealthBar") end
    elseif menuName == "Cosmetics" then if UI.OpenCosmetics then UI.OpenCosmetics("Locker") end
    elseif menuName == "CosmeticShop" then if UI.OpenCosmetics then UI.OpenCosmetics("Shop", a1, a2) end -- (a1, a2 = category, item: open on it)
    elseif menuName == "Armory" then Open(UI.armoryFrame); RefreshArmoryMenu()
    elseif menuName == "Creator" then if UI.creator and not UI.creator.Panel.Visible then OpenMenuFrame(UI.creator.Panel) end
    elseif menuName == "Season" then
        if UI.TrialRunner and UI.TrialRunner.IsRunning() then return end
        if not UI.seasonFrame.Visible then OpenMenuFrame(UI.seasonFrame) end
    elseif menuName == "Districts" then if UI.OpenDistricts then UI.OpenDistricts(a1) end -- (UPDATE 7 B5: a district leader)
    elseif menuName == "Market" then if UI.OpenMarket then UI.OpenMarket(a1) end -- (UPDATE 7 C7: the market board)
    elseif menuName == "Guild" then if UI.OpenGuild then UI.OpenGuild() end -- (UPDATE 7 B9)
    elseif menuName == "PartyFinder" then if UI.OpenPartyFinder then UI.OpenPartyFinder() end -- (2026-10-20)
    elseif menuName == "Referrals" then if UI.OpenReferrals then UI.OpenReferrals() end -- (2026-10-20 friend invites)
    elseif menuName == "Profile" then if UI.OpenProfile then UI.OpenProfile(a1) end -- (2026-10-20: a statue / anyone's profile)
    elseif menuName == "ShotMods" then if UI.OpenShotMods then UI.OpenShotMods(a1) end -- (UPDATE 8 OFFENSE phase 3: the MODS window)
    elseif menuName == "Challenges" then
        if UI.TrialRunner and UI.TrialRunner.IsRunning() then return end
        if UI.challFrame.Visible then return end -- walking into the gate again shouldn't reopen it
        OpenMenuFrame(UI.challFrame)
        if type(a1) == "string" and UI.challenges then UI.challenges.ShowTab(a1) end -- (["menu", "Challenges", "Mastery"]: a tab)
    end
end
Remotes.GetEvent("OpenMenu").OnClientEvent:Connect(function(menuName: string, a1: any?, a2: any?) UI.OpenMenuByName(menuName, a1, a2) end)
-- (UI CLEAN R-A) the top-bar nav of the R-A groups: GAME / PROGRESS / SOCIAL + the STORE (UIStyle.NavOpen; MenuKit.NAV)
;(function()
    local N = UIStyle.NavOpen
    if type(N) ~= "table" then return end
    local function Go(fn) return function() SoundHelper.Play("Click"); CloseAllMenus(); task.defer(fn) end end
    N.SETTINGS = Go(function() UI.OpenMenuByName("Settings") end)
    N.GUIDE = Go(function() if UI.welcome then UI.welcome.OpenGuide() end end)
    N["PATCH NOTES"] = Go(function() if UI.welcome then UI.welcome.OpenNotes() end end)
    N.CREDITS = Go(function() if UI.welcome then UI.welcome.OpenCredits() end end)
    N.CHALLENGES = Go(function() UI.OpenMenuByName("Challenges") end)
    N.SEASON = Go(function() UI.OpenMenuByName("Season") end)
    N.INDEX = Go(function() UI.OpenMenuByName("Index") end)
    N.STORE = Go(function() UI.OpenMenuByName("CosmeticShop") end)
    N.PROFILES = Go(function() if UI.OpenProfile then UI.OpenProfile() end end)
    N["PARTY FINDER"] = Go(function() if UI.OpenPartyFinder then UI.OpenPartyFinder() end end)
    N.CREW = Go(function() if UI.OpenGuild then UI.OpenGuild() end end)
    N.TRADE = Go(function() UI.OpenMenuByName("Trade") end)
    -- (UI CLEAN audit: the R-A2 additions were dead words in the top bar -- they open their windows now)
    N.DUEL = Go(function() if UI.duel then UI.duel.Open() end end)
    N.INVITE = Go(function() if UI.OpenReferrals then UI.OpenReferrals() end end)
    N.QUARTERS = Go(function() if UI.OpenDistricts then UI.OpenDistricts() end end)
    if RunService:IsStudio() then UI.DevNavGuide = N.GUIDE; UI.DevNavCredits = N.CREDITS end -- (Studio: DevAct "ui:DevNavGuide" / "ui:DevNavCredits")
end)()
-- (UI CLEAN R-A) THE INDEX on the target's language: the full-screen field + the PROGRESS top bar (UIStyle.MenuField), the
-- window fills the room under the bar, its tabs are WORDS (Sub, the selected one Text + a 2 px underline -- read from the colour
-- RenderIndexContent paints), every card is the target's raised card (no box / border), texts snapped onto the roles.
;(function()
    local f = UI.indexFrame
    if not (f and UIStyle.MenuField) then return end
    local MK = require(sharedFolder:WaitForChild("MenuKit"))
    local header = UI.windowHeaders and UI.windowHeaders[f]
    local tabsBar, scroll
    for _, c in ipairs(f:GetChildren()) do
        if c:IsA("ScrollingFrame") then scroll = c
        elseif c:IsA("Frame") and c:FindFirstChildWhichIsA("TextButton") and c.Position.Y.Offset > 30 and c.Position.Y.Offset < 70 then tabsBar = c end
    end
    local base = { Size = f.Size, Position = f.Position, Anchor = f.AnchorPoint }
    local function Desk(on: boolean, barBottom: number?)
        if header then header.Visible = not on end
        f.BackgroundTransparency = on and 1 or UIStyle.WINDOW_T
        for _, c in ipairs(f:GetChildren()) do if c:IsA("UIStroke") then c.Enabled = not on end end
        if on and barBottom then
            local hs = hudGui:FindFirstChildOfClass("UIScale")
            local k = math.max(hs and hs.Scale or 1, 0.05)
            local vs = workspace.CurrentCamera.ViewportSize
            local W, V = vs.X / k, vs.Y / k
            local w = math.min(1180, W - 64)
            f.AnchorPoint = Vector2.new(0.5, 0)
            f.Position = UDim2.new(0.5, 0, 0, barBottom - 30) -- (the old 40 px header strip sits under the bar: tabs start right below it)
            f.Size = UDim2.fromOffset(w, math.max(300, V - barBottom + 30 - 20))
        elseif not on then
            f.Size, f.Position, f.AnchorPoint = base.Size, base.Position, base.Anchor
        end
    end
    UIStyle.MenuField(f, { Items = UIStyle.MENU_NAV.PROGRESS or { "INDEX" }, Selected = "INDEX", OnClose = function() CloseAllMenus() end,
        Meta = "Every gun, gear slot, rarity, enemy and title -- and how the game works.",
        Place = function(barBottom: number, phone: boolean) Desk(not phone, barBottom) end })
    f:GetPropertyChangedSignal("Visible"):Connect(function() if not f.Visible then Desk(false) end end)
    if scroll then MK.Flat(scroll); scroll.ScrollBarThickness = 3; scroll.ScrollBarImageColor3 = UIStyle.Colors.Sub end
    -- word tabs: RenderIndexContent paints the selected tab (78, 82, 94); read that, draw words
    local SEL = Color3.fromRGB(78, 82, 94)
    for _, b in ipairs(tabsBar and tabsBar:GetChildren() or {}) do
        if b:IsA("TextButton") then
            b.BorderSizePixel = 0
            b:SetAttribute("NoNeon", true); b:SetAttribute("Skinned", true)
            for _, c in ipairs(b:GetChildren()) do if c:IsA("UIStroke") or c:IsA("UIGradient") or c:IsA("UICorner") then c:Destroy() end end
            UIStyle.TextRole(b, "Tab"); b.TextStrokeTransparency = 1
            local mark = Instance.new("Frame")
            mark.Name = "KitMark"; mark.BorderSizePixel = 0; mark.BackgroundColor3 = UIStyle.Colors.Text; mark.AnchorPoint = Vector2.new(0.5, 1)
            mark.Position = UDim2.fromScale(0.5, 1); mark.Visible = false; mark:SetAttribute("Skinned", true); mark.Parent = b
            local hov = false
            local function Paint()
                local on = b.BackgroundColor3 == SEL
                if b.BackgroundTransparency ~= 1 then b.BackgroundTransparency = 1 end
                b.TextColor3 = (on or hov) and UIStyle.Colors.Text or UIStyle.Colors.Sub
                mark.Visible = on
                mark.Size = UDim2.fromOffset(math.max(24, b.TextBounds.X), 2)
            end
            b:GetPropertyChangedSignal("BackgroundColor3"):Connect(Paint)
            b:GetPropertyChangedSignal("BackgroundTransparency"):Connect(Paint)
            b.MouseEnter:Connect(function() hov = true; Paint() end)
            b.MouseLeave:Connect(function() hov = false; Paint() end)
            Paint()
        end
    end
    if tabsBar then -- (one hairline under the word tabs, as the target's bag tabs)
        local r = Instance.new("Frame"); r.Name = "KitRule"; r.BorderSizePixel = 0; r.BackgroundColor3 = UIStyle.Colors.Text; r.BackgroundTransparency = 0.88
        r.AnchorPoint = Vector2.new(0, 1); r.Position = UDim2.fromScale(0, 1); r.Size = UDim2.new(1, 0, 0, 1); r:SetAttribute("Skinned", true); r.Parent = tabsBar
    end
    -- cards: every Frame the renderer drops straight into the list -> the target's card; texts onto the roles. A WEAPONS card
    -- ("<name>   •   <class> class") gets its name in display caps and the gun's drawn icon on the right (AimRngShared/ItemIcons)
    local byName = {}
    for id, b in pairs(ItemData.BaseWeapons) do if b.Name then byName[b.Name] = id end end
    local okI, Icons = pcall(function() return require(sharedFolder:WaitForChild("ItemIcons", 5)) end)
    local function GunCard(card: Frame)
        for _, t in ipairs(card:GetChildren()) do
            if t:IsA("TextLabel") then
                local nm, cls = string.match(t.Text, "^(.-)%s+•%s+(.-) class$")
                local id = nm and byName[nm]
                if id then
                    t.RichText = true
                    t.Text = string.format('%s   <font color="#%s" size="13">%s</font>', string.upper(nm), UIStyle.Colors.Sub:ToHex(), string.upper(cls))
                    UIStyle.TextRole(t, "ItemName", { Keep = true }); t.FontFace = UIStyle.RoleFace("Label"); t.TextColor3 = UIStyle.Colors.Text
                    t.TextScaled = false; t.TextSize = 22 -- (owner 2026-10-28: "gun names in index can be slightly increased": a step over the 14 px stat line)
                    t:SetAttribute("NoSnap", true)
                    if okI and Icons and Icons.For and Icons.For(id) then
                        local im = Instance.new("ImageLabel")
                        im.Name = "KitIcon"; im.BackgroundTransparency = 1; im.AnchorPoint = Vector2.new(1, 0.5); im.Position = UDim2.new(1, -18, 0.5, 0)
                        im.Size = UDim2.fromOffset(150, 56); im.ImageTransparency = 0.05; im:SetAttribute("Skinned", true); im.Parent = card
                        pcall(Icons.Apply, im, id)
                    end
                    return
                end
            end
        end
    end
    if scroll then
        scroll.DescendantAdded:Connect(function(d)
            if d:IsA("Frame") and d.Parent == scroll and d.BackgroundTransparency < 0.5 and not d:GetAttribute("KitCard") then
                d:SetAttribute("KitCard", true)
                task.defer(function() if d.Parent then MK.Card(d); GunCard(d) end end)
            elseif d:IsA("TextLabel") or d:IsA("TextButton") then
                task.defer(function() if d.Parent and UIStyle.SnapText then UIStyle.SnapText(d) end end)
            end
        end)
    end
end)()

-- TRADING (0.55): the TRADE window + request popup (TradeMenu; TradeService on the server checks everything)
;(function()
    local TradeMenu = require(sharedFolder:WaitForChild("TradeMenu"))
    UI.trade = TradeMenu.Build(UI.menuFolder, hudGui, {
        GetState = function() return clientState end,
        Toast = function(t) ShowToast(t) end,
        Click = function() SoundHelper.Play("Click") end,
        Sound = function(n) SoundHelper.Play(n) end,
        OpenFrame = function(f) OpenMenuFrame(f) end,
        CloseAll = function() CloseAllMenus() end,
        Tooltip = function(gui, item, isGear) if UI.HookItemTooltip then UI.HookItemTooltip(gui, item, isGear) end end,
        HideTooltip = function() if UI.HideTooltip then UI.HideTooltip() end end,
    })
end)()

-- DUELS (0.59): the DUEL window, challenges, the duel HUD and the standardized gun (PvpClient; PvpService checks everything)
;(function()
    local PvpClient = require(sharedFolder:WaitForChild("PvpClient"))
    local api = PvpClient.Build(UI.menuFolder, hudGui, {
        GetState = function() return clientState end,
        Toast = function(t) ShowToast(t) end,
        Click = function() SoundHelper.Play("Click") end,
        Sound = function(n) SoundHelper.Play(n) end,
        OpenFrame = function(f) OpenMenuFrame(f) end,
        CloseAll = function() CloseAllMenus() end,
        Tooltip = function(gui, item, isGear) if UI.HookItemTooltip then UI.HookItemTooltip(gui, item, isGear) end end,
        Hitmarker = function() TriggerHitmarker(false) end,
        Watch = function(uid: number) -- (0.79: the Duel window's WATCH -> SpectateClient)
            if UI.spectate and UI.spectate.Watch then UI.spectate.Watch(uid) end
        end,
        Hurt = function(_dmg: number?, from: any) -- (0.78 duels: a hit arc toward the shooter + the hurt sound, no red flash)
            if typeof(from) == "Vector3" then pcall(HurtFX.Arc, from, Color3.fromRGB(235, 238, 245)) end -- (0.93: white, no red in duels)
            SoundHelper.Play("PlayerHurt")
        end,
        LocalHit = function()
            SoundHelper.ChainHit()
            if GameSettings.Get("HitSound") ~= "Off" then SoundHelper.Play("HitNormal") end
        end,
        SetMainHud = function(on) if UI.healthFrame then UI.healthFrame.Visible = on end end,
        OnDuelChanged = function() if UpdateWeaponHUD then UpdateWeaponHUD() end end,
        Rebuild = function(w) RebuildViewmodelForWeapon(w); UpdateAmmoHUD(); if UpdateWeaponHUD then UpdateWeaponHUD() end end,
        SetSlot = function(slot) if UI.SetSlot then UI.SetSlot(slot) end end,
    })
    UI.duel = api
    UI.PvpDef = api.Def
    UI.PvpShot = api.Shot
    UI.PvpReapply = api.Reapply
end)()

-- HIDEOUTS (0.55): drawing the hideout you're in, the HIDEOUT window, build mode, visit requests (HideoutClient)
;(function()
    local HideoutClient = require(sharedFolder:WaitForChild("HideoutClient"))
    local api = HideoutClient.Init(UI.menuFolder, hudGui, {
        GetState = function() return clientState end,
        Toast = function(t) ShowToast(t) end,
        Click = function() SoundHelper.Play("Click") end,
        Sound = function(n) SoundHelper.Play(n) end,
        OpenFrame = function(f) OpenMenuFrame(f) end,
        CloseAll = function() CloseAllMenus() end,
        OpenMenu = function(n) UI.OpenMenuByName(n) end,
        IsTyping = function() return GameSettings.IsTyping() end,
        ShowStashTab = function(t) if UI.ShowStashTab then UI.ShowStashTab(t) end end,
    })
    UI.hideout = api
    UI.ToggleHideoutMenu = api.Toggle
    UI.OpenHideoutShop = api.OpenShop
    UI.HideoutOnState = api.OnState
end)()

-- Enemy health bars: one screen-space layer (EnemyBars) -- bars only while they matter, satisfying drain, boss bar on top
;(function()
    -- While any window is open, hide every interact prompt: a prompt floating over a window took the clicks meant for
    -- the window (clicking a skill tree node under the Monolith's prompt "closed" the tree)
    local PPS = game:GetService("ProximityPromptService")
    task.spawn(function()
        while true do
            task.wait(0.15)
            local open = false -- (what's on screen, not the isAnyMenuOpen flag: a stuck flag must never hide the stations)
            for _, c in ipairs(UI.menuFolder:GetChildren()) do
                if c:IsA("GuiObject") and c.Visible then open = true break end
            end
            if PPS.Enabled == open then PPS.Enabled = not open end
        end
    end)
end)()

;(function()
    local EnemyBars = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("EnemyBars"))
    EnemyBars.Start(function() return EnemyVisuals.HealthBars end)
    -- the cosmetics window: SHOP + MY COSMETICS (left dock tiles; Settings > Enemies > Health Bar Style opens it too)
    local CosmeticsMenu = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("CosmeticsMenu"))
    UI.cosmetics = CosmeticsMenu.Build(UI.menuFolder, {
        GetState = function() return clientState end,
        PlayClick = function() SoundHelper.Play("Click") end,
        OnClose = function() CloseAllMenus() end,
        Toast = function(t) ShowToast(t) end,
        OnEquipped = function() SoundHelper.Play("Upgrade") end,
        -- inspect before you buy: the item on you in first person, or a showcase of your character (TryOn)
        TryOn = function(e, how) UI.TryOnStart(e, how) end,
    })
    UI.TryOnStart = function(e, how)
            local TryOn = require(game.ReplicatedStorage.AimRngShared:WaitForChild("TryOn"))
            local lastMode = "Shop"
            local okSel, _, m = pcall(function() return UI.cosmetics.Selected() end)
            if okSel and m then lastMode = m end
            TryOn.Start(e, how, {
                State = function() return clientState end,
                Rebuild = function(w) RebuildViewmodelForWeapon(w) end,
                Rig = function() return realRig end,
                CloseMenus = function() CloseAllMenus() end,
                Reopen = function(entry) if UI.OpenCosmetics then UI.OpenCosmetics(lastMode, entry and entry.Cat, entry and entry.Id) end end,
                Toast = function(t) ShowToast(t) end,
                ApplyTheme = function(t) if UI.ApplyHudTheme then UI.ApplyHudTheme(t) end end,
                RefreshTheme = function() if UI.RefreshHudTheme then UI.RefreshHudTheme() end end,
                SelectSlot = function(slot) if UI.SetSlot then UI.SetSlot(slot) end end,
                Teleport = function(cf) TeleportClient(cf) end, -- (Update 6: the try range + back)
            })
            UI.TryOnShot = TryOn.Shot
            UI.TryOnReapply = TryOn.Reapply
            UI.TryOnStopForMenu = function(frame) if TryOn.Active() and frame ~= UI.cosmetics.Frame then TryOn.Stop(true) end end
    end
    UI.OpenCosmetics = function(mode, cat, itemId)
        UI.cosmetics.Open(mode, cat, itemId)
        if not UI.cosmetics.Frame.Visible then OpenMenuFrame(UI.cosmetics.Frame) end
    end
    SettingsMenu.Actions.BarStyles = function() UI.OpenCosmetics("Locker", "HealthBar") end
    UI.DevLockerBundles = function() UI.OpenCosmetics("Locker", "Bundle") end -- (Studio: DevAct "ui:DevLockerBundles" = MY COSMETICS > BUNDLES)
end)()

-- Sounds: the Hit Sound picker, and no Roblox "oof" when you die
;(function()
    GameSettings.OnChanged("HitSound", function(v)
        if type(v) == "string" and v ~= "Off" then SoundHelper.HitVariant = v end
    end)
    GameSettings.OnChanged("HeadHitSound", function(v)
        if type(v) == "string" and v ~= "Off" then SoundHelper.HeadVariant = v end
    end)
    GameSettings.OnChanged("HitSoundVol", function(v)
        SoundHelper.HitVolume = math.clamp((tonumber(v) or 200) / 100, 0, 3)
    end)
    -- preload the hit-sound pool now and whenever a choice changes, so even the first hit is instant
    task.defer(SoundHelper.WarmHits)
    GameSettings.OnChanged("HitSound", function() task.defer(SoundHelper.WarmHits) end)
    GameSettings.OnChanged("HeadHitSound", function() task.defer(SoundHelper.WarmHits) end)
    GameSettings.OnChanged("KillSound", function(v)
        if type(v) == "string" then SoundHelper.KillVariant = v end
        task.defer(SoundHelper.WarmHits)
    end)
    GameSettings.OnChanged("DeathSound", function(v) if type(v) == "string" then SoundHelper.DeathVariant = v end end)
    -- (0.62, owner: "Hitsounds in menu should be auto played to preview"): picking a hit / head / kill / death sound plays
    -- it (not the saved settings loading in at join)
    local previewFrom = os.clock() + 4
    for key, kind in pairs({ HitSound = "HitNormal", HeadHitSound = "HitCrit", KillSound = "Kill", DeathSound = "Death" }) do
        GameSettings.OnChanged(key, function(v)
            if os.clock() < previewFrom or v == "Off" or GameSettings.MirrorChanging then return end -- (0.83: not a spectate swap)
            task.delay(0.05, function() -- (after the variant above is set and the pool is rebuilt)
                SoundHelper.HitPitch = 1
                if kind == "Death" then pcall(SoundHelper.PlayDeath) else SoundHelper.Play(kind) end
            end)
        end)
    end
    -- no Roblox "oof" on ANY character (others' deaths too); your own death plays the Death Sound
    local function Mute(char)
        local root = char:WaitForChild("HumanoidRootPart", 10)
        local died = root and root:WaitForChild("Died", 10)
        if died and died:IsA("Sound") then died.Volume = 0 end
    end
    -- (runs never kill the Humanoid: the server respawns you and takes a life -- so a life lost IS the death)
    local lastLives = LocalPlayer:GetAttribute("Lives")
    LocalPlayer:GetAttributeChangedSignal("Lives"):Connect(function()
        local n = LocalPlayer:GetAttribute("Lives")
        if type(n) == "number" and type(lastLives) == "number" and n < lastLives then SoundHelper.PlayDeath() end
        lastLives = n
    end)
    local function Watch(p)
        if p.Character then task.spawn(Mute, p.Character) end
        p.CharacterAdded:Connect(Mute)
    end
    for _, p in ipairs(Players:GetPlayers()) do Watch(p) end
    Players.PlayerAdded:Connect(Watch)
end)()

-- OTHER RUNS ARE INVISIBLE (2026-10-03, owner: "I am currently in a dungeon. Another player is in one too, not in my party,
-- but I can see his name tag"): every solo dungeon is built at the same place, so a player in another run stands inside
-- yours. Whenever either of you is in a dungeon (Z > 450) and you're not in the same party run, their character is hidden
-- on this client: invisible, no name / title tag, no collisions with you, your shots pass through them. Restored the
-- moment you're both in the hub again (or share a run).
;(function()
    local views: { [Player]: any } = {}
    local function HideOne(store: any, d: Instance)
        if store[d] ~= nil then return end
        if d:IsA("BasePart") then
            store[d] = { CanCollide = d.CanCollide, CanQuery = d.CanQuery, CanTouch = d.CanTouch }
            d.LocalTransparencyModifier = 1
            d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
        elseif d:IsA("Decal") then
            store[d] = true
            d.LocalTransparencyModifier = 1
        elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Highlight") then
            store[d] = { Enabled = (d :: any).Enabled }
            ;(d :: any).Enabled = false
        elseif d:IsA("Humanoid") then
            store[d] = { Display = d.DisplayDistanceType }
            d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        elseif d:IsA("Sound") then
            store[d] = { Volume = d.Volume }
            d.Volume = 0
        end
    end
    local function RestoreAll(v: any)
        if v.Conn then v.Conn:Disconnect(); v.Conn = nil end
        for d, o in pairs(v.Store) do
            if d.Parent then
                if d:IsA("BasePart") then
                    d.LocalTransparencyModifier = 0
                    d.CanCollide, d.CanQuery, d.CanTouch = o.CanCollide, o.CanQuery, o.CanTouch
                elseif d:IsA("Decal") then
                    d.LocalTransparencyModifier = 0
                elseif d:IsA("Humanoid") then
                    d.DisplayDistanceType = o.Display
                elseif type(o) == "table" and o.Enabled ~= nil then
                    (d :: any).Enabled = o.Enabled
                elseif type(o) == "table" and o.Volume ~= nil then
                    (d :: any).Volume = o.Volume
                end
            end
        end
        table.clear(v.Store)
    end
    local function ShouldSee(p: Player): boolean
        local mine = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local theirs = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if not mine or not theirs then return true end
        local meIn = (mine :: BasePart).Position.Z > 450
        local themIn = (theirs :: BasePart).Position.Z > 450
        if not meIn and not themIn then return true end -- both in the hub
        local a, b = LocalPlayer:GetAttribute("RunId"), p:GetAttribute("RunId")
        return a ~= nil and a == b -- the same party run
    end
    local acc = 0
    RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < 0.3 then return end
        acc = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local char = p.Character
                local v = views[p]
                if v and v.Char ~= char then RestoreAll(v); views[p] = nil; v = nil end -- (respawned: start over)
                if char then
                    local see = ShouldSee(p)
                    if not see and not v then
                        v = { Char = char, Store = {} }
                        views[p] = v
                        for _, d in ipairs(char:GetDescendants()) do HideOne(v.Store, d) end
                        v.Conn = char.DescendantAdded:Connect(function(d) HideOne(v.Store, d) end)
                    elseif see and v then
                        RestoreAll(v)
                        views[p] = nil
                    end
                end
            end
        end
        for p, v in pairs(views) do if not p.Parent then RestoreAll(v); views[p] = nil end end
    end)
end)()

-- Your own title tag (above your head, visible to everyone): you see yours in third person, not in first person
;(function()
    local acc = 0
    RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < 0.25 then return end
        acc = 0
        local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
        if not head then return end
        local want = LocalPlayer:GetAttribute("ThirdPerson") == true
        local seen = false
        for _, tag in ipairs(head:GetChildren()) do
            if tag.Name == "PlayerTitleTag" and tag:IsA("BillboardGui") then
                if seen then tag:Destroy() -- (a stray duplicate from an older client build)
                else
                    seen = true
                    if tag.Enabled ~= want then tag.Enabled = want end
                end
            end
        end
    end)
end)()

-- HUB SHIFT LOCK HINT (owner 2026-10-02: Shift dashes in the hub now, so Shift Lock moved to Caps Lock -- "now I can't
-- shift lock in the hub"): a small "[CAPS] SHIFT LOCK: OFF / ON" line at the bottom of the screen in the hub hall
;(function()
    local HubCam = require(sharedFolder:WaitForChild("HubCamera"))
    local lbl = Instance.new("TextLabel")
    lbl.Name = "ShiftLockHint"
    lbl.AnchorPoint = Vector2.new(0, 1)
    -- (Update 5: right end of the row above the HUD stack; the run's hearts use this spot)
    lbl.AnchorPoint = Vector2.new(1, 1)
    lbl.Position = UDim2.new(0, UI.HudStack.X + UI.HudStack.W, 1, UI.HudStack.TopY)
    lbl.Size = UDim2.fromOffset(240, 22)
    lbl.BackgroundTransparency = 1 -- (UI CLEAN: plain small caps, shown for a moment when it changes -- not always on)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Right
    lbl.TextColor3 = UIStyle.Colors.Text
    lbl.TextStrokeTransparency = 0.72
    lbl:SetAttribute("TypeRole", "Label")
    lbl:SetAttribute("NoSkin", true)
    lbl.Visible = false
    lbl.Parent = hudGui
    local acc = 0
    local lastOn, showUntil = nil, 0
    RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < 0.15 then return end
        acc = 0
        local show = LocalPlayer:GetAttribute("ThirdPerson") == true and not isAnyMenuOpen and not GameSettings.TouchOnly()
            and not LocalPlayer:GetAttribute("CreatorOpen") and not LocalPlayer:GetAttribute("Showcase")
        local on = show and HubCam.ShiftLocked() or false
        if show and lastOn ~= nil and on ~= lastOn then showUntil = os.clock() + 2 end -- (a change: say so for 2 s)
        if show then lastOn = on end
        show = show and os.clock() < showUntil
        lbl.Visible = show
        if show then
            lbl.Text = "SHIFT LOCK " .. (on and "ON" or "OFF") .. "  " .. KeyTag("ShiftLock")
        end
    end)
end)()

-- SLIDE ANIMATION (owner 2026-10-02: "there needs to be a sliding animation so the player knows when they are sliding"):
-- * every sliding character (yours from MovementController, everyone else's from the server-relayed "Sliding" player
--   attribute) is posed on this client: body leaned back low, the lead leg out front, arms back for balance (R6 joints,
--   applied after the Animator each frame, eased in / out)
-- * first person: speed streaks down the screen edges (the gun tilt + camera lean are in the viewmodel / camera)
;(function()
    local MV = require(sharedFolder:WaitForChild("MovementController"))
    local amounts: { [Model]: number } = {}
    local function Pose(char: Model, k: number)
        local root = char:FindFirstChild("HumanoidRootPart")
        local torso = char:FindFirstChild("Torso")
        if root and not torso then
            -- R15 (joint frames line up with the parts: +X tilts back / swings a limb forward)
            local function J(partName: string, jointName: string): Motor6D?
                local part = char:FindFirstChild(partName)
                return part and part:FindFirstChild(jointName) :: Motor6D?
            end
            local rootJ, waist = J("LowerTorso", "Root"), J("UpperTorso", "Waist")
            local rh, lh = J("RightUpperLeg", "RightHip"), J("LeftUpperLeg", "LeftHip")
            local rs, ls = J("RightUpperArm", "RightShoulder"), J("LeftUpperArm", "LeftShoulder")
            local nk = J("Head", "Neck")
            if rootJ then rootJ.Transform = rootJ.Transform * CFrame.new(0, -1.3 * k, 0) * CFrame.Angles(math.rad(55) * k, 0, 0) end
            if waist then waist.Transform = waist.Transform * CFrame.Angles(math.rad(10) * k, 0, 0) end
            if rh then rh.Transform = rh.Transform * CFrame.Angles(math.rad(62) * k, 0, 0) end
            if lh then lh.Transform = lh.Transform * CFrame.Angles(math.rad(25) * k, 0, 0) end
            if rs then rs.Transform = rs.Transform * CFrame.Angles(math.rad(-30) * k, 0, math.rad(15) * k) end
            if ls then ls.Transform = ls.Transform * CFrame.Angles(math.rad(-30) * k, 0, math.rad(-15) * k) end
            if nk then nk.Transform = nk.Transform * CFrame.Angles(math.rad(-45) * k, 0, 0) end
            return
        end
        if not (root and torso) then return end
        local rj = root:FindFirstChild("RootJoint") :: Motor6D?
        local lh, rh = torso:FindFirstChild("Left Hip") :: Motor6D?, torso:FindFirstChild("Right Hip") :: Motor6D?
        local ls, rs = torso:FindFirstChild("Left Shoulder") :: Motor6D?, torso:FindFirstChild("Right Shoulder") :: Motor6D?
        local nk = torso:FindFirstChild("Neck") :: Motor6D?
        if rj then rj.Transform = rj.Transform * CFrame.new(0, 0, -1.25 * k) * CFrame.Angles(math.rad(-62) * k, 0, 0) end
        if rh then rh.Transform = rh.Transform * CFrame.Angles(0, 0, math.rad(58) * k) end
        if lh then lh.Transform = lh.Transform * CFrame.Angles(0, 0, math.rad(-22) * k) end
        if rs then rs.Transform = rs.Transform * CFrame.Angles(0, 0, math.rad(-35) * k) end
        if ls then ls.Transform = ls.Transform * CFrame.Angles(0, 0, math.rad(35) * k) end
        if nk then nk.Transform = nk.Transform * CFrame.Angles(math.rad(45) * k, 0, 0) end -- (head forward: eyes ahead)
    end
    -- speed streaks (first person only)
    local streaks = Instance.new("ScreenGui")
    streaks.Name = "SlideStreaks"; streaks.IgnoreGuiInset = true; streaks.ResetOnSpawn = false; streaks.DisplayOrder = 1
    streaks.Parent = LocalPlayer:WaitForChild("PlayerGui")
    local lines = {}
    for i = 1, 10 do
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0; f.BackgroundColor3 = Color3.new(1, 1, 1); f.BackgroundTransparency = 1
        f.AnchorPoint = Vector2.new(0.5, 0.5); f.Size = UDim2.new(0, 3, 0.18, 0)
        local g = Instance.new("UIGradient")
        g.Rotation = 90
        g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) })
        g.Parent = f
        f.Parent = streaks
        lines[i] = { F = f, X = (i <= 5) and (0.02 + 0.03 * i) or (1 - 0.03 * (i - 5) - 0.02), Ph = math.random() }
    end
    -- DASH ANIMATION (owner 2026-10-07: "Add dashing animations like we have with sliding, so the player knows"): a
    -- low lunge -- the body pitches forward and leans into the dash's side, the arms sweep back, the legs split into a
    -- long stride (R6 + R15). Yours from MovementController.DashAmount, everyone else's from the "Dashing" attribute.
    local dashAmt: { [Model]: number } = {}
    local function DashPose(char: Model, k: number, side: number)
        local root = char:FindFirstChild("HumanoidRootPart")
        local torso = char:FindFirstChild("Torso")
        if root and not torso then
            local function J(partName: string, jointName: string): Motor6D?
                local part = char:FindFirstChild(partName)
                return part and part:FindFirstChild(jointName) :: Motor6D?
            end
            local rootJ, waist = J("LowerTorso", "Root"), J("UpperTorso", "Waist")
            local rh, lh = J("RightUpperLeg", "RightHip"), J("LeftUpperLeg", "LeftHip")
            local rs, ls = J("RightUpperArm", "RightShoulder"), J("LeftUpperArm", "LeftShoulder")
            if rootJ then rootJ.Transform = rootJ.Transform * CFrame.new(0, -0.5 * k, 0) * CFrame.Angles(math.rad(-28) * k, 0, math.rad(-14 * side) * k) end
            if waist then waist.Transform = waist.Transform * CFrame.Angles(math.rad(-10) * k, 0, 0) end
            if rh then rh.Transform = rh.Transform * CFrame.Angles(math.rad(48) * k, 0, 0) end
            if lh then lh.Transform = lh.Transform * CFrame.Angles(math.rad(-40) * k, 0, 0) end
            if rs then rs.Transform = rs.Transform * CFrame.Angles(math.rad(-55) * k, 0, math.rad(-12) * k) end
            if ls then ls.Transform = ls.Transform * CFrame.Angles(math.rad(-55) * k, 0, math.rad(12) * k) end
            return
        end
        if not (root and torso) then return end
        local rj = root:FindFirstChild("RootJoint") :: Motor6D?
        local lh, rh = torso:FindFirstChild("Left Hip") :: Motor6D?, torso:FindFirstChild("Right Hip") :: Motor6D?
        local ls, rs = torso:FindFirstChild("Left Shoulder") :: Motor6D?, torso:FindFirstChild("Right Shoulder") :: Motor6D?
        local nk = torso:FindFirstChild("Neck") :: Motor6D?
        -- (R6 RootJoint: -X pitches the body forward, Y rolls it; hips / shoulders swing about Z)
        if rj then rj.Transform = rj.Transform * CFrame.new(0, 0, -0.45 * k) * CFrame.Angles(math.rad(30) * k, math.rad(16 * side) * k, 0) end
        if rh then rh.Transform = rh.Transform * CFrame.Angles(0, 0, math.rad(45) * k) end
        if lh then lh.Transform = lh.Transform * CFrame.Angles(0, 0, math.rad(40) * k) end
        if rs then rs.Transform = rs.Transform * CFrame.Angles(0, 0, math.rad(-60) * k) end -- (arms swept back, like the slide's)
        if ls then ls.Transform = ls.Transform * CFrame.Angles(0, 0, math.rad(60) * k) end
        if nk then nk.Transform = nk.Transform * CFrame.Angles(math.rad(-22) * k, 0, 0) end -- (head up: eyes ahead)
    end
    -- (the pose goes on in PreSimulation: the Animator writes the joints just before it, and the body is solved from
    -- them right after -- a pose set at render time was overwritten before it ever showed)
    -- (2026-10-13) R6 bodies (every character since R6Spawner) are animated by AimRngShared/CharacterPoser: locomotion,
    -- slide + dash, gun holds, recoil, reloads, melee swings, aim pitch -- this loop only poses an R15 fallback body
    local Poser = require(sharedFolder:WaitForChild("CharacterPoser"))
    Poser.Start({ MV = MV })
    UI.Poser = Poser
    RunService.PreSimulation:Connect(function(dt)
        local now = workspace:GetServerTimeNow()
        for _, p in ipairs(Players:GetPlayers()) do
            local c = p.Character
            if c and not c:FindFirstChild("Torso") then
                local want = (p == LocalPlayer) and ((MV.SlideAmount or 0) > 0.5 and 1 or 0) or (p:GetAttribute("Sliding") and 1 or 0)
                local k = amounts[c] or 0
                k += (want - k) * math.clamp(dt * (want > k and 14 or 9), 0, 1)
                amounts[c] = (k > 0.01 or want > 0) and k or nil
                if k > 0.01 then Pose(c, k) end
                -- the dash lunge (not on top of a slide)
                local dk
                if p == LocalPlayer then
                    dk = MV.DashAmount or 0
                else
                    local at = tonumber(p:GetAttribute("Dashing")) or -99
                    local wantD = (now - at < 0.28) and 1 or 0
                    dk = dashAmt[c] or 0
                    dk += (wantD - dk) * math.clamp(dt * (wantD > dk and 30 or 7), 0, 1)
                    dashAmt[c] = (dk > 0.01) and dk or nil
                end
                if dk > 0.01 and k < 0.5 then DashPose(c, dk, (p == LocalPlayer) and (MV.DashSide or 0) or 0) end
            end
        end
        for c in pairs(amounts) do if not c.Parent then amounts[c] = nil end end
        for c in pairs(dashAmt) do if not c.Parent then dashAmt[c] = nil end end
    end)
    RunService:BindToRenderStep("AimRngSlideStreaks", Enum.RenderPriority.Last.Value, function()
        local now = os.clock()
        -- streaks: only in first person, scaled by the slide and your speed
        local sa = (LocalPlayer:GetAttribute("ThirdPerson") and 0) or math.max(MV.SlideAmount or 0, (MV.DashAmount or 0) * 1.2)
        local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local sp = r and Vector3.new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z).Magnitude or 0
        local vis = sa * math.clamp((sp - 10) / 30, 0.25, 1)
        for _, l in ipairs(lines) do
            if vis < 0.02 then
                l.F.BackgroundTransparency = 1
            else
                local y = (l.Ph + now * (1.4 + sp / 25)) % 1
                l.F.Position = UDim2.fromScale(l.X, y * 1.2 - 0.1)
                l.F.BackgroundTransparency = 1 - 0.45 * vis
            end
        end
    end)
end)()

-- MOVEMENT TECH: dash / slide / bhop (MovementController runs itself once required)
;(function()
    require(sharedFolder:WaitForChild("MovementController"))
end)()

-- (Update 6, owner: "We also need to add a proper tutorial. Right now the game is incredibly confusing to new players of this
-- genre") THE TUTORIAL: a guided first run in its own hall, then the hub + your hideout; the maps cards at level 100.
-- AimRngShared/Tutorial; started from the join below (new saves), the guide's TUTORIAL button, or the one-time offer.
;(function()
    local Tutorial = require(sharedFolder:WaitForChild("Tutorial"))
    Tutorial.Init({
        State = function() return clientState end,
        Rebuild = function(w) RebuildViewmodelForWeapon(w); pcall(UpdateWeaponHUD); pcall(UpdateAmmoHUD) end,
        Teleport = function(cf) TeleportClient(cf) end,
        Hitmarker = function(weak) TriggerHitmarker(weak) end,
        DamageText = function(amount, weak, crit, pos, model, killed) SpawnDamageText(amount, weak, crit, pos, nil, nil, nil, killed, model) end,
        Estimate = function(weak, model) return UI.EstimateShot and UI.EstimateShot(weak, model) or nil end,
        MenuOpen = function() -- (a window really on screen: the flag alone can outlive a window closed some other way)
            if not isAnyMenuOpen then return false end
            for _, c in ipairs(UI.menuFolder:GetChildren()) do if c:IsA("GuiObject") and c.Visible then return true end end
            return false
        end,
        CloseMenus = function() CloseAllMenus() end,
        Busy = function() return UI.TrialRunner ~= nil and UI.TrialRunner.IsRunning() == true end, -- (PLAYTEST 2026-10-31: no cards over an Aim Trial)
        OpenClassPicker = function() if UI.OpenClassPicker then UI.OpenClassPicker() end end, -- (the tour's CLASS step)
        Toast = function(t) ShowToast(t) end,
        Quiet = function(on) -- (the daily contracts box steps aside while the tutorial card is up: same corner of the screen)
            UI.tutorialQuiet = on or nil
            if UI.RefreshContracts then pcall(UI.RefreshContracts) end
        end,
        StopTryOn = function()
            local okT, TryOnM = pcall(function() return require(sharedFolder:WaitForChild("TryOn")) end)
            if okT and TryOnM.Active() then TryOnM.Stop(true) end
        end,
    })
    UI.tutorial = Tutorial
    UI.TutorialShot = Tutorial.Shot
    UI.TutorialReapply = Tutorial.Reapply
end)()

-- (the STYLE STUDIO character creator was removed 2026-10-02: everyone plays as their own Roblox avatar, R6 like Rivals)
;(function()
    -- WELCOME GUIDE + PATCH NOTES (hub corner buttons; the guide also pops up on join)
    local WelcomeGuide = require(sharedFolder:WaitForChild("WelcomeGuide"))
    UI.welcome = WelcomeGuide.Build(UI.menuFolder, {
        Open = function(frame) if not frame.Visible then OpenMenuFrame(frame) end end,
        Close = function() CloseAllMenus() end,
        Click = function() SoundHelper.Play("Click") end,
        Parent = hudGui,
        Tutorial = function() if UI.tutorial then UI.tutorial.Replay() end end, -- (Update 6: REPLAY TUTORIAL)
    })
    SettingsMenu.Actions.Credits = function() UI.welcome.OpenCredits() end -- (UPDATE 4 wrap-up: Settings > Interface > Credits)
    SettingsMenu.Actions.DropRules = function() -- (UPDATE 7 C9: the DROP RULES window, saved on the server)
        local f = require(sharedFolder:WaitForChild("DropRules")).Open(UI.menuFolder, {
            GetState = function() return clientState end,
            Save = function(list) return Remotes.GetFunction("DropRulesAction"):InvokeServer("Set", list) end,
            Toast = function(t) ShowToast(t) end,
            Click = function() SoundHelper.Play("Click") end,
        })
        f.Visible = false
        OpenMenuFrame(f)
    end
    if RunService:IsStudio() then UI.DevDropRules = function() SettingsMenu.Actions.DropRules() end end -- (UI CLEAN audit: DevAct "ui:DevDropRules")
    task.spawn(function()
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        task.wait(3)
        if LocalPlayer:GetAttribute("RunId") or not char.Parent then return end
        -- (Update 6 TUTORIAL: a new save goes straight into the tutorial instead of the guide; the save has to be in first)
        local t0 = os.clock()
        while not UI.stateLoaded and os.clock() - t0 < 12 do task.wait(0.25) end
        if UI.tutorial then
            local okJ, took = pcall(UI.tutorial.OnJoin)
            if okJ and took then return end
        end
        if GameSettings.Get("WelcomeOnJoin") ~= false and not isAnyMenuOpen and not LocalPlayer:GetAttribute("RunId") then
            UI.welcome.OpenGuide()
        end
    end)
end)()

;(function()
    -- ASCENDANCY PANEL (tree v4, 2026-10-05): opened from the passive tree's ASCENDANCY button. Pick one of your
    -- class's 3 ascendancies (cards), then spend ascendancy points (2 per Trial of Ascension cleared, max 8) on its
    -- 13-node mini-tree: click = allocate, right-click = refund (touch: tap = select, tap again = act).
    local AscendancyData = require(sharedFolder:WaitForChild("AscendancyData"))
    local DISC, RING = "rbxassetid://113529141356504", "rbxassetid://76845609957677"
    local PX = { AscStart = 50, Notable = 40, Small = 22 }
    local tf = UI.treeFrame
    local W, H = 680, 580

    local ascBtn = Instance.new("TextButton")
    ascBtn.Name = "AscendancyBtn"
    ascBtn.Size = UDim2.new(0, 230, 0, 28); ascBtn.Position = UDim2.new(0, 240, 0, 50) -- (beside the search box: at x 400 it ran into the zoom keys on phones)
    ascBtn.BackgroundColor3 = Color3.fromRGB(70, 45, 20); ascBtn.BorderSizePixel = 1; ascBtn.BorderColor3 = Color3.fromRGB(255, 184, 28)
    ascBtn.Font = Enum.Font.GothamBold; ascBtn.TextSize = 12; ascBtn.TextColor3 = Color3.fromRGB(255, 220, 140); ascBtn.ZIndex = 3
    ascBtn.Text = "SPECIALIZE"; ascBtn.Parent = tf
    if UI.TreeBtn then UI.TreeBtn(ascBtn, Color3.fromRGB(255, 205, 90)) end -- (2026-10-22 TREE LOOK v2)

    local panel = Instance.new("Frame")
    panel.Name = "AscPanel"
    panel.Size = UDim2.fromOffset(W, H); panel.AnchorPoint = Vector2.new(0.5, 0.5); panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.BackgroundColor3 = Color3.fromRGB(14, 12, 20); panel.BorderSizePixel = 0; panel.ZIndex = 30; panel.Visible = false
    panel.Active = true -- (clicks don't fall through to the tree)
    panel.Parent = tf
    panel:GetPropertyChangedSignal("Visible"):Connect(function()
        if panel.Visible and UI.treeHoverClear then UI.treeHoverClear() end -- (drop the passive tree's hover card under it)
    end)
    local pStroke = Instance.new("UIStroke"); pStroke.Color = Color3.fromRGB(255, 184, 28); pStroke.Thickness = 2; pStroke.Parent = panel
    local function T(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font?, xa: Enum.TextXAlignment?): TextLabel
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1; l.Font = font or Enum.Font.GothamMedium; l.TextSize = size; l.TextColor3 = color
        l.TextWrapped = true; l.TextXAlignment = xa or Enum.TextXAlignment.Left; l.TextYAlignment = Enum.TextYAlignment.Top
        l.Text = text; l.ZIndex = 32; l.Parent = parent
        return l
    end
    local title = T(panel, "SPECIALIZATION", 20, Color3.fromRGB(255, 220, 140), Enum.Font.GothamBlack)
    title.Position = UDim2.fromOffset(16, 10); title.Size = UDim2.new(1, -120, 0, 26)
    local sub = T(panel, "", 12, Color3.fromRGB(180, 185, 200))
    sub.Position = UDim2.fromOffset(16, 38); sub.Size = UDim2.new(1, -32, 0, 32)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "Close"; closeBtn.Size = UDim2.fromOffset(34, 30); closeBtn.Position = UDim2.new(1, -44, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 30); closeBtn.Font = Enum.Font.GothamBlack; closeBtn.TextSize = 16
    closeBtn.TextColor3 = Color3.new(1, 1, 1); closeBtn.Text = "X"; closeBtn.ZIndex = 33; closeBtn.Parent = panel
    local switchBtn = Instance.new("TextButton")
    switchBtn.Name = "Switch"; switchBtn.Size = UDim2.fromOffset(190, 30); switchBtn.Position = UDim2.new(1, -244, 0, 10)
    switchBtn.BackgroundColor3 = Color3.fromRGB(40, 44, 60); switchBtn.Font = Enum.Font.GothamBold; switchBtn.TextSize = 11
    switchBtn.TextColor3 = Color3.fromRGB(220, 225, 240); switchBtn.Text = "OTHER SPECIALIZATIONS"; switchBtn.ZIndex = 33; switchBtn.Parent = panel

    local cardsView = Instance.new("Frame")
    cardsView.Name = "Cards"; cardsView.BackgroundTransparency = 1; cardsView.Position = UDim2.fromOffset(0, 76); cardsView.Size = UDim2.new(1, 0, 1, -76)
    cardsView.ZIndex = 31; cardsView.Parent = panel
    local treeView = Instance.new("Frame")
    treeView.Name = "Tree"; treeView.BackgroundTransparency = 1; treeView.Position = UDim2.fromOffset(0, 76); treeView.Size = UDim2.new(1, 0, 1, -76)
    treeView.ZIndex = 31; treeView.Parent = panel

    local browsing = false -- (true = cards even though an ascendancy is chosen)
    local armed: string? = nil
    local touchSel: string? = nil
    local busy = false
    local builtFor: string? = nil
    local nodeUi: { [string]: { Fill: ImageLabel, Ring: ImageLabel, Btn: ImageButton } } = {}
    local Refresh: () -> ()

    local function Points(): (number, number)
        return AscendancyData.Spent(clientState), AscendancyData.PointsFor(clientState)
    end
    local function Act(action: string, arg: string)
        if busy then return end
        busy = true
        local ok, msg = Remotes.GetFunction("AscendancyAction"):InvokeServer(action, arg)
        busy = false
        ShowToast(msg or (ok and "Done." or "Can't do that."))
        if ok then SoundHelper.Play(action == "Refund" and "Click" or "Upgrade") end
    end

    -- ----- cards: your class's three ascendancies -----
    local function BuildCards()
        for _, c in ipairs(cardsView:GetChildren()) do c:Destroy() end
        local list = AscendancyData.ByClass[clientState.Class or ""] or {}
        local cw, gap = 204, 14
        -- (any number per class: the row scrolls sideways once it's wider than the panel)
        local rowW = #list * cw + math.max(0, #list - 1) * gap
        local row = Instance.new("ScrollingFrame")
        row.Name = "Row"; row.BackgroundTransparency = 1; row.BorderSizePixel = 0; row.ZIndex = 32
        row.Size = UDim2.new(1, -20, 1, -6); row.Position = UDim2.fromOffset(10, 0)
        row.ScrollingDirection = Enum.ScrollingDirection.X; row.ScrollBarThickness = 6; row.CanvasSize = UDim2.fromOffset(rowW, 0)
        row.Parent = cardsView
        local x0 = math.max(0, (W - 20 - rowW) / 2)
        local _, total = Points()
        for i, a in ipairs(list) do
            local card = Instance.new("Frame")
            card.Name = a.Id; card.Size = UDim2.fromOffset(cw, H - 76 - 30); card.Position = UDim2.fromOffset(x0 + (i - 1) * (cw + gap), 4)
            card.BackgroundColor3 = Color3.fromRGB(22, 22, 32); card.BorderSizePixel = 0; card.ZIndex = 32; card.Parent = row
            local st = Instance.new("UIStroke"); st.Color = a.Color; st.Thickness = 1.5; st.Transparency = 0.3; st.Parent = card
            local n = T(card, string.upper(a.Name), 19, a.Color, Enum.Font.GothamBlack)
            n.Position = UDim2.fromOffset(10, 8); n.Size = UDim2.new(1, -20, 0, 24)
            local b = T(card, a.Blurb, 12, Color3.fromRGB(220, 225, 235))
            b.Position = UDim2.fromOffset(10, 34); b.Size = UDim2.new(1, -20, 0, 46)
            -- its notables in data order (* = a capstone: nothing after it), scrolling if there are many
            local notes = Instance.new("ScrollingFrame")
            notes.Name = "Notables"; notes.BackgroundTransparency = 1; notes.BorderSizePixel = 0; notes.ZIndex = 32
            notes.Position = UDim2.fromOffset(0, 82); notes.Size = UDim2.new(1, 0, 1, -132); notes.ScrollBarThickness = 4
            notes.ScrollingDirection = Enum.ScrollingDirection.Y; notes.Parent = card
            local y = 0
            local function Depth(n: any): number
                local d = 0
                while n and n.Parent do d += 1; n = AscendancyData.Nodes[n.Parent] end
                return d
            end
            local deepest = 0
            for _, id in ipairs(a.Nodes or {}) do deepest = math.max(deepest, Depth(AscendancyData.Nodes[id])) end
            for _, id in ipairs(a.Nodes or {}) do
                local node = AscendancyData.Nodes[id]
                if node and node.Type == "Notable" then
                    local capstone = #(node.Children or {}) == 0 and Depth(node) == deepest
                    local nm = T(notes, node.Name .. (capstone and "  *" or ""), 11, a.Color:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Font.GothamBold)
                    if node.Sig then nm.Text = node.Name .. "  •  SIGNATURE"; nm.TextColor3 = Color3.fromRGB(255, 214, 110) end -- (CLASS BUILDS) SIGNATURE
                    nm.Position = UDim2.fromOffset(10, y); nm.Size = UDim2.new(1, -20, 0, 13)
                    local d = T(notes, node.Desc or "", 10, Color3.fromRGB(150, 158, 175))
                    d.Position = UDim2.fromOffset(10, y + 13); d.Size = UDim2.new(1, -20, 0, 40)
                    if node.Sig then d.Size = UDim2.new(1, -20, 0, 80); y += 38 end -- (CLASS BUILDS) SIGNATURE: its longer text
                    y += 56
                end
            end
            notes.CanvasSize = UDim2.fromOffset(0, y)
            local btn = Instance.new("TextButton")
            btn.Name = "Choose"; btn.Size = UDim2.new(1, -20, 0, 32); btn.Position = UDim2.new(0, 10, 1, -42)
            btn.Font = Enum.Font.GothamBold; btn.TextSize = 12; btn.TextColor3 = Color3.new(1, 1, 1); btn.ZIndex = 33; btn.Parent = card
            local mine = clientState.Ascendancy == a.Id
            btn.BackgroundColor3 = mine and Color3.fromRGB(50, 50, 60) or a.Color:Lerp(Color3.new(0, 0, 0), 0.5)
            btn.Text = mine and "CURRENT: OPEN" or (total <= 0 and "LOCKED: CLEAR A BOSS TRIAL")
                or (clientState.Ascendancy and (armed == a.Id and "CLICK AGAIN: SPEND 1 SHARD" or "SWITCH (1 REBIRTH SHARD)") or "CHOOSE")
            btn.MouseButton1Click:Connect(function()
                SoundHelper.Play("Click")
                if mine then browsing = false; Refresh(); return end
                if clientState.Ascendancy and armed ~= a.Id then
                    armed = a.Id; Refresh()
                    task.delay(3, function() if armed == a.Id then armed = nil; Refresh() end end)
                    return
                end
                armed = nil
                Act("Choose", a.Id)
                browsing = false
            end)
        end
    end

    -- ----- the mini-tree of your ascendancy -----
    local function NodeState(node: any): string
        local has = table.find(clientState.AscNodes or {}, node.Id) ~= nil
        if has then return "Alloc" end
        local spent, total = Points()
        if node.Parent and table.find(clientState.AscNodes or {}, node.Parent) and spent < total then return "Open" end
        return "Locked"
    end
    local function Tip(node: any, a: any)
        local lines = { { Text = node.Name, Bold = true, Size = 15, Color = a.Color },
            { Text = (node.Type == "Notable" and "Notable" or node.Type == "Small" and "Small" or "Specialization start") .. "  •  " .. a.Name, Size = 12, Color = Color3.fromRGB(150, 160, 180) },
            { Sep = true } }
        if node.Sig then table.insert(lines, #lines, { Text = "SIGNATURE  •  " .. string.upper(node.Build or a.Build or "") .. " BUILD  (only " .. a.Name .. " has it)", Size = 12, Bold = true, Color = Color3.fromRGB(255, 214, 110) }) end -- (CLASS BUILDS) SIGNATURE
        if node.Desc then table.insert(lines, { Text = node.Desc, Color = Color3.fromRGB(150, 205, 255) }) end
        if node.Type == "Small" then
            local keys = {}
            for k in pairs(node.Stats) do table.insert(keys, k) end
            table.sort(keys)
            for _, l in ipairs(UI.TreeStatLines(node.Stats, table.find(clientState.AscNodes or {}, node.Id) ~= nil)) do
                table.insert(lines, { Text = l, Color = Color3.fromRGB(150, 205, 255) })
            end
        end
        if node.Type == "AscStart" then table.insert(lines, { Text = a.Blurb, Color = Color3.fromRGB(200, 205, 220) }) end
        local s = NodeState(node)
        table.insert(lines, { Sep = true })
        local touch = GameSettings.TouchOnly()
        if node.Type == "AscStart" then
            table.insert(lines, { Text = "Your specialization's start", Color = Color3.fromRGB(150, 150, 170), Size = 12 })
        elseif s == "Alloc" then
            table.insert(lines, { Text = touch and "Tap again to refund" or "Right-click to refund", Color = Color3.fromRGB(255, 170, 120), Size = 12 })
        elseif s == "Open" then
            table.insert(lines, { Text = touch and "Tap again to allocate" or "Click to allocate (1 point)", Color = Color3.fromRGB(120, 255, 140), Size = 12 })
        else
            local spent, total = Points()
            table.insert(lines, { Text = (spent >= total) and "No points left: clear the next Proving (Challenges)" or "Allocate the node before it first", Color = Color3.fromRGB(150, 150, 170), Size = 12 })
        end
        if UI.ShowTooltip then UI.ShowTooltip(a.Color, lines) end
    end
    local function BuildTree(a: any)
        for _, c in ipairs(treeView:GetChildren()) do c:Destroy() end
        nodeUi = {}
        local cx, cy = W / 2, (H - 76) / 2 - 22
        local pos: { [string]: Vector2 } = {}
        local order: { any } = {}
        for _, id in ipairs(a.Nodes or {}) do
            local n = AscendancyData.Nodes[id]
            if n then
                pos[id] = Vector2.new(cx + (n.X or 0) * 1.15, cy + (n.Y or 0))
                table.insert(order, { Slot = n.Slot, Type = n.Type, Parent = n.Parent and AscendancyData.Nodes[n.Parent] and AscendancyData.Nodes[n.Parent].Slot, Id = id })
            end
        end
        local pre = "ASC_" .. string.upper(a.Id) .. "_"
        for _, L in ipairs(order) do
            if L.Parent then
                local p1, p2 = pos[pre .. L.Parent], pos[pre .. L.Slot]
                local d = p2 - p1
                local line = Instance.new("Frame")
                line.Name = "L_" .. L.Slot; line.BorderSizePixel = 0; line.AnchorPoint = Vector2.new(0.5, 0.5)
                line.Size = UDim2.fromOffset(d.Magnitude, 3); line.Position = UDim2.fromOffset((p1.X + p2.X) / 2, (p1.Y + p2.Y) / 2)
                line.Rotation = math.deg(math.atan2(d.Y, d.X)); line.ZIndex = 32; line.Parent = treeView
            end
        end
        for _, L in ipairs(order) do
            local id = L.Id
            local node = AscendancyData.Nodes[id]
            local px = PX[L.Type] or 24
            if node and node.Sig then px += 8 end -- (CLASS BUILDS) SIGNATURE: the signature node stands out
            local btn = Instance.new("ImageButton")
            btn.Name = "N_" .. L.Slot; btn.BackgroundTransparency = 1; btn.AutoButtonColor = false; btn.Image = ""
            btn.Size = UDim2.fromOffset(px + 8, px + 8); btn.AnchorPoint = Vector2.new(0.5, 0.5); btn.Position = UDim2.fromOffset(pos[id].X, pos[id].Y)
            btn.ZIndex = 34; btn.Parent = treeView
            local fill = Instance.new("ImageLabel")
            fill.BackgroundTransparency = 1; fill.Image = DISC; fill.Size = UDim2.fromOffset(px, px); fill.AnchorPoint = Vector2.new(0.5, 0.5)
            fill.Position = UDim2.fromScale(0.5, 0.5); fill.ZIndex = 34; fill.Parent = btn
            local ring = Instance.new("ImageLabel")
            ring.BackgroundTransparency = 1; ring.Image = RING; ring.Size = UDim2.fromOffset(px + 6, px + 6); ring.AnchorPoint = Vector2.new(0.5, 0.5)
            ring.Position = UDim2.fromScale(0.5, 0.5); ring.ZIndex = 35; ring.Parent = btn
            if L.Type ~= "Small" then
                local lab = T(treeView, L.Type == "AscStart" and string.upper(a.Name) or node.Name, L.Type == "AscStart" and 14 or 11,
                    a.Color:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
                lab.Size = UDim2.fromOffset(130, 28); lab.AnchorPoint = Vector2.new(0.5, 0)
                lab.Position = UDim2.fromOffset(pos[id].X, pos[id].Y + px / 2 + 3); lab.ZIndex = 33
                if node.Sig then lab.Text = node.Name .. "\nSIGNATURE"; lab.TextColor3 = Color3.fromRGB(255, 214, 110) end -- (CLASS BUILDS) SIGNATURE
            end
            btn.MouseEnter:Connect(function() if not GameSettings.TouchOnly() then Tip(node, a) end end)
            btn.MouseLeave:Connect(function() if not GameSettings.TouchOnly() and UI.HideTooltip then UI.HideTooltip() end end)
            btn.MouseButton1Click:Connect(function()
                if GameSettings.TouchOnly() and touchSel ~= id then touchSel = id; Tip(node, a); return end
                touchSel = nil
                local s = NodeState(node)
                if s == "Alloc" and GameSettings.TouchOnly() then Act("Refund", id)
                elseif s == "Open" then Act("Allocate", id)
                elseif s == "Locked" and node.Type ~= "AscStart" then Tip(node, a) end
            end)
            btn.MouseButton2Click:Connect(function()
                if NodeState(node) == "Alloc" and node.Type ~= "AscStart" then Act("Refund", id) end
            end)
            nodeUi[id] = { Fill = fill, Ring = ring, Btn = btn }
        end
        builtFor = a.Id
    end
    local function StyleTree(a: any)
        local pre = "ASC_" .. string.upper(a.Id) .. "_"
        for id, ui in pairs(nodeUi) do
            local node = AscendancyData.Nodes[id]
            local s = NodeState(node)
            if s == "Alloc" then
                ui.Fill.ImageColor3 = a.Color; ui.Ring.ImageColor3 = Color3.new(1, 1, 1)
            elseif s == "Open" then
                ui.Fill.ImageColor3 = a.Color:Lerp(Color3.new(0, 0, 0), 0.65); ui.Ring.ImageColor3 = a.Color
            else
                ui.Fill.ImageColor3 = Color3.fromRGB(24, 24, 32); ui.Ring.ImageColor3 = a.Color:Lerp(Color3.fromRGB(40, 45, 60), 0.6)
            end
            local line = node.Parent and treeView:FindFirstChild("L_" .. node.Slot)
            if line then
                local on = s == "Alloc"
                line.BackgroundColor3 = on and a.Color or Color3.fromRGB(45, 48, 62)
                line.Size = UDim2.fromOffset(line.Size.X.Offset, on and 4 or 3)
            end
        end
        local _ = pre
    end

    Refresh = function()
        local spent, total = Points()
        local a = clientState.Ascendancy and AscendancyData.ById[clientState.Ascendancy]
        -- the tree window's button
        ascBtn.Visible = clientState.Class ~= nil
        ascBtn.Text = a and string.format("%s  %d / %d", string.upper(a.Name), spent, total) or string.format("SPECIALIZATION  (%d POINT%s)", total, total == 1 and "" or "S")
        ascBtn.BackgroundColor3 = (total > spent) and Color3.fromRGB(110, 70, 20) or Color3.fromRGB(45, 35, 25)
        if not panel.Visible then return end
        local showCards = browsing or not a
        cardsView.Visible = showCards
        treeView.Visible = not showCards
        switchBtn.Visible = a ~= nil
        switchBtn.Text = showCards and "BACK TO MY SPECIALIZATION" or "OTHER SPECIALIZATIONS"
        local pointsLine = string.format("%d / %d specialization points  •  2 per Proving cleared (Challenges > PROVING), up to 8.", spent, total)
        if showCards then
            title.Text = string.upper(clientState.Class or "") .. " SPECIALIZATIONS"
            sub.Text = (a and "Switching costs 1 Rebirth Shard and refunds your specialization points. " or "Choose one: the choice is free. ") .. pointsLine
            BuildCards()
        else
            title.Text = "SPECIALIZATION  •  " .. string.upper(a.Name)
            title.TextColor3 = a.Color
            sub.Text = pointsLine .. "  Click a glowing node to allocate; right-click to refund."
            if builtFor ~= a.Id then BuildTree(a) end
            StyleTree(a)
        end
        if not a then title.TextColor3 = Color3.fromRGB(255, 220, 140) end
    end
    UI.RefreshAsc = Refresh
    ascBtn.MouseButton1Click:Connect(function()
        SoundHelper.Play("Click")
        panel.Visible = not panel.Visible
        browsing = false; armed = nil
        Refresh()
    end)
    closeBtn.MouseButton1Click:Connect(function() panel.Visible = false; if UI.HideTooltip then UI.HideTooltip() end end)
    switchBtn.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); browsing = not browsing; armed = nil; Refresh() end)
    tf:GetPropertyChangedSignal("Visible"):Connect(function() if not tf.Visible then panel.Visible = false end end)
    Refresh()
end)()

;(function()
    -- CLASS PICKER (tree v4, 2026-10-05). Owner: "Players can pick on join and change at the monolith ... To change
    -- classes, lets add a rare currency that either drops or can be bought with robux".
    --   * first join (no class yet): pops up once the welcome guide is closed; the first pick is free
    --   * CHANGE CLASS (tree window side panel, at the Skill Monolith): costs 1 Rebirth Shard, refunds tree + gems
    local ClassData = require(sharedFolder:WaitForChild("ClassData"))
    local CARD_W, CARD_H, GAP = 214, 236, 10
    local PER_ROW = 5 -- (five weapon classes: one row)
    local ROWS = math.max(1, math.ceil(#ClassData.List / PER_ROW)) -- (more classes = more rows; the panel fits the screen)
    local frame = Instance.new("Frame")
    frame.Name = "ClassPicker"
    frame.Size = UDim2.new(0, CARD_W * PER_ROW + GAP * (PER_ROW + 1), 0, 48 + CARD_H * ROWS + GAP * (ROWS + 1) + 58)
    frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(14, 17, 24); frame.BorderSizePixel = 0; frame.Visible = false
    frame.Parent = UI.menuFolder
    ApplyPanelChrome(frame, Color3.fromRGB(150, 230, 255), 12)
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 42); header.BackgroundColor3 = Color3.fromRGB(24, 30, 42); header.Font = Enum.Font.GothamBold
    header.TextSize = 20; header.TextColor3 = Color3.fromRGB(150, 230, 255); header.Text = "CHOOSE YOUR CLASS"; header.Parent = frame
    UI.windowHeaders = UI.windowHeaders or {}; UI.windowHeaders[frame] = header
    -- (Update 5: built after the window-skin pass ran, so it never got its title bar -- skin it here; you can close it
    -- and pick later from the skill tree's CHOOSE YOUR CLASS button)
    UIStyle.SkinWindow(frame, header, function() CloseAllMenus() end)
    frame.ZIndex = math.max(frame.ZIndex, UIStyle.Z.Window)

    local changing = false
    local armed: string? = nil
    local busy = false
    local cards: { [string]: { Btn: TextButton, Card: Frame } } = {}
    local Refresh: () -> ()

    local function StartLines(c: any): string
        local node = SkillTreeData[c.Start]
        local parts = {}
        local keys = {}
        for k in pairs(node and node.Stats or {}) do table.insert(keys, k) end
        table.sort(keys)
        for _, k in ipairs(keys) do table.insert(parts, ItemData.FormatStat(k, node.Stats[k])) end
        return "Start: " .. table.concat(parts, ", ")
    end
    local function Label(parent: Instance, y: number, h: number, text: string, size: number, color: Color3, font: Enum.Font?): TextLabel
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1; l.Position = UDim2.new(0, 10, 0, y); l.Size = UDim2.new(1, -20, 0, h)
        l.Font = font or Enum.Font.GothamMedium; l.TextSize = size; l.TextColor3 = color; l.TextWrapped = true
        l.TextXAlignment = Enum.TextXAlignment.Left; l.TextYAlignment = Enum.TextYAlignment.Top; l.Text = text; l.Parent = parent
        return l
    end
    local function Choose(c: any)
        if busy then return end
        if changing and armed ~= c.Id then
            armed = c.Id
            Refresh()
            task.delay(3, function() if armed == c.Id then armed = nil; Refresh() end end)
            return
        end
        armed = nil
        busy = true
        local ok, msg = Remotes.GetFunction("ChooseClass"):InvokeServer(c.Id)
        busy = false
        ShowToast(msg or (ok and ("You are now a " .. c.Id .. ".") or "Can't pick that."))
        if ok then
            SoundHelper.Play("Upgrade")
            if frame.Visible then CloseAllMenus() end
        end
        Refresh()
    end
    for i, c in ipairs(ClassData.List) do
        local row, col = math.floor((i - 1) / PER_ROW), (i - 1) % PER_ROW
        local inRow = math.min(PER_ROW, #ClassData.List - row * PER_ROW)
        local rowOffset = (PER_ROW - inRow) * (CARD_W + GAP) / 2 -- (a short last row is centred)
        local card = Instance.new("Frame")
        card.Name = c.Id
        card.Size = UDim2.fromOffset(CARD_W, CARD_H)
        card.Position = UDim2.fromOffset(GAP + rowOffset + col * (CARD_W + GAP), 48 + GAP + row * (CARD_H + GAP))
        card.BackgroundColor3 = UIStyle.Colors.Bg1; card.BorderSizePixel = 0; card:SetAttribute("Skinned", true); card.Parent = frame
        RoundCorners(card, 8)
        -- (UI v4: a quiet edge in the class colour that lights up with a soft halo when the pointer is on the card)
        local stroke = Instance.new("UIStroke"); stroke.Color = c.Color; stroke.Thickness = 1; stroke.Transparency = 0.6; stroke.Parent = card
        do
            local halo = UIStyle.Glow(card, c.Color, 10)
            card.MouseEnter:Connect(function() UIStyle.GlowTo(halo, true, 0.4); UIStyle.Motion.Tween(stroke, 0.12, { Transparency = 0 }) end)
            card.MouseLeave:Connect(function() UIStyle.GlowTo(halo, false); UIStyle.Motion.Tween(stroke, 0.12, { Transparency = 0.6 }) end)
        end
        -- (0.53: the class's Mega-City icon instead of an emoji)
        local nameLbl = Label(card, 8, 26, string.upper(c.Id), 19, c.Color, Enum.Font.GothamBlack)
        if nameLbl then nameLbl:SetAttribute("NoRarityDrift", true) end
        if UIStyle.HasIcon(c.IconKey) then
            UIStyle.Icon(c.IconKey, { Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(28, 28), ImageColor3 = c.Color, Parent = card })
            if nameLbl then nameLbl.Position = UDim2.new(nameLbl.Position.X.Scale, nameLbl.Position.X.Offset + 34, nameLbl.Position.Y.Scale, nameLbl.Position.Y.Offset) end
        else
            if nameLbl then nameLbl.Text = string.upper(c.Id) end
        end
        Label(card, 36, 16, c.Role .. "  •  " .. (c.Attribute == "All" and "every attribute" or c.Attribute), 12, c.Color:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Font.GothamBold)
        -- (PLAYTEST 2026-10-31: the Marksman blurb ran past its 3 lines and was cut mid-sentence -- the two text blocks
        -- step their text size down (to 9 at least) until they fit their box; TextScaled read worse under the HUD scale)
        for _, l in ipairs({ Label(card, 56, 46, c.Blurb, 12, Color3.fromRGB(225, 230, 240)), Label(card, 104, 46, c.Playstyle, 11, Color3.fromRGB(150, 160, 180)) }) do
            local mx = l.TextSize
            local function Fit() -- (from the full size down, only once it has a real size: a 0-size label never fits)
                if l.AbsoluteSize.X < 2 then return end
                l.TextSize = mx
                while not l.TextFits and l.TextSize > 9 do l.TextSize -= 1 end
            end
            l:GetPropertyChangedSignal("AbsoluteSize"):Connect(Fit)
            l:GetPropertyChangedSignal("FontFace"):Connect(Fit)
            task.defer(Fit)
        end
        Label(card, 152, 32, StartLines(c), 11, Color3.fromRGB(150, 205, 255), Enum.Font.GothamBold)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -20, 0, 34); btn.Position = UDim2.new(0, 10, 1, -44)
        btn.BackgroundColor3 = c.Color:Lerp(Color3.new(0, 0, 0), 0.45); btn.Font = Enum.Font.GothamBold; btn.TextSize = 14
        btn.TextColor3 = Color3.new(1, 1, 1); btn.Text = "CHOOSE"; btn.Parent = card
        RoundCorners(btn, 6)
        btn.MouseButton1Click:Connect(function() SoundHelper.Play("Click"); Choose(c) end)
        cards[c.Id] = { Btn = btn, Card = card }
    end
    local footer = Instance.new("TextLabel")
    footer.BackgroundTransparency = 1; footer.Size = UDim2.new(1, -230, 0, 40); footer.Position = UDim2.new(0, 14, 1, -50)
    footer.Font = Enum.Font.GothamMedium; footer.TextSize = 13; footer.TextColor3 = Color3.fromRGB(190, 200, 215); footer.TextWrapped = true
    footer.TextXAlignment = Enum.TextXAlignment.Left; footer.Parent = frame
    local buyBtn = Instance.new("TextButton")
    buyBtn.Name = "BuyShard"
    buyBtn.Size = UDim2.new(0, 200, 0, 36); buyBtn.Position = UDim2.new(1, -214, 1, -48)
    buyBtn.BackgroundColor3 = Color3.fromRGB(40, 110, 140); buyBtn.Font = Enum.Font.GothamBold; buyBtn.TextSize = 13
    buyBtn.TextColor3 = Color3.new(1, 1, 1); buyBtn.Parent = frame
    RoundCorners(buyBtn, 6)
    buyBtn.MouseButton1Click:Connect(function()
        SoundHelper.Play("Click")
        -- (2026-10-20: BOUND points, behind the popup that shows how many you need)
        require(sharedFolder:WaitForChild("BoundShop")).Confirm({ Name = "a Rebirth Shard", Price = ItemData.RebirthShardProduct.Price or 99,
            Desc = "Changes your class.", OnBuy = function() return Remotes.GetFunction("BoundBuy"):InvokeServer("RebirthShard") end })
    end)

    Refresh = function()
        local shards = (clientState.Materials or {}).RebirthShard or 0
        changing = clientState.Class ~= nil
        header.Text = changing and "CHANGE CLASS" or "CHOOSE YOUR CLASS"
        buyBtn.Visible = changing
        buyBtn.Text = string.format("BUY REBIRTH SHARD  (%d BOUND)", ItemData.RebirthShardProduct.Price or 99)
        footer.Text = changing
            and string.format("Changing class costs 1 Rebirth Shard. You have %d. Your passive tree, gems and specialization are refunded. Every boss has a 5%% chance to drop one.", shards)
            or "Your class decides where your passive tree starts. You can still path anywhere. The first pick is free; change it later at the Skill Tree with a Rebirth Shard."
        for id, e in pairs(cards) do
            local mine = clientState.Class == id
            e.Btn.AutoButtonColor = not mine
            e.Btn.Text = mine and "CURRENT CLASS" or (armed == id and "CLICK AGAIN: SPEND 1 SHARD" or (changing and "CHANGE TO THIS" or "CHOOSE"))
            e.Btn.BackgroundTransparency = mine and 0.6 or 0
        end
    end
    UI.RefreshClassPicker = function() if frame.Visible then Refresh() end end
    UI.OpenClassPicker = function()
        armed = nil
        Refresh()
        if not frame.Visible then OpenMenuFrame(frame) end
    end

    -- (0.93, owner: "players shouldn't have to choose a class on spawn, they should be able to choose at the skill tree
    -- when desired instead of being forced without any game knowledge"): no pop-up on join any more -- the skill tree shows
    -- a CHOOSE YOUR CLASS prompt until you pick (the first pick is still free)
    if false then task.spawn(function()
        task.wait(4) -- (after the welcome guide's own pop-up, 3 s after spawning)
        local t0 = os.clock()
        while os.clock() - t0 < 600 do
            task.wait(0.5)
            if UI.stateLoaded and clientState.Class ~= nil then return end
            local rt = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local inHub = rt ~= nil and rt.Position.Z < 450 -- (never mid-fight: solo dungeons have no RunId)
            if UI.stateLoaded and clientState.Class == nil and not isAnyMenuOpen and not LocalPlayer:GetAttribute("RunId") and inHub then
                UI.OpenClassPicker()
                return
            end
        end
    end) end
end)()

-- Rare cosmetic drop (glove / sleeve / weapon finish). Big, unmissable banner: these are <1% / few-% drops.
Remotes.GetEvent("CosmeticDrop").OnClientEvent:Connect(function(info)
    if type(info) ~= "table" then return end
    local catalog = (info.Kind == "Glove" and ItemData.Gloves) or (info.Kind == "Sleeve" and ItemData.ArmSkins) or ItemData.WeaponSkins
    local data = catalog[info.Id] or ItemData.Gloves[info.Id] or ItemData.ArmSkins[info.Id] or ItemData.WeaponSkins[info.Id]
    local name = info.Name or (data and data.Name) or tostring(info.Id)
    local rarity = info.Rarity or (data and data.Rarity) or "Rare"
    SoundHelper.Play("Victory")
    local banner = Instance.new("TextLabel")
    banner.Name = "CosmeticDropBanner"
    banner.Size = UDim2.new(0, 560, 0, 64)
    banner.AnchorPoint = Vector2.new(0.5, 0)
    banner.Position = UDim2.new(0.5, 0, 0, 120)
    banner.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
    banner.BackgroundTransparency = 0.1
    banner.Font = Enum.Font.GothamBlack
    banner.TextSize = 20
    banner.TextColor3 = ItemData.RarityColors[rarity] or Color3.new(1, 1, 1)
    banner.TextWrapped = true
    banner.ZIndex = 40
    if info.Kind == "Avatar" then
        banner.Text = "◆ COSMETIC FOUND ◆\n" .. name .. "  [" .. rarity:upper() .. "]. Equip it in COSMETICS [H]"
    elseif info.Kind == "Duplicate" then
        banner.Text = "◆ RARE DROP (DUPLICATE) ◆\n" .. name .. " → +" .. tostring(info.Shards or 0) .. " Shards"
    else
        banner.Text = "◆ RARE COSMETIC DROP ◆\n" .. name .. "  [" .. rarity:upper() .. "]. Equip it in MENU > COSMETICS"
    end
    banner.Parent = hudGui
    RoundCorners(banner, 10)
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Thickness = 2
    stroke.Color = banner.TextColor3
    stroke.Parent = banner
    task.delay(6, function() banner:Destroy() end)
end)

Remotes.GetEvent("LootAnnounce").OnClientEvent:Connect(function(item: any, comp: any, wasAutoSold: boolean?)
    -- (2026-10-23, owner: "SLIM LINE ONLY": the old stats card / upgrade card are gone from the drop + pickup flow -- every item
    -- that reaches the bag gets one coloured line (GroundLoot.Toast); stats live in the bag)
    local GL = require(sharedFolder:WaitForChild("GroundLoot"))
    local kind = (item.Kind == "Gem") and "Gem" or (item.Slot and "Gear" or "Weapon")
    if wasAutoSold then -- (0.72: silent; a line only for Rare+ so a loot stream of commons doesn't churn the stack)
        if (ItemData.RarityRank[item.Rarity] or 1) >= ItemData.RarityRank.Rare then GL.Toast(item, kind, "sold") end
    else
        GL.AnnounceSound(item) -- (0.72: relative to the difficulty)
        if item.Kind == "Gem" then
            clientState.Gems = clientState.Gems or {}
            table.insert(clientState.Gems, item)
        elseif item.Slot then
            table.insert(clientState.GearInventory, item)
        else
            table.insert(clientState.Inventory, item)
        end
        local grp = require(sharedFolder:WaitForChild("ClassData")).GroupOf(clientState.Class)
        local better = kind == "Weapon" and comp and comp.IsBetter and not (grp and ItemData.WeaponGroupOf(item) ~= grp)
        GL.Toast(item, kind, better and "upgrade" or "bag")
    end
    if UI.invFrame.Visible then RefreshInventory() end
end)

Remotes.GetEvent("DungeonVictory").OnClientEvent:Connect(function(diff, floor)
    SoundHelper.Play("Victory")
    UI.victoryBanner.Visible = true
    UI.victoryToken = (UI.victoryToken or 0) + 1
    ShowToast("DUNGEON VICTORY! Completed " .. tostring(diff) .. " mode (floor " .. tostring(floor) .. "). Loot the vault, then take the gold portal home")
    if UI.RunAgain then UI.RunAgain.RefreshBanner() end -- (QOL F1: RUN AGAIN on the banner)
    -- (owner 2026-10-04: "have the players cursor automatically pop up ... to choose keep looting or back to hub")
    -- the cursor comes up and the popup waits for KEEP LOOTING (locks the cursor again) or RETURN TO HUB / [J]
    SetMouseLocked(false)
end)

Remotes.GetEvent("MeleeSlash").OnClientEvent:Connect(function()
    SoundHelper.Play("Melee")
end)

Remotes.GetEvent("DungeonUpdate").OnClientEvent:Connect(function(data)
    -- a run started (solo, party, daily, rift) while an Aim Trial was running: end the trial where you are
    if UI.TrialRunner and UI.TrialRunner.IsRunning() then UI.TrialRunner.Abort("dungeon") end
    currentRaidBiome = data.Biome
    currentRaidDiff = data.Difficulty
    currentRaidFloor = data.Floor
    if data.Endless ~= nil then UI.runEndless = data.Endless == true end -- (DungeonClient.OnFloorBuilt sets it for every run)
    -- (owner 0.49: "sometimes when spawning into a dungeon, the dungeon start menu still is on your screen": the hub gate
    -- re-fires its menu while you stand in it during the floor load -> arriving on a floor closes the hub run windows)
    UI.noGateUntil = os.clock() + 4
    for _, f in ipairs({ UI.dungFrame, UI.challFrame, UI.runSummary }) do if f and f.Visible then CloseAllMenus(); break end end

    UI.raidBanner.Visible = true
    local bt = DungeonGeneratorShared.BIOME_TITLES[data.Biome]
    -- (Update 5: plain words, one separator -- it read "[CYBER - EASY] ARENA FLOOR 2 | FOES: 4")
    UI.raidLabel.Text = string.upper(bt and bt.Name or data.Biome) .. "   •   " .. (UI.runEndless and "ENDLESS " or "") .. data.Difficulty:upper() .. "   •   FLOOR " .. data.Floor
        .. "   •   " .. data.Remaining .. (data.Remaining == 1 and " ENEMY LEFT" or " ENEMIES LEFT")
    -- MIXED RUNS: every floor is a new biome -- a title card names it as you arrive (once per floor; not in trials)
    if (data.Revisit or 0) > 0 then -- BACK PORTAL: you're on the floor behind you
        UI.raidLabel.Text = "◀ BACK ON FLOOR " .. data.Floor .. ": grab your loot, then take the blue portal back to floor " .. data.Revisit
        nextFloorReady = false
        return
    end
    local cardKey = tostring(data.Biome) .. "|" .. tostring(data.Floor) .. "|" .. tostring(data.Difficulty)
    if bt and not data.Trial and data.Remaining > 0 and UI.biomeCardKey ~= cardKey then
        UI.biomeCardKey = cardKey
        if not UI.biomeCard then
            local card = Instance.new("Frame")
            card.Name = "BiomeCard"; card.AnchorPoint = Vector2.new(0.5, 0.5); card.Position = UDim2.fromScale(0.5, 0.3)
            -- (owner 2026-10-07: "Biome text on dungeon screen runs out of bounds": the card is a share of the screen and its
            -- text shrinks to fit -- long biome names / matchup lines at 56 px ran off narrow screens)
            card.Size = UDim2.new(0.86, 0, 0, 110); card.BackgroundTransparency = 1; card:SetAttribute("NoSkin", true); card.Parent = hudGui
            local cap = Instance.new("UISizeConstraint"); cap.MaxSize = Vector2.new(820, 110); cap.Parent = card
            local title = Instance.new("TextLabel")
            title.Name = "Title"; title.Size = UDim2.new(1, 0, 0, 64); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBlack
            title.TextSize = 52; title.TextScaled = true; title.TextStrokeTransparency = 0.6; title:SetAttribute("NoSkin", true); title:SetAttribute("KeepFont", true); title.Parent = card
            title.FontFace = UIStyle.RoleFace("Header") -- (UI CLEAN R-C: display caps in Text; the biome's colour stays on its icon only)
            local tc = Instance.new("UITextSizeConstraint"); tc.MaxTextSize = 52; tc.MinTextSize = 18; tc.Parent = title
            local sub = Instance.new("TextLabel")
            sub.Name = "Sub"; sub.Position = UDim2.fromOffset(0, 66); sub.Size = UDim2.new(1, 0, 0, 26); sub.BackgroundTransparency = 1
            sub.Font = Enum.Font.GothamBold; sub.TextSize = 18; sub.TextScaled = true; sub.TextColor3 = UIStyle.Colors.Text; sub.TextStrokeTransparency = 0.6
            sub:SetAttribute("TypeRole", "Label")
            local sc2 = Instance.new("UITextSizeConstraint"); sc2.MaxTextSize = 20; sc2.MinTextSize = 10; sc2.Parent = sub
            sub:SetAttribute("NoSkin", true); sub.Parent = card
            local ic = Instance.new("ImageLabel") -- (0.53: the biome's Mega-City icon over its name)
            ic.Name = "Icon"; ic.AnchorPoint = Vector2.new(0.5, 1); ic.Position = UDim2.new(0.5, 0, 0, -4); ic.Size = UDim2.fromOffset(58, 58)
            ic.BackgroundTransparency = 1; ic.ScaleType = Enum.ScaleType.Fit; ic:SetAttribute("NoSkin", true); ic.Parent = card
            UI.biomeCard = card
        end
        local card = UI.biomeCard
        card.Title.Text = string.upper(bt.Name)
        card.Title.TextColor3 = UIStyle.Colors.Text
        card.Icon.Image = UIStyle.Icons["b_" .. string.lower(tostring(data.Biome))] or ""
        card.Icon.ImageColor3 = bt.Color
        card.Icon.ImageTransparency = 1
        TweenService:Create(card.Icon, TweenInfo.new(0.35), { ImageTransparency = 0 }):Play()
        do -- (elemental matchups: what this biome's enemies are weak to / resist)
            local aff = ItemData.ENEMY_AFFINITY[ItemData.ELEMENT_OF_BIOME[data.Biome] or ""]
            -- (0.86 BIOME MOODS: the floor's mood by name, when it has one -- the folder of THIS floor only)
            local moodTxt = ""
            local myRun = LocalPlayer:GetAttribute("RunId")
            local pr = Workspace:FindFirstChild("PartyRuns")
            local dg = (myRun and pr and pr:FindFirstChild("Run_" .. myRun)) or Workspace:FindFirstChild("DungeonFacility")
            local mn = dg and dg:GetAttribute("Floor") == data.Floor and dg:GetAttribute("MoodName")
            if mn and mn ~= "" then moodTxt = "  •  " .. string.upper(mn) end
            -- (UPDATE 8 OFFENSE: the biome's damage-type resistances, DamageTypes.ENEMY_RES)
            local DTc = require(sharedFolder:WaitForChild("DamageTypes"))
            local row = DTc.ENEMY_RES[ItemData.ELEMENT_OF_BIOME[data.Biome] or ""]
            local resTxt = ""
            if row then
                for _, t in ipairs(DTc.ORDER) do
                    local v = row[t]
                    if v and v > 0 then resTxt ..= "  •  RESISTS " .. string.upper(DTc.LABEL[t]) end
                end
                for _, t in ipairs(DTc.ORDER) do
                    local v = row[t]
                    if v and v < 0 then resTxt ..= "  •  WEAK TO " .. string.upper(DTc.LABEL[t]) end
                end
            end
            local _ = aff
            card.Sub.Text = "FLOOR " .. data.Floor .. moodTxt .. resTxt
        end
        card.Visible = true
        UI.biomeCardToken = (UI.biomeCardToken or 0) + 1
        local token = UI.biomeCardToken
        for _, l in ipairs({ card.Title, card.Sub }) do l.TextTransparency = 1; l.TextStrokeTransparency = 1 end
        for _, l in ipairs({ card.Title, card.Sub }) do
            TweenService:Create(l, TweenInfo.new(0.35), { TextTransparency = 0, TextStrokeTransparency = 0.6 }):Play()
        end
        task.delay(2.4, function()
            if UI.biomeCardToken ~= token then return end
            for _, l in ipairs({ card.Title, card.Sub }) do
                TweenService:Create(l, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
            end
            TweenService:Create(card.Icon, TweenInfo.new(0.8), { ImageTransparency = 1 }):Play()
        end)
    end
    -- Boss Trials: the banner names the fight (later updates of the same floor keep it)
    if data.Trial then UI.trialBanner = data.Trial elseif data.Floor ~= 5 then UI.trialBanner = nil end
    if UI.trialBanner then
        UI.raidLabel.Text = (data.Remaining == 0) and ("TRIAL CLEARED: " .. UI.trialBanner .. ". Loot up, then take the gold portal home") or ("BOSS TRIAL   •   " .. UI.trialBanner)
    end
    if data.Remaining == 0 and UI.trialBanner then
        SoundHelper.Play("Victory")
    elseif data.Remaining == 0 then
        UI.raidLabel.Text = "FLOOR CLEARED   •   loot the chest, then press " .. KeyTag("Interact") .. " at the portal"
        nextFloorReady = true
        SoundHelper.Play("Victory")
        -- Cursor stays LOCKED: the portal is entered with [E] and exit is [J], so there's nothing that
        -- needs clicking. (Unlocking here is what left the cursor stuck on screen after every clear.)
    else
        nextFloorReady = false
        -- A new wave just started -- re-lock the cursor for aiming, unless a menu is open over it.
        if not isAnyMenuOpen and isCursorUnlocked then SetMouseLocked(true) end
    end
end)

Remotes.GetEvent("TeleportPlayer").OnClientEvent:Connect(function(dest, cf)
    if UI.TrialRunner and UI.TrialRunner.IsRunning() then UI.TrialRunner.Abort(dest == "Hub" and "quit" or "dungeon") end
    if dest == "PartyDungeon" and typeof(cf) == "CFrame" then
        TeleportClient(cf)
        if not isAnyMenuOpen then SetMouseLocked(true) end
        return
    end
    if dest == "Goto" and typeof(cf) == "CFrame" then -- (0.55: the Bazaar gate, hideout doors)
        CloseAllMenus()
        if UI.hideout and UI.hideout.Prepare then pcall(UI.hideout.Prepare, cf) end
        TeleportClient(cf)
        return
    end
    if dest == "Hub" then
        TeleportClient(CFrame.lookAt(Vector3.new(0, 7.2, 24), Vector3.new(0, 7.2, 0))) -- (feet on the street: its top is y 4)
        UI.raidBanner.Visible = false
        UI.victoryBanner.Visible = false
        if not isAnyMenuOpen then SetMouseLocked(true) end
    else
        TeleportClient(CFrame.new(0, 7, 550))
        if not isAnyMenuOpen then SetMouseLocked(true) end
    end
end)

-- ==================== LIVES: hearts, out-of-lives revive screen, party spectating ====================
-- Server side: CombatServer "LIVES" block (attributes Lives / Revives / Downed / DownedUntil / Spectating).
-- (its own function: the main chunk is at Luau's 200-local limit)
;(function()
    local MarketplaceService = game:GetService("MarketplaceService")
    local LIVES = ItemData.Lives
    local C = UIStyle.Colors
    UI.HudClean = UI.HudClean or require(sharedFolder:WaitForChild("HudClean")) -- (UI CLEAN: the lives pips)

    -- hearts over the health bar (bottom centre) while in a run
    local hearts = Instance.new("TextLabel")
    hearts.Name = "LivesHearts"
    hearts.BackgroundTransparency = 1
    hearts.AnchorPoint = Vector2.new(1, 1)
    hearts.Size = UDim2.new(0, 160, 0, 19)
    hearts.TextXAlignment = Enum.TextXAlignment.Right
    hearts.Position = UDim2.new(0, UI.HudStack.X + UI.HudStack.W, 1, UI.HudStack.TopY) -- (PhoneHUD / HudClean place it: top right of the health row)
    hearts.Font = Enum.Font.GothamBold
    hearts.TextSize = 13
    hearts.RichText = true -- (UI CLEAN: plain pips -- off-white = a life left, dim = lost; HudClean.Pips)
    hearts.TextColor3 = UIStyle.Colors.Text
    hearts.TextStrokeTransparency = 0.72
    hearts:SetAttribute("TypeRole", "Label")
    hearts:SetAttribute("NoSkin", true)
    hearts.Visible = false
    hearts.Parent = hudGui

    -- the revive screen
    local overlay = Instance.new("Frame")
    overlay.Name = "OutOfLives"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = UIStyle.Colors.Ink -- (UI CLEAN R-C: a dark veil, not a red wash)
    overlay.BackgroundTransparency = 0.4
    overlay.Visible = false
    overlay.ZIndex = 40
    overlay:SetAttribute("NoSkin", true)
    overlay.Parent = hudGui
    local function Lbl(text, size, y, col)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.AnchorPoint = Vector2.new(0.5, 0.5)
        l.Position = UDim2.new(0.5, 0, 0.5, y)
        l.Size = UDim2.new(0, 700, 0, size + 10)
        l.Font = UIStyle.Font or Enum.Font.GothamBlack
        l.TextSize = size
        l.TextColor3 = col
        l.TextStrokeTransparency = 0.2
        l.Text = text
        l.ZIndex = 41
        l.Parent = overlay
        return l
    end
    -- (UI CLEAN R-C: type-led -- the title in display caps Text, the countdown a big display number in Sub, the line under it
    -- Roblox body Sub; REVIVE = the primary (filled accent), GIVE UP = the quiet secondary. No red title, no red / green slabs.)
    local title = Lbl("OUT OF LIVES", 48, -138, UIStyle.Colors.Text)
    local timerLbl = Lbl("", 40, -84, UIStyle.Colors.Sub)
    local infoLbl = Lbl("", 15, 112, UIStyle.Colors.Sub)
    for _, l in ipairs({ title, timerLbl, infoLbl }) do l.TextStrokeTransparency = 1 end
    UI.RunHud.Role(title, "WindowTitle"); title.TextSize = 48
    UI.RunHud.Num(timerLbl, 40, UIStyle.Colors.Sub)
    UI.RunHud.Role(infoLbl, "Body", { Color = "Sub" }); infoLbl.TextSize = 15
    local reviveBtn = UIStyle.Button(overlay, "REVIVE", UIStyle.Colors.Accent, UDim2.fromOffset(300, 52), UDim2.new(0.5, -150, 0.5, -30))
    local giveUpBtn = UIStyle.Button(overlay, "GIVE UP", UIStyle.Colors.Steel, UDim2.fromOffset(300, 44), UDim2.new(0.5, -150, 0.5, 34))
    for _, b in ipairs({ reviveBtn, giveUpBtn }) do
        b.Button.ZIndex = 42
        for _, d in ipairs(b.Button:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex = 43 end end
    end
    do -- (2026-10-13 phones: the words + buttons sit in one centred box that PhoneBoost draws at the phone window scale --
        -- at the HUD's 0.55 the info line was ~10 pt and GIVE UP ~29 pt tall)
        local box = Instance.new("Frame")
        box.Name = "Box"; box.BackgroundTransparency = 1; box.AnchorPoint = Vector2.new(0.5, 0.5)
        box.Position = UDim2.fromScale(0.5, 0.5); box.Size = UDim2.fromOffset(700, 330); box.ZIndex = 41; box.Parent = overlay
        for _, o in ipairs({ title, timerLbl, infoLbl, reviveBtn.Button, giveUpBtn.Button }) do o.Parent = box end
        UIStyle.PhoneBoost(box, 700, 330)
    end
    -- (QOL2 R1 DEATH RECAP) "KILLED BY" + the last hits: a card on a life lost, a panel on this screen (AimRngShared/DeathRecap)
    do -- (a missing module must never stall this block: WaitForChild with a timeout, pcall'd)
        local m = sharedFolder:WaitForChild("DeathRecap", 5)
        local okR, DR = pcall(function() return m and require(m) end)
        if okR and DR then UI.DeathRecap = DR.Init({ Hud = hudGui, Overlay = overlay, Stack = UI.HudStack }) end
    end

    -- spectate bar (party, gave up): who you're watching + a small revive button
    local specBar = Instance.new("Frame")
    specBar.Name = "SpectateBar"
    specBar.AnchorPoint = Vector2.new(0.5, 0)
    specBar.Position = UDim2.new(0.5, 0, 0, 132) -- below the floor banner
    specBar.Size = UDim2.fromOffset(620, 92)
    specBar.Visible = false
    specBar.Parent = hudGui
    UI.RunHud.Plate(specBar, 0.2) -- (UI CLEAN R-C: the run HUD plate, square)
    UIStyle.PhoneBoost(specBar, 620, 92) -- (phones: readable + a tappable REVIVE)
    local specLbl = Instance.new("TextLabel")
    specLbl.BackgroundTransparency = 1
    specLbl.Size = UDim2.new(1, -20, 0, 34)
    specLbl.Position = UDim2.fromOffset(10, 4)
    specLbl.Parent = specBar
    UI.RunHud.Role(specLbl, "SectionHead"); specLbl.TextSize = 17
    local specRevive = UIStyle.Button(specBar, "REVIVE", UIStyle.Colors.Accent, UDim2.fromOffset(240, 40), UDim2.new(0.5, -120, 0, 44))

    local function Teammates(): { Player }
        local out = {}
        local myRun = LocalPlayer:GetAttribute("RunId")
        if not myRun then return out end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p:GetAttribute("RunId") == myRun and not p:GetAttribute("Spectating") and not p:GetAttribute("Downed") then
                table.insert(out, p)
            end
        end
        return out
    end
    -- nobody standing: keep watching a teammate who is down (deciding on a revive) instead of a frozen view
    local function DownedTeammate(): Player?
        local myRun = LocalPlayer:GetAttribute("RunId")
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and myRun and p:GetAttribute("RunId") == myRun and p:GetAttribute("Downed") then return p end
        end
        return nil
    end
    local function NextTarget(step: number)
        local list = Teammates()
        if #list == 0 then spectateTarget = DownedTeammate() return end
        local i = spectateTarget and table.find(list, spectateTarget) or 0
        spectateTarget = list[((i - 1 + step) % #list) + 1]
    end

    -- the price of the next revive (or a stored credit)
    local function ReviveText(): (string, string)
        local credits = clientState.ReviveCredits or 0
        if credits > 0 then return "USE REVIVE (" .. credits .. " LEFT)", "credit" end
        -- (2026-10-20: revives cost BOUND points, through the popup that shows how many you need)
        local step = ItemData.RevivePriceStep(LocalPlayer:GetAttribute("Revives") or 0)
        return "REVIVE  -  " .. tostring(LIVES.Prices[step] or LIVES.Prices[#LIVES.Prices]) .. " BOUND", "bp"
    end
    local function DoRevive()
        local _, how = ReviveText()
        SoundHelper.Play("Click")
        if how == "credit" then
            Remotes.GetEvent("LivesAction"):FireServer("UseCredit")
        elseif how == "studio" then
            Remotes.GetEvent("LivesAction"):FireServer("Revive")
        elseif how == "bp" then
            local step = ItemData.RevivePriceStep(LocalPlayer:GetAttribute("Revives") or 0)
            require(sharedFolder:WaitForChild("BoundShop")).Confirm({ Name = "a revive", Price = LIVES.Prices[step] or LIVES.Prices[#LIVES.Prices],
                Desc = "One life, back at this floor's entrance. The price climbs with each revive this run.",
                OnBuy = function() return Remotes.GetFunction("BoundBuy"):InvokeServer("Revive") end })
        end
    end
    UI.DoRevive = DoRevive -- (Studio DevAct "revive")
    reviveBtn.Button.MouseButton1Click:Connect(DoRevive)
    specRevive.Button.MouseButton1Click:Connect(DoRevive)
    giveUpBtn.Button.MouseButton1Click:Connect(function()
        SoundHelper.Play("Click")
        Remotes.GetEvent("LivesAction"):FireServer("GiveUp")
    end)
    -- spectating: click to switch who you watch
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not LocalPlayer:GetAttribute("Spectating") or isCursorUnlocked then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then NextTarget(1) -- (tap on phones)
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then NextTarget(-1) end
    end)

    local wasOut, wasSpectating = false, false
    RunService.Heartbeat:Connect(function()
        local lives = LocalPlayer:GetAttribute("Lives")
        local downed = LocalPlayer:GetAttribute("Downed") == true
        local spectating = LocalPlayer:GetAttribute("Spectating") == true
        hearts.Visible = lives ~= nil and not downed and not spectating
        if hearts.Visible and hearts:GetAttribute("Shown") ~= lives then -- (only when the count changes)
            hearts:SetAttribute("Shown", lives)
            hearts.Text = "LIVES  " .. UI.HudClean.Pips(lives, math.max(LIVES.PerRun, lives))
        end
        overlay.Visible = downed
        if downed then
            local left = math.max(0, (LocalPlayer:GetAttribute("DownedUntil") or 0) - workspace:GetServerTimeNow())
            timerLbl.Text = string.format("%d", math.ceil(left))
            local txt, how = ReviveText()
            reviveBtn.Label.Text = txt
            reviveBtn.Button.Active = how ~= "none"
            local inParty = LocalPlayer:GetAttribute("RunId") ~= nil
            giveUpBtn.Label.Text = inParty and "SPECTATE" or "GIVE UP"
            infoLbl.Text = (inParty and #Teammates() == 0) and "Nobody is left standing. Revive, or the run ends when the timer runs out"
                or inParty and "Give up to watch your party. You can still revive while spectating"
                or "Give up and the run ends. You keep everything you found"
        end
        specBar.Visible = spectating
        if downed then
            -- third person on your own (fallen) body, so being down doesn't look like a frozen game
            if spectateTarget ~= LocalPlayer then
                spectateTarget = LocalPlayer
                local char = LocalPlayer.Character
                if char then for _, d in ipairs(char:GetDescendants()) do if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0 end end end
            end
        elseif spectating then
            if spectateTarget == LocalPlayer or not spectateTarget or not spectateTarget.Parent or spectateTarget:GetAttribute("Spectating") or spectateTarget:GetAttribute("RunId") ~= LocalPlayer:GetAttribute("RunId")
                or (spectateTarget:GetAttribute("Downed") and #Teammates() > 0) then
                NextTarget(1)
            end
            if spectateTarget and spectateTarget:GetAttribute("Downed") then
                local left = math.max(0, (spectateTarget:GetAttribute("DownedUntil") or 0) - workspace:GetServerTimeNow())
                specLbl.Text = string.format("%s IS DOWN: reviving or the run ends in %d", string.upper(spectateTarget.DisplayName), math.ceil(left))
            else
                specLbl.Text = (spectateTarget and ("SPECTATING  " .. spectateTarget.DisplayName) or "SPECTATING") .. "   |  click: switch  |  hold " .. KeyTag("FreeCursor") .. " free mouse"
            end
            specRevive.Label.Text = (ReviveText())
        elseif spectateTarget and not UI.watching then -- (0.62: a city watcher's target is SpectateClient's)
            spectateTarget = nil
            camInitialized = false
            -- un-hide the teammate whose eyes we were looking through
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    for _, d in ipairs(p.Character:GetDescendants()) do if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0 end end
                end
            end
        end
        -- free the mouse for the buttons while out; lock it again when back in
        local out = downed or spectating
        if out ~= wasOut then
            for _, g in ipairs({ UI.weaponCard, UI.healthFrame, UI.levelFrame, hudGui:FindFirstChild("StatusChips"), hudGui:FindFirstChild("BuildChips") }) do
                if g then g.Visible = not out end
            end
        end
        if downed and not wasOut then SetMouseLocked(false) end
        if spectating and not wasSpectating then SetMouseLocked(true) end -- the mouse turns the spectate camera
        if not out and wasOut then
            if not isAnyMenuOpen then SetMouseLocked(true) end
        end
        wasOut, wasSpectating = out, spectating
    end)
end)()

-- Materials / crafting currency from drops, chests and dismantling.
Remotes.GetEvent("MaterialsGained").OnClientEvent:Connect(function(gained)
    local parts = {}
    for _, key in ipairs(ItemData.MaterialOrder) do
        local n = gained[key]
        if n and n > 0 then
            local def = ItemData.MaterialDefs[key]
            table.insert(parts, "+" .. n .. " " .. def.Name)
        end
    end
    if #parts > 0 then ShowToast(table.concat(parts, "   ")) end
end)

Remotes.GetEvent("LevelUp").OnClientEvent:Connect(function(newLevel)
    SoundHelper.Play("LevelUp") -- (v4 game sounds: its own fanfare, was Victory)
    do -- (the real numbers: ItemData.TreePointsForLevelUp / AttrPointsForLevelUp)
        local tp, ap = ItemData.TreePointsForLevelUp(newLevel), ItemData.AttrPointsForLevelUp(newLevel)
        UI.lvlLabel.Text = "LEVEL UP"
        UI.lvlLabel.TextColor3 = UIStyle.Colors.Accent
        UI.levelUpShowing = true
        if UI.lvlBadge then UI.lvlBadge.Text = tostring(newLevel) end
        ShowToast(ap > 0 and string.format("Level %d  •  +%d passive point%s, +%d attribute point%s", newLevel, tp, tp == 1 and "" or "s", ap, ap == 1 and "" or "s")
            or string.format("Level %d  •  +%d passive point%s", newLevel, tp, tp == 1 and "" or "s")) -- (phase 4: no attribute points)
    end
    task.delay(3, function()
        UI.levelUpShowing = false
        UI.lvlLabel.TextColor3 = UIStyle.Colors.Sub
        UpdateWeaponHUD()
    end)
end)

local function StreakText(): string
    local streak = clientState.Streak or 0
    local t = (streak > 0) and ("FOCUS x" .. tostring(streak)) or ""
    local w = clientState.EquippedWeapon
    -- Fixation: only while stacks are up (they decay on the server after PROC.FixDecay without a hit, which is never
    -- sent, so the client times them out itself) -- it used to sit at "0/20" mid-screen in the hub
    local fix = clientState.FixStacks or 0
    if fix ~= UI.fixShown then UI.fixShown, UI.fixAt = fix, os.clock() end
    if os.clock() - (UI.fixAt or 0) > ItemData.PROC.FixDecay then fix = 0 end
    if w and w.Proc and w.Proc.Id == "Fixation" and fix > 0 then
        t ..= string.format("%sFIXATION %d/%d", (t ~= "") and "   |   " or "", fix, ItemData.PROC.FixMaxStacks)
        local at = UI.fixAt
        task.delay(ItemData.PROC.FixDecay + 0.05, function()
            if UI.fixAt == at then UI.streakLabel.Text = StreakText() end
        end)
    end
    -- hidden at zero (and in the third-person hub); warmer and bigger as the streak climbs
    UI.streakLabel.Visible = t ~= "" and not LocalPlayer:GetAttribute("ThirdPerson")
    local k = math.clamp(streak / 25, 0, 1)
    UI.streakLabel.TextColor3 = Color3.fromRGB(255, 225, 90):Lerp(Color3.fromRGB(255, 90, 60), k)
    UI.streakLabel.TextSize = 16 + math.floor(6 * k)
    return t
end
LocalPlayer:GetAttributeChangedSignal("ThirdPerson"):Connect(function() UI.streakLabel.Text = StreakText() end)
Remotes.GetEvent("CombatDelta").OnClientEvent:Connect(function(d)
    for k, v in pairs(d) do clientState[k] = v end
    UI.streakLabel.Text = StreakText()
    UpdateAmmoHUD()
    ScheduleHudRefresh()
end)

Remotes.GetEvent("SyncPlayerState").OnClientEvent:Connect(function(newState)
    if UI.TryOnReapply then newState = UI.TryOnReapply(newState) or newState end -- (a store try-on keeps showing)
    if UI.TutorialReapply then newState = UI.TutorialReapply(newState) or newState end -- (Update 6 TUTORIAL: the loaner rifle stays in your hands)
    if UI.PvpReapply then newState = UI.PvpReapply(newState) or newState end -- (0.60: a duel's picked gun stays in your hands)
    if UI.trade then task.defer(function() UI.trade.OnState() end) end -- (an open trade's stash column)
    if UI.HideoutOnState then task.defer(UI.HideoutOnState) end
    local prev = clientState or {}
    local cosmeticChanged = newState.EquippedKnife ~= prev.EquippedKnife or newState.EquippedGlove ~= prev.EquippedGlove
        or newState.EquippedSleeve ~= prev.EquippedSleeve or newState.EquippedWeaponSkin ~= prev.EquippedWeaponSkin
        or (type(newState.MeleeSkinFor) == "table" and newState.MeleeSkinFor[newState.EquippedKnife or ""] or nil) ~= (type(prev.MeleeSkinFor) == "table" and prev.MeleeSkinFor[prev.EquippedKnife or ""] or nil)
        or (function() -- glove / sleeve cosmetics (GloveFX)
            local a = type(newState.CosmeticsEquipped) == "table" and newState.CosmeticsEquipped or {}
            local b = type(prev.CosmeticsEquipped) == "table" and prev.CosmeticsEquipped or {}
            return a.Glove ~= b.Glove or a.Sleeve ~= b.Sleeve
        end)()
        or (function() -- the held gun's premium skin (SkinFX)
            local S, g = require(sharedFolder:WaitForChild("SkinFX")), newState.EquippedWeapon and newState.EquippedWeapon.BaseId
            return S.GunSkinFor(newState, g) ~= S.GunSkinFor(prev, g)
        end)()
        or (function() -- (0.93) a colourway change on the glove / sleeve / melee (each colourway is its own cached look)
            local G, M = require(sharedFolder:WaitForChild("GloveFX")), require(sharedFolder:WaitForChild("MeleeData"))
            return G.GloveFor(newState) ~= G.GloveFor(prev) or G.SleeveFor(newState) ~= G.SleeveFor(prev)
                or M.SkinFor(newState, newState.EquippedKnife) ~= M.SkinFor(prev, prev.EquippedKnife)
        end)()
    -- A weapon equipped by the server (dev command, forge swap, ...) also needs the viewmodel rebuilt;
    -- skip it when the client already shows this exact weapon (normal equips rebuild locally).
    local shown = vmTuneActiveWeapon
    local weaponChanged = newState.EquippedWeapon ~= nil and (shown == nil or shown.Uid ~= newState.EquippedWeapon.Uid)
    clientState = newState
    UI.stateLoaded = true
    if UI.RefreshClassPicker then UI.RefreshClassPicker() end
    if UI.RefreshAsc then UI.RefreshAsc() end
    UI.streakLabel.Text = StreakText()
    if (cosmeticChanged or weaponChanged) and newState.EquippedWeapon then
        -- Melee / glove / sleeve / weapon-finish changes all show on the viewmodel, so rebuild it.
        RebuildViewmodelForWeapon(newState.EquippedWeapon)
    end
    if UI.armoryFrame and UI.armoryFrame.Visible then RefreshArmoryMenu() end
    if UI.RefreshHudTheme then UI.RefreshHudTheme() end
    if UI.cosmetics then UI.cosmetics.Refresh() end
    UpdateWeaponHUD()
    if UI.treeFrame.Visible then RefreshTree() end
    if UI.invFrame.Visible then RefreshInventory() end
    if UI.upgFrame.Visible then RefreshUpgradeMenu() end
    if UI.indexFrame.Visible then RenderIndexContent() end
    if UI.RefreshBoons then UI.RefreshBoons() end
    if UI.RefreshContracts then UI.RefreshContracts() end
    if UI.Challenges then UI.Challenges.Refresh() end
    if UI.season then UI.season.Refresh() end
end)

-- party runs (and anyone being watched, 0.62 SPECTATE): share where you look up/down (10x/s, only when it changed) so spectators see your view
;(function()
    local ev = Remotes.GetEvent("AimPitch")
    local last, acc = 99, 0
    RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < 0.1 then return end
        acc = 0
        -- (2026-10-13: always in first person -- other players' bodies aim up / down with you, CharacterPoser)
        if spectateTarget or LocalPlayer:GetAttribute("ThirdPerson") then return end
        if math.abs(camPitch - last) > 0.03 then
            last = camPitch
            ev:FireServer(camPitch)
        end
    end)
end)()

-- ==================== RUN SUMMARY (0.49; server RunStats) ====================
-- After a run ends (victory, extraction, out of lives, or leaving), a window lists your run in detail: time, floors,
-- kills, accuracy, hits, weak-spot and crit rates, damage, DPS, biggest hit, damage taken, deaths... In a party every
-- member is a row of a comparison table (the best value in each column is gold); it refreshes as others finish.
;(function()
    local C = UIStyle.Colors
    local GOLD = Color3.fromRGB(255, 205, 70)
    local OUTCOME = {
        VICTORY = { "RUN COMPLETE", Color3.fromRGB(110, 230, 140) }, EXTRACTED = { "EXTRACTED", Color3.fromRGB(255, 205, 90) }, MAPCLEARED = { "MAP CLEARED", Color3.fromRGB(110, 230, 140) },
        DEFEATED = { "DEFEATED", Color3.fromRGB(255, 90, 90) }, LEFT = { "RUN ENDED", Color3.fromRGB(170, 180, 200) },
    }
    -- (UI CLEAN R-C: the target's language -- summary before detail: four big display numbers (TIME / KILLS / ACCURACY / DPS),
    -- then the rest as quiet label-over-value tiles on the raised surface (no boxes, no strokes), the best drop as the target's
    -- item card (2 px rarity line), the party table with the best value in Text and the rest in Sub; the title in Text.)
    local panel = UIStyle.Panel(UI.menuFolder, { Name = "RunSummary", Size = UDim2.fromOffset(860, 640), Accent = C.Accent })
    panel:SetAttribute("PhoneMinH", 300) -- (phones: as tall as the screen; its list scrolls)
    UI.runSummary = panel -- (a new run's first floor closes it: DungeonUpdate)
    local bar, sub = UIStyle.TitleBar(panel, "RUN SUMMARY", C.Accent, "", function() CloseAllMenus() end)
    local RAISE, RAISE_T = C.Text, 0.955 -- (the target's raised surface: the text colour at ~4.5%)
    local body = Instance.new("ScrollingFrame")
    body.Name = "Body"; body.BackgroundTransparency = 1; body.BorderSizePixel = 0
    body.Position = UDim2.fromOffset(16, 76); body.Size = UDim2.new(1, -32, 1, -92)
    body.ScrollBarThickness = 6; body.AutomaticCanvasSize = Enum.AutomaticSize.Y; body.CanvasSize = UDim2.new()
    body.Parent = panel
    local list = Instance.new("UIListLayout"); list.Padding = UDim.new(0, 10); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = body

    local function T(parent, props)
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1; l.TextColor3 = Color3.new(1, 1, 1); l.Font = UIStyle.Font; l.TextSize = 16
        for k, v in pairs(props) do l[k] = v end
        l.Parent = parent
        return l
    end
    local function Clock(t: number): string
        t = math.max(0, math.floor(t))
        local h, m, s = t // 3600, (t % 3600) // 60, t % 60
        return h > 0 and string.format("%d:%02d:%02d", h, m, s) or string.format("%d:%02d", m, s)
    end
    local function Pct(x: number): string return string.format("%d%%", math.round((x or 0) * 100)) end
    local N = function(x) return ItemData.FormatNumber(math.round(x or 0)) end

    local function Render(rows: { any })
        for _, c in ipairs(body:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
        local me = rows[1]
        local oc = OUTCOME[me.Outcome] or OUTCOME.LEFT
        -- (fits its content: the 16 tiles alone, or + the party table)
        panel.Size = UDim2.fromOffset(860, math.min(700, 422 + ((type(me.Best) == "table") and 64 or 0) + ((type(me.Killer) == "string") and 64 or 0) + ((#rows > 1) and (66 + 32 * #rows) or 0)))
        local title = bar:FindFirstChild("Title")
        if title then title.Text = oc[1]; title.TextColor3 = C.Text end -- (UI CLEAN R-C: the word says it; no outcome colour)
        if sub then
            sub.Text = string.format("%s%s  •  %s  •  %d floor%s cleared", me.Difficulty and (string.upper(tostring(me.Difficulty)) .. "  •  ") or "",
                me.Weapon or "", Clock(me.Time), me.Floors, me.Floors == 1 and "" or "s")
        end
        -- BEST DROP (2026-10-23 loot feel): the best item you kept this run, in its colour (hover = its card)
        if type(me.Best) == "table" then
            local it = me.Best
            local col = (ItemData.ItemColor and ItemData.ItemColor(it)) or ItemData.RarityColors[it.Rarity] or C.Text
            local row = Instance.new("TextButton"); row.Name = "BestDrop"; row.LayoutOrder = 0; row.AutoButtonColor = false; row.Text = ""
            row.Size = UDim2.new(1, -8, 0, 58); row.BackgroundColor3 = col:Lerp(RAISE, 0.5); row.BackgroundTransparency = 0.93; row.BorderSizePixel = 0
            row:SetAttribute("Skinned", true); row:SetAttribute("NoSkin", true); row.Parent = body
            local blk = Instance.new("Frame"); blk.BorderSizePixel = 0; blk.BackgroundColor3 = col; blk.AnchorPoint = Vector2.new(0, 1)
            blk.Position = UDim2.fromScale(0, 1); blk.Size = UDim2.new(1, 0, 0, 2); blk.Parent = row -- (the target card's rarity line)
            local hd = T(row, { Text = "BEST DROP", Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 16), TextXAlignment = Enum.TextXAlignment.Left })
            UI.RunHud.Role(hd, "Label"); hd.FontFace = UIStyle.RoleFace("Label"); hd.TextSize = 13
            local nm = (ItemData.DisplayName and ItemData.DisplayName(it)) or it.Name or "?"
            local lbl = (ItemData.RarityLabel and ItemData.RarityLabel(it)) or it.Rarity or ""
            local glyph = (not it.Exotic and UI.RarityGlyph) and (UI.RarityGlyph(it.Rarity) .. "  ") or "" -- (a relic's DisplayName has its own ◆)
            local nameL = T(row, { Text = glyph .. string.upper(nm), TextColor3 = col, Position = UDim2.fromOffset(14, 26), Size = UDim2.new(0.62, -14, 0, 26),
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
            UI.RunHud.Role(nameL, "Title", { Keep = true })
            if not it.Exotic and ItemData.StyleRarityText then ItemData.StyleRarityText(nameL, it.Rarity) end
            local ml = T(row, { Text = string.upper(lbl) .. (me.BestTop and "  •  TOP TIER" or "") .. "  •  iLvl " .. tostring(it.ItemLevel or 1),
                Position = UDim2.new(0.62, 0, 0, 26), Size = UDim2.new(0.38, -14, 0, 26), TextXAlignment = Enum.TextXAlignment.Right })
            UI.RunHud.Role(ml, "Label")
            if UI.HookItemTooltip then UI.HookItemTooltip(row, it, it.Slot ~= nil) end
        end
        -- your stats: HERO = the four that say how the run went, big; then the other twelve, 4 a row, quieter
        -- (tiles are named by their stat key: RunVsAvg finds ACCURACY / WEAK SPOT / DPS by name)
        local tiles = {
            { "TIME", Clock(me.Time), "", "Time" },
            { "KILLS", N(me.Kills), string.format("%d elite%s  •  %d boss%s", me.Elites, me.Elites == 1 and "" or "s", me.Bosses, me.Bosses == 1 and "" or "es"), "Kills" },
            { "ACCURACY", Pct(me.Accuracy), string.format("%s of %s shots hit", N(me.Hits), N(me.Shots)), "Accuracy" },
            { "DPS", N(me.DPS), "while fighting", "DPS" },
            { "FLOORS", tostring(me.Floors), me.BestFloor > 0 and ("reached floor " .. me.BestFloor) or "", "Floors" },
            { "WEAK SPOT", Pct(me.WeakPct), "of your hits", "WeakPct" },
            { "CRITS", Pct(me.CritPct), "of your hits", "CritPct" }, { "DAMAGE", N(me.Damage), "everything you dealt", "Damage" },
            { "TOTAL HITS", N(me.PelletHits), "every pellet that landed", "PelletHits" }, { "BIGGEST HIT", N(me.Highest), "", "Highest" },
            { "DAMAGE TAKEN", N(me.Taken), "", "Taken" }, { "DEATHS", tostring(me.Deaths), "", "Deaths" },
            { "BEST FOCUS", tostring(me.BestStreak), "weak-spot streak", "BestStreak" }, { "LOOT", tostring(me.Items), "items dropped", "Items" },
            { "GOLD", N(me.Gold), "earned this run", "Gold" }, { "LEVELS", "+" .. tostring(me.Levels), "gained", "Levels" },
        }
        local stats = Instance.new("Frame"); stats.Name = "Stats"; stats.BackgroundTransparency = 1; stats.LayoutOrder = 1
        stats.Size = UDim2.new(1, -8, 0, 0); stats.AutomaticSize = Enum.AutomaticSize.Y; stats.Parent = body
        local sl = Instance.new("UIListLayout"); sl.Padding = UDim.new(0, 10); sl.SortOrder = Enum.SortOrder.LayoutOrder; sl.Parent = stats
        local function Grid(name, order, h)
            local g = Instance.new("Frame"); g.Name = name; g.BackgroundTransparency = 1; g.LayoutOrder = order
            g.Size = UDim2.new(1, 0, 0, 0); g.AutomaticSize = Enum.AutomaticSize.Y; g.Parent = stats
            local gl = Instance.new("UIGridLayout"); gl.CellSize = UDim2.new(0.25, -6, 0, h); gl.CellPadding = UDim2.fromOffset(8, 8)
            gl.SortOrder = Enum.SortOrder.LayoutOrder; gl.Parent = g
            return g
        end
        local hero, grid = Grid("Hero", 1, 92), Grid("Mine", 3, 62)
        for i, t in ipairs(tiles) do
            local big = i <= 4
            local tile = Instance.new("Frame"); tile.Name = t[4]; tile.LayoutOrder = i; tile.BorderSizePixel = 0
            tile.BackgroundColor3 = RAISE; tile.BackgroundTransparency = big and 1 or RAISE_T
            tile:SetAttribute("NoSkin", true); tile.Parent = big and hero or grid
            local lab = T(tile, { Text = t[1], Position = UDim2.fromOffset(big and 0 or 12, big and 4 or 8), Size = UDim2.new(1, -24, 0, 16), TextXAlignment = Enum.TextXAlignment.Left })
            UI.RunHud.Role(lab, "Label"); lab.FontFace = UIStyle.RoleFace("Label"); lab.TextSize = 13
            local val = T(tile, { Text = t[2], Position = UDim2.fromOffset(big and 0 or 12, big and 22 or 26), Size = UDim2.new(1, -24, 0, big and 46 or 26), TextXAlignment = Enum.TextXAlignment.Left })
            UI.RunHud.Num(val, big and 44 or 22, C.Text)
            if t[3] ~= "" then
                local note = T(tile, { Text = t[3], Position = UDim2.new(0, big and 0 or 12, 1, big and -18 or -20), Size = UDim2.new(1, -24, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
                UI.RunHud.Role(note, "Meta"); note.TextSize = 12
                if not big then note.Visible = false end -- (the small tiles: label + value only; the hint lives in the HERO row)
            end
        end
        do -- (a hairline between the hero numbers and the detail tiles)
            local hl = Instance.new("Frame"); hl.Name = "Rule"; hl.BorderSizePixel = 0; hl.BackgroundColor3 = C.Text; hl.BackgroundTransparency = 0.9
            hl.Size = UDim2.new(1, 0, 0, 1); hl.LayoutOrder = 2; hl.Parent = stats
        end
        do local m = sharedFolder:FindFirstChild("RunVsAvg"); if m then pcall(function() require(m).Decorate(hero, me); require(m).Decorate(grid, me) end) end end -- (QOL2 R3: "+2.1% vs avg" lines)
        if UI.DeathRecap then UI.DeathRecap.SummaryRow(body, me, 2) end -- (QOL2 R1: the run's last death -- who killed you + the last hits)
        -- party comparison
        if #rows > 1 then
            local ph = T(body, { Name = "PartyHead", LayoutOrder = 3, Text = "PARTY", Size = UDim2.new(1, -8, 0, 26), TextXAlignment = Enum.TextXAlignment.Left })
            UI.RunHud.Role(ph, "SectionHead")
            local COLS = {
                { "PLAYER", function(r) return r.Name end, nil, 0.2 },
                { "ACCURACY", function(r) return Pct(r.Accuracy) end, function(r) return r.Accuracy end, 0.11 },
                { "DPS", function(r) return N(r.DPS) end, function(r) return r.DPS end, 0.11 },
                { "DAMAGE", function(r) return N(r.Damage) end, function(r) return r.Damage end, 0.12 },
                { "KILLS", function(r) return N(r.Kills) end, function(r) return r.Kills end, 0.09 },
                { "WEAK SPOT", function(r) return Pct(r.WeakPct) end, function(r) return r.WeakPct end, 0.11 },
                { "TAKEN", function(r) return N(r.Taken) end, function(r) return -r.Taken end, 0.1 },
                { "DEATHS", function(r) return tostring(r.Deaths) end, function(r) return -r.Deaths end, 0.08 },
                { "", function(r) return r.Outcome == "IN RUN" and "in run" or "" end, nil, 0.08 },
            }
            local best = {}
            for ci, col in ipairs(COLS) do
                if col[3] then
                    local b = -math.huge
                    for _, r in ipairs(rows) do b = math.max(b, col[3](r)) end
                    best[ci] = b
                end
            end
            local function Line(order, cells, isHead, isMe)
                local f = Instance.new("Frame"); f.LayoutOrder = order; f.Size = UDim2.new(1, -8, 0, isHead and 24 or 32)
                f.BackgroundColor3 = RAISE; f.BackgroundTransparency = isHead and 1 or (isMe and 0.92 or RAISE_T)
                f.BorderSizePixel = 0; f.Parent = body
                local x = 0
                for ci, col in ipairs(COLS) do
                    local c = cells[ci]
                    T(f, { Text = c[1], TextSize = isHead and 12 or 16, TextColor3 = c[2], Position = UDim2.new(x, 8, 0, 0),
                        Size = UDim2.new(col[4], -8, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                        Font = isHead and UIStyle.BodyFont or UIStyle.Font })
                    x += col[4]
                end
            end
            local head = {}
            for ci, col in ipairs(COLS) do head[ci] = { col[1], C.Sub } end
            Line(4, head, true, false)
            table.sort(rows, function(a, b) return a.Damage > b.Damage end)
            for i, r in ipairs(rows) do
                local cells = {}
                for ci, col in ipairs(COLS) do
                    local isBest = col[3] and #rows > 1 and math.abs(col[3](r) - best[ci]) < 1e-9
                    cells[ci] = { col[2](r), (isBest or not col[3]) and C.Text or C.Sub } -- (UI CLEAN R-C: the best in Text, the rest Sub -- gold is currency only)
                end
                Line(4 + i, cells, false, r.UserId == LocalPlayer.UserId)
            end
        end
    end

    -- (QOL2 R2 LAST RUN) the last summary of this session is kept; the MENU's LAST RUN tile opens it again (same key closes)
    UI.OpenLastRun = function()
        if not UI.lastRunRows then return end
        if panel.Visible then CloseAllMenus(); return end
        Render(UI.lastRunRows)
        if UI.RunAgain then UI.RunAgain.RefreshSummary() end
        OpenMenuFrame(panel)
    end
    Remotes.GetEvent("RunSummary").OnClientEvent:Connect(function(rows)
        if type(rows) ~= "table" or not rows[1] then return end
        UI.lastRunRows = rows -- (QOL2 R2)
        local refresh = panel.Visible
        Render(rows)
        if UI.RunAgain then UI.RunAgain.RefreshSummary() end -- (QOL F1: the RUN AGAIN footer)
        if refresh then return end -- (a party mate finished: same window, new numbers)
        task.delay(1.2, function() -- (let the trip back to the hub land first)
            if UI.RunAgain and UI.RunAgain.Busy() then return end -- (QOL F1: RUN AGAIN is starting the next run: no window over it)
            if not panel.Visible then OpenMenuFrame(panel) end
        end)
    end)
end)()

-- RUN AGAIN (QOL F1, 2026-10-28): a button on the RUN SUMMARY + the DUNGEON CLEARED banner (AimRngShared/RunAgainClient; the server
-- remembers the run and starts the next one through the real start path -- server AimRngServer/RunAgain)
;(function()
    local RA = require(sharedFolder:WaitForChild("RunAgainClient")).Init({
        StartSolo = function(b, k, sk) if UI.StartSolo then UI.StartSolo(b, k, sk) end end,
        Toast = function(t) ShowToast(t) end,
        Click = function() SoundHelper.Play("Click") end,
        InRun = function() return UI.InRunLocked ~= nil and UI.InRunLocked() end,
        LeaveGate = function() -- (QOL L1: loot still on the ground -> one warning, a second click leaves)
            local okG, GL = pcall(require, sharedFolder:WaitForChild("GroundLoot"))
            if okG and GL.LeaveGate then return GL.LeaveGate("click RUN AGAIN again to leave") end
            return true
        end,
        LeaveRun = function() -- (the client half of RETURN TO HUB; the server's RUN AGAIN ends the run itself)
            UI.victoryBanner.Visible = false
            UI.raidBanner.Visible = false
            TeleportClient(CFrame.lookAt(Vector3.new(0, 7.2, 24), Vector3.new(0, 7.2, 0)))
        end,
        CloseAll = function() CloseAllMenus() end,
    })
    UI.RunAgain = RA
    UI.RunAgainGo = RA.Go -- (QOL F1 Studio hook: DevAct "ui:RunAgainGo")
    -- (QOL F4) the party READY CHECK pop-up (AimRngShared/PartyReady); Studio: DevAct "ui:DevReady" / "ui:DevNotReady" / "ui:DevReadyStart"
    local PR = require(sharedFolder:WaitForChild("PartyReady")).Init({ Parent = hudGui, Click = function() SoundHelper.Play("Click") end, Toast = function(t) ShowToast(t) end })
    UI.DevReady = function() PR.Dev("ready") end; UI.DevNotReady = function() PR.Dev("notready") end; UI.DevReadyStart = function() PR.Dev("start") end -- (QOL F4)
    pcall(function() require(sharedFolder:WaitForChild("PartyHud")).Init({ Parent = hudGui, -- (QOL2 H4b: teammates' HP / lives as slim lines over the HUD column; Studio: DevPartyHud)
        HpColor = function() return UI.hpFill and UI.hpFill.BackgroundColor3 end, X = function() return UI.HudStack.X end,
        Bottom = function() return UI.HudStack.TopY - 56 end }) end) -- (above the Build chips row: TopY - 30, 22 tall)
    local list = nil -- (the window's own "Body" is its background: the run list is the ScrollingFrame "Body")
    for _, c in ipairs(UI.runSummary:GetChildren()) do if c.Name == "Body" and c:IsA("ScrollingFrame") then list = c end end
    if list then RA.AttachSummary(UI.runSummary, list) end
    local keep
    for _, c in ipairs(UI.victoryBanner:GetChildren()) do if c:IsA("TextButton") and c.Text == "KEEP LOOTING" then keep = c end end
    if keep and UI.btnVictoryHub then RA.AttachBanner(UI.victoryBanner, UI.btnVictoryHub, keep) end
end)()

-- GOAL TRACKER (QOL2 R4, 2026-10-28): up to 3 tracked daily contracts / weekly jobs with live progress, top-left in runs
-- (AimRngShared/GoalTracker; server AimRngServer/GoalTrack; TRACK buttons in Challenges > WEEKLY; setting Goal Tracker)
;(function()
    local m = sharedFolder:WaitForChild("GoalTracker", 5)
    local ok, GT = pcall(function() return m and require(m) end)
    if ok and GT then GT.Init({ Hud = hudGui, GetState = function() return clientState end, MenuOpen = function() return isAnyMenuOpen end,
        -- (UI CLEAN P5: left edge on the MENU button's margin, top under it + GAP. Both guis ignore the top-bar inset, but
        -- AbsolutePosition is measured below the inset -- add it back, then / the HUD scale = HUD units)
        Anchor = function()
            local b = UI.MenuButton
            local hs = hudGui:FindFirstChildOfClass("UIScale")
            local k = math.max(hs and hs.Scale or 1, 0.05)
            if b and b.Visible and b.AbsoluteSize.Y > 0 then
                local inset = game:GetService("GuiService"):GetGuiInset().Y
                return UIStyle.MARGIN, math.floor((b.AbsolutePosition.Y + inset + b.AbsoluteSize.Y) / k + UIStyle.GAP + 0.5)
            end
            return nil
        end }) end
end)()

-- GLOBAL DROP FEED (0.97, owner: "add global gear drop chats (can hover the weapon / gear they got to view the stats.
-- Overall rarity of the drop should be displayed)"): CombatServer.AnnounceDrop -> DropFeed. Rows on the right edge
-- (never over the crosshair), newest at the bottom, 4 at most, gone after 10 s; hover (free cursor) = the item's card.
;(function()
    local FEED_MAX, FEED_LIFE = 4, 10
    local gui = Instance.new("ScreenGui")
    gui.Name = "DropFeedGui"; gui.ResetOnSpawn = false; gui.DisplayOrder = 4; gui.IgnoreGuiInset = true
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    local list = Instance.new("Frame")
    list.Name = "Feed"; list.BackgroundTransparency = 1
    list.AnchorPoint = Vector2.new(1, 1); list.Position = UDim2.new(1, -16, 0.72, 0); list.Size = UDim2.fromOffset(360, 300)
    list.Parent = gui
    local lay = Instance.new("UIListLayout")
    lay.VerticalAlignment = Enum.VerticalAlignment.Bottom; lay.Padding = UDim.new(0, 6); lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Parent = list
    local sc = Instance.new("UIScale"); sc.Parent = list
    local order = 0
    local function esc(t) return (tostring(t):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end
    Remotes.GetEvent("DropFeed").OnClientEvent:Connect(function(name, display, userId, item, kind, label, oneIn, diff)
        if type(item) ~= "table" then return end
        if GameSettings.Get("GlobalDropFeed") == false then return end -- (QOL L4: Settings > Interface > Global Drop Feed)
        local hs = UI.hudGui:FindFirstChildOfClass("UIScale")
        sc.Scale = hs and hs.Scale or 1
        local col = (ItemData.ItemColor and ItemData.ItemColor(item)) or ItemData.RarityColors[item.Rarity] or Color3.new(1, 1, 1)
        order += 1
        local row = Instance.new("TextButton")
        row.Name = "Drop"; row.AutoButtonColor = false; row.Text = ""; row.LayoutOrder = order
        -- (UI CLEAN R-C: the target's item tile -- the run HUD plate with a 2 px rarity line along the bottom; who in Sub body,
        -- the item in its rarity colour in display caps, the odds line in Meta caps -- no ink stroke, no 5 px side bar)
        row.Size = UDim2.new(1, 0, 0, 50)
        UI.RunHud.Plate(row, 0.18)
        local bar = Instance.new("Frame"); bar.BorderSizePixel = 0; bar.BackgroundColor3 = col; bar.AnchorPoint = Vector2.new(0, 1)
        bar.Position = UDim2.fromScale(0, 1); bar.Size = UDim2.new(1, 0, 0, 2); bar.Parent = row
        local top = Instance.new("TextLabel")
        top.BackgroundTransparency = 1; top.RichText = true; top.TextXAlignment = Enum.TextXAlignment.Left
        top.Position = UDim2.fromOffset(12, 5); top.Size = UDim2.new(1, -24, 0, 22); top.TextTruncate = Enum.TextTruncate.AtEnd
        local nm = (ItemData.DisplayName and ItemData.DisplayName(item)) or item.Name or "?"
        top.Text = string.format('<font color="#%s">%s</font>   <font color="#%s">%s</font>', UIStyle.Colors.Sub:ToHex(), esc(string.upper(display or name)), col:ToHex(), esc(string.upper(nm)))
        top.Parent = row
        UI.RunHud.Role(top, "ItemName", { Keep = true })
        local sub = Instance.new("TextLabel")
        sub.BackgroundTransparency = 1; sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.Position = UDim2.fromOffset(12, 27); sub.Size = UDim2.new(1, -24, 0, 16); sub.TextTruncate = Enum.TextTruncate.AtEnd
        local odds = (tonumber(oneIn) or 0) > 0 and string.format("1 in %s drops", tostring(oneIn)) or "ultra rare"
        sub.Text = string.upper(tostring(label or item.Rarity)) .. "  •  " .. odds .. (diff and ("  •  " .. string.upper(tostring(diff))) or "")
        sub.Parent = row
        UI.RunHud.Role(sub, "Meta", { Color = "Sub" })
        row.Parent = list
        if UI.HookItemTooltip then UI.HookItemTooltip(row, item, kind == "Gear") end
        local hov = false
        row.MouseEnter:Connect(function() hov = true end)
        row.MouseLeave:Connect(function() hov = false end)
        row.Destroying:Connect(function() if hov and UI.HideTooltip then UI.HideTooltip() end end)
        local rows = {}
        for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then table.insert(rows, c) end end
        table.sort(rows, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
        while #rows > FEED_MAX do table.remove(rows, 1):Destroy() end
        task.delay(FEED_LIFE, function()
            if not row.Parent then return end
            local ti = TweenInfo.new(0.6)
            for _, o in ipairs(row:GetDescendants()) do
                if o:IsA("TextLabel") then TweenService:Create(o, ti, { TextTransparency = 1 }):Play()
                elseif o:IsA("Frame") then TweenService:Create(o, ti, { BackgroundTransparency = 1 }):Play()
                elseif o:IsA("UIStroke") then TweenService:Create(o, ti, { Transparency = 1 }):Play() end
            end
            TweenService:Create(row, ti, { BackgroundTransparency = 1 }):Play()
            task.delay(0.65, function() row:Destroy() end)
        end)
    end)
end)()

-- PHONE HUD (2026-10-13, owner's real-phone test: "nothing overlapping, nothing too big"): on a phone (UIStyle.IsPhone, a
-- Studio DevPhone preview included) the bottom-left HUD column is compact -- narrower, the weapon card keeps the name + the
-- ammo (type / stats / trait lines and the key hint hidden), slimmer health + level bars -- so it sits under less of the
-- Roblox thumbstick and the dock; the global drop feed moves from the right edge (over the touch buttons) to the top right
-- on touch screens. Tablets / desktop keep the full layout (UI.HudStack's original numbers).
;(function()
    local HS = UI.HudStack
    -- (UI CLEAN P2: HudClean strips the HUD chrome once and lays the column out -- sizes in HudClean.FULL / PHONE; on a
    -- phone the column is centred at the bottom between the thumbstick and the touch buttons)
    UI.HudClean = UI.HudClean or require(sharedFolder:WaitForChild("HudClean"))
    UI.HudClean.Init({ UI = UI, Hud = hudGui })
    local phoneNow = nil
    local function Hide(lbl: GuiObject?)
        if not lbl then return end
        lbl.Visible = false
        if not lbl:GetAttribute("PhoneHideHooked") then
            lbl:SetAttribute("PhoneHideHooked", true)
            lbl:GetPropertyChangedSignal("Visible"):Connect(function() if phoneNow and lbl.Visible then lbl.Visible = false end end)
        end
    end
    local function Apply()
        local phone = UIStyle.IsPhone()
        local T = UI.HudClean.Layout(HS, phone)
        UI.hpSubSize = math.floor((T and T.Big or 38) * 0.47)
        UI.levelFrame.Size = UDim2.new(0, HS.W, 0, HS.LevelH)
        UI.levelFrame.Position = UDim2.new(0, HS.X, 1, HS.LevelY)
        UI.healthFrame.Size = UDim2.new(0, HS.W, 0, HS.HealthH)
        UI.hpBasePos = UDim2.new(0, HS.X, 1, HS.HealthY)
        UI.healthFrame.Position = UI.hpBasePos
        UI.weaponCard.Size = UDim2.new(0, HS.W, 0, HS.WeaponH)
        UI.weaponCard.Position = UDim2.new(0, HS.X, 1, -HS.Bottom)
        local _ = Hide
        phoneNow = phone
        pcall(UpdateWeaponHUD) -- (the HP text's small "/ max" size follows the layout)
        local rows = {
            StatusChips = UDim2.new(0, HS.X, 1, HS.TopY - 2), BuildChips = UDim2.new(0, HS.X, 1, HS.TopY - 30),
            ShiftLockHint = UDim2.new(0, HS.X + HS.W, 1, HS.TopY), LivesHearts = UI.HudClean.LivesPos(HS),
        }
        for name, pos in pairs(rows) do
            local f = hudGui:FindFirstChild(name)
            if f and f:IsA("GuiObject") then f.Position = pos end
        end
        -- the Training Grounds / hideout dummy panel (RangeClient, right edge middle): over T / SLIDE / DASH / R on touch -> top right
        local rp = hudGui:FindFirstChild("RangePanel", true)
        if rp and rp:IsA("GuiObject") then
            if GameSettings.TouchOnly() then rp.AnchorPoint, rp.Position = Vector2.new(1, 0), UDim2.new(1, -16, 0, 84)
            else rp.AnchorPoint, rp.Position = Vector2.new(1, 0.5), UDim2.new(1, -18, 0.55, 0) end
        end
        -- the drop feed: off the touch buttons
        local feedGui = LocalPlayer.PlayerGui:FindFirstChild("DropFeedGui")
        local feed = feedGui and feedGui:FindFirstChild("Feed")
        local lay = feed and feed:FindFirstChildOfClass("UIListLayout")
        if feed and lay then
            if GameSettings.TouchOnly() then
                feed.AnchorPoint, feed.Position = Vector2.new(1, 0), UDim2.new(1, -16, 0, 84)
                lay.VerticalAlignment = Enum.VerticalAlignment.Top
            else
                feed.AnchorPoint, feed.Position = Vector2.new(1, 1), UDim2.new(1, -16, 0.72, 0)
                lay.VerticalAlignment = Enum.VerticalAlignment.Bottom
            end
        end
    end
    task.defer(function()
        local ok, err = pcall(Apply)
        if not ok then warn("[PhoneHUD] " .. tostring(err)) end
    end)
    local function Re() task.defer(function() pcall(Apply) end) end
    LocalPlayer:GetAttributeChangedSignal("DevPhone"):Connect(Re)
    LocalPlayer:GetAttributeChangedSignal("DevTouch"):Connect(Re)
    if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Re) end
    hudGui.ChildAdded:Connect(function(c) if c.Name == "ShiftLockHint" or c.Name == "LivesHearts" then Re() end end)
end)()

-- QOL2 H1 (2026-10-28): a rebind that takes another action's key swaps them; on join old duplicates get solved -> say so.
;(function()
    GameSettings.OnBindMoved(function(d, keyName)
        local label = string.upper((string.gsub(tostring(d and d.Label or "?"), "%s*%b()", "")))
        ShowToast(label .. " MOVED TO [" .. string.upper(GameSettings.KeyLabel(keyName)) .. "]", true)
    end)
    if not RunService:IsStudio() then return end
    -- Studio: Player attr DevBind = "load:<settings JSON>" | "set:<Key_X>=<name>" -> DevBindResult = every bind (JSON)
    LocalPlayer:GetAttributeChangedSignal("DevBind"):Connect(function()
        local a = LocalPlayer:GetAttribute("DevBind")
        if type(a) ~= "string" or a == "" then return end
        local H = game:GetService("HttpService")
        if string.sub(a, 1, 5) == "load:" then
            GameSettings.Load(H:JSONDecode(string.sub(a, 6)))
        elseif string.sub(a, 1, 4) == "set:" then
            local k, v = string.match(a, "^set:([%w_]+)=(.+)$")
            if k then GameSettings.Set(k, v) end
        end
        local out = {}
        for _, d in ipairs(GameSettings.Defs) do if d.Type == "key" then out[d.Key] = GameSettings.Get(d.Key) end end
        LocalPlayer:SetAttribute("DevBindResult", H:JSONEncode(out))
    end)
end)()

-- QOL2 H3 (2026-10-28): Exchange sales waiting (Player attr ExchangeSold, MarketService.SaleNotice / Buy / Collect): a toast once
-- on join ("join"), a green dot on the MENU button + the EXCHANGE cell until you COLLECT. Event-driven, no polling.
;(function()
    UI.ExchangeSoldOn = function()
        return LocalPlayer:GetAttribute("ExchangeSold") ~= nil and not (UI.InRunLocked and UI.InRunLocked())
    end
    UI.ExchangeDot = function(cell)
        if not UI.ExchangeSoldOn() then return end
        local d = Instance.new("Frame")
        d.Name = "SoldDot"; d.BorderSizePixel = 0; d.BackgroundColor3 = Color3.fromRGB(110, 230, 150); d.AnchorPoint = Vector2.new(0.5, 0.5)
        d.Position = UDim2.new(1, -10, 0, 10); d.Size = UDim2.fromOffset(12, 12); d.ZIndex = 4; d.Parent = cell
        UIStyle.InkEdge(2).Parent = d
    end
    local toasted = false
    local function Check()
        local v = LocalPlayer:GetAttribute("ExchangeSold")
        if v == nil then
            toasted = false
            local m = UI.menuFolder and UI.menuFolder:FindFirstChild("MainMenu")
            local c = m and m:FindFirstChild("EXCHANGE", true)
            local d = c and c:FindFirstChild("SoldDot")
            if d then d:Destroy() end
        elseif v == "join" and not toasted then
            toasted = true
            ShowToast("Your Exchange listings sold: COLLECT at the Exchange (MENU > EXCHANGE)", true)
        end
        if UI.TouchMenuSync then UI.TouchMenuSync() end
    end
    LocalPlayer:GetAttributeChangedSignal("ExchangeSold"):Connect(Check)
    task.defer(Check)
end)()

task.spawn(function()
    local s = Remotes.GetFunction("GetPlayerState"):InvokeServer()
    if s then
        GameSettings.Load(s.Settings) -- saved settings arrive with the player's save
        clientState = s
        UI.stateLoaded = true
        if UI.RefreshContracts then UI.RefreshContracts() end
        if UI.RefreshBoons then UI.RefreshBoons() end
        EnsureViewmodel()
        UpdateWeaponHUD()
    end
end)

do
    local weaponCount, nodeCount = 0, 0
    for _ in pairs(ItemData.BaseWeapons) do weaponCount += 1 end
    for _ in pairs(SkillTreeData) do nodeCount += 1 end
    print(string.format("[AimRngRogue] Client ready: %d weapons, %d-node passive tree.", weaponCount, nodeCount))
end

