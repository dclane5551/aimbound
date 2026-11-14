--!nocheck
-- Third-person camera for the hub (client). AimRngClient's camera hands over to this while you're in the hub hall
-- (not in a run, the training grounds or a trial): a standard Roblox-style orbit camera (free cursor, hold right mouse
-- to orbit -- AimRngClient feeds the angles), scroll to zoom, pulled in by walls, the character turning to face where it walks (turned here, see Update). The switch in and out is a smooth
-- pull-back / push-in through the eyes (Weight eases 0 <-> 1), so it never pops.
-- The character creator frames you from the front (Player attribute "CreatorOpen" = true, CreatorYaw = turntable).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local GameSettings = require(script.Parent:WaitForChild("GameSettings"))
local Zones = require(script.Parent:WaitForChild("Zones"))

local HubCamera = {}

local LocalPlayer = Players.LocalPlayer
local ZOOM_MIN, ZOOM_MAX, ZOOM_DEFAULT = 6, 20, 11
local SHOULDER = Vector3.new(0, 0.4, 0)   -- centred behind the character
local PIVOT_UP = 2.1                         -- orbit pivot above the root (neck height)
local EYE_UP = 1.5                           -- first-person eye height (matches AimRngClient CAM_EYE_HEIGHT)

local zoom = ZOOM_DEFAULT        -- wanted distance (scroll wheel)
local dist = ZOOM_DEFAULT        -- current distance (eased; walls pull it in instantly)
local weight = 0                 -- 0 = first person, 1 = full third person
local creatorW = 0               -- 0 = normal orbit, 1 = creator framing
local shiftLock = false          -- shift lock (toggle key, Settings > Controls): mouse turns the camera, body faces it
local shoulderW = 0              -- eased 0..1: the over-the-shoulder offset while shift locked
local showcaseYaw, showcaseBaseYaw = nil, nil -- the store's "view on character" orbit
local SHIFT_SHOULDER = Vector3.new(1.75, 0.4, 0)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

UserInputService.InputBegan:Connect(function(input, gp)
    if gp or weight < 0.5 or LocalPlayer:GetAttribute("CreatorOpen") then return end
    if input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode == GameSettings.KeyFor("ShiftLock") then
        shiftLock = not shiftLock
    end
end)

function HubCamera.ShiftLocked(): boolean return shiftLock end

UserInputService.InputChanged:Connect(function(input, gp)
    if input.UserInputType == Enum.UserInputType.MouseWheel and not gp and weight > 0.5 and not LocalPlayer:GetAttribute("CreatorOpen") then
        zoom = math.clamp(zoom - input.Position.Z * 1.5, ZOOM_MIN, ZOOM_MAX)
    end
end)

-- Should the hub camera be on right now?
function HubCamera.WantsThirdPerson(root: BasePart): boolean
    if LocalPlayer:GetAttribute("TryOnFP") then return false end -- (store try-on: in your own first-person view)
    if LocalPlayer:GetAttribute("CreatorOpen") or LocalPlayer:GetAttribute("Showcase") then return true end
    if LocalPlayer:GetAttribute("RunId") or LocalPlayer:GetAttribute("Downed") or LocalPlayer:GetAttribute("Spectating") then return false end
    local p = root.Position
    -- the Bazaar (trading hub) and hideouts are third person too, except a hideout's practice alcove (the dummy)
    local kind = Zones.Kind(p)
    if kind == "market" then return true end
    if kind == "hideout" then return not Zones.InHideoutRange(p) end
    -- the hub hall (the training grounds start past z = 75, dungeons at z >= 450)
    return math.abs(p.X) < 80 and p.Z > -80 and p.Z < 74 and p.Y < 70
end

function HubCamera.Weight(): number return weight end

-- Right-mouse orbit input for the hub camera: pixels the mouse moved this frame while right mouse is held (zero
-- otherwise). Reads the locked-mouse delta, and falls back to the cursor's own movement -- Roblox's default camera
-- scripts can reset the mouse lock, which zeroes the delta, so dragging with a free cursor still turns the camera.
local lastMouse: Vector2? = nil
HubCamera.PendingPad = Vector2.zero -- touch drags + the gamepad's right stick (PlatformControls), consumed per frame
function HubCamera.OrbitDelta(): Vector2
    local pad = HubCamera.PendingPad
    HubCamera.PendingPad = Vector2.zero
    if pad.Magnitude > 0 then return pad end
    if shiftLock then
        -- shift lock: the mouse is locked in the middle and every movement turns the camera
        if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter end
        if UserInputService.MouseIconEnabled then UserInputService.MouseIconEnabled = false end -- (no cursor pinned mid-screen)
        lastMouse = nil
        return UserInputService:GetMouseDelta()
    end
    local held = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    local want = held and Enum.MouseBehavior.LockCurrentPosition or Enum.MouseBehavior.Default
    if UserInputService.MouseBehavior ~= want then UserInputService.MouseBehavior = want end
    if not UserInputService.MouseIconEnabled then UserInputService.MouseIconEnabled = true end
    local loc = UserInputService:GetMouseLocation()
    if not held then lastMouse = nil return Vector2.zero end
    local d = UserInputService:GetMouseDelta()
    if d.Magnitude < 1e-3 and lastMouse then d = loc - lastMouse end
    lastMouse = loc
    return d
end

local function Ease(cur: number, target: number, k: number, dt: number): number
    return cur + (target - cur) * (1 - math.exp(-k * dt))
end

-- Advance the blend. Returns the camera CFrame while third person has any weight (nil = first person owns it).
-- yaw / pitch are the shared mouse-look angles; the character turns itself (AutoRotate) while in third person.
function HubCamera.Update(dt: number, char: Model, root: BasePart, hum: Humanoid, yaw: number, pitch: number): CFrame?
    local want = HubCamera.WantsThirdPerson(root)
    weight = Ease(weight, want and 1 or 0, want and 6 or 9, dt)
    if want and weight > 0.995 then weight = 1 elseif not want and weight < 0.01 then weight = 0 end
    local creator = LocalPlayer:GetAttribute("CreatorOpen") == true
    local showcase = LocalPlayer:GetAttribute("Showcase")
    creatorW = Ease(creatorW, (creator or showcase) and 1 or 0, 7, dt)
    local tp = weight > 0
    if (LocalPlayer:GetAttribute("ThirdPerson") == true) ~= tp then LocalPlayer:SetAttribute("ThirdPerson", tp) end
    if not tp then
        dist = 0.5
        return nil
    end

    -- Turn the character toward where it walks ourselves: the player is in first-person camera mode (server sets
    -- LockFirstPerson / zoom 0.5 for the shooter), which makes Roblox's own AutoRotate face the CAMERA -- the body
    -- spun with every orbit and you could never see your face.
    if hum.AutoRotate then hum.AutoRotate = false end
    local md = hum.MoveDirection
    shoulderW = Ease(shoulderW, (shiftLock and not creator) and 1 or 0, 10, dt)
    if shiftLock and not creator then
        -- shift lock: the body faces where the camera looks
        local look = root.CFrame.LookVector
        local cur = math.atan2(-look.X, -look.Z)
        local diff = (yaw - cur + math.pi) % (2 * math.pi) - math.pi
        if math.abs(diff) > 0.002 then
            root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, cur + diff * (1 - math.exp(-20 * dt)), 0)
        end
    elseif not creator and md.Magnitude > 0.1 then
        local look = root.CFrame.LookVector
        local cur = math.atan2(-look.X, -look.Z)
        local diff = (math.atan2(-md.X, -md.Z) - cur + math.pi) % (2 * math.pi) - math.pi
        if math.abs(diff) > 0.002 then
            root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, cur + diff * (1 - math.exp(-14 * dt)), 0)
        end
    end
    -- show the body once the camera has pulled back out of the head
    local ltm = weight > 0.35 and 0 or 1
    for _, d in ipairs(char:GetDescendants()) do
        if (d:IsA("BasePart") or d:IsA("Decal")) and d.LocalTransparencyModifier ~= ltm then d.LocalTransparencyModifier = ltm end -- (decals too: 2026-11-07)
    end

    -- orbit (normal) or the creator's front framing, blended
    local pivot = root.Position + Vector3.new(0, PIVOT_UP, 0)
    local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.clamp(pitch, -1.25, 1.0), 0, 0)
    local offset = (SHOULDER + (SHIFT_SHOULDER - SHOULDER) * shoulderW) * weight
    local wantDist = zoom
    if creatorW > 0.001 then
        -- in front of the character, a little to its left so the menu panel (screen left) doesn't cover it
        -- (fixed at the yaw the character faced when the creator opened, so spinning the character turns it on screen)
        local frontYaw = tonumber(LocalPlayer:GetAttribute("CreatorFrameYaw"))
        if not frontYaw then
            local facing = root.CFrame.LookVector
            frontYaw = math.atan2(facing.X, facing.Z) -- looking back at the character's face
        end
        if showcase and not creator then
            -- store "view on character": a slow orbit around you (from behind for wings), right-drag adds to it
            showcaseYaw = (showcaseYaw or 0) + dt * 0.35
            local orbitYaw = frontYaw + ((showcase == "Back") and math.pi or 0) + math.sin(showcaseYaw) * 0.9 + (yaw - (showcaseBaseYaw or yaw))
            showcaseBaseYaw = showcaseBaseYaw or yaw
            local cRot = CFrame.Angles(0, orbitYaw, 0) * CFrame.Angles(math.rad(-8), 0, 0)
            rot = rot:Lerp(cRot, creatorW)
            offset = offset:Lerp(Vector3.new(0, -0.3, 0), creatorW)
            wantDist = wantDist + (9.5 - wantDist) * creatorW
        else
            showcaseYaw, showcaseBaseYaw = nil, nil
            local cRot = CFrame.Angles(0, frontYaw, 0) * CFrame.Angles(math.rad(-6), 0, 0)
            local blendRot = rot:Lerp(cRot, creatorW)
            rot = blendRot
            offset = offset:Lerp(Vector3.new(-2.4, -0.4, 0), creatorW)
            wantDist = wantDist + (8.5 - wantDist) * creatorW
        end
    end
    -- pull-back blend: from the eyes (first person) to the full orbit
    local eye = root.Position + Vector3.new(0, EYE_UP, 0)
    local base = eye:Lerp(pivot, weight)
    local target = wantDist * weight
    -- walls pull the camera in immediately; it eases back out
    local origin = base + rot:VectorToWorldSpace(Vector3.new(offset.X, offset.Y, 0))
    local back = rot.LookVector * -1
    -- (2026-10-07, owner: "your hideout currently doesnt allow you to look around": invisible / see-through parts -- the
    -- furniture's hit boxes, the balcony barriers -- pulled the camera into your head. Only solid, visible geometry counts)
    local ignore = { char, Workspace.CurrentCamera }
    params.FilterDescendantsInstances = ignore
    local hit = Workspace:Raycast(base, (origin - base) + back * (target + 0.6), params)
    -- (2026-10-13, hideouts: the themed rooms' walls are visual, NON-colliding parts -- the camera went straight through the
    -- door wall and showed a flat colour until you turned. A visible part big enough to be a wall blocks even without collision)
    for _ = 1, 8 do
        local inst = hit and hit.Instance
        local ghost = inst and inst:IsA("BasePart") and not inst:GetAttribute("CamSolid") and (inst.Transparency > 0.6
            or (not inst.CanCollide and math.max(inst.Size.X, inst.Size.Y, inst.Size.Z) < 4))
        if not ghost then break end
        table.insert(ignore, inst)
        params.FilterDescendantsInstances = ignore
        hit = Workspace:Raycast(base, (origin - base) + back * (target + 0.6), params)
    end
    local maxDist = target
    if hit then
        local reach = (hit.Position - origin):Dot(back) - 0.6
        maxDist = math.clamp(reach, 0.3, target)
    end
    if maxDist < dist then dist = maxDist else dist = Ease(dist, maxDist, 8, dt) end
    return CFrame.new(origin + back * dist) * (rot - rot.Position)
end

return HubCamera
