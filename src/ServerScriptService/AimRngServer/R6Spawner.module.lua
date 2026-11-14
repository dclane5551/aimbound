--!nocheck
-- R6 SPAWNER (2026-10-13, owner: "yes, test it please"). Every character is R6 like Rivals -- the gloves, sleeves, guns,
-- melees, dash / slide poses and title tags are built for the R6 body -- but Studio's new Avatar Settings window has no R6
-- option any more, so characters spawned R15. Now the server builds every character itself:
--   Players.CharacterAutoLoads = false (also set as the place property); on join and after every death
--   Spawn(player) = the player's own avatar (Players:GetHumanoidDescriptionFromUserId, cached per player, 3 tries, a plain
--   description if it can't be fetched) -> Players:CreateHumanoidModelFromDescription(desc, R6) (body colours, clothes,
--   accessories, face; it carries its own R6 Animate script) -> named after the player, put on the hub spawn, network
--   owner = the player, player.Character = it. CharacterAppearanceLoaded never fires for a character made this way, so
--   AvatarRev (world gear re-fits) is bumped here, once at spawn and once a moment later for late accessories.
--   Respawn: Humanoid.Died -> after Players.RespawnTime (0: instant) a fresh character, unless something else already
--   replaced it. Nothing in the game calls player:LoadCharacter (runs move you, they never kill the Humanoid).
-- R6Spawner.Spawn(player) is the one way to (re)make a character; R6Spawner.Description(player) the cached look.
local Players = game:GetService("Players")

local R6Spawner = {}
local descs: { [Player]: HumanoidDescription } = {}
local spawning: { [Player]: boolean } = {}
local HUB_SPAWN = CFrame.lookAt(Vector3.new(0, 7.2, 24), Vector3.new(0, 7.2, 0)) -- (the street top is y 4: feet on it)

function R6Spawner.Description(player: Player): HumanoidDescription
    local d = descs[player]
    if d then return d end
    for attempt = 1, 3 do
        local ok, res = pcall(function() return Players:GetHumanoidDescriptionFromUserId(math.max(1, player.UserId)) end)
        if ok and res then d = res break end
        warn("[R6Spawner] avatar look for " .. player.Name .. " failed (" .. tostring(res) .. "), try " .. attempt)
        task.wait(attempt)
    end
    d = d or Instance.new("HumanoidDescription")
    descs[player] = d
    return d
end

-- (2026-10-21) Roblox's avatar loader can hang (CreateHumanoidModelFromDescription never returned for a whole Studio
-- session: the owner was left as a camera on the floor). After BUILD_TIMEOUT s the player gets a plain body; the late
-- real one is thrown away and the next respawn tries the real look again.
local BUILD_TIMEOUT = 8

local function Build(player: Player, desc: HumanoidDescription): (boolean, any)
    return pcall(function()
        local m = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
        m.Name = player.Name
        -- (2026-10-13) no Roblox Animate: every client poses R6 bodies in code (AimRngShared/CharacterPoser)
        local anim = m:FindFirstChild("Animate")
        if anim then anim:Destroy() end
        local hum = m:FindFirstChildOfClass("Humanoid")
        if hum then hum.DisplayName = player.DisplayName end
        m:PivotTo(HUB_SPAWN)
        return m
    end)
end

function R6Spawner.Spawn(player: Player): Model?
    if spawning[player] or not player.Parent then return nil end
    spawning[player] = true
    local done, ok, model = false, false, nil
    task.spawn(function()
        local slow = game:GetService("RunService"):IsStudio() and workspace:GetAttribute("DevSlowAvatar") -- (test hook: s)
        if slow then task.wait(slow) end
        local rOk, rModel = Build(player, R6Spawner.Description(player):Clone())
        if done then -- too late: the plain body is already in use
            if rOk and typeof(rModel) == "Instance" then rModel:Destroy() end
            return
        end
        done, ok, model = true, rOk, rModel
    end)
    local t0 = os.clock()
    while not done and os.clock() - t0 < BUILD_TIMEOUT and player.Parent do task.wait(0.1) end
    if not done then
        done = true
        warn("[R6Spawner] avatar for " .. player.Name .. " took over " .. BUILD_TIMEOUT .. " s: plain body this life")
        ok, model = Build(player, Instance.new("HumanoidDescription"))
    end
    spawning[player] = nil
    if not ok or not model or not player.Parent then
        warn("[R6Spawner] could not build " .. player.Name .. "'s character: " .. tostring(model))
        return nil
    end
    local old = player.Character
    player.Character = model
    model.Parent = workspace
    if old and old ~= model then old:Destroy() end
    local root = model:FindFirstChild("HumanoidRootPart")
    if root then pcall(function() root:SetNetworkOwner(player) end) end
    model:SetAttribute("AvatarRev", (model:GetAttribute("AvatarRev") or 0) + 1)
    task.delay(1.5, function() -- (accessory meshes can arrive a moment later: world gear re-fits once more)
        if model.Parent then model:SetAttribute("AvatarRev", (model:GetAttribute("AvatarRev") or 0) + 1) end
    end)
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function()
            task.wait(Players.RespawnTime)
            if player.Parent and player.Character == model then R6Spawner.Spawn(player) end
        end)
    end
    -- (a character removed without dying -- fell past FallenPartsDestroyHeight, destroyed by a script -- gets a new one too)
    model.AncestryChanged:Connect(function()
        if model:IsDescendantOf(workspace) then return end
        task.defer(function()
            if player.Parent and player.Character == model and not model:IsDescendantOf(workspace) then R6Spawner.Spawn(player) end
        end)
    end)
    return model
end

-- call once, AFTER every PlayerAdded / CharacterAdded hook of the game is connected (they see the first character too)
function R6Spawner.Init()
    Players.CharacterAutoLoads = false
    local function Join(player: Player)
        task.spawn(function()
            -- a character Roblox loaded before this ran (a Studio play-solo join can beat the server script) is R15:
            -- replaced like any other
            local c = player.Character
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if hum and hum.RigType == Enum.HumanoidRigType.R6 then return end
            R6Spawner.Spawn(player)
        end)
    end
    Players.PlayerAdded:Connect(Join)
    for _, p in ipairs(Players:GetPlayers()) do Join(p) end
    Players.PlayerRemoving:Connect(function(p) descs[p] = nil; spawning[p] = nil end)
end

return R6Spawner
