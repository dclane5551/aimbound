--!nocheck
-- ============================================================================================
-- LIVING HUB (UPDATE 7 A6): the city's plaza gets people.
--   DISTRICT LEADERS: one R6 figure per city district (Districts.Defs: name, colour), each with a name plate and a
--     ProximityPrompt "DistrictLeader" (attr District) that opens the QUARTERS window on that district. Two stand against the
--     wall between the gates, flanking the Hall of Aim; the Wire Market's leader at the west market stall, across from the
--     Exchange stall (one plate per spot: side by side they overlapped).
--     Client CharacterPoser poses them (tag AimPoseDummy: breathing idle). No animation assets.
--   HALL OF AIM: statues of the top three on the HIGHEST LEVEL board, cast from their own avatars in gold / silver / bronze
--     stone on a row of plinths against the gate wall, with name + level; rebuilt every STATUE_EVERY seconds when they change.
--   DROPS: the server's last DROP_ROWS big drops (CombatServer.AnnounceDrop -> NoteDrop), published as
--     ReplicatedStorage.Leaderboards.Drops (Kind "drop") for the RECENT BIG DROPS panel on the east leaderboard wall.
--   THE EXCHANGE: a prompt + name plate on the east market stall (no board of its own).
-- (2026-10-20 owner: "the hub now feels a bit cluttered": the plaza-floor drop board, market board and the mid-plaza plinths
--  and leaders went to the walls / edges.)
-- LivingHub.Build(hub, deps { TopOf(board, asc, n), OpenDistricts(player, id), OpenMarket(player) }) after the hub is built.
-- Budget: 3 figures (~16 parts each) + 3 statues, no lights.
-- ============================================================================================
local Players = game:GetService("Players")
local LivingHub = {}

LivingHub.GROUND = 4 -- (HubCity.GROUND: the street's top)
LivingHub.LEADER_SPOTS = { LANTERN = Vector3.new(-18, 0, -61), WIRE = Vector3.new(-28.5, 0, 27), IRON = Vector3.new(18, 0, -61) }
LivingHub.LEADER_LOOK = { LANTERN = Vector3.new(-18, 0, 0), WIRE = Vector3.new(0, 0, 27), IRON = Vector3.new(18, 0, 0) }
LivingHub.STATUE_SPOTS = { Vector3.new(0, 0, -63), Vector3.new(-7.5, 0, -62), Vector3.new(7.5, 0, -62) } -- (between the gates)
LivingHub.EXCHANGE_STALL = Vector3.new(35, 0, 27) -- (the east market stall nearest the spawn)
LivingHub.SUPPLY_STALL = Vector3.new(-35, 0, -25) -- (MOD SUPPLY 2026-11-07: the free west stall by the FORGE row)
LivingHub.SUPPLY_COLOR = Color3.fromRGB(120, 200, 255)
LivingHub.STATUE_TINT = { Color3.fromRGB(214, 176, 92), Color3.fromRGB(176, 182, 192), Color3.fromRGB(176, 118, 74) }
LivingHub.MARKET_SPOT = CFrame.lookAt(Vector3.new(36, 0, 14), Vector3.new(0, 0, 14)) -- (fallback board when the stall is missing)
LivingHub.DROP_ROWS = 8
LivingHub.LEADER_SCALE = 1.15
LivingHub.STATUE_EVERY = 600

local folder: Folder? = nil
local drops = {}
local deps: any = {}

local function P(props: any): BasePart
    local p = Instance.new(props.ClassName or "Part")
    props.ClassName = nil
    p.Anchored, p.CanCollide, p.CanTouch = true, props.CanCollide ~= false, false
    props.CanCollide = nil
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    for k, v in pairs(props) do p[k] = v end
    return p
end

local function Plate(parent: Instance, adornee: BasePart, title: string, sub: string, color: Color3, yOff: number, maxDist: number?)
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(240, 46)
    bb.StudsOffset = Vector3.new(0, yOff, 0)
    bb.MaxDistance = maxDist or 34 -- (close up only: from the spawn the plaza's plates crowded each other)
    bb.Adornee = adornee
    bb.Parent = parent
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Size = UDim2.new(1, 0, 0, 26)
    t.Font = Enum.Font.Oswald
    t.TextSize = 22
    t.TextColor3 = color
    t.TextStrokeTransparency = 0.35
    t.Text = title
    t.Parent = bb
    local s = t:Clone()
    s.Position = UDim2.fromOffset(0, 24)
    s.Size = UDim2.new(1, 0, 0, 20)
    s.TextSize = 15
    s.TextColor3 = Color3.fromRGB(220, 222, 228)
    s.Text = sub
    s.Parent = bb
end

-- an R6 figure from a description (plain body colours); anchored, facing `look`
local function Figure(desc: HumanoidDescription, pos: Vector3, look: Vector3): Model?
    local ok, m = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6) end)
    if not ok or not m then return nil end
    local hum = m:FindFirstChildOfClass("Humanoid")
    if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
    local animate = m:FindFirstChild("Animate")
    if animate then animate:Destroy() end
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then d.Anchored = (d.Name == "HumanoidRootPart"); d.CanTouch = false end
    end
    local root = m:FindFirstChild("HumanoidRootPart")
    if root then m.PrimaryPart = root end -- (the generated model's pivot is its Head: feet ended up 1.7 studs under the floor)
    m:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 3, 0), Vector3.new(look.X, pos.Y + 3, look.Z)))
    return m
end

local function BuildLeaders(parent: Instance)
    local Districts = require(game.ReplicatedStorage.AimRngShared.Districts)
    for _, id in ipairs(Districts.Order) do
        local d = Districts.Defs[id]
        local spot = LivingHub.LEADER_SPOTS[id] + Vector3.new(0, LivingHub.GROUND, 0)
        local desc = Instance.new("HumanoidDescription")
        local skin = Color3.fromRGB(196, 150, 118)
        -- (HUB LOOK v2: a dark coat in the quarter's hue, dark trousers; the colour itself goes on the collar / hat / prop)
        local coat = d.Color:Lerp(Color3.fromRGB(18, 16, 22), 0.72)
        local trousers = Color3.fromRGB(34, 32, 38)
        desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, coat, coat
        desc.TorsoColor, desc.LeftLegColor, desc.RightLegColor = coat, trousers, trousers
        local look = LivingHub.LEADER_LOOK[id] or Vector3.new(0, 0, 24)
        local fig = Figure(desc, spot, look)
        if fig then
            fig.Name = "Leader_" .. id
            fig:SetAttribute("District", id)
            -- (HUB LOOK v2 2026-10-24, owner: the leaders read as "plain blocky figures + ball hood"): each is DRESSED for
            -- their quarter in the city's night palette -- a long coat (skirt panel to the knee + a raised collar), a belt
            -- and one thing that says who they are: LANTERN = a wide rain hat + a paper lantern in hand, WIRE = a hood
            -- up + a cable coil slung across the chest + a lit visor, IRON = a hard hat + a hi-vis work vest. Parts are
            -- welded to the torso / head / arm, so the poser's breathing idle moves them.
            local head, torso = fig:FindFirstChild("Head"), fig:FindFirstChild("Torso")
            local armR = fig:FindFirstChild("Right Arm")
            if head and torso then
                local function Wear(owner: BasePart, name: string, size: Vector3, cf: CFrame, col: Color3, mat: Enum.Material, shape: Enum.PartType?)
                    local w = P({ Name = name, Size = size, Color = col, Material = mat, CanCollide = false, CFrame = owner.CFrame * cf })
                    if shape then w.Shape = shape end
                    w.CanQuery = false
                    local wc = Instance.new("WeldConstraint"); wc.Part0, wc.Part1 = owner, w; wc.Parent = w
                    w.Anchored = false
                    w.Parent = fig
                    return w
                end
                local dark = d.Color:Lerp(Color3.fromRGB(18, 16, 22), 0.72)
                local coatCol = (id == "IRON") and Color3.fromRGB(58, 56, 52) or dark
                -- the coat's skirt (from the waist to the knee, a touch wider than the hips) + its raised collar + a belt
                Wear(torso, "CoatSkirt", Vector3.new(2.12, 1.25, 1.12), CFrame.new(0, -1.55, 0), coatCol, Enum.Material.Fabric)
                Wear(torso, "CoatCollar", Vector3.new(1.5, 0.42, 1.14), CFrame.new(0, 0.95, 0.02), d.Color:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Fabric)
                Wear(torso, "Belt", Vector3.new(2.06, 0.2, 1.06), CFrame.new(0, -0.82, 0), Color3.fromRGB(34, 26, 22), Enum.Material.Leather)
                if id == "LANTERN" then
                    Wear(head, "HatBrim", Vector3.new(0.12, 2.5, 2.5), CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 52, 34), Enum.Material.Fabric, Enum.PartType.Cylinder)
                    Wear(head, "HatCrown", Vector3.new(0.5, 1.15, 1.15), CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(86, 64, 40), Enum.Material.Fabric, Enum.PartType.Cylinder)
                    if armR then
                        local lan = Wear(armR, "HandLantern", Vector3.new(0.95, 0.95, 0.95), CFrame.new(0, -1.75, -0.55), Color3.fromRGB(230, 70, 40), Enum.Material.Neon, Enum.PartType.Ball)
                        lan.Transparency = 0.1
                        Wear(armR, "HandLanternCap", Vector3.new(0.18, 0.7, 0.7), CFrame.new(0, -1.24, -0.55) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(34, 24, 20), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
                    end
                elseif id == "WIRE" then
                    Wear(head, "Hood", Vector3.new(1.35, 1.25, 1.3), CFrame.new(0, 0.12, 0.16), coatCol, Enum.Material.Fabric)
                    Wear(head, "Visor", Vector3.new(1.0, 0.16, 0.08), CFrame.new(0, 0.18, -0.6), d.Color, Enum.Material.Neon)
                    Wear(torso, "CableCoil", Vector3.new(0.22, 2.1, 0.22), CFrame.new(0, 0.05, -0.6) * CFrame.Angles(0, 0, math.rad(38)), Color3.fromRGB(26, 26, 30), Enum.Material.Rubber)
                    Wear(torso, "CableCoil2", Vector3.new(0.18, 2.1, 0.18), CFrame.new(0.1, 0.05, -0.64) * CFrame.Angles(0, 0, math.rad(38)), d.Color:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Rubber)
                else -- IRON
                    Wear(head, "HardHat", Vector3.new(0.7, 1.35, 1.35), CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(214, 160, 40), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
                    Wear(head, "HardHatBrim", Vector3.new(0.1, 1.65, 1.65), CFrame.new(0, 0.32, -0.05) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(196, 146, 36), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
                    Wear(torso, "WorkVest", Vector3.new(2.06, 1.6, 1.08), CFrame.new(0, 0.1, 0), d.Color:Lerp(Color3.fromRGB(230, 120, 40), 0.4), Enum.Material.Fabric)
                end
            end
            fig:AddTag("AimPoseDummy")
            local root = fig:FindFirstChild("HumanoidRootPart")
            local pr = Instance.new("ProximityPrompt")
            pr.Name = "DistrictLeader"
            pr.ActionText = "Talk"
            pr.ObjectText = d.Leader
            pr.MaxActivationDistance = 12
            pr.RequiresLineOfSight = false
            pr:SetAttribute("District", id)
            pr.Parent = root
            pr.Triggered:Connect(function(player) if deps.OpenDistricts then deps.OpenDistricts(player, id) end end)
            Plate(fig, head or root, string.upper(d.Leader), d.Name .. "  •  " .. d.Style, d.Color, 3.2)
            fig.Parent = parent
            -- a low plinth they stand at
            P({ Name = "LeaderStep_" .. id, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 6, 6), Color = Color3.fromRGB(52, 50, 56),
                Material = Enum.Material.Slate, CFrame = CFrame.new(spot + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)), Parent = parent })
            P({ Name = "LeaderRing_" .. id, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 6.4, 6.4), Color = d.Color, Material = Enum.Material.Neon,
                Transparency = 0.35, CanCollide = false, CFrame = CFrame.new(spot + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Parent = parent })
            pcall(function() fig:ScaleTo(LivingHub.LEADER_SCALE) end) -- (a touch bigger than players: they read as the city's people)
            fig:PivotTo(CFrame.lookAt(spot + Vector3.new(0, 3 * LivingHub.LEADER_SCALE + 0.5, 0), Vector3.new(look.X, spot.Y + 3, look.Z))) -- (feet on the step)
        end
    end
end

-- ===== HALL OF AIM: statues of the top three (HIGHEST LEVEL) =====
local statueFolder: Folder? = nil
local statueKey = ""
local function BuildStatues(parent: Instance)
    local rows = deps.TopOf and deps.TopOf("PlayerLevel", false, 3) or {}
    local key = ""
    for _, r in ipairs(rows) do key ..= tostring(r.UserId) .. ":" .. tostring(r.Value) .. ";" end
    if key == statueKey and statueFolder then return end
    statueKey = key
    if statueFolder then statueFolder:Destroy() end
    local f = Instance.new("Folder")
    f.Name = "HallOfAim"
    f.Parent = parent
    statueFolder = f
    for i = 1, 3 do
        local spot = LivingHub.STATUE_SPOTS[i] + Vector3.new(0, LivingHub.GROUND, 0)
        local tint = LivingHub.STATUE_TINT[i]
        local h = (i == 1) and 3 or 2.2
        -- (HUB LOOK v2 2026-10-24: a flat 5x5 Marble slab read as plastic, white under the gate neon) a dark granite
        -- pedestal: a wider stepped base, the die, a cap in the medal metal and a bronze-look plate on its front
        local stone = Color3.fromRGB(44, 42, 48)
        P({ Name = "PlinthBase" .. i, Size = Vector3.new(6, 0.45, 6), Color = stone:Lerp(Color3.new(0, 0, 0), 0.2), Material = Enum.Material.Slate,
            CFrame = CFrame.new(spot + Vector3.new(0, 0.225, 0)), Parent = f })
        local plinth = P({ Name = "Plinth" .. i, Size = Vector3.new(4.6, h - 0.45, 4.6), Color = stone, Material = Enum.Material.Slate,
            CFrame = CFrame.new(spot + Vector3.new(0, 0.45 + (h - 0.45) / 2, 0)), Parent = f })
        P({ Name = "PlinthTrim" .. i, Size = Vector3.new(5.1, 0.3, 5.1), Color = Color3.fromRGB(34, 32, 38), Material = Enum.Material.Slate, CanCollide = false,
            CFrame = CFrame.new(spot + Vector3.new(0, h - 0.1, 0)), Parent = f })
        P({ Name = "PlinthPlate" .. i, Size = Vector3.new(2.6, 0.7, 0.1), Color = tint:Lerp(Color3.new(0, 0, 0), 0.35), Material = Enum.Material.Metal, CanCollide = false,
            CFrame = CFrame.new(spot + Vector3.new(0, 0.45 + (h - 0.45) * 0.55, 2.37)), Parent = f })
        local r = rows[i]
        if r and r.UserId and r.UserId > 0 then
            local ok, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(r.UserId) end)
            local m = ok and desc and Figure(desc, spot + Vector3.new(0, h, 0), Vector3.new(0, 0, 24)) or nil
            if m then
                m.Name = "Statue" .. i
                for _, d in ipairs(m:GetDescendants()) do
                    if d:IsA("BasePart") then
                        d.Anchored, d.CanCollide, d.CanQuery = true, false, false
                        d.Color = tint
                        d.Material = (i == 1) and Enum.Material.Metal or Enum.Material.Marble
                        if d:IsA("MeshPart") then d.TextureID = "" end
                        local sa = d:FindFirstChildOfClass("SurfaceAppearance")
                        if sa then sa:Destroy() end
                    elseif d:IsA("Decal") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("Clothing") then
                        d:Destroy()
                    elseif d:IsA("SpecialMesh") then
                        d.TextureId = ""
                    end
                end
                local hum = m:FindFirstChildOfClass("Humanoid")
                if hum then hum:Destroy() end -- (stone: no body colours or clothes re-applied)
                m:PivotTo(m:GetPivot() * CFrame.new(0, 0, 0))
                m.Parent = f
            end
            if deps.OpenProfile then -- (2026-10-20 PLAYER PROFILES: see the statue's gear, build and aim)
                local pr = Instance.new("ProximityPrompt")
                pr.Name = "StatueProfile"
                pr.ActionText = "View profile"
                pr.ObjectText = tostring(r.Name or "?")
                pr.HoldDuration = 0
                pr.MaxActivationDistance = 12
                pr.RequiresLineOfSight = false
                pr.Parent = plinth
                local uid = r.UserId
                pr.Triggered:Connect(function(player) deps.OpenProfile(player, uid) end)
            end
            local lvl = math.floor((tonumber(r.Value) or 0) / 10000)
            Plate(f, plinth, "#" .. i .. "  " .. string.upper(tostring(r.Name or "?")), "level " .. lvl, tint, (i == 1) and 8.2 or 7.4)
        else
            Plate(f, plinth, "#" .. i, (i == 1) and "this could be you" or "", tint, 3) -- (one line each: the empty plates crowded)
        end
    end
end

-- ===== THE DROP BOARD =====
function LivingHub.NoteDrop(playerName: string, itemName: string, rarity: string, oneIn: number?, color: Color3?)
    table.insert(drops, 1, { Who = playerName, Item = itemName, Rarity = rarity, OneIn = oneIn, Color = color, At = os.time() })
    while #drops > LivingHub.DROP_ROWS do table.remove(drops) end
    LivingHub.RenderBoard()
end
function LivingHub.RenderBoard()
    local HttpService = game:GetService("HttpService")
    local rs = game:GetService("ReplicatedStorage")
    local lb = rs:FindFirstChild("Leaderboards")
    if not lb then
        lb = Instance.new("Folder")
        lb.Name = "Leaderboards"
        lb.Parent = rs
    end
    local sv = lb:FindFirstChild("Drops")
    if not sv then
        sv = Instance.new("StringValue")
        sv.Name = "Drops"
        sv:SetAttribute("Id", "Drops")
        sv:SetAttribute("Title", "RECENT BIG DROPS")
        sv:SetAttribute("Kind", "drop")
        sv.Parent = lb
    end
    local rows = {}
    for _, d in ipairs(drops) do
        table.insert(rows, { Name = d.Who, Item = d.Item, Rarity = d.Rarity, OneIn = d.OneIn, Color = d.Color and d.Color:ToHex() or "ffffff" })
    end
    sv.Value = HttpService:JSONEncode(rows)
end

-- (Studio / admin) rebuild the statues now
function LivingHub.RefreshStatues()
    statueKey = "?"
    if folder then BuildStatues(folder) end
end

-- THE EXCHANGE: a prompt + plate on the east market stall; the old lit board only when the stall isn't there
local function ExchangePrompt(at: BasePart)
    local pr = Instance.new("ProximityPrompt")
    pr.Name = "OpenMarket"
    pr.ActionText = "Open the Exchange"
    pr.ObjectText = "The Exchange"
    pr.MaxActivationDistance = 12
    pr.RequiresLineOfSight = false
    pr.Parent = at
    pr.Triggered:Connect(function(player) if deps.OpenMarket then deps.OpenMarket(player) end end)
end
local function BuildExchange(parent: Instance): boolean
    local hub = parent.Parent
    local best, bestD = nil, 12
    for _, d in ipairs(hub and hub:GetDescendants() or {}) do
        if d:IsA("BasePart") and d.Name == "Hitbox" then
            local p = d.Position
            local dist = (Vector3.new(p.X, 0, p.Z) - LivingHub.EXCHANGE_STALL).Magnitude
            if dist < bestD then best, bestD = d, dist end
        end
    end
    if not best then return false end
    ExchangePrompt(best)
    Plate(parent, best, "THE EXCHANGE", "buy + sell with every player", Color3.fromRGB(110, 230, 150), 4.4, 46)
    return true
end
-- (MOD SUPPLY 2026-11-07, builder scarce) the city's shot-mod vendor: a prompt + plate on the free west market stall (the
-- Exchange's pattern) -> deps.OpenSupply = the MODS window on its SUPPLY view (stock + prices: ShotMods.SUPPLY)
local function BuildSupply(parent: Instance): boolean
    local hub = parent.Parent
    local best, bestD = nil, 12
    for _, d in ipairs(hub and hub:GetDescendants() or {}) do
        if d:IsA("BasePart") and d.Name == "Hitbox" then
            local p = d.Position
            local dist = (Vector3.new(p.X, 0, p.Z) - LivingHub.SUPPLY_STALL).Magnitude
            if dist < bestD then best, bestD = d, dist end
        end
    end
    if not best then return false end
    local pr = Instance.new("ProximityPrompt")
    pr.Name = "OpenModSupply"
    pr.ActionText = "Browse mods"
    pr.ObjectText = "Mod Supply"
    pr.MaxActivationDistance = 12
    pr.RequiresLineOfSight = false
    pr.Parent = best
    pr.Triggered:Connect(function(player) if deps.OpenSupply then deps.OpenSupply(player) end end)
    Plate(parent, best, "MOD SUPPLY", "plain mods for scrap + gold", LivingHub.SUPPLY_COLOR, 4.4, 46)
    return true
end
local function BuildMarketBoard(parent: Instance)
    local cf = LivingHub.MARKET_SPOT + Vector3.new(0, LivingHub.GROUND, 0)
    local frame = P({ Name = "MarketBoardFrame", Size = Vector3.new(12, 7, 0.6), Color = Color3.fromRGB(30, 32, 36), Material = Enum.Material.Metal,
        CFrame = cf * CFrame.new(0, 5.6, 0), Parent = parent })
    for _, x in ipairs({ -4.6, 4.6 }) do
        P({ Name = "MarketBoardPost", Size = Vector3.new(0.6, 4.2, 0.6), Color = Color3.fromRGB(40, 40, 46), Material = Enum.Material.Metal, CFrame = cf * CFrame.new(x, 2.1, 0), Parent = parent })
    end
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 40
    sg.LightInfluence = 0
    sg.Brightness = 1.2
    sg.MaxDistance = 140
    sg.Parent = frame
    local t = Instance.new("TextLabel")
    t.Size = UDim2.fromScale(1, 1)
    t.BackgroundColor3 = Color3.fromRGB(12, 22, 16)
    t.BorderSizePixel = 0
    t.Font = Enum.Font.Oswald
    t.TextColor3 = Color3.fromRGB(110, 230, 150)
    t.RichText = true
    t.TextSize = 40
    t.Text = "THE EXCHANGE\n<font size=\"22\" color=\"#c8d2cc\">buy and sell with every player, even offline</font>"
    t.Parent = sg
    ExchangePrompt(frame)
end

function LivingHub.Build(hub: Instance, d: any)
    deps = d or {}
    if folder then folder:Destroy() end
    local f = Instance.new("Folder")
    f.Name = "LivingHub"
    f.Parent = hub
    folder = f
    pcall(BuildLeaders, f)
    pcall(LivingHub.RenderBoard)
    local okX, onStall = pcall(BuildExchange, f)
    if not (okX and onStall) then pcall(BuildMarketBoard, f) end
    pcall(BuildSupply, f)
    task.spawn(function()
        task.wait(8) -- (the boards' first read)
        while f.Parent do
            pcall(BuildStatues, f)
            task.wait(LivingHub.STATUE_EVERY)
        end
    end)
    return f
end

return LivingHub
