--!nocheck
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
-- (2026-10-13 R6: Studio's Avatar Settings lost the R6 option, so the server builds every character itself -- R6Spawner,
-- started below once the join hooks are connected. Set first thing, before any player can be auto-loaded as R15.)
Players.CharacterAutoLoads = false

local function GetModule(name: string): any
    local mod = script:FindFirstChild(name) or (script.Parent and script.Parent:FindFirstChild(name))
    if not mod then
        mod = script:WaitForChild(name, 5) or (script.Parent and script.Parent:WaitForChild(name, 5))
    end
    if not mod then
        error("[AimRngRogue] Failed to find module: " .. name)
    end
    return require(mod :: ModuleScript)
end

local HubGenerator = GetModule("HubGenerator")
local DungeonGenerator = GetModule("DungeonGenerator")
local CombatServer = GetModule("CombatServer")
local SkillTreeServer = GetModule("SkillTreeServer")
pcall(function() GetModule("MovementSanity").Start() end) -- (log-only movement sanity checks)
local Remotes = require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("Remotes"))

print("[AimRngRogue] Server starting...")
-- (FUTURE-PROOF 2026-10-25) Studio: every content registry checked for half-added entries (AimRngShared/ContentCheck, docs/EXTENDING.md)
if game:GetService("RunService"):IsStudio() then
    task.delay(3, function()
        local ok, rep = pcall(function() return require(game.ReplicatedStorage:WaitForChild("AimRngShared"):WaitForChild("ContentCheck")).Report() end)
        if not ok then warn("[ContentCheck] failed: " .. tostring(rep)) elseif string.find(rep, "ERROR", 1, true) or string.find(rep, "WARN", 1, true) then warn(rep) else print(rep) end
    end)
end

-- 0. Weapon mesh measurement + grip probe (runs once at startup, results replicate to every client).
--    a) Exact native size of every weapon mesh ("m<assetId>" = Vector3) -- a SpecialMesh can't report
--       its bounds, but a MeshPart built from the same MeshId can (MeshSize).
--    b) For every gun, a physical copy is posed exactly as the viewmodel shows it and its side silhouette
--       is scanned with raycasts. From that profile we find where the pistol grip / stock wrist, the
--       handguard and the muzzle really are ("rig_<BaseId>" = JSON). The client wraps the hands around
--       those points instead of guessing from fixed fractions -- this is what makes every gun's hold fit.
--    Purely cosmetic: anything that fails falls back to the client's per-class defaults.
task.spawn(function()
    local AssetService = game:GetService("AssetService")
    local HttpService = game:GetService("HttpService")
    local shared = game.ReplicatedStorage:WaitForChild("AimRngShared")
    local boundsFolder = shared:FindFirstChild("MeshBounds") or Instance.new("Folder")
    boundsFolder.Name = "MeshBounds"
    boundsFolder.Parent = shared
    local okMod, WeaponMeshes = pcall(function() return require(shared:WaitForChild("WeaponMeshes")) end)
    local okItems, ItemData = pcall(function() return require(shared:WaitForChild("ItemData")) end)
    if not okMod then return end

    -- c) A render-ready MeshPart template of every weapon mesh ("m<assetId>" in AimRngShared.MeshTemplates).
    --    The client draws viewmodel guns by cloning these, so what you see is EXACTLY the geometry the grip
    --    probe measured (a SpecialMesh can center/scale some legacy meshes differently, which is what put
    --    hands slightly off on some guns).
    local templatesFolder = shared:FindFirstChild("MeshTemplates") or Instance.new("Folder")
    templatesFolder.Name = "MeshTemplates"
    templatesFolder.Parent = shared
    local function MakeTemplate(id: string, precise: MeshPart)
        local ok, tpl = pcall(function()
            return AssetService:CreateMeshPartAsync("rbxassetid://" .. id, {
                CollisionFidelity = Enum.CollisionFidelity.Box,
                RenderFidelity = Enum.RenderFidelity.Precise,
            })
        end)
        if not ok or not tpl then tpl = precise:Clone() end
        tpl.Name = "m" .. id
        tpl.Anchored = true
        tpl.CanCollide = false
        tpl.CanQuery = false
        tpl.CanTouch = false
        tpl.CastShadow = false
        tpl.Size = tpl.MeshSize
        tpl.Parent = templatesFolder
    end

    local meshCache: { [string]: any } = {}
    local function LoadMesh(id: string): MeshPart?
        if meshCache[id] ~= nil then return meshCache[id] or nil end
        local ok, mp = pcall(function()
            return AssetService:CreateMeshPartAsync("rbxassetid://" .. id, {
                CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition,
                RenderFidelity = Enum.RenderFidelity.Performance,
            })
        end)
        if not ok then
            ok, mp = pcall(function() return AssetService:CreateMeshPartAsync("rbxassetid://" .. id) end)
        end
        if ok and mp then
            meshCache[id] = mp
            boundsFolder:SetAttribute("m" .. id, mp.MeshSize)
            pcall(MakeTemplate, id, mp)
            return mp
        end
        meshCache[id] = false
        warn("[AimRngRogue] Mesh bounds unavailable for " .. id .. " (using fallback): " .. tostring(mp))
        return nil
    end

    for _, group in ipairs({ WeaponMeshes.Guns, WeaponMeshes.Melee }) do
        for _, data in pairs(group) do
            local id = tostring(data.MeshId):match("(%d+)")
            if id then LoadMesh(id) end
        end
    end

    local PROBE_ORIGIN = Vector3.new(3000, 3000, 3000)
    local NZ, NY = 56, 36
    local probeFolder = Instance.new("Folder")
    probeFolder.Name = "AimRngMeshProbe"
    probeFolder.Parent = Workspace

    local function R3(n: number): number return math.round(n * 1000) / 1000 end

    local function ProbeGunRig(baseId: string, data: any, src: MeshPart): any
        local s = data.Scale
        local mp = src:Clone()
        mp.Size = src.MeshSize * Vector3.new(math.abs(s.X), math.abs(s.Y), math.abs(s.Z))
        -- Negative Scale components mirror the mesh. Keep the rotation part (flip back whichever mesh
        -- axis ends up as the viewmodel's sideways X, so any leftover mirror only swaps left/right).
        local sx, sy, sz = math.sign(s.X), math.sign(s.Y), math.sign(s.Z)
        local orient = data.Orient or CFrame.new()
        if sx * sy * sz < 0 then
            local cols = { orient.XVector, orient.YVector, orient.ZVector }
            local bi, best = 1, -1
            for i, c in ipairs(cols) do if math.abs(c.X) > best then best = math.abs(c.X); bi = i end end
            if bi == 1 then sx = -sx elseif bi == 2 then sy = -sy else sz = -sz end
        end
        local R = orient * CFrame.fromMatrix(Vector3.zero, Vector3.new(sx, 0, 0), Vector3.new(0, sy, 0), Vector3.new(0, 0, sz))
        mp.Anchored = true
        mp.CanCollide = false
        mp.CanTouch = false
        mp.CanQuery = true
        mp.Transparency = 1
        mp.CFrame = CFrame.new(PROBE_ORIGIN) * R
        mp.Parent = probeFolder

        local a, b, c = R.XVector, R.YVector, R.ZVector
        local sz3 = mp.Size
        local ext = Vector3.new(
            math.abs(a.X) * sz3.X + math.abs(b.X) * sz3.Y + math.abs(c.X) * sz3.Z,
            math.abs(a.Y) * sz3.X + math.abs(b.Y) * sz3.Y + math.abs(c.Y) * sz3.Z,
            math.abs(a.Z) * sz3.X + math.abs(b.Z) * sz3.Y + math.abs(c.Z) * sz3.Z)

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = { mp }

        local dz, dy = ext.Z / NZ, ext.Y / NY
        local halfX = ext.X / 2 + 0.5
        local function Z(zi: number): number return -ext.Z / 2 + (zi - 0.5) * dz end
        local function Y(yi: number): number return -ext.Y / 2 + (yi - 0.5) * dy end

        -- Side silhouette: occ[zi][yi] = {xLeft, xRight}; bottom/top = lowest/highest filled row per column.
        local occ, bottom, top = {}, {}, {}
        for zi = 1, NZ do
            occ[zi] = {}
            for yi = 1, NY do
                local y, z = Y(yi), Z(zi)
                local hitR = Workspace:Raycast(PROBE_ORIGIN + Vector3.new(halfX, y, z), Vector3.new(-2 * halfX, 0, 0), params)
                if hitR then
                    local hitL = Workspace:Raycast(PROBE_ORIGIN + Vector3.new(-halfX, y, z), Vector3.new(2 * halfX, 0, 0), params)
                    local xr = hitR.Position.X - PROBE_ORIGIN.X
                    local xl = hitL and (hitL.Position.X - PROBE_ORIGIN.X) or -xr
                    occ[zi][yi] = { xl, xr }
                    if not bottom[zi] then bottom[zi] = yi end
                    top[zi] = yi
                end
            end
        end
        mp:Destroy()

        local frontZi, rearZi
        local bottomsSorted = {}
        for zi = 1, NZ do
            if bottom[zi] then
                frontZi = frontZi or zi
                rearZi = zi
                table.insert(bottomsSorted, bottom[zi])
            end
        end
        if #bottomsSorted < 6 then return nil end
        table.sort(bottomsSorted)
        -- Receiver/barrel underside: most columns sit here; grips, magazines and stocks hang below it.
        local baseline = bottomsSorted[math.max(1, math.floor(#bottomsSorted * 0.65))]
        local margin = math.max(2, math.floor(NY * 0.12))

        local segments = {}
        local cur = nil
        for zi = frontZi, rearZi do
            local isDrop = bottom[zi] ~= nil and bottom[zi] <= baseline - margin
            if isDrop then
                if cur and zi - cur.e <= 2 then
                    cur.e = zi
                    cur.minB = math.min(cur.minB, bottom[zi])
                else
                    cur = { s = zi, e = zi, minB = bottom[zi] }
                    table.insert(segments, cur)
                end
            end
        end

        local class = (okItems and ItemData.BaseWeapons[baseId] and ItemData.BaseWeapons[baseId].Class) or "Rifle"
        local pistolLike = (class == "Pistol" or class == "Revolver")
        local last = segments[#segments]
        local stockSeg = (not pistolLike and last and last.e >= rearZi - 1) and last or nil
        local cands = {}
        for _, seg in ipairs(segments) do
            if seg ~= stockSeg then table.insert(cands, seg) end
        end
        local gripSeg = cands[#cands]
        if gripSeg and stockSeg and (stockSeg.s - gripSeg.e) > NZ * 0.18 then
            gripSeg = nil -- too far ahead of the stock to be a pistol grip: that's a magazine
        end
        if pistolLike and not gripSeg then gripSeg = last end

        -- Center (z) and front-to-back depth of the filled span on one row, within a column window.
        local function RowSpan(yi: number, zs: number, ze: number): (number?, number?)
            local zf, zb
            for zi = math.max(frontZi, zs), math.min(rearZi, ze) do
                if occ[zi][yi] then
                    zf = zf or zi
                    zb = zi
                end
            end
            if not zf then return nil, nil end
            return (Z(zf) + Z(zb)) / 2, (zb - zf + 1) * dz
        end

        local rig: any = { Ext = { R3(ext.X), R3(ext.Y), R3(ext.Z) } }
        if gripSeg then
            local gh = baseline - gripSeg.minB
            -- Only columns reaching at least halfway down count as the grip itself -- this drops shallow
            -- neighbors like the trigger guard, which would otherwise drag the hand forward.
            local gs, ge = nil, nil
            for zi = gripSeg.s, gripSeg.e do
                if bottom[zi] and bottom[zi] <= baseline - 0.5 * gh then
                    gs = gs or zi
                    ge = zi
                end
            end
            gs, ge = gs or gripSeg.s, ge or gripSeg.e
            local handYi = math.clamp(math.round(baseline - 0.38 * gh), 1, NY)
            local zc, depth = RowSpan(handYi, gs, ge)
            if zc then
                local ztop = RowSpan(math.clamp(math.round(baseline - 0.12 * gh), 1, NY), gs, ge)
                local zbot = RowSpan(math.clamp(math.round(baseline - 0.82 * gh), 1, NY), gs, ge)
                local rake = 0.25
                if ztop and zbot then
                    rake = math.clamp(math.atan2(zbot - ztop, 0.7 * gh * dy), -0.2, 0.65)
                end
                local czi = math.clamp(math.round((zc + ext.Z / 2) / dz + 0.5), 1, NZ)
                local cell = occ[czi][handYi] or { -0.05, 0.05 }
                rig.Grip = { R3((cell[1] + cell[2]) / 2), R3(Y(handYi)), R3(zc) }
                rig.GripD = R3(depth)
                rig.GripW = R3(cell[2] - cell[1])
                rig.Rake = R3(rake)
            end
        elseif stockSeg then
            -- Straight-stock long gun (no pistol grip): the hand wraps the wrist at the front of the stock.
            local zi = stockSeg.s
            local midYi = math.round((bottom[zi] + top[zi]) / 2)
            local cell = occ[zi][midYi] or occ[zi][bottom[zi]]
            rig.Grip = { R3((cell[1] + cell[2]) / 2), R3(Y(midYi)), R3(Z(zi)) }
            rig.GripD = R3(math.max(3 * dz, 0.2 * (top[zi] - bottom[zi]) * dy))
            rig.GripW = R3(cell[2] - cell[1])
            rig.Rake = 0.55
        end

        if rig.Grip and not pistolLike then
            local gz, fz = rig.Grip[3], Z(frontZi)
            local targetZ = gz - (gz - fz) * 0.5
            local zi = math.clamp(math.round((targetZ + ext.Z / 2) / dz + 0.5), frontZi, rearZi)
            local guard = 0
            while zi > frontZi and (not bottom[zi] or bottom[zi] <= baseline - margin) and guard < NZ do
                zi -= 1 -- slide forward off the magazine
                guard += 1
            end
            if bottom[zi] then
                local wy = math.min(bottom[zi] + 1, top[zi])
                local cell = occ[zi][wy] or occ[zi][bottom[zi]]
                rig.Support = { R3((cell[1] + cell[2]) / 2), R3(Y(bottom[zi]) - dy * 0.5), R3(Z(zi)) }
                rig.SupportW = R3(cell[2] - cell[1])
                rig.SupportH = R3((top[zi] - bottom[zi] + 1) * dy)
            end
        end

        local mb, mt = bottom[frontZi], top[frontZi]
        rig.Muzzle = { 0, R3((Y(mb) + Y(mt)) / 2), R3(Z(frontZi) - dz / 2) }
        return rig
    end

    for baseId, data in pairs(WeaponMeshes.Guns) do
        local id = tostring(data.MeshId):match("(%d+)")
        local src = id and meshCache[id]
        if src then
            local ok, rig = pcall(ProbeGunRig, baseId, data, src)
            if ok and rig then
                boundsFolder:SetAttribute("rig_" .. baseId, HttpService:JSONEncode(rig))
            else
                warn("[AimRngRogue] Grip probe failed for " .. baseId .. " (using class default): " .. tostring(rig))
            end
            task.wait()
        end
    end
    probeFolder:Destroy()
    for _, mp in pairs(meshCache) do
        if mp then mp:Destroy() end
    end
end)

-- 1. Build Peaceful Hub (or connect to pre-built HubWorld in Workspace)
local hub = Workspace:FindFirstChild("HubWorld")
if not hub then
    hub = HubGenerator.BuildHub()
else
    HubGenerator.SetupLighting()
end

-- 1b. THE BAZAAR (0.55): the trading hub west of the city (HubMarket). Its prompts: trade tables open the TRADE window,
-- the furniture stall the hideout furniture shop, the city gate takes you back to the hub.
do
    local HubMarket = GetModule("HubMarket")
    local okM, market = pcall(HubMarket.Build)
    if okM and market then
        for _, d in ipairs(market:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                d.Triggered:Connect(function(player)
                    if d.Name == "PromptTrade" then Remotes.GetEvent("OpenMenu"):FireClient(player, "Trade")
                    elseif d.Name == "PromptFurniture" then Remotes.GetEvent("OpenMenu"):FireClient(player, "HideoutShop")
                    elseif d.Name == "PromptCity" then Remotes.GetEvent("TeleportPlayer"):FireClient(player, "Goto", CFrame.lookAt(Vector3.new(0, 6, 24), Vector3.new(0, 6, 0))) end
                end)
            end
        end
    else
        warn("[AimRngRogue] Bazaar build failed: " .. tostring(market))
    end
end

-- 2. Dungeons are private and built on each player's own client (see DungeonRuns), so the server builds
-- none. A DungeonFacility left in the place file from the shared-dungeon days is removed.
local oldDungeon = Workspace:FindFirstChild("DungeonFacility")
if oldDungeon then oldDungeon:Destroy() end

-- Players never collide with each other: every private dungeon sits at the same coordinates.
do
    local PhysicsService = game:GetService("PhysicsService")
    pcall(function() PhysicsService:RegisterCollisionGroup("AimRngPlayers") end)
    PhysicsService:CollisionGroupSetCollidable("AimRngPlayers", "AimRngPlayers", false)
end

-- 3. Init Combat & Skill Systems
CombatServer.Init()
SkillTreeServer.Init()
GetModule("AvatarService").Init(CombatServer) -- custom characters (character creator)
GetModule("EndgameServer").Init(CombatServer) -- Daily Challenge, Aim Trials, leaderboards
GetModule("AdminService").Init(CombatServer) -- the owner's gift panel (F6; admins only, checked server-side)
GetModule("TradeService").Init(CombatServer) -- player trades (0.55)
GetModule("PvpService").Init(CombatServer) -- duels (0.59)
GetModule("Hideouts").Init(CombatServer, HubGenerator) -- player hideouts (0.55)
GetModule("SpectateService").Init(CombatServer) -- watch players in runs from the city (0.62)
GetModule("AtlasService").Init(CombatServer) -- the MAP TREE (points, take / refund)
GetModule("SharedSpoils").Init(CombatServer) -- (UPDATE 7 B4) party seals -> a shared pick
GetModule("MarketService").Init(CombatServer) -- (UPDATE 7 C7) the offline market
GetModule("PartyHud").Init(CombatServer) -- (QOL2 H4) teammates' HP / party id attributes for the client's party HUD
GetModule("MapRefund").Init(CombatServer) -- (QOL2 R5) a map left (game quit) before its floor 1 was cleared comes back once on the next join
GetModule("GuildService").Init(CombatServer) -- (UPDATE 7 B9) guilds
GetModule("PartyFinder").Init(CombatServer) -- (2026-10-20) open parties from every server (cross-server board + teleport)
GetModule("ProfileService").Init(CombatServer) -- (2026-10-20) player profiles: inspect anyone's gear / build + the aim profile
GetModule("ReferralService").Init(CombatServer) -- (2026-10-20) friend invites: both get BOUND points when a new friend gets going
-- (UPDATE 7 A6 + B5) THE LIVING HUB: district leaders, the Hall of Aim statues, the drop board
do
    local okL, err = pcall(function()
        local LivingHub = GetModule("LivingHub")
        local EG = GetModule("EndgameServer")
        LivingHub.Build(hub, {
            TopOf = EG.TopOf,
            OpenDistricts = function(player, id)
                local st = CombatServer.GetState(player)
                local D = require(game.ReplicatedStorage.AimRngShared.Districts)
                if st and D.Unlocked(st) then -- (today's bounties are rolled the moment you talk to a leader)
                    D.Ensure(st, player.UserId)
                    Remotes.GetEvent("SyncPlayerState"):FireClient(player, st)
                end
                Remotes.GetEvent("OpenMenu"):FireClient(player, "Districts", id)
            end,
            OpenMarket = function(player) Remotes.GetEvent("OpenMenu"):FireClient(player, "Market") end, -- (UPDATE 7 C7)
            OpenSupply = function(player) Remotes.GetEvent("OpenMenu"):FireClient(player, "ShotMods", "SUPPLY") end, -- (MOD SUPPLY 2026-11-07)
            OpenProfile = function(player, uid) Remotes.GetEvent("OpenMenu"):FireClient(player, "Profile", uid) end, -- (2026-10-20 statues)
        })
        CombatServer.OnDropFeed = LivingHub.NoteDrop
    end)
    if not okL then warn("[AimRngRogue] Living hub failed: " .. tostring(err)) end
end
GetModule("ErrorLog").Init() -- live error log: server + client script errors, read in the F6 admin panel (launch)
-- test / admin commands: everywhere for the ADMIN MENU (admin-checked in AdminService); the play-test hooks only in Studio
GetModule("DevCommands").Init(CombatServer)

-- Runs end on their own when the player leaves the arena (DungeonRuns); nothing shared to clean up.
local function CheckAndClearEmptyArena() end

-- 4. Hook In-World Proximity Prompts
local function ConnectPrompts()
    local rollAltar = hub:WaitForChild("RollAltar", 10)
    local treeAltar = hub:WaitForChild("TreeAltar", 10)
    local invLocker = hub:WaitForChild("InvLocker", 10)
    local upgAnvil = hub:WaitForChild("UpgradeAnvil", 10)
    local shopStand = hub:WaitForChild("ShopStand", 10)
    local indexAltar = hub:WaitForChild("IndexAltar", 10)
    local portalVortex = hub:WaitForChild("PortalVortex", 10) :: BasePart?

    if rollAltar then
        local p = rollAltar:WaitForChild("PromptRoll", 5) :: ProximityPrompt?
        if p then
            p.Triggered:Connect(function(player)
                Remotes.GetEvent("OpenMenu"):FireClient(player, "Roll")
            end)
        end
    end

    if treeAltar then
        local p = treeAltar:WaitForChild("PromptTree", 5) :: ProximityPrompt?
        if p then
            p.Triggered:Connect(function(player)
                Remotes.GetEvent("OpenMenu"):FireClient(player, "Skills")
            end)
        end
    end

    if invLocker then
        local p = invLocker:WaitForChild("PromptInv", 5) :: ProximityPrompt?
        if p then
            p.Triggered:Connect(function(player)
                Remotes.GetEvent("OpenMenu"):FireClient(player, "Inventory")
            end)
        end
    end

    if shopStand then
        local p = shopStand:WaitForChild("PromptShop", 5) :: ProximityPrompt?
        if p then
            p.Triggered:Connect(function(player)
                Remotes.GetEvent("OpenMenu"):FireClient(player, "Shop")
            end)
        end
    end

    if upgAnvil then
        local p = upgAnvil:WaitForChild("PromptUpgrade", 5) :: ProximityPrompt?
        if p then
            p.Triggered:Connect(function(player)
                Remotes.GetEvent("OpenMenu"):FireClient(player, "Upgrade")
            end)
        end
    end

    if indexAltar then
        local p = indexAltar:WaitForChild("PromptIndex", 5) :: ProximityPrompt?
        if p then
            p.Triggered:Connect(function(player)
                Remotes.GetEvent("OpenMenu"):FireClient(player, "Index")
            end)
        end
    end

    -- hub v2 stations / gates
    for _, spec in ipairs({ { "ChallengeVortex", "PromptChallenges", "Challenges" }, { "ArmoryStand", "PromptArmory", "Armory" }, { "SeasonStand", "PromptSeason", "Season" }, { "StyleStand", "PromptStyle", "Creator" } }) do
        local part = hub:FindFirstChild(spec[1])
        local p = part and part:FindFirstChild(spec[2])
        if p then
            p.Triggered:Connect(function(player)
                Remotes.GetEvent("OpenMenu"):FireClient(player, spec[3])
            end)
        end
    end

    if portalVortex then
        local p = portalVortex:WaitForChild("PromptDungeon", 5) :: ProximityPrompt?
        if p then
            p.Triggered:Connect(function(player)
                Remotes.GetEvent("OpenMenu"):FireClient(player, "Dungeons")
            end)
        end
    end

    -- Return Gate In-World trigger
    task.spawn(function()
        while true do
            local dFacility = Workspace:FindFirstChild("DungeonFacility")
            if dFacility then
                local returnGate = dFacility:FindFirstChild("ReturnGate") :: BasePart?
                if returnGate and not returnGate:GetAttribute("Hooked") then
                    returnGate:SetAttribute("Hooked", true)
                    local returnPrompt = returnGate:WaitForChild("PromptReturnHub", 5) :: ProximityPrompt?

                    local function ReturnToHub(player: Player)
                        local char = player.Character
                        if char then
                            char:PivotTo(CFrame.lookAt(Vector3.new(0, 6, 24), Vector3.new(0, 6, 0)))
                            local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
                            if root then
                                root.CFrame = CFrame.lookAt(Vector3.new(0, 6, 24), Vector3.new(0, 6, 0))
                                root.AssemblyLinearVelocity = Vector3.zero
                            end
                        end
                        Remotes.GetEvent("TeleportPlayer"):FireClient(player, "Hub")
                        task.wait(0.2)
                        CheckAndClearEmptyArena()
                    end

                    if returnPrompt then
                        returnPrompt.Triggered:Connect(ReturnToHub)
                    end
                    returnGate.Touched:Connect(function(hit)
                        local p = Players:GetPlayerFromCharacter(hit.Parent)
                        if p then ReturnToHub(p) end
                    end)
                end
            end
            task.wait(1)
        end
    end)

    portalVortex.Touched:Connect(function(hit)
        local p = Players:GetPlayerFromCharacter(hit.Parent)
        if p then Remotes.GetEvent("OpenMenu"):FireClient(p, "Dungeons") end
    end)
end
task.spawn(ConnectPrompts)

-- (owner 2026-10-07: "Respawning in the hub should be instant") no respawn countdown
Players.RespawnTime = 0

local function SetupPlayer(player: Player)
    player.CameraMinZoomDistance = 0.5
    player.CameraMaxZoomDistance = 0.5
    player.CameraMode = Enum.CameraMode.LockFirstPerson
    -- Roblox's own Shift Lock binds Shift (for players with "Shift Lock Switch" on in their Roblox settings -- live
    -- games only, never in Studio playtests) and swallows it, which killed the dash in the published game. Our hub has
    -- its own shift lock (HubCamera), so Roblox's is off (also StarterPlayer.EnableMouseLockOption = false).
    player.DevEnableMouseLock = false

    player.CharacterAdded:Connect(function(char)
        local function groupPart(d: Instance)
            if d:IsA("BasePart") then d.CollisionGroup = "AimRngPlayers" end
        end
        for _, d in ipairs(char:GetDescendants()) do groupPart(d) end
        char.DescendantAdded:Connect(groupPart)
        local root = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
        -- (2026-10-07, owner: "respawning often bugs you out in the hub and you fall over": y 5 put the legs inside the street
        -- (its top is y 4) and physics knocked the character over -- stand ON it: the whole rig, feet on the street)
        if root then char:PivotTo(CFrame.lookAt(Vector3.new(0, 7.2, 24), Vector3.new(0, 7.2, 0))) end
        local state = CombatServer.GetState(player)
        CombatServer.UpdatePlayerTitleTag(player)
        -- the avatar's appearance loads after this and swaps in a new Head (the title tag went with the old one)
        char.ChildAdded:Connect(function(c)
            if c.Name == "Head" and c:IsA("BasePart") then task.defer(CombatServer.UpdatePlayerTitleTag, player) end
        end)
        Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
        CheckAndClearEmptyArena()
    end)

    if player.Character then
        local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if root then root.CFrame = CFrame.lookAt(Vector3.new(0, 5, 24), Vector3.new(0, 5, 0)) end -- (HUB v4: south of the waypoint)
        local state = CombatServer.GetState(player)
        CombatServer.UpdatePlayerTitleTag(player)
        Remotes.GetEvent("SyncPlayerState"):FireClient(player, state)
    end
end

Players.PlayerAdded:Connect(SetupPlayer)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(SetupPlayer, p)
end
-- every character is an R6 copy of the player's own avatar, made by the server (join + respawn): R6Spawner
-- (if it can't start, Roblox spawns characters again -- R15 then, but nobody is left without one)
local okR6, errR6 = pcall(function() GetModule("R6Spawner").Init() end)
if not okR6 then
    warn("[AimRngRogue] R6Spawner failed, back to Roblox spawning: " .. tostring(errR6))
    Players.CharacterAutoLoads = true
    for _, p in ipairs(Players:GetPlayers()) do if not p.Character then task.spawn(function() p:LoadCharacter() end) end end
end
